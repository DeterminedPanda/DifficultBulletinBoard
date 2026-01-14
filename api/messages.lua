-- DBB2 Message API
-- Handles message capturing, storage, and filtering logic

-- Localize frequently used globals for performance
local string_lower = string.lower
local string_find = string.find
local string_sub = string.sub
local string_len = string.len
local string_gsub = string.gsub
local table_insert = table.insert
local table_remove = table.remove
local table_getn = table.getn
local time = time
local ipairs = ipairs
local pairs = pairs
local pcall = pcall

-- Constants
local MAX_MESSAGES = 100

-- =====================
-- CHAT FILTER HOOK
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
-- Filterable channels: World, Hardcore, Trade
-- World/Trade channel format: "[X] [PlayerName]: message" (X = channel number)
-- Hardcore channel format: "[H] [PlayerName]: message"
-- Uses GetChannelName API to resolve channel number to name
-- 'message'    [string]        the formatted message from chat frame
-- return:      [boolean]       true if from a filterable channel
function DBB2.api.IsFilterableChannel(message)
  if not message then return false end
  
  local lowerMsg = string_lower(message)
  
  -- Check for Hardcore channel: "[H] " prefix (Turtle WoW specific)
  if string_find(lowerMsg, "^%[h%]") then
    return true
  end
  
  -- Check for channel number format: "[5] " at the start
  -- Extract the channel number and use GetChannelName to get actual name
  local _, _, channelNum = string_find(message, "^%[(%d+)%]")
  if channelNum then
    -- GetChannelName returns: id, name (we need the second return value)
    local _, channelName = GetChannelName(tonumber(channelNum))
    if channelName then
      local lowerChannel = string_lower(channelName)
      -- Filter World, Hardcore, and Trade channels
      if lowerChannel == "world" or lowerChannel == "hardcore" or lowerChannel == "trade" then
        return true
      end
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
-- Also hides blacklisted messages and duplicates when enabled
-- IMPORTANT: Never hides system messages (like /who results) even if they match category patterns
-- IMPORTANT: Only filters messages from World, Hardcore, or Trade channels
-- IMPORTANT: Never filters the player's own messages
function DBB2.api.ShouldHideFromChat(message, sender)
  local mode = DBB2_Config.hideFromChat or 0
  if mode == 0 or mode == false then
    return false
  end
  
  -- CRITICAL: Never filter the player's own messages
  -- This ensures the player always sees what they typed
  if DBB2.api.IsOwnMessage(sender) then
    return false
  end
  
  -- CRITICAL: Only filter messages from filterable channels (World, Hardcore, Trade)
  -- Guild chat, party chat, whispers, etc. should never be filtered
  if not DBB2.api.IsFilterableChannel(message) then
    return false
  end
  
  -- CRITICAL: Never filter system messages, even if they match category patterns
  -- This protects /who results, loot messages, skill ups, etc.
  if DBB2.api.IsSystemMessage(message) then
    return false
  end
  
  -- Check blacklist first (always hide blacklisted when hideFromChat is enabled)
  if DBB2.api.IsMessageBlacklisted then
    local blocked = DBB2.api.IsMessageBlacklisted(message, sender)
    if blocked then
      return true
    end
  end
  
  -- Check if message matches categories
  local categoryTypes = {"groups", "professions", "hardcore"}
  local ignoreSelected = (mode == 2)  -- Mode 2 ignores selected state
  local matchesCategory = false
  
  for _, categoryType in ipairs(categoryTypes) do
    local categories = DBB2.api.GetCategories(categoryType)
    if categories then
      for _, cat in ipairs(categories) do
        if DBB2.api.MatchMessageToCategory(message, cat, ignoreSelected) then
          matchesCategory = true
          break
        end
      end
    end
    if matchesCategory then break end
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
    local msgContent = message
    -- Remove channel prefix like "[5. World] " or "5. World "
    msgContent = string_gsub(msgContent, "^%[?%d+%.%s*%w+%]?%s*", "")
    -- Remove sender prefix like "[Mam]: " or "Mam: "
    msgContent = string_gsub(msgContent, "^%[?[^%]:]+%]?:%s*", "")
    
    -- Use skipLog=true to avoid double-logging (AddMessage will log it)
    if DBB2.api.IsDuplicateMessage(msgContent, sender, true) then
      return true
    end
  end
  
  return false
end

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
          if msg and DBB2_Config and DBB2_Config.hideFromChat and DBB2_Config.hideFromChat ~= 0 then
            -- Extract the actual message text (remove color codes and sender info for matching)
            local cleanMsg = msg
            -- Remove color codes |cXXXXXXXX and |r
            cleanMsg = string_gsub(cleanMsg, "|c%x%x%x%x%x%x%x%x", "")
            cleanMsg = string_gsub(cleanMsg, "|r", "")
            -- Remove hyperlinks |H[player:NAME]|h[NAME]|h -> NAME
            cleanMsg = string_gsub(cleanMsg, "|H[^|]*|h([^|]*)|h", "%1")
            
            -- Try to extract sender name from message format
            -- World format: "[5] [Sender]: message" (number = channel)
            -- Hardcore format: "[H] [Sender]: message"
            -- Guild format: "[Sender]: message"
            local sender = nil
            
            -- First try to match channel + sender format: [Channel/Number] [Sender]:
            -- This handles "[5] [Name]:" and "[H] [Name]:"
            local _, _, extractedSender = string_find(cleanMsg, "^%[[^%]]+%]%s*%[([^%]]+)%]%s*:")
            if extractedSender then
              sender = extractedSender
            else
              -- Try simple [Sender]: format (guild chat, etc.)
              _, _, extractedSender = string_find(cleanMsg, "^%[([^%]]+)%]%s*:")
              if extractedSender then
                -- Make sure we didn't grab a channel number like "5" or "H"
                if not string_find(extractedSender, "^%d+$") and extractedSender ~= "H" then
                  sender = extractedSender
                end
              end
            end
            
            -- Wrap in pcall to prevent errors from breaking chat
            local success, shouldHide = pcall(DBB2.api.ShouldHideFromChat, cleanMsg, sender)
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

-- =====================
-- BLACKLIST API
-- =====================

-- [ InitBlacklist ]
-- Initializes blacklist config if not present
function DBB2.api.InitBlacklist()
  if not DBB2_Config.blacklist then
    DBB2_Config.blacklist = {
      enabled = true,
      players = {},
      keywords = {"[\\[(][a-z][a-z]?[a-z]?[\\])]", "recruit(ing)?", "<.*>"}
    }
  end
  -- Ensure all fields exist
  if DBB2_Config.blacklist.enabled == nil then
    DBB2_Config.blacklist.enabled = false
  end
  if not DBB2_Config.blacklist.players then
    DBB2_Config.blacklist.players = {}
  end
  if not DBB2_Config.blacklist.keywords then
    DBB2_Config.blacklist.keywords = {"[\\[(][a-z][a-z]?[a-z]?[\\])]", "recruit(ing)?", "<.*>"}
  end
end

-- [ IsBlacklistEnabled ]
-- Returns whether blacklist filtering is enabled
function DBB2.api.IsBlacklistEnabled()
  DBB2.api.InitBlacklist()
  return DBB2_Config.blacklist.enabled
end

-- [ SetBlacklistEnabled ]
-- Enables or disables blacklist filtering
function DBB2.api.SetBlacklistEnabled(enabled)
  DBB2.api.InitBlacklist()
  DBB2_Config.blacklist.enabled = enabled
end

-- [ AddPlayerToBlacklist ]
-- Adds a player name to the blacklist
function DBB2.api.AddPlayerToBlacklist(playerName)
  DBB2.api.InitBlacklist()
  if not playerName or playerName == "" then return false end
  
  local lowerName = string_lower(playerName)
  -- Check if already exists
  for _, name in ipairs(DBB2_Config.blacklist.players) do
    if string_lower(name) == lowerName then
      return false
    end
  end
  
  table_insert(DBB2_Config.blacklist.players, playerName)
  return true
end

-- [ RemovePlayerFromBlacklist ]
-- Removes a player name from the blacklist
function DBB2.api.RemovePlayerFromBlacklist(playerName)
  DBB2.api.InitBlacklist()
  local lowerName = string_lower(playerName or "")
  
  for i = table_getn(DBB2_Config.blacklist.players), 1, -1 do
    if string_lower(DBB2_Config.blacklist.players[i]) == lowerName then
      table_remove(DBB2_Config.blacklist.players, i)
      return true
    end
  end
  return false
end

-- [ IsPlayerBlacklisted ]
-- Checks if a player is blacklisted
function DBB2.api.IsPlayerBlacklisted(playerName)
  DBB2.api.InitBlacklist()
  if not DBB2_Config.blacklist.enabled then return false end
  
  local lowerName = string_lower(playerName or "")
  for _, name in ipairs(DBB2_Config.blacklist.players) do
    if string_lower(name) == lowerName then
      return true
    end
  end
  return false
end

-- [ AddKeywordToBlacklist ]
-- Adds a keyword to the blacklist
function DBB2.api.AddKeywordToBlacklist(keyword)
  DBB2.api.InitBlacklist()
  if not keyword or keyword == "" then return false end
  
  local lowerKeyword = string_lower(keyword)
  -- Check if already exists
  for _, kw in ipairs(DBB2_Config.blacklist.keywords) do
    if string_lower(kw) == lowerKeyword then
      return false
    end
  end
  
  table_insert(DBB2_Config.blacklist.keywords, keyword)
  return true
end

-- [ RemoveKeywordFromBlacklist ]
-- Removes a keyword from the blacklist
function DBB2.api.RemoveKeywordFromBlacklist(keyword)
  DBB2.api.InitBlacklist()
  local lowerKeyword = string_lower(keyword or "")
  
  for i = table_getn(DBB2_Config.blacklist.keywords), 1, -1 do
    if string_lower(DBB2_Config.blacklist.keywords[i]) == lowerKeyword then
      table_remove(DBB2_Config.blacklist.keywords, i)
      return true
    end
  end
  return false
end

-- [ WildcardToPattern ]
-- Converts a simple wildcard pattern to a Lua pattern
-- Supports: ? = single character, * = any characters (including none)
-- 'wildcard'   [string]        the wildcard pattern
-- return:      [string]        Lua pattern string
function DBB2.api.WildcardToPattern(wildcard)
  if not wildcard then return "" end
  
  -- Escape Lua pattern special characters (except ? and * which we handle)
  local pattern = wildcard
  pattern = string_gsub(pattern, "%%", "%%%%")
  pattern = string_gsub(pattern, "%^", "%%^")
  pattern = string_gsub(pattern, "%$", "%%$")
  pattern = string_gsub(pattern, "%(", "%%(")
  pattern = string_gsub(pattern, "%)", "%%)")
  pattern = string_gsub(pattern, "%.", "%%.")
  pattern = string_gsub(pattern, "%[", "%%[")
  pattern = string_gsub(pattern, "%]", "%%]")
  pattern = string_gsub(pattern, "%+", "%%+")
  pattern = string_gsub(pattern, "%-", "%%-")
  
  -- Convert wildcards: ? -> single char (any), * -> any chars (including spaces)
  pattern = string_gsub(pattern, "%*", ".*")
  pattern = string_gsub(pattern, "%?", ".")
  
  return pattern
end

-- [ MatchWildcard ]
-- Checks if text matches a wildcard pattern
-- 'text'       [string]        the text to check
-- 'wildcard'   [string]        the wildcard pattern (supports ? and *)
-- return:      [boolean]       true if matches
function DBB2.api.MatchWildcard(text, wildcard)
  if not text or not wildcard then return false end
  
  -- If no wildcards, do plain text search (faster)
  if not string_find(wildcard, "[%?%*]") then
    return string_find(text, wildcard, 1, true) ~= nil
  end
  
  local pattern = DBB2.api.WildcardToPattern(wildcard)
  return string_find(text, pattern) ~= nil
end

-- [ IsKeywordRegexPattern ]
-- Checks if a keyword contains regex special characters (meaning it's a regex pattern)
-- Plain keywords get word boundary treatment, regex patterns are used as-is
-- 'keyword'    [string]        the keyword to check
-- return:      [boolean]       true if keyword contains regex syntax
function DBB2.api.IsKeywordRegexPattern(keyword)
  if not keyword then return false end
  -- Check for common regex metacharacters that indicate intentional regex usage
  -- These are: . * + ? [ ] ( ) | ^ $ \ < >
  -- Note: We check for patterns that are unlikely in plain text
  if string_find(keyword, "[%[%]%(%)%|%^%$\\<>]") then
    return true
  end
  -- Check for .* .+ .? which are common regex patterns
  if string_find(keyword, "%.[%*%+%?]") then
    return true
  end
  return false
end

-- [ MatchKeywordWithBoundary ]
-- Matches a plain keyword with word boundary rules:
-- - Keyword must not be preceded by a letter/number
-- - Keyword must not be followed by a letter/number (but punctuation is OK)
-- This prevents "na" from matching "naxx" but allows "na!" or "na?"
-- 'text'       [string]        the text to search in (should be lowercase)
-- 'keyword'    [string]        the keyword to find (should be lowercase)
-- return:      [boolean]       true if keyword matches with proper boundaries
function DBB2.api.MatchKeywordWithBoundary(text, keyword)
  if not text or not keyword then return false end
  
  local keywordLen = string_len(keyword)
  local textLen = string_len(text)
  local startPos = 1
  
  while startPos <= textLen do
    -- Find the keyword in text (plain search)
    local foundStart, foundEnd = string_find(text, keyword, startPos, true)
    if not foundStart then
      return false
    end
    
    -- Check character before the match (must not be alphanumeric)
    local validStart = true
    if foundStart > 1 then
      local charBefore = string_sub(text, foundStart - 1, foundStart - 1)
      if string_find(charBefore, "[%w]") then
        validStart = false
      end
    end
    
    -- Check character after the match (must not be alphanumeric)
    local validEnd = true
    if foundEnd < textLen then
      local charAfter = string_sub(text, foundEnd + 1, foundEnd + 1)
      if string_find(charAfter, "[%w]") then
        validEnd = false
      end
    end
    
    if validStart and validEnd then
      return true
    end
    
    -- Continue searching from after this match
    startPos = foundStart + 1
  end
  
  return false
end

-- [ IsMessageBlacklistedByKeyword ]
-- Checks if a message contains any blacklisted keyword
-- Plain keywords: matched with word boundaries (won't match inside other words)
--   e.g., "na" matches "na", "na!", "na?" but NOT "naxx"
-- Regex keywords: matched as-is using regex API (for advanced patterns)
--   e.g., "na.*" would match "naxx" if you want loose matching
-- Returns: matched (boolean), matchedKeywords (table of matched keyword strings)
function DBB2.api.IsMessageBlacklistedByKeyword(message)
  DBB2.api.InitBlacklist()
  if not DBB2_Config.blacklist.enabled then return false, {} end
  if not message then return false, {} end
  
  local matchedKeywords = {}
  local lowerMessage = string_lower(message)
  
  for _, keyword in ipairs(DBB2_Config.blacklist.keywords) do
    local matched = false
    
    if DBB2.api.IsKeywordRegexPattern(keyword) then
      -- Regex pattern: use regex API for matching (case-insensitive)
      if DBB2.api.regex and DBB2.api.regex.Match then
        matched = DBB2.api.regex.Match(message, keyword, true)
      end
    else
      -- Plain keyword: use word boundary matching
      local lowerKeyword = string_lower(keyword)
      matched = DBB2.api.MatchKeywordWithBoundary(lowerMessage, lowerKeyword)
    end
    
    if matched then
      table_insert(matchedKeywords, keyword)
    end
  end
  
  return table_getn(matchedKeywords) > 0, matchedKeywords
end

-- [ IsMessageBlacklisted ]
-- Checks if a message should be filtered (player or keyword)
-- Returns: blocked (boolean), reason (string: "player" or "keyword"), details (string or table)
function DBB2.api.IsMessageBlacklisted(message, sender)
  if not DBB2.api.IsBlacklistEnabled() then return false, nil, nil end
  
  if DBB2.api.IsPlayerBlacklisted(sender) then
    return true, "player", sender
  end
  
  local keywordBlocked, matchedKeywords = DBB2.api.IsMessageBlacklistedByKeyword(message)
  if keywordBlocked then
    return true, "keyword", matchedKeywords
  end
  
  return false, nil, nil
end

-- [ GetBlacklistedPlayers ]
-- Returns the list of blacklisted players
function DBB2.api.GetBlacklistedPlayers()
  DBB2.api.InitBlacklist()
  return DBB2_Config.blacklist.players
end

-- [ GetBlacklistedKeywords ]
-- Returns the list of blacklisted keywords
function DBB2.api.GetBlacklistedKeywords()
  DBB2.api.InitBlacklist()
  return DBB2_Config.blacklist.keywords
end

-- =====================
-- NOTIFICATION API
-- =====================

-- Session-only notification state (not saved to config)
DBB2.notificationState = {}

-- [ InitNotificationState ]
-- Initializes notification state for all categories (session-only, all off by default)
function DBB2.api.InitNotificationState()
  DBB2.notificationState = {
    groups = {},
    professions = {},
    hardcore = {}
  }
end

-- [ IsNotificationEnabled ]
-- Returns whether notifications are enabled for a specific category
function DBB2.api.IsNotificationEnabled(categoryType, categoryName)
  if not DBB2.notificationState[categoryType] then
    return false
  end
  return DBB2.notificationState[categoryType][categoryName] or false
end

-- [ SetNotificationEnabled ]
-- Enables or disables notifications for a specific category
-- return:         [boolean] true if set successfully
function DBB2.api.SetNotificationEnabled(categoryType, categoryName, enabled)
  if not categoryType or not categoryName then return false end
  if not DBB2.notificationState[categoryType] then
    DBB2.notificationState[categoryType] = {}
  end
  DBB2.notificationState[categoryType][categoryName] = enabled
  return true
end

-- [ InitNotificationConfig ]
-- Initializes notification config settings
-- mode: 0 = off, 1 = chat only, 2 = raid warning only, 3 = both
function DBB2.api.InitNotificationConfig()
  if not DBB2_Config.notifications then
    DBB2_Config.notifications = {
      mode = 0  -- Default: off
    }
  end
  -- Migrate old config format (chat/raidWarn booleans) to new mode format
  if DBB2_Config.notifications.chat ~= nil or DBB2_Config.notifications.raidWarn ~= nil then
    local chat = DBB2_Config.notifications.chat
    local raid = DBB2_Config.notifications.raidWarn
    if chat and raid then
      DBB2_Config.notifications.mode = 3
    elseif chat then
      DBB2_Config.notifications.mode = 1
    elseif raid then
      DBB2_Config.notifications.mode = 2
    else
      DBB2_Config.notifications.mode = 0
    end
    -- Remove old fields
    DBB2_Config.notifications.chat = nil
    DBB2_Config.notifications.raidWarn = nil
  end
  -- Ensure mode is valid
  if not DBB2_Config.notifications.mode or DBB2_Config.notifications.mode < 0 or DBB2_Config.notifications.mode > 3 then
    DBB2_Config.notifications.mode = 0
  end
end

-- [ GetNotificationMode ]
-- Returns current notification mode (0-3)
function DBB2.api.GetNotificationMode()
  DBB2.api.InitNotificationConfig()
  return DBB2_Config.notifications.mode
end

-- [ SetNotificationMode ]
-- Sets notification mode (0 = off, 1 = chat, 2 = raid warning, 3 = both)
function DBB2.api.SetNotificationMode(mode)
  DBB2.api.InitNotificationConfig()
  if mode >= 0 and mode <= 3 then
    DBB2_Config.notifications.mode = mode
  end
end

-- [ GetNotificationSettings ]
-- Returns current notification settings (legacy compatibility)
-- Returns table with chat and raidWarn booleans based on mode
function DBB2.api.GetNotificationSettings()
  DBB2.api.InitNotificationConfig()
  local mode = DBB2_Config.notifications.mode
  return {
    mode = mode,
    chat = (mode == 1 or mode == 3),
    raidWarn = (mode == 2 or mode == 3)
  }
end

-- [ SetNotificationChat ]
-- Enables or disables chat notifications (legacy compatibility)
function DBB2.api.SetNotificationChat(enabled)
  DBB2.api.InitNotificationConfig()
  local mode = DBB2_Config.notifications.mode
  if enabled then
    if mode == 0 or mode == 2 then
      DBB2_Config.notifications.mode = mode + 1
    end
  else
    if mode == 1 then
      DBB2_Config.notifications.mode = 0
    elseif mode == 3 then
      DBB2_Config.notifications.mode = 2
    end
  end
end

-- [ SetNotificationRaidWarn ]
-- Enables or disables raid warning notifications (legacy compatibility)
function DBB2.api.SetNotificationRaidWarn(enabled)
  DBB2.api.InitNotificationConfig()
  local mode = DBB2_Config.notifications.mode
  if enabled then
    if mode == 0 or mode == 1 then
      DBB2_Config.notifications.mode = mode + 2
    end
  else
    if mode == 2 then
      DBB2_Config.notifications.mode = 0
    elseif mode == 3 then
      DBB2_Config.notifications.mode = 1
    end
  end
end

-- On-screen notification queue system
DBB2.notificationQueue = {}
DBB2.notificationActive = false
DBB2.notificationTimer = 0
DBB2.NOTIFICATION_DURATION = 3  -- seconds per notification (display time)
DBB2.NOTIFICATION_FADE_BUFFER = 5  -- extra time for fade out before next

-- Process the notification queue
local function ProcessNotificationQueue()
  if DBB2.notificationActive then return end
  if table.getn(DBB2.notificationQueue) == 0 then return end
  
  -- Get next notification from queue
  local notification = table.remove(DBB2.notificationQueue, 1)
  
  -- Show it
  UIErrorsFrame:AddMessage(notification.text, notification.r, notification.g, notification.b, 1.0, DBB2.NOTIFICATION_DURATION)
  
  -- Play sound if enabled
  if notification.playSound then
    PlaySoundFile("Interface\\AddOns\\DifficultBulletinBoard\\sound\\duck.wav")
  end
  
  -- Mark as active and set timer (duration + fade buffer)
  DBB2.notificationActive = true
  DBB2.notificationTimer = GetTime() + DBB2.NOTIFICATION_DURATION + DBB2.NOTIFICATION_FADE_BUFFER
end

-- Queue an on-screen notification
local function QueueScreenNotification(text, r, g, b, playSound)
  table.insert(DBB2.notificationQueue, {
    text = text,
    r = r,
    g = g,
    b = b,
    playSound = playSound
  })
  ProcessNotificationQueue()
end

-- Create a frame to handle the queue timer
local notificationFrame = CreateFrame("Frame")
notificationFrame:SetScript("OnUpdate", function()
  if DBB2.notificationActive and GetTime() >= DBB2.notificationTimer then
    DBB2.notificationActive = false
    ProcessNotificationQueue()
  end
end)

-- [ SendNotification ]
-- Sends a notification for a matched category
function DBB2.api.SendNotification(categoryName, sender, message)
  local settings = DBB2.api.GetNotificationSettings()
  
  -- Guard against nil values
  categoryName = categoryName or "Unknown"
  sender = sender or "Unknown"
  message = message or ""
  
  -- Get highlight color for notification text
  local hr, hg, hb = DBB2:GetHighlightColor()
  local hexColor = string.format("%02x%02x%02x", hr * 255, hg * 255, hb * 255)
  local notifyText = "|cff" .. hexColor .. "[DBB]|r " .. categoryName .. " - " .. sender .. ": " .. message
  
  if settings.chat then
    -- Use the original AddMessage function to bypass our chat filter hook
    -- This ensures notifications are always shown even when hideFromChat is enabled
    local origFunc = DBB2.originalAddMessage and DBB2.originalAddMessage[1]
    if origFunc then
      origFunc(DEFAULT_CHAT_FRAME, notifyText, 1, 1, 1, nil)
    else
      -- Fallback if hook not installed yet
      DEFAULT_CHAT_FRAME:AddMessage(notifyText)
    end
  end
  
  -- Check if sound should play (only with first notification, not queued ones)
  local soundEnabled = DBB2_Config.notificationSound or 1
  local playSound = (soundEnabled == 1)
  
  if settings.raidWarn then
    -- Queue on-screen notification
    local screenText = "[DBB] " .. categoryName .. " - " .. sender .. ": " .. message
    QueueScreenNotification(screenText, hr, hg, hb, playSound)
  elseif playSound then
    -- Play sound immediately if no raid warn (chat only mode)
    PlaySoundFile("Interface\\AddOns\\DifficultBulletinBoard\\sound\\duck.wav")
  end
end

-- [ CheckAndNotify ]
-- Checks if message matches any category with notifications enabled and sends notification
function DBB2.api.CheckAndNotify(message, sender)
  if not DBB2.notificationState then return end
  
  local categoryTypes = {"groups", "professions", "hardcore"}
  
  for _, categoryType in ipairs(categoryTypes) do
    local categories = DBB2.api.GetCategories(categoryType)
    if categories then
      for _, cat in ipairs(categories) do
        if cat.selected and DBB2.api.IsNotificationEnabled(categoryType, cat.name) then
          if DBB2.api.MatchMessageToCategory(message, cat) then
            DBB2.api.SendNotification(cat.name, sender, message)
            return  -- Only notify once per message
          end
        end
      end
    end
  end
end

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
-- 'skipLog'    [boolean]       if true, don't log the duplicate (used by ShouldHideFromChat)
-- return:      [boolean]       true if duplicate, false otherwise
function DBB2.api.IsDuplicateMessage(message, sender, skipLog)
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
      if not skipLog then
        DBB2.api.LogDuplicate(sender, timeDiff, message)
      end
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
  local blocked, reason, details = DBB2.api.IsMessageBlacklisted(message, sender)
  if blocked then
    DBB2.api.LogBlacklist(sender, reason, details, message)
    return
  end
  
  if DBB2.api.IsDuplicateMessage(message, sender) then
    return
  end
  
  -- Remove previous message from same sender in same category (Groups/Professions only)
  -- This ensures only the most recent message per sender is shown
  DBB2.api.RemovePreviousMessageFromSameSender(sender, categories)
  
  -- Check for notifications before storing (only for selected categories)
  DBB2.api.CheckAndNotify(message, sender)
  
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
