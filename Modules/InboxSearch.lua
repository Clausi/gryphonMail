local _, ns = ...
local L = ns.L

-- Search box that filters the inbox by sender or subject.
local InboxSearch = ns:RegisterModule("InboxSearch")
local InboxView = ns.modules.InboxView
local Characters = ns.modules.Characters

local SEARCH_WIDTH = 160
local SEARCH_HEIGHT = 20
local SEARCH_OFFSET_X = -14
local SEARCH_OFFSET_Y = -36

local MAX_SUGGESTIONS = 5
local SUGGESTION_HEIGHT = 16
local SUGGESTION_PADDING = 5

local SUGGESTION_BACKDROP = {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
}

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

-- Suggestion list for own characters below the search box.
-- Own frame instead of Blizzard's shared AutoCompleteBox: that one is also used by the chat
-- edit box, and touching it from addon code can taint chat commands.
local Suggestions = {
    results = {},
    selectedIndex = 0,
}

-- True if the first name or the surname starts with the text ("tor" and "donn" both find
-- "Tor Donnerstein"), or the full name does.
local function NameStartsWith(fullName, wanted)
    local lowerName = fullName:lower()
    if lowerName:sub(1, #wanted) == wanted then
        return true
    end
    for word in lowerName:gmatch("%S+") do
        if word:sub(1, #wanted) == wanted then
            return true
        end
    end
    return false
end

-- Own characters matching the text (case-insensitive), without exact matches. Only characters that
-- can send mail to this one (same faction and ruleset, not the current character) are suggested.
local function FindSuggestions(text)
    local wanted = text:lower()
    local results = {}
    for _, character in ipairs(Characters:GetCharacters()) do
        local name = character.fullName
        if character.canMail and name:lower() ~= wanted and NameStartsWith(name, wanted) then
            results[#results + 1] = character
            if #results == MAX_SUGGESTIONS then
                break
            end
        end
    end
    return results
end

function Suggestions:Create(searchBox)
    self.searchBox = searchBox

    local frame = CreateFrame("Frame", nil, searchBox, "BackdropTemplate")
    frame:SetBackdrop(SUGGESTION_BACKDROP)
    frame:SetBackdropColor(0, 0, 0, 0.9)
    frame:SetBackdropBorderColor(0.6, 0.6, 0.6)
    frame:SetFrameStrata("DIALOG")
    frame:SetWidth(SEARCH_WIDTH)
    -- The template's search icon sits left of the edit area.
    frame:SetPoint("TOPLEFT", searchBox, "BOTTOMLEFT", -6, -2)
    frame:Hide()
    self.frame = frame

    self.buttons = {}
    for i = 1, MAX_SUGGESTIONS do
        local button = CreateFrame("Button", nil, frame)
        button:SetHeight(SUGGESTION_HEIGHT)
        button:SetPoint("TOPLEFT", SUGGESTION_PADDING, -SUGGESTION_PADDING - (i - 1) * SUGGESTION_HEIGHT)
        button:SetPoint("TOPRIGHT", -SUGGESTION_PADDING, -SUGGESTION_PADDING - (i - 1) * SUGGESTION_HEIGHT)
        button:SetNormalFontObject("GameFontHighlightSmall")
        button:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        button:SetText(" ")
        local fontString = button:GetFontString()
        fontString:ClearAllPoints()
        fontString:SetPoint("LEFT", 6, 0)
        fontString:SetPoint("RIGHT", -6, 0)
        fontString:SetJustifyH("LEFT")
        fontString:SetWordWrap(false)
        button:SetScript("OnClick", function()
            self:Accept(i)
        end)
        self.buttons[i] = button
    end
end

function Suggestions:IsShown()
    return self.frame:IsShown()
end

function Suggestions:Hide()
    self.frame:Hide()
    self.results = {}
    self.selectedIndex = 0
end

function Suggestions:Select(index)
    self.selectedIndex = index
    for i, button in ipairs(self.buttons) do
        if i == index then
            button:LockHighlight()
        else
            button:UnlockHighlight()
        end
    end
end

-- Moves the selection down (or up), wrapping around.
function Suggestions:Step(up)
    local count = #self.results
    if count == 0 then
        return
    end
    local index = self.selectedIndex + (up and -1 or 1)
    if index < 1 then
        index = count
    elseif index > count then
        index = 1
    end
    self:Select(index)
end

function Suggestions:Update(text)
    if text == "" then
        self:Hide()
        return
    end

    self.results = FindSuggestions(text)
    if #self.results == 0 then
        self:Hide()
        return
    end

    for i, button in ipairs(self.buttons) do
        local character = self.results[i]
        if character then
            local color = character.class and C_ClassColor.GetClassColor(character.class)
            button:SetText(color and color:WrapTextInColorCode(character.fullName) or character.fullName)
            button:Show()
        else
            button:Hide()
        end
    end
    self.frame:SetHeight(#self.results * SUGGESTION_HEIGHT + 2 * SUGGESTION_PADDING)
    self.frame:Show()
    self:Select(1)
end

function Suggestions:Accept(index)
    local character = self.results[index]
    self:Hide()
    if character then
        -- Programmatic SetText: OnTextChanged runs without userInput and applies the query.
        self.searchBox:SetText(character.fullName)
        self.searchBox:SetCursorPosition(#character.fullName)
    end
end

local function CreateSearchBox()
    local searchBox = CreateFrame("EditBox", "GryphonMailInboxSearchBox", InboxFrame, "SearchBoxTemplate")
    searchBox:SetSize(SEARCH_WIDTH, SEARCH_HEIGHT)
    searchBox:SetPoint("TOPRIGHT", InboxFrame, "TOPRIGHT", SEARCH_OFFSET_X, SEARCH_OFFSET_Y)
    searchBox:SetAutoFocus(false)
    searchBox.Instructions:SetText(L["SEARCH_PLACEHOLDER"])

    Suggestions:Create(searchBox)

    -- HookScript keeps the template's own handler (placeholder text, clear button).
    searchBox:HookScript("OnTextChanged", function(self, userInput)
        SetQuery(self:GetText())
        if userInput then
            Suggestions:Update(self:GetText())
        else
            Suggestions:Hide()
        end
    end)

    searchBox:HookScript("OnTabPressed", function()
        if Suggestions:IsShown() then
            Suggestions:Step(IsShiftKeyDown())
        end
    end)

    searchBox:HookScript("OnArrowPressed", function(_, key)
        if Suggestions:IsShown() and (key == "UP" or key == "DOWN") then
            Suggestions:Step(key == "UP")
        end
    end)

    -- Replaced instead of hooked: the template clears the focus on Enter/Escape, which would close
    -- the suggestions before a hook could accept the selected one. This is our own frame, so no taint.
    searchBox:SetScript("OnEnterPressed", function(self)
        if Suggestions:IsShown() and Suggestions.selectedIndex > 0 then
            Suggestions:Accept(Suggestions.selectedIndex)
        else
            self:ClearFocus()
        end
    end)

    searchBox:SetScript("OnEscapePressed", function(self)
        if Suggestions:IsShown() then
            Suggestions:Hide()
        else
            self:ClearFocus()
        end
    end)

    -- Keep the list open while it is being clicked.
    searchBox:HookScript("OnEditFocusLost", function()
        if not Suggestions.frame:IsMouseOver() then
            Suggestions:Hide()
        end
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
