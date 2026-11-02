-- Alters Forever: correo carta a carta, cartas esperadas, avisos y pestana de correo
-- carga despues de AltersForever.lua; db, me y window se leen de ns, que se rellenan al entrar

local _, ns = ...
local mailbox, af = ns.mailbox, ns.af
local L, Say, Money, Duration, ClassColored, ClassIcon = af.L, af.Say, af.Money, af.Duration, af.ClassColored, af.ClassIcon
local SortedChars, ByName, Remember, ItemName, QualityColored = af.SortedChars, af.ByName, af.Remember, af.ItemName, af.QualityColored
local Matches, Skin, MakeTable, RefreshWindow, OpenCharacter = af.Matches, af.Skin, af.MakeTable, af.RefreshWindow, af.OpenCharacter
local ROWS = af.ROWS


-- correo: cada carta con remitente, asunto, objetos, oro, reembolso y caducidad
-- c.mail, mailLetters, mailMoney y mailExpires salen de las cartas, para tooltips y busqueda
function mailbox.Summarize(c)
    if not c.letters then return end
    local counts, gold, soonest = {}, 0, nil
    for _, letter in ipairs(c.letters) do
        gold = gold + (letter.money or 0)
        for _, item in ipairs(letter.items or {}) do
            counts[item[1]] = (counts[item[1]] or 0) + item[2]
        end
        -- solo las que pierden algo al caducar
        if letter.items or (letter.money or 0) > 0 then
            soonest = math.min(soonest or letter.expires, letter.expires)
        end
    end
    c.mail, c.mailMoney, c.mailExpires = counts, gold, soonest
    c.mailLetters = #c.letters + (c.mailHidden or 0)
end

local function InboxItems(index)
    local items
    for a = 1, ATTACHMENTS_MAX_RECEIVE or 16 do
        local _, itemID, _, count = GetInboxItem(index, a)
        if itemID then
            local link = GetInboxItemLink(index, a)
            items = items or {}
            table.insert(items, { itemID, count or 1, link })
            Remember(itemID, link)
        end
    end
    return items
end

-- el buzon solo ensena 50; el resto llega al borrar o vaciar cartas
function mailbox.Scan()
    local shown, total = GetInboxNumItems()
    local letters, now = {}, time()
    for i = 1, shown do
        local _, _, sender, subject, money, cod, daysLeft, hasItem, _, returned = GetInboxHeaderInfo(i)
        table.insert(letters, {
            from = sender, subject = subject, money = money or 0, cod = cod or 0,
            expires = now + math.floor((daysLeft or 0) * 86400),
            returned = returned and true or nil,
            items = hasItem and InboxItems(i) or nil,
        })
    end
    ns.me.letters = letters
    ns.me.mailHidden = math.max((total or shown) - shown, 0)
    ns.me.mailSeen = now
    ns.me.newMail = nil
    -- lo que acabo en la casa de subastas ya esta en este buzon
    mailbox.MarkAuctions(ns.me)
    mailbox.Summarize(ns.me)
end

local function FindAlt(name)
    if not name or name == "" then return end
    local short, realm = strsplit("-", name, 2)
    short = short:lower()
    for _, c in pairs(ns.db.chars) do
        if c ~= ns.me and c.name and c.name:lower() == short
            and (not realm or not c.realm or c.realm:gsub("[%s']", "") == realm:gsub("[%s']", "")) then
            return c
        end
    end
end

-- se apunta al enviarse como carta esperada; el buzon del alt la corrige
function mailbox.Deliver(c, letter)
    c.letters = c.letters or {}
    table.insert(c.letters, letter)
    c.newMail = true
    mailbox.Summarize(c)
end

function mailbox.Watch()
    hooksecurefunc("SendMail", function(recipient, subject)
        local c = FindAlt(recipient)
        if not c then mailbox.outgoing = nil return end
        local items
        for a = 1, ATTACHMENTS_MAX_SEND or 12 do
            local _, itemID, _, count = GetSendMailItem(a)
            if itemID then
                local link = GetSendMailItemLink(a)
                items = items or {}
                table.insert(items, { itemID, count or 1, link })
                Remember(itemID, link)
            end
        end
        local cod = GetSendMailCOD and GetSendMailCOD() or 0
        local now = time()
        mailbox.outgoing = { c = c, letter = {
            from = ns.me.name, subject = subject, money = GetSendMailMoney() or 0, cod = cod, items = items,
            expires = now + (cod > 0 and mailbox.COD_DAYS or mailbox.DAYS) * 86400, expected = "sent", at = now,
        } }
    end)

    -- devuelta a uno de los tuyos: le llega sin reembolso y con 30 dias
    hooksecurefunc("ReturnInboxItem", function(index)
        local _, _, sender, subject, money = GetInboxHeaderInfo(index)
        local c = FindAlt(sender)
        if not c then return end
        local now = time()
        mailbox.Deliver(c, {
            from = ns.me.name, subject = subject, money = money or 0, cod = 0, items = InboxItems(index),
            expires = now + mailbox.DAYS * 86400, returned = true, expected = "returned", at = now,
        })
    end)
end

-- datos de antes de 1.34: sin cartas, solo totales; quedan como una carta antigua
function mailbox.Upgrade(c)
    if c.letters or (c.mailLetters or 0) == 0 then return end
    local items
    for id, count in pairs(c.mail or {}) do
        items = items or {}
        table.insert(items, { id, count })
    end
    c.letters = { {
        from = "?", money = c.mailMoney or 0, cod = 0, items = items,
        expires = c.mailExpires or (time() + mailbox.DAYS * 86400), expected = "old",
    } }
    c.mailHidden = math.max(c.mailLetters - 1, 0)
    mailbox.Summarize(c)
end


-- subasta -> carta: [7] marca la subasta que ya dio su carta

-- las vendidas siguen en la lista en la siguiente lectura: conservan la marca
function mailbox.CarryMarks(old, list)
    local marked = {}
    for _, auction in ipairs(old or {}) do
        if auction[6] and auction[7] then table.insert(marked, auction) end
    end
    for _, auction in ipairs(list) do
        if auction[6] then
            for i, other in ipairs(marked) do
                if other[1] == auction[1] and other[3] == auction[3] and other[4] == auction[4] then
                    auction[7] = true
                    table.remove(marked, i)
                    break
                end
            end
        end
    end
end

function mailbox.MarkAuctions(c)
    local now = time()
    for _, auction in ipairs(c.auctions or {}) do
        if auction[6] or auction[5] <= now then auction[7] = true end
    end
end

-- vendida: llega el oro; acabada sin verla vendida: vuelve el objeto, o el oro si se vendio
-- el tiempo guardado es el maximo del tramo, asi que pasado ese tiempo seguro que acabo
function mailbox.CheckAuctions(c)
    if not ns.db.options.mailFromAuctions then return end
    local now, changed = time(), false
    for _, auction in ipairs(c.auctions or {}) do
        if not auction[7] and (auction[6] or auction[5] <= now) then
            auction[7] = true
            local id, link, count, price = auction[1], auction[2], auction[3], auction[4]
            local name = (link and link:match("%[(.-)%]")) or ns.db.names[id] or C_Item.GetItemNameByID(id) or ("item:" .. id)
            local letter = { from = L["Auction House"], cod = 0, money = 0,
                expires = now + mailbox.DAYS * 86400, expected = "auction", at = now }
            if auction[6] then
                letter.subject = format(L["Sold: %s"], name)
                letter.money = math.floor(price * count * (1 - mailbox.AH_CUT))
                letter.estimate = true
            else
                letter.subject = format(L["Ended: %s"], name)
                letter.items = { { id, count, link } }
                letter.maybeSold = true
                -- ya no esta en la casa de subastas
                if c.ah and c.ah[id] then
                    c.ah[id] = c.ah[id] - count
                    if c.ah[id] <= 0 then c.ah[id] = nil end
                end
            end
            c.letters = c.letters or {}
            table.insert(c.letters, letter)
            c.newMail = true
            changed = true
        end
    end
    if changed then mailbox.Summarize(c) end
end

-- "expiring" si caduca algo en menos de 3 dias, "new" si hay carta nueva
function mailbox.State(c)
    local left = c.mailExpires and c.mailExpires - time()
    if left and (c.mailLetters or 0) > 0 and left < mailbox.WARNING_DAYS * 86400 then return "expiring", left end
    if c.newMail then return "new" end
end

-- una vez por sesion, y otra cuando queda menos de un dia
function mailbox.Warn()
    if not ns.db.options.mailWarning then return end
    for _, c in pairs(ns.db.chars) do
        local state, left = mailbox.State(c)
        if state == "expiring" then
            local key = c.mailExpires .. (left < 86400 and "!" or "")
            if mailbox.warned[c] ~= key then
                mailbox.warned[c] = key
                if left > 0 then
                    Say("%s has mail that expires in %s.", ClassColored(c), Duration(left))
                else
                    Say("%s had mail that may have expired.", ClassColored(c))
                end
            end
        end
    end
end

function mailbox.Tick()
    for _, c in pairs(ns.db.chars) do mailbox.CheckAuctions(c) end
    mailbox.Warn()
    RefreshWindow()
end

-- carta roja: algo caduca pronto; azul: correo nuevo
function mailbox.Marker(c)
    if not ns.db.options.mailMarker then return "" end
    local state = mailbox.State(c)
    if state == "expiring" then return " |TInterface\\Icons\\INV_Letter_15:13:13:0:0:64:64:5:59:5:59:255:90:90|t" end
    if state == "new" then return " |TInterface\\Icons\\INV_Letter_15:13:13:0:0:64:64:5:59:5:59:120:180:255|t" end
    return ""
end

-- una carta en una linea: el primer objeto, o el asunto si no trae objetos
function mailbox.Contents(letter)
    local prefix = letter.returned and ("|cffff9933" .. L["Returned"] .. ":|r ") or ""
    local first = letter.items and letter.items[1]
    if not first then return prefix .. (letter.subject or "") end
    local id, count, link = first[1], first[2], first[3]
    local name = (link and link:match("%[(.-)%]")) or ItemName(id) or ("item:" .. id)
    local text = format("|T%s:14:14|t %s%s", C_Item.GetItemIconByID(id) or 134400, QualityColored(id, name), count > 1 and (" x" .. count) or "")
    if #letter.items > 1 then text = text .. " |cff999999" .. format(L["+%d more"], #letter.items - 1) .. "|r" end
    return prefix .. text
end

function mailbox.MoneyText(letter)
    if (letter.cod or 0) > 0 then return "|cffff5050" .. L["COD"] .. "|r " .. Money(letter.cod) end
    if (letter.money or 0) > 0 then return (letter.estimate and "~" or "") .. Money(letter.money) end
    return ""
end

function mailbox.ExpiresText(letter)
    local left = letter.expires - time()
    if left <= 0 then return "|cff999999" .. L["expired"] .. "|r" end
    local text = (letter.expected and "~" or "") .. Duration(left)
    if left < mailbox.WARNING_DAYS * 86400 and (letter.items or (letter.money or 0) > 0) then
        return "|cffff5050" .. text .. "|r"
    end
    return text
end

function mailbox.Sorted(c)
    local letters = {}
    for _, letter in ipairs(c.letters or {}) do table.insert(letters, letter) end
    table.sort(letters, function(a, b) return a.expires < b.expires end)
    return letters
end

-- en la ficha, con el filtro Correo
function mailbox.Rows(c)
    local rows = {}
    if not c.letters then return rows end
    local seen = c.mailSeen and ("  |cff999999" .. format(L["(seen %s ago)"], Duration(time() - c.mailSeen)) .. "|r") or ""
    table.insert(rows, { header = L["Letters"] .. seen })
    for _, letter in ipairs(mailbox.Sorted(c)) do
        local from = letter.expected and ("|cff999999" .. (letter.from or "?") .. "|r") or (letter.from or "?")
        local first = letter.items and letter.items[1]
        table.insert(rows, { mailbox.Contents(letter) .. "  |cff999999- " .. from .. "|r", mailbox.MoneyText(letter),
            mailbox.ExpiresText(letter), item = first and (first[3] or first[1]) })
    end
    if (c.mailHidden or 0) > 0 then
        table.insert(rows, { "|cff999999" .. format(L["%d more letters the game does not show yet"], c.mailHidden) .. "|r" })
    end
    if c.newMail then table.insert(rows, { "|cff80c0ff" .. L["New mail since the last mailbox visit"] .. "|r" }) end
    return rows
end

-- pestana de correo: todas las cartas, la que caduca antes primero

function mailbox.Matches(letter, query)
    if query == "" then return true end
    -- remitente y asunto solo con un nombre; un filtro (boe, >50, !x) mira los objetos
    if not ns.search.IsFilter(query) then
        for _, text in ipairs({ letter.from or "", letter.subject or "" }) do
            if text:lower():find(query, 1, true) then return true end
        end
    end
    for _, item in ipairs(letter.items or {}) do
        if Matches(item[1], query) then return true end
    end
    return false
end

function mailbox.List(query)
    local list = {}
    query = strtrim(query or ""):lower()
    for _, c in ipairs(SortedChars()) do
        for _, letter in ipairs(c.letters or {}) do
            if mailbox.Matches(letter, query) then table.insert(list, { c = c, letter = letter }) end
        end
        if (c.mailHidden or 0) > 0 and query == "" then table.insert(list, { c = c, hidden = c.mailHidden }) end
    end
    table.sort(list, function(a, b)
        local x, y = a.letter and a.letter.expires or math.huge, b.letter and b.letter.expires or math.huge
        if x == y then return ByName(a.c) < ByName(b.c) end
        return x < y
    end)
    return list
end

function mailbox.Fill(cells, entry)
    cells.name:SetText(ClassIcon(entry.c) .. ClassColored(entry.c))
    local letter = entry.letter
    if not letter then
        cells.what:SetText("|cff999999" .. format(L["%d more letters the game does not show yet"], entry.hidden) .. "|r")
        return
    end
    cells.from:SetText(letter.expected and ("|cff999999" .. (letter.from or "?") .. "|r") or (letter.from or "?"))
    cells.what:SetText(mailbox.Contents(letter))
    cells.money:SetText(mailbox.MoneyText(letter))
    cells.expires:SetText(mailbox.ExpiresText(letter))
end

mailbox.EXPECTED = {
    sent     = "Sent by %s; not seen in this mailbox yet.",
    returned = "Returned by %s; not seen in this mailbox yet.",
    old      = "Saved by an older version. Open the mailbox to read the letters one by one.",
}

function mailbox.Tooltip(entry)
    local c, letter = entry.c, entry.letter
    GameTooltip:AddLine(ClassColored(c))
    if not letter then
        GameTooltip:AddLine(L["The mailbox shows 50 letters at a time. Take or delete letters to see the rest."], 1, 1, 1, true)
        return
    end
    GameTooltip:AddDoubleLine(L["From"], letter.from or "?", 1, 0.82, 0, 1, 1, 1)
    if letter.subject and letter.subject ~= "" then GameTooltip:AddLine(letter.subject, 1, 1, 1, true) end
    for _, item in ipairs(letter.items or {}) do
        local id, count, link = item[1], item[2], item[3]
        local name = (link and link:match("%[(.-)%]")) or ItemName(id) or ("item:" .. id)
        GameTooltip:AddDoubleLine(format("|T%s:14:14|t %s", C_Item.GetItemIconByID(id) or 134400, QualityColored(id, name)), "x" .. count, 1, 1, 1, 1, 1, 1)
    end
    if (letter.money or 0) > 0 then GameTooltip:AddDoubleLine(L["Gold"], Money(letter.money), 1, 0.82, 0, 1, 1, 1) end
    if (letter.cod or 0) > 0 then
        GameTooltip:AddDoubleLine(L["COD"], Money(letter.cod), 1, 0.3, 0.3, 1, 1, 1)
        GameTooltip:AddLine(L["Not paid in time, it goes back to the sender."], 0.6, 0.6, 0.6, true)
    end
    local left = letter.expires - time()
    GameTooltip:AddLine(left > 0 and format(L["expires in %s"], Duration(left)) or L["expired"], 1, 1, 1)
    if letter.returned then GameTooltip:AddLine(L["Returned: deleted when it expires."], 1, 0.6, 0.2, true) end
    if letter.expected == "auction" then
        if letter.estimate then
            GameTooltip:AddLine(L["From a sold auction; the gold is an estimate after the auction house cut."], 0.6, 0.6, 0.6, true)
        else
            GameTooltip:AddLine(L["From an auction that ended: the item comes back, or the gold if it sold."], 0.6, 0.6, 0.6, true)
        end
    elseif letter.expected then
        GameTooltip:AddLine(format(L[mailbox.EXPECTED[letter.expected]], letter.from or "?"), 0.6, 0.6, 0.6, true)
    end
    if c.mailSeen then GameTooltip:AddLine(format(L["Mailbox seen %s ago"], Duration(time() - c.mailSeen)), 0.6, 0.6, 0.6) end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(L["Left click: open the character"], 0.6, 0.6, 0.6)
end

function mailbox.BuildPage(page)
    local search = CreateFrame("EditBox", nil, page, "InputBoxTemplate")
    search:SetSize(240, 20)
    search:SetPoint("TOPLEFT", 22, -6)
    search:SetAutoFocus(false)
    search:SetScript("OnEscapePressed", search.ClearFocus)
    search:SetScript("OnEnterPressed", search.ClearFocus)
    local hint = Skin(page:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"), "dim")
    hint:SetPoint("LEFT", search, "RIGHT", 12, 0)
    hint:SetText(L["Sender, subject or item"])

    local list = MakeTable(page, {
        { key = "name",    title = "Character", x = 4,   width = 130, sort = function(e) return ByName(e.c) end },
        { key = "from",    title = "From",      x = 138, width = 110, sort = function(e) return (e.letter and e.letter.from or ""):lower() end },
        { key = "what",    title = "Contents",  x = 252, width = 270 },
        { key = "money",   title = "Gold",      x = 526, width = 100, justify = "RIGHT",
          sort = function(e) return e.letter and math.max(e.letter.money or 0, e.letter.cod or 0) or 0 end, desc = true },
        { key = "expires", title = "Expires",   x = 630, width = 82, justify = "RIGHT",
          sort = function(e) return e.letter and e.letter.expires or math.huge end },
    }, -34, ROWS - 1)
    list.id = "mail"
    list.source = function() return mailbox.List(search:GetText()) end
    list.fill = mailbox.Fill
    list.onEnter = mailbox.Tooltip
    list.onClick = function(entry, mouse)
        if mouse ~= "LeftButton" then return end
        OpenCharacter(entry.c)
        ns.window.filter = "mail"
        RefreshWindow()
    end
    search:SetScript("OnTextChanged", function()
        list.offset = 0
        list:Refresh()
    end)

    local empty = Skin(page:CreateFontString(nil, "OVERLAY", "GameFontNormal"), "dim")
    empty:SetPoint("TOP", 0, -140)
    empty:SetWidth(520)
    empty:SetText(L["No mail yet. Open a mailbox with each character to read its letters."])
    local footer = Skin(page:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"), "dim")
    footer:SetPoint("BOTTOMLEFT", 16, 14)
    list.after = function(entries)
        local letters, money, owners = 0, 0, {}
        for _, entry in ipairs(entries) do
            if entry.letter then
                letters = letters + 1
                money = money + (entry.letter.money or 0)
                owners[entry.c] = true
            end
        end
        local count = 0
        for _ in pairs(owners) do count = count + 1 end
        empty:SetShown(#entries == 0 and strtrim(search:GetText() or "") == "")
        footer:SetText(format(L["%d letters on %d characters, %s in mail"], letters, count, Money(money))
            .. "    |cff999999~ " .. L["expected, not seen in the mailbox yet"] .. "|r")
    end
    page.table = list
end
