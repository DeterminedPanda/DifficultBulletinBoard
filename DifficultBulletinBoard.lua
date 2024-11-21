local defaultTopics = DifficultBulletinBoard.defaultTopics
local defaultNumberOfPlaceholders = DifficultBulletinBoard.defaultNumberOfPlaceholders
local allTopics = {}
local mainFrame = DifficultBulletinBoardMainFrame
local optionFrame = DifficultBulletinBoardOptionFrame
local string_gfind = string.gmatch or string.gfind
local numberOfPlaceholders = 3
local topicPlaceholders = {}
local activeChannels = {}

local function print(string)
    DEFAULT_CHAT_FRAME:AddMessage(string)
end

local function splitIntoLowerWords(input)
    local tags = {}

    -- iterate over words (separated by spaces) and insert them into the tags table
    for tag in string_gfind(input, "%S+") do
        table.insert(tags, string.lower(tag))
    end

    return tags
end


local function getChannelNames()
    local channelNames = {}
    local channelData = { GetChannelList() }

    for i = 1, table.getn(channelData), 2 do
        local channelId = channelData[i]
        local channelName = channelData[i + 1]
        local entry = {}
        entry.id = channelId
        entry.name = channelName
        entry.selected = true

        print("Name: " .. entry.name .. " Id: " .. entry.id)

        table.insert(channelNames, entry)
    end

    return channelNames
end


local function addScrollFrameToOptionFrame()
    local parentFrame = optionFrame

    local scrollFrame = CreateFrame("ScrollFrame", "DifficultBulletinBoardOptionFrame_ScrollFrame", parentFrame,
        "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", 5, -38)
    scrollFrame:SetWidth(469)
    scrollFrame:SetHeight(590)

    local scrollChild = CreateFrame("Frame", "DifficultBulletinBoardOptionFrame_ScrollFrame_ScrollChild", scrollFrame)
    scrollChild:SetWidth(480)
    scrollChild:SetHeight(1300)
    scrollFrame:SetScrollChild(scrollChild)
end


local function addPlaceholderOptionToOptionFrame()
    local parentFrame = DifficultBulletinBoardOptionFrame_ScrollFrame_ScrollChild

    -- Create the first FontString (label) above the scroll frame
    local scrollLabel = parentFrame:CreateFontString("DifficultBulletinBoard_Option_PlaceholderOption_FontString",
        "OVERLAY", "GameFontHighlight")
    scrollLabel:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", 15, -10) -- Position at the top of the parent frame
    scrollLabel:SetText("Number of Placeholders per Topic:")
    scrollLabel:SetFont("Fonts\\FRIZQT__.TTF", 14)

    local placeholderOptionTextBox = CreateFrame("EditBox", "DifficultBulletinBoard_Option_PlaceholderOption_TextBox",
        parentFrame, "InputBoxTemplate")
    placeholderOptionTextBox:SetPoint("RIGHT", scrollLabel, "RIGHT", 30, -0)
    placeholderOptionTextBox:SetWidth(20)
    placeholderOptionTextBox:SetHeight(20)
    placeholderOptionTextBox:SetText(numberOfPlaceholders)
    placeholderOptionTextBox:EnableMouse(true)
    placeholderOptionTextBox:SetAutoFocus(false)
end

local lastCheckBox = nil
local function addChannelOptionToOptionFrame()
    local parentFrame = DifficultBulletinBoardOptionFrame_ScrollFrame_ScrollChild
    local placeholderOptionFontString = DifficultBulletinBoard_Option_PlaceholderOption_FontString
    local yOffset = -30 -- Starting vertical offset for the first checkbox

    local scrollLabel = parentFrame:CreateFontString("DifficultBulletinBoard_Option_ChannelOption_FontString",
        "OVERLAY", "GameFontHighlight")
    scrollLabel:SetPoint("LEFT", placeholderOptionFontString, "LEFT", 0, -50) -- Position at the top of the parent frame
    scrollLabel:SetText("Select the Channels you want to observe:")
    scrollLabel:SetFont("Fonts\\FRIZQT__.TTF", 14)

    for _, channel in ipairs(activeChannels) do
        local checkbox = CreateFrame("CheckButton", "$parent_" .. channel.name .. "_Checkbox", parentFrame,
            "UICheckButtonTemplate")
        checkbox:SetPoint("LEFT", scrollLabel, "LEFT", 0, yOffset)
        checkbox:SetWidth(25)
        checkbox:SetHeight(25)
        checkbox:SetChecked(channel.selected)
        local currentChannel = channel
        checkbox:SetScript("OnClick", function()
            currentChannel.selected = checkbox:GetChecked()
        end)

        local topicLabel = parentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        topicLabel:SetPoint("LEFT", checkbox, "RIGHT", 0, 0)
        topicLabel:SetText(channel.name)
        topicLabel:SetFont("Fonts\\FRIZQT__.TTF", 12)
        topicLabel:SetJustifyH("LEFT")
        topicLabel:SetWidth(175)

        -- save this so it can be used as a reference point in the following option
        lastCheckBox = checkbox;

        yOffset = yOffset - 30 -- Adjust the vertical offset for the next row
    end
end

local tempTags = {}
local function addTopicOptionToOptionFrame()
    local scrollChild = DifficultBulletinBoardOptionFrame_ScrollFrame_ScrollChild
    local yOffset = -30 -- Starting vertical offset for the first checkbox

    local scrollLabel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    scrollLabel:SetPoint("LEFT", lastCheckBox, "LEFT", 0, -50)
    scrollLabel:SetText("Select the Topics you want to observe:")
    scrollLabel:SetFont("Fonts\\FRIZQT__.TTF", 14)

    for _, topic in ipairs(allTopics) do
        local checkbox = CreateFrame("CheckButton", "$parent_" .. topic.name .. "_Checkbox", scrollChild,
            "UICheckButtonTemplate")
        checkbox:SetPoint("LEFT", scrollLabel, "LEFT", 0, yOffset)
        checkbox:SetWidth(25)
        checkbox:SetHeight(25)
        checkbox:SetChecked(topic.selected)

        local currentTopic = topic
        checkbox:SetScript("OnClick", function()
            currentTopic.selected = checkbox:GetChecked()
        end)

        -- Add a label next to the checkbox displaying the topic
        local topicLabel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        topicLabel:SetPoint("LEFT", checkbox, "RIGHT", 0, 0)
        topicLabel:SetText(topic.name)
        topicLabel:SetFont("Fonts\\FRIZQT__.TTF", 12)
        topicLabel:SetJustifyH("LEFT")
        topicLabel:SetWidth(175)

        -- Add a text box next to the topic label for tags input
        local tagsTextBox = CreateFrame("EditBox", "$parent_" .. topic.name .. "_TagsTextBox", scrollChild,
            "InputBoxTemplate")
        tagsTextBox:SetPoint("LEFT", topicLabel, "RIGHT", 0, 0)
        tagsTextBox:SetWidth(230)
        tagsTextBox:SetHeight(20)
        tagsTextBox:SetText(table.concat(topic.tags, " "))
        tagsTextBox:EnableMouse(true)
        tagsTextBox:SetAutoFocus(false)

        local topicName = topic.name --save a reference for the onTextChanged event
        tagsTextBox:SetScript("OnTextChanged", function()
            local enteredText = this:GetText()
            tempTags[topicName] = splitIntoLowerWords(enteredText)
        end)

        yOffset = yOffset - 30 -- Adjust the vertical offset for the next row
    end
end

local function initializeOptionFrame()
    addScrollFrameToOptionFrame()
    addPlaceholderOptionToOptionFrame()
    addChannelOptionToOptionFrame()
    addTopicOptionToOptionFrame()
end

local isOptionFrameInitialized = false
function DifficultBulletinBoard_ToggleOptionFrame()
    if not isOptionFrameInitialized then
        print("test")
        initializeOptionFrame()
        isOptionFrameInitialized = true
    end

    if optionFrame then
        if optionFrame:IsShown() then
            print("Hiding frame")
            optionFrame:Hide()
        else
            print("Showing frame")
            optionFrame:Show()
            mainFrame:Hide()
        end
    else
        print("Option frame not found")
    end
end

function DifficultBulletinBoard_ToggleMainFrame()
    if mainFrame then
        if mainFrame:IsShown() then
            print("Hiding frame")
            mainFrame:Hide()
        else
            print("Showing frame")
            mainFrame:Show()
            optionFrame:Hide()
        end
    else
        print("Main frame not found")
    end
end

function DifficultBulletinBoard_DragMinimapStart()
    local button = DifficultBulletinBoard_MinimapButtonFrame

    if (IsShiftKeyDown()) and button then
        button:StartMoving()
    end
end

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

local function addScrollFrameToMainFrame()
    local parentFrame = mainFrame

    local scrollFrame = CreateFrame("ScrollFrame", "DifficultBulletinBoardMainFrame_ScrollFrame", parentFrame,
        "UIPanelScrollFrameTemplate")
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", 0, -38)
    scrollFrame:SetPoint("BOTTOMRIGHT", parentFrame, "BOTTOMRIGHT", -26, 10)

    local scrollChild = CreateFrame("Frame", "DifficultBulletinBoardMainFrame_ScrollFrame_ScrollChild", scrollFrame)
    scrollChild:SetHeight(2000)
    scrollChild:SetWidth(980)

    scrollFrame:SetScrollChild(scrollChild)
end


-- function to create the placeholders and font strings for a topic
local function addTopicsToMainFrame()
    -- initial Y-offset for the first header and placeholder
    local yOffset = 0

    local contentFrame = DifficultBulletinBoardMainFrame_ScrollFrame_ScrollChild

    for _, topic in ipairs(allTopics) do
        if topic.selected then
            local header = contentFrame:CreateFontString("$parent_" .. topic.name .. "Header", "OVERLAY",
                "GameFontNormal")
            header:SetText(topic.name)
            header:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 10, yOffset)
            header:SetWidth(200)
            header:SetJustifyH("LEFT")
            header:SetTextColor(1, 1, 0)
            header:SetFont("Fonts\\FRIZQT__.TTF", 12)

            -- Store the header Y offset for the current topic
            local topicYOffset = yOffset - 20 -- space between header and first placeholder
            yOffset = topicYOffset - 110      -- space between headers

            topicPlaceholders[topic.name] = topicPlaceholders[topic.name] or { FontStrings = {} }

            for i = 1, numberOfPlaceholders do
                -- create Name column as a button
                local nameButton = CreateFrame("Button", "$parent_" .. topic.name .. "Placeholder" .. i .. "_Name",
                    contentFrame, nil)
                nameButton:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 10, topicYOffset)
                nameButton:SetWidth(150)
                nameButton:SetHeight(14)

                -- Set the text of the button
                local buttonText = nameButton:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                buttonText:SetText("-")
                buttonText:SetPoint("LEFT", nameButton, "LEFT", 5, 0)
                buttonText:SetFont("Fonts\\FRIZQT__.TTF", 12)
                buttonText:SetTextColor(1, 1, 1)
                nameButton:SetFontString(buttonText)

                -- Set scripts for hover behavior
                nameButton:SetScript("OnEnter", function()
                    buttonText:SetFont("Fonts\\FRIZQT__.TTF", 12)
                    buttonText:SetTextColor(1, 1, 0)
                end)

                nameButton:SetScript("OnLeave", function()
                    buttonText:SetFont("Fonts\\FRIZQT__.TTF", 12)
                    buttonText:SetTextColor(1, 1, 1)
                end)

                nameButton:SetScript("OnClick", function()
                    print("Clicked on: " .. nameButton:GetText())
                    local pressedButton = arg1
                    local targetName = nameButton:GetText()
                    print(pressedButton)

                    -- dont do anything when its a placeholder
                    if targetName == "-" then
                        return
                    end

                    if pressedButton == "LeftButton" then
                        if IsShiftKeyDown() then
                            print("who")
                            SendWho(targetName)
                        else
                            print("whisp")
                            ChatFrame_OpenChat("/w " .. targetName)
                        end
                    end
                end)

                --OnClick doesnt support right clicking... so lets just check OnMouseDown instead
                nameButton:SetScript("OnMouseDown", function()
                    local pressedButton = arg1
                    local targetName = nameButton:GetText()

                    -- dont do anything when its a placeholder
                    if targetName == "-" then
                        return
                    end

                    if pressedButton == "RightButton" then
                        ChatFrame_OpenChat("/invite " .. targetName)
                    end
                end)

                -- create Message column
                local messageColumn = contentFrame:CreateFontString(
                    "$parent_" .. topic.name .. "Placeholder" .. i .. "_Message", "OVERLAY", "GameFontNormal")
                messageColumn:SetText("-")
                messageColumn:SetPoint("TOPLEFT", nameButton, "TOPRIGHT", 50, 0)
                messageColumn:SetWidth(650)
                messageColumn:SetHeight(10)
                messageColumn:SetJustifyH("LEFT")
                messageColumn:SetTextColor(1, 1, 1)
                messageColumn:SetFont("Fonts\\FRIZQT__.TTF", 12)

                -- create Time column
                local timeColumn = contentFrame:CreateFontString(
                    "$parent_" .. topic.name .. "Placeholder" .. i .. "_Time", "OVERLAY", "GameFontNormal")
                timeColumn:SetText("-")
                timeColumn:SetPoint("TOPLEFT", messageColumn, "TOPRIGHT", 20, 0)
                timeColumn:SetWidth(100)
                timeColumn:SetJustifyH("LEFT")
                timeColumn:SetTextColor(1, 1, 1)
                timeColumn:SetFont("Fonts\\FRIZQT__.TTF", 12)

                table.insert(topicPlaceholders[topic.name].FontStrings, { nameButton, messageColumn, timeColumn })

                -- Increment the Y-offset for the next placeholder
                topicYOffset = topicYOffset - 18 -- space between placeholders
            end

            -- After the placeholders, adjust the main yOffset for the next topic
            yOffset = topicYOffset - 10 -- space between topics
        end
    end
end

-- Function to update the first placeholder for a given topic with new name, message, and time and shift other placeholders down
local function UpdateFirstPlaceholderAndShiftDown(topic, name, message)
    local topicData = topicPlaceholders[topic]
    if not topicData or not topicData.FontStrings or not topicData.FontStrings[1] then
        print("No placeholders found for topic: " .. topic)
        return
    end

    local currentTime = date("%H:%M:%S")

    local index = 0
    for i, _ in ipairs(topicData.FontStrings) do
        index = i
    end

    for i = index, 2, -1 do
        -- Copy the data from the previous placeholder to the current one
        local currentFontString = topicData.FontStrings[i]
        local previousFontString = topicData.FontStrings[i - 1]

        -- Update the current placeholder with the previous placeholder's data
        currentFontString[1]:SetText(previousFontString[1]:GetText())
        currentFontString[2]:SetText(previousFontString[2]:GetText())
        currentFontString[3]:SetText(previousFontString[3]:GetText())
    end

    -- Update the first placeholder with the new data
    local firstFontString = topicData.FontStrings[1]
    firstFontString[1]:SetText(name or "No Name")
    firstFontString[2]:SetText(message or "No Message")
    firstFontString[3]:SetText(currentTime or "No Time")
end

-- Updates the specified placeholder for a topic with new name, message, and timestamp,
-- then moves the updated entry to the top of the list, shifting other entries down.
local function UpdateTopicPlaceholderWithShift(topic, name, message, index)
    local topicData = topicPlaceholders[topic]
    local FontStringsList = {}

    if not topicData or not topicData.FontStrings then
        print("No FontStrings found for topic:", topic)
        return nil
    end

    for i, row in ipairs(topicData.FontStrings) do
        local entryList = {}

        for j, fontString in ipairs(row) do
            local text = fontString:GetText()
            table.insert(entryList, text)
        end

        table.insert(FontStringsList, entryList)
    end

    local currentTime = date("%H:%M:%S")
    FontStringsList[index][1] = name
    FontStringsList[index][2] = message
    FontStringsList[index][3] = currentTime

    local tempFontStringsList = table.remove(FontStringsList, index)
    table.insert(FontStringsList, 1, tempFontStringsList)

    for i = 1, numberOfPlaceholders, 1 do
        local currentFontString = topicData.FontStrings[i]

        currentFontString[1]:SetText(FontStringsList[i][1])
        currentFontString[2]:SetText(FontStringsList[i][2])
        currentFontString[3]:SetText(FontStringsList[i][3])
    end
end

SLASH_DIFFICULTBB1 = "/dbb"
SlashCmdList["DIFFICULTBB"] = function()
    DifficultBulletinBoard_ToggleMainFrame()
end


local function loadSavedVariables()
    DifficultBulletinBoardSavedVariables = DifficultBulletinBoardSavedVariables or {}

    if DifficultBulletinBoardSavedVariables.activeChannels then
        activeChannels = DifficultBulletinBoardSavedVariables.activeChannels
    else
        activeChannels = getChannelNames()
    end

    if DifficultBulletinBoardSavedVariables.numberOfPlaceholders and DifficultBulletinBoardSavedVariables.numberOfPlaceholders ~= "" then
        numberOfPlaceholders = DifficultBulletinBoardSavedVariables.numberOfPlaceholders
    else
        numberOfPlaceholders = DifficultBulletinBoard.defaultNumberOfPlaceholders
        DifficultBulletinBoardSavedVariables.numberOfPlaceholders = numberOfPlaceholders
    end

    if DifficultBulletinBoardSavedVariables.activeTopics then
        allTopics = DifficultBulletinBoardSavedVariables.activeTopics
    else
        allTopics = DifficultBulletinBoard.deepCopy(DifficultBulletinBoard.defaultTopics)
        DifficultBulletinBoardSavedVariables.activeTopics = allTopics
    end
end


local function initializeAddon(event, arg1)
    if event == "ADDON_LOADED" and arg1 == "DifficultBulletinBoard" then
        loadSavedVariables()

        --create main frame
        addScrollFrameToMainFrame()
        addTopicsToMainFrame()
    end
end

local function overwriteTagsForAllTopics()
    for _, topic in ipairs(allTopics) do
        if tempTags[topic.name] then
            local newTags = tempTags[topic.name]
            topic.tags = newTags
            print("Tags for topic '" .. topic.name .. "' have been updated:")
            for _, tag in ipairs(newTags) do
                print("- " .. tag)
            end
        else
            print("No tags found for topic '" .. topic.name .. "' in tempTags.")
        end
    end
end

function DifficultBulletinBoard_ResetVariablesAndReload()
    DifficultBulletinBoardSavedVariables.numberOfPlaceholders = defaultNumberOfPlaceholders
    DifficultBulletinBoardSavedVariables.activeTopics = defaultTopics
    DifficultBulletinBoardSavedVariables.activeChannels = getChannelNames()
    ReloadUI();
end

function DifficultBulletinBoard_SaveVariablesAndReload()
    DifficultBulletinBoardSavedVariables.numberOfPlaceholders = DifficultBulletinBoard_Option_PlaceholderOption_TextBox
        :GetText()
    overwriteTagsForAllTopics();
    ReloadUI();
end

local function topicPlaceholdersContainsCharacterName(topicName, characterName)
    local topicData = topicPlaceholders[topicName]
    if not topicData or not topicData.FontStrings then
        print("Nothing in here yet")
        return false, nil
    end

    for index, row in ipairs(topicData.FontStrings) do
        local nameColumn = row[1]

        if nameColumn:GetText() == characterName then
            print("Already in there!")
            return true, index
        end
    end

    return false, nil
end

local function OnChatMessage(event, arg1, arg2, arg9)
    local chatMessage = arg1
    local characterName = arg2
    local channelName = arg9

    local s = string.lower(chatMessage)

    local words = splitIntoLowerWords(s)

    for _, topic in ipairs(allTopics) do
        local matchFound = false -- Flag to control breaking out of nested loops

        for _, tag in ipairs(topic.tags) do
            for _, word in ipairs(words) do
                if word == string.lower(tag) then
                    print("Tag '" .. tag .. "' matches Topic: " .. topic.name)
                    local found, index = topicPlaceholdersContainsCharacterName(topic.name, characterName)
                    if found then
                        print("An entry for that character already exists at " .. index)
                        UpdateTopicPlaceholderWithShift(topic.name, characterName, chatMessage, index)
                    else
                        print("No entry for that character exists. Creating one...")
                        UpdateFirstPlaceholderAndShiftDown(topic.name, characterName, chatMessage)
                    end

                    matchFound = true -- Set the flag to true to break out of loops
                    break
                end
            end

            if matchFound then
                break
            end
        end
    end
end

function handleEvent()
    if event == "ADDON_LOADED" then
        initializeAddon(event, arg1);
    end

    if event == "CHAT_MSG_CHANNEL" then
        OnChatMessage(event, arg1, arg2, arg9)
    end
end

mainFrame:RegisterEvent("ADDON_LOADED")
mainFrame:RegisterEvent("CHAT_MSG_CHANNEL")
mainFrame:SetScript("OnEvent", handleEvent)
