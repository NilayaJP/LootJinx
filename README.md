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
| `/lj debug` | Open a copyable diagnostic snapshot for bug reports |
| `/lj help` | Show available commands |

## Diagnostics

`/lj debug` opens a snapshot of the current session and run. It shows the instance-copy state, the stored primary-stat context, recent loot event types, open Need rolls, pending item classifications, and the latest classification decisions. The report is designed to be copied into a bug report. The window follows the active Classic or Journal design and scrolls long snapshots.

The snapshot contains item IDs, roll IDs, event counts, and classification flags only. Player names, chat text, and whisper targets are not included. The **Print to chat** button outputs the same snapshot locally if you prefer plain text.

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
- **Announce records in chat:** Show a local-only chat notice when you exceed a personal record. Off by default; ties do not announce.
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

**Dungeon Curse:** Dungeons without an observed item matching your primary stat. LootJinx determines the stat from your current specialization. For example, Balance Druid uses Intellect, Feral Druid uses Agility, Elemental Shaman uses Intellect, Enhancement Shaman uses Agility, Holy Paladin uses Intellect, and Protection or Retribution Paladin uses Strength. If specialization data is unavailable, LootJinx compares base stats through `UnitStat` before falling back to a class mapping. The stat used for classification is stored with each run, so changing specialization later does not reclassify older runs. Runs recorded before stat context was stored are marked as unknown. The tracker shows your current streak and longest recorded streak.

**Need Rolls:** Counts Need rolls, consecutive losses, and your longest losing streak. Greed rolls and items won through Greed do not affect Need statistics.

**No Need Win:** Dungeons where you rolled Need at least once but won no Need roll. Dungeons without a Need roll do not interrupt the streak.

**No Loot:** Dungeons where no item was observed as loot. Quest items (class ID 12 or type "Quest") do not count as loot.

**Since Need Win:** Dungeons since your last successful Need roll, including dungeons without a Need roll. This counter remains at zero until your first Need roll. The tracker shows the current value and personal record.

Record announcements are optional and local to your client. When enabled, LootJinx posts one chat line for each personal record that increases. Run-based records are checked when a run closes, so a dungeon in progress cannot announce a premature record; a lost Need roll is checked as soon as its result is known. Ties and decreases do not announce, and nothing is sent to party, raid, or whisper chat.

A *run* starts when you enter a group or scenario instance. It remains open when you leave. On re-entry, LootJinx uses a Creature or Cast GUID to determine whether you returned to the same instance copy. If so, the run continues; a different copy starts a new run. The check remains pending until a GUID is available. Entering a different dungeon also closes the previous run.

## Share a Report

The **Report** button in the dashboard footer opens the sharing dialog:

- **Party chat:** Post your statistics to party chat, or raid chat when you are in a raid.
- **Whisper:** Send the report to a named player or your current player target. The target is filled in when the dialog opens. A target on your realm appears without a realm suffix; a cross-realm target appears as `Name-Realm`.

The report has six short, consistently prefixed chat lines: a header followed by five numbered tracker lines. They are sent 0.6 seconds apart. If no party or whisper target is available, the dialog shows a message and sends nothing.

## Dungeon History

Click **History** in the dashboard footer to browse all saved runs, including in compact mode. Search dungeon names, filter by dungeon, and choose **Today**, **Last 7 days**, **Last 30 days**, or **All time**. Date ranges use local calendar days and combine with search and the dungeon filter. Use **Back** and **Next** to page through older runs. The list is newest first. The summary above it shows runs with primary-stat loot, runs without loot, and Need wins, losses, and pending results for the current filters. Active runs are included. Click a run to open its existing detail report; runs recorded before detailed history was introduced remain listed with a "Details unavailable" label.

The history window follows the selected Classic or Dungeon Journal design. ESC closes the detail report first, then the history window, then the dashboard.

The header shows how many runs are displayed and how many are saved. **Clean up** removes boss, drop, roll, and per-item Need details from completed runs older than 30 days after a confirmation prompt. It keeps the run summaries, Need outcomes, lifetime statistics, and active run. Runs with pending items or unresolved Need results are skipped. Cleaned runs remain in history but cannot open a detailed report. Cleanup is manual and cannot be undone.

## Run Details

Recent Runs shows the latest observed personal and other-player Need values directly in each row. Hover over a run to see all observed Need and Greed values with player names and items. Values appear only when the game exposed a roll number; the two short row values may come from different items in the same run.

Click a supported entry in **Recent Runs** to open its detail window (available for runs recorded since version 1.3.0). It shows:

- Dungeon name, date and time, and status (`LIVE` or completed).
- The primary stat used for the run, including any stat changes during that run. Older records without stored context show **Primary stat: unknown**.
- A summary of bosses, items, Need rolls, and Need wins.
- Equippable green-quality or better loot grouped by boss when an encounter or the dungeon loot catalog identifies its source.
- Cataloged dungeon trash in a **Trash drops** section. Other observed gear remains visible under **Other Loot**; proximity to a boss kill alone does not assign it to that boss.
- Each item's icon, quality-colored name, recipient (class-colored, or "You" for your character), winner's roll type and value, and your own Need roll and outcome when available.
- A per-item tooltip with observed roll values for each player when the client or loot chat supplied them.
- A confidence label beside your Need result and a tooltip explaining whether the result came from a direct roll message, a bag check, or another observation. Drop tooltips also explain the recipient evidence. Older records without a saved source show "evidence unavailable".
- Boss attribution by encounter ID. Gray, white, and non-equippable items are excluded.
- A "No loot observed" message for bosses without observed drops.

The detail window opens centered over the dashboard. Close it with **×**, **ESC**, or by closing the dashboard. Use **Back** and **Next** to navigate longer reports.

Runs recorded before version 1.3.0 remain in Recent Runs but cannot be opened because detailed boss and recipient data was not captured for them. Their tooltip explains this.

The bundled `DungeonLootData.lua` is an independent source index drawn from the item IDs in ForeverDungeonJournal 2.0.4. It covers 35 listed dungeons and supports 22 explicit trash groups. The catalog helps label observed drops; it is not a whitelist and does not change the five tracker totals. Unknown or ambiguous items stay in **Other Loot**. The catalog can be regenerated from a reviewed DungeonJournal `Data/Dungeons.lua` with `lua tools/build_dungeon_loot.lua <path-to-Dungeons.lua>`.

## Detection Limits

WoW Forever does not provide a combat log to addons. LootJinx therefore detects loot and roll results on a best-effort basis using:

- `START_LOOT_ROLL` / `CANCEL_LOOT_ROLL` and the roll window.
- `LOOT_HISTORY_UPDATE_DROP` and `C_LootHistory.GetSortedInfoForDrop` for per-player roll values on encounter loot when the API is available.
- `LOOT_OPENED` / `LOOT_READY` and the loot window.
- `CHAT_MSG_LOOT` for win, Need, and Greed messages.
- `ENCOUNTER_END` / `BOSS_KILL` for boss kills and `ENCOUNTER_LOOT_RECEIVED` for loot recipients.
- A `RollOnLoot` hook for your own Need or Greed choice.
- Bag counts as a fallback for unresolved Need results.

Items whose data is not yet available are queued and classified after `GET_ITEM_INFO_RECEIVED`. An item matches your primary stat when `C_Item.GetItemStats` reports a positive value for that stat.

When the client exposes `C_LootHistory`, LootJinx reads the per-player roll values for encounter loot and merges them with values parsed from loot chat. Item tooltips in run details list observed Need, Greed, and Transmog values per player; chat parsing remains the fallback for trash loot and older records. Separate loot-history events for identical items remain separate even when players roll the same numbers.

If a Need result cannot be resolved directly, LootJinx checks your bags after a short delay. A simultaneous Greed roll for the same item prevents a false Need win.

The confidence labels describe the evidence behind a recorded result; they do not change the five tracker totals. A direct roll chat message is marked **confirmed**. Bag checks and matching loot-chat messages are marked **inferred**. Pending results remain **unresolved**.

## Saved Data

- `LootJinxDB`: Account-wide window position, scale, display options, and minimap button angle.
- `LootJinxCharDB`: Per-character runs, Need rolls, and streaks.

`/lj reset` clears only the current character's statistics. Interface preferences remain unchanged.
