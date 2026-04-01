# GearScoreAI Runtime Tables

## Table of Contents

- [1. Global Scoring Constants](#1-global-scoring-constants)
  - [1.1 Rating Conversions (`GS_RatingConversions`)](#11-rating-conversions-gs_ratingconversions)
  - [1.2 Cap Segment Defaults (`GS_CapSegmentDefaults`)](#12-cap-segment-defaults-gs_capsegmentdefaults)
  - [1.3 Live Aura Cap Modifiers (`GS_LiveCapBuffs`)](#13-live-aura-cap-modifiers-gs_livecapbuffs)
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

## 1.1 Rating Conversions (`GS_RatingConversions`)

| Conversion | Value |
|---|---:|
| `MELEE_HIT` | `32.78998947` |
| `SPELL_HIT` | `26.231992` |
| `EXPERTISE` | `8.196` |
| `DEFENSE` | `4.9185` |

## 1.2 Cap Segment Defaults (`GS_CapSegmentDefaults`)

| Multiplier | Value |
|---|---:|
| `CRITICAL` | `1.25` |
| `USEFUL` | `0.60` |
| `OVERFLOW` | `0.20` |
| `DEFENSE_OVERFLOW` | `0.55` |
| `ARP_OVERFLOW` | `0.05` |

## 1.3 Live Aura Cap Modifiers (`GS_LiveCapBuffs`)

### Helpful auras

| Spell ID | Name | Effect |
|---|---|---|
| `6562` | `Heroic Presence` | `+1% melee hit`, `+1% spell hit` |

### Harmful auras on target

| Spell ID | Name | Effect |
|---|---|---|
| `33198` | `Misery` | `+3% target spell hit bonus` |

## 2. Legacy Slot Modifiers (`GS_ItemTypes`)

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

## 3. Legacy Formula Tables (`GS_Formula`)

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

## 4. Enchantable Slots (`GS_EnchantSlots`)

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

## 5. Armor Rank Order (`GS_ArmorClassOrder`)

| Armor Type | Rank |
|---|---:|
| `CLOTH` | `1` |
| `LEATHER` | `2` |
| `MAIL` | `3` |
| `PLATE` | `4` |

## 6. Class Default Specs (`GS_ClassDefaults`)

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

## 7. Specialization Profiles (`GS_SpecProfiles`)

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
| `ARMS` | `MELEE` | `PLATE` | No | No | No | `STR 2.4, CRIT 1.5, HIT 1.8, HASTE 1.1, ARP 1.9, AP 1.2, EXPERTISE 1.4` | `STR 2.2, CRIT 1.2, HIT 0.8, HASTE 0.9, ARP 1.3, AP 1.0, RESILIENCE 2.2` |
| `FURY` | `MELEE` | `PLATE` | No | No | Yes | `STR 2.6, CRIT 1.5, HIT 1.9, HASTE 1.3, ARP 1.9, AP 1.1, EXPERTISE 1.3` | `STR 2.0, CRIT 1.0, HASTE 0.8, AP 0.9, RESILIENCE 2.2` |
| `PROTECTION` | `TANK` | `PLATE` | Yes | No | No | `STR 0.8, DEFENSE 2.8, DODGE 2.1, PARRY 2.0, BLOCK 1.7, BLOCKVALUE 1.2, HIT 1.0, EXPERTISE 1.2` | `STR 0.8, DODGE 1.4, PARRY 1.3, BLOCK 1.2, RESILIENCE 1.7` |
| `HOLY` | `HEALER` | `PLATE` | Yes | No | No | `INT 2.4, SP 2.8, HASTE 1.8, CRIT 1.3, MP5 1.5, SPI 0.4` | `INT 2.0, SP 2.4, HASTE 1.1, CRIT 0.8, MP5 0.8, RESILIENCE 2.2` |
| `RETRIBUTION` | `MELEE` | `PLATE` | No | No | No | `STR 2.6, CRIT 1.5, HIT 1.6, HASTE 1.1, EXPERTISE 1.3, AP 1.0` | `STR 2.2, CRIT 1.0, AP 0.9, RESILIENCE 2.2` |
| `BEASTMASTERY` | `RANGED` | `MAIL` | No | Yes | No | `AGI 2.5, RAP 1.4, AP 0.8, HIT 1.7, CRIT 1.5, HASTE 1.0, ARP 1.1` | `AGI 2.1, RAP 1.0, CRIT 1.0, HASTE 0.7, RESILIENCE 2.2` |
| `MARKSMANSHIP` | `RANGED` | `MAIL` | No | Yes | No | `AGI 2.6, RAP 1.3, AP 0.7, HIT 1.8, CRIT 1.6, HASTE 1.0, ARP 1.8` | `AGI 2.2, RAP 1.0, CRIT 1.0, ARP 1.0, RESILIENCE 2.2` |
| `SURVIVAL` | `RANGED` | `MAIL` | No | Yes | No | `AGI 2.7, RAP 1.2, AP 0.7, HIT 1.7, CRIT 1.4, HASTE 1.0` | `AGI 2.2, CRIT 1.0, HASTE 0.8, RESILIENCE 2.2` |
| `ASSASSINATION` | `MELEE` | `LEATHER` | No | No | Yes | `AGI 2.5, AP 1.2, HIT 1.8, HASTE 1.2, CRIT 1.3, EXPERTISE 1.4` | `AGI 2.2, AP 1.0, HASTE 0.8, CRIT 0.9, RESILIENCE 2.2` |
| `COMBAT` | `MELEE` | `LEATHER` | No | No | Yes | `AGI 2.4, AP 1.0, HIT 1.9, HASTE 1.4, CRIT 1.2, ARP 1.5, EXPERTISE 1.4` | `AGI 2.0, AP 0.9, HASTE 0.7, CRIT 0.8, RESILIENCE 2.2` |
| `SUBTLETY` | `MELEE` | `LEATHER` | No | No | Yes | `AGI 2.2, AP 1.0, HIT 1.5, HASTE 0.8, CRIT 1.2, ARP 1.0, EXPERTISE 1.1` | `AGI 2.3, AP 1.0, CRIT 1.0, RESILIENCE 2.4` |
| `DISCIPLINE` | `HEALER` | `CLOTH` | No | No | No | `INT 2.4, SP 2.7, CRIT 1.5, HASTE 1.4, MP5 1.1, SPI 0.8` | `INT 2.1, SP 2.2, CRIT 0.9, HASTE 0.8, RESILIENCE 2.4` |
| `SHADOW` | `CASTER` | `CLOTH` | No | No | No | `INT 1.7, SP 2.8, HIT 1.9, HASTE 1.7, CRIT 1.0, SPI 1.2` | `INT 1.6, SP 2.3, HASTE 1.0, CRIT 0.8, RESILIENCE 2.3` |
| `BLOOD` | `TANK` | `PLATE` | No | No | No | `STR 1.0, DEFENSE 2.8, DODGE 2.0, PARRY 2.0, HIT 0.8, EXPERTISE 1.0` | `STR 1.0, RESILIENCE 2.0` |
| `FROST` | `MELEE` | `PLATE` | No | No | Yes | `STR 2.5, HIT 1.7, HASTE 1.2, CRIT 1.2, EXPERTISE 1.3, AP 0.9` | `STR 2.2, CRIT 0.9, RESILIENCE 2.2` |
| `UNHOLY` | `MELEE` | `PLATE` | No | No | No | `STR 2.5, HIT 1.7, HASTE 1.3, CRIT 1.1, EXPERTISE 1.2, AP 1.0` | `STR 2.2, HASTE 0.8, RESILIENCE 2.2` |
| `ELEMENTAL` | `CASTER` | `MAIL` | Yes | No | No | `INT 1.7, SP 2.8, HIT 1.8, HASTE 1.6, CRIT 1.1, MP5 0.4` | `INT 1.5, SP 2.3, HASTE 0.9, CRIT 0.8, RESILIENCE 2.3` |
| `ENHANCEMENT` | `MELEE` | `MAIL` | No | No | Yes | `AGI 2.0, AP 1.2, HIT 1.8, HASTE 1.4, CRIT 1.2, EXPERTISE 1.4` | `AGI 1.8, AP 1.0, HASTE 0.9, RESILIENCE 2.2` |
| `RESTORATION` | `HEALER` | `MAIL` | Yes | No | No | `INT 2.3, SP 2.7, HASTE 1.8, CRIT 1.2, MP5 1.4, SPI 0.2` | `INT 2.0, SP 2.3, HASTE 0.9, MP5 0.7, RESILIENCE 2.3` |
| `ARCANE` | `CASTER` | `CLOTH` | No | No | No | `INT 1.9, SP 2.7, HIT 1.8, HASTE 1.5, CRIT 1.2, SPI 0.4` | `INT 1.8, SP 2.2, HASTE 0.9, CRIT 0.8, RESILIENCE 2.2` |
| `FIRE` | `CASTER` | `CLOTH` | No | No | No | `INT 1.7, SP 2.8, HIT 1.7, HASTE 1.6, CRIT 1.3, SPI 0.3` | `INT 1.6, SP 2.3, HASTE 1.0, CRIT 0.8, RESILIENCE 2.2` |
| `MAGE_FROST` | `CASTER` | `CLOTH` | No | No | No | `INT 1.7, SP 2.6, HIT 1.7, HASTE 1.3, CRIT 1.2` | `INT 1.6, SP 2.3, HASTE 0.9, CRIT 0.8, RESILIENCE 2.5` |
| `AFFLICTION` | `CASTER` | `CLOTH` | No | No | No | `INT 1.7, SP 2.8, HIT 1.8, HASTE 1.6, CRIT 1.0, SPI 0.5` | `INT 1.6, SP 2.3, HASTE 1.0, RESILIENCE 2.3` |
| `DEMONOLOGY` | `CASTER` | `CLOTH` | No | No | No | `INT 1.7, SP 2.7, HIT 1.7, HASTE 1.4, CRIT 1.1, SPI 0.4` | `INT 1.6, SP 2.2, HASTE 0.9, RESILIENCE 2.2` |
| `DESTRUCTION` | `CASTER` | `CLOTH` | No | No | No | `INT 1.7, SP 2.8, HIT 1.7, HASTE 1.5, CRIT 1.2, SPI 0.3` | `INT 1.6, SP 2.3, HASTE 0.9, CRIT 0.8, RESILIENCE 2.3` |
| `BALANCE` | `CASTER` | `LEATHER` | No | No | No | `INT 1.8, SP 2.8, HIT 1.8, HASTE 1.6, CRIT 1.1, SPI 0.5` | `INT 1.7, SP 2.2, HASTE 0.9, CRIT 0.8, RESILIENCE 2.3` |
| `FERAL` | `MELEE` | `LEATHER` | No | No | No | `AGI 2.5, AP 1.1, HIT 1.6, HASTE 1.0, CRIT 1.3, ARP 1.5, EXPERTISE 1.2` | `AGI 2.2, AP 0.9, RESILIENCE 2.3` |
| `DRUID_RESTORATION` | `HEALER` | `LEATHER` | No | No | No | `INT 2.4, SP 2.7, HASTE 1.9, CRIT 1.0, MP5 1.1, SPI 1.2` | `INT 2.0, SP 2.2, HASTE 0.9, SPI 0.7, RESILIENCE 2.4` |

## 8. Enchant Data Runtime Shape

Entries in `enchant_data.lua` use:

| Field | Meaning |
|---|---|
| `kind = "stats"` | static stat payload exists and may be scored |
| `kind = "special"` | recognized enchant with no scoreable static stats |
| `label` | human-readable enchant label |
| `stats` | normalized stat payload used by scoring |
| `special = true` | mixed or special behavior was also detected in source data |
| `unknownTraits` | source-side traits that were not normalized into runtime stat keys |

## 9. Character Cap Profiles (`GS_CapProfiles`)

Cap profiles affect only final character `GearScore2`.

Each pool is processed in order. The same stat pool is consumed progressively across its segments.

### 9.1 Melee / Physical Specs

| Spec | Pools |
|---|---|
| `ARMS` | `HIT: 8% special -> overflow`, `EXPERTISE: 26 -> overflow`, `ARP: 1400 -> overflow` |
| `FURY` | `HIT: 8% special -> overflow`, `EXPERTISE: 26 -> overflow`, `ARP: 1400 -> overflow` |
| `RETRIBUTION` | `HIT: 8% special -> overflow`, `EXPERTISE: 26 -> overflow` |
| `FROST` | `HIT: 8% special -> overflow`, `EXPERTISE: 26 -> overflow` |
| `UNHOLY` | `HIT: 8% special -> overflow`, `EXPERTISE: 26 -> overflow` |
| `FERAL` | `HIT: 8% special -> overflow`, `EXPERTISE: 26 -> overflow`, `ARP: 1400 -> overflow` |

### 9.2 Tanks

| Spec | Pools |
|---|---|
| `PROTECTION` | `DEFENSE: 540 -> reduced overflow`, `EXPERTISE: 26 -> 56 -> overflow`, `HIT: 8% special -> overflow` |
| `BLOOD` | `DEFENSE: 540 -> reduced overflow`, `EXPERTISE: 26 -> 56 -> overflow`, `HIT: 8% special -> overflow` |

### 9.3 Rogues / Enhancement Shared Progressive Hit Pool

| Spec | Pools |
|---|---|
| `ASSASSINATION` | `HIT: 8% melee special -> 17% poison/spell -> overflow`, `EXPERTISE: 26 -> overflow` |
| `COMBAT` | `HIT: 8% melee special -> 17% poison/spell -> overflow`, `EXPERTISE: 26 -> overflow`, `ARP: 1400 -> overflow` |
| `SUBTLETY` | `HIT: 8% melee special -> 17% poison/spell -> overflow`, `EXPERTISE: 26 -> overflow` |
| `ENHANCEMENT` | `HIT: 8% melee special -> 17% spell hit -> overflow`, `EXPERTISE: 26 -> overflow` |

### 9.4 Casters / Spell-Hit Specs

| Spec | Pools |
|---|---|
| `SHADOW` | `HIT: 17% spell hit -> overflow` |
| `ELEMENTAL` | `HIT: 17% spell hit -> overflow` |
| `ARCANE` | `HIT: 17% spell hit -> overflow` |
| `FIRE` | `HIT: 17% spell hit -> overflow` |
| `MAGE_FROST` | `HIT: 17% spell hit -> overflow` |
| `AFFLICTION` | `HIT: 17% spell hit -> overflow` |
| `DEMONOLOGY` | `HIT: 17% spell hit -> overflow` |
| `DESTRUCTION` | `HIT: 17% spell hit -> overflow` |
| `BALANCE` | `HIT: 17% spell hit -> overflow` |

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
