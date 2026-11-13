-- LootJinx – Erfassung von Dungeons, Loot und Need-Rolls
local ADDON, ns = ...
local LJ = ns or _G.LootJinx
if not LJ then return end

local T = {}
LJ.Tracker = T

local NEED_TIMEOUT = 5 * 60
local DEDUPE_SECONDS = 5
local REPAIR_SECONDS = 15 * 60
local MAX_BOSSES = 20
local MAX_DROPS = 120
local MAX_ROLLS = 200

local inside = false
local blocked = false
local repairScheduled = false
local reclassifyScheduled = false
local started = false
local firstCheck = true
local lastPrimaryStat
local recentGreed = {}
local rollLinks = {}
local rollLinkAt = {}
local rollLinkCount = 0
local lootWindowOpen = false
local seenLootSlots = {}
local lootHistoryDrops = 0
local lootHistoryRolls = 0

local function now()
    return LJ.Now()
end

local function after(seconds, fn)
    if C_Timer and C_Timer.After then
        C_Timer.After(seconds, function() pcall(fn) end)
    end
end

-- Diagnose speichert nur Ereignistypen, IDs und Flags. Namen, Chattexte und
-- Whisper-Ziele gehören nicht in den kopierbaren Snapshot.
local function diag(kind, id, detail)
    local diagnostics = LJ.Diagnostics
    if diagnostics and diagnostics.Event then diagnostics:Event(kind, id, detail) end
end

local function diagItem(id, info, source)
    local diagnostics = LJ.Diagnostics
    if diagnostics and diagnostics.NoteItem then diagnostics:NoteItem(id, info, source) end
end

local function diagDuplicate()
    local diagnostics = LJ.Diagnostics
    if diagnostics and diagnostics.NoteDuplicate then diagnostics:NoteDuplicate() end
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

local function runByID(id)
    local data = db()
    for i = #((data and data.runs) or {}), 1, -1 do
        if data.runs[i].id == id then return data.runs[i] end
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
        if roll.id == id and lower(roll.name) == name
            and now() - (roll.at or 0) <= 180 then
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

function T:CloseActive(reason)
    local run = activeRun()
    if not run then return false end
    diag("run-close", run.id, reason or "closed")
    local previous = run.provisionalPreviousID and runByID(run.provisionalPreviousID)
    if previous then
        T:ResolveStaleNeeds(previous, true)
        T:FinalizeRunItems(previous)
    end
    run.provisionalPreviousID = nil
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
    local stat = LJ:PlayerStat()
    local run = {
        id = tonumber(data.nextRunID) or 1,
        name = d.name,
        key = d.key,
        instanceID = d.instanceID,
        zoneID = nil,
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
        stat = stat,
        statHistory = stat and { stat } or nil,
        statMixed = false,
    }
    data.nextRunID = run.id + 1
    data.runs[#data.runs + 1] = run
    data.activeID = run.id
    inside = true
    blocked = false
    lootWindowOpen = false
    seenLootSlots = {}
    diag("run-start", run.id, "partial=" .. tostring(run.partial))
    LJ:Changed()
    return run
end

-- Die ID aus GetInstanceInfo bezeichnet die Karte. Feld 5 einer Kreatur-
-- oder Cast-GUID bezeichnet die konkrete Instanzkopie (wie in NIT).
local function guidZoneID(guid)
    if type(issecretvalue) == "function" and issecretvalue(guid) then return nil end
    if type(guid) ~= "string" then return nil end
    local kind, id = guid:match("^(%a+)%-[^-]*%-[^-]*%-[^-]*%-(%d+)%-")
    if kind ~= "Creature" and kind ~= "Cast" then return nil end
    id = tonumber(id)
    return id and id > 0 and id or nil
end

function T:ObserveInstanceGUID(guid)
    if not inside then return false end
    local zoneID = guidZoneID(guid)
    local run = activeRun()
    if not zoneID or not run then return false end
    local previous = run.provisionalPreviousID and runByID(run.provisionalPreviousID)
    if previous then
        run.provisionalPreviousID = nil
        if previous.zoneID == zoneID then
            local data = db()
            local candidate = run
            for _, field in ipairs({ "needs", "pending", "greeds", "bosses", "drops", "rolls" }) do
                previous[field] = previous[field] or {}
                for _, entry in ipairs(candidate[field] or {}) do
                    previous[field][#previous[field] + 1] = entry
                end
            end
            previous.seenLinks = previous.seenLinks or {}
            for link in pairs(candidate.seenLinks or {}) do previous.seenLinks[link] = true end
            previous.lootSeen = previous.lootSeen or candidate.lootSeen
            previous.itemsSeen = (previous.itemsSeen or 0) + (candidate.itemsSeen or 0)
            previous.agiItemsSeen = (previous.agiItemsSeen or 0) + (candidate.agiItemsSeen or 0)
            previous.agilityDropped = previous.agilityDropped or candidate.agilityDropped
            previous.agilityLink = previous.agilityLink or candidate.agilityLink
            previous.agilityAt = previous.agilityAt or candidate.agilityAt
            previous.agilityName = previous.agilityName or candidate.agilityName
            if previous.stat then
                previous.statHistory = previous.statHistory or { previous.stat }
                local candidateHistory = candidate.statHistory
                    or (candidate.stat and { candidate.stat }) or {}
                for _, stat in ipairs(candidateHistory) do
                    if previous.statHistory[#previous.statHistory] ~= stat then
                        previous.statHistory[#previous.statHistory + 1] = stat
                    end
                end
                previous.stat = previous.statHistory[#previous.statHistory]
                previous.statMixed = #previous.statHistory > 1
            end
            previous.lastSeen = now()
            previous.outsideAt = nil
            previous.paused = false
            previous.closed = false
            previous.ended = nil
            previous.closedReason = nil
            for i = #data.runs, 1, -1 do
                if data.runs[i] == candidate then table.remove(data.runs, i); break end
            end
            data.activeID = previous.id
            run = previous
            diag("copy-merged", previous.id, "new=" .. tostring(candidate.id))
            if LJ.RunDetail and LJ.RunDetail.ReplaceRun then
                LJ.RunDetail:ReplaceRun(candidate, previous)
            end
        else
            T:ResolveStaleNeeds(previous, true)
            T:FinalizeRunItems(previous)
            diag("copy-mismatch", previous.id, "zone=" .. tostring(zoneID))
        end
    end
    if run and not run.zoneID then
        run.zoneID = zoneID
        diag("copy-confirmed", run.id, "zone=" .. tostring(zoneID))
        LJ:Changed()
    end
    return true
end

local function observeUnit(unit)
    if type(UnitGUID) ~= "function" then return end
    local ok, guid = pcall(UnitGUID, unit)
    if ok then T:ObserveInstanceGUID(guid) end
end

function T:CheckZone()
    if not db() then return end
    local wasFirst = firstCheck
    firstCheck = false
    local d = getDungeon()
    if d then
        if blocked then return end
        local run = activeRun()
        if run and sameInstance(run, d) then
            if not inside or run.outsideAt then
                diag("zone-reenter", run.id, run.zoneID and "known-copy" or "unknown-copy")
                if run.zoneID then
                    run.closed = true
                    run.ended = now()
                    run.closedReason = "pending-copy"
                    db().activeID = nil
                    local candidate = T:StartRun(d, false)
                    if candidate then
                        candidate.provisionalPreviousID = run.id
                        diag("copy-pending", candidate.id, "previous=" .. tostring(run.id))
                    end
                else
                    diag("copy-unknown", run.id)
                    T:CloseActive("unknown-copy")
                    T:StartRun(d, false)
                end
                observeUnit("target")
                observeUnit("mouseover")
                return
            end
            inside = true
            run.paused = false
            run.outsideAt = nil
            run.lastSeen = now()
            run.key = d.key
            run.instanceID = d.instanceID or run.instanceID
            run.difficulty = d.difficulty or run.difficulty
            if d.name and d.name ~= "" then run.name = d.name end
            observeUnit("target")
            observeUnit("mouseover")
            LJ:Changed()
            return
        end
        if run then T:CloseActive("switched-instance") end
        T:StartRun(d, wasFirst)
        observeUnit("target")
        observeUnit("mouseover")
    else
        local wasInside = inside
        inside = false
        blocked = false
        local run = activeRun()
        if run then
            run.outsideAt = run.outsideAt or now()
            run.lastSeen = now()
            run.paused = true
            if wasInside then
                diag("zone-leave", run.id)
                LJ:Changed()
            end
        end
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

local function queuePending(run, link, id, info, source)
    if not run or not link then return end
    run.pending = run.pending or {}
    for i = 1, #run.pending do
        local p = run.pending[i]
        if p.link == link then return end
    end
    run.pending[#run.pending + 1] = {
        link = link,
        id = id,
        stat = run.stat,
        added = now(),
        countedLoot = info and info.loot == true or false,
        source = source,
    }
    while #run.pending > 80 do table.remove(run.pending, 1) end
    diag("item-pending", id, source)
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
    if run.seenLinks[link] then
        diagDuplicate()
        return false
    end
    run.seenLinks[link] = true

    local info = LJ:ClassifyItem(link, run.stat)
    diagItem(id, info, source)
    if LJ.debugMode then LJ:NoteItemDebug(link, source) end
    if not info then
        diag("item-defer", id, source)
        queuePending(run, link, id, nil, source)
        return false
    end
    if info.quest then
        diag("item-quest", id, source)
        return false
    end

    local changed = false
    local knownLoot = info.loot == true
    if knownLoot then
        run.lootSeen = true
        run.itemsSeen = (run.itemsSeen or 0) + 1
        changed = true
        diag("item-counted", id, source)
    end
    if info.agi == true then
        if markAgility(run, link, info) then changed = true end
        diag("item-stat", id, source)
    elseif info.agi == nil then
        diag("item-stat-pending", id, source)
        queuePending(run, link, id, info, source)
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
        -- Runs ohne überlieferten Stat-Kontext werden nicht mit der aktuellen
        -- Spezialisierung nachklassifiziert.
        if type(pending) == "table" and #pending > 0 then
            local keep = {}
            for i = 1, #pending do
                local p = pending[i]
                local stat = p.stat or run.stat
                local info = stat and LJ:ClassifyItem(p.link, stat) or nil
                if info and (not itemID or p.id == itemID or info.id == itemID) then
                    local action, counted, agi = finalizePending(p, info)
                    diagItem(p.id or info.id, info, "reclassify")
                    if counted and not p.countedLoot then
                        p.countedLoot = true
                        run.lootSeen = true
                        run.itemsSeen = (run.itemsSeen or 0) + 1
                        changed = true
                        diag("pending-counted", p.id or info.id)
                    end
                    if action == "agi" then
                        if markAgility(run, p.link, info) then changed = true end
                        diag("pending-stat", p.id or info.id)
                    elseif action == "keep" then
                        keep[#keep + 1] = p
                    else
                        diag("pending-" .. tostring(action), p.id or info.id)
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
        if #pending > 0 then diag("pending-finalized", run.id, "n=" .. tostring(#pending)) end
        for i = 1, #pending do
            local p = pending[i]
            local stat = p.stat or run.stat
            local info = stat and LJ:ClassifyItem(p.link, stat) or nil
            if info and info.agi == true then markAgility(run, p.link, info) end
        end
    end
    run.pending = {}
end

-- Ein Spezialisierungswechsel aktualisiert nur den laufenden Run. Abgeschlossene
-- Runs behalten ihren gespeicherten Stat-Kontext; ihre Klassifikation wird nicht
-- rückwirkend mit der neuen Spezialisierung neu berechnet.
function T:CheckPrimaryStatChanged()
    local stat = LJ:PlayerStat()
    if not lastPrimaryStat then
        lastPrimaryStat = stat
        return false
    end
    if lastPrimaryStat == stat then return false end
    local previous = lastPrimaryStat
    lastPrimaryStat = stat
    diag("stat-change", nil, tostring(previous) .. "->" .. tostring(stat))

    local run = activeRun()
    if run and run.stat then
        run.statHistory = run.statHistory or { run.stat }
        if run.statHistory[#run.statHistory] ~= stat then
            run.statHistory[#run.statHistory + 1] = stat
        end
        run.stat = stat
        run.statMixed = #run.statHistory > 1
        diag("run-stat-change", run.id, tostring(previous) .. "->" .. tostring(stat))
        LJ:Changed()
    end
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
    local found, foundRun, matches = nil, nil, 0
    for i = #data.runs, 1, -1 do
        local run = data.runs[i]
        for j = #(run.needs or {}), 1, -1 do
            local n = run.needs[j]
            if needMatches(n, itemID, link, nil, maxAge or 900) then
                matches = matches + 1
                if not found or (n.at or 0) >= (found.at or 0) then
                    found, foundRun = n, run
                end
            end
        end
    end
    return found, foundRun, matches
end

function T:ResolveNeed(need, result, reason)
    if not need or (result ~= "won" and result ~= "lost") then return false end
    if need.result == "won" then return false end
    if need.result == "lost" and result ~= "won" then return false end
    need.result = result
    need.resolvedAt = now()
    need.reason = reason or "event"
    diag("need-result", need.id, tostring(result) .. ":" .. tostring(need.reason))
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
    diag("bags-check", id, "count=" .. tostring(count) .. " before=" .. tostring(before))
    if count > before then
        if T:HasGreedConflict(need, run) then
            need.noRepair = true
            diag("greed-guard", id)
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
                local filled = false
                if not n.link and link then n.link = link; filled = true end
                if not n.id and id then n.id = id; filled = true end
                if not n.rollID and rollID then n.rollID = rollID; filled = true end
                if n.id and not n.before then n.before = LJ:ItemCount(n.id) end
                if filled then diag("need-link", n.id or id, "roll=" .. tostring(rollID)) end
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
    diag("need-open", id, "roll=" .. tostring(rollID))
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
    local filled = false
    if not need.link then need.link = link; filled = true end
    if not need.id then
        local id = LJ:ItemID(link)
        if id then need.id = id; filled = true end
    end
    if need.id and (not need.before or need.before == 0) then
        need.before = LJ:ItemCount(need.id)
        filled = true
    end
    if filled then diag("need-link", need.id, "roll=" .. tostring(rollID)) end
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
    diag("greed", id, "roll=" .. tostring(rollID))
end

function T:ResolveNeedByLink(link, result, reason)
    link = LJ:NormalizeLink(link)
    local id = LJ:ItemID(link)
    local need, run, matches = T:FindPendingNeed(id, link, 900)
    if not need then return false end
    if matches > 1 and (reason == "chat-won" or reason == "chat-other-won"
        or reason == "chat-all-passed") then
        reason = reason .. "-ambiguous"
    end
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
                diag("roll-resolve", n.id, "roll=" .. tostring(rollID))
                T:ResolveNeedByBags(n, run, true)
                return
            end
        end
    end
end

-- ---------------------------------------------------------------- Loot-Events
-- ---------------------------------------------------------------- Boss-/Drop-Details
local function noteDrop(run, link, winner, boss, source, rollValue, rollKind, passed, winnerClass, rollID)
    if not run then return false end
    source = source or "seen"
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
    rollID = tonumber(rollID)
    rollKind = (rollKind == "need" or rollKind == "greed") and rollKind or nil
    local at = now()

    run.drops = run.drops or {}
    for i = #run.drops, 1, -1 do
        local d = run.drops[i]
        local sources = d.sources or { [d.source or "unknown"] = true }
        local age = at - (d.at or 0)
        local mergeAge = (source == "roll" or sources.roll) and 180 or 30
        if d.id == id and age >= 0 and age <= mergeAge
            and (not sources[source] or (rollID and d.rollID == rollID))
            and (not rollID or not d.rollID or d.rollID == rollID) then
            local sameWinner = not d.winner or not winner or lower(d.winner) == lower(winner)
            if sameWinner then
                local changed = false
                d.sources = sources
                sources[source] = true
                if winner and not d.winner then
                    d.winner = winner
                    d.winnerSource = source
                    changed = true
                end
                if winner and winnerClass and not d.winnerClass then d.winnerClass = winnerClass; changed = true end
                if rollValue and not d.roll then d.roll = rollValue; changed = true end
                if rollKind and not d.rollKind then d.rollKind = rollKind; changed = true end
                if rollID and not d.rollID then d.rollID = rollID; changed = true end
                if source == "encounter" and d.source ~= "encounter" then
                    d.source = "encounter"
                    d.bossID = bossID
                    d.bossName = bossName
                    changed = true
                end
                if passed and not d.passed and not d.winner then d.passed = true; changed = true end
                if d.winner and d.passed then d.passed = false; changed = true end
                if changed then
                    diag("drop-merge", id, source)
                    LJ:Changed()
                end
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
        winnerSource = winner and source or nil,
        winnerClass = winnerClass,
        roll = rollValue,
        rollID = rollID,
        rollKind = rollKind,
        passed = passed == true and not winner or false,
        source = source,
        sources = { [source or "unknown"] = true },
    }
    while #run.drops > MAX_DROPS do table.remove(run.drops, 1) end
    diag("drop-new", id, source)
    LJ:Changed()
    return true
end

function T:NoteDrop(...)
    return noteDrop(activeRun(), ...)
end

function T:NoteRoll(link, name, kind, value, source)
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
    local mine = LJ:IsMe(name)
    if kind ~= "greed" and kind ~= "transmog" then kind = "need" end
    run.rolls = run.rolls or {}
    local at = now()
    if source ~= "history" then
        for i = #run.rolls, 1, -1 do
            local prior = run.rolls[i]
            if at - (tonumber(prior.at) or 0) > 300 then break end
            if prior.lootHistoryKey and not prior.chatSeen and prior.id == id
                and prior.kind == kind and tonumber(prior.value) == value
                and lower(prior.name) == lower(name) then
                prior.chatSeen = true
                return false
            end
        end
    end
    run.rolls[#run.rolls + 1] = {
        id = id, name = name, kind = kind, value = value, at = at,
        chatSeen = source ~= "history",
    }
    while #run.rolls > MAX_ROLLS do table.remove(run.rolls, 1) end
    diag("roll", id, kind .. "=" .. tostring(value) .. (mine and " self" or " other"))

    if source ~= "history" then
        for i = #(run.drops or {}), 1, -1 do
            local drop = run.drops[i]
            if drop.id == id and drop.winner and lower(drop.winner) == lower(name) and not drop.roll then
                drop.roll = value
                drop.rollKind = kind
                break
            end
        end
        if kind == "need" and mine then
            for i = 1, #(run.needs or {}) do
                local need = run.needs[i]
                if need.id == id and not need.roll then
                    need.roll = value
                    need.rollKind = kind
                    break
                end
            end
        end
    end
    LJ:Changed()
    return true
end

local LOOT_HISTORY_STATES = {
    [0] = "need", [1] = "need", [2] = "transmog", [3] = "greed", [5] = "pass",
}

local function historyKind(state)
    state = LJ.Plain(state)
    local number = tonumber(state)
    if number then return LOOT_HISTORY_STATES[number] end
    if type(state) == "string" then
        local value = state:lower()
        if value:find("need", 1, true) then return "need" end
        if value:find("transmog", 1, true) then return "transmog" end
        if value:find("greed", 1, true) then return "greed" end
        if value:find("pass", 1, true) then return "pass" end
    end
end

local function recentDrop(run, id, at, historyKey)
    for i = #(run.drops or {}), 1, -1 do
        local drop = run.drops[i]
        if drop.id == id and drop.lootHistoryKey == historyKey then return drop end
    end
    for i = #(run.drops or {}), 1, -1 do
        local drop = run.drops[i]
        if drop.id == id and not drop.lootHistoryKey
            and math.abs((tonumber(drop.at) or 0) - at) <= 900 then
            return drop
        end
    end
end

-- C_LootHistory liefert für Encounter-Beute die echten Rollzahlen aller
-- Spieler. Die Chatmeldungen bleiben der Fallback für Trash und ältere Runs.
function T:NoteRollFromHistory(link, name, kind, value, historyKey)
    local run = activeRun()
    if not run then return false end
    link = LJ:NormalizeLink(link)
    local id = LJ:ItemID(link)
    value = tonumber(value)
    name = LJ.Plain(name)
    if not id or not value or value < 1 or value > 100
        or type(name) ~= "string" or name == "" then return false end
    local at = now()
    for i = #(run.rolls or {}), 1, -1 do
        local roll = run.rolls[i]
        if at - (tonumber(roll.at) or 0) > 300 then break end
        if roll.id == id and roll.kind == kind and tonumber(roll.value) == value
            and lower(roll.name) == lower(name) then
            if roll.lootHistoryKey == historyKey then return false end
            if not roll.lootHistoryKey then
                roll.lootHistoryKey = historyKey
                roll.chatSeen = true
                return false
            end
        end
    end
    if not T:NoteRoll(link, name, kind, value, "history") then return false end
    run.rolls[#run.rolls].lootHistoryKey = historyKey
    return true
end

function T:OnLootHistoryDrop(encounterID, lootListID)
    if not inside then return end
    local run = activeRun()
    if not run then return end
    local api = _G.C_LootHistory
    if type(api) ~= "table" or type(api.GetSortedInfoForDrop) ~= "function" then return end
    encounterID = tonumber(LJ.Plain(encounterID))
    lootListID = tonumber(LJ.Plain(lootListID))
    if not encounterID or not lootListID then return end
    local historyKey = tostring(encounterID) .. ":" .. tostring(lootListID)
    local ok, info = pcall(api.GetSortedInfoForDrop, encounterID, lootListID)
    if not ok or type(info) ~= "table" then return end

    local link = LJ:NormalizeLink(LJ.Plain(info.itemHyperlink))
    local id = LJ:ItemID(link)
    if not id then return end
    local drop = recentDrop(run, id, now(), historyKey)
    if not drop and not (run.seenLinks and run.seenLinks[link]) then
        diag("loot-history-skip", id, "unseen")
        return
    end
    lootHistoryDrops = lootHistoryDrops + 1
    local dropBound = false
    if drop and drop.lootHistoryKey ~= historyKey then
        drop.lootHistoryKey = historyKey
        dropBound = true
    end

    local winner = type(info.winner) == "table" and info.winner or nil
    local winnerName = winner and LJ.Plain(winner.playerName) or nil
    if type(winnerName) == "string" then
        winnerName = winnerName:match("^%s*(.-)%s*$")
        if winnerName == "" then winnerName = nil end
    else
        winnerName = nil
    end
    local winnerClass = winner and LJ.Plain(winner.playerClass) or nil
    if type(winnerClass) ~= "string" then winnerClass = nil end
    local winnerKind = winner and historyKind(winner.state) or nil
    if winnerKind == "pass" then winnerKind = nil end
    local winnerRoll = winner and tonumber(LJ.Plain(winner.roll)) or nil

    local added = 0
    local rollInfos = type(info.rollInfos) == "table" and info.rollInfos or {}
    for i = 1, #rollInfos do
        local entry = rollInfos[i]
        if type(entry) == "table" then
            local name = LJ.Plain(entry.playerName)
            if type(name) == "string" then
                name = name:match("^%s*(.-)%s*$")
                if name == "" then name = nil end
            else
                name = nil
            end
            local value = tonumber(LJ.Plain(entry.roll))
            local kind = historyKind(entry.state)
            if name and value and kind and kind ~= "pass" then
                if T:NoteRollFromHistory(link, name, kind, value, historyKey) then added = added + 1 end
            end
        end
    end
    if winnerName and winnerKind and winnerRoll then
        if T:NoteRollFromHistory(link, winnerName, winnerKind, winnerRoll, historyKey) then
            added = added + 1
        end
    end

    if winnerName then
        if drop then
            local changed = false
            if not drop.winner then
                drop.winner = winnerName
                drop.winnerSource = "lootHistory"
                changed = true
            end
            if winnerClass and not drop.winnerClass then drop.winnerClass = winnerClass; changed = true end
            if winnerRoll and not drop.roll then drop.roll = winnerRoll; changed = true end
            if winnerKind and not drop.rollKind then drop.rollKind = winnerKind; changed = true end
            if changed then diag("drop-merge", id, "lootHistory") end
        end
    elseif info.allPassed == true then
        if drop then
            if not drop.winner then drop.passed = true end
        end
    end

    lootHistoryRolls = lootHistoryRolls + added
    diag("loot-history", id, "rolls=" .. tostring(added)
        .. " winner=" .. tostring(winnerName and "yes" or "no"))
    if dropBound or added > 0 or winnerName or info.allPassed == true then LJ:Changed() end
end

function T:NotePassed(link)
    local run = activeRun()
    if not run then return false end
    diag("passed", LJ:ItemID(link))
    return noteDrop(run, link, nil, nil, "chat", nil, nil, true)
end

function T:NoteSeenDrop(link, source, rollID)
    local run = activeRun()
    if not run then return false end
    return noteDrop(run, link, nil, nil, source or "seen", nil, nil, nil, nil, rollID)
end

function T:OnBossEvent(event, ...)
    if not inside then return end
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
    diag("boss", id, event)

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
    if not inside then return end
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
    diag("encounter-loot", LJ:ItemID(link), "boss=" .. tostring(encounterID))
    local boss = bossByID(run, encounterID)
    if not boss and encounterID and encounterID > 0 then
        boss = { id = encounterID, name = LJ.L("DETAIL_UNKNOWN_BOSS"), at = now() }
        run.bosses[#run.bosses + 1] = boss
    end
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
    if not inside then return end
    rollID = tonumber(rollID)
    if not rollID then return end
    pruneRollLinks()
    local link = rollLink(rollID)
    if link then
        diag("roll-start", LJ:ItemID(link), "roll=" .. tostring(rollID))
        T:RecordItem(link, "loot-roll")
        T:NoteSeenDrop(link, "roll", rollID)
        return
    end
    diag("roll-start-unlinked", nil, "roll=" .. tostring(rollID))
    local function retry()
        if not inside then return end
        local l = rollLink(rollID)
        if l then
            diag("roll-start-late", LJ:ItemID(l), "roll=" .. tostring(rollID))
            T:RecordItem(l, "loot-roll-late")
            T:NoteSeenDrop(l, "roll", rollID)
        end
    end
    after(0.4, retry)
    after(1.5, retry)
    after(4, retry)
end

function T:OnCancelRoll(rollID)
    rollID = tonumber(rollID)
    if not rollID then return end
    diag("roll-cancel", nil, "roll=" .. tostring(rollID))
    after(4, function() T:ResolveNeedByRoll(rollID) end)
    after(20, function() T:ResolveNeedByRoll(rollID) end)
end

function T:OnLootWindow()
    if not inside or type(GetNumLootItems) ~= "function" then return end
    local ok, count = pcall(GetNumLootItems)
    count = ok and tonumber(LJ.Plain(count)) or nil
    if not count then return end
    if not lootWindowOpen then
        lootWindowOpen = true
        seenLootSlots = {}
        diag("loot-open", nil, "slots=" .. tostring(count))
    end
    for slot = 1, count do
        local okL, link = pcall(GetLootSlotLink, slot)
        link = okL and LJ.Plain(link) or nil
        if type(link) == "string" and link ~= "" then
            local key = tostring(slot) .. ":" .. link
            if not seenLootSlots[key] then
                seenLootSlots[key] = true
                diag("loot-window", LJ:ItemID(link), "slot=" .. tostring(slot))
                T:RecordItem(link, "loot-window")
                T:NoteSeenDrop(link, "loot-window")
            end
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
    noteDrop(run, link, winner, nil, "chat", nil, nil, nil, classFile)
end

function T:OnLootChat(text, _who, guid)
    if not inside then return end
    text = LJ.Plain(text)
    if type(text) ~= "string" then return end
    local p = Patterns()
    local args

    args = Match(p.youWon, text)
    if args then
        diag("chat", nil, "you-won")
        recordChatItems(args[1])
        noteChatDrop(firstItemLink(args[1]), LJ:PlayerName(), nil)
        T:ResolveNeedByLink(firstItemLink(args[1]), "won", "chat-won")
        return
    end

    args = Match(p.won, text)
    if args then
        diag("chat", nil, "won")
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
        diag("chat", nil, "all-passed")
        recordChatItems(args[1])
        T:NotePassed(firstItemLink(args[1]))
        T:ResolveNeedByLink(firstItemLink(args[1]), "lost", "chat-all-passed")
        return
    end

    args = Match(p.needSelf, text)
    if args then
        diag("chat", nil, "need-self")
        recordChatItems(args[1])
        T:OnNeedRoll(nil, firstItemLink(args[1]))
        return
    end

    args = Match(p.greedSelf, text)
    if args then
        diag("chat", nil, "greed-self")
        recordChatItems(args[1])
        T:MarkGreed(nil, firstItemLink(args[1]))
        return
    end

    args = Match(p.needOther, text)
    if args then
        diag("chat", nil, "need-other")
        recordChatItems(args[2])
        return
    end

    args = Match(p.greedOther, text)
    if args then
        diag("chat", nil, "greed-other")
        recordChatItems(args[2])
        return
    end

    args = Match(p.rolledNeed, text) or Match(p.rolledNeedBonus, text)
    if args then
        diag("chat", nil, "rolled-need")
        recordChatItems(args[2])
        T:NoteRoll(firstItemLink(args[2]), args[3], "need", Number(args[1]))
        return
    end

    args = Match(p.rolledGreed, text)
    if args then
        diag("chat", nil, "rolled-greed")
        recordChatItems(args[2])
        T:NoteRoll(firstItemLink(args[2]), args[3], "greed", Number(args[1]))
        return
    end

    args = Match(p.lootSelf, text)
    if args then
        diag("chat", nil, "loot-self")
        recordChatItems(args[1])
        noteChatDrop(firstItemLink(args[1]), LJ:PlayerName(), nil)
        T:ResolveNeedByLink(firstItemLink(args[1]), "won", "chat-loot-self")
        return
    end

    args = Match(p.lootOther, text)
    if args then
        diag("chat", nil, "loot-other")
        recordChatItems(args[2])
        noteChatDrop(firstItemLink(args[2]), args[1], guid)
        if not LJ:IsMe(args[1]) then
            T:ResolveNeedByLink(firstItemLink(args[2]), "lost", "chat-loot-other")
        else
            T:ResolveNeedByLink(firstItemLink(args[2]), "won", "chat-loot-self")
        end
        return
    end
    diag("chat-unmatched", nil, "len=" .. tostring(#text)
        .. " item=" .. tostring(firstItemLink(text) ~= nil)
        .. " num=" .. tostring(text:find("%d") ~= nil))
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
    diag("system-reset", run.id, "blocked=" .. tostring(blocked))
    T:CloseActive("instance-reset")
    LJ:Changed()
end

-- ---------------------------------------------------------------- Events
local eventFrame
local function onEvent(event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
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
    elseif event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_SUCCEEDED" then
        T:ObserveInstanceGUID(select(2, ...))
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        observeUnit((...))
    elseif event == "PLAYER_TARGET_CHANGED" then
        observeUnit("target")
    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        observeUnit("mouseover")
    elseif event == "ENCOUNTER_END" or event == "BOSS_KILL" then
        T:OnBossEvent(event, ...)
    elseif event == "ENCOUNTER_LOOT_RECEIVED" then
        T:OnEncounterLoot(...)
    elseif event == "START_LOOT_ROLL" then
        T:OnStartRoll((...))
    elseif event == "LOOT_HISTORY_UPDATE_DROP" then
        T:OnLootHistoryDrop(...)
    elseif event == "CANCEL_LOOT_ROLL" then
        T:OnCancelRoll((...))
    elseif event == "LOOT_OPENED" or event == "LOOT_READY" then
        T:OnLootWindow()
    elseif event == "LOOT_CLOSED" then
        lootWindowOpen = false
        seenLootSlots = {}
        diag("loot-close")
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
        "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_SUCCEEDED", "NAME_PLATE_UNIT_ADDED",
        "PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT",
        "ENCOUNTER_END", "BOSS_KILL", "ENCOUNTER_LOOT_RECEIVED",
        "START_LOOT_ROLL", "LOOT_HISTORY_UPDATE_DROP", "CANCEL_LOOT_ROLL",
        "LOOT_OPENED", "LOOT_READY", "LOOT_CLOSED",
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
    T.startedAt = now()
    lastPrimaryStat = LJ:PlayerStat()
    registerEvents()
    hookRolls()
    diag("tracker-start", nil, "version=" .. tostring(LJ:AddOnVersion()))
    if C_Timer and C_Timer.NewTicker then
        C_Timer.NewTicker(60, function()
            pcall(T.ResolveStaleNeedsAll, T, false)
            pcall(T.RepairLostNeeds, T)
        end)
    end
end

function T:ResetAll()
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
    lootWindowOpen = false
    seenLootSlots = {}
    lootHistoryDrops = 0
    lootHistoryRolls = 0
    if LJ.Diagnostics and LJ.Diagnostics.Reset then LJ.Diagnostics:Reset() end
    LJ:Changed()
    after(0.2, function() T:CheckZone() end)
end

local function countTable(value)
    local count = 0
    for _ in pairs(value or {}) do count = count + 1 end
    return count
end

local function diagnosticNeedCounts(needs)
    local total, won, lost, open = 0, 0, 0, 0
    for i = 1, #(needs or {}) do
        total = total + 1
        local result = needs[i].result
        if result == "won" then
            won = won + 1
        elseif result == "lost" then
            lost = lost + 1
        else
            open = open + 1
        end
    end
    return total, won, lost, open
end

local function diagnosticPending(run)
    local out = {}
    local pending = run and run.pending or {}
    for i = 1, #pending do
        local p = pending[i]
        out[#out + 1] = {
            id = p.id,
            source = p.source,
            added = p.added,
            age = now() - (tonumber(p.added) or now()),
            countedLoot = p.countedLoot == true,
            link = p.link ~= nil,
        }
    end
    return out
end

local function diagnosticOpenNeeds(run)
    local out = {}
    for i = 1, #((run and run.needs) or {}) do
        local n = run.needs[i]
        if n.result == nil then
            out[#out + 1] = {
                id = n.id,
                rollID = n.rollID,
                at = n.at,
                age = now() - (tonumber(n.at) or now()),
                link = n.link ~= nil,
                roll = n.roll,
                rollKind = n.rollKind,
            }
        end
    end
    return out
end

local function diagnosticCopy(run)
    local copy = { state = "none" }
    if blocked then
        copy.state = "blocked"
        return copy
    end
    if not run then
        if inside then copy.state = "blocked" end
        return copy
    end
    if run.zoneID then
        copy.state = "confirmed"
        copy.zoneID = run.zoneID
    elseif run.provisionalPreviousID then
        copy.state = "pending"
    else
        copy.state = "unconfirmed"
    end
    if run.provisionalPreviousID then
        copy.previousID = run.provisionalPreviousID
        local previous = runByID(run.provisionalPreviousID)
        if previous then
            copy.previousZoneID = previous.zoneID
            copy.previousClosedReason = previous.closedReason
        end
    end
    return copy
end

function T:GetDiagnosticState()
    local run = activeRun()
    local state = {
        inside = inside,
        blocked = blocked,
        live = inside and run ~= nil,
        runCount = #(T:GetRuns()),
        lootWindowOpen = lootWindowOpen,
        lootSlots = countTable(seenLootSlots),
        lootHistory = { drops = lootHistoryDrops, rolls = lootHistoryRolls },
        copy = diagnosticCopy(run),
        start = T.startedAt,
    }
    if run then
        local total, won, lost, open = diagnosticNeedCounts(run.needs)
        state.run = {
            id = run.id,
            name = run.name,
            key = run.key,
            instanceID = run.instanceID,
            zoneID = run.zoneID,
            difficulty = run.difficulty,
            started = run.started,
            ended = run.ended,
            lastSeen = run.lastSeen,
            outsideAt = run.outsideAt,
            closed = run.closed == true,
            paused = run.paused == true,
            closedReason = run.closedReason,
            provisionalPreviousID = run.provisionalPreviousID,
            partial = run.partial == true,
            lootSeen = run.lootSeen == true,
            agilityDropped = run.agilityDropped == true,
            stat = run.stat,
            statHistory = run.statHistory,
            statMixed = run.statMixed == true,
            itemsSeen = run.itemsSeen or 0,
            agiItemsSeen = run.agiItemsSeen or 0,
            bosses = #(run.bosses or {}),
            drops = #(run.drops or {}),
            rolls = #(run.rolls or {}),
            needs = total,
            won = won,
            lost = lost,
            open = open,
            pendingCount = #(run.pending or {}),
            seenLinks = countTable(run.seenLinks),
            pendingItems = diagnosticPending(run),
            openNeeds = diagnosticOpenNeeds(run),
        }
    end
    return state
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
