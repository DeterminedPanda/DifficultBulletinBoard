-- DBB2 Debug API
-- Centralized debug logging functions

-- [ Log ]
-- Core debug log function - only outputs when debug mode is enabled
-- 'message'    [string]        the message to log
-- 'color'      [string]        hex color code (optional, default yellow)
function DBB2.api.DebugLog(message, color)
  if not DBB2_Config.debugMode then return end
  color = color or "ff9900"
  DEFAULT_CHAT_FRAME:AddMessage("|cff" .. color .. "[DBB2]|r " .. (message or ""))
end

-- [ TruncateMessage ]
-- Truncates a message to maxLen characters, adding "..." if truncated
-- 'message'    [string]        the message to truncate
-- 'maxLen'     [number]        max length (default 100)
-- return:      [string]        truncated message
function DBB2.api.TruncateMessage(message, maxLen)
  if not message then return "" end
  maxLen = maxLen or 100
  if string.len(message) <= maxLen then
    return message
  end
  return string.sub(message, 1, maxLen) .. "..."
end

-- [ LogDuplicate ]
-- Logs when a duplicate message is blocked
-- 'sender'     [string]        the sender name
-- 'age'        [number]        seconds since original message
-- 'message'    [string]        the message content (optional)
function DBB2.api.LogDuplicate(sender, age, message)
  local logStr = "Duplicate: " .. (sender or "?") .. " (" .. (age or 0) .. "s)"
  if message and message ~= "" then
    logStr = logStr .. " - \"" .. DBB2.api.TruncateMessage(message, 100) .. "\""
  end
  DBB2.api.DebugLog(logStr, "ff9900")
end

-- [ LogBlacklist ]
-- Logs when a message is blocked by blacklist
-- 'sender'     [string]        the sender name
-- 'reason'     [string]        "player" or "keyword"
-- 'details'    [string|table]  player name or table of matched keywords
-- 'message'    [string]        the message content (optional)
function DBB2.api.LogBlacklist(sender, reason, details, message)
  local detailStr
  if reason == "player" then
    detailStr = details or "unknown"
  else
    detailStr = table.concat(details or {}, ", ")
  end
  local logStr = "Blacklist: " .. (sender or "?") .. " (" .. detailStr .. ")"
  if message and message ~= "" then
    logStr = logStr .. " - \"" .. DBB2.api.TruncateMessage(message, 100) .. "\""
  end
  DBB2.api.DebugLog(logStr, "ff6666")
end

-- [ LogExpired ]
-- Logs when messages are removed due to expiration
-- 'count'      [number]        number of messages removed
function DBB2.api.LogExpired(count)
  if count > 0 then
    DBB2.api.DebugLog("Expired: " .. count .. " message(s) removed", "999999")
  end
end
