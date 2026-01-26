-- DBB2 Config Module
-- Handles addon configuration UI and settings

DBB2:RegisterModule("config", function()
  -- Check if GUI exists
  if not DBB2.gui or not DBB2.gui.tabs or not DBB2.gui.tabs.panels or not DBB2.gui.tabs.panels["Config"] then
    DEFAULT_CHAT_FRAME:AddMessage("DBB2: ERROR - Config panel not ready")
    return
  end
  
  local configPanel = DBB2.gui.tabs.panels["Config"]
  
  -- When Config panel is shown, trigger scroll update for the active config tab
  local originalConfigOnShow = configPanel:GetScript("OnShow")
  configPanel:SetScript("OnShow", function()
    if originalConfigOnShow then originalConfigOnShow() end
    -- Defer scroll update for the active config tab's scroll frame
    if DBB2.gui.configTabs and DBB2.gui.configTabs.activeTab then
      local activePanel = DBB2.gui.configTabs.panels[DBB2.gui.configTabs.activeTab]
      if activePanel and activePanel.scrollFrame then
        activePanel.scrollFrame._needsScrollUpdate = true
      end
    end
  end)
  
  -- Reposition Config panel to fill the content area completely (remove default 2px inset)
  configPanel:ClearAllPoints()
  configPanel:SetPoint("TOPLEFT", DBB2.gui.tabs.content, "TOPLEFT", 0, 0)
  configPanel:SetPoint("BOTTOMRIGHT", DBB2.gui.tabs.content, "BOTTOMRIGHT", 0, 0)
  
  -- Create tab system for config (vertical tabs on right side inside content)
  local configTabs = {"General", "Channels", "Groups", "Professions", "Hardcore", "Blacklist"}
  DBB2.gui.configTabs = DBB2.api.CreateTabSystem("DBB2Config", configPanel, configTabs, 90, 14)
  
  -- Reposition the tab buttons vertically stacked inside the content area (top-right)
  local buttonWidth = DBB2:ScaleSize(90)
  local buttonHeight = DBB2:ScaleSize(14)
  local buttonSpacing = DBB2:ScaleSize(3)
  local padding = DBB2:ScaleSize(5)
  local versionArtHeight = DBB2:ScaleSize(55)  -- Space for version art above buttons
  
  for i, tabName in ipairs(configTabs) do
    local btn = DBB2.gui.configTabs.buttons[tabName]
    btn:ClearAllPoints()
    btn:SetWidth(buttonWidth)
    btn:SetHeight(buttonHeight)
    btn:SetParent(DBB2.gui.configTabs.content)
    
    -- Add extra spacing before Blacklist button (equal to button height)
    local extraSpacing = 0
    if tabName == "Blacklist" then
      extraSpacing = buttonHeight
    end
    
    btn:SetPoint("TOPRIGHT", DBB2.gui.configTabs.content, "TOPRIGHT", -padding, -padding - versionArtHeight - ((i - 1) * (buttonHeight + buttonSpacing)) - extraSpacing)
  end
  
  -- Content area fills the config panel
  DBB2.gui.configTabs.content:ClearAllPoints()
  DBB2.gui.configTabs.content:SetPoint("TOPLEFT", configPanel, "TOPLEFT", 0, 0)
  DBB2.gui.configTabs.content:SetPoint("BOTTOMRIGHT", configPanel, "BOTTOMRIGHT", 0, 0)
  
  -- Remove the extra backdrop from config tabs content (parent already has one)
  if DBB2.gui.configTabs.content.backdrop then
    DBB2.gui.configTabs.content.backdrop:Hide()
  end
  
  -- Adjust tab panels to not overlap with vertical buttons (extra 5px for separator padding)
  local separatorPadding = DBB2:ScaleSize(7)
  for _, tabName in ipairs(configTabs) do
    local panel = DBB2.gui.configTabs.panels[tabName]
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", DBB2.gui.configTabs.content, "TOPLEFT", 0, 0)
    panel:SetPoint("BOTTOMRIGHT", DBB2.gui.configTabs.content, "BOTTOMRIGHT", -(buttonWidth + padding + 3 + separatorPadding), 0)
    
    -- Store the panel name for the OnShow script
    panel._configTabName = tabName
    
    -- Reposition on show to ensure correct sizing
    local originalOnShow = panel:GetScript("OnShow")
    panel:SetScript("OnShow", function()
      this:ClearAllPoints()
      this:SetPoint("TOPLEFT", DBB2.gui.configTabs.content, "TOPLEFT", 0, 0)
      this:SetPoint("BOTTOMRIGHT", DBB2.gui.configTabs.content, "BOTTOMRIGHT", -(buttonWidth + padding + 3 + separatorPadding), 0)
      if originalOnShow then
        originalOnShow()
      end
    end)
  end
  
  -- Vertical separator line between content and right sidebar (5px padding on each side)
  local separatorLine = DBB2.gui.configTabs.content:CreateTexture(nil, "ARTWORK")
  separatorLine:SetWidth(1)
  separatorLine:SetPoint("TOP", DBB2.gui.configTabs.content, "TOPRIGHT", -(buttonWidth + padding + separatorPadding), 0)
  separatorLine:SetPoint("BOTTOM", DBB2.gui.configTabs.content, "BOTTOMRIGHT", -(buttonWidth + padding + separatorPadding), 0)
  separatorLine:SetTexture(0.3, 0.3, 0.3, 0.8)
  
  -- Reset to Defaults button (dangerous red button at bottom-right)
  local resetBtn = DBB2.api.CreateButton("DBB2ResetBtn", DBB2.gui.configTabs.content, "Reset Defaults")
  resetBtn:SetPoint("BOTTOMRIGHT", DBB2.gui.configTabs.content, "BOTTOMRIGHT", -padding, padding)
  resetBtn:SetWidth(DBB2:ScaleSize(90))
  resetBtn:SetHeight(buttonHeight)
  resetBtn.text:SetTextColor(1, 0.3, 0.3, 1)
  
  resetBtn:SetScript("OnEnter", function()
    this.backdrop:SetBackdropBorderColor(1, 0.3, 0.3, 1)
  end)
  
  resetBtn:SetScript("OnLeave", function()
    this.backdrop:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
  end)
  
  resetBtn:SetScript("OnClick", function()
    -- Reset all settings to defaults
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
    DBB2_Config.showLevelFilteredGroups = false
    DBB2_Config.clearNotificationsOnGroupJoin = true
    DBB2_Config.autoJoinChannels = true
    -- Reset notifications to defaults (mode 0 = off)
    DBB2_Config.notifications = { mode = 0 }
    -- Reset blacklist to defaults
    DBB2_Config.blacklist = {
      enabled = true,
      hideFromChat = true,
      players = {},
      keywords = {"recruit*", "recrut*", "<*>", "[???]", "[??]"}
    }
    -- Reset monitored channels to defaults (handles hardcore vs normal)
    -- Clear the initialized flag so hardcore defaults can be re-applied
    DBB2_Config.hardcoreChannelsInitialized = nil
    DBB2.api.ResetChannelDefaults()
    -- Reset GUI position and size to defaults
    DBB2_Config.position = nil
    -- Reset categories to defaults (lives in modules namespace, not api)
    if DBB2.modules.ResetCategoriesToDefaults then
      DBB2.modules.ResetCategoriesToDefaults()
    end
    -- Reload to apply
    ReloadUI()
  end)
  
  -- Save & Reload button (above Reset Defaults)
  local reloadBtn = DBB2.api.CreateButton("DBB2ReloadBtn", DBB2.gui.configTabs.content, "Save & Reload")
  reloadBtn:SetPoint("BOTTOMRIGHT", resetBtn, "TOPRIGHT", 0, buttonSpacing)
  reloadBtn:SetWidth(DBB2:ScaleSize(90))
  reloadBtn:SetHeight(buttonHeight)
  reloadBtn.text:SetTextColor(0.7, 0.7, 0.7, 1)
  reloadBtn:SetScript("OnClick", function()
    -- Save any pending tag changes from category config panels before reload
    -- This handles the case where user types in a field but doesn't press Enter or lose focus
    local categoryPanels = {"Groups", "Professions", "Hardcore"}
    for _, panelName in ipairs(categoryPanels) do
      local panel = DBB2.gui.configTabs.panels[panelName]
      if panel then
        -- Save category tags
        if panel.categoryRows then
          for _, row in ipairs(panel.categoryRows) do
            if row and row.tagsInput and row.categoryType and row.categoryName then
              local newTags = DBB2.api.ParseTagsString(row.tagsInput:GetText())
              DBB2.api.UpdateCategoryTags(row.categoryType, row.categoryName, newTags)
            end
          end
        end
        -- Save filter tags (Groups and Professions only)
        if panel.filterTagsInput and panel.filterCategoryType then
          local newTags = DBB2.api.ParseTagsString(panel.filterTagsInput:GetText())
          DBB2.api.UpdateFilterTags(panel.filterCategoryType, newTags)
        end
      end
    end
    ReloadUI()
  end)
  
  -- Version art (above the General button)
  local generalBtn = DBB2.gui.configTabs.buttons["General"]
  local versionFrame = CreateFrame("Frame", "DBB2VersionArt", DBB2.gui.configTabs.content)
  versionFrame:SetWidth(DBB2:ScaleSize(90))
  versionFrame:SetHeight(DBB2:ScaleSize(36))
  versionFrame:SetPoint("BOTTOMRIGHT", generalBtn, "TOPRIGHT", 0, DBB2:ScaleSize(14))
  
  -- "Difficult" text with highlight color (left aligned)
  local hr, hg, hb = DBB2:GetHighlightColor()
  versionFrame.difficult = versionFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  versionFrame.difficult:SetFont("Fonts\\FRIZQT__.TTF", DBB2:GetFontSize(11))
  versionFrame.difficult:SetPoint("TOPLEFT", versionFrame, "TOPLEFT", 0, 0)
  versionFrame.difficult:SetText("Difficult")
  versionFrame.difficult:SetTextColor(hr, hg, hb, 1)
  versionFrame.difficult:SetJustifyH("LEFT")
  
  -- "BulletinBoard 2" text in white (right aligned, anchored to frame's right edge)
  versionFrame.name = versionFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  versionFrame.name:SetFont("Fonts\\FRIZQT__.TTF", DBB2:GetFontSize(11))
  versionFrame.name:SetPoint("TOPRIGHT", versionFrame, "TOPRIGHT", 0, -(DBB2:GetFontSize(11) + DBB2:ScaleSize(1)))
  versionFrame.name:SetText("BulletinBoard")
  versionFrame.name:SetTextColor(1, 1, 1, 1)
  versionFrame.name:SetJustifyH("RIGHT")
  
  -- Version number in gray (right aligned, anchored to frame's right edge)
  versionFrame.version = versionFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  versionFrame.version:SetFont("Fonts\\FRIZQT__.TTF", DBB2:GetFontSize(9))
  versionFrame.version:SetPoint("TOPRIGHT", versionFrame.name, "BOTTOMRIGHT", 0, -2)
  versionFrame.version:SetText("v" .. (GetAddOnMetadata("DifficultBulletinBoard", "Version") or "?"))
  versionFrame.version:SetTextColor(0.5, 0.5, 0.5, 1)
  versionFrame.version:SetJustifyH("RIGHT")
  
  -- =====================
  -- GENERAL TAB
  -- =====================
  local generalPanel = DBB2.gui.configTabs.panels["General"]
  
  -- Create static scroll frame for General tab (fixed content height)
  local generalScroll = DBB2.api.CreateStaticScrollFrame("DBB2GeneralScroll", generalPanel)
  generalScroll:SetPoint("TOPLEFT", generalPanel, "TOPLEFT", 0, 0)
  generalScroll:SetPoint("BOTTOMRIGHT", generalPanel, "BOTTOMRIGHT", 0, 0)
  generalPanel.scrollFrame = generalScroll
  
  -- Add padding to scrollbar
  local sliderPadding = DBB2:ScaleSize(5)
  generalScroll.slider:ClearAllPoints()
  generalScroll.slider:SetPoint("TOPRIGHT", generalScroll, "TOPRIGHT", 0, -sliderPadding)
  generalScroll.slider:SetPoint("BOTTOMRIGHT", generalScroll, "BOTTOMRIGHT", 0, sliderPadding)
  
  -- Content container with fixed height for all settings
  -- Height calculated to fit all content with ScaleSize(5) bottom padding (matching main GUI)
  local contentHeight = DBB2:ScaleSize(638)
  local generalScrollChild = DBB2.api.CreateStaticScrollChild("DBB2GeneralScrollChild", generalScroll, contentHeight)
  
  -- Update scroll child width on size change
  local lastGeneralScrollWidth = 0
  generalScroll:SetScript("OnUpdate", function()
    if not this:IsVisible() then return end
    
    local scrollLeft = this:GetLeft()
    local scrollRight = this:GetRight()
    if not scrollLeft or not scrollRight then return end
    
    local scrollWidth = scrollRight - scrollLeft
    
    if scrollWidth > 0 and scrollWidth ~= lastGeneralScrollWidth then
      lastGeneralScrollWidth = scrollWidth
      generalScrollChild:SetWidth(scrollWidth)
      this.UpdateScrollState()
    end
  end)
  
  -- Section title
  local hr, hg, hb = DBB2:GetHighlightColor()
  local title = DBB2.api.CreateLabel(generalScrollChild, "Display Settings", 10)
  title:SetPoint("TOPLEFT", DBB2:ScaleSize(10), -DBB2:ScaleSize(10))
  title:SetTextColor(hr, hg, hb, 1)
  
  -- Default Tab slider (0 = Logs, 1 = Groups, 2 = Professions, 3 = Hardcore)
  local defaultTabNames = {
    [0] = "Logs",
    [1] = "Groups",
    [2] = "Professions",
    [3] = "Hardcore"
  }
  local currentDefaultTab = DBB2_Config.defaultTab or 0
  
  local defaultTabSlider = DBB2.api.CreateSlider("DBB2DefaultTabSlider", generalScrollChild, "Default Tab: " .. defaultTabNames[currentDefaultTab], 0, 3, 1, 9)
  defaultTabSlider:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -DBB2:ScaleSize(8))
  defaultTabSlider:SetWidth(DBB2:ScaleSize(250))
  defaultTabSlider:SetValue(currentDefaultTab)
  
  -- Add tooltip on hover
  defaultTabSlider.slider:SetScript("OnEnter", function()
    local r, g, b = DBB2:GetHighlightColor()
    this.backdrop:SetBackdropBorderColor(r, g, b, 1)
    DBB2.api.ShowTooltip(this, "RIGHT", {
      {"Default Tab", "highlight"},
      "The tab shown when opening the GUI.",
      {"0=Logs, 1=Groups, 2=Professions, 3=Hardcore", "gray"}
    })
  end)
  
  defaultTabSlider.slider:SetScript("OnLeave", function()
    this.backdrop:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
    DBB2.api.HideTooltip()
  end)
  
  -- Save on change and update label
  defaultTabSlider.OnValueChanged = function(val)
    DBB2_Config.defaultTab = val
    defaultTabSlider.label:SetText("Default Tab: " .. defaultTabNames[val])
  end
  
  -- Font Size Offset slider
  local fontSlider = DBB2.api.CreateSlider("DBB2FontOffsetSlider", generalScrollChild, "Font Size Offset", -4, 4, 1, 9)
  fontSlider:SetPoint("TOPLEFT", defaultTabSlider, "BOTTOMLEFT", 0, -DBB2:ScaleSize(11))
  fontSlider:SetWidth(DBB2:ScaleSize(250))
  fontSlider:SetValue(DBB2_Config.fontOffset or 0)
  
  -- Add tooltip on hover (attach to the slider child frame)
  fontSlider.slider:SetScript("OnEnter", function()
    local r, g, b = DBB2:GetHighlightColor()
    this.backdrop:SetBackdropBorderColor(r, g, b, 1)
    DBB2.api.ShowTooltip(this, "RIGHT", {
      {"Font Size Offset", "highlight"},
      "Adjusts all text sizes.",
      {"Requires /reload to fully apply.", "gray"}
    })
  end)
  
  fontSlider.slider:SetScript("OnLeave", function()
    this.backdrop:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
    DBB2.api.HideTooltip()
  end)
  
  -- Save on change (with safety clamping)
  fontSlider.OnValueChanged = function(val)
    -- Clamp to safe range
    if val < -4 then val = -4 end
    if val > 4 then val = 4 end
    DBB2_Config.fontOffset = val
    
    -- Update resize grip minimum size based on new font offset
    if DBB2.gui.resizeGrip then
      local baseMinWidth = 410
      local baseMinHeight = 275
      local scaleFactor = 1 + (val * 0.1)
      local newMinWidth = math.floor(baseMinWidth * scaleFactor + 0.5)
      local newMinHeight = math.floor(baseMinHeight * scaleFactor + 0.5)
      DBB2.gui.resizeGrip.minWidth = newMinWidth
      DBB2.gui.resizeGrip.minHeight = newMinHeight
      
      -- Enforce new minimums on current GUI size
      local currentWidth = DBB2.gui:GetWidth()
      local currentHeight = DBB2.gui:GetHeight()
      if currentWidth < newMinWidth then
        DBB2.gui:SetWidth(newMinWidth)
      end
      if currentHeight < newMinHeight then
        DBB2.gui:SetHeight(newMinHeight)
      end
    end
  end
  
  -- Background Color picker
  local bgColorPicker = DBB2.api.CreateColorPicker("DBB2BackgroundColor", generalScrollChild, "Background Color", 9)
  bgColorPicker:SetPoint("TOPLEFT", fontSlider, "BOTTOMLEFT", 0, -DBB2:ScaleSize(11))
  bgColorPicker:SetWidth(DBB2:ScaleSize(250))
  
  -- Load saved background color
  local bgc = DBB2_Config.backgroundColor or {r = 0.08, g = 0.08, b = 0.10, a = 0.85}
  bgColorPicker:SetColor(bgc.r, bgc.g, bgc.b, bgc.a)
  
  -- Add tooltip on hover
  bgColorPicker.button:SetScript("OnEnter", function()
    local r, g, b = DBB2:GetHighlightColor()
    this.backdrop:SetBackdropBorderColor(r, g, b, 1)
    DBB2.api.ShowTooltip(this, "RIGHT", {
      {"Background Color", "highlight"},
      "The main background color of the UI.",
      {"Requires /reload to fully apply.", "gray"}
    })
  end)
  
  bgColorPicker.button:SetScript("OnLeave", function()
    this.backdrop:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    DBB2.api.HideTooltip()
  end)
  
  -- Save on change
  bgColorPicker.OnColorChanged = function(r, g, b, a)
    DBB2_Config.backgroundColor = {r = r, g = g, b = b, a = a}
  end
  
  -- Highlight Color picker
  local colorPicker = DBB2.api.CreateColorPicker("DBB2HighlightColor", generalScrollChild, "Highlight Color", 9)
  colorPicker:SetPoint("TOPLEFT", bgColorPicker, "BOTTOMLEFT", 0, -DBB2:ScaleSize(11))
  colorPicker:SetWidth(DBB2:ScaleSize(250))
  
  -- Load saved color
  local hc = DBB2_Config.highlightColor or {r = 0.2, g = 1, b = 0.8, a = 1}
  colorPicker:SetColor(hc.r, hc.g, hc.b, hc.a)
  
  -- Add tooltip on hover (attach to the button child frame)
  colorPicker.button:SetScript("OnEnter", function()
    local r, g, b = DBB2:GetHighlightColor()
    this.backdrop:SetBackdropBorderColor(r, g, b, 1)
    DBB2.api.ShowTooltip(this, "RIGHT", {
      {"Highlight Color", "highlight"},
      "Used for active tabs, hover effects,",
      "and accents throughout the UI.",
      {"Requires /reload to fully apply.", "gray"}
    })
  end)
  
  colorPicker.button:SetScript("OnLeave", function()
    this.backdrop:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    DBB2.api.HideTooltip()
  end)
  
  -- Save on change
  colorPicker.OnColorChanged = function(r, g, b, a)
    DBB2_Config.highlightColor = {r = r, g = g, b = b, a = a}
  end
  
  -- Show Current Time toggle (0 = off, 1 = on)
  local showTimeEnabled = DBB2_Config.showCurrentTime and 1 or 0
  local showTimeNames = { [0] = "Off", [1] = "On" }
  local showTimeSlider = DBB2.api.CreateSlider("DBB2ShowTimeSlider", generalScrollChild, "Show Current Time: " .. showTimeNames[showTimeEnabled], 0, 1, 1, 9)
  showTimeSlider:SetPoint("TOPLEFT", colorPicker, "BOTTOMLEFT", 0, -DBB2:ScaleSize(11))
  showTimeSlider:SetWidth(DBB2:ScaleSize(250))
  showTimeSlider:SetValue(showTimeEnabled)
  
  -- Add tooltip on hover
  showTimeSlider.slider:SetScript("OnEnter", function()
    local r, g, b = DBB2:GetHighlightColor()
    this.backdrop:SetBackdropBorderColor(r, g, b, 1)
    DBB2.api.ShowTooltip(this, "RIGHT", {
      {"Show Current Time", "highlight"},
      "Display current time above timestamps."
    })
  end)
  
  showTimeSlider.slider:SetScript("OnLeave", function()
    this.backdrop:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
    DBB2.api.HideTooltip()
  end)
  
  showTimeSlider.OnValueChanged = function(value)
    DBB2_Config.showCurrentTime = (value == 1)
    showTimeSlider.label:SetText("Show Current Time: " .. showTimeNames[value])
    -- Update visibility immediately for all panels
    local panels = {"Logs", "Groups", "Professions", "Hardcore"}
    for _, panelName in ipairs(panels) do
      local panel = DBB2.gui.tabs.panels[panelName]
      if panel and panel.currentTimeText then
        if value == 1 then
          panel.currentTimeText:Show()
        else
          panel.currentTimeText:Hide()
        end
      end
    end
    -- Also update the main gui reference (Logs panel)
    if DBB2.gui.currentTimeText then
      if value == 1 then
        DBB2.gui.currentTimeText:Show()
      else
        DBB2.gui.currentTimeText:Hide()
      end
    end
  end
  
  -- Miscellaneous section title
  local miscTitle = DBB2.api.CreateLabel(generalScrollChild, "Miscellaneous", 10)
  miscTitle:SetPoint("TOPLEFT", showTimeSlider, "BOTTOMLEFT", 0, -DBB2:ScaleSize(19))
  miscTitle:SetTextColor(hr, hg, hb, 1)
  
  -- Scroll Speed slider
  local scrollSlider = DBB2.api.CreateSlider("DBB2ScrollSpeedSlider", generalScrollChild, "Scroll Speed", 10, 100, 5, 9)
  scrollSlider:SetPoint("TOPLEFT", miscTitle, "BOTTOMLEFT", 0, -DBB2:ScaleSize(8))
  scrollSlider:SetWidth(DBB2:ScaleSize(250))
  scrollSlider:SetValue(DBB2_Config.scrollSpeed or 55)
  
  -- Add tooltip on hover
  scrollSlider.slider:SetScript("OnEnter", function()
    local r, g, b = DBB2:GetHighlightColor()
    this.backdrop:SetBackdropBorderColor(r, g, b, 1)
    DBB2.api.ShowTooltip(this, "RIGHT", {
      {"Scroll Speed", "highlight"},
      "Pixels scrolled per mouse wheel tick.",
      {"Higher = faster scrolling", "gray"}
    })
  end)
  
  scrollSlider.slider:SetScript("OnLeave", function()
    this.backdrop:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
    DBB2.api.HideTooltip()
  end)
  
  -- Save on change
  scrollSlider.OnValueChanged = function(val)
    DBB2_Config.scrollSpeed = val
  end
  
  -- Level Filter toggle (0 = off, 1 = on) - filter Groups by player level
  local levelFilterEnabled = DBB2_Config.showLevelFilteredGroups and 1 or 0
  local levelFilterNames = { [0] = "Off", [1] = "On" }
  local levelFilterSlider = DBB2.api.CreateSlider("DBB2LevelFilterSlider", generalScrollChild, "Level Filter (Groups): " .. levelFilterNames[levelFilterEnabled], 0, 1, 1, 9)
  levelFilterSlider:SetPoint("TOPLEFT", scrollSlider, "BOTTOMLEFT", 0, -DBB2:ScaleSize(11))
  levelFilterSlider:SetWidth(DBB2:ScaleSize(250))
  levelFilterSlider:SetValue(levelFilterEnabled)
  
  -- Add tooltip on hover
  levelFilterSlider.slider:SetScript("OnEnter", function()
    local r, g, b = DBB2:GetHighlightColor()
    this.backdrop:SetBackdropBorderColor(r, g, b, 1)
    DBB2.api.ShowTooltip(this, "RIGHT", {
      {"Level Filter (Groups)", "highlight"},
      "Only show dungeon/raid categories",
      "appropriate for your current level.",
      {"Affects Groups tab only.", "gray"}
    })
  end)
  
  levelFilterSlider.slider:SetScript("OnLeave", function()
    this.backdrop:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
    DBB2.api.HideTooltip()
  end)
  
  levelFilterSlider.OnValueChanged = function(value)
    DBB2_Config.showLevelFilteredGroups = (value == 1)
    levelFilterSlider.label:SetText("Level Filter (Groups): " .. levelFilterNames[value])
    -- Update Groups panel if visible
    local groupsPanel = DBB2.gui.tabs.panels["Groups"]
    if groupsPanel and groupsPanel.UpdateCategories and groupsPanel:IsVisible() then
      groupsPanel.UpdateCategories()
    end
  end
  
  -- Notifications section title
  local notifyTitle = DBB2.api.CreateLabel(generalScrollChild, "Notifications", 10)
  notifyTitle:SetPoint("TOPLEFT", levelFilterSlider, "BOTTOMLEFT", 0, -DBB2:ScaleSize(19))
  notifyTitle:SetTextColor(hr, hg, hb, 1)
  
  -- Initialize notification config
  DBB2.api.InitNotificationConfig()
  local notifyMode = DBB2.api.GetNotificationMode()
  
  -- Notification mode slider (0 = off, 1 = chat, 2 = raid warning, 3 = both)
  local notifyModeNames = {
    [0] = "Off",
    [1] = "Chat",
    [2] = "Raid Warning",
    [3] = "Chat & Raid Warning"
  }
  
  local notifySlider = DBB2.api.CreateSlider("DBB2NotifySlider", generalScrollChild, "Mode: " .. notifyModeNames[notifyMode], 0, 3, 1, 9)
  notifySlider:SetPoint("TOPLEFT", notifyTitle, "BOTTOMLEFT", 0, -DBB2:ScaleSize(8))
  notifySlider:SetWidth(DBB2:ScaleSize(250))
  notifySlider:SetValue(notifyMode)
  
  -- Add tooltip on hover
  notifySlider.slider:SetScript("OnEnter", function()
    local r, g, b = DBB2:GetHighlightColor()
    this.backdrop:SetBackdropBorderColor(r, g, b, 1)
    DBB2.api.ShowTooltip(this, "RIGHT", {
      {"Notification Mode", "highlight"},
      "Enable notifications per category in",
      "Groups/Professions/Hardcore tabs.",
      {"0 = disabled", "gray"}
    })
  end)
  
  notifySlider.slider:SetScript("OnLeave", function()
    this.backdrop:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
    DBB2.api.HideTooltip()
  end)
  
  notifySlider.OnValueChanged = function(value)
    DBB2.api.SetNotificationMode(value)
    notifySlider.label:SetText("Mode: " .. notifyModeNames[value])
  end
  
  -- Notification sound toggle (0 = off, 1 = on)
  local soundEnabled = DBB2_Config.notificationSound or 1
  local soundNames = { [0] = "Off", [1] = "On" }
  local soundSlider = DBB2.api.CreateSlider("DBB2SoundSlider", generalScrollChild, "Sound: " .. soundNames[soundEnabled], 0, 1, 1, 9)
  soundSlider:SetPoint("TOPLEFT", notifySlider, "BOTTOMLEFT", 0, -DBB2:ScaleSize(11))
  soundSlider:SetWidth(DBB2:ScaleSize(250))
  soundSlider:SetValue(soundEnabled)
  
  -- Add tooltip on hover
  soundSlider.slider:SetScript("OnEnter", function()
    local r, g, b = DBB2:GetHighlightColor()
    this.backdrop:SetBackdropBorderColor(r, g, b, 1)
    DBB2.api.ShowTooltip(this, "RIGHT", {
      {"Notification Sound", "highlight"},
      "Play a sound when notifications trigger."
    })
  end)
  
  soundSlider.slider:SetScript("OnLeave", function()
    this.backdrop:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
    DBB2.api.HideTooltip()
  end)
  
  soundSlider.OnValueChanged = function(value)
    DBB2_Config.notificationSound = value
    soundSlider.label:SetText("Sound: " .. soundNames[value])
  end
  
  -- Clear on Group Join toggle (0 = off, 1 = on)
  local clearOnGroupEnabled = DBB2_Config.clearNotificationsOnGroupJoin and 1 or 0
  local clearOnGroupNames = { [0] = "Off", [1] = "On" }
  local clearOnGroupSlider = DBB2.api.CreateSlider("DBB2ClearOnGroupSlider", generalScrollChild, "Auto-Clear: " .. clearOnGroupNames[clearOnGroupEnabled], 0, 1, 1, 9)
  clearOnGroupSlider:SetPoint("TOPLEFT", soundSlider, "BOTTOMLEFT", 0, -DBB2:ScaleSize(11))
  clearOnGroupSlider:SetWidth(DBB2:ScaleSize(250))
  clearOnGroupSlider:SetValue(clearOnGroupEnabled)
  
  -- Add tooltip on hover
  clearOnGroupSlider.slider:SetScript("OnEnter", function()
    local r, g, b = DBB2:GetHighlightColor()
    this.backdrop:SetBackdropBorderColor(r, g, b, 1)
    DBB2.api.ShowTooltip(this, "RIGHT", {
      {"Auto-Clear", "highlight"},
      "Disable all category notifications",
      "when joining a party or raid."
    })
  end)
  
  clearOnGroupSlider.slider:SetScript("OnLeave", function()
    this.backdrop:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
    DBB2.api.HideTooltip()
  end)
  
  clearOnGroupSlider.OnValueChanged = function(value)
    DBB2_Config.clearNotificationsOnGroupJoin = (value == 1)
    clearOnGroupSlider.label:SetText("Auto-Clear: " .. clearOnGroupNames[value])
  end
  
  -- Spam Prevention section title
  local spamTitle = DBB2.api.CreateLabel(generalScrollChild, "Spam Prevention", 10)
  spamTitle:SetPoint("TOPLEFT", clearOnGroupSlider, "BOTTOMLEFT", 0, -DBB2:ScaleSize(19))
  spamTitle:SetTextColor(hr, hg, hb, 1)
  
  -- Message expire slider (0-30 minutes, 0 = disabled)
  local expireSlider = DBB2.api.CreateSlider("DBB2ExpireSlider", generalScrollChild, "Auto-Remove Old Messages (minutes)", 0, 30, 1, 9)
  expireSlider:SetPoint("TOPLEFT", spamTitle, "BOTTOMLEFT", 0, -DBB2:ScaleSize(8))
  expireSlider:SetWidth(DBB2:ScaleSize(250))
  expireSlider:SetValue(DBB2_Config.messageExpireMinutes or 15)
  
  -- Add tooltip on hover
  expireSlider.slider:SetScript("OnEnter", function()
    local r, g, b = DBB2:GetHighlightColor()
    this.backdrop:SetBackdropBorderColor(r, g, b, 1)
    DBB2.api.ShowTooltip(this, "RIGHT", {
      {"Auto-Remove Old Messages", "highlight"},
      "Automatically remove messages",
      "older than this time.",
      {"0 = disabled", "gray"}
    })
  end)
  
  expireSlider.slider:SetScript("OnLeave", function()
    this.backdrop:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
    DBB2.api.HideTooltip()
  end)
  
  -- Save on change
  expireSlider.OnValueChanged = function(val)
    DBB2_Config.messageExpireMinutes = val
  end
  
  -- Spam Filter slider (0-300 seconds, 0 = disabled)
  local spamSlider = DBB2.api.CreateSlider("DBB2SpamFilterSlider", generalScrollChild, "Duplicate Filter (seconds)", 0, 300, 10, 9)
  spamSlider:SetPoint("TOPLEFT", expireSlider, "BOTTOMLEFT", 0, -DBB2:ScaleSize(11))
  spamSlider:SetWidth(DBB2:ScaleSize(250))
  spamSlider:SetValue(DBB2_Config.spamFilterSeconds or 150)
  
  -- Add tooltip on hover
  spamSlider.slider:SetScript("OnEnter", function()
    local r, g, b = DBB2:GetHighlightColor()
    this.backdrop:SetBackdropBorderColor(r, g, b, 1)
    DBB2.api.ShowTooltip(this, "RIGHT", {
      {"Duplicate Filter", "highlight"},
      "Hide duplicate messages from the",
      "same sender within this time.",
      {"0 = disabled", "gray"}
    })
  end)
  
  spamSlider.slider:SetScript("OnLeave", function()
    this.backdrop:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
    DBB2.api.HideTooltip()
  end)
  
  -- Save on change
  spamSlider.OnValueChanged = function(val)
    DBB2_Config.spamFilterSeconds = val
  end
  
  -- Hide from chat slider (0 = disabled, 1 = selected only, 2 = all categories)
  local hideFromChatModes = {
    [0] = "Disabled",
    [1] = "Selected Only",
    [2] = "All Categories"
  }
  -- Handle legacy boolean values
  local currentHideMode = DBB2_Config.hideFromChat or 0
  if currentHideMode == true then currentHideMode = 1 end
  if currentHideMode == false then currentHideMode = 0 end
  
  local hideFromChatSlider = DBB2.api.CreateSlider("DBB2HideFromChatSlider", generalScrollChild, "Hide from Chat: " .. hideFromChatModes[currentHideMode], 0, 2, 1, 9)
  hideFromChatSlider:SetPoint("TOPLEFT", spamSlider, "BOTTOMLEFT", 0, -DBB2:ScaleSize(11))
  hideFromChatSlider:SetWidth(DBB2:ScaleSize(250))
  hideFromChatSlider:SetValue(currentHideMode)
  
  -- Add tooltip on hover
  hideFromChatSlider.slider:SetScript("OnEnter", function()
    local r, g, b = DBB2:GetHighlightColor()
    this.backdrop:SetBackdropBorderColor(r, g, b, 1)
    DBB2.api.ShowTooltip(this, "RIGHT", {
      {"Hide Captured Messages from Chat", "highlight"},
      "0 = Disabled (show all in chat)",
      "1 = Selected Only (hide enabled categories)",
      "2 = All Categories (hide all LFG spam)",
      {"Mode 2 gives cleanest chat", "gray"}
    })
  end)
  
  hideFromChatSlider.slider:SetScript("OnLeave", function()
    this.backdrop:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
    DBB2.api.HideTooltip()
  end)
  
  hideFromChatSlider.OnValueChanged = function(val)
    DBB2_Config.hideFromChat = val
    hideFromChatSlider.label:SetText("Hide from Chat: " .. hideFromChatModes[val])
  end
  
  -- Max messages per category slider
  local maxMsgSlider = DBB2.api.CreateSlider("DBB2MaxMsgSlider", generalScrollChild, "Messages per Category", 0, 10, 1, 9)
  maxMsgSlider:SetPoint("TOPLEFT", hideFromChatSlider, "BOTTOMLEFT", 0, -DBB2:ScaleSize(11))
  maxMsgSlider:SetWidth(DBB2:ScaleSize(250))
  maxMsgSlider:SetValue(DBB2_Config.maxMessagesPerCategory or 5)
  
  -- Add tooltip on hover
  maxMsgSlider.slider:SetScript("OnEnter", function()
    local r, g, b = DBB2:GetHighlightColor()
    this.backdrop:SetBackdropBorderColor(r, g, b, 1)
    DBB2.api.ShowTooltip(this, "RIGHT", {
      {"Messages per Category", "highlight"},
      "Max messages shown per category in",
      "Groups/Professions/Hardcore tabs.",
      {"0 = unlimited", "gray"}
    })
  end)
  
  maxMsgSlider.slider:SetScript("OnLeave", function()
    this.backdrop:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
    DBB2.api.HideTooltip()
  end)
  
  -- Save on change
  maxMsgSlider.OnValueChanged = function(val)
    DBB2_Config.maxMessagesPerCategory = val
  end
  
  -- =====================
  -- CHANNELS CONFIG PANEL
  -- =====================
  local channelsPanel = DBB2.gui.configTabs.panels["Channels"]
  
  -- Create static scroll frame for Channels tab
  local channelsScroll = DBB2.api.CreateStaticScrollFrame("DBB2ChannelsScroll", channelsPanel)
  channelsScroll:SetPoint("TOPLEFT", channelsPanel, "TOPLEFT", 0, 0)
  channelsScroll:SetPoint("BOTTOMRIGHT", channelsPanel, "BOTTOMRIGHT", 0, 0)
  channelsPanel.scrollFrame = channelsScroll
  
  -- Add padding to scrollbar
  local chSliderPadding = DBB2:ScaleSize(5)
  channelsScroll.slider:ClearAllPoints()
  channelsScroll.slider:SetPoint("TOPRIGHT", channelsScroll, "TOPRIGHT", 0, -chSliderPadding)
  channelsScroll.slider:SetPoint("BOTTOMRIGHT", channelsScroll, "BOTTOMRIGHT", 0, chSliderPadding)
  
  -- Content height will be set dynamically based on channel count
  local channelsScrollChild = DBB2.api.CreateStaticScrollChild("DBB2ChannelsScrollChild", channelsScroll, DBB2:ScaleSize(300))
  
  -- Update scroll child width on size change
  local lastChannelsScrollWidth = 0
  channelsScroll:SetScript("OnUpdate", function()
    if not this:IsVisible() then return end
    
    local scrollLeft = this:GetLeft()
    local scrollRight = this:GetRight()
    if not scrollLeft or not scrollRight then return end
    
    local scrollWidth = scrollRight - scrollLeft
    
    if scrollWidth > 0 and scrollWidth ~= lastChannelsScrollWidth then
      lastChannelsScrollWidth = scrollWidth
      channelsScrollChild:SetWidth(scrollWidth)
      this.UpdateScrollState()
    end
  end)
  
  -- Section title
  local channelsTitle = DBB2.api.CreateLabel(channelsScrollChild, "Monitored Channels", 10)
  channelsTitle:SetPoint("TOPLEFT", DBB2:ScaleSize(10), -DBB2:ScaleSize(10))
  channelsTitle:SetTextColor(hr, hg, hb, 1)
  
  local channelsDesc = DBB2.api.CreateLabel(channelsScrollChild, "Select which channels to monitor for LFG messages.", 9)
  channelsDesc:SetPoint("TOPLEFT", channelsTitle, "BOTTOMLEFT", 0, -DBB2:ScaleSize(5))
  channelsDesc:SetTextColor(0.5, 0.5, 0.5, 1)
  
  -- Initialize channel monitoring config (must be before UI elements that read config)
  DBB2.api.InitChannelConfig()
  
  -- Auto-Join Channels checkbox
  local autoJoinCheck = DBB2.api.CreateCheckBox("DBB2AutoJoinChannels", channelsScrollChild, "Auto-join World & LookingForGroup at login", 9)
  autoJoinCheck:SetPoint("TOPLEFT", channelsDesc, "BOTTOMLEFT", 0, -DBB2:ScaleSize(12))
  autoJoinCheck:SetChecked(DBB2_Config.autoJoinChannels ~= false)
  autoJoinCheck.OnChecked = function(checked)
    DBB2_Config.autoJoinChannels = checked
  end
  
  -- Add tooltip on hover
  autoJoinCheck:SetScript("OnEnter", function()
    local r, g, b = DBB2:GetHighlightColor()
    this.backdrop:SetBackdropBorderColor(r, g, b, 1)
    DBB2.api.ShowTooltip(this, "RIGHT", {
      {"Auto-Join Channels", "highlight"},
      "Automatically join World and",
      "LookingForGroup channels at login.",
      {"Disable if you prefer to manage", "gray"},
      {"channels manually.", "gray"}
    })
  end)
  
  autoJoinCheck:SetScript("OnLeave", function()
    this.backdrop:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    DBB2.api.HideTooltip()
  end)
  
  -- Channel List section title (below auto-join)
  local monitoredTitle = DBB2.api.CreateLabel(channelsScrollChild, "Channel List", 10)
  monitoredTitle:SetPoint("TOPLEFT", autoJoinCheck, "BOTTOMLEFT", 0, -DBB2:ScaleSize(15))
  monitoredTitle:SetTextColor(hr, hg, hb, 1)
  
  -- Known channel descriptions (for tooltips)
  local channelDescriptions = {
    Say = "Local /say chat (players nearby)",
    Yell = "Local /yell chat (wider range)",
    Guild = "Your guild chat",
    Whisper = "Private whisper messages",
    Party = "Your party chat",
    General = "Zone general chat (may be spammy)",
    Trade = "Trade channel (sometimes used for LFG)",
    LocalDefense = "Zone defense alerts",
    WorldDefense = "World-wide defense alerts",
    LookingForGroup = "Blizzard's official LFG channel",
    GuildRecruitment = "Guild recruitment channel",
    World = "Main LFG channel on most servers",
    Hardcore = "Turtle WoW hardcore channel"
  }
  
  -- Container for dynamically created channel checkboxes
  channelsPanel.channelCheckboxes = {}
  channelsPanel.checkboxContainer = CreateFrame("Frame", nil, channelsScrollChild)
  channelsPanel.checkboxContainer:SetPoint("TOPLEFT", monitoredTitle, "BOTTOMLEFT", 0, -DBB2:ScaleSize(8))
  channelsPanel.checkboxContainer:SetPoint("RIGHT", channelsScrollChild, "RIGHT", -DBB2:ScaleSize(10), 0)
  -- Height will be set dynamically by RebuildChannelCheckboxes
  
  local checkSize = DBB2:ScaleSize(14)
  
  -- Function to rebuild channel checkboxes dynamically
  local function RebuildChannelCheckboxes()
    -- Clear existing checkboxes and separators
    for _, check in ipairs(channelsPanel.channelCheckboxes) do
      check:Hide()
      check:SetParent(nil)
    end
    channelsPanel.channelCheckboxes = {}
    
    -- Clear existing inline separators
    if channelsPanel.inlineSeparators then
      for _, sep in ipairs(channelsPanel.inlineSeparators) do
        sep:Hide()
      end
    end
    channelsPanel.inlineSeparators = {}
    
    -- Detect hardcore character once for this rebuild
    local isHardcoreChar = DBB2.api.DetectHardcoreCharacter()
    
    -- Get fresh channel list
    local channelList = DBB2.api.RefreshJoinedChannels()
    
    local lastElement = nil
    local checkSize = DBB2:ScaleSize(14)
    local separatorHeight = DBB2:ScaleSize(8)
    local elementCount = 0
    local totalHeight = 0
    
    for i, channelName in ipairs(channelList) do
      if channelName == "-" then
        -- Create spacing between sections (no divider line)
        local spacer = CreateFrame("Frame", nil, channelsPanel.checkboxContainer)
        spacer:SetWidth(1)
        spacer:SetHeight(1)  -- Minimal height, just for anchoring
        if lastElement then
          -- Position with extra gap for section separation
          spacer:SetPoint("TOPLEFT", lastElement, "BOTTOMLEFT", 0, -separatorHeight)
        else
          spacer:SetPoint("TOPLEFT", channelsPanel.checkboxContainer, "TOPLEFT", 0, -separatorHeight)
        end
        table.insert(channelsPanel.channelCheckboxes, spacer)
        lastElement = spacer
        -- Count the gap (replaces the normal 5px gap with separatorHeight gap)
        -- Previous checkbox already added 5px, so add the difference
        totalHeight = totalHeight + (separatorHeight - DBB2:ScaleSize(5))
      else
        local check = DBB2.api.CreateCheckBox("DBB2Channel" .. channelName .. i, channelsPanel.checkboxContainer, channelName, 9)
        if not lastElement then
          check:SetPoint("TOPLEFT", channelsPanel.checkboxContainer, "TOPLEFT", 0, 0)
          -- First checkbox: only count its height, no gap before it
          totalHeight = totalHeight + checkSize
        else
          check:SetPoint("TOPLEFT", lastElement, "BOTTOMLEFT", 0, -DBB2:ScaleSize(5))
          -- Subsequent checkboxes: count height + gap before it
          totalHeight = totalHeight + checkSize + DBB2:ScaleSize(5)
        end
        check:SetWidth(checkSize)
        check:SetHeight(checkSize)
        
        -- Store channel name for callback
        check._channelName = channelName
        
        -- Special handling for Hardcore channel
        if channelName == "Hardcore" then
          -- Hardcore channel only available for hardcore characters
          if isHardcoreChar then
            check:SetChecked(DBB2.api.IsChannelMonitored("Hardcore"))
            check.OnChecked = function(checked)
              DBB2.api.SetChannelMonitored("Hardcore", checked)
            end
            -- Highlight border on hover when enabled
            check:SetScript("OnEnter", function()
              local r, g, b = DBB2:GetHighlightColor()
              this.backdrop:SetBackdropBorderColor(r, g, b, 1)
            end)
            check:SetScript("OnLeave", function()
              this.backdrop:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
            end)
          else
            check:SetChecked(false)
            check:Disable()
          end
        elseif channelName == "World" or channelName == "LookingForGroup" then
          -- World/LookingForGroup: normal handling, user controls state
          check:SetChecked(DBB2.api.IsChannelMonitored(channelName))
          check.OnChecked = function(checked)
            DBB2.api.SetChannelMonitored(check._channelName, checked)
          end
          -- Highlight border on hover
          check:SetScript("OnEnter", function()
            local r, g, b = DBB2:GetHighlightColor()
            this.backdrop:SetBackdropBorderColor(r, g, b, 1)
          end)
          check:SetScript("OnLeave", function()
            this.backdrop:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
          end)
        else
          -- Normal channel handling
          check:SetChecked(DBB2.api.IsChannelMonitored(channelName))
          
          check.OnChecked = function(checked)
            DBB2.api.SetChannelMonitored(check._channelName, checked)
          end
          
          -- Add tooltip
          check:SetScript("OnEnter", function()
            local r, g, b = DBB2:GetHighlightColor()
            this.backdrop:SetBackdropBorderColor(r, g, b, 1)
            local desc = channelDescriptions[this._channelName] or "Monitor this channel for messages."
            DBB2.api.ShowTooltip(this, "RIGHT", {
              {this._channelName, "highlight"},
              desc
            })
          end)
          
          check:SetScript("OnLeave", function()
            this.backdrop:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
            DBB2.api.HideTooltip()
          end)
        end
        
        table.insert(channelsPanel.channelCheckboxes, check)
        lastElement = check
        elementCount = elementCount + 1
      end
    end
    
    -- Set container height to fit content exactly
    channelsPanel.checkboxContainer:SetHeight(totalHeight)
    
    -- Update scroll child height to fit all content exactly
    -- Header (title + desc + auto-join checkbox + channel list title + spacing) + totalHeight + small bottom padding
    local headerHeight = DBB2:ScaleSize(10 + 12 + 5 + 12 + 14 + 15 + 12 + 8)
    local bottomPadding = DBB2:ScaleSize(5)
    local newContentHeight = headerHeight + totalHeight + bottomPadding
    channelsScrollChild:SetHeight(newContentHeight)
    
    -- Update scroll state
    if channelsScroll.UpdateScrollState then
      channelsScroll.UpdateScrollState()
    end
  end
  
  -- Build initial checkboxes
  RebuildChannelCheckboxes()
  
  -- Expose rebuild function on panel for event-driven updates
  channelsPanel.RebuildChannelCheckboxes = RebuildChannelCheckboxes
  
  -- Rebuild checkboxes when panel is shown (catches channels joined after login)
  local originalOnShow = channelsPanel:GetScript("OnShow")
  channelsPanel:SetScript("OnShow", function()
    RebuildChannelCheckboxes()
    if originalOnShow then
      originalOnShow()
    end
  end)
  
  -- =====================
  -- CATEGORY CONFIG PANELS (Groups, Professions, Hardcore)
  -- =====================
  
  -- Create category config panel (without scroll frame for EditBox compatibility)
  local function CreateCategoryConfigPanel(panelName, categoryType)
    local panel = DBB2.gui.configTabs.panels[panelName]
    
    -- Common sizing constants (defined early so filter section can use them)
    local rowHeight = DBB2:ScaleSize(28)
    local checkSize = DBB2:ScaleSize(14)
    local nameWidth = DBB2:ScaleSize(150)
    
    -- Section title
    local hr, hg, hb = DBB2:GetHighlightColor()
    local title = DBB2.api.CreateLabel(panel, panelName .. " - Edit Tags", 10)
    title:SetPoint("TOPLEFT", DBB2:ScaleSize(10), -DBB2:ScaleSize(10))
    title:SetTextColor(hr, hg, hb, 1)
    
    local desc = DBB2.api.CreateLabel(panel, "Edit tags to customize which messages match each category.", 9)
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -DBB2:ScaleSize(5))
    desc:SetTextColor(0.5, 0.5, 0.5, 1)

    -- Helper text for wildcard patterns
    local wildcardHelp = DBB2.api.CreateLabel(panel, "Supports wildcards: * (any), ? (one char), [a-z], {a,b}. See api/wildcards.lua", 8)
    wildcardHelp:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -DBB2:ScaleSize(2))
    wildcardHelp:SetTextColor(0.5, 0.5, 0.5, 1)

    -- Legend for checkboxes
    local legendLabel = DBB2.api.CreateLabel(panel, "[ ] = Enable category", 8)
    legendLabel:SetPoint("TOPLEFT", wildcardHelp, "BOTTOMLEFT", 0, -DBB2:ScaleSize(3))
    legendLabel:SetTextColor(0.4, 0.4, 0.4, 1)
    
    -- Track the last anchor element for container positioning
    local containerAnchor = legendLabel
    local containerAnchorOffset = -DBB2:ScaleSize(8)
    
    -- Filter Tags section (only for Groups and Professions)
    if categoryType == "groups" or categoryType == "professions" then
      -- Calculate right offset to match category rows (scrollbar width + 2 + row padding)
      local sliderWidth = DBB2:ScaleSize(7)
      local filterRightOffset = (sliderWidth + 2) + DBB2:ScaleSize(25)
      
      -- Create a row frame for filter tags to match category row styling
      local filterRow = CreateFrame("Frame", "DBB2Config" .. panelName .. "FilterRow", panel)
      filterRow:SetHeight(rowHeight)
      filterRow:SetPoint("TOPLEFT", legendLabel, "BOTTOMLEFT", 0, -DBB2:ScaleSize(8))
      filterRow:SetPoint("RIGHT", panel, "RIGHT", -(sliderWidth + 2), 0)
      
      -- Checkbox for enabled/disabled (same style as category checkboxes)
      local filterCheck = DBB2.api.CreateCheckBox("DBB2Config" .. panelName .. "FilterEnabled", filterRow)
      filterCheck:SetPoint("LEFT", 5, 0)
      filterCheck:SetWidth(checkSize)
      filterCheck:SetHeight(checkSize)
      filterCheck:SetChecked(DBB2.api.IsFilterTagsEnabled(categoryType))
      filterCheck.OnChecked = function(checked)
        DBB2.api.SetFilterTagsEnabled(categoryType, checked)
      end
      
      -- Filter label (same width and style as category name labels)
      local filterLabel = DBB2.api.CreateLabel(filterRow, "Filter Tags", 10)
      filterLabel:SetPoint("LEFT", filterCheck, "RIGHT", 8, 0)
      filterLabel:SetWidth(nameWidth)
      filterLabel:SetTextColor(hr, hg, hb, 0.9)
      
      -- Filter tags input (same style as category tags input)
      local filterTagsInput = CreateFrame("EditBox", "DBB2Config" .. panelName .. "FilterTags", filterRow)
      filterTagsInput:SetPoint("LEFT", filterLabel, "RIGHT", 5, 0)
      filterTagsInput:SetPoint("RIGHT", filterRow, "RIGHT", -DBB2:ScaleSize(25), 0)
      filterTagsInput:SetHeight(DBB2:ScaleSize(18))
      filterTagsInput:SetAutoFocus(false)
      filterTagsInput:EnableMouse(true)
      filterTagsInput:SetTextInsets(DBB2:ScaleSize(5), DBB2:ScaleSize(5), DBB2:ScaleSize(5), DBB2:ScaleSize(5))
      filterTagsInput:SetFont("Fonts\\FRIZQT__.TTF", DBB2:GetFontSize(10))
      filterTagsInput:SetTextColor(1, 1, 1, 1)
      filterTagsInput:SetJustifyH("LEFT")
      DBB2:CreateBackdrop(filterTagsInput, nil, true)
      
      -- Load current filter tags
      local filterConfig = DBB2.api.GetFilterTags(categoryType)
      if filterConfig and filterConfig.tags then
        filterTagsInput:SetText(DBB2.api.TagsToString(filterConfig.tags))
      end
      
      filterTagsInput:SetScript("OnEscapePressed", function()
        this:ClearFocus()
      end)
      
      filterTagsInput:SetScript("OnEnterPressed", function()
        local newTags = DBB2.api.ParseTagsString(this:GetText())
        DBB2.api.UpdateFilterTags(categoryType, newTags)
        this:ClearFocus()
      end)
      
      filterTagsInput:SetScript("OnEditFocusLost", function()
        local newTags = DBB2.api.ParseTagsString(this:GetText())
        DBB2.api.UpdateFilterTags(categoryType, newTags)
      end)
      
      filterTagsInput:SetScript("OnEnter", function()
        if this.backdrop then
          this.backdrop:SetBackdropBorderColor(hr, hg, hb, 1)
        end
        DBB2.api.ShowTooltip(this, "RIGHT", {
          {"Filter Tags", "highlight"},
          "Messages must contain one of these",
          "tags IN ADDITION to category tags.",
          {"Disable checkbox to match all.", "gray"}
        })
      end)
      
      filterTagsInput:SetScript("OnLeave", function()
        if this.backdrop then
          this.backdrop:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
        end
        DBB2.api.HideTooltip()
      end)
      
      -- Store reference for Save & Reload
      panel.filterTagsInput = filterTagsInput
      panel.filterCategoryType = categoryType
      
      -- Update container anchor to be below filter row
      containerAnchor = filterRow
      containerAnchorOffset = -DBB2:ScaleSize(5)
    end
    
    -- Scrollbar - fill panel height with padding from edges
    local sliderWidth = DBB2:ScaleSize(7)
    local sliderPadding = DBB2:ScaleSize(5)
    local slider = CreateFrame("Slider", "DBB2Config" .. panelName .. "Slider", panel)
    slider:SetOrientation("VERTICAL")
    slider:SetWidth(sliderWidth)
    slider:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, -sliderPadding)
    slider:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, sliderPadding)
    slider:EnableMouse(true)
    slider:SetValueStep(1)
    slider:SetMinMaxValues(0, 1)
    slider:SetValue(0)
    
    slider:SetThumbTexture("Interface\\BUTTONS\\WHITE8X8")
    slider.thumb = slider:GetThumbTexture()
    slider.thumb:SetWidth(sliderWidth)
    slider.thumb:SetHeight(DBB2:ScaleSize(50))
    slider.thumb:SetTexture(hr, hg, hb, 0.5)
    
    -- Container for rows (clips content) - fill panel below filter section with bottom padding
    local container = CreateFrame("Frame", "DBB2Config" .. panelName .. "Container", panel)
    container:SetPoint("TOPLEFT", containerAnchor, "BOTTOMLEFT", 0, containerAnchorOffset)
    container:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -(sliderWidth + 2), DBB2:ScaleSize(5))
    
    panel.container = container
    panel.slider = slider
    panel.categoryRows = {}
    panel.scrollOffset = 0
    
    -- Helper to get actual container height from rendered positions
    local function GetContainerHeight()
      local top = container:GetTop()
      local bottom = container:GetBottom()
      if top and bottom then
        return top - bottom
      end
      return 300  -- fallback
    end
    
    -- Update row positions based on scroll offset
    local function UpdateRowPositions()
      local containerHeight = GetContainerHeight()
      
      for i, row in ipairs(panel.categoryRows) do
        if row then
          -- Base position: row 1 at top (yPos=0), row 2 at -rowHeight, etc.
          -- scrollOffset is 0 at top, positive when scrolled down
          -- When scrolled down, we ADD scrollOffset to move content UP
          local baseY = -((i - 1) * rowHeight)
          local yPos = baseY + (panel.scrollOffset or 0)
          
          row:ClearAllPoints()
          row:SetPoint("TOPLEFT", container, "TOPLEFT", 0, yPos)
          row:SetPoint("RIGHT", container, "RIGHT", 0, 0)
          
          -- Hide if outside visible area
          -- Row top edge must be at or below 0 (container top)
          -- Row bottom edge must be at or above -containerHeight (container bottom)
          local rowTop = yPos
          local rowBottom = yPos - rowHeight
          
          -- Hide if row is above container (rowTop > 0) or below container (rowBottom < -containerHeight)
          if rowTop > 0 or rowBottom < -containerHeight then
            row:Hide()
          else
            row:Show()
          end
        end
      end
    end
    
    -- Update scrollbar state
    local function UpdateScrollbar()
      local categories = DBB2.api.GetCategories(categoryType)
      local totalHeight = table.getn(categories) * rowHeight
      local containerHeight = GetContainerHeight()
      local maxScroll = math.max(0, totalHeight - containerHeight)
      
      slider:SetMinMaxValues(0, maxScroll)
      slider:SetValue(-(panel.scrollOffset or 0))
      
      -- Update thumb size
      if totalHeight > 0 and containerHeight > 0 then
        local ratio = containerHeight / totalHeight
        if ratio < 1 then
          local thumbHeight = math.max(DBB2:ScaleSize(20), containerHeight * ratio)
          slider.thumb:SetHeight(thumbHeight)
          slider:Show()
        else
          slider:Hide()
        end
      else
        slider:Hide()
      end
    end
    
    -- Slider value changed
    slider:SetScript("OnValueChanged", function()
      panel.scrollOffset = this:GetValue()
      UpdateRowPositions()
    end)
    
    -- Build category rows
    local function BuildCategoryRows()
      local categories = DBB2.api.GetCategories(categoryType)
      
      -- Create/update rows
      for i, cat in ipairs(categories) do
        local row = panel.categoryRows[i]
        if not row then
          -- Create row frame parented to container
          row = CreateFrame("Frame", nil, container)
          row:SetHeight(rowHeight)
          panel.categoryRows[i] = row
          
          -- Checkbox for enabled/disabled
          row.check = DBB2.api.CreateCheckBox("DBB2Config" .. panelName .. "Check" .. i, row)
          row.check:SetPoint("LEFT", 5, 0)
          row.check:SetWidth(checkSize)
          row.check:SetHeight(checkSize)
          
          -- Category name label
          row.nameLabel = DBB2.api.CreateLabel(row, "", 10)
          row.nameLabel:SetPoint("LEFT", row.check, "RIGHT", 8, 0)
          row.nameLabel:SetWidth(nameWidth)
          
          -- Tags edit box - anchor to right edge so it resizes with container
          row.tagsInput = CreateFrame("EditBox", "DBB2Config" .. panelName .. "Tags" .. i, row)
          row.tagsInput:SetPoint("LEFT", row.nameLabel, "RIGHT", 5, 0)
          row.tagsInput:SetPoint("RIGHT", row, "RIGHT", -DBB2:ScaleSize(25), 0)
          row.tagsInput:SetHeight(DBB2:ScaleSize(18))
          row.tagsInput:SetAutoFocus(false)
          row.tagsInput:EnableMouse(true)
          row.tagsInput:SetTextInsets(DBB2:ScaleSize(5), DBB2:ScaleSize(5), DBB2:ScaleSize(5), DBB2:ScaleSize(5))
          row.tagsInput:SetFont("Fonts\\FRIZQT__.TTF", DBB2:GetFontSize(10))
          row.tagsInput:SetTextColor(1, 1, 1, 1)
          row.tagsInput:SetJustifyH("LEFT")
          DBB2:CreateBackdrop(row.tagsInput, nil, true)
          
          row.tagsInput:SetScript("OnEscapePressed", function()
            this:ClearFocus()
          end)
          
          row.tagsInput:SetScript("OnEnter", function()
            local r, g, b = DBB2:GetHighlightColor()
            if this.backdrop then
              this.backdrop:SetBackdropBorderColor(r, g, b, 1)
            end
          end)
          
          row.tagsInput:SetScript("OnLeave", function()
            if this.backdrop then
              this.backdrop:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
            end
          end)
        end
        
        -- Set data
        row.categoryName = cat.name
        row.categoryType = categoryType
        row.nameLabel:SetText(cat.name)
        row.nameLabel:SetTextColor(1, 1, 1, 1)
        
        -- Set checkbox state
        row.check:SetChecked(cat.selected)
        
        -- Set tags text
        local tagsStr = DBB2.api.TagsToString(cat.tags)
        row.tagsInput:SetText(tagsStr)
        
        -- Checkbox callback
        row.check.OnChecked = function(checked)
          DBB2.api.SetCategorySelected(row.categoryType, row.categoryName, checked)
        end
        
        -- Tags input callbacks
        row.tagsInput:SetScript("OnEnterPressed", function()
          local newTags = DBB2.api.ParseTagsString(this:GetText())
          DBB2.api.UpdateCategoryTags(row.categoryType, row.categoryName, newTags)
          this:ClearFocus()
        end)
        
        row.tagsInput:SetScript("OnEditFocusLost", function()
          local newTags = DBB2.api.ParseTagsString(this:GetText())
          DBB2.api.UpdateCategoryTags(row.categoryType, row.categoryName, newTags)
        end)
      end
      
      UpdateRowPositions()
      UpdateScrollbar()
    end
    
    -- Mouse wheel scrolling on container
    container:EnableMouseWheel(true)
    container:SetScript("OnMouseWheel", function()
      local categories = DBB2.api.GetCategories(categoryType)
      local totalHeight = table.getn(categories) * rowHeight
      local containerHeight = GetContainerHeight()
      local maxScroll = math.max(0, totalHeight - containerHeight)
      
      -- Use configured scroll speed
      local scrollSpeed = DBB2_Config.scrollSpeed or 20
      
      -- arg1 is positive when scrolling up (wheel away from you)
      -- arg1 is negative when scrolling down (wheel toward you)
      -- When scrolling DOWN (arg1 negative), we want to see content BELOW, so scrollOffset increases
      panel.scrollOffset = (panel.scrollOffset or 0) - (arg1 * scrollSpeed)
      
      -- Clamp scroll offset (0 = top, maxScroll = bottom)
      if panel.scrollOffset < 0 then
        panel.scrollOffset = 0
      elseif panel.scrollOffset > maxScroll then
        panel.scrollOffset = maxScroll
      end
      
      slider:SetValue(panel.scrollOffset)
      UpdateRowPositions()
    end)
    
    -- Build rows when panel is shown
    panel:SetScript("OnShow", function()
      panel.scrollOffset = 0
      slider:SetValue(0)
      BuildCategoryRows()
    end)
    
    -- Update when container size changes (window resize)
    container:SetScript("OnSizeChanged", function()
      UpdateScrollbar()
      UpdateRowPositions()
    end)
    
    -- Initial build (delayed to ensure container has size)
    -- Remove OnUpdate after initialization to stop per-frame calls
    panel:SetScript("OnUpdate", function()
      if this.initialized then
        this:SetScript("OnUpdate", nil)
        return
      end
      local h = GetContainerHeight()
      if h and h > 10 then
        this.initialized = true
        BuildCategoryRows()
        -- Remove OnUpdate after initialization
        this:SetScript("OnUpdate", nil)
      end
    end)
  end
  
  -- Create config panels for each category type
  CreateCategoryConfigPanel("Groups", "groups")
  CreateCategoryConfigPanel("Professions", "professions")
  CreateCategoryConfigPanel("Hardcore", "hardcore")
  
  -- =====================
  -- BLACKLIST PANEL (simplified with import/export)
  -- =====================
  local blacklistPanel = DBB2.gui.configTabs.panels["Blacklist"]
  
  -- Initialize blacklist
  DBB2.api.InitBlacklist()
  
  -- Layout constants
  local blRowHeight = DBB2:ScaleSize(22)
  local blInputHeight = DBB2:ScaleSize(20)
  local blBtnWidth = DBB2:ScaleSize(30)
  local blSpacing = DBB2:ScaleSize(5)
  local blSectionGap = DBB2:ScaleSize(15)
  local blPadding = DBB2:ScaleSize(10)
  
  -- Scrollbar (will be positioned after rowsContainer is created)
  local sliderWidth = DBB2:ScaleSize(7)
  local blSlider = CreateFrame("Slider", "DBB2BlacklistSlider", blacklistPanel)
  blSlider:SetOrientation("VERTICAL")
  blSlider:SetWidth(sliderWidth)
  blSlider:EnableMouse(true)
  blSlider:SetValueStep(1)
  blSlider:SetMinMaxValues(0, 1)
  blSlider:SetValue(0)
  
  blSlider:SetThumbTexture("Interface\\BUTTONS\\WHITE8X8")
  blSlider.thumb = blSlider:GetThumbTexture()
  blSlider.thumb:SetWidth(sliderWidth)
  blSlider.thumb:SetHeight(DBB2:ScaleSize(50))
  blSlider.thumb:SetTexture(hr, hg, hb, 0.5)
  
  -- Container (full panel width)
  local blContainer = CreateFrame("Frame", "DBB2BlacklistContainer", blacklistPanel)
  blContainer:SetPoint("TOPLEFT", blacklistPanel, "TOPLEFT", 0, 0)
  blContainer:SetPoint("BOTTOMRIGHT", blacklistPanel, "BOTTOMRIGHT", 0, 0)
  
  blacklistPanel.container = blContainer
  blacklistPanel.slider = blSlider
  blacklistPanel.scrollOffset = 0
  blacklistPanel.keywordRows = {}
  
  -- Section title
  local blTitle = DBB2.api.CreateLabel(blContainer, "Blacklist Management", 10)
  blTitle:SetPoint("TOPLEFT", blPadding, -blPadding)
  blTitle:SetTextColor(hr, hg, hb, 1)
  
  local blDesc = DBB2.api.CreateLabel(blContainer, "Block messages containing specific keywords.", 9)
  blDesc:SetPoint("TOPLEFT", blTitle, "BOTTOMLEFT", 0, -blSpacing)
  blDesc:SetTextColor(0.5, 0.5, 0.5, 1)
  
  -- Enable/Disable checkbox
  local blEnabledCheck = DBB2.api.CreateCheckBox("DBB2BlacklistEnabled", blContainer, "Enable Blacklist Filtering", 9)
  blEnabledCheck:SetPoint("TOPLEFT", blDesc, "BOTTOMLEFT", 0, -DBB2:ScaleSize(10))
  blEnabledCheck:SetChecked(DBB2.api.IsBlacklistEnabled())
  blEnabledCheck.OnChecked = function(checked)
    DBB2.api.SetBlacklistEnabled(checked)
  end
  
  -- Hide from chat checkbox (enabled by default)
  local blHideFromChatCheck = DBB2.api.CreateCheckBox("DBB2BlacklistHideFromChat", blContainer, "Hide messages from Chat", 9)
  blHideFromChatCheck:SetPoint("TOPLEFT", blEnabledCheck, "BOTTOMLEFT", 0, -DBB2:ScaleSize(5))
  blHideFromChatCheck:SetChecked(DBB2.api.IsBlacklistHideFromChatEnabled())
  blHideFromChatCheck.OnChecked = function(checked)
    DBB2.api.SetBlacklistHideFromChat(checked)
  end
  
  -- Add tooltip for hide from chat option
  blHideFromChatCheck:SetScript("OnEnter", function()
    local r, g, b = DBB2:GetHighlightColor()
    this.backdrop:SetBackdropBorderColor(r, g, b, 1)
    DBB2.api.ShowTooltip(this, "RIGHT", {
      {"Hide Blacklisted from Chat", "highlight"},
      "Hide messages matching blacklisted",
      "keywords from your chat window.",
      {"Works with Hide from Chat option.", "gray"}
    })
  end)
  
  blHideFromChatCheck:SetScript("OnLeave", function()
    this.backdrop:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    DBB2.api.HideTooltip()
  end)
  
  -- =====================
  -- IMPORT/EXPORT SECTION (first)
  -- =====================
  local importExportTitle = DBB2.api.CreateLabel(blContainer, "Import / Export", 10)
  importExportTitle:SetPoint("TOPLEFT", blHideFromChatCheck, "BOTTOMLEFT", 0, -blSectionGap)
  importExportTitle:SetTextColor(hr, hg, hb, 1)
  
  local importExportDesc = DBB2.api.CreateLabel(blContainer, "Copy to export, paste and press Enter to import (comma separated)", 9)
  importExportDesc:SetPoint("TOPLEFT", importExportTitle, "BOTTOMLEFT", 0, -blSpacing)
  importExportDesc:SetTextColor(0.5, 0.5, 0.5, 1)
  
  -- Import/Export text box (account for scrollbar space on right)
  local importExportBox = DBB2.api.CreateEditBox("DBB2BlacklistImportExport", blContainer)
  importExportBox:SetPoint("TOPLEFT", importExportDesc, "BOTTOMLEFT", 0, -blSpacing)
  importExportBox:SetPoint("RIGHT", blContainer, "RIGHT", -(sliderWidth + blPadding + DBB2:ScaleSize(16)), 0)
  importExportBox:SetHeight(blInputHeight)
  
  blacklistPanel.importExportBox = importExportBox
  
  -- =====================
  -- KEYWORDS SECTION
  -- =====================
  local keywordsTitle = DBB2.api.CreateLabel(blContainer, "Blacklisted Keywords", 10)
  keywordsTitle:SetPoint("TOPLEFT", importExportBox, "BOTTOMLEFT", 0, -blSectionGap)
  keywordsTitle:SetTextColor(hr, hg, hb, 1)
  
  -- Helper text for wildcard patterns
  local keywordsHelp = DBB2.api.CreateLabel(blContainer, "Supports wildcards: * (any), ? (one char), [a-z], {a,b}. See api/wildcards.lua", 8)
  keywordsHelp:SetPoint("TOPLEFT", keywordsTitle, "BOTTOMLEFT", 0, -DBB2:ScaleSize(2))
  keywordsHelp:SetTextColor(0.5, 0.5, 0.5, 1)
  
  -- Keyword input box (account for + button and scrollbar space)
  local keywordInput = DBB2.api.CreateEditBox("DBB2BlacklistKeywordInput", blContainer)
  keywordInput:SetPoint("TOPLEFT", keywordsHelp, "BOTTOMLEFT", 0, -blSpacing)
  keywordInput:SetPoint("RIGHT", blContainer, "RIGHT", -(blBtnWidth + blSpacing + sliderWidth + blPadding + DBB2:ScaleSize(16)), 0)
  keywordInput:SetHeight(blInputHeight)
  
  keywordInput.placeholder = keywordInput:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  keywordInput.placeholder:SetFont("Fonts\\FRIZQT__.TTF", DBB2:GetFontSize(9))
  keywordInput.placeholder:SetPoint("LEFT", DBB2:ScaleSize(6), 0)
  keywordInput.placeholder:SetText("Enter keyword to block...")
  keywordInput.placeholder:SetTextColor(0.4, 0.4, 0.4, 1)
  
  keywordInput:SetScript("OnEditFocusGained", function()
    this.placeholder:Hide()
  end)
  
  keywordInput:SetScript("OnEditFocusLost", function()
    if this:GetText() == "" then
      this.placeholder:Show()
    end
  end)
  
  -- Add keyword button
  local addKeywordBtn = DBB2.api.CreateButton("DBB2AddKeywordBtn", blContainer, "+")
  addKeywordBtn:SetPoint("LEFT", keywordInput, "RIGHT", blSpacing, 0)
  addKeywordBtn:SetWidth(blBtnWidth)
  addKeywordBtn:SetHeight(blInputHeight)
  
  -- Rows container (fills remaining space, leaves room for scrollbar and bottom padding)
  local rowsContainer = CreateFrame("Frame", "DBB2BlacklistRowsContainer", blContainer)
  rowsContainer:SetPoint("TOPLEFT", keywordInput, "BOTTOMLEFT", 0, -blSpacing)
  rowsContainer:SetPoint("BOTTOMRIGHT", blacklistPanel, "BOTTOMRIGHT", -(sliderWidth + DBB2:ScaleSize(4)), DBB2:ScaleSize(5))
  
  blacklistPanel.rowsContainer = rowsContainer
  
  -- Position scrollbar aligned with rows container top, at panel's right edge with padding
  local blSliderPadding = DBB2:ScaleSize(5)
  blSlider:SetPoint("TOP", rowsContainer, "TOP", 0, -blSliderPadding)
  blSlider:SetPoint("BOTTOMRIGHT", blacklistPanel, "BOTTOMRIGHT", 0, blSliderPadding)
  
  -- Helper function to convert keywords array to comma-separated string
  local function KeywordsToString()
    local keywords = DBB2.api.GetBlacklistedKeywords()
    -- table.concat is more efficient than manual concatenation
    return table.concat(keywords, ",")
  end
  
  -- Helper function to parse comma-separated string to keywords
  local function StringToKeywords(str)
    local keywords = {}
    for kw in string.gfind(str, "([^,]+)") do
      kw = string.gsub(kw, "^%s*(.-)%s*$", "%1")
      if kw ~= "" then
        table.insert(keywords, kw)
      end
    end
    return keywords
  end
  
  -- Update import/export box with current keywords
  local function UpdateImportExportBox()
    importExportBox:SetText(KeywordsToString())
  end
  
  -- Pattern descriptions for common/default patterns
  local patternDescriptions = {
    ["<*>"] = "<Guild Name>",
    ["[??]"] = "[pl], [it]",
    ["[???]"] = "[pol], [ita]",
    ["recruit*"] = "recruit, recruiting",
    ["recrut*"] = "recrut, recrute, recruting",
  }
  
  -- Helper function to create a blacklist row
  local function CreateBlacklistRow(index)
    local row = CreateFrame("Frame", "DBB2KeywordRow" .. index, rowsContainer)
    row:SetHeight(blRowHeight)
    
    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.name:SetFont("Fonts\\FRIZQT__.TTF", DBB2:GetFontSize(10))
    row.name:SetPoint("LEFT", DBB2:ScaleSize(5), 0)
    row.name:SetWidth(DBB2:ScaleSize(180))
    row.name:SetJustifyH("LEFT")
    row.name:SetTextColor(1, 1, 1, 1)
    
    -- Description label (gray, anchored to left of X button)
    row.desc = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.desc:SetFont("Fonts\\FRIZQT__.TTF", DBB2:GetFontSize(8))
    row.desc:SetJustifyH("RIGHT")
    row.desc:SetTextColor(0.5, 0.5, 0.5, 1)
    
    row.removeBtn = CreateFrame("Button", nil, row)
    row.removeBtn:SetWidth(DBB2:ScaleSize(16))
    row.removeBtn:SetHeight(DBB2:ScaleSize(16))
    row.removeBtn:SetPoint("RIGHT", -DBB2:ScaleSize(58), 0)
    
    -- Anchor description to left of remove button
    row.desc:SetPoint("RIGHT", row.removeBtn, "LEFT", -DBB2:ScaleSize(8), 0)
    
    row.removeBtn.text = row.removeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.removeBtn.text:SetFont("Fonts\\FRIZQT__.TTF", DBB2:GetFontSize(11))
    row.removeBtn.text:SetPoint("CENTER", 0, 0)
    row.removeBtn.text:SetText("x")
    row.removeBtn.text:SetTextColor(1, 0.3, 0.3, 1)
    
    row.removeBtn:SetScript("OnEnter", function()
      this.text:SetTextColor(1, 0.5, 0.5, 1)
    end)
    
    row.removeBtn:SetScript("OnLeave", function()
      this.text:SetTextColor(1, 0.3, 0.3, 1)
    end)
    
    return row
  end
  
  -- Helper to get description for a pattern
  local function GetPatternDescription(pattern)
    return patternDescriptions[pattern] or ""
  end
  
  -- Calculate total content height
  local function GetTotalContentHeight()
    local keywordCount = table.getn(DBB2.api.GetBlacklistedKeywords())
    return keywordCount * blRowHeight
  end
  
  -- Helper to get actual container height from rendered positions
  local function GetRowsContainerHeight()
    local top = rowsContainer:GetTop()
    local bottom = rowsContainer:GetBottom()
    if top and bottom then
      return top - bottom
    end
    return 100  -- fallback
  end
  
  -- Update row positions based on scroll offset
  local function UpdateRowPositions()
    local containerHeight = GetRowsContainerHeight()
    local scrollOffset = blacklistPanel.scrollOffset or 0
    local keywords = DBB2.api.GetBlacklistedKeywords()
    local keywordCount = table.getn(keywords)
    
    for i, row in ipairs(blacklistPanel.keywordRows) do
      if row then
        -- Only show rows that have corresponding keywords
        if i > keywordCount then
          row:Hide()
        else
          local baseY = -((i - 1) * blRowHeight)
          local yPos = baseY + scrollOffset
          
          row:ClearAllPoints()
          row:SetPoint("TOPLEFT", rowsContainer, "TOPLEFT", 0, yPos)
          row:SetPoint("RIGHT", rowsContainer, "RIGHT", 0, 0)
          
          local rowTop = yPos
          local rowBottom = yPos - blRowHeight
          if rowTop > 0 or rowBottom < -containerHeight then
            row:Hide()
          else
            row:Show()
          end
        end
      end
    end
  end
  
  -- Update scrollbar state
  local function UpdateBlacklistScrollbar()
    local containerHeight = GetRowsContainerHeight()
    local totalHeight = GetTotalContentHeight()
    local maxScroll = math.max(0, totalHeight - containerHeight)
    
    blSlider:SetMinMaxValues(0, maxScroll)
    blSlider:SetValue(blacklistPanel.scrollOffset or 0)
    
    if totalHeight > 0 and containerHeight > 0 then
      local ratio = containerHeight / totalHeight
      if ratio < 1 then
        local thumbHeight = math.max(DBB2:ScaleSize(20), containerHeight * ratio)
        blSlider.thumb:SetHeight(thumbHeight)
        blSlider:Show()
      else
        blSlider:Hide()
      end
    else
      blSlider:Hide()
    end
  end
  
  -- Function to rebuild keyword list
  local function RebuildKeywordList()
    for _, row in ipairs(blacklistPanel.keywordRows) do
      row:Hide()
    end
    
    local keywords = DBB2.api.GetBlacklistedKeywords()
    
    for i, keyword in ipairs(keywords) do
      local row = blacklistPanel.keywordRows[i]
      if not row then
        row = CreateBlacklistRow(i)
        blacklistPanel.keywordRows[i] = row
      end
      
      row.value = keyword
      row.name:SetText(keyword)
      row.desc:SetText(GetPatternDescription(keyword))
      
      -- Capture keyword value directly to avoid closure issues with loop variable
      local keywordToRemove = keyword
      row.removeBtn:SetScript("OnClick", function()
        DBB2.api.RemoveKeywordFromBlacklist(keywordToRemove)
        RebuildKeywordList()
        UpdateImportExportBox()
      end)
    end
    
    UpdateBlacklistScrollbar()
    UpdateRowPositions()
    UpdateImportExportBox()
  end
  
  -- Add keyword button click
  addKeywordBtn:SetScript("OnClick", function()
    local kw = keywordInput:GetText()
    if kw and kw ~= "" then
      DBB2.api.AddKeywordToBlacklist(kw)
      keywordInput:SetText("")
      keywordInput.placeholder:Show()
      RebuildKeywordList()
    end
  end)
  
  keywordInput:SetScript("OnEnterPressed", function()
    local kw = this:GetText()
    if kw and kw ~= "" then
      DBB2.api.AddKeywordToBlacklist(kw)
      this:SetText("")
      this.placeholder:Show()
      RebuildKeywordList()
    end
    this:ClearFocus()
  end)
  
  -- Import/Export box handlers
  importExportBox:SetScript("OnEnterPressed", function()
    local str = this:GetText()
    local newKeywords = StringToKeywords(str)
    
    -- Clear existing keywords by replacing the table
    DBB2_Config.blacklist.keywords = {}
    
    -- Add new keywords in order
    for _, kw in ipairs(newKeywords) do
      DBB2.api.AddKeywordToBlacklist(kw)
    end
    
    this:ClearFocus()
    RebuildKeywordList()
  end)
  
  importExportBox:SetScript("OnEditFocusLost", function()
    UpdateImportExportBox()
  end)
  
  -- Slider value changed
  blSlider:SetScript("OnValueChanged", function()
    blacklistPanel.scrollOffset = this:GetValue()
    UpdateRowPositions()
  end)
  
  -- Mouse wheel scrolling on rows container
  rowsContainer:EnableMouseWheel(true)
  rowsContainer:SetScript("OnMouseWheel", function()
    local containerHeight = GetRowsContainerHeight()
    local totalHeight = GetTotalContentHeight()
    local maxScroll = math.max(0, totalHeight - containerHeight)
    
    local scrollSpeed = DBB2_Config.scrollSpeed or 20
    blacklistPanel.scrollOffset = (blacklistPanel.scrollOffset or 0) - (arg1 * scrollSpeed)
    
    if blacklistPanel.scrollOffset < 0 then
      blacklistPanel.scrollOffset = 0
    elseif blacklistPanel.scrollOffset > maxScroll then
      blacklistPanel.scrollOffset = maxScroll
    end
    
    blSlider:SetValue(blacklistPanel.scrollOffset)
    UpdateRowPositions()
  end)
  
  -- Update on container size change (window resize)
  rowsContainer:SetScript("OnSizeChanged", function()
    UpdateBlacklistScrollbar()
    UpdateRowPositions()
  end)
  
  -- Rebuild lists when panel is shown
  blacklistPanel:SetScript("OnShow", function()
    blacklistPanel.scrollOffset = 0
    blSlider:SetValue(0)
    
    blEnabledCheck:SetChecked(DBB2.api.IsBlacklistEnabled())
    
    RebuildKeywordList()
  end)
  
  -- Initial setup (delayed)
  -- Remove OnUpdate after initialization to stop per-frame calls
  blacklistPanel:SetScript("OnUpdate", function()
    if this.initialized then
      this:SetScript("OnUpdate", nil)
      return
    end
    local h = GetRowsContainerHeight()
    if h and h > 10 then
      this.initialized = true
      RebuildKeywordList()
      -- Remove OnUpdate after initialization
      this:SetScript("OnUpdate", nil)
    end
  end)
  
  -- Set default tab
  DBB2.gui.configTabs.SwitchTab("General")
end)
