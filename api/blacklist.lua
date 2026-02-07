-- DBB2 Blacklist API
-- Handles player and keyword blocking for message filtering
--
-- Dependencies: env/defaults.lua, api/wildcards.lua
-- This file must be loaded BEFORE chat_filter.lua

-- Localize frequently used globals for performance
local string_lower = string.lower
local string_find = string.find
local string_sub = string.sub
local string_len = string.len
local table_insert = table.insert
local table_remove = table.remove
local table_getn = table.getn
local ipairs = ipairs

-- [ InitBlacklist ]
-- Initializes blacklist config if not present
-- Uses DBB2.env.defaultBlacklistKeywords from env/defaults.lua
function DBB2.api.InitBlacklist()
  if not DBB2_Config.blacklist then
    DBB2_Config.blacklist = {
      enabled = true,
      hideFromChat = true,  -- Hide blacklisted messages from chat (enabled by default)
      players = {},
      keywords = DBB2.api.DeepCopy(DBB2.env.defaultBlacklistKeywords)
    }
  end
  -- Ensure all fields exist
  if DBB2_Config.blacklist.enabled == nil then
    DBB2_Config.blacklist.enabled = false
  end
  if DBB2_Config.blacklist.hideFromChat == nil then
    DBB2_Config.blacklist.hideFromChat = true  -- Default to enabled
  end
  if not DBB2_Config.blacklist.players then
    DBB2_Config.blacklist.players = {}
  end
  if not DBB2_Config.blacklist.keywords then
    DBB2_Config.blacklist.keywords = DBB2.api.DeepCopy(DBB2.env.defaultBlacklistKeywords)
  end
end

-- [ IsBlacklistEnabled ]
-- Returns whether blacklist filtering is enabled
function DBB2.api.IsBlacklistEnabled()
  DBB2.api.InitBlacklist()
  return DBB2_Config.blacklist.enabled
end

-- [ SetBlacklistEnabled ]
-- Enables or disables blacklist filtering
function DBB2.api.SetBlacklistEnabled(enabled)
  DBB2.api.InitBlacklist()
  DBB2_Config.blacklist.enabled = enabled
end

-- [ IsBlacklistHideFromChatEnabled ]
-- Returns whether hiding blacklisted messages from chat is enabled
function DBB2.api.IsBlacklistHideFromChatEnabled()
  DBB2.api.InitBlacklist()
  return DBB2_Config.blacklist.hideFromChat
end

-- [ SetBlacklistHideFromChat ]
-- Enables or disables hiding blacklisted messages from chat
function DBB2.api.SetBlacklistHideFromChat(enabled)
  DBB2.api.InitBlacklist()
  DBB2_Config.blacklist.hideFromChat = enabled
end

-- [ AddPlayerToBlacklist ]
-- Adds a player name to the blacklist
function DBB2.api.AddPlayerToBlacklist(playerName)
  DBB2.api.InitBlacklist()
  if not playerName or playerName == "" then return false end
  
  local lowerName = string_lower(playerName)
  -- Check if already exists
  for _, name in ipairs(DBB2_Config.blacklist.players) do
    if string_lower(name) == lowerName then
      return false
    end
  end
  
  table_insert(DBB2_Config.blacklist.players, playerName)
  return true
end

-- [ RemovePlayerFromBlacklist ]
-- Removes a player name from the blacklist
function DBB2.api.RemovePlayerFromBlacklist(playerName)
  DBB2.api.InitBlacklist()
  local lowerName = string_lower(playerName or "")
  
  for i = table_getn(DBB2_Config.blacklist.players), 1, -1 do
    if string_lower(DBB2_Config.blacklist.players[i]) == lowerName then
      table_remove(DBB2_Config.blacklist.players, i)
      return true
    end
  end
  return false
end

-- [ IsPlayerBlacklisted ]
-- Checks if a player is blacklisted
function DBB2.api.IsPlayerBlacklisted(playerName)
  DBB2.api.InitBlacklist()
  if not DBB2_Config.blacklist.enabled then return false end
  
  local lowerName = string_lower(playerName or "")
  for _, name in ipairs(DBB2_Config.blacklist.players) do
    if string_lower(name) == lowerName then
      return true
    end
  end
  return false
end

-- [ GetBlacklistedPlayers ]
-- Returns the list of blacklisted players
function DBB2.api.GetBlacklistedPlayers()
  DBB2.api.InitBlacklist()
  return DBB2_Config.blacklist.players
end

-- [ AddKeywordToBlacklist ]
-- Adds a keyword to the blacklist
function DBB2.api.AddKeywordToBlacklist(keyword)
  DBB2.api.InitBlacklist()
  if not keyword or keyword == "" then return false end
  
  local lowerKeyword = string_lower(keyword)
  -- Check if already exists
  for _, kw in ipairs(DBB2_Config.blacklist.keywords) do
    if string_lower(kw) == lowerKeyword then
      return false
    end
  end
  
  table_insert(DBB2_Config.blacklist.keywords, keyword)
  return true
end

-- [ RemoveKeywordFromBlacklist ]
-- Removes a keyword from the blacklist
function DBB2.api.RemoveKeywordFromBlacklist(keyword)
  DBB2.api.InitBlacklist()
  local lowerKeyword = string_lower(keyword or "")
  
  for i = table_getn(DBB2_Config.blacklist.keywords), 1, -1 do
    if string_lower(DBB2_Config.blacklist.keywords[i]) == lowerKeyword then
      table_remove(DBB2_Config.blacklist.keywords, i)
      return true
    end
  end
  return false
end

-- [ GetBlacklistedKeywords ]
-- Returns the list of blacklisted keywords
function DBB2.api.GetBlacklistedKeywords()
  DBB2.api.InitBlacklist()
  return DBB2_Config.blacklist.keywords
end

-- [ IsKeywordWildcardPattern ]
-- Checks if a keyword contains wildcard special characters (meaning it's a pattern)
-- Plain keywords get word boundary treatment, wildcard patterns are used as-is
-- 'keyword'    [string]        the keyword to check
-- return:      [boolean]       true if keyword contains wildcard syntax
function DBB2.api.IsKeywordWildcardPattern(keyword)
  if not keyword then return false end
  -- Check for wildcard metacharacters: * ? [ ] { } \
  if string_find(keyword, "[%*%?%[%]%{%}\\]") then
    return true
  end
  return false
end

-- [ MatchKeywordWithBoundary ]
-- Matches a plain keyword with word boundary rules:
-- - Keyword must not be preceded by a letter/number
-- - Keyword must not be followed by a letter/number (but punctuation is OK)
-- This prevents "na" from matching "naxx" but allows "na!" or "na?"
-- 'text'       [string]        the text to search in (should be lowercase)
-- 'keyword'    [string]        the keyword to find (should be lowercase)
-- return:      [boolean]       true if keyword matches with proper boundaries
function DBB2.api.MatchKeywordWithBoundary(text, keyword)
  if not text or not keyword then return false end
  
  local keywordLen = string_len(keyword)
  local textLen = string_len(text)
  local startPos = 1
  
  while startPos <= textLen do
    -- Find the keyword in text (plain search)
    local foundStart, foundEnd = string_find(text, keyword, startPos, true)
    if not foundStart then
      return false
    end
    
    -- Check character before the match (must not be alphanumeric)
    local validStart = true
    if foundStart > 1 then
      local charBefore = string_sub(text, foundStart - 1, foundStart - 1)
      if string_find(charBefore, "[%w]") then
        validStart = false
      end
    end
    
    -- Check character after the match (must not be alphanumeric)
    local validEnd = true
    if foundEnd < textLen then
      local charAfter = string_sub(text, foundEnd + 1, foundEnd + 1)
      if string_find(charAfter, "[%w]") then
        validEnd = false
      end
    end
    
    if validStart and validEnd then
      return true
    end
    
    -- Continue searching from after this match
    startPos = foundStart + 1
  end
  
  return false
end

-- [ IsMessageBlacklistedByKeyword ]
-- Checks if a message contains any blacklisted keyword
-- Plain keywords: matched with word boundaries (won't match inside other words)
--   e.g., "na" matches "na", "na!", "na?" but NOT "naxx"
-- Wildcard keywords: matched using wildcard API (for pattern matching)
--   e.g., "na*" would match "naxx" if you want loose matching
-- Returns: matched (boolean), matchedKeywords (table of matched keyword strings)
function DBB2.api.IsMessageBlacklistedByKeyword(message)
  DBB2.api.InitBlacklist()
  if not DBB2_Config.blacklist.enabled then return false, {} end
  if not message then return false, {} end
  
  local matchedKeywords = {}
  local lowerMessage = string_lower(message)
  
  for _, keyword in ipairs(DBB2_Config.blacklist.keywords) do
    local matched = false
    
    if DBB2.api.IsKeywordWildcardPattern(keyword) then
      -- Wildcard pattern: use wildcards API for matching (case-insensitive)
      if DBB2.api.wildcards and DBB2.api.wildcards.Match then
        matched = DBB2.api.wildcards.Match(message, keyword, true)
      end
    else
      -- Plain keyword: use word boundary matching
      local lowerKeyword = string_lower(keyword)
      matched = DBB2.api.MatchKeywordWithBoundary(lowerMessage, lowerKeyword)
    end
    
    if matched then
      table_insert(matchedKeywords, keyword)
    end
  end
  
  return table_getn(matchedKeywords) > 0, matchedKeywords
end

-- [ IsMessageBlacklisted ]
-- Checks if a message should be filtered (player or keyword)
-- Returns: blocked (boolean), reason (string: "player" or "keyword"), details (string or table)
function DBB2.api.IsMessageBlacklisted(message, sender)
  if not DBB2.api.IsBlacklistEnabled() then return false, nil, nil end
  
  if DBB2.api.IsPlayerBlacklisted(sender) then
    return true, "player", sender
  end
  
  local keywordBlocked, matchedKeywords = DBB2.api.IsMessageBlacklistedByKeyword(message)
  if keywordBlocked then
    return true, "keyword", matchedKeywords
  end
  
  return false, nil, nil
end
