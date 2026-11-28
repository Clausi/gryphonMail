local _, ns = ...

-- Options page in Blizzard's settings (Esc > Options > AddOns) built from own controls on a canvas
-- category, instead of Blizzard's vertical settings list.
--
-- Blizzard's settings list reuses its control frames for every page. A control that showed a
-- setting registered by addon code keeps tainted callback handles, and the Blizzard setting it
-- shows next runs tainted. A changed action bar toggle then taints the Edit Mode layout, and Edit
-- Mode fails on secret values (TargetUnit blocked, party frames compare secret health colors).
-- The controls here are own frames and are never shown for Blizzard's settings. The canvas has no
-- OnShow script: Blizzard shows it from its own code and calls OnRefresh through
-- securecallfunction.
--
--   local panel = ns.OptionsPanel.Create(title)
--   panel:AddHeader(text)
--   panel:AddCheckbox(label, tooltip, getValue, setValue)
--   panel:AddSlider(label, tooltip, minValue, maxValue, step, formatValue, getValue, setValue)
--   panel:AddChoice(label, tooltip, choices, getValue, setValue)  -- row of radio buttons
--   panel:AddDropdown(label, tooltip, choices, getValue, setValue)  -- own dropdown, long lists
--   panel:AddButton(label, buttonText, tooltip, onClick)
--
-- There are no Blizzard dropdowns: their menus are shared frames of the menu system, which
-- Blizzard's own menus use as well. AddChoice shows the choices as a row of own radio buttons;
-- AddDropdown is an own dropdown (own button and list, only Blizzard's textures) for longer lists.
--   local category = panel:Register()  -- after all rows; Settings.OpenToCategory(category:GetID())
local OptionsPanel = {}
ns.OptionsPanel = OptionsPanel

local ROW_HEIGHT = 30
local HEADER_HEIGHT = 34
local SIDE_PADDING = 16
local LABEL_WIDTH = 220
local SCROLL_BAR_SPACE = 24
-- AddChoice: space between the radio buttons, gap between button and text, and the width the
-- buttons wrap at before the page has its size.
local CHOICE_SPACING = 16
local CHOICE_TEXT_GAP = 5
local CHOICE_MIN_WIDTH = 300
-- AddDropdown: width of button and list, height of a list entry, entries shown before the list
-- scrolls, and the list's inner padding (the background texture has a shadow at the bottom).
local DROPDOWN_WIDTH = 220
local DROPDOWN_HEIGHT = 25
local DROPDOWN_ENTRY_HEIGHT = 20
local DROPDOWN_MAX_ENTRIES = 12
local DROPDOWN_PADDING_X = 10
local DROPDOWN_PADDING_TOP = 8
local DROPDOWN_PADDING_BOTTOM = 14

local Panel = {}
Panel.__index = Panel

local function ShowTooltip(owner, title, text)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText(title, HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
    GameTooltip:AddLine(text, nil, nil, nil, true)
    GameTooltip:Show()
end

local function HideTooltip()
    GameTooltip:Hide()
end

local function SetTooltip(frame, title, text)
    frame:SetScript("OnEnter", function(self)
        ShowTooltip(self, title, text)
    end)
    frame:SetScript("OnLeave", HideTooltip)
end

-- The canvas is sized by Blizzard's settings panel; the rows scroll if they do not fit.
function OptionsPanel.Create(title)
    local panel = setmetatable({ controls = {}, height = 0, refreshing = false }, Panel)

    local canvas = CreateFrame("Frame")
    canvas:Hide()
    panel.canvas = canvas

    local titleText = canvas:CreateFontString(nil, "ARTWORK", "GameFontHighlightHuge")
    titleText:SetPoint("TOPLEFT", 7, -22)
    titleText:SetText(title)
    panel.title = title

    local scrollFrame = CreateFrame("ScrollFrame", nil, canvas, "ScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 0, -56)
    scrollFrame:SetPoint("BOTTOMRIGHT", -SCROLL_BAR_SPACE, 8)
    scrollFrame.ScrollBar:SetHideIfUnscrollable(true)
    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(1, 1)
    scrollFrame:SetScrollChild(content)
    scrollFrame:SetScript("OnSizeChanged", function(_, width)
        content:SetWidth(width)
    end)
    panel.content = content

    canvas.OnRefresh = function()
        panel:Refresh()
    end
    return panel
end

-- Shows the current values, e.g. after a change by slash command. Blizzard calls it each time the
-- page is shown.
function Panel:Refresh()
    self.refreshing = true
    for _, refresh in ipairs(self.controls) do
        refresh()
    end
    self.refreshing = false
end

-- Registers the page under Esc > Options > AddOns and returns its category.
function Panel:Register()
    self:Refresh()
    local category = Settings.RegisterCanvasLayoutCategory(self.canvas, self.title)
    Settings.RegisterAddOnCategory(category)
    return category
end

-- Returns the y offset of a new row of the given height.
function Panel:AddRow(height)
    local y = -self.height
    self.height = self.height + height
    self.content:SetHeight(self.height)
    return y
end

function Panel:AddHeader(text)
    local y = self:AddRow(HEADER_HEIGHT)
    local header = self.content:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
    header:SetPoint("BOTTOMLEFT", self.content, "TOPLEFT", 0, y - HEADER_HEIGHT + 6)
    header:SetText(text)
end

-- Label on the left and the control in the second column, like Blizzard's settings list. Returns
-- the point for the control.
function Panel:AddLabeledRow(label)
    local y = self:AddRow(ROW_HEIGHT)
    local text = self.content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    text:SetPoint("LEFT", self.content, "TOPLEFT", SIDE_PADDING, y - ROW_HEIGHT / 2)
    text:SetWidth(LABEL_WIDTH)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(false)
    text:SetText(label)
    return "LEFT", self.content, "TOPLEFT", SIDE_PADDING + LABEL_WIDTH, y - ROW_HEIGHT / 2
end

function Panel:AddCheckbox(label, tooltip, getValue, setValue)
    local checkbox = CreateFrame("CheckButton", nil, self.content, "UICheckButtonTemplate")
    checkbox:SetSize(26, 26)
    checkbox:SetPoint(self:AddLabeledRow(label))
    checkbox:SetScript("OnClick", function(button)
        setValue(button:GetChecked())
    end)
    SetTooltip(checkbox, label, tooltip)
    self.controls[#self.controls + 1] = function()
        checkbox:SetChecked(getValue() and true or false)
    end
end

-- formatValue(value) returns the text right of the slider.
function Panel:AddSlider(label, tooltip, minValue, maxValue, step, formatValue, getValue, setValue)
    local slider = CreateFrame("Frame", nil, self.content, "MinimalSliderWithSteppersTemplate")
    slider:SetPoint(self:AddLabeledRow(label))
    local formatters = { [MinimalSliderWithSteppersMixin.Label.Right] = formatValue }
    slider:Init(getValue(), minValue, maxValue, (maxValue - minValue) / step, formatters)
    slider:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, value)
        if not self.refreshing then
            setValue(value)
        end
    end, slider)
    slider.Slider:HookScript("OnEnter", function(frame)
        ShowTooltip(frame, label, tooltip)
    end)
    slider.Slider:HookScript("OnLeave", HideTooltip)
    self.controls[#self.controls + 1] = function()
        slider:SetValue(getValue())
    end
end

-- Moves the rows below a row whose height changed. rowFrame is anchored with its TOPLEFT at the top
-- of the row. Everything below it is anchored to the content (see AddLabeledRow and AddHeader).
function Panel:ResizeRow(rowFrame, oldHeight, newHeight)
    local _, _, _, _, top = rowFrame:GetPoint(1)
    local bottom = top - oldHeight
    local delta = oldHeight - newHeight
    local function Move(object)
        local point, relativeTo, relativePoint, x, y = object:GetPoint(1)
        if relativeTo == self.content and y <= bottom then
            object:SetPoint(point, relativeTo, relativePoint, x, y + delta)
        end
    end
    for _, child in ipairs({ self.content:GetChildren() }) do
        Move(child)
    end
    for _, region in ipairs({ self.content:GetRegions() }) do
        Move(region)
    end
    self.height = self.height - delta
    self.content:SetHeight(self.height)
end

-- choices: ordered list of { value = ..., text = ... }, or a function returning such a list, which
-- is called again on every refresh (for lists that change, e.g. known characters). The radio
-- buttons follow the label and wrap to more lines if they do not fit; the row grows with them.
-- The button of getValue() is checked; none if the value is not in the list.
function Panel:AddChoice(label, tooltip, choices, getValue, setValue)
    local _, _, _, x, y = self:AddLabeledRow(label)
    local holder = CreateFrame("Frame", nil, self.content)
    holder:SetPoint("TOPLEFT", self.content, "TOPLEFT", x, y + ROW_HEIGHT / 2)
    holder:SetSize(1, 1)

    local buttons = {}
    local shown = {}
    local rowHeight = ROW_HEIGHT

    local function UpdateChecked()
        local value = getValue()
        for i, choice in ipairs(shown) do
            buttons[i]:SetChecked(choice.value == value)
        end
    end

    local function GetButton(index)
        local button = buttons[index]
        if not button then
            button = CreateFrame("CheckButton", nil, holder, "UIRadioButtonTemplate")
            button.text:SetFontObject("GameFontHighlight")
            button:SetScript("OnClick", function()
                setValue(shown[index].value)
                -- A click on the checked button unchecks it; check it again.
                UpdateChecked()
            end)
            SetTooltip(button, label, tooltip)
            buttons[index] = button
        end
        return button
    end

    local function Layout()
        local width = self.content:GetWidth() - SIDE_PADDING - LABEL_WIDTH - SIDE_PADDING
        width = math.max(width, CHOICE_MIN_WIDTH)
        local line, lineX = 0, 0
        for i = 1, #shown do
            local button = buttons[i]
            local textWidth = button.text:GetStringWidth()
            local buttonWidth = button:GetWidth() + CHOICE_TEXT_GAP + textWidth
            if lineX > 0 and lineX + buttonWidth > width then
                line = line + 1
                lineX = 0
            end
            -- The text is part of the button, so it can be clicked as well.
            button:SetHitRectInsets(0, -(CHOICE_TEXT_GAP + textWidth), 0, 0)
            button:ClearAllPoints()
            button:SetPoint("LEFT", holder, "TOPLEFT", lineX, -(line + 0.5) * ROW_HEIGHT)
            lineX = lineX + buttonWidth + CHOICE_SPACING
        end
        local height = (line + 1) * ROW_HEIGHT
        if height ~= rowHeight then
            self:ResizeRow(holder, rowHeight, height)
            rowHeight = height
        end
    end
    self.content:HookScript("OnSizeChanged", Layout)

    self.controls[#self.controls + 1] = function()
        shown = type(choices) == "function" and choices() or choices
        for i, choice in ipairs(shown) do
            local button = GetButton(i)
            button.text:SetText(choice.text)
            button:Show()
        end
        for i = #shown + 1, #buttons do
            buttons[i]:Hide()
        end
        Layout()
        UpdateChecked()
    end
end

-- choices: as for AddChoice; a function is called again on every refresh and when the list opens.
-- The button shows the text of getValue() (empty if the value is not in the list). The list is an
-- own frame on UIParent below the button with a check mark on the current value; it scrolls with
-- more than DROPDOWN_MAX_ENTRIES entries. It closes on a click on an entry, on a click elsewhere
-- and when the page hides. Not in UISpecialFrames (read by Blizzard's panel manager); Esc closes
-- the options window and the page with it.
function Panel:AddDropdown(label, tooltip, choices, getValue, setValue)
    local button = CreateFrame("Button", nil, self.content)
    button:SetSize(DROPDOWN_WIDTH, DROPDOWN_HEIGHT)
    button:SetPoint(self:AddLabeledRow(label))

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetAtlas("common-dropdown-textholder")
    background:SetPoint("TOPLEFT", -8, 7)
    background:SetPoint("BOTTOMRIGHT", 8, -9)
    local arrow = button:CreateTexture(nil, "ARTWORK")
    arrow:SetPoint("RIGHT", 1, -3)
    local text = button:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    text:SetPoint("LEFT", 8, 0)
    text:SetPoint("RIGHT", arrow, "LEFT")
    text:SetJustifyH("LEFT")
    text:SetWordWrap(false)

    local pullout, scrollFrame, list
    local entries = {}
    local shown = {}
    local hovered = false

    local function UpdateArrow()
        local atlas = "common-dropdown-a-button"
        if pullout and pullout:IsShown() then
            atlas = "common-dropdown-a-button-open"
        elseif hovered then
            atlas = "common-dropdown-a-button-hover"
        end
        arrow:SetAtlas(atlas, true)
    end

    local function UpdateText()
        local value = getValue()
        for _, choice in ipairs(shown) do
            if choice.value == value then
                text:SetText(choice.text)
                return
            end
        end
        text:SetText("")
    end

    local function ReadChoices()
        shown = type(choices) == "function" and choices() or choices
    end

    local function Close()
        if pullout then
            pullout:Hide()
        end
    end

    local function CreatePullout()
        pullout = CreateFrame("Frame", nil, UIParent)
        pullout:SetFrameStrata("FULLSCREEN_DIALOG")
        pullout:SetClampedToScreen(true)
        -- Clicks on the list do not reach the frames below it.
        pullout:EnableMouse(true)
        pullout:Hide()
        local listBackground = pullout:CreateTexture(nil, "BACKGROUND")
        listBackground:SetAtlas("common-dropdown-bg")
        listBackground:SetAllPoints()
        listBackground:SetAlpha(0.925)

        scrollFrame = CreateFrame("ScrollFrame", nil, pullout, "ScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT", DROPDOWN_PADDING_X, -DROPDOWN_PADDING_TOP)
        scrollFrame.ScrollBar:SetHideIfUnscrollable(true)
        list = CreateFrame("Frame", nil, scrollFrame)
        list:SetSize(1, 1)
        scrollFrame:SetScrollChild(list)

        -- A click elsewhere closes the list; a click on the button toggles it in OnClick.
        pullout:SetScript("OnEvent", function()
            if not pullout:IsMouseOver() and not button:IsMouseOver() then
                Close()
            end
        end)
        pullout:SetScript("OnShow", function(frame)
            frame:RegisterEvent("GLOBAL_MOUSE_DOWN")
            UpdateArrow()
        end)
        pullout:SetScript("OnHide", function(frame)
            frame:UnregisterEvent("GLOBAL_MOUSE_DOWN")
            UpdateArrow()
        end)
    end

    local function GetEntry(index)
        local entry = entries[index]
        if not entry then
            entry = CreateFrame("Button", nil, list)
            entry:SetHeight(DROPDOWN_ENTRY_HEIGHT)
            entry:SetPoint("TOPLEFT", 0, -(index - 1) * DROPDOWN_ENTRY_HEIGHT)
            entry:SetPoint("RIGHT", list)
            local highlight = entry:CreateTexture(nil, "HIGHLIGHT")
            highlight:SetAllPoints()
            highlight:SetColorTexture(1, 1, 1, 0.1)
            entry.check = entry:CreateTexture(nil, "ARTWORK")
            entry.check:SetAtlas("common-dropdown-icon-checkmark-yellow")
            entry.check:SetSize(16, 16)
            entry.check:SetPoint("LEFT", 2, 0)
            entry.text = entry:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
            entry.text:SetPoint("LEFT", 22, 0)
            entry.text:SetPoint("RIGHT", -2, 0)
            entry.text:SetJustifyH("LEFT")
            entry.text:SetWordWrap(false)
            entry:SetScript("OnClick", function()
                Close()
                setValue(shown[index].value)
                UpdateText()
            end)
            entries[index] = entry
        end
        return entry
    end

    local function Open()
        if not pullout then
            CreatePullout()
        end
        ReadChoices()
        local value = getValue()
        for i, choice in ipairs(shown) do
            local entry = GetEntry(i)
            entry.text:SetText(choice.text)
            entry.check:SetShown(choice.value == value)
            entry:Show()
        end
        for i = #shown + 1, #entries do
            entries[i]:Hide()
        end

        local visible = math.max(math.min(#shown, DROPDOWN_MAX_ENTRIES), 1)
        local listWidth = DROPDOWN_WIDTH - 2 * DROPDOWN_PADDING_X
        if #shown > DROPDOWN_MAX_ENTRIES then
            listWidth = listWidth - SCROLL_BAR_SPACE
        end
        list:SetSize(listWidth, math.max(#shown, 1) * DROPDOWN_ENTRY_HEIGHT)
        scrollFrame:SetSize(listWidth, visible * DROPDOWN_ENTRY_HEIGHT)
        scrollFrame:SetVerticalScroll(0)
        -- The settings window may be scaled differently from UIParent.
        pullout:SetScale(button:GetEffectiveScale() / UIParent:GetEffectiveScale())
        pullout:SetSize(DROPDOWN_WIDTH, visible * DROPDOWN_ENTRY_HEIGHT + DROPDOWN_PADDING_TOP
            + DROPDOWN_PADDING_BOTTOM)
        pullout:ClearAllPoints()
        pullout:SetPoint("TOPLEFT", button, "BOTTOMLEFT", 0, -2)
        pullout:Show()
        UpdateText()
    end

    button:SetScript("OnClick", function()
        if pullout and pullout:IsShown() then
            Close()
        else
            Open()
        end
    end)
    SetTooltip(button, label, tooltip)
    button:HookScript("OnEnter", function()
        hovered = true
        UpdateArrow()
    end)
    button:HookScript("OnLeave", function()
        hovered = false
        UpdateArrow()
    end)
    -- The canvas is an own frame; the list must not stay open without the page.
    self.canvas:HookScript("OnHide", Close)
    UpdateArrow()

    self.controls[#self.controls + 1] = function()
        if pullout and pullout:IsShown() then
            Open()
        else
            ReadChoices()
            UpdateText()
        end
    end
end

function Panel:AddButton(label, buttonText, tooltip, onClick)
    local button = CreateFrame("Button", nil, self.content, "UIPanelButtonTemplate")
    button:SetSize(120, 22)
    button:SetPoint(self:AddLabeledRow(label))
    button:SetText(buttonText)
    button:SetScript("OnClick", onClick)
    SetTooltip(button, label, tooltip)
end
