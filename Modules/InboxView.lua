local _, ns = ...
local L = ns.L

-- Shared inbox filtering. Other modules register filters here; a mail is shown when it matches
-- every active filter. Handles redrawing the inbox rows, paging and "Open All".
local InboxView = ns:RegisterModule("InboxView")

local filters = {}
local readyCallbacks = {}
local isReady = false

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
    return {
        index = index,
        sender = sender,
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
-- Mirrors InboxMixin:Update() from Blizzard_MailFrame, only with a remapped index.
local function RenderSlot(inbox, slot, index)
    local packageIcon, stationeryIcon, sender, subject, money, CODAmount, daysLeft, itemCount, wasRead,
        _, _, _, isGM, firstItemQuantity, firstItemLink = GetInboxHeaderInfo(index)

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
        SetItemButtonQuality(button, select(3, C_Item.GetItemInfo(firstItemLink)), firstItemLink)
    else
        button.IconBorder:Hide()
        button.IconOverlay:Hide()
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

-- Runs after Blizzard's InboxFrame:Update() and redraws the rows when a filter is active.
-- Blizzard's page buttons keep working because they only change inbox.pageNum.
local function OnInboxUpdate(inbox)
    if not InboxView:IsFilterActive() then
        return
    end

    local indices = GetFilteredIndices()
    local perPage = INBOXITEMS_TO_DISPLAY
    local numPages = math.max(1, math.ceil(#indices / perPage))
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

    local hasPrev = inbox.pageNum > 1
    local hasNext = inbox.pageNum < numPages
    inbox.PrevPageButton:SetEnabled(hasPrev)
    inbox.PageTurnIndicatorLeft:SetEnabled(hasPrev)
    inbox.NextPageButton:SetEnabled(hasNext)
    inbox.PageTurnIndicatorRight:SetEnabled(hasNext)
end

-- Shows whether "Open All" currently opens all mails or only the filtered ones.
-- While opening, the button is disabled and shows Blizzard's progress text, which is left alone.
local function UpdateOpenAllText()
    if OpenAllMail:IsEnabled() then
        OpenAllMail:SetText(InboxView:IsFilterActive() and L["OPEN_FILTERED"] or OPEN_ALL_MAIL_BUTTON)
    end
end

-- Blizzard's "Open All" walks every mail and asks ShouldSkipCurrentMail() for each one.
-- With an active filter, non-matching mails are skipped as well; everything else (COD/GM mails,
-- bag space, delays, index shifts after deleted mails) stays Blizzard's logic.
-- The method is replaced on this button only, because a post-hook cannot change the return value.
-- The resulting taint is harmless here: the mail functions used by "Open All" are not protected.
local function SetupOpenAll()
    local shouldSkipCurrentMail = OpenAllMail.ShouldSkipCurrentMail
    OpenAllMail.ShouldSkipCurrentMail = function(self)
        if InboxView:IsFilterActive() and not InboxView:MailMatches(self.mailIndex) then
            return true
        end
        return shouldSkipCurrentMail(self)
    end

    -- StopOpening() resets the text to Blizzard's default.
    hooksecurefunc(OpenAllMail, "StopOpening", UpdateOpenAllText)
end

-- Call after a filter changed. Jumps back to the first page and redraws the inbox.
function InboxView:Refresh()
    if not isReady then
        return
    end
    InboxFrame.pageNum = 1
    InboxFrame:Update()
    UpdateOpenAllText()
end

-- Call when the data behind a filter changed (e.g. guild roster). Keeps the current page.
function InboxView:Redraw()
    if isReady and InboxFrame:IsVisible() then
        InboxFrame:Update()
    end
end

-- Runs the callback once the Blizzard mail frame exists.
function InboxView:OnReady(callback)
    if isReady then
        callback()
    else
        readyCallbacks[#readyCallbacks + 1] = callback
    end
end

local function Setup()
    isReady = true
    hooksecurefunc(InboxFrame, "Update", OnInboxUpdate)
    SetupOpenAll()

    for i = 1, #readyCallbacks do
        readyCallbacks[i]()
    end
    readyCallbacks = {}
end

function InboxView:OnInitialize()
    if InboxFrame then
        Setup()
        return
    end

    ns:RegisterEvent("ADDON_LOADED", function(_, loadedName)
        if loadedName == "Blizzard_MailFrame" and not isReady then
            Setup()
        end
    end)
end
