-- Adds "Block" and "Never hide" to the menu you get by right-clicking a name in
-- chat. Needs the Menu API (Retail 11+ and the current Classic clients); on
-- clients without it, /scrub block and /scrub allow still work.
local _, ns = ...
local L = ns.L

local TAGS = { "MENU_UNIT_FRIEND", "MENU_UNIT_PLAYER" }

local function fullName(contextData)
    if not contextData or type(contextData.name) ~= "string" or contextData.name == ""
        or (issecretvalue and (issecretvalue(contextData.name) or issecretvalue(contextData.server))) then
        return nil
    end
    if contextData.server and contextData.server ~= "" then
        return contextData.name .. "-" .. contextData.server
    end
    return contextData.name
end

local function addItems(_, rootDescription, contextData)
    local name = fullName(contextData)
    if not name or name == UnitName("player") or not ns.GetDB() then
        return
    end
    local db = ns.GetDB()
    rootDescription:CreateDivider()
    rootDescription:CreateTitle("ChatScrub")
    if ns.Lists.Find(db.blockedPlayers, name) then
        rootDescription:CreateButton(L["Unblock"], function() ns.say(select(2, ns.UnblockPlayer(name))) end)
    else
        rootDescription:CreateButton(L["Block (hide everything they say)"], function()
            ns.say(select(2, ns.BlockPlayer(name)))
        end)
    end
    if not ns.Lists.Find(db.allowPlayers, name) then
        rootDescription:CreateButton(L["Never hide this player"], function()
            ns.say(select(2, ns.AllowPlayer(name)))
        end)
    end
end

function ns.SetUpMenus()
    if not (Menu and Menu.ModifyMenu) then
        return
    end
    for _, tag in ipairs(TAGS) do
        Menu.ModifyMenu(tag, addItems)
    end
end
