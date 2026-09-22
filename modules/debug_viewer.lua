-- Command-only diagnostic viewer. Nothing is added to the regular DBB UI.

local table_getn = table.getn
local table_insert = table.insert
local string_find = string.find
local string_gsub = string.gsub
local string_gfind = string.gfind
local string_lower = string.lower
local string_len = string.len
local math_max = math.max
local math_ceil = math.ceil

-- Vanilla EditBoxes become unreliable with very large text buffers and tall
-- children. Render a bounded page while retaining the full diagnostic recorder.
local PAGE_SIZE = 50
local APPROX_CHARS_PER_LINE = 100
-- Increment this only when the TSV columns or their meaning changes.
local DIAGNOSTIC_TSV_SCHEMA_VERSION = "1"
local DIAGNOSTIC_EXPORT_BASENAME = "DifficultBulletinBoard_Diagnostics"
local SUPERWOW_DOWNLOAD_URL = "https://github.com/balakethelock/SuperWoW/releases/"

local levelFilters = {
  { label = "All levels", value = 1 },
  { label = "Info+", value = 2 },
  { label = "Warnings+", value = 3 },
  { label = "Errors", value = 4 }
}

local categoryFilters = { "all", "message", "event", "chat", "notify", "performance", "ui", "lua-error", "test", "system" }

-- Matches pfUI's compatibility check for both current and older SuperWoW
-- installations. ExportFile is required because diagnostics use it to write
-- a dedicated text file instead of relying on the EditBox clipboard export.
function DBB2.api.HasSuperWoWDiagnostics()
  local hasSuperWoW = SUPERWOW_VERSION or (SetAutoloot and SpellInfo)
  return hasSuperWoW and type(ExportFile) == "function"
end

function DBB2:ShowSuperWoWDiagnosticsRequirement()
  if not DEFAULT_CHAT_FRAME then return end
  DEFAULT_CHAT_FRAME:AddMessage("|cffffaa00DBB diagnostics requires SuperWoW.|r Install or update it, then restart the game.")
  DEFAULT_CHAT_FRAME:AddMessage("|cff66ddffDownload:|r " .. SUPERWOW_DOWNLOAD_URL)
end

local function CreateButton(parent, text, width, clickHandler)
  local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  button:SetWidth(width)
  button:SetHeight(22)
  button:SetText(text)
  button:SetScript("OnClick", clickHandler)
  return button
end

local function EntryMatches(viewer, entry)
  local level = levelFilters[viewer.levelFilterIndex].value
  if (entry.level or 1) < level then return false end

  local category = categoryFilters[viewer.categoryFilterIndex]
  if category ~= "all" and entry.category ~= category then return false end

  local search = string_lower(viewer.searchText or "")
  if search ~= "" then
    local haystack = string_lower((entry.category or "") .. " " .. (entry.action or "") .. " " .. (entry.details or ""))
    if not string_find(haystack, search, 1, true) then return false end
  end
  return true
end

local function ApproximateVisualLines(lines)
  local visualLines = 0
  for _, line in ipairs(lines) do
    visualLines = visualLines + math_max(1, math_ceil(string_len(line or "") / APPROX_CHARS_PER_LINE))
  end
  return visualLines
end

local function ScrollToNewest(viewer, force)
  if (viewer.pageOffset ~= 0 or DBB2.debug.paused) and not force then return end

  -- Vanilla recalculates a ScrollFrame's range after its child changes size.
  -- Update both the frame and template scrollbar so the scrollbar cannot
  -- restore the previous position on the following frame.
  viewer.scroll:UpdateScrollChildRect()

  local scrollRange = math_max(0, viewer.log:GetHeight() - viewer.scroll:GetHeight())
  if viewer.scroll.GetVerticalScrollRange then
    local calculatedRange = viewer.scroll:GetVerticalScrollRange()
    if calculatedRange and calculatedRange > scrollRange then
      scrollRange = calculatedRange
    end
  end

  viewer.scroll:SetVerticalScroll(scrollRange)

  local scrollBar = getglobal(viewer.scroll:GetName() .. "ScrollBar")
  if scrollBar then
    scrollBar:SetValue(scrollRange)
    viewer.scroll:SetVerticalScroll(scrollRange)
  end
end

local function RebuildMatchingEntries(viewer)
  viewer.matchingEntries = {}
  viewer.matchingStart = 1
  for _, entry in ipairs(DBB2.api.DebugGetEntries()) do
    if EntryMatches(viewer, entry) then
      table_insert(viewer.matchingEntries, entry)
    end
  end
  viewer.matchingLastSequence = DBB2.debug.sequence or 0
  viewer.matchingDirty = false
end

local function CompactMatchingEntries(viewer)
  local entries = viewer.matchingEntries
  local first = viewer.matchingStart or 1
  if first <= 100 or first * 2 <= table_getn(entries) then return end

  local compacted = {}
  for index = first, table_getn(entries) do
    table_insert(compacted, entries[index])
  end
  viewer.matchingEntries = compacted
  viewer.matchingStart = 1
end

-- Live refreshes receive only the traces recorded since the previous refresh.
-- A complete scan is reserved for opening, clearing, and changing a filter or
-- search term.  Export intentionally remains a full one-shot snapshot.
local function SyncMatchingEntries(viewer)
  local latestSequence = DBB2.debug.sequence or 0
  if viewer.matchingDirty or not viewer.matchingEntries or (viewer.matchingLastSequence or 0) > latestSequence then
    RebuildMatchingEntries(viewer)
    return
  end

  if (viewer.matchingLastSequence or 0) == latestSequence then return end

  local additions, complete, oldestSequence = DBB2.api.DebugGetEntriesSince(viewer.matchingLastSequence or 0)
  if not complete then
    RebuildMatchingEntries(viewer)
    return
  end

  local entries = viewer.matchingEntries
  local first = viewer.matchingStart or 1
  while first <= table_getn(entries) and entries[first].sequence < oldestSequence do
    first = first + 1
  end
  viewer.matchingStart = first

  for _, entry in ipairs(additions) do
    if EntryMatches(viewer, entry) then
      table_insert(entries, entry)
    end
  end
  viewer.matchingLastSequence = latestSequence
  CompactMatchingEntries(viewer)
end

local function RefreshViewer(viewer, force)
  if not force and not DBB2.debug.dirty then return end
  -- With no Tail toggle, fresh diagnostic activity always returns to the newest
  -- page. Manual Older/Newer clicks can still inspect history between updates.
  if not force and viewer.pageOffset > 0 then viewer.pageOffset = 0 end
  local refreshStarted = DBB2.api.DebugClock()

  local lines = {}

  SyncMatchingEntries(viewer)
  local matchingEntries = viewer.matchingEntries
  local matchingStart = viewer.matchingStart or 1

  local visibleCount = math_max(0, table_getn(matchingEntries) - matchingStart + 1)
  local totalPages = math_max(1, math_ceil(visibleCount / PAGE_SIZE))
  if viewer.pageOffset >= totalPages then viewer.pageOffset = totalPages - 1 end

  local pageEnd = visibleCount - (viewer.pageOffset * PAGE_SIZE)
  local pageStart = math_max(1, pageEnd - PAGE_SIZE + 1)
  if visibleCount == 0 then
    pageStart = 0
    pageEnd = 0
  else
    for i = pageStart, pageEnd do
      table_insert(lines, DBB2.api.DebugFormatEntry(matchingEntries[matchingStart + i - 1]))
    end
  end

  local text = table.concat(lines, "\n")
  viewer.log:SetText(text)
  viewer.log:SetHeight(math_max(324, ApproximateVisualLines(lines) * 12 + 18))
  viewer.totalPages = totalPages
  viewer.result:SetText(visibleCount .. " matches  ||  showing " .. pageStart .. "-" .. pageEnd .. "  ||  page " .. (totalPages - viewer.pageOffset) .. "/" .. totalPages)
  if viewer.olderButton then
    if viewer.pageOffset < totalPages - 1 then viewer.olderButton:Enable() else viewer.olderButton:Disable() end
    if viewer.pageOffset > 0 then viewer.newerButton:Enable() else viewer.newerButton:Disable() end
  end
  local recorderState = DBB2.debug.capacityReached and "FULL  ||  " or (DBB2.debug.paused and "PAUSED  ||  " or "CAPTURING  ||  ")
  viewer.status:SetText(recorderState .. DBB2.api.DebugGetLiveSummary())
  if DBB2.debug.capacityReached then
    viewer.pauseButton:SetText("Full")
    viewer.pauseButton:Disable()
    if viewer.testButton then viewer.testButton:Disable() end
  else
    viewer.pauseButton:SetText(DBB2.debug.paused and "Resume" or "Pause")
    viewer.pauseButton:Enable()
    if viewer.testButton then viewer.testButton:Enable() end
  end
  DBB2.debug.dirty = false

  if viewer.pageOffset == 0 and not DBB2.debug.paused then
    ScrollToNewest(viewer)
    -- Repeat after Vanilla's deferred scroll-range/layout update. Two frames
    -- covers both the child rect and UIPanelScrollFrameTemplate scrollbar.
    viewer.pendingTailFrames = 2
    viewer.forcePendingTail = false
  end
  DBB2.api.DebugPerf("diagnostic.console-refresh", DBB2.api.DebugClock() - refreshStarted, nil, true)
  -- Recording this self-measurement must not trigger an idle refresh loop.
  DBB2.debug.dirty = false
end

local function EscapeTSV(value)
  local text = tostring(value or "")
  text = string_gsub(text, "\\", "\\\\")
  text = string_gsub(text, "\r", "\\r")
  text = string_gsub(text, "\n", "\\n")
  return string_gsub(text, "\t", "\\t")
end

local function TSVRow(fields)
  local escaped = {}
  for index, value in ipairs(fields) do
    escaped[index] = EscapeTSV(value)
  end
  return table.concat(escaped, "\t")
end

local function BuildDiagnosticExportText()
  local exportStarted = DBB2.api.DebugClock()
  local entries = DBB2.api.DebugGetEntries()
  local exportLines = {
    "schema_version\trecord_type\tsequence\tsession_time_seconds\tlevel\tlevel_name\tcategory\taction\telapsed_ms\tmetadata_key\tmetadata_value\tdetails"
  }
  local function AddMetadata(row)
    table_insert(exportLines, TSVRow({
      DIAGNOSTIC_TSV_SCHEMA_VERSION,
      "metadata",
      "", "", "", "", "", "", "",
      row.key,
      row.value,
      ""
    }))
  end

  -- The chronological log begins immediately after the schema header. Its
  -- session-start configuration snapshot is the only prose configuration
  -- record; exact export-time settings remain in the structured appendix.
  local configurationRows = DBB2.api.DebugGetConfigurationExportRows()
  for _, entry in ipairs(entries) do
    table_insert(exportLines, TSVRow({
      DIAGNOSTIC_TSV_SCHEMA_VERSION,
      "entry",
      entry.sequence,
      entry.sessionTime,
      entry.level,
      entry.levelName,
      entry.category,
      entry.action,
      -- Lua 5.0 ipairs stops at a nil array slot. Keep this column explicit so
      -- untimed entries still export their metadata and details columns.
      entry.elapsedMS or "",
      "",
      "",
      entry.details or ""
    }))
  end

  for _, telemetryRow in ipairs(DBB2.api.DebugGetTelemetryExportRows()) do
    AddMetadata(telemetryRow)
  end

  -- Capture settings when Export is clicked, not only when the diagnostic
  -- viewer was opened. These rows contain the exact rules needed to reproduce
  -- matching decisions plus live state that is not stored in SavedVariables.
  for _, configRow in ipairs(configurationRows) do
    AddMetadata(configRow)
  end

  -- Keep the exact settings that produced the latest simulation even if the
  -- user changes options before exporting the diagnostic log.
  if DBB2.api.DebugGetSimulationConfigurationExportRows then
    for _, configRow in ipairs(DBB2.api.DebugGetSimulationConfigurationExportRows()) do
      AddMetadata(configRow)
    end
  end

  DBB2.api.DebugPerf("diagnostic.export-construction", DBB2.api.DebugClock() - exportStarted, nil, true)
  return table.concat(exportLines, "\n") .. "\n"
end

local function BuildDiagnosticExportFilename()
  -- Colons are not valid in Windows filenames. The per-second suffix keeps the
  -- saved files easy to sort chronologically, and the counter prevents a
  -- second export in the same second from replacing the first one.
  local timestamp = date("%Y-%m-%d_%H-%M-%S")
  if DBB2.debug.lastExportTimestamp ~= timestamp then
    DBB2.debug.lastExportTimestamp = timestamp
    DBB2.debug.exportSequence = 0
  end
  DBB2.debug.exportSequence = (DBB2.debug.exportSequence or 0) + 1
  return DIAGNOSTIC_EXPORT_BASENAME .. "_" .. timestamp .. "_" .. DBB2.debug.exportSequence
end

local function ExportDiagnostics()
  local exportText = BuildDiagnosticExportText()
  local filename = BuildDiagnosticExportFilename()
  local exported, exportError = pcall(ExportFile, filename, exportText)
  if not exported then
    DEFAULT_CHAT_FRAME:AddMessage("|cffff4444DBB diagnostics could not be exported:|r " .. tostring(exportError))
    return
  end
  DEFAULT_CHAT_FRAME:AddMessage("|cff66ddffDBB diagnostics exported:|r imports\\" .. filename .. ".txt")
end

local function CreateViewer()
  local viewer = CreateFrame("Frame", "DBB2DebugViewer", UIParent)
  -- 805px fits the streamlined controls, log, simulator, and scrollbars while
  -- leaving room for both control rows.
  viewer:SetWidth(805)
  viewer:SetHeight(540)
  viewer:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  viewer:SetFrameStrata("DIALOG")
  viewer:SetMovable(true)
  viewer:EnableMouse(true)
  viewer:RegisterForDrag("LeftButton")
  viewer:SetScript("OnDragStart", function() this:StartMoving() end)
  viewer:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
  viewer:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
  })
  viewer:SetBackdropColor(0.03, 0.03, 0.04, 0.98)
  viewer:SetBackdropBorderColor(0.55, 0.52, 0.75, 1)

  viewer.levelFilterIndex = 1
  viewer.categoryFilterIndex = 1
  viewer.searchText = ""
  viewer.pendingTailFrames = 0
  viewer.forcePendingTail = false
  viewer.pageOffset = 0
  viewer.totalPages = 1
  viewer.elapsed = 0

  viewer.title = viewer:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  viewer.title:SetPoint("TOPLEFT", viewer, "TOPLEFT", 14, -12)
  viewer.title:SetText("DBB Diagnostic Console")

  viewer.close = CreateFrame("Button", nil, viewer, "UIPanelCloseButton")
  viewer.close:SetPoint("TOPRIGHT", viewer, "TOPRIGHT", -4, -4)

  viewer.status = viewer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  viewer.status:SetPoint("TOPLEFT", viewer, "TOPLEFT", 14, -38)
  viewer.status:SetPoint("RIGHT", viewer, "RIGHT", -14, 0)
  viewer.status:SetJustifyH("LEFT")

  viewer.levelButton = CreateButton(viewer, levelFilters[1].label, 92, function()
    viewer.levelFilterIndex = viewer.levelFilterIndex + 1
    if viewer.levelFilterIndex > table_getn(levelFilters) then viewer.levelFilterIndex = 1 end
    viewer.pageOffset = 0
    viewer.matchingDirty = true
    this:SetText(levelFilters[viewer.levelFilterIndex].label)
    RefreshViewer(viewer, true)
  end)
  viewer.levelButton:SetPoint("TOPLEFT", viewer, "TOPLEFT", 12, -58)

  viewer.categoryButton = CreateButton(viewer, "Category: all", 116, function()
    viewer.categoryFilterIndex = viewer.categoryFilterIndex + 1
    if viewer.categoryFilterIndex > table_getn(categoryFilters) then viewer.categoryFilterIndex = 1 end
    viewer.pageOffset = 0
    viewer.matchingDirty = true
    this:SetText("Category: " .. categoryFilters[viewer.categoryFilterIndex])
    RefreshViewer(viewer, true)
  end)
  viewer.categoryButton:SetPoint("LEFT", viewer.levelButton, "RIGHT", 5, 0)

  viewer.pauseButton = CreateButton(viewer, "Pause", 65, function()
    if DBB2.debug.capacityReached then return end
    DBB2.debug.paused = not DBB2.debug.paused
    DBB2.debug.dirty = true
    RefreshViewer(viewer, true)
  end)
  viewer.pauseButton:SetPoint("LEFT", viewer.categoryButton, "RIGHT", 5, 0)

  viewer.clearButton = CreateButton(viewer, "Clear", 58, function()
    DBB2.api.DebugClear()
    viewer.pageOffset = 0
    RefreshViewer(viewer, true)
  end)
  viewer.clearButton:SetPoint("LEFT", viewer.pauseButton, "RIGHT", 5, 0)

  viewer.exportButton = CreateButton(viewer, "Export to file", 118, ExportDiagnostics)
  viewer.exportButton:SetPoint("LEFT", viewer.clearButton, "RIGHT", 5, 0)

  viewer.searchLabel = viewer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  viewer.searchLabel:SetPoint("LEFT", viewer.exportButton, "RIGHT", 8, 0)
  viewer.searchLabel:SetText("Search")

  viewer.search = CreateFrame("EditBox", "DBB2DebugSearch", viewer, "InputBoxTemplate")
  viewer.search:SetWidth(105)
  viewer.search:SetHeight(20)
  viewer.search:SetPoint("LEFT", viewer.searchLabel, "RIGHT", 7, 0)
  viewer.search:SetAutoFocus(false)
  viewer.search:SetScript("OnTextChanged", function()
    viewer.searchText = this:GetText() or ""
    viewer.pageOffset = 0
    viewer.matchingDirty = true
    RefreshViewer(viewer, true)
  end)
  viewer.search:SetScript("OnEscapePressed", function() this:ClearFocus() end)

  viewer.testLabel = viewer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  viewer.testLabel:SetPoint("TOPLEFT", viewer, "TOPLEFT", 14, -88)
  viewer.testLabel:SetText("Simulate messages (one per line)")

  -- A real scroll frame keeps large pasted corpora usable while reserving at
  -- least three visible text lines in the console layout.
  viewer.testInputScroll = CreateFrame("ScrollFrame", "DBB2DebugTestInputScroll", viewer, "UIPanelScrollFrameTemplate")
  viewer.testInputScroll:SetWidth(645)
  viewer.testInputScroll:SetHeight(58)
  viewer.testInputScroll:SetPoint("TOPLEFT", viewer, "TOPLEFT", 14, -106)
  viewer.testInputScroll:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 }
  })
  viewer.testInputScroll:SetBackdropColor(0.02, 0.02, 0.025, 0.95)
  viewer.testInputScroll:SetBackdropBorderColor(0.45, 0.43, 0.58, 1)

  viewer.testInput = CreateFrame("EditBox", "DBB2DebugTestInput", viewer.testInputScroll)
  viewer.testInput:SetWidth(615)
  viewer.testInput:SetHeight(54)
  viewer.testInput:SetAutoFocus(false)
  viewer.testInput:SetMultiLine(true)
  local testInputFont = getglobal("ChatFontNormal")
  if testInputFont then
    viewer.testInput:SetFontObject(testInputFont)
  else
    viewer.testInput:SetFont("Fonts\\FRIZQT__.TTF", 12)
  end
  viewer.testInput:SetTextColor(0.95, 0.95, 0.95, 1)
  viewer.testInput:SetTextInsets(6, 4, 4, 4)
  viewer.testInput:SetScript("OnEscapePressed", function() this:ClearFocus() end)
  viewer.testInputScroll:SetScrollChild(viewer.testInput)

  local function UpdateTestInputHeight()
    local text = viewer.testInput:GetText() or ""
    local visualLines = 0
    -- Count explicit lines and long lines that wrap inside the fixed-width field.
    for line in string_gfind(text .. "\n", "(.-)\n") do
      visualLines = visualLines + math_max(1, math_ceil(string_len(line) / 72))
    end
    visualLines = math_max(3, visualLines)
    viewer.testInput:SetHeight(visualLines * 14 + 12)
    viewer.testInputScroll:UpdateScrollChildRect()
  end
  viewer.testInput:SetScript("OnTextChanged", UpdateTestInputHeight)
  UpdateTestInputHeight()

  viewer.testInputScroll:EnableMouseWheel(true)
  viewer.testInputScroll:SetScript("OnMouseWheel", function()
    local scrollRange = math_max(0, viewer.testInput:GetHeight() - this:GetHeight())
    local nextOffset = this:GetVerticalScroll() - (arg1 * 28)
    if nextOffset < 0 then nextOffset = 0 end
    if nextOffset > scrollRange then nextOffset = scrollRange end
    this:SetVerticalScroll(nextOffset)
    local scrollBar = getglobal(this:GetName() .. "ScrollBar")
    if scrollBar then scrollBar:SetValue(nextOffset) end
  end)

  local function AnalyzeTestMessages()
    if DBB2.debug.capacityReached then return end
    local messages = viewer.testInput:GetText() or ""
    if messages ~= "" then
      DBB2.api.DebugAnalyzeBatch(messages)
      viewer.categoryFilterIndex = 1
      viewer.pageOffset = 0
      viewer.matchingDirty = true
      viewer.categoryButton:SetText("Category: all")
      viewer.searchText = ""
      viewer.search:SetText("")
      RefreshViewer(viewer, true)
      -- Pause stops live capture, not deliberate simulations. Reveal the fresh
      -- results without changing the user's paused or follow-tail settings.
      ScrollToNewest(viewer, true)
      viewer.pendingTailFrames = 2
      viewer.forcePendingTail = true
    end
  end

  viewer.testButton = CreateButton(viewer, "Simulate batch", 90, AnalyzeTestMessages)
  -- UIPanelScrollFrameTemplate places its scrollbar along the right edge, so
  -- leave a dedicated gutter before the action button.
  viewer.testButton:SetPoint("LEFT", viewer.testInputScroll, "RIGHT", 24, 0)

  viewer.scroll = CreateFrame("ScrollFrame", "DBB2DebugScroll", viewer, "UIPanelScrollFrameTemplate")
  viewer.scroll:SetPoint("TOPLEFT", viewer, "TOPLEFT", 14, -178)
  viewer.scroll:SetPoint("BOTTOMRIGHT", viewer, "BOTTOMRIGHT", -31, 34)

  viewer.log = CreateFrame("EditBox", "DBB2DebugLog", viewer.scroll)
  viewer.log:SetWidth(749)
  viewer.log:SetHeight(324)
  viewer.log:SetMultiLine(true)
  viewer.log:SetAutoFocus(false)
  viewer.log:EnableMouse(true)
  viewer.log:SetFont("Interface\\AddOns\\DifficultBulletinBoard\\font\\IBMPlexMono-SemiBold.ttf", 10)
  viewer.log:SetTextColor(0.88, 0.88, 0.9, 1)
  viewer.log:SetScript("OnEscapePressed", function() this:ClearFocus() end)
  viewer.scroll:SetScrollChild(viewer.log)

  viewer.result = viewer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  viewer.result:SetPoint("BOTTOMLEFT", viewer, "BOTTOMLEFT", 14, 13)
  viewer.result:SetWidth(310)
  viewer.result:SetJustifyH("LEFT")

  viewer.olderButton = CreateButton(viewer, "Older", 62, function()
    if viewer.pageOffset < viewer.totalPages - 1 then
      viewer.pageOffset = viewer.pageOffset + 1
      RefreshViewer(viewer, true)
      viewer.pendingTailFrames = 0
      viewer.scroll:SetVerticalScroll(0)
      local scrollBar = getglobal(viewer.scroll:GetName() .. "ScrollBar")
      if scrollBar then scrollBar:SetValue(0) end
    end
  end)
  viewer.olderButton:SetPoint("BOTTOM", viewer, "BOTTOM", -35, 7)

  viewer.newerButton = CreateButton(viewer, "Newer", 62, function()
    if viewer.pageOffset > 0 then
      viewer.pageOffset = viewer.pageOffset - 1
      RefreshViewer(viewer, true)
      viewer.pendingTailFrames = 0
      viewer.scroll:SetVerticalScroll(0)
      local scrollBar = getglobal(viewer.scroll:GetName() .. "ScrollBar")
      if scrollBar then scrollBar:SetValue(0) end
    end
  end)
  viewer.newerButton:SetPoint("LEFT", viewer.olderButton, "RIGHT", 8, 0)

  viewer:SetScript("OnUpdate", function()
    if this.pendingTailFrames and this.pendingTailFrames > 0 then
      ScrollToNewest(this, this.forcePendingTail)
      this.pendingTailFrames = this.pendingTailFrames - 1
      if this.pendingTailFrames == 0 then this.forcePendingTail = false end
    end

    this.elapsed = this.elapsed + arg1
    if this.elapsed >= 0.25 then
      this.elapsed = 0
      RefreshViewer(this, false)
    end
  end)
  viewer:SetScript("OnShow", function()
    DBB2.debug.dirty = true
    RefreshViewer(this, true)
  end)
  viewer:SetScript("OnHide", function()
    this.log:SetText("")
    this.log:SetHeight(390)
    DBB2.api.DebugStop()
  end)
  viewer:Hide()
  return viewer
end

function DBB2:ToggleDebugViewer(showOnly)
  if not DBB2.api.HasSuperWoWDiagnostics() then
    DBB2:ShowSuperWoWDiagnosticsRequirement()
    return
  end
  if not self.debug.viewer then self.debug.viewer = CreateViewer() end
  local viewer = self.debug.viewer
  if showOnly or not viewer:IsShown() then
    DBB2.api.DebugStart()
    DBB2.api.DebugCaptureSnapshot("viewer-opened")
    viewer:Show()
  else
    viewer:Hide()
  end
end
