-- Read-only review of ForeverDB.net loot observations against the LootJinx catalog.
-- Run from the repository root after tools/fetch_foreverdb_loot.py:
--   lua tools/review_foreverdb_loot.lua [--all]
-- This tool never writes DungeonLootData.lua. Catalog changes still go through
-- tools/review_dungeon_sources.lua and tools/build_dungeon_loot.lua.
--
-- Credit: Data from ForeverDB.net — https://foreverdb.net

local TSV = "tools/foreverdb_loot.tsv"
local UNMAPPED = "tools/foreverdb_loot_unmapped.tsv"
local GAP_RATE = 0.10
local DETAIL_SAMPLE = 10
local MAX_DETAILS_PER_DUNGEON = 12

local showAll = arg[1] == "--all"
assert(arg[1] == nil or showAll, "usage: lua tools/review_foreverdb_loot.lua [--all]")

local function loadRows(path)
    local rows = {}
    local file = assert(io.open(path, "r"), "missing " .. path .. "; run tools/fetch_foreverdb_loot.py first")
    for line in file:lines() do
        if line ~= "" and line:sub(1, 1) ~= "#" then
            local dungeon, boss, idText, name, dropsText, killsText, url =
                line:match("^([^\t]+)\t([^\t]+)\t(%d+)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]+)$")
            assert(dungeon, "invalid ForeverDB row: " .. line)
            rows[#rows + 1] = {
                dungeon = dungeon, boss = boss, id = tonumber(idText), name = name,
                drops = tonumber(dropsText), kills = tonumber(killsText), url = url,
            }
        end
    end
    file:close()
    return rows
end

local function loadUnmapped(path)
    local pages, bosses, items = {}, {}, {}
    local file = io.open(path, "r")
    if not file then return pages, bosses, items end
    for line in file:lines() do
        if line ~= "" and line:sub(1, 1) ~= "#" then
            local page, boss, reason, url, id, name, drops, kills, evidence =
                line:match("^([^\t]+)\t([^\t]+)\t([^\t]*)\t([^\t]+)\t(%d+)\t([^\t]+)\t(%d*)\t(%d*)\t([^\t]*)$")
            if id then
                items[#items + 1] = { page = page, boss = boss, reason = reason, url = url,
                    id = tonumber(id), name = name, drops = tonumber(drops), kills = tonumber(kills), evidence = evidence }
            else
                page, boss, reason, url = line:match("^([^\t]+)\t([^\t]+)\t([^\t]*)\t([^\t]+)$")
                assert(page, "invalid unresolved ForeverDB row: " .. line)
                if boss == "-" then
                    pages[#pages + 1] = { page = page, reason = reason, url = url }
                else
                    bosses[#bosses + 1] = { page = page, boss = boss, reason = reason, url = url }
                end
            end
        end
    end
    file:close()
    return pages, bosses, items
end

local function set()
    return setmetatable({}, { __index = function() return false end })
end

local function countKeys(map)
    local count = 0
    for _ in pairs(map or {}) do count = count + 1 end
    return count
end

local function rate(row)
    if row.kills and row.kills > 0 then return row.drops / row.kills end
    return -1
end

local function rateText(row)
    if row.kills and row.kills > 0 then
        return string.format("%d/%d (%.0f%%)", row.drops, row.kills, 100 * row.drops / row.kills)
    end
    return "seen, no drop rate"
end

local function byRateThenName(a, b)
    local ra, rb = rate(a), rate(b)
    if ra ~= rb then return ra > rb end
    if a.dungeon ~= b.dungeon then return a.dungeon < b.dungeon end
    if a.boss ~= b.boss then return a.boss < b.boss end
    return a.id < b.id
end

local rows = loadRows(TSV)
assert(#rows > 0, "empty ForeverDB snapshot")

local catalog = {}
assert(loadfile("DungeonLootData.lua"))("LootJinx", catalog)
catalog = catalog.DungeonLootData
assert(type(catalog) == "table", "DungeonLootData.lua did not load")

-- Catalog index: item -> sources per dungeon, plus a global item -> source list.
local catItems, catGlobal, catGlobalSources = {}, set(), {}
for dungeon, groups in pairs(catalog) do
    catItems[dungeon] = {}
    for _, group in ipairs(groups) do
        local source = group[2] and "Trash Drops" or group[1]
        for _, id in ipairs(group[3] or {}) do
            local entry = catItems[dungeon][id]
            if not entry then
                entry = { sources = {}, list = {} }
                catItems[dungeon][id] = entry
            end
            if not entry.sources[source] then
                entry.sources[source] = true
                entry.list[#entry.list + 1] = source
            end
            catGlobal[id] = true
            catGlobalSources[id] = catGlobalSources[id] or {}
            catGlobalSources[id][dungeon .. " / " .. source] = true
        end
    end
end

-- ForeverDB index.
local tsvDungeonItems, tsvBossKills = {}, {}
local itemDungeons, itemNames = {}, {}
for _, row in ipairs(rows) do
    tsvDungeonItems[row.dungeon] = tsvDungeonItems[row.dungeon] or set()
    tsvDungeonItems[row.dungeon][row.id] = true
    tsvBossKills[row.dungeon] = tsvBossKills[row.dungeon] or {}
    local kills = row.kills or 0
    if kills > (tsvBossKills[row.dungeon][row.boss] or 0) then
        tsvBossKills[row.dungeon][row.boss] = kills
    end
    itemDungeons[row.id] = itemDungeons[row.id] or {}
    itemDungeons[row.id][row.dungeon] = true
    if row.name ~= "" then itemNames[row.id] = row.name end
end

local function sortedSources(entry)
    local list = {}
    for _, source in ipairs(entry.list) do list[#list + 1] = source end
    table.sort(list)
    return table.concat(list, ", ")
end

local function sortedGlobalSources(id)
    local list = {}
    for source in pairs(catGlobalSources[id] or {}) do list[#list + 1] = source end
    table.sort(list)
    return table.concat(list, ", ")
end

print(string.format("ForeverDB review: %d observations, %d dungeons, %d items",
    #rows, countKeys(tsvDungeonItems), countKeys(itemDungeons)))
print("Read-only report. The catalog is not changed.")
if not showAll then
    print(string.format("Default view: gaps at >= %.0f%% drop rate; use --all for the complete list.",
        100 * GAP_RATE))
end

-- 1. Attribution conflicts: ForeverDB saw the item at another source.
local conflicts, trashConflicts, elsewhere = {}, {}, {}
for _, row in ipairs(rows) do
    local entry = catItems[row.dungeon] and catItems[row.dungeon][row.id]
    if entry and not entry.sources[row.boss] then
        if entry.sources["Trash Drops"] and #entry.list == 1 then
            trashConflicts[#trashConflicts + 1] = { row = row, sources = sortedSources(entry) }
        else
            conflicts[#conflicts + 1] = { row = row, sources = sortedSources(entry) }
        end
    elseif not entry and catGlobal[row.id] then
        elsewhere[#elsewhere + 1] = { row = row, sources = sortedGlobalSources(row.id) }
    end
end
table.sort(conflicts, function(a, b) return byRateThenName(a.row, b.row) end)
table.sort(trashConflicts, function(a, b) return byRateThenName(a.row, b.row) end)
table.sort(elsewhere, function(a, b) return byRateThenName(a.row, b.row) end)

print("")
print(string.format("Attribution conflicts (boss vs boss): %d", #conflicts))
for _, conflict in ipairs(conflicts) do
    local row = conflict.row
    print(string.format("  [%s] %s / %d %s — catalog: %s — ForeverDB: %s",
        row.dungeon, row.boss, row.id, row.name, conflict.sources, rateText(row)))
end

print("")
print(string.format("Boss drops the catalog files as trash: %d", #trashConflicts))
for _, conflict in ipairs(trashConflicts) do
    local row = conflict.row
    print(string.format("  [%s] %s / %d %s — catalog: %s — ForeverDB: %s",
        row.dungeon, row.boss, row.id, row.name, conflict.sources, rateText(row)))
end

print("")
print(string.format("Catalogued in another dungeon: %d", #elsewhere))
for _, conflict in ipairs(elsewhere) do
    local row = conflict.row
    print(string.format("  [%s] %s / %d %s — catalog: %s — ForeverDB: %s",
        row.dungeon, row.boss, row.id, row.name, conflict.sources, rateText(row)))
end

-- 2. Catalog gaps: ForeverDB saw the item, the catalog does not list it anywhere.
local gaps, world = {}, {}
for _, row in ipairs(rows) do
    if not (catItems[row.dungeon] and catItems[row.dungeon][row.id]) and not catGlobal[row.id] then
        if countKeys(itemDungeons[row.id]) >= 3 then
            world[#world + 1] = row
        else
            gaps[#gaps + 1] = row
        end
    end
end
table.sort(gaps, byRateThenName)

local notable, low = {}, {}
for _, row in ipairs(gaps) do
    if rate(row) >= GAP_RATE then notable[#notable + 1] = row else low[#low + 1] = row end
end

print("")
print(string.format("Catalog gaps (new items, >= %.0f%% drop rate): %d", 100 * GAP_RATE, #notable))
for _, row in ipairs(notable) do
    print(string.format("  [%s] %s / %d %s — %s",
        row.dungeon, row.boss, row.id, row.name, rateText(row)))
end
if showAll then
    print("")
    print(string.format("Catalog gaps (new items, below %.0f%%): %d", 100 * GAP_RATE, #low))
    for _, row in ipairs(low) do
        print(string.format("  [%s] %s / %d %s — %s",
            row.dungeon, row.boss, row.id, row.name, rateText(row)))
    end
else
    local perDungeon, order = {}, {}
    for _, row in ipairs(low) do
        if not perDungeon[row.dungeon] then
            perDungeon[row.dungeon] = 0
            order[#order + 1] = row.dungeon
        end
        perDungeon[row.dungeon] = perDungeon[row.dungeon] + 1
    end
    table.sort(order)
    print("")
    print(string.format("Catalog gaps (new items, below %.0f%%): %d (use --all to list)", 100 * GAP_RATE, #low))
    for _, dungeon in ipairs(order) do
        print(string.format("  [%s] %d", dungeon, perDungeon[dungeon]))
    end
end

-- Aggregate probable world drops by item so one item is not repeated per dungeon.
local worldItems = {}
for _, row in ipairs(world) do
    local entry = worldItems[row.id]
    if not entry then
        entry = { id = row.id, name = row.name, seen = {}, best = row }
        worldItems[row.id] = entry
    end
    entry.seen[row.dungeon] = true
    if rate(row) > rate(entry.best) then entry.best = row end
end
local worldList = {}
for _, entry in pairs(worldItems) do
    entry.seenIn = countKeys(entry.seen)
    worldList[#worldList + 1] = entry
end
table.sort(worldList, function(a, b)
    if a.seenIn ~= b.seenIn then return a.seenIn > b.seenIn end
    local ra, rb = rate(a.best), rate(b.best)
    if ra ~= rb then return ra > rb end
    return a.id < b.id
end)

print("")
print(string.format("Probable world drops (seen in 3+ dungeons): %d items from %d observations",
    #worldList, #world))
for _, entry in ipairs(worldList) do
    local best = entry.best
    print(string.format("  %d %s — seen in %d dungeons — best %s at %s / %s",
        entry.id, entry.name, entry.seenIn, rateText(best), best.dungeon, best.boss))
end

-- 3. Catalog only: the catalog lists it, ForeverDB never saw it in that dungeon.
print("")
print("Catalog only (informational; ForeverDB samples are small):")
local catalogDungeons = {}
for dungeon in pairs(tsvDungeonItems) do catalogDungeons[#catalogDungeons + 1] = dungeon end
table.sort(catalogDungeons)
local onlyTotal, onlyStrict = 0, 0
for _, dungeon in ipairs(catalogDungeons) do
    local missing = {}
    for _, group in ipairs(catalog[dungeon] or {}) do
        local source = group[2] and "Trash Drops" or group[1]
        local sample = tsvBossKills[dungeon] and tsvBossKills[dungeon][source] or 0
        for _, id in ipairs(group[3] or {}) do
            if not tsvDungeonItems[dungeon][id] then
                missing[#missing + 1] = { id = id, source = source, sample = sample,
                    unseen = not itemDungeons[id] }
            end
        end
    end
    table.sort(missing, function(a, b)
        if a.unseen ~= b.unseen then return a.unseen end
        if a.sample ~= b.sample then return a.sample > b.sample end
        if a.source ~= b.source then return a.source < b.source end
        return a.id < b.id
    end)
    if #missing > 0 then
        onlyTotal = onlyTotal + #missing
        local shown, strictCount = 0, 0
        local lines = {}
        for _, item in ipairs(missing) do
            local strict = item.sample >= DETAIL_SAMPLE and item.unseen
            if strict then
                strictCount = strictCount + 1
                onlyStrict = onlyStrict + 1
            end
            if (showAll or strict) and shown < MAX_DETAILS_PER_DUNGEON then
                shown = shown + 1
                local name = itemNames[item.id]
                lines[#lines + 1] = string.format("    %s / %d%s — %d kills sampled",
                    item.source, item.id, name and (" " .. name) or "", item.sample)
            end
        end
        print(string.format("  [%s] %d catalog items never observed; %d with >= %d kills and unseen everywhere",
            dungeon, #missing, strictCount, DETAIL_SAMPLE))
        for _, line in ipairs(lines) do print(line) end
        if shown < #missing and not showAll then
            print(string.format("    ... %d more not listed", #missing - shown))
        end
    end
end
print(string.format("  Total: %d catalog items never observed; %d with a meaningful unseen sample",
    onlyTotal, onlyStrict))

-- 4. Unresolved ForeverDB pages and bosses.
local pages, bosses, items = loadUnmapped(UNMAPPED)
print("")
print(string.format("Unresolved ForeverDB content: %d pages, %d bosses, %d item references",
    #pages, #bosses, #items))
for _, page in ipairs(pages) do
    print(string.format("  page: %s — %s", page.page, page.reason))
end
for _, boss in ipairs(bosses) do
    print(string.format("  boss: %s / %s — %s", boss.page, boss.boss, boss.reason))
end
if showAll then
    for _, row in ipairs(items) do
        print(string.format("  unassigned: [%s] %s / %d %s — %s — %s — %s",
            row.page, row.boss, row.id, row.name, row.reason, row.evidence, row.url))
    end
elseif #items > 0 then
    print("  Use --all to list item references without a unique source.")
end

print("")
print("Review every entry before touching the catalog. ForeverDB observations never override DungeonJournal data.")
