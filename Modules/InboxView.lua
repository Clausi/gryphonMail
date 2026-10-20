local _, ns = ...
local L = ns.L

-- Shared inbox filtering. Other modules register filters here; a mail is shown when it matches
-- every active filter. Handles redrawing the inbox rows, paging and "Open All".
local InboxView = ns:RegisterModule("InboxView")

local SECONDS_PER_DAY = 24 * 60 * 60
-- A mail is identified by sender, subject and expiry time (seconds); the expiry is derived from
-- daysLeft and may differ slightly between reads.
local EXPIRY_TOLERANCE_SECONDS = 5

local filters = {}
local readyCallbacks = {}
local isReady = false

local function SafeString(value)
    if type(value) ~= "string" or (issecretvalue and issecretvalue(value)) then
        return nil
    end
    return value
end

-- Identity of the mail at the inbox index, stable while indices shift (e.g. after a mail was
-- deleted): { sender, subject, expiry, icon }.
function InboxView:GetMailIdentity(index)
    local packageIcon, stationeryIcon, sender, subject, _, _, daysLeft = GetInboxHeaderInfo(index)
    return {
        sender = SafeString(sender) or UNKNOWN,
        subject = SafeString(subject) or "",
        expiry = time() + (daysLeft or 0) * SECONDS_PER_DAY,
        icon = packageIcon or stationeryIcon,
    }
end

function InboxView.IsSameMail(a, b)
    return a.sender == b.sender and a.subject == b.subject
        and math.abs(a.expiry - b.expiry) <= EXPIRY_TOLERANCE_SECONDS
end

-- A filter is a table with:
--   filter:IsActive()    -- true while the filter restricts the inbox
--   filter:Matches(mail) -- true if the mail passes, see GetMail() for the fields
function InboxView:RegisterFilter(filter)
    filters[#filters + 1] = filter
end

function InboxView:IsFilterActive()
    for i = 1, #filters do
        if filters[i]:IsActive() then
            return true
        end
    end
    return false
end

local function GetMail(index)
    local _, _, sender, subject, money, CODAmount, _, itemCount, wasRead, _, _, _, isGM = GetInboxHeaderInfo(index)
    -- Mail object as described in MailFilters.lua.
    return {
        index = index,
        name = sender,
        subject = subject,
        money = money or 0,
        cod = CODAmount or 0,
        itemCount = itemCount or 0,
        wasRead = wasRead,
        isGM = isGM,
    }
end

function InboxView:MailMatches(index)
    local mail = GetMail(index)
    for i = 1, #filters do
        local filter = filters[i]
        if filter:IsActive() and not filter:Matches(mail) then
            return false
        end
    end
    return true
end

local function GetFilteredIndices()
    local indices = {}
    for index = 1, GetInboxNumItems() do
        if InboxView:MailMatches(index) then
            indices[#indices + 1] = index
        end
    end
    return indices
end

-- Renders one inbox row for the given mail index.
-- Mirrors Blizzard's inbox update (InboxMixin:Update() on Forever, InboxFrame_Update() on Retail
-- and Classic), only with a remapped index. The rows are the same on all clients.
local function RenderSlot(inbox, slot, index)
    -- firstItem is an item link on Forever and Retail and an item ID on Classic; both work below.
    local packageIcon, stationeryIcon, sender, subject, money, CODAmount, daysLeft, itemCount, wasRead,
        _, _, _, isGM, firstItemQuantity, firstItem = GetInboxHeaderInfo(index)

    local icon = (packageIcon and not isGM) and packageIcon or stationeryIcon
    sender = sender or UNKNOWN

    local prefix = "MailItem" .. slot
    local button = _G[prefix .. "Button"]
    button:Show()
    button.index = index
    button.hasItem = itemCount
    button.itemCount = itemCount
    SetItemButtonCount(button, firstItemQuantity)
    if firstItemQuantity then
        SetItemButtonQuality(button, select(3, C_Item.GetItemInfo(firstItem)), firstItem)
    else
        button.IconBorder:Hide()
        button.IconOverlay:Hide()
        -- Only Forever and Retail have the overlay.
        if button.ProfessionQualityOverlay then
            button.ProfessionQualityOverlay:Hide()
        end
    end

    local buttonIcon = _G[prefix .. "ButtonIcon"]
    local subjectText = _G[prefix .. "Subject"]
    local senderText = _G[prefix .. "Sender"]
    buttonIcon:SetTexture(icon)
    subjectText:SetText(subject)
    senderText:SetText(sender)

    if wasRead then
        senderText:SetTextColor(0.75, 0.75, 0.75)
        subjectText:SetTextColor(0.75, 0.75, 0.75)
        _G[prefix .. "ButtonSlot"]:SetVertexColor(0.5, 0.5, 0.5)
        buttonIcon:SetDesaturated(true)
        button.IconBorder:SetVertexColor(0.5, 0.5, 0.5)
    else
        senderText:SetTextColor(NORMAL_FONT_COLOR:GetRGB())
        subjectText:SetTextColor(HIGHLIGHT_FONT_COLOR:GetRGB())
        _G[prefix .. "ButtonSlot"]:SetVertexColor(1.0, 0.82, 0)
        buttonIcon:SetDesaturated(false)
    end

    local expireTime = _G[prefix .. "ExpireTime"]
    if daysLeft >= 1 then
        expireTime:SetText(GREEN_FONT_COLOR_CODE .. format(DAYS_ABBR, floor(daysLeft)) .. " " .. FONT_COLOR_CODE_CLOSE)
    else
        local secondsLeft = floor(daysLeft * 24 * 60 * 60)
        expireTime:SetText(RED_FONT_COLOR_CODE .. SecondsToTime(secondsLeft) .. FONT_COLOR_CODE_CLOSE)
    end
    expireTime.tooltip = InboxItemCanDelete(index) and TIME_UNTIL_DELETED or TIME_UNTIL_RETURNED
    expireTime:Show()

    local hasCOD = CODAmount > 0
    _G[prefix .. "ButtonCOD"]:SetShown(hasCOD)
    _G[prefix .. "ButtonCODBackground"]:SetShown(hasCOD)
    button.cod = hasCOD and CODAmount or nil
    button.money = money > 0 and money or nil

    if inbox.openMailID == index then
        button:SetChecked(true)
        OpenMailFrame:SetPortraitToAsset(stationeryIcon)
    else
        button:SetChecked(false)
    end
end

local function ClearSlot(slot)
    local prefix = "MailItem" .. slot
    _G[prefix .. "Button"]:Hide()
    _G[prefix .. "Sender"]:SetText("")
    _G[prefix .. "Subject"]:SetText("")
    _G[prefix .. "ExpireTime"]:Hide()
end

-- Runs after Blizzard's inbox update and redraws the rows when a filter is active.
-- Blizzard's page buttons keep working because they only change inbox.pageNum.
local function OnInboxUpdate(inbox)
    if not InboxView:IsFilterActive() then
        return
    end

    local indices = GetFilteredIndices()
    local perPage = INBOXITEMS_TO_DISPLAY
    local numPages = math.max(1, math.ceil(#indices / perPage))
    -- Written to Blizzard's field on purpose: the filtered view can have fewer pages than the
    -- inbox, and the page buttons and Blizzard's inbox update keep using this page number.
    if inbox.pageNum > numPages then
        inbox.pageNum = numPages
    end

    local offset = (inbox.pageNum - 1) * perPage
    for slot = 1, perPage do
        local index = indices[offset + slot]
        if index then
            RenderSlot(inbox, slot, index)
        else
            ClearSlot(slot)
        end
    end

    ns.Compat.SetInboxPageButtonsEnabled(inbox.pageNum > 1, inbox.pageNum < numPages)
end

-- True once "Open All" is restricted to the filtered mails (see SetupOpenAll).
local canOpenFiltered = false

-- Shows whether "Open All" currently opens all mails or only the filtered ones.
-- While opening, the button is disabled and shows Blizzard's progress text, which is left alone.
local function UpdateOpenAllText()
    if canOpenFiltered and OpenAllMail:IsEnabled() then
        OpenAllMail:SetText(InboxView:IsFilterActive() and L["OPEN_FILTERED"] or OPEN_ALL_MAIL_BUTTON)
    end
end

-- State of the current "Open All" / "Open Filtered" run, nil while none is running:
--   mails       mails that matched the filters when the run started (nil without active filter).
--               Taking attachments changes a mail (e.g. it becomes read), so a mail must not drop
--               out of the run halfway; the filters are evaluated once per run.
--   requests    take requests of this run:
--               { mail, slot (nil for money), failed, numItems, sameMails (counts at request time) }
--   lastRequest the most recent request, marked as failed by MAIL_FAILED
local run

local function CollectMatchingMails()
    local mails = {}
    for index = 1, GetInboxNumItems() do
        if InboxView:MailMatches(index) then
            mails[#mails + 1] = InboxView:GetMailIdentity(index)
        end
    end
    return mails
end

-- Starts a run if none is running. Called from the first mail lookup of a run, before anything was
-- taken (StartOpening has no pre-hook).
local function StartRun()
    if not run then
        run = {
            mails = InboxView:IsFilterActive() and CollectMatchingMails() or nil,
            requests = {},
        }
    end
end

local function IsRunMail(index)
    local mail = InboxView:GetMailIdentity(index)
    for _, runMail in ipairs(run.mails) do
        if InboxView.IsSameMail(runMail, mail) then
            return true
        end
    end
    return false
end

-- Number of mails in the inbox with the same identity (e.g. identical auction mails).
local function CountSameMails(mail)
    local count = 0
    for index = 1, GetInboxNumItems() do
        if InboxView.IsSameMail(InboxView:GetMailIdentity(index), mail) then
            count = count + 1
        end
    end
    return count
end

-- True if this attachment (or with slot nil: the money) of the mail was already requested in this
-- run and the request has not failed. If one of several identical mails was deleted meanwhile,
-- the request belonged to that mail and no longer blocks the remaining one. The count is only
-- needed when the inbox has shrunk since the request.
local function WasRequested(index, slot)
    local mail = InboxView:GetMailIdentity(index)
    local numItems = GetInboxNumItems()
    for _, request in ipairs(run.requests) do
        if not request.failed and request.slot == slot and InboxView.IsSameMail(request.mail, mail)
            and (numItems >= request.numItems or CountSameMails(mail) >= request.sameMails) then
            return true
        end
    end
    return false
end

local function AddRequest(index, slot)
    if not run then
        return
    end
    local mail = InboxView:GetMailIdentity(index)
    local request = {
        mail = mail,
        slot = slot,
        failed = false,
        numItems = GetInboxNumItems(),
        sameMails = CountSameMails(mail),
    }
    run.requests[#run.requests + 1] = request
    run.lastRequest = request
end

-- Blizzard's "Open All" walks every mail and asks ShouldSkipCurrentMail() and, per attachment,
-- ShouldSkipCurrentAttachment(). Both methods are replaced on this button only, because a post-hook
-- cannot change the return value; everything else (COD/GM mails, bag space, delays, index shifts
-- after deleted mails) stays Blizzard's logic. The resulting taint is harmless here: the mail
-- functions used by "Open All" are not protected.
--   ShouldSkipCurrentMail:       with an active filter, skip mails that did not match at the start
--   ShouldSkipCurrentAttachment: skip attachments already requested in this run. Blizzard's loop
--                                requests them again while the inbox data is not updated yet (also
--                                after mail indices shift), which the server answers with "The item
--                                was not found". A failed request (MAIL_FAILED) may be retried.
local function SetupSkipHooks()
    local shouldSkipCurrentMail = OpenAllMail.ShouldSkipCurrentMail
    OpenAllMail.ShouldSkipCurrentMail = function(self)
        StartRun()
        if run.mails and not IsRunMail(self.mailIndex) then
            return true
        end
        return shouldSkipCurrentMail(self)
    end

    local shouldSkipCurrentAttachment = OpenAllMail.ShouldSkipCurrentAttachment
    OpenAllMail.ShouldSkipCurrentAttachment = function(self)
        if shouldSkipCurrentAttachment(self) then
            return true
        end
        if not run then
            return false
        end
        local index, slot = self.mailIndex, self.attachmentIndex
        if HasInboxItem(index, slot) then
            return WasRequested(index, slot)
        end
        -- Blizzard treats every slot as retrievable while the mail shows money; once the money was
        -- requested, empty slots are skipped.
        return WasRequested(index, nil)
    end

    hooksecurefunc("TakeInboxItem", function(index, slot)
        AddRequest(index, slot)
    end)
    hooksecurefunc("TakeInboxMoney", function(index)
        AddRequest(index, nil)
    end)
    ns:RegisterEvent("MAIL_FAILED", function()
        if run and run.lastRequest then
            run.lastRequest.failed = true
        end
    end)
end

-- Classic has neither skip method, its skip logic is inlined in AdvanceToNextItem(). That method is
-- wrapped instead: Blizzard's version finds the next mail with something to take, the wrapper moves
-- on past mails that did not match at the start of the run. Blizzard calls the method recursively
-- through self for the next mail, so every step passes the wrapper. Attachments already requested
-- are not skipped here: Blizzard's ProcessNextItem() takes the money of a mail regardless of the
-- attachment index, so skipping single attachments would not prevent repeated requests.
local function SetupAdvanceWrapper()
    local advanceToNextItem = OpenAllMail.AdvanceToNextItem
    OpenAllMail.AdvanceToNextItem = function(self)
        StartRun()
        while advanceToNextItem(self) do
            if not run.mails or IsRunMail(self.mailIndex) then
                return true
            end
            self.mailIndex = self.mailIndex + 1
            self.attachmentIndex = ATTACHMENTS_MAX
            if self.mailIndex > GetInboxNumItems() then
                return false
            end
        end
        return false
    end
end

-- "Open Filtered" needs the skip methods (Forever, Retail) or AdvanceToNextItem() (Classic).
local function SetupOpenAll()
    if ns.Compat.HasOpenAllSkipHooks() then
        SetupSkipHooks()
    elseif ns.Compat.HasOpenAllAdvance() then
        SetupAdvanceWrapper()
    else
        return
    end
    canOpenFiltered = true

    -- StopOpening() resets the text to Blizzard's default.
    hooksecurefunc(OpenAllMail, "StopOpening", function()
        run = nil
        UpdateOpenAllText()
    end)
end

-- Call after a filter changed. Jumps back to the first page and redraws the inbox.
function InboxView:Refresh()
    if not isReady then
        return
    end
    -- Written to Blizzard's field on purpose: Blizzard's inbox update and the page buttons read it,
    -- and the current page may be out of range or empty for the new filter.
    InboxFrame.pageNum = 1
    ns.Compat.UpdateInbox()
    UpdateOpenAllText()
end

-- Call when the data behind a filter changed (e.g. guild roster). Keeps the current page.
function InboxView:Redraw()
    if isReady and InboxFrame:IsVisible() then
        ns.Compat.UpdateInbox()
    end
end

-- Runs the callback once the Blizzard mail frame exists. label names it in the debug memory output.
function InboxView:OnReady(callback, label)
    if isReady then
        callback()
    else
        readyCallbacks[#readyCallbacks + 1] = { callback = callback, label = label or "?" }
    end
end

local function Setup()
    isReady = true
    ns:MeasureMemory("InboxView:Setup", function()
        ns.Compat.HookInboxUpdate(OnInboxUpdate)
        SetupOpenAll()
    end)

    for _, ready in ipairs(readyCallbacks) do
        ns:MeasureMemory(ready.label .. ":OnReady", ready.callback)
    end
    readyCallbacks = {}
end

function InboxView:OnInitialize()
    if InboxFrame then
        Setup()
        return
    end

    -- The mail frame is the load-on-demand addon Blizzard_MailFrame on Forever and Retail, and part
    -- of Blizzard_UIPanels_Game on Classic, which is usually loaded before this addon.
    ns:RegisterEvent("ADDON_LOADED", function(_, loadedName)
        if (loadedName == "Blizzard_MailFrame" or loadedName == "Blizzard_UIPanels_Game") and not isReady then
            Setup()
        end
    end)
end
