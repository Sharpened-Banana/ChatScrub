-- The blocked-lines log window and the import/export window.
local _, ns = ...
local L = ns.L

local ROWS = 12
local ROW_HEIGHT = 22

local function makeWindow(globalName, title, width, height)
    local f = CreateFrame("Frame", globalName, UIParent, "BasicFrameTemplateWithInset")
    f:SetSize(width, height)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetClampedToScreen(true)
    f:Hide()
    local text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("TOP", 0, -5)
    text:SetText(title)
    tinsert(UISpecialFrames, globalName) -- Esc closes it
    return f
end

local function button(parent, label, width, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width, 22)
    b:SetText(label)
    b:SetScript("OnClick", onClick)
    return b
end

---------------------------------------------------------------- Log window
local logFrame, search, rows, countText
local offset, shown = 0, {}

local function entryLine(e)
    return ("|cff888888%s %s|r %s: %s |cffff7070(%s)|r"):format(date("%H:%M", e.t), e.where, e.who, e.msg, e.why)
end

local function refreshLog()
    if not logFrame or not logFrame:IsShown() then
        return
    end
    -- Newest first.
    local found = ns.Lists.SearchLog(ns.GetDB().log, search:GetText())
    shown = {}
    for i = #found, 1, -1 do
        shown[#shown + 1] = found[i]
    end
    offset = math.max(0, math.min(offset, #shown - ROWS))
    for i, row in ipairs(rows) do
        local e = shown[offset + i]
        row.entry = e
        if e then
            row.text:SetText(entryLine(e))
            row:Show()
        else
            row:Hide()
        end
    end
    if #shown == 0 then
        countText:SetText(L["Nothing in the log."])
    else
        countText:SetText((L["%d-%d of %d, newest first. Scroll for more."]):format(
            offset + 1, math.min(offset + ROWS, #shown), #shown))
    end
end
ns.RefreshLogWindow = refreshLog

local function createLog()
    logFrame = makeWindow("ChatScrubLogFrame", L["ChatScrub: hidden lines"], 640, 120 + ROWS * ROW_HEIGHT)

    search = CreateFrame("EditBox", nil, logFrame, "InputBoxTemplate")
    search:SetSize(240, 20)
    search:SetPoint("TOPLEFT", 20, -34)
    search:SetAutoFocus(false)
    search:SetScript("OnTextChanged", function() offset = 0; refreshLog() end)
    search:SetScript("OnEscapePressed", search.ClearFocus)
    local hint = logFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("LEFT", search, "RIGHT", 8, 0)
    hint:SetText(L["Search by player, channel, text or rule"])

    rows = {}
    for i = 1, ROWS do
        local row = CreateFrame("Frame", nil, logFrame)
        row:SetSize(600, ROW_HEIGHT)
        row:SetPoint("TOPLEFT", 14, -60 - (i - 1) * ROW_HEIGHT)
        row:EnableMouse(true)
        row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.text:SetPoint("LEFT", 4, 0)
        row.text:SetPoint("RIGHT", -150, 0)
        row.text:SetJustifyH("LEFT")
        row.text:SetWordWrap(false)
        local allow = button(row, L["Allow"], 70, function(self)
            local e = self:GetParent().entry
            if e then
                ns.say(select(2, ns.AllowPlayer(e.author or e.who)))
            end
        end)
        allow:SetPoint("RIGHT", 0, 0)
        local show = button(row, L["Show"], 70, function(self)
            local e = self:GetParent().entry
            if e then
                DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99ChatScrub|r " .. L["(hidden line)"] .. " " .. entryLine(e))
            end
        end)
        show:SetPoint("RIGHT", allow, "LEFT", -4, 0)
        row:SetScript("OnEnter", function(self)
            if not self.entry then
                return
            end
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine(self.entry.who .. " (" .. self.entry.where .. ")")
            GameTooltip:AddLine(self.entry.msg, 1, 1, 1, true)
            GameTooltip:AddLine(self.entry.why, 1, 0.45, 0.45, true)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(L["Show prints the line in chat. Allow stops hiding this player."], 0.6, 0.6, 0.6, true)
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        rows[i] = row
    end

    logFrame:EnableMouseWheel(true)
    logFrame:SetScript("OnMouseWheel", function(_, delta)
        offset = offset - delta * 3
        refreshLog()
    end)

    countText = logFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    countText:SetPoint("BOTTOMLEFT", 20, 18)

    local clear = button(logFrame, L["Clear log"], 100, function()
        wipe(ns.GetDB().log)
        refreshLog()
    end)
    clear:SetPoint("BOTTOMRIGHT", -16, 12)

    logFrame:SetScript("OnShow", refreshLog)
end

function ns.ToggleLogWindow()
    if not logFrame then
        createLog()
    end
    if logFrame:IsShown() then
        logFrame:Hide()
    else
        logFrame:Show()
        refreshLog()
    end
end

---------------------------------------------------------------- Import/export window
local shareFrame, shareBox, shareTitle, importButton

local function createShare()
    shareFrame = makeWindow("ChatScrubShareFrame", "ChatScrub", 520, 360)
    shareTitle = shareFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    shareTitle:SetPoint("TOPLEFT", 18, -32)
    shareTitle:SetWidth(480)
    shareTitle:SetJustifyH("LEFT")

    local scroll = CreateFrame("ScrollFrame", nil, shareFrame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 18, -70)
    scroll:SetPoint("BOTTOMRIGHT", -36, 46)
    shareBox = CreateFrame("EditBox", nil, scroll)
    shareBox:SetMultiLine(true)
    shareBox:SetAutoFocus(false)
    shareBox:SetFontObject(ChatFontNormal)
    shareBox:SetWidth(450)
    shareBox:SetScript("OnEscapePressed", function() shareFrame:Hide() end)
    scroll:SetScrollChild(shareBox)

    importButton = button(shareFrame, L["Import"], 110, function()
        local _, reply = ns.Import(shareBox:GetText())
        ns.say(reply)
        ns.RefreshOptions()
    end)
    importButton:SetPoint("BOTTOMLEFT", 16, 14)
    local close = button(shareFrame, L["Close"], 90, function() shareFrame:Hide() end)
    close:SetPoint("BOTTOMRIGHT", -16, 14)
end

-- mode: "export" fills the box and selects it for copying; "import" empties it.
function ns.ShowShareWindow(mode)
    if not shareFrame then
        createShare()
    end
    if mode == "export" then
        shareTitle:SetText(L["Press Ctrl+C to copy. Keywords, watch words, allowed phrases and player lists are included."])
        shareBox:SetText(ns.Export())
        importButton:Hide()
    else
        shareTitle:SetText(L["Paste a ChatScrub export with Ctrl+V, then click Import. Entries are added to your lists; nothing is removed."])
        shareBox:SetText("")
        importButton:Show()
    end
    shareFrame:Show()
    shareBox:SetFocus()
    shareBox:HighlightText()
end
