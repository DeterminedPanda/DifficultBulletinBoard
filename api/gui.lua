-- DBB2 UI Widgets API
-- Reusable UI components for creating consistent interfaces

-- API table is already initialized in main file
-- Tooltip API is in api/tooltip.lua

-- [ CreateScrollFrame ]
-- Creates scroll frame with automatic scrollbar
-- 'name'       [string]        frame name (optional)
-- 'parent'     [frame]         parent frame
-- return:      [frame]         the scroll frame
function DBB2.api.CreateScrollFrame(name, parent)
  local f = CreateFrame("ScrollFrame", name, parent)

  -- create slider
  local sliderWidth = DBB2:ScaleSize(7)
  f.slider = CreateFrame("Slider", nil, f)
  f.slider:SetOrientation('VERTICAL')
  f.slider:SetWidth(sliderWidth)
  f.slider:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
  f.slider:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
  
  -- CRITICAL: These are required for the slider to be draggable in WoW 1.12.1
  f.slider:EnableMouse(1)
  f.slider:SetValueStep(1)
  f.slider:SetMinMaxValues(0, 0)
  f.slider:SetValue(0)
  
  -- Set thumb texture
  f.slider:SetThumbTexture("Interface\\BUTTONS\\WHITE8X8")
  f.slider.thumb = f.slider:GetThumbTexture()
  f.slider.thumb:SetWidth(sliderWidth)
  f.slider.thumb:SetHeight(DBB2:ScaleSize(50))
  local hr, hg, hb = DBB2:GetHighlightColor()
  f.slider.thumb:SetTexture(hr, hg, hb, .5)

  f.slider:SetScript("OnValueChanged", function()
    f:SetVerticalScroll(this:GetValue())
  end)

  f.UpdateScrollState = function()
    local scrollRange = f:GetVerticalScrollRange()
    local frameHeight = f:GetHeight()
    
    -- Only update if we have valid dimensions
    if frameHeight and frameHeight > 0 then
      f.slider:SetMinMaxValues(0, scrollRange)
      f.slider:SetValue(f:GetVerticalScroll())

      local m = frameHeight + scrollRange
      local ratio = frameHeight / m

      if ratio < 1 and scrollRange > 0 then
        local size = math.floor(frameHeight * ratio)
        f.slider.thumb:SetHeight(math.max(size, DBB2:ScaleSize(20)))
        f.slider:Show()
      else
        -- Hide scrollbar when not needed
        f.slider:Hide()
      end
    end
  end

  f.Scroll = function(self, step)
    step = step or 0

    local current = f:GetVerticalScroll()
    local max = f:GetVerticalScrollRange()
    local new = current - step

    if new >= max then
      f:SetVerticalScroll(max)
    elseif new <= 0 then
      f:SetVerticalScroll(0)
    else
      f:SetVerticalScroll(new)
    end

    f.UpdateScrollState()
  end

  f:EnableMouseWheel(1)
  f:SetScript("OnMouseWheel", function()
    local scrollSpeed = DBB2_Config.scrollSpeed or 20
    f:Scroll(arg1 * scrollSpeed)
  end)

  return f
end

-- [ CreateScrollChild ]
-- Creates a scroll child frame for a scroll frame
function DBB2.api.CreateScrollChild(name, parent)
  local f = CreateFrame("Frame", name, parent)
  f:SetWidth(1)
  f:SetHeight(1)
  parent:SetScrollChild(f)
  return f
end

-- [ CreateButton ]
-- Creates a button
function DBB2.api.CreateButton(name, parent, text)
  local f = CreateFrame("Button", name, parent)
  f:SetHeight(DBB2:ScaleSize(20))
  f:SetWidth(DBB2:ScaleSize(100))
  
  DBB2:CreateBackdrop(f)
  
  f.text = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f.text:SetFont("Fonts\\FRIZQT__.TTF", DBB2:GetFontSize(11))
  f.text:SetPoint("CENTER", 0, 0)
  f.text:SetText(text or "Button")
  f.text:SetTextColor(1, 1, 1, 1)
  
  f:SetScript("OnEnter", function()
    local r, g, b = DBB2:GetHighlightColor()
    this.backdrop:SetBackdropBorderColor(r, g, b, 1)
  end)
  
  f:SetScript("OnLeave", function()
    this.backdrop:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
  end)
  
  f:SetScript("OnMouseDown", function()
    if not this:IsEnabled() then return end
    this.text:SetPoint("CENTER", 1, -1)
  end)
  
  f:SetScript("OnMouseUp", function()
    this.text:SetPoint("CENTER", 0, 0)
  end)
  
  return f
end

-- [ CreateEditBox ]
-- Creates a edit box
function DBB2.api.CreateEditBox(name, parent)
  local f = CreateFrame("EditBox", name, parent)
  f:SetHeight(DBB2:ScaleSize(20))
  f:SetAutoFocus(false)
  f:EnableMouse(true)
  f:SetTextInsets(DBB2:ScaleSize(5), DBB2:ScaleSize(5), DBB2:ScaleSize(5), DBB2:ScaleSize(5))
  f:SetFont("Fonts\\FRIZQT__.TTF", DBB2:GetFontSize(11))
  f:SetTextColor(1, 1, 1, 1)
  f:SetJustifyH("LEFT")
  
  DBB2:CreateBackdrop(f, nil, true)
  
  f:SetScript("OnEscapePressed", function()
    this:ClearFocus()
  end)
  
  f:SetScript("OnEnter", function()
    local r, g, b = DBB2:GetHighlightColor()
    this.backdrop:SetBackdropBorderColor(r, g, b, 1)
  end)
  
  f:SetScript("OnLeave", function()
    this.backdrop:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
  end)
  
  return f
end

-- [ CreateCheckBox ]
-- Creates a checkbox
-- Uses Button + checkFrame pattern for reliable rendering in scroll frames
-- 'name'       [string]        frame name (optional)
-- 'parent'     [frame]         parent frame
-- 'label'      [string]        label text (optional)
-- return:      [frame]         the checkbox frame (use .isChecked for state, .OnChecked for callback)
function DBB2.api.CreateCheckBox(name, parent, label, fontSize)
  fontSize = fontSize or 10
  local checkSize = DBB2:ScaleSize(16)
  local hr, hg, hb = DBB2:GetHighlightColor()
  
  -- Container frame for positioning
  local f = CreateFrame("Frame", name, parent)
  f:SetWidth(checkSize)
  f:SetHeight(checkSize)
  
  -- Button for click handling
  f.button = CreateFrame("Button", name and (name .. "Btn") or nil, f)
  f.button:SetAllPoints(f)
  f.button:EnableMouse(true)
  DBB2:CreateBackdrop(f.button)
  
  -- Store backdrop reference on container for compatibility
  f.backdrop = f.button.backdrop
  
  -- Check texture frame at higher level (ensures visibility in scroll frames)
  f.checkFrame = CreateFrame("Frame", nil, f.button)
  f.checkFrame:SetPoint("TOPLEFT", 3, -3)
  f.checkFrame:SetPoint("BOTTOMRIGHT", -3, 3)
  f.checkFrame:SetFrameLevel(f.button:GetFrameLevel() + 5)
  
  f.check = f.checkFrame:CreateTexture(nil, "OVERLAY")
  f.check:SetAllPoints()
  f.check:SetTexture("Interface\\BUTTONS\\WHITE8X8")
  f.check:SetVertexColor(hr, hg, hb, 1)
  f.checkFrame:Hide()
  
  -- State tracking
  f.isChecked = false
  
  -- SetChecked method for compatibility
  f.SetChecked = function(self, checked)
    self.isChecked = checked and true or false
    if self.isChecked then
      self.checkFrame:Show()
    else
      self.checkFrame:Hide()
    end
  end
  
  -- GetChecked method for compatibility
  f.GetChecked = function(self)
    return self.isChecked
  end
  
  f.button:SetScript("OnClick", function()
    local container = this:GetParent()
    container.isChecked = not container.isChecked
    if container.isChecked then
      container.checkFrame:Show()
    else
      container.checkFrame:Hide()
    end
    -- Call custom callback if defined
    if container.OnChecked then
      container.OnChecked(container.isChecked)
    end
  end)
  
  f.button:SetScript("OnEnter", function()
    local r, g, b = DBB2:GetHighlightColor()
    this.backdrop:SetBackdropBorderColor(r, g, b, 1)
  end)
  
  f.button:SetScript("OnLeave", function()
    this.backdrop:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
  end)
  
  if label then
    f.label = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.label:SetFont("Fonts\\FRIZQT__.TTF", DBB2:GetFontSize(fontSize))
    f.label:SetPoint("LEFT", f, "RIGHT", DBB2:ScaleSize(8), 0)
    f.label:SetText(label)
    f.label:SetTextColor(1, 1, 1, 1)
  end
  
  return f
end

-- [ CreateDropDown ]
-- Creates a dropdown menu
function DBB2.api.CreateDropDown(name, parent)
  local f = CreateFrame("Button", name, parent)
  f:SetHeight(DBB2:ScaleSize(20))
  f:SetWidth(DBB2:ScaleSize(150))
  
  DBB2:CreateBackdrop(f)
  
  f.text = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f.text:SetFont("Fonts\\FRIZQT__.TTF", DBB2:GetFontSize(11))
  f.text:SetPoint("LEFT", 5, 0)
  f.text:SetPoint("RIGHT", -DBB2:ScaleSize(20), 0)
  f.text:SetJustifyH("LEFT")
  f.text:SetText("Select...")
  f.text:SetTextColor(1, 1, 1, 1)
  
  f.arrow = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f.arrow:SetFont("Fonts\\FRIZQT__.TTF", DBB2:GetFontSize(11))
  f.arrow:SetPoint("RIGHT", -5, 0)
  f.arrow:SetText("v")
  local hr, hg, hb = DBB2:GetHighlightColor()
  f.arrow:SetTextColor(hr, hg, hb, 1)
  
  f:SetScript("OnEnter", function()
    local r, g, b = DBB2:GetHighlightColor()
    this.backdrop:SetBackdropBorderColor(r, g, b, 1)
  end)
  
  f:SetScript("OnLeave", function()
    this.backdrop:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
  end)
  
  return f
end

-- [ CreatePanel ]
-- Creates a panel frame
function DBB2.api.CreatePanel(name, parent)
  local f = CreateFrame("Frame", name, parent)
  DBB2:CreateBackdrop(f)
  return f
end

-- [ CreateLabel ]
-- Creates a text label
-- size parameter is the BASE size (before font offset is applied)
function DBB2.api.CreateLabel(parent, text, size)
  local f = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f:SetFont("Fonts\\FRIZQT__.TTF", DBB2:GetFontSize(size or 11))
  f:SetText(text or "")
  f:SetTextColor(1, 1, 1, 1)
  f:SetJustifyH("LEFT")
  return f
end

-- [ CreateResizeGrip ]
-- Creates a resize grip for making frames resizable
function DBB2.api.CreateResizeGrip(parent, minWidth, minHeight)
  local gripSize = DBB2:ScaleSize(13)
  local grip = CreateFrame("Frame", nil, parent)
  grip:SetWidth(gripSize)
  grip:SetHeight(gripSize)
  grip:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 2, -2)
  grip:SetFrameLevel(parent:GetFrameLevel() + 10)
  grip:EnableMouse(true)
  
  grip.minWidth = minWidth or 300
  grip.minHeight = minHeight or 200
  
  grip.texture = grip:CreateTexture(nil, "OVERLAY")
  grip.texture:SetAllPoints(grip)
  grip.texture:SetTexture("Interface\\AddOns\\DifficultBulletinBoard\\img\\sizegrabber-up")
  
  grip:SetScript("OnEnter", function()
    this.texture:SetTexture("Interface\\AddOns\\DifficultBulletinBoard\\img\\sizegrabber-highlight")
  end)
  
  grip:SetScript("OnLeave", function()
    if not this.isResizing then
      this.texture:SetTexture("Interface\\AddOns\\DifficultBulletinBoard\\img\\sizegrabber-up")
    end
  end)
  
  grip:SetScript("OnMouseDown", function()
    if arg1 == "LeftButton" then
      this.isResizing = true
      this.texture:SetTexture("Interface\\AddOns\\DifficultBulletinBoard\\img\\sizegrabber-down")
      
      local cursorX, cursorY = GetCursorPosition()
      local scale = parent:GetEffectiveScale()
      this.startX = cursorX / scale
      this.startY = cursorY / scale
      this.startWidth = parent:GetWidth()
      this.startHeight = parent:GetHeight()
      
      this:SetScript("OnUpdate", function()
        local cursorX, cursorY = GetCursorPosition()
        local scale = parent:GetEffectiveScale()
        cursorX = cursorX / scale
        cursorY = cursorY / scale
        
        local newWidth = this.startWidth + (cursorX - this.startX)
        local newHeight = this.startHeight - (cursorY - this.startY)
        
        newWidth = math.max(newWidth, this.minWidth)
        newHeight = math.max(newHeight, this.minHeight)
        
        parent:SetWidth(newWidth)
        parent:SetHeight(newHeight)
      end)
    end
  end)

  grip:SetScript("OnMouseUp", function()
    if arg1 == "LeftButton" and this.isResizing then
      this.isResizing = false
      this:SetScript("OnUpdate", nil)
      
      DBB2.api.SavePosition(parent)
      
      if MouseIsOver(this) then
        this.texture:SetTexture("Interface\\AddOns\\DifficultBulletinBoard\\img\\sizegrabber-highlight")
      else
        this.texture:SetTexture("Interface\\AddOns\\DifficultBulletinBoard\\img\\sizegrabber-up")
      end
    end
  end)
  
  return grip
end

-- [ CreateTabSystem ]
-- Creates a tab system with buttons on the left and content panels
function DBB2.api.CreateTabSystem(name, parent, tabs, buttonWidth, buttonHeight)
  local tabSystem = {}
  tabSystem.buttons = {}
  tabSystem.panels = {}
  tabSystem.activeTab = nil
  tabSystem.onTabChanged = nil
  
  -- Scale button dimensions
  buttonWidth = DBB2:ScaleSize(buttonWidth or 90)
  buttonHeight = DBB2:ScaleSize(buttonHeight or 20)
  local buttonSpacing = DBB2:ScaleSize(5)
  
  -- Function to switch tabs
  tabSystem.SwitchTab = function(tabName)
    local hr, hg, hb = DBB2:GetHighlightColor()
    
    for tname, panel in pairs(tabSystem.panels) do
      panel:Hide()
    end
    
    for tname, btn in pairs(tabSystem.buttons) do
      btn.text:SetTextColor(0.7, 0.7, 0.7, 1)
      btn.backdrop:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
    end
    
    if tabSystem.panels[tabName] then
      tabSystem.panels[tabName]:Show()
    end
    if tabSystem.buttons[tabName] then
      tabSystem.buttons[tabName].text:SetTextColor(hr, hg, hb, 1)
      tabSystem.buttons[tabName].backdrop:SetBackdropBorderColor(hr, hg, hb, 1)
    end
    
    tabSystem.activeTab = tabName
    
    if tabSystem.onTabChanged then
      tabSystem.onTabChanged(tabName)
    end
  end
  
  -- Create content area
  tabSystem.content = CreateFrame("Frame", name .. "Content", parent)
  local contentPadding = DBB2:ScaleSize(7)
  tabSystem.content:SetPoint("TOPLEFT", parent, "TOPLEFT", contentPadding, -contentPadding - buttonHeight - DBB2:ScaleSize(5))
  tabSystem.content:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -contentPadding, contentPadding)
  DBB2:CreateBackdrop(tabSystem.content)
  
  if tabSystem.content.backdrop then
    local bgColor = DBB2_Config.backgroundColor or {r = 0.08, g = 0.08, b = 0.10, a = 0.85}
    tabSystem.content.backdrop:SetBackdropColor(bgColor.r, bgColor.g, bgColor.b, bgColor.a or 0.85)
  end

  -- Create tab buttons and panels
  local tabPadding = DBB2:ScaleSize(7)
  for i, tabName in ipairs(tabs) do
    local btn = DBB2.api.CreateButton(name .. "Tab" .. tabName, parent, tabName)
    btn:SetWidth(buttonWidth)
    btn:SetHeight(buttonHeight)
    btn:SetPoint("TOPLEFT", parent, "TOPLEFT", tabPadding + (i-1) * (buttonWidth + buttonSpacing), -tabPadding)
    
    btn.tabName = tabName
    btn:SetScript("OnClick", function()
      tabSystem.SwitchTab(this.tabName)
    end)
    
    btn:SetScript("OnEnter", function()
      if tabSystem.activeTab ~= this.tabName then
        local r, g, b = DBB2:GetHighlightColor()
        this.backdrop:SetBackdropBorderColor(r, g, b, 1)
      end
    end)
    
    btn:SetScript("OnLeave", function()
      if tabSystem.activeTab ~= this.tabName then
        this.backdrop:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
      end
    end)
    
    tabSystem.buttons[tabName] = btn
    
    local panel = CreateFrame("Frame", name .. "Panel" .. tabName, tabSystem.content)
    panel:SetPoint("TOPLEFT", 2, -2)
    panel:SetPoint("BOTTOMRIGHT", -2, 2)
    panel:Hide()
    
    tabSystem.panels[tabName] = panel
  end
  
  return tabSystem
end

-- [ IsFrameInVisibleScrollArea ]
-- Helper function to check if a frame is within the visible bounds of its scroll frame
-- This prevents mouse interactions with rows that are scrolled outside the visible area
local function IsFrameInVisibleScrollArea(frame)
  if not frame then return false end
  
  local frameTop = frame:GetTop()
  local frameBottom = frame:GetBottom()
  
  -- If frame positions aren't calculated yet (first frame after show), assume visible
  -- This prevents blocking interactions on newly shown frames
  if not frameTop or not frameBottom then return true end
  
  -- Walk up the parent chain to find the scroll frame
  local parent = frame:GetParent()
  while parent do
    -- Check if this parent is a ScrollFrame by looking for scroll-related methods
    if parent.GetVerticalScroll then
      local scrollTop = parent:GetTop()
      local scrollBottom = parent:GetBottom()
      
      -- If scroll frame positions aren't ready, assume visible
      if not scrollTop or not scrollBottom then return true end
      
      -- Frame is visible if it overlaps with the scroll frame's visible area
      -- Add small tolerance (1 pixel) to avoid edge cases
      if frameBottom > scrollTop + 1 or frameTop < scrollBottom - 1 then
        return false
      end
      break
    end
    parent = parent:GetParent()
  end
  
  return true
end

-- [ CreatePlaceholderText ]
function DBB2.api.CreatePlaceholderText(parent, text)
  local f = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f:SetPoint("CENTER", 0, 0)
  f:SetFont("Fonts\\FRIZQT__.TTF", DBB2:GetFontSize(12))
  f:SetTextColor(0.5, 0.5, 0.5, 1)
  f:SetText(text or "Coming Soon")
  return f
end

-- [ CreateMessageRow ]
function DBB2.api.CreateMessageRow(name, parent, rowHeight)
  -- Scale row height based on font offset
  local baseRowHeight = rowHeight or 16
  local scaledRowHeight = DBB2:ScaleSize(baseRowHeight)
  
  local row = CreateFrame("Frame", name, parent)
  row:SetHeight(scaledRowHeight)
  
  -- Store scaled dimensions for later use
  local charNameWidth = DBB2:ScaleSize(80)
  local timeWidth = DBB2:ScaleSize(55)
  local charNameOffset = DBB2:ScaleSize(85)
  
  -- Create clickable button for character name
  row.charNameBtn = CreateFrame("Button", nil, row)
  row.charNameBtn:SetPoint("LEFT", row, "LEFT", 6, 0)
  row.charNameBtn:SetWidth(charNameWidth)
  row.charNameBtn:SetHeight(scaledRowHeight)
  row.charNameBtn:EnableMouse(true)
  row.charNameBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  row.charNameBtn:SetFrameLevel(row:GetFrameLevel() + 5)
  
  row.charName = row.charNameBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  row.charName:SetFont("Fonts\\FRIZQT__.TTF", DBB2:GetFontSize(10))
  row.charName:SetPoint("LEFT", 0, 0)
  row.charName:SetWidth(charNameWidth)
  row.charName:SetJustifyH("LEFT")
  row.charName:SetTextColor(1, 1, 1, 1)
  
  -- Store original color for restoration
  row.charNameBtn.originalR = 1
  row.charNameBtn.originalG = 1
  row.charNameBtn.originalB = 1
  row.charNameBtn.isHovered = false
  
  -- Click handlers for character name
  row.charNameBtn:SetScript("OnClick", function()
    local sender = this:GetParent()._sender
    if not sender or sender == "" or sender == "Unknown" then return end
    
    if arg1 == "LeftButton" then
      -- Left-click: whisper (shift = /who)
      if IsShiftKeyDown() then
        -- Shift+Left-click: /who
        SendWho("n-\"" .. sender .. "\"")
      else
        -- Left-click: whisper
        ChatFrameEditBox:Show()
        ChatFrameEditBox:SetFocus()
        ChatFrameEditBox:SetText("/w " .. sender .. " ")
      end
    elseif arg1 == "RightButton" then
      -- Right-click: prepare /invite in chat
      ChatFrameEditBox:Show()
      ChatFrameEditBox:SetFocus()
      ChatFrameEditBox:SetText("/invite " .. sender)
    end
  end)
  
  -- Use OnUpdate to check hover state (since OnEnter/OnLeave don't work in scroll child)
  row.charNameBtn:SetScript("OnUpdate", function()
    if not this:IsVisible() then return end
    
    -- Check if row is within visible scroll area (prevents ghost hover on scrolled-out rows)
    local isInVisibleArea = IsFrameInVisibleScrollArea(this)
    local isOver = isInVisibleArea and MouseIsOver(this)
    
    if isOver == this.isHovered then return end
    
    if isOver then
      this.isHovered = true
      local parent = this:GetParent()
      local rawName = parent._sender or "Unknown"
      local hr, hg, hb = DBB2:GetHighlightColor()
      parent.charName:SetText(rawName)
      parent.charName:SetTextColor(hr, hg, hb, 1)
      -- Dismiss any active tooltip since we're hovering the name
      if DBB2.tooltip and DBB2.tooltip:IsShown() then
        DBB2.api.DismissMessageTooltip()
      end
    else
      this.isHovered = false
      local parent = this:GetParent()
      local rawName = parent._sender or "Unknown"
      local classColor = parent._classColor or "|cffffffff"
      parent.charName:SetText(classColor .. rawName .. "|r")
      parent.charName:SetTextColor(1, 1, 1, 1)
    end
  end)
  
  row.time = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  row.time:SetFont("Fonts\\FRIZQT__.TTF", DBB2:GetFontSize(10))
  row.time:SetPoint("RIGHT", row, "RIGHT", -2, 0)
  row.time:SetWidth(timeWidth)
  row.time:SetJustifyH("LEFT")
  row.time:SetTextColor(0.5, 0.5, 0.5, 1)
  
  -- Create clickable button for message area (for tooltip on truncated messages)
  row.messageBtn = CreateFrame("Button", nil, row)
  row.messageBtn:SetPoint("LEFT", row, "LEFT", charNameOffset, 0)
  row.messageBtn:SetPoint("RIGHT", row.time, "LEFT", -5, 0)
  row.messageBtn:SetHeight(scaledRowHeight)
  row.messageBtn:EnableMouse(true)
  row.messageBtn:SetFrameLevel(row:GetFrameLevel() + 5)
  row.messageBtn.isHovered = false
  
  row.message = row.messageBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  row.message:SetFont("Fonts\\FRIZQT__.TTF", DBB2:GetFontSize(10))
  row.message:SetPoint("LEFT", 0, 0)
  row.message:SetPoint("RIGHT", 0, 0)
  row.message:SetJustifyH("LEFT")
  row.message:SetTextColor(0.9, 0.9, 0.9, 1)
  
  -- Store scaled values for SetData calculations
  row._charNameOffset = charNameOffset
  row._timeWidth = timeWidth
  
  row.SetData = function(self, sender, message, timeStr, classColor)
    -- Store sender and class color for hover restoration
    self._sender = sender or "Unknown"
    self._classColor = classColor or "|cffffffff"
    
    -- Check if button is hovered - if so, keep highlight color (no color codes)
    if self.charNameBtn and self.charNameBtn.isHovered then
      self.charName:SetText(self._sender)
      local hr, hg, hb = DBB2:GetHighlightColor()
      self.charName:SetTextColor(hr, hg, hb, 1)
    else
      self.charName:SetText(self._classColor .. self._sender .. "|r")
      self.charName:SetTextColor(1, 1, 1, 1)
    end
    
    self.time:SetText(timeStr or "")
    
    -- Store the full message for later use
    self._fullMessage = message or ""
    self._isTruncated = false
    
    -- Calculate row width from parent scroll child (more reliable than GetLeft/GetRight during resize)
    -- GetLeft/GetRight aren't updated until after layout pass, causing stale values during resize
    local rowWidth = 0
    local scrollChild = self:GetParent()
    if scrollChild and scrollChild:GetWidth() then
      -- Row width = scroll child width minus left padding (5) and right padding (scrollbar + padding = 13)
      rowWidth = scrollChild:GetWidth() - 5 - DBB2:ScaleSize(13)
    end
    
    -- Fallback to GetLeft/GetRight if scroll child width not available
    if rowWidth <= 0 then
      local rowLeft = self:GetLeft() or 0
      local rowRight = self:GetRight() or 0
      rowWidth = rowRight - rowLeft
    end
    
    local fixedLeftWidth = self._charNameOffset
    local fixedTimeWidth = self._timeWidth
    local rightPadding = 7
    local availableWidth = rowWidth - fixedLeftWidth - fixedTimeWidth - rightPadding
    
    -- Always set the message text, even if width isn't calculated yet
    if availableWidth > 0 then
      self.message:SetWidth(availableWidth)
      self.message:SetText(self._fullMessage)
      
      -- Truncate if needed
      if self.message:GetStringWidth() > availableWidth and string.len(self._fullMessage) > 3 then
        local truncated = self._fullMessage
        while self.message:GetStringWidth() > availableWidth - 15 and string.len(truncated) > 3 do
          truncated = string.sub(truncated, 1, string.len(truncated) - 1)
          self.message:SetText(truncated .. "...")
        end
        self._isTruncated = true
      end
    else
      -- Width not ready yet, just set the text without truncation
      self.message:SetText(self._fullMessage)
    end
  end
  
  row.messageBtn:SetScript("OnUpdate", function()
    if not this:IsVisible() then return end
    
    local parent = this:GetParent()
    
    -- Check if row is within visible scroll area (prevents ghost hover on scrolled-out rows)
    local isInVisibleArea = IsFrameInVisibleScrollArea(this)
    local isOver = isInVisibleArea and MouseIsOver(this)
    
    if isOver == this.isHovered then return end
    
    if isOver then
      this.isHovered = true
      
      if parent._isTruncated and parent._fullMessage and parent._fullMessage ~= "" then
        local activeData = DBB2.api.GetTooltipActiveData()
        local tooltip = DBB2.tooltip
        
        -- If tooltip is showing for a different row, dismiss it first
        if activeData and tooltip and tooltip.triggerFrame ~= this then
          DBB2.api.DismissMessageTooltip()
        end
        
        if not activeData or (tooltip and tooltip.triggerFrame ~= this) then
          DBB2.api.ShowMessageTooltip(this, parent._sender, parent._fullMessage)
        end
      end
    else
      this.isHovered = false
      
      -- Check if we should dismiss the tooltip
      if DBB2.tooltip and DBB2.tooltip:IsShown() and DBB2.tooltip.triggerFrame == this then
        if DBB2.api.ShouldDismissTooltip() then
          DBB2.api.DismissMessageTooltip()
        end
      end
    end
  end)
  
  return row
end

-- [ CreateSlider ]
function DBB2.api.CreateSlider(name, parent, label, minVal, maxVal, step, fontSize)
  step = step or 1
  fontSize = fontSize or 10
  -- Ensure step is never zero to prevent division by zero
  if step == 0 then step = 1 end
  
  local container = CreateFrame("Frame", name, parent)
  container:SetHeight(DBB2:ScaleSize(30))
  container:SetWidth(DBB2:ScaleSize(200))
  
  container.label = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  container.label:SetFont("Fonts\\FRIZQT__.TTF", DBB2:GetFontSize(fontSize))
  container.label:SetPoint("TOPLEFT", 0, 0)
  container.label:SetText(label or "Slider")
  container.label:SetTextColor(1, 1, 1, 1)
  
  container.value = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  container.value:SetFont("Fonts\\FRIZQT__.TTF", DBB2:GetFontSize(fontSize))
  container.value:SetPoint("TOPRIGHT", 0, 0)
  container.value:SetText(minVal)
  local hr, hg, hb = DBB2:GetHighlightColor()
  container.value:SetTextColor(hr, hg, hb, 1)
  
  local sliderOffset = DBB2:ScaleSize(16)
  local sliderHeight = sliderOffset
  local thumbWidth = DBB2:ScaleSize(10)
  local thumbHeight = DBB2:ScaleSize(14)
  
  -- Create the slider
  container.slider = CreateFrame("Slider", name and (name .. "Slider") or nil, container)
  container.slider:SetPoint("TOPLEFT", 0, -sliderOffset)
  container.slider:SetPoint("TOPRIGHT", 0, -sliderOffset)
  container.slider:SetHeight(sliderHeight)
  container.slider:SetOrientation("HORIZONTAL")
  container.slider:SetMinMaxValues(minVal, maxVal)
  container.slider:SetValueStep(step)
  container.slider:SetValue(minVal)
  container.slider:EnableMouse(true)
  
  DBB2:CreateBackdrop(container.slider)
  
  -- Set thumb texture (required for slider to be draggable)
  container.slider:SetThumbTexture("Interface\\BUTTONS\\WHITE8X8")
  local nativeThumb = container.slider:GetThumbTexture()
  
  if nativeThumb then
    nativeThumb:SetWidth(thumbWidth)
    nativeThumb:SetHeight(thumbHeight)
    nativeThumb:SetVertexColor(hr, hg, hb, 1)
  end
  
  -- Create visual thumb frame (higher frame level to ensure visibility)
  container.thumbFrame = CreateFrame("Frame", nil, container.slider)
  container.thumbFrame:SetWidth(thumbWidth)
  container.thumbFrame:SetHeight(thumbHeight)
  container.thumbFrame:SetFrameLevel(container.slider:GetFrameLevel() + 5)
  
  container.thumbFrame.texture = container.thumbFrame:CreateTexture(nil, "OVERLAY")
  container.thumbFrame.texture:SetAllPoints()
  container.thumbFrame.texture:SetTexture("Interface\\BUTTONS\\WHITE8X8")
  container.thumbFrame.texture:SetVertexColor(hr, hg, hb, 1)
  
  local function UpdateVisualThumb()
    local min, max = container.slider:GetMinMaxValues()
    local val = container.slider:GetValue()
    local range = max - min
    if range <= 0 then range = 1 end
    
    -- Use container width since slider width may not be reliable
    local containerWidth = container:GetWidth()
    if not containerWidth or containerWidth <= 0 then
      containerWidth = 200
    end
    
    -- Position thumb across full container width
    -- At min: left edge at 0
    -- At max: left edge at containerWidth - thumbWidth (right edge touches right border)
    local percent = (val - min) / range
    local xOffset = percent * (containerWidth - thumbWidth)
    
    container.thumbFrame:ClearAllPoints()
    container.thumbFrame:SetPoint("LEFT", container, "LEFT", xOffset, 0)
    container.thumbFrame:SetPoint("TOP", container.slider, "TOP", 0, 0)
    container.thumbFrame:SetPoint("BOTTOM", container.slider, "BOTTOM", 0, 0)
  end
  
  container.slider:SetScript("OnValueChanged", function()
    local val = this:GetValue()
    val = math.floor(val / step + 0.5) * step
    container.value:SetText(val)
    UpdateVisualThumb()
    
    if container.OnValueChanged then
      container.OnValueChanged(val)
    end
  end)
  
  container.slider:SetScript("OnEnter", function()
    local r, g, b = DBB2:GetHighlightColor()
    this.backdrop:SetBackdropBorderColor(r, g, b, 1)
  end)
  
  container.slider:SetScript("OnLeave", function()
    this.backdrop:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
  end)
  
  container:SetScript("OnShow", function()
    this._thumbInitialized = false  -- Reset on show to ensure update
    UpdateVisualThumb()
  end)
  
  -- Only update once on first render, then remove the script
  container:SetScript("OnUpdate", function()
    if this._thumbInitialized then
      -- Remove OnUpdate after initialization to stop per-frame calls
      this:SetScript("OnUpdate", nil)
      return
    end
    this._thumbInitialized = true
    UpdateVisualThumb()
    -- Remove OnUpdate after initialization
    this:SetScript("OnUpdate", nil)
  end)
  
  container.SetValue = function(self, val)
    self.slider:SetValue(val)
    self.value:SetText(val)
    UpdateVisualThumb()
  end
  
  container.GetValue = function(self)
    return self.slider:GetValue()
  end
  
  return container
end

-- [ CreateColorPicker ]
function DBB2.api.CreateColorPicker(name, parent, label, fontSize)
  fontSize = fontSize or 10
  local container = CreateFrame("Frame", name, parent)
  container:SetHeight(DBB2:ScaleSize(20))
  container:SetWidth(DBB2:ScaleSize(200))
  
  container.label = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  container.label:SetFont("Fonts\\FRIZQT__.TTF", DBB2:GetFontSize(fontSize))
  container.label:SetPoint("LEFT", 0, 0)
  container.label:SetText(label or "Color")
  container.label:SetTextColor(1, 1, 1, 1)
  
  container.button = CreateFrame("Button", name and (name .. "Button") or nil, container)
  container.button:SetWidth(DBB2:ScaleSize(50))
  container.button:SetHeight(DBB2:ScaleSize(16))
  container.button:SetPoint("RIGHT", 0, 0)
  
  DBB2:CreateBackdrop(container.button)
  
  -- Create preview frame at higher level to ensure visibility above backdrop
  container.button.previewFrame = CreateFrame("Frame", nil, container.button)
  container.button.previewFrame:SetPoint("TOPLEFT", 3, -3)
  container.button.previewFrame:SetPoint("BOTTOMRIGHT", -3, 3)
  container.button.previewFrame:SetFrameLevel(container.button:GetFrameLevel() + 5)
  
  container.button.preview = container.button.previewFrame:CreateTexture(nil, "OVERLAY")
  container.button.preview:SetAllPoints()
  container.button.preview:SetTexture("Interface\\BUTTONS\\WHITE8X8")
  container.button.preview:SetVertexColor(1, 1, 1, 1)
  
  container.r = 1
  container.g = 1
  container.b = 1
  container.a = 1
  
  container.SetColor = function(self, r, g, b, a)
    self.r = r or 1
    self.g = g or 1
    self.b = b or 1
    self.a = a or 1
    self.button.preview:SetVertexColor(self.r, self.g, self.b, self.a)
  end
  
  container.GetColor = function(self)
    return self.r, self.g, self.b, self.a
  end
  
  container.button:SetScript("OnClick", function()
    local picker = container
    local cr, cg, cb, ca = picker.r, picker.g, picker.b, picker.a
    
    ColorPickerFrame.func = function()
      local r, g, b = ColorPickerFrame:GetColorRGB()
      local a = 1 - OpacitySliderFrame:GetValue()
      
      picker.r = r
      picker.g = g
      picker.b = b
      picker.a = a
      picker.button.preview:SetVertexColor(r, g, b, a)
      
      if picker.OnColorChanged then
        picker.OnColorChanged(r, g, b, a)
      end
    end
    
    ColorPickerFrame.cancelFunc = function()
      picker.r = cr
      picker.g = cg
      picker.b = cb
      picker.a = ca
      picker.button.preview:SetVertexColor(cr, cg, cb, ca)
    end
    
    ColorPickerFrame.opacityFunc = ColorPickerFrame.func
    ColorPickerFrame.opacity = 1 - ca
    ColorPickerFrame.hasOpacity = 1
    ColorPickerFrame:SetColorRGB(cr, cg, cb)
    ColorPickerFrame:SetFrameStrata("DIALOG")
    ShowUIPanel(ColorPickerFrame)
  end)
  
  container.button:SetScript("OnEnter", function()
    local r, g, b = DBB2:GetHighlightColor()
    this.backdrop:SetBackdropBorderColor(r, g, b, 1)
  end)
  
  container.button:SetScript("OnLeave", function()
    this.backdrop:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
  end)
  
  return container
end
