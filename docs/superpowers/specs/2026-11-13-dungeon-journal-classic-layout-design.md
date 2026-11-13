# Dungeon Journal Skin on the Classic Layout

## Intent

The owner changed the preview direction: Dungeon Journal should keep the Classic dashboard arrangement. Only its visual style should differ. Classic stays the default and unchanged, and the local Options selector still switches between the two previews.

## Design

The Journal remains an independent WoW frame with its own saved position. It matches Classic's 640 × 628 window and its card geometry: header, full-width dungeon curse card, full-width Need card, three tracker cards, four recent runs, and footer actions. Compact mode uses Classic's 476-pixel height and hides Recent Runs. Share opens a centered popup from the footer. Journal colors use leather, bronze, gold, and parchment with existing TGA icons.

Both views use the same tracker, statistics, run details, and report service. The Journal frame changes only presentation and keeps the current account-wide layout selection. No CurseForge release or push to `origin/main` is part of this preview.

The shared Run Details window follows the selected view's appearance when opened from Recent Runs. Journal uses leather, bronze, parchment, and gold in that window; Classic restores its original colors and font when opened from Classic.

## Approach

Keep the separate Journal view and give it Classic's geometry. This preserves the current Classic implementation and its look. Retheming the Classic frame in place would require restoring every texture and text color on each switch; duplicating the entire Classic module would couple two large UI implementations.

## Verification

Local tests compare the window and card positions, data values, recent-run interaction, report flow, compact height, scale, watermark, and layout routing. The owner will judge the visual result in WoW Forever after `/reload`.
