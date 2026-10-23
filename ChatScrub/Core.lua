local addonName, ns = ...
local Rules, Lists = ns.Rules, ns.Lists

-- Lists, counters and the log are shared by every character on the account.
local DEFAULTS = {
    keywords = {},
    trial = {},          -- [keyword] = time it stops being a trial
    watch = {},
    allowPhrases = {},
    blockedPlayers = {}, -- [name] = { note = ... }
    allowPlayers = {},   -- [name] = { note = ..., expires = ... }
    hits = {},           -- [hit key] = count, see Rules.Check
    log = {},
    logSize = 50,
    blocked = 0,
    repeatsHidden = 0,
    playerHidden = 0,
    minimap = {},
}

-- Switches, which a character can keep its own copy of (/scrub char on).
local SETTINGS = {
    enabled = true,
    spamRules = true,
    rules = {},          -- [rule id] = true/false, overrides the rule's default
    repeats = true,
    repeatMinutes = 5,
    autoBlock = true,
    autoBlockHits = 3,
    watchSound = true,
    stripIcons = false,
    hideLoot = false,
    bubbles = true,
}

local TRIAL_SECONDS = 24 * 60 * 60
local WATCH_SOUND_GAP = 5

-- Public chat only. Guild, officer, party, raid and instance chat are never
-- filtered, and neither are your friends or guildmates (see isTrusted).
local EVENTS = {
    CHAT_MSG_CHANNEL = "Channel",
    CHAT_MSG_SAY = "Say",
    CHAT_MSG_YELL = "Yell",
    CHAT_MSG_WHISPER = "Whisper",
    CHAT_MSG_EMOTE = "Emote",
}

-- Repeated lines are only hidden in these; a whisper sent twice is usually
-- someone waiting on an answer.
local REPEAT_EVENTS = {
    CHAT_MSG_CHANNEL = true,
    CHAT_MSG_SAY = true,
    CHAT_MSG_YELL = true,
    CHAT_MSG_EMOTE = true,
}

local db, charDB
local repeats = ns.Repeats.New()       -- this session only, not saved
local offenders = Lists.NewOffenders() -- this session only
local sessionBlocked = {}              -- auto-blocked players, cleared on logout
local lastWatchSound = 0

local function say(text)
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99ChatScrub|r: " .. text)
end
ns.say = say

local function copy(value)
    if type(value) ~= "table" then
        return value
    end
    local t = {}
    for k, v in pairs(value) do
        t[k] = copy(v)
    end
    return t
end

function ns.GetDB()
    return db
end

-- The table the switches live in: this character's own copy, or the account's.
function ns.Settings()
    if charDB and charDB.useOwn then
        return charDB.settings
    end
    return db
end

local function cfg()
    return ns.Settings()
end

local function playerName()
    return UnitName("player")
end

local function shortName(author)
    return Ambiguate and Ambiguate(author, "short") or author
end

local function isSelf(author)
    local name = Ambiguate and Ambiguate(author, "none") or author
    return name == playerName()
end

local function isTrusted(guid)
    if guid and guid ~= "" then
        if C_FriendList and C_FriendList.IsFriend and C_FriendList.IsFriend(guid) then
            return true
        end
        if IsGuildMember and IsGuildMember(guid) then
            return true
        end
    end
    return false
end

local function addToLog(event, author, channelName, msg, reason)
    local log = db.log
    log[#log + 1] = {
        t = time(),
        who = shortName(author),
        author = author,
        where = (event == "CHAT_MSG_CHANNEL" and channelName ~= "" and channelName) or EVENTS[event],
        msg = msg,
        why = reason,
    }
    while #log > db.logSize do
        table.remove(log, 1)
    end
end

-- Splits keywords into ones that hide and ones still on trial.
local function splitKeywords(now)
    local active, trial = {}, {}
    for kw, ends in pairs(db.trial) do
        if now >= ends then
            db.trial[kw] = nil
        end
    end
    for _, kw in ipairs(db.keywords) do
        if db.trial[kw] then
            trial[#trial + 1] = kw
        else
            active[#active + 1] = kw
        end
    end
    return active, trial
end

local function isBlockedPlayer(author, now)
    return Lists.Find(db.blockedPlayers, author, now) or Lists.Find(sessionBlocked, author, now)
end

-- Watch words: the line stays, gets a marker, and a sound plays (at most once
-- every few seconds).
local function watchMark(msg)
    local word = Rules.HasPhrase(msg, db.watch)
    if not word then
        return nil
    end
    local now = GetTime()
    if cfg().watchSound and PlaySound and SOUNDKIT and now - lastWatchSound >= WATCH_SOUND_GAP then
        PlaySound(SOUNDKIT.TELL_MESSAGE or SOUNDKIT.RAID_WARNING)
        lastWatchSound = now
    end
    return "|cffffd100[" .. word .. "]|r " .. msg
end

-- Decides one line. Returns hide, and a replacement message when the shown
-- line was changed (watch marker, raid icons removed).
local function decide(event, msg, author, channelName, guid)
    local s = cfg()
    local now = time()
    if isSelf(author) then
        return false
    end

    local allowed = Lists.Find(db.allowPlayers, author, now) or isTrusted(guid)
    if not allowed then
        if isBlockedPlayer(author, now) then
            db.playerHidden = db.playerHidden + 1
            return true
        end
        allowed = Rules.HasPhrase(msg, db.allowPhrases)
    end

    if not allowed then
        local where = event == "CHAT_MSG_CHANNEL" and channelName or event
        -- Checked before the rules so a spam line reposted every minute is
        -- logged once, not every time.
        if s.repeats and REPEAT_EVENTS[event] and repeats:IsRepeat(
                ns.Repeats.Key(where, author, msg), GetTime(), s.repeatMinutes * 60) then
            db.repeatsHidden = db.repeatsHidden + 1
            return true
        end

        local active, trial = splitKeywords(now)
        local reason, key = Rules.Check(msg, active, { spam = s.spamRules, rules = s.rules })
        if not reason and #trial > 0 then
            local trialReason = Rules.Check(msg, trial, false)
            if trialReason then
                addToLog(event, author, channelName, msg, trialReason .. " (trial, shown)")
            end
        end
        if reason then
            db.blocked = db.blocked + 1
            db.hits[key] = (db.hits[key] or 0) + 1
            addToLog(event, author, channelName, msg, reason)
            if s.autoBlock and key:find("^rule:") and Lists.Strike(offenders, author, s.autoBlockHits) then
                Lists.Add(sessionBlocked, author)
                say(("%s keeps spamming, so everything they say is hidden until you log out. /scrub unblock %s undoes it."):format(
                    shortName(author), shortName(author)))
            end
            return true
        end
    end

    local shown = msg
    if s.stripIcons then
        shown = Rules.StripIcons(shown)
    end
    shown = watchMark(shown) or shown
    if shown ~= msg then
        return false, shown
    end
    return false
end
ns.Decide = decide

-- WoW calls the filter once per chat window that shows the event, so the same
-- line can arrive several times. lineID (arg11) lets us decide and log it once.
local lastLineID, lastHide, lastShown

local function filter(_, event, msg, author, ...)
    if not db or not cfg().enabled then
        return false
    end
    local lineID = select(9, ...)
    -- Retail 12.x hides some chat contents from addons in restricted content
    -- ("secret values"); touching them errors, so let those lines through.
    if issecretvalue and (issecretvalue(msg) or issecretvalue(author) or issecretvalue(lineID)) then
        return false
    end
    if not (lineID and lineID == lastLineID) then
        lastLineID = lineID
        lastHide, lastShown = decide(event, msg, author, select(7, ...) or "", select(10, ...))
        if lastHide and ns.HideBubble and cfg().bubbles and (event == "CHAT_MSG_SAY" or event == "CHAT_MSG_YELL") then
            ns.HideBubble(msg)
        end
    end
    if lastShown then
        return false, lastShown, author, ...
    end
    return lastHide
end

-- Other players' loot lines. Your own loot (or lines with no looter named)
-- always shows.
local function lootFilter(_, _, msg, author)
    if not db or not cfg().enabled or not cfg().hideLoot then
        return false
    end
    if issecretvalue and (issecretvalue(msg) or issecretvalue(author)) then
        return false
    end
    return type(author) == "string" and author ~= "" and not isSelf(author)
end

local addFilter = ChatFrame_AddMessageEventFilter
    or (ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter)
for event in pairs(EVENTS) do
    addFilter(event, filter)
end
addFilter("CHAT_MSG_LOOT", lootFilter)

-- Keyword list helpers, shared with Options.lua.
local function clean(text)
    return (text or ""):gsub("^%s+", ""):gsub("%s+$", ""):lower()
end

local function addTo(list, text, what)
    local item = clean(text)
    if item == "" then
        return false, "nothing to add"
    end
    local ok, why = Rules.ValidKeyword(item)
    if not ok then
        return false, why
    end
    for _, existing in ipairs(list) do
        if existing == item then
            return false, '"' .. item .. '" is already on the ' .. what .. " list"
        end
    end
    list[#list + 1] = item
    return true, 'added "' .. item .. '"'
end

local function removeFrom(list, text, what)
    local n = tonumber(text)
    local item = clean(text)
    for i, existing in ipairs(list) do
        if i == n or existing == item then
            table.remove(list, i)
            return true, 'removed "' .. existing .. '"', existing
        end
    end
    return false, '"' .. item .. '" is not on the ' .. what .. " list"
end

function ns.AddKeyword(text)
    return addTo(db.keywords, text, "keyword")
end

function ns.RemoveKeyword(text)
    local ok, reply, kw = removeFrom(db.keywords, text, "keyword")
    if kw then
        db.trial[kw] = nil
    end
    return ok, reply
end

function ns.TryKeyword(text)
    local ok, reply = addTo(db.keywords, text, "keyword")
    if ok then
        local kw = clean(text)
        db.trial[kw] = time() + TRIAL_SECONDS
        return true, 'trying "' .. kw .. '" for 24 hours: matches go to the log but stay visible. After that it hides them.'
    end
    return ok, reply
end

local function setList(list, lines)
    wipe(list)
    for _, line in ipairs(lines) do
        addTo(list, line, "")
    end
end

function ns.SetKeywords(lines)
    setList(db.keywords, lines)
    local keep = {}
    for _, kw in ipairs(db.keywords) do
        keep[kw] = true
    end
    for kw in pairs(db.trial) do
        if not keep[kw] then
            db.trial[kw] = nil
        end
    end
end

function ns.SetWatch(lines)
    setList(db.watch, lines)
end

function ns.SetAllowPhrases(lines)
    setList(db.allowPhrases, lines)
end

-- Replaces a player list from text lines, keeping notes and expiry dates of
-- names that are still there.
function ns.SetPlayers(list, lines)
    local old = copy(list)
    wipe(list)
    for _, line in ipairs(lines) do
        local key = Lists.Key(line)
        if key ~= "" then
            list[key] = old[key] or {}
        end
    end
end

function ns.BlockPlayer(name, note)
    local key = Lists.Add(db.blockedPlayers, name, note)
    if not key then
        return false, "whose lines should be hidden? /scrub block <name>"
    end
    Lists.Remove(db.allowPlayers, key)
    return true, ("blocked %s: everything they say in public chat is hidden."):format(key)
end

function ns.UnblockPlayer(name)
    local a = Lists.Remove(db.blockedPlayers, name)
    local b = Lists.Remove(sessionBlocked, name)
    if a or b then
        return true, "unblocked " .. Lists.Key(name) .. "."
    end
    return false, Lists.Key(name) .. " isn't blocked."
end

function ns.AllowPlayer(name, days, note)
    local expires = days and time() + days * 24 * 60 * 60 or nil
    local key = Lists.Add(db.allowPlayers, name, note, expires)
    if not key then
        return false, "who should never be hidden? /scrub allow <name> [days] [note]"
    end
    Lists.Remove(db.blockedPlayers, key)
    Lists.Remove(sessionBlocked, key)
    return true, ("%s is never hidden%s."):format(key, days and (" for " .. days .. " days") or "")
end

-- Name list for chat output: "bob-realm (note, until 29 Oct)".
local function describePlayers(list)
    local out = {}
    for _, key in ipairs(Lists.Names(list, time())) do
        local e = list[key]
        local extra = {}
        if e.note then
            extra[#extra + 1] = e.note
        end
        if e.expires then
            extra[#extra + 1] = "until " .. date("%d %b", e.expires)
        end
        out[#out + 1] = #extra > 0 and (key .. " (" .. table.concat(extra, ", ") .. ")") or key
    end
    return out
end
ns.DescribePlayers = describePlayers

function ns.SessionBlocked()
    return Lists.Names(sessionBlocked, time())
end

function ns.Hits(key)
    return db.hits[key] or 0
end

function ns.PrintLog(count)
    local log = db.log
    if #log == 0 then
        say("nothing blocked yet.")
        return
    end
    count = math.min(count or 20, #log)
    say(("last %d blocked (oldest first):"):format(count))
    for i = #log - count + 1, #log do
        ns.PrintLogEntry(log[i])
    end
end

function ns.PrintLogEntry(e)
    DEFAULT_CHAT_FRAME:AddMessage(("|cff888888%s %s|r %s: %s |cffff7070(%s)|r"):format(
        date("%H:%M", e.t), e.where, e.who, e.msg, e.why))
end

-- Per-character switches. Turning it on starts from the account's current values.
function ns.UseCharacterSettings(on)
    if on and not charDB.useOwn then
        charDB.settings = {}
        for key in pairs(SETTINGS) do
            charDB.settings[key] = copy(db[key])
        end
    end
    charDB.useOwn = on
end

function ns.UsingCharacterSettings()
    return charDB and charDB.useOwn or false
end

function ns.Import(text)
    local lists, count = ns.Share.Decode(text)
    if not lists then
        return false, count
    end
    local added = 0
    for _, field in ipairs({ "keywords", "watch", "allowPhrases" }) do
        for _, item in ipairs(lists[field] or {}) do
            if addTo(db[field], item, "") then
                added = added + 1
            end
        end
    end
    for _, field in ipairs({ "blockedPlayers", "allowPlayers" }) do
        for _, name in ipairs(lists[field] or {}) do
            if not db[field][Lists.Key(name)] then
                Lists.Add(db[field], name)
                added = added + 1
            end
        end
    end
    return true, ("imported %d new entries (%d in the text)."):format(added, count)
end

function ns.Export()
    return ns.Share.Encode(db)
end

local function onOff(value)
    return value and "|cff00ff00on|r" or "|cffff4040off|r"
end
ns.OnOff = onOff

local HELP = {
    "Keywords:",
    "/scrub add <phrase> - hide lines containing it (* is a wildcard, ~ starts a Lua pattern)",
    "/scrub try <phrase> - log matches for 24 hours before hiding them",
    "/scrub remove <phrase or number>, /scrub list",
    "/scrub watch [phrase] - highlight lines with it and play a sound; /scrub unwatch <phrase or number>",
    "Players:",
    "/scrub block <name> [note], /scrub unblock <name>, /scrub blocked",
    "/scrub allow <name> [days] [note] - never hide them; /scrub unallow <name>, /scrub allowed",
    "/scrub allowphrase <text> - never hide lines with it; /scrub unallowphrase <text or number>",
    "/scrub autoblock on|off|<hits> - hide a sender for the session after that many spam hits",
    "Rules and switches:",
    "/scrub rules - list the built-in rules; /scrub rule <number or name> on|off",
    "/scrub spam on|off, /scrub on|off, /scrub repeats on|off|<minutes>",
    "/scrub icons on|off - remove raid icons; /scrub loot on|off - hide others' loot; /scrub bubbles on|off",
    "/scrub char on|off - give this character its own switches",
    "Other:",
    "/scrub log [n] - open the log window, or print the last n lines; /scrub clearlog",
    "/scrub test <text>, /scrub export, /scrub import, /scrub options, /scrub minimap",
}

local function printHelp()
    local s = cfg()
    say(("filtering %s, spam rules %s, repeats %s (%d min), %d keywords, %d blocked, %d repeats hidden%s."):format(
        onOff(s.enabled), onOff(s.spamRules), onOff(s.repeats), s.repeatMinutes,
        #db.keywords, db.blocked, db.repeatsHidden,
        ns.UsingCharacterSettings() and ", this character's own switches" or ""))
    for _, line in ipairs(HELP) do
        if line:sub(1, 1) == "/" then
            DEFAULT_CHAT_FRAME:AddMessage("  " .. line)
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cffffd100" .. line .. "|r")
        end
    end
end

local function printList(title, items, empty)
    if #items == 0 then
        say(empty)
        return
    end
    say(title)
    for i, item in ipairs(items) do
        DEFAULT_CHAT_FRAME:AddMessage(("  %d. %s"):format(i, item))
    end
end

local function toggle(field, rest, label)
    local s = cfg()
    if rest == "on" or rest == "off" then
        s[field] = rest == "on"
    else
        s[field] = not s[field]
    end
    say(label .. " " .. onOff(s[field]))
end

local commands = {}

commands.add = function(rest) say(select(2, ns.AddKeyword(rest))) end
commands.try = function(rest) say(select(2, ns.TryKeyword(rest))) end
commands.remove = function(rest) say(select(2, ns.RemoveKeyword(rest))) end
commands.del = commands.remove
commands.list = function()
    local items = {}
    for _, kw in ipairs(db.keywords) do
        items[#items + 1] = ("%s |cff888888(%d hidden%s)|r"):format(kw, ns.Hits("kw:" .. kw),
            db.trial[kw] and ", trial" or "")
    end
    printList("keywords:", items, "no keywords yet. Add one with /scrub add <phrase>.")
end
commands.watch = function(rest)
    if rest == "" then
        printList("watch words:", db.watch, "no watch words. /scrub watch <phrase> adds one.")
    else
        say(select(2, addTo(db.watch, rest, "watch")))
    end
end
commands.unwatch = function(rest) say(select(2, removeFrom(db.watch, rest, "watch"))) end
commands.block = function(rest)
    local name, note = rest:match("^(%S*)%s*(.-)$")
    say(select(2, ns.BlockPlayer(name, note)))
end
commands.unblock = function(rest) say(select(2, ns.UnblockPlayer(rest))) end
commands.blocked = function()
    local items = describePlayers(db.blockedPlayers)
    for _, key in ipairs(ns.SessionBlocked()) do
        items[#items + 1] = key .. " (auto-blocked until logout)"
    end
    printList("blocked players:", items, "nobody is blocked.")
end
commands.allow = function(rest)
    local name, days, note = rest:match("^(%S*)%s*(%d*)%s*(.-)$")
    say(select(2, ns.AllowPlayer(name, tonumber(days), note)))
end
commands.unallow = function(rest)
    say(Lists.Remove(db.allowPlayers, rest) and ("removed " .. Lists.Key(rest) .. ".") or (Lists.Key(rest) .. " isn't on the allowed list."))
end
commands.allowed = function()
    printList("never hidden:", describePlayers(db.allowPlayers), "no allowed players.")
    if #db.allowPhrases > 0 then
        printList("never hidden phrases:", db.allowPhrases, "")
    end
end
commands.allowphrase = function(rest) say(select(2, addTo(db.allowPhrases, rest, "allowed phrase"))) end
commands.unallowphrase = function(rest) say(select(2, removeFrom(db.allowPhrases, rest, "allowed phrase"))) end
commands.autoblock = function(rest)
    local n = tonumber(rest)
    if n then
        if n < 1 or n > 20 then
            say("pick between 1 and 20 hits.")
        else
            cfg().autoBlock, cfg().autoBlockHits = true, math.floor(n)
            say(("auto-block %s after %d spam hits from the same player."):format(onOff(true), cfg().autoBlockHits))
        end
    else
        toggle("autoBlock", rest, "auto-block")
    end
end
commands.rules = function()
    say("built-in rules (spam rules are " .. onOff(cfg().spamRules) .. "):")
    for i, rule in ipairs(Rules.SPAM) do
        DEFAULT_CHAT_FRAME:AddMessage(("  %d. %s %s |cff888888- %s (%d hidden)|r"):format(
            i, rule.id, onOff(Rules.IsOn(rule, cfg().rules)), rule.desc, ns.Hits("rule:" .. rule.id)))
    end
end
commands.rule = function(rest)
    local which, state = rest:match("^(.-)%s+(%a+)$")
    local rule = which and Rules.Find(which:lower())
    if not rule or (state ~= "on" and state ~= "off") then
        say("use /scrub rule <number or name> on|off. /scrub rules lists them.")
        return
    end
    cfg().rules[rule.id] = state == "on"
    say(rule.id .. " " .. onOff(state == "on"))
end
commands.log = function(rest)
    local n = tonumber(rest)
    if n or not ns.ToggleLogWindow then
        ns.PrintLog(n)
    else
        ns.ToggleLogWindow()
    end
end
commands.clearlog = function()
    wipe(db.log)
    say("log cleared.")
end
commands.test = function(rest)
    local reason = Rules.Check(rest, db.keywords, { spam = cfg().spamRules, rules = cfg().rules })
    say(reason and ("would hide it (" .. reason .. ")") or "would show it.")
end
commands.spam = function(rest) toggle("spamRules", rest, "spam rules") end
commands.repeats = function(rest)
    local n = tonumber(rest)
    if not n then
        toggle("repeats", rest, "repeat filter")
        return
    end
    local minutes = math.floor(n)
    if minutes < 1 or minutes > 60 then
        say("pick between 1 and 60 minutes.")
    else
        cfg().repeats, cfg().repeatMinutes = true, minutes
        say(("repeat filter %s: same line from the same player within %d min is hidden."):format(onOff(true), minutes))
    end
end
commands.icons = function(rest) toggle("stripIcons", rest, "raid icon removal") end
commands.loot = function(rest) toggle("hideLoot", rest, "hiding other players' loot") end
commands.bubbles = function(rest) toggle("bubbles", rest, "hiding chat bubbles of hidden lines") end
commands.sound = function(rest) toggle("watchSound", rest, "watch word sound") end
commands.on = function() cfg().enabled = true; say("filtering " .. onOff(true)) end
commands.off = function() cfg().enabled = false; say("filtering " .. onOff(false)) end
commands.char = function(rest)
    local on
    if rest == "on" or rest == "off" then
        on = rest == "on"
    else
        on = not ns.UsingCharacterSettings()
    end
    ns.UseCharacterSettings(on)
    say(on and "this character now has its own switches (lists stay shared)." or "this character uses the account-wide switches again.")
end
commands.export = function()
    if ns.ShowShareWindow then
        ns.ShowShareWindow("export")
    else
        say(ns.Export())
    end
end
commands.import = function()
    if ns.ShowShareWindow then
        ns.ShowShareWindow("import")
    end
end
commands.options = function() ns.OpenOptions() end
commands.config = commands.options
commands.minimap = function()
    db.minimap.hide = not db.minimap.hide
    say("minimap button " .. (db.minimap.hide and "hidden. /scrub minimap brings it back." or "shown."))
end

SLASH_CHATSCRUB1 = "/scrub"
SLASH_CHATSCRUB2 = "/chatscrub"
SlashCmdList.CHATSCRUB = function(input)
    if not db then
        return
    end
    local cmd, rest = (input or ""):match("^%s*(%S*)%s*(.-)%s*$")
    local handler = commands[cmd:lower()]
    if handler then
        handler(rest)
    else
        printHelp()
    end
    ns.RefreshOptions()
    ns.UpdateMinimapButton()
end

local function fillDefaults(target, defaults)
    for key, value in pairs(defaults) do
        if target[key] == nil then
            target[key] = copy(value)
        end
    end
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, _, name)
    if name ~= addonName then
        return
    end
    ChatScrubDB = ChatScrubDB or {}
    fillDefaults(ChatScrubDB, DEFAULTS)
    fillDefaults(ChatScrubDB, SETTINGS)
    db = ChatScrubDB
    ChatScrubCharDB = ChatScrubCharDB or {}
    charDB = ChatScrubCharDB
    charDB.settings = charDB.settings or {}
    fillDefaults(charDB.settings, SETTINGS)
    ns.CreateOptions()
    ns.CreateMinimapButton()
    if ns.SetUpMenus then
        ns.SetUpMenus()
    end
    self:UnregisterEvent("ADDON_LOADED")
end)
