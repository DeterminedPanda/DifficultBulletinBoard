-- DBB2 Tag Exclusions
-- Tag false positive exclusion rules for message matching
--
-- This file contains rules to prevent false positive tag matches.
-- For example, "ST" should not match "20:30 ST" (server time).

-- Initialize env namespace if needed
DBB2.env = DBB2.env or {}

-- Localize frequently used globals for performance
local string_find = string.find
local string_sub = string.sub
local string_len = string.len
local ipairs = ipairs

-- =====================================================
-- TAG FALSE POSITIVE EXCLUSIONS
-- =====================================================
-- Some short tags can match unintended patterns in messages.
-- This table defines exclusion rules to prevent false positives.
--
-- Format: tagExclusions[tag] = { check functions that return true if match should be REJECTED }
-- Each function receives: (lowerMsg, foundPos, tagLen)
--   lowerMsg  = lowercase message string
--   foundPos  = position where tag was found
--   tagLen    = length of the tag
--
-- Return true to REJECT the match (false positive), false to allow it.
-- =====================================================

DBB2.env.tagExclusions = {}

-- [ ST exclusion ]
-- "ST" is a tag for Sunken Temple, but also commonly used for "Server Time"
-- Reject matches like "20:30 ST", "8:00 ST", "19:45ST"
-- Pattern: digit(s) + colon + digit(s) + optional space + ST
DBB2.env.tagExclusions["st"] = {
  function(lowerMsg, foundPos, tagLen)
    -- Check if preceded by time pattern: look for "HH:MM " or "H:MM " before ST
    -- We need at least 4-6 chars before: "8:00 " (5) or "20:30 " (6) or "8:00" (4) or "20:30" (5)
    if foundPos < 3 then return false end
    
    -- Check for optional space right before ST
    local checkPos = foundPos - 1
    local charBeforeST = string_sub(lowerMsg, checkPos, checkPos)
    if charBeforeST == " " then
      checkPos = checkPos - 1
    end

    -- Now check for minutes (2 digits)
    if checkPos < 2 then return false end
    local min2 = string_sub(lowerMsg, checkPos, checkPos)
    local min1 = string_sub(lowerMsg, checkPos - 1, checkPos - 1)
    if not string_find(min1, "%d") or not string_find(min2, "%d") then
      return false
    end
    checkPos = checkPos - 2
    
    -- Check for colon
    if checkPos < 1 then return false end
    local colon = string_sub(lowerMsg, checkPos, checkPos)
    if colon ~= ":" then return false end
    checkPos = checkPos - 1
    
    -- Check for hour (1-2 digits)
    if checkPos < 1 then return false end
    local hour1 = string_sub(lowerMsg, checkPos, checkPos)
    if not string_find(hour1, "%d") then return false end
    
    -- Optional second hour digit
    if checkPos > 1 then
      local hour2 = string_sub(lowerMsg, checkPos - 1, checkPos - 1)
      if string_find(hour2, "%d") then
        checkPos = checkPos - 1
      end
    end
    
    -- Verify word boundary before the time
    if checkPos > 1 then
      local charBeforeTime = string_sub(lowerMsg, checkPos - 1, checkPos - 1)
      if string_find(charBeforeTime, "[%w]") then
        return false
      end
    end
    
    return true
  end
}

-- [ DM exclusion ]
-- "DM" is a tag for Dire Maul and Deadmines, but also commonly used for "Direct Message"
-- Reject matches like "DM me", "DM us" (direct message me/us)
-- Also reject "DM:" patterns (DM:E, DM:W, DM:N are Dire Maul wings, not generic DM)
DBB2.env.tagExclusions["dm"] = {
  function(lowerMsg, foundPos, tagLen)
    local msgLen = string_len(lowerMsg)
    local afterPos = foundPos + tagLen
    
    -- Check for colon after DM (indicates Dire Maul wing like DM:E, DM:W, DM:N)
    -- This prevents the generic "dm" tag from matching when a specific wing is mentioned
    if afterPos <= msgLen then
      local charAfter = string_sub(lowerMsg, afterPos, afterPos)
      if charAfter == ":" then
        return true  -- "DM:" - reject generic dm match, let specific dm:e/dm:w/dm:n tags handle it
      end
    end
    
    -- Check for space after DM (for "DM me" / "DM us" patterns)
    if afterPos > msgLen then return false end
    local charAfter = string_sub(lowerMsg, afterPos, afterPos)
    if charAfter ~= " " then return false end
    
    -- Check for "me" or "us" after the space
    local wordStart = afterPos + 1
    if wordStart > msgLen then return false end
    
    -- Check for "me"
    if wordStart + 1 <= msgLen then
      local nextWord = string_sub(lowerMsg, wordStart, wordStart + 1)
      if nextWord == "me" then
        -- Verify word boundary after "me"
        local afterMe = wordStart + 2
        if afterMe > msgLen or not string_find(string_sub(lowerMsg, afterMe, afterMe), "[%w]") then
          return true  -- "DM me" - reject as direct message
        end
      end
      if nextWord == "us" then
        -- Verify word boundary after "us"
        local afterUs = wordStart + 2
        if afterUs > msgLen or not string_find(string_sub(lowerMsg, afterUs, afterUs), "[%w]") then
          return true  -- "DM us" - reject as direct message
        end
      end
    end
    
    return false
  end
}

-- =====================================================
-- TAG EXCLUSION HELPER FUNCTION
-- =====================================================

-- [ IsTagExcluded ]
-- Helper function to check tag exclusions.
-- Returns true if the match should be REJECTED (is a false positive).
--
-- @param tag       [string] The lowercase tag being matched
-- @param lowerMsg  [string] The lowercase message string
-- @param foundPos  [number] Position where tag was found
-- @param tagLen    [number] Length of the tag
-- @return          [boolean] true if match should be rejected, false if valid
function DBB2.env.IsTagExcluded(tag, lowerMsg, foundPos, tagLen)
  -- Global exclusion: reject matches inside hyperlink brackets |h[...]|h
  -- This prevents item/spell/quest links like [Maul] from matching tags
  -- Only excludes REAL hyperlinks (with |h prefix), not manually typed [brackets]
  -- Search backwards for '[' and check if preceded by '|h'
  local bracketStart = nil
  for i = foundPos, 1, -1 do
    local char = string_sub(lowerMsg, i, i)
    if char == "[" then
      -- Check if this bracket is part of a hyperlink (preceded by |h)
      if i >= 3 then
        local prefix = string_sub(lowerMsg, i - 2, i - 1)
        if prefix == "|h" then
          bracketStart = i
        end
      end
      break
    elseif char == "]" then
      break
    end
  end
  
  if bracketStart then
    local matchEnd = foundPos + tagLen - 1
    local msgLen = string_len(lowerMsg)
    for i = matchEnd, msgLen do
      local char = string_sub(lowerMsg, i, i)
      if char == "]" then
        -- Check if followed by |h (closing hyperlink)
        if i + 2 <= msgLen then
          local suffix = string_sub(lowerMsg, i + 1, i + 2)
          if suffix == "|h" then
            return true  -- Match is inside |h[...]|h hyperlink - reject it
          end
        end
        break
      elseif char == "[" then
        break
      end
    end
  end
  
  -- Check tag-specific exclusions
  local exclusions = DBB2.env.tagExclusions[tag]
  if not exclusions then return false end
  
  for _, checkFunc in ipairs(exclusions) do
    if checkFunc(lowerMsg, foundPos, tagLen) then
      return true  -- Match should be rejected
    end
  end
  return false  -- Match is valid
end
