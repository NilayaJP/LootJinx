# Changelog

## 1.4.1 — 2026-11-13

- Keep loot from a returning dungeon run separate until its instance copy is identified. If the copy matches, the provisional loot joins the original run; otherwise it stays in a new run.
- Show equippable dungeon trash drops in their own section without assigning them to the last boss. Quest items, gems, and gray or white items remain excluded from run details.
- Preserve repeated drops and Need rolls for identical items, with each drop showing its matching Need result.
- Fix item class detection against the current WoW Forever API and track scenario runs.

## 1.4.0 — 2026-11-13

- Runs now continue automatically when you return to the same dungeon instance. Entering a different instance copy starts a new run. The exit prompt and 15-minute timeout have been removed.
- Run details now exclude non-equippable items such as The Scarlet Key and Citrine, as well as gray and white items.
- Fixed the "Since last Need win" counter showing dungeon runs before the first Need roll.
