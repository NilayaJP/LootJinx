-- LootJinx: shared report building and chat delivery for both layouts.
local ADDON, ns = ...
local LJ = ns or _G.LootJinx
if not LJ then return end

local R = {}
LJ.Report = R

local REPORT_DELAY = 0.6
local queue = {}
local timer
local session = 0
local reportChannel, reportTarget, reportDisplay

local function stripName(value)
    return tostring(value or ""):match("^%s*(.-)%s*$") or ""
end

local function targetPlayer()
    if type(UnitIsPlayer) ~= "function" then return nil end
    local okP, isPlayer = pcall(UnitIsPlayer, "target")
    if not okP or LJ.Plain(isPlayer) ~= true then return nil end
    return LJ:UnitCharacterName("target")
end

local function faction(unit)
    if type(UnitFactionGroup) ~= "function" then return nil end
    local ok, value = pcall(UnitFactionGroup, unit)
    value = ok and LJ.Plain(value) or nil
    if value == "Alliance" or value == "Horde" then return value end
    return nil
end

local function bnetFriend(battleTag, name, targetGUID)
    if not battleTag and not targetGUID then return nil end
    if type(BNGetNumFriends) ~= "function" or not C_BattleNet
        or type(C_BattleNet.GetFriendAccountInfo) ~= "function" then return nil end
    local ok, count = pcall(BNGetNumFriends)
    count = ok and tonumber(LJ.Plain(count)) or 0
    local matchID, matchTag
    for i = 1, math.min(count, 500) do
        local found, info = pcall(C_BattleNet.GetFriendAccountInfo, i)
        if found and type(info) == "table" then
            local tag = LJ.Plain(info.battleTag)
            local game = info.gameAccountInfo
            local same = type(tag) == "string" and battleTag and tag:lower() == battleTag:lower()
            if not same and name and type(game) == "table" and LJ.Plain(game.isOnline) == true then
                local friendGUID = LJ.Plain(game.playerGuid)
                same = LJ:SamePlayerName(name, game.characterName)
                    and LJ.Plain(game.isInCurrentRegion) ~= false
                    and targetGUID == friendGUID
            end
            local id = tonumber(LJ.Plain(info.bnetAccountID))
            if same and id and type(tag) == "string" then
                if matchID and matchID ~= id then return nil end
                matchID, matchTag = id, tag
            end
        end
    end
    return matchID, matchTag
end

local function targetGUID()
    if type(UnitGUID) ~= "function" then return nil end
    local ok, guid = pcall(UnitGUID, "target")
    guid = ok and LJ.Plain(guid) or nil
    return type(guid) == "string" and guid ~= "" and guid or nil
end

function R:GetTargetName()
    local fullName = targetPlayer()
    if not fullName then return nil end
    if faction("target") == faction("player") and faction("player") then return fullName end
    local _, tag = bnetFriend(nil, fullName, targetGUID())
    return tag
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
    return {
        LJ.L("REPORT_LINE_HEADER", className),
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

local function isGroupReport()
    return reportChannel == "PARTY" or reportChannel == "RAID"
end

local rosterFrame = CreateFrame and CreateFrame("Frame")
if rosterFrame then
    rosterFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    rosterFrame:SetScript("OnEvent", function()
        if isGroupReport() and #queue > 0 then
            R:Cancel()
            LJ:Print(LJ.L("REPORT_SEND_FAILED"))
        end
    end)
end

local function finishReport()
    if reportChannel == "WHISPER" then
        LJ:Print(LJ.L("REPORT_SENT_WHISPER", reportDisplay or reportTarget or "?"))
    elseif reportChannel == "BN_WHISPER" then
        LJ:Print(LJ.L("REPORT_SENT_BNET", reportDisplay or "?"))
    elseif reportChannel == "RAID" then
        LJ:Print(LJ.L("REPORT_SENT_RAID"))
    else
        LJ:Print(LJ.L("REPORT_SENT_GROUP"))
    end
end

local function sendNextLine(currentSession)
    if currentSession ~= session then return false end
    local line = table.remove(queue, 1)
    if not line then
        timer = nil
        finishReport()
        return true
    end
    if isGroupReport() then
        local channel, inGroup = groupChat()
        if not inGroup or channel ~= reportChannel then
            queue, timer = {}, nil
            return false
        end
    end
    local sent, accepted
    if reportChannel == "BN_WHISPER" then
        local whisper = C_BattleNet and C_BattleNet.SendWhisper
        if type(whisper) ~= "function" then whisper = BNSendWhisper end
        if type(whisper) ~= "function" then return false end
        -- The documented API returns nothing; only an explicit false is a refusal.
        sent, accepted = pcall(whisper, reportTarget, line)
        sent = sent and accepted ~= false
    else
        local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
        sent = pcall(send, line, reportChannel, nil, reportTarget)
    end
    if not sent then
        queue = {}
        timer = nil
        return false
    end
    if C_Timer and C_Timer.NewTimer then
        timer = C_Timer.NewTimer(REPORT_DELAY, function()
            local ok, delivered = pcall(sendNextLine, currentSession)
            if currentSession == session and (not ok or not delivered) then
                LJ:Print(LJ.L("REPORT_SEND_FAILED"))
            end
        end)
    elseif C_Timer and C_Timer.After then
        timer = nil
        C_Timer.After(REPORT_DELAY, function()
            local ok, delivered = pcall(sendNextLine, currentSession)
            if currentSession == session and (not ok or not delivered) then
                LJ:Print(LJ.L("REPORT_SEND_FAILED"))
            end
        end)
    else
        if #queue == 0 then
            timer = nil
            finishReport()
            return true
        end
        queue, timer = {}, nil
        LJ:Print(LJ.L("REPORT_SEND_FAILED"))
        return false
    end
    return true
end

function R:Send(channel, target)
    if not LJ.Stats or not LJ.Tracker then return false end
    if channel == "WHISPER" then
        target = stripName(target)
        if target == "" then target = self:GetTargetName() or "" end
        if target == "" then
            if targetPlayer() then return false, "REPORT_OPPOSITE_FACTION" end
            return false, "REPORT_NO_TARGET"
        end
        local resolvedChannel, resolvedTarget, display
        if target:find("#", 1, true) then
            resolvedTarget, display = bnetFriend(target)
            if not resolvedTarget then return false, "REPORT_BNET_NOT_FRIEND" end
            resolvedChannel = "BN_WHISPER"
        else
            local current = targetPlayer()
            if not current or target:lower() ~= current:lower() then
                return false, "REPORT_UNVERIFIED_TARGET"
            end
            if faction("target") == faction("player") and faction("player") then
                resolvedChannel, resolvedTarget, display = "WHISPER", current, current
            else
                resolvedTarget, display = bnetFriend(nil, current, targetGUID())
                if not resolvedTarget then return false, "REPORT_OPPOSITE_FACTION" end
                resolvedChannel = "BN_WHISPER"
            end
        end
        self:Cancel()
        reportChannel, reportTarget, reportDisplay = resolvedChannel, resolvedTarget, display
    elseif channel == "PARTY" or channel == "GROUP" then
        local chatChannel, inGroup = groupChat()
        if not inGroup then return false, "REPORT_NO_PARTY" end
        self:Cancel()
        reportChannel, reportTarget, reportDisplay = chatChannel, nil, nil
    else
        return false
    end
    queue = self:Build()
    if not sendNextLine(session) then return false, "REPORT_SEND_FAILED" end
    return true
end

return R
