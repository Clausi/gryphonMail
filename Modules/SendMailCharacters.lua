local _, ns = ...
local L = ns.L

-- Dropdown next to the "To" field of the "Send Mail" tab to pick one of the own characters.
local SendMailCharacters = ns:RegisterModule("SendMailCharacters")
local InboxView = ns.modules.InboxView
local Characters = ns.modules.Characters

-- Gap between the "To" field and the dropdown; there is room for one small button before the
-- postage text on the right.
local DROPDOWN_OFFSET_X = 6

-- Blizzard's reply also puts the sender's full name ("First Surname") into this field, so the full
-- name works as recipient. Programmatic SetText runs the field's OnTextChanged, which enables the
-- send button.
local function SelectRecipient(fullName)
    SendMailNameEditBox:SetText(fullName)
    SendMailSubjectEditBox:SetFocus()
end

-- Runs every time the menu opens (the dropdown regenerates it), so removed or new characters
-- show up without extra work.
local function GenerateMenu(_, rootDescription)
    rootDescription:SetTag("MENU_GRYPHONMAIL_SEND_TO_CHARACTER")
    rootDescription:CreateTitle(L["SEND_TO_CHARACTER"])

    local count = 0
    for _, character in ipairs(Characters:GetCharacters()) do
        -- Only characters of the same faction and ruleset can receive mail from this one.
        if character.canMail then
            local color = character.class and C_ClassColor.GetClassColor(character.class)
            local text = color and color:WrapTextInColorCode(character.fullName) or character.fullName
            rootDescription:CreateButton(text, function()
                SelectRecipient(character.fullName)
            end)
            count = count + 1
        end
    end

    if count == 0 then
        rootDescription:CreateTitle(GRAY_FONT_COLOR:WrapTextInColorCode(L["SEND_TO_CHARACTER_NONE"]))
    end
end

local function CreateDropdown()
    local dropdown = CreateFrame("DropdownButton", "GryphonMailSendToCharacterDropdown", SendMailFrame,
        "WowStyle1ArrowDropdownTemplate")
    dropdown:SetPoint("LEFT", SendMailNameEditBox, "RIGHT", DROPDOWN_OFFSET_X, 0)
    dropdown:SetupMenu(GenerateMenu)

    dropdown:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["SEND_TO_CHARACTER"])
        GameTooltip:Show()
    end)
    dropdown:HookScript("OnLeave", GameTooltip_Hide)

    return dropdown
end

function SendMailCharacters:OnInitialize()
    InboxView:OnReady(function()
        SendMailCharacters.dropdown = CreateDropdown()
    end)
end
