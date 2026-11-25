-- LootJinx – Erfassung von Dungeons, Loot und Need-Rolls
local ADDON, ns = ...
local LJ = ns or _G.LootJinx
if not LJ then return end

local T = {}
LJ.Tracker = T

local NEED_TIMEOUT = 5 * 60
local DEDUPE_SECONDS = 5
local NEED_CHAT_SECONDS = 120
local CHAT_RESULT_ECHO_SECONDS = 5 * 60
local REPAIR_SECONDS = 15 * 60
local LATE_HISTORY_SECONDS = 5 * 60
local MAX_BOSSES = 64
local MAX_TIMELINE_EVENTS = 24
local LOGIN_STALE_OUTSIDE_SECONDS = 6 * 60 * 60
local EXIT_SETTLE_SECONDS = 3
local RESUME_SECONDS = 5 * 60
local CONFIRMED_RESUME_SECONDS = 30 * 60
local RESUME_POPUP = "LOOTJINX_RESUME_CHOICE"
local pendingResumeChoice
-- Ein Loot-Fenster kann fuer dieselbe Leiche mehrfach geoeffnet werden. Solche
-- Wiederholungen sind kein neuer Drop, sondern zeigen das bereits gelootete
-- (oder liegengelassene) Item erneut an.
local LOOT_WINDOW_ECHO_SECONDS = 5 * 60

local inside = false
local blocked = false
local repairScheduled = false
local reclassifyScheduled = false
local started = false
local firstCheck = true
local rollLinks = {}
local rollLinkAt = {}
local rollStartTokens = {}
local nextRollPruneAt = 0
local needRollTokens = setmetatable({}, { __mode = "k" })
local dropRollTokens = setmetatable({}, { __mode = "k" })
local lootWindowOpen = false
local seenLootSlots = {}
local lootWindowClaims = {}
local pendingReentry, replayReentry, reentryEventTime
local lootWindowSources = setmetatable({}, { __mode = "k" })
local seenItemKeys = setmetatable({}, { __mode = "k" })
local lootHistoryDrops = 0
local lootHistoryRolls = 0
local worldEntries = 0
local exitGraceRun, exitGraceUntil
local lastExitedRun, lastExitUntil
local transitionGuardRun
local lastSwitchedRun

local function now()
    return reentryEventTime or LJ.Now()
end

local function reentryQueue(run, departure)
    if pendingReentry and pendingReentry.run == run then return pendingReentry end
    if not inside or not run or not run.reenterPending then return nil end
    local departed, exitIndex = departure, nil
    local index = #(run.timeline or {})
    local event = index > 0 and run.timeline[index]
    if event and event.kind == "exit" and (not departure or event.at >= departure) then
        departed, exitIndex = event.at, index
    end
    pendingReentry = { run = run, started = now(), departed = departed, exitIndex = exitIndex, events = {} }
    return pendingReentry
end

local function enqueueReentry(queue, replay, events)
    events = events or queue.events
    events[#events + 1] = { at = now(), replay = replay }
end

local function endBeforeReentry(run, queue)
    run.ended = queue.previousEnded or queue.departed or queue.started
    if queue.exitIndex then
        for i = #run.timeline, queue.exitIndex + 1, -1 do run.timeline[i] = nil end
    end
end

local function timelineEvent(run, kind, at)
    if type(run) ~= "table" or type(run.timeline) ~= "table" then return end
    if kind ~= "exit" and kind ~= "return" then return end
    local events = run.timeline
    local timestamp = tonumber(at) or now()
    local last = events[#events]
    if last and last.kind == kind and last.at == timestamp then return end
    events[#events + 1] = { kind = kind, at = timestamp }
    if #events > MAX_TIMELINE_EVENTS then
        table.remove(events, 1)
        run.timelineOmitted = (tonumber(run.timelineOmitted) or 0) + 1
    end
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

local function samePlayer(a, b)
    if LJ.SamePlayerName and LJ:SamePlayerName(a, b) then return true end
    local name = lower(a)
    return name ~= nil and name == lower(b)
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
    local at = now()
    for _, drop in ipairs(run.drops or {}) do
        if drop.id == id and math.abs(at - (drop.at or 0)) <= 300 then return nil end
    end
    local match
    for i = #((run and run.rolls) or {}), 1, -1 do
        local roll = run.rolls[i]
        if roll.id == id and not roll.lootHistoryKey and lower(roll.name) == name
            and at - (roll.at or 0) <= 180 then
            if match and (match.kind ~= roll.kind or match.value ~= roll.value) then return nil end
            match = roll
        end
    end
    if match then return match.kind, match.value end
end

local function emptyVisit(run)
    if type(run) ~= "table" or run.legacy or run.detailVersion == nil then return false end
    if run.lootSeen == true or (tonumber(run.itemsSeen) or 0) > 0 then return false end
    for _, field in ipairs({ "bosses", "drops", "needs", "greeds", "rolls", "pending" }) do
        if type(run[field]) == "table" and next(run[field]) then return false end
    end
    if type(run.seenLinks) == "table" and next(run.seenLinks) then return false end
    return true
end

local function discardRun(data, run)
    if not data or not run then return end
    for i = #data.runs, 1, -1 do
        if data.runs[i] == run then
            table.remove(data.runs, i)
            diag("run-discarded", run.id, "empty")
            return
        end
    end
end

function T:IsCounted(run)
    return not emptyVisit(run)
end

local function sameInstance(run, d)
    if run.key and d.key then return tostring(run.key) == tostring(d.key) end
    return lower(run.name) == lower(d.name)
end

local function emptyContinuation(run, previous)
    if not previous or not previous.closed or previous.closedReason ~= "left"
        or previous.resetAfterExit or not sameInstance(previous, run) then return false end
    local start, ended = tonumber(run.started), tonumber(previous.ended)
    return start and ended and start >= ended and start - ended <= CONFIRMED_RESUME_SECONDS
end

function T:GetRuns()
    local data = db()
    local runs = data and data.runs or {}
    local visible
    for i, run in ipairs(runs) do
        if (run.closed or emptyContinuation(run, runs[i - 1])) and emptyVisit(run) then
            if not visible then
                visible = {}
                for j = 1, i - 1 do visible[#visible + 1] = runs[j] end
            end
        elseif visible then
            visible[#visible + 1] = run
        end
    end
    return visible or runs
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

local function inExitGrace(run)
    return run and run == exitGraceRun and exitGraceUntil and now() < exitGraceUntil
end

local function transitioningFromOtherRun(run)
    return run and run == transitionGuardRun and lastExitedRun and run ~= lastExitedRun
        and lastExitUntil and now() < lastExitUntil
end

local function previousLootRun(run)
    if run and lastSwitchedRun and lastSwitchedRun ~= run
        and now() - lastSwitchedRun.ended < EXIT_SETTLE_SECONDS then
        return lastSwitchedRun
    end
    if transitioningFromOtherRun(run) then return lastExitedRun end
end

-- ---------------------------------------------------------------- Zone
local function getDungeon()
    if type(IsInInstance) ~= "function" then return nil end
    local ok, inInstance, kind = pcall(IsInInstance)
    if not ok then return nil end
    inInstance, kind = LJ.Plain(inInstance), LJ.Plain(kind)
    if not inInstance then return nil end
    if kind ~= "party" and kind ~= "scenario" and kind ~= "raid" then return nil end

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

-- Kehrt der Spieler kurz nach dem Verlassen in dieselbe Instanz zurück, wird
-- der zuletzt geschlossene Run fortgesetzt. Das verhindert geteilte Runs nach
-- Wipe, Portal oder Reload innerhalb des Zeitfensters.
local function recentlyLeftRun()
    local data = db()
    local run = data and data.runs[#data.runs]
    if not run or run.closed ~= true or run.closedReason ~= "left"
        or run.resetAfterExit or run.unconfirmedCopy then return nil end
    local ended = tonumber(run.ended) or tonumber(run.lastSeen)
    local age = ended and now() - ended
    if age and age >= 0 and age <= CONFIRMED_RESUME_SECONDS then return run, age end
end

local function resetRollLinks()
    rollLinks, rollLinkAt, rollStartTokens, nextRollPruneAt = {}, {}, {}, 0
end

local function resumeRun(run, d)
    resetRollLinks()
    local data = db()
    if not data then return nil end
    local previousEnded = run.ended
    run.closed = false
    run.closedReason = nil
    run.ended = nil
    run.outsideAt = nil
    run.corpseExit = nil
    run.lastSeen = now()
    run.key = d.key
    run.instanceID = d.instanceID or run.instanceID
    run.difficulty = d.difficulty or run.difficulty
    if d.name and d.name ~= "" and not (run.name and run.name:find(":")) then run.name = d.name end
    data.activeID = run.id
    inside = true
    blocked = false
    lootWindowOpen = false
    seenLootSlots, lootWindowClaims = {}, {}
    exitGraceRun, exitGraceUntil = nil, nil
    lastExitedRun, lastExitUntil = nil, nil
    transitionGuardRun = nil
    run.reenterPending = run.zoneID ~= nil
    local queue = reentryQueue(run)
    if queue then
        queue.previousEnded = previousEnded
    else
        timelineEvent(run, "return", now())
    end
    diag("run-resume", run.id, "name=" .. tostring(run.name))
    LJ:Changed()
    return run
end

local function closeRun(run, reason)
    diag("run-close", run.id, reason or "closed")
    if reason ~= "manual" and reason ~= "switched-instance" and reason ~= "login-outside" then
        T:ResolveStaleNeeds(run, true)
    end
    T:FinalizeRunItems(run)
    run.closed = true
    run.ended = run.ended or now()
    run.closedReason = reason or "closed"
    run.reenterPending = nil
    if reason == "switched-instance" then
        lastSwitchedRun = run
    end
    local data = db()
    if data then data.activeID = nil end
    if exitGraceRun == run then exitGraceRun, exitGraceUntil = nil, nil end
    if transitionGuardRun == run then transitionGuardRun = nil end
    if emptyVisit(run) then discardRun(data, run) end
    LJ:Changed()
    return true
end

function T:CloseActive(reason)
    local run = activeRun()
    if not run then return false end
    local queue = pendingReentry
    if not queue or queue.run ~= run then return closeRun(run, reason) end
    pendingReentry = nil
    local wasInside = inside
    endBeforeReentry(run, queue)
    closeRun(run, "left")
    if #queue.events == 0 and #(queue.history or {}) == 0 then return true end
    local visit = self:StartRun(run, true)
    if not visit then return true end
    visit.started = queue.started
    visit.unconfirmedCopy = true
    replayReentry(queue, visit)
    inside = wasInside
    return closeRun(visit, reason == "all-bosses-cleared" and "left" or reason)
end

function T:SavePendingReentry()
    if pendingReentry and pendingReentry.run == activeRun() then
        self:CloseActive("left")
    end
end

function T:FinishActiveManually(runID)
    local run = activeRun()
    if not run or run.id ~= tonumber(runID) then return false end
    local wasInside = inside
    if not T:CloseActive("manual") then return false end
    if wasInside then
        blocked = true
        local data = db()
        if data then data.manualBlockedKey = tostring(run.key or run.instanceID or run.name) end
        LJ:Changed()
    end
    return true
end

function T:StartRun(d, partial)
    exitGraceRun, exitGraceUntil = nil, nil
    transitionGuardRun = nil
    local data = db()
    if not data then return nil end
    resetRollLinks()
    local run = {
        id = tonumber(data.nextRunID) or 1,
        name = d.name,
        key = d.key,
        instanceID = d.instanceID,
        zoneID = nil,
        difficulty = d.difficulty,
        faction = LJ.PlayerFaction and LJ:PlayerFaction() or nil,
        started = now(),
        lastSeen = now(),
        lootSeen = false,
        itemsSeen = 0,
        needs = {},
        pending = {},
        seenLinks = {},
        greeds = {},
        bosses = {},
        drops = {},
        rolls = {},
        timeline = {},
        detailVersion = 1,
        legacy = false,
        partial = partial == true,
        closed = false,
    }
    data.nextRunID = run.id + 1
    data.runs[#data.runs + 1] = run
    data.activeID = run.id
    inside = true
    blocked = false
    lootWindowOpen = false
    seenLootSlots, lootWindowClaims = {}, {}
    diag("run-start", run.id, string.format("name=%s instance=%s partial=%s",
        tostring(run.name), tostring(run.instanceID), tostring(run.partial)))
    LJ:Changed()
    return run
end

local function guidInstanceID()
    -- WoW Forever obfuscates the server and spawn fields of creature GUIDs (Patch 1.60.1),
    -- so no readable per-copy ID is available and instance copies are not told apart.
    return nil
end

local function observeUnit(unit)
    if type(UnitGUID) ~= "function" then return end
    local ok, guid = pcall(UnitGUID, unit)
    if ok then T:ObserveInstanceGUID(guid) end
end

local function resumableRun(d)
    local run, age = recentlyLeftRun()
    if not run or age <= 0 or not sameInstance(run, d) then return nil end
    -- A saved copy ID lets resumeRun buffer observations until a readable
    -- GUID proves which copy the player returned to.
    if age <= RESUME_SECONDS or run.corpseExit or (run.zoneIDKind == "zone" and run.zoneID) then return run end
end

local function playerIsDeadOrGhost()
    if type(UnitIsDeadOrGhost) ~= "function" then return false end
    local ok, value = pcall(UnitIsDeadOrGhost, "player")
    value = ok and LJ.Plain(value)
    return value == true or value == 1
end

function T:ObserveInstanceGUID(guid)
    pcall(LJ.Probe, "U01-guid", guid)
    if not inside then return false end
    local run = activeRun()
    if not run then return false end
    local zoneID, zoneKind = guidInstanceID(guid, run.instanceID)
    if not zoneID then return false end
    if run.reenterPending then
        if run.zoneIDKind == "zone" and zoneKind ~= "zone" then return false end
        local queue = pendingReentry
        pendingReentry = nil
        run.reenterPending = nil
        if run.zoneIDKind == zoneKind and run.zoneID ~= zoneID then
            -- A different instance copy: close the previous run and start fresh.
            diag("copy-mismatch", run.id, "zone=" .. tostring(zoneID))
            local fallback = {
                name = run.name, key = run.key, instanceID = run.instanceID,
                difficulty = run.difficulty,
            }
            local d = getDungeon()
            if queue and queue.run == run then endBeforeReentry(run, queue) end
            T:CloseActive("switched-instance")
            local candidate = T:StartRun(d or fallback, false)
            if candidate then
                candidate.zoneID, candidate.zoneIDKind = zoneID, zoneKind
                diag("copy-confirmed", candidate.id, "zone=" .. tostring(zoneID))
                if queue and queue.run == run then
                    candidate.started = queue.started
                    replayReentry(queue, candidate)
                end
            end
            observeUnit("target")
            observeUnit("mouseover")
            LJ:Changed()
            return true
        end
        run.zoneID, run.zoneIDKind = zoneID, zoneKind
        local last = run.timeline and run.timeline[#run.timeline]
        if not last or last.kind ~= "return" then timelineEvent(run, "return", queue and queue.started or now()) end
        if queue and queue.run == run then replayReentry(queue, run) end
        diag("copy-merged", run.id, "zone=" .. tostring(zoneID))
        LJ:Changed()
        return true
    end
    if not run.zoneID or (zoneKind and not run.zoneIDKind) then
        run.zoneID, run.zoneIDKind = zoneID, zoneKind
        diag("copy-confirmed", run.id, "zone=" .. tostring(zoneID))
        LJ:Changed()
    end
    return true
end

local function askResumeChoice(recent, d)
    if type(StaticPopupDialogs) ~= "table" or type(StaticPopup_Show) ~= "function" then return false end
    local definition = {
        text = LJ.L("RESUME_CHOICE_TEXT", d.name or recent.name or "?"),
        button1 = LJ.L("RESUME_CHOICE_CONTINUE"),
        button2 = LJ.L("RESUME_CHOICE_NEW"),
        OnAccept = function()
            local choice = pendingResumeChoice
            pendingResumeChoice = nil
            if not choice then return end
            pcall(LJ.Probe, "U02-choice", "continue")
            resumeRun(choice.run, choice.d)
            observeUnit("target")
            observeUnit("mouseover")
            LJ:Changed()
        end,
        OnCancel = function()
            local choice = pendingResumeChoice
            pendingResumeChoice = nil
            if not choice then return end
            pcall(LJ.Probe, "U02-choice", "new")
            T:StartRun(choice.d, false)
            observeUnit("target")
            observeUnit("mouseover")
            LJ:Changed()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = false,
        preferredIndex = 3,
        exclusive = 1,
    }
    local W = LJ.Widgets
    if W and type(W.StylePopup) == "function" then definition = W:StylePopup(definition) end
    StaticPopupDialogs[RESUME_POPUP] = definition
    pendingResumeChoice = { run = recent, d = d }
    pcall(LJ.Probe, "U02-resume-shown", "sinceEnd=" .. tostring(now() - (tonumber(recent.ended) or now())))
    StaticPopup_Show(RESUME_POPUP)
    return true
end

function T:CheckZone()
    local data = db()
    if not data then return end
    local wasFirst = firstCheck
    firstCheck = false
    local d = getDungeon()
    if d then
        if data.manualBlockedKey then
            if tostring(d.key) == data.manualBlockedKey then return end
            data.manualBlockedKey = nil
            blocked = false
        end
        if blocked then return end
        local run = activeRun()
        if run and sameInstance(run, d) then
            local outsideAt = run.outsideAt
            local reentering = (not inside) or outsideAt ~= nil
            if reentering then
                diag("zone-reenter", run.id, run.zoneID and "known-copy" or "unknown-copy")
                run.corpseExit = nil
            end
            inside = true
            run.outsideAt = nil
            run.lastSeen = now()
            run.key = d.key
            run.instanceID = d.instanceID or run.instanceID
            run.difficulty = d.difficulty or run.difficulty
            if d.name and d.name ~= "" and not (run.name and run.name:find(":")) then run.name = d.name end
            if reentering and run.zoneID then
                run.reenterPending = true
                reentryQueue(run, outsideAt or now())
            end
            observeUnit("target")
            observeUnit("mouseover")
            LJ:Changed()
            return
        end
        if run then T:CloseActive("switched-instance") end
        local resumed = resumableRun(d)
        if resumed then
            resumeRun(resumed, d)
            observeUnit("target")
            observeUnit("mouseover")
            return
        end
        if pendingResumeChoice then return end
        local recent = recentlyLeftRun()
        if recent and sameInstance(recent, d) and askResumeChoice(recent, d) then return end
        local candidate = T:StartRun(d, wasFirst)
        if candidate and lastExitedRun and lastExitUntil and now() < lastExitUntil then
            transitionGuardRun = candidate
        end
        observeUnit("target")
        observeUnit("mouseover")
    else
        data.manualBlockedKey = nil
        if pendingResumeChoice then
            pendingResumeChoice = nil
            if StaticPopup_Hide then StaticPopup_Hide(RESUME_POPUP) end
        end
        local wasInside = inside
        inside = false
        blocked = false
        local run = activeRun()
        if run then
            if wasInside then
                timelineEvent(run, "exit", now())
                run.corpseExit = playerIsDeadOrGhost() or nil
                exitGraceRun, exitGraceUntil = run, now() + EXIT_SETTLE_SECONDS
                lastExitedRun, lastExitUntil = run, exitGraceUntil
                diag("exit-settle", run.id, "start")
                if C_Timer and type(C_Timer.After) == "function" then
                    after(EXIT_SETTLE_SECONDS + 1, function()
                        if activeRun() == run and not inside then T:CheckZone() end
                    end)
                else
                    exitGraceUntil = now()
                end
                run.outsideAt = run.outsideAt or now()
                run.lastSeen = now()
                diag("zone-leave", run.id)
                LJ:Changed()
                return
            end
            if inExitGrace(run) then return end
            -- Kein "paused"-Zustand mehr: nach dem kurzen Settle-Fenster wird der
            -- Run geschlossen (wie NIT die Instanz beim Verlassen schließt).
            local reason = "left"
            if LJ.DungeonCompletion then
                local dungeon, observed, required = LJ.DungeonCompletion:Match(run)
                if dungeon then
                    reason = "all-bosses-cleared"
                    diag("completion-close", run.id, "bosses=" .. observed .. "/" .. required)
                else
                    diag("completion-pending", run.id, "bosses=" .. observed .. "/" .. required)
                end
            end
            exitGraceRun, exitGraceUntil = nil, nil
            run.reenterPending = nil
            T:CloseActive(reason)
        end
    end
end

-- ---------------------------------------------------------------- Item-Links
local function rollToken(rollID)
    local token = rollStartTokens[rollID]
    if not token then
        token = {}
        rollStartTokens[rollID] = token
    end
    token.at = now()
    return token
end

local function forgetRollLink(rollID)
    rollLinks[rollID], rollLinkAt[rollID] = nil, nil
end

local function cacheRollLink(rollID, link)
    rollID = tonumber(rollID)
    if not rollID then return nil end
    link = LJ:NormalizeLink(link)
    if link and link ~= "" then
        rollLinks[rollID] = link
        rollLinkAt[rollID] = now()
    end
    return rollLinks[rollID]
end

local function readRollLink(rollID)
    if type(GetLootRollItemLink) ~= "function" then return nil end
    local ok, link = pcall(GetLootRollItemLink, rollID)
    if ok then return LJ:NormalizeLink(LJ.Plain(link)) end
end

local function rollLink(rollID)
    rollID = tonumber(rollID)
    if not rollID then return nil end
    local link = rollLinks[rollID]
    if link then return link end
    link = readRollLink(rollID)
    if type(link) ~= "string" or link == "" then return nil end
    return cacheRollLink(rollID, link)
end

local function pruneRollLinks()
    local current = now()
    if current < nextRollPruneAt then return end
    nextRollPruneAt = current + 60
    local cutoff = current - 900
    for id, at in pairs(rollLinkAt) do
        if at < cutoff then forgetRollLink(id) end
    end
    for id, token in pairs(rollStartTokens) do
        if token.at < cutoff then rollStartTokens[id] = nil end
    end
end

local function pendingRun()
    local run = activeRun()
    return (inside or inExitGrace(run)) and run or nil
end

local function itemObservationKey(link)
    if type(link) == "string" then return link:match("|H(item:[^|]+)|h") or link end
end

local compatibleItemVariant = LJ.CompatibleItemVariant or function() return true end

local function itemObservations(seen)
    local keys = seenItemKeys[seen]
    if not keys then
        keys = {}
        for link, value in pairs(seen) do
            if value and type(link) == "string" then keys[itemObservationKey(link)] = true end
        end
        seenItemKeys[seen] = keys
    end
    return keys
end

local function hasSeenItem(run, link)
    local seen = run.seenLinks
    return seen and link and (seen[link] or itemObservations(seen)[itemObservationKey(link)])
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
        added = now(),
        countedLoot = info and info.loot == true or false,
        source = source,
    }
    while #run.pending > 80 do table.remove(run.pending, 1) end
    diag("item-pending", id, source)
    if type(LJ.LoadItem) == "function" then LJ:LoadItem(link, id) end
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
    if hasSeenItem(run, link) then
        diagDuplicate()
        return false
    end
    run.seenLinks[link] = true
    itemObservations(run.seenLinks)[itemObservationKey(link)] = true

    local info = LJ:ClassifyItem(link)
    diagItem(id, info, source)
    if LJ.debugMode then LJ:NoteItemDebug(link, source) end
    if not info or info.known == false then
        diag("item-defer", id, source)
        queuePending(run, link, id, info, source)
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
    if changed then LJ:Changed() end
    return changed
end

local function finalizePending(entry, info)
    if info.quest then return "drop", false end
    if not info.loot then return "keep", false end
    return "done", true
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
                    local action, counted = finalizePending(p, info)
                    diagItem(p.id or info.id, info, "reclassify")
                    if counted and not p.countedLoot then
                        p.countedLoot = true
                        run.lootSeen = true
                        run.itemsSeen = (run.itemsSeen or 0) + 1
                        changed = true
                        diag("pending-counted", p.id or info.id)
                    end
                    if action == "keep" then
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

function T:RefreshPendingItemData()
    self:ReclassifyPending()
    local data = db()
    if not data then return end
    local requested = {}
    for _, run in ipairs(data.runs or {}) do
        for _, pending in ipairs(run.pending or {}) do
            local id = tonumber(pending.id) or LJ:ItemID(pending.link)
            if id and not requested[id] then
                requested[id] = true
                LJ:LoadItem(pending.link, id)
            end
        end
    end
end

function T:FinalizeRunItems(run)
    if not run then return end
    local pending = run.pending
    if type(pending) == "table" and #pending > 0 then
        diag("pending-finalized", run.id, "n=" .. tostring(#pending))
    end
end

-- ---------------------------------------------------------------- Need-Rolls
local function needMatches(n, itemID, link)
    if link and n.link == link then return true end
    if itemID and n.id == itemID then return compatibleItemVariant(n.link, link) end
    if not n.link and not n.id and n.rollID and needRollTokens[n] == rollStartTokens[n.rollID] then
        local cached = rollLinks[n.rollID]
        if link and cached == link then return true end
        if itemID and LJ:ItemID(cached) == itemID then return compatibleItemVariant(cached, link) end
    end
    return false
end

function T:FindPendingNeed(itemID, link, maxAge)
    local run = activeRun()
    if not run then return nil, nil end
    local found, matches = nil, 0
    local at = now()
    for _, need in ipairs(run.needs or {}) do
        local stamp = tonumber(need.at) or 0
        local age = at - stamp
        if need.result == nil and age >= 0 and age <= (maxAge or 900) and needMatches(need, itemID, link) then
            matches = matches + 1
            if not found or stamp >= (tonumber(found.at) or 0) then
                found = need
            end
        end
    end
    return found, run, matches
end

function T:ResolveNeed(need, result, reason, run)
    if not need or (result ~= "won" and result ~= "lost") then return false end
    if reason == "loot-history" then
        if need.reason == reason and need.result == result then return false end
    elseif need.reason == "loot-history" or need.result == "won"
        or (need.result == "lost" and result ~= "won") then
        return false
    end
    need.result = result
    need.resolvedAt = now()
    need.reason = reason or "event"
    diag("need-result", need.id, tostring(result) .. ":" .. tostring(need.reason))
    LJ:Changed()
    return true
end

-- Loot history settles whether our own Greed roll won the item. Without a
-- matching history result the Greed roll stays a possible source of the bag gain.
local function greedMayHaveWon(run, greed)
    for _, drop in ipairs((run and run.drops) or {}) do
        if drop.id == greed.id and math.abs((drop.at or 0) - (greed.at or 0)) <= 180
            and drop.winnerSource == "lootHistory" then
            return drop.rollKind == "greed" and LJ:IsMe(drop.winner) == true
        end
    end
    return true
end

function T:HasGreedConflict(need, run)
    local id = need and need.id
    if not id then return false end
    local at = need.at or now()
    for i = 1, #((run and run.greeds) or {}) do
        local g = run.greeds[i]
        if g.id == id and math.abs((g.at or 0) - at) <= 180 and greedMayHaveWon(run, g) then return true end
    end
    return false
end

local function competingBagGain(need, run, count)
    local baseline = tonumber(need.before)
    for _, other in ipairs((run and run.needs) or {}) do
        if other ~= need and other.id == need.id then
            local confirmedLoss = other.result == "lost" and (other.reason == "loot-history"
                or other.reason == "chat-other-won" or other.reason == "chat-all-passed")
            local before = tonumber(other.before)
            local resolvedAt = tonumber(other.resolvedAt)
            -- A later count can only be independent if its starting count already includes the win.
            local previousGain = other.result == "won" and resolvedAt and resolvedAt <= (need.at or 0)
                and before and baseline and before < baseline
            if not confirmedLoss and not previousGain and (not before or count > before) then
                return true
            end
        end
    end
    return false
end

function T:ResolveNeedByBags(need, run, force)
    if not need or need.result == "won" then return false end
    if need.result == "lost" and not force then return false end
    local id = need.id
    if not id then
        return false
    end
    local count = LJ:ItemCount(id)
    local before = tonumber(need.before)
    if count == nil or before == nil then
        diag("bags-unavailable", id)
        return false
    end
    diag("bags-check", id, "count=" .. tostring(count) .. " before=" .. tostring(before))
    if count > before then
        if competingBagGain(need, run, count) then
            diag("need-ambiguous", id, "bags")
            return false
        end
        if T:HasGreedConflict(need, run) then
            diag("greed-guard", id)
            return false
        end
        return T:ResolveNeed(need, "won", "bags", run)
    end
    for _, other in ipairs((run and run.needs) or {}) do
        if other ~= need and other.id == id and other.result ~= "lost"
            and math.abs((other.at or 0) - (need.at or 0)) <= 180 then
            diag("need-ambiguous", id, "bags")
            return false
        end
    end
    return T:ResolveNeed(need, "lost", "bags", run)
end

function T:ResolveStaleNeeds(run, force)
    if not run or run.closedReason == "manual" then return end
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
    local run = activeRun()
    if run and not run.reenterPending and (inside or inExitGrace(run)) then
        T:ResolveStaleNeeds(run, force)
    end
end

function T:RepairLostNeeds()
    local run = activeRun()
    if not run or run.reenterPending or (not inside and not inExitGrace(run)) then return end
    local t = now()
    local changed = false
    for _, n in ipairs(run.needs or {}) do
        if n.result == "lost" and not n.noRepair and n.id
            and (n.reason == "bags" or n.reason == "no-item") then
            local at = n.resolvedAt or n.at or 0
            if t - at <= REPAIR_SECONDS then
                local before = tonumber(n.before)
                local count = LJ:ItemCount(n.id)
                if before and count and count > before and not competingBagGain(n, run, count)
                    and not T:HasGreedConflict(n, run) then
                    n.result = "won"
                    n.resolvedAt = t
                    n.reason = "repair"
                    changed = true
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

function T:OnNeedRoll(rollID, link, evidence)
    if not inside then return end
    local run = activeRun()
    if not run then return end
    rollID = tonumber(LJ.Plain(rollID))
    local queue = reentryQueue(run)
    if queue then
        link = LJ:NormalizeLink(LJ.Plain(link)) or (rollID and readRollLink(rollID))
        local id = LJ:ItemID(link)
        local observation = { id = id, before = id and LJ:ItemCount(id) }
        enqueueReentry(queue, function()
            T:OnNeedRoll(rollID, link, observation)
        end)
        return
    end
    if not reentryEventTime and transitioningFromOtherRun(run) then
        diag("exit-late-roll-skip", tonumber(rollID), "need")
        return
    end
    local token = rollID and rollToken(rollID)
    if not link and rollID then
        if evidence then link = rollLinks[rollID] else link = rollLink(rollID) end
    end
    link = LJ:NormalizeLink(link)
    local id = LJ:ItemID(link)
    local function initialCount(itemID)
        if evidence then
            if itemID == evidence.id then return evidence.before end
        elseif itemID then
            return LJ:ItemCount(itemID)
        end
    end

    -- Forever liefert beim eigenen Need-Chat keinen Item-Link. Solche Echos
    -- dürfen keinen zweiten offenen Eintrag anlegen; sie bestätigen nur die
    -- bereits per Roll-ID erfassten Needs.
    if not rollID and not id then
        local candidates = 0
        for i = 1, #(run.needs or {}) do
            local n = run.needs[i]
            if n.result == nil and n.rollID and not n.chatSeen
                and now() - (n.at or 0) <= NEED_CHAT_SECONDS then
                n.chatSeen = true
                candidates = candidates + 1
            end
        end
        if candidates > 0 then
            diag("need-chat-merge", nil, "open=" .. tostring(candidates))
            LJ:Changed()
            return
        end
        -- Ohne Item-Link und ohne Roll-ID gibt es nichts, was sich spaeter
        -- aufloesen liesse; der Eintrag bliebe dauerhaft "offen".
        diag("need-chat-unlinked-skip", nil, "open=0")
        return
    end

    if link then T:RecordItem(link, "need-roll") end

    local match, matches = nil, 0
    for i = 1, #(run.needs or {}) do
        local n = run.needs[i]
        if n.result == nil then
            local sameRoll = rollID and n.rollID == rollID
                and (not needRollTokens[n] or needRollTokens[n] == token)
                and (not id or not n.id or id == n.id)
            local sameItem = rollID and id and n.id == id and not n.rollID
                and now() - (n.at or 0) <= DEDUPE_SECONDS
            local sameCached = id and n.rollID and not n.chatSeen
                and needMatches(n, id, link)
                and not rollID and now() - (n.at or 0) <= DEDUPE_SECONDS
            if sameRoll then match, matches = n, 1; break end
            if sameItem or sameCached then match, matches = n, matches + 1 end
        end
    end
    if matches > 1 then
        diag("need-ambiguous", id, "open")
        return
    end
    if match then
        local filled = false
        if not match.link and link then match.link = link; filled = true end
        if not match.id and id then match.id = id; filled = true end
        if not match.rollID and rollID then match.rollID = rollID; filled = true end
        if rollID then needRollTokens[match] = token end
        if not rollID then match.chatSeen = true end
        if match.id and not match.before then match.before = initialCount(match.id) end
        if filled then diag("need-link", match.id or id, "roll=" .. tostring(rollID)) end
        LJ:Changed()
        return
    end

    local need = {
        at = now(),
        id = id,
        link = link,
        rollID = rollID,
        chatSeen = not rollID,
        before = initialCount(id),
    }
    run.needs[#run.needs + 1] = need
    if rollID then needRollTokens[need] = token end
    diag("need-open", id, "roll=" .. tostring(rollID))
    LJ:Changed()

    if not link and rollID then
        local function fill()
            if inside and activeRun() == run and not run.reenterPending
                and rollStartTokens[rollID] == token and not need.link then
                T:FillNeedLink(need, rollID)
            end
        end
        after(0.5, fill)
        after(2, fill)
        after(6, fill)
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
    if filled then diag("need-link", need.id, "roll=" .. tostring(rollID)) end
    LJ:Changed()
end

function T:MarkGreed(rollID, link, captured)
    if not inside then return end
    local run = activeRun()
    if not run then return end
    rollID = tonumber(LJ.Plain(rollID))
    local queue = reentryQueue(run)
    if queue then
        link = LJ:NormalizeLink(LJ.Plain(link)) or (rollID and readRollLink(rollID))
        enqueueReentry(queue, function() T:MarkGreed(rollID, link, true) end)
        return
    end
    if not reentryEventTime and transitioningFromOtherRun(run) then
        diag("exit-late-roll-skip", tonumber(rollID), "greed")
        return
    end
    if not link and rollID then
        if captured then link = rollLinks[rollID] else link = rollLink(rollID) end
    end
    link = LJ:NormalizeLink(link)
    if link then T:RecordItem(link, "greed-roll") end
    local id = LJ:ItemID(link)
    if not id then return end
    run.greeds = run.greeds or {}
    run.greeds[#run.greeds + 1] = { at = now(), id = id, link = link, rollID = rollID }
    while #run.greeds > 25 do table.remove(run.greeds, 1) end
    diag("greed", id, "roll=" .. tostring(rollID))
end

local function competingDrop(run, id, at, requireUnsettled, accept)
    local count, unsettled = 0, false
    for _, drop in ipairs(run.drops or {}) do
        if drop.id == id and (not accept or accept(drop))
            and math.abs((tonumber(drop.at) or 0) - at) <= CHAT_RESULT_ECHO_SECONDS then
            count = count + 1
            if not drop.winner and not drop.passed then unsettled = true end
            if count > 1 and (not requireUnsettled or unsettled) then return true end
        end
    end
    return false
end

local function potentialRollDrop(drop)
    return not drop.winner or drop.rollID or drop.lootHistoryKey
        or drop.winnerSource == "chat-win" or drop.winnerSource == "lootHistory"
end

function T:ResolveNeedByLink(link, result, reason)
    link = LJ:NormalizeLink(link)
    local id = LJ:ItemID(link)
    local need, run, matches = T:FindPendingNeed(id, link, 900)
    if not need then return false end
    if matches > 1 or competingDrop(run, id, now(), false, potentialRollDrop) then
        diag("need-ambiguous", id, reason or "chat")
        return false
    end
    if T:HasGreedConflict(need, run) then
        diag("need-ambiguous", id, "greed")
        return false
    end
    return T:ResolveNeed(need, result, reason, run)
end

local function pendingNeedByRoll(run, rollID)
    for _, need in ipairs(run.needs or {}) do
        if need.result == nil and need.rollID == rollID
            and (not needRollTokens[need] or needRollTokens[need] == rollStartTokens[rollID]) then
            return need
        end
    end
end

function T:ResolveNeedByRoll(rollID, run, expected)
    rollID = tonumber(rollID)
    run = run or activeRun()
    if not rollID or not run or run.reenterPending or run ~= activeRun() then return end
    local need = pendingNeedByRoll(run, rollID)
    if need and (not expected or need == expected) then
        diag("roll-resolve", need.id, "roll=" .. tostring(rollID))
        T:ResolveNeedByBags(need, run, true)
    end
end

-- ---------------------------------------------------------------- Loot-Events
-- ---------------------------------------------------------------- Boss-/Drop-Details
local function reopenedDrop(drops, link, source, claimed, at)
    if not source then return nil end
    local key = itemObservationKey(link)
    for i = #drops, 1, -1 do
        local drop = drops[i]
        if lootWindowSources[drop] == source and itemObservationKey(drop.link) == key
            and (not claimed or not claimed[drop]) then
            local age = at - (tonumber(drop.lastWindowAt) or tonumber(drop.at) or 0)
            if age >= 0 and age <= LOOT_WINDOW_ECHO_SECONDS then return drop end
        end
    end
end

local function lootSourceNPC(run, guid)
    guid = LJ.Plain(guid)
    if not run or type(guid) ~= "string" then return nil end
    local kind, map, entry = guid:match("^(%a+)%-%d+%-[^-]+%-(%d+)%-%d+%-(%d+)%-[^-]+$")
    if kind ~= "Creature" and kind ~= "Vehicle" then return nil end
    if run.instanceID and tonumber(run.instanceID) ~= tonumber(map) then return nil end
    local npc = tonumber(entry)
    if npc and npc > 0 then return npc end
end

local function noteDrop(run, link, winner, boss, source, rollValue, rollKind, passed, winnerClass, rollID, windowClaims, windowSource)
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
    local sourceNPCID = lootSourceNPC(run, windowSource)
    rollValue = tonumber(rollValue)
    rollID = tonumber(rollID)
    local token = rollID and rollStartTokens[rollID]
    rollKind = (rollKind == "need" or rollKind == "greed") and rollKind or nil
    local at = now()

    run.drops = run.drops or {}
    local reopened = reopenedDrop(run.drops, link, windowSource, windowClaims, at)
    for i = #run.drops, 1, -1 do
        local d = run.drops[i]
        local sources = d.sources or { [d.source or "unknown"] = true }
        local age = at - (d.at or 0)
        local mergeAge = (source == "roll" or sources.roll) and 180 or 30
        local echo = d == reopened
        local within = echo or (age >= 0 and age <= mergeAge)
        local sameRoll = rollID and d.rollID == rollID
            and (not token or not dropRollTokens[d] or dropRollTokens[d] == token)
        local priorBossID = tonumber(d.bossID) or 0
        if (not reopened or echo) and d.id == id and within and (not windowClaims or not windowClaims[d])
            and compatibleItemVariant(d.link, link)
            and (bossID <= 0 or priorBossID <= 0 or bossID == priorBossID)
            and (not sourceNPCID or not d.sourceNPCID or sourceNPCID == d.sourceNPCID)
            and (echo or not sources[source] or sameRoll) and (not rollID or not d.rollID or sameRoll) then
            local sameWinner = not d.winner or not winner or samePlayer(d.winner, winner)
            if sameWinner then
                local changed = false
                if windowClaims then windowClaims[d] = true end
                d.sources = sources
                sources[source] = true
                if source == "loot-window" and d.lastWindowAt ~= at then
                    d.lastWindowAt = at
                    changed = true
                end
                if windowSource then lootWindowSources[d] = windowSource end
                if sourceNPCID and not d.sourceNPCID then d.sourceNPCID = sourceNPCID; changed = true end
                if windowSource == false and not d.lootSourceAmbiguous then
                    d.lootSourceAmbiguous, changed = true, true
                end
                if winner and not d.winner then
                    d.winner = winner
                    d.winnerSource = source
                    changed = true
                end
                if winner and winnerClass and not d.winnerClass then d.winnerClass = winnerClass; changed = true end
                if rollValue and not d.roll then d.roll = rollValue; changed = true end
                if rollKind and not d.rollKind then d.rollKind = rollKind; changed = true end
                if rollID and not d.rollID then d.rollID = rollID; changed = true end
                if token then dropRollTokens[d] = token end
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
                return true, d
            end
        end
    end

    if not rollValue and winner then
        local kind, value = rollFor(run, id, winner)
        rollValue, rollKind = value, kind
    end

    local drop = {
        id = id,
        link = link,
        bossID = bossID,
        sourceNPCID = sourceNPCID,
        lootSourceAmbiguous = windowSource == false or nil,
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
        windowSlotObserved = windowClaims ~= nil or nil,
    }
    run.drops[#run.drops + 1] = drop
    if windowClaims then windowClaims[drop] = true end
    if windowSource then lootWindowSources[drop] = windowSource end
    if token then dropRollTokens[drop] = token end
    diag("drop-new", id, source)
    LJ:Changed()
    return true, drop
end

function T:NoteDrop(...)
    return noteDrop(activeRun(), ...)
end

function T:NoteRoll(link, name, kind, value, source, run)
    run = run or activeRun()
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
    if kind ~= "need" and kind ~= "greed" and kind ~= "transmog" then return false end
    run.rolls = run.rolls or {}
    local at = now()
    if source ~= "history" then
        for i = #run.rolls, 1, -1 do
            local prior = run.rolls[i]
            if at - (tonumber(prior.at) or 0) > 300 then break end
            if prior.lootHistoryKey and not prior.chatSeen and prior.id == id
                and prior.kind == kind and tonumber(prior.value) == value
                and samePlayer(prior.name, name)
                and not competingDrop(run, id, at) then
                prior.chatSeen = true
                return false
            end
        end
    end
    run.rolls[#run.rolls + 1] = {
        id = id, name = name, kind = kind, value = value, at = at,
        chatSeen = source ~= "history",
    }
    diag("roll", id, kind .. "=" .. tostring(value) .. (mine and " self" or " other"))

    if source ~= "history" then
        if not competingDrop(run, id, at) then
            for i = #(run.drops or {}), 1, -1 do
                local drop = run.drops[i]
                if drop.id == id and not drop.lootHistoryKey and not drop.roll
                    and compatibleItemVariant(drop.link, link)
                    and math.abs(at - (drop.at or 0)) <= 300
                    and samePlayer(drop.winner, name) then
                    drop.roll = value
                    drop.rollKind = kind
                    break
                end
            end
        end
        if kind == "need" and mine then
            local match, count
            count = 0
            for _, need in ipairs(run.needs or {}) do
                if needMatches(need, id, link) and not need.roll and math.abs(at - (need.at or 0)) <= 300 then
                    match, count = need, count + 1
                end
            end
            if count == 1 then
                match.roll, match.rollKind = value, kind
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

local function recentDrop(run, id, at, historyKey, link, winnerName, encounterID)
    local keyed
    for i = #(run.drops or {}), 1, -1 do
        local drop = run.drops[i]
        if drop.id == id and drop.lootHistoryKey == historyKey then
            if keyed or not compatibleItemVariant(drop.link, link) then return nil, true, true end
            keyed = drop
        end
    end
    if keyed then return keyed end
    local candidates, winnerMatches = {}, {}
    for i = #(run.drops or {}), 1, -1 do
        local drop = run.drops[i]
        local bossID = tonumber(drop.bossID) or 0
        if drop.id == id and not drop.lootHistoryKey
            and compatibleItemVariant(drop.link, link)
            and (not encounterID or encounterID <= 0 or bossID <= 0 or bossID == encounterID)
            and math.abs((tonumber(drop.at) or 0) - at) <= 900 then
            candidates[#candidates + 1] = drop
            if winnerName and samePlayer(drop.winner, winnerName) then
                winnerMatches[#winnerMatches + 1] = drop
            end
        end
    end
    if #winnerMatches == 1 then return winnerMatches[1] end
    if #candidates == 1 and (#winnerMatches == 1 or not winnerName
        or not candidates[1].winner) then return candidates[1] end
    return nil, #candidates > 0
end

-- Late events can finish a closed run, but only when known drop evidence
-- locates the result. An encounter or item link alone is insufficient there.
local function runForHistory(id, link, historyKey, winnerName, encounterID)
    local current = activeRun()
    if current and not inside and not inExitGrace(current) then
        current = nil
    end
    local exactRun, exactDrop, possibleRun, possibleDrop, possibleUnkeyed
    local possibleCount = 0
    local at = now()
    local data = db()
    for _, run in ipairs(data and data.runs or {}) do
        local ended = tonumber(run.ended)
        local recent = run.closed
            and ended and at >= ended and at - ended <= LATE_HISTORY_SECONDS
        if run == current or recent then
            local drop, seen, duplicate = recentDrop(run, id, at, historyKey, link, winnerName, encounterID)
            if duplicate then return nil end
            if drop and drop.lootHistoryKey == historyKey then
                if exactRun or run.closedReason == "manual" then return nil end
                exactRun, exactDrop = run, drop
            elseif run.closedReason ~= "manual" and (drop or seen or (run == current
                and (bossByID(current, encounterID) or hasSeenItem(current, link)))) then
                possibleRun, possibleDrop, possibleUnkeyed = run, drop, seen
                possibleCount = possibleCount + 1
            end
        end
    end
    if exactRun then return exactRun, exactDrop end
    if possibleCount > 1 then return nil end
    if possibleCount == 1 then
        if possibleDrop or possibleRun == current then
            return possibleRun, possibleDrop, possibleUnkeyed
        end
        return nil
    end
    if not previousLootRun(current) then return current end
end

-- C_LootHistory liefert für Encounter-Beute die echten Rollzahlen aller
-- Spieler. Die Chatmeldungen bleiben der Fallback für Trash und ältere Runs.
local function bindHistoryNeed(run, id, value, historyKey, link)
    local drop = recentDrop(run, id, now(), historyKey, link)
    local rollID = drop and drop.lootHistoryKey == historyKey and drop.rollID
    local token = rollID and dropRollTokens[drop]
    local match, count, exact, exactCount = nil, 0, nil, 0
    for _, need in ipairs(run.needs or {}) do
        local sameRoll = rollID and need.rollID == rollID
            and (not token or not needRollTokens[need] or needRollTokens[need] == token)
        if needMatches(need, id, link) and (not need.lootHistoryKey or need.lootHistoryKey == historyKey)
            and (not rollID or not need.rollID or sameRoll) then
            if need.lootHistoryKey == historyKey or sameRoll then
                exact, exactCount = need, exactCount + 1
            elseif math.abs(now() - (need.at or 0)) <= 300
                and (not value or not need.roll or need.roll == value) then
                match, count = need, count + 1
            end
        end
    end
    if exactCount == 1 then
        match = exact
    elseif exactCount ~= 0 or count ~= 1 or competingDrop(run, id, now()) then
        return nil
    end
    if match.lootHistoryKey ~= historyKey or (value and value ~= match.roll) then
        match.lootHistoryKey = historyKey
        if value then match.roll, match.rollKind = value, "need" end
        LJ:Changed()
    end
    return match
end

function T:NoteRollFromHistory(link, name, kind, value, historyKey, isSelf, run)
    run = run or activeRun()
    if not run then return false end
    link = LJ:NormalizeLink(link)
    local id = LJ:ItemID(link)
    value = tonumber(value)
    name = LJ.Plain(name)
    if not id or not value or value < 1 or value > 100
        or type(name) ~= "string" or name == "" then return false end
    if isSelf == nil then isSelf = LJ:IsMe(name) end
    if kind == "need" and isSelf then bindHistoryNeed(run, id, value, historyKey, link) end
    local at = now()
    local chatEcho
    for i = #(run.rolls or {}), 1, -1 do
        local roll = run.rolls[i]
        if roll.id == id and roll.kind == kind and tonumber(roll.value) == value
            and samePlayer(roll.name, name) then
            if roll.lootHistoryKey == historyKey then
                return false
            end
            if not chatEcho and not roll.lootHistoryKey
                and at - (tonumber(roll.at) or 0) <= 300 then
                chatEcho = roll
            end
        end
    end
    if chatEcho and not competingDrop(run, id, at) then
        chatEcho.lootHistoryKey = historyKey
        chatEcho.chatSeen = true
        return false
    end
    if not T:NoteRoll(link, name, kind, value, "history", run) then return false end
    run.rolls[#run.rolls].lootHistoryKey = historyKey
    return true
end

local function historySelf(entry, name)
    local isSelf = LJ.Plain(entry.isSelf)
    if type(isSelf) == "boolean" then return isSelf end
    if name then return LJ:IsMe(name) end
end

local function recordLootHistoryDrop(encounterID, lootListID, link, info, routedRun)
    local historyKey = tostring(encounterID) .. ":" .. tostring(lootListID)
    local id = LJ:ItemID(link)
    local winner = type(info.winner) == "table" and info.winner or nil
    local winnerName = winner and LJ.Plain(winner.playerName) or nil
    if type(winnerName) == "string" then
        winnerName = winnerName:match("^%s*(.-)%s*$")
        if winnerName == "" then winnerName = nil end
    else
        winnerName = nil
    end
    local run, drop, observedUnkeyed
    if routedRun then
        local conflict
        drop, observedUnkeyed, conflict = recentDrop(routedRun, id, now(), historyKey, link, winnerName, encounterID)
        if not conflict then run = routedRun end
    else
        run, drop, observedUnkeyed = runForHistory(id, link, historyKey, winnerName, encounterID)
    end
    if not run then
        diag("loot-history-skip", id, "no unique run")
        return
    end
    local observedBoss = bossByID(run, encounterID)
    local observedItem = hasSeenItem(run, link)
    if not drop and not observedBoss and not observedItem then
        diag("loot-history-skip", id, "unseen")
        return
    end
    local createdDrop = false
    if not drop and not observedUnkeyed then
        -- Loot History can arrive without a START_LOOT_ROLL drop. A matching
        -- encounter or a link already observed in this run confirms the item.
        if not observedItem then
            T:RecordItem(link, "loot-history")
        end
        drop = {
            id = id, link = link, bossID = observedBoss and observedBoss.id or 0,
            bossName = observedBoss and observedBoss.name or nil, at = now(),
            lootHistoryKey = historyKey, source = "loot-history",
            sources = { ["loot-history"] = true },
        }
        run.drops = run.drops or {}
        run.drops[#run.drops + 1] = drop
        createdDrop = true
        diag("drop-new", id, "loot-history")
    end
    lootHistoryDrops = lootHistoryDrops + 1
    local dropBound = createdDrop
    if drop and drop.lootHistoryKey ~= historyKey then
        drop.lootHistoryKey = historyKey
        dropBound = true
    end
    if drop and drop.source == "loot-history-recovered" then
        drop.link = link
        drop.source = "loot-history"
        drop.sources = drop.sources or {}
        drop.sources["loot-history"] = true
        dropBound = true
    end

    local winnerClass = winner and LJ.Plain(winner.playerClass) or nil
    if type(winnerClass) ~= "string" then winnerClass = nil end
    local winnerKind = winner and historyKind(winner.state) or nil
    if winnerKind == "pass" then winnerKind = nil end
    local winnerRoll = winner and tonumber(LJ.Plain(winner.roll)) or nil
    local winnerIsSelf
    if winner then winnerIsSelf = historySelf(winner, winnerName) end

    local added = 0
    local ownNeed = historyKind(info.playerRollState) == "need"
    local ownRoll
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
            local isSelf = historySelf(entry, name)
            if isSelf and kind == "need" then
                ownNeed = true
                if value and value >= 1 and value <= 100 then ownRoll = value end
            end
            if name and value and kind and kind ~= "pass" then
                if T:NoteRollFromHistory(link, name, kind, value, historyKey, isSelf, run) then added = added + 1 end
            end
        end
    end
    if winnerName and winnerKind and winnerRoll then
        if T:NoteRollFromHistory(link, winnerName, winnerKind, winnerRoll, historyKey, winnerIsSelf, run) then
            added = added + 1
        end
    end

    if drop and winnerName then
        if not samePlayer(drop.winner, winnerName) then
            drop.roll, drop.rollKind, drop.winnerClass = nil, nil, nil
        elseif winnerKind and drop.rollKind and winnerKind ~= drop.rollKind then
            drop.roll = nil
        end
        drop.winner, drop.winnerSource, drop.passed = winnerName, "lootHistory", false
        drop.winnerClass = winnerClass or drop.winnerClass
        drop.rollKind = winnerKind or drop.rollKind
        if winnerRoll and winnerRoll >= 1 and winnerRoll <= 100 then drop.roll = winnerRoll end
        diag("drop-merge", id, "lootHistory")
    elseif drop and info.allPassed == true and not drop.winner then
        drop.passed = true
    end

    local needResult
    if winnerIsSelf == true and winnerKind == "need" then
        needResult = "won"
        ownRoll = ownRoll or (winnerRoll and winnerRoll >= 1 and winnerRoll <= 100 and winnerRoll or nil)
    elseif ownNeed and (winnerIsSelf == false or info.allPassed == true) then
        needResult = "lost"
    end
    if needResult then
        local need = bindHistoryNeed(run, id, ownRoll, historyKey, link)
        if need then T:ResolveNeed(need, needResult, "loot-history", run) end
    end

    lootHistoryRolls = lootHistoryRolls + added
    diag("loot-history", id, "rolls=" .. tostring(added)
        .. " winner=" .. tostring(winnerName and "yes" or "no"))
    if dropBound or added > 0 or winnerName or info.allPassed == true then LJ:Changed() end
end

local function historyPlayerSnapshot(entry)
    entry = LJ.Plain(entry)
    if type(entry) ~= "table" then return nil end
    return {
        playerName = LJ.Plain(entry.playerName), playerClass = LJ.Plain(entry.playerClass),
        state = LJ.Plain(entry.state), roll = LJ.Plain(entry.roll), isSelf = LJ.Plain(entry.isSelf),
    }
end

function T:OnLootHistoryDrop(encounterID, lootListID)
    local api = _G.C_LootHistory
    if type(api) ~= "table" or type(api.GetSortedInfoForDrop) ~= "function" then return end
    encounterID = tonumber(LJ.Plain(encounterID))
    lootListID = tonumber(LJ.Plain(lootListID))
    if not encounterID or not lootListID then return end
    local ok, info = pcall(api.GetSortedInfoForDrop, encounterID, lootListID)
    info = ok and LJ.Plain(info) or nil
    if type(info) ~= "table" then return end
    local link = LJ:NormalizeLink(LJ.Plain(info.itemHyperlink))
    if not LJ:ItemID(link) then return end
    local queue = reentryQueue(activeRun())
    if not queue then return recordLootHistoryDrop(encounterID, lootListID, link, info) end

    local snapshot = {
        winner = historyPlayerSnapshot(info.winner), playerRollState = LJ.Plain(info.playerRollState),
        allPassed = LJ.Plain(info.allPassed) == true, rollInfos = {},
    }
    local entries = LJ.Plain(info.rollInfos)
    if type(entries) == "table" then
        for _, entry in ipairs(entries) do
            local player = historyPlayerSnapshot(entry)
            if player then snapshot.rollInfos[#snapshot.rollInfos + 1] = player end
        end
    end
    queue.history = queue.history or {}
    enqueueReentry(queue, function(destination)
        recordLootHistoryDrop(encounterID, lootListID, link, snapshot, destination)
    end, queue.history)
end

function T:NotePassed(link)
    local run = activeRun()
    if not run then return false end
    local id = LJ:ItemID(link)
    if competingDrop(run, id, now(), true) then return false end
    diag("passed", id)
    return noteDrop(run, link, nil, nil, "chat", nil, nil, true)
end

function T:NoteSeenDrop(link, source, rollID, windowClaims, windowSource)
    local run = activeRun()
    if not run then return false end
    source = source or "seen"
    -- Quest items are neither loot nor counted. A window sighting without a
    -- recipient would only add a nameless drop line to the run details.
    if source == "loot-window" and not rollID then
        local ok, info = pcall(LJ.ClassifyItem, LJ, link)
        if ok and info and info.quest then return false end
    end
    return noteDrop(run, link, nil, nil, source, nil, nil, nil, nil, rollID, windowClaims, windowSource)
end

local function noteBoss(run, id, name, at, followUp)
    local bosses = run.bosses
    for i = #bosses, 1, -1 do
        local boss = bosses[i]
        if at - (boss.at or 0) > 60 then break end
        local same = id and boss.id and id == boss.id
            or ((not id or not boss.id) and lower(boss.name) == lower(name))
        if not same and followUp then same = LJ.DungeonLoot:MatchesBoss(run, boss.name, name) end
        if same then
            if id then boss.id = id end
            if name and (id or not boss.name) then boss.name = name end
            return
        end
    end
    bosses[#bosses + 1] = { id = id, name = name, at = at }
    while #bosses > MAX_BOSSES do table.remove(bosses, 1) end
end

local function recordBossEvent(run, id, name, event, at, members, routed)
    if not routed and transitioningFromOtherRun(run) and not bossByID(run, id) then
        diag("exit-late-boss-skip", id)
        return
    end
    diag("boss", id, event)
    if not inside then diag("exit-late-boss", id, event) end
    run.bosses = run.bosses or {}
    noteBoss(run, id, name, at)
    for _, member in ipairs(members) do noteBoss(run, nil, member, at, true) end
    if run.instanceID == 429 and type(run.name) == "string" and not run.name:find(":") then
        local wing = LJ.DungeonLoot and LJ.DungeonLoot:ResolveDireMaulWing(run)
        if wing then run.name = wing end
    end
    LJ:Changed()
end

function T:OnBossEvent(event, ...)
    local run = activeRun()
    if not run or (not inside and not inExitGrace(run)) then return end
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
    if type(name) ~= "string" or name == "" then name = nil end
    if not id and not name then return end

    local at = now()
    local members = {}
    local units = event == "ENCOUNTER_END" and LJ.Plain(select(6, ...))
    if type(units) == "table" and LJ.DungeonLoot then
        for _, value in ipairs(units) do
            local unit = LJ.Plain(value)
            if type(unit) == "table" and tonumber(LJ.Plain(unit.remainingHealthPercent)) == 0 then
                local npc = tonumber(LJ.Plain(unit.creatureID))
                local member = LJ.DungeonLoot:BossForNPC(run, npc)
                if member then members[#members + 1] = member end
            end
        end
    end
    local queue = reentryQueue(run)
    if queue then
        enqueueReentry(queue, function(destination)
            recordBossEvent(destination, id, name, event, at, members, true)
        end)
        return
    end
    recordBossEvent(run, id, name, event, at, members)
end

local function recordEncounterLoot(run, link, encounterID, routed)
    local boss = bossByID(run, encounterID)
    local previous = not routed and previousLootRun(run)
    if previous and not boss then
        local knownPrevious = bossByID(previous, encounterID) ~= nil
        if encounterID and encounterID > 0 and not knownPrevious then
            for _, drop in ipairs(previous.drops or {}) do
                if tonumber(drop.bossID) == encounterID then knownPrevious = true; break end
            end
        end
        if knownPrevious or transitioningFromOtherRun(run) then
            diag("exit-late-loot-skip", LJ:ItemID(link), "boss=" .. tostring(encounterID))
            return
        end
    end
    diag("encounter-loot", LJ:ItemID(link), "boss=" .. tostring(encounterID))
    if not inside then diag("exit-late-loot", LJ:ItemID(link), "boss=" .. tostring(encounterID)) end
    if not boss and encounterID and encounterID > 0 then
        boss = { id = encounterID, name = LJ.L("DETAIL_UNKNOWN_BOSS"), at = now() }
    end
    T:RecordItem(link, "encounter")
    noteDrop(run, link, nil, boss, "encounter")
end

function T:OnEncounterLoot(...)
    local run = activeRun()
    if not run or (not inside and not inExitGrace(run)) then return end
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
    local eventItemID = tonumber(LJ.Plain(args[2]))
    if eventItemID and eventItemID ~= LJ:ItemID(link) then return end
    local queue = reentryQueue(run)
    if queue then
        enqueueReentry(queue, function(destination)
            recordEncounterLoot(destination, link, encounterID, true)
        end)
        return
    end
    recordEncounterLoot(run, link, encounterID)
end

local function recordRollStart(run, rollID, observedLink, routed)
    if not routed and transitioningFromOtherRun(run) then
        diag("exit-late-roll-skip", rollID, "start")
        return
    end
    pruneRollLinks()
    local previousLink = rollLinks[rollID]
    local token = rollStartTokens[rollID]
    -- START can reuse an ID. Read the current link before trusting its cached item.
    forgetRollLink(rollID)
    local link
    if routed then link = cacheRollLink(rollID, observedLink)
    else link = rollLink(rollID) end
    if not token or token.cancelled or not link or link ~= previousLink then
        token = { at = now() }
        rollStartTokens[rollID] = token
    else
        token.at = now()
    end
    if link then
        diag("roll-start", LJ:ItemID(link), "roll=" .. tostring(rollID))
        T:RecordItem(link, "loot-roll")
        T:NoteSeenDrop(link, "roll", rollID)
        return
    end
    diag("roll-start-unlinked", nil, "roll=" .. tostring(rollID))
    if routed and LJ.Now() - now() >= 4 then return end
    local recorded = false
    local function retry()
        if recorded or not inside or activeRun() ~= run or run.reenterPending
            or rollStartTokens[rollID] ~= token then return end
        local l = rollLink(rollID)
        if l then
            recorded = true
            diag("roll-start-late", LJ:ItemID(l), "roll=" .. tostring(rollID))
            T:RecordItem(l, "loot-roll-late")
            T:NoteSeenDrop(l, "roll", rollID)
        end
    end
    after(0.4, retry)
    after(1.5, retry)
    after(4, retry)
end

function T:OnStartRoll(rollID)
    pcall(LJ.Probe, "U06-rollid", tostring(rollID) .. " t=" .. tostring(now()))
    if not inside then return end
    local run = activeRun()
    rollID = tonumber(LJ.Plain(rollID))
    if not run or not rollID then return end
    local queue = reentryQueue(run)
    if not queue then return recordRollStart(run, rollID) end
    queue.rollStarts = queue.rollStarts or {}
    local marker = {}
    queue.rollStarts[rollID] = marker
    local link = readRollLink(rollID)
    enqueueReentry(queue, function(destination)
        if link or queue.rollStarts[rollID] == marker then
            recordRollStart(destination, rollID, link, true)
        end
    end)
    if not link then
        local function capture()
            if pendingReentry == queue and queue.rollStarts[rollID] == marker and not link then
                link = readRollLink(rollID)
            end
        end
        after(0.4, capture)
        after(1.5, capture)
        after(4, capture)
    end
end

function T:OnCancelRoll(rollID)
    rollID = tonumber(LJ.Plain(rollID))
    local run = activeRun()
    if not rollID or not run then return end
    local queue = reentryQueue(run)
    if queue then
        enqueueReentry(queue, function() T:OnCancelRoll(rollID) end)
        return
    end
    diag("roll-cancel", nil, "roll=" .. tostring(rollID))
    local token = rollToken(rollID)
    token.cancelled = true
    local need = pendingNeedByRoll(run, rollID)
    if not need then return end
    local function resolve()
        if rollStartTokens[rollID] == token then T:ResolveNeedByRoll(rollID, run, need) end
    end
    after(4, resolve)
    after(20, resolve)
end

local function lootSlotSource(slot)
    if type(GetLootSourceInfo) ~= "function" then return nil end
    local function read(ok, ...)
        if not ok then return nil end
        -- A slot can contain more than one GUID/quantity pair.
        if select("#", ...) > 2 then return false end
        local guid = LJ.Plain((...))
        if type(guid) == "string" and guid ~= "" then return guid end
    end
    return read(pcall(GetLootSourceInfo, slot))
end

local function recordLootWindow(run, entries)
    if not lootWindowOpen then
        lootWindowOpen = true
        seenLootSlots, lootWindowClaims = {}, {}
        diag("loot-open", nil, "slots=" .. tostring(#entries))
    end
    for _, entry in ipairs(entries) do
        local observed = seenLootSlots[entry.key]
        if not observed then
            diag("loot-window", LJ:ItemID(entry.link), "slot=" .. tostring(entry.slot))
            T:RecordItem(entry.link, "loot-window")
            local _, drop = T:NoteSeenDrop(entry.link, "loot-window", nil, lootWindowClaims, entry.source)
            seenLootSlots[entry.key] = drop or true
        elseif type(observed) == "table" then
            if entry.source == false and not observed.lootSourceAmbiguous then
                observed.lootSourceAmbiguous = true
                LJ:Changed()
            elseif entry.source and not lootWindowSources[observed] then
                lootWindowSources[observed] = entry.source
                local npc = lootSourceNPC(run, entry.source)
                if npc and not observed.sourceNPCID then
                    observed.sourceNPCID = npc
                    LJ:Changed()
                end
            end
        end
    end
end

replayReentry = function(queue, run)
    local function replay(events)
        for _, entry in ipairs(events) do
            reentryEventTime = entry.at
            local ok = pcall(entry.replay, run)
            reentryEventTime = nil
            if not ok then diag("copy-replay-error", run.id) end
        end
    end
    replay(queue.events)
    -- Loot History may arrive before the matching drop or roll observation.
    if queue.history then replay(queue.history) end
    if not queue.current then
        lootWindowOpen = false
        seenLootSlots, lootWindowClaims = {}, {}
    end
end

function T:OnLootWindow()
    local run = activeRun()
    if not inside or not run or type(GetNumLootItems) ~= "function" then return end
    local ok, count = pcall(GetNumLootItems)
    count = ok and tonumber(LJ.Plain(count)) or nil
    if not count then return end
    local entries = {}
    for slot = 1, count do
        local okL, link = pcall(GetLootSlotLink, slot)
        link = okL and LJ.Plain(link) or nil
        if type(link) == "string" and link ~= "" then
            entries[#entries + 1] = { slot = slot, link = link,
                key = slot .. ":" .. itemObservationKey(link), source = lootSlotSource(slot) }
        end
    end
    if not run.reenterPending then return recordLootWindow(run, entries) end
    if #entries == 0 then return end
    local queue = reentryQueue(run)
    if not queue.current then
        local batch = {}
        queue.current = batch
        enqueueReentry(queue, function(destination)
            lootWindowOpen = false
            recordLootWindow(destination, batch)
        end)
    end
    local batch = queue.current
    batch.byKey = batch.byKey or {}
    local guid, zone, conflictingZones
    for _, entry in ipairs(entries) do
        local previous = batch.byKey[entry.key]
        if previous then
            if previous.source == nil or entry.source == false then previous.source = entry.source end
        else
            batch.byKey[entry.key] = entry
            batch[#batch + 1] = entry
        end
        local candidate, kind = guidInstanceID(entry.source, run.instanceID)
        if kind == "zone" then
            if zone and candidate ~= zone then conflictingZones = true end
            guid, zone = entry.source, candidate
        end
    end
    if guid and not conflictingZones then T:ObserveInstanceGUID(guid) end
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

local function noteChatDrop(link, winner, guid, source)
    local run = activeRun()
    if not run then return end
    if competingDrop(run, LJ:ItemID(link), now(), true) then return end
    local classFile
    if winner and LJ:IsMe(winner) then
        classFile = playerClassFile()
    else
        classFile = classFileFromGUID(guid)
    end
    noteDrop(run, link, winner, nil, source or "chat", nil, nil, nil, classFile)
end

local function recordLootChat(text, guid, routed)
    local itemLink = firstItemLink(text)
    local eventID = LJ:ItemID(itemLink)
    local run = activeRun()
    local previous = not routed and inside and previousLootRun(run)
    if previous then
        local foundCurrent = false
        for _, drop in ipairs(run.drops or {}) do
            if drop.id == eventID then foundCurrent = true; break end
        end
        local foundPrevious = hasSeenItem(previous, itemLink)
        for _, drop in ipairs(previous.drops or {}) do
            if drop.id == eventID then foundPrevious = true; break end
        end
        if foundPrevious or (not foundCurrent and transitioningFromOtherRun(run)) then
            diag("exit-late-chat-skip", eventID, "previous-run")
            return
        end
    end
    if not inside then
        if not inExitGrace(run) then return end
        local id = eventID
        local matched = false
        for _, drop in ipairs(run.drops or {}) do
            if drop.id == id and now() - (drop.at or 0) <= EXIT_SETTLE_SECONDS + 5 then
                matched = true
                break
            end
        end
        if not matched then
            diag("exit-late-chat-skip", id)
            return
        end
        diag("exit-late-chat", id)
    end
    local p = Patterns()
    local args

    args = Match(p.youWon, text)
    if args then
        diag("chat", nil, "you-won")
        recordChatItems(args[1])
        noteChatDrop(firstItemLink(args[1]), LJ:PlayerName(), nil, "chat-win")
        T:ResolveNeedByLink(firstItemLink(args[1]), "won", "chat-won")
        return
    end

    args = Match(p.won, text)
    if args then
        diag("chat", nil, "won")
        recordChatItems(args[2])
        noteChatDrop(firstItemLink(args[2]), args[1], guid, "chat-win")
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
        return
    end

    args = Match(p.lootOther, text)
    if args then
        diag("chat", nil, "loot-other")
        recordChatItems(args[2])
        noteChatDrop(firstItemLink(args[2]), args[1], guid)
        return
    end
    diag("chat-unmatched", nil, "len=" .. tostring(#text)
        .. " item=" .. tostring(firstItemLink(text) ~= nil)
        .. " num=" .. tostring(text:find("%d") ~= nil))
end

function T:OnLootChat(text, _who, guid)
    text, guid = LJ.Plain(text), LJ.Plain(guid)
    if type(text) ~= "string" then return end
    local run = activeRun()
    local queue = firstItemLink(text) and reentryQueue(run)
    if queue then
        enqueueReentry(queue, function() recordLootChat(text, guid, true) end)
        return
    end
    recordLootChat(text, guid)
end

function T:OnSystem(text)
    text = LJ.Plain(text)
    if type(text) ~= "string" then return end
    local p = Patterns()
    local args = Match(p.reset, text)
    if not args then return end
    local resetName = lower(args[1])
    local run = activeRun()
    if not run then
        local recent = recentlyLeftRun()
        if recent and resetName and resetName == lower(recent.name) then
            recent.resetAfterExit = true
            diag("system-reset", recent.id, "after-exit")
            LJ:Changed()
        end
        return
    end
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
        worldEntries = worldEntries + 1
        local isInitialLogin, isReloadingUI = ...
        local isStartupEntry = (worldEntries == 1) or (isInitialLogin == true) or (isInitialLogin == nil and isReloadingUI == nil)
        local run = activeRun()
        local outsideAt = run and tonumber(run.outsideAt)
        local staleOutside = outsideAt and now() - outsideAt >= LOGIN_STALE_OUTSIDE_SECONDS
        if not getDungeon() and isStartupEntry and staleOutside then
            T:CloseActive("login-outside")
        end
        after(1, function()
            T:CheckZone()
            T:RefreshPendingItemData()
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
            run.reenterPending = run.zoneID ~= nil
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
        if pendingReentry then pendingReentry.current = nil end
        lootWindowOpen = false
        seenLootSlots, lootWindowClaims = {}, {}
        diag("loot-close")
    elseif event == "CHAT_MSG_LOOT" then
        T:OnLootChat(select(1, ...), select(2, ...), select(12, ...))
    elseif event == "CHAT_MSG_SYSTEM" then
        T:OnSystem((...))
    elseif event == "GET_ITEM_INFO_RECEIVED" or event == "ITEM_DATA_LOAD_RESULT" then
        local id, success = ...
        id = tonumber(LJ.Plain(id))
        success = LJ.Plain(success)
        local loaded = success == true or success == 1
        if id and LJ.ItemLoadResult and (loaded or success == false or success == 0) then
            LJ:ItemLoadResult(id, loaded)
        end
        if id and loaded then
            T:ReclassifyPending(id)
            LJ:Changed()
            after(1, function() T:ReclassifyPending(id) end)
        else
            diag("item-data-failed", id, event)
        end
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
        "CHAT_MSG_LOOT", "CHAT_MSG_SYSTEM", "GET_ITEM_INFO_RECEIVED", "ITEM_DATA_LOAD_RESULT",
        "BAG_UPDATE_DELAYED",
    }
    for i = 1, #events do pcall(eventFrame.RegisterEvent, eventFrame, events[i]) end
    eventFrame:SetScript("OnEvent", function(_, event, ...)
        pcall(onEvent, event, ...)
    end)
end

local function hookRolls()
    if T.hooked then return end
    if type(RollOnLoot) ~= "function" or type(hooksecurefunc) ~= "function" then return end
    local ok = pcall(hooksecurefunc, "RollOnLoot", function(rollID, rollType)
        rollType = tonumber(rollType)
        if rollType == 1 then
            pcall(T.OnNeedRoll, T, rollID)
        elseif rollType == 2 then
            pcall(T.MarkGreed, T, rollID)
        end
    end)
    T.hooked = ok or nil
end

function T:Start()
    if started then return end
    started = true
    T.startedAt = now()
    registerEvents()
    hookRolls()
    diag("tracker-start", nil, "version=" .. tostring(LJ:AddOnVersion()))
    if C_Timer and C_Timer.NewTicker then
        C_Timer.NewTicker(60, function()
            pruneRollLinks()
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
    pendingResumeChoice = nil
    exitGraceRun, exitGraceUntil = nil, nil
    lastExitedRun, lastExitUntil = nil, nil
    lastSwitchedRun = nil
    transitionGuardRun = nil
    pendingReentry = nil
    firstCheck = false
    resetRollLinks()
    lootWindowOpen = false
    seenLootSlots, lootWindowClaims = {}, {}
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
    if run.reenterPending then
        copy.state = "pending"
    elseif run.zoneID then
        copy.state = "confirmed"
        copy.zoneID = run.zoneID
    else
        copy.state = "unconfirmed"
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
            closedReason = run.closedReason,
            partial = run.partial == true,
            lootSeen = run.lootSeen == true,
            bosses = #(run.bosses or {}),
            bossEvents = run.bosses,
            itemsSeen = tonumber(run.itemsSeen) or 0,
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
    local run = activeRun()
    LJ:Print(LJ.L("CHAT_DEBUG_HEADER"))
    LJ:Print(LJ.L("CHAT_DEBUG_INSIDE", tostring(inside), run and run.name or "–"))
    LJ:Print(LJ.L("CHAT_DEBUG_RUNS", #(T:GetRuns())))
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
