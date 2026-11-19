# LootJinx

LootJinx tracks dungeon bad luck in **World of Warcraft: Forever**: lost Need rolls, unlucky streaks, missing loot, and personal records. Tracking starts automatically in group and scenario instances. Available in all supported client languages, with **Classic** and **Dungeon Journal** designs.

**Current version:** 1.7.1 · **Interface:** 16001 · **Dependencies:** None

## What it tracks

- **Need Rolls:** Every Need roll is counted, with wins, losses, pending rolls, the current losing streak, and the personal record. Greed does not affect these statistics.
- **No Need Win:** Dungeons where you rolled Need but won no Need roll.
- **No Loot:** Recorded dungeon visits without observed eligible loot; quest items do not count.
- **Since Need Win:** Dungeons since your last successful Need roll.

All trackers appear in both designs. Empty visits with no observed boss, item, or roll are omitted after leaving the instance.

## Review and share

Browse recent runs and searchable history, filter or compare visits, and open run details to see observed bosses, drops, recipients, and roll values. Known boss and trash loot is grouped by source; unlisted or ambiguous gear stays visible under **Other Loot**. Older runs without detailed data remain in history. Clicking the No Need Win, No Loot, or Since Need Win card opens the history filtered to exactly those runs; a filter chip removes the focus again.

Share a short statistics report in party or raid chat, with a selected same-faction player, or with a confirmed Battle.net friend. Settings include window scale, compact mode, record announcements, and design choice. Character runs are saved in `LootJinxCharDB`; display settings are saved account-wide in `LootJinxDB`.

## Ruleset leaderboard

Open the leaderboard with **Leaderboard** in the dashboard footer or with `/lj leaderboard`. It shows LootJinx users on your ruleset and faction, ranked by Need wins, Need quote, or the longest lost-Need streak. The top 50 and your own row are always visible, with online markers and the last known values for players who are offline.

Sharing is opt-in. On first start, and for existing installations, LootJinx asks once in your selected language. Only your character name, ruleset, class, faction and Need statistics are shared - never your guild, items, dungeon history or account identifiers. You can change sharing at any time under **ESC > Options > AddOns > LootJinx**.

Version 1.7.1 introduces smooth corner drag-resizing (40% to 300%) with right-click reset, improved text legibility and contrast across both Classic and Journal themes, Gold/Silver/Bronze leaderboard podium ranks, and resolved raid and instance-copy detection. Version 1.7.0 adds a ruleset-wide leaderboard for Need wins, Need quote, and the longest lost-Need streak. Sharing is opt-in: LootJinx asks once on first start and for existing installations, and only character name, ruleset, class, faction, and Need statistics are transmitted - never guild, items, or dungeon history. The window shows the top 50 plus your own row and opens from both designs or with `/lj leaderboard`. Version 1.6.9 continues an unfinished run when you re-enter the same dungeon within five minutes, credits uniquely attributed boss loot and the Whitemane/Mograine pair as kill evidence, opens the matching history when you click one of the three tracker cards, and lists every Need roll at the top of the run details. Reopened loot windows no longer add a second drop with an unknown recipient. Version 1.6.8 removed primary-stat detection entirely: every Need roll counts regardless of item stats, and the former Dungeon Curse card is now a Need card showing wins, losses, and pending rolls. Older saved runs are migrated automatically when loaded.

## Install

1. Copy the `LootJinx` folder to `World of Warcraft\_forever_\Interface\AddOns\LootJinx`.
2. Enter `/reload` in game.
3. Open the dashboard with `/lj`, the minimap button, or the AddOn Compartment.

## Commands

| Command | Action |
| --- | --- |
| `/lj` | Open or close the dashboard |
| `/lj leaderboard` | Open the ruleset leaderboard |
| `/lj options` | Open settings |
| `/lj reset` | Reset this character's statistics after confirmation |
| `/lj scale 0.80–1.30` | Set dashboard scale |
| `/lj resetpos` | Center the dashboard |
| `/lj debug` | Open a copyable diagnostic snapshot |
| `/lj help` | Show all commands |

## Detection limits

WoW Forever does not expose a combat log to addons. LootJinx combines available loot, roll, chat, and encounter events, so some drops or outcomes remain unknown. An unobserved item or boss kill is not proof that it did not happen.
