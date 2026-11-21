# LootJinx

LootJinx tracks dungeon bad luck in **World of Warcraft: Forever**: lost Need rolls, unlucky streaks, missing loot, and personal records. Tracking starts automatically in dungeons, raids, and scenarios. Available in all supported client languages, with **Classic** and **Dungeon Journal** designs.

**Current version:** 1.7.4 · **Interface:** 16001 · **Dependencies:** None

## What it tracks

- **Need Rolls:** Every Need roll is counted, with wins, losses, pending rolls, the current losing streak, and the personal record. Greed does not affect these statistics.
- **No Need Win:** Dungeons where you rolled Need but won no Need roll.
- **No Loot:** Recorded dungeon visits without observed eligible loot; quest items do not count.
- **Since Need Win:** Dungeons since your last successful Need roll.

All trackers appear in both designs. Empty visits with no observed boss, item, or roll are omitted after leaving the instance.

## Review and share

Both designs use the same dashboard layout and carry their palette through the other LootJinx windows. Classic uses cool accents and Dungeon Journal uses warm brass tones and a WoW display font. History and Report stay in the footer alongside the **…** menu for Help and Reset.

Open the movable LootJinx settings with the dashboard gear, a right-click on the minimap icon, or **Options → AddOns → LootJinx** in WoW.

The status bar beside a run turns green while that run is live, in both Recent Runs and History. Run details show whether recorded activity counts toward the statistics.

In History, **Group by dungeon** shows expandable dungeon groups with visit counts, Need wins and the latest visit. Open **Trend** on a group to see weekly Need results for the current filters, including pending rolls and the total number of recorded rolls.

Open **Bosses** on a dungeon group to see which runs recorded a boss defeat. Expand a boss to inspect attributed drops and matching Need outcomes. Click the Need record on the dashboard to see the rolls behind the longest loss streak and the win that ended it, when recorded.

Use **Filters → Presets** to save and reuse searches, dungeon and status filters, date ranges, and sort order across characters. Open **Characters** in History to compare dungeon totals, Need results, and win rate. LootJinx records the summary locally once you log in on each character with the addon enabled.

Browse recent runs and searchable history, and open run details to see observed bosses, drops, recipients, and roll values. History opens centered over the dashboard. Drag the title bar to move either History or Run Details. Use **Filters** for date range, status, sort order, and cleanup. Use **Compare** to select two runs of the same dungeon. Known boss and trash loot is grouped by source; unlisted or ambiguous gear stays visible under **Other Loot**. Older runs without detailed data remain in history. Clicking the No Need Win, No Loot, or Since Need Win card opens the history filtered to exactly those runs; a filter chip removes the focus again.

Share a short statistics report in party or raid chat, with a selected same-faction player, or with a confirmed Battle.net friend. Settings include window scale, compact mode, record announcements, design, and language. The language defaults to your WoW client. Choose an override in LootJinx Options and confirm the reload to apply it. The override also translates class names and recognized dungeon names, and history search accepts both displayed and recorded dungeon names. Character runs are saved in `LootJinxCharDB`; display settings are saved account-wide in `LootJinxDB`.

Version 1.7.1 added smooth corner drag-resizing (40% to 300%) with right-click reset, improved legibility and contrast in both designs, and fixed raid and instance-copy detection. Version 1.6.9 continues an unfinished run when you re-enter the same dungeon within five minutes, credits uniquely attributed boss loot and the Whitemane/Mograine pair as kill evidence, opens the matching history when you click one of the three tracker cards, and lists every Need roll at the top of the run details. Reopened loot windows no longer add a second drop with an unknown recipient. Version 1.6.8 removed primary-stat detection entirely: every Need roll counts regardless of item stats, and the former Dungeon Curse card is now a Need card showing wins, losses, and pending rolls. Older saved runs are migrated automatically when loaded.

## Install

1. Copy the `LootJinx` folder to `World of Warcraft\_forever_\Interface\AddOns\LootJinx`.
2. Enter `/reload` in game.
3. Open the dashboard with `/lj`, the minimap button, or the AddOn Compartment.

After an update, the changelog opens at the first character login if that version's notes have not been shown. Open it manually under **LootJinx Settings → Changelog**. The checkbox in either window disables automatic opening account-wide. The window labels follow the addon language and the release notes use the English changelog.

## Build a release

To build the runtime ZIP from a Git checkout, run `python tools/build_changelog.py --zip`. It uses the checked-in release notes when the local `docs/CHANGELOG.md` is absent. When preparing a new release, update the version in `LootJinx.toc` and its section in `docs/CHANGELOG.md`, then run the tool to regenerate `ChangelogData.lua`. Use third-level headings such as `### Added New`, `### Changed`, `### Fixed` and `### Removed`. With the Markdown present, `--check` verifies the generated notes and `--zip` regenerates them before packaging.

## Commands

| Command | Action |
| --- | --- |
| `/lj` | Open or close the dashboard |
| `/lj options` | Open settings |
| `/lj reset` | Reset this character's statistics after confirmation |
| `/lj resetpos` | Center the dashboard |
| `/lj debug` | Open a copyable diagnostic snapshot |
| `/lj help` | Show all commands |

## Data sources and credits

The loot catalog is curated from ForeverDungeonJournal and reviewed against Wowhead Forever and [ForeverDB.net](https://foreverdb.net). The build-time importer uses the ForeverDB API for the instance list and the public dungeon pages for observed drops. Reviewed item sources are bundled with the addon.

To refresh the review snapshot, set `FOREVERDB_API_KEY` in the repository's `.env` or in your environment, then run `python tools/fetch_foreverdb_loot.py <path-to-ForeverDungeonJournal/Data/Dungeons.lua>` and `lua tools/review_foreverdb_loot.lua --all` from the repository root. The report includes dungeon loot and loot from unmatched bosses, with the evidence label from ForeverDB. Check the item pages for direct NPC sources before accepting dungeon-page observations into the catalog.

[Data from ForeverDB.net](https://foreverdb.net). The dashboard, history, and run details display a copyable link to the source.

## Detection limits

WoW Forever does not expose a combat log to addons. LootJinx combines available loot, roll, chat, and encounter events, so some drops or outcomes remain unknown. An unobserved item or boss kill is not proof that it did not happen.
