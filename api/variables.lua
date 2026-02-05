-- DBB2 Variables API
-- Centralized version numbers for auto-reset functionality
--
-- Each version number controls a specific set of defaults.
-- Increment ONLY the relevant version when you change those defaults.
-- This prevents unnecessary resets of unrelated user customizations.

DBB2.versions = {
  -- Groups category tags and filter tags (LF/LFG/LFM)
  -- Increment when: Adding/removing dungeon/raid categories, changing group tags
  GROUPS = 9,
  
  -- Professions category tags and filter tags (LFW/WTB/WTS)
  -- Increment when: Adding/removing profession categories, changing profession tags
  PROFESSIONS = 8,
  
  -- Hardcore category tags
  -- Increment when: Changing hardcore category tags (deaths, level ups)
  HARDCORE = 8,
  
  -- Blacklist keywords
  -- Increment when: Adding/removing default blacklist patterns
  BLACKLIST = 3,
  
  -- Monitored channels
  -- Increment when: Changing default channel selections
  -- CHANNELS = 1,
}
