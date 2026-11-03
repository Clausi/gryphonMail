local _, ns = ...
local L = ns.L

-- Faster attaching on the "Send Mail" tab:
-- - Alt-click an item in the bags: attaches all its stacks, as far as there are free slots.
-- - Right-click an empty attachment slot: menu that attaches all items of a category (item class >
--   subclass > item, with icons).
-- - Alt-right-click an attachment slot: removes all attachments.
-- Blizzard's bag buttons (and bag addons built on them) route every modified click to
-- HandleModifiedItemClick(link), on all clients; Alt is not bound to any modified click there by
-- default. Hooking that function instead of the bag buttons also covers bag addons.
local SendMailAttach = ns:RegisterModule("SendMailAttach")
local InboxView = ns.modules.InboxView

-- Enum.ItemQuality.Poor (gray items).
local QUALITY_POOR = 0

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

-- Attached items stay in the bags, locked, so stacks that are already attached are skipped.
local function IsAttachable(info)
    return info and not info.isLocked and not info.isBound
end

-- Calls callback(bag, slot, info) for every stack in the bags that can be attached. Stops when the
-- callback returns true.
local function ForEachAttachable(callback)
    for bag = 0, ns.Compat.GetLastBagIndex() do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if IsAttachable(info) and callback(bag, slot, info) then
                return
            end
        end
    end
end

-- Attaches every attachable stack for which matches(info) is true, as far as there are free slots.
local function AttachMatching(matches)
    local free = CountFreeSlots()
    ForEachAttachable(function(bag, slot, info)
        if free == 0 then
            return true
        end
        if matches(info) then
            C_Container.PickupContainerItem(bag, slot)
            ClickSendMailItemButton()
            -- Still on the cursor: the item cannot be mailed (Blizzard shows the error).
            if CursorHasItem() then
                ClearCursor()
                return true
            end
            free = free - 1
        end
    end)
end

local function MatchesItem(itemID)
    return function(info)
        return info.itemID == itemID
    end
end

local function OnModifiedItemClick(link)
    if not IsAltKeyDown() or not SendMailFrame:IsVisible() or CursorHasItem() then
        return
    end
    local itemID = GetItemID(link)
    if itemID then
        AttachMatching(MatchesItem(itemID))
    end
end

local function RemoveAll()
    for i = 1, ATTACHMENTS_MAX_SEND do
        if HasSendMailItem(i) then
            ClickSendMailItemButton(i, true)
        end
    end
end

-- Item class and subclass with their localized names. GetItemInfoInstant only uses static item
-- data, so it works for every item in the bags.
local function GetItemClass(itemID)
    local _, className, subClassName, _, _, classID, subClassID = C_Item.GetItemInfoInstant(itemID)
    return classID, subClassID, className, subClassName
end

local function MatchesClass(classID, subClassID)
    return function(info)
        local itemClassID, itemSubClassID = GetItemClass(info.itemID)
        return itemClassID == classID and (subClassID == nil or itemSubClassID == subClassID)
    end
end

local function ByName(a, b)
    return a.name < b.name
end

local function GetName(entry)
    return entry.name
end

-- Adds a child group (class, subclass or item) to parent.children, counting one stack.
local function CountChild(parent, id, create)
    local child = parent.byID[id]
    if not child then
        child = create()
        child.count = 0
        parent.byID[id] = child
        parent.children[#parent.children + 1] = child
    end
    child.count = child.count + 1
    return child
end

local function SortChildren(parent)
    table.sort(parent.children, ByName)
    for _, child in ipairs(parent.children) do
        if child.children then
            SortChildren(child)
        end
    end
end

-- The attachable stacks in the bags as a tree item class > subclass > item, sorted by name, plus
-- the number of gray stacks. Each node has the number of stacks (= attachment slots it needs).
local function CollectCategories()
    local root, poorCount = { children = {}, byID = {} }, 0
    ForEachAttachable(function(_, _, info)
        local classID, subClassID, className, subClassName = GetItemClass(info.itemID)
        if classID then
            local class = CountChild(root, classID, function()
                return { id = classID, name = className, children = {}, byID = {} }
            end)
            local subClass = CountChild(class, subClassID, function()
                return { id = subClassID, name = subClassName, children = {}, byID = {} }
            end)
            CountChild(subClass, info.itemID, function()
                return { id = info.itemID, name = info.itemName or UNKNOWN, icon = info.iconFileID,
                    quality = info.quality }
            end)
        end
        if info.quality == QUALITY_POOR then
            poorCount = poorCount + 1
        end
    end)
    SortChildren(root)
    return root.children, poorCount
end

local function AddAttachButton(description, name, count, matches)
    description:CreateButton(L["SEND_ATTACH_ENTRY"]:format(name, count), function()
        AttachMatching(matches)
    end)
end

-- Icon and name in the item's quality color, e.g. "[icon] Iron Ore (3)".
local function AddItemButton(description, item)
    local name = item.name
    if item.quality then
        local _, _, _, hex = C_Item.GetItemQualityColor(item.quality)
        name = "|c" .. hex .. name .. "|r"
    end
    if item.icon then
        name = ("|T%d:16|t %s"):format(item.icon, name)
    end
    AddAttachButton(description, name, item.count, MatchesItem(item.id))
end

-- Submenu of a subclass: "All" (if there is more than one item) and each item. A long list (e.g.
-- many armor pieces) is split into name ranges.
local function AddSubClass(description, class, subClass)
    local submenu = description:CreateButton(L["SEND_ATTACH_ENTRY"]:format(subClass.name, subClass.count))
    if #subClass.children > 1 then
        AddAttachButton(submenu, L["SEND_ATTACH_ALL"], subClass.count, MatchesClass(class.id, subClass.id))
        submenu:CreateDivider()
    end
    ns.AddMenuEntries(submenu, subClass.children, AddItemButton, GetName)
end

-- One submenu per item class: "All" (if there is more than one subclass) and each subclass, with
-- the items in a third level. Item classes and their subclasses stay below the 20 entries per menu
-- of ns.AddMenuEntries.
local function GenerateCategoryMenu(_, rootDescription)
    rootDescription:SetTag("MENU_GRYPHONMAIL_SEND_ATTACH")
    rootDescription:CreateTitle(L["SEND_ATTACH_MENU"]:format(CountFreeSlots()))

    local classes, poorCount = CollectCategories()
    if #classes == 0 then
        rootDescription:CreateTitle(GRAY_FONT_COLOR:WrapTextInColorCode(L["SEND_ATTACH_NONE"]))
        return
    end

    for _, class in ipairs(classes) do
        local submenu = rootDescription:CreateButton(L["SEND_ATTACH_ENTRY"]:format(class.name, class.count))
        if #class.children > 1 then
            AddAttachButton(submenu, L["SEND_ATTACH_ALL"], class.count, MatchesClass(class.id))
            submenu:CreateDivider()
        end
        for _, subClass in ipairs(class.children) do
            AddSubClass(submenu, class, subClass)
        end
    end

    if poorCount > 0 then
        rootDescription:CreateDivider()
        AddAttachButton(rootDescription, L["SEND_ATTACH_POOR"], poorCount, function(info)
            return info.quality == QUALITY_POOR
        end)
    end
end

-- Whether the slot was empty before Blizzard's OnClick ran: a right-click on a filled slot takes
-- the attachment back, so the slot is always empty afterwards.
local clickedEmptySlot = false

local function OnAttachmentPreClick(self)
    clickedEmptySlot = not HasSendMailItem(self:GetID()) and not CursorHasItem()
end

-- Runs after Blizzard's OnClick.
local function OnAttachmentClick(self, button)
    if button ~= "RightButton" then
        return
    end
    if IsAltKeyDown() then
        RemoveAll()
    elseif clickedEmptySlot then
        MenuUtil.CreateContextMenu(self, GenerateCategoryMenu)
    end
end

-- Blizzard sets the tooltip again on every UpdateTooltip, which calls the hooked global again.
local function OnAttachmentEnter()
    GameTooltip:AddLine(L["SEND_ATTACH_HINT_ALL"], GRAY_FONT_COLOR:GetRGB())
    GameTooltip:AddLine(L["SEND_ATTACH_HINT_MENU"], GRAY_FONT_COLOR:GetRGB())
    GameTooltip:AddLine(L["SEND_ATTACH_HINT_REMOVE"], GRAY_FONT_COLOR:GetRGB())
    GameTooltip:Show()
end

function SendMailAttach:OnInitialize()
    hooksecurefunc("HandleModifiedItemClick", OnModifiedItemClick)
    InboxView:OnReady(function()
        for i = 1, ATTACHMENTS_MAX_SEND do
            local button = SendMailFrame.SendMailAttachments[i]
            button:HookScript("PreClick", OnAttachmentPreClick)
            button:HookScript("OnClick", OnAttachmentClick)
        end
        hooksecurefunc("SendMailAttachment_OnEnter", OnAttachmentEnter)
    end, "SendMailAttach")
end
