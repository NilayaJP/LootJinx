-- LootJinx – Lade- und Integrationstest mit WoW-API-Stubs
-- Ausführen: lua tests/load_stub.lua
local checks, failures = 0, 0
local function ok(cond, message)
    checks = checks + 1
    if not cond then
        failures = failures + 1
        print("FEHLER: " .. message)
    end
end

-- ---------------------------------------------------------------- UI-Stub
local frames = {}
local newObject
local UIObject = {}
function UIObject:SetPoint(...) self.__point = { ... } end
function UIObject:GetPoint() return "CENTER", UIParent, "CENTER", 0, -40 end
function UIObject:ClearAllPoints() end
function UIObject:SetSize(w, h) self.__w, self.__h = w, h end
function UIObject:SetWidth(w) self.__w = w end
function UIObject:SetHeight(h) self.__h = h end
function UIObject:GetWidth() return self.__w or 0 end
function UIObject:GetHeight() return self.__h or 0 end
function UIObject:SetAllPoints() end
function UIObject:SetFrameLevel(level) self.__level = level end
function UIObject:GetFrameLevel() return self.__level or 1 end
function UIObject:SetFrameStrata() end
function UIObject:SetToplevel() end
function UIObject:SetMovable() end
function UIObject:EnableMouse() end
function UIObject:SetClampedToScreen() end
function UIObject:RegisterForDrag() end
function UIObject:RegisterForClicks(...)
    -- Wie im echten Client: RegisterForClicks gibt es nur auf Buttons und
    -- erwartet genau eine Button-Angabe ("LeftButton", "anyUp", ...).
    if self.__kind ~= "Button" then
        error("attempt to call a nil value", 2)
    end
    if select("#", ...) ~= 1 then
        error("bad argument #2 to '?' (Usage: self:RegisterForClicks(buttons))", 2)
    end
    self.__clicks = true
end
function UIObject:StartMoving() end
function UIObject:StopMovingOrSizing() end
function UIObject:SetScale(v) self.__scale = v end
function UIObject:GetScale() return self.__scale or 1 end
function UIObject:GetEffectiveScale() return self.__scale or 1 end
function UIObject:GetCenter() return self.__centerX or 0, self.__centerY or 0 end
function UIObject:SetAlpha(v) self.__alpha = v end
function UIObject:GetAlpha() return self.__alpha or 1 end
function UIObject:Show()
    if self.__shown == true then return end
    self.__shown = true
    local fn = self.__scripts and self.__scripts.OnShow
    if fn then fn(self) end
end
function UIObject:Hide()
    if self.__shown == false then return end
    self.__shown = false
    local fn = self.__scripts and self.__scripts.OnHide
    if fn then fn(self) end
end
function UIObject:SetShown(v)
    v = v and true or false
    if self.__shown == v then return end
    self.__shown = v
    local fn = self.__scripts and self.__scripts[v and "OnShow" or "OnHide"]
    if fn then fn(self) end
end
function UIObject:IsShown() return self.__shown == true end
function UIObject:GetName() return self.__name end
function UIObject:SetText(v) self.__text = v end
function UIObject:GetText() return self.__text end
function UIObject:SetFocus() self.__focused = true end
function UIObject:ClearFocus() self.__focused = false end
function UIObject:SetAutoFocus() end
function UIObject:SetMaxLetters() end
function UIObject:SetTextInsets() end
function UIObject:SetFont(font, size, flags) self.__font = { font, size, flags } end
function UIObject:GetFont() return self.__font and self.__font[1], self.__font and self.__font[2], self.__font and self.__font[3] end
function UIObject:SetFontObject() end
function UIObject:SetTextColor() end
function UIObject:SetShadowColor() end
function UIObject:SetShadowOffset() end
function UIObject:SetJustifyH() end
function UIObject:SetJustifyV() end
function UIObject:SetWordWrap() end
function UIObject:SetTexture(v) self.__texture = v end
function UIObject:SetBlendMode(v) self.__blendMode = v end
function UIObject:SetColorTexture(r, g, b, a) self.__color = { r, g, b, a } end
function UIObject:SetTexCoord() end
function UIObject:SetGradient() end
function UIObject:SetMinMaxValues(minValue, maxValue) self.__min, self.__max = minValue, maxValue end
function UIObject:GetMinMaxValues() return self.__min or 0, self.__max or 0 end
function UIObject:SetValueStep(step) self.__step = step end
function UIObject:SetObeyStepOnDrag() end
function UIObject:SetValue(v)
    self.__value = v
    local fn = self.__scripts and self.__scripts.OnValueChanged
    if fn then fn(self, v) end
end
function UIObject:GetValue() return self.__value or 0 end
function UIObject:SetChecked(v) self.__checked = v end
function UIObject:GetChecked() return self.__checked end
function UIObject:SetBackdrop() end
function UIObject:SetBackdropColor() end
function UIObject:SetBackdropBorderColor() end
function UIObject:SetScript(name, fn)
    -- Wie im echten Client: ein Frame kann nur dann ein OnClick-Skript
    -- bekommen, wenn er vorher RegisterForClicks aufgerufen hat.
    if name == "OnClick" and self.__kind == "Frame" and not self.__clicks then
        error("Frame:SetScript(): Cannot assign script handler for 'onclick' "
            .. "(script type not supported by this object)", 2)
    end
    self.__scripts = self.__scripts or {}; self.__scripts[name] = fn
end
function UIObject:GetScript(name) return self.__scripts and self.__scripts[name] end
function UIObject:RegisterEvent(event) self.__events = self.__events or {}; self.__events[event] = true end
function UIObject:CreateTexture() return newObject("Texture") end
function UIObject:CreateFontString() return newObject("FontString") end
function UIObject:SetOwner() end
function UIObject:AddLine() end
function UIObject:SetHyperlink(link) self.__hyperlink = link; return true end

local frames = {}
function newObject(kind, name)
    local o = {
        __kind = kind,
        __name = name,
        __shown = true,
        __level = 1,
    }
    return setmetatable(o, { __index = UIObject })
end

function _G.CreateFrame(kind, name, parent, template)
    local o = newObject(kind, name)
    o.__parent = parent
    o.__template = template
    frames[#frames + 1] = o
    if name then _G[name] = o end
    return o
end

_G.UIParent = newObject("Frame", "UIParent")
_G.UIParent.__w, _G.UIParent.__h = 1920, 1080
_G.Minimap = newObject("Frame", "Minimap")
_G.Minimap.__w, _G.Minimap.__h = 140, 140
_G.Minimap.__centerX, _G.Minimap.__centerY = 1000, 800
local cursorX, cursorY = 1000, 800
_G.GetCursorPosition = function() return cursorX, cursorY end
_G.GameTooltip = newObject("GameTooltip", "GameTooltip")
_G.BackdropTemplateMixin = true
_G.STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
_G.UISpecialFrames = {}
_G.StaticPopupDialogs = {}
local shownPopup, popupShows
popupShows = 0
_G.StaticPopup_Show = function(which, text, _, data)
    shownPopup = { which = which, text = text, data = data }
    popupShows = popupShows + 1
    return shownPopup
end
_G.StaticPopup_Hide = function(which)
    if shownPopup and shownPopup.which == which then shownPopup = nil end
end
_G.UIFrameFadeIn = function() end
_G.BreakUpLargeNumbers = function(n) return tostring(n) end
_G.date = os.date
_G.SlashCmdList = {}
_G.INSTANCE_RESET_SUCCESS = "%s has been reset."
_G.YOU = "You"

-- ---------------------------------------------------------------- Klassen / Items
_G.RAID_CLASS_COLORS = {
    WARRIOR = { r = 0.78, g = 0.61, b = 0.43 },
    ROGUE = { r = 1.00, g = 0.96, b = 0.41 },
    MAGE = { r = 0.41, g = 0.80, b = 0.94 },
}
_G.LOCALIZED_CLASS_NAMES_MALE = {
    WARRIOR = "Krieger", ROGUE = "Schurke", MAGE = "Magier",
}
_G.LOCALIZED_CLASS_NAMES_FEMALE = {
    WARRIOR = "Kriegerin", ROGUE = "Schurkin", MAGE = "Magierin",
}
function _G.GetPlayerInfoByGUID(guid)
    if guid == "Player-1-00000002" then return "Krieger", "WARRIOR" end
    return "Schurke", "ROGUE"
end
_G.ITEM_QUALITY_COLORS = {
    [0] = { r = 1, g = 1, b = 1 },
    [1] = { r = 1, g = 1, b = 1 },
    [2] = { r = 0.40, g = 0.80, b = 0.40 },
    [3] = { r = 0.30, g = 0.70, b = 1.00 },
    [4] = { r = 0.70, g = 0.30, b = 0.90 },
}

-- ---------------------------------------------------------------- Chat-Texte
_G.LOOT_ROLL_YOU_WON = "You won: %s"
_G.LOOT_ROLL_WON = "%s won: %s"
_G.LOOT_ROLL_ALL_PASSED = "Everyone passed on: %s"
_G.LOOT_ROLL_NEED_SELF = "You have selected Need for: %s"
_G.LOOT_ROLL_GREED_SELF = "You have selected Greed for: %s"
_G.LOOT_ROLL_NEED = "%s has selected Need for: %s"
_G.LOOT_ROLL_GREED = "%s has selected Greed for: %s"
_G.LOOT_ROLL_ROLLED_NEED = "Need Roll - %d for %s by %s"
_G.LOOT_ROLL_ROLLED_GREED = "Greed Roll - %d for %s by %s"
_G.LOOT_ITEM_SELF = "You receive loot: %s"
_G.LOOT_ITEM = "%s receives loot: %s"

-- ---------------------------------------------------------------- Zeit / Zonen
local clock = 1000000
function _G.GetServerTime() return clock end
function _G.time() return clock end
function _G.GetTime() return clock end
local function advance(seconds) clock = clock + seconds end

local zone = { inside = false, kind = "none", name = "", instanceID = 0 }
function _G.IsInInstance() return zone.inside, zone.kind end
function _G.GetInstanceInfo()
    return zone.name, zone.kind, 0, "Normal", 5, false, false, zone.instanceID
end

-- ---------------------------------------------------------------- Charakter
local playerClassName = "Schurke"
local playerClassFile = "ROGUE"
local playerSpecIndex = 0
local playerSpecStatID = nil
local playerUnitStats = { [1] = 10, [2] = 100, [3] = 50, [4] = 10 }
local targetAvailable = true

function _G.GetLocale() return "deDE" end
function _G.UnitName(unit)
    if unit == "player" then return "Testrogue", "Testrealm" end
    if unit == "target" then
        if targetAvailable then return "Otherguy", "Testrealm" end
        return nil
    end
    return "Otherguy", "Testrealm"
end
function _G.UnitIsPlayer(unit)
    if unit == "target" then return targetAvailable end
    return true
end
function _G.UnitClass(unit)
    if unit == "player" then return playerClassName, playerClassFile end
    return "Krieger", "WARRIOR"
end
_G.C_SpecializationInfo = {
    GetSpecialization = function() return playerSpecIndex end,
    GetSpecializationInfo = function(index)
        if index ~= playerSpecIndex then return nil end
        return 100 + index, "Spec " .. tostring(index), "", 134400, "DAMAGER", playerSpecStatID
    end,
}
function _G.UnitStat(unit, index)
    if unit == "player" then return playerUnitStats[index] or 0 end
    return 0
end

local function setPlayer(classFile, specIndex, specStatID, unitStats)
    playerClassName = classFile
    playerClassFile = classFile
    playerSpecIndex = specIndex or 0
    playerSpecStatID = specStatID
    if unitStats then playerUnitStats = unitStats end
end

-- ---------------------------------------------------------------- Items
local items = {}
local bagCounts = {}
local rolls = {}
_G.C_Item = {}
function _G.C_Item.GetItemInfo(x)
    local id = type(x) == "number" and x or tonumber(tostring(x):match("item:(%d+)"))
    local it = id and items[id]
    if not it then return nil end
    local link = it.link or ("|cff1eff00|Hitem:" .. id .. "::::::::|h[" .. it.name .. "]|h|r")
    return it.name, link, it.quality or 2, it.ilvl or 20, it.req or 1,
        it.classID or 4, it.subclassID or 1, 1, it.equipLoc or "", it.icon or 134400, it.sellPrice or 0
end
function _G.C_Item.GetItemInfoInstant(x)
    local id = type(x) == "number" and x or tonumber(tostring(x):match("item:(%d+)"))
    local it = id and items[id]
    if not it then return nil end
    local itemType = it.classID == 12 and "Quest" or (it.classID == 2 and "Weapon" or "Armor")
    return id, itemType, "Misc", "", it.icon or 134400, it.classID or 4
end
function _G.C_Item.GetItemStats(x)
    local id = type(x) == "number" and x or tonumber(tostring(x):match("item:(%d+)"))
    local it = id and items[id]
    return it and it.stats or nil
end
function _G.C_Item.GetItemCount(id) return bagCounts[tonumber(id)] or 0 end
function _G.C_Item.RequestLoadItemDataByID() end
_G.GetItemInfo = _G.C_Item.GetItemInfo
_G.GetItemCount = _G.C_Item.GetItemCount

function _G.GetLootRollItemLink(rollID) return rolls[tonumber(rollID)] end
function _G.GetNumLootItems() return 0 end
function _G.GetLootSlotLink() return nil end
function _G.RollOnLoot() end

local sentMessages = {}
function _G.SendChatMessage(message, chatType, language, target)
    sentMessages[#sentMessages + 1] = {
        message = message,
        channel = chatType,
        target = target,
    }
end
local playerInGroup = true
local playerInRaid = false
function _G.IsInGroup() return playerInGroup end
function _G.IsInRaid() return playerInRaid end

function _G.hooksecurefunc(name, fn)
    local orig = _G[name]
    _G[name] = function(...)
        if orig then orig(...) end
        fn(...)
    end
end

-- ---------------------------------------------------------------- Timer
local timers = {}
_G.C_Timer = {
    After = function(seconds, fn)
        timers[#timers + 1] = { seconds = seconds, fn = fn }
    end,
    NewTimer = function(seconds, fn)
        local token = {}
        token.Cancel = function() token.cancelled = true end
        timers[#timers + 1] = { seconds = seconds, fn = fn, token = token }
        return token
    end,
    NewTicker = function()
        local token = {}
        token.Cancel = function() token.cancelled = true end
        return token
    end,
}
local function flushTimers(limit)
    local guard = 0
    while #timers > 0 and guard < (limit or 200) do
        guard = guard + 1
        local t = table.remove(timers, 1)
        if not (t.token and t.token.cancelled) then
            local ok, err = pcall(t.fn)
            if not ok then
                failures = failures + 1
                print("TIMER-FEHLER: " .. tostring(err))
            end
        end
    end
end

-- ---------------------------------------------------------------- Addon laden
_G.LootJinxDB = nil
_G.LootJinxCharDB = nil
local ns = {}
local files = { "Localization.lua", "Core.lua", "Stats.lua", "Widgets.lua", "Tracker.lua", "UI.lua", "RunDetail.lua", "Minimap.lua", "Options.lua" }
for _, file in ipairs(files) do
    local chunk, err = loadfile(file)
    ok(chunk ~= nil, "loadfile " .. file .. ": " .. tostring(err))
    if chunk then
        local good, callErr = pcall(chunk, "LootJinx", ns)
        ok(good, "load " .. file .. ": " .. tostring(callErr))
    end
end

local LJ = _G.LootJinx
ok(LJ ~= nil, "Namespace LootJinx")
local loader
for _, f in ipairs(frames) do
    if f.__events and f.__events.ADDON_LOADED then loader = f break end
end
ok(loader ~= nil, "ADDON_LOADED-Frame")
local function fire(frame, event, ...)
    local fn = frame and frame.__scripts and frame.__scripts.OnEvent
    if not fn then return end
    local good, err = pcall(fn, frame, event, ...)
    ok(good, event .. ": " .. tostring(err))
end

fire(loader, "ADDON_LOADED", "LootJinx")
ok(LJ.dbReady == true, "DB initialisiert")
ok(LJ.Tracker ~= nil, "Tracker vorhanden")
ok(LJ.UI ~= nil, "UI vorhanden")
local trackerFrame
for _, f in ipairs(frames) do
    if f.__events and f.__events.ENCOUNTER_END then trackerFrame = f break end
end
ok(trackerFrame ~= nil, "Tracker-Eventframe vorhanden")

local openedCategory
_G.Settings = {
    RegisterCanvasLayoutCategory = function(panel, name)
        return { ID = "LootJinx", name = name, panel = panel }
    end,
    RegisterAddOnCategory = function(category)
        _G.__ljCategory = category
        return true
    end,
    OpenToCategory = function(id)
        openedCategory = id
        return true
    end,
}

fire(loader, "PLAYER_LOGIN")
ok(_G.LootJinxFrame ~= nil, "Hauptfenster erstellt")
ok(_G.LootJinxFrame:IsShown() == false, "Fenster startet versteckt")
ok(LJ.Options ~= nil, "Options vorhanden")
ok(LJ.Options and LJ.Options.panel ~= nil, "Options-Panel erstellt")
ok(LJ.UI.settingsButton ~= nil, "Settings-Button erstellt")
ok(LJ.DB.locked == false, "Option locked Default")
ok(LJ.DB.showWelcome == false, "Option showWelcome Default")
ok(LJ.DB.showWatermark == true, "Option showWatermark Default")
ok(LJ.DB.compact == false, "Option compact Default")
ok(LJ.Options.controls.scaleValue:GetText() == "100 %", "Options-Sliderwert")
ok(_G.__ljCategory ~= nil, "Settings-Kategorie registriert")
local opened = LJ.Options:Open()
ok(opened == true, "Options lassen sich öffnen")
ok(openedCategory == "LootJinx", "Settings öffnet LootJinx-Kategorie")
openedCategory = nil
LJ:HandleCommand("options")
ok(openedCategory == "LootJinx", "/lj options öffnet Einstellungen")

-- ---------------------------------------------------------------- Minimap
local mm = LJ.Minimap and LJ.Minimap.button
ok(LJ.Minimap ~= nil, "Minimap-Modul vorhanden")
ok(mm ~= nil, "Minimap-Button erstellt")
ok(LJ.DB.minimapAngle == 225, "Minimap-Winkel Default")
ok(mm and mm.__parent == _G.Minimap, "Minimap-Button an Minimap")
local mmPoint = mm and mm.__point
ok(mmPoint and math.abs(mmPoint[4] + 53.03) < 0.1 and math.abs(mmPoint[5] + 53.03) < 0.1,
    "Minimap-Position Default")

local mmClick = mm and mm:GetScript("OnClick")
mmClick(mm, "LeftButton")
ok(_G.LootJinxFrame:IsShown() == true, "Minimap Linksklick öffnet Fenster")
mmClick(mm, "LeftButton")
ok(_G.LootJinxFrame:IsShown() == false, "Minimap Linksklick schließt Fenster")
openedCategory = nil
mmClick(mm, "RightButton")
ok(openedCategory == "LootJinx", "Minimap Rechtsklick öffnet Einstellungen")

local mmDragStart = mm and mm:GetScript("OnDragStart")
local mmDragStop = mm and mm:GetScript("OnDragStop")
ok(type(mmDragStart) == "function" and type(mmDragStop) == "function", "Minimap-Drag-Handler")
mmDragStart(mm)
cursorX, cursorY = 1100, 800
local mmUpdate = mm:GetScript("OnUpdate")
ok(type(mmUpdate) == "function", "Minimap-Drag-Update")
mmUpdate(mm)
ok(math.abs((LJ.DB.minimapAngle or -1) - 0) < 0.01, "Minimap-Winkel beim Ziehen")
mmDragStop(mm)
ok(mm:GetScript("OnUpdate") == nil, "Minimap-Drag beendet")
mmPoint = mm.__point
ok(mmPoint and math.abs(mmPoint[4] - 75) < 0.1 and math.abs(mmPoint[5]) < 0.1,
    "Minimap-Position nach Ziehen")

LJ.DB.compact = true
LJ.DB.showWatermark = false
LJ.UI:ApplyDisplayOptions()
LJ.Options:Refresh()
ok(_G.LootJinxFrame:GetHeight() == 476, "Kompaktmodus verkleinert Fenster")
ok(_G.LootJinxFrame.watermark:IsShown() == false, "Wasserzeichen ausgeblendet")
ok(LJ.Options.controls.compact:GetChecked() == true, "Kompakt-Checkbox")
ok(LJ.Options.controls.watermark:GetChecked() == false, "Wasserzeichen-Checkbox")

LJ.DB.compact = false
LJ.DB.showWatermark = true
LJ.DB.locked = true
LJ.UI:ApplyDisplayOptions()
LJ.Options:Refresh()
ok(_G.LootJinxFrame:GetHeight() == 628, "Normale Fensterhöhe")
ok(_G.LootJinxFrame.watermark:IsShown() == true, "Wasserzeichen sichtbar")
ok(LJ.Options.controls.lock:GetChecked() == true, "Lock-Checkbox")
LJ.DB.locked = false
LJ.Options:Refresh()

-- ---------------------------------------------------------------- Dungeon 1
zone.inside, zone.kind = true, "party"
zone.name, zone.instanceID = "The Deadmines", 101
LJ.Tracker:CheckZone()
local runs = LJ.Tracker:GetRuns()
ok(#runs == 1, "Dungeon 1 gestartet")
local run1 = runs[1]
ok(run1 and run1.name == "The Deadmines", "Dungeon-Name")

items[1001] = {
    name = "Agile Ring", classID = 4, quality = 3,
    stats = { ITEM_MOD_AGILITY_SHORT = 5 },
}
rolls[9001] = "|cff0070dd|Hitem:1001::::::::|h[Agile Ring]|h|r"
LJ.Tracker:OnStartRoll(9001)
ok(run1.agilityDropped == true, "Agility-Drop erkannt")
ok(run1.lootSeen == true, "Loot erkannt")
_G.RollOnLoot(9001, 1)
ok(#run1.needs == 1, "Need-Roll erfasst")
ok(run1.needs[1].id == 1001, "Need-Item-ID")
LJ.Tracker:OnLootChat("You won: " .. rolls[9001])
ok(run1.needs[1].result == "won", "Need gewonnen")

items[1002] = {
    name = "Strong Sword", classID = 2, quality = 3,
    stats = { ITEM_MOD_STRENGTH_SHORT = 8 },
}
rolls[9002] = "|cff0070dd|Hitem:1002::::::::|h[Strong Sword]|h|r"
LJ.Tracker:OnStartRoll(9002)
_G.RollOnLoot(9002, 1)
LJ.Tracker:OnLootChat("Otherguy won: " .. rolls[9002])
ok(run1.needs[2] and run1.needs[2].result == "lost", "Need verloren")

items[1003] = {
    name = "Greedy Cloak", classID = 4, quality = 3,
    stats = { ITEM_MOD_INTELLECT_SHORT = 4 },
}
rolls[9003] = "|cff0070dd|Hitem:1003::::::::|h[Greedy Cloak]|h|r"
LJ.Tracker:OnStartRoll(9003)
local needsBefore = #run1.needs
_G.RollOnLoot(9003, 2)
LJ.Tracker:OnLootChat("You won: " .. rolls[9003])
ok(#run1.needs == needsBefore, "Gier erzeugt keinen Need-Eintrag")

-- ---------------------------------------------------------------- Dungeon 2
zone.inside, zone.kind = false, "none"
LJ.Tracker:CheckZone()
ok(LJ.Tracker:GetActive() ~= nil, "Run nach Verlassen noch aktiv (Wiedereintritt)")
advance(5)
zone.inside, zone.kind = true, "party"
zone.name, zone.instanceID = "Wailing Caverns", 102
LJ.Tracker:CheckZone()
runs = LJ.Tracker:GetRuns()
ok(#runs == 2, "Dungeon 2 gestartet")
ok(runs[1].closed == true, "Dungeon 1 abgeschlossen")
ok(runs[2].name == "Wailing Caverns", "Dungeon 2 Name")

items[1004] = {
    name = "Lost Dagger", classID = 2, quality = 3,
    stats = { ITEM_MOD_AGILITY_SHORT = 9 },
}
rolls[9004] = "|cff0070dd|Hitem:1004::::::::|h[Lost Dagger]|h|r"
LJ.Tracker:OnStartRoll(9004)
_G.RollOnLoot(9004, 1)
LJ.Tracker:OnLootChat("Otherguy won: " .. rolls[9004])
ok(runs[2].needs[1] and runs[2].needs[1].result == "lost", "Need-Verlust in Dungeon 2")

-- Questitems zählen nicht als Loot
items[1005] = { name = "Quest Thing", classID = 12, quality = 1 }
rolls[9005] = "|cffffffff|Hitem:1005::::::::|h[Quest Thing]|h|r"
local lootBefore = runs[2].itemsSeen
LJ.Tracker:OnStartRoll(9005)
ok(runs[2].itemsSeen == lootBefore, "Questitem zählt nicht als Loot")

-- Asynchron geladene Itemdaten: erst Loot, dann Agility
items[1006] = { name = "Late Ring", classID = 4, quality = 2 }
rolls[9006] = "|cff1eff00|Hitem:1006::::::::|h[Late Ring]|h|r"
LJ.Tracker:OnStartRoll(9006)
ok(runs[2].lootSeen == true, "Item ohne Stats zählt als Loot")
ok(#runs[2].pending == 1, "Item ohne Stats ist pending")
items[1006].stats = { ITEM_MOD_AGILITY_SHORT = 7 }
LJ.Tracker:ReclassifyPending(1006)
ok(runs[2].agilityDropped == true, "Pending-Item nachgeladen als Agility")
ok(#runs[2].pending == 0, "Pending-Liste geleert")

-- ---------------------------------------------------------------- Statistik
local stats = LJ.Stats.Compute(LJ.Tracker:GetRuns())
ok(stats.totalDungeons == 2, "Stats: 2 Dungeons")
ok(stats.noAgiDungeons == 0, "Stats: alle mit Agility")
ok(stats.needRolls == 3, "Stats: 3 Need-Rolls (Gier ignoriert)")
ok(stats.needWins == 1, "Stats: 1 Need-Win")
ok(stats.needLost == 2, "Stats: 2 Need-Verluste")
ok(stats.lostNeedCurrent == 2, "Stats: 2 verlorene Needs in Folge")
ok(stats.lostNeedMax == 2, "Stats: Rekord 2")
ok(stats.noNeedWinDungeons == 1, "Stats: 1 Dungeon ohne Need-Win")
ok(stats.noNeedWinCurrent == 1, "Stats: aktuelle No-Win-Serie 1")
ok(stats.sinceNeedWinCurrent == 1, "Stats: 1 Dungeon seit Need-Win")
ok(stats.sinceNeedWinMax == 1, "Stats: Rekord seit Need-Win 1")

-- ---------------------------------------------------------------- UI/Commands
local uiOk, uiErr = pcall(function()
    LJ.UI:Show()
    LJ.UI:Refresh()
end)
ok(uiOk, "UI Show/Refresh: " .. tostring(uiErr))
ok(_G.LootJinxFrame:IsShown() == true, "UI sichtbar")
ok(_G.LootJinxFrame.footer ~= nil and _G.LootJinxFrame.footer:GetText() ~= nil, "Footer gefüllt")

LJ:HandleCommand("scale 0.9")
ok(math.abs((LJ.DB.scale or 0) - 0.9) < 0.001, "Slash scale")
LJ:HandleCommand("help")
LJ:HandleCommand("debug")
LJ:HandleCommand("unbekannt")
ok(type(LootJinx_OnAddonCompartmentClick) == "function", "AddonCompartment Click")
ok(type(LootJinx_OnAddonCompartmentEnter) == "function", "AddonCompartment Enter")
ok(type(LootJinx_OnAddonCompartmentLeave) == "function", "AddonCompartment Leave")

-- ---------------------------------------------------------------- Report
local reportLines = LJ.UI:BuildReport()
ok(#reportLines == 6, "Report: 6 Zeilen")
local lengthOk = true
for _, line in ipairs(reportLines) do
    if type(line) ~= "string" or #line > 255 then lengthOk = false end
end
ok(lengthOk, "Report: alle Zeilen unter 255 Zeichen")
ok(type(reportLines[1]) == "string" and reportLines[1]:find("Schurke", 1, true) ~= nil,
    "Report: Klassenkopf")
ok(reportLines[1]:find("Beweglichkeit", 1, true) ~= nil, "Report: Primärstat im Kopf")
ok(LJ.UI:GetTargetName() == "Otherguy", "Report: Ziel erkannt")

sentMessages = {}
ok(LJ.UI:SendReport("PARTY") == true, "Report: Partychat startet")
flushTimers()
ok(#sentMessages == 6, "Report: 6 Partychat-Nachrichten")
local partyOk = true
for _, m in ipairs(sentMessages) do
    if m.channel ~= "PARTY" then partyOk = false end
end
ok(partyOk, "Report: Kanal PARTY")

playerInRaid = true
sentMessages = {}
ok(LJ.UI:SendReport("PARTY") == true, "Report: Raidchat startet")
flushTimers()
ok(#sentMessages == 6 and sentMessages[1].channel == "RAID", "Report: Kanal RAID")
playerInRaid = false

sentMessages = {}
ok(LJ.UI:SendReport("WHISPER", "Freund") == true, "Report: Whisper startet")
flushTimers()
ok(#sentMessages == 6, "Report: 6 Whisper-Nachrichten")
ok(sentMessages[1].channel == "WHISPER" and sentMessages[1].target == "Freund",
    "Report: Whisper-Name")

sentMessages = {}
ok(LJ.UI:SendReport("WHISPER", "") == true, "Report: Ziel-Fallback startet")
flushTimers()
ok(#sentMessages == 6 and sentMessages[1].target == "Otherguy", "Report: ans aktuelle Ziel")

targetAvailable = false
sentMessages = {}
ok(LJ.UI:SendReport("WHISPER", "") == false, "Report: ohne Ziel abgelehnt")
ok(#sentMessages == 0, "Report: ohne Ziel nichts gesendet")
playerInGroup = false
ok(LJ.UI:SendReport("PARTY") == false, "Report: ohne Gruppe abgelehnt")
ok(#sentMessages == 0, "Report: ohne Gruppe nichts gesendet")
playerInGroup = true
targetAvailable = true

-- ---------------------------------------------------------------- Primärstat je Klasse/Spec
setPlayer("DRUID", 1, 4)     -- Gleichgewicht
ok((LJ:PlayerStat()) == "intellect", "Druide Balance → Intellekt")
setPlayer("DRUID", 2, 2)     -- Wilder Kampf
ok((LJ:PlayerStat()) == "agility", "Druide Feral → Beweglichkeit")
setPlayer("SHAMAN", 1, 4)    -- Elementar
ok((LJ:PlayerStat()) == "intellect", "Schamane Elementar → Intellekt")
setPlayer("SHAMAN", 2, 2)    -- Verstärkung
ok((LJ:PlayerStat()) == "agility", "Schamane Verstärkung → Beweglichkeit")
setPlayer("PALADIN", 1, 4)   -- Heilig
ok((LJ:PlayerStat()) == "intellect", "Paladin Heilig → Intellekt")
setPlayer("PALADIN", 2, 1)   -- Schutz
ok((LJ:PlayerStat()) == "strength", "Paladin Schutz → Stärke")
setPlayer("WARRIOR", 1, 1)
ok((LJ:PlayerStat()) == "strength", "Krieger → Stärke")
setPlayer("MAGE", 1, 4)
ok((LJ:PlayerStat()) == "intellect", "Magier → Intellekt")
ok(LJ:StatShort() == "INT", "Kurzlabel Magier → INT")
setPlayer("HUNTER", 1, 2)
ok((LJ:PlayerStat()) == "agility", "Jäger → Beweglichkeit")

-- Ohne Stat-ID in den Spezialisierungsdaten entscheidet UnitStat.
setPlayer("SHAMAN", 3, nil, { [1] = 20, [2] = 80, [3] = 30, [4] = 40 })
ok((LJ:PlayerStat()) == "agility", "UnitStat-Fallback → Beweglichkeit")

-- Ohne Spezialisierung greift der Klassen-Fallback.
setPlayer("PRIEST", 0, nil, { [1] = 0, [2] = 0, [3] = 30, [4] = 0 })
ok((LJ:PlayerStat()) == "intellect", "Klassen-Fallback Priester → Intellekt")

-- Der Klassen-Fallback wird nicht dauerhaft gecacht: Sobald UnitStat Werte
-- liefert, gewinnt der tatsächliche Basiswert.
setPlayer("PALADIN", 3, nil, { [1] = 0, [2] = 0, [3] = 0, [4] = 0 })
ok((LJ:PlayerStat()) == "strength", "Paladin ohne Werte → Klassen-Fallback")
setPlayer("PALADIN", 3, nil, { [1] = 10, [2] = 10, [3] = 10, [4] = 80 })
ok((LJ:PlayerStat()) == "intellect", "Paladin: UnitStat nachgeladen → Intellekt")

-- Item-Klassifikation nutzt den Primärstat der aktuellen Klasse.
setPlayer("MAGE", 1, 4)
items[2001] = { name = "Intellect Robe", classID = 4, quality = 2,
    stats = { ITEM_MOD_INTELLECT_SHORT = 9 } }
local info = LJ:ClassifyItem("|cff1eff00|Hitem:2001::::::::|h[Intellect Robe]|h|r")
ok(info and info.agi == true, "Intellekt-Item zählt für Magier")
items[2002] = { name = "Agile Robe", classID = 4, quality = 2,
    stats = { ITEM_MOD_AGILITY_SHORT = 9 } }
info = LJ:ClassifyItem("|cff1eff00|Hitem:2002::::::::|h[Agile Robe]|h|r")
ok(info and info.agi == false, "Agility-Item zählt nicht für Magier")

-- Ein Spezialisierungswechsel bewertet bestehende Runs neu.
setPlayer("MAGE", 1, 4)
ok(LJ.Tracker:CheckPrimaryStatChanged() == true, "Primärstat-Wechsel erkannt")
ok(runs[1].agilityDropped == true, "Magier: Intellekt-Drop in Dungeon 1")
ok(runs[2].agilityDropped == false, "Magier: Dungeon 2 ohne Primärstat-Drop")
ok(runs[2].lootSeen == true, "Magier: Loot bleibt erkannt")
ok(runs[2].itemsSeen == 2, "Magier: 2 Loot-Items, Quest ausgeschlossen")
ok(LJ.Tracker:CheckPrimaryStatChanged() == false, "Kein Wechsel ohne Spec-Änderung")
setPlayer("ROGUE", 1, 2)
ok(LJ.Tracker:CheckPrimaryStatChanged() == true, "Rückwechsel erkannt")
ok(runs[2].agilityDropped == true, "Schurke: Dungeon 2 wieder Primärstat-Drop")
ok(runs[2].agiItemsSeen == 2, "Schurke: 2 Primärstat-Items")

-- ---------------------------------------------------------------- Run-Details
local detail = LJ.RunDetail
ok(detail ~= nil, "RunDetail-Modul vorhanden")
local unpackFn = unpack or table.unpack

local function dropById(run, id)
    for i = 1, #(run.drops or {}) do
        if run.drops[i].id == id then return run.drops[i] end
    end
    return nil
end

-- Boss-Kills
fire(trackerFrame, "ENCOUNTER_END", 5001, "Glubtok", 0, 5, 1)
ok(#runs[2].bosses == 1, "Boss aus ENCOUNTER_END erfasst")
ok(runs[2].bosses[1] and runs[2].bosses[1].id == 5001 and runs[2].bosses[1].name == "Glubtok",
    "Boss-Daten gespeichert")
fire(trackerFrame, "ENCOUNTER_END", 5001, "Glubtok", 0, 5, 0)
ok(#runs[2].bosses == 1, "Fehlgeschlagener Boss wird ignoriert")
fire(trackerFrame, "BOSS_KILL", 5001, "Glubtok")
ok(#runs[2].bosses == 1, "Boss-Dedupe")
fire(trackerFrame, "BOSS_KILL", 5002, "Helix")
ok(#runs[2].bosses == 2, "Zweiter Boss erfasst")

-- Boss-Beute mit Empfänger
items[1011] = { name = "Boss Axe", classID = 2, quality = 4, icon = 132394 }
local bossLink = "|cffa335ee|Hitem:1011::::::::|h[Boss Axe]|h|r"
rolls[9011] = bossLink
fire(trackerFrame, "ENCOUNTER_LOOT_RECEIVED", 5001, "Glubtok", bossLink, 1, "Otherguy", "Krieger")
local bossDrop = dropById(runs[2], 1011)
ok(bossDrop ~= nil, "Encounter-Beute erfasst")
ok(bossDrop and bossDrop.bossID == 5001, "Encounter-Beute dem Boss zugeordnet")
ok(bossDrop and bossDrop.winner == "Otherguy", "Encounter-Beute mit Empfänger")
ok(bossDrop and bossDrop.winnerClass == "WARRIOR", "Klassenname aufgelöst")

items[1017] = { name = "Late Boss Shield", classID = 4, quality = 3 }
local lateBossLink = "|cff0070dd|Hitem:1017::::::::|h[Late Boss Shield]|h|r"
ok(LJ.Tracker:NoteDrop(lateBossLink, "Otherguy", runs[2].bosses[1], "chat") == true,
    "Chat-Beute vor Encounter-Ereignis erfasst")
fire(trackerFrame, "ENCOUNTER_LOOT_RECEIVED", 5001, "Glubtok", lateBossLink, 1, "Otherguy", "Krieger")
ok(dropById(runs[2], 1017).source == "encounter", "Encounter bestätigt bestehenden Chat-Drop")

-- Rollzahl aus dem Chat
local chatArgs = { "Need Roll - 91 for " .. bossLink .. " by Otherguy", "Otherguy" }
chatArgs[12] = "Player-1-00000002"
fire(trackerFrame, "CHAT_MSG_LOOT", unpackFn(chatArgs, 1, 12))
ok(#runs[2].rolls == 1 and runs[2].rolls[1].value == 91, "Rollzahl aus Chat gespeichert")
ok(runs[2].rolls[1] and runs[2].rolls[1].kind == "need", "Rollart gespeichert")
ok(bossDrop and bossDrop.roll == 91 and bossDrop.rollKind == "need", "Rollzahl am Drop hinterlegt")

-- Eigene Need-Rollzahl
LJ.Tracker:OnLootChat("Need Roll - 88 for " .. rolls[9004] .. " by Testrogue")
ok(runs[2].needs[1] and runs[2].needs[1].roll == 88, "Eigene Need-Rollzahl gespeichert")
ok(runs[2].needs[1] and runs[2].needs[1].rollKind == "need", "Eigene Rollart gespeichert")

-- Beute ohne Boss und „alle haben gepasst“
items[1012] = { name = "Trash Cloak", classID = 4, quality = 2 }
local trashLink = "|cff1eff00|Hitem:1012::::::::|h[Trash Cloak]|h|r"
rolls[9012] = trashLink
ok(LJ.Tracker:NoteDrop(trashLink, nil, nil, "test") == true, "Beute ohne Boss erfasst")
local trashDrop = dropById(runs[2], 1012)
ok(trashDrop and (trashDrop.bossID or 0) == 0, "Beute ohne Boss-Zuordnung bleibt unzugeordnet")

items[1013] = { name = "Passed Ring", classID = 4, quality = 2 }
local passedLink = "|cff1eff00|Hitem:1013::::::::|h[Passed Ring]|h|r"
ok(LJ.Tracker:NotePassed(passedLink) == true, "Alle-gepasst-Meldung erfasst")
local passedDrop = dropById(runs[2], 1013)
ok(passedDrop and passedDrop.passed == true and passedDrop.winner == nil,
    "Alle haben gepasst markiert")

items[1015] = { name = "Sweet Nectar", classID = 0, quality = 0 }
local grayLink = "|cff9d9d9d|Hitem:1015::::::::|h[Sweet Nectar]|h|r"
ok(LJ.Tracker:NoteDrop(grayLink, nil, runs[2].bosses[1], "encounter") == true,
    "Graues Item mit Boss-Zuordnung erfasst")
items[1016] = { name = "Silk Cloth", classID = 7, quality = 1 }
local whiteLink = "|cffffffff|Hitem:1016::::::::|h[Silk Cloth]|h|r"
ok(LJ.Tracker:NoteDrop(whiteLink, nil, runs[2].bosses[1], "encounter") == true,
    "Weißes Item mit Boss-Zuordnung erfasst")
items[1018] = { name = "Boss Blue", classID = 4, quality = 3 }
local bossBlueLink = "|cff0070dd|Hitem:1018::::::::|h[Boss Blue]|h|r"
ok(LJ.Tracker:NoteDrop(bossBlueLink, nil, runs[2].bosses[1], "chat") == true,
    "Seltenes Item mit zeitlicher Boss-Zuordnung erfasst")
local lateCacheLink = "|cff0070dd|Hitem:1019::::::::|h[Late Cache Sword]|h|r"
ok(LJ.Tracker:NoteDrop(lateCacheLink, nil, runs[2].bosses[1], "chat") == true,
    "Boss-Item vor geladenen Itemdaten erfasst")

-- Detailfenster
local shownOk = detail:Show(runs[2])
ok(shownOk == true and detail:IsShown(), "Detailfenster öffnet")
ok(detail.frame:GetName() == "LootJinxRunDetailFrame", "Detailfenster-Name")
local hasBossSection, hasOtherSection, itemLines = false, false, 0
local shownIDs = {}
for _, line in ipairs(detail.lines or {}) do
    if line.kind == "boss" then
        if line.name == "Glubtok" then hasBossSection = true end
        if line.name == LJ.L("DETAIL_OTHER") then hasOtherSection = true end
    elseif line.kind == "item" then
        itemLines = itemLines + 1
        shownIDs[line.drop.id] = true
    end
end
ok(hasBossSection, "Boss-Bereich im Detail")
ok(not hasOtherSection, "Keine bossfremde Beute im Detail")
ok(shownIDs[1011] == true and shownIDs[1017] == true and shownIDs[1018] == true,
    "Bosszugeordnete Beute auch ohne Encounter-Event im Detail")
ok(not shownIDs[1012] and not shownIDs[1015] and not shownIDs[1016],
    "Bossfremde, graue und weiße Items im Detail ausgeblendet")
ok(detail.summary:GetText():find("2 Bosse · " .. itemLines .. " Items", 1, true) ~= nil,
    "Zusammenfassung zählt nur angezeigte Items")

items[1019] = { name = "Late Cache Sword", classID = 2, quality = 3 }
fire(trackerFrame, "GET_ITEM_INFO_RECEIVED", 1019, true)
local lateCacheShown = false
for _, line in ipairs(detail.lines or {}) do
    if line.kind == "item" and line.drop.id == 1019 then lateCacheShown = true end
end
ok(lateCacheShown, "Boss-Item erscheint nach Laden der Itemdaten")

-- Laufende Aktualisierung: neue Beute erscheint ohne Neuanzeige
local linesBefore = #detail.lines
ok(LJ.Tracker:NoteDrop("|cff1eff00|Hitem:1014::::::::|h[Live Item]|h|r", nil, nil, "live") == true,
    "Live-Drop erfasst")
ok(#detail.lines == linesBefore, "Bossfremder Live-Drop bleibt ausgeblendet")

-- Lange Runs werden auf Seiten aufgeteilt
local manyRun = { id = 9001, name = "Viele Bosse", started = clock, bosses = {}, drops = {}, needs = {} }
for i = 1, 18 do
    manyRun.bosses[i] = { id = 6000 + i, name = "Boss " .. i, at = clock - 100 + i }
    manyRun.drops[i] = {
        id = 3000 + i,
        link = "|cff1eff00|Hitem:" .. (3000 + i) .. "::::::::|h[Item " .. i .. "]|h|r",
        bossID = 6000 + i, at = clock - 90 + i, source = "encounter",
        winner = "Otherguy", winnerClass = "WARRIOR", roll = 50, rollKind = "need",
    }
end
detail:Show(manyRun)
ok(#detail.pages > 1, "Lange Runs werden aufgeteilt")
detail:SetPage(2)
ok(detail.page == 2, "Seitenwechsel funktioniert")
detail:SetPage(1)
ok(detail.page == 1, "Rückwärtswechsel funktioniert")

-- Alte Runs ohne Detaildaten
local legacyRun = {
    id = 9002, name = "Alte Schlucht", started = clock - 5000,
    legacy = true,
    needs = { { id = 1001, link = rolls[9001], at = clock - 4000, result = "won", roll = 87, rollKind = "need" } },
}
detail:Show(legacyRun)
local legacyNote, legacyNeed = false, false
for _, line in ipairs(detail.lines or {}) do
    if line.kind == "note" and line.text == LJ.L("DETAIL_LEGACY") then legacyNote = true end
    if line.kind == "need" then legacyNeed = true end
end
ok(legacyNote, "Alte Runs zeigen den Legacy-Hinweis")
ok(legacyNeed, "Alte Runs zeigen ihre Need-Ergebnisse")

-- ESC-Hinweis: Fenster ist als Sonderframe registriert
local specialOk = false
for _, name in ipairs(_G.UISpecialFrames) do
    if name == "LootJinxRunDetailFrame" then specialOk = true end
end
ok(specialOk, "Detailfenster für ESC registriert")

-- Klick auf eine Recent-Zeile öffnet die Details
LJ.UI:Show()
LJ.UI:Refresh()
local recentRow, legacyRow
for i = 1, #frames do
    local f = frames[i]
    if f.__w == 584 and f.__h == 24 and f.run then
        if f.run == runs[2] then recentRow = f end
        if f.run == runs[1] then legacyRow = f end
    end
end
ok(recentRow ~= nil, "Recent-Zeile mit Run gefunden")
detail:Hide()
local rowClick = recentRow and recentRow:GetScript("OnClick")
ok(type(rowClick) == "function", "Recent-Zeile ist klickbar")
rowClick(recentRow)
ok(detail:IsShown() == true, "Klick öffnet die Run-Details")
LJ.UI:Hide()
ok(detail:IsShown() == false, "Dashboard-Schließen schließt die Details")

-- Runs vor Version 1.3.0 haben keine Detaildaten und sind nicht anklickbar
ok(runs[2].legacy == false, "Neue Runs sind keine Legacy-Runs")
runs[1].legacy = true
LJ.UI:Show()
LJ.UI:Refresh()
local legacyClickable
for i = 1, #frames do
    local f = frames[i]
    if f.__w == 584 and f.__h == 24 and f.run == runs[1] then legacyClickable = f.clickable end
end
ok(legacyClickable == false, "Legacy-Run ist nicht anklickbar")
detail:Hide()
local legacyClick
for i = 1, #frames do
    local f = frames[i]
    if f.__w == 584 and f.__h == 24 and f.run == runs[1] then
        legacyClick = f:GetScript("OnClick")
        legacyRow = f
    end
end
if legacyClick then legacyClick(legacyRow) end
ok(detail:IsShown() == false, "Klick auf Legacy-Run öffnet kein Detailfenster")
runs[1].legacy = false

-- ---------------------------------------------------------------- Legacy-Erkennung
local savedCharDB = _G.LootJinxCharDB
_G.LootJinxCharDB = {
    version = 1, nextRunID = 2,
    runs = { {
        id = 1, name = "Alter Run", started = 100, closed = true,
        needs = {}, pending = {}, seenLinks = {}, greeds = {},
    } },
}
LJ:InitDB()
ok(LJ.CharDB.runs[1].legacy == true, "Run ohne Detailfelder wird als Legacy markiert")
ok(LJ.CharDB.runs[1].bosses ~= nil and LJ.CharDB.runs[1].drops ~= nil,
    "Detailfelder werden auch für alte Runs angelegt")
LJ:InitDB()
ok(LJ.CharDB.runs[1].legacy == true, "Legacy-Kennzeichen bleibt über Starts erhalten")
-- Ein falsch gespeichertes Kennzeichen wird aus dem Detailmarker korrigiert.
LJ.CharDB.runs[1].legacy = false
LJ:InitDB()
ok(LJ.CharDB.runs[1].legacy == true, "Falsch gespeichertes Legacy-Kennzeichen wird korrigiert")
_G.LootJinxCharDB = savedCharDB
LJ:InitDB()
ok(LJ.CharDB.runs[1].legacy == false, "Run mit Detailfeldern ist kein Legacy-Run")

-- ---------------------------------------------------------------- Run beim Verlassen pausieren oder beenden
zone.inside, zone.kind = false, "none"
local popupCount = popupShows
LJ.Tracker:CheckZone()
ok(shownPopup and shownPopup.which == "LOOTJINX_RUN_EXIT" and shownPopup.data == runs[2].id,
    "Beim Verlassen erscheint Run-Dialog")
LJ.Tracker:CheckZone()
ok(popupShows == popupCount + 1, "Run-Dialog erscheint nur einmal pro Verlassen")
local exitDialog = _G.StaticPopupDialogs["LOOTJINX_RUN_EXIT"]
ok(exitDialog and exitDialog.button1 == "Pausieren" and exitDialog.button2 == "Beenden",
    "Run-Dialog bietet Pausieren und Beenden")
if exitDialog then exitDialog.OnButton1(nil, runs[2].id) end
ok(runs[2].paused == true and runs[2].closed == false, "Pausieren hält Run offen")
LJ.UI:Refresh()
ok(recentRow.name:GetText():find("PAUSE", 1, true) ~= nil,
    "Pausierter Recent Run zeigt PAUSE statt LIVE")
detail:Show(runs[2])
ok(detail.subtitle and detail.subtitle:GetText():find("PAUSE", 1, true) ~= nil,
    "Pausierte Run-Details zeigen PAUSE statt LIVE")
LJ:InitDB()
ok(runs[2].paused == true, "Pausierter Run bleibt gespeichert")
advance(901)
LJ.Tracker:CloseStale()
ok(runs[2].closed == false, "Pausierter Run verfällt nicht nach 15 Minuten")
zone.inside, zone.kind = true, "party"
zone.name, zone.instanceID = "Wailing Caverns", 102
LJ.Tracker:CheckZone()
ok(runs[2].paused == false and LJ.Tracker:GetActive() == runs[2],
    "Wiedereintritt setzt pausierten Run fort")
ok(shownPopup == nil, "Wiedereintritt schließt Run-Dialog")
zone.inside, zone.kind = false, "none"
LJ.Tracker:CheckZone()
if exitDialog then exitDialog.OnButton2(nil, runs[2].id) end
ok(runs[2].closed == true and LJ.Tracker:GetActive() == nil,
    "Beenden schließt Run sofort")

-- Beenden ohne Speichern entfernt nur den aktuellen Run.
local savedStats = LJ.Stats.Compute(LJ.Tracker:GetRuns())
zone.inside, zone.kind = true, "party"
zone.name, zone.instanceID = "Discard Test", 103
LJ.Tracker:CheckZone()
local discardRun = LJ.Tracker:GetActive()
ok(discardRun ~= nil, "Test-Run für Verwerfen gestartet")
local nextRunID = LJ.CharDB.nextRunID
zone.inside, zone.kind = false, "none"
LJ.Tracker:CheckZone()
ok(exitDialog and exitDialog.button3 == "Beenden ohne Speichern?"
    and type(exitDialog.OnButton3) == "function",
    "Run-Dialog bietet Beenden ohne Speichern")
if exitDialog and exitDialog.OnButton3 then exitDialog.OnButton3(nil, runs[2].id) end
ok(LJ.Tracker:GetActive() == discardRun, "Veralteter Dialog verwirft keinen neuen Run")
detail:Show(discardRun)
if exitDialog and exitDialog.OnButton3 then exitDialog.OnButton3(nil, discardRun.id) end
local discardedStats = LJ.Stats.Compute(LJ.Tracker:GetRuns())
ok(LJ.Tracker:GetActive() == nil and #LJ.Tracker:GetRuns() == 2,
    "Verworfener Run aus Historie entfernt")
ok(discardedStats.totalDungeons == savedStats.totalDungeons
    and discardedStats.needRolls == savedStats.needRolls,
    "Verworfener Run beeinflusst Statistik nicht")
ok(detail:IsShown() == false, "Details des verworfenen Runs schließen")
ok(LJ.CharDB.nextRunID == nextRunID, "Run-IDs werden nach Verwerfen nicht wiederverwendet")

-- ---------------------------------------------------------------- Reset
zone.inside, zone.kind = false, "none"
detail:Show(runs[2])
LJ.Tracker:ResetAll()
flushTimers()
ok(detail:IsShown() == false, "Reset schließt das Detailfenster")
ok(#LJ.Tracker:GetRuns() == 0, "Reset leert die Historie")
ok(LJ.CharDB.activeID == nil, "Reset entfernt aktiven Run")

local resetBuildOk, resetLines = pcall(function() return LJ.UI:BuildReport() end)
ok(resetBuildOk and #resetLines == 6, "Report funktioniert auch ohne Runs")

if failures > 0 then
    print(string.format("%d von %d Prüfungen fehlgeschlagen.", failures, checks))
    os.exit(1)
end
print(string.format("OK – %d Prüfungen erfolgreich.", checks))
