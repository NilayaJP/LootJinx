# LootJinx — Improvement Ideas

Updated: 2026-11-14

These are proposals, not promised features. LootJinx tracks personal dungeon loot and Need-roll luck in WoW Forever. Client events can be absent or ambiguous; new detection rules must preserve unknown results.

## Shipped baseline

Version 1.6.0 added searchable history, date filters, per-dungeon summaries, manual detail cleanup, evidence labels, optional record announcements, run stat context, a diagnostic snapshot, and the independent loot-source catalog. Version 1.6.1 added a separate required-boss table for all 35 cataloged dungeons and closed complete runs on exit. Rares are excluded; incomplete or ambiguous boss evidence leaves the run paused. See [Changelog](CHANGELOG.md).

## Priority 1 — Explain run completion

**Problem:** A paused run gives no player-facing reason why the boss check did not close it. Shared maps and missing boss events make this confusing.

**Proposal:** Show resolved wing, observed required-boss count, and missing bosses in run details. Keep the copyable diagnostic snapshot privacy-safe. Do not claim an unobserved boss was defeated.

**Done when:** Players can distinguish an incomplete run, a missing event, and an unresolved wing in both designs.

## Priority 2 — Validate boss names in the client

**Problem:** The 1.6.1 table came from ForeverDungeonJournal 2.0.5, while `BOSS_KILL` and `ENCOUNTER_END` can use localized or differing names.

**Proposal:** Gather privacy-safe encounter IDs and names from German and English client runs. Review mismatches against source data, add aliases only with evidence, and audit rare and optional classifications before regenerating the table.

**Done when:** Representative ordinary and shared-map dungeons resolve without false closes; unknown names remain unmatched.

**Progress:** All 35 completion entries were regenerated from ForeverDungeonJournal 2.0.5 with available German boss names and compared with Wowhead Forever dungeon-journal entries where published. The generator now excludes documented optional bosses as well as rares and summons, groups the six mutually exclusive Blackrock Depths arena opponents, and handles confirmed combined encounter labels. Automated checks cover every dungeon with a complete and an incomplete boss set. Saved English encounter IDs and names from Razorfen Kraul and Scarlet Monastery matched. `/lj debug` exposes saved IDs and names for future reports. This is a source-data audit; live German event names and dungeons without a published Wowhead journal still need client evidence. Unknown names remain unmatched.

## Priority 3 — Manual run finish

**Problem:** The six-hour outside fallback cannot prove when a player abandoned a dungeon.

**Proposal:** Add an optional, confirmed **Finish run** action with a distinct manual close reason. Preserve run details and Need outcomes.

**Done when:** Both designs provide confirmation; the action never silently resets statistics.

## Priority 4 — Pending item classification

**Problem:** Snapshots can show many long-lived pending classifications even when item data exists.

**Proposal:** Audit `C_Item.GetItemStats` for non-equippable materials. Distinguish "stat not applicable" from "item data unavailable" and reclassify on verified item-data events. Keep repeated drops distinct and historical stat context unchanged.

**Done when:** Known materials do not stay pending indefinitely, and primary-stat streaks remain stable.

## Priority 5 — Backup and migration guidance

**Problem:** Players fear losing history when switching from a manual install to CurseForge.

**Proposal:** Document WoW Forever `WTF/Account/.../SavedVariables/LootJinx.lua` backups with the game closed. Explain that deleting addon code differs from `/lj reset`. Consider in-addon export only if file backups prove insufficient.

**Done when:** The upgrade retains `LootJinxDB` settings and `LootJinxCharDB` runs.

## Priority 6 — Release consistency

**Problem:** GitHub, CurseForge, installed metadata, and descriptions can diverge.

**Proposal:** Use a checklist for `.toc` and `Core.lua` versions, English changelog, description, tests, zip contents, GitHub release, and CurseForge upload. Keep CurseForge publication manual unless explicitly requested.

**Done when:** Published description and version match the uploaded archive.

## Priority 7 — Match repeated Need rolls more precisely

**Problem:** Several rolls for the same item can overlap, while chat and loot-history events arrive in different orders.

**Proposal:** Match by available roll ID, history key, item, player, and time window in that order. Record ambiguous matches as unresolved instead of assigning one result to several rolls.

**Done when:** Focused tests cover identical items, duplicate events, unknown roll values, and simultaneous Need and Greed without changing Need statistics incorrectly.

## Priority 8 — Make copy detection visible

**Problem:** After re-entry, a provisional run may wait for a Creature or Cast GUID. Players cannot tell why two entries briefly appear.

**Proposal:** Show a restrained "checking instance copy" status and merge outcome in run details and history. Do not merge drops before copy evidence arrives.

**Done when:** Same-copy and different-copy paths remain distinct after reload and in both UI designs.

## Priority 9 — Handle late boss and loot events

**Problem:** Instance transitions and loading screens can reorder the last boss, loot, and zone events.

**Proposal:** Capture real event sequences in diagnostics, then adjust only the observed race. Avoid a blanket delay that keeps completed runs open indefinitely.

**Done when:** Final-boss loot and rolls survive exit, and a later event cannot attach to the wrong run.

## Priority 10 — Explain incomplete runs in statistics

**Problem:** A paused, partial, or manually closed run can affect streak interpretation differently from a fully observed clear.

**Proposal:** Add concise status markers and a tooltip explaining inclusion in each tracker. Keep historical totals stable unless a separate migration is reviewed.

**Done when:** The five tracker values have an understandable run-by-run basis in Classic and Dungeon Journal.

## Priority 11 — Compare runs of one dungeon

**Problem:** The history summary aggregates runs but makes variation between repeated visits hard to see.

**Proposal:** Add an optional per-dungeon comparison of dates, observed stat loot, Need outcomes, and completion state using existing saved runs.

**Done when:** A player can compare two visits without a new permanent counter or guessed missing data.

## Priority 12 — Improve history filtering

**Problem:** Name and date filters cannot directly find paused runs, clears, or runs with unresolved Needs.

**Proposal:** Add a small status filter with clear combinations and a visible reset control. Preserve current paging behavior.

**Done when:** Search, dungeon, date, and status filters combine predictably and show the filtered count.

## Priority 13 — Add a session timeline

**Problem:** A run detail shows bosses and drops but not the sequence of exits, re-entries, and evidence updates.

**Proposal:** Show a compact, optional timeline from timestamps already saved. Add new persisted events only after assessing saved-data growth.

**Done when:** The timeline explains run continuity without duplicating the diagnostic log or inventing precise timestamps for legacy runs.

## Priority 14 — Improve accessibility and readability

**Problem:** Color alone can make Need outcomes and evidence confidence difficult to distinguish.

**Proposal:** Pair colors with short text labels, review contrast at supported scales, and keep focus and ESC behavior consistent in both designs.

**Done when:** Status and outcome remain understandable without color and at 80% UI scale.

## Priority 15 — Make compact mode more useful

**Problem:** Compact mode hides Recent Runs, requiring a separate history window for the latest result.

**Proposal:** Test a single-line latest-run summary or quick history link within the existing compact height. Keep the five trackers prominent.

**Done when:** The newest run remains accessible without crowding or changing full-size layout.

## Priority 16 — Explain unknown loot attribution

**Problem:** "Other Loot" combines uncataloged items, ambiguous boss sources, and unassigned observed gear.

**Proposal:** Add tooltip explanations for the attribution reason while keeping all observed items visible. Do not treat the loot catalog as a drop whitelist.

**Done when:** Players know why an item lacks a boss label without losing repeated drops.

## Priority 17 — Review source-data updates safely

**Problem:** DungeonJournal updates can change boss names, rare flags, and loot sources independently.

**Proposal:** Produce a review report before regenerating either catalog: added/removed bosses, changed rare flags, shared-map candidates, and item-source differences. Require explicit review before committing generated Lua.

**Done when:** Data changes are inspectable and do not silently alter old run history or completion rules.

## Priority 18 — Validate saved-data migration

**Problem:** Older runs lack detail markers, stat context, or newer roll evidence.

**Proposal:** Keep fixtures from several historical versions and test normalization, totals, and cleanup after each schema change. Preserve unknown fields conservatively.

**Done when:** Loading older `LootJinxCharDB` data never fabricates a boss kill, recipient, roll value, or primary stat.

## Priority 19 — Add a small in-client test checklist

**Problem:** Lua stubs prove logic but cannot prove that Forever emits every expected event.

**Proposal:** Maintain a reproducible checklist for fresh run, full clear, rare spawn, shared wing, short reconnect, logout outside, duplicate item roll, and both designs. Record client build and diagnostic snapshot for failures.

**Done when:** Each release has documented client observations separate from stub-test results.

## Priority 20 — Keep installation paths explicit

**Problem:** Editing the source tree does not update the installed `_forever_` addon, and `/reload` reads only the installed files.

**Proposal:** Add a local deployment check that copies only `.toc`, Lua modules, and media to the selected Forever AddOns path and verifies file hashes. Keep it opt-in and never touch `WTF` saved data.

**Done when:** The installed version and source version match before a client test, without accidentally deleting character history.

## Guardrails

- Keep loot attribution independent from required-boss completion.
- Preserve older runs and saved variables; missing values stay unknown.
- Verify tracker, roll, and run-continuity changes with focused regressions and client checks.

## Code reference

[`Tracker.lua`](../Tracker.lua) records events; [`DungeonCompletion.lua`](../DungeonCompletion.lua) checks required bosses; [`DungeonCompletionData.lua`](../DungeonCompletionData.lua) contains generated reference data; [`Diagnostics.lua`](../Diagnostics.lua) builds the snapshot; [`Core.lua`](../Core.lua) normalizes saved runs.
