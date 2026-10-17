local _, ns = ...
local L = ns.L

-- Records what was collected from mails (gold and items) per character, keeps it for a configurable
-- number of days and prints a summary after "Open All".
--
-- A take request (TakeInboxItem / TakeInboxMoney / AutoLootMailItem) is not proof that something
-- arrived: Blizzard's "Open All" repeats requests for the same attachment (also after mail indices
-- shift), requests fail, and on Forever MAIL_SUCCESS / MAIL_FAILED carry no item ID to match them.
-- Requests are therefore only remembered as pending and logged once the result is visible:
--   items: the "You receive item: ..." loot message (CHAT_MSG_LOOT) with the same item
--   gold:  the increase of the player's money (PLAYER_MONEY)
--   C.O.D.: the decrease of the player's money by exactly the C.O.D. amount (PLAYER_MONEY)
-- Duplicate or failed requests produce no such result and are dropped.
local MailLog = ns:RegisterModule("MailLog")
local InboxView = ns.modules.InboxView

local SECONDS_PER_DAY = 24 * 60 * 60
local MIN_RETENTION_DAYS = 1
local MAX_RETENTION_DAYS = 365

-- Pending requests older than this are not matched anymore.
local PENDING_TIMEOUT_SECONDS = 10
-- Loot messages can arrive shortly after "Open All" has finished.
local SUMMARY_DELAY_SECONDS = 1

-- Localized "You receive item: %s" formats; the part before the item is used to recognize own loot.
local LOOT_SELF_FORMATS = { "LOOT_ITEM_PUSHED_SELF", "LOOT_ITEM_PUSHED_SELF_MULTIPLE" }

-- Entries of the logged-in character, oldest first:
--   { time, sender, subject, icon, money, items = { { link, count } }, codPaid (optional) }
local entries = {}
-- Mails touched since the mailbox was opened: { mail, entry }. Used to group takes per mail.
local sessionMails = {}
-- Take requests waiting for their result:
--   { kind = "item" | "money" | "cod", mail, slot, itemID, link, count, money, requestedAt }
local pendingTakes = {}
-- Totals of the current "Open All" / "Open Filtered" run (item quantities and copper), nil while none
-- is running. Manual takes outside such a run are logged but not summarized.
local session
local lastMoney = 0
local changeListeners = {}

local function SafeString(value)
    if type(value) ~= "string" or (issecretvalue and issecretvalue(value)) then
        return nil
    end
    return value
end

local function NotifyChanged()
    for _, listener in ipairs(changeListeners) do
        listener()
    end
end

local function Prune()
    local cutoff = time() - ns.db.logRetentionDays * SECONDS_PER_DAY
    local kept = {}
    for _, entry in ipairs(entries) do
        if entry.time >= cutoff then
            kept[#kept + 1] = entry
        end
    end
    wipe(entries)
    for i, entry in ipairs(kept) do
        entries[i] = entry
    end
end

-- Mail identity (sender, subject, expiry) shared with InboxView, stable while indices shift.
local function GetMailIdentity(index)
    return InboxView:GetMailIdentity(index)
end

local IsSameMail = InboxView.IsSameMail

local function GetEntryForMail(mail)
    for _, sessionMail in ipairs(sessionMails) do
        if IsSameMail(sessionMail.mail, mail) then
            return sessionMail.entry
        end
    end

    local entry = {
        time = time(),
        sender = mail.sender,
        subject = mail.subject,
        icon = mail.icon,
        money = 0,
        items = {},
    }
    entries[#entries + 1] = entry
    sessionMails[#sessionMails + 1] = { mail = mail, entry = entry }
    return entry
end

local function AddPending(pending)
    pending.requestedAt = GetTime()
    pendingTakes[#pendingTakes + 1] = pending
end

local function RequestMoney(index)
    local money = select(5, GetInboxHeaderInfo(index))
    if not money or money <= 0 then
        return
    end
    ns:Debug("TakeInboxMoney(%d): %d copper requested", index, money)
    AddPending({ kind = "money", mail = GetMailIdentity(index), money = money })
end

local function RequestItem(index, attachmentIndex)
    local link = GetInboxItemLink(index, attachmentIndex)
    if not link then
        return
    end
    local _, itemID, _, count = GetInboxItem(index, attachmentIndex)
    itemID = itemID or tonumber(link:match("item:(%d+)"))
    ns:Debug("TakeInboxItem(%d, %d): %s x%d requested", index, attachmentIndex, link, count or 1)
    local mail = GetMailIdentity(index)
    AddPending({
        kind = "item",
        mail = mail,
        slot = attachmentIndex,
        itemID = itemID,
        link = link,
        count = count or 1,
    })

    -- Taking an attachment of a C.O.D. mail pays its C.O.D. amount (once per mail).
    local codAmount = select(6, GetInboxHeaderInfo(index))
    if codAmount and codAmount > 0 then
        ns:Debug("C.O.D. of %d copper requested", codAmount)
        AddPending({ kind = "cod", mail = mail, money = codAmount })
    end
end

-- Shift-click on a mail takes its money and all attachments at once.
local function RequestAutoLoot(index)
    RequestMoney(index)
    for attachmentIndex = 1, ATTACHMENTS_MAX_RECEIVE do
        if HasInboxItem(index, attachmentIndex) then
            RequestItem(index, attachmentIndex)
        end
    end
end

local function DropExpiredPending()
    local now = GetTime()
    for i = #pendingTakes, 1, -1 do
        if now - pendingTakes[i].requestedAt > PENDING_TIMEOUT_SECONDS then
            table.remove(pendingTakes, i)
        end
    end
end

-- Removes the committed request and every other request for the same attachment (duplicates).
local function RemoveWithDuplicates(committed)
    for i = #pendingTakes, 1, -1 do
        local pending = pendingTakes[i]
        if pending == committed or (pending.kind == committed.kind and pending.slot == committed.slot
            and IsSameMail(pending.mail, committed.mail)) then
            table.remove(pendingTakes, i)
        end
    end
end

local function CommitItem(pending)
    local entry = GetEntryForMail(pending.mail)
    entry.items[#entry.items + 1] = { link = pending.link, count = pending.count }
    if session then
        session.items = session.items + pending.count
    end
    ns:Debug("Received %s x%d", pending.link, pending.count)
    RemoveWithDuplicates(pending)
    NotifyChanged()
end

local function CommitMoney(pending)
    local entry = GetEntryForMail(pending.mail)
    entry.money = entry.money + pending.money
    if session then
        session.money = session.money + pending.money
    end
    ns:Debug("Received %d copper", pending.money)
    RemoveWithDuplicates(pending)
    NotifyChanged()
end

local function IsOwnLootMessage(text)
    for _, key in ipairs(LOOT_SELF_FORMATS) do
        local fmt = _G[key]
        local prefix = type(fmt) == "string" and fmt:match("^(.-)%%")
        if prefix and prefix ~= "" and text:sub(1, #prefix) == prefix then
            return true
        end
    end
    return false
end

local function OnLootMessage(_, text)
    text = SafeString(text)
    if not text or #pendingTakes == 0 or not IsOwnLootMessage(text) then
        return
    end
    local itemID = tonumber(text:match("item:(%d+)"))
    if not itemID then
        return
    end

    DropExpiredPending()
    for _, pending in ipairs(pendingTakes) do
        if pending.kind == "item" and pending.itemID == itemID then
            CommitItem(pending)
            return
        end
    end
end

local function CommitCod(pending)
    local entry = GetEntryForMail(pending.mail)
    entry.codPaid = (entry.codPaid or 0) + pending.money
    ns:Debug("Paid %d copper C.O.D.", pending.money)
    RemoveWithDuplicates(pending)
    NotifyChanged()
end

-- A payment counts as C.O.D. only if the money dropped by exactly the requested amount.
local function OnMoneySpent(amount)
    for _, pending in ipairs(pendingTakes) do
        if pending.kind == "cod" and pending.money == amount then
            CommitCod(pending)
            return
        end
    end
end

local function OnMoneyChanged()
    local money = GetMoney()
    local delta = money - lastMoney
    lastMoney = money
    if delta == 0 or #pendingTakes == 0 then
        return
    end

    DropExpiredPending()
    if delta < 0 then
        OnMoneySpent(-delta)
        return
    end
    -- Prefer the request with exactly this amount, otherwise take requests in order while they fit.
    for _, pending in ipairs(pendingTakes) do
        if pending.kind == "money" and pending.money == delta then
            CommitMoney(pending)
            return
        end
    end
    local remaining = delta
    local i = 1
    while i <= #pendingTakes do
        local pending = pendingTakes[i]
        if pending.kind == "money" and pending.money <= remaining then
            remaining = remaining - pending.money
            CommitMoney(pending)
            i = 1
        else
            i = i + 1
        end
    end
end

local function FormatItemCount(count)
    return count == 1 and L["ITEM_COUNT_ONE"] or L["ITEM_COUNT"]:format(count)
end

function MailLog:FormatItemCount(count)
    return FormatItemCount(count)
end

-- Total quantity of all items of an entry (a stack of 20 counts as 20).
function MailLog:GetItemQuantity(entry)
    local quantity = 0
    for _, item in ipairs(entry.items) do
        quantity = quantity + item.count
    end
    return quantity
end

local function PrintSummary(totals)
    local parts = {}
    if totals.items > 0 then
        parts[#parts + 1] = FormatItemCount(totals.items)
    end
    if totals.money > 0 then
        parts[#parts + 1] = GetMoneyString(totals.money, true)
    end
    if #parts > 0 then
        ns:Print(L["SUMMARY_COLLECTED"], table.concat(parts, L["SUMMARY_AND"]))
    end
end

local function SetupOpenAllSummary()
    hooksecurefunc(OpenAllMail, "StartOpening", function()
        session = { money = 0, items = 0 }
    end)
    -- Also runs when the mailbox is closed while opening. The summary waits briefly, so loot
    -- messages of the last take are still counted.
    hooksecurefunc(OpenAllMail, "StopOpening", function()
        local finished = session
        if not finished then
            return
        end
        C_Timer.After(SUMMARY_DELAY_SECONDS, function()
            if session == finished then
                session = nil
            end
            PrintSummary(finished)
        end)
    end)
end

local function HandleLogCommand(args)
    local action, rest = args:match("^(%S*)%s*(.-)$")
    action = action:lower()

    if action == "days" then
        local days = tonumber(rest)
        if not days or days < MIN_RETENTION_DAYS or days > MAX_RETENTION_DAYS or days ~= floor(days) then
            ns:Print(L["LOG_DAYS_INVALID"], MIN_RETENTION_DAYS, MAX_RETENTION_DAYS)
            return
        end
        ns.db.logRetentionDays = days
        Prune()
        NotifyChanged()
        ns:Print(L["LOG_DAYS_SET"], days)
    elseif action == "clear" then
        wipe(entries)
        wipe(sessionMails)
        wipe(pendingTakes)
        NotifyChanged()
        ns:Print(L["LOG_CLEARED"])
    else
        ns:Print(L["LOG_INFO"], ns.db.logRetentionDays, #entries)
    end
end

-- Entries of the logged-in character, oldest first. Do not modify.
function MailLog:GetEntries()
    return entries
end

function MailLog:GetRetentionDays()
    return ns.db.logRetentionDays
end

-- Registers a callback that runs whenever the log changes.
function MailLog:OnChange(callback)
    changeListeners[#changeListeners + 1] = callback
end

function MailLog:OnInitialize()
    -- Stored per character (SavedVariablesPerCharacter), so only the own log is loaded.
    entries = ns.charDb.log

    ns:RegisterCommand("log", HandleLogCommand, { L["HELP_LOG"], L["HELP_LOG_DAYS"], L["HELP_LOG_CLEAR"] })

    -- Post-hooks run right after the call, while the mail data is still available.
    hooksecurefunc("TakeInboxMoney", RequestMoney)
    hooksecurefunc("TakeInboxItem", RequestItem)
    hooksecurefunc("AutoLootMailItem", RequestAutoLoot)

    ns:RegisterEvent("CHAT_MSG_LOOT", OnLootMessage)
    ns:RegisterEvent("PLAYER_MONEY", OnMoneyChanged)
    ns:RegisterEvent("MAIL_SHOW", function()
        lastMoney = GetMoney()
    end)
    ns:RegisterEvent("MAIL_CLOSED", function()
        wipe(sessionMails)
        wipe(pendingTakes)
    end)

    InboxView:OnReady(SetupOpenAllSummary)
end

function MailLog:OnEnable()
    lastMoney = GetMoney()
    Prune()
end
