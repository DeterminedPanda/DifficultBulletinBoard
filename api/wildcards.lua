-- DBB2 Wildcards API
-- Provides wildcard pattern matching for Lua 5.0 (WoW 1.12.1)
-- Simple, intuitive syntax familiar to users from file searching

--[[
================================================================================
                          DBB2 WILDCARDS USER GUIDE
================================================================================

This addon supports wildcard patterns for blacklist filtering.
All matching is CASE-INSENSITIVE by default.

--------------------------------------------------------------------------------
                              QUICK REFERENCE
--------------------------------------------------------------------------------

  PATTERN         MEANING                      EXAMPLE
  -------         -------                      -------
  *               Any characters (0 or more)   *day matches "Monday", "day"
  ?               Any single character         P?rt matches "Part", "Port"
  [abc]           Any of these characters      [aeiou] matches any vowel
  [a-z]           Character range              [0-9] matches any digit
  [!abc]          NOT these characters         [!0-9] matches non-digits
  {a,b,c}         Any of these words           {cat,dog} matches "cat" or "dog"
]]

-- Localize frequently used globals
local string_find = string.find
local string_sub = string.sub
local string_gsub = string.gsub
local string_len = string.len
local string_lower = string.lower
local string_byte = string.byte
local table_insert = table.insert
local table_getn = table.getn
local ipairs = ipairs

-- Initialize wildcards API namespace
DBB2.api.wildcards = {}

-- [ ConvertWildcardToLua ]
-- Converts a wildcard pattern to a Lua pattern
-- Supports: * ? [abc] [a-z] [!abc] {a,b,c}
-- 'wildcard'   [string]        the wildcard pattern
-- return:      [string/table]  Lua pattern string, or table of patterns for alternation
local function ConvertWildcardToLua(wildcard)
  if not wildcard or wildcard == "" then return "" end
  
  local len = string_len(wildcard)
  local result = ""
  local i = 1
  local alternations = nil  -- Will hold {a,b,c} expansions if found
  
  while i <= len do
    local c = string_sub(wildcard, i, i)
    local nextChar = ""
    if i < len then nextChar = string_sub(wildcard, i+1, i+1) end
    
    if c == "\\" and nextChar ~= "" then
      -- Escaped character - treat next char as literal
      -- Escape it for Lua pattern if needed
      if string_find(nextChar, "[%(%)%.%%%+%-%*%?%[%]%^%$]") then
        result = result .. "%" .. nextChar
      else
        result = result .. nextChar
      end
      i = i + 2
      
    elseif c == "*" then
      -- * = zero or more of any character
      result = result .. ".*"
      i = i + 1
      
    elseif c == "?" then
      -- ? = exactly one character
      result = result .. "."
      i = i + 1
      
    elseif c == "[" then
      -- Character class: [abc], [a-z], [!abc]
      local classEnd = string_find(wildcard, "]", i + 1, true)
      if classEnd then
        local classContent = string_sub(wildcard, i + 1, classEnd - 1)
        
        -- Check for negation [!...]
        if string_sub(classContent, 1, 1) == "!" then
          -- Convert [!abc] to [^abc]
          result = result .. "[^" .. string_sub(classContent, 2) .. "]"
        else
          -- Pass through as-is (Lua supports [abc] and [a-z])
          result = result .. "[" .. classContent .. "]"
        end
        i = classEnd + 1
      else
        -- No closing bracket, treat [ as literal
        result = result .. "%["
        i = i + 1
      end
      
    elseif c == "{" then
      -- Alternation: {a,b,c}
      local braceEnd = string_find(wildcard, "}", i + 1, true)
      if braceEnd then
        local altContent = string_sub(wildcard, i + 1, braceEnd - 1)
        -- IMPORTANT: Use the original wildcard prefix, not the converted result
        -- 'result' contains Lua patterns (e.g., ".*"), but we need the original
        -- wildcard syntax (e.g., "*") for recursive conversion
        local beforeWildcard = string_sub(wildcard, 1, i - 1)
        local after = string_sub(wildcard, braceEnd + 1)
        
        -- Split by comma and create multiple patterns
        alternations = {}
        local altStart = 1
        local altLen = string_len(altContent)
        
        for j = 1, altLen do
          local ac = string_sub(altContent, j, j)
          if ac == "," then
            local alt = string_sub(altContent, altStart, j - 1)
            table_insert(alternations, alt)
            altStart = j + 1
          end
        end
        -- Don't forget the last alternative
        if altStart <= altLen then
          table_insert(alternations, string_sub(altContent, altStart))
        end
        
        -- Build full patterns for each alternative
        local fullPatterns = {}
        for _, alt in ipairs(alternations) do
          -- Recursively convert using original wildcard syntax (not Lua patterns)
          local altPattern = ConvertWildcardToLua(beforeWildcard .. alt .. after)
          if type(altPattern) == "table" then
            -- Nested alternation - flatten
            for _, p in ipairs(altPattern) do
              table_insert(fullPatterns, p)
            end
          else
            table_insert(fullPatterns, altPattern)
          end
        end
        return fullPatterns
      else
        -- No closing brace, treat { as literal
        result = result .. "%{"
        i = i + 1
      end
      
    elseif c == "}" then
      -- Unmatched }, treat as literal
      result = result .. "%}"
      i = i + 1
      
    elseif c == "]" then
      -- Unmatched ], treat as literal
      result = result .. "%]"
      i = i + 1
      
    else
      -- Regular character - escape if it's a Lua pattern special char
      if string_find(c, "[%(%)%.%%%+%-%^%$]") then
        result = result .. "%" .. c
      else
        result = result .. c
      end
      i = i + 1
    end
  end
  
  return result
end

-- [ IsWildcardPattern ]
-- Checks if a string contains wildcard special characters
-- 'pattern'    [string]        the pattern to check
-- return:      [boolean]       true if contains wildcard syntax
function DBB2.api.wildcards.IsWildcardPattern(pattern)
  if not pattern then return false end
  -- Check for wildcard metacharacters: * ? [ ] { }
  -- Also check for escape sequences which indicate intentional pattern usage
  if string_find(pattern, "[%*%?%[%]%{%}\\]") then
    return true
  end
  return false
end

-- [ Match ]
-- Tests if a wildcard pattern matches anywhere in the text
-- 'text'       [string]        the text to search in
-- 'wildcard'   [string]        the wildcard pattern
-- 'ignoreCase' [boolean]       if true (default), match case-insensitively
-- return:      [boolean]       true if pattern matches
function DBB2.api.wildcards.Match(text, wildcard, ignoreCase)
  if not text or not wildcard then return false end
  if wildcard == "" then return true end
  
  if ignoreCase == nil then ignoreCase = true end
  
  local searchText = text
  local searchWildcard = wildcard
  
  if ignoreCase then
    searchText = string_lower(text)
    searchWildcard = string_lower(wildcard)
  end
  
  local pattern = ConvertWildcardToLua(searchWildcard)
  
  if type(pattern) == "table" then
    -- Has alternations - try each pattern
    for _, p in ipairs(pattern) do
      local success, result = pcall(string_find, searchText, p)
      if success and result then
        return true
      end
    end
    return false
  else
    -- Single pattern
    local success, result = pcall(string_find, searchText, pattern)
    return success and result ~= nil
  end
end

-- [ Find ]
-- Finds the first match of a wildcard pattern in text
-- 'text'       [string]        the text to search in
-- 'wildcard'   [string]        the wildcard pattern
-- 'ignoreCase' [boolean]       if true (default), match case-insensitively
-- return:      [number, number, string] start, end, matched text (or nil if no match)
function DBB2.api.wildcards.Find(text, wildcard, ignoreCase)
  if not text or not wildcard then return nil end
  if wildcard == "" then return 1, 0, "" end
  
  if ignoreCase == nil then ignoreCase = true end
  
  local searchText = text
  local searchWildcard = wildcard
  
  if ignoreCase then
    searchText = string_lower(text)
    searchWildcard = string_lower(wildcard)
  end
  
  local pattern = ConvertWildcardToLua(searchWildcard)
  
  if type(pattern) == "table" then
    -- Has alternations - try each pattern
    for _, p in ipairs(pattern) do
      local success, s, e = pcall(string_find, searchText, p)
      if success and s then
        return s, e, string_sub(text, s, e)
      end
    end
    return nil
  else
    -- Single pattern
    local success, s, e = pcall(string_find, searchText, pattern)
    if success and s then
      return s, e, string_sub(text, s, e)
    end
    return nil
  end
end

-- [ IsValid ]
-- Checks if a wildcard pattern is valid (won't cause errors)
-- 'wildcard'   [string]        the pattern to validate
-- return:      [boolean, string] true if valid, or false with error message
function DBB2.api.wildcards.IsValid(wildcard)
  if not wildcard then return false, "Pattern is nil" end
  if wildcard == "" then return true, nil end
  
  local pattern = ConvertWildcardToLua(wildcard)
  
  if type(pattern) == "table" then
    -- Check each alternation
    for _, p in ipairs(pattern) do
      local success, result = pcall(string_find, "test", p)
      if not success then
        return false, result
      end
    end
    return true, nil
  else
    local success, result = pcall(string_find, "test", pattern)
    if not success then
      return false, result
    end
    return true, nil
  end
end

-- [ Escape ]
-- Escapes a string so it can be used as a literal in a wildcard pattern
-- 'str'        [string]        the string to escape
-- return:      [string]        escaped string safe for use in patterns
function DBB2.api.wildcards.Escape(str)
  if not str then return "" end
  -- Escape wildcard special characters: * ? [ ] { } \
  local escaped = str
  escaped = string_gsub(escaped, "\\", "\\\\")
  escaped = string_gsub(escaped, "%*", "\\*")
  escaped = string_gsub(escaped, "%?", "\\?")
  escaped = string_gsub(escaped, "%[", "\\[")
  escaped = string_gsub(escaped, "%]", "\\]")
  escaped = string_gsub(escaped, "%{", "\\{")
  escaped = string_gsub(escaped, "%}", "\\}")
  return escaped
end

-- [ GetLuaPattern ]
-- Returns the converted Lua pattern (for debugging)
-- 'wildcard'   [string]        the wildcard pattern
-- return:      [string/table]  Lua pattern(s)
function DBB2.api.wildcards.GetLuaPattern(wildcard)
  return ConvertWildcardToLua(wildcard)
end

-- =====================================================
-- CONVENIENCE WRAPPER (matches old regex API signature)
-- =====================================================

-- [ MatchWildcard ]
-- Convenience wrapper for wildcard matching (exposed at api level)
-- 'text'       [string]        the text to search in
-- 'pattern'    [string]        the wildcard pattern
-- return:      [boolean]       true if pattern matches anywhere in text
function DBB2.api.MatchWildcard(text, pattern)
  return DBB2.api.wildcards.Match(text, pattern, true)
end

