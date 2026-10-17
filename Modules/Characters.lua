local _, ns = ...
local L = ns.L
local Names = ns.Names

-- Remembers the account's own characters. There is no API listing them, so every character
-- is recorded on login in the account-wide saved variables, keyed by full name ("Tor Donnerstein").
local Characters = ns:RegisterModule("Characters")

-- The logged-in character, read once on login: { name, faction, realm }. Name and ruleset do not
-- change during a session; the faction only when a Pandaren chooses one (refreshed then).
local player
-- Caches, rebuilt only when the stored characters change (login, faction choice, remove):
--   nameSet       set of full names for IsOwnCharacter()
--   characterList result of GetCharacters()
local nameSet
local characterList

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
    return color and color:WrapTextInColorCode(fullName) or fullName
end

-- Resolves a number from the list, a full name or a unique first name, case-insensitive.
local function FindCharacter(input)
    local names = GetSortedNames()
    local number = tonumber(input)
    if number then
        return names[number]
    end

    local wanted = input:lower()
    local firstNameMatch
    local firstNameMatches = 0
    for _, fullName in ipairs(names) do
        local lowerName = fullName:lower()
        if lowerName == wanted then
            return fullName
        end
        if lowerName:match("^%S+") == wanted then
            firstNameMatch = fullName
            firstNameMatches = firstNameMatches + 1
        end
    end
    return firstNameMatches == 1 and firstNameMatch or nil
end

local function ListCharacters()
    local names = GetSortedNames()
    if #names == 0 then
        ns:Print(L["CHARS_EMPTY"])
        return
    end

    local current = GetPlayerName()
    ns:Print(L["CHARS_HEADER"])
    for i, fullName in ipairs(names) do
        local line = ("%d. %s"):format(i, ColorizeName(fullName))
        local realm = ns.db.characters[fullName].realm
        if realm then
            line = line .. " " .. GRAY_FONT_COLOR:WrapTextInColorCode("(" .. realm .. ")")
        end
        if fullName == current then
            line = line .. " " .. L["CHARS_CURRENT"]
        end
        ns:Print(line)
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
    if fullName == GetPlayerName() then
        ns:Print(L["CHARS_REMOVE_CURRENT"])
        return
    end

    local coloredName = ColorizeName(fullName)
    ns.db.characters[fullName] = nil
    InvalidateCaches()
    ns:Print(L["CHARS_REMOVED"], coloredName)
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
--   { fullName = "Tor Donnerstein", class = "WARRIOR", faction = "Alliance",
--     realm = "Classic Beta PvE", isCurrent = bool, canMail = bool }
-- realm is nil for characters not logged in since it was added.
-- canMail: mail can go between this character and the logged-in one. Forever only delivers mail
-- within the same faction and ruleset (each ruleset is its own realm), and not to oneself.
function Characters:GetCharacters()
    if characterList then
        return characterList
    end

    characterList = {}
    for _, fullName in ipairs(GetSortedNames()) do
        local info = ns.db.characters[fullName]
        local isCurrent = player ~= nil and fullName == player.name
        characterList[#characterList + 1] = {
            fullName = fullName,
            class = info.class,
            faction = info.faction,
            realm = info.realm,
            isCurrent = isCurrent,
            canMail = player ~= nil and not isCurrent
                and info.faction == player.faction and info.realm == player.realm,
        }
    end
    return characterList
end

-- Expects a name as returned by the mail API; a possible realm suffix is ignored.
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
