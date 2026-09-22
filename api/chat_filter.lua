-- DBB2 Chat Filter API
-- Handles chat frame hook system to hide captured messages from normal chat
--
-- Dependencies: api/blacklist.lua (IsMessageBlacklisted, IsBlacklistHideFromChatEnabled)
--               api/categories_api.lua (GetCategories, MatchMessageToCategory)
-- This file must be loaded AFTER blacklist.lua and categories_api.lua

-- Localize frequently used globals for performance
local string_lower = string.lower
local string_find = string.find
local string_gsub = string.gsub
local ipairs = ipairs
local pcall = pcall
local getglobal = getglobal
local pairs = pairs
local tostring = tostring

-- [ ExtractFormattedMessageContent ]
-- Strips the channel/sender wrappers from a rendered chat line so filtering uses
-- the same plain message body that AddMessage receives from chat events.
-- 'message'    [string]        the formatted message from the chat frame
-- return:      [string]        plain message content
-- return:      [string|nil]    extracted sender name, if present
local function ExtractFormattedMessageContent(message)
  if not message then return "", nil end
  
  local content = message
  
  -- Remove a single leading channel block such as "[5. World] ", "[5] ", or "[H] ".
  content = string_gsub(content, "^%[[^%]]+%]%s*", "", 1)
  
  -- Extract "[Sender]: message"
  local _, _, sender, body = string_find(content, "^%[([^%]]+)%]%s*:%s*(.*)$")
  if sender then
    return body or "", sender
  end
  
  -- Fallback for formats like "Sender: message"
  _, _, sender, body = string_find(content, "^([^:]+):%s*(.*)$")
  if sender then
    sender = string_gsub(sender, "^%s*(.-)%s*$", "%1")
    if not string_find(sender, "^%d+$") and sender ~= "H" and sender ~= "" then
      return body or "", sender
    end
  end
  
  return content, nil
end

-- [ IsEnabledChatSource ]
-- Checks whether the current chat event source is one DBB2 is actively watching.
-- This keeps hide-from-chat aligned with the Channels config tab for all enabled
-- source types, not just numbered chat channels.
-- 'message'       [string]        formatted chat line (used for fallback parsing)
-- 'sourceEvent'   [string|nil]    explicit event for read-only simulation
-- 'sourceChannel' [string|nil]    explicit channel for read-only simulation
-- return:      [boolean]       true if this line comes from an enabled source
local function IsEnabledChatSource(message, sourceEvent, sourceChannel)
  local eventName = sourceEvent or event

  if eventName == "CHAT_MSG_CHANNEL" then
    local channelName = sourceChannel or arg9
    return channelName and DBB2.api.IsChannelWhitelisted and DBB2.api.IsChannelWhitelisted(channelName) or false
  end
  
  if eventName == "CHAT_MSG_GUILD" then
    return DBB2.api.IsChannelMonitored and DBB2.api.IsChannelMonitored("Guild") or false
  end
  
  if eventName == "CHAT_MSG_SAY" then
    return DBB2.api.IsChannelMonitored and DBB2.api.IsChannelMonitored("Say") or false
  end
  
  if eventName == "CHAT_MSG_YELL" then
    return DBB2.api.IsChannelMonitored and DBB2.api.IsChannelMonitored("Yell") or false
  end
  
  if eventName == "CHAT_MSG_PARTY" then
    return DBB2.api.IsChannelMonitored and DBB2.api.IsChannelMonitored("Party") or false
  end
  
  if eventName == "CHAT_MSG_WHISPER" then
    return DBB2.api.IsChannelMonitored and DBB2.api.IsChannelMonitored("Whisper") or false
  end
  
  if eventName == "CHAT_MSG_HARDCORE" then
    return DBB2.api.IsChannelMonitored and DBB2.api.IsChannelMonitored("Hardcore") or false
  end
  
  -- Fallback when the line is not being added during a live chat event.
  return DBB2.api.IsFilterableChannel(message)
end

-- Resolves All Chat history scope exclusively from the checkboxes shown under
-- Config > Channels > Available Channels. Whitelist membership and auto-join
-- state do not opt an unchecked source into duplicate history.
local function IsAllChatHistorySourceEnabled(message, sourceEvent, sourceChannel)
  if not DBB2.api.IsChannelCheckboxEnabled then return false, nil end

  local eventName = sourceEvent or event
  local channelName = nil
  if eventName == "CHAT_MSG_CHANNEL" then
    channelName = sourceChannel or arg9
  elseif eventName == "CHAT_MSG_GUILD" then
    channelName = "Guild"
  elseif eventName == "CHAT_MSG_SAY" then
    channelName = "Say"
  elseif eventName == "CHAT_MSG_YELL" then
    channelName = "Yell"
  elseif eventName == "CHAT_MSG_PARTY" then
    channelName = "Party"
  elseif eventName == "CHAT_MSG_WHISPER" then
    channelName = "Whisper"
  elseif eventName == "CHAT_MSG_HARDCORE" then
    channelName = "Hardcore"
  end

  -- Fallback for a rendered line evaluated outside its live CHAT_MSG_* event.
  if not channelName and message then
    local _, _, namedChannel = string_find(message, "^%[%d+%.%s*([^%]]+)%]")
    channelName = namedChannel
    if not channelName then
      local _, _, channelNum = string_find(message, "^%[(%d+)%]")
      if channelNum then
        local _, resolvedName = GetChannelName(tonumber(channelNum))
        channelName = resolvedName
      end
    end
    if not channelName and string_find(string_lower(message), "^%[h%]") then
      channelName = "Hardcore"
    end
  end

  if not channelName then return false, nil end
  local enabled, checkboxName = DBB2.api.IsChannelCheckboxEnabled(channelName)
  return enabled, checkboxName or channelName
end

-- =====================
-- CHAT FILTER DETECTION
-- =====================

-- [ IsSystemMessage ]
-- Detects if a message is a WoW system message that should never be filtered
-- System messages include: /who results, combat log, loot, experience, etc.
-- 'message'    [string]        the message text (may include color codes)
-- return:      [boolean]       true if this is a system message
function DBB2.api.IsSystemMessage(message)
  if not message then return false end
  
  -- /who results format: "[Name]: Level XX Race Class <Guild> - Zone"
  -- The key identifier is the format with Level + Race + Class pattern
  -- Example: "[Hexbear]: Level 60 Night Elf Druid <Phoenix Rising> - Ahn'Qiraj"
  
  -- Check for /who result pattern: "Level [number] [race] [class]"
  -- This pattern is unique to /who results and won't match normal chat
  if string_find(message, "Level %d+ %a+ %a+") then
    return true
  end
  
  -- Also check for the "X player(s) total" message that accompanies /who
  if string_find(message, "%d+ players? total") then
    return true
  end
  
  -- Check for common system message patterns that might accidentally match categories
  -- These are WoW system messages, not player chat
  
  -- Loot messages: "You receive loot: [Item]"
  if string_find(message, "^You receive") then
    return true
  end
  
  -- Experience messages: "You gain X experience"
  if string_find(message, "^You gain %d+ experience") then
    return true
  end
  
  -- Reputation messages: "Your reputation with X has increased"
  if string_find(message, "^Your reputation") then
    return true
  end
  
  -- Skill up messages: "Your skill in X has increased to Y"
  if string_find(message, "^Your skill in") then
    return true
  end
  
  -- Discovery messages: "Discovered: Zone"
  if string_find(message, "^Discovered:") then
    return true
  end
  
  -- Quest messages
  if string_find(message, "^Quest ") or string_find(message, " completed%.$") then
    return true
  end
  
  return false
end

-- [ IsFilterableChannel ]
-- Checks if a formatted chat message is from a channel that should be filtered
-- Filterable channels: addon-whitelisted chat channels such as World, General,
-- LookingForGroup, Trade, Hardcore, and custom channels the addon monitors.
-- Custom channel format: "[X] [PlayerName]: message" (X = channel number only)
-- Built-in channel format: "[X. ChannelName] [PlayerName]: message" (number + dot + name)
-- Trade can also be "[2. Trade - City]" format
-- Hardcore channel format: "[H] [PlayerName]: message"
-- Uses the channel whitelist so chat hiding matches what DBB2 actually captures
-- from CHAT_MSG_CHANNEL.
-- 'message'    [string]        the formatted message from chat frame
-- return:      [boolean]       true if from a filterable channel
function DBB2.api.IsFilterableChannel(message)
  if not message then return false end
  
  local lowerMsg = string_lower(message)
  
  -- Check for Hardcore channel: "[H] " prefix (Turtle WoW specific)
  if string_find(lowerMsg, "^%[h%]") then
    return true
  end
  
  -- Check built-in channel format: "[X. ChannelName]"
  local _, _, namedChannel = string_find(message, "^%[%d+%.%s*([^%]]+)%]")
  if namedChannel then
    if DBB2.api.IsChannelWhitelisted and DBB2.api.IsChannelWhitelisted(namedChannel) then
      return true
    end
  end
  
  -- Check for custom channel format: "[5]" at the start (number only, no dot)
  -- This format is used by custom channels on private servers and also covers
  -- chat frames that render only the channel number.
  local _, _, channelNum = string_find(message, "^%[(%d+)%]")
  if channelNum then
    -- GetChannelName returns: id, name (we need the second return value)
    local _, channelName = GetChannelName(tonumber(channelNum))
    if channelName and DBB2.api.IsChannelWhitelisted and DBB2.api.IsChannelWhitelisted(channelName) then
      return true
    end
  end
  
  return false
end

-- [ IsOwnMessage ]
-- Checks if a message was sent by the player themselves
-- 'sender'     [string]        the sender name extracted from the message
-- return:      [boolean]       true if the sender is the player
function DBB2.api.IsOwnMessage(sender)
  if not sender then return false end
  
  -- Get the player's name
  local playerName = UnitName("player")
  if not playerName then return false end
  
  -- Compare case-insensitively
  return string_lower(sender) == string_lower(playerName)
end

-- All Chat duplicate history is deliberately separate from DBB2.messages.
-- Ordinary conversation must never enter the bulletin-board store. History is
-- session-only and records accepted copies, preserving the existing behavior
-- where rejected repetitions do not extend the cooldown indefinitely.
DBB2._allChatDuplicateHistory = DBB2._allChatDuplicateHistory or {}
DBB2._allChatDuplicateDeliveries = DBB2._allChatDuplicateDeliveries or {}
DBB2._allChatDuplicateLastCleanup = DBB2._allChatDuplicateLastCleanup or 0
DBB2._allChatDuplicateHistoryCount = DBB2._allChatDuplicateHistoryCount or 0
DBB2._allChatDuplicateHistoryPeak = DBB2._allChatDuplicateHistoryPeak or DBB2._allChatDuplicateHistoryCount

local function NormalizeAllChatDuplicatePart(value)
  local normalized = value or ""
  if DBB2.api.StripHyperlinks then
    normalized = DBB2.api.StripHyperlinks(normalized)
  else
    normalized = string_gsub(normalized, "|c%x%x%x%x%x%x%x%x", "")
    normalized = string_gsub(normalized, "|r", "")
    normalized = string_gsub(normalized, "|H[^|]*|h([^|]*)|h", "%1")
  end
  return string_lower(normalized)
end

local function CleanupAllChatDuplicateHistory(now, spamSeconds)
  if now - DBB2._allChatDuplicateLastCleanup < 10 then return end
  DBB2._allChatDuplicateLastCleanup = now

  local removed = 0
  for key, seenAt in pairs(DBB2._allChatDuplicateHistory) do
    if now - seenAt > spamSeconds then
      DBB2._allChatDuplicateHistory[key] = nil
      DBB2._allChatDuplicateHistoryCount = math.max(0, DBB2._allChatDuplicateHistoryCount - 1)
      removed = removed + 1
    end
  end
  for key, delivery in pairs(DBB2._allChatDuplicateDeliveries) do
    if not delivery or now - (delivery.time or 0) > 0.25 then
      DBB2._allChatDuplicateDeliveries[key] = nil
    end
  end

  if removed > 0 and DBB2.debug.enabled and not DBB2.debug.paused then
    DBB2.api.DebugCount("duplicates.chatHistoryPruned", removed)
  end
end

-- Returns whether this is a repeated All Chat delivery plus its age. WoW may
-- render one delivery into several chat frames, so a very short per-frame cache
-- shares the first decision without treating the message as its own duplicate.
function DBB2.api.IsAllChatDuplicate(message, sender, frameIndex, readOnly)
  if not message or not sender or sender == "" then return false, nil, "missing-sender" end

  local duplicateMode = DBB2_Config.duplicateFilterMode
  if duplicateMode ~= 2 then return false, nil, "mode-not-all-chat" end

  local spamSeconds = DBB2_Config.spamFilterSeconds or 150
  if spamSeconds <= 0 then return false, nil, "window-disabled" end

  local now = GetTime()
  local key = NormalizeAllChatDuplicatePart(sender) .. "\031" .. NormalizeAllChatDuplicatePart(message)

  if not readOnly and frameIndex then
    local delivery = DBB2._allChatDuplicateDeliveries[key]
    if delivery and now - delivery.time <= 0.10 and not delivery.frames[frameIndex] then
      delivery.frames[frameIndex] = true
      return delivery.duplicate, delivery.age, "coalesced-render"
    end
  end

  if not readOnly then CleanupAllChatDuplicateHistory(now, spamSeconds) end
  local seenAt = DBB2._allChatDuplicateHistory[key]
  local age = seenAt and (now - seenAt) or nil
  local duplicate = age and age <= spamSeconds or false

  if not readOnly then
    if not duplicate then
      if not seenAt then
        DBB2._allChatDuplicateHistoryCount = DBB2._allChatDuplicateHistoryCount + 1
        if DBB2._allChatDuplicateHistoryCount > DBB2._allChatDuplicateHistoryPeak then
          DBB2._allChatDuplicateHistoryPeak = DBB2._allChatDuplicateHistoryCount
        end
      end
      DBB2._allChatDuplicateHistory[key] = now
    end
    if frameIndex then
      DBB2._allChatDuplicateDeliveries[key] = {
        time = now,
        frames = { [frameIndex] = true },
        duplicate = duplicate,
        age = age
      }
    end

    if DBB2.debug.enabled and not DBB2.debug.paused then
      if duplicate then
        DBB2.api.DebugCount("duplicates.chatRejected", 1)
      else
        DBB2.api.DebugCount("duplicates.chatTracked", 1)
      end
    end
  end

  return duplicate, age, duplicate and "history-match" or "history-recorded"
end

function DBB2.api.ClearAllChatDuplicateHistory()
  DBB2._allChatDuplicateHistory = {}
  DBB2._allChatDuplicateDeliveries = {}
  DBB2._allChatDuplicateLastCleanup = GetTime()
  DBB2._allChatDuplicateHistoryCount = 0
end

function DBB2.api.GetAllChatDuplicateHistoryStats()
  return DBB2._allChatDuplicateHistoryCount or 0, DBB2._allChatDuplicateHistoryPeak or 0
end

-- [ ShouldHideFromChat ]
-- Checks if a message should be hidden from normal chat
-- hideFromChat modes: 0 = disabled, 1 = filtered, 2 = all
-- Mode 1: Hide selected category matches that pass the optional Filter Tags
-- Mode 2: Hide messages matching any category (even disabled ones)
-- Also hides blacklisted messages when blacklist.hideFromChat is enabled (independent of hideFromChat mode)
-- All Chat duplicate mode independently hides repeated eligible player chat
-- IMPORTANT: Never hides system messages (like /who results) even if they match category patterns
-- IMPORTANT: Only filters messages from sources enabled in the Channels tab
-- IMPORTANT: Never filters the player's own messages
-- IMPORTANT: Filtered follows selected categories and Filter Tags; All ignores
-- both restrictions so broad tags like "dm" or "mc" can still be suppressed.
function DBB2.api.ShouldHideFromChat(message, sender, matchMessage, sourceEvent, sourceChannel, frameIndex, duplicateReadOnly)
  local mode = DBB2_Config.hideFromChat or 0
  local duplicateMode = DBB2_Config.duplicateFilterMode
  if duplicateMode == nil then duplicateMode = 1 end
  local hideBlacklisted = DBB2.api.IsBlacklistHideFromChatEnabled()
  local textToMatch = matchMessage or message or ""
  local allChatHistoryDetail = nil
  local allChatHistoryTracked = false
  
  -- All Chat duplicate filtering is independent from category chat hiding.
  if (mode == 0 or mode == false) and duplicateMode ~= 2 and not hideBlacklisted then
    return false, "chat hiding and blacklist hiding disabled"
  end
  
  -- CRITICAL: Never filter the player's own messages
  -- This ensures the player always sees what they typed
  if DBB2.api.IsOwnMessage(sender) then
    return false, "player's own message"
  end
  
  -- CRITICAL: Only filter messages from sources enabled in the Channels tab
  if not IsEnabledChatSource(message, sourceEvent, sourceChannel) then
    return false, "source not monitored"
  end
  
  -- CRITICAL: Never filter system messages, even if they match category patterns
  -- This protects /who results, loot messages, skill ups, etc.
  if sourceEvent == "CHAT_MSG_SYSTEM" or DBB2.api.IsSystemMessage(message) then
    return false, "protected system message"
  end
  
  -- Check blacklist (hide if blacklist.hideFromChat is enabled, independent of hideFromChat mode)
  if hideBlacklisted and DBB2.api.IsMessageBlacklisted then
    local blocked = DBB2.api.IsMessageBlacklisted(textToMatch, sender)
    if blocked then
      return true, "blacklist"
    end
  end

  -- In All Chat mode, every eligible player line participates even when it is
  -- unrelated to a bulletin-board category. This check follows safety/source
  -- gates and blacklist handling but precedes the independent category mode.
  if duplicateMode == 2 and DBB2.api.IsAllChatDuplicate then
    local historySourceEnabled, historySource = IsAllChatHistorySourceEnabled(message, sourceEvent, sourceChannel)
    if historySourceEnabled then
      allChatHistoryTracked = true
      local duplicate, duplicateAge, duplicateHistoryRule = DBB2.api.IsAllChatDuplicate(textToMatch, sender, frameIndex, duplicateReadOnly)
      local duplicateAgeText = duplicateAge and (tostring(duplicateAge) .. "s") or "none"
      allChatHistoryDetail =
        "duplicateHistory=" .. tostring(duplicateHistoryRule or "unknown") ..
        " sourceCheckbox=" .. tostring(historySource or "unknown") ..
        " age=" .. duplicateAgeText ..
        " window=" .. tostring(DBB2_Config.spamFilterSeconds or 150) .. "s"
      if duplicate then
        return true, "duplicate; mode=all-chat",
          allChatHistoryDetail
      end
    else
      allChatHistoryDetail =
        "duplicateHistory=bypassed-unchecked-source" ..
        " sourceCheckbox=" .. tostring(historySource or "none")
      if not duplicateReadOnly and DBB2.debug.enabled and not DBB2.debug.paused then
        DBB2.api.DebugCount("duplicates.chatBypassedUncheckedSourceRenders", 1)
      end
    end
  end
  
  -- If category hiding is disabled, the independent All Chat decision above is
  -- still applied; only category-based hiding stops here.
  if mode == 0 or mode == false then
    local reason = "category hiding disabled"
    if duplicateMode == 2 then
      reason = allChatHistoryTracked and "category hiding disabled; all-chat history recorded" or "category hiding disabled; all-chat source unchecked"
    end
    return false, reason, allChatHistoryDetail
  end

  -- Unsorted messages have no selected category, so Filtered keeps them in
  -- chat while All hides them like any other message captured by the addon.
  -- Depending on frame/event ordering, the message may already be stored.
  if DBB2.api.IsStoredUnsortedMessage and DBB2.api.IsStoredUnsortedMessage(textToMatch, sender) then
    return mode == 2, mode == 2 and "stored unsorted; mode=all" or "stored unsorted; mode=filtered", allChatHistoryDetail
  end

  -- Also recognize a first-time unsorted candidate directly. This covers both
  -- possible event orders: chat rendering before storage and storage before
  -- chat rendering.
  if DBB2_Config.showUnsortedMessagesInLogs and DBB2.api.CategorizeMessage and DBB2.api.MatchUnsortedFilterTags then
    local baseCategories = DBB2.api.CategorizeMessage(textToMatch, true, true)
    local matchesKnownCategory =
      (baseCategories.groups and baseCategories.groups[1] ~= nil) or
      (baseCategories.professions and baseCategories.professions[1] ~= nil) or
      (baseCategories.hardcore and baseCategories.hardcore[1] ~= nil)

    if not matchesKnownCategory and DBB2.api.MatchUnsortedFilterTags(textToMatch) then
      return mode == 2, mode == 2 and "unsorted candidate; mode=all" or "unsorted candidate; mode=filtered", allChatHistoryDetail
    end
  end
  
  local ignoreSelected = (mode == 2)  -- All ignores selected state
  local matchesCategory = false
  local categoryMatchMissingFilter = false

  -- Start from category matches without the storage filter gate. Filtered then
  -- requires the configured tag list even when that list is disabled for normal
  -- bulletin-board storage. All deliberately catches category words alone.
  if DBB2.api.CategorizeMessage then
    local categories = DBB2.api.CategorizeMessage(textToMatch, ignoreSelected, true)
    local matchesGroup = categories.groups and categories.groups[1] ~= nil
    local matchesProfession = categories.professions and categories.professions[1] ~= nil
    local matchesHardcore = categories.hardcore and categories.hardcore[1] ~= nil

    if mode == 2 then
      matchesCategory = matchesGroup or matchesProfession or matchesHardcore
    else
      local groupQualified = matchesGroup and DBB2.api.MatchConfiguredFilterTags and DBB2.api.MatchConfiguredFilterTags(textToMatch, "groups")
      local professionQualified = matchesProfession and DBB2.api.MatchConfiguredFilterTags and DBB2.api.MatchConfiguredFilterTags(textToMatch, "professions")
      matchesCategory = groupQualified or professionQualified or matchesHardcore
      categoryMatchMissingFilter = (matchesGroup or matchesProfession) and not matchesCategory
    end
  else
    local categoryTypes = {"groups", "professions", "hardcore"}
    for _, categoryType in ipairs(categoryTypes) do
      local categories = DBB2.api.GetCategories(categoryType)
      if categories then
        for _, cat in ipairs(categories) do
          if DBB2.api.MatchMessageToCategory(textToMatch, cat, ignoreSelected, categoryType, true) then
            if mode == 2 or categoryType == "hardcore" then
              matchesCategory = true
            elseif DBB2.api.MatchConfiguredFilterTags and DBB2.api.MatchConfiguredFilterTags(textToMatch, categoryType) then
              matchesCategory = true
            else
              categoryMatchMissingFilter = true
            end
            if matchesCategory then break end
          end
        end
      end
      if matchesCategory then break end
    end
  end
  
  -- If message matches a category, also hide duplicates
  -- This ensures duplicate messages are hidden even when the original was hidden
  if matchesCategory then
    return true, "category match", allChatHistoryDetail
  end

  -- A selected category word alone is intentionally insufficient in Filtered.
  -- Return before the broad duplicate fallback so a stored conversational false
  -- positive cannot become hidden merely because it was seen before.
  if mode == 1 and categoryMatchMissingFilter then
    return false, "category match missing configured Filter Tag; mode=filtered", allChatHistoryDetail
  end

  if mode == 1 then
    return false, "no selected category with configured Filter Tag; mode=filtered", allChatHistoryDetail
  end

  -- All also suppresses a stored duplicate when no current category remains.
  -- Extract just the message content (after sender) for duplicate comparison
  if DBB2.api.IsDuplicateMessage then
    if DBB2.api.IsDuplicateMessage(textToMatch, sender) then
      return true, "duplicate", allChatHistoryDetail
    end
  end
  
  return false, "no hide rule matched", allChatHistoryDetail
end

-- =====================
-- CHAT FRAME HOOKS
-- =====================

-- Track which chat frames we've hooked (by frame index)
-- Using a table since we can't add properties to functions in Lua 5.0
DBB2._hookedChatFrames = DBB2._hookedChatFrames or {}

-- [ SetupChatFilter ]
-- Hooks into chat frames to filter captured messages
-- Uses tracking table to prevent double-hooking on addon reload
function DBB2.api.SetupChatFilter()
  -- Store original AddMessage functions (only if not already stored)
  if not DBB2.originalAddMessage then
    DBB2.originalAddMessage = {}
  end
  
  -- Hook all chat frames
  for i = 1, NUM_CHAT_WINDOWS do
    local chatFrame = getglobal("ChatFrame" .. i)
    if chatFrame and chatFrame.AddMessage then
      if DBB2._hookedChatFrames[i] then
        -- Already hooked, skip
      else
        -- Store original function
        local originalFunc = chatFrame.AddMessage
        DBB2.originalAddMessage[i] = originalFunc
        
        -- Mark as hooked
        DBB2._hookedChatFrames[i] = true
        
        -- Create our hook function
        -- Use closure to capture the frame index
        local frameIndex = i
        chatFrame.AddMessage = function(self, msg, r, g, b, id)
          -- Safety check: ensure we have a valid original to call
          local origToCall = DBB2.originalAddMessage[frameIndex]
          if not origToCall then
            return
          end
          
          -- Check if this message should be filtered
          -- Filter runs for category hiding, blacklist hiding, or independent
          -- All Chat duplicate suppression.
          local hideFromChatEnabled = DBB2_Config and DBB2_Config.hideFromChat and DBB2_Config.hideFromChat ~= 0
          local hideBlacklistedEnabled = DBB2_Config and DBB2_Config.blacklist and DBB2_Config.blacklist.hideFromChat
          local hideDuplicateEnabled = DBB2_Config and DBB2_Config.duplicateFilterMode == 2
          
          if msg and (hideFromChatEnabled or hideBlacklistedEnabled or hideDuplicateEnabled) then
            -- Normalize the formatted chat line into the same plain message body
            -- used by CHAT_MSG_* events before applying blacklist/category checks.
            local cleanMsg = msg
            -- Remove color codes |cXXXXXXXX and |r
            cleanMsg = string_gsub(cleanMsg, "|c%x%x%x%x%x%x%x%x", "")
            cleanMsg = string_gsub(cleanMsg, "|r", "")
            -- Remove hyperlinks |H[player:NAME]|h[NAME]|h -> NAME
            cleanMsg = string_gsub(cleanMsg, "|H[^|]*|h([^|]*)|h", "%1")
            
            local msgContent, extractedSender = ExtractFormattedMessageContent(cleanMsg)
            
            -- Try to extract sender name from message format
            -- World format: "[5] [Sender]: message" (number = channel)
            -- Hardcore format: "[H] [Sender]: message"
            -- Guild format: "[Sender]: message"
            local sender = nil
            
            sender = extractedSender
            
            -- Wrap in pcall to prevent errors from breaking chat
            local debugging = DBB2.debug.enabled and not DBB2.debug.paused
            local started = nil
            if debugging then started = DBB2.api.DebugClock() end
            local success, shouldHide, hideReason, hideDetails = pcall(DBB2.api.ShouldHideFromChat, cleanMsg, sender, msgContent, nil, nil, frameIndex, false)
            local elapsed = nil
            if debugging then
              elapsed = DBB2.api.DebugClock() - started
              -- Unmonitored renders include combat-log traffic and other lines
              -- that cannot affect DBB. Do not let them dirty/refill the
              -- diagnostic console or skew filter timing statistics.
              if not (success and not shouldHide and hideReason == "source not monitored") then
                DBB2.api.DebugPerf("ShouldHideFromChat", elapsed)
              end
            end
            if success and shouldHide then
              if debugging then
                DBB2.api.DebugCount("chat.hiddenRenders", 1)
                DBB2.api.DebugChatLifecycle(msgContent, sender, true, hideReason, frameIndex, hideDetails)
                DBB2.api.DebugCount("chat.hidden", 1)
              end
              return  -- Don't show this message
            elseif success and debugging then
              if hideReason == "source not monitored" then
                -- Keep one aggregate signal without allocating a lifecycle or
                -- one trace per combat/system render. Silent counting also
                -- avoids waking the visible diagnostic console every line.
                DBB2.api.DebugCountSilent("chat.ignoredUnmonitoredRenders", 1)
                if hideDuplicateEnabled then
                  DBB2.api.DebugCountSilent("duplicates.chatBypassedUncheckedSourceRenders", 1)
                end
              else
                DBB2.api.DebugCount("chat.visibleRenders", 1)
                DBB2.api.DebugChatLifecycle(msgContent, sender, false, hideReason, frameIndex, hideDetails)
                DBB2.api.DebugCount("chat.visible", 1)
              end
            elseif not success and debugging then
              DBB2.api.DebugCount("chat.filterErrors", 1)
              DBB2.api.DebugTrace(4, "chat", "filter-error", "frame=ChatFrame" .. frameIndex .. " error=" .. tostring(shouldHide or "unknown error"), elapsed)
            end
          elseif msg and DBB2.debug.enabled and not DBB2.debug.paused then
            -- Keep lifecycle correlation complete even when filtering is off.
            -- This is diagnostic-only and does not alter the chat line.
            local cleanMsg = string_gsub(msg, "|c%x%x%x%x%x%x%x%x", "")
            cleanMsg = string_gsub(cleanMsg, "|r", "")
            cleanMsg = string_gsub(cleanMsg, "|H[^|]*|h([^|]*)|h", "%1")
            local msgContent, sender = ExtractFormattedMessageContent(cleanMsg)
            if IsEnabledChatSource(cleanMsg) then
              DBB2.api.DebugCount("chat.visibleRenders", 1)
              DBB2.api.DebugChatLifecycle(msgContent, sender, false, "filter-disabled", frameIndex)
              DBB2.api.DebugCount("chat.visible", 1)
            else
              DBB2.api.DebugCountSilent("chat.ignoredUnmonitoredRenders", 1)
            end
          end
          
          -- Call original function
          origToCall(self, msg, r, g, b, id)
        end
      end
    end
  end
end

-- [ RemoveChatFilter ]
-- Removes our chat hooks and restores original functions
-- Call this if you need to cleanly disable the filter
function DBB2.api.RemoveChatFilter()
  if not DBB2.originalAddMessage then return end
  
  for i = 1, NUM_CHAT_WINDOWS do
    local chatFrame = getglobal("ChatFrame" .. i)
    if chatFrame and DBB2.originalAddMessage[i] and DBB2._hookedChatFrames[i] then
      chatFrame.AddMessage = DBB2.originalAddMessage[i]
      DBB2._hookedChatFrames[i] = nil
    end
  end
  
  -- Clear stored references
  DBB2.originalAddMessage = nil
end
