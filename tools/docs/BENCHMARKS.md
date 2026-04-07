# Benchmark Tooling

This directory restores the benchmark documentation that used to live in the main `docs/` tree.

The repository currently contains one active benchmark entrypoint plus one shared scoring core:

- `tools/wowhead_bis_benchmark.py`
  Synthetic Wowhead PvE benchmark that decodes guide-embedded gear-planner builds and scores them with runtime-style logic.
- `tools/benchmark_core.py`
  Shared benchmark scoring core. It contains the runtime-parity scoring, cap handling, diagnostics, summaries, and CLI entrypoint that were previously exposed through the Warmane benchmark wrapper.

Related files:

- `tools/test_wowhead_bis_benchmark.py`
- `tools/data/wowhead_wotlk_pve_guides.json`
- `tools/output/wowhead_bis_phase_1_benchmark.csv`
- `tools/output/wowhead_bis_phase_1_benchmark.json`
- `tools/output/wowhead_bis_all_phases_benchmark.csv`
- `tools/output/wowhead_bis_all_phases_benchmark.json`

## What The Benchmark Tries To Preserve

The benchmark aims for practical offline parity with the addon runtime for:

- core item scoring
- character-level cap scoring
- compatibility gating
- additive-only spec normalization
- active-spec vs inferred-spec comparison logic
- snapshot-fit behavior used by `GearScore2`

It does not attempt to reproduce live WoW inspect transport, delayed inspect updates, or temporary runtime-only aura states.

## Run

Default Wowhead benchmark run:

```powershell
python tools\wowhead_bis_benchmark.py
```

Useful options:

```powershell
python tools\wowhead_bis_benchmark.py --spec MAGE_ARCANE
python tools\wowhead_bis_benchmark.py --phase PHASE_1
python tools\wowhead_bis_benchmark.py --phase ALL
python tools\wowhead_bis_benchmark.py --refresh
python tools\wowhead_bis_benchmark.py --delay 0.2
```

Cached HTML is stored under `tools/cache/`.

## Warmane Balance Benchmark

The historical Warmane benchmark wrapper is gone, but the active CLI entrypoint still exists inside `tools/benchmark_core.py`.

Default Warmane run:

```powershell
python tools\benchmark_core.py
```

By default this:

- reads character URLs from `tools/data/warmane_onyxia_top_chars.txt`
- fetches or reuses cached Warmane armory HTML under `tools/cache/warmane/`
- scores each character with the shared runtime-parity benchmark core
- writes:
  - `tools/output/gs2_balance_report.csv`
  - `tools/output/gs2_balance_report.json`

Useful options:

```powershell
python tools\benchmark_core.py --character Mizianolas
python tools\benchmark_core.py --dataset tools\data\cherrypicked.txt
python tools\benchmark_core.py --output-dir tools\output
python tools\benchmark_core.py --active-spec-only
python tools\benchmark_core.py --refresh
python tools\benchmark_core.py --delay 0.2
```

Practical Warmane workflow:

1. Put one Warmane armory profile URL per line into a dataset file such as `tools/data/cherrypicked.txt`.
2. Run `python tools\benchmark_core.py --dataset tools\data\cherrypicked.txt`.
3. Inspect `tools/output/gs2_balance_report.csv` for the quick comparison view.
4. Inspect `tools/output/gs2_balance_report.json` for full diagnostics, item breakdowns, selected spec source, and cap details.

Notes:

- `--character` filters by character name after the dataset is loaded, so the target character must already be present in the dataset file.
- `--active-spec-only` keeps the exported final `gs2_final` on the active spec, even when the benchmark finds a stronger inferred/offspec candidate.
- `--refresh` forces a refetch of cached Warmane and WotLKDB pages.
- `--delay` is useful when refreshing many uncached profiles to avoid hammering remote sites.

## Wowhead Synthetic Benchmark

The synthetic Wowhead benchmark:

- scrapes the configured WotLK PvE guide manifest
- selects planner builds from the guide markup
- decodes exact equipped items, gems, and enchants from planner payloads
- uses planner-decoded gear as the authoritative build source
- scores the resulting build with the same `GearScore2` / `Legacy GearScore` / `PvP GearScore` logic used by the shared benchmark core
- records planner validation and rejected slots so parser or compatibility issues stay visible in the output

`--phase ALL` runs one combined benchmark across:

- `PHASE_1`
- `PHASE_2`
- `PHASE_3`
- `PHASE_4`

and writes:

- `tools/output/wowhead_bis_all_phases_benchmark.csv`
- `tools/output/wowhead_bis_all_phases_benchmark.json`

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

Those temporary effects may still exist as informational addon data, but they do not change benchmark `GS2`.

## Outputs

The CSV artifact is the quick comparison view. It includes fields such as:

- `class`, `spec`, `role`, `phase`
- `resolved_spec` for the canonical runtime profile key; prefer this over bare `spec` when charting cross-class archetypes such as `PROTECTION`
- `parse_status`, `item_count`, `avg_item_level`
- `legacy_gs`, `gs2_pre_cap`, `gs2_cap_bonus`, `gs2_final`, `pvp_gs`
- planner validation and rejected-slot fields

The JSON artifact is the full audit output. It includes:

- run metadata and benchmark assumptions
- summary statistics and spread analysis
- one detailed record per benchmark build
- nested item breakdowns
- cap breakdown and enhancement metadata
- diagnostics and quality-tier annotations

## Shared Core And Historical Note

Historically, the repository also shipped a dedicated Warmane benchmark wrapper and a separate benchmark doc in `docs/GS2_BALANCE_BENCHMARK.md`.

That wrapper is no longer present in the current tree, but its scoring and reporting logic was not discarded. The shared implementation now lives in `tools/benchmark_core.py`, and the current benchmark documentation was restored here under `tools/docs/` so benchmark-specific material stays next to the tooling it describes.
