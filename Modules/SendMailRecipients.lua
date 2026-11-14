local _, ns = ...
local L = ns.L

-- Dropdown next to the "To" field of the "Send Mail" tab to pick a recipient: own characters and
-- favorites, plus submenus with friends, guild members and recent allies. The last entry adds the
-- name in the "To" field to the favorites or removes it.
local SendMailRecipients = ns:RegisterModule("SendMailRecipients")
local InboxView = ns.modules.InboxView
local Characters = ns.modules.Characters
local Contacts = ns.modules.Contacts
local Favorites = ns.modules.Favorites

-- Gap between the "To" field and the dropdown; there is room for one small button before the
-- postage text on the right.
local DROPDOWN_OFFSET_X = 6

-- Icons at line height in front of the favorites title and the add/remove entry. Both textures exist
-- on every client: the raid target star and the "Pass" button of the loot roll.
local FAVORITE_ICON = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:0|t "
local REMOVE_FAVORITE_ICON = "|TInterface\\Buttons\\UI-GroupLoot-Pass-Up:0|t "

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

local function AddFavorite(description, favorite)
    AddRecipient(description, favorite.name, favorite.class)
end

local function GetFavoriteFirstName(favorite)
    return ns.Names.GetFirstName(favorite.name)
end

-- Favorites that can receive mail from this character (Characters:CanMail); long lists are split
-- into name ranges like the contacts.
local function AddFavorites(rootDescription)
    rootDescription:CreateTitle(FAVORITE_ICON .. L["FILTER_FAVORITES"])
    local favorites = {}
    for _, favorite in ipairs(Favorites:GetList()) do
        if favorite.canMail then
            favorites[#favorites + 1] = favorite
        end
    end
    if #favorites == 0 then
        AddNote(rootDescription, L["SEND_TO_FAVORITES_NONE"])
    else
        ns.AddMenuEntries(rootDescription, favorites, AddFavorite, GetFavoriteFirstName)
    end
end

-- Adds the name in the "To" field to the favorites, or removes it if it is one. Disabled while the
-- field is empty. The labels leave out the name, so the menu stays narrow.
local function AddFavoriteToggle(rootDescription)
    local text = strtrim(SendMailNameEditBox:GetText() or "")
    if text == "" then
        local label = FAVORITE_ICON .. GRAY_FONT_COLOR:WrapTextInColorCode(L["SEND_TO_FAV_ADD"])
        rootDescription:CreateButton(label):SetEnabled(false)
    elseif Favorites:Contains(text) then
        rootDescription:CreateButton(REMOVE_FAVORITE_ICON .. L["SEND_TO_FAV_REMOVE"], function()
            Favorites:Remove(text)
        end)
    else
        rootDescription:CreateButton(FAVORITE_ICON .. L["SEND_TO_FAV_ADD"], function()
            Favorites:Add(text)
        end)
    end
end

local function AddContact(description, contact)
    AddRecipient(description, contact.name, contact.class)
end

-- Long lists are split into name ranges by first name ("Abby - Fiona").
local function GetContactFirstName(contact)
    return ns.Names.GetFirstName(contact.name)
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
    ns.AddMenuEntries(submenu, contacts, AddContact, GetContactFirstName)
    return #contacts
end

local function AddFriends(rootDescription)
    local submenu = rootDescription:CreateButton(L["FILTER_FRIENDS"])
    if AddContacts(submenu, Contacts.FRIENDS) == 0 then
        AddNote(submenu, L["SEND_TO_FRIENDS_EMPTY"])
    end
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
    AddFavorites(rootDescription)
    rootDescription:CreateDivider()
    AddFriends(rootDescription)
    AddGuild(rootDescription)
    AddRecentAllies(rootDescription)
    rootDescription:CreateDivider()
    AddFavoriteToggle(rootDescription)
end

local function CreateDropdown()
    local dropdown = CreateFrame("DropdownButton", "GryphonMailSendRecipientDropdown", SendMailFrame,
        "WowStyle1ArrowDropdownTemplate")
    dropdown:SetPoint("LEFT", SendMailNameEditBox, "RIGHT", DROPDOWN_OFFSET_X, 0)
    -- The menu (all characters, friends, guild members and recent allies) can take hundreds of KB; this arrow
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
