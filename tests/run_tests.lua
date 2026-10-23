-- Run from the repo root: luajit tests/run_tests.lua  (or lua tests/run_tests.lua)
-- Loads the addon files with tiny stand-ins for the WoW API.

local failures, passes = 0, 0
local function check(name, cond, detail)
    if cond then
        passes = passes + 1
    else
        failures = failures + 1
        print("FAIL: " .. name .. (detail and ("  -> " .. tostring(detail)) or ""))
    end
end

---------------------------------------------------------------- WoW stubs
local filters, frames, printed = {}, {}, {}
local function stubFrame()
    local f = { scripts = {} }
    return setmetatable(f, { __index = function(t, k)
        if k == "SetScript" then
            return function(self, name, fn) self.scripts[name] = fn end
        elseif k == "GetText" then
            return function(self) return self.text or "" end
        elseif k == "SetText" then
            return function(self, v) self.text = v end
        elseif k == "HasFocus" or k == "GetChecked" then
            return function() return false end
        elseif k == "CreateFontString" or k == "CreateTexture" then
            return function() return stubFrame() end
        elseif k == "SetPoint" then
            return function(self, ...) self.point = { ... } end
        elseif k == "Show" then
            return function(self) self.shown = true end
        elseif k == "Hide" then
            return function(self) self.shown = false end
        end
        return function() end
    end })
end
CreateFrame = function() local f = stubFrame(); frames[#frames + 1] = f; return f end
ChatFrame_AddMessageEventFilter = function(event, fn) filters[event] = fn end
DEFAULT_CHAT_FRAME = { AddMessage = function(_, text) printed[#printed + 1] = text end }
UnitName = function() return "Me" end
Ambiguate = function(name) return (name:gsub("%-.*", "")) end
C_FriendList = { IsFriend = function(guid) return guid == "Player-friend" end }
IsGuildMember = function(guid) return guid == "Player-guildie" end
SlashCmdList = {}
Settings = {
    RegisterCanvasLayoutCategory = function() return { GetID = function() return 1 end } end,
    RegisterAddOnCategory = function() end,
    RegisterCanvasLayoutSubcategory = function() end,
}
ChatFontNormal = {}
Minimap = {
    GetWidth = function() return 140 end,
    GetCenter = function() return 1000, 700 end,
    GetEffectiveScale = function() return 1 end,
}
local cursorX, cursorY = 0, 0
GetCursorPosition = function() return cursorX, cursorY end
local tooltipLines = {}
GameTooltip = {
    SetOwner = function() tooltipLines = {} end,
    AddLine = function(_, text) tooltipLines[#tooltipLines + 1] = text end,
    Show = function() end, Hide = function() end, IsOwned = function() return false end,
}
local openedOptions = 0
GetLocale = function() return "enUS" end
UIParent = {}
UISpecialFrames = {}
tinsert = table.insert
local played = 0
local menus = {}
Menu = { ModifyMenu = function(tag, fn) menus[tag] = fn end }
C_Timer = { After = function(_, fn) fn() end }
local bubbleText, bubbleHolder = nil, nil
C_ChatBubbles = { GetAllChatBubbles = function()
    if not bubbleText then return {} end
    local fs = { GetObjectType = function() return "FontString" end, GetText = function() return bubbleText end }
    bubbleHolder = { hidden = false, GetRegions = function() return fs end,
        Hide = function(self) self.hidden = true end, Show = function() end }
    return { { GetChildren = function() return bubbleHolder end, IsForbidden = function() return false end } }
end }
SOUNDKIT = { TELL_MESSAGE = 1 }
PlaySound = function() played = played + 1 end
local clock = 1000
GetTime = function() return clock end
time = os.time
date = os.date
wipe = function(t) for k in pairs(t) do t[k] = nil end return t end

local ns = {}
-- Same order as ChatScrub.toc.
local tocFiles = {}
for line in io.lines("ChatScrub/ChatScrub.toc") do
    if line:find("%.lua$") then tocFiles[#tocFiles + 1] = line end
end
for _, file in ipairs(tocFiles) do
    local chunk = assert(loadfile("ChatScrub/" .. file))
    chunk("ChatScrub", ns)
end
local Rules = ns.Rules

---------------------------------------------------------------- Rules.Check
local spam = {
    "WTS +15 keys boost, cheap and safe, /w me",
    "Selling Mythic+ carries all keys, 300k",
    "WTS AOTC heroic raid tonight, piloted or selfplay",
    "WTS gladiator rating boost",
    "Cheap g0ld fast delivery www.g0ldshop.com",
    "buy gold 5$ per 100k",
    "WTS curve and cutting edge, pay with paypal",
    "carry for 2 keys 500k each",
    "best service, 100% safe, handmade leveling",
    "visit mmocarry.com for boost",
    "|cffffd100|Hitem:1234|h[Bag]|h|r WTS b00st",
}
for _, msg in ipairs(spam) do
    check("spam caught: " .. msg, Rules.Check(msg, {}, true) ~= nil)
end

local normal = {
    "WTS [Linen Cloth] 5g each",
    "LF tank for +12 key",
    "anyone want to run Deadmines?",
    "how much gold for a token these days?",
    "WTB [Copper Ore] x20",
    "LFM ZG need healers, /w me",
    "Guild <Night Owls> recruiting casual raiders, discord.gg/abc123",
    "can someone carry me through the jumping puzzle lol",
    "selling [Heavy Leather] cheap, 20 stacks",
    "what's the price of [Arcanite Bar]?",
    "nice gold farm spot in Winterspring",
}
for _, msg in ipairs(normal) do
    local why = Rules.Check(msg, {}, true)
    check("normal kept: " .. msg, why == nil, why)
end

check("keyword match, case-insensitive", Rules.Check("Big ANAL joke incoming", { "anal" }, false) ~= nil)
check("keyword phrase", Rules.Check("time for chuck norris facts", { "chuck norris" }, false) ~= nil)
check("keyword through link markup", Rules.Check("|cff0070dd|Hitem:1|h[Spoiler Blade]|h|r", { "spoiler" }, false) ~= nil)
check("keyword with 0-for-o", Rules.Check("spoil3r alert, sp0iler", { "spoiler" }, false) ~= nil)
check("spam rules off", Rules.Check("WTS boost cheap", {}, false) == nil)
check("empty message", Rules.Check("", { "x" }, true) == nil)
check("keyword reason text", Rules.Check("hello there", { "hello" }, false) == 'keyword "hello"')

-- Look-alikes and spaced-out letters
check("1/3/4/5 look-alikes", Rules.Check("WTS c4rry, b3st pr1ce", {}, true) ~= nil)
check("go1d look-alike", Rules.Check("cheap go1d here", {}, true) ~= nil)
check("spaced letters", Rules.Check("W T S mythic c.a.r.r.y", {}, true) ~= nil)
check("dotted letters", Rules.Check("cheap g.o.l.d delivery", {}, true) ~= nil)
check("squeeze leaves words alone", Rules.Squeeze("wts gold now") == "wts gold now")
check("squeeze joins letters", Rules.Squeeze("buy g o l d now") == "buy gold now", Rules.Squeeze("buy g o l d now"))
check("prices untouched by look-alikes", Rules.Loosen("500k 2v2 3s") == "500k 2v2 3s", Rules.Loosen("500k 2v2 3s"))
check("keyword through spacing", Rules.Check("s p o i l e r ahead", { "spoiler" }, false) ~= nil)

-- Wildcards and patterns
check("wildcard keyword", Rules.Check("wts heroic raid carry", { "wts*carry" }, false) == 'keyword "wts*carry"')
check("wildcard needs order", Rules.Check("carry wts", { "wts*carry" }, false) == nil)
check("wildcard escapes magic chars", Rules.Check("m+ (fast)", { "m+*(fast)" }, false) ~= nil)
check("lua pattern keyword", Rules.Check("lf 2 dps", { "~lf %d dps" }, false) ~= nil)
check("bad pattern rejected", Rules.ValidKeyword("~[oops") == false)
check("bad pattern never matches", Rules.Check("[oops", { "~[oops" }, false) == nil)

-- Per-rule switches and the guild rule
local _, key = Rules.Check("buy gold cheap", {}, true)
check("hit key for rules", key == "rule:gold selling", key)
check("rule can be turned off", Rules.Check("buy gold cheap", {}, { spam = true, rules = { ["gold selling"] = false } }) == nil)
check("guild rule off by default", Rules.Check("<Night Owls> recruiting raiders", {}, true) == nil)
check("guild rule when on", Rules.Check("<Night Owls> recruiting raiders", {}, { spam = true, rules = { ["guild recruitment"] = true } })
    == "spam: guild recruitment")
check("find rule by number and id", Rules.Find(2) == Rules.Find("gold selling") and Rules.Find("nope") == nil)

-- Other languages
check("german spam", Rules.Check("Verkaufe Mythic+ Boost, billig", {}, true) ~= nil)
check("french spam", Rules.Check("vends boost raid mythique", {}, true) ~= nil)
check("spanish spam", Rules.Check("vendo oro barato", {}, true) ~= nil)
check("german chat kept", Rules.Check("Wer hat Lust auf eine Runde Schlachtzug?", {}, true) == nil)

-- Allow phrases and raid icons
check("allow phrase found", Rules.HasPhrase("WTS [Linen Cloth] 5g", { "wts [linen" }) == "wts [linen")
check("strip typed icons", select(1, Rules.StripIcons("{rt1}{Skull} LFM {star} ZG")) == "LFM ZG", (Rules.StripIcons("{rt1}{Skull} LFM {star} ZG")))
check("strip leaves other braces", Rules.StripIcons("{hello} there") == "{hello} there")
check("strip texture icons", Rules.StripIcons("|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_8:0|t go") == "go")

---------------------------------------------------------------- Core filter
frames[1].scripts.OnEvent(frames[1], "ADDON_LOADED", "ChatScrub")
local db = ChatScrubDB
check("saved variables created", db and db.enabled == true and db.spamRules == true)

local function fire(event, msg, author, lineID, guid, channelName)
    -- args after msg, author: language, channelString, target, flags, zoneChannelID,
    -- channelNumber, channelName, unused, lineID, guid
    return filters[event](nil, event, msg, author, "", "", "", "", 0, 2, channelName or "", 0, lineID, guid or "Player-x")
end

check("filters registered", filters.CHAT_MSG_CHANNEL and filters.CHAT_MSG_WHISPER and not filters.CHAT_MSG_GUILD)
check("spam hidden", fire("CHAT_MSG_CHANNEL", "WTS mythic carry 200k", "Spammer-Realm", 1, nil, "Trade") == true)
check("logged once", #db.log == 1 and db.blocked == 1)
check("same line in second chat window not double-counted",
    fire("CHAT_MSG_CHANNEL", "WTS mythic carry 200k", "Spammer-Realm", 1, nil, "Trade") == true and db.blocked == 1)
check("log entry fields", db.log[1].who == "Spammer" and db.log[1].where == "Trade" and db.log[1].why == "spam: sells a boost/carry")
check("normal shown", fire("CHAT_MSG_SAY", "hello", "Bob-Realm", 2) == false)
check("own message never hidden", fire("CHAT_MSG_SAY", "WTS boost cheap", "Me-Realm", 3) == false)
check("friend never hidden", fire("CHAT_MSG_WHISPER", "WTS boost cheap", "Pal-Realm", 4, "Player-friend") == false)
check("guildmate never hidden", fire("CHAT_MSG_CHANNEL", "WTS boost cheap", "Gm-Realm", 5, "Player-guildie") == false)

issecretvalue = function(v) return v == "SECRET" end
check("secret message passes through", fire("CHAT_MSG_SAY", "SECRET", "Bob-Realm", 6) == false)
issecretvalue = nil

SlashCmdList.CHATSCRUB("add  Chuck Norris ")
check("slash add trims and lowercases", db.keywords[1] == "chuck norris")
SlashCmdList.CHATSCRUB("add chuck norris")
check("slash add dedupes", #db.keywords == 1)
check("keyword hides line", fire("CHAT_MSG_CHANNEL", "Chuck Norris can divide by zero", "Joker-Realm", 7, nil, "General") == true)
SlashCmdList.CHATSCRUB("remove 1")
check("slash remove by number", #db.keywords == 0)
SlashCmdList.CHATSCRUB("off")
check("off disables", fire("CHAT_MSG_CHANNEL", "WTS boost cheap", "Spammer-Realm", 8) == false)
SlashCmdList.CHATSCRUB("on")

for i = 1, 60 do
    fire("CHAT_MSG_CHANNEL", "WTS boost cheap #" .. i, "Spammer" .. i .. "-Realm", 100 + i)
end
check("log capped at logSize", #db.log == db.logSize)

---------------------------------------------------------------- Repeat filter
check("repeats on by default", db.repeats == true and db.repeatMinutes == 5)
local repeatsBefore, blockedBefore, logBefore = db.repeatsHidden, db.blocked, #db.log
check("first line shown", fire("CHAT_MSG_CHANNEL", "LF tank for +12 key", "Rep-Realm", 300, nil, "Trade") == false)
clock = clock + 60
check("same line a minute later hidden",
    fire("CHAT_MSG_CHANNEL", "LF  Tank for +12 KEY ", "Rep-Realm", 301, nil, "Trade") == true)
check("repeat counted, not logged",
    db.repeatsHidden == repeatsBefore + 1 and db.blocked == blockedBefore and #db.log == logBefore)
check("repeat in a second chat window counted once",
    fire("CHAT_MSG_CHANNEL", "LF  Tank for +12 KEY ", "Rep-Realm", 301, nil, "Trade") == true
    and db.repeatsHidden == repeatsBefore + 1)
check("same text from another player shown", fire("CHAT_MSG_CHANNEL", "LF tank for +12 key", "Other-Realm", 302, nil, "Trade") == false)
check("same text in another channel shown", fire("CHAT_MSG_CHANNEL", "LF tank for +12 key", "Rep-Realm", 303, nil, "General") == false)
check("repeated whispers shown", fire("CHAT_MSG_WHISPER", "inv pls", "Pug-Realm", 304) == false
    and fire("CHAT_MSG_WHISPER", "inv pls", "Pug-Realm", 305) == false)
clock = clock + 4 * 60
check("hidden repeats don't extend the window",
    fire("CHAT_MSG_CHANNEL", "LF tank for +12 key", "Rep-Realm", 306, nil, "Trade") == false)
check("spam repeat hidden without a second log entry",
    fire("CHAT_MSG_CHANNEL", "WTS mythic carry 200k", "Spam2-Realm", 307, nil, "Trade") == true
    and fire("CHAT_MSG_CHANNEL", "WTS mythic carry 200k", "Spam2-Realm", 308, nil, "Trade") == true
    and #db.log == math.min(logBefore + 1, db.logSize) and db.log[#db.log].msg == "WTS mythic carry 200k"
    and db.log[#db.log - 1].msg ~= "WTS mythic carry 200k")
check("trusted senders' repeats shown", fire("CHAT_MSG_CHANNEL", "hi", "Gm-Realm", 309, "Player-guildie") == false
    and fire("CHAT_MSG_CHANNEL", "hi", "Gm-Realm", 310, "Player-guildie") == false)
SlashCmdList.CHATSCRUB("repeats off")
check("/scrub repeats off", db.repeats == false
    and fire("CHAT_MSG_CHANNEL", "LF tank for +12 key", "Rep-Realm", 311, nil, "Trade") == false)
SlashCmdList.CHATSCRUB("repeats 10")
check("/scrub repeats <minutes> sets window and turns on", db.repeats == true and db.repeatMinutes == 10)
SlashCmdList.CHATSCRUB("repeats 0")
check("/scrub repeats rejects 0", db.repeatMinutes == 10)
SlashCmdList.CHATSCRUB("repeats 5")
clock = clock + 6 * 60
check("line shown again after the window", fire("CHAT_MSG_CHANNEL", "LF tank for +12 key", "Rep-Realm", 312, nil, "Trade") == false)

printed = {}
SlashCmdList.CHATSCRUB("test cheap gold www.goldnow.com")
check("slash test reports", printed[1] and printed[1]:find("would hide"), printed[1])
printed = {}
SlashCmdList.CHATSCRUB("log 3")
check("slash log prints header + 3 lines", #printed == 4, #printed)

---------------------------------------------------------------- Options panel
for _, rule in ipairs(Rules.SPAM) do
    check("rule has a description: " .. rule.id, type(rule.desc) == "string" and rule.desc ~= "")
end
local spamBox = ns.Widgets.spamBox
check("spam checkbox has a tooltip", spamBox and spamBox.scripts.OnEnter ~= nil)
if spamBox then
    spamBox.scripts.OnEnter(spamBox)
    local tip = table.concat(tooltipLines, "|")
    local listed = 0
    for _, rule in ipairs(Rules.SPAM) do
        if tip:find(rule.id .. ":", 1, true) and tip:find(rule.desc, 1, true) then listed = listed + 1 end
    end
    check("rules tooltip lists every rule", listed == #Rules.SPAM, tip)
end
local repeatBox = ns.Widgets.repeatBox
check("repeat checkbox has a tooltip", repeatBox and repeatBox.scripts.OnEnter ~= nil)
if repeatBox then
    repeatBox.scripts.OnEnter(repeatBox)
    check("repeat tooltip names the window", table.concat(tooltipLines, "|"):find("5 minutes", 1, true))
end

---------------------------------------------------------------- Minimap button
local function near(a, b) return math.abs(a - b) < 1e-6 end
local x, y = ns.MinimapOffset(0, 75)
check("offset at 0 degrees is right", near(x, 75) and near(y, 0))
x, y = ns.MinimapOffset(90, 75)
check("offset at 90 degrees is top", near(x, 0) and near(y, 75))
check("angle from cursor above", near(ns.AngleFrom(0, 0, 0, 10), 90))
check("angle from cursor lower-left is 225", near(ns.AngleFrom(0, 0, -5, -5), 225))
check("angle is never negative", ns.AngleFrom(0, 0, 0, -10) >= 0)

local mm = frames[#frames]
for i = #frames, 1, -1 do
    if frames[i].scripts.OnDragStart then mm = frames[i] break end
end
check("minimap button created and shown", mm.scripts.OnDragStart and mm.shown == true)
check("default angle saved", db.minimap.angle == 225)
check("placed relative to minimap", mm.point and mm.point[2] == Minimap and mm.point[1] == "CENTER")

mm.scripts.OnEnter(mm)
local tip = table.concat(tooltipLines, "|")
check("tooltip shows on/off and count", tip:find("Filtering:") and tip:find("Blocked so far: " .. db.blocked, 1, true), tip)

ns.OpenOptions = function() openedOptions = openedOptions + 1 end
mm.scripts.OnClick(mm, "LeftButton")
check("left-click opens options", openedOptions == 1)
mm.scripts.OnClick(mm, "RightButton")
check("right-click turns filtering off", db.enabled == false)
mm.scripts.OnClick(mm, "RightButton")
check("right-click turns it back on", db.enabled == true)

-- Drag: cursor straight above the minimap center should move the button to 90 degrees.
mm.scripts.OnDragStart(mm)
cursorX, cursorY = 1000, 900
mm.scripts.OnUpdate(mm)
mm.scripts.OnDragStop(mm)
check("drag saves angle", near(db.minimap.angle, 90), db.minimap.angle)
check("drag moves button", near(mm.point[4], 0) and near(mm.point[5], 75), mm.point[4] .. "," .. mm.point[5])
check("drag stops following cursor", mm.scripts.OnUpdate == nil)

SlashCmdList.CHATSCRUB("minimap")
check("/scrub minimap hides", db.minimap.hide == true and mm.shown == false)
SlashCmdList.CHATSCRUB("minimap")
check("/scrub minimap shows again", db.minimap.hide == false and mm.shown == true)

---------------------------------------------------------------- New features
local function fireAll(event, msg, author, lineID, guid, channelName)
    return { filters[event](nil, event, msg, author, "", "", "", "", 0, 2, channelName or "", 0, lineID, guid or "Player-x") }
end
local nextID = 1000
local function line(msg, author, event, guid)
    nextID = nextID + 1
    return fire(event or "CHAT_MSG_CHANNEL", msg, author, nextID, guid, "Trade")
end
local function lineAll(msg, author, event)
    nextID = nextID + 1
    return fireAll(event or "CHAT_MSG_CHANNEL", msg, author, nextID, nil, "Trade")
end
db.repeats = false -- keep the repeat filter out of these checks

-- Blocking players
SlashCmdList.CHATSCRUB("block Annoy spams memes")
check("block hides everything", line("hello there", "Annoy-Realm") == true and line("nice weather", "Annoy-OtherRealm") == true)
check("block keeps note", db.blockedPlayers["annoy"] and db.blockedPlayers["annoy"].note == "spams memes")
check("blocked lines counted, not logged", db.playerHidden >= 2)
check("realm-specific block", select(1, ns.BlockPlayer("Pest-Realm")) and line("hi", "Pest-Other") == false and line("hi", "Pest-Realm") == true)
SlashCmdList.CHATSCRUB("unblock annoy")
check("unblock", line("hello again", "Annoy-Realm") == false)

-- Allowing players and phrases
SlashCmdList.CHATSCRUB("allow Seller 7 my crafter")
check("allowed player never hidden", line("WTS mythic carry 200k", "Seller-Realm") == false)
check("allow keeps note and expiry", db.allowPlayers["seller"].note == "my crafter" and db.allowPlayers["seller"].expires > os.time())
db.allowPlayers["seller"].expires = os.time() - 1
check("expired allow stops applying", line("WTS mythic carry 300k", "Seller-Realm") == true and db.allowPlayers["seller"] == nil)
SlashCmdList.CHATSCRUB("allowphrase wts mythic carry 400k")
check("allowed phrase shown", line("WTS mythic carry 400k", "Other1-Realm") == false)
SlashCmdList.CHATSCRUB("unallowphrase 1")
check("unallowphrase", #db.allowPhrases == 0)

-- Auto-block after repeated spam
local spammer = "Repeat-Spam"
for i = 1, 3 do line("WTS gold cheap #" .. i, spammer) end
printed = {}
check("auto-blocked after 3 spam hits", line("totally normal line", spammer) == true)
check("auto-block listed", table.concat(ns.SessionBlocked(), ","):find("repeat%-spam") ~= nil)
SlashCmdList.CHATSCRUB("unblock Repeat")
check("unblock clears auto-block", line("normal again", spammer) == false)
SlashCmdList.CHATSCRUB("autoblock off")
check("/scrub autoblock off", db.autoBlock == false)
SlashCmdList.CHATSCRUB("autoblock 5")
check("/scrub autoblock <n>", db.autoBlock == true and db.autoBlockHits == 5)

-- Hit counts
local before = ns.Hits("rule:gold selling")
line("buy gold cheap now", "Hits1-Realm")
check("rule hit counted", ns.Hits("rule:gold selling") == before + 1)
SlashCmdList.CHATSCRUB("add pineapple")
line("I love pineapple", "Hits2-Realm")
printed = {}
SlashCmdList.CHATSCRUB("list")
check("/scrub list shows counts", table.concat(printed, "|"):find("pineapple |cff888888(1 hidden)", 1, true), table.concat(printed, "|"))
SlashCmdList.CHATSCRUB("remove pineapple")

-- Per-rule switches by slash
SlashCmdList.CHATSCRUB("rule 2 off")
check("/scrub rule off", line("buy gold cheap again", "Rule1-Realm") == false)
SlashCmdList.CHATSCRUB("rule gold selling on")
check("/scrub rule by name on", line("buy gold cheap again!", "Rule2-Realm") == true)
printed = {}
SlashCmdList.CHATSCRUB("rules")
check("/scrub rules lists all", #printed == #Rules.SPAM + 1, #printed)

-- Trial keywords
SlashCmdList.CHATSCRUB("try banana")
local logCount = #db.log
check("trial keyword shows the line", line("banana bread", "Trial-Realm") == false)
check("trial match logged", db.log[#db.log].why:find("trial", 1, true) ~= nil)
db.trial["banana"] = os.time() - 1
check("trial ends, keyword hides", line("banana split", "Trial2-Realm") == true and db.trial["banana"] == nil)
SlashCmdList.CHATSCRUB("remove banana")

-- Watch words
SlashCmdList.CHATSCRUB("watch lf tank")
played = 0
local res = lineAll("LF tank for +10", "Watch-Realm")
check("watch line shown with marker", res[1] == false and res[2] == "|cffffd100[lf tank]|r LF tank for +10", tostring(res[2]))
check("watch passes the other args back", res[3] == "Watch-Realm" and #res > 10)
check("watch plays a sound", played == 1)
lineAll("LF tank please", "Watch2-Realm")
check("watch sound throttled", played == 1)
check("watch works for guildmates", line("lf tank", "Gm-Realm", nil, "Player-guildie") == false)
SlashCmdList.CHATSCRUB("unwatch 1")

-- Raid icons
SlashCmdList.CHATSCRUB("icons on")
res = lineAll("{skull} LFM ZG {rt1}", "Icon-Realm")
check("icons stripped", res[1] == false and res[2] == "LFM ZG", tostring(res[2]))
res = lineAll("LFM ZG plain", "Icon2-Realm")
check("unchanged lines pass untouched", res[1] == false and res[2] == nil)
SlashCmdList.CHATSCRUB("icons off")

-- Loot
check("loot shown by default", filters.CHAT_MSG_LOOT(nil, "CHAT_MSG_LOOT", "Bob receives loot: [Rag]", "Bob-Realm") == false)
SlashCmdList.CHATSCRUB("loot on")
check("others' loot hidden", filters.CHAT_MSG_LOOT(nil, "CHAT_MSG_LOOT", "Bob receives loot: [Rag]", "Bob-Realm") == true)
check("own loot shown", filters.CHAT_MSG_LOOT(nil, "CHAT_MSG_LOOT", "You receive loot: [Rag]", "Me-Realm") == false)
check("loot without looter shown", filters.CHAT_MSG_LOOT(nil, "CHAT_MSG_LOOT", "Everyone passed", "") == false)
SlashCmdList.CHATSCRUB("loot off")

-- Chat bubbles
bubbleText = "WTS mythic carry 900k"
line("WTS mythic carry 900k", "Bubble-Realm", "CHAT_MSG_SAY")
check("bubble of hidden say line hidden", bubbleHolder and bubbleHolder.hidden == true)
bubbleText, bubbleHolder = "hello friend", nil
line("hello friend", "Bubble2-Realm", "CHAT_MSG_SAY")
check("bubble of shown line left alone", bubbleHolder == nil or bubbleHolder.hidden == false)
bubbleText = nil

-- Per-character switches
SlashCmdList.CHATSCRUB("char on")
check("char settings start as a copy", ns.UsingCharacterSettings() and ns.Settings().autoBlockHits == 5 and ns.Settings() ~= db)
SlashCmdList.CHATSCRUB("spam off")
check("char switch doesn't touch account", ns.Settings().spamRules == false and db.spamRules == true)
check("char switch applies", line("buy gold cheap char", "Char-Realm") == false)
SlashCmdList.CHATSCRUB("char off")
check("back to account switches", ns.Settings() == db and line("buy gold cheap acct", "Char2-Realm") == true)

-- Import/export
SlashCmdList.CHATSCRUB("add export me")
SlashCmdList.CHATSCRUB("watch heals")
ns.BlockPlayer("Rude-Realm")
local text = ns.Export()
check("export has header and entries", text:find("^ChatScrub export v1") and text:find("keyword: export me", 1, true)
    and text:find("watch: heals", 1, true) and text:find("block: rude-realm", 1, true), text)
local decoded, n = ns.Share.Decode(text .. "\njunk line\nkeyword: another one")
check("decode reads entries, skips junk", decoded.keywords[#decoded.keywords] == "another one" and n >= 4)
check("decode rejects other text", ns.Share.Decode("hello") == nil)
local kwCount = #db.keywords
local ok, reply = ns.Import(text .. "\nkeyword: brand new\nallow: friendly")
check("import adds only new entries", ok and #db.keywords == kwCount + 1 and db.allowPlayers["friendly"] ~= nil, reply)

-- Editing player lists keeps notes
ns.BlockPlayer("Noted", "reason here")
ns.SetPlayers(db.blockedPlayers, { "noted", "Fresh-Realm", "" })
check("list edit keeps notes, adds new, drops removed",
    db.blockedPlayers["noted"].note == "reason here" and db.blockedPlayers["fresh-realm"] and not db.blockedPlayers["rude-realm"])

-- Log search
local found = ns.Lists.SearchLog({ { who = "Bob", where = "Trade", msg = "WTS gold", why = "spam" },
    { who = "Al", where = "Say", msg = "hi", why = 'keyword "hi"' } }, "trade")
check("log search", #found == 1 and found[1].who == "Bob")
check("empty search returns all", #ns.Lists.SearchLog(db.log, "") == #db.log)

-- Right-click menu
local items = {}
local root = { CreateDivider = function() end, CreateTitle = function() end,
    CreateButton = function(_, text, fn) items[#items + 1] = { text = text, fn = fn } end }
check("menus registered", menus.MENU_UNIT_FRIEND ~= nil)
menus.MENU_UNIT_FRIEND(nil, root, { name = "Menuguy", server = "Realm" })
check("menu offers block and allow", #items == 2 and items[1].text:find("Block"))
items[1].fn()
check("menu block works", db.blockedPlayers["menuguy-realm"] ~= nil)
items = {}
menus.MENU_UNIT_FRIEND(nil, root, { name = "Me" })
check("no menu items for yourself", #items == 0)

-- Windows build without errors
local okLog = pcall(ns.ToggleLogWindow)
check("log window opens", okLog)
local okShare = pcall(ns.ShowShareWindow, "export")
check("export window opens", okShare)
printed = {}
SlashCmdList.CHATSCRUB("")
check("help lists the new commands", table.concat(printed, "|"):find("/scrub block", 1, true) ~= nil)

print(("%d passed, %d failed"):format(passes, failures))
os.exit(failures == 0 and 0 or 1)
