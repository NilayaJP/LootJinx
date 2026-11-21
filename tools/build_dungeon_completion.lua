-- lua tools/build_dungeon_completion.lua <ForeverDungeonJournal/Data/Dungeons.lua> --reviewed
local input = assert(arg[1], "pass Data/Dungeons.lua")
assert(arg[2] == "--reviewed", "run tools/review_dungeon_sources.lua first; pass --reviewed after reviewing its report")
local root = assert(input:match("^(.*)[/\\]Data[/\\]Dungeons%.lua$"))
local toc = assert(io.open(root .. "/ForeverDungeonJournal.toc", "r"))
local version
for line in toc:lines() do version = version or line:match("^## Version:%s*(%S+)") end
toc:close()
assert(version, "source version missing")
local source = { Constants = { ALBA_FAIRMOON_LOCATION = "" } }
assert(loadfile(input))("ForeverDungeonJournal", source)
for _, file in ipairs({ "Content_deDE.lua", "Content_NewDungeons.lua", "Content_Verified.lua" }) do
    assert(loadfile(root .. "/Localization/" .. file))("ForeverDungeonJournal", source)
end
local german = source.ContentLocales.deDE.bosses or {}
local germanDungeons = source.ContentLocales.deDE.dungeons or {}

-- These raid encounters come from LootJinx's separately reviewed raid data.
local current = {}
assert(loadfile("DungeonCompletionData.lua"))("LootJinx", current)
local raids = {
    "Molten Core", "Onyxia's Lair", "Blackwing Lair", "Zul'Gurub",
    "Ruins of Ahn'Qiraj", "Ahn'Qiraj Temple", "Naxxramas",
}

-- Wowhead Forever journal encounter labels can combine several NPCs. Only
-- add a shared alias when the journal explicitly presents one encounter.
local journalAliases = {
    ["The Drowned City"] = {
        ["Deathless Marrow"] = { "Deathless Guardians" },
    },
    ["Shadowfang Keep"] = {
        ["Fel Steed / Shadow Charger"] = { "Fel Steeds / Shadow Charger" },
    },
    ["Scarlet Monastery: Cathedral"] = {
        ["Scarlet Commander Mograine"] = { "Scarlet Commander Mograine & High Inquisitor Whitemane" },
        ["High Inquisitor Whitemane"] = { "Scarlet Commander Mograine & High Inquisitor Whitemane" },
    },
    ["Razorfen Downs"] = {
        ["Plaguemaw the Rotting"] = { "Plaguemaw the Rotting Event" },
    },
    ["Zul'Farrak"] = {
        ["Nekrum Gutchewer"] = { "Nekrum Gutchewer & Shadowpriest Sezz'ziz" },
        ["Shadowpriest Sezz'ziz"] = { "Nekrum Gutchewer & Shadowpriest Sezz'ziz" },
    },
    ["Blackrock Depths"] = {
        ["The Seven"] = { "Chest of the Seven" },
    },
    ["Upper Blackrock Spire"] = {
        ["Gyth"] = { "Warchief Rend Blackhand & Gyth" },
        ["Warchief Rend Blackhand"] = { "Warchief Rend Blackhand & Gyth" },
    },
    ["Dire Maul: North"] = {
        ["Cho'Rush the Observer"] = { "King Gordok & Cho'Rush the Observer" },
        ["King Gordok"] = { "King Gordok & Cho'Rush the Observer" },
    },
}

local arenaNames = {
    ["Gorosh the Dervish"] = true, Grizzle = true, Eviscerator = true,
    ["Ok'thor the Breaker"] = true, ["Anub'shiah"] = true,
    ["Hedrum the Creeper"] = true,
}

local function appendUnique(list, value)
    if type(value) ~= "string" or value == "" then return end
    for _, existing in ipairs(list) do
        if existing == value then return end
    end
    list[#list + 1] = value
end

local function writeList(out, key, entries)
    out:write(", ", key, " = { ")
    for i, entry in ipairs(entries) do
        if i > 1 then out:write(", ") end
        out:write(string.format("%q", entry))
    end
    out:write(" }")
end

local function writeBoss(out, name, aliases, npcID, deName, impliedBy, members)
    out:write("        { name = ", string.format("%q", name))
    writeList(out, "aliases", aliases)
    out:write(", npcID = ", tostring(tonumber(npcID) or "nil"))
    if type(deName) == "string" and deName ~= "" and deName ~= name then
        out:write(", deName = ", string.format("%q", deName))
    end
    if impliedBy then writeList(out, "impliedBy", impliedBy) end
    if members then writeList(out, "members", members) end
    out:write(" },\n")
end

local out = assert(io.open("DungeonCompletionData.lua", "w"))
out:write("-- Required boss names from ForeverDungeonJournal " .. version .. " with available German names and reviewed Wowhead Forever encounter labels. Rare, optional, summoned, and trash entries excluded.\n")
out:write("local ADDON, ns = ...\nlocal LJ = ns or _G.LootJinx\nif not LJ then return end\n")
out:write("LJ.DungeonCompletionData = {\n")
for _, dungeonName in ipairs(source.ORDER or {}) do
    local dungeon = source.DB[dungeonName]
    if dungeon then
        out:write("    [", string.format("%q", dungeonName), "] = {\n")
        local implicitKills, groupMembers = {}, {}
        for _, boss in ipairs(dungeon.bosses or {}) do
            if boss.childOf then
                local members = groupMembers[boss.childOf] or {}
                appendUnique(members, boss.name)
                groupMembers[boss.childOf] = members
            end
            for _, prior in ipairs(boss.killedBefore or {}) do
                if type(prior) == "string" then
                    implicitKills[prior] = implicitKills[prior] or {}
                    appendUnique(implicitKills[prior], boss.name)
                end
            end
        end
        for _, boss in ipairs(dungeon.bosses or {}) do
            if not boss.trash and not boss.rare and not boss.optional
                and not boss.summonItem and not boss.childOf and type(boss.name) == "string" then
                if dungeonName ~= "Blackrock Depths" or not arenaNames[boss.name]
                    or boss.name == "Gorosh the Dervish" then
                    local name = boss.name
                    local aliases = {}
                    if dungeonName == "Blackrock Depths" and arenaNames[name] then
                        name = "Ring of the Law"
                        appendUnique(aliases, name)
                        for _, arenaBoss in ipairs(dungeon.bosses or {}) do
                            if arenaNames[arenaBoss.name] then
                                appendUnique(aliases, arenaBoss.name)
                                appendUnique(aliases, german[arenaBoss.name])
                            end
                        end
                    else
                        appendUnique(aliases, name)
                        for _, alias in ipairs(type(boss.aliases) == "table" and boss.aliases or { boss.name }) do
                            appendUnique(aliases, alias)
                        end
                        appendUnique(aliases, german[boss.name])
                        for _, alias in ipairs((journalAliases[dungeonName] or {})[boss.name] or {}) do
                            appendUnique(aliases, alias)
                        end
                        for _, killer in ipairs(implicitKills[boss.name] or {}) do
                            appendUnique(aliases, killer)
                            appendUnique(aliases, german[killer])
                        end
                    end
                    local impliedBy
                    if dungeonName == "Scarlet Monastery: Cathedral" and name == "Scarlet Commander Mograine" then
                        impliedBy = { "High Inquisitor Whitemane" }
                    elseif dungeonName == "Sunken Temple" and name == "Altar Bosses" then
                        -- The six altar guardians gate Jammal'an.
                        impliedBy = { "Jammal'an the Prophet", "Jammal'an der Prophet" }
                    end
                    writeBoss(out, name, aliases, boss.npcID, german[boss.name], impliedBy, groupMembers[name])
                end
            end
        end
        out:write("    },\n")
    end
end
out:write("    -- Separately reviewed raid encounters.\n")
for _, dungeonName in ipairs(raids) do
    if not source.DB[dungeonName] then
        out:write("    [", string.format("%q", dungeonName), "] = {\n")
        for _, boss in ipairs(assert(current.DungeonCompletionData[dungeonName])) do
            writeBoss(out, boss.name, boss.aliases, boss.npcID, boss.deName, boss.impliedBy, boss.members)
        end
        out:write("    },\n")
    end
end
out:write("}\n")
out:write("LJ.DungeonCompletionNames = {\n")
for _, dungeonName in ipairs(source.ORDER or {}) do
    local label = germanDungeons[dungeonName] and germanDungeons[dungeonName].name
    if type(label) == "string" and label ~= "" then
        out:write("    [", string.format("%q", dungeonName), "] = ",
            string.format("%q", label), ",\n")
    end
end
for _, dungeonName in ipairs(raids) do
    local label = current.DungeonCompletionNames[dungeonName]
    if not germanDungeons[dungeonName] and label then
        out:write("    [", string.format("%q", dungeonName), "] = ",
            string.format("%q", label), ",\n")
    end
end
out:write("}\n")
out:close()
