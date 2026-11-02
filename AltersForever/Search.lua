-- Alters Forever: busqueda de objetos, con filtros
-- carga antes de AltersForever.lua, que pone search.ItemName y llama a search.Matches
--
--   linen              parte del nombre, y nada mas
--   #boe #epic #head   palabra clave: tipo, subtipo, hueco, calidad o ligado del objeto
--   #cloth armor       subtipo y tipo juntos: la tela de Linen Cloth es "Trade Goods", "Cloth"
--   >50  <20  10-20    nivel de objeto (>=, <= y =50 tambien)
--   a & b   a | b   !a     y, o, no; & va antes que |

local _, ns = ...

local search = {}
ns.search = search

-- las palabras del juego si las hay; las inglesas siempre, para quien escribe en ingles
local QUALITY_WORDS = { [0] = "poor", "common", "uncommon", "rare", "epic", "legendary", "artifact", "heirloom" }
local QUALITY_ALIASES = { junk = 0, grey = 0, gray = 0, white = 1, green = 2, blue = 3, purple = 4, orange = 5 }
local BIND_WORDS = { "bop", "boe", "bou", "quest" }
local SLOT_WORDS = {
    INVTYPE_HEAD = "head", INVTYPE_NECK = "neck", INVTYPE_SHOULDER = "shoulder", INVTYPE_BODY = "shirt",
    INVTYPE_CHEST = "chest", INVTYPE_ROBE = "chest", INVTYPE_WAIST = "waist", INVTYPE_LEGS = "legs",
    INVTYPE_FEET = "feet", INVTYPE_WRIST = "wrist", INVTYPE_HAND = "hands", INVTYPE_FINGER = "finger",
    INVTYPE_TRINKET = "trinket", INVTYPE_CLOAK = "back", INVTYPE_WEAPON = "one-hand", INVTYPE_SHIELD = "shield",
    INVTYPE_2HWEAPON = "two-hand", INVTYPE_WEAPONMAINHAND = "main hand", INVTYPE_WEAPONOFFHAND = "off hand",
    INVTYPE_HOLDABLE = "held in off-hand", INVTYPE_RANGED = "ranged", INVTYPE_RANGEDRIGHT = "ranged",
    INVTYPE_THROWN = "thrown", INVTYPE_RELIC = "relic", INVTYPE_TABARD = "tabard", INVTYPE_BAG = "bag",
    INVTYPE_QUIVER = "quiver", INVTYPE_AMMO = "ammo",
}
local SLOT_ALIASES = { ring = "finger", cloak = "back", gloves = "hands", boots = "feet", belt = "waist", ["2h"] = "two-hand", ["1h"] = "one-hand" }

-- lo que el juego sabe del objeto; nil hasta que el cliente lo tiene
local infos = {}
local misses = {}            -- veces que se pidio sin llegar; un objeto borrado no llega nunca
local MAX_MISSES = 3
search.waiting = false       -- alguna busqueda pidio un objeto que no habia llegado

local function AddWords(set, text)
    if type(text) ~= "string" or text == "" then return end
    text = text:lower()
    set[text] = true
    -- "food & drink" vale tambien por "food" y por "drink"
    for word in text:gmatch("[^%s&,/]+") do
        if #word >= 4 then set[word] = true end
    end
end

function search.Info(id)
    local info = infos[id]
    if info then return info end
    if not (C_Item and C_Item.GetItemInfo) then return nil end
    local name, _, quality, level, _, itemType, subType, _, equipLoc, _, _, _, _, bindType = C_Item.GetItemInfo(id)
    if not name then
        local n = (misses[id] or 0) + 1
        misses[id] = n
        if n <= MAX_MISSES then search.waiting = true end
        return nil
    end
    misses[id] = nil
    local words = {}
    AddWords(words, itemType)
    AddWords(words, subType)
    if type(itemType) == "string" and type(subType) == "string" and subType ~= itemType then
        words[(subType .. " " .. itemType):lower()] = true
    end
    -- lo que no se equipa trae "" o INVTYPE_NON_EQUIP_IGNORE: sin hueco ni gear
    if SLOT_WORDS[equipLoc] then
        AddWords(words, SLOT_WORDS[equipLoc])
        AddWords(words, _G[equipLoc])
        if equipLoc ~= "INVTYPE_BAG" and equipLoc ~= "INVTYPE_QUIVER" and equipLoc ~= "INVTYPE_AMMO" then
            words.gear = true
        end
    end
    if quality then
        AddWords(words, QUALITY_WORDS[quality])
        AddWords(words, _G["ITEM_QUALITY" .. quality .. "_DESC"])
    end
    if bindType and BIND_WORDS[bindType] then words[BIND_WORDS[bindType]] = true end
    info = { level = level or 0, quality = quality, words = words }
    infos[id] = info
    return info
end

-- ---------------------------------------------------------------- terminos

local function LevelTest(term)
    local op, n = term:match("^([<>]=?)%s*(%d+)$")
    if not op then
        n = term:match("^=%s*(%d+)$")
        if n then op = "=" end
    end
    if op then
        n = tonumber(n)
        if op == "<" then return function(l) return l < n end end
        if op == "<=" then return function(l) return l <= n end end
        if op == ">" then return function(l) return l > n end end
        if op == ">=" then return function(l) return l >= n end end
        return function(l) return l == n end
    end
    local a, b = term:match("^(%d+)%s*%-%s*(%d+)$")
    if a then
        a, b = tonumber(a), tonumber(b)
        if a > b then a, b = b, a end
        return function(l) return l >= a and l <= b end
    end
end

-- cada prueba da true, false, o nil si el objeto no tiene datos aun y el nombre no basta;
-- asi !epic no encaja con un objeto sin datos: sin ellos solo cuenta el nombre

-- una palabra clave con #: solo los datos del objeto, nunca el nombre
local function Keyword(word)
    local quality = QUALITY_ALIASES[word]
    local slot = SLOT_ALIASES[word]
    return function(id)
        local info = search.Info(id)
        if not info then return nil end
        if info.words[word] then return true end
        if quality and info.quality == quality then return true end
        return slot ~= nil and info.words[slot] == true
    end
end

-- un termino suelto: nivel de objeto, #palabra clave, o parte del nombre
local function Term(term)
    local level = LevelTest(term)
    if level then
        return function(id)
            local info = search.Info(id)
            if not info then return nil end
            return level(info.level)
        end
    end
    if term:sub(1, 1) == "#" then
        local word = strtrim(term:sub(2))
        if word == "" then return nil end
        return Keyword(word)
    end
    return function(id)
        local name = search.ItemName and search.ItemName(id)
        if not name then return nil end
        return name:lower():find(term, 1, true) ~= nil
    end
end

local function Not(test)
    return function(id)
        local r = test(id)
        if r == nil then return nil end
        return not r
    end
end

local function All(tests)
    if #tests == 1 then return tests[1] end
    return function(id)
        local unknown = false
        for _, test in ipairs(tests) do
            local r = test(id)
            if r == false then return false end
            if r == nil then unknown = true end
        end
        if unknown then return nil end
        return true
    end
end

local function Any(tests)
    if #tests == 1 then return tests[1] end
    return function(id)
        local unknown = false
        for _, test in ipairs(tests) do
            local r = test(id)
            if r then return true end
            if r == nil then unknown = true end
        end
        if unknown then return nil end
        return false
    end
end

-- nil si la busqueda esta vacia: entonces vale todo
local compiled, numCompiled = {}, 0
function search.Compile(query)
    query = strtrim(query or ""):lower()
    if query == "" then return nil end
    local test = compiled[query]
    if test then return test end
    -- cada letra tecleada es una busqueda nueva; que no crezca sin fin
    if numCompiled >= 200 then wipe(compiled); numCompiled = 0 end
    local ors = {}
    for part in (query .. "|"):gmatch("([^|]*)|") do
        local ands = {}
        for term in (part .. "&"):gmatch("([^&]*)&") do
            term = strtrim(term)
            local negate = false
            while term:sub(1, 1) == "!" do
                negate = not negate
                term = strtrim(term:sub(2))
            end
            local t = term ~= "" and Term(term)
            if t then table.insert(ands, negate and Not(t) or t) end
        end
        if #ands > 0 then table.insert(ors, All(ands)) end
    end
    if #ors == 0 then return nil end
    test = Any(ors)
    compiled[query] = test
    numCompiled = numCompiled + 1
    return test
end

function search.Matches(id, query)
    local test = search.Compile(query)
    return test == nil or test(id) == true
end

-- una busqueda con filtros, no solo un nombre: el correo no la mira en remitente ni asunto
function search.IsFilter(query)
    query = strtrim(query or ""):lower()
    if query:find("[&|#]") or query:sub(1, 1) == "!" then return true end
    return LevelTest(query) ~= nil
end
