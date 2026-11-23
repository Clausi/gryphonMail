local _, ns = ...
local L = ns.L
local Names = ns.Names

-- Dialog to add a favorite by name, opened from the options. The name is suggested from the recent
-- allies while typing. Own frame instead of a StaticPopup: Blizzard's popup edit boxes are shared by
-- all dialogs, and hooking them from addon code could taint them.
local FavoriteDialog = ns:RegisterModule("FavoriteDialog")
local Characters = ns.modules.Characters
local Contacts = ns.modules.Contacts
local Favorites = ns.modules.Favorites

local WIDTH = 320
local HEIGHT = 130
local EDIT_WIDTH = 260
local BUTTON_WIDTH = 100

local BACKDROP = {
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true,
    tileSize = 32,
    edgeSize = 32,
    insets = { left = 11, right = 11, top = 12, bottom = 11 },
}

local frame

-- Recent allies that are neither favorites nor own characters and start with the text.
local function FindSuggestions(text)
    local list = {}
    for _, contact in ipairs(Contacts:GetList(Contacts.RECENT_ALLIES)) do
        if not Favorites:Contains(contact.name) and not Characters:IsOwnCharacter(contact.name) then
            list[#list + 1] = { displayName = Names.ToDisplay(contact.name), class = contact.class }
        end
    end
    local results = {}
    ns.Suggestions.AddMatches(results, list, text:lower())
    return results
end

-- Adds the favorite and closes the dialog; stays open when the name was not added (the reason is
-- printed), so it can be corrected.
local function Accept()
    if Favorites:Add(frame.editBox:GetText()) then
        frame:Hide()
    end
end

local function Create()
    frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
    frame:SetBackdrop(BACKDROP)
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:EnableMouse(true)
    frame:Hide()

    local text = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    text:SetPoint("TOP", 0, -20)
    text:SetWidth(WIDTH - 40)
    text:SetText(L["OPTIONS_FAVORITE_ADD_PROMPT"])

    local editBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    editBox:SetSize(EDIT_WIDTH, 20)
    editBox:SetPoint("TOP", text, "BOTTOM", 0, -12)
    editBox:SetAutoFocus(false)
    editBox:SetMaxLetters(64)
    -- The template's left inset places the text 6 px right of the box.
    ns.Suggestions.Attach(editBox, {
        width = EDIT_WIDTH,
        offsetX = -6,
        find = FindSuggestions,
        onEnter = Accept,
        onEscape = function()
            frame:Hide()
        end,
    })
    frame.editBox = editBox

    local add = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    add:SetSize(BUTTON_WIDTH, 22)
    add:SetPoint("BOTTOMRIGHT", frame, "BOTTOM", -4, 16)
    add:SetText(L["OPTIONS_FAVORITE_ADD_BUTTON"])
    add:SetScript("OnClick", Accept)

    local cancel = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    cancel:SetSize(BUTTON_WIDTH, 22)
    cancel:SetPoint("BOTTOMLEFT", frame, "BOTTOM", 4, 16)
    cancel:SetText(CANCEL)
    cancel:SetScript("OnClick", function()
        frame:Hide()
    end)

    frame:SetScript("OnShow", function()
        editBox:SetText("")
        editBox:SetFocus()
    end)
end

function FavoriteDialog:Show()
    if not frame then
        Create()
    end
    frame:Show()
end
