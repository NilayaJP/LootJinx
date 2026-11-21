local _, LJ = ...
local W = LJ.Widgets
local Changelog = {}
LJ.Changelog = Changelog

local function isNewer(current, previous)
    local function parts(version)
        return { tostring(version or ""):match("^(%d+)%.(%d+)%.(%d+)$") }
    end
    local left, right = parts(current), parts(previous)
    if not left[1] then return false end
    if not right[1] then return true end
    for i = 1, 3 do
        local a, b = tonumber(left[i]), tonumber(right[i])
        if a ~= b then return a > b end
    end
    return false
end

function Changelog:InitializeVersion()
    local db = LJ.DB
    if not db.seenWelcome and not db.changelogBaseVersion then
        db.changelogBaseVersion = LJ:AddOnVersion()
    end
end

function Changelog:RefreshPreference()
    if self.checkbox then
        local checked = LJ.DB and LJ.DB.hideChangelog == true
        self.checkbox:SetChecked(checked)
        self.checkbox.mark:SetShown(checked)
    end
end

function Changelog:Create()
    if self.frame then return self.frame end
    local frame = CreateFrame("Frame", "LootJinxChangelogFrame", UIParent)
    frame:SetSize(588, 432)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetFrameLevel(220)
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:Hide()

    local panel = W:Panel(frame)
    panel:SetAllPoints()
    local accent = W:AccentLine(panel)
    local title = W:Font(panel, 20)
    title:SetPoint("TOPLEFT", 20, -16)
    title:SetText(LJ.L("CHANGELOG_TITLE"))

    local version = W:Font(panel, 11)
    version:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -7)

    local close = W:Button(panel, LJ.L("CLOSE"), 96, 22)
    close:SetPoint("TOPRIGHT", -16, -17)
    close:SetScript("OnClick", function() frame:Hide() end)

    local scroll = CreateFrame("ScrollFrame", "LootJinxChangelogScroll", panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 20, -68)
    scroll:SetPoint("BOTTOMRIGHT", -40, 76)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(528, 1)
    scroll:SetScrollChild(content)
    local notes = W:Font(content, 12)
    notes:SetPoint("TOPLEFT")
    notes:SetWidth(516)
    notes:SetJustifyV("TOP")
    notes:SetWordWrap(true)
    notes:SetSpacing(4)

    local checkbox = CreateFrame("CheckButton", nil, panel, BackdropTemplateMixin and "BackdropTemplate" or nil)
    checkbox:SetPoint("BOTTOMLEFT", 20, 19)
    checkbox:SetSize(22, 22)
    checkbox.mark = checkbox:CreateTexture(nil, "ARTWORK")
    checkbox.mark:SetAllPoints()
    checkbox.mark:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    checkbox:SetScript("OnClick", function(button)
        LJ.DB.hideChangelog = button:GetChecked() == true
        self:RefreshPreference()
        if LJ.Options then LJ.Options:Refresh() end
    end)
    local label = W:Font(panel, 11)
    label:SetPoint("LEFT", checkbox, "RIGHT", 5, 0)
    label:SetWidth(515)
    label:SetText(LJ.L("CHANGELOG_OPT_OUT"))

    local credit = W:ForeverDBCredit(panel, function() frame:Hide() end)
    credit:SetPoint("BOTTOMRIGHT", -20, 50)
    if UISpecialFrames then table.insert(UISpecialFrames, frame:GetName()) end

    self.frame, self.version, self.notes = frame, version, notes
    self.panel, self.title, self.accent, self.close, self.preferenceLabel = panel, title, accent, close, label
    self.scroll, self.content, self.checkbox, self.credit = scroll, content, checkbox, credit
    return frame
end

function Changelog:ApplyTheme()
    if not self.frame then return end
    local skin = W:Skin()
    if self.skin ~= skin then
        self.skin = skin
        W:Paint(self.panel, skin.bg, skin.border)
        W:StyleAccent(self.accent, skin)
        W:SetTextFont(self.title, 20, "", skin.displayFont)
        W:ColorText(self.title, skin.text)
        W:ColorText(self.version, skin.muted)
        W:ColorText(self.notes, skin.text)
        W:ColorText(self.preferenceLabel, skin.text)
        W:StyleCheck(self.checkbox, skin, self.checkbox.mark)
        W:StyleCredit(self.credit, skin)
        W:StyleButton(self.close, skin)
        local bar = self.scroll.ScrollBar or _G[self.scroll:GetName() .. "ScrollBar"]
        local thumb = bar and bar.GetThumbTexture and bar:GetThumbTexture()
        if thumb and thumb.SetVertexColor then
            thumb:SetVertexColor(skin.progress[1], skin.progress[2], skin.progress[3], 1)
        end
    end
    local data = self.data
    local text = LJ.L("CHANGELOG_UNAVAILABLE")
    if data and data.sections then
        local blocks = {}
        local accent = ("|cff%02x%02x%02x"):format(
            math.floor(skin.accent[1] * 255), math.floor(skin.accent[2] * 255), math.floor(skin.accent[3] * 255))
        for _, section in ipairs(data.sections) do
            blocks[#blocks + 1] = section.title ~= "" and
                (accent .. section.title .. ":|r\n" .. section.text) or section.text
        end
        text = table.concat(blocks, "\n\n")
    elseif data then
        text = data.text or text
    end
    self.notes:SetText(text)
    if self.frame:IsShown() then
        self.content:SetHeight(math.max(self.scroll:GetHeight(), self.notes:GetStringHeight() + 8))
    end
end

function Changelog:Show()
    if not LJ.DB then return false end
    local data = LJ.ChangelogData
    local current = LJ:AddOnVersion()
    local matches = data and data.version == current
    local frame = self:Create()
    self.data = matches and data or nil
    self.version:SetText("LootJinx " .. current .. (matches and data.date ~= "" and " · " .. data.date or ""))
    local credit = matches and data.foreverDB == true or false
    self.credit:SetShown(credit)
    self.credit.label:SetShown(credit)
    self:RefreshPreference()
    frame:Show()
    self:ApplyTheme()
    self.scroll:SetVerticalScroll(0)
    if matches and isNewer(current, LJ.DB.lastChangelogVersion) then
        LJ.DB.lastChangelogVersion = current
    end
    return true
end

function Changelog:ShowOnLogin()
    local data = LJ.ChangelogData
    if not LJ.DB or LJ.DB.hideChangelog or not data or data.version ~= LJ:AddOnVersion()
        or not isNewer(data.version, LJ.DB.changelogBaseVersion)
        or not isNewer(data.version, LJ.DB.lastChangelogVersion) then return false end
    return self:Show()
end
