local addonName = "SynastriaBuildManager"
local SBM = {}

-- Track if we've already added the build manager button
local buildManagerButtonAdded = false

-- Queue system
local actionQueue = {}
local queueFrame = CreateFrame("Frame")
local queueTimer = 0
local isProcessing = false

-- Queue action types
local ActionTypes = {
    CLICK_PERK = "click_perk",
    CLICK_TOGGLE = "click_toggle",
    DELAY = "delay",
    COMPLETE = "complete"
}

-- Add action to queue
local function QueueAction(actionType, data)
    table.insert(actionQueue, {
        type = actionType,
        data = data or {}
    })
end

-- Process the action queue
local function ProcessQueue(self, elapsed)
    -- Process multiple actions per frame if possible
    while #actionQueue > 0 do
        local action = actionQueue[1]
        
        if action.type == ActionTypes.DELAY then
            queueTimer = queueTimer + elapsed
            if queueTimer >= action.data.duration then
                table.remove(actionQueue, 1)
                queueTimer = 0
                -- Don't return - continue to next action
            else
                -- Delay not finished, exit and wait for next frame
                return
            end
        else
            -- Process non-delay action immediately
            table.remove(actionQueue, 1)
            
            if action.type == ActionTypes.CLICK_PERK then
                local frameName = "PerkMgrFrame-PerkLine-" .. action.data.position
                local perkFrame = getglobal(frameName)
                if perkFrame then
                    perkFrame:Click()
                end
            elseif action.type == ActionTypes.CLICK_TOGGLE then
                local toggleButton = getglobal("PerkMgrFrame-Toggle")
                if toggleButton then
                    toggleButton:Click()
                end
            elseif action.type == ActionTypes.COMPLETE then
                print("Perk import completed! Made " .. action.data.changeCount .. " changes.")
            end
        end
    end
    
    -- Queue is empty, stop processing
    queueFrame:SetScript("OnUpdate", nil)
    isProcessing = false
end

-- Start processing the queue
local function StartQueue()
    if isProcessing then
        return
    end
    
    isProcessing = true
    queueTimer = 0
    queueFrame:SetScript("OnUpdate", ProcessQueue)
end

-- Clear the queue
local function ClearQueue()
    actionQueue = {}
    queueFrame:SetScript("OnUpdate", nil)
    isProcessing = false
    queueTimer = 0
end

-- Helper function to get all perk data
function GetAllPerks()
    local perks = {}
    local perkContainer = select(7, PerkMgrFrame:GetChildren())
    if not perkContainer then
        return perks
    end
    
    local perkList = select(2, perkContainer:GetChildren())
    if not perkList then
        return perks
    end
    
    local children = {perkList:GetChildren()}
    
    -- Find the starting index by looking for PerkMgrFrame-PerkLine-1
    local startIndex = nil
    for i = 1, #children do
        local child = children[i]
        if child and child:GetName() == "PerkMgrFrame-PerkLine-1" then
            startIndex = i
            break
        end
    end
    
    if not startIndex then
        return perks
    end
    
    -- Iterate through all perk frames starting from the found index
    for i = startIndex, #children do
        local perkFrame = children[i]
        if perkFrame and perkFrame.perk and perkFrame.perk.id then
            local perkId = perkFrame.perk.id
            
            -- Stop if we hit perk ID 1042 (don't include it or anything after)
            if perkId == 1042 then
                break
            end
            
            local isActive = GetPerkActive(perkId)
            table.insert(perks, {
                id = perkId,
                active = isActive and true or false,
                position = i - startIndex + 1 -- Convert to 1-based position relative to first perk
            })
        else
            -- If we hit a frame without perk data, we've probably reached the end
            break
        end
    end
    
    return perks
end

-- Import function with queue system
function SBM.ImportPerks(importString)
    if not importString or importString == "" then
        print("Please provide a valid import string.")
        return
    end
    
    -- Clear any existing queue
    ClearQueue()
    
    -- Parse import string
    local targetPerkIds = {}
    for perkId in string.gmatch(importString, "([^,]+)") do
        local id = tonumber(perkId)
        if id then
            targetPerkIds[id] = true
        end
    end
    
    if next(targetPerkIds) == nil then
        print("No valid perk IDs found in import string.")
        return
    end
    
    local perks = GetAllPerks()
    local deactivateList = {}
    local activateList = {}
    
    -- Separate perks into deactivate and activate lists
    for _, perk in ipairs(perks) do
        local shouldBeActive = targetPerkIds[perk.id] and true or false
        
        if perk.active and not shouldBeActive then
            -- Currently active but should be inactive - add to deactivate list
            table.insert(deactivateList, {
                id = perk.id,
                position = perk.position,
                action = "deactivate"
            })
        elseif not perk.active and shouldBeActive then
            -- Currently inactive but should be active - add to activate list
            table.insert(activateList, {
                id = perk.id,
                position = perk.position,
                action = "activate"
            })
        end
    end
    
    -- Combine lists: deactivate first, then activate
    local allChanges = {}
    for _, change in ipairs(deactivateList) do
        table.insert(allChanges, change)
    end
    for _, change in ipairs(activateList) do
        table.insert(allChanges, change)
    end
    
    if #allChanges == 0 then
        print("Perks are already configured correctly.")
        return
    end
    
    -- Build the action queue
    for _, change in ipairs(allChanges) do
        QueueAction(ActionTypes.CLICK_PERK, {position = change.position})
        QueueAction(ActionTypes.DELAY, {duration = 0.01})
        QueueAction(ActionTypes.CLICK_TOGGLE, {})
        QueueAction(ActionTypes.DELAY, {duration = 0.01})
    end
    
    -- Add completion message
    QueueAction(ActionTypes.COMPLETE, {changeCount = #allChanges})
    
    -- Start processing the queue
    StartQueue()
end

-- Create Build Manager interface
local buildManagerFrame = nil

local function CreateBuildManagerFrame()
    if buildManagerFrame then
        return buildManagerFrame
    end
    
    -- Main frame
    buildManagerFrame = CreateFrame("Frame", "SBM_BuildManagerFrame", UIParent)
    buildManagerFrame:SetSize(350, 160)
    buildManagerFrame:SetPoint("CENTER")
    buildManagerFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    buildManagerFrame:SetBackdropColor(0, 0, 0, 1)
    buildManagerFrame:Hide()
    buildManagerFrame:SetFrameStrata("DIALOG")
    
    -- Make it movable
    buildManagerFrame:SetMovable(true)
    buildManagerFrame:EnableMouse(true)
    buildManagerFrame:RegisterForDrag("LeftButton")
    buildManagerFrame:SetScript("OnDragStart", buildManagerFrame.StartMoving)
    buildManagerFrame:SetScript("OnDragStop", buildManagerFrame.StopMovingOrSizing)
    
    -- Title
    local title = buildManagerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -15)
    title:SetText("Build Manager")
    
    -- Export button
    local exportBtn = CreateFrame("Button", nil, buildManagerFrame, "UIPanelButtonTemplate")
    exportBtn:SetSize(70, 22)
    exportBtn:SetPoint("BOTTOMLEFT", 25, 15)
    exportBtn:SetText("Export")
    exportBtn:SetScript("OnClick", function()
        local exportLines = {}
        
        -- Get perk export
        local perks = GetAllPerks()
        local activePerks = {}
        
        for _, perk in ipairs(perks) do
            if perk.active then
                table.insert(activePerks, perk.id)
            end
        end
        
        if #activePerks > 0 then
            table.insert(exportLines, table.concat(activePerks, ","))
        else
            table.insert(exportLines, "")  -- Empty line for no perks
        end
        
        -- Get talent export
        local talentExport = ExportDualClassTalents()
        if talentExport and talentExport ~= "" then
            -- Split talent export by newlines and add each line
            for line in talentExport:gmatch("[^\n]+") do
                table.insert(exportLines, line)
            end
        else
            -- Add empty talent lines if no talents
            table.insert(exportLines, "")
        end
        
        -- Combine all lines with newlines
        local finalExport = table.concat(exportLines, "\n")
        
        -- Populate the text box
        buildManagerFrame.editBox:SetText(finalExport)
        buildManagerFrame.editBox:SetFocus()
        buildManagerFrame.editBox:HighlightText()
    end)
    
    -- Import button
    local importBtn = CreateFrame("Button", nil, buildManagerFrame, "UIPanelButtonTemplate")
    importBtn:SetSize(70, 22)
    importBtn:SetPoint("BOTTOM", 0, 15)
    importBtn:SetText("Import")
    importBtn:SetScript("OnClick", function()
        local importText = buildManagerFrame.editBox:GetText()
        
        if not importText or importText == "" then
            print("Please paste a build string into the text box first.")
            return
        end
        
        -- Split the import text into lines and remove whitespace
        local lines = {}
        for line in importText:gmatch("[^\r\n]+") do
            local cleanLine = line:gsub("^%s*(.-)%s*$", "%1") -- Remove leading/trailing whitespace
            if cleanLine ~= "" then
                table.insert(lines, cleanLine)
            end
        end
        
        if #lines == 0 then
            print("No valid build data found.")
            return
        end
        
        -- First line should be perks (comma-separated numbers)
        local perkLine = lines[1]
        local hasPerkData = perkLine and perkLine:match("^[0-9,]+$")
        
        -- Import perks if we have perk data (this will print its own message with change count)
        if hasPerkData and perkLine ~= "" then
            SBM.ImportPerks(perkLine)
        end
        
        -- Remaining lines should be talent data (Class:talents format)
        local talentLines = {}
        local startIndex = hasPerkData and 2 or 1
        
        for i = startIndex, #lines do
            local line = lines[i]
            if line:match("^[^:]+:.+") then -- Format: ClassName:talentdata
                table.insert(talentLines, line)
            end
        end
        
        -- Import talents if we have talent data
        if #talentLines > 0 then
            local talentImportString = table.concat(talentLines, "\n")
            
            local success = ImportDualClassTalents(talentImportString)
            if success then
                print("Talents imported successfully!")
            else
                print("Failed to import talents. Make sure the format is correct.")
            end
        end
    end)
    
    -- Close button
    local closeBtn = CreateFrame("Button", nil, buildManagerFrame, "UIPanelButtonTemplate")
    closeBtn:SetSize(70, 22)
    closeBtn:SetPoint("BOTTOMRIGHT", -25, 15)
    closeBtn:SetText("Close")
    closeBtn:SetScript("OnClick", function()
        buildManagerFrame:Hide()
    end)
    
    -- Multi-line text area using ScrollFrame
    local scrollFrame = CreateFrame("ScrollFrame", nil, buildManagerFrame)
    scrollFrame:SetSize(300, 60)
    scrollFrame:SetPoint("TOP", title, "BOTTOM", 0, -15)
    
    local editBox = CreateFrame("EditBox", nil, scrollFrame)
    editBox:SetSize(300, 60)
    editBox:SetPoint("TOPLEFT")
    editBox:SetMultiLine(true)
    editBox:SetFontObject(ChatFontNormal)
    editBox:SetAutoFocus(false)
    editBox:SetScript("OnEscapePressed", function() 
        editBox:ClearFocus()
        buildManagerFrame:Hide() 
    end)
    -- Add this new script to handle focus when the frame is shown
    editBox:SetScript("OnShow", function(self)
        C_Timer.After(0.1, function() -- Small delay to ensure frame is fully shown
            self:SetFocus()
            self:SetCursorPosition(0) -- Position cursor at start
        end)
    end)
    
    scrollFrame:SetScrollChild(editBox)
    
    -- Add a border around the text area
    local border = CreateFrame("Frame", nil, buildManagerFrame)
    border:SetSize(304, 64)
    border:SetPoint("CENTER", scrollFrame, "CENTER")
    border:SetBackdrop({
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    border:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
    
    -- Store references
    buildManagerFrame.editBox = editBox
    buildManagerFrame.exportBtn = exportBtn
    buildManagerFrame.importBtn = importBtn
    buildManagerFrame.closeBtn = closeBtn
    
    return buildManagerFrame
end

-- Add build manager button to perk frame
local function AddBuildManagerButton()
    if buildManagerButtonAdded or not _G["PerkMgrFrame"] then
        return
    end
    
    local buildManagerButton = CreateFrame("Button", "SBM_BuildManagerButton", _G["PerkMgrFrame"], "UIPanelButtonTemplate")
    buildManagerButton:SetSize(100, 22)
    buildManagerButton:SetPoint("TOPRIGHT", _G["PerkMgrFrame"], "TOPRIGHT", -230, -22)
    buildManagerButton:SetText("Build Manager")
    buildManagerButton:SetScript("OnClick", function()
        local frame = CreateBuildManagerFrame()
        if frame:IsShown() then
            frame:Hide()
        else
            frame:Show()
            -- Ensure the editBox gets focus when opening
            C_Timer.After(0.1, function()
                frame.editBox:SetFocus()
                frame.editBox:SetCursorPosition(0)
            end)
        end
    end)
    
    buildManagerButtonAdded = true
end

-- Hook the PerkMgrFrame OnShow event
local function HookPerkFrame()
    if _G["PerkMgrFrame"] then
        _G["PerkMgrFrame"]:HookScript("OnShow", AddBuildManagerButton)
    else
        -- If PerkMgrFrame doesn't exist yet, try again later
        C_Timer.After(1, HookPerkFrame)
    end
end

-- Function to initialize the addon
local function InitializeAddon()
    -- Hook the perk frame to add build manager button
    HookPerkFrame()
    
    print("Synastria Build Manager loaded.")
end

-- Create main frame for event handling
local frame = CreateFrame("Frame")

-- Event handler
local function OnEvent(self, event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddonName = ...
        if loadedAddonName == addonName then
            InitializeAddon()
            frame:UnregisterEvent("ADDON_LOADED")
        end
    elseif event == "PLAYER_LOGIN" then
        -- Fallback in case ADDON_LOADED doesn't work
        if not SBM.initialized then
            InitializeAddon()
            SBM.initialized = true
        end
        frame:UnregisterEvent("PLAYER_LOGIN")
    end
end

-- Register events
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", OnEvent)