local _, ns = ...
local L = ns.L

-- Search box and preset dropdown shared by the inbox and the mail log. Both work on mail objects:
--   { name, subject, money, cod, wasRead, sent, deleted, returned, index }
--   name     the other character: sender of received mail, recipient of sent mail
--   cod      C.O.D. amount (to pay, paid or requested)
--   wasRead  inbox only
--   sent     log only: true for sent mail
--   deleted  log only: true for deleted mail
--   returned log only: true for returned mail
--   index    inbox only: inbox index, for the auction house invoice
-- Each created search box or dropdown is a filter with IsActive() and Matches(mail).
local MailFilters = ns:RegisterModule("MailFilters")
local Characters = ns.modules.Characters
local Contacts = ns.modules.Contacts

-- Both widgets sit in the top row of MailFrame, as children of InboxFrame or the log.
local SEARCH_WIDTH = 160
local SEARCH_HEIGHT = 20
local SEARCH_OFFSET_X = -14
local SEARCH_OFFSET_Y = -36

local DROPDOWN_WIDTH = 84
local DROPDOWN_OFFSET_X = 64
-- The dropdown is anchored at its vertical center, on the center line of the search box: the
-- filter dropdown template is 18 high on Forever and Retail and 22 on Classic.
local DROPDOWN_CENTER_Y = SEARCH_OFFSET_Y - SEARCH_HEIGHT / 2

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

MailFilters.PRESET_ALL = "all"

-- Mail names and subjects could be secret values on Forever; those are never matched.
local function IsUsableString(text)
    return type(text) == "string" and not (issecretvalue and issecretvalue(text))
end

-- Explains in the chat why the filter shows no mail when there are no recent allies to match.
local function ReportEmptyRecentAllies()
    if not Contacts:IsRecentAlliesReady() then
        ns:Notify(L["RECENT_ALLIES_NOT_LOADED"])
    elseif #Contacts:GetList(Contacts.RECENT_ALLIES) == 0 then
        ns:Notify(L["RECENT_ALLIES_EMPTY"])
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
    if mail.sent then
        return false
    end
    if mail.index and GetInboxInvoiceInfo(mail.index) then
        return true
    end

    local subject = mail.subject
    if not IsUsableString(subject) then
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

-- All presets. A dropdown shows the ones its caller lists, in that order.
--   isAvailable hides the preset while it returns false, onSelect runs when the user picks it.
local PRESETS = {
    [MailFilters.PRESET_ALL] = { label = "FILTER_ALL" },
    alts = {
        label = "FILTER_ALTS",
        matches = function(mail)
            return Characters:IsOwnCharacter(mail.name)
        end,
    },
    [Contacts.FRIENDS] = {
        label = "FILTER_FRIENDS",
        matches = function(mail)
            return Contacts:Contains(Contacts.FRIENDS, mail.name)
        end,
    },
    [Contacts.RECENT_ALLIES] = {
        label = "FILTER_RECENT_ALLIES",
        isAvailable = function()
            return Contacts:IsRecentAlliesEnabled()
        end,
        onSelect = ReportEmptyRecentAllies,
        matches = function(mail)
            return Contacts:Contains(Contacts.RECENT_ALLIES, mail.name)
        end,
    },
    [Contacts.GUILD] = {
        label = "FILTER_GUILD",
        matches = function(mail)
            return Contacts:Contains(Contacts.GUILD, mail.name)
        end,
    },
    unread = { label = "FILTER_UNREAD", matches = function(mail) return not mail.wasRead end },
    read = { label = "FILTER_READ", matches = function(mail) return mail.wasRead == true end },
    received = {
        label = "FILTER_RECEIVED",
        matches = function(mail) return not mail.sent and not mail.deleted and not mail.returned end,
    },
    sent = { label = "FILTER_SENT", matches = function(mail) return mail.sent == true end },
    returned = { label = "FILTER_RETURNED", matches = function(mail) return mail.returned == true end },
    deleted = { label = "FILTER_DELETED", matches = function(mail) return mail.deleted == true end },
    auction = { label = "FILTER_AUCTION", matches = IsAuctionMail },
    money = { label = "FILTER_MONEY", matches = function(mail) return mail.money > 0 end },
    cod = { label = "FILTER_COD", matches = function(mail) return mail.cod > 0 end },
}

-- Separates groups in a preset layout.
MailFilters.DIVIDER = "divider"

local PresetFilter = {}
PresetFilter.__index = PresetFilter

function PresetFilter:IsActive()
    return self.activeKey ~= MailFilters.PRESET_ALL
end

function PresetFilter:Matches(mail)
    return PRESETS[self.activeKey].matches(mail)
end

function PresetFilter:Set(key)
    if key == self.activeKey then
        return
    end
    self.activeKey = key
    self.dropdown:ValidateResetState()
    self.onChange()
end

function PresetFilter:Reset()
    self:Set(MailFilters.PRESET_ALL)
end

-- Creates the preset dropdown in the top left of MailFrame, as a child of parent.
--   layout   preset keys and MailFilters.DIVIDER, in dropdown order
--   onChange called after the user picked another preset
--   onDataChange called when the data behind the active preset changed (e.g. guild roster)
function MailFilters:CreatePresetDropdown(parent, frameName, layout, onChange, onDataChange)
    local filter = setmetatable({ activeKey = MailFilters.PRESET_ALL, onChange = onChange }, PresetFilter)

    local dropdown = CreateFrame("DropdownButton", frameName, parent, "WowStyle1FilterDropdownTemplate")
    -- The template sizes itself to its text; use a fixed width so it fits next to the search box.
    dropdown.resizeToText = false
    dropdown:SetWidth(DROPDOWN_WIDTH)
    dropdown:SetPoint("LEFT", MailFrame, "TOPLEFT", DROPDOWN_OFFSET_X, DROPDOWN_CENTER_Y)
    filter.dropdown = dropdown

    local function IsSelected(key)
        return key == filter.activeKey
    end
    local function Select(key)
        filter:Set(key)
        if PRESETS[key].onSelect then
            PRESETS[key].onSelect()
        end
    end

    -- The filter template always shows "Filter" and its reset button uses the callbacks below, so the
    -- menu is only built while open.
    ns.SetupMenuOnDemand(dropdown, function(_, rootDescription)
        rootDescription:SetTag("MENU_GRYPHONMAIL_FILTER")
        for _, key in ipairs(layout) do
            local preset = PRESETS[key]
            if key == MailFilters.DIVIDER then
                rootDescription:CreateDivider()
            elseif not preset.isAvailable or preset.isAvailable() then
                rootDescription:CreateRadio(L[preset.label], IsSelected, Select, key)
            end
        end
    end)

    -- The template's reset button (shown while a preset is active) goes back to all mails.
    dropdown:SetIsDefaultCallback(function()
        return filter.activeKey == MailFilters.PRESET_ALL
    end)
    dropdown:SetDefaultCallback(function()
        filter:Reset()
    end)

    -- Preset keys of the people presets equal the contact kinds.
    Contacts:OnUpdate(function(kind)
        if filter.activeKey == kind then
            onDataChange()
        end
    end)

    -- Start unfiltered every time the mailbox is opened.
    MailFrame:HookScript("OnHide", function()
        filter:Reset()
    end)

    return filter
end

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
-- can exchange mail with this one (same faction and ruleset, not the current character) are suggested.
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

-- Suggestion list for own characters below a search box.
-- Own frame instead of Blizzard's shared AutoCompleteBox: that one is also used by the chat
-- edit box, and touching it from addon code can taint chat commands.
local Suggestions = {}
Suggestions.__index = Suggestions

local function CreateSuggestions(searchBox)
    local self = setmetatable({ searchBox = searchBox, results = {}, selectedIndex = 0 }, Suggestions)

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
    return self
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

local SearchFilter = {}
SearchFilter.__index = SearchFilter

function SearchFilter:IsActive()
    return self.query ~= ""
end

function SearchFilter:Contains(text)
    return IsUsableString(text) and text:lower():find(self.query, 1, true) ~= nil
end

function SearchFilter:Matches(mail)
    return self:Contains(mail.name) or self:Contains(mail.subject)
end

function SearchFilter:SetQuery(text)
    local query = strtrim(text or ""):lower()
    if query == self.query then
        return
    end
    self.query = query
    self.onChange()
end

-- Creates the search box (name or subject) in the top right of MailFrame, as a child of parent.
-- InboxFrame fills MailFrame on Forever, but has a fixed size of 384 x 512 on Retail and Classic,
-- wider than the visible frame, so the box is anchored to MailFrame. onChange runs after the search
-- text changed.
function MailFilters:CreateSearchBox(parent, frameName, onChange)
    local filter = setmetatable({ query = "", onChange = onChange }, SearchFilter)

    local searchBox = CreateFrame("EditBox", frameName, parent, "SearchBoxTemplate")
    searchBox:SetSize(SEARCH_WIDTH, SEARCH_HEIGHT)
    searchBox:SetPoint("TOPRIGHT", MailFrame, "TOPRIGHT", SEARCH_OFFSET_X, SEARCH_OFFSET_Y)
    searchBox:SetAutoFocus(false)
    searchBox.Instructions:SetText(L["SEARCH_PLACEHOLDER"])
    filter.searchBox = searchBox

    local suggestions = CreateSuggestions(searchBox)

    -- HookScript keeps the template's own handler (placeholder text, clear button).
    searchBox:HookScript("OnTextChanged", function(box, userInput)
        filter:SetQuery(box:GetText())
        if userInput then
            suggestions:Update(box:GetText())
        else
            suggestions:Hide()
        end
    end)

    searchBox:HookScript("OnTabPressed", function()
        if suggestions:IsShown() then
            suggestions:Step(IsShiftKeyDown())
        end
    end)

    searchBox:HookScript("OnArrowPressed", function(_, key)
        if suggestions:IsShown() and (key == "UP" or key == "DOWN") then
            suggestions:Step(key == "UP")
        end
    end)

    -- Replaced instead of hooked: the template clears the focus on Enter/Escape, which would close
    -- the suggestions before a hook could accept the selected one. This is our own frame, so no taint.
    searchBox:SetScript("OnEnterPressed", function(box)
        if suggestions:IsShown() and suggestions.selectedIndex > 0 then
            suggestions:Accept(suggestions.selectedIndex)
        else
            box:ClearFocus()
        end
    end)

    searchBox:SetScript("OnEscapePressed", function(box)
        if suggestions:IsShown() then
            suggestions:Hide()
        else
            box:ClearFocus()
        end
    end)

    -- Keep the list open while it is being clicked.
    searchBox:HookScript("OnEditFocusLost", function()
        if not suggestions.frame:IsMouseOver() then
            suggestions:Hide()
        end
    end)

    -- Start unfiltered every time the mailbox is opened.
    MailFrame:HookScript("OnHide", function()
        searchBox:SetText("")
        searchBox:ClearFocus()
    end)

    return filter
end
