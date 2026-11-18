local _, ns = ...
local L = ns.L
local Options = ns:RegisterModule("Options")

-- Options page in Blizzard's settings (Esc > Options > AddOns > GryphonMail) as a vertical list.
-- The settings stay in ns.db and ns.charDb; proxy settings read and write them there.

local category

-- Proxy setting variables must be unique among all settings of the game and addons.
local function RegisterProxySetting(variable, varType, name, defaultValue, getValue, setValue)
    return Settings.RegisterProxySetting(category, "GRYPHONMAIL_" .. variable, varType, name, defaultValue,
        getValue, setValue)
end

-- Known characters, like "/gryphonmail chars remove": a dropdown picks one, the button removes it.
-- The selection is not saved; "" is no selection.
local function RegisterCharacterRemoval()
    local Characters = ns.modules.Characters
    local layout = SettingsPanel:GetLayout(category)
    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(L["OPTIONS_CHARACTERS_HEADER"]))

    local selected = ""
    local selection = RegisterProxySetting("REMOVE_CHARACTER", Settings.VarType.String, L["OPTIONS_CHARACTER"], "",
        function()
            return selected
        end,
        function(value)
            selected = value
        end)

    -- Called each time the dropdown opens, so it lists the characters stored at that moment.
    local function GetOptions()
        local container = Settings.CreateControlTextContainer()
        container:Add("", L["OPTIONS_CHARACTER_NONE"])
        for _, character in ipairs(Characters:GetCharacters()) do
            if not character.isCurrent then
                container:Add(character.fullName, Characters:FormatCharacter(character))
            end
        end
        return container:GetData()
    end
    Settings.CreateDropdown(category, selection, GetOptions, L["OPTIONS_CHARACTER_TOOLTIP"])

    -- No search tags (addSearchTags = false): tags added from addon code taint the initializer, the
    -- settings search reads them for every initializer and carries the taint on to the search results.
    -- On Forever, showing a Discord row there then calls the protected C_Discord.IsUserOAuthed.
    layout:AddInitializer(CreateSettingsButtonInitializer(L["OPTIONS_CHARACTER_REMOVE"],
        L["OPTIONS_CHARACTER_REMOVE_BUTTON"], function()
        if selected == "" then
            return
        end
        Characters:Remove(selected)
        -- Also clears a selection that was removed by command in the meantime.
        selection:SetValue("")
    end, nil, false))
end

-- Favorites, like "/gryphonmail fav": a dropdown picks one, the buttons remove it or add a character
-- by name (popup with an edit box). The selection is not saved; "" is no selection.
local function RegisterFavorites()
    local Favorites = ns.modules.Favorites
    local layout = SettingsPanel:GetLayout(category)
    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(L["OPTIONS_FAVORITES_HEADER"]))

    local selected = ""
    local selection = RegisterProxySetting("REMOVE_FAVORITE", Settings.VarType.String, L["OPTIONS_FAVORITE"], "",
        function()
            return selected
        end,
        function(value)
            selected = value
        end)

    -- Called each time the dropdown opens, so it lists the favorites stored at that moment.
    local function GetOptions()
        local container = Settings.CreateControlTextContainer()
        container:Add("", L["OPTIONS_FAVORITE_NONE"])
        for _, favorite in ipairs(Favorites:GetList()) do
            local color = favorite.class and C_ClassColor.GetClassColor(favorite.class)
            container:Add(favorite.name, color and color:WrapTextInColorCode(favorite.displayName)
                or favorite.displayName)
        end
        return container:GetData()
    end
    Settings.CreateDropdown(category, selection, GetOptions, L["OPTIONS_FAVORITE_TOOLTIP"])

    -- No search tags, see RegisterCharacterRemoval.
    layout:AddInitializer(CreateSettingsButtonInitializer(L["OPTIONS_FAVORITE_REMOVE"],
        L["OPTIONS_FAVORITE_REMOVE_BUTTON"], function()
        if selected == "" then
            return
        end
        Favorites:Remove(selected)
        selection:SetValue("")
    end, nil, false))

    StaticPopupDialogs["GRYPHONMAIL_ADD_FAVORITE"] = {
        text = L["OPTIONS_FAVORITE_ADD_PROMPT"],
        button1 = L["OPTIONS_FAVORITE_ADD_BUTTON"],
        button2 = CANCEL,
        hasEditBox = 1,
        maxLetters = 64,
        timeout = 0,
        whileDead = 1,
        hideOnEscape = 1,
        OnAccept = function(dialog)
            Favorites:Add(ns.Compat.GetPopupEditBox(dialog):GetText())
        end,
        EditBoxOnEnterPressed = function(editBox)
            local dialog = editBox:GetParent()
            Favorites:Add(editBox:GetText())
            dialog:Hide()
        end,
        EditBoxOnEscapePressed = function(editBox)
            editBox:GetParent():Hide()
        end,
    }
    layout:AddInitializer(CreateSettingsButtonInitializer(L["OPTIONS_FAVORITE_ADD"],
        L["OPTIONS_FAVORITE_ADD_BUTTON"], function()
        StaticPopup_Show("GRYPHONMAIL_ADD_FAVORITE")
    end, nil, false))
end

local function RegisterSettings()
    local notifications = RegisterProxySetting("NOTIFICATIONS", Settings.VarType.Boolean,
        L["OPTIONS_NOTIFICATIONS"], ns.charDefaults.notifications,
        function()
            return ns.charDb.notifications
        end,
        function(value)
            ns:SetNotifications(value)
        end)
    Settings.CreateCheckbox(category, notifications, L["OPTIONS_NOTIFICATIONS_TOOLTIP"])

    local MailLog = ns.modules.MailLog
    local logDays = RegisterProxySetting("LOG_DAYS", Settings.VarType.Number, L["OPTIONS_LOG_DAYS"],
        ns.charDefaults.logRetentionDays,
        function()
            return MailLog:GetRetentionDays()
        end,
        function(value)
            -- The slider moves in whole steps, but its values may carry rounding errors.
            MailLog:SetRetentionDays(floor(value + 0.5))
        end)
    local sliderOptions = Settings.CreateSliderOptions(MailLog.MIN_RETENTION_DAYS, MailLog.MAX_RETENTION_DAYS, 1)
    sliderOptions:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
    Settings.CreateSlider(category, logDays, sliderOptions, L["OPTIONS_LOG_DAYS_TOOLTIP"])

    local attachItemCounts = RegisterProxySetting("ATTACH_ITEM_COUNTS", Settings.VarType.Boolean,
        L["OPTIONS_ATTACH_ITEM_COUNTS"], ns.defaults.attachItemCounts,
        function()
            return ns.db.attachItemCounts
        end,
        function(value)
            ns.db.attachItemCounts = value
        end)
    Settings.CreateCheckbox(category, attachItemCounts, L["OPTIONS_ATTACH_ITEM_COUNTS_TOOLTIP"])

    local attachKeepMenuOpen = RegisterProxySetting("ATTACH_KEEP_MENU_OPEN", Settings.VarType.Boolean,
        L["OPTIONS_ATTACH_KEEP_OPEN"], ns.defaults.attachKeepMenuOpen,
        function()
            return ns.db.attachKeepMenuOpen
        end,
        function(value)
            ns.db.attachKeepMenuOpen = value
        end)
    Settings.CreateCheckbox(category, attachKeepMenuOpen, L["OPTIONS_ATTACH_KEEP_OPEN_TOOLTIP"])

    local attachSetSubject = RegisterProxySetting("ATTACH_SET_SUBJECT", Settings.VarType.Boolean,
        L["OPTIONS_ATTACH_SET_SUBJECT"], ns.defaults.attachSetSubject,
        function()
            return ns.db.attachSetSubject
        end,
        function(value)
            ns.db.attachSetSubject = value
        end)
    Settings.CreateCheckbox(category, attachSetSubject, L["OPTIONS_ATTACH_SET_SUBJECT_TOOLTIP"])

    RegisterFavorites()
    RegisterCharacterRemoval()
end

function Options:OnInitialize()
    category = Settings.RegisterVerticalLayoutCategory(ns.name)
    RegisterSettings()
    Settings.RegisterAddOnCategory(category)
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
