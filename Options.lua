-- LootJinx – Einstellungen (Interface > AddOns)
local ADDON, ns = ...
local LJ = ns or _G.LootJinx
if not LJ then return end

local O = {}
LJ.Options = O
local W = LJ.Widgets
local C = LJ.COLORS
local MEDIA = "Interface\\AddOns\\LootJinx\\Media\\"

-- SettingsPanel/OpenSettingsPanel sind geschützt: im Kampf loest der Aufruf
-- ein ADDON_ACTION_BLOCKED aus. pcall verhindert nur den Lua-Fehler, nicht die
-- Meldung des Clients, daher muessen diese Aufrufe vorher ausbleiben.
local function inCombat()
    return type(InCombatLockdown) == "function" and InCombatLockdown() == true
end

local panel
local registered = false
local controls = {}
O.controls = controls

local function versionText()
    local getter = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    if type(getter) == "function" then
        local ok, version = pcall(getter, "LootJinx", "Version")
        if ok and version and version ~= "" then return "v" .. tostring(version) end
    end
    return ""
end

local function applyOption(key)
    if key == "compact" then
        if LJ.UI and LJ.UI.ApplyDisplayOptions then LJ.UI:ApplyDisplayOptions() end
    end
end

local function languageName(code)
    for _, loc in ipairs(LJ.LOCALES or {}) do
        if loc.code == code then return loc.name end
    end
    return "Auto"
end

local function closeOptionsPanel()
    if not inCombat() then
        if SettingsPanel and SettingsPanel:IsShown() then SettingsPanel:Hide() end
        if InterfaceOptionsFrame and InterfaceOptionsFrame:IsShown() then InterfaceOptionsFrame:Hide() end
    end
    if panel and panel:IsShown() then panel:Hide() end
end

local function selectLanguage(code)
    if not LJ.DB then return end
    if LJ:LanguageFor(code) == LJ.lang then
        LJ.DB.language = code
        O:Refresh()
        return
    end
    if inCombat() then
        LJ:Print(LJ.L("OPT_LANGUAGE_COMBAT_LOCKED"))
        return
    end

    local reload = (C_UI and C_UI.Reload) or ReloadUI
    if type(reload) ~= "function" or type(StaticPopupDialogs) ~= "table"
        or type(StaticPopup_Show) ~= "function" then return end

    StaticPopupDialogs["LOOTJINX_RELOAD"] = {
        text = LJ.L("OPT_LANGUAGE_RELOAD_CONFIRM", languageName(code)),
        button1 = LJ.L("OPT_LANGUAGE_RELOAD"),
        button2 = LJ.L("OPT_LANGUAGE_RELOAD_CANCEL"),
        OnAccept = function(_, selectedCode)
            if inCombat() then
                LJ:Print(LJ.L("OPT_LANGUAGE_COMBAT_LOCKED"))
                return
            end
            if not LJ.DB or not selectedCode then return end
            closeOptionsPanel()
            LJ.DB.language = selectedCode
            reload()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
        exclusive = 1,
    }
    StaticPopup_Show("LOOTJINX_RELOAD", nil, nil, code)
end

local function createCheck(parent, key, labelText, hintText, y, rowWidth)
    local check = CreateFrame("CheckButton", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    check:SetSize(18, 18)
    check:SetPoint("TOPLEFT", 14, y)
    if check.SetBackdrop then
        check:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        check:SetBackdropColor(0.04, 0.045, 0.06, 1)
        check:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 1)
    end

    check.check = check:CreateTexture(nil, "ARTWORK")
    check.check:SetSize(14, 14)
    check.check:SetPoint("CENTER", 0, 0)
    check.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    check.check:Hide()

    local label = W:Font(parent, 10, C.text, "")
    label:SetPoint("TOPLEFT", 40, y + 1)
    label:SetText(labelText)

    local hint = W:Font(parent, 8, C.dim, "")
    hint:SetPoint("TOPLEFT", 40, y - 14)
    hint:SetWidth(rowWidth or 500)
    hint:SetText(hintText)

    local function highlight(active)
        if not check.SetBackdropBorderColor then return end
        if active then
            check:SetBackdropBorderColor(C.accent[1], C.accent[2], C.accent[3], 1)
        else
            check:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 1)
        end
    end

    check:SetScript("OnEnter", function() highlight(true) end)
    check:SetScript("OnLeave", function() highlight(false) end)
    check:SetScript("OnClick", function(self)
        local checked = self:GetChecked() and true or false
        LJ.DB[key] = checked
        self.check:SetShown(checked)
        applyOption(key)
    end)

    -- Die gesamte Zeile ist klickbar, nicht nur die kleine Checkbox.
    local hit = CreateFrame("Button", nil, parent)
    hit:SetPoint("TOPLEFT", 40, y + 4)
    hit:SetSize(rowWidth or 510, 30)
    hit:SetFrameLevel(check:GetFrameLevel() + 1)
    hit:SetScript("OnEnter", function() highlight(true) end)
    hit:SetScript("OnLeave", function() highlight(false) end)
    hit:SetScript("OnClick", function()
        check:SetChecked(not (check:GetChecked() and true or false))
        local handler = check:GetScript("OnClick")
        if handler then handler(check, "LeftButton") end
    end)

    return check
end

local function setCheck(check, value)
    if not check then return end
    value = value == true
    check:SetChecked(value)
    if check.check then check.check:SetShown(value) end
end

local function buildPanel()
    panel = CreateFrame("Frame", "LootJinxOptionsPanel")
    panel.name = LJ.L("OPTIONS_TAB")
    panel:SetSize(600, 524)
    panel:SetScript("OnShow", function() O:Refresh() end)
    panel:SetScript("OnHide", function()
        if controls.layoutMenu then controls.layoutMenu:Hide() end
        if controls.langMenu then controls.langMenu:Hide() end
    end)
    O.panel = panel

    local header = W:Card(panel)
    header:SetPoint("TOPLEFT", 16, -16)
    header:SetSize(568, 64)

    local iconFrame = W:Panel(header, "BACKGROUND")
    iconFrame:SetSize(38, 38)
    iconFrame:SetPoint("TOPLEFT", 14, -12)
    iconFrame:SetFrameLevel(header:GetFrameLevel() + 2)
    local icon = iconFrame:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 2, -2)
    icon:SetPoint("BOTTOMRIGHT", -2, 2)
    icon:SetTexture(MEDIA .. "LootJinxIcon")

    local title = W:Font(header, 20, C.text, "OUTLINE")
    title:SetPoint("TOPLEFT", 64, -12)
    title:SetText(LJ.L("OPTIONS_TAB"))

    local subtitle = W:Font(header, 10, C.muted, "")
    subtitle:SetPoint("TOPLEFT", 65, -36)
    subtitle:SetText(LJ.L("OPTIONS_TITLE"))

    local version = W:Font(header, 9, C.dim, "")
    version:SetPoint("TOPRIGHT", -14, -16)
    version:SetText(versionText())

    local window = W:Card(panel)
    window:SetPoint("TOPLEFT", 16, -88)
    window:SetSize(568, 64)

    local windowTitle = W:Font(window, 9, C.accent, "OUTLINE")
    windowTitle:SetPoint("TOPLEFT", 14, -10)
    windowTitle:SetText(LJ.L("OPT_WINDOW"))

    controls.compact = createCheck(window, "compact", LJ.L("OPT_COMPACT"), LJ.L("OPT_COMPACT_HINT"), -28, 354)

    local reset = W:Button(window, LJ.L("OPT_RESET_POS"), 150, 22)
    reset:SetPoint("TOPRIGHT", -14, -28)
    reset:SetScript("OnClick", function()
        if LJ.UI and LJ.UI.ResetPosition then LJ.UI:ResetPosition() end
    end)
    W:Tooltip(reset, LJ.L("OPT_RESET_POS"), { LJ.L("OPT_RESET_HINT") })

    local behavior = W:Card(panel)
    behavior:SetPoint("TOPLEFT", 16, -160)
    behavior:SetSize(568, 114)

    local behaviorTitle = W:Font(behavior, 9, C.accent, "OUTLINE")
    behaviorTitle:SetPoint("TOPLEFT", 14, -10)
    behaviorTitle:SetText(LJ.L("OPT_BEHAVIOR"))

    controls.lock = createCheck(behavior, "locked", LJ.L("OPT_LOCK"), LJ.L("OPT_LOCK_HINT"), -26)
    controls.welcome = createCheck(behavior, "showWelcome", LJ.L("OPT_WELCOME"), LJ.L("OPT_WELCOME_HINT"), -54)
    controls.records = createCheck(behavior, "announceRecords", LJ.L("OPT_RECORDS"), LJ.L("OPT_RECORDS_HINT"), -82)

    local layoutCard = W:Card(panel)
    layoutCard:SetPoint("TOPLEFT", 16, -282)
    layoutCard:SetSize(568, 68)
    local layoutTitle = W:Font(layoutCard, 9, C.accent, "OUTLINE")
    layoutTitle:SetPoint("TOPLEFT", 14, -8)
    layoutTitle:SetText(LJ.L("OPT_LAYOUT"))

    local dropdown = W:Button(layoutCard, "", 322, 24)
    dropdown:SetPoint("TOPLEFT", 14, -26)
    local arrow = W:Font(dropdown, 12, C.text, "")
    arrow:SetPoint("RIGHT", -10, 0)
    arrow:SetText("v")
    local menu = W:Card(panel)
    menu:SetPoint("TOPLEFT", dropdown, "BOTTOMLEFT", 0, -2)
    menu:SetSize(322, 56)
    menu:SetFrameLevel(layoutCard:GetFrameLevel() + 10)
    local classic = W:Button(menu, LJ.L("OPT_LAYOUT_CLASSIC"), 310, 24)
    classic:SetPoint("TOPLEFT", 6, -4)
    local journal = W:Button(menu, LJ.L("OPT_LAYOUT_JOURNAL"), 310, 24)
    journal:SetPoint("TOPLEFT", 6, -29)
    dropdown:SetScript("OnClick", function() menu:SetShown(not menu:IsShown()) end)
    classic:SetScript("OnClick", function()
        menu:Hide()
        LJ.UI:SetLayout("classic")
    end)
    journal:SetScript("OnClick", function()
        menu:Hide()
        LJ.UI:SetLayout("journal")
    end)
    menu:Hide()
    controls.layoutDropdown, controls.layoutMenu = dropdown, menu
    controls.layoutClassic, controls.layoutJournal = classic, journal
    local layoutHint = W:Font(layoutCard, 8, C.dim, "")
    layoutHint:SetPoint("TOPLEFT", 14, -52)
    layoutHint:SetWidth(530)
    layoutHint:SetText(LJ.L("OPT_LAYOUT_HINT"))

    local languageCard = W:Card(panel)
    languageCard:SetPoint("TOPLEFT", 16, -358)
    languageCard:SetSize(568, 68)
    local languageTitle = W:Font(languageCard, 9, C.accent, "OUTLINE")
    languageTitle:SetPoint("TOPLEFT", 14, -8)
    languageTitle:SetText(LJ.L("OPT_LANGUAGE"))

    local langDropdown = W:Button(languageCard, "", 322, 24)
    langDropdown:SetPoint("TOPLEFT", 14, -26)
    local langArrow = W:Font(langDropdown, 12, C.text, "")
    langArrow:SetPoint("RIGHT", -10, 0)
    langArrow:SetText("v")
    local langMenu = W:Card(panel)
    langMenu:SetPoint("BOTTOMLEFT", langDropdown, "TOPLEFT", 0, 2)
    langMenu:SetSize(322, 280)
    langMenu:SetFrameLevel(languageCard:GetFrameLevel() + 10)
    local langButtons = {}
    for i, loc in ipairs(LJ.LOCALES) do
        local b = W:Button(langMenu, loc.name, 310, 24)
        b:SetPoint("TOPLEFT", 6, -4 - (i - 1) * 25)
        b.code = loc.code
        b:SetScript("OnClick", function(self)
            langMenu:Hide()
            selectLanguage(self.code)
        end)
        langButtons[i] = b
    end
    langDropdown:SetScript("OnClick", function() langMenu:SetShown(not langMenu:IsShown()) end)
    langMenu:Hide()
    controls.langDropdown, controls.langMenu = langDropdown, langMenu
    controls.langButtons = langButtons
    local languageHint = W:Font(languageCard, 8, C.dim, "")
    languageHint:SetPoint("TOPLEFT", 14, -52)
    languageHint:SetWidth(530)
    languageHint:SetText(LJ.L("OPT_LANGUAGE_HINT"))

    local footer = W:Font(panel, 9, C.muted, "")
    footer:SetPoint("TOPLEFT", 18, -444)
    footer:SetWidth(560)
    footer:SetText(LJ.L("OPT_FOOTER"))
end

local function registerPanel()
    if registered or not panel then return false end
    local modern = false
    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        local ok, category = pcall(Settings.RegisterCanvasLayoutCategory, panel, panel.name)
        if ok and category then
            if category.ID == nil then category.ID = "LootJinx" end
            local registeredOK = pcall(Settings.RegisterAddOnCategory, category)
            if registeredOK then
                O.category = category
                modern = true
            end
        end
    end
    if not modern and InterfaceOptions_AddCategory then
        local ok = pcall(InterfaceOptions_AddCategory, panel)
        modern = ok and true or false
    end
    registered = modern
    return modern
end

function O:Create()
    if panel then return panel end
    if not LJ.DB then return nil end
    buildPanel()
    registerPanel()
    O:Refresh()
    return panel
end

function O:Refresh()
    if not panel or not LJ.DB then return end
    if controls.lock then setCheck(controls.lock, LJ.DB.locked) end
    if controls.welcome then setCheck(controls.welcome, LJ.DB.showWelcome) end
    if controls.records then setCheck(controls.records, LJ.DB.announceRecords) end
    if controls.compact then setCheck(controls.compact, LJ.DB.compact) end
    if controls.layoutDropdown then
        controls.layoutDropdown.label:SetText(LJ.L(LJ.DB.layoutPreview == "journal"
            and "OPT_LAYOUT_JOURNAL" or "OPT_LAYOUT_CLASSIC"))
    end
    if controls.langDropdown then
        controls.langDropdown.label:SetText(languageName(LJ.DB.language or "auto"))
    end
end

function O:Open()
    if inCombat() then
        -- Im Kampf geschützt: nicht aufrufen, sondern verständlich ablehnen.
        LJ:Print(LJ.L("OPTIONS_COMBAT_LOCKED"))
        return false
    end
    if not panel then self:Create() end
    if not panel then
        LJ:Print(LJ.L("OPTIONS_UNAVAILABLE"))
        return false
    end
    if not registered then registerPanel() end
    if Settings and Settings.OpenToCategory and O.category then
        local id = O.category.ID
        if not id and O.category.GetID then
            local ok, value = pcall(O.category.GetID, O.category)
            if ok then id = value end
        end
        if id then
            local ok = pcall(Settings.OpenToCategory, id)
            if ok then return true end
        end
    end
    if InterfaceOptionsFrame_OpenToCategory then
        pcall(InterfaceOptionsFrame_OpenToCategory, panel)
        pcall(InterfaceOptionsFrame_OpenToCategory, panel)
        return true
    end
    LJ:Print(LJ.L("OPTIONS_UNAVAILABLE"))
    return false
end
