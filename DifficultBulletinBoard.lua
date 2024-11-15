local defaultTopics = DifficultBulletinBoard.defaultTopics
local defaultNumberOfPlaceholders = DifficultBulletinBoard.defaultNumberOfPlaceholders
local allTopics = {}
local mainFrame = DifficultBulletinBoardMainFrame
local optionFrame = DifficultBulletinBoardOptionFrame
local string_gfind = string.gmatch or string.gfind

local numberOfPlaceholders = 3
local topicPlaceholders = {}

local function print(string)
    --DEFAULT_CHAT_FRAME:AddMessage(string)
end

local function splitIntoLowerWords(input)
    local tags = {}

    -- iterate over words (separated by spaces) and insert them into the tags table
    for tag in string_gfind(input, "%S+") do
        table.insert(tags, string.lower(tag))
    end

    return tags
end

function DifficultBulletinBoard_ToggleOptionFrame()
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


-- function to create the placeholders and font strings for a topic
local function createTopicList()
    -- initial Y-offset for the first header and placeholder
    local yOffset = 0

    local contentFrame = DifficultBulletinBoardMainFrame_ScrollChild_ContentFrame

    for _, topic in ipairs(allTopics) do

        if topic.selected then

            local header = contentFrame:CreateFontString("$parent_" .. topic.name .. "Header", "OVERLAY", "GameFontNormal")
            header:SetText(topic.name)
            header:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 10, yOffset)
            header:SetWidth(200)
            header:SetJustifyH("LEFT")
            header:SetTextColor(1, 1, 0)
            header:SetFont("Fonts\\FRIZQT__.TTF", 12)

            -- Store the header Y offset for the current topic
            local topicYOffset = yOffset - 20  -- space between header and first placeholder
            yOffset = topicYOffset - 110  -- space between headers

            topicPlaceholders[topic.name] = topicPlaceholders[topic.name] or { FontStrings = {} }

            for i = 1, numberOfPlaceholders do

                -- create Name column
                local nameColumn = contentFrame:CreateFontString("$parent_" .. topic.name .. "Placeholder" .. i .. "_Name", "OVERLAY", "GameFontNormal")
                nameColumn:SetText("-")  -- Example name
                nameColumn:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 10, topicYOffset)
                nameColumn:SetWidth(150)
                nameColumn:SetJustifyH("LEFT")
                nameColumn:SetTextColor(1, 1, 1)
                nameColumn:SetFont("Fonts\\FRIZQT__.TTF", 10)

                -- create Message column
                local messageColumn = contentFrame:CreateFontString("$parent_" .. topic.name .. "Placeholder" .. i .. "_Message", "OVERLAY", "GameFontNormal")
                messageColumn:SetText("-")
                messageColumn:SetPoint("TOPLEFT", nameColumn, "TOPRIGHT", 10, 0)
                messageColumn:SetWidth(500)
                messageColumn:SetHeight(10)
                messageColumn:SetJustifyH("LEFT")
                messageColumn:SetTextColor(1, 1, 1)
                messageColumn:SetFont("Fonts\\FRIZQT__.TTF", 10)

                -- create Time column
                local timeColumn = contentFrame:CreateFontString("$parent_" .. topic.name .. "Placeholder" .. i .. "_Time", "OVERLAY", "GameFontNormal")
                timeColumn:SetText("-")
                timeColumn:SetPoint("TOPLEFT", messageColumn, "TOPRIGHT", 10, 0)
                timeColumn:SetWidth(100)
                timeColumn:SetJustifyH("LEFT")
                timeColumn:SetTextColor(1, 1, 1)
                timeColumn:SetFont("Fonts\\FRIZQT__.TTF", 10)

                table.insert(topicPlaceholders[topic.name].FontStrings, { nameColumn, messageColumn, timeColumn })

                -- Increment the Y-offset for the next placeholder
                topicYOffset = topicYOffset - 18  -- space between placeholders
            end

            -- After the placeholders, adjust the main yOffset for the next topic
            yOffset = topicYOffset - 10  -- space between topics
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

    if DifficultBulletinBoardSavedVariables.numberOfPlaceholders and  DifficultBulletinBoardSavedVariables.numberOfPlaceholders ~= "" then
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

local function addPlaceholderOptionToExistingUI()
    local parentFrame = DifficultBulletinBoardOptionFrame

    -- Create the first FontString (label) above the scroll frame
    local scrollLabel = parentFrame:CreateFontString("DifficultBulletinBoard_Option_PlaceholderOption_FontString", "OVERLAY", "GameFontHighlight")
    scrollLabel:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", 15, -50)  -- Position at the top of the parent frame
    scrollLabel:SetText("Set the Number of Placeholders for Each Topic:")
    scrollLabel:SetText("Number of Placeholders per Topic:")
    scrollLabel:SetFont("Fonts\\FRIZQT__.TTF", 14)

    local placeholderOptionTextBox = CreateFrame("EditBox", "DifficultBulletinBoard_Option_PlaceholderOption_TextBox", parentFrame, "InputBoxTemplate")
    placeholderOptionTextBox:SetPoint("RIGHT", scrollLabel, "RIGHT", 30, -0)
    placeholderOptionTextBox:SetWidth(20)
    placeholderOptionTextBox:SetHeight(20)
    placeholderOptionTextBox:SetText(numberOfPlaceholders)
    placeholderOptionTextBox:EnableMouse(true)
    placeholderOptionTextBox:SetAutoFocus(false)
end

local function addScrollFrameToExistingUI()
    local parentFrame = DifficultBulletinBoardOptionFrame
    local placeholderOptionTextBox = DifficultBulletinBoard_Option_PlaceholderOption_FontString

    -- Create the second FontString (label) below the first label
    local scrollLabel = parentFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    scrollLabel:SetPoint("TOPLEFT", placeholderOptionTextBox, "BOTTOMLEFT", 0, -25)  -- Position it below the first label
    scrollLabel:SetText("Select the Topics you want to observe:")
    scrollLabel:SetFont("Fonts\\FRIZQT__.TTF", 14)

    -- Create the ScrollFrame, positioning it below the second label
    local scrollFrame = CreateFrame("ScrollFrame", "$parent_ScrollFrame", parentFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", scrollLabel, "BOTTOMLEFT", -10, -10)  -- Position it below the second label
    scrollFrame:SetWidth(460)
    scrollFrame:SetHeight(520)

    -- Create the child frame inside the scroll frame
    local scrollChild = CreateFrame("Frame", "$parent_ScrollChild", scrollFrame)
    scrollChild:SetWidth(480)
    scrollChild:SetHeight(1300)
    scrollFrame:SetScrollChild(scrollChild)
end

local tempTags = {}
local function createOptions()
    local scrollChild = DifficultBulletinBoardOptionFrame_ScrollFrame_ScrollChild
    local yOffset = 0  -- Starting vertical offset for the first checkbox

    for _, topic in ipairs(allTopics) do
        local checkbox = CreateFrame("CheckButton", "$parent_" .. topic.name .. "_Checkbox", scrollChild, "UICheckButtonTemplate")
        checkbox:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 10, yOffset)
        checkbox:SetWidth(25)
        checkbox:SetHeight(25)
        checkbox:SetChecked(topic.selected)

        local currentTopic = topic
        checkbox:SetScript("OnClick", function()
            currentTopic.selected = checkbox:GetChecked()
        end)

        -- Add a label next to the checkbox displaying the topic
        local topicLabel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        topicLabel:SetPoint("LEFT", checkbox, "RIGHT", 10, 0)
        topicLabel:SetText(topic.name)
        topicLabel:SetFont("Fonts\\FRIZQT__.TTF", 12)
        topicLabel:SetJustifyH("LEFT")
        topicLabel:SetWidth(175)

        -- Add a text box next to the topic label for tags input
        local tagsTextBox = CreateFrame("EditBox", "$parent_" .. topic.name .. "_TagsTextBox", scrollChild, "InputBoxTemplate")
        tagsTextBox:SetPoint("LEFT", topicLabel, "RIGHT", 10, 0)
        tagsTextBox:SetWidth(200)
        tagsTextBox:SetHeight(20)
        tagsTextBox:SetText(table.concat(topic.tags, " "))
        tagsTextBox:EnableMouse(true)
        tagsTextBox:SetAutoFocus(false)

        local topicName = topic.name --save a reference for the onTextChanged event
        tagsTextBox:SetScript("OnTextChanged", function()
            local enteredText = this:GetText()
            tempTags[topicName] = splitIntoLowerWords(enteredText)
        end)

        yOffset = yOffset - 30  -- Adjust the vertical offset for the next row
    end
end

local function initializeAddon(event, arg1)
    if event == "ADDON_LOADED" and arg1 == "DifficultBulletinBoard" then
        loadSavedVariables()

        -- create option frame first so the user can update his options in case he put in some invalid data that might result in the addon crashing
        addPlaceholderOptionToExistingUI()
        addScrollFrameToExistingUI()
        createOptions()

        --create main frame afterwards
        createTopicList()
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
    ReloadUI();
end

function DifficultBulletinBoard_SaveVariablesAndReload()
    DifficultBulletinBoardSavedVariables.numberOfPlaceholders = DifficultBulletinBoard_Option_PlaceholderOption_TextBox:GetText()
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
        local matchFound = false  -- Flag to control breaking out of nested loops

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

                    matchFound = true  -- Set the flag to true to break out of loops
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