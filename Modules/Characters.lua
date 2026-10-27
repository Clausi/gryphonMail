local _, ns = ...
local L = ns.L
local Names = ns.Names

-- Remembers the account's own characters. There is no API listing them, so every character
-- is recorded on login in the account-wide saved variables, keyed by full name (Names.Normalize:
-- "Tor Donnerstein" on Forever, "Tor-Gehennas" on other clients).
local Characters = ns:RegisterModule("Characters")

-- The logged-in character, read once on login: { name, faction, realm }. Name and ruleset do not
-- change during a session; the faction only when a Pandaren chooses one (refreshed then).
local player
-- Caches, rebuilt only when the stored characters change (login, faction choice, remove):
--   nameSet       set of full names for IsOwnCharacter()
--   characterList result of GetCharacters()
local nameSet
local characterList

-- Localized faction names for UnitFactionGroup() values, shown by "/gryphonmail chars".
local FACTION_LABELS = {
    Alliance = L["FACTION_ALLIANCE"],
    Horde = L["FACTION_HORDE"],
    Neutral = L["FACTION_NEUTRAL"],
}

-- Minimap mailbox tracking icon at line height, marks mail targets in "/gryphonmail chars".
local MAIL_TARGET_ICON = "|TInterface\\Minimap\\Tracking\\Mailbox:0|t"

local function InvalidateCaches()
    nameSet = nil
    characterList = nil
end

local function GetPlayerName()
    return player and player.name
end

-- Returns the stored full names, sorted. The order defines the numbers shown by "/gryphonmail chars".
local function GetSortedNames()
    local names = {}
    for fullName in pairs(ns.db.characters) do
        names[#names + 1] = fullName
    end
    table.sort(names)
    return names
end

local function ColorizeName(fullName)
    local info = ns.db.characters[fullName]
    local color = info and info.class and C_ClassColor.GetClassColor(info.class)
    local displayName = Names.ToDisplay(fullName)
    return color and color:WrapTextInColorCode(displayName) or displayName
end

-- Resolves a number from the list, a full name (also "Name" for the own realm) or a unique first
-- name, case-insensitive.
local function FindCharacter(input)
    local names = GetSortedNames()
    local number = tonumber(input)
    if number then
        return names[number]
    end

    local wanted = input:lower()
    local wantedFullName = (Names.Normalize(input) or input):lower()
    local firstNameMatch
    local firstNameMatches = 0
    for _, fullName in ipairs(names) do
        if fullName:lower() == wantedFullName then
            return fullName
        end
        if Names.GetFirstName(fullName):lower() == wanted then
            firstNameMatch = fullName
            firstNameMatches = firstNameMatches + 1
        end
    end
    return firstNameMatches == 1 and firstNameMatch or nil
end

local function ListCharacters()
    -- Same order as GetSortedNames(), so the numbers match "chars remove".
    local characters = Characters:GetCharacters()
    if #characters == 0 then
        ns:Print(L["CHARS_EMPTY"])
        return
    end

    ns:Print(L["CHARS_HEADER"], MAIL_TARGET_ICON)
    for i, character in ipairs(characters) do
        local line = Characters:FormatCharacter(character)
        if character.canMail then
            line = MAIL_TARGET_ICON .. " " .. line
        end
        ns:Print(("%d. %s"):format(i, line))
    end
end

local function RemoveCharacter(input)
    if input == "" then
        ns:Print(L["HELP_CHARS_REMOVE"])
        return
    end

    local fullName = FindCharacter(input)
    if not fullName then
        ns:Print(L["CHARS_NOT_FOUND"], input)
        return
    end
    Characters:Remove(fullName)
end

-- Reads the logged-in character and records it in the saved variables.
local function RecordPlayer()
    local fullName = Names.GetPlayerName()
    if not fullName then
        return
    end

    player = {
        name = fullName,
        faction = UnitFactionGroup("player"),
        -- Forever runs each ruleset (PvE, PvP, RP) as its own realm, e.g. "Classic Beta PvE";
        -- characters can only trade and send mail within it.
        realm = GetRealmName(),
    }
    local _, classFile = UnitClass("player")
    ns.db.characters[fullName] = {
        class = classFile,
        faction = player.faction,
        realm = player.realm,
    }
    InvalidateCaches()
end

function Characters:OnInitialize()
    ns:RegisterCommand("chars", function(args)
        local action, rest = args:match("^(%S*)%s*(.-)$")
        if action:lower() == "remove" then
            RemoveCharacter(rest)
        else
            ListCharacters()
        end
    end, { L["HELP_CHARS"], L["HELP_CHARS_REMOVE"] })

    -- A Pandaren picks a faction during the session; mail targets change with it.
    ns:RegisterEvent("NEUTRAL_FACTION_SELECT_RESULT", RecordPlayer)
end

function Characters:OnEnable()
    RecordPlayer()
end

-- Returns the known characters, sorted by name. The list is cached and must not be modified:
--   { fullName = "Tor Donnerstein", displayName = "Tor Donnerstein", class = "WARRIOR",
--     faction = "Alliance", realm = "Classic Beta PvE", isCurrent = bool, canMail = bool }
-- fullName is the stored key (Names.Normalize), displayName the form to show and to enter as
-- recipient (Names.ToDisplay). realm is nil for characters not logged in since it was added.
-- canMail: mail can go between this character and the logged-in one. It is only delivered within
-- the same faction, not to oneself, and on Forever within the same ruleset (each ruleset is its own
-- realm). Other clients deliver it within the own realm and, on Retail, its connected realms.
function Characters:GetCharacters()
    if characterList then
        return characterList
    end

    local mailRealms
    if player and Names.GetRealm(player.name) then
        mailRealms = { [Names.GetRealm(player.name)] = true }
        for _, realm in ipairs(C_AutoComplete.GetAutoCompleteRealms()) do
            mailRealms[realm] = true
        end
    end

    characterList = {}
    for _, fullName in ipairs(GetSortedNames()) do
        local info = ns.db.characters[fullName]
        local isCurrent = player ~= nil and fullName == player.name
        local sameRealm
        if mailRealms then
            sameRealm = mailRealms[Names.GetRealm(fullName) or ""] == true
        else
            sameRealm = player ~= nil and info.realm == player.realm
        end
        characterList[#characterList + 1] = {
            fullName = fullName,
            displayName = Names.ToDisplay(fullName),
            class = info.class,
            faction = info.faction,
            realm = info.realm,
            isCurrent = isCurrent,
            canMail = player ~= nil and not isCurrent and info.faction == player.faction and sameRealm,
        }
    end
    return characterList
end

-- Class-colored name, "(realm, faction)" in gray and "(current)", for an entry of GetCharacters().
function Characters:FormatCharacter(character)
    local line = ColorizeName(character.fullName)
    -- "(realm, faction)", either part may be unknown for old entries.
    local details = {}
    details[#details + 1] = character.realm
    details[#details + 1] = FACTION_LABELS[character.faction] or character.faction
    if #details > 0 then
        line = line .. " " .. GRAY_FONT_COLOR:WrapTextInColorCode("(" .. table.concat(details, ", ") .. ")")
    end
    if character.isCurrent then
        line = line .. " " .. L["CHARS_CURRENT"]
    end
    return line
end

-- Forgets a stored character (fullName as in GetCharacters()) and prints the result. The logged-in
-- character cannot be removed. Returns true if it was removed.
function Characters:Remove(fullName)
    if fullName == GetPlayerName() then
        ns:Print(L["CHARS_REMOVE_CURRENT"])
        return false
    end
    if not ns.db.characters[fullName] then
        return false
    end

    local coloredName = ColorizeName(fullName)
    ns.db.characters[fullName] = nil
    InvalidateCaches()
    ns:Print(L["CHARS_REMOVED"], coloredName)
    return true
end

-- Expects a name as returned by the mail API, compared with Names.Normalize.
function Characters:IsOwnCharacter(name)
    if not nameSet then
        nameSet = {}
        for fullName in pairs(ns.db.characters) do
            nameSet[fullName] = true
        end
    end
    local normalized = Names.Normalize(name)
    return normalized ~= nil and nameSet[normalized] == true
end
