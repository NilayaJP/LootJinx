# LootJinx — Improvement Ideas

Updated: 2026-11-13

These are proposals for future versions, not implemented features. LootJinx's focus remains **tracking personal dungeon and Need-roll bad luck in WoW Forever**. The searchable run history and compact chat report are already present in the local `1.6.0-dev` build.

| Priority | Idea | Player benefit | Effort |
| --- | --- | --- | --- |
| 1 | Detection confidence | Understand which loot and roll results are certain | Medium |
| 2 | Per-dungeon statistics | See where unlucky streaks happen most often | Medium |
| 3 | Saved-data controls | Keep long-running histories manageable | Medium–high |
| 4 | History date filters | Find a run from a particular day or week | Low–medium |
| 5 | New-record notifications | Notice a personal record when it happens | Low |
| 6 | Diagnostic snapshot | Make missed-loot bug reports easier to investigate | Medium |
| 7 | Run stat context | Understand which specialization/stat a historical run used | Medium |

## 1. Show detection confidence

**Problem:** WoW Forever does not expose every loot or roll outcome unambiguously. LootJinx sometimes verifies an unresolved Need result from bag counts, but the run detail view does not explain how certain an outcome is.

**Proposal:** Mark each observed result as **confirmed**, **inferred**, or **unresolved**, and show a short explanation in the run detail tooltip. Store the evidence source with the result. Keep this separate from the five curse totals so the current definitions stay understandable.

**Done when:** A player can tell why a Need win or loss was counted, and unresolved results are never presented as confirmed. Older runs display an “evidence unavailable” state.

## 2. Add per-dungeon statistics

**Problem:** The dashboard has overall streaks, while the new history can filter runs by dungeon. It does not summarize how those runs went.

**Proposal:** For the selected dungeon, show run count, primary-stat drops, Need wins/losses, and no-loot runs. Calculate these from saved runs rather than maintaining duplicate counters.

**Done when:** The figures match the filtered run list, including older records with incomplete detail data. Current/live runs are clearly identified if included.

## 3. Add saved-data controls

**Problem:** Individual runs have caps for bosses, drops, and rolls, but the number of saved runs has no cap. Long-term play can grow `LootJinxCharDB` indefinitely.

**Proposal:** Show the number of saved runs and offer an explicit cleanup action for old run details. Preserve lifetime totals and records before any pruning; today, statistics are computed from the run list, so deleting runs directly would change the displayed all-time numbers.

**Done when:** Cleanup explains exactly what will be removed, asks for confirmation, preserves all-time statistics, and leaves the active run untouched.

## 4. Filter history by date

**Problem:** Dungeon-name search cannot find “the run from last night” when the player does not remember the dungeon.

**Proposal:** Add simple date ranges such as **Today**, **Last 7 days**, **Last 30 days**, and **All time** to the existing history. Combine the range with the dungeon search and filter.

**Done when:** Filtering and pagination still work together, and runs at the local midnight boundary appear in the expected range.

## 5. Announce personal records optionally

**Problem:** A new longest losing streak can happen while the dashboard is closed.

**Proposal:** Add an opt-in, local-only chat notification when a personal record is exceeded. Show the record name and new value once per change. Do not post automatically to party or raid chat.

**Done when:** A new record triggers exactly one notification, ties do not trigger one, and the option is off by default.

## 6. Produce a diagnostic snapshot

**Problem:** Missed loot and duplicate rolls are difficult to reproduce from a description alone.

**Proposal:** Extend `/lj debug` with a concise snapshot of the current run: instance-copy state, recent loot event types, pending rolls, and the last item-classification decisions. Avoid including player names or whisper targets in text intended for sharing.

**Done when:** A player can copy a short report into an issue, and it gives enough context to distinguish event gaps from classification errors.

## 7. Keep the stat context of each run

**Problem:** Dungeon Curse depends on the player's primary stat. A historical run does not currently explain which specialization/stat was used for its classification.

**Proposal:** Store the chosen primary-stat key with each run and show it in run details. Mark older records whose original stat context cannot be reconstructed.

**Done when:** Changing specialization later does not make an old run's classification appear to refer to the new specialization.

## Suggested order

Start with **detection confidence**, then **per-dungeon statistics**. These make the existing history more trustworthy and useful. Plan **saved-data controls** before the history becomes large; they need special care because lifetime statistics currently depend on saved runs.

## Reference points

- LootJinx: [`Tracker.lua`](Tracker.lua) limits details per run; [`Core.lua`](Core.lua) normalizes the full saved run list; [`History.lua`](History.lua) searches and paginates it.
- [PlayerTracker on CurseForge](https://www.curseforge.com/wow/addons/playertracker) shows date-range history filters and distinguishes observed from unavailable information.
- [LootTracker on CurseForge](https://www.curseforge.com/wow/addons/loottracker) uses timestamps and roll history to make results easier to inspect.
