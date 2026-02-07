-- DBB2 Utilities API
-- General utility functions: frame position persistence, table utilities, time formatting

-- Localize frequently used globals for performance
local table_getn = table.getn
local pairs = pairs
local type = type
local time = time
local date = date
local math_floor = math.floor
local math_mod = math.mod
local string_format = string.format

-- =====================================================
-- FRAME POSITION UTILITIES
-- =====================================================
-- Functions for saving and loading frame positions to saved variables.

-- [ SavePosition ]
-- Saves the position and size of a frame to saved variables
-- @param frame  [Frame]   The frame to save position for
-- @return       [boolean] true if saved successfully, false if invalid frame
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
-- @param frame  [Frame]   The frame to load position for
-- @return       [boolean] true if loaded successfully, false if no saved position
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

-- =====================================================
-- TABLE UTILITIES
-- =====================================================
-- General table manipulation functions.

-- [ DeepCopy ]
-- Creates a deep copy of a table (preserves array structure)
-- @param orig  [table]  The table to copy
-- @return      [any]    Deep copy of the input (or the input itself if not a table)
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

-- =====================================================
-- TIME FORMATTING UTILITIES
-- =====================================================
-- Functions for formatting timestamps in various display modes.

-- [ FormatRelativeTime ]
-- Formats a timestamp as relative time (e.g., "<1m", "2m", "15m", "1h")
-- @param timestamp  [number]  Unix timestamp
-- @return           [string]  Formatted relative time string
function DBB2.api.FormatRelativeTime(timestamp)
  if not timestamp then return "?" end
  
  local now = time()
  local diff = now - timestamp
  if diff < 0 then diff = 0 end
  
  if diff < 60 then
    return "<1m"
  elseif diff < 120 then
    return "2m"
  elseif diff < 3600 then
    local minutes = math_floor(diff / 60)
    return minutes .. "m"
  else
    local hours = math_floor(diff / 3600)
    local minutes = math_floor(math_mod(diff, 3600) / 60)
    if minutes > 0 then
      return hours .. "h" .. minutes .. "m"
    else
      return hours .. "h"
    end
  end
end

-- [ FormatRelativeTimeHMS ]
-- Formats a timestamp as MM:SS format, caps at 59:59 with overflow flag
-- @param timestamp  [number]  Unix timestamp
-- @return           [string]  Formatted MM:SS string
-- @return           [boolean] true if capped at 59:59 (over an hour old)
function DBB2.api.FormatRelativeTimeHMS(timestamp)
  if not timestamp then return "00:00", false end
  
  local now = time()
  local diff = now - timestamp
  if diff < 0 then diff = 0 end
  
  local hours = math_floor(diff / 3600)
  local minutes = math_floor(math_mod(diff, 3600) / 60)
  local seconds = math_floor(math_mod(diff, 60))
  
  -- Cap at 59:59 if over an hour
  if hours >= 1 then
    return "59:59", true
  end
  
  return string_format("%02d:%02d", minutes, seconds), false
end

-- [ FormatMessageTime ]
-- Returns time format based on config: 0=HH:MM:SS, 1=Relative, 2=Elapsed MM:SS
-- @param timestamp  [number]  Unix timestamp
-- @return           [string]  Formatted time string
-- @return           [boolean] Overflow flag (only for elapsed mode)
function DBB2.api.FormatMessageTime(timestamp)
  if DBB2_Config.timeDisplayMode == 1 then
    return DBB2.api.FormatRelativeTime(timestamp), false
  elseif DBB2_Config.timeDisplayMode == 2 then
    return DBB2.api.FormatRelativeTimeHMS(timestamp)
  else
    return date("%H:%M:%S", timestamp), false
  end
end
