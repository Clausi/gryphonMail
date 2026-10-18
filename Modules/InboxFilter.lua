local _, ns = ...
local L = ns.L

-- Dropdown with predefined inbox filters (friends, recent allies, guild, own characters, auction house,
-- C.O.D., gold, unread, read).
-- Combines with the search box: a mail must match both.
local InboxFilter = ns:RegisterModule("InboxFilter")
local InboxView = ns.modules.InboxView
local Characters = ns.modules.Characters
local Contacts = ns.modules.Contacts

local DROPDOWN_WIDTH = 84
local DROPDOWN_OFFSET_X = 64
local DROPDOWN_OFFSET_Y = -37

local PRESET_ALL = "all"

-- Explains in the chat why the filter shows no mail when there are no recent allies to match.
local function ReportEmptyRecentAllies()
    if not Contacts:IsRecentAlliesReady() then
        ns:Print(L["RECENT_ALLIES_NOT_LOADED"])
    elseif #Contacts:GetList(Contacts.RECENT_ALLIES) == 0 then
        ns:Print(L["RECENT_ALLIES_EMPTY"])
    end
end

-- Auction house mails are recognized by Blizzard's localized subject formats, e.g. "Auction won: %s".
local AUCTION_SUBJECT_FORMATS = {
    "AUCTION_SOLD_MAIL_SUBJECT",
    "AUCTION_WON_MAIL_SUBJECT",
    "AUCTION_OUTBID_MAIL_SUBJECT",
    "AUCTION_EXPIRED_MAIL_SUBJECT",
    "AUCTION_REMOVED_MAIL_SUBJECT",
}

local auctionSubjects

-- Splits each format at its "%s" placeholder into a prefix and a suffix.
local function GetAuctionSubjects()
    if not auctionSubjects then
        auctionSubjects = {}
        for _, key in ipairs(AUCTION_SUBJECT_FORMATS) do
            local fmt = _G[key]
            local prefix, suffix
            if type(fmt) == "string" then
                prefix, suffix = fmt:match("^(.-)%%%d*%$?s(.*)$")
            end
            if prefix then
                auctionSubjects[#auctionSubjects + 1] = { prefix = prefix, suffix = suffix }
            end
        end
    end
    return auctionSubjects
end

local function IsAuctionMail(mail)
    if GetInboxInvoiceInfo(mail.index) then
        return true
    end

    local subject = mail.subject
    if type(subject) ~= "string" or (issecretvalue and issecretvalue(subject)) then
        return false
    end
    for _, pattern in ipairs(GetAuctionSubjects()) do
        local prefix, suffix = pattern.prefix, pattern.suffix
        if #subject > #prefix + #suffix
            and subject:sub(1, #prefix) == prefix
            and subject:sub(#subject - #suffix + 1) == suffix then
            return true
        end
    end
    return false
end

-- Order defines the order in the dropdown. startsGroup adds a divider above the preset, isAvailable
-- hides it while it returns false, onSelect runs when the user picks it:
--   all mail | people (own characters, friends, recent allies, guild) | read state
--   | trade (auction house, gold, C.O.D.)
local PRESETS = {
    { key = PRESET_ALL, label = "FILTER_ALL" },
    {
        key = "alts",
        label = "FILTER_ALTS",
        startsGroup = true,
        matches = function(mail)
            return Characters:IsOwnCharacter(mail.sender)
        end,
    },
    {
        key = Contacts.FRIENDS,
        label = "FILTER_FRIENDS",
        matches = function(mail)
            return Contacts:Contains(Contacts.FRIENDS, mail.sender)
        end,
    },
    {
        key = Contacts.RECENT_ALLIES,
        label = "FILTER_RECENT_ALLIES",
        isAvailable = function()
            return Contacts:IsRecentAlliesEnabled()
        end,
        onSelect = ReportEmptyRecentAllies,
        matches = function(mail)
            return Contacts:Contains(Contacts.RECENT_ALLIES, mail.sender)
        end,
    },
    {
        key = Contacts.GUILD,
        label = "FILTER_GUILD",
        matches = function(mail)
            return Contacts:Contains(Contacts.GUILD, mail.sender)
        end,
    },
    {
        key = "unread",
        label = "FILTER_UNREAD",
        startsGroup = true,
        matches = function(mail) return not mail.wasRead end,
    },
    { key = "read", label = "FILTER_READ", matches = function(mail) return mail.wasRead == true end },
    { key = "auction", label = "FILTER_AUCTION", startsGroup = true, matches = IsAuctionMail },
    { key = "money", label = "FILTER_MONEY", matches = function(mail) return mail.money > 0 end },
    { key = "cod", label = "FILTER_COD", matches = function(mail) return mail.cod > 0 end },
}

local presetsByKey = {}
for _, preset in ipairs(PRESETS) do
    presetsByKey[preset.key] = preset
end

local activeKey = PRESET_ALL

local presetFilter = {}

function presetFilter:IsActive()
    return activeKey ~= PRESET_ALL
end

function presetFilter:Matches(mail)
    return presetsByKey[activeKey].matches(mail)
end

local function SetPreset(key)
    if key == activeKey then
        return
    end
    activeKey = key
    if InboxFilter.dropdown then
        InboxFilter.dropdown:ValidateResetState()
    end
    InboxView:Refresh()
end

local function SelectPreset(key)
    SetPreset(key)
    local onSelect = presetsByKey[key].onSelect
    if onSelect then
        onSelect()
    end
end

local function IsSelected(key)
    return key == activeKey
end

local function CreateDropdown()
    local dropdown = CreateFrame("DropdownButton", "GryphonMailInboxFilterDropdown", InboxFrame,
        "WowStyle1FilterDropdownTemplate")
    -- The template sizes itself to its text; use a fixed width so it fits next to the search box.
    dropdown.resizeToText = false
    dropdown:SetWidth(DROPDOWN_WIDTH)
    dropdown:SetPoint("TOPLEFT", InboxFrame, "TOPLEFT", DROPDOWN_OFFSET_X, DROPDOWN_OFFSET_Y)

    dropdown:SetupMenu(function(_, rootDescription)
        rootDescription:SetTag("MENU_GRYPHONMAIL_INBOX_FILTER")
        for _, preset in ipairs(PRESETS) do
            if preset.startsGroup then
                rootDescription:CreateDivider()
            end
            if not preset.isAvailable or preset.isAvailable() then
                rootDescription:CreateRadio(L[preset.label], IsSelected, SelectPreset, preset.key)
            end
        end
    end)

    -- The template's reset button (shown while a preset is active) goes back to all mails.
    dropdown:SetIsDefaultCallback(function()
        return activeKey == PRESET_ALL
    end)
    dropdown:SetDefaultCallback(function()
        SetPreset(PRESET_ALL)
    end)

    -- Start unfiltered every time the mailbox is opened.
    MailFrame:HookScript("OnHide", function()
        SetPreset(PRESET_ALL)
    end)

    return dropdown
end

local function IsPresetActive(key)
    return activeKey == key
end

function InboxFilter:OnInitialize()
    InboxView:RegisterFilter(presetFilter)
    InboxView:OnReady(function()
        InboxFilter.dropdown = CreateDropdown()
    end)

    -- Preset keys of the people presets equal the contact kinds.
    Contacts:OnUpdate(function(kind)
        if IsPresetActive(kind) then
            InboxView:Redraw()
        end
    end)
end
