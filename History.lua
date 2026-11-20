-- Searchable dungeon run history shared by both dashboard designs.
local ADDON, ns = ...
local LJ = ns or _G.LootJinx
if not LJ then return end

local H = { query = "", dungeon = nil, dungeonKey = nil, range = "all", status = "all", sort = "date",
    focus = nil,
    page = 1, filterPage = 1,
    rows = {}, filterRows = {}, dateRows = {}, statusRows = {} }
LJ.History = H
local W = LJ.Widgets
local WHITE = "Interface\\Buttons\\WHITE8X8"
local PAGE_SIZE, FILTER_PAGE_SIZE = 9, 8
local palettes = {
    classic = { bg = { .065, .075, .10, .98 }, card = { .10, .11, .14, .98 }, border = { .27, .29, .35, 1 }, text = { .91, .91, .94, 1 }, accent = { .81, .36, .61, 1 }, muted = { .65, .67, .72, 1 } },
    journal = { bg = { .141, .102, .102, .98 }, card = { .190, .145, .133, .98 }, border = { .545, .384, .267, 1 }, text = { .906, .835, .729, 1 }, accent = { .918, .769, .494, 1 }, muted = { .690, .608, .510, 1 } },
}
local function rgba(c) return c[1], c[2], c[3], c[4] or 1 end
local function paint(frame, color, edge)
    if not frame.SetBackdrop then return end
    frame:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 } })
    frame:SetBackdropColor(rgba(color))
    frame:SetBackdropBorderColor(rgba(edge))
end
local function label(parent, size, text)
    local f = W:Font(parent, size, palettes.classic.text, "")
    f:SetText(text or "")
    return f
end
local function button(parent, text, width, height)
    local b = W:Button(parent, text, width, height)
    b:RegisterForClicks("LeftButtonUp")
    b:SetScript("OnEnter", function(self)
        local theme = LJ.UI and LJ.UI.GetLayout and LJ.UI:GetLayout() or "classic"
        local p = palettes[theme] or palettes.classic
        if self.SetBackdropColor then
            self:SetBackdropColor(p.card[1] * .75 + p.accent[1] * .25,
                p.card[2] * .75 + p.accent[2] * .25,
                p.card[3] * .75 + p.accent[3] * .25, .98)
            self:SetBackdropBorderColor(rgba(p.accent))
        end
    end)
    b:SetScript("OnLeave", function(self)
        local theme = LJ.UI and LJ.UI.GetLayout and LJ.UI:GetLayout() or "classic"
        local p = palettes[theme] or palettes.classic
        if self.SetBackdropColor then
            self:SetBackdropColor(rgba(p.card))
            self:SetBackdropBorderColor(rgba(p.border))
        end
    end)
    return b
end
local function normalized(text)
    return string.lower(tostring(text or ""))
end

local function hex(c)
    return string.format("|cff%02x%02x%02x",
        math.floor((c[1] or 1) * 255),
        math.floor((c[2] or 1) * 255),
        math.floor((c[3] or 1) * 255))
end

local STATUS_COLORS = {
    RUN_STATUS_LIVE = LJ.COLORS.green,
    RUN_STATUS_OPEN = LJ.COLORS.cyan,
    RUN_STATUS_PAUSED = LJ.COLORS.accent,
    RUN_STATUS_MANUAL = LJ.COLORS.muted,
    RUN_STATUS_PARTIAL = LJ.COLORS.muted,
}

local SORT_MODES = { "date", "dateAsc", "name", "wins", "losses" }
local SORT_LABELS = {
    date = "HISTORY_SORT_DATE",
    dateAsc = "HISTORY_SORT_DATE_ASC",
    name = "HISTORY_SORT_NAME",
    wins = "HISTORY_SORT_WINS",
    losses = "HISTORY_SORT_LOSSES",
}

local function runStatusKey(run)
    local active = LJ.Tracker and LJ.Tracker:GetActive() == run
    return LJ.Stats and LJ.Stats.RunStatusKey(run, active) or nil
end

local function needStats(run)
    local won, lost = 0, 0
    for _, n in ipairs(run and run.needs or {}) do
        if n.result == "won" then won = won + 1
        elseif n.result == "lost" then lost = lost + 1 end
    end
    return won, lost
end

local function needTextMatches(run, needle)
    for _, need in ipairs(run and run.needs or {}) do
        local link = need.link
        if type(link) == "string" then
            local name = link:match("%[(.-)%]")
            if name and normalized(name):find(needle, 1, true) then return true end
            local info = LJ:ItemInfo(link)
            if info and info.name and normalized(info.name):find(needle, 1, true) then return true end
        end
    end
    return false
end

local function runBadges(run)
    local parts = {}
    local total = #(run.needs or {})
    if total > 0 then
        local wins = needStats(run)
        local color = wins > 0 and LJ.COLORS.green or LJ.COLORS.red
        parts[#parts + 1] = hex(color) .. LJ.L("BADGE_NEED", wins, total) .. "|r"
    end
    if run.legacy then
        parts[#parts + 1] = hex(LJ.COLORS.muted) .. LJ.L("HISTORY_LEGACY") .. "|r"
    end
    return table.concat(parts, " · ")
end

local function sortMatches(result, mode)
    local function newer(a, b)
        return (tonumber(a.started) or 0) > (tonumber(b.started) or 0)
    end
    local cmp
    if mode == "dateAsc" then
        cmp = function(a, b) return (tonumber(a.started) or 0) < (tonumber(b.started) or 0) end
    elseif mode == "name" then
        cmp = function(a, b) return normalized(LJ:DungeonName(a)) < normalized(LJ:DungeonName(b)) end
    elseif mode == "wins" then
        cmp = function(a, b)
            local aw, al = needStats(a)
            local bw, bl = needStats(b)
            if aw == bw then return newer(a, b) end
            return aw > bw
        end
    elseif mode == "losses" then
        cmp = function(a, b)
            local aw, al = needStats(a)
            local bw, bl = needStats(b)
            if al == bl then return newer(a, b) end
            return al > bl
        end
    else
        cmp = newer
    end
    table.sort(result, cmp)
end

local function dungeonIdentity(run, includeWing)
    local instanceID = tonumber(run and run.instanceID)
    if instanceID and instanceID > 0 then
        local key = tostring(instanceID)
        if includeWing and LJ.DungeonCompletion and LJ.DungeonCompletion.Progress then
            local progress = LJ.DungeonCompletion:Progress(run)
            if progress and progress.dungeon then
                key = key .. ":" .. progress.dungeon
            end
        end
        return key
    end
end

local function sameDungeon(first, second, includeWing)
    if not first or not second then return false end
    local firstID = dungeonIdentity(first, includeWing)
    local secondID = dungeonIdentity(second, includeWing)
    if firstID and secondID then return firstID == secondID end
    return type(first.name) == "string" and first.name ~= ""
        and first.name == second.name
end

local function knownDungeonIDs(runs)
    local byName = {}
    for _, run in ipairs(runs or {}) do
        if type(run) == "table" and type(run.name) == "string" then
            local id = dungeonIdentity(run)
            if id then
                local group = byName[run.name]
                if not group then
                    group = { count = 0, seen = {} }
                    byName[run.name] = group
                end
                if not group.seen[id] then
                    group.seen[id] = true
                    group.count = group.count + 1
                    group.sole = id
                end
            end
        end
    end
    return byName
end

local function filterKey(run, knownIDs)
    local id = dungeonIdentity(run)
    if id then return "id:" .. id end
    local name = type(run.name) == "string" and run.name or ""
    local group = knownIDs[name]
    if group and group.count == 1 then return "id:" .. group.sole end
    return "name:" .. name
end

local function localDayStart(now, daysBack)
    local gameClock = type(date) == "function" and type(time) == "function"
    local dateFn = gameClock and date or (os and os.date)
    local timeFn = gameClock and time or (os and os.time)
    if not dateFn or not timeFn then return nil end
    local day = dateFn("*t", now)
    if type(day) ~= "table" then return nil end
    return tonumber(timeFn({ year = day.year, month = day.month,
        day = day.day - daysBack, hour = 0, min = 0, sec = 0 }))
end

local function isBossClear(run)
    if run.closedReason == "all-bosses-cleared" then return true end
    if run.closed ~= true or run.closedReason ~= "left" or run.legacy == true then return false end
    local progress = LJ.DungeonCompletion and LJ.DungeonCompletion:Progress(run)
    return progress ~= nil and progress.state == "complete"
end

function H:StatusMatches(run, status)
    status = status or "all"
    if status == "all" then return true end
    if status == "clear" then return isBossClear(run) end
    if status == "manual" then return run.closedReason == "manual" end
    if status == "pending" then
        for _, need in ipairs(run.needs or {}) do
            if need.result == nil then return true end
        end
    end
    return false
end

-- Das Dropdown-Label ist kein stabiler Schlüssel: sobald ein zweiter Eintrag
-- mit gleichem Dungeon-Namen dazukommt, wird daraus "Name (Instanz-ID)", und
-- nach dem Aufräumen fällt der Zusatz wieder weg. Deshalb wird die Auswahl
-- zusätzlich über den Schlüssel aufgelöst.
function H:ResolveDungeonKey(dungeon, runs, rememberedKey)
    if type(dungeon) ~= "string" or dungeon == "" then return nil end
    local options = self:DungeonOptions(runs)
    for _, option in ipairs(options) do
        if option.label == dungeon then return option.key end
    end
    local base = dungeon:gsub("%s+%b()%s*$", "")
    local found, ambiguous
    for _, option in ipairs(options) do
        if option.name == base or option.displayName == base then
            if found == nil then
                found = option.key
            elseif found ~= option.key then
                ambiguous = true
            end
        end
    end
    if found and not ambiguous then return found end
    if rememberedKey then
        for _, option in ipairs(options) do
            if option.key == rememberedKey then return option.key end
        end
    end
    return nil
end

-- Fokussierte Auswahl der drei Dashboard-Karten. "sinceNeedWin" entspricht
-- der laufenden Serie in Stats.Compute; "noNeedWin" und "noLoot" den Summen.
local function focusSet(runs, focus)
    if not focus then return nil end
    local set, seenNeed = {}, false
    for _, run in ipairs(runs or {}) do
        if type(run) == "table" then
            local total, won = 0, 0
            for _, need in ipairs(run.needs or {}) do
                total = total + 1
                if need.result == "won" then won = won + 1 end
            end
            if total > 0 then seenNeed = true end
            if focus == "noNeedWin" then
                if total > 0 and won == 0 then set[run] = true end
            elseif focus == "noLoot" then
                if run.lootSeen ~= true then set[run] = true end
            elseif focus == "sinceNeedWin" then
                if won > 0 then
                    -- Ein Need-Win startet die Serie neu; nur Runs danach zaehlen.
                    set = {}
                elseif seenNeed then
                    set[run] = true
                end
            end
        end
    end
    return set
end

function H:Filter(runs, query, dungeon, range, now, status, dungeonKey, focus)
    local result, needle = {}, normalized(query)
    focus = focus or self.focus
    local focused = focusSet(runs, focus)
    range = range or "all"
    now = tonumber(now) or (LJ.Now and LJ.Now()) or 0
    local daysBack = ({ today = 0, week = 6, month = 29 })[range]
    local cutoff = daysBack and localDayStart(now, daysBack) or nil
    local searchIDs, nameMatches = {}, {}
    if needle ~= "" then
        for _, candidate in ipairs(runs or {}) do
            if type(candidate) == "table" then
                local recordedMatch = normalized(candidate.name):find(needle, 1, true)
                if recordedMatch then
                    local key = dungeonIdentity(candidate)
                    if key then searchIDs[key] = true end
                end
                nameMatches[candidate] = recordedMatch
                    or normalized(LJ:DungeonName(candidate)):find(needle, 1, true)
            end
        end
    end
    local selectedKey
    if dungeon then
        selectedKey = self:ResolveDungeonKey(dungeon, runs, dungeonKey)
    end
    local knownIDs = knownDungeonIDs(runs)
    for i = #(runs or {}), 1, -1 do
        local run = runs[i]
        local started = type(run) == "table" and tonumber(run.started) or nil
        if type(run) == "table" and (not dungeon or (selectedKey
            and filterKey(run, knownIDs) == selectedKey))
            and (needle == "" or nameMatches[run]
                or searchIDs[dungeonIdentity(run)]
                or needTextMatches(run, needle))
            and (not daysBack or (cutoff and started and started >= cutoff and started <= now))
            and (not focused or focused[run])
            and self:StatusMatches(run, status) then
            result[#result + 1] = run
        end
    end
    sortMatches(result, self.sort)
    return result
end

local function comparisonState(run)
    if isBossClear(run) then return "HISTORY_COMPARE_CLEAR" end
    if run.closedReason == "manual" then return "HISTORY_COMPARE_MANUAL" end
    if run.partial then return "HISTORY_COMPARE_PARTIAL" end
    if run.closed then return "HISTORY_COMPARE_CLOSED" end
    return "HISTORY_COMPARE_OPEN"
end

local function compareNeedColor(won, lost)
    if won > 0 then return LJ.COLORS.green end
    if lost > 0 then return LJ.COLORS.red end
    return LJ.COLORS.muted
end

local function compareStateColor(key)
    if key == "HISTORY_COMPARE_CLEAR" then return LJ.COLORS.green end
    if key == "HISTORY_COMPARE_OPEN" then return LJ.COLORS.cyan end
    return LJ.COLORS.muted
end

local function comparisonRun(run)
    local won, lost, pending = 0, 0, 0
    for _, need in ipairs(run.needs or {}) do
        if need.result == "won" then won = won + 1
        elseif need.result == "lost" then lost = lost + 1
        else pending = pending + 1 end
    end
    return {
        started = tonumber(run.started) or 0,
        won = won, lost = lost, pending = pending,
        state = comparisonState(run),
    }
end

function H:ComparisonData(first, second)
    if type(first) ~= "table" or type(second) ~= "table" or first == second
        or type(first.name) ~= "string" or first.name == ""
        or not sameDungeon(first, second, true) then return nil end
    return { name = first.name, first = comparisonRun(first), second = comparisonRun(second) }
end

function H:DungeonOptions(runs)
    local seen, options, nameCounts = {}, {}, {}
    local knownIDs = knownDungeonIDs(runs)
    for i = #(runs or {}), 1, -1 do
        local run = runs[i]
        local name = run and run.name
        local key = type(run) == "table" and filterKey(run, knownIDs) or nil
        if type(name) == "string" and name ~= "" and not seen[key] then
            seen[key] = true
            local displayName = LJ:DungeonName(run)
            nameCounts[displayName] = (nameCounts[displayName] or 0) + 1
            options[#options + 1] = { run = run, name = name, key = key, displayName = displayName }
        end
    end
    for _, option in ipairs(options) do
        local id = tonumber(option.run.instanceID)
        option.label = nameCounts[option.displayName] > 1
            and (option.displayName .. " (" .. (id and tostring(id) or LJ.L("HISTORY_LEGACY")) .. ")")
            or option.displayName
    end
    table.sort(options, function(a, b) return normalized(a.label) < normalized(b.label) end)
    return options
end

function H:Dungeons(runs)
    local names = {}
    for _, option in ipairs(self:DungeonOptions(runs)) do
        names[#names + 1] = option.label
    end
    return names
end

function H:Summarize(runs)
    local stats = LJ.Stats.Compute(runs)
    return {
        runs = stats.totalDungeons or 0,
        noLoot = stats.noLootDungeons or 0,
        needWins = stats.needWins or 0,
        needLost = stats.needLost or 0,
        needPending = stats.needPending or 0,
    }
end

local function suspendDashboardEscape()
    local dashboard = LJ.UI and LJ.UI.frame
    local name = dashboard and dashboard.IsShown and dashboard:IsShown()
        and dashboard.GetName and dashboard:GetName()
    if not name or type(UISpecialFrames) ~= "table" then return end
    for i = #UISpecialFrames, 1, -1 do
        if UISpecialFrames[i] == name then table.remove(UISpecialFrames, i) end
    end
    H.suspendedName = name
end

local function restoreDashboardEscape()
    local name = H.suspendedName
    if not name then return end
    H.suspendedName = nil
    H.restoreToken = (H.restoreToken or 0) + 1
    local token = H.restoreToken
    local function restore()
        if token ~= H.restoreToken or type(UISpecialFrames) ~= "table" then return end
        for i = 1, #UISpecialFrames do if UISpecialFrames[i] == name then return end end
        table.insert(UISpecialFrames, name)
    end
    if C_Timer and C_Timer.After then C_Timer.After(0, restore)
    else restore() end
end

function H:ApplyTheme()
    if not self.frame then return end
    local theme = LJ.UI and LJ.UI.GetLayout and LJ.UI:GetLayout() or "classic"
    local p = palettes[theme] or palettes.classic
    paint(self.frame, p.bg, p.border)
    paint(self.search, p.card, p.border)
    paint(self.menu, p.card, p.border)
    paint(self.dateMenu, p.card, p.border)
    paint(self.statusMenu, p.card, p.border)
    paint(self.summaryPanel, p.card, p.border)
    paint(self.comparePanel, p.bg, p.border)
    for _, card in ipairs(self.compareCards or {}) do paint(card, p.card, p.border) end
    for _, f in ipairs(self.labels) do f:SetTextColor(rgba(p.text)) end
    for _, f in ipairs(self.mutedLabels) do f:SetTextColor(rgba(p.muted)) end
    self.creditLink:SetTextColor(rgba(p.accent))
    self.title:SetTextColor(rgba(p.accent))
    self.summaryTitle:SetTextColor(rgba(p.accent))
    self.compareTitle:SetTextColor(rgba(p.accent))
    for _, t in ipairs(self.compareColTitles or {}) do t:SetTextColor(rgba(p.accent)) end
    for _, b in ipairs(self.buttons) do
        paint(b, p.card, p.border)
        b.label:SetTextColor(rgba(p.text))
    end
end

function H:Create()
    if self.frame then return self.frame end
    local f = CreateFrame("Frame", "LootJinxHistoryFrame", UIParent,
        BackdropTemplateMixin and "BackdropTemplate" or nil)
    self.frame = f
    f:SetSize(610, 520)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    f:SetFrameStrata("DIALOG")
    f:SetFrameLevel(150)
    f:SetToplevel(true)
    f:EnableMouse(true)
    if f.SetClampedToScreen then f:SetClampedToScreen(true) end
    self.labels, self.mutedLabels, self.buttons = {}, {}, {}
    local function addButton(parent, text, w, h)
        local b = button(parent, text, w, h)
        self.buttons[#self.buttons + 1] = b
        return b
    end
    self.title = label(f, 16, LJ.L("HISTORY_TITLE"))
    self.title:SetPoint("TOPLEFT", 16, -14)
    local legend = addButton(f, "?", 16, 16)
    legend:SetPoint("LEFT", self.title, "RIGHT", 8, -1)
    W:Tooltip(legend, LJ.L("HISTORY_LEGEND_TITLE"), {
        LJ.L("HISTORY_LEGEND_COUNTED"),
        LJ.L("HISTORY_LEGEND_EMPTY"),
        LJ.L("HISTORY_LEGEND_STATUS"),
    })
    self.count = label(f, 10, "")
    self.count:SetPoint("TOPLEFT", 16, -40)
    self.mutedLabels[#self.mutedLabels + 1] = self.count
    self.creditLink = W:ForeverDBCredit(f, function() H:Hide() end)
    self.creditLink:SetPoint("TOPRIGHT", -16, -39)
    self.mutedLabels[#self.mutedLabels + 1] = self.creditLink.label
    local close = addButton(f, "×", 24, 24)
    close:SetPoint("TOPRIGHT", -14, -12)
    close:SetScript("OnClick", function() H:Hide() end)
    self.cleanupButton = addButton(f, "", 130, 24)
    self.cleanupButton:SetPoint("TOPRIGHT", -46, -12)
    self.cleanupButton:SetScript("OnClick", function() H:ConfirmCleanup() end)
    W:Tooltip(self.cleanupButton, LJ.L("HISTORY_CLEANUP_ACCEPT"),
        { LJ.L("HISTORY_CLEANUP_HINT") })
    self.dateButton = addButton(f, "", 150, 24)
    self.dateButton:SetPoint("TOPRIGHT", -184, -12)
    local dateArrow = label(self.dateButton, 10, "v")
    dateArrow:SetPoint("RIGHT", -8, 0)
    self.labels[#self.labels + 1] = dateArrow
    self.dateButton:SetScript("OnClick", function()
        H.menu:Hide()
        H.statusMenu:Hide()
        H.dateMenu:SetShown(not H.dateMenu:IsShown())
    end)
    self.dateMenu = CreateFrame("Frame", nil, f, BackdropTemplateMixin and "BackdropTemplate" or nil)
    self.dateMenu:SetSize(150, 104)
    self.dateMenu:SetPoint("TOPLEFT", self.dateButton, "BOTTOMLEFT", 0, -2)
    self.dateMenu:SetFrameLevel(f:GetFrameLevel() + 25)
    for i, range in ipairs({ "all", "today", "week", "month" }) do
        local choice = addButton(self.dateMenu,
            LJ.L("HISTORY_DATE_" .. string.upper(range)), 138, 23)
        choice:SetPoint("TOPLEFT", 6, -4 - (i - 1) * 24)
        choice.range = range
        choice:SetScript("OnClick", function(self)
            H.range = self.range
            H.page = 1
            H:ClearComparison()
            H.dateMenu:Hide()
            H:Refresh()
        end)
        self.dateRows[i] = choice
    end
    self.dateMenu:Hide()

    self.search = CreateFrame("EditBox", nil, f, BackdropTemplateMixin and "BackdropTemplate" or nil)
    self.search:SetSize(278, 25)
    self.search:SetPoint("TOPLEFT", 16, -64)
    self.search:SetAutoFocus(false)
    self.search:SetFontObject("GameFontNormal")
    local _, searchFontSize, searchFontFlags = self.search:GetFont()
    W:SetTextFont(self.search, searchFontSize or 12, searchFontFlags, false)
    self.search:SetTextInsets(8, 8, 0, 0)
    self.search:SetText("")
    self.search:SetScript("OnTextChanged", function(edit)
        H.query = edit:GetText() or ""
        H.page = 1
        H:ClearComparison()
        H:Refresh()
    end)
    self.search:SetScript("OnEnterPressed", function(edit) edit:ClearFocus() end)
    self.search:SetScript("OnEscapePressed", function(edit) edit:ClearFocus() end)
    local searchLabel = label(f, 9, LJ.L("HISTORY_SEARCH"))
    searchLabel:SetPoint("BOTTOMLEFT", self.search, "TOPLEFT", 3, 2)
    self.mutedLabels[#self.mutedLabels + 1] = searchLabel

    self.filterButton = addButton(f, LJ.L("HISTORY_ALL_DUNGEONS"), 278, 25)
    self.filterButton:SetPoint("TOPLEFT", 310, -64)
    self.filterButton:SetScript("OnClick", function()
        H.dateMenu:Hide()
        H.statusMenu:Hide()
        H.menu:SetShown(not H.menu:IsShown())
        if H.menu:IsShown() then H:RefreshFilterMenu() end
    end)
    local filterLabel = label(f, 9, LJ.L("HISTORY_DUNGEON"))
    filterLabel:SetPoint("BOTTOMLEFT", self.filterButton, "TOPLEFT", 3, 2)
    self.mutedLabels[#self.mutedLabels + 1] = filterLabel
    self.menu = CreateFrame("Frame", nil, f, BackdropTemplateMixin and "BackdropTemplate" or nil)
    self.menu:SetSize(278, 250)
    self.menu:SetPoint("TOPLEFT", self.filterButton, "BOTTOMLEFT", 0, -2)
    self.menu:SetFrameLevel(f:GetFrameLevel() + 20)
    for i = 1, FILTER_PAGE_SIZE do
        local choice = addButton(self.menu, "", 264, 23)
        choice:SetPoint("TOPLEFT", 7, -6 - (i - 1) * 24)
        choice:SetScript("OnClick", function(self)
            H.dungeon, H.dungeonKey = self.dungeon, self.dungeonKey
            H.page = 1
            H:ClearComparison()
            H.menu:Hide()
            H:Refresh()
        end)
        self.filterRows[i] = choice
    end
    self.filterPrev = addButton(self.menu, "<", 32, 22)
    self.filterPrev:SetPoint("BOTTOMLEFT", 7, 7)
    self.filterPrev:SetScript("OnClick", function() H.filterPage = H.filterPage - 1; H:RefreshFilterMenu() end)
    self.filterNext = addButton(self.menu, ">", 32, 22)
    self.filterNext:SetPoint("BOTTOMRIGHT", -7, 7)
    self.filterNext:SetScript("OnClick", function() H.filterPage = H.filterPage + 1; H:RefreshFilterMenu() end)
    self.filterPageText = label(self.menu, 9, "")
    self.filterPageText:SetPoint("BOTTOM", 0, 11)
    self.mutedLabels[#self.mutedLabels + 1] = self.filterPageText
    self.menu:Hide()

    self.summaryPanel = CreateFrame("Frame", nil, f, BackdropTemplateMixin and "BackdropTemplate" or nil)
    self.summaryPanel:SetPoint("TOPLEFT", 16, -99)
    self.summaryPanel:SetSize(578, 54)
    self.summaryTitle = label(self.summaryPanel, 10, "")
    self.summaryTitle:SetPoint("TOPLEFT", 10, -5)
    self.summaryTitle:SetWidth(170)
    self.sortButton = addButton(self.summaryPanel, "", 112, 20)
    self.sortButton:SetPoint("TOPLEFT", 186, -4)
    self.sortButton:SetScript("OnClick", function() H:CycleSort() end)
    W:Tooltip(self.sortButton, LJ.L("HISTORY_SORT_TITLE"),
        { LJ.L("HISTORY_SORT_HINT") })
    self.statusButton = addButton(self.summaryPanel, LJ.L("HISTORY_STATUS_ALL"), 138, 20)
    self.statusButton:SetPoint("TOPRIGHT", -102, -4)
    self.statusButton:SetScript("OnClick", function()
        H.menu:Hide()
        H.dateMenu:Hide()
        H.statusMenu:SetShown(not H.statusMenu:IsShown())
    end)
    self.resetFilters = addButton(self.summaryPanel, LJ.L("HISTORY_RESET_FILTERS"), 88, 20)
    self.resetFilters:SetPoint("TOPRIGHT", -8, -4)
    self.resetFilters:SetScript("OnClick", function() H:ResetFilters() end)
    self.focusButton = addButton(f, "", 210, 18)
    self.focusButton:SetPoint("TOPRIGHT", -46, -36)
    self.focusButton:SetScript("OnClick", function()
        H.focus = nil
        H.page = 1
        H:ClearComparison()
        H:Refresh()
    end)
    W:Tooltip(self.focusButton, LJ.L("HISTORY_RESET_FILTERS"))
    self.focusButton:Hide()
    self.statusMenu = CreateFrame("Frame", nil, f, BackdropTemplateMixin and "BackdropTemplate" or nil)
    self.statusMenu:SetSize(138, 106)
    self.statusMenu:SetPoint("TOPLEFT", self.statusButton, "BOTTOMLEFT", 0, -2)
    self.statusMenu:SetFrameLevel(f:GetFrameLevel() + 25)
    for i, status in ipairs({ "all", "clear", "manual", "pending" }) do
        local choice = addButton(self.statusMenu,
            LJ.L("HISTORY_STATUS_" .. string.upper(status)), 126, 22)
        choice:SetPoint("TOPLEFT", 6, -5 - (i - 1) * 24)
        choice.status = status
        choice:SetScript("OnClick", function(self)
            H.status = self.status
            H.page = 1
            H:ClearComparison()
            H.statusMenu:Hide()
            H:Refresh()
        end)
        self.statusRows[i] = choice
    end
    self.statusMenu:Hide()
    self.summaryLine1 = label(self.summaryPanel, 9, "")
    self.summaryLine1:SetPoint("TOPLEFT", 10, -22)
    self.summaryLine1:SetWidth(550)
    self.summaryLine2 = label(self.summaryPanel, 9, "")
    self.summaryLine2:SetPoint("TOPLEFT", 10, -37)
    self.summaryLine2:SetWidth(550)
    self.labels[#self.labels + 1] = self.summaryLine1
    self.labels[#self.labels + 1] = self.summaryLine2

    self.headerDungeon = label(f, 8, LJ.L("HISTORY_COL_DUNGEON"))
    self.headerDungeon:SetPoint("TOPLEFT", 34, -160)
    self.headerInfo = label(f, 8, LJ.L("HISTORY_COL_INFO"))
    self.headerInfo:SetPoint("TOPLEFT", 240, -160)
    self.headerDate = label(f, 8, LJ.L("HISTORY_COL_DATE"))
    self.headerDate:SetPoint("TOPRIGHT", -26, -160)
    self.headerDate:SetJustifyH("RIGHT")
    self.mutedLabels[#self.mutedLabels + 1] = self.headerDungeon
    self.mutedLabels[#self.mutedLabels + 1] = self.headerInfo
    self.mutedLabels[#self.mutedLabels + 1] = self.headerDate

    for i = 1, PAGE_SIZE do
        local row = addButton(f, "", 578, 31)
        row:SetPoint("TOPLEFT", 16, -176 - (i - 1) * 34)
        row.label:ClearAllPoints()
        row.label:SetPoint("LEFT", 18, 0)
        row.label:SetWidth(200)
        row.label:SetJustifyH("LEFT")
        row.bar = row:CreateTexture(nil, "ARTWORK")
        row.bar:SetSize(2, 18)
        row.bar:SetPoint("LEFT", 0, 0)
        row.bar:Hide()
        row.status = row:CreateTexture(nil, "ARTWORK")
        row.status:SetSize(6, 6)
        row.status:SetPoint("LEFT", 7, 0)
        row.status:Hide()
        row.badges = W:Font(row, 9, LJ.COLORS.muted, "")
        row.badges:SetPoint("LEFT", 224, 0)
        row.badges:SetWidth(140)
        row.badges:SetWordWrap(false)
        row.compare = addButton(row, LJ.L("HISTORY_COMPARE_PICK"), 76, 22)
        row.compare:SetPoint("RIGHT", row, "RIGHT", -118, 0)
        row.compare:SetScript("OnClick", function()
            if row.run then H:SelectForComparison(row.run) end
        end)
        W:Tooltip(row.compare, LJ.L("HISTORY_COMPARE_PICK"),
            { LJ.L("HISTORY_COMPARE_HINT") })
        row.date = label(row, 9, "")
        row.date:SetPoint("RIGHT", -10, 0)
        row.date:SetWidth(88)
        row.date:SetJustifyH("RIGHT")
        self.mutedLabels[#self.mutedLabels + 1] = row.date
        row:SetScript("OnClick", function(self)
            if self.run and not self.run.legacy and LJ.RunDetail then
                H.menu:Hide()
                LJ.RunDetail:Show(self.run, LJ.UI and LJ.UI:GetLayout())
            end
        end)
        local prevEnter = row:GetScript("OnEnter")
        local prevLeave = row:GetScript("OnLeave")
        row:SetScript("OnEnter", function(self)
            if prevEnter then prevEnter(self) end
            if self.run and LJ.ShowRecentTooltip then LJ:ShowRecentTooltip(self, self.run) end
        end)
        row:SetScript("OnLeave", function(self)
            if prevLeave then prevLeave(self) end
            if GameTooltip then GameTooltip:Hide() end
        end)
        self.rows[i] = row
    end
    self.empty = label(f, 10, LJ.L("HISTORY_EMPTY"))
    self.empty:SetPoint("CENTER", 0, -20)
    self.mutedLabels[#self.mutedLabels + 1] = self.empty
    self.pageText = label(f, 9, "")
    self.pageText:SetPoint("BOTTOM", 0, 16)
    self.mutedLabels[#self.mutedLabels + 1] = self.pageText
    self.prev = addButton(f, LJ.L("DETAIL_PREV"), 75, 22)
    self.prev:SetPoint("BOTTOMLEFT", 16, 12)
    self.prev:SetScript("OnClick", function() H.page = H.page - 1; H:Refresh() end)
    self.next = addButton(f, LJ.L("DETAIL_NEXT"), 75, 22)
    self.next:SetPoint("BOTTOMRIGHT", -16, 12)
    self.next:SetScript("OnClick", function() H.page = H.page + 1; H:Refresh() end)
    self.comparePanel = CreateFrame("Frame", nil, f,
        BackdropTemplateMixin and "BackdropTemplate" or nil)
    self.comparePanel:SetSize(560, 240)
    self.comparePanel:SetPoint("CENTER", f, "CENTER", 0, 0)
    self.comparePanel:SetFrameLevel(f:GetFrameLevel() + 40)
    self.comparePanel:EnableMouse(true)
    self.compareTitle = label(self.comparePanel, 14, "")
    self.compareTitle:SetPoint("TOPLEFT", 16, -14)
    self.compareTitle:SetWidth(480)
    local compareClose = addButton(self.comparePanel, "×", 24, 22)
    compareClose:SetPoint("TOPRIGHT", -12, -10)
    compareClose:SetScript("OnClick", function() H:ClearComparison(); H:Refresh() end)
    self.compareValues = {}
    self.compareCards = {}
    self.compareColTitles = {}
    for i = 1, 2 do
        local x = i == 1 and 16 or 290
        local card = CreateFrame("Frame", nil, self.comparePanel,
            BackdropTemplateMixin and "BackdropTemplate" or nil)
        card:SetSize(254, 184)
        card:SetPoint("TOPLEFT", x, -40)
        self.compareCards[i] = card
        local column = { card = card, title = label(card, 12,
            LJ.L(i == 1 and "HISTORY_COMPARE_A" or "HISTORY_COMPARE_B")) }
        column.title:SetPoint("TOPLEFT", 12, -12)
        self.compareColTitles[i] = column.title
        for _, field in ipairs({ "date", "need", "state" }) do
            column[field] = label(card, 10, "")
            column[field]:SetWidth(226)
            column[field]:SetWordWrap(true)
        end
        column.date:SetPoint("TOPLEFT", 12, -42)
        column.need:SetPoint("TOPLEFT", 12, -80)
        column.state:SetPoint("TOPLEFT", 12, -118)
        self.compareValues[i] = column
    end
    self.comparePanel:Hide()
    f:SetScript("OnShow", function() suspendDashboardEscape(); H:Refresh() end)
    f:SetScript("OnHide", function()
        H.menu:Hide()
        H.dateMenu:Hide()
        H.statusMenu:Hide()
        H:ClearComparison()
        if LJ.RunDetail and LJ.RunDetail:IsShown() then LJ.RunDetail:Hide() end
        restoreDashboardEscape()
    end)
    if type(UISpecialFrames) == "table" then
        local escapeName = "LootJinxHistoryFrame"
        local found = false
        for i = 1, #UISpecialFrames do
            if UISpecialFrames[i] == escapeName then found = true break end
        end
        if not found then table.insert(UISpecialFrames, escapeName) end
    end
    f:Hide()
    LJ:RegisterRefresh(function() if f:IsShown() then H:Refresh() end end)
    return f
end

function H:RefreshFilterMenu()
    local options = { false }
    for _, option in ipairs(self:DungeonOptions(LJ.Tracker:GetRuns())) do
        options[#options + 1] = option
    end
    local pages = math.max(1, math.ceil(#options / FILTER_PAGE_SIZE))
    self.filterPage = math.max(1, math.min(self.filterPage, pages))
    for i, row in ipairs(self.filterRows) do
        local option = options[(self.filterPage - 1) * FILTER_PAGE_SIZE + i]
        row.dungeon = option and option.label or nil
        row.dungeonKey = option and option.key or nil
        row.label:SetText(option == false and LJ.L("HISTORY_ALL_DUNGEONS")
            or (option and option.label) or "")
        row:SetShown(option ~= nil)
    end
    self.filterPageText:SetText(self.filterPage .. " / " .. pages)
    self.filterPrev:SetShown(self.filterPage > 1)
    self.filterNext:SetShown(self.filterPage < pages)
end

function H:ClearComparison()
    self.compareA, self.compareB = nil, nil
    if self.comparePanel then self.comparePanel:Hide() end
end

function H:ResetFilters()
    self.query, self.dungeon, self.dungeonKey, self.range, self.status = "", nil, nil, "all", "all"
    self.focus = nil
    self.page, self.filterPage = 1, 1
    self:ClearComparison()
    if self.search then self.search:SetText("") end
    if self.menu then self.menu:Hide() end
    if self.dateMenu then self.dateMenu:Hide() end
    if self.statusMenu then self.statusMenu:Hide() end
    self:Refresh()
end

function H:ShowComparison(first, second)
    local data = self:ComparisonData(first, second)
    if not data or not self.comparePanel then return false end
    self.compareTitle:SetText(LJ.L("HISTORY_COMPARE_TITLE",
        W:Truncate(LJ:DungeonName(first), 37)))
    self:ApplyTheme()
    for i, run in ipairs({ data.first, data.second }) do
        local column = self.compareValues[i]
        local when = LJ:FormatTime(run.started, "DATE_TIME")
        column.date:SetText(LJ.L("HISTORY_COMPARE_DATE", when))
        column.date:SetTextColor(rgba(LJ.COLORS.muted))
        column.need:SetText(LJ.L("HISTORY_COMPARE_NEED", run.won, run.lost, run.pending))
        column.need:SetTextColor(rgba(compareNeedColor(run.won, run.lost)))
        column.state:SetText(LJ.L(run.state))
        column.state:SetTextColor(rgba(compareStateColor(run.state)))
    end
    self.comparePanel:Show()
    return true
end

function H:SelectForComparison(run)
    if type(run) ~= "table" then return false end
    if self.compareA == run then
        self.compareA, self.compareB = self.compareB, nil
        self.comparePanel:Hide()
    elseif self.compareB == run then
        self.compareB = nil
        self.comparePanel:Hide()
    elseif not self.compareA then
        self.compareA = run
    elseif not sameDungeon(self.compareA, run, true) then
        -- Anderer Dungeon: Auswahl neu starten, statt den Nutzer zu blockieren.
        self.compareA, self.compareB = run, nil
        self.comparePanel:Hide()
    else
        self.compareB = run
        self:ShowComparison(self.compareA, self.compareB)
    end
    self:Refresh()
    return true
end

function H:CycleSort()
    local idx = 1
    for i, mode in ipairs(SORT_MODES) do
        if mode == self.sort then idx = i break end
    end
    idx = (idx % #SORT_MODES) + 1
    self.sort = SORT_MODES[idx]
    self.page = 1
    self:Refresh()
end

function H:Refresh()
    if not self.frame or not LJ.Tracker then return end
    local runs = LJ.Tracker:GetRuns()
    if self.dungeon then
        local key = self:ResolveDungeonKey(self.dungeon, runs, self.dungeonKey)
        if key then
            self.dungeonKey = key
        else
            -- Der gewählte Dungeon existiert nicht mehr (z. B. nach dem Aufräumen):
            -- Filter zurücksetzen, statt eine leere Liste ohne Erklärung zu zeigen.
            self.dungeon, self.dungeonKey = nil, nil
            self.page, self.filterPage = 1, 1
        end
    end
    local matches = self:Filter(runs, self.query, self.dungeon, self.range, LJ.Now(), self.status,
        self.dungeonKey)
    local preview = LJ.Storage:Preview(runs, LJ.Tracker:GetActive(), LJ.Now())
    self.cleanupButton.label:SetText(LJ.L("HISTORY_CLEANUP_BUTTON", preview.eligible))
    local summary = self:Summarize(matches)
    self.summaryTitle:SetText(LJ.L("HISTORY_SUMMARY_TITLE",
        W:Truncate(self.dungeon or LJ.L("HISTORY_ALL_DUNGEONS"), 28)))
    self.summaryLine1:SetText(LJ.L("HISTORY_SUMMARY_RUNS", summary.runs, summary.noLoot))
    self.summaryLine2:SetText(LJ.L("HISTORY_SUMMARY_NEED", summary.needWins,
        summary.needLost, summary.needPending))
    local pages = math.max(1, math.ceil(#matches / PAGE_SIZE))
    self.page = math.max(1, math.min(self.page, pages))
    self.filterButton.label:SetText(self.dungeon or LJ.L("HISTORY_ALL_DUNGEONS"))
    self.dateButton.label:SetText(LJ.L("HISTORY_DATE_" .. string.upper(self.range)))
    self.statusButton.label:SetText(LJ.L("HISTORY_STATUS_" .. string.upper(self.status)))
    self.sortButton.label:SetText(LJ.L("HISTORY_SORT_BUTTON", LJ.L(SORT_LABELS[self.sort])))
    local focusLabels = { noNeedWin = "MINI_NO_WIN", noLoot = "MINI_NO_LOOT", sinceNeedWin = "MINI_SINCE" }
    if self.focusButton then
        local focusKey = focusLabels[self.focus]
        self.focusButton:SetShown(focusKey ~= nil)
        if focusKey then
            self.focusButton.label:SetText(LJ.L("HISTORY_FOCUS_CHIP", LJ.L(focusKey)))
        end
    end
    self.count:SetText(LJ.L("HISTORY_COUNT", #matches, preview.savedRuns))
    self.empty:SetShown(#matches == 0)
    self.pageText:SetText(self.page .. " / " .. pages)
    self.prev:SetShown(self.page > 1)
    self.next:SetShown(self.page < pages)
    for i, row in ipairs(self.rows) do
        local run = matches[(self.page - 1) * PAGE_SIZE + i]
        row.run = run
        row:SetShown(run ~= nil)
        if run then
            row.compare.label:SetText(run == self.compareA and LJ.L("HISTORY_COMPARE_A")
                or run == self.compareB and LJ.L("HISTORY_COMPARE_B")
                or LJ.L("HISTORY_COMPARE_PICK"))
            local color = LJ.Tracker:IsCounted(run) and LJ.COLORS.green or LJ.COLORS.red
            row.bar:SetColorTexture(color[1], color[2], color[3], 0.85)
            row.bar:Show()
            local key = runStatusKey(run)
            if key and STATUS_COLORS[key] then
                local sc = STATUS_COLORS[key]
                row.status:SetColorTexture(sc[1], sc[2], sc[3], 1)
                row.status:Show()
            else
                row.status:Hide()
            end
            local name = W:Truncate(LJ:DungeonName(run), 22)
            if key then
                local sc = STATUS_COLORS[key] or LJ.COLORS.muted
                name = name .. " · " .. hex(sc) .. LJ.L(key) .. "|r"
            end
            row.label:SetText(name)
            row.badges:SetText(runBadges(run))
            row.date:SetText(LJ:FormatTime(run.started, "DATE_LONG"))
        end
    end
    self:ApplyTheme()
end

function H:ConfirmCleanup()
    if not LJ.Storage or not LJ.Tracker then return end
    local preview = LJ.Storage:Preview(LJ.Tracker:GetRuns(), LJ.Tracker:GetActive(), LJ.Now())
    if preview.eligible == 0 then
        LJ:Print(LJ.L("HISTORY_CLEANUP_NONE"))
        return
    end
    if type(StaticPopupDialogs) ~= "table" or type(StaticPopup_Show) ~= "function" then
        LJ:Print(LJ.L("HISTORY_CLEANUP_UNAVAILABLE"))
        return
    end
    StaticPopupDialogs.LOOTJINX_CLEANUP = {
        text = LJ.L("HISTORY_CLEANUP_CONFIRM", preview.eligible, LJ.Storage.AGE_DAYS),
        button1 = LJ.L("HISTORY_CLEANUP_ACCEPT"),
        button2 = LJ.L("REPORT_CANCEL"),
        OnAccept = function()
            local cleaned = LJ.Storage:Clean(LJ.Tracker:GetRuns(), LJ.Tracker:GetActive(), LJ.Now())
            if cleaned > 0 then
                LJ:Changed()
                LJ:Print(LJ.L("HISTORY_CLEANUP_DONE", cleaned))
            end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
    StaticPopup_Show("LOOTJINX_CLEANUP")
end

function H:Show(focus)
    if not self.frame then self:Create() end
    if not self.frame then return end
    if focus then
        self.focus = focus
        self.query, self.dungeon, self.dungeonKey, self.range, self.status = "", nil, nil, "all", "all"
        self.page, self.filterPage = 1, 1
        self:ClearComparison()
        if self.search then self.search:SetText("") end
        if self.menu then self.menu:Hide() end
        if self.dateMenu then self.dateMenu:Hide() end
        if self.statusMenu then self.statusMenu:Hide() end
    else
        self.focus = nil
    end
    self:Refresh()
    self.frame:Show()
end

function H:Hide() if self.frame then self.frame:Hide() end end
function H:IsShown() return self.frame and self.frame:IsShown() or false end
return H
