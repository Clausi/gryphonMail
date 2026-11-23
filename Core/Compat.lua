local _, ns = ...

-- Differences between the supported clients (Forever, Retail), in one place. Detects the APIs and
-- methods a client has instead of comparing version numbers. Blizzard UI reference: the forever and
-- live branches of Gethe/wow-ui-source.
local Compat = {}
ns.Compat = Compat

-- Forever names are "First Surname", unique per region, without a realm part. Retail uses
-- "Name-Realm". RegionalUniqueNamesEnabled() is the check Blizzard's own NameUtil uses.
function Compat.HasRealmNames()
    return not (RegionalUniqueNamesEnabled and RegionalUniqueNamesEnabled())
end

-- Ruleset of the logged-in character on Forever from its game rules: "PvE", "PvP", "RP", "RPPvP"
-- or "HC" (hardcore); nil without the ruleset game rules. Since Forever build 71037 it is the only
-- way to tell the ruleset: GetRealmName() returns "" and GetRealmID() 0.
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
-- Clients without the check always have it.
function Compat.HasCharacterFriendList()
    local check = C_FriendList.IsLegacyFriendSystemEnabled
    return check == nil or check() == true
end

-- Forever redraws the inbox with the method InboxFrame:Update() (InboxMixin). Retail uses the
-- global function InboxFrame_Update() instead. Call once InboxFrame exists.
function Compat.HasInboxUpdateMethod()
    return InboxFrame ~= nil and InboxFrame.Update ~= nil
end

-- Runs callback(InboxFrame) after every inbox redraw by Blizzard.
function Compat.HookInboxUpdate(callback)
    if Compat.HasInboxUpdateMethod() then
        hooksecurefunc(InboxFrame, "Update", callback)
    else
        hooksecurefunc("InboxFrame_Update", function()
            callback(InboxFrame)
        end)
    end
end

-- Redraws the inbox with Blizzard's update function.
function Compat.UpdateInbox()
    if Compat.HasInboxUpdateMethod() then
        InboxFrame:Update()
    else
        InboxFrame_Update()
    end
end

-- Enables the inbox page buttons. Forever has them as InboxFrame.PrevPageButton / NextPageButton,
-- plus gamepad page turn indicators. Retail has the globals InboxPrevPageButton /
-- InboxNextPageButton.
function Compat.SetInboxPageButtonsEnabled(hasPrev, hasNext)
    if InboxFrame.PrevPageButton then
        InboxFrame.PrevPageButton:SetEnabled(hasPrev)
        InboxFrame.NextPageButton:SetEnabled(hasNext)
        if InboxFrame.PageTurnIndicatorLeft then
            InboxFrame.PageTurnIndicatorLeft:SetEnabled(hasPrev)
            InboxFrame.PageTurnIndicatorRight:SetEnabled(hasNext)
        end
    else
        InboxPrevPageButton:SetEnabled(hasPrev)
        InboxNextPageButton:SetEnabled(hasNext)
    end
end

-- "Open All" asks ShouldSkipCurrentMail() and ShouldSkipCurrentAttachment(), which lets the addon
-- restrict it to filtered mails. Call once OpenAllMail exists.
function Compat.HasOpenAllSkipHooks()
    return OpenAllMail ~= nil and OpenAllMail.ShouldSkipCurrentMail ~= nil
        and OpenAllMail.ShouldSkipCurrentAttachment ~= nil
end
