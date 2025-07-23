local testFrame

-- Create the testing UI frame
local function CreateTestFrame()
    local f = CreateFrame("Frame", "TalentTesterFrame", UIParent)
    f:SetSize(400, 300)
    f:SetPoint("CENTER")
    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:Hide()
    
    -- Title
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -15)
    title:SetText("Talent Tester")
    
    -- Export button
    local exportBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    exportBtn:SetSize(80, 25)
    exportBtn:SetPoint("TOPLEFT", 30, -50)
    exportBtn:SetText("Export")
    exportBtn:SetScript("OnClick", function()
        local exportString = ExportDualClassTalents()
        f.editBox:SetText(exportString)
        f.editBox:HighlightText()
    end)
    
    -- Import button
    local importBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    importBtn:SetSize(80, 25)
    importBtn:SetPoint("TOP", 0, -50)
    importBtn:SetText("Import")
    importBtn:SetScript("OnClick", function()
        local importString = f.editBox:GetText()
        if importString ~= "" then
            ImportDualClassTalents(importString)
        else
            print("Please paste talent string first!")
        end
    end)
    
    -- Close button
    local closeBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    closeBtn:SetSize(80, 25)
    closeBtn:SetPoint("TOPRIGHT", -30, -50)
    closeBtn:SetText("Close")
    closeBtn:SetScript("OnClick", function() f:Hide() end)
    
    -- Text box
    local scrollFrame = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 20, -85)
    scrollFrame:SetPoint("BOTTOMRIGHT", -40, 20)
    
    local editBox = CreateFrame("EditBox", nil, scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetFontObject(ChatFontNormal)
    editBox:SetWidth(scrollFrame:GetWidth())
    editBox:SetScript("OnEscapePressed", function() f:Hide() end)
    scrollFrame:SetScrollChild(editBox)
    
    f.editBox = editBox
    
    return f
end

testFrame = CreateTestFrame()

-- Slash command to open tester
SLASH_TTEST1 = "/ttest"
SlashCmdList["TTEST"] = function()
    if testFrame:IsShown() then
        testFrame:Hide()
    else
        testFrame:Show()
    end
end

print("Talent Tester loaded! Use /ttest to open.")