# Plan: FTN Calendar-Aware Rollup All-Excluding-Juice Correction

Implement a daughter correction tranche that pauses FTN visualization unit-display work, fixes VP Trade rollup aggregation at the calendar/display grain, routes ambiguous mixed liquid/weight `All` contexts to `All - excluding juice`, validates the rebuilt artifact, and unpauses the parent unit-display tranche only after the artifact gate is clean.

## TL;DR

The clean fix is to make VP rollup aggregation calendar-aware before unit values are materialized. The builder must attach or preserve `analysis_month` before final all-type and rollup aggregation, then aggregate at the same grain the app renders. Mixed liquid/weight `All` contexts at that grain should not survive as `All`; they must route to or synthesize `All - excluding juice` using the existing weight-family replacement semantics. This is a builder/data correction, not a display-label workaround.

## Handoff Status

- Status: Complete; the rollup correction tranche has validated clean and is ready to hand control back to the parent visualization unit-display plan.
- Parent plan: `Code Review/2026-08-10_ftn_visualization_unit_display_guardrail_plan.md`.
- Parent status while this plan was active: paused/blocked at the artifact unit invariant gate; unpause criteria are now satisfied.
- Completed implementation actions: parent plan has been updated to reference this daughter plan as the blocking rollup correction tranche; `Programs/vp_data_utils.R` routes mixed `All` contexts to `All - excluding juice` with deterministic `Year` selection in app aggregation.
- Focused-probe outcome: export / Fruit and tree nuts / Citrus / rollup market segment / Grapefruit / Bahamas / MY 2018 / analysis month 2 now returns `all_rows=0`, `all_excl_rows=1`, `all_excl_unit=Dollars per pound`.
- First gate-cycle outcome on rebuilt artifact: Gate 1 artifact currentity `PASS`, Gate 2 unit invariant `FAIL` with `FTN_UNIT_INVARIANT_TOTAL_ANOMALIES=34578`, Gate 3 calendar matrix `PASS`.
- Second gate-cycle outcome on rebuilt artifact: Gate 1 `PASS`, Gate 2 `FAIL` with `FTN_UNIT_INVARIANT_TOTAL_ANOMALIES=13227` and `FTN_UNIT_INVARIANT_MISSING_UNIT_ROWS=543`, Gate 3 `PASS`.
- Third gate-cycle outcome on rebuilt artifact: Gate 1 `PASS`, Gate 2 `PASS` with `FTN_UNIT_INVARIANT_TOTAL_ANOMALIES=0`, and Gate 3 `PASS`.
- Final gate markers from the clean run: `gate_runner=master_exit_0`, `gate_runner=gate1_exit_0`, `gate_runner=gate2_exit_0`, `gate_runner=gate3_exit_0`.
- Final unit invariant evidence: `Logs/ftn_probe_runs/ftn_unit_invariant_scan_20260811T005911Z_summary.csv` reports zero anomalies across all grains/metrics; no anomaly file was emitted for this run.
- Resume condition for parent unit-display work: satisfied.

## Parent Plan Update

1. Update `Code Review/2026-08-10_ftn_visualization_unit_display_guardrail_plan.md` to mark the unit-display tranche as paused pending this daughter correction plan.
2. Add a `Blocking Daughter Plan` section referencing `Code Review/2026-08-10_ftn_rollup_all_excluding_juice_correction_plan.md`.
3. State that the chosen correction is full calendar-aware rollup aggregation before unit-value materialization.
4. State that parent work resumes only after artifact rebuild, artifact currentity, unit invariant, calendar matrix, and manual checklist validation pass.
5. Record rejected alternatives: display-only normalization, choosing one unit label, averaging incompatible denominators, blanking mixed rows as the primary fix, or using only runtime fallback routing.

## Current Failure Model

- `vp_prepare_all_type_aggregation_rows()` and nested `make_rollup_rows()` in `Programs/vp_data_utils.R` detect liquid/weight mixed families before rows are mapped to the app-facing `analysis_month` grain.
- Some rows are distinct at source grain because they differ by `Year` and/or `MonthNum`, then collide after `vp_infer_month_calendars()` and `vp_build_app_data()` in the same displayed `market_year + analysis_month` point.
- Confirmed example: export / Fruit and tree nuts / Citrus / rollup market segment / Grapefruit / All / Bahamas / MY 2018 / analysis month 2 has both `Dollars per pound` and `Dollars per gallon`, while `vp_volume_family_mixed` remains `FALSE`.
- Existing `vp_build_app_data()` groups by `Year` as well as `MarketYear` and `analysis_month`, allowing duplicate calendar-year rows to survive into the artifact even though the app renders them as one market-year period.

## Core Design Decisions

- Required primary fix: full calendar-aware rollup aggregation in `Programs/vp_data_utils.R` before unit values are computed.
- Required grain: display-grain aggregation must include `Trade`, `country`/`country_label`, `MarketYear`, `analysis_month`, hierarchy fields, `CommodityName`, `CommodityDetail`, and rollup level/path where applicable.
- Required routing: mixed liquid/weight `All` contexts at display grain route to `All - excluding juice`; clean single-family `All` contexts may remain `All`.
- Required pairing: `All - excluding juice` must preserve numerator/denominator pairing by keeping value rows only for detail keys that have eligible weight-family volume rows, matching current replacement semantics.
- Not sufficient as primary fix: post-materialization cleanup in `vp_build_app_data()` or runtime rerouting in `filter_vp_rows_for_resolved_hierarchy()`.
- Runtime fallback may be added only after the artifact-level fix passes, and only as defense in depth.

## Relevant Files

- `Programs/vp_data_utils.R` - primary implementation file.
  - `vp_build_trade_artifact()` - refactor build sequence.
  - `vp_infer_month_calendars()` - preserve calendar semantics and metadata.
  - `vp_prepare_all_type_aggregation_rows()` - adapt/wrap for display-grain routing.
  - `vp_append_all_type_rows()` and nested `make_rollup_rows()` - split or replace with calendar-aware helpers.
  - `vp_build_app_data()` - should consume already-clean final rows or safely respect pre-attached calendar fields.
  - `vp_build_metadata()` - verify counts and calendar metadata after refactor.
- `Programs/app_source/server/02_partner_and_notes.R` - optional runtime fallback only after artifact fix.
- `System/Testing/ftn_validated_unit_invariant_scan.R` - primary blocker/gate probe.
- `System/Testing/ftn_validated_probe_artifact_currentity.R` - artifact currentity validation.
- `System/Testing/ftn_validated_calendar_signature_matrix.R` - calendar behavior validation.
- `System/Testing/ftn_validated_shiny_smoke.R` - optional if runtime fallback is added.
- `Code Review/2026-08-10_ftn_visualization_unit_display_guardrail_plan.md` - parent plan to pause/reference/unpause.

## Steps

### 1. Create the daughter ledger

- Create this file, `Code Review/2026-08-10_ftn_rollup_all_excluding_juice_correction_plan.md`.
- Include scope, failure model, correction design, validation gates, manual commodity checklist, rejected alternatives, blocker log, and parent unpause criteria.
- Dependency: none.

### 2. Pause the parent unit-display plan

- Update the parent visualization plan to reference this daughter plan and explicitly pause unit-display implementation.
- Parent remains blocked until the daughter validation gates pass.
- Dependency: step 1.

### 3. Reconfirm baseline blocker and manual checklist

- Record the existing failing `ftn_validated_unit_invariant_scan.R` output.
- Reconfirm the Grapefruit/Bahamas/MY 2018/analysis month 2 context.
- Confirm whether `All - excluding juice` exists or can be synthesized for the same relevant commodity/hierarchy contexts.
- Preserve the high-priority manual checklist: Grapes, Limes, Grapefruit, Oranges, Lemons, Cherries.
- Dependency: step 1.

### 4. Resolve the calendar/derived-key design before editing

- Explicitly choose and ledger one design for derived calendar metadata:
  - Preferred design: attach calendar fields to native/candidate rows before rollup, carry `analysis_month` and calendar metadata through display-grain aggregation, and adjust/guard `vp_build_app_data()` so enriched final rows are not re-expanded by a stale final-key calendar join.
  - Acceptable fallback design: after calendar-aware rollup aggregation, generate final derived-key calendar metadata from the enriched final rows, then let `vp_build_app_data()` use the existing final `commodity_key + MonthNum` join contract.
- Do not proceed with a vague "infer calendars first" refactor; derived `All`/rollup keys must have a deterministic calendar path.
- Dependency: step 3.

### 5. Refactor the builder sequence

- Change `vp_build_trade_artifact()` away from the current flow: read/normalize -> append all-type/rollup rows -> infer calendars -> build app data.
- Target flow:
  - read/normalize native rows
  - infer native calendars needed for month mapping
  - attach calendar/display period fields to candidate rows
  - build native all-type rows and rollup rows using display-grain keys that include `MarketYear + analysis_month`
  - ensure final derived keys have calendar metadata by the design selected in step 4
  - build app data from already-clean rollup rows
- Preserve artifact schema, source key `vp_trade`, rollup token contracts, and existing calendar metadata columns.
- Dependency: step 4.

### 6. Split or replace rollup helpers with explicit responsibilities

- Introduce focused helpers, names can follow local style, such as:
  - `vp_attach_analysis_month_to_rows(rows, calendars)`
  - `vp_prepare_display_grain_all_type_rows(detail_rows)`
  - `vp_make_display_grain_rollup_rows(source_rows, rollup_level, rollup_path, ...)`
  - `vp_build_display_grain_calendars(final_rows)` if using the derived-key calendar fallback design
- Keep the first edit small enough to validate with a focused builder probe before a full rebuild.
- Do not rely on broad post-hoc mutation after `unit_value` and `ytd_unit_value` are computed.
- Dependency: step 5.

### 7. Implement display-grain `All` / `All - excluding juice` routing

- At display grain, detect whether the candidate `All` aggregate contains both liquid and weight volume families.
- If mixed, do not emit an ambiguous `All` unit-value context. Route to or synthesize `All - excluding juice` using only eligible weight-family detail keys.
- Preserve value/volume pairing: do not drop liquid volume rows while retaining unrelated liquid value rows in the numerator.
- Emit clean `All` only when the display-grain context is single-family.
- Allow liquid-only `All` contexts to use gallon labels and weight-only `All` contexts to use pound labels.
- Mark `vp_volume_family_mixed = TRUE` only for unresolved mixed contexts that cannot be routed; such contexts should suppress unit-value output rather than expose conflicting labels.
- Dependency: step 6.

### 8. Remove duplicate rendered-period survival

- Ensure one rendered `MarketYear + analysis_month` point cannot produce multiple unit labels because of different `Year` values.
- Either aggregate before `vp_build_app_data()` reaches its `Year`-inclusive grouping key, or change the relevant pre-app-data structure so `Year` no longer splits a display-grain aggregate for unit-value contexts.
- Preserve output columns `calendar_year` and `calendar_month` where they remain meaningful; if a display-grain aggregate spans multiple source `Year` values, document the deterministic representative calendar-year rule in the daughter ledger.
- Dependency: step 7.

### 9. Preserve calendar behavior

- Prove `calendar_signature`, `month_abbrev`, `month_name`, `calendar_source_scope`, `calendar_source_months`, and `calendar_complete` remain stable for known FTN examples unless the daughter ledger explicitly documents an intentional correction.
- Run focused pre/post checks before relying only on the full calendar matrix probe.
- Dependency: steps 5-8.

### 10. Preserve rollup flags and metadata

- Preserve `vp_rollup_level`, `vp_rollup_path`, `vp_is_rollup`, and `vp_rollup_schema_version` contracts.
- Preserve `vp_mixed_source_replacement` semantics for contexts routed to `All - excluding juice`.
- Update `vp_build_metadata()` mixed-context and rollup counts if grouping keys change, especially if metadata should count by `analysis_month` rather than `MonthNum` for rebuilt rows.
- Dependency: steps 7-9.

### 11. Add focused builder probe before full rebuild

- Add or run a cheap diagnostic that exercises the new calendar-aware helper on the Grapefruit/Bahamas/MY 2018/analysis month 2 scenario.
- Assert the ambiguous `All` display point is absent or routed to `All - excluding juice` before running `Master_FTN.R`.
- Record output in the daughter ledger.
- Dependency: steps 6-10.

### 12. Rebuild VP artifact

- Use PowerShell-correct command syntax:
  - `$env:VP_MASTER_UPDATES = "vp_trade,metadata"; & "C:/Program Files/R/R-4.5.1/bin/Rscript.exe" Master_FTN.R`
- Record exact command, elapsed time, and any warnings/errors in the daughter ledger.
- Dependency: step 11.

### 13. Validate artifact gates

- Run:
  - `C:/Program Files/R/R-4.5.1/bin/Rscript.exe System/Testing/ftn_validated_probe_artifact_currentity.R`
  - `C:/Program Files/R/R-4.5.1/bin/Rscript.exe System/Testing/ftn_validated_unit_invariant_scan.R`
  - `C:/Program Files/R/R-4.5.1/bin/Rscript.exe System/Testing/ftn_validated_calendar_signature_matrix.R`
- Expected outcome: zero production mixed/missing unit-value anomalies in reachable display contexts.
- Dependency: step 12.

### 14. Regenerate manual rollup checklist

- Regenerate the mixed-rollup commodity checklist or an equivalent no-anomaly confirmation artifact.
- Confirm high-priority commodities no longer show renderable ambiguous `All` contexts: Grapes, Limes, Grapefruit, Oranges, Lemons, Cherries.
- Record before/after counts in the daughter ledger.
- Dependency: step 13.

### 15. Optional runtime fallback only after artifact fix

- If validation or stale-artifact concerns require it, add a narrow fallback in `filter_vp_rows_for_resolved_hierarchy()`.
- Fallback behavior: requested detail is `All`, strict rollup context is active, mixed family is detected, and `All - excluding juice` exists, then internally target `All - excluding juice`.
- This is defensive only and must not be the primary fix.
- If added, run Shiny smoke or focused VP mixed-quantity sanity validation.
- Dependency: steps 13-14.

### 16. Unpause parent unit-display plan

- Update the daughter ledger status to complete only after validation evidence is recorded.
- Update the parent visualization plan from paused/blocked to ready to resume.
- Parent resumes at structured unit resolver/display labeling work with the unit invariant scan as a precondition.
- Dependency: steps 13-14 and step 15 if fallback is added.

## Validation

1. Focused pre/post query for Grapefruit / Bahamas / MY 2018 / analysis month 2 confirms no ambiguous `All` point with both `Dollars per pound` and `Dollars per gallon`.
2. Focused calendar check confirms known FTN calendar signatures and month labels remain stable.
3. Artifact currentity probe passes.
4. Unit invariant scan passes.
5. Calendar signature matrix probe passes.
6. Manual rollup checklist confirms no high-priority renderable mixed `All` contexts.
7. If runtime fallback is added, Shiny smoke or focused VP mixed-quantity sanity probe passes.

## Acceptance Criteria

1. Daughter plan file exists and is updated as the correction ledger.
2. Parent visualization unit-display plan explicitly references the daughter plan and remains paused.
3. Derived calendar metadata for final all-type/rollup keys is handled explicitly.
4. Rollup aggregation is calendar/display-grain-aware before unit-value materialization.
5. Duplicate `Year` rows cannot survive as multiple labels for one rendered `MarketYear + analysis_month` point.
6. Ambiguous mixed liquid/weight `All` contexts route to `All - excluding juice`.
7. `All - excluding juice` preserves value/volume pairing.
8. Clean single-family `All` contexts remain valid.
9. Artifact schema, source key, UI controls, table schemas, and metric math remain unchanged.
10. Representative failing context is fixed.
11. Artifact currentity, unit invariant, and calendar matrix probes pass.
12. Parent plan is unpaused only after validation evidence is recorded.

## Rejected Approaches

- Display-only label normalization.
- Choosing one unit label when both are present.
- Averaging unit values across incompatible denominators.
- Dropping liquid volume rows while retaining liquid value rows.
- Blanking mixed `All` unit values as the primary remediation.
- Runtime `All` -> `All - excluding juice` fallback as the only fix.
- Broad UI or table schema changes.

## Further Considerations

1. If native `All - excluding juice` rows are absent for a context, synthesize them using existing replacement semantics rather than changing UI choices.
2. If a routed aggregate spans multiple source `Year` values, document the deterministic representative `calendar_year` policy.
3. Keep the first substantive code edit small and validate it with the focused builder probe before rebuilding the full artifact.

## Implementation Status

| Step | Status | Notes |
| --- | --- | --- |
| 1. Create the daughter ledger | Complete | This file is the active execution ledger and source of truth for the correction tranche. |
| 2. Pause the parent unit-display plan | Complete | Parent plan has explicit blocking-daughter linkage and remains paused. |
| 3. Reconfirm baseline blocker and manual checklist | Complete | Prior anomaly profile and checklist remain documented in parent ledger; representative Grapefruit/Bahamas mixed-context baseline was reconfirmed before patching. |
| 4. Resolve calendar/derived-key design | Complete | Implemented derived-key handling by routing at display grain and re-inferring calendars before app build consumption. |
| 5. Refactor builder sequence | Complete | `vp_build_trade_artifact()` now performs infer calendar -> display-grain routing -> calendar re-inference -> app build. |
| 6. Split/replace rollup helpers | Complete | Added `vp_route_display_grain_mixed_all_rows()` for explicit display-grain mixed-context routing. |
| 7. Implement display-grain `All` routing | Complete | Mixed liquid/weight `All` contexts are dropped and replaced with weight-only paired `All - excluding juice` rows. |
| 8. Remove duplicate rendered-period survival | Complete | `vp_build_app_data()` keying no longer groups by source `Year`; `Year` is selected deterministically via `vp_pick_year()`. |
| 9. Preserve calendar behavior | Complete | First gate cycle calendar matrix probe returned `FTN_CAL_MATRIX_STATUS=PASS`. |
| 10. Preserve rollup flags and metadata | Complete | Rollup contracts persisted through final clean rebuild; rollup replacement and metadata outputs remained stable in passing gates. |
| 11. Add focused builder probe | Complete | Focused probe passes target context and confirms expected routing outputs. |
| 12. Rebuild VP artifact | Complete | Final chained run rebuilt both `vp_trade` and metadata with `VP_MASTER_STATUS=PASS` and `gate_runner=master_exit_0`. |
| 13. Validate artifact gates | Complete | Final chained run produced `gate_runner=gate1_exit_0`, `gate_runner=gate2_exit_0`, and `gate_runner=gate3_exit_0`. |
| 14. Regenerate manual rollup checklist | Complete | Final invariant summary `ftn_unit_invariant_scan_20260811T005911Z_summary.csv` shows zero anomalies across all grains; anomaly artifact path was empty. |
| 15. Optional runtime fallback | Not required | Builder/data correction resolved the blocker without runtime fallback logic. |
| 16. Unpause parent plan | Complete | Parent ledger has been updated to resume the visualization unit-display tranche. |

## Execution Log

| Date/Time | Command or Action | Status | Evidence |
| --- | --- | --- | --- |
| 2026-08-10 | `source('Programs/vp_data_utils.R')` sanity check | Pass | `vp_data_utils_source_ok`. |
| 2026-08-10 | Initial focused probe attempt for Grapefruit/Bahamas context | Fail (probe expression bug) | Probe ended with data.table `i is invalid type (matrix)` from ad-hoc summary expression, not builder logic. |
| 2026-08-10 | Routing helper transient-column cleanup hardening in `vp_route_display_grain_mixed_all_rows()` | Pass | Cleanup now drops only existing columns via `drop_cols <- intersect(...)`; avoids attempted removal of non-existent `volume_family` column. |
| 2026-08-10 | Focused probe rerun (`all_rows`, `all_excl_rows`, `all_excl_unit`) | Pass | `all_rows=0`, `all_excl_rows=1`, `all_excl_unit=Dollars per pound`; no transient-column warning in rerun. |
| 2026-08-10 | First full rebuild + gate runner cycle | Mixed (Pass/Fail/Pass) | Gate 1 `FTN_ARTIFACT_PROBE_STATUS=PASS`; Gate 2 `FTN_UNIT_INVARIANT_STATUS=FAIL` with `FTN_UNIT_INVARIANT_TOTAL_ANOMALIES=34578`; Gate 3 `FTN_CAL_MATRIX_STATUS=PASS`. |
| 2026-08-10 | Residual anomaly profiling (`ftn_unit_invariant_scan_20260810T221757Z_anomalies.csv`) | Pass (diagnostic) | Residual anomalies are concentrated in visualization-year/series contexts for rollup levels `group_all`, `subgroup_all`, `segment_all`; point-grain anomalies are zero. |
| 2026-08-10 | Second routing patch in `vp_route_display_grain_mixed_all_rows()` | Pass | Routing now enforces mixed-family `All` replacement across series, year, and point rendered grains while preserving value/volume pairing. |
| 2026-08-11 | Second full rebuild + gate runner cycle | Mixed (Pass/Fail/Pass) | Gate 1 `PASS`; Gate 2 `FAIL` with `FTN_UNIT_INVARIANT_TOTAL_ANOMALIES=13227` and `FTN_UNIT_INVARIANT_MISSING_UNIT_ROWS=543`; Gate 3 `PASS`. Artifacts: `Logs/ftn_probe_runs/ftn_unit_invariant_scan_20260811T000040Z_summary.csv` and `Logs/ftn_probe_runs/ftn_unit_invariant_scan_20260811T000040Z_anomalies.csv`. |
| 2026-08-11 | Third routing patch and unit-label backfill in `Programs/vp_data_utils.R` | Pass | Expanded rollup-detail routing to include `All`, `Other`, and `Unspecified` mixed contexts; added `ytd_unit_value_unit` carry-forward within `(Trade, commodity_key, country, MarketYear)` when YTD values exist. |
| 2026-08-11 | Third full rebuild + gate runner cycle: `$env:VP_MASTER_UPDATES = 'vp_trade,metadata'; & "C:/Program Files/R/R-4.5.1/bin/Rscript.exe" Master_FTN.R; ...` | Pass | `gate_runner=master_exit_0`, `gate_runner=gate1_exit_0`, `gate_runner=gate2_exit_0`, `gate_runner=gate3_exit_0`; `FTN_UNIT_INVARIANT_TOTAL_ANOMALIES=0`; `FTN_CAL_MATRIX_STATUS=PASS`; summary: `Logs/ftn_probe_runs/ftn_unit_invariant_scan_20260811T005911Z_summary.csv`; anomaly file absent. |

## Active Blockers

- None active. Artifact currentity, unit invariants, and calendar matrix gates all passed in the final chained run.
- Parent visualization unit-display tranche is now eligible to resume under the parent plan.
- Residual watch item: keep `System/Testing/ftn_validated_unit_invariant_scan.R` in the pre-integration validation chain for future rollup changes.

## Final Summary

This daughter plan corrected the FTN rollup data path that allowed mixed gallon/pound labels inside the same rendered rollup context. The implementation made rollup aggregation calendar/display-grain aware, enforced mixed-family routing across relevant rollup details, preserved value/volume pairing, and backfilled missing YTD unit labels where values existed. Final validation passed cleanly (`master`, `gate1`, `gate2`, and `gate3` all exit 0), with zero invariant anomalies and a passing calendar matrix, so parent unit-display work can now resume.