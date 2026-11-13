-- Explicit cleanup of old run details. Summary data remains for lifetime stats.
local ADDON, ns = ...
local LJ = ns or _G.LootJinx
if not LJ then return end

local S = { AGE_DAYS = 30 }
LJ.Storage = S
local AGE_SECONDS = S.AGE_DAYS * 86400

local function eligible(run, active, now)
    if type(run) ~= "table" or run == active or run.closed ~= true
        or run.detailVersion == nil or run.provisionalPreviousID then return false end
    local lastAt = tonumber(run.ended) or tonumber(run.lastSeen) or tonumber(run.started)
    if not lastAt or lastAt <= 0 or now - lastAt < AGE_SECONDS then return false end
    if type(run.pending) == "table" and #run.pending > 0 then return false end
    for _, need in ipairs(run.needs or {}) do
        if type(need) == "table" and need.result ~= "won" and need.result ~= "lost" then
            return false
        end
    end
    return true
end

function S:Preview(runs, active, now)
    runs = type(runs) == "table" and runs or {}
    now = tonumber(now) or (LJ.Now and LJ.Now()) or 0
    local count = 0
    for _, run in ipairs(runs) do
        if eligible(run, active, now) then count = count + 1 end
    end
    return { savedRuns = #runs, eligible = count }
end

function S:Clean(runs, active, now)
    runs = type(runs) == "table" and runs or {}
    now = tonumber(now) or (LJ.Now and LJ.Now()) or 0
    local cleaned = 0
    for _, run in ipairs(runs) do
        if eligible(run, active, now) then
            local needs = {}
            for _, need in ipairs(run.needs or {}) do
                if type(need) == "table" then
                    needs[#needs + 1] = { at = need.at, result = need.result }
                end
            end
            run.needs = needs
            run.bosses, run.drops, run.rolls = {}, {}, {}
            run.seenLinks, run.pending, run.greeds = {}, {}, {}
            run.detailVersion = nil
            run.legacy = true
            cleaned = cleaned + 1
        end
    end
    return cleaned
end

return S
