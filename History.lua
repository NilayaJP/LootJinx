-- Searchable dungeon run history shared by both dashboard designs.
local ADDON, ns = ...
local LJ = ns or _G.LootJinx
if not LJ then return end

local H = { query = "", dungeon = nil, page = 1, filterPage = 1, rows = {}, filterRows = {} }
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

function H:Filter(runs, query, dungeon)
    local result, needle = {}, normalized(query)
    for i = #(runs or {}), 1, -1 do
        local run = runs[i]
        local name = type(run) == "table" and tostring(run.name or "") or ""
        if type(run) == "table" and (not dungeon or name == dungeon)
            and (needle == "" or normalized(name):find(needle, 1, true)) then
            result[#result + 1] = run
        end
    end
    return result
end

function H:Dungeons(runs)
    local seen, names = {}, {}
    for i = 1, #(runs or {}) do
        local name = runs[i] and runs[i].name
        if type(name) == "string" and name ~= "" and not seen[name] then
            seen[name] = true
            names[#names + 1] = name
        end
    end
    table.sort(names, function(a, b) return normalized(a) < normalized(b) end)
    return names
end

function H:Summarize(runs)
    local stats = LJ.Stats.Compute(runs)
    return {
        runs = stats.totalDungeons or 0,
        statRuns = stats.agilityDungeons or 0,
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
    paint(self.summaryPanel, p.card, p.border)
    for _, f in ipairs(self.labels) do f:SetTextColor(rgba(p.text)) end
    for _, f in ipairs(self.mutedLabels) do f:SetTextColor(rgba(p.muted)) end
    self.title:SetTextColor(rgba(p.accent))
    self.summaryTitle:SetTextColor(rgba(p.accent))
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
    self.count = label(f, 10, "")
    self.count:SetPoint("TOPLEFT", 16, -40)
    self.mutedLabels[#self.mutedLabels + 1] = self.count
    local close = addButton(f, "×", 24, 24)
    close:SetPoint("TOPRIGHT", -14, -12)
    close:SetScript("OnClick", function() H:Hide() end)
    self.cleanupButton = addButton(f, "", 130, 24)
    self.cleanupButton:SetPoint("TOPRIGHT", -46, -12)
    self.cleanupButton:SetScript("OnClick", function() H:ConfirmCleanup() end)
    W:Tooltip(self.cleanupButton, LJ.L("HISTORY_CLEANUP_ACCEPT"),
        { LJ.L("HISTORY_CLEANUP_HINT") })

    self.search = CreateFrame("EditBox", nil, f, BackdropTemplateMixin and "BackdropTemplate" or nil)
    self.search:SetSize(278, 25)
    self.search:SetPoint("TOPLEFT", 16, -64)
    self.search:SetAutoFocus(false)
    self.search:SetFontObject("GameFontNormal")
    self.search:SetTextInsets(8, 8, 0, 0)
    self.search:SetText("")
    self.search:SetScript("OnTextChanged", function(edit)
        H.query = edit:GetText() or ""
        H.page = 1
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
            H.dungeon = self.dungeon
            H.page = 1
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
    self.summaryTitle:SetWidth(550)
    self.summaryLine1 = label(self.summaryPanel, 9, "")
    self.summaryLine1:SetPoint("TOPLEFT", 10, -22)
    self.summaryLine1:SetWidth(550)
    self.summaryLine2 = label(self.summaryPanel, 9, "")
    self.summaryLine2:SetPoint("TOPLEFT", 10, -37)
    self.summaryLine2:SetWidth(550)
    self.labels[#self.labels + 1] = self.summaryLine1
    self.labels[#self.labels + 1] = self.summaryLine2

    for i = 1, PAGE_SIZE do
        local row = addButton(f, "", 578, 31)
        row:SetPoint("TOPLEFT", 16, -162 - (i - 1) * 34)
        row.label:ClearAllPoints()
        row.label:SetPoint("LEFT", 10, 0)
        row.label:SetWidth(400)
        row.label:SetJustifyH("LEFT")
        row.date = label(row, 9, "")
        row.date:SetPoint("RIGHT", -10, 0)
        row.date:SetWidth(105)
        row.date:SetJustifyH("RIGHT")
        self.mutedLabels[#self.mutedLabels + 1] = row.date
        row:SetScript("OnClick", function(self)
            if self.run and not self.run.legacy and LJ.RunDetail then
                H.menu:Hide()
                LJ.RunDetail:Show(self.run, LJ.UI and LJ.UI:GetLayout())
            end
        end)
        self.rows[i] = row
    end
    self.empty = label(f, 10, LJ.L("HISTORY_EMPTY"))
    self.empty:SetPoint("CENTER", 0, -20)
    self.mutedLabels[#self.mutedLabels + 1] = self.empty
    self.pageText = label(f, 9, "")
    self.pageText:SetPoint("BOTTOM", 0, 16)
    self.mutedLabels[#self.mutedLabels + 1] = self.pageText
    self.prev = addButton(f, LJ.L("DETAIL_BACK"), 75, 22)
    self.prev:SetPoint("BOTTOMLEFT", 16, 12)
    self.prev:SetScript("OnClick", function() H.page = H.page - 1; H:Refresh() end)
    self.next = addButton(f, LJ.L("DETAIL_NEXT"), 75, 22)
    self.next:SetPoint("BOTTOMRIGHT", -16, 12)
    self.next:SetScript("OnClick", function() H.page = H.page + 1; H:Refresh() end)
    f:SetScript("OnShow", function() suspendDashboardEscape(); H:Refresh() end)
    f:SetScript("OnHide", function()
        H.menu:Hide()
        if LJ.RunDetail and LJ.RunDetail:IsShown() then LJ.RunDetail:Hide() end
        restoreDashboardEscape()
    end)
    if type(UISpecialFrames) == "table" then table.insert(UISpecialFrames, "LootJinxHistoryFrame") end
    f:Hide()
    LJ:RegisterRefresh(function() if f:IsShown() then H:Refresh() end end)
    return f
end

function H:RefreshFilterMenu()
    local options = { false }
    for _, name in ipairs(self:Dungeons(LJ.Tracker:GetRuns())) do options[#options + 1] = name end
    local pages = math.max(1, math.ceil(#options / FILTER_PAGE_SIZE))
    self.filterPage = math.max(1, math.min(self.filterPage, pages))
    for i, row in ipairs(self.filterRows) do
        local name = options[(self.filterPage - 1) * FILTER_PAGE_SIZE + i]
        row.dungeon = name or nil
        row.label:SetText(name == false and LJ.L("HISTORY_ALL_DUNGEONS") or name or "")
        row:SetShown(name ~= nil)
    end
    self.filterPageText:SetText(self.filterPage .. " / " .. pages)
    self.filterPrev:SetShown(self.filterPage > 1)
    self.filterNext:SetShown(self.filterPage < pages)
end

function H:Refresh()
    if not self.frame or not LJ.Tracker then return end
    local runs = LJ.Tracker:GetRuns()
    local matches = self:Filter(runs, self.query, self.dungeon)
    local preview = LJ.Storage:Preview(runs, LJ.Tracker:GetActive(), LJ.Now())
    self.cleanupButton.label:SetText(LJ.L("HISTORY_CLEANUP_BUTTON", preview.eligible))
    local summary = self:Summarize(matches)
    self.summaryTitle:SetText(LJ.L("HISTORY_SUMMARY_TITLE",
        W:Truncate(self.dungeon or LJ.L("HISTORY_ALL_DUNGEONS"), 55)))
    self.summaryLine1:SetText(LJ.L("HISTORY_SUMMARY_RUNS", summary.runs,
        summary.statRuns, summary.noLoot))
    self.summaryLine2:SetText(LJ.L("HISTORY_SUMMARY_NEED", summary.needWins,
        summary.needLost, summary.needPending))
    local pages = math.max(1, math.ceil(#matches / PAGE_SIZE))
    self.page = math.max(1, math.min(self.page, pages))
    self.filterButton.label:SetText(self.dungeon or LJ.L("HISTORY_ALL_DUNGEONS"))
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
            local name = W:Truncate(run.name or LJ.L("UNKNOWN_DUNGEON"), 48)
            row.label:SetText(name .. (run.legacy and "  ·  " .. LJ.L("HISTORY_LEGACY") or ""))
            row.date:SetText(date and date("%d.%m.%Y", run.started or 0) or "")
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

function H:Show()
    if not self.frame then self:Create() end
    if not self.frame then return end
    self:Refresh()
    self.frame:Show()
end

function H:Hide() if self.frame then self.frame:Hide() end end
function H:IsShown() return self.frame and self.frame:IsShown() or false end
return H
