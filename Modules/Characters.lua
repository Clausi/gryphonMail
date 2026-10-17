local _, ns = ...
local L = ns.L
local Names = ns.Names

-- Remembers the account's own characters. There is no API listing them, so every character
-- is recorded on login in the account-wide saved variables, keyed by full name ("Tor Donnerstein").
local Characters = ns:RegisterModule("Characters")

-- Cached set of full names for IsOwnCharacter().
local nameSet

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

    local current = Names.GetPlayerName()
    ns:Print(L["CHARS_HEADER"])
    for i, fullName in ipairs(names) do
        local line = ("%d. %s"):format(i, ColorizeName(fullName))
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
    if fullName == Names.GetPlayerName() then
        ns:Print(L["CHARS_REMOVE_CURRENT"])
        return
    end

    local coloredName = ColorizeName(fullName)
    ns.db.characters[fullName] = nil
    nameSet = nil
    ns:Print(L["CHARS_REMOVED"], coloredName)
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
end

function Characters:OnEnable()
    local fullName = Names.GetPlayerName()
    if not fullName then
        return
    end

    local _, classFile = UnitClass("player")
    ns.db.characters[fullName] = {
        class = classFile,
        faction = UnitFactionGroup("player"),
    }
    nameSet = nil
end

-- Returns the known characters, sorted by name:
--   { fullName = "Tor Donnerstein", class = "WARRIOR", faction = "Alliance", isCurrent = bool }
function Characters:GetCharacters()
    local current = Names.GetPlayerName()
    local characters = {}
    for _, fullName in ipairs(GetSortedNames()) do
        local info = ns.db.characters[fullName]
        characters[#characters + 1] = {
            fullName = fullName,
            class = info and info.class,
            faction = info and info.faction,
            isCurrent = fullName == current,
        }
    end
    return characters
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
