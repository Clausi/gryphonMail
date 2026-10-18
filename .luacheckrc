-- luacheck configuration for GryphonMail (WoW Forever, Lua 5.1)
std = "lua51"
max_line_length = 120
exclude_files = { ".tools/" }

-- Methods defined with ":" do not have to use the implicit self.
self = false

-- Globals the addon defines.
globals = {
    "GryphonMailDB",
    "GryphonMailCharDB",
    "SLASH_GRYPHONMAIL1",
    "SlashCmdList",
}

-- WoW API and Blizzard UI globals the addon reads. Add new ones here when used.
read_globals = {
    -- WoW Lua extensions
    "format",
    "floor",
    "strtrim",
    "issecretvalue",
    "hooksecurefunc",
    "wipe",
    "date",
    "time",

    -- API
    "C_AddOns",
    "Constants",
    "C_ClassColor",
    "CreateColor",
    "C_CreatureInfo",
    "C_FriendList",
    "C_GuildInfo",
    "C_Item",
    "C_RecentAllies",
    "C_Timer",
    "GetMoney",
    "GetTime",
    "GetAddOnMemoryUsage",
    "UpdateAddOnMemoryUsage",
    "CreateFrame",
    "GetGuildRosterInfo",
    "GetLocale",
    "GetRealmName",
    "GetInboxHeaderInfo",
    "GetInboxInvoiceInfo",
    "GetInboxItem",
    "GetInboxItemLink",
    "GetInboxNumItems",
    "GetSendMailCOD",
    "GetSendMailItem",
    "GetSendMailItemLink",
    "GetSendMailMoney",
    "HasSendMailItem",
    "GetMoneyString",
    "HasInboxItem",
    "PlaySound",
    "SetSendMailShowing",
    -- UI helpers
    "ButtonFrameTemplate_HideButtonBar",
    "DropdownButtonMixin",
    "GameTooltip_AddMoneyLine",
    "GameTooltip_Hide",
    "PanelTemplates_DeselectTab",
    "PanelTemplates_SelectTab",
    "GetNumGuildMembers",
    "IsInGuild",
    "IsShiftKeyDown",
    "UnitClass",
    "UnitFactionGroup",
    "UnitName",
    "InboxItemCanDelete",
    "SecondsToTime",
    "SetItemButtonCount",
    "SetItemButtonQuality",

    -- Frames
    "DEFAULT_CHAT_FRAME",
    -- pageNum is written on purpose to reset or clamp paging when a filter changes (see InboxView.lua).
    InboxFrame = { other_fields = true, fields = { pageNum = { read_only = false } } },
    "GameTooltip",
    "MailFrame",
    "MailFrameInset",
    "MailFrameTab1",
    "MailFrameTab2",
    "OpenMailFrame",
    "SendMailFrame",
    "SendMailNameEditBox",
    "SendMailSubjectEditBox",
    -- ShouldSkipCurrentMail / ShouldSkipCurrentAttachment are replaced on purpose to restrict
    -- "Open All" to filtered mails and to avoid duplicate take requests (see InboxView.lua).
    OpenAllMail = {
        other_fields = true,
        fields = {
            ShouldSkipCurrentMail = { read_only = false },
            ShouldSkipCurrentAttachment = { read_only = false },
        },
    },

    -- Constants and global strings
    "INBOXITEMS_TO_DISPLAY",
    "ATTACHMENTS_MAX_RECEIVE",
    "ATTACHMENTS_MAX_SEND",
    "SOUNDKIT",
    "UNKNOWN",
    "OPEN_ALL_MAIL_BUTTON",
    "DAYS_ABBR",
    "TIME_UNTIL_DELETED",
    "TIME_UNTIL_RETURNED",
    "NORMAL_FONT_COLOR",
    "HIGHLIGHT_FONT_COLOR",
    "RED_FONT_COLOR",
    "GRAY_FONT_COLOR",
    "GREEN_FONT_COLOR_CODE",
    "RED_FONT_COLOR_CODE",
    "FONT_COLOR_CODE_CLOSE",
}
