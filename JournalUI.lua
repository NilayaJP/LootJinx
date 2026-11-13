-- LootJinx: optional Dungeon Journal layout for local preview.
local ADDON, ns = ...
local LJ = ns or _G.LootJinx
if not LJ then return end

local J = { tabs = {}, viewPanels = {}, fields = {}, recentRows = {} }
LJ.JournalUI = J

local W = LJ.Widgets
local WHITE = "Interface\\Buttons\\WHITE8X8"
local MEDIA = "Interface\\AddOns\\LootJinx\\Media\\"
local P = {
    leather = { 0.141, 0.102, 0.102, 0.98 },
    rail = { 0.286, 0.188, 0.176, 0.98 },
    page = { 0.190, 0.145, 0.133, 0.98 },
    inset = { 0.114, 0.086, 0.082, 0.96 },
    bronze = { 0.545, 0.384, 0.267, 1 },
    gold = { 0.918, 0.769, 0.494, 1 },
    parchment = { 0.906, 0.835, 0.729, 1 },
    muted = { 0.690, 0.608, 0.510, 1 },
    red = { 0.900, 0.420, 0.340, 1 },
}

local function rgba(c)
    return c[1], c[2], c[3], c[4] or 1
end

local function backdrop(f, background, border)
    if f.SetBackdrop then
        f:SetBackdrop({
            bgFile = WHITE, edgeFile = WHITE, edgeSize = 2,
            insets = { left = 2, right = 2, top = 2, bottom = 2 },
        })
        f:SetBackdropColor(rgba(background))
        f:SetBackdropBorderColor(rgba(border))
    end
end

local function panel(parent, x, y, width, height, background)
    local f = CreateFrame("Frame", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    f:SetPoint("TOPLEFT", x, y)
    f:SetSize(width, height)
    backdrop(f, background or P.page, P.bronze)
    return f
end

local function line(parent, x, y, width, height, color)
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetPoint("TOPLEFT", x, y)
    t:SetSize(width, height)
    t:SetColorTexture(rgba(color or P.bronze))
    return t
end

local function font(parent, size, color, text)
    local f = W:Font(parent, size, color or P.parchment, "")
    f:SetText(text or "")
    return f
end

local function heading(parent, size, color, text)
    local f = font(parent, size, color or P.gold, text)
    if f.SetFont then pcall(f.SetFont, f, "Fonts\\MORPHEUS.TTF", size, "") end
    return f
end

local function button(parent, text, width, height)
    local b = CreateFrame("Button", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    b:SetSize(width, height)
    backdrop(b, P.inset, P.bronze)
    b.label = font(b, 10, P.parchment, text)
    b.label:SetPoint("CENTER", 0, 0)
    b:SetScript("OnEnter", function(self)
        if self.SetBackdropColor then self:SetBackdropColor(rgba(P.rail)) end
    end)
    b:SetScript("OnLeave", function(self)
        if self.SetBackdropColor then self:SetBackdropColor(rgba(P.inset)) end
    end)
    return b
end

local metricKeys = {
    { label = "CARD_CURSE", current = "noAgiCurrent", record = "noAgiMax", field = "curseCurrent" },
    { label = "CARD_NEED", current = "lostNeedCurrent", record = "lostNeedMax", field = "needLostCurrent" },
    { label = "MINI_NO_WIN", current = "noNeedWinCurrent", record = "noNeedWinMax", field = "noNeedWinCurrent" },
    { label = "MINI_NO_LOOT", current = "noLootCurrent", record = "noLootMax", field = "noLootCurrent" },
    { label = "MINI_SINCE", current = "sinceNeedWinCurrent", record = "sinceNeedWinMax", field = "sinceWinCurrent" },
}

local function savePosition()
    if not J.frame or not LJ.DB then return end
    local point, _, relativePoint, x, y = J.frame:GetPoint(1)
    if point then
        LJ.DB.journalPoint = point
        LJ.DB.journalRelPoint = relativePoint or point
        LJ.DB.journalX = tonumber(x) or 0
        LJ.DB.journalY = tonumber(y) or -40
    end
end

local function applyPosition()
    if not J.frame or not LJ.DB then return end
    J.frame:ClearAllPoints()
    J.frame:SetPoint(LJ.DB.journalPoint or "CENTER", UIParent,
        LJ.DB.journalRelPoint or "CENTER",
        tonumber(LJ.DB.journalX) or 0, tonumber(LJ.DB.journalY) or -40)
end

local function makeTabs(rail)
    local tabData = {
        { id = "runs", key = "JOURNAL_TAB_RUNS" },
        { id = "curses", key = "JOURNAL_TAB_CURSES" },
        { id = "records", key = "JOURNAL_TAB_RECORDS" },
        { id = "share", key = "JOURNAL_TAB_SHARE" },
    }
    for i, tab in ipairs(tabData) do
        local b = button(rail, LJ.L(tab.key), 68, 51)
        b:SetPoint("TOPLEFT", 7, -15 - (i - 1) * 58)
        b:SetScript("OnClick", function() J:SelectTab(tab.id) end)
        J.tabs[tab.id] = b
    end
end

local function makeRuns(view)
    local latest = panel(view, 0, 0, 416, 187, P.page)
    J.latestPanel = latest
    J.fields.latestLabel = heading(latest, 14, P.gold, LJ.L("JOURNAL_LATEST"))
    J.fields.latestLabel:SetPoint("TOPLEFT", 16, -10)
    J.fields.latestName = heading(latest, 20, P.parchment, LJ.L("RECENT_EMPTY"))
    J.fields.latestName:SetPoint("TOPLEFT", 16, -36)
    J.fields.latestName:SetWidth(376)
    J.fields.latestName:SetWordWrap(false)
    J.fields.latestStatus = font(latest, 9, P.muted, "")
    J.fields.latestStatus:SetPoint("TOPLEFT", 17, -64)

    local art = latest:CreateTexture(nil, "ARTWORK")
    art:SetTexture(MEDIA .. "CurseChest")
    art:SetSize(90, 90)
    art:SetPoint("TOPLEFT", 16, -83)
    J.fields.latestArt = art

    J.fields.latestCurse = heading(latest, 40, P.gold, "0")
    J.fields.latestCurse:SetPoint("TOPLEFT", 119, -89)
    J.fields.latestCurseLabel = font(latest, 10, P.parchment, LJ.L("CARD_CURSE"))
    J.fields.latestCurseLabel:SetPoint("TOPLEFT", 120, -132)
    J.fields.latestNeed = font(latest, 10, P.muted, "")
    J.fields.latestNeed:SetPoint("TOPLEFT", 120, -153)

    local recent = panel(view, 0, -198, 416, 202, P.page)
    J.recentPanel = recent
    local recentTitle = heading(recent, 15, P.gold, LJ.L("RECENT"))
    recentTitle:SetPoint("TOPLEFT", 14, -9)
    line(recent, 14, -33, 388, 1, P.bronze)
    J.fields.recentEmpty = font(recent, 10, P.muted, LJ.L("RECENT_EMPTY"))
    J.fields.recentEmpty:SetPoint("TOPLEFT", 15, -52)
    J.fields.recentEmpty:SetWidth(385)
    for i = 1, 4 do
        local row = button(recent, "", 388, 31)
        row:SetPoint("TOPLEFT", 14, -40 - (i - 1) * 37)
        row.label:SetWidth(362)
        row.label:SetJustifyH("LEFT")
        row:SetScript("OnClick", function(self)
            if self.run and self.run.legacy ~= true and LJ.RunDetail then
                LJ.RunDetail:Show(self.run)
            end
        end)
        row:Hide()
        J.recentRows[i] = row
    end
end

local function makeMetricPage(view, isRecord)
    local title = heading(view, 20, P.gold, LJ.L(isRecord and "JOURNAL_TAB_RECORDS" or "JOURNAL_TAB_CURSES"))
    title:SetPoint("TOPLEFT", 8, -2)
    line(view, 8, -31, 398, 1, P.bronze)
    local rows = {}
    for i, item in ipairs(metricKeys) do
        local r = panel(view, 6, -41 - (i - 1) * 70, 404, 62, P.page)
        local label = font(r, 10, P.parchment, LJ.L(item.label))
        label:SetPoint("TOPLEFT", 12, -10)
        local value = heading(r, 25, P.gold, "0")
        value:SetPoint("TOPRIGHT", -14, -12)
        local sub = font(r, 9, P.muted, LJ.L(isRecord and "STREAK" or "RECORD"))
        sub:SetPoint("TOPLEFT", 12, -36)
        rows[i] = { value = value, sub = sub }
    end
    if isRecord then
        J.recordRows = rows
        local reset = button(view, LJ.L("RESET"), 80, 22)
        reset:SetPoint("BOTTOMRIGHT", -9, 4)
        reset:SetScript("OnClick", function()
            if LJ.UI and LJ.UI.ConfirmReset then LJ.UI:ConfirmReset() end
        end)
    else
        J.curseRows = rows
    end
end

local function makeShare(view)
    local title = heading(view, 20, P.gold, LJ.L("REPORT_TITLE"))
    title:SetPoint("TOPLEFT", 8, -2)
    line(view, 8, -31, 398, 1, P.bronze)
    local intro = font(view, 11, P.parchment, LJ.L("REPORT_SUB"))
    intro:SetPoint("TOPLEFT", 9, -49)
    local targetLabel = font(view, 10, P.muted, LJ.L("REPORT_WHISPER_LABEL"))
    targetLabel:SetPoint("TOPLEFT", 9, -104)
    local edit = CreateFrame("EditBox", nil, view, BackdropTemplateMixin and "BackdropTemplate" or nil)
    edit:SetSize(273, 28)
    edit:SetPoint("TOPLEFT", 9, -125)
    backdrop(edit, P.inset, P.bronze)
    edit:SetAutoFocus(false)
    edit:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 11, "")
    edit:SetTextInsets(8, 8, 0, 0)
    edit:SetText("")
    J.shareTarget = edit
    local party = button(view, LJ.L("REPORT_PARTY"), 123, 30)
    party:SetPoint("TOPLEFT", 9, -178)
    local whisper = button(view, LJ.L("REPORT_WHISPER"), 123, 30)
    whisper:SetPoint("TOPLEFT", 143, -178)
    local errorText = font(view, 10, P.red, "")
    errorText:SetPoint("TOPLEFT", 9, -222)
    errorText:SetWidth(390)
    J.fields.shareError = errorText
    local function send(channel, target)
        local sent, reason = LJ.Report:Send(channel, target)
        errorText:SetText(reason and LJ.L(reason) or "")
        if sent then edit:ClearFocus() end
    end
    party:SetScript("OnClick", function() send("PARTY") end)
    whisper:SetScript("OnClick", function() send("WHISPER", edit:GetText()) end)
    edit:SetScript("OnEnterPressed", function() send("WHISPER", edit:GetText()) end)
    J.shareParty, J.shareWhisper = party, whisper
end

function J:Create()
    if self.frame then return self.frame end
    if not LJ.DB or not LJ.Tracker or not CreateFrame then return nil end
    local f = CreateFrame("Frame", "LootJinxJournalFrame", UIParent,
        BackdropTemplateMixin and "BackdropTemplate" or nil)
    self.frame = f
    f:SetSize(760, 520)
    f:SetFrameStrata("DIALOG")
    f:SetFrameLevel(70)
    f:SetToplevel(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    if f.SetClampedToScreen then f:SetClampedToScreen(true) end
    backdrop(f, P.leather, P.bronze)
    applyPosition()

    line(f, 10, -7, 740, 2, P.gold)
    line(f, 10, -58, 740, 1, P.bronze)
    local title = heading(f, 24, P.gold, LJ.L("JOURNAL_TITLE"))
    title:SetPoint("TOPLEFT", 17, -13)
    local subtitle = font(f, 9, P.muted, LJ.L("JOURNAL_SUBTITLE"))
    subtitle:SetPoint("TOPLEFT", 18, -40)
    self.fields.status = font(f, 10, P.gold, "")
    self.fields.status:SetPoint("TOPRIGHT", -81, -20)

    local settings = button(f, "⚙", 27, 24)
    settings:SetPoint("TOPRIGHT", -44, -15)
    settings:SetScript("OnClick", function()
        if LJ.Options then LJ.Options:Open() end
    end)
    local close = button(f, "×", 27, 24)
    close:SetPoint("TOPRIGHT", -13, -15)
    close:SetScript("OnClick", function() J:Hide() end)

    local drag = CreateFrame("Frame", nil, f)
    drag:SetPoint("TOPLEFT", 0, 0)
    drag:SetSize(500, 56)
    drag:EnableMouse(true)
    drag:RegisterForDrag("LeftButton")
    drag:SetScript("OnDragStart", function()
        if LJ.DB and LJ.DB.locked then return end
        f:StartMoving()
    end)
    drag:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
        savePosition()
    end)

    local rail = panel(f, 12, -67, 84, 408, P.rail)
    makeTabs(rail)
    local content = CreateFrame("Frame", nil, f)
    content:SetPoint("TOPLEFT", 104, -67)
    content:SetSize(416, 408)
    for _, id in ipairs({ "runs", "curses", "records", "share" }) do
        local view = CreateFrame("Frame", nil, content)
        view:SetAllPoints()
        view:Hide()
        self.viewPanels[id] = view
    end
    makeRuns(self.viewPanels.runs)
    makeMetricPage(self.viewPanels.curses, false)
    makeMetricPage(self.viewPanels.records, true)
    makeShare(self.viewPanels.share)

    local records = panel(f, 530, -67, 218, 408, P.inset)
    local recordTitle = heading(records, 17, P.gold, LJ.L("JOURNAL_CURRENT_RECORDS"))
    recordTitle:SetPoint("TOPLEFT", 12, -12)
    line(records, 12, -42, 194, 1, P.bronze)
    for i, item in ipairs(metricKeys) do
        local y = -55 - (i - 1) * 65
        local label = font(records, 9, P.muted, LJ.L(item.label))
        label:SetPoint("TOPLEFT", 12, y)
        local current = heading(records, 23, P.parchment, "0")
        current:SetPoint("TOPLEFT", 12, y - 17)
        local record = font(records, 9, P.gold, "0")
        record:SetPoint("TOPRIGHT", -12, y - 23)
        self.fields[item.field] = current
        self.fields[item.field:gsub("Current$", "Record")] = record
    end
    self.fields.curseRecord = self.fields.curseRecord or font(records, 9, P.gold, "0")

    self.watermark = f:CreateTexture(nil, "BACKGROUND")
    self.watermark:SetTexture(MEDIA .. "LootJinxIcon")
    self.watermark:SetSize(150, 150)
    self.watermark:SetPoint("BOTTOMRIGHT", -18, 10)
    self.watermark:SetAlpha(0.07)
    local footer = font(f, 9, P.muted, LJ.L("FOOTER_HINT"))
    footer:SetPoint("BOTTOMLEFT", 17, 10)
    self.footer = footer

    f:SetScript("OnHide", function()
        if LJ.RunDetail then LJ.RunDetail:Hide() end
        if self.shareTarget then self.shareTarget:ClearFocus() end
    end)
    f:Hide()
    if type(UISpecialFrames) == "table" then
        table.insert(UISpecialFrames, "LootJinxJournalFrame")
    end
    self:SelectTab("runs")
    self:ApplyScale(LJ.DB.scale or 1)
    self:ApplyDisplayOptions()
    LJ:RegisterRefresh(function()
        if self.frame and self.frame:IsShown() then self:Refresh() end
    end)
    self:Refresh()
    return f
end

function J:SelectTab(id)
    if not self.frame then self:Create() end
    if not self.viewPanels[id] then return false end
    self.currentTab = id
    for name, view in pairs(self.viewPanels) do
        view:SetShown(name == id)
        local b = self.tabs[name]
        if b and b.SetBackdropColor then
            b:SetBackdropColor(rgba(name == id and P.page or P.inset))
        end
    end
    if id == "share" and self.shareTarget and self.shareTarget:GetText() == "" then
        self.shareTarget:SetText(LJ.Report:GetTargetName() or "")
    end
    return true
end

function J:Refresh()
    if not self.frame or not LJ.Stats or not LJ.Tracker then return end
    local runs = LJ.Tracker:GetRuns()
    local stats = LJ.Stats.Compute(runs)
    local latest = runs[#runs]
    self.fields.latestName:SetText(latest and latest.name or LJ.L("RECENT_EMPTY"))
    self.fields.latestStatus:SetText(latest and
        (latest.paused and LJ.L("STATUS_IDLE") or latest.closed and LJ.L("DETAIL_CLOSED") or LJ.L("STATUS_LIVE")) or "")
    self.fields.status:SetText(latest and (latest.closed and LJ.L("STATUS_READY") or LJ.L("STATUS_LIVE"))
        or LJ.L("STATUS_READY"))
    self.fields.latestCurse:SetText(tostring(stats.noAgiCurrent or 0))
    local latestNeeds = 0
    if latest then
        for _, need in ipairs(latest.needs or {}) do
            if need.result == "lost" then latestNeeds = latestNeeds + 1 end
        end
    end
    self.fields.latestNeed:SetText(LJ.L("CARD_NEED_LOST", latestNeeds))
    for i, item in ipairs(metricKeys) do
        local current = tonumber(stats[item.current]) or 0
        local record = tonumber(stats[item.record]) or 0
        self.fields[item.field]:SetText(tostring(current))
        local recordField = self.fields[item.field:gsub("Current$", "Record")]
        if recordField then recordField:SetText(LJ.L("JOURNAL_RECORD_VALUE", record)) end
        self.curseRows[i].value:SetText(tostring(current))
        self.curseRows[i].sub:SetText(LJ.L("JOURNAL_RECORD_VALUE", record))
        self.recordRows[i].value:SetText(tostring(record))
        self.recordRows[i].sub:SetText(LJ.L("JOURNAL_CURRENT_VALUE", current))
    end
    self.fields.recentEmpty:SetShown(#runs == 0)
    for i = 1, 4 do
        local row = self.recentRows[i]
        local run = runs[#runs - i + 1]
        row.run = run
        row:SetShown(run ~= nil)
        if run then
            local suffix = run.legacy and LJ.L("JOURNAL_LEGACY") or
                (run.closed and LJ.L("DETAIL_CLOSED") or LJ.L("STATUS_LIVE"))
            row.label:SetText(W:Truncate(run.name, 32) .. "  ·  " .. suffix)
        end
    end
end

function J:Show()
    if not self.frame then self:Create() end
    if not self.frame then return false end
    self:ApplyScale(LJ.DB and LJ.DB.scale or 1)
    self:ApplyDisplayOptions()
    self:Refresh()
    self.frame:Show()
    return true
end

function J:Hide()
    if self.frame then self.frame:Hide() end
end

function J:ApplyScale(scale)
    if not LJ.DB then return end
    scale = tonumber(scale) or LJ.DB.scale or 1
    if scale < 0.80 then scale = 0.80 end
    if scale > 1.30 then scale = 1.30 end
    LJ.DB.scale = scale
    if self.frame then self.frame:SetScale(scale) end
    return scale
end

function J:ApplyDisplayOptions()
    if not self.frame or not LJ.DB then return end
    local compact = LJ.DB.compact == true
    -- The three columns end at y=-475, so keep them inside the compact frame.
    self.frame:SetHeight(compact and 476 or 520)
    self.recentPanel:SetShown(not compact)
    self.watermark:SetShown(LJ.DB.showWatermark ~= false)
end

function J:ResetPosition()
    if not LJ.DB then return end
    LJ.DB.journalPoint = "CENTER"
    LJ.DB.journalRelPoint = "CENTER"
    LJ.DB.journalX = 0
    LJ.DB.journalY = -40
    applyPosition()
end

return J
