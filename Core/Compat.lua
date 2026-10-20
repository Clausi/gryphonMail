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
-- plus gamepad page turn indicators. Retail and Classic have the globals InboxPrevPageButton /
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

-- Template for an extra mail frame tab that looks like Blizzard's. The mail tabs inherit
-- PanelTabButtonTemplate on Forever and Retail, and CharacterFrameTabButtonTemplate (named
-- textures, no LeftActive) on Classic.
function Compat.GetMailTabTemplate()
    if MailFrameTab2.LeftActive then
        return "PanelTabButtonTemplate"
    end
    return "CharacterFrameTabButtonTemplate"
end

-- Forever and Retail set the title with MailFrame:SetTitle() on every tab switch. Classic shows
-- own title strings in InboxFrame (InboxTitleText) and SendMailFrame and leaves MailFrame's title
-- empty.
function Compat.HasMailFrameTitle()
    return InboxTitleText == nil
end

-- "Open All" asks ShouldSkipCurrentMail() and ShouldSkipCurrentAttachment() on Forever and Retail,
-- which lets the addon restrict it to filtered mails. Classic inlines that logic in
-- AdvanceToNextItem(). Call once OpenAllMail exists.
function Compat.HasOpenAllSkipHooks()
    return OpenAllMail ~= nil and OpenAllMail.ShouldSkipCurrentMail ~= nil
        and OpenAllMail.ShouldSkipCurrentAttachment ~= nil
end

-- "Open All" finds the next mail and attachment with AdvanceToNextItem() on all clients. On Classic
-- it is the only method that can restrict the run to filtered mails. Call once OpenAllMail exists.
function Compat.HasOpenAllAdvance()
    return OpenAllMail ~= nil and OpenAllMail.AdvanceToNextItem ~= nil
end
