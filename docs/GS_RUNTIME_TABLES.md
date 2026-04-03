# GearScore2 Runtime Tables

Runtime table data is now namespaced under `GS.Data` instead of being exposed as raw top-level globals.

- `Data/RuntimeTables.lua` populates `GS.Data.Tables`
- `Data/EnchantData.lua` populates `GS.Data.Enchants.Values`
- `Data/GemData.lua` populates `GS.Data.Gems.Values` and `GS.Data.Gems.Items`

For readability, section titles below still mention the legacy table names in parentheses, but the canonical runtime access path is the namespaced one.

## Table of Contents

- [1. Global Scoring Constants](#1-global-scoring-constants)
  - [1.1 Rating Conversions (`GS_RatingConversions`)](#11-rating-conversions-gs_ratingconversions)
  - [1.2 Cap Segment Defaults (`GS_CapSegmentDefaults`)](#12-cap-segment-defaults-gs_capsegmentdefaults)
  - [1.3 Live Aura Cap Modifiers (`GS_LiveCapBuffs`)](#13-live-aura-cap-modifiers-gs_livecapbuffs)
  - [1.4 Inspect Runtime Thresholds](#14-inspect-runtime-thresholds)
- [2. Legacy Slot Modifiers (`GS_ItemTypes`)](#2-legacy-slot-modifiers-gs_itemtypes)
- [3. Legacy Formula Tables (`GS_Formula`)](#3-legacy-formula-tables-gs_formula)
  - [3.1 Formula A (`itemLevel > 120`)](#31-formula-a-itemlevel--120)
  - [3.2 Formula B (`itemLevel <= 120`)](#32-formula-b-itemlevel--120)
- [4. Enchantable Slots (`GS_EnchantSlots`)](#4-enchantable-slots-gs_enchantslots)
- [5. Armor Rank Order (`GS_ArmorClassOrder`)](#5-armor-rank-order-gs_armorclassorder)
- [6. Class Default Specs (`GS_ClassDefaults`)](#6-class-default-specs-gs_classdefaults)
- [7. Specialization Profiles (`GS_SpecProfiles`)](#7-specialization-profiles-gs_specprofiles)
- [8. Enchant Data Runtime Shape](#8-enchant-data-runtime-shape)
- [9. Character Cap Profiles (`GS_CapProfiles`)](#9-character-cap-profiles-gs_capprofiles)
  - [9.1 Melee / Physical Specs](#91-melee--physical-specs)
  - [9.2 Tanks](#92-tanks)
  - [9.3 Rogues / Enhancement Shared Progressive Hit Pool](#93-rogues--enhancement-shared-progressive-hit-pool)
  - [9.4 Casters / Spell-Hit Specs](#94-casters--spell-hit-specs)
  - [9.5 Spec-Defined Passive Bonuses Used In Threshold Resolution](#95-spec-defined-passive-bonuses-used-in-threshold-resolution)

## 1. Global Scoring Constants

| Constant | Value |
|---|---:|
| `GS_GS2_STAT_SCALE` | `0.12` |
| `GS_GEM_SCALE` | `0.35` |
| `GS_ENCHANT_SCALE` | `0.35` |
| `GS_PVE_RESILIENCE_RATE` | `0.0015` |
| `GS_PVP_RESILIENCE_RATE` | `0.0020` |
| `GS_PVE_RESILIENCE_FLOOR` | `0.70` |
| `GS_PVP_RESILIENCE_CAP` | `1.35` |
| `GS_CAP_BONUS_ANCHOR_LOW_GS2` | `4000` |
| `GS_CAP_BONUS_ANCHOR_HIGH_GS2` | `5000` |
| `GS_CAP_BONUS_ANCHOR_LOW_BONUS` | `180` |
| `GS_CAP_BONUS_ANCHOR_HIGH_BONUS` | `90` |
| `GS_CAP_BONUS_MIN` | `20` |
| `GS_CAP_BONUS_MAX` | `250` |

## 1.1 Rating Conversions (`GS.Data.Tables.RatingConversions`)

| Conversion | Value |
|---|---:|
| `MELEE_HIT` | `32.78998947` |
| `SPELL_HIT` | `26.231992` |
| `EXPERTISE` | `8.196` |
| `DEFENSE` | `4.9185` |

## 1.2 Cap Segment Defaults (`GS.Data.Tables.CapSegmentDefaults`)

| Multiplier | Value |
|---|---:|
| `CRITICAL` | `1.25` |
| `USEFUL` | `0.60` |
| `OVERFLOW` | `0.20` |
| `HIT_OVERFLOW` | `0.50` |
| `DEFENSE_OVERFLOW` | `0.55` |
| `ARP_OVERFLOW` | `0.05` |

## 1.3 Live Aura Cap Modifiers (`GS.Data.Tables.LiveCapBuffs`)

### Helpful auras

| Spell ID | Name | Effect |
|---|---|---|
| `6562` | `Heroic Presence` | `+1% melee hit`, `+1% spell hit` |
| `60340` | `Elixir of Accuracy` | `+45 hit rating` |
| `60343` | `Elixir of Mighty Defense` | `+45 defense rating` |
| `60344` | `Elixir of Expertise` | `+45 expertise rating` |
| `60345` | `Elixir of Armor Piercing` | `+45 armor penetration rating` |

### Harmful auras on target

| Spell ID | Name | Effect |
|---|---|---|
| `33198` | `Misery` | `+3% target spell hit bonus` |

## 1.4 Inspect Runtime Thresholds

| Constant | Value | Meaning |
|---|---:|---|
| `GS_MOUSEOVER_INSPECT_DELAY` | `0.25` | Mouseover must remain on the same player GUID for this long before inspect is queued |
| `GS_INSPECT_THROTTLE` | `0.35` | Minimum time between starting inspect requests |
| `GS_RECENT_WINDOW` | `1.5` | Same GUID is not re-queued inside this recent window |
| `GS_ACTIVE_TIMEOUT` | `3.0` | Safety timeout for an active inspect session |
| `GS_SCAN_TIMEOUT` | `3.0` | Maximum time before scan finalizes as timeout/inferred state |
| `GS_READY_DELAY` | `0.15` | Delay after inspect-ready events before polling snapshot data |
| `GS_FORCE_POLL_DELAY` | `0.20` | Initial fallback poll delay after `NotifyInspect` |
| `GS_MIN_INSPECT_ITEMS` | `8` | Minimum item count required before finalizing a snapshot |
| `GS_TALENT_SPEC_WAIT` | `1.0` | Time allowed for inspect talent data to resolve before gear-based spec inference is allowed |
| `GS_OFFSPEC_MIN_RATIO` | `0.05` | Minimum relative `GS2` lead required before an alternate inferred spec is marked as off-spec |
| `GS_CACHE_TTL` | `180` | Cached inspect record lifetime |
| `GS_FRESH_TTL` | `15` | Freshness window used to avoid immediate re-inspection |
| `GS_INSPECT_CACHE_MAX` | `300` | Hard cap on stored inspect records before LRU-style trimming runs |
| `GS_INSPECT_CACHE_TRIM_TO` | `220` | Target size after inspect-cache trimming |

## 2. Legacy Slot Modifiers (`GS.Data.Tables.ItemTypes`)

| EquipLoc | SlotMOD | ItemSlot | Enchantable |
|---|---:|---:|---|
| `INVTYPE_HEAD` | `1.0000` | `1` | Yes |
| `INVTYPE_NECK` | `0.5625` | `2` | No |
| `INVTYPE_SHOULDER` | `0.7500` | `3` | Yes |
| `INVTYPE_BODY` | `0` | `4` | No |
| `INVTYPE_CHEST` | `1.0000` | `5` | Yes |
| `INVTYPE_ROBE` | `1.0000` | `5` | Yes |
| `INVTYPE_WAIST` | `0.7500` | `6` | No |
| `INVTYPE_LEGS` | `1.0000` | `7` | Yes |
| `INVTYPE_FEET` | `0.7500` | `8` | Yes |
| `INVTYPE_WRIST` | `0.5625` | `9` | Yes |
| `INVTYPE_HAND` | `0.7500` | `10` | Yes |
| `INVTYPE_FINGER` | `0.5625` | `31` | No |
| `INVTYPE_TRINKET` | `0.5625` | `33` | No |
| `INVTYPE_CLOAK` | `0.5625` | `15` | Yes |
| `INVTYPE_WEAPON` | `1.0000` | `36` | Yes |
| `INVTYPE_2HWEAPON` | `2.0000` | `16` | Yes |
| `INVTYPE_WEAPONMAINHAND` | `1.0000` | `16` | Yes |
| `INVTYPE_WEAPONOFFHAND` | `1.0000` | `17` | Yes |
| `INVTYPE_SHIELD` | `1.0000` | `17` | Yes |
| `INVTYPE_HOLDABLE` | `1.0000` | `17` | No |
| `INVTYPE_RANGED` | `0.3164` | `18` | Yes |
| `INVTYPE_THROWN` | `0.3164` | `18` | No |
| `INVTYPE_RANGEDRIGHT` | `0.3164` | `18` | No |
| `INVTYPE_RELIC` | `0.3164` | `18` | No |

## 3. Legacy Formula Tables (`GS.Data.Tables.Formula`)

### 3.1 Formula A (`itemLevel > 120`)

| Rarity | A | B |
|---|---:|---:|
| `4` | `91.4500` | `0.6500` |
| `3` | `81.3750` | `0.8125` |
| `2` | `73.0000` | `1.0000` |

### 3.2 Formula B (`itemLevel <= 120`)

| Rarity | A | B |
|---|---:|---:|
| `4` | `26.0000` | `1.2000` |
| `3` | `0.7500` | `1.8000` |
| `2` | `8.0000` | `2.0000` |
| `1` | `0.0000` | `2.2500` |

## 4. Enchantable Slots (`GS.Data.Tables.EnchantSlots`)

| EquipLoc |
|---|
| `INVTYPE_HEAD` |
| `INVTYPE_SHOULDER` |
| `INVTYPE_CHEST` |
| `INVTYPE_ROBE` |
| `INVTYPE_LEGS` |
| `INVTYPE_FEET` |
| `INVTYPE_WRIST` |
| `INVTYPE_HAND` |
| `INVTYPE_CLOAK` |
| `INVTYPE_2HWEAPON` |
| `INVTYPE_WEAPONMAINHAND` |
| `INVTYPE_WEAPONOFFHAND` |
| `INVTYPE_WEAPON` |
| `INVTYPE_SHIELD` |
| `INVTYPE_RANGED` |

## 5. Armor Rank Order (`GS.Data.Tables.ArmorClassOrder`)

| Armor Type | Rank |
|---|---:|
| `CLOTH` | `1` |
| `LEATHER` | `2` |
| `MAIL` | `3` |
| `PLATE` | `4` |

## 6. Class Default Specs (`GS.Data.Tables.ClassDefaults`)

| Class | Default Spec |
|---|---|
| `WARRIOR` | `FURY` |
| `PALADIN` | `RETRIBUTION` |
| `HUNTER` | `MARKSMANSHIP` |
| `ROGUE` | `COMBAT` |
| `PRIEST` | `SHADOW` |
| `DEATHKNIGHT` | `UNHOLY` |
| `SHAMAN` | `ELEMENTAL` |
| `MAGE` | `ARCANE` |
| `WARLOCK` | `AFFLICTION` |
| `DRUID` | `BALANCE` |

## 7. Specialization Profiles (`GS.Data.Tables.SpecProfiles`)

Each row lists:

- role
- armor target
- shield usage
- ranged usage
- dual wield usage when present
- PvE weights
- PvP weights

| Spec | Role | Armor | Shield | Ranged | Dual Wield | PvE Weights | PvP Weights |
|---|---|---|---|---|---|---|---|
| `ARMS` | `MELEE` | `PLATE` | No | No | No | `STR 3.95, CRIT 2.35, HIT 2.6, HASTE 1.9, ARP 3.05, AP 2.0, EXPERTISE 2.2` | `STR 2.2, CRIT 1.2, HIT 0.8, HASTE 0.9, ARP 1.3, AP 1.0, RESILIENCE 2.2` |
| `FURY` | `MELEE` | `PLATE` | No | No | Yes | `STR 3.35, CRIT 1.95, HIT 2.35, HASTE 1.75, ARP 2.35, AP 1.55, EXPERTISE 1.75` | `STR 2.0, CRIT 1.0, HASTE 0.8, AP 0.9, RESILIENCE 2.2` |
| `PROTECTION` | `TANK` | `PLATE` | Yes | No | No | `STA 1.8, STR 0.9, DEFENSE 2.8, DODGE 2.4, PARRY 2.3, BLOCK 2.0, BLOCKVALUE 1.5, HIT 1.1, EXPERTISE 1.3` | `STR 0.8, DODGE 1.4, PARRY 1.3, BLOCK 1.2, RESILIENCE 1.7` |
| `HOLY` | `HEALER` | `PLATE` | Yes | No | No | `INT 2.5, SP 2.9, HASTE 1.9, CRIT 1.4, MP5 1.7, SPI 0.5` | `INT 2.0, SP 2.4, HASTE 1.1, CRIT 0.8, MP5 0.8, RESILIENCE 2.2` |
| `RETRIBUTION` | `MELEE` | `PLATE` | No | No | No | `STR 5.5, CRIT 3.1, HIT 3.45, HASTE 3.2, EXPERTISE 3.25, ARP 3.95, AP 2.8` | `STR 2.2, CRIT 1.0, AP 0.9, RESILIENCE 2.2` |
| `BEASTMASTERY` | `RANGED` | `MAIL` | No | Yes | No | `AGI 2.05, RAP 1.15, AP 0.7, HIT 1.35, CRIT 1.15, HASTE 0.8, ARP 0.85` | `AGI 2.1, RAP 1.0, CRIT 1.0, HASTE 0.7, RESILIENCE 2.2` |
| `MARKSMANSHIP` | `RANGED` | `MAIL` | No | Yes | No | `AGI 2.9, RAP 1.6, AP 0.9, HIT 1.8, CRIT 1.7, HASTE 1.2, ARP 2.0` | `AGI 2.2, RAP 1.0, CRIT 1.0, ARP 1.0, RESILIENCE 2.2` |
| `SURVIVAL` | `RANGED` | `MAIL` | No | Yes | No | `AGI 2.45, RAP 1.2, AP 0.7, HIT 1.45, CRIT 1.2, HASTE 1.0` | `AGI 2.2, CRIT 1.0, HASTE 0.8, RESILIENCE 2.2` |
| `ASSASSINATION` | `MELEE` | `LEATHER` | No | No | Yes | `AGI 1.15, AP 0.5, HIT 0.7, HASTE 0.4, CRIT 0.6, EXPERTISE 0.55` | `AGI 2.2, AP 1.0, HASTE 0.8, CRIT 0.9, RESILIENCE 2.2` |
| `COMBAT` | `MELEE` | `LEATHER` | No | No | Yes | `AGI 1.1, AP 0.45, HIT 0.7, HASTE 0.42, CRIT 0.58, ARP 0.52, EXPERTISE 0.55` | `AGI 2.0, AP 0.9, HASTE 0.7, CRIT 0.8, RESILIENCE 2.2` |
| `SUBTLETY` | `MELEE` | `LEATHER` | No | No | Yes | `AGI 2.2, AP 1.0, HIT 1.5, HASTE 0.8, CRIT 1.2, ARP 1.0, EXPERTISE 1.1` | `AGI 2.3, AP 1.0, CRIT 1.0, RESILIENCE 2.4` |
| `DISCIPLINE` | `HEALER` | `CLOTH` | No | No | No | `INT 2.0, SP 2.3, CRIT 1.2, HASTE 1.1, MP5 0.9, SPI 0.65` | `INT 2.1, SP 2.2, CRIT 0.9, HASTE 0.8, RESILIENCE 2.4` |
| `PRIEST_HOLY` | `HEALER` | `CLOTH` | No | No | No | `INT 2.35, SP 3.05, HASTE 2.2, CRIT 1.75, SPI 1.9, MP5 1.25` | `INT 2.0, SP 2.2, HASTE 0.9, CRIT 0.8, SPI 0.9, RESILIENCE 2.4` |
| `SHADOW` | `CASTER` | `CLOTH` | No | No | No | `INT 1.1, SP 1.8, HIT 1.0, HASTE 0.8, CRIT 0.6, SPI 0.45` | `INT 1.6, SP 2.3, HASTE 1.0, CRIT 0.8, RESILIENCE 2.3` |
| `BLOOD` | `TANK` | `PLATE` | No | No | No | `STA 2.95, STR 1.8, DEFENSE 3.9, DODGE 3.1, PARRY 3.1, HIT 1.5, EXPERTISE 1.75` | `STR 1.0, RESILIENCE 2.0` |
| `FROST` | `MELEE` | `PLATE` | No | No | Yes | `STR 2.5, HIT 1.7, HASTE 1.2, CRIT 1.2, EXPERTISE 1.3, AP 0.9` | `STR 2.2, CRIT 0.9, RESILIENCE 2.2` |
| `UNHOLY` | `MELEE` | `PLATE` | No | No | No | `STR 2.6, HIT 1.8, HASTE 1.5, CRIT 1.2, EXPERTISE 1.3, AP 1.1` | `STR 2.2, HASTE 0.8, RESILIENCE 2.2` |
| `ELEMENTAL` | `CASTER` | `CLOTH` | Yes | No | No | `INT 1.1, SP 1.8, HIT 1.05, HASTE 0.9, CRIT 0.7, MP5 0.55` | `INT 1.5, SP 2.3, HASTE 0.9, CRIT 0.8, RESILIENCE 2.3` |
| `ENHANCEMENT` | `MELEE` | `MAIL` | No | No | Yes | `AGI 2.65, AP 1.65, HIT 2.4, HASTE 2.0, CRIT 1.65, EXPERTISE 1.95` | `AGI 1.8, AP 1.0, HASTE 0.9, RESILIENCE 2.2` |
| `RESTORATION` | `HEALER` | `MAIL` | Yes | No | No | `INT 2.3, SP 2.7, HASTE 1.8, CRIT 1.2, MP5 1.4, SPI 0.2` | `INT 2.0, SP 2.3, HASTE 0.9, MP5 0.7, RESILIENCE 2.3` |
| `ARCANE` | `CASTER` | `CLOTH` | No | No | No | `INT 1.85, SP 2.7, HIT 1.75, HASTE 1.45, CRIT 1.15, SPI 0.4` | `INT 1.8, SP 2.2, HASTE 0.9, CRIT 0.8, RESILIENCE 2.2` |
| `FIRE` | `CASTER` | `CLOTH` | No | No | No | `INT 1.45, SP 2.4, HIT 1.4, HASTE 1.3, CRIT 1.0, SPI 0.2` | `INT 1.6, SP 2.3, HASTE 1.0, CRIT 0.8, RESILIENCE 2.2` |
| `MAGE_FROST` | `CASTER` | `CLOTH` | No | No | No | `INT 1.7, SP 2.6, HIT 1.7, HASTE 1.3, CRIT 1.2` | `INT 1.6, SP 2.3, HASTE 0.9, CRIT 0.8, RESILIENCE 2.5` |
| `AFFLICTION` | `CASTER` | `CLOTH` | No | No | No | `INT 1.7, SP 2.8, HIT 1.8, HASTE 1.6, CRIT 1.0, SPI 0.5` | `INT 1.6, SP 2.3, HASTE 1.0, RESILIENCE 2.3` |
| `DEMONOLOGY` | `CASTER` | `CLOTH` | No | No | No | `INT 1.7, SP 2.7, HIT 1.7, HASTE 1.4, CRIT 1.1, SPI 0.4` | `INT 1.6, SP 2.2, HASTE 0.9, RESILIENCE 2.2` |
| `DESTRUCTION` | `CASTER` | `CLOTH` | No | No | No | `INT 2.45, SP 3.55, HIT 2.25, HASTE 2.1, CRIT 1.75, SPI 0.65` | `INT 1.6, SP 2.3, HASTE 0.9, CRIT 0.8, RESILIENCE 2.3` |
| `BALANCE` | `CASTER` | `LEATHER` | No | No | No | `INT 2.95, SP 3.85, HIT 2.6, HASTE 2.45, CRIT 1.95, SPI 1.85` | `INT 1.7, SP 2.2, HASTE 0.9, CRIT 0.8, RESILIENCE 2.3` |
| `DRUID_FERAL_DPS` | `MELEE` | `LEATHER` | No | No | No | `AGI 2.5, AP 1.1, HIT 1.6, HASTE 1.0, CRIT 1.3, ARP 1.5, EXPERTISE 1.2` | `AGI 2.2, AP 0.9, RESILIENCE 2.3` |
| `DRUID_FERAL_TANK` | `TANK` | `LEATHER` | No | No | No | `STA 2.9, AGI 2.2, DODGE 1.9, DEFENSE 0.8, HIT 1.2, EXPERTISE 1.35, AP 0.45, CRIT 0.55` | `STA 1.6, AGI 1.8, DODGE 1.0, RESILIENCE 2.3` |
| `DRUID_RESTORATION` | `HEALER` | `LEATHER` | No | No | No | `INT 4.1, SP 4.2, HASTE 3.15, CRIT 1.65, MP5 2.0, SPI 2.25` | `INT 2.0, SP 2.2, HASTE 0.9, SPI 0.7, RESILIENCE 2.4` |

Notes:

- `PALADIN` still uses `HOLY` as its spec key.
- `PRIEST` uses `PRIEST_HOLY` to avoid colliding with Paladin `HOLY`.
- `DRUID` still detects the feral talent tree as `FERAL`, but runtime scoring resolves that tree into `DRUID_FERAL_DPS` or `DRUID_FERAL_TANK` before final scoring.

## 8. Enchant Data Runtime Shape

Entries in `Data/EnchantData.lua` use:

| Field | Meaning |
|---|---|
| `kind = "stats"` | static stat payload exists and may be scored |
| `kind = "special"` | recognized enchant with no scoreable static stats |
| `label` | human-readable enchant label |
| `stats` | normalized stat payload used by scoring |
| `special = true` | mixed or special behavior was also detected in source data |
| `unknownTraits` | source-side traits that were not normalized into runtime stat keys |

## 9. Character Cap Profiles (`GS.Data.Tables.CapProfiles`)

Cap profiles affect only final character `GearScore2`.

Each pool contributes a `0..100%` progress value toward the character cap bonus.
Resolved thresholds still come from the pool data below, but final scoring uses progress to a single target per pool instead of segment-by-segment overflow math.

### 9.1 Melee / Physical Specs

| Spec | Pools |
|---|---|
| `ARMS` | `HIT: 8% special progress target`, `EXPERTISE: 26 progress target`, `ARP: 1400 progress target` |
| `FURY` | `HIT: 8% special progress target`, `EXPERTISE: 26 progress target`, `ARP: 1400 progress target` |
| `RETRIBUTION` | `HIT: 8% special progress target`, `EXPERTISE: 26 progress target` |
| `FROST` | `HIT: 8% special progress target`, `EXPERTISE: 26 progress target` |
| `UNHOLY` | `HIT: 8% special progress target`, `EXPERTISE: 26 progress target` |
| `DRUID_FERAL_DPS` | `HIT: 8% special progress target`, `EXPERTISE: 26 progress target`, `ARP: 1400 progress target` |

### 9.2 Tanks

| Spec | Pools |
|---|---|
| `PROTECTION` | `DEFENSE: 540 progress target`, `EXPERTISE: 26 progress target`, `HIT: 8% special progress target` |
| `BLOOD` | `DEFENSE: 540 progress target`, `EXPERTISE: 26 progress target`, `HIT: 8% special progress target` |
| `DRUID_FERAL_TANK` | `HIT: 8% special progress target`, `EXPERTISE: 26 progress target` |

### 9.3 Rogues / Enhancement Hit Progress Targets

| Spec | Pools |
|---|---|
| `ASSASSINATION` | `HIT: 8% melee special progress target`, `SPELL_HIT: 17% poison/spell progress target`, `EXPERTISE: 26 progress target` |
| `COMBAT` | `HIT: 8% melee special progress target`, `SPELL_HIT: 17% poison/spell progress target`, `EXPERTISE: 26 progress target`, `ARP: 1400 progress target` |
| `SUBTLETY` | `HIT: 8% melee special progress target`, `SPELL_HIT: 17% poison/spell progress target`, `EXPERTISE: 26 progress target` |
| `ENHANCEMENT` | `HIT: 8% melee special progress target`, `EXPERTISE: 26 progress target` |

### 9.4 Casters / Spell-Hit Specs

| Spec | Pools |
|---|---|
| `SHADOW` | `HIT: 17% spell-hit progress target` |
| `ELEMENTAL` | `HIT: 17% spell-hit progress target` |
| `ARCANE` | `HIT: 17% spell-hit progress target` |
| `FIRE` | `HIT: 17% spell-hit progress target` |
| `MAGE_FROST` | `HIT: 17% spell-hit progress target` |
| `AFFLICTION` | `HIT: 17% spell-hit progress target` |
| `DEMONOLOGY` | `HIT: 17% spell-hit progress target` |
| `DESTRUCTION` | `HIT: 17% spell-hit progress target` |
| `BALANCE` | `HIT: 17% spell-hit progress target` |

### 9.5 Spec-Defined Passive Bonuses Used In Threshold Resolution

| Spec | Passive Context |
|---|---|
| `ASSASSINATION` | `meleeHitBonus 5`, `spellHitBonus 5` |
| `COMBAT` | `meleeHitBonus 5`, `spellHitBonus 5` |
| `SUBTLETY` | `meleeHitBonus 5`, `spellHitBonus 5` |
| `ENHANCEMENT` | `meleeHitBonus 3`, `spellHitBonus 3` |
| `SHADOW` | `spellHitBonus 3` |
| `ELEMENTAL` | `spellHitBonus 3` |
| `ARCANE` | `spellHitBonus 3` |
| `FIRE` | `spellHitBonus 3` |
| `MAGE_FROST` | `spellHitBonus 3` |
| `AFFLICTION` | `spellHitBonus 3` |
| `BALANCE` | `spellHitBonus 4` |

## 10. Permanent And Temporary Cap Context

`GS.Data.Tables.CapProfiles` and `GS.Data.Tables.PermanentCapRacials` feed the permanent cap context used by scoring.

`GS.Data.Tables.LiveCapBuffs` remains in runtime for live tooltip presentation only.

Temporary buffs from that table do not affect:

- `cap progress`
- `capped`
- `capAdjustedGs2`
- final `GearScore2`

## 11. Permanent Racial Cap Bonuses (`GS.Data.Tables.PermanentCapRacials`)

```lua
GS_PermanentCapRacials = {
  HUMAN = {
    EXPERTISE = {
      bonus = 3,
      subTypes = {
        ["SWORDS"] = true,
        ["ONE-HANDED SWORDS"] = true,
        ["TWO-HANDED SWORDS"] = true,
        ["MACES"] = true,
        ["ONE-HANDED MACES"] = true,
        ["TWO-HANDED MACES"] = true,
      },
    },
  },
  ORC = {
    EXPERTISE = {
      bonus = 5,
      subTypes = {
        ["AXES"] = true,
        ["ONE-HANDED AXES"] = true,
        ["TWO-HANDED AXES"] = true,
        ["FIST WEAPONS"] = true,
      },
    },
  },
}
```

These racials are applied only when the currently equipped weapon subtype matches the racial rule.
