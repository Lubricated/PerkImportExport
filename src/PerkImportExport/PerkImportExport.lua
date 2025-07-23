local addonName = "PerkImportExport"
local PIE = {}

-- Create export popup frame
local exportFrame = nil

local function CreateExportFrame()
    if exportFrame then
        return exportFrame
    end
    
    -- Main frame
    exportFrame = CreateFrame("Frame", "PerkExportFrame", UIParent)
    exportFrame:SetSize(400, 150)
    exportFrame:SetPoint("CENTER")
    exportFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    exportFrame:SetBackdropColor(0, 0, 0, 1)
    exportFrame:Hide()
    exportFrame:SetFrameStrata("DIALOG")
    
    -- Make it movable
    exportFrame:SetMovable(true)
    exportFrame:EnableMouse(true)
    exportFrame:SetScript("OnMouseDown", function(self) self:StartMoving() end)
    exportFrame:SetScript("OnMouseUp", function(self) self:StopMovingOrSizing() end)
    
    -- Title
    local title = exportFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -15)
    title:SetText("Perk Export")
    
    -- Instructions
    local instructions = exportFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    instructions:SetPoint("TOP", title, "BOTTOM", 0, -10)
    instructions:SetText("Copy this export string:")
    
    -- Edit box
    local editBox = CreateFrame("EditBox", nil, exportFrame, "InputBoxTemplate")
    editBox:SetSize(360, 20)
    editBox:SetPoint("TOP", instructions, "BOTTOM", 0, -10)
    editBox:SetAutoFocus(true)
    editBox:SetScript("OnEscapePressed", function(self) 
        self:ClearFocus()
        exportFrame:Hide()
    end)
    editBox:SetScript("OnEnterPressed", function(self) 
        self:HighlightText()
    end)
    editBox:SetScript("OnShow", function(self)
        self:SetFocus()
        self:HighlightText()
    end)
    
    -- OK Button
    local okButton = CreateFrame("Button", nil, exportFrame, "UIPanelButtonTemplate")
    okButton:SetSize(80, 22)
    okButton:SetPoint("BOTTOM", 0, 20)
    okButton:SetText("OK")
    okButton:SetScript("OnClick", function() 
        exportFrame:Hide()
    end)
    
    -- Store references
    exportFrame.editBox = editBox
    exportFrame.okButton = okButton
    
    return exportFrame
end

-- Helper function to get all perk data
local function GetAllPerks()
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

-- Export function
function PIE.ExportPerks()
    local perks = GetAllPerks()
    local activePerks = {}
    
    for _, perk in ipairs(perks) do
        if perk.active then
            table.insert(activePerks, perk.id)
        end
    end
    
    if #activePerks == 0 then
        print("No active perks to export.")
        return
    end
    
    local exportString = table.concat(activePerks, ",")
    
    -- Create and show the export frame
    local frame = CreateExportFrame()
    frame.editBox:SetText(exportString)
    frame:Show()
    
    -- Backup export string to chat
    print("Export string: " .. exportString)
end

-- Import function
function PIE.ImportPerks(importString)
    if not importString or importString == "" then
        print("Please provide a valid import string.")
        return
    end
    
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
    
    -- Apply changes with minimal delays
    local changeIndex = 1
    local function ApplyNextChange()
        if changeIndex > #allChanges then
            print("Perk import completed! Made " .. #allChanges .. " changes.")
            return
        end
        
        local change = allChanges[changeIndex]
        local frameName = "PerkMgrFrame-PerkLine-" .. change.position
        local perkFrame = getglobal(frameName)
        
        if perkFrame then
            -- Click the perk line first
            perkFrame:Click()
            
            -- Minimal delay before clicking toggle (0.01s)
            local timer = 0
            local timerFrame = CreateFrame("Frame")
            timerFrame:SetScript("OnUpdate", function(self, elapsed)
                timer = timer + elapsed
                if timer >= 0.01 then
                    timerFrame:SetScript("OnUpdate", nil)
                    local toggleButton = getglobal("PerkMgrFrame-Toggle")
                    if toggleButton then
                        toggleButton:Click()
                    end
                    
                    changeIndex = changeIndex + 1
                    -- Minimal delay before next change (0.01s)
                    local nextTimer = 0
                    local nextFrame = CreateFrame("Frame")
                    nextFrame:SetScript("OnUpdate", function(self, elapsed)
                        nextTimer = nextTimer + elapsed
                        if nextTimer >= 0.01 then
                            nextFrame:SetScript("OnUpdate", nil)
                            ApplyNextChange()
                        end
                    end)
                end
            end)
        else
            changeIndex = changeIndex + 1
            -- Skip to next immediately on error
            ApplyNextChange()
        end
    end
    
    ApplyNextChange()
end

-- Slash command handlers
local function SlashPerkExport(msg)
    PIE.ExportPerks()
end

local function SlashPerkImport(msg)
    PIE.ImportPerks(msg)
end

local function SlashPerkHelp(msg)
    print("=== Perk Import/Export Help ===")
    print("/perkexport - Export your current active perks")
    print("/perkimport <string> - Import perks from export string")
    print("/perkhelp - Show this help")
    print("Example: /perkimport 1,5,12,23")
end

-- Function to initialize the addon
local function InitializeAddon()
    -- Register slash commands
    SLASH_PERKEXPORT1 = "/perkexport"
    SlashCmdList["PERKEXPORT"] = SlashPerkExport
    
    SLASH_PERKIMPORT1 = "/perkimport"
    SlashCmdList["PERKIMPORT"] = SlashPerkImport
    
    SLASH_PERKHELP1 = "/perkhelp"
    SlashCmdList["PERKHELP"] = SlashPerkHelp
    
    print("Perk Import/Export loaded. Type /perkhelp for commands.")
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
        if not PIE.initialized then
            InitializeAddon()
            PIE.initialized = true
        end
        frame:UnregisterEvent("PLAYER_LOGIN")
    end
end

-- Register events
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", OnEvent)