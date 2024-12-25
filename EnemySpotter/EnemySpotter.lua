-- EnemySpotter.lua

-- Variable to track whether the addon is enabled
local isEnabled = true

-- Variable to track whether /say functionality is enabled
local isSayEnabled = true

-- Create the main addon frame
local frame = CreateFrame("Frame")

-- Register combat log, nameplate, and unit events
frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
frame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
frame:RegisterEvent("PLAYER_TARGET_CHANGED")
frame:RegisterEvent("UNIT_AURA")
frame:RegisterEvent("PLAYER_ENTERING_WORLD") -- Ensure proper initialization on login or reload

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

-- Tables to track detected players and announce cooldowns
local detectedPlayers = {}
local announceCooldowns = {}

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

-- Function to announce a player in /say
local function AnnouncePlayerInSay(playerName, playerClass)
    if not isSayEnabled then return end -- Do nothing if /say is disabled
    if UnitIsDeadOrGhost("player") then return end -- Do nothing if the player is dead
    if announceCooldowns[playerName] and GetTime() - announceCooldowns[playerName] < 10 then return end -- Check cooldown

    announceCooldowns[playerName] = GetTime() -- Update cooldown timestamp
    local message = "Enemy spotted: " .. playerName .. " (" .. playerClass .. ")"
    SendChatMessage(message, "SAY")
end

-- Function to send player alerts
local function AlertPlayer(playerName, playerClass)
    if playerName and isEnabled and not detectedPlayers[playerName] then
        detectedPlayers[playerName] = true -- Mark the player as detected
        local message = "Ally: " .. playerName .. "\n"

        -- Safely get current text (handle potential nil values)
        local currentText = alertText:GetText() or ""
        alertText:SetText(currentText .. message)

        -- Announce in /say if alive
        AnnouncePlayerInSay(playerName, playerClass)

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

-- Ensure the window disappears after loading
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        -- Initialize and hide the window if no text is present
        UpdateWindowSize()
        if alertText:GetText() == "" then
            alertWindow:Hide()
        end
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        -- Handle combat log events
        local timestamp, subevent, _, sourceGUID, sourceName, _, _, destGUID, destName, _, _, spellId, spellName, _, auraType = CombatLogGetCurrentEventInfo()
        -- Handle events (additional logic if needed)
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        -- Handle nameplate addition logic
    elseif event == "PLAYER_TARGET_CHANGED" then
        -- Handle target changes
    elseif event == "UNIT_AURA" then
        -- Handle aura updates
    end
end)

-- Create a draggable toggle button for "E" (Enemy detection toggle)
local toggleButtonE = CreateFrame("Button", "EnemySpotterToggleButton", UIParent, "UIPanelButtonTemplate")
toggleButtonE:SetSize(20, 20) -- 20x20 pixels
toggleButtonE:SetPoint("CENTER") -- Default position in the center of the screen
toggleButtonE:SetText("E") -- Label on the button
toggleButtonE:RegisterForDrag("LeftButton")

-- Dragging functionality for "E"
toggleButtonE:SetMovable(true)
toggleButtonE:SetScript("OnDragStart", function(self)
    self:StartMoving()
end)
toggleButtonE:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
end)

-- Toggle functionality for "E"
toggleButtonE:SetScript("OnClick", function(self)
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

-- Ensure the "E" button is always visible
toggleButtonE:SetFrameStrata("HIGH")
toggleButtonE:SetClampedToScreen(true)

-- Create a draggable toggle button for "S" (Say functionality toggle)
local toggleButtonS = CreateFrame("Button", "SayToggleButton", UIParent, "UIPanelButtonTemplate")
toggleButtonS:SetSize(20, 20) -- 20x20 pixels
toggleButtonS:SetPoint("LEFT", toggleButtonE, "RIGHT", 5, 0) -- Position next to "E" button
toggleButtonS:SetText("S") -- Label on the button
toggleButtonS:RegisterForDrag("LeftButton")

-- Dragging functionality for "S"
toggleButtonS:SetMovable(true)
toggleButtonS:SetScript("OnDragStart", function(self)
    self:StartMoving()
end)
toggleButtonS:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
end)

-- Toggle functionality for "S"
toggleButtonS:SetScript("OnClick", function(self)
    isSayEnabled = not isSayEnabled
    local status = isSayEnabled and "|cff00ff00Say ON|r" or "|cffff0000Say OFF|r" -- Green for ON, red for OFF
    DEFAULT_CHAT_FRAME:AddMessage(status)
end)

-- Ensure the "S" button is always visible
toggleButtonS:SetFrameStrata("HIGH")
toggleButtonS:SetClampedToScreen(true)
