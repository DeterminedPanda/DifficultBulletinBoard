-- DBB2 Config Widgets
-- Complex list widgets for config panels
-- Depends on: env/constants.lua, env/tables.lua, api/config_schema.lua

-- Localize frequently used globals for performance
local string_gfind = string.gfind
local string_gsub = string.gsub
local table_insert = table.insert
local table_getn = table.getn
local ipairs = ipairs

-- Local references to env constants (for performance)
local SPACING = DBB2.env.SPACING
local FONT_SIZE = DBB2.env.FONT_SIZE
local FONT_SIZE_INPUT = DBB2.env.FONT_SIZE_INPUT
local FONT_SIZE_SMALL = DBB2.env.FONT_SIZE_SMALL
local FONT_SIZE_LARGE = DBB2.env.FONT_SIZE_LARGE
local SECTION_FONT_SIZE = DBB2.env.SECTION_FONT_SIZE


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
  
  -- Use channel descriptions from env/tables.lua
  local channelDescriptions = DBB2.env.channelDescriptions
  
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
  
  -- Use pattern descriptions from env/tables.lua
  local patternDescriptions = DBB2.env.patternDescriptions
  
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
