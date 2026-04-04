# GearScore2 Benchmarks

This repository now maintains three separate benchmark or audit pipelines:

- `tools/warmane_balance_benchmark.py`
  Warmane real-character offline benchmark with runtime-parity scoring and cohort diagnostics.
- `tools/wowhead_profile_audit.py`
  Wowhead guide taxonomy audit that checks archetype and profile coverage without building a scored gear set.
- `tools/wowhead_bis_benchmark.py`
  Wowhead Phase 1 synthetic BiS benchmark that decodes guide-embedded gear-planner builds and scores them with the same runtime-style logic used by the Warmane benchmark.

Shared companion files:

- `tools/benchmark_core.py`
- `tools/data/wowhead_wotlk_pve_guides.json`
- `tools/wowhead_profile_audit.py`
- `tools/wowhead_bis_benchmark.py`
- `output/wowhead_profile_audit.csv`
- `output/wowhead_profile_audit.json`
- `output/wowhead_bis_phase1_benchmark.csv`
- `output/wowhead_bis_phase1_benchmark.json`

## Warmane Benchmark

`tools/warmane_balance_benchmark.py` builds a repeatable offline benchmark from Warmane armory profiles and exports exactly two output files. Item and gem reference data is resolved from `wotlkdb.com`.

Warmane and Wowhead benchmark scoring now share one Python source of truth in `tools/benchmark_core.py`. The Warmane and Wowhead scripts are input/output adapters over that shared benchmark core, so runtime-parity scoring updates only need to be synchronized in one benchmark module.

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

Wowhead Phase 1 synthetic BiS benchmark:

```powershell
python tools\wowhead_bis_benchmark.py
python tools\wowhead_bis_benchmark.py --spec MAGE_ARCANE
python tools\wowhead_bis_benchmark.py --phase ALL
python tools\wowhead_bis_benchmark.py --refresh --delay 0.2
```

Cached HTML is stored under `tools/cache/`.

## Wowhead Phase 1 Benchmark

The synthetic Wowhead benchmark:

- scrapes the current direct `PHASE_1` guide page for each supported archetype
- selects the first valid embedded `gear-planner` build shown on the guide page
- decodes the planner build into exact equipped items, gems, and enchants
- treats guide tables as non-authoritative for slot selection
- scores the resulting synthetic build with the same `GS2` / `Legacy` / `PvP` logic used by the Warmane benchmark
- uses canonical `CLASS_SPEC` runtime profiles directly; old short spec names are only accepted as input aliases
- enforces global spread compression through runtime `gs2Scale`, not benchmark-only normalization
- records planner validation and rejected runtime slots so parser issues and compatibility issues are visible in the output

CSV headline columns:

- `class`, `spec`, `role`, `phase`
- `parse_status`, `item_count`, `avg_item_level`
- `legacy_gs`, `gs2_pre_cap`, `gs2_cap_bonus`, `gs2_final`, `pvp_gs`
- `missing_enhancement_count`
- `guide_url`, `phase_url`, `planner_url`, `planner_tab_label`
- `planner_validation_status`, `rejected_slot_count`

The JSON artifact contains:

- run metadata and parsing assumptions
- cross-spec summary including ranking, median, and spread
- one full synthetic build record per guide with nested item breakdowns
- cap breakdown and planner enhancement metadata per slot

Important synthetic benchmark assumptions:

- the default build uses the first embedded planner build that passes phase-aware validation, or a manifest override when one is configured
- planner-decoded items, gems, and enchants are the authoritative build source
- guide tables are not used to synthesize or patch missing equipped slots
- temporary proc-only enchants remain unscored to stay aligned with current parity rules
- records are only marked `partial` when planner-encoded gem or enchant data could not be fully resolved
- records can be marked `failed` when the available planner source is clearly invalid for the requested phase

`--phase ALL` runs one combined benchmark across `PHASE_1`, `PHASE_2`, `PHASE_3`, and `PHASE_4` and writes:

- `output/wowhead_bis_all_phases_benchmark.csv`
- `output/wowhead_bis_all_phases_benchmark.json`

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
- `incompatible-item` no longer zeros `GS2`; it keeps legacy base and applies a strong penalty only to the PvE bonus bucket
- Warmane benchmark now exports active, inferred, and selected spec results; the final benchmark score is the higher GS2 between active and inferred
- summary spread is computed from the selected result, while the addon UI keeps the active result visible and shows inferred as a comparison line

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
- raw vs clean `legacy` / `GS2` / `GS2-Legacy` spread metrics
- top positive and negative median spec deltas for each balance view
- quality tier counts and per-category diagnostic coverage
- inferred-spec selection counts and inferred reason counts

Each item record includes:

- `legacy_base`
- matched stat raw and bonus values
- gem raw and bonus values
- enchant raw and bonus values
- resilience multipliers
- final per-item `GS2` / `PvP GearScore`

Each character record now also includes:

- `active_spec_gs2`
- `requested_spec`
- `requested_spec_gs2`
- `inferred_spec`
- `inferred_spec_gs2`
- `inferred_reason`
- `selected_spec`
- `selected_spec_gs2`
- `selected_spec_source`
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

Warmane balance should now be read in two passes:

1. `raw cohort` to see the whole dataset, including broken or off-model records,
2. `clean cohort` to evaluate real `GS2` tuning without collapsed compatibility artifacts.
