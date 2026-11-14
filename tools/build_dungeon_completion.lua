-- lua tools/build_dungeon_completion.lua <ForeverDungeonJournal/Data/Dungeons.lua>
local input = assert(arg[1], "pass Data/Dungeons.lua")
local root = assert(input:match("^(.*)[/\\]Data[/\\]Dungeons%.lua$"))
local toc = assert(io.open(root .. "/ForeverDungeonJournal.toc", "r"))
local version
for line in toc:lines() do version = version or line:match("^## Version:%s*(%S+)") end
toc:close()
assert(version, "source version missing")
local source = { Constants = { ALBA_FAIRMOON_LOCATION = "" } }
assert(loadfile(input))("ForeverDungeonJournal", source)
local out = assert(io.open("DungeonCompletionData.lua", "w"))
out:write("-- Required boss names from ForeverDungeonJournal " .. version .. ". Rare and trash entries excluded.\n")
out:write("local ADDON, ns = ...\nlocal LJ = ns or _G.LootJinx\nif not LJ then return end\n")
out:write("LJ.DungeonCompletionData = {\n")
for _, dungeonName in ipairs(source.ORDER or {}) do
    local dungeon = source.DB[dungeonName]
    if dungeon then
        out:write("    [", string.format("%q", dungeonName), "] = {\n")
        for _, boss in ipairs(dungeon.bosses or {}) do
            if not boss.trash and not boss.rare and not boss.summonItem and type(boss.name) == "string" then
                out:write("        { name = ", string.format("%q", boss.name), ", aliases = { ")
                local aliases = type(boss.aliases) == "table" and boss.aliases or { boss.name }
                for i, alias in ipairs(aliases) do
                    if i > 1 then out:write(", ") end
                    out:write(string.format("%q", alias))
                end
                out:write(" }, npcID = ", tostring(tonumber(boss.npcID) or "nil"), " },\n")
            end
        end
        out:write("    },\n")
    end
end
out:write("}\n")
out:close()
