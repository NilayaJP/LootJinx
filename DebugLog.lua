-- LootJinx – temporäres Debug-Log für Instanz-Tests
-- WoW-Addons können keine Dateien schreiben. Das Log landet deshalb in der
-- SavedVariable LootJinxDebugLog und wird beim Logout bzw. /reload in
-- WTF/Account/<Account>/SavedVariables/LootJinx.lua geschrieben.
local ADDON, ns = ...
local LJ = ns or _G.LootJinx or {}
_G.LootJinx = LJ

local D = {}
LJ.DebugLog = D

local MAX_ENTRIES = 600

local function stamp()
    local t = LJ.Now and LJ.Now() or 0
    local ok, text = pcall(function() return LJ:FormatTime(t, "%Y-%m-%d %H:%M:%S") end)
    if ok and type(text) == "string" then return text end
    return "?"
end

function D:Add(kind, text)
    local entries = self.entries
    if not entries then return end
    local line = stamp() .. " | " .. tostring(kind or "?")
    if text ~= nil and text ~= "" then line = line .. " | " .. tostring(text) end
    line = line:gsub("[\r\n]+", " ")
    if #line > 400 then line = line:sub(1, 400) .. "..." end
    entries[#entries + 1] = line
    while #entries > MAX_ENTRIES do table.remove(entries, 1) end
end

function D:InstallErrorHandler()
    if self.errorHandlerInstalled then return end
    if type(geterrorhandler) ~= "function" or type(seterrorhandler) ~= "function" then return end
    local ok, previous = pcall(geterrorhandler)
    if not ok or type(previous) ~= "function" then return end
    self.errorHandlerInstalled = true
    seterrorhandler(function(message)
        pcall(D.Add, D, "ERROR", tostring(message))
        local handled, result = pcall(previous, message)
        if handled then return result end
    end)
end

function D:InstallLogout()
    if self.logoutInstalled or type(CreateFrame) ~= "function" then return end
    self.logoutInstalled = true
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_LOGOUT")
    frame:SetScript("OnEvent", function()
        D:Add("session", "logout")
    end)
end

-- Wird aus Core:InitDB nach dem Laden der SavedVariables aufgerufen.
function D:Init()
    if self.ready then return end
    self.ready = true
    local store = _G.LootJinxDebugLog
    if type(store) ~= "table" then
        store = {}
        _G.LootJinxDebugLog = store
    end
    if type(store.entries) ~= "table" then store.entries = {} end
    self.store = store
    self.entries = store.entries
    local version = LJ.AddOnVersion and LJ:AddOnVersion() or "?"
    self:Add("session", string.format("login version=%s locale=%s lang=%s layout=%s",
        tostring(version), tostring(LJ.locale), tostring(LJ.lang),
        tostring(LJ.DB and LJ.DB.layoutPreview)))
    self:InstallErrorHandler()
    self:InstallLogout()
end
