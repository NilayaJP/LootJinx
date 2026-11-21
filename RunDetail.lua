-- LootJinx – Run-Details
local ADDON, ns = ...
local LJ = ns or _G.LootJinx
if not LJ then return end

local M = {}
LJ.RunDetail = M

local W = LJ.Widgets
local C = LJ.COLORS
local skin = W:Skin("classic")
local UNKNOWN_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"

local WIDTH, HEIGHT = 560, 560
local ROW_HEIGHT = 30
local ROWS_PER_PAGE = 12
local CONTENT_HEIGHT = ROW_HEIGHT * ROWS_PER_PAGE

local frame, content, summary, subtitle, title, eyebrow, pageText, prevButton, nextButton
local summaryPanel, hint, closeButton, finishButton
local rows = {}
local pages = {}
local currentRun
local collapsedGroups = {}
local page = 1
local suspendedSpecialNames
local restoreToken = 0
local deferredRestoreFrame

function M:SuspendParentEscape()
    if type(UISpecialFrames) ~= "table" then return end
    local dashboard = LJ.UI and LJ.UI.frame
    local history = LJ.History and LJ.History.frame
    local historyShown = history and history.IsShown and history:IsShown()
    local windows = { dashboard = dashboard, history = history }
    local names = suspendedSpecialNames or {}
    for _, window in pairs(windows) do
        local name = window and window.IsShown and window:IsShown()
            and window.GetName and window:GetName()
        if name then
            local removed = false
            for i = #UISpecialFrames, 1, -1 do
                if UISpecialFrames[i] == name then
                    table.remove(UISpecialFrames, i)
                    removed = true
                end
            end
            if removed or (window == dashboard and not historyShown) then
                names[name] = true
            end
        end
    end
    suspendedSpecialNames = names
    restoreToken = restoreToken + 1
end

local function restoreDashboardEscape()
    local names = suspendedSpecialNames
    if not names then return end
    restoreToken = restoreToken + 1
    local token = restoreToken
    local function restore()
        if token ~= restoreToken or type(UISpecialFrames) ~= "table" then return end
        suspendedSpecialNames = nil
        local history = LJ.History
        for name in pairs(names) do
            local found = false
            for i = 1, #UISpecialFrames do
                if UISpecialFrames[i] == name then found = true break end
            end
            if not found and not (history and history.suspendedName == name)
                and not (LJ.Options and LJ.Options:KeepDashboardEscapeSuspended(name)) then
                table.insert(UISpecialFrames, name)
            end
        end
    end
    -- CloseSpecialWindows iterates this table; restore after its ESC pass ends.
    if C_Timer and C_Timer.After then
        C_Timer.After(0, restore)
    elseif CreateFrame then
        deferredRestoreFrame = deferredRestoreFrame or CreateFrame("Frame", nil, UIParent)
        deferredRestoreFrame:SetScript("OnUpdate", function(self)
            self:SetScript("OnUpdate", nil)
            self:Hide()
            restore()
        end)
        deferredRestoreFrame:Show()
    end
end

local function hex(c)
    c = c or skin.text
    return string.format("|cff%02x%02x%02x",
        math.floor((c[1] or 1) * 255),
        math.floor((c[2] or 1) * 255),
        math.floor((c[3] or 1) * 255))
end

local function colored(c, text)
    return hex(c) .. tostring(text) .. "|r"
end

local function qualityColor(quality)
    local c = _G.ITEM_QUALITY_COLORS and _G.ITEM_QUALITY_COLORS[tonumber(quality) or 1]
    if c then return { c.r or 1, c.g or 1, c.b or 1 } end
    return skin.text
end

local function classColor(classFile)
    local c = classFile and _G.RAID_CLASS_COLORS and _G.RAID_CLASS_COLORS[classFile]
    if c then return { c.r or 1, c.g or 1, c.b or 1 } end
    return skin.text
end

local function formatDate(run)
    local t = tonumber(run and run.started) or 0
    if t <= 0 then return LJ.L("NO_DATA") end
    return LJ:FormatTime(t, "DATE_TIME")
end

local function sortedNeeds(run)
    local list = {}
    for i = 1, #(run.needs or {}) do
        local n = run.needs[i]
        if type(n) == "table" then list[#list + 1] = { n = n, index = i } end
    end
    table.sort(list, function(a, b)
        local ta, tb = tonumber(a.n.at) or 0, tonumber(b.n.at) or 0
        if ta == tb then return a.index < b.index end
        return ta < tb
    end)
    local out = {}
    for i = 1, #list do out[i] = list[i].n end
    return out
end

local function legacyRollNear(roll, item)
    local at = tonumber(item.at) or 0
    local rollAt = tonumber(roll.at) or 0
    local window = item.lootHistoryKey and 30 or 300
    local distance = math.abs(rollAt - at)
    return at == 0 or distance <= window, at > 0 and rollAt > 0 and distance or nil
end

local function canPairNeed(need, drop)
    return need.id == drop.id and LJ.CompatibleItemVariant(need.link, drop.link)
        and (not need.rollID or not drop.rollID or need.rollID == drop.rollID)
        and (not need.lootHistoryKey or not drop.lootHistoryKey or need.lootHistoryKey == drop.lootHistoryKey)
end

local function legacyNeedDistance(need, drop)
    if drop.winner and need.result
        and need.result ~= (LJ:IsMe(drop.winner) and "won" or "lost") then return nil end
    local near, distance = legacyRollNear(need, drop)
    if near then return distance end
end

local function findNeed(run, drop, used, exactOnly)
    if drop.rollKind and drop.rollKind ~= "need" then return nil end
    local exact, found, nearest, tied
    for i = 1, #(run.needs or {}) do
        local n = run.needs[i]
        if not used[n] and canPairNeed(n, drop) then
            if (drop.rollID and n.rollID == drop.rollID)
                or (drop.lootHistoryKey and n.lootHistoryKey == drop.lootHistoryKey) then
                if exact then return false end
                exact = n
            elseif not exactOnly then
                local distance = legacyNeedDistance(n, drop)
                if distance then
                    if not nearest or distance < nearest then
                        found, nearest, tied = n, distance, false
                    elseif distance == nearest then
                        tied = true
                    end
                end
            end
        end
    end
    if exact then return exact end
    if not tied then return found end
end

local function recordNearest(matches, from, to, distance)
    local closest = matches[from]
    if not closest or distance < closest.distance then
        matches[from] = { candidate = to, distance = distance }
    elseif distance == closest.distance then
        closest.candidate = nil
    end
end

local function matchDetailNeeds(run, drops)
    local byDrop, exactCounts, used = {}, {}, {}
    for _, drop in ipairs(drops) do
        local need = findNeed(run, drop, used, true)
        byDrop[drop] = need
        if need then exactCounts[need] = (exactCounts[need] or 0) + 1 end
    end
    for need in pairs(exactCounts) do used[need] = true end
    local nearestNeeds, nearestDrops = {}, {}
    for _, drop in ipairs(drops) do
        local need = byDrop[drop]
        if need == nil then
            if not drop.rollKind or drop.rollKind == "need" then
                for _, candidate in ipairs(run.needs or {}) do
                    if not used[candidate] and canPairNeed(candidate, drop) then
                        local distance = legacyNeedDistance(candidate, drop)
                        if distance then
                            recordNearest(nearestNeeds, drop, candidate, distance)
                            recordNearest(nearestDrops, candidate, drop, distance)
                        end
                    end
                end
            end
        elseif need == false or exactCounts[need] > 1 then
            byDrop[drop] = nil
        end
    end
    for drop, closest in pairs(nearestNeeds) do
        local need = closest.candidate
        if need and nearestDrops[need].candidate == drop then byDrop[drop] = need end
    end
    return byDrop
end

local function observedNeedWinner(need, drop)
    return need and drop and drop.rollKind == "need" and drop.winner and LJ:IsMe(drop.winner)
        and ((need.rollID and need.rollID == drop.rollID)
            or (need.lootHistoryKey and need.lootHistoryKey == drop.lootHistoryKey))
end

local function needStatusText(need, drop)
    local result = need and need.result
    local observedSelfWinner = observedNeedWinner(need, drop)
    if not result and observedSelfWinner then result = "won" end
    local status, color
    if result == "won" then
        status, color = LJ.L("DETAIL_NEED_WON"), C.green
    elseif result == "lost" then
        status, color = LJ.L("DETAIL_NEED_LOST"), C.red
    else
        status, color = LJ.L("DETAIL_NEED_OPEN"), skin.muted
    end
    local value = need and tonumber(need.roll) or nil
    if not value and observedSelfWinner then
        value = tonumber(drop.roll)
    end
    local text
    if value then
        text = LJ.L("DETAIL_NEED_LINE", value, status)
    else
        text = LJ.L("DETAIL_NEED_LINE_NO_ROLL", status)
    end
    if LJ.Evidence then
        local level = LJ.Evidence:Classify(need, observedSelfWinner)
        text = text .. " · " .. LJ.L("EVIDENCE_" .. string.upper(level))
    end
    return text, color
end

local function itemText(link, id)
    local item = link or tonumber(id)
    if item then LJ:LoadItem(link, id) end
    local info = item and LJ:ItemInfo(item)
    local instant = item and LJ:ItemInfoInstant(item)
    local icon = (info and info.icon) or (instant and instant.icon) or UNKNOWN_ICON
    if info and type(info.name) == "string" and info.name ~= "" then
        local color = qualityColor(info.quality)
        return colored(color, info.name), icon, color, info.link
    end
    if type(link) == "string" and link ~= "" then
        return link, icon, qualityColor(info and info.quality)
    end
    return LJ.L("DETAIL_ITEM_UNKNOWN", tonumber(id) or 0), icon, skin.muted
end

local function rollMatch(roll, item, peers)
    if roll.id ~= item.id or not tonumber(roll.value) then return nil end
    if roll.lootHistoryKey and item.lootHistoryKey and roll.lootHistoryKey ~= item.lootHistoryKey then
        return nil
    end
    if roll.rollID and item.rollID and roll.rollID ~= item.rollID then return nil end
    if (roll.lootHistoryKey and roll.lootHistoryKey == item.lootHistoryKey)
        or (roll.rollID and roll.rollID == item.rollID) then
        return "exact"
    end
    if roll.lootHistoryKey or roll.rollID or not legacyRollNear(roll, item) then return nil end
    for _, other in ipairs(peers or {}) do
        if other ~= item and other.id == item.id and legacyRollNear(roll, other) then return nil end
    end
    return "legacy"
end

local function dropRollText(run, drop)
    local value = tonumber(drop.roll)
    local kind = drop.rollKind
    if not value and drop.winner then
        local matches = {}
        for _, roll in ipairs(run.rolls or {}) do
            if LJ:SamePlayerName(roll.name, drop.winner) then
                local match = rollMatch(roll, drop, run.drops)
                if match then
                    local previous = matches[match]
                    if previous == nil then
                        matches[match] = roll
                    elseif previous and (tonumber(previous.value) ~= tonumber(roll.value)
                        or previous.kind ~= roll.kind) then
                        matches[match] = false
                    end
                end
            end
        end
        local roll = matches.exact
        if roll == nil then roll = matches.legacy end
        if roll then value, kind = tonumber(roll.value), roll.kind end
    end
    if not value then return nil end
    if kind == "transmog" then return LJ.L("DETAIL_ROLL_TRANSMOG", value) end
    if kind == "greed" then return LJ.L("DETAIL_ROLL_GREED", value) end
    if kind == "need" then return LJ.L("DETAIL_ROLL_NEED", value) end
    return LJ.L("DETAIL_ROLL_UNKNOWN", value)
end

local function closestBoss(bosses, at, matches)
    local count, first, lastDistance, best, tied = 0
    at = tonumber(at) or 0
    for i, boss in ipairs(bosses) do
        if matches(boss) then
            count, first = count + 1, i
            local bossAt = tonumber(boss.at) or 0
            if at > 0 and bossAt > 0 then
                local distance = math.abs(at - bossAt)
                if not lastDistance or distance < lastDistance then
                    best, lastDistance, tied = i, distance, false
                elseif distance == lastDistance then
                    tied = true
                end
            end
        end
    end
    if count == 1 then return first, true end
    return not tied and best or nil, count > 0, first
end

local function bossIndexFor(run, drop, bosses, catalogKind, catalogBoss, corpse, aggregate)
    local id = not corpse and tonumber(drop.bossID)
    if id and id > 0 then
        local index, found, any = closestBoss(bosses, drop.at, function(boss) return tonumber(boss.id) == id end)
        if found then return index or (aggregate and any or nil), true end
    end
    local name = not corpse and type(drop.bossName) == "string" and drop.bossName:gsub("’", "'"):lower() or nil
    if name then
        local index, found = closestBoss(bosses, drop.at, function(boss)
            local observedID = tonumber(boss.id)
            return (not id or id <= 0 or not observedID or observedID <= 0 or id == observedID)
                and type(boss.name) == "string" and boss.name:gsub("’", "'"):lower() == name
        end)
        if found then return index, true end
    end
    if not corpse and not LJ.DungeonLoot:CanInferBoss(drop) then return nil, true end
    if catalogKind == "boss" and type(catalogBoss) == "string" then
        return closestBoss(bosses, drop.at, function(boss)
            return LJ.DungeonLoot:MatchesBoss(run, boss.name, catalogBoss)
        end)
    end
end

local function bossLootFor(run, aggregate)
    local bosses, resolved, inferred, byDrop = {}, {}, {}, {}
    local observed = run.bosses or {}
    for index, boss in ipairs(observed) do bosses[index] = boss end
    for _, drop in ipairs(run.drops or {}) do
        local kind, name, corpse = LJ.DungeonLoot:DropSource(run, drop)
        local index, found = bossIndexFor(run, drop, observed, kind, name, corpse, aggregate)
        -- Only a unique catalog source or a known corpse can supply a group
        -- without a saved boss event. Keep unresolved encounter IDs visible.
        if not found and kind == "boss" then
            index = inferred[name]
            if not index then
                index = #bosses + 1
                inferred[name] = index
                bosses[index] = { name = name, lootEvidence = true, at = drop.at }
            elseif (tonumber(drop.at) or 0) < (tonumber(bosses[index].at) or 0) then
                bosses[index].at = drop.at
            end
        end
        if found and not index and kind == "boss" and (corpse or LJ.DungeonLoot:CanInferBoss(drop)) then
            kind = "ambiguous"
        end
        resolved[drop] = kind
        byDrop[drop] = index
    end
    return bosses, byDrop, resolved
end

local NEED_MATCH_FIELDS = { "rollID", "lootHistoryKey" }

local function itemCounts(entries)
    local totals, exact = {}, {}
    for _, entry in ipairs(entries) do
        local id = tonumber(entry.id)
        if id then
            totals[id] = (totals[id] or 0) + 1
            for _, field in ipairs(NEED_MATCH_FIELDS) do
                if entry[field] then
                    local key = id .. ":" .. field .. ":" .. entry[field]
                    exact[key] = (exact[key] or 0) + 1
                end
            end
        end
    end
    return totals, exact
end

function M:BossStatistics(runs)
    local rows, groups, knownIDs = {}, {}, {}
    for _, run in ipairs(runs) do
        for _, boss in ipairs(run.bosses or {}) do
            local id, name = tonumber(boss.id), type(boss.name) == "string" and boss.name:lower()
            if id and id > 0 and name then
                local known = knownIDs[name]
                if known == nil then knownIDs[name] = id
                elseif known ~= id then knownIDs[name] = false end
            end
        end
    end
    for _, run in ipairs(runs) do
        local bosses, byDrop = bossLootFor(run, true)
        local byIndex, seen, used = {}, {}, {}
        for index, boss in ipairs(bosses) do
            local name = boss.name or LJ.L("DETAIL_UNKNOWN_BOSS")
            local id = tonumber(boss.id)
            if not id or id <= 0 then id = knownIDs[name:lower()] end
            local key = id and ("id:" .. id) or ("name:" .. name:lower())
            local data = groups[key]
            if not data then
                data = { key = key, name = name, visits = 0, drops = 0, won = 0, lost = 0, pending = 0,
                    items = {}, byItem = {} }
                rows[#rows + 1], groups[key] = data, data
            end
            if not seen[data] then data.visits, seen[data] = data.visits + 1, true end
            byIndex[index] = data
        end
        if #bosses > 0 then
            local drops, needs = run.drops or {}, run.needs or {}
            local dropCount, dropExact = itemCounts(drops)
            local needCount, needExact = itemCounts(needs)
            for _, drop in ipairs(drops) do
                local id = tonumber(drop.id)
                if id then
                    local index = byDrop[drop]
                    local boss = byIndex[index]
                    if boss then
                        local item = boss.byItem[id]
                        if not item then
                            item = { id = id, count = 0, won = 0, lost = 0, pending = 0 }
                            boss.byItem[id], boss.items[#boss.items + 1] = item, item
                        end
                        item.link = item.link or drop.link
                        boss.drops, item.count = boss.drops + 1, item.count + 1
                        local need = findNeed(run, drop, used)
                        if need then
                            local dropAt, needAt = tonumber(drop.at) or 0, tonumber(need.at) or 0
                            local unique = dropCount[id] == 1 and needCount[id] == 1
                                and dropAt > 0 and needAt > 0 and legacyRollNear(need, drop)
                            for _, field in ipairs(NEED_MATCH_FIELDS) do
                                if drop[field] and drop[field] == need[field] then
                                    local key = id .. ":" .. field .. ":" .. drop[field]
                                    unique = unique or (dropExact[key] == 1 and needExact[key] == 1)
                                end
                            end
                            if unique then
                                local outcome = need.result == "won" and "won" or need.result == "lost" and "lost" or "pending"
                                boss[outcome], item[outcome], used[need] = boss[outcome] + 1, item[outcome] + 1, true
                            end
                        end
                    end
                end
            end
        end
    end
    for _, boss in ipairs(rows) do
        table.sort(boss.items, function(a, b)
            if a.count ~= b.count then return a.count > b.count end
            return a.id < b.id
        end)
    end
    table.sort(rows, function(a, b)
        if a.visits ~= b.visits then return a.visits > b.visits end
        return a.name < b.name
    end)
    return rows
end

local function otherLootReason(run, drop, catalogKind)
    if (tonumber(drop.bossID) or 0) > 0 or drop.bossName or drop.source == "encounter" then
        return "DETAIL_OTHER_ENCOUNTER"
    end
    if catalogKind == "unknown-npc" then return "DETAIL_OTHER_NPC" end
    if catalogKind == "ambiguous" then return "DETAIL_OTHER_AMBIGUOUS" end
    if catalogKind == "boss" then return "DETAIL_OTHER_BOSS_NOT_SEEN" end
    local candidates = LJ.DungeonLoot and LJ.DungeonLoot:Candidates(run)
    if not candidates or #candidates == 0 then return "DETAIL_OTHER_NO_DUNGEON" end
    local hasCatalog = false
    for _, dungeon in ipairs(candidates) do
        if LJ.DungeonLootData and LJ.DungeonLootData[dungeon] then
            hasCatalog = true
            break
        end
    end
    return hasCatalog and "DETAIL_OTHER_UNLISTED" or "DETAIL_OTHER_NO_DUNGEON"
end

local function bossLootQuality(drop)
    -- Fast path: drops whose link already encodes a sub-rare quality can be
    -- filtered out without any item-data lookup.
    local linkQuality = LJ:ItemQuality(drop.link)
    if linkQuality and linkQuality < 2 then return nil end
    LJ:LoadItem(drop.link, drop.id)
    local info = LJ:ItemInfo(drop.link or drop.id)
    local instant = LJ:ItemInfoInstant(drop.link or drop.id) or LJ:ItemInfoInstant(drop.id)
    local classID = (instant and instant.classID) or info.classID
    if classID ~= 2 and classID ~= 4 then return nil end
    local equipLoc = instant and instant.equipLoc or info.equipLoc
    if type(equipLoc) ~= "string" or equipLoc == ""
        or equipLoc == "INVTYPE_NON_EQUIP" then return nil end
    if info.quality ~= nil then return tonumber(info.quality) end
    local getQuality = C_Item and C_Item.GetItemQualityByID
    if type(getQuality) == "function" then
        local ok, quality = pcall(getQuality, drop.id)
        if ok and tonumber(LJ.Plain(quality)) then return tonumber(LJ.Plain(quality)) end
    end
    return linkQuality
end

local function completionDungeonName(dungeon)
    local names = (LJ.DungeonNames or {})[dungeon]
    if names and names[LJ.lang] then return names[LJ.lang] end
    if LJ.lang == "de" then
        return (LJ.DungeonCompletionNames or {})[dungeon] or dungeon
    end
    return dungeon
end

local function addCompletionLines(lines, run, progress)
    lines[#lines + 1] = { kind = "section", name = LJ.L("DETAIL_COMPLETION_SECTION") }
    if run.legacy == true then
        lines[#lines + 1] = { kind = "note", text = LJ.L("DETAIL_COMPLETION_LEGACY"), muted = true }
        return
    end
    if not progress or progress.state == "unavailable" then
        lines[#lines + 1] = { kind = "note", text = LJ.L("DETAIL_COMPLETION_UNAVAILABLE"), muted = true }
        return
    end
    if progress.state == "unresolved" then
        lines[#lines + 1] = { kind = "note", text = LJ.L("DETAIL_COMPLETION_UNRESOLVED"), accent = true }
        for _, candidate in ipairs(progress.candidates or {}) do
            lines[#lines + 1] = { kind = "note", text = LJ.L("DETAIL_COMPLETION_CANDIDATE",
                completionDungeonName(candidate.dungeon), candidate.observed, candidate.required), muted = true }
        end
        return
    end
    lines[#lines + 1] = { kind = "note", text = LJ.L("DETAIL_COMPLETION_WING",
        completionDungeonName(progress.dungeon)), muted = true }
    lines[#lines + 1] = { kind = "note", text = LJ.L("DETAIL_COMPLETION_COUNT",
        progress.observed, progress.required), muted = true }
    if progress.state == "complete" then
        lines[#lines + 1] = { kind = "note", text = LJ.L("DETAIL_COMPLETION_COMPLETE"), muted = true }
    else
        local names = {}
        if LJ.lang == "de" then
            for _, boss in ipairs((LJ.DungeonCompletionData or {})[progress.dungeon] or {}) do
                names[boss.name] = boss.deName or boss.name
            end
        end
        for _, boss in ipairs(progress.missing or {}) do
            lines[#lines + 1] = { kind = "note", text = LJ.L("DETAIL_COMPLETION_NO_EVENT",
                names[boss] or boss), muted = true }
        end
        lines[#lines + 1] = { kind = "note", text = LJ.L("DETAIL_COMPLETION_UNCERTAIN"), accent = true }
    end
end

local function buildTimelineLines(run)
    local lines = { { kind = "section", name = LJ.L("DETAIL_TIMELINE_TITLE") } }
    local events = {}
    local function add(at, text)
        at = tonumber(at)
        if at and at > 0 then events[#events + 1] = { at = at, text = text, order = #events + 1 } end
    end
    add(run.started, LJ.L("DETAIL_TIMELINE_START"))
    if type(run.timeline) == "table" then
        for _, event in ipairs(run.timeline) do
            if event.kind == "exit" or event.kind == "return" then
                add(event.at, LJ.L(event.kind == "exit" and "DETAIL_TIMELINE_EXIT"
                    or "DETAIL_TIMELINE_RETURN"))
            end
        end
        for _, boss in ipairs(run.bosses or {}) do
            if tonumber(boss.at) and tonumber(boss.at) > (tonumber(run.started) or 0) then
                add(boss.at, LJ.L("DETAIL_TIMELINE_BOSS",
                    W:Truncate(boss.name or LJ.L("DETAIL_UNKNOWN_BOSS"), 36)))
            end
        end
        for _, need in ipairs(run.needs or {}) do
            if (need.result == "won" or need.result == "lost") and tonumber(need.resolvedAt)
                and tonumber(need.resolvedAt) > (tonumber(run.started) or 0) then
                add(need.resolvedAt, LJ.L(need.result == "won"
                    and "DETAIL_TIMELINE_NEED_WON" or "DETAIL_TIMELINE_NEED_LOST"))
            end
        end
    end
    if run.closed then add(run.ended, LJ.L("DETAIL_TIMELINE_END")) end
    table.sort(events, function(a, b)
        return a.at == b.at and a.order < b.order or a.at < b.at
    end)
    local first = 1
    if #events > 18 then first = #events - 17 end
    if first > 1 or (tonumber(run.timelineOmitted) or 0) > 0 then
        lines[#lines + 1] = { kind = "note", text = LJ.L("DETAIL_TIMELINE_OMITTED",
            first - 1 + (tonumber(run.timelineOmitted) or 0)), muted = true }
    end
    for i = first, #events do
        local event = events[i]
        local stamp = LJ:FormatTime(event.at, "DATE_TIME_SHORT")
        lines[#lines + 1] = { kind = "note", text = stamp .. " · " .. event.text, muted = true }
    end
    if type(run.timeline) ~= "table" then
        lines[#lines + 1] = { kind = "note", text = LJ.L("DETAIL_TIMELINE_OLD"), accent = true }
    end
    return lines
end

local function buildLines(run, progress)
    local lines = {}
    -- Need-Ergebnisse direkt oben zeigen; einzelne Drops verlinken ihre Need
    -- weiterhin zusaetzlich in der Boss-Liste.
    local needs = sortedNeeds(run)
    if #needs > 0 then
        lines[#lines + 1] = { kind = "section", name = LJ.L("DETAIL_NEED_SECTION") }
        for i = 1, #needs do
            lines[#lines + 1] = { kind = "need", need = needs[i] }
        end
    end
    local bosses, bossByDrop, sourceByDrop = bossLootFor(run)
    local byBoss = {}
    local trash = {}
    local other = {}
    local otherReasons = {}
    local visibleDrops = {}
    for _, drop in ipairs(run.drops or {}) do
        if (bossLootQuality(drop) or 0) >= 2 then
            visibleDrops[#visibleDrops + 1] = drop
        end
    end
    local needByDrop = matchDetailNeeds(run, visibleDrops)
    local dropCount = #visibleDrops
    for _, drop in ipairs(visibleDrops) do
        local catalogKind = sourceByDrop[drop]
        local index = bossByDrop[drop]
        if index then
            byBoss[index] = byBoss[index] or {}
            byBoss[index][#byBoss[index] + 1] = drop
        elseif catalogKind == "trash" then
            trash[#trash + 1] = drop
        else
            other[#other + 1] = drop
            otherReasons[drop] = otherLootReason(run, drop, catalogKind)
        end
    end

    local order = {}
    for i = 1, #bosses do order[i] = i end
    table.sort(order, function(a, b)
        local first, second = tonumber(bosses[a].at) or 0, tonumber(bosses[b].at) or 0
        if first ~= second then return first < second end
        return a < b
    end)
    for _, i in ipairs(order) do
        local boss = bosses[i]
        local items = byBoss[i] or {}
        local group = boss.lootEvidence and ("loot:" .. boss.name) or boss
        lines[#lines + 1] = {
            kind = "boss",
            name = boss.name or LJ.L("DETAIL_UNKNOWN_BOSS"),
            count = #items, group = group, collapsed = collapsedGroups[group] == true,
            lootEvidence = boss.lootEvidence,
        }
        if not collapsedGroups[group] then
            if #items == 0 then
                lines[#lines + 1] = { kind = "note", text = LJ.L("DETAIL_BOSS_EMPTY"), muted = true }
            else
                for j = 1, #items do
                    lines[#lines + 1] = { kind = "item", drop = items[j], need = needByDrop[items[j]] }
                end
            end
        end
    end

    if #trash > 0 then
        lines[#lines + 1] = {
            kind = "boss", name = LJ.L("DETAIL_TRASH"), count = #trash, other = true,
            group = "trash", collapsed = collapsedGroups.trash == true,
        }
        if not collapsedGroups.trash then
            for i = 1, #trash do
                lines[#lines + 1] = { kind = "item", drop = trash[i], need = needByDrop[trash[i]] }
            end
        end
    end

    if #other > 0 then
        lines[#lines + 1] = {
            kind = "boss", name = LJ.L("DETAIL_OTHER"), count = #other, other = true,
            group = "other", collapsed = collapsedGroups.other == true,
        }
        if not collapsedGroups.other then
            for i = 1, #other do
                lines[#lines + 1] = { kind = "item", drop = other[i], need = needByDrop[other[i]],
                    attributionReason = otherReasons[other[i]] }
            end
        end
    end

    if #bosses == 0 then
        if dropCount == 0 then
            if run.legacy == true then
                lines[#lines + 1] = { kind = "note", text = LJ.L("DETAIL_LEGACY"), accent = true }
            else
                lines[#lines + 1] = { kind = "note", text = LJ.L("DETAIL_EMPTY"), muted = true }
            end
        end
        if #needs == 0 then
            lines[#lines + 1] = { kind = "note", text = LJ.L("DETAIL_NO_NEEDS"), muted = true }
        end
    end

    addCompletionLines(lines, run, progress)
    return lines, dropCount, #bosses
end

local function paginate(lines)
    local out = {}
    local current = {}
    local function flush()
        if #current > 0 then
            out[#out + 1] = current
            current = {}
        end
    end
    for i = 1, #lines do
        local line = lines[i]
        if line.group and not line.collapsed and #current == ROWS_PER_PAGE - 1 then flush() end
        current[#current + 1] = line
        if #current >= ROWS_PER_PAGE then flush() end
    end
    flush()
    if #out == 0 then
        out[1] = { { kind = "note", text = LJ.L("DETAIL_EMPTY"), muted = true } }
    end
    return out
end

local function itemRolls(run, item, peers)
    local out = {}
    if not run or not item or not item.id then return out end
    for _, roll in ipairs(run.rolls or {}) do
        if rollMatch(roll, item, peers) then out[#out + 1] = roll end
    end
    table.sort(out, function(a, b)
        local av, bv = tonumber(a.value) or 0, tonumber(b.value) or 0
        if av == bv then return tostring(a.name) < tostring(b.name) end
        return av > bv
    end)
    return out
end

local function rowTooltip(row)
    local line = row.line
    local link = row.link
    if not line or not GameTooltip then return end
    local need = line.need
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    local shown = false
    if link and GameTooltip.SetHyperlink then
        shown = pcall(GameTooltip.SetHyperlink, GameTooltip, link)
    end
    if not shown then GameTooltip:AddLine(link or row.name:GetText(), 0.92, 0.93, 0.96) end
    if line.kind == "item" and line.drop and LJ.Evidence then
        local level, reason = LJ.Evidence:ClassifyDrop(line.drop)
        GameTooltip:AddLine(LJ.L("EVIDENCE_DROP_TOOLTIP", LJ.L("EVIDENCE_" .. string.upper(level))),
            0.92, 0.82, 0.61)
        GameTooltip:AddLine(LJ.L(reason), 0.76, 0.78, 0.83, true)
    end
    if line.attributionReason then
        GameTooltip:AddLine(LJ.L("DETAIL_OTHER_REASON"), 0.92, 0.82, 0.61)
        GameTooltip:AddLine(LJ.L(line.attributionReason), 0.76, 0.78, 0.83, true)
    end
    if need and LJ.Evidence then
        local drop = line.drop
        local level, reason = LJ.Evidence:Classify(need, observedNeedWinner(need, drop))
        GameTooltip:AddLine(LJ.L("EVIDENCE_TOOLTIP", LJ.L("EVIDENCE_" .. string.upper(level))),
            0.92, 0.82, 0.61)
        GameTooltip:AddLine(LJ.L(reason), 0.76, 0.78, 0.83, true)
    end
    local item = line.drop or line.need
    local peers = currentRun and (line.drop and currentRun.drops or currentRun.needs)
    local rolls = itemRolls(currentRun, item, peers)
    if #rolls > 0 then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(LJ.L("DETAIL_ROLLS_SECTION"), 0.92, 0.82, 0.61)
        for i = 1, #rolls do
            local roll = rolls[i]
            local kind = roll.kind == "transmog" and LJ.L("DETAIL_ROLL_KIND_TRANSMOG")
                or roll.kind == "greed" and LJ.L("DETAIL_ROLL_KIND_GREED")
                or roll.kind == "need" and LJ.L("DETAIL_ROLL_KIND_NEED")
                or LJ.L("DETAIL_ROLL_KIND_UNKNOWN")
            local name = roll.name
            if LJ:IsMe(name) then name = LJ.L("DETAIL_YOU") end
            local text = LJ.L("DETAIL_ROLL_LINE", kind, name, tonumber(roll.value))
            if roll.kind ~= "need" then
                GameTooltip:AddLine(text, 0.70, 0.75, 0.80)
            else
                GameTooltip:AddLine(text, 0.95, 0.82, 0.45)
            end
        end
    end
    GameTooltip:Show()
end

local function configureRow(row, line)
    row.line = line
    row.link = nil
    row.baseAlpha = 0
    row.bg:SetColorTexture(skin.surface[1], skin.surface[2], skin.surface[3], 0)
    row.bar:Hide()
    W:SetFoldIndicator(row)
    row.icon:Hide()
    row.recipient:SetText("")
    row.roll:SetText("")
    row.meta:SetText("")
    row.name:SetText("")

    if line.kind == "boss" or line.kind == "section" then
        row:Show()
        row.name:ClearAllPoints()
        row.name:SetPoint("LEFT", line.group and 23 or 10, 0)
        row.name:SetWidth(380)
        local color = line.kind == "section" and skin.progress or (line.other and skin.progress or skin.accent)
        if line.group then
            W:SetFoldIndicator(row, color, not line.collapsed)
        end
        row.name:SetText(colored(color, line.name))
        if line.count then
            row.recipient:ClearAllPoints()
            row.recipient:SetPoint("RIGHT", -8, 0)
            row.recipient:SetWidth(186)
            local caption = line.lootEvidence and "DETAIL_BOSS_ITEMS_EVIDENCE" or "DETAIL_BOSS_ITEMS"
            row.recipient:SetText(colored(skin.muted, LJ.L(caption, line.count)))
        end
        row.baseAlpha = line.kind == "section" and .65 or .88
        row.bg:SetColorTexture(skin.surface[1], skin.surface[2], skin.surface[3], row.baseAlpha)
        row.bar:SetColorTexture(color[1], color[2], color[3], 1)
        row.bar:Show()
        return
    end

    if line.kind == "note" then
        row:Show()
        row.name:ClearAllPoints()
        row.name:SetPoint("LEFT", 10, 0)
        row.name:SetWidth(500)
        row.name:SetText(colored(line.accent and C.orange or skin.muted, line.text))
        return
    end

    local link, id, need
    if line.kind == "need" then
        need = line.need
        link, id = need and need.link, need and need.id
    else
        local drop = line.drop
        link, id = drop and drop.link, drop and drop.id
    end
    row:Show()
    local text, icon, color, resolvedLink = itemText(link, id)
    row.link = link or resolvedLink
    row.icon:SetTexture(icon)
    row.icon:Show()
    row.name:ClearAllPoints()
    row.name:SetPoint("LEFT", 32, 5)
    row.name:SetWidth(280)
    row.name:SetText(text)

    if line.kind == "need" then
        local meta, metaColor = needStatusText(need, nil)
        row.meta:ClearAllPoints()
        row.meta:SetPoint("LEFT", 32, -7)
        row.meta:SetWidth(300)
        row.meta:SetText(colored(metaColor, meta))
        row.bar:SetColorTexture(metaColor[1], metaColor[2], metaColor[3], 0.9)
        row.bar:Show()
        return
    end

    local drop = line.drop
    local recipientText, recipientColor
    if drop.winner then
        recipientText = LJ:IsMe(drop.winner) and LJ.L("DETAIL_YOU") or drop.winner
        recipientColor = classColor(drop.winnerClass)
    elseif drop.passed then
        recipientText = LJ.L("DETAIL_NOBODY")
        recipientColor = skin.muted
    else
        recipientText = LJ.L("DETAIL_RECIPIENT_UNKNOWN")
        recipientColor = skin.muted
    end
    row.recipient:ClearAllPoints()
    row.recipient:SetPoint("RIGHT", -8, 4)
    row.recipient:SetWidth(190)
    row.recipient:SetText(colored(recipientColor, recipientText))

    need = line.need
    if need then
        local meta, metaColor = needStatusText(need, drop)
        row.meta:SetText(colored(metaColor, meta))
    elseif drop.passed and not drop.winner then
        row.meta:SetText(colored(skin.muted, LJ.L("DETAIL_PASSED")))
    end
    row.meta:ClearAllPoints()
    row.meta:SetPoint("LEFT", 32, -7)
    row.meta:SetWidth(300)

    local roll = dropRollText(currentRun, drop)
    row.roll:ClearAllPoints()
    row.roll:SetPoint("RIGHT", -8, -7)
    row.roll:SetWidth(190)
    if roll then row.roll:SetText(colored(skin.progress, roll)) end

    row.bar:SetColorTexture(color[1], color[2], color[3], 0.9)
    row.bar:Show()
end

local function renderPage()
    if not frame then return end
    local list = pages[page] or {}
    for i = 1, ROWS_PER_PAGE do
        local row = rows[i]
        if row then
            if list[i] then
                configureRow(row, list[i])
            else
                row.line = nil
                row:Hide()
            end
        end
    end
    pageText:SetText(LJ.L("DETAIL_PAGE", page, #pages))
    prevButton:SetShown(page > 1)
    nextButton:SetShown(page < #pages)
    M.page = page
end

function M:Create()
    if frame then return frame end
    if type(CreateFrame) ~= "function" then return nil end

    local f = CreateFrame("Frame", "LootJinxRunDetailFrame", UIParent,
        BackdropTemplateMixin and "BackdropTemplate" or nil)
    frame = f
    M.frame = f
    f:SetSize(WIDTH, HEIGHT)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetFrameLevel(100)
    f:SetToplevel(true)
    f:EnableMouse(true)
    if f.SetClampedToScreen then f:SetClampedToScreen(true) end
    local stopDragging = W:DragHeader(f, 66, 46)

    eyebrow = W:Font(f, 8, skin.accent, "OUTLINE")
    eyebrow:SetPoint("TOPLEFT", 57, -12)
    eyebrow:SetText(LJ.L("DETAIL_TITLE"))

    title = W:Font(f, 17, skin.text, "OUTLINE")
    title:SetPoint("TOPLEFT", 57, -25)
    title:SetWidth(433)
    title:SetWordWrap(false)

    subtitle = W:Font(f, 9, skin.muted, "")
    M.subtitle = subtitle
    subtitle:SetPoint("TOPLEFT", 58, -51)
    subtitle:SetWidth(433)
    subtitle:SetWordWrap(false)

    closeButton = W:Button(f, "×", 22, 22)
    W:WindowClose(closeButton)
    closeButton.label:SetPoint("CENTER", 0, 1)
    closeButton:SetScript("OnClick", function() M:Hide() end)
    W:Tooltip(closeButton, LJ.L("CLOSE"), { LJ.L("CLOSE") })

    summaryPanel = W:Panel(f, "BACKGROUND")
    M.summaryPanel = summaryPanel
    summaryPanel:SetPoint("TOPLEFT", 16, -70)
    summaryPanel:SetSize(528, 34)
    summary = W:Font(summaryPanel, 10, skin.text, "")
    M.summary = summary
    summary:SetPoint("LEFT", 12, 0)
    summary:SetWidth(400)
    summary:SetWordWrap(true)
    M.timelineButton = W:Button(summaryPanel, LJ.L("DETAIL_TIMELINE_BUTTON"), 96, 20)
    M.timelineButton:SetPoint("RIGHT", -8, 0)
    M.timelineButton:SetScript("OnClick", function() M:ToggleTimeline() end)
    summaryPanel:EnableMouse(true)
    summaryPanel:SetScript("OnEnter", function(self)
        if currentRun and LJ.ShowRunBasisTooltip then LJ:ShowRunBasisTooltip(self, currentRun) end
    end)
    summaryPanel:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)

    content = CreateFrame("Frame", nil, f)
    content:SetPoint("TOPLEFT", 16, -112)
    content:SetSize(528, CONTENT_HEIGHT)
    content:SetFrameLevel(f:GetFrameLevel() + 2)

    for i = 1, ROWS_PER_PAGE do
        local row = CreateFrame("Button", nil, content)
        row:SetSize(528, ROW_HEIGHT)
        row:SetPoint("TOPLEFT", 0, -((i - 1) * ROW_HEIGHT))
        row:RegisterForClicks("LeftButtonUp")

        row.bg = row:CreateTexture(nil, "BACKGROUND")
        row.bg:SetAllPoints()
        row.bg:SetColorTexture(1, 1, 1, 0)
        row.separator = W:Divider(row)
        row.separator:SetPoint("BOTTOMLEFT")
        row.separator:SetPoint("BOTTOMRIGHT")

        row.bar = row:CreateTexture(nil, "ARTWORK")
        row.bar:SetSize(2, 18)
        row.bar:SetPoint("LEFT", 0, 0)
        row.bar:Hide()

        W:CreateFoldIndicator(row, 10)

        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(16, 16)
        row.icon:SetPoint("LEFT", 8, 0)
        row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        row.icon:Hide()

        row.name = W:Font(row, 11, skin.text, "")
        row.name:SetPoint("LEFT", 32, 5)
        row.name:SetWidth(280)
        row.name:SetWordWrap(false)

        row.recipient = W:Font(row, 10, skin.text, "")
        row.recipient:SetPoint("RIGHT", -8, 4)
        row.recipient:SetWidth(190)
        row.recipient:SetJustifyH("RIGHT")
        row.recipient:SetWordWrap(false)

        row.meta = W:Font(row, 9, skin.muted, "")
        row.meta:SetPoint("LEFT", 32, -7)
        row.meta:SetWidth(300)
        row.meta:SetWordWrap(false)

        row.roll = W:Font(row, 9, skin.progress, "")
        row.roll:SetPoint("RIGHT", -8, -7)
        row.roll:SetWidth(190)
        row.roll:SetJustifyH("RIGHT")
        row.roll:SetWordWrap(false)

        row:SetScript("OnEnter", function(self)
            if self.line and (self.line.group or self.line.kind == "item" or self.line.kind == "need") then
                W:ColorTexture(self.bg, skin.hover)
                if not self.line.group then rowTooltip(self) end
            end
        end)
        row:SetScript("OnClick", function(self)
            local group = self.line and self.line.group
            if group then
                collapsedGroups[group] = not collapsedGroups[group] or nil
                M:Refresh(group)
            end
        end)
        row:SetScript("OnLeave", function(self)
            self.bg:SetColorTexture(skin.surface[1], skin.surface[2], skin.surface[3], self.baseAlpha or 0)
            if GameTooltip then GameTooltip:Hide() end
        end)

        rows[i] = row
    end
    M.rows = rows

    local separator = f:CreateTexture(nil, "ARTWORK")
    separator:SetColorTexture(0.18, 0.19, 0.24, 0.7)
    separator:SetPoint("BOTTOMLEFT", 16, 48)
    separator:SetPoint("BOTTOMRIGHT", -16, 48)
    separator:SetHeight(1)
    self.separator = separator

    hint = W:Font(f, 8, skin.muted, "")
    hint:SetPoint("BOTTOMLEFT", 16, 28)
    hint:SetText(LJ.L("DETAIL_HINT"))
    self.creditLink = W:ForeverDBCredit(f, function() M:Hide() end)
    self.creditLink:SetPoint("BOTTOMRIGHT", -16, 31)

    pageText = W:Font(f, 9, skin.muted, "")
    pageText:SetPoint("BOTTOMLEFT", 132, 10)
    pageText:SetText("")

    finishButton = W:Button(f, LJ.L("RUN_FINISH"), 108, 20)
    M.finishButton = finishButton
    finishButton:SetPoint("BOTTOMLEFT", 16, 10)
    finishButton:SetScript("OnClick", function() M:ConfirmFinish() end)
    finishButton:Hide()

    prevButton = W:Button(f, LJ.L("DETAIL_PREV"), 58, 20)
    prevButton:SetPoint("BOTTOMRIGHT", -82, 10)
    prevButton:SetScript("OnClick", function() M:Page(-1) end)

    nextButton = W:Button(f, LJ.L("DETAIL_NEXT"), 58, 20)
    nextButton:SetPoint("BOTTOMRIGHT", -16, 10)
    nextButton:SetScript("OnClick", function() M:Page(1) end)


    f:SetScript("OnHide", function()
        stopDragging()
        if GameTooltip then GameTooltip:Hide() end
        restoreDashboardEscape()
    end)
    f:Hide()

    if type(UISpecialFrames) == "table" then
        local found = false
        for i = 1, #UISpecialFrames do
            if UISpecialFrames[i] == "LootJinxRunDetailFrame" then found = true break end
        end
        if not found then table.insert(UISpecialFrames, "LootJinxRunDetailFrame") end
    end

    if type(StaticPopupDialogs) == "table" then
        StaticPopupDialogs.LOOTJINX_FINISH_RUN = W:StylePopup({
            text = LJ.L("RUN_FINISH_CONFIRM"),
            button1 = LJ.L("RUN_FINISH_ACCEPT"),
            button2 = LJ.L("REPORT_CANCEL"),
            OnAccept = function()
                local id = M.pendingFinishID
                M.pendingFinishID = nil
                if id and LJ.Tracker and LJ.Tracker:FinishActiveManually(id) then
                    LJ:Print(LJ.L("RUN_FINISH_DONE"))
                    M:Refresh()
                end
            end,
            OnCancel = function() M.pendingFinishID = nil end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        })
    end

    return f
end

function M:ApplyTheme(theme)
    self.theme = LJ:GetLayoutSpec(theme or (LJ.DB and LJ.DB.layoutPreview)).id
    skin = W:Skin(self.theme)
    if not frame then return end
    W:StyleWindow(frame, skin, 63, 30)
    W:Paint(summaryPanel, skin.surface, skin.border)
    W:SetTextFont(title, 20, "", skin.displayFont)
    W:ColorText(title, skin.text)
    W:ColorText(eyebrow, skin.accent)
    for _, label in ipairs({ subtitle, hint, pageText }) do W:ColorText(label, skin.muted) end
    W:ColorText(summary, skin.text)
    W:StyleCredit(self.creditLink, skin)
    W:ColorTexture(self.separator, skin.border)
    for i, row in ipairs(rows) do
        W:StyleListRow(row, skin, i % 2 == 1)
        W:ColorText(row.name, skin.text)
        W:ColorText(row.recipient, skin.text)
        W:ColorText(row.meta, skin.muted)
        W:ColorText(row.roll, skin.progress)
        row.separator:SetColorTexture(skin.border[1], skin.border[2], skin.border[3], .60)
    end
    for _, button in ipairs({ closeButton, finishButton, self.timelineButton, prevButton, nextButton }) do
        W:StyleButton(button, skin)
    end
end
function M:Show(run, theme)
    if type(run) ~= "table" then return false end
    if not frame then self:Create() end
    if not frame then return false end
    self:ApplyTheme(theme or (LJ.UI and LJ.UI.GetLayout and LJ.UI:GetLayout()))
    if run ~= currentRun then collapsedGroups = {} end
    currentRun = run
    self.showTimeline = false
    page = 1
    local ok, err = pcall(M.Refresh, M)
    if not ok then
        LJ:Print(LJ.L("ERROR_PART", "Run-Details", tostring(err)))
        return false
    end
    if not frame:IsShown() then self:SuspendParentEscape() end
    frame:Show()
    return true
end

function M:Hide()
    if frame then frame:Hide() end
end

function M:ConfirmFinish()
    local active = LJ.Tracker and LJ.Tracker:GetActive()
    if not currentRun or active ~= currentRun then return false end
    if type(StaticPopup_Show) ~= "function"
        or type(StaticPopupDialogs) ~= "table"
        or not StaticPopupDialogs.LOOTJINX_FINISH_RUN then
        LJ:Print(LJ.L("RUN_FINISH_UNAVAILABLE"))
        return false
    end
    M.pendingFinishID = active.id
    StaticPopup_Show("LOOTJINX_FINISH_RUN")
    return true
end

function M:ReplaceRun(previous, replacement)
    if currentRun == previous then self:Show(replacement) end
end

function M:IsShown()
    return frame ~= nil and frame:IsShown()
end

local function durationText(run, live)
    local start = tonumber(run.started)
    local finish = live and LJ.Now() or tonumber(run.ended)
    if not start or start <= 0 or not finish or finish < start then return "–" end
    local seconds = math.floor(finish - start)
    if seconds >= 3600 then
        return ("%d:%02d:%02d"):format(math.floor(seconds / 3600), math.floor(seconds / 60) % 60, seconds % 60)
    end
    return ("%d:%02d"):format(math.floor(seconds / 60), seconds % 60)
end

function M:Refresh(group)
    if not frame or not currentRun then return end
    local run = currentRun
    title:SetText(W:Truncate(LJ:DungeonName(run), 42))
    local active = LJ.Tracker and LJ.Tracker.GetActive and LJ.Tracker:GetActive()
    local live = active == run and LJ.Tracker:IsLive() and not run.paused
    local progress = not run.legacy and LJ.DungeonCompletion:Progress(run) or nil
    local status = "RUN_STATUS_OPEN"
    if run.closedReason == "manual" then
        status = "RUN_FINISH_MANUAL"
    elseif run.paused then
        status = "STATUS_IDLE"
    elseif live then
        status = "LIVE"
    elseif LJ.DungeonCompletion:WasCleared(run, progress) then
        status = "DETAIL_CLOSED"
    elseif run.closed then
        status = "DETAIL_ENDED"
    end
    local counted = LJ.Tracker:IsCounted(run)
    local tracking = LJ.L(counted and "DETAIL_STAT_COUNTED" or "DETAIL_STAT_NO_ACTIVITY")
    subtitle:SetText(formatDate(run) .. " · " .. LJ.L(status) .. " · " .. tracking)
    if finishButton then finishButton:SetShown(active == run) end

    local lines, dropCount, bossCount = buildLines(run, progress)
    local won, lost, pending = 0, 0, 0
    for _, need in ipairs(run.needs or {}) do
        if need.result == "won" then won = won + 1
        elseif need.result == "lost" then lost = lost + 1
        else pending = pending + 1 end
    end
    summary:SetText(LJ.L("DETAIL_RUN_COUNTS", durationText(run, live), bossCount, dropCount)
        .. "\n" .. LJ.L("HISTORY_SUMMARY_NEED", won, lost, pending))

    M.lines = self.showTimeline and buildTimelineLines(run) or lines
    self.timelineButton.label:SetText(LJ.L(self.showTimeline
        and "DETAIL_TIMELINE_BACK" or "DETAIL_TIMELINE_BUTTON"))
    W:StyleButton(self.timelineButton, skin, self.showTimeline)
    pages = paginate(M.lines)
    M.pages = pages
    if group then
        for index, list in ipairs(pages) do
            local found
            for _, line in ipairs(list) do
                if line.group == group then found = true; break end
            end
            if found then page = index; break end
        end
    end
    if page > #pages then page = #pages end
    if page < 1 then page = 1 end
    renderPage()
end

function M:ToggleTimeline()
    if not currentRun then return end
    self.showTimeline = not self.showTimeline
    page = 1
    self:Refresh()
end

function M:Page(delta)
    if not frame then return end
    local count = #pages
    if count == 0 then return end
    local newPage = page + (tonumber(delta) or 0)
    if newPage < 1 then newPage = 1 end
    if newPage > count then newPage = count end
    if newPage ~= page then
        page = newPage
        renderPage()
    end
end

function M:SetPage(value)
    if not frame then return end
    value = tonumber(value) or 1
    if value < 1 then value = 1 end
    if value > #pages then value = #pages end
    if value ~= page then
        page = value
        renderPage()
    end
end

if LJ.RegisterRefresh then
    LJ:RegisterRefresh(function()
        if frame and frame:IsShown() then pcall(M.Refresh, M) end
    end)
end
