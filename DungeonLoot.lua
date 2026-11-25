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
    -- Raids (Klassik-Instanz-IDs, in Forever unverändert)
    [409] = "Molten Core", [249] = "Onyxia's Lair", [469] = "Blackwing Lair",
    [309] = "Zul'Gurub", [509] = "Ruins of Ahn'Qiraj",
    [531] = "Ahn'Qiraj Temple", [533] = "Naxxramas",
}

local itemIndex, byLowerName, bossesByNPC, trashByNPC, removedLoot
local function indexData()
    if itemIndex then return end
    itemIndex, byLowerName, bossesByNPC = {}, {}, {}
    trashByNPC, removedLoot = {}, {}
    for dungeonName, groups in pairs(LJ.DungeonLootData or {}) do
        local items = {}
        local npcs = {}
        itemIndex[dungeonName] = items
        bossesByNPC[dungeonName] = npcs
        trashByNPC[dungeonName], removedLoot[dungeonName] = {}, {}
        byLowerName[dungeonName:lower()] = dungeonName
        for _, group in ipairs(groups) do
            local bossName, trash, ids, npcID = group[1], group[2], group[3], group[4]
            if not trash and npcID then
                local previous = npcs[npcID]
                npcs[npcID] = (previous == nil or previous == bossName) and bossName or false
            end
            if trash and npcID then trashByNPC[dungeonName][npcID] = true end
            if group.lootRemoved then removedLoot[dungeonName][bossName] = true end
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
    for _, val in pairs(BY_INSTANCE) do
        if type(val) == "string" then
            byLowerName[val:lower()] = val
        elseif type(val) == "table" then
            for _, sub in ipairs(val) do
                byLowerName[sub:lower()] = sub
            end
        end
    end
    for dungeonName in pairs(LJ.DungeonCompletionData or {}) do
        byLowerName[dungeonName:lower()] = dungeonName
    end
end

local displayKeys
local function displayKey(name)
    if not displayKeys then
        displayKeys = {}
        local function index(label, key)
            label = label:gsub("’", "'"):lower()
            local previous = displayKeys[label]
            if previous == nil then displayKeys[label] = key
            elseif previous ~= key then displayKeys[label] = false end
        end
        for key, translations in pairs(LJ.DungeonNames or {}) do
            index(key, key)
            for _, label in pairs(translations) do index(label, key) end
        end
        index("The Temple of Atal'Hakkar", "Sunken Temple")
        index("Temple of Atal'Hakkar", "Sunken Temple")
    end
    return displayKeys[(name:gsub("’", "'"):lower())]
end

local function candidates(run)
    if type(run) ~= "table" then return nil end
    local value = BY_INSTANCE[tonumber(run.instanceID)]
    if type(value) == "string" then return { value } end
    local name
    if type(run.name) == "string" then
        local localizedKey = displayKey(run.name)
        name = byLowerName[run.name:lower()]
            or (localizedKey and byLowerName[localizedKey:lower()])
    end
    if type(value) == "table" then
        for _, candidate in ipairs(value) do
            if candidate == name then return { name } end
        end
        return value
    end
    if name then return { name } end
end

function Catalog:Candidates(run)
    indexData()
    return candidates(run)
end

function Catalog:IsSharedMap(instanceID)
    return type(BY_INSTANCE[tonumber(instanceID)]) == "table"
end

function Catalog:DisplayName(run, language)
    local name = type(run) == "table" and run.name
    local possible = self:Candidates(run)
    local key = possible and #possible == 1 and possible[1]
        or (type(name) == "string" and displayKey(name))
    local translations = (LJ.DungeonNames or {})[key]
    if translations then return language == "en" and key or translations[language] end
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

function Catalog:BossForNPC(run, npcID)
    if not npcID then return nil end
    local found
    for _, dungeon in ipairs(self:Candidates(run) or {}) do
        local name = (bossesByNPC[dungeon] or {})[npcID]
        if name == false then return nil end
        if not name then
            for _, boss in ipairs((LJ.DungeonCompletionData or {})[dungeon] or {}) do
                if boss.npcID == npcID then
                    if name and name ~= boss.name then return nil end
                    name = boss.name
                end
            end
        end
        if name then
            if found and found ~= name then return nil end
            found = name
        end
    end
    return found
end

function Catalog:MatchesBoss(run, observed, canonical)
    if type(observed) ~= "string" or type(canonical) ~= "string" then return false end
    observed, canonical = observed:gsub("’", "'"):lower(), canonical:gsub("’", "'"):lower()
    if observed == canonical then return true end
    local match
    for _, dungeon in ipairs(self:Candidates(run) or {}) do
        for _, boss in ipairs((LJ.DungeonCompletionData or {})[dungeon] or {}) do
            local name = boss.name:gsub("’", "'"):lower()
            if observed == name then return false end
            for _, alias in ipairs(boss.aliases or {}) do
                if observed == alias:gsub("’", "'"):lower() then
                    if match and match ~= name then return false end
                    match = name
                end
            end
        end
    end
    return match == canonical
end

function Catalog:MatchesFight(run, observed, challenger)
    for _, dungeon in ipairs(self:Candidates(run) or {}) do
        for _, boss in ipairs((LJ.DungeonCompletionData or {})[dungeon] or {}) do
            if boss.fightGroup and (observed == boss.fightGroup or observed == boss.name) then
                for _, alias in ipairs(boss.aliases) do
                    if alias == challenger then return true end
                end
            end
        end
    end
    return false
end

function Catalog:DropSource(run, drop)
    if drop.lootSourceAmbiguous then return "ambiguous" end
    local npcID = tonumber(drop.sourceNPCID)
    local boss = self:BossForNPC(run, npcID)
    if boss then return "boss", boss, true end
    if npcID then
        local possible = self:Candidates(run)
        local trash = possible and #possible == 1 and trashByNPC[possible[1]]
        if trash and trash[npcID] then return "trash" end
    end
    local kind, name = self:Source(run, drop.id)
    if drop.sourceNPCID and kind == "boss" then return "unknown-npc" end
    return kind, name
end

function Catalog:IsRecipe(itemID)
    itemID = tonumber(itemID)
    if not itemID then return false end
    if LJ.DungeonRecipeIDs and LJ.DungeonRecipeIDs[itemID] then return true end
    local info = LJ.ItemInfoInstant and LJ:ItemInfoInstant(itemID)
    return info and info.classID == 9 or false
end

function Catalog:IsLootRemoved(run, name)
    for _, dungeon in ipairs(self:Candidates(run) or {}) do
        for boss in pairs(removedLoot[dungeon] or {}) do
            if self:MatchesBoss(run, name, boss) then return true end
        end
    end
    return false
end

function Catalog:ResolveDireMaulWing(run)
    if type(run) ~= "table" or tonumber(run.instanceID) ~= 429 then return nil end
    if type(run.name) == "string" and run.name:find(":") then return nil end
    local observedIDs, observedNames = {}, {}
    for _, boss in ipairs(run.bosses or {}) do
        if tonumber(boss.id) then observedIDs[tonumber(boss.id)] = true end
        if type(boss.name) == "string" then observedNames[boss.name:lower()] = true end
    end
    for wing, list in pairs(LJ.DungeonCompletionData or {}) do
        if type(wing) == "string" and wing:match("^Dire Maul:") then
            for _, boss in ipairs(list or {}) do
                if boss.npcID and observedIDs[boss.npcID] then return wing end
                if type(boss.name) == "string" and observedNames[boss.name:lower()] then return wing end
                for _, alias in ipairs(boss.aliases or {}) do
                    if type(alias) == "string" and observedNames[alias:lower()] then return wing end
                end
            end
        end
    end
    return nil
end

function Catalog:CanInferBoss(drop)
    return (tonumber(drop.bossID) or 0) <= 0 and drop.source ~= "encounter"
        and not (drop.sources and drop.sources.encounter)
end
