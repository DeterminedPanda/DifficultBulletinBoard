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

-- Localize frequently used globals for performance
local string_lower = string.lower
local string_len = string.len
local string_sub = string.sub
local string_find = string.find
local table_insert = table.insert
local table_remove = table.remove
local table_getn = table.getn
local ipairs = ipairs
local pairs = pairs
local type = type

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
  for i = 1, table_getn(orig) do
    if type(orig[i]) == "table" then
      copy[i] = DBB2.api.DeepCopy(orig[i])
    else
      copy[i] = orig[i]
    end
  end
  -- Then copy hash part
  for k, v in pairs(orig) do
    if type(k) ~= "number" or k < 1 or k > table_getn(orig) then
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
  local lowerName = string_lower(channelName)
  local whitelist = DBB2.api.GetWhitelistedChannels()
  
  for _, name in ipairs(whitelist) do
    local lowerWhitelist = string_lower(name)
    local whitelistLen = string_len(lowerWhitelist)
    -- Use prefix matching: "trade - orgrimmar" starts with "trade"
    -- Check if channel name starts with whitelist entry (plain string comparison)
    if string_sub(lowerName, 1, whitelistLen) == lowerWhitelist then
      -- Ensure it's a word boundary (next char is space, dash, or end of string)
      local nextChar = string_sub(lowerName, whitelistLen + 1, whitelistLen + 1)
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
  
  local lowerName = string_lower(channelName)
  local whitelist = DBB2.api.GetWhitelistedChannels()
  
  -- Check if already exists
  for _, name in ipairs(whitelist) do
    if string_lower(name) == lowerName then
      return false
    end
  end
  
  table_insert(DBB2_Config.whitelistedChannels, lowerName)
  return true
end

-- [ RemoveWhitelistedChannel ]
-- Removes a channel from the whitelist
-- 'channelName' [string]       the channel name to remove
-- return:       [boolean]      true if removed, false if not found
function DBB2.api.RemoveWhitelistedChannel(channelName)
  if not channelName then return false end
  
  local lowerName = string_lower(channelName)
  local whitelist = DBB2.api.GetWhitelistedChannels()
  
  for i = table_getn(whitelist), 1, -1 do
    if string_lower(whitelist[i]) == lowerName then
      table_remove(DBB2_Config.whitelistedChannels, i)
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
  
  for i = 1, table_getn(list), 2 do
    local id = list[i]
    local name = list[i + 1]
    if id and name then
      table_insert(channels, { id = id, name = name })
    end
  end
  
  return channels
end


-- =====================
-- CHANNEL MONITORING CONFIG API
-- =====================

-- Default channel monitoring settings (which channels are enabled for monitoring)
DBB2._defaultMonitoredChannels = {
  -- Group 1: Local/Social
  Say = false,
  Yell = false,
  Guild = true,
  Whisper = false,
  Party = false,
  -- Group 2: Zone/Global channels
  General = true,
  Trade = true,
  LocalDefense = false,
  WorldDefense = false,
  LookingForGroup = true,
  GuildRecruitment = false,
  World = true,
  -- Special
  Hardcore = true,  -- Will only work for hardcore characters
}

-- Static channel order (always shown regardless of joined status)
-- Use "-" as separator marker between groups
DBB2._staticChannelOrder = {
  "Say", "Yell", "Guild", "Whisper", "Party",
  "-",  -- separator
  "General", "Trade", "LocalDefense", "WorldDefense", "LookingForGroup", "GuildRecruitment", "World", "Hardcore",
  "-",  -- separator (dynamic channels follow)
}

-- [ InitChannelConfig ]
-- Initializes channel monitoring config if not present
function DBB2.api.InitChannelConfig()
  if not DBB2_Config.monitoredChannels then
    DBB2_Config.monitoredChannels = {}
    for channel, enabled in pairs(DBB2._defaultMonitoredChannels) do
      DBB2_Config.monitoredChannels[channel] = enabled
    end
  end
  -- Ensure all default channels exist in config (for new channels added in updates)
  for channel, enabled in pairs(DBB2._defaultMonitoredChannels) do
    if DBB2_Config.monitoredChannels[channel] == nil then
      DBB2_Config.monitoredChannels[channel] = enabled
    end
  end
  -- Ensure autoJoinChannels exists (default: enabled)
  if DBB2_Config.autoJoinChannels == nil then
    DBB2_Config.autoJoinChannels = true
  end
end

-- [ ResetChannelDefaults ]
-- Resets channel monitoring to defaults based on character type
-- Hardcore characters: only Hardcore + Guild enabled
-- Normal characters: standard defaults (World, LFG, General, Trade, Guild)
-- return:      [boolean]       true if hardcore defaults applied, false if normal
function DBB2.api.ResetChannelDefaults()
  local isHardcore = DBB2.api.IsHardcoreCharacter()
  
  -- Reset all channels to off first
  DBB2_Config.monitoredChannels = {}
  for channel, _ in pairs(DBB2._defaultMonitoredChannels) do
    DBB2_Config.monitoredChannels[channel] = false
  end
  
  if isHardcore then
    -- Hardcore defaults: only Hardcore and Guild
    DBB2_Config.monitoredChannels["Hardcore"] = true
    DBB2_Config.monitoredChannels["Guild"] = true
    -- Clear the initialized flag so it can be re-applied if needed
    DBB2_Config.hardcoreChannelsInitialized = true
  else
    -- Normal defaults from the default table
    for channel, enabled in pairs(DBB2._defaultMonitoredChannels) do
      DBB2_Config.monitoredChannels[channel] = enabled
    end
  end
  
  -- Also reset the whitelist to match
  DBB2.api.ResetWhitelistedChannels()
  
  return isHardcore
end

-- [ RefreshJoinedChannels ]
-- Fetches all currently joined channels and adds them to config (disabled by default)
-- This should be called when the Channels panel is shown to catch late-joining channels
-- return:      [table]         array of channel names (static order + separators + dynamic)
function DBB2.api.RefreshJoinedChannels()
  DBB2.api.InitChannelConfig()
  
  -- Get currently joined channels
  local joinedChannels = DBB2.api.GetJoinedChannels()
  
  -- Build set of static channel names for quick lookup
  local staticChannels = {}
  for _, name in ipairs(DBB2._staticChannelOrder) do
    if name ~= "-" then
      staticChannels[name] = true
    end
  end
  
  -- Add any new custom channels to config (disabled by default)
  for _, ch in ipairs(joinedChannels) do
    local name = ch.name
    if name and DBB2_Config.monitoredChannels[name] == nil then
      -- New channel not in defaults, disable by default
      DBB2_Config.monitoredChannels[name] = false
    end
  end
  
  -- Build result: static channels in order (with separators), then dynamic custom channels
  local result = {}
  
  -- Add all static channels (including separators)
  for _, name in ipairs(DBB2._staticChannelOrder) do
    table_insert(result, name)
  end
  
  -- Add custom joined channels (not in static list)
  for _, ch in ipairs(joinedChannels) do
    local name = ch.name
    if name and not staticChannels[name] then
      table_insert(result, name)
    end
  end
  
  return result
end

-- [ IsChannelMonitored ]
-- Returns whether a specific channel is enabled for monitoring
-- 'channelName' [string]       the channel name to check
-- return:       [boolean]      true if channel is monitored
function DBB2.api.IsChannelMonitored(channelName)
  if not channelName then return false end
  DBB2.api.InitChannelConfig()
  return DBB2_Config.monitoredChannels[channelName] or false
end

-- [ SetChannelMonitored ]
-- Enables or disables monitoring for a specific channel
-- 'channelName' [string]       the channel name
-- 'enabled'     [boolean]      whether to monitor this channel
function DBB2.api.SetChannelMonitored(channelName, enabled)
  if not channelName then return end
  DBB2.api.InitChannelConfig()
  DBB2_Config.monitoredChannels[channelName] = enabled
  
  -- Also update the whitelist to match
  if enabled then
    DBB2.api.AddWhitelistedChannel(channelName)
  else
    DBB2.api.RemoveWhitelistedChannel(channelName)
  end
end

-- [ GetMonitoredChannels ]
-- Returns table of all monitored channel settings
-- return:      [table]         table of channelName -> boolean
function DBB2.api.GetMonitoredChannels()
  DBB2.api.InitChannelConfig()
  return DBB2_Config.monitoredChannels
end


-- =====================
-- HARDCORE CHARACTER DETECTION
-- =====================

-- [ DetectHardcoreCharacter ]
-- Detects if the current character is an active hardcore character by scanning spellbook
-- Only scans the first "General" tab for efficiency and accuracy.
-- Looks for spells with rank "Challenge" (e.g., "Hardcore (Challenge)", "Inferno (Challenge)")
-- A character is considered "active hardcore" if:
--   1. Has "Hardcore" spell with "Challenge" rank AND is below level 60 (normal hardcore), OR
--   2. Has "Inferno" spell with "Challenge" rank (level 60 hardcore who chose to stay hardcore)
-- return:      [boolean]       true if active hardcore character detected
function DBB2.api.DetectHardcoreCharacter()
  -- Check cached result first
  if DBB2_Config.isHardcoreCharacter ~= nil then
    return DBB2_Config.isHardcoreCharacter
  end
  
  local hasHardcoreSpell = false
  local hasInfernoSpell = false
  local playerLevel = UnitLevel("player") or 60
  
  -- Only scan the first "General" tab (tab 1) for challenge spells
  -- This is more efficient and avoids false matches from other spell tabs
  local numTabs = GetNumSpellTabs()
  if numTabs >= 1 then
    local tabName, _, offset, numSpells = GetSpellTabInfo(1)
    
    for i = 1, numSpells do
      local spellName, spellRank = GetSpellName(offset + i, "spell")
      if spellName and spellRank then
        -- Only match spells with "Challenge" rank for precise detection
        if spellRank == "Challenge" then
          local lowerName = string_lower(spellName)
          if lowerName == "hardcore" then
            hasHardcoreSpell = true
          elseif lowerName == "inferno" then
            hasInfernoSpell = true
          end
        end
      end
    end
  end
  
  -- Active hardcore: has Inferno spell, OR has Hardcore spell and below level 60
  local isActiveHardcore = hasInfernoSpell or (hasHardcoreSpell and playerLevel < 60)
  
  DBB2_Config.isHardcoreCharacter = isActiveHardcore
  return isActiveHardcore
end

-- [ IsHardcoreCharacter ]
-- Returns cached hardcore character status (use DetectHardcoreCharacter to force re-scan)
-- return:      [boolean]       true if hardcore character
function DBB2.api.IsHardcoreCharacter()
  if DBB2_Config.isHardcoreCharacter == nil then
    return DBB2.api.DetectHardcoreCharacter()
  end
  return DBB2_Config.isHardcoreCharacter
end


-- =====================
-- AUTO-JOIN CHANNELS
-- =====================

-- Channels that should be auto-joined if not already joined
DBB2._autoJoinChannels = {"World", "LookingForGroup"}

-- [ AutoJoinRequiredChannels ]
-- Automatically joins World and LookingForGroup channels if not already joined
-- Should be called on PLAYER_ENTERING_WORLD event
-- Respects the autoJoinChannels config setting (enabled by default)
function DBB2.api.AutoJoinRequiredChannels()
  -- Check if auto-join is disabled by user
  if DBB2_Config.autoJoinChannels == false then
    return
  end
  
  -- Get currently joined channels
  local joinedChannels = DBB2.api.GetJoinedChannels()
  
  -- Build lookup table of joined channel names (lowercase for comparison)
  local joinedLookup = {}
  for _, ch in ipairs(joinedChannels) do
    if ch.name then
      joinedLookup[string_lower(ch.name)] = true
    end
  end
  
  -- Check and join required channels
  for _, channelName in ipairs(DBB2._autoJoinChannels) do
    local lowerName = string_lower(channelName)
    if not joinedLookup[lowerName] then
      -- Channel not joined, join it
      JoinChannelByName(channelName)
      DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccDBB2|r: Auto-joined |cffffffff" .. channelName .. "|r channel.")
    end
  end
end


-- =====================
-- RELATIVE TIME FORMATTING
-- =====================

-- [ FormatRelativeTime ]
-- Formats a timestamp as relative time (e.g., "<1m", "2m", "15m", "1h")
-- 'timestamp'  [number]        Unix timestamp of the message
-- return:      [string]        Formatted relative time string
function DBB2.api.FormatRelativeTime(timestamp)
  if not timestamp then return "?" end
  
  local now = time()
  local diff = now - timestamp
  
  -- Handle edge cases
  if diff < 0 then diff = 0 end
  
  if diff < 60 then
    return "<1m"
  elseif diff < 120 then
    return "2m"
  elseif diff < 3600 then
    local minutes = math.floor(diff / 60)
    return minutes .. "m"
  else
    local hours = math.floor(diff / 3600)
    local minutes = math.floor(math.mod(diff, 3600) / 60)
    if minutes > 0 then
      return hours .. "h" .. minutes .. "m"
    else
      return hours .. "h"
    end
  end
end

-- [ FormatRelativeTimeHMS ]
-- Formats a timestamp as relative time in HH:MM:SS format
-- 'timestamp'  [number]        Unix timestamp of the message
-- return:      [string]        Formatted relative time string (e.g., "00:05:30")
function DBB2.api.FormatRelativeTimeHMS(timestamp)
  if not timestamp then return "00:00:00" end
  
  local now = time()
  local diff = now - timestamp
  
  -- Handle edge cases
  if diff < 0 then diff = 0 end
  
  local hours = math.floor(diff / 3600)
  local minutes = math.floor(math.mod(diff, 3600) / 60)
  local seconds = math.floor(math.mod(diff, 60))
  
  -- Cap at 99:59:59 to keep 8 characters
  if hours > 99 then
    return "99:59:59"
  end
  
  return string.format("%02d:%02d:%02d", hours, minutes, seconds)
end

-- [ FormatMessageTime ]
-- Returns either absolute or relative time based on config setting
-- timeDisplayMode: 0 = Timestamp (HH:MM:SS), 1 = Relative (2m, 15m, 1h), 2 = Relative HH:MM:SS
-- 'timestamp'  [number]        Unix timestamp of the message
-- return:      [string]        Formatted time string
function DBB2.api.FormatMessageTime(timestamp)
  if DBB2_Config.timeDisplayMode == 1 then
    return DBB2.api.FormatRelativeTime(timestamp)
  elseif DBB2_Config.timeDisplayMode == 2 then
    return DBB2.api.FormatRelativeTimeHMS(timestamp)
  else
    return date("%H:%M:%S", timestamp)
  end
end
