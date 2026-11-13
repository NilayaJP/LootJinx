-- LootJinx – kopierbarer Diagnose-Snapshot für Fehlerberichte
local ADDON, ns = ...
local LJ = ns or _G.LootJinx or {}
_G.LootJinx = LJ
if not LJ then return end

local D = {}
LJ.Diagnostics = D

local MAX_EVENTS = 160
local MAX_ITEMS = 40
local REPORT_EVENTS = 10
local REPORT_ITEMS = 8
local REPORT_PENDING = 8

local W = LJ.Widgets
local C = LJ.COLORS
local FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
local WHITE = "Interface\\Buttons\\WHITE8X8"

local function now()
    return LJ.Now and LJ.Now() or 0
end

local function duration(seconds)
    seconds = math.max(0, math.floor(tonumber(seconds) or 0))
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = seconds % 60
    if hours > 0 then
        return string.format("%02d:%02d:%02d", hours, minutes, secs)
    end
    return string.format("%02d:%02d", minutes, secs)
end

local function ago(at)
    at = tonumber(at)
    if not at then return "-" end
    return "-" .. duration(now() - at)
end

local function age(at)
    at = tonumber(at)
    if not at then return "-" end
    return duration(now() - at)
end

local function idText(id)
    id = tonumber(id)
    if not id then return "-" end
    return tostring(math.floor(id))
end

local function boolText(value)
    return value == true and "true" or "false"
end

local function flagText(value)
    if value == true then return "true" end
    if value == false then return "false" end
    return "?"
end

local function append(lines, text)
    lines[#lines + 1] = text
end

local function section(lines, key)
    lines[#lines + 1] = ""
    lines[#lines + 1] = "[" .. tostring(LJ.L(key)) .. "]"
end

function D:Reset()
    self.events = {}
    self.items = {}
    self.counts = {}
    self.startedAt = now()
    self.classified = 0
    self.unknownData = 0
    self.unknownStat = 0
    self.quests = 0
    self.nonLoot = 0
    self.duplicates = 0
end

-- Nur kurze, kontrollierte Zeichenketten speichern. Spielernamen, Chattexte
-- und Whisper-Ziele dürfen hier nicht hineingeraten.
function D:Event(kind, id, detail)
    self.events = self.events or {}
    self.counts = self.counts or {}
    kind = tostring(kind or "?")
    self.counts[kind] = (self.counts[kind] or 0) + 1
    self.events[#self.events + 1] = {
        at = now(),
        kind = kind,
        id = tonumber(id),
        detail = detail and tostring(detail):sub(1, 60) or nil,
    }
    while #self.events > MAX_EVENTS do table.remove(self.events, 1) end
end

function D:NoteDuplicate()
    self.duplicates = (self.duplicates or 0) + 1
end

local function sameDecision(left, id, info, source)
    if not left then return false end
    if left.id ~= id or left.source ~= source then return false end
    return left.known == (info.known == true)
        and left.loot == (info.loot == true)
        and left.quest == (info.quest == true)
        and left.agi == info.agi
        and left.classID == tonumber(info.classID)
end

-- Speichert die Entscheidung ohne Item-Namen oder Link.
function D:NoteItem(id, info, source)
    self.items = self.items or {}
    id = tonumber(id)
    source = tostring(source or "?")
    self.classified = (self.classified or 0) + 1
    if not info then
        self.unknownData = (self.unknownData or 0) + 1
    else
        if info.quest == true then
            self.quests = (self.quests or 0) + 1
        elseif info.known == true and info.loot ~= true then
            self.nonLoot = (self.nonLoot or 0) + 1
        end
        if info.loot == true and info.agi == nil then
            self.unknownStat = (self.unknownStat or 0) + 1
        end
    end

    local last = self.items[#self.items]
    if info and sameDecision(last, id, info, source) and now() - (last.at or 0) <= 2 then
        last.at = now()
        return
    end

    self.items[#self.items + 1] = {
        at = now(),
        id = id,
        source = source,
        known = info and info.known == true or false,
        loot = info and info.loot == true or false,
        quest = info and info.quest == true or false,
        agi = info and info.agi or nil,
        classID = info and tonumber(info.classID) or nil,
    }
    while #self.items > MAX_ITEMS do table.remove(self.items, 1) end
end

local function trackerState()
    if not LJ.Tracker or not LJ.Tracker.GetDiagnosticState then return {} end
    local ok, state = pcall(LJ.Tracker.GetDiagnosticState, LJ.Tracker)
    if ok and type(state) == "table" then return state end
    return {}
end

local function addCharacter(lines)
    local class, classFile = "?", nil
    if LJ.ClassName then
        local ok, value, file = pcall(LJ.ClassName, LJ)
        if ok then class, classFile = value, file end
    end
    local stat, statLabel = "?", nil
    if LJ.PlayerStat then
        local ok, value, label = pcall(LJ.PlayerStat, LJ)
        if ok then stat, statLabel = value, label end
    end
    local layout = "?"
    if LJ.UI and LJ.UI.GetLayout then
        local ok, value = pcall(LJ.UI.GetLayout, LJ.UI)
        if ok then layout = tostring(value) end
    end
    local shown = false
    if LJ.UI and LJ.UI.frame and LJ.UI.frame.IsShown then
        local ok, value = pcall(LJ.UI.frame.IsShown, LJ.UI.frame)
        shown = ok and value == true
    end

    section(lines, "DIAG_SECTION_CHARACTER")
    append(lines, "class=" .. tostring(classFile or class)
        .. " stat=" .. tostring(stat) .. " (" .. tostring(statLabel or "?") .. ")")
    append(lines, "layout=" .. layout
        .. " ui=" .. boolText(LJ.UI ~= nil)
        .. " db=" .. boolText(LJ.dbReady == true)
        .. " details=" .. boolText(LJ.RunDetail ~= nil)
        .. " window=" .. boolText(shown))
end

local function addCopyState(lines, state)
    local run = state.run
    local copy = state.copy or {}
    section(lines, "DIAG_SECTION_COPY")
    append(lines, "inside=" .. boolText(state.inside)
        .. " blocked=" .. boolText(state.blocked)
        .. " live=" .. boolText(state.live)
        .. " paused=" .. boolText(run and run.paused))
    append(lines, "copy=" .. tostring(copy.state or "?")
        .. " runs=" .. tostring(state.runCount or 0)
        .. " lootWindow=" .. boolText(state.lootWindowOpen)
        .. " slots=" .. tostring(state.lootSlots or 0))
    if not run then
        append(lines, "run=none")
    else
        append(lines, "run=" .. idText(run.id)
            .. " name=" .. tostring(run.name or "?")
            .. " key=" .. tostring(run.key or "-")
            .. " instance=" .. tostring(run.instanceID or "-")
            .. " zone=" .. tostring(run.zoneID or "-"))
        append(lines, "closed=" .. boolText(run.closed)
            .. " reason=" .. tostring(run.closedReason or "-")
            .. " provisional=" .. tostring(run.provisionalPreviousID or "-")
            .. " partial=" .. boolText(run.partial))
        append(lines, "age=" .. duration(now() - (tonumber(run.started) or now()))
            .. " lastSeen=" .. ago(run.lastSeen)
            .. " outside=" .. (run.outsideAt and ago(run.outsideAt) or "-"))
        append(lines, "items=" .. tostring(run.itemsSeen or 0)
            .. " statItems=" .. tostring(run.agiItemsSeen or 0)
            .. " lootSeen=" .. boolText(run.lootSeen)
            .. " statLoot=" .. boolText(run.agilityDropped))
        append(lines, "bosses=" .. tostring(run.bosses or 0)
            .. " drops=" .. tostring(run.drops or 0)
            .. " rolls=" .. tostring(run.rolls or 0)
            .. " seenLinks=" .. tostring(run.seenLinks or 0))
        append(lines, "needs=" .. tostring(run.needs or 0)
            .. " won=" .. tostring(run.won or 0)
            .. " lost=" .. tostring(run.lost or 0)
            .. " open=" .. tostring(run.open or 0)
            .. " pending=" .. tostring(run.pendingCount or 0))
    end
    if copy.previousID then
        append(lines, "previous=" .. idText(copy.previousID)
            .. " previousZone=" .. tostring(copy.previousZoneID or "-")
            .. " previousReason=" .. tostring(copy.previousClosedReason or "-"))
    end
end

local function addEvents(lines, self)
    section(lines, "DIAG_SECTION_EVENTS")
    local events = self.events or {}
    if #events == 0 then
        append(lines, "none")
    else
        local first = math.max(1, #events - REPORT_EVENTS + 1)
        for i = first, #events do
            local event = events[i]
            local text = ago(event.at) .. " " .. event.kind
            if event.id then text = text .. " id=" .. idText(event.id) end
            if event.detail then text = text .. " " .. event.detail end
            append(lines, text)
        end
    end

    local kinds = {}
    for kind in pairs(self.counts or {}) do kinds[#kinds + 1] = kind end
    table.sort(kinds)
    if #kinds == 0 then
        append(lines, "counts=none")
    else
        local parts = {}
        for i = 1, #kinds do
            parts[#parts + 1] = kinds[i] .. "=" .. tostring(self.counts[kinds[i]])
        end
        append(lines, "counts=" .. table.concat(parts, " "))
    end
end

local function addPending(lines, run)
    section(lines, "DIAG_SECTION_PENDING")
    local needs = run and run.openNeeds or {}
    if #needs == 0 then
        append(lines, "none")
    else
        local shown = math.min(#needs, REPORT_PENDING)
        for i = 1, shown do
            local need = needs[i]
            append(lines, "id=" .. idText(need.id)
                .. " roll=" .. tostring(need.rollID or "-")
                .. " age=" .. age(need.at)
                .. " link=" .. boolText(need.link)
                .. " value=" .. tostring(need.roll or "-")
                .. " kind=" .. tostring(need.rollKind or "-"))
        end
        if #needs > shown then
            append(lines, "+" .. tostring(#needs - shown) .. " more")
        end
    end

    section(lines, "DIAG_SECTION_QUEUE")
    local pending = run and run.pendingItems or {}
    if #pending == 0 then
        append(lines, "none")
    else
        local shown = math.min(#pending, REPORT_PENDING)
        for i = 1, shown do
            local item = pending[i]
            append(lines, "id=" .. idText(item.id)
                .. " age=" .. age(item.added)
                .. " source=" .. tostring(item.source or "?")
                .. " countedLoot=" .. boolText(item.countedLoot)
                .. " link=" .. boolText(item.link))
        end
        if #pending > shown then
            append(lines, "+" .. tostring(#pending - shown) .. " more")
        end
    end
end

local function addItems(lines, self)
    section(lines, "DIAG_SECTION_ITEMS")
    local items = self.items or {}
    if #items == 0 then
        append(lines, "none")
        return
    end
    local first = math.max(1, #items - REPORT_ITEMS + 1)
    for i = first, #items do
        local item = items[i]
        append(lines, ago(item.at)
            .. " id=" .. idText(item.id)
            .. " src=" .. tostring(item.source or "?")
            .. " known=" .. boolText(item.known)
            .. " loot=" .. boolText(item.loot)
            .. " quest=" .. boolText(item.quest)
            .. " agi=" .. flagText(item.agi)
            .. " class=" .. tostring(item.classID or "-"))
    end
end

local function addSignals(lines, self, state)
    local run = state.run
    local copy = state.copy or {}
    section(lines, "DIAG_SECTION_SIGNALS")
    append(lines, "classified=" .. tostring(self.classified or 0)
        .. " unknownData=" .. tostring(self.unknownData or 0)
        .. " unknownStat=" .. tostring(self.unknownStat or 0)
        .. " quest=" .. tostring(self.quests or 0)
        .. " nonLoot=" .. tostring(self.nonLoot or 0)
        .. " duplicates=" .. tostring(self.duplicates or 0))

    local hints = {}
    if not run then
        hints[#hints + 1] = "no-active-run"
    else
        if (run.drops or 0) == 0 and (run.itemsSeen or 0) == 0 then
            hints[#hints + 1] = "no-loot-event-in-run"
        end
        if (run.drops or 0) > 0 and (run.itemsSeen or 0) == 0 then
            hints[#hints + 1] = "drops-not-counted"
        end
        if (run.pendingCount or 0) > 0 then
            hints[#hints + 1] = "classification-pending"
        end
        if (run.open or 0) > 0 then
            hints[#hints + 1] = "open-needs"
        end
    end
    if copy.state == "pending" then hints[#hints + 1] = "copy-pending" end
    if copy.state == "unconfirmed" then hints[#hints + 1] = "copy-unconfirmed" end
    if copy.state == "blocked" then hints[#hints + 1] = "copy-blocked" end
    if #hints == 0 then hints[#hints + 1] = "no-anomaly-detected" end
    append(lines, "hint=" .. table.concat(hints, ","))
    append(lines, LJ.L("DIAG_PRIVACY"))
end

function D:Build()
    local lines = {}
    local clock = now()
    local version = "?"
    if LJ.AddOnVersion then
        local ok, value = pcall(LJ.AddOnVersion, LJ)
        if ok then version = tostring(value) end
    end
    local dateText = tostring(clock)
    if date then
        local ok, value = pcall(date, "%Y-%m-%d %H:%M:%S", clock)
        if ok and value then dateText = tostring(value) end
    end
    append(lines, "LootJinx " .. version .. " · " .. dateText)
    append(lines, "session=" .. duration(clock - (self.startedAt or clock))
        .. " events=" .. tostring(#(self.events or {}))
        .. " classifications=" .. tostring(self.classified or 0))

    addCharacter(lines)
    local state = trackerState()
    addCopyState(lines, state)
    addEvents(lines, self)
    addPending(lines, state.run)
    addItems(lines, self)
    addSignals(lines, self, state)
    return table.concat(lines, "\n")
end

function D:Print()
    if not LJ.Print then return end
    LJ:Print(LJ.L("DIAG_PRINTED"))
    local text = self:Build()
    for line in (text .. "\n"):gmatch("(.-)\n") do
        if line ~= "" then LJ:Print(line) end
    end
end

local function applyBackdrop(frame)
    if not frame.SetBackdrop then return end
    frame:SetBackdrop({
        bgFile = WHITE,
        edgeFile = WHITE,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    frame:SetBackdropColor(C.bg[1], C.bg[2], C.bg[3], C.bg[4] or 1)
    frame:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 1)
end

local function createWindow()
    if not W or not C or not CreateFrame then return nil end
    local frame = CreateFrame("Frame", "LootJinxDiagnosticsFrame", UIParent,
        BackdropTemplateMixin and "BackdropTemplate" or nil)
    frame:SetSize(580, 470)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    applyBackdrop(frame)

    local accent = frame:CreateTexture(nil, "ARTWORK")
    accent:SetPoint("TOPLEFT", 1, -1)
    accent:SetPoint("TOPRIGHT", -1, -1)
    accent:SetHeight(2)
    W:SetGradient(accent, true, C.accent, C.cyan)

    local title = W:Font(frame, 10, C.accent, "OUTLINE")
    title:SetPoint("TOPLEFT", 18, -12)
    title:SetText(LJ.L("DIAG_TITLE"))

    local sub = W:Font(frame, 9, C.muted, "")
    sub:SetPoint("TOPLEFT", 18, -28)
    sub:SetText(LJ.L("DIAG_SUB"))

    local close = W:Button(frame, "×", 20, 20)
    close:SetPoint("TOPRIGHT", -12, -10)
    close.label:SetFont(FONT, 14, "")
    close.label:SetPoint("CENTER", 0, 1)
    close:SetScript("OnClick", function() frame:Hide() end)

    local edit = CreateFrame("EditBox", nil, frame, BackdropTemplateMixin and "BackdropTemplate" or nil)
    edit:SetSize(548, 350)
    edit:SetPoint("TOPLEFT", 16, -48)
    if edit.SetBackdrop then
        edit:SetBackdrop({
            bgFile = WHITE,
            edgeFile = WHITE,
            edgeSize = 1,
            insets = { left = 2, right = 2, top = 2, bottom = 2 },
        })
        edit:SetBackdropColor(0.04, 0.045, 0.06, 1)
        edit:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 1)
    end
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetMaxLetters(20000)
    edit:SetFont(FONT, 9, "")
    edit:SetTextColor(C.text[1], C.text[2], C.text[3])
    edit:SetTextInsets(10, 10, 10, 10)
    edit:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        frame:Hide()
    end)
    frame:SetScript("OnHide", function() edit:ClearFocus() end)

    local refresh = W:Button(frame, LJ.L("DIAG_REFRESH"), 110, 22)
    refresh:SetPoint("BOTTOMLEFT", 16, 14)
    refresh:SetScript("OnClick", function() D:Refresh() end)

    local selectAll = W:Button(frame, LJ.L("DIAG_SELECT"), 130, 22)
    selectAll:SetPoint("BOTTOMLEFT", 134, 14)
    selectAll:SetScript("OnClick", function()
        edit:SetFocus()
        if edit.HighlightText then edit:HighlightText() end
    end)

    local print = W:Button(frame, LJ.L("DIAG_PRINT"), 130, 22)
    print:SetPoint("BOTTOMLEFT", 272, 14)
    print:SetScript("OnClick", function() D:Print() end)

    local closeButton = W:Button(frame, LJ.L("DIAG_CLOSE"), 90, 22)
    closeButton:SetPoint("BOTTOMRIGHT", -16, 14)
    closeButton:SetScript("OnClick", function() frame:Hide() end)

    if UISpecialFrames then
        local found = false
        for _, name in ipairs(UISpecialFrames) do
            if name == "LootJinxDiagnosticsFrame" then found = true break end
        end
        if not found then UISpecialFrames[#UISpecialFrames + 1] = "LootJinxDiagnosticsFrame" end
    end

    D.frame = frame
    D.edit = edit
    return frame
end

function D:Create()
    if self.frame then return self.frame end
    local ok, frame = pcall(createWindow)
    if not ok then return nil end
    return frame
end

function D:Refresh()
    if not self.edit then return nil end
    local text = self:Build()
    self.edit:SetText(text)
    if self.edit.SetCursorPosition then self.edit:SetCursorPosition(0) end
    return text
end

function D:Show()
    local frame = self:Create()
    if not frame then
        self:Print()
        return
    end
    self:Refresh()
    frame:Show()
    if self.edit then
        self.edit:SetFocus()
        if self.edit.HighlightText then self.edit:HighlightText() end
    end
end

function D:Hide()
    if self.frame then self.frame:Hide() end
end

D:Reset()

return D
