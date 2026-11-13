-- LootJinx – wiederverwendbare UI-Bausteine
local ADDON, ns = ...
local LJ = ns or _G.LootJinx or {}
_G.LootJinx = LJ

local W = {}
LJ.Widgets = W

local C = LJ.COLORS
local WHITE = "Interface\\Buttons\\WHITE8X8"
local FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"

local function c4(c)
    return c[1], c[2], c[3], c[4] or 1
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

function W:Font(parent, size, color, flags)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(FONT, size or 10, flags or "")
    if color then fs:SetTextColor(c4(color)) else fs:SetTextColor(c4(C.text)) end
    fs:SetShadowColor(0, 0, 0, 0.85)
    fs:SetShadowOffset(0, 1)
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

function W:Bar(parent, height, gradientFrom, gradientTo)
    local bar = CreateFrame("Frame", nil, parent)
    bar:SetHeight(height or 6)
    bar:SetFrameLevel((parent:GetFrameLevel() or 1) + 2)

    bar.bg = bar:CreateTexture(nil, "BACKGROUND")
    bar.bg:SetAllPoints()
    self:ColorTexture(bar.bg, C.track)

    bar.fill = bar:CreateTexture(nil, "ARTWORK")
    bar.fill:SetAllPoints()
    self:SetGradient(bar.fill, true, gradientFrom or C.accent, gradientTo or C.cyan)
    bar.fill:SetTexCoord(0, 0, 0, 1)

    bar.value = 0
    function bar:SetValue(v)
        v = tonumber(v) or 0
        if v < 0 then v = 0 elseif v > 1 then v = 1 end
        self.value = v
        self.fill:SetTexCoord(0, v, 0, 1)
    end
    bar:SetValue(0)
    return bar
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
    b:SetScript("OnEnter", function(self)
        if self.SetBackdropBorderColor then self:SetBackdropBorderColor(c4(C.accent)) end
        if self.SetBackdropColor then self:SetBackdropColor(0.16, 0.13, 0.20, 0.98) end
        self.label:SetTextColor(c4(C.text))
    end)
    b:SetScript("OnLeave", function(self)
        if self.SetBackdropBorderColor then self:SetBackdropBorderColor(c4(C.border)) end
        if self.SetBackdropColor then self:SetBackdropColor(0.10, 0.11, 0.14, 0.96) end
        self.label:SetTextColor(c4(C.muted))
    end)
    b:SetScript("OnMouseDown", function(self) self.label:SetPoint("CENTER", 0, -1) end)
    b:SetScript("OnMouseUp", function(self) self.label:SetPoint("CENTER", 0, 0) end)
    return b
end

function W:Pill(parent, width, height)
    local p = CreateFrame("Frame", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    p:SetSize(width or 112, height or 22)
    if p.SetBackdrop then
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
    p.dot:SetPoint("LEFT", 10, 0)
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
        if self.SetBackdropBorderColor then
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
    local prevEnter = frame:GetScript("OnEnter")
    local prevLeave = frame:GetScript("OnLeave")
    frame:SetScript("OnEnter", function(self, ...)
        if prevEnter then prevEnter(self, ...) end
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(title, c4(C.accent))
        for i = 1, #(lines or {}) do
            local line = lines[i]
            if type(line) == "table" then
                GameTooltip:AddLine(line[1], line[2], line[3], line[4], true)
            else
                GameTooltip:AddLine(tostring(line), 0.86, 0.87, 0.90, true)
            end
        end
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function(self, ...)
        if prevLeave then prevLeave(self, ...) end
        if GameTooltip then GameTooltip:Hide() end
    end)
end

function W:Truncate(text, maxChars)
    text = tostring(text or "")
    maxChars = tonumber(maxChars) or 40
    if #text <= maxChars then return text end
    return text:sub(1, maxChars - 1) .. "…"
end

function W:FadeIn(frame, duration)
    if not frame then return end
    frame:SetAlpha(1)
    if UIFrameFadeIn then
        pcall(UIFrameFadeIn, frame, duration or 0.15, 0.05, 1)
    end
end

return W
