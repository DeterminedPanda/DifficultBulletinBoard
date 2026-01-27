-- DBB2 Config Schema API
-- Declarative configuration system for building config panels
-- All tabs use the same scroll frame system for consistent look and feel

-- Localize frequently used globals for performance
local string_gfind = string.gfind
local string_gsub = string.gsub
local table_insert = table.insert
local table_getn = table.getn
local ipairs = ipairs

DBB2.api = DBB2.api or {}

-- Spacing constants (used everywhere for consistency)
local SPACING = {
  widget = 11,        -- Between widgets
  section = 19,       -- Before section headers
  afterSection = 8,   -- After section headers
  description = 5,    -- After descriptions
  padding = 10,       -- Panel edge padding
  rowHeight = 28,     -- Category/keyword row height
  checkSize = 14,     -- Checkbox size
  inputHeight = 18,   -- Input field height
  bottomPadding = 0, -- Extra scroll space after last content
}

local DEFAULT_WIDTH = 250
local FONT_SIZE = 9            -- For settings/labels under sections
local FONT_SIZE_INPUT = 10     -- For text inside input boxes
local FONT_SIZE_SMALL = 8      -- For descriptions and secondary text
local FONT_SIZE_LARGE = 11     -- For buttons and emphasis
local SECTION_FONT_SIZE = 10   -- For section headers (Display Settings, etc.)

-- ============================================================================
-- [ CreateConfigInput ]
-- ============================================================================
-- Creates an input box (EditBox) specifically styled for config panels.
-- The input box has a minimal border style that matches slider boxes,
-- with highlight color on hover for visual feedback.
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
local function CreateConfigInput(name, parent)
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


-- =====================
-- CHANNEL LIST WIDGET
-- =====================

-- ============================================================================
-- [ RenderChannelList ]
-- ============================================================================
-- Renders a dynamic list of channel checkboxes for monitoring configuration.
-- Displays all available channels with checkboxes to enable/disable monitoring.
-- Automatically detects hardcore characters and disables Hardcore channel
-- for non-hardcore characters.
--
-- Parameters:
--   parent (Frame) - The parent frame (scroll child) to attach the list to.
--   panel (Frame)  - The config panel (stores channelCheckboxes reference).
--   item (table)   - Schema item (currently unused, reserved for options).
--   x (number)     - X offset from parent's TOPLEFT.
--   y (number)     - Y offset from parent's TOPLEFT (negative = down).
--
-- Returns:
--   table - Widget interface with:
--     - container (Frame): The container frame holding all checkboxes
--     - rebuild (function): Function to rebuild the checkbox list
--     - getHeight (function): Returns the current total height
-- ============================================================================
function RenderChannelList(parent, panel, item, x, y)
  local hr, hg, hb = DBB2:GetHighlightColor()
  local checkSize = DBB2:ScaleSize(SPACING.checkSize)
  local rowSpacing = DBB2:ScaleSize(5)
  local sectionGap = DBB2:ScaleSize(8)
  
  local container = CreateFrame("Frame", nil, parent)
  container:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  container:SetPoint("RIGHT", parent, "RIGHT", -DBB2:ScaleSize(SPACING.padding), 0)
  container:SetHeight(1)  -- Will be set by rebuild
  
  panel.channelCheckboxes = {}
  
  local channelDescriptions = {
    Say = "Local /say chat", Yell = "Local /yell chat", Guild = "Your guild chat",
    Whisper = "Private whispers", Party = "Your party chat", General = "Zone general chat",
    Trade = "Trade channel", LocalDefense = "Zone defense", WorldDefense = "World defense",
    LookingForGroup = "Official LFG channel", GuildRecruitment = "Guild recruitment",
    World = "Main LFG channel", Hardcore = "Hardcore channel"
  }
  
  local totalHeight = checkSize  -- Minimum height
  
  local function Rebuild()
    -- Hide existing checkboxes
    for _, check in ipairs(panel.channelCheckboxes) do
      check:Hide()
    end
    panel.channelCheckboxes = {}
    
    local isHardcoreChar = DBB2.api.DetectHardcoreCharacter()
    local channelList = DBB2.api.RefreshJoinedChannels()
    
    -- Ensure we have channels
    if not channelList then
      totalHeight = checkSize
      container:SetHeight(totalHeight)
      return
    end
    
    -- Count channels (Lua 5.0 compatible)
    local channelCount = 0
    for _ in ipairs(channelList) do
      channelCount = channelCount + 1
    end
    
    if channelCount == 0 then
      totalHeight = checkSize
      container:SetHeight(totalHeight)
      return
    end
    
    local currentY = 0
    totalHeight = 0
    
    for i, channelName in ipairs(channelList) do
      if channelName == "-" then
        -- Section separator
        currentY = currentY - sectionGap
        totalHeight = totalHeight + sectionGap
      else
        local check = DBB2.schema.CreateCheckBox(nil, container, channelName, FONT_SIZE)
        check:SetPoint("TOPLEFT", container, "TOPLEFT", 0, currentY)
        check:SetWidth(checkSize)
        check:SetHeight(checkSize)
        check._channelName = channelName
        
        if channelName == "Hardcore" and not isHardcoreChar then
          check:SetChecked(false)
          check:Disable()
        else
          check:SetChecked(DBB2.api.IsChannelMonitored(channelName))
          check.OnChecked = function(checked)
            DBB2.api.SetChannelMonitored(check._channelName, checked)
          end
        end
        
        check:SetScript("OnEnter", function()
          local r, g, b = DBB2:GetHighlightColor()
          this.backdrop:SetBackdropBorderColor(r, g, b, 1)
          local desc = channelDescriptions[this._channelName] or "Monitor this channel."
          DBB2.api.ShowTooltip(this, "RIGHT", {{this._channelName, "highlight"}, desc})
        end)
        check:SetScript("OnLeave", function()
          this.backdrop:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
          DBB2.api.HideTooltip()
        end)
        
        table_insert(panel.channelCheckboxes, check)
        currentY = currentY - checkSize - rowSpacing
        totalHeight = totalHeight + checkSize + rowSpacing
      end
    end
    
    -- Ensure minimum height
    if totalHeight < checkSize then
      totalHeight = checkSize
    end
    
    container:SetHeight(totalHeight)
  end
  
  -- Initial build
  Rebuild()
  panel.RebuildChannelCheckboxes = Rebuild
  
  return {
    container = container,
    rebuild = Rebuild,
    getHeight = function() return totalHeight end
  }
end


-- =====================
-- CATEGORY LIST WIDGET
-- =====================

-- ============================================================================
-- [ RenderCategoryList ]
-- ============================================================================
-- Renders a dynamic list of category rows with checkboxes and tag inputs.
-- Each row shows a category name, enabled checkbox, and editable tags field.
-- Optionally includes a filter tags row at the top for additional filtering.
--
-- Parameters:
--   parent (Frame) - The parent frame (scroll child) to attach the list to.
--   panel (Frame)  - The config panel (stores categoryRows, filterTagsInput).
--   item (table)   - Schema item with:
--                    - categoryType (string): "groups", "professions", etc.
--                    - showFilterTags (boolean): Whether to show filter row.
--   x (number)     - X offset from parent's TOPLEFT.
--   y (number)     - Y offset from parent's TOPLEFT (negative = down).
--
-- Returns:
--   table - Widget interface with:
--     - container (Frame): The container frame holding all rows
--     - rebuild (function): Function to rebuild the category rows
--     - getHeight (function): Returns the current total height
-- ============================================================================
function RenderCategoryList(parent, panel, item, x, y)
  local hr, hg, hb = DBB2:GetHighlightColor()
  local categoryType = item.categoryType
  local rowHeight = DBB2:ScaleSize(SPACING.rowHeight)
  local checkSize = DBB2:ScaleSize(SPACING.checkSize)
  local nameWidth = DBB2:ScaleSize(150)
  local inputHeight = DBB2:ScaleSize(SPACING.inputHeight)
  
  local container = CreateFrame("Frame", nil, parent)
  container:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  container:SetPoint("RIGHT", parent, "RIGHT", -DBB2:ScaleSize(SPACING.padding), 0)
  container:SetHeight(1)
  
  panel.categoryRows = {}
  local totalHeight = rowHeight  -- Minimum
  
  -- Filter tags row (for groups/professions)
  local filterRowHeight = 0
  local filterRow = nil
  
  if item.showFilterTags then
    filterRow = CreateFrame("Frame", nil, container)
    filterRow:SetHeight(rowHeight)
    filterRow:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
    filterRow:SetPoint("RIGHT", container, "RIGHT", 0, 0)
    
    local filterCheck = DBB2.schema.CreateCheckBox(nil, filterRow)
    filterCheck:SetPoint("LEFT", 0, 0)
    filterCheck:SetWidth(checkSize)
    filterCheck:SetHeight(checkSize)
    filterCheck:SetChecked(DBB2.api.IsFilterTagsEnabled(categoryType))
    filterCheck.OnChecked = function(checked)
      DBB2.api.SetFilterTagsEnabled(categoryType, checked)
    end
    
    local filterLabel = DBB2.schema.CreateLabel(filterRow, "Filter Tags", FONT_SIZE)
    filterLabel:SetPoint("LEFT", filterCheck, "RIGHT", 8, 0)
    filterLabel:SetWidth(nameWidth)
    filterLabel:SetTextColor(hr, hg, hb, 0.9)
    
    local filterInput = CreateConfigInput(nil, filterRow)
    filterInput:SetPoint("LEFT", filterLabel, "RIGHT", 5, 0)
    filterInput:SetPoint("RIGHT", filterRow, "RIGHT", -DBB2:ScaleSize(5), 0)
    filterInput:SetHeight(inputHeight)
    
    local filterConfig = DBB2.api.GetFilterTags(categoryType)
    if filterConfig and filterConfig.tags then
      filterInput:SetText(DBB2.api.TagsToString(filterConfig.tags))
    end
    
    filterInput:SetScript("OnEscapePressed", function() this:ClearFocus() end)
    filterInput:SetScript("OnEnterPressed", function()
      DBB2.api.UpdateFilterTags(categoryType, DBB2.api.ParseTagsString(this:GetText()))
      this:ClearFocus()
    end)
    filterInput:SetScript("OnEditFocusLost", function()
      DBB2.api.UpdateFilterTags(categoryType, DBB2.api.ParseTagsString(this:GetText()))
    end)
    filterInput:SetScript("OnEnter", function()
      local r, g, b = DBB2:GetHighlightColor()
      this.borderTop:SetTexture(r, g, b, 1)
      this.borderBottom:SetTexture(r, g, b, 1)
      this.borderLeft:SetTexture(r, g, b, 1)
      this.borderRight:SetTexture(r, g, b, 1)
      DBB2.api.ShowTooltip(this, "RIGHT", {{"Filter Tags", "highlight"}, "Messages must also match one of these.", {"Disable to match all.", "gray"}})
    end)
    filterInput:SetScript("OnLeave", function()
      this.borderTop:SetTexture(0.2, 0.2, 0.2, 1)
      this.borderBottom:SetTexture(0.2, 0.2, 0.2, 1)
      this.borderLeft:SetTexture(0.2, 0.2, 0.2, 1)
      this.borderRight:SetTexture(0.2, 0.2, 0.2, 1)
      DBB2.api.HideTooltip()
    end)
    
    panel.filterTagsInput = filterInput
    panel.filterCategoryType = categoryType
    filterRowHeight = rowHeight + DBB2:ScaleSize(5)
  end
  
  local function BuildRows()
    local categories = DBB2.api.GetCategories(categoryType)
    if not categories then
      totalHeight = filterRowHeight + rowHeight
      container:SetHeight(totalHeight)
      return
    end
    
    local currentY = -filterRowHeight
    
    for i, cat in ipairs(categories) do
      local row = panel.categoryRows[i]
      if not row then
        row = CreateFrame("Frame", nil, container)
        row:SetHeight(rowHeight)
        panel.categoryRows[i] = row
        
        row.check = DBB2.schema.CreateCheckBox(nil, row)
        row.check:SetPoint("LEFT", 0, 0)
        row.check:SetWidth(checkSize)
        row.check:SetHeight(checkSize)
        
        row.nameLabel = DBB2.schema.CreateLabel(row, "", FONT_SIZE)
        row.nameLabel:SetPoint("LEFT", row.check, "RIGHT", 8, 0)
        row.nameLabel:SetWidth(nameWidth)
        
        row.tagsInput = CreateConfigInput(nil, row)
        row.tagsInput:SetPoint("LEFT", row.nameLabel, "RIGHT", 5, 0)
        row.tagsInput:SetPoint("RIGHT", row, "RIGHT", -DBB2:ScaleSize(5), 0)
        row.tagsInput:SetHeight(inputHeight)
        
        row.tagsInput:SetScript("OnEscapePressed", function() this:ClearFocus() end)
      end
      
      row:ClearAllPoints()
      row:SetPoint("TOPLEFT", container, "TOPLEFT", 0, currentY)
      row:SetPoint("RIGHT", container, "RIGHT", 0, 0)
      row:Show()
      
      row.categoryName = cat.name
      row.categoryType = categoryType
      row.nameLabel:SetText(cat.name)
      row.nameLabel:SetTextColor(1, 1, 1, 1)
      row.check:SetChecked(cat.selected)
      row.tagsInput:SetText(DBB2.api.TagsToString(cat.tags))
      
      row.check.OnChecked = function(checked)
        DBB2.api.SetCategorySelected(row.categoryType, row.categoryName, checked)
      end
      row.tagsInput:SetScript("OnEnterPressed", function()
        DBB2.api.UpdateCategoryTags(row.categoryType, row.categoryName, DBB2.api.ParseTagsString(this:GetText()))
        this:ClearFocus()
      end)
      row.tagsInput:SetScript("OnEditFocusLost", function()
        DBB2.api.UpdateCategoryTags(row.categoryType, row.categoryName, DBB2.api.ParseTagsString(this:GetText()))
      end)
      
      currentY = currentY - rowHeight
    end
    
    -- Hide extra rows
    local catCount = 0
    for _ in ipairs(categories) do catCount = catCount + 1 end
    local rowCount = 0
    for _ in ipairs(panel.categoryRows) do rowCount = rowCount + 1 end
    
    for i = catCount + 1, rowCount do
      if panel.categoryRows[i] then panel.categoryRows[i]:Hide() end
    end
    
    totalHeight = filterRowHeight + (catCount * rowHeight)
    if totalHeight < rowHeight then totalHeight = rowHeight end
    container:SetHeight(totalHeight)
  end
  
  BuildRows()
  
  return {
    container = container,
    rebuild = BuildRows,
    getHeight = function() return totalHeight end
  }
end


-- =====================
-- KEYWORD IMPORT/EXPORT WIDGET
-- =====================

-- ============================================================================
-- [ RenderKeywordImportExport ]
-- ============================================================================
-- Renders an input box for bulk import/export of blacklist keywords.
-- Keywords are displayed as a comma-separated string that can be edited.
-- On Enter press, the entire keyword list is replaced with the parsed input.
-- On focus lost, the input reverts to the current keyword list.
--
-- Parameters:
--   parent (Frame) - The parent frame (scroll child) to attach the widget to.
--   panel (Frame)  - The config panel (stores importExportBox reference).
--   item (table)   - Schema item (currently unused, reserved for options).
--   x (number)     - X offset from parent's TOPLEFT.
--   y (number)     - Y offset from parent's TOPLEFT (negative = down).
--
-- Returns:
--   table - Widget interface with:
--     - container (Frame): The container frame holding the input box
--     - rebuild (function): Function to update the input with current keywords
--     - getHeight (function): Returns the widget height
-- ============================================================================
function RenderKeywordImportExport(parent, panel, item, x, y)
  local inputHeight = DBB2:ScaleSize(SPACING.inputHeight)
  
  local container = CreateFrame("Frame", nil, parent)
  container:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  container:SetPoint("RIGHT", parent, "RIGHT", -DBB2:ScaleSize(SPACING.padding), 0)
  container:SetHeight(inputHeight)
  
  -- Helper function to convert keywords array to comma-separated string
  local function KeywordsToString()
    local keywords = DBB2.api.GetBlacklistedKeywords()
    if not keywords then return "" end
    return table.concat(keywords, ", ")
  end
  
  -- Helper function to parse comma-separated string to keywords
  local function StringToKeywords(str)
    local keywords = {}
    for kw in string_gfind(str, "([^,]+)") do
      kw = string_gsub(kw, "^%s*(.-)%s*$", "%1")
      if kw ~= "" then
        table_insert(keywords, kw)
      end
    end
    return keywords
  end
  
  -- Create the import/export input box
  local importExportBox = CreateConfigInput(nil, container)
  importExportBox:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
  importExportBox:SetPoint("RIGHT", container, "RIGHT", -DBB2:ScaleSize(5), 0)  -- Match category tags spacing
  importExportBox:SetHeight(inputHeight)
  
  -- Store reference on panel for rebuilding
  panel.importExportBox = importExportBox
  
  -- Update box with current keywords
  local function UpdateImportExportBox()
    importExportBox:SetText(KeywordsToString())
  end
  
  -- Import on Enter press
  importExportBox:SetScript("OnEnterPressed", function()
    local str = this:GetText()
    local newKeywords = StringToKeywords(str)
    
    -- Clear existing keywords
    DBB2_Config.blacklist.keywords = {}
    
    -- Add new keywords in order
    for _, kw in ipairs(newKeywords) do
      DBB2.api.AddKeywordToBlacklist(kw)
    end
    
    this:ClearFocus()
    
    -- Rebuild keyword list if it exists
    if panel.RebuildDynamicContent then
      panel.RebuildDynamicContent()
    end
  end)
  
  -- Restore current keywords on focus lost (cancel edit)
  importExportBox:SetScript("OnEditFocusLost", function()
    UpdateImportExportBox()
  end)
  
  importExportBox:SetScript("OnEscapePressed", function()
    this:ClearFocus()
  end)
  
  -- Initial population
  UpdateImportExportBox()
  
  return {
    container = container,
    rebuild = UpdateImportExportBox,
    getHeight = function() return inputHeight end
  }
end


-- =====================
-- KEYWORD LIST WIDGET
-- =====================

-- ============================================================================
-- [ RenderKeywordList ]
-- ============================================================================
-- Renders a dynamic list of blacklist keywords with an input field for adding
-- new keywords and remove buttons for each existing keyword.
-- Each keyword row shows the keyword text, optional pattern description,
-- and a remove button.
--
-- Parameters:
--   parent (Frame) - The parent frame (scroll child) to attach the list to.
--   panel (Frame)  - The config panel (stores keywordRows reference).
--   item (table)   - Schema item (currently unused, reserved for options).
--   x (number)     - X offset from parent's TOPLEFT.
--   y (number)     - Y offset from parent's TOPLEFT (negative = down).
--
-- Returns:
--   table - Widget interface with:
--     - container (Frame): The container frame holding input and keyword rows
--     - rebuild (function): Function to rebuild the keyword list
--     - getHeight (function): Returns the current total height
-- ============================================================================
function RenderKeywordList(parent, panel, item, x, y)
  local hr, hg, hb = DBB2:GetHighlightColor()
  local rowHeight = DBB2:ScaleSize(22)
  local inputHeight = DBB2:ScaleSize(SPACING.inputHeight)
  local spacing = DBB2:ScaleSize(5)
  
  local container = CreateFrame("Frame", nil, parent)
  container:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  container:SetPoint("RIGHT", parent, "RIGHT", -DBB2:ScaleSize(SPACING.padding), 0)
  container:SetHeight(1)
  
  panel.keywordRows = {}
  local totalHeight = inputHeight + spacing  -- Minimum (input row)
  
  -- Input row
  local inputRow = CreateFrame("Frame", nil, container)
  inputRow:SetHeight(inputHeight)
  inputRow:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
  inputRow:SetPoint("RIGHT", container, "RIGHT", 0, 0)
  
  local keywordInput = CreateConfigInput(nil, inputRow)
  keywordInput:SetPoint("TOPLEFT", inputRow, "TOPLEFT", 0, 0)
  keywordInput:SetPoint("RIGHT", inputRow, "RIGHT", -DBB2:ScaleSize(5), 0)  -- Match category tags spacing
  keywordInput:SetHeight(inputHeight)
  
  keywordInput.placeholder = keywordInput:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  keywordInput.placeholder:SetFont("Fonts\\FRIZQT__.TTF", DBB2:GetFontSize(FONT_SIZE_INPUT))
  keywordInput.placeholder:SetPoint("LEFT", DBB2:ScaleSize(6), 0)
  keywordInput.placeholder:SetText("Enter keyword and press Enter...")
  keywordInput.placeholder:SetTextColor(0.4, 0.4, 0.4, 1)
  
  keywordInput:SetScript("OnEditFocusGained", function() this.placeholder:Hide() end)
  keywordInput:SetScript("OnEditFocusLost", function()
    if this:GetText() == "" then this.placeholder:Show() end
  end)
  
  -- Pattern descriptions
  local patternDescriptions = {
    ["<*>"] = "<Guild Name>", ["\\[??\\]"] = "[pl], [it]", ["\\[???\\]"] = "[pol], [ita]",
    ["recruit*"] = "recruit, recruiting", ["recrut*"] = "recrut, recrute"
  }
  
  local function CreateKeywordRow(index)
    local row = CreateFrame("Frame", nil, container)
    row:SetHeight(rowHeight)
    
    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.name:SetFont("Fonts\\FRIZQT__.TTF", DBB2:GetFontSize(FONT_SIZE))
    row.name:SetPoint("LEFT", DBB2:ScaleSize(5), 0)
    row.name:SetWidth(DBB2:ScaleSize(180))
    row.name:SetJustifyH("LEFT")
    row.name:SetTextColor(1, 1, 1, 1)
    
    row.desc = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.desc:SetFont("Fonts\\FRIZQT__.TTF", DBB2:GetFontSize(FONT_SIZE_SMALL))
    row.desc:SetJustifyH("RIGHT")
    row.desc:SetTextColor(0.5, 0.5, 0.5, 1)
    
    row.removeBtn = CreateFrame("Button", nil, row)
    row.removeBtn:SetWidth(DBB2:ScaleSize(16))
    row.removeBtn:SetHeight(DBB2:ScaleSize(16))
    row.removeBtn:SetPoint("RIGHT", -DBB2:ScaleSize(5), 0)
    
    row.desc:SetPoint("RIGHT", row.removeBtn, "LEFT", -DBB2:ScaleSize(8), 0)
    
    row.removeBtn.text = row.removeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.removeBtn.text:SetFont("Fonts\\FRIZQT__.TTF", DBB2:GetFontSize(FONT_SIZE_LARGE))
    row.removeBtn.text:SetPoint("CENTER", 0, 0)
    row.removeBtn.text:SetText("x")
    row.removeBtn.text:SetTextColor(1, 0.3, 0.3, 1)
    
    row.removeBtn:SetScript("OnEnter", function() this.text:SetTextColor(1, 0.5, 0.5, 1) end)
    row.removeBtn:SetScript("OnLeave", function() this.text:SetTextColor(1, 0.3, 0.3, 1) end)
    
    return row
  end
  
  local function RebuildKeywords()
    -- Hide existing rows
    for _, row in ipairs(panel.keywordRows) do
      row:Hide()
    end
    
    local keywords = DBB2.api.GetBlacklistedKeywords()
    if not keywords then
      totalHeight = inputHeight + spacing
      container:SetHeight(totalHeight)
      return
    end
    
    local currentY = -(inputHeight + spacing)
    
    for i, keyword in ipairs(keywords) do
      local row = panel.keywordRows[i]
      if not row then
        row = CreateKeywordRow(i)
        panel.keywordRows[i] = row
      end
      
      row:ClearAllPoints()
      row:SetPoint("TOPLEFT", container, "TOPLEFT", 0, currentY)
      row:SetPoint("RIGHT", container, "RIGHT", 0, 0)
      row:Show()
      
      row.value = keyword
      row.name:SetText(keyword)
      row.desc:SetText(patternDescriptions[keyword] or "")
      
      local keywordToRemove = keyword
      row.removeBtn:SetScript("OnClick", function()
        DBB2.api.RemoveKeywordFromBlacklist(keywordToRemove)
        RebuildKeywords()
        if panel.RebuildDynamicContent then panel.RebuildDynamicContent() end
      end)
      
      currentY = currentY - rowHeight
    end
    
    local kwCount = 0
    for _ in ipairs(keywords) do kwCount = kwCount + 1 end
    
    totalHeight = inputHeight + spacing + (kwCount * rowHeight)
    if totalHeight < inputHeight + spacing then
      totalHeight = inputHeight + spacing
    end
    container:SetHeight(totalHeight)
  end
  
  local function AddKeyword()
    local kw = keywordInput:GetText()
    if kw and kw ~= "" then
      DBB2.api.AddKeywordToBlacklist(kw)
      keywordInput:SetText("")
      keywordInput.placeholder:Show()
      RebuildKeywords()
      if panel.RebuildDynamicContent then panel.RebuildDynamicContent() end
    end
  end
  
  keywordInput:SetScript("OnEnterPressed", function()
    AddKeyword()
    this:ClearFocus()
  end)
  
  RebuildKeywords()
  
  return {
    container = container,
    rebuild = RebuildKeywords,
    getHeight = function() return totalHeight end
  }
end
