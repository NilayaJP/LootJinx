# LootJinx Agent Rules

## WoW API research

- Before adding or changing any WoW API call, event handler, hook, or API-dependent behavior, search for the relevant API documentation or client evidence first.
- Check that the API, its arguments, return values, and event payloads apply to the WoW Forever client and the interface version declared in `LootJinx.toc`. Do not assume another WoW client's API is identical.
- If reliable documentation is unavailable, inspect the existing addon code and available client API evidence, then state the uncertainty and keep the implementation defensive.

## Changelog

- Write all entries in `CHANGELOG.md` in English.
- Describe completed changes using past-tense verbs, such as `Added`, `Changed`, `Fixed`, or `Removed`. Do not use imperative verbs such as `Add` or `Fix` for changelog entries.
- Put unreleased work under `## Unreleased` until a release is explicitly requested.
