-- DBB2 Utility API
-- General utility functions for the addon
--
-- API DEPENDENCY MAP
-- ==================
-- The DBB2.api table is initialized in DifficultBulletinBoard.lua
-- API functions are spread across multiple files loaded via TOC order.
--
-- Cross-file dependencies (called at runtime, not load time):
--   api/messages.lua:
--     - Calls DBB2.api.GetCategories() from api/categories.lua
--     - Calls DBB2.api.MatchMessageToCategory() from api/categories.lua
--
--   api/lockouts.lua:
--     - Updates GUI panels defined in modules/gui.lua
--
--   api/tooltip.lua:
--     - Uses DBB2:GetFontSize(), DBB2:ScaleSize() from main file
--     - Uses DBB2:GetHighlightColor() from main file
--
--   api/ui-widgets.lua:
--     - Uses DBB2:CreateBackdrop() from main file
--     - Uses DBB2:GetFontSize(), DBB2:ScaleSize() from main file
--
--   api/categories.lua:
--     - Provides category API functions (GetCategories, MatchMessageToCategory, etc.)
--     - Reads from DBB2_Config.categories (initialized by modules/categories.lua)
--
--   modules/categories.lua:
--     - Initializes DBB2_Config.categories with default data
--     - Provides ResetCategoriesToDefaults() (needs access to default tables)
--
-- Load order (from TOC):
--   1. DifficultBulletinBoard.lua (creates DBB2, DBB2.api)
--   2. api/*.lua files (add functions to DBB2.api)
--   3. modules/*.lua files (register via DBB2:RegisterModule, executed on ADDON_LOADED)

-- [ SavePosition ]
-- Saves the position and size of a frame to saved variables
-- 'frame'      [frame]         the frame to save
-- return:      [boolean]       true if saved successfully
function DBB2.api.SavePosition(frame)
  if not frame then return false end
  local name = frame:GetName()
  if not name then return false end
  
  local anchor, _, _, xpos, ypos = frame:GetPoint()
  
  DBB2_Config.position = DBB2_Config.position or {}
  DBB2_Config.position[name] = {
    anchor = anchor or "CENTER",
    xpos = xpos or 0,
    ypos = ypos or 0,
    width = frame:GetWidth(),
    height = frame:GetHeight()
  }
  return true
end

-- [ LoadPosition ]
-- Loads the saved position and size of a frame
-- 'frame'      [frame]         the frame to load
-- return:      [boolean]       true if position was loaded, false if no saved position
function DBB2.api.LoadPosition(frame)
  if not frame then return false end
  local name = frame:GetName()
  if not name then return false end
  
  if DBB2_Config.position and DBB2_Config.position[name] then
    local pos = DBB2_Config.position[name]
    
    frame:ClearAllPoints()
    frame:SetPoint(pos.anchor or "CENTER", pos.xpos or 0, pos.ypos or 0)
    
    if pos.width and pos.width > 0 then
      frame:SetWidth(pos.width)
    end
    
    if pos.height and pos.height > 0 then
      frame:SetHeight(pos.height)
    end
    return true
  end
  return false
end

-- [ DeepCopy ]
-- Creates a deep copy of a table (preserves array structure)
-- 'orig'       [table]         the table to copy
-- return:      [table]         a new table with copied values
function DBB2.api.DeepCopy(orig)
  if type(orig) ~= "table" then return orig end
  
  local copy = {}
  -- First copy array part
  for i = 1, table.getn(orig) do
    if type(orig[i]) == "table" then
      copy[i] = DBB2.api.DeepCopy(orig[i])
    else
      copy[i] = orig[i]
    end
  end
  -- Then copy hash part
  for k, v in pairs(orig) do
    if type(k) ~= "number" or k < 1 or k > table.getn(orig) then
      if type(v) == "table" then
        copy[k] = DBB2.api.DeepCopy(v)
      else
        copy[k] = v
      end
    end
  end
  return copy
end

-- =====================
-- HARDCORE MODE API
-- =====================

-- Turtle WoW hardcore mode: automatically switches between World and Hardcore chat.
-- When CHAT_MSG_HARDCORE events are received, World channel is ignored.
-- This is tracked per-session (resets on login).

-- Session flag: set to true when we receive any CHAT_MSG_HARDCORE event
DBB2._hardcoreChatActive = false

-- [ IsHardcoreChatActive ]
-- Returns whether hardcore chat has been detected this session
-- return:      [boolean]       true if hardcore chat is active
function DBB2.api.IsHardcoreChatActive()
  return DBB2._hardcoreChatActive
end

-- [ SetHardcoreChatActive ]
-- Marks hardcore chat as active (called when CHAT_MSG_HARDCORE is received)
function DBB2.api.SetHardcoreChatActive()
  DBB2._hardcoreChatActive = true
end

-- [ ClearWorldMessages ]
-- Removes all messages from World channel (used when switching to hardcore mode)
function DBB2.api.ClearWorldMessages()
  if not DBB2.messages then return end
  
  for i = table.getn(DBB2.messages), 1, -1 do
    local msg = DBB2.messages[i]
    if msg.channel and string.lower(msg.channel) == "world" then
      table.remove(DBB2.messages, i)
    end
  end
end


-- =====================
-- CHANNEL WHITELIST API
-- =====================

-- Only captures messages from known LFG-relevant channels.
-- This automatically filters out addon data channels (TTRP, XTENSIONXTOOLTIP, etc.)
-- without needing to maintain a blacklist.

-- Default whitelisted channels (case-insensitive)
-- These are the standard channels where players look for groups
DBB2._defaultWhitelistedChannels = {
  "world",           -- Main LFG channel on most servers
  "lookingforgroup", -- Blizzard's LFG channel
  "lfg",             -- Common abbreviation
  "trade",           -- Sometimes used for LFG
  "general",         -- Zone general chat
  "hardcore",        -- Turtle WoW hardcore
}

-- [ GetWhitelistedChannels ]
-- Returns the list of whitelisted channel names
-- return:      [table]         array of lowercase channel names
function DBB2.api.GetWhitelistedChannels()
  if not DBB2_Config.whitelistedChannels then
    -- Copy defaults
    DBB2_Config.whitelistedChannels = {}
    for i, ch in ipairs(DBB2._defaultWhitelistedChannels) do
      DBB2_Config.whitelistedChannels[i] = ch
    end
  end
  return DBB2_Config.whitelistedChannels
end

-- [ IsChannelWhitelisted ]
-- Checks if a channel is in the whitelist (LFG-relevant)
-- Uses prefix matching to handle channels with city suffixes (e.g., "Trade - Orgrimmar")
-- 'channelName' [string]       the channel name to check
-- return:       [boolean]      true if channel should be captured
function DBB2.api.IsChannelWhitelisted(channelName)
  if not channelName then return false end
  local lowerName = string.lower(channelName)
  local whitelist = DBB2.api.GetWhitelistedChannels()
  
  for _, name in ipairs(whitelist) do
    local lowerWhitelist = string.lower(name)
    local whitelistLen = string.len(lowerWhitelist)
    -- Use prefix matching: "trade - orgrimmar" starts with "trade"
    -- Check if channel name starts with whitelist entry (plain string comparison)
    if string.sub(lowerName, 1, whitelistLen) == lowerWhitelist then
      -- Ensure it's a word boundary (next char is space, dash, or end of string)
      local nextChar = string.sub(lowerName, whitelistLen + 1, whitelistLen + 1)
      if nextChar == "" or nextChar == " " or nextChar == "-" then
        return true
      end
    end
  end
  return false
end

-- [ AddWhitelistedChannel ]
-- Adds a channel to the whitelist
-- 'channelName' [string]       the channel name to whitelist
-- return:       [boolean]      true if added, false if already exists
function DBB2.api.AddWhitelistedChannel(channelName)
  if not channelName or channelName == "" then return false end
  
  local lowerName = string.lower(channelName)
  local whitelist = DBB2.api.GetWhitelistedChannels()
  
  -- Check if already exists
  for _, name in ipairs(whitelist) do
    if string.lower(name) == lowerName then
      return false
    end
  end
  
  table.insert(DBB2_Config.whitelistedChannels, lowerName)
  return true
end

-- [ RemoveWhitelistedChannel ]
-- Removes a channel from the whitelist
-- 'channelName' [string]       the channel name to remove
-- return:       [boolean]      true if removed, false if not found
function DBB2.api.RemoveWhitelistedChannel(channelName)
  if not channelName then return false end
  
  local lowerName = string.lower(channelName)
  local whitelist = DBB2.api.GetWhitelistedChannels()
  
  for i = table.getn(whitelist), 1, -1 do
    if string.lower(whitelist[i]) == lowerName then
      table.remove(DBB2_Config.whitelistedChannels, i)
      return true
    end
  end
  return false
end

-- [ ResetWhitelistedChannels ]
-- Resets the whitelist to defaults
function DBB2.api.ResetWhitelistedChannels()
  DBB2_Config.whitelistedChannels = {}
  for i, ch in ipairs(DBB2._defaultWhitelistedChannels) do
    DBB2_Config.whitelistedChannels[i] = ch
  end
end

-- [ GetJoinedChannels ]
-- Returns a list of channels the player has joined (uses GetChannelList)
-- return:      [table]         array of {id, name} tables
function DBB2.api.GetJoinedChannels()
  local channels = {}
  -- GetChannelList returns: id1, name1, id2, name2, ...
  local list = { GetChannelList() }
  
  for i = 1, table.getn(list), 2 do
    local id = list[i]
    local name = list[i + 1]
    if id and name then
      table.insert(channels, { id = id, name = name })
    end
  end
  
  return channels
end

