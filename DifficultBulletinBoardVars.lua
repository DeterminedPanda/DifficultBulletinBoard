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

DifficultBulletinBoardSavedVariables.playerList = DifficultBulletinBoardSavedVariables.playerList or {}
DifficultBulletinBoardSavedVariables.keywordBlacklist = DifficultBulletinBoardSavedVariables.keywordBlacklist or ""




-- Retrieves a player's class from the saved database
function DifficultBulletinBoardVars.GetPlayerClassFromDatabase(name)
    local realmName = GetRealmName()

    -- Add or update the player entry
    if DifficultBulletinBoardSavedVariables.playerList[realmName][name] then
        return DifficultBulletinBoardSavedVariables.playerList[realmName][name].class
    else
        return nil
    end
end

-- Adds a player to the class database
function DifficultBulletinBoardVars.AddPlayerToDatabase(name, class)
    local realmName = GetRealmName()

    -- Add or update the player entry
    DifficultBulletinBoardSavedVariables.playerList[realmName][name] = {
        class = class
    }


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
    DifficultBulletinBoardSavedVariables.playerList = DifficultBulletinBoardSavedVariables.playerList or {}
    DifficultBulletinBoardSavedVariables.keywordBlacklist = DifficultBulletinBoardSavedVariables.keywordBlacklist or ""
    
    local realmName = GetRealmName()
    DifficultBulletinBoardSavedVariables.playerList[realmName] = DifficultBulletinBoardSavedVariables.playerList[realmName] or {}

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