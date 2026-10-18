local _, ns = ...
local L = ns.L

-- Third mail frame tab ("Log") listing collected mails, newest first, in pages like the inbox.
local MailLogFrame = ns:RegisterModule("MailLogFrame")
local InboxView = ns.modules.InboxView
local MailLog = ns.modules.MailLog

local ROWS_PER_PAGE = 7
local ROW_WIDTH = 305
local ROW_HEIGHT = 45
local ICON_SIZE = 37
local LOG_TAB_OFFSET_X = 2

local frame
local tab
local rows = {}
local pageNum = 1

local function GetNewestFirst()
    local entries = MailLog:GetEntries()
    local sorted = {}
    for i = #entries, 1, -1 do
        sorted[#sorted + 1] = entries[i]
    end
    return sorted
end

local function FormatDetails(entry)
    local parts = {}
    if entry.money > 0 then
        parts[#parts + 1] = GetMoneyString(entry.money, true)
    end
    if #entry.items > 0 then
        parts[#parts + 1] = MailLog:FormatItemCount(MailLog:GetItemQuantity(entry))
    end
    if (entry.codPaid or 0) > 0 then
        local codText = L["LOG_COD_PAID"]:format(GetMoneyString(entry.codPaid, true))
        parts[#parts + 1] = RED_FONT_COLOR:WrapTextInColorCode(codText)
    end
    return table.concat(parts, "  ")
end

local function ShowEntryTooltip(row)
    local entry = row.entry
    if not entry then
        return
    end
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:SetText(entry.sender)
    GameTooltip:AddLine(entry.subject, 1, 1, 1, true)
    GameTooltip:AddLine(date(L["LOG_DATE_FORMAT"], entry.time), 0.75, 0.75, 0.75)
    if entry.money > 0 or #entry.items > 0 then
        GameTooltip:AddLine(" ")
    end
    if entry.money > 0 then
        GameTooltip_AddMoneyLine(GameTooltip, entry.money)
    end
    for _, item in ipairs(entry.items) do
        GameTooltip:AddLine(item.count > 1 and ("%s x%d"):format(item.link, item.count) or item.link)
    end
    if (entry.codPaid or 0) > 0 then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L["LOG_COD_PAID_LABEL"], RED_FONT_COLOR:GetRGB())
        GameTooltip_AddMoneyLine(GameTooltip, entry.codPaid)
    end
    GameTooltip:Show()
end

local function CreateRow(index)
    local row = CreateFrame("Button", nil, frame)
    row:SetSize(ROW_WIDTH, ROW_HEIGHT)
    if index == 1 then
        -- Same position as the first inbox row (MailItem1).
        row:SetPoint("TOPLEFT", frame, "TOPLEFT", 13, -70)
    else
        row:SetPoint("TOPLEFT", rows[index - 1], "BOTTOMLEFT")
    end
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")

    row.Icon = row:CreateTexture(nil, "ARTWORK")
    row.Icon:SetSize(ICON_SIZE, ICON_SIZE)
    row.Icon:SetPoint("LEFT", 4, 0)

    row.Sender = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    row.Sender:SetPoint("TOPLEFT", row.Icon, "TOPRIGHT", 8, 0)
    row.Sender:SetPoint("RIGHT", row, "RIGHT", -80, 0)
    row.Sender:SetJustifyH("LEFT")
    row.Sender:SetWordWrap(false)

    row.Date = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.Date:SetPoint("TOPRIGHT", row, "TOPRIGHT", -6, -6)
    row.Date:SetTextColor(0.75, 0.75, 0.75)

    row.Subject = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.Subject:SetPoint("TOPLEFT", row.Sender, "BOTTOMLEFT", 0, -2)
    row.Subject:SetPoint("RIGHT", row, "RIGHT", -6, 0)
    row.Subject:SetJustifyH("LEFT")
    row.Subject:SetWordWrap(false)

    row.Details = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.Details:SetPoint("TOPLEFT", row.Subject, "BOTTOMLEFT", 0, -2)
    row.Details:SetPoint("RIGHT", row, "RIGHT", -6, 0)
    row.Details:SetJustifyH("LEFT")
    row.Details:SetWordWrap(false)

    row:SetScript("OnEnter", ShowEntryTooltip)
    row:SetScript("OnLeave", GameTooltip_Hide)
    return row
end

local function CreatePageButton(direction)
    local button = CreateFrame("Button", nil, frame)
    button:SetSize(32, 32)
    local prefix = "Interface\\Buttons\\UI-SpellbookIcon-" .. direction .. "Page-"
    button:SetNormalTexture(prefix .. "Up")
    button:SetPushedTexture(prefix .. "Down")
    button:SetDisabledTexture(prefix .. "Disabled")
    button:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    return button
end

function MailLogFrame:Update()
    if not frame or not frame:IsShown() then
        return
    end

    local entries = GetNewestFirst()
    local numPages = math.max(1, math.ceil(#entries / ROWS_PER_PAGE))
    pageNum = math.min(math.max(pageNum, 1), numPages)

    frame.Header:SetFormattedText(L["LOG_HEADER"], MailLog:GetRetentionDays())
    frame.Empty:SetShown(#entries == 0)

    local offset = (pageNum - 1) * ROWS_PER_PAGE
    for i, row in ipairs(rows) do
        local entry = entries[offset + i]
        row.entry = entry
        if entry then
            row.Icon:SetTexture(entry.icon)
            row.Sender:SetText(entry.sender)
            row.Subject:SetText(entry.subject)
            row.Details:SetText(FormatDetails(entry))
            row.Date:SetText(date(L["LOG_DATE_FORMAT"], entry.time))
            row:Show()
        else
            row:Hide()
        end
    end

    frame.PageText:SetFormattedText(L["LOG_PAGE"], pageNum, numPages)
    frame.PrevPage:SetEnabled(pageNum > 1)
    frame.NextPage:SetEnabled(pageNum < numPages)
end

local function CreateLogFrame()
    frame = CreateFrame("Frame", "GryphonMailLogFrame", MailFrame)
    frame:SetAllPoints(InboxFrame)
    frame:SetFrameLevel(InboxFrame:GetFrameLevel())
    frame:Hide()

    frame.Header = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    frame.Header:SetPoint("TOP", frame, "TOP", 20, -42)

    frame.Empty = frame:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    frame.Empty:SetPoint("CENTER", frame, "CENTER", 0, 20)
    frame.Empty:SetText(L["LOG_EMPTY"])

    for i = 1, ROWS_PER_PAGE do
        rows[i] = CreateRow(i)
    end

    frame.PrevPage = CreatePageButton("Prev")
    frame.PrevPage:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 16, 10)
    frame.PrevPage:SetScript("OnClick", function()
        pageNum = pageNum - 1
        MailLogFrame:Update()
    end)

    frame.NextPage = CreatePageButton("Next")
    frame.NextPage:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -16, 10)
    frame.NextPage:SetScript("OnClick", function()
        pageNum = pageNum + 1
        MailLogFrame:Update()
    end)

    frame.PageText = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    frame.PageText:SetPoint("BOTTOM", frame, "BOTTOM", 0, 20)

    frame:SetScript("OnShow", function()
        pageNum = 1
        MailLogFrame:Update()
    end)
end

-- Blizzard's MailFrameTab_OnClick() treats every tab ID other than 1 as "Send Mail", so the log tab
-- does not go through it. It switches the view itself and leaves Blizzard's tab state
-- (MailFrame.selectedTab / numTabs / activeSubFrame) untouched to avoid taint.
local function ShowLog()
    PanelTemplates_DeselectTab(MailFrameTab1)
    PanelTemplates_DeselectTab(MailFrameTab2)
    PanelTemplates_SelectTab(tab)

    if SendMailFrame:IsShown() then
        SetSendMailShowing(false)
    end
    InboxFrame:Hide()
    SendMailFrame:Hide()

    ButtonFrameTemplate_HideButtonBar(MailFrame)
    MailFrameInset:SetPoint("TOPLEFT", 4, -58)
    MailFrame:SetTitle(L["LOG_TITLE"])

    frame:Show()
    PlaySound(SOUNDKIT.IG_SPELLBOOK_OPEN)
end

local function HideLog()
    frame:Hide()
    PanelTemplates_DeselectTab(tab)
end

local function CreateTab()
    tab = CreateFrame("Button", "GryphonMailLogTab", MailFrame, "PanelTabButtonTemplate")
    tab:SetText(L["LOG_TAB"])
    -- Blizzard anchors its tabs with x = -8, but the visible gap next to MailFrameTab2 ends up
    -- smaller with that (measured on screenshots), so the log tab uses its own offset. The active
    -- tab art starts ~2 units further right than the inactive one, so the gap differs slightly
    -- between both states, the same as for Blizzard's tabs.
    tab:SetPoint("LEFT", MailFrameTab2, "RIGHT", LOG_TAB_OFFSET_X, 0)
    tab:SetScript("OnClick", ShowLog)
    PanelTemplates_DeselectTab(tab)
end

local function Setup()
    CreateLogFrame()
    CreateTab()

    -- Switching to Inbox / Send Mail (also done by Blizzard when the mailbox opens) hides the log.
    hooksecurefunc("MailFrameTab_OnClick", HideLog)
    MailFrame:HookScript("OnHide", HideLog)
end

function MailLogFrame:OnInitialize()
    InboxView:OnReady(Setup, "MailLogFrame")
    MailLog:OnChange(function()
        MailLogFrame:Update()
    end)
end
