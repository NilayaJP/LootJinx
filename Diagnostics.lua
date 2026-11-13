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
local CLASSIC = LJ.COLORS or {}
local FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
local WHITE = "Interface\\Buttons\\WHITE8X8"

local JOURNAL = {
    bg = { 0.141, 0.102, 0.102, 0.98 },
    card = { 0.190, 0.145, 0.133, 0.98 },
    border = { 0.545, 0.384, 0.267, 1 },
    accent = { 0.918, 0.769, 0.494, 1 },
    text = { 0.906, 0.835, 0.729, 1 },
    muted = { 0.690, 0.608, 0.510, 1 },
    inset = { 0.114, 0.086, 0.082, 0.96 },
}

local palettes = {
    classic = {
        bg = CLASSIC.bg,
        card = CLASSIC.card,
        border = CLASSIC.border,
        accent = CLASSIC.accent,
        cyan = CLASSIC.cyan,
        text = CLASSIC.text,
        muted = CLASSIC.muted,
        editBg = { 0.040, 0.045, 0.060, 1 },
        editBorder = CLASSIC.border,
        buttonBg = { 0.100, 0.110, 0.140, 0.96 },
        titleFont = FONT,
        titleSize = 10,
        titleFlags = "OUTLINE",
        titleColor = CLASSIC.accent,
    },
    journal = {
        bg = JOURNAL.bg,
        card = JOURNAL.card,
        border = JOURNAL.border,
        accent = JOURNAL.accent,
        cyan = JOURNAL.text,
        text = JOURNAL.text,
        muted = JOURNAL.muted,
        editBg = JOURNAL.inset,
        editBorder = JOURNAL.border,
        buttonBg = JOURNAL.inset,
        titleFont = "Fonts\\MORPHEUS.TTF",
        titleSize = 14,
        titleFlags = "",
        titleColor = JOURNAL.accent,
    },
}

local function currentTheme()
    local ui = LJ.UI
    if ui and ui.GetLayout then
        local ok, value = pcall(ui.GetLayout, ui)
        if ok and value == "journal" then return "journal" end
    end
    return "classic"
end

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
    local history = state.lootHistory or {}
    append(lines, "copy=" .. tostring(copy.state or "?")
        .. " runs=" .. tostring(state.runCount or 0)
        .. " lootWindow=" .. boolText(state.lootWindowOpen)
        .. " slots=" .. tostring(state.lootSlots or 0))
    append(lines, "lootHistory=" .. tostring(history.drops or 0)
        .. " historyRolls=" .. tostring(history.rolls or 0))
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
        local history = type(run.statHistory) == "table" and table.concat(run.statHistory, ">") or "-"
        append(lines, "stat=" .. tostring(run.stat or "-")
            .. " history=" .. history
            .. " mixed=" .. boolText(run.statMixed))
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

local function paint(frame, bg, edge)
    if not frame or not frame.SetBackdrop or not bg or not edge then return end
    frame:SetBackdrop({
        bgFile = WHITE,
        edgeFile = WHITE,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    frame:SetBackdropColor(bg[1], bg[2], bg[3], bg[4] or 1)
    frame:SetBackdropBorderColor(edge[1], edge[2], edge[3], 1)
end

local function tintButton(button, p, theme)
    if not button then return end
    if not button.__classicEnter then
        button.__classicEnter = button:GetScript("OnEnter")
        button.__classicLeave = button:GetScript("OnLeave")
    end
    if button.SetBackdropColor then
        button:SetBackdropColor(p.buttonBg[1], p.buttonBg[2], p.buttonBg[3], p.buttonBg[4] or 1)
        button:SetBackdropBorderColor(p.border[1], p.border[2], p.border[3], 1)
    end
    button.label:SetTextColor(p.muted[1], p.muted[2], p.muted[3], 1)
    if theme == "journal" then
        button:SetScript("OnEnter", function(self)
            if self.SetBackdropColor then
                self:SetBackdropColor(p.card[1], p.card[2], p.card[3], p.card[4] or 1)
                self:SetBackdropBorderColor(p.accent[1], p.accent[2], p.accent[3], 1)
            end
            self.label:SetTextColor(p.text[1], p.text[2], p.text[3], 1)
        end)
        button:SetScript("OnLeave", function(self)
            if self.SetBackdropColor then
                self:SetBackdropColor(p.buttonBg[1], p.buttonBg[2], p.buttonBg[3], p.buttonBg[4] or 1)
                self:SetBackdropBorderColor(p.border[1], p.border[2], p.border[3], 1)
            end
            self.label:SetTextColor(p.muted[1], p.muted[2], p.muted[3], 1)
        end)
    else
        button:SetScript("OnEnter", button.__classicEnter)
        button:SetScript("OnLeave", button.__classicLeave)
    end
end

local function createWindow()
    if not W or not CreateFrame then return nil end
    local frame = CreateFrame("Frame", "LootJinxDiagnosticsFrame", UIParent,
        BackdropTemplateMixin and "BackdropTemplate" or nil)
    frame:SetSize(600, 520)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)

    local accent = frame:CreateTexture(nil, "ARTWORK")
    accent:SetPoint("TOPLEFT", 1, -1)
    accent:SetPoint("TOPRIGHT", -1, -1)
    accent:SetHeight(2)

    local title = W:Font(frame, 10, nil, "OUTLINE")
    title:SetPoint("TOPLEFT", 18, -12)
    title:SetText(LJ.L("DIAG_TITLE"))

    local subtitle = W:Font(frame, 9, nil, "")
    subtitle:SetPoint("TOPLEFT", 18, -32)
    subtitle:SetText(LJ.L("DIAG_SUB"))

    local close = W:Button(frame, "×", 20, 20)
    close:SetPoint("TOPRIGHT", -12, -10)
    close.label:SetFont(FONT, 14, "")
    close.label:SetPoint("CENTER", 0, 1)
    close:SetScript("OnClick", function() frame:Hide() end)

    local scroll = CreateFrame("ScrollFrame", nil, frame,
        BackdropTemplateMixin and "BackdropTemplate" or nil)
    scroll:SetPoint("TOPLEFT", 16, -50)
    scroll:SetSize(540, 414)
    scroll:SetFrameLevel((frame:GetFrameLevel() or 1) + 2)
    scroll:EnableMouseWheel(true)

    local edit = CreateFrame("EditBox", nil, scroll,
        BackdropTemplateMixin and "BackdropTemplate" or nil)
    edit:SetSize(520, 414)
    edit:SetPoint("TOPLEFT", 0, 0)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetMaxLetters(20000)
    edit:SetFont(FONT, 9, "")
    edit:SetTextInsets(10, 10, 10, 10)
    edit:EnableMouseWheel(true)
    edit:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        frame:Hide()
    end)
    scroll:SetScrollChild(edit)

    local measure = frame:CreateFontString(nil, "OVERLAY")
    measure:SetFont(FONT, 9, "")
    measure:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    measure:SetAlpha(0)

    local slider = CreateFrame("Slider", nil, frame)
    slider:SetOrientation("VERTICAL")
    slider:SetSize(12, 414)
    slider:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -16, -50)
    slider:SetMinMaxValues(0, 0)
    slider:SetValueStep(1)
    slider:SetObeyStepOnDrag(true)

    local track = slider:CreateTexture(nil, "BACKGROUND")
    track:SetWidth(2)
    track:SetPoint("TOP", 0, 0)
    track:SetPoint("BOTTOM", 0, 0)

    local thumb = slider:CreateTexture(nil, "ARTWORK")
    thumb:SetSize(10, 40)
    slider:SetThumbTexture(thumb)

    local function scrollBy(delta)
        local value = (tonumber(slider:GetValue()) or 0) - (tonumber(delta) or 0) * 48
        local minValue, maxValue = slider:GetMinMaxValues()
        minValue, maxValue = tonumber(minValue) or 0, tonumber(maxValue) or 0
        if value < minValue then value = minValue end
        if value > maxValue then value = maxValue end
        slider:SetValue(value)
    end
    slider:SetScript("OnValueChanged", function(_, value)
        if scroll.SetVerticalScroll then scroll:SetVerticalScroll(tonumber(value) or 0) end
    end)
    scroll:SetScript("OnMouseWheel", function(_, delta) scrollBy(delta) end)
    edit:SetScript("OnMouseWheel", function(_, delta) scrollBy(delta) end)
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
    D.scroll = scroll
    D.slider = slider
    D.track = track
    D.thumb = thumb
    D.measure = measure
    D.accent = accent
    D.title = title
    D.subtitle = subtitle
    D.buttons = { refresh, selectAll, print, closeButton, close }
    return frame
end

function D:Create()
    if self.frame then return self.frame end
    local ok, frame = pcall(createWindow)
    if not ok then return nil end
    return frame
end

local function measureWidth(text)
    if not D.measure then return #tostring(text or "") * 5 end
    D.measure:SetText(tostring(text or ""))
    if D.measure.GetStringWidth then
        local ok, value = pcall(D.measure.GetStringWidth, D.measure)
        if ok then return tonumber(value) or 0 end
    end
    return #tostring(text or "") * 5
end

local function estimateHeight(text)
    if not D.measure then return 0 end
    local width = 500
    local spaceWidth = measureWidth(" ")
    local lines = 0
    for line in (tostring(text or "") .. "\n"):gmatch("(.-)\n") do
        lines = lines + 1
        local current = 0
        local hasWord = false
        for word in line:gmatch("%S+") do
            local wordWidth = measureWidth(word)
            local add = hasWord and spaceWidth or 0
            if hasWord and current + add + wordWidth > width then
                lines = lines + 1
                current = wordWidth
            else
                current = current + add + wordWidth
            end
            hasWord = true
            while current > width do
                lines = lines + 1
                current = current - width
            end
        end
    end
    -- Etwas Puffer, weil EditBox und Messschrift minimal anders umbrechen.
    return math.ceil(math.max(1, lines) * 12 * 1.1) + 24
end

function D:ApplyTheme(force)
    if not self.frame then return end
    local theme = currentTheme()
    if self.theme == theme and not force then return end
    local p = palettes[theme] or palettes.classic
    self.theme = theme

    paint(self.frame, p.bg, p.border)
    if self.accent then
        if theme == "journal" then
            self.accent:SetColorTexture(p.accent[1], p.accent[2], p.accent[3], 1)
        else
            W:SetGradient(self.accent, true, p.accent, p.cyan)
        end
    end
    if self.title then
        pcall(self.title.SetFont, self.title, p.titleFont, p.titleSize, p.titleFlags)
        self.title:SetTextColor(p.titleColor[1], p.titleColor[2], p.titleColor[3], 1)
    end
    if self.subtitle then
        self.subtitle:SetTextColor(p.muted[1], p.muted[2], p.muted[3], 1)
    end
    paint(self.scroll, p.editBg, p.editBorder)
    if self.edit then
        self.edit:SetTextColor(p.text[1], p.text[2], p.text[3], 1)
    end
    for i = 1, #(self.buttons or {}) do
        tintButton(self.buttons[i], p, theme)
    end
    if self.track then
        self.track:SetColorTexture(p.muted[1], p.muted[2], p.muted[3], 0.25)
    end
    if self.thumb then
        self.thumb:SetColorTexture(p.accent[1], p.accent[2], p.accent[3], 1)
    end
end

function D:Refresh(reset)
    if not self.edit then return nil end
    local text = self:Build()
    self.edit:SetText(text)

    local viewHeight = self.scroll and tonumber(self.scroll:GetHeight()) or 414
    local contentHeight = math.max(viewHeight, estimateHeight(text))
    self.edit:SetHeight(contentHeight)

    local maxScroll = math.max(0, contentHeight - viewHeight)
    if self.thumb then
        local thumbHeight = viewHeight
        if contentHeight > viewHeight then
            thumbHeight = math.max(36, viewHeight * viewHeight / contentHeight)
        end
        self.thumb:SetHeight(thumbHeight)
    end
    if self.slider then
        self.slider:SetMinMaxValues(0, maxScroll)
        local value = reset and 0 or (tonumber(self.slider:GetValue()) or 0)
        if value > maxScroll then value = maxScroll end
        self.slider:SetValue(value)
        self.slider:SetShown(maxScroll > 0)
    end
    if reset and self.scroll and self.scroll.SetVerticalScroll then
        self.scroll:SetVerticalScroll(0)
    end
    self:ApplyTheme()
    return text
end

function D:Show()
    local frame = self:Create()
    if not frame then
        self:Print()
        return
    end
    self:Refresh(true)
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
