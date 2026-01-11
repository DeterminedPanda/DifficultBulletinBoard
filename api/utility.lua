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
