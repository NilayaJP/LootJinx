# LootJinx – Track Your Bad Loot Luck in WoW Forever

**Another dungeon with no useful drop? Another Need roll lost? LootJinx keeps score.**

LootJinx tracks your dungeon runs, Need rolls, and unlucky streaks in **World of Warcraft: Forever**. See how long your dry spell has lasted, revisit recent runs, and share the numbers with your group.

Tracking starts automatically when you enter a group or scenario instance. No external libraries or setup required.

## What LootJinx Tracks

- **Dungeon Curse:** Consecutive dungeons without an observed drop matching your specialization’s primary stat.
- **Lost Need Rolls:** Your Need wins, losses, current losing streak, and personal record. Greed rolls do not affect these statistics.
- **No Need Win:** Dungeons where you rolled Need but won nothing. A dungeon without a Need roll does not break this streak.
- **No Loot:** Dungeons where no eligible loot was observed. Quest items are excluded.
- **Since Need Win:** Dungeons since your last successful Need roll, including runs where you did not roll Need.

Each tracker shows your current streak and longest recorded streak.

## Review Your Runs

The dashboard shows your four most recent runs. Click a supported run to see its dungeon, bosses, observed drops, item recipients, and Need roll results.

Run details show equippable green-quality or better loot by boss. Eligible dungeon trash drops appear in their own section. Older runs recorded before detailed history was introduced remain in the list but have no detailed report.

If you leave and return to the **same instance copy**, LootJinx continues the run. Entering a different copy starts a new run.

## Share Your Bad Luck

Send a compact statistics report to party chat, raid chat, or a player by whisper. Open LootJinx with `/lj`, the minimap button, or the AddOn Compartment.

The dashboard supports adjustable scale, a compact mode, and a movable window. Settings are available under **ESC → Options → AddOns → LootJinx** or with `/lj options`.

## Choose Your Design

Use the **Design** dropdown in Options to switch between **Classic** and **Dungeon Journal**. Both show the same trackers and recent runs in the same layout, with a different visual style. The run detail window matches your chosen design. The choice is saved across all characters and takes effect immediately.

When a run detail window is open, pressing **ESC** closes that window first and leaves the dashboard open.

## Commands

- `/lj` — Open or close the dashboard
- `/lj options` — Open settings
- `/lj reset` — Reset this character’s statistics after confirmation
- `/lj scale 0.80–1.30` — Change dashboard scale
- `/lj resetpos` — Center the dashboard
- `/lj help` — Show all commands

## Compatibility

- **Game:** World of Warcraft: Forever
- **Interface:** 16001
- **Version:** 1.5.0
- **Languages:** English and German
- **Dependencies:** None

Forever does not expose a combat log to addons. LootJinx combines available loot, roll, chat, and encounter events; some drops or roll results may therefore be impossible to identify with certainty.

**Bad RNG happens. Now you have the numbers to prove it.**
