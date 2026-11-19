-- LootJinx – rulesetweites Leaderboard: Daten, Protokoll und Transport
local ADDON, ns = ...
local LJ = ns or _G.LootJinx or {}
_G.LootJinx = LJ

local L = {}
LJ.Leaderboard = L

local PREFIX = "LootJinx"
local PROTOCOL = "LJ1"
local CHANNEL_PASSWORD = "LootJinx"
local TTL = 30 * 86400
local MAX_PEERS = 500
local ONLINE_WINDOW = 15 * 60
local MIN_DECIDED = 10
local TOP_N = 50
local MAX_MESSAGE = 240
local MAX_NAME = 32
local MAX_REALM = 24
local SEND_INTERVAL = 1
local RETRY_DELAY = 3
local MAX_ATTEMPTS = 5
local RESEND_INTERVAL = 600
local REPLY_COOLDOWN = 600

L.PREFIX = PREFIX
L.PROTOCOL = PROTOCOL
L.CHANNEL_PASSWORD = CHANNEL_PASSWORD
L.TTL = TTL
L.MAX_PEERS = MAX_PEERS
L.ONLINE_WINDOW = ONLINE_WINDOW
L.MIN_DECIDED = MIN_DECIDED
L.TOP_N = TOP_N
L.SEND_INTERVAL = SEND_INTERVAL
L.RETRY_DELAY = RETRY_DELAY
L.MAX_ATTEMPTS = MAX_ATTEMPTS
L.RESEND_INTERVAL = RESEND_INTERVAL
L.REPLY_COOLDOWN = REPLY_COOLDOWN

local function clean(value, maxLen)
    value = tostring(value or "")
    value = value:gsub("[%c|]", " ")
    value = value:gsub("%s+", " ")
    value = value:match("^%s*(.-)%s*$") or ""
    if maxLen and #value > maxLen then value = value:sub(1, maxLen) end
    return value
end

local function count(value, max)
    value = tonumber(value) or 0
    if value ~= value then value = 0 end
    value = math.floor(value)
    if value < 0 then value = 0 end
    if max and value > max then value = max end
    return value
end

local function sortName(a, b)
    local an, bn = a.name:lower(), b.name:lower()
    if an ~= bn then return an < bn end
    return a.realm:lower() < b.realm:lower()
end

function L:Board()
    if not LJ.DB then return { peers = {} } end
    local board = LJ.DB.leaderboard
    if type(board) ~= "table" then
        board = {}
        LJ.DB.leaderboard = board
    end
    if type(board.peers) ~= "table" then board.peers = {} end
    board.lastSentAt = tonumber(board.lastSentAt) or 0
    return board
end

function L:Key(name, realm)
    return (clean(name, MAX_NAME) .. "-" .. clean(realm, MAX_REALM)):lower()
end

function L:RulesetName()
    if C_GameRules and type(C_GameRules.IsGameRuleActive) == "function" and Enum and Enum.GameRule then
        local R = Enum.GameRule
        local function on(rule)
            local ok, val = pcall(C_GameRules.IsGameRuleActive, rule)
            return ok and val == true
        end
        if on(R.HardcoreRuleset) then return "Hardcore" end
        local pvp, rp = on(R.PvPRuleset), on(R.RPRuleset)
        if pvp and rp then return "RP-PvP" end
        if pvp then return "PvP" end
        if rp then return "RP" end
        return "PvE"
    end
    if type(GetRealmName) == "function" then
        local ok, r = pcall(GetRealmName)
        if ok and type(r) == "string" and r ~= "" then return r end
    end
    return "PvE"
end

function L:Identity()
    local name, surname
    if type(UnitName) == "function" then
        local ok, n, s = pcall(UnitName, "player")
        if ok then name, surname = n, s end
    end
    name = clean(name, MAX_NAME)
    surname = clean(surname, MAX_NAME)
    local fullName = name
    if surname ~= "" and not name:find("%s") then
        fullName = clean(name .. " " .. surname, MAX_NAME)
    end
    local realm = self:RulesetName()
    return fullName, clean(realm, MAX_REALM)
end

function L:IsSelf(name, realm)
    local mine, myRealm = self:Identity()
    name, realm = clean(name, MAX_NAME), clean(realm, MAX_REALM)
    if name == "" then return false end
    local n1, n2 = name:lower(), mine:lower()
    local matchName = (n1 == n2)
    if not matchName then
        local first1 = n1:match("^(%S+)")
        local first2 = n2:match("^(%S+)")
        if first1 and first2 and first1 == first2 then
            matchName = true
        end
    end
    if not matchName then return false end
    return realm == "" or myRealm == "" or realm:lower() == myRealm:lower()
end

function L:Snapshot()
    local name, realm = self:Identity()
    local _, class = nil, nil
    if type(UnitClass) == "function" then
        local ok, _, c = pcall(UnitClass, "player")
        if ok then class = c end
    end
    local faction = "Neutral"
    if type(UnitFactionGroup) == "function" then
        local ok, f = pcall(UnitFactionGroup, "player")
        if ok and type(f) == "string" then faction = f end
    end
    local runs = {}
    if LJ.Tracker and LJ.Tracker.GetRuns then
        local ok, value = pcall(LJ.Tracker.GetRuns, LJ.Tracker)
        if ok and type(value) == "table" then runs = value end
    end
    local stats = {}
    if LJ.Stats and LJ.Stats.Compute then stats = LJ.Stats.Compute(runs) end
    return {
        name = name,
        realm = realm,
        class = clean(tostring(class or "UNKNOWN"), 16):upper(),
        faction = clean(faction, 16),
        wins = count(stats.needWins, 10000000),
        losses = count(stats.needLost, 10000000),
        streak = count(stats.lostNeedMax, 10000000),
        ts = count(time(), 4000000000),
    }
end

function L:Init()
    if not LJ.DB then return false end
    local board = self:Board()
    local old = {}
    for key, peer in pairs(board.peers) do old[#old + 1] = { key = key, peer = peer } end
    board.peers = {}
    for _, item in ipairs(old) do
        local peer = item.peer
        if type(peer) == "table" then
            local name = clean(peer.name, MAX_NAME)
            local realm = clean(peer.realm, MAX_REALM)
            if name ~= "" then
                board.peers[self:Key(name, realm)] = {
                    name = name,
                    realm = realm,
                    class = clean(peer.class, 16):upper(),
                    faction = clean(peer.faction, 16),
                    wins = count(peer.wins, 10000000),
                    losses = count(peer.losses, 10000000),
                    streak = count(peer.streak, 10000000),
                    seenAt = count(peer.seenAt, 4000000000),
                }
            end
        end
    end
    self:Prune()
    return true
end

function L:UpsertPeer(peer, seenAt)
    if type(peer) ~= "table" then return nil end
    local name = clean(peer.name, MAX_NAME)
    local realm = clean(peer.realm, MAX_REALM)
    if name == "" or self:IsSelf(name, realm) then return nil end
    local entry = {
        name = name,
        realm = realm,
        class = clean(peer.class or "UNKNOWN", 16):upper(),
        faction = clean(peer.faction or "Neutral", 16),
        wins = count(peer.wins, 10000000),
        losses = count(peer.losses, 10000000),
        streak = count(peer.streak, 10000000),
        seenAt = count(seenAt or time(), 4000000000),
    }
    self:Board().peers[self:Key(name, realm)] = entry
    self:Prune(entry.seenAt)
    return entry
end

function L:Prune(now)
    now = tonumber(now) or time()
    local board = self:Board()
    local live = {}
    for key, peer in pairs(board.peers) do
        if type(peer) ~= "table" or now - (tonumber(peer.seenAt) or 0) > TTL then
            board.peers[key] = nil
        else
            live[#live + 1] = { key = key, seenAt = tonumber(peer.seenAt) or 0 }
        end
    end
    if #live > MAX_PEERS then
        table.sort(live, function(a, b) return a.seenAt < b.seenAt end)
        for i = 1, #live - MAX_PEERS do board.peers[live[i].key] = nil end
    end
end

function L:Entries(now)
    now = tonumber(now) or time()
    local board = self:Board()
    local list = {}
    for _, peer in pairs(board.peers) do
        if now - (tonumber(peer.seenAt) or 0) <= TTL then
            local decided = peer.wins + peer.losses
            list[#list + 1] = {
                name = peer.name,
                realm = peer.realm,
                class = peer.class,
                faction = peer.faction,
                wins = peer.wins,
                losses = peer.losses,
                streak = peer.streak,
                seenAt = peer.seenAt,
                decided = decided,
                online = (now - peer.seenAt) <= ONLINE_WINDOW,
                isSelf = false,
            }
        end
    end
    local snapshot = self:Snapshot()
    if snapshot.name ~= "" then
        local key = self:Key(snapshot.name, snapshot.realm)
        for i = #list, 1, -1 do
            if self:Key(list[i].name, list[i].realm) == key then table.remove(list, i) end
        end
        list[#list + 1] = {
            name = snapshot.name,
            realm = snapshot.realm,
            class = snapshot.class,
            faction = snapshot.faction,
            wins = snapshot.wins,
            losses = snapshot.losses,
            streak = snapshot.streak,
            seenAt = now,
            decided = snapshot.wins + snapshot.losses,
            online = true,
            isSelf = true,
        }
    end
    return list
end

function L:Ranking(mode, now)
    if mode ~= "quote" and mode ~= "streak" then mode = "wins" end
    local list = self:Entries(now)
    for _, entry in ipairs(list) do
        if entry.decided >= MIN_DECIDED then
            entry.quote = entry.wins / entry.decided
        else
            entry.quote = nil
        end
    end
    if mode == "quote" then
        table.sort(list, function(a, b)
            if (a.quote == nil) ~= (b.quote == nil) then return a.quote ~= nil end
            if a.quote and b.quote and a.quote ~= b.quote then return a.quote > b.quote end
            if a.wins ~= b.wins then return a.wins > b.wins end
            return sortName(a, b)
        end)
    elseif mode == "streak" then
        table.sort(list, function(a, b)
            if a.streak ~= b.streak then return a.streak > b.streak end
            if a.losses ~= b.losses then return a.losses > b.losses end
            return sortName(a, b)
        end)
    else
        table.sort(list, function(a, b)
            if a.wins ~= b.wins then return a.wins > b.wins end
            if a.losses ~= b.losses then return a.losses < b.losses end
            return sortName(a, b)
        end)
    end
    for i, entry in ipairs(list) do entry.rank = i end
    return list
end

-- ---------------------------------------------------------------- Protokoll

local function splitFields(message)
    local fields = {}
    for part in (message .. "|"):gmatch("([^|]*)|") do
        fields[#fields + 1] = part
    end
    return fields
end

function L:Encode(snapshot)
    snapshot = snapshot or self:Snapshot()
    if type(snapshot) ~= "table" then return nil end
    local name = clean(snapshot.name, MAX_NAME)
    if name == "" then return nil end
    local message = table.concat({
        PROTOCOL,
        name,
        clean(snapshot.realm, MAX_REALM),
        clean(snapshot.class or "UNKNOWN", 16):upper(),
        clean(snapshot.faction or "Neutral", 16),
        tostring(count(snapshot.wins, 10000000)),
        tostring(count(snapshot.losses, 10000000)),
        tostring(count(snapshot.streak, 10000000)),
        tostring(count(snapshot.ts or time(), 4000000000)),
    }, "|")
    if #message > MAX_MESSAGE then return nil end
    return message
end

function L:Decode(message, sender)
    if type(message) ~= "string" or #message > MAX_MESSAGE then return nil end
    local fields = splitFields(message)
    if #fields ~= 9 or fields[1] ~= PROTOCOL then return nil end
    local wins = tonumber(fields[6])
    local losses = tonumber(fields[7])
    local streak = tonumber(fields[8])
    local ts = tonumber(fields[9])
    if not wins or not losses or not streak or not ts then return nil end

    local senderName, senderRealm = tostring(sender or ""):match("^([^%-]+)%-(.+)$")
    if not senderName then senderName = tostring(sender or "") end
    local name = clean(senderName, MAX_NAME)
    if name == "" then name = clean(fields[2], MAX_NAME) end
    if name == "" then return nil end
    local realm = clean(fields[3], MAX_REALM)
    if realm == "" and senderRealm and senderRealm ~= "" then realm = clean(senderRealm, MAX_REALM) end
    if realm == "" then realm = "PvE" end

    local class = clean(fields[4], 16):upper()
    if class == "" or not class:match("^[A-Z_]+$") then class = "UNKNOWN" end
    local faction = clean(fields[5], 16)
    if faction ~= "Alliance" and faction ~= "Horde" and faction ~= "Neutral" then
        faction = "Neutral"
    end
    return {
        name = name,
        realm = realm,
        class = class,
        faction = faction,
        wins = count(wins, 10000000),
        losses = count(losses, 10000000),
        streak = count(streak, 10000000),
        ts = count(ts, 4000000000),
    }
end

function L:HandleMessage(message, sender, now, channel)
    local peer = self:Decode(message, sender)
    if not peer then return nil end
    now = tonumber(now) or time()
    local entry = self:UpsertPeer(peer, now)
    if not entry then return nil end
    if channel == nil then channel = "WHISPER" end
    if channel == "WHISPER" and self.Queue and self:Consent() == true then
        local key = self:Key(entry.name, entry.realm)
        self.replied = self.replied or {}
        local target = clean(sender, 64)
        if target ~= "" and now - (tonumber(self.replied[key]) or 0) >= REPLY_COOLDOWN then
            self.replied[key] = now
            local snapshot = self:Encode(self:Snapshot())
            if snapshot then self:Queue(target, "WHISPER", snapshot) end
        end
    end
    return entry
end

function L:OnAddonMessage(prefix, message, channel, sender)
    if prefix ~= PREFIX then return end
    self:HandleMessage(message, sender, time(), channel)
end

-- ---------------------------------------------------------------- Consent

function L:Consent()
    if not LJ.DB then return nil end
    local value = LJ.DB.leaderboardConsent
    if value == true or value == false then return value end
    return nil
end

function L:StatusText()
    local consent = self:Consent()
    local label
    if consent == true then
        label = LJ.L("LEADERBOARD_STATUS_ON")
    elseif consent == false then
        label = LJ.L("LEADERBOARD_STATUS_OFF")
    else
        label = LJ.L("LEADERBOARD_STATUS_PENDING")
    end
    local seen, online = 0, 0
    local now = time()
    for _, peer in pairs(self:Board().peers) do
        if now - (tonumber(peer.seenAt) or 0) <= TTL then
            seen = seen + 1
            if now - (tonumber(peer.seenAt) or 0) <= ONLINE_WINDOW then
                online = online + 1
            end
        end
    end
    local send = C_ChatInfo and C_ChatInfo.SendAddonMessage
    if type(send) ~= "function" then
        return label .. "  " .. LJ.L("LEADERBOARD_STATUS_UNAVAILABLE")
    end
    return label .. "  " .. LJ.L("LEADERBOARD_STATUS_PEERS", seen, online)
end

function L:SetConsent(value)
    if not LJ.DB then return false end
    value = value == true
    local changed = LJ.DB.leaderboardConsent ~= value
    LJ.DB.leaderboardConsent = value
    if value then
        if self.Enable then pcall(self.Enable, self) end
        if self.StartTicker then pcall(self.StartTicker, self) end
    else
        if self.Disable then pcall(self.Disable, self) end
    end
    if changed then
        LJ:Print(LJ.L(value and "CONSENT_CHANGED_ON" or "CONSENT_CHANGED_OFF"))
    end
    if LJ.Options and LJ.Options.Refresh then pcall(LJ.Options.Refresh, LJ.Options) end
    if LJ.Changed then LJ:Changed() end
    return true
end

function L:ShowConsentPrompt()
    if not LJ.DB or self:Consent() ~= nil then return false end
    if not StaticPopupDialogs or not StaticPopup_Show then return false end
    self.promptCount = (self.promptCount or 0) + 1
    StaticPopupDialogs["LOOTJINX_LEADERBOARD_CONSENT"] = {
        text = LJ.L("CONSENT_TEXT"),
        button1 = LJ.L("CONSENT_ACCEPT"),
        button2 = LJ.L("CONSENT_DECLINE"),
        OnAccept = function()
            L:SetConsent(true)
            L:ShowTestNotice()
        end,
        OnCancel = function() L:SetConsent(false) end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = false,
        preferredIndex = 3,
    }
    StaticPopup_Show("LOOTJINX_LEADERBOARD_CONSENT")
    return true
end

function L:TestNoticeAck()
    if not LJ.DB then return false end
    return LJ.DB.leaderboardTestAck == true
end

function L:SetTestNoticeAck(value)
    if not LJ.DB then return false end
    LJ.DB.leaderboardTestAck = (value == true) or nil
    return true
end

function L:ShowTestNotice()
    if not LJ.DB or self:TestNoticeAck() then return false end
    if not StaticPopupDialogs or not StaticPopup_Show then return false end
    self.testNoticePromptCount = (self.testNoticePromptCount or 0) + 1
    StaticPopupDialogs["LOOTJINX_LEADERBOARD_TEST_NOTICE"] = {
        text = LJ.L("LEADERBOARD_TEST_NOTICE"),
        button1 = LJ.L("LEADERBOARD_TEST_ACK"),
        OnAccept = function()
            L:SetTestNoticeAck(true)
        end,
        OnCancel = function()
            L:SetTestNoticeAck(true)
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
    StaticPopup_Show("LOOTJINX_LEADERBOARD_TEST_NOTICE")
    return true
end

function L:MaybePrompt()
    if self:Consent() ~= nil then return false end
    if C_Timer and C_Timer.After then
        C_Timer.After(6, function() L:ShowConsentPrompt() end)
        return true
    end
    return self:ShowConsentPrompt()
end

-- ---------------------------------------------------------------- Transport

local function callBool(name)
    local fn = _G[name]
    if type(fn) ~= "function" then return false end
    local ok, value = pcall(fn)
    return ok and value == true
end

function L:ChannelName()
    local faction = "Alliance"
    if type(UnitFactionGroup) == "function" then
        local ok, value = pcall(UnitFactionGroup, "player")
        if ok and value == "Horde" then faction = "Horde" end
    end
    return "LootJinx-" .. faction
end

function L:JoinChannel()
    if self:Consent() ~= true then return false end
    local join = _G.JoinTemporaryChannel
    if type(join) ~= "function" then
        self.channelAvailable = false
        return false
    end
    local ok = pcall(join, self:ChannelName(), CHANNEL_PASSWORD)
    self.channelAvailable = ok
    self.channelJoined = ok
    return ok
end

function L:LeaveChannel()
    local leave = _G.LeaveChannelByName
    if type(leave) == "function" then pcall(leave, self:ChannelName()) end
    self.channelJoined = false
end

function L:RosterTargets()
    local targets = {}
    if type(GetChannelName) ~= "function" or type(GetChannelRosterInfo) ~= "function" then
        return targets
    end
    local ok, index = pcall(GetChannelName, self:ChannelName())
    if not ok or type(index) ~= "number" or index <= 0 then return targets end
    for i = 1, 200 do
        local good, name = pcall(GetChannelRosterInfo, index, i)
        if not good or type(name) ~= "string" or name == "" then break end
        if not self:IsSelf(name, "") then
            targets[#targets + 1] = clean(name, 64)
        end
    end
    return targets
end

function L:Send(item)
    if self:Consent() ~= true then return false end
    local send = C_ChatInfo and C_ChatInfo.SendAddonMessage
    if type(send) ~= "function" then return false end
    local ok, result = pcall(send, PREFIX, item.message, item.channel, item.target)
    if not ok or result == false then return false end
    if type(result) == "number" then return result == 0 end
    return true
end

function L:Pump()
    if self.pumping then return end
    self.queue = self.queue or {}
    if #self.queue == 0 then return end
    if self:Consent() ~= true then
        self.queue = {}
        return
    end
    self.pumping = true
    local item = table.remove(self.queue, 1)
    local sent = self:Send(item)
    if not sent and item.attempts < MAX_ATTEMPTS then
        item.attempts = item.attempts + 1
        table.insert(self.queue, 1, item)
        if C_Timer and C_Timer.After then
            C_Timer.After(RETRY_DELAY, function()
                self.pumping = false
                self:Pump()
            end)
        else
            self.pumping = false
        end
        return
    end
    if C_Timer and C_Timer.After then
        C_Timer.After(SEND_INTERVAL, function()
            self.pumping = false
            self:Pump()
        end)
    else
        self.pumping = false
    end
end

function L:Queue(target, channel, message)
    if self:Consent() ~= true or type(message) ~= "string" or message == "" then
        return false
    end
    self.queue = self.queue or {}
    self.queue[#self.queue + 1] = {
        target = target,
        channel = channel,
        message = message,
        attempts = 0,
    }
    self:Pump()
    return true
end

function L:Broadcast(reason)
    if self:Consent() ~= true then return false end
    local snapshot = self:Snapshot()
    local message = self:Encode(snapshot)
    if not message then return false end
    local key = table.concat({
        snapshot.name, snapshot.realm, snapshot.wins, snapshot.losses, snapshot.streak,
    }, "|")
    local now = time()
    local force = reason == "manual" or reason == "login" or reason == "roster"
    if not force and key == self.lastSnapshotKey
        and now - (self.lastBroadcastAt or 0) < RESEND_INTERVAL then
        return false
    end
    self.lastSnapshotKey = key
    self.lastBroadcastAt = now
    self:Board().lastSentAt = now

    local targets = self:RosterTargets()
    if #targets > 0 then
        for _, target in ipairs(targets) do
            self:Queue(target, "WHISPER", message)
        end
        return true
    end
    if callBool("IsInGuild") then
        self:Queue(nil, "GUILD", message)
        return true
    end
    if callBool("IsInGroup") then
        local channel = callBool("IsInRaid") and "RAID" or "PARTY"
        self:Queue(nil, channel, message)
        return true
    end
    return false
end

function L:Enable()
    if self:Consent() ~= true then return false end
    self:JoinChannel()
    return self:Broadcast("login")
end

function L:Disable()
    self:LeaveChannel()
    self.queue = {}
    self.pumping = false
    self.lastSnapshotKey = nil
    if self.ticker and self.ticker.Cancel then self.ticker:Cancel() end
    self.ticker = nil
end

function L:StartTicker()
    if self.ticker or not C_Timer or not C_Timer.NewTicker then return end
    self.ticker = C_Timer.NewTicker(RESEND_INTERVAL, function()
        L:Broadcast("tick")
    end)
end

function L:OnLogin()
    if not LJ.DB then return end
    self:Init()
    if not self.refreshHooked and LJ.RegisterRefresh then
        self.refreshHooked = true
        LJ:RegisterRefresh(function()
            if L:Consent() ~= true or L.broadcastQueued then return end
            L.broadcastQueued = true
            if C_Timer and C_Timer.After then
                C_Timer.After(3, function()
                    L.broadcastQueued = false
                    L:Broadcast("stats")
                end)
            else
                L.broadcastQueued = false
                L:Broadcast("stats")
            end
        end)
    end
    if self:Consent() == nil then
        self:MaybePrompt()
        return
    end
    if self:Consent() ~= true then return end
    local function start()
        L:Enable()
        L:StartTicker()
    end
    if C_Timer and C_Timer.After then
        C_Timer.After(5, start)
    else
        start()
    end
    if not self:TestNoticeAck() then
        if C_Timer and C_Timer.After then
            C_Timer.After(8, function() L:ShowTestNotice() end)
        else
            L:ShowTestNotice()
        end
    end
end

function L:OnRosterUpdate()
    if self:Consent() ~= true then return end
    if self.rosterQueued then return end
    self.rosterQueued = true
    local function run()
        self.rosterQueued = false
        self:Broadcast("roster")
    end
    if C_Timer and C_Timer.After then
        C_Timer.After(2, run)
    else
        run()
    end
end

function L:RegisterPrefix()
    local register = C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix
    if type(register) == "function" then pcall(register, PREFIX) end
end

local frame = CreateFrame and CreateFrame("Frame") or nil
if frame then
    L.frame = frame
    frame:RegisterEvent("CHAT_MSG_ADDON")
    frame:RegisterEvent("CHANNEL_ROSTER_UPDATE")
    frame:RegisterEvent("CHANNEL_COUNT_UPDATE")
    frame:RegisterEvent("PLAYER_LOGIN")
    frame:SetScript("OnEvent", function(_, event, ...)
        if event == "CHAT_MSG_ADDON" then
            L:OnAddonMessage(...)
        elseif event == "CHANNEL_ROSTER_UPDATE" or event == "CHANNEL_COUNT_UPDATE" then
            L:OnRosterUpdate()
        elseif event == "PLAYER_LOGIN" then
            L:OnLogin()
        end
    end)
end
L:RegisterPrefix()
