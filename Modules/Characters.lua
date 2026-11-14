local _, ns = ...
local L = ns.L
local Names = ns.Names

-- Remembers the account's own characters. There is no API listing them, so every character
-- is recorded on login in the account-wide saved variables, keyed by full name (Names.Normalize:
-- "Tor Donnerstein" on Forever, "Tor-Gehennas" on other clients).
local Characters = ns:RegisterModule("Characters")

-- The logged-in character, read once on login: { name, faction, realm, ruleset }. Name and ruleset
-- do not change during a session; the faction only when a Pandaren chooses one (refreshed then).
local player
-- Caches, rebuilt only when the stored characters change (login, faction choice, remove):
--   nameSet       set of full names for IsOwnCharacter()
--   characterList result of GetCharacters()
--   mailRealms    realms mail can go to from the logged-in character (not on Forever)
local nameSet
local characterList
local mailRealms
-- callback() runs after the stored characters or the logged-in character changed.
local listeners = {}

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
    mailRealms = nil
    for _, callback in ipairs(listeners) do
        callback()
    end
end

local function GetPlayerName()
    return player and player.name
end

-- Ruleset of a Forever realm name, nil without a realm. Forever has one mega server per ruleset,
-- made up of many realms, and characters of one ruleset can land on different ones:
-- "CAMWOW US1 Realm 10 RP" and "CAMWOW US2 Realm 11 RP" are the same mega server. No API returns
-- the ruleset, so it is read from the name: the text after "Realm <number>" ("PvE", "PVP", "RP",
-- "RPPVP"), or the last word for names without that part ("Classic Beta PvE").
local function GetRulesetName(realm)
    if not realm then
        return nil
    end
    return realm:match("Realm %d+%s+(.-)%s*$") or realm:match("(%S+)%s*$") or realm
end

-- Comparable form of GetRulesetName(): case and spaces are not consistent between realm names.
local function GetRulesetKey(realm)
    local name = GetRulesetName(realm)
    return name and (name:lower():gsub("%s+", ""))
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
        -- On Forever one of the realms of a ruleset, see GetRulesetName().
        realm = GetRealmName(),
    }
    player.ruleset = GetRulesetKey(player.realm)
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

-- Own realm and, on Retail, its connected realms; nil on Forever or before login.
local function GetMailRealms()
    if not mailRealms and player and Names.GetRealm(player.name) then
        mailRealms = { [Names.GetRealm(player.name)] = true }
        for _, realm in ipairs(C_AutoComplete.GetAutoCompleteRealms()) do
            mailRealms[realm] = true
        end
    end
    return mailRealms
end

-- True if mail can go between the logged-in character and the one with that full name
-- (Names.Normalize), faction and realm. Mail is only delivered within the same faction, not to
-- oneself, and on Forever within the same ruleset, whichever of its realms the characters are on.
-- Other clients deliver it within the own realm and, on Retail, its connected realms.
function Characters:CanMail(fullName, faction, realm)
    if not player or fullName == player.name or faction ~= player.faction then
        return false
    end
    local realms = GetMailRealms()
    if realms then
        return realms[Names.GetRealm(fullName) or ""] == true
    end
    return GetRulesetKey(realm) == player.ruleset
end

-- Faction and realm of the logged-in character, nil before login.
function Characters:GetPlayerFactionAndRealm()
    if player then
        return player.faction, player.realm
    end
end

-- callback() runs after the stored characters or the logged-in character changed.
function Characters:OnUpdate(callback)
    listeners[#listeners + 1] = callback
end

-- Returns the known characters, sorted by name. The list is cached and must not be modified:
--   { fullName = "Tor Donnerstein", displayName = "Tor Donnerstein", class = "WARRIOR",
--     faction = "Alliance", realm = "CAMWOW US1 Realm 10 RP", ruleset = "RP", isCurrent = bool,
--     canMail = bool }
-- fullName is the stored key (Names.Normalize), displayName the form to show and to enter as
-- recipient (Names.ToDisplay). realm is nil for characters not logged in since it was added.
-- ruleset is only set on Forever, the other clients have no rulesets.
-- canMail: mail can go between this character and the logged-in one (Characters:CanMail).
function Characters:GetCharacters()
    if characterList then
        return characterList
    end

    local hasRulesets = not ns.Compat.HasRealmNames()
    characterList = {}
    for _, fullName in ipairs(GetSortedNames()) do
        local info = ns.db.characters[fullName]
        characterList[#characterList + 1] = {
            fullName = fullName,
            displayName = Names.ToDisplay(fullName),
            class = info.class,
            faction = info.faction,
            realm = info.realm,
            ruleset = hasRulesets and GetRulesetName(info.realm) or nil,
            isCurrent = player ~= nil and fullName == player.name,
            canMail = self:CanMail(fullName, info.faction, info.realm),
        }
    end
    return characterList
end

-- Class-colored name, "(realm, faction)" in gray (Forever: ruleset instead of realm) and
-- "(current)", for an entry of GetCharacters().
function Characters:FormatCharacter(character)
    local line = ColorizeName(character.fullName)
    -- Either part may be unknown for old entries.
    local details = {}
    details[#details + 1] = character.ruleset or character.realm
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
