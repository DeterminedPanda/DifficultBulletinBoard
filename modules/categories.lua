-- DBB2 Categories Module
-- Category initialization and auto-reset logic
--
-- NOTE: Default category data is in env/defaults.lua (DBB2.env.*)
-- NOTE: Category API functions are in api/categories.lua
-- This module provides initialization and the ResetCategoriesToDefaults function.
--
-- VERSION NUMBERS are in env/versions.lua:
--   DBB2.versions.CATEGORY  - for category/filter tag changes
--   DBB2.versions.BLACKLIST - for blacklist keyword changes

-- Localize frequently used globals for performance
local ipairs = ipairs
local pairs = pairs

DBB2:RegisterModule("categories", function()
  -- Level range lookup table (runtime only, not saved)
  -- Populated from DBB2.env.defaultGroups defined in env/defaults.lua
  -- Access via DBB2.api.GetCategoryLevelRange() or DBB2.api.IsLevelAppropriate()
  DBB2.categoryLevelRanges = {}
  for _, cat in ipairs(DBB2.env.defaultGroups) do
    if cat.minLevel and cat.maxLevel then
      DBB2.categoryLevelRanges[cat.name] = {
        minLevel = cat.minLevel,
        maxLevel = cat.maxLevel
      }
    end
  end
  
  -- Initialize saved categories config
  if not DBB2_Config.categories then
    DBB2_Config.categories = {}
  end
  
  -- Initialize filter tags config
  if not DBB2_Config.filterTags then
    DBB2_Config.filterTags = {}
  end
  if not DBB2_Config.filterTags.groups then
    DBB2_Config.filterTags.groups = DBB2.api.DeepCopy(DBB2.env.defaultFilterTags.groups)
  end
  if not DBB2_Config.filterTags.professions then
    DBB2_Config.filterTags.professions = DBB2.api.DeepCopy(DBB2.env.defaultFilterTags.professions)
  end
  
  -- Helper to check if a table has any array elements (more reliable than table.getn in Lua 5.0)
  local function hasArrayElements(t)
    if not t then return false end
    -- Check if first element exists (all category arrays start at index 1)
    return t[1] ~= nil
  end
  
  -- Initialize categories from saved or defaults
  -- Use hasArrayElements instead of table.getn for more reliable detection
  if not DBB2_Config.categories.groups or not hasArrayElements(DBB2_Config.categories.groups) then
    DBB2_Config.categories.groups = DBB2.api.DeepCopy(DBB2.env.defaultGroups)
  end
  if not DBB2_Config.categories.professions or not hasArrayElements(DBB2_Config.categories.professions) then
    DBB2_Config.categories.professions = DBB2.api.DeepCopy(DBB2.env.defaultProfessions)
  end
  if not DBB2_Config.categories.hardcore or not hasArrayElements(DBB2_Config.categories.hardcore) then
    DBB2_Config.categories.hardcore = DBB2.api.DeepCopy(DBB2.env.defaultHardcore)
  end
  
  -- Ensure all categories have a tags field (fix for SavedVariables not preserving empty tables)
  -- Also clean up runtime-only fields that shouldn't be saved (_tagsLower, _tagsLen)
  local function ensureTagsField(categories)
    for _, cat in ipairs(categories) do
      if cat.tags == nil then
        cat.tags = {}
      end
      -- Clean up runtime-only precomputed fields (they'll be regenerated on demand)
      cat._tagsLower = nil
      cat._tagsLen = nil
    end
  end
  ensureTagsField(DBB2_Config.categories.groups)
  ensureTagsField(DBB2_Config.categories.professions)
  ensureTagsField(DBB2_Config.categories.hardcore)
  
  -- Initialize collapsed states if not present
  if not DBB2_Config.categoryCollapsed then
    DBB2_Config.categoryCollapsed = {}
  end
  
  -- =====================================================
  -- AUTO-RESET ON VERSION CHANGE
  -- =====================================================
  -- Check each version number separately to only reset what changed
  
  -- Groups version: reset groups categories and filter tags
  local savedGroupsVersion = DBB2_Config.groupsVersion or 0
  if savedGroupsVersion < DBB2.versions.GROUPS then
    DBB2_Config.categories.groups = DBB2.api.DeepCopy(DBB2.env.defaultGroups)
    DBB2_Config.filterTags.groups = DBB2.api.DeepCopy(DBB2.env.defaultFilterTags.groups)
    DBB2_Config.groupsVersion = DBB2.versions.GROUPS
    DBB2:QueueMessage("|cff33ffccDBB2:|r Groups tags updated to v" .. DBB2.versions.GROUPS .. " defaults.")
  end
  
  -- Professions version: reset professions categories and filter tags
  local savedProfessionsVersion = DBB2_Config.professionsVersion or 0
  if savedProfessionsVersion < DBB2.versions.PROFESSIONS then
    DBB2_Config.categories.professions = DBB2.api.DeepCopy(DBB2.env.defaultProfessions)
    DBB2_Config.filterTags.professions = DBB2.api.DeepCopy(DBB2.env.defaultFilterTags.professions)
    DBB2_Config.professionsVersion = DBB2.versions.PROFESSIONS
    DBB2:QueueMessage("|cff33ffccDBB2:|r Professions tags updated to v" .. DBB2.versions.PROFESSIONS .. " defaults.")
  end
  
  -- Hardcore version: reset hardcore categories
  local savedHardcoreVersion = DBB2_Config.hardcoreVersion or 0
  if savedHardcoreVersion < DBB2.versions.HARDCORE then
    DBB2_Config.categories.hardcore = DBB2.api.DeepCopy(DBB2.env.defaultHardcore)
    DBB2_Config.hardcoreVersion = DBB2.versions.HARDCORE
    DBB2:QueueMessage("|cff33ffccDBB2:|r Hardcore tags updated to v" .. DBB2.versions.HARDCORE .. " defaults.")
  end
  
  -- Blacklist version: reset blacklist keywords only (preserves enabled state and player list)
  local savedBlacklistVersion = DBB2_Config.blacklistVersion or 0
  if savedBlacklistVersion < DBB2.versions.BLACKLIST then
    -- Ensure blacklist structure exists before resetting keywords
    if not DBB2_Config.blacklist then
      DBB2_Config.blacklist = {
        enabled = true,
        hideFromChat = true,
        players = {},
        keywords = {}
      }
    end
    DBB2_Config.blacklist.keywords = DBB2.api.DeepCopy(DBB2.env.defaultBlacklistKeywords)
    DBB2_Config.blacklistVersion = DBB2.versions.BLACKLIST
    DBB2:QueueMessage("|cff33ffccDBB2:|r Blacklist keywords updated to v" .. DBB2.versions.BLACKLIST .. " defaults.")
  end
  
  -- [ ResetCategoriesToDefaults ]
  -- Resets all tag-related settings to default values (categories, filter tags, blacklist keywords)
  -- NOTE: This function lives in DBB2.modules (not DBB2.api) because it performs
  -- a full reset operation. Default data is now in env/defaults.lua (DBB2.env.*).
  function DBB2.modules.ResetCategoriesToDefaults()
    DBB2_Config.categories.groups = DBB2.api.DeepCopy(DBB2.env.defaultGroups)
    DBB2_Config.categories.professions = DBB2.api.DeepCopy(DBB2.env.defaultProfessions)
    DBB2_Config.categories.hardcore = DBB2.api.DeepCopy(DBB2.env.defaultHardcore)
    DBB2_Config.filterTags = {
      groups = DBB2.api.DeepCopy(DBB2.env.defaultFilterTags.groups),
      professions = DBB2.api.DeepCopy(DBB2.env.defaultFilterTags.professions)
    }
    -- Reset blacklist keywords (preserves enabled state and player list)
    if DBB2_Config.blacklist then
      DBB2_Config.blacklist.keywords = DBB2.api.DeepCopy(DBB2.env.defaultBlacklistKeywords)
    end
    -- Update version numbers to current
    DBB2_Config.groupsVersion = DBB2.versions.GROUPS
    DBB2_Config.professionsVersion = DBB2.versions.PROFESSIONS
    DBB2_Config.hardcoreVersion = DBB2.versions.HARDCORE
    DBB2_Config.blacklistVersion = DBB2.versions.BLACKLIST
  end
end)
