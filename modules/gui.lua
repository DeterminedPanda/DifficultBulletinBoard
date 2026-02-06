-- Localize frequently used globals for performance
local string_lower = string.lower
local string_find = string.find
local string_len = string.len
local string_gfind = string.gfind
local string_gsub = string.gsub
local table_insert = table.insert
local table_getn = table.getn
local ipairs = ipairs
local pairs = pairs
local date = date
local math_max = math.max

DBB2:RegisterModule("gui", function()
  -- Initialize schema layout constants
  DBB2.schema.InitLayout()
  local S = DBB2.schema
  
  -- Constants
  local MAX_ROWS = 50
  local DEFAULT_ROW_HEIGHT = 16
  
  -- Create main GUI frame
  DBB2.gui = CreateFrame("Frame", "DBB2ConfigGUI", UIParent)
  DBB2.gui:SetMovable(true)
  DBB2.gui:EnableMouse(true)
  DBB2.gui:RegisterForDrag("LeftButton")
  DBB2.gui:SetWidth(539)
  DBB2.gui:SetHeight(343)
  DBB2.gui:SetFrameStrata("DIALOG")
  DBB2.gui:SetClampedToScreen(DBB2_Config.clampToScreen ~= false)
  DBB2.gui:SetPoint("CENTER", 0, 0)
  DBB2.gui:Hide()
  
  -- Load saved position and size
  DBB2.api.LoadPosition(DBB2.gui)
  
  DBB2.gui:SetScript("OnDragStart", function()
    this:StartMoving()
  end)
  
  DBB2.gui:SetScript("OnDragStop", function()
    this:StopMovingOrSizing()
    DBB2.api.SavePosition(this)
  end)
  
  -- Create backdrop
  DBB2:CreateBackdrop(DBB2.gui, nil, nil, 0.85)
  
  -- Make frame closable with ESC
  table_insert(UISpecialFrames, "DBB2ConfigGUI")
  
  -- Close button - in header area between borders
  local closeSize = DBB2:ScaleSize(14)
  local headerPadding = DBB2:ScaleSize(7)
  DBB2.gui.close = CreateFrame("Button", "DBB2Close", DBB2.gui)
  DBB2.gui.close:SetPoint("TOPRIGHT", -headerPadding, -headerPadding)
  DBB2.gui.close:SetHeight(closeSize)
  DBB2.gui.close:SetWidth(closeSize)
  DBB2:CreateBackdrop(DBB2.gui.close)
  
  DBB2.gui.close.texture = DBB2.gui.close:CreateTexture(nil, "OVERLAY")
  DBB2.gui.close.texture:SetTexture("Interface\\AddOns\\DifficultBulletinBoard\\img\\close")
  DBB2.gui.close.texture:SetPoint("CENTER", 0, 0)
  DBB2.gui.close.texture:SetWidth(DBB2:ScaleSize(16))
  DBB2.gui.close.texture:SetHeight(DBB2:ScaleSize(16))
  DBB2.gui.close.texture:SetVertexColor(1, 0.25, 0.25, 1)
  
  DBB2.gui.close:SetScript("OnEnter", function()
    this.backdrop:SetBackdropBorderColor(1, 0.25, 0.25, 1)
  end)
  
  DBB2.gui.close:SetScript("OnLeave", function()
    this.backdrop:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
  end)
  
  DBB2.gui.close:SetScript("OnClick", function()
    this:GetParent():Hide()
  end)
  
  -- Config button - in header area between borders
  DBB2.gui.configBtn = S.CreateButton("DBB2ConfigBtn", DBB2.gui, "Config")
  DBB2.gui.configBtn:SetPoint("RIGHT", DBB2.gui.close, "LEFT", -DBB2:ScaleSize(5), 0)
  DBB2.gui.configBtn:SetWidth(DBB2:ScaleSize(50))
  DBB2.gui.configBtn:SetHeight(closeSize)
  DBB2.gui.configBtn.text:SetTextColor(0.7, 0.7, 0.7, 1)  -- Match inactive tab color
  DBB2.gui.configBtn:SetScript("OnClick", function()
    DBB2.gui.tabs.SwitchTab("Config")
  end)
  
  -- Override hover scripts to respect active state
  DBB2.gui.configBtn:SetScript("OnEnter", function()
    if DBB2.gui.tabs.activeTab ~= "Config" then
      local r, g, b = DBB2:GetHighlightColor()
      this.backdrop:SetBackdropBorderColor(r, g, b, 1)
    end
  end)
  DBB2.gui.configBtn:SetScript("OnLeave", function()
    if DBB2.gui.tabs.activeTab ~= "Config" then
      this.backdrop:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
    end
  end)
  
  -- Create tab system using schema (horizontal tabs at top, height 14 to match close/refresh)
  local tabNames = {"Logs", "Groups", "Professions", "Hardcore", "Config"}
  DBB2.gui.tabs = S.CreateTabSystem("DBB2", DBB2.gui, tabNames, 70, 14)
  
  -- Hide the Config tab button (we use the separate Config button on the right)
  DBB2.gui.tabs.buttons["Config"]:Hide()
  
  -- Store original SwitchTab function
  local originalSwitchTab = DBB2.gui.tabs.SwitchTab
  
  -- Override SwitchTab to also handle Config button styling
  DBB2.gui.tabs.SwitchTab = function(tabName)
    -- Call original function
    originalSwitchTab(tabName)
    
    -- Update Config button styling
    local hr, hg, hb = DBB2:GetHighlightColor()
    if tabName == "Config" then
      DBB2.gui.configBtn.text:SetTextColor(hr, hg, hb, 1)
      DBB2.gui.configBtn.backdrop:SetBackdropBorderColor(hr, hg, hb, 1)
    else
      DBB2.gui.configBtn.text:SetTextColor(0.7, 0.7, 0.7, 1)
      DBB2.gui.configBtn.backdrop:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
    end
  end
  
  -- Tab change callback
  DBB2.gui.tabs.onTabChanged = function(tabName)
    -- Defer update to next frame to ensure panel dimensions are calculated
    -- This fixes the issue where messages don't fill width until resize
    local panel = DBB2.gui.tabs.panels[tabName]
    if panel then
      panel._needsContentUpdate = true
      panel._contentUpdateType = tabName
    end
  end
  
  -- =====================
  -- LOGS PANEL
  -- =====================
  local logsPanel = DBB2.gui.tabs.panels["Logs"]
  
  -- Filter input with placeholder (uses schema constants)
  DBB2.gui.filterInput = S.CreateFilterInput("DBB2FilterInput", logsPanel)
  DBB2.gui.filterInput:SetPoint("TOPLEFT", logsPanel, "TOPLEFT", 0, 0)
  DBB2.gui.filterInput:SetPoint("TOPRIGHT", logsPanel, "TOPRIGHT", -S.TIME_COLUMN_WIDTH, 0)
  
  -- Current time display - aligned with message timestamps
  DBB2.gui.currentTimeText = S.CreateCurrentTimeDisplay(logsPanel)
  -- Position to align with row timestamps
  DBB2.gui.currentTimeText:SetPoint("RIGHT", logsPanel, "TOPRIGHT", -S.SCROLLBAR_SPACE + S.TIMESTAMP_RIGHT_OFFSET, -(S.FILTER_HEIGHT / 2))
  
  -- Also store reference on logsPanel for config onChange handler compatibility
  logsPanel.currentTimeText = DBB2.gui.currentTimeText
  
  -- Hide by default (controlled by config)
  if not DBB2_Config.showCurrentTime then
    DBB2.gui.currentTimeText:Hide()
  end
  
  -- Global time update frame (updates all panels at once for smooth tab transitions)
  -- Also handles periodic refresh of relative timestamps
  -- Only create once, on the main GUI frame so it always runs
  if not DBB2.gui.globalTimeFrame then
    DBB2.gui.globalTimeFrame = CreateFrame("Frame", nil, DBB2.gui)
    DBB2.gui.globalTimeFrame.elapsed = 0
    DBB2.gui.globalTimeFrame.relativeTimeElapsed = 0
    DBB2.gui.globalTimeFrame:SetScript("OnUpdate", function()
      this.elapsed = this.elapsed + arg1
      this.relativeTimeElapsed = this.relativeTimeElapsed + arg1
      
      -- Update current time display every second
      if this.elapsed >= 1 then
        this.elapsed = 0
        if DBB2_Config.showCurrentTime then
          local timeStr = date("%H:%M:%S")
          -- Update Logs panel
          if DBB2.gui.currentTimeText then
            DBB2.gui.currentTimeText:SetText(timeStr)
          end
          -- Update categorized panels (Groups, Professions, Hardcore)
          local panels = {"Groups", "Professions", "Hardcore"}
          for _, panelName in ipairs(panels) do
            local panel = DBB2.gui.tabs.panels[panelName]
            if panel and panel.currentTimeText then
              panel.currentTimeText:SetText(timeStr)
            end
          end
        end
        
        -- Update elapsed timestamps every second (mode 2)
        if DBB2_Config.timeDisplayMode == 2 and DBB2.gui:IsShown() then
          if DBB2.gui.tabs and DBB2.gui.tabs.activeTab then
            local activeTab = DBB2.gui.tabs.activeTab
            if activeTab == "Logs" then
              if DBB2.gui.UpdateTimestampsOnly then DBB2.gui:UpdateTimestampsOnly() end
            else
              local panel = DBB2.gui.tabs.panels[activeTab]
              if panel and panel.UpdateTimestampsOnly then panel.UpdateTimestampsOnly() end
            end
          end
        end
      end
      
      -- Update relative timestamps every 30 seconds (to keep them fresh)
      if this.relativeTimeElapsed >= 30 then
        this.relativeTimeElapsed = 0
        if DBB2_Config.timeDisplayMode == 1 and DBB2.gui:IsShown() then
          -- Refresh active panel to update relative times
          if DBB2.gui.tabs and DBB2.gui.tabs.activeTab then
            local activeTab = DBB2.gui.tabs.activeTab
            if activeTab == "Logs" then
              if DBB2.gui.UpdateMessages then DBB2.gui:UpdateMessages() end
            else
              local panel = DBB2.gui.tabs.panels[activeTab]
              if panel and panel.UpdateCategories then panel.UpdateCategories() end
            end
          end
        end
      end
    end)
  end
  
  -- Store current filter terms
  DBB2.gui.filterTerms = {}
  
  -- Throttle state for filter updates
  DBB2.gui.filterPending = false
  DBB2.gui.filterLastText = ""
  
  -- Parse filter input into terms (minimum 2 characters per term)
  local function ParseFilterTerms(text)
    local terms = {}
    if text and text ~= "" then
      -- Split by comma
      for term in string_gfind(text, "([^,]+)") do
        -- Trim whitespace and convert to lowercase
        term = string_gsub(term, "^%s*(.-)%s*$", "%1")
        term = string_lower(term)
        -- Only include terms with at least 2 characters
        if string_len(term) >= 2 then
          table_insert(terms, term)
        end
      end
    end
    return terms
  end
  
  -- Check if message matches any filter term
  local function MessageMatchesFilter(message, terms)
    if table_getn(terms) == 0 then
      return true  -- No filter = all match
    end
    local lowerMsg = string_lower(message or "")
    for _, term in ipairs(terms) do
      if string_find(lowerMsg, term, 1, true) then
        return true
      end
    end
    return false
  end
  
  -- Throttled filter update (runs on next frame to avoid stale GetText)
  local function ScheduleLogsFilterUpdate()
    DBB2.gui.filterPending = true
  end
  
  -- Process pending filter update (called from OnUpdate)
  DBB2.gui.filterInput:SetScript("OnUpdate", function()
    if not DBB2.gui.filterPending then return end
    DBB2.gui.filterPending = false
    
    local currentText = this:GetText() or ""
    -- Only update if text actually changed (avoids redundant updates)
    if currentText ~= DBB2.gui.filterLastText then
      DBB2.gui.filterLastText = currentText
      DBB2.gui.filterTerms = ParseFilterTerms(currentText)
      -- Reset scroll to top when filter changes
      if DBB2.gui.scroll then
        DBB2.gui.scroll:SetVerticalScroll(0)
      end
      DBB2.gui:UpdateMessages()
    end
  end)
  
  -- Update filter on text change (schedules update for next frame)
  DBB2.gui.filterInput:SetScript("OnTextChanged", function()
    ScheduleLogsFilterUpdate()
  end)
  
  DBB2.gui.filterInput:SetScript("OnEnterPressed", function()
    this:ClearFocus()
  end)
  
  -- Create scroll frame for messages (using schema)
  DBB2.gui.scroll = S.CreateScrollFrame("DBB2ScrollFrame", logsPanel)
  DBB2.gui.scroll:SetPoint("TOPLEFT", logsPanel, "TOPLEFT", 0, -(S.FILTER_HEIGHT + S.FILTER_PADDING))
  DBB2.gui.scroll:SetPoint("BOTTOMRIGHT", logsPanel, "BOTTOMRIGHT", 0, 0)
  logsPanel.scrollFrame = DBB2.gui.scroll  -- Register for OnShow update
  
  -- Create scroll child (using schema)
  DBB2.gui.scrollchild = S.CreateScrollChild("DBB2ScrollChild", DBB2.gui.scroll)
  
  -- Message row pool (using schema)
  DBB2.gui.messageRows = {}
  local ROW_HEIGHT = S.ROW_HEIGHT
  
  -- Pre-create message rows using schema
  for i = 1, MAX_ROWS do
    local row = S.CreateMessageRow("DBB2MsgRow" .. i, DBB2.gui.scrollchild)
    row:SetPoint("TOPLEFT", DBB2.gui.scrollchild, "TOPLEFT", S.ROW_LEFT_PADDING, -((i-1) * ROW_HEIGHT))
    row:SetPoint("RIGHT", DBB2.gui.scrollchild, "RIGHT", -S.SCROLLBAR_SPACE, 0)
    row:Hide()
    DBB2.gui.messageRows[i] = row
  end
  
  -- Continuously update scroll child dimensions
  local lastChildHeight = 0
  local lastScrollWidth = 0
  DBB2.gui.scroll:SetScript("OnUpdate", function()
    -- Check for deferred scroll update
    if this._needsScrollUpdate then
      this._needsScrollUpdate = false
      this.UpdateScrollState()
    end
    
    -- Early exit if not visible
    if not this:IsVisible() then return end
    
    -- Use actual rendered width (right - left) instead of GetWidth()
    local scrollLeft = this:GetLeft()
    local scrollRight = this:GetRight()
    if not scrollLeft or not scrollRight then return end
    
    local scrollWidth = scrollRight - scrollLeft
    local scrollHeight = this:GetHeight()
    
    -- Early exit if dimensions not ready
    if scrollWidth <= 0 or not scrollHeight or scrollHeight <= 0 then return end
    
    -- Only update if width changed
    if scrollWidth ~= lastScrollWidth then
      lastScrollWidth = scrollWidth
      DBB2.gui.scrollchild:SetWidth(scrollWidth)
      -- Defer message refresh to coalesce with resize updates
      DBB2.gui._resizePending = true
    end
    
    -- Calculate content height based on visible rows
    local visibleRows = 0
    for i = 1, MAX_ROWS do
      if DBB2.gui.messageRows[i]:IsShown() then
        visibleRows = visibleRows + 1
      end
    end
    
    local contentHeight = visibleRows * S.ROW_HEIGHT
    local newChildHeight = contentHeight
    
    if newChildHeight ~= lastChildHeight then
      DBB2.gui.scrollchild:SetHeight(newChildHeight)
      DBB2.gui.scrollchild:SetWidth(scrollWidth)
      lastChildHeight = newChildHeight
    end
    
    this.UpdateScrollState()
  end)
  
  -- Function to update messages
  function DBB2.gui:UpdateMessages()
    local count = table_getn(DBB2.messages)
    local filterTerms = DBB2.gui.filterTerms or {}
    local hasFilter = table_getn(filterTerms) > 0
    
    -- Hide all rows first
    for i = 1, MAX_ROWS do
      DBB2.gui.messageRows[i]:Hide()
    end
    
    if count > 0 then
      local rowIndex = 1
      
      -- Display messages (newest first)
      -- Only show messages that match Groups or Professions tags (not Hardcore)
      for i = count, 1, -1 do
        local msg = DBB2.messages[i]
        if msg and rowIndex <= MAX_ROWS then
          -- Check message categories
          local categories = nil
          if DBB2.api.CategorizeMessage then
            categories = DBB2.api.CategorizeMessage(msg.message)
          end
          
          if categories and categories.isHardcore then
          else
            -- Check if message matches any Groups or Professions tag
            local matchesCategory = false
            if categories then
              matchesCategory = (table_getn(categories.groups) > 0) or (table_getn(categories.professions) > 0)
            end
            
            -- Only show messages that match at least one category
            if matchesCategory then
              local row = DBB2.gui.messageRows[rowIndex]
              local timeStr, isOverHour = DBB2.api.FormatMessageTime(msg.time)
              
              -- Check if message matches filter
              local matches = true
              if hasFilter then
                matches = false
                local lowerMsg = string_lower(msg.message or "")
                for _, term in ipairs(filterTerms) do
                  if string_find(lowerMsg, term, 1, true) then
                    matches = true
                    break
                  end
                end
              end
              
              -- Determine class color (placeholder - white for now)
              local classColor = "|cffffffff"
              
              row:SetData(msg.sender, msg.message, timeStr, classColor)
              row._msgTime = msg.time  -- Store for lightweight time updates
              
              -- Apply filter styling
              if hasFilter and not matches then
                -- Greyed out: subtle dimmed text
                row.message:SetTextColor(0.35, 0.35, 0.35, 1)
                row.charName:SetTextColor(0.35, 0.35, 0.35, 1)
                row.time:SetTextColor(0.25, 0.25, 0.25, 1)
              else
                -- Normal colors (no filter or matches)
                row.message:SetTextColor(0.9, 0.9, 0.9, 1)
                -- Only set charName color if not currently hovered
                if not row.charNameBtn or not row.charNameBtn.isHovered then
                  row.charName:SetTextColor(1, 1, 1, 1)
                end
                -- Red if over 1 hour in elapsed mode
                if isOverHour then
                  row.time:SetTextColor(1, 0.3, 0.3, 1)
                else
                  row.time:SetTextColor(0.5, 0.5, 0.5, 1)
                end
              end
              
              row:Show()
              rowIndex = rowIndex + 1
            end
          end
        end
      end
    end
    
    DBB2.gui.scroll:SetVerticalScroll(0)
  end
  
  -- Lightweight function to update only timestamps (no row rebuilding)
  function DBB2.gui:UpdateTimestampsOnly()
    for i = 1, MAX_ROWS do
      local row = DBB2.gui.messageRows[i]
      if row:IsShown() and row._msgTime then
        local timeStr, isOverHour = DBB2.api.FormatMessageTime(row._msgTime)
        row.time:SetText(timeStr)
        -- Red if over 1 hour in elapsed mode
        if isOverHour then
          row.time:SetTextColor(1, 0.3, 0.3, 1)
        else
          row.time:SetTextColor(0.5, 0.5, 0.5, 1)
        end
      end
    end
  end
  
  -- =====================
  -- CATEGORIZED PANELS (Groups, Professions, Hardcore)
  -- =====================
  
  -- Create categorized panel for each type
  local function CreateCategorizedPanel(panelName, categoryType)
    local panel = DBB2.gui.tabs.panels[panelName]
    
    -- Shared row pool constants
    local MAX_POOL_ROWS = 100
    local ROW_HEIGHT = S.ROW_HEIGHT
    
    -- Filter input with placeholder (using schema)
    panel.filterInput = S.CreateFilterInput("DBB2" .. panelName .. "FilterInput", panel)
    panel.filterInput:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
    panel.filterInput:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -S.TIME_COLUMN_WIDTH, 0)
    
    -- Current time display - aligned with message timestamps (using schema)
    panel.currentTimeText = S.CreateCurrentTimeDisplay(panel)
    panel.currentTimeText:SetPoint("RIGHT", panel, "TOPRIGHT", -S.SCROLLBAR_SPACE + S.TIMESTAMP_RIGHT_OFFSET, -(S.FILTER_HEIGHT / 2))
    
    -- Hide by default (controlled by config)
    if not DBB2_Config.showCurrentTime then
      panel.currentTimeText:Hide()
    end
    
    -- Store filter terms
    panel.filterTerms = {}
    
    -- Throttle state for filter updates
    panel.filterPending = false
    panel.filterLastText = ""
    
    -- Parse filter input into terms (minimum 2 characters per term)
    local function ParseFilterTerms(text)
      local terms = {}
      if text and text ~= "" then
        for term in string_gfind(text, "([^,]+)") do
          term = string_gsub(term, "^%s*(.-)%s*$", "%1")
          term = string_lower(term)
          -- Only include terms with at least 2 characters
          if string_len(term) >= 2 then
            table_insert(terms, term)
          end
        end
      end
      return terms
    end
    
    -- Throttled filter update (runs on next frame to avoid stale GetText)
    local function ScheduleFilterUpdate()
      if panel.filterPending then return end
      panel.filterPending = true
    end
    
    -- Process pending filter update (called from OnUpdate)
    panel.filterInput:SetScript("OnUpdate", function()
      if not panel.filterPending then return end
      panel.filterPending = false
      
      local currentText = this:GetText() or ""
      -- Only update if text actually changed (avoids redundant updates)
      if currentText ~= panel.filterLastText then
        panel.filterLastText = currentText
        panel.filterTerms = ParseFilterTerms(currentText)
        -- Reset scroll to top when filter changes
        if panel.scroll then
          panel.scroll:SetVerticalScroll(0)
        end
        if panel.UpdateCategories then
          panel.UpdateCategories()
        end
      end
    end)
    
    -- Update filter on text change (schedules update for next frame)
    panel.filterInput:SetScript("OnTextChanged", function()
      ScheduleFilterUpdate()
    end)
    
    panel.filterInput:SetScript("OnEnterPressed", function()
      this:ClearFocus()
    end)
    
    -- Create scroll frame for categories (using schema)
    local scroll = S.CreateScrollFrame("DBB2" .. panelName .. "Scroll", panel)
    scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -(S.FILTER_HEIGHT + S.FILTER_PADDING))
    scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 0)
    panel.scrollFrame = scroll  -- Register for OnShow update
    
    local scrollchild = S.CreateScrollChild("DBB2" .. panelName .. "ScrollChild", scroll)
    
    -- Store references
    panel.scroll = scroll
    panel.scrollchild = scrollchild
    panel.categoryType = categoryType
    panel.categoryFrames = {}
    
    -- Shared row pool (like Logs panel)
    panel.rowPool = {}
    panel.rowPoolIndex = 0
    
    -- Pre-create pooled rows (using schema)
    for i = 1, MAX_POOL_ROWS do
      local row = S.CreateMessageRow("DBB2" .. panelName .. "PoolRow" .. i, scrollchild)
      row:Hide()
      panel.rowPool[i] = row
    end
    
    -- Get next available row from pool
    local function GetPooledRow()
      panel.rowPoolIndex = panel.rowPoolIndex + 1
      if panel.rowPoolIndex <= MAX_POOL_ROWS then
        return panel.rowPool[panel.rowPoolIndex]
      end
      return nil
    end
    
    -- Reset pool at start of each update
    local function ResetRowPool()
      for i = 1, panel.rowPoolIndex do
        if panel.rowPool[i] then
          panel.rowPool[i]:Hide()
        end
      end
      panel.rowPoolIndex = 0
    end
    
    -- Helper function to check if category tags match any filter term
    local function CategoryMatchesFilter(cat, filterTerms)
      if not cat or not cat.tags then return false end
      for _, term in ipairs(filterTerms) do
        -- Check category tags (exact match only)
        for _, tag in ipairs(cat.tags) do
          if string_lower(tag) == term then
            return true
          end
        end
      end
      return false
    end
    
    -- Update function for this panel
    panel.UpdateCategories = function()
      -- Reset row pool
      ResetRowPool()
      
      -- Hide all existing category frames
      for _, frame in pairs(panel.categoryFrames) do
        frame:Hide()
      end
      
      local categorized = DBB2.api.GetCategorizedMessages(categoryType)
      local categories = DBB2.api.GetCategories(categoryType)
      local yOffset = 0
      local hr, hg, hb = DBB2:GetHighlightColor()
      local filterTerms = panel.filterTerms or {}
      local hasFilter = table_getn(filterTerms) > 0
      
      for _, cat in ipairs(categories) do
        if cat.selected then
          -- Level filter check for Groups tab only
          -- Skip categories outside player's level range when filter is enabled
          local passesLevelFilter = true
          if categoryType == "groups" and DBB2_Config.showLevelFilteredGroups then
            passesLevelFilter = DBB2.api.IsLevelAppropriate(cat.name)
          end
          
          if passesLevelFilter then
          local messages = categorized[cat.name] or {}
          local msgCount = table_getn(messages)
          local isCollapsed = DBB2.api.IsCategoryCollapsed(categoryType, cat.name)
          
          -- Check if this category is locked (only for Groups tab)
          -- Locked categories display with red [Saved] tag but function normally
          -- (can be expanded/collapsed, notifications work, etc.)
          local isLocked = false
          local lockoutInfo = nil
          if categoryType == "groups" and DBB2.api.IsCategoryLocked then
            isLocked = DBB2.api.IsCategoryLocked(cat.name)
            if isLocked then
              lockoutInfo = DBB2.api.GetCategoryLockout(cat.name)
            end
          end
          
          -- Check if category matches filter via tags/name
          local categoryMatchesTags = hasFilter and CategoryMatchesFilter(cat, filterTerms)
          
          -- Filter messages if filter is active
          local filteredMessages = {}
          if hasFilter then
            if categoryMatchesTags then
              -- Category matches by tag/name - show ALL its messages
              filteredMessages = messages
            else
              -- Category doesn't match by tag - filter messages by content
              for _, msg in ipairs(messages) do
                local lowerMsg = string_lower(msg.message or "")
                for _, term in ipairs(filterTerms) do
                  if string_find(lowerMsg, term, 1, true) then
                    table_insert(filteredMessages, msg)
                    break
                  end
                end
              end
            end
          else
            filteredMessages = messages
          end
          
          local filteredCount = table_getn(filteredMessages)
          
          if hasFilter and filteredCount == 0 and not categoryMatchesTags then
          else
            -- Always show enabled categories (even with 0 messages when no filter)
            -- Get or create category frame
            local catFrame = panel.categoryFrames[cat.name]
            if not catFrame then
              catFrame = CreateFrame("Frame", nil, scrollchild)
              -- No right offset - let rows handle their own offset like Logs panel
              catFrame:SetPoint("LEFT", scrollchild, "LEFT", 0, 0)
              catFrame:SetPoint("RIGHT", scrollchild, "RIGHT", 0, 0)
              panel.categoryFrames[cat.name] = catFrame
              
              -- Clickable header button (for collapse only)
              catFrame.headerBtn = CreateFrame("Button", nil, catFrame)
              catFrame.headerBtn:SetPoint("TOPLEFT", 0, 0)
              catFrame.headerBtn:SetPoint("TOPRIGHT", 0, 0)
              catFrame.headerBtn:SetHeight(S.CATEGORY_HEADER_HEIGHT)
              catFrame.headerBtn:EnableMouse(true)
              
              -- Collapse indicator
              catFrame.collapseIndicator = catFrame.headerBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
              catFrame.collapseIndicator:SetFont("Fonts\\FRIZQT__.TTF", DBB2:GetFontSize(14))
              catFrame.collapseIndicator:SetPoint("LEFT", S.ROW_LEFT_PADDING, 0)
              catFrame.collapseIndicator:SetWidth(DBB2:ScaleSize(12))
              catFrame.collapseIndicator:SetText("+")
              
              -- Category header text
              catFrame.header = catFrame.headerBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
              catFrame.header:SetFont("Fonts\\FRIZQT__.TTF", DBB2:GetFontSize(10))
              catFrame.header:SetPoint("LEFT", catFrame.collapseIndicator, "RIGHT", 3, 0)
              catFrame.header:SetTextColor(hr, hg, hb, 1)
              
              -- Bell button for notifications (right after header text)
              local bellSize = DBB2:ScaleSize(14)
              catFrame.bellBtn = CreateFrame("Button", nil, catFrame)
              catFrame.bellBtn:SetPoint("LEFT", catFrame.header, "RIGHT", 3, 0)
              catFrame.bellBtn:SetWidth(bellSize)
              catFrame.bellBtn:SetHeight(bellSize)
              catFrame.bellBtn:SetFrameLevel(catFrame.headerBtn:GetFrameLevel() + 1)
              catFrame.bellBtn:EnableMouse(true)
              
              catFrame.bellIcon = catFrame.bellBtn:CreateTexture(nil, "OVERLAY")
              catFrame.bellIcon:SetTexture("Interface\\AddOns\\DifficultBulletinBoard\\img\\bell")
              catFrame.bellIcon:SetAllPoints()
              catFrame.bellIcon:SetVertexColor(1, 1, 1, 1)
              catFrame.bellBtn:Hide()
              
              -- Store references for bell click handler
              catFrame.bellBtn.categoryName = cat.name
              catFrame.bellBtn.categoryType = categoryType
              catFrame.bellBtn.catFrame = catFrame
              
              catFrame.bellBtn:SetScript("OnClick", function()
                local isEnabled = DBB2.api.IsNotificationEnabled(this.categoryType, this.categoryName)
                DBB2.api.SetNotificationEnabled(this.categoryType, this.categoryName, not isEnabled)
                panel.UpdateCategories()
              end)
              
              catFrame.bellBtn:SetScript("OnEnter", function()
                -- Brighten the bell on hover
                this.catFrame.bellIcon:SetVertexColor(1, 1, 1, 1)
              end)
              
              catFrame.bellBtn:SetScript("OnLeave", function()
                -- Restore bell state based on notification status
                local isEnabled = DBB2.api.IsNotificationEnabled(this.categoryType, this.categoryName)
                if isEnabled then
                  this.catFrame.bellIcon:SetVertexColor(1, 1, 1, 1)
                  this:Show()
                else
                  -- Hide if header is not hovered
                  if not MouseIsOver(this.catFrame.headerBtn) then
                    this:Hide()
                  else
                    -- Still hovering header, keep dimmed
                    this.catFrame.bellIcon:SetVertexColor(1, 1, 1, 0.5)
                  end
                end
              end)
              
              -- Store references for click handler
              catFrame.categoryName = cat.name
              catFrame.categoryType = categoryType
              
              -- Click handler (collapse only)
              catFrame.headerBtn:SetScript("OnClick", function()
                DBB2.api.ToggleCategoryCollapsed(catFrame.categoryType, catFrame.categoryName)
                panel.UpdateCategories()
              end)
              
              -- Hover effect - show bell on hover (dimmed) only if notifications mode is not off
              catFrame.headerBtn:SetScript("OnEnter", function()
                catFrame.header:SetTextColor(1, 1, 1, 1)
                catFrame.collapseIndicator:SetTextColor(1, 1, 1, 1)
                -- Show bell (dimmed) on hover only if notification mode is not off
                local notifyMode = DBB2.api.GetNotificationMode()
                if notifyMode > 0 then
                  catFrame.bellBtn:Show()
                  local isEnabled = DBB2.api.IsNotificationEnabled(catFrame.categoryType, catFrame.categoryName)
                  if not isEnabled then
                    catFrame.bellIcon:SetVertexColor(1, 1, 1, 0.5)
                  end
                end

              end)
              
              catFrame.headerBtn:SetScript("OnLeave", function()
                -- Restore appropriate color based on current state (stored on frame)
                local hr, hg, hb = DBB2:GetHighlightColor()
                -- Check if collapsed (+ means collapsed)
                local isCollapsed = catFrame.collapseIndicator:GetText() == "+"
                
                -- Collapse indicator: always red when collapsed
                if isCollapsed then
                  catFrame.collapseIndicator:SetTextColor(0.8, 0.3, 0.3, 1)
                elseif catFrame.isLocked then
                  catFrame.collapseIndicator:SetTextColor(0.8, 0.3, 0.3, 1)
                elseif catFrame.currentMsgCount and catFrame.currentMsgCount > 0 then
                  catFrame.collapseIndicator:SetTextColor(hr, hg, hb, 1)
                else
                  catFrame.collapseIndicator:SetTextColor(0.5, 0.5, 0.5, 1)
                end
                
                -- Header color based on locked/message state (not collapse state)
                if catFrame.isLocked then
                  catFrame.header:SetTextColor(0.8, 0.3, 0.3, 1)
                elseif catFrame.currentMsgCount and catFrame.currentMsgCount > 0 then
                  catFrame.header:SetTextColor(hr, hg, hb, 1)
                else
                  catFrame.header:SetTextColor(0.5, 0.5, 0.5, 1)
                end
                -- Hide bell if not enabled and not hovering bell itself
                local isEnabled = DBB2.api.IsNotificationEnabled(catFrame.categoryType, catFrame.categoryName)
                if not isEnabled and not MouseIsOver(catFrame.bellBtn) then
                  catFrame.bellBtn:Hide()
                end
                DBB2.api.HideTooltip()
              end)
            end
            
            -- Store lockout state on frame
            catFrame.isLocked = isLocked
            catFrame.lockoutInfo = lockoutInfo
            
            -- Update collapse indicator
            if isCollapsed then
              catFrame.collapseIndicator:SetText("+")
              catFrame.collapseIndicator:SetTextColor(0.8, 0.3, 0.3, 1)  -- Red when collapsed
            else
              catFrame.collapseIndicator:SetText("-")
            end
            
            -- Update header with count (show filtered count if filtering)
            local displayCount = filteredCount
            -- Store current message count on frame for OnLeave handler
            catFrame.currentMsgCount = displayCount
            
            -- Determine header text and color based on lockout and message count
            local headerText = cat.name
            if displayCount > 0 then
              headerText = cat.name .. " (" .. displayCount .. ")"
            end
            
            -- Add lockout indicator to header with reset time
            if isLocked and lockoutInfo then
              local remaining = lockoutInfo.resetTime - time()
              local timeStr = DBB2.api.FormatTimeRemaining(remaining)
              headerText = headerText .. " |cffff6666[Saved - " .. timeStr .. "]|r"
              catFrame.header:SetText(headerText)
              catFrame.header:SetTextColor(0.8, 0.3, 0.3, 1)
              if not isCollapsed then
                catFrame.collapseIndicator:SetTextColor(0.8, 0.3, 0.3, 1)
              end
            elseif displayCount > 0 then
              catFrame.header:SetText(headerText)
              catFrame.header:SetTextColor(hr, hg, hb, 1)
              if not isCollapsed then
                catFrame.collapseIndicator:SetTextColor(hr, hg, hb, 1)
              end
            else
              catFrame.header:SetText(headerText)
              catFrame.header:SetTextColor(0.5, 0.5, 0.5, 1)
              if not isCollapsed then
                catFrame.collapseIndicator:SetTextColor(0.5, 0.5, 0.5, 1)
              end
            end
            
            -- Show/hide bell button based on notification state and mode
            local notifyMode = DBB2.api.GetNotificationMode()
            local notifyEnabled = DBB2.api.IsNotificationEnabled(categoryType, cat.name)
            if notifyMode > 0 and notifyEnabled then
              catFrame.bellBtn:Show()
              catFrame.bellIcon:SetVertexColor(1, 1, 1, 1)
            else
              catFrame.bellBtn:Hide()
              catFrame.bellIcon:SetVertexColor(1, 1, 1, 0.5)
            end
            -- Update bell button references (in case category was reused)
            catFrame.bellBtn.categoryName = cat.name
            catFrame.bellBtn.categoryType = categoryType
            
            -- Position category frame - use explicit width from scroll frame
            catFrame:ClearAllPoints()
            catFrame:SetPoint("TOPLEFT", scrollchild, "TOPLEFT", 0, -yOffset)
            -- Get scroll frame width and set catFrame width explicitly
            -- Subtract scrollbar space to avoid overlap
            local sfLeft = scroll:GetLeft()
            local sfRight = scroll:GetRight()
            if sfLeft and sfRight and sfRight > sfLeft then
              catFrame:SetWidth(sfRight - sfLeft - S.SCROLLBAR_SPACE)
            else
              -- Fallback to anchor-based
              catFrame:SetPoint("RIGHT", scrollchild, "RIGHT", -S.SCROLLBAR_SPACE, 0)
            end
            
            -- Create/update message rows using shared pool
            local headerHeight = S.CATEGORY_HEADER_HEIGHT
            local maxSetting = DBB2_Config.maxMessagesPerCategory or 5
            local maxMessages
            if maxSetting == 0 then
              maxMessages = filteredCount  -- Unlimited
            else
              maxMessages = math.min(filteredCount, maxSetting)
            end
            
            -- Only show messages if not collapsed
            local visibleMessages = 0
            if not isCollapsed then
              -- Show messages (newest first)
              for i = 1, maxMessages do
                local msgIndex = filteredCount - i + 1
                local msg = filteredMessages[msgIndex]
                
                if msg then
                  local row = GetPooledRow()
                  if not row then break end
                  
                  -- Reparent row to category frame
                  row:SetParent(catFrame)
                  row:ClearAllPoints()
                  row:SetPoint("TOPLEFT", catFrame, "TOPLEFT", S.ROW_LEFT_PADDING, -(headerHeight + (i-1) * ROW_HEIGHT))
                  row:SetPoint("RIGHT", catFrame, "RIGHT", 0, 0)
                  
                  local timeStr, isOverHour = DBB2.api.FormatMessageTime(msg.time)
                  row:SetData(msg.sender, msg.message, timeStr, "|cffffffff")
                  row._msgTime = msg.time  -- Store for lightweight time updates
                  row.message:SetTextColor(0.9, 0.9, 0.9, 1)
                  -- Only set charName color if not currently hovered
                  if not row.charNameBtn or not row.charNameBtn.isHovered then
                    row.charName:SetTextColor(1, 1, 1, 1)
                  end
                  -- Red if over 1 hour in elapsed mode
                  if isOverHour then
                    row.time:SetTextColor(1, 0.3, 0.3, 1)
                  else
                    row.time:SetTextColor(0.5, 0.5, 0.5, 1)
                  end
                  row:Show()
                  visibleMessages = visibleMessages + 1
                end
              end
            end
            
            -- Set category frame height
            local catHeight
            if isCollapsed or visibleMessages == 0 then
              catHeight = headerHeight + S.CATEGORY_SPACING  -- Just header height
            else
              catHeight = headerHeight + (visibleMessages * ROW_HEIGHT) + S.CATEGORY_SPACING
            end
            catFrame:SetHeight(catHeight)
            catFrame:Show()
            
            yOffset = yOffset + catHeight + S.CATEGORY_SPACING
          end
          end  -- if passesLevelFilter
        end
      end
      
      -- Update scroll child height (includes bottom padding for extra scroll space)
      local bottomPadding = S.GUI_PADDING * 3  -- Extra scroll space
      local scrollHeight = scroll:GetHeight()
      local newChildHeight = math_max(yOffset + bottomPadding, scrollHeight)
      scrollchild:SetHeight(newChildHeight)
      scrollchild:SetWidth(scroll:GetWidth() or 1)
      -- Defer UpdateScrollState to next frame so WoW can recalculate scroll range
      scroll._needsScrollUpdate = true
    end
    
    -- Lightweight function to update only timestamps (no row rebuilding)
    panel.UpdateTimestampsOnly = function()
      for i = 1, panel.rowPoolIndex do
        local row = panel.rowPool[i]
        if row and row:IsShown() and row._msgTime then
          local timeStr, isOverHour = DBB2.api.FormatMessageTime(row._msgTime)
          row.time:SetText(timeStr)
          -- Red if over 1 hour in elapsed mode
          if isOverHour then
            row.time:SetTextColor(1, 0.3, 0.3, 1)
          else
            row.time:SetTextColor(0.5, 0.5, 0.5, 1)
          end
        end
      end
    end
    
    -- Update scroll child width on size change
    -- Track last width to avoid redundant updates
    local lastCatScrollWidth = 0
    scroll:SetScript("OnUpdate", function()
      -- Check for deferred scroll update
      if this._needsScrollUpdate then
        this._needsScrollUpdate = false
        this.UpdateScrollState()
      end
      
      -- Early exit if not visible
      if not this:IsVisible() then return end
      
      local scrollLeft = this:GetLeft()
      local scrollRight = this:GetRight()
      if not scrollLeft or not scrollRight then return end
      
      local scrollWidth = scrollRight - scrollLeft
      
      -- Only update if width actually changed
      if scrollWidth > 0 and scrollWidth ~= lastCatScrollWidth then
        lastCatScrollWidth = scrollWidth
        scrollchild:SetWidth(scrollWidth)
        -- Defer category refresh to coalesce with resize updates
        DBB2.gui._resizePending = true
      end
    end)
  end
  
  -- Create the three categorized panels
  CreateCategorizedPanel("Groups", "groups")
  CreateCategorizedPanel("Professions", "professions")
  CreateCategorizedPanel("Hardcore", "hardcore")
  
  -- Config panel content is created by modules/config.lua
  
  -- =====================
  -- INITIALIZATION
  -- =====================
  
  -- Update messages when shown
  DBB2.gui:SetScript("OnShow", function()
    -- Refresh lockout data
    if DBB2.api.RefreshLockouts then
      DBB2.api.RefreshLockouts()
    end
    -- Switch to configured default tab
    local defaultTabNames = {"Logs", "Groups", "Professions", "Hardcore"}
    local tabIndex = (DBB2_Config.defaultTab or 0) + 1  -- Convert 0-based to 1-based
    local tabName = defaultTabNames[tabIndex] or "Logs"
    DBB2.gui.tabs.SwitchTab(tabName)
    -- Defer a second update to next frame to ensure proper dimensions are calculated
    -- This fixes the issue where messages don't fill width until resize
    this._needsDeferredUpdate = true
  end)
  
  -- Handle deferred update after OnShow AND deferred resize updates
  DBB2.gui:SetScript("OnUpdate", function()
    local needsUpdate = this._needsDeferredUpdate or DBB2.gui._resizePending
    if not needsUpdate then return end
    
    this._needsDeferredUpdate = nil
    DBB2.gui._resizePending = false
    
    local activeTab = DBB2.gui.tabs.activeTab
    if activeTab == "Logs" then
      DBB2.gui:UpdateMessages()
      if DBB2.gui.scroll and DBB2.gui.scroll.UpdateScrollState then
        DBB2.gui.scroll.UpdateScrollState()
      end
    elseif activeTab == "Groups" or activeTab == "Professions" or activeTab == "Hardcore" then
      local panel = DBB2.gui.tabs.panels[activeTab]
      if panel and panel.UpdateCategories then
        panel.UpdateCategories()
      end
      if panel and panel.scroll and panel.scroll.UpdateScrollState then
        panel.scroll.UpdateScrollState()
      end
    end
  end)
  
  -- Add resize grip using schema
  local baseMinWidth = 410
  local baseMinHeight = 275
  -- Calculate scale factor directly to avoid cache issues
  local fontOffset = DBB2_Config.fontOffset or 0
  if fontOffset < -4 then fontOffset = -4 end
  if fontOffset > 4 then fontOffset = 4 end
  local scaleFactor = 1 + (fontOffset * 0.1)
  local scaledMinWidth = math.floor(baseMinWidth * scaleFactor + 0.5)
  local scaledMinHeight = math.floor(baseMinHeight * scaleFactor + 0.5)
  DBB2.gui.resizeGrip = S.CreateResizeGrip(DBB2.gui, scaledMinWidth, scaledMinHeight)
  
  -- Enforce minimum size on loaded position (in case saved size is smaller than scaled minimum)
  local minW = DBB2.gui.resizeGrip.minWidth
  local minH = DBB2.gui.resizeGrip.minHeight
  if DBB2.gui:GetWidth() < minW then
    DBB2.gui:SetWidth(minW)
  end
  if DBB2.gui:GetHeight() < minH then
    DBB2.gui:SetHeight(minH)
  end
  
  -- Update messages when window is resized (throttled to avoid client crash)
  -- The 1.12 client can ACCESS_VIOLATION if we rebuild all rows on every pixel
  -- of a drag resize, so we defer the heavy update to the next frame instead.
  DBB2.gui._resizePending = false
  DBB2.gui:SetScript("OnSizeChanged", function()
    DBB2.gui._resizePending = true
  end)
  
  -- Set default tab based on config
  local defaultTabNames = {"Logs", "Groups", "Professions", "Hardcore"}
  local tabIndex = (DBB2_Config.defaultTab or 0) + 1  -- Convert 0-based to 1-based
  local tabName = defaultTabNames[tabIndex] or "Logs"
  DBB2.gui.tabs.SwitchTab(tabName)
end)
