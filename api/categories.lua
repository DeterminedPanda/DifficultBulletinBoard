-- DBB2 Categories API
-- Category management functions for message filtering
--
-- NOTE: Default category data and initialization is in modules/categories.lua
-- This file provides the API functions that operate on category data.

-- Localize frequently used globals for performance
local string_lower = string.lower
local string_find = string.find
local string_sub = string.sub
local string_len = string.len
local string_gfind = string.gfind
local string_gsub = string.gsub
local table_insert = table.insert
local table_concat = table.concat
local table_getn = table.getn
local ipairs = ipairs
local math_abs = math.abs

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

local tagExclusions = {}

-- [ ST exclusion ]
-- "ST" is a tag for Sunken Temple, but also commonly used for "Server Time"
-- Reject matches like "20:30 ST", "8:00 ST", "19:45ST"
-- Pattern: digit(s) + colon + digit(s) + optional space + ST
tagExclusions["st"] = {
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
tagExclusions["dm"] = {
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

-- [ Helper function to check tag exclusions ]
-- Returns true if the match should be REJECTED (is a false positive)
local function IsTagExcluded(tag, lowerMsg, foundPos, tagLen)
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
  local exclusions = tagExclusions[tag]
  if not exclusions then return false end
  
  for _, checkFunc in ipairs(exclusions) do
    if checkFunc(lowerMsg, foundPos, tagLen) then
      return true  -- Match should be rejected
    end
  end
  return false  -- Match is valid
end

-- [ IsCategoryCollapsed ]
-- Returns whether a category is collapsed
-- 'categoryType'  [string]  "groups", "professions", or "hardcore"
-- 'categoryName'  [string]  the category name
-- return:         [boolean] true if collapsed
function DBB2.api.IsCategoryCollapsed(categoryType, categoryName)
  if not categoryType or not categoryName then return false end
  if not DBB2_Config.categoryCollapsed then return false end
  if not DBB2_Config.categoryCollapsed[categoryType] then return false end
  return DBB2_Config.categoryCollapsed[categoryType][categoryName] or false
end

-- [ SetCategoryCollapsed ]
-- Sets the collapsed state of a category
-- 'categoryType'  [string]  "groups", "professions", or "hardcore"
-- 'categoryName'  [string]  the category name
-- 'collapsed'     [boolean] collapsed state
-- return:         [boolean] true if set successfully
function DBB2.api.SetCategoryCollapsed(categoryType, categoryName, collapsed)
  if not categoryType or not categoryName then return false end
  if not DBB2_Config.categoryCollapsed then
    DBB2_Config.categoryCollapsed = {}
  end
  if not DBB2_Config.categoryCollapsed[categoryType] then
    DBB2_Config.categoryCollapsed[categoryType] = {}
  end
  DBB2_Config.categoryCollapsed[categoryType][categoryName] = collapsed
  return true
end

-- [ ToggleCategoryCollapsed ]
-- Toggles the collapsed state of a category
-- 'categoryType'  [string]  "groups", "professions", or "hardcore"
-- 'categoryName'  [string]  the category name
-- return:         [boolean] new collapsed state
function DBB2.api.ToggleCategoryCollapsed(categoryType, categoryName)
  local isCollapsed = DBB2.api.IsCategoryCollapsed(categoryType, categoryName)
  DBB2.api.SetCategoryCollapsed(categoryType, categoryName, not isCollapsed)
  return not isCollapsed
end

-- =====================================================
-- FILTER TAGS API
-- =====================================================
-- Filter tags are additional tags that must ALSO match (in addition to category tags)
-- when enabled. This allows filtering for specific message types like LFG/LFM for groups
-- or LFW/WTB/WTS for professions.

-- [ GetFilterTags ]
-- Returns filter tags config for a category type
-- 'categoryType' [string] "groups" or "professions"
-- return:        [table]  { enabled = bool, tags = {...} }
function DBB2.api.GetFilterTags(categoryType)
  if not categoryType then return nil end
  if not DBB2_Config.filterTags then return nil end
  return DBB2_Config.filterTags[categoryType]
end

-- [ IsFilterTagsEnabled ]
-- Returns whether filter tags are enabled for a category type
-- 'categoryType' [string] "groups" or "professions"
-- return:        [boolean]
function DBB2.api.IsFilterTagsEnabled(categoryType)
  local filter = DBB2.api.GetFilterTags(categoryType)
  if not filter then return false end
  return filter.enabled or false
end

-- [ SetFilterTagsEnabled ]
-- Enables or disables filter tags for a category type
-- 'categoryType' [string]  "groups" or "professions"
-- 'enabled'      [boolean] enabled state
-- return:        [boolean] true if set successfully
function DBB2.api.SetFilterTagsEnabled(categoryType, enabled)
  if not categoryType then return false end
  if not DBB2_Config.filterTags then
    DBB2_Config.filterTags = {}
  end
  if not DBB2_Config.filterTags[categoryType] then
    DBB2_Config.filterTags[categoryType] = { enabled = false, tags = {} }
  end
  DBB2_Config.filterTags[categoryType].enabled = enabled and true or false
  return true
end

-- [ UpdateFilterTags ]
-- Updates filter tags for a category type
-- 'categoryType' [string] "groups" or "professions"
-- 'newTags'      [table]  array of tag strings
-- return:        [boolean] true if updated
function DBB2.api.UpdateFilterTags(categoryType, newTags)
  if not categoryType then return false end
  if not DBB2_Config.filterTags then
    DBB2_Config.filterTags = {}
  end
  if not DBB2_Config.filterTags[categoryType] then
    DBB2_Config.filterTags[categoryType] = { enabled = false, tags = {} }
  end
  DBB2_Config.filterTags[categoryType].tags = newTags or {}
  return true
end

-- [ MatchFilterTags ]
-- Checks if a message matches any of the filter tags for a category type
-- Uses wildcard matching via DBB2.api.MatchWildcard for patterns containing special chars
-- 'message'      [string] the message text
-- 'categoryType' [string] "groups" or "professions"
-- return:        [boolean] true if matches (or if filter is disabled)
function DBB2.api.MatchFilterTags(message, categoryType)
  -- If filter is disabled, always return true (no filtering)
  if not DBB2.api.IsFilterTagsEnabled(categoryType) then
    return true
  end
  
  local filter = DBB2.api.GetFilterTags(categoryType)
  if not filter or not filter.tags then
    return true  -- No tags defined, pass through
  end
  
  -- Quick check: any tags at all?
  local hasAnyTags = false
  for _ in ipairs(filter.tags) do
    hasAnyTags = true
    break
  end
  if not hasAnyTags then
    return true  -- No tags, pass through
  end
  
  local lowerMsg = string_lower(message or "")
  if lowerMsg == "" then return false end
  
  local msgLen = string_len(lowerMsg)
  
  for _, tag in ipairs(filter.tags) do
    local lowerTag = string_lower(tag)
    local tagLen = string_len(lowerTag)
    
    -- Check if tag contains wildcard special characters
    local isWildcard = string_find(lowerTag, "[%*%?%[%]%{%}\\]")
    
    if isWildcard then
      -- Use wildcard matching
      if DBB2.api.MatchWildcard(lowerMsg, lowerTag) then
        return true
      end
    else
      -- Plain text matching with word boundaries
      local startPos = 1
      while true do
        local foundPos = string_find(lowerMsg, lowerTag, startPos, true)
        if not foundPos then
          break
        end
        
        -- Check word boundaries
        local charBefore = ""
        if foundPos > 1 then
          charBefore = string_sub(lowerMsg, foundPos - 1, foundPos - 1)
        end
        
        local afterPos = foundPos + tagLen
        local charAfter = ""
        if afterPos <= msgLen then
          charAfter = string_sub(lowerMsg, afterPos, afterPos)
        end
        
        local validBefore = (foundPos == 1) or not string_find(charBefore, "[%w]")
        local validAfter = (afterPos > msgLen) or not string_find(charAfter, "[%w]")
        
        -- Also allow digits after (like LF1M, LF2M)
        if not validAfter and string_find(charAfter, "%d") then
          local digitEndPos = afterPos
          while digitEndPos <= msgLen and string_find(string_sub(lowerMsg, digitEndPos, digitEndPos), "%d") do
            digitEndPos = digitEndPos + 1
          end
          -- Check for 'M' after digits (for patterns like LF1M, LF2M)
          if digitEndPos <= msgLen then
            local afterDigits = string_sub(lowerMsg, digitEndPos, digitEndPos)
            if string_lower(afterDigits) == "m" then
              digitEndPos = digitEndPos + 1
            end
          end
          -- Check boundary after digits/M
          if digitEndPos > msgLen or not string_find(string_sub(lowerMsg, digitEndPos, digitEndPos), "[%w]") then
            validAfter = true
          end
        end
        
        if validBefore and validAfter then
          return true
        end
        
        startPos = foundPos + 1
      end
    end
  end
  
  return false
end

-- [ GetCategories ]
-- Returns categories for a given type
-- 'categoryType' [string] "groups", "professions", or "hardcore"
-- return:        [table]  array of category objects
function DBB2.api.GetCategories(categoryType)
  if not categoryType then return {} end
  if not DBB2_Config.categories then return {} end
  return DBB2_Config.categories[categoryType] or {}
end

-- [ GetCategoryByName ]
-- Returns a specific category by name
-- 'categoryType'  [string]  "groups", "professions", or "hardcore"
-- 'name'          [string]  the category name
-- return:         [table, number] category object and index, or nil
function DBB2.api.GetCategoryByName(categoryType, name)
  if not categoryType or not name then return nil end
  local cats = DBB2.api.GetCategories(categoryType)
  for i, cat in ipairs(cats) do
    if cat.name == name then
      return cat, i
    end
  end
  return nil
end

-- [ UpdateCategoryTags ]
-- Updates tags for a category
-- Also pre-computes lowercase versions for faster matching
-- 'categoryType'  [string]  "groups", "professions", or "hardcore"
-- 'categoryName'  [string]  the category name
-- 'newTags'       [table]   array of tag strings
-- return:         [boolean] true if updated
function DBB2.api.UpdateCategoryTags(categoryType, categoryName, newTags)
  local cat = DBB2.api.GetCategoryByName(categoryType, categoryName)
  if cat then
    cat.tags = newTags or {}
    -- Pre-compute lowercase tags and their lengths for faster matching
    cat._tagsLower = {}
    cat._tagsLen = {}
    for i, tag in ipairs(cat.tags) do
      local lower = string_lower(tag)
      cat._tagsLower[i] = lower
      cat._tagsLen[i] = string_len(lower)
    end
    return true
  end
  return false
end

-- [ EnsureTagsPrecomputed ]
-- Ensures a category has pre-computed lowercase tags
-- Called internally before matching
local function EnsureTagsPrecomputed(category)
  -- Always recompute if _tagsLower doesn't exist
  if not category._tagsLower then
    category._tagsLower = {}
    category._tagsLen = {}
    for i, tag in ipairs(category.tags or {}) do
      local lower = string_lower(tag)
      category._tagsLower[i] = lower
      category._tagsLen[i] = string_len(lower)
    end
    return
  end
  
  -- Check if tags array length changed (recompute if so)
  local tagsCount = 0
  if category.tags then
    for _ in ipairs(category.tags) do
      tagsCount = tagsCount + 1
    end
  end
  
  local cachedCount = 0
  for _ in ipairs(category._tagsLower) do
    cachedCount = cachedCount + 1
  end
  
  if tagsCount ~= cachedCount then
    category._tagsLower = {}
    category._tagsLen = {}
    for i, tag in ipairs(category.tags or {}) do
      local lower = string_lower(tag)
      category._tagsLower[i] = lower
      category._tagsLen[i] = string_len(lower)
    end
  end
end

-- [ SetCategorySelected ]
-- Enables or disables a category
-- 'categoryType'  [string]  "groups", "professions", or "hardcore"
-- 'categoryName'  [string]  the category name
-- 'selected'      [boolean] selected state
-- return:         [boolean] true if updated
function DBB2.api.SetCategorySelected(categoryType, categoryName, selected)
  local cat = DBB2.api.GetCategoryByName(categoryType, categoryName)
  if cat then
    cat.selected = selected and true or false
    return true
  end
  return false
end

-- [ ParseTagsString ]
-- Converts comma-separated string to tags array
-- 'str'    [string]  comma-separated tags
-- return:  [table]   array of lowercase tag strings
function DBB2.api.ParseTagsString(str)
  local tags = {}
  if not str or str == "" then return tags end
  
  for tag in string_gfind(str, "([^,]+)") do
    -- Trim whitespace
    tag = string_gsub(tag, "^%s*(.-)%s*$", "%1")
    tag = string_lower(tag)
    if tag ~= "" then
      table_insert(tags, tag)
    end
  end
  return tags
end

-- [ TagsToString ]
-- Converts tags array to comma-separated string
-- 'tags'   [table]   array of tag strings
-- return:  [string]  comma-separated string
function DBB2.api.TagsToString(tags)
  if not tags then return "" end
  if table_getn(tags) == 0 then return "" end
  
  -- table.concat is more efficient than manual concatenation
  return table_concat(tags, ", ")
end

-- [ MatchMessageToCategory ]
-- Checks if a message matches any tag in a category
-- Returns true if message contains any of the category's tags as whole words
-- Supports wildcard patterns: * (any chars), ? (one char), [abc], [a-z], [!abc], {a,b,c}
-- Also matches tags followed by 1-2 digits (e.g., "zg15", "ony12") for raid group sizes
-- Special case: "aq" tag only matches with "40" suffix to distinguish from aq20 (Ruins)
-- If filter tags are enabled for the category type, message must ALSO match a filter tag
-- 'message'       [string]  the message text
-- 'category'      [table]   category object with .selected and .tags
-- 'ignoreSelected' [boolean] if true, skip the .selected check (for mode 2 filtering)
-- 'categoryType'  [string]  optional - "groups", "professions", or "hardcore" for filter tag checking
-- return:         [boolean] true if matches
function DBB2.api.MatchMessageToCategory(message, category, ignoreSelected, categoryType)
  if not category then
    return false
  end
  if not ignoreSelected and not category.selected then
    return false
  end
  if not category.tags then
    return false
  end
  
  -- Quick check: any tags at all?
  local hasAnyTags = false
  for _ in ipairs(category.tags) do
    hasAnyTags = true
    break
  end
  if not hasAnyTags then
    return false
  end
  
  local lowerMsg = string_lower(message or "")
  if lowerMsg == "" then return false end
  
  -- Check filter tags first (if enabled for this category type)
  -- This is an AND condition - message must match BOTH filter tags AND category tags
  if categoryType and (categoryType == "groups" or categoryType == "professions") then
    if not DBB2.api.MatchFilterTags(message, categoryType) then
      return false
    end
  end
  
  -- Ensure pre-computed lowercase tags exist
  EnsureTagsPrecomputed(category)
  
  local msgLen = string_len(lowerMsg)
  local tagsLower = category._tagsLower
  local tagsLen = category._tagsLen
  
  -- Use ipairs instead of table.getn for Lua 5.0 compatibility
  for i, lowerTag in ipairs(tagsLower) do
    local tagLen = tagsLen[i]

    -- Check if tag contains wildcard special characters
    local isWildcard = string_find(lowerTag, "[%*%?%[%]%{%}\\]")

    if isWildcard then
      -- Use wildcard matching for patterns
      if DBB2.api.MatchWildcard(lowerMsg, lowerTag) then
        return true
      end
    else
      -- Plain text matching with word boundaries
      local startPos = 1

      while true do
        local foundPos = string_find(lowerMsg, lowerTag, startPos, true)
        if not foundPos then
          break
        end

        -- Check character before the match (must be start or non-alphanumeric)
        local charBefore = ""
        if foundPos > 1 then
          charBefore = string_sub(lowerMsg, foundPos - 1, foundPos - 1)
        end

        -- Check character after the match
        local afterPos = foundPos + tagLen
        local charAfter = ""
        if afterPos <= msgLen then
          charAfter = string_sub(lowerMsg, afterPos, afterPos)
        end

        -- Check if boundaries are word boundaries (not letters or numbers)
        local validBefore = (foundPos == 1) or not string_find(charBefore, "[%w]")

        -- For validAfter, we now allow 1-2 trailing digits (raid group sizes like "zg15", "ony12")
        -- Special case: "aq" tag should only match "aq40" to distinguish from aq20 (Ruins)
        local validAfter = false
        if afterPos > msgLen then
          -- End of message - valid
          validAfter = true
        elseif not string_find(charAfter, "[%w]") then
          -- Non-alphanumeric after - valid word boundary
          validAfter = true
        elseif string_find(charAfter, "%d") then
          -- Digit after tag - check for raid group size pattern (1-2 digits)
          local digit1 = charAfter
          local digit2 = ""
          local charAfterDigits = ""
          local digitEndPos = afterPos + 1

          -- Check for second digit
          if digitEndPos <= msgLen then
            local nextChar = string_sub(lowerMsg, digitEndPos, digitEndPos)
            if string_find(nextChar, "%d") then
              digit2 = nextChar
              digitEndPos = digitEndPos + 1
            end
          end

          -- Check character after the digits
          if digitEndPos <= msgLen then
            charAfterDigits = string_sub(lowerMsg, digitEndPos, digitEndPos)
          end

          -- Valid if digits are followed by word boundary
          local digitsFollowedByBoundary = (digitEndPos > msgLen) or not string_find(charAfterDigits, "[%w]")

          if digitsFollowedByBoundary then
            -- Special handling for "aq" tag to distinguish Temple (40-man) from Ruins (20-man)
            -- "aq40" -> Temple of Ahn'Qiraj only
            -- "aq" + any other number (aq13, aq15, aq20, etc.) -> Ruins of Ahn'Qiraj
            if lowerTag == "aq" then
              local digitSuffix = digit1 .. digit2
              -- Check which category we're matching against by looking at category name
              local catNameLower = string_lower(category.name or "")
              if string_find(catNameLower, "temple") or string_find(catNameLower, "aq40") then
                -- Temple of Ahn'Qiraj - only match "aq40"
                if digitSuffix == "40" then
                  validAfter = true
                end
              elseif string_find(catNameLower, "ruins") or string_find(catNameLower, "aq20") then
                -- Ruins of Ahn'Qiraj - match any number except "40"
                if digitSuffix ~= "40" then
                  validAfter = true
                end
              end
            -- Special handling for "kara" tag to distinguish Upper (40-man) from Lower (10-man)
            -- "kara40" -> Upper Karazhan Halls only
            -- "kara" + any other number (kara10, kara15, etc.) -> Lower Karazhan Halls
            elseif lowerTag == "kara" then
              local digitSuffix = digit1 .. digit2
              local catNameLower = string_lower(category.name or "")
              if string_find(catNameLower, "upper") or string_find(catNameLower, "ukh") then
                -- Upper Karazhan Halls - only match "kara40"
                if digitSuffix == "40" then
                  validAfter = true
                end
              elseif string_find(catNameLower, "lower") or string_find(catNameLower, "lkh") then
                -- Lower Karazhan Halls - match any number except "40"
                if digitSuffix ~= "40" then
                  validAfter = true
                end
              end
            else
              -- For all other tags, allow any 1-2 digit suffix
              validAfter = true
            end
          end
        end

        if validBefore and validAfter then
          -- Check tag exclusions for false positives
          if not IsTagExcluded(lowerTag, lowerMsg, foundPos, tagLen) then
            return true
          end
        end

        -- Continue searching from next position
        startPos = foundPos + 1
      end
    end  -- end else (plain text matching)
  end
  return false
end

-- [ CategorizeMessage ]
-- Determines which categories a message belongs to
-- Returns table with matched category names for each type
-- 'message'        [string]  the message text
-- 'ignoreSelected' [boolean] if true, match against all categories regardless of enabled state
-- return:          [table]   { groups = {}, professions = {}, hardcore = {}, isHardcore = bool }
function DBB2.api.CategorizeMessage(message, ignoreSelected)
  -- Create fresh result table each call (safer than pooling)
  local result = {
    groups = {},
    professions = {},
    hardcore = {},
    isHardcore = false
  }
  
  if not message then return result end
  if not DBB2_Config.categories then return result end
  
  -- Check groups (pass categoryType for filter tag checking)
  for _, cat in ipairs(DBB2_Config.categories.groups or {}) do
    if DBB2.api.MatchMessageToCategory(message, cat, ignoreSelected, "groups") then
      table_insert(result.groups, cat.name)
    end
  end
  
  -- Check professions (pass categoryType for filter tag checking)
  for _, cat in ipairs(DBB2_Config.categories.professions or {}) do
    if DBB2.api.MatchMessageToCategory(message, cat, ignoreSelected, "professions") then
      table_insert(result.professions, cat.name)
    end
  end
  
  -- Check hardcore (no filter tags for hardcore)
  for _, cat in ipairs(DBB2_Config.categories.hardcore or {}) do
    if DBB2.api.MatchMessageToCategory(message, cat, ignoreSelected, "hardcore") then
      table_insert(result.hardcore, cat.name)
      result.isHardcore = true
    end
  end
  
  return result
end

-- [ GetCategorizedMessages ]
-- Returns messages organized by category for a given type
-- Applies duplicate filtering per category (same sender + message within spam window)
-- 'categoryType' [string] "groups", "professions", or "hardcore"
-- return:        [table]  { categoryName = { messages... }, ... }
function DBB2.api.GetCategorizedMessages(categoryType)
  local categorized = {}
  
  if not categoryType then return categorized end
  
  local categories = DBB2.api.GetCategories(categoryType)
  local spamSeconds = DBB2_Config.spamFilterSeconds or 150
  
  -- Initialize empty arrays for each selected category
  for _, cat in ipairs(categories) do
    if cat.selected then
      categorized[cat.name] = {}
    end
  end
  
  -- Guard against nil messages table
  if not DBB2.messages then return categorized end
  
  -- Helper to check if message is duplicate within a category's message list
  local function isDuplicateInCategory(catMessages, msg)
    if spamSeconds <= 0 then return false end
    
    local lowerMsg = string_lower(DBB2.api.StripHyperlinks(msg.message or ""))
    local lowerSender = string_lower(msg.sender or "")
    local msgTime = msg.time or 0
    
    for _, existing in ipairs(catMessages) do
      local timeDiff = math_abs(msgTime - (existing.time or 0))
      if timeDiff <= spamSeconds then
        local existingMsg = string_lower(DBB2.api.StripHyperlinks(existing.message or ""))
        local existingSender = string_lower(existing.sender or "")
        if existingSender == lowerSender and existingMsg == lowerMsg then
          return true
        end
      end
    end
    return false
  end
  
  -- Categorize each message
  for _, msg in ipairs(DBB2.messages) do
    local msgCategories = DBB2.api.CategorizeMessage(msg.message)
    
    if categoryType == "hardcore" then
      -- Only show hardcore messages in hardcore tab
      for _, catName in ipairs(msgCategories.hardcore) do
        if categorized[catName] then
          if not isDuplicateInCategory(categorized[catName], msg) then
            table_insert(categorized[catName], msg)
          end
        end
      end
    else
      -- Skip hardcore messages in other tabs
      if not msgCategories.isHardcore then
        local matchedCats = msgCategories[categoryType] or {}
        for _, catName in ipairs(matchedCats) do
          if categorized[catName] then
            if not isDuplicateInCategory(categorized[catName], msg) then
              table_insert(categorized[catName], msg)
            end
          end
        end
      end
    end
  end
  
  return categorized
end
