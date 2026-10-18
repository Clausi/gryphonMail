local _, ns = ...

-- Friends, guild members and recent allies of the logged-in character, shared by the inbox filter and
-- the "Send Mail" recipient dropdown.
-- Lists are cached and rebuilt after FRIENDLIST_UPDATE / GUILD_ROSTER_UPDATE / RECENT_ALLIES_CACHE_UPDATE.
local Contacts = ns:RegisterModule("Contacts")

Contacts.FRIENDS = "friends"
Contacts.GUILD = "guild"
Contacts.RECENT_ALLIES = "recentAllies"

-- Names in the form of Names.Normalize ("Tor Donnerstein" on Forever, "Tor-Gehennas" on other
-- clients); secret values are never matched.
local NormalizeName = ns.Names.Normalize

-- Recent allies: the realmless "Recent Allies" tab of the friends frame (C_RecentAllies).
function Contacts:IsRecentAlliesEnabled()
    return C_RecentAllies ~= nil and C_RecentAllies.IsSystemEnabled() == true
end

-- C_RecentAllies.TryRequestRecentAlliesData is protected (ADDON_ACTION_FORBIDDEN), so the addon cannot
-- load the data itself; the client usually has it already.
function Contacts:IsRecentAlliesReady()
    return self:IsRecentAlliesEnabled() and C_RecentAllies.IsRecentAllyDataReady() == true
end

local function GetClassFile(classID)
    local info = classID and C_CreatureInfo.GetClassInfo(classID)
    return info and info.classFile
end

-- Each builder fills the list with { name = full name, class = class file or nil } entries.
-- Returning false means the data is not available yet and must not be cached.
local builders = {
    [Contacts.FRIENDS] = function(add)
        for i = 1, C_FriendList.GetNumFriends() do
            local info = C_FriendList.GetFriendInfoByIndex(i)
            if info then
                add(info.name)
            end
        end
    end,
    [Contacts.GUILD] = function(add)
        if IsInGuild() then
            for i = 1, GetNumGuildMembers() do
                local name, _, _, _, _, _, _, _, _, _, classFile = GetGuildRosterInfo(i)
                add(name, classFile)
            end
        end
    end,
    [Contacts.RECENT_ALLIES] = function(add)
        if not Contacts:IsRecentAlliesReady() then
            return false
        end
        for _, ally in ipairs(C_RecentAllies.GetRecentAllies() or {}) do
            local data = ally.characterData
            if data then
                add(NormalizeName(data.fullName) or data.name, GetClassFile(data.classID))
            end
        end
    end,
}

-- cache[kind] = { list = { entries sorted by name }, byName = { [name] = entry } }
local cache = {}

local function SortByName(a, b)
    return a.name < b.name
end

local function GetCache(kind)
    if cache[kind] then
        return cache[kind]
    end
    local entry = { list = {}, byName = {} }
    local ready = builders[kind](function(rawName, class)
        local name = NormalizeName(rawName)
        if name and not entry.byName[name] then
            local contact = { name = name, class = class }
            entry.list[#entry.list + 1] = contact
            entry.byName[name] = contact
        end
    end)
    table.sort(entry.list, SortByName)
    if ready ~= false then
        cache[kind] = entry
    end
    return entry
end

-- Contacts of one kind, sorted by name: { { name = "Tor Donnerstein", class = "WARRIOR" }, ... }.
-- Do not modify the returned table.
function Contacts:GetList(kind)
    return GetCache(kind).list
end

function Contacts:Contains(kind, name)
    name = NormalizeName(name)
    return name ~= nil and GetCache(kind).byName[name] ~= nil
end

-- callback(kind) runs after the contacts of that kind changed.
local listeners = {}

function Contacts:OnUpdate(callback)
    listeners[#listeners + 1] = callback
end

local function Invalidate(kind)
    cache[kind] = nil
    for _, callback in ipairs(listeners) do
        callback(kind)
    end
end

function Contacts:OnInitialize()
    -- Ask the server for fresh friend and guild data when the mailbox opens.
    ns:RegisterEvent("MAIL_SHOW", function()
        C_FriendList.ShowFriends()
        if IsInGuild() then
            C_GuildInfo.GuildRoster()
        end
    end)

    ns:RegisterEvent("FRIENDLIST_UPDATE", function()
        Invalidate(Contacts.FRIENDS)
    end)
    ns:RegisterEvent("GUILD_ROSTER_UPDATE", function()
        Invalidate(Contacts.GUILD)
    end)
    ns:RegisterEvent("RECENT_ALLIES_CACHE_UPDATE", function()
        Invalidate(Contacts.RECENT_ALLIES)
    end)
end
