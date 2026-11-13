-- LootJinx – Erfassung von Dungeons, Loot und Need-Rolls
local ADDON, ns = ...
local LJ = ns or _G.LootJinx
if not LJ then return end

local T = {}
LJ.Tracker = T

local RESUME_SECONDS = 15 * 60
local NEED_TIMEOUT = 5 * 60
local DEDUPE_SECONDS = 5
local REPAIR_SECONDS = 15 * 60
local BOSS_LINK_SECONDS = 5 * 60
local MAX_BOSSES = 20
local MAX_DROPS = 120
local MAX_ROLLS = 200

local inside = false
local blocked = false
local staleTimer
local repairScheduled = false
local reclassifyScheduled = false
local started = false
local firstCheck = true
local lastPrimaryStat
local recentGreed = {}
local rollLinks = {}
local rollLinkAt = {}
local rollLinkCount = 0

local function now()
    return LJ.Now()
end

local function after(seconds, fn)
    if C_Timer and C_Timer.After then
        C_Timer.After(seconds, function() pcall(fn) end)
    end
end

local function lower(s)
    s = LJ.Plain(s)
    if type(s) ~= "string" then return nil end
    return s:lower()
end

local function db()
    return LJ.CharDB
end

local localizedClassFiles
local function classFileFromLocalized(name)
    local raw = LJ.Plain(name)
    if type(raw) == "string" and _G.RAID_CLASS_COLORS and _G.RAID_CLASS_COLORS[raw] then
        return raw
    end
    name = lower(name)
    if not name then return nil end
    if not localizedClassFiles then
        localizedClassFiles = {}
        local function add(map)
            if type(map) ~= "table" then return end
            for classFile, localized in pairs(map) do
                if type(localized) == "string" then
                    localizedClassFiles[localized:lower()] = classFile
                end
            end
        end
        add(_G.LOCALIZED_CLASS_NAMES_MALE)
        add(_G.LOCALIZED_CLASS_NAMES_FEMALE)
    end
    return localizedClassFiles[name]
end

local function classFileFromGUID(guid)
    guid = LJ.Plain(guid)
    if type(guid) ~= "string" or guid == "" then return nil end
    if type(GetPlayerInfoByGUID) ~= "function" then return nil end
    local ok, localized, classFile = pcall(GetPlayerInfoByGUID, guid)
    if not ok then return nil end
    classFile = LJ.Plain(classFile)
    if type(classFile) == "string" and classFile ~= "" then return classFile end
    return classFileFromLocalized(localized)
end

local function playerClassFile()
    if type(UnitClass) ~= "function" then return nil end
    local ok, _, classFile = pcall(UnitClass, "player")
    classFile = ok and LJ.Plain(classFile) or nil
    return type(classFile) == "string" and classFile or nil
end

local function activeRun()
    local data = db()
    if not data or not data.activeID then return nil end
    for i = #data.runs, 1, -1 do
        local run = data.runs[i]
        if run.id == data.activeID and not run.closed then return run end
    end
    return nil
end

local function lastRecentBoss(run, at)
    at = at or now()
    for i = #((run and run.bosses) or {}), 1, -1 do
        local boss = run.bosses[i]
        if boss and at - (boss.at or 0) <= BOSS_LINK_SECONDS then return boss end
    end
    return nil
end

local function bossByID(run, id)
    id = tonumber(id)
    if not id or id <= 0 then return nil end
    for i = #((run and run.bosses) or {}), 1, -1 do
        local boss = run.bosses[i]
        if boss and boss.id == id then return boss end
    end
    return nil
end

local function rollFor(run, id, name)
    name = lower(name)
    if not id or not name then return nil end
    for i = #((run and run.rolls) or {}), 1, -1 do
        local roll = run.rolls[i]
        if roll.id == id and lower(roll.name) == name then
            return roll.kind, roll.value
        end
    end
    return nil
end

function T:GetRuns()
    local data = db()
    return data and data.runs or {}
end

function T:GetActive()
    return activeRun()
end

function T:IsInside()
    return inside
end

function T:IsLive()
    return inside and activeRun() ~= nil
end

-- ---------------------------------------------------------------- Zone
local function getDungeon()
    if type(IsInInstance) ~= "function" then return nil end
    local ok, inInstance, kind = pcall(IsInInstance)
    if not ok then return nil end
    inInstance, kind = LJ.Plain(inInstance), LJ.Plain(kind)
    if not inInstance then return nil end
    if kind ~= "party" and kind ~= "scenario" then return nil end

    local okI, name, instanceType, difficultyID, difficultyName, maxPlayers,
        dynamicDifficulty, isDynamic, instanceID = pcall(GetInstanceInfo)
    if not okI then return nil end
    name = LJ.Plain(name)
    instanceType = LJ.Plain(instanceType)
    if kind ~= "party" and instanceType ~= "party" then return nil end
    if type(name) ~= "string" or name == "" then
        name = LJ.L("UNKNOWN_DUNGEON")
    end
    instanceID = tonumber(LJ.Plain(instanceID))
    local key = (instanceID and instanceID > 0) and tostring(instanceID) or name
    return {
        name = name,
        key = key,
        instanceID = instanceID,
        difficulty = LJ.Plain(difficultyName),
        kind = kind,
    }
end

local function sameInstance(run, d)
    if run.key and d.key then return tostring(run.key) == tostring(d.key) end
    return lower(run.name) == lower(d.name)
end

local function cancelStaleTimer()
    if staleTimer and staleTimer.Cancel then
        pcall(staleTimer.Cancel, staleTimer)
    end
    staleTimer = nil
end

function T:ScheduleStaleClose()
    if not (C_Timer and C_Timer.NewTimer) then return end
    cancelStaleTimer()
    staleTimer = C_Timer.NewTimer(RESUME_SECONDS + 2, function()
        pcall(T.CloseStale, T)
        LJ:Changed()
    end)
end

function T:CloseStale()
    local run = activeRun()
    if not run or inside then return false end
    if run.paused then return false end
    local since = run.outsideAt or run.lastSeen or run.started or 0
    if since > 0 and now() - since >= RESUME_SECONDS then
        T:CloseActive("stale")
        return true
    end
    return false
end

function T:CloseActive(reason)
    local run = activeRun()
    if not run then return false end
    if type(StaticPopup_Hide) == "function" then StaticPopup_Hide("LOOTJINX_RUN_EXIT") end
    T:ResolveStaleNeeds(run, true)
    T:FinalizeRunItems(run)
    run.closed = true
    run.paused = false
    run.ended = run.ended or now()
    run.closedReason = reason or "closed"
    local data = db()
    if data then data.activeID = nil end
    LJ:Changed()
    return true
end

function T:PauseActive(runID)
    local run = activeRun()
    if not run or inside or run.id ~= tonumber(runID) then return false end
    run.paused = true
    LJ:Changed()
    return true
end

function T:DiscardActive(runID)
    local run = activeRun()
    if not run or inside or run.id ~= tonumber(runID) then return false end
    local data = db()
    if not data then return false end
    for i = #data.runs, 1, -1 do
        if data.runs[i] == run then
            table.remove(data.runs, i)
            break
        end
    end
    data.activeID = nil
    cancelStaleTimer()
    if type(StaticPopup_Hide) == "function" then StaticPopup_Hide("LOOTJINX_RUN_EXIT") end
    if LJ.RunDetail and type(LJ.RunDetail.Hide) == "function" then
        LJ.RunDetail:Hide()
    end
    LJ:Changed()
    return true
end

local function markAgility(run, link, info)
    if run.agilityDropped then return false end
    run.agilityDropped = true
    run.agiItemsSeen = (run.agiItemsSeen or 0) + 1
    run.agilityLink = run.agilityLink or link
    run.agilityAt = run.agilityAt or now()
    if info and info.name then run.agilityName = info.name end
    return true
end

function T:StartRun(d, partial)
    local data = db()
    if not data then return nil end
    local run = {
        id = tonumber(data.nextRunID) or 1,
        name = d.name,
        key = d.key,
        instanceID = d.instanceID,
        difficulty = d.difficulty,
        started = now(),
        lastSeen = now(),
        lootSeen = false,
        agilityDropped = false,
        itemsSeen = 0,
        agiItemsSeen = 0,
        needs = {},
        pending = {},
        seenLinks = {},
        greeds = {},
        bosses = {},
        drops = {},
        rolls = {},
        detailVersion = 1,
        legacy = false,
        partial = partial == true,
        closed = false,
        paused = false,
    }
    data.nextRunID = run.id + 1
    data.runs[#data.runs + 1] = run
    data.activeID = run.id
    inside = true
    blocked = false
    T:ScheduleStaleClose()
    LJ:Changed()
    return run
end

function T:CheckZone()
    if not db() then return end
    local wasFirst = firstCheck
    firstCheck = false
    T:CloseStale()

    local d = getDungeon()
    if d then
        if blocked then return end
        local run = activeRun()
        if run and sameInstance(run, d) then
            inside = true
            if type(StaticPopup_Hide) == "function" then StaticPopup_Hide("LOOTJINX_RUN_EXIT") end
            run.paused = false
            run.outsideAt = nil
            run.lastSeen = now()
            run.key = d.key
            run.instanceID = d.instanceID or run.instanceID
            run.difficulty = d.difficulty or run.difficulty
            if d.name and d.name ~= "" then run.name = d.name end
            T:ScheduleStaleClose()
            LJ:Changed()
            return
        end
        if run then T:CloseActive("switched-instance") end
        T:StartRun(d, wasFirst)
    else
        local wasInside = inside
        inside = false
        blocked = false
        local run = activeRun()
        if run then
            run.outsideAt = run.outsideAt or now()
            run.lastSeen = now()
            if wasInside then LJ:Changed() end
            if wasInside and type(StaticPopup_Show) == "function" then
                StaticPopup_Show("LOOTJINX_RUN_EXIT", run.name, nil, run.id)
            end
        end
        T:ScheduleStaleClose()
    end
end

-- ---------------------------------------------------------------- Item-Links
local function cacheRollLink(rollID, link)
    rollID = tonumber(rollID)
    if not rollID then return nil end
    link = LJ:NormalizeLink(link)
    if link and link ~= "" then
        if not rollLinks[rollID] then rollLinkCount = rollLinkCount + 1 end
        rollLinks[rollID] = link
        rollLinkAt[rollID] = now()
    end
    return rollLinks[rollID]
end

local function rollLink(rollID)
    rollID = tonumber(rollID)
    if not rollID then return nil end
    local cached = rollLinks[rollID]
    if cached then return cached end
    if type(GetLootRollItemLink) ~= "function" then return nil end
    local ok, link = pcall(GetLootRollItemLink, rollID)
    link = ok and LJ.Plain(link) or nil
    if type(link) ~= "string" or link == "" then return nil end
    return cacheRollLink(rollID, link)
end

local function pruneRollLinks()
    if rollLinkCount < 250 then return end
    local cutoff = now() - 900
    local kept = 0
    for id, at in pairs(rollLinkAt) do
        if at < cutoff then
            rollLinks[id] = nil
            rollLinkAt[id] = nil
        else
            kept = kept + 1
        end
    end
    rollLinkCount = kept
end

local function pendingRun()
    if not inside then return nil end
    return activeRun()
end

local function queuePending(run, link, id, info)
    if not run or not link then return end
    run.pending = run.pending or {}
    for i = 1, #run.pending do
        local p = run.pending[i]
        if p.link == link then return end
    end
    run.pending[#run.pending + 1] = {
        link = link,
        id = id,
        added = now(),
        countedLoot = info and info.loot == true or false,
    }
    while #run.pending > 80 do table.remove(run.pending, 1) end
    LJ:LoadItem(link, id)
    if not reclassifyScheduled then
        reclassifyScheduled = true
        after(2, function()
            reclassifyScheduled = false
            T:ReclassifyPending()
        end)
    end
end

function T:RecordItem(link, source)
    local run = pendingRun()
    if not run then return false end
    link = LJ:NormalizeLink(link)
    if type(link) ~= "string" then return false end
    local id = LJ:ItemID(link)
    if not id then return false end
    run.seenLinks = run.seenLinks or {}
    if run.seenLinks[link] then return false end
    run.seenLinks[link] = true

    local info = LJ:ClassifyItem(link)
    if LJ.debugMode then LJ:NoteItemDebug(link, source) end
    if not info then
        queuePending(run, link, id, nil)
        return false
    end
    if info.quest then return false end

    local changed = false
    local knownLoot = info.loot == true
    if knownLoot then
        run.lootSeen = true
        run.itemsSeen = (run.itemsSeen or 0) + 1
        changed = true
    end
    if info.agi == true then
        if markAgility(run, link, info) then changed = true end
    elseif info.agi == nil then
        queuePending(run, link, id, info)
    end
    if changed then LJ:Changed() end
    return changed
end

local function finalizePending(entry, info)
    if info.quest then return "drop", false, false end
    if not info.loot then return "keep", false, false end
    if info.agi == true then return "agi", true, true end
    if info.agi == false then return "done", true, false end
    return "keep", true, false
end

function T:ReclassifyPending(itemID)
    local data = db()
    if not data then return end
    local changed = false
    for _, run in ipairs(data.runs) do
        local pending = run.pending
        if type(pending) == "table" and #pending > 0 then
            local keep = {}
            for i = 1, #pending do
                local p = pending[i]
                local info = LJ:ClassifyItem(p.link)
                if info and (not itemID or p.id == itemID or info.id == itemID) then
                    local action, counted, agi = finalizePending(p, info)
                    if counted and not p.countedLoot then
                        p.countedLoot = true
                        run.lootSeen = true
                        run.itemsSeen = (run.itemsSeen or 0) + 1
                        changed = true
                    end
                    if action == "agi" then
                        if markAgility(run, p.link, info) then changed = true end
                    elseif action == "keep" then
                        keep[#keep + 1] = p
                    end
                    if action ~= "keep" then changed = true end
                else
                    keep[#keep + 1] = p
                end
            end
            run.pending = keep
        end
    end
    if changed then LJ:Changed() end
end

function T:FinalizeRunItems(run)
    if not run then return end
    local pending = run.pending
    if type(pending) == "table" then
        for i = 1, #pending do
            local p = pending[i]
            local info = LJ:ClassifyItem(p.link)
            if info and info.agi == true then markAgility(run, p.link, info) end
        end
    end
    run.pending = {}
end

-- Bewertet alle bereits gesehenen Items eines Runs mit dem aktuellen
-- Primärstat neu (z. B. nach einem Spezialisierungswechsel).
local function rebuildRunItems(run)
    run.lootSeen = false
    run.itemsSeen = 0
    run.agilityDropped = false
    run.agiItemsSeen = 0
    run.agilityLink = nil
    run.agilityAt = nil
    run.agilityName = nil
    for link in pairs(run.seenLinks or {}) do
        local info = LJ:ClassifyItem(link)
        if info and not info.quest then
            if info.loot == true then
                run.lootSeen = true
                run.itemsSeen = run.itemsSeen + 1
                for i = 1, #(run.pending or {}) do
                    local p = run.pending[i]
                    if p.link == link then p.countedLoot = true end
                end
            end
            if info.agi == true then
                run.agilityDropped = true
                run.agiItemsSeen = run.agiItemsSeen + 1
                run.agilityLink = run.agilityLink or link
                run.agilityAt = run.agilityAt or run.started or now()
                run.agilityName = run.agilityName or info.name
            end
        end
    end
end

function T:ReclassifyAll()
    local data = db()
    if not data then return end
    for _, run in ipairs(data.runs) do rebuildRunItems(run) end
    LJ:Changed()
end

function T:CheckPrimaryStatChanged()
    local stat = LJ:PlayerStat()
    if not lastPrimaryStat then
        lastPrimaryStat = stat
        return false
    end
    if lastPrimaryStat == stat then return false end
    lastPrimaryStat = stat
    T:ReclassifyAll()
    return true
end

-- ---------------------------------------------------------------- Need-Rolls
local function needMatches(n, itemID, link, rollID, maxAge)
    if n.result ~= nil then return false end
    if maxAge and now() - (n.at or 0) > maxAge then return false end
    if rollID and n.rollID == rollID then return true end
    if link and n.link == link then return true end
    if itemID and n.id == itemID then return true end
    if link and n.rollID and rollLinks[n.rollID] == link then return true end
    if itemID and n.rollID and LJ:ItemID(rollLinks[n.rollID]) == itemID then return true end
    return false
end

function T:FindPendingNeed(itemID, link, maxAge)
    local data = db()
    if not data then return nil, nil end
    local found, foundRun
    for i = #data.runs, 1, -1 do
        local run = data.runs[i]
        for j = #(run.needs or {}), 1, -1 do
            local n = run.needs[j]
            if needMatches(n, itemID, link, nil, maxAge or 900) then
                if not found or (n.at or 0) >= (found.at or 0) then
                    found, foundRun = n, run
                end
            end
        end
    end
    return found, foundRun
end

function T:ResolveNeed(need, result, reason)
    if not need or (result ~= "won" and result ~= "lost") then return false end
    if need.result == "won" then return false end
    if need.result == "lost" and result ~= "won" then return false end
    need.result = result
    need.resolvedAt = now()
    need.reason = reason or "event"
    LJ:Changed()
    return true
end

function T:HasGreedConflict(need, run)
    local id = need and need.id
    if not id then return false end
    local at = need.at or now()
    if recentGreed[id] and math.abs(recentGreed[id] - at) <= 180 then return true end
    for i = 1, #((run and run.greeds) or {}) do
        local g = run.greeds[i]
        if g.id == id and math.abs((g.at or 0) - at) <= 180 then return true end
    end
    return false
end

function T:ResolveNeedByBags(need, run, force)
    if not need or need.result == "won" then return false end
    if need.result == "lost" and not force then return false end
    local id = need.id
    if not id then
        return T:ResolveNeed(need, "lost", "no-item")
    end
    local count = LJ:ItemCount(id)
    local before = tonumber(need.before) or 0
    if count > before then
        if T:HasGreedConflict(need, run) then
            need.noRepair = true
            return T:ResolveNeed(need, "lost", "greed-guard")
        end
        return T:ResolveNeed(need, "won", "bags")
    end
    return T:ResolveNeed(need, "lost", "bags")
end

function T:ResolveStaleNeeds(run, force)
    if not run then return end
    local t = now()
    for i = 1, #(run.needs or {}) do
        local n = run.needs[i]
        if n.result == nil then
            local age = t - (n.at or t)
            if force or age > NEED_TIMEOUT then
                T:ResolveNeedByBags(n, run, force)
            end
        end
    end
end

function T:ResolveStaleNeedsAll(force)
    local data = db()
    if not data then return end
    for i = 1, #data.runs do
        T:ResolveStaleNeeds(data.runs[i], force)
    end
end

function T:RepairLostNeeds()
    local data = db()
    if not data then return end
    local t = now()
    local changed = false
    for _, run in ipairs(data.runs) do
        for _, n in ipairs(run.needs or {}) do
            if n.result == "lost" and not n.noRepair and n.id
                and (n.reason == "bags" or n.reason == "no-item") then
                local at = n.resolvedAt or n.at or 0
                if t - at <= REPAIR_SECONDS then
                    local before = tonumber(n.before) or 0
                    if LJ:ItemCount(n.id) > before and not T:HasGreedConflict(n, run) then
                        n.result = "won"
                        n.resolvedAt = t
                        n.reason = "repair"
                        changed = true
                    end
                end
            end
        end
    end
    if changed then LJ:Changed() end
end

local function scheduleRepair()
    if repairScheduled then return end
    repairScheduled = true
    after(1.5, function()
        repairScheduled = false
        T:RepairLostNeeds()
    end)
end

function T:OnNeedRoll(rollID, link)
    if not inside then return end
    local run = activeRun()
    if not run then return end
    rollID = tonumber(rollID)
    link = link or (rollID and rollLink(rollID)) or nil
    link = LJ:NormalizeLink(link)
    local id = LJ:ItemID(link)

    if link then T:RecordItem(link, "need-roll") end

    for i = 1, #(run.needs or {}) do
        local n = run.needs[i]
        if n.result == nil then
            local sameRoll = rollID and n.rollID == rollID
            local sameItem = id and n.id == id and now() - (n.at or 0) <= DEDUPE_SECONDS
            local sameCached = id and n.rollID and LJ:ItemID(rollLinks[n.rollID]) == id
                and now() - (n.at or 0) <= DEDUPE_SECONDS
            if sameRoll or sameItem or sameCached then
                if not n.link and link then n.link = link end
                if not n.id and id then n.id = id end
                n.rollID = n.rollID or rollID
                if n.id and not n.before then n.before = LJ:ItemCount(n.id) end
                LJ:Changed()
                return
            end
        end
    end

    local need = {
        at = now(),
        id = id,
        link = link,
        rollID = rollID,
        before = id and LJ:ItemCount(id) or 0,
    }
    run.needs[#run.needs + 1] = need
    LJ:Changed()

    if not link and rollID then
        after(0.5, function() T:FillNeedLink(need, rollID) end)
        after(2, function() T:FillNeedLink(need, rollID) end)
        after(6, function() T:FillNeedLink(need, rollID) end)
    end
end

function T:FillNeedLink(need, rollID)
    if not need then return end
    local link = need.link or rollLink(rollID)
    if not link then return end
    need.link = need.link or link
    if not need.id then need.id = LJ:ItemID(link) end
    if need.id and (not need.before or need.before == 0) then
        need.before = LJ:ItemCount(need.id)
    end
    LJ:Changed()
end

function T:MarkGreed(rollID, link)
    if not inside then return end
    local run = activeRun()
    if not run then return end
    rollID = tonumber(rollID)
    link = link or (rollID and rollLink(rollID)) or nil
    link = LJ:NormalizeLink(link)
    if link then T:RecordItem(link, "greed-roll") end
    local id = LJ:ItemID(link)
    if not id then return end
    run.greeds = run.greeds or {}
    run.greeds[#run.greeds + 1] = { at = now(), id = id, link = link, rollID = rollID }
    while #run.greeds > 25 do table.remove(run.greeds, 1) end
    recentGreed[id] = now()
end

function T:ResolveNeedByLink(link, result, reason)
    link = LJ:NormalizeLink(link)
    local id = LJ:ItemID(link)
    local need, run = T:FindPendingNeed(id, link, 900)
    if not need then return false end
    if result == "won" then
        return T:ResolveNeed(need, "won", reason)
    elseif result == "lost" then
        if T:HasGreedConflict(need, run) then
            need.noRepair = true
            return T:ResolveNeed(need, "lost", "greed-guard")
        end
        return T:ResolveNeed(need, "lost", reason)
    end
    return false
end

function T:ResolveNeedByRoll(rollID)
    rollID = tonumber(rollID)
    if not rollID then return end
    local data = db()
    if not data then return end
    for _, run in ipairs(data.runs) do
        for _, n in ipairs(run.needs or {}) do
            if n.result == nil and n.rollID == rollID then
                T:ResolveNeedByBags(n, run, true)
                return
            end
        end
    end
end

-- ---------------------------------------------------------------- Loot-Events
-- ---------------------------------------------------------------- Boss-/Drop-Details
local function noteDrop(run, link, winner, boss, source, rollValue, rollKind, passed, winnerClass)
    if not run then return false end
    link = LJ:NormalizeLink(link)
    local id = LJ:ItemID(link)
    if not id then return false end
    winner = LJ.Plain(winner)
    if type(winner) == "string" then
        winner = winner:match("^%s*(.-)%s*$")
        if winner == "" then winner = nil end
    else
        winner = nil
    end
    local bossID = boss and tonumber(boss.id) or 0
    if not bossID or bossID <= 0 then bossID = 0 end
    local bossName = boss and boss.name or nil
    rollValue = tonumber(rollValue)
    rollKind = (rollKind == "need" or rollKind == "greed") and rollKind or nil
    local at = now()

    run.drops = run.drops or {}
    for i = #run.drops, 1, -1 do
        local d = run.drops[i]
        local sameBoss
        if bossID > 0 then
            sameBoss = (d.bossID or 0) == bossID
        else
            sameBoss = (d.bossID or 0) == 0 and lower(d.bossName) == lower(bossName)
        end
        if d.id == id and sameBoss and at - (d.at or 0) <= 15 * 60 then
            local sameWinner = not d.winner or not winner or lower(d.winner) == lower(winner)
            if sameWinner then
                local changed = false
                if winner and not d.winner then d.winner = winner; changed = true end
                if winner and winnerClass and not d.winnerClass then d.winnerClass = winnerClass; changed = true end
                if rollValue and not d.roll then d.roll = rollValue; changed = true end
                if rollKind and not d.rollKind then d.rollKind = rollKind; changed = true end
                if source == "encounter" and d.source ~= "encounter" then
                    d.source = "encounter"
                    changed = true
                end
                if passed and not d.passed and not d.winner then d.passed = true; changed = true end
                if d.winner and d.passed then d.passed = false; changed = true end
                if changed then LJ:Changed() end
                return true
            end
        end
    end

    if not rollValue and winner then
        local kind, value = rollFor(run, id, winner)
        rollValue, rollKind = value, kind
    end

    run.drops[#run.drops + 1] = {
        id = id,
        link = link,
        bossID = bossID,
        bossName = bossName,
        at = at,
        winner = winner,
        winnerClass = winnerClass,
        roll = rollValue,
        rollKind = rollKind,
        passed = passed == true and not winner or false,
        source = source,
    }
    while #run.drops > MAX_DROPS do table.remove(run.drops, 1) end
    LJ:Changed()
    return true
end

function T:NoteDrop(...)
    return noteDrop(activeRun(), ...)
end

function T:NoteRoll(link, name, kind, value)
    local run = activeRun()
    if not run then return false end
    link = LJ:NormalizeLink(link)
    local id = LJ:ItemID(link)
    value = tonumber(value)
    name = LJ.Plain(name)
    if type(name) == "string" then
        name = name:match("^%s*(.-)%s*$")
    end
    if not id or not value or type(name) ~= "string" or name == "" then return false end
    kind = kind == "greed" and "greed" or "need"
    run.rolls = run.rolls or {}
    local at = now()
    local found
    for i = 1, #run.rolls do
        local roll = run.rolls[i]
        if roll.id == id and roll.kind == kind and lower(roll.name) == lower(name) then
            found = roll
            break
        end
    end
    if found then
        found.value = value
        found.at = at
    else
        run.rolls[#run.rolls + 1] = { id = id, name = name, kind = kind, value = value, at = at }
        while #run.rolls > MAX_ROLLS do table.remove(run.rolls, 1) end
    end

    local changed = false
    for i = 1, #(run.drops or {}) do
        local drop = run.drops[i]
        if drop.id == id and drop.winner and lower(drop.winner) == lower(name) and not drop.roll then
            drop.roll = value
            drop.rollKind = kind
            changed = true
        end
    end
    if LJ:IsMe(name) then
        for i = 1, #(run.needs or {}) do
            local need = run.needs[i]
            if need.id == id and not need.roll then
                need.roll = value
                need.rollKind = kind
                changed = true
            end
        end
    end
    LJ:Changed()
    return true
end

function T:NotePassed(link)
    local run = activeRun()
    if not run then return false end
    return noteDrop(run, link, nil, lastRecentBoss(run), "chat", nil, nil, true)
end

function T:NoteSeenDrop(link, source)
    local run = activeRun()
    if not run then return false end
    return noteDrop(run, link, nil, lastRecentBoss(run), source or "seen")
end

function T:OnBossEvent(event, ...)
    local run = activeRun()
    if not run then return end
    local id, name, success
    if event == "ENCOUNTER_END" then
        id, name = select(1, ...), select(2, ...)
        success = select(5, ...)
    else
        id, name = select(1, ...), select(2, ...)
        success = 1
    end
    id = tonumber(LJ.Plain(id))
    if id and id <= 0 then id = nil end
    name = LJ.Plain(name)
    if type(name) == "string" then name = name:match("^%s*(.-)%s*$") end
    success = LJ.Plain(success)
    if not (success == 1 or success == true or success == "1") then return end
    if type(name) ~= "string" or name == "" then name = LJ.L("DETAIL_UNKNOWN_BOSS") end

    run.bosses = run.bosses or {}
    local at = now()
    local last = run.bosses[#run.bosses]
    local same = last and at - (last.at or 0) <= 60 and (
        (id and last.id == id) or
        (last.name and lower(last.name) == lower(name)))
    if same then
        last.at = at
        last.name = name
        if id then last.id = id end
    else
        run.bosses[#run.bosses + 1] = { id = id, name = name, at = at }
        while #run.bosses > MAX_BOSSES do table.remove(run.bosses, 1) end
    end
    LJ:Changed()
end

function T:OnEncounterLoot(...)
    local run = activeRun()
    if not run then return end
    local args = { ... }
    local link
    for i = 1, #args do
        local candidate = LJ:NormalizeLink(args[i])
        if candidate and LJ:ItemID(candidate) then
            link = candidate
            break
        end
    end
    if not link then return end
    local encounterID = tonumber(LJ.Plain(args[1]))
    local boss = bossByID(run, encounterID) or lastRecentBoss(run)
    local winner = LJ.Plain(args[5])
    if type(winner) == "string" then
        winner = winner:match("^%s*(.-)%s*$")
        if winner == "" then winner = nil end
    else
        winner = nil
    end
    local classFile = classFileFromLocalized(args[6])
    T:RecordItem(link, "encounter")
    noteDrop(run, link, winner, boss, "encounter", nil, nil, nil, classFile)
end

function T:OnStartRoll(rollID)
    rollID = tonumber(rollID)
    if not rollID then return end
    pruneRollLinks()
    local link = rollLink(rollID)
    if link then
        T:RecordItem(link, "loot-roll")
        T:NoteSeenDrop(link, "roll")
        return
    end
    local function retry()
        local l = rollLink(rollID)
        if l then
            T:RecordItem(l, "loot-roll-late")
            T:NoteSeenDrop(l, "roll-late")
        end
    end
    after(0.4, retry)
    after(1.5, retry)
    after(4, retry)
end

function T:OnCancelRoll(rollID)
    rollID = tonumber(rollID)
    if not rollID then return end
    after(4, function() T:ResolveNeedByRoll(rollID) end)
    after(20, function() T:ResolveNeedByRoll(rollID) end)
end

function T:OnLootWindow()
    if not inside or type(GetNumLootItems) ~= "function" then return end
    local ok, count = pcall(GetNumLootItems)
    count = ok and tonumber(LJ.Plain(count)) or nil
    if not count then return end
    for slot = 1, count do
        local okL, link = pcall(GetLootSlotLink, slot)
        link = okL and LJ.Plain(link) or nil
        if type(link) == "string" and link ~= "" then
            T:RecordItem(link, "loot-window")
            T:NoteSeenDrop(link, "loot-window")
        end
    end
end

-- ---------------------------------------------------------------- Chat-Muster
local function MakePattern(fmt, anchorEnd)
    if type(fmt) ~= "string" or fmt == "" then return nil end
    local out, order, i = {}, {}, 1
    while i <= #fmt do
        local c = fmt:sub(i, i)
        if c == "%" then
            local pos, conv = fmt:match("^%%(%d)%$([sd])", i)
            local skip = 4
            if not conv then
                conv = fmt:match("^%%([sd])", i)
                skip = 2
            end
            if conv then
                order[#order + 1] = tonumber(pos) or (#order + 1)
                out[#out + 1] = conv == "d" and "([%d%.,]+)" or "(.-)"
                i = i + skip
            elseif fmt:sub(i + 1, i + 1) == "%" then
                out[#out + 1] = "%%"
                i = i + 2
            else
                out[#out + 1] = "%%"
                i = i + 1
            end
        elseif c:find("[%(%)%.%+%-%*%?%[%]%^%$]") then
            out[#out + 1] = "%" .. c
            i = i + 1
        else
            out[#out + 1] = c
            i = i + 1
        end
    end
    return { pattern = "^" .. table.concat(out) .. (anchorEnd and "$" or ""), order = order }
end

local function Match(p, text)
    if not p or type(text) ~= "string" then return nil end
    local caps = { text:match(p.pattern) }
    if #caps == 0 then return nil end
    local args = {}
    for k, argIndex in ipairs(p.order) do args[argIndex] = caps[k] end
    return args
end

local function Number(s)
    if type(s) ~= "string" then return tonumber(s) end
    return tonumber((s:gsub("[^%d]", "")))
end

local patterns
local function Patterns()
    if patterns then return patterns end
    patterns = {
        youWon = MakePattern(_G.LOOT_ROLL_YOU_WON, true),
        won = MakePattern(_G.LOOT_ROLL_WON, true),
        allPassed = MakePattern(_G.LOOT_ROLL_ALL_PASSED, true),
        needSelf = MakePattern(_G.LOOT_ROLL_NEED_SELF, true),
        greedSelf = MakePattern(_G.LOOT_ROLL_GREED_SELF, true),
        needOther = MakePattern(_G.LOOT_ROLL_NEED, true),
        greedOther = MakePattern(_G.LOOT_ROLL_GREED, true),
        rolledNeed = MakePattern(_G.LOOT_ROLL_ROLLED_NEED, true),
        rolledNeedBonus = _G.LOOT_ROLL_ROLLED_NEED_ROLE_BONUS and MakePattern(_G.LOOT_ROLL_ROLLED_NEED_ROLE_BONUS, true) or nil,
        rolledGreed = MakePattern(_G.LOOT_ROLL_ROLLED_GREED, true),
        lootSelf = MakePattern(_G.LOOT_ITEM_SELF, true),
        lootOther = MakePattern(_G.LOOT_ITEM, true),
        reset = MakePattern(_G.INSTANCE_RESET_SUCCESS, true),
    }
    return patterns
end

local function recordChatItems(raw)
    local links = LJ:ExtractItemLinks(raw)
    if links then
        for i = 1, #links do T:RecordItem(links[i], "chat") end
    else
        local id = LJ:ItemID(raw)
        if id then T:RecordItem(raw, "chat") end
    end
end

local function firstItemLink(raw)
    local links = LJ:ExtractItemLinks(raw)
    if links and #links > 0 then return links[1] end
    if LJ:ItemID(raw) then return raw end
    return nil
end

local function noteChatDrop(link, winner, guid)
    local run = activeRun()
    if not run then return end
    local classFile
    if winner and LJ:IsMe(winner) then
        classFile = playerClassFile()
    else
        classFile = classFileFromGUID(guid)
    end
    noteDrop(run, link, winner, lastRecentBoss(run), "chat", nil, nil, nil, classFile)
end

function T:OnLootChat(text, _who, guid)
    text = LJ.Plain(text)
    if type(text) ~= "string" then return end
    local p = Patterns()
    local args

    args = Match(p.youWon, text)
    if args then
        recordChatItems(args[1])
        noteChatDrop(firstItemLink(args[1]), LJ:PlayerName(), nil)
        T:ResolveNeedByLink(firstItemLink(args[1]), "won", "chat-won")
        return
    end

    args = Match(p.won, text)
    if args then
        recordChatItems(args[2])
        noteChatDrop(firstItemLink(args[2]), args[1], guid)
        if LJ:IsMe(args[1]) then
            T:ResolveNeedByLink(firstItemLink(args[2]), "won", "chat-won")
        else
            T:ResolveNeedByLink(firstItemLink(args[2]), "lost", "chat-other-won")
        end
        return
    end

    args = Match(p.allPassed, text)
    if args then
        recordChatItems(args[1])
        T:NotePassed(firstItemLink(args[1]))
        T:ResolveNeedByLink(firstItemLink(args[1]), "lost", "chat-all-passed")
        return
    end

    args = Match(p.needSelf, text)
    if args then
        recordChatItems(args[1])
        T:OnNeedRoll(nil, firstItemLink(args[1]))
        return
    end

    args = Match(p.greedSelf, text)
    if args then
        recordChatItems(args[1])
        T:MarkGreed(nil, firstItemLink(args[1]))
        return
    end

    args = Match(p.needOther, text)
    if args then
        recordChatItems(args[2])
        return
    end

    args = Match(p.greedOther, text)
    if args then
        recordChatItems(args[2])
        return
    end

    args = Match(p.rolledNeed, text) or Match(p.rolledNeedBonus, text)
    if args then
        recordChatItems(args[2])
        T:NoteRoll(firstItemLink(args[2]), args[3], "need", Number(args[1]))
        return
    end

    args = Match(p.rolledGreed, text)
    if args then
        recordChatItems(args[2])
        T:NoteRoll(firstItemLink(args[2]), args[3], "greed", Number(args[1]))
        return
    end

    args = Match(p.lootSelf, text)
    if args then
        recordChatItems(args[1])
        noteChatDrop(firstItemLink(args[1]), LJ:PlayerName(), nil)
        T:ResolveNeedByLink(firstItemLink(args[1]), "won", "chat-loot-self")
        return
    end

    args = Match(p.lootOther, text)
    if args then
        recordChatItems(args[2])
        noteChatDrop(firstItemLink(args[2]), args[1], guid)
        if not LJ:IsMe(args[1]) then
            T:ResolveNeedByLink(firstItemLink(args[2]), "lost", "chat-loot-other")
        else
            T:ResolveNeedByLink(firstItemLink(args[2]), "won", "chat-loot-self")
        end
    end
end

function T:OnSystem(text)
    text = LJ.Plain(text)
    if type(text) ~= "string" then return end
    local p = Patterns()
    local args = Match(p.reset, text)
    if not args then return end
    local resetName = lower(args[1])
    local run = activeRun()
    if not run then return end
    local runName = lower(run.name)
    if resetName and runName and resetName ~= runName then return end
    if inside then blocked = true end
    T:CloseActive("instance-reset")
    LJ:Changed()
end

-- ---------------------------------------------------------------- Events
local eventFrame
local function onEvent(event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        T:CloseStale()
        after(1, function()
            T:CheckZone()
            T:ResolveStaleNeedsAll(false)
            T:RepairLostNeeds()
        end)
        after(3, function()
            T:CheckZone()
            T:ResolveStaleNeedsAll(false)
        end)
    elseif event == "PLAYER_LEAVING_WORLD" then
        local run = activeRun()
        if run then
            run.lastSeen = now()
            run.outsideAt = run.outsideAt or now()
        end
    elseif event == "ZONE_CHANGED_NEW_AREA" then
        after(0.2, function() T:CheckZone() end)
        after(2, function() T:CheckZone() end)
    elseif event == "ZONE_CHANGED" then
        if inside then after(1, function() T:CheckZone() end) end
    elseif event == "ENCOUNTER_END" or event == "BOSS_KILL" then
        T:OnBossEvent(event, ...)
    elseif event == "ENCOUNTER_LOOT_RECEIVED" then
        T:OnEncounterLoot(...)
    elseif event == "START_LOOT_ROLL" then
        T:OnStartRoll((...))
    elseif event == "CANCEL_LOOT_ROLL" then
        T:OnCancelRoll((...))
    elseif event == "LOOT_OPENED" or event == "LOOT_READY" then
        T:OnLootWindow()
    elseif event == "CHAT_MSG_LOOT" then
        T:OnLootChat(select(1, ...), select(2, ...), select(12, ...))
    elseif event == "CHAT_MSG_SYSTEM" then
        T:OnSystem((...))
    elseif event == "GET_ITEM_INFO_RECEIVED" then
        local id = tonumber(LJ.Plain((...)))
        T:ReclassifyPending(id)
        LJ:Changed()
        after(1, function() T:ReclassifyPending(id) end)
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" or event == "PLAYER_TALENT_UPDATE" then
        after(1, function() T:CheckPrimaryStatChanged() end)
    elseif event == "BAG_UPDATE_DELAYED" then
        scheduleRepair()
    end
end

local function registerEvents()
    eventFrame = CreateFrame("Frame")
    local events = {
        "PLAYER_ENTERING_WORLD", "PLAYER_LEAVING_WORLD", "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED",
        "ENCOUNTER_END", "BOSS_KILL", "ENCOUNTER_LOOT_RECEIVED",
        "START_LOOT_ROLL", "CANCEL_LOOT_ROLL", "LOOT_OPENED", "LOOT_READY",
        "CHAT_MSG_LOOT", "CHAT_MSG_SYSTEM", "GET_ITEM_INFO_RECEIVED", "BAG_UPDATE_DELAYED",
        "PLAYER_SPECIALIZATION_CHANGED", "PLAYER_TALENT_UPDATE",
    }
    for i = 1, #events do pcall(eventFrame.RegisterEvent, eventFrame, events[i]) end
    eventFrame:SetScript("OnEvent", function(_, event, ...)
        pcall(onEvent, event, ...)
    end)
end

local function hookRolls()
    if T.hooked then return end
    T.hooked = true
    if type(RollOnLoot) ~= "function" or type(hooksecurefunc) ~= "function" then return end
    pcall(hooksecurefunc, "RollOnLoot", function(rollID, rollType)
        rollType = tonumber(rollType)
        if rollType == 1 then
            pcall(T.OnNeedRoll, T, rollID)
        elseif rollType == 2 then
            pcall(T.MarkGreed, T, rollID)
        end
    end)
end

function T:Start()
    if started then return end
    started = true
    if StaticPopupDialogs then
        StaticPopupDialogs["LOOTJINX_RUN_EXIT"] = {
            text = LJ.L("RUN_EXIT_PROMPT"),
            button1 = LJ.L("RUN_PAUSE"),
            button2 = LJ.L("RUN_END"),
            button3 = LJ.L("RUN_DISCARD"),
            selectCallbackByIndex = true,
            OnButton1 = function(_, runID) T:PauseActive(runID) end,
            OnButton2 = function(_, runID)
                local run = activeRun()
                if run and not inside and run.id == tonumber(runID) then T:CloseActive("manual") end
            end,
            OnButton3 = function(_, runID) T:DiscardActive(runID) end,
            OnEscape = function(_, runID) T:PauseActive(runID) end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }
    end
    T.startedAt = now()
    lastPrimaryStat = LJ:PlayerStat()
    registerEvents()
    hookRolls()
    T:CloseStale()
    if C_Timer and C_Timer.NewTicker then
        C_Timer.NewTicker(60, function()
            pcall(T.CloseStale, T)
            pcall(T.ResolveStaleNeedsAll, T, false)
            pcall(T.RepairLostNeeds, T)
        end)
    end
end

function T:ResetAll()
    cancelStaleTimer()
    if type(StaticPopup_Hide) == "function" then StaticPopup_Hide("LOOTJINX_RUN_EXIT") end
    LJ:ResetChar()
    if LJ.RunDetail and type(LJ.RunDetail.Hide) == "function" then
        pcall(LJ.RunDetail.Hide, LJ.RunDetail)
    end
    inside = false
    blocked = false
    firstCheck = false
    lastPrimaryStat = nil
    recentGreed = {}
    rollLinks = {}
    rollLinkAt = {}
    rollLinkCount = 0
    LJ:Changed()
    after(0.2, function() T:CheckZone() end)
end

function T:Debug()
    local class, classFile = LJ:ClassName()
    local stat, label = LJ:PlayerStat()
    local run = activeRun()
    LJ:Print(LJ.L("CHAT_DEBUG_HEADER"))
    LJ:Print(LJ.L("CHAT_DEBUG_INSIDE", tostring(inside), run and run.name or "–"))
    LJ:Print(LJ.L("CHAT_DEBUG_RUNS", #(T:GetRuns())))
    LJ:Print(LJ.L("CHAT_DEBUG_STAT", tostring(class) .. " (" .. tostring(classFile) .. ")", tostring(label)))
    LJ:Print("Stat-Key: " .. tostring(stat) .. " · Key: " .. tostring(run and run.key or "–"))
    local debugItems = LJ.debugItems or {}
    if #debugItems == 0 then
        LJ:Print(LJ.L("CHAT_DEBUG_NONE"))
    else
        LJ:Print(LJ.L("CHAT_DEBUG_ITEMS"))
        for i = 1, math.min(#debugItems, 8) do
            LJ:Print("  " .. debugItems[i])
        end
    end
end
