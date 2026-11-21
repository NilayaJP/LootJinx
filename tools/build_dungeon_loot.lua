-- lua tools/build_dungeon_loot.lua <ForeverDungeonJournal/Data/Dungeons.lua> --reviewed
-- Produces factual item-ID/source references. LootJinx never loads the source addon.
local input = assert(arg[1], "pass the DungeonJournal Dungeons.lua path")
assert(arg[2] == "--reviewed", "run tools/review_dungeon_sources.lua first; pass --reviewed after reviewing its report")
local root = assert(input:match("^(.*)[/\\]Data[/\\]Dungeons%.lua$"), "expected Data/Dungeons.lua")
local toc = assert(io.open(root .. "/ForeverDungeonJournal.toc", "r"))
local version
for line in toc:lines() do
    version = version or line:match("^## Version:%s*(%S+)")
end
toc:close()
assert(version, "DungeonJournal version missing from .toc")
local source = { Constants = { ALBA_FAIRMOON_LOCATION = "" } }
assert(loadfile(input))("ForeverDungeonJournal", source)
local sharedPath = input:gsub("Dungeons%.lua$", "SharedLoot.lua")
local sharedFile = loadfile(sharedPath)
if sharedFile then sharedFile("ForeverDungeonJournal", source) end
-- DungeonJournal adds the confirmed Drowned City boss drops after Dungeons.lua.
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
local foreverAdded, foreverPresent, foreverConflicts, foreverSeen =
    assert(loadfile("tools/apply_foreverdb_loot.lua"))()(source)
print(string.format("ForeverDB.net: %d reviewed references, %d added, %d already present, %d conflicts",
    foreverSeen, foreverAdded, foreverPresent, #foreverConflicts))
for _, conflict in ipairs(foreverConflicts) do print("  conflict: " .. conflict) end

local out = assert(io.open("DungeonLootData.lua", "w"))
out:write("-- Curated item ID/source index from ForeverDungeonJournal " .. version .. " (WoW Forever 1.60.1).\n")
out:write("-- Sources: Data/Dungeons.lua, Data/SharedLoot.lua, reviewed Data/QuestUpdates.lua, tools/wowhead_forever_loot.tsv,\n")
out:write("-- and reviewed tools/foreverdb_loot_reviewed.tsv (Data from ForeverDB.net — https://foreverdb.net).\n")
out:write("-- Reference data only: observations and client events decide whether an item actually dropped.\n")
out:write("-- Groups store the name, trash flag, item IDs, and a boss NPC ID when available.\n")
out:write("-- Regenerate with tools/build_dungeon_loot.lua after reviewing upstream data changes.\n")
out:write("local ADDON, ns = ...\n")
out:write("local LJ = ns or _G.LootJinx\n")
out:write("if not LJ then return end\n")
out:write("LJ.DungeonLootData = {\n")
for _, dungeonName in ipairs(source.ORDER or {}) do
    local dungeon = source.DB[dungeonName]
    if dungeon then
        out:write("    [", string.format("%q", dungeonName), "] = {\n")
        for _, boss in ipairs(dungeon.bosses or {}) do
            local ids, seen = {}, {}
            local npcID = not boss.trash and tonumber(boss.npcID)
            for _, item in ipairs(boss.loot or {}) do
                local id = type(item) == "table" and tonumber(item[1])
                if id and id > 0 and not seen[id] then
                    ids[#ids + 1] = id
                    seen[id] = true
                end
            end
            local shared = source.GetBossSharedLoot and source.GetBossSharedLoot(dungeonName, boss)
            for _, item in ipairs(shared or {}) do
                local id = type(item) == "table" and tonumber(item[1])
                if id and id > 0 and not seen[id] then
                    ids[#ids + 1] = id
                    seen[id] = true
                end
            end
            if #ids > 0 or (npcID and npcID > 0) then
                out:write("        { ", string.format("%q", boss.name or "?"), ", ",
                    boss.trash and "true" or "false", ", { ")
                for i, id in ipairs(ids) do
                    if i > 1 then out:write(", ") end
                    out:write(tostring(id))
                end
                out:write(" }")
                if npcID and npcID > 0 then out:write(", ", tostring(npcID)) end
                out:write(" },\n")
            end
        end
        out:write("    },\n")
    end
end
out:write("}\n")
out:close()
