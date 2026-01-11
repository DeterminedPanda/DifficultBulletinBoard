-- DBB2 Categories Module
-- Default category definitions and initialization
--
-- NOTE: Category API functions are in api/categories.lua
-- This module provides default data and the ResetCategoriesToDefaults function.

DBB2:RegisterModule("categories", function()
  -- Default category definitions
  local defaultGroups = {
    { name = "Custom Topic",                  selected = false, tags = {} },
    { name = "Upper Karazhan Halls",          selected = true, tags = { "kara40", "ukh"} },
    { name = "Naxxramas",                     selected = true, tags = { "naxxramas", "naxx" } },
    { name = "Temple of Ahn'Qiraj",           selected = true, tags = { "ahn'qiraj", "ahnqiraj", "aq40", "aq" } },
    { name = "Emerald Sanctum",               selected = true, tags = { "emerald", "sanctum", "es", "esnormal", "eshardcore" } },
    { name = "Blackwing Lair",                selected = true, tags = { "blackwing", "bwl" } },
    { name = "Lower Karazhan Halls",          selected = true, tags = { "karazhan", "kara", "kara10", "k10", "kz10" } },
    { name = "Onyxia's Lair",                 selected = true, tags = { "onyxia", "ony", "onyx" } },
    { name = "Molten Core",                   selected = true, tags = { "molten", "mc" } },
    { name = "Ruins of Ahn'Qiraj",            selected = true, tags = { "ruins", "ahn'qiraj", "ahnqiraj", "aq20", "aq" } },
    { name = "Zul'Gurub",                     selected = true, tags = { "zul'gurub", "zulgurub", "zg" } },
    { name = "Stormwind Vault",               selected = true, tags = { "vault", "swvault" } },
    { name = "Caverns of Time: Black Morass", selected = true, tags = { "cot", "morass", "cavern", "cot:bm", "bm" } },
    { name = "Karazhan Crypt",                selected = true, tags = { "crypt", "kara", "karazhan" } },
    { name = "Upper Blackrock Spire",         selected = true, tags = { "ubrs", "blackrock", "upper", "spire" } },
    { name = "Lower Blackrock Spire",         selected = true, tags = { "lbrs", "blackrock", "lower", "spire" } },
    { name = "Stratholme",                    selected = true, tags = { "strat", "stratholme" } },
    { name = "Scholomance",                   selected = true, tags = { "scholo", "scholomance" } },
    { name = "Dire Maul",                     selected = true, tags = { "dire", "maul", "dm", "dm:e", "dm:east", "dm:w", "dm:west", "dm:n", "dm:north", "dmw", "dmwest", "dmn", "dmnorth", "dme", "dmeast", "tribute" } },
    { name = "Blackrock Depths",              selected = true, tags = { "brd", "blackrock", "depths", "emp", "lava" } },
    { name = "Hateforge Quarry",              selected = true, tags = { "hateforge", "quarry", "hq", "hfq" } },
    { name = "The Sunken Temple",             selected = true, tags = { "st", "sunken", "temple" } },
    { name = "Zul'Farrak",                    selected = true, tags = { "zf", "zul'farrak", "zulfarrak", "farrak" } },
    { name = "Maraudon",                      selected = true, tags = { "mara", "maraudon" } },
    { name = "Gilneas City",                  selected = true, tags = { "gilneas", "city" } },
    { name = "Stormwrought Ruins",            selected = true, tags = { "stormwrought", "ruins", "castle", "descent" } },
    { name = "Uldaman",                       selected = true, tags = { "uldaman" } },
    { name = "Razorfen Downs",                selected = true, tags = { "razorfen", "downs", "rfd" } },
    { name = "Scarlet Monastery",             selected = true, tags = { "scarlet", "monastery", "sm", "armory", "cathedral", "cath", "library", "lib", "graveyard" } },
    { name = "The Crescent Grove",            selected = true, tags = { "crescent", "grove" } },
    { name = "Razorfen Kraul",                selected = true, tags = { "razorfen", "kraul", "rfk" } },
    { name = "Dragonmaw Retreat",             selected = true, tags = { "dragonmaw", "retreat", "dmr" } },
    { name = "Gnomeregan",                    selected = true, tags = { "gnomeregan", "gnomer" } },
    { name = "The Stockade",                  selected = true, tags = { "stockade", "stockades", "stock", "stocks" } },
    { name = "Blackfathom Deeps",             selected = true, tags = { "bfd", "blackfathom" } },
    { name = "Shadowfang Keep",               selected = true, tags = { "sfk", "shadowfang" } },
    { name = "The Deadmines",                 selected = true, tags = { "vc", "dm", "deadmine", "deadmines" } },
    { name = "Wailing Caverns",               selected = true, tags = { "wc", "wailing", "caverns" } },
    { name = "Ragefire Chasm",                selected = true, tags = { "rfc", "ragefire", "chasm" } },
  }
  
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
  
  -- [ ResetCategoriesToDefaults ]
  -- Resets all categories to default values
  -- NOTE: This function lives in DBB2.modules (not DBB2.api) because it needs
  -- access to the default tables defined in this module. API functions in
  -- api/categories.lua operate on the saved config data, while this function
  -- needs the original defaults for reset functionality.
  function DBB2.modules.ResetCategoriesToDefaults()
    DBB2_Config.categories.groups = DBB2.api.DeepCopy(defaultGroups)
    DBB2_Config.categories.professions = DBB2.api.DeepCopy(defaultProfessions)
    DBB2_Config.categories.hardcore = DBB2.api.DeepCopy(defaultHardcore)
  end
end)
