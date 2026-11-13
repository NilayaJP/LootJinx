# Dungeon Journal Preview Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a locally testable Dungeon Journal view beside the unchanged Classic dashboard, selected in Options.

**Architecture:** Extract shared report behavior into one small service, build the Journal as its own WoW frame, and route dashboard entry points through an active-view façade. The current UI remains the Classic implementation and default. The local feature branch is the development boundary; no CurseForge release or `origin/main` push.

**Tech Stack:** WoW Forever Lua 5.1-compatible AddOn API, SavedVariables, existing TGA art, local Lua tests.

**Spec:** `docs/superpowers/specs/2026-11-13-dungeon-journal-preview-design.md`

## Global Constraints

- Classic remains the default and must stay visually unchanged.
- No changes to loot detection, character run records, or third-party dependencies.
- German and English strings for every new user-facing control.
- Keep `/lj`, minimap, AddOn Compartment, scale, reset position, report, and reset functional in both views.
- Tests under `tests/` are local and Git-ignored by explicit user request; never force-add them.
- Commit only to local `feature/dungeon-journal-preview`; do not publish to CurseForge.

## Review Focus

1. Unknown or corrupted saved layout value selects Classic after reload (Task 3 test).
2. Switching while a report or Run Details window is open closes transient UI and leaves one main frame visible (Task 3 test).
3. Empty run history renders all Journal tabs without an exception or stale prior run (Task 2 test).
4. Legacy runs remain visible but cannot open unsupported details; pending Need results are not presented as losses (Task 2 test).
5. Switching layouts during a queued six-line report does not duplicate or cancel already scheduled lines (Task 1 and Task 3 tests).

---

## File map

- `Report.lua` (new): report lines, target normalization, group channel choice, timed sending; returns errors to either view.
- `UI.lua` (modify): delegate existing report actions to `Report.lua`; keep Classic frame construction and visuals intact.
- `JournalUI.lua` (new): Journal frame, four tabs, refresh from `Stats` and `Tracker`, own position, scale, compact and watermark handling.
- `LayoutRouter.lua` (new): `LJ.UI` façade selecting Classic or Journal, routing all dashboard entry points and switch lifecycle.
- `Core.lua` (modify): validate account-wide `layoutPreview` to `classic` or `journal`, default `classic`.
- `Options.lua` (modify): localized development selector and active-view option behavior.
- `Localization.lua` (modify): Journal tabs, headings, statuses, and selector copy in German and English.
- `LootJinx.toc` (modify): load `Report.lua` before `UI.lua`; load `JournalUI.lua` and `LayoutRouter.lua` after `RunDetail.lua`, before `Minimap.lua` and `Options.lua`.
- `tests/load_stub.lua` (local only): regression assertions for each task; stays Git-ignored.

### Task 1: Shared report service

**Files:** Create `Report.lua`; modify `UI.lua`, `LootJinx.toc`; test locally in `tests/load_stub.lua`.

**Interfaces:** `LJ.Report:Build() -> string[]`; `LJ.Report:GetTargetName() -> string|nil`; `LJ.Report:Send(channel, target) -> boolean, errorKey|nil`; `LJ.Report:Cancel()`. `channel` accepts `PARTY`/`GROUP` or `WHISPER`; the service chooses RAID when applicable and sends six lines one second apart. Classic UI keeps its public `BuildReport`, `GetTargetName`, and `SendReport` methods as delegates.

- [ ] **Step 1: Add failing local tests** for all six report lines, party/raid/whisper routing, missing group/target errors, one-second sequencing, and a queued report surviving a view switch.
- [ ] **Step 2: Run** `lua tests/load_stub.lua` and confirm the new assertions fail for missing `LJ.Report`.
- [ ] **Step 3: Implement** the service by moving the nonvisual helpers and send queue from `UI.lua`; keep Classic popup error display and success behavior as delegates.
- [ ] **Step 4: Run** `lua tests/load_stub.lua` and `luac -p Report.lua UI.lua`; expect all checks and syntax to pass.
- [ ] **Step 5: Commit** only `Report.lua`, `UI.lua`, and `LootJinx.toc` with `git commit -m "refactor: share report actions across layouts"`.

### Task 2: Dungeon Journal view

**Files:** Create `JournalUI.lua`; modify `Localization.lua`, `LootJinx.toc`; test locally in `tests/load_stub.lua`.

**Interfaces:** `LJ.JournalUI:Create() -> frame|nil`, `Show()`, `Hide()`, `Refresh()`, `ApplyScale(scale)`, `ApplyDisplayOptions()`, `ResetPosition()`. It consumes `LJ.Tracker:GetRuns()`, `LJ.Stats.Compute(runs)`, `LJ.RunDetail:Show(run)`, and `LJ.Report` from Task 1. The main frame is exposed as `LJ.JournalUI.frame`.

- [ ] **Step 1: Add failing local tests** for creating and showing all four tabs, five current values and records, latest/recent run rendering, click to supported Run Details, empty history, legacy and pending Need states, localized tab labels, compact, watermark, scale, and saved Journal position.
- [ ] **Step 2: Run** `lua tests/load_stub.lua` and confirm new assertions fail because `LJ.JournalUI` is absent.
- [ ] **Step 3: Implement** the Journal with the spec's three-column proportions, palette, existing `CurseChest.tga`, clickable register tabs, and a Share tab using `LJ.Report:Send`. Build only in WoW frames and keep the classic frame untouched.
- [ ] **Step 4: Run** `lua tests/load_stub.lua` and `luac -p JournalUI.lua Localization.lua`; expect all checks and syntax to pass.
- [ ] **Step 5: Commit** only `JournalUI.lua`, `Localization.lua`, and `LootJinx.toc` with `git commit -m "feat: add Dungeon Journal preview view"`.

### Task 3: Layout selection and active-view routing

**Files:** Create `LayoutRouter.lua`; modify `Core.lua`, `Options.lua`, `LootJinx.toc`; test locally in `tests/load_stub.lua`.

**Interfaces:** `LJ.UI:SetLayout(id) -> id`, `GetLayout() -> id`, `Create()`, `Toggle()`, `Show()`, `Hide()`, `Refresh()`, `ApplyScale(scale)`, `ApplyDisplayOptions()`, `ResetPosition()`, `ConfirmReset()`, `BuildReport()`, `SendReport(channel,target)`, and `DebugInfo()`; `LJ.UI.frame` points to the active view's frame. `id` is `classic` or `journal`. The façade captures the existing `LJ.UI` as Classic before replacing the global reference; callbacks inside Classic still use their local UI table.

- [ ] **Step 1: Add failing local tests** for default Classic, invalid saved values, switching in both directions, persistence after `LJ:InitDB()`, `/lj`, minimap and AddOn Compartment routing, active-view scale/position reset, old layout unchanged, one visible frame, transient window closure, and report queue continuation.
- [ ] **Step 2: Run** `lua tests/load_stub.lua` and confirm new assertions fail because `SetLayout` and the selector are absent.
- [ ] **Step 3: Implement** `layoutPreview` validation, router, and two-choice Development Preview control in Options. Resize/reflow the Options panel so existing controls remain visible. Switching hides the previous main view, closes transient UI, and shows the new view only when one was visible.
- [ ] **Step 4: Run** `lua tests/stats_spec.lua`, `lua tests/load_stub.lua`, `Get-ChildItem -File -Filter *.lua | ForEach-Object { luac -p $_.FullName }`, and `git diff --check`; expect all to pass. In WoW Forever, compare both views at 80%, 100%, and 130% scale in German and English; check details, sharing, reset, compact, watermark, reload, and return to Classic.
- [ ] **Step 5: Commit** only `LayoutRouter.lua`, `Core.lua`, `Options.lua`, and `LootJinx.toc` with `git commit -m "feat: switch between Classic and Dungeon Journal locally"`.

## Handoff

Keep the preview branch local. Share the test result and any in-game visual limits with the owner. Wait for the owner's final design decision before removing the selector or preparing a CurseForge release.
