-- LootJinx – Einstellungen (Interface > AddOns)
local ADDON, ns = ...
local LJ = ns or _G.LootJinx
if not LJ then return end

local O = {}
LJ.Options = O
local W = LJ.Widgets
local C = LJ.COLORS
local MEDIA = "Interface\\AddOns\\LootJinx\\Media\\"

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
    if key == "compact" or key == "showWatermark" then
        if LJ.UI and LJ.UI.ApplyDisplayOptions then LJ.UI:ApplyDisplayOptions() end
    end
end

local function createCheck(parent, key, labelText, hintText, y)
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
    hint:SetWidth(500)
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
    hit:SetSize(510, 30)
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
    panel:SetSize(600, 520)
    panel:SetScript("OnShow", function() O:Refresh() end)
    O.panel = panel

    local header = W:Card(panel)
    header:SetPoint("TOPLEFT", 16, -16)
    header:SetSize(568, 72)

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
    window:SetPoint("TOPLEFT", 16, -100)
    window:SetSize(568, 128)

    local windowTitle = W:Font(window, 9, C.accent, "OUTLINE")
    windowTitle:SetPoint("TOPLEFT", 14, -10)
    windowTitle:SetText(LJ.L("OPT_WINDOW"))

    local scaleLabel = W:Font(window, 10, C.text, "")
    scaleLabel:SetPoint("TOPLEFT", 14, -28)
    scaleLabel:SetText(LJ.L("OPT_SCALE"))

    local scaleValue = W:Font(window, 12, C.accent, "OUTLINE")
    scaleValue:SetPoint("TOPLEFT", 330, -40)

    local scale = CreateFrame("Slider", nil, window, "OptionsSliderTemplate")
    scale:SetPoint("TOPLEFT", 14, -48)
    scale:SetWidth(300)
    scale:SetMinMaxValues(0.80, 1.30)
    scale:SetValueStep(0.05)
    scale:SetObeyStepOnDrag(true)
    if scale.Text then scale.Text:SetText("") end
    if scale.Low then scale.Low:SetText("80 %") end
    if scale.High then scale.High:SetText("130 %") end
    scale:SetScript("OnValueChanged", function(self, value)
        if controls.updating then return end
        value = tonumber(value) or 1
        value = math.floor(value * 20 + 0.5) / 20
        if LJ.UI and LJ.UI.ApplyScale then
            LJ.UI:ApplyScale(value)
        elseif LJ.DB then
            LJ.DB.scale = value
        end
        if controls.scaleValue then
            controls.scaleValue:SetText(string.format("%d %%", math.floor(value * 100 + 0.5)))
        end
    end)
    controls.scale = scale
    controls.scaleValue = scaleValue

    local reset = W:Button(window, LJ.L("OPT_RESET_POS"), 150, 22)
    reset:SetPoint("TOPRIGHT", -14, -24)
    reset:SetScript("OnClick", function()
        if LJ.UI and LJ.UI.ResetPosition then LJ.UI:ResetPosition() end
    end)
    W:Tooltip(reset, LJ.L("OPT_RESET_POS"), { LJ.L("OPT_RESET_HINT") })

    local windowHint = W:Font(window, 8, C.dim, "")
    windowHint:SetPoint("TOPLEFT", 14, -88)
    windowHint:SetWidth(520)
    windowHint:SetText(LJ.L("OPT_SCALE_RANGE"))

    local behavior = W:Card(panel)
    behavior:SetPoint("TOPLEFT", 16, -240)
    behavior:SetSize(568, 112)

    local behaviorTitle = W:Font(behavior, 9, C.accent, "OUTLINE")
    behaviorTitle:SetPoint("TOPLEFT", 14, -10)
    behaviorTitle:SetText(LJ.L("OPT_BEHAVIOR"))

    controls.lock = createCheck(behavior, "locked", LJ.L("OPT_LOCK"), LJ.L("OPT_LOCK_HINT"), -30)
    controls.welcome = createCheck(behavior, "showWelcome", LJ.L("OPT_WELCOME"), LJ.L("OPT_WELCOME_HINT"), -66)

    local appearance = W:Card(panel)
    appearance:SetPoint("TOPLEFT", 16, -364)
    appearance:SetSize(568, 112)

    local appearanceTitle = W:Font(appearance, 9, C.accent, "OUTLINE")
    appearanceTitle:SetPoint("TOPLEFT", 14, -10)
    appearanceTitle:SetText(LJ.L("OPT_APPEARANCE"))

    controls.watermark = createCheck(appearance, "showWatermark", LJ.L("OPT_WATERMARK"), LJ.L("OPT_WATERMARK_HINT"), -30)
    controls.compact = createCheck(appearance, "compact", LJ.L("OPT_COMPACT"), LJ.L("OPT_COMPACT_HINT"), -66)

    local footer = W:Font(panel, 9, C.muted, "")
    footer:SetPoint("TOPLEFT", 18, -488)
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
    controls.updating = true
    if controls.scale then controls.scale:SetValue(LJ.DB.scale or 1) end
    controls.updating = false
    if controls.scaleValue then
        controls.scaleValue:SetText(string.format("%d %%", math.floor((LJ.DB.scale or 1) * 100 + 0.5)))
    end
    if controls.lock then setCheck(controls.lock, LJ.DB.locked) end
    if controls.welcome then setCheck(controls.welcome, LJ.DB.showWelcome) end
    if controls.watermark then setCheck(controls.watermark, LJ.DB.showWatermark ~= false) end
    if controls.compact then setCheck(controls.compact, LJ.DB.compact) end
end

function O:Open()
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
