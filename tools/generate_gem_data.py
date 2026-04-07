from __future__ import annotations

import argparse
import html
import re
import time
import urllib.request
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parent.parent
CACHE_ROOT = REPO_ROOT / "tools" / "cache" / "wotlkdb"
INDEX_CACHE = CACHE_ROOT / "items_3_index.html"
ITEM_CACHE_DIR = CACHE_ROOT / "items"
OUTPUT_PATH = REPO_ROOT / "Data" / "GemData.lua"
GEM_TYPE_IDS = tuple(range(0, 9))

GEM_SUBCLASS_TO_COLORS = {
    0: ("RED",),
    1: ("BLUE",),
    2: ("YELLOW",),
    3: ("RED", "BLUE"),
    4: ("BLUE", "YELLOW"),
    5: ("RED", "YELLOW"),
    6: ("META",),
    8: ("RED", "BLUE", "YELLOW"),
}

LISTVIEW_STAT_MAP = {
    "str": "STR",
    "agi": "AGI",
    "sta": "STA",
    "int": "INT",
    "spi": "SPI",
    "atkpwr": "AP",
    "splpwr": "SP",
    "hitrtng": "HIT",
    "critstrkrtng": "CRIT",
    "hastertng": "HASTE",
    "resirtng": "RESILIENCE",
    "exprtng": "EXPERTISE",
    "dodgertng": "DODGE",
    "parryrtng": "PARRY",
    "defrtng": "DEFENSE",
    "armorpenrtng": "ARP",
    "manargn": "MP5",
}

LABEL_STAT_PATTERNS = {
    "STR": (r"\+\d+ Strength",),
    "AGI": (r"\+\d+ Agility",),
    "STA": (r"\+\d+ Stamina",),
    "INT": (r"\+\d+ Intellect",),
    "SPI": (r"\+\d+ Spirit",),
    "AP": (r"\+\d+ Attack Power",),
    "SP": (r"\+\d+ Spell Power", r"\+\d+ Spell Damage"),
    "HIT": (r"\+\d+ Hit Rating",),
    "CRIT": (r"\+\d+ Critical Strike Rating", r"\+\d+ Crit Rating", r"\+\d+ Critical strike rating"),
    "HASTE": (r"\+\d+ Haste Rating",),
    "RESILIENCE": (r"\+\d+ Resilience Rating",),
    "EXPERTISE": (r"\+\d+ Expertise Rating",),
    "DODGE": (r"\+\d+ Dodge Rating",),
    "PARRY": (r"\+\d+ Parry Rating",),
    "DEFENSE": (r"\+\d+ Defense Rating",),
    "ARP": (r"\+\d+ Armor Penetration Rating",),
    "MP5": (
        r"\+\d+ Mana every 5 seconds",
        r"\+\d+ Mana per 5 sec",
        r"\+\d+ Mana/5 seconds",
        r"\+\d+ mana per 5 seconds",
    ),
    "ARMOR": (r"\+\d+ Armor",),
}


def extract_supported_stats_from_label(label: str | None) -> set[str]:
    if not label:
        return set()

    matched = {
        stat
        for stat, patterns in LABEL_STAT_PATTERNS.items()
        if any(re.search(pattern, label, re.IGNORECASE) for pattern in patterns)
    }
    if "All Stats" in label:
        matched.update({"STR", "AGI", "STA", "INT", "SPI"})
    return matched


def sanitize_stats(record: dict[str, object]) -> None:
    stats = record.get("stats")
    if not isinstance(stats, dict) or not stats:
        return

    label_stats = extract_supported_stats_from_label(record.get("enchantLabel"))
    if label_stats and set(stats).isdisjoint(label_stats):
        record.pop("stats", None)


def fetch_text(url: str, cache_path: Path, refresh: bool, delay: float) -> str:
    cache_path.parent.mkdir(parents=True, exist_ok=True)
    if cache_path.exists() and not refresh:
        return cache_path.read_text(encoding="utf-8")
    request = urllib.request.Request(
        url,
        headers={
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Safari/537.36",
            "Accept-Language": "en-US,en;q=0.9",
        },
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        text = response.read().decode("utf-8", errors="replace")
    cache_path.write_text(text, encoding="utf-8")
    if delay > 0:
        time.sleep(delay)
    return text


def parse_catalog(index_html: str) -> dict[int, dict[str, object]]:
    quality_map = {
        int(item_id): {
            "itemId": int(item_id),
            "itemName": html.unescape(name),
            "quality": int(quality),
        }
        for item_id, quality, name in re.findall(
            r'_\[(\d+)\]=\{"quality":(\d+),"icon":"[^"]+","name_enus":"([^"]+)"\}',
            index_html,
        )
    }

    listview_pattern = re.compile(
        r'\{"id":(\d+),"name":"\d([^"]+)".*?"subclass":(\d+).*?"gearscore":(\d+)(.*?),"source":',
        re.DOTALL,
    )
    for item_id_text, display_name, subclass_text, _gearscore_text, stats_fragment in listview_pattern.findall(index_html):
        item_id = int(item_id_text)
        record = quality_map.get(item_id)
        if not record:
            record = {"itemId": item_id, "itemName": html.unescape(display_name), "quality": 4}
            quality_map[item_id] = record
        record["itemName"] = html.unescape(display_name)
        record["subclass"] = int(subclass_text)
        record["colors"] = GEM_SUBCLASS_TO_COLORS.get(int(subclass_text), ())
        stats: dict[str, int] = {}
        for raw_key, raw_value in re.findall(r'"([a-z]+)":(-?\d+)', stats_fragment):
            stat_key = LISTVIEW_STAT_MAP.get(raw_key)
            if stat_key:
                stats[stat_key] = stats.get(stat_key, 0) + int(raw_value)
        record["stats"] = stats
    return quality_map


def merge_catalogs(target: dict[int, dict[str, object]], source: dict[int, dict[str, object]]) -> None:
    for item_id, record in source.items():
        existing = target.get(item_id)
        if not existing:
            target[item_id] = record
            continue
        for key, value in record.items():
            if key not in existing or not existing.get(key):
                existing[key] = value


def enrich_item_record(record: dict[str, object], refresh: bool, delay: float) -> None:
    item_id = int(record["itemId"])
    item_html = fetch_text(
        f"https://wotlkdb.com/?item={item_id}",
        ITEM_CACHE_DIR / f"{item_id}.html",
        refresh=refresh,
        delay=delay,
    )
    tooltip_match = re.search(rf'_\[{item_id}\]\.tooltip_enus = "(.+?)";', item_html, re.DOTALL)
    tooltip = tooltip_match.group(1) if tooltip_match else ""
    record["tooltip"] = tooltip

    enchant_match = re.search(r'enchantment=(\d+).*?>([^<]+)<', tooltip)
    if enchant_match:
        record["enchantId"] = int(enchant_match.group(1))
        record["enchantLabel"] = html.unescape(enchant_match.group(2))
    else:
        record["enchantId"] = None
        record["enchantLabel"] = None

    color_match = re.search(r"Matches a ([^.]+?) Socket", tooltip, re.IGNORECASE)
    if color_match:
        color_text = html.unescape(color_match.group(1)).upper()
        colors = []
        if "RED" in color_text:
            colors.append("RED")
        if "BLUE" in color_text:
            colors.append("BLUE")
        if "YELLOW" in color_text:
            colors.append("YELLOW")
        if "META" in color_text:
            colors.append("META")
        if "PRISMATIC" in color_text:
            colors.extend(["RED", "BLUE", "YELLOW"])
        if colors:
            record["colors"] = tuple(dict.fromkeys(colors))

    sanitize_stats(record)


def render_lua(records: list[dict[str, object]]) -> str:
    lines = [
        "-------------------------------------------------------------------------------",
        "--                           GearScore2 Gem Database                           --",
        "-------------------------------------------------------------------------------",
        "-- Generated from WotLKDB gem items and their linked enchant pages for WoW 3.3.5a.",
        "-- GS.Data.Gems.Values is keyed by gem enchant ID, matching the IDs present in item links.",
        "-- GS.Data.Gems.Items is keyed by gem item ID and can be used as a runtime fallback when",
        "-- the item link exposes the gem item but not the gem enchant ID.",
        "",
        "local GS = _G.GS2 or {}",
        "GS.Data = GS.Data or {}",
        "GS.Data.Gems = GS.Data.Gems or {}",
        "",
        "GS.Data.Gems.Values = {",
    ]

    enchant_records = [record for record in records if record.get("enchantId")]
    for record in sorted(enchant_records, key=lambda entry: int(entry["enchantId"])):
        parts = [
            'kind = "stats"' if record.get("stats") else 'kind = "special"',
            f'label = "{str(record["itemName"]).replace(chr(34), "\\\"")}"',
            f'itemId = {record["itemId"]}',
            f'quality = {record["quality"]}',
        ]
        if record.get("enchantLabel"):
            parts.append(f'enchantLabel = "{str(record["enchantLabel"]).replace(chr(34), "\\\"")}"')
        if record.get("colors"):
            parts.append("colors = { " + ", ".join(f'"{color}"' for color in record["colors"]) + " }")
        if record.get("stats"):
            parts.append(
                "stats = { "
                + ", ".join(f"{key} = {value}" for key, value in sorted(record["stats"].items()))
                + " }"
            )
        lines.append(f'\t[{record["enchantId"]}] = {{ {", ".join(parts)} }},')

    lines.extend(["}", "", "GS.Data.Gems.Items = {"])
    for record in sorted(records, key=lambda entry: int(entry["itemId"])):
        parts = [
            f'label = "{str(record["itemName"]).replace(chr(34), "\\\"")}"',
            f'quality = {record["quality"]}',
        ]
        if record.get("enchantId"):
            parts.append(f'enchantId = {record["enchantId"]}')
        if record.get("enchantLabel"):
            parts.append(f'enchantLabel = "{str(record["enchantLabel"]).replace(chr(34), "\\\"")}"')
        if record.get("colors"):
            parts.append("colors = { " + ", ".join(f'"{color}"' for color in record["colors"]) + " }")
        if record.get("stats"):
            parts.append(
                "stats = { "
                + ", ".join(f"{key} = {value}" for key, value in sorted(record["stats"].items()))
                + " }"
            )
        lines.append(f'\t[{record["itemId"]}] = {{ {", ".join(parts)} }},')
    lines.extend(["}", ""])
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate Data/GemData.lua from WotLKDB gem items and linked enchants.")
    parser.add_argument("--refresh", action="store_true", help="Refresh cached WotLKDB pages.")
    parser.add_argument("--delay", type=float, default=0.05, help="Delay between uncached requests in seconds.")
    parser.add_argument("--output", type=Path, default=OUTPUT_PATH)
    args = parser.parse_args()

    catalog: dict[int, dict[str, object]] = {}
    index_html = fetch_text("https://wotlkdb.com/?items=3", INDEX_CACHE, refresh=args.refresh, delay=args.delay)
    merge_catalogs(catalog, parse_catalog(index_html))
    for gem_type_id in GEM_TYPE_IDS:
        type_cache = CACHE_ROOT / f"items_3_ty_{gem_type_id}.html"
        type_html = fetch_text(
            f"https://wotlkdb.com/?items=3&filter=ty={gem_type_id}",
            type_cache,
            refresh=args.refresh,
            delay=args.delay,
        )
        merge_catalogs(catalog, parse_catalog(type_html))
    records = list(catalog.values())
    for record in records:
        enrich_item_record(record, refresh=args.refresh, delay=args.delay)

    args.output.write_text(render_lua(records), encoding="utf-8")
    resolved = sum(1 for record in records if record.get("enchantId"))
    print(f"Wrote {args.output} with {len(records)} gem items and {resolved} gem-enchant pairs.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
