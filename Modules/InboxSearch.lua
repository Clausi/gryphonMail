local _, ns = ...
local L = ns.L

-- Search box that filters the inbox by sender or subject.
local InboxSearch = ns:RegisterModule("InboxSearch")
local InboxView = ns.modules.InboxView

local SEARCH_WIDTH = 160
local SEARCH_HEIGHT = 20
local SEARCH_OFFSET_X = -14
local SEARCH_OFFSET_Y = -36

-- Current search text, lowercased. Empty string means no filter.
local query = ""

-- Mail sender and subject could be secret values on Forever; those are never matched.
local function Contains(text)
    if type(text) ~= "string" or (issecretvalue and issecretvalue(text)) then
        return false
    end
    return text:lower():find(query, 1, true) ~= nil
end

local searchFilter = {}

function searchFilter:IsActive()
    return query ~= ""
end

function searchFilter:Matches(mail)
    return Contains(mail.sender) or Contains(mail.subject)
end

local function SetQuery(text)
    local newQuery = strtrim(text or ""):lower()
    if newQuery == query then
        return
    end
    query = newQuery
    InboxView:Refresh()
end

local function CreateSearchBox()
    local searchBox = CreateFrame("EditBox", "GryphonMailInboxSearchBox", InboxFrame, "SearchBoxTemplate")
    searchBox:SetSize(SEARCH_WIDTH, SEARCH_HEIGHT)
    searchBox:SetPoint("TOPRIGHT", InboxFrame, "TOPRIGHT", SEARCH_OFFSET_X, SEARCH_OFFSET_Y)
    searchBox:SetAutoFocus(false)
    searchBox.Instructions:SetText(L["SEARCH_PLACEHOLDER"])

    -- HookScript keeps the template's own handler (placeholder text, clear button).
    searchBox:HookScript("OnTextChanged", function(self)
        SetQuery(self:GetText())
    end)

    -- Start unfiltered every time the mailbox is opened.
    MailFrame:HookScript("OnHide", function()
        searchBox:SetText("")
        searchBox:ClearFocus()
    end)

    return searchBox
end

function InboxSearch:OnInitialize()
    InboxView:RegisterFilter(searchFilter)
    InboxView:OnReady(function()
        InboxSearch.searchBox = CreateSearchBox()
    end)
end
