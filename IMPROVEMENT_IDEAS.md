# LootJinx — Improvement Ideas

Updated: 2026-11-13

These are proposals for future versions unless marked complete. LootJinx's focus remains **tracking personal dungeon and Need-roll bad luck in WoW Forever**. The searchable run history, compact chat report, detection-confidence labels, per-dungeon statistics, manual saved-data cleanup, history date filters, optional local record announcements, run stat context, and the copyable diagnostic snapshot are included in `1.6.0`.

| Priority | Idea | Player benefit | Effort |
| --- | --- | --- | --- |
| Released in 1.6.0 | Detection confidence | Understand which loot and roll results are certain | Medium |
| Released in 1.6.0 | Per-dungeon statistics | Compare loot and Need results by dungeon | Medium |
| Released in 1.6.0 | Saved-data controls | Keep long-running histories manageable | Medium–high |
| Released in 1.6.0 | History date filters | Find a run from a particular day or week | Low–medium |
| Released in 1.6.0 | New-record notifications | Notice a personal record when it happens | Low |
| Released in 1.6.0 | Diagnostic snapshot | Make missed-loot bug reports easier to investigate | Medium |
| Released in 1.6.0 | Run stat context | Understand which specialization/stat a historical run used | Medium |

## 1. Show detection confidence

**Problem:** WoW Forever does not expose every loot or roll outcome unambiguously. LootJinx sometimes verifies an unresolved Need result from bag counts, but the run detail view does not explain how certain an outcome is.

**Implemented locally:** Need results show **confirmed**, **inferred**, or **unresolved** beside the outcome, with a tooltip explaining the saved evidence source. Older results without a source show **evidence unavailable**. Drop tooltips explain the recipient evidence. This remains separate from the five curse totals.

**Done when:** A player can tell why a Need win or loss was counted, and unresolved results are never presented as confirmed. Older runs display an “evidence unavailable” state.

## 2. Add per-dungeon statistics

**Problem:** The dashboard has overall streaks, while the new history can filter runs by dungeon. It does not summarize how those runs went.

**Implemented locally:** The history summary shows run count, runs with primary-stat loot, runs without loot, and Need wins, losses, and pending results for the selected dungeon. It also follows the text search. Figures are calculated from saved runs rather than duplicate counters.

**Done when:** The figures match the filtered run list, including older records with incomplete detail data. Current/live runs are clearly identified if included.

## 3. Add saved-data controls

**Problem:** Individual runs have caps for bosses, drops, and rolls, but the number of saved runs has no cap. Long-term play can grow `LootJinxCharDB` indefinitely.

**Implemented locally:** History shows the saved run count and offers a confirmed cleanup action for completed runs older than 30 days. Cleanup removes heavy details while keeping each run's summary and ordered Need outcomes, so lifetime totals and records remain derived from the same run list. Active runs and unresolved data are skipped.

**Done when:** Cleanup explains exactly what will be removed, asks for confirmation, preserves all-time statistics, and leaves the active run untouched.

## 4. Filter history by date

**Problem:** Dungeon-name search cannot find “the run from last night” when the player does not remember the dungeon.

**Implemented locally:** History offers **Today**, **Last 7 days**, **Last 30 days**, and **All time**. The range follows local calendar days and combines with the dungeon search and filter.

**Done when:** Filtering and pagination still work together, and runs at the local midnight boundary appear in the expected range.

## 5. Announce personal records optionally

**Problem:** A new longest losing streak can happen while the dashboard is closed.

**Implemented locally:** The settings option **Announce records in chat** is off by default. When enabled, LootJinx posts one local chat line with the record name and new value. Run-based records are evaluated from closed runs, so a dungeon in progress cannot announce a premature record; a resolved Need loss is evaluated immediately. Ties and decreases update the baseline silently. No message is sent to party, raid, or whisper chat.

**Done when:** A new record triggers exactly one notification, ties do not trigger one, and the option is off by default.

## 6. Produce a diagnostic snapshot

**Problem:** Missed loot and duplicate rolls are difficult to reproduce from a description alone.

**Implemented locally:** `/lj debug` opens a copyable snapshot of the current session and run. It reports the instance-copy state, recent loot event types and counts, open Need rolls, pending item classifications, and the latest classification decisions. The report uses item IDs, roll IDs, and flags only; player names, chat text, and whisper targets are excluded. In-chat output of the same snapshot remains available from the window.

**Done when:** A player can copy a short report into an issue, and it gives enough context to distinguish event gaps from classification errors.

## 7. Keep the stat context of each run

**Problem:** Dungeon Curse depends on the player's primary stat. A historical run does not currently explain which specialization/stat was used for its classification.

**Proposal:** Store the chosen primary-stat key with each run and show it in run details. Mark older records whose original stat context cannot be reconstructed.

**Implemented locally:** Each run stores its primary-stat key and the sequence of stat changes observed while it was active. Run details show the stat context; the history marks runs without a stored context as **Stat unknown**. A specialization change updates only the active run and no longer reclassifies closed runs. Diagnostics include the stat context without player names.

**Done when:** Changing specialization later does not make an old run's classification appear to refer to the new specialization.

## Suggested order

After in-game validation of the completed items, consider the remaining ideas in priority order. All saved-data cleanup remains manual so players decide when older detail reports are removed.

## Reference points

- LootJinx: [`Diagnostics.lua`](Diagnostics.lua) builds the copyable snapshot from recent event and classification buffers; [`Tracker.lua`](Tracker.lua) records events without player names; [`Core.lua`](Core.lua) normalizes the full saved run list; [`History.lua`](History.lua) searches and paginates it.
- [PlayerTracker on CurseForge](https://www.curseforge.com/wow/addons/playertracker) shows date-range history filters and distinguishes observed from unavailable information.
- [LootTracker on CurseForge](https://www.curseforge.com/wow/addons/loottracker) uses timestamps and roll history to make results easier to inspect.
