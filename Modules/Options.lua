local _, ns = ...
local L = ns.L
local Options = ns:RegisterModule("Options")

-- Options page in Blizzard's settings (Esc > Options > AddOns > GryphonMail), built with own
-- controls (Core/OptionsPanel.lua explains why). The settings stay in ns.db and ns.charDb; the
-- controls read and write them through the getters and setters of the modules, so a change takes
-- effect right away.

local category, panel

-- Shows the whole log days value; the slider moves in whole steps, but its values may carry
-- rounding errors.
local function FormatDays(value)
    return tostring(floor(value + 0.5))
end

local function AddSettings()
    panel:AddCheckbox(L["OPTIONS_NOTIFICATIONS"], L["OPTIONS_NOTIFICATIONS_TOOLTIP"],
        function()
            return ns.charDb.notifications
        end,
        function(value)
            ns:SetNotifications(value)
        end)

    local MailLog = ns.modules.MailLog
    panel:AddSlider(L["OPTIONS_LOG_DAYS"], L["OPTIONS_LOG_DAYS_TOOLTIP"],
        MailLog.MIN_RETENTION_DAYS, MailLog.MAX_RETENTION_DAYS, 1, FormatDays,
        function()
            return MailLog:GetRetentionDays()
        end,
        function(value)
            MailLog:SetRetentionDays(floor(value + 0.5))
        end)

    local settings = {
        { key = "attachItemCounts", label = "OPTIONS_ATTACH_ITEM_COUNTS" },
        { key = "attachKeepMenuOpen", label = "OPTIONS_ATTACH_KEEP_OPEN" },
        { key = "attachSetSubject", label = "OPTIONS_ATTACH_SET_SUBJECT" },
    }
    for _, entry in ipairs(settings) do
        local key = entry.key
        panel:AddCheckbox(L[entry.label], L[entry.label .. "_TOOLTIP"],
            function()
                return ns.db[key]
            end,
            function(value)
                ns.db[key] = value
            end)
    end
end

-- Favorites, like "/gryphonmail fav": a dropdown picks one, the buttons remove it or add a character
-- by name (own dialog with suggestions). The selection is not saved; "" is no selection.
local function AddFavorites()
    local Favorites = ns.modules.Favorites
    panel:AddHeader(L["OPTIONS_FAVORITES_HEADER"])

    local selected = ""
    -- Called on every refresh, so it lists the favorites stored at that moment.
    local function GetChoices()
        local choices = { { value = "", text = L["OPTIONS_FAVORITE_NONE"] } }
        for _, favorite in ipairs(Favorites:GetList()) do
            local color = favorite.class and C_ClassColor.GetClassColor(favorite.class)
            choices[#choices + 1] = {
                value = favorite.name,
                text = color and color:WrapTextInColorCode(favorite.displayName) or favorite.displayName,
            }
        end
        return choices
    end
    panel:AddDropdown(L["OPTIONS_FAVORITE"], L["OPTIONS_FAVORITE_TOOLTIP"], GetChoices,
        function()
            return selected
        end,
        function(value)
            selected = value
        end)
    -- A favorite added with the dialog (or changed by command) shows while the page is open.
    Favorites:OnUpdate(function()
        if panel.canvas:IsShown() then
            panel:Refresh()
        end
    end)

    panel:AddButton(L["OPTIONS_FAVORITE_REMOVE"], L["OPTIONS_FAVORITE_REMOVE_BUTTON"],
        L["OPTIONS_FAVORITE_REMOVE_TOOLTIP"], function()
            if selected == "" then
                return
            end
            Favorites:Remove(selected)
            selected = ""
            panel:Refresh()
        end)

    panel:AddButton(L["OPTIONS_FAVORITE_ADD"], L["OPTIONS_FAVORITE_ADD_BUTTON"],
        L["OPTIONS_FAVORITE_ADD_TOOLTIP"], function()
            ns.modules.FavoriteDialog:Show()
        end)
end

-- Known characters, like "/gryphonmail chars remove": a dropdown picks one, the button removes it.
-- The selection is not saved; "" is no selection.
local function AddCharacterRemoval()
    local Characters = ns.modules.Characters
    panel:AddHeader(L["OPTIONS_CHARACTERS_HEADER"])

    local selected = ""
    -- Called on every refresh, so it lists the characters stored at that moment.
    local function GetChoices()
        local choices = { { value = "", text = L["OPTIONS_CHARACTER_NONE"] } }
        for _, character in ipairs(Characters:GetCharacters()) do
            if not character.isCurrent then
                choices[#choices + 1] = { value = character.fullName, text = Characters:FormatCharacter(character) }
            end
        end
        return choices
    end
    panel:AddDropdown(L["OPTIONS_CHARACTER"], L["OPTIONS_CHARACTER_TOOLTIP"], GetChoices,
        function()
            return selected
        end,
        function(value)
            selected = value
        end)

    panel:AddButton(L["OPTIONS_CHARACTER_REMOVE"], L["OPTIONS_CHARACTER_REMOVE_BUTTON"],
        L["OPTIONS_CHARACTER_REMOVE_TOOLTIP"], function()
            if selected == "" then
                return
            end
            Characters:Remove(selected)
            selected = ""
            panel:Refresh()
        end)
end

function Options:OnInitialize()
    panel = ns.OptionsPanel.Create(ns.name)
    AddSettings()
    AddFavorites()
    AddCharacterRemoval()
    category = panel:Register()
end

-- "/gryphonmail options" opens the options page. Opening it from addon code is blocked in combat
-- (ADDON_ACTION_BLOCKED for OpenSettingsPanel); Esc > Options still works there.
ns:RegisterCommand("options", function()
    if InCombatLockdown() then
        ns:Print(L["OPTIONS_IN_COMBAT"])
        return
    end
    Settings.OpenToCategory(category:GetID())
end, { L["HELP_OPTIONS"] })
