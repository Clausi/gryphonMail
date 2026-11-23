local _, ns = ...

-- Access to Blizzard's mail frame internals and to APIs that need a check, in one place. Blizzard UI
-- reference: the forever branch of Gethe/wow-ui-source.
local Compat = {}
ns.Compat = Compat

-- Ruleset of the logged-in character from its game rules: "PvE", "PvP", "RP", "RPPvP" or "HC"
-- (hardcore); nil without the ruleset game rules. Since Forever build 71037 it is the only way to
-- tell the ruleset: GetRealmName() returns "" and GetRealmID() 0.
function Compat.GetRuleset()
    local rules = Enum.GameRule
    if not (C_GameRules and C_GameRules.IsGameRuleActive and rules and rules.PvPRuleset
            and rules.RPRuleset) then
        return nil
    end
    local isPvP = C_GameRules.IsGameRuleActive(rules.PvPRuleset)
    local isRP = C_GameRules.IsGameRuleActive(rules.RPRuleset)
    if isPvP and isRP then
        return "RPPvP"
    elseif isPvP then
        return "PvP"
    elseif isRP then
        return "RP"
    elseif rules.HardcoreRuleset and C_GameRules.IsGameRuleActive(rules.HardcoreRuleset) then
        return "HC"
    end
    return "PvE"
end

-- The character-based friends list (C_FriendList). Forever can turn it off: its friends frame only
-- lists Battle.net friends then, otherwise both (Blizzard_FriendsFrame/Camelot/FriendsFrame.lua).
function Compat.HasCharacterFriendList()
    local check = C_FriendList.IsLegacyFriendSystemEnabled
    return check == nil or check() == true
end

-- Runs callback(InboxFrame) after every inbox redraw by Blizzard (InboxMixin:Update()).
function Compat.HookInboxUpdate(callback)
    hooksecurefunc(InboxFrame, "Update", callback)
end

-- Redraws the inbox with Blizzard's update method.
function Compat.UpdateInbox()
    InboxFrame:Update()
end

-- Enables the inbox page buttons (InboxFrame.PrevPageButton / NextPageButton) and the gamepad page
-- turn indicators.
function Compat.SetInboxPageButtonsEnabled(hasPrev, hasNext)
    InboxFrame.PrevPageButton:SetEnabled(hasPrev)
    InboxFrame.NextPageButton:SetEnabled(hasNext)
    if InboxFrame.PageTurnIndicatorLeft then
        InboxFrame.PageTurnIndicatorLeft:SetEnabled(hasPrev)
        InboxFrame.PageTurnIndicatorRight:SetEnabled(hasNext)
    end
end

-- "Open All" asks ShouldSkipCurrentMail() and ShouldSkipCurrentAttachment(), which lets the addon
-- restrict it to filtered mails. Call once OpenAllMail exists.
function Compat.HasOpenAllSkipHooks()
    return OpenAllMail ~= nil and OpenAllMail.ShouldSkipCurrentMail ~= nil
        and OpenAllMail.ShouldSkipCurrentAttachment ~= nil
end
