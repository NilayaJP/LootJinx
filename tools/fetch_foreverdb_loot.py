"""Fetch ForeverDB.net dungeon loot for review against the LootJinx catalog.

Run from the repository root:

    python tools/fetch_foreverdb_loot.py <ForeverDungeonJournal/Data/Dungeons.lua>

The TSV files are build-time review data. The addon never loads them, and this
tool never changes DungeonLootData.lua. ForeverDB pages are parsed instead of
the key-protected API, so a layout change aborts the run without touching the
previous snapshot.

Credit: Data from ForeverDB.net — https://foreverdb.net
"""
import html
import os
import re
import subprocess
import sys
import time
import unicodedata
import urllib.error
import urllib.request
from pathlib import Path

BASE = "https://foreverdb.net"
INDEX = BASE + "/dungeons"
OUT = Path("tools/foreverdb_loot.tsv")
UNMAPPED_OUT = Path("tools/foreverdb_loot_unmapped.tsv")
USER_AGENT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) LootJinx-source-review/1.0"
DELAY_SECONDS = 0.5

# ForeverDB pages that cover several DungeonJournal wings at once.
WING_PREFIXES = {
    "scarletmonastery": ("Scarlet Monastery:",),
    "diremaul": ("Dire Maul:",),
    "stratholme": ("Stratholme:",),
    "blackrockspire": ("Lower Blackrock Spire", "Upper Blackrock Spire"),
}

# Names that differ beyond a leading "The".
DUNGEON_ALIASES = {
    "stormwindstockade": "The Stockade",
}

# ForeverDB labels that differ from the DungeonJournal boss name.
BOSS_ALIASES = {
    "hazzas": "Morphaz & Hazzas",
    "weaver": "Dreamscythe & Weaver",
    "kirtonos": "Kirtonos the Herald",
    "rasfrostwhisperer": "Ras Frostwhisper",
}

BOSS_LOOT = re.compile(r"<h4\b[^>]*>\s*Loot\s*</h4>\s*<ul\b[^>]*>(.*?)</ul>", re.I | re.S)
BOSS_HEADING = re.compile(r"<h3\b[^>]*>\s*\d+\.\s*(.*?)\s*</h3>", re.I | re.S)
ITEM_ROW = re.compile(
    r'<li\b[^>]*>\s*<a\b[^>]*href="/item/(\d+)"[^>]*>(.*?)</a>(.*?)</li>', re.I | re.S)
DROP_RATE = re.compile(r"dropped in (\d+) of (\d+) kills", re.I)


def fetch(url):
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    last = None
    for attempt in range(3):
        try:
            with urllib.request.urlopen(request, timeout=25) as response:
                return response.read().decode("utf-8", "replace")
        except (urllib.error.URLError, TimeoutError) as error:
            last = error
            time.sleep(1.5 * (attempt + 1))
    raise RuntimeError(f"cannot fetch {url}: {last}")


def text(raw):
    return re.sub(r"\s+", " ", html.unescape(re.sub(r"<[^>]*>", "", raw))).strip()


def normalize(value):
    ascii_text = unicodedata.normalize("NFKD", value).encode("ascii", "ignore").decode("ascii")
    return re.sub(r"[^0-9a-z]", "", ascii_text.casefold())


def without_the(value):
    return re.sub(r"^the\s+", "", value.strip(), flags=re.I)


def boss_index(source_path):
    """Read DungeonJournal names and aliases with the same stub as the Wowhead tool."""
    lua = r'''
local path = assert(os.getenv("LJ_FDJ_PATH"))
local s = { Constants = { ALBA_FAIRMOON_LOCATION = "" } }
assert(loadfile(path))("ForeverDungeonJournal", s)
for _, dungeon in ipairs(s.ORDER) do
  for _, boss in ipairs(s.DB[dungeon].bosses or {}) do
    if boss.name and not boss.trash then
      print(dungeon .. "\t" .. boss.name .. "\t" .. boss.name)
      for _, alias in ipairs(boss.aliases or {}) do
        print(dungeon .. "\t" .. boss.name .. "\t" .. alias)
      end
    end
  end
end
'''
    result = subprocess.run(["lua", "-e", lua], check=True,
                            capture_output=True, text=True, encoding="utf-8",
                            env={**os.environ, "LJ_FDJ_PATH": source_path})
    order, bosses, aliases = [], {}, {}
    for line in result.stdout.splitlines():
        if not line.strip():
            continue
        dungeon, boss, alias = line.split("\t")
        if dungeon not in bosses:
            order.append(dungeon)
            bosses[dungeon] = []
        if boss not in bosses[dungeon]:
            bosses[dungeon].append(boss)
        key = normalize(alias)
        targets = aliases.setdefault(key, [])
        if (dungeon, boss) not in targets:
            targets.append((dungeon, boss))
    return order, bosses, aliases


def dungeon_candidates(page_name, order):
    """Return the DungeonJournal dungeons a ForeverDB page can cover."""
    key = normalize(without_the(page_name))
    by_key = {}
    for dungeon in order:
        by_key[normalize(dungeon)] = dungeon
        by_key[normalize(without_the(dungeon))] = dungeon
    if key in DUNGEON_ALIASES:
        return [DUNGEON_ALIASES[key]]
    if key in by_key:
        return [by_key[key]]
    for prefix_key, prefixes in WING_PREFIXES.items():
        if key == prefix_key:
            return [d for d in order if d.startswith(prefixes)]
    return []


def page_bosses(page):
    section = re.search(r"<h2\b[^>]*>\s*Bosses\s*</h2>(.*?)(?=<h2\b|\Z)", page, re.I | re.S)
    if not section:
        return None
    body = section.group(1)
    matches = list(BOSS_HEADING.finditer(body))
    bosses = []
    for index, match in enumerate(matches):
        end = matches[index + 1].start() if index + 1 < len(matches) else len(body)
        bosses.append((text(match.group(1)), body[match.end():end]))
    return bosses


def parse_loot(block):
    loot = BOSS_LOOT.search(block)
    if not loot:
        return []
    items = []
    for item in ITEM_ROW.finditer(loot.group(1)):
        item_id = int(item.group(1))
        name = text(item.group(2))
        note = text(item.group(3))
        rate = DROP_RATE.search(note)
        drops, kills = (int(rate.group(1)), int(rate.group(2))) if rate else (None, None)
        items.append((item_id, name, drops, kills, bool(rate)))
    return items


def main():
    if len(sys.argv) != 2:
        raise SystemExit("usage: python tools/fetch_foreverdb_loot.py "
                         "<ForeverDungeonJournal/Data/Dungeons.lua>")
    order, _, aliases = boss_index(sys.argv[1])
    overview = fetch(INDEX)
    slugs = []
    for slug in re.findall(r'href="(/dungeon/\d+-[a-z0-9-]+)"', overview):
        if slug not in slugs:
            slugs.append(slug)
    if not slugs:
        raise SystemExit("no dungeon links found on " + INDEX)

    rows = {}
    unmapped = []
    pages_without_dungeon = []
    failed = []
    observed_bosses = {}
    covered_dungeons = set()
    no_rate = 0

    for number, slug in enumerate(slugs, 1):
        url = BASE + slug
        try:
            page = fetch(url)
        except RuntimeError as error:
            failed.append(str(error))
            continue
        heading = re.search(r"<h1\b[^>]*>(.*?)</h1>", page, re.I | re.S)
        page_name = text(heading.group(1)) if heading else slug
        candidates = dungeon_candidates(page_name, order)
        bosses = page_bosses(page)
        if bosses is None:
            if candidates:
                failed.append(f"{page_name}: no Bosses section ({url})")
            else:
                pages_without_dungeon.append((page_name, url, None))
            continue
        if not candidates:
            pages_without_dungeon.append((page_name, url, len(bosses)))
        for boss_name, block in bosses:
            target = None
            if candidates:
                hits = [hit for hit in aliases.get(normalize(boss_name), []) if hit[0] in candidates]
                if not hits:
                    mapped = BOSS_ALIASES.get(normalize(boss_name))
                    if mapped:
                        hits = [hit for hit in aliases.get(normalize(mapped), [])
                                if hit[0] in candidates]
                if len(hits) == 1:
                    target = hits[0]
                elif len(hits) > 1:
                    unmapped.append((page_name, boss_name,
                                     "ambiguous: " + ", ".join(f"{d} / {b}" for d, b in hits), url))
                else:
                    elsewhere = aliases.get(normalize(boss_name), [])
                    reason = ("mapped elsewhere: " + ", ".join(f"{d} / {b}" for d, b in elsewhere)
                              if elsewhere else "no DungeonJournal boss")
                    unmapped.append((page_name, boss_name, reason, url))
            if not target:
                continue
            dungeon, boss = target
            covered_dungeons.add(dungeon)
            observed_bosses[(dungeon, boss)] = observed_bosses.get((dungeon, boss), 0) + 1
            for item_id, name, drops, kills, has_rate in parse_loot(block):
                if not has_rate:
                    no_rate += 1
                rows.setdefault((dungeon, boss, item_id), (dungeon, boss, item_id, name,
                                                          drops, kills, url))
        if number % 10 == 0 or number == len(slugs):
            print(f"  fetched {number}/{len(slugs)} pages", flush=True)
        time.sleep(DELAY_SECONDS)

    if failed:
        print("Fetch aborted; existing snapshot left untouched.", file=sys.stderr)
        for line in failed:
            print("  " + line, file=sys.stderr)
        raise SystemExit(1)

    if not rows:
        raise SystemExit("no loot references parsed; page layout probably changed")

    content = ["# Dungeon\tBoss\tItem ID\tItem\tDrops\tKills\tForeverDB URL"]

    def sort_key(key):
        drops, kills = rows[key][4], rows[key][5]
        known = kills is not None
        rate = drops / kills if known and kills else -1
        return (normalize(key[0]), normalize(key[1]), 0 if known else 1, -rate, key[2])

    for key in sorted(rows, key=sort_key):
        row = rows[key]
        content.append("\t".join("" if value is None else str(value) for value in row))
    OUT.write_text("\n".join(content) + "\n", encoding="utf-8")

    lines = ["# Page\tBoss\tReason\tForeverDB URL"]
    for page_name, url, count in pages_without_dungeon:
        detail = "no Bosses section" if count is None else f"{count} bosses"
        lines.append(f"{page_name}\t-\tno DungeonJournal dungeon ({detail})\t{url}")
    for page_name, boss, reason, url in unmapped:
        lines.append(f"{page_name}\t{boss}\t{reason}\t{url}")
    UNMAPPED_OUT.write_text("\n".join(lines) + "\n", encoding="utf-8")

    dungeons = {row[0] for row in rows.values()}
    print(f"ForeverDB: {len(slugs)} pages, {len(dungeons)} matched dungeons, "
          f"{len(pages_without_dungeon)} pages without a DungeonJournal match")
    if pages_without_dungeon:
        print("  no DJ dungeon:", ", ".join(name for name, _, _ in pages_without_dungeon))
    missing_dungeons = [dungeon for dungeon in order if dungeon not in covered_dungeons]
    print("  no ForeverDB page:", ", ".join(missing_dungeons) or "none")
    if unmapped:
        print(f"  {len(unmapped)} bosses without a unique match (see {UNMAPPED_OUT})")
    if no_rate:
        print(f"  {no_rate} items had no observed drop rate")
    print(f"Total: {len(rows)} references at {len(observed_bosses)} bosses in {len(dungeons)} dungeons")
    print("Wrote", OUT)
    print("Wrote", UNMAPPED_OUT)


if __name__ == "__main__":
    main()
