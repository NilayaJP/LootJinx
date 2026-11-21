-- LootJinx options and the launcher in the WoW AddOns settings.
local ADDON, ns = ...
local LJ = ns or _G.LootJinx
if not LJ then return end

local O = {}
LJ.Options = O
local W = LJ.Widgets
local MEDIA = "Interface\\AddOns\\LootJinx\\Media\\"

local function inCombat()
    return type(InCombatLockdown) == "function" and InCombatLockdown() == true
end

local panel
local launcher
local registered = false
local suspendedName
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
    if key == "hideChangelog" and LJ.Changelog then LJ.Changelog:RefreshPreference() end
end

local function languageName(code)
    for _, loc in ipairs(LJ.LOCALES or {}) do
        if loc.code == code then return loc.name end
    end
    return "Auto"
end

local function closeOptionsPanel()
    if panel and panel:IsShown() then panel:Hide() end
end

local function restoreEscape(deferred)
    local restored = suspendedName
    suspendedName = nil
    if not restored or not UISpecialFrames then return end
    local function restore()
        if suspendedName == restored or (LJ.History and LJ.History.suspendedName == restored) then return end
        local main = LJ.UI and LJ.UI.frame
        if panel:IsShown() and main and main:IsShown() and main:GetName() == restored then
            suspendedName = restored
            return
        end
        for _, name in ipairs(UISpecialFrames) do if name == restored then return end end
        table.insert(UISpecialFrames, restored)
    end
    if deferred and C_Timer and C_Timer.After then C_Timer.After(0, restore)
    else restore() end
end

local function syncEscape()
    if not UISpecialFrames or not panel:IsShown() then return end
    local main = LJ.UI and LJ.UI.frame
    local name = main and main:IsShown() and main:GetName()
    if suspendedName == name then return end
    restoreEscape()
    if name then
        for i, entry in ipairs(UISpecialFrames) do
            if entry == name then
                table.remove(UISpecialFrames, i)
                suspendedName = name
                break
            end
        end
    end
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

    StaticPopupDialogs["LOOTJINX_RELOAD"] = W:StylePopup({
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
    })
    StaticPopup_Show("LOOTJINX_RELOAD", nil, nil, code)
end

local themed = { panels = {}, text = {}, buttons = {}, checks = {} }

local function optionPanel(parent)
    local frame = W:Panel(parent)
    themed.panels[#themed.panels + 1] = frame
    return frame
end

local function optionText(parent, size, role)
    local field = W:Font(parent, size)
    themed.text[#themed.text + 1] = { field = field, size = size, role = role }
    return field
end

local function optionButton(parent, caption, width, height)
    local button = W:Button(parent, caption, width, height)
    themed.buttons[#themed.buttons + 1] = button
    return button
end

function O:ApplyTheme()
    if not panel then return end
    local skin = W:Skin()
    if self.skin == skin then return end
    self.skin = skin
    W:Paint(panel, skin.bg, skin.border)
    W:StyleAccent(self.accent, skin)
    for _, card in ipairs(themed.panels) do W:Paint(card, skin.surface, skin.border) end
    for _, entry in ipairs(themed.text) do
        local role, field = entry.role, entry.field
        W:ColorText(field, role == "section" and skin.accent or role == "muted" and skin.muted or skin.text)
        if role == "heading" or role == "section" then
            W:SetTextFont(field, entry.size, "", skin.displayFont)
        end
    end
    for _, button in ipairs(themed.buttons) do W:StyleButton(button, skin) end
    for _, check in ipairs(themed.checks) do W:StyleCheck(check, skin, check.check) end
    if launcher then
        W:ColorText(launcher.title, skin.text)
        W:SetTextFont(launcher.title, 22, "", skin.displayFont)
        W:ColorText(launcher.hint, skin.muted)
        W:StyleButton(launcher.open, skin)
    end
end
local function createCheck(parent, key, labelText, hintText, y, rowWidth)
    local check = CreateFrame("CheckButton", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    check:SetSize(18, 18)
    check:SetPoint("TOPLEFT", 14, y)
    check.check = check:CreateTexture(nil, "ARTWORK")
    check.check:SetSize(14, 14)
    check.check:SetPoint("CENTER", 0, 0)
    check.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    check.check:Hide()

    local label = optionText(parent, 10, "text")
    label:SetPoint("TOPLEFT", 40, y + 1)
    label:SetText(labelText)

    local hint = optionText(parent, 8, "muted")
    hint:SetPoint("TOPLEFT", 40, y - 14)
    hint:SetWidth(rowWidth or 500)
    hint:SetText(hintText)

    themed.checks[#themed.checks + 1] = check
    local function highlight(active)
        if not check.SetBackdropBorderColor then return end
        local skin = W:Skin()
        local color = active and skin.accent or skin.border
        check:SetBackdropBorderColor(color[1], color[2], color[3], 1)
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
    panel = CreateFrame("Frame", "LootJinxOptionsPanel", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    panel.name = LJ.L("OPTIONS_TAB")
    panel:SetSize(600, 524)
    panel:SetPoint("CENTER")
    panel:SetFrameStrata("DIALOG")
    panel:SetFrameLevel(175)
    panel:SetToplevel(true)
    panel:SetClampedToScreen(true)
    panel:EnableMouse(true)
    local stopDragging = W:DragHeader(panel, 76, 66)
    panel:SetScript("OnShow", function() O:Refresh() end)
    panel:SetScript("OnHide", function()
        stopDragging()
        if controls.layoutMenu then controls.layoutMenu:Hide() end
        if controls.langMenu then controls.langMenu:Hide() end
        restoreEscape(true)
    end)
    panel:Hide()
    if UISpecialFrames then table.insert(UISpecialFrames, panel:GetName()) end
    O.panel = panel
    O.accent = W:AccentLine(panel)

    local header = optionPanel(panel)
    header:SetPoint("TOPLEFT", 16, -16)
    header:SetSize(568, 64)

    local iconFrame = optionPanel(header)
    iconFrame:SetSize(38, 38)
    iconFrame:SetPoint("TOPLEFT", 14, -12)
    iconFrame:SetFrameLevel(header:GetFrameLevel() + 2)
    local icon = iconFrame:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 2, -2)
    icon:SetPoint("BOTTOMRIGHT", -2, 2)
    icon:SetTexture(MEDIA .. "LootJinxIcon")

    local title = optionText(header, 20, "heading")
    title:SetPoint("TOPLEFT", 64, -12)
    title:SetText(LJ.L("OPTIONS_TAB"))

    local subtitle = optionText(header, 10, "muted")
    subtitle:SetPoint("TOPLEFT", 65, -36)
    subtitle:SetText(LJ.L("OPTIONS_TITLE"))

    local version = optionText(header, 9, "muted")
    version:SetPoint("TOPRIGHT", -54, -18)
    version:SetText(versionText())
    local close = optionButton(header, "×", 26, 26)
    close:SetPoint("TOPRIGHT", -12, -12)
    W:SetTextFont(close.label, 15)
    close:SetScript("OnClick", closeOptionsPanel)
    W:Tooltip(close, LJ.L("CLOSE"))
    controls.close = close

    local window = optionPanel(panel)
    window:SetPoint("TOPLEFT", 16, -88)
    window:SetSize(568, 64)

    local windowTitle = optionText(window, 11, "section")
    windowTitle:SetPoint("TOPLEFT", 14, -10)
    windowTitle:SetText(LJ.L("OPT_WINDOW"))

    controls.compact = createCheck(window, "compact", LJ.L("OPT_COMPACT"), LJ.L("OPT_COMPACT_HINT"), -28, 354)

    local reset = optionButton(window, LJ.L("OPT_RESET_POS"), 150, 22)
    reset:SetPoint("TOPRIGHT", -14, -28)
    reset:SetScript("OnClick", function()
        if LJ.UI and LJ.UI.ResetPosition then LJ.UI:ResetPosition() end
    end)
    W:Tooltip(reset, LJ.L("OPT_RESET_POS"), { LJ.L("OPT_RESET_HINT") })

    local behavior = optionPanel(panel)
    behavior:SetPoint("TOPLEFT", 16, -160)
    behavior:SetSize(568, 114)

    local behaviorTitle = optionText(behavior, 11, "section")
    behaviorTitle:SetPoint("TOPLEFT", 14, -10)
    behaviorTitle:SetText(LJ.L("OPT_BEHAVIOR"))

    controls.lock = createCheck(behavior, "locked", LJ.L("OPT_LOCK"), LJ.L("OPT_LOCK_HINT"), -26)
    controls.welcome = createCheck(behavior, "showWelcome", LJ.L("OPT_WELCOME"), LJ.L("OPT_WELCOME_HINT"), -54)
    controls.records = createCheck(behavior, "announceRecords", LJ.L("OPT_RECORDS"), LJ.L("OPT_RECORDS_HINT"), -82)

    local layoutCard = optionPanel(panel)
    layoutCard:SetPoint("TOPLEFT", 16, -282)
    layoutCard:SetSize(568, 68)
    local layoutTitle = optionText(layoutCard, 11, "section")
    layoutTitle:SetPoint("TOPLEFT", 14, -8)
    layoutTitle:SetText(LJ.L("OPT_LAYOUT"))

    local dropdown = optionButton(layoutCard, "", 322, 24)
    dropdown:SetPoint("TOPLEFT", 14, -26)
    local arrow = optionText(dropdown, 12, "text")
    arrow:SetPoint("RIGHT", -10, 0)
    arrow:SetText("v")
    local menu = optionPanel(panel)
    menu:SetPoint("TOPLEFT", dropdown, "BOTTOMLEFT", 0, -2)
    menu:SetSize(322, 56)
    menu:SetFrameLevel(layoutCard:GetFrameLevel() + 10)
    local classic = optionButton(menu, LJ.L("OPT_LAYOUT_CLASSIC"), 310, 24)
    classic:SetPoint("TOPLEFT", 6, -4)
    local journal = optionButton(menu, LJ.L("OPT_LAYOUT_JOURNAL"), 310, 24)
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
    local layoutHint = optionText(layoutCard, 8, "muted")
    layoutHint:SetPoint("TOPLEFT", 14, -52)
    layoutHint:SetWidth(530)
    layoutHint:SetText(LJ.L("OPT_LAYOUT_HINT"))

    local languageCard = optionPanel(panel)
    languageCard:SetPoint("TOPLEFT", 16, -358)
    languageCard:SetSize(568, 68)
    local languageTitle = optionText(languageCard, 11, "section")
    languageTitle:SetPoint("TOPLEFT", 14, -8)
    languageTitle:SetText(LJ.L("OPT_LANGUAGE"))

    local langDropdown = optionButton(languageCard, "", 322, 24)
    langDropdown:SetPoint("TOPLEFT", 14, -26)
    local langArrow = optionText(langDropdown, 12, "text")
    langArrow:SetPoint("RIGHT", -10, 0)
    langArrow:SetText("v")
    local langMenu = optionPanel(panel)
    langMenu:SetPoint("BOTTOMLEFT", langDropdown, "TOPLEFT", 0, 2)
    langMenu:SetSize(322, 280)
    langMenu:SetFrameLevel(languageCard:GetFrameLevel() + 10)
    local langButtons = {}
    for i, loc in ipairs(LJ.LOCALES) do
        local b = optionButton(langMenu, loc.name, 310, 24)
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
    local languageHint = optionText(languageCard, 8, "muted")
    languageHint:SetPoint("TOPLEFT", 14, -52)
    languageHint:SetWidth(530)
    languageHint:SetText(LJ.L("OPT_LANGUAGE_HINT"))

    local changelogCard = optionPanel(panel)
    changelogCard:SetPoint("TOPLEFT", 16, -434)
    changelogCard:SetSize(568, 68)
    local changelogTitle = optionText(changelogCard, 11, "section")
    changelogTitle:SetPoint("TOPLEFT", 14, -10)
    changelogTitle:SetText(LJ.L("CHANGELOG_TITLE"))
    controls.hideChangelog = createCheck(changelogCard, "hideChangelog",
        LJ.L("CHANGELOG_OPT_OUT"), "", -28, 316)
    controls.changelogButton = optionButton(changelogCard, LJ.L("CHANGELOG_OPEN"), 180, 22)
    controls.changelogButton:SetPoint("TOPRIGHT", -14, -28)
    controls.changelogButton:SetScript("OnClick", function()
        if LJ.Changelog then
            closeOptionsPanel()
            LJ.Changelog:Show()
        end
    end)

    local footer = optionText(panel, 9, "muted")
    footer:SetPoint("TOPLEFT", 18, -508)
    footer:SetWidth(560)
    footer:SetText(LJ.L("OPT_FOOTER"))
end

local function registerPanel()
    if registered or not panel or inCombat() then return false end
    if not launcher then
        launcher = CreateFrame("Frame")
        launcher.name = panel.name
        local logo = launcher:CreateTexture(nil, "ARTWORK")
        logo:SetPoint("TOPLEFT", 20, -24)
        logo:SetSize(40, 40)
        logo:SetTexture(MEDIA .. "LootJinxIcon")
        launcher.title = W:Font(launcher, 22)
        launcher.title:SetPoint("TOPLEFT", 72, -26)
        launcher.title:SetText(LJ.L("OPTIONS_TAB"))
        launcher.hint = W:Font(launcher, 11)
        launcher.hint:SetPoint("TOPLEFT", 73, -51)
        launcher.hint:SetText(LJ.L("OPT_LAUNCHER_HINT"))
        launcher.open = W:Button(launcher, LJ.L("OPT_LAUNCHER_OPEN"), 200, 26)
        launcher.open:SetPoint("TOPLEFT", 72, -77)
        launcher.open:SetScript("OnClick", function() O:Open() end)
        launcher:Hide()
        O.launcher = launcher
        O.skin = nil
    end
    local modern = false
    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        local ok, category = pcall(Settings.RegisterCanvasLayoutCategory, launcher, launcher.name)
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
        local ok = pcall(InterfaceOptions_AddCategory, launcher)
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
    syncEscape()
    self:ApplyTheme()
    if controls.lock then setCheck(controls.lock, LJ.DB.locked) end
    if controls.welcome then setCheck(controls.welcome, LJ.DB.showWelcome) end
    if controls.hideChangelog then setCheck(controls.hideChangelog, LJ.DB.hideChangelog) end
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
    if not panel then self:Create() end
    if not panel then
        LJ:Print(LJ.L("OPTIONS_UNAVAILABLE"))
        return false
    end
    if not registered and not inCombat() then registerPanel() end
    if not panel:IsShown() then
        local main = LJ.UI and LJ.UI.frame
        if not self.positioned and main and main:IsShown() then
            panel:ClearAllPoints()
            panel:SetPoint("CENTER", main, "CENTER", 0, 0)
        end
        self.positioned = true
        panel:Show()
    end
    self:Refresh()
    return true
end
