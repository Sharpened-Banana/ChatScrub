-- Minimap button. Hand-rolled (no LibDBIcon) so the addon has no dependencies.
-- Position is an angle in degrees around the minimap, saved in ChatScrubDB.minimap.
local addonName, ns = ...

local DEFAULT_ANGLE = 225 -- lower left, out of the way of the clock and tracking buttons
local button
local atan2 = math.atan2 or math.atan -- WoW is Lua 5.1; newer Lua (for tests) has 2-arg math.atan

-- Pure helpers, tested in tests/run_tests.lua.
function ns.MinimapOffset(angle, radius)
    local rad = math.rad(angle)
    return math.cos(rad) * radius, math.sin(rad) * radius
end

function ns.AngleFrom(centerX, centerY, cursorX, cursorY)
    return math.deg(atan2(cursorY - centerY, cursorX - centerX)) % 360
end

local function place()
    local x, y = ns.MinimapOffset(ns.GetDB().minimap.angle, Minimap:GetWidth() / 2 + 5)
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function followCursor()
    local cx, cy = Minimap:GetCenter()
    local px, py = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    ns.GetDB().minimap.angle = ns.AngleFrom(cx, cy, px / scale, py / scale)
    place()
end

local function onOff(value)
    return value and "|cff00ff00on|r" or "|cffff4040off|r"
end

local function showTooltip(self)
    local db, s = ns.GetDB(), ns.Settings()
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("ChatScrub")
    GameTooltip:AddLine("Filtering: " .. onOff(s.enabled), 1, 1, 1)
    GameTooltip:AddLine("Spam rules: " .. onOff(s.spamRules), 1, 1, 1)
    GameTooltip:AddLine("Blocked so far: " .. db.blocked, 1, 1, 1)
    GameTooltip:AddLine("Repeats hidden: " .. db.repeatsHidden, 1, 1, 1)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Left-click: options", 0.6, 0.6, 0.6)
    GameTooltip:AddLine("Right-click: turn filtering on/off", 0.6, 0.6, 0.6)
    GameTooltip:AddLine("Drag: move around the minimap", 0.6, 0.6, 0.6)
    GameTooltip:Show()
end

function ns.UpdateMinimapButton()
    if not button then
        return
    end
    if ns.GetDB().minimap.hide then
        button:Hide()
    else
        place()
        button:Show()
    end
    button.icon:SetDesaturated(not ns.Settings().enabled)
end

function ns.CreateMinimapButton()
    local saved = ns.GetDB().minimap
    saved.angle = saved.angle or DEFAULT_ANGLE

    button = CreateFrame("Button", "ChatScrubMinimapButton", Minimap)
    button:SetSize(31, 31)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    background:SetSize(20, 20)
    background:SetPoint("TOPLEFT", 7, -5)

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetTexture("Interface\\AddOns\\" .. addonName .. "\\Media\\Icon")
    icon:SetTexCoord(0.05, 0.95, 0.05, 0.95) -- trim the dark frame; the minimap border replaces it
    icon:SetSize(17, 17)
    icon:SetPoint("TOPLEFT", 7, -6)
    button.icon = icon

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT")

    button:SetScript("OnClick", function(self, mouse)
        if mouse == "RightButton" then
            SlashCmdList.CHATSCRUB(ns.Settings().enabled and "off" or "on")
        else
            ns.OpenOptions()
        end
        if GameTooltip:IsOwned(self) then
            showTooltip(self)
        end
    end)
    button:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", followCursor)
        GameTooltip:Hide()
    end)
    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
    end)
    button:SetScript("OnEnter", showTooltip)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)

    ns.UpdateMinimapButton()
end
