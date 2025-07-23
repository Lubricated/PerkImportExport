-- Count number of set bits in a number (number of classes)
local function CountSetBits(n)
    local count = 0
    while n > 0 do
        if n % 2 == 1 then
            count = count + 1
        end
        n = math.floor(n / 2)
    end
    return count
end

-- Check if player is dual class
local function IsDualClass()
    local classMask = CustomGetClassMask()
    return CountSetBits(classMask) > 1
end

-- Parse compressed talent string back to full format
local function ParseCompressedTalents(compressedString, numTabs)
    local fullTabs = {}
    
    -- Initialize all tabs as empty
    for tab = 1, numTabs do
        fullTabs[tab] = ""
    end
    
    -- Parse compressed format: "1:123,2:21"
    for tabData in compressedString:gmatch("[^,]+") do
        local tabIndex, talents = tabData:match("(%d+):(.+)")
        if tabIndex and talents then
            fullTabs[tonumber(tabIndex)] = talents
        end
    end
    
    -- Pad each tab to correct length with trailing zeros
    for tab = 1, numTabs do
        local numTalents = GetNumTalents(tab)
        local currentLength = string.len(fullTabs[tab])
        
        if currentLength < numTalents then
            fullTabs[tab] = fullTabs[tab] .. string.rep("0", numTalents - currentLength)
        end
    end
    
    return fullTabs
end

-- Get class name from button tooltip
local function GetClassNameFromButton(buttonName)
    local btn = _G[buttonName]
    if not btn then return nil end
    
    GameTooltip:ClearLines()
    btn:GetScript("OnEnter")(btn)
    local line = GameTooltipTextLeft1
    return line and line:GetText() or nil
end

-- Apply talents to current class using preview, then learn them
local function ApplyTalentsToCurrentClass(talentTabs)
    local currentClass = GetSelectedTalentClassIndex()
    print("Applying talents to class " .. currentClass)
    
    -- Clear current preview
    for tab = 1, GetNumTalentTabs() do
        for talent = 1, GetNumTalents(tab) do
            AddPreviewTalentPoints(tab, talent, -5)
        end
    end
    
    -- Apply new talents to preview
    for tab = 1, GetNumTalentTabs() do
        if talentTabs[tab] then
            for i = 1, string.len(talentTabs[tab]) do
                local points = tonumber(string.sub(talentTabs[tab], i, i))
                if points and points > 0 then
                    AddPreviewTalentPoints(tab, i, points)
                end
            end
        end
    end
    
    -- Commit all preview talents at once
    LearnPreviewTalents()
    print("Learned preview talents for class " .. currentClass)
end

-- Apply talents for single class
local function ApplyTalentsToSingleClass(talentTabs)
    print("Applying talents to single class")
    
    -- Clear current preview
    for tab = 1, GetNumTalentTabs() do
        for talent = 1, GetNumTalents(tab) do
            AddPreviewTalentPoints(tab, talent, -5)
        end
    end
    
    -- Apply new talents to preview
    for tab = 1, GetNumTalentTabs() do
        if talentTabs[tab] then
            for i = 1, string.len(talentTabs[tab]) do
                local points = tonumber(string.sub(talentTabs[tab], i, i))
                if points and points > 0 then
                    AddPreviewTalentPoints(tab, i, points)
                end
            end
        end
    end
    
    -- Commit all preview talents at once
    LearnPreviewTalents()
    print("Learned preview talents for single class")
end

-- Main import function
function ImportDualClassTalents(importString)
    -- Ensure talent frame is loaded
    TalentFrame_LoadUI()
    
    local isDual = IsDualClass()
    
    -- Parse import string
    local classData = {}
    for line in importString:gmatch("[^\n]+") do
        local className, talents = line:match("([^:]+):(.+)")
        if className and talents then
            classData[className] = talents
        end
    end
    
    if not next(classData) then
        print("Invalid import format!")
        return
    end
    
    if isDual then
        -- Dual class logic
        if not _G["PlayerClassTalentBtn1"] or not _G["PlayerClassTalentBtn2"] then
            print("Could not load talent frame properly!")
            return
        end
        
        local originalClass = GetSelectedTalentClassIndex()
        local imported = 0
        
        -- Try to import for both classes
        for classIndex = 1, 2 do
            -- Switch to this class
            _G["PlayerClassTalentBtn" .. classIndex]:Click()
            
            -- Get current class name
            local currentClassName = GetClassNameFromButton("PlayerClassTalentBtn" .. classIndex)
            
            -- Check if we have data for this class
            if classData[currentClassName] then
                local talentTabs = ParseCompressedTalents(classData[currentClassName], GetNumTalentTabs())
                ApplyTalentsToCurrentClass(talentTabs)
                print("Imported talents for " .. currentClassName)
                imported = imported + 1
            end
        end
        
        -- Switch back to original class
        _G["PlayerClassTalentBtn" .. originalClass]:Click()
        
        if imported > 0 then
            print("Import complete!")
        else
            print("No matching classes found in import string!")
        end
    else
        -- Single class logic
        local _, playerClassName = UnitClass("player")
        
        if classData[playerClassName] then
            local talentTabs = ParseCompressedTalents(classData[playerClassName], GetNumTalentTabs())
            ApplyTalentsToSingleClass(talentTabs)
            print("Imported talents for " .. playerClassName)
            print("Import complete!")
        else
            print("No matching class found in import string!")
        end
    end
end

-- Slash command for testing
SLASH_TIMPORT1 = "/timport"
SlashCmdList["TIMPORT"] = function(msg)
    if msg == "" then
        print("Usage: /timport <talent_string>")
        return
    end
    ImportDualClassTalents(msg)
end

print("Talent Importer loaded! Use /timport <string> to import.")