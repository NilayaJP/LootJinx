-- LootJinx – Lokalisierung (Deutsch / Englisch)
local ADDON, ns = ...
local LJ = ns or _G.LootJinx or {}
_G.LootJinx = LJ

local locale = (GetLocale and GetLocale()) or "enUS"
local lang = (locale == "deDE") and "de" or "en"
LJ.locale = locale
LJ.lang = lang

local S = {
    TITLE = { de = "LOOTJINX", en = "LOOTJINX" },
    SUBTITLE = { de = "Dein Dungeon-Pech im Blick", en = "Your dungeon luck, exposed" },

    STATUS_LIVE = { de = "LIVE", en = "LIVE" },
    STATUS_READY = { de = "BEREIT", en = "READY" },
    STATUS_IDLE = { de = "PAUSE", en = "PAUSED" },

    CLOSE = { de = "Schließen", en = "Close" },
    ERROR_START = { de = "LootJinx konnte nicht starten: %s", en = "LootJinx could not start: %s" },
    ERROR_PART = { de = "LootJinx: Teil %s fehlerhaft: %s", en = "LootJinx: part %s failed: %s" },
    ERROR_REFRESH = { de = "LootJinx: Anzeige konnte nicht aktualisiert werden: %s", en = "LootJinx: display could not be refreshed: %s" },
    ERROR_SHOW = { de = "LootJinx: Das Fenster liess sich nicht öffnen. Bitte /lj debug nutzen.", en = "LootJinx: the window could not be opened. Please use /lj debug." },
    ERROR_NO_DB = { de = "LootJinx: Datenbank oder Tracker sind nicht bereit.", en = "LootJinx: database or tracker are not ready." },
    HELP = { de = "Hilfe", en = "Help" },
    RESET = { de = "Reset", en = "Reset" },
    REPORT = { de = "Bericht", en = "Report" },
    OPTIONS_TITLE = { de = "Einstellungen", en = "Settings" },
    OPTIONS_TAB = { de = "LootJinx", en = "LootJinx" },
    OPTIONS_UNAVAILABLE = { de = "Die Einstellungen sind in diesem Client nicht verfügbar.", en = "Settings are not available in this client." },
    TT_OPTIONS_1 = { de = "Öffnet die LootJinx-Einstellungen.", en = "Opens the LootJinx settings." },
    MINIMAP_LEFT = { de = "Linksklick: Fenster öffnen oder schließen", en = "Left click: open or close the window" },
    MINIMAP_RIGHT = { de = "Rechtsklick: Einstellungen öffnen", en = "Right click: open settings" },
    MINIMAP_DRAG = { de = "Ziehen: Position ändern", en = "Drag: change position" },

    OPT_WINDOW = { de = "FENSTER", en = "WINDOW" },
    OPT_SCALE = { de = "Fenstergröße", en = "Window scale" },
    OPT_SCALE_RANGE = { de = "80 % bis 130 %, wird sofort angewendet.", en = "80% to 130%, applied immediately." },
    OPT_RESET_POS = { de = "Position zurücksetzen", en = "Reset position" },
    OPT_RESET_HINT = { de = "Setzt das Fenster wieder in die Bildschirmmitte.", en = "Centers the window on screen again." },
    OPT_BEHAVIOR = { de = "VERHALTEN", en = "BEHAVIOR" },
    OPT_LOCK = { de = "Fensterposition sperren", en = "Lock window position" },
    OPT_LOCK_HINT = { de = "Verhindert das versehentliche Verschieben am Kopfbereich.", en = "Prevents accidental dragging by the header." },
    OPT_WELCOME = { de = "Willkommensnachricht bei jedem Login", en = "Welcome message on every login" },
    OPT_WELCOME_HINT = { de = "Zeigt zusätzlich zum ersten Start einen kurzen Hinweis im Chat.", en = "Shows a short chat hint in addition to the first-start message." },
    OPT_APPEARANCE = { de = "DARSTELLUNG", en = "APPEARANCE" },
    OPT_WATERMARK = { de = "Wasserzeichen anzeigen", en = "Show watermark" },
    OPT_WATERMARK_HINT = { de = "Blendet das große LootJinx-Symbol unten rechts ein oder aus.", en = "Toggles the large LootJinx symbol in the bottom right." },
    OPT_COMPACT = { de = "Kompakter Modus", en = "Compact mode" },
    OPT_COMPACT_HINT = { de = "Blendet „Letzte Runs“ aus und verkleinert das Fenster.", en = "Hides Recent Runs and shrinks the window." },
    OPT_FOOTER = { de = "Änderungen werden sofort gespeichert. Weitere Befehle: /lj help", en = "Changes are saved immediately. More commands: /lj help" },

    JOURNAL_TITLE = { de = "Dungeon-Journal", en = "Dungeon Journal" },
    JOURNAL_SUBTITLE = { de = "Chronik deines Dungeon-Pechs", en = "A chronicle of your dungeon luck" },
    JOURNAL_TAB_RUNS = { de = "Runs", en = "Runs" },
    JOURNAL_TAB_CURSES = { de = "Flüche", en = "Curses" },
    JOURNAL_TAB_RECORDS = { de = "Rekorde", en = "Records" },
    JOURNAL_TAB_SHARE = { de = "Teilen", en = "Share" },
    JOURNAL_LATEST = { de = "Letzter Dungeon", en = "Latest Dungeon" },
    JOURNAL_CURRENT_RECORDS = { de = "Serien & Rekorde", en = "Streaks & Records" },
    JOURNAL_RECORD_VALUE = { de = "Rekord %d", en = "Record %d" },
    JOURNAL_CURRENT_VALUE = { de = "Aktuell %d", en = "Current %d" },
    JOURNAL_LEGACY = { de = "Keine Details", en = "No details" },

    REPORT_TITLE = { de = "BERICHT TEILEN", en = "SHARE REPORT" },
    REPORT_SUB = { de = "Statistik in den Chat posten", en = "Post your stats to chat" },
    REPORT_WHISPER_LABEL = { de = "Whisper-Ziel:", en = "Whisper target:" },
    REPORT_PARTY = { de = "Partychat", en = "Party chat" },
    REPORT_WHISPER = { de = "Flüstern", en = "Whisper" },
    REPORT_CANCEL = { de = "Abbrechen", en = "Cancel" },
    REPORT_NO_PARTY = { de = "Du bist in keiner Gruppe.", en = "You are not in a group." },
    REPORT_NO_TARGET = { de = "Bitte einen Namen eingeben oder ein Spieler-Ziel auswählen.", en = "Enter a name or select a player target." },
    REPORT_TARGET_HINT = { de = "Leer lassen, um das aktuelle Spieler-Ziel anzuflüstern.", en = "Leave empty to whisper your current player target." },
    REPORT_SENT_GROUP = { de = "Bericht in den Gruppenchat gepostet.", en = "Report posted to group chat." },
    REPORT_SENT_RAID = { de = "Bericht in den Raidchat gepostet.", en = "Report posted to raid chat." },
    REPORT_SENT_WHISPER = { de = "Bericht an %s geflüstert.", en = "Report whispered to %s." },
    REPORT_LINE_HEADER = { de = "LootJinx · %s (%s)", en = "LootJinx · %s (%s)" },
    REPORT_LINE_CURSE = { de = "Dungeon-Fluch: %d von %d Dungeons ohne Drop mit %s · Serie %d · Rekord %d", en = "Dungeon curse: %d of %d dungeons without a %s drop · streak %d · record %d" },
    REPORT_LINE_NEED = { de = "Need-Rolls: %d gewonnen, %d verloren, %d offen · Verlustserie %d · Rekord %d", en = "Need rolls: %d won, %d lost, %d pending · loss streak %d · record %d" },
    REPORT_LINE_NO_WIN = { de = "Dungeons ohne Need-Win: %d · Serie %d · Rekord %d", en = "Dungeons without a need win: %d · streak %d · record %d" },
    REPORT_LINE_NO_LOOT = { de = "Dungeons ohne Loot: %d · Serie %d · Rekord %d", en = "Dungeons without loot: %d · streak %d · record %d" },
    REPORT_LINE_SINCE = { de = "Dungeons seit letztem Need-Win: %d · Rekord %d", en = "Dungeons since last need win: %d · record %d" },
    TT_REPORT_1 = { de = "Postet die Statistik in den Partychat oder per Whisper an einen Freund.", en = "Posts your stats to party chat or whispers them to a friend." },

    CARD_CURSE = { de = "DUNGEON-FLUCH", en = "DUNGEON CURSE" },
    CARD_CURSE_SUB = { de = "Dungeons ohne Drop mit %s", en = "Dungeons without a %s drop" },
    CARD_CURSE_EMPTY = { de = "Noch keine Dungeons aufgezeichnet", en = "No dungeons recorded yet" },
    CARD_CURSE_RATIO = { de = "%d von %d Dungeons", en = "%d of %d dungeons" },
    CARD_CURSE_PCT = { de = "%d %% ohne %s", en = "%d %% without %s" },

    CARD_NEED = { de = "NEED-ROLLS", en = "NEED ROLLS" },
    CARD_NEED_SUB = { de = "Gier zählt nicht", en = "Greed doesn't count" },
    CARD_NEED_LOST = { de = "%d verloren", en = "%d lost" },
    CARD_NEED_TOTAL = { de = "von %d Need-Rolls", en = "of %d need rolls" },
    CARD_NEED_WINS = { de = "%d gewonnen", en = "%d won" },
    CARD_NEED_PENDING = { de = "%d offen", en = "%d pending" },
    CARD_NEED_WINRATE = { de = "%d %% Wins", en = "%d %% wins" },
    CARD_NEED_NO_DATA = { de = "Noch keine Need-Rolls", en = "No need rolls yet" },

    STREAK = { de = "SERIE", en = "STREAK" },
    RECORD = { de = "REKORD", en = "RECORD" },
    LIVE = { de = "LIVE", en = "LIVE" },
    NO_DATA = { de = "–", en = "–" },

    MINI_NO_WIN = { de = "OHNE NEED-WIN", en = "NO NEED WIN" },
    MINI_NO_WIN_SUB = { de = "Dungeons mit Need,\naber ohne Sieg", en = "Dungeons with a need\nroll but no win" },
    MINI_NO_LOOT = { de = "OHNE LOOT", en = "NO LOOT" },
    MINI_NO_LOOT_SUB = { de = "Kein Item als Beute\nbeobachtet", en = "No item observed\nas loot" },
    MINI_SINCE = { de = "SEIT NEED-WIN", en = "SINCE NEED WIN" },
    MINI_SINCE_SUB = { de = "Dungeons seit dem\nletzten Need-Sieg", en = "Dungeons since the\nlast need win" },

    RECENT = { de = "LETZTE RUNS", en = "RECENT RUNS" },
    RECENT_EMPTY = { de = "Noch keine Dungeons aufgezeichnet. Betritt einen Dungeon, um zu starten.", en = "No dungeons recorded yet. Enter a dungeon to begin." },

    DETAIL_TITLE = { de = "Run-Details", en = "Run details" },
    DETAIL_CLICK = { de = "Klicken für Details", en = "Click for details" },
    DETAIL_NO_LEGACY_CLICK = { de = "Für Runs vor Version 1.3.0 gibt es keine Details.", en = "Runs from before version 1.3.0 have no details." },
    DETAIL_CLOSED = { de = "Abgeschlossen", en = "Completed" },
    DETAIL_SUMMARY = { de = "%d Bosse · %d Items · %d Need-Rolls (%d gewonnen)", en = "%d bosses · %d items · %d need rolls (%d won)" },
    DETAIL_BOSS_ITEMS = { de = "%d Items", en = "%d items" },
    DETAIL_BOSS_EMPTY = { de = "Keine Beute beobachtet", en = "No loot observed" },
    DETAIL_OTHER = { de = "Dungeon-Trash", en = "Dungeon trash" },
    DETAIL_NEED_SECTION = { de = "Need-Rolls", en = "Need rolls" },
    DETAIL_LEGACY = { de = "Boss- und Empfängerdetails werden erst ab Version 1.3.0 erfasst.", en = "Boss and recipient details are only recorded from version 1.3.0 onward." },
    DETAIL_EMPTY = { de = "Keine Beute aufgezeichnet.", en = "No loot recorded." },
    DETAIL_NO_NEEDS = { de = "Keine Need-Rolls aufgezeichnet.", en = "No need rolls recorded." },
    DETAIL_UNKNOWN_BOSS = { de = "Unbekannter Boss", en = "Unknown boss" },
    DETAIL_ITEM_UNKNOWN = { de = "Item #%d", en = "Item #%d" },
    DETAIL_RECIPIENT_UNKNOWN = { de = "Empfänger unbekannt", en = "Recipient unknown" },
    DETAIL_NOBODY = { de = "niemand", en = "nobody" },
    DETAIL_YOU = { de = "Du", en = "You" },
    DETAIL_PASSED = { de = "Alle haben gepasst", en = "Everyone passed" },
    DETAIL_NEED_LINE = { de = "Dein Need: %d · %s", en = "Your need: %d · %s" },
    DETAIL_NEED_LINE_NO_ROLL = { de = "Dein Need · %s", en = "Your need · %s" },
    DETAIL_NEED_WON = { de = "gewonnen", en = "won" },
    DETAIL_NEED_LOST = { de = "verloren", en = "lost" },
    DETAIL_NEED_OPEN = { de = "offen", en = "pending" },
    DETAIL_ROLL_NEED = { de = "Need %d", en = "Need %d" },
    DETAIL_ROLL_GREED = { de = "Gier %d", en = "Greed %d" },
    DETAIL_PAGE = { de = "Seite %d / %d", en = "Page %d / %d" },
    DETAIL_PREV = { de = "Zurück", en = "Back" },
    DETAIL_NEXT = { de = "Weiter", en = "Next" },
    DETAIL_HINT = { de = "ESC schließt das Fenster.", en = "ESC closes the window." },

    FOOTER_HINT = { de = "Gier zählt nicht", en = "Greed doesn't count" },
    FOOTER_CLASS = { de = "%s · %s", en = "%s · %s" },

    BADGE_STAT = { de = "%s", en = "%s" },
    BADGE_NO_STAT = { de = "OHNE %s", en = "NO %s" },
    BADGE_NEED = { de = "NEED %d/%d", en = "NEED %d/%d" },
    BADGE_LOST = { de = "%d verloren", en = "%d lost" },
    BADGE_LOOT = { de = "LOOT", en = "LOOT" },
    BADGE_EMPTY = { de = "LEER", en = "EMPTY" },
    BADGE_NO_NEED = { de = "KEIN NEED", en = "NO NEED" },

    TODAY = { de = "Heute", en = "Today" },
    YESTERDAY = { de = "Gestern", en = "Yesterday" },

    TT_CURSE_TITLE = { de = "Dungeon-Fluch", en = "Dungeon Curse" },
    TT_CURSE_1 = { de = "Zählt Dungeons, in denen kein Item mit deinem Primärstat (%s) gedroppt ist.", en = "Counts dungeons where no item with your primary stat (%s) dropped." },
    TT_CURSE_2 = { de = "Serie: aktuelle Folge ohne solchen Drop. Rekord: die längste je gemessene Folge.", en = "Streak: the current run of dungeons without such a drop. Record: the longest streak ever measured." },

    TT_NEED_TITLE = { de = "Need-Rolls", en = "Need Rolls" },
    TT_NEED_1 = { de = "Zählt ausschließlich Need-Würfe. Gier-Würfe und per Gier gewonnene Items werden komplett ignoriert.", en = "Counts only need rolls. Greed rolls and items won with greed are ignored completely." },
    TT_NEED_2 = { de = "Serie: verlorene Need-Rolls in Folge. Rekord: die längste solche Folge.", en = "Streak: lost need rolls in a row. Record: the longest such streak." },

    TT_NO_WIN_TITLE = { de = "Dungeons ohne Need-Win", en = "Dungeons without a Need win" },
    TT_NO_WIN_1 = { de = "Dungeons mit mindestens einem Need-Wurf, in denen du keinen Need-Roll gewonnen hast.", en = "Dungeons with at least one need roll in which you won no need roll." },
    TT_NO_WIN_2 = { de = "Dungeons ganz ohne Need unterbrechen die Serie nicht.", en = "Dungeons without any need roll do not break the streak." },

    TT_NO_LOOT_TITLE = { de = "Dungeons ohne Loot", en = "Dungeons without loot" },
    TT_NO_LOOT_1 = { de = "Dungeons, in denen überhaupt kein Item als Beute beobachtet wurde. Questitems zählen nicht.", en = "Dungeons where no item was observed as loot at all. Quest items are excluded." },

    TT_SINCE_TITLE = { de = "Seit letztem Need-Win", en = "Since the last Need win" },
    TT_SINCE_1 = { de = "Alle Dungeons seit deinem letzten gewonnenen Need-Roll – auch Dungeons ohne Need.", en = "Every dungeon since your last won need roll – including dungeons without a need roll." },
    TT_SINCE_2 = { de = "Gier-Gewinne zählen nicht. Serie: aktueller Wert, Rekord: höchster Wert jemals.", en = "Greed wins do not count. Streak: current value, record: highest value ever." },

    TT_RECENT_TITLE = { de = "Letzte Runs", en = "Recent runs" },
    TT_RECENT_1 = { de = "Die letzten vier Dungeons mit Kurzinfo.", en = "The last four dungeons at a glance." },
    TT_RUN_AGI = { de = "Primärstat-Drop: %s", en = "Primary stat drop: %s" },
    TT_RUN_LOOT = { de = "Loot beobachtet: %s", en = "Loot observed: %s" },
    TT_RUN_NEEDS = { de = "Need-Rolls: %d (gewonnen: %d, verloren: %d, offen: %d)", en = "Need rolls: %d (won: %d, lost: %d, pending: %d)" },
    TT_RUN_TIME = { de = "Zeitraum: %s", en = "Duration: %s" },
    YES = { de = "Ja", en = "Yes" },
    NO = { de = "Nein", en = "No" },

    CHAT_HELP_1 = { de = "Befehle:", en = "Commands:" },
    CHAT_HELP_2 = { de = "/lj – Fenster öffnen oder schließen", en = "/lj – open or close the window" },
    CHAT_HELP_3 = { de = "/lj reset – Statistiken dieses Charakters löschen", en = "/lj reset – delete this character's statistics" },
    CHAT_HELP_4 = { de = "/lj scale 0.80–1.30 – Fenstergröße", en = "/lj scale 0.80–1.30 – window scale" },
    CHAT_HELP_5 = { de = "/lj options – Einstellungen öffnen", en = "/lj options – open settings" },
    CHAT_HELP_6 = { de = "/lj debug – Diagnose ausgeben", en = "/lj debug – print diagnostics" },
    CHAT_RESET_DONE = { de = "Alle Statistiken für %s wurden gelöscht.", en = "All statistics for %s have been deleted." },
    CHAT_RESET_NONE = { de = "Es gibt noch keine Statistiken zum Löschen.", en = "There are no statistics to delete yet." },
    CHAT_SCALE_SET = { de = "Fenstergröße: %.2f", en = "Window scale: %.2f" },
    CHAT_SCALE_RANGE = { de = "Erlaubt sind 0.80 bis 1.30.", en = "Allowed range is 0.80 to 1.30." },
    CHAT_UNKNOWN = { de = "Unbekannter Befehl. Nutze /lj help.", en = "Unknown command. Use /lj help." },
    CHAT_WELCOME = { de = "Willkommen! Tippe /lj oder nutze den Addon-Button, um dein Pech zu sehen.", en = "Welcome! Type /lj or use the addon button to see your luck." },
    CHAT_DEBUG_HEADER = { de = "LootJinx Diagnose", en = "LootJinx diagnostics" },
    CHAT_DEBUG_INSIDE = { de = "Im Dungeon: %s · Aktiv: %s", en = "Inside dungeon: %s · Active: %s" },
    CHAT_DEBUG_RUNS = { de = "Aufgezeichnete Runs: %d", en = "Recorded runs: %d" },
    CHAT_DEBUG_STAT = { de = "Klasse: %s · Primärstat: %s", en = "Class: %s · Primary stat: %s" },
    CHAT_DEBUG_ITEMS = { de = "Letzte Item-Prüfungen:", en = "Recent item checks:" },
    CHAT_DEBUG_NONE = { de = "Noch keine Items geprüft.", en = "No items checked yet." },
    CHAT_DEBUG_UI = { de = "UI: %s · DB: %s · Details: %s · Fenster sichtbar: %s", en = "UI: %s · DB: %s · Details: %s · window visible: %s" },
    CHAT_LOADED = { de = "LootJinx %s geladen.", en = "LootJinx %s loaded." },

    RESET_POPUP_TITLE = { de = "LootJinx zurücksetzen", en = "Reset LootJinx" },
    RESET_POPUP_TEXT = { de = "Alle Dungeon-, Need- und Rekord-Daten dieses Charakters werden gelöscht. Das kann nicht rückgängig gemacht werden.", en = "All dungeon, need and record data for this character will be deleted. This cannot be undone." },
    RESET_POPUP_OK = { de = "Löschen", en = "Delete" },
    RESET_POPUP_CANCEL = { de = "Abbrechen", en = "Cancel" },

    STAT_AGILITY = { de = "Beweglichkeit", en = "Agility" },
    STAT_STRENGTH = { de = "Stärke", en = "Strength" },
    STAT_INTELLECT = { de = "Intelligenz", en = "Intellect" },
    STAT_SHORT_AGILITY = { de = "AGI", en = "AGI" },
    STAT_SHORT_STRENGTH = { de = "STR", en = "STR" },
    STAT_SHORT_INTELLECT = { de = "INT", en = "INT" },
    UNKNOWN_CLASS = { de = "Abenteurer", en = "Adventurer" },
    UNKNOWN_DUNGEON = { de = "Dungeon", en = "Dungeon" },
}

local function lookup(key)
    local e = S[key]
    if not e then return key end
    return e[lang] or e.en or key
end

function LJ.L(key, ...)
    local text = lookup(key)
    if select("#", ...) > 0 then
        local ok, formatted = pcall(string.format, text, ...)
        if ok then return formatted end
    end
    return text
end

LJ.strings = S
