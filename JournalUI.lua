-- Shared dashboard controller for Dungeon Journal and the illustrated designs.
local ADDON, ns = ...
local LJ = ns or _G.LootJinx
if not LJ then return end

local W = LJ.Widgets
local Dashboard = {}

function Dashboard:Create()
    if self.frame then return self.frame end
    if not LJ.DB or not LJ.Tracker then return nil end
    local S = W:Skin(self.theme)
    local f = CreateFrame("Frame", self.frameName, UIParent,
        BackdropTemplateMixin and "BackdropTemplate" or nil)
    self.frame = f
    f:SetSize(640, 510)
    f:SetFrameStrata("DIALOG")
    f:SetFrameLevel(70)
    f:SetToplevel(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    if f.SetClampedToScreen then f:SetClampedToScreen(true) end
    LJ:ApplyDashboardPosition(f)
    self.statusPill = LJ:CreateDashboardHeader(self, f, S)
    self.fields.status = self.statusPill.label
    self.needCard = LJ:CreateDashboardNeed(self, f, S)
    self.miniCards = LJ:CreateDashboardMinis(self, f, S)
    if self.theme == "dwarven" then
        for i, card in ipairs(self.miniCards) do
            card:ClearAllPoints()
            card:SetPoint("TOPLEFT", 16 + (i - 1) * 208, -68)
            W:StyleAccent(W:AccentLine(card), S)
        end
        self.needCard:ClearAllPoints()
        self.needCard:SetPoint("TOPLEFT", 16, -186)
    end
    self.recentPanel, self.recentRows = LJ:CreateDashboardRecent(self, f, S, self.theme)
    self.fields.recentEmpty = self.recentPanel.empty
    self.fields.needLostCurrent = self.needCard.metric.streak
    self.fields.noNeedWinCurrent = self.miniCards[1].value
    self.fields.noLootCurrent = self.miniCards[2].value
    self.fields.sinceWinCurrent = self.miniCards[3].value

    local divider = f:CreateTexture(nil, "ARTWORK")
    divider:SetPoint("BOTTOMLEFT", 16, 42)
    divider:SetPoint("BOTTOMRIGHT", -16, 42)
    divider:SetHeight(1)
    W:ColorTexture(divider, S.border)
    self.footer = W:Font(f, 9, S.muted, "")
    self.footer:SetText(LJ.L("FOOTER_HINT"))
    self.footer:SetPoint("BOTTOMLEFT", 16, 25)
    self.footer:SetWidth(230)
    W:AddDashboardCredit(f, S.accent)
    self.compactLatest = CreateFrame("Button", nil, f)
    self.compactLatest:SetSize(230, 20)
    self.compactLatest:SetPoint("BOTTOMLEFT", 16, 21)
    self.compactLatest:RegisterForClicks("LeftButtonUp")
    self.compactLatest.label = W:Font(self.compactLatest, 10, S.text, "")
    W:UseTextSize(self.compactLatest.label, "list", 10)
    self.compactLatest.label:SetPoint("LEFT", 0, 0)
    self.compactLatest.label:SetWidth(230)
    self.compactLatest.label:SetWordWrap(false)
    self.compactLatest:SetScript("OnEnter", function(button)
        W:ColorText(button.label, S.accent)
        if button.run then LJ:ShowRecentTooltip(button, button.run) end
    end)
    self.compactLatest:SetScript("OnLeave", function(button)
        W:ColorText(button.label, S.text)
        if GameTooltip then GameTooltip:Hide() end
    end)
    self.compactLatest:SetScript("OnClick", function(button)
        if self.moreMenu then self.moreMenu:Hide() end
        LJ:OpenCompactRun(button.run, self.theme)
    end)
    self.compactLatest:Hide()
    LJ:CreateDashboardFooterActions(self, f, S)
    self.resizeGrip = W:ResizeGrip(f, function(scale) LJ.UI:ApplyScale(scale) end,
        function() LJ.UI:ApplyScale(1.0) end)
    self.reportPopup, self.shareTarget, self.fields.shareError, self.shareParty, self.shareWhisper =
        LJ:CreateDashboardReport(f, S, function(channel, target)
            local sent, reason = LJ.Report:Send(channel, target)
            self.fields.shareError:SetText(reason and LJ.L(reason) or "")
            if sent then self.reportPopup:Hide() end
        end)
    f:SetScript("OnHide", function()
        self.moreMenu:Hide()
        self.reportPopup:Hide()
        if LJ.History then LJ.History:Hide() end
        if LJ.RunDetail then LJ.RunDetail:Hide() end
        self.shareTarget:ClearFocus()
    end)
    f:Hide()
    if type(UISpecialFrames) == "table" then
        local escapeName = self.frameName
        local found = false
        for i = 1, #UISpecialFrames do
            if UISpecialFrames[i] == escapeName then found = true break end
        end
        if not found then table.insert(UISpecialFrames, escapeName) end
    end
    self:ApplyScale(LJ.DB.scale or 1)
    self:ApplyDisplayOptions()
    LJ:RegisterRefresh(function() if f:IsShown() then self:Refresh() end end)
    self:Refresh()
    return f
end
function Dashboard:Refresh()
    if not self.frame or not LJ.Stats or not LJ.Tracker then return end
    local S = W:Skin(self.theme)
    local runs = LJ.Tracker:GetRuns()
    local stats = LJ.Stats.Compute(runs)
    local active = LJ.Tracker:GetActive()
    local live = LJ.Tracker:IsLive()
    local latest = runs[#runs]
    self.compactLatest.run = latest
    if latest then self.compactLatest.label:SetText(LJ:CompactLatestText(latest)) end
    self.compactLatest:SetShown(LJ.DB.compact == true and latest ~= nil)
    self.footer:SetShown(LJ.DB.compact ~= true or latest == nil)
    LJ:UpdateDashboardStatus(self.statusPill, active, live, latest, S)
    LJ:UpdateDashboardNeed(self.needCard.metric, stats)
    LJ:UpdateDashboardMinis(self.miniCards, stats)
    LJ:UpdateDashboardRecent(self.recentPanel, self.recentRows, runs)
end
function Dashboard:ShowReport()
    if not self.frame then self:Create() end
    if not self.frame then return end
    self.moreMenu:Hide()
    self:Show()
    self.shareTarget:SetText(LJ.Report:GetTargetName() or "")
    self.fields.shareError:SetText("")
    self.reportPopup:Show()
    self.shareTarget:SetFocus()
end
function Dashboard:Show()
    if not self.frame then self:Create() end
    if not self.frame then return false end
    self:ApplyScale(LJ.DB.scale or 1)
    self:ApplyDisplayOptions()
    self:Refresh()
    self.frame:Show()
    return true
end
function Dashboard:Hide() if self.frame then self.frame:Hide() end end
function Dashboard:ApplyScale(scale)
    if not LJ.DB then return end
    scale = tonumber(scale) or LJ.DB.scale or 1
    if scale < 0.40 then scale = 0.40 end
    if scale > 3.00 then scale = 3.00 end
    LJ.DB.scale = scale
    if self.frame then self.frame:SetScale(scale) end
    LJ:ApplyDashboardPosition(self.frame)
    return scale
end
function Dashboard:ApplyDisplayOptions()
    if not self.frame or not LJ.DB then return end
    local compact = LJ.DB.compact == true
    self.frame:SetHeight(compact and 358 or 510)
    self.recentPanel:SetShown(not compact)
    self.compactLatest:SetShown(compact and self.compactLatest.run ~= nil)
    self.footer:SetShown(not compact or self.compactLatest.run == nil)
end
function Dashboard:ResetPosition()
    LJ:ResetDashboardPosition(self.frame)
end
local function createDashboard(theme, name)
    return setmetatable({
        theme = theme, frameName = name, fields = {},
    }, { __index = Dashboard })
end

LJ.JournalUI = createDashboard("journal", "LootJinxJournalFrame")
LJ.ThemeDashboards = {
    goblin = createDashboard("goblin", "LootJinxGoblinFrame"),
    dwarven = createDashboard("dwarven", "LootJinxDwarvenFrame"),
    oracle = createDashboard("oracle", "LootJinxOracleFrame"),
}
return LJ.JournalUI
