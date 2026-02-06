-- DBB2 Tooltip API
-- Centralized tooltip system for consistent styling across the addon

-- Localize frequently used globals for performance
local table_getn = table.getn
local ipairs = ipairs
local type = type
local math_min = math.min
local math_max = math.max

-- [ InitTooltip ]
-- Creates the shared tooltip frame
function DBB2.api.InitTooltip()
  if DBB2.tooltip then return DBB2.tooltip end
  
  local tooltip = CreateFrame("Frame", "DBB2Tooltip", UIParent)
  tooltip:SetFrameStrata("TOOLTIP")
  tooltip:SetFrameLevel(100)
  tooltip:Hide()
  
  -- Create backdrop matching main GUI (but use fixed color, not configurable)
  DBB2:CreateBackdrop(tooltip, nil, nil, 0.95, true)
  
  -- Lines storage
  tooltip.lines = {}
  tooltip.maxLines = 20
  
  -- Pre-create line font strings
  for i = 1, tooltip.maxLines do
    local line = tooltip:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    line:SetJustifyH("LEFT")
    line:Hide()
    tooltip.lines[i] = line
  end
  
  DBB2.tooltip = tooltip
  return tooltip
end

-- [ ShowTooltip ]
-- Shows a tooltip with multiple lines
-- owner:   [frame]   the frame to anchor to
-- anchor:  [string]  anchor position ("RIGHT", "LEFT", "TOP", "BOTTOM", "CURSOR")
-- lines:   [table]   array of lines, each can be:
--                    - string: white text
--                    - {text}: white text
--                    - {text, r, g, b}: colored text
--                    - {text, "highlight"}: uses highlight color
--                    - {text, "gray"}: uses gray color
function DBB2.api.ShowTooltip(owner, anchor, lines)
  -- Guard against nil parameters
  if not lines or table_getn(lines) == 0 then return end
  
  local tooltip = DBB2.api.InitTooltip()
  
  -- Hide all lines first
  for i = 1, tooltip.maxLines do
    tooltip.lines[i]:Hide()
  end
  
  local padding = DBB2:ScaleSize(8)
  local spacing = DBB2:ScaleSize(2)
  local fontSize = DBB2:GetFontSize(10)
  local hr, hg, hb = DBB2:GetHighlightColor()
  local maxWidth = 0
  local totalHeight = padding
  
  -- Process lines
  for i, lineData in ipairs(lines) do
    if i > tooltip.maxLines then break end
    
    local text, r, g, b
    
    if type(lineData) == "string" then
      text = lineData
      r, g, b = 1, 1, 1
    elseif type(lineData) == "table" then
      text = lineData[1]
      if lineData[2] == "highlight" then
        r, g, b = hr, hg, hb
      elseif lineData[2] == "gray" then
        r, g, b = 0.5, 0.5, 0.5
      elseif type(lineData[2]) == "number" then
        r, g, b = lineData[2], lineData[3] or 1, lineData[4] or 1
      else
        r, g, b = 1, 1, 1
      end
    else
      text = ""
      r, g, b = 1, 1, 1
    end
    
    local line = tooltip.lines[i]
    line:SetFont("Fonts\\FRIZQT__.TTF", fontSize)
    line:SetText(text or "")
    line:SetTextColor(r, g, b, 1)
    line:ClearAllPoints()
    
    if i == 1 then
      line:SetPoint("TOPLEFT", tooltip, "TOPLEFT", padding, -padding)
    else
      line:SetPoint("TOPLEFT", tooltip.lines[i-1], "BOTTOMLEFT", 0, -spacing)
    end
    
    line:Show()
    
    local lineWidth = line:GetStringWidth()
    if lineWidth > maxWidth then
      maxWidth = lineWidth
    end
    totalHeight = totalHeight + line:GetHeight() + spacing
  end
  
  totalHeight = totalHeight + padding - spacing
  
  tooltip:SetWidth(maxWidth + padding * 2)
  tooltip:SetHeight(totalHeight)
  
  -- Position based on anchor
  tooltip:ClearAllPoints()
  anchor = anchor or "CURSOR"
  
  if anchor == "CURSOR" then
    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    x, y = x / scale, y / scale
    tooltip:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x + 15, y + 10)
    
    -- Keep on screen
    local screenWidth = GetScreenWidth()
    local screenHeight = GetScreenHeight()
    local tipWidth = tooltip:GetWidth()
    local tipHeight = tooltip:GetHeight()
    
    if x + 15 + tipWidth > screenWidth then
      tooltip:ClearAllPoints()
      tooltip:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMLEFT", x - 5, y + 10)
    end
    if y + 10 + tipHeight > screenHeight then
      tooltip:ClearAllPoints()
      tooltip:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x + 15, y - 5)
    end
  elseif anchor == "RIGHT" and owner then
    tooltip:SetPoint("LEFT", owner, "RIGHT", 5, 0)
  elseif anchor == "LEFT" and owner then
    tooltip:SetPoint("RIGHT", owner, "LEFT", -5, 0)
  elseif anchor == "TOP" and owner then
    tooltip:SetPoint("BOTTOM", owner, "TOP", 0, 5)
  elseif anchor == "BOTTOM" and owner then
    tooltip:SetPoint("TOP", owner, "BOTTOM", 0, -5)
  elseif owner then
    -- Default: top-right of owner
    tooltip:SetPoint("BOTTOMLEFT", owner, "TOPRIGHT", 5, 5)
  else
    -- Fallback to cursor position if no owner
    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    x, y = x / scale, y / scale
    tooltip:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x + 15, y + 10)
  end
  
  tooltip:Show()
end

-- [ HideTooltip ]
-- Hides the tooltip
function DBB2.api.HideTooltip()
  if DBB2.tooltip then
    DBB2.tooltip:Hide()
  end
end

-- [ ShowMessageTooltip ]
-- Shows a tooltip for message display (sender + message)
-- owner:   [frame]   the frame that triggered the tooltip
-- sender:  [string]  sender name (shown in highlight color)
-- message: [string]  message text
function DBB2.api.ShowMessageTooltip(owner, sender, message)
  local tooltip = DBB2.api.InitTooltip()
  
  -- Hide all lines first
  for i = 1, tooltip.maxLines do
    tooltip.lines[i]:Hide()
  end
  
  local padding = DBB2:ScaleSize(8)
  local spacing = DBB2:ScaleSize(4)
  local fontSize = DBB2:GetFontSize(10)
  local hr, hg, hb = DBB2:GetHighlightColor()
  local maxWidth = DBB2:ScaleSize(350)
  
  -- Guard against nil values
  sender = sender or "Unknown"
  message = message or ""
  
  -- Title (sender)
  local titleLine = tooltip.lines[1]
  titleLine:SetFont("Fonts\\FRIZQT__.TTF", fontSize)
  titleLine:SetText(sender)
  titleLine:SetTextColor(hr, hg, hb, 1)
  titleLine:ClearAllPoints()
  titleLine:SetPoint("TOPLEFT", tooltip, "TOPLEFT", padding, -padding)
  titleLine:Show()
  
  -- Message
  local msgLine = tooltip.lines[2]
  msgLine:SetFont("Fonts\\FRIZQT__.TTF", fontSize)
  msgLine:SetWidth(maxWidth)
  msgLine:SetText(message)
  msgLine:SetTextColor(0.9, 0.9, 0.9, 1)
  msgLine:ClearAllPoints()
  msgLine:SetPoint("TOPLEFT", titleLine, "BOTTOMLEFT", 0, -spacing)
  msgLine:Show()
  
  -- Calculate size
  local textWidth = math_min(msgLine:GetStringWidth(), maxWidth)
  local titleWidth = titleLine:GetStringWidth()
  local tooltipWidth = math_max(textWidth, titleWidth) + (padding * 2)
  local tooltipHeight = titleLine:GetHeight() + msgLine:GetHeight() + spacing + (padding * 2)
  
  tooltip:SetWidth(tooltipWidth)
  tooltip:SetHeight(tooltipHeight)
  
  -- Position near cursor
  local x, y = GetCursorPosition()
  local scale = UIParent:GetEffectiveScale()
  x, y = x / scale, y / scale
  
  tooltip:ClearAllPoints()
  tooltip:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x + 15, y + 10)
  
  -- Keep on screen
  local screenWidth = GetScreenWidth()
  local screenHeight = GetScreenHeight()
  
  if x + 15 + tooltipWidth > screenWidth then
    tooltip:ClearAllPoints()
    tooltip:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMLEFT", x - 5, y + 10)
  end
  if y + 10 + tooltipHeight > screenHeight then
    tooltip:ClearAllPoints()
    tooltip:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x + 15, y - 5)
  end
  
  -- Store state for message tooltips (used by message rows)
  tooltip.activeData = {sender = sender, message = message}
  tooltip.triggerFrame = owner
  
  tooltip:Show()
end

-- [ ShouldDismissTooltip ]
-- Check if tooltip should be dismissed
-- Returns false if mouse is still over the trigger frame
function DBB2.api.ShouldDismissTooltip()
  local tooltip = DBB2.tooltip
  if not tooltip or not tooltip.activeData then return true end
  
  -- Keep visible if mouse is still over the trigger frame
  if tooltip.triggerFrame and MouseIsOver(tooltip.triggerFrame) then
    return false
  end
  
  -- Mouse is elsewhere, dismiss
  return true
end

-- [ DismissMessageTooltip ]
-- Dismisses message tooltip and clears state
function DBB2.api.DismissMessageTooltip()
  local tooltip = DBB2.tooltip
  if tooltip then
    tooltip.activeData = nil
    tooltip.triggerFrame = nil
    tooltip:Hide()
  end
end

-- [ GetTooltipActiveData ]
-- Returns the active message tooltip data (if any)
function DBB2.api.GetTooltipActiveData()
  if DBB2.tooltip then
    return DBB2.tooltip.activeData
  end
  return nil
end
