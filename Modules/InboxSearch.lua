local _, ns = ...

-- Search box that filters the inbox by sender or subject (see MailFilters).
local InboxSearch = ns:RegisterModule("InboxSearch")
local InboxView = ns.modules.InboxView
local MailFilters = ns.modules.MailFilters

-- Filter registered with InboxView before the search box exists; inactive until then.
local searchFilter

local proxy = {}

function proxy:IsActive()
    return searchFilter ~= nil and searchFilter:IsActive()
end

function proxy:Matches(mail)
    return searchFilter:Matches(mail)
end

function InboxSearch:OnInitialize()
    InboxView:RegisterFilter(proxy)
    InboxView:OnReady(function()
        searchFilter = MailFilters:CreateSearchBox(InboxFrame, "GryphonMailInboxSearchBox", function()
            InboxView:Refresh()
        end)
        InboxSearch.searchBox = searchFilter.searchBox
    end, "InboxSearch")
end
