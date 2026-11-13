-- Dungeon and item-source lookup. This catalog supports attribution only;
-- observed drops remain visible when an item or dungeon is absent here.
local ADDON, ns = ...
local LJ = ns or _G.LootJinx
if not LJ then return end

local Catalog = {}
LJ.DungeonLoot = Catalog

-- Instance map IDs verified against ForeverDungeonJournal 2.0.4. Several
-- wings share a map ID; an item is assigned only when its source is unique.
local BY_INSTANCE = {
    [36] = "The Deadmines", [43] = "Wailing Caverns", [33] = "Shadowfang Keep",
    [34] = "The Stockade", [48] = "Blackfathom Deeps", [90] = "Gnomeregan",
    [47] = "Razorfen Kraul", [389] = "Ragefire Chasm",
    [2999] = "Ruins of Lordaeron", [2959] = "City of Dalaran",
    [3001] = "Shaper's Terrace", [2970] = "The Drowned City",
    [3039] = "Krol'dok Stronghold", [2998] = "Excavation Site: Wetlands",
    [3065] = "Hall of Thanes", [2994] = "Alcaz Prison",
    [2974] = "Blackmaw Hold", [129] = "Razorfen Downs",
    [70] = "Uldaman", [209] = "Zul'Farrak", [109] = "Sunken Temple",
    [289] = "Scholomance", [349] = "Maraudon", [230] = "Blackrock Depths",
    [189] = {
        "Scarlet Monastery: Graveyard", "Scarlet Monastery: Library",
        "Scarlet Monastery: Armory", "Scarlet Monastery: Cathedral",
    },
    [302] = "Scarlet Monastery: Graveyard",
    [303] = "Scarlet Monastery: Library",
    [304] = "Scarlet Monastery: Armory",
    [305] = "Scarlet Monastery: Cathedral",
    [429] = { "Dire Maul: East", "Dire Maul: West", "Dire Maul: North" },
    [229] = { "Lower Blackrock Spire", "Upper Blackrock Spire" },
    [329] = { "Stratholme: Living", "Stratholme: Undead" },
}

local itemIndex, byLowerName
local function indexData()
    if itemIndex then return end
    itemIndex, byLowerName = {}, {}
    for dungeonName, groups in pairs(LJ.DungeonLootData or {}) do
        local items = {}
        itemIndex[dungeonName] = items
        byLowerName[dungeonName:lower()] = dungeonName
        for _, group in ipairs(groups) do
            local bossName, trash, ids = group[1], group[2], group[3]
            for _, id in ipairs(ids or {}) do
                local source = items[id]
                if not source then
                    source = { trash = false, bosses = {} }
                    items[id] = source
                end
                if trash then source.trash = true else source.bosses[bossName] = true end
            end
        end
    end
end

local function candidates(run)
    if type(run) ~= "table" then return nil end
    local value = BY_INSTANCE[tonumber(run.instanceID)]
    local name = type(run.name) == "string" and byLowerName[run.name:lower()] or nil
    if type(value) == "string" then return { value } end
    if type(value) == "table" then
        if name then
            for _, candidate in ipairs(value) do
                if candidate == name then return { name } end
            end
        end
        return value
    end
    if name then return { name } end
    return nil
end

function Catalog:Source(run, itemID)
    indexData()
    itemID = tonumber(itemID)
    if not itemID then return nil end
    local possible = candidates(run)
    if not possible then return nil end
    local count, result, boss, offered = 0, nil, nil, {}
    local function offer(kind, bossName)
        local key = kind .. ":" .. (bossName or "")
        if offered[key] then return end
        offered[key] = true
        count = count + 1
        result, boss = kind, bossName
    end
    for _, dungeonName in ipairs(possible) do
        local entry = itemIndex[dungeonName] and itemIndex[dungeonName][itemID]
        if entry then
            if entry.trash then offer("trash") end
            for bossName in pairs(entry.bosses) do offer("boss", bossName) end
        end
    end
    if count == 1 then return result, boss end
    if count > 1 then return "ambiguous" end
    return nil
end
