-- DifficultBulletinBoardVars.lua
-- Handles variable initialization and loading of saved variables

DifficultBulletinBoardSavedVariables = DifficultBulletinBoardSavedVariables or {}
DifficultBulletinBoardVars = DifficultBulletinBoardVars or {}
DifficultBulletinBoardDefaults = DifficultBulletinBoardDefaults or {}

DifficultBulletinBoardVars.version = DifficultBulletinBoardDefaults.version

DifficultBulletinBoardVars.fontSize = DifficultBulletinBoardDefaults.defaultFontSize

DifficultBulletinBoardVars.serverTimePosition = DifficultBulletinBoardDefaults.defaultServerTimePosition

DifficultBulletinBoardVars.timeFormat = DifficultBulletinBoardDefaults.defaultTimeFormat

DifficultBulletinBoardVars.numberOfGroupPlaceholders = DifficultBulletinBoardDefaults.defaultNumberOfGroupPlaceholders
DifficultBulletinBoardVars.numberOfProfessionPlaceholders = DifficultBulletinBoardDefaults.defaultNumberOfProfessionPlaceholders
DifficultBulletinBoardVars.numberOfHardcorePlaceholders = DifficultBulletinBoardDefaults.defaultNumberOfHardcorePlaceholders

DifficultBulletinBoardVars.allGroupTopics = {}
DifficultBulletinBoardVars.allProfessionTopics = {}
DifficultBulletinBoardVars.allHardcoreTopics = {}

DifficultBulletinBoardSavedVariables.keywordBlacklist = DifficultBulletinBoardSavedVariables.keywordBlacklist or ""




-- Debug flag to track if we've already shown addon detection status
local addon_detection_shown = false

-- Retrieves a player's class from pfUI or CensusPlus database if available
function DifficultBulletinBoardVars.GetPlayerClassFromDatabase(name)
    -- Show detection message once on first call
    if not addon_detection_shown then
        local hasPfUI = pfUI_playerDB ~= nil
        local hasCensus = CensusPlus_Database and CensusPlus_Database["Servers"] ~= nil
        
        if hasPfUI and hasCensus then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[DBB]|r pfUI and CensusPlus detected! Class icons enabled.")
        elseif hasPfUI then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[DBB]|r pfUI detected! Class icons enabled.")
        elseif hasCensus then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[DBB]|r CensusPlus detected! Class icons enabled.")
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFFAA00[DBB]|r pfUI or CensusPlus not detected. Class icons disabled.")
        end
        
        addon_detection_shown = true
    end
    
    -- Try pfUI first (most efficient, O(1) lookup)
    if pfUI_playerDB and pfUI_playerDB[name] and pfUI_playerDB[name].class then
        return pfUI_playerDB[name].class
    end
    
    -- If pfUI doesn't have the player, try CensusPlus (more complete data)
    if CensusPlus_Database and CensusPlus_Database["Servers"] then
        -- Get realm name with locale prefix
        local realmName = GetRealmName()
        local locale = GetLocale()
        local localePrefix = ""
        
        -- CensusPlus uses locale prefixes
        if locale == "enUS" then
            localePrefix = "US"
        elseif locale == "enGB" or locale == "frFR" or locale == "deDE" or locale == "esES" then
            localePrefix = "EU"
        end
        
        local fullRealmName = localePrefix .. realmName
        
        -- Try with locale prefix first, fallback to realm name without prefix
        local realmDatabase = CensusPlus_Database["Servers"][fullRealmName] or CensusPlus_Database["Servers"][realmName]
        
        if realmDatabase then
            -- CensusPlus structure: Servers[realm][faction][race][class][name]
            -- We need to search through all factions, races, and classes
            for factionName, factionData in pairs(realmDatabase) do
                if type(factionData) == "table" then
                    for raceName, raceData in pairs(factionData) do
                        if type(raceData) == "table" then
                            for className, classData in pairs(raceData) do
                                if type(classData) == "table" and classData[name] then
                                    -- Found the player! Return the class name
                                    return className
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    
    -- Return nil if player not found in either database
    return nil
end

-- Helper function to get saved variable or default
local function setSavedVariable(savedVar, defaultVar, savedName)
    if savedVar and savedVar ~= "" then
        return savedVar
    else
        -- Handle nil default values gracefully
        local fallbackValue = defaultVar or ""
        DifficultBulletinBoardSavedVariables[savedName] = fallbackValue
        return fallbackValue
    end
end

-- Loads saved variables or initializes defaults
function DifficultBulletinBoardVars.LoadSavedVariables()

    -- Ensure the root and container tables exist
    DifficultBulletinBoardSavedVariables = DifficultBulletinBoardSavedVariables or {}
    DifficultBulletinBoardSavedVariables.keywordBlacklist = DifficultBulletinBoardSavedVariables.keywordBlacklist or ""
    
    -- Clean up old player database if it exists (migration from old version)
    if DifficultBulletinBoardSavedVariables.playerList then
        DifficultBulletinBoardSavedVariables.playerList = nil
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[DBB]|r Cleaned up old player database. Class icons will now use pfUI if available.")
    end

    if DifficultBulletinBoardSavedVariables.version then
        local savedVersion = DifficultBulletinBoardSavedVariables.version

        -- update the saved activeTopics if a new version of the topic list was released
        if savedVersion < DifficultBulletinBoardVars.version then

            DifficultBulletinBoardVars.allGroupTopics = DifficultBulletinBoardDefaults.deepCopy(DifficultBulletinBoardDefaults.defaultGroupTopics)
            DifficultBulletinBoardSavedVariables.activeGroupTopics = DifficultBulletinBoardVars.allGroupTopics

            DifficultBulletinBoardVars.allProfessionTopics = DifficultBulletinBoardDefaults.deepCopy(DifficultBulletinBoardDefaults.defaultProfessionTopics)
            DifficultBulletinBoardSavedVariables.activeProfessionTopics = DifficultBulletinBoardVars.allProfessionTopics

            DifficultBulletinBoardVars.allHardcoreTopics = DifficultBulletinBoardDefaults.deepCopy(DifficultBulletinBoardDefaults.defaultHardcoreTopics)
            DifficultBulletinBoardSavedVariables.activeHardcoreTopics = DifficultBulletinBoardVars.allHardcoreTopics

            DifficultBulletinBoardSavedVariables.version = DifficultBulletinBoardVars.version
        end
    else
        DifficultBulletinBoardSavedVariables.version = DifficultBulletinBoardVars.version
        DifficultBulletinBoardVars.allGroupTopics = DifficultBulletinBoardDefaults.deepCopy(DifficultBulletinBoardDefaults.defaultGroupTopics)
        DifficultBulletinBoardSavedVariables.activeGroupTopics = DifficultBulletinBoardVars.allGroupTopics

        DifficultBulletinBoardVars.allProfessionTopics = DifficultBulletinBoardDefaults.deepCopy(DifficultBulletinBoardDefaults.defaultProfessionTopics)
        DifficultBulletinBoardSavedVariables.activeProfessionTopics = DifficultBulletinBoardVars.allProfessionTopics

        DifficultBulletinBoardVars.allHardcoreTopics = DifficultBulletinBoardDefaults.deepCopy(DifficultBulletinBoardDefaults.defaultHardcoreTopics)
        DifficultBulletinBoardSavedVariables.activeHardcoreTopics = DifficultBulletinBoardVars.allHardcoreTopics
    end

    -- Set the saved or default variables for different settings
    DifficultBulletinBoardVars.serverTimePosition = setSavedVariable(DifficultBulletinBoardSavedVariables.serverTimePosition, DifficultBulletinBoardDefaults.defaultServerTimePosition, "serverTimePosition")
    DifficultBulletinBoardVars.fontSize = setSavedVariable(DifficultBulletinBoardSavedVariables.fontSize, DifficultBulletinBoardDefaults.defaultFontSize, "fontSize")
    DifficultBulletinBoardVars.timeFormat = setSavedVariable(DifficultBulletinBoardSavedVariables.timeFormat, DifficultBulletinBoardDefaults.defaultTimeFormat, "timeFormat")
    DifficultBulletinBoardVars.mainFrameSound = setSavedVariable(DifficultBulletinBoardSavedVariables.mainFrameSound, DifficultBulletinBoardDefaults.defaultMainFrameSound, "mainFrameSound")
    DifficultBulletinBoardVars.optionFrameSound = setSavedVariable(DifficultBulletinBoardSavedVariables.optionFrameSound, DifficultBulletinBoardDefaults.defaultOptionFrameSound, "optionFrameSound")
    DifficultBulletinBoardVars.notificationSound = setSavedVariable(DifficultBulletinBoardSavedVariables.notificationSound, DifficultBulletinBoardDefaults.defaultNotificationSound, "notificationSound")
	DifficultBulletinBoardVars.notificationMessage = setSavedVariable(DifficultBulletinBoardSavedVariables.notificationMessage, DifficultBulletinBoardDefaults.defaultNotificationMessage, "notificationMessage")
    DifficultBulletinBoardVars.filterMatchedMessages = setSavedVariable(DifficultBulletinBoardSavedVariables.filterMatchedMessages, DifficultBulletinBoardDefaults.defaultFilterMatchedMessages, "filterMatchedMessages")
    DifficultBulletinBoardVars.hardcoreOnly = setSavedVariable(DifficultBulletinBoardSavedVariables.hardcoreOnly, DifficultBulletinBoardDefaults.defaultHardcoreOnly, "hardcoreOnly")
    DifficultBulletinBoardVars.messageExpirationTime = setSavedVariable(DifficultBulletinBoardSavedVariables.messageExpirationTime, DifficultBulletinBoardDefaults.defaultMessageExpirationTime, "messageExpirationTime")

    -- Set placeholders variables
    DifficultBulletinBoardVars.numberOfGroupPlaceholders = setSavedVariable(DifficultBulletinBoardSavedVariables.numberOfGroupPlaceholders, DifficultBulletinBoardDefaults.defaultNumberOfGroupPlaceholders, "numberOfGroupPlaceholders")
    DifficultBulletinBoardVars.numberOfProfessionPlaceholders = setSavedVariable(DifficultBulletinBoardSavedVariables.numberOfProfessionPlaceholders, DifficultBulletinBoardDefaults.defaultNumberOfProfessionPlaceholders, "numberOfProfessionPlaceholders")
    DifficultBulletinBoardVars.numberOfHardcorePlaceholders = setSavedVariable(DifficultBulletinBoardSavedVariables.numberOfHardcorePlaceholders, DifficultBulletinBoardDefaults.defaultNumberOfHardcorePlaceholders, "numberOfHardcorePlaceholders")

    -- Set active topics, or default if not found
    DifficultBulletinBoardVars.allGroupTopics = setSavedVariable(DifficultBulletinBoardSavedVariables.activeGroupTopics, DifficultBulletinBoardDefaults.deepCopy(DifficultBulletinBoardDefaults.defaultGroupTopics), "activeGroupTopics")
    DifficultBulletinBoardVars.allProfessionTopics = setSavedVariable(DifficultBulletinBoardSavedVariables.activeProfessionTopics, DifficultBulletinBoardDefaults.deepCopy(DifficultBulletinBoardDefaults.defaultProfessionTopics), "activeProfessionTopics")
    DifficultBulletinBoardVars.allHardcoreTopics = setSavedVariable(DifficultBulletinBoardSavedVariables.activeHardcoreTopics, DifficultBulletinBoardDefaults.deepCopy(DifficultBulletinBoardDefaults.defaultHardcoreTopics), "activeHardcoreTopics")
    

end