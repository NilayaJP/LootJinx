# LootJinx Dungeon Journal Preview

## Intent

Build the selected **Dungeon Journal** layout as a second in-game view so the owner can compare it with the current dashboard locally. The current dashboard stays the default. This preview is not a CurseForge release; after testing, the owner will choose one final design for a later release.

## Goals and boundaries

- Keep the existing dashboard functional and visually unchanged.
- Add a complete Dungeon Journal layout with WoW-style dark leather, aged metal, warm gold, vertical register tabs, a prominent latest run, and a right-hand record column. Use existing TGA artwork and WoW frame APIs; the browser concept is a direction, not a pixel-perfect asset.
- Show the same tracked statistics and recent runs in both layouts. Clicking a recent run opens the existing Run Details view.
- Offer a development-only layout choice in Options: **Classic** (default) or **Dungeon Journal**. Switching takes effect immediately and persists account-wide across reloads. Only one main dashboard is visible at a time.
- Keep `/lj`, minimap left click, AddOn Compartment, scale, position reset, report sharing, and character reset working with the active layout.
- Make no change to loot detection, run records, or character SavedVariables. Do not publish this preview to CurseForge or push it to `origin/main`.

## Approaches considered

1. **Separate Journal view with shared data and actions (chosen).** Add a Journal UI module and route dashboard actions to the selected view. The existing view remains independently testable. This costs more UI code but keeps experimental layout changes away from the stable layout.
2. **Rearrange the existing frame on every selection.** Fewer frames, but most existing widgets use fixed anchors and sizes. Reversing all layout changes on a switch would risk altering the classic view.
3. **Separate addon package.** Strong isolation, but duplicates the database and installation and makes side-by-side testing awkward.

## In-game design

The selected concept has this visual hierarchy (approximately 760 × 520 game UI units at 100% scale):

```text
╔════════╦══════════════════════════════════════╦══════════════════╗
║ RUNS   ║ Wailing Caverns                      ║ Current Records  ║
║ CURSES ║ Latest dungeon run · Need roll lost  ║ Lost Need      7  ║
║ RECORDS║                                      ║ No Need Win    3  ║
║ SHARE  ║ [CurseChest art]  Dungeon Curse  4    ║ No Loot        2  ║
║        ║                  no stat drop streak  ║ Since Win      5  ║
║        ║                                      ║ Longest Curse  9  ║
║        ║ Recent runs · clickable rows         ║                  ║
╚════════╩══════════════════════════════════════╩══════════════════╝
```

Use a narrow register rail (about 10% of the width), a broad content page (about 60%), and a record column (about 30%). Frame: charcoal leather (`#241a1a`) with aged bronze border (`#8b6244`); rail: brown leather (`#49302d`); headings and emphasized values: warm gold (`#eac47e`); body text: pale parchment (`#e7d5ba`). The main panel may use a subtle radial shading. Use WoW-provided fonts and the existing `CurseChest.tga`; no external font or browser image is required. The layout remains readable in the supported scale range.

The Journal opens as a single resizable-scale frame. Its left register has four functional tabs:

- **Runs** (default): latest run in the main panel with status, dungeon name, key loot and Need results; recent runs below it. Clicking an eligible run opens the existing detail window. The right column shows five current streaks and records.
- **Curses:** the five trackers with current values and short explanations.
- **Records:** the all-time streak records with their corresponding current values.
- **Share:** the existing six-line report, with party/raid and whisper actions, target input, and the same validation and send timing as the classic view.

The Journal header has title, status, settings, and close controls. Existing icons and labels are reused where helpful. All user-facing strings are localized in German and English. Both layouts read the same `LJ.Stats.Compute` and `LJ.Tracker` data. Data changes refresh the visible layout.

The Options panel gets a clearly marked **Development preview** selector. Classic is selected for existing accounts and invalid saved values. A switch hides the old view, closes transient details or share UI, then opens the selected view if a dashboard was open. Selection is saved in account-wide `LootJinxDB`. Scale is shared; Journal window position is stored separately so previewing it does not move the classic dashboard. Reset Position affects the selected layout. Compact mode shortens the Journal and hides its recent-run list; watermark setting applies to both layouts.

## Implementation boundaries

Keep the existing `UI.lua` dashboard construction intact. Add a separate Journal UI module loaded from the TOC and a small active-view router for toggle/show/hide and options. Shared report generation and sending remain one implementation, decoupled from the classic report popup so either view can invoke them. The existing Run Details window is reused. No third-party library or new web-only PNG is required.

## Verification

- Automated Lua checks: default Classic, switch in both directions, persisted selection after database initialization, only one main frame visible, active-view routing from commands and minimap, refreshed Journal data, and shared report behavior.
- Lua syntax check for every addon file.
- Local WoW Forever review: both layouts at 80%, 100%, and 130% scale; German and English; recent-run detail, share, reset, compact mode, watermark, reload, and return to Classic.

## Release decision

Work stays on local branch `feature/dungeon-journal-preview`. The owner compares both layouts in game. A later decision fixes one design and removes the temporary selector before a CurseForge update.
