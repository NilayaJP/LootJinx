# Changelog

## Unreleased

## 1.6.3 — 2026-11-15

- Removed the per-run drop and roll caps that discarded early boss loot in long dungeons. Restored missing keyed drops from saved Loot History rolls and observed item links on load, and recorded Loot History drops even when no earlier roll-window drop existed.
- Read the quality of newer `|cnIQ` item links when item quality data was temporarily unavailable, keeping observed boss gear such as Zul'Alai's Oathbound Bracers visible in run details.
- Included the confirmed Drowned City boss drops from DungeonJournal's later QuestUpdates data so observed items could be attributed to their bosses, including older saved runs. Matched the Deathless Guardians event to Deathless Marrow for loot grouping.
- Added a Wowhead Forever guide importer and source review for all 35 dungeons. Checked 113 boss-item references from six guides with usable loot tables among 28 fetched guides, retained DungeonJournal attribution in four conflicts, and kept dungeons without Wowhead loot data on DungeonJournal data.
- Hid fully empty dungeon visits from history, reports, and all five trackers after leaving the instance. Kept boss visits without loot in the No Loot statistic and preserved older runs without detail data.
- Updated the independent loot-source catalog from ForeverDungeonJournal 2.0.7 with 1,092 additional item-source relationships across 28 dungeons, including recipe and trash drops. Preserved all existing relationships and recorded the reviewed 2.0.7 source baseline.
- Restricted report whispers to a selected player of the same faction or a confirmed Battle.net friend. Rejected NPCs, opposite-faction strangers, and unverified character names before sending.
- Added Battle.net report whispers for an opposite-faction friend target or an entered BattleTag, with German and English target and error messages.
- Matched the observed Deathless Guardians encounter to Deathless Marrow in The Drowned City completion check.
- Combined a roll-win chat message with its matching loot receipt into one drop while keeping repeated identical drops separate.
- Labeled runs ended by an instance-copy change as ended rather than completed in run details.

## 1.6.2 — 2026-11-14

- Preserved required boss kills in long dungeons when additional optional bosses were observed, including after reload.
- Matched loot-history keys to a unique compatible drop instead of assigning them to the latest identical item.
- Separated history filter choices with identical dungeon names by instance ID and kept ambiguous legacy runs distinct.
- Excluded runs with unknown primary-stat context from Dungeon Curse totals and streaks, and labeled them as unknown in both layouts.
- Kept unresolved item classifications after a run closed so late item data could update that run.
- Stopped ordinary item-loot chat from deciding Need outcomes; retained explicit roll-win chat as direct evidence.
- Kept Need outcomes pending when bag counts or the initial item count could not be read.
- Preserved separate rapid Need choices for identical items without roll IDs while matching one chat observation to a keyed choice only once.
- Fixed ambiguous bag gains from concurrent Need and Greed rolls being recorded as Need losses.
- Preserved identical rolls on overlapping drops when chat and loot-history observations could not be matched safely; removed duplicate own Need entries from recent-roll displays.
- Fixed chat report success messages after a sending API error and added a localized failure message.
- Matched history runs by stable instance identity across client language changes while keeping distinct resolved wings separate.
- Explained why observed gear appears under Other loot in item tooltips: missing catalog, unlisted item, ambiguous sources, unobserved catalog boss, or unmatched encounter clue. Kept all drops and tracker totals unchanged.
- Added a source-data review report for boss flags, required bosses, shared-map candidates, and loot sources before regeneration. Recorded the reviewed 2.0.5 boss baseline and required `--reviewed` for both catalog generators.
- Added an optional run timeline in both detail designs using saved start, finish, boss, primary-stat, and Need-resolution times. Recorded bounded dungeon exits and confirmed same-copy returns for new runs; explained missing transition history on older runs.
- Removed timeline transitions during confirmed old-detail cleanup while preserving runs, Need outcomes, and lifetime statistics.
- Added a clickable latest-run summary to the existing footer in compact mode for Classic and Dungeon Journal. Opened legacy runs through History and kept the window height and five trackers unchanged.
- Kept primary-stat outcome labels visible beside recent roll summaries in both designs and clarified the compact-mode option text. Retained written Need and evidence labels and the detail-first Escape flow.
- Added a per-dungeon comparison for two saved runs, showing visit dates, observed primary-stat loot, Need outcomes, and completion state without adding persistent counters.
- Added History status filters for paused runs, observed boss clears, manual finishes, and pending Need results. Combined them with existing search, dungeon, date, and paging controls and added a visible filter reset.
- Kept exiting runs open for a bounded three-second event window so late final-boss kills, encounter loot, and matching rolls could reach the correct run. Rejected ambiguous carryover events during a confirmed switch to another run.
- Corrected Forever `ENCOUNTER_LOOT_RECEIVED` parsing: used its item ID and link and stopped treating the item name as a recipient or the file name as a class. Kept loot-only encounter evidence from fabricating a boss kill.
- Explained how each saved run contributes to the five trackers in recent-run and run-detail tooltips. Marked partial, paused, and manually finished runs in both dashboard designs without changing historical totals.
- Clarified the main dashboard in both designs: showed the number of runs without a primary-stat drop alongside the tracked-run total, and labeled the large Need value as lost rolls.
- Added a confirmed manual finish action to active run details in Classic and Dungeon Journal. Preserved recorded details and unresolved Need outcomes, and prevented the same instance from reopening a run until exit.
- Matched overlapping Need rolls by distinct roll IDs and loot-history keys. Left ambiguous chat roll values, outcomes, and bag evidence unresolved instead of assigning them to an arbitrary roll.
- Showed provisional instance-copy checks and confirmed same-copy or different-copy outcomes in run details and history across both designs.
- Fixed long-lived pending classifications for known non-equipment loot, including materials and consumables. Distinguished inapplicable stats from missing item data in the diagnostic snapshot.
- Reclassified pending equipment on successful Forever item-data events and retried unresolved saved items after login. Preserved historical run stat context and Need outcomes.
- Added a completion explanation to run details in both designs, showing the identified dungeon or wing, observed required-boss count, and bosses without a recorded kill event. Showed candidate wings when a shared map remains unresolved.
- Added available German dungeon and boss names to the completion explanation and kept older runs without boss evidence explicit.
- Added observed boss encounter IDs and names to the copyable diagnostic snapshot, including bosses retained in the saved run after reload.
- Verified required and rare boss entries for Razorfen Kraul and Scarlet Monastery: Graveyard against Wowhead Forever and observed client events. Kept unknown encounter names unmatched.
- Regenerated completion data for all 35 dungeons with available German boss names from ForeverDungeonJournal 2.0.5 and reviewed combined encounter labels against Wowhead Forever.
- Excluded four documented optional bosses from completion, grouped the mutually exclusive Blackrock Depths arena opponents, and credited Sneed's Shredder when the observed Sneed kill implies it.
- Fixed missing canonical aliases for grouped encounters such as The Lost Dwarves and Morphaz & Hazzas.

## 1.6.1 — 2026-11-14

- Added a separate required-boss table for all 35 cataloged dungeons, generated from ForeverDungeonJournal 2.0.5. Excluded rare spawns and trash; kept the existing loot-source catalog independent.
- Resolved shared instance maps to a specific dungeon wing from observed boss kills, including Scarlet Monastery. Left ambiguous or incomplete boss evidence paused.
- Closed completed runs when the player left the dungeon after every required boss was observed killed. Kept the run open through the final boss's loot and rolls.
- Fixed stale runs remaining paused after a long login gap outside their dungeon. Preserved short reconnects and same-copy continuation.

## 1.6.0 — 2026-11-13

- Updated the independent loot catalog from DungeonJournal 2.0.5, adding 30 boss and trash item-source entries across Excavation Site: Wetlands, City of Dalaran, Razorfen Downs, Zul'Farrak, and Sunken Temple. Added source-version detection to the catalog generator.
- Added an independent dungeon loot catalog for boss and trash attribution, based on reviewed DungeonJournal item IDs. Kept unlisted observed gear visible under Other Loot and stopped assigning drops to the last boss solely by time.
- Stored the primary-stat context with each run and showed it in run details, including a marker when the stat changed during the run. Marked older runs without a stored context as unknown and stopped reclassifying them with the current specialization.
- Used `C_LootHistory` as an optional source for per-player roll values on encounter loot, with loot-chat parsing as fallback. Listed observed Need, Greed, and Transmog values in run-detail item tooltips and kept rolls for identical drops separate.
- Extended `/lj debug` with a copyable diagnostic snapshot of the current run: instance-copy state, recent loot event types, open Need rolls, pending classifications, and the latest item-classification decisions. The snapshot uses IDs and flags only and excludes player names, chat text, and whisper targets. The window follows the active Classic or Journal design and scrolls long reports.
- Added an opt-in, local-only chat notice for new personal records, disabled by default; ties do not trigger a notice.
- Added the latest observed personal and other-player Need values to Recent Runs in both designs, with per-item roll values and players in the hover tooltip.
- Added a searchable, paginated history of all saved dungeon runs with a dungeon filter, accessible from both designs and compact mode.
- Enabled opening run details from history and closing the detail window, history, and dashboard in order with ESC.
- Shortened and numbered the shared chat report lines so the five trackers read as a compact block, with less delay between lines.
- Added evidence labels and explanations for Need results and drop recipients in run details, including clear states for inferred, unresolved, and older entries without a saved source.
- Added a history summary for the selected dungeon or search, showing primary-stat loot runs, no-loot runs, and Need outcomes.
- Added a confirmed cleanup action for completed run details older than 30 days, while preserving saved runs, Need outcomes, and lifetime statistics.
- Added local-calendar date filters for Today, Last 7 days, Last 30 days, and All time to the run history; they combine with dungeon search and filtering.

## 1.5.0 — 2026-11-13

- Added a Design dropdown in Options to switch between Classic and Dungeon Journal. The selected design takes effect immediately and is saved account-wide; Classic remains the default.
- Added the Dungeon Journal visual style to the existing dashboard layout, including the five trackers, recent runs, sharing controls, and a matching run detail window.
- Kept run details open in their selected style and made ESC close only the detail window first; a second ESC closes the dashboard.
- Shared report building and sending across both designs, so party, raid, and whisper reports use the same statistics.
- Updated the CurseForge description and repository README for both designs.

## 1.4.1 — 2026-11-13

- Kept loot from a returning dungeon run separate until its instance copy is identified. If the copy matches, the provisional loot joins the original run; otherwise it stays in a new run.
- Showed equippable dungeon trash drops in their own section without assigning them to the last boss. Quest items, gems, and gray or white items remain excluded from run details.
- Preserved repeated drops and Need rolls for identical items, with each drop showing its matching Need result.
- Fixed item class detection against the current WoW Forever API and added scenario run tracking.

## 1.4.0 — 2026-11-13

- Updated runs to continue automatically when you return to the same dungeon instance. Entering a different instance copy starts a new run. The exit prompt and 15-minute timeout were removed.
- Excluded non-equippable items such as The Scarlet Key and Citrine, as well as gray and white items, from run details.
- Fixed the "Since last Need win" counter showing dungeon runs before the first Need roll.
