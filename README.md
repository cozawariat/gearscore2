# GearScore2 (WotLK 3.3.5a)

[![Character tooltip settings](/docs/GearScore2_character_tooltip.png "Character tooltip settings")](docs/GearScore2_character_tooltip.png)

## Intro

I am fully aware that the chance of the wider WoW 3.3.5a community abandoning classic `GearScore` and migrating to `GS2` is probably very small, even if that would be the dream outcome.

That is not really the main point.

## What It Is

`GearScore2` is a hobby addon for World of Warcraft 3.3.5a.

It is a smarter PvE-oriented alternative to classic `GearScore` / `GearScoreLite: Reborn`.

> how good is this gear for the actual class and specialization using it?

The addon is built as a practical, spec-aware scoring system rather than a strict reimplementation of older GearScore-family addons.

## Key Features

- `GearScore2`, `Legacy GearScore`, and `PvP GearScore` shown side by side for clearer comparison
- [`spec-aware`](#spec-awareness) PvE scoring instead of treating raw item level as the whole story
- [`Inferred scoring`](#inferred-scoring) as a safety mechanism for cases where the detected spec does not match the equipped gear set
- rewards for good gems and enchants instead of relying only on base item value
- PvP stat devaluation in PvE contexts
- [`stat-cap awareness`](#stat-cap-awareness), so valuable PvE stats are judged with cap progress in mind

## What It Tries To Improve

Classic `GearScore` is easy to read, but it also treats many very different items too similarly.

`GearScore2` tries to improve that by producing more realistic PvE evaluations for the actual specialization and gear set being worn, instead of collapsing everything into raw item level.

> [!CAUTION]
> - `GearScore2` may conflict with the original `GearScore` addon and related forks such as `GearScoreLite` or `GearScoreLite: Reborn`.
> - The addon includes conflict detection, but it is still strongly recommended to disable the others completely.
> - Run only one addon from that family at a time to avoid duplicate tooltip lines, conflicting hooks, or inconsistent values.

## The Three Scores

`GearScore2` shows three score families:

- `GearScore2`
  - the main PvE-oriented score
- `Legacy GearScore`
  - a familiar item-level-style baseline
- `PvP GearScore`
  - a separate PvP-oriented score

These scores are intentionally different.

`Legacy GearScore` is there as a recognizable comparison point. `GearScore2` is the addon's main product: a score meant to reflect real PvE usefulness more closely. `PvP GearScore` exists so PvP evaluation does not have to distort PvE scoring.

[![Item tooltip settings](/docs/GearScore2_item_tooltip.png "Item tooltip settings")](docs/GearScore2_item_tooltip.png)

## How To Read GearScore2

In practice:

- high `GearScore2` usually means the gear is both strong and appropriate for the spec
- high `Legacy GearScore` with weaker `GearScore2` usually means "good item level, weaker real PvE fit"
- strong PvP pieces tend to look worse in `GearScore2` than in `Legacy`
- good gems and enchants help, but missing or bad ones are mostly "not rewarded" rather than hard-punished

## Spec Awareness

The addon tries to score gear for the right specialization whenever possible.

- for the local player, it uses the talent tab with the highest point count
- for inspected targets, it tries to resolve the active spec from inspect talent data
- if that is not available in time, it can fall back to gear-based inference

The addon may therefore show both:

- an `Active` result
- an `Inferred` result

## Inferred Scoring

`Inferred` is one of the addon's most important features. It calculates a score for every spec of the character's class and, if one of them scores higher than the currently detected spec, shows it as a separate comparison.

This acts as a safety mechanism when someone forgets to switch spec or gear set, and it makes off-spec or mismatched equipment much easier to interpret.

## Stat-Cap Awareness

`GearScore2` does not treat important PvE stats as equally valuable at every point on the gear curve.

For cap-aware stats such as hit, expertise, defense, or armor penetration, the addon looks at whole-character progress toward meaningful PvE targets and adds value based on how much those caps are being meaningfully approached or satisfied.

This helps the score better distinguish between gear that only looks strong on paper and gear that is actually improving the character's real PvE readiness.

## Current Direction

`GearScore2` is not meant to be a frozen standard.

It is an evolving system focused on:

- better spec awareness
- better PvE realism
- clearer tooltip explanations
- more useful comparisons than a pure item-level score

Weights, profiles, and edge-case handling can still improve over time, but the product direction stays the same: practical usefulness first.

## Documentation Map

This README is the high-level overview of the addon.

Use the deeper docs when you need exact behavior:

- [docs/GS_ALGORITHM.md](docs/GS_ALGORITHM.md)
  - exact scoring behavior and formulas
- [docs/GS_RUNTIME_TABLES.md](docs/GS_RUNTIME_TABLES.md)
  - runtime constants, profiles, cap data, and tables
- [docs/GS_WOWHEAD_PROFILE_AUDIT.md](docs/GS_WOWHEAD_PROFILE_AUDIT.md)
  - curated Wowhead WotLK PvE archetype audit and profile notes
