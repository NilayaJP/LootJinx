# LootJinx

LootJinx tracks dungeon bad luck in **World of Warcraft: Forever**: missing primary-stat drops, lost Need rolls, unlucky streaks, and personal records. Tracking starts automatically in group and scenario instances. Available in English and German, with **Classic** and **Dungeon Journal** designs.

**Current version:** 1.6.5 · **Interface:** 16001 · **Dependencies:** None

## What it tracks

- **Dungeon Curse:** Runs without an observed rare or better drop matching the primary stat saved for that run. Green trash gear remains visible in run details but does not reset the curse.
- **Need Rolls:** Need wins, losses, and the current and longest losing streaks. Greed does not affect these statistics.
- **No Need Win:** Dungeons where you rolled Need but won no Need roll.
- **No Loot:** Recorded dungeon visits without observed eligible loot; quest items do not count.
- **Since Need Win:** Dungeons since your last successful Need roll.

All five trackers appear in both designs. Empty visits with no observed boss, item, or roll are omitted after leaving the instance.

## Review and share

Browse recent runs and searchable history, filter or compare visits, and open run details to see observed bosses, drops, recipients, and roll values. Known boss and trash loot is grouped by source; unlisted or ambiguous gear stays visible under **Other Loot**. Older runs without detailed data remain in history.

Share a short statistics report in party or raid chat, with a selected same-faction player, or with a confirmed Battle.net friend. Settings include window scale, compact mode, record announcements, and design choice. Character runs are saved in `LootJinxCharDB`; display settings are saved account-wide in `LootJinxDB`.

Version 1.6.5 excludes green primary-stat drops from Dungeon Curse and corrects older runs when saved item evidence is sufficient.

## Install

1. Copy the `LootJinx` folder to `World of Warcraft\_forever_\Interface\AddOns\LootJinx`.
2. Enter `/reload` in game.
3. Open the dashboard with `/lj`, the minimap button, or the AddOn Compartment.

## Commands

| Command | Action |
| --- | --- |
| `/lj` | Open or close the dashboard |
| `/lj options` | Open settings |
| `/lj reset` | Reset this character's statistics after confirmation |
| `/lj scale 0.80–1.30` | Set dashboard scale |
| `/lj resetpos` | Center the dashboard |
| `/lj debug` | Open a copyable diagnostic snapshot |
| `/lj help` | Show all commands |

## Detection limits

WoW Forever does not expose a combat log to addons. LootJinx combines available loot, roll, chat, and encounter events, so some drops or outcomes remain unknown. An unobserved item or boss kill is not proof that it did not happen.
