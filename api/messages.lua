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
  
  -- Remove from oldest to newest (start from beginning)
  for i = table_getn(DBB2.messages), 1, -1 do
    local msg = DBB2.messages[i]
    local age = currentTime - (msg.time or 0)
    
    if age > expireSeconds then
      table_remove(DBB2.messages, i)
      removed = true
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

-- [ RemovePreviousMessageFromSameSender ]
-- Removes any previous message from the same sender that matches the same categories
-- This ensures only the most recent message per sender per category is shown
-- Hardcore messages are excluded from this deduplication
-- 'sender'         [string]        the sender name
-- 'newCategories'  [table]         categories the new message matches (from CategorizeMessage)
-- return:          [boolean]       true if a message was removed
function DBB2.api.RemovePreviousMessageFromSameSender(sender, newCategories)
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
      local oldCategories = DBB2.api.CategorizeMessage(msg.message, true)
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
          return true
        end
      end
    end
  end
  
  return false
end

-- [ AddMessage ]
-- Adds a new message to the message store
-- Only stores messages that match at least one category (regardless of enabled state)
-- IMPORTANT: System messages (CHAT_MSG_SYSTEM) are ONLY stored if they match hardcore categories
-- This prevents /who results, loot messages, etc. from appearing in Groups/Professions tabs
-- For Groups and Professions: replaces previous message from same sender in same category
-- 'message'    [string]        the message text
-- 'sender'     [string]        the sender name
-- 'channel'    [string]        the channel name
-- 'type'       [string]        the message type (CHAT_MSG_GUILD, CHAT_MSG_CHANNEL, etc)
function DBB2.api.AddMessage(message, sender, channel, msgType)
  -- Guard against nil message
  if not message then return end
  
  -- Clean up expired messages first
  DBB2.api.RemoveExpiredMessages()
  
  -- Check if message matches any category (ignoring enabled state)
  -- This ensures duplicate filter works for all category patterns
  local categories = DBB2.api.CategorizeMessage(message, true)  -- true = ignoreSelected
  local matchesAnyCategory = (table_getn(categories.groups) > 0) or 
                              (table_getn(categories.professions) > 0) or 
                              (table_getn(categories.hardcore) > 0)
  
  if not matchesAnyCategory then
    return  -- Message doesn't match any category pattern, ignore it
  end
  
  -- CRITICAL: System messages (like /who results) should ONLY be stored if they match
  -- hardcore categories. This prevents zone names in /who results from polluting
  -- the Groups/Professions tabs (e.g., "Zul'Gurub" in a /who result)
  if msgType == "CHAT_MSG_SYSTEM" then
    local matchesHardcore = table_getn(categories.hardcore) > 0
    if not matchesHardcore then
      return  -- System message doesn't match hardcore, ignore it
    end
  end
  
  -- Check blacklist (only for messages that match categories)
  -- Uses DBB2.api.IsMessageBlacklisted from blacklist.lua
  if DBB2.api.IsMessageBlacklisted(message, sender) then
    return
  end
  
  if DBB2.api.IsDuplicateMessage(message, sender) then
    return
  end
  
  -- Remove previous message from same sender in same category (Groups/Professions only)
  -- This ensures only the most recent message per sender is shown
  DBB2.api.RemovePreviousMessageFromSameSender(sender, categories)
  
  -- Check for notifications before storing (only for selected categories)
  -- Uses DBB2.api.CheckAndNotify from notifications.lua
  -- Pass msgType so system messages only trigger hardcore notifications
  DBB2.api.CheckAndNotify(message, sender, msgType)
  
  -- Store message
  table_insert(DBB2.messages, {
    message = message,
    sender = sender or "Unknown",
    channel = channel or "",
    time = time(),
    type = msgType or ""
  })
  
  -- Keep only last MAX_MESSAGES messages
  if table_getn(DBB2.messages) > MAX_MESSAGES then
    table_remove(DBB2.messages, 1)
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
