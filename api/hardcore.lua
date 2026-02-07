-- DBB2 Hardcore Mode API
-- Turtle WoW hardcore mode detection and state tracking
--
-- Functions:
--   DBB2.api.IsHardcoreChatActive() - Check if hardcore chat detected this session
--   DBB2.api.SetHardcoreChatActive() - Mark hardcore chat as active
--   DBB2.api.DetectHardcoreCharacter() - Scan spellbook for hardcore spells
--   DBB2.api.IsHardcoreCharacter() - Return cached hardcore status

-- Localize frequently used globals for performance
local string_lower = string.lower

-- =====================
-- HARDCORE MODE API
-- =====================

-- Turtle WoW hardcore mode: automatically switches between World and Hardcore chat.
-- When CHAT_MSG_HARDCORE events are received, World channel is ignored.
-- This is tracked per-session (resets on login).

-- Session flag: set to true when we receive any CHAT_MSG_HARDCORE event
DBB2._hardcoreChatActive = false

-- [ IsHardcoreChatActive ]
-- Returns whether hardcore chat has been detected this session
-- return:      [boolean]       true if hardcore chat is active
function DBB2.api.IsHardcoreChatActive()
  return DBB2._hardcoreChatActive
end

-- [ SetHardcoreChatActive ]
-- Marks hardcore chat as active (called when CHAT_MSG_HARDCORE is received)
function DBB2.api.SetHardcoreChatActive()
  DBB2._hardcoreChatActive = true
end


-- =====================
-- HARDCORE CHARACTER DETECTION
-- =====================

-- [ DetectHardcoreCharacter ]
-- Detects if the current character is an active hardcore character by scanning spellbook
-- Only scans the first "General" tab for efficiency and accuracy.
-- Looks for spells with rank "Challenge" (e.g., "Hardcore (Challenge)", "Inferno (Challenge)")
-- A character is considered "active hardcore" if:
--   1. Has "Hardcore" spell with "Challenge" rank AND is below level 60 (normal hardcore), OR
--   2. Has "Inferno" spell with "Challenge" rank (level 60 hardcore who chose to stay hardcore)
-- return:      [boolean]       true if active hardcore character detected
function DBB2.api.DetectHardcoreCharacter()
  -- Check cached result first
  if DBB2_Config.isHardcoreCharacter ~= nil then
    return DBB2_Config.isHardcoreCharacter
  end
  
  local hasHardcoreSpell = false
  local hasInfernoSpell = false
  local playerLevel = UnitLevel("player") or 60
  
  -- Only scan the first "General" tab (tab 1) for challenge spells
  -- This is more efficient and avoids false matches from other spell tabs
  local numTabs = GetNumSpellTabs()
  if numTabs >= 1 then
    local tabName, _, offset, numSpells = GetSpellTabInfo(1)
    
    for i = 1, numSpells do
      local spellName, spellRank = GetSpellName(offset + i, "spell")
      if spellName and spellRank then
        -- Only match spells with "Challenge" rank for precise detection
        if spellRank == "Challenge" then
          local lowerName = string_lower(spellName)
          if lowerName == "hardcore" then
            hasHardcoreSpell = true
          elseif lowerName == "inferno" then
            hasInfernoSpell = true
          end
        end
      end
    end
  end
  
  -- Active hardcore: has Inferno spell, OR has Hardcore spell and below level 60
  local isActiveHardcore = hasInfernoSpell or (hasHardcoreSpell and playerLevel < 60)
  
  DBB2_Config.isHardcoreCharacter = isActiveHardcore
  return isActiveHardcore
end

-- [ IsHardcoreCharacter ]
-- Returns cached hardcore character status (use DetectHardcoreCharacter to force re-scan)
-- return:      [boolean]       true if hardcore character
function DBB2.api.IsHardcoreCharacter()
  if DBB2_Config.isHardcoreCharacter == nil then
    return DBB2.api.DetectHardcoreCharacter()
  end
  return DBB2_Config.isHardcoreCharacter
end
