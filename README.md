# LootJinx

LootJinx tracks dungeon bad luck in **World of Warcraft: Forever**: lost Need rolls, unlucky streaks, missing loot, and personal records. Tracking starts automatically in dungeons, raids, and scenarios. Available in all supported client languages with five dashboard designs.

**Current version:** 1.7.6 · **Interface:** 16001 · **Dependencies:** None

## What it tracks

- **Need Rolls:** Every Need roll is counted, with wins, losses, pending rolls, the current losing streak, and the personal record. Greed does not affect these statistics.
- **No Need Win:** Dungeons where you rolled Need but won no Need roll.
- **No Loot:** Recorded dungeon visits without observed eligible loot; quest items do not count.
- **Since Need Win:** Dungeons since your last successful Need roll.

All trackers appear in all five designs. Empty visits with no observed boss, item, or roll are omitted after leaving the instance.

## Review and share

Choose a design under **Options → Design**. Every design includes its own illustration and icon, with matching headers, controls, and list colors across LootJinx windows. The dashboard keeps its position when you switch designs. History and Report stay in the footer alongside the **…** menu for Help and Reset.

- **Classic** uses cool blue and violet accents with iron dice.
- **Dungeon Journal** uses parchment and warm brass tones.
- **Goblin Betting Hall** puts the Need win rate first and styles recent runs as betting slips.
- **Dwarven Chronicle** puts three large streak cards along the top in slate and ember tones.
- **Shadow Oracle** highlights the active Need loss streak, the clickable loss record, and roll summaries in violet.

Open the movable LootJinx settings with the dashboard gear, a right-click on the minimap icon, or **Options → AddOns → LootJinx** in WoW.

The status bar beside a run turns green while that run is live, in both Recent Runs and History. Run details show whether recorded activity counts toward the statistics.

In History, **Group by dungeon** shows expandable dungeon groups with visit counts, Need wins and the latest visit. Open **Trend** on a group to see weekly Need win rates for the current filters. Each rate shows the wins and the number of resolved rolls, with pending rolls listed separately.

Open **Bosses** on a dungeon group to see which runs recorded a boss defeat. Expand a boss to inspect attributed drops and matching Need outcomes. Click the Need record on the dashboard to see the longest loss streak's date range, dungeon count, and individual rolls, including the win that ended it when recorded.

Use **Filters → Presets** to save and reuse searches, dungeon and status filters, date ranges, and sort order across characters. Open **Characters** in History to compare dungeon totals, Need results, and win rate. LootJinx records the summary locally once you log in on each character with the addon enabled.

Open **Weekly Recap** in History for runs started since Monday, their Need results, and any new Need loss streak record. Bookmark runs from their History rows and find them again under **Bookmarks** on the same character. **Need by Quality** groups wins, losses, and pending rolls for the filtered runs by item quality. Rolls without usable item quality are listed separately.

Browse recent runs and searchable history, and open run details to see bosses, drops, recipients, and roll values. History opens centered over the dashboard. Drag the title bar to move either History or Run Details. Use **Filters** for date range, status, sort order, and cleanup. Use **Compare** to select two runs of the same dungeon. Known boss and trash loot is grouped by source. A boss group marked **Loot evidence** has a recorded drop pointing to that boss. Unlisted or ambiguous gear stays visible under **Other Loot**. Older runs without detailed data remain in history. Clicking the No Need Win, No Loot, or Since Need Win card opens the history filtered to exactly those runs; a filter chip removes the focus again.

Run details show the run's duration when available, completion status, boss and loot counts, and won, lost, and pending Need rolls at the top. Click a loot group heading to collapse or expand it. Completion evidence follows the Need and loot sections.

Open **Timeline** in Run Details to play or pause the recorded events and jump to the next boss or drop. Events without usable timestamps are omitted from playback.

Share a short statistics report in party or raid chat, with a selected same-faction player, or with a confirmed Battle.net friend. Settings include window scale, compact mode, record announcements, design, and language. The language defaults to your WoW client. Choose an override in LootJinx Options and confirm the reload to apply it. The override also translates class names and recognized dungeon names, and history search accepts both displayed and recorded dungeon names. Character runs are saved in `LootJinxCharDB`; display settings are saved account-wide in `LootJinxDB`.

Under **Options → Text Size**, adjust lists, Run Details, and LootJinx tooltips separately from window scale. Click a size value to restore its default.

Automatic Battle.net targeting uses the selected character's GUID. If the client withholds it, enter the friend's BattleTag in the report window.

Version 1.7.1 added smooth corner drag-resizing (40% to 300%) with right-click reset, improved legibility and contrast in both designs, and fixed raid and instance-copy detection. Version 1.6.9 continues an unfinished run when you re-enter the same dungeon within five minutes, credits uniquely attributed boss loot and the Whitemane/Mograine pair as kill evidence, opens the matching history when you click one of the three tracker cards, and lists every Need roll at the top of the run details. Reopened loot windows no longer add a second drop with an unknown recipient. Version 1.6.8 removed primary-stat detection entirely: every Need roll counts regardless of item stats, and the former Dungeon Curse card is now a Need card showing wins, losses, and pending rolls. Older saved runs are migrated automatically when loaded.

## Install

1. Copy the `LootJinx` folder to `World of Warcraft\_forever_\Interface\AddOns\LootJinx`.
2. Enter `/reload` in game.
3. Open the dashboard with `/lj`, the minimap button, or the AddOn Compartment.

After an update, the changelog opens at the first character login or UI reload if that version's notes have not been shown. Open it manually under **LootJinx Settings → Changelog**. The checkbox in either window disables automatic opening account-wide. The window labels follow the addon language and the release notes use the English changelog.

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

Run `lua tools/review_dungeon_sources.lua <path-to-ForeverDungeonJournal/Data/Dungeons.lua>` before regenerating the catalogs. The report lists the previous and proposed sources beside each changed item ID, along with the Journal file or reviewed URL supporting the proposed sources.

The generated loot catalog includes boss NPC IDs for readable corpse sources, including rares. The completion catalog separately defines required bosses and prerequisite kills. A confirmed reset after leaving starts a new run on re-entry.

LootJinx can continue a run after a corpse run or a return to a verified instance copy for up to 30 minutes. A map ID identifies the dungeon, so a longer ordinary return also needs matching copy evidence.

The journal source review also checks faction and quest restrictions, encounter groups and linked bosses, and changes to loot availability. Run Details keep historical loot visible when DungeonJournal marks a boss's loot as temporarily unavailable. Recipes without direct source evidence do not count as boss defeats.

To refresh the review snapshot, set `FOREVERDB_API_KEY` in the repository's `.env` or in your environment, then run `python tools/fetch_foreverdb_loot.py <path-to-ForeverDungeonJournal/Data/Dungeons.lua>` and `lua tools/review_foreverdb_loot.lua --all` from the repository root. The report includes dungeon loot and loot from unmatched bosses, with the evidence label from ForeverDB. Check the item pages for direct NPC sources before accepting dungeon-page observations into the catalog.

The dashboard, history, run details, and in-game changelog credit both sources in a two-line footer. [DungeonJournal by ExehnTV](https://www.curseforge.com/wow/addons/dungeonjournal) · [Data from ForeverDB.net](https://foreverdb.net)

## Detection limits

WoW Forever does not expose a combat log to addons. LootJinx combines available loot, roll, chat, and encounter events, so some drops or outcomes remain unknown. An unobserved item or boss kill is not proof that it did not happen.
