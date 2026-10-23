-- Import/export of keyword and player lists as plain text, one entry per line.
-- No WoW API calls, so tests can load it in plain Lua.

local _, ns = ...
local Share = {}
ns.Share = Share

local HEADER = "ChatScrub export v1"

-- Line prefix for each list, in export order.
Share.KINDS = {
    { prefix = "keyword", field = "keywords" },
    { prefix = "watch", field = "watch" },
    { prefix = "allowphrase", field = "allowPhrases" },
    { prefix = "block", field = "blockedPlayers", keyed = true },
    { prefix = "allow", field = "allowPlayers", keyed = true },
}

-- lists: { keywords = {...}, watch = {...}, allowPhrases = {...},
-- blockedPlayers = { [name] = entry }, allowPlayers = { [name] = entry } }
function Share.Encode(lists)
    local out = { HEADER }
    for _, kind in ipairs(Share.KINDS) do
        local items = lists[kind.field] or {}
        if kind.keyed then
            local names = {}
            for name in pairs(items) do
                names[#names + 1] = name
            end
            table.sort(names)
            items = names
        end
        for _, item in ipairs(items) do
            out[#out + 1] = kind.prefix .. ": " .. item
        end
    end
    return table.concat(out, "\n")
end

-- Returns { field = { entries... } } plus the number of entries read, or nil
-- and a reason. Unknown lines are skipped so hand-edited text still imports.
function Share.Decode(text)
    if type(text) ~= "string" or not text:find(HEADER, 1, true) then
        return nil, "that doesn't look like a ChatScrub export (it should start with \"" .. HEADER .. "\")"
    end
    local byPrefix = {}
    for _, kind in ipairs(Share.KINDS) do
        byPrefix[kind.prefix] = kind
    end
    local result, count = {}, 0
    for line in (text .. "\n"):gmatch("(.-)\r?\n") do
        local prefix, value = line:match("^%s*(%a+):%s*(.-)%s*$")
        local kind = prefix and byPrefix[prefix:lower()]
        if kind and value ~= "" then
            result[kind.field] = result[kind.field] or {}
            table.insert(result[kind.field], value:lower())
            count = count + 1
        end
    end
    return result, count
end
