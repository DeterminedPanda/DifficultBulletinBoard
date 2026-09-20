-- DBB2 diagnostic recorder
-- Kept independent of the normal GUI. The viewer is created lazily by
-- modules/debug_viewer.lua and can only be opened with /dbb debug.

DBB2.debug = DBB2.debug or {}

local debugState = DBB2.debug
local table_insert = table.insert
local table_remove = table.remove
local table_getn = table.getn
local table_sort = table.sort
local string_format = string.format
local string_gsub = string.gsub
local string_lower = string.lower
local string_find = string.find
local string_gfind = string.gfind
local string_len = string.len
local string_sub = string.sub
local tostring = tostring
local type = type
local pairs = pairs
local ipairs = ipairs
local pcall = pcall
local math_floor = math.floor

debugState.entries = debugState.entries or {}
debugState.entryStart = debugState.entryStart or 1
debugState.entryCount = debugState.entryCount or 0
debugState.counters = debugState.counters or {}
debugState.perf = debugState.perf or {}
debugState.sequence = debugState.sequence or 0
debugState.maxEntries = debugState.maxEntries or 500
debugState.enabled = false
debugState.paused = false
debugState.startTime = debugState.startTime or GetTime()
debugState.dirty = true
debugState.lastChatTrace = nil
debugState.addonMemoryKB = nil
debugState.lastMemoryUpdate = 0
debugState.luaMemoryStartKB = debugState.luaMemoryStartKB or 0
debugState.messageSequence = debugState.messageSequence or 0
debugState.messageLifecycles = debugState.messageLifecycles or {}
debugState.messageLifecycleOrder = debugState.messageLifecycleOrder or {}
debugState.perfSampleLimit = debugState.perfSampleLimit or 120
debugState.perfRecentLimit = debugState.perfRecentLimit or 20
debugState.slowThresholds = debugState.slowThresholds or {
  default = 5,
  ["pipeline.logs-tab-redraw"] = 8,
  ["pipeline.categorized-tab-redraw"] = 8,
  ["pipeline.total"] = 10
}
debugState.freezeOnError = true
debugState.currentEvent = debugState.currentEvent or "none"
debugState.currentDiagnosticID = debugState.currentDiagnosticID or nil
debugState.categoryCollisions = debugState.categoryCollisions or {}

local LEVEL_NAMES = { "TRACE", "INFO", "WARN", "ERROR" }

local function ClockMS()
  if debugprofilestop then
    return debugprofilestop()
  end
  return GetTime() * 1000
end

local function SafeText(value, maxLength)
  local text = tostring(value or "")
  text = string_gsub(text, "[\r\n\t]", " ")
  text = string_gsub(text, "|", "||")
  if maxLength and string.len(text) > maxLength then
    text = string.sub(text, 1, maxLength - 3) .. "..."
  end
  return text
end

local function Join(values)
  if not values or not values[1] then return "-" end
  return table.concat(values, ",")
end

-- Formats the detailed match scan in category configuration order.  It is kept
-- here so normal classification stays lean; only diagnostic callers request it.
function DBB2.api.DebugFormatCategoryEvidence(evidenceByType)
  if not evidenceByType then return "-" end
  local typeParts = {}
  for _, categoryType in ipairs({ "groups", "professions", "hardcore" }) do
    local categories = evidenceByType[categoryType] or {}
    local entries = {}
    for _, categoryResult in ipairs(categories) do
      local evidence = categoryResult.evidence or {}
      local via = {}
      for _, tagResult in ipairs(evidence.tags or {}) do
        table_insert(via, "\"" .. tostring(tagResult.tag) .. "\" (" .. tostring(tagResult.kind) .. ")")
      end
      local rejected = {}
      for _, tagResult in ipairs(evidence.rejected or {}) do
        table_insert(rejected, "\"" .. tostring(tagResult.tag) .. "\" (" .. tostring(tagResult.kind) .. ")")
      end
      local filters = {}
      for _, tagResult in ipairs(evidence.filterTags or {}) do
        table_insert(filters, "\"" .. tostring(tagResult.tag) .. "\" (" .. tostring(tagResult.kind) .. ")")
      end
      local description = categoryResult.name
      if via[1] then description = description .. " via " .. table.concat(via, ",") end
      if filters[1] then description = description .. " filter=" .. table.concat(filters, ",") end
      if evidence.filterRejected then description = description .. " filter-tag rejected" end
      if rejected[1] then description = description .. " rejected=" .. table.concat(rejected, ",") end
      table_insert(entries, description)
    end
    if entries[1] then table_insert(typeParts, categoryType .. "=[" .. table.concat(entries, "; ") .. "]") end
  end
  return typeParts[1] and table.concat(typeParts, " ") or "-"
end

function DBB2.api.DebugReportCategoryEvidence(diagnosticID, evidenceByType, phase)
  if not debugState.enabled or not evidenceByType then return end
  for _, categoryType in ipairs({ "groups", "professions", "hardcore" }) do
    for _, categoryResult in ipairs(evidenceByType[categoryType] or {}) do
      local oneCategory = { [categoryType] = { categoryResult } }
      DBB2.api.DebugLifecycleStage(diagnosticID, "category-evidence", "phase=" .. (phase or "full") .. " " .. DBB2.api.DebugFormatCategoryEvidence(oneCategory))
    end
  end
end

-- Keep correlation deliberately small and Lua 5.0-safe.  Chat frame rendering
-- and CHAT_MSG_* delivery may arrive in either order, so records are matched by
-- their normalized visible text and then by sender where possible.
local function NormalizeDiagnosticText(value)
  local text = tostring(value or "")
  text = string_gsub(text, "|c%x%x%x%x%x%x%x%x", "")
  text = string_gsub(text, "|r", "")
  text = string_gsub(text, "|H[^|]*|h([^|]*)|h", "%1")
  text = string_gsub(text, "^%s*(.-)%s*$", "%1")
  return string_lower(text)
end

local function LifecyclePrefix(id)
  return "mid=" .. tostring(id) .. " "
end

local function FindLifecycle(message, sender)
  local text = NormalizeDiagnosticText(message)
  local normalizedSender = NormalizeDiagnosticText(sender)
  local records = debugState.messageLifecycles
  local order = debugState.messageLifecycleOrder
  local now = GetTime()
  local senderMismatchRecord = nil
  for i = table_getn(order), 1, -1 do
    local record = records[order[i]]
    local age = record and now - record.created or 999
    -- Open chat/event pairs may wait briefly for their other half. Completed
    -- records only remain eligible long enough for same-frame chat rendering;
    -- repeated messages must start a new lifecycle.
    local withinMatchWindow = record and ((not record.terminal and age <= 1.0) or age <= 0.10)
    if withinMatchWindow and record.text == text then
      if record.sender == normalizedSender then return record, false end
      if not record.sender or record.sender == "" or not normalizedSender or normalizedSender == "" then return record, false end
      if not senderMismatchRecord then senderMismatchRecord = record end
    end
  end
  if senderMismatchRecord then return senderMismatchRecord, true end
  -- If the paths disagree after normalization, keep a very short sender-based
  -- association so the resulting warning remains tied to one lifecycle.
  for i = table_getn(order), 1, -1 do
    local record = records[order[i]]
    if record and not record.terminal and record.sender == normalizedSender and now - record.created <= 0.25 then
      return record, false, true
    end
  end
  return nil, false, false
end

local function NewLifecycle(message, sender)
  debugState.messageSequence = debugState.messageSequence + 1
  local record = {
    id = "M" .. tostring(debugState.messageSequence),
    text = NormalizeDiagnosticText(message),
    sender = NormalizeDiagnosticText(sender),
    rawText = tostring(message or ""),
    rawSender = tostring(sender or ""),
    created = GetTime()
  }
  debugState.messageLifecycles[record.id] = record
  table_insert(debugState.messageLifecycleOrder, record.id)
  if table_getn(debugState.messageLifecycleOrder) > 120 then
    local oldID = table_remove(debugState.messageLifecycleOrder, 1)
    debugState.messageLifecycles[oldID] = nil
  end
  return record
end

local function ConsistencyWarning(record, counter, warning, details)
  if not record then return end
  record.consistencyWarnings = record.consistencyWarnings or {}
  if record.consistencyWarnings[counter] then return end
  record.consistencyWarnings[counter] = true
  DBB2.api.DebugCount(counter, 1)
  DBB2.api.DebugTrace(3, "message", "WARN " .. warning, LifecyclePrefix(record.id) .. details)
end

local function CheckLifecycle(record)
  if not record then return end
  -- Blacklisted messages are deliberately both hidden from chat and rejected
  -- from storage. Only category-based hiding expects a stored DBB entry.
  if record.expectHidden and record.terminal and string_find(record.terminal, "^stored") == nil then
    ConsistencyWarning(record, "consistency.hidden-not-stored", "hidden-not-stored",
      "chatRule=" .. tostring(record.chatRule or "unknown") .. " storageRule=" .. tostring(record.storageRule or record.terminal))
  end
  if record.visible and record.terminal and string_find(record.terminal, "^stored") then
    ConsistencyWarning(record, "consistency.stored-not-hidden", "stored-not-hidden",
      "chatRule=" .. tostring(record.chatRule or "unknown") .. " storageRule=" .. tostring(record.storageRule or record.terminal))
  end
  if record.chatRule == "category match" and record.terminal and
     (record.terminal == "rejected-no-category" or record.terminal == "rejected-filter-tags") then
    ConsistencyWarning(record, "consistency.category-mismatch", "category-mismatch",
      "chatRule=" .. record.chatRule .. " storageRule=" .. tostring(record.storageRule or record.terminal) .. " categories=" .. tostring(record.categorySummary or "unavailable"))
  elseif record.chatRule == "no hide rule matched" and record.terminal and string_find(record.terminal, "^stored") then
    ConsistencyWarning(record, "consistency.category-mismatch", "category-mismatch",
      "chatRule=" .. record.chatRule .. " storageRule=" .. tostring(record.storageRule or record.terminal) .. " categories=" .. tostring(record.categorySummary or "unavailable"))
  end
end

function DBB2.api.DebugBeginMessage(message, sender, channel, msgType)
  if not debugState.enabled then return nil end
  local record, senderMismatch, textMismatch = FindLifecycle(message, sender)
  -- A prior event with identical text is a separate delivery (often a real
  -- duplicate message), not another stage of the old lifecycle. Chat rendering
  -- can still attach to a completed event through DebugChatLifecycle.
  if not record or record.eventSeen then
    record = NewLifecycle(message, sender)
    senderMismatch = false
    textMismatch = false
  end
  if senderMismatch then
    ConsistencyWarning(record, "consistency.sender-mismatch", "sender-mismatch",
      "eventSender=" .. tostring(sender or "") .. " chatSender=" .. tostring(record.chatSender or record.rawSender))
  end
  if textMismatch then
    ConsistencyWarning(record, "consistency.text-normalization-mismatch", "text-normalization-mismatch",
      "eventText=\"" .. tostring(message or "") .. "\" chatText=\"" .. tostring(record.chatText or record.rawText) .. "\"")
  end
  record.eventSender = tostring(sender or "")
  record.eventText = tostring(message or "")
  record.eventSeen = true
  debugState.currentDiagnosticID = record.id
  record.channel = channel
  record.msgType = msgType
  DBB2.api.DebugTrace(2, "event", "received", LifecyclePrefix(record.id) .. "sender=" .. tostring(sender or "Unknown") .. " channel=" .. tostring(channel or "") .. " type=" .. tostring(msgType or "") .. " text=\"" .. tostring(message or "") .. "\"")
  return record.id
end

function DBB2.api.DebugChatLifecycle(message, sender, hidden, reason, frameIndex)
  if not debugState.enabled then return nil end
  local record, senderMismatch, textMismatch = FindLifecycle(message, sender)
  if not record then record = NewLifecycle(message, sender) end
  if senderMismatch then
    ConsistencyWarning(record, "consistency.sender-mismatch", "sender-mismatch",
      "chatSender=" .. tostring(sender or "") .. " eventSender=" .. tostring(record.eventSender or record.rawSender))
  end
  local normalizedText = NormalizeDiagnosticText(message)
  if textMismatch or record.text ~= normalizedText then
    ConsistencyWarning(record, "consistency.text-normalization-mismatch", "text-normalization-mismatch",
      "eventText=\"" .. tostring(record.eventText or record.rawText) .. "\" chatText=\"" .. tostring(message or "") .. "\"")
  end
  record.chatSender = tostring(sender or "")
  record.chatText = tostring(message or "")
  record.chatRule = reason or "unknown"
  if hidden then record.hidden = true else record.visible = true end
  if hidden and reason ~= "blacklist" then record.expectHidden = true end
  DBB2.api.DebugChatTrace(hidden and 2 or 1, hidden and "hidden" or "visible", LifecyclePrefix(record.id) .. "reason=" .. tostring(reason or "unknown") .. " sender=" .. tostring(sender or "Unknown") .. " text=\"" .. tostring(message or "") .. "\"", nil, frameIndex)
  CheckLifecycle(record)
  return record.id
end

function DBB2.api.DebugLifecycleStage(id, stage, details)
  if not debugState.enabled or not id then return end
  local record = debugState.messageLifecycles[id]
  if record and stage == "category-matching" then record.categorySummary = SafeText(details, 400) end
  DBB2.api.DebugTrace(2, "message", stage, LifecyclePrefix(id) .. (details or ""))
end

function DBB2.api.DebugPipelineStage(id, stage, elapsedMS, details, storedMessages, renderedRows)
  if not debugState.enabled then return end
  -- Per-call stage timings overwhelmed the bounded trace while duplicating the
  -- aggregate performance report. Keep samples and slow-call warnings; the
  -- terminal entry retains each message's total elapsed time and outcome.
  DBB2.api.DebugPerf("pipeline." .. stage, elapsedMS, storedMessages)
end

function DBB2.api.DebugUITransition(action, details)
  if not debugState.enabled then return end
  if action == "level-filter-changed" or action == "category-tags-changed" or
     action == "category-selection-changed" or action == "filter-tags-changed" or
     action == "filter-tags-enabled-changed" then
    DBB2.api.DebugCount("configuration.changes", 1)
  end
  local uiState = DBB2.api.DebugGetUIStateSummary and DBB2.api.DebugGetUIStateSummary() or "UI=unavailable"
  DBB2.api.DebugTrace(2, "ui", action or "state-changed", (details or "") .. " " .. uiState)
end

function DBB2.api.DebugLifecycleTerminal(id, outcome, details, suppressTrace)
  if not debugState.enabled or not id then return end
  local record = debugState.messageLifecycles[id]
  if record and record.terminal then
    DBB2.api.DebugCount("lifecycle.multipleTerminal", 1)
    DBB2.api.DebugTrace(3, "message", "WARN multiple-terminal-decisions", LifecyclePrefix(id) .. "first=" .. record.terminal .. " next=" .. tostring(outcome))
  elseif record then
    record.terminal = outcome
    record.storageRule = details
  end
  if not suppressTrace then DBB2.api.DebugLifecycleStage(id, outcome, details) end
  CheckLifecycle(record)
end

local function ReadAddonMemoryKB()
  if not GetAddOnMemoryUsage then return nil end

  -- Some clients accept an addon name while older clients require its index.
  local ok, memory = pcall(GetAddOnMemoryUsage, "DifficultBulletinBoard")
  if ok and type(memory) == "number" then return memory end

  if GetNumAddOns and GetAddOnInfo then
    local addonCount = GetNumAddOns() or 0
    for i = 1, addonCount do
      local addonName = GetAddOnInfo(i)
      if addonName == "DifficultBulletinBoard" then
        ok, memory = pcall(GetAddOnMemoryUsage, i)
        if ok and type(memory) == "number" then return memory end
        break
      end
    end
  end
  return nil
end

function DBB2.api.DebugClock()
  return ClockMS()
end

function DBB2.api.DebugCount(name, amount)
  if not debugState.enabled then return end
  debugState.counters[name] = (debugState.counters[name] or 0) + (amount or 1)
  debugState.dirty = true
end

-- Aggregate noisy background activity without forcing the visible report to
-- rebuild. The count appears on the next meaningful refresh.
function DBB2.api.DebugCountSilent(name, amount)
  if not debugState.enabled then return end
  debugState.counters[name] = (debugState.counters[name] or 0) + (amount or 1)
end

function DBB2.api.DebugTrace(level, category, action, details, elapsedMS)
  if not debugState.enabled or debugState.paused then return end
  local traceStarted = ClockMS()

  level = level or 2
  category = category or "system"
  action = action or "event"
  debugState.sequence = debugState.sequence + 1

  local entry = {
    sequence = debugState.sequence,
    sessionTime = GetTime() - debugState.startTime,
    level = level,
    levelName = LEVEL_NAMES[level] or "INFO",
    category = SafeText(category, 18),
    action = SafeText(action, 28),
    details = SafeText(details, category == "lua-error" and 2600 or 700),
    elapsedMS = elapsedMS
  }

  if debugState.entryCount < debugState.maxEntries then
    local position = math.mod(debugState.entryStart + debugState.entryCount - 1, debugState.maxEntries) + 1
    debugState.entries[position] = entry
    debugState.entryCount = debugState.entryCount + 1
  else
    debugState.entries[debugState.entryStart] = entry
    debugState.entryStart = math.mod(debugState.entryStart, debugState.maxEntries) + 1
    debugState.dropped = (debugState.dropped or 0) + 1
  end
  debugState.dirty = true
  DBB2.api.DebugPerf("diagnostic.trace-creation", ClockMS() - traceStarted, nil, true)
  return entry
end

-- Chat lines may be rendered into more than one chat frame. Coalesce identical
-- render decisions that occur together while retaining the contributing frame
-- names and the total render count.
function DBB2.api.DebugChatTrace(level, action, details, elapsedMS, frameIndex)
  if not debugState.enabled or debugState.paused then return nil end
  local coalesceStarted = ClockMS()

  local now = GetTime()
  local frameName = "ChatFrame" .. tostring(frameIndex or "?")
  local key = tostring(level or 1) .. "\031" .. tostring(action or "event") .. "\031" .. tostring(details or "")
  local previous = debugState.lastChatTrace

  if previous and previous.key == key and now - previous.time <= 0.10 and previous.entry then
    if not previous.frames[frameName] then
      previous.frames[frameName] = true
      table_insert(previous.frameNames, frameName)
    end
    previous.renders = previous.renders + 1
    previous.entry.details = SafeText(details .. " frames=" .. table.concat(previous.frameNames, ",") .. " renders=" .. previous.renders, 700)
    previous.time = now
    DBB2.api.DebugCount("chat.renderCoalesced", 1)
    debugState.dirty = true
    DBB2.api.DebugPerf("diagnostic.chat-trace-coalescing", ClockMS() - coalesceStarted, nil, true)
    return true
  end

  local entry = DBB2.api.DebugTrace(level, "chat", action, details .. " frames=" .. frameName .. " renders=1", elapsedMS)
  debugState.lastChatTrace = {
    key = key,
    time = now,
    entry = entry,
    frames = { [frameName] = true },
    frameNames = { frameName },
    renders = 1
  }
  DBB2.api.DebugPerf("diagnostic.chat-trace-coalescing", ClockMS() - coalesceStarted, nil, true)
  return false
end

function DBB2.api.DebugGetEntries()
  local ordered = {}
  for i = 1, debugState.entryCount do
    local position = math.mod(debugState.entryStart + i - 2, debugState.maxEntries) + 1
    ordered[i] = debugState.entries[position]
  end
  return ordered
end

function DBB2.api.DebugDecision(outcome, details, elapsedMS)
  DBB2.api.DebugCount("decision." .. (outcome or "unknown"), 1)
  DBB2.api.DebugTrace(2, "message", outcome or "unknown", details, elapsedMS)
end

function DBB2.api.DebugFinishDecision(startedMS, outcome, details, startingMessageCount)
  if not debugState.enabled then return end
  local elapsed = ClockMS() - startedMS
  local retainedMessages = DBB2.messages and table_getn(DBB2.messages) or 0
  local messageContext = " retainedMessages=" .. retainedMessages
  if startingMessageCount ~= nil then
    messageContext = " retainedMessages=" .. startingMessageCount .. "->" .. retainedMessages
  end
  DBB2.api.DebugDecision(outcome, details .. messageContext, elapsed)
  DBB2.api.DebugPerf("AddMessage", elapsed, retainedMessages)
  DBB2.api.DebugPerf("AddMessage." .. (outcome or "unknown"), elapsed, retainedMessages)
end

function DBB2.api.DebugPerf(name, elapsedMS, retainedMessages, suppressSlowWarning)
  if not debugState.enabled or not elapsedMS then return end
  local item = debugState.perf[name]
  if not item then
    item = { count = 0, total = 0, max = 0, samples = {}, sampleStart = 1, sampleCount = 0 }
    debugState.perf[name] = item
  end
  item.count = item.count + 1
  item.total = item.total + elapsedMS
  if elapsedMS > item.max then item.max = elapsedMS end
  local sampleLimit = debugState.perfSampleLimit
  local samplePosition = math.mod(item.sampleStart + item.sampleCount - 1, sampleLimit) + 1
  item.samples[samplePosition] = elapsedMS
  if item.sampleCount < sampleLimit then
    item.sampleCount = item.sampleCount + 1
  else
    item.sampleStart = math.mod(item.sampleStart, sampleLimit) + 1
  end
  if retainedMessages ~= nil then
    if item.minMessages == nil or retainedMessages < item.minMessages then item.minMessages = retainedMessages end
    if item.maxMessages == nil or retainedMessages > item.maxMessages then item.maxMessages = retainedMessages end
  end
  debugState.dirty = true
  local threshold = debugState.slowThresholds[name]
  if threshold == nil then threshold = debugState.slowThresholds.default end
  if not suppressSlowWarning and threshold and threshold > 0 and elapsedMS >= threshold then
    DBB2.api.DebugCount("performance.slowCalls", 1)
    DBB2.api.DebugTrace(3, "performance", "slow-call", "metric=" .. name .. " elapsedMS=" .. string_format("%.3f", elapsedMS) .. " thresholdMS=" .. tostring(threshold) .. " retainedMessages=" .. tostring(retainedMessages or ""))
  end
end

function DBB2.api.DebugSetSlowThreshold(name, thresholdMS)
  if not name or name == "" then return false end
  thresholdMS = tonumber(thresholdMS)
  if not thresholdMS or thresholdMS < 0 then return false end
  debugState.slowThresholds[name] = thresholdMS
  return true
end

function DBB2.api.DebugGetSlowThreshold(name)
  if name and debugState.slowThresholds[name] ~= nil then return debugState.slowThresholds[name] end
  return debugState.slowThresholds.default
end

function DBB2.api.DebugReportAmbiguousCategories(message, sender, channel, categories, evidenceByType)
  if not debugState.enabled or not categories then return false end

  local ambiguousTypes = {}
  local allMatches = {}
  local tagCounts = {}
  local tagOrder = {}
  local function FindEvidence(categoryType, name)
    for _, item in ipairs(evidenceByType and evidenceByType[categoryType] or {}) do
      if item.name == name then return item.evidence end
    end
    return nil
  end
  local function AddAmbiguity(categoryType, values)
    if values and table_getn(values) > 1 then
      table_insert(ambiguousTypes, categoryType .. "=[" .. table.concat(values, ",") .. "]")
      for _, name in ipairs(values) do
        local item = { type = categoryType, name = name, tags = {} }
        local evidence = FindEvidence(categoryType, name)
        for _, tagResult in ipairs(evidence and evidence.tags or {}) do
          local tag = string_lower(tagResult.tag or "")
          if tag ~= "" then
            if not item.tags[tag] then
              item.tags[tag] = true
              if not tagCounts[tag] then table_insert(tagOrder, tag) end
              tagCounts[tag] = (tagCounts[tag] or 0) + 1
            end
          end
        end
        table_insert(allMatches, item)
      end
    end
  end

  AddAmbiguity("groups", categories.groups)
  AddAmbiguity("professions", categories.professions)
  AddAmbiguity("hardcore", categories.hardcore)
  if not ambiguousTypes[1] then return false end

  local sharedTag = nil
  for _, tag in ipairs(tagOrder) do
    if tagCounts[tag] > 1 then sharedTag = tag break end
  end

  local distinctTags = true
  for _, item in ipairs(allMatches) do
    local hasUnique = false
    for tag, _ in pairs(item.tags) do
      if tagCounts[tag] == 1 then hasUnique = true break end
    end
    if not hasUnique then distinctTags = false break end
  end

  local commonNameWord = nil
  local hasVariantMarker = false
  for _, item in ipairs(allMatches) do
    local lowerName = string_lower(item.name)
    if string_find(lowerName, "upper", 1, true) or string_find(lowerName, "lower", 1, true) then
      hasVariantMarker = true
      break
    end
  end
  if not sharedTag and not distinctTags and allMatches[1] then
    for word in string_gfind(string_lower(allMatches[1].name), "[%a%d]+") do
      if string.len(word) >= 4 then
        local inEveryName = true
        for i = 2, table_getn(allMatches) do
          if not string_find(string_lower(allMatches[i].name), word, 1, true) then inEveryName = false break end
        end
        if inEveryName then commonNameWord = word break end
      end
    end
  end

  local classification = "multi-intent"
  local reason = "each category has a distinct triggering tag"
  if sharedTag and hasVariantMarker and not distinctTags then
    classification = "parent/variant-overlap"
    reason = "shared parent tag=\"" .. sharedTag .. "\" crossed upper/lower variants"
  elseif sharedTag and string.len(sharedTag) <= 3 and not distinctTags then
    classification = "unresolved-abbreviation"
    reason = "shared short tag=\"" .. sharedTag .. "\" cannot select one category"
  elseif sharedTag then
    classification = "shared-tag-collision"
    reason = "shared tag=\"" .. sharedTag .. "\" matched multiple categories"
  elseif commonNameWord then
    classification = "parent/variant-overlap"
    reason = "related category name token=\"" .. commonNameWord .. "\""
  end

  DBB2.api.DebugCount("classification.ambiguous", 1)
  DBB2.api.DebugCount("classification." .. classification, 1)
  local collisionKey = table.concat(ambiguousTypes, ";")
  debugState.categoryCollisions[collisionKey] = (debugState.categoryCollisions[collisionKey] or 0) + 1
  DBB2.api.DebugTrace(3, "message", classification,
    "sender=" .. tostring(sender or "Unknown") ..
    " channel=" .. tostring(channel or "") ..
    " matches=" .. table.concat(ambiguousTypes, ";") ..
    " reason=" .. reason ..
    " text=\"" .. SafeText(message, 300) .. "\"")
  return true
end

-- Static, diagnostic-only category audit. It deliberately reports risks rather
-- than changing data: shared or short tags can be intentional conventions.
function DBB2.api.DebugAuditCategoryData()
  if not debugState.enabled or not DBB2_Config.categories then return end

  local tags = {}
  local categories = {}
  local emitted = 0
  local totalIssues = 0
  -- Counters and the summary retain every issue. Only keep a small, balanced
  -- sample in the bounded trace so this one-time audit cannot evict live data.
  local maxIssues = 24
  local maxIssuesPerKind = 5
  local issueCounts = {}
  local emittedByKind = {}
  local function Emit(kind, details)
    issueCounts[kind] = (issueCounts[kind] or 0) + 1
    totalIssues = totalIssues + 1
    DBB2.api.DebugCount("audit." .. kind, 1)
    local kindEmitted = emittedByKind[kind] or 0
    if emitted < maxIssues and kindEmitted < maxIssuesPerKind then
      emitted = emitted + 1
      emittedByKind[kind] = kindEmitted + 1
      DBB2.api.DebugTrace(3, "audit", kind, details)
    end
  end

  for _, categoryType in ipairs({ "groups", "professions", "hardcore" }) do
    for _, category in ipairs(DBB2_Config.categories[categoryType] or {}) do
      local categoryEntry = { type = categoryType, name = category.name, tags = {} }
      table_insert(categories, categoryEntry)
      for _, rawTag in ipairs(category.tags or {}) do
        local tag = string_lower(rawTag or "")
        if tag ~= "" then
          categoryEntry.tags[tag] = true
          if not tags[tag] then tags[tag] = {} end
          table_insert(tags[tag], { type = categoryType, name = category.name, raw = rawTag })
        end
      end
    end
  end

  for tag, owners in pairs(tags) do
    if table_getn(owners) > 1 then
      local names = {}
      for _, owner in ipairs(owners) do table_insert(names, owner.type .. ":" .. owner.name) end
      Emit("shared-tag", "tag=\"" .. tag .. "\" categories=[" .. table.concat(names, ";") .. "]")
    end
    if string_len(tag) <= 2 then
      Emit("high-risk-short-tag", "tag=\"" .. tag .. "\" length=" .. string_len(tag) .. " categories=" .. table_getn(owners))
    end
    if string_find(tag, "[%*%?%[%]%{%}\\]") then
      local literal = string_gsub(tag, "[%*%?%[%]%{%}\\,]", "")
      if string_len(literal) < 4 or string_sub(tag, 1, 1) == "*" or string_sub(tag, -1) == "*" then
        Emit("broad-wildcard", "tag=\"" .. tag .. "\" literalLength=" .. string_len(literal))
      end
    end
  end

  local tagNames = {}
  for tag, _ in pairs(tags) do table_insert(tagNames, tag) end
  table.sort(tagNames)
  for i = 1, table_getn(tagNames) do
    local shortTag = tagNames[i]
    for j = i + 1, table_getn(tagNames) do
      local longTag = tagNames[j]
      if string_len(shortTag) < string_len(longTag) and string_find(longTag, shortTag, 1, true) then
        Emit("substring-tag", "short=\"" .. shortTag .. "\" longer=\"" .. longTag .. "\"")
      elseif string_len(longTag) < string_len(shortTag) and string_find(shortTag, longTag, 1, true) then
        Emit("substring-tag", "short=\"" .. longTag .. "\" longer=\"" .. shortTag .. "\"")
      end
    end
  end

  for _, category in ipairs(categories) do
    local hasTag = false
    local hasUniqueTag = false
    for tag, _ in pairs(category.tags) do
      hasTag = true
      if tags[tag] and table_getn(tags[tag]) == 1 then hasUniqueTag = true break end
    end
    if hasTag and not hasUniqueTag then
      Emit("no-unique-tags", "category=" .. category.type .. ":" .. category.name)
    end
  end

  for _, categoryType in ipairs({ "groups", "professions", "hardcore" }) do
    local filter = DBB2.api.GetFilterTags and DBB2.api.GetFilterTags(categoryType) or nil
    for _, filterTag in ipairs(filter and filter.tags or {}) do
      local lowerFilterTag = string_lower(filterTag or "")
      if tags[lowerFilterTag] then
        local names = {}
        for _, owner in ipairs(tags[lowerFilterTag]) do
          if owner.type == categoryType then table_insert(names, owner.name) end
        end
        if names[1] then
          Emit("filter-category-overlap", "type=" .. categoryType .. " filterTag=\"" .. lowerFilterTag .. "\" categories=[" .. table.concat(names, ",") .. "]")
        end
      end
    end
  end

  local summary = {}
  for kind, count in pairs(issueCounts) do table_insert(summary, kind .. "=" .. count) end
  table.sort(summary)
  DBB2.api.DebugTrace(2, "audit", "category-data-summary", "issues=" .. table.concat(summary, " ") .. " emitted=" .. emitted .. " total=" .. totalIssues .. " truncated=" .. tostring(totalIssues > emitted))
end

function DBB2.api.DebugFormatEntry(entry)
  local elapsed = ""
  if entry.elapsedMS then
    elapsed = string_format(" (%.3fms)", entry.elapsedMS)
  end
  return string_format("%05d +%07.2fs %-5s %-10s %-24s%s || %s",
    entry.sequence or 0,
    entry.sessionTime or 0,
    entry.levelName or "INFO",
    entry.category or "system",
    entry.action or "event",
    elapsed,
    entry.details or "")
end

function DBB2.api.DebugClear()
  debugState.entries = {}
  debugState.entryStart = 1
  debugState.entryCount = 0
  debugState.counters = {}
  debugState.perf = {}
  debugState.dropped = 0
  debugState.sequence = 0
  debugState.startTime = GetTime()
  debugState.lastChatTrace = nil
  debugState.messageSequence = 0
  debugState.messageLifecycles = {}
  debugState.messageLifecycleOrder = {}
  debugState.categoryCollisions = {}
  debugState.currentEvent = "none"
  debugState.currentDiagnosticID = nil
  debugState.luaMemoryStartKB = collectgarbage and (collectgarbage("count") or 0) or 0
  debugState.lastMemoryUpdate = 0
  debugState.dirty = true
  DBB2.api.DebugTrace(2, "system", "log-cleared", "Diagnostic log and counters reset")
end

function DBB2.api.DebugGetRuntimeSummary()
  local fps = GetFramerate and GetFramerate() or 0
  local latency = 0
  if GetNetStats then
    local _, _, homeLatency = GetNetStats()
    latency = homeLatency or 0
  end
  local memory = 0
  if collectgarbage then
    memory = collectgarbage("count") or 0
  end

  local now = GetTime()
  if now - (debugState.lastMemoryUpdate or 0) >= 5 then
    local memorySampleStarted = ClockMS()
    debugState.lastMemoryUpdate = now
    DBB2.api.DebugPerf("diagnostic.memory-sampling", ClockMS() - memorySampleStarted, nil, true)
  end
  local memoryDelta = memory - (debugState.luaMemoryStartKB or memory)
  local messageRows = DBB2.gui and DBB2.gui.messageRows and table_getn(DBB2.gui.messageRows) or 0
  local categoryFrames = 0
  local categoryRows = 0
  if DBB2.gui and DBB2.gui.tabs and DBB2.gui.tabs.panels then
    for _, tabName in ipairs({ "Groups", "Professions", "Hardcore" }) do
      local panel = DBB2.gui.tabs.panels[tabName]
      if panel then
        for _, _ in pairs(panel.categoryFrames or {}) do categoryFrames = categoryFrames + 1 end
        categoryRows = categoryRows + table_getn(panel.rowPool or {})
      end
    end
  end
  local notificationQueue = DBB2.notificationQueue and table_getn(DBB2.notificationQueue) or 0
  local pendingMessages = DBB2.pendingMessages and table_getn(DBB2.pendingMessages) or 0
  local categoryCount = 0
  if DBB2_Config.categories then
    for _, categoryType in ipairs({ "groups", "professions", "hardcore" }) do
      categoryCount = categoryCount + table_getn(DBB2_Config.categories[categoryType] or {})
    end
  end

  return string_format("entries %d/%d  dropped %d  messages %d  FPS %.1f  latency %dms  AddonMemory unsupported  LuaStart %.1fKB  LuaNow %.1fKB  LuaDelta %+.1fKB  rows %d  categoryFrames %d  categoryRows %d  notifyQueue %d  pending %d  categories %d  lifecycles %d  uptime %.0fs",
    debugState.entryCount,
    debugState.maxEntries,
    debugState.dropped or 0,
    DBB2.messages and table_getn(DBB2.messages) or 0,
    fps,
    latency,
    debugState.luaMemoryStartKB or 0,
    memory,
    memoryDelta,
    messageRows,
    categoryFrames,
    categoryRows,
    notificationQueue,
    pendingMessages,
    categoryCount,
    table_getn(debugState.messageLifecycleOrder or {}),
    GetTime() - debugState.startTime)
end

-- Compact, fixed-width-enough status for the diagnostic viewer's top bar.
-- The full runtime summary remains available in the log and TSV export.
function DBB2.api.DebugGetLiveSummary()
  local uptime = GetTime() - debugState.startTime
  local minutes = math_floor(uptime / 60)
  local seconds = math_floor(uptime - (minutes * 60))
  return string_format("%d/%d entries  ||  %d dropped  ||  %d messages  ||  %d errors  ||  %dm%02ds",
    debugState.entryCount,
    debugState.maxEntries,
    debugState.dropped or 0,
    DBB2.messages and table_getn(DBB2.messages) or 0,
    debugState.counters.errors or 0,
    minutes,
    seconds)
end

function DBB2.api.DebugGetHealthSummary()
  local counters = debugState.counters or {}
  local consistency = 0
  local commonRejection = "none"
  local commonRejectionCount = 0
  for name, count in pairs(counters) do
    if string_find(name, "consistency.", 1, true) == 1 then
      consistency = consistency + count
    end
    if string_find(name, "decision.rejected-", 1, true) == 1 and count > commonRejectionCount then
      commonRejection = string_sub(name, string_len("decision.") + 1)
      commonRejectionCount = count
    end
  end

  local slowestStage = "none"
  local slowestStageMS = 0
  for name, item in pairs(debugState.perf or {}) do
    if string_find(name, "pipeline.", 1, true) == 1 and (item.max or 0) > slowestStageMS then
      slowestStage = string_sub(name, string_len("pipeline.") + 1)
      slowestStageMS = item.max or 0
    end
  end

  local commonCollision = "none"
  local commonCollisionCount = 0
  for collision, count in pairs(debugState.categoryCollisions or {}) do
    if count > commonCollisionCount then
      commonCollision = collision
      commonCollisionCount = count
    end
  end

  return "Health: errors=" .. tostring(counters.errors or 0) ..
    " consistency=" .. tostring(consistency) ..
    " ambiguous=" .. tostring(counters["classification.ambiguous"] or 0) ..
    " slowestPipeline=" .. slowestStage .. "(" .. string_format("%.3f", slowestStageMS) .. "ms)" ..
    " commonRejection=" .. commonRejection .. "(" .. commonRejectionCount .. ")" ..
    " commonCollision=" .. commonCollision .. "(" .. commonCollisionCount .. ")" ..
    " dropped=" .. tostring(debugState.dropped or 0) ..
    " configChanges=" .. tostring(counters["configuration.changes"] or 0)
end

function DBB2.api.DebugGetCounterSummary()
  local names = {}
  for name, _ in pairs(debugState.counters) do table_insert(names, name) end
  table.sort(names)
  local parts = {}
  for _, name in ipairs(names) do
    table_insert(parts, name .. "=" .. debugState.counters[name])
  end
  return table.concat(parts, "  ")
end

function DBB2.api.DebugGetPerfSummary()
  local names = {}
  for name, _ in pairs(debugState.perf) do table_insert(names, name) end
  table.sort(names)
  local parts = {}
  for _, name in ipairs(names) do
    local item = debugState.perf[name]
    local average = item.count > 0 and (item.total / item.count) or 0
    local samples = {}
    local sampleCount = item.sampleCount or 0
    local sampleLimit = debugState.perfSampleLimit
    for i = 1, sampleCount do
      local position = math.mod((item.sampleStart or 1) + i - 2, sampleLimit) + 1
      samples[i] = item.samples and item.samples[position] or 0
    end
    local recentTotal = 0
    local recentCount = math.min(sampleCount, debugState.perfRecentLimit)
    for i = sampleCount - recentCount + 1, sampleCount do
      if i > 0 then recentTotal = recentTotal + (samples[i] or 0) end
    end
    table.sort(samples)
    local function Percentile(percent)
      if sampleCount == 0 then return 0 end
      local position = math.ceil(sampleCount * percent)
      if position < 1 then position = 1 end
      return samples[position] or 0
    end
    local messageRange = ""
    if item.minMessages ~= nil then
      messageRange = string_format(" messages=%d-%d", item.minMessages, item.maxMessages or item.minMessages)
    end
    local recentAverage = recentCount > 0 and recentTotal / recentCount or 0
    table_insert(parts, string_format("%s n=%d avg=%.3fms recent%d=%.3fms p50=%.3fms p95=%.3fms p99=%.3fms max=%.3fms%s", name, item.count, average, recentCount, recentAverage, Percentile(0.50), Percentile(0.95), Percentile(0.99), item.max, messageRange))
  end
  return table.concat(parts, "  ||  ")
end

function DBB2.api.DebugGetUIStateSummary()
  local mainWindowState = "unavailable"
  local activeTab = "none"
  local activeSearchTerms = 0
  local activeSearchText = ""
  if DBB2.gui then
    mainWindowState = DBB2.gui.IsShown and (DBB2.gui:IsShown() and "shown" or "hidden") or "created"
    if DBB2.gui.tabs and DBB2.gui.tabs.activeTab then
      activeTab = DBB2.gui.tabs.activeTab
      if activeTab == "Logs" then
        activeSearchTerms = DBB2.gui.filterTerms and table_getn(DBB2.gui.filterTerms) or 0
        activeSearchText = DBB2.gui.filterTerms and table.concat(DBB2.gui.filterTerms, ",") or ""
      else
        local panel = DBB2.gui.tabs.panels and DBB2.gui.tabs.panels[activeTab]
        activeSearchTerms = panel and panel.filterTerms and table_getn(panel.filterTerms) or 0
        activeSearchText = panel and panel.filterTerms and table.concat(panel.filterTerms, ",") or ""
      end
    end
  end
  return "mainWindow=" .. mainWindowState ..
    " activeTab=" .. activeTab ..
    " activeSearchTerms=" .. tostring(activeSearchTerms) ..
    " activeSearch=" .. activeSearchText ..
    " levelFilter=" .. tostring(DBB2_Config.showLevelFilteredGroups or false)
end

function DBB2.api.DebugGetConfigurationSummary(reason)
  local monitored = {}
  if DBB2.api.GetMonitoredChannels then
    for channel, enabled in pairs(DBB2.api.GetMonitoredChannels()) do
      if enabled then table_insert(monitored, channel) end
    end
    table.sort(monitored)
  end

  local groupFilter = DBB2.api.GetFilterTags and DBB2.api.GetFilterTags("groups") or nil
  local professionFilter = DBB2.api.GetFilterTags and DBB2.api.GetFilterTags("professions") or nil
  local notificationMode = DBB2.api.GetNotificationMode and DBB2.api.GetNotificationMode() or -1
  local playerLevel = UnitLevel and UnitLevel("player") or 0
  local playerFaction = UnitFactionGroup and UnitFactionGroup("player") or "Unknown"
  local versions = DBB2.versions or {}
  local categoryVersions = "groups:" .. tostring(DBB2_Config.groupsVersion or versions.GROUPS or 0) ..
    ",professions:" .. tostring(DBB2_Config.professionsVersion or versions.PROFESSIONS or 0) ..
    ",hardcore:" .. tostring(DBB2_Config.hardcoreVersion or versions.HARDCORE or 0) ..
    ",blacklist:" .. tostring(DBB2_Config.blacklistVersion or versions.BLACKLIST or 0)
  local categoryCounts = {}
  for _, categoryType in ipairs({ "groups", "professions", "hardcore" }) do
    local categories = DBB2_Config.categories and DBB2_Config.categories[categoryType] or {}
    local selected = 0
    for _, category in ipairs(categories) do
      if category.selected then selected = selected + 1 end
    end
    table_insert(categoryCounts, categoryType .. ":" .. selected .. "/" .. table_getn(categories))
  end
  local detail = "reason=" .. (reason or "manual") ..
    " version=" .. (GetAddOnMetadata("DifficultBulletinBoard", "Version") or "?") ..
    " monitored=[" .. table.concat(monitored, ",") .. "]" ..
    " hideFromChat=" .. tostring(DBB2_Config.hideFromChat or 0) ..
    " blacklist=" .. tostring(DBB2_Config.blacklist and DBB2_Config.blacklist.enabled or false) ..
    " spamWindow=" .. tostring(DBB2_Config.spamFilterSeconds or 0) ..
    " expiryMinutes=" .. tostring(DBB2_Config.messageExpireMinutes or 0) ..
    " unsortedLogs=" .. tostring(DBB2_Config.showUnsortedMessagesInLogs or false) ..
    " groupFilter=" .. tostring(groupFilter and groupFilter.enabled or false) ..
    " professionFilter=" .. tostring(professionFilter and professionFilter.enabled or false) ..
    " notificationMode=" .. tostring(notificationMode) ..
    " hardcore=" .. tostring(DBB2.api.IsHardcoreCharacter and DBB2.api.IsHardcoreCharacter() or false) ..
    " playerLevel=" .. tostring(playerLevel) ..
    " faction=" .. tostring(playerFaction) ..
    " categoryVersions=[" .. categoryVersions .. "]" ..
    " categorySelection=[" .. table.concat(categoryCounts, ",") .. "] " ..
    DBB2.api.DebugGetUIStateSummary()
  return detail
end

function DBB2.api.DebugCaptureSnapshot(reason)
  DBB2.api.DebugTrace(2, "system", "configuration-snapshot", DBB2.api.DebugGetConfigurationSummary(reason))
end

-- Produce deterministic, Lua-like values for the TSV configuration rows. The
-- export must be detailed enough to reproduce matching without depending on
-- the defaults in the installed addon version.
local function QuoteConfigurationString(value)
  local text = tostring(value or "")
  text = string_gsub(text, "\\", "\\\\")
  text = string_gsub(text, "\r", "\\r")
  text = string_gsub(text, "\n", "\\n")
  text = string_gsub(text, "\t", "\\t")
  text = string_gsub(text, '"', '\\"')
  return '"' .. text .. '"'
end

local function SortedConfigurationKeys(value)
  local keys = {}
  for key, _ in pairs(value or {}) do table_insert(keys, key) end
  table_sort(keys, function(left, right)
    local leftType = type(left)
    local rightType = type(right)
    if leftType ~= rightType then return leftType < rightType end
    if leftType == "number" then return left < right end
    return tostring(left) < tostring(right)
  end)
  return keys
end

local function SerializeConfigurationValue(value, seen, depth)
  local valueType = type(value)
  if valueType == "nil" then return "nil" end
  if valueType == "string" then return QuoteConfigurationString(value) end
  if valueType == "number" or valueType == "boolean" then return tostring(value) end
  if valueType ~= "table" then return QuoteConfigurationString("<" .. valueType .. ">") end

  seen = seen or {}
  depth = depth or 0
  if seen[value] then return QuoteConfigurationString("<cycle>") end
  if depth >= 16 then return QuoteConfigurationString("<maximum-depth>") end
  seen[value] = true

  local parts = {}
  for _, key in ipairs(SortedConfigurationKeys(value)) do
    local serializedKey
    if type(key) == "string" then
      serializedKey = QuoteConfigurationString(key)
    else
      serializedKey = SerializeConfigurationValue(key, seen, depth + 1)
    end
    table_insert(parts, "[" .. serializedKey .. "]=" .. SerializeConfigurationValue(value[key], seen, depth + 1))
  end

  seen[value] = nil
  return "{" .. table.concat(parts, ",") .. "}"
end

-- Returns fresh export-time configuration rows. Large matching structures are
-- split into one row per logical item so no single EditBox line becomes
-- needlessly huge, while unknown/future top-level settings are still included.
function DBB2.api.DebugGetConfigurationExportRows()
  local rows = {}
  local function Add(key, value)
    table_insert(rows, { key = key, value = value })
  end
  local function AddSerialized(key, value)
    Add(key, SerializeConfigurationValue(value))
  end

  Add("configuration.export_summary", DBB2.api.DebugGetConfigurationSummary("export-generated"))

  local speciallyHandled = {
    categories = true,
    filterTags = true,
    blacklist = true,
    monitoredChannels = true,
    whitelistedChannels = true,
    notificationState = true
  }
  for _, key in ipairs(SortedConfigurationKeys(DBB2_Config or {})) do
    if not speciallyHandled[key] then
      AddSerialized("configuration.saved." .. tostring(key), DBB2_Config[key])
    end
  end

  local categories = DBB2_Config and DBB2_Config.categories or {}
  for _, categoryType in ipairs(SortedConfigurationKeys(categories)) do
    for index, category in ipairs(categories[categoryType] or {}) do
      AddSerialized("configuration.category." .. tostring(categoryType) .. "." .. string_format("%03d", index), category)
    end
  end

  local filters = DBB2_Config and DBB2_Config.filterTags or {}
  for _, categoryType in ipairs(SortedConfigurationKeys(filters)) do
    AddSerialized("configuration.filter." .. tostring(categoryType), filters[categoryType])
  end

  local blacklist = DBB2_Config and DBB2_Config.blacklist or {}
  for _, key in ipairs(SortedConfigurationKeys(blacklist)) do
    AddSerialized("configuration.blacklist." .. tostring(key), blacklist[key])
  end

  AddSerialized("configuration.channels.monitored", DBB2_Config and DBB2_Config.monitoredChannels or {})
  AddSerialized("configuration.channels.whitelist", DBB2_Config and DBB2_Config.whitelistedChannels or {})
  AddSerialized("configuration.notification.savedState", DBB2_Config and DBB2_Config.notificationState or nil)
  AddSerialized("configuration.notification.activeState", DBB2.notificationState or {})

  local joinedChannels = {}
  if DBB2.api.GetJoinedChannels then joinedChannels = DBB2.api.GetJoinedChannels() or {} end
  AddSerialized("configuration.runtime.joinedChannels", joinedChannels)
  AddSerialized("configuration.runtime.activeClassicTheme", DBB2.activeClassicTheme == true)
  AddSerialized("configuration.runtime.player", {
    level = UnitLevel and UnitLevel("player") or 0,
    faction = UnitFactionGroup and UnitFactionGroup("player") or "Unknown",
    hardcore = DBB2.api.IsHardcoreCharacter and DBB2.api.IsHardcoreCharacter() or false
  })

  Add("configuration.export_manifest",
    "format=deterministic-lua-literal rows=" .. tostring(table_getn(rows) + 1) ..
    " sessionTime=" .. string_format("%.3f", GetTime() - debugState.startTime) ..
    " serverTime=" .. tostring(time and time() or 0))
  return rows
end

function DBB2.api.DebugAnalyzeMessage(message, sender, channel, msgType)
  message = message or ""
  sender = sender or UnitName("player") or "DebugUser"
  channel = channel or "World"
  msgType = msgType or "CHAT_MSG_CHANNEL"

  local started = ClockMS()
  local blocked, reason, details = DBB2.api.IsMessageBlacklisted(message, sender)
  local full = DBB2.api.CategorizeMessage(message, true)
  local base = DBB2.api.CategorizeMessage(message, true, true)
  local fullEvidence = DBB2.api.GetMessageCategoryEvidence(message, true, false)
  local baseEvidence = DBB2.api.GetMessageCategoryEvidence(message, true, true)
  local unsorted = DBB2.api.MatchUnsortedFilterTags(message)
  local duplicate = DBB2.api.IsDuplicateMessage(message, sender)
  local elapsed = ClockMS() - started

  local hasFull = full.groups[1] or full.professions[1] or full.hardcore[1]
  local hasBase = base.groups[1] or base.professions[1] or base.hardcore[1]
  local outcome = "stored-categorized"
  if blocked then
    outcome = "rejected-blacklist"
  elseif msgType == "CHAT_MSG_SYSTEM" and not base.hardcore[1] then
    outcome = "rejected-system"
  elseif not hasBase and (not DBB2_Config.showUnsortedMessagesInLogs or not unsorted) then
    outcome = "rejected-no-category"
  elseif duplicate then
    outcome = "rejected-duplicate"
  elseif hasBase and not hasFull then
    outcome = "rejected-filter-tags"
  elseif not hasBase and unsorted then
    outcome = "stored-unsorted"
  end

  local sourceAccepted = true
  if msgType == "CHAT_MSG_CHANNEL" and DBB2.api.IsChannelWhitelisted then
    sourceAccepted = DBB2.api.IsChannelWhitelisted(channel) and
                     (not DBB2.api.IsChannelJoined or DBB2.api.IsChannelJoined(channel))
  elseif DBB2.api.IsChannelMonitored then
    sourceAccepted = DBB2.api.IsChannelMonitored(channel)
  end

  local blacklistDetail = "no"
  if blocked then
    if type(details) == "table" then details = Join(details) end
    blacklistDetail = (reason or "yes") .. ":" .. tostring(details or "")
  end

  local detail = "predictedOutcome=" .. outcome ..
    " sourceAccepted=" .. tostring(sourceAccepted) ..
    " sender=" .. sender ..
    " channel=" .. channel ..
    " type=" .. msgType ..
    " blacklist=" .. blacklistDetail ..
    " duplicate=" .. tostring(duplicate) ..
    " groups=[" .. Join(full.groups) .. "]" ..
    " professions=[" .. Join(full.professions) .. "]" ..
    " hardcore=[" .. Join(full.hardcore) .. "]" ..
    " baseGroups=[" .. Join(base.groups) .. "]" ..
    " baseProfessions=[" .. Join(base.professions) .. "]" ..
    " fullEvidence=" .. DBB2.api.DebugFormatCategoryEvidence(fullEvidence) ..
    " baseEvidence=" .. DBB2.api.DebugFormatCategoryEvidence(baseEvidence) ..
    " ambiguous=" .. tostring((table_getn(base.groups) > 1) or (table_getn(base.professions) > 1) or (table_getn(base.hardcore) > 1)) ..
    " unsorted=" .. tostring(unsorted or "no") ..
    " text=\"" .. SafeText(message, 240) .. "\""

  DBB2.api.DebugTrace(2, "test", "message-analysis", detail, elapsed)
  DBB2.api.DebugPerf("test-analysis", elapsed)
  DBB2.api.DebugPerf("diagnostic.message-analyzer", elapsed, nil, true)
  return detail, outcome
end

-- Analyze a pasted corpus one line at a time. Blank lines and # comments are
-- ignored; the cap protects the bounded recorder from an accidental huge paste.
function DBB2.api.DebugAnalyzeBatch(text, sender, channel, msgType)
  local started = ClockMS()
  local processed = 0
  local skipped = 0
  local outcomes = {}
  local maxLines = 60
  text = string_gsub(text or "", "\r", "")

  for line in string_gfind(text, "[^\n]+") do
    line = string_gsub(line, "^%s*(.-)%s*$", "%1")
    if line == "" or string_sub(line, 1, 1) == "#" then
      skipped = skipped + 1
    elseif processed < maxLines then
      local _, outcome = DBB2.api.DebugAnalyzeMessage(line, sender, channel, msgType)
      outcomes[outcome or "unknown"] = (outcomes[outcome or "unknown"] or 0) + 1
      processed = processed + 1
    else
      skipped = skipped + 1
    end
  end

  local outcomeParts = {}
  for outcome, count in pairs(outcomes) do table_insert(outcomeParts, outcome .. "=" .. count) end
  table.sort(outcomeParts)
  local elapsed = ClockMS() - started
  DBB2.api.DebugCount("test.batchMessages", processed)
  DBB2.api.DebugTrace(2, "test", "batch-analysis", "processed=" .. processed .. " skipped=" .. skipped .. " capped=" .. tostring(processed >= maxLines) .. " outcomes=[" .. table.concat(outcomeParts, ",") .. "]", elapsed)
  DBB2.api.DebugPerf("test-batch-analysis", elapsed)
  DBB2.api.DebugPerf("diagnostic.batch-message-analyzer", elapsed, nil, true)
  return processed, skipped
end

-- Preserve the normal error dialog while retaining errors in the diagnostic log.
function DBB2.api.DebugSetCurrentEvent(eventName)
  if not debugState.enabled then return end
  debugState.currentEvent = eventName or "unknown"
  debugState.currentDiagnosticID = nil
end

function DBB2.api.DebugSetFreezeOnError(enabled)
  debugState.freezeOnError = enabled and true or false
end

local function RecentErrorContext()
  local entries = DBB2.api.DebugGetEntries()
  local first = math.max(1, table_getn(entries) - 7)
  local recent = {}
  for i = first, table_getn(entries) do
    local entry = entries[i]
    table_insert(recent, "#" .. tostring(entry.sequence or 0) .. ":" .. tostring(entry.category or "") .. "/" .. tostring(entry.action or ""))
  end
  return table.concat(recent, " | ")
end

function DBB2.api.DebugInstallErrorHandler()
  if debugState.errorHandlerInstalled or not geterrorhandler or not seterrorhandler then return end
  local original = geterrorhandler()
  debugState.originalErrorHandler = original
  local wrapper = function(errorMessage)
    local stack = "debugstack unsupported"
    if debugstack then
      local ok, trace = pcall(debugstack)
      if ok and trace and trace ~= "" then stack = trace end
    end
    local detail = "error=\"" .. tostring(errorMessage or "unknown error") .. "\"" ..
      " event=" .. tostring(debugState.currentEvent or "unknown") ..
      " mid=" .. tostring(debugState.currentDiagnosticID or "none") ..
      " ui={" .. DBB2.api.DebugGetUIStateSummary() .. "}" ..
      " recent=[" .. RecentErrorContext() .. "]" ..
      " stack=" .. tostring(stack)
    pcall(DBB2.api.DebugTrace, 4, "lua-error", "unhandled-error", detail)
    pcall(DBB2.api.DebugCount, "errors", 1)
    if debugState.freezeOnError then
      debugState.paused = true
      debugState.dirty = true
    end
    if original then return original(errorMessage) end
  end
  debugState.errorHandler = wrapper
  seterrorhandler(wrapper)
  debugState.errorHandlerInstalled = true
end

function DBB2.api.DebugRemoveErrorHandler()
  if not debugState.errorHandlerInstalled then return end
  if geterrorhandler and seterrorhandler and geterrorhandler() == debugState.errorHandler then
    seterrorhandler(debugState.originalErrorHandler)
  end
  debugState.errorHandlerInstalled = false
  debugState.errorHandler = nil
  debugState.originalErrorHandler = nil
end

function DBB2.api.DebugStart()
  if debugState.enabled then return end
  debugState.entries = {}
  debugState.entryStart = 1
  debugState.entryCount = 0
  debugState.counters = {}
  debugState.perf = {}
  debugState.dropped = 0
  debugState.sequence = 0
  debugState.startTime = GetTime()
  debugState.lastChatTrace = nil
  debugState.messageSequence = 0
  debugState.messageLifecycles = {}
  debugState.messageLifecycleOrder = {}
  debugState.categoryCollisions = {}
  debugState.currentEvent = "none"
  debugState.currentDiagnosticID = nil
  debugState.luaMemoryStartKB = collectgarbage and (collectgarbage("count") or 0) or 0
  debugState.lastMemoryUpdate = 0
  debugState.paused = false
  debugState.enabled = true
  debugState.dirty = true
  DBB2.api.DebugInstallErrorHandler()
  DBB2.api.DebugTrace(2, "system", "recorder-started", "On-demand recorder active; maximum entries=" .. debugState.maxEntries)
end

function DBB2.api.DebugStop()
  if not debugState.enabled then return end
  DBB2.api.DebugRemoveErrorHandler()
  debugState.enabled = false
  debugState.paused = false
  debugState.entries = {}
  debugState.entryStart = 1
  debugState.entryCount = 0
  debugState.counters = {}
  debugState.perf = {}
  debugState.dropped = 0
  debugState.sequence = 0
  debugState.lastChatTrace = nil
  debugState.messageSequence = 0
  debugState.messageLifecycles = {}
  debugState.messageLifecycleOrder = {}
  debugState.categoryCollisions = {}
  debugState.currentEvent = "none"
  debugState.currentDiagnosticID = nil
  debugState.luaMemoryStartKB = 0
  debugState.lastMemoryUpdate = 0
  debugState.dirty = false
end
