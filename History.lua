-- Searchable dungeon run history shared by both dashboard designs.
local ADDON, ns = ...
local LJ = ns or _G.LootJinx
if not LJ then return end

local H = { query = "", dungeon = nil, dungeonKey = nil, range = "all", status = "all", sort = "date",
    focus = nil, expanded = {},
    page = 1, filterPage = 1,
    rows = {}, filterRows = {}, advancedChoices = {} }
LJ.History = H
local W = LJ.Widgets
local PAGE_SIZE, FILTER_PAGE_SIZE, PRESET_PAGE_SIZE = 9, 8, 5
local REVIEW_MODES = {
    { key = "weekly", label = "HISTORY_WEEKLY_RECAP" },
    { key = "bookmarks", label = "HISTORY_BOOKMARKS" },
    { key = "quality", label = "HISTORY_NEED_QUALITY" },
}
local function rgba(c) return c[1], c[2], c[3], c[4] or 1 end
local function label(parent, size, text)
    local field = W:Font(parent, size, W:Skin().text, "")
    field:SetText(text or "")
    return field
end
-- WoW's Lua lowercases ASCII. Fold uppercase letters used in the supported
-- Latin and Cyrillic locales so they work in case-insensitive searches too.
local UTF8_LETTER = "[\194-\244][\128-\191]+"
local lowerCase = {}
do
    local lowerLetters = ("àáâãäåæçèéêëìíîïñòóôõöøœùúûüýÿšžß"
        .. "абвгдеёжзийклмнопрстуфхцчшщъыьэюя"):gmatch(UTF8_LETTER)
    for upper in ("ÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏÑÒÓÔÕÖØŒÙÚÛÜÝŸŠŽẞ"
        .. "АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ"):gmatch(UTF8_LETTER) do
        lowerCase[upper] = lowerLetters()
    end
end

local function normalized(text)
    return (string.lower(tostring(text or "")):gsub(UTF8_LETTER, lowerCase))
end

local function hex(c)
    return string.format("|cff%02x%02x%02x",
        math.floor((c[1] or 1) * 255),
        math.floor((c[2] or 1) * 255),
        math.floor((c[3] or 1) * 255))
end

local SORT_MODES = { "date", "dateAsc", "name", "wins", "losses" }
local SORT_LABELS = {
    date = "HISTORY_SORT_DATE",
    dateAsc = "HISTORY_SORT_DATE_ASC",
    name = "HISTORY_SORT_NAME",
    wins = "HISTORY_SORT_WINS",
    losses = "HISTORY_SORT_LOSSES",
}

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

local function runNeed(run)
    local total = #(run.needs or {})
    if total == 0 then return "—" end
    local wins, losses = needStats(run)
    local color = wins > 0 and LJ.COLORS.green or (losses == total and LJ.COLORS.red or LJ.COLORS.muted)
    return string.format("%s%d / %d|r", hex(color), wins, total)
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
        if includeWing and (includeWing ~= "shared" or (LJ.DungeonLoot and LJ.DungeonLoot:IsSharedMap(instanceID))) then
            local candidates = LJ.DungeonLoot and LJ.DungeonLoot:Candidates(run)
            local wing
            if candidates and #candidates == 1 then
                wing = candidates[1]
            elseif LJ.DungeonCompletion and (not candidates or #candidates > 1) then
                local progress = LJ.DungeonCompletion:Progress(run)
                wing = progress and progress.dungeon
            end
            if wing then return key .. ":" .. wing, wing end
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

local function knownDungeonIDs(runs, includeWing)
    local byName = {}
    for _, run in ipairs(runs or {}) do
        if type(run) == "table" and type(run.name) == "string" then
            local id = dungeonIdentity(run, includeWing)
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

local function filterKey(run, knownIDs, includeWing)
    local id = dungeonIdentity(run, includeWing)
    if id then return "id:" .. id end
    local name = type(run.name) == "string" and run.name or ""
    local group = knownIDs[name]
    if group and group.count == 1 then return "id:" .. group.sole end
    return "name:" .. name
end

local localDayStart = LJ.Stats.LocalDayStart

local function isBossClear(run)
    local completion = LJ.DungeonCompletion
    if completion then return completion:WasCleared(run) end
    return run.closedReason == "all-bosses-cleared"
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

function H:ResolvePresetDungeon(dungeon, rememberedKey, runs)
    local options = self:DungeonOptions(runs)
    local mapID = rememberedKey:match("^id:(%d+)$")
    if mapID and LJ.DungeonLoot and LJ.DungeonLoot:IsSharedMap(mapID) then
        local label = normalized(dungeon:gsub("%s+%b()%s*$", ""))
        local match
        for _, option in ipairs(options) do
            local wing = option.key:match("^id:" .. mapID .. ":(.+)$")
            if (wing or option.key == rememberedKey)
                and (label == normalized(option.displayName) or label == normalized(wing)) then
                if match then return nil end
                match = option
            end
        end
        return match
    end
    for _, option in ipairs(options) do
        if option.key == rememberedKey then return option end
    end

    local rememberedName = rememberedKey:match("^name:(.+)$")
    local name = rememberedName or dungeon:gsub("%s+%b()%s*$", "")
    local names = { [normalized(name)] = true, [normalized(LJ:DungeonName({ name = name }))] = true }
    local match
    for _, option in ipairs(options) do
        local legacy = option.key:match("^name:")
        if (rememberedName or legacy) and (names[normalized(option.name)] or names[normalized(option.displayName)]) then
            if match then return nil end
            match = option
        end
    end
    return match
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
    local searchMaps, searchIDs, nameMatches = {}, {}, {}
    if needle ~= "" then
        for _, candidate in ipairs(runs or {}) do
            if type(candidate) == "table" then
                local recordedMatch = normalized(candidate.name):find(needle, 1, true)
                if recordedMatch then
                    local key = dungeonIdentity(candidate)
                    if key then
                        searchMaps[key] = true
                        searchIDs[dungeonIdentity(candidate, true)] = true
                    end
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
    local knownIDs = knownDungeonIDs(runs, "shared")
    for i = #(runs or {}), 1, -1 do
        local run = runs[i]
        local started = type(run) == "table" and tonumber(run.started) or nil
        if type(run) == "table" and (not dungeon or (selectedKey
            and filterKey(run, knownIDs, "shared") == selectedKey))
            and (needle == "" or nameMatches[run]
                or (searchMaps[dungeonIdentity(run)] and searchIDs[dungeonIdentity(run, true)])
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
    local knownIDs = knownDungeonIDs(runs, "shared")
    for i = #(runs or {}), 1, -1 do
        local run = runs[i]
        local name = run and run.name
        local key = type(run) == "table" and filterKey(run, knownIDs, "shared") or nil
        if type(name) == "string" and name ~= "" and not seen[key] then
            seen[key] = true
            local _, wing = dungeonIdentity(run, "shared")
            local displayName = wing and LJ.DungeonLoot:DisplayName({ name = wing }, LJ.lang)
                or wing or LJ:DungeonName(run)
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

function H:GroupRuns(matches, runs)
    local groups, byKey = {}, {}
    local knownIDs = knownDungeonIDs(runs, true)
    for _, run in ipairs(matches) do
        local key = filterKey(run, knownIDs, true)
        local group = byKey[key]
        local stamp = tonumber(run.started) or 0
        if not group then
            group = { key = key, latest = stamp, name = LJ:DungeonName(run), runs = {}, wins = 0, rolls = 0 }
            groups[#groups + 1], byKey[key] = group, group
        elseif stamp > group.latest then
            group.latest, group.name = stamp, LJ:DungeonName(run)
        end
        group.runs[#group.runs + 1] = run
        group.wins = group.wins + needStats(run)
        group.rolls = group.rolls + #(run.needs or {})
    end
    return groups, byKey
end

function H:WeeklyNeed(runs)
    local weeks, byStart = {}, {}
    for _, run in ipairs(runs) do
        local stamp = tonumber(run.started)
        local start = stamp and stamp > 0 and localDayStart(stamp, 0, true) or 0
        local week = byStart[start]
        if not week then
            week = { start = start, wins = 0, losses = 0, pending = 0, rolls = 0 }
            weeks[#weeks + 1], byStart[start] = week, week
        end
        local won, lost = needStats(run)
        local total = #(run.needs or {})
        week.wins, week.losses = week.wins + won, week.losses + lost
        week.pending, week.rolls = week.pending + total - won - lost, week.rolls + total
    end
    table.sort(weeks, function(a, b) return a.start > b.start end)
    return weeks
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
    local function restore()
        if H.suspendedName == name or type(UISpecialFrames) ~= "table" then return end
        local dashboard = LJ.UI and LJ.UI.frame
        if LJ.RunDetail and LJ.RunDetail:IsShown() and dashboard and dashboard:GetName() == name then return end
        if LJ.Options and LJ.Options:KeepDashboardEscapeSuspended(name) then return end
        for i = 1, #UISpecialFrames do if UISpecialFrames[i] == name then return end end
        table.insert(UISpecialFrames, name)
    end
    if C_Timer and C_Timer.After then C_Timer.After(0, restore)
    else restore() end
end

function H:ApplyTheme()
    if not self.frame then return end
    local skin = W:Skin()
    if self.skin ~= skin then
        self.skin = skin
        W:StyleWindow(self.frame, skin, 60, 30)
        for _, control in ipairs({ self.search, self.presetName }) do
            W:StyleInput(control, skin)
        end
        for _, menu in ipairs({ self.menu, self.advancedMenu, self.presetMenu }) do
            W:Paint(menu, skin.bg, skin.border)
        end
        W:StyleWindow(self.comparePanel, skin, 39, 24)
        for _, panel in ipairs(self.compareCards) do W:Paint(panel, skin.surface, skin.border) end
        for _, field in ipairs(self.mutedLabels) do W:ColorText(field, skin.muted) end
        W:StyleCredit(self.creditLink, skin)
        W:SetTextFont(self.title, 20, "", skin.displayFont)
        W:ColorText(self.title, skin.text)
        W:SetTextFont(self.compareTitle, 16, "", skin.displayFont)
        W:ColorText(self.compareTitle, skin.text)
        for _, field in ipairs(self.compareColTitles) do W:ColorText(field, skin.accent) end
        for _, button in ipairs(self.buttons) do W:StyleButton(button, skin) end
        for i, row in ipairs(self.rows) do
            W:StyleListRow(row, skin, i % 2 == 1)
            row.separator:SetColorTexture(skin.border[1], skin.border[2], skin.border[3], .60)
            W:ColorTexture(row.hover, skin.hover)
            W:StyleCheck(row.compare, skin, row.compare.mark)
        end
    end
    for _, choice in ipairs(self.advancedChoices) do
        W:StyleButton(choice, skin, self[choice.field] == choice.value)
    end
    W:StyleButton(self.groupButton, skin,
        self.grouped and not (self.trend or self.bossView or self.lossRecord or self.review))
    for key, button in pairs(self.reviewButtons) do W:StyleButton(button, skin, self.review == key) end
    W:StyleButton(self.compareButton, skin, self.comparing)
    W:StyleButton(self.filterButton, skin, self.dungeon ~= nil)
    W:StyleButton(self.advancedButton, skin,
        self.query ~= "" or self.dungeon ~= nil or self.range ~= "all" or self.status ~= "all" or self.focus ~= nil)
    for _, row in ipairs(self.rows) do
        W:ColorText(row.label, (row.group or row.boss) and skin.accent or skin.text)
        local bookmarked = row.run and row.run.bookmarked == true
        W:StyleButton(row.bookmark, skin, bookmarked)
        for _, mark in ipairs(row.bookmark.marks) do
            W:ColorTexture(mark, bookmarked and skin.accent or skin.muted)
        end
    end
end
function H:Create()
    if self.frame then return self.frame end
    local f = CreateFrame("Frame", "LootJinxHistoryFrame", UIParent,
        BackdropTemplateMixin and "BackdropTemplate" or nil)
    self.frame = f
    f:SetSize(610, 546)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    f:SetFrameStrata("DIALOG")
    f:SetFrameLevel(150)
    f:SetToplevel(true)
    f:EnableMouse(true)
    if f.SetClampedToScreen then f:SetClampedToScreen(true) end
    local stopDragging = W:DragHeader(f, 36, 72)
    self.mutedLabels, self.buttons = {}, {}
    local function addButton(parent, text, w, h)
        local b = W:Button(parent, text, w, h)
        b:RegisterForClicks("LeftButtonUp")
        self.buttons[#self.buttons + 1] = b
        return b
    end
    local function toggleMenu(menu, otherMenu)
        otherMenu:Hide()
        H.presetMenu:Hide()
        if H.comparePanel:IsShown() then
            H:ClearComparison()
            H:Refresh()
        end
        menu:SetShown(not menu:IsShown())
    end
    self.title = label(f, 16, LJ.L("HISTORY_TITLE"))
    self.title:SetPoint("TOPLEFT", 56, -13)
    local legend = addButton(f, "?", 16, 16)
    legend:SetPoint("TOPRIGHT", -51, -16)
    W:Tooltip(legend, LJ.L("HISTORY_LEGEND_TITLE"), {
        LJ.L("HISTORY_LEGEND_STATUS"),
        LJ.L("HISTORY_NEED_LEGEND"),
    })
    self.count = label(f, 10, "")
    self.count:SetPoint("TOPLEFT", 56, -38)
    self.count:SetWidth(154)
    self.count:SetWordWrap(false)
    self.mutedLabels[#self.mutedLabels + 1] = self.count
    self.groupButton = addButton(f, "", 132, 19)
    self.groupButton:SetPoint("TOPLEFT", 218, -37)
    self.groupButton:SetScript("OnClick", function()
        if H.trend or H.bossView or H.lossRecord or H.review then
            H:CloseReview()
        else
            H.grouped = not H.grouped
            if LJ.DB then LJ.DB.historyGrouped = H.grouped end
            H.page = 1
            H:SetComparisonMode(false)
            return
        end
        H:Refresh()
    end)
    self.creditLink = W:ForeverDBCredit(f, function() H:Hide() end)
    self.creditLink:SetPoint("BOTTOMRIGHT", -16, 15)
    self.mutedLabels[#self.mutedLabels + 1] = self.creditLink.label
    local close = addButton(f, "×", 24, 24)
    W:WindowClose(close)
    close:SetScript("OnClick", function() H:Hide() end)
    self.search = CreateFrame("EditBox", nil, f, BackdropTemplateMixin and "BackdropTemplate" or nil)
    self.search:SetSize(178, 25)
    self.search:SetPoint("TOPLEFT", 16, -73)
    self.search:SetAutoFocus(false)
    self.search:SetFontObject("GameFontNormal")
    local _, searchFontSize, searchFontFlags = self.search:GetFont()
    W:SetTextFont(self.search, searchFontSize or 12, searchFontFlags, false)
    self.search:SetTextInsets(8, 8, 0, 0)
    self.search:SetText("")
    self.search:SetScript("OnTextChanged", function(edit)
        local query = edit:GetText() or ""
        if H.query == query then return end
        H.query = query
        H.page = 1
        H:ClearComparison()
        H:Refresh()
    end)
    self.search:SetScript("OnEnterPressed", function(edit) edit:ClearFocus() end)
    self.search:SetScript("OnEscapePressed", function(edit) edit:ClearFocus() end)
    self.searchLabel = label(f, 9, LJ.L("HISTORY_SEARCH"))
    self.searchLabel:SetPoint("BOTTOMLEFT", self.search, "TOPLEFT", 3, 2)
    self.mutedLabels[#self.mutedLabels + 1] = self.searchLabel

    self.filterButton = addButton(f, LJ.L("HISTORY_ALL_DUNGEONS"), 164, 25)
    self.filterButton:SetPoint("TOPLEFT", 202, -73)
    self.filterButton.label:SetWordWrap(false)
    self.filterButton:SetScript("OnClick", function()
        toggleMenu(H.menu, H.advancedMenu)
        if H.menu:IsShown() then H:RefreshFilterMenu() end
    end)
    self.filterLabel = label(f, 9, LJ.L("HISTORY_DUNGEON"))
    self.filterLabel:SetPoint("BOTTOMLEFT", self.filterButton, "TOPLEFT", 3, 2)
    self.mutedLabels[#self.mutedLabels + 1] = self.filterLabel
    self.menu = CreateFrame("Frame", nil, f, BackdropTemplateMixin and "BackdropTemplate" or nil)
    self.menu:SetSize(278, 250)
    self.menu:SetPoint("TOPLEFT", self.filterButton, "BOTTOMLEFT", 0, -2)
    self.menu:SetFrameLevel(f:GetFrameLevel() + 20)
    for i = 1, FILTER_PAGE_SIZE do
        local choice = addButton(self.menu, "", 264, 23)
        choice:SetPoint("TOPLEFT", 7, -6 - (i - 1) * 24)
        choice:SetScript("OnClick", function(self)
            H.dungeon, H.dungeonKey = self.dungeon, self.dungeonKey
            H.presetDungeon = nil
            H.trend, H.bossView = nil, nil
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

    self.advancedButton = addButton(f, "", 96, 25)
    self.advancedButton:SetPoint("TOPLEFT", 374, -73)
    self.advancedButton:SetScript("OnClick", function()
        toggleMenu(H.advancedMenu, H.menu)
    end)
    self.compareButton = addButton(f, LJ.L("HISTORY_COMPARE_PICK"), 116, 25)
    self.compareButton:SetPoint("TOPRIGHT", -16, -73)
    self.compareButton:SetScript("OnClick", function() H:SetComparisonMode(not H.comparing) end)
    self.advancedMenu = CreateFrame("Frame", nil, f, BackdropTemplateMixin and "BackdropTemplate" or nil)
    self.advancedMenu:SetSize(550, 207)
    self.advancedMenu:SetPoint("TOPRIGHT", self.compareButton, "BOTTOMRIGHT", 0, -4)
    self.advancedMenu:SetFrameLevel(f:GetFrameLevel() + 25)
    self.advancedMenu:EnableMouse(true)
    local groups = {
        { field = "range", title = "HISTORY_FILTER_PERIOD", values = { "all", "today", "week", "month" } },
        { field = "status", title = "HISTORY_FILTER_STATUS", values = { "all", "clear", "manual", "pending" } },
        { field = "sort", title = "HISTORY_SORT_TITLE", values = SORT_MODES, labels = SORT_LABELS },
    }
    for i, group in ipairs(groups) do
        local x = 12 + (i - 1) * 178
        local heading = label(self.advancedMenu, 10, LJ.L(group.title))
        heading:SetPoint("TOPLEFT", x + 2, -10)
        self.mutedLabels[#self.mutedLabels + 1] = heading
        for index, value in ipairs(group.values) do
            local key = group.labels and group.labels[value] or
                ("HISTORY_" .. (group.field == "range" and "DATE_" or "STATUS_") .. string.upper(value))
            local choice = addButton(self.advancedMenu, LJ.L(key), 170, 22)
            choice:SetPoint("TOPLEFT", x, -30 - (index - 1) * 26)
            choice.field, choice.value = group.field, value
            choice:SetScript("OnClick", function(selected)
                H[selected.field] = selected.value
                H.page = 1
                if selected.field ~= "sort" then H:ClearComparison() end
                H:Refresh()
            end)
            self.advancedChoices[#self.advancedChoices + 1] = choice
        end
    end
    self.resetFilters = addButton(self.advancedMenu, LJ.L("HISTORY_RESET_FILTERS"), 166, 24)
    self.resetFilters:SetPoint("BOTTOMLEFT", 12, 12)
    self.resetFilters:SetScript("OnClick", function() H:ResetFilters() end)
    self.presetsButton = addButton(self.advancedMenu, LJ.L("HISTORY_PRESETS"), 166, 24)
    self.presetsButton:SetPoint("BOTTOM", 0, 12)
    self.presetsButton:SetScript("OnClick", function()
        H.advancedMenu:Hide()
        H.presetStatus:SetText("")
        H.presetMenu:Show()
        H:RefreshPresets()
    end)
    self.cleanupButton = addButton(self.advancedMenu, "", 166, 24)
    self.cleanupButton:SetPoint("BOTTOMRIGHT", -12, 12)
    self.cleanupButton:SetScript("OnClick", function()
        H.advancedMenu:Hide()
        H:ConfirmCleanup()
    end)
    W:Tooltip(self.cleanupButton, LJ.L("HISTORY_CLEANUP_ACCEPT"), { LJ.L("HISTORY_CLEANUP_HINT") })
    self.advancedMenu:Hide()
    self.presetMenu = CreateFrame("Frame", nil, f, BackdropTemplateMixin and "BackdropTemplate" or nil)
    self.presetMenu:SetSize(354, 256)
    self.presetMenu:SetPoint("TOPRIGHT", self.compareButton, "BOTTOMRIGHT", 0, -4)
    self.presetMenu:SetFrameLevel(f:GetFrameLevel() + 26)
    self.presetMenu:EnableMouse(true)
    local presetTitle = label(self.presetMenu, 11, LJ.L("HISTORY_PRESETS"))
    presetTitle:SetPoint("TOPLEFT", 12, -12)
    local presetBack = addButton(self.presetMenu, LJ.L("HISTORY_FILTERS"), 86, 22)
    presetBack:SetPoint("TOPRIGHT", -12, -8)
    presetBack:SetScript("OnClick", function()
        H.presetMenu:Hide()
        H.advancedMenu:Show()
    end)
    local presetLabel = label(self.presetMenu, 9, LJ.L("HISTORY_PRESET_NAME"))
    presetLabel:SetPoint("TOPLEFT", 12, -38)
    self.mutedLabels[#self.mutedLabels + 1] = presetLabel
    self.presetName = CreateFrame("EditBox", nil, self.presetMenu, BackdropTemplateMixin and "BackdropTemplate" or nil)
    self.presetName:SetPoint("TOPLEFT", 12, -51)
    self.presetName:SetSize(238, 24)
    self.presetName:SetAutoFocus(false)
    self.presetName:SetMaxLetters(42)
    self.presetName:SetTextInsets(7, 7, 0, 0)
    W:SetTextFont(self.presetName, 11)
    self.presetName:SetScript("OnEscapePressed", function(edit) edit:ClearFocus() end)
    self.presetMenu:SetScript("OnHide", function() H.presetName:ClearFocus() end)
    self.presetSave = addButton(self.presetMenu, LJ.L("HISTORY_PRESET_SAVE"), 84, 24)
    self.presetSave:SetPoint("TOPRIGHT", -12, -51)
    local function savePreset()
        H:SavePreset(H.presetName:GetText())
        H.presetName:ClearFocus()
    end
    self.presetSave:SetScript("OnClick", savePreset)
    self.presetName:SetScript("OnEnterPressed", savePreset)
    self.presetStatus = label(self.presetMenu, 9, "")
    self.presetStatus:SetPoint("TOPLEFT", 12, -82)
    self.mutedLabels[#self.mutedLabels + 1] = self.presetStatus
    self.presetRows = {}
    for i = 1, PRESET_PAGE_SIZE do
        local loadButton = addButton(self.presetMenu, "", 298, 21)
        loadButton:SetPoint("TOPLEFT", 12, -100 - (i - 1) * 25)
        loadButton.label:SetWidth(284)
        loadButton.label:SetWordWrap(false)
        loadButton:SetScript("OnClick", function(b) H:ApplyPreset(b.index) end)
        local remove = addButton(self.presetMenu, "×", 24, 21)
        remove:SetPoint("LEFT", loadButton, "RIGHT", 8, 0)
        W:Tooltip(remove, LJ.L("HISTORY_PRESET_DELETE"))
        remove:SetScript("OnClick", function() H:DeletePreset(loadButton.index) end)
        self.presetRows[i] = { load = loadButton, remove = remove }
    end
    self.presetPrev = addButton(self.presetMenu, "<", 32, 19)
    self.presetPrev:SetPoint("BOTTOMLEFT", 12, 8)
    self.presetPrev:SetScript("OnClick", function() H.presetPage = H.presetPage - 1; H:RefreshPresets() end)
    self.presetNext = addButton(self.presetMenu, ">", 32, 19)
    self.presetNext:SetPoint("BOTTOMRIGHT", -12, 8)
    self.presetNext:SetScript("OnClick", function() H.presetPage = H.presetPage + 1; H:RefreshPresets() end)
    self.presetPageText = label(self.presetMenu, 9, "")
    self.presetPageText:SetPoint("BOTTOM", 0, 13)
    self.mutedLabels[#self.mutedLabels + 1] = self.presetPageText
    self.presetMenu:Hide()

    self.focusButton = addButton(f, "", 236, 18)
    self.focusButton:SetPoint("TOPRIGHT", -16, -37)
    self.focusButton:SetScript("OnClick", function()
        H.focus = nil
        H.presetFocus = nil
        H.page = 1
        H:ClearComparison()
        H:Refresh()
    end)
    W:Tooltip(self.focusButton, LJ.L("HISTORY_RESET_FILTERS"))
    self.focusButton:Hide()
    self.reviewButtons = {}
    for i, mode in ipairs(REVIEW_MODES) do
        local key = mode.key
        local button = addButton(f, LJ.L(mode.label), 138, 22)
        button:SetPoint("TOPLEFT", 16 + (i - 1) * 146, -105)
        button:SetScript("OnClick", function() H:ShowReview(key) end)
        self.reviewButtons[key] = button
    end
    self.summary = label(f, 10, "")
    self.summary:SetPoint("TOPLEFT", 16, -137)
    self.summary:SetWidth(578)
    self.summary:SetWordWrap(false)
    self.mutedLabels[#self.mutedLabels + 1] = self.summary

    self.streakContext = label(f, 9)
    self.streakContext:SetPoint("TOPLEFT", 16, -150)
    self.streakContext:SetWidth(578)
    self.streakContext:SetWordWrap(false)
    self.streakContext:Hide()
    self.mutedLabels[#self.mutedLabels + 1] = self.streakContext

    self.headerDungeon = label(f, 8, LJ.L("HISTORY_COL_DUNGEON"))
    self.headerDungeon:SetPoint("TOPLEFT", 38, -165)
    self.headerDungeon:SetWidth(546)
    self.headerNeed = label(f, 8, LJ.L("HISTORY_COL_NEED"))
    self.headerNeed:SetPoint("TOPLEFT", 370, -165)
    self.headerDate = label(f, 8, LJ.L("HISTORY_COL_DATE"))
    self.headerDate:SetPoint("TOPRIGHT", -26, -165)
    self.headerDate:SetJustifyH("RIGHT")
    self.mutedLabels[#self.mutedLabels + 1] = self.headerDungeon
    self.mutedLabels[#self.mutedLabels + 1] = self.headerNeed
    self.mutedLabels[#self.mutedLabels + 1] = self.headerDate

    for i = 1, PAGE_SIZE do
        local row = CreateFrame("Button", nil, f)
        row:RegisterForClicks("LeftButtonUp")
        row:SetSize(578, 35)
        row:SetPoint("TOPLEFT", 16, -180 - (i - 1) * 35)
        W:CreateFoldIndicator(row, 10)
        row.label = label(row, 11)
        row.label:SetPoint("LEFT", 22, 0)
        row.label:SetWidth(319)
        row.label:SetWordWrap(false)
        row.separator = row:CreateTexture(nil, "BACKGROUND")
        row.separator:SetPoint("BOTTOMLEFT")
        row.separator:SetPoint("BOTTOMRIGHT")
        row.separator:SetHeight(1)
        row.hover = row:CreateTexture(nil, "BACKGROUND")
        row.hover:SetAllPoints()
        row.hover:Hide()
        row.bar = row:CreateTexture(nil, "ARTWORK")
        row.bar:SetSize(2, 18)
        row.bar:SetPoint("LEFT", 0, 0)
        row.need = label(row, 10)
        row.need:SetPoint("LEFT", 354, 0)
        self.mutedLabels[#self.mutedLabels + 1] = row.need
        row.groupCount = label(row, 10)
        row.groupCount:SetPoint("LEFT", 212, 0)
        row.groupCount:SetWidth(66)
        row.groupCount:SetWordWrap(false)
        self.mutedLabels[#self.mutedLabels + 1] = row.groupCount
        row.trendValues = label(row, 10)
        row.trendValues:SetPoint("LEFT", 155, 0)
        row.trendValues:SetWidth(414)
        row.trendValues:SetWordWrap(false)
        self.mutedLabels[#self.mutedLabels + 1] = row.trendValues
        row.trend = addButton(row, LJ.L("HISTORY_TREND_SHORT"), 76, 20)
        row.trend:SetPoint("RIGHT", -101, 0)
        row.trend:SetScript("OnClick", function()
            if not row.group then return end
            H.menu:Hide()
            H.advancedMenu:Hide()
            H.trend = { key = row.group.key, name = row.group.name }
            H.groupPage, H.page = H.page, 1
            H:Refresh()
        end)
        row.trend:Hide()
        row.bossButton = addButton(row, LJ.L("HISTORY_BOSS_SHORT"), 68, 20)
        row.bossButton:SetPoint("LEFT", 282, 0)
        row.bossButton:SetScript("OnClick", function()
            if not row.group then return end
            H:HideMenus()
            H.bossView = { key = row.group.key, name = row.group.name, expanded = {} }
            H.groupPage, H.page = H.page, 1
            H:Refresh()
        end)
        row.bossButton:Hide()
        row.context = label(row, 9)
        row.context:SetPoint("LEFT", 22, -8)
        row.context:SetWidth(320)
        row.context:SetWordWrap(false)
        self.mutedLabels[#self.mutedLabels + 1] = row.context
        row.compare = CreateFrame("CheckButton", nil, row, BackdropTemplateMixin and "BackdropTemplate" or nil)
        row.compare:SetSize(20, 20)
        row.compare:SetPoint("RIGHT", -112, 0)
        row.compare.mark = row.compare:CreateTexture(nil, "ARTWORK")
        row.compare.mark:SetAllPoints()
        row.compare.mark:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
        row.compare:SetScript("OnClick", function()
            if row.run then
                H.menu:Hide()
                H.advancedMenu:Hide()
                H:SelectForComparison(row.run)
            end
        end)
        row.compare:Hide()
        row.bookmark = addButton(row, "", 23, 20)
        row.bookmark:SetPoint("RIGHT", -122, 0)
        local mark = row.bookmark:CreateTexture(nil, "ARTWORK")
        mark:SetSize(9, 7)
        mark:SetPoint("CENTER", 0, 2)
        row.bookmark.marks = { mark }
        for _, side in ipairs({ "LEFT", "RIGHT" }) do
            local tail = row.bookmark:CreateTexture(nil, "ARTWORK")
            tail:SetSize(3, 4)
            tail:SetPoint("TOP" .. side, mark, "BOTTOM" .. side)
            row.bookmark.marks[#row.bookmark.marks + 1] = tail
        end
        row.bookmark:SetScript("OnClick", function()
            if not row.run then return end
            row.run.bookmarked = row.run.bookmarked ~= true or nil
            if GameTooltip then GameTooltip:Hide() end
            H:Refresh()
        end)
        row.bookmark:Hide()
        row.date = label(row, 9, "")
        row.date:SetPoint("RIGHT", -10, 0)
        row.date:SetWidth(88)
        row.date:SetJustifyH("RIGHT")
        self.mutedLabels[#self.mutedLabels + 1] = row.date
        W:UseTextSize(row.label, "list", 11)
        W:UseTextSize(row.need, "list", 10)
        W:UseTextSize(row.groupCount, "list", 10)
        W:UseTextSize(row.trendValues, "list", 10)
        W:UseTextSize(row.context, "list", 9)
        W:UseTextSize(row.date, "list", 9)
        row:SetScript("OnClick", function(self)
            H:HideMenus()
            if self.boss then
                local expanded = H.bossView.expanded
                expanded[self.boss.key] = not expanded[self.boss.key] or nil
                H:Refresh()
                return
            end
            if self.group then
                H.expanded[self.group.key] = not H.expanded[self.group.key] or nil
                H:Refresh()
                return
            end
            if not self.run then return end
            if H.comparing then
                H:SelectForComparison(self.run)
            elseif not self.run.legacy and LJ.RunDetail then
                LJ.RunDetail:Show(self.run, LJ.UI and LJ.UI:GetLayout())
            end
        end)
        row:SetScript("OnEnter", function(self)
            self.hover:SetShown(self.group ~= nil or self.boss ~= nil or self.run ~= nil)
            if self.run and LJ.ShowRecentTooltip then LJ:ShowRecentTooltip(self, self.run) end
        end)
        row:SetScript("OnLeave", function(self)
            self.hover:Hide()
            if GameTooltip then GameTooltip:Hide() end
        end)
        self.rows[i] = row
    end
    self.empty = label(f, 10, LJ.L("HISTORY_EMPTY"))
    self.empty:SetPoint("CENTER", 0, -20)
    self.mutedLabels[#self.mutedLabels + 1] = self.empty
    self.pageText = label(f, 9, "")
    self.pageText:SetPoint("BOTTOM", f, "BOTTOMLEFT", 111, 19)
    self.mutedLabels[#self.mutedLabels + 1] = self.pageText
    self.prev = addButton(f, "<", 54, 22)
    self.prev:SetPoint("BOTTOMLEFT", 16, 12)
    W:Tooltip(self.prev, LJ.L("DETAIL_PREV"))
    self.prev:SetScript("OnClick", function() H.page = H.page - 1; H:Refresh() end)
    self.next = addButton(f, ">", 54, 22)
    self.next:SetPoint("BOTTOMLEFT", 152, 12)
    W:Tooltip(self.next, LJ.L("DETAIL_NEXT"))
    self.next:SetScript("OnClick", function() H.page = H.page + 1; H:Refresh() end)
    if LJ.CharacterOverview then
        self.characterButton = addButton(f, LJ.L("CHARACTER_OVERVIEW_BUTTON"), 118, 22)
        self.characterButton:SetPoint("BOTTOMLEFT", 216, 12)
        self.characterButton:SetScript("OnClick", function() H:ToggleCharacters() end)
    end
    self.comparePanel = CreateFrame("Frame", nil, f,
        BackdropTemplateMixin and "BackdropTemplate" or nil)
    self.comparePanel:SetSize(560, 240)
    self.comparePanel:SetPoint("CENTER", f, "CENTER", 0, 0)
    self.comparePanel:SetFrameLevel(f:GetFrameLevel() + 40)
    self.comparePanel:EnableMouse(true)
    self.compareTitle = label(self.comparePanel, 14, "")
    self.compareTitle:SetPoint("TOPLEFT", 50, -11)
    self.compareTitle:SetWidth(460)
    local compareClose = addButton(self.comparePanel, "×", 24, 22)
    W:WindowClose(compareClose)
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
    f:Hide()
    f:SetScript("OnShow", function()
        suspendDashboardEscape()
        if LJ.RunDetail and LJ.RunDetail:IsShown() then LJ.RunDetail:SuspendParentEscape() end
        H:Refresh()
    end)
    f:SetScript("OnHide", function()
        stopDragging()
        H.menu:Hide()
        H.advancedMenu:Hide()
        H.presetMenu:Hide()
        if LJ.CharacterOverview and LJ.CharacterOverview.panel then LJ.CharacterOverview.panel:Hide() end
        H.comparing = false
        H:CloseReview()
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
    self.compareMismatch = nil
    if self.comparePanel then self.comparePanel:Hide() end
end

function H:HideMenus()
    self.menu:Hide()
    self.advancedMenu:Hide()
    self.presetMenu:Hide()
end

function H:CloseReview()
    if self.review then
        self.page = self.reviewPage or 1
    elseif self.lossRecord then
        self.page = self.recordPage or 1
    elseif self.trend or self.bossView then
        self.page = self.groupPage or 1
    end
    self.trend, self.bossView, self.lossRecord, self.record, self.review = nil, nil, nil, nil, nil
end

function H:ShowReview(mode)
    if self.review == mode then return end
    if not self.review then
        self:CloseReview()
        self.reviewPage = self.page
    end
    self.review, self.page = mode, 1
    self:HideMenus()
    self.search:ClearFocus()
    if LJ.RunDetail then LJ.RunDetail:Hide() end
    self.comparing = false
    self:ClearComparison()
    self:Refresh()
end

function H:ShowLossRecord()
    if not self:IsShown() then self:Show() end
    if not self.frame then return end
    if not self.lossRecord then
        self:CloseReview()
        self.recordPage = self.page
        self.page = 1
    end
    self:HideMenus()
    self.search:ClearFocus()
    if LJ.RunDetail then LJ.RunDetail:Hide() end
    if LJ.CharacterOverview and LJ.CharacterOverview.panel then LJ.CharacterOverview.panel:Hide() end
    self.comparing = false
    self:ClearComparison()
    self.lossRecord = true
    self:Refresh()
end

local function choice(value, options, fallback)
    for _, option in ipairs(options) do
        if option == value then return value end
    end
    return fallback
end

function H:SavePreset(name)
    local presets = LJ.DB.historyPresets
    name = type(name) == "string" and name:match("^%s*(.-)%s*$") or ""
    if name == "" then
        self.presetStatus:SetText(LJ.L("HISTORY_PRESET_NAME_REQUIRED"))
        return false
    end
    local entry = {
        name = name, query = self.query, dungeon = self.dungeon, dungeonKey = self.dungeonKey,
        range = self.range, status = self.status, sort = self.sort, focus = self.focus,
    }
    local index = #presets + 1
    for i, preset in ipairs(presets) do
        if type(preset) == "table" and normalized(preset.name) == normalized(name) then
            index = i
            break
        end
    end
    presets[index] = entry
    self.presetPage = math.ceil(index / PRESET_PAGE_SIZE)
    self.presetStatus:SetText(LJ.L("HISTORY_PRESET_SAVED"))
    self:RefreshPresets()
    return true
end

function H:ApplyPreset(index)
    local preset = index and LJ.DB.historyPresets[index]
    if type(preset) ~= "table" or type(preset.name) ~= "string" then return false end
    self.query = type(preset.query) == "string" and preset.query or ""
    self.dungeon = type(preset.dungeon) == "string" and preset.dungeon ~= "" and preset.dungeon or nil
    self.dungeonKey = type(preset.dungeonKey) == "string" and preset.dungeonKey or nil
    self.presetDungeon = self.dungeon ~= nil
    self.range = choice(preset.range, { "all", "today", "week", "month" }, "all")
    self.status = choice(preset.status, { "all", "clear", "manual", "pending" }, "all")
    self.sort = choice(preset.sort, SORT_MODES, "date")
    self.focus = choice(preset.focus, { "noNeedWin", "noLoot", "sinceNeedWin" })
    self.presetFocus = self.focus ~= nil
    if self.review ~= "quality" then self:CloseReview() end
    self.page, self.filterPage = 1, 1
    self:ClearComparison()
    self.search:SetText(self.query)
    self.presetMenu:Hide()
    self:Refresh()
    return true
end

function H:DeletePreset(index)
    local presets = LJ.DB.historyPresets
    if not index or not presets[index] then return end
    table.remove(presets, index)
    self.presetStatus:SetText("")
    self:RefreshPresets()
end

function H:RefreshPresets()
    local presets = LJ.DB.historyPresets
    local pages = math.max(1, math.ceil(#presets / PRESET_PAGE_SIZE))
    self.presetPage = math.max(1, math.min(self.presetPage or 1, pages))
    for i, row in ipairs(self.presetRows) do
        local index = (self.presetPage - 1) * PRESET_PAGE_SIZE + i
        local preset = presets[index]
        local name = type(preset) == "table" and type(preset.name) == "string" and preset.name or nil
        row.load.index = name and index or nil
        row.load:SetShown(name ~= nil)
        row.remove:SetShown(name ~= nil)
        if name then row.load.label:SetText((name:gsub("|", "||"))) end
    end
    self.presetPrev:SetShown(self.presetPage > 1)
    self.presetNext:SetShown(self.presetPage < pages)
    self.presetPageText:SetShown(pages > 1)
    self.presetPageText:SetText(self.presetPage .. " / " .. pages)
end

function H:ToggleCharacters()
    local overview = LJ.CharacterOverview
    local panel = overview:Create(self.frame)
    if panel:IsShown() then
        panel:Hide()
    else
        self.menu:Hide()
        self.advancedMenu:Hide()
        self.presetMenu:Hide()
        self:ClearComparison()
        self.search:ClearFocus()
        if LJ.RunDetail then LJ.RunDetail:Hide() end
        panel:Show()
    end
    self:Refresh()
end

function H:ResetFilters()
    self.query, self.dungeon, self.dungeonKey, self.range, self.status = "", nil, nil, "all", "all"
    self.focus, self.sort = nil, "date"
    if self.review ~= "quality" then self:CloseReview() end
    self.presetDungeon, self.presetFocus = nil, nil
    self.page, self.filterPage = 1, 1
    self:ClearComparison()
    if self.search then self.search:SetText("") end
    if self.menu then self.menu:Hide() end
    if self.advancedMenu then self.advancedMenu:Hide() end
    if self.presetMenu then self.presetMenu:Hide() end
    self:Refresh()
end

function H:ShowComparison(first, second)
    local data = self:ComparisonData(first, second)
    if not data or not self.comparePanel then return false end
    self.compareTitle:SetText(LJ.L("HISTORY_COMPARE_TITLE",
        W:Truncate(LJ:DungeonName(first), 37)))
    for i, run in ipairs({ data.first, data.second }) do
        local column = self.compareValues[i]
        local when = LJ:FormatTime(run.started, "DATE_TIME")
        column.date:SetText(LJ.L("HISTORY_COMPARE_DATE", when))
        W:ColorText(column.date, W:Skin().muted)
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
    self.compareMismatch = nil
    if self.compareA == run then
        self.compareA, self.compareB = self.compareB, nil
        self.comparePanel:Hide()
    elseif self.compareB == run then
        self.compareB = nil
        self.comparePanel:Hide()
    elseif not self.compareA then
        self.compareA = run
    elseif not sameDungeon(self.compareA, run, true) then
        self.compareMismatch = true
        self:Refresh()
        return false
    else
        self.compareB = run
    end
    self:Refresh()
    return true
end

function H:SetComparisonMode(enabled)
    self.comparing = enabled
    self:CloseReview()
    if self.grouped then self.page = 1 end
    self.menu:Hide()
    self.advancedMenu:Hide()
    self.presetMenu:Hide()
    self:ClearComparison()
    self:Refresh()
end

function H:VisibleEntries(matches, runs, recap)
    local entries = {}
    if self.review == "quality" then
        for _, quality in ipairs(LJ.Stats.NeedByQuality(matches)) do
            entries[#entries + 1] = { quality = quality }
        end
        return entries, matches
    elseif self.review == "weekly" or self.review == "bookmarks" then
        local selected = {}
        if self.review == "weekly" then
            for _, run in ipairs(recap.weekRuns) do selected[#selected + 1] = run end
        else
            local saved = LJ.CharDB and LJ.CharDB.runs or runs
            for _, run in ipairs(saved) do
                if run.bookmarked == true then selected[#selected + 1] = run end
            end
        end
        sortMatches(selected, "date")
        for _, run in ipairs(selected) do entries[#entries + 1] = { run = run } end
        return entries, selected
    end
    if self.lossRecord then
        local record = LJ.Stats.Compute(runs, true).longestLossSeries
        self.record = record
        if record then
            for _, loss in ipairs(record.losses) do
                entries[#entries + 1] = { roll = loss, run = loss.run }
            end
            if record.winner then entries[#entries + 1] = { roll = record.winner, run = record.winner.run } end
        end
        return entries, runs
    end
    if self.grouped and not self.comparing then
        local groups, byKey = self:GroupRuns(matches, runs)
        local review = self.trend or self.bossView
        if review then
            local group = byKey[review.key]
            local visits = group and group.runs or {}
            if self.trend then
                for _, week in ipairs(self:WeeklyNeed(visits)) do
                    entries[#entries + 1] = { week = week }
                end
            else
                for _, boss in ipairs(LJ.RunDetail:BossStatistics(visits)) do
                    entries[#entries + 1] = { boss = boss, visits = #visits }
                    if self.bossView.expanded[boss.key] then
                        for _, item in ipairs(boss.items) do
                            entries[#entries + 1] = { bossItem = item, nested = true }
                        end
                    end
                end
            end
            return entries, visits
        end
        for _, group in ipairs(groups) do
            entries[#entries + 1] = { group = group }
            if self.expanded[group.key] then
                for _, run in ipairs(group.runs) do
                    entries[#entries + 1] = { run = run, nested = true }
                end
            end
        end
    else
        for _, run in ipairs(matches) do
            entries[#entries + 1] = { run = run }
        end
    end
    return entries, matches
end

local function trendCounts(wins, losses, pending)
    local resolved = wins + losses
    local rate = resolved > 0 and ("%d%%"):format(math.floor(wins * 100 / resolved + 0.5)) or "–"
    return LJ.L("HISTORY_TREND_RESULT", rate, wins, resolved, pending)
end

local function streakContext(record)
    local first, last, missingDate
    local runs, seen = {}, {}
    for _, loss in ipairs(record.losses) do
        local at = tonumber(loss.need.at)
        if at and at > 0 then
            first, last = math.min(first or at, at), math.max(last or at, at)
        else
            missingDate = true
        end
        if not seen[loss.run] then
            seen[loss.run] = true
            runs[#runs + 1] = loss.run
        end
    end
    local knownIDs = knownDungeonIDs(runs, true)
    local dungeons, count = {}, 0
    for _, run in ipairs(runs) do
        local key = filterKey(run, knownIDs, true)
        if not dungeons[key] then dungeons[key], count = true, count + 1 end
    end
    local period = LJ.L("HISTORY_TREND_UNDATED")
    if first and not missingDate then
        local start, finish = LJ:FormatTime(first, "DATE_LONG"), LJ:FormatTime(last, "DATE_LONG")
        period = start == finish and start or start .. " – " .. finish
    end
    return LJ.L("HISTORY_STREAK_CONTEXT", period, count)
end

local function summaryItemName(item)
    if type(item.link) == "string" then
        local name = item.link:match("%[(.-)%]")
        if name and name ~= "" then return name end
    end
    local id = tonumber(item.id)
    if not id then return LJ.L("HISTORY_STREAK_ITEM_MISSING") end
    local info = LJ:ItemInfo(id)
    return info and info.name or LJ.L("DETAIL_ITEM_UNKNOWN", id)
end

function H:RenderEntry(row, entry)
    local run, group, week = entry.run, entry.group, entry.week
    local boss, item, roll = entry.boss, entry.bossItem, entry.roll
    local quality = entry.quality
    local withContext = boss or item or roll
    local expanded = group and self.expanded[group.key]
        or (boss and self.bossView.expanded[boss.key])
    W:SetFoldIndicator(row, (group or boss) and W:Skin().accent or nil, expanded)
    row.run, row.group, row.boss = run, group, boss
    row.compare:SetShown(run ~= nil and self.comparing == true)
    row.bookmark:SetShown(run ~= nil and not roll and not self.comparing
        and (run.bookmarked == true or run.closed or LJ.Tracker:IsCounted(run)))
    row.bar:SetShown(run ~= nil and roll == nil)
    row.trend:SetShown(group ~= nil)
    row.bossButton:SetShown(group ~= nil)
    row.groupCount:SetShown(group ~= nil)
    row.need:SetShown(not (week or boss or item or quality))
    row.date:SetShown(not (week or boss or item or quality))
    row.trendValues:SetShown(week ~= nil or quality ~= nil)
    row.context:SetShown(withContext ~= nil)
    row.label:ClearAllPoints()
    local x = entry.nested and 36 or 22
    row.label:SetPoint("LEFT", x, withContext and 7 or 0)
    row.label:SetWidth((week or quality) and 126 or (group and 183 or (entry.nested and 305 or 319)))
    if withContext then
        row.context:ClearAllPoints()
        row.context:SetPoint("LEFT", x, -8)
        row.context:SetWidth(roll and 319 or 532)
    end
    if roll then
        local need = roll.need
        row.label:SetText(summaryItemName(need))
        row.context:SetText(LJ:DungeonName(run) .. " · " .. LJ.L(need.result == "won"
            and "HISTORY_STREAK_ENDING_WIN" or "DETAIL_NEED_LOST"))
        row.need:SetText(tonumber(need.roll) or "—")
        local at = tonumber(need.at)
        row.date:SetText(LJ:FormatTime(at and at > 0 and at or run.started, "DATE_LONG"))
    elseif run then
        local bookmarked = run.bookmarked == true
        W:Tooltip(row.bookmark, LJ.L(bookmarked and "HISTORY_BOOKMARK_REMOVE" or "HISTORY_BOOKMARK_ADD"))
        local checked = run == self.compareA or run == self.compareB
        row.compare:SetChecked(checked)
        row.compare.mark:SetShown(checked)
        local marker, color = LJ:RunStatusMarker(run)
        W:ColorTexture(row.bar, color)
        local name = LJ:DungeonName(run)
        if marker then name = name .. " · " .. marker end
        if run.legacy then
            name = name .. " · " .. hex(LJ.COLORS.muted) .. LJ.L("HISTORY_LEGACY") .. "|r"
        end
        row.label:SetText(name)
        row.need:SetText(runNeed(run))
        row.date:SetText(LJ:FormatTime(run.started, "DATE_LONG"))
    elseif group then
        row.label:SetText(group.name)
        row.groupCount:SetText(LJ.L("HISTORY_GROUP_COUNT", #group.runs))
        row.need:SetText(group.rolls > 0 and ("%d / %d"):format(group.wins, group.rolls) or "—")
        row.date:SetText(LJ:FormatTime(group.latest, "DATE_LONG"))
    elseif week then
        local date = week.start > 0 and LJ:FormatTime(week.start, "DATE_LONG")
        row.label:SetText(date and LJ.L("HISTORY_TREND_WEEK", date) or LJ.L("HISTORY_TREND_UNDATED"))
        row.trendValues:SetText(trendCounts(week.wins, week.losses, week.pending))
    elseif quality then
        local key = quality.quality and "NEED_QUALITY_" .. quality.quality or "NEED_QUALITY_UNKNOWN"
        local name = LJ.L(key)
        row.label:SetText(name ~= key and name or LJ.L("NEED_QUALITY_UNKNOWN"))
        row.trendValues:SetText(trendCounts(quality.wins, quality.losses, quality.pending))
    elseif boss then
        row.label:SetText(boss.name)
        row.context:SetText(LJ.L("HISTORY_BOSS_TOTALS", boss.visits, entry.visits, boss.drops) .. " · "
            .. LJ.L("HISTORY_BOSS_NEED", boss.won, boss.lost, boss.pending))
    elseif item then
        row.label:SetText(summaryItemName(item))
        row.context:SetText(LJ.L("HISTORY_BOSS_ITEM_DROPS", item.count) .. " · "
            .. LJ.L("HISTORY_BOSS_NEED", item.won, item.lost, item.pending))
    end
end

function H:Refresh()
    if not self.frame or not LJ.Tracker then return end
    local overview = LJ.CharacterOverview
    local showingCharacters = overview and overview.panel and overview.panel:IsShown()
    if self.characterButton then
        self.characterButton.label:SetText(LJ.L(showingCharacters and "CHARACTER_OVERVIEW_BACK" or "CHARACTER_OVERVIEW_BUTTON"))
    end
    for _, button in pairs(self.reviewButtons) do button:SetShown(not showingCharacters) end
    if showingCharacters then
        self.prev:Hide()
        self.next:Hide()
        self.pageText:Hide()
        self:ApplyTheme()
        overview:Refresh()
        return
    end
    self.pageText:Show()
    local runs, now = LJ.Tracker:GetRuns(), LJ.Now()
    local weekly, bookmarks, quality = self.review == "weekly", self.review == "bookmarks", self.review == "quality"
    local ignoreFilters = self.lossRecord or weekly or bookmarks
    local recap = weekly and LJ.Stats.WeeklyRecap(runs, now)
    if self.compareA then
        local foundA, foundB = false, false
        for _, run in ipairs(runs) do
            if run == self.compareA then foundA = true end
            if run == self.compareB then foundB = true end
        end
        if not foundA or (self.compareB and
            (not foundB or not self:ShowComparison(self.compareA, self.compareB))) then
            self:ClearComparison()
        end
    end
    local unavailableDungeon, filterDungeonKey = false, self.dungeonKey
    if not ignoreFilters and self.dungeon and self.presetDungeon and self.dungeonKey then
        local option = self:ResolvePresetDungeon(self.dungeon, self.dungeonKey, runs)
        unavailableDungeon = option == nil
        if option then
            self.dungeon = option.label
            filterDungeonKey = option.key
        end
    elseif not ignoreFilters and self.dungeon then
        local key = self:ResolveDungeonKey(self.dungeon, runs, self.dungeonKey)
        if key then
            self.dungeonKey, filterDungeonKey = key, key
        elseif not self.presetDungeon then
            -- Der gewählte Dungeon existiert nicht mehr (z. B. nach dem Aufräumen):
            -- Filter zurücksetzen, statt eine leere Liste ohne Erklärung zu zeigen.
            self.dungeon, self.dungeonKey = nil, nil
            if not quality then self:CloseReview() end
            self.page, self.filterPage = 1, 1
        else
            unavailableDungeon = true
        end
    end
    local matches = ignoreFilters and runs or (unavailableDungeon and {} or
        self:Filter(runs, self.query, self.dungeon, self.range, now, self.status, filterDungeonKey))
    local entries, visibleRuns = self:VisibleEntries(matches, runs, recap)
    local preview = LJ.Storage:Preview(runs, LJ.Tracker:GetActive(), now)
    self.cleanupButton.label:SetText(LJ.L("HISTORY_CLEANUP_BUTTON", preview.eligible))
    local summary = self:Summarize(visibleRuns)
    if quality then
        summary.needWins, summary.needLost, summary.needPending = 0, 0, 0
        for _, entry in ipairs(entries) do
            local bucket = entry.quality
            summary.needWins = summary.needWins + bucket.wins
            summary.needLost = summary.needLost + bucket.losses
            summary.needPending = summary.needPending + bucket.pending
        end
    end
    local trend, bossView, lossRecord = self.trend, self.bossView, self.lossRecord
    self.streakContext:SetShown(weekly or (lossRecord == true and self.record ~= nil))
    local header, empty = "HISTORY_COL_DUNGEON", "HISTORY_EMPTY"
    if unavailableDungeon then empty = "HISTORY_PRESET_NO_DUNGEON" end
    if lossRecord then
        self.summary:SetText(LJ.L("HISTORY_STREAK_TITLE", self.record and #self.record.losses or 0))
        if self.record then self.streakContext:SetText(streakContext(self.record)) end
        header = not self.record and "HISTORY_STREAK_ITEM"
            or self.record.winner and "HISTORY_STREAK_CLOSED" or "HISTORY_STREAK_ONGOING"
        empty = "HISTORY_STREAK_EMPTY"
    elseif weekly then
        self.summary:SetText(LJ.L("HISTORY_WEEKLY_RECAP_RUNS", recap.runs) .. "   ||   " ..
            LJ.L("HISTORY_SUMMARY_NEED", recap.wins, recap.losses, recap.pending))
        self.streakContext:SetText(recap.newRecord and LJ.L("HISTORY_WEEKLY_RECAP_RECORD", recap.newRecord) or
            LJ.L("HISTORY_WEEKLY_RECAP_NO_RECORD"))
    elseif bossView then
        self.summary:SetText(LJ.L("HISTORY_BOSS_TITLE", bossView.name, LJ.L("HISTORY_DATE_" .. string.upper(self.range))))
        header, empty = "HISTORY_BOSS_HINT", "HISTORY_BOSS_EMPTY"
    elseif trend then
        self.summary:SetText(LJ.L("HISTORY_TREND_TITLE", trend.name,
            LJ.L("HISTORY_DATE_" .. string.upper(self.range))))
        self.headerDungeon:SetText(trendCounts(summary.needWins, summary.needLost, summary.needPending))
    elseif self.comparing then
        self.summary:SetText(self.compareMismatch and LJ.L("HISTORY_COMPARE_SAME_DUNGEON") or
            LJ.L("HISTORY_COMPARE_PROGRESS", self.compareB and 2 or (self.compareA and 1 or 0)))
    else
        self.summary:SetText(LJ.L("HISTORY_SUMMARY_RUNS", summary.runs, summary.noLoot) .. "   ||   " ..
            LJ.L("HISTORY_SUMMARY_NEED", summary.needWins, summary.needLost, summary.needPending))
    end
    if bookmarks then
        empty = "HISTORY_BOOKMARKS_EMPTY"
    elseif quality then
        header = "HISTORY_NEED_QUALITY_COLUMN"
        if not unavailableDungeon then empty = "HISTORY_NEED_QUALITY_EMPTY" end
    end
    if not trend then self.headerDungeon:SetText(LJ.L(header)) end
    self.headerDungeon:SetWidth(lossRecord and 315 or 546)
    self.headerNeed:SetText(LJ.L(lossRecord and "HISTORY_STREAK_ROLL" or "HISTORY_COL_NEED"))
    self.headerNeed:SetShown(not (trend or bossView or quality))
    self.headerDate:SetShown(not (trend or bossView or quality))
    local groupKey = (lossRecord or self.review) and "CHARACTER_OVERVIEW_BACK" or
        (trend or bossView) and "HISTORY_TREND_BACK" or
        (self.grouped and not self.comparing and "HISTORY_GROUP_FLAT" or "HISTORY_GROUP_TOGGLE")
    self.groupButton.label:SetText(LJ.L(groupKey))
    self.groupButton:SetShown(not self.comparing)
    self.count:SetShown(not lossRecord)
    self.search:SetShown(not ignoreFilters)
    self.searchLabel:SetShown(not ignoreFilters)
    self.filterButton:SetShown(not ignoreFilters)
    self.filterLabel:SetShown(not ignoreFilters)
    self.advancedButton:SetShown(not ignoreFilters)
    self.compareButton:SetShown(not (ignoreFilters or quality))
    local pages = math.max(1, math.ceil(#entries / PAGE_SIZE))
    self.page = math.max(1, math.min(self.page, pages))
    self.filterButton.label:SetText(self.dungeon or LJ.L("HISTORY_ALL_DUNGEONS"))
    local activeFilters = (self.query ~= "" and 1 or 0) + (self.dungeon and 1 or 0)
        + (self.range ~= "all" and 1 or 0) + (self.status ~= "all" and 1 or 0) + (self.focus and 1 or 0)
    self.advancedButton.label:SetText(activeFilters > 0 and LJ.L("HISTORY_FILTER_COUNT", activeFilters)
        or LJ.L("HISTORY_FILTERS"))
    self.compareButton.label:SetText(LJ.L(self.comparing and "HISTORY_COMPARE_DONE" or "HISTORY_COMPARE_PICK"))
    local focusLabels = { noNeedWin = "MINI_NO_WIN", noLoot = "MINI_NO_LOOT", sinceNeedWin = "MINI_SINCE" }
    if self.focusButton then
        local focusKey = focusLabels[self.focus]
        self.focusButton:SetShown(not ignoreFilters and focusKey ~= nil)
        if focusKey then
            self.focusButton.label:SetText(LJ.L("HISTORY_FOCUS_CHIP", LJ.L(focusKey)))
        end
    end
    self.count:SetText(weekly and LJ.L("HISTORY_TREND_WEEK", LJ:FormatTime(recap.start, "DATE_LONG")) or
        LJ.L("HISTORY_COUNT", #visibleRuns, preview.savedRuns))
    self.empty:SetText(LJ.L(empty))
    self.empty:SetShown(#entries == 0)
    self.pageText:SetText(self.page .. " / " .. pages)
    self.prev:SetShown(self.page > 1)
    self.next:SetShown(self.page < pages)
    for i, row in ipairs(self.rows) do
        local entry = entries[(self.page - 1) * PAGE_SIZE + i]
        self:RenderEntry(row, entry or {})
        row:SetShown(entry ~= nil)
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
    StaticPopupDialogs.LOOTJINX_CLEANUP = W:StylePopup({
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
    })
    StaticPopup_Show("LOOTJINX_CLEANUP")
end

function H:Show(focus)
    if not self.frame then self:Create() end
    if not self.frame then return end
    if not self.frame:IsShown() then
        self.grouped = LJ.DB and LJ.DB.historyGrouped == true
        local dashboard = LJ.UI and LJ.UI.frame
        local anchor = dashboard and dashboard:IsShown() and dashboard or UIParent
        self.frame:ClearAllPoints()
        self.frame:SetPoint("CENTER", anchor, "CENTER", 0, 0)
    end
    if focus then
        self:CloseReview()
        self.presetDungeon, self.presetFocus = nil, nil
        self.focus = focus
        self.query, self.dungeon, self.dungeonKey, self.range, self.status = "", nil, nil, "all", "all"
        self.page, self.filterPage = 1, 1
        self:ClearComparison()
        if self.search then self.search:SetText("") end
        if self.menu then self.menu:Hide() end
        if self.advancedMenu then self.advancedMenu:Hide() end
        self.presetMenu:Hide()
        if LJ.CharacterOverview and LJ.CharacterOverview.panel then LJ.CharacterOverview.panel:Hide() end
    elseif not self.presetFocus then
        self.focus = nil
    end
    self:Refresh()
    self.frame:Show()
end

function H:Hide() if self.frame then self.frame:Hide() end end
function H:IsShown() return self.frame and self.frame:IsShown() or false end
return H
