-- Alters Forever: pestanas, secciones, filtros, notas y resumen del boton del minimapa
-- carga despues de AltersForever.lua; db, me y window se leen de ns, que se rellenan al entrar

local _, ns = ...
local mailbox, custom, af = ns.mailbox, ns.custom, ns.af
local L, Money, Duration, ClassColored, SortedChars = af.L, af.Money, af.Duration, af.ClassColored, af.SortedChars
local Skin, forever, MakeButton, MakeCheck, RefreshWindow = af.Skin, af.forever, af.MakeButton, af.MakeCheck, af.RefreshWindow
local TABS, SECTIONS, COOLDOWNS_PAGE, OPTIONS_PAGE = af.TABS, af.SECTIONS, af.COOLDOWNS_PAGE, af.OPTIONS_PAGE


-- filtros de reino y faccion; el pj actual siempre pasa
function custom.Allowed(c)
    local options = ns.db.options
    if c == ns.me then return true end
    if options.onlyRealm and c.realm and ns.me.realm and c.realm ~= ns.me.realm then return false end
    if options.onlyFaction and c.faction and ns.me.faction and c.faction ~= ns.me.faction then return false end
    return true
end


-- notas: se ven en el tooltip y en la ficha
function custom.PopupBox(dialog)
    return dialog.editBox or (dialog.GetEditBox and dialog:GetEditBox())
end

StaticPopupDialogs.ALTERSFOREVER_NOTE = {
    text = L["Note for %s:"],
    button1 = ACCEPT or OKAY,
    button2 = CANCEL,
    hasEditBox = 1,
    maxLetters = 200,
    editBoxWidth = 280,
    OnShow = function(self, c)
        c = c or self.data
        local box = custom.PopupBox(self)
        box:SetText(c and c.note or "")
        box:HighlightText()
    end,
    OnAccept = function(self, c)
        c = c or self.data
        if not c then return end
        local text = strtrim(custom.PopupBox(self):GetText() or "")
        c.note = text ~= "" and text or nil
        RefreshWindow()
    end,
    EditBoxOnEnterPressed = function(self, c)
        local dialog = self:GetParent()
        StaticPopupDialogs.ALTERSFOREVER_NOTE.OnAccept(dialog, c)
        dialog:Hide()
    end,
    EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

function custom.EditNote(c)
    StaticPopup_Show("ALTERSFOREVER_NOTE", c.name, nil, c)
end

function custom.LayoutSections(page, anchor)
    local previous
    for i, btn in ipairs(page.sectionButtons) do
        local shown = i == 1 or ns.db.options["showSection" .. btn.key]
        btn:SetShown(shown)
        if shown then
            btn:ClearAllPoints()
            if previous then
                btn:SetPoint("LEFT", previous, "RIGHT", 4, 0)
            else
                btn:SetPoint("LEFT", anchor, "RIGHT", 10, 2)
            end
            previous = btn
        elseif ns.window.section == btn.key then
            ns.window.section = "items"
        end
    end
end


-- orden guardado por nombre; las pestanas que falten van al final
function custom.TabOrder()
    local order, seen = {}, {}
    for _, name in ipairs(ns.db.options.tabOrder or {}) do
        for i, tabName in ipairs(TABS) do
            if tabName == name and not seen[i] then
                table.insert(order, i)
                seen[i] = true
            end
        end
    end
    for i in ipairs(TABS) do
        if not seen[i] then table.insert(order, i) end
    end
    return order
end

-- Opciones no se puede quitar: sin ella no se vuelve a esta pagina
function custom.TabShown(i)
    return TABS[i] == "Options" or ns.db.options["showTab" .. TABS[i]]
end

function custom.FirstTab()
    for _, i in ipairs(custom.TabOrder()) do
        if custom.TabShown(i) then return i end
    end
    return OPTIONS_PAGE
end

function custom.MoveTab(i, delta)
    local order = custom.TabOrder()
    for n, index in ipairs(order) do
        if index == i and order[n + delta] then
            order[n], order[n + delta] = order[n + delta], order[n]
            break
        end
    end
    local names = {}
    for _, index in ipairs(order) do table.insert(names, TABS[index]) end
    ns.db.options.tabOrder = names
    custom.LayoutTabs()
end

-- el ancho se reparte entre las que se ven
function custom.LayoutTabs()
    local shown = {}
    for _, i in ipairs(custom.TabOrder()) do
        local tab = ns.window.tabs[i]
        if custom.TabShown(i) then
            table.insert(shown, tab)
        else
            tab:Hide()
        end
    end
    local step = math.min(116, math.floor(716 / #shown))
    for n, tab in ipairs(shown) do
        tab:SetWidth(step - 6)
        tab:ClearAllPoints()
        tab:SetPoint("TOPLEFT", 12 + (n - 1) * step, -36)
        tab:Show()
    end
    if ns.window.lastTab and not custom.TabShown(ns.window.lastTab) then ns.window.lastTab = custom.FirstTab() end
    RefreshWindow()
end

-- cuantos personajes piden atencion, en la pestana
function custom.UpdateBadges()
    local expiring, new, ready, now = 0, 0, 0, time()
    for _, c in ipairs(SortedChars()) do
        local state = mailbox.State(c)
        if state == "expiring" then expiring = expiring + 1 elseif state == "new" then new = new + 1 end
        for _, at in pairs(c.cooldowns or {}) do
            if at <= now then ready = ready + 1 end
        end
    end
    local mail = L["Mail"]
    if expiring > 0 then
        mail = mail .. format(" |cffff5050(%d)|r", expiring)
    elseif new > 0 then
        mail = mail .. format(" |cff80c0ff(%d)|r", new)
    end
    ns.window.tabs[mailbox.PAGE]:SetLabel(mail)
    ns.window.tabs[COOLDOWNS_PAGE]:SetLabel(L["Cooldowns"] .. (ready > 0 and format(" |cff40bf40(%d)|r", ready) or ""))
end


-- filtros de reino y faccion bajo la lista de personajes
function custom.BuildFilters(page)
    local function Toggle(key, x, labels)
        local btn
        btn = MakeButton(page, 150, "", function()
            ns.db.options[key] = not ns.db.options[key]
            RefreshWindow()
        end)
        btn:SetPoint("BOTTOMLEFT", x, 34)
        btn.Update = function() btn:SetLabel(L[labels[ns.db.options[key] and 2 or 1]]) end
        return btn
    end
    local realm = Toggle("onlyRealm", 16, { "Realm: all", "Realm: this one" })
    local faction = Toggle("onlyFaction", 172, { "Faction: both", "Faction: this one" })
    page.Update = function()
        realm.Update()
        faction.Update()
    end
end

-- pagina sin pestana, desde Opciones
function custom.BuildPage(page)
    local function Header(text, x, y)
        local header = forever.Display(Skin(page:CreateFontString(nil, "OVERLAY", "GameFontNormal"), "header"), 17)
        header:SetPoint("TOPLEFT", x, y)
        header:SetText(L[text])
    end
    local back = MakeButton(page, 100, L["Back"], function() ns.window.ShowTab(OPTIONS_PAGE) end)
    back:SetPoint("TOPRIGHT", -12, -6)

    Header("Tabs", 16, -8)
    local rows = {}
    for i, name in ipairs(TABS) do
        local row = CreateFrame("Frame", nil, page)
        row:SetSize(330, 24)
        local up = MakeButton(row, 22, "^", function() custom.MoveTab(i, -1) end)
        up:SetPoint("LEFT")
        local down = MakeButton(row, 22, "v", function() custom.MoveTab(i, 1) end)
        down:SetPoint("LEFT", up, "RIGHT", 4, 0)
        if name == "Options" then
            local label = Skin(row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"), "dim")
            label:SetPoint("LEFT", down, "RIGHT", 10, 0)
            label:SetText(L["Options"] .. " " .. L["(always shown)"])
        else
            MakeCheck(row, L[name], "showTab" .. name, custom.LayoutTabs):SetPoint("LEFT", down, "RIGHT", 10, 0)
        end
        rows[i] = row
    end

    local function Check(label, key, x, y, onChange)
        MakeCheck(page, L[label], key, onChange):SetPoint("TOPLEFT", x, y)
    end
    Header("Character page", 400, -8)
    for i = 2, #SECTIONS do
        Check(SECTIONS[i][2], "showSection" .. SECTIONS[i][1], 400, -32 - (i - 2) * 22, RefreshWindow)
    end

    Header("Mail", 16, -232)
    Check("Letter icon in the character list", "mailMarker", 16, -256, RefreshWindow)
    Check("Expect mail from ended auctions", "mailFromAuctions", 16, -280, mailbox.Tick)
    Check("Warn about mail that is about to expire", "mailWarning", 16, -304)

    Header("Characters", 400, -232)
    Check("Only characters on this realm", "onlyRealm", 400, -256, RefreshWindow)
    Check("Only characters of this faction", "onlyFaction", 400, -280, RefreshWindow)
    local note = Skin(page:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"), "dim")
    note:SetPoint("TOPLEFT", 400, -306)
    note:SetWidth(320)
    note:SetJustifyH("LEFT")
    note:SetText(L["The filters also apply to tooltips and search. Characters saved before this version need one login to record their faction."])

    page.Update = function()
        for n, i in ipairs(custom.TabOrder()) do
            rows[i]:ClearAllPoints()
            rows[i]:SetPoint("TOPLEFT", 16, -32 - (n - 1) * 26)
        end
    end
end


-- lo que pide atencion, de un vistazo
function custom.Summary(tooltip)
    local expiring, new, ready, money, now = {}, {}, {}, 0, time()
    local list = SortedChars()
    for _, c in ipairs(list) do
        money = money + (c.money or 0)
        local state, left = mailbox.State(c)
        if state == "expiring" then
            table.insert(expiring, format("%s (%s)", ClassColored(c), left > 0 and Duration(left) or L["expired"]))
        elseif state == "new" then
            table.insert(new, ClassColored(c))
        end
        for _, at in pairs(c.cooldowns or {}) do
            if at <= now then
                table.insert(ready, ClassColored(c))
                break
            end
        end
    end
    tooltip:AddDoubleLine(format(L["%d characters"], #list), Money(money), 1, 1, 1, 1, 1, 1)
    if #expiring > 0 then tooltip:AddLine(format(L["Mail about to expire: %s"], table.concat(expiring, ", ")), 1, 0.4, 0.4, true) end
    if #new > 0 then tooltip:AddLine(format(L["New mail: %s"], table.concat(new, ", ")), 0.5, 0.75, 1, true) end
    if #ready > 0 then tooltip:AddLine(format(L["Cooldowns ready: %s"], table.concat(ready, ", ")), 0.4, 0.85, 0.4, true) end
    tooltip:AddLine(" ")
end
