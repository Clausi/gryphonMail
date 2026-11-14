local _, ns = ...
local L = ns.L
local Names = ns.Names

-- Favorite characters of the account: any character (e.g. a recent ally or a friend's alt) the user
-- adds, shown first in the "Send Mail" recipient dropdown, as an inbox and log filter and in the
-- search suggestions. Stored account-wide in ns.db.favorites, keyed by Names.Normalize:
--   { class = class file or nil, faction = faction, realm = realm }
-- faction and realm are those of the character that added the favorite: mail goes only within one
-- faction and realm (Forever: ruleset), so the favorite is a mail target of the characters that
-- share them (Characters:CanMail).
local Favorites = ns:RegisterModule("Favorites")
local Characters = ns.modules.Characters
local Contacts = ns.modules.Contacts

-- Preset key of the inbox and log filter (MailFilters).
Favorites.KEY = "favorites"

-- Minimap mailbox tracking icon at line height, marks mail targets in "/gryphonmail fav".
local MAIL_TARGET_ICON = "|TInterface\\Minimap\\Tracking\\Mailbox:0|t"

-- Result of GetList(), rebuilt after a change of the favorites or of the logged-in character.
local favoriteList
-- callback() runs after a favorite was added or removed.
local listeners = {}

local function Changed()
    favoriteList = nil
    for _, callback in ipairs(listeners) do
        callback()
    end
end

function Favorites:OnUpdate(callback)
    listeners[#listeners + 1] = callback
end

local function SortByName(a, b)
    return a.name < b.name
end

-- Returns the favorites, sorted by name. The list is cached and must not be modified:
--   { name = "Tor Donnerstein", displayName = "Tor Donnerstein", class = "WARRIOR", canMail = bool }
-- name is the stored key (Names.Normalize), displayName the form to show and to enter as recipient
-- (Names.ToDisplay). canMail: the favorite is a mail target of the logged-in character.
function Favorites:GetList()
    if favoriteList then
        return favoriteList
    end
    favoriteList = {}
    for name, info in pairs(ns.db.favorites) do
        -- Favorites added without a known class get it once they show up in the guild or recent allies.
        if not info.class then
            info.class = Contacts:FindClass(name)
        end
        favoriteList[#favoriteList + 1] = {
            name = name,
            displayName = Names.ToDisplay(name),
            class = info.class,
            canMail = Characters:CanMail(name, info.faction, info.realm),
        }
    end
    table.sort(favoriteList, SortByName)
    return favoriteList
end

-- Expects a name as returned by the mail API, compared with Names.Normalize.
function Favorites:Contains(name)
    local normalized = Names.Normalize(name)
    return normalized ~= nil and ns.db.favorites[normalized] ~= nil
end

local function ColorizeName(name, class)
    local color = class and C_ClassColor.GetClassColor(class)
    local displayName = Names.ToDisplay(name)
    return color and color:WrapTextInColorCode(displayName) or displayName
end

-- Adds a character (any name form, e.g. the text of the "To" field) and prints the result.
-- Returns true if it was added.
function Favorites:Add(input)
    local name = Names.Normalize(input and strtrim(input))
    if not name then
        ns:Print(L["HELP_FAV_ADD"])
        return false
    end
    if Characters:IsOwnCharacter(name) then
        ns:Print(L["FAV_OWN_CHARACTER"], ColorizeName(name))
        return false
    end
    if ns.db.favorites[name] then
        ns:Print(L["FAV_ALREADY"], ColorizeName(name, ns.db.favorites[name].class))
        return false
    end

    local faction, realm = Characters:GetPlayerFactionAndRealm()
    local class = Contacts:FindClass(name)
    ns.db.favorites[name] = { class = class, faction = faction, realm = realm }
    Changed()
    ns:Print(L["FAV_ADDED"], ColorizeName(name, class))
    return true
end

-- Removes a favorite (name as stored or in any form Names.Normalize accepts) and prints the
-- result. Returns true if it was removed.
function Favorites:Remove(name)
    name = Names.Normalize(name)
    local info = name and ns.db.favorites[name]
    if not info then
        return false
    end
    ns.db.favorites[name] = nil
    Changed()
    ns:Print(L["FAV_REMOVED"], ColorizeName(name, info.class))
    return true
end

-- Resolves a number from "/gryphonmail fav" or a name (also "Name" for the own realm),
-- case-insensitive.
local function FindFavorite(input)
    local list = Favorites:GetList()
    local number = tonumber(input)
    if number then
        return list[number] and list[number].name
    end
    local wanted = (Names.Normalize(input) or input):lower()
    for _, favorite in ipairs(list) do
        if favorite.name:lower() == wanted then
            return favorite.name
        end
    end
    return nil
end

local function ListFavorites()
    local list = Favorites:GetList()
    if #list == 0 then
        ns:Print(L["FAV_EMPTY"])
        return
    end
    ns:Print(L["FAV_HEADER"], MAIL_TARGET_ICON)
    for i, favorite in ipairs(list) do
        local line = ColorizeName(favorite.name, favorite.class)
        if favorite.canMail then
            line = MAIL_TARGET_ICON .. " " .. line
        end
        ns:Print(("%d. %s"):format(i, line))
    end
end

local function RemoveFavorite(input)
    if input == "" then
        ns:Print(L["HELP_FAV_REMOVE"])
        return
    end
    local name = FindFavorite(input)
    if not name then
        ns:Print(L["FAV_NOT_FOUND"], input)
        return
    end
    Favorites:Remove(name)
end

function Favorites:OnInitialize()
    ns:RegisterCommand("fav", function(args)
        local action, rest = args:match("^(%S*)%s*(.-)$")
        action = action:lower()
        if action == "add" then
            Favorites:Add(rest)
        elseif action == "remove" then
            RemoveFavorite(rest)
        else
            ListFavorites()
        end
    end, { L["HELP_FAV"], L["HELP_FAV_ADD"], L["HELP_FAV_REMOVE"] })

    -- Mail targets depend on the logged-in character (login, faction choice).
    Characters:OnUpdate(function()
        favoriteList = nil
    end)
end
