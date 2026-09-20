-- DBB2 Message API
-- Handles message capturing, storage, and filtering logic
--
-- Dependencies: api/blacklist.lua (IsMessageBlacklisted)
--               api/notifications.lua (CheckAndNotify)
--               api/categories_api.lua (CategorizeMessage)
-- This file must be loaded AFTER blacklist.lua and notifications.lua

-- Localize frequently used globals for performance
local string_lower = string.lower
local string_gsub = string.gsub
local table_insert = table.insert
local table_remove = table.remove
local table_getn = table.getn
local time = time
local ipairs = ipairs

-- Constants
local MAX_MESSAGES = 100

-- =====================
-- MESSAGE API
-- =====================

-- [ RemoveExpiredMessages ]
-- Removes messages older than the configured expire time
-- Called periodically to clean up old messages
function DBB2.api.RemoveExpiredMessages()
  local expireMinutes = DBB2_Config.messageExpireMinutes or 15
  if expireMinutes <= 0 then
    return
  end
  
  local expireSeconds = expireMinutes * 60
  local currentTime = time()
  local removed = false
  local removedCount = 0
  
  -- Remove from oldest to newest (start from beginning)
  for i = table_getn(DBB2.messages), 1, -1 do
    local msg = DBB2.messages[i]
    local age = currentTime - (msg.time or 0)
    
    if age > expireSeconds then
      table_remove(DBB2.messages, i)
      removed = true
      removedCount = removedCount + 1
    end
  end
  
  -- Update GUI if messages were removed and GUI is visible
  if removed and DBB2.gui and DBB2.gui:IsShown() then
    if DBB2.gui.UpdateMessages then
      DBB2.gui:UpdateMessages()
    end
    
    -- Update active categorized tab if showing
    if DBB2.gui.tabs and DBB2.gui.tabs.activeTab then
      local activeTab = DBB2.gui.tabs.activeTab
      if activeTab == "Groups" or activeTab == "Professions" or activeTab == "Hardcore" then
        local panel = DBB2.gui.tabs.panels[activeTab]
        if panel and panel.UpdateCategories then
          panel.UpdateCategories()
        end
      end
    end
  end

  if removedCount > 0 then
    if DBB2.debug.enabled then
      DBB2.api.DebugCount("messages.expired", removedCount)
      DBB2.api.DebugTrace(2, "message", "expired-cleanup", "removed=" .. removedCount .. " expiryMinutes=" .. expireMinutes)
    end
  end
end

-- [ StripHyperlinks ]
-- Removes WoW hyperlink formatting from a message for comparison purposes
-- Hyperlinks like |Hplayer:Name|h[Name]|h become just [Name]
-- 'message'    [string]        the message text
-- return:      [string]        message with hyperlinks stripped
function DBB2.api.StripHyperlinks(message)
  if not message then return "" end
  -- Remove color codes |cXXXXXXXX and |r
  local clean = string_gsub(message, "|c%x%x%x%x%x%x%x%x", "")
  clean = string_gsub(clean, "|r", "")
  -- Remove hyperlinks |H...|h...|h -> keep the visible text
  clean = string_gsub(clean, "|H[^|]*|h([^|]*)|h", "%1")
  return clean
end

-- [ IsDuplicateMessage ]
-- Checks if a message is a duplicate within the spam filter time window
-- 'message'    [string]        the message text
-- 'sender'     [string]        the sender name
-- return:      [boolean]       true if duplicate, false otherwise
function DBB2.api.IsDuplicateMessage(message, sender)
  if not message then return false end
  
  local spamSeconds = DBB2_Config.spamFilterSeconds or 150
  if spamSeconds <= 0 then
    return false  -- Spam filter disabled
  end
  
  local currentTime = time()
  -- Strip hyperlinks before comparison so [Guild] links with different internal IDs still match
  local lowerMsg = string_lower(DBB2.api.StripHyperlinks(message))
  local lowerSender = string_lower(sender or "")
  local msgCount = table_getn(DBB2.messages)
  
  -- Check existing messages for duplicates
  for i = msgCount, 1, -1 do
    local msg = DBB2.messages[i]
    local timeDiff = currentTime - (msg.time or 0)
    
    -- Only check messages within the spam filter window
    if timeDiff > spamSeconds then
      break  -- Messages are ordered by time, so we can stop here
    end
    
    -- Check if same sender and same message (strip hyperlinks for comparison)
    local storedMsg = string_lower(DBB2.api.StripHyperlinks(msg.message or ""))
    local storedSender = string_lower(msg.sender or "")
    
    if storedSender == lowerSender and storedMsg == lowerMsg then
      return true
    end
  end
  
  return false
end

-- [ IsStoredUnsortedMessage ]
-- Returns true when the same sender/message pair is already present as an
-- unsorted entry. The chat filter uses this to apply the Hide from Chat mode
-- directly instead of treating the entry as an ordinary duplicate.
function DBB2.api.IsStoredUnsortedMessage(message, sender)
  if not message then return false end

  local lowerMsg = string_lower(DBB2.api.StripHyperlinks(message))
  local lowerSender = string_lower(sender or "")

  for i = table_getn(DBB2.messages), 1, -1 do
    local msg = DBB2.messages[i]
    if msg and msg.isUnsorted then
      local storedMsg = string_lower(DBB2.api.StripHyperlinks(msg.message or ""))
      local storedSender = string_lower(msg.sender or "")
      if storedSender == lowerSender and storedMsg == lowerMsg then
        return true
      end
    end
  end

  return false
end

-- [ RemovePreviousMessageFromSameSender ]
-- Removes any previous message from the same sender that matches the same categories
-- This ensures only the most recent message per sender per category is shown
-- Hardcore messages are excluded from this deduplication
-- 'sender'         [string]        the sender name
-- 'newCategories'  [table]         categories the new message matches (from CategorizeMessage)
-- 'ignoreFilterTags' [boolean]     if true, compare categories without the extra filter tag gate
-- return:          [boolean]       true if a message was removed
function DBB2.api.RemovePreviousMessageFromSameSender(sender, newCategories, ignoreFilterTags)
  if not sender or not newCategories then return false end
  
  -- Skip deduplication for hardcore messages
  if newCategories.isHardcore then return false end
  
  local lowerSender = string_lower(sender)
  local newGroups = newCategories.groups or {}
  local newProfessions = newCategories.professions or {}
  
  -- No categories to dedupe against
  if table_getn(newGroups) == 0 and table_getn(newProfessions) == 0 then
    return false
  end
  
  -- Build lookup tables for new message category names (they are strings)
  local newGroupsLookup = {}
  local newProfessionsLookup = {}
  for _, catName in ipairs(newGroups) do
    newGroupsLookup[catName] = true
  end
  for _, catName in ipairs(newProfessions) do
    newProfessionsLookup[catName] = true
  end
  
  -- Search for previous messages from same sender with overlapping categories
  for i = table_getn(DBB2.messages), 1, -1 do
    local msg = DBB2.messages[i]
    if msg and string_lower(msg.sender or "") == lowerSender then
      -- Check if this old message matches any of the same categories
      local oldCategories = DBB2.api.CategorizeMessage(msg.message, true, ignoreFilterTags)
      if oldCategories and not oldCategories.isHardcore then
        local hasOverlap = false
        
        -- Check groups overlap (category names are strings)
        for _, catName in ipairs(oldCategories.groups or {}) do
          if newGroupsLookup[catName] then
            hasOverlap = true
            break
          end
        end
        
        -- Check professions overlap if no groups overlap found
        if not hasOverlap then
          for _, catName in ipairs(oldCategories.professions or {}) do
            if newProfessionsLookup[catName] then
              hasOverlap = true
              break
            end
          end
        end
        
        -- Remove the old message if categories overlap
        if hasOverlap then
          table_remove(DBB2.messages, i)
          if DBB2.debug.enabled then
            DBB2.api.DebugCount("messages.replaced", 1)
            DBB2.api.DebugTrace(2, "message", "replaced-previous", "sender=" .. sender .. " oldText=\"" .. (msg.message or "") .. "\"")
          end
          return true
        end
      end
    end
  end
  
  return false
end

-- [ AddMessage ]
-- Adds a new message to the message store
-- Stores category matches plus optional Logs-only unsorted messages.
-- IMPORTANT: System messages (CHAT_MSG_SYSTEM) are ONLY stored if they match hardcore categories
-- This prevents /who results, loot messages, etc. from appearing in Groups/Professions tabs
-- For Groups and Professions: replaces previous message from same sender in same category
-- 'message'    [string]        the message text
-- 'sender'     [string]        the sender name
-- 'channel'    [string]        the channel name
-- 'type'       [string]        the message type (CHAT_MSG_GUILD, CHAT_MSG_CHANNEL, etc)
function DBB2.api.AddMessage(message, sender, channel, msgType)
  local debugging = DBB2.debug.enabled
  local debugStart = nil
  if debugging then debugStart = DBB2.api.DebugClock() end

  -- Guard against nil message
  if not message then
    if debugging then DBB2.api.DebugFinishDecision(debugStart, "rejected-invalid", "reason=nil message") end
    return
  end

  local context = nil
  if debugging then
    context = "sender=" .. (sender or "Unknown") .. " channel=" .. (channel or "") .. " type=" .. (msgType or "") .. " text=\"" .. message .. "\""
  end
  
  -- Clean up expired messages first
  DBB2.api.RemoveExpiredMessages()

  -- Blacklist handling is the first matching decision for every message from
  -- an enabled source, including candidates for unsorted capture.
  local isBlacklisted, blacklistReason, blacklistDetails = DBB2.api.IsMessageBlacklisted(message, sender)
  if isBlacklisted then
    if debugging then
      local detailText = blacklistDetails
      if type(detailText) == "table" then detailText = table.concat(detailText, ",") end
      DBB2.api.DebugFinishDecision(debugStart, "rejected-blacklist", context .. " reason=" .. (blacklistReason or "unknown") .. " match=" .. tostring(detailText or ""))
    end
    return
  end
  
  -- Categorize twice:
  -- 1) fullCategories respects filter tags and controls what is actually stored/shown
  -- 2) baseCategories ignores filter tags so a newer reworded message can still clear
  --    an older same-sender entry for the same run instead of leaving stale GUI data behind
  local fullCategories = DBB2.api.CategorizeMessage(message, true)
  local baseCategories = DBB2.api.CategorizeMessage(message, true, true)
  
  -- Check if message matches any category (ignoring enabled state)
  -- This ensures duplicate filter works for all category patterns
  local categories = fullCategories
  local matchesAnyCategory = (table_getn(categories.groups) > 0) or 
                              (table_getn(categories.professions) > 0) or 
                              (table_getn(categories.hardcore) > 0)
  local matchesBaseCategory = (table_getn(baseCategories.groups) > 0) or
                              (table_getn(baseCategories.professions) > 0) or
                              (table_getn(baseCategories.hardcore) > 0)

  local categoryDetail = nil
  if debugging then
    categoryDetail = " full(groups=" .. table.concat(fullCategories.groups, ",") ..
                     ";professions=" .. table.concat(fullCategories.professions, ",") ..
                     ";hardcore=" .. table.concat(fullCategories.hardcore, ",") .. ")" ..
                     " base(groups=" .. table.concat(baseCategories.groups, ",") ..
                     ";professions=" .. table.concat(baseCategories.professions, ",") ..
                     ";hardcore=" .. table.concat(baseCategories.hardcore, ",") .. ")"
  end
  
  -- CRITICAL: System messages (like /who results) should ONLY be stored if they match
  -- hardcore categories. This prevents zone names in /who results from polluting
  -- the Groups/Professions tabs (e.g., "Zul'Gurub" in a /who result)
  if msgType == "CHAT_MSG_SYSTEM" then
    local matchesHardcore = table_getn(baseCategories.hardcore) > 0
    if not matchesHardcore then
      if debugging then DBB2.api.DebugFinishDecision(debugStart, "rejected-system", context .. " reason=system messages require a Hardcore category" .. categoryDetail) end
      return  -- System message doesn't match hardcore, ignore it
    end
  end

  -- A message matching any known category can never become unsorted, even if
  -- the category is disabled or its optional Filter Tags gate rejects it.
  local unsortedType = nil
  if not matchesBaseCategory then
    if not DBB2_Config.showUnsortedMessagesInLogs then
      if debugging then DBB2.api.DebugFinishDecision(debugStart, "rejected-no-category", context .. " reason=no known category and unsorted logging disabled" .. categoryDetail) end
      return
    end

    unsortedType = DBB2.api.MatchUnsortedFilterTags(message)
    if not unsortedType then
      if debugging then DBB2.api.DebugFinishDecision(debugStart, "rejected-no-category", context .. " reason=no known category or unsorted filter-tag match" .. categoryDetail) end
      return
    end
  end
  
  if DBB2.api.IsDuplicateMessage(message, sender) then
    if debugging then DBB2.api.DebugFinishDecision(debugStart, "rejected-duplicate", context .. " spamWindow=" .. (DBB2_Config.spamFilterSeconds or 150) .. "s" .. categoryDetail) end
    return
  end
  
  if not unsortedType then
    -- Clear stale messages from the same sender using base category overlap so an
    -- updated line can replace an older GUI entry even if it no longer passes the
    -- optional filter tag requirement.
    DBB2.api.RemovePreviousMessageFromSameSender(sender, baseCategories, true)

    -- If the message no longer passes the active filter tag gate, stop after clearing
    -- any stale older entry. We do not store/show the new line in the GUI.
    if not matchesAnyCategory then
      if debugging then DBB2.api.DebugFinishDecision(debugStart, "rejected-filter-tags", context .. " reason=base category matched but active filter tags did not; stale entry cleared if present" .. categoryDetail) end
      return
    end

    -- Unsorted messages intentionally skip notifications. Categorized messages
    -- retain the existing notification behavior.
    DBB2.api.CheckAndNotify(message, sender, msgType)
  end
  
  -- Store message
  table_insert(DBB2.messages, {
    message = message,
    sender = sender or "Unknown",
    channel = channel or "",
    time = time(),
    type = msgType or "",
    isUnsorted = unsortedType ~= nil,
    unsortedType = unsortedType
  })
  
  -- Keep only last MAX_MESSAGES messages
  if table_getn(DBB2.messages) > MAX_MESSAGES then
    table_remove(DBB2.messages, 1)
    if debugging then DBB2.api.DebugCount("messages.capacityEvicted", 1) end
  end
  
  -- Update GUI if visible
  if DBB2.gui and DBB2.gui:IsShown() then
    -- Update logs tab
    if DBB2.gui.UpdateMessages then
      DBB2.gui:UpdateMessages()
    end
    
    -- Update active categorized tab if showing
    if DBB2.gui.tabs and DBB2.gui.tabs.activeTab then
      local activeTab = DBB2.gui.tabs.activeTab
      if activeTab == "Groups" or activeTab == "Professions" or activeTab == "Hardcore" then
        local panel = DBB2.gui.tabs.panels[activeTab]
        if panel and panel.UpdateCategories then
          panel.UpdateCategories()
        end
      end
    end
  end


  if debugging then
    if unsortedType then
      DBB2.api.DebugFinishDecision(debugStart, "stored-unsorted", context .. " unsortedType=" .. unsortedType .. categoryDetail)
    else
      DBB2.api.DebugFinishDecision(debugStart, "stored-categorized", context .. categoryDetail)
    end
  end
end

-- [ GetMessages ]
-- Returns all stored messages
-- return:      [table]         array of message objects
function DBB2.api.GetMessages()
  return DBB2.messages
end

-- [ GetMessageCount ]
-- Returns the number of stored messages
-- return:      [number]        message count
function DBB2.api.GetMessageCount()
  return table_getn(DBB2.messages)
end

-- [ ClearMessages ]
-- Clears all stored messages
-- return:      [boolean]       true (always succeeds)
function DBB2.api.ClearMessages()
  DBB2.messages = {}
  
  -- Update GUI if visible
  if DBB2.gui and DBB2.gui:IsShown() and DBB2.gui.UpdateMessages then
    DBB2.gui:UpdateMessages()
  end
  return true
end

-- [ FilterMessages ]
-- Returns filtered messages based on criteria
-- 'filterType' [string]        filter type: "guild", "channel", "all"
-- 'limit'      [number]        max number of messages to return (optional)
-- return:      [table]         filtered array of message objects
function DBB2.api.FilterMessages(filterType, limit)
  local filtered = {}
  local count = table_getn(DBB2.messages)
  
  -- Default to "all" if no filter type specified
  filterType = filterType or "all"
  
  for i = 1, count do
    local msg = DBB2.messages[i]
    
    if filterType == "all" then
      table_insert(filtered, msg)
    elseif filterType == "guild" and msg.type == "CHAT_MSG_GUILD" then
      table_insert(filtered, msg)
    elseif filterType == "channel" and msg.type == "CHAT_MSG_CHANNEL" then
      table_insert(filtered, msg)
    end
  end
  
  -- Apply limit if specified
  if limit and limit > 0 and table_getn(filtered) > limit then
    local start = table_getn(filtered) - limit + 1
    local limited = {}
    for i = start, table_getn(filtered) do
      table_insert(limited, filtered[i])
    end
    return limited
  end
  
  return filtered
end
