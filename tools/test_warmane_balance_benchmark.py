import pathlib
import sys
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

from warmane_balance_benchmark import (
    DEFAULT_CACHE_DIR,
    Fetcher,
    WarmaneCharacterRef,
    build_character_record,
    get_class_spec_candidates,
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
)


REPO_ROOT = pathlib.Path(__file__).resolve().parents[1]


class WarmaneBalanceBenchmarkTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.tables = load_runtime_tables(REPO_ROOT)
        cls.fetcher = Fetcher(DEFAULT_CACHE_DIR)

    def test_runtime_tables_include_spec_profiles(self) -> None:
        self.assertIn("SpecProfiles", self.tables["Tables"])
        self.assertIn("ASSASSINATION", self.tables["Tables"]["SpecProfiles"])
        self.assertEqual(self.tables["Tables"]["SpecProfiles"]["ASSASSINATION"]["role"], "MELEE")
        self.assertIn("PRIEST_HOLY", self.tables["Tables"]["SpecProfiles"])
        self.assertIn("DRUID_FERAL_DPS", self.tables["Tables"]["SpecProfiles"])
        self.assertIn("DRUID_FERAL_TANK", self.tables["Tables"]["SpecProfiles"])

    def test_item_resolution_uses_wotlkdb_item_data(self) -> None:
        item = parse_item_page(40502, 0, self.fetcher)
        self.assertEqual(item["name"], "Valorous Bonescythe Pauldrons")
        self.assertEqual(item["equipLoc"], "INVTYPE_SHOULDER")
        self.assertEqual(item["stats"]["CRIT"], 58.0)
        self.assertEqual(item["stats"]["HASTE"], 43.0)

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
        self.assertEqual(record["gs2_final"], 4238)
        self.assertEqual(record["active_spec"], "ASSASSINATION")
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
        protection = self.tables["Tables"]["SpecProfiles"]["PROTECTION"]
        holy = self.tables["Tables"]["SpecProfiles"]["HOLY"]
        self.assertTrue(is_item_compatible(tank_item, "PALADIN", protection))
        self.assertFalse(is_item_compatible(caster_item, "PALADIN", protection))
        self.assertTrue(is_item_compatible(tank_item, "PALADIN", holy))

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
        diagnostics = get_snapshot_spec_diagnostics(items, "PALADIN", "PROTECTION", self.tables)
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
        self.assertIn("best_alternate_spec", record)
        self.assertIn("best_alternate_spec_gs2", record)
        self.assertIn("best_alternate_delta_pct", record)
        self.assertIn("off_spec_flag", record)
        self.assertIn("off_spec_reason", record)
        self.assertIn("off_spec_diagnostics", record)

    def test_normalize_spec_name_supports_priest_holy_and_feral_tree(self) -> None:
        self.assertEqual(normalize_spec_name("Holy", "PRIEST"), "PRIEST_HOLY")
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
