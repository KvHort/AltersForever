-- Minimal WoW API mock to load Alters Forever and drive its mail, tabs and options.
local ADDON_DIR = ...
local log = {}
local timers, tickers = {}, {}
local now = 1700000000
local hooks = {}

local function noop() end

-- widget mock: unknown methods do nothing; Get*/Is* return safe values
local Widget = {}
local function NewWidget(kind, name)
    local w = { _kind = kind, _shown = true, _scripts = {}, _text = "", _events = {}, _w = 100, _h = 20 }
    return setmetatable(w, Widget)
end
local methods = {}
Widget.__index = function(self, key)
    if methods[key] then return methods[key] end
    if not key:match("^%u") then return nil end
    if key:match("^Get") or key:match("^Is") or key:match("^Can") then return function() return nil end end
    return noop
end
function methods:SetScript(event, fn) self._scripts[event] = fn end
function methods:HookScript(event, fn) local old = self._scripts[event]; self._scripts[event] = function(...) if old then old(...) end fn(...) end end
function methods:GetScript(event) return self._scripts[event] end
function methods:Show() self._shown = true; if self._scripts.OnShow then self._scripts.OnShow(self) end end
function methods:Hide() self._shown = false end
function methods:SetShown(on) if on then self:Show() else self:Hide() end end
function methods:IsShown() return self._shown end
function methods:IsVisible() return self._shown end
function methods:SetText(t) self._text = t == nil and "" or tostring(t) end
function methods:SetFormattedText(f, ...) self._text = string.format(f, ...) end
function methods:GetText() return self._text end
function methods:GetStringWidth() return #self._text * 5 end
function methods:GetUnboundedStringWidth() return #self._text * 5 end
function methods:SetWidth(w) self._w = w end
function methods:SetHeight(h) self._h = h end
function methods:SetSize(w, h) self._w, self._h = w, h end
function methods:GetWidth() return self._w end
function methods:GetHeight() return self._h end
function methods:GetLeft() return 0 end
function methods:GetCenter() return 0, 0 end
function methods:GetEffectiveScale() return 1 end
function methods:GetPoint() return "CENTER", nil, "CENTER", 0, 0 end
function methods:GetFont() return "Fonts\\FRIZQT__.TTF", 12, "" end
function methods:GetName() return self._name end
function methods:NumLines() return 0 end
function methods:RegisterEvent(e) self._events[e] = true end
function methods:UnregisterEvent(e) self._events[e] = nil end
function methods:IsEventRegistered(e) return self._events[e] end
function methods:GetObjectType() return self._kind end
function methods:CreateFontString() return NewWidget("FontString") end
function methods:CreateTexture() return NewWidget("Texture") end
function methods:CreateLine() return NewWidget("Line") end
function methods:CreateAnimationGroup() return NewWidget("AnimationGroup") end
function methods:CreateAnimation() return NewWidget("Animation") end
function methods:GetNormalTexture() return nil end
function methods:GetFrameLevel() return 1 end

local frames = {}
function CreateFrame(kind, name, parent, template)
    local w = NewWidget(kind, name)
    w._name = name
    if name then _G[name] = w end
    if kind == "EditBox" then w._text = "" end
    table.insert(frames, w)
    return w
end
UIParent = NewWidget("Frame")
Minimap = NewWidget("Frame")
GameTooltip = NewWidget("GameTooltip")
GameTooltip._lines = {}
function GameTooltip:AddLine(t) table.insert(self._lines, tostring(t)) end
function GameTooltip:AddDoubleLine(a, b) table.insert(self._lines, tostring(a) .. " | " .. tostring(b)) end
ItemRefTooltip = NewWidget("GameTooltip")
DEFAULT_CHAT_FRAME = { AddMessage = function(_, msg) table.insert(log, msg) end }
UISpecialFrames = {}
StaticPopupDialogs = {}
local popups = {}
function StaticPopup_Show(key, a, b, data) popups[#popups + 1] = { key = key, data = data } end
RAID_CLASS_COLORS = { WARRIOR = { colorStr = "ffc79c6e" }, MAGE = { colorStr = "ff69ccf0" } }
ITEM_QUALITY_COLORS = {}
CANCEL, YES, NO, ACCEPT = "Cancel", "Yes", "No", "Accept"
NUM_CHAT_WINDOWS = 1
Enum = {}

format = string.format
strtrim = function(s) return (s or ""):match("^%s*(.-)%s*$") end
strsplit = function(sep, s, n)
    local a, b = s:match("^(.-)" .. sep .. "(.*)$")
    if a then return a, b end
    return s
end
wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
tinsert = table.insert
hooksecurefunc = function(name, fn) hooks[name] = fn end
time = function() return now end
date = os.date
GetTime = function() return now end
GetLocale = function() return "enUS" end
GetCursorPosition = function() return 0, 0 end
IsShiftKeyDown = function() return false end

C_Timer = {
    After = function(_, fn) table.insert(timers, fn) end,
    NewTicker = function(_, fn) table.insert(tickers, fn) end,
}
C_DateAndTime = { GetSecondsUntilWeeklyReset = function() return 3 * 86400 end }

-- player
local player = { name = "Alpha", realm = "Normal", faction = "Alliance", money = 12345 }
UnitGUID = function() return "Player-1-" .. player.name end
UnitName = function() return player.name end
GetRealmName = function() return player.realm end
UnitClass = function() return "Warrior", "WARRIOR" end
UnitFactionGroup = function() return player.faction end
UnitRace = function() return "Human" end
UnitLevel = function() return 40 end
GetGuildInfo = function() return nil end
GetMoney = function() return player.money end
UnitXP = function() return 10 end
UnitXPMax = function() return 100 end
GetXPExhaustion = function() return 0 end
IsResting = function() return false end
GetRealZoneText = function() return "Elwynn" end
GetMaxPlayerLevel = function() return 60 end
GetProfessions = function() return nil end
GetInventoryItemID = function() return nil end
GetInventoryItemLink = function() return nil end
GetInventorySlotInfo = function() return 1, "tex" end
RequestTimePlayed = noop
RequestRaidInfo = noop
GetNumSavedInstances = function() return 0 end
GetNumFactions = function() return 0 end
GetNumSkillLines = function() return 0 end
HasNewMail = function() return true end
InCombatLockdown = function() return false end
-- the attributes scan: every value 0
for _, name in ipairs({ "UnitArmor", "UnitAttackPower", "UnitDamage", "UnitHealthMax", "UnitPowerMax",
    "UnitRangedAttackPower", "UnitRangedDamage", "UnitResistance", "UnitStat", "GetBlockChance", "GetCritChance",
    "GetDodgeChance", "GetHitModifier", "GetManaRegen", "GetParryChance", "GetRangedCritChance",
    "GetSpellBonusDamage", "GetSpellBonusHealing", "GetSpellCritChance" }) do
    _G[name] = function() return 0, 0, 0, 0 end
end
GetPVPLifetimeStats = function() return 0, 0 end
GetPVPSessionStats = function() return 0, 0 end
GetPVPYesterdayStats = function() return 0, 0 end
C_Container = {
    GetContainerNumSlots = function() return 0 end,
    GetContainerItemInfo = function() return nil end,
    GetContainerNumFreeSlots = function() return 0, 0 end,
    ContainerIDToInventoryID = function() return nil end,
}
C_Item = {
    GetItemNameByID = function(id) return "Item" .. id end,
    GetItemIconByID = function() return 134400 end,
    GetItemQualityByID = function() return 1 end,
    GetItemInfoInstant = function() return nil end,
}
C_Spell = { GetSpellName = function() return "Spell" end }

-- inbox
local inbox = {}
GetInboxNumItems = function() return #inbox, #inbox + 7 end
GetInboxHeaderInfo = function(i)
    local l = inbox[i]
    return nil, nil, l.from, l.subject, l.money, l.cod, l.days, l.items and #l.items or nil, false, l.returned
end
GetInboxItem = function(i, a)
    local item = inbox[i].items and inbox[i].items[a]
    if item then return "name", item[1], nil, item[2] end
end
GetInboxItemLink = function(i, a)
    local item = inbox[i].items and inbox[i].items[a]
    return item and ("|cffffffff|Hitem:" .. item[1] .. "|h[Item" .. item[1] .. "]|h|r")
end
local sendItems = {}
GetSendMailItem = function(a) local it = sendItems[a]; if it then return "n", it[1], nil, it[2] end end
GetSendMailItemLink = function(a) local it = sendItems[a]; return it and ("|Hitem:" .. it[1] .. "|h[Item" .. it[1] .. "]|h") end
GetSendMailMoney = function() return 500 end
GetSendMailCOD = function() return 0 end

-- auction house
local owned = {}
C_AuctionHouse = {
    GetNumOwnedAuctions = function() return #owned end,
    GetOwnedAuctionInfo = function(i) return owned[i] end,
    GetNumBids = function() return 0 end,
    QueryOwnedAuctions = noop,
    QueryBids = noop,
}

SlashCmdList = {}

-- load the addon
local ns = {}
for _, file in ipairs({ "Locales.lua", "Themes.lua", "AltersForever.lua", "Mail.lua", "Customize.lua" }) do
    local fh = assert(io.open(ADDON_DIR .. "/" .. file))
    local chunk = assert(loadstring(fh:read("*a"), "@" .. file))
    fh:close()
    chunk("AltersForever", ns)
end

local loader
for _, f in ipairs(frames) do
    if f._events.PLAYER_LOGIN then loader = f end
end
assert(loader, "no loader frame")
local function Fire(event, ...) loader._scripts.OnEvent(loader, event, ...) end
local function RunTimers()
    local list = timers
    timers = {}
    for _, fn in ipairs(list) do fn() end
end
local function Tick() for _, fn in ipairs(tickers) do fn() end end

local function Check(cond, msg)
    if not cond then error("CHECK FAILED: " .. msg, 2) end
    print("pass  " .. msg)
end

-- an older save: Beta has mail totals from 1.33
AltersForeverDB = {
    version = 2,
    chars = {
        ["Player-1-Beta"] = { name = "Beta", realm = "Normal", class = "MAGE", level = 20,
            mail = { [111] = 3 }, mailLetters = 2, mailMoney = 100, mailExpires = now + 86400, lastSeen = now - 3600 },
    },
}

Fire("PLAYER_LOGIN")
local db = AltersForeverDB
local beta = db.chars["Player-1-Beta"]
local me = db.chars["Player-1-Alpha"]
Check(db.version == 3, "data version upgraded to 3")
Check(beta.letters and #beta.letters == 1 and beta.letters[1].expected == "old", "old mail totals became one old letter")
Check(beta.mail[111] == 3 and beta.mailLetters == 2, "old item counts and letter count kept")
Check(me.faction == "Alliance", "faction recorded")

RunTimers()
Tick()
local warned = false
for _, m in ipairs(log) do if m:find("Beta") and m:find("expires") then warned = true end end
Check(warned, "expiry warning for Beta in chat")
local before = #log
Tick()
Check(#log == before, "no repeated warning on the next tick")

-- the player gets new mail and opens the mailbox
Fire("UPDATE_PENDING_MAIL")
Check(me.newMail, "new mail flag set from UPDATE_PENDING_MAIL")
inbox = {
    { from = "Bob", subject = "Hi", money = 0, cod = 0, days = 20, items = { { 222, 5 } } },
    { from = "Auction House", subject = "Sold", money = 900, cod = 0, days = 29.5 },
    { from = "Carl", subject = "COD", money = 0, cod = 5000, days = 2.5, items = { { 333, 1 } } },
}
Fire("MAIL_SHOW")
Fire("MAIL_INBOX_UPDATE")
Check(#me.letters == 3, "three letters saved")
Check(me.mailHidden == 7 and me.mailLetters == 10, "letters beyond the visible 50 counted")
Check(not me.newMail, "new mail flag cleared at the mailbox")
Check(me.mail[222] == 5 and me.mail[333] == 1, "item counts from letters")
Check(me.mailMoney == 900, "gold in mail")
Check(me.letters[3].cod == 5000, "COD amount saved")

-- send mail to Beta
sendItems = { { 444, 2 } }
hooks.SendMail("Beta", "For you")
Fire("MAIL_SEND_SUCCESS")
Check(#beta.letters == 2 and beta.letters[2].expected == "sent", "sent mail is an expected letter on Beta")
Check(beta.mail[444] == 2 and beta.newMail, "Beta has the sent items and a new mail flag")

-- return a letter to Beta? Bob is not an alt, so nothing
hooks.ReturnInboxItem(1)
Check(#beta.letters == 2, "returning a letter from a stranger changes no alt")
Fire("MAIL_CLOSED")

-- auctions: one sold, one active that ends later
owned = {
    { itemKey = { itemID = 555 }, itemLink = "|Hitem:555|h[Item555]|h", quantity = 1, status = 1, buyoutAmount = 1000, timeLeftSeconds = 0 },
    { itemKey = { itemID = 666 }, itemLink = "|Hitem:666|h[Item666]|h", quantity = 2, status = 0, buyoutAmount = 50, timeLeftSeconds = 3600 },
}
Fire("OWNED_AUCTIONS_UPDATED")
local sold
for _, l in ipairs(me.letters) do if l.expected == "auction" and l.estimate then sold = l end end
Check(sold and sold.money == 950, "sold auction gives an expected letter with 95% of the price")
Check(me.ah[666] == 2, "active auction still on the auction house")
-- a second scan must not give the sold letter twice
Fire("OWNED_AUCTIONS_UPDATED")
local count = 0
for _, l in ipairs(me.letters) do if l.expected == "auction" and l.estimate then count = count + 1 end end
Check(count == 1, "sold auction letter not repeated on a second scan")
now = now + 7200
Tick()
local ended
for _, l in ipairs(me.letters) do if l.maybeSold then ended = l end end
Check(ended and ended.items[1][1] == 666, "ended auction gives an expected letter with the item")
Check(me.ah[666] == nil and me.mail[666] == 2, "ended auction item moved from auction to mail")

-- window: open every tab and the customize page
SlashCmdList.ALTERSFOREVER("")
local window = AltersForeverWindow
Check(window and window:IsShown(), "window opens")
window.detail, window.filter, window.section = me, "bags", "items"
window.recipesOf = me
for i = 1, 10 do window.ShowTab(i) end
window.filter = "mail"
window.ShowTab(8)
window.detail = beta
window.ShowTab(8)
print("pass  every page opens without errors")
local mailTab = window.tabs[7]
Check(mailTab.label:GetText():find("Mail"), "mail tab label: " .. mailTab.label:GetText())
window.ShowTab(7)
local page = window.pages[7]
local rows = 0
for _, row in ipairs(page.table.rows) do if row.data then rows = rows + 1 end end
Check(rows >= 6, "mail tab lists letters (" .. rows .. " rows)")
for _, row in ipairs(page.table.rows) do
    if row.data then
        GameTooltip._lines = {}
        row._scripts.OnEnter(row)
    end
end
print("pass  every mail row tooltip works")
page.table.rows[1]._scripts.OnClick(page.table.rows[1], "LeftButton")
Check(window.tab == 8 and window.filter == "mail", "click on a letter opens the character page with the mail filter")
local charPage = window.pages[8]
Check(charPage.info:IsShown(), "character page shows the letter list")

-- slash commands
SlashCmdList.ALTERSFOREVER("customize")
Check(window.tab == 10, "/alts customize opens the customize page")
SlashCmdList.ALTERSFOREVER("mail")
Check(window.tab == 7, "/alts mail opens the mail tab")

-- hide the Guild tab, then move Mail with its up button on the customize page
db.options.showTabGuild = false
local ups = {}
for _, f in ipairs(frames) do
    if f.label and f.label._text == "^" then table.insert(ups, f) end
end
Check(#ups == 7, "one up button per tab")
-- without a saved order, Mail (tab 7) comes last
db.options.tabOrder = nil
ups[7]._scripts.OnClick(ups[7])
local names = {}
for _, n in ipairs(db.options.tabOrder) do names[#names + 1] = n end
Check(table.concat(names, ",") == "Characters,Professions,Cooldowns,Guild,Search,Mail,Options", "Mail moved one place up: " .. table.concat(names, ","))
Check(not window.tabs[4]:IsShown(), "hidden Guild tab is not shown")
Check(window.tabs[6]:IsShown(), "Options tab always shown")
Check(window.tabs[1]._w == 110, "six visible tabs share the width (" .. window.tabs[1]._w .. ")")

-- section hiding
db.options.showSectiontalents = false
window.detail = me
window.section = "talents"
window.ShowTab(8)
Check(window.section == "items", "a hidden section falls back to items")

-- filters
db.options.onlyFaction = true
beta.faction = "Horde"
window.ShowTab(1)
local names = {}
for _, row in ipairs(window.pages[1].table.rows) do if row.data then names[#names + 1] = row.data.name end end
Check(#names == 1 and names[1] == "Alpha", "faction filter hides the Horde alt")
db.options.onlyFaction = false

-- minimap summary
local button = AltersForeverMinimapButton
GameTooltip._lines = {}
button._scripts.OnEnter(button)
local summary = table.concat(GameTooltip._lines, "\n")
Check(summary:find("characters"), "minimap tooltip has a summary")
print("---- minimap tooltip")
print(summary)

-- notes
local chars = window.pages[1].table
IsShiftKeyDown = function() return true end
chars.onClick(beta, "RightButton")
Check(popups[#popups].key == "ALTERSFOREVER_NOTE", "shift-right click opens the note popup")
local dialog = NewWidget("Frame")
dialog.editBox = NewWidget("EditBox")
dialog.editBox._text = "  Bank alt  "
StaticPopupDialogs.ALTERSFOREVER_NOTE.OnAccept(dialog, beta)
Check(beta.note == "Bank alt", "note saved and trimmed")

print("---- chat")
for _, m in ipairs(log) do print(m) end
