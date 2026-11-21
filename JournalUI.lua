-- Classic dashboard geometry with an independent Dungeon Journal skin.
local ADDON, ns = ...
local LJ = ns or _G.LootJinx
if not LJ then return end

local J = { fields = {}, recentRows = {}, miniCards = {} }
LJ.JournalUI = J
local W = LJ.Widgets
local S = W:Skin("journal")
local function position()
    local db = LJ.DB
    if not J.frame or not db then return end
    J.frame:ClearAllPoints()
    J.frame:SetPoint(db.journalPoint or "CENTER", UIParent,
        db.journalRelPoint or "CENTER", tonumber(db.journalX) or 0, tonumber(db.journalY) or -40)
end
local function savePosition()
    if not J.frame or not LJ.DB then return end
    local point, _, relativePoint, x, y = J.frame:GetPoint(1)
    if point then
        LJ.DB.journalPoint = point
        LJ.DB.journalRelPoint = relativePoint or point
        LJ.DB.journalX = tonumber(x) or 0
        LJ.DB.journalY = tonumber(y) or -40
    end
end
local function makeReport(f)
    J.reportPopup, J.shareTarget, J.fields.shareError, J.shareParty, J.shareWhisper =
        LJ:CreateDashboardReport(f, S, function(channel, target)
            local sent, reason = LJ.Report:Send(channel, target)
            J.fields.shareError:SetText(reason and LJ.L(reason) or "")
            if sent then J.reportPopup:Hide() end
        end)
end
function J:Create()
    if self.frame then return self.frame end
    if not LJ.DB or not LJ.Tracker then return nil end
    local f = CreateFrame("Frame", "LootJinxJournalFrame", UIParent,
        BackdropTemplateMixin and "BackdropTemplate" or nil)
    self.frame = f
    f:SetSize(640, 510)
    f:SetFrameStrata("DIALOG")
    f:SetFrameLevel(70)
    f:SetToplevel(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    if f.SetClampedToScreen then f:SetClampedToScreen(true) end
    W:Paint(f, S.bg, S.border)
    position()
    W:StyleAccent(W:AccentLine(f), S)
    self.statusPill = LJ:CreateDashboardHeader(self, f, S, savePosition)
    self.fields.status = self.statusPill.label
    self.needCard = LJ:CreateDashboardNeed(self, f, S)
    self.miniCards = LJ:CreateDashboardMinis(self, f, S)
    self.recentPanel, self.recentRows = LJ:CreateDashboardRecent(self, f, S, "journal")
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
        LJ:OpenCompactRun(button.run, "journal")
    end)
    self.compactLatest:Hide()
    LJ:CreateDashboardFooterActions(self, f, S)
    self.resizeGrip = W:ResizeGrip(f, function(scale)
        if LJ.UI and LJ.UI.ApplyScale then
            LJ.UI:ApplyScale(scale)
        else
            J:ApplyScale(scale)
        end
    end, function()
        if LJ.UI and LJ.UI.ApplyScale then
            LJ.UI:ApplyScale(1.0)
        else
            J:ApplyScale(1.0)
        end
    end)
    makeReport(f)
    f:SetScript("OnHide", function()
        self.moreMenu:Hide()
        self.reportPopup:Hide()
        if LJ.History then LJ.History:Hide() end
        if LJ.RunDetail then LJ.RunDetail:Hide() end
        self.shareTarget:ClearFocus()
    end)
    f:Hide()
    if type(UISpecialFrames) == "table" then
        local escapeName = "LootJinxJournalFrame"
        local found = false
        for i = 1, #UISpecialFrames do
            if UISpecialFrames[i] == escapeName then found = true break end
        end
        if not found then table.insert(UISpecialFrames, escapeName) end
    end
    self:ApplyScale(LJ.DB.scale or 1)
    self:ApplyDisplayOptions()
    LJ:RegisterRefresh(function() if f:IsShown() then J:Refresh() end end)
    self:Refresh()
    return f
end
function J:Refresh()
    if not self.frame or not LJ.Stats or not LJ.Tracker then return end
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
function J:ShowReport()
    if not self.frame then self:Create() end
    if not self.frame then return end
    self.moreMenu:Hide()
    self:Show()
    self.shareTarget:SetText(LJ.Report:GetTargetName() or "")
    self.fields.shareError:SetText("")
    self.reportPopup:Show()
    self.shareTarget:SetFocus()
end
function J:Show()
    if not self.frame then self:Create() end
    if not self.frame then return false end
    self:ApplyScale(LJ.DB.scale or 1)
    self:ApplyDisplayOptions()
    self:Refresh()
    self.frame:Show()
    return true
end
function J:Hide() if self.frame then self.frame:Hide() end end
function J:ApplyScale(scale)
    if not LJ.DB then return end
    scale = tonumber(scale) or LJ.DB.scale or 1
    if scale < 0.40 then scale = 0.40 end
    if scale > 3.00 then scale = 3.00 end
    LJ.DB.scale = scale
    if self.frame then self.frame:SetScale(scale) end
    return scale
end
function J:ApplyDisplayOptions()
    if not self.frame or not LJ.DB then return end
    local compact = LJ.DB.compact == true
    self.frame:SetHeight(compact and 358 or 510)
    self.recentPanel:SetShown(not compact)
    self.compactLatest:SetShown(compact and self.compactLatest.run ~= nil)
    self.footer:SetShown(not compact or self.compactLatest.run == nil)
end
function J:ResetPosition()
    if not LJ.DB then return end
    LJ.DB.journalPoint, LJ.DB.journalRelPoint = "CENTER", "CENTER"
    LJ.DB.journalX, LJ.DB.journalY = 0, -40
    position()
end
return J
