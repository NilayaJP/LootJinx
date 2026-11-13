-- Routes dashboard entry points to the selected layout.
local ADDON, ns = ...
local LJ = ns or _G.LootJinx
if not LJ or not LJ.UI then return end

local Classic = LJ.UI
local Journal = LJ.JournalUI
local R = { classic = Classic, journal = Journal }
LJ.UI = R

local function valid(id)
    return id == "journal" and "journal" or "classic"
end

local function selected()
    return valid(LJ.DB and LJ.DB.layoutPreview)
end

local function view()
    return selected() == "journal" and Journal or Classic
end

local function syncFrame()
    R.frame = view().frame
end

function R:GetLayout()
    return selected()
end

function R:SetLayout(id)
    id = valid(id)
    if not LJ.DB then return id end
    local old = self.frame
    local wasVisible = old and old:IsShown()
    if old then
        if Classic.frame == old then Classic:Hide()
        elseif Journal and Journal.frame == old then Journal:Hide() end
    end
    if LJ.RunDetail then LJ.RunDetail:Hide() end
    LJ.DB.layoutPreview = id
    self:Create()
    if wasVisible then self:Show() end
    if LJ.Options and LJ.Options.Refresh then LJ.Options:Refresh() end
    return id
end

function R:Create()
    if not LJ.DB then return nil end
    -- Classic remains initialized for its legacy callbacks and saved position.
    if not Classic.frame then Classic:Create() end
    self.settingsButton = Classic.settingsButton
    local active = view()
    if active == Journal and Journal and not Journal.frame then Journal:Create() end
    if Classic.frame and active ~= Classic then Classic:Hide() end
    if Journal and Journal.frame and active ~= Journal then Journal:Hide() end
    syncFrame()
    return self.frame
end

function R:Show()
    self:Create()
    local active = view()
    if active == Journal then
        Journal:Show()
    else
        Classic:ApplyScale(LJ.DB and LJ.DB.scale or 1)
        Classic:Show()
    end
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
    if selected() == "journal" then
        Journal:ShowReport()
    else
        Classic:ShowReport()
    end
end

function R:SendReport(channel, target)
    if selected() == "journal" then
        return LJ.Report:Send(channel, target)
    end
    return Classic:SendReport(channel, target)
end

function R:DebugInfo()
    return "Layout: " .. selected() .. " · " .. Classic:DebugInfo()
end

return R
