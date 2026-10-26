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
        ns.defaults.logRetentionDays,
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
