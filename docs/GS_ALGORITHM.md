# GearScoreAI Algorithm Specification

## Table of Contents

- [1. Purpose](#1-purpose)
- [2. Runtime Sources of Truth](#2-runtime-sources-of-truth)
- [3. Outputs](#3-outputs)
  - [3.1 Legacy GearScore](#31-legacy-gearscore)
  - [3.2 GearScore2](#32-gearscore2)
  - [3.3 PvP GearScore](#33-pvp-gearscore)
- [4. Data Normalization Pipeline](#4-data-normalization-pipeline)
  - [4.1 Item Link Parsing](#41-item-link-parsing)
  - [4.2 Base Item Data](#42-base-item-data)
  - [4.3 Base Stats](#43-base-stats)
  - [4.4 Gem Data](#44-gem-data)
  - [4.5 Enchant Data](#45-enchant-data)
- [5. Legacy GearScore Exact Formula](#5-legacy-gearscore-exact-formula)
  - [5.1 Legacy Base Computation](#51-legacy-base-computation)
  - [5.2 Quality Normalization](#52-quality-normalization)
  - [5.3 Formula Selection](#53-formula-selection)
  - [5.4 Hunter Legacy Exception](#54-hunter-legacy-exception)
- [6. Profile Resolution](#6-profile-resolution)
  - [6.1 Spec Selection](#61-spec-selection)
  - [6.2 Inspect-Side Spec Detection](#62-inspect-side-spec-detection)
- [7. Item Compatibility Rules](#7-item-compatibility-rules)
- [8. GearScore2 and PvP GearScore Exact Item Algorithm](#8-gearscore2-and-pvp-gearscore-exact-item-algorithm)
  - [8.1 Start Value](#81-start-value)
  - [8.2 Base Item Stat Bonus](#82-base-item-stat-bonus)
  - [8.3 Gem Bonus](#83-gem-bonus)
  - [8.4 Enchant Bonus](#84-enchant-bonus)
  - [8.5 Pre-Multiplier Base](#85-pre-multiplier-base)
  - [8.6 Resilience Multiplier](#86-resilience-multiplier)
- [9. Character Score Aggregation](#9-character-score-aggregation)
  - [9.1 Snapshot Collection](#91-snapshot-collection)
  - [9.2 Base Character Totals Before Caps](#92-base-character-totals-before-caps)
  - [9.3 Character-Level Cap Layer](#93-character-level-cap-layer)
  - [9.4 Character Stat Aggregation](#94-character-stat-aggregation)
  - [9.5 Cap Context](#95-cap-context)
  - [9.6 Segment Model](#96-segment-model)
  - [9.7 Threshold Resolution](#97-threshold-resolution)
  - [9.8 What the Runtime Currently Models](#98-what-the-runtime-currently-models)
  - [9.9 Final Character Record](#99-final-character-record)
  - [9.10 Average Item Level](#910-average-item-level)
- [10. Explain Tooltip Semantics](#10-explain-tooltip-semantics)
- [11. Character Cap UI Semantics](#11-character-cap-ui-semantics)
- [12. Enchant Data Semantics](#12-enchant-data-semantics)
  - [12.1 `kind = "stats"`](#121-kind--stats)
  - [12.2 `kind = "special"`](#122-kind--special)
  - [12.3 `special = true`](#123-special--true)
  - [12.4 Unknown Enchant](#124-unknown-enchant)
- [13. Worked Examples](#13-worked-examples)
  - [13.1 Example A: PvE Melee Item With Matching Stats](#131-example-a-pve-melee-item-with-matching-stats)
  - [13.2 Example B: Matching Gem](#132-example-b-matching-gem)
  - [13.3 Example C: Non-Matching Gem](#133-example-c-non-matching-gem)
  - [13.4 Example D: Recognized Stat Enchant](#134-example-d-recognized-stat-enchant)
  - [13.5 Example E: Special Enchant](#135-example-e-special-enchant)
  - [13.6 Example F: PvP Item With Resilience](#136-example-f-pvp-item-with-resilience)
  - [13.7 Example G: Rejected Item](#137-example-g-rejected-item)
- [14. Runtime Limitations to Keep in Mind](#14-runtime-limitations-to-keep-in-mind)
- [15. Appendix Reference](#15-appendix-reference)

## 1. Purpose

This document describes the runtime scoring behavior of the addon exactly as implemented in the current codebase.

The addon exposes three score families:

- `Legacy GearScore`
- `GearScore2`
- `PvP GearScore`

The goal of this document is to explain every step required to reproduce the final score shown by the addon for:

- a single item,
- a fully equipped character,
- the item explanation tooltip shown on `CTRL`.

This document is normative for the current runtime. If the code changes, this document must be updated to match it.

## 2. Runtime Sources of Truth

The current runtime behavior is defined by the following files:

- `core.lua`
- `item_logic.lua`
- `score_logic.lua`
- `inspect_logic.lua`
- `tooltip_logic.lua`
- `informationLite.lua`
- `enchant_data.lua`

`enchant_data.lua` is generated from WotLKDB and loaded before scoring modules.

## 3. Outputs

### 3.1 Legacy GearScore

`Legacy GearScore` is the legacy item-level-based score. It is driven by:

- item rarity,
- item level,
- slot modifier,
- legacy formula tables.

It does not use:

- class/spec weight profiles,
- gem weighting,
- enchant weighting,
- resilience multipliers.

### 3.2 GearScore2

`GearScore2` is the PvE-oriented score. It uses:

- the legacy base as its starting point,
- class/spec compatibility rules,
- PvE stat weights,
- gem bonuses,
- enchant bonuses,
- a PvE resilience multiplier.

For characters only, it also uses:

- a character-level cap adjustment layer applied after all item scores are summed,
- aggregated character stats from gear, gems, and scoreable enchants,
- spec-specific cap profiles for `HIT`, `EXPERTISE`, `DEFENSE`, and `ARP`,
- visible live aura modifiers when runtime can read them.

### 3.3 PvP GearScore

`PvP GearScore` is the PvP-oriented score. It uses:

- the legacy base as its starting point,
- the same class/spec compatibility rules,
- PvP stat weights,
- gem bonuses under PvP weights,
- enchant bonuses under PvP weights,
- a PvP resilience multiplier.

## 4. Data Normalization Pipeline

### 4.1 Item Link Parsing

`GS_ParseItemLink(itemLink)` extracts:

- `enchantId` from item link field 3,
- up to 4 gem IDs from item link fields 4-7.

The parsed result is cached in `GS_ParsedLinkCache`.

### 4.2 Base Item Data

`GS_GetItemData(itemLink)` builds a normalized runtime item object with:

- `link`
- `name`
- `rarity`
- `level`
- `type`
- `subType`
- `equipLoc`
- `slot`
- `legacyBase`
- `stats`
- `socketCount`
- `gemCount`
- `gemStats`
- `enchantId`
- `hasEnchant`
- `enchantInfo`
- `resilience`
- `armorRank`

The normalized item object is cached in `GS_ItemCache`.

### 4.3 Base Stats

`GS_GetNormalizedStats(itemLink)` reads `GetItemStats(itemLink)` and converts Blizzard stat keys into short runtime keys:

- `STR`
- `AGI`
- `STA`
- `INT`
- `SPI`
- `AP`
- `RAP`
- `SP`
- `HIT`
- `CRIT`
- `HASTE`
- `RESILIENCE`
- `ARP`
- `EXPERTISE`
- `DEFENSE`
- `DODGE`
- `PARRY`
- `BLOCK`
- `BLOCKVALUE`
- `MP5`

Socket placeholders such as `EMPTY_SOCKET_RED` are counted into `socketCount` and are not treated as item stats.

### 4.4 Gem Data

For each gem slot from 1 to 4:

1. The gem ID is read from the parsed item link.
2. The runtime attempts to resolve the gem link and normalize its stats.
3. If gem stat resolution fails or returns an empty stat set, a name-based fallback is used for common single-stat gems:
   - `Rigid` -> `HIT`
   - `Delicate` -> `AGI`
   - `Bold` -> `STR`
   - `Bright` -> `INT`
   - `Solid` -> `STA`
   - `Runed` -> `SP`
   - `Quick` -> `HASTE`
   - `Smooth` -> `CRIT`
   - `Fractured` -> `ARP`
   - `Precise` -> `EXPERTISE`

The gem fallback uses:

- `20` for epic quality gems,
- `16` otherwise,
- except `Runed`, which uses `SP = amount * 1.15`.

### 4.5 Enchant Data

Enchant data is resolved through `GS_EnchantValues[enchantId]` from `enchant_data.lua`.

Entry shape:

- `kind = "stats"` means the entry has static stat payload in `stats`.
- `kind = "special"` means the enchant is recognized but does not expose scoreable static stats in the runtime dataset.
- `special = true` means the source page included mixed or special effects in addition to any extracted static stats.

Runtime helpers:

- `GS_GetEnchantInfo(item)` returns the full enchant entry.
- `GS_GetEnchantStats(item)` returns `enchantInfo.stats` when present.

## 5. Legacy GearScore Exact Formula

### 5.1 Legacy Base Computation

`GS_CalculateLegacyBase(itemLink)` computes the legacy base score from:

- item rarity,
- item level,
- slot modifier,
- quality scale,
- `GS_Formula`,
- `GS_ItemTypes`.

### 5.2 Quality Normalization

Before legacy score math:

- rarity `5` is downgraded to `4` and multiplied by `qualityScale = 1.3`
- rarity `1` or `0` is normalized to rarity `2` and multiplied by `qualityScale = 0.005`
- rarity `7` is normalized to rarity `3` and item level `187.05`

### 5.3 Formula Selection

If `itemLevel > 120`, use `GS_Formula.A`, else use `GS_Formula.B`.

For an eligible item:

```text
score = floor(
    ((itemLevel - tableRef[itemRarity].A) / tableRef[itemRarity].B)
    * GS_ItemTypes[itemEquipLoc].SlotMOD
    * 1.8618
    * qualityScale
)
```

If the result is negative, it is clamped to `0`.

### 5.4 Hunter Legacy Exception

`GS_GetHunterLegacy(slotId, item)` modifies legacy scoring for hunters:

- slot `16` -> `floor(item.legacyBase * 0.3164)`
- slot `18` with ranged/rangedright -> `floor(item.legacyBase * 5.3224)`
- all other slots -> unchanged

## 6. Profile Resolution

### 6.1 Spec Selection

`GS_GetProfile(classToken, specKey)` resolves the active profile as:

1. use `specKey` if it exists in `GS_SpecProfiles`
2. otherwise use `GS_ClassDefaults[classToken]`

### 6.2 Inspect-Side Spec Detection

For the local player, `GS_DetectSpec(unit, classToken, inspect)`:

1. reads 3 talent tabs through `GetTalentTabInfo(tab, inspect, false)`
2. chooses the tab with the highest point count once point values are available
3. maps the winning tab to `GS_ClassSpecOrder[classToken][tab]`

For inspected non-player units, the runtime does not wait for inspected talent data.

- it first gathers an inspect snapshot of equipped items
- then it evaluates all candidate specs for that class against the observed gear
- it selects the highest-scoring candidate and marks the result as inferred

If the inspect snapshot itself is still incomplete, the target remains in `Scanning...` until the timeout window is reached.

## 7. Item Compatibility Rules

`GS_IsItemCompatible(item, classToken, profile)` returns `false` when any of the following runtime conditions is met:

- item is missing
- profile is missing
- item slot is `0`
- item armor class is below the target armor class for most armor slots
- item is a shield and the profile does not use shields
- item is a holdable and the profile is neither caster nor healer
- item is ranged/rangedright/thrown and the profile is not ranged
- hunter is trying to use shield or holdable
- a caster/healer item is treated as invalid when it has `STR` but no `SP` and no `INT`
- a melee/ranged item is treated as invalid when it has `SP` but no `STR`, `AGI`, `AP`, or `RAP`

If compatibility fails:

- `GearScore2 = 0`
- `PvP GearScore = 0`
- explain tooltip emits an offspec/incompatible-item flag

`Legacy GearScore` is not filtered by this compatibility logic.

## 8. GearScore2 and PvP GearScore Exact Item Algorithm

The following algorithm is implemented in `GS_ScoreItem(item, classToken, specKey, wantExplain)`.

### 8.1 Start Value

```text
pveScore = item.legacyBase
pvpScore = item.legacyBase
```

### 8.2 Base Item Stat Bonus

Raw stat-weight sums:

```text
pveStatRaw = GS_ScoreStats(item.stats, profile.pve)
pvpStatRaw = GS_ScoreStats(item.stats, profile.pvp)
```

Bonuses:

```text
pveStatBonus = floor(pveStatRaw * GS_GS2_STAT_SCALE)
pvpStatBonus = floor(pvpStatRaw * GS_GS2_STAT_SCALE)
```

Applied as:

```text
pveScore = pveScore + pveStatBonus
pvpScore = pvpScore + pvpStatBonus
```

### 8.3 Gem Bonus

For each gem slot `1..4`:

- if normalized gem stats exist:

```text
gemPveRaw = GS_ScoreStats(item.gemStats[index], profile.pve)
gemPvpRaw = GS_ScoreStats(item.gemStats[index], profile.pvp)

gemPveBonus = floor(gemPveRaw * GS_GEM_SCALE) only if gemPveRaw > 0 else 0
gemPvpBonus = floor(gemPvpRaw * GS_GEM_SCALE) only if gemPvpRaw > 0 else 0
```

- if the socket exists but no gem is present:

```text
bonus = 0
```

Important runtime rule:

- a bad or non-matching gem never applies a penalty
- it only yields `+0`
- explain mismatch flags ignore `STA` by itself
- explain mismatch flags still trigger for tank-only defenses outside matching tank profiles

### 8.4 Enchant Bonus

If the item slot is enchantable and `item.hasEnchant` is true:

```text
enchantInfo = GS_GetEnchantInfo(item)
enchantStats = enchantInfo and enchantInfo.stats or nil

pveEnchantRaw = GS_ScoreStats(enchantStats, profile.pve)
pvpEnchantRaw = GS_ScoreStats(enchantStats, profile.pvp)

pveEnchant = floor(pveEnchantRaw * GS_ENCHANT_SCALE) only if pveEnchantRaw > 0 else 0
pvpEnchant = floor(pvpEnchantRaw * GS_ENCHANT_SCALE) only if pvpEnchantRaw > 0 else 0
```

Runtime cases:

- `kind = "stats"` with static stats:
  - score normally
  - if weights do not match the profile, result is `+0`
  - explain mismatch flags ignore `STA` by itself, but not tank-only defenses
- `kind = "special"`:
  - recognized enchant
  - runtime gives `+0`
- missing lookup:
  - runtime gives `+0`
  - explain tooltip labels it as `unknown enchant`

If the slot is enchantable but no enchant exists:

- runtime gives `+0`
- no penalty is applied

### 8.5 Pre-Multiplier Base

After base stats, gems, and enchant:

```text
pveBaseScore = max(0, pveScore)
pvpBaseScore = max(0, pvpScore)
```

### 8.6 Resilience Multiplier

`GS_GetResilienceMultiplier(resilience, mode)`:

PvE:

```text
if resilience <= 0:
    pveMultiplier = 1
else:
    pveMultiplier = max(GS_PVE_RESILIENCE_FLOOR, 1 - resilience * GS_PVE_RESILIENCE_RATE)
```

PvP:

```text
if resilience <= 0:
    pvpMultiplier = 1
else:
    pvpMultiplier = min(GS_PVP_RESILIENCE_CAP, 1 + resilience * GS_PVP_RESILIENCE_RATE)
```

Final item scores:

```text
GearScore2(item) = floor(pveBaseScore * pveMultiplier)
PvP GearScore(item) = floor(pvpBaseScore * pvpMultiplier)
```

## 9. Character Score Aggregation

### 9.1 Snapshot Collection

`GS_CollectSnapshot(unit, inspect)`:

- reads all inventory slots `1..18`
- skips slot `4` (`shirt`)
- normalizes each item
- collects:
  - `classToken`
  - `specKey`
  - `specResolved`
  - `specSource`
  - normalized item entries
  - average item level
  - fingerprint composed from GUID, class, spec, and item links

### 9.2 Base Character Totals Before Caps

`GS_BuildRecord(snapshot)` sums per-item scores:

```text
gs2 = sum(itemGS2)
legacy = sum(itemLegacy)
pvp = sum(itemPvp)
```

When `specResolved` is false:

- `legacy` is still built normally
- `GearScore2` is withheld
- cap logic is skipped
- the record exposes scan-state metadata so tooltips can show `Scanning...` or `Spec: Unknown`

At this stage:

- `legacy` is already final,
- `pvp` is already final,
- `gs2` is only the pre-cap total.

### 9.3 Character-Level Cap Layer

After the per-item sums are built, `GS_BuildRecord(snapshot)` calls:

```text
capAdjustedGs2, capBreakdown, capStats = GS_ApplyCharacterCaps(snapshot)
gs2 = gs2 + capAdjustedGs2
```

This layer affects only final character `GearScore2`.

It does **not** affect:

- item tooltip `GearScore2`,
- `Legacy GearScore`,
- `PvP GearScore`.

### 9.4 Character Stat Aggregation

`GS_ApplyCharacterCaps(snapshot)` first aggregates total character stats through `GS_CollectSnapshotStats(snapshot)`.

The stat pool is built from:

- `item.stats`
- all normalized gem stats in `item.gemStats`
- enchant stats from `GS_GetEnchantStats(item)` when present

The cap layer does not read:

- temporary proc effects,
- unsupported special enchants,
- hidden target assumptions,
- manually assumed raid debuffs.

### 9.5 Cap Context

`GS_GetCapContext(unit, specKey)` builds a runtime context containing:

- `meleeHitBonus`
- `spellHitBonus`
- `targetSpellHitBonus`
- `expertiseBonus`
- `defenseSkillBonus`

The context starts from spec-defined passive bonuses in `GS_CapProfiles`.

Then runtime adds live aura bonuses when it can actually read them from the unit.

Important runtime rule:

- live helpful buffs are only counted when `UnitExists(unit)` and `UnitIsVisible(unit)` are true
- target debuffs are only counted for the player and only when the current target actually has the debuff
- there is no hidden assumption that common raid debuffs are always present

### 9.6 Progress Model

Every cap-aware stat pool resolves to one progress target.

For each pool:

1. runtime reads the full pool value from aggregated character stats
2. runtime picks a single progress target for that pool
3. runtime resolves that target into rating-space
4. pool progress is `clamp(statValue / targetThreshold, 0, 1)`
5. character cap progress is the average of all active pool progresses
6. final cap bonus is the average progress multiplied by a pre-cap-`GS2` ceiling

Core algorithm:

```text
for each active pool:
    targetThreshold = resolved target threshold in rating space
    poolProgress = clamp(statValue / targetThreshold, 0, 1)

overallProgress = average(poolProgress for all active pools)
maxCapBonus = clamp(
    round(
        200 - 100 * (ln(preCapGs2) - ln(4000)) / (ln(5000) - ln(4000))
    ),
    25,
    300
)
capAdjustedGs2 = floor(maxCapBonus * overallProgress)
```

Important runtime details:

- overcap never reduces pool progress below `100%`
- the cap layer no longer uses overflow penalties to reduce the final bonus
- `ASSASSINATION`, `COMBAT`, and `SUBTLETY` use `17% spell hit` as their `HIT` progress target
- tank `EXPERTISE` still uses `26` as the progress target even though the pool table also contains a secondary `56` threshold

### 9.7 Threshold Resolution

Thresholds are resolved by `GS_ResolveCapThreshold(segment, context)`:

- `MELEE_HIT_PERCENT`
  - `(thresholdPercent - meleeHitBonus) * GS_RatingConversions.MELEE_HIT`
- `SPELL_HIT_PERCENT`
  - `(thresholdPercent - spellHitBonus - targetSpellHitBonus) * GS_RatingConversions.SPELL_HIT`
- `EXPERTISE_POINTS`
  - `(thresholdPoints - expertiseBonus) * GS_RatingConversions.EXPERTISE`
- `DEFENSE_SKILL`
  - `(thresholdDefenseSkill - 400 - defenseSkillBonus) * GS_RatingConversions.DEFENSE`
- `RATING`
  - raw threshold is already in rating

All resolved thresholds are clamped to at least `0`.

### 9.8 What the Runtime Currently Models

The current runtime includes progress targets for:

- melee/ranged hit caps
- spell-hit caps
- rogue poison-hit caps
- DPS expertise soft caps
- tank expertise soft caps at `26`
- tank defense `540`
- physical `ARP` hard cap `1400`

Important runtime semantics:

- overcap is clamped to full progress instead of becoming a negative cap penalty
- `Assassination`, `Combat`, and `Subtlety` do not stop `HIT` progress at the melee special cap; they progress toward poison cap
- `Legacy` and `PvP` scores do not use cap profiles

### 9.9 Final Character Record

The final cached record stores:

```text
record.gs2 = floor(gs2)
record.legacy = floor(legacy)
record.pvp = floor(pvp)
record.capAdjustedGs2 = capAdjustedGs2
record.capBreakdown = capBreakdown
record.capStats = capStats
```

`detailLinks[slotId]` stores the exact link used by tooltip details.

### 9.10 Average Item Level

Average item level is:

```text
average = floor(levelTotal / itemCount)
```

where:

- only non-empty slots are counted,
- shirt is excluded.

## 10. Explain Tooltip Semantics

The item explain tooltip is generated from `GS_ScoreItem(..., true)`.

It shows:

- final `GearScore2`
- final `Legacy GearScore`
- final `PvP GearScore`
- legacy base
- each PvE and PvP component delta
- base before resilience multiplier
- resilience multiplier
- final score after multiplier
- flags
- top 4 base-item stats by weighted contribution

Important runtime detail:

- `Top PvE stats` and `Top PvP stats` are built only from `item.stats`
- they do not include gem stats
- they do not include enchant stats
- they do not include the character-level cap layer

## 11. Character Cap UI Semantics

Character tooltip and paper doll may show a short cap summary built from `record.capBreakdown.summary`.

Current runtime summary behavior:

- active cap pools with progress above `0%` may be listed
- the total cap bonus is split proportionally by pool progress
- capped pools are labeled as `capped`
- uncapped pools are labeled by their rounded progress percent

Examples:

- `GS2 Caps: Hit capped (+82 GS2), Expertise 50% (+41 GS2)`
- `GS2 Caps: Defense capped (+67 GS2), Hit 25% (+17 GS2)`

Summary rules:

- if a pool reached its target, it is shown as `<Summary> capped (+N GS2)`
- otherwise it is shown as `<Summary> <P>% (+N GS2)`
- displayed pool bonuses are a proportional allocation of the single total cap bonus
- the displayed pool bonuses always sum back to `record.capAdjustedGs2`

## 12. Enchant Data Semantics

`enchant_data.lua` is generated from WotLKDB enchant pages.

### 12.1 `kind = "stats"`

This means the dataset currently exposes at least one static stat payload that runtime can score.

### 12.2 `kind = "special"`

This means the enchant is recognized, but runtime does not have a usable static stat payload for scoring.

Examples of effects that often fall into this class:

- procs
- triggered spells
- weapon chains
- special movement or utility effects

### 12.3 `special = true`

This is a supplemental marker meaning the source page exposed mixed or special behavior in addition to any extracted static stats.

Runtime behavior does **not** suppress scoring when:

- `kind = "stats"`
- and `stats` exist

In that case the static stats are scored, even if `special = true`.

### 12.4 Unknown Enchant

An enchant is treated as `unknown` only when:

- an `enchantId` exists on the item,
- but no matching entry exists in `GS_EnchantValues`.

## 13. Worked Examples

### 13.1 Example A: PvE Melee Item With Matching Stats

Normalized item:

```text
legacyBase = 100
item.stats = { AGI = 40, HIT = 20 }
profile = ASSASSINATION
GS_GEM_SCALE = 0.35
GS_ENCHANT_SCALE = 0.35
resilience = 0
```

PvE stat raw:

```text
(40 * 2.5) + (20 * 1.8) = 136
```

PvE stat bonus:

```text
floor(136 * 0.12) = 16
```

No gem bonus, no enchant bonus, no resilience multiplier change:

```text
preMultiplier = 100 + 16 = 116
multiplier = 1
GearScore2 = floor(116 * 1) = 116
```

### 13.2 Example B: Matching Gem

Additional gem:

```text
gemStats = { HIT = 16 }
```

PvE gem raw:

```text
16 * 1.8 = 28.8
```

PvE gem bonus:

```text
floor(28.8 * 0.35) = floor(10.08) = 10
```

### 13.3 Example C: Non-Matching Gem

Gem:

```text
gemStats = { INT = 16 }
profile = ASSASSINATION
```

PvE gem raw:

```text
0
```

PvE gem bonus:

```text
0
```

The gem gives no penalty. It simply contributes `+0`.

### 13.4 Example D: Recognized Stat Enchant

Enchant:

```text
enchantInfo = { kind = "stats", stats = { HIT = 20 } }
```

PvE enchant raw:

```text
20 * 1.8 = 36
```

PvE enchant bonus:

```text
floor(36 * 0.35) = 12
```

### 13.5 Example E: Special Enchant

Enchant:

```text
enchantInfo = { kind = "special", label = "Blood Draining" }
```

Runtime result:

```text
Enchant bonus = 0
```

The enchant is recognized, but not statically scored.

### 13.6 Example F: PvP Item With Resilience

Inputs:

```text
preMultiplierPvE = 160
preMultiplierPvP = 150
resilience = 100
GS_PVE_RESILIENCE_RATE = 0.0015
GS_PVP_RESILIENCE_RATE = 0.0020
GS_PVE_RESILIENCE_FLOOR = 0.70
GS_PVP_RESILIENCE_CAP = 1.35
```

Multipliers:

```text
pveMultiplier = max(0.70, 1 - 100 * 0.0015) = max(0.70, 0.85) = 0.85
pvpMultiplier = min(1.35, 1 + 100 * 0.0020) = min(1.35, 1.20) = 1.20
```

Finals:

```text
GearScore2 = floor(160 * 0.85) = 136
PvP GearScore = floor(150 * 1.20) = 180
```

### 13.7 Example G: Rejected Item

If `GS_IsItemCompatible(...)` returns `false`:

```text
GearScore2 = 0
PvP GearScore = 0
Legacy GearScore = unchanged legacy base logic
```

## 14. Runtime Limitations to Keep in Mind

- explain tooltip top-stat lists are limited to 4 entries
- top-stat lists only use base item stats
- gem fallback only supports selected common single-stat gem names
- generated enchant data may contain mixed entries where static stats are only partially exposed
- character scores depend on inspect availability for non-player units

## 15. Appendix Reference

The following runtime tables are documented in `docs/GS_RUNTIME_TABLES.md`:

- global scoring constants
- legacy slot modifiers
- legacy formula tables
- enchantable slots
- armor rank order
- class defaults
- full PvE/PvP specialization profiles
