local _, ns = ...

-- Character names are "First Surname" ("Tor Donnerstein"), unique per region, without a realm.
-- Names from some APIs may still carry a "-Realm" suffix, which is ignored. The names are shown and
-- entered as mail recipient as they are.
local Names = {}
ns.Names = Names

local separatorConsts = Constants and Constants.CharacterNameSeparatorConsts
local SEPARATOR = separatorConsts and separatorConsts.CHARACTERNAME_SURNAME_SEPARATOR or " "

local function IsUsableString(value)
    return type(value) == "string" and not (issecretvalue and issecretvalue(value)) and value ~= ""
end

-- "Tor", "Donnerstein" -> "Tor Donnerstein"; without surname just the first name.
function Names.Join(firstName, surname)
    if IsUsableString(surname) then
        return firstName .. SEPARATOR .. surname
    end
    return firstName
end

-- Comparable form of a name, without realm suffix. Returns nil for secret or empty values.
function Names.Normalize(name)
    if not IsUsableString(name) then
        return nil
    end
    return (name:gsub("%-.*$", ""))
end

-- "Tor Donnerstein" -> "Tor".
function Names.GetFirstName(name)
    return name:match("^%S+") or name
end

-- Full name of the logged-in character, or nil while it is not available. UnitName("player")
-- returns first name and surname.
function Names.GetPlayerName()
    local firstName, surname = UnitName("player")
    if not IsUsableString(firstName) then
        return nil
    end
    return Names.Join(firstName, surname)
end
