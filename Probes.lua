-- LootJinx - Beobachtungen fuer offene Client-Fragen. Schreibt nur in
-- LootJinxDB.probes und veraendert kein Verhalten.
local ADDON, ns = ...
local LJ = ns or _G.LootJinx
if not LJ then return end

local MAX_PER_KEY = 25

function LJ.Probe(key, value)
    local db = _G.LootJinxDB
    if type(db) ~= "table" or type(key) ~= "string" then return end
    db.probes = type(db.probes) == "table" and db.probes or {}
    local list = db.probes[key]
    if type(list) ~= "table" then
        list = {}
        db.probes[key] = list
    end
    local converted, text = pcall(tostring, value)
    if not converted then text = "unreadable" end
    for i = 1, #list do
        if list[i] == text then return end
    end
    -- Ringpuffer: Bei vollem Speicher faellt die aelteste Beobachtung heraus,
    -- damit spaetere DungeonRuns nicht dauerhaft unsichtbar bleiben.
    if #list >= MAX_PER_KEY then table.remove(list, 1) end
    list[#list + 1] = text
end

local function snapshot()
    if type(GetBuildInfo) == "function" then
        LJ.Probe("U04-build", table.concat({ tostring(GetBuildInfo()) }, " "))
    end
    local runs = _G.LootJinxCharDB and _G.LootJinxCharDB.runs
    LJ.Probe("U04-savedvars", "charRuns=" .. tostring(type(runs) == "table" and #runs or "nil"))
    LJ.Probe("U18-realm", tostring(type(GetRealmName) == "function" and GetRealmName() or "nil"))
    LJ.Probe("U17-api", "Settings=" .. type(Settings)
        .. " RegisterAddOnCategory=" .. type(Settings and Settings.RegisterAddOnCategory)
        .. " GameTooltip.IsOwned=" .. type(GameTooltip and GameTooltip.IsOwned))
    LJ.Probe("U05-api", "issecretvalue=" .. type(issecretvalue)
        .. " InChatMessagingLockdown=" .. type(C_ChatInfo and C_ChatInfo.InChatMessagingLockdown))
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then pcall(snapshot) end
end)
