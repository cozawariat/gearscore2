# Changelog

All notable changes to this project should be documented in this file.

The release script reads version sections in the format `## [vX.Y.Z] - YYYY-MM-DD`.

## [Unreleased]

- Update this section while preparing the next release.

## [v1.2.0] - 2026-04-07

- Rounded PvE gem bonuses up for cap-relevant matched stats when the resolved spec actively uses that cap pool.
- Added explain tooltip settings to hide zero-contribution rows by default and optionally suppress neutral resilience multiplier lines.
- Updated explain tooltip rendering to filter zero-score parts and top-stat entries for cleaner item breakdowns.
- Synced the algorithm docs and offline benchmark parity logic with the new gem rounding behavior.

## [v1.1.0] - 2026-04-05

- Refactored `GearScore2` into clearer runtime and UI modules for better structure and maintainability.
- Expanded active and inferred spec detection, settings, and tooltip presentation.
- Improved off-spec diagnostics and tooltip readability.
- Recalibrated scoring profiles and weights for better PvE consistency.
- Cleaned up and updated runtime tables, gem/enchant data, and algorithm documentation.
