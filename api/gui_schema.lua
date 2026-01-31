-- DBB2 GUI Schema
-- Unified UI component system with consistent layout constants
-- All panels (Logs, Groups, Professions, Hardcore) use the same patterns

-- Note: This file uses global string/math functions directly rather than localized versions
-- because the functions are called infrequently (UI setup, not per-frame)

-- =====================
-- LAYOUT CONSTANTS
-- =====================
-- Single source of truth for all spacing and sizing values

DBB2.schema = DBB2.schema or {}

--- Initialize layout constants for the GUI schema system.
-- Must be called after config is loaded to ensure proper scaling.
-- Sets up all spacing, sizing, and layout constants used by UI components.
-- @return nil
function DBB2.schema.InitLayout()
  local S = DBB2.schema
  
  -- Scrollbar and padding
  S.SCROLLBAR_WIDTH = DBB2:ScaleSize(7)
  S.SCROLLBAR_PADDING = DBB2:ScaleSize(6)
  S.SCROLLBAR_SPACE = S.SCROLLBAR_WIDTH + S.SCROLLBAR_PADDING  -- Total space for scrollbar
  
  -- Row layout
  S.ROW_HEIGHT = DBB2:ScaleSize(16)
  S.ROW_LEFT_PADDING = 5
  S.ROW_RIGHT_PADDING = 0  -- Row extends to container edge (container handles scrollbar space)
  
  -- Character name column
  S.CHARNAME_WIDTH = DBB2:ScaleSize(80)
  S.CHARNAME_OFFSET = DBB2:ScaleSize(85)  -- Where message starts (after charname)
  
  -- Timestamp column
  S.TIMESTAMP_WIDTH = DBB2:ScaleSize(55)
  S.TIMESTAMP_RIGHT_OFFSET = 3  -- Offset from row right edge
  S.TIMESTAMP_GAP = 5  -- Gap between message and timestamp
  
  -- Filter bar
  S.FILTER_HEIGHT = DBB2:ScaleSize(22)
  S.FILTER_PADDING = DBB2:ScaleSize(5)
  
  -- Category header (for categorized panels)
  S.CATEGORY_HEADER_HEIGHT = DBB2:ScaleSize(22)
  S.CATEGORY_SPACING = DBB2:ScaleSize(5)
  
  -- GUI frame padding
  S.GUI_PADDING = DBB2:ScaleSize(7)
  S.CONTENT_PADDING = 2
  
  -- Calculate derived values
  S.TIME_COLUMN_WIDTH = S.TIMESTAMP_WIDTH + S.SCROLLBAR_SPACE
end

-- =====================
-- SCROLL FRAME
-- =====================

--- Create a scrollable frame with a vertical scrollbar.
-- The scroll frame includes mouse wheel support and automatic thumb sizing.
-- @param name (string) Unique name for the scroll frame
-- @param parent (Frame) Parent frame to attach the scroll frame to
-- @return (ScrollFrame) The created scroll frame with the following methods:
--   - GetCalculatedScrollRange(): Returns the calculated scroll range
--   - UpdateScrollState(): Updates scrollbar visibility and thumb size
--   - Scroll(step): Scrolls by the specified amount
function DBB2.schema.CreateScrollFrame(name, parent)
  local S = DBB2.schema
  local f = CreateFrame("ScrollFrame", name, parent)

  -- Create slider
  f.slider = CreateFrame("Slider", nil, f)
  f.slider:SetOrientation('VERTICAL')
  f.slider:SetWidth(S.SCROLLBAR_WIDTH)
  f.slider:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -1)
  f.slider:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 1)
  
  -- Required for draggable slider in WoW 1.12.1
  f.slider:EnableMouse(1)
  f.slider:SetValueStep(1)
  f.slider:SetMinMaxValues(0, 0)
  f.slider:SetValue(0)
  
  -- Thumb texture
  f.slider:SetThumbTexture("Interface\\BUTTONS\\WHITE8X8")
  f.slider.thumb = f.slider:GetThumbTexture()
  f.slider.thumb:SetWidth(S.SCROLLBAR_WIDTH)
  f.slider.thumb:SetHeight(DBB2:ScaleSize(50))
  local hr, hg, hb = DBB2:GetHighlightColor()
  f.slider.thumb:SetTexture(hr, hg, hb, 0.5)

  f.slider:SetScript("OnValueChanged", function()
    f:SetVerticalScroll(this:GetValue())
  end)
  
  -- Calculate scroll range from scroll child
  f.GetCalculatedScrollRange = function()
    local frameHeight = f:GetHeight() or 0
    local calcRange = 0
    if f.scrollChild and frameHeight > 0 then
      local childHeight = f.scrollChild:GetHeight() or 0
      calcRange = math.max(0, childHeight - frameHeight)
    end
    return calcRange
  end

  f.UpdateScrollState = function()
    local frameHeight = f:GetHeight()
    if frameHeight and frameHeight > 0 then
      local scrollRange = f.GetCalculatedScrollRange()
      f.slider:SetMinMaxValues(0, scrollRange)
      f.slider:SetValue(f:GetVerticalScroll())

      if scrollRange <= 1 then
        f.slider:Hide()
      else
        local m = frameHeight + scrollRange
        local ratio = frameHeight / m
        local size = math.floor(frameHeight * ratio)
        f.slider.thumb:SetHeight(math.max(size, DBB2:ScaleSize(20)))
        f.slider:Show()
      end
    end
  end

  f.Scroll = function(self, step)
    step = step or 0
    local current = f:GetVerticalScroll()
    local max = f.GetCalculatedScrollRange()
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
  
  f._needsScrollUpdate = false
  f:SetScript("OnUpdate", function()
    if this._needsScrollUpdate then
      this._needsScrollUpdate = false
      this.UpdateScrollState()
    end
  end)

  return f
end

-- =====================
-- SCROLL CHILD
-- =====================

--- Create a scroll child frame to hold scrollable content.
-- The scroll child is automatically attached to the parent scroll frame.
-- @param name (string) Unique name for the scroll child frame
-- @param parent (ScrollFrame) Parent scroll frame created by CreateScrollFrame
-- @return (Frame) The created scroll child frame
function DBB2.schema.CreateScrollChild(name, parent)
  local f = CreateFrame("Frame", name, parent)
  f:SetWidth(1)
  f:SetHeight(1)
  parent:SetScrollChild(f)
  parent.scrollChild = f
  return f
end

-- =====================
-- MESSAGE CONTAINER
-- =====================

--- Create a container frame for message rows.
-- Used by both Logs and categorized panels (Groups, Professions, Hardcore).
-- Handles scrollbar space consistently by adjusting container width.
-- @param name (string) Unique name for the container frame
-- @param parent (Frame) Parent frame to attach the container to
-- @param scrollFrame (ScrollFrame) Associated scroll frame for width calculations
-- @return (Frame) The created container frame with the following methods:
--   - UpdateWidth(): Updates container width based on scroll frame dimensions
function DBB2.schema.CreateMessageContainer(name, parent, scrollFrame)
  local S = DBB2.schema
  local f = CreateFrame("Frame", name, parent)
  
  -- Container width = scroll frame width - scrollbar space
  -- This is set dynamically in UpdateContainerWidth
  f.scrollFrame = scrollFrame
  
  f.UpdateWidth = function(self)
    local sfLeft = self.scrollFrame:GetLeft()
    local sfRight = self.scrollFrame:GetRight()
    if sfLeft and sfRight and sfRight > sfLeft then
      self:SetWidth(sfRight - sfLeft - S.SCROLLBAR_SPACE)
      return true
    end
    return false
  end
  
  return f
end

-- =====================
-- MESSAGE ROW
-- =====================

--- Create a message row for displaying chat messages.
-- Each row contains a clickable character name, message text, and timestamp.
-- Supports truncation with tooltip for long messages.
-- @param name (string) Unique name for the row frame
-- @param parent (Frame) Parent frame to attach the row to
-- @return (Frame) The created message row with the following methods:
--   - SetData(sender, message, timeStr, classColor): Sets the row data
-- @usage
--   local row = DBB2.schema.CreateMessageRow("MyRow", parent)
--   row:SetData("PlayerName", "Looking for group!", "12:34", "|cff00ff00")
function DBB2.schema.CreateMessageRow(name, parent)
  local S = DBB2.schema
  
  local row = CreateFrame("Frame", name, parent)
  row:SetHeight(S.ROW_HEIGHT)
  
  -- Character name button (clickable)
  row.charNameBtn = CreateFrame("Button", nil, row)
  row.charNameBtn:SetPoint("LEFT", row, "LEFT", 6, 0)
  row.charNameBtn:SetWidth(S.CHARNAME_WIDTH)
  row.charNameBtn:SetHeight(S.ROW_HEIGHT)
  row.charNameBtn:EnableMouse(true)
  row.charNameBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  row.charNameBtn:SetFrameLevel(row:GetFrameLevel() + 5)
  
  row.charName = row.charNameBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  row.charName:SetFont("Fonts\\FRIZQT__.TTF", DBB2:GetFontSize(10))
  row.charName:SetPoint("LEFT", 0, 0)
  row.charName:SetWidth(S.CHARNAME_WIDTH)
  row.charName:SetJustifyH("LEFT")
  row.charName:SetTextColor(1, 1, 1, 1)
  
  row.charNameBtn.isHovered = false
  
  -- Character name click handlers
  row.charNameBtn:SetScript("OnClick", function()
    local sender = this:GetParent()._sender
    if not sender or sender == "" or sender == "Unknown" then return end
    
    if arg1 == "LeftButton" then
      if IsShiftKeyDown() then
        SendWho("n-\"" .. sender .. "\"")
      else
        ChatFrameEditBox:Show()
        ChatFrameEditBox:SetFocus()
        ChatFrameEditBox:SetText("/w " .. sender .. " ")
      end
    elseif arg1 == "RightButton" then
      ChatFrameEditBox:Show()
      ChatFrameEditBox:SetFocus()
      ChatFrameEditBox:SetText("/invite " .. sender)
    end
  end)
  
  -- Timestamp
  row.time = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  row.time:SetFont("Fonts\\FRIZQT__.TTF", DBB2:GetFontSize(10))
  row.time:SetPoint("RIGHT", row, "RIGHT", S.TIMESTAMP_RIGHT_OFFSET, 0)
  row.time:SetWidth(S.TIMESTAMP_WIDTH)
  row.time:SetJustifyH("LEFT")
  row.time:SetTextColor(0.5, 0.5, 0.5, 1)
  
  -- Message button (for tooltip on truncated messages)
  row.messageBtn = CreateFrame("Button", nil, row)
  row.messageBtn:SetPoint("LEFT", row, "LEFT", S.CHARNAME_OFFSET, 0)
  row.messageBtn:SetPoint("RIGHT", row.time, "LEFT", -S.TIMESTAMP_GAP, 0)
  row.messageBtn:SetHeight(S.ROW_HEIGHT)
  row.messageBtn:EnableMouse(true)
  row.messageBtn:SetFrameLevel(row:GetFrameLevel() + 5)
  row.messageBtn.isHovered = false
  
  row.message = row.messageBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  row.message:SetFont("Fonts\\FRIZQT__.TTF", DBB2:GetFontSize(10))
  row.message:SetPoint("LEFT", 0, 0)
  row.message:SetPoint("RIGHT", 0, 0)
  row.message:SetJustifyH("LEFT")
  row.message:SetTextColor(0.9, 0.9, 0.9, 1)
  
  -- SetData function
  row.SetData = function(self, sender, message, timeStr, classColor)
    self._sender = sender or "Unknown"
    self._classColor = classColor or "|cffffffff"
    self._fullMessage = message or ""
    self._isTruncated = false
    
    -- Set character name
    if self.charNameBtn and self.charNameBtn.isHovered then
      self.charName:SetText(self._sender)
      local hr, hg, hb = DBB2:GetHighlightColor()
      self.charName:SetTextColor(hr, hg, hb, 1)
    else
      self.charName:SetText(self._classColor .. self._sender .. "|r")
      self.charName:SetTextColor(1, 1, 1, 1)
    end
    
    self.time:SetText(timeStr or "")
    
    -- Calculate available width from GUI
    local availableWidth = 0
    if DBB2.gui then
      local guiWidth = DBB2.gui:GetWidth()
      if guiWidth and guiWidth > 0 then
        local scrollWidth = guiWidth - (S.GUI_PADDING * 2) - (S.CONTENT_PADDING * 2)
        local rowWidth = scrollWidth - S.ROW_LEFT_PADDING - S.SCROLLBAR_SPACE
        availableWidth = rowWidth - S.CHARNAME_OFFSET - S.TIMESTAMP_WIDTH - S.TIMESTAMP_RIGHT_OFFSET - S.TIMESTAMP_GAP
      end
    end
    
    -- Set message text and truncate if needed
    if availableWidth > 20 then
      self.message:SetWidth(availableWidth)
      self.message:SetText(self._fullMessage)
      
      if self.message:GetStringWidth() > availableWidth and string.len(self._fullMessage) > 3 then
        local truncated = self._fullMessage
        while self.message:GetStringWidth() > availableWidth - 15 and string.len(truncated) > 3 do
          truncated = string.sub(truncated, 1, string.len(truncated) - 1)
          self.message:SetText(truncated .. "...")
        end
        self._isTruncated = true
      end
      self._needsWidthRecalc = false
    else
      self.message:SetText(self._fullMessage)
      self._needsWidthRecalc = true
    end
  end
  
  -- Helper: Check if row is visible within scroll frame viewport
  local function IsRowVisibleInScrollFrame(rowFrame)
    -- Walk up to find the scroll frame
    local scrollFrame = nil
    local current = rowFrame:GetParent()
    while current do
      -- Check if parent is a scroll child (has a scroll frame parent)
      local grandparent = current:GetParent()
      if grandparent and grandparent.GetVerticalScroll then
        scrollFrame = grandparent
        break
      end
      current = grandparent
    end
    
    if not scrollFrame then return true end  -- No scroll frame found, assume visible
    
    -- Get scroll frame bounds
    local sfTop = scrollFrame:GetTop()
    local sfBottom = scrollFrame:GetBottom()
    if not sfTop or not sfBottom then return true end
    
    -- Get row bounds
    local rowTop = rowFrame:GetTop()
    local rowBottom = rowFrame:GetBottom()
    if not rowTop or not rowBottom then return false end
    
    -- Row must be fully within viewport (not just overlapping)
    -- This prevents tooltips when row is partially scrolled out of view
    if rowTop > sfTop or rowBottom < sfBottom then
      return false
    end
    
    return true
  end
  
  -- Hover handlers for character name
  row.charNameBtn:SetScript("OnUpdate", function()
    if not this:IsVisible() then return end
    
    local parent = this:GetParent()
    
    -- Check if row is actually visible in scroll viewport
    local isVisibleInViewport = IsRowVisibleInScrollFrame(parent)
    local isOver = MouseIsOver(this) and isVisibleInViewport
    
    if isOver == this.isHovered then return end
    
    if isOver then
      this.isHovered = true
      local hr, hg, hb = DBB2:GetHighlightColor()
      parent.charName:SetText(parent._sender or "Unknown")
      parent.charName:SetTextColor(hr, hg, hb, 1)
      if DBB2.tooltip and DBB2.tooltip:IsShown() then
        DBB2.api.DismissMessageTooltip()
      end
    else
      this.isHovered = false
      local classColor = parent._classColor or "|cffffffff"
      parent.charName:SetText(classColor .. (parent._sender or "Unknown") .. "|r")
      parent.charName:SetTextColor(1, 1, 1, 1)
    end
  end)
  
  -- Hover handlers for message (tooltip)
  row.messageBtn:SetScript("OnUpdate", function()
    if not this:IsVisible() then return end
    
    local parent = this:GetParent()
    
    -- Check if row is actually visible in scroll viewport
    local isVisibleInViewport = IsRowVisibleInScrollFrame(parent)
    local isOver = MouseIsOver(this) and isVisibleInViewport
    
    if isOver == this.isHovered then return end
    
    if isOver then
      this.isHovered = true
      if parent._isTruncated and parent._fullMessage and parent._fullMessage ~= "" then
        if DBB2.api.ShowMessageTooltip then
          DBB2.api.ShowMessageTooltip(this, parent._sender, parent._fullMessage)
        end
      end
    else
      this.isHovered = false
      if DBB2.tooltip and DBB2.tooltip:IsShown() and DBB2.tooltip.triggerFrame == this then
        if DBB2.api.ShouldDismissTooltip and DBB2.api.ShouldDismissTooltip() then
          DBB2.api.DismissMessageTooltip()
        end
      end
    end
  end)
  
  -- OnUpdate for deferred width recalculation
  row:SetScript("OnUpdate", function()
    if not this._needsWidthRecalc then return end
    if not this:IsVisible() then return end
    
    local availableWidth = 0
    if DBB2.gui then
      local guiWidth = DBB2.gui:GetWidth()
      if guiWidth and guiWidth > 0 then
        local scrollWidth = guiWidth - (S.GUI_PADDING * 2) - (S.CONTENT_PADDING * 2)
        local rowWidth = scrollWidth - S.ROW_LEFT_PADDING - S.SCROLLBAR_SPACE
        availableWidth = rowWidth - S.CHARNAME_OFFSET - S.TIMESTAMP_WIDTH - S.TIMESTAMP_RIGHT_OFFSET - S.TIMESTAMP_GAP
      end
    end
    
    if availableWidth > 20 then
      this._needsWidthRecalc = false
      this.message:SetWidth(availableWidth)
      this.message:SetText(this._fullMessage)
      
      if this.message:GetStringWidth() > availableWidth and string.len(this._fullMessage) > 3 then
        local truncated = this._fullMessage
        while this.message:GetStringWidth() > availableWidth - 15 and string.len(truncated) > 3 do
          truncated = string.sub(truncated, 1, string.len(truncated) - 1)
          this.message:SetText(truncated .. "...")
        end
        this._isTruncated = true
      end
    end
  end)
  
  return row
end


-- =====================
-- FILTER INPUT
-- =====================

--- Create a filter input field for filtering messages.
-- Includes placeholder text and visual feedback on focus/hover.
-- @param name (string) Unique name for the edit box
-- @param parent (Frame) Parent frame to attach the input to
-- @return (EditBox) The created filter input with placeholder text support
function DBB2.schema.CreateFilterInput(name, parent)
  local S = DBB2.schema
  
  local f = CreateFrame("EditBox", name, parent)
  f:SetHeight(S.FILTER_HEIGHT)
  f:SetAutoFocus(false)
  f:EnableMouse(true)
  f:SetTextInsets(DBB2:ScaleSize(5), DBB2:ScaleSize(5), DBB2:ScaleSize(5), DBB2:ScaleSize(5))
  f:SetFont("Fonts\\FRIZQT__.TTF", DBB2:GetFontSize(10))
  f:SetJustifyH("LEFT")
  
  DBB2:CreateBackdrop(f, nil, nil, nil, true)
  
  -- Hide full border, we'll add bottom-only
  if f.backdrop then
    f.backdrop:SetBackdropBorderColor(0, 0, 0, 0)
    f.backdrop:SetBackdropColor(0, 0, 0, 0)
  end
  
  -- Bottom border line
  f.bottomBorder = parent:CreateTexture(nil, "BORDER")
  f.bottomBorder:SetTexture("Interface\\BUTTONS\\WHITE8X8")
  f.bottomBorder:SetHeight(1)
  f.bottomBorder:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
  f.bottomBorder:SetPoint("BOTTOMRIGHT", parent, "TOPRIGHT", 0, -S.FILTER_HEIGHT)
  f.bottomBorder:SetVertexColor(0.25, 0.25, 0.25, 1)
  
  -- Placeholder text
  f.placeholder = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f.placeholder:SetFont("Fonts\\FRIZQT__.TTF", DBB2:GetFontSize(10))
  f.placeholder:SetPoint("LEFT", 6, 0)
  f.placeholder:SetText("Filter messages... (e.g. bwl,zg,mc)")
  f.placeholder:SetTextColor(0.4, 0.4, 0.4, 1)
  
  f:SetScript("OnEscapePressed", function()
    this:ClearFocus()
  end)
  
  f:SetScript("OnEnterPressed", function()
    this:ClearFocus()
  end)
  
  f:SetScript("OnEditFocusGained", function()
    this.placeholder:Hide()
  end)
  
  f:SetScript("OnEditFocusLost", function()
    if this:GetText() == "" then
      this.placeholder:Show()
    end
  end)
  
  f:SetScript("OnEnter", function()
    local r, g, b = DBB2:GetHighlightColor()
    this.bottomBorder:SetVertexColor(r, g, b, 1)
  end)
  
  f:SetScript("OnLeave", function()
    this.bottomBorder:SetVertexColor(0.25, 0.25, 0.25, 1)
  end)
  
  return f
end

-- =====================
-- CURRENT TIME DISPLAY
-- =====================

--- Create a font string for displaying the current time.
-- Used in the filter bar area to show real-time clock.
-- @param parent (Frame) Parent frame to attach the font string to
-- @return (FontString) The created time display font string
function DBB2.schema.CreateCurrentTimeDisplay(parent)
  local S = DBB2.schema
  
  local f = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f:SetFont("Fonts\\FRIZQT__.TTF", DBB2:GetFontSize(10))
  f:SetJustifyH("LEFT")
  f:SetTextColor(0.5, 0.5, 0.5, 1)
  f:SetText(date("%H:%M:%S"))
  f:SetWidth(S.TIMESTAMP_WIDTH)
  
  return f
end

-- =====================
-- BUTTON
-- =====================

--- Create a styled button with hover effects.
-- Includes backdrop, text label, and press animation.
-- @param name (string) Unique name for the button
-- @param parent (Frame) Parent frame to attach the button to
-- @param text (string|nil) Button label text (default: "Button")
-- @return (Button) The created button with text property
function DBB2.schema.CreateButton(name, parent, text)
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

-- =====================
-- CHECKBOX
-- =====================

--- Create a checkbox with optional label.
-- Includes visual check indicator and hover effects.
-- @param name (string|nil) Unique name for the checkbox (optional)
-- @param parent (Frame) Parent frame to attach the checkbox to
-- @param label (string|nil) Text label displayed next to the checkbox
-- @param fontSize (number|nil) Font size for the label (default: 10)
-- @return (Frame) The created checkbox with the following methods:
--   - SetChecked(checked): Sets the checked state
--   - GetChecked(): Returns the current checked state (boolean)
--   - Enable(): Enables the checkbox
--   - Disable(): Disables the checkbox
--   - OnChecked: Callback function called when state changes
function DBB2.schema.CreateCheckBox(name, parent, label, fontSize)
  fontSize = fontSize or 10
  local checkSize = DBB2:ScaleSize(16)
  local hr, hg, hb = DBB2:GetHighlightColor()
  
  local f = CreateFrame("Frame", name, parent)
  f:SetWidth(checkSize)
  f:SetHeight(checkSize)
  
  f.button = CreateFrame("Button", name and (name .. "Btn") or nil, f)
  f.button:SetAllPoints(f)
  f.button:EnableMouse(true)
  DBB2:CreateBackdrop(f.button)
  
  f.backdrop = f.button.backdrop
  
  f.checkFrame = CreateFrame("Frame", nil, f.button)
  f.checkFrame:SetPoint("TOPLEFT", 3, -3)
  f.checkFrame:SetPoint("BOTTOMRIGHT", -3, 3)
  f.checkFrame:SetFrameLevel(f.button:GetFrameLevel() + 5)
  
  f.check = f.checkFrame:CreateTexture(nil, "OVERLAY")
  f.check:SetAllPoints()
  f.check:SetTexture("Interface\\BUTTONS\\WHITE8X8")
  f.check:SetVertexColor(hr, hg, hb, 1)
  f.checkFrame:Hide()
  
  f.isChecked = false
  
  f.SetChecked = function(self, checked)
    self.isChecked = checked and true or false
    if self.isChecked then
      self.checkFrame:Show()
    else
      self.checkFrame:Hide()
    end
  end
  
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
  
  f.Disable = function(self)
    self.isDisabled = true
    self.button:EnableMouse(false)
    self.check:SetVertexColor(0.5, 0.5, 0.5, 1)
    if self.backdrop then
      self.backdrop:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
    end
    if self.label then
      self.label:SetTextColor(0.5, 0.5, 0.5, 1)
    end
  end
  
  f.Enable = function(self)
    self.isDisabled = false
    self.button:EnableMouse(true)
    local r, g, b = DBB2:GetHighlightColor()
    self.check:SetVertexColor(r, g, b, 1)
    if self.backdrop then
      self.backdrop:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    end
    if self.label then
      self.label:SetTextColor(1, 1, 1, 1)
    end
  end
  
  return f
end

-- =====================
-- EDIT BOX
-- =====================

--- Create a styled text input field.
-- Includes backdrop and hover effects.
-- @param name (string) Unique name for the edit box
-- @param parent (Frame) Parent frame to attach the edit box to
-- @return (EditBox) The created edit box with backdrop
function DBB2.schema.CreateEditBox(name, parent)
  local f = CreateFrame("EditBox", name, parent)
  f:SetHeight(DBB2:ScaleSize(20))
  f:SetAutoFocus(false)
  f:EnableMouse(true)
  f:SetTextInsets(DBB2:ScaleSize(5), DBB2:ScaleSize(5), DBB2:ScaleSize(5), DBB2:ScaleSize(5))
  f:SetFont("Fonts\\FRIZQT__.TTF", DBB2:GetFontSize(10))
  f:SetJustifyH("LEFT")
  
  DBB2:CreateBackdrop(f, nil, nil, nil, true)
  
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

-- =====================
-- DROPDOWN
-- =====================

--- Create a dropdown button for selection menus.
-- Displays selected text with a dropdown arrow indicator.
-- @param name (string) Unique name for the dropdown button
-- @param parent (Frame) Parent frame to attach the dropdown to
-- @return (Button) The created dropdown button with text and arrow properties
function DBB2.schema.CreateDropDown(name, parent)
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

-- =====================
-- LABEL
-- =====================

--- Create a simple text label.
-- @param parent (Frame) Parent frame to attach the label to
-- @param text (string|nil) Label text content
-- @param size (number|nil) Font size (default: 11)
-- @return (FontString) The created label font string
function DBB2.schema.CreateLabel(parent, text, size)
  local f = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f:SetFont("Fonts\\FRIZQT__.TTF", DBB2:GetFontSize(size or 11))
  f:SetText(text or "")
  f:SetTextColor(1, 1, 1, 1)
  f:SetJustifyH("LEFT")
  return f
end

-- =====================
-- SLIDER
-- =====================

--- Create a horizontal slider with label and value display.
-- Includes track background and draggable thumb.
-- @param name (string|nil) Unique name for the slider container
-- @param parent (Frame) Parent frame to attach the slider to
-- @param label (string|nil) Label text displayed above the slider
-- @param minVal (number) Minimum slider value
-- @param maxVal (number) Maximum slider value
-- @param step (number|nil) Value step increment (default: 1)
-- @param fontSize (number|nil) Font size for label and value (default: 10)
-- @return (Frame) The created slider container with the following methods:
--   - SetValue(val): Sets the slider value
--   - GetValue(): Returns the current slider value (number)
--   - OnValueChanged: Callback function called when value changes
function DBB2.schema.CreateSlider(name, parent, label, minVal, maxVal, step, fontSize)
  step = step or 1
  fontSize = fontSize or 10
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
  
  container.slider = CreateFrame("Slider", name and (name .. "Slider") or nil, container)
  container.slider:SetPoint("TOPLEFT", 0, -sliderOffset)
  container.slider:SetPoint("TOPRIGHT", 0, -sliderOffset)
  container.slider:SetHeight(sliderHeight)
  container.slider:SetOrientation("HORIZONTAL")
  container.slider:SetMinMaxValues(minVal, maxVal)
  container.slider:SetValueStep(step)
  container.slider:SetValue(minVal)
  container.slider:EnableMouse(true)
  
  -- Track background
  container.track = container:CreateTexture(nil, "BACKGROUND")
  container.track:SetTexture("Interface\\BUTTONS\\WHITE8X8")
  container.track:SetVertexColor(0.2, 0.2, 0.2, 1)
  container.track:SetPoint("TOPLEFT", container.slider, "TOPLEFT", 0, -sliderHeight/2 + 2)
  container.track:SetPoint("BOTTOMRIGHT", container.slider, "BOTTOMRIGHT", 0, sliderHeight/2 - 2)
  
  -- Thumb
  container.slider:SetThumbTexture("Interface\\BUTTONS\\WHITE8X8")
  local thumb = container.slider:GetThumbTexture()
  thumb:SetWidth(DBB2:ScaleSize(10))
  thumb:SetHeight(DBB2:ScaleSize(14))
  thumb:SetVertexColor(hr, hg, hb, 1)
  
  container.slider:SetScript("OnValueChanged", function()
    local val = math.floor(this:GetValue() + 0.5)
    container.value:SetText(val)
    if container.OnValueChanged then
      container.OnValueChanged(val)
    end
  end)
  
  container.SetValue = function(self, val)
    self.slider:SetValue(val)
  end
  
  container.GetValue = function(self)
    return math.floor(self.slider:GetValue() + 0.5)
  end
  
  return container
end

-- =====================
-- RESIZE GRIP
-- =====================

--- Create a resize grip for resizable frames.
-- Allows users to drag the corner to resize the parent frame.
-- Automatically saves position after resize via DBB2.api.SavePosition.
-- @param parent (Frame) Parent frame that will be resizable
-- @param minWidth (number|nil) Minimum allowed width (default: 300)
-- @param minHeight (number|nil) Minimum allowed height (default: 200)
-- @return (Frame) The created resize grip frame
function DBB2.schema.CreateResizeGrip(parent, minWidth, minHeight)
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

-- =====================
-- TAB SYSTEM
-- =====================

--- Create a tabbed interface with multiple panels.
-- Each tab has a button and associated content panel.
-- @param name (string) Base name for tab system components
-- @param parent (Frame) Parent frame to attach the tab system to
-- @param tabs (table) Array of tab names (e.g., {"Logs", "Groups", "Config"})
-- @param buttonWidth (number|nil) Width of tab buttons (default: 90)
-- @param buttonHeight (number|nil) Height of tab buttons (default: 20)
-- @return (table) Tab system object with the following properties:
--   - buttons: Table of tab buttons keyed by tab name
--   - panels: Table of content panels keyed by tab name
--   - content: The main content container frame
--   - activeTab: Currently active tab name
--   - SwitchTab(tabName): Switches to the specified tab
--   - onTabChanged: Callback function called when tab changes
function DBB2.schema.CreateTabSystem(name, parent, tabs, buttonWidth, buttonHeight)
  local S = DBB2.schema
  local tabSystem = {}
  tabSystem.buttons = {}
  tabSystem.panels = {}
  tabSystem.activeTab = nil
  tabSystem.onTabChanged = nil
  
  buttonWidth = DBB2:ScaleSize(buttonWidth or 90)
  buttonHeight = DBB2:ScaleSize(buttonHeight or 20)
  local buttonSpacing = DBB2:ScaleSize(5)
  
  -- Switch tab function
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
  
  -- Content area
  tabSystem.content = CreateFrame("Frame", name .. "Content", parent)
  tabSystem.content:SetPoint("TOPLEFT", parent, "TOPLEFT", S.GUI_PADDING, -S.GUI_PADDING - buttonHeight - DBB2:ScaleSize(5))
  tabSystem.content:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -S.GUI_PADDING, S.GUI_PADDING)
  DBB2:CreateBackdrop(tabSystem.content)
  
  if tabSystem.content.backdrop then
    local bgColor = DBB2_Config.backgroundColor or {r = 0.08, g = 0.08, b = 0.10, a = 0.85}
    tabSystem.content.backdrop:SetBackdropColor(bgColor.r, bgColor.g, bgColor.b, bgColor.a or 0.85)
  end

  -- Create tab buttons and panels
  for i, tabName in ipairs(tabs) do
    local btn = DBB2.schema.CreateButton(name .. "Tab" .. tabName, parent, tabName)
    btn:SetWidth(buttonWidth)
    btn:SetHeight(buttonHeight)
    btn:SetPoint("TOPLEFT", parent, "TOPLEFT", S.GUI_PADDING + (i-1) * (buttonWidth + buttonSpacing), -S.GUI_PADDING)
    
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
    panel:SetPoint("TOPLEFT", S.CONTENT_PADDING, -S.CONTENT_PADDING)
    panel:SetPoint("BOTTOMRIGHT", -S.CONTENT_PADDING, S.CONTENT_PADDING)
    panel:Hide()
    
    panel.scrollFrame = nil
    
    panel:SetScript("OnShow", function()
      this._updateScrollPending = true
      if this.scrollFrame then
        this.scrollFrame._needsScrollUpdate = true
      end
    end)
    
    panel:SetScript("OnUpdate", function()
      if this._updateScrollPending then
        this._updateScrollPending = nil
        if this.scrollFrame and this.scrollFrame.UpdateScrollState then
          this.scrollFrame.UpdateScrollState()
        end
      end
      if this._needsContentUpdate then
        this._needsContentUpdate = nil
        local updateType = this._contentUpdateType
        this._contentUpdateType = nil
        if updateType == "Logs" then
          if DBB2.gui and DBB2.gui.UpdateMessages then
            DBB2.gui:UpdateMessages()
          end
        elseif updateType == "Groups" or updateType == "Professions" or updateType == "Hardcore" then
          if this.UpdateCategories then
            this.UpdateCategories()
          end
        end
      end
    end)
    
    tabSystem.panels[tabName] = panel
  end
  
  return tabSystem
end


-- =====================
-- STATIC SCROLL FRAME
-- =====================

--- Create a static scroll frame for config panels.
-- Simpler than the dynamic scroll frame, optimized for static content.
-- @param name (string) Unique name for the scroll frame
-- @param parent (Frame) Parent frame to attach the scroll frame to
-- @return (ScrollFrame) The created scroll frame with the following methods:
--   - GetScrollRange(): Returns the calculated scroll range
--   - UpdateScrollState(): Updates scrollbar visibility and thumb size
--   - Scroll(step): Scrolls by the specified amount
function DBB2.schema.CreateStaticScrollFrame(name, parent)
  local S = DBB2.schema
  local f = CreateFrame("ScrollFrame", name, parent)

  -- Create slider
  f.slider = CreateFrame("Slider", nil, f)
  f.slider:SetOrientation('VERTICAL')
  f.slider:SetWidth(S.SCROLLBAR_WIDTH or DBB2:ScaleSize(7))
  f.slider:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -1)
  f.slider:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 1)
  
  f.slider:EnableMouse(1)
  f.slider:SetValueStep(1)
  f.slider:SetMinMaxValues(0, 0)
  f.slider:SetValue(0)
  
  f.slider:SetThumbTexture("Interface\\BUTTONS\\WHITE8X8")
  f.slider.thumb = f.slider:GetThumbTexture()
  f.slider.thumb:SetWidth(S.SCROLLBAR_WIDTH or DBB2:ScaleSize(7))
  f.slider.thumb:SetHeight(DBB2:ScaleSize(50))
  local hr, hg, hb = DBB2:GetHighlightColor()
  f.slider.thumb:SetTexture(hr, hg, hb, 0.5)

  f.slider:SetScript("OnValueChanged", function()
    f:SetVerticalScroll(this:GetValue())
  end)

  f.GetScrollRange = function()
    local frameHeight = f:GetHeight() or 0
    if f.scrollChild and frameHeight > 0 then
      local childHeight = f.scrollChild:GetHeight() or 0
      return math.max(0, childHeight - frameHeight)
    end
    return 0
  end

  f.UpdateScrollState = function()
    local frameHeight = f:GetHeight()
    if frameHeight and frameHeight > 0 then
      local scrollRange = f.GetScrollRange()
      f.slider:SetMinMaxValues(0, scrollRange)
      
      local currentScroll = f:GetVerticalScroll()
      if currentScroll > scrollRange then
        f:SetVerticalScroll(scrollRange)
        f.slider:SetValue(scrollRange)
      else
        f.slider:SetValue(currentScroll)
      end

      if scrollRange <= 1 then
        f.slider:Hide()
      else
        local m = frameHeight + scrollRange
        local ratio = frameHeight / m
        local size = math.floor(frameHeight * ratio)
        f.slider.thumb:SetHeight(math.max(size, DBB2:ScaleSize(20)))
        f.slider:Show()
      end
    end
  end

  f.Scroll = function(self, step)
    step = step or 0
    local current = f:GetVerticalScroll()
    local max = f.GetScrollRange()
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

--- Create a scroll child for static scroll frames.
-- The scroll child is automatically attached to the parent scroll frame.
-- @param name (string) Unique name for the scroll child frame
-- @param parent (ScrollFrame) Parent scroll frame created by CreateStaticScrollFrame
-- @param height (number|nil) Initial height of the scroll child (default: 1)
-- @return (Frame) The created scroll child frame
function DBB2.schema.CreateStaticScrollChild(name, parent, height)
  local f = CreateFrame("Frame", name, parent)
  f:SetWidth(parent:GetWidth() or 1)
  f:SetHeight(height or 1)
  parent:SetScrollChild(f)
  parent.scrollChild = f
  
  if parent.UpdateScrollState then
    parent.UpdateScrollState()
  end
  
  return f
end


-- =====================
-- COLOR PICKER
-- =====================

--- Create a color picker button with preview.
-- Opens the WoW color picker dialog when clicked.
-- Supports opacity/alpha channel selection.
-- @param name (string|nil) Unique name for the color picker container
-- @param parent (Frame) Parent frame to attach the color picker to
-- @param label (string|nil) Label text displayed next to the color button
-- @param fontSize (number|nil) Font size for the label (default: 10)
-- @return (Frame) The created color picker with the following methods:
--   - SetColor(r, g, b, a): Sets the color (values 0-1)
--   - GetColor(): Returns r, g, b, a color values
--   - OnColorChanged: Callback function called when color changes
function DBB2.schema.CreateColorPicker(name, parent, label, fontSize)
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
