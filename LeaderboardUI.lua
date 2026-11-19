-- LootJinx – Fenster für das rulesetweite Leaderboard
local ADDON, ns = ...
local LJ = ns or _G.LootJinx
if not LJ then return end

local LUI = {}
LJ.LeaderboardUI = LUI
local W = LJ.Widgets
local CLASSIC = LJ.COLORS
local JOURNAL = {
    bg = { 0.141, 0.102, 0.102, 0.98 },
    card = { 0.190, 0.145, 0.133, 0.98 },
    border = { 0.545, 0.384, 0.267, 1 },
    accent = { 0.957, 0.820, 0.490, 1 },
    text = { 0.957, 0.898, 0.824, 1 },
    muted = { 0.820, 0.760, 0.670, 1 },
    dim = { 0.680, 0.620, 0.520, 1 },
    green = { 0.400, 0.850, 0.400, 1 },
    red = { 0.900, 0.350, 0.350, 1 },
    gold = { 1.000, 0.820, 0.380, 1 },
    parchment = { 0.960, 0.910, 0.830, 1 },
}
local C = CLASSIC
local WHITE = "Interface\\Buttons\\WHITE8X8"

local ROW_HEIGHT = 24
local ROW_COUNT = 51
local LIST_HEIGHT = 292
local MODES = { "wins", "quote", "streak" }
local TAB_KEYS = {
    wins = "LEADERBOARD_TAB_WINS",
    quote = "LEADERBOARD_TAB_QUOTE",
    streak = "LEADERBOARD_TAB_STREAK",
}
local TT_KEYS = {
    wins = "LEADERBOARD_TT_WINS",
    quote = "LEADERBOARD_TT_QUOTE",
    streak = "LEADERBOARD_TT_STREAK",
}

-- Medaillen-Farben und Styling für Platz 1-3
local MEDALS = {
    [1] = {
        name = "Gold",
        color = { 1.000, 0.843, 0.000, 1.0 },     -- Strahlendes Gold
        border = { 1.000, 0.820, 0.200, 1.0 },    -- Goldener Leuchtrahmen
        classicBg = { 0.220, 0.170, 0.040, 0.95 },-- Gold-Hintergrund Classic
        classicHover = { 0.280, 0.220, 0.060, 0.98 },
        journalBg = { 0.260, 0.180, 0.080, 0.96 },-- Gold-Hintergrund Journal
        journalBorder = { 0.960, 0.820, 0.300, 1.0 },
        journalHover = { 0.320, 0.230, 0.110, 0.98 },
        icon = "Interface\\MoneyFrame\\UI-GoldIcon",
    },
    [2] = {
        name = "Silber",
        color = { 0.880, 0.910, 0.960, 1.0 },     -- Helles Silber
        border = { 0.750, 0.820, 0.920, 0.95 },
        classicBg = { 0.120, 0.140, 0.180, 0.95 },
        classicHover = { 0.160, 0.190, 0.240, 0.98 },
        journalBg = { 0.180, 0.155, 0.155, 0.96 },
        journalBorder = { 0.780, 0.820, 0.900, 0.95 },
        journalHover = { 0.230, 0.200, 0.200, 0.98 },
        icon = "Interface\\MoneyFrame\\UI-SilverIcon",
    },
    [3] = {
        name = "Bronze",
        color = { 0.900, 0.580, 0.320, 1.0 },     -- Warmes Bronze
        border = { 0.820, 0.500, 0.280, 0.95 },
        classicBg = { 0.160, 0.100, 0.060, 0.95 },
        classicHover = { 0.210, 0.140, 0.085, 0.98 },
        journalBg = { 0.210, 0.135, 0.100, 0.96 },
        journalBorder = { 0.800, 0.500, 0.280, 0.95 },
        journalHover = { 0.260, 0.175, 0.130, 0.98 },
        icon = "Interface\\MoneyFrame\\UI-CopperIcon",
    },
}

local function rgba(c) return c[1], c[2], c[3], c[4] or 1 end

local function paint(frame, color, edge)
    if not frame or not frame.SetBackdrop then return end
    frame:SetBackdrop({
        bgFile = WHITE, edgeFile = WHITE, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    frame:SetBackdropColor(rgba(color))
    frame:SetBackdropBorderColor(rgba(edge))
end

local function classColor(class)
    local c = _G.RAID_CLASS_COLORS and _G.RAID_CLASS_COLORS[class]
    if c then return c.r or 1, c.g or 1, c.b or 1 end
    return C.text[1], C.text[2], C.text[3]
end

local function className(class)
    local names = _G.LOCALIZED_CLASS_NAMES_MALE
    if names and names[class] then return names[class] end
    names = _G.LOCALIZED_CLASS_NAMES_FEMALE
    if names and names[class] then return names[class] end
    return LJ.L("UNKNOWN_CLASS")
end

local function valueText(entry, mode)
    if mode == "wins" then return tostring(entry.wins or 0) end
    if mode == "streak" then return tostring(entry.streak or 0) end
    if not entry.quote then return LJ.L("LEADERBOARD_NO_VALUE") end
    return string.format("%d %%", math.floor(entry.quote * 100 + 0.5))
end

local function tintButton(button, journal)
    if not button then return end
    if not button.classicOnEnter then
        button.classicOnEnter = button:GetScript("OnEnter")
        button.classicOnLeave = button:GetScript("OnLeave")
    end
    if journal then
        if button.SetBackdropColor then button:SetBackdropColor(0.114, 0.086, 0.082, 0.96) end
        if button.SetBackdropBorderColor then
            button:SetBackdropBorderColor(JOURNAL.border[1], JOURNAL.border[2], JOURNAL.border[3], 1)
        end
        if button.label then button.label:SetTextColor(JOURNAL.text[1], JOURNAL.text[2], JOURNAL.text[3], 1) end
        button:SetScript("OnEnter", function(self)
            if self.SetBackdropColor then
                self:SetBackdropColor(JOURNAL.card[1], JOURNAL.card[2], JOURNAL.card[3], 1)
            end
            if self.SetBackdropBorderColor then
                self:SetBackdropBorderColor(JOURNAL.accent[1], JOURNAL.accent[2], JOURNAL.accent[3], 1)
            end
        end)
        button:SetScript("OnLeave", function(self)
            if self.SetBackdropColor then self:SetBackdropColor(0.114, 0.086, 0.082, 0.96) end
            if self.SetBackdropBorderColor then
                self:SetBackdropBorderColor(JOURNAL.border[1], JOURNAL.border[2], JOURNAL.border[3], 1)
            end
        end)
    else
        if button.SetBackdropColor then button:SetBackdropColor(0.10, 0.11, 0.14, 0.96) end
        if button.SetBackdropBorderColor then
            button:SetBackdropBorderColor(CLASSIC.border[1], CLASSIC.border[2], CLASSIC.border[3], 1)
        end
        if button.label then button.label:SetTextColor(CLASSIC.muted[1], CLASSIC.muted[2], CLASSIC.muted[3], 1) end
        button:SetScript("OnEnter", button.classicOnEnter)
        button:SetScript("OnLeave", button.classicOnLeave)
    end
end

local function paintTab(button, active)
    if not button or not button.SetBackdropColor then return end
    local isJournal = (C == JOURNAL)
    button.active = active
    if active then
        if isJournal then
            button:SetBackdropColor(0.240, 0.170, 0.140, 0.98)
            button:SetBackdropBorderColor(rgba(JOURNAL.accent))
            button.label:SetTextColor(rgba(JOURNAL.gold))
            if button.label.SetFont then pcall(button.label.SetFont, button.label, "Fonts\\MORPHEUS.TTF", 12, "") end
        else
            button:SetBackdropColor(C.accent[1] * 0.22, C.accent[2] * 0.22, C.accent[3] * 0.22, 0.98)
            button:SetBackdropBorderColor(rgba(C.accent))
            button.label:SetTextColor(rgba(C.text))
            if button.label.SetFont then pcall(button.label.SetFont, button.label, STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 11, "OUTLINE") end
        end
    else
        local inactiveBg = isJournal and { 0.114, 0.086, 0.082, 0.96 } or { 0.070, 0.080, 0.100, 0.95 }
        button:SetBackdropColor(rgba(inactiveBg))
        button:SetBackdropBorderColor(rgba(C.border))
        button.label:SetTextColor(rgba(C.muted))
        if button.label.SetFont then pcall(button.label.SetFont, button.label, STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 10, "") end
    end
end

function LUI:Create()
    if self.frame then return self.frame end
    local f = CreateFrame("Frame", "LootJinxLeaderboardFrame", UIParent,
        BackdropTemplateMixin and "BackdropTemplate" or nil)
    self.frame = f
    f:SetSize(560, 480)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    f:SetFrameStrata("DIALOG")
    f:SetFrameLevel(120)
    f:SetToplevel(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    if f.SetClampedToScreen then f:SetClampedToScreen(true) end
    paint(f, C.bg, C.border)

    local sheen = f:CreateTexture(nil, "BORDER")
    sheen:SetPoint("TOPLEFT", 1, -1)
    sheen:SetPoint("TOPRIGHT", -1, -1)
    sheen:SetHeight(48)
    W:SetGradient(sheen, false, { 1, 1, 1, 0.035 }, { 1, 1, 1, 0 })
    self.sheen = sheen

    local top = f:CreateTexture(nil, "ARTWORK")
    top:SetPoint("TOPLEFT", 1, -1)
    top:SetPoint("TOPRIGHT", -1, -1)
    top:SetHeight(2)
    top:SetColorTexture(rgba(C.accent))
    top:Hide()
    self.topAccent = top

    self.title = W:Font(f, 16, C.text, "OUTLINE")
    self.title:SetPoint("TOPLEFT", 16, -14)
    self.title:SetText(LJ.L("LEADERBOARD_TITLE"))

    self.status = W:Font(f, 9, C.muted, "")
    self.status:SetPoint("TOPLEFT", 17, -36)
    self.status:SetWidth(430)
    self.status:SetWordWrap(false)

    local close = W:Button(f, "×", 22, 22)
    close:SetPoint("TOPRIGHT", -14, -14)
    close.label:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 14, "")
    close:SetScript("OnClick", function() LUI:Hide() end)
    self.closeButton = close

    local drag = CreateFrame("Frame", nil, f)
    drag:SetPoint("TOPLEFT", 0, 0)
    drag:SetSize(420, 56)
    drag:EnableMouse(true)
    drag:RegisterForDrag("LeftButton")
    drag:SetScript("OnDragStart", function() f:StartMoving() end)
    drag:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)

    self.tabs = {}
    for i, mode in ipairs(MODES) do
        local tab = W:Button(f, LJ.L(TAB_KEYS[mode]), 166, 26)
        tab:SetPoint("TOPLEFT", 16 + (i - 1) * 174, -58)
        tab:SetScript("OnClick", function() LUI:SetMode(mode) end)
        tab:SetScript("OnEnter", function(self)
            if not self.active then
                local isJournal = (C == JOURNAL)
                if self.SetBackdropBorderColor then
                    self:SetBackdropBorderColor(rgba(isJournal and JOURNAL.border or C.borderHot))
                end
                if self.SetBackdropColor then
                    local hBg = isJournal and { 0.170, 0.125, 0.115, 0.98 } or { 0.100, 0.115, 0.145, 0.98 }
                    self:SetBackdropColor(rgba(hBg))
                end
                self.label:SetTextColor(rgba(isJournal and JOURNAL.parchment or C.text))
            end
        end)
        tab:SetScript("OnLeave", function(self)
            paintTab(self, self.active)
        end)
        W:Tooltip(tab, LJ.L(TAB_KEYS[mode]), {
            mode == "quote" and LJ.L(TT_KEYS[mode], LJ.Leaderboard.MIN_DECIDED)
                or LJ.L(TT_KEYS[mode]),
        })
        self.tabs[mode] = tab
    end

    -- Tabellen-Container
    local tableCard = CreateFrame("Frame", nil, f, BackdropTemplateMixin and "BackdropTemplate" or nil)
    tableCard:SetPoint("TOPLEFT", 14, -92)
    tableCard:SetPoint("BOTTOMRIGHT", -14, 38)
    paint(tableCard, { 0.045, 0.052, 0.070, 0.96 }, C.border)
    self.tableCard = tableCard

    -- Tabellen-Kopfzeile
    local headerBar = CreateFrame("Frame", nil, tableCard, BackdropTemplateMixin and "BackdropTemplate" or nil)
    headerBar:SetPoint("TOPLEFT", 1, -1)
    headerBar:SetPoint("TOPRIGHT", -1, -1)
    headerBar:SetHeight(22)
    paint(headerBar, { 0.035, 0.040, 0.055, 0.98 }, { 0, 0, 0, 0 })
    self.headerBar = headerBar

    local headerDivider = headerBar:CreateTexture(nil, "ARTWORK")
    headerDivider:SetPoint("BOTTOMLEFT", 0, 0)
    headerDivider:SetPoint("BOTTOMRIGHT", 0, 0)
    headerDivider:SetHeight(1)
    headerDivider:SetColorTexture(rgba(C.border))
    self.headerDivider = headerDivider

    local headers = {
        { key = "LEADERBOARD_COL_RANK", x = 8, width = 38, justify = "CENTER" },
        { key = "LEADERBOARD_COL_PLAYER", x = 50, width = 184, justify = "LEFT" },
        { key = "LEADERBOARD_COL_REALM", x = 240, width = 140, justify = "LEFT" },
        { key = "LEADERBOARD_COL_VALUE", x = 390, width = 90, justify = "RIGHT" },
    }
    self.headers = {}
    for _, header in ipairs(headers) do
        local text = W:Font(headerBar, 9, C.dim, "")
        text:SetPoint("LEFT", header.x, 0)
        text:SetWidth(header.width)
        text:SetJustifyH(header.justify)
        text:SetText(LJ.L(header.key))
        self.headers[#self.headers + 1] = text
    end

    self.child = CreateFrame("Frame", nil, f)
    self.child:SetSize(504, 1)
    self.scroll = CreateFrame("ScrollFrame", nil, f)
    self.scroll:SetPoint("TOPLEFT", tableCard, "TOPLEFT", 4, -25)
    self.scroll:SetPoint("BOTTOMRIGHT", tableCard, "BOTTOMRIGHT", -20, 4)
    self.scroll:SetScrollChild(self.child)
    self.scroll:EnableMouseWheel(true)

    self.slider = CreateFrame("Slider", nil, f)
    self.slider:SetPoint("TOPLEFT", self.scroll, "TOPRIGHT", 4, -1)
    self.slider:SetPoint("BOTTOMLEFT", self.scroll, "BOTTOMRIGHT", 4, 1)
    self.slider:SetWidth(10)
    self.slider:SetOrientation("VERTICAL")
    self.slider:SetMinMaxValues(0, 1)
    self.slider:SetValueStep(1)
    local thumb = self.slider:CreateTexture(nil, "ARTWORK")
    thumb:SetSize(8, 40)
    thumb:SetColorTexture(rgba(C.accent))
    self.slider:SetThumbTexture(thumb)
    self.sliderThumb = thumb
    self.slider:SetScript("OnValueChanged", function(_, value)
        LUI.scroll:SetVerticalScroll(tonumber(value) or 0)
    end)
    self.scroll:SetScript("OnMouseWheel", function(self, delta)
        local value = self:GetVerticalScroll() - (tonumber(delta) or 0) * ROW_HEIGHT * 3
        if value < 0 then value = 0 end
        local _, maxValue = LUI.slider:GetMinMaxValues()
        if value > maxValue then value = maxValue end
        self:SetVerticalScroll(value)
        LUI.slider:SetValue(value)
    end)

    self.rows = {}
    for i = 1, ROW_COUNT do
        local row = W:Button(self.child, "", 504, 22)
        row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)
        row.label:Hide()

        -- Medaillen-Icon (14x14) für Platz 1-3
        local medal = row:CreateTexture(nil, "ARTWORK")
        medal:SetSize(14, 14)
        medal:SetPoint("LEFT", 6, 0)
        row.medal = medal

        row.rank = W:Font(row, 11, C.muted, "OUTLINE")
        row.rank:SetPoint("LEFT", 6, 0)
        row.rank:SetWidth(38)
        row.rank:SetJustifyH("CENTER")

        row.name = W:Font(row, 10, C.text, "OUTLINE")
        row.name:SetPoint("LEFT", 48, 0)
        row.name:SetWidth(186)
        row.name:SetWordWrap(false)

        row.realm = W:Font(row, 9, C.muted, "")
        row.realm:SetPoint("LEFT", 240, 0)
        row.realm:SetWidth(140)
        row.realm:SetWordWrap(false)

        row.value = W:Font(row, 10, C.text, "OUTLINE")
        row.value:SetPoint("LEFT", 390, 0)
        row.value:SetWidth(90)
        row.value:SetJustifyH("RIGHT")

        row.dot = row:CreateTexture(nil, "ARTWORK")
        row.dot:SetSize(7, 7)
        row.dot:SetPoint("LEFT", 492, 0)

        row:SetScript("OnEnter", function(self)
            if self.hoverBg and self.SetBackdropColor then
                self:SetBackdropColor(rgba(self.hoverBg))
            end
            if self.hoverBorder and self.SetBackdropBorderColor then
                self:SetBackdropBorderColor(rgba(self.hoverBorder))
            end
            local entry = self.entry
            if not entry or not GameTooltip then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(entry.name, 1, 1, 1)
            GameTooltip:AddLine(className(entry.class) .. (entry.realm and (" – " .. entry.realm) or ""), 0.72, 0.75, 0.82)
            if entry.rank and entry.rank <= 3 then
                local medalData = MEDALS[entry.rank]
                local medalName = medalData and medalData.name or tostring(entry.rank)
                local medalCol = medalData and medalData.color or { 1, 1, 1 }
                GameTooltip:AddLine(string.format("#%d (%s)", entry.rank, medalName), medalCol[1], medalCol[2], medalCol[3])
            else
                GameTooltip:AddLine(string.format("#%d", entry.rank or 0), 0.7, 0.7, 0.7)
            end
            if entry.wins or entry.losses then
                GameTooltip:AddLine(string.format("%s: %d  |  %s: %d",
                    LJ.L("STATS_WINS") or "Siege", entry.wins or 0,
                    LJ.L("STATS_LOSSES") or "Niederlagen", entry.losses or 0), 0.9, 0.82, 0.5)
            end
            if entry.streak and entry.streak > 0 then
                GameTooltip:AddLine(string.format("%s: %d", LJ.L("LEADERBOARD_TAB_STREAK"), entry.streak), 0.9, 0.5, 0.4)
            end
            if entry.online then
                GameTooltip:AddLine(LJ.L("LEADERBOARD_ONLINE"), C.green[1], C.green[2], C.green[3])
            else
                GameTooltip:AddLine(LJ.L("LEADERBOARD_OFFLINE"), C.muted[1], C.muted[2], C.muted[3])
            end
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function(self)
            if self.restingBg and self.SetBackdropColor then
                self:SetBackdropColor(rgba(self.restingBg))
            end
            if self.restingBorder and self.SetBackdropBorderColor then
                self:SetBackdropBorderColor(rgba(self.restingBorder))
            end
            if GameTooltip then GameTooltip:Hide() end
        end)
        row:Hide()
        self.rows[i] = row
    end

    self.empty = W:Font(tableCard, 11, C.muted, "")
    self.empty:SetPoint("CENTER", tableCard, "CENTER", 0, 14)
    self.empty:SetWidth(460)
    self.empty:SetJustifyH("CENTER")
    self.empty:SetWordWrap(true)
    self.empty:SetText(LJ.L("LEADERBOARD_EMPTY"))

    self.emptyHint = W:Font(tableCard, 9, C.dim, "")
    self.emptyHint:SetPoint("TOP", self.empty, "BOTTOM", 0, -8)
    self.emptyHint:SetWidth(460)
    self.emptyHint:SetJustifyH("CENTER")
    self.emptyHint:SetWordWrap(true)
    self.emptyHint:SetText(LJ.L("LEADERBOARD_EMPTY_HINT"))

    self.hint = W:Font(f, 8, C.dim, "")
    self.hint:SetPoint("BOTTOMLEFT", 18, 14)
    self.hint:SetWidth(520)
    self.hint:SetWordWrap(true)

    if UISpecialFrames then
        local found = false
        for _, entry in ipairs(UISpecialFrames) do
            if entry == "LootJinxLeaderboardFrame" then found = true break end
        end
        if not found then table.insert(UISpecialFrames, "LootJinxLeaderboardFrame") end
    end

    f:SetScript("OnShow", function() LUI:Refresh() end)
    if LJ.RegisterRefresh then
        LJ:RegisterRefresh(function()
            if LUI.frame and LUI.frame:IsShown() then LUI:Refresh() end
        end)
    end
    self.mode = "wins"
    self:Refresh()
    f:Hide()
    return f
end

function LUI:SetMode(mode)
    if mode ~= "quote" and mode ~= "streak" then mode = "wins" end
    self.mode = mode
    self:Refresh()
end

function LUI:Refresh()
    if not self.frame or not LJ.Leaderboard then return end
    local mode = self.mode or "wins"
    local entries = LJ.Leaderboard:Ranking(mode, time())
    local display = {}
    for i = 1, math.min(#entries, LJ.Leaderboard.TOP_N) do
        display[#display + 1] = entries[i]
    end
    local own
    for _, entry in ipairs(entries) do
        if entry.isSelf then own = entry break end
    end
    if own and own.rank > LJ.Leaderboard.TOP_N then display[#display + 1] = own end
    self.display = display
    self.entries = entries

    for modeKey, tab in pairs(self.tabs) do paintTab(tab, modeKey == mode) end
    self.status:SetText(LJ.Leaderboard:StatusText())

    local consent = LJ.Leaderboard:Consent()
    if consent == true then
        self.hint:SetText(LJ.L("LEADERBOARD_MIN_ROLLS", LJ.Leaderboard.MIN_DECIDED))
    else
        self.hint:SetText(LJ.L("LEADERBOARD_CONSENT_HINT"))
    end

    local hasOther = false
    for _, entry in ipairs(entries) do
        if not entry.isSelf then hasOther = true break end
    end
    self.empty:SetShown(not hasOther)
    self.emptyHint:SetShown(not hasOther)

    local appended = #display > LJ.Leaderboard.TOP_N and display[#display].isSelf == true
    local gap = appended and 8 or 0
    self.child:SetSize(504, math.max(1, #display * ROW_HEIGHT + gap))
    local maxScroll = math.max(0, #display * ROW_HEIGHT + gap - LIST_HEIGHT)
    self.slider:SetMinMaxValues(0, math.max(1, maxScroll))
    if self.scroll:GetVerticalScroll() > maxScroll then
        self.scroll:SetVerticalScroll(maxScroll)
        self.slider:SetValue(maxScroll)
    end

    local isJournal = (C == JOURNAL)
    for i = 1, #self.rows do
        local row = self.rows[i]
        local entry = display[i]
        row.entry = entry
        if entry then
            local extra = (entry.isSelf and i > LJ.Leaderboard.TOP_N) and 8 or 0
            row:SetPoint("TOPLEFT", 0, -((i - 1) * ROW_HEIGHT + extra))
            row.rank:SetText(tostring(entry.rank))
            row.realm:SetText(entry.realm or "")
            row.value:SetText(valueText(entry, mode))

            local medal = MEDALS[entry.rank]
            if medal then
                row.medal:SetTexture(medal.icon)
                row.medal:Show()
                row.rank:ClearAllPoints()
                row.rank:SetPoint("LEFT", row.medal, "RIGHT", 2, 0)
                row.rank:SetWidth(20)
                row.rank:SetJustifyH("LEFT")
                row.rank:SetTextColor(rgba(medal.color))

                local bg = isJournal and medal.journalBg or medal.classicBg
                local border = isJournal and medal.journalBorder or medal.border
                local hoverBg = isJournal and medal.journalHover or medal.classicHover

                if entry.isSelf then
                    row.name:SetText(LJ.L("LEADERBOARD_YOU") .. "  " .. entry.name)
                else
                    row.name:SetText(entry.name)
                end

                -- Platz 1-3 strahlen in ihrer Medaillenfarbe (Gold, Silber, Bronze)
                row.name:SetTextColor(rgba(medal.color))
                row.value:SetTextColor(rgba(medal.color))

                row.restingBg = bg
                row.restingBorder = border
                row.hoverBg = hoverBg
                row.hoverBorder = medal.color
                row:SetBackdropColor(rgba(bg))
                row:SetBackdropBorderColor(rgba(border))
            else
                row.medal:Hide()
                row.rank:ClearAllPoints()
                row.rank:SetPoint("LEFT", 6, 0)
                row.rank:SetWidth(38)
                row.rank:SetJustifyH("CENTER")
                row.rank:SetTextColor(rgba(C.muted))

                if entry.isSelf then
                    row.name:SetText(LJ.L("LEADERBOARD_YOU") .. "  " .. entry.name)
                    row.name:SetTextColor(rgba(C.accent))
                    local selfBg = isJournal and { 0.220, 0.170, 0.120, 0.98 } or { C.accent[1] * 0.16, C.accent[2] * 0.16, C.accent[3] * 0.16, 0.98 }
                    row.restingBg = selfBg
                    row.restingBorder = C.accent
                    row.hoverBg = isJournal and { 0.260, 0.200, 0.140, 0.98 } or { C.accent[1] * 0.26, C.accent[2] * 0.26, C.accent[3] * 0.26, 0.98 }
                    row.hoverBorder = C.accent
                    row:SetBackdropColor(rgba(selfBg))
                    row:SetBackdropBorderColor(rgba(C.accent))
                else
                    row.name:SetText(entry.name)
                    row.name:SetTextColor(classColor(entry.class))
                    local zebraBg
                    if i % 2 == 0 then
                        zebraBg = isJournal and { 0.165, 0.125, 0.118, 0.96 } or { 0.080, 0.090, 0.115, 0.96 }
                    else
                        zebraBg = isJournal and { 0.145, 0.108, 0.102, 0.96 } or { 0.065, 0.072, 0.092, 0.96 }
                    end
                    local hoverBg = isJournal and { 0.210, 0.160, 0.145, 0.98 } or { 0.115, 0.125, 0.160, 0.98 }
                    local border = C.border
                    local hoverBorder = isJournal and JOURNAL.accent or C.accent
                    row.restingBg = zebraBg
                    row.restingBorder = border
                    row.hoverBg = hoverBg
                    row.hoverBorder = hoverBorder
                    row:SetBackdropColor(rgba(zebraBg))
                    row:SetBackdropBorderColor(rgba(border))
                end

                row.value:SetTextColor(rgba(C.gold or C.text))
            end

            row.realm:SetTextColor(rgba(C.muted))
            row.dot:SetColorTexture(rgba(entry.online and C.green or C.dim))
            row:Show()
        else
            row:Hide()
        end
    end
end

function LUI:ApplyTheme(theme)
    theme = theme == "journal" and "journal" or (theme == "classic" and "classic" or (LJ.DB and LJ.DB.layoutPreview == "journal" and "journal" or "classic"))
    self.theme = theme
    C = (theme == "journal") and JOURNAL or CLASSIC
    if not self.frame then return end

    paint(self.frame, C.bg, C.border)
    if self.topAccent then
        self.topAccent:SetColorTexture(rgba(C.accent))
        self.topAccent:SetShown(theme == "journal")
    end
    if self.sheen then
        self.sheen:SetShown(theme == "classic")
    end
    if self.tableCard then
        local cardBg = (theme == "journal") and { 0.114, 0.086, 0.082, 0.96 } or { 0.045, 0.052, 0.070, 0.96 }
        paint(self.tableCard, cardBg, C.border)
    end
    if self.headerBar then
        local hBg = (theme == "journal") and { 0.145, 0.110, 0.100, 0.98 } or { 0.035, 0.040, 0.055, 0.98 }
        paint(self.headerBar, hBg, { 0, 0, 0, 0 })
    end
    if self.headerDivider then
        self.headerDivider:SetColorTexture(rgba(C.border))
    end
    if self.title then
        if theme == "journal" then
            pcall(self.title.SetFont, self.title, "Fonts\\MORPHEUS.TTF", 18, "")
            self.title:SetTextColor(rgba(JOURNAL.gold))
        else
            self.title:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 16, "OUTLINE")
            self.title:SetTextColor(rgba(C.text))
        end
    end
    if self.status then self.status:SetTextColor(rgba(C.muted)) end
    if self.closeButton then
        tintButton(self.closeButton, theme == "journal")
    end
    if self.headers then
        for _, h in ipairs(self.headers) do
            h:SetTextColor(rgba(theme == "journal" and JOURNAL.muted or C.dim))
        end
    end
    if self.sliderThumb then
        self.sliderThumb:SetColorTexture(rgba(C.accent))
    end
    if self.empty then self.empty:SetTextColor(rgba(C.muted)) end
    if self.emptyHint then self.emptyHint:SetTextColor(rgba(C.dim)) end
    if self.hint then self.hint:SetTextColor(rgba(C.dim)) end

    self:Refresh()
end

function LUI:Show(theme)
    if not self.frame then self:Create() end
    if not self.frame then
        LJ:Print(LJ.L("LEADERBOARD_STATUS_UNAVAILABLE"))
        return
    end
    theme = theme or (LJ.DB and LJ.DB.layoutPreview == "journal" and "journal" or "classic")
    self:ApplyTheme(theme)
    self.frame:Show()
    W:FadeIn(self.frame, 0.15)
    if LJ.Leaderboard and LJ.Leaderboard.ShowTestNotice then
        LJ.Leaderboard:ShowTestNotice()
    end
end

function LUI:Hide()
    if self.frame then self.frame:Hide() end
end

function LUI:IsShown()
    return self.frame and self.frame:IsShown() and true or false
end
