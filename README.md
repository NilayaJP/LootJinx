# LootJinx

LootJinx is a World of Warcraft: Forever addon (Interface 16001) that tracks your dungeon bad luck: runs without a drop matching your primary stat, lost Need rolls, unlucky streaks, and personal records.

The interface is available in German and English. Open it with `/lj`, the minimap button, the AddOn button, or the AddOn Compartment next to the minimap.

## Installation

1. Copy the `LootJinx` folder to `World of Warcraft\_forever_\Interface\AddOns\LootJinx`.
2. Enter `/reload` in game.
3. Enter `/lj` to open the dashboard.

## Commands

| Command | Action |
| --- | --- |
| `/lj` | Open or close the dashboard |
| `/lj options` | Open settings (alias: `/lj settings`) |
| `/lj reset` | Reset this character's statistics after confirmation |
| `/lj scale 0.80–1.30` | Change the dashboard scale |
| `/lj resetpos` | Center the dashboard |
| `/lj debug` | Print diagnostic information in chat |
| `/lj help` | Show available commands |

## Minimap Button

LootJinx adds a circular button to the edge of the minimap.

- **Left click:** Open or close the dashboard.
- **Right click:** Open settings.
- **Left click and drag:** Move the button around the minimap.

The button position is saved account-wide (default: bottom left). The button is always visible.

## Settings

Open **ESC > Options > AddOns > LootJinx**. The gear icon in the dashboard and `/lj options` open the same page.

- **Window size:** Scale from 80% to 130% in 5% steps.
- **Reset position:** Center the dashboard.
- **Lock window position:** Prevent accidental dragging by the header.
- **Welcome message on every login:** Show an additional chat hint. The one-time first-start message is independent of this setting.
- **Show watermark:** Toggle the large LootJinx symbol in the lower-right corner.
- **Compact mode:** Hide Recent Runs and reduce the dashboard height from 628 to 476 pixels.
- **Design:** Choose Classic or Dungeon Journal from the dropdown. The choice applies to all characters and takes effect immediately. Both designs show the same trackers and run history; the detail window follows the selected design. Pressing ESC with run details open closes the details first.

Changes are saved immediately.

## Graphics

| File | Use |
| --- | --- |
| `Media/LootJinxIcon.tga` | AddOn and Compartment icon, header icon, and watermark |
| `Media/CurseChest.tga` | Dungeon Curse card illustration |
| `Media/NeedRolls.tga` | Need Rolls card illustration |
| `Media/NoNeedWin.tga` | No Need Win card icon |
| `Media/NoLoot.tga` | No Loot card icon |
| `Media/SinceNeedWin.tga` | Since Need Win card icon |
| `Media/Report.tga` | Report button and sharing dialog icon |

All graphics are 32-bit TGA files at 256 × 256 pixels. If you replace them, use power-of-two dimensions; WoW does not load PNG or JPG files for these textures.

## What Gets Tracked

**Dungeon Curse:** Dungeons without an observed item matching your primary stat. LootJinx determines the stat from your current specialization. For example, Balance Druid uses Intellect, Feral Druid uses Agility, Elemental Shaman uses Intellect, Enhancement Shaman uses Agility, Holy Paladin uses Intellect, and Protection or Retribution Paladin uses Strength. If specialization data is unavailable, LootJinx compares base stats through `UnitStat` before falling back to a class mapping. Changing specialization during a run re-evaluates items already observed in that run. The tracker shows your current streak and longest recorded streak.

**Need Rolls:** Counts Need rolls, consecutive losses, and your longest losing streak. Greed rolls and items won through Greed do not affect Need statistics.

**No Need Win:** Dungeons where you rolled Need at least once but won no Need roll. Dungeons without a Need roll do not interrupt the streak.

**No Loot:** Dungeons where no item was observed as loot. Quest items (class ID 12 or type "Quest") do not count as loot.

**Since Need Win:** Dungeons since your last successful Need roll, including dungeons without a Need roll. This counter remains at zero until your first Need roll. The tracker shows the current value and personal record.

A *run* starts when you enter a group or scenario instance. It remains open when you leave. On re-entry, LootJinx uses a Creature or Cast GUID to determine whether you returned to the same instance copy. If so, the run continues; a different copy starts a new run. The check remains pending until a GUID is available. Entering a different dungeon also closes the previous run.

## Share a Report

The **Report** button in the dashboard footer opens the sharing dialog:

- **Party chat:** Post your statistics to party chat, or raid chat when you are in a raid.
- **Whisper:** Send the report to a named player or your current player target. The target is filled in when the dialog opens. A target on your realm appears without a realm suffix; a cross-realm target appears as `Name-Realm`.

The report has six short, consistently prefixed chat lines: a header followed by five numbered tracker lines. They are sent 0.6 seconds apart. If no party or whisper target is available, the dialog shows a message and sends nothing.

## Dungeon History

Click **History** in the dashboard footer to browse all saved runs, including in compact mode. Search dungeon names, filter by dungeon, and use **Back** and **Next** to page through older runs. The list is newest first. Click a run to open its existing detail report; runs recorded before detailed history was introduced remain listed with a "Details unavailable" label.

The history window follows the selected Classic or Dungeon Journal design. ESC closes the detail report first, then the history window, then the dashboard.

## Run Details

Click a supported entry in **Recent Runs** to open its detail window (available for runs recorded since version 1.3.0). It shows:

- Dungeon name, date and time, and status (`LIVE` or completed).
- A summary of bosses, items, Need rolls, and Need wins.
- Equippable green-quality or better loot grouped by boss in drop order.
- Equippable green-quality or better dungeon trash loot in a separate section.
- Each item's icon, quality-colored name, recipient (class-colored, or "You" for your character), winner's roll type and value, and your own Need roll and outcome when available.
- Boss attribution by encounter ID. Gray, white, and non-equippable items are excluded.
- A "No loot observed" message for bosses without observed drops.

The detail window opens centered over the dashboard. Close it with **×**, **ESC**, or by closing the dashboard. Use **Back** and **Next** to navigate longer reports.

Runs recorded before version 1.3.0 remain in Recent Runs but cannot be opened because detailed boss and recipient data was not captured for them. Their tooltip explains this.

## Detection Limits

WoW Forever does not provide a combat log to addons. LootJinx therefore detects loot and roll results on a best-effort basis using:

- `START_LOOT_ROLL` / `CANCEL_LOOT_ROLL` and the roll window.
- `LOOT_OPENED` / `LOOT_READY` and the loot window.
- `CHAT_MSG_LOOT` for win, Need, and Greed messages.
- `ENCOUNTER_END` / `BOSS_KILL` for boss kills and `ENCOUNTER_LOOT_RECEIVED` for loot recipients.
- A `RollOnLoot` hook for your own Need or Greed choice.
- Bag counts as a fallback for unresolved Need results.

Items whose data is not yet available are queued and classified after `GET_ITEM_INFO_RECEIVED`. An item matches your primary stat when `C_Item.GetItemStats` reports a positive value for that stat.

If a Need result cannot be resolved directly, LootJinx checks your bags after a short delay. A simultaneous Greed roll for the same item prevents a false Need win.

## Saved Data

- `LootJinxDB`: Account-wide window position, scale, display options, and minimap button angle.
- `LootJinxCharDB`: Per-character runs, Need rolls, and streaks.

`/lj reset` clears only the current character's statistics. Interface preferences remain unchanged.
