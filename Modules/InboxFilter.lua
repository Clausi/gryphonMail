local _, ns = ...

-- Dropdown with predefined inbox filters (see MailFilters). Combines with the search box: a mail must
-- match both.
local InboxFilter = ns:RegisterModule("InboxFilter")
local InboxView = ns.modules.InboxView
local MailFilters = ns.modules.MailFilters
local Contacts = ns.modules.Contacts

local DIVIDER = MailFilters.DIVIDER

-- all mail | people | read state | trade
local LAYOUT = {
    MailFilters.PRESET_ALL, DIVIDER,
    "alts", Contacts.FRIENDS, Contacts.RECENT_ALLIES, Contacts.GUILD, DIVIDER,
    "unread", "read", DIVIDER,
    "auction", "money", "cod",
}

-- Filter registered with InboxView before the dropdown exists; inactive until then.
local presetFilter

local proxy = {}

function proxy:IsActive()
    return presetFilter ~= nil and presetFilter:IsActive()
end

function proxy:Matches(mail)
    return presetFilter:Matches(mail)
end

function InboxFilter:OnInitialize()
    InboxView:RegisterFilter(proxy)
    InboxView:OnReady(function()
        presetFilter = MailFilters:CreatePresetDropdown(InboxFrame, "GryphonMailInboxFilterDropdown", LAYOUT,
            function()
                InboxView:Refresh()
            end,
            function()
                InboxView:Redraw()
            end)
        InboxFilter.dropdown = presetFilter.dropdown
    end, "InboxFilter")
end
