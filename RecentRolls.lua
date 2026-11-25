local ADDON, ns = ...
local LJ = ns or _G.LootJinx
if not LJ then return end
local R = {}
LJ.RecentRolls = R

local function validRoll(value)
    value = tonumber(value)
    if value and value >= 1 and value <= 100 then return math.floor(value) end
end

local function itemLabel(run, id)
    for _, list in ipairs({ run.needs or {}, run.drops or {} }) do
        for _, entry in ipairs(list) do
            if id ~= nil and entry.id == id and type(entry.link) == "string" and entry.link ~= "" then
                return entry.link
            end
        end
    end
    return LJ.L("RECENT_ROLL_ITEM", tonumber(id) or 0)
end

function R:Entries(run)
    local entries, matched = {}, {}
    local rollIDs = {}
    for _, drop in ipairs(run.drops or {}) do
        if drop.lootHistoryKey and drop.rollID then
            local byItem = rollIDs[drop.id] or {}
            local previous = byItem[drop.lootHistoryKey]
            if previous == nil then
                byItem[drop.lootHistoryKey] = drop.rollID
            elseif previous ~= drop.rollID then
                byItem[drop.lootHistoryKey] = false
            end
            rollIDs[drop.id] = byItem
        end
    end
    for _, roll in ipairs(run.rolls or {}) do
        local value = validRoll(roll.value)
        if value and (roll.kind == "need" or roll.kind == "greed" or roll.kind == "transmog") then
            entries[#entries + 1] = {
                id = roll.id, name = roll.name, kind = roll.kind,
                value = value, at = tonumber(roll.at) or 0,
                lootHistoryKey = roll.lootHistoryKey,
                rollID = roll.rollID or (rollIDs[roll.id] and rollIDs[roll.id][roll.lootHistoryKey]) or nil,
                own = type(roll.name) == "string" and LJ:IsMe(roll.name) or false,
            }
        end
    end
    local observedCount = #entries
    local function matchObservation(need, value, exactOnly)
        local at = tonumber(need.at) or 0
        for i = 1, observedCount do
            local entry = entries[i]
            if not matched[i] and entry.own and entry.kind == "need" and need.id ~= nil and entry.id == need.id
                and entry.value == value then
                local bothKeys = need.lootHistoryKey and entry.lootHistoryKey
                local bothIDs = need.rollID and entry.rollID
                local compatible = (not bothKeys or need.lootHistoryKey == entry.lootHistoryKey)
                    and (not bothIDs or need.rollID == entry.rollID)
                local exact = bothKeys or bothIDs
                local near = entry.at >= at and entry.at - at <= 300
                if compatible and (exactOnly and exact or not exactOnly and near) then
                    matched[i] = true
                    return true
                end
            end
        end
    end

    -- Reserve identity matches before considering observations with missing identity.
    local matchedNeeds = {}
    for _, need in ipairs(run.needs or {}) do
        local value = validRoll(need.roll)
        if value and (need.lootHistoryKey or need.rollID) then
            matchedNeeds[need] = matchObservation(need, value, true)
        end
    end
    for _, need in ipairs(run.needs or {}) do
        local value = validRoll(need.roll)
        if value and not matchedNeeds[need] and not matchObservation(need, value, false) then
            entries[#entries + 1] = {
                id = need.id, name = LJ.L("RECENT_ROLL_YOU"), kind = "need",
                value = value, at = tonumber(need.at) or 0, own = true,
                lootHistoryKey = need.lootHistoryKey, rollID = need.rollID,
            }
        end
    end
    table.sort(entries, function(a, b) return a.at < b.at end)
    return entries
end

-- Ein Badge ist knapp. Statt nur den letzten Need-Wert zu zeigen (bei
-- mehreren Würfen im selben Run irreführend) zählt die Zusammenfassung die
-- beobachteten Würfe je Art. Item, Spieler und Werte stehen im Tooltip.
function R:Summary(run)
    local counts, total = {}, 0
    for _, entry in ipairs(self:Entries(run)) do
        if entry.own then
            counts[entry.kind] = (counts[entry.kind] or 0) + 1
            total = total + 1
        end
    end
    if total == 0 then return nil end
    local parts = {}
    for _, kind in ipairs({ "need", "greed", "transmog" }) do
        local count = counts[kind]
        if count then
            parts[#parts + 1] = LJ.L("RECENT_ROLL_" .. string.upper(kind) .. "_COUNT", count)
        end
    end
    return table.concat(parts, " · ")
end

function R:Lines(run)
    local lines = {}
    for _, entry in ipairs(self:Entries(run)) do
        local key = entry.kind == "transmog" and "DETAIL_ROLL_TRANSMOG"
            or entry.kind == "greed" and "DETAIL_ROLL_GREED" or "DETAIL_ROLL_NEED"
        local kind = LJ.L(key, entry.value)
        lines[#lines + 1] = LJ.L("RECENT_ROLL_LINE", itemLabel(run, entry.id),
            entry.name or LJ.L("RECENT_ROLL_YOU"), kind)
    end
    return lines
end

function R:AddTooltip(run)
    local lines = self:Lines(run)
    if #lines == 0 then return end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(LJ.L("RECENT_ROLL_TITLE"), 1, 0.82, 0.4)
    for i = 1, math.min(#lines, 12) do
        GameTooltip:AddLine(lines[i], 0.86, 0.87, 0.90, true)
    end
    if #lines > 12 then
        GameTooltip:AddLine(LJ.L("RECENT_ROLL_MORE", #lines - 12), 0.6, 0.6, 0.6)
    end
end
