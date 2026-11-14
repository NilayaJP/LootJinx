# LootJinx — Improvement Ideas

Updated: 2026-11-14

These are proposals, not promised features. LootJinx tracks personal dungeon loot and Need-roll luck in WoW Forever. Client events can be absent or ambiguous; new detection rules must preserve unknown results.

## Shipped baseline

Version 1.6.0 added searchable history, date filters, per-dungeon summaries, manual detail cleanup, evidence labels, optional record announcements, run stat context, a diagnostic snapshot, and the independent loot-source catalog. Version 1.6.1 added a separate required-boss table for all 35 cataloged dungeons and closed complete runs on exit. Rares are excluded; incomplete or ambiguous boss evidence leaves the run paused. See [Changelog](CHANGELOG.md).

## Priority 1 — Explain run completion

**Problem:** A paused run gives no player-facing reason why the boss check did not close it. Shared maps and missing boss events make this confusing.

**Proposal:** Show resolved wing, observed required-boss count, and missing bosses in run details. Keep the copyable diagnostic snapshot privacy-safe. Do not claim an unobserved boss was defeated.

**Done when:** Players can distinguish an incomplete run, a missing event, and an unresolved wing in both designs.

**Progress:** Both run-detail designs now show the candidate dungeon or wing, observed required-boss count, and the names without recorded kill events. Shared maps with no unique candidate show each wing's count. The UI explicitly says that an unobserved event cannot distinguish a living boss from a missed client event; no inferred kill is claimed.

## Priority 2 — Validate boss names in the client

**Problem:** The 1.6.1 table came from ForeverDungeonJournal 2.0.5, while `BOSS_KILL` and `ENCOUNTER_END` can use localized or differing names.

**Proposal:** Gather privacy-safe encounter IDs and names from German and English client runs. Review mismatches against source data, add aliases only with evidence, and audit rare and optional classifications before regenerating the table.

**Done when:** Representative ordinary and shared-map dungeons resolve without false closes; unknown names remain unmatched.

**Progress:** All 35 completion entries were regenerated from ForeverDungeonJournal 2.0.5 with available German boss names and compared with Wowhead Forever dungeon-journal entries where published. The generator now excludes documented optional bosses as well as rares and summons, groups the six mutually exclusive Blackrock Depths arena opponents, and handles confirmed combined encounter labels. Automated checks cover every dungeon with a complete and an incomplete boss set. Saved English encounter IDs and names from Razorfen Kraul and Scarlet Monastery matched. `/lj debug` exposes saved IDs and names for future reports. This is a source-data audit; live German event names and dungeons without a published Wowhead journal still need client evidence. Unknown names remain unmatched.

## Priority 3 — Manual run finish

**Status:** Implemented on the feature branch. Client UI behavior remains to be checked in WoW Forever.

**Implemented:** Active run details in Classic and Dungeon Journal show a confirmed Finish run action. A manual close records its own reason, retains saved bosses, drops, and Need outcomes, and leaves pending Needs unknown. Closing inside an instance suppresses a new run for that instance until exit, including across a reload. The history and run details identify manually finished runs.

**Problem:** The six-hour outside fallback cannot prove when a player abandoned a dungeon.

**Proposal:** Add an optional, confirmed **Finish run** action with a distinct manual close reason. Preserve run details and Need outcomes.

**Done when:** Both designs provide confirmation; the action never silently resets statistics.

## Priority 4 — Pending item classification

**Problem:** Snapshots can show many long-lived pending classifications even when item data exists.

**Proposal:** Audit `C_Item.GetItemStats` for non-equippable materials. Distinguish "stat not applicable" from "item data unavailable" and reclassify on verified item-data events. Keep repeated drops distinct and historical stat context unchanged.

**Done when:** Known materials do not stay pending indefinitely, and primary-stat streaks remain stable.

**Progress:** Known non-equipment classes now receive an explicit not-applicable stat state. Equipment without a stat table remains pending until item data is cached; successful `GET_ITEM_INFO_RECEIVED` and `ITEM_DATA_LOAD_RESULT` events trigger reclassification. On login, saved pending items are checked and unresolved item data is requested again. Old runs without a stored stat context only clear items proven stat-free. Stub regressions cover materials, uncached equipment, empty stat tables, failed and successful events, and historical stat preservation. Client behavior remains to be checked in game.

## Priority 5 — Backup and migration guidance

**Problem:** Players fear losing history when switching from a manual install to CurseForge.

**Proposal:** Document WoW Forever `WTF/Account/.../SavedVariables/LootJinx.lua` backups with the game closed. Explain that deleting addon code differs from `/lj reset`. Consider in-addon export only if file backups prove insufficient.

**Done when:** The upgrade retains `LootJinxDB` settings and `LootJinxCharDB` runs.

## Priority 6 — Release consistency

**Problem:** GitHub, CurseForge, installed metadata, and descriptions can diverge.

**Proposal:** Use a checklist for `.toc` and `Core.lua` versions, English changelog, description, tests, zip contents, GitHub release, and CurseForge upload. Keep CurseForge publication manual unless explicitly requested.

**Done when:** Published description and version match the uploaded archive.

## Priority 7 — Match repeated Need rolls more precisely

**Status:** Implemented on `feature/boss-name-validation` in commit `5bb9c36`. The WoW Forever client behavior remains to be checked.

**Implemented:** Distinct roll IDs now create distinct Need entries, while repeated events for the same roll ID reuse the entry. Loot-history rolls use their history key and the associated drop's roll ID to find the matching Need entry. Chat roll values, chat outcomes, and bag evidence remain unassigned when multiple overlapping Need rolls could match. Greed rolls do not receive a Need roll value. Focused local checks cover repeated items, duplicate events, reversed history-event order, missing values, and overlapping Need and Greed.

**Problem:** Several rolls for the same item can overlap, while chat and loot-history events arrive in different orders.

**Proposal:** Match by available roll ID, history key, item, player, and time window in that order. Record ambiguous matches as unresolved instead of assigning one result to several rolls.

**Done when:** Focused tests cover identical items, duplicate events, unknown roll values, and simultaneous Need and Greed without changing Need statistics incorrectly.

## Priority 8 — Make copy detection visible

**Status:** Implemented on `feature/boss-name-validation` in commit `5bb9c36`. The WoW Forever client display remains to be checked.

**Implemented:** A provisional re-entry shows "Checking copy" in the Classic status and history, and the checking state appears in Journal and run details. The same-copy path merges the provisional run only after matching GUID evidence and records "Same copy"; the different-copy path keeps both runs and records "Different copy". The outcome survives saved-data reload. Local checks cover both paths and the run-detail designs.

**Problem:** After re-entry, a provisional run may wait for a Creature or Cast GUID. Players cannot tell why two entries briefly appear.

**Proposal:** Show a restrained "checking instance copy" status and merge outcome in run details and history. Do not merge drops before copy evidence arrives.

**Done when:** Same-copy and different-copy paths remain distinct after reload and in both UI designs.

## Priority 9 — Handle late boss and loot events

**Status:** Implemented on the feature branch with a bounded exit window. Real client event ordering remains to be checked in WoW Forever.

**Implemented:** Leaving an instance starts a three-second settling window before the completion check closes the run. Boss kills, encounter loot, and matching chat or loot-history rolls observed in that window stay with the exiting run. Events arriving during an immediate transition to another run are held out of the new run when their source cannot be established safely. Diagnostics record the transition and skipped late events without chat text or player names. Forever's encounter-loot payload is parsed by item ID and link; its item name no longer becomes a guessed recipient, and loot-only evidence cannot count as a boss kill. Focused local checks cover late final-boss evidence, closure after the window, and an immediate dungeon switch.

**Problem:** Instance transitions and loading screens can reorder the last boss, loot, and zone events.

**Proposal:** Capture real event sequences in diagnostics, then adjust only the observed race. Avoid a blanket delay that keeps completed runs open indefinitely.

**Done when:** Final-boss loot and rolls survive exit, and a later event cannot attach to the wrong run.

## Priority 10 — Explain incomplete runs in statistics

**Status:** Implemented on the feature branch. Client tooltip placement remains to be checked in WoW Forever.

**Implemented:** Classic and Dungeon Journal mark active, paused, partial, and manually finished recent runs. Hovering a recent run or the run-detail summary shows its contribution to each of the five trackers, including confirmed Need losses, pending outcomes, and whether the since-win counter increments or resets. All five tracker cards explain how unfinished runs are included. Historical totals and formulas remain unchanged.

**Problem:** A paused, partial, or manually closed run can affect streak interpretation differently from a fully observed clear.

**Proposal:** Add concise status markers and a tooltip explaining inclusion in each tracker. Keep historical totals stable unless a separate migration is reviewed.

**Done when:** The five tracker values have an understandable run-by-run basis in Classic and Dungeon Journal.

## Priority 11 — Compare runs of one dungeon

**Status:** Implemented on the feature branch. Client layout remains to be checked in WoW Forever.

**Implemented:** Each history row offers a Compare selection. Selecting two visits to the same dungeon, including visits on different pages, opens a side-by-side view of date, observed primary-stat loot, won/lost/pending Need outcomes, and completion state. Older runs without primary-stat context show an unknown state; no new saved counter is added.

**Problem:** The history summary aggregates runs but makes variation between repeated visits hard to see.

**Proposal:** Add an optional per-dungeon comparison of dates, observed stat loot, Need outcomes, and completion state using existing saved runs.

**Done when:** A player can compare two visits without a new permanent counter or guessed missing data.

## Priority 12 — Improve history filtering

**Status:** Implemented on the feature branch. Client layout remains to be checked in WoW Forever.

**Implemented:** History now filters paused runs, observed required-boss clears, manual finishes, and runs with pending Need results. The status filter combines with name search, dungeon, and local-day date ranges; counts and paging use the combined result. A visible reset clears all filters and comparison selections.

**Problem:** Name and date filters cannot directly find paused runs, clears, or runs with unresolved Needs.

**Proposal:** Add a small status filter with clear combinations and a visible reset control. Preserve current paging behavior.

**Done when:** Search, dungeon, date, and status filters combine predictably and show the filtered count.

## Priority 13 — Add a session timeline

**Status:** Implemented on the feature branch. Client layout and transition events remain to be checked in WoW Forever.

**Implemented:** A Details/Timeline toggle in the shared run-detail window works in Classic and Dungeon Journal. The timeline orders saved start, end, boss, primary-stat, and resolved Need timestamps. New runs save only exits and confirmed same-copy returns in a capped 24-entry transition list; older runs explicitly state that earlier transitions were not recorded. The view limits visible events and marks omissions. Confirmed cleanup of old run details also removes the transition list.

**Problem:** A run detail shows bosses and drops but not the sequence of exits, re-entries, and evidence updates.

**Proposal:** Show a compact, optional timeline from timestamps already saved. Add new persisted events only after assessing saved-data growth.

**Done when:** The timeline explains run continuity without duplicating the diagnostic log or inventing precise timestamps for legacy runs.

## Priority 14 — Improve accessibility and readability

**Status:** Implemented on the feature branch. Contrast, focus, and text clipping need a final client check at 80% scale.

**Implemented:** Recent-run roll values retain an explicit with/without primary-stat label in both designs. Run details continue to show written Need outcomes and evidence levels, while recent-run status markers and tooltips explain completion and tracker contribution. Stub checks cover the 80% layout and the existing detail-first ESC order in Classic and Dungeon Journal.

**Problem:** Color alone can make Need outcomes and evidence confidence difficult to distinguish.

**Proposal:** Pair colors with short text labels, review contrast at supported scales, and keep focus and ESC behavior consistent in both designs.

**Done when:** Status and outcome remain understandable without color and at 80% UI scale.

## Priority 15 — Make compact mode more useful

**Status:** Implemented on the feature branch. Client spacing and click behavior remain to be checked in WoW Forever.

**Implemented:** The existing footer space now shows one clickable latest-run line with its dungeon and completion status in both designs. It opens run details, or History for an older run without details. The compact window remains 476 units high; the five tracker cards and full-size layout keep their positions.

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
