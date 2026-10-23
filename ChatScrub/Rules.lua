-- Matching logic. No WoW API calls in this file, so tests/run_tests.lua can load
-- it in plain Lua. Core.lua decides which chat events reach Rules.Check.

local _, ns = ...
local Rules = {}
ns.Rules = Rules

-- Strip WoW markup so "|cffffd000|Hitem:...|h[Gold Coin]|h|r" reads as "[gold coin]".
function Rules.Normalize(msg)
    local s = msg
    s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    s = s:gsub("|H.-|h(.-)|h", "%1")
    s = s:gsub("|T.-|t", ""):gsub("|A.-|a", "")
    return s:lower()
end

-- Spammers swap digits for letters ("g0ld", "b00st", "c4rry", "go1d"). A 0 after
-- a letter becomes o; 1, 3, 4, 5 and 7 only change between two letters, so
-- prices like "500k" and "2v2" stay as they are. Run twice to catch "00".
local LOOKALIKE = { ["1"] = "l", ["3"] = "e", ["4"] = "a", ["5"] = "s", ["7"] = "t" }

function Rules.Loosen(lower)
    local s = lower
    for _ = 1, 2 do
        s = s:gsub("(%a)0", "%1o")
        s = s:gsub("(%a)([13457])(%a)", function(a, d, b) return a .. LOOKALIKE[d] .. b end)
    end
    return s
end

-- "g o l d", "b.o.o.s.t" and "c-a-r-r-y" become "gold", "boost", "carry". Runs of
-- three or more single letters split by one space, dot, dash, underscore or star
-- are joined; everything else is left alone.
function Rules.Squeeze(text)
    local out, i = {}, 1
    while true do
        local s = text:find("%f[%w]%a[ %.%-_%*]%a[ %.%-_%*]%a%f[%A]", i)
        if not s then
            break
        end
        local e = s + 4
        while text:sub(e + 1, e + 1):find("^[ %.%-_%*]$") and text:sub(e + 2, e + 2):find("^%a$")
            and not text:sub(e + 3, e + 3):find("^%a$") do
            e = e + 2
        end
        out[#out + 1] = text:sub(i, s - 1)
        out[#out + 1] = (text:sub(s, e):gsub("[ %.%-_%*]", ""))
        i = e + 1
    end
    out[#out + 1] = text:sub(i)
    return table.concat(out)
end

-- Each rule is a list of groups. A rule matches when every group has at least
-- one pattern found in the message. Two groups ("selling" AND "a service") keep
-- ordinary trade chat like "WTS [Linen Cloth]" from being caught. desc is the
-- plain-English summary shown in the options panel tooltip. defaultOff rules
-- are only used once turned on.
--
-- Patterns include German, French and Spanish words, since spam in those
-- realms uses them. Accented letters are spelled out as separate patterns
-- because Lua's [] classes work on bytes, not UTF-8 characters.
local SELLING = {
    "%f[%a]wts%f[%A]", "selling", "%f[%a]sell%f[%A]",
    "verkaufe", "%f[%a]vends?%f[%A]", "%f[%a]vendo%f[%A]", "%f[%a]venta%f[%A]",
}
local SERVICE = {
    "boost", "carry", "carries", "%f[%a]runs?%f[%A]", "%f[%a]keys?%f[%A]",
    "mythic", "%f[%a]m%+", "%f[%a]raid", "aotc", "curve", "cutting edge",
    "glad", "%f[%a]rating", "%f[%a]rbg", "%f[%a]arena", "leveling",
    "power ?level", "pilot", "achievement",
    "schlachtzug", "erfolg", "donjon", "mazmorra", "%f[%a]banda%f[%A]", "logro", "haut fait",
}

Rules.SPAM = {
    { id = "sells a boost/carry", desc = "WTS or selling, plus a service word (boost, carry, keys, mythic+, raid, arena, rating, leveling...)",
      SELLING, SERVICE },
    { id = "gold selling", desc = "gold, plus cheap, delivery, a real-money price or a website",
      { "gold", "%f[%a]oro%f[%A]", "pi\195\168ces d'or", "pieces d'or" },
      { "cheap", "delivery", "%f[%a]usd%f[%A]", "%$%s?%d", "%d%s?%$", "\226\130\172", "website", "%a%.com%f[%A]", "%a%.net%f[%A]",
        "billig", "g\195\188nstig", "lieferung", "pas cher", "livraison", "barato", "entrega" } },
    { id = "real-money payment", desc = "mentions PayPal, Venmo, Cash App, Zelle or Bitcoin",
      { "paypal", "venmo", "cash ?app", "zelle", "bitcoin" } },
    { id = "crypto sale", desc = "crypto or BTC, plus sell, buy or cheap",
      { "crypto", "%f[%a]btc%f[%A]" }, { "sell", "wts", "%f[%a]buy", "cheap" } },
    { id = "website ad", desc = "a web address, plus gold, boost, carry, sell, discount or promo",
      { "www%.", "%a%a%.com%f[%A]", "%a%.net%f[%A]", "%a%.gg/" },
      { "gold", "boost", "carry", "cheap", "sell", "wts", "discount", "promo" } },
    { id = "spam phrase", desc = "stock phrases like \"safe and fast\", \"cheapest\" or \"promo code\"",
      { "safe and fast", "fast and safe", "100%% safe", "hand ?made", "fast delivery",
        "cheapest", "discount code", "coupon code", "promo code",
        "schnell und sicher", "sicher und schnell", "rapide et s\195\187r", "rapide et sur",
        "r\195\161pido y seguro", "rapido y seguro" } },
    { id = "priced boost", desc = "boost, carry or piloted, plus a price like 300k or 2 mil",
      { "boost", "carry", "carries", "piloted" },
      { "%d%s?k%f[%A]", "%d%s?mil", "%f[%a]gold%f[%A]" } },
    { id = "guild recruitment", defaultOff = true,
      desc = "guild ads: recruiting or looking for members, plus a guild name or the word guild",
      { "recruit", "lf members", "looking for members", "looking for raiders", "looking for players",
        "is looking for", "join us", "rekrut", "sucht", "recrute", "recluta" },
      { "guild", "<.->", "gilde", "guilde", "hermandad" } },
}

-- overrides: { [rule.id] = true/false } from the player's settings.
function Rules.IsOn(rule, overrides)
    local v = overrides and overrides[rule.id]
    if v == nil then
        return not rule.defaultOff
    end
    return v
end

function Rules.Find(idOrNumber)
    local n = tonumber(idOrNumber)
    for i, rule in ipairs(Rules.SPAM) do
        if i == n or rule.id == idOrNumber then
            return rule, i
        end
    end
end

local function anyFound(text, patterns)
    for i = 1, #patterns do
        if text:find(patterns[i]) then
            return true
        end
    end
    return false
end

local function ruleMatches(text, rule)
    for g = 1, #rule do
        if not anyFound(text, rule[g]) then
            return false
        end
    end
    return true
end

-- Keywords are plain text by default. A * matches anything ("wts*carry"), and
-- a keyword starting with ~ is a raw Lua pattern for advanced users.
local cache = {}

function Rules.CompileKeyword(kw)
    local hit = cache[kw]
    if hit ~= nil then
        return hit
    end
    local compiled
    if kw:sub(1, 1) == "~" and #kw > 1 then
        local pattern = kw:sub(2)
        if pcall(string.find, "", pattern) then
            compiled = { pattern = pattern }
        else
            compiled = false
        end
    elseif kw:find("*", 1, true) then
        local pattern = kw:gsub("[%^%$%(%)%%%.%[%]%+%-%?]", "%%%0"):gsub("%*+", ".-")
        compiled = { pattern = pattern }
    else
        compiled = { plain = kw }
    end
    cache[kw] = compiled
    return compiled
end

-- True when kw is usable; false plus a reason when it's a broken ~pattern.
function Rules.ValidKeyword(kw)
    if Rules.CompileKeyword(kw) == false then
        return false, "that ~pattern isn't valid Lua pattern syntax"
    end
    return true
end

local function keywordFound(compiled, texts)
    for i = 1, #texts do
        local text = texts[i]
        if compiled.plain then
            if text:find(compiled.plain, 1, true) then
                return true
            end
        else
            local ok, found = pcall(string.find, text, compiled.pattern)
            if ok and found then
                return true
            end
        end
    end
    return false
end

-- The forms of msg that rules and keywords look at: lowercase, look-alikes
-- swapped, and spaced-out letters joined.
function Rules.Variants(msg)
    local lower = Rules.Normalize(msg)
    local loose = Rules.Loosen(lower)
    local squeezed = Rules.Squeeze(loose)
    local texts = { lower, loose }
    if squeezed ~= loose then
        texts[3] = squeezed
    end
    return texts
end

-- Returns a reason string and a hit-count key when msg should be hidden, or nil.
-- The third value is the matching keyword, if a keyword matched.
-- keywords: array of lowercase phrases. opts.spam turns on the built-in rules,
-- opts.rules holds per-rule on/off overrides.
function Rules.Check(msg, keywords, opts)
    if type(msg) ~= "string" or msg == "" then
        return nil
    end
    if type(opts) ~= "table" then
        opts = { spam = opts }
    end
    local texts = Rules.Variants(msg)

    for i = 1, #keywords do
        local kw = keywords[i]
        local compiled = kw ~= "" and Rules.CompileKeyword(kw)
        if compiled and keywordFound(compiled, texts) then
            return 'keyword "' .. kw .. '"', "kw:" .. kw, kw
        end
    end

    if opts.spam then
        for i = 1, #Rules.SPAM do
            local rule = Rules.SPAM[i]
            if Rules.IsOn(rule, opts.rules) then
                for t = 2, #texts do
                    if ruleMatches(texts[t], rule) then
                        return "spam: " .. rule.id, "rule:" .. rule.id
                    end
                end
            end
        end
    end
    return nil
end

-- True when msg contains any of phrases (plain, after normalizing).
function Rules.HasPhrase(msg, phrases)
    if type(msg) ~= "string" or #phrases == 0 then
        return nil
    end
    local texts = Rules.Variants(msg)
    for i = 1, #phrases do
        local compiled = phrases[i] ~= "" and Rules.CompileKeyword(phrases[i])
        if compiled and keywordFound(compiled, texts) then
            return phrases[i]
        end
    end
    return nil
end

-- Raid target icons, as typed ({rt1}, {skull}) or as texture markup.
local ICON_WORDS = {
    star = true, circle = true, coin = true, diamond = true, triangle = true,
    moon = true, square = true, cross = true, x = true, skull = true,
}

function Rules.StripIcons(msg)
    local total = 0
    local s = msg:gsub("{(%w+)}", function(word)
        local w = word:lower()
        if ICON_WORDS[w] or w:find("^rt[1-8]$") then
            total = total + 1
            return ""
        end
    end)
    local n
    s, n = s:gsub("|T[Ii]nterface\\[Tt]argeting[Ff]rame\\UI%-RaidTargetingIcon_%d.-|t", "")
    total = total + n
    if total == 0 then
        return msg, 0
    end
    return (s:gsub("  +", " "):gsub("^ ", ""):gsub(" $", "")), total
end
