-- DBB2 Categories Module
-- Default category definitions and initialization
--
-- NOTE: Category API functions are in api/categories.lua
-- This module provides default data and the ResetCategoriesToDefaults function.

-- =====================================================
-- CATEGORY VERSION - INCREMENT THIS WHEN YOU CHANGE DEFAULT TAGS
-- =====================================================
-- When you modify any default tags below, bump this number.
-- On next login, users will get ALL tag-related settings auto-reset to new defaults:
--   - Category tags (groups, professions, hardcore)
--   - Filter tags (LF/LFG/LFM, LFW/WTB/WTS)
--   - Blacklist keywords
-- This only happens ONCE per version bump, so users won't lose custom changes repeatedly.
local CATEGORY_VERSION = 5

DBB2:RegisterModule("categories", function()
  -- Default filter tags for category types (must match in addition to category tags when enabled)
  -- These are global filters that apply to all categories within a type
  local defaultFilterTags = {
    groups = {
      enabled = false,
      tags = { "LF", "LFG", "LFM", "LF*M" }
    },
    professions = {
      enabled = false,
      tags = { "LF", "LFW", "WTB", "WTS" }
    }
  }
  
  -- Default category definitions
  -- Level ranges: minLevel = minimum recommended level, maxLevel = maximum useful level (60 = endgame)
  local defaultGroups = {
    { name = "Custom Topic",                  selected = false, tags = {}, minLevel = 1, maxLevel = 60 },
    { name = "Upper Karazhan Halls",          selected = true, tags = { "kara40", "ukh"}, minLevel = 60, maxLevel = 60 },
    { name = "Naxxramas",                     selected = true, tags = { "naxxramas", "naxx" }, minLevel = 60, maxLevel = 60 },
    { name = "Temple of Ahn'Qiraj",           selected = true, tags = { "ahn'qiraj", "ahnqiraj", "aq40", "aq" }, minLevel = 60, maxLevel = 60 },
    { name = "Emerald Sanctum",               selected = true, tags = { "emerald", "sanctum", "es", "esnormal", "eshardcore" }, minLevel = 60, maxLevel = 60 },
    { name = "Blackwing Lair",                selected = true, tags = { "blackwing", "bwl" }, minLevel = 60, maxLevel = 60 },
    { name = "Lower Karazhan Halls",          selected = true, tags = { "karazhan", "kara", "kara10", "k10", "kz10" }, minLevel = 60, maxLevel = 60 },
    { name = "Onyxia's Lair",                 selected = true, tags = { "onyxia", "ony", "onyx" }, minLevel = 60, maxLevel = 60 },
    { name = "Molten Core",                   selected = true, tags = { "molten", "mc" }, minLevel = 60, maxLevel = 60 },
    { name = "Ruins of Ahn'Qiraj",            selected = true, tags = { "ruins", "ahn'qiraj", "ahnqiraj", "aq20", "aq" }, minLevel = 60, maxLevel = 60 },
    { name = "Zul'Gurub",                     selected = true, tags = { "zul'gurub", "zulgurub", "zg" }, minLevel = 60, maxLevel = 60 },
    { name = "Stormwind Vault",               selected = true, tags = { "vault", "swvault", "swv" }, minLevel = 60, maxLevel = 60 },
    { name = "Caverns of Time: Black Morass", selected = true, tags = { "cot", "morass", "cavern", "cot:bm", "bm" }, minLevel = 60, maxLevel = 60 },
    { name = "Karazhan Crypt",                selected = true, tags = { "crypt", "kara", "karazhan" }, minLevel = 60, maxLevel = 60 },
    { name = "Upper Blackrock Spire",         selected = true, tags = { "ubrs", "blackrock", "upper", "spire" }, minLevel = 60, maxLevel = 60 },
    { name = "Lower Blackrock Spire",         selected = true, tags = { "lbrs", "blackrock", "lower", "spire" }, minLevel = 55, maxLevel = 60 },
    { name = "Stratholme",                    selected = true, tags = { "strat", "stratholme" }, minLevel = 58, maxLevel = 60 },
    { name = "Scholomance",                   selected = true, tags = { "scholo", "scholomance" }, minLevel = 58, maxLevel = 60 },
    { name = "Dire Maul",                     selected = true, tags = { "dire", "maul", "dm", "dm:e", "dm:east", "dm:w", "dm:west", "dm:n", "dm:north", "dmw", "dmwest", "dmn", "dmnorth", "dme", "dmeast", "tribute" }, minLevel = 57, maxLevel = 60 },
    { name = "Blackrock Depths",              selected = true, tags = { "brd", "blackrock", "depths", "emp", "lava" }, minLevel = 50, maxLevel = 60 },
    { name = "Hateforge Quarry",              selected = true, tags = { "hateforge", "quarry", "hq", "hfq" }, minLevel = 51, maxLevel = 60 },
    { name = "The Sunken Temple",             selected = true, tags = { "st", "sunken", "temple" }, minLevel = 49, maxLevel = 58 },
    { name = "Zul'Farrak",                    selected = true, tags = { "zf", "zul'farrak", "zulfarrak", "farrak" }, minLevel = 42, maxLevel = 51 },
    { name = "Maraudon",                      selected = true, tags = { "mara", "maraudon" }, minLevel = 43, maxLevel = 54 },
    { name = "Gilneas City",                  selected = true, tags = { "gilneas", "city" }, minLevel = 43, maxLevel = 52 },
    { name = "Stormwrought Ruins",            selected = true, tags = { "stormwrought", "ruins", "castle", "descent" }, minLevel = 32, maxLevel = 44 },
    { name = "Uldaman",                       selected = true, tags = { "uldaman" }, minLevel = 41, maxLevel = 50 },
    { name = "Razorfen Downs",                selected = true, tags = { "razorfen", "downs", "rfd" }, minLevel = 35, maxLevel = 44 },
    { name = "Scarlet Monastery",             selected = true, tags = { "scarlet", "monastery", "sm", "armory", "cathedral", "cath", "library", "lib", "graveyard" }, minLevel = 30, maxLevel = 45 },
    { name = "The Crescent Grove",            selected = true, tags = { "crescent", "grove" }, minLevel = 28, maxLevel = 38 },
    { name = "Razorfen Kraul",                selected = true, tags = { "razorfen", "kraul", "rfk" }, minLevel = 29, maxLevel = 36 },
    { name = "Dragonmaw Retreat",             selected = true, tags = { "dragonmaw", "retreat", "dmr" }, minLevel = 26, maxLevel = 35 },
    { name = "Gnomeregan",                    selected = true, tags = { "gnomeregan", "gnomer" }, minLevel = 28, maxLevel = 37 },
    { name = "The Stockade",                  selected = true, tags = { "stockade", "stockades", "stock", "stocks" }, minLevel = 23, maxLevel = 32 },
    { name = "Blackfathom Deeps",             selected = true, tags = { "bfd", "blackfathom" }, minLevel = 22, maxLevel = 31 },
    { name = "Shadowfang Keep",               selected = true, tags = { "sfk", "shadowfang" }, minLevel = 20, maxLevel = 28 },
    { name = "The Deadmines",                 selected = true, tags = { "vc", "dm", "deadmine", "deadmines" }, minLevel = 16, maxLevel = 24 },
    { name = "Wailing Caverns",               selected = true, tags = { "wc", "wailing", "caverns" }, minLevel = 16, maxLevel = 25 },
    { name = "Ragefire Chasm",                selected = true, tags = { "rfc", "ragefire", "chasm" }, minLevel = 13, maxLevel = 19 },
  }
  
  -- Level range lookup table (runtime only, not saved)
  -- Populated here because defaultGroups is defined locally in this module.
  -- Access via DBB2.api.GetCategoryLevelRange() or DBB2.api.IsLevelAppropriate()
  DBB2.categoryLevelRanges = {}
  for _, cat in ipairs(defaultGroups) do
    if cat.minLevel and cat.maxLevel then
      DBB2.categoryLevelRanges[cat.name] = {
        minLevel = cat.minLevel,
        maxLevel = cat.maxLevel
      }
    end
  end
  
  local defaultProfessions = {
    { name = "Alchemy",        selected = true, tags = { "alchemist", "alchemy", "alch" } },
    { name = "Blacksmithing",  selected = true, tags = { "blacksmithing", "blacksmith", "bs" } },
    { name = "Enchanting",     selected = true, tags = { "enchanting", "enchanter", "enchant", "ench" } },
    { name = "Engineering",    selected = true, tags = { "engineering", "engineer", "eng" } },
    { name = "Herbalism",      selected = true, tags = { "herbalism", "herbalist", "herb" } },
    { name = "Leatherworking", selected = true, tags = { "leatherworking", "leatherworker", "lw" } },
    { name = "Mining",         selected = true, tags = { "mining", "miner" } },
    { name = "Tailoring",      selected = true, tags = { "tailoring", "tailor" } },
    { name = "Jewelcrafting",  selected = true, tags = { "jewelcrafting", "Jewelcrafter", "jeweler", "jewel", "jc" } },
    { name = "Cooking",        selected = true, tags = { "cooking", "cook" } },
  }
  
  local defaultHardcore = {
    { name = "Deaths",    selected = true, tags = { "tragedy" } },
    { name = "Level Ups", selected = true, tags = { "reached", "inferno" } },
  }
  
  -- Initialize saved categories config
  if not DBB2_Config.categories then
    DBB2_Config.categories = {}
  end
  
  -- Initialize filter tags config
  if not DBB2_Config.filterTags then
    DBB2_Config.filterTags = {}
  end
  if not DBB2_Config.filterTags.groups then
    DBB2_Config.filterTags.groups = DBB2.api.DeepCopy(defaultFilterTags.groups)
  end
  if not DBB2_Config.filterTags.professions then
    DBB2_Config.filterTags.professions = DBB2.api.DeepCopy(defaultFilterTags.professions)
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
    DBB2_Config.categories.groups = DBB2.api.DeepCopy(defaultGroups)
  end
  if not DBB2_Config.categories.professions or not hasArrayElements(DBB2_Config.categories.professions) then
    DBB2_Config.categories.professions = DBB2.api.DeepCopy(defaultProfessions)
  end
  if not DBB2_Config.categories.hardcore or not hasArrayElements(DBB2_Config.categories.hardcore) then
    DBB2_Config.categories.hardcore = DBB2.api.DeepCopy(defaultHardcore)
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
  -- Check if category version has changed - if so, auto-reset ALL tag-related settings
  -- This ensures users get updated tags when you modify defaults, but only once
  local savedVersion = DBB2_Config.categoryVersion or 0
  if savedVersion < CATEGORY_VERSION then
    -- Reset categories to new defaults
    DBB2_Config.categories.groups = DBB2.api.DeepCopy(defaultGroups)
    DBB2_Config.categories.professions = DBB2.api.DeepCopy(defaultProfessions)
    DBB2_Config.categories.hardcore = DBB2.api.DeepCopy(defaultHardcore)
    -- Reset filter tags to new defaults
    DBB2_Config.filterTags = {
      groups = DBB2.api.DeepCopy(defaultFilterTags.groups),
      professions = DBB2.api.DeepCopy(defaultFilterTags.professions)
    }
    -- Reset blacklist keywords to new defaults (preserves enabled state and player list)
    if DBB2_Config.blacklist then
      DBB2_Config.blacklist.keywords = DBB2.api.DeepCopy(DBB2.DEFAULT_BLACKLIST_KEYWORDS)
    end
    -- Update stored version so this only happens once
    DBB2_Config.categoryVersion = CATEGORY_VERSION
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccDBB2:|r Tags updated to v" .. CATEGORY_VERSION .. " defaults.")
  end
  
  -- [ ResetCategoriesToDefaults ]
  -- Resets all tag-related settings to default values (categories, filter tags, blacklist keywords)
  -- NOTE: This function lives in DBB2.modules (not DBB2.api) because it needs
  -- access to the default tables defined in this module. API functions in
  -- api/categories.lua operate on the saved config data, while this function
  -- needs the original defaults for reset functionality.
  function DBB2.modules.ResetCategoriesToDefaults()
    DBB2_Config.categories.groups = DBB2.api.DeepCopy(defaultGroups)
    DBB2_Config.categories.professions = DBB2.api.DeepCopy(defaultProfessions)
    DBB2_Config.categories.hardcore = DBB2.api.DeepCopy(defaultHardcore)
    DBB2_Config.filterTags = {
      groups = DBB2.api.DeepCopy(defaultFilterTags.groups),
      professions = DBB2.api.DeepCopy(defaultFilterTags.professions)
    }
    -- Reset blacklist keywords (preserves enabled state and player list)
    if DBB2_Config.blacklist then
      DBB2_Config.blacklist.keywords = DBB2.api.DeepCopy(DBB2.DEFAULT_BLACKLIST_KEYWORDS)
    end
  end
end)
