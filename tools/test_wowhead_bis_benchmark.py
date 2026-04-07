import json
import pathlib
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

import benchmark_core
import wowhead_bis_benchmark as wb


REPO_ROOT = pathlib.Path(__file__).resolve().parents[1]
FIXTURES_DIR = REPO_ROOT / "tools" / "test_fixtures" / "wowhead"


class FakeFetcher:
    def __init__(self, payloads: dict[str, str]) -> None:
        self.payloads = payloads

    def fetch_text(self, url: str, cache_key: str) -> str:
        if url not in self.payloads:
            raise KeyError(f"Missing fixture for {url}")
        return self.payloads[url]


def read_fixture(name: str) -> str:
    return (FIXTURES_DIR / name).read_text(encoding="utf-8")


def build_main_guide_html(phase_url: str) -> str:
    return f'<script>WH.Gatherer.addData(100, 8, {{"1000":{{"name":"Phase 2","url":"https:\\/\\/www.wowhead.com\\/wotlk\\/guide\\/classes\\/demo\\/spec\\/pve-phase-2"}},"1001":{{"name":"Phase 1","url":"{phase_url.replace("/", "\\/")}"}}}});</script>'


def build_test_tables() -> dict[str, object]:
    tables = wb.load_runtime_tables(REPO_ROOT)
    wb.apply_runtime_constants(tables)
    return tables


def stub_parse_item_page(item_id: int, slot_id: int, fetcher: object) -> dict[str, object]:
    mapping = {
        10001: {"name": "Arcane Hood", "level": 213, "rarity": 4, "equipLoc": "INVTYPE_HEAD", "stats": {"SP": 80.0, "CRIT": 40.0, "INT": 50.0}, "socketCount": 2, "resilience": 0.0},
        10002: {"name": "Arcane Robe", "level": 213, "rarity": 4, "equipLoc": "INVTYPE_CHEST", "stats": {"SP": 90.0, "HASTE": 42.0, "INT": 52.0}, "socketCount": 2, "resilience": 0.0},
        10003: {"name": "Arcane Ring A", "level": 213, "rarity": 4, "equipLoc": "INVTYPE_FINGER", "stats": {"SP": 60.0, "HIT": 30.0}, "socketCount": 0, "resilience": 0.0},
        10004: {"name": "Arcane Ring B", "level": 213, "rarity": 4, "equipLoc": "INVTYPE_FINGER", "stats": {"SP": 62.0, "CRIT": 28.0}, "socketCount": 0, "resilience": 0.0},
        10005: {"name": "Arcane Trinket A", "level": 213, "rarity": 4, "equipLoc": "INVTYPE_TRINKET", "stats": {"HIT": 40.0}, "socketCount": 0, "resilience": 0.0},
        10006: {"name": "Arcane Trinket B", "level": 200, "rarity": 4, "equipLoc": "INVTYPE_TRINKET", "stats": {"SP": 55.0}, "socketCount": 0, "resilience": 0.0},
        10007: {"name": "Arcane Blade", "level": 213, "rarity": 4, "equipLoc": "INVTYPE_WEAPONMAINHAND", "stats": {"SP": 150.0, "HASTE": 30.0}, "socketCount": 0, "resilience": 0.0},
        10008: {"name": "Arcane Offhand", "level": 213, "rarity": 4, "equipLoc": "INVTYPE_HOLDABLE", "stats": {"SP": 70.0, "CRIT": 20.0}, "socketCount": 0, "resilience": 0.0},
        10009: {"name": "Arcane Wand", "level": 213, "rarity": 4, "equipLoc": "INVTYPE_RANGED", "subType": "WAND", "stats": {"SP": 38.0, "HIT": 18.0}, "socketCount": 0, "resilience": 0.0},
    }
    fallback = {"name": f"Stub Item {item_id}", "level": 213, "rarity": 4, "equipLoc": "INVTYPE_HEAD", "stats": {"SP": 40.0}, "socketCount": 0, "resilience": 0.0}
    base = dict(mapping.get(item_id, fallback))
    base.setdefault("subType", "")
    base.setdefault("socketColors", [])
    base.setdefault("socketBonusStats", {})
    base.setdefault("armorRank", None)
    base["itemId"] = item_id
    return base


class WowheadBisBenchmarkTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.tables = build_test_tables()

    def test_wowhead_uses_shared_benchmark_core_scoring(self) -> None:
        self.assertIs(wb.load_runtime_tables, benchmark_core.load_runtime_tables)
        self.assertIs(wb.get_profile, benchmark_core.get_profile)
        self.assertIs(wb.score_item_with_debug, benchmark_core.score_item_with_debug)
        self.assertIs(wb.apply_character_caps, benchmark_core.apply_character_caps)

    def test_resolve_phase_url_uses_phase_one_link(self) -> None:
        html = build_main_guide_html("https://www.wowhead.com/wotlk/guide/classes/mage/arcane/dps-bis-gear-pve-phase-1")
        phase_url = wb.resolve_phase_url(html, "PHASE_1", {"build_archetype": "MAGE_ARCANE"})
        self.assertTrue(phase_url.endswith("pve-phase-1"))

    def test_arcane_parser_preserves_gems_and_enchants(self) -> None:
        phase_url = "https://www.wowhead.com/wotlk/guide/classes/mage/arcane/dps-bis-gear-pve-phase-1"
        fetcher = FakeFetcher(
            {
                "https://www.wowhead.com/wotlk/guide/arcane-mage-dps-best-in-slot-gear-list": build_main_guide_html(phase_url),
                phase_url: read_fixture("arcane_phase1_fixture.html"),
            }
        )
        phase_guide = wb.load_phase_guide(
            {"url": "https://www.wowhead.com/wotlk/guide/arcane-mage-dps-best-in-slot-gear-list", "build_archetype": "MAGE_ARCANE"},
            "PHASE_1",
            fetcher,
        )
        entries_by_slot = {entry["slotId"]: entry for entry in phase_guide["entries"]}
        self.assertEqual(phase_guide["planner"]["tabLabel"], "Gloves as Off-Piece")
        self.assertEqual(phase_guide["planner"]["selectionPolicy"], "validated-first")
        self.assertEqual(entries_by_slot[1]["gemItemIds"], [20001, 20002])
        self.assertEqual(entries_by_slot[1]["plannerEnchantId"], 30002)
        self.assertEqual(entries_by_slot[16]["plannerEnchantId"], 40002)
        self.assertEqual([entry["slotId"] for entry in phase_guide["entries"] if entry["slotId"] in {11, 12}], [11, 12])

    def test_holy_paladin_parser_maps_shield_and_libram_slots(self) -> None:
        phase_url = "https://www.wowhead.com/wotlk/guide/classes/paladin/holy/healer-bis-gear-pve-phase-1"
        fetcher = FakeFetcher(
            {
                "https://www.wowhead.com/wotlk/guide/holy-paladin-healer-best-in-slot-gear-list": build_main_guide_html(phase_url),
                phase_url: read_fixture("holy_paladin_phase1_fixture.html"),
            }
        )
        phase_guide = wb.load_phase_guide(
            {"url": "https://www.wowhead.com/wotlk/guide/holy-paladin-healer-best-in-slot-gear-list", "build_archetype": "PALADIN_HOLY"},
            "PHASE_1",
            fetcher,
        )
        parsed_slots = sorted(entry["slotId"] for entry in phase_guide["entries"])
        self.assertIn(16, parsed_slots)
        self.assertIn(17, parsed_slots)
        self.assertIn(18, parsed_slots)

    def test_rogue_parser_supports_icon_socket_urls_and_dual_weapons(self) -> None:
        phase_url = "https://www.wowhead.com/wotlk/guide/classes/rogue/combat/dps-bis-gear-pve-phase-1"
        fetcher = FakeFetcher(
            {
                "https://www.wowhead.com/wotlk/guide/combat-rogue-dps-best-in-slot-gear-list": build_main_guide_html(phase_url),
                phase_url: read_fixture("combat_rogue_phase1_fixture.html"),
            }
        )
        phase_guide = wb.load_phase_guide(
            {"url": "https://www.wowhead.com/wotlk/guide/combat-rogue-dps-best-in-slot-gear-list", "build_archetype": "ROGUE_COMBAT"},
            "PHASE_1",
            fetcher,
        )
        entries_by_slot = {entry["slotId"]: entry for entry in phase_guide["entries"]}
        self.assertEqual(entries_by_slot[1]["gemItemIds"], [71001, 71002])
        self.assertEqual(entries_by_slot[16]["itemId"], 70003)
        self.assertEqual(entries_by_slot[17]["itemId"], 70004)
        self.assertEqual(entries_by_slot[18]["itemId"], 70005)

    def test_arms_warrior_parser_uses_first_planner_build_for_all_16_slots(self) -> None:
        phase_url = "https://www.wowhead.com/wotlk/guide/classes/warrior/arms/dps-bis-gear-pve-phase-1"
        fetcher = FakeFetcher(
            {
                "https://www.wowhead.com/wotlk/guide/arms-warrior-dps-best-in-slot-gear-list": build_main_guide_html(phase_url),
                phase_url: read_fixture("arms_warrior_phase1_fixture.html"),
            }
        )
        phase_guide = wb.load_phase_guide(
            {"url": "https://www.wowhead.com/wotlk/guide/arms-warrior-dps-best-in-slot-gear-list", "build_archetype": "WARRIOR_ARMS"},
            "PHASE_1",
            fetcher,
        )
        self.assertEqual(phase_guide["planner"]["tabLabel"], "P1 Raid BiS Alliance")
        self.assertEqual(len(phase_guide["entries"]), 16)
        entries_by_slot = {entry["slotId"]: entry for entry in phase_guide["entries"]}
        self.assertEqual(entries_by_slot[16]["itemId"], 40384)
        self.assertEqual(entries_by_slot[18]["itemId"], 40385)

    def test_planner_selection_rejects_low_ilvl_candidate_for_late_phase(self) -> None:
        markup = (
            '[tab name="Classic"]'
            "[gear-planner=druid/night-elf/AAA][/tab]"
            '[tab name="P3 BiS"]'
            "[gear-planner=druid/night-elf/BBB][/tab]"
        )
        planners, diagnostics = wb.extract_planner_builds(markup)
        self.assertFalse(diagnostics)

        def planner_stub(item_id: int, slot_id: int, fetcher: object) -> dict[str, object]:
            level = 80 if item_id == 20001 else 245
            return {
                "itemId": item_id,
                "name": f"Item {item_id}",
                "level": level,
                "rarity": 4,
                "equipLoc": "INVTYPE_HEAD",
                "stats": {"SP": 50.0},
                "socketCount": 0,
                "resilience": 0.0,
                "subType": "",
                "socketColors": [],
                "socketBonusStats": {},
                "armorRank": None,
            }

        with patch.object(wb, "build_entries_from_planner") as build_entries, patch.object(wb, "parse_item_page", side_effect=planner_stub):
            build_entries.side_effect = [
                ([{"slotId": 1, "itemId": 20001, "slotTitle": "Head", "gemItemIds": [], "gemSockets": {}, "plannerEnchantId": 0, "plannerRandomEnchantId": 0, "rowLabel": "Classic"}], []),
                ([{"slotId": 1, "itemId": 20002, "slotTitle": "Head", "gemItemIds": [], "gemSockets": {}, "plannerEnchantId": 0, "plannerRandomEnchantId": 0, "rowLabel": "P3 BiS"}], []),
            ]
            selected, candidates, selection_diagnostics = wb.select_planner_candidate(planners, "PHASE_3", FakeFetcher({}), {})
        self.assertFalse(selection_diagnostics)
        self.assertEqual(selected["planner"]["tabLabel"], "P3 BiS")
        self.assertEqual(candidates[0]["validation_status"], "rejected")
        self.assertTrue(any("below-phase_3-floor" in reason for reason in candidates[0]["rejection_reasons"]))

    def test_manifest_override_planner_is_preferred_for_phase(self) -> None:
        phase_url = "https://www.wowhead.com/wotlk/guide/classes/druid/balance/dps-bis-gear-pve-phase-3"
        fetcher = FakeFetcher(
            {
                "https://www.wowhead.com/wotlk/guide/balance-druid-dps-best-in-slot-gear-list": build_main_guide_html(phase_url),
                phase_url: '<script>WH.markup.printHtml("[tab name=\\"Broken\\"][gear-planner=druid/night-elf/AAA][/tab]", "guide-body", {});</script>',
            }
        )
        phase_guide = wb.load_phase_guide(
            {
                "url": "https://www.wowhead.com/wotlk/guide/balance-druid-dps-best-in-slot-gear-list",
                "build_archetype": "DRUID_BALANCE",
                "planner_overrides": {"PHASE_3": "druid/night-elf/BBB"},
            },
            "PHASE_3",
            fetcher,
        )
        self.assertEqual(phase_guide["plannerCandidates"][0]["path"], "druid/night-elf/BBB")
        self.assertEqual(phase_guide["plannerCandidates"][0]["selectionPolicy"], "manifest-override")

    def test_match_spec_filter_accepts_canonical_class_specific_protection_key(self) -> None:
        guide = {
            "class": "PALADIN",
            "build_archetype": "PROTECTION",
        }
        self.assertTrue(wb.match_spec_filter(guide, "PALADIN:PROTECTION"))
        self.assertTrue(wb.match_spec_filter(guide, "PALADIN_PROTECTION"))
        self.assertFalse(wb.match_spec_filter(guide, "WARRIOR_PROTECTION"))

    def test_invalid_planner_path_is_rejected_without_crashing_selection(self) -> None:
        selected, candidates, diagnostics = wb.select_planner_candidate(
            [{"path": "paladin/", "url": "https://www.wowhead.com/wotlk/gear-planner/paladin/", "tabLabel": None, "selectionPolicy": "validated-first"}],
            "PHASE_2",
            FakeFetcher({}),
            {},
        )
        self.assertEqual(selected["validation_status"], "rejected")
        self.assertTrue(any(reason.startswith("planner-decode-error:") for reason in candidates[0]["rejection_reasons"]))
        self.assertIn("planner-selection-fell-back-to-rejected-candidate", diagnostics)

    def test_shadow_priest_phase_two_ignores_tabard_and_body_for_ilvl_floor_validation(self) -> None:
        phase_url = "https://www.wowhead.com/wotlk/guide/classes/priest/shadow/dps-bis-gear-pve-phase-2"
        fetcher = FakeFetcher(
            {
                "https://www.wowhead.com/wotlk/guide/shadow-priest-dps-best-in-slot-gear-list": f'<script>WH.Gatherer.addData(100, 8, {{"1000":{{"name":"Phase 2","url":"{phase_url.replace("/", "\\/")}"}}}});</script>',
                phase_url: read_fixture("shadow_priest_phase2_fixture.html"),
            }
        )
        guide = {
            "class": "PRIEST",
            "build_archetype": "SHADOW",
            "role": "CASTER",
            "url": "https://www.wowhead.com/wotlk/guide/shadow-priest-dps-best-in-slot-gear-list",
        }
        priest_phase_two_items = {
            46172: ("Conqueror's Circlet of Sanctification", 226, "INVTYPE_HEAD"),
            45243: ("Sapphire Amulet of Renewal", 239, "INVTYPE_NECK"),
            46165: ("Conqueror's Mantle of Sanctification", 226, "INVTYPE_SHOULDER"),
            44693: ("Wound Dressing", 1, "INVTYPE_BODY"),
            46168: ("Conqueror's Raiments of Sanctification", 226, "INVTYPE_CHEST"),
            45619: ("Starwatcher's Binding", 239, "INVTYPE_WAIST"),
            46170: ("Conqueror's Pants of Sanctification", 226, "INVTYPE_LEGS"),
            45135: ("Boots of Fiery Resolution", 239, "INVTYPE_FEET"),
            45446: ("Grasps of Reason", 239, "INVTYPE_WRIST"),
            45665: ("Pharos Gloves", 239, "INVTYPE_HAND"),
            46046: ("Nebula Band", 226, "INVTYPE_FINGER"),
            45495: ("Conductive Seal", 239, "INVTYPE_FINGER"),
            45518: ("Flare of the Heavens", 239, "INVTYPE_TRINKET"),
            45466: ("Scale of Fates", 226, "INVTYPE_TRINKET"),
            45242: ("Drape of Mortal Downfall", 239, "INVTYPE_CLOAK"),
            45620: ("Starshard Edge", 239, "INVTYPE_WEAPONMAINHAND"),
            45617: ("Cosmos", 239, "INVTYPE_HOLDABLE"),
            45294: ("Petrified Ivy Sprig", 232, "INVTYPE_RANGED"),
            23192: ("Tabard of the Scarlet Crusade", 1, "INVTYPE_TABARD"),
        }

        def priest_phase_two_stub(item_id: int, slot_id: int, fetcher: object) -> dict[str, object]:
            name, level, equip_loc = priest_phase_two_items[item_id]
            return {
                "itemId": item_id,
                "name": name,
                "level": level,
                "rarity": 4,
                "equipLoc": equip_loc,
                "stats": {"SP": 50.0},
                "socketCount": 0,
                "resilience": 0.0,
                "subType": "WAND" if equip_loc == "INVTYPE_RANGED" else "",
                "socketColors": [],
                "socketBonusStats": {},
                "armorRank": None,
            }

        def priest_phase_two_enchant_stub(
            entry: dict[str, object],
            items_data: dict[str, object],
            spells_data: dict[str, object],
            fetcher: object,
            spell_cache: dict[int, dict[str, object]],
        ) -> tuple[dict[str, object] | None, list[dict[str, object]]]:
            enchant_id = int(entry.get("plannerEnchantId", 0) or 0)
            if not enchant_id:
                return None, []
            resolved = {
                "kind": "special",
                "label": f"ENCHANT_{enchant_id}",
                "stats": {"SP": 1.0},
                "sourceType": "spell",
                "sourceId": enchant_id,
                "extraSocketCount": 0,
            }
            return resolved, [resolved]

        with patch.object(wb, "parse_item_page", side_effect=priest_phase_two_stub), patch.object(wb, "choose_enchant_for_entry", side_effect=priest_phase_two_enchant_stub):
            record = wb.build_spec_record(guide, "PHASE_2", fetcher, self.tables, {})
        self.assertNotEqual(record["parse_status"], "failed")
        self.assertEqual(record["planner_validation_status"], "accepted")
        self.assertAlmostEqual(record["avg_item_level"], 234.0)

    def test_smoke_single_spec_run_writes_outputs(self) -> None:
        arcane_main_url = "https://www.wowhead.com/wotlk/guide/arcane-mage-dps-best-in-slot-gear-list"
        arcane_phase_url = "https://www.wowhead.com/wotlk/guide/classes/mage/arcane/dps-bis-gear-pve-phase-1"
        manifest = {
            "phases": ["PHASE_1"],
            "guides": [
                {
                    "class": "MAGE",
                    "build_archetype": "MAGE_ARCANE",
                    "role": "CASTER",
                    "url": arcane_main_url,
                }
            ],
        }
        payloads = {
            arcane_main_url: build_main_guide_html(arcane_phase_url),
            arcane_phase_url: read_fixture("arcane_phase1_fixture.html"),
        }

        class LocalFetcher(FakeFetcher):
            def __init__(self, cache_dir: pathlib.Path | None = None, refresh: bool = False, delay: float = 0.0) -> None:
                super().__init__(payloads)

        with tempfile.TemporaryDirectory() as temp_dir, patch.object(wb, "Fetcher", LocalFetcher), patch.object(wb, "parse_item_page", side_effect=stub_parse_item_page):
            manifest_path = pathlib.Path(temp_dir) / "manifest.json"
            output_dir = pathlib.Path(temp_dir) / "output"
            manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
            records, summary, outputs = wb.run_benchmark(
                manifest_path=manifest_path,
                output_dir=output_dir,
                cache_dir=pathlib.Path(temp_dir) / "cache",
                phase="PHASE_1",
                spec_filter="MAGE_ARCANE",
                refresh=False,
                delay=0.0,
            )
            self.assertEqual(len(records), 1)
            self.assertEqual(records[0]["parse_status"], "complete")
            self.assertGreater(records[0]["gs2_final"], 0)
            self.assertGreaterEqual(records[0]["gs2_cap_bonus"], 0)
            self.assertIn("/gear-planner/", records[0]["planner_url"])
            self.assertEqual(records[0]["planner_selection_policy"], "validated-first")
            self.assertEqual(records[0]["planner_validation_status"], "accepted")
            self.assertEqual(records[0]["rejected_slot_count"], 0)
            self.assertTrue(outputs[0].exists())
            self.assertTrue(outputs[1].exists())
            self.assertEqual(outputs[0].name, "wowhead_bis_phase_1_benchmark.csv")
            self.assertEqual(outputs[1].name, "wowhead_bis_phase_1_benchmark.json")
            payload = json.loads(outputs[1].read_text(encoding="utf-8"))
            public_record = payload["records"][0]
            self.assertIn("planner_validation_status", public_record)
            self.assertIn("delta_from_legacy", public_record)
            self.assertIn("pve_bonus_bucket_effective", public_record)
            self.assertNotIn("planner_candidates", public_record)
            self.assertNotIn("profile_summary", public_record)
            self.assertEqual(summary["spec_count_processed"], 1)

    def test_phase_all_runs_multiple_phases_into_single_report(self) -> None:
        arcane_main_url = "https://www.wowhead.com/wotlk/guide/arcane-mage-dps-best-in-slot-gear-list"
        phase_1_url = "https://www.wowhead.com/wotlk/guide/classes/mage/arcane/dps-bis-gear-pve-phase-1"
        phase_2_url = "https://www.wowhead.com/wotlk/guide/classes/mage/arcane/dps-bis-gear-pve-phase-2"
        manifest = {
            "phases": ["PHASE_1", "PHASE_2"],
            "guides": [
                {
                    "class": "MAGE",
                    "build_archetype": "MAGE_ARCANE",
                    "role": "CASTER",
                    "url": arcane_main_url,
                    "phase_urls": {
                        "PHASE_1": phase_1_url,
                        "PHASE_2": phase_2_url,
                    },
                }
            ],
        }
        payloads = {
            arcane_main_url: build_main_guide_html(phase_1_url),
            phase_1_url: read_fixture("arcane_phase1_fixture.html"),
            phase_2_url: read_fixture("arcane_phase1_fixture.html"),
        }

        class LocalFetcher(FakeFetcher):
            def __init__(self, cache_dir: pathlib.Path | None = None, refresh: bool = False, delay: float = 0.0) -> None:
                super().__init__(payloads)

        with tempfile.TemporaryDirectory() as temp_dir, patch.object(wb, "Fetcher", LocalFetcher), patch.object(wb, "parse_item_page", side_effect=stub_parse_item_page):
            manifest_path = pathlib.Path(temp_dir) / "manifest.json"
            output_dir = pathlib.Path(temp_dir) / "output"
            manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
            records, summary, outputs = wb.run_benchmark(
                manifest_path=manifest_path,
                output_dir=output_dir,
                cache_dir=pathlib.Path(temp_dir) / "cache",
                phase="ALL",
                spec_filter="MAGE_ARCANE",
                refresh=False,
                delay=0.0,
            )
            self.assertEqual(len(records), 2)
            self.assertEqual({record["phase"] for record in records}, {"PHASE_1", "PHASE_2"})
            self.assertEqual(summary["phase_counts"]["PHASE_1"], 1)
            self.assertEqual(summary["phase_counts"]["PHASE_2"], 1)
            self.assertIn("phase_summary", summary)
            self.assertIn("spec_phase_trends", summary)
            self.assertIn("class_phase_trends", summary)
            self.assertIn("largest_phase_drifts", summary)
            self.assertIn("median_target_delta", summary)
            self.assertIn("largest_target_delta_errors", summary)
            self.assertIn("phase_4_target_outliers", summary)
            self.assertIn("median_delta_from_legacy", summary["phase_summary"]["PHASE_1"])
            self.assertIn("median_delta_error", summary["phase_summary"]["PHASE_1"])
            self.assertEqual(
                summary["phase_summary"]["PHASE_1"]["spread_gap_to_target"],
                summary["phase_summary"]["PHASE_1"]["spread_gs2_final"] - 300,
            )
            self.assertTrue(outputs[0].name.endswith("wowhead_bis_all_phases_benchmark.csv"))
            self.assertTrue(outputs[1].name.endswith("wowhead_bis_all_phases_benchmark.json"))


if __name__ == "__main__":
    unittest.main()
