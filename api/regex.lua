-- DBB2 Regex API
-- Provides regex-like pattern matching for Lua 5.0 (WoW 1.12.1)
-- Translates common regex syntax to Lua patterns with extended features

--[[
================================================================================
                            DBB2 REGEX USER GUIDE
================================================================================

This addon supports regex-like patterns for powerful blacklist filtering.
All matching is CASE-INSENSITIVE by default.

--------------------------------------------------------------------------------
                              QUICK REFERENCE
--------------------------------------------------------------------------------

  PATTERN         MEANING                      EXAMPLE
  -------         -------                      -------
  .               Any single character         a.c matches "abc", "aXc"
  .*              Any characters (0 or more)   a.*z matches "az", "abcz"
  .+              Any characters (1 or more)   a.+z matches "abz", not "az"
  .?              Any character (0 or 1)       colou?r matches "color", "colour"
  
  [abc]           Any of these characters      [aeiou] matches any vowel
  [^abc]          NOT these characters         [^0-9] matches non-digits
  [a-z]           Character range              [a-zA-Z] matches any letter
  [0-9]           Digit range                  [0-9]+ matches numbers
  
  \d              Any digit (0-9)              \d+ matches "123", "5000"
  \D              Any non-digit                \D+ matches "abc", "hello"
  \w              Word char (letter/digit/_)   \w+ matches "hello_world"
  \W              Non-word character           \W matches spaces, punctuation
  \s              Whitespace (space/tab)       \s+ matches spaces
  \S              Non-whitespace               \S+ matches words
  
  *               Zero or more                 ab*c matches "ac", "abc", "abbc"
  +               One or more                  ab+c matches "abc", "abbc"
  ?               Optional (zero or one)       https? matches "http", "https"
  
  ^               Start of message             ^WTS matches "WTS sword"
  $               End of message               gold$ matches "selling gold"
  
  |               OR (alternation)             cat|dog matches either
  (...)           Grouping                     (ab)+ matches "ab", "abab"

--------------------------------------------------------------------------------
                           PRACTICAL EXAMPLES
--------------------------------------------------------------------------------

GUILD RECRUITMENT SPAM:
  <.*>                          Matches any guild tag: <My Guild>, <Phoenix>
  recruit|recruiting            Matches "recruit" or "recruiting"
  guild.*recruit                Matches "guild is recruiting", "guild now recruiting"
  <.*>.*recruit                 Guild tag followed by "recruit"

TRADE SPAM:
  wts|wtb|selling|buying        Common trade keywords
  \d+g                          Gold amounts: 500g, 1000g, 50000g
  \d+\s*gold                    "500 gold", "1000gold"
  (wts|wtb).*\d+g               Trade with gold amount

BOOST/CARRY SPAM:
  boost|carry|run               Common boost keywords
  (boost|carry).*\d+g           Boost service with price
  gdkp|gbid                     GDKP/gold bid runs

LFG SPAM:
  lf\d*m                        Matches "lfm", "lf2m", "lf3m"
  (lf|lfm|lfg).*               Any LFG message

--------------------------------------------------------------------------------
                              IMPORTANT NOTES
--------------------------------------------------------------------------------

1. CASE INSENSITIVE: "WTS" matches "wts", "Wts", "WTS"

2. ESCAPE SPECIAL CHARS: To match literal . * + ? [ ] ( ) ^ $ | \ < >
   put a backslash before them: \. \* \+ \? \[ \] \( \) \^ \$ \| \\ \< \>

3. COMMAS SEPARATE PATTERNS: In the blacklist, use commas to separate
   different patterns. Each pattern is tested independently.
   Example: <.*>,wts|wtb,\d+g (three separate patterns)

4. PATTERNS ARE TESTED LIVE: Your blacklist patterns are applied in real-time
   to incoming chat messages. Invalid patterns are safely ignored.

--------------------------------------------------------------------------------
                            NOT SUPPORTED
--------------------------------------------------------------------------------

These regex features are NOT available due to Lua 5.0 limitations:

  \b            Word boundaries
  {n} {n,m}     Counted quantifiers (use * + ? instead)
  \1 \2         Backreferences
  (?=...) (?!...) Lookahead/lookbehind
  (?:...)       Non-capturing groups

================================================================================
]]

-- Localize frequently used globals
local string_find = string.find
local string_sub = string.sub
local string_gsub = string.gsub
local string_len = string.len
local string_lower = string.lower
local table_insert = table.insert
local table_getn = table.getn
local ipairs = ipairs
local tonumber = tonumber

-- Initialize regex API namespace
DBB2.api.regex = {}

-- Convert regex pattern to Lua pattern
local function ConvertRegexToLua(regex)
  if not regex or regex == "" then return "" end
  
  local len = string_len(regex)
  local depth = 0
  local hasAlt = false
  local inCharClass = false
  
  -- First pass: check for top-level alternation (outside char classes)
  for j = 1, len do
    local c = string_sub(regex, j, j)
    local prev = ""
    if j > 1 then prev = string_sub(regex, j-1, j-1) end
    
    if prev ~= "\\" then
      if c == "[" and not inCharClass then
        inCharClass = true
      elseif c == "]" and inCharClass then
        inCharClass = false
      elseif not inCharClass then
        if c == "(" then
          depth = depth + 1
        elseif c == ")" then
          depth = depth - 1
        elseif c == "|" and depth == 0 then
          hasAlt = true
          break
        end
      end
    end
  end
  
  -- Handle alternation by splitting and converting each part
  if hasAlt then
    local alternatives = {}
    local current = ""
    depth = 0
    inCharClass = false
    
    for j = 1, len do
      local c = string_sub(regex, j, j)
      local prev = ""
      if j > 1 then prev = string_sub(regex, j-1, j-1) end
      
      if prev ~= "\\" then
        if c == "[" and not inCharClass then
          inCharClass = true
          current = current .. c
        elseif c == "]" and inCharClass then
          inCharClass = false
          current = current .. c
        elseif not inCharClass then
          if c == "(" then
            depth = depth + 1
            current = current .. c
          elseif c == ")" then
            depth = depth - 1
            current = current .. c
          elseif c == "|" and depth == 0 then
            if current ~= "" then
              table_insert(alternatives, ConvertRegexToLua(current))
            end
            current = ""
          else
            current = current .. c
          end
        else
          current = current .. c
        end
      else
        current = current .. c
      end
    end
    
    if current ~= "" then
      table_insert(alternatives, ConvertRegexToLua(current))
    end
    
    return nil, alternatives
  end
  
  -- No alternation - convert the pattern character by character
  local result = ""
  local i = 1
  inCharClass = false
  
  while i <= len do
    local c = string_sub(regex, i, i)
    local nextChar = ""
    if i < len then nextChar = string_sub(regex, i+1, i+1) end
    
    -- Inside character class - most chars are literal
    if inCharClass then
      if c == "]" then
        inCharClass = false
        result = result .. "]"
        i = i + 1
      elseif c == "\\" and nextChar ~= "" then
        -- Handle escapes inside character class
        if nextChar == "d" then
          result = result .. "0-9"
        elseif nextChar == "w" then
          result = result .. "a-zA-Z0-9_"
        elseif nextChar == "s" then
          result = result .. " \t\n"
        else
          result = result .. nextChar
        end
        i = i + 2
      else
        -- Pass through literally (including - for ranges)
        result = result .. c
        i = i + 1
      end
    elseif c == "[" then
      -- Start character class
      inCharClass = true
      result = result .. "["
      i = i + 1
    elseif c == "\\" then
      -- Handle escape sequences
      if nextChar == "d" then
        result = result .. "%d"
        i = i + 2
      elseif nextChar == "D" then
        result = result .. "%D"
        i = i + 2
      elseif nextChar == "w" then
        result = result .. "[%w_]"
        i = i + 2
      elseif nextChar == "W" then
        result = result .. "[^%w_]"
        i = i + 2
      elseif nextChar == "s" then
        result = result .. "%s"
        i = i + 2
      elseif nextChar == "S" then
        result = result .. "%S"
        i = i + 2
      elseif nextChar == "b" then
        -- Word boundary - not fully supported, skip
        i = i + 2
      elseif nextChar == "n" then
        result = result .. "\n"
        i = i + 2
      elseif nextChar == "t" then
        result = result .. "\t"
        i = i + 2
      elseif nextChar == "\\" then
        result = result .. "%%"
        i = i + 2
      else
        -- Escaped special character - make it literal
        result = result .. "%" .. nextChar
        i = i + 2
      end
    elseif c == "<" or c == ">" then
      -- Angle brackets need escaping in Lua patterns
      result = result .. "%" .. c
      i = i + 1
    elseif c == "." or c == "*" or c == "+" or c == "?" or c == "^" or c == "$" then
      -- These work the same in Lua patterns
      result = result .. c
      i = i + 1
    elseif c == "(" then
      -- Handle groups - need to check for alternation inside
      local groupDepth = 1
      local groupEnd = i + 1
      local groupInClass = false
      while groupEnd <= len and groupDepth > 0 do
        local gc = string_sub(regex, groupEnd, groupEnd)
        local gprev = ""
        if groupEnd > 1 then gprev = string_sub(regex, groupEnd-1, groupEnd-1) end
        if gprev ~= "\\" then
          if gc == "[" and not groupInClass then
            groupInClass = true
          elseif gc == "]" and groupInClass then
            groupInClass = false
          elseif not groupInClass then
            if gc == "(" then groupDepth = groupDepth + 1
            elseif gc == ")" then groupDepth = groupDepth - 1
            end
          end
        end
        groupEnd = groupEnd + 1
      end
      
      local groupContent = string_sub(regex, i+1, groupEnd-2)
      local converted, alts = ConvertRegexToLua(groupContent)
      
      if alts then
        -- Group has alternation - keep original syntax for ExpandGroupAlternation to handle
        result = result .. "(" .. groupContent .. ")"
      else
        result = result .. "(" .. converted .. ")"
      end
      i = groupEnd
    elseif c == ")" then
      result = result .. ")"
      i = i + 1
    elseif c == "|" then
      -- Should have been handled at top level
      result = result .. "|"
      i = i + 1
    else
      -- Regular character - escape if it's a Lua pattern special char
      if string_find(c, "[%(%)%.%%%+%-%*%?%[%]%^%$]") then
        result = result .. "%" .. c
      else
        result = result .. c
      end
      i = i + 1
    end
  end
  
  return result
end

-- Expand optional groups (...)? into multiple patterns
-- e.g., "recruit(ing)?" becomes {"recruit", "recruiting"}
local function ExpandOptionalGroups(regex)
  if not regex or regex == "" then return {regex} end
  
  local patterns = {regex}
  local changed = true
  
  while changed do
    changed = false
    local newPatterns = {}
    
    for _, pat in ipairs(patterns) do
      -- Find an optional group: (content)?
      -- Pattern: find ( followed by content (no nested parens for simplicity), then )?
      local groupStart, groupEnd, groupContent = string_find(pat, "%(([^()]*)%)%?")
      
      if groupStart then
        changed = true
        -- Create two patterns: one without the group content, one with it
        local before = string_sub(pat, 1, groupStart - 1)
        local after = string_sub(pat, groupEnd + 1)
        
        -- Pattern without the optional group
        table_insert(newPatterns, before .. after)
        -- Pattern with the optional group content included
        table_insert(newPatterns, before .. groupContent .. after)
      else
        table_insert(newPatterns, pat)
      end
    end
    
    patterns = newPatterns
  end
  
  return patterns
end

-- Expand groups with alternation into multiple patterns
local function ExpandGroupAlternation(regex)
  if not regex or regex == "" then return {regex} end
  
  -- First expand optional groups
  local patterns = ExpandOptionalGroups(regex)
  local changed = true
  
  while changed do
    changed = false
    local newPatterns = {}
    
    for _, pat in ipairs(patterns) do
      -- Find a group with alternation
      local groupStart, groupEnd, groupContent = string_find(pat, "%(([^()]*|[^()]*)%)")
      
      if groupStart and string_find(groupContent, "|") then
        changed = true
        -- Split the alternation
        local alts = {}
        for alt in string.gfind(groupContent, "([^|]+)") do
          table_insert(alts, alt)
        end
        -- Create new patterns for each alternative
        for _, alt in ipairs(alts) do
          local newPat = string_sub(pat, 1, groupStart-1) .. alt .. string_sub(pat, groupEnd+1)
          table_insert(newPatterns, newPat)
        end
      else
        table_insert(newPatterns, pat)
      end
    end
    
    patterns = newPatterns
  end
  
  return patterns
end

-- Test if a regex pattern matches anywhere in the text
function DBB2.api.regex.Match(text, regex, ignoreCase)
  if not text or not regex then return false end
  if regex == "" then return true end
  
  if ignoreCase == nil then ignoreCase = true end
  
  local searchText = text
  local searchRegex = regex
  
  if ignoreCase then
    searchText = string_lower(text)
    -- Lowercase the regex but preserve escape sequences
    -- We need to be careful not to lowercase the char after backslash
    local result = ""
    local i = 1
    local len = string_len(regex)
    while i <= len do
      local c = string_sub(regex, i, i)
      if c == "\\" and i < len then
        -- Keep escape sequence as-is
        result = result .. c .. string_sub(regex, i+1, i+1)
        i = i + 2
      else
        result = result .. string_lower(c)
        i = i + 1
      end
    end
    searchRegex = result
  end
  
  local pattern, alternatives = ConvertRegexToLua(searchRegex)
  
  if alternatives then
    -- Has top-level alternation - try each alternative
    for _, alt in ipairs(alternatives) do
      -- Expand any group alternations
      local expanded = ExpandGroupAlternation(alt)
      for _, exp in ipairs(expanded) do
        if string_find(searchText, exp) then
          return true
        end
      end
    end
    return false
  else
    -- Single pattern - expand any group alternations
    local expanded = ExpandGroupAlternation(pattern)
    for _, exp in ipairs(expanded) do
      if string_find(searchText, exp) then
        return true
      end
    end
    return false
  end
end

-- Find the first match of a regex pattern in text
function DBB2.api.regex.Find(text, regex, ignoreCase)
  if not text or not regex then return nil end
  if regex == "" then return 1, 0, "" end
  
  local searchText = text
  local searchRegex = regex
  
  if ignoreCase == nil then ignoreCase = true end
  
  if ignoreCase then
    searchText = string_lower(text)
    -- Lowercase the regex but preserve escape sequences
    local result = ""
    local i = 1
    local len = string_len(regex)
    while i <= len do
      local c = string_sub(regex, i, i)
      if c == "\\" and i < len then
        result = result .. c .. string_sub(regex, i+1, i+1)
        i = i + 2
      else
        result = result .. string_lower(c)
        i = i + 1
      end
    end
    searchRegex = result
  end
  
  local pattern, alternatives = ConvertRegexToLua(searchRegex)
  
  if alternatives then
    for _, alt in ipairs(alternatives) do
      local expanded = ExpandGroupAlternation(alt)
      for _, exp in ipairs(expanded) do
        local s, e = string_find(searchText, exp)
        if s then
          return s, e, string_sub(text, s, e)
        end
      end
    end
    return nil
  else
    local expanded = ExpandGroupAlternation(pattern)
    for _, exp in ipairs(expanded) do
      local s, e = string_find(searchText, exp)
      if s then
        return s, e, string_sub(text, s, e)
      end
    end
    return nil
  end
end

-- Alias for Match (familiar name for JS users)
function DBB2.api.regex.Test(text, regex, ignoreCase)
  return DBB2.api.regex.Match(text, regex, ignoreCase)
end

-- Check if a regex pattern is valid
function DBB2.api.regex.IsValid(regex)
  if not regex then return false, "Pattern is nil" end
  if regex == "" then return true, nil end
  
  local pattern, alternatives = ConvertRegexToLua(regex)
  local ok = true
  local err = nil
  
  if alternatives then
    for _, alt in ipairs(alternatives) do
      local success, result = pcall(string_find, "test", alt)
      if not success then
        ok = false
        err = result
        break
      end
    end
  else
    local success, result = pcall(string_find, "test", pattern)
    if not success then
      ok = false
      err = result
    end
  end
  
  return ok, err
end

-- Get the converted Lua pattern (for debugging)
function DBB2.api.regex.GetLuaPattern(regex)
  return ConvertRegexToLua(regex)
end

-- Escape a string so it can be used as a literal in a regex pattern
function DBB2.api.regex.Escape(str)
  if not str then return "" end
  return string_gsub(str, "([%(%)%.%%%+%-%*%?%[%]%^%$|\\<>])", "\\%1")
end

-- Convenience wrapper for regex matching (exposed at api level)
-- 'text'    [string] the text to search in
-- 'pattern' [string] the regex pattern
-- return:   [boolean] true if pattern matches anywhere in text
function DBB2.api.MatchRegex(text, pattern)
  return DBB2.api.regex.Match(text, pattern, true)
end
