# GearScore2 Balance Benchmark

`tools/warmane_balance_benchmark.py` builds a repeatable offline benchmark from Warmane armory profiles and exports exactly two output files. Item and gem reference data is resolved from `wotlkdb.com`.

Profile/audit companion files:

- `tools/data/wowhead_wotlk_pve_guides.json`
- `tools/wowhead_profile_audit.py`
- `output/wowhead_profile_audit.csv`
- `output/wowhead_profile_audit.json`

The benchmark now aims for practical offline parity with current addon runtime for:

- core item scoring
- cap scoring
- compatibility gating
- offline off-spec comparison audit

It does not attempt to reproduce live WoW inspect transport or timing behavior.

- `output/gs2_balance_report.csv`
- `output/gs2_balance_report.json`

## Run

```powershell
python tools\warmane_balance_benchmark.py
```

Useful options:

```powershell
python tools\warmane_balance_benchmark.py --refresh
python tools\warmane_balance_benchmark.py --delay 0.2
python tools\warmane_balance_benchmark.py --dataset tools\data\warmane_onyxia_top_chars.txt
python tools\warmane_balance_benchmark.py --character Mizianolas
```

Wowhead profile audit:

```powershell
python tools\wowhead_profile_audit.py
```

Cached HTML is stored under `tools/cache/`.

## Cap Parity

Benchmark cap parity follows the addon's permanent cap model.

Benchmark cap scoring includes:

- gear
- gems
- enchants
- spec passives
- supported permanent racials

Benchmark cap scoring excludes temporary score impact from:

- elixirs
- food
- party or raid auras
- target debuffs
- other temporary live buffs

Those temporary effects may still exist as informational tooltip/runtime data in the addon, but they do not change benchmark `GS2`.

## CSV Columns

- `name`, `realm`, `class`, `active_spec`, `role`
- `item_count`, `avg_item_level`
- `legacy_gs`, `gs2_pre_cap`, `gs2_cap_bonus`, `gs2_final`, `pvp_gs`
- `global_delta_from_median_pct`
- `group_key`, `group_median_gs2`, `group_delta_from_median_pct`
- `top_geared_band_flag`, `top_band_clean_flag`
- `benchmark_quality_tier`, `clean_record_flag`, `outlier_flag`
- `diagnostic_informational_count`, `diagnostic_optimization_count`
- `diagnostic_compatibility_count`, `diagnostic_blocker_count`
- `cap_hit_progress`, `cap_expertise_progress`, `cap_defense_progress`, `cap_arp_progress`
- `red_flag_reason`

Benchmark-specific runtime parity notes:

- shirt and tabard are ignored to match addon runtime character scoring
- `special-enchant-unscored` is informational, not an automatic balance failure
- clean records exclude compatibility issues and benchmark data blockers
- benchmark parity applies to scoring/profile comparison logic, not `NotifyInspect` / `INSPECT_TALENT_READY` timing
- `PRIEST_HOLY` is treated as a first-class profile key
- druid feral tree sources are normalized into `DRUID_FERAL_DPS` or `DRUID_FERAL_TANK` before final profile comparison

## JSON

The JSON file is the full audit artifact. It contains run metadata, assumptions, explicit data source mapping, benchmark summary, and one complete record per character with:

- Warmane snapshot fields
- talent tree data
- resolved spec profile loaded from addon runtime tables
- parsed items and resolved gems
- per-item score breakdown matching the Lua scoring stages
- cap breakdown, collected cap stats, diagnostics, and flattened benchmark fields
- diagnostic categories and benchmark quality tier

The summary section now includes:

- whole-cohort score distribution
- clean-subset score distribution
- clean top-geared band distribution
- quality tier counts and per-category diagnostic coverage

Each item record includes:

- `legacy_base`
- matched stat raw and bonus values
- gem raw and bonus values
- enchant raw and bonus values
- resilience multipliers
- final per-item `GS2` / `PvP GearScore`

Each character record now also includes:

- `active_spec_gs2`
- `best_alternate_spec`
- `best_alternate_spec_gs2`
- `best_alternate_delta_pct`
- `off_spec_flag`
- `off_spec_reason`
- `off_spec_diagnostics`

## Interpretation

The benchmark compares characters in two ways:

1. globally against the whole cohort,
2. against sensible peers, using spec first and role as fallback.

Flagged outliers are meant for manual review, especially when they combine high item level with weak `GS2`, low cap progress, real compatibility issues, or missing benchmark data.

`top_geared_band_flag` is now based on item-level banding instead of score spread. The benchmark uses the top `10%` item-level threshold as the default end-game comparison band.
