local _, ns = ...

if GetLocale() ~= "deDE" then
    return
end

local L = ns.L

L["ADDON_LOADED"] = "Version %s geladen. Tippe /gryphonmail für Hilfe."
L["DEBUG_ON"] = "Debug-Ausgabe aktiviert."
L["DEBUG_OFF"] = "Debug-Ausgabe deaktiviert."
L["HELP_DEBUG"] = "/gryphonmail debug - schaltet die Debug-Ausgabe um"
L["HELP_HEADER"] = "Befehle:"
L["HELP_VERSION"] = "/gryphonmail version - zeigt die Addon-Version"
