-- LootJinx – Dashboard
local ADDON, ns = ...
local LJ = ns or _G.LootJinx
if not LJ then return end

local UI = {}
LJ.UI = UI
local W = LJ.Widgets
local C = LJ.COLORS
local WHITE = "Interface\\Buttons\\WHITE8X8"
local FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
local MEDIA = "Interface\\AddOns\\LootJinx\\Media\\"

local frame
local refreshQueued = false
local pulse = 0
local statusPill, closeButton
local hero, needCard, recentCard
local miniNoWin, miniNoLoot, miniSince
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
    return date("%d.%m.", t)
end

local function applyBackdrop(f)
    if f.SetBackdrop then
        f:SetBackdrop({
            bgFile = WHITE,
            edgeFile = WHITE,
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        f:SetBackdropColor(C.bg[1], C.bg[2], C.bg[3], C.bg[4] or 1)
        f:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 1)
    end
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

local function createHeader()
    local iconFrame = W:Panel(frame, "BACKGROUND")
    iconFrame:SetSize(38, 38)
    iconFrame:SetPoint("TOPLEFT", 16, -12)
    iconFrame:SetFrameLevel(frame:GetFrameLevel() + 2)
    local icon = iconFrame:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 2, -2)
    icon:SetPoint("BOTTOMRIGHT", -2, 2)
    icon:SetTexture(MEDIA .. "LootJinxIcon")

    local glow = iconFrame:CreateTexture(nil, "BORDER")
    glow:SetPoint("TOPLEFT", -3, 3)
    glow:SetPoint("BOTTOMRIGHT", 3, -3)
    glow:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.10)

    local title = W:Font(frame, 20, C.text, "OUTLINE")
    title:SetPoint("TOPLEFT", 64, -12)
    title:SetText(LJ.L("TITLE"))

    local subtitle = W:Font(frame, 10, C.muted, "")
    subtitle:SetPoint("TOPLEFT", 65, -35)
    subtitle:SetText(LJ.L("SUBTITLE"))

    statusPill = W:Pill(frame, 164, 22)
    statusPill:SetPoint("TOPRIGHT", -68, -16)
    statusPill:SetFrameLevel(frame:GetFrameLevel() + 3)

    local settings = W:Button(frame, "", 22, 22)
    settings:SetPoint("TOPRIGHT", -40, -14)
    settings:SetFrameLevel(frame:GetFrameLevel() + 5)
    local gear = settings:CreateTexture(nil, "ARTWORK")
    gear:SetSize(14, 14)
    gear:SetPoint("CENTER", 0, 0)
    gear:SetTexture("Interface\\Icons\\INV_Misc_Gear_01")
    gear:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    settings:SetScript("OnClick", function()
        if LJ.Options then LJ.Options:Open() end
    end)
    W:Tooltip(settings, LJ.L("OPTIONS_TITLE"), { LJ.L("TT_OPTIONS_1") })
    UI.settingsButton = settings

    closeButton = W:Button(frame, "×", 22, 22)
    closeButton:SetPoint("TOPRIGHT", -14, -14)
    closeButton:SetFrameLevel(frame:GetFrameLevel() + 5)
    closeButton.label:SetFont(FONT, 15, "")
    closeButton.label:SetPoint("CENTER", 0, 1)
    closeButton:SetScript("OnClick", function() frame:Hide() end)
    W:Tooltip(closeButton, LJ.L("CLOSE"), { LJ.L("CLOSE") })

    local drag = CreateFrame("Frame", nil, frame)
    drag:SetPoint("TOPLEFT", 0, 0)
    drag:SetSize(300, 58)
    drag:SetFrameLevel(frame:GetFrameLevel() + 1)
    drag:EnableMouse(true)
    drag:RegisterForDrag("LeftButton")
    drag:SetScript("OnDragStart", function()
        if LJ.DB and LJ.DB.locked then return end
        frame:StartMoving()
    end)
    drag:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        savePosition()
    end)
end

local function createHero()
    hero = W:Card(frame)
    hero:SetPoint("TOPLEFT", 16, -68)
    hero:SetSize(608, 116)

    local art = W:Panel(hero, "BACKGROUND")
    art:SetSize(38, 38)
    art:SetPoint("TOPLEFT", 14, -8)
    art:SetFrameLevel(hero:GetFrameLevel() + 2)
    local artTexture = art:CreateTexture(nil, "ARTWORK")
    artTexture:SetPoint("TOPLEFT", 2, -2)
    artTexture:SetPoint("BOTTOMRIGHT", -2, 2)
    artTexture:SetTexture(MEDIA .. "CurseChest")

    hero.title = W:Font(hero, 9, C.accent, "OUTLINE")
    hero.title:SetPoint("TOPLEFT", 62, -10)
    hero.title:SetText(LJ.L("CARD_CURSE"))

    hero.value = W:Font(hero, 27, C.text, "OUTLINE")
    hero.value:SetPoint("TOPLEFT", 62, -23)
    hero.value:SetText("0 / 0")

    hero.sub = W:Font(hero, 10, C.muted, "")
    hero.sub:SetPoint("TOPLEFT", 63, -58)
    hero.sub:SetText(LJ.L("CARD_CURSE_EMPTY"))

    hero.pct = W:Font(hero, 9, C.dim, "")
    hero.pct:SetPoint("TOPLEFT", 63, -102)

    hero.bar = W:Bar(hero, 5, C.accent, C.red)
    hero.bar:SetPoint("TOPLEFT", 62, -96)
    hero.bar:SetWidth(372)

    local divider = W:Divider(hero, true)
    divider:SetPoint("TOPLEFT", 440, -18)
    divider:SetHeight(62)

    hero.streakLabel = W:Font(hero, 8, C.muted, "")
    hero.streakLabel:SetPoint("TOPLEFT", 454, -18)
    hero.streakLabel:SetWidth(60)
    hero.streakLabel:SetJustifyH("CENTER")
    hero.streakLabel:SetText(LJ.L("STREAK"))

    hero.streakValue = W:Font(hero, 22, C.text, "OUTLINE")
    hero.streakValue:SetPoint("TOPLEFT", 454, -30)
    hero.streakValue:SetWidth(60)
    hero.streakValue:SetJustifyH("CENTER")
    hero.streakValue:SetText("0")

    hero.recordLabel = W:Font(hero, 8, C.muted, "")
    hero.recordLabel:SetPoint("TOPLEFT", 526, -18)
    hero.recordLabel:SetWidth(60)
    hero.recordLabel:SetJustifyH("CENTER")
    hero.recordLabel:SetText(LJ.L("RECORD"))

    hero.recordValue = W:Font(hero, 22, C.gold, "OUTLINE")
    hero.recordValue:SetPoint("TOPLEFT", 526, -30)
    hero.recordValue:SetWidth(60)
    hero.recordValue:SetJustifyH("CENTER")
    hero.recordValue:SetText("0")

    W:Tooltip(hero, LJ.L("TT_CURSE_TITLE"), {
        LJ.L("TT_CURSE_1", select(2, LJ:PlayerStat())),
        LJ.L("TT_CURSE_2"),
    })
end

local function createNeedCard()
    needCard = W:Card(frame)
    needCard:SetPoint("TOPLEFT", 16, -194)
    needCard:SetSize(608, 108)

    local art = W:Panel(needCard, "BACKGROUND")
    art:SetSize(38, 38)
    art:SetPoint("TOPLEFT", 14, -8)
    art:SetFrameLevel(needCard:GetFrameLevel() + 2)
    local artTexture = art:CreateTexture(nil, "ARTWORK")
    artTexture:SetPoint("TOPLEFT", 2, -2)
    artTexture:SetPoint("BOTTOMRIGHT", -2, 2)
    artTexture:SetTexture(MEDIA .. "NeedRolls")

    needCard.title = W:Font(needCard, 9, C.accent, "OUTLINE")
    needCard.title:SetPoint("TOPLEFT", 62, -10)
    needCard.title:SetText(LJ.L("CARD_NEED"))

    needCard.note = W:Font(needCard, 8, C.dim, "")
    needCard.note:SetPoint("BOTTOMRIGHT", -14, 10)
    needCard.note:SetJustifyH("RIGHT")
    needCard.note:SetText(LJ.L("CARD_NEED_SUB"))

    needCard.value = W:Font(needCard, 28, C.text, "OUTLINE")
    needCard.value:SetPoint("TOPLEFT", 62, -21)
    needCard.value:SetText("0")

    needCard.sub = W:Font(needCard, 10, C.muted, "")
    needCard.sub:SetPoint("TOPLEFT", 118, -28)
    needCard.sub:SetText(LJ.L("CARD_NEED_NO_DATA"))

    needCard.sub2 = W:Font(needCard, 9, C.dim, "")
    needCard.sub2:SetPoint("TOPLEFT", 118, -46)
    needCard.sub2:SetText("")

    needCard.pct = W:Font(needCard, 9, C.dim, "")
    needCard.pct:SetPoint("TOPLEFT", 63, -94)

    needCard.bar = W:Bar(needCard, 5, C.green, C.cyan)
    needCard.bar:SetPoint("TOPLEFT", 62, -87)
    needCard.bar:SetWidth(372)

    local divider = W:Divider(needCard, true)
    divider:SetPoint("TOPLEFT", 440, -18)
    divider:SetHeight(54)

    needCard.streakLabel = W:Font(needCard, 8, C.muted, "")
    needCard.streakLabel:SetPoint("TOPLEFT", 454, -18)
    needCard.streakLabel:SetWidth(60)
    needCard.streakLabel:SetJustifyH("CENTER")
    needCard.streakLabel:SetText(LJ.L("STREAK"))

    needCard.streakValue = W:Font(needCard, 22, C.text, "OUTLINE")
    needCard.streakValue:SetPoint("TOPLEFT", 454, -30)
    needCard.streakValue:SetWidth(60)
    needCard.streakValue:SetJustifyH("CENTER")
    needCard.streakValue:SetText("0")

    needCard.recordLabel = W:Font(needCard, 8, C.muted, "")
    needCard.recordLabel:SetPoint("TOPLEFT", 526, -18)
    needCard.recordLabel:SetWidth(60)
    needCard.recordLabel:SetJustifyH("CENTER")
    needCard.recordLabel:SetText(LJ.L("RECORD"))

    needCard.recordValue = W:Font(needCard, 22, C.gold, "OUTLINE")
    needCard.recordValue:SetPoint("TOPLEFT", 526, -30)
    needCard.recordValue:SetWidth(60)
    needCard.recordValue:SetJustifyH("CENTER")
    needCard.recordValue:SetText("0")

    W:Tooltip(needCard, LJ.L("TT_NEED_TITLE"), {
        LJ.L("TT_NEED_1"),
        LJ.L("TT_NEED_2"),
    })
end

local function createMini(parent, x, title, sub, tooltipTitle, tooltipLines, iconTexture)
    local card = W:Card(parent)
    card:SetPoint("TOPLEFT", x, -312)
    card:SetSize(192, 108)

    if iconTexture then
        local art = W:Panel(card, "BACKGROUND")
        art:SetSize(30, 30)
        art:SetPoint("TOPRIGHT", -10, -8)
        art:SetFrameLevel(card:GetFrameLevel() + 2)
        local tex = art:CreateTexture(nil, "ARTWORK")
        tex:SetPoint("TOPLEFT", 2, -2)
        tex:SetPoint("BOTTOMRIGHT", -2, 2)
        tex:SetTexture(iconTexture)
    end

    card.title = W:Font(card, 8, C.accent, "OUTLINE")
    card.title:SetPoint("TOPLEFT", 12, -10)
    card.title:SetText(title)

    card.value = W:Font(card, 26, C.text, "OUTLINE")
    card.value:SetPoint("TOPLEFT", 12, -22)
    card.value:SetText("0")

    card.sub = W:Font(card, 9, C.muted, "")
    card.sub:SetPoint("TOPLEFT", 12, -53)
    card.sub:SetWidth(168)
    card.sub:SetJustifyV("TOP")
    card.sub:SetText(sub)

    card.footer = W:Font(card, 9, C.muted, "")
    card.footer:SetPoint("TOPLEFT", 12, -89)
    card.footer:SetWidth(168)
    card.footer:SetText("")

    W:Tooltip(card, tooltipTitle, tooltipLines)
    return card
end

local function createMinis()
    miniNoWin = createMini(frame, 16, LJ.L("MINI_NO_WIN"), LJ.L("MINI_NO_WIN_SUB"),
        LJ.L("TT_NO_WIN_TITLE"), { LJ.L("TT_NO_WIN_1"), LJ.L("TT_NO_WIN_2") },
        MEDIA .. "NoNeedWin")
    miniNoLoot = createMini(frame, 224, LJ.L("MINI_NO_LOOT"), LJ.L("MINI_NO_LOOT_SUB"),
        LJ.L("TT_NO_LOOT_TITLE"), { LJ.L("TT_NO_LOOT_1") },
        MEDIA .. "NoLoot")
    miniSince = createMini(frame, 432, LJ.L("MINI_SINCE"), LJ.L("MINI_SINCE_SUB"),
        LJ.L("TT_SINCE_TITLE"), { LJ.L("TT_SINCE_1"), LJ.L("TT_SINCE_2") },
        MEDIA .. "SinceNeedWin")
end

local function runTooltip(row, run)
    if not GameTooltip then return end
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:AddLine(LJ.Widgets:Truncate(run.name or LJ.L("UNKNOWN_DUNGEON"), 44),
        C.accent[1], C.accent[2], C.accent[3], true)
    GameTooltip:AddLine(dateLabel(run), C.muted[1], C.muted[2], C.muted[3])
    GameTooltip:AddLine(" ")
    local yes = LJ.L("YES")
    local no = LJ.L("NO")
    GameTooltip:AddLine(LJ.L("TT_RUN_AGI", run.agilityDropped and yes or no),
        run.agilityDropped and C.green[1] or C.red[1],
        run.agilityDropped and C.green[2] or C.red[2],
        run.agilityDropped and C.green[3] or C.red[3], true)
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
    if run.agilityLink then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(run.agilityLink, 0.86, 0.87, 0.90)
    end
    if run.id and LJ.Tracker and LJ.Tracker:GetActive() == run then
        GameTooltip:AddLine(" ")
        local status = LJ.Tracker:IsLive() and LJ.L("LIVE") or LJ.L("STATUS_IDLE")
        GameTooltip:AddLine(status, C.green[1], C.green[2], C.green[3])
    end
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

local function createRecent()
    recentCard = W:Card(frame)
    recentCard:SetPoint("TOPLEFT", 16, -430)
    recentCard:SetSize(608, 148)

    local title = W:Font(recentCard, 9, C.accent, "OUTLINE")
    title:SetPoint("TOPLEFT", 14, -10)
    title:SetText(LJ.L("RECENT"))

    recentCard.empty = W:Font(recentCard, 10, C.muted, "")
    recentCard.empty:SetPoint("CENTER", 0, -6)
    recentCard.empty:SetWidth(550)
    recentCard.empty:SetJustifyH("CENTER")
    recentCard.empty:SetText(LJ.L("RECENT_EMPTY"))

    for i = 1, 4 do
        -- Als Button: nur ein Button kann ein OnClick-Skript bekommen,
        -- ein Frame nicht (das wirft im echten Client einen Fehler).
        local row = CreateFrame("Button", nil, recentCard)
        row:SetSize(584, 24)
        row:SetPoint("TOPLEFT", 12, -28 - (i - 1) * 25)
        row:EnableMouse(true)
        -- RegisterForClicks erwartet genau eine Button-Angabe; "Up" gehört
        -- als Suffix in den Namen ("LeftButtonUp" = Klick beim Loslassen).
        row:RegisterForClicks("LeftButtonUp")
        row.bg = row:CreateTexture(nil, "BACKGROUND")
        row.bg:SetAllPoints()
        row.bg:SetColorTexture(1, 1, 1, 0)
        row.bar = row:CreateTexture(nil, "ARTWORK")
        row.bar:SetSize(2, 14)
        row.bar:SetPoint("LEFT", 0, 0)
        row.name = W:Font(row, 10, C.text, "")
        row.name:SetPoint("LEFT", 10, 0)
        row.name:SetWidth(260)
        row.name:SetWordWrap(false)
        row.badges = W:Font(row, 9, C.muted, "")
        row.badges:SetPoint("LEFT", 274, 0)
        row.badges:SetWidth(220)
        row.badges:SetWordWrap(false)
        row.date = W:Font(row, 9, C.dim, "")
        row.date:SetPoint("RIGHT", 0, 0)
        row.date:SetWidth(62)
        row.date:SetJustifyH("RIGHT")
        row:SetScript("OnEnter", function(self)
            if self.run then
                self.bg:SetColorTexture(1, 1, 1, 0.045)
                runTooltip(self, self.run)
            end
        end)
        row:SetScript("OnLeave", function(self)
            self.bg:SetColorTexture(1, 1, 1, 0)
            if GameTooltip then GameTooltip:Hide() end
        end)
        row:SetScript("OnClick", function(self)
            if not self.run then return end
            if self.clickable == false then return end
            if GameTooltip then GameTooltip:Hide() end
            if LJ.RunDetail and type(LJ.RunDetail.Show) == "function" then
                local ok, err = pcall(LJ.RunDetail.Show, LJ.RunDetail, self.run)
                if not ok then LJ:Print(LJ.L("ERROR_PART", "Run-Details", tostring(err))) end
            end
        end)
        row:Hide()
        recentRows[i] = row
    end
end

local function createFooter()
    local separator = frame:CreateTexture(nil, "ARTWORK")
    separator:SetColorTexture(0.18, 0.19, 0.24, 0.7)
    separator:SetPoint("BOTTOMLEFT", 16, 42)
    separator:SetPoint("BOTTOMRIGHT", -16, 42)
    separator:SetHeight(1)

    local footer = W:Font(frame, 9, C.muted, "")
    footer:SetPoint("BOTTOMLEFT", 16, 16)
    footer:SetWidth(310)
    footer:SetWordWrap(false)
    frame.footer = footer

    local history = W:Button(frame, LJ.L("HISTORY"), 72, 20)
    history:SetPoint("BOTTOMRIGHT", -228, 14)
    history:SetScript("OnClick", function() if LJ.History then LJ.History:Show() end end)
    UI.historyButton = history

    local report = W:Button(frame, LJ.L("REPORT"), 72, 20)
    report:SetPoint("BOTTOMRIGHT", -148, 14)
    local reportIcon = report:CreateTexture(nil, "ARTWORK")
    reportIcon:SetSize(14, 14)
    reportIcon:SetPoint("LEFT", 3, 0)
    reportIcon:SetTexture(MEDIA .. "Report")
    report:SetScript("OnClick", function() UI:ShowReport() end)
    W:Tooltip(report, LJ.L("REPORT_TITLE"), { LJ.L("TT_REPORT_1") })

    local help = W:Button(frame, LJ.L("HELP"), 58, 20)
    help:SetPoint("BOTTOMRIGHT", -82, 14)
    help:SetScript("OnClick", function() LJ:PrintHelp() end)
    W:Tooltip(help, LJ.L("HELP"), { LJ.L("CHAT_HELP_2"), LJ.L("CHAT_HELP_3"), LJ.L("CHAT_HELP_4") })

    local reset = W:Button(frame, LJ.L("RESET"), 58, 20)
    reset:SetPoint("BOTTOMRIGHT", -16, 14)
    reset:SetScript("OnClick", function() UI:ConfirmReset() end)
    W:Tooltip(reset, LJ.L("RESET"), { LJ.L("RESET_POPUP_TEXT") })
end

-- Teilen-Dialog: Partychat oder Whisper an einen eingegebenen Namen.
local function createReportPopup()
    reportPopup = W:Card(frame)
    reportPopup:SetSize(320, 150)
    reportPopup:SetPoint("CENTER", frame, "CENTER", 0, 10)
    reportPopup:SetFrameLevel((frame:GetFrameLevel() or 1) + 20)
    reportPopup:SetClampedToScreen(true)
    reportPopup:EnableMouse(true)
    reportPopup:Hide()

    local icon = reportPopup:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetPoint("TOPLEFT", 14, -8)
    icon:SetTexture(MEDIA .. "Report")

    local title = W:Font(reportPopup, 9, C.accent, "OUTLINE")
    title:SetPoint("TOPLEFT", 40, -10)
    title:SetText(LJ.L("REPORT_TITLE"))

    local close = W:Button(reportPopup, "×", 20, 20)
    close:SetPoint("TOPRIGHT", -10, -8)
    close.label:SetFont(FONT, 14, "")
    close.label:SetPoint("CENTER", 0, 1)
    close:SetScript("OnClick", function() reportPopup:Hide() end)

    local sub = W:Font(reportPopup, 9, C.muted, "")
    sub:SetPoint("TOPLEFT", 40, -27)
    sub:SetText(LJ.L("REPORT_SUB"))

    local targetLabel = W:Font(reportPopup, 9, C.muted, "")
    targetLabel:SetPoint("TOPLEFT", 14, -56)
    targetLabel:SetText(LJ.L("REPORT_WHISPER_LABEL"))

    reportEdit = CreateFrame("EditBox", nil, reportPopup, BackdropTemplateMixin and "BackdropTemplate" or nil)
    reportEdit:SetSize(200, 24)
    reportEdit:SetPoint("TOPLEFT", 104, -50)
    if reportEdit.SetBackdrop then
        reportEdit:SetBackdrop({
            bgFile = WHITE,
            edgeFile = WHITE,
            edgeSize = 1,
            insets = { left = 2, right = 2, top = 2, bottom = 2 },
        })
        reportEdit:SetBackdropColor(0.04, 0.045, 0.06, 1)
        reportEdit:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 1)
    end
    reportEdit:SetAutoFocus(false)
    reportEdit:SetMaxLetters(64)
    reportEdit:SetFont(FONT, 10, "")
    reportEdit:SetTextColor(C.text[1], C.text[2], C.text[3])
    reportEdit:SetTextInsets(8, 8, 0, 0)
    reportEdit:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        reportPopup:Hide()
    end)
    reportEdit:SetScript("OnEnterPressed", function(self)
        UI:SendReport("WHISPER", self:GetText())
    end)

    local hint = W:Font(reportPopup, 9, C.dim, "")
    hint:SetPoint("TOPLEFT", 14, -80)
    hint:SetWidth(292)
    hint:SetText(LJ.L("REPORT_TARGET_HINT"))

    reportError = W:Font(reportPopup, 9, C.red, "")
    reportError:SetPoint("TOPLEFT", 14, -94)
    reportError:SetWidth(292)
    reportError:SetText("")

    local party = W:Button(reportPopup, LJ.L("REPORT_PARTY"), 90, 22)
    party:SetPoint("BOTTOMLEFT", 14, 12)
    party:SetScript("OnClick", function() UI:SendReport("PARTY") end)

    local whisper = W:Button(reportPopup, LJ.L("REPORT_WHISPER"), 90, 22)
    whisper:SetPoint("BOTTOMLEFT", 112, 12)
    whisper:SetScript("OnClick", function() UI:SendReport("WHISPER", reportEdit:GetText()) end)

    local cancel = W:Button(reportPopup, LJ.L("REPORT_CANCEL"), 90, 22)
    cancel:SetPoint("BOTTOMLEFT", 210, 12)
    cancel:SetScript("OnClick", function() reportPopup:Hide() end)
end

local function createFrame()
    frame = CreateFrame("Frame", "LootJinxFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    UI.frame = frame
    frame:SetSize(640, 628)
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    if frame.SetClampedToScreen then frame:SetClampedToScreen(true) end
    applyBackdrop(frame)

    local top = frame:CreateTexture(nil, "ARTWORK")
    top:SetPoint("TOPLEFT", 1, -1)
    top:SetPoint("TOPRIGHT", -1, -1)
    top:SetHeight(2)
    W:SetGradient(top, true, C.accent, C.cyan)

    local watermark = frame:CreateTexture(nil, "BACKGROUND")
    watermark:SetPoint("BOTTOMRIGHT", -18, 44)
    watermark:SetSize(110, 110)
    watermark:SetTexture(MEDIA .. "LootJinxIcon")
    watermark:SetBlendMode("ADD")
    watermark:SetAlpha(0.08)
    frame.watermark = watermark

    local function safe(label, fn)
        local ok, err = pcall(fn)
        if not ok then
            LJ.lastRefreshError = label .. ": " .. tostring(err)
            LJ:Print(LJ.L("ERROR_PART", label, tostring(err)))
        end
    end

    safe("Header", createHeader)
    safe("Hero", createHero)
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
        if reportPopup then reportPopup:Hide() end
        if LJ.History then LJ.History:Hide() end
        if LJ.RunDetail and type(LJ.RunDetail.Hide) == "function" then
            pcall(LJ.RunDetail.Hide, LJ.RunDetail)
        end
        if statusPill and statusPill.dot then statusPill.dot:SetAlpha(1) end
    end)
    frame:SetScript("OnUpdate", function(_, elapsed)
        if not statusPill or not statusPill.dot then return end
        if LJ.Tracker and LJ.Tracker:IsLive() then
            pulse = (pulse + elapsed) % 1.6
            local a = 0.45 + 0.55 * math.abs(math.sin(pulse * math.pi / 1.6))
            statusPill.dot:SetAlpha(a)
        else
            statusPill.dot:SetAlpha(1)
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
        StaticPopupDialogs["LOOTJINX_RESET"] = {
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
        }
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

    local stats = {}
    section("Stats", function() stats = LJ.Stats.Compute(LJ.Tracker:GetRuns()) end)
    UI.stats = stats
    local statLabel, statShort = "", ""
    section("Stat", function()
        local _, label = LJ:PlayerStat()
        statLabel = label or ""
        statShort = LJ:StatShort() or ""
    end)

    local active, live
    section("Status", function()
        active = LJ.Tracker:GetActive()
        live = LJ.Tracker:IsLive()
    end)
    if statusPill then
        if live and active then
            statusPill:SetState(LJ.L("STATUS_LIVE") .. " · " .. W:Truncate(active.name, 18), C.green, C.green)
        elseif active then
            statusPill:SetState(LJ.L("STATUS_IDLE") .. " · " .. W:Truncate(active.name, 16), C.orange, C.orange)
        else
            statusPill:SetState(LJ.L("STATUS_READY"), C.muted, C.dim)
        end
    end

    local total = stats.totalDungeons or 0
    local noAgi = stats.noAgiDungeons or 0
    local pct = total > 0 and math.floor((noAgi / total) * 100 + 0.5) or 0
    if hero then
        setText(hero.value, total > 0 and string.format("%d / %d", noAgi, total) or "0 / 0")
        setText(hero.sub, total > 0 and LJ.L("CARD_CURSE_SUB", statLabel) or LJ.L("CARD_CURSE_EMPTY"))
        setText(hero.pct, LJ.L("CARD_CURSE_PCT", pct, statLabel))
        hero.bar:SetValue(total > 0 and (noAgi / total) or 0)
        setText(hero.streakValue, stats.noAgiCurrent or 0)
        setText(hero.recordValue, stats.noAgiMax or 0)
    end

    if needCard then
        if stats.needRolls > 0 then
            setText(needCard.value, stats.needLost or 0)
            setText(needCard.sub, LJ.L("CARD_NEED_TOTAL", stats.needRolls or 0))
            local extra = LJ.L("CARD_NEED_WINS", stats.needWins or 0)
            if (stats.needPending or 0) > 0 then
                extra = extra .. " · " .. LJ.L("CARD_NEED_PENDING", stats.needPending)
            end
            setText(needCard.sub2, extra)
            local rate = math.floor((stats.winRate or 0) + 0.5)
            setText(needCard.pct, LJ.L("CARD_NEED_WINRATE", rate))
            needCard.bar:SetValue((stats.winRate or 0) / 100)
        else
            setText(needCard.value, "0")
            setText(needCard.sub, LJ.L("CARD_NEED_NO_DATA"))
            setText(needCard.sub2, "")
            setText(needCard.pct, LJ.L("NO_DATA"))
            needCard.bar:SetValue(0)
        end
        setText(needCard.streakValue, stats.lostNeedCurrent or 0)
        setText(needCard.recordValue, stats.lostNeedMax or 0)
    end

    if miniNoWin then
        setText(miniNoWin.value, stats.noNeedWinDungeons or 0)
        setText(miniNoWin.footer, colored(C.muted, LJ.L("STREAK") .. " ")
            .. colored(C.text, stats.noNeedWinCurrent or 0) .. "   "
            .. colored(C.gold, LJ.L("RECORD") .. " " .. tostring(stats.noNeedWinMax or 0)))
    end

    if miniNoLoot then
        setText(miniNoLoot.value, stats.noLootDungeons or 0)
        setText(miniNoLoot.footer, colored(C.muted, LJ.L("STREAK") .. " ")
            .. colored(C.text, stats.noLootCurrent or 0) .. "   "
            .. colored(C.gold, LJ.L("RECORD") .. " " .. tostring(stats.noLootMax or 0)))
    end

    if miniSince then
        setText(miniSince.value, stats.sinceNeedWinCurrent or 0)
        setText(miniSince.footer, colored(C.gold, LJ.L("RECORD") .. " " .. tostring(stats.sinceNeedWinMax or 0)))
    end

    if frame.footer then
        setText(frame.footer, LJ.L("FOOTER_CLASS", select(1, LJ:ClassName()), statLabel)
            .. " · " .. LJ.L("FOOTER_HINT"))
    end

    local runs = {}
    section("Runs", function() runs = LJ.Tracker:GetRuns() end)
    local shown = 0
    for i = 1, 4 do
        local row = recentRows[i]
        if row then row:Hide() end
    end
    if not recentCard then return end
    if recentCard.empty then recentCard.empty:Hide() end
    if #runs == 0 then
        if recentCard.empty then recentCard.empty:Show() end
    else
        for idx = #runs, math.max(1, #runs - 3), -1 do
            shown = shown + 1
            local run = runs[idx]
            local row = recentRows[shown]
            if row and run then
                row.run = run
                row.clickable = run.legacy ~= true
                row:Show()
                local name = W:Truncate(run.name or LJ.L("UNKNOWN_DUNGEON"), 36)
                if active == run then
                    local status = live and LJ.L("LIVE") or LJ.L("STATUS_IDLE")
                    row.name:SetText(colored(C.green, status .. " ") .. colored(C.text, name))
                    row.bar:SetColorTexture(C.green[1], C.green[2], C.green[3], 1)
                else
                    row.name:SetText(colored(run.agilityDropped and C.text or C.muted, name))
                    local c = run.agilityDropped and C.green or C.red
                    row.bar:SetColorTexture(c[1], c[2], c[3], 0.85)
                end
                setText(row.date, dateLabel(run))
                local totalNeeds, wins = 0, 0
                for _, n in ipairs(run.needs or {}) do
                    totalNeeds = totalNeeds + 1
                    if n.result == "won" then wins = wins + 1 end
                end
                local badges = colored(run.agilityDropped and C.green or C.red,
                    run.agilityDropped and LJ.L("BADGE_STAT", statShort) or LJ.L("BADGE_NO_STAT", statShort))
                if totalNeeds > 0 then
                    badges = badges .. " · " .. colored(wins > 0 and C.green or C.red,
                        LJ.L("BADGE_NEED", wins, totalNeeds))
                end
                if not run.lootSeen then
                    badges = badges .. " · " .. colored(C.muted, LJ.L("BADGE_EMPTY"))
                end
                setText(row.badges, LJ.RecentRolls:Summary(run) or badges)
            end
        end
    end
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
    if scale < 0.80 then scale = 0.80 end
    if scale > 1.30 then scale = 1.30 end
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
    frame:SetHeight(compact and 476 or 628)
    if recentCard then recentCard:SetShown(not compact) end
    if frame.watermark then frame.watermark:SetShown(LJ.DB.showWatermark ~= false) end
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
    LJ:Print(LJ.L("CHAT_HELP_4"))
    LJ:Print(LJ.L("CHAT_HELP_5"))
    LJ:Print(LJ.L("CHAT_HELP_6"))
end

function LJ:HandleCommand(msg)
    msg = tostring(msg or ""):match("^%s*(.-)%s*$")
    local cmd, rest = msg:match("^(%S*)%s*(.-)$")
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
    elseif cmd == "scale" then
        local value = tonumber(rest)
        if value and value >= 0.80 and value <= 1.30 then
            if LJ.UI then LJ.UI:ApplyScale(value) end
            LJ:Print(LJ.L("CHAT_SCALE_SET", value))
        else
            LJ:Print(LJ.L("CHAT_SCALE_RANGE"))
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
