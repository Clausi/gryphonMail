local _, ns = ...

-- Character names on Forever consist of a first name and a surname ("Tor Donnerstein").
-- There are no realms, but names from other APIs may still carry a "-Realm" suffix.
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

-- Comparable form of a name: realm suffix removed. Returns nil for secret or empty values.
function Names.Normalize(name)
    if not IsUsableString(name) then
        return nil
    end
    return (name:gsub("%-.*$", ""))
end

-- Full name of the logged-in character, or nil while it is not available.
function Names.GetPlayerName()
    local firstName, surname = UnitName("player")
    if not IsUsableString(firstName) then
        return nil
    end
    return Names.Join(firstName, surname)
end
