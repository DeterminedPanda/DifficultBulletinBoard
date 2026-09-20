-- DBB2 Notification API
-- Handles alert system for watched categories
--
-- Dependencies: api/categories_api.lua (GetCategories, MatchMessageToCategory)
-- This file must be loaded AFTER categories_api.lua

-- Localize frequently used globals for performance
local string_format = string.format
local table_insert = table.insert
local table_remove = table.remove
local table_getn = table.getn
local ipairs = ipairs
local GetTime = GetTime

-- =====================
-- NOTIFICATION STATE
-- =====================

-- Notification state for all categories
-- Session-only by default; with the persistNotifications option enabled this is
-- the same table as DBB2_Config.notificationState, so writes are saved per character
DBB2.notificationState = {}

-- [ NewNotificationState ]
-- Returns an empty notification state table (local helper)
-- return:          [table]         fresh state with one sub-table per category type
local function NewNotificationState()
  return {
    groups = {},
    professions = {},
    hardcore = {}
  }
end

-- [ InitNotificationState ]
-- Initializes notification state for all categories (all off by default)
-- With persistNotifications enabled, reuses the saved state so enabled bells
-- survive a logout; otherwise starts empty and keeps nothing in the config
function DBB2.api.InitNotificationState()
  if not DBB2_Config.persistNotifications then
    DBB2_Config.notificationState = nil
    DBB2.notificationState = NewNotificationState()
    return
  end

  local state = DBB2_Config.notificationState or NewNotificationState()
  if not state.groups then state.groups = {} end
  if not state.professions then state.professions = {} end
  if not state.hardcore then state.hardcore = {} end
  -- same table reference, so every write lands in the saved variables
  DBB2_Config.notificationState = state
  DBB2.notificationState = state
end

-- [ SetNotificationPersistence ]
-- Starts or stops saving the current notification state between sessions
-- Called when the persistNotifications option is toggled
-- 'enabled'        [boolean]       whether enabled bells should be remembered
function DBB2.api.SetNotificationPersistence(enabled)
  if enabled then
    -- adopt the current session state so bells enabled before the toggle are kept
    DBB2_Config.notificationState = DBB2.notificationState
  else
    -- drop the saved copy; the live table stays untouched for this session
    DBB2_Config.notificationState = nil
  end
end

-- [ IsNotificationEnabled ]
-- Returns whether notifications are enabled for a specific category
-- 'categoryType'   [string]        the category type (groups, professions, hardcore)
-- 'categoryName'   [string]        the category name
-- return:          [boolean]       true if notifications enabled for this category
function DBB2.api.IsNotificationEnabled(categoryType, categoryName)
  if not DBB2.notificationState[categoryType] then
    return false
  end
  return DBB2.notificationState[categoryType][categoryName] or false
end

-- [ SetNotificationEnabled ]
-- Enables or disables notifications for a specific category
-- 'categoryType'   [string]        the category type (groups, professions, hardcore)
-- 'categoryName'   [string]        the category name
-- 'enabled'        [boolean]       whether to enable notifications
-- return:          [boolean]       true if set successfully
function DBB2.api.SetNotificationEnabled(categoryType, categoryName, enabled)
  if not categoryType or not categoryName then return false end
  if not DBB2.notificationState[categoryType] then
    DBB2.notificationState[categoryType] = {}
  end
  -- store nil instead of false so disabled categories are not saved
  DBB2.notificationState[categoryType][categoryName] = enabled and true or nil
  return true
end

-- =====================
-- NOTIFICATION CONFIG
-- =====================

-- [ InitNotificationConfig ]
-- Initializes notification config settings
-- mode: 0 = off, 1 = chat only, 2 = raid warning only, 3 = both
function DBB2.api.InitNotificationConfig()
  if not DBB2_Config.notifications then
    DBB2_Config.notifications = {
      mode = 3  -- Default: both
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
    DBB2_Config.notifications.mode = 3
  end
end

-- [ GetNotificationMode ]
-- Returns current notification mode (0-3)
-- return:      [number]        0 = off, 1 = chat, 2 = raid warning, 3 = both
function DBB2.api.GetNotificationMode()
  DBB2.api.InitNotificationConfig()
  return DBB2_Config.notifications.mode
end

-- [ SetNotificationMode ]
-- Sets notification mode (0 = off, 1 = chat, 2 = raid warning, 3 = both)
-- 'mode'       [number]        the notification mode (0-3)
function DBB2.api.SetNotificationMode(mode)
  DBB2.api.InitNotificationConfig()
  if mode >= 0 and mode <= 3 then
    DBB2_Config.notifications.mode = mode
  end
end

-- =====================
-- LEGACY COMPATIBILITY
-- =====================

-- [ GetNotificationSettings ]
-- Returns current notification settings (legacy compatibility)
-- Returns table with chat and raidWarn booleans based on mode
-- return:      [table]         {mode, chat, raidWarn}
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
-- 'enabled'    [boolean]       whether to enable chat notifications
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
-- 'enabled'    [boolean]       whether to enable raid warning notifications
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

-- =====================
-- NOTIFICATION QUEUE
-- =====================

-- On-screen notification queue system
DBB2.notificationQueue = {}
DBB2.notificationActive = false
DBB2.notificationTimer = 0

-- Constants for notification timing
local NOTIFICATION_DURATION = 3  -- seconds per notification (display time)
local NOTIFICATION_FADE_BUFFER = 5  -- extra time for fade out before next

-- [ ProcessNotificationQueue ]
-- Process the notification queue (local function)
local function ProcessNotificationQueue()
  if DBB2.notificationActive then return end
  if table_getn(DBB2.notificationQueue) == 0 then return end
  
  -- Get next notification from queue
  local notification = table_remove(DBB2.notificationQueue, 1)
  
  -- Show it
  UIErrorsFrame:AddMessage(notification.text, notification.r, notification.g, notification.b, 1.0, NOTIFICATION_DURATION)
  
  -- Play sound if enabled
  if notification.playSound then
    PlaySoundFile("Interface\\AddOns\\DifficultBulletinBoard\\sound\\duck.wav")
  end
  
  -- Mark as active and set timer (duration + fade buffer)
  DBB2.notificationActive = true
  DBB2.notificationTimer = GetTime() + NOTIFICATION_DURATION + NOTIFICATION_FADE_BUFFER
end

-- [ QueueScreenNotification ]
-- Queue an on-screen notification (local function)
-- 'text'       [string]        the notification text
-- 'r'          [number]        red color component (0-1)
-- 'g'          [number]        green color component (0-1)
-- 'b'          [number]        blue color component (0-1)
-- 'playSound'  [boolean]       whether to play notification sound
local function QueueScreenNotification(text, r, g, b, playSound)
  table_insert(DBB2.notificationQueue, {
    text = text,
    r = r,
    g = g,
    b = b,
    playSound = playSound
  })
  ProcessNotificationQueue()
end

-- =====================
-- NOTIFICATION FRAME
-- =====================

-- Create a frame to handle the queue timer
local notificationFrame = CreateFrame("Frame")
notificationFrame:SetScript("OnUpdate", function()
  if DBB2.notificationActive and GetTime() >= DBB2.notificationTimer then
    DBB2.notificationActive = false
    ProcessNotificationQueue()
  end
end)

-- =====================
-- QUEUE MANAGEMENT
-- =====================

-- [ ClearNotificationQueue ]
-- Clears all pending notifications from the queue
-- Called when joining a group (if clearNotificationsOnGroupJoin is enabled)
function DBB2.api.ClearNotificationQueue()
  DBB2.notificationQueue = {}
  DBB2.notificationActive = false
  DBB2.notificationTimer = 0
end

-- [ DisableAllNotifications ]
-- Disables notifications for all categories and clears the pending queue
-- Called when joining a group (if clearNotificationsOnGroupJoin is enabled)
function DBB2.api.DisableAllNotifications()
  -- Clear the notification state for all category types
  DBB2.notificationState = NewNotificationState()
  if DBB2_Config.persistNotifications then
    -- keep the saved copy pointed at the live table, otherwise it would detach
    -- from DBB2.notificationState and stop recording later toggles
    DBB2_Config.notificationState = DBB2.notificationState
  end
  
  -- Also clear any pending notifications in the queue
  DBB2.api.ClearNotificationQueue()
  
  -- Update GUI bell icons if visible
  if DBB2.gui and DBB2.gui:IsShown() and DBB2.gui.tabs then
    local panels = {"Groups", "Professions", "Hardcore"}
    for _, panelName in ipairs(panels) do
      local panel = DBB2.gui.tabs.panels[panelName]
      if panel and panel.UpdateCategories then
        panel.UpdateCategories()
      end
    end
  end
end

-- =====================
-- NOTIFICATION SENDING
-- =====================

-- [ SendNotification ]
-- Sends a notification for a matched category
-- 'categoryName'   [string]        the category name that matched
-- 'sender'         [string]        the message sender
-- 'message'        [string]        the message text
function DBB2.api.SendNotification(categoryName, sender, message, diagnosticID)
  local settings = DBB2.api.GetNotificationSettings()
  
  -- Guard against nil values
  categoryName = categoryName or "Unknown"
  sender = sender or "Unknown"
  message = message or ""
  
  -- Get highlight color for notification text
  local hr, hg, hb = DBB2:GetHighlightColor()
  local hexColor = string_format("%02x%02x%02x", hr * 255, hg * 255, hb * 255)
  -- Wrap the sender in a player hyperlink so the chat line can be left-clicked to
  -- open a whisper. Hardcore/system alerts have no real sender, so only link a
  -- name we actually have -- a link around "Unknown" would just be a dead click.
  local senderText = sender
  if sender ~= "Unknown" and sender ~= "" then
    senderText = "|Hplayer:" .. sender .. "|h[" .. sender .. "]|h"
  end
  local notifyText = "|cff" .. hexColor .. "[DBB]|r " .. categoryName .. " - " .. senderText .. ": " .. message
  
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

  if DBB2.debug.enabled and not DBB2.debug.paused then
    DBB2.api.DebugCount("notifications.sent", 1)
    DBB2.api.DebugTrace(2, "notify", "sent", "category=" .. categoryName .. " sender=" .. sender .. " chat=" .. tostring(settings.chat) .. " screen=" .. tostring(settings.raidWarn) .. " sound=" .. tostring(playSound))
  end
end

-- [ CheckAndNotify ]
-- Checks if message matches any category with notifications enabled and sends notification
-- IMPORTANT: System messages (CHAT_MSG_SYSTEM) only trigger hardcore notifications,
-- never groups/professions. This prevents zone names in death messages from triggering dungeon alerts.
-- 'message'    [string]        the message text
-- 'sender'     [string]        the message sender
-- 'msgType'    [string]        optional message type (CHAT_MSG_SYSTEM, CHAT_MSG_CHANNEL, etc)
function DBB2.api.CheckAndNotify(message, sender, msgType, diagnosticID)
  local debugging = DBB2.debug.enabled and not DBB2.debug.paused
  local debugStart = nil
  if debugging then debugStart = DBB2.api.DebugClock() end
  if not DBB2.notificationState then
    if debugging then
      DBB2.api.DebugTrace(3, "notify", "skipped", "reason=notification state unavailable")
    end
    return
  end
  
  -- System messages should ONLY trigger hardcore notifications
  -- This prevents false positives like "Golbolar Quarry" in death messages
  -- triggering alerts for "Hateforge Quarry"
  local isSystemMessage = (msgType == "CHAT_MSG_SYSTEM")
  
  local categoryTypes = {"groups", "professions", "hardcore"}
  
  for _, categoryType in ipairs(categoryTypes) do
    -- Skip groups/professions for system messages
    if isSystemMessage and categoryType ~= "hardcore" then
      -- Do nothing, skip this category type
    else
      local categories = DBB2.api.GetCategories(categoryType)
      if categories then
        for _, cat in ipairs(categories) do
          if cat.selected and DBB2.api.IsNotificationEnabled(categoryType, cat.name) then
            if DBB2.api.MatchMessageToCategory(message, cat, nil, categoryType) then
              DBB2.api.SendNotification(cat.name, sender, message, diagnosticID)
              if debugging then DBB2.api.DebugPerf("CheckAndNotify", DBB2.api.DebugClock() - debugStart) end
              return  -- Only notify once per message
            end
          end
        end
      end
    end
  end
  if debugging then
    local elapsed = DBB2.api.DebugClock() - debugStart
    DBB2.api.DebugPerf("CheckAndNotify", elapsed)
  end
end
