#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
import html
import json
import math
import re
import statistics
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[1]
TOOLS_DIR = REPO_ROOT / "tools"
DEFAULT_DATASET = TOOLS_DIR / "data" / "warmane_onyxia_top_chars.txt"
DEFAULT_CACHE_DIR = TOOLS_DIR / "cache"
DEFAULT_OUTPUT_DIR = REPO_ROOT / "tools" / "output"

WARMANE_PROFILE_RE = re.compile(
    r"armory\.warmane\.com/character/(?P<name>[^/]+)/(?P<realm>[^/]+)/profile",
    re.IGNORECASE,
)

USER_AGENT = "GearScore2-Benchmark/1.0"

GS_GS2_STAT_SCALE = 0.12
GS_GEM_SCALE = 0.35
GS_ENCHANT_SCALE = 0.35
GS_PVE_RESILIENCE_RATE = 0.0015
GS_PVP_RESILIENCE_RATE = 0.0020
GS_PVE_RESILIENCE_FLOOR = 0.70
GS_PVP_RESILIENCE_CAP = 1.35
GS_CAP_BONUS_ANCHOR_LOW_GS2 = 4000
GS_CAP_BONUS_ANCHOR_HIGH_GS2 = 5000
GS_CAP_BONUS_ANCHOR_LOW_BONUS = 180
GS_CAP_BONUS_ANCHOR_HIGH_BONUS = 90
GS_CAP_BONUS_MIN = 20
GS_CAP_BONUS_MAX = 250
GS_OFFSPEC_MIN_RATIO = 0.05
GS_OFFSPEC_FIT_MATCH_RATIO_FLOOR = 0.35
GS_OFFSPEC_FIT_MATCH_RATIO_FULL = 0.75
GS_OFFSPEC_FIT_MULTIPLIER_FLOOR = 0.45
GS_OFFSPEC_FIT_SIGNATURE_PENALTY = 0.80
GS_INCOMPATIBLE_PVE_BONUS_SCALE = 0.15

PROFILE_SLOT_ORDER = [
    1, 2, 3, 15, 5, 4, 19, 9,
    10, 6, 7, 8, 11, 12, 13, 14,
    16, 17, 18,
]
PROFILE_SLOT_SECTIONS = [
    ("item-left", [1, 2, 3, 15, 5, 4, 19, 9]),
    ("item-right", [10, 6, 7, 8, 11, 12, 13, 14]),
    ("item-bottom", [16, 17, 18]),
]

STAT_ALIASES = {
    "strength": "STR",
    "agility": "AGI",
    "stamina": "STA",
    "intellect": "INT",
    "spirit": "SPI",
    "attack power": "AP",
    "ranged attack power": "RAP",
    "spell power": "SP",
    "hit rating": "HIT",
    "critical strike rating": "CRIT",
    "critical rating": "CRIT",
    "haste rating": "HASTE",
    "resilience rating": "RESILIENCE",
    "armor penetration rating": "ARP",
    "expertise rating": "EXPERTISE",
    "defense rating": "DEFENSE",
    "defense skill rating": "DEFENSE",
    "dodge rating": "DODGE",
    "parry rating": "PARRY",
    "block rating": "BLOCK",
    "block value": "BLOCKVALUE",
    "mana per 5 sec": "MP5",
    "mana every 5 sec": "MP5",
}

ARMOR_SUBTYPE_TO_RANK = {
    "CLOTH": 1,
    "LEATHER": 2,
    "MAIL": 3,
    "PLATE": 4,
}

SLOT_TO_EQUIPLOC = {
    1: "INVTYPE_HEAD",
    2: "INVTYPE_NECK",
    3: "INVTYPE_SHOULDER",
    4: "INVTYPE_BODY",
    5: "INVTYPE_CHEST",
    6: "INVTYPE_WAIST",
    7: "INVTYPE_LEGS",
    8: "INVTYPE_FEET",
    9: "INVTYPE_WRIST",
    10: "INVTYPE_HAND",
    11: "INVTYPE_FINGER",
    12: "INVTYPE_FINGER",
    13: "INVTYPE_TRINKET",
    14: "INVTYPE_TRINKET",
    15: "INVTYPE_CLOAK",
    16: "INVTYPE_WEAPONMAINHAND",
    17: "INVTYPE_WEAPONOFFHAND",
    18: "INVTYPE_RANGED",
    19: "INVTYPE_TABARD",
}

IGNORED_STATS_FOR_FLAGS = {"STA"}
GEM_SUBCLASS_TO_COLORS = {
    0: {"RED"},
    1: {"BLUE"},
    2: {"YELLOW"},
    3: {"RED", "BLUE"},
    4: {"BLUE", "YELLOW"},
    5: {"RED", "YELLOW"},
    6: {"META"},
    8: {"RED", "BLUE", "YELLOW"},
}

CLASS_NAME_ALIASES = {
    "WARRIOR": "WARRIOR",
    "PALADIN": "PALADIN",
    "HUNTER": "HUNTER",
    "ROGUE": "ROGUE",
    "PRIEST": "PRIEST",
    "DEATH KNIGHT": "DEATHKNIGHT",
    "SHAMAN": "SHAMAN",
    "MAGE": "MAGE",
    "WARLOCK": "WARLOCK",
    "DRUID": "DRUID",
}

IGNORED_BENCHMARK_SLOT_IDS = {4, 19}
DIAGNOSTIC_CATEGORY_INFORMATIONAL = "informational"
DIAGNOSTIC_CATEGORY_OPTIMIZATION = "optimization_issue"
DIAGNOSTIC_CATEGORY_COMPATIBILITY = "compatibility_issue"
DIAGNOSTIC_CATEGORY_BLOCKER = "benchmark_blocker"
DIAGNOSTIC_CATEGORY_ORDER = [
    DIAGNOSTIC_CATEGORY_INFORMATIONAL,
    DIAGNOSTIC_CATEGORY_OPTIMIZATION,
    DIAGNOSTIC_CATEGORY_COMPATIBILITY,
    DIAGNOSTIC_CATEGORY_BLOCKER,
]
QUALITY_TIER_CLEAN = "CLEAN"
QUALITY_TIER_REVIEW = "REVIEW"
QUALITY_TIER_NOISY = "NOISY"
QUALITY_TIER_BLOCKED = "BLOCKED"
BALANCE_TARGET_SPREAD_GS2 = 200
PHASE_SORT_ORDER = {
    "PRE_RAID": 0,
    "PHASE_1": 1,
    "PHASE_2": 2,
    "PHASE_3": 3,
    "PHASE_4": 4,
}
@dataclass
class WarmaneCharacterRef:
    url: str
    name: str
    realm: str


@dataclass
class ResolvedGem:
    source_id: int
    item_id: int | None
    name: str
    quality: int
    stats: dict[str, float]
    colors: set[str]
    used_fallback: bool = False


class Fetcher:
    def __init__(self, cache_dir: Path, refresh: bool = False, delay: float = 0.0) -> None:
        self.cache_dir = cache_dir
        self.refresh = refresh
        self.delay = delay

    def fetch_text(self, url: str, cache_key: str) -> str:
        cache_path = self.cache_dir / cache_key
        cache_path.parent.mkdir(parents=True, exist_ok=True)
        if cache_path.exists() and not self.refresh:
            return cache_path.read_text(encoding="utf-8")
        request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                body = response.read().decode("utf-8", errors="replace")
        except urllib.error.URLError as exc:
            if cache_path.exists():
                return cache_path.read_text(encoding="utf-8")
            raise RuntimeError(f"Failed to fetch {url}: {exc}") from exc
        cache_path.write_text(body, encoding="utf-8")
        if self.delay > 0:
            time.sleep(self.delay)
        return body


class LuaTableParser:
    def __init__(self, text: str, env: dict[str, Any] | None = None) -> None:
        self.text = text
        self.env = env or {}
        self.tokens = self._tokenize(text)
        self.index = 0

    @staticmethod
    def _tokenize(text: str) -> list[tuple[str, str]]:
        tokens: list[tuple[str, str]] = []
        i = 0
        while i < len(text):
            ch = text[i]
            if ch in " \t\r\n":
                i += 1
                continue
            if ch == "-" and i + 1 < len(text) and text[i + 1] == "-":
                while i < len(text) and text[i] != "\n":
                    i += 1
                continue
            if ch in "{}[]=,+-*/()":
                tokens.append((ch, ch))
                i += 1
                continue
            if ch in ('"', "'"):
                quote = ch
                i += 1
                start = i
                buf = []
                while i < len(text):
                    cur = text[i]
                    if cur == "\\" and i + 1 < len(text):
                        buf.append(text[start:i])
                        buf.append(text[i + 1])
                        i += 2
                        start = i
                        continue
                    if cur == quote:
                        break
                    i += 1
                buf.append(text[start:i])
                tokens.append(("STRING", "".join(buf)))
                i += 1
                continue
            if ch.isdigit() or (ch == "-" and i + 1 < len(text) and text[i + 1].isdigit()):
                start = i
                i += 1
                while i < len(text) and (text[i].isdigit() or text[i] == "."):
                    i += 1
                tokens.append(("NUMBER", text[start:i]))
                continue
            if ch.isalpha() or ch == "_":
                start = i
                i += 1
                while i < len(text) and (text[i].isalnum() or text[i] in "._"):
                    i += 1
                tokens.append(("IDENT", text[start:i]))
                continue
            raise ValueError(f"Unsupported Lua token at {i}: {text[i:i+20]!r}")
        return tokens

    def parse(self) -> Any:
        value = self._parse_expression()
        if self.index != len(self.tokens):
            raise ValueError("Unexpected trailing tokens in Lua table")
        return value

    def _peek(self) -> tuple[str, str] | None:
        if self.index >= len(self.tokens):
            return None
        return self.tokens[self.index]

    def _advance(self) -> tuple[str, str]:
        token = self.tokens[self.index]
        self.index += 1
        return token

    def _expect(self, kind: str) -> tuple[str, str]:
        token = self._advance()
        if token[0] != kind:
            raise ValueError(f"Expected {kind}, got {token}")
        return token

    def _parse_primary(self) -> Any:
        token = self._peek()
        if token is None:
            raise ValueError("Unexpected end of Lua input")
        if token[0] == "{":
            return self._parse_table()
        if token[0] == "(":
            self._advance()
            value = self._parse_expression()
            self._expect(")")
            return value
        if token[0] == "STRING":
            return self._advance()[1]
        if token[0] == "NUMBER":
            raw = self._advance()[1]
            return float(raw) if "." in raw else int(raw)
        if token[0] == "IDENT":
            ident = self._advance()[1]
            if ident == "true":
                return True
            if ident == "false":
                return False
            if ident == "nil":
                return None
            return self._resolve_ident(ident)
        if token[0] == "-":
            self._advance()
            value = self._parse_primary()
            if not isinstance(value, (int, float)):
                raise ValueError(f"Unsupported unary minus for {value!r}")
            return -value
        raise ValueError(f"Unexpected token {token}")

    def _parse_term(self) -> Any:
        value = self._parse_primary()
        while True:
            token = self._peek()
            if token is None or token[0] not in {"*", "/"}:
                return value
            operator = self._advance()[0]
            right = self._parse_primary()
            if not isinstance(value, (int, float)) or not isinstance(right, (int, float)):
                raise ValueError(f"Unsupported Lua arithmetic {value!r} {operator} {right!r}")
            if operator == "*":
                value = value * right
            else:
                value = value / right

    def _parse_expression(self) -> Any:
        value = self._parse_term()
        while True:
            token = self._peek()
            if token is None or token[0] not in {"+", "-"}:
                return value
            operator = self._advance()[0]
            right = self._parse_term()
            if not isinstance(value, (int, float)) or not isinstance(right, (int, float)):
                raise ValueError(f"Unsupported Lua arithmetic {value!r} {operator} {right!r}")
            if operator == "+":
                value = value + right
            else:
                value = value - right

    def _resolve_ident(self, ident: str) -> Any:
        if "." not in ident:
            return ident
        parts = ident.split(".")
        value: Any = self.env.get(parts[0])
        if value is None:
            raise ValueError(f"Unknown Lua reference {ident}")
        for part in parts[1:]:
            if isinstance(value, dict) and part in value:
                value = value[part]
            else:
                raise ValueError(f"Unknown Lua reference {ident}")
        return value

    def _parse_table(self) -> Any:
        self._expect("{")
        keyed: dict[Any, Any] = {}
        array: list[Any] = []
        saw_keyed = False
        saw_array = False
        while True:
            token = self._peek()
            if token is None:
                raise ValueError("Unterminated Lua table")
            if token[0] == "}":
                self._advance()
                break
            if token[0] == ",":
                self._advance()
                continue
            next_token = self.tokens[self.index + 1] if self.index + 1 < len(self.tokens) else None
            if token[0] == "IDENT" and next_token and next_token[0] == "=":
                key = self._advance()[1]
                self._expect("=")
                keyed[key] = self._parse_expression()
                saw_keyed = True
            elif token[0] == "[":
                self._advance()
                key = self._parse_expression()
                self._expect("]")
                self._expect("=")
                keyed[key] = self._parse_expression()
                saw_keyed = True
            else:
                array.append(self._parse_expression())
                saw_array = True
            if self._peek() and self._peek()[0] == ",":
                self._advance()
        if saw_keyed and not saw_array:
            return keyed
        if saw_array and not saw_keyed:
            return array
        if not saw_keyed and not saw_array:
            return {}
        for index, value in enumerate(array, start=1):
            keyed[index] = value
        return keyed


def extract_lua_table(source: str, name: str) -> str:
    needle = f"{name} ="
    start = source.find(needle)
    if start == -1:
        raise ValueError(f"Could not find Lua table {name}")
    brace_start = source.find("{", start)
    if brace_start == -1:
        raise ValueError(f"Could not find opening brace for {name}")
    depth = 0
    in_string = False
    string_char = ""
    escaped = False
    for index in range(brace_start, len(source)):
        ch = source[index]
        if in_string:
            if escaped:
                escaped = False
            elif ch == "\\":
                escaped = True
            elif ch == string_char:
                in_string = False
            continue
        if ch in ("'", '"'):
            in_string = True
            string_char = ch
            continue
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                return source[brace_start:index + 1]
    raise ValueError(f"Could not find closing brace for {name}")


def extract_lua_number_assignment(source: str, name: str) -> float:
    match = re.search(rf"(?m)^\s*{re.escape(name)}\s*=\s*(-?\d+(?:\.\d+)?)\s*$", source)
    if not match:
        raise ValueError(f"Could not find Lua number assignment for {name}")
    return float(match.group(1))


def load_runtime_tables(repo_root: Path) -> dict[str, Any]:
    info_text = (repo_root / "Data" / "RuntimeTables.lua").read_text(encoding="utf-8")
    core_text = (repo_root / "Runtime" / "Bootstrap.lua").read_text(encoding="utf-8")
    env: dict[str, Any] = {}
    table_names = {
        "GS_ItemTypes": "Tables.ItemTypes",
        "GS_Formula": "Tables.Formula",
        "GS_EnchantSlots": "Tables.EnchantSlots",
        "GS_ArmorClassOrder": "Tables.ArmorClassOrder",
        "GS_ClassDefaults": "Tables.ClassDefaults",
        "GS_ClassSpecOrder": "Tables.ClassSpecOrder",
        "GS_SpecProfiles": "Tables.SpecProfiles",
        "GS_RatingConversions": "Tables.RatingConversions",
        "GS_CapSegmentDefaults": "Tables.CapSegmentDefaults",
        "GS_PermanentCapRacials": "Tables.PermanentCapRacials",
        "GS_CapProfiles": "Tables.CapProfiles",
    }
    env["Tables"] = {}
    for legacy_name, namespaced_name in table_names.items():
        table_text = extract_lua_table(info_text, namespaced_name)
        parsed = LuaTableParser(table_text, env).parse()
        env[legacy_name] = parsed
        env["Tables"][legacy_name[3:]] = parsed

    enchant_text = (repo_root / "Data" / "EnchantData.lua").read_text(encoding="utf-8")
    env["GS_EnchantValues"] = LuaTableParser(
        extract_lua_table(enchant_text, "GS.Data.Enchants.Values"),
        env,
    ).parse()
    env["Enchants"] = {"Values": env["GS_EnchantValues"]}
    constants = LuaTableParser(extract_lua_table(core_text, "GS.Constants"), env).parse()
    for name in [
        "GS_GS2_STAT_SCALE",
        "GS_GEM_SCALE",
        "GS_ENCHANT_SCALE",
        "GS_INCOMPATIBLE_PVE_BONUS_SCALE",
        "GS_PVE_RESILIENCE_RATE",
        "GS_PVP_RESILIENCE_RATE",
        "GS_PVE_RESILIENCE_FLOOR",
        "GS_PVP_RESILIENCE_CAP",
        "GS_CAP_BONUS_ANCHOR_LOW_GS2",
        "GS_CAP_BONUS_ANCHOR_HIGH_GS2",
        "GS_CAP_BONUS_ANCHOR_LOW_BONUS",
        "GS_CAP_BONUS_ANCHOR_HIGH_BONUS",
        "GS_CAP_BONUS_MIN",
        "GS_CAP_BONUS_MAX",
    ]:
        constant_key = name[3:]
        env[name] = float(constants[constant_key])
    return env


def apply_runtime_constants(tables: dict[str, Any]) -> None:
    global GS_GS2_STAT_SCALE
    global GS_GEM_SCALE
    global GS_ENCHANT_SCALE
    global GS_INCOMPATIBLE_PVE_BONUS_SCALE
    global GS_PVE_RESILIENCE_RATE
    global GS_PVP_RESILIENCE_RATE
    global GS_PVE_RESILIENCE_FLOOR
    global GS_PVP_RESILIENCE_CAP
    global GS_CAP_BONUS_ANCHOR_LOW_GS2
    global GS_CAP_BONUS_ANCHOR_HIGH_GS2
    global GS_CAP_BONUS_ANCHOR_LOW_BONUS
    global GS_CAP_BONUS_ANCHOR_HIGH_BONUS
    global GS_CAP_BONUS_MIN
    global GS_CAP_BONUS_MAX

    constants = {
        "GS2_STAT_SCALE": float(tables["GS_GS2_STAT_SCALE"]),
        "GEM_SCALE": float(tables["GS_GEM_SCALE"]),
        "ENCHANT_SCALE": float(tables["GS_ENCHANT_SCALE"]),
        "INCOMPATIBLE_PVE_BONUS_SCALE": float(tables["GS_INCOMPATIBLE_PVE_BONUS_SCALE"]),
        "PVE_RESILIENCE_RATE": float(tables["GS_PVE_RESILIENCE_RATE"]),
        "PVP_RESILIENCE_RATE": float(tables["GS_PVP_RESILIENCE_RATE"]),
        "PVE_RESILIENCE_FLOOR": float(tables["GS_PVE_RESILIENCE_FLOOR"]),
        "PVP_RESILIENCE_CAP": float(tables["GS_PVP_RESILIENCE_CAP"]),
        "CAP_BONUS_ANCHOR_LOW_GS2": float(tables["GS_CAP_BONUS_ANCHOR_LOW_GS2"]),
        "CAP_BONUS_ANCHOR_HIGH_GS2": float(tables["GS_CAP_BONUS_ANCHOR_HIGH_GS2"]),
        "CAP_BONUS_ANCHOR_LOW_BONUS": float(tables["GS_CAP_BONUS_ANCHOR_LOW_BONUS"]),
        "CAP_BONUS_ANCHOR_HIGH_BONUS": float(tables["GS_CAP_BONUS_ANCHOR_HIGH_BONUS"]),
        "CAP_BONUS_MIN": float(tables["GS_CAP_BONUS_MIN"]),
        "CAP_BONUS_MAX": float(tables["GS_CAP_BONUS_MAX"]),
        "OFFSPEC_FIT_MATCH_RATIO_FLOOR": GS_OFFSPEC_FIT_MATCH_RATIO_FLOOR,
        "OFFSPEC_FIT_MATCH_RATIO_FULL": GS_OFFSPEC_FIT_MATCH_RATIO_FULL,
        "OFFSPEC_FIT_MULTIPLIER_FLOOR": GS_OFFSPEC_FIT_MULTIPLIER_FLOOR,
        "OFFSPEC_FIT_SIGNATURE_PENALTY": GS_OFFSPEC_FIT_SIGNATURE_PENALTY,
    }
    tables["constants"] = constants

    GS_GS2_STAT_SCALE = float(constants["GS2_STAT_SCALE"])
    GS_GEM_SCALE = float(constants["GEM_SCALE"])
    GS_ENCHANT_SCALE = float(constants["ENCHANT_SCALE"])
    GS_INCOMPATIBLE_PVE_BONUS_SCALE = float(constants["INCOMPATIBLE_PVE_BONUS_SCALE"])
    GS_PVE_RESILIENCE_RATE = float(constants["PVE_RESILIENCE_RATE"])
    GS_PVP_RESILIENCE_RATE = float(constants["PVP_RESILIENCE_RATE"])
    GS_PVE_RESILIENCE_FLOOR = float(constants["PVE_RESILIENCE_FLOOR"])
    GS_PVP_RESILIENCE_CAP = float(constants["PVP_RESILIENCE_CAP"])
    GS_CAP_BONUS_ANCHOR_LOW_GS2 = float(constants["CAP_BONUS_ANCHOR_LOW_GS2"])
    GS_CAP_BONUS_ANCHOR_HIGH_GS2 = float(constants["CAP_BONUS_ANCHOR_HIGH_GS2"])
    GS_CAP_BONUS_ANCHOR_LOW_BONUS = float(constants["CAP_BONUS_ANCHOR_LOW_BONUS"])
    GS_CAP_BONUS_ANCHOR_HIGH_BONUS = float(constants["CAP_BONUS_ANCHOR_HIGH_BONUS"])
    GS_CAP_BONUS_MIN = float(constants["CAP_BONUS_MIN"])
    GS_CAP_BONUS_MAX = float(constants["CAP_BONUS_MAX"])


def normalize_spec_name(name: str, class_name: str) -> str:
    key = re.sub(r"[^A-Za-z]+", "_", name.strip().upper()).strip("_")
    class_token = class_name.upper()
    if class_token == "DRUID" and key in {"FERAL", "FERAL_COMBAT"}:
        return "FERAL"
    canonical_by_class = {
        "WARRIOR": {
            "ARMS": "WARRIOR_ARMS",
            "FURY": "WARRIOR_FURY",
            "PROTECTION": "WARRIOR_PROTECTION",
        },
        "PALADIN": {
            "HOLY": "PALADIN_HOLY",
            "PROTECTION": "PALADIN_PROTECTION",
            "RETRIBUTION": "PALADIN_RETRIBUTION",
        },
        "HUNTER": {
            "BEASTMASTERY": "HUNTER_BEASTMASTERY",
            "BEAST_MASTERY": "HUNTER_BEASTMASTERY",
            "MARKSMAN": "HUNTER_MARKSMANSHIP",
            "MARKSMANSHIP": "HUNTER_MARKSMANSHIP",
            "SURVIVAL": "HUNTER_SURVIVAL",
        },
        "ROGUE": {
            "ASSASSINATION": "ROGUE_ASSASSINATION",
            "COMBAT": "ROGUE_COMBAT",
            "SUBTLETY": "ROGUE_SUBTLETY",
        },
        "PRIEST": {
            "DISCIPLINE": "PRIEST_DISCIPLINE",
            "HOLY": "PRIEST_HOLY",
            "SHADOW": "PRIEST_SHADOW",
        },
        "DEATHKNIGHT": {
            "BLOOD": "DEATHKNIGHT_BLOOD",
            "FROST": "DEATHKNIGHT_FROST",
            "UNHOLY": "DEATHKNIGHT_UNHOLY",
        },
        "SHAMAN": {
            "ELEMENTAL": "SHAMAN_ELEMENTAL",
            "ENHANCEMENT": "SHAMAN_ENHANCEMENT",
            "RESTORATION": "SHAMAN_RESTORATION",
        },
        "MAGE": {
            "ARCANE": "MAGE_ARCANE",
            "FIRE": "MAGE_FIRE",
            "FROST": "MAGE_FROST",
        },
        "WARLOCK": {
            "AFFLICTION": "WARLOCK_AFFLICTION",
            "DEMONOLOGY": "WARLOCK_DEMONOLOGY",
            "DESTRUCTION": "WARLOCK_DESTRUCTION",
        },
        "DRUID": {
            "BALANCE": "DRUID_BALANCE",
            "RESTORATION": "DRUID_RESTORATION",
        },
    }
    if key.startswith(f"{class_token}_"):
        return key
    resolved = canonical_by_class.get(class_token, {}).get(key)
    if resolved:
        return resolved
    return key


def normalize_class_name(race_and_class: str) -> str:
    upper = race_and_class.upper()
    for class_label, token in sorted(CLASS_NAME_ALIASES.items(), key=lambda entry: len(entry[0]), reverse=True):
        if upper.endswith(class_label):
            return token
    return race_and_class.split()[-1].upper()


def normalize_race_name(race_and_class: str) -> str:
    upper = race_and_class.upper()
    for class_label, _token in sorted(CLASS_NAME_ALIASES.items(), key=lambda entry: len(entry[0]), reverse=True):
        if upper.endswith(class_label):
            race_name = upper[: -len(class_label)].strip()
            return re.sub(r"[^A-Z]+", "", race_name)
    return re.sub(r"[^A-Z]+", "", race_and_class.split()[0].upper())


def parse_dataset(path: Path) -> list[WarmaneCharacterRef]:
    refs: list[WarmaneCharacterRef] = []
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        match = WARMANE_PROFILE_RE.search(line)
        if not match:
            raise ValueError(f"Unsupported Warmane URL: {line}")
        refs.append(
            WarmaneCharacterRef(
                url=line,
                name=match.group("name"),
                realm=match.group("realm"),
            )
        )
    return refs


def slugify_url(url: str) -> str:
    parsed = urllib.parse.urlparse(url)
    return re.sub(r"[^A-Za-z0-9._-]+", "_", parsed.path.strip("/"))


def strip_tags(value: str) -> str:
    text = re.sub(r"<!--.*?-->", "", value, flags=re.DOTALL)
    text = re.sub(r"</?(?:table|tr|td|th|div|span)[^>]*>", "\n", text, flags=re.IGNORECASE)
    text = re.sub(r"<br\s*/?>", "\n", text, flags=re.IGNORECASE)
    text = re.sub(r"<[^>]+>", "", text)
    text = re.sub(r"\n+", "\n", text)
    return html.unescape(text)


def parse_number(text: str) -> float | str:
    cleaned = text.replace(",", "").replace("%", "").strip()
    try:
        return float(cleaned)
    except ValueError:
        return cleaned


def parse_stats_from_text(text: str) -> tuple[dict[str, float], int]:
    stats: dict[str, float] = {}
    socket_count = 0
    for raw_line in text.splitlines():
        line = html.unescape(raw_line).strip()
        if not line:
            continue
        lower = line.lower()
        if lower.startswith("socket bonus:"):
            continue
        if "socket" in lower and "bonus" not in lower:
            socket_count += 1
            continue
        match = re.match(r"^\+(\d+)\s+(.+)$", line)
        if match:
            amount = float(match.group(1))
            stat_key = STAT_ALIASES.get(match.group(2).strip().lower())
            if stat_key:
                stats[stat_key] = stats.get(stat_key, 0) + amount
            continue
        for pattern, stat_key in [
            (r"improves spell power by (\d+)", "SP"),
            (r"increases spell power by (\d+)", "SP"),
            (r"increases damage and healing done by magical spells and effects by up to (\d+)", "SP"),
            (r"increases damage done by arcane spells and effects by up to (\d+)", "SP"),
            (r"increases damage done by fire spells and effects by up to (\d+)", "SP"),
            (r"increases damage done by frost spells and effects by up to (\d+)", "SP"),
            (r"increases damage done by shadow spells and effects by up to (\d+)", "SP"),
            (r"increases damage done by holy spells and effects by up to (\d+)", "SP"),
            (r"increases damage done by nature spells and effects by up to (\d+)", "SP"),
            (r"improves critical strike rating by (\d+)", "CRIT"),
            (r"increases your (?:critical strike|critical) rating by (\d+)", "CRIT"),
            (r"improves hit rating by (\d+)", "HIT"),
            (r"increases your hit rating by (\d+)", "HIT"),
            (r"improves haste rating by (\d+)", "HASTE"),
            (r"increases your haste rating by (\d+)", "HASTE"),
            (r"improves armor penetration rating by (\d+)", "ARP"),
            (r"increases your armor penetration rating by (\d+)", "ARP"),
            (r"increases expertise rating by (\d+)", "EXPERTISE"),
            (r"increases your expertise rating by (\d+)", "EXPERTISE"),
            (r"improves defense rating by (\d+)", "DEFENSE"),
            (r"increases your defense rating by (\d+)", "DEFENSE"),
            (r"improves dodge rating by (\d+)", "DODGE"),
            (r"increases your dodge rating by (\d+)", "DODGE"),
            (r"improves parry rating by (\d+)", "PARRY"),
            (r"increases your parry rating by (\d+)", "PARRY"),
            (r"improves block rating by (\d+)", "BLOCK"),
            (r"increases your block rating by (\d+)", "BLOCK"),
            (r"increases the block value of your shield by (\d+)", "BLOCKVALUE"),
            (r"restores (\d+) mana per 5 sec", "MP5"),
            (r"restores (\d+) mana every 5 sec", "MP5"),
            (r"increases attack power by (\d+)", "AP"),
            (r"increases ranged attack power by (\d+)", "RAP"),
            (r"improves resilience rating by (\d+)", "RESILIENCE"),
            (r"increases your resilience rating by (\d+)", "RESILIENCE"),
        ]:
            found = re.search(pattern, lower)
            if found:
                stats[stat_key] = stats.get(stat_key, 0) + float(found.group(1))
        hybrid_ap = re.search(r"increases attack power by (\d+) in cat, bear, dire bear, and moonkin forms only", lower)
        if hybrid_ap:
            stats["AP"] = stats.get("AP", 0) + float(hybrid_ap.group(1))
    return stats, socket_count


def parse_inline_stat_string(text: str) -> dict[str, float]:
    stats: dict[str, float] = {}
    for amount_text, label in re.findall(r"\+(\d+)\s+([A-Za-z ]+?)(?=(?:\s+and\s+\+\d+\s+[A-Za-z ]+)|$)", text):
        stat_key = STAT_ALIASES.get(label.strip().lower())
        if stat_key:
            stats[stat_key] = stats.get(stat_key, 0) + float(amount_text)
    return stats


def parse_stat_phrase(text: str) -> dict[str, float]:
    stats = parse_inline_stat_string(text)
    if stats:
        return stats
    cleaned = text.strip().rstrip(".")
    match = re.match(r"^(\d+)\s+(.+)$", cleaned)
    if match:
        amount = float(match.group(1))
        stat_key = STAT_ALIASES.get(match.group(2).strip().lower())
        if stat_key:
            return {stat_key: amount}
    lowered = cleaned.lower()
    patterns = [
        (r"(\d+)\s+mana per 5 sec", "MP5"),
        (r"(\d+)\s+mana every 5 sec", "MP5"),
        (r"(\d+)\s+attack power", "AP"),
        (r"(\d+)\s+critical strike rating", "CRIT"),
        (r"(\d+)\s+crit rating", "CRIT"),
        (r"(\d+)\s+hit rating", "HIT"),
        (r"(\d+)\s+haste rating", "HASTE"),
        (r"(\d+)\s+expertise rating", "EXPERTISE"),
        (r"(\d+)\s+armor penetration rating", "ARP"),
        (r"(\d+)\s+agility", "AGI"),
        (r"(\d+)\s+strength", "STR"),
        (r"(\d+)\s+stamina", "STA"),
        (r"(\d+)\s+intellect", "INT"),
        (r"(\d+)\s+spirit", "SPI"),
        (r"(\d+)\s+spell power", "SP"),
    ]
    for pattern, stat_key in patterns:
        found = re.search(pattern, lowered)
        if found:
            return {stat_key: float(found.group(1))}
    return {}


def parse_slot_and_subtype_from_tooltip(tooltip_text: str) -> tuple[str, str]:
    lines = [line.strip() for line in tooltip_text.splitlines() if line.strip()]
    slot_label = ""
    subtype = ""
    slot_tokens = {
        "Head", "Neck", "Shoulder", "Back", "Chest", "Shirt", "Tabard", "Wrist",
        "Hands", "Waist", "Legs", "Feet", "Finger", "Trinket", "Main Hand",
        "Off Hand", "Held In Off-hand", "One-Hand", "Two-Hand", "Ranged",
        "Thrown", "Relic",
    }
    subtype_tokens = {
        "Cloth", "Leather", "Mail", "Plate", "Shield", "Dagger", "Sword",
        "Axe", "Mace", "Fist Weapon", "Staff", "Polearm", "Bow", "Gun",
        "Crossbow", "Wand", "Thrown", "Idol", "Totem", "Sigil", "Libram",
    }
    for line in lines:
        if not slot_label and line in slot_tokens:
            slot_label = line
            continue
        if line in subtype_tokens:
            subtype = line
            if slot_label:
                break
    return slot_label, subtype


def infer_equip_loc(slot_id: int, slot_label: str, subtype: str, tooltip_text: str) -> str:
    upper_slot = slot_label.upper()
    upper_subtype = subtype.upper()
    tooltip_upper = tooltip_text.upper()
    if upper_slot == "SHIRT":
        return "INVTYPE_BODY"
    if upper_slot == "TABARD":
        return "INVTYPE_TABARD"
    if upper_slot == "HEAD":
        return "INVTYPE_HEAD"
    if upper_slot == "NECK":
        return "INVTYPE_NECK"
    if upper_slot == "SHOULDER":
        return "INVTYPE_SHOULDER"
    if upper_slot == "BACK":
        return "INVTYPE_CLOAK"
    if upper_slot == "CHEST":
        return "INVTYPE_CHEST"
    if upper_slot == "WRIST":
        return "INVTYPE_WRIST"
    if upper_slot == "HANDS":
        return "INVTYPE_HAND"
    if upper_slot == "WAIST":
        return "INVTYPE_WAIST"
    if upper_slot == "LEGS":
        return "INVTYPE_LEGS"
    if upper_slot == "FEET":
        return "INVTYPE_FEET"
    if upper_slot == "FINGER":
        return "INVTYPE_FINGER"
    if upper_slot == "TRINKET":
        return "INVTYPE_TRINKET"
    if upper_slot == "MAIN HAND":
        return "INVTYPE_WEAPONMAINHAND"
    if upper_slot == "OFF HAND":
        if "SHIELD" in upper_subtype or "SHIELD" in tooltip_upper:
            return "INVTYPE_SHIELD"
        return "INVTYPE_WEAPONOFFHAND"
    if upper_slot == "HELD IN OFF-HAND":
        return "INVTYPE_HOLDABLE"
    if upper_slot == "RANGED":
        return "INVTYPE_RANGED"
    if upper_slot == "THROWN":
        return "INVTYPE_THROWN"
    if upper_slot == "RELIC":
        return "INVTYPE_RELIC"
    if slot_id in SLOT_TO_EQUIPLOC and slot_id not in (16, 17, 18, 5):
        return SLOT_TO_EQUIPLOC[slot_id]
    if slot_id == 5:
        return "INVTYPE_CHEST"
    if slot_id == 16:
        if "TWO-HAND" in upper_subtype or "TWO-HAND" in tooltip_upper:
            return "INVTYPE_2HWEAPON"
        if "MAIN HAND" in tooltip_upper:
            return "INVTYPE_WEAPONMAINHAND"
        return "INVTYPE_WEAPON"
    if slot_id == 17:
        if "SHIELD" in upper_subtype or "SHIELD" in tooltip_upper:
            return "INVTYPE_SHIELD"
        if "HELD IN OFF-HAND" in tooltip_upper:
            return "INVTYPE_HOLDABLE"
        return "INVTYPE_WEAPONOFFHAND"
    if slot_id == 18:
        if "RELIC" in upper_subtype:
            return "INVTYPE_RELIC"
        if "THROWN" in upper_subtype:
            return "INVTYPE_THROWN"
        if "WAND" in upper_subtype or "BOW" in upper_subtype or "GUN" in upper_subtype or "CROSSBOW" in upper_subtype:
            return "INVTYPE_RANGED"
        return "INVTYPE_RANGEDRIGHT"
    return SLOT_TO_EQUIPLOC.get(slot_id, "INVTYPE_WEAPON")


def get_item_slot_value(equip_loc: str, item_types: dict[str, Any]) -> int:
    item_type = item_types.get(equip_loc)
    return int(item_type.get("ItemSlot", 0)) if item_type else 0


def assign_slot_id(equip_loc: str, slot_counters: dict[str, int]) -> int:
    if equip_loc == "INVTYPE_FINGER":
        slot_counters[equip_loc] = slot_counters.get(equip_loc, 0) + 1
        return 11 if slot_counters[equip_loc] == 1 else 12
    if equip_loc == "INVTYPE_TRINKET":
        slot_counters[equip_loc] = slot_counters.get(equip_loc, 0) + 1
        return 13 if slot_counters[equip_loc] == 1 else 14
    mapping = {
        "INVTYPE_HEAD": 1,
        "INVTYPE_NECK": 2,
        "INVTYPE_SHOULDER": 3,
        "INVTYPE_BODY": 4,
        "INVTYPE_CHEST": 5,
        "INVTYPE_ROBE": 5,
        "INVTYPE_WAIST": 6,
        "INVTYPE_LEGS": 7,
        "INVTYPE_FEET": 8,
        "INVTYPE_WRIST": 9,
        "INVTYPE_HAND": 10,
        "INVTYPE_CLOAK": 15,
        "INVTYPE_WEAPONMAINHAND": 16,
        "INVTYPE_WEAPON": 16,
        "INVTYPE_2HWEAPON": 16,
        "INVTYPE_WEAPONOFFHAND": 17,
        "INVTYPE_SHIELD": 17,
        "INVTYPE_HOLDABLE": 17,
        "INVTYPE_RANGED": 18,
        "INVTYPE_RANGEDRIGHT": 18,
        "INVTYPE_THROWN": 18,
        "INVTYPE_RELIC": 18,
    }
    return mapping.get(equip_loc, 0)


def calculate_legacy_base(item: dict[str, Any], item_types: dict[str, Any], formulas: dict[str, Any]) -> int:
    item_rarity = int(item["rarity"])
    item_level = float(item["level"])
    item_equip_loc = item["equipLoc"]
    quality_scale = 1.0
    scale = 1.8618
    if item_rarity == 5:
        quality_scale = 1.3
        item_rarity = 4
    elif item_rarity in (0, 1):
        quality_scale = 0.005
        item_rarity = 2
    if item_rarity == 7:
        item_rarity = 3
        item_level = 187.05
    if item_equip_loc in item_types:
        table_ref = formulas["A"] if item_level > 120 else formulas["B"]
        if item_rarity in table_ref:
            ref = table_ref[item_rarity]
            score = math.floor(
                ((item_level - ref["A"]) / ref["B"])
                * item_types[item_equip_loc]["SlotMOD"]
                * scale
                * quality_scale
            )
            return max(score, 0)
    return 0


def get_hunter_legacy(slot_id: int, item: dict[str, Any]) -> int:
    if slot_id == 16:
        return math.floor(item["legacyBase"] * 0.3164)
    if slot_id == 18 and item["equipLoc"] in {"INVTYPE_RANGEDRIGHT", "INVTYPE_RANGED"}:
        return math.floor(item["legacyBase"] * 5.3224)
    return item["legacyBase"]


GENERIC_TREE_PROFILE_DEFAULTS = {
    "FERAL": "DRUID_FERAL_DPS",
}

def get_class_spec_candidates(class_token: str, tables: dict[str, Any]) -> list[str]:
    candidates: list[str] = []
    for spec_key in tables["GS_ClassSpecOrder"].get(class_token) or []:
        if class_token == "DRUID" and spec_key == "DRUID_FERAL_DPS":
            candidates.extend(["DRUID_FERAL_DPS", "DRUID_FERAL_TANK"])
        elif spec_key in tables["GS_SpecProfiles"]:
            candidates.append(spec_key)
    return candidates


def is_better_spec_diagnostics(candidate_spec: str, candidate: dict[str, Any] | None, best_spec: str | None, best: dict[str, Any] | None) -> bool:
    if not candidate:
        return False
    if not best:
        return True
    candidate_compatible = int(candidate.get("compatible_items", 0))
    best_compatible = int(best.get("compatible_items", 0))
    if candidate_compatible != best_compatible:
        return candidate_compatible > best_compatible
    candidate_matched = int(candidate.get("matched_items", 0))
    best_matched = int(best.get("matched_items", 0))
    if candidate_matched != best_matched:
        return candidate_matched > best_matched
    candidate_total = int(candidate.get("total", 0))
    best_total = int(best.get("total", 0))
    if candidate_total != best_total:
        return candidate_total > best_total
    return candidate_spec == "DRUID_FERAL_TANK" and best_spec != "DRUID_FERAL_TANK"


def resolve_druid_feral_spec(items: list[dict[str, Any]], tables: dict[str, Any], race_token: str | None = None) -> str:
    best_spec: str | None = None
    best_diagnostics: dict[str, Any] | None = None
    for candidate_spec in ("DRUID_FERAL_DPS", "DRUID_FERAL_TANK"):
        diagnostics = get_snapshot_spec_diagnostics(items, "DRUID", candidate_spec, tables, race_token)
        if is_better_spec_diagnostics(candidate_spec, diagnostics, best_spec, best_diagnostics):
            best_spec = candidate_spec
            best_diagnostics = diagnostics
    return best_spec or "DRUID_FERAL_DPS"


def resolve_spec_key(class_token: str, spec_key: str | None, tables: dict[str, Any], items: list[dict[str, Any]] | None = None, race_token: str | None = None) -> str:
    if class_token == "DRUID" and spec_key == "FERAL" and items is not None:
        return resolve_druid_feral_spec(items, tables, race_token)
    if spec_key in tables["GS_SpecProfiles"]:
        return spec_key
    if spec_key in GENERIC_TREE_PROFILE_DEFAULTS and GENERIC_TREE_PROFILE_DEFAULTS[spec_key] in tables["GS_SpecProfiles"]:
        return GENERIC_TREE_PROFILE_DEFAULTS[spec_key]
    return tables["GS_ClassDefaults"][class_token]


def get_profile(class_token: str, spec_key: str | None, tables: dict[str, Any], items: list[dict[str, Any]] | None = None, race_token: str | None = None) -> tuple[dict[str, Any], str]:
    resolved_spec = resolve_spec_key(class_token, spec_key, tables, items, race_token)
    return tables["GS_SpecProfiles"][resolved_spec], resolved_spec


def score_stats(stats: dict[str, float] | None, weights: dict[str, float] | None) -> float:
    if not stats or not weights:
        return 0.0
    total = 0.0
    for stat, value in stats.items():
        if stat in weights:
            total += value * weights[stat]
    return total


def is_cap_relevant_stat(spec_key: str | None, stat: str, tables: dict[str, Any]) -> bool:
    pools = ((tables.get("GS_CapProfiles") or {}).get(spec_key or "") or {}).get("pools") or {}
    if stat == "HIT":
        return "HIT" in pools or "SPELL_HIT" in pools
    if stat == "SPELL_HIT":
        return "SPELL_HIT" in pools or "HIT" in pools
    return stat in pools


def has_cap_relevant_matched_stat(
    stats: dict[str, float] | None, weights: dict[str, float] | None, spec_key: str | None, tables: dict[str, Any]
) -> bool:
    if not stats or not weights or not spec_key:
        return False
    for stat, value in stats.items():
        if value > 0 and stat in weights and is_cap_relevant_stat(spec_key, stat, tables):
            return True
    return False


def scale_bonus(raw_value: float, scale: float, round_up: bool = False) -> int:
    raw = float(raw_value or 0.0)
    if raw <= 0:
        return 0
    scaled = raw * float(scale)
    return math.ceil(scaled) if round_up else math.floor(scaled)


def should_flag_stats(stats: dict[str, float] | None, weights: dict[str, float]) -> bool:
    if not stats:
        return False
    has_matched = False
    has_non_ignored_miss = False
    for stat, value in stats.items():
        if value <= 0:
            continue
        if stat in weights:
            has_matched = True
        elif stat not in IGNORED_STATS_FOR_FLAGS:
            has_non_ignored_miss = True
    return has_non_ignored_miss and not has_matched


def get_resilience_multiplier(resilience: float, mode: str) -> float:
    if resilience <= 0:
        return 1.0
    if mode == "PVP":
        return min(GS_PVP_RESILIENCE_CAP, 1 + (resilience * GS_PVP_RESILIENCE_RATE))
    return max(GS_PVE_RESILIENCE_FLOOR, 1 - (resilience * GS_PVE_RESILIENCE_RATE))


def is_ranged_helper_compatible(item: dict[str, Any], class_token: str, profile: dict[str, Any]) -> bool:
    equip_loc = item.get("equipLoc")
    subtype = str(item.get("subType") or "").upper()
    if equip_loc in {"INVTYPE_RANGED", "INVTYPE_RANGEDRIGHT", "INVTYPE_THROWN"} and profile.get("ranged"):
        return True
    if equip_loc == "INVTYPE_RELIC":
        return (
            (class_token == "PALADIN" and subtype in {"LIBRAM", "LIBRAMS"})
            or (class_token == "SHAMAN" and subtype in {"TOTEM", "TOTEMS"})
            or (class_token == "DRUID" and subtype in {"IDOL", "IDOLS"})
            or (class_token == "DEATHKNIGHT" and subtype in {"SIGIL", "SIGILS"})
        )
    if class_token in {"MAGE", "PRIEST", "WARLOCK"}:
        return equip_loc == "INVTYPE_RANGED" and subtype == "WAND"
    if class_token in {"ROGUE", "WARRIOR"}:
        return equip_loc in {"INVTYPE_RANGED", "INVTYPE_RANGEDRIGHT", "INVTYPE_THROWN"} and subtype in {"BOW", "GUN", "CROSSBOW", "THROWN"}
    return False


def get_role_signature_kind(item: dict[str, Any] | None) -> str | None:
    if not item:
        return None
    stats = item.get("stats", {})
    equip_loc = item.get("equipLoc")
    has_tank = (
        stats.get("DEFENSE", 0) > 0
        or stats.get("DODGE", 0) > 0
        or stats.get("PARRY", 0) > 0
        or stats.get("BLOCK", 0) > 0
        or stats.get("BLOCKVALUE", 0) > 0
        or equip_loc == "INVTYPE_SHIELD"
    )
    has_healer = stats.get("MP5", 0) > 0 or stats.get("SPI", 0) > 0
    has_caster = stats.get("SP", 0) > 0 or stats.get("INT", 0) > 0
    has_physical = any(stats.get(key, 0) > 0 for key in ("STR", "AGI", "AP", "RAP", "ARP", "EXPERTISE"))
    has_ranged = stats.get("RAP", 0) > 0 or equip_loc in {"INVTYPE_RANGED", "INVTYPE_RANGEDRIGHT", "INVTYPE_THROWN"}
    if has_tank:
        return "TANK"
    if has_healer and has_caster and not has_physical:
        return "HEALER"
    if has_caster and not has_physical:
        return "CASTER"
    if has_ranged:
        return "RANGED"
    if has_physical:
        return "MELEE"
    return None


def is_item_compatible(item: dict[str, Any], class_token: str, profile: dict[str, Any]) -> bool:
    if not item or not profile or item.get("slot") == 0:
        return False
    stats = item.get("stats", {})
    role_signature = get_role_signature_kind(item)
    armor_target = profile.get("armor")
    armor_rank = item.get("armorRank")
    ignore_armor_downgrade = bool(profile.get("allowLowerArmor")) or (class_token == "DRUID" and profile.get("role") in {"CASTER", "HEALER"})
    if armor_target in ARMOR_SUBTYPE_TO_RANK and armor_rank and item.get("slot") not in {15, 2, 11, 13}:
        if armor_rank < ARMOR_SUBTYPE_TO_RANK[armor_target] and not ignore_armor_downgrade:
            return False
    if item["equipLoc"] == "INVTYPE_SHIELD" and not profile.get("shield"):
        return False
    if item["equipLoc"] == "INVTYPE_WEAPONOFFHAND" and not profile.get("dualwield"):
        return False
    if item["equipLoc"] == "INVTYPE_HOLDABLE" and profile.get("role") not in {"CASTER", "HEALER"}:
        return False
    if item["equipLoc"] == "INVTYPE_RELIC" and not is_ranged_helper_compatible(item, class_token, profile):
        return False
    if item["equipLoc"] in {"INVTYPE_RANGED", "INVTYPE_RANGEDRIGHT", "INVTYPE_THROWN"} and not is_ranged_helper_compatible(item, class_token, profile):
        return False
    if class_token == "HUNTER" and item["equipLoc"] in {"INVTYPE_SHIELD", "INVTYPE_HOLDABLE"}:
        return False
    role = profile.get("role")
    allow_hybrid_caster_items = bool(profile.get("hybridCasterItems"))
    if role in {"CASTER", "HEALER"} and stats.get("STR", 0) > 0 and stats.get("SP", 0) == 0 and stats.get("INT", 0) == 0:
        return False
    if role in {"MELEE", "RANGED"} and stats.get("SP", 0) > 0 and all(stats.get(key, 0) == 0 for key in ("STR", "AGI", "AP", "RAP")) and not allow_hybrid_caster_items:
        return False
    if role == "TANK" and role_signature in {"CASTER", "HEALER"}:
        return False
    if role in {"CASTER", "HEALER"} and role_signature in {"MELEE", "RANGED"} and stats.get("SP", 0) == 0 and stats.get("INT", 0) == 0:
        return False
    if role in {"MELEE", "RANGED"} and role_signature in {"CASTER", "HEALER"} and all(stats.get(key, 0) == 0 for key in ("STR", "AGI", "AP", "RAP")) and not allow_hybrid_caster_items:
        return False
    return True


def score_item_with_debug(item: dict[str, Any], class_token: str, spec_key: str, tables: dict[str, Any]) -> tuple[int, int, list[str], dict[str, Any]]:
    profile, resolved_spec = get_profile(class_token, spec_key, tables)
    flags: list[str] = []
    debug = {
        "spec_key": resolved_spec,
        "legacy_base": int(item["legacyBase"]),
        "gs2_scale": float(profile.get("gs2Scale", 1.0)),
        "slot_multiplier": 1.0,
        "slot_multiplier_source": "none",
        "item_level": int(item.get("level", 0) or 0),
        "compatible": False,
        "compatibility_penalty_scale": 1.0,
        "matched_stat_raw_pve": 0.0,
        "matched_stat_bonus_pve": 0,
        "matched_stat_raw_pvp": 0.0,
        "matched_stat_bonus_pvp": 0,
        "bonus_bucket_pve": 0,
        "bonus_bucket_pve_scaled": 0,
        "gem_breakdown": [],
        "enchant_breakdown": None,
        "resilience": float(item.get("resilience", 0)),
        "resilience_multiplier_pve": 1.0,
        "resilience_multiplier_pvp": 1.0,
        "pre_multiplier_pve": 0,
        "pre_multiplier_pvp": 0,
        "item_gs2_pre_slot_multiplier": 0,
        "item_gs2_final": 0,
        "item_pvp_final": 0,
    }
    compatible = is_item_compatible(item, class_token, profile)
    debug["compatible"] = compatible
    compatibility_penalty_scale = 1.0 if compatible else GS_INCOMPATIBLE_PVE_BONUS_SCALE
    debug["compatibility_penalty_scale"] = compatibility_penalty_scale
    if not compatible:
        flags.append("incompatible-item")
    pve_score = float(item["legacyBase"])
    pvp_score = float(item["legacyBase"])
    pve_scale = float(profile.get("gs2Scale", 1.0))
    slot_multiplier = float(resolve_slot_multiplier(profile, int(item.get("slot", 0) or 0), int(item.get("level", 0) or 0)))
    debug["slot_multiplier"] = slot_multiplier
    if slot_multiplier != 1.0:
        debug["slot_multiplier_source"] = "curve"
    pve_bonus_bucket = 0
    pve_stat_raw = score_stats(item.get("stats"), profile.get("pve"))
    pvp_stat_raw = score_stats(item.get("stats"), profile.get("pvp"))
    pve_stat_bonus = math.floor(pve_stat_raw * GS_GS2_STAT_SCALE)
    pvp_stat_bonus = math.floor(pvp_stat_raw * GS_GS2_STAT_SCALE)
    debug["matched_stat_raw_pve"] = pve_stat_raw
    debug["matched_stat_bonus_pve"] = pve_stat_bonus
    debug["matched_stat_raw_pvp"] = pvp_stat_raw
    debug["matched_stat_bonus_pvp"] = pvp_stat_bonus
    pve_bonus_bucket += pve_stat_bonus
    pvp_score += pvp_stat_bonus

    for gem in item.get("gemStats", []):
        gem_pve_raw = score_stats(gem, profile.get("pve"))
        gem_pvp_raw = score_stats(gem, profile.get("pvp"))
        gem_uses_cap_rounding = has_cap_relevant_matched_stat(gem, profile.get("pve"), resolved_spec, tables)
        gem_pve_bonus = scale_bonus(gem_pve_raw, GS_GEM_SCALE, gem_uses_cap_rounding)
        gem_pvp_bonus = math.floor(gem_pvp_raw * GS_GEM_SCALE) if gem_pvp_raw > 0 else 0
        pve_bonus_bucket += gem_pve_bonus
        pvp_score += gem_pvp_bonus
        debug["gem_breakdown"].append(
            {
                "stats": safe_json_value(gem),
                "raw_pve": gem_pve_raw,
                "bonus_pve": gem_pve_bonus,
                "raw_pvp": gem_pvp_raw,
                "bonus_pvp": gem_pvp_bonus,
                "cap_round_up_pve": gem_uses_cap_rounding,
            }
        )
        if should_flag_stats(gem, profile.get("pve", {})):
            flags.append("gem-mismatch")

    enchant_info = item.get("enchantInfo")
    if item["equipLoc"] in tables["GS_EnchantSlots"] and enchant_info:
        enchant_stats = enchant_info.get("stats")
        pve_enchant_raw = score_stats(enchant_stats, profile.get("pve"))
        pvp_enchant_raw = score_stats(enchant_stats, profile.get("pvp"))
        pve_enchant_bonus = math.floor(pve_enchant_raw * GS_ENCHANT_SCALE) if pve_enchant_raw > 0 else 0
        pvp_enchant_bonus = math.floor(pvp_enchant_raw * GS_ENCHANT_SCALE) if pvp_enchant_raw > 0 else 0
        pve_bonus_bucket += pve_enchant_bonus
        pvp_score += pvp_enchant_bonus
        debug["enchant_breakdown"] = {
            "enchant_id": item.get("enchantId", 0),
            "stats": safe_json_value(enchant_stats),
            "raw_pve": pve_enchant_raw,
            "bonus_pve": pve_enchant_bonus,
            "raw_pvp": pvp_enchant_raw,
            "bonus_pvp": pvp_enchant_bonus,
            "kind": enchant_info.get("kind"),
        }
        if enchant_info.get("kind") == "special":
            flags.append("special-enchant-unscored")
        elif enchant_stats and should_flag_stats(enchant_stats, profile.get("pve", {})):
            flags.append("enchant-mismatch")
    elif item["equipLoc"] in tables["GS_EnchantSlots"] and item.get("hasEnchant") and not enchant_info:
        flags.append("unknown-enchant")
        debug["enchant_breakdown"] = {
            "enchant_id": item.get("enchantId", 0),
            "stats": None,
            "raw_pve": 0.0,
            "bonus_pve": 0,
            "raw_pvp": 0.0,
            "bonus_pvp": 0,
            "kind": "unknown",
        }

    debug["bonus_bucket_pve"] = int(pve_bonus_bucket)
    pve_scaled_bonus = math.floor(pve_bonus_bucket * pve_scale * compatibility_penalty_scale) if pve_bonus_bucket > 0 else 0
    debug["bonus_bucket_pve_scaled"] = int(pve_scaled_bonus)
    pve_score += pve_scaled_bonus
    resilience = float(item.get("resilience", 0))
    pve_pre_multiplier = max(0, pve_score)
    pvp_pre_multiplier = max(0, pvp_score)
    pve_multiplier = get_resilience_multiplier(resilience, "PVE")
    pvp_multiplier = get_resilience_multiplier(resilience, "PVP")
    pve_score = math.floor(pve_pre_multiplier * pve_multiplier)
    pvp_score = math.floor(pvp_pre_multiplier * pvp_multiplier)
    debug["item_gs2_pre_slot_multiplier"] = int(pve_score)
    if slot_multiplier != 1.0:
        pve_score = math.floor(pve_score * slot_multiplier)
    debug["resilience_multiplier_pve"] = pve_multiplier
    debug["resilience_multiplier_pvp"] = pvp_multiplier
    debug["pre_multiplier_pve"] = int(pve_pre_multiplier)
    debug["pre_multiplier_pvp"] = int(pvp_pre_multiplier)
    debug["item_gs2_final"] = int(pve_score)
    debug["item_pvp_final"] = int(pvp_score)
    return int(pve_score), int(pvp_score), flags, debug


def score_item(item: dict[str, Any], class_token: str, spec_key: str, tables: dict[str, Any]) -> tuple[int, int, list[str]]:
    pve_score, pvp_score, flags, _ = score_item_with_debug(item, class_token, spec_key, tables)
    return pve_score, pvp_score, flags


def resolve_slot_multiplier(profile: dict[str, Any], slot_id: int, item_level: int) -> float:
    curves = profile.get("gs2SlotCurves") or {}
    curve = curves.get(slot_id)
    if not curve:
        return 1.0
    ilvl_start = int(curve.get("ilvlStart", 0) or 0)
    ilvl_end = int(curve.get("ilvlEnd", ilvl_start) or ilvl_start)
    multiplier_high = float(curve.get("multiplierHigh", 1.0) or 1.0)
    level = int(item_level or 0)
    if level <= ilvl_start or ilvl_end <= ilvl_start:
        return 1.0
    if level >= ilvl_end:
        return multiplier_high
    progress = (level - ilvl_start) / float(ilvl_end - ilvl_start)
    return 1.0 - ((1.0 - multiplier_high) * progress)


def get_max_cap_bonus(pre_cap_gs2: float) -> int:
    if pre_cap_gs2 <= 0:
        return 0
    low_gs = max(GS_CAP_BONUS_ANCHOR_LOW_GS2, 1)
    high_gs = max(GS_CAP_BONUS_ANCHOR_HIGH_GS2, low_gs + 1)
    ratio = (math.log(pre_cap_gs2) - math.log(low_gs)) / (math.log(high_gs) - math.log(low_gs))
    raw_bonus = GS_CAP_BONUS_ANCHOR_LOW_BONUS + ((GS_CAP_BONUS_ANCHOR_HIGH_BONUS - GS_CAP_BONUS_ANCHOR_LOW_BONUS) * ratio)
    rounded = math.floor(raw_bonus + 0.5)
    return min(GS_CAP_BONUS_MAX, max(GS_CAP_BONUS_MIN, rounded))


def resolve_cap_threshold(segment: dict[str, Any], context: dict[str, float], rating_conversions: dict[str, float]) -> float:
    mode = segment.get("mode")
    threshold = float(segment.get("threshold", 0))
    if mode == "MELEE_HIT_PERCENT":
        return max(0.0, (threshold - context.get("meleeHitBonus", 0)) * rating_conversions["MELEE_HIT"])
    if mode == "SPELL_HIT_PERCENT":
        return max(0.0, (threshold - context.get("spellHitBonus", 0) - context.get("targetSpellHitBonus", 0)) * rating_conversions["SPELL_HIT"])
    if mode == "EXPERTISE_POINTS":
        return max(0.0, (threshold - context.get("expertiseBonus", 0)) * rating_conversions["EXPERTISE"])
    if mode == "DEFENSE_SKILL":
        return max(0.0, (threshold - 400 - context.get("defenseSkillBonus", 0)) * rating_conversions["DEFENSE"])
    return max(0.0, threshold)


def is_rogue_poison_cap_spec(spec_key: str) -> bool:
    return spec_key in {"ROGUE_ASSASSINATION", "ROGUE_COMBAT", "ROGUE_SUBTLETY"}


def find_cap_segment(pool: dict[str, Any], mode: str | None) -> dict[str, Any] | None:
    if not mode:
        return None
    for segment in pool.get("segments", []):
        if segment.get("mode") == mode:
            return segment
    return None


def get_cap_progress_target(pool_stat: str, pool: dict[str, Any], context: dict[str, float], spec_key: str, rating_conversions: dict[str, float]) -> tuple[dict[str, Any] | None, float]:
    target_segment = find_cap_segment(pool, pool.get("progressMode"))
    if target_segment is None and pool_stat == "SPELL_HIT":
        target_segment = find_cap_segment(pool, "SPELL_HIT_PERCENT")
    elif target_segment is None and pool_stat == "HIT":
        if is_rogue_poison_cap_spec(spec_key):
            target_segment = find_cap_segment(pool, "SPELL_HIT_PERCENT")
        else:
            target_segment = find_cap_segment(pool, "MELEE_HIT_PERCENT") or find_cap_segment(pool, "SPELL_HIT_PERCENT")
    elif target_segment is None and pool_stat == "EXPERTISE":
        target_segment = find_cap_segment(pool, "EXPERTISE_POINTS")
    elif target_segment is None and pool_stat == "DEFENSE":
        target_segment = find_cap_segment(pool, "DEFENSE_SKILL")
    elif target_segment is None and pool_stat == "ARP":
        target_segment = find_cap_segment(pool, "RATING")
    if target_segment is None and pool.get("segments"):
        target_segment = pool["segments"][0]
    resolved_threshold = resolve_cap_threshold(target_segment, context, rating_conversions) if target_segment else 0.0
    return target_segment, resolved_threshold


def get_cap_pool_display(pool_stat: str, stat_value: float, target_segment: dict[str, Any] | None, resolved_threshold: float, context: dict[str, float], rating_conversions: dict[str, float]) -> tuple[float, float, bool]:
    if pool_stat == "DEFENSE":
        return (
            400 + math.floor((stat_value / rating_conversions["DEFENSE"]) + context.get("defenseSkillBonus", 0) + 0.5),
            float(target_segment.get("threshold", 540) if target_segment else 540),
            False,
        )
    if pool_stat == "EXPERTISE":
        return (
            math.floor((stat_value / rating_conversions["EXPERTISE"]) + context.get("expertiseBonus", 0) + 0.5),
            float(target_segment.get("threshold", 26) if target_segment else 26),
            False,
        )
    if pool_stat in {"HIT", "SPELL_HIT"} and target_segment and target_segment.get("mode") == "SPELL_HIT_PERCENT":
        return (
            (stat_value / rating_conversions["SPELL_HIT"]) + context.get("spellHitBonus", 0) + context.get("targetSpellHitBonus", 0),
            float(target_segment.get("threshold", 17)),
            False,
        )
    if pool_stat == "HIT" and target_segment and target_segment.get("mode") == "MELEE_HIT_PERCENT":
        return (
            (stat_value / rating_conversions["MELEE_HIT"]) + context.get("meleeHitBonus", 0),
            float(target_segment.get("threshold", 8)),
            False,
        )
    if pool_stat == "ARP":
        return math.floor(stat_value + context.get("arpBonus", 0) + 0.5), math.floor(resolved_threshold + 0.5), True
    return math.floor(stat_value + 0.5), math.floor(resolved_threshold + 0.5), True


def get_cap_pool_context_bonus(pool_stat: str, target_segment: dict[str, Any] | None, context: dict[str, float]) -> float:
    if pool_stat == "SPELL_HIT" or (pool_stat == "HIT" and target_segment and target_segment.get("mode") == "SPELL_HIT_PERCENT"):
        return context.get("spellHitBonus", 0.0) + context.get("targetSpellHitBonus", 0.0)
    if pool_stat == "HIT" and target_segment and target_segment.get("mode") == "MELEE_HIT_PERCENT":
        return context.get("meleeHitBonus", 0.0)
    if pool_stat == "EXPERTISE":
        return context.get("expertiseBonus", 0.0)
    if pool_stat == "DEFENSE":
        return context.get("defenseSkillBonus", 0.0)
    if pool_stat == "ARP":
        return context.get("arpBonus", 0.0)
    return 0.0


def create_cap_context() -> dict[str, float]:
    return {
        "meleeHitBonus": 0.0,
        "spellHitBonus": 0.0,
        "targetSpellHitBonus": 0.0,
        "expertiseBonus": 0.0,
        "defenseSkillBonus": 0.0,
        "arpBonus": 0.0,
        "liveMeleeHitBonus": 0.0,
        "liveSpellHitBonus": 0.0,
        "liveTargetSpellHitBonus": 0.0,
        "liveExpertiseBonus": 0.0,
        "liveDefenseSkillBonus": 0.0,
        "liveArpBonus": 0.0,
    }


def get_base_cap_context(spec_key: str, tables: dict[str, Any]) -> dict[str, float]:
    context = create_cap_context()
    cap_profile = tables["GS_CapProfiles"].get(spec_key) or {}
    for pool in (cap_profile.get("pools") or {}).values():
        context["meleeHitBonus"] = max(context["meleeHitBonus"], float(pool.get("meleeHitBonus", 0.0)))
        context["spellHitBonus"] = max(context["spellHitBonus"], float(pool.get("spellHitBonus", 0.0)))
        context["expertiseBonus"] = max(context["expertiseBonus"], float(pool.get("expertiseBonus", 0.0)))
        context["defenseSkillBonus"] = max(context["defenseSkillBonus"], float(pool.get("defenseSkillBonus", 0.0)))
        context["arpBonus"] = max(context["arpBonus"], float(pool.get("arpBonus", 0.0)))
    return context


def get_cap_weapon_subtypes(items: list[dict[str, Any]]) -> set[str]:
    subtypes: set[str] = set()
    for item in items:
        slot_id = int(item.get("slotId", 0) or 0)
        if slot_id in {16, 17}:
            subtype = str(item.get("subType") or "").upper()
            if subtype:
                subtypes.add(subtype)
    return subtypes


def get_racial_cap_context(race_token: str | None, items: list[dict[str, Any]], tables: dict[str, Any]) -> dict[str, float]:
    context = create_cap_context()
    if not race_token:
        return context
    racial = (tables.get("GS_PermanentCapRacials") or {}).get(race_token)
    if not racial:
        return context
    expertise = racial.get("EXPERTISE") or {}
    for subtype in get_cap_weapon_subtypes(items):
        if (expertise.get("subTypes") or {}).get(subtype):
            context["expertiseBonus"] = float(expertise.get("bonus", 0.0))
            break
    return context


def did_cap_pool_use_live_buffs(pool_stat: str, target_segment: dict[str, Any] | None, context: dict[str, float]) -> bool:
    if not target_segment:
        return False
    mode = target_segment.get("mode")
    if mode == "MELEE_HIT_PERCENT":
        return context.get("liveMeleeHitBonus", 0.0) > 0
    if mode == "SPELL_HIT_PERCENT":
        return context.get("liveSpellHitBonus", 0.0) > 0 or context.get("liveTargetSpellHitBonus", 0.0) > 0
    if mode == "EXPERTISE_POINTS":
        return context.get("liveExpertiseBonus", 0.0) > 0
    if mode == "DEFENSE_SKILL":
        return context.get("liveDefenseSkillBonus", 0.0) > 0
    if pool_stat == "ARP":
        return context.get("liveArpBonus", 0.0) > 0
    return False


def collect_snapshot_stats(items: list[dict[str, Any]]) -> dict[str, float]:
    totals: dict[str, float] = {}
    for item in items:
        for stat_source in [item.get("stats")] + item.get("gemStats", []) + [item.get("enchantInfo", {}).get("stats")]:
            if not stat_source:
                continue
            for stat, value in stat_source.items():
                totals[stat] = totals.get(stat, 0) + float(value)
    return totals


def get_cap_pool_stat_value(pool_stat: str, total_stats: dict[str, float]) -> float:
    if pool_stat == "SPELL_HIT":
        return total_stats.get("HIT", 0.0)
    return total_stats.get(pool_stat, 0.0)


def apply_character_caps(class_token: str, spec_key: str, items: list[dict[str, Any]], pre_cap_gs2: int, tables: dict[str, Any], race_token: str | None = None) -> tuple[int, dict[str, Any] | None, dict[str, float]]:
    cap_profile = tables["GS_CapProfiles"].get(spec_key)
    profile, _ = get_profile(class_token, spec_key, tables, items, race_token)
    total_stats = collect_snapshot_stats(items)
    if not cap_profile or not profile or not profile.get("pve"):
        return 0, None, total_stats

    permanent_context = get_base_cap_context(spec_key, tables)
    racial_context = get_racial_cap_context(race_token, items, tables)
    for key, value in racial_context.items():
        if isinstance(value, (int, float)) and value:
            permanent_context[key] = permanent_context.get(key, 0.0) + float(value)
    temporary_context = create_cap_context()

    pools = []
    for stat in cap_profile.get("order", []):
        pool = cap_profile.get("pools", {}).get(stat)
        base_weight = profile.get("pve", {}).get(stat)
        if base_weight is None and stat == "SPELL_HIT":
            base_weight = profile.get("pve", {}).get("HIT")
        stat_value = get_cap_pool_stat_value(stat, total_stats)
        if pool and base_weight and stat_value > 0:
            target_segment, resolved_threshold = get_cap_progress_target(
                stat,
                pool,
                permanent_context,
                spec_key,
                tables["GS_RatingConversions"],
            )
            current, target, rating_summary = get_cap_pool_display(
                stat,
                stat_value,
                target_segment,
                resolved_threshold,
                permanent_context,
                tables["GS_RatingConversions"],
            )
            progress = min(max((current / target), 0.0), 1.0) if target > 0 else 0.0
            context_bonus = get_cap_pool_context_bonus(stat, target_segment, permanent_context)
            display_current, display_target, _ = get_cap_pool_display(
                stat,
                stat_value,
                target_segment,
                resolved_threshold,
                temporary_context,
                tables["GS_RatingConversions"],
            )
            pools.append(
                {
                    "stat": stat,
                    "summary": pool.get("summary", stat),
                    "rawValue": stat_value,
                    "baseWeight": base_weight,
                    "progress": progress,
                    "current": current,
                    "target": target,
                    "targetSegment": target_segment,
                    "targetThreshold": resolved_threshold,
                    "ratingSummary": rating_summary,
                    "contextBonus": context_bonus,
                    "permanentContextBonus": context_bonus,
                    "temporaryContextBonus": get_cap_pool_context_bonus(stat, target_segment, temporary_context),
                    "capped": progress >= 1,
                    "displayCurrent": display_current,
                    "displayTarget": display_target,
                    "usedLiveBuffs": did_cap_pool_use_live_buffs(stat, target_segment, temporary_context),
                    "bonusGs2": 0,
                }
            )

    overall_progress = (sum(pool["progress"] for pool in pools) / len(pools)) if pools else 0.0
    max_bonus = get_max_cap_bonus(pre_cap_gs2)
    delta_gs2 = math.floor(max_bonus * overall_progress)
    positive_total = sum(pool["progress"] for pool in pools if pool["progress"] > 0)
    remaining = delta_gs2
    last_positive = max((idx for idx, pool in enumerate(pools) if pool["progress"] > 0), default=-1)
    for idx, pool in enumerate(pools):
        if pool["progress"] <= 0 or positive_total <= 0 or delta_gs2 <= 0:
            pool["bonusGs2"] = 0
        elif idx == last_positive:
            pool["bonusGs2"] = remaining
        else:
            bonus = math.floor(delta_gs2 * (pool["progress"] / positive_total))
            pool["bonusGs2"] = bonus
            remaining -= bonus

    summary_parts = []
    for pool in pools:
        if pool["progress"] <= 0:
            continue
        label = f"{pool['summary']} capped" if pool["capped"] else f"{pool['summary']} {math.floor(pool['progress'] * 100 + 0.5)}%"
        summary_parts.append(f"{label} (+{pool['bonusGs2']} GS2)")
    breakdown = {
        "pools": pools,
        "summary": ", ".join(summary_parts) if summary_parts else None,
        "context": permanent_context,
        "permanentContext": permanent_context,
        "temporaryContext": temporary_context,
        "preCapGs2": pre_cap_gs2,
        "overallProgress": overall_progress,
        "maxBonus": max_bonus,
        "deltaGs2": delta_gs2,
    }
    return delta_gs2, breakdown, total_stats


def get_candidate_signature_floor(role: str | None, item_count: int) -> int:
    if role == "TANK":
        return 2
    if role == "HEALER":
        return max(3, math.floor(item_count * 0.18))
    if role == "CASTER":
        return max(4, math.floor(item_count * 0.25))
    return max(4, math.floor(item_count * 0.25))


def clamp01(value: float) -> float:
    return max(0.0, min(1.0, float(value)))


def should_apply_signature_fit_penalty(role: str | None, spec_key: str | None) -> bool:
    if spec_key == "DRUID_FERAL_TANK":
        return False
    return role in {"TANK", "HEALER", "CASTER"}


def calculate_snapshot_fit_multiplier(role: str | None, spec_key: str | None, item_count: int, matched_items: int, signature_items: int, tables: dict[str, Any]) -> tuple[float, float]:
    constants = tables["constants"]
    if item_count <= 0:
        return 1.0, 1.0
    matched_ratio = matched_items / item_count
    ratio_floor = float(constants.get("OFFSPEC_FIT_MATCH_RATIO_FLOOR", GS_OFFSPEC_FIT_MATCH_RATIO_FLOOR))
    ratio_full = float(constants.get("OFFSPEC_FIT_MATCH_RATIO_FULL", GS_OFFSPEC_FIT_MATCH_RATIO_FULL))
    multiplier_floor = float(constants.get("OFFSPEC_FIT_MULTIPLIER_FLOOR", GS_OFFSPEC_FIT_MULTIPLIER_FLOOR))
    signature_penalty = float(constants.get("OFFSPEC_FIT_SIGNATURE_PENALTY", GS_OFFSPEC_FIT_SIGNATURE_PENALTY))
    ratio_range = ratio_full - ratio_floor
    if ratio_range > 0:
        fit_progress = clamp01((matched_ratio - ratio_floor) / ratio_range)
    else:
        fit_progress = 1.0 if matched_ratio >= ratio_full else 0.0
    fit_multiplier = multiplier_floor + ((1.0 - multiplier_floor) * fit_progress)
    if should_apply_signature_fit_penalty(role, spec_key):
        required_signature_items = get_candidate_signature_floor(role, item_count)
        if signature_items < required_signature_items:
            fit_multiplier *= signature_penalty
    return fit_multiplier, matched_ratio


def get_snapshot_spec_diagnostics(items: list[dict[str, Any]], class_token: str, spec_key: str, tables: dict[str, Any], race_token: str | None = None) -> dict[str, Any] | None:
    profile, resolved_spec = get_profile(class_token, spec_key, tables, items, race_token)
    if not profile:
        return None
    compatible_items = 0
    matched_items = 0
    signature_items = 0
    positive_slots: list[str] = []
    signature_slots: list[str] = []
    total_before_caps = 0
    legacy_total = 0
    for item in items:
        item_gs2, _, _ = score_item(item, class_token, spec_key, tables)
        total_before_caps += item_gs2
        legacy_total += int(item.get("legacyBase", 0))
        if is_item_compatible(item, class_token, profile):
            compatible_items += 1
            raw_score = score_stats(item.get("stats"), profile.get("pve"))
            gem_score = sum(score_stats(gem, profile.get("pve")) for gem in item.get("gemStats", []))
            enchant_score = score_stats((item.get("enchantInfo") or {}).get("stats"), profile.get("pve"))
            if raw_score > 0 or gem_score > 0 or enchant_score > 0:
                matched_items += 1
                positive_slots.append(str(item.get("slotId", 0)))
            if get_role_signature_kind(item) == profile.get("role"):
                signature_items += 1
                signature_slots.append(str(item.get("slotId", 0)))
    cap_bonus, _, _ = apply_character_caps(class_token, resolved_spec, items, total_before_caps, tables, race_token)
    fit_multiplier, matched_ratio = calculate_snapshot_fit_multiplier(
        profile.get("role"), resolved_spec, len(items), matched_items, signature_items, tables
    )
    pre_fit_total = total_before_caps + cap_bonus
    return {
        "spec_key": resolved_spec,
        "role": profile.get("role"),
        "item_count": len(items),
        "compatible_items": compatible_items,
        "matched_items": matched_items,
        "signature_items": signature_items,
        "legacy_total": legacy_total,
        "total_before_caps": total_before_caps,
        "cap_bonus": cap_bonus,
        "pre_fit_total": pre_fit_total,
        "matched_ratio": matched_ratio,
        "fit_multiplier": fit_multiplier,
        "total": math.floor(pre_fit_total * fit_multiplier),
        "positive_slots": positive_slots,
        "signature_slots": signature_slots,
    }


def is_plausible_offspec_candidate(items: list[dict[str, Any]], diagnostics: dict[str, Any] | None) -> tuple[bool, str]:
    if not items or not diagnostics:
        return False, "no diagnostics"
    item_count = int(diagnostics.get("item_count", len(items)))
    required_matched_items = max(4, math.floor(item_count * 0.35))
    required_signature_items = get_candidate_signature_floor(diagnostics.get("role"), item_count)
    if int(diagnostics.get("compatible_items", 0)) < max(6, math.floor(item_count * 0.6)):
        return False, "too few compatible items"
    if int(diagnostics.get("matched_items", 0)) < required_matched_items:
        return False, "too few matched items"
    if diagnostics.get("spec_key") == "DRUID_FERAL_TANK":
        return True, "plausible"
    if diagnostics.get("role") in {"TANK", "HEALER", "CASTER"} and int(diagnostics.get("signature_items", 0)) < required_signature_items:
        return False, "insufficient role signature"
    return True, "plausible"


def get_offspec_reason(active_diagnostics: dict[str, Any] | None, alternate_diagnostics: dict[str, Any] | None) -> str:
    if not active_diagnostics or not alternate_diagnostics:
        return "unknown"
    if int(alternate_diagnostics.get("compatible_items", 0)) > int(active_diagnostics.get("compatible_items", 0)):
        return "item acceptance"
    return "weight overlap"


def get_best_snapshot_spec(items: list[dict[str, Any]], class_token: str, tables: dict[str, Any], race_token: str | None = None, excluded_spec_key: str | None = None) -> tuple[str | None, int | None, dict[str, Any] | None]:
    candidates = get_class_spec_candidates(class_token, tables)
    best_spec: str | None = None
    best_score: int | None = None
    best_diagnostics: dict[str, Any] | None = None
    for candidate_spec in candidates:
        if candidate_spec == excluded_spec_key or candidate_spec not in tables["GS_SpecProfiles"]:
            continue
        diagnostics = get_snapshot_spec_diagnostics(items, class_token, candidate_spec, tables, race_token)
        plausible, _ = is_plausible_offspec_candidate(items, diagnostics)
        total = diagnostics.get("total") if diagnostics else None
        if plausible and total is not None and (best_score is None or total > best_score):
            best_spec = candidate_spec
            best_score = int(total)
            best_diagnostics = diagnostics
    return best_spec, best_score, best_diagnostics


def safe_json_value(value: Any) -> Any:
    if isinstance(value, dict):
        return {str(key): safe_json_value(val) for key, val in value.items()}
    if isinstance(value, list):
        return [safe_json_value(item) for item in value]
    if isinstance(value, float):
        return round(value, 4)
    return value


def parse_item_page(item_id: int, slot_id: int, fetcher: Fetcher) -> dict[str, Any]:
    html_text = fetcher.fetch_text(
        f"https://wotlkdb.com/?item={item_id}",
        f"wotlkdb/items/{item_id}.html",
    )
    quality_match = re.search(rf"_\[{item_id}\]=\{{\"quality\":(\d+).*?\"name_enus\":\"([^\"]+)\"", html_text, re.DOTALL)
    tooltip_match = re.search(rf"_\[{item_id}\]\.tooltip_enus = \"(.*?)\";", html_text, re.DOTALL)
    if not quality_match or not tooltip_match:
        raise RuntimeError(f"Could not parse WotLKDB item page for {item_id}")
    tooltip_html = json.loads(f"\"{tooltip_match.group(1)}\"")
    tooltip_text = strip_tags(tooltip_html)
    level_match = re.search(r"Item Level (\d+)", tooltip_text)
    slot_label, subtype = parse_slot_and_subtype_from_tooltip(tooltip_text)
    stats, socket_count = parse_stats_from_text(tooltip_text)
    equip_loc = infer_equip_loc(slot_id, slot_label, subtype, tooltip_text)
    socket_colors = [color.upper() for color in re.findall(r"socket-([a-z]+)\s+q0", tooltip_html, re.IGNORECASE)]
    socket_bonus_match = re.search(r"Socket Bonus:\s*(.*?)<", tooltip_html, re.IGNORECASE | re.DOTALL)
    socket_bonus_stats = parse_stat_phrase(strip_tags(socket_bonus_match.group(1))) if socket_bonus_match else {}
    return {
        "itemId": item_id,
        "name": html.unescape(quality_match.group(2)),
        "rarity": int(quality_match.group(1)),
        "level": int(level_match.group(1)) if level_match else 0,
        "subType": subtype.upper(),
        "equipLoc": equip_loc,
        "stats": stats,
        "socketCount": socket_count,
        "socketColors": socket_colors,
        "socketBonusStats": socket_bonus_stats,
        "resilience": stats.get("RESILIENCE", 0.0),
        "armorRank": ARMOR_SUBTYPE_TO_RANK.get(subtype.upper()),
    }


def parse_gem_page(gem_id: int, fetcher: Fetcher) -> tuple[str, int, int | None, dict[str, float], set[str]]:
    html_text = fetcher.fetch_text(
        f"https://wotlkdb.com/?enchantment={gem_id}",
        f"wotlkdb/enchantments/{gem_id}.html",
    )
    title_match = re.search(r"<title>([^<]+?) - Enchantment - WotLK Database 3\.3\.5a</title>", html_text)
    gem_match = re.search(r'"id":"used-by-gem".*?\{"id":(\d+),"name":"(\d)([^"]+)".*?"subclass":(\d+)', html_text, re.DOTALL)
    if not title_match:
        return f"UNKNOWN_GEM_{gem_id}", 4, None, {}, set()
    enchant_name = html.unescape(title_match.group(1)).strip()
    stats = parse_inline_stat_string(enchant_name)
    if not stats:
        detail_stats = re.findall(r"Statistics:.*?<small><br>Value: (\d+)</small>.*?LANG\.traits\['([^']+)'\]\[0\]", html_text, re.DOTALL)
        trait_map = {
            "str": "STR",
            "agi": "AGI",
            "sta": "STA",
            "int": "INT",
            "spi": "SPI",
            "map5s": "MP5",
            "hitrtng": "HIT",
            "critstrkrtng": "CRIT",
            "hastertng": "HASTE",
            "resirtng": "RESILIENCE",
            "exprtng": "EXPERTISE",
            "dodgertng": "DODGE",
            "parryrtng": "PARRY",
            "defrtng": "DEFENSE",
            "splpwr": "SP",
            "atkpwr": "AP",
            "ratkpwr": "RAP",
            "armorpenrtng": "ARP",
        }
        for amount_text, trait in detail_stats:
            stat_key = trait_map.get(trait.lower())
            if stat_key:
                stats[stat_key] = stats.get(stat_key, 0) + float(amount_text)
    if gem_match:
        item_id = int(gem_match.group(1))
        quality = int(gem_match.group(2))
        gem_name = html.unescape(gem_match.group(3))
        subclass = int(gem_match.group(4))
        return gem_name, quality, item_id, stats, GEM_SUBCLASS_TO_COLORS.get(subclass, set())
    return enchant_name, 4, None, stats, set()


def get_gem_fallback_stats(gem_name: str, quality: int) -> dict[str, float] | None:
    amount = 20 if quality == 4 else 16
    if "Rigid" in gem_name:
        return {"HIT": amount}
    if "Delicate" in gem_name:
        return {"AGI": amount}
    if "Bold" in gem_name:
        return {"STR": amount}
    if "Bright" in gem_name:
        return {"INT": amount}
    if "Solid" in gem_name:
        return {"STA": amount}
    if "Runed" in gem_name:
        return {"SP": amount * 1.15}
    if "Quick" in gem_name:
        return {"HASTE": amount}
    if "Smooth" in gem_name:
        return {"CRIT": amount}
    if "Fractured" in gem_name:
        return {"ARP": amount}
    if "Precise" in gem_name:
        return {"EXPERTISE": amount}
    return None


def resolve_gem(gem_id: int, fetcher: Fetcher, gem_cache: dict[int, ResolvedGem]) -> ResolvedGem:
    if gem_id in gem_cache:
        return gem_cache[gem_id]
    gem_name, quality, item_id, gem_stats, colors = parse_gem_page(gem_id, fetcher)
    used_fallback = False
    if not gem_stats:
        gem_stats = get_gem_fallback_stats(gem_name, quality) or {}
        used_fallback = bool(gem_stats)
    resolved = ResolvedGem(
        source_id=gem_id,
        item_id=item_id,
        name=gem_name,
        quality=quality,
        stats=gem_stats,
        colors=colors,
        used_fallback=used_fallback,
    )
    gem_cache[gem_id] = resolved
    return resolved


def parse_warmane_profile(ref: WarmaneCharacterRef, fetcher: Fetcher) -> dict[str, Any]:
    html_text = fetcher.fetch_text(ref.url, f"warmane/{slugify_url(ref.url)}.html")
    name_match = re.search(r"<div class=\"name\">([^<]+)", html_text)
    level_class_match = re.search(r"<div class=\"level-race-class\">\s*Level\s+(\d+)\s+([^<,]+),\s*([^<\n]+)", html_text)
    if not name_match or not level_class_match:
        raise RuntimeError(f"Could not parse Warmane profile header for {ref.url}")
    character_name = html.unescape(name_match.group(1)).strip()
    race_and_class = level_class_match.group(2).strip()
    class_token = normalize_class_name(race_and_class)
    race_token = normalize_race_name(race_and_class)
    class_name = class_token

    profile_blocks = re.findall(r"<div class=\"specialization\">(.*?)</div>\s*<div class=\"clear\"></div>", html_text, re.DOTALL)
    spec_entries = []
    if profile_blocks:
        spec_entries = re.findall(r"<div class=\"text\">\s*([A-Za-z ]+)\s*<span class=\"value\">([0-9\s/]+)</span>", profile_blocks[0])
    if not spec_entries:
        raise RuntimeError(f"Could not parse specialization block for {ref.url}")
    active_spec_label = spec_entries[0][0].strip()
    active_spec = normalize_spec_name(active_spec_label, class_name)
    talent_trees = [
        {
            "label": label.strip(),
            "spec_key": normalize_spec_name(label.strip(), class_name),
            "points": points.strip(),
        }
        for label, points in spec_entries
    ]

    stats_snapshot: dict[str, Any] = {}
    stats_block_match = re.search(r"<div class=\"character-stats\">(.*?)</div>\s*</div>\s*<div class=\"information-right\">", html_text, re.DOTALL)
    if stats_block_match:
        stats_text = strip_tags(stats_block_match.group(1))
        sections = {}
        current = None
        for raw_line in stats_text.splitlines():
            line = raw_line.strip()
            if not line:
                continue
            if line in {"Melee", "Attributes", "Ranged", "Defense", "Spell", "Resistances"}:
                current = line
                sections[current] = {}
                continue
            if current and ":" in line:
                label, value = [part.strip() for part in line.split(":", 1)]
                sections[current][label] = parse_number(value)
        stats_snapshot = sections

    items = []
    gear_end = html_text.find('<div class="model">')
    gear_html = html_text[:gear_end] if gear_end != -1 else html_text
    order = 0
    for section_index, (section_name, slot_order) in enumerate(PROFILE_SLOT_SECTIONS):
        section_start = gear_html.find(f'<div class="{section_name}">')
        if section_start == -1:
            continue
        section_end = gear_end if gear_end != -1 else len(gear_html)
        for next_section_name, _ in PROFILE_SLOT_SECTIONS[section_index + 1:]:
            next_start = gear_html.find(f'<div class="{next_section_name}">', section_start + 1)
            if next_start != -1 and next_start < section_end:
                section_end = next_start
                break
        section_html = gear_html[section_start:section_end]
        slot_blocks = re.findall(r'<div class="item-slot">(.*?)</div>\s*</div>', section_html, re.DOTALL)
        for index, slot_id in enumerate(slot_order):
            if index >= len(slot_blocks):
                break
            block_html = slot_blocks[index]
            rel_match = re.search(r'rel="item=(\d+)(?:&amp;ench=(\d+))?(?:&amp;gems=([0-9:]+))?', block_html)
            if not rel_match:
                continue
            item_id_text, enchant_id_text, gems_text = rel_match.groups()
            gem_ids = [int(part) for part in gems_text.split(":")] if gems_text else []
            items.append(
                {
                    "order": order,
                    "inventorySlot": slot_id,
                    "itemId": int(item_id_text),
                    "enchantId": int(enchant_id_text) if enchant_id_text else 0,
                    "gemIds": [gem_id for gem_id in gem_ids if gem_id > 0],
                }
            )
            order += 1

    return {
        "name": character_name,
        "realm": ref.realm,
        "url": ref.url,
        "classToken": class_token,
        "raceToken": race_token,
        "activeSpec": active_spec,
        "activeSpecLabel": active_spec_label,
        "talentTrees": talent_trees,
        "statsSnapshot": stats_snapshot,
        "items": items,
    }


def build_character_record(
    profile: dict[str, Any],
    fetcher: Fetcher,
    tables: dict[str, Any],
    item_cache: dict[tuple[int, int], dict[str, Any]],
    gem_cache: dict[int, ResolvedGem],
    prefer_inferred_selection: bool = True,
) -> dict[str, Any]:
    prepared_items = []
    enriched_items = []
    runtime_items = []
    legacy = 0
    item_levels = []
    diagnostics: list[str] = []

    for entry in profile["items"]:
        slot_id = entry.get("inventorySlot") or 0
        if slot_id in IGNORED_BENCHMARK_SLOT_IDS:
            continue
        item_id = entry["itemId"]
        cache_key = (item_id, slot_id)
        if cache_key not in item_cache:
            item_cache[cache_key] = parse_item_page(item_id, slot_id, fetcher)
        base_item = dict(item_cache[cache_key])
        base_item["slotId"] = slot_id or assign_slot_id(base_item["equipLoc"], {})
        base_item["slot"] = get_item_slot_value(base_item["equipLoc"], tables["GS_ItemTypes"])
        base_item["enchantId"] = entry["enchantId"]
        base_item["hasEnchant"] = entry["enchantId"] > 0
        base_item["enchantInfo"] = tables["GS_EnchantValues"].get(entry["enchantId"])
        base_item["legacyBase"] = calculate_legacy_base(base_item, tables["GS_ItemTypes"], tables["GS_Formula"])
        base_item["gemStats"] = []
        resolved_gems: list[ResolvedGem] = []
        for gem_id in entry["gemIds"]:
            resolved_gem = resolve_gem(gem_id, fetcher, gem_cache)
            if resolved_gem.name.startswith("UNKNOWN_GEM_"):
                diagnostics.append(f"slot-{base_item['slotId']}:unknown-gem-{gem_id}")
            base_item["gemStats"].append(resolved_gem.stats)
            resolved_gems.append(resolved_gem)
        item_legacy = get_hunter_legacy(base_item["slotId"], base_item) if profile["classToken"] == "HUNTER" else base_item["legacyBase"]
        legacy += item_legacy
        item_levels.append(base_item["level"])

        runtime_items.append(
            {
                "slotId": base_item["slotId"],
                "equipLoc": base_item["equipLoc"],
                "subType": base_item["subType"],
                "armorRank": base_item.get("armorRank"),
                "stats": base_item["stats"],
                "gemStats": base_item["gemStats"],
                "enchantInfo": base_item["enchantInfo"] or {},
                "legacyBase": base_item["legacyBase"],
                "slot": base_item["slot"],
            }
        )
        prepared_items.append(
            {
                "entry": entry,
                "item_id": item_id,
                "item_legacy": item_legacy,
                "base_item": base_item,
                "resolved_gems": resolved_gems,
            }
        )

    resolved_profile, resolved_spec = get_profile(
        profile["classToken"],
        profile["activeSpec"],
        tables,
        runtime_items,
        profile.get("raceToken"),
    )
    class_token = profile["classToken"]

    gs2_pre_cap = 0
    pvp_gs = 0
    for prepared in prepared_items:
        entry = prepared["entry"]
        item_id = prepared["item_id"]
        item_legacy = prepared["item_legacy"]
        base_item = prepared["base_item"]
        resolved_gems = prepared["resolved_gems"]
        item_gs2, item_pvp, item_flags, item_debug = score_item_with_debug(base_item, profile["classToken"], resolved_spec, tables)
        gs2_pre_cap += item_gs2
        pvp_gs += item_pvp
        diagnostics.extend(f"slot-{base_item['slotId']}:{flag}" for flag in item_flags)
        enriched_items.append(
            {
                "slot_id": base_item["slotId"],
                "item_id": item_id,
                "name": base_item["name"],
                "item_level": base_item["level"],
                "equip_loc": base_item["equipLoc"],
                "sub_type": base_item["subType"],
                "legacy_gs": item_legacy,
                "gs2": item_gs2,
                "pvp_gs": item_pvp,
                "enchant_id": entry["enchantId"],
                "enchant_info": safe_json_value(base_item["enchantInfo"]),
                "gem_ids": entry["gemIds"],
                "stats": safe_json_value(base_item["stats"]),
                "gem_stats": safe_json_value(base_item["gemStats"]),
                "resolved_gems": [
                    {
                        "source_id": gem.source_id,
                        "item_id": gem.item_id,
                        "name": gem.name,
                        "quality": gem.quality,
                        "colors": sorted(gem.colors),
                        "used_fallback": gem.used_fallback,
                        "stats": safe_json_value(gem.stats),
                    }
                    for gem in resolved_gems
                ],
                "score_breakdown": safe_json_value(item_debug),
            }
        )

    active_diagnostics = get_snapshot_spec_diagnostics(runtime_items, profile["classToken"], resolved_spec, tables, profile.get("raceToken"))
    cap_bonus, cap_breakdown, cap_stats = apply_character_caps(class_token, resolved_spec, runtime_items, gs2_pre_cap, tables, profile.get("raceToken"))
    active_spec_gs2 = math.floor(active_diagnostics["total"]) if active_diagnostics else math.floor(gs2_pre_cap + cap_bonus)
    best_alternate_spec, best_alternate_gs2, best_alternate_diagnostics = get_best_snapshot_spec(
        runtime_items,
        profile["classToken"],
        tables,
        profile.get("raceToken"),
        excluded_spec_key=resolved_spec,
    )
    inferred_reason = None
    if best_alternate_gs2 is not None and active_spec_gs2 > 0:
        inferred_reason = get_offspec_reason(active_diagnostics, best_alternate_diagnostics)
    selected_spec = resolved_spec
    selected_spec_gs2 = active_spec_gs2
    selected_cap_bonus = cap_bonus
    selected_cap_breakdown = cap_breakdown
    selected_cap_stats = cap_stats
    selected_source = "active"
    if prefer_inferred_selection and best_alternate_spec and best_alternate_gs2 is not None and best_alternate_gs2 > active_spec_gs2:
        selected_spec = best_alternate_spec
        selected_spec_gs2 = math.floor(best_alternate_gs2)
        selected_source = "inferred"
        selected_cap_bonus, selected_cap_breakdown, selected_cap_stats = apply_character_caps(
            class_token,
            best_alternate_spec,
            runtime_items,
            best_alternate_diagnostics["total_before_caps"] if best_alternate_diagnostics else 0,
            tables,
            profile.get("raceToken"),
        )
    avg_item_level = math.floor(sum(item_levels) / len(item_levels)) if item_levels else 0
    diagnostic_summary = build_diagnostic_summary(sorted(set(diagnostics)))
    return {
        "name": profile["name"],
        "realm": profile["realm"],
        "url": profile["url"],
        "class": profile["classToken"],
        "race": profile.get("raceToken"),
        "active_spec": resolved_spec,
        "active_spec_label": profile["activeSpecLabel"],
        "talent_trees": safe_json_value(profile["talentTrees"]),
        "role": resolved_profile["role"],
        "spec_profile": safe_json_value(resolved_profile),
        "item_count": len(item_levels),
        "avg_item_level": avg_item_level,
        "legacy_gs": math.floor(legacy),
        "gs2_pre_cap": math.floor(gs2_pre_cap),
        "gs2_cap_bonus": cap_bonus,
        "gs2_final": selected_spec_gs2,
        "active_spec_gs2": active_spec_gs2,
        "inferred_spec": best_alternate_spec,
        "inferred_spec_gs2": math.floor(best_alternate_gs2) if best_alternate_gs2 is not None else None,
        "inferred_reason": inferred_reason,
        "selected_spec": selected_spec,
        "selected_spec_gs2": selected_spec_gs2,
        "selected_spec_source": selected_source,
        "off_spec_diagnostics": safe_json_value({"active": active_diagnostics, "alternate": best_alternate_diagnostics}),
        "pvp_gs": math.floor(pvp_gs),
        "items": enriched_items,
        "stats_snapshot": safe_json_value(profile["statsSnapshot"]),
        "cap_breakdown": safe_json_value(selected_cap_breakdown),
        "cap_stats": safe_json_value(selected_cap_stats),
        "data_sources": {
            "snapshot": "warmane",
            "item_stats": "wotlkdb",
            "scoring_logic": "lua_runtime_tables",
        },
        "diagnostics": sorted(set(diagnostics)),
        "diagnostic_summary": safe_json_value(diagnostic_summary),
        "benchmark_quality_tier": diagnostic_summary["quality_tier"],
        "clean_record_flag": diagnostic_summary["clean_record_flag"],
    }


def median(values: list[float]) -> float:
    return statistics.median(values) if values else 0.0


def pct_delta(value: float, baseline: float) -> float:
    if baseline == 0:
        return 0.0
    return ((value - baseline) / baseline) * 100.0


def parse_diagnostic_token(token: str) -> tuple[int | None, str]:
    match = re.match(r"^slot-(\d+):(.+)$", token)
    if not match:
        return None, token
    return int(match.group(1)), match.group(2)


def classify_diagnostic(token: str) -> str:
    slot_id, issue = parse_diagnostic_token(token)
    if issue.startswith("unknown-gem-") or issue == "unknown-enchant":
        return DIAGNOSTIC_CATEGORY_BLOCKER
    if issue == "special-enchant-unscored":
        return DIAGNOSTIC_CATEGORY_INFORMATIONAL
    if issue in {"gem-mismatch", "enchant-mismatch"}:
        return DIAGNOSTIC_CATEGORY_OPTIMIZATION
    if issue == "incompatible-item":
        if slot_id in IGNORED_BENCHMARK_SLOT_IDS:
            return DIAGNOSTIC_CATEGORY_INFORMATIONAL
        return DIAGNOSTIC_CATEGORY_COMPATIBILITY
    return DIAGNOSTIC_CATEGORY_INFORMATIONAL


def build_diagnostic_summary(diagnostics: list[str]) -> dict[str, Any]:
    categorized: dict[str, list[str]] = {category: [] for category in DIAGNOSTIC_CATEGORY_ORDER}
    for token in diagnostics:
        categorized[classify_diagnostic(token)].append(token)
    counts = {category: len(entries) for category, entries in categorized.items()}
    if counts[DIAGNOSTIC_CATEGORY_BLOCKER] > 0:
        quality_tier = QUALITY_TIER_BLOCKED
    elif counts[DIAGNOSTIC_CATEGORY_COMPATIBILITY] > 0:
        quality_tier = QUALITY_TIER_NOISY
    elif counts[DIAGNOSTIC_CATEGORY_OPTIMIZATION] > 0:
        quality_tier = QUALITY_TIER_REVIEW
    else:
        quality_tier = QUALITY_TIER_CLEAN
    return {
        "categorized": categorized,
        "counts": counts,
        "quality_tier": quality_tier,
        "clean_record_flag": counts[DIAGNOSTIC_CATEGORY_COMPATIBILITY] == 0 and counts[DIAGNOSTIC_CATEGORY_BLOCKER] == 0,
    }


def summarize_group(records: list[dict[str, Any]]) -> dict[str, Any]:
    values = [record["gs2_final"] for record in records]
    med = median(values)
    min_value = min(values) if values else 0
    max_value = max(values) if values else 0
    return {
        "size": len(values),
        "median_gs2": med,
        "min_gs2": min_value,
        "max_gs2": max_value,
        "spread_pct": (pct_delta(max_value, med) - pct_delta(min_value, med)) if med else 0.0,
    }


def build_spec_delta_rankings(records: list[dict[str, Any]], limit: int = 5) -> dict[str, list[dict[str, Any]]]:
    spec_groups: dict[str, list[dict[str, Any]]] = {}
    for record in records:
        spec_groups.setdefault(str(record.get("selected_spec") or record["active_spec"]), []).append(record)
    rows: list[dict[str, Any]] = []
    for spec, group_records in spec_groups.items():
        deltas = [record["gs2_final"] - record["legacy_gs"] for record in group_records]
        rows.append(
            {
                "spec": spec,
                "size": len(group_records),
                "median_delta": round(median(deltas), 2),
                "min_delta": min(deltas),
                "max_delta": max(deltas),
                "spread_delta": max(deltas) - min(deltas),
            }
        )
    ordered = sorted(rows, key=lambda row: (row["median_delta"], row["size"], row["spec"]))
    return {
        "top_positive_spec_deltas": ordered[-limit:][::-1],
        "top_negative_spec_deltas": ordered[:limit],
    }


def enrich_component_metrics(record: dict[str, Any]) -> dict[str, Any]:
    gs2_final = int(record.get("gs2_final") or 0)
    legacy_gs = int(record.get("legacy_gs") or 0)
    gs2_pre_cap = int(record.get("gs2_pre_cap") or 0)
    record["delta_from_legacy"] = gs2_final - legacy_gs
    record["pve_bonus_bucket_effective"] = gs2_pre_cap - legacy_gs
    return record


def build_phase_component_summary(records: list[dict[str, Any]]) -> dict[str, Any]:
    if not records:
        return {
            "size": 0,
            "median_legacy_gs": 0.0,
            "median_gs2_pre_cap": 0.0,
            "median_gs2_final": 0.0,
            "median_gs2_cap_bonus": 0.0,
            "median_delta_from_legacy": 0.0,
            "median_pve_bonus_bucket_effective": 0.0,
            "spread_gs2_final": 0,
        }
    return {
        "size": len(records),
        "median_legacy_gs": round(median([record["legacy_gs"] for record in records]), 2),
        "median_gs2_pre_cap": round(median([record["gs2_pre_cap"] for record in records]), 2),
        "median_gs2_final": round(median([record["gs2_final"] for record in records]), 2),
        "median_gs2_cap_bonus": round(median([record["gs2_cap_bonus"] for record in records]), 2),
        "median_delta_from_legacy": round(median([record["delta_from_legacy"] for record in records]), 2),
        "median_pve_bonus_bucket_effective": round(median([record["pve_bonus_bucket_effective"] for record in records]), 2),
        "spread_gs2_final": max(record["gs2_final"] for record in records) - min(record["gs2_final"] for record in records),
    }


def build_phase_growth_trends(records: list[dict[str, Any]], group_field: str, phases: list[str]) -> list[dict[str, Any]]:
    grouped: dict[str, list[dict[str, Any]]] = {}
    for record in records:
        grouped.setdefault(str(record[group_field]), []).append(record)
    rows: list[dict[str, Any]] = []
    for group_name, group_records in grouped.items():
        phase_rows: dict[str, dict[str, Any]] = {}
        for phase in phases:
            matching = [record for record in group_records if record.get("phase") == phase]
            if not matching:
                continue
            phase_rows[phase] = {
                "legacy_gs": round(median([record["legacy_gs"] for record in matching]), 2),
                "gs2_pre_cap": round(median([record["gs2_pre_cap"] for record in matching]), 2),
                "gs2_cap_bonus": round(median([record["gs2_cap_bonus"] for record in matching]), 2),
                "gs2_final": round(median([record["gs2_final"] for record in matching]), 2),
                "delta_from_legacy": round(median([record["delta_from_legacy"] for record in matching]), 2),
                "pve_bonus_bucket_effective": round(median([record["pve_bonus_bucket_effective"] for record in matching]), 2),
            }
        if not phase_rows:
            continue
        ordered_phases = [phase for phase in phases if phase in phase_rows]
        start_phase = ordered_phases[0]
        end_phase = ordered_phases[-1]
        start = phase_rows[start_phase]
        end = phase_rows[end_phase]
        rows.append(
            {
                group_field: group_name,
                "start_phase": start_phase,
                "end_phase": end_phase,
                "phase_count": len(ordered_phases),
                "phases": safe_json_value(phase_rows),
                "gs2_final_growth": round(end["gs2_final"] - start["gs2_final"], 2),
                "delta_from_legacy_growth": round(end["delta_from_legacy"] - start["delta_from_legacy"], 2),
                "pve_bonus_bucket_growth": round(end["pve_bonus_bucket_effective"] - start["pve_bonus_bucket_effective"], 2),
                "cap_bonus_growth": round(end["gs2_cap_bonus"] - start["gs2_cap_bonus"], 2),
            }
        )
    rows.sort(key=lambda row: (row["delta_from_legacy_growth"], row["gs2_final_growth"], row[group_field]), reverse=True)
    return rows


def build_balance_slice(records: list[dict[str, Any]]) -> dict[str, Any]:
    if not records:
        return {
            "size": 0,
            "median_legacy": 0.0,
            "median_gs2": 0.0,
            "median_delta": 0.0,
            "legacy_spread": 0,
            "gs2_spread": 0,
            "delta_spread": 0,
            "min_gs2": 0,
            "max_gs2": 0,
            "spread_pct": 0.0,
            "top_positive_spec_deltas": [],
            "top_negative_spec_deltas": [],
        }
    legacy_values = [record["legacy_gs"] for record in records]
    gs2_values = [record["gs2_final"] for record in records]
    delta_values = [record["gs2_final"] - record["legacy_gs"] for record in records]
    rankings = build_spec_delta_rankings(records)
    return {
        "size": len(records),
        "median_legacy": round(median(legacy_values), 2),
        "median_gs2": round(median(gs2_values), 2),
        "median_delta": round(median(delta_values), 2),
        "legacy_spread": max(legacy_values) - min(legacy_values),
        "gs2_spread": max(gs2_values) - min(gs2_values),
        "delta_spread": max(delta_values) - min(delta_values),
        "min_gs2": min(gs2_values),
        "max_gs2": max(gs2_values),
        "spread_pct": round(
            pct_delta(max(gs2_values), median(gs2_values))
            - pct_delta(min(gs2_values), median(gs2_values)),
            2,
        ),
        "top_positive_spec_deltas": safe_json_value(rankings["top_positive_spec_deltas"]),
        "top_negative_spec_deltas": safe_json_value(rankings["top_negative_spec_deltas"]),
    }


def annotate_records(records: list[dict[str, Any]]) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    global_median = median([record["gs2_final"] for record in records])
    global_min = min(record["gs2_final"] for record in records)
    global_max = max(record["gs2_final"] for record in records)
    global_avg_ilvl_median = median([record["avg_item_level"] for record in records])
    spec_groups: dict[str, list[dict[str, Any]]] = {}
    role_groups: dict[str, list[dict[str, Any]]] = {}
    for record in records:
        spec_groups.setdefault(record.get("selected_spec") or record["active_spec"], []).append(record)
        role_groups.setdefault(record["role"], []).append(record)

    for record in records:
        spec_group_key = record.get("selected_spec") or record["active_spec"]
        spec_group = spec_groups[spec_group_key]
        group_records = spec_group if len(spec_group) >= 2 else role_groups[record["role"]]
        group_median = median([candidate["gs2_final"] for candidate in group_records])
        global_delta = pct_delta(record["gs2_final"], global_median)
        group_delta = pct_delta(record["gs2_final"], group_median)
        diagnostic_summary = record.get("diagnostic_summary") or build_diagnostic_summary(record.get("diagnostics", []))
        counts = diagnostic_summary["counts"]

        cap_progresses = {"HIT": None, "EXPERTISE": None, "DEFENSE": None, "ARP": None}
        red_flags: list[str] = []
        pools = (record.get("cap_breakdown") or {}).get("pools", [])
        for pool in pools:
            stat = pool.get("stat")
            if stat in cap_progresses:
                cap_progresses[stat] = round(float(pool.get("progress", 0.0)) * 100.0, 2)
                if float(pool.get("progress", 0.0)) < 0.9:
                    red_flags.append(f"{pool.get('summary', stat)} under cap")

        if abs(global_delta) > 10.0:
            red_flags.append("global spread outlier")
        if abs(group_delta) > 8.0:
            red_flags.append("group spread outlier")
        if record["avg_item_level"] >= global_avg_ilvl_median and global_delta < -8.0:
            red_flags.append("low GS2 for item level")
        if counts[DIAGNOSTIC_CATEGORY_COMPATIBILITY] > 0:
            red_flags.append("contains incompatible item")
        if counts[DIAGNOSTIC_CATEGORY_BLOCKER] > 0:
            red_flags.append("benchmark data gap")

        red_flag_reason = "; ".join(sorted(dict.fromkeys(red_flags)))
        outlier_flag = bool(red_flag_reason)
        clean_record_flag = bool(diagnostic_summary["clean_record_flag"])

        record.update(
            {
                "global_delta_from_median_pct": round(global_delta, 2),
                "group_delta_from_median_pct": round(group_delta, 2),
                "outlier_flag": outlier_flag,
                "benchmark_quality_tier": diagnostic_summary["quality_tier"],
                "clean_record_flag": clean_record_flag,
                "diagnostic_informational_count": counts[DIAGNOSTIC_CATEGORY_INFORMATIONAL],
                "diagnostic_optimization_count": counts[DIAGNOSTIC_CATEGORY_OPTIMIZATION],
                "diagnostic_compatibility_count": counts[DIAGNOSTIC_CATEGORY_COMPATIBILITY],
                "diagnostic_blocker_count": counts[DIAGNOSTIC_CATEGORY_BLOCKER],
                "cap_hit_progress": cap_progresses["HIT"],
                "cap_expertise_progress": cap_progresses["EXPERTISE"],
                "cap_defense_progress": cap_progresses["DEFENSE"],
                "cap_arp_progress": cap_progresses["ARP"],
                "red_flag_reason": red_flag_reason,
                "flags": {
                    "outlier_flag": outlier_flag,
                },
            }
        )

    tier_counts: dict[str, int] = {}
    for tier in (QUALITY_TIER_CLEAN, QUALITY_TIER_REVIEW, QUALITY_TIER_NOISY, QUALITY_TIER_BLOCKED):
        tier_counts[tier] = sum(1 for record in records if record["benchmark_quality_tier"] == tier)
    clean_records = [record for record in records if record["clean_record_flag"]]
    inferred_reason_counts: dict[str, int] = {}
    for record in records:
        if record.get("selected_spec_source") != "inferred":
            continue
        reason = str(record.get("inferred_reason") or "unknown")
        inferred_reason_counts[reason] = inferred_reason_counts.get(reason, 0) + 1
    summary = {
        "global_median_gs2": round(global_median, 2),
        "global_min_gs2": global_min,
        "global_max_gs2": global_max,
        "global_spread_pct": round((pct_delta(global_max, global_median) - pct_delta(global_min, global_median)) if global_median else 0.0, 2),
        "balance_target_spread_gs2": BALANCE_TARGET_SPREAD_GS2,
        "quality": {
            "clean_record_count": len(clean_records),
            "inferred_selected_count": sum(1 for record in records if record.get("selected_spec_source") == "inferred"),
            "inferred_reason_counts": safe_json_value(inferred_reason_counts),
            "quality_tier_counts": tier_counts,
            "diagnostic_character_counts": {
                DIAGNOSTIC_CATEGORY_INFORMATIONAL: sum(1 for record in records if record["diagnostic_informational_count"] > 0),
                DIAGNOSTIC_CATEGORY_OPTIMIZATION: sum(1 for record in records if record["diagnostic_optimization_count"] > 0),
                DIAGNOSTIC_CATEGORY_COMPATIBILITY: sum(1 for record in records if record["diagnostic_compatibility_count"] > 0),
                DIAGNOSTIC_CATEGORY_BLOCKER: sum(1 for record in records if record["diagnostic_blocker_count"] > 0),
            },
        },
        "balance_views": {
            "all_records": safe_json_value(build_balance_slice(records)),
            "clean_records": safe_json_value(build_balance_slice(clean_records)),
        },
    }
    return records, summary


def build_public_character_record(record: dict[str, Any]) -> dict[str, Any]:
    return {
        "name": record["name"],
        "realm": record["realm"],
        "url": record["url"],
        "class": record["class"],
        "race": record.get("race"),
        "active_spec": record["active_spec"],
        "active_spec_label": record.get("active_spec_label"),
        "talent_trees": safe_json_value(record.get("talent_trees")),
        "role": record["role"],
        "item_count": record["item_count"],
        "avg_item_level": record["avg_item_level"],
        "legacy_gs": record["legacy_gs"],
        "gs2_pre_cap": record["gs2_pre_cap"],
        "gs2_cap_bonus": record["gs2_cap_bonus"],
        "gs2_final": record["gs2_final"],
        "pvp_gs": record["pvp_gs"],
        "active_spec_gs2": record["active_spec_gs2"],
        "inferred_spec": record.get("inferred_spec"),
        "inferred_spec_gs2": record.get("inferred_spec_gs2"),
        "inferred_reason": record.get("inferred_reason"),
        "selected_spec": record["selected_spec"],
        "selected_spec_gs2": record["selected_spec_gs2"],
        "selected_spec_source": record["selected_spec_source"],
        "benchmark_quality_tier": record["benchmark_quality_tier"],
        "clean_record_flag": record["clean_record_flag"],
        "outlier_flag": record["outlier_flag"],
        "diagnostic_summary": safe_json_value(record.get("diagnostic_summary")),
        "diagnostics": safe_json_value(record.get("diagnostics")),
        "diagnostic_counts": {
            "informational": record["diagnostic_informational_count"],
            "optimization": record["diagnostic_optimization_count"],
            "compatibility": record["diagnostic_compatibility_count"],
            "blocker": record["diagnostic_blocker_count"],
        },
        "cap_progress": {
            "hit": record.get("cap_hit_progress"),
            "expertise": record.get("cap_expertise_progress"),
            "defense": record.get("cap_defense_progress"),
            "arp": record.get("cap_arp_progress"),
        },
        "red_flag_reason": record.get("red_flag_reason"),
        "cap_breakdown": safe_json_value(record.get("cap_breakdown")),
        "cap_stats": safe_json_value(record.get("cap_stats")),
        "items": safe_json_value(record.get("items")),
        "data_sources": safe_json_value(record.get("data_sources")),
    }


def export_csv(records: list[dict[str, Any]], path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fieldnames = [
        "name", "realm", "class", "active_spec", "role", "item_count", "avg_item_level",
        "legacy_gs", "gs2_pre_cap", "gs2_cap_bonus", "gs2_final", "pvp_gs",
        "active_spec_gs2",
        "inferred_spec", "inferred_spec_gs2", "inferred_reason", "selected_spec", "selected_spec_gs2", "selected_spec_source",
        "global_delta_from_median_pct", "group_delta_from_median_pct",
        "benchmark_quality_tier", "clean_record_flag", "outlier_flag",
        "diagnostic_informational_count", "diagnostic_optimization_count",
        "diagnostic_compatibility_count", "diagnostic_blocker_count",
        "cap_hit_progress", "cap_expertise_progress", "cap_defense_progress",
        "cap_arp_progress", "red_flag_reason",
    ]
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        for record in sorted(records, key=lambda entry: (-entry["gs2_final"], entry["name"])):
            writer.writerow({key: record.get(key, "") for key in fieldnames})


def export_json(records: list[dict[str, Any]], summary: dict[str, Any], dataset_name: str, output_path: Path) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    public_records = [build_public_character_record(record) for record in sorted(records, key=lambda entry: (-entry["gs2_final"], entry["name"]))]
    payload = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "dataset_name": dataset_name,
        "dataset_size": len(records),
        "scoring_version": "gearscore2-benchmark-v5-clean-report",
        "assumptions": [
            "Benchmark records keep both the Warmane active-spec result and the best plausible inferred-spec result, then export the higher snapshot-fit-adjusted GS2 value as the selected benchmark score.",
            "Offline benchmark does not model live aura buffs or target debuffs.",
            "Offline benchmark reproduces compatibility, cap, snapshot-fit, and off-spec comparison logic, but not live inspect transport or timing.",
            "Spec groups with size 1 fall back to role-based comparison.",
            "Shirt and tabard slots are ignored to match addon runtime scoring.",
            "Special enchants are informational unless they block static stat resolution.",
            "CSV is a slim comparison view; JSON keeps item-level audit detail without exporting every internal helper field.",
        ],
        "data_sources": {
            "snapshot": "warmane",
            "item_stats": "wotlkdb",
            "scoring_logic": "lua_runtime_tables",
        },
        "summary": safe_json_value(summary),
        "characters": safe_json_value(public_records),
    }
    output_path.write_text(json.dumps(payload, indent=2, ensure_ascii=True), encoding="utf-8")


def log_progress(message: str) -> None:
    print(message, flush=True)


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="Build a GearScore2 balance benchmark from Warmane armory profiles.")
    parser.add_argument("--dataset", type=Path, default=DEFAULT_DATASET)
    parser.add_argument("--cache-dir", type=Path, default=DEFAULT_CACHE_DIR)
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT_DIR)
    parser.add_argument("--character", help="Only process a single character name from the dataset.")
    parser.add_argument("--refresh", action="store_true", help="Ignore cached HTML and refetch remote pages.")
    parser.add_argument("--delay", type=float, default=0.0, help="Delay between uncached HTTP requests.")
    parser.add_argument(
        "--active-spec-only",
        action="store_true",
        help="Keep the active-spec GS2 as the exported final result even if an inferred/offspec score is higher.",
    )
    args = parser.parse_args(argv)

    dataset_path = args.dataset.resolve()
    if not dataset_path.exists():
        raise SystemExit(f"Dataset not found: {dataset_path}")

    log_progress(f"[init] Loading runtime tables from {REPO_ROOT}")
    tables = load_runtime_tables(REPO_ROOT)
    apply_runtime_constants(tables)
    fetcher = Fetcher(args.cache_dir.resolve(), refresh=args.refresh, delay=args.delay)
    refs = parse_dataset(dataset_path)
    log_progress(f"[init] Loaded {len(refs)} character references from {dataset_path}")
    if args.character:
        refs = [ref for ref in refs if ref.name.lower() == args.character.lower()]
        if not refs:
            raise SystemExit(f"Character not found in dataset: {args.character}")
        log_progress(f"[init] Filtered dataset to character '{args.character}'")
    item_cache: dict[int, dict[str, Any]] = {}
    gem_cache: dict[int, ResolvedGem] = {}

    records = []
    total_refs = len(refs)
    for index, ref in enumerate(refs, start=1):
        log_progress(f"[{index}/{total_refs}] Processing {ref.name} ({ref.realm})")
        profile = parse_warmane_profile(ref, fetcher)
        records.append(
            build_character_record(
                profile,
                fetcher,
                tables,
                item_cache,
                gem_cache,
                prefer_inferred_selection=not args.active_spec_only,
            )
        )

    log_progress(f"[summary] Annotating {len(records)} benchmark records")
    records, summary = annotate_records(records)
    output_dir = args.output_dir.resolve()
    csv_path = output_dir / "gs2_balance_report.csv"
    json_path = output_dir / "gs2_balance_report.json"
    log_progress(f"[write] Writing CSV to {csv_path}")
    export_csv(records, csv_path)
    log_progress(f"[write] Writing JSON to {json_path}")
    export_json(records, summary, dataset_path.stem, json_path)

    print(f"Wrote {csv_path}")
    print(f"Wrote {json_path}")
    print(f"Characters: {len(records)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
