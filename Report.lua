-- LootJinx: shared report building and chat delivery for both layouts.
local ADDON, ns = ...
local LJ = ns or _G.LootJinx
if not LJ then return end

local R = {}
LJ.Report = R

local queue = {}
local timer
local session = 0
local reportChannel, reportTarget

local function stripName(value)
    return tostring(value or ""):match("^%s*(.-)%s*$") or ""
end

function R:GetTargetName()
    if type(UnitName) ~= "function" then return nil end
    if type(UnitIsPlayer) == "function" then
        local okP, isPlayer = pcall(UnitIsPlayer, "target")
        isPlayer = okP and LJ.Plain(isPlayer) or nil
        if isPlayer == false then return nil end
    end
    local ok, name, realm = pcall(UnitName, "target")
    name, realm = ok and LJ.Plain(name) or nil, ok and LJ.Plain(realm) or nil
    if type(name) ~= "string" or name == "" then return nil end
    local okP, _, ownRealm = pcall(UnitName, "player")
    ownRealm = okP and LJ.Plain(ownRealm) or nil
    if type(realm) == "string" and realm ~= "" and realm ~= ownRealm then
        return name .. "-" .. realm
    end
    return name
end

local function groupChat()
    if type(IsInRaid) == "function" then
        local ok, raid = pcall(IsInRaid)
        raid = ok and LJ.Plain(raid) or nil
        if raid == true then return "RAID", true end
    end
    if type(IsInGroup) == "function" then
        local ok, grouped = pcall(IsInGroup)
        grouped = ok and LJ.Plain(grouped) or nil
        if grouped == true then return "PARTY", true end
        if grouped == false then return "PARTY", false end
    end
    if type(GetNumSubgroupMembers) == "function" then
        local ok, count = pcall(GetNumSubgroupMembers)
        count = ok and tonumber(LJ.Plain(count)) or 0
        return "PARTY", count > 0
    end
    if type(GetNumPartyMembers) == "function" then
        local ok, count = pcall(GetNumPartyMembers)
        count = ok and tonumber(LJ.Plain(count)) or 0
        return "PARTY", count > 0
    end
    return "PARTY", false
end

function R:Build()
    local stats = LJ.Stats.Compute(LJ.Tracker:GetRuns())
    local className = select(1, LJ:ClassName())
    local _, statLabel = LJ:PlayerStat()
    return {
        LJ.L("REPORT_LINE_HEADER", className, statLabel),
        LJ.L("REPORT_LINE_CURSE", stats.noAgiDungeons or 0, stats.totalDungeons or 0,
            statLabel, stats.noAgiCurrent or 0, stats.noAgiMax or 0),
        LJ.L("REPORT_LINE_NEED", stats.needWins or 0, stats.needLost or 0,
            stats.needPending or 0, stats.lostNeedCurrent or 0, stats.lostNeedMax or 0),
        LJ.L("REPORT_LINE_NO_WIN", stats.noNeedWinDungeons or 0,
            stats.noNeedWinCurrent or 0, stats.noNeedWinMax or 0),
        LJ.L("REPORT_LINE_NO_LOOT", stats.noLootDungeons or 0,
            stats.noLootCurrent or 0, stats.noLootMax or 0),
        LJ.L("REPORT_LINE_SINCE", stats.sinceNeedWinCurrent or 0, stats.sinceNeedWinMax or 0),
    }
end

function R:Cancel()
    session = session + 1
    if timer and timer.Cancel then pcall(timer.Cancel, timer) end
    timer = nil
    queue = {}
end

local function finishReport()
    if reportChannel == "WHISPER" then
        LJ:Print(LJ.L("REPORT_SENT_WHISPER", reportTarget or "?"))
    elseif reportChannel == "RAID" then
        LJ:Print(LJ.L("REPORT_SENT_RAID"))
    else
        LJ:Print(LJ.L("REPORT_SENT_GROUP"))
    end
end

local function sendNextLine(currentSession)
    if currentSession ~= session then return end
    local line = table.remove(queue, 1)
    if not line then
        timer = nil
        finishReport()
        return
    end
    pcall(SendChatMessage, line, reportChannel, nil, reportTarget)
    if C_Timer and C_Timer.NewTimer then
        timer = C_Timer.NewTimer(1.0, function()
            pcall(sendNextLine, currentSession)
        end)
    elseif C_Timer and C_Timer.After then
        timer = nil
        C_Timer.After(1.0, function() pcall(sendNextLine, currentSession) end)
    else
        sendNextLine(currentSession)
    end
end

function R:Send(channel, target)
    if not LJ.Stats or not LJ.Tracker then return false end
    if channel == "WHISPER" then
        target = stripName(target)
        if target == "" then target = self:GetTargetName() or "" end
        if target == "" then return false, "REPORT_NO_TARGET" end
        self:Cancel()
        reportChannel, reportTarget = "WHISPER", target
    elseif channel == "PARTY" or channel == "GROUP" then
        local chatChannel, inGroup = groupChat()
        if not inGroup then return false, "REPORT_NO_PARTY" end
        self:Cancel()
        reportChannel, reportTarget = chatChannel, nil
    else
        return false
    end
    queue = self:Build()
    sendNextLine(session)
    return true
end

return R
