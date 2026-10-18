local _, ns = ...

-- Differences between the supported clients (Forever, Classic Era, Anniversary, Retail), in one
-- place. Detects the APIs and methods a client has instead of comparing version numbers. Blizzard
-- UI reference: the forever, classic_era, classic_anniversary and live branches of
-- Gethe/wow-ui-source.
local Compat = {}
ns.Compat = Compat

-- Forever names are "First Surname", unique per region, without a realm part. Other clients use
-- "Name-Realm". RegionalUniqueNamesEnabled() is the check Blizzard's own NameUtil uses; Classic
-- does not have the function.
function Compat.HasRealmNames()
    return not (RegionalUniqueNamesEnabled and RegionalUniqueNamesEnabled())
end

-- Forever redraws the inbox with the method InboxFrame:Update() (InboxMixin). Retail and Classic
-- use the global function InboxFrame_Update() instead. Call once InboxFrame exists.
function Compat.HasInboxUpdateMethod()
    return InboxFrame ~= nil and InboxFrame.Update ~= nil
end

-- "Open All" asks ShouldSkipCurrentMail() and ShouldSkipCurrentAttachment() on Forever and Retail,
-- which lets the addon restrict it to filtered mails. Classic inlines that logic in
-- AdvanceToNextItem(). Call once OpenAllMail exists.
function Compat.HasOpenAllSkipHooks()
    return OpenAllMail ~= nil and OpenAllMail.ShouldSkipCurrentMail ~= nil
        and OpenAllMail.ShouldSkipCurrentAttachment ~= nil
end
