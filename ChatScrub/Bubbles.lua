-- Hides the say/yell chat bubble of a line the filter hid. Bubbles are created
-- after the chat event, so the search runs on the next frame. Bubbles in
-- dungeons and raids are forbidden to addons and are skipped.
local _, ns = ...

local RESTORE_AFTER = 8 -- seconds; the bubble frame is reused for later lines

local function fontStrings(frame)
    local found = {}
    if frame and frame.GetRegions then
        for _, region in ipairs({ frame:GetRegions() }) do
            if region.GetObjectType and region:GetObjectType() == "FontString" then
                found[#found + 1] = region
            end
        end
    end
    return found
end

local function hideMatching(msg)
    local ok, bubbles = pcall(C_ChatBubbles.GetAllChatBubbles, false)
    if not ok or type(bubbles) ~= "table" then
        return
    end
    for _, bubble in ipairs(bubbles) do
        if not (bubble.IsForbidden and bubble:IsForbidden()) then
            local holder = bubble.GetChildren and bubble:GetChildren() or nil
            for _, frame in ipairs({ holder or bubble, bubble }) do
                for _, text in ipairs(fontStrings(frame)) do
                    local shown = text:GetText()
                    if shown and not (issecretvalue and issecretvalue(shown)) and shown == msg then
                        frame:Hide()
                        C_Timer.After(RESTORE_AFTER, function() frame:Show() end)
                        return
                    end
                end
            end
        end
    end
end

function ns.HideBubble(msg)
    if not (C_ChatBubbles and C_ChatBubbles.GetAllChatBubbles and C_Timer) then
        return
    end
    C_Timer.After(0, function() hideMatching(msg) end)
end
