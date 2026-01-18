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

-- [ LogFilterTag ]
-- Logs filter tag matching results
-- 'categoryType' [string]      "groups" or "professions"
-- 'message'      [string]      the message being tested
-- 'matched'      [boolean]     whether filter tags matched
-- 'matchedTag'   [string]      which tag matched (optional)
function DBB2.api.LogFilterTag(categoryType, message, matched, matchedTag)
  local status = matched and "|cff00ff00PASS|r" or "|cffff0000FAIL|r"
  local tagInfo = matchedTag and (" [" .. matchedTag .. "]") or ""
  local logStr = "FilterTag (" .. categoryType .. "): " .. status .. tagInfo .. " - \"" .. DBB2.api.TruncateMessage(message, 80) .. "\""
  DBB2.api.DebugLog(logStr, matched and "00ff00" or "ff6666")
end

-- [ TestFilterTags ]
-- Tests filter tag matching against a message and logs results
-- 'message'      [string]      the message to test
-- return:        [table]       { groups = bool, professions = bool }
function DBB2.api.TestFilterTags(message)
  if not message or message == "" then
    DEFAULT_CHAT_FRAME:AddMessage("|cffff9900[DBB2]|r Usage: /dbb2 testfilter <message>")
    return
  end
  
  DEFAULT_CHAT_FRAME:AddMessage("|cffff9900[DBB2]|r Testing filter tags for: \"" .. message .. "\"")
  
  local results = { groups = false, professions = false }
  local categoryTypes = {"groups", "professions"}
  
  for _, categoryType in ipairs(categoryTypes) do
    local filter = DBB2.api.GetFilterTags(categoryType)
    local enabled = DBB2.api.IsFilterTagsEnabled(categoryType)
    
    DEFAULT_CHAT_FRAME:AddMessage("|cffff9900[DBB2]|r " .. categoryType .. " filter: " .. (enabled and "|cff00ff00ENABLED|r" or "|cff999999DISABLED|r"))
    
    if filter and filter.tags then
      local tags = filter.tags
      local tagCount = 0
      for _ in ipairs(tags) do tagCount = tagCount + 1 end
      DEFAULT_CHAT_FRAME:AddMessage("|cffff9900[DBB2]|r   Tags (" .. tagCount .. "): " .. DBB2.api.TagsToString(tags))
      
      -- Test each tag individually
      local lowerMsg = string.lower(message)
      local anyMatch = false
      local matchedTag = nil
      
      for _, tag in ipairs(tags) do
        local lowerTag = string.lower(tag)
        local isRegex = string.find(lowerTag, "[%[%]%.%*%+%?%^%$%(%)%%]")
        local matched = false
        
        if isRegex then
          matched = DBB2.api.MatchRegex(lowerMsg, lowerTag)
        else
          -- Simple word boundary check
          local pattern = "%f[%w]" .. lowerTag .. "%f[%W]"
          matched = string.find(lowerMsg, lowerTag) ~= nil
        end
        
        local status = matched and "|cff00ff00MATCH|r" or "|cff666666no match|r"
        local typeStr = isRegex and "(regex)" or "(plain)"
        DEFAULT_CHAT_FRAME:AddMessage("|cffff9900[DBB2]|r     " .. tag .. " " .. typeStr .. ": " .. status)
        
        if matched then
          anyMatch = true
          matchedTag = tag
        end
      end
      
      -- Overall result for this category type
      local overallResult = DBB2.api.MatchFilterTags(message, categoryType)
      results[categoryType] = overallResult
      
      local finalStatus
      if not enabled then
        finalStatus = "|cff999999PASS (disabled)|r"
      elseif overallResult then
        finalStatus = "|cff00ff00PASS|r"
      else
        finalStatus = "|cffff0000FAIL|r"
      end
      DEFAULT_CHAT_FRAME:AddMessage("|cffff9900[DBB2]|r   Result: " .. finalStatus)
    end
  end
  
  return results
end
