-- DifficultBulletinBoard.lua
-- Main addon file for Difficult Bulletin Board
-- Handles event hooks, core functionality, and message filtering

DifficultBulletinBoard = DifficultBulletinBoard or {}
DifficultBulletinBoardVars = DifficultBulletinBoardVars or {}
DifficultBulletinBoardDefaults = DifficultBulletinBoardDefaults or {}
DifficultBulletinBoardOptionFrame = DifficultBulletinBoardOptionFrame or {}

local lastFilteredMessages = {}
local FILTER_LOG_TIMEOUT = 5 -- seconds

local string_gfind = string.gmatch or string.gfind

local mainFrame = DifficultBulletinBoardMainFrame
local optionFrame = DifficultBulletinBoardOptionFrame
local blacklistFrame = DifficultBulletinBoardBlacklistFrame

-- Flag to track if the last processed message was matched
local lastMessageWasMatched = false

-- Track previous messages to handle filtering
local previousMessages = {}

-- Global debug flag - off by default
local debugMode = false

local function print(string) 
    --DEFAULT_CHAT_FRAME:AddMessage(string) 
end

-- Debug function that prints to chat only when debug mode is enabled
local function debugPrint(string)
    if debugMode then
        DEFAULT_CHAT_FRAME:AddMessage("[DBB] " .. string, 1, 0.7, 0.2)
    end
end

-- Split input string into lowercase words for tag matching
function DifficultBulletinBoard.SplitIntoLowerWords(input)
    local tags = {}

    -- iterate over words (separated by spaces) and insert them into the tags table
    for tag in string_gfind(input, "%S+") do
        table.insert(tags, string.lower(tag))
    end

    return tags
end

-- Toggle the options frame visibility
-- Modify the DifficultBulletinBoard_ToggleOptionFrame function to close the blacklist frame
function DifficultBulletinBoard_ToggleOptionFrame()
    if optionFrame then
        if optionFrame:IsShown() then
            if DifficultBulletinBoardVars.optionFrameSound == "true" then
                PlaySound("igMainMenuClose");
            end
            -- Hide all dropdowns before hiding the frame
            DifficultBulletinBoardOptionFrame.HideAllDropdownMenus()
            optionFrame:Hide()
            -- Also hide the blacklist frame when closing the option frame
            if blacklistFrame and blacklistFrame:IsShown() then
                blacklistFrame:Hide()
            end
        else
            if DifficultBulletinBoardVars.optionFrameSound == "true" then
                PlaySound("igMainMenuClose");
            end
            optionFrame:Show()
            mainFrame:Hide()
        end
    else
        print("Option frame not found")
    end
end

-- Toggle the main bulletin board frame visibility
-- Modify the DifficultBulletinBoard_ToggleMainFrame function to close the blacklist frame
function DifficultBulletinBoard_ToggleMainFrame()
    if mainFrame then
        if mainFrame:IsShown() then
            if DifficultBulletinBoardVars.mainFrameSound == "true" then
                PlaySound("igQuestLogOpen");
            end
            mainFrame:Hide()
        else
            if DifficultBulletinBoardVars.mainFrameSound == "true" then
                PlaySound("igQuestLogClose");
            end
            -- Hide any open dropdowns when showing main frame
            if DifficultBulletinBoardOptionFrame.HideAllDropdownMenus then
                DifficultBulletinBoardOptionFrame.HideAllDropdownMenus()
            end
            mainFrame:Show()
            optionFrame:Hide()
            -- Also hide the blacklist frame when opening the main frame
            if blacklistFrame and blacklistFrame:IsShown() then
                blacklistFrame:Hide()
            end
        end
    else
        print("Main frame not found")
    end
end

-- Start minimap button dragging when shift+click
function DifficultBulletinBoard_DragMinimapStart()
    local button = DifficultBulletinBoard_MinimapButtonFrame

    if (IsShiftKeyDown()) and button then 
        button:StartMoving()
    end
end

-- Stop minimap button dragging and save position
function DifficultBulletinBoard_DragMinimapStop()
    local button = DifficultBulletinBoard_MinimapButtonFrame

    if button then
        button:StopMovingOrSizing()

        local x, y = button:GetCenter()
        button.db = button.db or {}
        button.db.posX = x
        button.db.posY = y
    end
end

-- Register slash commands
SLASH_DIFFICULTBB1 = "/dbb"
SlashCmdList["DIFFICULTBB"] = function() DifficultBulletinBoard_ToggleMainFrame() end

-- Debug slash command to toggle filter debug messages on/off
SLASH_DBBFILTERDEBUG1 = "/dbbfilterdebug"
SlashCmdList["DBBFILTERDEBUG"] = function(msg)
    debugMode = not debugMode
    
    -- This message always shows regardless of debug mode
    DEFAULT_CHAT_FRAME:AddMessage("[DBB] Filter debug mode " .. (debugMode and "ENABLED" or "DISABLED"), 1, 0.7, 0.2)
    
    -- Show additional information when debug is enabled
    if debugMode then
        debugPrint("Filtering is: " .. DifficultBulletinBoardVars.filterMatchedMessages)
        
        -- Show how many messages we're tracking
        local count = 0
        for _ in pairs(previousMessages) do count = count + 1 end
        debugPrint("Currently tracking " .. count .. " messages")
        
        -- Show keyword blacklist information if it exists
        if DifficultBulletinBoardSavedVariables.keywordBlacklist and 
           DifficultBulletinBoardSavedVariables.keywordBlacklist ~= "" then
            debugPrint("Keyword blacklist: " .. DifficultBulletinBoardSavedVariables.keywordBlacklist)
        else
            debugPrint("No keyword blacklist configured")
        end
    end
end

-- Initialize addon when loaded
local function initializeAddon(event, arg1)
    if event == "ADDON_LOADED" and arg1 == "DifficultBulletinBoard" then
        DifficultBulletinBoardVars.LoadSavedVariables()

        -- Create option frame first
        DifficultBulletinBoardOptionFrame.InitializeOptionFrame()

        -- Create main frame afterwards
        DifficultBulletinBoardMainFrame.InitializeMainFrame()
        
        -- Install ChatFrame_OnEvent hook (complete replacement)
        if not DifficultBulletinBoard.hookInstalled then
            DifficultBulletinBoard.originalChatFrameOnEvent = ChatFrame_OnEvent
            ChatFrame_OnEvent = DifficultBulletinBoard.hookedChatFrameOnEvent
            DifficultBulletinBoard.hookInstalled = true
            debugPrint("Chat filter installed. Filtering: " .. DifficultBulletinBoardVars.filterMatchedMessages)
        end
    end
end

-- Advanced function to check if a message contains a keyword as a whole word
local function messageContainsKeyword(message, keyword)
    -- Bail out on empty inputs
    if not message or not keyword or keyword == "" then
        return false
    end
    
    -- Convert both strings to lowercase for case-insensitive matching
    local lowerMessage = string.lower(message)
    local lowerKeyword = string.lower(keyword)
    
    -- Add spaces at beginning and end of message to help find boundaries
    lowerMessage = " " .. lowerMessage .. " "
    
    -- If keyword already contains punctuation, use more flexible matching for it
    if string.find(lowerKeyword, "[.,!?;:\"']") then
        -- 1. Exact match with spaces (standard case)
        if string.find(lowerMessage, " " .. lowerKeyword .. " ", 1, true) then
            return true
        end
        
        -- 2. At beginning of message
        if string.find(lowerMessage, "^ " .. lowerKeyword, 1, true) then
            return true
        end
        
        -- 3. At end of message
        if string.find(lowerMessage, " " .. lowerKeyword .. " $", 1, true) then
            return true
        end
        
        -- 4. With additional punctuation after (e.g. "members," followed by another punctuation)
        if string.find(lowerMessage, " " .. lowerKeyword .. "[.,!?;:\"']", 1, false) then
            return true
        end
        
        -- If we got here, no match found for the custom punctuated keyword
        return false
    end
    
    -- PATTERN MATCHING FOR REGULAR WORDS (without user-added punctuation)
    
    -- 1. Standard word match with spaces (most common case)
    if string.find(lowerMessage, " " .. lowerKeyword .. " ", 1, true) then
        return true
    end
    
    -- 2. Word followed by punctuation (catches "members," in text)
    local punctuation = "[.,!?;:\"'%-%)]"
    if string.find(lowerMessage, " " .. lowerKeyword .. punctuation, 1, false) then
        return true
    end
    
    -- 3. Word at start of message
    if string.find(lowerMessage, "^ " .. lowerKeyword .. "[ " .. punctuation .. "]", 1, false) then
        return true
    end
    
    -- 4. Word at end of message with possible punctuation
    if string.find(lowerMessage, " " .. lowerKeyword .. " $", 1, false) then
        return true
    end
    
    -- 5. Word with opening punctuation before it (less common)
    if string.find(lowerMessage, "[\"%('%-] *" .. lowerKeyword .. " ", 1, false) then
        return true
    end
    
    -- No whole word match found
    return false
end

-- Keyword management helper with punctuation support
function DifficultBulletinBoard_AddKeywordToBlacklist(keyword)
    -- Skip empty keywords
    if not keyword or keyword == "" then
        return
    end
    
    -- Ensure the blacklist variable exists
    if not DifficultBulletinBoardSavedVariables.keywordBlacklist then
        DifficultBulletinBoardSavedVariables.keywordBlacklist = ""
    end
    
    -- Trim spaces from the keyword
    keyword = string.gsub(keyword, "^%s*(.-)%s*$", "%1")
    
    -- Check if keyword is already in the blacklist (exact match)
    local currentBlacklist = DifficultBulletinBoardSavedVariables.keywordBlacklist
    for existingKeyword in string.gmatch(currentBlacklist, "[^,]+") do
        existingKeyword = string.gsub(existingKeyword, "^%s*(.-)%s*$", "%1") -- Trim spaces
        if existingKeyword == keyword then
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFFCC00[DBB]|r Keyword '" .. keyword .. "' is already in the blacklist.")
            return
        end
    end
    
    -- Add the keyword to the blacklist with a comma separator
    if currentBlacklist == "" then
        DifficultBulletinBoardSavedVariables.keywordBlacklist = keyword
    else
        DifficultBulletinBoardSavedVariables.keywordBlacklist = currentBlacklist .. "," .. keyword
    end
    
    -- Update UI elements with the new blacklist
    if DifficultBulletinBoard_SyncKeywordBlacklist then
        DifficultBulletinBoard_SyncKeywordBlacklist(DifficultBulletinBoardSavedVariables.keywordBlacklist)
    end
    
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFFCC00[DBB]|r Added keyword '" .. keyword .. "' to blacklist.")
end

-- Replacement for ChatFrame_OnEvent that implements message filtering
function DifficultBulletinBoard.hookedChatFrameOnEvent(event)
    -- Skip processing for irrelevant events or our own messages
    if not arg1 or not arg2 or arg2 == "" or arg2 == UnitName("player") or not arg9 then
        DifficultBulletinBoard.originalChatFrameOnEvent(event)
        return
    end
    
    -- Create a unique identifier for this message
    local messageKey = arg2 .. ":" .. arg1
    
    -- Check if we've recently logged this exact filtered message
    if lastFilteredMessages[messageKey] and lastFilteredMessages[messageKey] + FILTER_LOG_TIMEOUT > GetTime() then
        -- We've already logged this message recently, skip logging again
        if previousMessages[arg2] and previousMessages[arg2][3] then
            return -- Skip this message as it was marked for filtering
        end
    end
    
    -- Check if message is in the blacklist before any other processing
    if event == "CHAT_MSG_CHANNEL" and DifficultBulletinBoardSavedVariables.messageBlacklist and 
       DifficultBulletinBoardSavedVariables.messageBlacklist[arg1] then
        -- Only log if we haven't logged this message recently
        if not lastFilteredMessages[messageKey] or lastFilteredMessages[messageKey] + FILTER_LOG_TIMEOUT <= GetTime() then
            debugPrint("Filtering blacklisted message: " .. string.sub(arg1, 1, 40) .. "...")
            lastFilteredMessages[messageKey] = GetTime()
        end
        return -- Skip this message entirely as it's blacklisted
    end
    
    -- Check if message contains any blacklisted keywords
    if event == "CHAT_MSG_CHANNEL" and DifficultBulletinBoardSavedVariables.keywordBlacklist and 
       DifficultBulletinBoardSavedVariables.keywordBlacklist ~= "" then
        
        local message = arg1
        local keywordList = DifficultBulletinBoardSavedVariables.keywordBlacklist
        local hasMatchingKeyword = false
        local matchedKeyword = ""
        
        -- Split keywords by commas and check each one
        for keyword in string_gfind(keywordList, "[^,]+") do
            -- Trim whitespace
            keyword = string.gsub(keyword, "^%s*(.-)%s*$", "%1")
            
            -- Skip empty keywords
            if keyword ~= "" then
                if messageContainsKeyword(message, keyword) then
                    matchedKeyword = keyword
                    hasMatchingKeyword = true
                    break
                end
            end
        end
        
        if hasMatchingKeyword then
            -- Only log if we haven't logged this message recently
            if not lastFilteredMessages[messageKey] or lastFilteredMessages[messageKey] + FILTER_LOG_TIMEOUT <= GetTime() then
                debugPrint("Filtering message containing keyword '" .. matchedKeyword .. "': " .. 
                          string.sub(message, 1, 40) .. "...")
                lastFilteredMessages[messageKey] = GetTime()
            end
            
            -- Mark message as filtered in the previous messages tracker
            if previousMessages[arg2] then
                previousMessages[arg2][3] = true
            else
                previousMessages[arg2] = {arg1, GetTime(), true, arg9}
            end
            
            return -- Skip this message as it contains a blacklisted keyword
        end
    end
    
    -- Only process chat channel messages
    if event == "CHAT_MSG_CHANNEL" then
        -- Check if we've seen this message before
        if not previousMessages[arg2] or previousMessages[arg2][1] ~= arg1 or 
           previousMessages[arg2][2] + 30 < GetTime() then
            
            -- Store the message with: [1]=content, [2]=timestamp, [3]=shouldFilter
            previousMessages[arg2] = {arg1, GetTime(), false, arg9}
            
            -- Process with our addon's message handler
            lastMessageWasMatched = DifficultBulletinBoard.OnChatMessage(arg1, arg2, arg9)
            
            -- If matched and filtering enabled, mark for filtering
            if lastMessageWasMatched and DifficultBulletinBoardVars.filterMatchedMessages == "true" then
                -- Only log if we haven't logged this message recently
                if not lastFilteredMessages[messageKey] or lastFilteredMessages[messageKey] + FILTER_LOG_TIMEOUT <= GetTime() then
                    debugPrint("Filtering matched message: " .. string.sub(arg1, 1, 40) .. "...")
                    lastFilteredMessages[messageKey] = GetTime()
                end
                previousMessages[arg2][3] = true
                return -- Skip this message entirely
            end
        else
            -- This is a repeat message we've seen recently
            if previousMessages[arg2][3] then
                -- It was marked for filtering
                return -- Skip this message
            end
        end
    elseif event == "CHAT_MSG_SYSTEM" then
        lastMessageWasMatched = DifficultBulletinBoard.OnSystemMessage(arg1)
        
        if lastMessageWasMatched and DifficultBulletinBoardVars.filterMatchedMessages == "true" then
            -- Only log if we haven't logged this message recently
            if not lastFilteredMessages[messageKey] or lastFilteredMessages[messageKey] + FILTER_LOG_TIMEOUT <= GetTime() then
                debugPrint("Filtering system message: " .. string.sub(arg1, 1, 40) .. "...")
                lastFilteredMessages[messageKey] = GetTime()
            end
            return -- Skip this message
        end
    elseif event == "CHAT_MSG_HARDCORE" then
        lastMessageWasMatched = DifficultBulletinBoard.OnChatMessage(arg1, arg2, "HC")
        
        if lastMessageWasMatched and DifficultBulletinBoardVars.filterMatchedMessages == "true" then
            -- Only log if we haven't logged this message recently
            if not lastFilteredMessages[messageKey] or lastFilteredMessages[messageKey] + FILTER_LOG_TIMEOUT <= GetTime() then
                debugPrint("Filtering hardcore message: " .. string.sub(arg1, 1, 40) .. "...")
                lastFilteredMessages[messageKey] = GetTime()
            end
            return -- Skip this message
        end
    end
    
    -- Call the original handler for non-filtered messages
    DifficultBulletinBoard.originalChatFrameOnEvent(event)
end

-- Event handler for registered events
local function handleEvent()
    if event == "ADDON_LOADED" then 
        initializeAddon(event, arg1)
    end

    -- The message filtering is now handled by the hookedChatFrameOnEvent function
    -- so we just need to handle the ADDON_LOADED event here
end

-- Initialize with the current server time
local lastUpdateTime = GetTime() 
local lastCleanupTime = GetTime()

-- OnUpdate handler for regular tasks
local function OnUpdate()
    local currentTime = GetTime()
    local deltaTime = currentTime - lastUpdateTime

    -- Update only if at least 1 second has passed
    if deltaTime >= 1 then
        -- Update the lastUpdateTime
        lastUpdateTime = currentTime

        DifficultBulletinBoardMainFrame.UpdateServerTime()

        if DifficultBulletinBoardVars.timeFormat == "elapsed" then
            DifficultBulletinBoardMainFrame.UpdateElapsedTimes()
        end
        
        -- Clean up old message entries every 5 minutes
        if currentTime - lastCleanupTime > 300 then
            lastCleanupTime = currentTime
            local tempMessages = {}
            for sender, data in pairs(previousMessages) do
                if data[2] + 60 > GetTime() then
                    tempMessages[sender] = data
                end
            end
            previousMessages = tempMessages
        end
    end
end

-- DifficultBulletinBoard Frame Linking System
-- Links blacklist and option frames to move together
DifficultBulletinBoard.FrameLinker = DifficultBulletinBoard.FrameLinker or {}
local FrameLinker = DifficultBulletinBoard.FrameLinker

-- Configuration - spacing between linked frames
FrameLinker.FRAME_OFFSET_X = 1  -- Horizontal offset
FrameLinker.FRAME_OFFSET_Y = 0   -- Vertical offset

-- Create update frame for monitoring frame movement
local linkUpdateFrame = CreateFrame("Frame")
linkUpdateFrame:Hide()

-- Track frame movement and update linked frame position
linkUpdateFrame:SetScript("OnUpdate", function()
    local blacklistFrame = DifficultBulletinBoardBlacklistFrame
    local optionFrame = DifficultBulletinBoardOptionFrame
    
    -- Skip if either frame doesn't exist yet
    if not blacklistFrame or not optionFrame then
        return
    end
    
    -- Check if either frame is being moved
    if blacklistFrame.isMoving and optionFrame:IsShown() then
        -- Blacklist is moving, update option frame position
        optionFrame:ClearAllPoints()
        optionFrame:SetPoint("TOPRIGHT", blacklistFrame, "TOPLEFT", 
                           -FrameLinker.FRAME_OFFSET_X, FrameLinker.FRAME_OFFSET_Y)
    elseif optionFrame.isMoving and blacklistFrame:IsShown() then
        -- Option is moving, update blacklist frame position
        blacklistFrame:ClearAllPoints()
        blacklistFrame:SetPoint("TOPLEFT", optionFrame, "TOPRIGHT", 
                             FrameLinker.FRAME_OFFSET_X, FrameLinker.FRAME_OFFSET_Y)
    end
end)

-- Position blacklist relative to option frame with robust error handling
function FrameLinker.PositionBlacklistRelativeToOption()
    local blacklistFrame = DifficultBulletinBoardBlacklistFrame
    local optionFrame = DifficultBulletinBoardOptionFrame
    
    -- Verify both frames exist and are shown
    if not blacklistFrame or not optionFrame then
        return -- Silently exit if frames don't exist
    end
    
    if blacklistFrame:IsShown() and optionFrame:IsShown() then
        -- Safely get frame positions
        local optionRight = optionFrame:GetRight()
        local optionTop = optionFrame:GetTop()
        
        if optionRight and optionTop then
            -- Position blacklist frame to the right of option frame
            blacklistFrame:ClearAllPoints()
            blacklistFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 
                                 optionRight + FrameLinker.FRAME_OFFSET_X, 
                                 optionTop + FrameLinker.FRAME_OFFSET_Y)
        end
    end
end

-- Store original toggle function
local originalToggleBlacklist = DifficultBulletinBoard_ToggleBlacklistFrame

-- Override blacklist toggle function with robust error handling
DifficultBulletinBoard_ToggleBlacklistFrame = function()
    -- Make sure the module exists
    if not DifficultBulletinBoardBlacklistFrame then
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[DBB]|r Error: BlacklistFrame module not found")
        return
    end
    
    -- Toggle visibility with proper initialization
    if DifficultBulletinBoardBlacklistFrame:IsShown() then
        DifficultBulletinBoardBlacklistFrame:Hide()
    else
        -- Use the EnsureInitialized function to guarantee proper setup
        if DifficultBulletinBoardBlacklistFrame.EnsureInitialized then
            if not DifficultBulletinBoardBlacklistFrame.EnsureInitialized() then
                DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[DBB]|r Error: Failed to initialize blacklist frame")
                return
            end
        else
            -- Fallback to direct initialization if EnsureInitialized isn't available
            if DifficultBulletinBoardBlacklistFrame.InitializeBlacklistFrame then
                DifficultBulletinBoardBlacklistFrame.InitializeBlacklistFrame()
            else
                DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[DBB]|r Error: Cannot initialize blacklist frame")
                return
            end
        end
        
        -- Show the frame after successful initialization
        DifficultBulletinBoardBlacklistFrame:Show()
        
        -- Refresh the content
        if DifficultBulletinBoardBlacklistFrame.RefreshBlacklist then
            DifficultBulletinBoardBlacklistFrame.RefreshBlacklist()
        end
    end
    
    -- Position the frame if needed
    if FrameLinker and FrameLinker.PositionBlacklistRelativeToOption then
        FrameLinker.PositionBlacklistRelativeToOption()
    end
end

-- Start tracking frame movement
linkUpdateFrame:Show()

-- Register events and set up script handlers
mainFrame:RegisterEvent("ADDON_LOADED")
mainFrame:RegisterEvent("CHAT_MSG_CHANNEL")
mainFrame:RegisterEvent("CHAT_MSG_HARDCORE")
mainFrame:RegisterEvent("CHAT_MSG_SYSTEM")
mainFrame:SetScript("OnEvent", handleEvent)
mainFrame:SetScript("OnUpdate", OnUpdate)