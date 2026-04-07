import pathlib
import sys
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

import benchmark_core


REPO_ROOT = pathlib.Path(__file__).resolve().parents[1]


class BenchmarkCoreParityTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.tables = benchmark_core.load_runtime_tables(REPO_ROOT)
        benchmark_core.apply_runtime_constants(cls.tables)

    def test_runtime_constants_are_exposed_under_constants_alias(self) -> None:
        constants = self.tables.get("constants")
        self.assertIsInstance(constants, dict)
        self.assertAlmostEqual(constants["GS2_STAT_SCALE"], self.tables["GS_GS2_STAT_SCALE"])
        self.assertAlmostEqual(constants["GEM_SCALE"], self.tables["GS_GEM_SCALE"])
        self.assertAlmostEqual(constants["ENCHANT_SCALE"], self.tables["GS_ENCHANT_SCALE"])
        self.assertAlmostEqual(constants["OFFSPEC_FIT_MATCH_RATIO_FLOOR"], benchmark_core.GS_OFFSPEC_FIT_MATCH_RATIO_FLOOR)
        self.assertAlmostEqual(constants["OFFSPEC_FIT_MATCH_RATIO_FULL"], benchmark_core.GS_OFFSPEC_FIT_MATCH_RATIO_FULL)
        self.assertAlmostEqual(constants["OFFSPEC_FIT_MULTIPLIER_FLOOR"], benchmark_core.GS_OFFSPEC_FIT_MULTIPLIER_FLOOR)
        self.assertAlmostEqual(constants["OFFSPEC_FIT_SIGNATURE_PENALTY"], benchmark_core.GS_OFFSPEC_FIT_SIGNATURE_PENALTY)

    def test_snapshot_fit_multiplier_matches_runtime_threshold_rules(self) -> None:
        fit_multiplier, matched_ratio = benchmark_core.calculate_snapshot_fit_multiplier(
            "CASTER",
            "MAGE_ARCANE",
            item_count=10,
            matched_items=5,
            signature_items=1,
            tables=self.tables,
        )
        expected_progress = (0.5 - benchmark_core.GS_OFFSPEC_FIT_MATCH_RATIO_FLOOR) / (
            benchmark_core.GS_OFFSPEC_FIT_MATCH_RATIO_FULL - benchmark_core.GS_OFFSPEC_FIT_MATCH_RATIO_FLOOR
        )
        expected_base = benchmark_core.GS_OFFSPEC_FIT_MULTIPLIER_FLOOR + (
            (1.0 - benchmark_core.GS_OFFSPEC_FIT_MULTIPLIER_FLOOR) * expected_progress
        )
        expected_final = expected_base * benchmark_core.GS_OFFSPEC_FIT_SIGNATURE_PENALTY
        self.assertAlmostEqual(matched_ratio, 0.5)
        self.assertAlmostEqual(fit_multiplier, expected_final, places=6)

    def test_druid_feral_resolution_prefers_runtime_tiebreak_order(self) -> None:
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
        self.assertEqual(
            benchmark_core.resolve_spec_key("DRUID", "FERAL", self.tables, dps_items, None),
            "DRUID_FERAL_DPS",
        )
        self.assertEqual(
            benchmark_core.resolve_spec_key("DRUID", "FERAL", self.tables, tank_items, None),
            "DRUID_FERAL_TANK",
        )

    def test_incompatible_items_keep_legacy_base_and_penalize_only_pve_bonus_bucket(self) -> None:
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
            "level": 200,
        }
        compatible_pve, compatible_pvp, _flags, compatible_debug = benchmark_core.score_item_with_debug(
            item, "MAGE", "MAGE_ARCANE", self.tables
        )
        incompatible_pve, incompatible_pvp, incompatible_flags, incompatible_debug = benchmark_core.score_item_with_debug(
            item, "PALADIN", "PALADIN_RETRIBUTION", self.tables
        )
        self.assertEqual(compatible_debug["legacy_base"], incompatible_debug["legacy_base"])
        self.assertLess(incompatible_pve, compatible_pve)
        self.assertGreaterEqual(incompatible_pvp, incompatible_debug["legacy_base"])
        self.assertLessEqual(incompatible_pvp, compatible_pvp)
        self.assertIn("incompatible-item", incompatible_flags)

    def test_spec_scale_can_reduce_bonus_bucket_before_application(self) -> None:
        item = {
            "legacyBase": 100,
            "slot": 5,
            "equipLoc": "INVTYPE_CHEST",
            "armorRank": 4,
            "stats": {"STR": 80.0, "CRIT": 40.0, "HIT": 30.0},
            "gemStats": [],
            "enchantInfo": None,
            "hasEnchant": False,
            "resilience": 0.0,
            "level": 232,
        }
        pve_score, _pvp_score, _flags, debug = benchmark_core.score_item_with_debug(
            item, "PALADIN", "PALADIN_RETRIBUTION", self.tables
        )
        self.assertIn("bonus_bucket_pve_scaled", debug)
        self.assertLessEqual(debug["bonus_bucket_pve_scaled"], debug["bonus_bucket_pve"])
        self.assertGreaterEqual(pve_score, debug["legacy_base"])

    def test_snapshot_diagnostics_apply_caps_before_fit_multiplier(self) -> None:
        items = [
            {
                "slotId": index + 1,
                "slot": 5,
                "equipLoc": "INVTYPE_CHEST",
                "subType": "PLATE",
                "armorRank": 4,
                "stats": {"STR": 60.0, "CRIT": 20.0, "HIT": 30.0},
                "gemStats": [],
                "enchantInfo": {},
                "legacyBase": 100,
                "level": 232,
            }
            for index in range(8)
        ]
        diagnostics = benchmark_core.get_snapshot_spec_diagnostics(
            items,
            "PALADIN",
            "PALADIN_RETRIBUTION",
            self.tables,
            None,
        )
        self.assertIsNotNone(diagnostics)
        self.assertEqual(
            diagnostics["total"],
            int((diagnostics["total_before_caps"] + diagnostics["cap_bonus"]) * diagnostics["fit_multiplier"]),
        )
        self.assertEqual(diagnostics["pre_fit_total"], diagnostics["total_before_caps"] + diagnostics["cap_bonus"])


if __name__ == "__main__":
    unittest.main()
