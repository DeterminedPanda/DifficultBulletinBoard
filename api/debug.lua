-- DBB2 diagnostic recorder
-- Kept independent of the normal GUI. The viewer is created lazily by
-- modules/debug_viewer.lua and can only be opened with /dbb debug.

DBB2.debug = DBB2.debug or {}

local debugState = DBB2.debug
local table_insert = table.insert
local table_remove = table.remove
local table_getn = table.getn
local string_format = string.format
local string_gsub = string.gsub
local string_lower = string.lower
local tostring = tostring
local type = type
local pairs = pairs
local ipairs = ipairs

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
    details = SafeText(details, 700),
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

function DBB2.api.DebugFinishDecision(startedMS, outcome, details)
  if not debugState.enabled then return end
  local elapsed = ClockMS() - startedMS
  DBB2.api.DebugDecision(outcome, details, elapsed)
  DBB2.api.DebugPerf("AddMessage", elapsed)
end

function DBB2.api.DebugPerf(name, elapsedMS)
  if not debugState.enabled or not elapsedMS then return end
  local item = debugState.perf[name]
  if not item then
    item = { count = 0, total = 0, max = 0 }
    debugState.perf[name] = item
  end
  item.count = item.count + 1
  item.total = item.total + elapsedMS
  if elapsedMS > item.max then item.max = elapsedMS end
  debugState.dirty = true
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
  return string_format("entries %d/%d  dropped %d  messages %d  FPS %.1f  latency %dms  Lua %.1fKB  uptime %.0fs",
    debugState.entryCount,
    debugState.maxEntries,
    debugState.dropped or 0,
    DBB2.messages and table_getn(DBB2.messages) or 0,
    fps,
    latency,
    memory,
    GetTime() - debugState.startTime)
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
    table_insert(parts, string_format("%s n=%d avg=%.3fms max=%.3fms", name, item.count, average, item.max))
  end
  return table.concat(parts, "  ||  ")
end

function DBB2.api.DebugCaptureSnapshot(reason)
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
    " hardcore=" .. tostring(DBB2.api.IsHardcoreCharacter and DBB2.api.IsHardcoreCharacter() or false)
  DBB2.api.DebugTrace(2, "system", "configuration-snapshot", detail)
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
    sourceAccepted = DBB2.api.IsChannelWhitelisted(channel)
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
    " unsorted=" .. tostring(unsorted or "no") ..
    " text=\"" .. SafeText(message, 240) .. "\""

  DBB2.api.DebugTrace(2, "test", "message-analysis", detail, elapsed)
  DBB2.api.DebugPerf("test-analysis", elapsed)
  return detail
end

-- Preserve the normal error dialog while retaining errors in the diagnostic log.
function DBB2.api.DebugInstallErrorHandler()
  if debugState.errorHandlerInstalled or not geterrorhandler or not seterrorhandler then return end
  local original = geterrorhandler()
  debugState.originalErrorHandler = original
  local wrapper = function(errorMessage)
    pcall(DBB2.api.DebugTrace, 4, "lua-error", "unhandled-error", errorMessage or "unknown error")
    pcall(DBB2.api.DebugCount, "errors", 1)
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
  debugState.dirty = false
end
