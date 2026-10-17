local _, ns = ...

if GetLocale() ~= "deDE" then
    return
end

local L = ns.L

L["ADDON_LOADED"] = "Version %s geladen. Tippe /gryphonmail für Hilfe."
L["SEARCH_PLACEHOLDER"] = "Absender oder Betreff"
L["OPEN_FILTERED"] = "Gefiltert öffnen"
L["DEBUG_ON"] = "Debug-Ausgabe aktiviert."
L["DEBUG_OFF"] = "Debug-Ausgabe deaktiviert."
L["HELP_DEBUG"] = "/gryphonmail debug - schaltet die Debug-Ausgabe um"
L["HELP_HEADER"] = "Befehle:"
L["HELP_VERSION"] = "/gryphonmail version - zeigt die Addon-Version"
L["HELP_CHARS"] = "/gryphonmail chars - listet deine bekannten Charaktere"
L["HELP_CHARS_REMOVE"] = "/gryphonmail chars remove <Nummer||Name> - vergisst einen Charakter"
L["CHARS_HEADER"] = "Bekannte Charaktere:"
L["CHARS_EMPTY"] = "Noch keine Charaktere bekannt."
L["CHARS_CURRENT"] = "(aktuell)"
L["CHARS_REMOVED"] = "%s entfernt."
L["CHARS_NOT_FOUND"] = "Charakter nicht gefunden: %s"
L["CHARS_REMOVE_CURRENT"] = "Der aktuelle Charakter kann nicht entfernt werden."
