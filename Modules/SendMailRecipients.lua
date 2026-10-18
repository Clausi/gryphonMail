local _, ns = ...
local L = ns.L

-- Dropdown next to the "To" field of the "Send Mail" tab to pick a recipient: own characters, plus
-- submenus with guild members and recent allies.
local SendMailRecipients = ns:RegisterModule("SendMailRecipients")
local InboxView = ns.modules.InboxView
local Characters = ns.modules.Characters
local Contacts = ns.modules.Contacts

-- Gap between the "To" field and the dropdown; there is room for one small button before the
-- postage text on the right.
local DROPDOWN_OFFSET_X = 6

-- At most this many entries per submenu; longer lists (e.g. a big guild) are split into nested
-- submenus by name range. Blizzard's scroll mode (SetScrollMode) is not used: every time a scrolling
-- menu opens, Menu.lua registers an OnScroll callback on the pooled menu frame's ScrollBox and never
-- unregisters it, which keeps the whole menu alive (~400 KB per open with ~100 recent allies).
-- Short submenus also keep Blizzard's pool of menu element frames small, which are never freed.
local MAX_ENTRIES_PER_MENU = 20

-- Blizzard's reply also puts the sender's name into this field: the full name ("First Surname") on
-- Forever, the name with realm for other realms on other clients (Names.ToDisplay). Programmatic
-- SetText runs the field's OnTextChanged, which enables the send button.
local function SelectRecipient(name)
    SendMailNameEditBox:SetText(name)
    SendMailSubjectEditBox:SetFocus()
end

local function ClassColored(name, class)
    local color = class and C_ClassColor.GetClassColor(class)
    return color and color:WrapTextInColorCode(name) or name
end

-- name: a normalized name (Names.Normalize); shown and entered in its display form.
local function AddRecipient(description, name, class)
    local displayName = ns.Names.ToDisplay(name)
    description:CreateButton(ClassColored(displayName, class), function()
        SelectRecipient(displayName)
    end)
end

local function AddNote(description, text)
    description:CreateTitle(GRAY_FONT_COLOR:WrapTextInColorCode(text))
end

local function AddOwnCharacters(rootDescription)
    rootDescription:CreateTitle(L["FILTER_ALTS"])

    local count = 0
    for _, character in ipairs(Characters:GetCharacters()) do
        -- Only characters of the same faction and realm (Forever: ruleset) can receive mail from this one.
        if character.canMail then
            AddRecipient(rootDescription, character.fullName, character.class)
            count = count + 1
        end
    end

    if count == 0 then
        AddNote(rootDescription, L["SEND_TO_CHARACTER_NONE"])
    end
end

local FirstName = ns.Names.GetFirstName

-- Adds contacts[first..last]. More than MAX_ENTRIES_PER_MENU become at most that many submenus
-- named by their first and last first name ("Abby - Fiona"), nested further if needed.
local function AddContactRange(description, contacts, first, last)
    local count = last - first + 1
    if count <= MAX_ENTRIES_PER_MENU then
        for i = first, last do
            AddRecipient(description, contacts[i].name, contacts[i].class)
        end
        return
    end

    local groupSize = MAX_ENTRIES_PER_MENU
    while math.ceil(count / groupSize) > MAX_ENTRIES_PER_MENU do
        groupSize = groupSize * MAX_ENTRIES_PER_MENU
    end
    for groupFirst = first, last, groupSize do
        local groupLast = math.min(groupFirst + groupSize - 1, last)
        local label = L["NAME_RANGE"]:format(FirstName(contacts[groupFirst].name),
            FirstName(contacts[groupLast].name))
        AddContactRange(description:CreateButton(label), contacts, groupFirst, groupLast)
    end
end

-- Submenu with the contacts of one kind (sorted by name), without the logged-in character.
-- Returns the number of entries.
local function AddContacts(submenu, kind)
    local playerName = ns.Names.GetPlayerName()
    local contacts = {}
    for _, contact in ipairs(Contacts:GetList(kind)) do
        if contact.name ~= playerName then
            contacts[#contacts + 1] = contact
        end
    end
    AddContactRange(submenu, contacts, 1, #contacts)
    return #contacts
end

local function AddGuild(rootDescription)
    local submenu = rootDescription:CreateButton(L["FILTER_GUILD"])
    if not IsInGuild() then
        AddNote(submenu, L["SEND_TO_GUILD_NONE"])
    elseif AddContacts(submenu, Contacts.GUILD) == 0 then
        AddNote(submenu, L["SEND_TO_GUILD_EMPTY"])
    end
end

local function AddRecentAllies(rootDescription)
    if not Contacts:IsRecentAlliesEnabled() then
        return
    end
    local submenu = rootDescription:CreateButton(L["FILTER_RECENT_ALLIES"])
    if not Contacts:IsRecentAlliesReady() then
        AddNote(submenu, L["RECENT_ALLIES_NOT_LOADED"])
    elseif AddContacts(submenu, Contacts.RECENT_ALLIES) == 0 then
        AddNote(submenu, L["RECENT_ALLIES_EMPTY"])
    end
end

-- Runs every time the menu opens (the dropdown regenerates it), so removed or new characters and
-- contacts show up without extra work.
local function GenerateMenu(_, rootDescription)
    rootDescription:SetTag("MENU_GRYPHONMAIL_SEND_RECIPIENT")
    AddOwnCharacters(rootDescription)
    rootDescription:CreateDivider()
    AddGuild(rootDescription)
    AddRecentAllies(rootDescription)
end

local function CreateDropdown()
    local dropdown = CreateFrame("DropdownButton", "GryphonMailSendRecipientDropdown", SendMailFrame,
        "WowStyle1ArrowDropdownTemplate")
    dropdown:SetPoint("LEFT", SendMailNameEditBox, "RIGHT", DROPDOWN_OFFSET_X, 0)
    -- The menu (all characters, guild members and recent allies) can take hundreds of KB; this arrow
    -- dropdown shows no selection text, so it is only built while open.
    ns.SetupMenuOnDemand(dropdown, GenerateMenu)

    dropdown:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["SEND_TO_RECIPIENT"])
        GameTooltip:Show()
    end)
    dropdown:HookScript("OnLeave", GameTooltip_Hide)

    return dropdown
end

function SendMailRecipients:OnInitialize()
    InboxView:OnReady(function()
        SendMailRecipients.dropdown = CreateDropdown()
    end, "SendMailRecipients")
end
