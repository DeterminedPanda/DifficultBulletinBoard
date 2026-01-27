-- DBB2 Lockouts API
-- Tracks raid lockouts and maps them to categories

-- Localize frequently used globals for performance
local string_lower = string.lower
local math_floor = math.floor
local math_mod = math.mod
local time = time
local pairs = pairs

-- Storage for lockout data
DBB2.lockouts = {}

-- Alias map for instance names that differ from category names
-- Only needed when GetSavedInstanceInfo returns a different name than our category
DBB2.INSTANCE_ALIASES = {
  ["ahn'qiraj temple"] = "Temple of Ahn'Qiraj",
  ["ahn'qiraj ruins"] = "Ruins of Ahn'Qiraj",
  ["karazhan halls"] = "Upper Karazhan Halls",
  ["black morass"] = "Caverns of Time: Black Morass",
}

-- [ InitLockouts ]
-- Initializes the lockout tracking system
-- NOTE: UPDATE_INSTANCE_INFO event is registered in DifficultBulletinBoard.lua
function DBB2.api.InitLockouts()
  -- Request initial data
  RequestRaidInfo()
end

-- [ RefreshLockouts ]
-- Requests fresh lockout data from the server
function DBB2.api.RefreshLockouts()
  RequestRaidInfo()
end

-- [ UpdateLockouts ]
-- Called when UPDATE_INSTANCE_INFO fires, parses lockout data
function DBB2.api.UpdateLockouts()
  -- Clear existing lockouts
  DBB2.lockouts = {}
  
  local numInstances = GetNumSavedInstances()
  
  for i = 1, numInstances do
    local instanceName, instanceID, instanceReset = GetSavedInstanceInfo(i)
    
    if instanceName and instanceReset and instanceReset > 0 then
      -- Store raw lockout info
      local lowerName = string_lower(instanceName)
      DBB2.lockouts[lowerName] = {
        name = instanceName,
        id = instanceID,
        reset = instanceReset,
        resetTime = time() + instanceReset
      }
    end
  end
  
  -- Update GUI if visible
  if DBB2.gui and DBB2.gui:IsShown() then
    local activeTab = DBB2.gui.tabs and DBB2.gui.tabs.activeTab
    if activeTab == "Groups" then
      local panel = DBB2.gui.tabs.panels["Groups"]
      if panel and panel.UpdateCategories then
        panel.UpdateCategories()
      end
    end
  end
end

-- [ GetCategoryLockout ]
-- Checks if a category corresponds to a locked instance
-- 'categoryName' [string]  the category name to check
-- return: [table|nil]      lockout info if locked, nil otherwise
function DBB2.api.GetCategoryLockout(categoryName)
  if not categoryName then return nil end
  
  local lowerCat = string_lower(categoryName)
  
  -- Check each lockout
  for instanceKey, lockoutData in pairs(DBB2.lockouts) do
    -- First check aliases for non-standard instance names
    local aliasedCategory = DBB2.INSTANCE_ALIASES[instanceKey]
    if aliasedCategory and aliasedCategory == categoryName then
      return lockoutData
    end
    
    -- Direct match: instance name (lowercase) matches category name (lowercase)
    if instanceKey == lowerCat then
      return lockoutData
    end
  end
  
  return nil
end

-- [ IsCategoryLocked ]
-- Simple boolean check if category is locked
-- 'categoryName' [string]  the category name to check
-- return: [boolean]        true if locked
function DBB2.api.IsCategoryLocked(categoryName)
  return DBB2.api.GetCategoryLockout(categoryName) ~= nil
end

-- [ FormatTimeRemaining ]
-- Formats seconds into a readable time string
-- 'seconds' [number]  seconds remaining
-- return: [string]    formatted string like "2d 5h" or "3h 20m"
function DBB2.api.FormatTimeRemaining(seconds)
  if not seconds or type(seconds) ~= "number" or seconds <= 0 then
    return "Expired"
  end
  
  local days = math_floor(seconds / 86400)
  local hours = math_floor(math_mod(seconds, 86400) / 3600)
  local minutes = math_floor(math_mod(seconds, 3600) / 60)
  
  if days > 0 then
    return days .. "d " .. hours .. "h"
  elseif hours > 0 then
    return hours .. "h " .. minutes .. "m"
  else
    return minutes .. "m"
  end
end

-- [ GetLockoutTimeRemaining ]
-- Gets formatted time remaining for a category lockout
-- 'categoryName' [string]  the category name to check
-- return: [string|nil]     formatted time or nil if not locked
function DBB2.api.GetLockoutTimeRemaining(categoryName)
  local lockout = DBB2.api.GetCategoryLockout(categoryName)
  if lockout then
    local remaining = lockout.resetTime - time()
    return DBB2.api.FormatTimeRemaining(remaining)
  end
  return nil
end
