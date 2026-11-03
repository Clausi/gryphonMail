local _, ns = ...
local L = ns.L

-- Faster attaching on the "Send Mail" tab:
-- - Alt-click an item in the bags: attaches all its stacks, as far as there are free slots.
-- - Alt-right-click an attachment slot: removes all attachments.
-- Blizzard's bag buttons (and bag addons built on them) route every modified click to
-- HandleModifiedItemClick(link), on all clients; Alt is not bound to any modified click there by
-- default. Hooking that function instead of the bag buttons also covers bag addons.
local SendMailAttach = ns:RegisterModule("SendMailAttach")
local InboxView = ns.modules.InboxView

local function GetItemID(link)
    local itemID = link and link:match("|Hitem:(%d+)")
    return itemID and tonumber(itemID)
end

local function CountFreeSlots()
    local free = 0
    for i = 1, ATTACHMENTS_MAX_SEND do
        if not HasSendMailItem(i) then
            free = free + 1
        end
    end
    return free
end

-- Attaches every unlocked, unbound stack of itemID from the bags. Attached items stay in the bags,
-- locked, so stacks that are already attached are skipped.
local function AttachAll(itemID)
    local free = CountFreeSlots()
    for bag = 0, ns.Compat.GetLastBagIndex() do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            if free == 0 then
                return
            end
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID == itemID and not info.isLocked and not info.isBound then
                C_Container.PickupContainerItem(bag, slot)
                ClickSendMailItemButton()
                -- Still on the cursor: the item cannot be mailed (Blizzard shows the error).
                if CursorHasItem() then
                    ClearCursor()
                    return
                end
                free = free - 1
            end
        end
    end
end

local function OnModifiedItemClick(link)
    if not IsAltKeyDown() or not SendMailFrame:IsVisible() or CursorHasItem() then
        return
    end
    local itemID = GetItemID(link)
    if itemID then
        AttachAll(itemID)
    end
end

local function RemoveAll()
    for i = 1, ATTACHMENTS_MAX_SEND do
        if HasSendMailItem(i) then
            ClickSendMailItemButton(i, true)
        end
    end
end

-- Runs after Blizzard's OnClick, which already took the clicked attachment back.
local function OnAttachmentClick(_, button)
    if button == "RightButton" and IsAltKeyDown() then
        RemoveAll()
    end
end

-- Blizzard sets the tooltip again on every UpdateTooltip, which calls the hooked global again.
local function OnAttachmentEnter()
    GameTooltip:AddLine(L["SEND_ATTACH_HINT_ALL"], GRAY_FONT_COLOR:GetRGB())
    GameTooltip:AddLine(L["SEND_ATTACH_HINT_REMOVE"], GRAY_FONT_COLOR:GetRGB())
    GameTooltip:Show()
end

function SendMailAttach:OnInitialize()
    hooksecurefunc("HandleModifiedItemClick", OnModifiedItemClick)
    InboxView:OnReady(function()
        for i = 1, ATTACHMENTS_MAX_SEND do
            SendMailFrame.SendMailAttachments[i]:HookScript("OnClick", OnAttachmentClick)
        end
        hooksecurefunc("SendMailAttachment_OnEnter", OnAttachmentEnter)
    end, "SendMailAttach")
end
