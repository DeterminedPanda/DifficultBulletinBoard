-- DBB2 Version Check API
-- Notifies users when a newer version is available via addon channel communication
-- Uses the TOC ## Version field as the single source of truth

local ADDON_PREFIX = "DBB2Ver"
local MY_VERSION = GetAddOnMetadata("DifficultBulletinBoard", "Version") or "0.0"

-- Session flag to only show upgrade notification once per login
local notifiedThisSession = false

-- Parse version string to comparable number (e.g., "2.33" -> 2033)
local function ParseVersion(str)
  if not str then return 0 end
  local _, _, major, minor = string.find(str, "^(%d+)%.(%d+)")
  return (tonumber(major) or 0) * 1000 + (tonumber(minor) or 0)
end

-- Check if version A is newer than version B
local function IsNewerVersion(versionA, versionB)
  return ParseVersion(versionA) > ParseVersion(versionB)
end

-- Show upgrade notification to user
local function ShowUpgradeNotification(newVersion)
  if notifiedThisSession then return end
  notifiedThisSession = true
  
  local hr, hg, hb = DBB2:GetHighlightColor()
  local hexColor = string.format("%02x%02x%02x", hr * 255, hg * 255, hb * 255)
  DEFAULT_CHAT_FRAME:AddMessage("|cff" .. hexColor .. "DBB2|r: A new version |cff00ff00v" .. newVersion .. "|r is available!")
  DEFAULT_CHAT_FRAME:AddMessage("|cff" .. hexColor .. "DBB2|r: |cff88aaffhttps://github.com/DeterminedPanda/DifficultBulletinBoard|r")
end

-- Check if we should show notification (called 10s after login)
local function CheckForUpdateNotification()
  local newestSeen = DBB2_Config.newestVersionSeen
  if newestSeen and IsNewerVersion(newestSeen, MY_VERSION) then
    ShowUpgradeNotification(newestSeen)
  end
end

-- Broadcast our version to available channels
local function BroadcastVersion()
  -- RAID covers both raid and party (auto-downgrades to PARTY if not in raid)
  SendAddonMessage(ADDON_PREFIX, MY_VERSION, "RAID")
  -- GUILD (silently ignored if not in a guild)
  SendAddonMessage(ADDON_PREFIX, MY_VERSION, "GUILD")
  -- BATTLEGROUND (silently ignored if not in a battleground)
  SendAddonMessage(ADDON_PREFIX, MY_VERSION, "BATTLEGROUND")
end

-- Handle incoming addon message
local function OnAddonMessage(prefix, message, channel, sender)
  if prefix ~= ADDON_PREFIX then return end
  
  -- Ignore our own messages
  local playerName = UnitName("player")
  if sender == playerName then return end
  
  local theirVersion = message
  
  -- Check if they have a newer version than us
  if IsNewerVersion(theirVersion, MY_VERSION) then
    -- Save it for next login (don't notify mid-session)
    local currentNewest = DBB2_Config.newestVersionSeen
    if not currentNewest or IsNewerVersion(theirVersion, currentNewest) then
      DBB2_Config.newestVersionSeen = theirVersion
    end
  end
end

-- Initialize version check system
local function InitVersionCheck()
  -- Register for addon messages
  DBB2:RegisterEvent("CHAT_MSG_ADDON")
  
  -- Hook into the main event handler
  local originalOnEvent = DBB2:GetScript("OnEvent")
  DBB2:SetScript("OnEvent", function()
    -- Handle addon messages
    if event == "CHAT_MSG_ADDON" then
      OnAddonMessage(arg1, arg2, arg3, arg4)
      return
    end
    
    -- Call original handler
    if originalOnEvent then
      originalOnEvent()
    end
  end)
  
  -- Schedule version broadcast and update check 10 seconds after login
  local delayFrame = CreateFrame("Frame")
  delayFrame.elapsed = 0
  delayFrame.waiting = true
  delayFrame:SetScript("OnUpdate", function()
    if not this.waiting then return end
    this.elapsed = this.elapsed + arg1
    if this.elapsed >= 10 then
      CheckForUpdateNotification()
      BroadcastVersion()
      this.waiting = false
      this:Hide()
    end
  end)
end

-- Register module
DBB2:RegisterModule("version_check", InitVersionCheck)
