-- DBB2 Channel Management API
-- All channel-related functionality: whitelist, monitoring config, auto-join
-- Dependencies: env/defaults.lua, api/hardcore.lua (for IsHardcoreCharacter)

local string_lower = string.lower
local string_len = string.len
local string_sub = string.sub
local table_insert = table.insert
local table_remove = table.remove
local table_getn = table.getn
local ipairs = ipairs
local pairs = pairs

-- =====================
-- CHANNEL WHITELIST API
-- =====================

-- Returns the list of whitelisted channel names
function DBB2.api.GetWhitelistedChannels()
  if not DBB2_Config.whitelistedChannels then
    DBB2_Config.whitelistedChannels = {}
    for i, ch in ipairs(DBB2.env.defaultWhitelistedChannels) do
      DBB2_Config.whitelistedChannels[i] = ch
    end
  end
  return DBB2_Config.whitelistedChannels
end

-- Checks if a channel is in the whitelist (uses prefix matching for city suffixes)
function DBB2.api.IsChannelWhitelisted(channelName)
  if not channelName then return false end
  local lowerName = string_lower(channelName)
  local whitelist = DBB2.api.GetWhitelistedChannels()
  
  for _, name in ipairs(whitelist) do
    local lowerWhitelist = string_lower(name)
    local whitelistLen = string_len(lowerWhitelist)
    if string_sub(lowerName, 1, whitelistLen) == lowerWhitelist then
      local nextChar = string_sub(lowerName, whitelistLen + 1, whitelistLen + 1)
      if nextChar == "" or nextChar == " " or nextChar == "-" then
        return true
      end
    end
  end
  return false
end

-- Adds a channel to the whitelist (returns true if added, false if exists)
function DBB2.api.AddWhitelistedChannel(channelName)
  if not channelName or channelName == "" then return false end
  local lowerName = string_lower(channelName)
  local whitelist = DBB2.api.GetWhitelistedChannels()
  
  for _, name in ipairs(whitelist) do
    if string_lower(name) == lowerName then return false end
  end
  
  table_insert(DBB2_Config.whitelistedChannels, lowerName)
  return true
end

-- Removes a channel from the whitelist (returns true if removed, false if not found)
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

-- Resets the whitelist to defaults
function DBB2.api.ResetWhitelistedChannels()
  DBB2_Config.whitelistedChannels = {}
  for i, ch in ipairs(DBB2.env.defaultWhitelistedChannels) do
    DBB2_Config.whitelistedChannels[i] = ch
  end
end

-- Returns a list of channels the player has joined
function DBB2.api.GetJoinedChannels()
  local channels = {}
  local list = { GetChannelList() }
  for i = 1, table_getn(list), 2 do
    local id, name = list[i], list[i + 1]
    if id and name then
      table_insert(channels, { id = id, name = name })
    end
  end
  return channels
end

-- =====================
-- CHANNEL MONITORING CONFIG API
-- =====================

-- Initializes channel monitoring config if not present
function DBB2.api.InitChannelConfig()
  if not DBB2_Config.monitoredChannels then
    DBB2_Config.monitoredChannels = {}
    for channel, enabled in pairs(DBB2.env.defaultMonitoredChannels) do
      DBB2_Config.monitoredChannels[channel] = enabled
    end
  end
  for channel, enabled in pairs(DBB2.env.defaultMonitoredChannels) do
    if DBB2_Config.monitoredChannels[channel] == nil then
      DBB2_Config.monitoredChannels[channel] = enabled
    end
  end
  if DBB2_Config.autoJoinChannels == nil then
    DBB2_Config.autoJoinChannels = true
  end
end

-- Resets channel monitoring to defaults based on character type
-- Returns true if hardcore defaults applied, false if normal
function DBB2.api.ResetChannelDefaults()
  local isHardcore = DBB2.api.IsHardcoreCharacter()
  
  DBB2_Config.monitoredChannels = {}
  for channel, _ in pairs(DBB2.env.defaultMonitoredChannels) do
    DBB2_Config.monitoredChannels[channel] = false
  end
  
  if isHardcore then
    DBB2_Config.monitoredChannels["Hardcore"] = true
    DBB2_Config.monitoredChannels["Guild"] = true
    DBB2_Config.hardcoreChannelsInitialized = true
  else
    for channel, enabled in pairs(DBB2.env.defaultMonitoredChannels) do
      DBB2_Config.monitoredChannels[channel] = enabled
    end
  end
  
  DBB2.api.ResetWhitelistedChannels()
  return isHardcore
end

-- Fetches all currently joined channels and adds them to config
-- Returns array of channel names (static order + separators + dynamic)
function DBB2.api.RefreshJoinedChannels()
  DBB2.api.InitChannelConfig()
  local joinedChannels = DBB2.api.GetJoinedChannels()
  
  local staticChannels = {}
  for _, name in ipairs(DBB2.env.staticChannelOrder) do
    if name ~= "-" then staticChannels[name] = true end
  end
  
  for _, ch in ipairs(joinedChannels) do
    local name = ch.name
    if name and DBB2_Config.monitoredChannels[name] == nil then
      DBB2_Config.monitoredChannels[name] = false
    end
  end
  
  local result = {}
  for _, name in ipairs(DBB2.env.staticChannelOrder) do
    table_insert(result, name)
  end
  for _, ch in ipairs(joinedChannels) do
    local name = ch.name
    if name and not staticChannels[name] then
      table_insert(result, name)
    end
  end
  return result
end

-- Returns whether a specific channel is enabled for monitoring
function DBB2.api.IsChannelMonitored(channelName)
  if not channelName then return false end
  DBB2.api.InitChannelConfig()
  return DBB2_Config.monitoredChannels[channelName] or false
end

-- Enables or disables monitoring for a specific channel
function DBB2.api.SetChannelMonitored(channelName, enabled)
  if not channelName then return end
  DBB2.api.InitChannelConfig()
  DBB2_Config.monitoredChannels[channelName] = enabled
  if enabled then
    DBB2.api.AddWhitelistedChannel(channelName)
  else
    DBB2.api.RemoveWhitelistedChannel(channelName)
  end
end

-- Returns table of all monitored channel settings
function DBB2.api.GetMonitoredChannels()
  DBB2.api.InitChannelConfig()
  return DBB2_Config.monitoredChannels
end

-- =====================
-- AUTO-JOIN CHANNELS
-- =====================

-- Automatically joins World and LookingForGroup channels if not already joined
function DBB2.api.AutoJoinRequiredChannels()
  if DBB2_Config.autoJoinChannels == false then return end
  
  local joinedChannels = DBB2.api.GetJoinedChannels()
  local joinedLookup = {}
  for _, ch in ipairs(joinedChannels) do
    if ch.name then joinedLookup[string_lower(ch.name)] = true end
  end
  
  for _, channelName in ipairs(DBB2.env.autoJoinChannels) do
    local lowerName = string_lower(channelName)
    if not joinedLookup[lowerName] then
      JoinChannelByName(channelName)
      local hr, hg, hb = DBB2:GetHighlightColor()
      local hexColor = string.format("%02x%02x%02x", hr * 255, hg * 255, hb * 255)
      DEFAULT_CHAT_FRAME:AddMessage("|cff" .. hexColor .. "DBB2|r: Auto-joined |cffffffff" .. channelName .. "|r channel.")
    end
  end
end
