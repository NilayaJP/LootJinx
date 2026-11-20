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
    cyan        = { 0.350, 0.800, 1.000, 1.00 },
    gold        = { 1.000, 0.820, 0.300, 1.00 },
    green       = { 0.400, 0.900, 0.550, 1.00 },
    red         = { 0.960, 0.360, 0.430, 1.00 },
    orange      = { 0.980, 0.580, 0.280, 1.00 },
    text        = { 0.950, 0.960, 0.980, 1.00 },
    muted       = { 0.720, 0.750, 0.820, 1.00 },
    dim         = { 0.580, 0.610, 0.680, 1.00 },
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

-- Zeitstempel lokalisierbar formatieren. 0/nil steht bei Legacy- und
-- Importdaten für "kein Datum" und darf nicht als 1.1.1970 erscheinen.
-- Der zweite Parameter ist entweder ein DATE_*-Schlüssel (lokalisiertes
-- Format) oder ein explizites strftime-Muster.
local DATE_FORMAT_KEYS = {
    DATE_SHORT = true,
    DATE_LONG = true,
    DATE_TIME = true,
    DATE_TIME_SHORT = true,
}

function LJ:FormatTime(stamp, format)
    stamp = tonumber(stamp)
    if not stamp or stamp <= 0 then return "–" end
    if DATE_FORMAT_KEYS[format] then
        format = self.L(format)
    elseif type(format) ~= "string" or format == "" then
        format = self.L("DATE_LONG")
    end
    local fn = type(date) == "function" and date or (os and os.date)
    if type(fn) ~= "function" then return "–" end
    local ok, text = pcall(fn, format, stamp)
    if ok and type(text) == "string" then return text end
    return "–"
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
    return "1.7.2"
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
    if kind ~= "need" and kind ~= "greed" and kind ~= "transmog" then kind = nil end
    return {
        id = id,
        link = link,
        bossID = bossID,
        bossName = type(d.bossName) == "string" and d.bossName or nil,
        at = tonumber(d.at) or fallbackAt or 0,
        winner = winner,
        winnerSource = type(d.winnerSource) == "string" and d.winnerSource or nil,
        winnerClass = type(d.winnerClass) == "string" and d.winnerClass or nil,
        roll = tonumber(d.roll),
        rollID = tonumber(d.rollID),
        lootHistoryKey = type(d.lootHistoryKey) == "string" and d.lootHistoryKey or nil,
        rollKind = kind,
        passed = d.passed == true,
        source = type(d.source) == "string" and d.source or nil,
        sources = type(d.sources) == "table" and d.sources or nil,
        lastWindowAt = tonumber(d.lastWindowAt),
    }
end

local function normalizeRoll(r, fallbackAt)
    if type(r) ~= "table" then return nil end
    local id = tonumber(r.id)
    local value = tonumber(r.value)
    local name = type(r.name) == "string" and r.name or nil
    if not id or not value or not name then return nil end
    local kind = r.kind
    if kind ~= "need" and kind ~= "greed" and kind ~= "transmog" then kind = "need" end
    return {
        id = id,
        name = name,
        kind = kind,
        value = value,
        at = tonumber(r.at) or fallbackAt or 0,
        lootHistoryKey = type(r.lootHistoryKey) == "string" and r.lootHistoryKey or nil,
        chatSeen = r.chatSeen == true,
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
    n.chatSeen = n.chatSeen == true
    n.before = tonumber(n.before)
    n.link = type(n.link) == "string" and n.link or nil
    n.result = (n.result == "won" or n.result == "lost") and n.result or nil
    n.resolvedAt = tonumber(n.resolvedAt)
    n.reason = type(n.reason) == "string" and n.reason or nil
    n.roll = tonumber(n.roll)
    n.rollKind = (n.rollKind == "need" or n.rollKind == "greed") and n.rollKind or nil
    -- Ohne Item-Link, Item-ID oder Roll-ID laesst sich ein offener Need nie
    -- aufloesen; solche Alt-Eintraege wuerden dauerhaft als "offen" zaehlen.
    if n.result == nil and not n.id and not n.link and not n.roll and not n.rollID then
        return nil
    end
    return n
end

local function normalizeRun(run, fallbackID)
    if type(run) ~= "table" then return nil end
    run.id = tonumber(run.id) or fallbackID or 0
    run.name = type(run.name) == "string" and run.name or ""
    run.key = type(run.key) == "string" and run.key or nil
    run.instanceID = tonumber(run.instanceID)
    run.zoneID = tonumber(run.zoneID)
    -- The instance-copy check was removed; legacy copy fields are dropped.
    run.provisionalPreviousID = nil
    run.copyOutcome = nil
    run.difficulty = type(run.difficulty) == "string" and run.difficulty or nil
    run.started = tonumber(run.started) or 0
    run.lastSeen = tonumber(run.lastSeen) or run.started
    run.outsideAt = tonumber(run.outsideAt)
    run.paused = run.paused == true
    run.ended = tonumber(run.ended)
    run.lootSeen = run.lootSeen == true
    -- Primary-stat tracking was removed; legacy fields are dropped on load.
    run.stat = nil
    run.statHistory = nil
    run.statMixed = false
    run.agilityDropped = nil
    run.agiItemsSeen = nil
    run.agilityLink = nil
    run.agilityAt = nil
    run.agilityName = nil
    run.itemsSeen = tonumber(run.itemsSeen) or 0
    run.closed = run.closed == true
    run.closedReason = type(run.closedReason) == "string" and run.closedReason or nil
    if run.closedReason == "pending-copy" or run.closedReason == "different-copy"
        or run.closedReason == "unknown-copy" then
        run.closedReason = "closed"
    end
    -- Legacy-Migration: "paused"-Runs (alter Leave-Zustand vor dem
    -- NIT-Style-Close) werden zu geschlossenen Runs, damit kein
    -- "PAUSIERT"-Status (orangener Punkt) mehr erscheint.
    if run.paused then
        run.paused = false
        run.closed = true
        run.closedReason = run.closedReason or "left"
        run.ended = run.ended or run.lastSeen or run.started
    end
    run.partial = run.partial == true
    if type(run.timeline) == "table" then
        local cleanTimeline = {}
        for i = 1, #run.timeline do
            local event = run.timeline[i]
            if type(event) == "table" and (event.kind == "exit" or event.kind == "return")
                and tonumber(event.at) and tonumber(event.at) > 0 then
                cleanTimeline[#cleanTimeline + 1] = { kind = event.kind, at = tonumber(event.at) }
            end
        end
        while #cleanTimeline > 24 do table.remove(cleanTimeline, 1) end
        run.timeline = cleanTimeline
        run.timelineOmitted = math.max(0, math.floor(tonumber(run.timelineOmitted) or 0))
    else
        run.timeline = nil
        run.timelineOmitted = nil
    end

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
    while #cleanBosses > 64 do table.remove(cleanBosses, 1) end
    run.bosses = cleanBosses

    local drops = type(run.drops) == "table" and run.drops or {}
    local cleanDrops = {}
    for i = 1, #drops do
        local drop = normalizeDrop(drops[i], run.started)
        if drop then cleanDrops[#cleanDrops + 1] = drop end
    end
    run.drops = cleanDrops

    local rolls = type(run.rolls) == "table" and run.rolls or {}
    local cleanRolls = {}
    for i = 1, #rolls do
        local roll = normalizeRoll(rolls[i], run.started)
        if roll then cleanRolls[#cleanRolls + 1] = roll end
    end
    run.rolls = cleanRolls
    local function sameObservedDrop(a, b)
        if a.id ~= b.id or math.abs((a.at or 0) - (b.at or 0)) > 900 then
            return false
        end
        return not (a.bossID and b.bossID and a.bossID ~= b.bossID)
    end
    -- An older recovery pass could append a synthetic drop beside one that
    -- was already observed but had not yet received its Loot History key.
    for i = #cleanDrops, 1, -1 do
        local recovered = cleanDrops[i]
        if recovered.source == "loot-history-recovered" then
            for j = 1, #cleanDrops do
                local observed = cleanDrops[j]
                if i ~= j and observed.source ~= "loot-history-recovered"
                    and (not observed.lootHistoryKey
                        or observed.lootHistoryKey == recovered.lootHistoryKey)
                    and sameObservedDrop(recovered, observed) then
                    table.remove(cleanDrops, i)
                    break
                end
            end
        end
    end
    -- Old runs can contain a second chat or loot-window observation of the
    -- same keyed roll. Only coalesce it when exactly one keyed drop fits.
    local function matchingObservation(keyed, duplicate)
        return not duplicate.lootHistoryKey and not duplicate.rollID
            and (duplicate.source == "chat" or duplicate.source == "chat-win"
                or duplicate.source == "loot-window")
            and keyed.lootHistoryKey and keyed.rollID
            and keyed.id == duplicate.id
            and math.abs((keyed.at or 0) - (duplicate.at or 0)) <= 30
            and (not keyed.bossID or not duplicate.bossID
                or keyed.bossID == duplicate.bossID)
            and (not keyed.winner or not duplicate.winner
                or LJ:SamePlayerName(keyed.winner, duplicate.winner))
            and (not keyed.roll or not duplicate.roll
                or keyed.roll == duplicate.roll)
    end
    local candidateCount = {}
    for _, keyed in ipairs(cleanDrops) do
        if keyed.lootHistoryKey and keyed.rollID then
            local count = 0
            for _, duplicate in ipairs(cleanDrops) do
                if keyed ~= duplicate and matchingObservation(keyed, duplicate) then
                    count = count + 1
                end
            end
            candidateCount[keyed] = count
        end
    end
    for i = #cleanDrops, 1, -1 do
        local duplicate = cleanDrops[i]
        if not duplicate.lootHistoryKey and not duplicate.rollID
            and (duplicate.source == "chat" or duplicate.source == "chat-win"
                or duplicate.source == "loot-window") then
            local match, count = nil, 0
            for j = 1, #cleanDrops do
                local keyed = cleanDrops[j]
                if i ~= j and matchingObservation(keyed, duplicate) then
                    match, count = keyed, count + 1
                end
            end
            if count == 1 and candidateCount[match] == 1 then
                match.sources = match.sources or { [match.source or "unknown"] = true }
                match.sources[duplicate.source] = true
                for source in pairs(duplicate.sources or {}) do match.sources[source] = true end
                if not match.winner then
                    match.winner, match.winnerSource = duplicate.winner, duplicate.winnerSource
                end
                match.winnerClass = match.winnerClass or duplicate.winnerClass
                match.roll = match.roll or duplicate.roll
                match.rollKind = match.rollKind or duplicate.rollKind
                match.bossID = match.bossID or duplicate.bossID
                match.bossName = match.bossName or duplicate.bossName
                table.remove(cleanDrops, i)
            end
        end
    end
    -- Ein erneut geoeffnetes Loot-Fenster meldet dieselbe Leiche noch einmal.
    -- Aeltere Versionen legten jede Wiederholung als eigenen Drop ohne
    -- Empfaenger ab; solche Echos werden in den bereits belegten Drop gefaltet.
    local windowEchoSeconds = 5 * 60
    local lastWindowDrop = {}
    local isEcho = {}
    for i = 1, #cleanDrops do
        local drop = cleanDrops[i]
        local anchor = lastWindowDrop[drop.id]
        local sighting = drop.source == "loot-window" and not drop.winner
            and not drop.rollID and not drop.lootHistoryKey
        if sighting and anchor and anchor.winner then
            local at = tonumber(drop.at) or 0
            local reference = tonumber(anchor.lastWindowAt) or tonumber(anchor.at) or 0
            if at >= reference and at - reference <= windowEchoSeconds then
                anchor.sources = anchor.sources or { [anchor.source or "unknown"] = true }
                for source in pairs(drop.sources or {}) do anchor.sources[source] = true end
                anchor.lastWindowAt = at
                anchor.bossID = anchor.bossID or drop.bossID
                anchor.bossName = anchor.bossName or drop.bossName
                anchor.link = anchor.link or drop.link
                anchor.passed = anchor.passed or drop.passed
                isEcho[i] = true
            else
                lastWindowDrop[drop.id] = drop
            end
        else
            lastWindowDrop[drop.id] = drop
        end
    end
    for i = #cleanDrops, 1, -1 do
        if isEcho[i] then table.remove(cleanDrops, i) end
    end
    -- Older versions trimmed the earliest drops in long runs. Loot History's
    -- keyed rolls and a link observed in that run can restore the missing item
    -- without inventing a winner or a roll result.
    local keyedDrops, linksByID = {}, {}
    for _, drop in ipairs(cleanDrops) do
        if drop.lootHistoryKey then keyedDrops[drop.lootHistoryKey] = true end
    end
    for link in pairs(run.seenLinks or {}) do
        if type(link) == "string" then
            local itemID = tonumber(link:match("item:(%d+)"))
            if itemID and (not linksByID[itemID] or link:match("^|c")) then
                linksByID[itemID] = link
            end
        end
    end
    for _, roll in ipairs(cleanRolls) do
        local key = roll.lootHistoryKey
        local link = key and linksByID[roll.id]
        local alreadyObserved = false
        if link and not keyedDrops[key] then
            local at = tonumber(roll.at) or 0
            local bossID = tonumber(key:match("^(%d+):"))
            for _, drop in ipairs(cleanDrops) do
                if not drop.lootHistoryKey and sameObservedDrop(
                    { id = roll.id, at = at, bossID = bossID }, drop) then
                    alreadyObserved = true
                    break
                end
            end
        end
        if link and not keyedDrops[key] and not alreadyObserved then
            local bossID = tonumber(key:match("^(%d+):"))
            local bossName
            for _, boss in ipairs(cleanBosses) do
                if bossID and bossID > 0 and boss.id == bossID then
                    bossName = boss.name
                    break
                end
            end
            cleanDrops[#cleanDrops + 1] = {
                id = roll.id, link = link, bossID = bossName and bossID or 0,
                bossName = bossName, at = roll.at, lootHistoryKey = key,
                source = "loot-history-recovered",
                sources = { ["loot-history-recovered"] = true },
            }
            keyedDrops[key] = true
        end
    end
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
    if db.scale < 0.40 then db.scale = 0.40 end
    if db.scale > 3.00 then db.scale = 3.00 end
    db.point = type(db.point) == "string" and db.point or "CENTER"
    db.x = tonumber(db.x) or 0
    db.y = tonumber(db.y) or -40
    db.seenWelcome = db.seenWelcome == true
    db.locked = db.locked == true
    db.showWelcome = db.showWelcome == true
    db.compact = db.compact == true
    db.announceRecords = db.announceRecords == true
    db.layoutPreview = db.layoutPreview == "journal" and "journal" or "classic"
    db.language = type(db.language) == "string" and db.language or "auto"
    if db.leaderboardConsent ~= true and db.leaderboardConsent ~= false then
        db.leaderboardConsent = nil
    end
    if db.leaderboardTestAck ~= true then
        db.leaderboardTestAck = nil
    end
    if type(db.leaderboard) ~= "table" then db.leaderboard = {} end
    db.minimapAngle = tonumber(db.minimapAngle) or 225
    if db.minimapAngle ~= db.minimapAngle then db.minimapAngle = 225 end
    db.minimapAngle = db.minimapAngle % 360
    self.DB = db
    if self.SetLanguage then self:SetLanguage(db.language) end

    local char = _G.LootJinxCharDB
    if type(char) ~= "table" then
        char = {}
        _G.LootJinxCharDB = char
    end
    char.version = 2
    char.manualBlockedKey = type(char.manualBlockedKey) == "string" and char.manualBlockedKey or nil
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

function LJ:SamePlayerName(a, b)
    a, b = Plain(a), Plain(b)
    if type(a) ~= "string" or type(b) ~= "string" then return false end
    local function compact(name)
        return name:lower():gsub("[%s%-]", "")
    end
    return compact(a) == compact(b)
end

function LJ:IsMe(name)
    if self:SamePlayerName(name, self:PlayerName()) then return true end
    name = nameOnly(name)
    if not name then return false end
    local me = nameOnly(self:PlayerName())
    if me and name == me then return true end
    local you = Plain(_G.YOU)
    if type(you) == "string" and name == you:lower() then return true end
    return false
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
    local ok, a, b, c, d, e, f, g, h, i, j, k, l, m = pcall(fn, linkOrID)
    if not ok then return nil end
    if type(a) == "table" then
        local info = a
        return Plain(info.name), Plain(info.link), tonumber(Plain(info.quality)),
            tonumber(Plain(info.itemLevel)), tonumber(Plain(info.requiredLevel)),
            tonumber(Plain(info.classID)), tonumber(Plain(info.subclassID)),
            tonumber(Plain(info.maxStack)), Plain(info.equipLoc), Plain(info.icon),
            tonumber(Plain(info.sellPrice))
    end
    -- Forever returns classID/subclassID after sellPrice (positions 12 and 13),
    -- while positions 6 and 7 are the localized type strings.
    return Plain(a), Plain(b), tonumber(Plain(c)), tonumber(Plain(d)), tonumber(Plain(e)),
        tonumber(Plain(l)), tonumber(Plain(m)), tonumber(Plain(h)), Plain(i),
        Plain(j), tonumber(Plain(k))
end

-- Item-Lookups sind der Hot-Path beim Rendern der Run-Details: Dieselbe
-- Item-ID wird pro Render und über mehrere Render hinweg mehrfach aufgelöst.
-- Erfolgreiche Ergebnisse werden für die Session gecacht (Item-Daten sind pro
-- ID statisch). Ein Treffer wird bewusst NICHT gecacht, damit der nächste
-- Render es erneut versucht, sobald die Item-Daten asynchron geladen sind.
local itemInfoCache = {}
local itemInfoInstantCache = {}
local itemLoadRequested = {}

local function itemIDKey(linkOrID)
    if type(linkOrID) == "number" then return linkOrID end
    if type(linkOrID) == "string" then
        return tonumber(linkOrID) or LJ:ItemID(linkOrID)
    end
    return nil
end

function LJ:ItemInfo(linkOrID)
    local key = itemIDKey(linkOrID)
    if key and itemInfoCache[key] then return itemInfoCache[key] end
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
    local info = {
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
    -- Nur vollständig geladene Einträge cachen; classID fehlt, solange der
    -- Item-Datensatz im Client noch nicht verfügbar ist.
    if key and info.classID then itemInfoCache[key] = info end
    return info
end

function LJ:ItemInfoInstant(linkOrID)
    local key = itemIDKey(linkOrID)
    if key and itemInfoInstantCache[key] then return itemInfoInstantCache[key] end
    local fn = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if type(fn) ~= "function" then return nil end
    local ok, itemID, itemType, itemSubType, itemEquipLoc, icon, classID = pcall(fn, linkOrID)
    if not ok then return nil end
    local info = {
        id = tonumber(Plain(itemID)),
        itemType = Plain(itemType),
        itemSubType = Plain(itemSubType),
        equipLoc = Plain(itemEquipLoc),
        icon = Plain(icon),
        classID = tonumber(Plain(classID)),
    }
    if key and info.classID then itemInfoInstantCache[key] = info end
    return info
end

function LJ:ItemQuality(link, knownQuality)
    local quality = tonumber(knownQuality)
    if quality then return quality end
    if type(link) ~= "string" then return nil end
    quality = tonumber(link:match("^|cnIQ(%d+):"))
    if quality then return quality end
    local color = link:match("^|cff(%x%x%x%x%x%x)")
    local colors = { ["9d9d9d"] = 0, ["ffffff"] = 1, ["1eff00"] = 2,
        ["0070dd"] = 3, ["a335ee"] = 4, ["ff8000"] = 5 }
    return color and colors[color:lower()] or nil
end

-- Classifies a link as loot or quest; primary stats are no longer tracked.
function LJ:ClassifyItem(link)
    link = Plain(link)
    if type(link) ~= "string" then return nil end
    local id = self:ItemID(link)
    local info = self:ItemInfo(link)
    local instant = self:ItemInfoInstant(link)
    local classID = instant and instant.classID or info.classID
    local itemType = instant and instant.itemType or nil
    local isQuest = (classID == 12) or (type(itemType) == "string" and itemType == "Quest")
    local known = isQuest or (classID ~= nil)
    local loot = known and not isQuest
    return {
        id = id,
        link = link,
        name = info.name or instant and instant.itemType,
        classID = classID,
        itemType = itemType,
        quality = self:ItemQuality(link, info.quality),
        icon = info.icon or (instant and instant.icon),
        quest = isQuest,
        known = known,
        loot = loot,
    }
end

function LJ:ItemCount(id)
    id = tonumber(id)
    if not id then return nil end
    local fn = (C_Item and C_Item.GetItemCount) or GetItemCount
    if type(fn) ~= "function" then return nil end
    local ok, n = pcall(fn, id, true, false, false, false)
    n = ok and tonumber(Plain(n))
    if type(n) ~= "number" then
        ok, n = pcall(fn, id, true)
        n = ok and tonumber(Plain(n))
    end
    return type(n) == "number" and n or nil
end

function LJ:LoadItem(link, id)
    id = tonumber(id) or self:ItemID(link)
    if not id then return end
    if itemInfoCache[id] then return end
    if not itemLoadRequested[id] then
        itemLoadRequested[id] = true
        local req = C_Item and C_Item.RequestLoadItemDataByID
        if type(req) == "function" then pcall(req, id) end
    end
    local get = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    if type(get) == "function" then pcall(get, link or id) end
end

function LJ:NoteItemDebug(link, source)
    self.debugItems = self.debugItems or {}
    local info = self:ClassifyItem(link)
    local text = tostring(link)
    if info then
        text = string.format("%s [%s] source=%s quest=%s known=%s",
            tostring(info.name or "?"), tostring(info.id or "?"), tostring(source),
            tostring(info.quest), tostring(info.known))
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
