local _, ns = ...

-- Suggestion list below an edit box, shared by the search boxes and the "add favorite" dialog.
-- Own frame instead of Blizzard's shared AutoCompleteBox: that one is also used by the chat
-- edit box, and touching it from addon code can taint chat commands.
local Suggestions = {}
ns.Suggestions = Suggestions

local MAX_SUGGESTIONS = 5
local SUGGESTION_HEIGHT = 16
local SUGGESTION_PADDING = 5

local SUGGESTION_BACKDROP = {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
}

-- True if the first name or the surname starts with the text ("tor" and "donn" both find
-- "Tor Donnerstein"), or the full name does.
local function NameStartsWith(fullName, wanted)
    local lowerName = fullName:lower()
    if lowerName:sub(1, #wanted) == wanted then
        return true
    end
    for word in lowerName:gmatch("%S+") do
        if word:sub(1, #wanted) == wanted then
            return true
        end
    end
    return false
end

-- Adds the entries of list ({ displayName, class, canMail }) matching the text to results, up to
-- MAX_SUGGESTIONS; exact matches and entries with canMail == false are left out. wanted is the
-- lowercase text. Returns false once results is full.
function Suggestions.AddMatches(results, list, wanted)
    for _, entry in ipairs(list) do
        if #results == MAX_SUGGESTIONS then
            return false
        end
        local name = entry.displayName
        if entry.canMail ~= false and name:lower() ~= wanted and NameStartsWith(name, wanted) then
            results[#results + 1] = entry
        end
    end
    return #results < MAX_SUGGESTIONS
end

local Suggestion = {}
Suggestion.__index = Suggestion

local function CreateList(editBox, width, offsetX, find)
    local self = setmetatable({ editBox = editBox, find = find, results = {}, selectedIndex = 0 }, Suggestion)

    local frame = CreateFrame("Frame", nil, editBox, "BackdropTemplate")
    frame:SetBackdrop(SUGGESTION_BACKDROP)
    frame:SetBackdropColor(0, 0, 0, 0.9)
    frame:SetBackdropBorderColor(0.6, 0.6, 0.6)
    frame:SetFrameStrata("DIALOG")
    frame:SetWidth(width)
    frame:SetPoint("TOPLEFT", editBox, "BOTTOMLEFT", offsetX, -2)
    frame:Hide()
    self.frame = frame

    self.buttons = {}
    for i = 1, MAX_SUGGESTIONS do
        local button = CreateFrame("Button", nil, frame)
        button:SetHeight(SUGGESTION_HEIGHT)
        button:SetPoint("TOPLEFT", SUGGESTION_PADDING, -SUGGESTION_PADDING - (i - 1) * SUGGESTION_HEIGHT)
        button:SetPoint("TOPRIGHT", -SUGGESTION_PADDING, -SUGGESTION_PADDING - (i - 1) * SUGGESTION_HEIGHT)
        button:SetNormalFontObject("GameFontHighlightSmall")
        button:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        button:SetText(" ")
        local fontString = button:GetFontString()
        fontString:ClearAllPoints()
        fontString:SetPoint("LEFT", 6, 0)
        fontString:SetPoint("RIGHT", -6, 0)
        fontString:SetJustifyH("LEFT")
        fontString:SetWordWrap(false)
        button:SetScript("OnClick", function()
            self:Accept(i)
        end)
        self.buttons[i] = button
    end
    return self
end

function Suggestion:IsShown()
    return self.frame:IsShown()
end

function Suggestion:Hide()
    self.frame:Hide()
    self.results = {}
    self.selectedIndex = 0
end

function Suggestion:Select(index)
    self.selectedIndex = index
    for i, button in ipairs(self.buttons) do
        if i == index then
            button:LockHighlight()
        else
            button:UnlockHighlight()
        end
    end
end

-- Moves the selection down (or up), wrapping around.
function Suggestion:Step(up)
    local count = #self.results
    if count == 0 then
        return
    end
    local index = self.selectedIndex + (up and -1 or 1)
    if index < 1 then
        index = count
    elseif index > count then
        index = 1
    end
    self:Select(index)
end

function Suggestion:Update(text)
    if text == "" then
        self:Hide()
        return
    end

    self.results = self.find(text)
    if #self.results == 0 then
        self:Hide()
        return
    end

    for i, button in ipairs(self.buttons) do
        local character = self.results[i]
        if character then
            local color = character.class and C_ClassColor.GetClassColor(character.class)
            button:SetText(color and color:WrapTextInColorCode(character.displayName) or character.displayName)
            button:Show()
        else
            button:Hide()
        end
    end
    self.frame:SetHeight(#self.results * SUGGESTION_HEIGHT + 2 * SUGGESTION_PADDING)
    self.frame:Show()
    self:Select(1)
end

function Suggestion:Accept(index)
    local character = self.results[index]
    self:Hide()
    if character then
        -- Programmatic SetText: OnTextChanged runs without userInput and does not show the list again.
        self.editBox:SetText(character.displayName)
        self.editBox:SetCursorPosition(#character.displayName)
    end
end

-- Shows a list of suggestions below the edit box while the user types. options:
--   width    width of the list
--   offsetX  horizontal offset of the list from the left edge of the edit box (optional)
--   find     find(text) returns the matching { displayName, class } entries, at most MAX_SUGGESTIONS
--   onEnter  onEnter(editBox) runs on Enter when no suggestion is selected (optional, else the focus
--            is cleared)
-- Tab and the up and down arrows move the selection, Enter accepts it, Escape closes the list. The
-- scripts OnEnterPressed and OnEscapePressed are replaced instead of hooked: the edit box templates
-- clear the focus on Enter and Escape, which would close the list before a hook could accept the
-- selected suggestion. Use it on own edit boxes only. Returns the list.
function Suggestions.Attach(editBox, options)
    local list = CreateList(editBox, options.width, options.offsetX or 0, options.find)

    -- HookScript keeps the template's own handler (placeholder text, clear button).
    editBox:HookScript("OnTextChanged", function(box, userInput)
        if userInput then
            list:Update(box:GetText())
        else
            list:Hide()
        end
    end)

    editBox:HookScript("OnTabPressed", function()
        if list:IsShown() then
            list:Step(IsShiftKeyDown())
        end
    end)

    editBox:HookScript("OnArrowPressed", function(_, key)
        if list:IsShown() and (key == "UP" or key == "DOWN") then
            list:Step(key == "UP")
        end
    end)

    editBox:SetScript("OnEnterPressed", function(box)
        if list:IsShown() and list.selectedIndex > 0 then
            list:Accept(list.selectedIndex)
        elseif options.onEnter then
            options.onEnter(box)
        else
            box:ClearFocus()
        end
    end)

    editBox:SetScript("OnEscapePressed", function(box)
        if list:IsShown() then
            list:Hide()
        elseif options.onEscape then
            options.onEscape(box)
        else
            box:ClearFocus()
        end
    end)

    -- Keep the list open while it is being clicked.
    editBox:HookScript("OnEditFocusLost", function()
        if not list.frame:IsMouseOver() then
            list:Hide()
        end
    end)

    return list
end
