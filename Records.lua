-- LootJinx – optionale lokale Rekord-Meldungen
local ADDON, ns = ...
local LJ = ns or _G.LootJinx or {}
_G.LootJinx = LJ

local R = {}
LJ.Records = R

local RECORDS = {
    { key = "noAgiMax", label = "RECORD_NAME_CURSE" },
    { key = "lostNeedMax", label = "RECORD_NAME_NEED_LOSS" },
    { key = "noNeedWinMax", label = "RECORD_NAME_NO_WIN" },
    { key = "noLootMax", label = "RECORD_NAME_NO_LOOT" },
    { key = "sinceNeedWinMax", label = "RECORD_NAME_SINCE" },
}

local function settledRuns(runs)
    local provisional = {}
    for i = 1, #(runs or {}) do
        local run = runs[i]
        if type(run) == "table" and run.provisionalPreviousID then
            provisional[run.provisionalPreviousID] = true
        end
    end
    local closed = {}
    for i = 1, #(runs or {}) do
        local run = runs[i]
        if type(run) == "table" and run.closed == true
            and not provisional[run.id] then
            closed[#closed + 1] = run
        end
    end
    return closed
end

-- Rekorde aus abgeschlossenen Runs, damit ein laufender Dungeon noch keinen
-- vorläufigen Rekord meldet. Verlorene Need-Rolls stehen dagegen sofort fest
-- und werden deshalb aus allen Runs gezählt.
function R:Snapshot(runs)
    if not LJ.Stats then return nil end
    runs = type(runs) == "table" and runs or {}
    local all = LJ.Stats.Compute(runs)
    local closed = LJ.Stats.Compute(settledRuns(runs))
    return {
        noAgiMax = closed.noAgiMax or 0,
        lostNeedMax = all.lostNeedMax or 0,
        noNeedWinMax = closed.noNeedWinMax or 0,
        noLootMax = closed.noLootMax or 0,
        sinceNeedWinMax = closed.sinceNeedWinMax or 0,
    }
end

function R:Changes(previous, current)
    local changes = {}
    if type(previous) ~= "table" or type(current) ~= "table" then return changes end
    for i = 1, #RECORDS do
        local record = RECORDS[i]
        local before = tonumber(previous[record.key]) or 0
        local after = tonumber(current[record.key]) or 0
        if after > before then
            changes[#changes + 1] = {
                key = record.key,
                label = record.label,
                value = after,
            }
        end
    end
    return changes
end

function R:Check()
    if not LJ.Stats or not LJ.Tracker then return end
    local current = self:Snapshot(LJ.Tracker:GetRuns())
    local previous = self.last
    self.last = current
    if not previous or not LJ.DB or LJ.DB.announceRecords ~= true then return end
    local changes = self:Changes(previous, current)
    for i = 1, #changes do
        local change = changes[i]
        LJ:Print(LJ.L("CHAT_RECORD", LJ.L(change.label), change.value))
    end
end

LJ:RegisterRefresh(function() R:Check() end)
