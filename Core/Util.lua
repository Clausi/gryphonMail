local _, ns = ...

local PREFIX = "|cff33ccffGryphonMail|r: "

-- Prints a message to the default chat frame with the addon prefix.
function ns:Print(message, ...)
    if select("#", ...) > 0 then
        message = message:format(...)
    end
    DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. tostring(message))
end

-- Prints a message the addon shows on its own (not as the answer to a command). The user can turn
-- these off with "/gryphonmail notify off".
function ns:Notify(message, ...)
    if self.charDb and self.charDb.notifications then
        self:Print(message, ...)
    end
end

-- Turns the automatic messages of the current character on or off. Also writes the old name
-- chatMessages, so an older version keeps the setting (TODO: remove in a later release).
function ns:SetNotifications(value)
    self.charDb.notifications = value
    self.charDb.chatMessages = value
end

-- Prints only when debug mode is enabled in the saved variables.
function ns:Debug(message, ...)
    if self.db and self.db.debug then
        self:Print("|cff999999[debug]|r " .. tostring(message), ...)
    end
end

-- Memory the addon keeps (in KB) after a full garbage collection. Slow (collects garbage and scans
-- every addon), so it is only used in debug mode.
local function GetRetainedMemory()
    collectgarbage("collect")
    UpdateAddOnMemoryUsage()
    return GetAddOnMemoryUsage(ns.name)
end

-- Calls fn(...). In debug mode, also prints how much memory it retained afterwards.
function ns:MeasureMemory(label, fn, ...)
    if not (self.db and self.db.debug) then
        fn(...)
        return
    end
    local before = GetRetainedMemory()
    fn(...)
    local after = GetRetainedMemory()
    self:Debug("Memory %s: %+.1f KB (total %.1f KB)", label, after - before, after)
end

-- In debug mode, prints the memory the addon currently retains.
function ns:DebugMemory(label)
    if self.db and self.db.debug then
        self:Debug("Memory %s: %.1f KB", label, GetRetainedMemory())
    end
end

-- Sets up the menu of a DropdownButton that shows no selection text (fixed text or only an arrow),
-- so it only needs the menu while it is open. A generated menu takes ~80 KB even with 12 entries:
-- - SetupMenu builds the menu right away on a shown dropdown, so it runs while hidden. The menu is
--   generated anyway on every open (DropdownButtonMixin:OpenMenu).
-- - After closing, the generated description is released. Blizzard's code handles a nil description
--   (it is nil until the first open as well). Only used on own frames, so the write causes no taint.
function ns.SetupMenuOnDemand(dropdown, generator)
    local wasShown = dropdown:IsShown()
    dropdown:Hide()
    dropdown:SetupMenu(generator)
    dropdown:SetShown(wasShown)
    dropdown:RegisterCallback(DropdownButtonMixin.Event.OnMenuClose, function()
        dropdown.menuDescription = nil
    end, dropdown)
end

-- At most this many entries per (sub)menu; longer lists (e.g. a big guild) are split into nested
-- submenus by name range. Blizzard's scroll mode (SetScrollMode) is not used: every time a scrolling
-- menu opens, Menu.lua registers an OnScroll callback on the pooled menu frame's ScrollBox and never
-- unregisters it, which keeps the whole menu alive (~400 KB per open with ~100 recent allies).
-- Short submenus also keep Blizzard's pool of menu element frames small, which are never freed.
local MAX_ENTRIES_PER_MENU = 20

local function AddMenuRange(description, entries, first, last, addEntry, getName)
    local count = last - first + 1
    if count <= MAX_ENTRIES_PER_MENU then
        for i = first, last do
            addEntry(description, entries[i])
        end
        return
    end

    local groupSize = MAX_ENTRIES_PER_MENU
    while math.ceil(count / groupSize) > MAX_ENTRIES_PER_MENU do
        groupSize = groupSize * MAX_ENTRIES_PER_MENU
    end
    for groupFirst = first, last, groupSize do
        local groupLast = math.min(groupFirst + groupSize - 1, last)
        local label = ns.L["NAME_RANGE"]:format(getName(entries[groupFirst]), getName(entries[groupLast]))
        AddMenuRange(description:CreateButton(label), entries, groupFirst, groupLast, addEntry, getName)
    end
end

-- Adds the entries (sorted by name) to a menu description with addEntry(description, entry). More
-- than MAX_ENTRIES_PER_MENU become at most that many submenus named by the getName(entry) of their
-- first and last entry ("Abby - Fiona"), nested further if needed.
function ns.AddMenuEntries(description, entries, addEntry, getName)
    AddMenuRange(description, entries, 1, #entries, addEntry, getName)
end

-- Recursively copies missing default values into the target table.
function ns.ApplyDefaults(target, defaults)
    for key, value in pairs(defaults) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then
                target[key] = {}
            end
            ns.ApplyDefaults(target[key], value)
        elseif target[key] == nil then
            target[key] = value
        end
    end
    return target
end
