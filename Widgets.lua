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
    local function restLabel(self)
        self.label:SetPoint("CENTER", 0, 0)
    end
    b:SetScript("OnEnter", function(self)
        if self.SetBackdropBorderColor then self:SetBackdropBorderColor(c4(C.accent)) end
        if self.SetBackdropColor then self:SetBackdropColor(0.16, 0.13, 0.20, 0.98) end
        self.label:SetTextColor(c4(C.text))
    end)
    b:SetScript("OnLeave", function(self)
        if self.SetBackdropBorderColor then self:SetBackdropBorderColor(c4(C.border)) end
        if self.SetBackdropColor then self:SetBackdropColor(0.10, 0.11, 0.14, 0.96) end
        self.label:SetTextColor(c4(C.muted))
        -- Wird die Maustaste außerhalb des Buttons losgelassen, feuert kein
        -- OnMouseUp. Das versetzte Label muss auch hier zurück.
        restLabel(self)
    end)
    b:SetScript("OnMouseDown", function(self) self.label:SetPoint("CENTER", 0, -1) end)
    b:SetScript("OnMouseUp", restLabel)
    b:SetScript("OnHide", restLabel)
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
    frame.__ljTooltip = { title = title, lines = lines }
    if frame.__ljTooltipInstalled then return end
    frame.__ljTooltipInstalled = true
    local prevEnter = frame:GetScript("OnEnter")
    local prevLeave = frame:GetScript("OnLeave")
    frame:SetScript("OnEnter", function(self, ...)
        if prevEnter then prevEnter(self, ...) end
        local data = self.__ljTooltip
        if not data or not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(data.title, c4(C.accent))
        for i = 1, #(data.lines or {}) do
            local line = data.lines[i]
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
    link:SetFont(FONT, 10, "")
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
        onEscape()
    end)
    link:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    link:SetScript("OnHide", function(self) self:ClearFocus() end)
    link.label = self:Font(parent, 10, C.muted)
    link.label:SetPoint("RIGHT", link, "LEFT", -4, 0)
    link.label:SetText(LJ.L("FOREVERDB_CREDIT"))
    self:Tooltip(link, "ForeverDB.net", { LJ.L("FOREVERDB_COPY") })
    return link
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
