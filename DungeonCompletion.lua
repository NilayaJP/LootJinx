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

function Completion:Progress(run)
    local candidates = LJ.DungeonLoot and LJ.DungeonLoot:Candidates(run)
    if type(candidates) ~= "table" then
        return { state = "unavailable", candidates = {}, observed = 0, required = 0 }
    end
    local seen = {}
    for _, boss in ipairs((run and run.bosses) or {}) do
        local name = normalized(boss.name)
        if name and name ~= "" then seen[name] = true end
    end
    local results = {}
    local best, tied = nil, false
    for _, dungeon in ipairs(candidates) do
        local required = LJ.DungeonCompletionData and LJ.DungeonCompletionData[dungeon]
        if type(required) == "table" and #required > 0 then
            local missing = {}
            for _, boss in ipairs(required) do
                local found = seen[normalized(boss.name)] == true
                for _, alias in ipairs(boss.aliases or {}) do
                    if seen[normalized(alias)] then found = true end
                end
                if not found then missing[#missing + 1] = boss.name end
            end
            local result = {
                dungeon = dungeon, observed = #required - #missing,
                required = #required, missing = missing,
            }
            results[#results + 1] = result
            if not best or result.observed > best.observed then
                best, tied = result, false
            elseif result.observed == best.observed then
                tied = true
            end
        end
    end
    if not best then
        return { state = "unavailable", candidates = {}, observed = 0, required = 0 }
    end
    local complete, completeCount = nil, 0
    for _, result in ipairs(results) do
        if #result.missing == 0 then
            complete, completeCount = result, completeCount + 1
        end
    end
    local selected = completeCount == 1 and complete
        or (completeCount == 0 and (#results == 1 or (best.observed > 0 and not tied)) and best)
    if selected then
        return {
            state = #selected.missing == 0 and "complete" or "incomplete",
            dungeon = selected.dungeon,
            observed = selected.observed, required = selected.required,
            missing = selected.missing, candidates = results,
        }
    end
    return {
        state = "unresolved", candidates = results,
        observed = best.observed, required = best.required,
    }
end

function Completion:Match(run)
    local progress = self:Progress(run)
    if progress.state == "complete" then
        return progress.dungeon, progress.required, progress.required
    end
    return nil, progress.observed, progress.required
end
