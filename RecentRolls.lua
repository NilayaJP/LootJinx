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
            if entry.id == id and type(entry.link) == "string" and entry.link ~= "" then
                return entry.link
            end
        end
    end
    return LJ.L("RECENT_ROLL_ITEM", tonumber(id) or 0)
end

function R:Entries(run)
    local entries, matched = {}, {}
    for _, roll in ipairs(run.rolls or {}) do
        local value = validRoll(roll.value)
        if value and (roll.kind == "need" or roll.kind == "greed" or roll.kind == "transmog") then
            entries[#entries + 1] = {
                id = roll.id, name = roll.name, kind = roll.kind,
                value = value, at = tonumber(roll.at) or 0,
                own = type(roll.name) == "string" and LJ:IsMe(roll.name) or false,
            }
        end
    end
    for _, need in ipairs(run.needs or {}) do
        local value = validRoll(need.roll)
        if value then
            local match
            for i, entry in ipairs(entries) do
                if entry.own and entry.kind == "need" and entry.id == need.id
                    and entry.value == value and not matched[i]
                    and math.abs(entry.at - (tonumber(need.at) or 0)) <= 10 then
                    match = i
                    break
                end
            end
            if match then
                matched[match] = true
            else
                entries[#entries + 1] = {
                    id = need.id, name = LJ.L("RECENT_ROLL_YOU"), kind = "need",
                    value = value, at = tonumber(need.at) or 0, own = true,
                }
            end
        end
    end
    table.sort(entries, function(a, b) return a.at < b.at end)
    return entries
end

function R:Summary(run)
    local own, other
    for _, entry in ipairs(self:Entries(run)) do
        if entry.kind == "need" then
            if entry.own then own = entry.value else other = entry.value end
        end
    end
    if own and other then return LJ.L("RECENT_ROLL_BOTH", own, other) end
    if own then return LJ.L("RECENT_ROLL_OWN", own) end
    if other then return LJ.L("RECENT_ROLL_OTHER", other) end
    return nil
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
