# GearScoreAI Algorithm Specification

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

For inspected units, `GS_DetectSpec(classToken, inspect)`:

1. reads 3 talent tabs through `GetTalentTabInfo(tab, inspect, false)`
2. chooses the tab with the highest point count
3. maps the winning tab to `GS_ClassSpecOrder[classToken][tab]`
4. falls back to `GS_ClassDefaults[classToken]`

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
pveStatBonus = floor(pveStatRaw * 0.12)
pvpStatBonus = floor(pvpStatRaw * 0.12)
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
  - normalized item entries
  - average item level
  - fingerprint composed from GUID, class, spec, and item links

### 9.2 Final Character Record

`GS_BuildRecord(snapshot)` sums per-item scores:

```text
gs2 = sum(itemGS2)
legacy = sum(itemLegacy)
pvp = sum(itemPvp)
```

Then stores:

```text
record.gs2 = floor(gs2)
record.legacy = floor(legacy)
record.pvp = floor(pvp)
```

`detailLinks[slotId]` stores the exact link used by tooltip details.

### 9.3 Average Item Level

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

## 11. Enchant Data Semantics

`enchant_data.lua` is generated from WotLKDB enchant pages.

### 11.1 `kind = "stats"`

This means the dataset currently exposes at least one static stat payload that runtime can score.

### 11.2 `kind = "special"`

This means the enchant is recognized, but runtime does not have a usable static stat payload for scoring.

Examples of effects that often fall into this class:

- procs
- triggered spells
- weapon chains
- special movement or utility effects

### 11.3 `special = true`

This is a supplemental marker meaning the source page exposed mixed or special behavior in addition to any extracted static stats.

Runtime behavior does **not** suppress scoring when:

- `kind = "stats"`
- and `stats` exist

In that case the static stats are scored, even if `special = true`.

### 11.4 Unknown Enchant

An enchant is treated as `unknown` only when:

- an `enchantId` exists on the item,
- but no matching entry exists in `GS_EnchantValues`.

## 12. Worked Examples

### 12.1 Example A: PvE Melee Item With Matching Stats

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

### 12.2 Example B: Matching Gem

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

### 12.3 Example C: Non-Matching Gem

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

### 12.4 Example D: Recognized Stat Enchant

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

### 12.5 Example E: Special Enchant

Enchant:

```text
enchantInfo = { kind = "special", label = "Blood Draining" }
```

Runtime result:

```text
Enchant bonus = 0
```

The enchant is recognized, but not statically scored.

### 12.6 Example F: PvP Item With Resilience

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

### 12.7 Example G: Rejected Item

If `GS_IsItemCompatible(...)` returns `false`:

```text
GearScore2 = 0
PvP GearScore = 0
Legacy GearScore = unchanged legacy base logic
```

## 13. Runtime Limitations to Keep in Mind

- explain tooltip top-stat lists are limited to 4 entries
- top-stat lists only use base item stats
- gem fallback only supports selected common single-stat gem names
- generated enchant data may contain mixed entries where static stats are only partially exposed
- character scores depend on inspect availability for non-player units

## 14. Appendix Reference

The following runtime tables are documented in `docs/GS_RUNTIME_TABLES.md`:

- global scoring constants
- legacy slot modifiers
- legacy formula tables
- enchantable slots
- armor rank order
- class defaults
- full PvE/PvP specialization profiles
