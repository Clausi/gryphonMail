local addonName, ns = ...
local L = ns.L

ns:RegisterEvent("ADDON_LOADED", function(_, loadedName)
    if loadedName ~= addonName then
        return
    end

    GryphonMailDB = ns.ApplyDefaults(GryphonMailDB or {}, ns.defaults)
    ns.db = GryphonMailDB
    GryphonMailCharDB = ns.ApplyDefaults(GryphonMailCharDB or {}, ns.charDefaults)
    ns.charDb = GryphonMailCharDB

    for _, module in ipairs(ns.modules) do
        if module.OnInitialize then
            module:OnInitialize()
        end
    end
end)

ns:RegisterEvent("PLAYER_LOGIN", function()
    for _, module in ipairs(ns.modules) do
        if module.OnEnable then
            module:OnEnable()
        end
    end

    ns:Print(L["ADDON_LOADED"], ns.version or "?")
end)

-- Slash commands
ns:RegisterCommand("version", function()
    ns:Print(ns.version or "?")
end, { L["HELP_VERSION"] })

ns:RegisterCommand("debug", function()
    ns.db.debug = not ns.db.debug
    ns:Print(ns.db.debug and L["DEBUG_ON"] or L["DEBUG_OFF"])
end, { L["HELP_DEBUG"] })

local function PrintHelp()
    ns:Print(L["HELP_HEADER"])
    for _, command in ipairs(ns.commands) do
        for _, line in ipairs(command.helpLines) do
            ns:Print(line)
        end
    end
end

SLASH_GRYPHONMAIL1 = "/gryphonmail"
SlashCmdList["GRYPHONMAIL"] = function(input)
    local name, args = strtrim(input or ""):match("^(%S*)%s*(.-)$")
    local command = ns.commands[name:lower()]

    if command then
        command.handler(args)
    else
        PrintHelp()
    end
end
