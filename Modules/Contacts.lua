local _, ns = ...

-- Friends, guild members and recent allies of the logged-in character, shared by the inbox filter and
-- the "Send Mail" recipient dropdown.
-- Lists are cached and rebuilt after FRIENDLIST_UPDATE (also BN_FRIEND_* on Forever) / GUILD_ROSTER_UPDATE /
-- RECENT_ALLIES_CACHE_UPDATE.
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

-- Do not change during a session.
local hasCharacterFriendList
local hasBattleNetFriends

local function HasCharacterFriendList()
    if hasCharacterFriendList == nil then
        hasCharacterFriendList = ns.Compat.HasCharacterFriendList()
    end
    return hasCharacterFriendList
end

-- Characters of Battle.net friends are only listed on Forever: their names are unique without a
-- realm there. Forever's friends frame shows them next to the character friends, if that list is
-- enabled (Blizzard_FriendsFrame/Camelot/FriendsFrame.lua).
local function HasBattleNetFriends()
    if hasBattleNetFriends == nil then
        hasBattleNetFriends = not ns.Compat.HasRealmNames()
    end
    return hasBattleNetFriends
end

-- True if the game account is a character online in this game version and region.
local function IsInThisGame(gameAccount)
    return gameAccount ~= nil and gameAccount.isOnline and gameAccount.clientProgram == BNET_CLIENT_WOW
        and gameAccount.wowProjectID == WOW_PROJECT_ID and gameAccount.isInCurrentRegion
end

-- A WoW character of a Battle.net friend that can exchange mail with the logged-in character:
-- online in this game version and region, same faction and (Characters:CanMail) ruleset.
local function GetMailableCharacter(gameAccount)
    if not IsInThisGame(gameAccount) then
        return nil
    end
    local name = NormalizeName(gameAccount.characterName)
    if name and ns.modules.Characters:CanMail(name, gameAccount.factionName, gameAccount.realmName, nil,
        gameAccount.playerGuid) then
        return name
    end
    return nil
end

-- Character name of a title friend (Forever: a character added by name in the friends frame, a
-- Battle.net friend of friend level Title), nil for other friends. It is the target Blizzard's chat
-- whispers (ChatFrameUtil.lua) and is known while the friend is offline.
local function GetTitleFriendName(accountInfo)
    local titleLevel = Enum.BattleNetFriendLevel and Enum.BattleNetFriendLevel.Title
    if not titleLevel or accountInfo.friendLevel ~= titleLevel
        or not C_BattleNet.GetDefaultTitleWhisperTarget then
        return nil
    end
    return NormalizeName(C_BattleNet.GetDefaultTitleWhisperTarget(accountInfo.bnetAccountID))
end

-- Battle.net friends only have a character while they are online. A title friend is one character,
-- so it is also listed while offline; faction and ruleset are unknown then, it is listed unchecked.
local function AddBattleNetFriends(add)
    for i = 1, BNGetNumFriends() or 0 do
        local isInThisGame = false
        for j = 1, C_BattleNet.GetFriendNumGameAccounts(i) or 0 do
            local gameAccount = C_BattleNet.GetFriendGameAccountInfo(i, j)
            isInThisGame = isInThisGame or IsInThisGame(gameAccount)
            local name = GetMailableCharacter(gameAccount)
            if name then
                add(name, gameAccount.classFilename or GetClassFile(gameAccount.classID))
            end
        end
        local accountInfo = not isInThisGame and C_BattleNet.GetFriendAccountInfo(i)
        local titleFriendName = accountInfo and GetTitleFriendName(accountInfo)
        if titleFriendName then
            add(titleFriendName)
        end
    end
end

-- Each builder fills the list with { name = full name, class = class file or nil } entries.
-- Returning false means the data is not available yet and must not be cached.
local builders = {
    [Contacts.FRIENDS] = function(add)
        if HasBattleNetFriends() then
            AddBattleNetFriends(add)
        end
        if not HasCharacterFriendList() then
            return
        end
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

-- Class file of a contact of any kind, nil if unknown (friends have none).
function Contacts:FindClass(name)
    name = NormalizeName(name)
    if not name then
        return nil
    end
    for _, kind in ipairs({ Contacts.GUILD, Contacts.RECENT_ALLIES }) do
        local contact = GetCache(kind).byName[name]
        if contact and contact.class then
            return contact.class
        end
    end
    return nil
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

function Contacts:OnEnable()
    -- The characters of Battle.net friends change when they log in, out or switch characters (the
    -- same events as Blizzard's friends frame).
    if HasBattleNetFriends() then
        local function InvalidateFriends()
            Invalidate(Contacts.FRIENDS)
        end
        ns:RegisterEvent("BN_FRIEND_ACCOUNT_ONLINE", InvalidateFriends)
        ns:RegisterEvent("BN_FRIEND_ACCOUNT_OFFLINE", InvalidateFriends)
        ns:RegisterEvent("BN_FRIEND_INFO_CHANGED", InvalidateFriends)
        ns:RegisterEvent("BN_FRIEND_LIST_SIZE_CHANGED", InvalidateFriends)
        ns:RegisterEvent("BN_CONNECTED", InvalidateFriends)
        ns:RegisterEvent("BN_DISCONNECTED", InvalidateFriends)
    end
end
