local _, ns = ...

-- Base locale. Every key used in the addon must be defined here.
-- Other locales only override the keys they translate; missing keys fall back to enUS.
local L = setmetatable({}, {
    __index = function(_, key)
        return key
    end,
})
ns.L = L

L["ADDON_LOADED"] = "Version %s loaded. Type /gryphonmail for help."
L["SEARCH_PLACEHOLDER"] = "Sender or subject"
L["OPEN_FILTERED"] = "Open Filtered"
L["FILTER_ALL"] = "All Mail"
L["FILTER_FRIENDS"] = "Friends"
L["FILTER_GUILD"] = "Guild"
L["FILTER_ALTS"] = "My Characters"
L["FILTER_AUCTION"] = "Auction House"
L["FILTER_COD"] = "C.O.D."
L["FILTER_MONEY"] = "Gold"
L["DEBUG_ON"] = "Debug output enabled."
L["DEBUG_OFF"] = "Debug output disabled."
L["HELP_DEBUG"] = "/gryphonmail debug - toggle debug output"
L["HELP_HEADER"] = "Commands:"
L["HELP_VERSION"] = "/gryphonmail version - show the addon version"
L["HELP_CHARS"] = "/gryphonmail chars - list your known characters"
L["HELP_CHARS_REMOVE"] = "/gryphonmail chars remove <number||name> - forget a character"
L["CHARS_HEADER"] = "Known characters:"
L["CHARS_EMPTY"] = "No characters known yet."
L["CHARS_CURRENT"] = "(current)"
L["CHARS_REMOVED"] = "Removed %s."
L["CHARS_NOT_FOUND"] = "Character not found: %s"
L["CHARS_REMOVE_CURRENT"] = "The current character cannot be removed."
