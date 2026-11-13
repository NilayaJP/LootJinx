# Changelog

## Unreleased

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
