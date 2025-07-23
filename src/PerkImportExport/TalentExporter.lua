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

-- Get class name from button tooltip
local function GetClassNameFromButton(buttonName)
    local btn = _G[buttonName]
    if not btn then return nil end
    
    GameTooltip:ClearLines()
    btn:GetScript("OnEnter")(btn)
    local line = GameTooltipTextLeft1
    return line and line:GetText() or nil
end

-- Export talents from current class
local function ExportCurrentClass()
    local tabStrings = {}
    
    for tab = 1, GetNumTalentTabs() do
        local tabString = ""
        for talent = 1, GetNumTalents(tab) do
            local _, _, _, _, currentRank = GetTalentInfo(tab, talent)
            tabString = tabString .. currentRank
        end
        
        -- Remove trailing zeros
        tabString = tabString:gsub("0+$", "")
        
        -- Only include tab if it has any points
        if tabString ~= "" then
            tabStrings[tab] = tabString
        end
    end
    
    -- Convert to compact format: tab1:talents,tab2:talents
    local compactString = ""
    for tab, talents in pairs(tabStrings) do
        if compactString ~= "" then compactString = compactString .. "," end
        compactString = compactString .. tab .. ":" .. talents
    end
    
    return compactString
end

-- Main export function
function ExportDualClassTalents()
    -- Ensure talent frame is loaded
    TalentFrame_LoadUI()
    
    local isDual = IsDualClass()
    local exportData = {}
    
    if isDual then
        -- Dual class logic
        if not _G["PlayerClassTalentBtn1"] or not _G["PlayerClassTalentBtn2"] then
            print("Could not load talent frame properly!")
            return nil
        end
        
        local originalClass = GetSelectedTalentClassIndex()
        
        -- Get current class data
        local currentClassName = GetClassNameFromButton("PlayerClassTalentBtn" .. originalClass)
        local currentTalents = ExportCurrentClass()
        exportData[currentClassName] = currentTalents
        
        -- Switch to other class
        local otherButton = originalClass == 1 and 2 or 1
        _G["PlayerClassTalentBtn" .. otherButton]:Click()
        
        -- Get other class data
        local otherClassName = GetClassNameFromButton("PlayerClassTalentBtn" .. otherButton)
        local otherTalents = ExportCurrentClass()
        exportData[otherClassName] = otherTalents
        
        -- Switch back to original
        _G["PlayerClassTalentBtn" .. originalClass]:Click()
    else
        -- Single class logic
        local _, className = UnitClass("player")
        local talents = ExportCurrentClass()
        exportData[className] = talents
    end
    
    -- Format export string
    local exportString = ""
    for className, talents in pairs(exportData) do
        exportString = exportString .. className .. ":" .. talents .. "\n"
    end
    
    -- Remove trailing newline
    exportString = exportString:gsub("\n$", "")
    
    print("=== TALENT EXPORT ===")
    print(exportString)
    print("=== END EXPORT ===")
    
    return exportString
end

-- Slash command
SLASH_TEXPORT1 = "/texport"
SlashCmdList["TEXPORT"] = function()
    -- Ensure talent frame is loaded
    TalentFrame_LoadUI()
    
    -- Quick check that our buttons exist for dual class
    if IsDualClass() and (not _G["PlayerClassTalentBtn1"] or not _G["PlayerClassTalentBtn2"]) then
        print("Could not load talent frame properly!")
        return
    end
    
    ExportDualClassTalents()
end

print("Talent Exporter loaded! Use /texport with talent window open.")