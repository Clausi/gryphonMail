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
L["LOG_TAB"] = "Log"
L["LOG_TITLE"] = "Mail Log"
L["LOG_HEADER"] = "Collected mail of the last %d days"
L["LOG_EMPTY"] = "No collected mail yet."
L["LOG_PAGE"] = "Page %d / %d"
L["LOG_DATE_FORMAT"] = "%m/%d %H:%M"
L["ITEM_COUNT_ONE"] = "1 item"
L["ITEM_COUNT"] = "%d items"
L["SUMMARY_COLLECTED"] = "Collected %s."
L["SUMMARY_AND"] = " and "
L["LOG_INFO"] = "The log keeps %d days and has %d entries for this character."
L["LOG_DAYS_SET"] = "The log now keeps %d days."
L["LOG_DAYS_INVALID"] = "Please enter a whole number of days between %d and %d."
L["LOG_CLEARED"] = "Log of this character cleared."
L["DEBUG_ON"] = "Debug output enabled."
L["DEBUG_OFF"] = "Debug output disabled."
L["HELP_DEBUG"] = "/gryphonmail debug - toggle debug output"
L["HELP_HEADER"] = "Commands:"
L["HELP_VERSION"] = "/gryphonmail version - show the addon version"
L["HELP_CHARS"] = "/gryphonmail chars - list your known characters"
L["HELP_CHARS_REMOVE"] = "/gryphonmail chars remove <number||name> - forget a character"
L["HELP_LOG"] = "/gryphonmail log - show log settings"
L["HELP_LOG_DAYS"] = "/gryphonmail log days <1-365> - keep log entries for that many days"
L["HELP_LOG_CLEAR"] = "/gryphonmail log clear - clear the log of this character"
L["CHARS_HEADER"] = "Known characters:"
L["CHARS_EMPTY"] = "No characters known yet."
L["CHARS_CURRENT"] = "(current)"
L["CHARS_REMOVED"] = "Removed %s."
L["CHARS_NOT_FOUND"] = "Character not found: %s"
L["CHARS_REMOVE_CURRENT"] = "The current character cannot be removed."
