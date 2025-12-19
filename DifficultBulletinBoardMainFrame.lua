-- DifficultBulletinBoardMainFrame.lua
-- Main frame implementation for Difficult Bulletin Board
-- Handles all UI display, filtering, and message processing for the main window

DifficultBulletinBoard = DifficultBulletinBoard or {}
DifficultBulletinBoardVars = DifficultBulletinBoardVars or {}
DifficultBulletinBoardMainFrame = DifficultBulletinBoardMainFrame or {}



local string_gfind = string.gmatch or string.gfind

local mainFrame = DifficultBulletinBoardMainFrame

-- Constants for dynamic button sizing
local BUTTON_SPACING = 10  -- Fixed spacing between buttons
local MIN_TEXT_PADDING = 10  -- Minimum spacing between text and button edges
local NUM_BUTTONS = 4      -- Total number of main buttons
local SIDE_PADDING = 10    -- Padding on left and right sides of frame

--[[
    Dynamic Button Sizing Logic:
    
    The top button row (Groups, Groups Logs, Professions, Hardcore Logs)
    will dynamically resize when the user changes the width of the main frame.
    
    Key behaviors:
    - The spacing between buttons remains fixed at 10px
    - The buttons grow/shrink to fill available space
    - Button text always has at least 5px padding on each side
    - The minimum frame width is determined dynamically based on button text
    
    If you add more buttons or change button text, the sizing will adjust automatically.
]]

local chatMessageWidthDelta = 220
local systemMessageWidthDelta = 155

local groupScrollFrame
local groupScrollChild
local groupsLogsScrollFrame
local groupsLogsScrollChild
local professionScrollFrame
local professionScrollChild
local hardcoreScrollFrame
local hardcoreScrollChild

local groupsButton = DifficultBulletinBoardMainFrameGroupsButton
local groupsLogsButton = DifficultBulletinBoardMainFrameGroupsLogsButton
local professionsButton = DifficultBulletinBoardMainFrameProfessionsButton
local hcMessagesButton = DifficultBulletinBoardMainFrameHCMessagesButton

local groupTopicPlaceholders = {}
local groupTopicHeaders = {}  -- registry for group topic headers for dynamic reflow
local groupTopicCollapsed = {} -- track collapse state for each topic
local groupTopicSavedInstances = {} -- track which topics are saved instances (red color when collapsed)
local groupsLogsPlaceholders = {} -- New container for Groups Logs entries
local professionTopicPlaceholders = {}
local professionTopicHeaders = {}  -- registry for profession topic headers for dynamic reflow
local professionTopicCollapsed = {} -- track collapse state for each profession topic
local hardcoreTopicPlaceholders = {}
local hardcoreTopicHeaders = {}  -- registry for hardcore topic headers for dynamic reflow
local hardcoreTopicCollapsed = {} -- track collapse state for each hardcore topic

DifficultBulletinBoard.notificationList = {} --tracks which topic has notifications enabled

-- Store current filter text globally
local currentGroupsLogsFilter = ""

-- Add global reference to the search frame
local groupsLogsSearchFrame = nil

-- Apply filter to Groups Logs entries - delegates to message processor
local function applyGroupsLogsFilter(searchText)
    if DifficultBulletinBoardMessageProcessor and DifficultBulletinBoardMessageProcessor.ApplyGroupsLogsFilter then
        DifficultBulletinBoardMessageProcessor.ApplyGroupsLogsFilter(searchText)
    end
end

-- Check saved instances and auto-collapse matching group topics
function DifficultBulletinBoardMainFrame.CheckSavedInstancesAndCollapse()
    -- Get the number of saved instances
    local numSavedInstances = GetNumSavedInstances()
    if not numSavedInstances or numSavedInstances == 0 then
        return
    end

    -- Clear previous saved instance tracking
    for k in pairs(groupTopicSavedInstances) do
        groupTopicSavedInstances[k] = nil
    end

    -- Build a list of saved instance names (lowercase for matching)
    local savedInstanceNames = {}
    for i = 1, numSavedInstances do
        local instanceName = GetSavedInstanceInfo(i)
        if instanceName then
            -- Store the lowercase version for case-insensitive matching
            savedInstanceNames[string.lower(instanceName)] = true
        end
    end

    -- Check each group topic to see if it matches a saved instance
    for _, topic in ipairs(DifficultBulletinBoardVars.allGroupTopics) do
        if topic.selected then
            local topicNameLower = string.lower(topic.name)

            -- Check if this topic name matches any saved instance
            if savedInstanceNames[topicNameLower] then
                groupTopicSavedInstances[topic.name] = true
                groupTopicCollapsed[topic.name] = true

                -- Update the header if it exists
                local header = groupTopicHeaders[topic.name]
                if header then
                    header:SetText("[+] " .. topic.name)
                    header:SetTextColor(1.0, 0.2, 0.2, 1.0)  -- red color for saved instances
                end
            end
        end
    end

    -- Trigger reflow to apply the collapse state
    DifficultBulletinBoardMainFrame.ReflowGroupsTab()
end

-- Function to get current filter text for message processor
function DifficultBulletinBoardMainFrame.GetCurrentGroupsLogsFilter()
    return currentGroupsLogsFilter
end

-- Note: OnChatMessage and OnSystemMessage are now implemented in DifficultBulletinBoardMessageProcessor.lua
-- They are defined as DifficultBulletinBoard.OnChatMessage and DifficultBulletinBoard.OnSystemMessage
-- No delegation needed here since they're already in the correct namespace

-- Number of entries to show in the Groups Logs tab
local MAX_GROUPS_LOGS_ENTRIES = 50

-- Keyword filter variables
local KEYWORD_FILTER_HEIGHT = 30
local KEYWORD_FILTER_BOTTOM_MARGIN = 4  -- Distance from bottom of frame to filter line
local KEYWORD_FILTER_SCROLL_MARGIN = 8  -- Distance from filter line to scroll content
local keywordFilterVisible = false
local keywordFilterLine = nil
local keywordFilterInput = nil











-- This function configures the tab switching behavior for the main frame
local function configureTabSwitching()
    -- Define all tabs with their buttons and scroll frames
    local tabs = {
        { button = groupsButton, frame = groupScrollFrame, isActive = true },
        { button = groupsLogsButton, frame = groupsLogsScrollFrame, isActive = false },
        { button = professionsButton, frame = professionScrollFrame, isActive = false },
        { button = hcMessagesButton, frame = hardcoreScrollFrame, isActive = false },
    }

    local function UpdateButtonState(tab)
        local button = tab.button
        local textElement = getglobal(button:GetName().."_Text")
        
        if tab.isActive then
            button:SetBackdropColor(0.25, 0.25, 0.3, 1.0) -- Darker color for active tab
            textElement:SetTextColor(1.0, 1.0, 1.0, 1.0) -- Brighter text for active tab
        elseif tab.isHovered then
            button:SetBackdropColor(0.18, 0.18, 0.2, 1.0) -- Hover color
            textElement:SetTextColor(0.9, 0.9, 1.0, 1.0) -- Hover text color
        else
            button:SetBackdropColor(0.15, 0.15, 0.15, 1.0) -- Normal color
            textElement:SetTextColor(0.9, 0.9, 0.9, 1.0) -- Normal text color
        end
    end

    local function ResetButtonStates()
        for _, tab in ipairs(tabs) do
            tab.isActive = false
            tab.frame:Hide()
            UpdateButtonState(tab)
        end
    end

    local function ActivateTab(activeTab)
        activeTab.isActive = true
        activeTab.frame:Show()
        UpdateButtonState(activeTab)
    end

    for _, tab in ipairs(tabs) do
        local currentTab = tab
        tab.isHovered = false

        -- Set up hover effects
        tab.button:SetScript("OnEnter", function()
            currentTab.isHovered = true
            UpdateButtonState(currentTab)
        end)

        tab.button:SetScript("OnLeave", function()
            currentTab.isHovered = false
            UpdateButtonState(currentTab)
        end)

        -- Set up click handler
        tab.button:SetScript("OnClick", function()
            ResetButtonStates()
            ActivateTab(currentTab)
        end)
    end

    -- set groups as the initial tab
    ActivateTab(tabs[1])
end

local tempChatMessageFrames = {}
local tempChatMessageColumns = {}

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
    if not frame or not message or message == "-" or message == "" or not GameTooltip then
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
    
    --save the old font settings
    local leftLine = GameTooltipTextLeft1
    local oldR, oldG, oldB, oldA = GameTooltip:GetBackdropBorderColor()
    local oldFontPath, oldFontSize, oldFontFlags = leftLine:GetFont()

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

    --swap in a temporary OnHide handler
    local origOnHide = GameTooltip:GetScript("OnHide")
    GameTooltip:SetScript("OnHide", function()
        leftLine:SetFont(oldFontPath, oldFontSize, oldFontFlags)
        this:SetBackdropBorderColor(oldR, oldG, oldB, oldA)
        
        --restore the original script
        this:SetScript("OnHide", origOnHide)
        
        --call the original if it existed
        if origOnHide then 
            origOnHide() 
        end
    end)
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

-- Helper to reflow the Groups tab based on actual entries
function DifficultBulletinBoardMainFrame.ReflowGroupsTab()
  if not groupScrollChild then return end
  local cf = groupScrollChild
  local y = -3
  for _, topic in ipairs(DifficultBulletinBoardVars.allGroupTopics) do
    if topic.selected then
      -- Reposition header
      local header = groupTopicHeaders[topic.name]
      if header then
        header:ClearAllPoints()
        header:SetPoint("TOPLEFT", cf, "TOPLEFT", 15, y)
      end
      y = y - 20  -- space after header
      local placeholders = groupTopicPlaceholders[topic.name] or {}
      if groupTopicCollapsed[topic.name] then
        -- Hide all entries when collapsed
        for _, entry in ipairs(placeholders) do
          if entry.nameButton then entry.nameButton:Hide() end
          if entry.messageFontString then entry.messageFontString:Hide() end
          if entry.timeFontString then entry.timeFontString:Hide() end
          if entry.icon then entry.icon:Hide() end
        end
        y = y - 10  -- gap between topics
      else
        -- Count visible entries
        local count = 0
        for _, entry in ipairs(placeholders) do
          if entry.creationTimestamp then count = count + 1 end
        end
        -- First pass: Reposition entries
        for i = 1, table.getn(placeholders) do
          local entry = placeholders[i]
          
          if i <= count and entry.creationTimestamp then
            -- This is a visible entry with content
            -- Reposition name button
            entry.nameButton:ClearAllPoints()
            entry.nameButton:SetPoint("TOPLEFT", cf, "TOPLEFT", entry.baseX, y)
            -- Ensure text and time are visible on expand
            if entry.nameButton then entry.nameButton:Show() end
            if entry.messageFontString then entry.messageFontString:Show() end
            if entry.timeFontString then entry.timeFontString:Show() end
            if entry.icon then
              entry.icon:ClearAllPoints()
              entry.icon:SetPoint("RIGHT", entry.nameButton, "LEFT", 3, 0)
              entry.icon:Show()
            end
            y = y - 18
          else
            -- This is an empty placeholder - hide it completely
            if entry.nameButton then entry.nameButton:Hide() end
            if entry.messageFontString then entry.messageFontString:Hide() end
            if entry.timeFontString then entry.timeFontString:Hide() end
            if entry.icon then entry.icon:Hide() end
          end
        end
        
        -- Tooltip handlers are now dynamic and don't need updating after repositioning
        y = y - 10  -- gap between topics
      end
    end
  end
  -- Resize scroll child and update scroll frame
  cf:SetHeight(math.abs(y))
  if groupScrollFrame then
      local scrollBar = getglobal(groupScrollFrame:GetName().."ScrollBar")
      local scrollFrameHeight = groupScrollFrame:GetHeight()
      local contentHeight = cf:GetHeight()
      local actualMaxScroll = contentHeight - scrollFrameHeight
      
      -- Ensure minimum 25px scrollable content to prevent snap behavior
      local finalHeight = contentHeight
      if actualMaxScroll < 25 then
          finalHeight = scrollFrameHeight + 25
          cf:SetHeight(finalHeight)
      end
      
      local maxScroll = finalHeight - scrollFrameHeight
      if maxScroll < 0 then maxScroll = 0 end
      scrollBar:SetMinMaxValues(0, maxScroll)
      if scrollBar:GetValue() > maxScroll then scrollBar:SetValue(maxScroll) end
  end
end

-- Helper to reflow the Professions tab based on actual entries
function DifficultBulletinBoardMainFrame.ReflowProfessionsTab()
  if not professionScrollChild then return end
  local cf = professionScrollChild
  local y = -3
  for _, topic in ipairs(DifficultBulletinBoardVars.allProfessionTopics) do
    if topic.selected then
      -- Reposition header
      local header = professionTopicHeaders[topic.name]
      if header then
        header:ClearAllPoints()
        header:SetPoint("TOPLEFT", cf, "TOPLEFT", 15, y)
      end
      y = y - 20  -- space after header
      local placeholders = professionTopicPlaceholders[topic.name] or {}
      if professionTopicCollapsed[topic.name] then
        -- Hide all entries when collapsed
        for _, entry in ipairs(placeholders) do
          if entry.nameButton then entry.nameButton:Hide() end
          if entry.messageFontString then entry.messageFontString:Hide() end
          if entry.timeFontString then entry.timeFontString:Hide() end
          if entry.icon then entry.icon:Hide() end
        end
        y = y - 10  -- gap between topics
      else
        -- Count visible entries
        local count = 0
        for _, entry in ipairs(placeholders) do
          if entry.creationTimestamp then count = count + 1 end
        end
        -- First pass: Reposition entries
        for i = 1, table.getn(placeholders) do
          local entry = placeholders[i]
          
          if i <= count and entry.creationTimestamp then
            -- This is a visible entry with content
            -- Reposition name button
            entry.nameButton:ClearAllPoints()
            entry.nameButton:SetPoint("TOPLEFT", cf, "TOPLEFT", entry.baseX, y)
            -- Ensure text and time are visible on expand
            if entry.nameButton then entry.nameButton:Show() end
            if entry.messageFontString then entry.messageFontString:Show() end
            if entry.timeFontString then entry.timeFontString:Show() end
            if entry.icon then
              entry.icon:ClearAllPoints()
              entry.icon:SetPoint("RIGHT", entry.nameButton, "LEFT", 3, 0)
              entry.icon:Show()
            end
            y = y - 18
          else
            -- This is an empty placeholder - hide it completely
            if entry.nameButton then entry.nameButton:Hide() end
            if entry.messageFontString then entry.messageFontString:Hide() end
            if entry.timeFontString then entry.timeFontString:Hide() end
            if entry.icon then entry.icon:Hide() end
          end
        end
        
        -- Tooltip handlers are now dynamic and don't need updating after repositioning
        y = y - 10  -- gap between topics
      end
    end
  end
  -- Resize scroll child and update scroll frame
  cf:SetHeight(math.abs(y))
  if professionScrollFrame then
      local scrollBar = getglobal(professionScrollFrame:GetName().."ScrollBar")
      local scrollFrameHeight = professionScrollFrame:GetHeight()
      local contentHeight = cf:GetHeight()
      local actualMaxScroll = contentHeight - scrollFrameHeight
      
      -- Ensure minimum 25px scrollable content to prevent snap behavior
      local finalHeight = contentHeight
      if actualMaxScroll < 25 then
          finalHeight = scrollFrameHeight + 25
          cf:SetHeight(finalHeight)
      end
      
      local maxScroll = finalHeight - scrollFrameHeight
      if maxScroll < 0 then maxScroll = 0 end
      scrollBar:SetMinMaxValues(0, maxScroll)
      if scrollBar:GetValue() > maxScroll then scrollBar:SetValue(maxScroll) end
  end
end

-- Helper to reflow the Hardcore tab based on actual entries
function DifficultBulletinBoardMainFrame.ReflowHardcoreTab()
  if not hardcoreScrollChild then return end
  local cf = hardcoreScrollChild
  local y = -3
  for _, topic in ipairs(DifficultBulletinBoardVars.allHardcoreTopics) do
    if topic.selected then
      -- Reposition header
      local header = hardcoreTopicHeaders[topic.name]
      if header then
        header:ClearAllPoints()
        header:SetPoint("TOPLEFT", cf, "TOPLEFT", 5, y)
      end
      y = y - 20  -- space after header
      local placeholders = hardcoreTopicPlaceholders[topic.name] or {}
      if hardcoreTopicCollapsed[topic.name] then
        -- Hide all entries when collapsed
        for _, entry in ipairs(placeholders) do
          if entry.messageFontString then entry.messageFontString:Hide() end
          if entry.timeFontString then entry.timeFontString:Hide() end
        end
        y = y - 10  -- gap between topics
      else
        -- Count visible entries
        local count = 0
        for _, entry in ipairs(placeholders) do
          if entry.creationTimestamp then count = count + 1 end
        end
        -- First pass: Reposition entries
        for i = 1, table.getn(placeholders) do
          local entry = placeholders[i]
          
          if i <= count and entry.creationTimestamp then
            -- This is a visible entry with content
            -- Reposition message frame
            entry.messageFrame:ClearAllPoints()
            entry.messageFrame:SetPoint("TOPLEFT", cf, "TOPLEFT", entry.baseX, y)
            -- Ensure text and time are visible on expand
            if entry.messageFontString then entry.messageFontString:Show() end
            if entry.timeFontString then entry.timeFontString:Show() end
            y = y - 18
          else
            -- This is an empty placeholder - hide it completely
            if entry.messageFontString then entry.messageFontString:Hide() end
            if entry.timeFontString then entry.timeFontString:Hide() end
          end
        end
        
        -- Tooltip handlers are now dynamic and don't need updating after repositioning
        y = y - 10  -- gap between topics
      end
    end
  end
  -- Resize scroll child and update scroll frame
  cf:SetHeight(math.abs(y))
  if hardcoreScrollFrame then
      local scrollBar = getglobal(hardcoreScrollFrame:GetName().."ScrollBar")
      local scrollFrameHeight = hardcoreScrollFrame:GetHeight()
      local contentHeight = cf:GetHeight()
      local actualMaxScroll = contentHeight - scrollFrameHeight
      
      -- Ensure minimum 25px scrollable content to prevent snap behavior
      local finalHeight = contentHeight
      if actualMaxScroll < 25 then
          finalHeight = scrollFrameHeight + 25
          cf:SetHeight(finalHeight)
      end
      
      local maxScroll = finalHeight - scrollFrameHeight
      if maxScroll < 0 then maxScroll = 0 end
      scrollBar:SetMinMaxValues(0, maxScroll)
      if scrollBar:GetValue() > maxScroll then scrollBar:SetValue(maxScroll) end
  end
end

-- Create topic list with name, message, and date columns
-- Used for Groups, Groups Logs, and Professions tabs
local function createTopicListWithNameMessageDateColumns(contentFrame, topicList, topicPlaceholders, numberOfPlaceholders)
  local yOffset = -3
  -- Store initial top offset to calculate dynamic height
  local initialYOffset = yOffset

  local chatMessageWidth = mainFrame:GetWidth() - chatMessageWidthDelta

  for _, topic in ipairs(topicList) do
   if topic.selected then
    local header =
     contentFrame:CreateFontString(
      "$parent_" .. topic.name .. "Header",
      "OVERLAY",
      "GameFontNormal"
     )
    header:SetText(topic.name)
    header:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 5, yOffset)
    header:SetWidth(mainFrame:GetWidth())
    header:SetJustifyH("LEFT")
    header:SetTextColor(0.9, 0.9, 1.0, 1.0)
    header:SetFont("Fonts\\FRIZQT__.TTF", DifficultBulletinBoardVars.fontSize - 1)
    -- Determine which header registry and collapse state to use based on topicPlaceholders
    local topicHeaders, topicCollapsed, reflowFunction
    if topicPlaceholders == groupTopicPlaceholders then
        topicHeaders = groupTopicHeaders
        topicCollapsed = groupTopicCollapsed
        reflowFunction = DifficultBulletinBoardMainFrame.ReflowGroupsTab
    elseif topicPlaceholders == professionTopicPlaceholders then
        topicHeaders = professionTopicHeaders
        topicCollapsed = professionTopicCollapsed
        reflowFunction = DifficultBulletinBoardMainFrame.ReflowProfessionsTab
    else
        -- For other tabs (like Groups Logs), use group headers as fallback
        topicHeaders = groupTopicHeaders
        topicCollapsed = groupTopicCollapsed
        reflowFunction = DifficultBulletinBoardMainFrame.ReflowGroupsTab
    end
    
    -- Register the header for dynamic reflow later
    topicHeaders[topic.name] = header
    -- Initialize collapse state for this topic - load from saved variables or default to false
    local collapseTopicName = topic.name
    local savedState = false
    if DifficultBulletinBoardSavedVariables and DifficultBulletinBoardSavedVariables.collapsedHeaders then
        if topicPlaceholders == groupTopicPlaceholders then
            savedState = DifficultBulletinBoardSavedVariables.collapsedHeaders.groups and 
                        DifficultBulletinBoardSavedVariables.collapsedHeaders.groups[collapseTopicName] or false
        elseif topicPlaceholders == professionTopicPlaceholders then
            savedState = DifficultBulletinBoardSavedVariables.collapsedHeaders.professions and 
                        DifficultBulletinBoardSavedVariables.collapsedHeaders.professions[collapseTopicName] or false
        end
    end
    topicCollapsed[collapseTopicName] = savedState
    -- Set initial header text with collapse indicator based on saved state
    if savedState then
        header:SetText("[+] " .. collapseTopicName)
        header:SetTextColor(0.6, 0.6, 0.7, 1.0)  -- dimmed color when collapsed
    else
        header:SetText("[-] " .. collapseTopicName)
        header:SetTextColor(0.9, 0.9, 1.0, 1.0)  -- default bright color when expanded
    end
    -- Create clickable header area to toggle collapse
    local headerButton = CreateFrame("Button", "$parent_"..collapseTopicName.."HeaderButton", contentFrame)
    headerButton:SetAllPoints(header)
    headerButton:RegisterForClicks("LeftButtonUp")
    headerButton:SetScript("OnClick", function()
        -- Toggle collapse state using captured name
        topicCollapsed[collapseTopicName] = not topicCollapsed[collapseTopicName]

        -- Save the new state to saved variables
        if not DifficultBulletinBoardSavedVariables then
            DifficultBulletinBoardSavedVariables = {}
        end
        if not DifficultBulletinBoardSavedVariables.collapsedHeaders then
            DifficultBulletinBoardSavedVariables.collapsedHeaders = {groups = {}, professions = {}, hardcore = {}}
        end

        -- Determine which category to save to
        if topicPlaceholders == groupTopicPlaceholders then
            if not DifficultBulletinBoardSavedVariables.collapsedHeaders.groups then
                DifficultBulletinBoardSavedVariables.collapsedHeaders.groups = {}
            end
            DifficultBulletinBoardSavedVariables.collapsedHeaders.groups[collapseTopicName] = topicCollapsed[collapseTopicName]
        elseif topicPlaceholders == professionTopicPlaceholders then
            if not DifficultBulletinBoardSavedVariables.collapsedHeaders.professions then
                DifficultBulletinBoardSavedVariables.collapsedHeaders.professions = {}
            end
            DifficultBulletinBoardSavedVariables.collapsedHeaders.professions[collapseTopicName] = topicCollapsed[collapseTopicName]
        end

        -- Update header text and color to reflect new collapse state
        if topicCollapsed[collapseTopicName] then
            header:SetText("[+] " .. collapseTopicName)
            -- Use red color if this is a saved instance, otherwise use grey
            if topicPlaceholders == groupTopicPlaceholders and groupTopicSavedInstances[collapseTopicName] then
                header:SetTextColor(1.0, 0.2, 0.2, 1.0)  -- red color for saved instances
            else
                header:SetTextColor(0.6, 0.6, 0.7, 1.0)  -- dimmed color when collapsed
            end
        else
            header:SetText("[-] " .. collapseTopicName)
            header:SetTextColor(1.0, 1.0, 1.0, 1.0)  -- white color when expanded
        end
        reflowFunction()
    end)

    -- Hover effect to indicate clickability
    headerButton:SetScript("OnEnter", function()
        -- Highlight header text on hover with pure white
        header:SetTextColor(1.0, 1.0, 1.0, 1.0)
    end)

    headerButton:SetScript("OnLeave", function()
        -- Revert header color based on collapse state
        if topicCollapsed[collapseTopicName] then
            -- Use red color if this is a saved instance, otherwise use grey
            if topicPlaceholders == groupTopicPlaceholders and groupTopicSavedInstances[collapseTopicName] then
                header:SetTextColor(1.0, 0.2, 0.2, 1.0)  -- red color for saved instances
            else
                header:SetTextColor(0.6, 0.6, 0.7, 1.0)  -- dimmed color when collapsed
            end
        else
            header:SetTextColor(1.0, 1.0, 1.0, 1.0)  -- white color when expanded
        end
    end)

    -- do not add notifications to the Group Logs. This wouldnt make sense imo
    if collapseTopicName ~= "Group Logs" then
        local notificationButton = CreateFrame(
            "Button",
            "$parent_"..collapseTopicName.."NotificationButton",
            contentFrame
        )
        notificationButton:SetWidth(20)
        notificationButton:SetHeight(20)
        notificationButton:SetPoint("LEFT", header, "LEFT", -18, 0)

        notificationButton.icon = notificationButton:CreateTexture(nil, "ARTWORK")
        notificationButton.icon:SetAllPoints(notificationButton)
        notificationButton.icon:SetTexture("Interface\\AddOns\\DifficultBulletinBoard\\icons\\bell")
        notificationButton.icon:SetAlpha(0.3)

        DifficultBulletinBoard.notificationList[collapseTopicName] = false --default to false

        notificationButton:SetScript("OnClick", function()
            if DifficultBulletinBoard.notificationList[collapseTopicName] == true then
                notificationButton.icon:SetAlpha(0.3)
            else
                notificationButton.icon:SetAlpha(1)
            end

            DifficultBulletinBoard.notificationList[collapseTopicName] = not DifficultBulletinBoard.notificationList[collapseTopicName]
        end)

        notificationButton:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(notificationButton, "ANCHOR_RIGHT")
            GameTooltip:SetText(
                "Enabling the bell will show a notification if a new entry gets added to this topic.",
                1, 1, 1, 1, true
            )
            GameTooltip:Show()
        end)

        notificationButton:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
    end
    
    -- Calculate vertical offset for entries - add extra space for Group Logs tab
    local topicYOffset = yOffset - 20
    
    -- Add extra padding below the header in the Group Logs tab
    if topic.name == "Group Logs" then
      topicYOffset = topicYOffset - 5  -- Add 5px extra spacing for filter box
    end
    
    -- Dynamic height: rowHeight * max placeholders
    local rowHeight = 18  -- height of each entry row
    local placeholderHeight = numberOfPlaceholders * rowHeight
    yOffset = topicYOffset - placeholderHeight

    topicPlaceholders[topic.name] = topicPlaceholders[topic.name] or {
     FontStrings = {},
    }

    for i = 1, numberOfPlaceholders do
     -- Create a unique Icon texture for this placeholder
     local icon = contentFrame:CreateTexture(
       "$parent_" .. topic.name .. "Placeholder" .. i .. "_Icon",
       "ARTWORK"
     )
     icon:SetHeight(14)
     icon:SetWidth(14)
     -- Removed initial icon anchor; will anchor to nameButton after creation
     icon:SetPoint("RIGHT", contentFrame, "RIGHT", -2, topicYOffset - 2)

     local nameButton =
      CreateFrame(
       "Button",
       "$parent_" .. topic.name .. "Placeholder" .. i .. "_Name",
       contentFrame,
       nil
      )
     nameButton:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 10, topicYOffset)
     nameButton:SetWidth(40)
     nameButton:SetHeight(10)
     -- Anchor icon to the left of the name button with 1px gap
     icon:ClearAllPoints()
     icon:SetPoint("RIGHT", nameButton, "LEFT", 3, 0)
     
     -- Add this line to extend clickable area to the right
     nameButton:SetHitRectInsets(0, -45, 0, 0)

     local buttonText = nameButton:CreateFontString(nil, "OVERLAY", "GameFontNormal")
     buttonText:SetText("-")
     buttonText:SetPoint("LEFT", nameButton, "LEFT", 5, 0)
     buttonText:SetFont("Fonts\\FRIZQT__.TTF", DifficultBulletinBoardVars.fontSize - 1)
     buttonText:SetTextColor(1, 1, 1)
     nameButton:SetFontString(buttonText)

     nameButton:SetScript("OnEnter", function()
      buttonText:SetFont("Fonts\\FRIZQT__.TTF", DifficultBulletinBoardVars.fontSize - 1)
      buttonText:SetTextColor(0.9, 0.9, 1.0)
     end)

     nameButton:SetScript("OnLeave", function()
      buttonText:SetFont("Fonts\\FRIZQT__.TTF", DifficultBulletinBoardVars.fontSize - 1)
      buttonText:SetTextColor(1, 1, 1)
     end)

     local messageFrame =
      CreateFrame(
       "Button",
       "$parent_" .. topic.name .. "Placeholder" .. i .. "_MessageFrame",
       contentFrame
      )
     messageFrame:SetPoint("TOPLEFT", nameButton, "TOPLEFT", 90, 0)
     messageFrame:SetWidth(chatMessageWidth)
     messageFrame:SetHeight(10)
     messageFrame:EnableMouse(true)

     local messageColumn =
      contentFrame:CreateFontString(
       "$parent_" .. topic.name .. "Placeholder" .. i .. "_Message",
       "OVERLAY",
       "GameFontNormal"
      )
     messageColumn:SetText("-")
     messageColumn:SetPoint("TOPLEFT", nameButton, "TOPRIGHT", 50, 0)
     messageColumn:SetWidth(chatMessageWidth)
     messageColumn:SetHeight(10)
     messageColumn:SetJustifyH("LEFT")
     messageColumn:SetTextColor(1, 1, 1)
     messageColumn:SetFont("Fonts\\FRIZQT__.TTF", DifficultBulletinBoardVars.fontSize - 1)

     local timeColumn =
      contentFrame:CreateFontString(
       "$parent_" .. topic.name .. "Placeholder" .. i .. "_Time",
       "OVERLAY",
       "GameFontNormal"
      )
     timeColumn:SetText("-")
     timeColumn:SetPoint("TOPLEFT", messageColumn, "TOPRIGHT", 20, 0)
     timeColumn:SetWidth(100)
     timeColumn:SetJustifyH("LEFT")
     timeColumn:SetTextColor(1, 1, 1)
     timeColumn:SetFont("Fonts\\FRIZQT__.TTF", DifficultBulletinBoardVars.fontSize - 1)

     -- Store reference to message column directly in the button for easy access
     nameButton.messageFontString = messageColumn

	nameButton:SetScript("OnClick", function()
	  local pressedButton = arg1
	  local targetName = nameButton:GetText()

	  -- dont do anything when its a placeholder
	  if targetName == "-" then
	   return
	  end

	  if pressedButton == "LeftButton" then
	   if IsShiftKeyDown() then
		SendWho(targetName)
	   else
		ChatFrame_OpenChat("/w " .. targetName)
	   end
	  end
	end)

     -- OnClick doesnt support right clicking... so lets just check OnMouseDown
     -- instead
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

     table.insert(
      topicPlaceholders[topic.name],
      {
       icon = icon,
       nameButton = nameButton,
       messageFontString = messageColumn,
       timeFontString = timeColumn,
       messageFrame = messageFrame,
       creationTimestamp = nil,
       contentFrame = contentFrame,
       baseX = 10,
       baseY = topicYOffset,
      }
     )

     table.insert(tempChatMessageFrames, messageFrame)
     table.insert(tempChatMessageColumns, messageColumn)

     -- Set up dynamic tooltip system that always finds the correct message
     messageFrame:SetScript("OnEnter", function()
       DifficultBulletinBoardMainFrame.ShowDynamicTooltip(this)
     end)

     messageFrame:SetScript("OnLeave", function()
       DifficultBulletinBoardMainFrame.HideMessageTooltip(this)
     end)

     topicYOffset = topicYOffset - 18
    end

    yOffset = topicYOffset - 10
   end
  end

  -- Adjust content frame height to fit all entries dynamically
  local contentHeight = initialYOffset - yOffset
  contentFrame:SetHeight(contentHeight)
  -- Update scroll frame for new content height
  local scrollFrame = contentFrame:GetParent()
  if scrollFrame then
    scrollFrame:SetScrollChild(contentFrame)
    local scrollBar = getglobal(scrollFrame:GetName().."ScrollBar")
    local scrollFrameHeight = scrollFrame:GetHeight()
    local actualMaxScroll = contentHeight - scrollFrameHeight
    
    -- Ensure minimum 25px scrollable content to prevent snap behavior
    local finalHeight = contentHeight
    if actualMaxScroll < 25 then
        finalHeight = scrollFrameHeight + 25
        contentFrame:SetHeight(finalHeight)
    end
    
    local maxScroll = finalHeight - scrollFrameHeight
    if maxScroll < 0 then maxScroll = 0 end
    scrollBar:SetMinMaxValues(0, maxScroll)
    if scrollBar:GetValue() > maxScroll then scrollBar:SetValue(maxScroll) end
  end
end

local tempSystemMessageFrames = {}
local tempSystemMessageColumns = {}

-- Function to create the placeholders and font strings for a topic
-- Used for Hardcore Logs tab with precise alignment and resize support
local function createTopicListWithMessageDateColumns(contentFrame, topicList, topicPlaceholders, numberOfPlaceholders)
    -- initial Y-offset for the first header and placeholder
    local yOffset = -3
    -- Store initial top offset for dynamic height calculation
    local initialYOffset = yOffset

    local systemMessageWidth = mainFrame:GetWidth() - systemMessageWidthDelta

    for _, topic in ipairs(topicList) do
        if topic.selected then
            local header = contentFrame:CreateFontString("$parent_" .. topic.name ..  "Header", "OVERLAY", "GameFontNormal")
            header:SetText(topic.name)
            header:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 5, yOffset)
            header:SetWidth(mainFrame:GetWidth())
            header:SetJustifyH("LEFT")
            header:SetTextColor(0.9, 0.9, 1.0, 1.0)
            header:SetFont("Fonts\\FRIZQT__.TTF", DifficultBulletinBoardVars.fontSize - 1)
            
            -- Register the header for dynamic reflow later
            hardcoreTopicHeaders[topic.name] = header
            -- Initialize collapse state for this topic - load from saved variables or default to false
            local collapseTopicName = topic.name
            local savedState = false
            if DifficultBulletinBoardSavedVariables and DifficultBulletinBoardSavedVariables.collapsedHeaders and
               DifficultBulletinBoardSavedVariables.collapsedHeaders.hardcore then
                savedState = DifficultBulletinBoardSavedVariables.collapsedHeaders.hardcore[collapseTopicName] or false
            end
            hardcoreTopicCollapsed[collapseTopicName] = savedState
            -- Set initial header text with collapse indicator based on saved state
            if savedState then
                header:SetText("[+] " .. collapseTopicName)
                header:SetTextColor(0.6, 0.6, 0.7, 1.0)  -- dimmed color when collapsed
            else
                header:SetText("[-] " .. collapseTopicName)
                header:SetTextColor(0.9, 0.9, 1.0, 1.0)  -- default bright color when expanded
            end
            -- Create clickable header area to toggle collapse
            local headerButton = CreateFrame("Button", "$parent_"..collapseTopicName.."HeaderButton", contentFrame)
            headerButton:SetAllPoints(header)
            headerButton:RegisterForClicks("LeftButtonUp")
            headerButton:SetScript("OnClick", function()
                -- Toggle collapse state using captured name
                hardcoreTopicCollapsed[collapseTopicName] = not hardcoreTopicCollapsed[collapseTopicName]
                
                -- Save the new state to saved variables
                if not DifficultBulletinBoardSavedVariables then
                    DifficultBulletinBoardSavedVariables = {}
                end
                if not DifficultBulletinBoardSavedVariables.collapsedHeaders then
                    DifficultBulletinBoardSavedVariables.collapsedHeaders = {groups = {}, professions = {}, hardcore = {}}
                end
                if not DifficultBulletinBoardSavedVariables.collapsedHeaders.hardcore then
                    DifficultBulletinBoardSavedVariables.collapsedHeaders.hardcore = {}
                end
                DifficultBulletinBoardSavedVariables.collapsedHeaders.hardcore[collapseTopicName] = hardcoreTopicCollapsed[collapseTopicName]
                
                -- Update header text and color to reflect new collapse state
                if hardcoreTopicCollapsed[collapseTopicName] then
                    header:SetText("[+] " .. collapseTopicName)
                    header:SetTextColor(0.6, 0.6, 0.7, 1.0)  -- dimmed color when collapsed
                else
                    header:SetText("[-] " .. collapseTopicName)
                    header:SetTextColor(0.9, 0.9, 1.0, 1.0)  -- default bright color when expanded
                end
                DifficultBulletinBoardMainFrame.ReflowHardcoreTab()
            end)
            -- Hover effect to indicate clickability
            headerButton:SetScript("OnEnter", function()
                -- Highlight header text on hover with pure white
                header:SetTextColor(1.0, 1.0, 1.0, 1.0)
            end)
            headerButton:SetScript("OnLeave", function()
                -- Revert header color based on collapse state
                if hardcoreTopicCollapsed[collapseTopicName] then
                    header:SetTextColor(0.6, 0.6, 0.7, 1.0)
                else
                    header:SetTextColor(0.9, 0.9, 1.0, 1.0)
                end
            end)

            -- Calculate vertical offset for entries - dynamic height based on actual entries
            local topicYOffset = yOffset - 20
            -- Dynamic height: rowHeight * max placeholders
            local rowHeight = 18  -- height of each entry row
            local placeholderHeight = numberOfPlaceholders * rowHeight
            yOffset = topicYOffset - placeholderHeight

            topicPlaceholders[topic.name] = topicPlaceholders[topic.name] or {FontStrings = {}}

            for i = 1, numberOfPlaceholders do
                -- Create an invisible button to act as a parent
                local messageFrame = CreateFrame("Button", "$parent_" .. topic.name .. "Placeholder" .. i .. "_MessageFrame", contentFrame)
                messageFrame:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 10, topicYOffset)
                messageFrame:SetWidth(systemMessageWidth)
                messageFrame:SetHeight(10)
                messageFrame:EnableMouse(true)

                -- Create Message column with exact alignment
                local messageColumn = contentFrame:CreateFontString("$parent_" .. topic.name .. "Placeholder" .. i .. "_Message", "OVERLAY", "GameFontNormal")
                messageColumn:SetText("-")
                messageColumn:SetPoint("TOPLEFT", messageFrame, "TOPLEFT", 5, 0)  -- Add 5px offset to match name column text
                messageColumn:SetWidth(systemMessageWidth)
                messageColumn:SetHeight(10)
                messageColumn:SetJustifyH("LEFT")
                messageColumn:SetTextColor(1, 1, 1, 1)
                messageColumn:SetFont("Fonts\\FRIZQT__.TTF", DifficultBulletinBoardVars.fontSize - 1)

                -- Create Time column with correct positioning for proper resize behavior
                local timeColumn = contentFrame:CreateFontString("$parent_" .. topic.name .. "Placeholder" .. i .. "_Time", "OVERLAY", "GameFontNormal")
                timeColumn:SetText("-")
                
                -- Important: Attach time column to message column for consistent resizing behavior
                -- Use the user-specified offset of 57px instead of the default 20px
                timeColumn:SetPoint("LEFT", messageColumn, "RIGHT", 40, 0)
                timeColumn:SetWidth(100)
                timeColumn:SetJustifyH("LEFT")
                timeColumn:SetTextColor(1, 1, 1, 1)
                timeColumn:SetFont("Fonts\\FRIZQT__.TTF", DifficultBulletinBoardVars.fontSize - 1)

                table.insert(topicPlaceholders[topic.name], {
                    nameButton = nil, 
                    messageFontString = messageColumn, 
                    timeFontString = timeColumn, 
                    messageFrame = messageFrame, 
                    creationTimestamp = nil,
                    contentFrame = contentFrame,
                    baseX = 10,
                    baseY = topicYOffset,
                })

                table.insert(tempSystemMessageFrames, messageFrame)
                table.insert(tempSystemMessageColumns, messageColumn)

                -- Set up dynamic tooltip system that always finds the correct message
                messageFrame:SetScript("OnEnter", function()
                    DifficultBulletinBoardMainFrame.ShowDynamicTooltip(this)
                end)

                messageFrame:SetScript("OnLeave", function()
                    DifficultBulletinBoardMainFrame.HideMessageTooltip(this)
                end)

                -- Increment the Y-offset for the next placeholder
                topicYOffset = topicYOffset - 18 -- space between placeholders
            end

            -- After the placeholders, adjust the main yOffset for the next topic
            yOffset = topicYOffset - 10 -- space between topics
        end
    end
    -- Adjust content frame height to fit all entries dynamically
    local contentHeight = initialYOffset - yOffset
    contentFrame:SetHeight(contentHeight)
    -- Update scroll frame for new content height
    local scrollFrame = contentFrame:GetParent()
    if scrollFrame then
        scrollFrame:SetScrollChild(contentFrame)
        local scrollBar = getglobal(scrollFrame:GetName().."ScrollBar")
        local scrollFrameHeight = scrollFrame:GetHeight()
        local actualMaxScroll = contentHeight - scrollFrameHeight
        
        -- Ensure minimum 25px scrollable content to prevent snap behavior
        local finalHeight = contentHeight
        if actualMaxScroll < 25 then
            finalHeight = scrollFrameHeight + 25
            contentFrame:SetHeight(finalHeight)
        end
        
        local maxScroll = finalHeight - scrollFrameHeight
        if maxScroll < 0 then maxScroll = 0 end
        scrollBar:SetMinMaxValues(0, maxScroll)
        if scrollBar:GetValue() > maxScroll then scrollBar:SetValue(maxScroll) end
    end
end

-- Create scroll frame with hidden arrows and modern styling
local function createScrollFrameForMainFrame(scrollFrameName)
    -- Create the ScrollFrame
    local scrollFrame = CreateFrame("ScrollFrame", scrollFrameName, mainFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:EnableMouseWheel(true)

    -- Set ScrollFrame anchors with reduced left margin (50% less)
    -- Use 25px bottom padding for balanced spacing above filter line
    scrollFrame:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 15, -55)  
    scrollFrame:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -26, 25)  -- Changed to 25px padding
    
    -- Store original bottom point for filter toggle adjustment
    scrollFrame.originalBottomOffset = 25  -- Also update stored value
    
    -- Get the scroll bar reference
    local scrollBar = getglobal(scrollFrame:GetName().."ScrollBar")
    
    -- Get references to the scroll buttons
    local upButton = getglobal(scrollBar:GetName().."ScrollUpButton")
    local downButton = getglobal(scrollBar:GetName().."ScrollDownButton")
    
    -- Completely remove the scroll buttons from the layout
    upButton:SetHeight(0.001)
    upButton:SetWidth(0.001)
    upButton:SetAlpha(0)
    upButton:EnableMouse(false)
    upButton:ClearAllPoints()
    upButton:SetPoint("TOP", scrollBar, "TOP", 0, 1000)
    
    -- Same for down button
    downButton:SetHeight(0.001)
    downButton:SetWidth(0.001)
    downButton:SetAlpha(0)
    downButton:EnableMouse(false)
    downButton:ClearAllPoints()
    downButton:SetPoint("BOTTOM", scrollBar, "BOTTOM", 0, -1000)
    
    -- Adjust scroll bar position - changed from 16 to 8 pixels for consistency
    scrollBar:ClearAllPoints()
    scrollBar:SetPoint("TOPLEFT", scrollFrame, "TOPRIGHT", 8, 0)
    scrollBar:SetPoint("BOTTOMLEFT", scrollFrame, "BOTTOMRIGHT", 8, 0)
    
    -- Style the scroll bar to be slimmer
    scrollBar:SetWidth(8)
    
    -- Set up the thumb texture with slightly blue-tinted colors
    local thumbTexture = scrollBar:GetThumbTexture()
    thumbTexture:SetWidth(8)
    thumbTexture:SetHeight(50)
    thumbTexture:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
    thumbTexture:SetGradientAlpha("VERTICAL", 0.504, 0.504, 0.576, 0.7, 0.648, 0.648, 0.72, 0.9)
    
    -- Style the scroll bar track with darker background
    scrollBar:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = nil,
        tile = true, tileSize = 8,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    scrollBar:SetBackdropColor(0.072, 0.072, 0.108, 0.3)

    -- Create the ScrollChild (content frame)
    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetHeight(1)
    scrollChild:SetWidth(980)

    -- Attach the ScrollChild to the ScrollFrame
    scrollFrame:SetScrollChild(scrollChild)

    -- Default Hide, because the default tab shows the correct frame later
    scrollFrame:Hide()

    -- Use both mouse wheel directions for scrolling
    scrollFrame:SetScript("OnMouseWheel", function()
        local scrollBar = getglobal(this:GetName().."ScrollBar")
        local currentValue = scrollBar:GetValue()
        
        if arg1 > 0 then
            scrollBar:SetValue(currentValue - (scrollBar:GetHeight() / 2))
        else
            scrollBar:SetValue(currentValue + (scrollBar:GetHeight() / 2))
        end
    end)

    return scrollFrame, scrollChild
end

-- Function to create a search box for the Groups Logs tab
-- Places the search box next to the "Group Logs" headline with dynamic sizing
local function createGroupsLogsSearchBox()
    -- Wait until the Groups Logs scroll frame exists
    if not groupsLogsScrollFrame then
        return nil
    end
    
    -- Create a temporary font string to calculate the width of "Group Logs"
    -- with the current font size
    local tempFontString = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    tempFontString:SetFont("Fonts\\FRIZQT__.TTF", DifficultBulletinBoardVars.fontSize - 1)
    tempFontString:SetText("Group Logs")
    local headerWidth = tempFontString:GetStringWidth()
    tempFontString:Hide()
    
    -- Position settings - adjust this value to control how far to the left the search box starts
    local HEADER_TO_SEARCH_GAP = 42  -- Spacing between header text and search box (increase to move right)
    local xOffset = headerWidth + HEADER_TO_SEARCH_GAP  -- Horizontal position after header
    local yOffset = 4  -- Vertical offset for even border visibility
    
    -- Create a frame to hold the search box
    local frame = CreateFrame("Frame", "DifficultBulletinBoardMainFrame_GroupsLogs_SearchFrame", groupsLogsScrollChild)
    
    -- Position based on calculated width and maintain right edge anchoring
    frame:SetPoint("TOPLEFT", groupsLogsScrollChild, "TOPLEFT", xOffset, yOffset)
    frame:SetPoint("RIGHT", groupsLogsScrollFrame, "RIGHT", -10, 0)
    frame:SetHeight(26)
    
    -- Ensure the frame is visible above the scroll content
    frame:SetFrameLevel(groupsLogsScrollChild:GetFrameLevel() + 5)

    -- Create a backdrop for the search box - updated to match main panel style
    local searchBackdrop = {
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, 
        tileSize = 16, 
        edgeSize = 14,  -- Match main panel edge size
        insets = { left = 4, right = 4, top = 4, bottom = 4 }  -- Match main panel insets
    }

    -- Create the search box with balanced margins from container frame
    local searchBox = CreateFrame("EditBox", "DifficultBulletinBoardMainFrame_GroupsLogs_SearchBox", frame)
    searchBox:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -2)
    searchBox:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
    searchBox:SetBackdrop(searchBackdrop)
    searchBox:SetBackdropColor(0.1, 0.1, 0.1, 0.9)  -- Match main panel background color
    searchBox:SetBackdropBorderColor(0.3, 0.3, 0.3, 1.0)  -- Match main panel border color
    searchBox:SetText("")
    searchBox:SetFontObject(GameFontHighlight)
    searchBox:SetTextColor(0.8, 0.8, 0.8, 1.0)
    searchBox:SetAutoFocus(false)
    searchBox:SetJustifyH("LEFT")
    
    -- Add padding on the left side of text - adjusted for larger insets
    searchBox:SetTextInsets(6, 3, 3, 3)

    -- Add placeholder text - adjusted position for larger insets
    local placeholderText = searchBox:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    placeholderText:SetPoint("LEFT", searchBox, "LEFT", 8, 0)
    placeholderText:SetText("Filter (separate terms with commas)...")
    placeholderText:SetTextColor(0.5, 0.5, 0.5, 0.7)

    -- Track focus state with a variable
    searchBox.hasFocus = false

    -- Add placeholder handlers with updated highlight colors
    searchBox:SetScript("OnEditFocusGained", function()
        this:SetBackdropBorderColor(0.4, 0.4, 0.5, 1.0)  -- Subtle highlight that fits theme
        this.hasFocus = true
        placeholderText:Hide() -- Always hide on focus
    end)

    searchBox:SetScript("OnEditFocusLost", function()
        this:SetBackdropBorderColor(0.3, 0.3, 0.3, 1.0)  -- Back to main panel border color
        this.hasFocus = false
        -- Show placeholder only if text is empty
        if this:GetText() == "" then
            placeholderText:Show()
        end
    end)

    -- Apply filter when text changes
    searchBox:SetScript("OnTextChanged", function()
        -- Get text and convert to lowercase for case-insensitive search
        currentGroupsLogsFilter = string.lower(this:GetText() or "")
        
        -- Update placeholder visibility based on text content and our tracked focus state
        if this:GetText() == "" and not this.hasFocus then
            placeholderText:Show()
        else
            placeholderText:Hide()
        end
        
        -- Apply the filter on text change
        applyGroupsLogsFilter(currentGroupsLogsFilter)
    end)
    
    -- Add Escape key handler to clear focus and apply filter
    searchBox:SetScript("OnEscapePressed", function()
        -- Update filter before clearing focus
        currentGroupsLogsFilter = string.lower(this:GetText() or "")
        applyGroupsLogsFilter(currentGroupsLogsFilter)
        
        this:ClearFocus()
        return true -- Indicates the escape was handled
    end)
    
    -- Add Enter key handler to clear focus and apply filter
    searchBox:SetScript("OnEnterPressed", function()
        -- Update filter before clearing focus
        currentGroupsLogsFilter = string.lower(this:GetText() or "")
        applyGroupsLogsFilter(currentGroupsLogsFilter)
        
        this:ClearFocus()
        return true -- Indicates the enter was handled
    end)

    -- Initialize placeholder - assume not focused initially
    if searchBox:GetText() == "" then
        placeholderText:Show()
    else
        placeholderText:Hide()
    end
    
    -- Create spacing between filter box and content below
    -- This adds an invisible spacer below the filter box
    local spacer = groupsLogsScrollChild:CreateTexture(nil, "BACKGROUND")
    spacer:SetHeight(12) -- Adjust this value to control spacing
    spacer:SetWidth(1)
    spacer:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, -5)
    spacer:SetAlpha(0) -- Invisible spacer
    
    -- Store the frame reference
    groupsLogsSearchFrame = frame

    return frame
end

-- Create a horizontal line button that toggles the keyword filter
local function createKeywordFilterLine()
    -- Match Groups Logs search height for consistency
    local SEARCH_BOX_HEIGHT = 22  -- Same as Groups Logs search box
    
    -- Store the original height of the main frame for positioning
    local originalHeight = mainFrame:GetHeight()
    mainFrame.originalHeight = originalHeight
    
    -- Create the line button with bottom anchor
    local line = CreateFrame("Button", "DifficultBulletinBoardMainFrameKeywordLine", mainFrame)
    line:SetHeight(16)
    
    -- Use bottom anchor for stable positioning
    line:SetPoint("BOTTOMLEFT", mainFrame, "BOTTOMLEFT", 15, KEYWORD_FILTER_BOTTOM_MARGIN)
    line:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -26, KEYWORD_FILTER_BOTTOM_MARGIN)
    
    -- Add text label in the center of the line
    local text = line:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetPoint("CENTER", line, "CENTER", 0, 0) -- Position text at center
    text:SetText("Keyword Blacklist")
    text:SetTextColor(0.8, 0.8, 0.8, 1.0)
    
    -- Get text width to position the line segments properly
    local textWidth = text:GetStringWidth()
    local padding = 10 -- Space between text and lines
    
    -- Line inset to match input box width with border
    local LINE_INSET = 2  -- Pixels to inset lines from edges of button
    
    -- Create the left line texture with inset from button edge
    local leftLineTexture = line:CreateTexture(nil, "BACKGROUND")
    leftLineTexture:SetHeight(1)
    leftLineTexture:SetPoint("LEFT", line, "LEFT", LINE_INSET, 0)  -- Start LINE_INSET pixels from left edge
    leftLineTexture:SetPoint("RIGHT", text, "LEFT", -padding, 0)   -- End left of text with padding
    leftLineTexture:SetTexture(1, 1, 1, 0.3)
    
    -- Create the right line texture with inset from button edge
    local rightLineTexture = line:CreateTexture(nil, "BACKGROUND")
    rightLineTexture:SetHeight(1)
    rightLineTexture:SetPoint("LEFT", text, "RIGHT", padding, 0)    -- Start right of text with padding
    rightLineTexture:SetPoint("RIGHT", line, "RIGHT", -LINE_INSET, 0)  -- End LINE_INSET pixels from right edge
    rightLineTexture:SetTexture(1, 1, 1, 0.3)
    
    -- Add hover effect for both lines and text
    line:SetScript("OnEnter", function()
        leftLineTexture:SetTexture(0.9, 0.9, 1.0, 0.5)
        rightLineTexture:SetTexture(0.9, 0.9, 1.0, 0.5)
        text:SetTextColor(0.9, 0.9, 1.0, 1.0)
    end)
    
    line:SetScript("OnLeave", function()
        leftLineTexture:SetTexture(1, 1, 1, 0.3)
        rightLineTexture:SetTexture(1, 1, 1, 0.3)
        text:SetTextColor(0.8, 0.8, 0.8, 1.0)
    end)
    
    -- Create the input box positioned below the line
    local input = CreateFrame("EditBox", "DifficultBulletinBoardMainFrameKeywordInput", mainFrame)
    input:SetHeight(SEARCH_BOX_HEIGHT)
    
    -- Position input directly below the line
    input:SetPoint("TOPLEFT", line, "BOTTOMLEFT", 0, -4)
    input:SetPoint("TOPRIGHT", line, "BOTTOMRIGHT", 0, -4)
    
    -- Style the input box backdrop to match main panel
    local mainPanelBackdrop = {
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, 
        tileSize = 16, 
        edgeSize = 14,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    }
    
    input:SetBackdrop(mainPanelBackdrop)
    input:SetBackdropColor(0.1, 0.1, 0.1, 0.9)  -- Match main panel background color
    input:SetBackdropBorderColor(0.3, 0.3, 0.3, 1.0)  -- Match main panel border color
    
    input:SetFontObject(GameFontHighlight)
    input:SetTextColor(0.8, 0.8, 0.8, 1.0)
    input:SetAutoFocus(false)
    input:SetJustifyH("LEFT")
    input:SetTextInsets(6, 3, 3, 3)  -- Adjusted insets for larger border
    
    -- Add placeholder text with matching style
    local placeholderText = input:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    placeholderText:SetPoint("LEFT", input, "LEFT", 8, 0)  -- Adjusted left position for larger insets
    placeholderText:SetText("Filter (separate terms with commas)...")
    placeholderText:SetTextColor(0.5, 0.5, 0.5, 0.7)
    
    -- Track focus state
    input.hasFocus = false
    
    -- Load saved keywords
    if DifficultBulletinBoardSavedVariables and DifficultBulletinBoardSavedVariables.keywordBlacklist then
        input:SetText(DifficultBulletinBoardSavedVariables.keywordBlacklist)
        -- Hide placeholder if there's text
        if input:GetText() ~= "" then
            placeholderText:Hide()
        end
    else
        input:SetText("")
    end
    
	-- Handle text changes
	input:SetScript("OnTextChanged", function()
		local text = this:GetText()
		if DifficultBulletinBoardSavedVariables then
			DifficultBulletinBoardSavedVariables.keywordBlacklist = text
		end
		
		-- Update placeholder visibility
		if this:GetText() == "" and not this.hasFocus then
			placeholderText:Show()
		else
			placeholderText:Hide()
		end
	end)
    
    -- Handle focus with subtle highlight effect matching main panel theme
    input:SetScript("OnEditFocusGained", function()
        this:SetBackdropBorderColor(0.4, 0.4, 0.5, 1.0)  -- Subtle highlight that fits theme
        this.hasFocus = true
        placeholderText:Hide()  -- Always hide on focus
    end)
    
    input:SetScript("OnEditFocusLost", function()
        this:SetBackdropBorderColor(0.3, 0.3, 0.3, 1.0)  -- Back to main panel border color
        this.hasFocus = false
        -- Show placeholder only if text is empty
        if this:GetText() == "" then
            placeholderText:Show()
        end
    end)
    
    -- Handle enter and escape keys
    input:SetScript("OnEnterPressed", function()
        this:ClearFocus()
    end)
    
    input:SetScript("OnEscapePressed", function()
        this:ClearFocus()
    end)
    
    -- Create function to update scroll frames based on filter visibility
    local function updateScrollFramePositions()
        local originalBottomOffset = 25
        local newBottomOffset = 25 + KEYWORD_FILTER_HEIGHT + 8
        
        -- Update all scroll frames
        local scrollFrames = {groupScrollFrame, groupsLogsScrollFrame, 
                             professionScrollFrame, hardcoreScrollFrame}
        
        for _, scrollFrame in ipairs(scrollFrames) do
            if scrollFrame then
                scrollFrame:ClearAllPoints()
                scrollFrame:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 15, -55)
                scrollFrame:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -26,
                    keywordFilterVisible and newBottomOffset or originalBottomOffset)
            end
        end
    end
    
    -- Define a function to fully reset the keyword filter state
    local function resetKeywordFilterState()
        -- Hide the input
        input:Hide()
        -- Reset tracking variable
        keywordFilterVisible = false
        -- Reset frame height to original
        mainFrame:SetHeight(mainFrame.originalHeight)
        -- Reset scroll positions
        updateScrollFramePositions()
    end
    
    -- Get original OnHide handler to preserve existing behavior
    local originalOnHide = mainFrame:GetScript("OnHide")
    
    -- Set OnHide handler to reset keyword filter state
    mainFrame:SetScript("OnHide", function()
        -- Call our reset function
        resetKeywordFilterState()
        
        -- Call original handler if it exists
        if originalOnHide then
            originalOnHide()
        end
    end)
    
    -- Toggle filter visibility when clicking the line
    line:SetScript("OnClick", function()
        DifficultBulletinBoard_ToggleKeywordFilter()
    end)
    
    -- Store references
    keywordFilterInput = input
    keywordFilterLine = line
    
    -- Hide input initially (starts collapsed)
    input:Hide()
    
    return line
end

-- Function to toggle the keyword filter visibility by expanding/collapsing the main frame
function DifficultBulletinBoard_ToggleKeywordFilter()
    if not keywordFilterInput then
        return
    end
    
    keywordFilterVisible = not keywordFilterVisible
    
    if keywordFilterVisible then
        -- Calculate the amount to expand the frame
        local expandAmount = KEYWORD_FILTER_HEIGHT + 4 -- Input height + gap
        
        -- Adjust the line position before expanding the frame
        keywordFilterLine:ClearAllPoints()
        keywordFilterLine:SetPoint("BOTTOMLEFT", mainFrame, "BOTTOMLEFT", 15, KEYWORD_FILTER_BOTTOM_MARGIN + expandAmount)
        keywordFilterLine:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -26, KEYWORD_FILTER_BOTTOM_MARGIN + expandAmount)
        
        -- Now expand the frame
        mainFrame:SetHeight(mainFrame.originalHeight + expandAmount)
        
        -- Show the input
        keywordFilterInput:Show()
        
        -- Adjust all scroll frames to avoid content appearing under the filter
        local newBottomOffset = 25 + KEYWORD_FILTER_HEIGHT + 4
        if groupScrollFrame then
            groupScrollFrame:ClearAllPoints()
            groupScrollFrame:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 15, -55)
            groupScrollFrame:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -26, newBottomOffset)
        end
        if groupsLogsScrollFrame then
            groupsLogsScrollFrame:ClearAllPoints()
            groupsLogsScrollFrame:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 15, -55)
            groupsLogsScrollFrame:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -26, newBottomOffset)
        end
        if professionScrollFrame then
            professionScrollFrame:ClearAllPoints()
            professionScrollFrame:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 15, -55)
            professionScrollFrame:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -26, newBottomOffset)
        end
        if hardcoreScrollFrame then
            hardcoreScrollFrame:ClearAllPoints()
            hardcoreScrollFrame:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 15, -55)
            hardcoreScrollFrame:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -26, newBottomOffset)
        end
    else
        -- Hide the input first
        keywordFilterInput:Hide()
        
        -- Adjust the line position before collapsing the frame
        keywordFilterLine:ClearAllPoints()
        keywordFilterLine:SetPoint("BOTTOMLEFT", mainFrame, "BOTTOMLEFT", 15, KEYWORD_FILTER_BOTTOM_MARGIN)
        keywordFilterLine:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -26, KEYWORD_FILTER_BOTTOM_MARGIN)
        
        -- Restore the main frame to original height
        mainFrame:SetHeight(mainFrame.originalHeight)
        
        -- Restore original scroll frame positions
        local originalBottomOffset = 25
        if groupScrollFrame then
            groupScrollFrame:ClearAllPoints()
            groupScrollFrame:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 15, -55)
            groupScrollFrame:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -26, originalBottomOffset)
        end
        if groupsLogsScrollFrame then
            groupsLogsScrollFrame:ClearAllPoints()
            groupsLogsScrollFrame:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 15, -55)
            groupsLogsScrollFrame:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -26, originalBottomOffset)
        end
        if professionScrollFrame then
            professionScrollFrame:ClearAllPoints()
            professionScrollFrame:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 15, -55)
            professionScrollFrame:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -26, originalBottomOffset)
        end
        if hardcoreScrollFrame then
            hardcoreScrollFrame:ClearAllPoints()
            hardcoreScrollFrame:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 15, -55)
            hardcoreScrollFrame:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -26, originalBottomOffset)
        end
    end
end

-- Function to update button widths based on frame size
local function updateButtonWidths()
    -- Safety check for buttons
    if not groupsButton or not groupsLogsButton or not professionsButton or not hcMessagesButton then
        return
    end
    
    local buttons = {
        groupsButton, 
        groupsLogsButton, 
        professionsButton, 
        hcMessagesButton
    }
    
    -- Get button text widths to calculate minimum required widths
    local textWidths = {}
    local totalTextWidth = 0
    local buttonCount = NUM_BUTTONS
    
    -- Check all buttons have text elements and get their widths
    for i = 1, buttonCount do
        local button = buttons[i]
        if not button:GetName() then
            return
        end
        
        local textObjName = button:GetName() .. "_Text"
        local textObj = getglobal(textObjName)
        
        if not textObj then
            return
        end
        
        local textWidth = textObj:GetStringWidth()
        if not textWidth then
            return
        end
        
        textWidths[i] = textWidth
        totalTextWidth = totalTextWidth + textWidth
    end
    
    -- Calculate minimum padded widths for each button (text + minimum padding)
    local minButtonWidths = {}
    for i = 1, buttonCount do
        minButtonWidths[i] = textWidths[i] + (2 * MIN_TEXT_PADDING)
    end
    
    -- Find the button that needs the most minimum width
    local maxMinWidth = 0
    for i = 1, buttonCount do
        if minButtonWidths[i] > maxMinWidth then
            maxMinWidth = minButtonWidths[i]
        end
    end
    
    -- Calculate total content width if all buttons had the same width (maxMinWidth)
    -- This ensures all buttons have at least minimum padding
    local totalEqualContentWidth = maxMinWidth * buttonCount
    
    -- Add spacing to total minimum width
    local totalMinFrameWidth = totalEqualContentWidth + ((NUM_BUTTONS - 1) * BUTTON_SPACING) + (2 * SIDE_PADDING)
    
    -- Get current frame width
    local frameWidth = mainFrame:GetWidth()
    
    -- Set the minimum resizable width of the frame directly
    -- This prevents the user from dragging it smaller than the minimum width
    mainFrame:SetMinResize(totalMinFrameWidth, 300)
    
    -- If frame is somehow smaller than minimum (should not happen), force a resize
    if frameWidth < totalMinFrameWidth then
        mainFrame:SetWidth(totalMinFrameWidth)
        frameWidth = totalMinFrameWidth
    end
    
    -- Calculate available width for buttons
    local availableWidth = frameWidth - (2 * SIDE_PADDING) - ((NUM_BUTTONS - 1) * BUTTON_SPACING)
    
    -- Calculate equal width distribution
    local equalWidth = availableWidth / NUM_BUTTONS
    
    -- Always try to use equal widths first
    if equalWidth >= maxMinWidth then
        -- We can use equal widths for all buttons
        for i = 1, buttonCount do
            buttons[i]:SetWidth(equalWidth)
        end
    else
        -- We can't use equal widths because some text would have less than minimum padding
        -- Set all buttons to the maximum minimum width to ensure all have same width
        -- unless that would mean having less than minimum padding
        for i = 1, buttonCount do
            buttons[i]:SetWidth(maxMinWidth)
        end
    end
end

function DifficultBulletinBoardMainFrame.InitializeMainFrame()
    DifficultBulletinBoardMainFrame.UpdateServerTime()

    -- Initialize the message processor with references to our placeholders
    if DifficultBulletinBoardMessageProcessor and DifficultBulletinBoardMessageProcessor.Initialize then
        DifficultBulletinBoardMessageProcessor.Initialize({
            groupTopicPlaceholders = groupTopicPlaceholders,
            groupsLogsPlaceholders = groupsLogsPlaceholders,
            professionTopicPlaceholders = professionTopicPlaceholders,
            hardcoreTopicPlaceholders = hardcoreTopicPlaceholders
        }, currentGroupsLogsFilter, MAX_GROUPS_LOGS_ENTRIES, {
            RepackEntries = RepackEntries,
            ReflowTopicEntries = ReflowTopicEntries
        })
    end

    -- Create scroll frame for Groups tab
    groupScrollFrame, groupScrollChild = createScrollFrameForMainFrame("DifficultBulletinBoardMainFrame_Group_ScrollFrame")
    createTopicListWithNameMessageDateColumns(groupScrollChild, DifficultBulletinBoardVars.allGroupTopics, groupTopicPlaceholders, DifficultBulletinBoardVars.numberOfGroupPlaceholders)
    -- Initial dynamic reflow for Groups tab and immediate scroll range update
    DifficultBulletinBoardMainFrame.ReflowGroupsTab()

    -- Create the Groups Logs scroll frame using the same function as other tabs
    groupsLogsScrollFrame, groupsLogsScrollChild = createScrollFrameForMainFrame("DifficultBulletinBoardMainFrame_GroupsLogs_ScrollFrame")
    -- Use the same function to create content as for group topics
    createTopicListWithNameMessageDateColumns(groupsLogsScrollChild, {{name = "Group Logs", selected = true, tags = {}}}, groupsLogsPlaceholders, MAX_GROUPS_LOGS_ENTRIES)
    
    -- Hide all Groups Logs placeholders initially since they start empty and update scroll range
    if groupsLogsPlaceholders["Group Logs"] then
        for _, entry in ipairs(groupsLogsPlaceholders["Group Logs"]) do
            if entry.nameButton then entry.nameButton:Hide() end
            if entry.messageFontString then entry.messageFontString:Hide() end
            if entry.timeFontString then entry.timeFontString:Hide() end
            if entry.icon then entry.icon:Hide() end
        end
        -- Force immediate scroll range update after hiding placeholders
        groupsLogsScrollChild:SetHeight(50) -- Set minimal height for Groups Logs
        local scrollBar = getglobal(groupsLogsScrollFrame:GetName().."ScrollBar")
        local scrollFrameHeight = groupsLogsScrollFrame:GetHeight()
        local finalHeight = scrollFrameHeight + 25 -- Always ensure 25px scrollable
        groupsLogsScrollChild:SetHeight(finalHeight)
        local maxScroll = 25 -- Always 25px scrollable for Groups Logs
        scrollBar:SetMinMaxValues(0, maxScroll)
        scrollBar:SetValue(0)
    end
    
    professionScrollFrame, professionScrollChild = createScrollFrameForMainFrame("DifficultBulletinBoardMainFrame_Profession_ScrollFrame")
    createTopicListWithNameMessageDateColumns(professionScrollChild, DifficultBulletinBoardVars.allProfessionTopics, professionTopicPlaceholders, DifficultBulletinBoardVars.numberOfProfessionPlaceholders)
    -- Initial dynamic reflow for Professions tab and immediate scroll range update
    DifficultBulletinBoardMainFrame.ReflowProfessionsTab()
    -- Force immediate scroll range update for professions tab to prevent excessive scrolling on login
    if professionScrollFrame and professionScrollChild then
        local scrollBar = getglobal(professionScrollFrame:GetName().."ScrollBar")
        local scrollFrameHeight = professionScrollFrame:GetHeight()
        local contentHeight = professionScrollChild:GetHeight()
        local actualMaxScroll = contentHeight - scrollFrameHeight
        
        -- Ensure minimum 25px scrollable content to prevent snap behavior
        local finalHeight = contentHeight
        if actualMaxScroll < 25 then
            finalHeight = scrollFrameHeight + 25
            professionScrollChild:SetHeight(finalHeight)
        end
        
        local maxScroll = finalHeight - scrollFrameHeight
        if maxScroll < 0 then maxScroll = 0 end
        scrollBar:SetMinMaxValues(0, maxScroll)
        scrollBar:SetValue(0)
    end
    
    hardcoreScrollFrame, hardcoreScrollChild = createScrollFrameForMainFrame("DifficultBulletinBoardMainFrame_Hardcore_ScrollFrame")
    createTopicListWithMessageDateColumns(hardcoreScrollChild, DifficultBulletinBoardVars.allHardcoreTopics, hardcoreTopicPlaceholders, DifficultBulletinBoardVars.numberOfHardcorePlaceholders)
    -- Initial dynamic reflow for Hardcore tab and immediate scroll range update
    DifficultBulletinBoardMainFrame.ReflowHardcoreTab()

    -- Add topic group tab switching
    configureTabSwitching()
    
    -- Create the search box after all scroll frames are created
    createGroupsLogsSearchBox()
    
    -- Create the keyword filter components
    createKeywordFilterLine()
    
    -- Initialize filter state
    keywordFilterVisible = false
    
    -- Initialize button widths based on current frame size
    updateButtonWidths()
 end

-- Resize handler - Updates frame widths and keyword filter positioning when main frame is resized
mainFrame:SetScript("OnSizeChanged", function()
    -- Update chat message frames and columns width
    local chatMessageWidth = mainFrame:GetWidth() - chatMessageWidthDelta
    
    -- Add type checking for tempChatMessageFrames
    if tempChatMessageFrames and type(tempChatMessageFrames) == "table" then
        for _, msgFrame in ipairs(tempChatMessageFrames) do
            if msgFrame and type(msgFrame.SetWidth) == "function" then
                msgFrame:SetWidth(chatMessageWidth)
            end
        end
    end

    -- Add type checking for tempChatMessageColumns
    if tempChatMessageColumns and type(tempChatMessageColumns) == "table" then
        for _, msgColumn in ipairs(tempChatMessageColumns) do
            if msgColumn and type(msgColumn.SetWidth) == "function" then
                msgColumn:SetWidth(chatMessageWidth)
            end
        end
    end

    -- Update system message frames and columns width
    local systemMessageWidth = mainFrame:GetWidth() - systemMessageWidthDelta
    
    -- Add type checking for tempSystemMessageFrames
    if tempSystemMessageFrames and type(tempSystemMessageFrames) == "table" then
        for _, msgFrame in ipairs(tempSystemMessageFrames) do
            if msgFrame and type(msgFrame.SetWidth) == "function" then
                msgFrame:SetWidth(systemMessageWidth)
            end
        end
    end

    -- Add type checking for tempSystemMessageColumns
    if tempSystemMessageColumns and type(tempSystemMessageColumns) == "table" then
        for _, msgColumn in ipairs(tempSystemMessageColumns) do
            if msgColumn and type(msgColumn.SetWidth) == "function" then
                msgColumn:SetWidth(systemMessageWidth)
            end
        end
    end
    
    -- Update keyword filter components
    if keywordFilterLine then
        local currentHeight = mainFrame:GetHeight()
        
        if not keywordFilterVisible then
            -- When collapsed: update originalHeight and maintain line at bottom
            mainFrame.originalHeight = currentHeight
            keywordFilterLine:ClearAllPoints()
            keywordFilterLine:SetPoint("BOTTOMLEFT", mainFrame, "BOTTOMLEFT", 15, KEYWORD_FILTER_BOTTOM_MARGIN)
            keywordFilterLine:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -26, KEYWORD_FILTER_BOTTOM_MARGIN)
        else
            -- When expanded: maintain line at proper distance from bottom
            local expandAmount = KEYWORD_FILTER_HEIGHT + 4
            keywordFilterLine:ClearAllPoints()
            keywordFilterLine:SetPoint("BOTTOMLEFT", mainFrame, "BOTTOMLEFT", 15, KEYWORD_FILTER_BOTTOM_MARGIN + expandAmount)
            keywordFilterLine:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -26, KEYWORD_FILTER_BOTTOM_MARGIN + expandAmount)
            
            -- Update the input position to follow the line
            if keywordFilterInput then
                keywordFilterInput:ClearAllPoints()
                keywordFilterInput:SetPoint("TOPLEFT", keywordFilterLine, "BOTTOMLEFT", 0, -4)
                keywordFilterInput:SetPoint("TOPRIGHT", keywordFilterLine, "BOTTOMRIGHT", 0, -4)
            end
        end
    end
    
    -- Update button widths - now handled intelligently based on available space
    updateButtonWidths()
end)

-- Hide handler - Resets keyword filter when main frame is closed
mainFrame:SetScript("OnHide", function()
    -- Reset keyword filter state when main frame is hidden
    if keywordFilterVisible then
        keywordFilterVisible = false
        keywordFilterInput:Hide()
        
        -- Only reset height if we've stored the original height
        if mainFrame.originalHeight then
            mainFrame:SetHeight(mainFrame.originalHeight)
        end
    end
end)

function DifficultBulletinBoardMainFrame.UpdateServerTime()
    if DifficultBulletinBoardVars.serverTimePosition == "disabled" then
        return
    end

    local serverTimeString = date("%H:%M:%S") -- Format server time

    if DifficultBulletinBoardVars.serverTimePosition == "right-of-tabs" then
        DifficultBulletinBoardMainFrameServerTimeRight:SetText("Time: " .. serverTimeString)
    end

    if DifficultBulletinBoardVars.serverTimePosition == "top-left" then
        DifficultBulletinBoardMainFrameServerTimeTopLeft:SetText("Time: " .. serverTimeString)
    end
end



-- Modified to also update times in the Groups Logs tab - delegates to message processor
function DifficultBulletinBoardMainFrame.UpdateElapsedTimes()
    if DifficultBulletinBoardMessageProcessor and DifficultBulletinBoardMessageProcessor.UpdateElapsedTimes then
        DifficultBulletinBoardMessageProcessor.UpdateElapsedTimes()
    end
end

-- Initialize with the current server time
mainFrame:RegisterEvent("ADDON_LOADED")
mainFrame:RegisterEvent("CHAT_MSG_CHANNEL")
mainFrame:RegisterEvent("CHAT_MSG_HARDCORE")
mainFrame:RegisterEvent("CHAT_MSG_SYSTEM")



-- Helper to reflow entries and remove blank gaps (supports optional nameButton/icon)
local function RepackEntries(entries)
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
            if entry.nameButton and data.name and type(entry.nameButton.SetText) == "function" and type(entry.nameButton.Show) == "function" then
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
            if entry.nameButton and type(entry.nameButton.SetText) == "function" and type(entry.nameButton.Show) == "function" then
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
local function ReflowTopicEntries(entries)
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

-- Function to expire messages older than specified seconds - delegates to message processor
function DifficultBulletinBoard.ExpireMessages(seconds)
    if DifficultBulletinBoardMessageProcessor and DifficultBulletinBoardMessageProcessor.ExpireMessages then
        DifficultBulletinBoardMessageProcessor.ExpireMessages(seconds)
        
        -- After expiring messages, reflow all tabs to collapse gaps
        DifficultBulletinBoardMainFrame.ReflowGroupsTab()
        DifficultBulletinBoardMainFrame.ReflowProfessionsTab()
        DifficultBulletinBoardMainFrame.ReflowHardcoreTab()
        
        -- Reapply Groups Logs filter after expiration and reflow
        if DifficultBulletinBoardMessageProcessor and DifficultBulletinBoardMessageProcessor.ApplyGroupsLogsFilter then
            local currentFilter = ""
            if DifficultBulletinBoardMainFrame and DifficultBulletinBoardMainFrame.GetCurrentGroupsLogsFilter then
                currentFilter = DifficultBulletinBoardMainFrame.GetCurrentGroupsLogsFilter()
            end
            DifficultBulletinBoardMessageProcessor.ApplyGroupsLogsFilter(currentFilter)
        end
    end
end









-- FIRST_EDIT: expose on mainFrame
DifficultBulletinBoardMainFrame.RepackEntries = RepackEntries
DifficultBulletinBoardMainFrame.ReflowTopicEntries = ReflowTopicEntries

-- Public API: recalc all scroll ranges manually
function DifficultBulletinBoardMainFrame.RefreshAllScrollRanges()
    local scrollPairs = {
        {sf=groupScrollFrame, sc=groupScrollChild},
        {sf=groupsLogsScrollFrame, sc=groupsLogsScrollChild},
        {sf=professionScrollFrame, sc=professionScrollChild},
        {sf=hardcoreScrollFrame, sc=hardcoreScrollChild},
    }
    for _, info in ipairs(scrollPairs) do
        if info.sf and info.sc then
            local sb = getglobal(info.sf:GetName().."ScrollBar")
            local scrollFrameHeight = info.sf:GetHeight()
            local contentHeight = info.sc:GetHeight()
            local actualMaxScroll = contentHeight - scrollFrameHeight
            
            -- Ensure minimum 25px scrollable content to prevent snap behavior
            local finalHeight = contentHeight
            if actualMaxScroll < 25 then
                finalHeight = scrollFrameHeight + 25
                info.sc:SetHeight(finalHeight)
            end
            
            local maxScroll = finalHeight - scrollFrameHeight
            if maxScroll < 0 then maxScroll = 0 end
            sb:SetMinMaxValues(0, maxScroll)
            if sb:GetValue() > maxScroll then sb:SetValue(maxScroll) end
        end
    end
end
