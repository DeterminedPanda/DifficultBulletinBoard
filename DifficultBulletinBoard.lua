-- Create main addon namespace
DBB2 = CreateFrame("Frame", nil, UIParent)
DBB2:RegisterEvent("ADDON_LOADED")
DBB2:RegisterEvent("PLAYER_ENTERING_WORLD")
DBB2:RegisterEvent("CHAT_MSG_CHANNEL")
DBB2:RegisterEvent("CHAT_MSG_GUILD")
DBB2:RegisterEvent("CHAT_MSG_SAY")
DBB2:RegisterEvent("CHAT_MSG_YELL")
DBB2:RegisterEvent("CHAT_MSG_PARTY")
DBB2:RegisterEvent("CHAT_MSG_WHISPER")
DBB2:RegisterEvent("CHAT_MSG_SYSTEM")
DBB2:RegisterEvent("UPDATE_INSTANCE_INFO")
DBB2:RegisterEvent("CHAT_MSG_HARDCORE")  -- Turtle WoW hardcore chat
DBB2:RegisterEvent("CHAT_MSG_CHANNEL_NOTICE")  -- Channel join/leave notifications

-- Initialize saved variables
DBB2_Config = {}

-- Initialize addon tables
DBB2.messages = {}
DBB2.modules = {}
DBB2.api = {}  -- Initialize API table

-- Store minimap button angle
if not DBB2_Config.minimapAngle then
  DBB2_Config.minimapAngle = 45
end

-- Backdrop definitions
DBB2.backdrop = {
  bgFile = "Interface\\BUTTONS\\WHITE8X8", 
  tile = false, 
  tileSize = 0,
  edgeFile = "Interface\\BUTTONS\\WHITE8X8", 
  edgeSize = 1,
  insets = {left = -1, right = -1, top = -1, bottom = -1},
}

DBB2.backdrop_shadow = {
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  edgeSize = 8,
  insets = {left = 0, right = 0, top = 0, bottom = 0},
}

-- Helper function to create backdrop
-- useFixedBg: if true, uses the default dark charcoal instead of configurable color
function DBB2:CreateBackdrop(frame, inset, legacy, transp, useFixedBg)
  local border = 1
  
  -- Use configurable background color (with fallback to default dark charcoal)
  -- Unless useFixedBg is true, then always use the default
  local br, bg, bb, ba
  if useFixedBg then
    br, bg, bb, ba = 0.08, 0.08, 0.10, 0.85
  else
    local bgColor = DBB2_Config.backgroundColor or {r = 0.08, g = 0.08, b = 0.10, a = 0.85}
    br, bg, bb, ba = bgColor.r, bgColor.g, bgColor.b, bgColor.a or 0.85
  end
  local er, eg, eb, ea = 0.25, 0.25, 0.25, 1  -- Border: subtle gray
  
  -- Override transparency if specified
  if transp and transp < ba then ba = transp end
  
  if not frame.backdrop then
    local b = CreateFrame("Frame", nil, frame)
    local level = frame:GetFrameLevel()
    if level < 1 then
      b:SetFrameLevel(level)
    else
      b:SetFrameLevel(level - 1)
    end
    frame.backdrop = b
  end
  
  frame.backdrop:SetPoint("TOPLEFT", frame, "TOPLEFT", -border, border)
  frame.backdrop:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", border, -border)
  frame.backdrop:SetBackdrop(DBB2.backdrop)
  frame.backdrop:SetBackdropColor(br, bg, bb, ba)
  frame.backdrop:SetBackdropBorderColor(er, eg, eb, ea)
end

-- Helper function to create shadow
function DBB2:CreateBackdropShadow(frame)
  if frame.backdrop_shadow then return end
  
  local anchor = frame.backdrop or frame
  frame.backdrop_shadow = CreateFrame("Frame", nil, anchor)
  frame.backdrop_shadow:SetFrameStrata("BACKGROUND")
  frame.backdrop_shadow:SetFrameLevel(1)
  frame.backdrop_shadow:SetPoint("TOPLEFT", anchor, "TOPLEFT", -5, 5)
  frame.backdrop_shadow:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", 5, -5)
  frame.backdrop_shadow:SetBackdrop(DBB2.backdrop_shadow)
  frame.backdrop_shadow:SetBackdropBorderColor(0, 0, 0, 0.8)
end

-- Event handler
DBB2:SetScript("OnEvent", function()
  if event == "ADDON_LOADED" and arg1 == "DifficultBulletinBoard" then
    -- Initialize config with defaults if needed
    DBB2_Config = DBB2_Config or {}
    
    if not DBB2_Config.initialized then
      DBB2_Config.initialized = true
      DBB2_Config.version = "1.0.0"
      DBB2_Config.position = {}
      DBB2_Config.fontOffset = 0  -- Font size offset (-4 to +4)
      DBB2_Config.highlightColor = {r = 0.667, g = 0.655, b = 0.8, a = 1}  -- Default highlight color (#aaa7cc)
      DBB2_Config.backgroundColor = {r = 0.08, g = 0.08, b = 0.10, a = 0.85}  -- Default background color (dark charcoal)
      DBB2_Config.spamFilterSeconds = 150  -- Duplicate message filter time
      DBB2_Config.messageExpireMinutes = 15  -- Auto-remove messages older than X minutes (0 = disabled)
      DBB2_Config.hideFromChat = 0  -- Hide captured messages from chat (0=off, 1=selected, 2=all)
      DBB2_Config.maxMessagesPerCategory = 5  -- Max messages shown per category (0 = unlimited)
      DBB2_Config.scrollSpeed = 55  -- Scroll speed (pixels per wheel tick)
    end
    
    -- Ensure fontOffset exists for existing configs and is within safe bounds
    if DBB2_Config.fontOffset == nil or type(DBB2_Config.fontOffset) ~= "number" then
      DBB2_Config.fontOffset = 0
    end
    -- Clamp fontOffset to safe range (-4 to +4) to prevent crashes
    if DBB2_Config.fontOffset < -4 then
      DBB2_Config.fontOffset = -4
    elseif DBB2_Config.fontOffset > 4 then
      DBB2_Config.fontOffset = 4
    end
    
    -- Ensure highlightColor exists for existing configs
    if DBB2_Config.highlightColor == nil then
      DBB2_Config.highlightColor = {r = 0.667, g = 0.655, b = 0.8, a = 1}
    end
    
    -- Ensure backgroundColor exists for existing configs
    if DBB2_Config.backgroundColor == nil then
      DBB2_Config.backgroundColor = {r = 0.08, g = 0.08, b = 0.10, a = 0.85}
    end
    
    -- Ensure spamFilterSeconds exists for existing configs
    if DBB2_Config.spamFilterSeconds == nil then
      DBB2_Config.spamFilterSeconds = 150
    end
    
    -- Ensure maxMessagesPerCategory exists for existing configs
    if DBB2_Config.maxMessagesPerCategory == nil then
      DBB2_Config.maxMessagesPerCategory = 5
    end
    
    -- Ensure messageExpireMinutes exists for existing configs
    if DBB2_Config.messageExpireMinutes == nil then
      DBB2_Config.messageExpireMinutes = 15
    end
    
    -- Ensure hideFromChat exists for existing configs (migrate boolean to number)
    if DBB2_Config.hideFromChat == nil then
      DBB2_Config.hideFromChat = 0
    elseif DBB2_Config.hideFromChat == true then
      DBB2_Config.hideFromChat = 1
    elseif DBB2_Config.hideFromChat == false then
      DBB2_Config.hideFromChat = 0
    end
    
    -- Ensure scrollSpeed exists for existing configs
    if DBB2_Config.scrollSpeed == nil then
      DBB2_Config.scrollSpeed = 55
    end
    
    -- Ensure showLevelFilteredGroups exists for existing configs (default off)
    if DBB2_Config.showLevelFilteredGroups == nil then
      DBB2_Config.showLevelFilteredGroups = false
    end
    
    -- Load modules (use ipairs to preserve load order from TOC file)
    for i, module in ipairs(DBB2.modules) do
      if module then
        module()
      end
    end
    
    -- Initialize notification state (session-only, all off by default)
    DBB2.api.InitNotificationState()
    
    -- Setup chat filter hook for hiding captured messages
    DBB2.api.SetupChatFilter()
    
    -- Initialize lockout tracking
    DBB2.api.InitLockouts()
    
    -- Initialize channel monitoring config
    DBB2.api.InitChannelConfig()
    
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccDifficult|cffffffffBulletinBoard |cff555555v2.00|r loaded. Click minimap button to open.")
  end
  
  if event == "PLAYER_ENTERING_WORLD" then
    -- Clear hardcore detection cache to force fresh detection on each login/switch
    DBB2_Config.isHardcoreCharacter = nil
    local isHardcore = DBB2.api.DetectHardcoreCharacter()
    
    -- For hardcore characters, default all channels to off except Hardcore and Guild
    if isHardcore then
      DBB2.api.SetChannelMonitored("World", false)
      DBB2.api.SetChannelMonitored("LookingForGroup", false)
      DBB2.api.SetChannelMonitored("General", false)
      DBB2.api.SetChannelMonitored("Trade", false)
      DBB2.api.SetChannelMonitored("Say", false)
      DBB2.api.SetChannelMonitored("Yell", false)
      DBB2.api.SetChannelMonitored("Whisper", false)
      DBB2.api.SetChannelMonitored("Party", false)
      DBB2.api.SetChannelMonitored("LocalDefense", false)
      DBB2.api.SetChannelMonitored("WorldDefense", false)
      DBB2.api.SetChannelMonitored("GuildRecruitment", false)
    end
    
    -- Rebuild channel config panel if it exists (updates states)
    if DBB2.gui and DBB2.gui.configTabs and DBB2.gui.configTabs.panels then
      local channelsPanel = DBB2.gui.configTabs.panels["Channels"]
      if channelsPanel and channelsPanel.RebuildChannelCheckboxes then
        channelsPanel.RebuildChannelCheckboxes()
      end
    end
    
    -- Auto-join required channels (World, LookingForGroup) if not already joined
    -- Use a small delay to ensure channel system is ready
    if not DBB2._autoJoinScheduled then
      DBB2._autoJoinScheduled = true
      -- Create a frame for the delayed call
      local delayFrame = CreateFrame("Frame")
      delayFrame.elapsed = 0
      delayFrame:SetScript("OnUpdate", function()
        this.elapsed = this.elapsed + arg1
        if this.elapsed >= 2 then  -- 2 second delay
          DBB2.api.AutoJoinRequiredChannels()
          this:SetScript("OnUpdate", nil)
          this:Hide()
        end
      end)
    end
  end
  
  if event == "CHAT_MSG_CHANNEL" or event == "CHAT_MSG_GUILD" then
    -- Capture chat messages using API
    local message = arg1
    local sender = arg2
    local channel = arg9 or "Guild"
    
    -- For Guild messages, check if Guild channel is monitored
    if event == "CHAT_MSG_GUILD" then
      if not DBB2.api.IsChannelMonitored("Guild") then
        return  -- Guild channel not monitored, ignore
      end
    end
    
    -- For channel messages, only capture from whitelisted LFG-relevant channels
    -- This automatically filters out addon channels like TTRP, XTENSIONXTOOLTIP, etc.
    if event == "CHAT_MSG_CHANNEL" then
      if not DBB2.api.IsChannelWhitelisted(channel) then
        return  -- Not an LFG channel, ignore
      end
      
      -- Ignore World channel when hardcore is active
      local lowerChannel = string.lower(channel or "")
      if DBB2.api.IsHardcoreChatActive() and lowerChannel == "world" then
        return
      end
    end
    
    DBB2.api.AddMessage(message, sender, channel, event)
  end
  
  if event == "CHAT_MSG_SAY" or event == "CHAT_MSG_YELL" or event == "CHAT_MSG_PARTY" or event == "CHAT_MSG_WHISPER" then
    -- Capture Say, Yell, Party, Whisper messages
    local message = arg1
    local sender = arg2
    local channel
    
    if event == "CHAT_MSG_SAY" then
      channel = "Say"
    elseif event == "CHAT_MSG_YELL" then
      channel = "Yell"
    elseif event == "CHAT_MSG_WHISPER" then
      channel = "Whisper"
    else
      channel = "Party"
    end
    
    -- Check if this channel is monitored
    if not DBB2.api.IsChannelMonitored(channel) then
      return
    end
    
    DBB2.api.AddMessage(message, sender, channel, event)
  end
  
  if event == "CHAT_MSG_HARDCORE" then
    -- Turtle WoW hardcore chat messages
    local message = arg1
    local sender = arg2
    
    -- Check if Hardcore channel is monitored
    if not DBB2.api.IsChannelMonitored("Hardcore") then
      return  -- Hardcore channel not monitored, ignore
    end
    
    -- Mark hardcore chat as active (enables auto-switch from World)
    if not DBB2.api.IsHardcoreChatActive() then
      DBB2.api.SetHardcoreChatActive()
    end
    
    DBB2.api.AddMessage(message, sender, "Hardcore", event)
  end
  
  if event == "CHAT_MSG_SYSTEM" then
    -- Capture system messages (hardcore deaths, level ups, etc.)
    local message = arg1
    -- System messages don't have a sender, use "System" as placeholder
    local sender = "System"
    local channel = "System"
    
    DBB2.api.AddMessage(message, sender, channel, event)
  end
  
  if event == "UPDATE_INSTANCE_INFO" then
    DBB2.api.UpdateLockouts()
  end
  
  if event == "CHAT_MSG_CHANNEL_NOTICE" then
    -- Channel join/leave notification - refresh channel list if panel exists
    -- arg1 = notice type (e.g. "YOU_JOINED", "YOU_LEFT")
    -- arg9 = channel name
    if DBB2.gui and DBB2.gui.configTabs and DBB2.gui.configTabs.panels then
      local channelsPanel = DBB2.gui.configTabs.panels["Channels"]
      if channelsPanel and channelsPanel.RebuildChannelCheckboxes then
        channelsPanel.RebuildChannelCheckboxes()
      end
    end
  end
end)

-- Register module function
function DBB2:RegisterModule(name, func)
  if DBB2.modules[name] then return end
  DBB2.modules[name] = func
  table.insert(DBB2.modules, func)
end

-- Cache tables for scaled values (populated on first call, constant per session)
DBB2._fontCache = {}
DBB2._scaledCache = {}

-- Get font size with offset applied (cached)
-- 'baseSize'   [number]        the base font size
-- return:      [number]        font size with offset applied (minimum 6, maximum 24)
-- Note: WoW 1.12.1 has internal font size limits. Large fonts can cause crashes.
function DBB2:GetFontSize(baseSize)
  if self._fontCache[baseSize] then
    return self._fontCache[baseSize]
  end
  local offset = DBB2_Config.fontOffset
  -- Ensure offset is a valid number
  if type(offset) ~= "number" then offset = 0 end
  local size = baseSize + offset
  -- Clamp between 6 and 24 to prevent crashes in WoW 1.12.1
  -- Using conservative limits as vanilla WoW has strict font rendering constraints
  if size < 6 then size = 6 end
  if size > 24 then size = 24 end
  self._fontCache[baseSize] = size
  return size
end

-- [ GetScaleFactor ]
-- Returns a scale factor based on font offset for scaling UI element widths/heights
-- return:      [number]        scale factor (1.0 at offset 0, increases with positive offset)
function DBB2:GetScaleFactor()
  local offset = DBB2_Config.fontOffset
  -- Ensure offset is a valid number
  if type(offset) ~= "number" then offset = 0 end
  -- Clamp offset to safe range to prevent extreme scaling
  if offset < -4 then offset = -4 end
  if offset > 4 then offset = 4 end
  -- Scale by ~10% per font size increase (offset of +4 = 1.4x scale)
  return 1 + (offset * 0.1)
end

-- [ ScaleSize ]
-- Scales a base size value according to font offset (cached)
-- 'baseSize'   [number]        the base size value
-- return:      [number]        scaled size (minimum 1 to prevent zero/negative dimensions)
function DBB2:ScaleSize(baseSize)
  if self._scaledCache[baseSize] then
    return self._scaledCache[baseSize]
  end
  local scaled = math.floor(baseSize * DBB2:GetScaleFactor() + 0.5)
  -- Ensure minimum size of 1 to prevent invalid frame dimensions
  if scaled < 1 then scaled = 1 end
  self._scaledCache[baseSize] = scaled
  return scaled
end

-- Get highlight color
-- return:      [r, g, b, a]    highlight color components
function DBB2:GetHighlightColor()
  local c = DBB2_Config.highlightColor or {r = 0.2, g = 1, b = 0.8, a = 1}
  return c.r, c.g, c.b, c.a
end

-- Slash command to toggle GUI
SLASH_DBB1 = "/dbb"
SlashCmdList["DBB"] = function(msg)
  if DBB2.gui then
    if DBB2.gui:IsShown() then
      DBB2.gui:Hide()
    else
      DBB2.gui:Show()
    end
  end
end

