# AGENTS.md

## Purpose

This file is the persistent default guidance for Codex and similar coding agents working in this repository.

Use it as the first-reference project brief for future sessions. Follow it by default, but explicit user instructions override it when they intentionally ask for something different.

## Project Identity

- This repository contains a World of Warcraft 3.3.5a addon targeting Interface `30300`.
- The current addon branding is `GearScore2`.
- The project is a hobby addon focused on building a smarter alternative to classic `GearScore`, not a strict reimplementation of it.
- The main product goal is practical usefulness: a score that is more spec-aware, explainable, and PvE-relevant than the original item-level-heavy model.
- `GearScore2` is an evolving system. Weights, thresholds, cap profiles, and edge-case handling may continue to change as the addon improves.

## Core Product Assumptions

- Preserve the distinction between the three score families:
  - `GearScore2` for PvE-oriented intelligent scoring,
  - `Legacy GearScore` for the classic-style baseline,
  - `PvP GearScore` for PvP-oriented scoring.
- Treat these as core design pillars unless the user explicitly asks to change them:
  - spec awareness,
  - item compatibility checks,
  - weighted PvE stat evaluation,
  - gem and enchant reward logic,
  - PvE vs PvP differentiation,
  - character-level cap awareness.
- Prefer changes that improve realism, interpretability, and practical decision value over changes that merely add complexity.
- Keep user-facing naming and terminology consistent across code, docs, tooltips, and UI unless a rename or wording sweep is explicitly requested.

## Sources Of Truth

- Read existing code and docs before making assumptions.
- Treat these documents as the primary written references for scoring behavior:
  - `README.md` for the high-level model / GitHub-facing overview,
  - `docs/GS_ALGORITHM.md` for the implemented scoring logic,
  - `docs/GS_RUNTIME_TABLES.md` for runtime constants, tables, and profiles.
- `docs/GS_ALGORITHM.md` is intended to match the current runtime behavior exactly. If implementation changes materially alter scoring behavior, update the relevant docs so they stay aligned.

## Repo Shape

- The addon is intentionally split into focused files such as:
  - `core.lua`,
  - `item_logic.lua`,
  - `score_logic.lua`,
  - `inspect_logic.lua`,
  - `tooltip_logic.lua`,
  - `ui.lua`.
- Prefer extending this modular structure rather than collapsing logic back into a monolithic file.
- Keep formulas, lookup tables, and runtime scoring data explicit and easy to audit.

## Working Defaults For The Agent

- Inspect existing code paths and docs first, then change the smallest reasonable surface area.
- Prefer targeted edits that preserve current behavior unless the user asks for a behavioral change.
- When changing scoring logic:
  - verify how the current runtime works first,
  - cross-check the implementation against the docs,
  - update docs when the behavior meaningfully changes.
- When changing UI, tooltip text, or labels:
  - preserve readability,
  - preserve consistency with the current addon tone and terminology,
  - avoid silent wording drift between the UI and the docs.
- Favor deterministic, readable logic over clever abstractions.
- Add comments only when they help explain non-obvious scoring behavior or tricky runtime constraints.

## Validation Expectations

- For scoring or runtime logic changes, verify the affected code paths and confirm that docs still describe the behavior accurately.
- For documentation or naming changes, ensure terminology stays aligned across the repo.
- For broader behavior changes, summarize the expected impact on:
  - `GearScore2`,
  - `Legacy GearScore`,
  - `PvP GearScore`.

## Decision Defaults

- If a prompt is ambiguous, infer from the current project direction before asking follow-up questions.
- Do not silently rewrite project identity, terminology, formulas, or score semantics.
- If a requested change would create tension between implementation and documentation, resolve both in the same task whenever practical.
