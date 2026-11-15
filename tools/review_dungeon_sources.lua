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
local shared = loadfile(root .. "/Data/SharedLoot.lua")
if shared then shared("ForeverDungeonJournal", source) end
local updates = assert(io.open(root .. "/Data/QuestUpdates.lua", "r"))
local updateText = updates:read("*a")
updates:close()
local drownedLoot = assert(updateText:match("%-%- BEGIN drownedloot(.-)%-%- END drownedloot"),
    "Drowned City loot block missing from QuestUpdates.lua")
assert(load("local _, FDJ = ...\n" .. drownedLoot, "@QuestUpdates.lua:drownedloot"))(
    "ForeverDungeonJournal", source)
local wowheadAdded, wowheadConflicts, wowheadSeen = assert(loadfile("tools/apply_wowhead_forever_loot.lua"))()(source)
print(string.format("Wowhead Forever: %d reviewed references, %d added, %d conflicts", wowheadSeen, wowheadAdded, #wowheadConflicts))
for _, conflict in ipairs(wowheadConflicts) do print("  conflict: " .. conflict) end
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
    for _, boss in ipairs(bosses) do oldRequired[dungeon .. " / " .. boss.name] = "required" end
end
for _, dungeon in ipairs(source.ORDER) do
    for _, boss in ipairs((source.DB[dungeon] or {}).bosses or {}) do
        if type(boss.name) == "string" and not boss.trash and not boss.rare
            and not boss.optional and not boss.summonItem then
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
for dungeon, groups in pairs(current.DungeonLootData or {}) do
    for _, group in ipairs(groups) do
        local sourceName = group[2] and "trash" or group[1]
        for _, id in ipairs(group[3] or {}) do
            oldLoot[dungeon .. " / " .. sourceName .. " / " .. id] = "source"
        end
    end
end
for _, dungeon in ipairs(source.ORDER) do
    for _, boss in ipairs((source.DB[dungeon] or {}).bosses or {}) do
        local sourceName = boss.trash and "trash" or boss.name
        if type(sourceName) == "string" then
            local function add(items)
                for _, item in ipairs(items or {}) do
                    local id = type(item) == "table" and tonumber(item[1])
                    if id and id > 0 then
                        newLoot[dungeon .. " / " .. sourceName .. " / " .. id] = "source"
                    end
                end
            end
            add(boss.loot)
            add(source.GetBossSharedLoot and source.GetBossSharedLoot(dungeon, boss))
        end
    end
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
total = total + compare("Item-source entries", oldLoot, newLoot)
print("Total differences: " .. total)
print("Review every difference before running a generator with --reviewed; never commit generated catalogs solely from this report.")
