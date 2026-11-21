-- Routes dashboard entry points to the selected layout.
local ADDON, ns = ...
local LJ = ns or _G.LootJinx
if not LJ or not LJ.UI then return end

local Classic = LJ.UI
local R = LJ.ThemeDashboards
R.classic, R.journal = Classic, LJ.JournalUI
LJ.UI = R

local function selected()
    return LJ:GetLayoutSpec(LJ.DB and LJ.DB.layoutPreview).id
end

local function view()
    return R[selected()]
end

local function syncFrame()
    local active = view()
    R.frame = active.frame
    R.historyButton = active.historyButton
    R.lossRecordButton = active.lossRecordButton
    R.settingsButton = active.settingsButton
    R.resizeGrip = active.resizeGrip
end

function R:GetLayout()
    return selected()
end

function R:SetLayout(id)
    id = LJ:GetLayoutSpec(id).id
    if not LJ.DB then return id end
    if self.frame and LJ.DB.layoutPreview == id and self.frame == view().frame then return id end
    local old = view()
    local wasVisible = old.frame and old.frame:IsShown()
    old:Hide()
    if LJ.RunDetail then LJ.RunDetail:Hide() end
    if LJ.History then LJ.History:Hide() end
    LJ.DB.layoutPreview = id
    self:Create()
    if LJ.Diagnostics and LJ.Diagnostics.ApplyTheme then LJ.Diagnostics:ApplyTheme() end
    if LJ.Changelog then LJ.Changelog:ApplyTheme() end
    if wasVisible then self:Show() end
    if LJ.Options and LJ.Options.Refresh then LJ.Options:Refresh() end
    return id
end

function R:Create()
    if not LJ.DB then return nil end
    -- Classic remains initialized for its legacy callbacks and saved position.
    if not Classic.frame then Classic:Create() end
    local active = view()
    if not active.frame then active:Create() end
    syncFrame()
    return self.frame
end

function R:Show()
    self:Create()
    local active = view()
    if active == Classic then
        Classic:ApplyScale(LJ.DB and LJ.DB.scale or 1)
    end
    active:Show()
    syncFrame()
end

function R:Hide()
    local active = view()
    active:Hide()
    syncFrame()
end

function R:Toggle()
    self:Create()
    if self.frame and self.frame:IsShown() then self:Hide() else self:Show() end
end

function R:Refresh()
    local active = view()
    active:Refresh()
    syncFrame()
end

function R:ApplyScale(scale)
    local active = view()
    local value = active:ApplyScale(scale)
    syncFrame()
    if LJ.Options and LJ.Options.Refresh then LJ.Options:Refresh() end
    return value
end

function R:ApplyDisplayOptions()
    view():ApplyDisplayOptions()
    if LJ.Options and LJ.Options.Refresh then LJ.Options:Refresh() end
end

function R:ResetPosition()
    return view():ResetPosition()
end

function R:ConfirmReset()
    return Classic:ConfirmReset()
end

function R:GetTargetName()
    return LJ.Report:GetTargetName()
end

function R:BuildReport()
    return LJ.Report:Build()
end

function R:ShowReport()
    return view():ShowReport()
end

function R:SendReport(channel, target)
    if view() ~= Classic then
        return LJ.Report:Send(channel, target)
    end
    return Classic:SendReport(channel, target)
end

function R:DebugInfo()
    return "Layout: " .. selected() .. " · " .. Classic:DebugInfo()
end

return R
