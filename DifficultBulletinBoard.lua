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

-- Fallback for string.match in Lua 5.0 (WoW Vanilla)
if not string.match then
    function string.match(s, pattern)
        local _, _, c1, c2 = string.find(s, pattern)
        return c1, c2
    end
end

local mainFrame = DifficultBulletinBoardMainFrame
local optionFrame = DifficultBulletinBoardOptionFrame
local blacklistFrame = DifficultBulletinBoardBlacklistFrame

-- Flag to track if the last processed message was matched
local lastMessageWasMatched = false

-- Track previous messages to handle filtering
local previousMessages = {}



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
                PlaySound("igSpellBookClose");
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
                PlaySound("igSpellBookOpen");
            end
            optionFrame:Show()
            mainFrame:Hide()
        end
            end
end

-- Toggle the main bulletin board frame
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
            -- Recalculate scroll ranges before showing frame to avoid flicker
            if DifficultBulletinBoardMainFrame.RefreshAllScrollRanges then
                DifficultBulletinBoardMainFrame.RefreshAllScrollRanges()
            end
            mainFrame:Show()
            optionFrame:Hide()
            -- Also hide the blacklist frame when opening the main frame
            if blacklistFrame and blacklistFrame:IsShown() then
                blacklistFrame:Hide()
            end
        end
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
SlashCmdList["DIFFICULTBB"] = function(msg)
    -- Parse the first word as command and the rest as argument
    local command, arg = string.match(msg, "^(%S*)%s*(.*)$")
    if command == "expire" then
        local secs = tonumber(arg)
        if secs then
            -- Call expiration function on main frame
            DifficultBulletinBoard.ExpireMessages(secs)
            -- Remember manual expiration setting to reapply on new messages
            DifficultBulletinBoardVars.manualExpireSeconds = secs
            DEFAULT_CHAT_FRAME:AddMessage("[DBB] Expired messages older than " .. secs .. " seconds.")
        else
            DEFAULT_CHAT_FRAME:AddMessage("[DBB] Usage: /dbb expire <seconds>")
        end
    else
        -- Toggle main bulletin board frame
        DifficultBulletinBoard_ToggleMainFrame()
    end
end



-- Initialize addon when loaded
local function initializeAddon(event, arg1)
    if event == "ADDON_LOADED" and arg1 == "DifficultBulletinBoard" then
        DifficultBulletinBoardVars.LoadSavedVariables()

        -- Create option frame first
        if DifficultBulletinBoardOptionFrame and DifficultBulletinBoardOptionFrame.InitializeOptionFrame then
            DifficultBulletinBoardOptionFrame.InitializeOptionFrame()
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[DBB Error]|r Failed to initialize option frame - module not loaded properly.")
        end

        -- Create main frame afterwards
        if DifficultBulletinBoardMainFrame and DifficultBulletinBoardMainFrame.InitializeMainFrame then
            DifficultBulletinBoardMainFrame.InitializeMainFrame()
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[DBB Error]|r Failed to initialize main frame - module not loaded properly.")
        end
        
        -- Install ChatFrame_OnEvent hooks for all chat frames
        if not DifficultBulletinBoard.hookInstalled then
            DifficultBulletinBoard.originalChatFrameHandlers = {}
            
            -- Hook all existing and active chat frames using GetChatWindowInfo
            for i = 1, NUM_CHAT_WINDOWS or 7 do
                local chatFrame = getglobal("ChatFrame" .. i)
                if chatFrame then
                    -- Check if this chat window is actually shown and configured
                    local name, fontSize, r, g, b, alpha, shown, locked, docked, uninteractable = GetChatWindowInfo(i)
                    if shown and shown == 1 then
                        -- Store the original OnEvent handler for this specific chat frame
                        DifficultBulletinBoard.originalChatFrameHandlers[i] = chatFrame:GetScript("OnEvent")
                        
                        -- Set our custom handler for this chat frame
                        chatFrame:SetScript("OnEvent", function()
                            DifficultBulletinBoard.hookedChatFrameOnEvent(event, chatFrame)
                        end)
                        
                        -- Chat filtering hooked for ChatFrame
                    end
                end
            end
            
            -- Also keep the global hook as fallback for any frames that might use it
            DifficultBulletinBoard.originalChatFrameOnEvent = ChatFrame_OnEvent
            ChatFrame_OnEvent = DifficultBulletinBoard.hookedChatFrameOnEvent
            
            DifficultBulletinBoard.hookInstalled = true
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
    
    -- Define word boundary characters (space + specified punctuation)
    local boundaries = " .,!?;:\"'%-()%[%]<>"
    
    -- Find all occurrences of the keyword in the message
    local startPos = 1
    while true do
        local foundStart, foundEnd = string.find(lowerMessage, lowerKeyword, startPos, true)
        if not foundStart then
            break
        end
        
        -- Check character before the keyword (or start of string)
        local charBefore = ""
        if foundStart > 1 then
            charBefore = string.sub(lowerMessage, foundStart - 1, foundStart - 1)
        end
        
        -- Check character after the keyword (or end of string)
        local charAfter = ""
        if foundEnd < string.len(lowerMessage) then
            charAfter = string.sub(lowerMessage, foundEnd + 1, foundEnd + 1)
        end
        
        -- Check if both boundaries are valid (space, punctuation, or string boundary)
        local validBefore = (foundStart == 1) or (string.find(boundaries, charBefore, 1, true) ~= nil)
        local validAfter = (foundEnd == string.len(lowerMessage)) or (string.find(boundaries, charAfter, 1, true) ~= nil)
        
        if validBefore and validAfter then
            return true
        end
        
        -- Continue searching from the next position
        startPos = foundStart + 1
    end
    
    -- No valid word boundary match found
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

-- Track messages processed to prevent duplicate processing within a short timeframe
local recentlyProcessedMessages = {}
local DUPLICATE_PREVENTION_WINDOW = 0.1 -- 100ms window

-- Helper function to call the appropriate original chat frame handler
local function callOriginalChatFrameHandler(event, chatFrame)
    if chatFrame and DifficultBulletinBoard.originalChatFrameHandlers then
        -- Find which chat frame this is and call its original handler
        for i = 1, 7 do
            if getglobal("ChatFrame" .. i) == chatFrame and DifficultBulletinBoard.originalChatFrameHandlers[i] then
                DifficultBulletinBoard.originalChatFrameHandlers[i]()
                return
            end
        end
    end
    
    -- Fallback to global handler
    DifficultBulletinBoard.originalChatFrameOnEvent(event)
end

-- Replacement for ChatFrame_OnEvent that implements message filtering
-- Now supports both global calls and per-frame calls
function DifficultBulletinBoard.hookedChatFrameOnEvent(event, chatFrame)
    local name = arg2 or "empty_name"
    local message = arg1 or "empty_message"
    
    -- Initialize shouldFilter flag for this message
    shouldFilter = false
    
    -- Create a unique identifier for this exact event call
    local eventKey = event .. ":" .. name .. ":" .. message .. ":" .. tostring(arg9)
    local currentTime = GetTime()
    
    -- Check if we've processed this exact event very recently
    if recentlyProcessedMessages[eventKey] and 
       recentlyProcessedMessages[eventKey] + DUPLICATE_PREVENTION_WINDOW > currentTime then
        -- For duplicate prevention, check if the message was previously filtered
        local messageKey = name .. ":" .. message
        local messageSpecificKey = name .. ":" .. message
        
        -- Check for blacklisted messages
        if lastFilteredMessages[messageKey] and 
           lastFilteredMessages[messageKey] + FILTER_LOG_TIMEOUT > currentTime then
            -- Message was recently filtered by blacklist, apply the same filtering decision
            if DifficultBulletinBoardVars.filterMatchedMessages == "true" then
                return -- Skip this duplicate message as it was filtered
            end
        end
        
        -- Check for addon-matched messages
        if previousMessages[messageSpecificKey] and 
           previousMessages[messageSpecificKey][3] == "matched" then
            -- Message was matched by addon filtering, apply the same filtering decision
            if DifficultBulletinBoardVars.filterMatchedMessages == "true" then
                return -- Skip this duplicate message as it was matched
            end
        end
        
        -- For non-filtered duplicates, call the original handler
        callOriginalChatFrameHandler(event, chatFrame)
        return -- Skip duplicate processing
    end
    
    -- Mark this event as processed
    recentlyProcessedMessages[eventKey] = currentTime
    
    -- Clean up old entries periodically
    if math.random(1, 100) == 1 then -- 1% chance to clean up
        local tempMessages = {}
        for key, timestamp in pairs(recentlyProcessedMessages) do
            if timestamp + DUPLICATE_PREVENTION_WINDOW > currentTime then
                tempMessages[key] = timestamp
            end
        end
        recentlyProcessedMessages = tempMessages
    end

    -- This caused the CHAT_MSG_SYSTEM eventhandler to not work. 
    -- CHAT_MSG_SYSTEM messages do not contain a name (arg2) and therefore never pass this check.
    --if not arg1 or not arg2 or arg2 == "" or arg2 == UnitName("player") or not arg9 then
    --    DifficultBulletinBoard.originalChatFrameOnEvent(event)
    --    return
    --end
    
    -- Create a unique identifier for this message
    local messageKey = name .. ":" .. message
    
    -- Check if we've recently logged this exact filtered message
    if lastFilteredMessages[messageKey] and lastFilteredMessages[messageKey] + FILTER_LOG_TIMEOUT > GetTime() then
        -- We've already logged this message recently, skip logging again
        if previousMessages[name] and previousMessages[name][3] then
            -- Only skip if filtering is enabled, otherwise let it through to chat
            if DifficultBulletinBoardVars.filterMatchedMessages == "true" then
                return -- Skip this message as it was marked for filtering
            end
        end
    end
    
    -- Check if message contains any blacklisted keywords
    if event == "CHAT_MSG_CHANNEL" and DifficultBulletinBoardSavedVariables.keywordBlacklist and 
       DifficultBulletinBoardSavedVariables.keywordBlacklist ~= "" then
        
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
            -- Set shouldFilter flag for this message
            shouldFilter = true
            
            -- Only log if we haven't logged this message recently
            if not lastFilteredMessages[messageKey] or lastFilteredMessages[messageKey] + FILTER_LOG_TIMEOUT <= GetTime() then
                lastFilteredMessages[messageKey] = GetTime()
            end
            
            -- Mark message as filtered in the previous messages tracker
            local messageSpecificKey = name .. ":" .. message
            local currentTime = GetTime()
            previousMessages[messageSpecificKey] = {message, currentTime, true}
            
            if previousMessages[name] then
                previousMessages[name][3] = true
            else
                previousMessages[name] = {message, GetTime(), true, arg9}
            end

            -- Skip both chat display and addon processing for blacklisted messages
            if DifficultBulletinBoardVars.filterMatchedMessages == "true" then
                return -- Skip this message entirely - no chat, no addon processing
            end
        end
    end
    
    -- Only process chat channel messages
    if event == "CHAT_MSG_CHANNEL" or event == "CHAT_MSG_GUILD" then
        
        -- arg9 for CHAT_MSG_GUILD is empty, so overwrite it here
        if(event == "CHAT_MSG_GUILD" ) then
            arg9 = "Guild"
        end

        -- Check if we've seen this specific message before (using message-specific key)
         local messageSpecificKey = name .. ":" .. message
         local currentTime = GetTime()
         

         
         if not previousMessages[messageSpecificKey] or 
            previousMessages[messageSpecificKey][2] + 60 < currentTime then
            
            -- Skip addon processing if message was blacklisted
            if shouldFilter then
                -- Store the blacklisted message but don't process it
                previousMessages[messageSpecificKey] = {message, currentTime, true}
                -- Call original handler for chat display (if filtering disabled)
                callOriginalChatFrameHandler(event, chatFrame)
                return
            end
            
            -- Process with our addon's message handler
            lastMessageWasMatched = DifficultBulletinBoard.OnChatMessage(message, name, arg9)
            
            -- Store/update the message with: [1]=content, [2]=timestamp, [3]=shouldFilter
            -- Always update timestamp when processing, whether new or repeat
            previousMessages[messageSpecificKey] = {message, currentTime, shouldFilter}

            
            -- If matched and filtering enabled, mark for filtering
            if lastMessageWasMatched and DifficultBulletinBoardVars.filterMatchedMessages == "true" then
                -- Only log if we haven't logged this message recently
                if not lastFilteredMessages[messageKey] or lastFilteredMessages[messageKey] + FILTER_LOG_TIMEOUT <= GetTime() then
                    lastFilteredMessages[messageKey] = GetTime()
                end
                -- Update the stored message to reflect that it was matched and filtered
                previousMessages[messageSpecificKey][3] = "matched"
                -- Only skip if filtering is enabled, otherwise let it through to chat
                if DifficultBulletinBoardVars.filterMatchedMessages == "true" then
                    return -- Skip this message entirely
                end
            end
        else
              -- This is a repeat message we've seen recently (within 60 seconds)
              local timeSince = currentTime - previousMessages[messageSpecificKey][2]
              local filterReason = previousMessages[messageSpecificKey][3]
              if filterReason == true then
                  -- It was blacklisted
                  if DifficultBulletinBoardVars.filterMatchedMessages == "true" then
                      return -- Skip this message
                  end
              elseif filterReason == "matched" then
                  -- It was matched by addon filtering
                  if DifficultBulletinBoardVars.filterMatchedMessages == "true" then
                      return -- Skip this message
                  end
              end
              -- Skip repeat messages within 60 seconds to prevent spam
              if DifficultBulletinBoardVars.filterMatchedMessages == "true" then
                  return
              end
        end
    end
    
    if event == "CHAT_MSG_SYSTEM" then
        lastMessageWasMatched = DifficultBulletinBoard.OnSystemMessage(message)
        
        if lastMessageWasMatched then
            -- Only log if we haven't logged this message recently
            if not lastFilteredMessages[messageKey] or lastFilteredMessages[messageKey] + FILTER_LOG_TIMEOUT <= GetTime() then
                lastFilteredMessages[messageKey] = GetTime()
            end
            -- Only skip if filtering is enabled, otherwise let it through to chat
            if DifficultBulletinBoardVars.filterMatchedMessages == "true" then
                return -- Skip this message
            end
        end
    end

    if event == "CHAT_MSG_HARDCORE" then
        lastMessageWasMatched = DifficultBulletinBoard.OnChatMessage(message, name, "HC")
        
        if lastMessageWasMatched then
            -- Only log if we haven't logged this message recently
            if not lastFilteredMessages[messageKey] or lastFilteredMessages[messageKey] + FILTER_LOG_TIMEOUT <= GetTime() then
                lastFilteredMessages[messageKey] = GetTime()
            end
            -- Only skip if filtering is enabled, otherwise let it through to chat
            if DifficultBulletinBoardVars.filterMatchedMessages == "true" then
                return -- Skip this message
            end
        end
    end
    
    -- Call the original handler for non-filtered messages
    callOriginalChatFrameHandler(event, chatFrame)
end

-- Function to re-hook chat frames when chat window configuration changes
local function rehookChatFrames()
    if not DifficultBulletinBoard.hookInstalled then
        return
    end
    
    -- Re-hook all existing and active chat frames using GetChatWindowInfo
    for i = 1, NUM_CHAT_WINDOWS or 7 do
        local chatFrame = getglobal("ChatFrame" .. i)
        if chatFrame then
            -- Check if this chat window is actually shown and configured
            local name, fontSize, r, g, b, alpha, shown, locked, docked, uninteractable = GetChatWindowInfo(i)
            if shown and shown == 1 then
                -- Only hook if we haven't already hooked this frame
                if not DifficultBulletinBoard.originalChatFrameHandlers[i] then
                    -- Store the original OnEvent handler for this specific chat frame
                    DifficultBulletinBoard.originalChatFrameHandlers[i] = chatFrame:GetScript("OnEvent")
                    
                    -- Set our custom handler for this chat frame
                    chatFrame:SetScript("OnEvent", function()
                        DifficultBulletinBoard.hookedChatFrameOnEvent(event, chatFrame)
                    end)
                    
                    -- Chat filtering hooked for new ChatFrame
                end
            elseif DifficultBulletinBoard.originalChatFrameHandlers[i] then
                -- If frame is no longer shown but we had it hooked, restore original handler
                chatFrame:SetScript("OnEvent", DifficultBulletinBoard.originalChatFrameHandlers[i])
                DifficultBulletinBoard.originalChatFrameHandlers[i] = nil
                -- Chat filtering unhooked for hidden ChatFrame
            end
        end
    end
end

-- Event handler for registered events
local function handleEvent()
    if event == "ADDON_LOADED" then 
        initializeAddon(event, arg1)
    elseif event == "UPDATE_CHAT_WINDOWS" then
        -- Re-hook chat frames when chat window configuration changes
        rehookChatFrames()
    end

    -- The message filtering is now handled by the hookedChatFrameOnEvent function
end

-- Initialize with the current server time
local lastUpdateTime = GetTime() 
local lastCleanupTime = GetTime()

-- OnUpdate handler for regular tasks
local function OnUpdate()
    local currentTime = GetTime()
    local deltaTime = currentTime - lastUpdateTime

    -- Process on-screen notification queue every frame for responsive display
    if DifficultBulletinBoardMessageProcessor and DifficultBulletinBoardMessageProcessor.ProcessOnScreenQueue then
        DifficultBulletinBoardMessageProcessor.ProcessOnScreenQueue()
    end

    -- Update only if at least 1 second has passed
    if deltaTime >= 1 then
        -- Update the lastUpdateTime
        lastUpdateTime = currentTime

        DifficultBulletinBoardMainFrame.UpdateServerTime()

        if DifficultBulletinBoardVars.timeFormat == "elapsed" then
            DifficultBulletinBoardMainFrame.UpdateElapsedTimes()
        end
        
        -- Auto-expiration of messages based on user setting (0 = disabled)
        local expireSecs = tonumber(DifficultBulletinBoardVars.messageExpirationTime)
        if expireSecs and expireSecs > 0 then
            DifficultBulletinBoard.ExpireMessages(expireSecs)
        end

        -- Clean up old message entries every 5 minutes
        if currentTime - lastCleanupTime > 300 then
            lastCleanupTime = currentTime
            local tempMessages = {}
            for messageKey, data in pairs(previousMessages) do
                if data[2] + 120 > GetTime() then
                    tempMessages[messageKey] = data
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

-- Store original toggle function
local originalToggleBlacklist = DifficultBulletinBoard_ToggleBlacklistFrame

-- Override blacklist toggle function with robust error handling
DifficultBulletinBoard_ToggleBlacklistFrame = function()
    -- Always hide the blacklist frame, never show it since we've removed the UI elements to open it
    if DifficultBulletinBoardBlacklistFrame and DifficultBulletinBoardBlacklistFrame:IsShown() then
        DifficultBulletinBoardBlacklistFrame:Hide()
    end
end

-- Start tracking frame movement
linkUpdateFrame:Show()

-- Register events and set up script handlers
mainFrame:RegisterEvent("ADDON_LOADED")
mainFrame:RegisterEvent("UPDATE_CHAT_WINDOWS")
mainFrame:RegisterEvent("CHAT_MSG_CHANNEL")
mainFrame:RegisterEvent("CHAT_MSG_HARDCORE")
mainFrame:RegisterEvent("CHAT_MSG_SYSTEM")
mainFrame:RegisterEvent("CHAT_MSG_GUILD")
mainFrame:SetScript("OnEvent", handleEvent)
mainFrame:SetScript("OnUpdate", OnUpdate)

--make frames closable by pressing ESC
UIPanelWindows["DifficultBulletinBoardMainFrame"] = {
  area = "center",
  pushable = 0,
  whileDead = true,
}

UIPanelWindows["DifficultBulletinBoardOptionFrame"] = {
  area = "center",
  pushable = 0,
  whileDead = true,
}

tinsert(UISpecialFrames, "DifficultBulletinBoardMainFrame")
tinsert(UISpecialFrames, "DifficultBulletinBoardOptionFrame")