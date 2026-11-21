local _, LJ = ...
local Overview = {}
LJ.CharacterOverview = Overview
local W, C = LJ.Widgets, LJ.COLORS
local PAGE_SIZE = 7

local function readText(getter, ...)
    if type(getter) ~= "function" then return nil end
    local ok, value = pcall(getter, ...)
    value = ok and LJ.Plain(value)
    if type(value) == "string" and value ~= "" then return value end
end

function Overview:Snapshot()
    if not LJ.DB or not LJ.DB.characterStats or not LJ.CharDB then return nil end
    local name = LJ:PlayerName()
    local realm = readText(GetRealmName)
    local guid = readText(UnitGUID, "player")
    local identity = self.identity
    if identity and identity.char == LJ.CharDB then
        name, realm = name or identity.name, realm or identity.realm
        if name == identity.name and realm == identity.realm then guid = guid or identity.guid end
    end
    if not name or not realm then return nil end
    self.identity = { char = LJ.CharDB, name = name, realm = realm, guid = guid }
    local profiles = LJ.DB.characterStats
    local fallback = "name:" .. realm .. ":" .. name
    local key = guid or fallback
    if guid then
        profiles[fallback] = nil
    else
        local match
        for savedKey, profile in pairs(profiles) do
            if savedKey ~= fallback and type(profile) == "table" and profile.name == name and profile.realm == realm then
                if match then return nil end
                match = savedKey
            end
        end
        key = match or key
    end
    local stats = LJ.Stats.Compute(LJ.Tracker:GetRuns())
    profiles[key] = {
        name = name, realm = realm, updated = LJ.Now(),
        runs = stats.totalDungeons, completed = stats.completedDungeons, noLoot = stats.noLootDungeons,
        won = stats.needWins, lost = stats.needLost, pending = stats.needPending,
    }
    return key
end

local function count(profile, field)
    local value = tonumber(profile[field])
    return value and value >= 0 and value < math.huge and math.floor(value) or 0
end

function Overview:Profiles(current)
    local result = {}
    for key, profile in pairs(LJ.DB.characterStats) do
        if type(key) == "string" and type(profile) == "table"
            and type(profile.name) == "string" and type(profile.realm) == "string" then
            result[#result + 1] = { key = key, profile = profile }
        end
    end
    table.sort(result, function(a, b)
        if a.key == current then return b.key ~= current end
        if b.key == current then return false end
        if a.profile.name ~= b.profile.name then return a.profile.name < b.profile.name end
        if a.profile.realm ~= b.profile.realm then return a.profile.realm < b.profile.realm end
        return a.key < b.key
    end)
    return result
end

local function text(parent, size, color, x, y, width)
    local label = W:Font(parent, size, color)
    label:SetPoint("TOPLEFT", x, y)
    label:SetWidth(width)
    label:SetWordWrap(false)
    return label
end

local columns = {
    { key = "CHARACTER_OVERVIEW_NAME", x = 12, width = 214 },
    { key = "CHARACTER_OVERVIEW_RUNS", x = 230, width = 56 },
    { key = "CHARACTER_OVERVIEW_WON", x = 289, width = 57 },
    { key = "CHARACTER_OVERVIEW_LOST", x = 349, width = 66 },
    { key = "CHARACTER_OVERVIEW_PENDING", x = 418, width = 65 },
    { key = "CHARACTER_OVERVIEW_RATE", x = 486, width = 72 },
}

function Overview:Create(parent)
    if self.panel then return self.panel end
    local panel = W:Panel(parent)
    panel:SetPoint("TOPLEFT", 12, -35)
    panel:SetPoint("BOTTOMRIGHT", -12, 42)
    panel:SetFrameLevel(parent:GetFrameLevel() + 30)
    panel:EnableMouse(true)
    self.panel = panel
    self.title = text(panel, 15, C.accent, 12, -12, 550)
    self.title:SetText(LJ.L("CHARACTER_OVERVIEW_TITLE"))
    self.hint = text(panel, 10, C.muted, 12, -38, 550)
    self.hint:SetText(LJ.L("CHARACTER_OVERVIEW_HINT"))
    self.headers = {}
    for _, column in ipairs(columns) do
        local header = text(panel, 9, C.muted, column.x, -65, column.width)
        header:SetText(LJ.L(column.key))
        self.headers[#self.headers + 1] = header
    end
    self.rows = {}
    for index = 1, PAGE_SIZE do
        local row = W:Button(panel, "", 566, 34)
        row:SetPoint("TOPLEFT", 10, -82 - (index - 1) * 36)
        row.label:Hide()
        row.values = {}
        for i, column in ipairs(columns) do
            row.values[i] = text(row, 11, C.text, column.x - 10, -5, column.width)
        end
        row.realm = text(row, 9, C.muted, 2, -19, 218)
        row:SetScript("OnClick", function(button)
            self.selected = button.profileKey
            self:Refresh()
        end)
        self.rows[index] = row
    end
    self.details = text(panel, 10, C.text, 12, -349, 552)
    self.updated = text(panel, 10, C.muted, 12, -372, 552)
    self.empty = text(panel, 11, C.muted, 12, -105, 548)
    self.empty:SetText(LJ.L("CHARACTER_OVERVIEW_EMPTY"))
    self.prev = W:Button(panel, "<", 42, 22)
    self.prev:SetPoint("BOTTOMLEFT", 12, 10)
    self.prev:SetScript("OnClick", function() self.page = self.page - 1; self:Refresh() end)
    self.next = W:Button(panel, ">", 42, 22)
    self.next:SetPoint("BOTTOMLEFT", 116, 10)
    self.next:SetScript("OnClick", function() self.page = self.page + 1; self:Refresh() end)
    self.pageText = W:Font(panel, 10, C.muted)
    self.pageText:SetPoint("BOTTOMLEFT", 65, 15)
    self.rule = W:Divider(panel)
    self.rule:SetPoint("TOPLEFT", 12, -79)
    self.rule:SetPoint("TOPRIGHT", -12, -79)
    panel:Hide()
    return panel
end

function Overview:ApplyTheme()
    if not self.panel then return end
    local skin = W:Skin()
    if self.skin == skin then return end
    self.skin = skin
    W:Paint(self.panel, skin.bg, skin.border)
    W:SetTextFont(self.title, 18, "", skin.displayFont)
    W:ColorText(self.title, skin.text)
    W:ColorText(self.details, skin.text)
    for _, field in ipairs({ self.hint, self.updated, self.empty, self.pageText }) do
        W:ColorText(field, skin.muted)
    end
    for _, field in ipairs(self.headers) do W:ColorText(field, skin.muted) end
    for _, row in ipairs(self.rows) do
        W:StyleButton(row, skin)
        for _, field in ipairs(row.values) do W:ColorText(field, skin.text) end
        W:ColorText(row.realm, skin.muted)
    end
    W:StyleButton(self.prev, skin)
    W:StyleButton(self.next, skin)
    W:ColorTexture(self.rule, skin.border)
end

function Overview:Refresh()
    if not self.panel or not self.panel:IsShown() then return end
    self:ApplyTheme()
    local current = self:Snapshot()
    local profiles = self:Profiles(current)
    local pages = math.max(1, math.ceil(#profiles / PAGE_SIZE))
    self.page = math.max(1, math.min(self.page or 1, pages))
    local first = (self.page - 1) * PAGE_SIZE + 1
    local selected
    for index = first, math.min(first + PAGE_SIZE - 1, #profiles) do
        if profiles[index].key == self.selected then selected = profiles[index] end
    end
    selected = selected or profiles[first]
    self.selected = selected and selected.key
    for index, row in ipairs(self.rows) do
        local data = profiles[first + index - 1]
        if data then
            local profile = data.profile
            local won, lost = count(profile, "won"), count(profile, "lost")
            local rate = (won + lost) > 0 and ("%.0f%%"):format(100 * won / (won + lost)) or "—"
            local values = { profile.name, count(profile, "runs"), won, lost, count(profile, "pending"), rate }
            for i, value in ipairs(values) do row.values[i]:SetText(value) end
            W:ColorText(row.values[1], data.key == self.selected and self.skin.accent or self.skin.text)
            row.realm:SetText(profile.realm .. (data.key == current and (" · " .. LJ.L("CHARACTER_OVERVIEW_CURRENT")) or ""))
            row.profileKey = data.key
        end
        row:SetShown(data ~= nil)
    end
    self.empty:SetShown(#profiles == 0)
    self.details:SetShown(selected ~= nil)
    self.updated:SetShown(selected ~= nil)
    if selected then
        local profile = selected.profile
        local total = count(profile, "won") + count(profile, "lost") + count(profile, "pending")
        self.details:SetText(LJ.L("CHARACTER_OVERVIEW_DETAILS", profile.name, count(profile, "completed"), count(profile, "noLoot"), total))
        self.updated:SetText(LJ.L("CHARACTER_OVERVIEW_UPDATED", LJ:FormatTime(count(profile, "updated"), "DATE_TIME")))
    end
    self.pageText:SetShown(pages > 1)
    self.pageText:SetText(self.page .. " / " .. pages)
    self.prev:SetShown(self.page > 1)
    self.next:SetShown(self.page < pages)
end
