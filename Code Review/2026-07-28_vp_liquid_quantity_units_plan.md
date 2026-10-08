# VP Liquid Quantity Units Plan

Date: 2026-07-28
Branch: main
Status: Complete for code tranche. This file is the source of truth for implementing VP family-aware quantity-unit behavior and preventing invalid liquid-to-weight conversion.

## Purpose

Prevent invalid VP liquid quantity conversions by making VP Trade quantity-unit choices, defaults, and conversion paths aware of volume family.

## Scope

Included:
- VP Trade quantity-unit UI choices and defaults.
- VP Trade pending-default logic safety.
- VP quantity conversion in base_data_converted.
- VP quantity conversion in filtered_vp_data_for_custom_panel.
- Quantity-unit labels for gallon units.

Excluded:
- Rollup cleanup/elimination work for mixed unit contexts.
- Non-VP source conversion logic.
- Processed artifact rebuilds.

## Decisions

- No gallon-to-weight conversion without density metadata.
- Use app-native unit tokens in runtime UI logic.
- Keep full existing app weight-unit set for VP weight-family contexts.
- Mixed-family short-run behavior: disable quantity conversion affordance and present an unavailable state.

## Step Ledger

| Step | Work | Status | Notes |
|---|---|---|---|
| 1 | Create implementation ledger | Complete | This file created before code edits. |
| 2 | Add VP runtime family resolver and family-aware unit-choice/default helpers | Complete | Implemented in [Programs/app_source/server/02_partner_and_notes.R](Programs/app_source/server/02_partner_and_notes.R) with app-native unit codes and mixed/unknown handling. |
| 3 | Patch VP pending-default logic for family-safe behavior | Complete | Removed hard thousand_lbs forcing in mixed/unknown and routed pending target to dynamic family default. |
| 4 | Patch VP conversion call sites | Complete | Updated both base_data_converted (02) and filtered_vp_data_for_custom_panel (03) quantity paths to use VP family-aware conversion helper. |
| 5 | Add VP mixed-family unavailable UX state and gallon labels | Complete | Quantity unit affordance now unavailable in mixed/unknown contexts; gallon labels added to shared unit label helper. |
| 6 | Validate targeted behavior and parse integrity | Complete (targeted) | R parse checks passed on edited files; focused conversion assertions added for liquid/weight/mixed behavior contracts. |
| 7 | Close ledger with evidence and residual risk | Complete | Evidence, caveats, and residual risk documented below. |

## Working Notes

- Repository currently has unrelated large binary processed-data changes present in worktree.
- Per prior user direction, those artifacts are treated as unrelated and will not be reverted in this tranche.

## Validation Plan

- Parse target files touched in this tranche.
- Focused conversion probe checks:
  - liquid identity and thousand-gallon scaling.
  - weight thousand-lbs behavior unchanged for weight-family rows.
  - mixed/unknown VP quantity conversion returns unavailable output.
- Manual runtime check target:
  - Tomato/Juice/Accumulated Exports exposes liquid-only unit behavior and no liquid-to-weight conversion path.

## Implementation Log

1. Implemented VP family-aware quantity unit context helpers in [Programs/app_source/server/02_partner_and_notes.R](Programs/app_source/server/02_partner_and_notes.R):
- Added family-aware helpers for:
  - unit-choice support detection,
  - context-row selection,
  - resolved VP family,
  - unavailable-state messaging,
  - family-aware unit-choice list,
  - family-aware default target selection.
- Updated unit control visibility/default selection to respect VP family and mixed/unknown states.

2. Patched pending-default behavior in [Programs/app_source/server/02_partner_and_notes.R](Programs/app_source/server/02_partner_and_notes.R):
- Replaced hardcoded thousand_lbs pending target logic with dynamic family target.
- Added guard to clear pending defaults when VP quantity unit is unavailable (mixed/unknown).
- Preserved existing behavior for non-VP sources.

3. Added a VP-specific quantity converter in [Programs/app_source/server/02_partner_and_notes.R](Programs/app_source/server/02_partner_and_notes.R):
- Added vp_trade_quantity_unit_conversion with row-aware handling of:
  - liquid family: gallons, thousand_gallons,
  - weight family: existing MT-derived unit set,
  - mixed/unknown family: unavailable (NA) output.
- Added fallback family derivation from source_volume_unit using vp_volume_family when explicit volume_unit_family is missing.

4. Rewired VP conversion call sites:
- In [Programs/app_source/server/02_partner_and_notes.R](Programs/app_source/server/02_partner_and_notes.R), base_data_converted now routes VP quantity metrics through vp_trade_quantity_unit_conversion.
- In [Programs/app_source/server/03_core_reactives_and_ui.R](Programs/app_source/server/03_core_reactives_and_ui.R), filtered_vp_data_for_custom_panel now routes VP quantity metrics through vp_trade_quantity_unit_conversion.

5. Added/updated conversion contracts and labels in [Programs/app_source/server/02_partner_and_notes.R](Programs/app_source/server/02_partner_and_notes.R):
- Added unit labels:
  - gallons -> Gallons
  - thousand_gallons -> 1000 Gallons
- Added assertions for:
  - liquid gallons identity,
  - liquid thousand-gallons scaling,
  - liquid-to-weight unit blocking,
  - mixed-family blocking,
  - gallon label mapping.

6. Patch friction encountered and resolved:
- Initial attempt to patch 03 custom-panel conversion block failed due stale context mismatch.
- Re-read target region and reapplied a minimal-context patch successfully.

## Validation Evidence

- Diagnostics check:
  - [Programs/app_source/server/03_core_reactives_and_ui.R](Programs/app_source/server/03_core_reactives_and_ui.R) reports no problems in editor diagnostics.
  - [Programs/app_source/server/02_partner_and_notes.R](Programs/app_source/server/02_partner_and_notes.R) shows existing/global static-analysis notes typical for Shiny-scoped symbols; no new syntax diagnostics tied to this tranche.

- Parse check command (explicit workstation Rscript path):
  - & "C:\Program Files\R\R-4.5.1\bin\Rscript.exe" -e "parse(file='VP Clone/Programs/app_source/server/02_partner_and_notes.R'); parse(file='VP Clone/Programs/app_source/server/03_core_reactives_and_ui.R'); cat('PARSE_OK\\n')"
  - Result: PARSE_OK

## Residual Risk

- Manual runtime smoke has not been executed in this tranche:
  - Tomato/Juice/Accumulated Exports UI behavior should still be manually confirmed in a live Shiny session.
- Contract assertions were extended, but execution is option-gated in-app; this tranche validated parse integrity and wiring rather than full interactive execution.

## Summary (Lay Terms)

This change prevents the app from treating liquid trade quantities like weight quantities in VP Trade views. Liquid products now stay in gallon units, weight products keep weight-unit options, and mixed contexts show quantity units as unavailable instead of applying invalid conversions. The main blocker investigated during this work was the old hardcoded default-to-1000-pounds behavior, which could force the wrong unit in liquid contexts; that behavior is now replaced with a family-aware default target.
