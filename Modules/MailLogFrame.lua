local _, ns = ...
local L = ns.L

-- Third mail frame tab ("Log") listing collected and sent mails, newest first, in pages like the
-- inbox, with the same search box and filter dropdown.
local MailLogFrame = ns:RegisterModule("MailLogFrame")
local InboxView = ns.modules.InboxView
local MailLog = ns.modules.MailLog
local MailFilters = ns.modules.MailFilters
local Contacts = ns.modules.Contacts

local ROWS_PER_PAGE = 7
local ROW_WIDTH = 305
local ROW_HEIGHT = 45
local ICON_SIZE = 37
local LOG_TAB_OFFSET_X = 2
-- Sender line of sent mail, light blue to tell it apart from received mail (gold).
local SENT_COLOR = CreateColor(0.4, 0.78, 1)

local DIVIDER = MailFilters.DIVIDER

-- Same presets as the inbox, with received / sent instead of the read state:
-- all mail | people | direction | trade
local FILTER_LAYOUT = {
    MailFilters.PRESET_ALL, DIVIDER,
    "alts", Contacts.FRIENDS, Contacts.RECENT_ALLIES, Contacts.GUILD, DIVIDER,
    "received", "sent", DIVIDER,
    "auction", "money", "cod",
}

local frame
local tab
local rows = {}
local pageNum = 1
-- Search box and preset dropdown (see MailFilters), created with the frame.
local filters = {}

-- Reused mail object (see MailFilters.lua) for matching a log entry against the filters.
local filterMail = {}

local function MatchesFilters(entry)
    filterMail.name = entry.sent and entry.recipient or entry.sender
    filterMail.subject = entry.subject
    filterMail.money = entry.money
    filterMail.cod = (entry.sent and entry.cod or entry.codPaid) or 0
    filterMail.sent = entry.sent == true
    for _, filter in ipairs(filters) do
        if filter:IsActive() and not filter:Matches(filterMail) then
            return false
        end
    end
    return true
end

-- Entries matching the filters, newest first.
local function GetVisibleEntries()
    local entries = MailLog:GetEntries()
    local visible = {}
    for i = #entries, 1, -1 do
        if MatchesFilters(entries[i]) then
            visible[#visible + 1] = entries[i]
        end
    end
    return visible
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
    if (entry.cod or 0) > 0 then
        parts[#parts + 1] = L["LOG_COD_REQUESTED"]:format(GetMoneyString(entry.cod, true))
    end
    return table.concat(parts, "  ")
end

-- Received mail shows the sender, sent mail "To: <recipient>" in a different color.
local function GetCounterpart(entry)
    if entry.sent then
        return L["LOG_SENT_TO"]:format(entry.recipient), SENT_COLOR
    end
    return entry.sender, NORMAL_FONT_COLOR
end

local function ShowEntryTooltip(row)
    local entry = row.entry
    if not entry then
        return
    end
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    local counterpart, color = GetCounterpart(entry)
    GameTooltip:SetText(counterpart, color:GetRGB())
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
    if (entry.cod or 0) > 0 then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L["LOG_COD_REQUESTED_LABEL"])
        GameTooltip_AddMoneyLine(GameTooltip, entry.cod)
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

    local entries = GetVisibleEntries()
    local numPages = math.max(1, math.ceil(#entries / ROWS_PER_PAGE))
    pageNum = math.min(math.max(pageNum, 1), numPages)

    -- The search box and the filter take the place of a header, so the retention goes into the title.
    MailFrame:SetTitle(L["LOG_TITLE"]:format(MailLog:GetRetentionDays()))
    frame.Empty:SetText(#MailLog:GetEntries() == 0 and L["LOG_EMPTY"] or L["LOG_EMPTY_FILTERED"])
    frame.Empty:SetShown(#entries == 0)

    local offset = (pageNum - 1) * ROWS_PER_PAGE
    for i, row in ipairs(rows) do
        local entry = entries[offset + i]
        row.entry = entry
        if entry then
            row.Icon:SetTexture(entry.icon)
            local counterpart, color = GetCounterpart(entry)
            row.Sender:SetText(counterpart)
            row.Sender:SetTextColor(color:GetRGB())
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

    -- Same position and behavior as in the inbox; a changed filter starts on the first page.
    local function OnFilterChanged()
        pageNum = 1
        MailLogFrame:Update()
    end
    local function OnFilterDataChanged()
        MailLogFrame:Update()
    end
    filters[1] = MailFilters:CreateSearchBox(frame, "GryphonMailLogSearchBox", OnFilterChanged)
    filters[2] = MailFilters:CreatePresetDropdown(frame, "GryphonMailLogFilterDropdown", FILTER_LAYOUT,
        OnFilterChanged, OnFilterDataChanged)

    frame.Empty = frame:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    frame.Empty:SetPoint("CENTER", frame, "CENTER", 0, 20)

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
