-- Player lists (blocked, allowed), repeat offenders and log search. No WoW API
-- calls (callers pass names and times in), so tests can load it in plain Lua.

local _, ns = ...
local Lists = {}
ns.Lists = Lists

-- Names are stored lowercase. "Bob" matches Bob on any realm; "Bob-Realm" only
-- that realm. Chat gives authors as "Name-Realm".
function Lists.Key(name)
    return ((name or ""):gsub("^%s+", ""):gsub("%s+$", ""):lower())
end

local function realmless(key)
    return (key:gsub("%-.*", ""))
end

-- list: { [key] = { note = "...", expires = time or nil } }
-- Returns the entry and its key when author is on the list and not expired.
function Lists.Find(list, author, now)
    local full = Lists.Key(author)
    for _, key in ipairs({ full, realmless(full) }) do
        local entry = list[key]
        if entry then
            if entry.expires and now and now >= entry.expires then
                list[key] = nil
            else
                return entry, key
            end
        end
    end
    return nil
end

function Lists.Add(list, name, note, expires)
    local key = Lists.Key(name)
    if key == "" then
        return nil
    end
    list[key] = { note = note ~= "" and note or nil, expires = expires }
    return key
end

-- Removes name. A name without a realm also removes that name on every realm.
function Lists.Remove(list, name)
    local key = Lists.Key(name)
    local removed
    if list[key] then
        list[key] = nil
        removed = key
    end
    if not key:find("-", 1, true) then
        for other in pairs(list) do
            if realmless(other) == key then
                list[other] = nil
                removed = removed or other
            end
        end
    end
    return removed
end

-- Sorted keys, dropping expired entries.
function Lists.Names(list, now)
    local names = {}
    for key, entry in pairs(list) do
        if entry.expires and now and now >= entry.expires then
            list[key] = nil
        else
            names[#names + 1] = key
        end
    end
    table.sort(names)
    return names
end

-- Counts spam hits per sender this session. Returns true the moment a sender
-- reaches limit hits.
function Lists.NewOffenders()
    return { hits = {} }
end

function Lists.Strike(offenders, author, limit)
    local key = Lists.Key(author)
    local n = (offenders.hits[key] or 0) + 1
    offenders.hits[key] = n
    return n == limit
end

-- Log entries whose sender, place, text or reason contain query (plain,
-- case-insensitive). An empty query returns everything.
function Lists.SearchLog(log, query)
    query = (query or ""):lower()
    if query == "" then
        return log
    end
    local found = {}
    for _, e in ipairs(log) do
        local hay = table.concat({ e.who or "", e.where or "", e.msg or "", e.why or "" }, "\n"):lower()
        if hay:find(query, 1, true) then
            found[#found + 1] = e
        end
    end
    return found
end
