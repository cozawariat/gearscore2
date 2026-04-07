#!/usr/bin/env python3
from __future__ import annotations

import argparse
import base64
import csv
import json
import math
import re
import statistics
import urllib.parse
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from benchmark_core import (
    BALANCE_TARGET_SPREAD_GS2,
    IGNORED_BENCHMARK_SLOT_IDS,
    PHASE_SORT_ORDER,
    Fetcher,
    apply_character_caps,
    apply_runtime_constants,
    build_phase_component_summary,
    build_phase_growth_trends,
    calculate_legacy_base,
    enrich_component_metrics,
    get_hunter_legacy,
    get_item_slot_value,
    get_profile,
    load_runtime_tables,
    normalize_spec_name,
    parse_item_page,
    safe_json_value,
    score_item_with_debug,
)


REPO_ROOT = Path(__file__).resolve().parents[1]
TOOLS_DIR = REPO_ROOT / "tools"
DEFAULT_MANIFEST = TOOLS_DIR / "data" / "wowhead_wotlk_pve_guides.json"
DEFAULT_CACHE_DIR = TOOLS_DIR / "cache"
DEFAULT_OUTPUT_DIR = REPO_ROOT / "tools" / "output"
ALL_PHASES_LABEL = "ALL"
MEDIAN_TARGET_DELTA = 500
BENCHMARK_PHASES = ("PHASE_1", "PHASE_2", "PHASE_3", "PHASE_4")

PHASE_URL_MARKERS = {
    "PRE_RAID": "pre-raid",
    "PHASE_1": "pve-phase-1",
    "PHASE_2": "pve-phase-2",
    "PHASE_3": "pve-phase-3",
    "PHASE_4": "pve-phase-4",
}

WOWHEAD_SLOT_MAP = {
    1: "INVTYPE_HEAD",
    2: "INVTYPE_NECK",
    3: "INVTYPE_SHOULDER",
    5: "INVTYPE_CHEST",
    6: "INVTYPE_WAIST",
    7: "INVTYPE_LEGS",
    8: "INVTYPE_FEET",
    9: "INVTYPE_WRIST",
    10: "INVTYPE_HAND",
    11: "INVTYPE_FINGER",
    12: "INVTYPE_TRINKET",
    13: "INVTYPE_WEAPON",
    14: "INVTYPE_SHIELD",
    15: "INVTYPE_RANGED",
    16: "INVTYPE_CLOAK",
    20: "INVTYPE_CHEST",
    21: "INVTYPE_WEAPONMAINHAND",
    22: "INVTYPE_WEAPONOFFHAND",
    23: "INVTYPE_HOLDABLE",
    26: "INVTYPE_RANGED",
    28: "INVTYPE_RELIC",
}

STAT_KEY_MAP = {
    "str": "STR",
    "agi": "AGI",
    "sta": "STA",
    "int": "INT",
    "spi": "SPI",
    "spldmg": "SP",
    "splheal": "SP",
    "atkpwr": "AP",
    "ratkpwr": "RAP",
    "rgdatkpwr": "RAP",
    "critstrkrtng": "CRIT",
    "splcritstrkrtng": "CRIT",
    "mlecritstrkrtng": "CRIT",
    "rgdcritstrkrtng": "CRIT",
    "hastertng": "HASTE",
    "splhastertng": "HASTE",
    "mlehastertng": "HASTE",
    "rgdhastertng": "HASTE",
    "hitrtng": "HIT",
    "splhitrtng": "HIT",
    "mlehitrtng": "HIT",
    "rgdhitrtng": "HIT",
    "exprtng": "EXPERTISE",
    "defrtng": "DEFENSE",
    "dodgertng": "DODGE",
    "parryrtng": "PARRY",
    "blockrtng": "BLOCK",
    "blockval": "BLOCKVALUE",
    "armorpenrtng": "ARP",
    "resirtng": "RESILIENCE",
    "manargn": "MP5",
    "mleatkpwr": "AP",
}

SINGLE_SLOT_IDS = {1, 2, 3, 5, 6, 7, 8, 9, 10, 15, 16, 17, 18}
DEFAULT_PHASE_LABEL = "PHASE_1"
PLANNER_SELECTION_POLICY = "validated-first"
PLANNER_BASE_URL = "https://www.wowhead.com/wotlk/gear-planner"
PHASE_MIN_AVG_ITEM_LEVEL = {
    "PRE_RAID": 150.0,
    "PHASE_1": 190.0,
    "PHASE_2": 210.0,
    "PHASE_3": 225.0,
    "PHASE_4": 245.0,
}
PHASE_TAB_LABEL_HINTS = {
    "PRE_RAID": ("PRE-RAID", "PRERAID"),
    "PHASE_1": ("P1", "PHASE 1", "TIER 7", "NAXX"),
    "PHASE_2": ("P2", "PHASE 2", "TIER 8", "Ulduar".upper()),
    "PHASE_3": ("P3", "PHASE 3", "TIER 9", "TOC", "TRIAL OF THE CRUSADER"),
    "PHASE_4": ("P4", "PHASE 4", "P5", "PHASE 5", "TIER 10", "ICC", "ICECROWN"),
}
PLANNER_ENCHANT_SPELL_OVERRIDES = {
    30258: {"CRIT": 28.0},
}
PLANNER_SLOT_LABELS = {
    1: "Head",
    2: "Neck",
    3: "Shoulder",
    5: "Chest",
    6: "Waist",
    7: "Legs",
    8: "Feet",
    9: "Wrist",
    10: "Hands",
    11: "Finger1",
    12: "Finger2",
    13: "Trinket1",
    14: "Trinket2",
    15: "Back",
    16: "MainHand",
    17: "OffHand",
    18: "Ranged",
}


def log_progress(message: str) -> None:
    print(message, flush=True)


def slugify_url(url: str) -> str:
    parsed = urllib.parse.urlparse(url)
    return re.sub(r"[^A-Za-z0-9._-]+", "_", parsed.path.strip("/"))


def extract_braced_object(source: str, start_index: int) -> tuple[str, int]:
    brace_start = source.find("{", start_index)
    if brace_start == -1:
        raise ValueError("Could not find opening brace for JSON object")
    depth = 0
    in_string = False
    escaped = False
    for index in range(brace_start, len(source)):
        ch = source[index]
        if in_string:
            if escaped:
                escaped = False
            elif ch == "\\":
                escaped = True
            elif ch == '"':
                in_string = False
            continue
        if ch == '"':
            in_string = True
            continue
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                return source[brace_start:index + 1], index + 1
    raise ValueError("Could not find closing brace for JSON object")


def extract_gatherer_data(html_text: str) -> dict[int, dict[str, Any]]:
    data: dict[int, dict[str, Any]] = {}
    needle = "WH.Gatherer.addData("
    offset = 0
    while True:
        start = html_text.find(needle, offset)
        if start == -1:
            break
        tree_start = start + len(needle)
        tree_end = html_text.find(",", tree_start)
        if tree_end == -1:
            break
        tree_id = int(html_text[tree_start:tree_end].strip())
        object_text, offset = extract_braced_object(html_text, tree_end)
        parsed = json.loads(object_text)
        existing = data.setdefault(tree_id, {})
        existing.update(parsed)
    return data


def extract_markup_text(html_text: str) -> str:
    match = re.search(r'WH\.markup\.printHtml\(("(?:\\.|[^"])*")\s*,\s*"guide-body"', html_text, re.DOTALL)
    if not match:
        raise ValueError("Could not find Wowhead guide markup payload")
    return json.loads(match.group(1))


def extract_planner_builds(markup: str) -> tuple[list[dict[str, Any]], list[str]]:
    planner_entries: list[dict[str, Any]] = []
    current_tab_label: str | None = None
    token_pattern = re.compile(r"(\[tab[^\]]*\]|\[/tab\]|\[gear-planner=([^\]]+)\])", re.IGNORECASE)
    for match in token_pattern.finditer(markup):
        token = match.group(1)
        lowered = token.lower()
        if lowered.startswith("[tab"):
            tab_name_match = re.search(r'name="([^"]+)"', token, re.IGNORECASE)
            current_tab_label = tab_name_match.group(1).strip() if tab_name_match else None
            continue
        if lowered == "[/tab]":
            current_tab_label = None
            continue
        planner_path = (match.group(2) or "").strip()
        if planner_path:
            planner_entries.append(
                {
                    "path": planner_path,
                    "url": f"{PLANNER_BASE_URL}/{planner_path}",
                    "tabLabel": current_tab_label,
                    "selectionPolicy": PLANNER_SELECTION_POLICY,
                }
            )
    if not planner_entries:
        return [], ["no-planner-build-found"]
    return planner_entries, []


def extract_first_planner_build(markup: str) -> tuple[dict[str, Any] | None, list[str]]:
    planner_entries, diagnostics = extract_planner_builds(markup)
    if not planner_entries:
        return None, diagnostics
    return planner_entries[0], diagnostics


def normalize_planner_path(planner_value: str) -> str:
    value = planner_value.strip()
    if not value:
        return value
    parsed = urllib.parse.urlparse(value)
    if parsed.scheme and parsed.netloc:
        prefix = "/wotlk/gear-planner/"
        path = parsed.path
        if path.startswith(prefix):
            return path[len(prefix):].strip("/")
        raise ValueError(f"Unsupported planner URL: {planner_value}")
    return value.strip("/")


def decode_planner_payload(planner_path: str) -> dict[str, Any]:
    planner_path = normalize_planner_path(planner_path)
    match = re.fullmatch(r"([a-z-]+)/([a-z-]+)(?:/([A-Za-z0-9_-]+))?", planner_path.strip(), re.IGNORECASE)
    if not match:
        raise ValueError(f"Unsupported planner path: {planner_path}")
    class_slug, race_slug, payload = match.groups()
    state = {
        "classSlug": class_slug.lower(),
        "raceSlug": race_slug.lower(),
        "slots": {},
        "level": 80,
        "genderId": None,
        "version": None,
    }
    if not payload:
        return state
    normalized_payload = payload.replace("-", "+").replace("_", "/")
    normalized_payload += "=" * (-len(normalized_payload) % 4)
    raw_bytes = list(base64.b64decode(normalized_payload))
    if not raw_bytes:
        return state
    version = raw_bytes.pop(0)
    state["version"] = version
    if version > 4 and raw_bytes:
        state["genderId"] = raw_bytes.pop(0)
    if version > 0 and raw_bytes:
        state["level"] = raw_bytes.pop(0)
    if version > 1 and raw_bytes:
        talent_bytes = raw_bytes.pop(0)
        del raw_bytes[:talent_bytes]
        if version >= 4 and raw_bytes:
            extra_bytes = raw_bytes.pop(0)
            del raw_bytes[:extra_bytes]
    while len(raw_bytes) >= 3:
        slot_value = raw_bytes.pop(0)
        gem_count = 0
        item_id = 0
        if version >= 3:
            item_header = raw_bytes.pop(0)
            gem_count = (item_header & 224) >> 5
            item_id |= (item_header & 31) << 16
        item_id |= raw_bytes.pop(0) << 8
        item_id |= raw_bytes.pop(0)
        has_enchant = bool(slot_value & 128)
        has_random_enchant = bool(slot_value & 64)
        slot_id = slot_value & ~128 & ~64
        slot_record: dict[str, Any] = {"itemId": item_id, "gems": {}}
        if has_enchant:
            enchant_id = 0
            if version >= 6 and raw_bytes:
                enchant_id |= raw_bytes.pop(0) << 16
            if len(raw_bytes) >= 2:
                enchant_id |= raw_bytes.pop(0) << 8
                enchant_id |= raw_bytes.pop(0)
            slot_record["enchantId"] = enchant_id
        if has_random_enchant and len(raw_bytes) >= 2:
            random_enchant_id = (raw_bytes.pop(0) << 8) | raw_bytes.pop(0)
            if random_enchant_id & 32768:
                random_enchant_id -= 65536
            slot_record["randomEnchantId"] = random_enchant_id
        for _ in range(gem_count):
            if len(raw_bytes) < 3:
                break
            gem_header = raw_bytes.pop(0)
            gem_slot = (gem_header & 224) >> 5
            gem_id = (gem_header & 31) << 16
            gem_id |= raw_bytes.pop(0) << 8
            gem_id |= raw_bytes.pop(0)
            slot_record["gems"][gem_slot] = gem_id
        state["slots"][slot_id] = slot_record
    return state


def build_entries_from_planner(planner: dict[str, Any]) -> tuple[list[dict[str, Any]], list[str]]:
    diagnostics: list[str] = []
    entries: list[dict[str, Any]] = []
    planner_state = decode_planner_payload(planner["path"])
    planner["classSlug"] = planner_state["classSlug"]
    planner["raceSlug"] = planner_state["raceSlug"]
    planner["level"] = planner_state["level"]
    planner["genderId"] = planner_state["genderId"]
    planner["version"] = planner_state["version"]
    for slot_id in sorted(planner_state["slots"]):
        slot_state = planner_state["slots"][slot_id]
        entries.append(
            {
                "slotId": slot_id,
                "slotTitle": PLANNER_SLOT_LABELS.get(slot_id, f"Slot {slot_id}"),
                "itemId": slot_state["itemId"],
                "itemAlternates": [],
                "gemItemIds": [slot_state["gems"][index] for index in sorted(slot_state["gems"])],
                "gemSockets": safe_json_value(slot_state["gems"]),
                "plannerEnchantId": int(slot_state.get("enchantId", 0) or 0),
                "plannerRandomEnchantId": int(slot_state.get("randomEnchantId", 0) or 0),
                "rowLabel": planner.get("tabLabel") or "",
            }
        )
    if not entries:
        diagnostics.append("planner-build-decoded-without-slots")
    if any(entry["plannerRandomEnchantId"] for entry in entries):
        diagnostics.append("planner-random-enchants-present")
    return entries, diagnostics


def get_item_level(item: dict[str, Any]) -> int:
    return int(item.get("level", 0) or 0)


def build_planner_candidate(
    planner: dict[str, Any],
    phase: str,
    fetcher: Fetcher,
    item_cache: dict[tuple[int, int], dict[str, Any]],
) -> dict[str, Any]:
    candidate = dict(planner)
    try:
        entries, planner_diagnostics = build_entries_from_planner(candidate)
        rejection_reasons = list(planner_diagnostics)
    except ValueError as exc:
        entries = []
        rejection_reasons = [f"planner-decode-error:{exc}"]
    item_levels: list[int] = []
    benchmark_item_levels: list[int] = []
    item_names: list[str] = []
    for entry in entries:
        cache_key = (entry["itemId"], entry["slotId"])
        if cache_key not in item_cache:
            item_cache[cache_key] = parse_item_page(entry["itemId"], entry["slotId"], fetcher)
        item_data = item_cache[cache_key]
        item_level = get_item_level(item_data)
        item_levels.append(item_level)
        if entry["slotId"] not in IGNORED_BENCHMARK_SLOT_IDS:
            benchmark_item_levels.append(item_level)
        item_names.append(str(item_data.get("name") or ""))
    avg_item_level = round(sum(benchmark_item_levels) / len(benchmark_item_levels), 2) if benchmark_item_levels else 0.0
    min_expected_ilvl = PHASE_MIN_AVG_ITEM_LEVEL.get(phase, 0.0)
    if avg_item_level and avg_item_level < min_expected_ilvl:
        rejection_reasons.append(f"planner-avg-ilvl-below-{phase.lower()}-floor:{avg_item_level}")
    tab_label = str(candidate.get("tabLabel") or "").upper()
    hint_score = 0
    for hint in PHASE_TAB_LABEL_HINTS.get(phase, ()):
        if hint in tab_label:
            hint_score += 1
    validation_status = "accepted" if not rejection_reasons else "rejected"
    return {
        "planner": candidate,
        "entries": entries,
        "avg_item_level": avg_item_level,
        "item_levels": item_levels,
        "item_names": item_names,
        "hint_score": hint_score,
        "validation_status": validation_status,
        "rejection_reasons": rejection_reasons,
    }


def select_planner_candidate(
    planners: list[dict[str, Any]],
    phase: str,
    fetcher: Fetcher,
    item_cache: dict[tuple[int, int], dict[str, Any]],
) -> tuple[dict[str, Any] | None, list[dict[str, Any]], list[str]]:
    candidates = [build_planner_candidate(planner, phase, fetcher, item_cache) for planner in planners]
    if not candidates:
        return None, [], ["planner-build-missing"]
    accepted = [candidate for candidate in candidates if candidate["validation_status"] == "accepted"]
    if accepted:
        accepted.sort(key=lambda candidate: (candidate["hint_score"], candidate["avg_item_level"]), reverse=True)
        selected = accepted[0]
        return selected, candidates, []
    candidates.sort(key=lambda candidate: (candidate["hint_score"], candidate["avg_item_level"]), reverse=True)
    selected = candidates[0]
    diagnostics = ["planner-selection-fell-back-to-rejected-candidate"]
    diagnostics.extend(selected["rejection_reasons"])
    return selected, candidates, diagnostics


def strip_markup_tags(text: str) -> str:
    cleaned = text
    cleaned = re.sub(r"\[/?(?:b|i|u|center|color|icon|span|ul|ol|li|pad|db|toc|nav|nav-item|cta-button|tabs|tab)[^\]]*\]", "", cleaned, flags=re.IGNORECASE)
    cleaned = re.sub(r"\[/?(?:url|quote|h2|h3|table|tr|td|currency|npc|zone|spell|item|item-set|faction|object|class|race|skill|event|quest)[^\]]*\]", "", cleaned, flags=re.IGNORECASE)
    cleaned = re.sub(r"\s+", " ", cleaned)
    return cleaned.strip()


def extract_item_ids(text: str) -> list[int]:
    values = [int(raw) for raw in re.findall(r"\[item=(\d+)\]", text)]
    values.extend(int(raw) for raw in re.findall(r"url=/item=(\d+)", text))
    return values


def extract_spell_ids(text: str) -> list[int]:
    values = [int(raw) for raw in re.findall(r"\[spell=(\d+)\]", text)]
    values.extend(int(raw) for raw in re.findall(r"url=/spell=(\d+)", text))
    return values


def split_rows(table_markup: str) -> list[list[str]]:
    rows: list[list[str]] = []
    for row_match in re.finditer(r"\[tr\](.*?)\[/tr\]", table_markup, re.DOTALL | re.IGNORECASE):
        cells = re.findall(r"\[td[^\]]*\](.*?)\[/td\]", row_match.group(1), re.DOTALL | re.IGNORECASE)
        if cells:
            rows.append(cells)
    return rows


def normalize_header_name(text: str) -> str:
    return strip_markup_tags(text).strip().lower()


def parse_table_rows(table_markup: str) -> dict[str, Any] | None:
    rows = split_rows(table_markup)
    if len(rows) < 2:
        return None
    header_row = rows[0]
    headers = [normalize_header_name(cell) for cell in header_row]
    if "item" not in headers:
        return None
    item_index = headers.index("item")
    sockets_index = headers.index("sockets") if "sockets" in headers else None
    parsed_rows = []
    for raw_cells in rows[1:]:
        if item_index >= len(raw_cells):
            continue
        item_ids = extract_item_ids(raw_cells[item_index])
        if not item_ids:
            continue
        gem_ids = extract_item_ids(raw_cells[sockets_index]) if sockets_index is not None and sockets_index < len(raw_cells) else []
        parsed_rows.append(
            {
                "rowLabel": strip_markup_tags(raw_cells[0]) if raw_cells else "",
                "itemIds": item_ids,
                "gemItemIds": gem_ids,
            }
        )
    if not parsed_rows:
        return None
    return {"headers": headers, "rows": parsed_rows}


def find_last_subsection_title(text: str) -> str | None:
    clean = text.replace("\r", "")
    heading_matches = list(re.finditer(r"\[h3[^\]]*\](.*?)\[/h3\]", clean, re.DOTALL | re.IGNORECASE))
    if heading_matches:
        return strip_markup_tags(heading_matches[-1].group(1))
    candidates = [
        r"Main(?:-| )?Hand(?: and Two-Handed)? Weapons[^\n]*",
        r"Main-Hand and Two-Handed Weapons[^\n]*",
        r"Off Hand Weapons[^\n]*",
        r"Shields and Off-Hands[^\n]*",
        r"Guns and Bows[^\n]*",
        r"Ranged Weapons[^\n]*",
        r"Wands[^\n]*",
        r"Librams[^\n]*",
        r"Idols[^\n]*",
        r"Totems[^\n]*",
        r"Sigils[^\n]*",
        r"Relics[^\n]*",
    ]
    found_title: str | None = None
    for pattern in candidates:
        matches = list(re.finditer(pattern, clean, re.IGNORECASE))
        if matches:
            found_title = strip_markup_tags(matches[-1].group(0))
    return found_title


def resolve_slot_ids(title: str) -> list[int]:
    upper = title.upper()
    if "MAIN-HAND" in upper or "MAIN HAND" in upper or "TWO-HANDED" in upper:
        return [16]
    if "OFF HAND" in upper or "OFF-HAND" in upper or "SHIELDS AND OFF-HANDS" in upper or "SHIELDS AND OFF HANDS" in upper:
        return [17]
    if any(token in upper for token in ["WANDS", "GUNS AND BOWS", "RANGED", "LIBRAM", "IDOL", "TOTEM", "SIGIL", "RELIC"]):
        return [18]
    if "HEAD" in upper:
        return [1]
    if "SHOULDER" in upper:
        return [3]
    if "BACK" in upper or "CLOAK" in upper:
        return [15]
    if "CHEST" in upper or "TUNIC" in upper or "ROBE" in upper:
        return [5]
    if "WRIST" in upper or "BRACER" in upper or "CUFF" in upper:
        return [9]
    if "HANDS" in upper or "GLOVE" in upper:
        return [10]
    if "WAIST" in upper or "BELT" in upper:
        return [6]
    if "LEGS" in upper or "LEGS" in upper or "GREAVES" in upper or "LEGPLATE" in upper:
        return [7]
    if "FEET" in upper or "BOOT" in upper or "SABATON" in upper or "TRAMPLER" in upper:
        return [8]
    if "NECK" in upper:
        return [2]
    if "RINGS" in upper or upper.startswith("RING "):
        return [11, 12]
    if "TRINKETS" in upper or upper.startswith("TRINKET "):
        return [13, 14]
    return []


def choose_primary_rows(slot_ids: list[int], parsed_table: dict[str, Any]) -> list[dict[str, Any]]:
    rows = parsed_table["rows"]
    if not rows:
        return []
    if slot_ids in ([11, 12], [13, 14]):
        return rows[:2]
    return rows[:1]


def parse_section_enhancements(intro_text: str) -> list[dict[str, Any]]:
    enhancements: list[dict[str, Any]] = []
    seen: set[tuple[str, int]] = set()
    for item_id in extract_item_ids(intro_text):
        key = ("item", item_id)
        if key not in seen:
            enhancements.append({"type": "item", "id": item_id})
            seen.add(key)
    for spell_id in extract_spell_ids(intro_text):
        key = ("spell", spell_id)
        if key not in seen:
            enhancements.append({"type": "spell", "id": spell_id})
            seen.add(key)
    return enhancements


def extract_primary_build(markup: str) -> tuple[list[dict[str, Any]], list[str]]:
    entries: list[dict[str, Any]] = []
    diagnostics: list[str] = []
    token_pattern = re.compile(r"(\[table[^\]]*\].*?\[/table\])", re.DOTALL | re.IGNORECASE)
    position = 0
    for match in token_pattern.finditer(markup):
        intro_text = markup[position:match.start()]
        title = find_last_subsection_title(intro_text)
        slot_ids = resolve_slot_ids(title or "")
        parsed_table = parse_table_rows(match.group(1))
        if title and slot_ids and parsed_table:
            chosen_rows = choose_primary_rows(slot_ids, parsed_table)
            enhancements = parse_section_enhancements(intro_text)
            for index, row in enumerate(chosen_rows):
                slot_id = slot_ids[min(index, len(slot_ids) - 1)]
                entries.append(
                    {
                        "slotId": slot_id,
                        "slotTitle": title,
                        "itemId": row["itemIds"][0],
                        "itemAlternates": row["itemIds"][1:],
                        "gemItemIds": row["gemItemIds"],
                        "enhancements": enhancements,
                        "rowLabel": row["rowLabel"],
                    }
                )
        position = match.end()
    if not entries:
        diagnostics.append("no-slot-entries-parsed")
    return entries, diagnostics


def translate_wowhead_stats(jsonequip: dict[str, Any]) -> dict[str, float]:
    stats: dict[str, float] = {}
    grouped_values: dict[str, list[float]] = {}
    for raw_key, stat_key in STAT_KEY_MAP.items():
        if raw_key not in jsonequip:
            continue
        grouped_values.setdefault(stat_key, []).append(float(jsonequip[raw_key]))
    for stat_key, values in grouped_values.items():
        stats[stat_key] = max(values)
    return stats


def build_item_enchant_info(item_id: int, item_data: dict[str, Any]) -> dict[str, Any]:
    jsonequip = item_data.get("jsonequip") or {}
    stats = translate_wowhead_stats(jsonequip)
    name = item_data.get("name_enus", f"ITEM_{item_id}")
    extra_socket_count = 1 if item_id == 41611 or "BUCKLE" in str(name).upper() else 0
    return {
        "kind": "stats" if stats else "special",
        "label": name,
        "stats": stats or None,
        "sourceType": "item",
        "sourceId": item_id,
        "extraSocketCount": extra_socket_count,
    }


def fetch_spell_data(spell_id: int, fetcher: Fetcher, spell_cache: dict[int, dict[str, Any]]) -> dict[str, Any] | None:
    if spell_id in spell_cache:
        return spell_cache[spell_id]
    html_text = fetcher.fetch_text(
        f"https://www.wowhead.com/wotlk/spell={spell_id}",
        f"wowhead/spells/{spell_id}.html",
    )
    gatherer = extract_gatherer_data(html_text)
    spell_data = (gatherer.get(6) or {}).get(str(spell_id))
    if not spell_data:
        name_match = re.search(r'"name":"(.*?)"', html_text, re.DOTALL)
        desc_match = re.search(r'"description":"(.*?)"', html_text, re.DOTALL)
        spell_data = {
            "name_enus": json.loads(f'"{name_match.group(1)}"') if name_match else f"SPELL_{spell_id}",
            "description_enus": json.loads(f'"{desc_match.group(1)}"') if desc_match else "",
        }
    spell_cache[spell_id] = spell_data
    return spell_data


def build_spell_enchant_info(spell_id: int, spell_data: dict[str, Any]) -> dict[str, Any]:
    name = spell_data.get("name_enus", f"SPELL_{spell_id}")
    description = str(spell_data.get("description_enus") or "")
    text = re.sub(r"<br\s*/?>", " ", description, flags=re.IGNORECASE)
    text = re.sub(r"<[^>]+>", " ", text)
    lowered = text.lower().replace("+", "")
    stats: dict[str, float] = {}
    all_stats_match = re.search(r"increase all stats by (\d+)", lowered)
    if all_stats_match:
        amount = float(all_stats_match.group(1))
        stats.update({"STR": amount, "AGI": amount, "STA": amount, "INT": amount, "SPI": amount})
    if spell_id in PLANNER_ENCHANT_SPELL_OVERRIDES:
        stats.update(PLANNER_ENCHANT_SPELL_OVERRIDES[spell_id])
    shared_patterns = [
        (r"increase agility by (\d+)", "AGI"),
        (r"increasing agility by (\d+)(?!%)", "AGI"),
        (r"increase intellect by (\d+)", "INT"),
        (r"increasing intellect by (\d+)(?!%)", "INT"),
        (r"add (\d+) intellect", "INT"),
        (r"increase attack power by (\d+)", "AP"),
        (r"increasing attack power by (\d+)(?!%)", "AP"),
        (r"increase spell power by (\d+)", "SP"),
        (r"increasing spell power by (\d+)(?!%)", "SP"),
        (r"increase your spell power by (\d+)", "SP"),
        (r"increase critical strike rating by (\d+)", "CRIT"),
        (r"increasing critical strike rating by (\d+)(?!%)", "CRIT"),
        (r"increases its critical strike rating by (\d+)(?!%)", "CRIT"),
        (r"increases its ranged critical strike rating by (\d+)(?!%)", "CRIT"),
        (r"increase hit rating by (\d+)", "HIT"),
        (r"increasing hit rating by (\d+)(?!%)", "HIT"),
        (r"increase haste rating by (\d+)", "HASTE"),
        (r"increasing haste rating by (\d+)(?!%)", "HASTE"),
        (r"increase dodge rating by (\d+)", "DODGE"),
        (r"increase defense rating by (\d+)", "DEFENSE"),
        (r"increasing defense by (\d+)(?!%)", "DEFENSE"),
        (r"increase expertise by (\d+)(?!%)", "EXPERTISE"),
        (r"increase spirit by (\d+)(?!%)", "SPI"),
        (r"increasing spirit by (\d+)(?!%)", "SPI"),
        (r"grant (\d+) spirit", "SPI"),
        (r"increase stamina by (\d+)(?!%)", "STA"),
        (r"increasing stamina by (\d+)(?!%)", "STA"),
        (r"add (\d+) stamina", "STA"),
        (r"restores? (\d+) mana every 5 seconds", "MP5"),
        (r"(\d+) mana every 5 seconds", "MP5"),
        (r"(\d+) mana per 5 seconds", "MP5"),
        (r"increasing block value by (\d+)(?!%)", "BLOCKVALUE"),
        (r"block value by (\d+)(?!%)", "BLOCKVALUE"),
        (r"give (\d+) additional armor", "ARMOR"),
        (r"increasing armor by (\d+)(?!%)", "ARMOR"),
        (r"increase attack power and critical strike rating by (\d+)", "AP"),
    ]
    for pattern, stat_key in shared_patterns:
        found = re.search(pattern, lowered)
        if found:
            amount = float(found.group(1))
            if pattern.startswith("increase attack power and critical strike rating"):
                stats["AP"] = amount
                stats["CRIT"] = amount
            else:
                stats[stat_key] = amount
    dual_rating_match = re.search(r"increase critical strike and hit rating by (\d+)", lowered)
    if dual_rating_match:
        amount = float(dual_rating_match.group(1))
        stats["CRIT"] = amount
        stats["HIT"] = amount
    combo_patterns = [
        (r"adds (\d+) attack power and (\d+) critical strike rating", ("AP", "CRIT")),
        (r"adds (\d+) spell power and (\d+) critical strike rating", ("SP", "CRIT")),
        (r"adds (\d+) spell power and (\d+) mana per 5 seconds", ("SP", "MP5")),
        (r"adds (\d+) stamina and (\d+) defense rating", ("STA", "DEFENSE")),
        (r"adds (\d+) stamina and (\d+) resilience rating", ("STA", "RESILIENCE")),
        (r"increasing spell power by (\d+) and spirit by (\d+)", ("SP", "SPI")),
        (r"increasing spell power by (\d+) and stamina by (\d+)", ("SP", "STA")),
        (r"increasing stamina by (\d+) and agility by (\d+)", ("STA", "AGI")),
        (r"increasing attack power by (\d+) and critical strike rating by (\d+)", ("AP", "CRIT")),
        (r"increasing stamina by (\d+) and resilience rating by (\d+)", ("STA", "RESILIENCE")),
        (r"minor movement speed increase and (\d+) stamina", ("STA", "STA")),
    ]
    for pattern, stat_keys in combo_patterns:
        found = re.search(pattern, lowered)
        if found:
            stats[stat_keys[0]] = float(found.group(1))
            if len(found.groups()) > 1:
                stats[stat_keys[1]] = float(found.group(2))
    special = any(token in lowered for token in ["chance to", "sometimes", "for 15 sec", "for 12 sec", "activated", "parachute", "run speed", "allowing you", "reduce the duration", "control them", "extra weapon damage"])
    if "requires" in lowered or "only the" in lowered or "soulbound" in lowered:
        special = special or bool(stats)
    if "can only be activated" in lowered or "sometimes increase" in lowered:
        if any(token in lowered for token in ["attack power by 400", "spell power by 295", "haste rating by 340"]):
            stats = {}
    return {
        "kind": "special" if special and not stats else ("special" if special else "stats"),
        "label": name,
        "stats": stats or None,
        "sourceType": "spell",
        "sourceId": spell_id,
        "extraSocketCount": 0,
    }


def choose_enchant_for_entry(
    entry: dict[str, Any],
    items_data: dict[str, Any],
    spells_data: dict[str, Any],
    fetcher: Fetcher,
    spell_cache: dict[int, dict[str, Any]],
) -> tuple[dict[str, Any] | None, list[dict[str, Any]]]:
    enchant_id = int(entry.get("plannerEnchantId", 0) or 0)
    if not enchant_id:
        return None, []
    if str(enchant_id) in items_data:
        resolved = build_item_enchant_info(enchant_id, items_data[str(enchant_id)])
        return resolved, [resolved]
    spell_data = spells_data.get(str(enchant_id)) or fetch_spell_data(enchant_id, fetcher, spell_cache)
    if not spell_data:
        return None, []
    resolved = build_spell_enchant_info(enchant_id, spell_data)
    return resolved, [resolved]


def build_gem_payload(gem_item_id: int, items_data: dict[str, Any], fetcher: Fetcher, gem_cache: dict[int, dict[str, Any]]) -> dict[str, Any]:
    if gem_item_id in gem_cache:
        return gem_cache[gem_item_id]
    item_data = items_data.get(str(gem_item_id))
    if not item_data:
        try:
            parsed_item = parse_item_page(gem_item_id, 0, fetcher)
            payload = {
                "itemId": gem_item_id,
                "name": parsed_item["name"],
                "stats": parsed_item.get("stats", {}),
                "resolved": True,
            }
        except Exception:
            payload = {
                "itemId": gem_item_id,
                "name": f"UNKNOWN_GEM_{gem_item_id}",
                "stats": {},
                "resolved": False,
            }
        gem_cache[gem_item_id] = payload
        return payload
    payload = {
        "itemId": gem_item_id,
        "name": item_data.get("name_enus", f"GEM_{gem_item_id}"),
        "stats": translate_wowhead_stats(item_data.get("jsonequip") or {}),
        "resolved": True,
    }
    gem_cache[gem_item_id] = payload
    return payload


def get_item_level(item: dict[str, Any]) -> int:
    return int(item.get("level", 0) or 0)


def resolve_phase_url(main_html: str, phase: str, guide: dict[str, Any]) -> str:
    overrides = guide.get("phase_urls") or {}
    if phase in overrides:
        return str(overrides[phase])
    marker = str(guide.get("phase_url_override") or PHASE_URL_MARKERS[phase]).lower()
    gatherer_data = extract_gatherer_data(main_html)
    for record in (gatherer_data.get(100) or {}).values():
        url = str(record.get("url") or "")
        if marker in url.lower():
            return url.replace("\\/", "/")
    raise RuntimeError(f"Could not resolve {phase} URL for {guide['build_archetype']}")


def load_phase_guide(guide: dict[str, Any], phase: str, fetcher: Fetcher) -> dict[str, Any]:
    main_url = guide["url"]
    main_html = fetcher.fetch_text(main_url, f"wowhead/guides/{slugify_url(main_url)}.html")
    phase_url = resolve_phase_url(main_html, phase, guide)
    phase_html = fetcher.fetch_text(phase_url, f"wowhead/guides/{slugify_url(phase_url)}.html")
    gatherer = extract_gatherer_data(phase_html)
    markup = extract_markup_text(phase_html)
    planners, parse_diagnostics = extract_planner_builds(markup)
    override_path = ((guide.get("planner_overrides") or {}).get(phase) or "").strip()
    if override_path:
        normalized_override_path = normalize_planner_path(override_path)
        planners.insert(
            0,
            {
                "path": normalized_override_path,
                "url": f"{PLANNER_BASE_URL}/{normalized_override_path}",
                "tabLabel": "Manifest Override",
                "selectionPolicy": "manifest-override",
            },
        )
    planner = planners[0] if planners else None
    entries: list[dict[str, Any]] = []
    if planner:
        entries, planner_diagnostics = build_entries_from_planner(planner)
        parse_diagnostics.extend(planner_diagnostics)
    return {
        "phaseUrl": phase_url,
        "planner": planner,
        "plannerCandidates": planners,
        "entries": entries,
        "itemsData": gatherer.get(3, {}),
        "spellsData": gatherer.get(6, {}),
        "parseDiagnostics": parse_diagnostics,
        "markup": markup,
    }


def build_spec_record(
    guide: dict[str, Any],
    phase: str,
    fetcher: Fetcher,
    tables: dict[str, Any],
    item_cache: dict[tuple[int, int], dict[str, Any]],
) -> dict[str, Any]:
    phase_guide = load_phase_guide(guide, phase, fetcher)
    selected_planner_candidate, planner_candidates, selection_diagnostics = select_planner_candidate(
        phase_guide.get("plannerCandidates", []),
        phase,
        fetcher,
        item_cache,
    )
    items_data = phase_guide["itemsData"]
    spells_data = phase_guide["spellsData"]
    planner = (selected_planner_candidate or {}).get("planner", {})
    class_token = guide["class"]
    input_archetype = guide["build_archetype"]
    spec_key = normalize_spec_name(input_archetype, class_token)
    role = guide["role"]
    planner_race_slug = str(planner.get("raceSlug") or "")
    race_token = re.sub(r"[^A-Z]+", "", planner_race_slug.upper()) or None

    runtime_items: list[dict[str, Any]] = []
    item_records: list[dict[str, Any]] = []
    diagnostics = list(phase_guide["parseDiagnostics"])
    diagnostics.extend(selection_diagnostics)
    item_levels: list[int] = []
    slot_gs2 = 0
    slot_legacy = 0
    slot_pvp = 0
    missing_enhancement_count = 0
    gem_cache: dict[int, dict[str, Any]] = {}
    spell_cache: dict[int, dict[str, Any]] = {}
    rejected_slots: list[dict[str, Any]] = []

    sorted_entries = sorted((selected_planner_candidate or {}).get("entries", []), key=lambda entry: entry["slotId"])
    if not sorted_entries:
        return {
            "class": class_token,
            "spec": spec_key,
            "resolved_spec": spec_key,
            "input_archetype": input_archetype,
            "role": role,
            "race": race_token,
            "phase": phase,
            "guide_url": guide["url"],
            "phase_url": phase_guide["phaseUrl"],
            "planner_path": planner.get("path"),
            "planner_url": planner.get("url"),
            "planner_tab_label": planner.get("tabLabel"),
            "planner_selection_policy": planner.get("selectionPolicy"),
            "planner_validation_status": "missing",
            "planner_rejection_reasons": selection_diagnostics or ["planner-build-missing"],
            "planner_candidates": safe_json_value(planner_candidates),
            "parse_status": "failed",
            "parse_diagnostics": diagnostics or ["planner-build-missing"],
            "item_count": 0,
            "avg_item_level": 0,
            "legacy_gs": 0,
            "gs2_pre_cap": 0,
            "gs2_cap_bonus": 0,
            "gs2_final": 0,
            "pvp_gs": 0,
            "missing_enhancement_count": 0,
            "profile_summary": {},
            "cap_breakdown": {},
            "cap_stats": {},
            "rejected_slot_count": 0,
            "rejected_slots": [],
            "items": [],
        }
    for entry in sorted_entries:
        cache_key = (entry["itemId"], entry["slotId"])
        if cache_key not in item_cache:
            item_cache[cache_key] = parse_item_page(entry["itemId"], entry["slotId"], fetcher)
        prepared_item = dict(item_cache[cache_key])
        prepared_item["slotId"] = entry["slotId"]
        prepared_item["slot"] = get_item_slot_value(prepared_item["equipLoc"], tables["GS_ItemTypes"])
        prepared_item["legacyBase"] = calculate_legacy_base(prepared_item, tables["GS_ItemTypes"], tables["GS_Formula"])
        if class_token == "HUNTER":
            prepared_item["legacyBase"] = get_hunter_legacy(entry["slotId"], prepared_item)

        gem_payloads = [build_gem_payload(gem_item_id, items_data, fetcher, gem_cache) for gem_item_id in entry["gemItemIds"]]
        prepared_item["gemStats"] = [gem["stats"] for gem in gem_payloads if gem.get("stats")]

        chosen_enchant, all_enchants = choose_enchant_for_entry(entry, items_data, spells_data, fetcher, spell_cache)
        prepared_item["enchantInfo"] = chosen_enchant or {}
        prepared_item["enchantId"] = int(entry.get("plannerEnchantId", 0) or 0)
        prepared_item["hasEnchant"] = prepared_item["enchantId"] > 0
        prepared_item["resilience"] = float(prepared_item.get("stats", {}).get("RESILIENCE", 0))
        if any(not gem.get("resolved") for gem in gem_payloads):
            unresolved_gems = sum(1 for gem in gem_payloads if not gem.get("resolved"))
            missing_enhancement_count += unresolved_gems
            diagnostics.append(f"slot-{entry['slotId']}:unresolved-gem-data")
        if prepared_item["hasEnchant"] and not chosen_enchant:
            missing_enhancement_count += 1
            diagnostics.append(f"slot-{entry['slotId']}:unresolved-enchant")
        if entry.get("plannerRandomEnchantId"):
            diagnostics.append(f"slot-{entry['slotId']}:random-enchant-present")
            missing_enhancement_count += 1

        item_gs2, item_pvp, flags, debug = score_item_with_debug(prepared_item, class_token, spec_key, tables)
        slot_gs2 += item_gs2
        slot_legacy += int(prepared_item["legacyBase"])
        slot_pvp += item_pvp
        if entry["slotId"] not in IGNORED_BENCHMARK_SLOT_IDS:
            item_levels.append(get_item_level(prepared_item))
        runtime_items.append(prepared_item)
        if "incompatible-item" in flags:
            rejected_slots.append(
                {
                    "slot_id": entry["slotId"],
                    "slot_title": entry["slotTitle"],
                    "name": prepared_item["name"],
                    "equip_loc": prepared_item["equipLoc"],
                    "flags": list(flags),
                }
            )
        item_records.append(
            {
                "slot_id": entry["slotId"],
                "slot_title": entry["slotTitle"],
                "name": prepared_item["name"],
                "item_id": prepared_item["itemId"],
                "item_level": get_item_level(prepared_item),
                "equip_loc": prepared_item["equipLoc"],
                "planner_slot_gems": safe_json_value(entry.get("gemSockets", {})),
                "planner_enchant_id": int(entry.get("plannerEnchantId", 0) or 0),
                "planner_random_enchant_id": int(entry.get("plannerRandomEnchantId", 0) or 0),
                "gems": safe_json_value(gem_payloads),
                "planner_enchant_candidates": safe_json_value(all_enchants),
                "chosen_enchant": safe_json_value(chosen_enchant),
                "legacy_base": int(prepared_item["legacyBase"]),
                "gs2": item_gs2,
                "pvp_gs": item_pvp,
                "flags": flags,
                "score_debug": safe_json_value(debug),
            }
        )

    cap_bonus, cap_breakdown, cap_stats = apply_character_caps(class_token, spec_key, runtime_items, slot_gs2, tables, race_token)
    final_gs2 = slot_gs2 + cap_bonus
    planner_validation_status = (selected_planner_candidate or {}).get("validation_status", "missing")
    if planner_validation_status == "rejected":
        parse_status = "failed"
    elif missing_enhancement_count:
        parse_status = "partial"
    else:
        parse_status = "complete"
    profile, resolved_spec = get_profile(class_token, spec_key, tables, race_token=race_token)
    return {
        "class": class_token,
        "spec": spec_key,
        "resolved_spec": resolved_spec,
        "input_archetype": input_archetype,
        "role": role,
        "race": race_token,
        "phase": phase,
        "guide_url": guide["url"],
        "phase_url": phase_guide["phaseUrl"],
        "planner_path": planner.get("path"),
        "planner_url": planner.get("url"),
        "planner_tab_label": planner.get("tabLabel"),
        "planner_selection_policy": planner.get("selectionPolicy"),
        "planner_validation_status": planner_validation_status,
        "planner_rejection_reasons": selection_diagnostics,
        "planner_candidates": safe_json_value(
            [
                {
                    "path": candidate["planner"].get("path"),
                    "tabLabel": candidate["planner"].get("tabLabel"),
                    "avg_item_level": candidate["avg_item_level"],
                    "validation_status": candidate["validation_status"],
                    "rejection_reasons": candidate["rejection_reasons"],
                }
                for candidate in planner_candidates
            ]
        ),
        "parse_status": parse_status,
        "parse_diagnostics": diagnostics,
        "item_count": len(runtime_items),
        "avg_item_level": round(sum(item_levels) / len(item_levels), 2) if item_levels else 0,
        "legacy_gs": slot_legacy,
        "gs2_pre_cap": slot_gs2,
        "gs2_cap_bonus": cap_bonus,
        "gs2_final": final_gs2,
        "pvp_gs": slot_pvp,
        "delta_from_legacy": final_gs2 - slot_legacy,
        "pve_bonus_bucket_effective": slot_gs2 - slot_legacy,
        "missing_enhancement_count": missing_enhancement_count,
        "profile_summary": safe_json_value(profile),
        "cap_breakdown": safe_json_value(cap_breakdown),
        "cap_stats": safe_json_value(cap_stats),
        "rejected_slot_count": len(rejected_slots),
        "rejected_slots": safe_json_value(rejected_slots),
        "items": item_records,
    }


def match_spec_filter(guide: dict[str, Any], spec_filter: str | None) -> bool:
    if not spec_filter:
        return True
    token = spec_filter.strip().upper()
    archetype = guide["build_archetype"].upper()
    canonical = normalize_spec_name(guide["build_archetype"], guide["class"]).upper()
    legacy_suffix = archetype.split("_", 1)[1] if "_" in archetype else archetype
    canonical_suffix = canonical.split("_", 1)[1] if "_" in canonical else canonical
    return token in {
        archetype,
        canonical,
        legacy_suffix,
        canonical_suffix,
        f"{guide['class']}:{archetype}".upper(),
        f"{guide['class']}:{canonical}".upper(),
        f"{guide['class']}/{archetype}".upper(),
        f"{guide['class']}/{canonical}".upper(),
        f"{guide['class']}:{legacy_suffix}".upper(),
        f"{guide['class']}:{canonical_suffix}".upper(),
        f"{guide['class']}/{legacy_suffix}".upper(),
        f"{guide['class']}/{canonical_suffix}".upper(),
    }


def build_summary(records: list[dict[str, Any]]) -> dict[str, Any]:
    for record in records:
        enrich_component_metrics(record)
    scores = [record["gs2_final"] for record in records if record["parse_status"] != "failed"]
    ordered_phases = sorted({record["phase"] for record in records}, key=lambda phase: PHASE_SORT_ORDER.get(phase, 999))
    non_failed = [record for record in records if record["parse_status"] != "failed"]
    ranking = [
        {
            "class": record["class"],
            "spec": record["spec"],
            "gs2_final": record["gs2_final"],
            "parse_status": record["parse_status"],
        }
        for record in sorted(records, key=lambda row: row["gs2_final"], reverse=True)
    ]
    phase_summary = {
        phase: build_phase_component_summary([record for record in non_failed if record["phase"] == phase])
        for phase in ordered_phases
    }
    for row in phase_summary.values():
        row["median_target_delta"] = MEDIAN_TARGET_DELTA
        row["median_delta_error"] = row.get("median_delta_from_legacy", 0) - MEDIAN_TARGET_DELTA
        row["spread_gap_to_target"] = row.get("spread_gs2_final", 0) - 300

    phase_top_outliers = {}
    phase_bottom_outliers = {}
    for phase in ordered_phases:
        phase_records = [record for record in non_failed if record["phase"] == phase]
        ordered_records = sorted(phase_records, key=lambda row: row["gs2_final"])
        phase_bottom_outliers[phase] = [
            {"class": row["class"], "spec": row["spec"], "gs2_final": row["gs2_final"], "delta_from_legacy": row.get("delta_from_legacy", 0)}
            for row in ordered_records[:5]
        ]
        phase_top_outliers[phase] = [
            {"class": row["class"], "spec": row["spec"], "gs2_final": row["gs2_final"], "delta_from_legacy": row.get("delta_from_legacy", 0)}
            for row in ordered_records[-5:][::-1]
        ]

    spec_phase_trends = build_phase_growth_trends(non_failed, "spec", ordered_phases)
    class_phase_trends = build_phase_growth_trends(non_failed, "class", ordered_phases)

    target_distance_ranking = []
    for record in non_failed:
        target_distance_ranking.append(
            {
                "class": record["class"],
                "spec": record["spec"],
                "phase": record["phase"],
                "delta_from_legacy": record.get("delta_from_legacy", 0),
                "target_delta": MEDIAN_TARGET_DELTA,
                "target_delta_error": record.get("delta_from_legacy", 0) - MEDIAN_TARGET_DELTA,
            }
        )
    target_distance_ranking.sort(key=lambda row: abs(row["target_delta_error"]), reverse=True)
    phase_4_target_outliers = [row for row in target_distance_ranking if row["phase"] == "PHASE_4"]

    return {
        "spec_count_processed": len(records),
        "phase_counts": {
            phase: sum(1 for record in records if record["phase"] == phase)
            for phase in sorted({record["phase"] for record in records})
        },
        "parse_status_counts": {
            status: sum(1 for record in records if record["parse_status"] == status)
            for status in sorted({record["parse_status"] for record in records})
        },
        "planner_validation_counts": {
            status: sum(1 for record in records if record.get("planner_validation_status") == status)
            for status in sorted({record.get("planner_validation_status", "missing") for record in records})
        },
        "scrape_failures": [f"{record['class']}:{record['spec']}" for record in records if record["parse_status"] == "failed"],
        "records_with_rejected_slots": [f"{record['class']}:{record['spec']}" for record in records if record.get("rejected_slot_count", 0) > 0],
        "score_ranking": ranking,
        "median_gs2_final": statistics.median(scores) if scores else 0,
        "min_gs2_final": min(scores) if scores else 0,
        "max_gs2_final": max(scores) if scores else 0,
        "spread_gs2_final": (max(scores) - min(scores)) if len(scores) >= 2 else 0,
        "median_target_delta": MEDIAN_TARGET_DELTA,
        "phase_summary": phase_summary,
        "phase_top_outliers": phase_top_outliers,
        "phase_bottom_outliers": phase_bottom_outliers,
        "spec_phase_trends": spec_phase_trends,
        "class_phase_trends": class_phase_trends,
        "largest_phase_drifts": spec_phase_trends[:10],
        "largest_target_delta_errors": target_distance_ranking[:10],
        "phase_4_target_outliers": phase_4_target_outliers[:10],
    }


def build_public_wowhead_item(item: dict[str, Any]) -> dict[str, Any]:
    return {
        "slot_id": item.get("slot_id"),
        "slot_name": item.get("slot_name"),
        "item_id": item.get("item_id"),
        "name": item.get("name"),
        "item_level": item.get("item_level"),
        "legacy_base": item.get("legacy_base"),
        "gs2": item.get("gs2"),
        "pvp_gs": item.get("pvp_gs"),
        "flags": safe_json_value(item.get("flags")),
        "chosen_enchant": safe_json_value(item.get("chosen_enchant")),
        "gems": safe_json_value(item.get("gems")),
    }


def build_public_wowhead_record(record: dict[str, Any]) -> dict[str, Any]:
    return {
        "class": record.get("class"),
        "spec": record.get("spec"),
        "resolved_spec": record.get("resolved_spec"),
        "input_archetype": record.get("input_archetype"),
        "role": record.get("role"),
        "race": record.get("race"),
        "phase": record.get("phase"),
        "parse_status": record.get("parse_status"),
        "parse_diagnostics": safe_json_value(record.get("parse_diagnostics")),
        "item_count": record.get("item_count"),
        "avg_item_level": record.get("avg_item_level"),
        "legacy_gs": record.get("legacy_gs"),
        "gs2_pre_cap": record.get("gs2_pre_cap"),
        "gs2_cap_bonus": record.get("gs2_cap_bonus"),
        "gs2_final": record.get("gs2_final"),
        "pvp_gs": record.get("pvp_gs"),
        "delta_from_legacy": record.get("delta_from_legacy"),
        "pve_bonus_bucket_effective": record.get("pve_bonus_bucket_effective"),
        "missing_enhancement_count": record.get("missing_enhancement_count"),
        "guide_url": record.get("guide_url"),
        "phase_url": record.get("phase_url"),
        "planner_url": record.get("planner_url"),
        "planner_tab_label": record.get("planner_tab_label"),
        "planner_selection_policy": record.get("planner_selection_policy"),
        "planner_validation_status": record.get("planner_validation_status"),
        "planner_rejection_reasons": safe_json_value(record.get("planner_rejection_reasons")),
        "rejected_slot_count": record.get("rejected_slot_count"),
        "rejected_slots": safe_json_value(record.get("rejected_slots")),
        "cap_breakdown": safe_json_value(record.get("cap_breakdown")),
        "cap_stats": safe_json_value(record.get("cap_stats")),
        "items": [build_public_wowhead_item(item) for item in record.get("items", [])],
    }


def write_outputs(output_dir: Path, records: list[dict[str, Any]], summary: dict[str, Any], phase: str, spec_filter: str | None) -> tuple[Path, Path]:
    output_dir.mkdir(parents=True, exist_ok=True)
    if phase == ALL_PHASES_LABEL:
        csv_path = output_dir / "wowhead_bis_all_phases_benchmark.csv"
        json_path = output_dir / "wowhead_bis_all_phases_benchmark.json"
    else:
        phase_slug = phase.lower()
        csv_path = output_dir / f"wowhead_bis_{phase_slug}_benchmark.csv"
        json_path = output_dir / f"wowhead_bis_{phase_slug}_benchmark.json"
    fieldnames = [
        "class",
        "spec",
        "resolved_spec",
        "role",
        "race",
        "phase",
        "parse_status",
        "item_count",
        "avg_item_level",
        "legacy_gs",
        "gs2_pre_cap",
        "gs2_cap_bonus",
        "gs2_final",
        "pvp_gs",
        "delta_from_legacy",
        "pve_bonus_bucket_effective",
        "missing_enhancement_count",
        "guide_url",
        "phase_url",
        "planner_url",
        "planner_tab_label",
        "planner_validation_status",
        "rejected_slot_count",
    ]
    with csv_path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        for record in records:
            writer.writerow({name: record.get(name, "") for name in fieldnames})
    payload = {
        "run_metadata": {
            "generated_at_utc": datetime.now(timezone.utc).isoformat(),
            "phase": phase,
            "phases": BENCHMARK_PHASES if phase == ALL_PHASES_LABEL else [phase],
            "spec_filter": spec_filter,
            "artifacts": [str(csv_path), str(json_path)],
        },
        "assumptions": [
            "Each spec record is a synthetic build scraped from the current Wowhead WotLK PvE guide inventory.",
            "The parser prefers the first valid embedded Wowhead gear-planner build whose tab label and item-level band fit the requested phase.",
            "Planner-decoded items, gems, and enchants are the authoritative source for each benchmark record.",
            "Guide tables are non-authoritative and are not used to synthesize or patch equipped slots.",
            "A record is marked partial only when planner-encoded gem or enchant data could not be fully resolved.",
            "Profession-sensitive or proc-style enchants are parsed from spell data and kept in parity-friendly form. Temporary proc-only bonuses remain unscored.",
        ],
        "summary": summary,
        "records": [build_public_wowhead_record(record) for record in records],
    }
    json_path.write_text(json.dumps(payload, indent=2), encoding="utf-8")
    return csv_path, json_path


def run_benchmark(
    manifest_path: Path,
    output_dir: Path,
    cache_dir: Path,
    phase: str,
    spec_filter: str | None,
    refresh: bool,
    delay: float,
) -> tuple[list[dict[str, Any]], dict[str, Any], tuple[Path, Path]]:
    log_progress(f"[init] Loading manifest from {manifest_path}")
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    log_progress(f"[init] Loading runtime tables from {REPO_ROOT}")
    tables = load_runtime_tables(REPO_ROOT)
    apply_runtime_constants(tables)
    fetcher = Fetcher(cache_dir=cache_dir, refresh=refresh, delay=delay)
    item_cache: dict[tuple[int, int], dict[str, Any]] = {}
    records: list[dict[str, Any]] = []
    requested_phases = BENCHMARK_PHASES if phase == ALL_PHASES_LABEL else (phase,)
    manifest_phases = set(manifest.get("phases") or [])
    phases_to_run = [phase_name for phase_name in requested_phases if not manifest_phases or phase_name in manifest_phases]
    guides_to_run = [guide for guide in manifest["guides"] if match_spec_filter(guide, spec_filter)]
    total_tasks = len(guides_to_run) * len(phases_to_run)
    log_progress(
        f"[init] Running {len(guides_to_run)} guide archetypes across {len(phases_to_run)} phase(s) "
        f"for {total_tasks} benchmark record(s)"
    )
    completed = 0
    for guide in guides_to_run:
        if not match_spec_filter(guide, spec_filter):
            continue
        for phase_name in phases_to_run:
            completed += 1
            label = f"{guide['class']}:{guide['build_archetype']}"
            log_progress(f"[{completed}/{total_tasks}] Processing {label} [{phase_name}]")
            record = build_spec_record(guide, phase_name, fetcher, tables, item_cache)
            records.append(record)
            log_progress(
                f"[{completed}/{total_tasks}] Finished {label} [{phase_name}] "
                f"status={record['parse_status']} gs2={record.get('gs2_final', 0)}"
            )
    log_progress(f"[summary] Building summary for {len(records)} record(s)")
    summary = build_summary(records)
    log_progress(f"[write] Writing outputs to {output_dir}")
    outputs = write_outputs(output_dir, records, summary, phase, spec_filter)
    return records, summary, outputs


def build_arg_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Benchmark Wowhead WotLK BiS Phase gear against GearScore2 parity logic.")
    parser.add_argument("--phase", default=DEFAULT_PHASE_LABEL, choices=sorted(list(PHASE_URL_MARKERS) + [ALL_PHASES_LABEL]))
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--spec", default=None, help="Run a single archetype, for example MAGE_ARCANE or MAGE:ARCANE.")
    parser.add_argument("--refresh", action="store_true")
    parser.add_argument("--delay", type=float, default=0.0)
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT_DIR)
    return parser


def main() -> None:
    parser = build_arg_parser()
    args = parser.parse_args()
    _, summary, outputs = run_benchmark(
        manifest_path=args.manifest,
        output_dir=args.output_dir,
        cache_dir=DEFAULT_CACHE_DIR,
        phase=args.phase,
        spec_filter=args.spec,
        refresh=args.refresh,
        delay=args.delay,
    )
    print(f"Wrote {outputs[0]}")
    print(f"Wrote {outputs[1]}")
    print(
        f"Processed {summary['spec_count_processed']} specs | "
        f"median GS2={summary['median_gs2_final']} | spread={summary['spread_gs2_final']}"
    )


if __name__ == "__main__":
    main()
