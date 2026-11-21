-- Run from the LootJinx repository root before either catalog generator.
-- lua tools/review_dungeon_sources.lua <ForeverDungeonJournal/Data/Dungeons.lua>
-- The --snapshot mode is for recording a reviewed upstream baseline after an update.
local input = assert(arg[1], "pass ForeverDungeonJournal/Data/Dungeons.lua")
local root = assert(input:match("^(.*)[/\\]Data[/\\]Dungeons%.lua$"),
    "expected ForeverDungeonJournal/Data/Dungeons.lua")
local toc = assert(io.open(root .. "/ForeverDungeonJournal.toc", "r"))
local version
for line in toc:lines() do version = version or line:match("^## Version:%s*(%S+)") end
toc:close()
assert(version, "source version missing from .toc")

local source = { Constants = { ALBA_FAIRMOON_LOCATION = "" } }
assert(loadfile(input))("ForeverDungeonJournal", source)
local journalBosses = {}
for _, dungeon in ipairs(source.ORDER) do
    for _, boss in ipairs((source.DB[dungeon] or {}).bosses or {}) do
        journalBosses[boss] = true
    end
end
local shared = loadfile(root .. "/Data/SharedLoot.lua")
if shared then shared("ForeverDungeonJournal", source) end
local updates = assert(io.open(root .. "/Data/QuestUpdates.lua", "r"))
local updateText = updates:read("*a")
updates:close()
local drownedLoot = assert(updateText:match("%-%- BEGIN drownedloot(.-)%-%- END drownedloot"),
    "Drowned City loot block missing from QuestUpdates.lua")
local drowned = assert(source.DB["The Drowned City"])
local originalDrownedItems = {}
for _, boss in ipairs(drowned.bosses or {}) do
    for _, item in ipairs(boss.loot or {}) do originalDrownedItems[item] = true end
end
assert(load("local _, FDJ = ...\n" .. drownedLoot, "@QuestUpdates.lua:drownedloot"))(
    "ForeverDungeonJournal", source)
for _, boss in ipairs(drowned.bosses or {}) do
    for _, item in ipairs(boss.loot or {}) do
        if type(item) == "table" and not originalDrownedItems[item] then
            item.reviewEvidence = "Data/QuestUpdates.lua:drownedloot"
        end
    end
end
local wowheadAdded, wowheadConflicts, wowheadSeen = assert(loadfile("tools/apply_wowhead_forever_loot.lua"))()(source)
print(string.format("Wowhead Forever: %d reviewed references, %d added, %d conflicts", wowheadSeen, wowheadAdded, #wowheadConflicts))
for _, conflict in ipairs(wowheadConflicts) do print("  conflict: " .. conflict) end
local foreverAdded, foreverPresent, foreverConflicts, foreverSeen =
    assert(loadfile("tools/apply_foreverdb_loot.lua"))()(source)
print(string.format("ForeverDB.net: %d reviewed references, %d added, %d already present, %d conflicts",
    foreverSeen, foreverAdded, foreverPresent, #foreverConflicts))
for _, conflict in ipairs(foreverConflicts) do print("  conflict: " .. conflict) end
assert(type(source.DB) == "table" and type(source.ORDER) == "table", "invalid source data")

local function bossFlags()
    local result = {}
    for _, dungeon in ipairs(source.ORDER) do
        result[dungeon] = {}
        for _, boss in ipairs((source.DB[dungeon] or {}).bosses or {}) do
            if type(boss.name) == "string" then
                local function values(list)
                    local out = {}
                    for _, value in ipairs(type(list) == "table" and list or {}) do
                        out[#out + 1] = tostring(value)
                    end
                    table.sort(out)
                    return table.concat(out, ",")
                end
                result[dungeon][boss.name] = string.format("rare=%d optional=%d trash=%d summon=%d npc=%s aliases=%s prior=%s",
                    boss.rare and 1 or 0, boss.optional and 1 or 0,
                    boss.trash and 1 or 0, boss.summonItem and 1 or 0,
                    tostring(tonumber(boss.npcID) or "-"), values(boss.aliases),
                    values(boss.killedBefore))
                if boss.childOf then
                    result[dungeon][boss.name] = result[dungeon][boss.name] .. " parent=" .. boss.childOf
                end
                if boss.children then
                    result[dungeon][boss.name] = result[dungeon][boss.name] .. " members=" .. values(boss.children)
                end
            end
        end
    end
    return result
end

local flags = bossFlags()
if arg[2] == "--snapshot" then
    local out = assert(io.open("tools/dungeon_source_baseline.lua", "w"))
    out:write("-- Reviewed ForeverDungeonJournal boss flags; update only after source review.\n")
    out:write("return { version = ", string.format("%q", version), ", bosses = {\n")
    local dungeons = {}
    for dungeon in pairs(flags) do dungeons[#dungeons + 1] = dungeon end
    table.sort(dungeons)
    for _, dungeon in ipairs(dungeons) do
        out:write("    [", string.format("%q", dungeon), "] = {\n")
        local names = {}
        for name in pairs(flags[dungeon]) do names[#names + 1] = name end
        table.sort(names)
        for _, name in ipairs(names) do
            out:write("        [", string.format("%q", name), "] = ",
                string.format("%q", flags[dungeon][name]), ",\n")
        end
        out:write("    },\n")
    end
    out:write("} }\n")
    out:close()
    print("Wrote tools/dungeon_source_baseline.lua for " .. version)
    return
end
assert(arg[2] == nil, "usage: lua tools/review_dungeon_sources.lua <Dungeons.lua> [--snapshot]")

local baseline = assert(loadfile("tools/dungeon_source_baseline.lua"))()
local current = {}
assert(loadfile("DungeonCompletionData.lua"))("LootJinx", current)
assert(loadfile("DungeonLootData.lua"))("LootJinx", current)
assert(loadfile("DungeonLoot.lua"))("LootJinx", current)

local function sortedKeys(map)
    local keys = {}
    for key in pairs(map) do keys[#keys + 1] = key end
    table.sort(keys)
    return keys
end

local function compare(label, old, new)
    local added, removed, changed = {}, {}, {}
    for key, value in pairs(new) do
        if old[key] == nil then added[#added + 1] = key
        elseif old[key] ~= value then changed[#changed + 1] = key .. " (" .. old[key] .. " -> " .. value .. ")" end
    end
    for key in pairs(old) do if new[key] == nil then removed[#removed + 1] = key end end
    table.sort(added)
    table.sort(removed)
    table.sort(changed)
    print(string.format("%s: +%d -%d changed=%d", label, #added, #removed, #changed))
    for _, key in ipairs(added) do print("  + " .. key) end
    for _, key in ipairs(removed) do print("  - " .. key) end
    for _, key in ipairs(changed) do print("  ~ " .. key) end
    return #added + #removed + #changed
end

local oldBosses, newBosses = {}, {}
for dungeon, bosses in pairs(baseline.bosses or {}) do
    for name, value in pairs(bosses) do oldBosses[dungeon .. " / " .. name] = value end
end
for dungeon, bosses in pairs(flags) do
    for name, value in pairs(bosses) do newBosses[dungeon .. " / " .. name] = value end
end

local arena = {
    ["Gorosh the Dervish"] = true, Grizzle = true, Eviscerator = true,
    ["Ok'thor the Breaker"] = true, ["Anub'shiah"] = true,
    ["Hedrum the Creeper"] = true,
}
local oldRequired, newRequired = {}, {}
for dungeon, bosses in pairs(current.DungeonCompletionData or {}) do
    -- Curated raid entries outside the Journal are kept by the generator.
    if source.DB[dungeon] then
        for _, boss in ipairs(bosses) do oldRequired[dungeon .. " / " .. boss.name] = "required" end
    end
end
for _, dungeon in ipairs(source.ORDER) do
    for _, boss in ipairs((source.DB[dungeon] or {}).bosses or {}) do
        if journalBosses[boss] and type(boss.name) == "string" and not boss.trash and not boss.rare
            and not boss.optional and not boss.summonItem and not boss.childOf then
            if dungeon ~= "Blackrock Depths" or not arena[boss.name]
                or boss.name == "Gorosh the Dervish" then
                local name = dungeon == "Blackrock Depths" and arena[boss.name]
                    and "Ring of the Law" or boss.name
                newRequired[dungeon .. " / " .. name] = "required"
            end
        end
    end
end

local oldLoot, newLoot = {}, {}
local function addLoot(index, dungeon, id, sourceName, evidence)
    local key = dungeon .. " / " .. id
    local entry = index[key] or {}
    index[key] = entry
    entry[sourceName] = entry[sourceName] or evidence
end

for dungeon, groups in pairs(current.DungeonLootData or {}) do
    for _, group in ipairs(groups) do
        local sourceName = group[2] and "trash" or group[1]
        for _, id in ipairs(group[3] or {}) do
            addLoot(oldLoot, dungeon, id, sourceName, true)
        end
    end
end
for _, dungeon in ipairs(source.ORDER) do
    for _, boss in ipairs((source.DB[dungeon] or {}).bosses or {}) do
        local sourceName = boss.trash and "trash" or boss.name
        if type(sourceName) == "string" then
            local function add(items, evidence)
                for _, item in ipairs(items or {}) do
                    local id = type(item) == "table" and tonumber(item[1])
                    if id and id > 0 then
                        addLoot(newLoot, dungeon, id, sourceName, item.reviewEvidence or evidence)
                    end
                end
            end
            add(boss.loot, "Data/Dungeons.lua")
            add(source.GetBossSharedLoot and source.GetBossSharedLoot(dungeon, boss), "Data/SharedLoot.lua")
        end
    end
end

local function compareLoot()
    local keys = {}
    for key in pairs(oldLoot) do keys[key] = true end
    for key in pairs(newLoot) do keys[key] = true end
    local changes = {}
    local added, removed = 0, 0
    for _, key in ipairs(sortedKeys(keys)) do
        local old, new = oldLoot[key] or {}, newLoot[key] or {}
        local evidence = {}
        local changed = false
        for _, name in ipairs(sortedKeys(new)) do
            if not old[name] then
                added = added + 1
                changed = true
            end
            evidence[#evidence + 1] = name .. ": " .. new[name]
        end
        for name in pairs(old) do
            if not new[name] then removed = removed + 1; changed = true end
        end
        if changed then
            changes[#changes + 1] = string.format("  %s | old=%s | new=%s | evidence=%s", key,
                next(old) and table.concat(sortedKeys(old), ", ") or "none",
                next(new) and table.concat(sortedKeys(new), ", ") or "none",
                #evidence > 0 and table.concat(evidence, "; ") or "no current source")
        end
    end
    print(string.format("Item-source entries: +%d -%d across %d items", added, removed, #changes))
    for _, change in ipairs(changes) do print(change) end
    return added + removed
end

print("ForeverDungeonJournal " .. baseline.version .. " -> " .. version)
local total = 0
total = total + compare("Boss names and rare/optional/trash/summon flags", oldBosses, newBosses)
total = total + compare("Required-boss membership", oldRequired, newRequired)

local sharedMaps = {
    [189] = "^Scarlet Monastery:", [229] = "Blackrock Spire$",
    [329] = "^Stratholme:", [429] = "^Dire Maul:",
}
for _, mapID in ipairs(sortedKeys(sharedMaps)) do
    local old, new = {}, {}
    for _, dungeon in ipairs(current.DungeonLoot:Candidates({ instanceID = mapID }) or {}) do
        old[dungeon] = "candidate"
    end
    for _, dungeon in ipairs(source.ORDER) do
        if dungeon:match(sharedMaps[mapID]) then new[dungeon] = "candidate" end
    end
    total = total + compare("Shared map " .. mapID .. " candidates", old, new)
end
total = total + compareLoot()
print("Total differences: " .. total)
print("Review every difference before running a generator with --reviewed; never commit generated catalogs solely from this report.")
