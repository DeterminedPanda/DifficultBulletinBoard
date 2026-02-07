-- DBB2 Categories API
-- Core category management functions for message filtering
--
-- NOTE: Default category data and initialization is in modules/categories.lua
-- This file provides the API functions that operate on category data.
--
-- Includes:
-- - Category collapse state (UI)
-- - Category management (get, update, select)
-- - Tag parsing utilities
-- - Filter tags (AND-condition filtering for groups/professions)
-- - Level range filtering (dungeon/raid level appropriateness)
-- - Message matching and categorization
--
-- Related files:
-- - env/tag_exclusions.lua: Tag false positive exclusion rules (DBB2.env.IsTagExcluded)

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
-- CATEGORY COLLAPSE STATE API
-- =====================================================
-- Functions for managing the collapsed/expanded state of categories in the UI.
-- Collapsed categories show only the header, hiding their messages.

-- [ IsCategoryCollapsed ]
-- Checks whether a category is currently collapsed in the UI.
-- Collapsed categories show only the header row, hiding their messages.
--
-- @param categoryType  [string]  Category type: "groups", "professions", or "hardcore"
-- @param categoryName  [string]  The display name of the category
-- @return              [boolean] true if collapsed, false if expanded or not found
function DBB2.api.IsCategoryCollapsed(categoryType, categoryName)
  if not categoryType or not categoryName then return false end
  if not DBB2_Config.categoryCollapsed then return false end
  if not DBB2_Config.categoryCollapsed[categoryType] then return false end
  return DBB2_Config.categoryCollapsed[categoryType][categoryName] or false
end

-- [ SetCategoryCollapsed ]
-- Sets the collapsed/expanded state of a category in the UI.
-- Creates the necessary config tables if they don't exist.
--
-- @param categoryType  [string]  Category type: "groups", "professions", or "hardcore"
-- @param categoryName  [string]  The display name of the category
-- @param collapsed     [boolean] true to collapse, false to expand
-- @return              [boolean] true if set successfully, false if invalid params
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
-- Toggles the collapsed/expanded state of a category.
-- If collapsed, expands it; if expanded, collapses it.
--
-- @param categoryType  [string]  Category type: "groups", "professions", or "hardcore"
-- @param categoryName  [string]  The display name of the category
-- @return              [boolean] The new collapsed state (true = now collapsed)
function DBB2.api.ToggleCategoryCollapsed(categoryType, categoryName)
  local isCollapsed = DBB2.api.IsCategoryCollapsed(categoryType, categoryName)
  DBB2.api.SetCategoryCollapsed(categoryType, categoryName, not isCollapsed)
  return not isCollapsed
end

-- =====================================================
-- CATEGORY MANAGEMENT API
-- =====================================================
-- Functions for retrieving and modifying category definitions.
-- Categories contain tags used to match messages to dungeon/raid groups,
-- profession services, or hardcore-specific content.

-- [ GetCategories ]
-- Returns all categories for a given type from the saved config.
--
-- @param categoryType  [string] Category type: "groups", "professions", or "hardcore"
-- @return              [table]  Array of category objects, or empty table if not found
--                               Each category: { name, selected, tags, _tagsLower, _tagsLen }
function DBB2.api.GetCategories(categoryType)
  if not categoryType then return {} end
  if not DBB2_Config.categories then return {} end
  return DBB2_Config.categories[categoryType] or {}
end

-- [ GetCategoryByName ]
-- Finds and returns a specific category by its display name.
--
-- @param categoryType  [string]  Category type: "groups", "professions", or "hardcore"
-- @param name          [string]  The exact display name of the category
-- @return              [table]   The category object if found, or nil
-- @return              [number]  The index in the categories array, or nil
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
-- Updates the search tags for a category.
-- Also pre-computes lowercase versions and lengths for faster matching.
--
-- @param categoryType  [string]  Category type: "groups", "professions", or "hardcore"
-- @param categoryName  [string]  The display name of the category to update
-- @param newTags       [table]   Array of tag strings (e.g., {"mc", "molten core", "molten"})
-- @return              [boolean] true if updated successfully, false if category not found
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
-- Enables or disables a category for message matching.
-- Disabled categories will not match any messages (unless ignoreSelected is used).
--
-- @param categoryType  [string]  Category type: "groups", "professions", or "hardcore"
-- @param categoryName  [string]  The display name of the category
-- @param selected      [boolean] true to enable, false to disable
-- @return              [boolean] true if updated successfully, false if category not found
function DBB2.api.SetCategorySelected(categoryType, categoryName, selected)
  local cat = DBB2.api.GetCategoryByName(categoryType, categoryName)
  if cat then
    cat.selected = selected and true or false
    return true
  end
  return false
end

-- =====================================================
-- TAG PARSING UTILITIES
-- =====================================================
-- Functions for converting between tag string formats.

-- [ ParseTagsString ]
-- Converts a comma-separated string into an array of tags.
-- Trims whitespace and converts to lowercase.
--
-- Example: "MC, BWL, Ony" -> {"mc", "bwl", "ony"}
--
-- @param str     [string] Comma-separated tags string
-- @return        [table]  Array of lowercase tag strings
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
-- Converts an array of tags into a comma-separated string.
-- Uses table.concat for efficiency.
--
-- Example: {"mc", "bwl", "ony"} -> "mc, bwl, ony"
--
-- @param tags    [table]  Array of tag strings
-- @return        [string] Comma-separated string, or empty string if no tags
function DBB2.api.TagsToString(tags)
  if not tags then return "" end
  if table_getn(tags) == 0 then return "" end
  
  -- table.concat is more efficient than manual concatenation
  return table_concat(tags, ", ")
end


-- =====================================================
-- FILTER TAGS API
-- =====================================================
-- Filter tags are additional tags that must ALSO match (AND condition)
-- when enabled, allowing filtering for specific message types like LFG/LFM
-- for groups or LFW/WTB/WTS for professions.

-- [ GetFilterTags ]
-- Returns the filter tags configuration for a category type.
-- Filter tags are additional tags that must ALSO match (AND condition)
-- when enabled, allowing filtering for specific message types.
--
-- @param categoryType  [string] Category type: "groups" or "professions"
-- @return              [table]  Config table { enabled = boolean, tags = {string...} }, or nil if not found
function DBB2.api.GetFilterTags(categoryType)
  if not categoryType then return nil end
  if not DBB2_Config.filterTags then return nil end
  return DBB2_Config.filterTags[categoryType]
end

-- [ IsFilterTagsEnabled ]
-- Checks whether filter tags are currently enabled for a category type.
-- When enabled, messages must match both category tags AND filter tags.
--
-- @param categoryType  [string]  Category type: "groups" or "professions"
-- @return              [boolean] true if filter tags are enabled, false otherwise
function DBB2.api.IsFilterTagsEnabled(categoryType)
  local filter = DBB2.api.GetFilterTags(categoryType)
  if not filter then return false end
  return filter.enabled or false
end

-- [ SetFilterTagsEnabled ]
-- Enables or disables filter tags for a category type.
-- Creates the necessary config tables if they don't exist.
--
-- @param categoryType  [string]  Category type: "groups" or "professions"
-- @param enabled       [boolean] true to enable filter tags, false to disable
-- @return              [boolean] true if set successfully, false if invalid params
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
-- Updates the filter tags array for a category type.
-- Creates the necessary config tables if they don't exist.
--
-- @param categoryType  [string] Category type: "groups" or "professions"
-- @param newTags       [table]  Array of tag strings (e.g., {"lfg", "lfm", "lf1m"})
-- @return              [boolean] true if updated successfully, false if invalid params
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
-- Checks if a message matches any of the filter tags for a category type.
-- Uses word boundary matching for plain tags and wildcard matching for patterns.
-- Returns true if filter is disabled (pass-through behavior).
--
-- Supports wildcard patterns: * (any chars), ? (one char), [abc], [a-z], {a,b,c}
-- Also matches tags followed by digits (e.g., "lf1m", "lf2m" for "lf" tag).
--
-- @param message       [string]  The message text to check
-- @param categoryType  [string]  Category type: "groups" or "professions"
-- @return              [boolean] true if matches any filter tag, or if filter is disabled
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

-- =====================================================
-- LEVEL RANGE API
-- =====================================================
-- Functions for level-based category filtering.
-- Level ranges define the appropriate player level for dungeon/raid content.
-- Level ranges are populated by modules/categories.lua during initialization
-- and stored in DBB2.categoryLevelRanges lookup table.

-- [ GetCategoryLevelRange ]
-- Returns the level range for a category (used for level filtering).
-- Level ranges define the appropriate player level for dungeon/raid content.
--
-- @param categoryName  [string] The display name of the category
-- @return              [table]  Level range table { minLevel = number, maxLevel = number }, or nil if not found
function DBB2.api.GetCategoryLevelRange(categoryName)
  if DBB2.categoryLevelRanges and DBB2.categoryLevelRanges[categoryName] then
    return DBB2.categoryLevelRanges[categoryName]
  end
  return nil
end

-- [ IsLevelAppropriate ]
-- Checks if a category is appropriate for the given player level.
-- Used to filter out content that is too high or too low level.
-- Categories without defined level ranges are considered appropriate for all levels.
--
-- @param categoryName  [string] The display name of the category
-- @param playerLevel   [number] Player's level (optional, defaults to UnitLevel("player"))
-- @return              [boolean] true if player level is within category's range, or if no range defined
function DBB2.api.IsLevelAppropriate(categoryName, playerLevel)
  playerLevel = playerLevel or UnitLevel("player")
  local levelRange = DBB2.api.GetCategoryLevelRange(categoryName)
  if levelRange then
    return playerLevel >= levelRange.minLevel and playerLevel <= levelRange.maxLevel
  end
  -- If no level range defined, assume it's appropriate for all levels
  return true
end

-- =====================================================
-- MESSAGE MATCHING API
-- =====================================================
-- Functions for matching messages to categories based on tags.

-- [ MatchMessageToCategory ]
-- Checks if a message matches any tag in a category.
-- Uses word boundary matching to avoid partial matches (e.g., "dm" won't match "admin").
--
-- Features:
-- - Supports wildcard patterns: * (any chars), ? (one char), [abc], [a-z], [!abc], {a,b,c}
-- - Matches tags followed by 1-2 digits for raid sizes (e.g., "zg15", "ony12")
-- - Special handling for "aq" tag to distinguish Temple (40) from Ruins (20)
-- - Special handling for "kara" tag to distinguish Upper (40) from Lower (10)
-- - Applies tag exclusion rules to prevent false positives (e.g., "ST" for server time)
-- - If filter tags are enabled, message must match BOTH category tags AND filter tags
--
-- @param message        [string]  The message text to check
-- @param category       [table]   Category object with .selected, .tags, ._tagsLower, ._tagsLen
-- @param ignoreSelected [boolean] If true, skip the .selected check (for mode 2 filtering)
-- @param categoryType   [string]  Optional: "groups", "professions", or "hardcore" for filter tag checking
-- @return               [boolean] true if message matches the category
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
          -- Check tag exclusions for false positives (uses DBB2.env.IsTagExcluded)
          if not DBB2.env.IsTagExcluded(lowerTag, lowerMsg, foundPos, tagLen) then
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
-- Determines which categories a message belongs to across all category types.
-- Checks groups, professions, and hardcore categories.
--
-- @param message        [string]  The message text to categorize
-- @param ignoreSelected [boolean] If true, match against all categories regardless of enabled state
-- @return               [table]   Result table with structure:
--                                 {
--                                   groups = {string...},      -- Array of matched group category names
--                                   professions = {string...}, -- Array of matched profession category names
--                                   hardcore = {string...},    -- Array of matched hardcore category names
--                                   isHardcore = boolean       -- true if any hardcore category matched
--                                 }
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
-- Returns all messages organized by category for a given type.
-- Only includes messages for selected (enabled) categories.
-- Applies duplicate filtering per category (same sender + message within spam window).
-- Hardcore messages are excluded from groups/professions tabs and vice versa.
--
-- @param categoryType  [string] Category type: "groups", "professions", or "hardcore"
-- @return              [table]  Table mapping category names to message arrays:
--                               { ["Molten Core"] = {msg1, msg2, ...}, ["BWL"] = {...}, ... }
--                               Each message has: sender, message, time, channel, etc.
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
