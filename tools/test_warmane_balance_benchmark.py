import copy
import pathlib
import sys
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

import benchmark_core
from warmane_balance_benchmark import (
    DEFAULT_CACHE_DIR,
    Fetcher,
    WarmaneCharacterRef,
    annotate_records,
    build_character_record,
    get_class_spec_candidates,
    get_profile,
    get_role_signature_kind,
    get_snapshot_spec_diagnostics,
    is_item_compatible,
    is_plausible_offspec_candidate,
    load_runtime_tables,
    normalize_spec_name,
    parse_dataset,
    parse_item_page,
    parse_warmane_profile,
    resolve_spec_key,
    score_item_with_debug,
)
from unittest.mock import patch


REPO_ROOT = pathlib.Path(__file__).resolve().parents[1]


class WarmaneBalanceBenchmarkTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.tables = load_runtime_tables(REPO_ROOT)
        cls.fetcher = Fetcher(DEFAULT_CACHE_DIR)

    def test_runtime_tables_include_spec_profiles(self) -> None:
        self.assertIn("SpecProfiles", self.tables["Tables"])
        self.assertIn("ROGUE_ASSASSINATION", self.tables["Tables"]["SpecProfiles"])
        self.assertEqual(self.tables["Tables"]["SpecProfiles"]["ROGUE_ASSASSINATION"]["role"], "MELEE")
        self.assertIn("PRIEST_HOLY", self.tables["Tables"]["SpecProfiles"])
        self.assertIn("DRUID_FERAL_DPS", self.tables["Tables"]["SpecProfiles"])
        self.assertIn("DRUID_FERAL_TANK", self.tables["Tables"]["SpecProfiles"])

    def test_warmane_wrapper_reexports_benchmark_core_scoring_functions(self) -> None:
        self.assertIs(load_runtime_tables, benchmark_core.load_runtime_tables)
        self.assertIs(get_profile, benchmark_core.get_profile)
        self.assertIs(score_item_with_debug, benchmark_core.score_item_with_debug)

    def test_item_resolution_uses_wotlkdb_item_data(self) -> None:
        item = parse_item_page(40502, 0, self.fetcher)
        self.assertEqual(item["name"], "Valorous Bonescythe Pauldrons")
        self.assertEqual(item["equipLoc"], "INVTYPE_SHOULDER")
        self.assertEqual(item["stats"]["CRIT"], 58.0)
        self.assertEqual(item["stats"]["HASTE"], 43.0)

    def test_item_resolution_captures_generic_spell_power_lines(self) -> None:
        item = parse_item_page(39423, 16, self.fetcher)
        self.assertEqual(item["name"], "Hammer of the Astral Plane")
        self.assertEqual(item["stats"]["SP"], 461.0)

    def test_staff_resolution_uses_inventory_slot_for_two_hand_weapon(self) -> None:
        item = parse_item_page(40455, 16, self.fetcher)
        self.assertEqual(item["name"], "Staff of Restraint")
        self.assertEqual(item["equipLoc"], "INVTYPE_2HWEAPON")

    def test_mizianolas_record_contains_debug_breakdown(self) -> None:
        ref = WarmaneCharacterRef(
            "https://armory.warmane.com/character/Mizianolas/Onyxia/profile",
            "Mizianolas",
            "Onyxia",
        )
        profile = parse_warmane_profile(ref, self.fetcher)
        record = build_character_record(profile, self.fetcher, self.tables, {}, {})
        self.assertEqual(record["legacy_gs"], 3772)
        self.assertEqual(record["gs2_final"], 4674)
        self.assertEqual(record["active_spec"], "ROGUE_ASSASSINATION")
        self.assertEqual(record["requested_spec_gs2"], 4604)
        self.assertEqual(record["inferred_spec"], "ROGUE_SUBTLETY")
        self.assertEqual(record["inferred_spec_gs2"], 4674)
        self.assertEqual(record["selected_spec"], "ROGUE_SUBTLETY")
        self.assertEqual(record["selected_spec_source"], "inferred")
        self.assertEqual(record["data_sources"]["item_stats"], "wotlkdb")
        self.assertIn("score_breakdown", record["items"][0])
        self.assertIn("talent_trees", record)

    def test_dataset_parsing_finds_urls(self) -> None:
        dataset = parse_dataset(REPO_ROOT / "tools" / "data" / "warmane_onyxia_top_chars.txt")
        self.assertGreaterEqual(len(dataset), 1)
        self.assertEqual(dataset[0].realm, "Onyxia")

    def test_warmane_profile_slot_grid_preserves_empty_slots(self) -> None:
        ref = WarmaneCharacterRef(
            "https://armory.warmane.com/character/Gadxpofewqxx/Onyxia/profile",
            "Gadxpofewqxx",
            "Onyxia",
        )
        profile = parse_warmane_profile(ref, self.fetcher)
        by_slot = {entry["inventorySlot"]: entry["itemId"] for entry in profile["items"]}
        self.assertEqual(by_slot[1], 40467)
        self.assertEqual(by_slot[16], 40455)
        self.assertEqual(by_slot[18], 40321)
        self.assertNotIn(4, by_slot)
        self.assertNotIn(17, by_slot)

    def test_role_signature_and_compatibility_follow_runtime_rules(self) -> None:
        tank_item = {
            "slot": 16,
            "equipLoc": "INVTYPE_SHIELD",
            "stats": {"DEFENSE": 40.0, "BLOCK": 20.0},
        }
        caster_item = {
            "slot": 16,
            "equipLoc": "INVTYPE_WEAPONMAINHAND",
            "stats": {"SP": 60.0, "INT": 20.0},
        }
        self.assertEqual(get_role_signature_kind(tank_item), "TANK")
        self.assertEqual(get_role_signature_kind(caster_item), "CASTER")
        protection = self.tables["Tables"]["SpecProfiles"]["PALADIN_PROTECTION"]
        holy = self.tables["Tables"]["SpecProfiles"]["PALADIN_HOLY"]
        self.assertTrue(is_item_compatible(tank_item, "PALADIN", protection))
        self.assertFalse(is_item_compatible(caster_item, "PALADIN", protection))
        self.assertTrue(is_item_compatible(tank_item, "PALADIN", holy))

    def test_relic_compatibility_accepts_plural_relic_subtypes(self) -> None:
        relic_item = {
            "slot": 18,
            "equipLoc": "INVTYPE_RELIC",
            "subType": "IDOLS",
            "stats": {},
        }
        balance = self.tables["Tables"]["SpecProfiles"]["DRUID_BALANCE"]
        self.assertTrue(is_item_compatible(relic_item, "DRUID", balance))

    def test_class_specific_profiles_are_distinct_canonical_profiles(self) -> None:
        warrior_protection, warrior_resolved = get_profile("WARRIOR", "WARRIOR_PROTECTION", self.tables)
        paladin_protection, paladin_resolved = get_profile("PALADIN", "PALADIN_PROTECTION", self.tables)
        self.assertEqual(warrior_resolved, "WARRIOR_PROTECTION")
        self.assertEqual(paladin_resolved, "PALADIN_PROTECTION")
        self.assertAlmostEqual(warrior_protection["pve"]["DEFENSE"], 2.8, places=3)
        self.assertAlmostEqual(paladin_protection["pve"]["DEFENSE"], 2.8, places=3)
        self.assertAlmostEqual(warrior_protection["gs2Scale"], 1.211, places=3)
        self.assertAlmostEqual(paladin_protection["gs2Scale"], 1.162, places=3)

    def test_class_specific_compatibility_overrides_allow_planner_bis_exceptions(self) -> None:
        lower_armor_item = {
            "slot": 5,
            "equipLoc": "INVTYPE_CHEST",
            "armorRank": 2,
            "stats": {"STR": 70.0, "CRIT": 48.0, "HIT": 32.0},
        }
        spellhance_item = {
            "slot": 16,
            "equipLoc": "INVTYPE_WEAPONMAINHAND",
            "stats": {"SP": 457.0, "HASTE": 49.0, "HIT": 32.0, "INT": 33.0},
        }
        unholy_offhand = {
            "slot": 17,
            "equipLoc": "INVTYPE_WEAPONOFFHAND",
            "stats": {"STR": 44.0, "CRIT": 36.0, "HASTE": 28.0},
        }
        arms_profile, _ = get_profile("WARRIOR", "WARRIOR_ARMS", self.tables)
        enhancement_profile, _ = get_profile("SHAMAN", "SHAMAN_ENHANCEMENT", self.tables)
        unholy_profile, _ = get_profile("DEATHKNIGHT", "DEATHKNIGHT_UNHOLY", self.tables)
        paladin_retribution, _ = get_profile("PALADIN", "PALADIN_RETRIBUTION", self.tables)
        self.assertTrue(is_item_compatible(lower_armor_item, "WARRIOR", arms_profile))
        self.assertTrue(is_item_compatible(lower_armor_item, "PALADIN", paladin_retribution))
        self.assertTrue(is_item_compatible(spellhance_item, "SHAMAN", enhancement_profile))
        self.assertTrue(is_item_compatible(unholy_offhand, "DEATHKNIGHT", unholy_profile))

    def test_planner_aligned_off_armor_profiles_accept_lower_armor_bis_items(self) -> None:
        hunter_mail_profile, _ = get_profile("HUNTER", "HUNTER_MARKSMANSHIP", self.tables)
        paladin_holy_profile, _ = get_profile("PALADIN", "PALADIN_HOLY", self.tables)
        shaman_resto_profile, _ = get_profile("SHAMAN", "SHAMAN_RESTORATION", self.tables)

        leather_physical = {
            "slot": 5,
            "equipLoc": "INVTYPE_CHEST",
            "armorRank": 2,
            "stats": {"AGI": 80.0, "CRIT": 52.0, "ARP": 40.0},
        }
        cloth_healer = {
            "slot": 9,
            "equipLoc": "INVTYPE_WRIST",
            "armorRank": 1,
            "stats": {"INT": 48.0, "SP": 70.0, "HASTE": 34.0},
        }
        self.assertTrue(is_item_compatible(leather_physical, "HUNTER", hunter_mail_profile))
        self.assertTrue(is_item_compatible(cloth_healer, "PALADIN", paladin_holy_profile))
        self.assertTrue(is_item_compatible(cloth_healer, "SHAMAN", shaman_resto_profile))

    def test_gs2_scale_changes_only_pve_bonus_bucket(self) -> None:
        item = {
            "legacyBase": 100,
            "slot": 5,
            "equipLoc": "INVTYPE_CHEST",
            "stats": {"SP": 80.0, "HASTE": 30.0, "INT": 20.0},
            "gemStats": [],
            "enchantInfo": None,
            "hasEnchant": False,
            "resilience": 0.0,
            "armorRank": 1,
        }
        baseline_tables = copy.deepcopy(self.tables)
        scaled_tables = copy.deepcopy(self.tables)
        baseline_tables["Tables"]["SpecProfiles"]["MAGE_ARCANE"]["gs2Scale"] = 1.0
        scaled_tables["Tables"]["SpecProfiles"]["MAGE_ARCANE"]["gs2Scale"] = 2.0

        base_pve, base_pvp, _flags, base_debug = score_item_with_debug(item, "MAGE", "MAGE_ARCANE", baseline_tables)
        scaled_pve, scaled_pvp, _flags, scaled_debug = score_item_with_debug(item, "MAGE", "MAGE_ARCANE", scaled_tables)

        self.assertEqual(base_debug["legacy_base"], scaled_debug["legacy_base"])
        self.assertEqual(base_pvp, scaled_pvp)
        self.assertEqual(base_debug["bonus_bucket_pve"], scaled_debug["bonus_bucket_pve"])
        self.assertEqual(base_debug["bonus_bucket_pve_scaled"], base_debug["bonus_bucket_pve"])
        self.assertEqual(scaled_debug["bonus_bucket_pve_scaled"], base_debug["bonus_bucket_pve"] * 2)
        self.assertGreater(scaled_pve, base_pve)

    def test_incompatible_items_keep_legacy_base_but_get_penalized_gs2_bonus(self) -> None:
        item = {
            "legacyBase": 100,
            "slot": 5,
            "equipLoc": "INVTYPE_CHEST",
            "armorRank": 1,
            "stats": {"SP": 80.0, "HASTE": 30.0, "INT": 20.0},
            "gemStats": [],
            "enchantInfo": None,
            "hasEnchant": False,
            "resilience": 0.0,
        }
        compatible_pve, compatible_pvp, _flags, compatible_debug = score_item_with_debug(item, "MAGE", "MAGE_ARCANE", self.tables)
        incompatible_pve, incompatible_pvp, incompatible_flags, incompatible_debug = score_item_with_debug(item, "PALADIN", "PALADIN_RETRIBUTION", self.tables)
        self.assertGreater(incompatible_pve, 0)
        self.assertLess(incompatible_pve, compatible_pve)
        self.assertGreaterEqual(incompatible_pvp, incompatible_debug["legacy_base"])
        self.assertLessEqual(incompatible_pvp, compatible_pvp)
        self.assertIn("incompatible-item", incompatible_flags)
        self.assertFalse(incompatible_debug["compatible"])
        self.assertEqual(incompatible_debug["legacy_base"], compatible_debug["legacy_base"])

    def test_character_record_selects_higher_inferred_result_for_benchmark(self) -> None:
        ref = WarmaneCharacterRef(
            "https://armory.warmane.com/character/Mizianolas/Onyxia/profile",
            "Mizianolas",
            "Onyxia",
        )
        profile = parse_warmane_profile(ref, self.fetcher)
        inferred_diagnostics = {
            "spec_key": "ROGUE_COMBAT",
            "role": "MELEE",
            "item_count": 16,
            "compatible_items": 14,
            "matched_items": 12,
            "signature_items": 10,
            "legacy_total": 3772,
            "total_before_caps": 4980,
            "cap_bonus": 20,
            "total": 5000,
            "positive_slots": ["1", "3", "5"],
            "signature_slots": ["1", "3", "5"],
        }
        with patch.object(benchmark_core, "get_best_snapshot_spec", return_value=("ROGUE_COMBAT", 5000, inferred_diagnostics)):
            record = build_character_record(profile, self.fetcher, self.tables, {}, {})
        self.assertEqual(record["requested_spec"], "ROGUE_ASSASSINATION")
        self.assertEqual(record["inferred_spec"], "ROGUE_COMBAT")
        self.assertEqual(record["inferred_spec_gs2"], 5000)
        self.assertEqual(record["selected_spec"], "ROGUE_COMBAT")
        self.assertEqual(record["selected_spec_gs2"], 5000)
        self.assertEqual(record["selected_spec_source"], "inferred")
        self.assertEqual(record["gs2_final"], 5000)
        self.assertEqual(record["inferred_reason"], "weight overlap")

    def test_balance_summary_reports_raw_and_clean_delta_metrics(self) -> None:
        records = [
            {
                "name": "A",
                "realm": "Onyxia",
                "class": "DEATHKNIGHT",
                "active_spec": "DEATHKNIGHT_FROST",
                "role": "MELEE",
                "avg_item_level": 220,
                "item_count": 16,
                "legacy_gs": 4200,
                "gs2_pre_cap": 5800,
                "gs2_cap_bonus": 10,
                "gs2_final": 5810,
                "diagnostics": [],
                "cap_breakdown": {"pools": []},
            },
            {
                "name": "B",
                "realm": "Onyxia",
                "class": "DEATHKNIGHT",
                "active_spec": "DEATHKNIGHT_FROST",
                "role": "MELEE",
                "avg_item_level": 219,
                "item_count": 16,
                "legacy_gs": 4180,
                "gs2_pre_cap": 5750,
                "gs2_cap_bonus": 10,
                "gs2_final": 5760,
                "diagnostics": [],
                "cap_breakdown": {"pools": []},
            },
            {
                "name": "C",
                "realm": "Onyxia",
                "class": "MAGE",
                "active_spec": "MAGE_ARCANE",
                "role": "CASTER",
                "avg_item_level": 218,
                "item_count": 16,
                "legacy_gs": 4200,
                "gs2_pre_cap": 5000,
                "gs2_cap_bonus": 0,
                "gs2_final": 5000,
                "diagnostics": [],
                "cap_breakdown": {"pools": []},
            },
        ]
        _records, summary = annotate_records(records)
        all_records = summary["balance_views"]["all_records"]
        self.assertEqual(all_records["legacy_spread"], 20)
        self.assertEqual(all_records["gs2_spread"], 810)
        self.assertEqual(all_records["delta_spread"], 810)
        self.assertIn("top_positive_spec_deltas", all_records)
        self.assertEqual(all_records["top_positive_spec_deltas"][0]["spec"], "DEATHKNIGHT_FROST")

    def test_offspec_plausibility_requires_signature_support(self) -> None:
        items = [
            {
                "slotId": index + 1,
                "slot": 5,
                "equipLoc": "INVTYPE_CHEST",
                "subType": "Mace",
                "armorRank": 4,
                "stats": {"STR": 40.0, "CRIT": 20.0},
                "gemStats": [],
                "enchantInfo": {},
                "legacyBase": 100,
            }
            for index in range(8)
        ]
        diagnostics = get_snapshot_spec_diagnostics(items, "PALADIN", "PALADIN_PROTECTION", self.tables)
        plausible, reason = is_plausible_offspec_candidate(items, diagnostics)
        self.assertFalse(plausible)
        self.assertEqual(reason, "insufficient role signature")

    def test_character_record_exposes_offspec_audit_fields(self) -> None:
        ref = WarmaneCharacterRef(
            "https://armory.warmane.com/character/Mizianolas/Onyxia/profile",
            "Mizianolas",
            "Onyxia",
        )
        profile = parse_warmane_profile(ref, self.fetcher)
        record = build_character_record(profile, self.fetcher, self.tables, {}, {})
        self.assertIn("active_spec_gs2", record)
        self.assertIn("requested_spec", record)
        self.assertIn("requested_spec_gs2", record)
        self.assertIn("inferred_spec", record)
        self.assertIn("inferred_spec_gs2", record)
        self.assertIn("selected_spec", record)
        self.assertIn("selected_spec_gs2", record)
        self.assertIn("selected_spec_source", record)
        self.assertIn("best_alternate_spec", record)
        self.assertIn("best_alternate_spec_gs2", record)
        self.assertIn("best_alternate_delta_pct", record)
        self.assertIn("off_spec_flag", record)
        self.assertIn("off_spec_reason", record)
        self.assertIn("off_spec_diagnostics", record)

    def test_normalize_spec_name_supports_priest_holy_and_feral_tree(self) -> None:
        self.assertEqual(normalize_spec_name("Holy", "PRIEST"), "PRIEST_HOLY")
        self.assertEqual(normalize_spec_name("Protection", "PALADIN"), "PALADIN_PROTECTION")
        self.assertEqual(normalize_spec_name("Beast Mastery", "HUNTER"), "HUNTER_BEASTMASTERY")
        self.assertEqual(normalize_spec_name("Feral Combat", "DRUID"), "FERAL")

    def test_get_class_spec_candidates_expands_druid_feral_tree(self) -> None:
        candidates = get_class_spec_candidates("DRUID", self.tables)
        self.assertIn("DRUID_FERAL_DPS", candidates)
        self.assertIn("DRUID_FERAL_TANK", candidates)
        self.assertNotIn("FERAL", candidates)

    def test_resolve_spec_key_splits_druid_feral_between_dps_and_tank(self) -> None:
        dps_items = [
            {
                "slotId": index + 1,
                "slot": 5,
                "equipLoc": "INVTYPE_CHEST",
                "subType": "LEATHER",
                "armorRank": 2,
                "stats": {"AGI": 60.0, "AP": 90.0, "CRIT": 30.0, "HIT": 24.0},
                "gemStats": [],
                "enchantInfo": {},
                "legacyBase": 100,
            }
            for index in range(8)
        ]
        tank_items = [
            {
                "slotId": index + 1,
                "slot": 5,
                "equipLoc": "INVTYPE_CHEST",
                "subType": "LEATHER",
                "armorRank": 2,
                "stats": {"STA": 70.0, "AGI": 45.0, "DODGE": 24.0, "HIT": 16.0},
                "gemStats": [],
                "enchantInfo": {},
                "legacyBase": 100,
            }
            for index in range(8)
        ]
        self.assertEqual(resolve_spec_key("DRUID", "FERAL", self.tables, dps_items, None), "DRUID_FERAL_DPS")
        self.assertEqual(resolve_spec_key("DRUID", "FERAL", self.tables, tank_items, None), "DRUID_FERAL_TANK")


if __name__ == "__main__":
    unittest.main()
