# LootJinx

LootJinx ist ein WoW-Forever-Addon (Interface 16001), das dein Dungeon-Pech dokumentiert:
Dungeons ohne Beute mit deinem Primärstat, verlorene Need-Rolls und die längsten
Pech-Serien – inklusive Rekordwerten.

Die Oberfläche ist auf Deutsch (englischer Fallback) und öffnet sich über `/lj`,
den Minimap-Button, den Addon-Button oder das AddonCompartment neben der Minimap.

## Installation

1. Ordner `LootJinx` nach `World of Warcraft\_forever_\Interface\AddOns\LootJinx` kopieren.
2. Im Spiel `/reload` ausführen.
3. `/lj` eingeben.

## Befehle

| Befehl | Wirkung |
| --- | --- |
| `/lj` | Fenster öffnen oder schließen |
| `/lj options` | Einstellungen öffnen (Alias: `/lj settings`) |
| `/lj reset` | Alle Statistiken dieses Charakters löschen (mit Bestätigung) |
| `/lj scale 0.80–1.30` | Fenstergröße ändern |
| `/lj resetpos` | Fenster wieder in die Bildschirmmitte setzen |
| `/lj debug` | Diagnose in den Chat ausgeben |
| `/lj help` | Befehlsübersicht anzeigen |

## Minimap-Button

LootJinx legt einen klassischen runden Button an den Rand der Minimap.

- **Linksklick** – Dashboard öffnen oder schließen
- **Rechtsklick** – Einstellungen öffnen
- **Ziehen mit gedrückter linker Maustaste** – Position um die Minimap ändern

Die Position wird accountweit gespeichert (Standard: unten links). Der Button ist
immer sichtbar.

## Einstellungen

Die Einstellungsseite liegt unter **ESC > Optionen > AddOns > LootJinx**.
Zusätzlich öffnet das Zahnrad oben rechts im Dashboard die Seite direkt;
`/lj options` funktioniert ebenfalls.

- **Fenstergröße** – Slider von 80 % bis 130 % in 5-%-Schritten.
- **Position zurücksetzen** – zentriert das Fenster wieder auf dem Bildschirm.
- **Fensterposition sperren** – verhindert versehentliches Verschieben am Kopfbereich.
- **Willkommensnachricht bei jedem Login** – zusätzlicher Chat-Hinweis; der
  einmalige Hinweis beim ersten Start bleibt davon unabhängig.
- **Wasserzeichen anzeigen** – blendet das große LootJinx-Symbol unten rechts ein oder aus.
- **Kompakter Modus** – blendet „Letzte Runs“ aus und verkleinert das Fenster
  von 628 auf 476 px Höhe.

Änderungen werden sofort gespeichert.

## Grafiken

| Datei | Verwendung |
| --- | --- |
| `Media/LootJinxIcon.tga` | Addon-/Compartment-Icon, Header-Icon und Wasserzeichen |
| `Media/CurseChest.tga` | Illustration der Dungeon-Fluch-Karte |
| `Media/NeedRolls.tga` | Illustration der Need-Rolls-Karte |
| `Media/NoNeedWin.tga` | Icon der Karte „Ohne Need-Win" |
| `Media/NoLoot.tga` | Icon der Karte „Ohne Loot" |
| `Media/SinceNeedWin.tga` | Icon der Karte „Seit Need-Win" |
| `Media/Report.tga` | Icon am Bericht-Button und im Teilen-Dialog |

Alle Dateien liegen als 32-Bit-TGA (256×256) vor. Beim Austauschen darauf achten,
dass WoW keine PNG/JPG-Dateien lädt und die Kantenlängen Zweierpotenzen sind.
Die PNGs in `docs/preview/` dienen nur der Browser-Vorschau.

## Was gezählt wird

**Dungeon-Fluch** – Dungeons, in denen kein Item mit deinem Primärstat gedroppt ist.
Der Primärstat wird automatisch aus deiner aktuellen Spezialisierung bestimmt, also
z. B. Druide Balance = Intellekt / Feral = Beweglichkeit, Schamane Elementar =
Intellekt / Verstärkung = Beweglichkeit, Paladin Heilig = Intellekt / Schutz und
Vergeltung = Stärke. Liefert der Client keine Spezialisierungsdaten, vergleicht
LootJinx die Basiswerte über `UnitStat`; erst danach greift eine Klassen-Zuordnung.
Wechselst du die Spezialisierung, werden bereits gesehene Items des Runs mit dem
neuen Primärstat neu bewertet.
Serie = aktuelle Folge solcher Dungeons, Rekord = längste je gemessene Folge.

**Need-Rolls** – ausschließlich Need-Würfe. Verlorene Need-Rolls in Folge und der
höchste Wert ever. Gier-Würfe und per Gier gewonnene Items werden vollständig
ignoriert und beeinflussen keine Need-Statistik.

**Ohne Need-Win** – Dungeons mit mindestens einem Need-Wurf, in denen kein Need-Roll
gewonnen wurde. Dungeons ganz ohne Need unterbrechen die Serie nicht.

**Ohne Loot** – Dungeons, in denen überhaupt kein Item als Beute beobachtet wurde.
Questitems (Klassen-ID 12 bzw. Typ „Quest") zählen nicht als Loot.

**Seit Need-Win** – alle Dungeons seit deinem letzten gewonnenen Need-Roll,
auch Dungeons ohne Need-Wurf. Vor dem ersten Need-Wurf bleibt der Wert 0.
Serie = aktueller Wert, Rekord = höchster Wert.

Ein *Run* beginnt beim Betreten einer Gruppen- oder Szenario-Instanz. Beim Verlassen
bleibt er automatisch offen. Beim Wiedereintritt erkennt LootJinx anhand der
Kreatur- oder Cast-GUID, ob es dieselbe Instanzkopie ist. In diesem Fall wird der
Run fortgesetzt; bei einer anderen Kopie beginnt ein neuer Run. Bis eine GUID
verfügbar ist, bleibt die Prüfung offen. Ein Wechsel zu einem anderen Dungeon
schließt den bisherigen Run ebenfalls ab.

## Bericht teilen

Der Button **Bericht** in der Fußzeile öffnet einen Teilen-Dialog:

- **Partychat** – postet die Statistik in den Partychat; im Raid automatisch in den Raidchat.
- **Flüstern** – verschickt die Statistik per Whisper. Den Namen kannst du eintippen oder
  frei lassen: Beim Öffnen wird ein aktuelles Spieler-Ziel vorbefüllt, und ein leeres Feld
  flüstert ans aktuelle Ziel. Ein Ziel vom eigenen Realm wird ohne Realm-Zusatz eingetragen,
  ein Ziel von einem anderen Realm als `Name-Realm`.

Der Bericht besteht aus sechs Zeilen – Kopf, Dungeon-Fluch, Need-Rolls, ohne Need-Win,
ohne Loot und seit Need-Win – und wird im Abstand von einer Sekunde gesendet, damit das
Chat-Limit eingehalten wird. Ist niemand in der Gruppe oder kein Whisper-Ziel vorhanden,
zeigt der Dialog einen Hinweis und sendet nichts.

## Run-Details

Ein Klick auf einen Eintrag unter **„Letzte Runs"** öffnet ein eigenes
Detailfenster (Version 1.3.0). Es zeigt:

- Kopf mit Dungeonname, Datum/Uhrzeit und Status (`LIVE` oder abgeschlossen),
- die Kurzzeile „Bosse · Items · Need-Rolls (gewonnen)",
- Bossen zugeordnete, ausrüstbare Beute ab grüner Qualität, nach Bossen und Drop-Reihenfolge gruppiert,
- pro Item: Icon und Name in Qualitätsfarbe, Empfänger (Klassenfarbe, „Du" bei dir),
  Rollart und Rollzahl des Gewinners (z. B. `Need 91`, `Gier 45`) und darunter dein
  eigener Need-Wurf mit Ergebnis (`Dein Need: 87 · verloren`),
- Items mit Boss-Zuordnung durch Encounter-ID oder letzten erfolgreichen Boss; graue, weiße, nicht ausrüstbare und nicht zugeordnete Drops bleiben ausgeblendet,
- Bosse ohne beobachtete Beute mit dem Hinweis „Keine Beute beobachtet".

Das Fenster wird zentriert über dem Dashboard geöffnet, lässt sich per `×`, `ESC`
oder durch Schließen des Dashboards beenden und blättert bei langen Runs über
„Zurück"/„Weiter" durch die Seiten.

Boss- und Empfängerdetails werden erst ab Version 1.3.0 erfasst. Runs, die vor
dieser Version aufgezeichnet wurden, stehen weiterhin unter „Letzte Runs",
sind aber **nicht anklickbar** – ihr Tooltip weist darauf hin, dass für sie
keine Details vorliegen.

## Grenzen der Erkennung

Forever stellt Addons keinen Combat-Log zur Verfügung. LootJinx erkennt Beute daher
best effort über:

- `START_LOOT_ROLL` / `CANCEL_LOOT_ROLL` und das Roll-Fenster,
- `LOOT_OPENED` / `LOOT_READY` (Loot-Fenster),
- `CHAT_MSG_LOOT` (Gewinn-/Need-/Gier-Meldungen),
- `ENCOUNTER_END` / `BOSS_KILL` (Boss-Kills) und `ENCOUNTER_LOOT_RECEIVED`
  (Beute samt Empfänger),
- den `RollOnLoot`-Hook für deine eigene Need-/Gier-Auswahl,
- Beutelzählung als Absicherung für Need-Ergebnisse.

Items, deren Daten noch nicht geladen sind, werden vorgemerkt und über
`GET_ITEM_INFO_RECEIVED` nachträglich eingeordnet. Ein Item gilt als „für dich",
wenn `C_Item.GetItemStats` den Primärstat deiner Spezialisierung positiv meldet.

Wird ein Need-Roll nicht eindeutig aufgelöst, entscheidet nach kurzer Zeit die
Beutelzählung; ein gleichzeitig laufender Gier-Roll auf dasselbe Item verhindert
einen falschen Need-Sieg.

## Datenspeicherung

- `LootJinxDB` – Fensterposition, Skalierung, Darstellungsoptionen und Minimap-Winkel (accountweit).
- `LootJinxCharDB` – Runs, Need-Rolls und Serien (pro Charakter).

`/lj reset` löscht nur die Charakterdaten. Die UI-Einstellungen bleiben erhalten.

## Tests

Die Addon-Logik lässt sich ohne WoW ausführen:

```sh
lua tests/stats_spec.lua   # reine Statistik-Engine (50 Prüfungen)
lua tests/load_stub.lua    # Integrationstest mit WoW-API-Stubs (195 Prüfungen, inkl. Klassen-/Spec-Matrix, Report, Einstellungen, Minimap-Button und Run-Details)
```

`luac -p` über alle Lua-Dateien prüft die Syntax (Lua 5.1-kompatibel halten).
