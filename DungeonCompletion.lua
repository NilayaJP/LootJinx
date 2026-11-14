-- Independent required-boss completion check. No inferred kills.
local ADDON, ns = ...
local LJ = ns or _G.LootJinx
if not LJ then return end
local Completion = {}
LJ.DungeonCompletion = Completion

local function normalized(value)
    value = LJ.Plain(value)
    if type(value) ~= "string" then return nil end
    return value:match("^%s*(.-)%s*$"):lower()
end

function Completion:Match(run)
    local candidates = LJ.DungeonLoot and LJ.DungeonLoot:Candidates(run)
    if type(candidates) ~= "table" then return nil, 0, 0 end
    local seen = {}
    for _, boss in ipairs((run and run.bosses) or {}) do
        local name = normalized(boss.name)
        if name and name ~= "" then seen[name] = true end
    end
    local matched, bestSeen, bestRequired = nil, 0, 0
    for _, dungeon in ipairs(candidates) do
        local required = LJ.DungeonCompletionData and LJ.DungeonCompletionData[dungeon]
        if type(required) == "table" and #required > 0 then
            local count = 0
            for _, boss in ipairs(required) do
                local found = seen[normalized(boss.name)] == true
                for _, alias in ipairs(boss.aliases or {}) do
                    if seen[normalized(alias)] then found = true end
                end
                if found then count = count + 1 end
            end
            if count > bestSeen then bestSeen, bestRequired = count, #required end
            if count == #required then
                if matched then return nil, bestSeen, bestRequired end
                matched = dungeon
            end
        end
    end
    if matched then
        local total = #LJ.DungeonCompletionData[matched]
        return matched, total, total
    end
    return nil, bestSeen, bestRequired
end
