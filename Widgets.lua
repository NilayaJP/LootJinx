-- LootJinx – wiederverwendbare UI-Bausteine
local ADDON, ns = ...
local LJ = ns or _G.LootJinx or {}
_G.LootJinx = LJ

local W = {}
LJ.Widgets = W

local C = LJ.COLORS or {}
local WHITE = "Interface\\Buttons\\WHITE8X8"
local THEME_MEDIA = "Interface\\AddOns\\LootJinx\\Media\\Themes\\"
local FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
W.skins = {
    classic = {
        art = "Classic",
        header = { .072, .086, .126, 1 }, artworkAlpha = .24, edgeHeight = 1,
        bg = { .057, .064, .087, .98 }, surface = { .084, .098, .13, .98 },
        border = { .192, .214, .27, 1 }, hover = { .133, .141, .207, 1 },
        text = C.text, muted = C.muted, accent = { .72, .59, .95, 1 },
        progress = { .43, .82, .93, 1 }, track = { .153, .169, .223, 1 },
    },
    journal = {
        art = "Journal",
        header = { .205, .147, .105, 1 }, artworkAlpha = .35, edgeHeight = 2,
        bg = { .137, .100, .081, .98 }, surface = { .180, .134, .102, .98 },
        border = { .340, .255, .181, 1 }, hover = { .248, .183, .126, 1 },
        text = { .950, .900, .815, 1 }, muted = { .82, .75, .66, 1 },
        accent = { .90, .74, .49, 1 }, progress = { .80, .61, .35, 1 },
        track = { .255, .184, .126, 1 }, displayFont = "Fonts\\MORPHEUS.TTF",
    },
    goblin = {
        art = "Goblin",
        header = { .151, .118, .073, 1 }, artworkAlpha = .42, edgeHeight = 2,
        bg = { .074, .093, .068, .98 }, surface = { .108, .153, .108, .98 },
        border = { .32, .28, .17, 1 }, hover = { .174, .227, .147, 1 },
        text = { .97, .93, .81, 1 }, muted = { .77, .80, .69, 1 },
        accent = { .99, .73, .44, 1 }, progress = { .64, .91, .60, 1 },
        track = { .22, .31, .20, 1 },
    },
    dwarven = {
        art = "Dwarven",
        header = { .175, .170, .174, 1 }, artworkAlpha = .33, edgeHeight = 3,
        bg = { .080, .082, .092, .98 }, surface = { .137, .141, .156, .98 },
        border = { .36, .34, .33, 1 }, hover = { .222, .208, .199, 1 },
        text = { .96, .94, .91, 1 }, muted = { .82, .79, .75, 1 },
        accent = { 1, .75, .52, 1 }, progress = { 1, .61, .40, 1 },
        track = { .29, .22, .20, 1 }, displayFont = "Fonts\\MORPHEUS.TTF",
    },
    oracle = {
        art = "Oracle",
        header = { .134, .100, .230, 1 }, artworkAlpha = .34, edgeHeight = 1,
        bg = { .073, .062, .118, .98 }, surface = { .117, .095, .185, .98 },
        border = { .29, .24, .43, 1 }, hover = { .205, .153, .32, 1 },
        text = { .96, .93, 1, 1 }, muted = { .81, .76, .91, 1 },
        accent = { .88, .73, 1, 1 }, progress = { .76, .73, 1, 1 },
        track = { .23, .18, .34, 1 }, displayFont = "Fonts\\MORPHEUS.TTF",
    },
}

function W:Skin(layout)
    return self.skins[layout or (LJ.DB and LJ.DB.layoutPreview)] or self.skins.classic
end

function W:SetThemeArt(texture, skin, variant)
    texture:SetTexture(THEME_MEDIA .. skin.art .. variant .. ".tga")
end

function W:ThemeBanner(parent)
    local art = parent:CreateTexture(nil, "BACKGROUND", nil, 1)
    art:SetPoint("TOPLEFT", 1, -1)
    art:SetPoint("BOTTOMRIGHT", -1, 1)
    art:SetAlpha(.48)
    return art
end

-- The selected addon language can use a different script from the client.
local SCRIPT_FONTS = {
    ko = "Fonts\\2002.TTF",
    zhCN = "Fonts\\ARKai_T.ttf",
    zhTW = "Fonts\\bLEI00D.ttf",
    ru = "Fonts\\FRIZQT___CYR.TTF",
}

local function c4(c)
    return c[1], c[2], c[3], c[4] or 1
end

function W:Paint(frame, color, edge)
    if not frame or not frame.SetBackdrop then return end
    frame:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 } })
    frame:SetBackdropColor(c4(color))
    frame:SetBackdropBorderColor(c4(edge))
end

function W:ColorText(region, color)
    region:SetTextColor(c4(color))
end

function W:ColorTexture(tex, c)
    if not tex then return end
    tex:SetColorTexture(c4(c))
end

function W:SetGradient(tex, horizontal, c1, c2)
    if not tex then return end
    tex:SetTexture(WHITE)
    if tex.SetGradient and CreateColor then
        local ok = pcall(tex.SetGradient, tex,
            horizontal and "HORIZONTAL" or "VERTICAL",
            CreateColor(c1[1], c1[2], c1[3], c1[4] or 1),
            CreateColor(c2[1], c2[2], c2[3], c2[4] or 1))
        if ok then return end
    end
    tex:SetColorTexture(c4(c1))
end

function W:AccentLine(parent)
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetPoint("TOPLEFT", 1, -1)
    line:SetPoint("TOPRIGHT", -1, -1)
    line:SetHeight(2)
    return line
end

function W:StyleAccent(line, skin)
    if skin.displayFont then
        self:ColorTexture(line, skin.progress)
    else
        self:SetGradient(line, true, skin.accent, skin.progress)
    end
end

function W:StyleWindow(frame, skin, height, iconSize, subtleArt)
    local chrome = frame.ljChrome
    if not chrome then
        local header = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
        header:SetPoint("TOPLEFT", 1, -1)
        header:SetPoint("TOPRIGHT", -1, -1)
        header:SetHeight(height)
        local art = frame:CreateTexture(nil, "BACKGROUND", nil, 2)
        art:SetAllPoints(header)
        art:SetTexCoord(0, 1, .08, subtleArt and .55 or .92)
        local rule = frame:CreateTexture(nil, "BACKGROUND", nil, 3)
        rule:SetPoint("TOPLEFT", header, "BOTTOMLEFT")
        rule:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT")
        rule:SetHeight(1)
        local icon = frame:CreateTexture(nil, "ARTWORK")
        icon:SetSize(iconSize, iconSize)
        icon:SetPoint("TOPLEFT", 16, -math.floor((height - iconSize) / 2))
        chrome = { header = header, art = art, rule = rule, icon = icon, accent = self:AccentLine(frame) }
        frame.ljChrome = chrome
    end
    if chrome.skin == skin then return end
    chrome.skin = skin
    self:Paint(frame, { skin.bg[1], skin.bg[2], skin.bg[3], 1 }, skin.border)
    self:ColorTexture(chrome.header, skin.header)
    self:ColorTexture(chrome.rule, skin.border)
    self:SetThemeArt(chrome.art, skin, "Banner")
    chrome.art:SetAlpha(subtleArt and skin.artworkAlpha * .55 or skin.artworkAlpha)
    self:SetThemeArt(chrome.icon, skin, "Icon")
    chrome.accent:SetHeight(skin.edgeHeight)
    self:StyleAccent(chrome.accent, skin)
end

function W:WindowClose(button)
    button:SetSize(24, 24)
    button:SetPoint("TOPRIGHT", -14, -12)
    self:SetTextFont(button.label, 15)
end

local function inputBorder(control)
    local skin = control.ljInputSkin
    local border = control.ljInputFocused and skin.accent or skin.border
    if control.SetBackdropBorderColor then control:SetBackdropBorderColor(c4(border)) end
end

function W:StyleInput(control, skin)
    if not control.ljInputSkin and control.HookScript then
        control:HookScript("OnEditFocusGained", function(self)
            self.ljInputFocused = true
            inputBorder(self)
        end)
        control:HookScript("OnEditFocusLost", function(self)
            self.ljInputFocused = nil
            inputBorder(self)
        end)
    end
    control.ljInputSkin = skin
    self:Paint(control, skin.surface, skin.border)
    self:ColorText(control, skin.text)
    inputBorder(control)
end

function W:StyleListRow(row, skin, alternate)
    if not row.ljListFill then
        row.ljListFill = row:CreateTexture(nil, "BACKGROUND", nil, -4)
        row.ljListFill:SetAllPoints()
    end
    self:ColorTexture(row.ljListFill, alternate and skin.surface or skin.bg)
end

function W:CreateFoldIndicator(row, inset)
    row.foldHorizontal = row:CreateTexture(nil, "ARTWORK")
    row.foldHorizontal:SetPoint("LEFT", inset, 0)
    row.foldHorizontal:SetSize(7, 1)
    row.foldHorizontal:Hide()
    row.foldVertical = row:CreateTexture(nil, "ARTWORK")
    row.foldVertical:SetPoint("CENTER", row.foldHorizontal, "CENTER")
    row.foldVertical:SetSize(1, 7)
    row.foldVertical:Hide()
end

function W:SetFoldIndicator(row, color, expanded)
    if color then
        self:ColorTexture(row.foldHorizontal, color)
        self:ColorTexture(row.foldVertical, color)
    end
    row.foldHorizontal:SetShown(color ~= nil)
    row.foldVertical:SetShown(color ~= nil and not expanded)
end

local popupLayers = setmetatable({}, { __mode = "k" })

function W:StylePopup(definition)
    local show, hide = definition.OnShow, definition.OnHide
    definition.OnShow = function(dialog, ...)
        local parent = dialog.BG
        if parent and parent.CreateTexture then
            local layers = popupLayers[dialog]
            if not layers then
                local fill = parent:CreateTexture(nil, "BACKGROUND", nil, -3)
                fill:SetPoint("TOPLEFT", 4, -4)
                fill:SetPoint("BOTTOMRIGHT", -4, 4)
                local line = parent:CreateTexture(nil, "BACKGROUND", nil, -2)
                line:SetPoint("TOPLEFT", 4, -4)
                line:SetPoint("TOPRIGHT", -4, -4)
                line:SetHeight(2)
                local art = parent:CreateTexture(nil, "BACKGROUND", nil, -2)
                art:SetPoint("TOPLEFT", 4, -6)
                art:SetPoint("TOPRIGHT", -4, -6)
                art:SetHeight(36)
                layers = { fill = fill, line = line, art = art }
                popupLayers[dialog] = layers
            end
            local skin = W:Skin()
            W:ColorTexture(layers.fill, skin.bg)
            W:StyleAccent(layers.line, skin)
            W:SetThemeArt(layers.art, skin, "Banner")
            layers.art:SetAlpha(skin.artworkAlpha * .7)
            layers.fill:Show()
            layers.line:Show()
            layers.art:Show()
        end
        if show then show(dialog, ...) end
    end
    definition.OnHide = function(dialog, ...)
        local layers = popupLayers[dialog]
        if layers then
            layers.fill:Hide()
            layers.line:Hide()
            layers.art:Hide()
        end
        if hide then hide(dialog, ...) end
    end
    return definition
end

local function tryFont(region, path, size, flags)
    local ok, applied = pcall(region.SetFont, region, path, size, flags)
    return ok and applied ~= false
end

function W:SetTextFont(region, size, flags, defaultFont)
    size, flags = size or 10, flags or ""
    local scriptFont = SCRIPT_FONTS[LJ.lang]
    if scriptFont and tryFont(region, scriptFont, size, flags) then return end
    -- A caller that already set a native font object can keep it as the fallback.
    if defaultFont == false then return end
    if defaultFont and defaultFont ~= FONT and tryFont(region, defaultFont, size, flags) then return end
    region:SetFont(FONT, size, flags)
end

function W:Font(parent, size, color, flags, defaultFont)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    self:SetTextFont(fs, size, flags, defaultFont)
    if color then fs:SetTextColor(c4(color)) else fs:SetTextColor(c4(C.text)) end
    fs:SetShadowColor(0, 0, 0, 1.0)
    fs:SetShadowOffset(1, -1)
    fs:SetJustifyH("LEFT")
    fs:SetJustifyV("MIDDLE")
    return fs
end

function W:Panel(parent, layer)
    local f = CreateFrame("Frame", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    if f.SetBackdrop then
        f:SetBackdrop({
            bgFile = WHITE,
            edgeFile = WHITE,
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        f:SetBackdropColor(c4(C.card))
        f:SetBackdropBorderColor(c4(C.border))
    else
        local bg = f:CreateTexture(nil, layer or "BACKGROUND")
        bg:SetAllPoints()
        self:ColorTexture(bg, C.card)
    end
    return f
end

function W:Card(parent)
    local card = self:Panel(parent, "BACKGROUND")

    local sheen = card:CreateTexture(nil, "BORDER")
    sheen:SetPoint("TOPLEFT", 1, -1)
    sheen:SetPoint("TOPRIGHT", -1, -1)
    sheen:SetHeight(48)
    self:SetGradient(sheen, false, { 1, 1, 1, 0.035 }, { 1, 1, 1, 0 })
    sheen:SetAlpha(1)

    local accent = card:CreateTexture(nil, "ARTWORK")
    accent:SetPoint("TOPLEFT", 14, -1)
    accent:SetSize(34, 2)
    self:SetGradient(accent, true, C.accent, C.cyan)
    card.accent = accent

    return card
end

function W:Bar(parent, width, height, gradientFrom, gradientTo)
    local bar = CreateFrame("Frame", nil, parent)
    bar:SetSize(width, height)
    bar:SetFrameLevel((parent:GetFrameLevel() or 1) + 2)

    bar.bg = bar:CreateTexture(nil, "BACKGROUND")
    bar.bg:SetAllPoints()
    self:ColorTexture(bar.bg, C.track)

    bar.fill = bar:CreateTexture(nil, "ARTWORK")
    bar.fill:SetPoint("TOPLEFT")
    bar.fill:SetPoint("BOTTOMLEFT")
    self:SetGradient(bar.fill, true, gradientFrom or C.accent, gradientTo or C.cyan)

    function bar:SetValue(v)
        v = tonumber(v) or 0
        if v < 0 then v = 0 elseif v > 1 then v = 1 end
        self.value = v
        self.fill:SetShown(v > 0)
        if v > 0 then self.fill:SetWidth(width * v) end
    end
    bar:SetValue(0)
    return bar
end

local defaultButtonFill, defaultButtonHover = { .10, .11, .14, .96 }, { .16, .13, .20, .98 }
local function buttonColors(button, hovering)
    local skin = button.ljSkin
    local fill = skin and (hovering and skin.hover or skin.surface)
        or (hovering and defaultButtonHover or defaultButtonFill)
    local edge = (hovering or button.ljSelected) and (skin and skin.accent or C.accent)
        or (skin and skin.border or C.border)
    if button.SetBackdropColor then button:SetBackdropColor(c4(fill)) end
    if button.SetBackdropBorderColor then button:SetBackdropBorderColor(c4(edge)) end
    W:ColorText(button.label, skin and (button.ljSelected and skin.accent or skin.text)
        or (hovering and C.text or C.muted))
end

function W:StyleButton(button, skin, selected)
    button.ljSkin = skin
    button.ljSelected = selected
    buttonColors(button, false)
end

function W:StyleCheck(control, skin, mark)
    self:Paint(control, skin.bg, skin.border)
    if mark and mark.SetVertexColor then mark:SetVertexColor(c4(skin.progress)) end
end

function W:Button(parent, text, width, height)
    local b = CreateFrame("Button", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    b:SetSize(width or 64, height or 20)
    if b.SetBackdrop then
        b:SetBackdrop({
            bgFile = WHITE,
            edgeFile = WHITE,
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        b:SetBackdropColor(0.10, 0.11, 0.14, 0.96)
        b:SetBackdropBorderColor(c4(C.border))
    end
    b.label = self:Font(b, 10, C.muted, "")
    b.label:SetPoint("CENTER", 0, 0)
    b.label:SetText(text or "")
    local function restLabel(self)
        self.label:SetPoint("CENTER", 0, 0)
    end
    b:SetScript("OnEnter", function(self) buttonColors(self, true) end)
    b:SetScript("OnLeave", function(self)
        buttonColors(self, false)
        -- Wird die Maustaste außerhalb des Buttons losgelassen, feuert kein
        -- OnMouseUp. Das versetzte Label muss auch hier zurück.
        restLabel(self)
    end)
    b:SetScript("OnMouseDown", function(self) self.label:SetPoint("CENTER", 0, -1) end)
    b:SetScript("OnMouseUp", restLabel)
    b:SetScript("OnHide", restLabel)
    return b
end

function W:Pill(parent, width, height, flat)
    local p = CreateFrame("Frame", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    p:SetSize(width or 112, height or 22)
    if not flat and p.SetBackdrop then
        p:SetBackdrop({
            bgFile = WHITE,
            edgeFile = WHITE,
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        p:SetBackdropColor(0.07, 0.09, 0.11, 0.96)
        p:SetBackdropBorderColor(0.20, 0.28, 0.24, 1)
    end
    p.dot = p:CreateTexture(nil, "ARTWORK")
    p.dot:SetSize(6, 6)
    p.dot:SetPoint("LEFT", flat and 1 or 10, 0)
    p.dot:SetColorTexture(c4(C.green))
    p.label = self:Font(p, 9, C.green, "OUTLINE")
    p.label:SetPoint("LEFT", p.dot, "RIGHT", 6, 0)
    p.label:SetPoint("RIGHT", -8, 0)
    p.label:SetWordWrap(false)
    p.label:SetJustifyH("LEFT")

    function p:SetState(text, color, dotColor)
        self.label:SetText(text or "")
        self.label:SetTextColor(c4(color or C.green))
        self.dot:SetColorTexture(c4(dotColor or color or C.green))
        if not flat and self.SetBackdropBorderColor then
            self:SetBackdropBorderColor(dotColor and dotColor[1] * 0.55 or 0.2,
                dotColor and dotColor[2] * 0.55 or 0.28,
                dotColor and dotColor[3] * 0.55 or 0.24, 1)
        end
    end
    return p
end

function W:Divider(parent, vertical)
    local d = parent:CreateTexture(nil, "ARTWORK")
    d:SetColorTexture(0.22, 0.23, 0.29, 0.8)
    if vertical then
        d:SetWidth(1)
    else
        d:SetHeight(1)
    end
    return d
end

function W:Tooltip(frame, title, lines)
    if not frame then return end
    frame:EnableMouse(true)
    frame.__ljTooltip = { title = title, lines = lines }
    if frame.__ljTooltipInstalled then return end
    frame.__ljTooltipInstalled = true
    local prevEnter = frame:GetScript("OnEnter")
    local prevLeave = frame:GetScript("OnLeave")
    frame:SetScript("OnEnter", function(self, ...)
        if prevEnter then prevEnter(self, ...) end
        local data = self.__ljTooltip
        if not data or not GameTooltip then return end
        local skin = self.ljSkin or W:Skin()
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(data.title, skin.accent[1], skin.accent[2], skin.accent[3])
        for i = 1, #(data.lines or {}) do
            local line = data.lines[i]
            if type(line) == "table" then
                GameTooltip:AddLine(line[1], line[2], line[3], line[4], true)
            else
                GameTooltip:AddLine(tostring(line), skin.text[1], skin.text[2], skin.text[3], true)
            end
        end
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function(self, ...)
        if prevLeave then prevLeave(self, ...) end
        if not GameTooltip then return end
        local owned = true
        if type(GameTooltip.IsOwned) == "function" then
            local ok, result = pcall(GameTooltip.IsOwned, GameTooltip, self)
            owned = ok and result == true
        end
        if owned then GameTooltip:Hide() end
    end)
end

function W:ForeverDBCredit(parent, onEscape)
    local url = "https://foreverdb.net"
    local link = CreateFrame("EditBox", nil, parent)
    link:SetSize(120, 16)
    link:SetAutoFocus(false)
    self:SetTextFont(link, 10)
    link:SetText(url)
    link:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    link:SetScript("OnTextChanged", function(self)
        if self:GetText() ~= url then
            self:SetText(url)
            self:HighlightText()
        end
    end)
    link:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        if onEscape then onEscape() end
    end)
    link:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    link:SetScript("OnHide", function(self) self:ClearFocus() end)
    link.label = self:Font(parent, 10, C.muted)
    link.label:SetPoint("RIGHT", link, "LEFT", -4, 0)
    link.label:SetText(LJ.L("FOREVERDB_CREDIT"))
    self:Tooltip(link, "ForeverDB.net", { LJ.L("FOREVERDB_COPY") })
    return link
end

function W:StyleCredit(link, skin)
    self:ColorText(link, skin.accent)
    self:ColorText(link.label, skin.muted)
end

function W:AddDashboardCredit(frame, linkColor)
    local link = self:ForeverDBCredit(frame)
    link.label:ClearAllPoints()
    link.label:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 16, 5)
    link:SetPoint("LEFT", link.label, "RIGHT", 4, 0)
    link:SetTextColor(c4(linkColor))
    frame.creditLink = link
end

function W:Truncate(text, maxChars)
    text = tostring(text or "")
    maxChars = math.floor(tonumber(maxChars) or 40)
    if maxChars < 1 then return "" end
    if #text <= maxChars then return text end

    local count, ellipsisAt = 0, nil
    -- UTF-8 continuation bytes do not start a new character.
    for byteIndex in text:gmatch("()[^\128-\191]") do
        count = count + 1
        if count == maxChars then ellipsisAt = byteIndex end
        if count > maxChars then return text:sub(1, ellipsisAt - 1) .. "…" end
    end
    return text
end

function W:FadeIn(frame, duration)
    if not frame then return end
    frame:SetAlpha(1)
    if UIFrameFadeIn then
        pcall(UIFrameFadeIn, frame, duration or 0.15, 0.05, 1)
    end
end

function W:DragHeader(window, height, rightInset)
    window:SetMovable(true)
    local handle = CreateFrame("Frame", nil, window)
    handle:SetPoint("TOPLEFT", window, "TOPLEFT", 8, 0)
    handle:SetSize(window:GetWidth() - 8 - rightInset, height)
    handle:SetFrameLevel(window:GetFrameLevel() + 1)
    handle:EnableMouse(true)
    handle:RegisterForDrag("LeftButton")

    local moving = false
    handle:SetScript("OnDragStart", function()
        window:StartMoving()
        moving = true
    end)
    local function stopMoving()
        if moving then
            window:StopMovingOrSizing()
            moving = false
        end
    end
    handle:SetScript("OnDragStop", stopMoving)
    return stopMoving
end

function W:ResizeGrip(parent, onScaleChanged, onReset)
    if not parent then return nil end
    local grip = CreateFrame("Button", nil, parent)
    grip:SetSize(16, 16)
    grip:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -2, 2)
    grip:SetFrameLevel((parent:GetFrameLevel() or 1) + 60)
    if grip.SetNormalTexture then
        grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    end
    if grip.SetHighlightTexture then
        grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight", "ADD")
    end
    if grip.SetPushedTexture then
        grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    end
    if grip.RegisterForClicks then
        grip:RegisterForClicks("AnyUp")
    end

    grip:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" then return end

        local left = parent.GetLeft and parent:GetLeft()
        local top = parent.GetTop and parent:GetTop()
        if left and top then
            parent:ClearAllPoints()
            parent:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
            self.pinLeft = left
            self.pinTop = top
        end

        local uScale = (UIParent and UIParent:GetEffectiveScale()) or 1
        local baseW = parent:GetWidth() or 640
        local baseH = parent:GetHeight() or 510
        if baseW <= 0 then baseW = 640 end
        if baseH <= 0 then baseH = 510 end
        self.baseW = baseW
        self.baseH = baseH

        local x, y = GetCursorPosition()
        self.startX = x
        self.startY = y
        self.startScale = parent:GetScale() or 1
        self.dragging = true
    end)

    grip:SetScript("OnUpdate", function(self)
        if not self.dragging then return end
        if IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then
            self.dragging = false
            local finalScale = parent:GetScale() or 1
            if onScaleChanged then onScaleChanged(finalScale) end
            return
        end
        local x, y = GetCursorPosition()
        local uScale = (UIParent and UIParent:GetEffectiveScale()) or 1
        local dx = (x - self.startX) / uScale
        local dy = (self.startY - y) / uScale
        local relX = dx / (self.baseW or 640)
        local relY = dy / (self.baseH or 510)
        local deltaRel = (relX + relY) * 0.5
        local scale = self.startScale + deltaRel
        if scale < 0.40 then scale = 0.40 end
        if scale > 3.00 then scale = 3.00 end
        parent:SetScale(scale)
        -- Do NOT call onScaleChanged here; applyPosition() must only run once at drag end.
    end)

    grip:SetScript("OnMouseUp", function(self, button)
        if button == "RightButton" then
            if onReset then
                onReset()
            elseif onScaleChanged then
                onScaleChanged(1.0)
            end
            return
        end
        if self.dragging then
            self.dragging = false
            local finalScale = parent:GetScale() or 1
            if onScaleChanged then onScaleChanged(finalScale) end
        end
    end)

    grip:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
        GameTooltip:SetText(LJ.L("RESIZE_GRIP_TITLE"), c4(C.accent))
        GameTooltip:AddLine(LJ.L("RESIZE_GRIP_TIP"), 1, 1, 1, true)
        GameTooltip:Show()
    end)
    grip:SetScript("OnLeave", function(self)
        if not GameTooltip then return end
        GameTooltip:Hide()
    end)

    return grip
end

return W
