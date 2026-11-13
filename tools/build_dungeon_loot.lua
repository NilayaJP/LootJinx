-- One-time build helper: lua tools/build_dungeon_loot.lua <ForeverDungeonJournal/Data/Dungeons.lua>
-- Produces factual item-ID/source references. LootJinx never loads the source addon.
local input = assert(arg[1], "pass the DungeonJournal Dungeons.lua path")
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

local out = assert(io.open("DungeonLootData.lua", "w"))
out:write("-- Curated item ID/source index from ForeverDungeonJournal " .. version .. " (WoW Forever 1.60.1).\n")
out:write("-- Sources: Data/Dungeons.lua and Data/SharedLoot.lua.\n")
out:write("-- Reference data only: observations and client events decide whether an item actually dropped.\n")
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
            if #ids > 0 then
                out:write("        { ", string.format("%q", boss.name or "?"), ", ",
                    boss.trash and "true" or "false", ", { ")
                for i, id in ipairs(ids) do
                    if i > 1 then out:write(", ") end
                    out:write(tostring(id))
                end
                out:write(" } },\n")
            end
        end
        out:write("    },\n")
    end
end
out:write("}\n")
out:close()
