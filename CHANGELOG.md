# Changelog

## Unreleased

## 1.6.1 — 2026-11-14

- Closed runs on dungeon exit after all required bosses for a resolved dungeon or wing were observed killed; excluded rare spawns and retained incomplete runs as paused.
- Fixed stale runs remaining paused after a long login gap outside their dungeon. Short reconnects and zone changes still use the instance-copy check.

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
