-- DifficultBulletinBoardMessageProcessor.lua
-- Message processing, filtering, and data management for Difficult Bulletin Board
-- Handles chat message analysis, entry management, tooltips, and filtering

-- Ensure global namespaces exist
DifficultBulletinBoard = DifficultBulletinBoard or {}
DifficultBulletinBoardVars = DifficultBulletinBoardVars or {}
DifficultBulletinBoardMainFrame = DifficultBulletinBoardMainFrame or {}
DifficultBulletinBoardMessageProcessor = DifficultBulletinBoardMessageProcessor or {}

-- Local reference for string.gfind compatibility
local string_gfind = string.gmatch or string.gfind

-- Forward declarations for variables that will be set by the main frame
local groupTopicPlaceholders
local groupsLogsPlaceholders
local professionTopicPlaceholders
local hardcoreTopicPlaceholders
local currentGroupsLogsFilter
local MAX_GROUPS_LOGS_ENTRIES
local RepackEntries
local ReflowTopicEntries

-- Initialize function to receive references from main frame
function DifficultBulletinBoardMessageProcessor.Initialize(placeholders, filter, maxEntries, helpers)
    groupTopicPlaceholders = placeholders.groupTopicPlaceholders
    groupsLogsPlaceholders = placeholders.groupsLogsPlaceholders
    professionTopicPlaceholders = placeholders.professionTopicPlaceholders
    hardcoreTopicPlaceholders = placeholders.hardcoreTopicPlaceholders
    currentGroupsLogsFilter = filter
    MAX_GROUPS_LOGS_ENTRIES = maxEntries
    
    -- Store helper functions if provided
    if helpers then
        RepackEntries = helpers.RepackEntries
        ReflowTopicEntries = helpers.ReflowTopicEntries
    end
end

-- Apply filter to Groups Logs entries
function DifficultBulletinBoardMessageProcessor.ApplyGroupsLogsFilter(searchText)
    -- Only filter if we have entries to filter
    if groupsLogsPlaceholders and groupsLogsPlaceholders["Group Logs"] then
        -- Process each entry
        for _, entry in ipairs(groupsLogsPlaceholders["Group Logs"]) do
            -- Check if this is a valid entry with name and message
            if entry and entry.nameButton and entry.messageFontString then
                local name = entry.nameButton:GetText() or ""
                local message = entry.messageFontString:GetText() or ""
                
                -- Skip placeholders
                if name == "-" or message == "-" then
                    -- Do nothing for placeholder entries
                else
                    -- If no search text, show everything
                    if searchText == "" then
                        entry.nameButton:SetAlpha(1.0)
                        entry.messageFontString:SetAlpha(1.0)
                        entry.timeFontString:SetAlpha(1.0)
                        if entry.icon then entry.icon:SetAlpha(1.0) end
                    else
                        -- Prepare terms for comma-separated search
                        local terms = {}
                        for term in string_gfind(searchText, "[^,]+") do
                            term = string.gsub(term, "^%s*(.-)%s*$", "%1") -- Trim whitespace
                            table.insert(terms, term)
                        end
                        
                        -- Convert entry text to lowercase
                        local lowerName = string.lower(name)
                        local lowerMessage = string.lower(message)
                        
                        -- Check all search terms
                        local matches = false
                        for _, term in ipairs(terms) do
                            if term ~= "" and 
                              (string.find(lowerName, term, 1, true) or 
                               string.find(lowerMessage, term, 1, true)) then
                                matches = true
                                break
                            end
                        end
                        
                        -- Set visibility based on match result
                        if matches then
                            entry.nameButton:SetAlpha(1.0)
                            entry.messageFontString:SetAlpha(1.0)
                            entry.timeFontString:SetAlpha(1.0)
                            if entry.icon then entry.icon:SetAlpha(1.0) end
                        else
                            entry.nameButton:SetAlpha(0.25)
                            entry.messageFontString:SetAlpha(0.25)
                            entry.timeFontString:SetAlpha(0.25)
                            if entry.icon then entry.icon:SetAlpha(0.25) end
                        end
                    end
                end
            end
        end
    end
end

-- Function to reduce noise in messages and making matching easier
local function replaceSymbolsWithSpace(inputString)
    return string.gsub(inputString, "[,/!%?.]", " ")
end

local function topicPlaceholdersContainsCharacterName(topicPlaceholders, topicName, characterName)
    local topicData = topicPlaceholders[topicName]
    if not topicData then
        return false, nil
    end

    for index, row in ipairs(topicData) do
        local nameColumn = row.nameButton

        if nameColumn:GetText() == characterName then
            return true, index
        end
    end

    return false, nil
end

local function getClassIconFromClassName(class) 
    if class == "Druid" then
        return "Interface\\AddOns\\DifficultBulletinBoard\\icons\\druid_class_icon"
    elseif class == "Hunter" then
        return "Interface\\AddOns\\DifficultBulletinBoard\\icons\\hunter_class_icon"
    elseif class == "Mage" then
        return "Interface\\AddOns\\DifficultBulletinBoard\\icons\\mage_class_icon"
    elseif class == "Paladin" then
        return "Interface\\AddOns\\DifficultBulletinBoard\\icons\\paladin_class_icon"
    elseif class == "Priest" then
        return "Interface\\AddOns\\DifficultBulletinBoard\\icons\\priest_class_icon"
    elseif class == "Rogue" then
        return "Interface\\AddOns\\DifficultBulletinBoard\\icons\\rogue_class_icon"
    elseif class == "Shaman" then
        return "Interface\\AddOns\\DifficultBulletinBoard\\icons\\shaman_class_icon"
    elseif class == "Warlock" then
        return "Interface\\AddOns\\DifficultBulletinBoard\\icons\\warlock_class_icon"
    elseif class == "Warrior" then
        return "Interface\\AddOns\\DifficultBulletinBoard\\icons\\warrior_class_icon"
    else
        return nil
    end
end

-- Updates the specified placeholder for a topic with new name, message, and timestamp,
-- then moves the updated entry to the top of the list, shifting other entries down.
local function UpdateTopicEntryAndPromoteToTop(topicPlaceholders, topic, numberOfPlaceholders, channelName, name, message, index)
    local topicData = topicPlaceholders[topic]

    local timestamp
    if DifficultBulletinBoardVars.timeFormat == "elapsed" then
        timestamp = "00:00"
    else 
        timestamp = date("%H:%M:%S")
    end

    -- Shift all entries down from index 1 to the updated entry's position
    for i = index, 2, -1 do
        topicData[i].nameButton:SetText(topicData[i - 1].nameButton:GetText())
        topicData[i].messageFontString:SetText(topicData[i - 1].messageFontString:GetText())
        topicData[i].timeFontString:SetText(topicData[i - 1].timeFontString:GetText())
        topicData[i].creationTimestamp = topicData[i - 1].creationTimestamp
        topicData[i].icon:SetTexture(topicData[i - 1].icon:GetTexture())
    end

    -- Place the updated entry's data at the top
    topicData[1].nameButton:SetText(name)
    -- Add this line to update hit rect for updated name
    topicData[1].nameButton:SetHitRectInsets(0, -45, 0, 0)
    
    topicData[1].messageFontString:SetText("[" .. channelName .. "] " .. message or "No Message")
    topicData[1].timeFontString:SetText(timestamp)
    topicData[1].creationTimestamp = date("%H:%M:%S")
    local class = DifficultBulletinBoardVars.GetPlayerClassFromDatabase(name)
    topicData[1].icon:SetTexture(getClassIconFromClassName(class))

    -- Tooltip handlers are now dynamic and don't need manual updates
    
    -- Apply filter if this is a Groups Logs entry
    if topic == "Group Logs" and topicPlaceholders == groupsLogsPlaceholders then
        local currentFilter = ""
        if DifficultBulletinBoardMainFrame and DifficultBulletinBoardMainFrame.GetCurrentGroupsLogsFilter then
            currentFilter = DifficultBulletinBoardMainFrame.GetCurrentGroupsLogsFilter()
        end
        DifficultBulletinBoardMessageProcessor.ApplyGroupsLogsFilter(currentFilter)
    end
end

-- Helper function to convert HH:MM:SS to seconds
local function timeToSeconds(timeString)
    --idk how else to do it :/ just loop over and return the first match
    for hours, minutes, seconds in string_gfind(timeString, "(%d+):(%d+):(%d+)") do
        return (tonumber(hours) * 3600) + (tonumber(minutes) * 60) + tonumber(seconds)
    end
end
    
-- Helper function to format seconds into MM:SS
local function secondsToMMSS(totalSeconds)
    local minutes = math.floor(totalSeconds / 60)
    local seconds = totalSeconds - math.floor(totalSeconds / 60) * 60

    -- Return "99:59" if minutes exceed 99
    if minutes > 99 then
        return "99:59"
    end

    return string.format("%02d:%02d", minutes, seconds)
end

-- Calculate delta in MM:SS format
local function calculateDelta(creationTimestamp, currentTime)
    local creationInSeconds = timeToSeconds(creationTimestamp)
    local currentInSeconds = timeToSeconds(currentTime)
    local deltaSeconds = currentInSeconds - creationInSeconds

    -- Handle negative delta (e.g., crossing midnight)
    if deltaSeconds < 0 then
        -- Add a day's worth of seconds
        deltaSeconds = deltaSeconds + 86400 
    end

    return secondsToMMSS(deltaSeconds)
end

-- Function to add a new entry to the given topic with and shift other entries down
local function AddNewTopicEntryAndShiftOthers(topicPlaceholders, topic, numberOfPlaceholders, channelName, name, message)
    local topicData = topicPlaceholders[topic]
    if not topicData or not topicData[1] then
        return
    end

    local timestamp
    if DifficultBulletinBoardVars.timeFormat == "elapsed" then
        timestamp = "00:00"
    else 
        timestamp = date("%H:%M:%S")
    end

    for i = numberOfPlaceholders, 2, -1 do
        -- Copy the data from the previous placeholder to the current one
        local currentFontString = topicData[i]
        local previousFontString = topicData[i - 1]
        
        if not currentFontString or not previousFontString then
            break
        end

        -- Update the current placeholder with the previous placeholder's data safely
        if currentFontString.nameButton and type(currentFontString.nameButton.SetText) == "function" and
           previousFontString.nameButton and type(previousFontString.nameButton.GetText) == "function" then
            currentFontString.nameButton:SetText(previousFontString.nameButton:GetText())
        end
        
        if currentFontString.messageFontString and type(currentFontString.messageFontString.SetText) == "function" and
           previousFontString.messageFontString and type(previousFontString.messageFontString.GetText) == "function" then
            currentFontString.messageFontString:SetText(previousFontString.messageFontString:GetText())
        end
        
        if currentFontString.timeFontString and type(currentFontString.timeFontString.SetText) == "function" and
           previousFontString.timeFontString and type(previousFontString.timeFontString.GetText) == "function" then
            currentFontString.timeFontString:SetText(previousFontString.timeFontString:GetText())
        end
        
        currentFontString.creationTimestamp = previousFontString.creationTimestamp
        
        if currentFontString.icon and type(currentFontString.icon.SetTexture) == "function" and
           previousFontString.icon and type(previousFontString.icon.GetTexture) == "function" then
            currentFontString.icon:SetTexture(previousFontString.icon:GetTexture())
        end
    end

    -- Update the first placeholder with the new data safely
    local firstFontString = topicData[1]
    if firstFontString.nameButton and type(firstFontString.nameButton.SetText) == "function" then
        firstFontString.nameButton:SetText(name)
        -- Add this line to update hit rect for the new name
        firstFontString.nameButton:SetHitRectInsets(0, -45, 0, 0)
    end
    
    if firstFontString.messageFontString and type(firstFontString.messageFontString.SetText) == "function" then
        firstFontString.messageFontString:SetText("[" .. channelName .. "] " .. message)
    end
    
    if firstFontString.timeFontString and type(firstFontString.timeFontString.SetText) == "function" then
        firstFontString.timeFontString:SetText(timestamp)
    end
    
    firstFontString.creationTimestamp = date("%H:%M:%S")
    local class = DifficultBulletinBoardVars.GetPlayerClassFromDatabase(name)
    
    if firstFontString.icon and type(firstFontString.icon.SetTexture) == "function" then
        firstFontString.icon:SetTexture(getClassIconFromClassName(class))
    end

    -- Show a RaidWarning for enabled notifications. dont show it for the Group Logs
    if topic ~= "Group Logs" and DifficultBulletinBoard.notificationList[topic] == true then
        if DifficultBulletinBoardVars.notificationSound == "true" then
            PlaySound("TellMessage")
        end
        RaidWarningFrame:AddMessage("DBB Notification: " .. message)
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFCC00[DBB Notification]|r " .. "|Hplayer:" .. name .. "|h[" .. name .. "]|h" .. " :|cFFB2B2FF" .. message)
    end
    
    -- Apply filter if this is a Groups Logs entry
    if topic == "Group Logs" and topicPlaceholders == groupsLogsPlaceholders then
        local currentFilter = ""
        if DifficultBulletinBoardMainFrame and DifficultBulletinBoardMainFrame.GetCurrentGroupsLogsFilter then
            currentFilter = DifficultBulletinBoardMainFrame.GetCurrentGroupsLogsFilter()
        end
        DifficultBulletinBoardMessageProcessor.ApplyGroupsLogsFilter(currentFilter)
    end
end

-- Function to update the first placeholder for a given topic with new message, and time and shift other placeholders down
local function AddNewSystemTopicEntryAndShiftOthers(topicPlaceholders, topic, message)
    local topicData = topicPlaceholders[topic]
    if not topicData or not topicData[1] then
        return
    end

    local timestamp
    if DifficultBulletinBoardVars.timeFormat == "elapsed" then
        timestamp = "00:00"
    else 
        timestamp = date("%H:%M:%S")
    end

    local index = 0
    for i, _ in ipairs(topicData) do index = i end
        for i = index, 2, -1 do
            -- Copy the data from the previous placeholder to the current one
            local currentFontString = topicData[i]
            local previousFontString = topicData[i - 1]
            
            if not currentFontString or not previousFontString then
                break
            end

            -- Update the current placeholder with the previous placeholder's data safely
            if currentFontString.messageFontString and type(currentFontString.messageFontString.SetText) == "function" and
               previousFontString.messageFontString and type(previousFontString.messageFontString.GetText) == "function" then
                currentFontString.messageFontString:SetText(previousFontString.messageFontString:GetText())
            end
            
            if currentFontString.timeFontString and type(currentFontString.timeFontString.SetText) == "function" and
               previousFontString.timeFontString and type(previousFontString.timeFontString.GetText) == "function" then
                currentFontString.timeFontString:SetText(previousFontString.timeFontString:GetText())
            end
            
            currentFontString.creationTimestamp = previousFontString.creationTimestamp
        end

    -- Update the first placeholder with the new data safely
    local firstFontString = topicData[1]
    if firstFontString.messageFontString and type(firstFontString.messageFontString.SetText) == "function" then
        firstFontString.messageFontString:SetText(message)
    end
    
    if firstFontString.timeFontString and type(firstFontString.timeFontString.SetText) == "function" then
        firstFontString.timeFontString:SetText(timestamp)
    end
    
    firstFontString.creationTimestamp = date("%H:%M:%S")

    -- Tooltip handlers are now dynamic and don't need manual updates
end

-- Function to check if a character name already exists in the Groups Logs
local function groupsLogsContainsCharacterName(characterName)
    if not groupsLogsPlaceholders["Group Logs"] then
        return false, nil
    end
    
    local entries = groupsLogsPlaceholders["Group Logs"]
    for index, entry in ipairs(entries) do
        if entry.nameButton and entry.nameButton:GetText() == characterName then
            return true, index
        end
    end
    
    return false, nil
end

-- Searches the passed topicList for the passed words. If a match is found the topicPlaceholders will be updated
local function analyzeChatMessage(channelName, characterName, chatMessage, words, topicList, topicPlaceholders, numberOfPlaceholders)
    local isAnyMatch = false
    local isGroupMatch = false
    
    for _, topic in ipairs(topicList) do
        if topic.selected then
            local matchFound = false -- Flag to control breaking out of nested loops

            for _, tag in ipairs(topic.tags) do
                for _, word in ipairs(words) do
                    if word == string.lower(tag) then
                        local found, index = topicPlaceholdersContainsCharacterName(topicPlaceholders, topic.name, characterName)
                        if found then
                            UpdateTopicEntryAndPromoteToTop(topicPlaceholders, topic.name, numberOfPlaceholders, channelName, characterName, chatMessage, index)
                        else
                            AddNewTopicEntryAndShiftOthers(topicPlaceholders, topic.name, numberOfPlaceholders, channelName, characterName, chatMessage)
                        end

                        matchFound = true -- Set the flag to true to break out of loops
                        isAnyMatch = true -- Set the outer function result
                        
                        -- If this is a group topic, mark it
                        if topicList == DifficultBulletinBoardVars.allGroupTopics then
                            isGroupMatch = true
                        end
                        
                        break
                    end
                end

                if matchFound then break end
            end
            
            --if matchFound then break end --removed because it would skip remaining topics
        end
    end
    
    return isGroupMatch == true and isGroupMatch or isAnyMatch
end

-- Searches the passed topicList for the passed words. If a match is found the topicPlaceholders will be updated
local function analyzeSystemMessage(chatMessage, words, topicList, topicPlaceholders)
    local isAnyMatch = false
    
    for _, topic in ipairs(topicList) do
        if topic.selected then
            local matchFound = false -- Flag to control breaking out of nested loops

            for _, tag in ipairs(topic.tags) do
                for _, word in ipairs(words) do
                    if word == string.lower(tag) then
                        AddNewSystemTopicEntryAndShiftOthers(topicPlaceholders, topic.name, chatMessage)

                        matchFound = true -- Set the flag to true to break out of loops
                        isAnyMatch = true -- Set the outer function result
                        break
                    end
                end

                if matchFound then break end
            end
            
            if matchFound then break end
        end
    end
    
    return isAnyMatch
end

-- Process chat messages and add matched content to the appropriate sections
function DifficultBulletinBoard.OnChatMessage(arg1, arg2, arg9)
    local chatMessage = arg1
    local characterName = arg2
    local channelName = arg9

    if characterName == "" or characterName == nil then
        return
    end
    
    local stringWithoutNoise = replaceSymbolsWithSpace(chatMessage)

    local words = DifficultBulletinBoard.SplitIntoLowerWords(stringWithoutNoise)

    if DifficultBulletinBoardVars.hardcoreOnly == "true" and channelName ~= "HC" then
        local found = false
        for _, w in ipairs(words) do
            if w == "hc" or w == "hardcore" or w == "inferno" then
                found = true
                break
            end
        end

       -- bail out if nothing matched
        if not found then
            return
        end
    end

    -- Process group topics and check if it's a group-related message
    local isGroupMessage = analyzeChatMessage(channelName, characterName, chatMessage, words, 
                         DifficultBulletinBoardVars.allGroupTopics, 
                         groupTopicPlaceholders, 
                         DifficultBulletinBoardVars.numberOfGroupPlaceholders)
    
    -- After updating group entries, reflow the Groups tab
    if isGroupMessage then DifficultBulletinBoardMainFrame.ReflowGroupsTab() end
    
    -- If it's a group message, add it to the Groups Logs with duplicate checking
    if isGroupMessage then
        local found, index = groupsLogsContainsCharacterName(characterName)
        if found then
            -- Update the existing entry and move it to the top
            local entries = groupsLogsPlaceholders["Group Logs"]
            if not entries then
                return isGroupMessage or isProfessionMessage
            end
            
            -- Get timestamp
            local timestamp
            if DifficultBulletinBoardVars.timeFormat == "elapsed" then
                timestamp = "00:00"
            else 
                timestamp = date("%H:%M:%S")
            end
            
            -- Shift entries down from index to top
            for i = index, 2, -1 do
                if not entries[i] or not entries[i-1] then
                    break
                end
                
                if entries[i].nameButton and type(entries[i].nameButton.SetText) == "function" and
                   entries[i-1].nameButton and type(entries[i-1].nameButton.GetText) == "function" then
                    entries[i].nameButton:SetText(entries[i-1].nameButton:GetText())
                end
                
                if entries[i].messageFontString and type(entries[i].messageFontString.SetText) == "function" and
                   entries[i-1].messageFontString and type(entries[i-1].messageFontString.GetText) == "function" then
                    entries[i].messageFontString:SetText(entries[i-1].messageFontString:GetText())
                end
                
                if entries[i].timeFontString and type(entries[i].timeFontString.SetText) == "function" and
                   entries[i-1].timeFontString and type(entries[i-1].timeFontString.GetText) == "function" then
                    entries[i].timeFontString:SetText(entries[i-1].timeFontString:GetText())
                end
                
                entries[i].creationTimestamp = entries[i-1].creationTimestamp
                
                if entries[i].icon and type(entries[i].icon.SetTexture) == "function" and
                   entries[i-1].icon and type(entries[i-1].icon.GetTexture) == "function" then
                    entries[i].icon:SetTexture(entries[i-1].icon:GetTexture())
                end
            end
            
            -- Update top entry
            if entries[1] and entries[1].nameButton and type(entries[1].nameButton.SetText) == "function" then
                entries[1].nameButton:SetText(characterName)
            end
            
            if entries[1] and entries[1].messageFontString and type(entries[1].messageFontString.SetText) == "function" then
                entries[1].messageFontString:SetText("[" .. channelName .. "] " .. chatMessage)
            end
            
            if entries[1] and entries[1].timeFontString and type(entries[1].timeFontString.SetText) == "function" then
                entries[1].timeFontString:SetText(timestamp)
            end
            
            entries[1].creationTimestamp = date("%H:%M:%S")
            
            local class = DifficultBulletinBoardVars.GetPlayerClassFromDatabase(characterName)
            if entries[1] and entries[1].icon and type(entries[1].icon.SetTexture) == "function" then
                entries[1].icon:SetTexture(getClassIconFromClassName(class))
            end
            
            -- reflow Group Logs placeholders first
            local glEntries = groupsLogsPlaceholders["Group Logs"]
            if glEntries then
                DifficultBulletinBoardMainFrame.RepackEntries(glEntries)
                DifficultBulletinBoardMainFrame.ReflowTopicEntries(glEntries)
                -- Reflow the Groups tab to adjust to updated entries
                DifficultBulletinBoardMainFrame.ReflowGroupsTab()
            end
            
            -- Apply the current filter AFTER repack/reflow to ensure it's not overridden
            local currentFilter = ""
            if DifficultBulletinBoardMainFrame and DifficultBulletinBoardMainFrame.GetCurrentGroupsLogsFilter then
                currentFilter = DifficultBulletinBoardMainFrame.GetCurrentGroupsLogsFilter()
            end
            DifficultBulletinBoardMessageProcessor.ApplyGroupsLogsFilter(currentFilter)
        else
            -- Add as new entry
            AddNewTopicEntryAndShiftOthers(groupsLogsPlaceholders, "Group Logs", MAX_GROUPS_LOGS_ENTRIES, channelName, characterName, chatMessage)
            -- reflow after adding new entry
            local glEntries = groupsLogsPlaceholders["Group Logs"]
            if glEntries then
                DifficultBulletinBoardMainFrame.RepackEntries(glEntries)
                DifficultBulletinBoardMainFrame.ReflowTopicEntries(glEntries)
                -- Reflow the Groups tab after adding new entry
                DifficultBulletinBoardMainFrame.ReflowGroupsTab()
            end
            
            -- Apply the current filter AFTER repack/reflow to ensure it's not overridden
            local currentFilter = ""
            if DifficultBulletinBoardMainFrame and DifficultBulletinBoardMainFrame.GetCurrentGroupsLogsFilter then
                currentFilter = DifficultBulletinBoardMainFrame.GetCurrentGroupsLogsFilter()
            end
            DifficultBulletinBoardMessageProcessor.ApplyGroupsLogsFilter(currentFilter)
        end
    end

    -- Reapply manual expiration setting to keep old entries hidden
    if DifficultBulletinBoardVars.manualExpireSeconds then
        DifficultBulletinBoard.ExpireMessages(DifficultBulletinBoardVars.manualExpireSeconds)
    end

    -- Process profession topics as usual
    local isProfessionMessage = analyzeChatMessage(channelName, characterName, chatMessage, words, 
                      DifficultBulletinBoardVars.allProfessionTopics, 
                      professionTopicPlaceholders, 
                      DifficultBulletinBoardVars.numberOfProfessionPlaceholders)
    
    -- After updating profession entries, reflow the Professions tab
    if isProfessionMessage then DifficultBulletinBoardMainFrame.ReflowProfessionsTab() end
    
    -- Return true if any match was found
    return isGroupMessage or isProfessionMessage
end

function DifficultBulletinBoard.OnSystemMessage(arg1)
    local systemMessage = arg1

    local stringWithoutNoise = replaceSymbolsWithSpace(systemMessage)

    local words = DifficultBulletinBoard.SplitIntoLowerWords(stringWithoutNoise)

    local isMatched = analyzeSystemMessage(systemMessage, words, DifficultBulletinBoardVars.allHardcoreTopics, hardcoreTopicPlaceholders)
    
    -- After updating hardcore entries, reflow the Hardcore tab
    if isMatched then DifficultBulletinBoardMainFrame.ReflowHardcoreTab() end
    
    return isMatched
end

-- Dynamic tooltip system that finds the correct message based on visual position
-- This solves the issue where repositioned entries show wrong tooltips
function DifficultBulletinBoardMainFrame.ShowDynamicTooltip(frame)
    if not frame then
        return
    end
    
    -- Get frame position for position-based matching
    local frameX, frameY = frame:GetLeft(), frame:GetTop()
    
    -- Find message by matching VISIBLE position instead of frame object
    -- This works because reflow functions reposition frames but don't change the frame objects
    local message = nil
    local bestMatch = nil
    local POSITION_TOLERANCE = 2.0  -- Allow 2 pixel tolerance for position matching
    
    -- Search all placeholder tables for frames at the same visual position
    local allPlaceholderTables = {
        {name = "Groups", table = groupTopicPlaceholders},
        {name = "GroupsLogs", table = groupsLogsPlaceholders},
        {name = "Professions", table = professionTopicPlaceholders},
        {name = "Hardcore", table = hardcoreTopicPlaceholders}
    }
    
    for _, placeholderInfo in ipairs(allPlaceholderTables) do
        local placeholderTable = placeholderInfo.table
        for topicName, entries in pairs(placeholderTable) do
            for entryIndex, entry in ipairs(entries) do
                -- Check if this entry has a visible message frame
                if entry.messageFrame and entry.messageFrame:IsVisible() then
                    local entryX, entryY = entry.messageFrame:GetLeft(), entry.messageFrame:GetTop()
                    
                    -- Check if positions match within tolerance
                    if entryX and entryY and frameX and frameY then
                        local deltaX = math.abs(entryX - frameX)
                        local deltaY = math.abs(entryY - frameY)
                        
                        if deltaX <= POSITION_TOLERANCE and deltaY <= POSITION_TOLERANCE then
                            local msg = entry.messageFontString and entry.messageFontString:GetText() or ""
                            
                            -- Prefer entries with actual content over placeholders
                            if msg and msg ~= "-" and msg ~= "" then
                                message = msg
                                bestMatch = entry
                                break
                            elseif not bestMatch then
                                -- Keep this as a fallback if no better match is found
                                bestMatch = entry
                            end
                        end
                    end
                end
            end
            if message and message ~= "-" and message ~= "" then break end
        end
        if message and message ~= "-" and message ~= "" then break end
    end
    
    -- Show tooltip if we found a valid message
    if message and message ~= "-" and message ~= "" then
        DifficultBulletinBoardMainFrame.ShowMessageTooltip(frame, message)
    end
end

-- Robust tooltip helper function to handle common tooltip issues in Vanilla WoW
function DifficultBulletinBoardMainFrame.ShowMessageTooltip(frame, message)
    if not frame then
        return
    end
    
    if not message or message == "-" or message == "" then
        return
    end
    
    -- Check if GameTooltip exists
    if not GameTooltip then
        return
    end
    
    -- Ensure GameTooltip is properly reset before use
    GameTooltip:Hide()
    GameTooltip:ClearLines()
    
    -- Set owner and anchor with error checking
    if GameTooltip.SetOwner then
        GameTooltip:SetOwner(frame, "ANCHOR_CURSOR")
    else
        return -- GameTooltip not available
    end
    
    -- Set the text with word wrapping enabled
    GameTooltip:SetText(message, 1, 1, 1, 1, true)
    
    -- Ensure proper font and sizing for better readability using user's font size setting + 2
    if GameTooltipTextLeft1 and GameTooltipTextLeft1.SetFont then
        local tooltipFontSize = (DifficultBulletinBoardVars.fontSize or 12) + 2
        GameTooltipTextLeft1:SetFont("Fonts\\ARIALN.TTF", tooltipFontSize, "")
    end
    
    -- Set tooltip border color to match header color (light blue-white)
    if GameTooltip.SetBackdropBorderColor then
        GameTooltip:SetBackdropBorderColor(0.9, 0.9, 1.0, 1.0)
    end
    
    -- Force the tooltip to appear on top of other UI elements
    GameTooltip:SetFrameStrata("TOOLTIP")
    
    -- Show the tooltip
    GameTooltip:Show()
end

-- Safe tooltip hide function
function DifficultBulletinBoardMainFrame.HideMessageTooltip(frame)
    if GameTooltip and GameTooltip.IsOwned and GameTooltip:IsOwned(frame) then
        GameTooltip:Hide()
    elseif GameTooltip and GameTooltip.Hide then
        -- Fallback for cases where IsOwned might not work
        GameTooltip:Hide()
    end
end

-- Helper to reflow entries and remove blank gaps (supports optional nameButton/icon)
function DifficultBulletinBoardMainFrame.RepackEntries(entries)
    -- Collect non-expired entries data
    local validData = {}
    for _, entry in ipairs(entries) do
        if entry.creationTimestamp then
            local item = {
                message = entry.messageFontString and entry.messageFontString:GetText() or "",
                timeText = entry.timeFontString and entry.timeFontString:GetText() or "",
                timestamp = entry.creationTimestamp
            }
            if entry.nameButton then
                item.name = entry.nameButton:GetText()
            end
            if entry.icon then
                item.iconTexture = entry.icon:GetTexture()
            end
            table.insert(validData, item)
        end
    end
    local validCount = table.getn(validData)
    for i, entry in ipairs(entries) do
        if i <= validCount then
            local data = validData[i]
            if entry.nameButton and data.name then
                entry.nameButton:SetText(data.name)
                entry.nameButton:Show()
            end
            if entry.messageFontString then
                entry.messageFontString:SetText(data.message)
                entry.messageFontString:Show()
            end
            if entry.timeFontString then
                entry.timeFontString:SetText(data.timeText)
                entry.timeFontString:Show()
            end
            entry.creationTimestamp = data.timestamp
            if entry.icon then
                if data.iconTexture then
                    entry.icon:SetTexture(data.iconTexture)
                    entry.icon:Show()
                else
                    entry.icon:Hide()
                end
            end
        else
            if entry.nameButton then
                entry.nameButton:SetText("-")
                entry.nameButton:Show()
            end
            if entry.messageFontString then
                entry.messageFontString:SetText("-")
                entry.messageFontString:Show()
            end
            if entry.timeFontString then
                entry.timeFontString:SetText("-")
                entry.timeFontString:Show()
            end
            entry.creationTimestamp = nil
            if entry.icon then entry.icon:Hide() end
        end
        
        -- Tooltip handlers are now dynamic and don't need updating after data movement
    end
end

-- Helper to reflow visible placeholders top-to-bottom
function DifficultBulletinBoardMessageProcessor.ReflowTopicEntries(entries)
    local ROW_HEIGHT = 18
    -- Determine the top Y based on first placeholder
    local initialY = entries[1] and entries[1].baseY or 0
    local baseX = entries[1] and entries[1].baseX or 0
    local cf = entries[1] and entries[1].contentFrame
    for i, entry in ipairs(entries) do
        if entry.creationTimestamp and entry.nameButton and cf then
            -- Reposition row using common initialY
            entry.nameButton:ClearAllPoints()
            entry.nameButton:SetPoint("TOPLEFT", cf, "TOPLEFT", baseX, initialY - (i-1)*ROW_HEIGHT)
            -- Reposition icon alongside
            if entry.icon then
                entry.icon:ClearAllPoints()
                -- Anchor icon to the left of the name button for consistent alignment
                entry.icon:SetPoint("RIGHT", entry.nameButton, "LEFT", 3, 0)
                entry.icon:Show()
            end
            -- Show text columns
            if entry.messageFontString then entry.messageFontString:Show() end
            if entry.timeFontString then entry.timeFontString:Show() end
            entry.nameButton:Show()
        else
            -- Hide unused rows
            if entry.nameButton then entry.nameButton:Hide() end
            if entry.icon then entry.icon:Hide() end
            if entry.messageFontString then entry.messageFontString:Hide() end
            if entry.timeFontString then entry.timeFontString:Hide() end
        end
    end
end

-- Modified to also update times in the Groups Logs tab
function DifficultBulletinBoardMessageProcessor.UpdateElapsedTimes()
    for topicName, entries in pairs(groupTopicPlaceholders) do
        for _, entry in ipairs(entries) do
            if entry and entry.timeFontString and entry.creationTimestamp then
                local currentTimeStr = date("%H:%M:%S")
                local ageSeconds = timeToSeconds(currentTimeStr) - timeToSeconds(entry.creationTimestamp)
                if ageSeconds < 0 then ageSeconds = ageSeconds + 86400 end
                local expirationTime = tonumber(DifficultBulletinBoardVars.messageExpirationTime)
                if expirationTime and expirationTime > 0 and ageSeconds >= expirationTime then
                    entry.nameButton:SetText("-")
                    entry.messageFontString:SetText("-")
                    entry.timeFontString:SetText("-")
                    entry.creationTimestamp = nil
                    if entry.icon then entry.icon:SetTexture(nil) end
                else
                    local delta = calculateDelta(entry.creationTimestamp, currentTimeStr)
                    entry.timeFontString:SetText(delta)
                end
            end
        end
    end
    
    -- Update and expire Groups Logs times
    if groupsLogsPlaceholders["Group Logs"] then
        for _, entry in ipairs(groupsLogsPlaceholders["Group Logs"]) do
            if entry and entry.timeFontString and entry.creationTimestamp then
                local currentTimeStr = date("%H:%M:%S")
                local ageSeconds = timeToSeconds(currentTimeStr) - timeToSeconds(entry.creationTimestamp)
                if ageSeconds < 0 then ageSeconds = ageSeconds + 86400 end
                local expirationTime = tonumber(DifficultBulletinBoardVars.messageExpirationTime)
                if expirationTime and expirationTime > 0 and ageSeconds >= expirationTime then
                    entry.nameButton:SetText("-")
                    entry.messageFontString:SetText("-")
                    entry.timeFontString:SetText("-")
                    entry.creationTimestamp = nil
                    if entry.icon then entry.icon:SetTexture(nil) end
                else
                    local delta = calculateDelta(entry.creationTimestamp, currentTimeStr)
                    entry.timeFontString:SetText(delta)
                end
            end
        end
    end

    for topicName, entries in pairs(professionTopicPlaceholders) do
        for _, entry in ipairs(entries) do
            if entry and entry.timeFontString and entry.creationTimestamp then
                local currentTimeStr = date("%H:%M:%S")
                local ageSeconds = timeToSeconds(currentTimeStr) - timeToSeconds(entry.creationTimestamp)
                if ageSeconds < 0 then ageSeconds = ageSeconds + 86400 end
                local expirationTime = tonumber(DifficultBulletinBoardVars.messageExpirationTime)
                if expirationTime and expirationTime > 0 and ageSeconds >= expirationTime then
                    entry.nameButton:SetText("-")
                    entry.messageFontString:SetText("-")
                    entry.timeFontString:SetText("-")
                    entry.creationTimestamp = nil
                    if entry.icon then entry.icon:SetTexture(nil) end
                else
                    local delta = calculateDelta(entry.creationTimestamp, currentTimeStr)
                    entry.timeFontString:SetText(delta)
                end
            end
        end
    end

    for topicName, entries in pairs(hardcoreTopicPlaceholders) do
        for _, entry in ipairs(entries) do
            if entry and entry.timeFontString and entry.creationTimestamp then
                local currentTimeStr = date("%H:%M:%S")
                local ageSeconds = timeToSeconds(currentTimeStr) - timeToSeconds(entry.creationTimestamp)
                if ageSeconds < 0 then ageSeconds = ageSeconds + 86400 end
                local expirationTime = tonumber(DifficultBulletinBoardVars.messageExpirationTime)
                if expirationTime and expirationTime > 0 and ageSeconds >= expirationTime then
                    entry.nameButton:SetText("-")
                    entry.messageFontString:SetText("-")
                    entry.timeFontString:SetText("-")
                    entry.creationTimestamp = nil
                    if entry.icon then entry.icon:SetTexture(nil) end
                else
                    local delta = calculateDelta(entry.creationTimestamp, currentTimeStr)
                    entry.timeFontString:SetText(delta)
                end
            end
        end
    end
end

-- Function to expire messages older than specified seconds
function DifficultBulletinBoardMessageProcessor.ExpireMessages(seconds)
    local secs = tonumber(seconds)
    if not secs then return end
    local currentTimeStr = date("%H:%M:%S")
    -- Hide/show entries
    local function expireEntry(entry)
        if entry and entry.creationTimestamp then
            local age = timeToSeconds(currentTimeStr) - timeToSeconds(entry.creationTimestamp)
            if age < 0 then age = age + 86400 end
            if age >= secs then
                -- Prevent reprocessing
                entry.creationTimestamp = nil
                if entry.nameButton then entry.nameButton:Hide() end
                entry.messageFontString:Hide()
                entry.timeFontString:Hide()
                if entry.icon then entry.icon:Hide() end
            else
                if entry.nameButton then entry.nameButton:Show() end
                entry.messageFontString:Show()
                entry.timeFontString:Show()
                if entry.icon then entry.icon:Show() end
            end
        end
    end
    -- Process all tabs
    for _, entries in pairs(groupTopicPlaceholders) do
        for _, entry in ipairs(entries) do expireEntry(entry) end
    end
    if groupsLogsPlaceholders["Group Logs"] then
        for _, entry in ipairs(groupsLogsPlaceholders["Group Logs"]) do expireEntry(entry) end
    end
    for _, entries in pairs(professionTopicPlaceholders) do
        for _, entry in ipairs(entries) do expireEntry(entry) end
    end
    for _, entries in pairs(hardcoreTopicPlaceholders) do
        for _, entry in ipairs(entries) do expireEntry(entry) end
    end


    -- Repack and reflow all placeholder lists to collapse gaps and reposition rows
    if RepackEntries and ReflowTopicEntries then
        for _, entries in pairs(groupTopicPlaceholders) do
            RepackEntries(entries)
            ReflowTopicEntries(entries)
        end
        if groupsLogsPlaceholders["Group Logs"] then
            RepackEntries(groupsLogsPlaceholders["Group Logs"])
            ReflowTopicEntries(groupsLogsPlaceholders["Group Logs"])
        end
        for _, entries in pairs(professionTopicPlaceholders) do
            RepackEntries(entries)
            ReflowTopicEntries(entries)
        end
        for _, entries in pairs(hardcoreTopicPlaceholders) do
            RepackEntries(entries)
            ReflowTopicEntries(entries)
        end
    end
end
