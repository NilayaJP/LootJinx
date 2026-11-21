-- LootJinx – Dashboard
local ADDON, ns = ...
local LJ = ns or _G.LootJinx
if not LJ then return end

local UI = {}
LJ.UI = UI
local W = LJ.Widgets
local C = LJ.COLORS
local unpackColor = unpack or table.unpack
local MEDIA = "Interface\\AddOns\\LootJinx\\Media\\"
local S = W:Skin("classic")

local frame
local refreshQueued = false
local statusPill
local needCard, recentCard
local compactLatest
local recentRows = {}
local reportPopup, reportEdit, reportError

local function hex(c)
    return string.format("|cff%02x%02x%02x",
        math.floor((c[1] or 1) * 255),
        math.floor((c[2] or 1) * 255),
        math.floor((c[3] or 1) * 255))
end

local function colored(c, text)
    return hex(c) .. tostring(text) .. "|r"
end

local function setText(fs, text)
    text = tostring(text or "")
    if fs:GetText() ~= text then fs:SetText(text) end
end

local function dateLabel(run)
    local t = tonumber(run and run.started) or 0
    if t <= 0 then return LJ.L("NO_DATA") end
    local d = date("*t", t)
    local nowT = time and time() or t
    local n = date("*t", nowT)
    if d and n and d.year == n.year and d.yday == n.yday then return LJ.L("TODAY") end
    local yesterday = date("*t", nowT - 86400)
    if d and yesterday and d.year == yesterday.year and d.yday == yesterday.yday then
        return LJ.L("YESTERDAY")
    end
    return LJ:FormatTime(t, "DATE_SHORT")
end

local function savePosition()
    if not frame then return end
    local point, _, relPoint, x, y = frame:GetPoint(1)
    if point and LJ.DB then
        LJ.DB.point = point
        LJ.DB.relPoint = relPoint or point
        LJ.DB.x = tonumber(x) or 0
        LJ.DB.y = tonumber(y) or 0
    end
end

local function applyPosition()
    if not frame or not LJ.DB then return end
    frame:ClearAllPoints()
    frame:SetPoint(LJ.DB.point or "CENTER", UIParent,
        LJ.DB.relPoint or LJ.DB.point or "CENTER",
        tonumber(LJ.DB.x) or 0, tonumber(LJ.DB.y) or -40)
    if frame.SetClampedToScreen then frame:SetClampedToScreen(true) end
end

local function applyScale()
    if not frame or not LJ.DB then return end
    frame:SetScale(tonumber(LJ.DB.scale) or 1)
end

local function dashboardCard(parent, skin, x, y, width, height)
    local card = W:Panel(parent)
    card:SetPoint("TOPLEFT", x, y)
    card:SetSize(width, height)
    if card.SetBackdropColor then
        card:SetBackdropColor(unpackColor(skin.surface))
        card:SetBackdropBorderColor(unpackColor(skin.border))
    end
    return card
end

local function dashboardText(parent, skin, text, x, y, width, size, color, display)
    local field = W:Font(parent, size, color, "", display and skin.displayFont or nil)
    field:SetPoint("TOPLEFT", x, y)
    if width then field:SetWidth(width) end
    field:SetWordWrap(false)
    field:SetText(text)
    return field
end

local function dashboardAction(parent, skin, caption, width, height)
    local action = W:Button(parent, caption, width, height)
    action:RegisterForClicks("LeftButtonUp")
    W:StyleButton(action, skin)
    return action
end
function LJ:CreateDashboardHeader(owner, window, skin, save)
    W:StyleWindow(window, skin, 59, 30, true)
    dashboardText(window, skin, LJ.L("TITLE"), 56, -12, 480, 22, skin.text, true)

    local status = W:Pill(window, 490, 18, true)
    status:SetPoint("TOPLEFT", 56, -37)
    status:SetFrameLevel(window:GetFrameLevel() + 2)
    W:SetTextFont(status.label, 11, "")

    local settings = dashboardAction(window, skin, "", 26, 26)
    settings:SetPoint("TOPRIGHT", -46, -11)
    local gear = settings:CreateTexture(nil, "ARTWORK")
    gear:SetSize(14, 14)
    gear:SetPoint("CENTER")
    gear:SetTexture("Interface\\Icons\\INV_Misc_Gear_01")
    gear:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    settings:SetScript("OnClick", function()
        if owner.moreMenu then owner.moreMenu:Hide() end
        if LJ.Options then LJ.Options:Open() end
    end)
    W:Tooltip(settings, LJ.L("OPTIONS_TITLE"), { LJ.L("TT_OPTIONS_1") })
    owner.settingsButton = settings

    local close = dashboardAction(window, skin, "×", 26, 26)
    W:WindowClose(close)
    close:SetScript("OnClick", function() window:Hide() end)
    W:Tooltip(close, LJ.L("CLOSE"))

    local drag = CreateFrame("Frame", nil, window)
    drag:SetPoint("TOPLEFT")
    drag:SetSize(554, 60)
    drag:SetFrameLevel(window:GetFrameLevel() + 1)
    drag:EnableMouse(true)
    drag:RegisterForDrag("LeftButton")
    local moving = false
    drag:SetScript("OnDragStart", function()
        if LJ.DB and LJ.DB.locked then return end
        window:StartMoving()
        moving = true
    end)
    drag:SetScript("OnDragStop", function()
        if not moving then return end
        window:StopMovingOrSizing()
        moving = false
        save()
    end)
    return status
end

function LJ:UpdateDashboardStatus(status, active, live, latest, skin)
    if live and active then
        status:SetState(LJ.L("STATUS_LIVE") .. " · " .. LJ:DungeonName(active), C.green, C.green)
    elseif (active and active.paused) or (latest and not latest.closed and latest.paused) then
        status:SetState(LJ.L("STATUS_IDLE"), skin.muted, skin.accent)
    else
        status:SetState(LJ.L("STATUS_READY"), skin.muted, C.dim)
    end
end

local function createHeader()
    statusPill = LJ:CreateDashboardHeader(UI, frame, S, savePosition)
end

function LJ:CreateDashboardNeed(owner, window, skin)
    local card = dashboardCard(window, skin, 16, -68, 608, 116)
    W:SetThemeArt(W:ThemeBanner(card), skin, "Banner")
    local icon = card:CreateTexture(nil, "ARTWORK")
    icon:SetSize(27, 27)
    icon:SetPoint("TOPLEFT", 14, -12)
    icon:SetTexture(MEDIA .. "NeedRolls")
    local metric = {
        title = dashboardText(card, skin, LJ.L("CARD_NEED"), 49, -16, 147, 11, skin.text, true),
        value = dashboardText(card, skin, "0", 14, -46, 124, 28, skin.text, true),
        sub = dashboardText(card, skin, "", 14, -82, 124, 10, skin.muted),
        pct = dashboardText(card, skin, "—", 165, -46, 85, 26, skin.progress, true),
        extra = dashboardText(card, skin, "", 165, -80, 273, 11, skin.text),
    }
    local rateLabel = dashboardText(card, skin, LJ.L("DASHBOARD_WIN_RATE"), 165, -30, 245, 10, skin.muted)
    metric.bar = W:Bar(card, owner.theme == "goblin" and 119 or 169, 8, skin.progress, skin.progress)
    metric.bar:SetPoint("TOPLEFT", 257, -55)
    W:ColorTexture(metric.bar.bg, skin.track)

    local line = W:Divider(card, true)
    line:SetPoint("TOPLEFT", 440, -15)
    line:SetHeight(86)
    W:ColorTexture(line, skin.border)

    local streakLabel = dashboardText(card, skin, LJ.L("STREAK"), 449, -36, 59, 9, skin.muted)
    streakLabel:SetJustifyH("CENTER")
    metric.streak = dashboardText(card, skin, "0", 449, -53, 59, 22, skin.text, true)
    metric.streak:SetJustifyH("CENTER")

    local record = dashboardAction(card, skin, "", 75, 62)
    record:SetPoint("TOPLEFT", 516, -27)
    record.label:Hide()
    record.caption = dashboardText(record, skin, LJ.L("RECORD") .. " »", 1, -10, 73, 10, skin.accent)
    record.caption:SetJustifyH("CENTER")
    metric.record = dashboardText(record, skin, "0", 0, -26, 75, 22, skin.accent, true)
    metric.record:SetJustifyH("CENTER")
    if owner.theme == "goblin" then
        icon:ClearAllPoints()
        icon:SetPoint("TOPLEFT", 289, -12)
        metric.title:ClearAllPoints()
        metric.title:SetPoint("TOPLEFT", 323, -16)
        metric.title:SetWidth(110)
        rateLabel:ClearAllPoints()
        rateLabel:SetPoint("TOPLEFT", 14, -22)
        metric.pct:ClearAllPoints()
        metric.pct:SetPoint("TOPLEFT", 14, -42)
        metric.pct:SetWidth(110)
        W:SetTextFont(metric.pct, 31, "")
        metric.bar:ClearAllPoints()
        metric.bar:SetPoint("TOPLEFT", 136, -54)
        metric.extra:ClearAllPoints()
        metric.extra:SetPoint("TOPLEFT", 14, -87)
        metric.value:ClearAllPoints()
        metric.value:SetPoint("TOPLEFT", 301, -49)
        metric.sub:ClearAllPoints()
        metric.sub:SetPoint("TOPLEFT", 301, -82)
    elseif owner.theme == "oracle" then
        W:ColorText(metric.streak, skin.progress)
        W:SetTextFont(metric.streak, 28, "", skin.displayFont)
        W:SetTextFont(metric.record, 30, "", skin.displayFont)
        if record.SetBackdropBorderColor then record:SetBackdropBorderColor(unpackColor(skin.accent)) end
    end
    record:SetScript("OnClick", function()
        if owner.moreMenu then owner.moreMenu:Hide() end
        if LJ.History then LJ.History:ShowLossRecord() end
    end)
    W:Tooltip(record, LJ.L("HISTORY_STREAK_LINK"))
    owner.lossRecordButton = record
    card.metric = metric
    W:Tooltip(card, LJ.L("TT_NEED_TITLE"), { LJ.L("TT_NEED_1"), LJ.L("TT_NEED_2"), LJ.L("TT_NEED_3") })
    return card
end

function LJ:UpdateDashboardNeed(metric, stats)
    local rolls = stats.needRolls or 0
    local rate = stats.winRate or 0
    local resolved = (stats.resolvedNeeds or 0) > 0
    setText(metric.value, rolls)
    setText(metric.sub, LJ.L("CARD_OF_RUNS", stats.totalDungeons or 0))
    setText(metric.extra, rolls > 0 and LJ.L("CARD_NEED_BREAKDOWN",
        stats.needWins or 0, stats.needLost or 0, stats.needPending or 0) or LJ.L("CARD_NEED_NO_DATA"))
    setText(metric.pct, resolved and ("%d%%"):format(math.floor(rate + .5)) or LJ.L("NO_DATA"))
    metric.bar:SetValue(resolved and rate / 100 or 0)
    setText(metric.streak, stats.lostNeedCurrent or 0)
    setText(metric.record, stats.lostNeedMax or 0)
end

local miniSpecs = {
    { title = "MINI_NO_WIN", art = "NoNeedWin", focus = "noNeedWin", help = "TT_NO_WIN_TITLE",
        tips = { "TT_NO_WIN_1", "TT_NO_WIN_2", "TT_NO_WIN_3" } },
    { title = "MINI_NO_LOOT", art = "NoLoot", focus = "noLoot", help = "TT_NO_LOOT_TITLE",
        tips = { "TT_NO_LOOT_1", "TT_NO_LOOT_2" } },
    { title = "MINI_SINCE", art = "SinceNeedWin", focus = "sinceNeedWin", help = "TT_SINCE_TITLE",
        tips = { "TT_SINCE_1", "TT_SINCE_2", "TT_SINCE_3" } },
}

function LJ:CreateDashboardMinis(owner, window, skin)
    local cards = {}
    for i, spec in ipairs(miniSpecs) do
        local card = dashboardCard(window, skin, 16 + (i - 1) * 208, -194, 192, 108)
        cards[i] = card
        local icon = card:CreateTexture(nil, "ARTWORK")
        icon:SetSize(20, 20)
        icon:SetPoint("TOPRIGHT", -12, -11)
        icon:SetTexture(MEDIA .. spec.art)
        card.title = dashboardText(card, skin, LJ.L(spec.title), 12, -11, 142, 10, skin.text, true)
        card.value = dashboardText(card, skin, "0", 12, -29, 76,
            owner.theme == "dwarven" and 33 or 27,
            owner.theme == "dwarven" and skin.progress or skin.text, true)
        card.sub = dashboardText(card, skin, "", 12, -60, 168, 10, skin.muted)
        card.sub:SetHeight(22)
        card.sub:SetWordWrap(true)
        card.sub:SetJustifyV("TOP")
        card.footer = dashboardText(card, skin, "", 12, -85, 168, 10, skin.accent)
        card.hint = dashboardText(card, skin, LJ.L("MINI_HISTORY_LINK"), 90, -39, 90, 9, skin.accent)
        card.hint:SetJustifyH("RIGHT")
        card.hint:SetAlpha(.82)
        card:SetScript("OnEnter", function(self)
            if self.SetBackdropColor then
                self:SetBackdropColor(unpackColor(skin.hover))
                self:SetBackdropBorderColor(unpackColor(skin.accent))
            end
            self.hint:SetAlpha(1)
        end)
        card:SetScript("OnLeave", function(self)
            if self.SetBackdropColor then
                self:SetBackdropColor(unpackColor(skin.surface))
                self:SetBackdropBorderColor(unpackColor(skin.border))
            end
            self.hint:SetAlpha(.82)
        end)
        local tips = {}
        for _, key in ipairs(spec.tips) do tips[#tips + 1] = LJ.L(key) end
        tips[#tips + 1] = LJ.L("TT_MINI_HISTORY")
        W:Tooltip(card, LJ.L(spec.help), tips)
        card:SetScript("OnMouseUp", function(_, mouseButton)
            if mouseButton and mouseButton ~= "LeftButton" then return end
            if owner.moreMenu then owner.moreMenu:Hide() end
            if LJ.History then LJ.History:Show(spec.focus) end
        end)
    end
    return cards
end

function LJ:UpdateDashboardMinis(cards, stats)
    local values = {
        { stats.noNeedWinDungeons, stats.noNeedWinCurrent, stats.noNeedWinMax,
            LJ.L("JOURNAL_NO_WIN_TOTAL", stats.noNeedWinDungeons or 0, stats.needDungeons or 0) },
        { stats.noLootDungeons, stats.noLootCurrent, stats.noLootMax,
            LJ.L("JOURNAL_NO_LOOT_TOTAL", stats.noLootDungeons or 0, stats.totalDungeons or 0) },
        { stats.sinceNeedWinCurrent, nil, stats.sinceNeedWinMax, LJ.L("JOURNAL_SINCE_NOTE") },
    }
    for i, card in ipairs(cards) do
        local value = values[i]
        setText(card.value, value[1] or 0)
        setText(card.sub, value[4])
        local record = LJ.L("JOURNAL_RECORD_VALUE", value[3] or 0)
        setText(card.footer, value[2] ~= nil and (LJ.L("JOURNAL_CURRENT_VALUE", value[2]) .. " · " .. record) or record)
    end
end

local function createNeedCard()
    needCard = LJ:CreateDashboardNeed(UI, frame, S)
    UI.needCard = needCard
end

local function createMinis()
    UI.miniCards = LJ:CreateDashboardMinis(UI, frame, S)
end

function LJ:RunStatusMarker(run)
    local live = run and not run.closed and self.Tracker and self.Tracker:GetActive() == run
        and self.Tracker:IsLive()
    local key = self.Stats.RunStatusKey(run, live)
    local marker = key and self.L(key)
    if live and key == "RUN_STATUS_PARTIAL" then
        return self.L("RUN_STATUS_LIVE") .. " · " .. marker, C.green
    end
    return marker, key == "RUN_STATUS_LIVE" and C.green or C.muted
end

function LJ:CompactLatestText(run)
    local name = W:Truncate(self:DungeonName(run), 22)
    local status = self:RunStatusMarker(run) or self.L("DETAIL_CLOSED")
    return self.L("COMPACT_LATEST", name, status)
end

function LJ:OpenCompactRun(run, theme)
    if not run then return end
    if GameTooltip then GameTooltip:Hide() end
    if run.legacy ~= true and self.RunDetail then
        self.RunDetail:Show(run, theme)
    elseif self.History then
        self.History:Show()
    end
end

function LJ:AppendRunBasisTooltip(run)
    if not GameTooltip or not self.Stats then return end
    local basis = self.Stats.RunBasis(self.Tracker and self.Tracker:GetRuns(), run)
    if not basis then return end
    local line = function(key, ...)
        GameTooltip:AddLine(self.L(key, ...), 0.86, 0.87, 0.90, true)
    end
    local status = self:RunStatusMarker(run) or self.L("TT_BASIS_COMPLETE")
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(self.L("TT_BASIS_TITLE"), C.accent[1], C.accent[2], C.accent[3])
    line("TT_BASIS_STATUS", status)
    line("TT_BASIS_NEED", basis.needLost, basis.needWon, basis.needPending)
    line(basis.noNeedWin and "TT_BASIS_NO_WIN_YES"
        or basis.needTotal > 0 and "TT_BASIS_NO_WIN_WON" or "TT_BASIS_NO_WIN_NONE")
    line(basis.noLoot and "TT_BASIS_NO_LOOT_YES" or "TT_BASIS_NO_LOOT_NO")
    line("TT_BASIS_SINCE_" .. string.upper((basis.sinceNeedWin or "not-started"):gsub("-", "_")))
end

function LJ:ShowRunBasisTooltip(owner, run)
    if not GameTooltip or not run then return end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    self:AppendRunBasisTooltip(run)
    GameTooltip:Show()
end

local function runTooltip(row, run)
    if not GameTooltip then return end
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:AddLine(LJ.Widgets:Truncate(LJ:DungeonName(run), 44),
        C.accent[1], C.accent[2], C.accent[3], true)
    GameTooltip:AddLine(dateLabel(run), C.muted[1], C.muted[2], C.muted[3])
    GameTooltip:AddLine(" ")
    local yes = LJ.L("YES")
    local no = LJ.L("NO")
    GameTooltip:AddLine(LJ.L("TT_RUN_LOOT", run.lootSeen and yes or no),
        run.lootSeen and C.green[1] or C.red[1],
        run.lootSeen and C.green[2] or C.red[2],
        run.lootSeen and C.green[3] or C.red[3], true)

    local total, won, lost, pending = 0, 0, 0, 0
    for _, n in ipairs(run.needs or {}) do
        total = total + 1
        if n.result == "won" then won = won + 1
        elseif n.result == "lost" then lost = lost + 1
        else pending = pending + 1 end
    end
    if total > 0 then
        GameTooltip:AddLine(LJ.L("TT_RUN_NEEDS", total, won, lost, pending),
            0.86, 0.87, 0.90, true)
    end
    if LJ.RecentRolls then LJ.RecentRolls:AddTooltip(run) end
    LJ:AppendRunBasisTooltip(run)
    if LJ.RunDetail then
        GameTooltip:AddLine(" ")
        if run.legacy == true then
            GameTooltip:AddLine(LJ.L("DETAIL_NO_LEGACY_CLICK"), C.muted[1], C.muted[2], C.muted[3])
        else
            GameTooltip:AddLine(LJ.L("DETAIL_CLICK"), C.muted[1], C.muted[2], C.muted[3])
        end
    end
    GameTooltip:Show()
end

function LJ:ShowRecentTooltip(row, run)
    runTooltip(row, run)
end

function LJ:CreateDashboardRecent(owner, window, skin, theme)
    local panel = dashboardCard(window, skin, 16, -312, 608, 148)
    dashboardText(panel, skin, LJ.L("RECENT"), 13, -8, 560, 12, skin.text, true)
    panel.empty = W:Font(panel, 10, skin.muted, "")
    panel.empty:SetPoint("CENTER", 0, -6)
    panel.empty:SetText(LJ.L("RECENT_EMPTY"))

    local rule = W:Divider(panel)
    rule:SetPoint("TOPLEFT", 12, -27)
    rule:SetPoint("TOPRIGHT", -12, -27)
    W:ColorTexture(rule, skin.border)

    local rows = {}
    for i = 1, 4 do
        local row = CreateFrame("Button", nil, panel)
        row:SetSize(584, 27)
        row:SetPoint("TOPLEFT", 12, -31 - (i - 1) * 27)
        W:StyleListRow(row, skin, i % 2 == 1)
        row:EnableMouse(true)
        row:RegisterForClicks("LeftButtonUp")
        row.bg = row:CreateTexture(nil, "BACKGROUND")
        row.bg:SetAllPoints()
        W:ColorTexture(row.bg, skin.hover)
        row.bg:Hide()
        if i < 4 then
            local separator = W:Divider(row)
            separator:SetPoint("BOTTOMLEFT")
            separator:SetPoint("BOTTOMRIGHT")
            W:ColorTexture(separator, skin.border)
        end
        row.bar = row:CreateTexture(nil, "ARTWORK")
        row.bar:SetSize(2, 15)
        row.bar:SetPoint("LEFT", 0, 0)
        row.name = dashboardText(row, skin, "", 10, -6, 247, 11, skin.text)
        row.badges = dashboardText(row, skin, "", 264, -7, 206, 10,
            theme == "oracle" and skin.accent or skin.muted)
        if theme == "goblin" then
            local slip = row:CreateTexture(nil, "BACKGROUND", nil, -1)
            slip:SetPoint("TOPLEFT", 2, -1)
            slip:SetPoint("BOTTOMRIGHT", 0, 2)
            W:ColorTexture(slip, { skin.border[1], skin.border[2], skin.border[3], .30 })
        end
        row.date = dashboardText(row, skin, "", 477, -7, 101, 10, skin.muted)
        row.date:SetJustifyH("RIGHT")
        row:SetScript("OnEnter", function(self)
            if self.run then
                self.bg:Show()
                LJ:ShowRecentTooltip(self, self.run)
            end
        end)
        row:SetScript("OnLeave", function(self)
            self.bg:Hide()
            if GameTooltip then GameTooltip:Hide() end
        end)
        row:SetScript("OnHide", function(self) self.bg:Hide() end)
        row:SetScript("OnClick", function(self)
            if not self.run or self.run.legacy or not LJ.RunDetail then return end
            if owner.moreMenu then owner.moreMenu:Hide() end
            if GameTooltip then GameTooltip:Hide() end
            local ok, err = pcall(LJ.RunDetail.Show, LJ.RunDetail, self.run, theme)
            if not ok then LJ:Print(LJ.L("ERROR_PART", "Run-Details", tostring(err))) end
        end)
        row:Hide()
        rows[i] = row
    end
    return panel, rows
end

function LJ:UpdateDashboardRecent(panel, rows, runs)
    panel.empty:SetShown(#runs == 0)
    for i, row in ipairs(rows) do
        local run = runs[#runs - i + 1]
        row.run = run
        row:SetShown(run ~= nil)
        if run then
            local marker, color = LJ:RunStatusMarker(run)
            W:ColorTexture(row.bar, color)
            local name = W:Truncate(LJ:DungeonName(run), marker and 24 or 36)
            setText(row.name, marker and (name .. " · " .. marker) or name)
            setText(row.date, LJ:FormatTime(run.started, "DATE_LONG"))

            local badges = {}
            local total, wins = #(run.needs or {}), 0
            for _, need in ipairs(run.needs or {}) do
                if need.result == "won" then wins = wins + 1 end
            end
            if total > 0 then
                badges[#badges + 1] = colored(wins > 0 and C.green or C.muted, LJ.L("BADGE_NEED", wins, total))
            end
            if not run.lootSeen then badges[#badges + 1] = LJ.L("BADGE_EMPTY") end
            if run.legacy then badges[#badges + 1] = LJ.L("JOURNAL_LEGACY") end
            local rolls = LJ.RecentRolls:Summary(run)
            if rolls then badges[#badges + 1] = rolls end
            setText(row.badges, table.concat(badges, " · "))
        end
    end
end

local function createRecent()
    recentCard, recentRows = LJ:CreateDashboardRecent(UI, frame, S, "classic")
    UI.recentPanel, UI.recentRows = recentCard, recentRows
end

function LJ:CreateDashboardFooterActions(owner, window, skin)
    local history = dashboardAction(window, skin, LJ.L("HISTORY"), 102, 23)
    history:SetPoint("BOTTOMRIGHT", -162, 15)
    history:SetScript("OnClick", function()
        owner.moreMenu:Hide()
        if LJ.History then LJ.History:Show() end
    end)
    owner.historyButton = history

    local report = dashboardAction(window, skin, LJ.L("REPORT"), 100, 23)
    report:SetPoint("BOTTOMRIGHT", -53, 15)
    report:SetScript("OnClick", function()
        owner.moreMenu:Hide()
        owner:ShowReport()
    end)
    W:Tooltip(report, LJ.L("REPORT_TITLE"), { LJ.L("TT_REPORT_1") })
    owner.reportButton = report

    local more = dashboardAction(window, skin, "…", 29, 23)
    more:SetPoint("BOTTOMRIGHT", -17, 15)
    W:Tooltip(more, LJ.L("DASHBOARD_MORE"))
    owner.moreButton = more

    local menu = dashboardCard(window, skin, 0, 0, 158, 70)
    menu:ClearAllPoints()
    menu:SetPoint("BOTTOMRIGHT", more, "TOPRIGHT", 0, 6)
    menu:SetFrameLevel(window:GetFrameLevel() + 25)
    menu:EnableMouse(true)
    owner.moreMenu = menu
    more:SetScript("OnClick", function() menu:SetShown(not menu:IsShown()) end)

    local help = dashboardAction(menu, skin, LJ.L("HELP"), 142, 24)
    help:SetPoint("TOPLEFT", 8, -8)
    help:SetScript("OnClick", function()
        menu:Hide()
        LJ:PrintHelp()
    end)
    W:Tooltip(help, LJ.L("HELP"), { LJ.L("CHAT_HELP_2"), LJ.L("CHAT_HELP_3"), LJ.L("CHAT_HELP_5") })
    owner.helpButton = help

    local reset = dashboardAction(menu, skin, LJ.L("RESET"), 142, 24)
    reset:SetPoint("TOPLEFT", 8, -38)
    reset:SetScript("OnClick", function()
        menu:Hide()
        if LJ.UI then LJ.UI:ConfirmReset() end
    end)
    W:Tooltip(reset, LJ.L("RESET"), { LJ.L("RESET_POPUP_TEXT") })
    owner.resetButton = reset
    menu:Hide()
end
local function createFooter()
    local separator = frame:CreateTexture(nil, "ARTWORK")
    W:ColorTexture(separator, S.border)
    separator:SetPoint("BOTTOMLEFT", 16, 42)
    separator:SetPoint("BOTTOMRIGHT", -16, 42)
    separator:SetHeight(1)

    local footer = W:Font(frame, 9, C.muted, "")
    footer:SetPoint("BOTTOMLEFT", 16, 25)
    footer:SetWidth(230)
    footer:SetWordWrap(false)
    frame.footer = footer
    W:AddDashboardCredit(frame, S.accent)

    compactLatest = CreateFrame("Button", nil, frame)
    compactLatest:SetSize(230, 20)
    compactLatest:SetPoint("BOTTOMLEFT", 16, 21)
    compactLatest:RegisterForClicks("LeftButtonUp")
    compactLatest.label = W:Font(compactLatest, 10, C.text, "")
    compactLatest.label:SetPoint("LEFT", 0, 0)
    compactLatest.label:SetWidth(230)
    compactLatest.label:SetWordWrap(false)
    compactLatest:SetScript("OnEnter", function(self)
        self.label:SetTextColor(C.accent[1], C.accent[2], C.accent[3])
        if self.run then LJ:ShowRecentTooltip(self, self.run) end
    end)
    compactLatest:SetScript("OnLeave", function(self)
        self.label:SetTextColor(C.text[1], C.text[2], C.text[3])
        if GameTooltip then GameTooltip:Hide() end
    end)
    compactLatest:SetScript("OnClick", function(self)
        if UI.moreMenu then UI.moreMenu:Hide() end
        LJ:OpenCompactRun(self.run)
    end)
    compactLatest:Hide()
    UI.compactLatest = compactLatest

    LJ:CreateDashboardFooterActions(UI, frame, S)

    UI.resizeGrip = W:ResizeGrip(frame, function(scale)
        UI:ApplyScale(scale)
    end, function()
        UI:ApplyScale(1.0)
    end)
end

-- Teilen-Dialog: Partychat oder Whisper an einen eingegebenen Namen.
function LJ:CreateDashboardReport(window, skin, send)
    local popup = W:Panel(window)
    popup:SetSize(320, 150)
    popup:SetPoint("CENTER", window, "CENTER", 0, 10)
    popup:SetFrameLevel(window:GetFrameLevel() + 20)
    popup:SetClampedToScreen(true)
    popup:EnableMouse(true)
    W:StyleWindow(popup, skin, 45, 24)
    dashboardText(popup, skin, LJ.L("REPORT_TITLE"), 50, -10, 225, 16, skin.text, true)
    dashboardText(popup, skin, LJ.L("REPORT_SUB"), 50, -29, 224, 9, skin.muted)
    dashboardText(popup, skin, LJ.L("REPORT_WHISPER_LABEL"), 14, -57, 90, 10, skin.muted)

    local close = dashboardAction(popup, skin, "×", 20, 20)
    W:WindowClose(close)
    close:SetScript("OnClick", function() popup:Hide() end)
    local edit = CreateFrame("EditBox", nil, popup, BackdropTemplateMixin and "BackdropTemplate" or nil)
    edit:SetSize(200, 24)
    edit:SetPoint("TOPLEFT", 104, -50)
    W:StyleInput(edit, skin)
    W:SetTextFont(edit, 10)
    edit:SetAutoFocus(false)
    edit:SetMaxLetters(64)
    edit:SetTextInsets(8, 8, 0, 0)
    edit:SetScript("OnEnterPressed", function(self) send("WHISPER", self:GetText()) end)
    edit:SetScript("OnEscapePressed", function() popup:Hide() end)
    popup:SetScript("OnHide", function() edit:ClearFocus() end)

    dashboardText(popup, skin, LJ.L("REPORT_TARGET_HINT"), 14, -80, 292, 9, skin.muted)
    local errorText = W:Font(popup, 9, C.red, "")
    errorText:SetPoint("TOPLEFT", 14, -94)
    errorText:SetWidth(292)

    local party = dashboardAction(popup, skin, LJ.L("REPORT_PARTY"), 90, 22)
    party:SetPoint("BOTTOMLEFT", 14, 12)
    party:SetScript("OnClick", function() send("PARTY") end)
    local whisper = dashboardAction(popup, skin, LJ.L("REPORT_WHISPER"), 90, 22)
    whisper:SetPoint("BOTTOMLEFT", 112, 12)
    whisper:SetScript("OnClick", function() send("WHISPER", edit:GetText()) end)
    local cancel = dashboardAction(popup, skin, LJ.L("REPORT_CANCEL"), 90, 22)
    cancel:SetPoint("BOTTOMLEFT", 210, 12)
    cancel:SetScript("OnClick", function() popup:Hide() end)
    popup:Hide()
    return popup, edit, errorText, party, whisper
end

local function createReportPopup()
    reportPopup, reportEdit, reportError = LJ:CreateDashboardReport(frame, S, function(channel, target)
        UI:SendReport(channel, target)
    end)
    UI.reportPopup = reportPopup
end
local function createFrame()
    frame = CreateFrame("Frame", "LootJinxFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    UI.frame = frame
    frame:SetSize(640, 510)
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    if frame.SetClampedToScreen then frame:SetClampedToScreen(true) end

    local function safe(label, fn)
        local ok, err = pcall(fn)
        if not ok then
            LJ.lastRefreshError = label .. ": " .. tostring(err)
            LJ:Print(LJ.L("ERROR_PART", label, tostring(err)))
        end
    end

    safe("Header", createHeader)
    safe("NeedCard", createNeedCard)
    safe("Minis", createMinis)
    safe("Recent", createRecent)
    safe("Footer", createFooter)
    safe("Report", createReportPopup)
    safe("Position", applyPosition)
    safe("Scale", applyScale)

    frame:SetScript("OnShow", function()
        UI:Refresh()
        W:FadeIn(frame, 0.15)
    end)
    frame:SetScript("OnHide", function()
        if UI.moreMenu then UI.moreMenu:Hide() end
        if reportPopup then reportPopup:Hide() end
        if LJ.History then LJ.History:Hide() end
        if LJ.RunDetail and type(LJ.RunDetail.Hide) == "function" then
            pcall(LJ.RunDetail.Hide, LJ.RunDetail)
        end
    end)

    if UISpecialFrames and frame:GetName() then
        local found = false
        for _, name in ipairs(UISpecialFrames) do
            if name == frame:GetName() then found = true break end
        end
        if not found then table.insert(UISpecialFrames, frame:GetName()) end
    end

    if StaticPopupDialogs then
        StaticPopupDialogs["LOOTJINX_RESET"] = W:StylePopup({
            text = LJ.L("RESET_POPUP_TITLE") .. "\n\n" .. LJ.L("RESET_POPUP_TEXT"),
            button1 = LJ.L("RESET_POPUP_OK"),
            button2 = LJ.L("RESET_POPUP_CANCEL"),
            OnAccept = function()
                local name = LJ:PlayerName() or "?"
                if LJ.Tracker then LJ.Tracker:ResetAll() end
                LJ:Print(LJ.L("CHAT_RESET_DONE", name))
                UI:Refresh()
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        })
    end
    frame:Hide()
end

function UI:Create()
    if frame then return frame end
    if not LJ.dbReady or not LJ.Tracker then
        LJ:Print(LJ.L("ERROR_NO_DB"))
        return nil
    end
    local ok, err = pcall(createFrame)
    if not ok then
        LJ:Print(LJ.L("ERROR_PART", "Fenster", tostring(err)))
    end
    if not frame then return nil end
    pcall(UI.ApplyDisplayOptions, UI)
    LJ:RegisterRefresh(function() UI:RequestRefresh() end)
    UI:Refresh()
    return frame
end

function UI:RequestRefresh()
    if not frame or not frame:IsShown() then return end
    if refreshQueued then return end
    refreshQueued = true
    if C_Timer and C_Timer.After then
        C_Timer.After(0.1, function()
            refreshQueued = false
            if frame and frame:IsShown() then UI:Refresh() end
        end)
    else
        refreshQueued = false
        UI:Refresh()
    end
end

function UI:Toggle()
    if not frame then UI:Create() end
    if not frame then
        LJ:Print(LJ.L("ERROR_SHOW"))
        return
    end
    if frame:IsShown() then
        frame:Hide()
    else
        local ok, err = pcall(frame.Show, frame)
        if not ok then
            LJ:Print(LJ.L("ERROR_SHOW"))
            return
        end
        if not frame:IsShown() then LJ:Print(LJ.L("ERROR_SHOW")) end
    end
end

function UI:Show()
    if not frame then UI:Create() end
    if frame then frame:Show() end
end

function UI:Hide()
    if frame then frame:Hide() end
end

local function refreshContent()
    if not frame or not LJ.Stats or not LJ.Tracker then return end

    -- Jeder Abschnitt wird einzeln abgesichert: ein Fehler in den Statistiken
    -- darf die Recent-Liste nicht mitreißen.
    local function section(label, fn)
        local ok, err = pcall(fn)
        if not ok then
            LJ.lastRefreshError = label .. ": " .. tostring(err)
        end
        return ok
    end

    local runs, stats = {}, {}
    section("Runs", function() runs = LJ.Tracker:GetRuns() end)
    section("Stats", function() stats = LJ.Stats.Compute(runs) end)
    UI.stats = stats

    local latest = runs[#runs]
    if statusPill then
        section("Status", function()
            LJ:UpdateDashboardStatus(statusPill, LJ.Tracker:GetActive(), LJ.Tracker:IsLive(), latest, S)
        end)
    end
    if needCard then section("Need", function() LJ:UpdateDashboardNeed(needCard.metric, stats) end) end
    if UI.miniCards then section("Minis", function() LJ:UpdateDashboardMinis(UI.miniCards, stats) end) end

    if frame.footer then
        setText(frame.footer, LJ.L("FOOTER_CLASS", select(1, LJ:ClassName()), LJ.L("FOOTER_HINT")))
        frame.footer:SetShown(LJ.DB.compact ~= true or latest == nil)
    end
    if compactLatest then
        compactLatest.run = latest
        if latest then setText(compactLatest.label, LJ:CompactLatestText(latest)) end
        compactLatest:SetShown(LJ.DB.compact == true and latest ~= nil)
    end
    if recentCard then section("Recent", function() LJ:UpdateDashboardRecent(recentCard, recentRows, runs) end) end
end
-- Diagnose für /lj debug: Zustand der Recent-Liste und der Runs.
function UI:DebugInfo()
    local parts = {}
    parts[#parts + 1] = "Recent-Karte: " .. (recentCard and "da" or "FEHLT")
    if recentCard then
        parts[#parts + 1] = "sichtbar: " .. tostring(recentCard:IsShown())
        parts[#parts + 1] = "empty-Text: " .. (recentCard.empty and "da" or "FEHLT")
        parts[#parts + 1] = "Höhe: " .. tostring(recentCard:GetHeight())
    end
    local rowCount = 0
    for i = 1, 4 do
        if recentRows[i] then rowCount = rowCount + 1 end
    end
    parts[#parts + 1] = "Zeilenobjekte: " .. rowCount
    parts[#parts + 1] = "Kompakt: " .. tostring(LJ.DB and LJ.DB.compact == true)
    parts[#parts + 1] = "Fensterhöhe: " .. tostring(frame and frame:GetHeight())
    local runs = (LJ.Tracker and LJ.Tracker:GetRuns()) or {}
    local names = {}
    for i = 1, #runs do
        names[#names + 1] = tostring(runs[i].name or "?")
    end
    parts[#parts + 1] = "Runs: " .. #runs .. " (" .. table.concat(names, ", ") .. ")"
    local visible, withRun = 0, 0
    for i = 1, 4 do
        local row = recentRows[i]
        if row and row:IsShown() then visible = visible + 1 end
        if row and row.run then withRun = withRun + 1 end
    end
    parts[#parts + 1] = "Recent-Zeilen sichtbar: " .. visible
    parts[#parts + 1] = "Zeilen mit Run: " .. withRun
    parts[#parts + 1] = "CharDB-Runs: " .. tostring(LJ.CharDB and #(LJ.CharDB.runs or {}) or -1)
    parts[#parts + 1] = "Letzter Anzeigefehler: " .. tostring(LJ.lastRefreshError or "-")
    return table.concat(parts, " · ")
end

function UI:Refresh()
    local ok, err = pcall(refreshContent)
    if not ok then
        LJ.lastRefreshError = tostring(err)
        LJ:Print(LJ.L("ERROR_REFRESH", tostring(err)))
    end
end

function UI:GetTargetName()
    return LJ.Report:GetTargetName()
end

function UI:BuildReport()
    return LJ.Report:Build()
end

function UI:ShowReport()
    if not frame then UI:Create() end
    if not frame or not reportPopup then return end
    if UI.moreMenu then UI.moreMenu:Hide() end
    if not frame:IsShown() then frame:Show() end
    local target = UI:GetTargetName()
    if reportEdit then
        reportEdit:SetText(target or "")
        reportEdit:SetFocus()
    end
    if reportError then reportError:SetText("") end
    reportPopup:Show()
end

function UI:SendReport(channel, target)
    if not frame then UI:Create() end
    if not reportPopup then return false end
    local sent, reason = LJ.Report:Send(channel, target)
    if not sent then
        if reason and reportError then reportError:SetText(LJ.L(reason)) end
        return false
    end
    if reportError then reportError:SetText("") end
    reportPopup:Hide()
    if reportEdit then reportEdit:ClearFocus() end
    return true
end

function UI:ConfirmReset()
    if StaticPopup_Show then
        StaticPopup_Show("LOOTJINX_RESET")
    elseif LJ.Tracker then
        LJ.Tracker:ResetAll()
        UI:Refresh()
    end
end

function UI:ApplyScale(scale)
    if not LJ.DB then return end
    scale = tonumber(scale) or LJ.DB.scale or 1
    if scale < 0.40 then scale = 0.40 end
    if scale > 3.00 then scale = 3.00 end
    LJ.DB.scale = scale
    applyScale()
    applyPosition()
    UI:Refresh()
    if LJ.Options and LJ.Options.Refresh then pcall(LJ.Options.Refresh, LJ.Options) end
    return scale
end

function UI:ApplyDisplayOptions()
    if not frame or not LJ.DB then return end
    local compact = LJ.DB.compact == true
    frame:SetHeight(compact and 358 or 510)
    if recentCard then recentCard:SetShown(not compact) end
    if compactLatest then compactLatest:SetShown(compact and compactLatest.run ~= nil) end
    if frame.footer then frame.footer:SetShown(not compact or not compactLatest or compactLatest.run == nil) end
    if LJ.Options and LJ.Options.Refresh then pcall(LJ.Options.Refresh, LJ.Options) end
end

function UI:ResetPosition()
    if not LJ.DB then return end
    LJ.DB.point = "CENTER"
    LJ.DB.relPoint = "CENTER"
    LJ.DB.x = 0
    LJ.DB.y = -40
    applyPosition()
end

function LJ:PrintHelp()
    LJ:Print(LJ.L("CHAT_HELP_1"))
    LJ:Print(LJ.L("CHAT_HELP_2"))
    LJ:Print(LJ.L("CHAT_HELP_3"))
    LJ:Print(LJ.L("CHAT_HELP_5"))
    LJ:Print(LJ.L("CHAT_HELP_6"))
end

function LJ:HandleCommand(msg)
    msg = tostring(msg or ""):match("^%s*(.-)%s*$")
    local cmd = msg:match("^(%S*)")
    cmd = (cmd or ""):lower()
    if cmd == "" or cmd == "toggle" or cmd == "show" then
        if LJ.UI then LJ.UI:Toggle() end
    elseif cmd == "reset" then
        if LJ.UI then LJ.UI:ConfirmReset() end
    elseif cmd == "help" then
        LJ:PrintHelp()
    elseif cmd == "options" or cmd == "settings" then
        if LJ.Options then
            LJ.Options:Open()
        else
            LJ:Print(LJ.L("OPTIONS_UNAVAILABLE"))
        end
    elseif cmd == "debug" then
        if LJ.Diagnostics then
            LJ.Diagnostics:Show()
        else
            LJ.debugMode = true
            if LJ.Tracker then LJ.Tracker:Debug() end
            LJ:Print(LJ.L("CHAT_DEBUG_UI",
                tostring(LJ.UI ~= nil),
                tostring(LJ.dbReady == true),
                tostring(LJ.RunDetail ~= nil),
                tostring(LJ.UI and LJ.UI.frame and LJ.UI.frame:IsShown())))
            if LJ.UI and LJ.UI.DebugInfo then
                LJ:Print(LJ.UI:DebugInfo())
            end
        end
    elseif cmd == "resetpos" or cmd == "position" then
        if LJ.UI then LJ.UI:ResetPosition() end
    else
        LJ:Print(LJ.L("CHAT_UNKNOWN"))
    end
end

function LJ:SetupCommands()
    if self.commandsReady then return end
    self.commandsReady = true
    SLASH_LOOTJINX1 = "/lootjinx"
    SLASH_LOOTJINX2 = "/lj"
    SlashCmdList["LOOTJINX"] = function(msg)
        LJ:HandleCommand(msg)
    end
end

-- AddonCompartment (Addon-Leiste neben der Minimap)
function LootJinx_OnAddonCompartmentClick(_, button)
    if button == "RightButton" then
        LJ:PrintHelp()
    elseif LJ.UI then
        LJ.UI:Toggle()
    end
end

function LootJinx_OnAddonCompartmentEnter(_, owner)
    if not GameTooltip then return end
    GameTooltip:SetOwner(owner or UIParent, "ANCHOR_LEFT")
    GameTooltip:AddLine("LootJinx", C.accent[1], C.accent[2], C.accent[3])
    GameTooltip:AddLine(LJ.L("SUBTITLE"), 0.86, 0.87, 0.90, true)
    GameTooltip:AddLine("/lj", 0.70, 0.72, 0.80)
    GameTooltip:Show()
end

function LootJinx_OnAddonCompartmentLeave()
    if GameTooltip then GameTooltip:Hide() end
end

return UI
