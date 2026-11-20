-- LootJinx – reine Statistik-Engine (keine WoW-API-Abhängigkeit)
local ADDON, ns = ...
local LJ = ns or _G.LootJinx or {}
_G.LootJinx = LJ

local Stats = {}
LJ.Stats = Stats

local function max(a, b)
    if a > b then return a end
    return b
end

local function sortedNeeds(run)
    local list = {}
    for i = 1, #(run.needs or {}) do
        local n = run.needs[i]
        if type(n) == "table" then
            list[#list + 1] = { n = n, index = i }
        end
    end
    table.sort(list, function(a, b)
        local ta, tb = tonumber(a.n.at) or 0, tonumber(b.n.at) or 0
        if ta == tb then return a.index < b.index end
        return ta < tb
    end)
    return list
end

function Stats.Compute(runs)
    runs = type(runs) == "table" and runs or {}

    local out = {
        totalDungeons = 0,
        completedDungeons = 0,
        lootDungeons = 0,
        noLootDungeons = 0,
        noLootCurrent = 0,
        noLootMax = 0,
        needRolls = 0,
        needWins = 0,
        needLost = 0,
        needPending = 0,
        resolvedNeeds = 0,
        winRate = 0,
        lostNeedCurrent = 0,
        lostNeedMax = 0,
        noNeedWinDungeons = 0,
        noNeedWinCurrent = 0,
        noNeedWinMax = 0,
        needDungeons = 0,
        pendingDungeons = 0,
        sinceNeedWinCurrent = 0,
        sinceNeedWinMax = 0,
        lastNeedWin = nil,
        lastNeedWinNeed = nil,
        lastNeedLoss = nil,
        lastRun = nil,
    }

    local seenNeed = false
    for _, run in ipairs(runs) do
        if type(run) == "table" then
            out.totalDungeons = out.totalDungeons + 1
            out.lastRun = run
            if run.closed == true then out.completedDungeons = out.completedDungeons + 1 end

            -- Dungeons ohne beobachteten Loot
            if run.lootSeen == true then
                out.lootDungeons = out.lootDungeons + 1
                out.noLootCurrent = 0
            else
                out.noLootDungeons = out.noLootDungeons + 1
                out.noLootCurrent = out.noLootCurrent + 1
                out.noLootMax = max(out.noLootMax, out.noLootCurrent)
            end

            -- Need-Rolls
            local hasNeed = false
            local hasWin = false
            local hasPending = false
            local needs = sortedNeeds(run)
            for _, entry in ipairs(needs) do
                local n = entry.n
                hasNeed = true
                out.needRolls = out.needRolls + 1
                if n.result == "won" then
                    hasWin = true
                    out.needWins = out.needWins + 1
                    out.lostNeedCurrent = 0
                    out.lastNeedWin = run
                    out.lastNeedWinNeed = n
                elseif n.result == "lost" then
                    out.needLost = out.needLost + 1
                    out.lostNeedCurrent = out.lostNeedCurrent + 1
                    out.lostNeedMax = max(out.lostNeedMax, out.lostNeedCurrent)
                    out.lastNeedLoss = n
                else
                    hasPending = true
                    out.needPending = out.needPending + 1
                end
            end
            if hasNeed then
                out.needDungeons = out.needDungeons + 1
                if hasPending then out.pendingDungeons = out.pendingDungeons + 1 end
                if hasWin then
                    out.noNeedWinCurrent = 0
                else
                    out.noNeedWinDungeons = out.noNeedWinDungeons + 1
                    out.noNeedWinCurrent = out.noNeedWinCurrent + 1
                    out.noNeedWinMax = max(out.noNeedWinMax, out.noNeedWinCurrent)
                end
            end

            -- Vor dem ersten Need-Wurf beginnt die Serie noch nicht.
            if hasNeed then seenNeed = true end
            if hasWin then
                out.sinceNeedWinCurrent = 0
            elseif seenNeed then
                out.sinceNeedWinCurrent = out.sinceNeedWinCurrent + 1
                out.sinceNeedWinMax = max(out.sinceNeedWinMax, out.sinceNeedWinCurrent)
            end
        end
    end

    out.resolvedNeeds = out.needWins + out.needLost
    if out.resolvedNeeds > 0 then
        out.winRate = (out.needWins / out.resolvedNeeds) * 100
    end

    return out
end

function Stats.RunBasis(runs, run)
    if type(run) ~= "table" then return nil end
    local basis = {
        noLoot = run.lootSeen ~= true,
        needLost = 0,
        needPending = 0,
        needWon = 0,
        needTotal = 0,
    }
    for _, need in ipairs(run.needs or {}) do
        basis.needTotal = basis.needTotal + 1
        if need.result == "won" then
            basis.needWon = basis.needWon + 1
        elseif need.result == "lost" then
            basis.needLost = basis.needLost + 1
        else
            basis.needPending = basis.needPending + 1
        end
    end
    basis.noNeedWin = basis.needTotal > 0 and basis.needWon == 0
    local seenNeed = false
    for _, entry in ipairs(type(runs) == "table" and runs or {}) do
        if entry == run then
            if basis.needWon > 0 then
                basis.sinceNeedWin = "reset"
            elseif seenNeed or basis.needTotal > 0 then
                basis.sinceNeedWin = "increment"
            else
                basis.sinceNeedWin = "not-started"
            end
            break
        end
        if type(entry) == "table" and #(entry.needs or {}) > 0 then seenNeed = true end
    end
    return basis
end

function Stats.RunStatusKey(run, active)
    if type(run) ~= "table" then return nil end
    if run.closedReason == "manual" then return "RUN_STATUS_MANUAL" end
    if run.partial then return "RUN_STATUS_PARTIAL" end
    if run.paused then return "RUN_STATUS_PAUSED" end
    if active then return "RUN_STATUS_LIVE" end
    if not run.closed then return "RUN_STATUS_OPEN" end
    return nil
end

return Stats
