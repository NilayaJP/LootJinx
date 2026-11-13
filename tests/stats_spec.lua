-- LootJinx – Tests der reinen Statistik-Engine
-- Ausführen: lua tests/stats_spec.lua
local ns = {}
local chunk = assert(loadfile("Stats.lua"))
chunk("LootJinx", ns)
local Stats = ns.Stats
assert(Stats and Stats.Compute, "Stats.Compute fehlt")

local failures = 0
local checks = 0
local function ok(cond, message)
    checks = checks + 1
    if not cond then
        failures = failures + 1
        print("FEHLER: " .. message)
    end
end
local function eq(actual, expected, message)
    ok(actual == expected, string.format("%s (erwartet: %s, erhalten: %s)",
        message, tostring(expected), tostring(actual)))
end

local function need(at, result)
    return { at = at, result = result }
end

local function run(opts)
    opts = opts or {}
    return {
        id = opts.id or 1,
        started = opts.started or 0,
        closed = opts.closed ~= false,
        lootSeen = opts.lootSeen == true,
        agilityDropped = opts.agilityDropped == true,
        needs = opts.needs or {},
    }
end

-- 1. Leere Historie
do
    local s = Stats.Compute({})
    eq(s.totalDungeons, 0, "leer: totalDungeons")
    eq(s.noAgiDungeons, 0, "leer: noAgiDungeons")
    eq(s.lostNeedCurrent, 0, "leer: lostNeedCurrent")
    eq(s.sinceNeedWinCurrent, 0, "leer: sinceNeedWinCurrent")
    eq(s.winRate, 0, "leer: winRate")
end

-- 2. Dungeons ohne Agility-Drop und Serie
do
    local s = Stats.Compute({
        run({ agilityDropped = true }),
        run({}),
        run({}),
        run({}),
        run({ agilityDropped = true }),
    })
    eq(s.totalDungeons, 5, "agi: total")
    eq(s.agilityDungeons, 2, "agi: mit Agility")
    eq(s.noAgiDungeons, 3, "agi: ohne Agility")
    eq(s.noAgiCurrent, 0, "agi: aktuelle Serie nach Treffer")
    eq(s.noAgiMax, 3, "agi: Rekord")
end

-- 3. Loot-Serie
do
    local s = Stats.Compute({
        run({ lootSeen = true }),
        run({}),
        run({}),
        run({ lootSeen = true }),
        run({}),
    })
    eq(s.lootDungeons, 2, "loot: mit Loot")
    eq(s.noLootDungeons, 3, "loot: ohne Loot")
    eq(s.noLootCurrent, 1, "loot: aktuelle Serie")
    eq(s.noLootMax, 2, "loot: Rekord")
end

-- 4. Verlorene Need-Rolls in Folge
do
    local s = Stats.Compute({
        run({ needs = { need(1, "lost"), need(2, "lost") } }),
        run({ needs = { need(3, "won") } }),
        run({ needs = { need(4, "lost"), need(5, "lost"), need(6, "lost") } }),
        run({ needs = { need(7, nil) } }),
    })
    eq(s.needRolls, 7, "need: Rolls")
    eq(s.needWins, 1, "need: Gewinne")
    eq(s.needLost, 5, "need: Verluste")
    eq(s.needPending, 1, "need: offen")
    eq(s.resolvedNeeds, 6, "need: aufgelöst")
    eq(s.lostNeedCurrent, 3, "need: aktuelle Verlustserie")
    eq(s.lostNeedMax, 3, "need: Rekord-Verlustserie")
    ok(math.abs(s.winRate - (100 / 6)) < 0.0001, "need: Winrate")
end

-- 5. Need-Siege setzen die Verlustserie zurück
do
    local s = Stats.Compute({
        run({ needs = { need(1, "lost") } }),
        run({ needs = { need(2, "won") } }),
        run({ needs = { need(3, "lost") } }),
    })
    eq(s.lostNeedCurrent, 1, "need reset: aktuell")
    eq(s.lostNeedMax, 1, "need reset: Rekord")
end

-- 6. Dungeons ohne Need-Win; Dungeons ohne Need unterbrechen nicht
do
    local s = Stats.Compute({
        run({ needs = { need(1, "lost") } }),
        run({}),
        run({ needs = { need(2, "lost") } }),
        run({ needs = { need(3, "won") } }),
        run({}),
        run({ needs = { need(4, "lost") } }),
    })
    eq(s.needDungeons, 4, "no need win: Dungeons mit Need")
    eq(s.noNeedWinDungeons, 3, "no need win: ohne Sieg")
    eq(s.noNeedWinCurrent, 1, "no need win: aktuelle Serie")
    eq(s.noNeedWinMax, 2, "no need win: Rekord")
end

-- 7. Seit letztem Need-Win zählt alle Dungeons
do
    local s = Stats.Compute({
        run({}),
        run({ needs = { need(1, "won") } }),
        run({}),
        run({}),
    })
    eq(s.sinceNeedWinCurrent, 2, "since: aktuell")
    eq(s.sinceNeedWinMax, 2, "since: Rekord")
    ok(s.lastNeedWin ~= nil, "since: lastNeedWin gesetzt")
    ok(s.lastNeedWinNeed ~= nil and s.lastNeedWinNeed.result == "won", "since: letzter Sieg")
end

-- 8. Ohne Need-Wurf beginnt die Serie noch nicht
do
    local s = Stats.Compute({
        run({}),
        run({}),
        run({}),
    })
    eq(s.sinceNeedWinCurrent, 0, "since none: aktuell")
    eq(s.sinceNeedWinMax, 0, "since none: Rekord")
end

-- 8a. Erste Need-Niederlage startet die Serie ohne frühere Dungeons
do
    local s = Stats.Compute({
        run({}),
        run({ needs = { need(1, "lost") } }),
        run({}),
    })
    eq(s.sinceNeedWinCurrent, 2, "since first need: aktuell")
    eq(s.sinceNeedWinMax, 2, "since first need: Rekord")
end

-- 9. Offene Need-Rolls zählen als offen, nicht als verloren
do
    local s = Stats.Compute({
        run({ needs = { need(1, nil), need(2, nil) } }),
    })
    eq(s.needPending, 2, "pending: offen")
    eq(s.needLost, 0, "pending: nicht verloren")
    eq(s.lostNeedCurrent, 0, "pending: keine Verlustserie")
    eq(s.noNeedWinDungeons, 1, "pending: Dungeon ohne Sieg")
    eq(s.noNeedWinCurrent, 1, "pending: aktuelle Serie")
end

-- 10. Need-Einträge werden chronologisch sortiert
do
    local s = Stats.Compute({
        run({ needs = { need(30, "lost"), need(10, "won"), need(20, "lost") } }),
    })
    eq(s.lostNeedCurrent, 2, "sort: aktuelle Serie")
    eq(s.lostNeedMax, 2, "sort: Rekord")
    eq(s.needWins, 1, "sort: Gewinne")
end

-- 11. Aktiver Run zählt in laufenden Serien mit
do
    local s = Stats.Compute({
        run({ closed = true, agilityDropped = true, lootSeen = true }),
        run({ closed = false }),
    })
    eq(s.totalDungeons, 2, "aktiv: total")
    eq(s.noAgiCurrent, 1, "aktiv: noAgi aktuell")
    eq(s.noLootCurrent, 1, "aktiv: noLoot aktuell")
    eq(s.noAgiMax, 1, "aktiv: noAgi Rekord")
end

-- 12. Rekord bleibt erhalten, wenn die aktuelle Serie abreißt
do
    local s = Stats.Compute({
        run({}),
        run({}),
        run({}),
        run({ agilityDropped = true }),
        run({ agilityDropped = true }),
    })
    eq(s.noAgiCurrent, 0, "rekord: aktuell")
    eq(s.noAgiMax, 3, "rekord: Maximum bleibt")
end

-- 13. Ein Need-Sieg in einem Run zählt nicht als Dungeon seit dem Sieg
do
    local s = Stats.Compute({
        run({ needs = { need(1, "won") } }),
        run({}),
    })
    eq(s.sinceNeedWinCurrent, 1, "since: Sieg-Dungeon zählt nicht")
    eq(s.sinceNeedWinMax, 1, "since: Rekord")
end

if failures > 0 then
    print(string.format("%d von %d Prüfungen fehlgeschlagen.", failures, checks))
    os.exit(1)
end
print(string.format("OK – %d Prüfungen erfolgreich.", checks))
