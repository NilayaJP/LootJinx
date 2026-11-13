# LootJinx Agent Rules

## Project and loading

- LootJinx is a native Lua addon for World of Warcraft: Forever. The supported interface number and addon version are declared in `LootJinx.toc`.
- `LootJinx.toc` defines module load order. When adding or renaming a Lua file, update the `.toc` and the test loader in `tests/load_stub.lua` in the same change.
- Keep the addon free of external runtime libraries unless the user explicitly requests a dependency.

## WoW API research

- Before implementing a gameplay or UI feature, identify its relevant WoW APIs and search their documentation or client evidence. Do this before adding or changing API calls, event handlers, hooks, or API-dependent behavior.
- Check that the API, its arguments, return values, and event payloads apply to the WoW Forever client and the interface version declared in `LootJinx.toc`. Do not assume another WoW client's API is identical.
- If reliable documentation is unavailable, inspect the existing addon code and available client API evidence, then state the uncertainty and keep the implementation defensive.
- WoW Forever does not expose a combat log to addons. Treat loot and roll detection as best-effort; do not present inferred outcomes as directly observed facts.

## Data and behavior

- Preserve existing `LootJinxDB` account-wide settings and `LootJinxCharDB` per-character runs and statistics when changing saved data. Handle older runs that lack detailed data.
- Keep repeated drops and Need rolls for identical items distinct. A missing roll value or recipient must remain unknown rather than being invented.
- Greed rolls must not change Need statistics. Changes to the five trackers, roll matching, or run continuity need focused regression checks.
- `DungeonLootData.lua` is attribution reference data, not a whitelist of possible drops. Keep observed items visible when the catalog is missing or ambiguous. Review source data and regenerate it with `tools/build_dungeon_loot.lua` when updating the catalog.
- Keep Classic and Dungeon Journal functional. Changes to shared behavior should appear in both designs; the selected design also applies to run details. ESC closes the detail window before history or the dashboard.
- Add or update both German and English entries in `Localization.lua` for user-facing text.

## Verification

- Run `lua tests/load_stub.lua`, `lua tests/stats_spec.lua`, `lua tests/history_spec.lua`, `lua tests/evidence_spec.lua`, `lua tests/storage_spec.lua`, and `lua tests/report_format_spec.lua` when their covered behavior changes. Run `luac -p` on changed Lua files and `git diff --check` before committing.
- `tests/`, `docs/`, and `dist/` are intentionally ignored by Git. Do not force-add generated files or local tests without an explicit request.
- A stub test cannot prove behavior in the WoW client. Report any client-specific behavior that remains unverified.

## Changelog

- Write all entries in `CHANGELOG.md` in English.
- Describe completed changes using past-tense verbs, such as `Added`, `Changed`, `Fixed`, or `Removed`. Do not use imperative verbs such as `Add` or `Fix` for changelog entries.
- Put unreleased work under `## Unreleased` until a release is explicitly requested.

## Publishing

- Keep `README.md` in English. Update user-facing documentation when behavior changes; keep the CurseForge description aligned with an actual release.
- A Git push is not a version release. Do not create a version tag, release archive, CurseForge upload, or enable automatic packaging unless the user explicitly asks for it.
- After an approved merge, keep local `main` and `origin/main` synchronized. Never force-push.
