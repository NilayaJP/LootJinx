# Changelog

## Unreleased

- Add a searchable, paginated history of all saved dungeon runs with a dungeon filter, accessible from both designs and compact mode.
- Open existing run details from history and close detail, history, and dashboard in order with ESC.
- Shorten and number the shared chat report lines so the five trackers read as a compact block, with less delay between lines.

## 1.5.0 — 2026-11-13

- Add a Design dropdown in Options to switch between Classic and Dungeon Journal. The selected design takes effect immediately and is saved account-wide; Classic remains the default.
- Add the Dungeon Journal visual style to the existing dashboard layout, including the five trackers, recent runs, sharing controls, and a matching run detail window.
- Keep run details open in their selected style and close only the detail window when ESC is pressed; a second ESC closes the dashboard.
- Share report building and sending across both designs, so party, raid, and whisper reports use the same statistics.
- Update the CurseForge description and repository README for both designs.

## 1.4.1 — 2026-11-13

- Keep loot from a returning dungeon run separate until its instance copy is identified. If the copy matches, the provisional loot joins the original run; otherwise it stays in a new run.
- Show equippable dungeon trash drops in their own section without assigning them to the last boss. Quest items, gems, and gray or white items remain excluded from run details.
- Preserve repeated drops and Need rolls for identical items, with each drop showing its matching Need result.
- Fix item class detection against the current WoW Forever API and track scenario runs.

## 1.4.0 — 2026-11-13

- Runs now continue automatically when you return to the same dungeon instance. Entering a different instance copy starts a new run. The exit prompt and 15-minute timeout have been removed.
- Run details now exclude non-equippable items such as The Scarlet Key and Citrine, as well as gray and white items.
- Fixed the "Since last Need win" counter showing dungeon runs before the first Need roll.
