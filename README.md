# GearScore2 Overview

[![The San Juan Mountains are beautiful](/docs/GearScore2_character_tooltip.png "San Juan Mountains")](docs/GearScore2_character_tooltip.png)

## Intro

GearScore2 is a hobby project.

This addon is the successor to `GearScoreLite: Reborn` (https://github.com/Arcitec/GearScoreLite_Reborn).

> [!IMPORTANT]
> `GearScore2` may conflict with the original `GearScore` addon and with related forks such as `GearScoreLite` and `GearScoreLite: Reborn`.
> `GearScore2` includes conflict detection for other GearScore-family addons, but it is still strongly recommended to disable the others completely.
> Run only one addon from that family at a time, because overlapping tooltip hooks, slash commands, globals, or UI elements can cause duplicate lines, inconsistent values, or other unexpected behavior.

I am fully aware that the chance of the wider WoW 3.3.5a community abandoning classic `GearScore` and migrating to `GS2` is probably very small, even if that would be the dream outcome.

That is not really the main point.

This addon is first and foremost a functional proof of concept: an attempt to show that a gear score can be made much more intelligent, more spec-aware, and more useful than the original item-level-heavy model.

It still needs polishing. Some weights, thresholds, cap profiles, and edge cases will continue to evolve. But even in this relatively early state, `GearScore2` already outperforms the original `GearScore` in many practical situations:

- it understands spec compatibility,
- it rewards relevant gems and enchants,
- it devalues PvP stats for PvE,
- it notices wasted overcap stats,
- it gives a more realistic picture of actual PvE gear quality.

If you ever felt that classic `GearScore` was too easy to game, too shallow, or too disconnected from how characters really perform, this addon is worth trying.

You should treat `GS2` as an evolving system rather than a finished standard, but it is already useful, already playable, and already strong enough to compare against the old model in real gear decisions.

## GearScore2 vs Legacy GearScore

| Area | GearScore2 | Legacy GearScore |
|---|---|---|
| Main goal | PvE usefulness | Item-level-style gear estimate |
| Base math | Starts from legacy base, then adjusts | Pure legacy formula |
| Class/spec aware | Yes | No |
| Off-spec filtering | Yes | No |
| Stat weights | Yes, per spec | No |
| Gems | Matching gems add score | Ignored |
| Enchants | Matching enchants add score | Ignored |
| Missing gem/enchant | `+0`, no direct penalty | Ignored |
| PvP `Resilience` in PvE | Reduces score through multiplier | Ignored |
| Character stat caps | Yes, for final character `GS2` | No |
| Overcap waste handling | Yes | No |
| Same item for different specs | Can score differently | Mostly same outcome |
| Best use | PvE gearing quality | Fast rough comparison |

[![The San Juan Mountains are beautiful](/docs/GearScore2_item_tooltip.png "San Juan Mountains")](docs/GearScore2_item_tooltip.png)

## Table of Contents

- [1. Purpose](#1-purpose)
- [2. What GearScore2 Measures](#2-what-gearscore2-measures)
- [3. Core GearScore2 Rules](#3-core-gearscore2-rules)
- [4. Character Cap Logic](#4-character-cap-logic)
- [5. Practical Reading Guide](#5-practical-reading-guide)

## 1. Purpose

This document is a shortened overview of the scoring model, focused on the most important behavior of `GearScore2` and how it differs from `Legacy GearScore`.

Use this file when you want the high-level logic without the full implementation detail from:

- [GS_ALGORITHM.md](docs/GS_ALGORITHM.md)
- [GS_RUNTIME_TABLES.md](docs/GS_RUNTIME_TABLES.md)

## 2. What GearScore2 Measures

`GearScore2` is the PvE-oriented score.

It starts from the old item-level-based `Legacy GearScore`, then adjusts the result using gameplay-aware rules:

- class and specialization compatibility,
- weighted PvE stats,
- gems,
- enchants,
- PvE treatment of `Resilience`,
- character-level cap awareness for important PvE stats.

The goal is to score how useful a character's gear is for real PvE performance, not just how high the item level looks.

## 3. Core GearScore2 Rules

### 3.1 Legacy base still matters

Each item still begins with the old legacy base derived from:

- item level,
- rarity,
- slot modifier.

This means higher-ilvl gear still matters, but it is no longer the only thing that matters.

### 3.2 Off-spec and obviously wrong gear is rejected

Items can be ignored by `GearScore2` if they are clearly wrong for the class/spec, for example:

- lower-than-expected armor class,
- wrong role category,
- caster-style item on a melee profile,
- melee-style item on a caster profile.

This is one of the biggest differences from `Legacy GearScore`.

### 3.3 Stats are weighted per spec

Each specialization has its own PvE stat profile.

Examples:

- Assassination values `AGI`, `HIT`, `EXPERTISE`, `HASTE`
- tanks value `DEFENSE`, avoidance stats, and other tank-specific defenses
- casters value `SP`, `HIT`, `HASTE`, and spec-specific secondaries

Because of this, the same item can score differently for different specs.

### 3.4 Gems and enchants can help, but do not punish by themselves

Current runtime behavior:

- a matching gem adds score,
- a matching enchant adds score,
- a non-matching gem gives `+0`,
- a non-matching enchant gives `+0`,
- a missing gem gives `+0`,
- a missing enchant gives `+0`.

Explain tooltip behavior:

- `STA` is treated as a universal baseline stat and does not create gem/enchant mismatch flags by itself
- tank-only defenses such as `DEFENSE`, `DODGE`, `PARRY`, `BLOCK`, and `BLOCKVALUE` still create mismatch flags outside tank profiles

So GearScore2 does not punish empty or bad enhancements directly; it simply refuses to reward them.

### 3.5 Resilience lowers PvE value

`Resilience` is not handled as a flat penalty.

Instead, for PvE it reduces the item result through a multiplier:

- more `Resilience` means lower final PvE value,
- but the item is not automatically worth `0`.

That makes PvP items look worse for PvE than equivalent PvE items, without completely breaking the score.

## 4. Character Cap Logic

The biggest addition on top of item scoring is the character-level cap layer.

This applies only to final character `GearScore2`, not to individual item tooltip scores.

### 4.1 Why it exists

Some stats are extremely valuable until a cap, then much less valuable after that.

Examples:

- `HIT`
- `EXPERTISE`
- `DEFENSE`
- `ARP`

Without cap logic, a character can appear stronger simply by stacking too much of a stat that has already passed the useful threshold.

### 4.2 How the cap layer works

After all item `GearScore2` values are summed, the addon:

1. aggregates total character stats from gear, gems, and scoreable enchants,
2. resolves the active PvE spec profile,
3. measures progress toward important stat caps,
4. adds a progress-based bonus to final character `GearScore2`.

For inspected targets this spec resolution is asynchronous, but it no longer waits for inspected talent data.

- while item data is still loading, character and item tooltips show `Scanning...`
- once the inspect snapshot is ready, the addon infers the most likely specialization from the full gear setup
- inferred inspect results are marked as `[INFERRED]`

### 4.3 Progress model

Cap-aware stats are converted into progress values instead of an overflow penalty curve.

Runtime idea:

- each active cap contributes `0..100%` progress,
- overcap is clamped to `100%`,
- the character gets the average progress across all active caps,
- that average scales a max cap bonus that shrinks as pre-cap `GS2` rises.

Current anchors:

- around `4000` pre-cap `GS2`: max bonus about `200`
- around `5000` pre-cap `GS2`: max bonus about `100`
- final bonus is clamped to the runtime min/max window

### 4.4 Important runtime semantics

- overcap does not reduce cap progress below `100%`
- rogue `HIT` progress uses poison cap (`17% spell hit`) rather than stopping at the `8%` melee special cap
- `Legacy GearScore` does not use cap logic.
- `PvP GearScore` does not use cap logic.

### 4.5 Buff-aware behavior

If runtime can actually read live auras, cap thresholds can change.

Current examples:

- `Heroic Presence` can reduce required hit
- `Misery` on the current target can reduce required spell-hit for the player
- cap lines affected by such live aura help are marked with a small star icon

The addon does not assume invisible raid debuffs by default. If runtime cannot read them, they are not counted.

## 5. Practical Reading Guide

In practice, `GearScore2` should be read like this:

- high `GearScore2` means the gear is not only high ilvl, but also appropriate and efficient for PvE,
- low `GearScore2` relative to legacy often means the character has:
  - wrong-role items,
  - PvP pieces,
  - weak gem/enchant choices,
  - too much wasted capped stat,
- strong `Legacy GearScore` but weaker `GearScore2` usually means “high item level, lower real PvE efficiency”.

If you need the exact formulas, thresholds, or spec tables, use:

- [GS_ALGORITHM.md](docs/GS_ALGORITHM.md)
- [GS_RUNTIME_TABLES.md](docs/GS_RUNTIME_TABLES.md)
