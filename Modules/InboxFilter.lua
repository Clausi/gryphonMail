local _, ns = ...
local L = ns.L

-- Dropdown with predefined inbox filters (friends, recent allies, guild, own characters, auction house,
-- C.O.D., gold, unread, read).
-- Combines with the search box: a mail must match both.
local InboxFilter = ns:RegisterModule("InboxFilter")
local InboxView = ns.modules.InboxView
local Characters = ns.modules.Characters

local DROPDOWN_WIDTH = 84
local DROPDOWN_OFFSET_X = 64
local DROPDOWN_OFFSET_Y = -37

local PRESET_ALL = "all"

-- Full names ("Tor Donnerstein") without realm suffix; secret values are never matched.
local NormalizeName = ns.Names.Normalize

-- Name sets are cached and rebuilt after FRIENDLIST_UPDATE / RECENT_ALLIES_CACHE_UPDATE /
-- GUILD_ROSTER_UPDATE.
local friendNames
local recentAllyNames
local guildNames

local function GetFriendNames()
    if not friendNames then
        friendNames = {}
        for i = 1, C_FriendList.GetNumFriends() do
            local info = C_FriendList.GetFriendInfoByIndex(i)
            local name = info and NormalizeName(info.name)
            if name then
                friendNames[name] = true
            end
        end
    end
    return friendNames
end

-- Recent allies: the realmless "Recent Allies" tab of the friends frame (C_RecentAllies).
local function IsRecentAlliesEnabled()
    return C_RecentAllies ~= nil and C_RecentAllies.IsSystemEnabled() == true
end

local function GetRecentAllyNames()
    if recentAllyNames then
        return recentAllyNames
    end
    if not (IsRecentAlliesEnabled() and C_RecentAllies.IsRecentAllyDataReady()) then
        -- Not loaded yet: do not cache the empty set, RECENT_ALLIES_CACHE_UPDATE follows.
        return {}
    end
    recentAllyNames = {}
    for _, ally in ipairs(C_RecentAllies.GetRecentAllies() or {}) do
        local data = ally.characterData
        local name = data and (NormalizeName(data.fullName) or NormalizeName(data.name))
        if name then
            recentAllyNames[name] = true
        end
    end
    return recentAllyNames
end

-- Explains in the chat why the filter shows no mail when there are no recent allies to match.
local function ReportEmptyRecentAllies()
    if not C_RecentAllies.IsRecentAllyDataReady() then
        ns:Print(L["RECENT_ALLIES_NOT_LOADED"])
    elseif next(GetRecentAllyNames()) == nil then
        ns:Print(L["RECENT_ALLIES_EMPTY"])
    end
end

local function GetGuildNames()
    if not guildNames then
        guildNames = {}
        if IsInGuild() then
            for i = 1, GetNumGuildMembers() do
                local name = NormalizeName((GetGuildRosterInfo(i)))
                if name then
                    guildNames[name] = true
                end
            end
        end
    end
    return guildNames
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
        key = "friends",
        label = "FILTER_FRIENDS",
        matches = function(mail)
            local name = NormalizeName(mail.sender)
            return name ~= nil and GetFriendNames()[name] == true
        end,
    },
    {
        key = "recentAllies",
        label = "FILTER_RECENT_ALLIES",
        isAvailable = IsRecentAlliesEnabled,
        onSelect = ReportEmptyRecentAllies,
        matches = function(mail)
            local name = NormalizeName(mail.sender)
            return name ~= nil and GetRecentAllyNames()[name] == true
        end,
    },
    {
        key = "guild",
        label = "FILTER_GUILD",
        matches = function(mail)
            local name = NormalizeName(mail.sender)
            return name ~= nil and GetGuildNames()[name] == true
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

    -- Ask the server for fresh friend and guild data when the mailbox opens. Recent allies cannot be
    -- requested: C_RecentAllies.TryRequestRecentAlliesData is protected (ADDON_ACTION_FORBIDDEN).
    -- Their data arrives with RECENT_ALLIES_CACHE_UPDATE once the client has loaded it.
    ns:RegisterEvent("MAIL_SHOW", function()
        C_FriendList.ShowFriends()
        if IsInGuild() then
            C_GuildInfo.GuildRoster()
        end
    end)

    ns:RegisterEvent("FRIENDLIST_UPDATE", function()
        friendNames = nil
        if IsPresetActive("friends") then
            InboxView:Redraw()
        end
    end)

    ns:RegisterEvent("RECENT_ALLIES_CACHE_UPDATE", function()
        recentAllyNames = nil
        if IsPresetActive("recentAllies") then
            InboxView:Redraw()
        end
    end)

    ns:RegisterEvent("GUILD_ROSTER_UPDATE", function()
        guildNames = nil
        if IsPresetActive("guild") then
            InboxView:Redraw()
        end
    end)
end
