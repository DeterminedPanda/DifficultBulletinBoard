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
-- 'message'    [string]        formatted chat line (used for fallback parsing)
-- return:      [boolean]       true if this line comes from an enabled source
local function IsEnabledChatSource(message)
  if event == "CHAT_MSG_CHANNEL" then
    local channelName = arg9
    return channelName and DBB2.api.IsChannelWhitelisted and DBB2.api.IsChannelWhitelisted(channelName) or false
  end
  
  if event == "CHAT_MSG_GUILD" then
    return DBB2.api.IsChannelMonitored and DBB2.api.IsChannelMonitored("Guild") or false
  end
  
  if event == "CHAT_MSG_SAY" then
    return DBB2.api.IsChannelMonitored and DBB2.api.IsChannelMonitored("Say") or false
  end
  
  if event == "CHAT_MSG_YELL" then
    return DBB2.api.IsChannelMonitored and DBB2.api.IsChannelMonitored("Yell") or false
  end
  
  if event == "CHAT_MSG_PARTY" then
    return DBB2.api.IsChannelMonitored and DBB2.api.IsChannelMonitored("Party") or false
  end
  
  if event == "CHAT_MSG_WHISPER" then
    return DBB2.api.IsChannelMonitored and DBB2.api.IsChannelMonitored("Whisper") or false
  end
  
  if event == "CHAT_MSG_HARDCORE" then
    return DBB2.api.IsChannelMonitored and DBB2.api.IsChannelMonitored("Hardcore") or false
  end
  
  -- Fallback when the line is not being added during a live chat event.
  return DBB2.api.IsFilterableChannel(message)
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

-- [ ShouldHideFromChat ]
-- Checks if a message should be hidden from normal chat
-- hideFromChat modes: 0 = disabled, 1 = enabled (selected only), 2 = enabled (all categories)
-- Mode 1: Hide messages matching selected categories only
-- Mode 2: Hide messages matching any category (even disabled ones)
-- Also hides blacklisted messages when blacklist.hideFromChat is enabled (independent of hideFromChat mode)
-- Also hides duplicates when hideFromChat is enabled
-- IMPORTANT: Never hides system messages (like /who results) even if they match category patterns
-- IMPORTANT: Only filters messages from sources enabled in the Channels tab
-- IMPORTANT: Never filters the player's own messages
-- IMPORTANT: Category hiding intentionally ignores optional filter tags so broad
-- group/profession tags like "dm" or "mc" can still be suppressed from chat.
function DBB2.api.ShouldHideFromChat(message, sender, matchMessage)
  local mode = DBB2_Config.hideFromChat or 0
  local hideBlacklisted = DBB2.api.IsBlacklistHideFromChatEnabled()
  local textToMatch = matchMessage or message or ""
  
  -- If both hideFromChat and hideBlacklisted are disabled, nothing to filter
  if (mode == 0 or mode == false) and not hideBlacklisted then
    return false
  end
  
  -- CRITICAL: Never filter the player's own messages
  -- This ensures the player always sees what they typed
  if DBB2.api.IsOwnMessage(sender) then
    return false
  end
  
  -- CRITICAL: Only filter messages from sources enabled in the Channels tab
  if not IsEnabledChatSource(message) then
    return false
  end
  
  -- CRITICAL: Never filter system messages, even if they match category patterns
  -- This protects /who results, loot messages, skill ups, etc.
  if DBB2.api.IsSystemMessage(message) then
    return false
  end
  
  -- Check blacklist (hide if blacklist.hideFromChat is enabled, independent of hideFromChat mode)
  if hideBlacklisted and DBB2.api.IsMessageBlacklisted then
    local blocked = DBB2.api.IsMessageBlacklisted(textToMatch, sender)
    if blocked then
      return true
    end
  end
  
  -- If hideFromChat mode is disabled, don't check categories or duplicates
  if mode == 0 or mode == false then
    return false
  end
  
  local ignoreSelected = (mode == 2)  -- Mode 2 ignores selected state
  local matchesCategory = false

  -- Hide-from-chat should be broader than the optional bulletin board filter tag
  -- gate. The GUI/storage path can still require LF/LFG/LFM style tags, but chat
  -- suppression should catch obvious run keywords on their own.
  if DBB2.api.CategorizeMessage then
    local categories = DBB2.api.CategorizeMessage(textToMatch, ignoreSelected, true)
    matchesCategory =
      (categories.groups and categories.groups[1] ~= nil) or
      (categories.professions and categories.professions[1] ~= nil) or
      (categories.hardcore and categories.hardcore[1] ~= nil)
  else
    local categoryTypes = {"groups", "professions", "hardcore"}
    for _, categoryType in ipairs(categoryTypes) do
      local categories = DBB2.api.GetCategories(categoryType)
      if categories then
        for _, cat in ipairs(categories) do
          if DBB2.api.MatchMessageToCategory(textToMatch, cat, ignoreSelected, categoryType, true) then
            matchesCategory = true
            break
          end
        end
      end
      if matchesCategory then break end
    end
  end
  
  -- If message matches a category, also hide duplicates
  -- This ensures duplicate messages are hidden even when the original was hidden
  if matchesCategory then
    return true
  end
  
  -- Also check for duplicates of messages that would match categories
  -- This catches the case where a duplicate comes in after the original was already stored
  -- Extract just the message content (after sender) for duplicate comparison
  if DBB2.api.IsDuplicateMessage then
    if DBB2.api.IsDuplicateMessage(textToMatch, sender) then
      return true
    end
  end
  
  return false
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
          -- Filter runs if hideFromChat is enabled OR hideBlacklistedFromChat is enabled
          local hideFromChatEnabled = DBB2_Config and DBB2_Config.hideFromChat and DBB2_Config.hideFromChat ~= 0
          local hideBlacklistedEnabled = DBB2_Config and DBB2_Config.blacklist and DBB2_Config.blacklist.hideFromChat
          
          if msg and (hideFromChatEnabled or hideBlacklistedEnabled) then
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
            local success, shouldHide = pcall(DBB2.api.ShouldHideFromChat, cleanMsg, sender, msgContent)
            if success and shouldHide then
              return  -- Don't show this message
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
