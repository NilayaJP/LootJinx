-- LootJinx – Minimap-Button
local ADDON, ns = ...
local LJ = ns or _G.LootJinx
if not LJ then return end

local M = {}
LJ.Minimap = M

local MEDIA = "Interface\\AddOns\\LootJinx\\Media\\"
local DEFAULT_ANGLE = 225
local RADIUS_PADDING = 5
local C = LJ.COLORS

local button

-- Lua 5.1 hat math.atan2, Lua 5.4 nicht mehr. Der Fallback hält Tests und
-- den Addon-Code auf beiden Varianten lauffähig.
local atan2 = math.atan2
if not atan2 then
    atan2 = function(y, x)
        if x > 0 then return math.atan(y / x) end
        if x < 0 then
            if y >= 0 then return math.atan(y / x) + math.pi end
            return math.atan(y / x) - math.pi
        end
        if y > 0 then return math.pi / 2 end
        if y < 0 then return -math.pi / 2 end
        return 0
    end
end

local function normalizeAngle(value)
    value = tonumber(value)
    if not value or value ~= value then return DEFAULT_ANGLE end
    value = value % 360
    if value < 0 then value = value + 360 end
    return value
end

local function applyPosition(angle)
    if not button or not Minimap then return end
    angle = math.rad(normalizeAngle(angle or (LJ.DB and LJ.DB.minimapAngle)))
    local width = Minimap.GetWidth and Minimap:GetWidth() or 140
    local height = Minimap.GetHeight and Minimap:GetHeight() or 140
    if not width or width <= 0 then width = 140 end
    if not height or height <= 0 then height = 140 end
    local radiusX = width / 2 + RADIUS_PADDING
    local radiusY = height / 2 + RADIUS_PADDING
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radiusX, math.sin(angle) * radiusY)
end

local function tooltipAnchor(self)
    local x = self.GetCenter and self:GetCenter()
    local width = UIParent and UIParent.GetWidth and UIParent:GetWidth() or 1920
    if x and x > width / 2 then return "ANCHOR_LEFT" end
    return "ANCHOR_RIGHT"
end

local function onEnter(self)
    if self.dragging or not GameTooltip then return end
    GameTooltip:SetOwner(self, tooltipAnchor(self))
    GameTooltip:AddLine("LootJinx", C.accent[1], C.accent[2], C.accent[3])
    GameTooltip:AddLine(LJ.L("SUBTITLE"), 0.86, 0.87, 0.90, true)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(LJ.L("MINIMAP_LEFT"), 0.70, 0.72, 0.80)
    GameTooltip:AddLine(LJ.L("MINIMAP_RIGHT"), 0.70, 0.72, 0.80)
    GameTooltip:AddLine(LJ.L("MINIMAP_DRAG"), 0.70, 0.72, 0.80)
    GameTooltip:Show()
end

local function onLeave()
    if GameTooltip then GameTooltip:Hide() end
end

local function onClick(_, mouseButton)
    if mouseButton == "RightButton" then
        if LJ.Options and LJ.Options.Open then pcall(LJ.Options.Open, LJ.Options) end
    elseif mouseButton == "LeftButton" then
        if LJ.UI and LJ.UI.Toggle then pcall(LJ.UI.Toggle, LJ.UI) end
    end
end

local function onUpdate()
    if not Minimap or not Minimap.GetCenter or not GetCursorPosition then return end
    local mx, my = Minimap:GetCenter()
    local px, py = GetCursorPosition()
    if not mx or not my or not px or not py then return end
    local scale = Minimap.GetEffectiveScale and Minimap:GetEffectiveScale() or 1
    if not scale or scale == 0 then scale = 1 end
    px, py = px / scale, py / scale
    local angle = math.deg(atan2(py - my, px - mx)) % 360
    if LJ.DB then LJ.DB.minimapAngle = angle end
    applyPosition(angle)
end

local function onDragStart(self)
    self.dragging = true
    if self.LockHighlight then self:LockHighlight() end
    if GameTooltip then GameTooltip:Hide() end
    self:SetScript("OnUpdate", onUpdate)
end

local function onDragStop(self)
    self.dragging = false
    self:SetScript("OnUpdate", nil)
    if self.UnlockHighlight then self:UnlockHighlight() end
    applyPosition(LJ.DB and LJ.DB.minimapAngle)
end

function M:Create()
    if button then return button end
    if not Minimap or not CreateFrame then return nil end

    local b = CreateFrame("Button", "LootJinxMinimapButton", Minimap)
    button = b
    M.button = b

    b:SetSize(31, 31)
    b:SetFrameStrata("MEDIUM")
    if b.SetFixedFrameStrata then b:SetFixedFrameStrata(true) end
    b:SetFrameLevel(8)
    if b.SetFixedFrameLevel then b:SetFixedFrameLevel(true) end
    b:RegisterForClicks("anyUp")
    b:RegisterForDrag("LeftButton")
    b:SetMovable(true)
    if b.SetClampedToScreen then b:SetClampedToScreen(true) end
    if b.SetHighlightTexture then
        b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    end

    local border = b:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT", 0, 0)

    local background = b:CreateTexture(nil, "BACKGROUND")
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    background:SetSize(20, 20)
    background:SetPoint("TOPLEFT", 7, -5)

    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(MEDIA .. "LootJinxIcon")
    icon:SetSize(18, 18)
    icon:SetPoint("TOPLEFT", 8, -6)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.icon = icon

    b:SetScript("OnEnter", onEnter)
    b:SetScript("OnLeave", onLeave)
    b:SetScript("OnClick", onClick)
    b:SetScript("OnDragStart", onDragStart)
    b:SetScript("OnDragStop", onDragStop)

    applyPosition(LJ.DB and LJ.DB.minimapAngle)

    if Minimap.HookScript then
        pcall(Minimap.HookScript, Minimap, "OnSizeChanged", function()
            applyPosition(LJ.DB and LJ.DB.minimapAngle)
        end)
    end

    return b
end

return M
