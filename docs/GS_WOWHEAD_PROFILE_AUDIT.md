# Wowhead WotLK Profile Audit

This document records the current curated audit of Wowhead WotLK PvE build guides against the runtime `GS2` profile model.

The source manifest lives in `tools/data/wowhead_wotlk_pve_guides.json`.

The repeatable machine-readable exports are produced by:

```powershell
python tools\wowhead_profile_audit.py
```

Generated artifacts:

- `output/wowhead_profile_audit.csv`
- `output/wowhead_profile_audit.json`

## Current Findings

The audit treats Wowhead's WotLK PvE guides as the external reference for:

- supported PvE build archetypes
- role expectations
- gear-family expectations
- cross-phase BiS structure

## Implemented Model Fixes

### `PRIEST_HOLY`

- Wowhead supports Holy Priest as a distinct PvE healer build.
- Runtime and benchmark now expose an explicit `PRIEST_HOLY` profile.
- Priest talent-tree mapping now resolves the Holy tree to `PRIEST_HOLY` instead of colliding with Paladin `HOLY`.

### `DRUID_FERAL_DPS` and `DRUID_FERAL_TANK`

- Wowhead splits feral cat DPS and bear tank into separate PvE builds.
- Runtime and benchmark now split the old generic feral model into:
  - `DRUID_FERAL_DPS`
  - `DRUID_FERAL_TANK`
- Talent detection still uses the feral tree, but the final runtime/benchmark profile is resolved from gear-fit scoring between the two feral variants.
- `DRUID_FERAL_TANK` uses its own cap model instead of inheriting cat DPS `ARP` logic.

### Druid Cloth Exception

- Wowhead BiS lists justify allowing cloth on caster/healer druids.
- `BALANCE` and `DRUID_RESTORATION` therefore keep leather as their native armor family, but no longer hard-reject cloth in `GS2`.

## Audit Reading Guide

`support_status` values in the audit export:

- `exact_match`: direct runtime profile already matches the Wowhead archetype
- `new_profile_added`: archetype required a new runtime profile
- `split_profile_added`: archetype required splitting a previous shared runtime profile
- `missing_profile`: no runtime profile exists yet

`support_path` values:

- `direct_profile`: guide maps directly to one runtime profile
- `druid_feral_tree_split`: guide is resolved from the shared feral tree into a canonical feral subtype
- `manual_review`: guide is present but still needs manual tuning review

## Remaining Review Queue

This refactor intentionally focuses on structural model correctness first:

- missing archetypes
- spec-key collisions
- shared-tree profile splits
- guide-backed compatibility exceptions

Exact stat-weight tuning for already-supported archetypes remains a manual review track. The audit exports keep every Wowhead archetype and phase visible so those follow-up weight/cap reviews can be repeated without rebuilding the taxonomy.
