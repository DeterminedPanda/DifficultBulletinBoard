-- DBB2 Environment Defaults
-- Central location for default configuration values
--
-- This file is loaded early in the TOC order so that API files
-- can reference these defaults via DBB2.env.* namespace.

-- Initialize the env namespace
DBB2.env = DBB2.env or {}

-- =====================
-- CHANNEL DEFAULTS
-- =====================

-- Default whitelisted channels (case-insensitive)
-- These are the standard channels where players look for groups
DBB2.env.defaultWhitelistedChannels = {
  "world",           -- Main LFG channel on most servers
  "lookingforgroup", -- Blizzard's LFG channel
  "lfg",             -- Common abbreviation
  "trade",           -- Sometimes used for LFG
  "general",         -- Zone general chat
  "hardcore",        -- Turtle WoW hardcore
}

-- Default channel monitoring settings (which channels are enabled for monitoring)
DBB2.env.defaultMonitoredChannels = {
  -- Group 1: Local/Social
  Say = false,
  Yell = false,
  Guild = true,
  Whisper = false,
  Party = false,
  -- Group 2: Zone/Global channels
  General = true,
  Trade = true,
  LocalDefense = false,
  WorldDefense = false,
  LookingForGroup = true,
  GuildRecruitment = false,
  World = true,
  -- Special
  Hardcore = true,  -- Will only work for hardcore characters
}

-- Static channel order for UI display (always shown regardless of joined status)
-- Use "-" as separator marker between groups
DBB2.env.staticChannelOrder = {
  "Say", "Yell", "Guild", "Whisper", "Party",
  "-",  -- separator
  "General", "Trade", "LocalDefense", "WorldDefense", "LookingForGroup", "GuildRecruitment", "World", "Hardcore",
  "-",  -- separator (dynamic channels follow)
}

-- Channels to auto-join if not already joined
DBB2.env.autoJoinChannels = {"World", "LookingForGroup"}

-- =====================
-- BLACKLIST DEFAULTS
-- =====================

-- Default blacklist keywords (used by InitBlacklist and reset functions)
-- These patterns are used to filter out common spam/recruitment messages
-- Supports wildcards: * matches any characters
DBB2.env.defaultBlacklistKeywords = {"recruit*", "recrut*", "<*>", "\\[???\\]", "\\[??\\]"}


-- =====================
-- CATEGORY DEFAULTS
-- =====================

-- Default filter tags for category types (must match in addition to category tags when enabled)
-- These are global filters that apply to all categories within a type
-- groups: LFG-style tags for dungeon/raid groups
-- professions: Trade-style tags for profession services
DBB2.env.defaultFilterTags = {
  groups = {
    enabled = false,
    tags = { "LF", "LFG", "LFM", "LF*M" }
  },
  professions = {
    enabled = false,
    tags = { "LF", "LFW", "WTB", "WTS" }
  }
}

-- Default group categories (dungeons/raids)
-- Level ranges: minLevel = minimum recommended level, maxLevel = maximum useful level (60 = endgame)
-- Each category has: name, selected (default state), tags (matching keywords), minLevel, maxLevel
DBB2.env.defaultGroups = {
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
  { name = "Dire Maul",                     selected = true, tags = { "dire", "maul", "dm", "dm:e", "dm:east", "dm:w", "dm:west", "dm:n", "dm:north", "dmw", "dmwest", "dmn", "dmnorth", "dme", "dmeast", "tribute", "dmt" }, minLevel = 57, maxLevel = 60 },
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

-- Default profession categories
-- Each category has: name, selected (default state), tags (matching keywords)
DBB2.env.defaultProfessions = {
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

-- Default hardcore categories (Turtle WoW specific)
-- Deaths: Tracks player death announcements
-- Level Ups: Tracks level up announcements
DBB2.env.defaultHardcore = {
  { name = "Deaths",    selected = true, tags = { "tragedy" } },
  { name = "Level Ups", selected = true, tags = { "reached", "inferno" } },
}
