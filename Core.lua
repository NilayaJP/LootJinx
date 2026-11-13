-- LootJinx – Kern: Datenbank, Helfer, Item-Erkennung
local ADDON, ns = ...
local LJ = ns or _G.LootJinx or {}
_G.LootJinx = LJ
LJ.name = ADDON or "LootJinx"

-- ---------------------------------------------------------------- Farben
LJ.COLORS = {
    bg          = { 0.035, 0.040, 0.055, 0.97 },
    card        = { 0.075, 0.082, 0.105, 0.94 },
    cardHover   = { 0.105, 0.112, 0.145, 0.96 },
    border      = { 0.190, 0.200, 0.250, 1.00 },
    borderHot   = { 0.470, 0.300, 0.560, 1.00 },
    accent      = { 0.800, 0.360, 0.920, 1.00 },
    accentDark  = { 0.420, 0.160, 0.520, 1.00 },
    cyan        = { 0.300, 0.740, 0.960, 1.00 },
    gold        = { 1.000, 0.820, 0.300, 1.00 },
    green       = { 0.360, 0.860, 0.520, 1.00 },
    red         = { 0.960, 0.360, 0.430, 1.00 },
    orange      = { 0.980, 0.580, 0.280, 1.00 },
    text        = { 0.920, 0.930, 0.960, 1.00 },
    muted       = { 0.590, 0.610, 0.680, 1.00 },
    dim         = { 0.400, 0.420, 0.490, 1.00 },
    track       = { 0.120, 0.125, 0.155, 1.00 },
}

-- ---------------------------------------------------------------- Helfer
local function Plain(v)
    if type(issecretvalue) == "function" and issecretvalue(v) then return nil end
    return v
end
LJ.Plain = Plain

function LJ.Now()
    local t = GetServerTime and GetServerTime()
    t = Plain(t)
    if type(t) == "number" and t > 0 then return t end
    return time and time() or 0
end

function LJ:FormatNumber(n)
    n = tonumber(n) or 0
    local fn = BreakUpLargeNumbers
    if type(fn) == "function" then
        local ok, v = pcall(fn, n)
        v = ok and Plain(v)
        if type(v) == "string" then return v end
    end
    return tostring(n)
end

function LJ:Print(msg, ...)
    if select("#", ...) > 0 then
        local ok, formatted = pcall(string.format, tostring(msg), ...)
        if ok then msg = formatted end
    end
    print("|cffcf5cf0LootJinx:|r " .. tostring(msg))
end

-- Version aus der .toc, damit Chat-Meldungen und Einstellungen immer zum
-- tatsächlich geladenen Stand passen.
function LJ:AddOnVersion()
    local getter = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    if type(getter) == "function" then
        local ok, version = pcall(getter, "LootJinx", "Version")
        if ok and type(version) == "string" and version ~= "" then return version end
    end
    return "1.3.0"
end

local function normalizeBoss(b, fallbackAt)
    if type(b) ~= "table" then return nil end
    local id = tonumber(b.id)
    local name = type(b.name) == "string" and b.name or nil
    if not id and not name then return nil end
    return {
        id = id and id > 0 and id or nil,
        name = name,
        at = tonumber(b.at) or fallbackAt or 0,
    }
end

local function normalizeDrop(d, fallbackAt)
    if type(d) ~= "table" then return nil end
    local link = type(d.link) == "string" and d.link or nil
    local id = tonumber(d.id) or (link and LJ:ItemID(link)) or nil
    if not id then return nil end
    local bossID = tonumber(d.bossID)
    if bossID and bossID <= 0 then bossID = nil end
    local winner = type(d.winner) == "string" and d.winner or nil
    local kind = d.rollKind
    if kind ~= "need" and kind ~= "greed" then kind = nil end
    return {
        id = id,
        link = link,
        bossID = bossID,
        bossName = type(d.bossName) == "string" and d.bossName or nil,
        at = tonumber(d.at) or fallbackAt or 0,
        winner = winner,
        winnerClass = type(d.winnerClass) == "string" and d.winnerClass or nil,
        roll = tonumber(d.roll),
        rollKind = kind,
        passed = d.passed == true,
        source = type(d.source) == "string" and d.source or nil,
    }
end

local function normalizeRoll(r, fallbackAt)
    if type(r) ~= "table" then return nil end
    local id = tonumber(r.id)
    local value = tonumber(r.value)
    local name = type(r.name) == "string" and r.name or nil
    if not id or not value or not name then return nil end
    local kind = r.kind
    if kind ~= "need" and kind ~= "greed" then kind = "need" end
    return {
        id = id,
        name = name,
        kind = kind,
        value = value,
        at = tonumber(r.at) or fallbackAt or 0,
    }
end

function LJ:RegisterRefresh(fn)
    if type(fn) ~= "function" then return end
    self.listeners = self.listeners or {}
    self.listeners[#self.listeners + 1] = fn
end

function LJ:Changed()
    if self._changing then return end
    self._changing = true
    local list = self.listeners
    if list then
        for i = 1, #list do
            pcall(list[i])
        end
    end
    self._changing = false
end

-- ---------------------------------------------------------------- Datenbank
local function normalizeNeed(n, fallbackAt)
    if type(n) ~= "table" then return nil end
    n.at = tonumber(n.at) or fallbackAt or 0
    n.id = tonumber(n.id)
    n.rollID = tonumber(n.rollID)
    n.before = tonumber(n.before) or 0
    n.link = type(n.link) == "string" and n.link or nil
    n.result = (n.result == "won" or n.result == "lost") and n.result or nil
    n.resolvedAt = tonumber(n.resolvedAt)
    n.reason = type(n.reason) == "string" and n.reason or nil
    n.roll = tonumber(n.roll)
    n.rollKind = (n.rollKind == "need" or n.rollKind == "greed") and n.rollKind or nil
    return n
end

local function normalizeRun(run, fallbackID)
    if type(run) ~= "table" then return nil end
    run.id = tonumber(run.id) or fallbackID or 0
    run.name = type(run.name) == "string" and run.name or ""
    run.key = type(run.key) == "string" and run.key or nil
    run.instanceID = tonumber(run.instanceID)
    run.zoneID = tonumber(run.zoneID)
    run.difficulty = type(run.difficulty) == "string" and run.difficulty or nil
    run.started = tonumber(run.started) or 0
    run.lastSeen = tonumber(run.lastSeen) or run.started
    run.outsideAt = tonumber(run.outsideAt)
    run.paused = run.paused == true
    run.ended = tonumber(run.ended)
    run.lootSeen = run.lootSeen == true
    run.agilityDropped = run.agilityDropped == true
    run.itemsSeen = tonumber(run.itemsSeen) or 0
    run.agiItemsSeen = tonumber(run.agiItemsSeen) or 0
    run.agilityLink = type(run.agilityLink) == "string" and run.agilityLink or nil
    run.agilityAt = tonumber(run.agilityAt)
    run.closed = run.closed == true
    run.closedReason = type(run.closedReason) == "string" and run.closedReason or nil
    run.partial = run.partial == true

    -- Runs, die vor Version 1.3.0 aufgezeichnet wurden, tragen keinen
    -- Detailmarker. Für sie lassen sich keine Bosse und Empfänger anzeigen.
    -- Der Marker ist die Quelle der Wahrheit: legacy wird bei jedem Start
    -- neu daraus abgeleitet, damit ein falsch gespeichertes Kennzeichen
    -- (z. B. aus einer älteren Erkennungslogik) korrigiert wird.
    run.legacy = (run.detailVersion == nil) == true

    local seen = type(run.seenLinks) == "table" and run.seenLinks or {}
    run.seenLinks = seen

    local needs = type(run.needs) == "table" and run.needs or {}
    local cleanNeeds = {}
    for i = 1, #needs do
        local n = normalizeNeed(needs[i], run.started)
        if n then cleanNeeds[#cleanNeeds + 1] = n end
    end
    run.needs = cleanNeeds

    local pending = type(run.pending) == "table" and run.pending or {}
    local cleanPending = {}
    for i = 1, #pending do
        local p = pending[i]
        if type(p) == "table" and type(p.link) == "string" then
            p.id = tonumber(p.id) or LJ:ItemID(p.link)
            p.added = tonumber(p.added) or run.started
            p.countedLoot = p.countedLoot == true
            if p.id then cleanPending[#cleanPending + 1] = p end
        end
    end
    run.pending = cleanPending

    local greeds = type(run.greeds) == "table" and run.greeds or {}
    local cleanGreeds = {}
    for i = 1, #greeds do
        local g = greeds[i]
        if type(g) == "table" then
            g.at = tonumber(g.at) or 0
            g.id = tonumber(g.id)
            g.link = type(g.link) == "string" and g.link or nil
            g.rollID = tonumber(g.rollID)
            if g.at > 0 then cleanGreeds[#cleanGreeds + 1] = g end
        end
    end
    run.greeds = cleanGreeds

    local bosses = type(run.bosses) == "table" and run.bosses or {}
    local cleanBosses = {}
    for i = 1, #bosses do
        local boss = normalizeBoss(bosses[i], run.started)
        if boss then cleanBosses[#cleanBosses + 1] = boss end
    end
    while #cleanBosses > 20 do table.remove(cleanBosses, 1) end
    run.bosses = cleanBosses

    local drops = type(run.drops) == "table" and run.drops or {}
    local cleanDrops = {}
    for i = 1, #drops do
        local drop = normalizeDrop(drops[i], run.started)
        if drop then cleanDrops[#cleanDrops + 1] = drop end
    end
    while #cleanDrops > 120 do table.remove(cleanDrops, 1) end
    run.drops = cleanDrops

    local rolls = type(run.rolls) == "table" and run.rolls or {}
    local cleanRolls = {}
    for i = 1, #rolls do
        local roll = normalizeRoll(rolls[i], run.started)
        if roll then cleanRolls[#cleanRolls + 1] = roll end
    end
    while #cleanRolls > 200 do table.remove(cleanRolls, 1) end
    run.rolls = cleanRolls
    return run
end

function LJ:InitDB()
    local db = _G.LootJinxDB
    if type(db) ~= "table" then
        db = {}
        _G.LootJinxDB = db
    end
    db.version = 1
    db.scale = tonumber(db.scale) or 1.0
    if db.scale < 0.80 then db.scale = 0.80 end
    if db.scale > 1.30 then db.scale = 1.30 end
    db.point = type(db.point) == "string" and db.point or "CENTER"
    db.x = tonumber(db.x) or 0
    db.y = tonumber(db.y) or -40
    db.seenWelcome = db.seenWelcome == true
    db.locked = db.locked == true
    db.showWelcome = db.showWelcome == true
    db.showWatermark = db.showWatermark ~= false
    db.compact = db.compact == true
    db.minimapAngle = tonumber(db.minimapAngle) or 225
    if db.minimapAngle ~= db.minimapAngle then db.minimapAngle = 225 end
    db.minimapAngle = db.minimapAngle % 360
    self.DB = db

    local char = _G.LootJinxCharDB
    if type(char) ~= "table" then
        char = {}
        _G.LootJinxCharDB = char
    end
    char.version = 2
    char.nextRunID = tonumber(char.nextRunID) or 1
    if char.nextRunID < 1 then char.nextRunID = 1 end

    local runs = type(char.runs) == "table" and char.runs or {}
    local cleanRuns = {}
    local maxID = 0
    for i = 1, #runs do
        local run = normalizeRun(runs[i], i)
        if run then
            cleanRuns[#cleanRuns + 1] = run
            if run.id > maxID then maxID = run.id end
        end
    end
    char.runs = cleanRuns
    if char.nextRunID <= maxID then char.nextRunID = maxID + 1 end

    char.activeID = tonumber(char.activeID)
    if char.activeID then
        local found = false
        for i = 1, #cleanRuns do
            if cleanRuns[i].id == char.activeID then found = true break end
        end
        if not found then char.activeID = nil end
    end

    self.CharDB = char
    self.dbReady = true
    self.debugItems = self.debugItems or {}
end

function LJ:ResetChar()
    local char = self.CharDB
    if not char then return end
    char.runs = {}
    char.activeID = nil
    char.nextRunID = 1
    self.debugItems = {}
    self:Changed()
end

-- ---------------------------------------------------------------- Charakter
function LJ:ClassName()
    local ok, name, classFile = pcall(UnitClass, "player")
    name, classFile = ok and Plain(name) or nil, ok and Plain(classFile) or nil
    return type(name) == "string" and name or self.L("UNKNOWN_CLASS"),
        type(classFile) == "string" and classFile or nil
end

function LJ:PlayerName()
    local ok, name, realm = pcall(UnitName, "player")
    name, realm = ok and Plain(name) or nil, ok and Plain(realm) or nil
    if type(name) ~= "string" or name == "" then return nil end
    if type(realm) == "string" and realm ~= "" and not name:find("-", 1, true) then
        name = name .. "-" .. realm
    end
    return name
end

local function nameOnly(name)
    name = Plain(name)
    if type(name) ~= "string" then return nil end
    name = name:lower()
    local dash = name:find("-", 1, true)
    if dash then name = name:sub(1, dash - 1) end
    return name
end

function LJ:IsMe(name)
    name = nameOnly(name)
    if not name then return false end
    local me = nameOnly(self:PlayerName())
    if me and name == me then return true end
    local you = Plain(_G.YOU)
    if type(you) == "string" and name == you:lower() then return true end
    return false
end

-- Primärstat: zuerst die Spezialisierung (C_SpecializationInfo), dann ein
-- Vergleich der Basiswerte über UnitStat, zuletzt der Klassen-Fallback.
-- So stimmen auch Hybridklassen (Druide, Schamane, Paladin, Mönch), deren
-- Primärstat sich je nach Spezialisierung unterscheidet.
local CLASS_STAT = {
    ROGUE = "agility", HUNTER = "agility", DRUID = "agility", SHAMAN = "agility",
    MONK = "agility", DEMONHUNTER = "agility",
    WARRIOR = "strength", PALADIN = "strength", DEATHKNIGHT = "strength",
    MAGE = "intellect", PRIEST = "intellect", WARLOCK = "intellect", EVOKER = "intellect",
}

local STAT_KEYS = {
    agility = { "ITEM_MOD_AGILITY_SHORT", "ITEM_MOD_AGILITY" },
    strength = { "ITEM_MOD_STRENGTH_SHORT", "ITEM_MOD_STRENGTH" },
    intellect = { "ITEM_MOD_INTELLECT_SHORT", "ITEM_MOD_INTELLECT" },
}

local STAT_LABELS = {
    agility = "STAT_AGILITY",
    strength = "STAT_STRENGTH",
    intellect = "STAT_INTELLECT",
}

local STAT_BY_ID = {}
local STAT_IDS = {}
local statIDsReady = false

local function InitStatIDs()
    if statIDsReady then return end
    statIDsReady = true
    local function id(value, fallback)
        value = tonumber(Plain(value))
        if value and value >= 1 and value <= 4 then return value end
        return fallback
    end
    local strength = id(_G.LE_UNIT_STAT_STRENGTH, 1)
    local agility = id(_G.LE_UNIT_STAT_AGILITY, 2)
    local intellect = id(_G.LE_UNIT_STAT_INTELLECT, 4)
    STAT_BY_ID[strength] = "strength"
    STAT_BY_ID[agility] = "agility"
    STAT_BY_ID[intellect] = "intellect"
    STAT_IDS.strength = strength
    STAT_IDS.agility = agility
    STAT_IDS.intellect = intellect
end

local function specIndexFrom(get)
    if type(get) ~= "function" then return nil end
    local ok, index = pcall(get)
    index = ok and tonumber(Plain(index)) or nil
    if index and index > 0 then return index end
    return nil
end

local function currentSpec()
    local api = _G.C_SpecializationInfo
    local index = specIndexFrom(api and api.GetSpecialization)
    if index then return index end
    return specIndexFrom(_G.GetSpecialization)
end

local function specStatFrom(info, index)
    if type(info) ~= "function" then return nil end
    local ok, _, _, _, _, _, statID = pcall(info, index)
    statID = ok and tonumber(Plain(statID)) or nil
    if not statID then return nil end
    InitStatIDs()
    return STAT_BY_ID[statID]
end

local function specStat(index)
    if not index then return nil end
    local api = _G.C_SpecializationInfo
    local stat = specStatFrom(api and api.GetSpecializationInfo, index)
    return stat or specStatFrom(_G.GetSpecializationInfo, index)
end

local function unitStat(stat)
    if type(UnitStat) ~= "function" then return nil end
    InitStatIDs()
    local index = STAT_IDS[stat]
    if not index then return nil end
    local ok, value = pcall(UnitStat, "player", index)
    value = ok and tonumber(Plain(value)) or nil
    if value and value > 0 then return value end
    return nil
end

local function highestUnitStat()
    local best, bestValue
    for stat in pairs(STAT_KEYS) do
        local value = unitStat(stat)
        if value and (not bestValue or value > bestValue) then
            best, bestValue = stat, value
        end
    end
    return best
end

local statCache = { key = nil, stat = nil }

function LJ:PlayerStat()
    local _, classFile = self:ClassName()
    local index = currentSpec()
    local cacheKey = index and (tostring(classFile) .. ":" .. tostring(index)) or nil
    local stat
    if cacheKey and statCache.key == cacheKey then
        stat = statCache.stat
    else
        local exact
        stat = specStat(index)
        exact = stat ~= nil
        if not stat then
            stat = highestUnitStat()
            exact = stat ~= nil
        end
        if not stat then
            stat = classFile and CLASS_STAT[classFile] or nil
        end
        if not stat then stat = "agility" end
        -- Nur eindeutig erkannte Werte cachen: Der Klassen-Fallback bleibt
        -- ungecacht, damit später geladene UnitStat-Werte noch greifen.
        if cacheKey and exact then
            statCache.key, statCache.stat = cacheKey, stat
        end
    end
    local keys = STAT_KEYS[stat]
    local label = keys and _G[keys[1]]
    label = Plain(label)
    if type(label) ~= "string" or label == "" then
        label = self.L(STAT_LABELS[stat] or "STAT_AGILITY")
    end
    return stat, label, keys
end

local STAT_SHORT = {
    agility = "STAT_SHORT_AGILITY",
    strength = "STAT_SHORT_STRENGTH",
    intellect = "STAT_SHORT_INTELLECT",
}

function LJ:StatShort()
    local stat = self:PlayerStat()
    return self.L(STAT_SHORT[stat] or "STAT_SHORT_AGILITY")
end

-- ---------------------------------------------------------------- Items
function LJ:ItemID(link)
    link = Plain(link)
    if type(link) ~= "string" then return nil end
    return tonumber(link:match("item:(%d+)"))
end

function LJ:ExtractItemLinks(text)
    text = Plain(text)
    if type(text) ~= "string" then return nil end
    local links = {}
    for link in text:gmatch("(|Hitem:[^|]+|h.-|h)") do
        links[#links + 1] = link
    end
    return links
end

-- Entfernt Farbcodes, damit derselbe Link aus Chat, Roll-Fenster und Beuteln
-- als identisch erkannt wird (sonst zählt ein Item doppelt).
function LJ:NormalizeLink(link)
    link = Plain(link)
    if type(link) ~= "string" then return nil end
    link = link:gsub("|c%x%x%x%x%x%x%x%x", "")
    link = link:gsub("|r", "")
    return link
end

local function itemInfoCall(linkOrID)
    local fn = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d, e, f, g, h, i, j, k = pcall(fn, linkOrID)
    if not ok then return nil end
    if type(a) == "table" then
        local info = a
        return Plain(info.name), Plain(info.link), tonumber(Plain(info.quality)),
            tonumber(Plain(info.itemLevel)), tonumber(Plain(info.requiredLevel)),
            tonumber(Plain(info.classID)), tonumber(Plain(info.subclassID)),
            tonumber(Plain(info.maxStack)), Plain(info.equipLoc), Plain(info.icon),
            tonumber(Plain(info.sellPrice))
    end
    return Plain(a), Plain(b), tonumber(Plain(c)), tonumber(Plain(d)), tonumber(Plain(e)),
        tonumber(Plain(f)), tonumber(Plain(g)), tonumber(Plain(h)), Plain(i),
        Plain(j), tonumber(Plain(k))
end

function LJ:ItemInfo(linkOrID)
    local name, link, quality, itemLevel, requiredLevel, classID, subclassID, maxStack, equipLoc, icon, sellPrice = itemInfoCall(linkOrID)
    if not name and not link and not classID then
        local fn = (C_Item and C_Item.GetItemInfo) or GetItemInfo
        if type(fn) == "function" and type(linkOrID) == "string" then
            -- Different clients may accept only the item ID.
            local id = self:ItemID(linkOrID)
            if id then
                name, link, quality, itemLevel, requiredLevel, classID, subclassID, maxStack, equipLoc, icon, sellPrice = itemInfoCall(id)
            end
        end
    end
    return {
        name = name or nil,
        link = link or nil,
        quality = quality,
        itemLevel = itemLevel,
        requiredLevel = requiredLevel,
        classID = classID,
        subclassID = subclassID,
        maxStack = maxStack,
        equipLoc = equipLoc,
        icon = icon,
        sellPrice = sellPrice,
    }
end

function LJ:ItemInfoInstant(linkOrID)
    local fn = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if type(fn) ~= "function" then return nil end
    local ok, itemID, itemType, itemSubType, itemEquipLoc, icon, classID = pcall(fn, linkOrID)
    if not ok then return nil end
    return {
        id = tonumber(Plain(itemID)),
        itemType = Plain(itemType),
        itemSubType = Plain(itemSubType),
        equipLoc = Plain(itemEquipLoc),
        icon = Plain(icon),
        classID = tonumber(Plain(classID)),
    }
end

function LJ:ItemStats(link)
    link = Plain(link)
    if type(link) ~= "string" then return nil end
    local fn = C_Item and C_Item.GetItemStats
    if type(fn) ~= "function" then return nil end
    local ok, stats = pcall(fn, link)
    if ok and type(stats) == "table" and next(stats) ~= nil then return stats end
    return nil
end

local function statValue(stats, keys)
    if type(stats) ~= "table" or type(keys) ~= "table" then return nil end
    for i = 1, #keys do
        local v = tonumber(Plain(stats[keys[i]]))
        if v and v > 0 then return v end
    end
    return 0
end

-- Returns a table:
--   known      true when enough data is available to classify the item
--   loot       true when the item is non-quest loot
--   quest      true for quest items
--   agi        true / false / nil für den Primärstat des Spielers
--              (historischer Feldname; beim Schurken = Beweglichkeit),
--              nil solange die Itemdaten noch nicht geladen sind
function LJ:ClassifyItem(link)
    link = Plain(link)
    if type(link) ~= "string" then return nil end
    local id = self:ItemID(link)
    local info = self:ItemInfo(link)
    local instant = self:ItemInfoInstant(link)
    local classID = instant and instant.classID or info.classID
    local itemType = instant and instant.itemType or nil
    local isQuest = (classID == 12) or (type(itemType) == "string" and itemType == "Quest")
    local stats = self:ItemStats(link)
    local stat, _, keys = self:PlayerStat()
    local agi
    if stats then
        local v = statValue(stats, keys)
        agi = (v ~= nil and v > 0) or false
    end
    local known = isQuest or (classID ~= nil) or (stats ~= nil)
    local loot = known and not isQuest
    return {
        id = id,
        link = link,
        name = info.name or instant and instant.itemType,
        classID = classID,
        itemType = itemType,
        quality = info.quality,
        icon = info.icon or (instant and instant.icon),
        quest = isQuest,
        known = known,
        loot = loot,
        agi = agi,
        stats = stats,
        stat = stat,
    }
end

function LJ:ItemCount(id)
    id = tonumber(id)
    if not id then return 0 end
    local fn = (C_Item and C_Item.GetItemCount) or GetItemCount
    if type(fn) ~= "function" then return 0 end
    local ok, n = pcall(fn, id, true, false, false, false)
    n = ok and tonumber(Plain(n))
    if type(n) ~= "number" then
        ok, n = pcall(fn, id, true)
        n = ok and tonumber(Plain(n))
    end
    return type(n) == "number" and n or 0
end

function LJ:LoadItem(link, id)
    id = tonumber(id) or self:ItemID(link)
    if not id then return end
    local req = C_Item and C_Item.RequestLoadItemDataByID
    if type(req) == "function" then pcall(req, id) end
    local get = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    if type(get) == "function" then pcall(get, link or id) end
end

function LJ:NoteItemDebug(link, source)
    self.debugItems = self.debugItems or {}
    local info = self:ClassifyItem(link)
    local text = tostring(link)
    if info then
        text = string.format("%s [%s] source=%s quest=%s known=%s agi=%s",
            tostring(info.name or "?"), tostring(info.id or "?"), tostring(source),
            tostring(info.quest), tostring(info.known), tostring(info.agi))
    end
    table.insert(self.debugItems, 1, text)
    while #self.debugItems > 8 do table.remove(self.debugItems) end
end

-- ---------------------------------------------------------------- Addon-Load
local loader = CreateFrame and CreateFrame("Frame") or nil
if loader then
    loader:RegisterEvent("ADDON_LOADED")
    loader:RegisterEvent("PLAYER_LOGIN")
    loader:SetScript("OnEvent", function(_, event, arg1)
        if event == "ADDON_LOADED" and arg1 == LJ.name then
            local ok, err = pcall(LJ.InitDB, LJ)
            if not ok then
                LJ:Print(LJ.L("ERROR_START", tostring(err)))
                return
            end
            if LJ.Tracker then pcall(LJ.Tracker.Start, LJ.Tracker) end
            if LJ.SetupCommands then pcall(LJ.SetupCommands, LJ) end
        elseif event == "PLAYER_LOGIN" and LJ.dbReady then
            if LJ.UI then pcall(LJ.UI.Create, LJ.UI) end
            if LJ.Minimap then pcall(LJ.Minimap.Create, LJ.Minimap) end
            if LJ.Options then pcall(LJ.Options.Create, LJ.Options) end
            LJ:Print(LJ.L("CHAT_LOADED", LJ:AddOnVersion()))
            local welcome = not LJ.DB.seenWelcome or LJ.DB.showWelcome == true
            if not LJ.DB.seenWelcome then LJ.DB.seenWelcome = true end
            if welcome and C_Timer and C_Timer.After then
                C_Timer.After(4, function() LJ:Print(LJ.L("CHAT_WELCOME")) end)
            end
            LJ:Changed()
        end
    end)
end
