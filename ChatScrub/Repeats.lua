-- Repeat-message tracking. No WoW API calls (the caller passes the time), so
-- tests/run_tests.lua can load it in plain Lua and a chat addon could reuse it.

local _, ns = ...
local Repeats = {}
ns.Repeats = Repeats

local PRUNE_EVERY = 60 -- seconds between sweeps of expired entries

-- Lines count as the same when they differ only in case, markup or spacing.
function Repeats.Key(where, sender, msg)
    local text = ns.Rules.Normalize(msg):gsub("%s+", " "):gsub("^ ", ""):gsub(" $", "")
    return where .. "\0" .. sender .. "\0" .. text
end

function Repeats.New()
    return setmetatable({ seen = {}, nextPrune = 0 }, { __index = Repeats })
end

-- True when key was first seen less than window seconds before now. A repeat
-- doesn't restart the window, so a line reposted every minute still shows
-- once per window instead of staying hidden for good.
function Repeats:IsRepeat(key, now, window)
    if now >= self.nextPrune then
        for k, t in pairs(self.seen) do
            if now - t >= window then
                self.seen[k] = nil
            end
        end
        self.nextPrune = now + PRUNE_EVERY
    end
    local first = self.seen[key]
    if first and now - first < window then
        return true
    end
    self.seen[key] = now
    return false
end
