-- DBB2 Config Module
-- All config tabs use the same declarative schema system

DBB2:RegisterModule("config", function()
  if not DBB2.gui or not DBB2.gui.tabs or not DBB2.gui.tabs.panels or not DBB2.gui.tabs.panels["Config"] then
    DEFAULT_CHAT_FRAME:AddMessage("DBB2: ERROR - Config panel not ready")
    return
  end
  
  local configPanel = DBB2.gui.tabs.panels["Config"]
  
  -- Scroll update on show
  local originalConfigOnShow = configPanel:GetScript("OnShow")
  configPanel:SetScript("OnShow", function()
    if originalConfigOnShow then originalConfigOnShow() end
    if DBB2.gui.configTabs and DBB2.gui.configTabs.activeTab then
      local activePanel = DBB2.gui.configTabs.panels[DBB2.gui.configTabs.activeTab]
      if activePanel and activePanel.scrollFrame then
        activePanel.scrollFrame._needsScrollUpdate = true
      end
    end
  end)
  
  -- Position config panel
  configPanel:ClearAllPoints()
  configPanel:SetPoint("TOPLEFT", DBB2.gui.tabs.content, "TOPLEFT", 0, 0)
  configPanel:SetPoint("BOTTOMRIGHT", DBB2.gui.tabs.content, "BOTTOMRIGHT", 0, 0)
  
  -- Create tab system
  local configTabs = {"General", "Channels", "Groups", "Professions", "Hardcore", "Blacklist"}
  DBB2.gui.configTabs = DBB2.schema.CreateTabSystem("DBB2Config", configPanel, configTabs, 90, 14)
  
  -- Position tab buttons vertically on right side
  local buttonWidth = DBB2:ScaleSize(90)
  local buttonHeight = DBB2:ScaleSize(14)
  local buttonSpacing = DBB2:ScaleSize(3)
  local padding = DBB2:ScaleSize(5)
  local versionArtHeight = DBB2:ScaleSize(55)
  
  for i, tabName in ipairs(configTabs) do
    local btn = DBB2.gui.configTabs.buttons[tabName]
    btn:ClearAllPoints()
    btn:SetWidth(buttonWidth)
    btn:SetHeight(buttonHeight)
    btn:SetParent(DBB2.gui.configTabs.content)
    local extraSpacing = (tabName == "Blacklist") and buttonHeight or 0
    btn:SetPoint("TOPRIGHT", DBB2.gui.configTabs.content, "TOPRIGHT", -padding, -padding - versionArtHeight - ((i - 1) * (buttonHeight + buttonSpacing)) - extraSpacing)
  end
  
  DBB2.gui.configTabs.content:ClearAllPoints()
  DBB2.gui.configTabs.content:SetPoint("TOPLEFT", configPanel, "TOPLEFT", 0, 0)
  DBB2.gui.configTabs.content:SetPoint("BOTTOMRIGHT", configPanel, "BOTTOMRIGHT", 0, 0)
  
  if DBB2.gui.configTabs.content.backdrop then
    DBB2.gui.configTabs.content.backdrop:Hide()
  end
  
  -- Adjust tab panels
  local separatorPadding = DBB2:ScaleSize(7)
  for _, tabName in ipairs(configTabs) do
    local panel = DBB2.gui.configTabs.panels[tabName]
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", DBB2.gui.configTabs.content, "TOPLEFT", 0, 0)
    panel:SetPoint("BOTTOMRIGHT", DBB2.gui.configTabs.content, "BOTTOMRIGHT", -(buttonWidth + padding + 3 + separatorPadding), 0)
    panel._configTabName = tabName
  end
  
  -- Separator line
  local separatorLine = DBB2.gui.configTabs.content:CreateTexture(nil, "ARTWORK")
  separatorLine:SetWidth(1)
  separatorLine:SetPoint("TOP", DBB2.gui.configTabs.content, "TOPRIGHT", -(buttonWidth + padding + separatorPadding), 0)
  separatorLine:SetPoint("BOTTOM", DBB2.gui.configTabs.content, "BOTTOMRIGHT", -(buttonWidth + padding + separatorPadding), 0)
  separatorLine:SetTexture(0.3, 0.3, 0.3, 0.8)
  
  -- Reset button
  local resetBtn = DBB2.schema.CreateButton("DBB2ResetBtn", DBB2.gui.configTabs.content, "Reset Defaults")
  resetBtn:SetPoint("BOTTOMRIGHT", DBB2.gui.configTabs.content, "BOTTOMRIGHT", -padding, padding)
  resetBtn:SetWidth(buttonWidth)
  resetBtn:SetHeight(buttonHeight)
  resetBtn.text:SetTextColor(1, 0.3, 0.3, 1)
  resetBtn:SetScript("OnEnter", function() this.backdrop:SetBackdropBorderColor(1, 0.3, 0.3, 1) end)
  resetBtn:SetScript("OnLeave", function() this.backdrop:SetBackdropBorderColor(0.3, 0.3, 0.3, 1) end)
  resetBtn:SetScript("OnClick", function()
    DBB2_Config.fontOffset = 0
    DBB2_Config.backgroundColor = {r = 0.08, g = 0.08, b = 0.10, a = 0.85}
    DBB2_Config.highlightColor = {r = 0.667, g = 0.655, b = 0.8, a = 1}
    DBB2_Config.spamFilterSeconds = 150
    DBB2_Config.messageExpireMinutes = 15
    DBB2_Config.hideFromChat = 0
    DBB2_Config.maxMessagesPerCategory = 5
    DBB2_Config.scrollSpeed = 55
    DBB2_Config.defaultTab = 0
    DBB2_Config.notificationSound = 1
    DBB2_Config.showCurrentTime = false
    DBB2_Config.timeDisplayMode = 0
    DBB2_Config.showLevelFilteredGroups = false
    DBB2_Config.clearNotificationsOnGroupJoin = true
    DBB2_Config.autoJoinChannels = true
    DBB2_Config.clampToScreen = true
    DBB2_Config.minimapAngle = 45
    DBB2_Config.minimapFreeMode = false
    DBB2_Config.minimapFreePos = nil
    DBB2_Config.notifications = { mode = 0 }
    DBB2_Config.blacklist = { enabled = true, hideFromChat = true, players = {}, keywords = {"recruit*", "recrut*", "<*>", "\\[???\\]", "\\[??\\]"} }
    DBB2_Config.hardcoreChannelsInitialized = nil
    DBB2.api.ResetChannelDefaults()
    DBB2_Config.position = nil
    if DBB2.modules.ResetCategoriesToDefaults then DBB2.modules.ResetCategoriesToDefaults() end
    ReloadUI()
  end)
  
  -- Reload button
  local reloadBtn = DBB2.schema.CreateButton("DBB2ReloadBtn", DBB2.gui.configTabs.content, "Save & Reload")
  reloadBtn:SetPoint("BOTTOMRIGHT", resetBtn, "TOPRIGHT", 0, buttonSpacing)
  reloadBtn:SetWidth(buttonWidth)
  reloadBtn:SetHeight(buttonHeight)
  reloadBtn.text:SetTextColor(0.7, 0.7, 0.7, 1)
  reloadBtn:SetScript("OnClick", function()
    for _, panelName in ipairs({"Groups", "Professions", "Hardcore"}) do
      local panel = DBB2.gui.configTabs.panels[panelName]
      if panel and panel.categoryRows then
        for _, row in ipairs(panel.categoryRows) do
          if row and row.tagsInput and row.categoryType and row.categoryName then
            DBB2.api.UpdateCategoryTags(row.categoryType, row.categoryName, DBB2.api.ParseTagsString(row.tagsInput:GetText()))
          end
        end
      end
      if panel and panel.filterTagsInput and panel.filterCategoryType then
        DBB2.api.UpdateFilterTags(panel.filterCategoryType, DBB2.api.ParseTagsString(panel.filterTagsInput:GetText()))
      end
    end
    ReloadUI()
  end)
  
  -- Version art
  local hr, hg, hb = DBB2:GetHighlightColor()
  local versionFrame = CreateFrame("Frame", "DBB2VersionArt", DBB2.gui.configTabs.content)
  versionFrame:SetWidth(buttonWidth)
  versionFrame:SetHeight(DBB2:ScaleSize(36))
  versionFrame:SetPoint("BOTTOMRIGHT", DBB2.gui.configTabs.buttons["General"], "TOPRIGHT", 0, DBB2:ScaleSize(14))
  
  versionFrame.difficult = versionFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  versionFrame.difficult:SetFont("Fonts\\FRIZQT__.TTF", DBB2:GetFontSize(11))
  versionFrame.difficult:SetPoint("TOPLEFT", 0, 0)
  versionFrame.difficult:SetText("Difficult")
  versionFrame.difficult:SetTextColor(hr, hg, hb, 1)
  
  versionFrame.name = versionFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  versionFrame.name:SetFont("Fonts\\FRIZQT__.TTF", DBB2:GetFontSize(11))
  versionFrame.name:SetPoint("TOPRIGHT", 0, -(DBB2:GetFontSize(11) + DBB2:ScaleSize(1)))
  versionFrame.name:SetText("BulletinBoard")
  versionFrame.name:SetTextColor(1, 1, 1, 1)
  
  versionFrame.version = versionFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  versionFrame.version:SetFont("Fonts\\FRIZQT__.TTF", DBB2:GetFontSize(9))
  versionFrame.version:SetPoint("TOPRIGHT", versionFrame.name, "BOTTOMRIGHT", 0, -2)
  versionFrame.version:SetText("v" .. (GetAddOnMetadata("DifficultBulletinBoard", "Version") or "?"))
  versionFrame.version:SetTextColor(0.5, 0.5, 0.5, 1)


  -- Initialize APIs
  DBB2.api.InitNotificationConfig()
  DBB2.api.InitChannelConfig()
  DBB2.api.InitBlacklist()
  DBB2_Config.notificationMode = DBB2.api.GetNotificationMode()

  -- =====================
  -- GENERAL TAB
  -- =====================
  DBB2.api.RenderConfigSchema(DBB2.gui.configTabs.panels["General"], {
    { type = "section", label = "Display Settings" },
    { type = "slider", key = "defaultTab", label = "Default Tab", min = 0, max = 3, step = 1,
      valueLabels = {[0] = "Logs", [1] = "Groups", [2] = "Professions", [3] = "Hardcore"},
      tooltip = {{"Default Tab", "highlight"}, "The tab shown when opening the GUI."} },
    { type = "slider", key = "fontOffset", label = "Font Size Offset", min = -4, max = 4, step = 1,
      tooltip = {{"Font Size Offset", "highlight"}, "Adjusts all text sizes.", {"Requires /reload", "gray"}},
      onChange = function(val)
        if DBB2.gui.resizeGrip then
          local s = 1 + (val * 0.1)
          DBB2.gui.resizeGrip.minWidth = math.floor(410 * s + 0.5)
          DBB2.gui.resizeGrip.minHeight = math.floor(275 * s + 0.5)
        end
      end },
    { type = "colorpicker", key = "backgroundColor", label = "Background Color",
      default = {r = 0.08, g = 0.08, b = 0.10, a = 0.85},
      tooltip = {{"Background Color", "highlight"}, {"Requires /reload", "gray"}} },
    { type = "colorpicker", key = "highlightColor", label = "Highlight Color",
      default = {r = 0.2, g = 1, b = 0.8, a = 1},
      tooltip = {{"Highlight Color", "highlight"}, {"Requires /reload", "gray"}} },
    { type = "toggle", key = "showCurrentTime", label = "Show Current Time",
      tooltip = {{"Show Current Time", "highlight"}, "Display current time above timestamps."},
      onChange = function(enabled)
        for _, p in ipairs({"Logs", "Groups", "Professions", "Hardcore"}) do
          local panel = DBB2.gui.tabs.panels[p]
          if panel and panel.currentTimeText then
            if enabled then panel.currentTimeText:Show() else panel.currentTimeText:Hide() end
          end
        end
      end },
    { type = "slider", key = "timeDisplayMode", label = "Time Format", min = 0, max = 2, step = 1,
      valueLabels = {[0] = "Timestamp", [1] = "Relative", [2] = "Elapsed"},
      tooltip = {{"Time Format", "highlight"}, "Timestamp: 14:32:15", "Relative: <1m, 2m, 15m, 1h", "Elapsed: 05:30 (red at 59:59)"},
      onChange = function(val)
        -- Refresh all panels to update timestamp display
        if DBB2.gui and DBB2.gui:IsShown() then
          if DBB2.gui.UpdateMessages then DBB2.gui:UpdateMessages() end
          for _, p in ipairs({"Groups", "Professions", "Hardcore"}) do
            local panel = DBB2.gui.tabs.panels[p]
            if panel and panel.UpdateCategories then panel.UpdateCategories() end
          end
        end
      end },
    
    { type = "section", label = "Miscellaneous" },
    { type = "toggle", key = "clampToScreen", label = "Clamp to Screen", default = true,
      tooltip = {{"Clamp to Screen", "highlight"}, "Prevent dragging the main window off-screen."},
      onChange = function(enabled)
        if DBB2.gui then
          DBB2.gui:SetClampedToScreen(enabled)
        end
      end },
    { type = "slider", key = "scrollSpeed", label = "Scroll Speed", min = 10, max = 100, step = 5,
      tooltip = {{"Scroll Speed", "highlight"}, "Pixels per mouse wheel tick."} },
    { type = "toggle", key = "showLevelFilteredGroups", label = "Level Filter (Groups)",
      tooltip = {{"Level Filter", "highlight"}, "Only show level-appropriate categories."},
      onChange = function()
        local gp = DBB2.gui.tabs.panels["Groups"]
        if gp and gp.UpdateCategories and gp:IsVisible() then gp.UpdateCategories() end
      end },
    
    { type = "section", label = "Notifications" },
    { type = "slider", key = "notificationMode", label = "Mode", min = 0, max = 3, step = 1,
      valueLabels = {[0] = "Off", [1] = "Chat", [2] = "Raid Warning", [3] = "Both"},
      tooltip = {{"Notification Mode", "highlight"}, "How to display notifications."},
      onChange = function(val) DBB2.api.SetNotificationMode(val) end },
    { type = "slider", key = "notificationSound", label = "Sound", min = 0, max = 1, step = 1,
      valueLabels = {[0] = "Off", [1] = "On"},
      tooltip = {{"Sound", "highlight"}, "Play sound on notification."} },
    { type = "toggle", key = "clearNotificationsOnGroupJoin", label = "Auto-Clear", default = true,
      tooltip = {{"Auto-Clear", "highlight"}, "Clear notifications when joining group."} },
    
    { type = "section", label = "Spam Prevention" },
    { type = "slider", key = "messageExpireMinutes", label = "Auto-Remove (minutes)", min = 0, max = 30, step = 1,
      tooltip = {{"Auto-Remove", "highlight"}, "Remove old messages.", {"0 = disabled", "gray"}} },
    { type = "slider", key = "spamFilterSeconds", label = "Duplicate Filter (seconds)", min = 0, max = 300, step = 10,
      tooltip = {{"Duplicate Filter", "highlight"}, "Hide duplicate messages.", {"0 = disabled", "gray"}} },
    { type = "slider", key = "hideFromChat", label = "Hide from Chat", min = 0, max = 2, step = 1,
      valueLabels = {[0] = "Disabled", [1] = "Selected", [2] = "All"},
      tooltip = {{"Hide from Chat", "highlight"}, "Hide captured messages from chat."} },
    { type = "slider", key = "maxMessagesPerCategory", label = "Messages per Category", min = 0, max = 10, step = 1,
      tooltip = {{"Messages per Category", "highlight"}, {"0 = unlimited", "gray"}} },
  })

  -- =====================
  -- CHANNELS TAB
  -- =====================
  DBB2.api.RenderConfigSchema(DBB2.gui.configTabs.panels["Channels"], {
    { type = "section", label = "Monitored Channels" },
    { type = "description", text = "Select which channels to monitor for LFG messages." },
    { type = "checkbox", key = "autoJoinChannels", label = "Auto-join World & LookingForGroup", default = true,
      tooltip = {{"Auto-Join", "highlight"}, "Join channels automatically at login."} },
    { type = "section", label = "Channel List" },
    { type = "channelList" },
  })

  -- =====================
  -- GROUPS TAB
  -- =====================
  DBB2.api.RenderConfigSchema(DBB2.gui.configTabs.panels["Groups"], {
    { type = "section", label = "Groups - Edit Tags" },
    { type = "description", text = "Edit tags to customize which messages match each category." },
    { type = "description", text = "Wildcards: * (any), ? (one char), [a-z], {a,b}", fontSize = 8 },
    { type = "categoryList", categoryType = "groups", showFilterTags = true },
  })

  -- =====================
  -- PROFESSIONS TAB
  -- =====================
  DBB2.api.RenderConfigSchema(DBB2.gui.configTabs.panels["Professions"], {
    { type = "section", label = "Professions - Edit Tags" },
    { type = "description", text = "Edit tags to customize which messages match each category." },
    { type = "description", text = "Wildcards: * (any), ? (one char), [a-z], {a,b}", fontSize = 8 },
    { type = "categoryList", categoryType = "professions", showFilterTags = true },
  })

  -- =====================
  -- HARDCORE TAB
  -- =====================
  DBB2.api.RenderConfigSchema(DBB2.gui.configTabs.panels["Hardcore"], {
    { type = "section", label = "Hardcore - Edit Tags" },
    { type = "description", text = "Edit tags to customize which messages match each category." },
    { type = "description", text = "Wildcards: * (any), ? (one char), [a-z], {a,b}", fontSize = 8 },
    { type = "categoryList", categoryType = "hardcore", showFilterTags = false },
  })

  -- =====================
  -- BLACKLIST TAB
  -- =====================
  -- Set config keys from API for checkbox binding
  DBB2_Config.blacklistEnabled = DBB2.api.IsBlacklistEnabled()
  DBB2_Config.blacklistHideFromChat = DBB2.api.IsBlacklistHideFromChatEnabled()
  
  DBB2.api.RenderConfigSchema(DBB2.gui.configTabs.panels["Blacklist"], {
    { type = "section", label = "Blacklist Management" },
    { type = "description", text = "Block messages containing specific keywords." },
    { type = "checkbox", key = "blacklistEnabled", label = "Enable Blacklist Filtering",
      onChange = function(checked) DBB2.api.SetBlacklistEnabled(checked) end },
    { type = "checkbox", key = "blacklistHideFromChat", label = "Hide messages from Chat",
      tooltip = {{"Hide from Chat", "highlight"}, "Also hide blacklisted messages from chat."},
      onChange = function(checked) DBB2.api.SetBlacklistHideFromChat(checked) end },
    { type = "section", label = "Import / Export" },
    { type = "description", text = "Copy to export, paste and press Enter to import.", fontSize = 8 },
    { type = "keywordImportExport" },
    { type = "section", label = "Keywords" },
    { type = "description", text = "Wildcards: * (any), ? (one char), [a-z], {a,b}", fontSize = 8 },
    { type = "keywordList" },
  })

  -- Set default tab
  DBB2.gui.configTabs.SwitchTab("General")
end)
