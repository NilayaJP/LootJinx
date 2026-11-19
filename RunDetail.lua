-- LootJinx – Run-Details
local ADDON, ns = ...
local LJ = ns or _G.LootJinx
if not LJ then return end

local M = {}
LJ.RunDetail = M

local W = LJ.Widgets
local CLASSIC = LJ.COLORS
local JOURNAL = {
    bg = { 0.141, 0.102, 0.102, 0.98 },
    card = { 0.190, 0.145, 0.133, 0.98 },
    border = { 0.545, 0.384, 0.267, 1 },
    accent = { 0.918, 0.769, 0.494, 1 },
    cyan = { 0.906, 0.835, 0.729, 1 },
    gold = { 0.918, 0.769, 0.494, 1 },
    green = { 0.560, 0.800, 0.500, 1 },
    red = { 0.900, 0.420, 0.340, 1 },
    orange = { 0.910, 0.600, 0.340, 1 },
    text = { 0.906, 0.835, 0.729, 1 },
    muted = { 0.690, 0.608, 0.510, 1 },
    dim = { 0.545, 0.460, 0.380, 1 },
}
local C = CLASSIC
local FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
local WHITE = "Interface\\Buttons\\WHITE8X8"
local UNKNOWN_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"

local WIDTH, HEIGHT = 560, 560
local ROW_HEIGHT = 30
local ROWS_PER_PAGE = 12
local CONTENT_HEIGHT = ROW_HEIGHT * ROWS_PER_PAGE

local frame, content, summary, subtitle, title, eyebrow, pageText, prevButton, nextButton
local summaryPanel, hint, closeButton, finishButton, topAccent
local rows = {}
local pages = {}
local currentRun
local page = 1
local suspendedSpecialNames
local restoreToken = 0
local deferredRestoreFrame

local function suspendDashboardEscape()
    if type(UISpecialFrames) ~= "table" then return end
    local dashboard = LJ.UI and LJ.UI.frame
    local history = LJ.History and LJ.History.frame
    local historyShown = history and history.IsShown and history:IsShown()
    local windows = { dashboard, history }
    local names = {}
    for _, window in ipairs(windows) do
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
                names[#names + 1] = name
            end
        end
    end
    suspendedSpecialNames = names
    restoreToken = restoreToken + 1
end

local function restoreDashboardEscape()
    local names = suspendedSpecialNames
    if not names then return end
    suspendedSpecialNames = nil
    restoreToken = restoreToken + 1
    local token = restoreToken
    local function restore()
        if token ~= restoreToken or type(UISpecialFrames) ~= "table" then return end
        for _, name in ipairs(names) do
            local found = false
            for i = 1, #UISpecialFrames do
                if UISpecialFrames[i] == name then found = true break end
            end
            if not found then table.insert(UISpecialFrames, name) end
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
    c = c or C.text
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
    return C.text
end

local function classColor(classFile)
    local c = classFile and _G.RAID_CLASS_COLORS and _G.RAID_CLASS_COLORS[classFile]
    if c then return { c.r or 1, c.g or 1, c.b or 1 } end
    return C.text
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

local function findNeed(run, drop, used)
    local found, nearest
    for i = 1, #(run.needs or {}) do
        local n = run.needs[i]
        if n.id == drop.id and not used[n]
            and (not n.rollID or not drop.rollID or n.rollID == drop.rollID)
            and (not n.lootHistoryKey or not drop.lootHistoryKey
                or n.lootHistoryKey == drop.lootHistoryKey) then
            if drop.rollID and n.rollID == drop.rollID then return n end
            if drop.lootHistoryKey and n.lootHistoryKey == drop.lootHistoryKey then return n end
            local selfWon = drop.winner and LJ:IsMe(drop.winner)
            local compatible = not drop.winner or not n.result
                or (selfWon and n.result == "won")
                or (not selfWon and n.result == "lost")
            local distance = math.abs((tonumber(drop.at) or 0) - (tonumber(n.at) or 0))
            if compatible and (not nearest or distance < nearest) then
                found, nearest = n, distance
            end
        end
    end
    return found
end

local function needStatusText(need, drop)
    local result = need and need.result
    if not result and drop and drop.winner and LJ:IsMe(drop.winner) then result = "won" end
    local status, color
    if result == "won" then
        status, color = LJ.L("DETAIL_NEED_WON"), C.green
    elseif result == "lost" then
        status, color = LJ.L("DETAIL_NEED_LOST"), C.red
    else
        status, color = LJ.L("DETAIL_NEED_OPEN"), C.muted
    end
    local value = need and tonumber(need.roll) or nil
    if not value and drop and drop.winner and LJ:IsMe(drop.winner)
        and drop.rollKind == "need" then
        value = tonumber(drop.roll)
    end
    local text
    if value then
        text = LJ.L("DETAIL_NEED_LINE", value, status)
    else
        text = LJ.L("DETAIL_NEED_LINE_NO_ROLL", status)
    end
    if LJ.Evidence then
        local observedSelfWinner = drop and drop.winner and LJ:IsMe(drop.winner)
        local level = LJ.Evidence:Classify(need, observedSelfWinner)
        text = text .. " · " .. LJ.L("EVIDENCE_" .. string.upper(level))
    end
    return text, color
end

local function itemText(link, id)
    if link then LJ:LoadItem(link, id) end
    local info = link and LJ:ItemInfo(link) or nil
    local instant = link and LJ:ItemInfoInstant(link) or nil
    local icon = (info and info.icon) or (instant and instant.icon) or UNKNOWN_ICON
    if info and type(info.name) == "string" and info.name ~= "" then
        return colored(qualityColor(info.quality), info.name), icon, qualityColor(info.quality)
    end
    if type(link) == "string" and link ~= "" then
        return link, icon, qualityColor(info and info.quality)
    end
    return LJ.L("DETAIL_ITEM_UNKNOWN", tonumber(id) or 0), icon, C.muted
end

local function dropRollText(run, drop)
    local value = tonumber(drop.roll)
    local kind = drop.rollKind
    if not value and drop.winner then
        local name = tostring(drop.winner):lower()
        for i = #(run.rolls or {}), 1, -1 do
            local roll = run.rolls[i]
            if roll.id == drop.id and type(roll.name) == "string"
                and roll.name:lower() == name then
                value, kind = tonumber(roll.value), roll.kind
                break
            end
        end
    end
    if not value then return nil end
    if kind == "transmog" then return LJ.L("DETAIL_ROLL_TRANSMOG", value) end
    if kind == "greed" then return LJ.L("DETAIL_ROLL_GREED", value) end
    return LJ.L("DETAIL_ROLL_NEED", value)
end

local function bossIndexFor(run, drop, bosses, catalogKind, catalogBoss)
    local id = tonumber(drop.bossID)
    if id and id > 0 then
        for i = #bosses, 1, -1 do
            if tonumber(bosses[i].id) == id then return i end
        end
    end
    local name = type(drop.bossName) == "string" and drop.bossName:lower() or nil
    if name then
        for i = #bosses, 1, -1 do
            local bossName = bosses[i].name
            if type(bossName) == "string" and bossName:lower() == name then return i end
        end
    end
    if (id and id > 0) or drop.source == "encounter" then return nil end
    if catalogKind == "boss" and type(catalogBoss) == "string" then
        local aliases = {}
        for _, dungeon in ipairs(LJ.DungeonLoot and LJ.DungeonLoot:Candidates(run) or {}) do
            for _, required in ipairs((LJ.DungeonCompletionData or {})[dungeon] or {}) do
                if required.name == catalogBoss then
                    for _, alias in ipairs(required.aliases or {}) do
                        aliases[alias:lower()] = true
                    end
                end
            end
        end
        for i = #bosses, 1, -1 do
            if type(bosses[i].name) == "string"
                and (bosses[i].name:lower() == catalogBoss:lower()
                    or aliases[bosses[i].name:lower()]) then return i end
        end
    end
    return nil
end

local function otherLootReason(run, drop, catalogKind)
    if (tonumber(drop.bossID) or 0) > 0 or drop.bossName or drop.source == "encounter" then
        return "DETAIL_OTHER_ENCOUNTER"
    end
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
    local modernQuality = type(drop.link) == "string"
        and tonumber(drop.link:match("^|cnIQ(%d+):")) or nil
    if modernQuality and modernQuality >= 0 and modernQuality <= 7 then
        return modernQuality
    end
    local color = type(drop.link) == "string" and drop.link:match("^|cff(%x%x%x%x%x%x)")
    local qualities = { ["9d9d9d"] = 0, ["ffffff"] = 1, ["1eff00"] = 2,
        ["0070dd"] = 3, ["a335ee"] = 4, ["ff8000"] = 5 }
    return color and qualities[color:lower()] or nil
end

local function completionDungeonName(dungeon)
    if LJ.lang == "de" then
        return (LJ.DungeonCompletionNames or {})[dungeon] or dungeon
    end
    return dungeon
end

local function addCompletionLines(lines, run)
    lines[#lines + 1] = { kind = "section", name = LJ.L("DETAIL_COMPLETION_SECTION") }
    if run.legacy == true then
        lines[#lines + 1] = { kind = "note", text = LJ.L("DETAIL_COMPLETION_LEGACY"), muted = true }
        return
    end
    local progress = LJ.DungeonCompletion and LJ.DungeonCompletion:Progress(run)
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

local function buildLines(run)
    local lines = {}
    addCompletionLines(lines, run)
    -- Need-Ergebnisse direkt oben zeigen; einzelne Drops verlinken ihre Need
    -- weiterhin zusaetzlich in der Boss-Liste.
    local needs = sortedNeeds(run)
    if #needs > 0 then
        lines[#lines + 1] = { kind = "section", name = LJ.L("DETAIL_NEED_SECTION") }
        for i = 1, #needs do
            lines[#lines + 1] = { kind = "need", need = needs[i] }
        end
    end
    local bosses = run.bosses or {}
    local byBoss = {}
    local trash = {}
    local other = {}
    local otherReasons = {}
    local needByDrop = {}
    local usedNeeds = {}
    local dropCount = 0

    for i = 1, #(run.drops or {}) do
        local drop = run.drops[i]
        if (bossLootQuality(drop) or 0) >= 2 then
            local need = findNeed(run, drop, usedNeeds)
            if need then
                needByDrop[drop] = need
                usedNeeds[need] = true
            end
            local catalogKind, catalogBoss
            if LJ.DungeonLoot then
                catalogKind, catalogBoss = LJ.DungeonLoot:Source(run, drop.id)
            end
            local index = bossIndexFor(run, drop, bosses, catalogKind, catalogBoss)
            if index then
                byBoss[index] = byBoss[index] or {}
                byBoss[index][#byBoss[index] + 1] = drop
            elseif catalogKind == "trash" then
                trash[#trash + 1] = drop
            else
                other[#other + 1] = drop
                otherReasons[drop] = otherLootReason(run, drop, catalogKind)
            end
            dropCount = dropCount + 1
        end
    end

    for i = 1, #bosses do
        local boss = bosses[i]
        local items = byBoss[i] or {}
        lines[#lines + 1] = {
            kind = "boss",
            name = boss.name or LJ.L("DETAIL_UNKNOWN_BOSS"),
            count = #items,
        }
        if #items == 0 then
            lines[#lines + 1] = { kind = "note", text = LJ.L("DETAIL_BOSS_EMPTY"), muted = true }
        else
            for j = 1, #items do
                lines[#lines + 1] = { kind = "item", drop = items[j], need = needByDrop[items[j]] }
            end
        end
    end

    if #trash > 0 then
        lines[#lines + 1] = {
            kind = "boss", name = LJ.L("DETAIL_TRASH"), count = #trash, other = true,
        }
        for i = 1, #trash do
            lines[#lines + 1] = { kind = "item", drop = trash[i], need = needByDrop[trash[i]] }
        end
    end

    if #other > 0 then
        lines[#lines + 1] = {
            kind = "boss", name = LJ.L("DETAIL_OTHER"), count = #other, other = true,
        }
        for i = 1, #other do
            lines[#lines + 1] = { kind = "item", drop = other[i], need = needByDrop[other[i]],
                attributionReason = otherReasons[other[i]] }
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
        local needs = sortedNeeds(run)
        if #needs == 0 then
            lines[#lines + 1] = { kind = "note", text = LJ.L("DETAIL_NO_NEEDS"), muted = true }
        end
    end

    if #lines == 0 then
        lines[#lines + 1] = { kind = "note", text = LJ.L("DETAIL_EMPTY"), muted = true }
    end
    return lines, dropCount
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
        if line.kind == "boss" and #current >= ROWS_PER_PAGE - 1 then flush() end
        current[#current + 1] = line
        if #current >= ROWS_PER_PAGE then
            if line.kind == "boss" and #current > 1 then
                local header = table.remove(current)
                flush()
                current[#current + 1] = header
            else
                flush()
            end
        end
    end
    flush()
    if #out == 0 then
        out[1] = { { kind = "note", text = LJ.L("DETAIL_EMPTY"), muted = true } }
    end
    return out
end

local function itemRolls(run, id, at, historyKey)
    local out = {}
    if not run or not id then return out end
    local center = tonumber(at) or 0
    for i = 1, #(run.rolls or {}) do
        local roll = run.rolls[i]
        if roll.id == id then
            local rollAt = tonumber(roll.at) or 0
            local near = center == 0 or math.abs(rollAt - center) <= (historyKey and 30 or 300)
            local matchingHistory = historyKey and roll.lootHistoryKey == historyKey
            if matchingHistory or (near and (not historyKey or not roll.lootHistoryKey)) then
                out[#out + 1] = roll
            end
        end
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
    if not link and not need then return end
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    local shown = false
    if link and GameTooltip.SetHyperlink then
        shown = pcall(GameTooltip.SetHyperlink, GameTooltip, link)
    end
    if link and not shown then GameTooltip:AddLine(link, 0.92, 0.93, 0.96) end
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
        local observedSelfWinner = drop and drop.winner and LJ:IsMe(drop.winner)
        local level, reason = LJ.Evidence:Classify(need, observedSelfWinner)
        GameTooltip:AddLine(LJ.L("EVIDENCE_TOOLTIP", LJ.L("EVIDENCE_" .. string.upper(level))),
            0.92, 0.82, 0.61)
        GameTooltip:AddLine(LJ.L(reason), 0.76, 0.78, 0.83, true)
    end
    local id = line.kind == "item" and line.drop and line.drop.id
        or line.kind == "need" and line.need and line.need.id
    local at = line.kind == "item" and line.drop and line.drop.at
        or line.kind == "need" and line.need and line.need.at
    local historyKey = line.kind == "item" and line.drop and line.drop.lootHistoryKey
    local rolls = itemRolls(currentRun, id, at, historyKey)
    if #rolls > 0 then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(LJ.L("DETAIL_ROLLS_SECTION"), 0.92, 0.82, 0.61)
        for i = 1, #rolls do
            local roll = rolls[i]
            local kind = roll.kind == "transmog" and LJ.L("DETAIL_ROLL_KIND_TRANSMOG")
                or roll.kind == "greed" and LJ.L("DETAIL_ROLL_KIND_GREED")
                or LJ.L("DETAIL_ROLL_KIND_NEED")
            local name = roll.name
            if LJ:IsMe(name) then name = LJ.L("DETAIL_YOU") end
            local text = LJ.L("DETAIL_ROLL_LINE", kind, name, tonumber(roll.value) or 0)
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
    row.bg:SetColorTexture(1, 1, 1, 0)
    row.bar:Hide()
    row.icon:Hide()
    row.recipient:SetText("")
    row.roll:SetText("")
    row.meta:SetText("")
    row.name:SetText("")

    if line.kind == "boss" or line.kind == "section" then
        row:Show()
        row.name:ClearAllPoints()
        row.name:SetPoint("LEFT", 10, 0)
        row.name:SetWidth(380)
        local color = line.kind == "section" and C.cyan or (line.other and C.gold or C.accent)
        row.name:SetText(colored(color, line.name))
        if line.count then
            row.recipient:ClearAllPoints()
            row.recipient:SetPoint("RIGHT", -8, 0)
            row.recipient:SetWidth(140)
            row.recipient:SetText(colored(C.muted, LJ.L("DETAIL_BOSS_ITEMS", line.count)))
        end
        row.bg:SetColorTexture(1, 1, 1, line.kind == "section" and 0.02 or 0.035)
        row.baseAlpha = line.kind == "section" and 0.02 or 0.035
        row.bar:SetColorTexture(color[1], color[2], color[3], 1)
        row.bar:Show()
        return
    end

    if line.kind == "note" then
        row:Show()
        row.name:ClearAllPoints()
        row.name:SetPoint("LEFT", 10, 0)
        row.name:SetWidth(500)
        row.name:SetText(colored(line.accent and C.orange or C.muted, line.text))
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
    local text, icon, color = itemText(link, id)
    row.link = link
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
        recipientColor = C.muted
    else
        recipientText = LJ.L("DETAIL_RECIPIENT_UNKNOWN")
        recipientColor = C.muted
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
        row.meta:SetText(colored(C.muted, LJ.L("DETAIL_PASSED")))
    end
    row.meta:ClearAllPoints()
    row.meta:SetPoint("LEFT", 32, -7)
    row.meta:SetWidth(300)

    local roll = dropRollText(currentRun, drop)
    row.roll:ClearAllPoints()
    row.roll:SetPoint("RIGHT", -8, -7)
    row.roll:SetWidth(190)
    if roll then row.roll:SetText(colored(C.gold, roll)) end

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
                row:Hide()
            end
        end
    end
    pageText:SetText(LJ.L("DETAIL_PAGE", page, #pages))
    prevButton:SetShown(page > 1)
    nextButton:SetShown(page < #pages)
    M.page = page
end

local function applyBackdrop(f)
    if f.SetBackdrop then
        f:SetBackdrop({
            bgFile = WHITE,
            edgeFile = WHITE,
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        f:SetBackdropColor(C.bg[1], C.bg[2], C.bg[3], C.bg[4] or 1)
        f:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 1)
    end
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
    applyBackdrop(f)

    eyebrow = W:Font(f, 8, C.accent, "OUTLINE")
    eyebrow:SetPoint("TOPLEFT", 20, -12)
    eyebrow:SetText(LJ.L("DETAIL_TITLE"))

    title = W:Font(f, 17, C.text, "OUTLINE")
    title:SetPoint("TOPLEFT", 20, -24)
    title:SetWidth(470)
    title:SetWordWrap(false)

    subtitle = W:Font(f, 9, C.muted, "")
    M.subtitle = subtitle
    subtitle:SetPoint("TOPLEFT", 21, -47)
    subtitle:SetWidth(470)
    subtitle:SetWordWrap(false)

    closeButton = W:Button(f, "×", 22, 22)
    closeButton:SetPoint("TOPRIGHT", -14, -14)
    closeButton.label:SetFont(FONT, 15, "")
    closeButton.label:SetPoint("CENTER", 0, 1)
    closeButton:SetScript("OnClick", function() M:Hide() end)
    W:Tooltip(closeButton, LJ.L("CLOSE"), { LJ.L("CLOSE") })

    summaryPanel = W:Panel(f, "BACKGROUND")
    M.summaryPanel = summaryPanel
    summaryPanel:SetPoint("TOPLEFT", 16, -70)
    summaryPanel:SetSize(528, 34)
    summary = W:Font(summaryPanel, 10, C.text, "")
    M.summary = summary
    summary:SetPoint("LEFT", 12, 0)
    summary:SetWidth(400)
    summary:SetWordWrap(false)
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
        local row = CreateFrame("Frame", nil, content)
        row:SetSize(528, ROW_HEIGHT)
        row:SetPoint("TOPLEFT", 0, -((i - 1) * ROW_HEIGHT))
        row:EnableMouse(true)

        row.bg = row:CreateTexture(nil, "BACKGROUND")
        row.bg:SetAllPoints()
        row.bg:SetColorTexture(1, 1, 1, 0)

        row.bar = row:CreateTexture(nil, "ARTWORK")
        row.bar:SetSize(2, 18)
        row.bar:SetPoint("LEFT", 0, 0)
        row.bar:Hide()

        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(16, 16)
        row.icon:SetPoint("LEFT", 8, 0)
        row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        row.icon:Hide()

        row.name = W:Font(row, 11, C.text, "")
        row.name:SetPoint("LEFT", 32, 5)
        row.name:SetWidth(280)
        row.name:SetWordWrap(false)

        row.recipient = W:Font(row, 10, C.text, "")
        row.recipient:SetPoint("RIGHT", -8, 4)
        row.recipient:SetWidth(190)
        row.recipient:SetJustifyH("RIGHT")
        row.recipient:SetWordWrap(false)

        row.meta = W:Font(row, 9, C.muted, "")
        row.meta:SetPoint("LEFT", 32, -7)
        row.meta:SetWidth(300)
        row.meta:SetWordWrap(false)

        row.roll = W:Font(row, 9, C.gold, "")
        row.roll:SetPoint("RIGHT", -8, -7)
        row.roll:SetWidth(190)
        row.roll:SetJustifyH("RIGHT")
        row.roll:SetWordWrap(false)

        row:SetScript("OnEnter", function(self)
            if self.line and (self.line.kind == "item" or self.line.kind == "need") then
                self.bg:SetColorTexture(1, 1, 1, 0.045)
                rowTooltip(self)
            end
        end)
        row:SetScript("OnLeave", function(self)
            self.bg:SetColorTexture(1, 1, 1, self.baseAlpha or 0)
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

    hint = W:Font(f, 8, C.dim, "")
    hint:SetPoint("BOTTOMLEFT", 16, 28)
    hint:SetText(LJ.L("DETAIL_HINT"))

    pageText = W:Font(f, 9, C.muted, "")
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

    topAccent = f:CreateTexture(nil, "ARTWORK")
    topAccent:SetPoint("TOPLEFT", 1, -1)
    topAccent:SetPoint("TOPRIGHT", -1, -1)
    topAccent:SetHeight(2)
    topAccent:SetColorTexture(JOURNAL.accent[1], JOURNAL.accent[2], JOURNAL.accent[3], 1)
    topAccent:Hide()

    f:SetScript("OnHide", function()
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
        StaticPopupDialogs.LOOTJINX_FINISH_RUN = {
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
        }
    end

    return f
end

local function tintButton(button, journal)
    if not button then return end
    if not button.classicOnEnter then
        button.classicOnEnter = button:GetScript("OnEnter")
        button.classicOnLeave = button:GetScript("OnLeave")
    end
    if journal then
        if button.SetBackdropColor then button:SetBackdropColor(0.114, 0.086, 0.082, 0.96) end
        if button.SetBackdropBorderColor then
            button:SetBackdropBorderColor(JOURNAL.border[1], JOURNAL.border[2], JOURNAL.border[3], 1)
        end
        button.label:SetTextColor(JOURNAL.text[1], JOURNAL.text[2], JOURNAL.text[3], 1)
        button:SetScript("OnEnter", function(self)
            if self.SetBackdropColor then
                self:SetBackdropColor(JOURNAL.card[1], JOURNAL.card[2], JOURNAL.card[3], 1)
            end
            if self.SetBackdropBorderColor then
                self:SetBackdropBorderColor(JOURNAL.accent[1], JOURNAL.accent[2], JOURNAL.accent[3], 1)
            end
        end)
        button:SetScript("OnLeave", function(self)
            if self.SetBackdropColor then self:SetBackdropColor(0.114, 0.086, 0.082, 0.96) end
            if self.SetBackdropBorderColor then
                self:SetBackdropBorderColor(JOURNAL.border[1], JOURNAL.border[2], JOURNAL.border[3], 1)
            end
        end)
    else
        if button.SetBackdropColor then button:SetBackdropColor(0.10, 0.11, 0.14, 0.96) end
        if button.SetBackdropBorderColor then
            button:SetBackdropBorderColor(CLASSIC.border[1], CLASSIC.border[2], CLASSIC.border[3], 1)
        end
        button.label:SetTextColor(CLASSIC.muted[1], CLASSIC.muted[2], CLASSIC.muted[3], 1)
        button:SetScript("OnEnter", button.classicOnEnter)
        button:SetScript("OnLeave", button.classicOnLeave)
    end
end

function M:ApplyTheme(theme)
    theme = theme == "journal" and "journal" or "classic"
    C = theme == "journal" and JOURNAL or CLASSIC
    self.theme = theme
    if not frame then return end
    applyBackdrop(frame)
    if summaryPanel and summaryPanel.SetBackdropColor then
        summaryPanel:SetBackdropColor(C.card[1], C.card[2], C.card[3], C.card[4] or 1)
        summaryPanel:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 1)
    end
    eyebrow:SetTextColor(C.accent[1], C.accent[2], C.accent[3], 1)
    title:SetTextColor(C.text[1], C.text[2], C.text[3], 1)
    if theme == "journal" then
        pcall(title.SetFont, title, "Fonts\\MORPHEUS.TTF", 19, "")
    else
        title:SetFont(FONT, 17, "OUTLINE")
    end
    subtitle:SetTextColor(C.muted[1], C.muted[2], C.muted[3], 1)
    summary:SetTextColor(C.text[1], C.text[2], C.text[3], 1)
    hint:SetTextColor(C.dim[1], C.dim[2], C.dim[3], 1)
    pageText:SetTextColor(C.muted[1], C.muted[2], C.muted[3], 1)
    for i = 1, #rows do
        local row = rows[i]
        row.name:SetTextColor(C.text[1], C.text[2], C.text[3], 1)
        row.recipient:SetTextColor(C.text[1], C.text[2], C.text[3], 1)
        row.meta:SetTextColor(C.muted[1], C.muted[2], C.muted[3], 1)
        row.roll:SetTextColor(C.gold[1], C.gold[2], C.gold[3], 1)
    end
    tintButton(closeButton, theme == "journal")
    tintButton(finishButton, theme == "journal")
    tintButton(self.timelineButton, theme == "journal")
    tintButton(prevButton, theme == "journal")
    tintButton(nextButton, theme == "journal")
    topAccent:SetShown(theme == "journal")
end

function M:Show(run, theme)
    if type(run) ~= "table" then return false end
    if not frame then self:Create() end
    if not frame then return false end
    self:ApplyTheme(theme or (LJ.UI and LJ.UI.GetLayout and LJ.UI:GetLayout()))
    currentRun = run
    self.showTimeline = false
    page = 1
    local ok, err = pcall(M.Refresh, M)
    if not ok then
        LJ:Print(LJ.L("ERROR_PART", "Run-Details", tostring(err)))
        return false
    end
    if not frame:IsShown() then suspendDashboardEscape() end
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

function M:Refresh()
    if not frame or not currentRun then return end
    local run = currentRun
    title:SetText(W:Truncate(run.name or LJ.L("UNKNOWN_DUNGEON"), 42))
    local active = LJ.Tracker and LJ.Tracker.GetActive and LJ.Tracker:GetActive()
    local status = active == run and (LJ.Tracker:IsLive() and LJ.L("LIVE") or LJ.L("DETAIL_ENDED"))
        or LJ.L(run.closedReason == "all-bosses-cleared" and "DETAIL_CLOSED" or "DETAIL_ENDED")
    if run.closedReason == "manual" then
        status = LJ.L("RUN_FINISH_MANUAL")
    end
    subtitle:SetText(formatDate(run) .. " · " .. status)
    if finishButton then finishButton:SetShown(active == run) end

    local bossCount = #(run.bosses or {})
    local lines, dropCount = buildLines(run)
    local needTotal, needWon = 0, 0
    for i = 1, #(run.needs or {}) do
        local n = run.needs[i]
        needTotal = needTotal + 1
        if n.result == "won" then needWon = needWon + 1 end
    end
    summary:SetText(LJ.L("DETAIL_SUMMARY", bossCount, dropCount, needTotal, needWon))

    M.lines = self.showTimeline and buildTimelineLines(run) or lines
    self.timelineButton.label:SetText(LJ.L(self.showTimeline
        and "DETAIL_TIMELINE_BACK" or "DETAIL_TIMELINE_BUTTON"))
    pages = paginate(M.lines)
    M.pages = pages
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
