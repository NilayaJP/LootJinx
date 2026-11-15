"""Fetch reviewed boss/item references from Wowhead Forever dungeon guides.

Run from the repository root. The TSV is build-time reference data, never loaded
by the addon. Unknown bosses and unpublished guides are reported, not guessed.
"""
import concurrent.futures
import html
import os
import re
import subprocess
import sys
import urllib.request
from pathlib import Path

BASE = "https://www.wowhead.com/forever/guide/"
OVERVIEW = BASE + "dungeons-overview-locations-details"
OUT = Path("tools/wowhead_forever_loot.tsv")
SPECIAL = {
    "hall-of-thanes": "Hall of Thanes",
    "the-deadmines": "The Deadmines",
    "excavation-site-wetlands": "Excavation Site: Wetlands",
    "the-stockade": "The Stockade",
    "city-of-dalaran": "City of Dalaran",
    "the-drowned-city": "The Drowned City",
    "ruins-of-lordaeron": "Ruins of Lordaeron",
    "razerfen-kraul": "Razorfen Kraul",
    "the-temple-of-atalhakkar": "Sunken Temple",
    "dire-maul-warpwood-quarter-east": "Dire Maul: East",
    "dire-maul-capital-gardens-west": "Dire Maul: West",
    "dire-maul-gordoks-commons-north": "Dire Maul: North",
    "lower-blackrock-spire": "Lower Blackrock Spire",
    "upper-blackrock-spire": "Upper Blackrock Spire",
    "stratholme-live-side": "Stratholme: Living",
    "stratholme-undead-side": "Stratholme: Undead",
    "zulfarrak": "Zul'Farrak",
    "scarlet-monastery-cathedral": "Scarlet Monastery: Cathedral",
}


def fetch(url):
    request = urllib.request.Request(url, headers={"User-Agent": "LootJinx source review/1.0"})
    with urllib.request.urlopen(request, timeout=20) as response:
        return response.read().decode("utf-8", "replace")


def boss_index(source_path):
    lua = r'''
local path = assert(os.getenv("LJ_FDJ_PATH"))
local root = assert(path:match("^(.*)[/\\]Data[/\\]Dungeons%.lua$"))
local s = { Constants = { ALBA_FAIRMOON_LOCATION = "" } }
assert(loadfile(path))("ForeverDungeonJournal", s)
local shared = loadfile(root .. "/Data/SharedLoot.lua")
if shared then shared("ForeverDungeonJournal", s) end
local f = io.open(root .. "/Data/QuestUpdates.lua", "r")
if f then
  local block = f:read("*a"):match("%-%- BEGIN drownedloot(.-)%-%- END drownedloot")
  f:close()
  if block then assert(load("local _, FDJ = ...\n" .. block))("ForeverDungeonJournal", s) end
end
for _, dungeon in ipairs(s.ORDER) do
  for _, boss in ipairs(s.DB[dungeon].bosses or {}) do
    if boss.name then
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
    names = {}
    dungeons = set()
    for line in result.stdout.splitlines():
        dungeon, boss, alias = line.split("\t")
        dungeons.add(dungeon)
        names.setdefault(dungeon, {})[alias.casefold()] = boss
    return names, dungeons


def guide_dungeon(slug, dungeons):
    name = SPECIAL.get(slug) or slug.replace("-", " ").title()
    # The index has a combined Maraudon guide and no individual wing guides.
    if name == "Maraudon":
        return name
    return name if name in dungeons else None


def parse(url, page, dungeon, aliases):
    found = set()
    unmatched = set()
    # Quest reward tables also name bosses. Only the guide's loot section is
    # suitable for boss-drop attribution.
    heading = re.search(r"<h2\b[^>]*>[^<]*\bLoot\b[^<]*</h2>", page, re.I)
    if not heading:
        return found, unmatched
    page = page[heading.end():]
    end = re.search(r"<h2\b", page, re.I)
    if end:
        page = page[:end.start()]
    for row in re.findall(r"<tr\b[^>]*>.*?</tr>", page, re.I | re.S):
        items = re.findall(r"/forever/item=(\d+)(?:[/?\"#]|$)", row)
        if not items:
            continue
        cells = re.findall(r"<td\b[^>]*>(.*?)</td>", row, re.I | re.S)
        if len(cells) < 3:
            continue
        source = html.unescape(re.sub(r"<[^>]*>", "", cells[-1])).strip()
        source = re.sub(r"\s+", " ", source)
        corrected = {"deathless marrowl": "deathless marrow",
                     "gilll": "gill", "dirgen durgehammer": "durgen dirgehammer"}
        boss = aliases.get(corrected.get(source.casefold(), source.casefold()))
        if not boss:
            unmatched.add(source)
            continue
        for item in items:
            found.add((dungeon, boss, int(item), url))
    return found, unmatched


def main():
    if len(sys.argv) != 2:
        raise SystemExit("usage: python tools/fetch_wowhead_forever_loot.py <ForeverDungeonJournal/Data/Dungeons.lua>")
    names, dungeons = boss_index(sys.argv[1])
    overview = fetch(OVERVIEW).replace("\\/", "/")
    slugs = set(re.findall(r"https://www\.wowhead\.com/forever/guide/([a-z0-9-]+)-dungeon-overview-location-rewards", overview))
    slugs.add("the-drowned-city")
    guides = []
    for slug in sorted(slugs):
        dungeon = guide_dungeon(slug, dungeons)
        if dungeon:
            guides.append((dungeon, BASE + slug + "-dungeon-overview-location-rewards"))
        else:
            print("Unmapped guide:", slug, file=sys.stderr)
    def read_guide(entry):
        dungeon, url = entry
        return dungeon, url, fetch(url)
    rows = set()
    covered = set()
    with_loot = set()
    with concurrent.futures.ThreadPoolExecutor(max_workers=5) as pool:
        for dungeon, url, page in pool.map(read_guide, guides):
            covered.add(dungeon)
            matches, unknown = parse(url, page, dungeon, names[dungeon])
            rows.update(matches)
            if matches:
                with_loot.add(dungeon)
            print(f"{dungeon}: {len(matches)} boss-item references, {len(unknown)} unmatched source labels")
            if unknown:
                print("  unmatched:", ", ".join(sorted(unknown)[:12]))
    missing = sorted(dungeons - covered)
    print("No Wowhead guide:", ", ".join(missing) or "none")
    print(f"Total: {len(rows)} references in {len(with_loot)} dungeons with usable boss loot; "
          f"{len(covered)}/{len(dungeons)} guides fetched")
    OUT.write_text("# Dungeon\tBoss\tItem ID\tWowhead Forever guide URL\n" +
                   "".join("\t".join(map(str, row)) + "\n" for row in sorted(rows)),
                   encoding="utf-8")
    print("Wrote", OUT)


if __name__ == "__main__":
    main()
