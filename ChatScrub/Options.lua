-- Settings panels: Options > AddOns > ChatScrub (Esc > Interface > AddOns on
-- older clients), with Rules, Players and Extras pages underneath.
local addonName, ns = ...
local L = ns.L

local category
local checks = {}   -- { box, get } pairs refreshed by RefreshOptions
local listBoxes = {} -- multi-line boxes refreshed by RefreshOptions
local ruleBoxes = {}
local statsText
ns.Widgets = {}

local function checkbox(parent, label, anchor, get, set, tooltip)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -6)
    local text = cb:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    text:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    text:SetText(label)
    cb.label = text
    -- Let the label take clicks and hovers too, not just the box.
    cb:SetHitRectInsets(0, -((text:GetStringWidth() or 0) + 4), 0, 0)
    cb:SetScript("OnClick", function(self)
        set(self:GetChecked() and true or false)
        ns.UpdateMinimapButton()
    end)
    if tooltip then
        cb:SetScript("OnEnter", tooltip)
        cb:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    checks[#checks + 1] = { box = cb, get = get }
    return cb
end

local function button(parent, label, width, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width, 22)
    b:SetText(label)
    b:SetScript("OnClick", onClick)
    return b
end

local function heading(parent, text, sub)
    local title = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(text)
    local desc = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    desc:SetWidth(580)
    desc:SetJustifyH("LEFT")
    desc:SetText(sub)
    return desc
end

local function simpleTooltip(title, ...)
    local lines = { ... }
    return function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(title)
        for _, line in ipairs(lines) do
            if type(line) == "function" then
                line = line()
            end
            GameTooltip:AddLine(line, 1, 1, 1, true)
        end
        GameTooltip:Show()
    end
end

local function splitLines(text)
    local lines = {}
    for line in (text .. "\n"):gmatch("(.-)\n") do
        lines[#lines + 1] = line
    end
    return lines
end

-- A labelled multi-line box with Save and Undo buttons. getText returns the
-- saved text; save receives the edited lines.
local function listBox(parent, labelText, width, height, getText, save)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(width, height + 50)

    local label = holder:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetPoint("TOPLEFT")
    label:SetWidth(width)
    label:SetJustifyH("LEFT")
    label:SetText(labelText)

    local box = CreateFrame("Frame", nil, holder, "BackdropTemplate")
    box:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -6)
    box:SetSize(width, height)
    box:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 14,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    box:SetBackdropColor(0, 0, 0, 0.6)
    box:EnableMouse(true)

    local scroll = CreateFrame("ScrollFrame", nil, box, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 8, -8)
    scroll:SetPoint("BOTTOMRIGHT", -28, 8)

    local edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetFontObject(ChatFontNormal)
    edit:SetWidth(width - 40)
    edit:SetHeight(height - 16)
    edit:SetScript("OnEscapePressed", edit.ClearFocus)
    scroll:SetScrollChild(edit)
    box:SetScript("OnMouseDown", function() edit:SetFocus() end)

    local saveButton = button(holder, L["Save"], 90, function()
        save(splitLines(edit:GetText()))
        edit:ClearFocus()
        edit:SetText(getText())
        ns.say(L["saved."])
    end)
    saveButton:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 0, -6)
    local undo = button(holder, L["Undo edits"], 100, function()
        edit:ClearFocus()
        edit:SetText(getText())
    end)
    undo:SetPoint("LEFT", saveButton, "RIGHT", 6, 0)

    listBoxes[#listBoxes + 1] = { edit = edit, getText = getText }
    holder.edit = edit
    return holder
end

local function joined(list)
    return function() return table.concat(list(), "\n") end
end

local function playerNames(field)
    return function()
        return ns.Lists.Names(ns.GetDB()[field], time())
    end
end

local function showRulesTooltip(self)
    local s = ns.Settings()
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(L["Built-in spam rules"])
    GameTooltip:AddLine(L["A line is hidden when it matches any of these:"], 1, 1, 1, true)
    for _, rule in ipairs(ns.Rules.SPAM) do
        local on = ns.Rules.IsOn(rule, s.rules)
        local color = on and "|cffffd100" or "|cff808080"
        GameTooltip:AddLine(("%s%s:|r %s |cff888888(%d)|r%s"):format(color, rule.id, rule.desc,
            ns.Hits("rule:" .. rule.id), on and "" or (" " .. L["(off)"])), 1, 1, 1, true)
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(L["Also catches look-alike spellings like g0ld, c4rry and g o l d."], 0.6, 0.6, 0.6, true)
    GameTooltip:AddLine(L["Turn single rules on or off on the Rules page. Check a line with /scrub test <text>."], 0.6, 0.6, 0.6, true)
    GameTooltip:Show()
end

local function register(frame, name, parentCategory)
    if Settings and Settings.RegisterCanvasLayoutCategory then
        if parentCategory then
            Settings.RegisterCanvasLayoutSubcategory(parentCategory, frame, name)
            return parentCategory
        end
        local cat = Settings.RegisterCanvasLayoutCategory(frame, name)
        Settings.RegisterAddOnCategory(cat)
        return cat
    end
    frame.name = name
    if parentCategory ~= nil then
        frame.parent = addonName
    end
    InterfaceOptions_AddCategory(frame)
    return false
end

---------------------------------------------------------------- Main page
local function createMain()
    local panel = CreateFrame("Frame")
    panel.name = addonName
    local s = ns.Settings
    local sub = heading(panel, "ChatScrub",
        L["Hides public chat (channels, say, yell, whispers, emotes) that matches your keywords or looks like gold/boost spam. Friends, guildmates and group chat are never hidden."])

    local enabledBox = checkbox(panel, L["Filter chat"], sub,
        function() return s().enabled end, function(v) s().enabled = v end)
    local spamBox = checkbox(panel, L["Use built-in gold/boost spam rules"], enabledBox,
        function() return s().spamRules end, function(v) s().spamRules = v end, showRulesTooltip)
    local repeatBox = checkbox(panel, L["Hide repeated lines"], spamBox,
        function() return s().repeats end, function(v) s().repeats = v end,
        simpleTooltip(L["Hide repeated lines"],
            function() return (L["Hides a line when the same player already said the same thing in the same channel within the last %d minutes. They show again once that time has passed."]):format(s().repeatMinutes) end,
            L["Covers channels, say, yell and emotes, not whispers. Repeats are counted but not added to the log."],
            L["Change the time with /scrub repeats <minutes>."]))
    ns.Widgets.spamBox, ns.Widgets.repeatBox = spamBox, repeatBox

    local keywords = listBox(panel,
        L["Keywords, one per line (not case-sensitive; matches anywhere in the line; * is a wildcard):"],
        420, 170, joined(function() return ns.GetDB().keywords end), ns.SetKeywords)
    keywords:SetPoint("TOPLEFT", repeatBox, "BOTTOMLEFT", 0, -14)

    statsText = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    statsText:SetPoint("TOPLEFT", keywords, "BOTTOMLEFT", 0, -10)

    local openLog = button(panel, L["Open blocked log"], 150, function() ns.ToggleLogWindow() end)
    openLog:SetPoint("TOPLEFT", statsText, "BOTTOMLEFT", 0, -8)
    local export = button(panel, L["Export lists"], 120, function() ns.ShowShareWindow("export") end)
    export:SetPoint("LEFT", openLog, "RIGHT", 8, 0)
    local import = button(panel, L["Import lists"], 120, function() ns.ShowShareWindow("import") end)
    import:SetPoint("LEFT", export, "RIGHT", 8, 0)

    panel:SetScript("OnShow", ns.RefreshOptions)
    return panel
end

---------------------------------------------------------------- Rules page
local function createRules()
    local panel = CreateFrame("Frame")
    local s = ns.Settings
    local sub = heading(panel, L["Rules"],
        L["Each built-in rule can be turned on or off. The number is how many lines it has hidden. Guild recruitment is off unless you turn it on."])
    local anchor = sub
    for _, rule in ipairs(ns.Rules.SPAM) do
        local box = checkbox(panel, rule.id, anchor,
            function() return ns.Rules.IsOn(rule, s().rules) end,
            function(v) s().rules[rule.id] = v end,
            simpleTooltip(rule.id, rule.desc))
        ruleBoxes[#ruleBoxes + 1] = { box = box, rule = rule }
        anchor = box
    end
    local auto = checkbox(panel, L["Auto-block repeat spammers for the session"], anchor,
        function() return s().autoBlock end, function(v) s().autoBlock = v end,
        simpleTooltip(L["Auto-block repeat spammers for the session"],
            function() return (L["After %d spam hits from the same player, everything they say is hidden until you log out. Change the number with /scrub autoblock <hits>."]):format(s().autoBlockHits) end))
    auto:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -16)
    return panel
end

---------------------------------------------------------------- Players page
local function createPlayers()
    local panel = CreateFrame("Frame")
    local db = ns.GetDB
    local sub = heading(panel, L["Players and phrases"],
        L["One entry per line. A name without a realm matches that name on any realm. Notes and end dates are set with /scrub block and /scrub allow, and kept when you edit here."])

    local blocked = listBox(panel, L["Blocked players (everything they say is hidden):"], 280, 120,
        joined(playerNames("blockedPlayers")), function(lines) ns.SetPlayers(db().blockedPlayers, lines) end)
    blocked:SetPoint("TOPLEFT", sub, "BOTTOMLEFT", 0, -14)
    local allowed = listBox(panel, L["Never hide these players:"], 280, 120,
        joined(playerNames("allowPlayers")), function(lines) ns.SetPlayers(db().allowPlayers, lines) end)
    allowed:SetPoint("LEFT", blocked, "RIGHT", 20, 0)

    local phrases = listBox(panel, L["Never hide lines containing:"], 280, 120,
        joined(function() return db().allowPhrases end), ns.SetAllowPhrases)
    phrases:SetPoint("TOPLEFT", blocked, "BOTTOMLEFT", 0, -10)
    local watch = listBox(panel, L["Watch words (highlight the line and play a sound):"], 280, 120,
        joined(function() return db().watch end), ns.SetWatch)
    watch:SetPoint("LEFT", phrases, "RIGHT", 20, 0)
    return panel
end

---------------------------------------------------------------- Extras page
local function createExtras()
    local panel = CreateFrame("Frame")
    local s = ns.Settings
    local sub = heading(panel, L["Extras"], L["Smaller clean-ups for public chat."])
    local icons = checkbox(panel, L["Remove raid target icons from public chat"], sub,
        function() return s().stripIcons end, function(v) s().stripIcons = v end)
    local loot = checkbox(panel, L["Hide other players' loot messages"], icons,
        function() return s().hideLoot end, function(v) s().hideLoot = v end)
    local bubbles = checkbox(panel, L["Hide the chat bubbles of hidden say/yell lines"], loot,
        function() return s().bubbles end, function(v) s().bubbles = v end,
        simpleTooltip(L["Chat bubbles"], L["Works in the open world. Inside dungeons and raids the game doesn't let addons touch chat bubbles."]))
    local sound = checkbox(panel, L["Play a sound for watch words"], bubbles,
        function() return s().watchSound end, function(v) s().watchSound = v end)
    local char = checkbox(panel, L["Give this character its own switches"], sound,
        function() return ns.UsingCharacterSettings() end,
        function(v) ns.UseCharacterSettings(v); ns.RefreshOptions() end,
        simpleTooltip(L["Give this character its own switches"],
            L["The checkboxes on these pages apply to this character only. Keywords and player lists stay shared across the account."]))
    char:SetPoint("TOPLEFT", sound, "BOTTOMLEFT", 0, -16)
    return panel
end

function ns.RefreshOptions()
    if not statsText then
        return
    end
    local db = ns.GetDB()
    for _, c in ipairs(checks) do
        c.box:SetChecked(c.get())
    end
    for _, r in ipairs(ruleBoxes) do
        r.box.label:SetText(("%s |cff888888(%d)|r"):format(r.rule.id, ns.Hits("rule:" .. r.rule.id)))
    end
    for _, b in ipairs(listBoxes) do
        if not b.edit:HasFocus() then
            b.edit:SetText(b.getText())
        end
    end
    statsText:SetText((L["Blocked so far: %d   Repeats hidden: %d   Blocked players' lines: %d"]):format(
        db.blocked, db.repeatsHidden, db.playerHidden))
    if ns.RefreshLogWindow then
        ns.RefreshLogWindow()
    end
end

function ns.CreateOptions()
    local main = createMain()
    category = register(main, addonName)
    register(createRules(), L["Rules"], category)
    register(createPlayers(), L["Players"], category)
    register(createExtras(), L["Extras"], category)
    ns.mainPanel = main
end

function ns.OpenOptions()
    if category then
        Settings.OpenToCategory(category:GetID())
    else
        -- Old Interface Options needs two calls the first time it opens.
        InterfaceOptionsFrame_OpenToCategory(ns.mainPanel)
        InterfaceOptionsFrame_OpenToCategory(ns.mainPanel)
    end
end
