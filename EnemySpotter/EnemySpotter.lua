-- EnemySpotter.lua

-- Create the main addon frame
local frame = CreateFrame("Frame")

-- Register combat log, nameplate, and unit events
frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
frame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
frame:RegisterEvent("PLAYER_TARGET_CHANGED")
frame:RegisterEvent("UNIT_AURA")
frame:RegisterEvent("PLAYER_ENTERING_WORLD") -- Ensure proper initialization on login or reload

-- Determine the opposing faction
local opposingFaction = UnitFactionGroup("player") == "Horde" and "Alliance" or "Horde"

-- Variable to track whether the addon is enabled
local isEnabled = true

-- Create a movable and resizable window for alerts
local alertWindow = CreateFrame("Frame", "EnemySpotterAlertWindow", UIParent, "BackdropTemplate")
alertWindow:SetSize(200, 14) -- Default to fit one character height
alertWindow:SetPoint("CENTER") -- Default position
alertWindow:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
})
alertWindow:SetBackdropColor(0, 0, 0, 0.4)
alertWindow:SetMovable(true)
alertWindow:EnableMouse(true)
alertWindow:RegisterForDrag("LeftButton")
alertWindow:SetScript("OnDragStart", function(self) self:StartMoving() end)
alertWindow:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

-- Create a scrolling message frame inside the window
local alertText = alertWindow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
alertText:SetPoint("TOPLEFT", alertWindow, "TOPLEFT", 10, -10)
alertText:SetWidth(alertWindow:GetWidth() - 20)
alertText:SetJustifyH("LEFT")
alertText:SetText("")
alertText:SetWordWrap(true)

-- Ensure the text width adjusts dynamically with the window size
alertWindow:SetScript("OnSizeChanged", function(self)
    if alertText then
        alertText:SetWidth(self:GetWidth() - 20)
    end
end)

-- Table to track detected players
local detectedPlayers = {}

-- Function to update the window size dynamically and hide when empty
local function UpdateWindowSize()
    local lineHeight = 14 -- Height of one line of text
    local text = alertText:GetText() or "" -- Safeguard against nil
    local numLines = select(2, text:gsub("\n", "")) + 1 -- Count lines, at least 1 if empty
    local newHeight = math.max(14 + 20, numLines * lineHeight + 20) -- Minimum height for one line
    alertWindow:SetHeight(newHeight)

    -- Hide the window if there are no lines to display
    if numLines == 1 and text == "" then
        alertWindow:Hide()
    else
        alertWindow:Show()
    end
end

-- Function to send player alerts
local function AlertPlayer(playerName)
    if playerName and isEnabled and not detectedPlayers[playerName] then
        detectedPlayers[playerName] = true -- Mark the player as detected
        local message = "Ally: " .. playerName .. "\n"

        -- Safely get current text (handle potential nil values)
        local currentText = alertText:GetText() or ""
        alertText:SetText(currentText .. message)

        -- Play a custom sound
        PlaySoundFile("Sound\\Spells\\PVPFlagTaken.ogg")

        -- Update the window size
        UpdateWindowSize()

        -- Fade out the name after 10 seconds
        C_Timer.After(10, function()
            detectedPlayers[playerName] = nil
            local updatedText = alertText:GetText() or ""
            alertText:SetText(string.gsub(updatedText, "Ally: " .. playerName .. "\n", ""))

            -- Update the window size after removal
            UpdateWindowSize()
        end)
    end
end

-- Function to check if a unit is a hostile human player
local function IsHostilePlayer(unit)
    if UnitIsPlayer(unit) and not UnitIsFriend("player", unit) and UnitFactionGroup(unit) == opposingFaction then
        return true
    end
    return false
end

-- Function to scan all visible nameplates
local function ScanNameplates()
    if not isEnabled then return end
    for _, unit in pairs(C_NamePlate.GetNamePlates()) do
        local unitID = unit.unitFrame.unit
        if unitID and IsHostilePlayer(unitID) then
            local name = UnitName(unitID)
            if name then
                AlertPlayer(name)
            end
        end
    end
end

-- Function to check a unit for player status
local function CheckUnit(unit)
    if IsHostilePlayer(unit) then
        local name = UnitName(unit)
        if name then
            AlertPlayer(name)
        end
    end
end

-- Event handler
frame:SetScript("OnEvent", function(self, event, ...)
    if not isEnabled then return end

    if event == "PLAYER_ENTERING_WORLD" then
        -- Initialize the window on login or reload
        UpdateWindowSize()

    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        -- Parse combat log events
        local _, eventType, _, sourceGUID, sourceName, sourceFlags, _, destGUID, destName, destFlags = CombatLogGetCurrentEventInfo()

        local isHostileSource = sourceName and bit.band(sourceFlags, COMBATLOG_OBJECT_TYPE_PLAYER) ~= 0 and
                                bit.band(sourceFlags, COMBATLOG_OBJECT_REACTION_HOSTILE) ~= 0

        if isHostileSource then
            AlertPlayer(sourceName)
        end

        local isHostileDest = destName and bit.band(destFlags, COMBATLOG_OBJECT_TYPE_PLAYER) ~= 0 and
                              bit.band(destFlags, COMBATLOG_OBJECT_REACTION_HOSTILE) ~= 0

        if isHostileDest and destGUID == UnitGUID("player") then
            AlertPlayer(destName)
        end

    elseif event == "NAME_PLATE_UNIT_ADDED" then
        -- Detect enemy players from nameplates
        local unit = ...
        CheckUnit(unit)

    elseif event == "PLAYER_TARGET_CHANGED" then
        -- Check the current target for enemy status
        CheckUnit("target")

    elseif event == "UNIT_AURA" then
        -- Check unit auras for enemy players
        CheckUnit("target")
    end
end)

-- Create a draggable toggle button
local toggleButton = CreateFrame("Button", "EnemySpotterToggleButton", UIParent, "UIPanelButtonTemplate")
toggleButton:SetSize(20, 20) -- 20x20 pixels
toggleButton:SetPoint("CENTER") -- Default position in the center of the screen
toggleButton:SetText("E") -- Label on the button
toggleButton:RegisterForDrag("LeftButton")

-- Dragging functionality
toggleButton:SetMovable(true)
toggleButton:SetScript("OnDragStart", function(self)
    self:StartMoving()
end)
toggleButton:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
end)

-- Toggle functionality
toggleButton:SetScript("OnClick", function(self)
    isEnabled = not isEnabled
    if isEnabled then
        alertWindow:Show()
        C_Timer.After(5, function()
            UpdateWindowSize()
        end)
    else
        alertWindow:Hide()
    end
    local status = isEnabled and "|cff00ff00Spy ON|r" or "|cffff0000Spy OFF|r" -- Green for ON, red for OFF
    DEFAULT_CHAT_FRAME:AddMessage(status)
end)

-- Ensure the button is always visible
toggleButton:SetFrameStrata("HIGH")
toggleButton:SetClampedToScreen(true)

-- Periodically scan for nameplates
C_Timer.NewTicker(1.0, ScanNameplates)
