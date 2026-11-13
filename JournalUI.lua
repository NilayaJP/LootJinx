-- Classic dashboard geometry with an independent Dungeon Journal skin.
local ADDON, ns = ...
local LJ = ns or _G.LootJinx
if not LJ then return end

local J = { fields = {}, recentRows = {}, miniCards = {} }
LJ.JournalUI = J
local W = LJ.Widgets
local WHITE = "Interface\\Buttons\\WHITE8X8"
local MEDIA = "Interface\\AddOns\\LootJinx\\Media\\"
local P = {
    leather = { 0.141, 0.102, 0.102, 0.98 },
    page = { 0.190, 0.145, 0.133, 0.98 },
    inset = { 0.114, 0.086, 0.082, 0.96 },
    bronze = { 0.545, 0.384, 0.267, 1 },
    gold = { 0.918, 0.769, 0.494, 1 },
    parchment = { 0.906, 0.835, 0.729, 1 },
    muted = { 0.690, 0.608, 0.510, 1 },
    red = { 0.900, 0.420, 0.340, 1 },
}
local function rgba(c) return c[1], c[2], c[3], c[4] or 1 end
local function backdrop(f, bg)
    if not f.SetBackdrop then return end
    f:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 2,
        insets = { left = 2, right = 2, top = 2, bottom = 2 } })
    f:SetBackdropColor(rgba(bg or P.page))
    f:SetBackdropBorderColor(rgba(P.bronze))
end
local function card(parent, x, y, width, height)
    local f = CreateFrame("Frame", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    f:SetPoint("TOPLEFT", x, y)
    f:SetSize(width, height)
    backdrop(f)
    return f
end
local function font(parent, size, color, text)
    local f = W:Font(parent, size, color or P.parchment, "")
    f:SetText(text or "")
    return f
end
local function heading(parent, size, text)
    local f = font(parent, size, P.gold, text)
    if f.SetFont then pcall(f.SetFont, f, "Fonts\\MORPHEUS.TTF", size, "") end
    return f
end
local function button(parent, label, width, height)
    local b = CreateFrame("Button", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    b:SetSize(width, height)
    b:RegisterForClicks("LeftButtonUp")
    backdrop(b, P.inset)
    b.label = font(b, 10, P.parchment, label)
    b.label:SetPoint("CENTER", 0, 0)
    b:SetScript("OnEnter", function(self) self:SetBackdropColor(rgba(P.page)) end)
    b:SetScript("OnLeave", function(self) self:SetBackdropColor(rgba(P.inset)) end)
    return b
end
local function icon(parent, texture, x, y, size)
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetTexture(MEDIA .. texture)
    t:SetPoint("TOPLEFT", x, y)
    t:SetSize(size, size)
    return t
end
local function position()
    local db = LJ.DB
    if not J.frame or not db then return end
    J.frame:ClearAllPoints()
    J.frame:SetPoint(db.journalPoint or "CENTER", UIParent,
        db.journalRelPoint or "CENTER", tonumber(db.journalX) or 0, tonumber(db.journalY) or -40)
end
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
local function metric(parent, title, texture)
    icon(parent, texture, 14, -9, 36)
    local label = heading(parent, 12, title)
    label:SetPoint("TOPLEFT", 62, -10)
    local value = heading(parent, 27, "0")
    value:SetPoint("TOPLEFT", 62, -29)
    local sub = font(parent, 10, P.muted, "")
    sub:SetPoint("TOPLEFT", 117, -35)
    local extra = font(parent, 9, P.muted, "")
    extra:SetPoint("TOPLEFT", 63, -68)
    local streak = font(parent, 10, P.parchment, "")
    streak:SetPoint("TOPRIGHT", -108, -86)
    local record = font(parent, 10, P.gold, "")
    record:SetPoint("TOPRIGHT", -14, -86)
    return { title = label, value = value, sub = sub, extra = extra,
        streak = streak, record = record }
end
local function mini(parent, x, title, texture)
    local f = card(parent, x, -312, 192, 108)
    icon(f, texture, 150, -8, 30)
    f.title = heading(f, 10, title)
    f.title:SetPoint("TOPLEFT", 12, -10)
    f.value = heading(f, 26, "0")
    f.value:SetPoint("TOPLEFT", 12, -28)
    f.sub = font(f, 9, P.muted, "")
    f.sub:SetPoint("TOPLEFT", 12, -64)
    f.sub:SetWidth(168)
    f.footer = font(f, 9, P.gold, "")
    f.footer:SetPoint("TOPLEFT", 12, -87)
    f.footer:SetWidth(168)
    return f
end
local function makeRecent(f)
    local recent = card(f, 16, -430, 608, 148)
    J.recentPanel = recent
    local title = heading(recent, 13, LJ.L("RECENT"))
    title:SetPoint("TOPLEFT", 14, -8)
    J.fields.recentEmpty = font(recent, 10, P.muted, LJ.L("RECENT_EMPTY"))
    J.fields.recentEmpty:SetPoint("CENTER", 0, -6)
    for i = 1, 4 do
        local row = button(recent, "", 584, 24)
        row:SetPoint("TOPLEFT", 12, -28 - (i - 1) * 25)
        row.label:Hide()
        row.name = font(row, 10, P.parchment, "")
        row.name:SetPoint("LEFT", 10, 0)
        row.name:SetWidth(260)
        row.name:SetWordWrap(false)
        row.badges = font(row, 9, P.muted, "")
        row.badges:SetPoint("LEFT", 274, 0)
        row.badges:SetWidth(220)
        row.badges:SetWordWrap(false)
        row.date = font(row, 9, P.muted, "")
        row.date:SetPoint("RIGHT", 0, 0)
        row.date:SetWidth(62)
        row.date:SetJustifyH("RIGHT")
        row:SetScript("OnClick", function(self)
            if self.run and self.run.legacy ~= true and LJ.RunDetail then
                LJ.RunDetail:Show(self.run, "journal")
            end
        end)
        row:Hide()
        J.recentRows[i] = row
    end
end
local function makeReport(f)
    local popup = CreateFrame("Frame", nil, f, BackdropTemplateMixin and "BackdropTemplate" or nil)
    popup:SetSize(320, 150)
    popup:SetPoint("CENTER", f, "CENTER", 0, 10)
    popup:SetFrameLevel(f:GetFrameLevel() + 20)
    backdrop(popup)
    J.reportPopup = popup
    local title = heading(popup, 13, LJ.L("REPORT_TITLE"))
    title:SetPoint("TOPLEFT", 14, -10)
    local close = button(popup, "×", 20, 20)
    close:SetPoint("TOPRIGHT", -10, -8)
    close:SetScript("OnClick", function() popup:Hide() end)
    local targetLabel = font(popup, 10, P.muted, LJ.L("REPORT_WHISPER_LABEL"))
    targetLabel:SetPoint("TOPLEFT", 14, -48)
    local edit = CreateFrame("EditBox", nil, popup, BackdropTemplateMixin and "BackdropTemplate" or nil)
    edit:SetSize(196, 24)
    edit:SetPoint("TOPLEFT", 108, -42)
    backdrop(edit, P.inset)
    edit:SetAutoFocus(false)
    edit:SetMaxLetters(64)
    edit:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 10, "")
    edit:SetTextInsets(8, 8, 0, 0)
    J.shareTarget = edit
    J.fields.shareError = font(popup, 9, P.red, "")
    J.fields.shareError:SetPoint("TOPLEFT", 14, -73)
    J.fields.shareError:SetWidth(290)
    local function send(channel, target)
        local sent, reason = LJ.Report:Send(channel, target)
        J.fields.shareError:SetText(reason and LJ.L(reason) or "")
        if sent then popup:Hide(); edit:ClearFocus() end
        return sent
    end
    edit:SetScript("OnEnterPressed", function() send("WHISPER", edit:GetText()) end)
    edit:SetScript("OnEscapePressed", function() edit:ClearFocus(); popup:Hide() end)
    local party = button(popup, LJ.L("REPORT_PARTY"), 90, 22)
    party:SetPoint("BOTTOMLEFT", 14, 14)
    party:SetScript("OnClick", function() send("PARTY") end)
    local whisper = button(popup, LJ.L("REPORT_WHISPER"), 90, 22)
    whisper:SetPoint("BOTTOMLEFT", 114, 14)
    whisper:SetScript("OnClick", function() send("WHISPER", edit:GetText()) end)
    local cancel = button(popup, LJ.L("REPORT_CANCEL"), 90, 22)
    cancel:SetPoint("BOTTOMRIGHT", -14, 14)
    cancel:SetScript("OnClick", function() popup:Hide() end)
    J.shareParty, J.shareWhisper = party, whisper
    popup:Hide()
end
function J:Create()
    if self.frame then return self.frame end
    if not LJ.DB or not LJ.Tracker then return nil end
    local f = CreateFrame("Frame", "LootJinxJournalFrame", UIParent,
        BackdropTemplateMixin and "BackdropTemplate" or nil)
    self.frame = f
    f:SetSize(640, 628)
    f:SetFrameStrata("DIALOG")
    f:SetFrameLevel(70)
    f:SetToplevel(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    if f.SetClampedToScreen then f:SetClampedToScreen(true) end
    backdrop(f, P.leather)
    position()
    local top = f:CreateTexture(nil, "ARTWORK")
    top:SetPoint("TOPLEFT", 1, -1)
    top:SetPoint("TOPRIGHT", -1, -1)
    top:SetHeight(2)
    top:SetColorTexture(rgba(P.gold))
    icon(f, "LootJinxIcon", 16, -12, 38)
    local title = heading(f, 20, LJ.L("TITLE"))
    title:SetPoint("TOPLEFT", 64, -12)
    local subtitle = font(f, 10, P.muted, LJ.L("SUBTITLE"))
    subtitle:SetPoint("TOPLEFT", 65, -35)
    self.fields.status = font(f, 10, P.gold, "")
    self.fields.status:SetPoint("TOPRIGHT", -68, -20)
    local settings = button(f, "", 22, 22)
    settings:SetPoint("TOPRIGHT", -40, -14)
    local gear = settings:CreateTexture(nil, "ARTWORK")
    gear:SetSize(14, 14)
    gear:SetPoint("CENTER", 0, 0)
    gear:SetTexture("Interface\\Icons\\INV_Misc_Gear_01")
    settings:SetScript("OnClick", function() if LJ.Options then LJ.Options:Open() end end)
    self.settingsButton = settings
    local close = button(f, "×", 22, 22)
    close:SetPoint("TOPRIGHT", -14, -14)
    close:SetScript("OnClick", function() J:Hide() end)
    local drag = CreateFrame("Frame", nil, f)
    drag:SetPoint("TOPLEFT", 0, 0)
    drag:SetSize(300, 58)
    drag:EnableMouse(true)
    drag:RegisterForDrag("LeftButton")
    drag:SetScript("OnDragStart", function() if not LJ.DB.locked then f:StartMoving() end end)
    drag:SetScript("OnDragStop", function() f:StopMovingOrSizing(); savePosition() end)

    self.hero = card(f, 16, -68, 608, 116)
    local hero = metric(self.hero, LJ.L("CARD_CURSE"), "CurseChest")
    hero.sub:ClearAllPoints()
    hero.sub:SetPoint("TOPLEFT", 63, -59)
    self.hero.metric = hero
    self.needCard = card(f, 16, -194, 608, 108)
    local need = metric(self.needCard, LJ.L("CARD_NEED"), "NeedRolls")
    self.needCard.metric = need
    self.miniCards[1] = mini(f, 16, LJ.L("MINI_NO_WIN"), "NoNeedWin")
    self.miniCards[2] = mini(f, 224, LJ.L("MINI_NO_LOOT"), "NoLoot")
    self.miniCards[3] = mini(f, 432, LJ.L("MINI_SINCE"), "SinceNeedWin")
    makeRecent(f)
    self.fields.curseCurrent, self.fields.curseRecord = hero.streak, hero.record
    self.fields.needLostCurrent = need.streak
    self.fields.noNeedWinCurrent = self.miniCards[1].value
    self.fields.noLootCurrent = self.miniCards[2].value
    self.fields.sinceWinCurrent = self.miniCards[3].value

    local divider = f:CreateTexture(nil, "ARTWORK")
    divider:SetPoint("BOTTOMLEFT", 16, 42)
    divider:SetPoint("BOTTOMRIGHT", -16, 42)
    divider:SetHeight(1)
    divider:SetColorTexture(rgba(P.bronze))
    self.footer = font(f, 9, P.muted, LJ.L("FOOTER_HINT"))
    self.footer:SetPoint("BOTTOMLEFT", 16, 16)
    self.footer:SetWidth(310)
    self.historyButton = button(f, LJ.L("HISTORY"), 72, 20)
    self.historyButton:SetPoint("BOTTOMRIGHT", -228, 14)
    self.historyButton:SetScript("OnClick", function() if LJ.History then LJ.History:Show() end end)
    self.reportButton = button(f, LJ.L("REPORT"), 72, 20)
    self.reportButton:SetPoint("BOTTOMRIGHT", -148, 14)
    self.reportButton:SetScript("OnClick", function() J:ShowReport() end)
    self.helpButton = button(f, LJ.L("HELP"), 58, 20)
    self.helpButton:SetPoint("BOTTOMRIGHT", -82, 14)
    self.helpButton:SetScript("OnClick", function() LJ:PrintHelp() end)
    self.resetButton = button(f, LJ.L("RESET"), 58, 20)
    self.resetButton:SetPoint("BOTTOMRIGHT", -16, 14)
    self.resetButton:SetScript("OnClick", function() if LJ.UI then LJ.UI:ConfirmReset() end end)
    self.watermark = f:CreateTexture(nil, "BACKGROUND")
    self.watermark:SetTexture(MEDIA .. "LootJinxIcon")
    self.watermark:SetSize(110, 110)
    self.watermark:SetPoint("BOTTOMRIGHT", -18, 44)
    self.watermark:SetAlpha(0.07)
    makeReport(f)
    f:SetScript("OnHide", function()
        self.reportPopup:Hide()
        if LJ.History then LJ.History:Hide() end
        if LJ.RunDetail then LJ.RunDetail:Hide() end
        self.shareTarget:ClearFocus()
    end)
    f:Hide()
    if type(UISpecialFrames) == "table" then table.insert(UISpecialFrames, "LootJinxJournalFrame") end
    self:ApplyScale(LJ.DB.scale or 1)
    self:ApplyDisplayOptions()
    LJ:RegisterRefresh(function() if f:IsShown() then J:Refresh() end end)
    self:Refresh()
    return f
end
function J:Refresh()
    if not self.frame or not LJ.Stats or not LJ.Tracker then return end
    local runs = LJ.Tracker:GetRuns()
    local stats = LJ.Stats.Compute(runs)
    local active = LJ.Tracker:GetActive()
    local live = LJ.Tracker:IsLive()
    local latest = runs[#runs]
    self.fields.status:SetText(active and (live and LJ.L("STATUS_LIVE") or LJ.L("STATUS_IDLE"))
        or latest and latest.paused and LJ.L("STATUS_IDLE") or LJ.L("STATUS_READY"))
    local hero, need = self.hero.metric, self.needCard.metric
    hero.value:SetText(string.format("%d / %d", stats.noAgiDungeons or 0, stats.totalDungeons or 0))
    hero.sub:SetText(LJ.L("CARD_CURSE_SUB", select(2, LJ:PlayerStat()) or ""))
    hero.extra:SetText(LJ.L("JOURNAL_CURSE_TOTAL", stats.noAgiDungeons or 0, stats.totalDungeons or 0))
    hero.streak:SetText(LJ.L("JOURNAL_CURRENT_VALUE", stats.noAgiCurrent or 0))
    hero.record:SetText(LJ.L("JOURNAL_RECORD_VALUE", stats.noAgiMax or 0))
    need.value:SetText(tostring(stats.needLost or 0))
    need.sub:SetText(LJ.L("JOURNAL_NEED_TOTAL", stats.needRolls or 0,
        stats.needWins or 0, stats.needLost or 0))
    need.extra:SetText(LJ.L("JOURNAL_NEED_EXTRA", stats.needPending or 0,
        math.floor((stats.winRate or 0) + 0.5), stats.lostNeedMax or 0))
    need.streak:SetText(LJ.L("JOURNAL_CURRENT_VALUE", stats.lostNeedCurrent or 0))
    need.record:SetText(LJ.L("JOURNAL_RECORD_VALUE", stats.lostNeedMax or 0))
    local values = {
        { stats.noNeedWinDungeons, stats.noNeedWinCurrent, stats.noNeedWinMax,
            LJ.L("JOURNAL_NO_WIN_TOTAL", stats.noNeedWinDungeons or 0, stats.needDungeons or 0) },
        { stats.noLootDungeons, stats.noLootCurrent, stats.noLootMax,
            LJ.L("JOURNAL_NO_LOOT_TOTAL", stats.noLootDungeons or 0, stats.totalDungeons or 0) },
        { stats.sinceNeedWinCurrent, stats.sinceNeedWinCurrent, stats.sinceNeedWinMax,
            LJ.L("JOURNAL_SINCE_NOTE") },
    }
    for i = 1, 3 do
        local m, v = self.miniCards[i], values[i]
        m.value:SetText(tostring(v[1] or 0))
        m.sub:SetText(v[4])
        m.footer:SetText(LJ.L("JOURNAL_CURRENT_VALUE", v[2] or 0)
            .. " · " .. LJ.L("JOURNAL_RECORD_VALUE", v[3] or 0))
    end
    self.fields.recentEmpty:SetShown(#runs == 0)
    for i = 1, 4 do
        local row = self.recentRows[i]
        local run = runs[#runs - i + 1]
        row.run = run
        row:SetShown(run ~= nil)
        if run then
            local totalNeeds, wins = 0, 0
            for _, n in ipairs(run.needs or {}) do
                totalNeeds = totalNeeds + 1
                if n.result == "won" then wins = wins + 1 end
            end
            local stat = run.agilityDropped and LJ.L("YES") or LJ.L("NO")
            local badges = LJ.L("TT_RUN_AGI", stat)
            if totalNeeds > 0 then badges = badges .. " · " .. LJ.L("BADGE_NEED", wins, totalNeeds) end
            if run.legacy then badges = badges .. " · " .. LJ.L("JOURNAL_LEGACY") end
            row.name:SetText(W:Truncate(run.name or LJ.L("UNKNOWN_DUNGEON"), 36))
            row.badges:SetText(badges)
            row.date:SetText(date and date("%d.%m.", run.started or 0) or "")
        end
    end
end
function J:ShowReport()
    if not self.frame then self:Create() end
    if not self.frame then return end
    self:Show()
    self.shareTarget:SetText(LJ.Report:GetTargetName() or "")
    self.fields.shareError:SetText("")
    self.reportPopup:Show()
    self.shareTarget:SetFocus()
end
function J:Show()
    if not self.frame then self:Create() end
    if not self.frame then return false end
    self:ApplyScale(LJ.DB.scale or 1)
    self:ApplyDisplayOptions()
    self:Refresh()
    self.frame:Show()
    return true
end
function J:Hide() if self.frame then self.frame:Hide() end end
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
    self.frame:SetHeight(compact and 476 or 628)
    self.recentPanel:SetShown(not compact)
    self.watermark:SetShown(LJ.DB.showWatermark ~= false)
end
function J:ResetPosition()
    if not LJ.DB then return end
    LJ.DB.journalPoint, LJ.DB.journalRelPoint = "CENTER", "CENTER"
    LJ.DB.journalX, LJ.DB.journalY = 0, -40
    position()
end
return J
