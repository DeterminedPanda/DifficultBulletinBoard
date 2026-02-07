-- DBB2 Config Schema API
-- Core schema rendering system and basic widget renderers
-- Complex list widgets are in api/config_widgets.lua
-- Constants are in env/constants.lua

-- Localize frequently used globals for performance
local string_gfind = string.gfind
local string_gsub = string.gsub
local table_insert = table.insert
local table_getn = table.getn
local ipairs = ipairs

DBB2.api = DBB2.api or {}

-- Local references to env constants (for performance)
local SPACING = DBB2.env.SPACING
local DEFAULT_WIDTH = DBB2.env.DEFAULT_WIDTH
local FONT_SIZE = DBB2.env.FONT_SIZE
local FONT_SIZE_INPUT = DBB2.env.FONT_SIZE_INPUT
local FONT_SIZE_SMALL = DBB2.env.FONT_SIZE_SMALL
local FONT_SIZE_LARGE = DBB2.env.FONT_SIZE_LARGE
local SECTION_FONT_SIZE = DBB2.env.SECTION_FONT_SIZE

-- ============================================================================
-- [ CreateConfigInput ]
-- ============================================================================
-- Creates an input box (EditBox) specifically styled for config panels.
-- The input box has a minimal border style that matches slider boxes,
-- with highlight color on hover for visual feedback.
--
-- This function is GLOBAL so that config_widgets.lua can access it.
--
-- Parameters:
--   name (string|nil) - Optional frame name for the EditBox.
--   parent (Frame)    - The parent frame to attach the EditBox to.
--
-- Returns:
--   EditBox - A styled EditBox frame with:
--     - Border textures (borderTop, borderBottom, borderLeft, borderRight)
--     - Highlight color on hover
--     - Escape key clears focus
--     - Height set to SPACING.inputHeight
-- ============================================================================
function CreateConfigInput(name, parent)
  local f = CreateFrame("EditBox", name, parent)
  f:SetHeight(DBB2:ScaleSize(SPACING.inputHeight))
  f:SetAutoFocus(false)
  f:EnableMouse(true)
  f:SetTextInsets(DBB2:ScaleSize(5), DBB2:ScaleSize(5), DBB2:ScaleSize(3), DBB2:ScaleSize(3))
  f:SetJustifyH("LEFT")
  
  -- Set font directly with explicit bright white color
  f:SetFont("Fonts\\FRIZQT__.TTF", DBB2:GetFontSize(FONT_SIZE_INPUT))
  f:SetTextColor(1, 1, 1, 1)
  
  -- Border textures only (no background) - matches slider box style
  f.borderTop = f:CreateTexture(nil, "BORDER")
  f.borderTop:SetTexture(0.2, 0.2, 0.2, 1)
  f.borderTop:SetHeight(1)
  f.borderTop:SetPoint("TOPLEFT", -1, 1)
  f.borderTop:SetPoint("TOPRIGHT", 1, 1)
  
  f.borderBottom = f:CreateTexture(nil, "BORDER")
  f.borderBottom:SetTexture(0.2, 0.2, 0.2, 1)
  f.borderBottom:SetHeight(1)
  f.borderBottom:SetPoint("BOTTOMLEFT", -1, -1)
  f.borderBottom:SetPoint("BOTTOMRIGHT", 1, -1)
  
  f.borderLeft = f:CreateTexture(nil, "BORDER")
  f.borderLeft:SetTexture(0.2, 0.2, 0.2, 1)
  f.borderLeft:SetWidth(1)
  f.borderLeft:SetPoint("TOPLEFT", -1, 1)
  f.borderLeft:SetPoint("BOTTOMLEFT", -1, -1)
  
  f.borderRight = f:CreateTexture(nil, "BORDER")
  f.borderRight:SetTexture(0.2, 0.2, 0.2, 1)
  f.borderRight:SetWidth(1)
  f.borderRight:SetPoint("TOPRIGHT", 1, 1)
  f.borderRight:SetPoint("BOTTOMRIGHT", 1, -1)
  
  f:SetScript("OnEscapePressed", function()
    this:ClearFocus()
  end)
  
  f:SetScript("OnEnter", function()
    local r, g, b = DBB2:GetHighlightColor()
    this.borderTop:SetTexture(r, g, b, 1)
    this.borderBottom:SetTexture(r, g, b, 1)
    this.borderLeft:SetTexture(r, g, b, 1)
    this.borderRight:SetTexture(r, g, b, 1)
  end)
  
  f:SetScript("OnLeave", function()
    this.borderTop:SetTexture(0.2, 0.2, 0.2, 1)
    this.borderBottom:SetTexture(0.2, 0.2, 0.2, 1)
    this.borderLeft:SetTexture(0.2, 0.2, 0.2, 1)
    this.borderRight:SetTexture(0.2, 0.2, 0.2, 1)
  end)
  
  return f
end

-- ============================================================================
-- [ RenderConfigSchema ]
-- ============================================================================
-- Renders a declarative config schema into a scrollable panel with widgets.
-- This is the main entry point for building configuration UI panels using
-- the schema-based approach. Each schema item defines a widget type and its
-- configuration, which is then rendered into the panel.
--
-- Parameters:
--   panel (Frame)  - The parent frame to render the config UI into.
--                    Will have scrollFrame and _widgets attached to it.
--   schema (table) - Array of widget definitions. Each item is a table with:
--                    - type (string): Widget type - "section", "description",
--                      "slider", "toggle", "colorpicker", "checkbox",
--                      "channelList", "categoryList", "keywordList",
--                      "keywordImportExport", or "editbox"
--                    - Additional fields depend on widget type (see below)
--   options (table, optional) - Reserved for future configuration options.
--
-- Schema Widget Types:
--   section:     { type="section", label="Section Title" }
--   description: { type="description", text="Help text", fontSize=8 }
--   slider:      { type="slider", key="configKey", label="Label",
--                  min=0, max=100, step=1, default=50, width=250,
--                  tooltip="Help", valueLabels={[0]="Off"}, onChange=fn }
--   toggle:      { type="toggle", key="configKey", label="Label",
--                  default=false, width=250, tooltip="Help", onChange=fn }
--   colorpicker: { type="colorpicker", key="configKey", label="Label",
--                  default={r=1,g=1,b=1,a=1}, width=250, tooltip="Help",
--                  onChange=fn }
--   checkbox:    { type="checkbox", key="configKey", label="Label",
--                  default=false, tooltip="Help", onChange=fn }
--   channelList: { type="channelList" }
--   categoryList:{ type="categoryList", categoryType="groups"|"professions",
--                  showFilterTags=true }
--   keywordList: { type="keywordList" }
--   keywordImportExport: { type="keywordImportExport" }
--   editbox:     { type="editbox", placeholder="Text...", onEnter=fn }
--
-- Returns:
--   table - A result table containing:
--     - scrollFrame (Frame): The scroll frame widget
--     - scrollChild (Frame): The scroll child containing all widgets
--     - widgets (table): Array of created widget references
--     - panel (Frame): Reference to the input panel
--
-- Usage Example:
--   local schema = {
--     { type = "section", label = "Display Settings" },
--     { type = "slider", key = "fontOffset", label = "Font Size",
--       min = -4, max = 4, step = 1, default = 0 },
--     { type = "toggle", key = "showCurrentTime", label = "Show Time",
--       default = false },
--   }
--   DBB2.api.RenderConfigSchema(myPanel, schema)
-- ============================================================================
function DBB2.api.RenderConfigSchema(panel, schema, options)
  options = options or {}
  local scrollPadding = DBB2:ScaleSize(5)
  
  -- Create scroll frame
  local scrollFrame = DBB2.schema.CreateStaticScrollFrame(nil, panel)
  scrollFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
  scrollFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 0)
  panel.scrollFrame = scrollFrame
  
  -- Scrollbar padding
  scrollFrame.slider:ClearAllPoints()
  scrollFrame.slider:SetPoint("TOPRIGHT", scrollFrame, "TOPRIGHT", 0, -scrollPadding)
  scrollFrame.slider:SetPoint("BOTTOMRIGHT", scrollFrame, "BOTTOMRIGHT", 0, scrollPadding)
  
  -- Create scroll child
  local scrollChild = CreateFrame("Frame", nil, scrollFrame)
  scrollChild:SetWidth(1)
  scrollChild:SetHeight(1)
  scrollFrame:SetScrollChild(scrollChild)
  scrollFrame.scrollChild = scrollChild
  
  -- Store schema and rendering state on panel for rebuilding
  panel._schema = schema
  panel._widgets = {}
  panel._xOffset = DBB2:ScaleSize(SPACING.padding)
  
  -- Function to render/rebuild all widgets
  local function RenderAllWidgets()
    local hr, hg, hb = DBB2:GetHighlightColor()
    local yOffset = -DBB2:ScaleSize(SPACING.padding)
    local xOffset = panel._xOffset
    local lastType = nil
    
    for i, item in ipairs(schema) do
      local widget = panel._widgets[i]
      local widgetHeight = 0
      
      -- Calculate spacing
      local spacing = SPACING.widget
      if lastType == "section" then spacing = SPACING.afterSection
      elseif lastType == "description" then spacing = SPACING.description
      elseif item.type == "section" then spacing = SPACING.section
      end
      
      if lastType then
        yOffset = yOffset - DBB2:ScaleSize(spacing)
      end
      
      -- Create widget if not exists, otherwise just reposition
      if not widget then
        if item.type == "section" then
          widget = DBB2.schema.CreateLabel(scrollChild, item.label, SECTION_FONT_SIZE)
          widget:SetTextColor(hr, hg, hb, 1)
        elseif item.type == "description" then
          widget = DBB2.schema.CreateLabel(scrollChild, item.text, item.fontSize or FONT_SIZE_SMALL)
          widget:SetTextColor(0.5, 0.5, 0.5, 1)
        elseif item.type == "slider" then
          widget = RenderSlider(scrollChild, item, xOffset, yOffset)
        elseif item.type == "toggle" then
          widget = RenderToggle(scrollChild, item, xOffset, yOffset)
        elseif item.type == "colorpicker" then
          widget = RenderColorPicker(scrollChild, item, xOffset, yOffset)
        elseif item.type == "checkbox" then
          widget = RenderCheckbox(scrollChild, item, xOffset, yOffset)
        elseif item.type == "channelList" then
          widget = RenderChannelList(scrollChild, panel, item, xOffset, yOffset)
        elseif item.type == "categoryList" then
          widget = RenderCategoryList(scrollChild, panel, item, xOffset, yOffset)
        elseif item.type == "keywordList" then
          widget = RenderKeywordList(scrollChild, panel, item, xOffset, yOffset)
        elseif item.type == "keywordImportExport" then
          widget = RenderKeywordImportExport(scrollChild, panel, item, xOffset, yOffset)
        elseif item.type == "editbox" then
          widget = RenderEditBox(scrollChild, item, xOffset, yOffset)
        end
        panel._widgets[i] = widget
      end
      
      -- Get widget height
      if item.type == "section" or item.type == "description" then
        widgetHeight = DBB2:ScaleSize(12)
        if widget.SetPoint then
          widget:ClearAllPoints()
          widget:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", xOffset, yOffset)
        end
      elseif item.type == "slider" or item.type == "toggle" then
        widgetHeight = DBB2:ScaleSize(30)
      elseif item.type == "colorpicker" then
        widgetHeight = DBB2:ScaleSize(20)
      elseif item.type == "checkbox" then
        widgetHeight = DBB2:ScaleSize(16)
      elseif item.type == "channelList" or item.type == "categoryList" or item.type == "keywordList" or item.type == "keywordImportExport" then
        -- Dynamic widgets - rebuild and get height
        if widget and widget.rebuild then
          widget.rebuild()
        end
        if widget and widget.getHeight then
          widgetHeight = widget.getHeight()
        end
        -- Reposition container
        if widget and widget.container then
          widget.container:ClearAllPoints()
          widget.container:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", xOffset, yOffset)
          widget.container:SetPoint("RIGHT", scrollChild, "RIGHT", -DBB2:ScaleSize(SPACING.padding), 0)
        end
      elseif item.type == "editbox" then
        widgetHeight = DBB2:ScaleSize(20)
      end
      
      yOffset = yOffset - widgetHeight
      lastType = item.type
    end
    
    -- Set content height (includes bottom padding for extra scroll space)
    local contentHeight = -yOffset + DBB2:ScaleSize(SPACING.padding) + DBB2:ScaleSize(SPACING.bottomPadding)
    scrollChild:SetHeight(contentHeight)
    
    -- Update scroll state
    if scrollFrame.UpdateScrollState then
      scrollFrame.UpdateScrollState()
    end
  end
  
  -- Track scroll width for responsive updates
  local lastScrollWidth = 0
  local function UpdateScrollWidth()
    local scrollLeft = scrollFrame:GetLeft()
    local scrollRight = scrollFrame:GetRight()
    if not scrollLeft or not scrollRight then return false end
    
    local scrollWidth = scrollRight - scrollLeft
    if scrollWidth > 0 and scrollWidth ~= lastScrollWidth then
      lastScrollWidth = scrollWidth
      scrollChild:SetWidth(scrollWidth)
      return true
    end
    return false
  end
  
  scrollFrame:SetScript("OnUpdate", function()
    if not this:IsVisible() then return end
    if UpdateScrollWidth() then
      this.UpdateScrollState()
    end
  end)
  
  -- Store rebuild function on panel
  panel.RebuildDynamicContent = RenderAllWidgets
  
  -- Initial render (widgets will be created but may need repositioning on show)
  RenderAllWidgets()
  
  -- Rebuild on show - this ensures proper dimensions after panel is visible
  local origOnShow = panel:GetScript("OnShow")
  panel:SetScript("OnShow", function()
    -- Ensure width is set
    local left = scrollFrame:GetLeft()
    local right = scrollFrame:GetRight()
    if left and right then
      scrollChild:SetWidth(right - left)
    end
    RenderAllWidgets()
    if scrollFrame.UpdateScrollState then
      scrollFrame.UpdateScrollState()
    end
    if origOnShow then origOnShow() end
  end)
  
  return { scrollFrame = scrollFrame, scrollChild = scrollChild, widgets = panel._widgets, panel = panel }
end


-- =====================
-- BASIC WIDGET RENDERERS
-- =====================
-- These functions render individual widget types for the config schema system.
-- They are called internally by RenderConfigSchema based on the widget type.

-- ============================================================================
-- [ RenderSlider ]
-- ============================================================================
-- Renders a slider widget for numeric configuration values.
--
-- Parameters:
--   parent (Frame) - The parent frame (scroll child) to attach the slider to.
--   item (table)   - Schema item with: key, label, min, max, step, default,
--                    width, tooltip, valueLabels, onChange.
--   x (number)     - X offset from parent's TOPLEFT.
--   y (number)     - Y offset from parent's TOPLEFT (negative = down).
--
-- Returns:
--   Frame - The slider widget frame with OnValueChanged callback.
-- ============================================================================
function RenderSlider(parent, item, x, y)
  local currentValue = DBB2_Config[item.key]
  if currentValue == nil then currentValue = item.default or item.min or 0 end
  if currentValue == true then currentValue = 1 end
  if currentValue == false then currentValue = 0 end
  
  local labelText = item.label
  if item.valueLabels and item.valueLabels[currentValue] then
    labelText = item.label .. ": " .. item.valueLabels[currentValue]
  end
  
  local slider = DBB2.schema.CreateSlider(nil, parent, labelText, item.min, item.max, item.step or 1, FONT_SIZE)
  slider:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  slider:SetWidth(DBB2:ScaleSize(item.width or DEFAULT_WIDTH))
  slider:SetValue(currentValue)
  
  if item.tooltip then
    slider.slider:SetScript("OnEnter", function()
      local r, g, b = DBB2:GetHighlightColor()
      local container = this:GetParent()
      container.track:SetVertexColor(r, g, b, 1)
      DBB2.api.ShowTooltip(this, "RIGHT", item.tooltip)
    end)
    slider.slider:SetScript("OnLeave", function()
      local container = this:GetParent()
      container.track:SetVertexColor(0.2, 0.2, 0.2, 1)
      DBB2.api.HideTooltip()
    end)
  end
  
  slider.OnValueChanged = function(val)
    DBB2_Config[item.key] = val
    if item.valueLabels and item.valueLabels[val] then
      slider.label:SetText(item.label .. ": " .. item.valueLabels[val])
    end
    if item.onChange then item.onChange(val) end
  end
  
  return slider
end

-- ============================================================================
-- [ RenderToggle ]
-- ============================================================================
-- Renders a toggle widget (On/Off slider) for boolean configuration values.
--
-- Parameters:
--   parent (Frame) - The parent frame (scroll child) to attach the toggle to.
--   item (table)   - Schema item with: key, label, default, width, tooltip,
--                    onChange.
--   x (number)     - X offset from parent's TOPLEFT.
--   y (number)     - Y offset from parent's TOPLEFT (negative = down).
--
-- Returns:
--   Frame - The toggle widget frame with OnValueChanged callback.
-- ============================================================================
function RenderToggle(parent, item, x, y)
  local currentValue = DBB2_Config[item.key]
  if currentValue == nil then currentValue = item.default end
  local numValue = currentValue and 1 or 0
  
  local toggleNames = { [0] = "Off", [1] = "On" }
  local slider = DBB2.schema.CreateSlider(nil, parent, item.label .. ": " .. toggleNames[numValue], 0, 1, 1, FONT_SIZE)
  slider:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  slider:SetWidth(DBB2:ScaleSize(item.width or DEFAULT_WIDTH))
  slider:SetValue(numValue)
  
  if item.tooltip then
    slider.slider:SetScript("OnEnter", function()
      local r, g, b = DBB2:GetHighlightColor()
      local container = this:GetParent()
      container.track:SetVertexColor(r, g, b, 1)
      DBB2.api.ShowTooltip(this, "RIGHT", item.tooltip)
    end)
    slider.slider:SetScript("OnLeave", function()
      local container = this:GetParent()
      container.track:SetVertexColor(0.2, 0.2, 0.2, 1)
      DBB2.api.HideTooltip()
    end)
  end
  
  slider.OnValueChanged = function(val)
    DBB2_Config[item.key] = (val == 1)
    slider.label:SetText(item.label .. ": " .. toggleNames[val])
    if item.onChange then item.onChange(val == 1) end
  end
  
  return slider
end

-- ============================================================================
-- [ RenderColorPicker ]
-- ============================================================================
-- Renders a color picker widget for RGBA color configuration values.
--
-- Parameters:
--   parent (Frame) - The parent frame (scroll child) to attach the picker to.
--   item (table)   - Schema item with: key, label, default (table with r,g,b,a),
--                    width, tooltip, onChange.
--   x (number)     - X offset from parent's TOPLEFT.
--   y (number)     - Y offset from parent's TOPLEFT (negative = down).
--
-- Returns:
--   Frame - The color picker widget frame with OnColorChanged callback.
-- ============================================================================
function RenderColorPicker(parent, item, x, y)
  local colorPicker = DBB2.schema.CreateColorPicker(nil, parent, item.label, FONT_SIZE)
  colorPicker:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  colorPicker:SetWidth(DBB2:ScaleSize(item.width or DEFAULT_WIDTH))
  
  local color = DBB2_Config[item.key] or item.default or {r = 1, g = 1, b = 1, a = 1}
  colorPicker:SetColor(color.r, color.g, color.b, color.a)
  
  if item.tooltip then
    colorPicker.button:SetScript("OnEnter", function()
      local r, g, b = DBB2:GetHighlightColor()
      this.backdrop:SetBackdropBorderColor(r, g, b, 1)
      DBB2.api.ShowTooltip(this, "RIGHT", item.tooltip)
    end)
    colorPicker.button:SetScript("OnLeave", function()
      this.backdrop:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
      DBB2.api.HideTooltip()
    end)
  end
  
  colorPicker.OnColorChanged = function(r, g, b, a)
    DBB2_Config[item.key] = {r = r, g = g, b = b, a = a}
    if item.onChange then item.onChange(r, g, b, a) end
  end
  
  return colorPicker
end

-- ============================================================================
-- [ RenderCheckbox ]
-- ============================================================================
-- Renders a checkbox widget for boolean configuration values.
--
-- Parameters:
--   parent (Frame) - The parent frame (scroll child) to attach the checkbox to.
--   item (table)   - Schema item with: key, label, default, tooltip, onChange.
--   x (number)     - X offset from parent's TOPLEFT.
--   y (number)     - Y offset from parent's TOPLEFT (negative = down).
--
-- Returns:
--   Frame - The checkbox widget frame with OnChecked callback.
-- ============================================================================
function RenderCheckbox(parent, item, x, y)
  local checkSize = DBB2:ScaleSize(SPACING.checkSize)
  local checkbox = DBB2.schema.CreateCheckBox(nil, parent, item.label, FONT_SIZE)
  checkbox:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  checkbox:SetWidth(checkSize)
  checkbox:SetHeight(checkSize)
  
  local checked = DBB2_Config[item.key]
  if checked == nil then checked = item.default end
  checkbox:SetChecked(checked)
  
  if item.tooltip then
    checkbox:SetScript("OnEnter", function()
      local r, g, b = DBB2:GetHighlightColor()
      this.backdrop:SetBackdropBorderColor(r, g, b, 1)
      DBB2.api.ShowTooltip(this, "RIGHT", item.tooltip)
    end)
    checkbox:SetScript("OnLeave", function()
      this.backdrop:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
      DBB2.api.HideTooltip()
    end)
  end
  
  checkbox.OnChecked = function(checked)
    DBB2_Config[item.key] = checked
    if item.onChange then item.onChange(checked) end
  end
  
  return checkbox
end

-- ============================================================================
-- [ RenderEditBox ]
-- ============================================================================
-- Renders an edit box widget for text input.
--
-- Parameters:
--   parent (Frame) - The parent frame (scroll child) to attach the editbox to.
--   item (table)   - Schema item with: placeholder, onEnter callback.
--   x (number)     - X offset from parent's TOPLEFT.
--   y (number)     - Y offset from parent's TOPLEFT (negative = down).
--
-- Returns:
--   EditBox - The edit box widget frame.
-- ============================================================================
function RenderEditBox(parent, item, x, y)
  local editbox = CreateConfigInput(nil, parent)
  editbox:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  editbox:SetPoint("RIGHT", parent, "RIGHT", -DBB2:ScaleSize(SPACING.padding + 20), 0)
  editbox:SetHeight(DBB2:ScaleSize(SPACING.inputHeight))
  
  if item.placeholder then
    editbox.placeholder = editbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    editbox.placeholder:SetFont("Fonts\\FRIZQT__.TTF", DBB2:GetFontSize(FONT_SIZE_INPUT))
    editbox.placeholder:SetPoint("LEFT", DBB2:ScaleSize(6), 0)
    editbox.placeholder:SetText(item.placeholder)
    editbox.placeholder:SetTextColor(0.4, 0.4, 0.4, 1)
    
    editbox:SetScript("OnEditFocusGained", function()
      if this.placeholder then this.placeholder:Hide() end
    end)
    editbox:SetScript("OnEditFocusLost", function()
      if this.placeholder and this:GetText() == "" then this.placeholder:Show() end
    end)
  end
  
  if item.onEnter then
    editbox:SetScript("OnEnterPressed", function()
      item.onEnter(this:GetText())
      this:ClearFocus()
    end)
  end
  
  return editbox
end
