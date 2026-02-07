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
-- Filterable channels: World, Hardcore, Trade
-- Custom channel format: "[X] [PlayerName]: message" (X = channel number only)
-- Built-in channel format: "[X. ChannelName] [PlayerName]: message" (number + dot + name)
-- Trade can also be "[2. Trade - City]" format
-- Hardcore channel format: "[H] [PlayerName]: message"
-- Uses GetChannelName API to resolve channel number to name for custom channels
-- 'message'    [string]        the formatted message from chat frame
-- return:      [boolean]       true if from a filterable channel
function DBB2.api.IsFilterableChannel(message)
  if not message then return false end
  
  local lowerMsg = string_lower(message)
  
  -- Check for Hardcore channel: "[H] " prefix (Turtle WoW specific)
  if string_find(lowerMsg, "^%[h%]") then
    return true
  end
  
  -- Check for built-in channel format containing "trade", "world", or "hardcore"
  -- Examples: "[2. Trade]", "[2. Trade - Orgrimmar]", "[1. General - Durotar]"
  -- Simply check if the message starts with a channel bracket containing our keywords
  if string_find(lowerMsg, "^%[%d+%.") then
    -- Message starts with "[X." format - check for our target channels
    if string_find(lowerMsg, "^%[%d+%.%s*trade") then
      return true
    end
    if string_find(lowerMsg, "^%[%d+%.%s*world") then
      return true
    end
    if string_find(lowerMsg, "^%[%d+%.%s*hardcore") then
      return true
    end
  end
  
  -- Check for custom channel format: "[5]" at the start (number only, no dot)
  -- This format is used by custom channels like World on private servers
  -- Also handles built-in channels after color code stripping (e.g., Trade shows as [2])
  local _, _, channelNum = string_find(message, "^%[(%d+)%]")
  if channelNum then
    -- GetChannelName returns: id, name (we need the second return value)
    local _, channelName = GetChannelName(tonumber(channelNum))
    if channelName then
      local lowerChannel = string_lower(channelName)
      -- Filter World, Hardcore, and Trade channels
      -- Use string_find because channel names can include zone (e.g., "Trade - City")
      if string_find(lowerChannel, "^world") or string_find(lowerChannel, "^hardcore") or string_find(lowerChannel, "^trade") then
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
-- Also hides blacklisted messages when blacklist.hideFromChat is enabled (independent of hideFromChat mode)
-- Also hides duplicates when hideFromChat is enabled
-- IMPORTANT: Never hides system messages (like /who results) even if they match category patterns
-- IMPORTANT: Only filters messages from World, Hardcore, or Trade channels
-- IMPORTANT: Never filters the player's own messages
function DBB2.api.ShouldHideFromChat(message, sender)
  local mode = DBB2_Config.hideFromChat or 0
  local hideBlacklisted = DBB2.api.IsBlacklistHideFromChatEnabled()
  
  -- If both hideFromChat and hideBlacklisted are disabled, nothing to filter
  if (mode == 0 or mode == false) and not hideBlacklisted then
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
  
  -- Check blacklist (hide if blacklist.hideFromChat is enabled, independent of hideFromChat mode)
  if hideBlacklisted and DBB2.api.IsMessageBlacklisted then
    local blocked = DBB2.api.IsMessageBlacklisted(message, sender)
    if blocked then
      return true
    end
  end
  
  -- If hideFromChat mode is disabled, don't check categories or duplicates
  if mode == 0 or mode == false then
    return false
  end
  
  -- Check if message matches categories
  local categoryTypes = {"groups", "professions", "hardcore"}
  local ignoreSelected = (mode == 2)  -- Mode 2 ignores selected state
  local matchesCategory = false
  
  for _, categoryType in ipairs(categoryTypes) do
    local categories = DBB2.api.GetCategories(categoryType)
    if categories then
      for _, cat in ipairs(categories) do
        if DBB2.api.MatchMessageToCategory(message, cat, ignoreSelected, categoryType) then
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
    
    if DBB2.api.IsDuplicateMessage(msgContent, sender) then
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
