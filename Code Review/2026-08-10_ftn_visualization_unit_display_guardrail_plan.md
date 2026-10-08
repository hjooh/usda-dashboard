# Plan: FTN Visualization Unit Display Guardrails

Add explicit display-unit labeling across FTN visualizations and tables while adding guardrails that flag impossible mixed or missing unit-value units. This tranche must not change metric math, conversion policy, UI structure, control IDs, data-source contracts, or table schemas unless a documented blocker is found and approved.

This handoff plan is the implementation source of truth for the FTN visualization unit-display tranche. It is modeled after `Code Review/2026-08-10_ftn_conversion_plan.md` and must be updated after every tranche with status, validation evidence, failed attempts, blockers, rejected approaches, deferred work, and final lay summary.

## Handoff Status

- Status: Ready to Resume; implementation can continue because the artifact-data blocker has been cleared.
- Active blocker tranche: `Code Review/2026-08-10_ftn_rollup_all_excluding_juice_correction_plan.md` is complete and no longer blocking parent execution.
- First implementation action completed: this file is the Code Review ledger and must continue to be updated before and after each tranche.
- Baseline implementation state: artifact-only unit invariant probe was created at `System/Testing/ftn_validated_unit_invariant_scan.R`, corrected after an initial data.table evaluation failure, and rerun successfully to completion.
- Blocker-resolution evidence: the daughter plan final chained run emitted `gate_runner=master_exit_0`, `gate_runner=gate1_exit_0`, `gate_runner=gate2_exit_0`, and `gate_runner=gate3_exit_0`, with `FTN_UNIT_INVARIANT_TOTAL_ANOMALIES=0`, `FTN_UNIT_INVARIANT_MISSING_UNIT_ROWS=0`, and `FTN_CAL_MATRIX_STATUS=PASS`.
- Manual review support: historical rollup mixed-unit commodity checklists remain archived under `Logs/ftn_probe_runs/`; the latest invariant summary reports zero anomalies.
- Primary stop condition: if production candidate data contains mixed or missing unit-value units in a reachable visualization context, stop, mark this plan `Not Ready`, and diagnose data/routing before display integration proceeds.

## Daughter Plan Resolution

- Resolved daughter plan: `Code Review/2026-08-10_ftn_rollup_all_excluding_juice_correction_plan.md`.
- Chosen correction path: full calendar-aware rollup aggregation before unit-value materialization, with ambiguous mixed-family `All` contexts routed to `All - excluding juice`.
- Parent pause condition is now cleared. The daughter plan recorded passing results for artifact rebuild plus:
  - `System/Testing/ftn_validated_probe_artifact_currentity.R`
  - `System/Testing/ftn_validated_unit_invariant_scan.R`
  - `System/Testing/ftn_validated_calendar_signature_matrix.R`
  - zero-anomaly invariant summary (`Logs/ftn_probe_runs/ftn_unit_invariant_scan_20260811T005911Z_summary.csv`)
- Parent implementation resumes at Step 3 in this plan.
- Rejected as primary fixes: display-only normalization, single-label forcing, incompatible denominator averaging, blanking mixed rows as the main remediation, runtime-only fallback routing.

## Scope Boundaries

- Allowed: display-unit labels, structured unit resolver helpers, visualization context extraction, plot/table/title/caption/hover unit clarity, mixed/missing unit guardrail detection, validation probes, and ledger updates.
- Not allowed: metric math changes, new unit-conversion policy, broad UI redesign, new table unit columns, tab/control/ID changes, source-key changes, artifact-name changes, dropdown mechanics changes, cache-semantics churn beyond required cache keys, or internal namespace renames.
- Any production mixed-unit anomaly is a blocker, not a display-normalization choice.
- Any production missing-unit anomaly for non-missing unit-value values is a blocker, not a fallback-label choice.
- Legitimate multi-metric displays are allowed only when units are explicit per trace, panel, caption, or metric label.

## Critical Existing Facts

- Source key remains `vp_trade` for the FTN clone.
- Processed artifact remains `System/Processed Data/vp_trade_monthly_pre.rds`.
- Unit-value display units are sourced from artifact fields `unit_value_unit` and `ytd_unit_value_unit`.
- Production candidate artifact rows now use deterministic source-year selection for rendered periods, so one displayed `market_year + analysis_month` point is no longer split into multiple labels by source `Year`.
- `Programs/vp_data_utils.R` now computes unit values using source-native denominators after the Almond sanity fix.
- Almond export unit values were validated against source data at roughly `2.582` to `2.945 Dollars per pound` after repair.
- `Programs/app_source/server/02_partner_and_notes.R` currently owns shared labels, metric choices, and many helper surfaces. It is the preferred home for resolver/context helpers.
- `Programs/app_source/server/04_comparison_plots.R` owns current-vs-historical comparison, custom comparison panels, overlay paths, and YTD unit-value overlay behavior.
- `Programs/app_source/server/05_trend_and_heatmap.R` owns trendline, heatmap, map, map summary, and data-tab surfaces.
- `Programs/app_source/server/06_pace_analysis_and_reset.R` owns pace analysis KPI/plot/gauge/note surfaces.
- Existing reviewed FTN probes include `System/Testing/ftn_validated_probe_artifact_currentity.R`, `System/Testing/ftn_validated_shiny_smoke.R`, and `System/Testing/ftn_validated_calendar_signature_matrix.R`.
- Use explicit R executable on Windows: `C:/Program Files/R/R-4.5.1/bin/Rscript.exe`.

## Definitions

- Display unit: the unit matching the numeric value shown in the visualization.
- Unit-value metric: `unit_value` or `ytd_unit_value` for `vp_trade`.
- Mixed-unit anomaly: one visualization context for the same unit-value metric contains multiple non-missing display units, for example both `Dollars per pound` and `Dollars per gallon`.
- Missing-unit anomaly: unit-value numeric values exist but display unit labels are missing or blank.
- Multi-metric display: a visualization showing different metrics with legitimately different units. This is allowed only when per-trace/per-panel/per-caption units are explicit.
- Production candidate guardrail: production validation must have zero mixed-unit and zero missing-unit anomalies.
- Synthetic guardrail test: a controlled fixture that intentionally creates mixed or missing unit contexts only to prove detection and warning behavior.
- Visualization grain: the full row context represented by one rendered axis/colorbar/title/caption/trace/table label, often broader than a single month row.
- Point grain: the row-level or month-level context used for diagnostic detail, which may be narrower than a displayed visualization context.

## Implementation Steps

### 1. Confirm this Code Review implementation ledger

- Treat this file, `Code Review/2026-08-10_ftn_visualization_unit_display_guardrail_plan.md`, as the implementation ledger.
- Record all scope boundaries, definitions, guardrails, files, acceptance criteria, and planned validation before code changes.
- Update this ledger after every tranche, including successful validation, failed attempts, rejected approaches, bugs, blockers, and any anomalies found.
- Dependency: none. Blocks all implementation work.

### 2. Baseline artifact invariant scan before UI work

- Run a focused R/data.table scan over `System/Processed Data/vp_trade_monthly_pre.rds`.
- Check all visualizable `vp_trade` unit-value contexts for:
  - More than one `unit_value_unit` in a single plotting context.
  - More than one `ytd_unit_value_unit` in a single YTD plotting context.
  - Non-missing `unit_value` or `ytd_unit_value` with missing unit labels.
  - Reachable `vp_volume_family_mixed == TRUE` rows after standard FTN filters.
- Scan at both point grain and visualization grain. Point grain may include month/analysis month; visualization grain must also aggregate across the months/years each surface displays so mixed units are not hidden by over-granular grouping.
- Group diagnostic context by trade flow, group, subgroup, market segment, commodity, detail/type, country, market-year scope, month/analysis-month scope, rollup level/path, surface type, and metric.
- Include row count, context count, anomaly count, elapsed seconds, and strict pass/fail in output.
- Update this ledger with scan command, output, and status.
- If anomalies exist in production data, stop display work and mark status `Not Ready` until All / All - excluding juice routing is diagnosed.
- Dependency: depends on Step 1.

### 3. Define a structured unit-display resolver contract

- Implement shared resolver in `Programs/app_source/server/02_partner_and_notes.R` as a pure row-first helper, for example `resolve_display_unit(metric, source, rows, context, fallback_context = NULL)`.
- The core resolver must not read top-level `input`; reactive wrappers may gather rows/context and pass them in.
- Resolver returns structured fields, not just text: `label`, `status`, `units`, `metric`, `source`, `message`, and `context`.
- Status values should include `ok`, `mixed_unit_anomaly`, `missing_unit_anomaly`, `multi_metric`, and `fallback`.
- Existing display callers may consume `label`; guardrail logic and probes consume `status`, `units`, and `context`.
- For `vp_trade` unit-value metrics, use artifact fields `unit_value_unit` and `ytd_unit_value_unit` as the source of truth.
- For non-unit-value quantity/value metrics, preserve existing metric-label behavior while adding explicit unit text where current display values already imply a unit.
- Add helper-level parse/source validation before broader app wiring.
- Update this ledger with contract details and validation output.
- Dependency: depends on Steps 1-2.

### 4. Add centralized context extraction and guardrail event sink

- Add helper(s) in `Programs/app_source/server/02_partner_and_notes.R` to extract row/context sets used by visualizations before unit labels are resolved.
- Resolve units before each visualization aggregates, pivots, ranks, or drops unit metadata; carry a `unit_resolution` object into derived plot/table state.
- Centralize mixed/missing unit detection.
- Add a deduped, append-only event sink readable by tests and ledgering.
- Prefer a non-reactive or one-way store such as `session$userData` to avoid render/reactive invalidation loops.
- Event fields should include: tab/output id, source, metric, trade flow, hierarchy path, country/country group, market-year/month scope, rollup level/path, unit set, status, message, timestamp/run id.
- Visible warning text should be deterministic: `Unit guardrail: mixed unit values detected; review All - excluding juice routing.`
- Update this ledger with helper/event contract and validation output.
- Dependency: depends on Step 3.

### 5. Inventory output row contexts and cache keys before surface edits

- For each target output, identify the row set available before aggregation and the `bindCache()` or cache-key inputs that determine rendered label/warning state.
- Cover at minimum: current-vs-historical plot, YTD unit-value overlay, custom comparison panels, custom overlay, historical trendline, monthly heatmap, map plot, map summary, data tab, and pace analysis.
- Add selected metric and any unit-resolution discriminator to cache keys where labels or warnings depend on them.
- Pay particular attention to map and map-summary paths because stale cache keys can show correct values with stale labels/warnings.
- Update this ledger with inventory results and any cache-key changes before broad surface edits.
- Dependency: depends on Steps 3-4.

### 6. Update current-vs-historical and custom comparison plots

- Modify `Programs/app_source/server/04_comparison_plots.R`.
- Resolve unit status before each plot path aggregates or drops unit metadata.
- Axis titles include explicit display unit.
- Hover templates include explicit display unit next to numeric values.
- YTD unit-value overlay resolves `ytd_unit_value_unit` separately and includes explicit units in trace names/hovers.
- Projection annotations include explicit units.
- Custom comparison panels use per-panel/per-trace units.
- Custom overlay distinguishes legitimate multi-metric units from mixed-unit-value anomalies.
- If trace units differ legitimately, use per-trace labels and a neutral axis such as `Value` rather than pretending one shared unit applies.
- Update this ledger with touched functions, cache-key review, screenshots/logs if available, and validation output.
- Dependency: depends on Steps 3-5.

### 7. Update historical trendline and monthly heatmap surfaces

- Modify `Programs/app_source/server/05_trend_and_heatmap.R`.
- Resolve unit status before trend/heatmap data is summarized, pivoted, or converted to matrices.
- Historical trendline axis, hover, projection labels, and min/max annotations include explicit units.
- Annual/OLS trendline hovers and annotations include units where currently only raw values appear.
- Monthly heatmap title, hover, and colorbar title include explicit display unit.
- Mixed/missing unit-value status triggers central guardrail event and visible warning.
- Update this ledger after tranche, including cache-key review for modified outputs.
- Dependency: depends on Steps 3-5.

### 8. Update map and map-summary surfaces without schema churn

- Modify map paths in `Programs/app_source/server/05_trend_and_heatmap.R` and wrappers in `Programs/app_source/server/02_partner_and_notes.R`.
- Resolve units before map ranking/snapshot creation drops unit metadata.
- Map subtitle, hover, and colorbar use explicit display units.
- Map summary table schemas stay unchanged; add unit clarity in title/caption/header text only.
- Mixed/missing unit-value status triggers central guardrail event and visible warning.
- Review map-related `bindCache()` keys so selected metric and unit-resolution state cannot go stale.
- Update this ledger after tranche.
- Dependency: depends on Steps 3-5.

### 9. Update data-tab and summary table captions

- Modify `Programs/app_source/server/04_comparison_plots.R` and `Programs/app_source/server/05_trend_and_heatmap.R` as needed.
- Summary statistic headings/captions state explicit units for displayed values.
- Data tab schema remains unchanged; section title/caption states active metric unit.
- If raw source metadata and displayed value unit diverge, prefer displayed value unit in visible captions.
- Update this ledger after tranche.
- Dependency: depends on Steps 3-5.

### 10. Update pace-analysis display alignment

- Modify `Programs/app_source/server/06_pace_analysis_and_reset.R`.
- KPI labels, pace plot axis/hover, target notes, and gauge labels use explicit display units.
- Pace currently appears to expose quantity/value metrics rather than unit-value metrics; treat unit-value guardrails as applicable only if unit-value metrics become pace-eligible.
- Update this ledger after tranche.
- Dependency: depends on Steps 3-5.

### 11. Add validation probes and manual checks

- Add or extend reviewed FTN probes under `System/Testing`.
- Reuse and extend the existing artifact-only invariant probe `System/Testing/ftn_validated_unit_invariant_scan.R`; it should continue to run fast and report row count, context count, anomaly count, elapsed seconds, and strict pass/fail.
- Discover a real liquid/gallon candidate from the artifact before promising Shiny UI assertions for `Dollars per gallon`.
- If no reachable production liquid/gallon candidate exists, mark liquid UI validation blocked and cover gallons via helper-level synthetic test.
- Prefer Plotly object extraction over mouse-hover simulation. Assert relevant values from:
  - `layout.yaxis.title.text`
  - `layout.title.text`
  - `layout.annotations[].text`
  - `data[].name`
  - `data[].hovertemplate`
  - `data[].hovertext`
  - `data[].text`
  - `data[].colorbar.title.text`
- Consolidate Shiny validation into as few app launches as possible, using existing robust patterns: `set_inputs(wait_ = FALSE)`, explicit input confirmation, DOM polling, and Plotly readiness checks.
- Production candidate checks:
  - Almonds weight context expects `Dollars per pound` in axis/title/caption and hover-template/source text.
  - Liquid/juice context expects `Dollars per gallon` where a reachable candidate exists.
  - Standard candidate runs emit zero guardrail anomalies.
  - Any production anomaly marks validation `Not Ready`.
- Synthetic guardrail checks:
  - Controlled fixture/helper-level test forces clean weight, clean liquid, mixed units, and missing-unit contexts.
  - Assert guardrail status, context payload, unit set, and visible warning text.
- Existing artifact/currentity, Shiny smoke, and calendar matrix probes must still pass.
- Update this ledger with all probe commands and outputs.
- Dependency: depends on Steps 6-10.

### 12. Perform final go/no-go review

- Update this ledger with final status.
- Go only if:
  - Baseline production artifact scan has zero anomalies.
  - Output row-context and cache-key inventory is complete.
  - Display-unit probes pass for weight context and for liquid context when a reachable production liquid candidate exists.
  - Liquid/gallon candidate discovery is documented, including fallback to helper-level synthetic coverage if no reachable production candidate exists.
  - Synthetic guardrail tests fire correctly for mixed and missing units.
  - Production candidate run emits zero guardrail anomalies.
  - Existing FTN probes still pass.
- If any gate fails, mark handoff status `Not Ready`, name the blocker, record evidence, and identify the next remediation step.
- Include a final summary in lay terms covering scope, outcome, blockers investigated, and any deferred work.

## Relevant Files

- `Code Review/2026-08-10_ftn_visualization_unit_display_guardrail_plan.md` - this source-of-truth implementation ledger.
- `Code Review/2026-08-10_ftn_conversion_plan.md` - structure/convention template and historical FTN conversion context.
- `Programs/app_source/server/02_partner_and_notes.R` - resolver, context extraction, metric labels, wrappers, and guardrail event sink.
- `Programs/app_source/server/04_comparison_plots.R` - current-vs-historical, custom comparison panels, overlay, hovers, annotations, and summary captions.
- `Programs/app_source/server/05_trend_and_heatmap.R` - trendlines, heatmap, map, map summary, data-tab captions, hovers, and colorbars.
- `Programs/app_source/server/06_pace_analysis_and_reset.R` - pace KPIs, pace plot, gauge, target notes, and labels.
- `Programs/app_source/server/03_core_reactives_and_ui.R` - wrapper placements if a shared warning/banner is needed.
- `Programs/app_source/global.R` - optional artifact unit-field validation guardrails during startup.
- `Programs/vp_data_utils.R` - unit-value/unit metadata source of truth for future builds.
- `System/Processed Data/vp_trade_monthly_pre.rds` - production candidate artifact for invariant scans.
- `System/Testing/ftn_validated_probe_artifact_currentity.R` - existing FTN artifact/currentity regression probe.
- `System/Testing/ftn_validated_shiny_smoke.R` - existing FTN Shiny smoke regression probe to extend or keep as regression.
- `System/Testing/ftn_validated_calendar_signature_matrix.R` - existing calendar matrix regression probe.
- `System/Testing/ftn_validated_unit_invariant_scan.R` - existing artifact-only unit invariant probe.

## Acceptance Criteria

1. This Code Review plan file exists and is updated after every tranche.
2. Baseline artifact invariant scan shows zero production mixed-unit and missing-unit anomalies before display integration proceeds.
3. Output row-context and cache-key inventory is completed before broad surface edits.
4. Automated probes pass for representative weight unit labels and liquid labels where a reachable production liquid candidate exists.
5. Plotly-object extraction, not mouse-hover simulation, verifies axis/title/caption/annotation/hover-template/colorbar unit text.
6. Every modified visualization surface shows explicit units in axis/title/caption and hover/value text as applicable.
7. Synthetic mixed/missing-unit tests fire guardrail with deterministic payload and visible warning text.
8. Production candidate guardrail scan emits zero anomalies; any anomaly marks status `Not Ready`.
9. Existing FTN artifact/currentity, Shiny smoke, and calendar matrix probes still pass.
10. Final ledger includes validation outputs, failed attempts, blockers, deferred work, and lay summary.

## Critical Guardrails

- Do not normalize away mixed units in display code.
- Do not add table unit columns in this tranche.
- Do not alter metric math or conversion policy.
- Do not change tab structure, control IDs, source keys, artifact names, dropdown mechanics, or broad internal `vp_` contracts.
- Do not treat legitimate multi-metric overlays as mixed-unit anomalies if each trace/panel is explicitly labeled.
- Do resolve unit status before aggregation, pivoting, ranking, or matrix conversion drops unit metadata.
- Do review cache keys for every modified cached output whose labels or warnings depend on selected metric/unit state.
- Do stop and ledger a blocker if production candidate data has mixed or missing unit-value units.

## Implementation Status

| Step | Status | Notes |
| --- | --- | --- |
| 1. Confirm implementation ledger | Complete | This file is the implementation ledger. It has now been updated with baseline gate failure evidence and manual-check artifacts. |
| 2. Baseline artifact invariant scan | Complete / Pass | Baseline blocker was resolved in daughter-plan final cycle; latest production candidate run reports zero anomalies and emitted `FTN_UNIT_INVARIANT_STATUS=PASS`. |
| 3. Structured resolver contract | Complete / Pass | Row-first resolver scaffolding is present in `Programs/app_source/server/02_partner_and_notes.R`; helper-level fixture assertions now cover clean weight/liquid, mixed units, missing units, fallback, multi-metric, and event dedupe behavior. |
| 4. Context extraction/event sink | Complete / Pass | Centralized unit-resolution context/event sink helpers in `Programs/app_source/server/02_partner_and_notes.R` are active, and output-scoped guardrail events now emit from comparison, trend/heatmap, map/map-summary, `summary_table`, and `raw_data_table` unit-value paths. Pace remained quantity/value-oriented by design in this tranche. |
| 5. Output context/cache inventory | Complete / Pass | Inventory completed across comparison, trend/heatmap, and map paths. `comparison_plot` cache discrimination includes `main_tabs_panel`; trend/heatmap cache discrimination includes `census_value_unit_choice`; map cache path already includes metric + source/hierarchy/unit/basis discriminators through `map_runtime_source_cache_key()` and related keys. |
| 6. Comparison/custom plots | Complete / Pass | Unit-aware value labels now cover main `comparison_plot`, shared `weekly_metric_comparison_plot` panel consumers, `comparison_overlay_plot`, and YTD overlay unit text paths. Comparison title now also carries explicit display unit to keep title/axis/hover consistency. |
| 7. Trendline/heatmap | Complete / Pass | `timeseries_plot` and `heatmap_plot` now resolve vp_trade unit-value display units with output-scoped context/event capture, with unit-aware title/hover/colorbar evidence confirmed by the UI probe. |
| 8. Map/map summary | Complete / Pass | `map_plot`, map note block, and map-summary outputs resolve vp_trade unit labels against map row context, emit output-scoped events, and retain existing table schemas. Final UI probe pass confirms map title/hover/colorbar unit behavior in forced value-shading mode for both pound and gallon contexts. |
| 9. Data-tab/summary captions | Complete / Parse Pass | Added explicit unit captions to `summary_table` in `Programs/app_source/server/04_comparison_plots.R` and to `psd_time_series_summary_table` plus `raw_data_table` in `Programs/app_source/server/05_trend_and_heatmap.R`, while preserving table schemas/columns. VP unit-value captions prefer resolver-derived display units and emit output-scoped guardrail events. |
| 10. Pace-analysis alignment | Complete / Parse Pass | Updated `Programs/app_source/server/06_pace_analysis_and_reset.R` so pace KPI unit text reuses a shared display-unit helper, pace plot trace names/hover/title/y-axis carry explicit units, target-note text names the active unit, and gauge titles include unit-per-period context. Pace remains quantity/value-oriented; no unit-value guardrail resolver route was added in this tranche. |
| 11. Validation probes/manual checks | Complete / Pass | Baseline artifact/currentity/calendar gates are complete; helper-level synthetic guardrail fixture passes; post-map chained rerun passed fixture, artifact currentity, invariant, calendar matrix, and Shiny smoke probes. Dedicated UI Plotly extraction probe at `System/Testing/ftn_validated_unit_display_ui_guardrail.R` now runs with mirrored launch/confirm architecture and passes (`FTN_UNIT_UI_GUARDRAIL_STATUS=PASS`, `FTN_UNIT_UI_GUARDRAIL_TOTAL_CHECKS=34`, `FTN_UNIT_UI_GUARDRAIL_FAILURE_COUNT=0`). |
| 12. Final go/no-go | Complete / Go | Final gate review passed with zero production invariant anomalies, UI unit-display probe pass (`34/34` checks), and current regression probes passing (`artifact currentity`, `calendar signature matrix`, `Shiny smoke`). Ready for handoff. |

## Validation Log

| Date/Time | Command or Probe | Status | Evidence |
| --- | --- | --- | --- |
| 2026-08-10 | Planning handoff | Ready | Plan created; implementation not started. |
| 2026-08-10 | `C:/Program Files/R/R-4.5.1/bin/Rscript.exe System/Testing/ftn_validated_unit_invariant_scan.R` | Fail / Blocker | Probe executed end-to-end and emitted `FTN_UNIT_INVARIANT_STATUS=FAIL`, `FTN_UNIT_INVARIANT_ROW_COUNT=2636349`, `FTN_UNIT_INVARIANT_TOTAL_ANOMALIES=76401`, `FTN_UNIT_INVARIANT_MISSING_UNIT_ROWS=0`, `FTN_UNIT_INVARIANT_MIXED_VOLUME_ROWS=0`, and `FTN_UNIT_INVARIANT_LIQUID_CANDIDATE_ROWS=505291`. Output artifacts: `Logs/ftn_probe_runs/ftn_unit_invariant_scan_20260810T201220Z_summary.csv` and `Logs/ftn_probe_runs/ftn_unit_invariant_scan_20260810T201220Z_anomalies.csv`. |
| 2026-08-10 | Focused anomaly query for export Grapefruit / Bahamas / MY 2018 / analysis month 2 | Fail / Blocker confirmed | One renderable rollup point contains two rows with `source_volume_unit` = `Thousand pounds` and `Thousand gallons`, `unit_value_unit` = `Dollars per pound` and `Dollars per gallon`, and `vp_volume_family_mixed = FALSE` on both rows. The rows differ by `calendar_year` but collide in `market_year` + `analysis_month`. |
| 2026-08-10 | Rollup anomaly profiling from latest anomaly CSV | Informational | All 76,401 anomalies are in rollup levels: 25,467 each for `segment_all`, `subgroup_all`, and `group_all`. Renderable anomalies are 34,080 point-grain contexts; 42,321 non-renderable visualization-year/series contexts have missing period keys. |
| 2026-08-10 | Manual rollup mixed-commodity checklist generation | Pass | Generated `Logs/ftn_probe_runs/ftn_rollup_mixed_commodity_checklist_summary.csv`, `Logs/ftn_probe_runs/ftn_rollup_mixed_commodity_checklist_renderable_by_level.csv`, `Logs/ftn_probe_runs/ftn_rollup_mixed_renderable_commodity_names.csv`, `Logs/ftn_probe_runs/ftn_rollup_mixed_renderable_commodity_names.txt`, `Logs/ftn_probe_runs/ftn_rollup_mixed_all_commodity_names.csv`, and `Logs/ftn_probe_runs/ftn_rollup_mixed_all_commodity_names.txt`. |
| 2026-08-10 | Daughter-plan first full rebuild gate cycle | Mixed (Pass/Fail/Pass) | `FTN_ARTIFACT_PROBE_STATUS=PASS`; `FTN_UNIT_INVARIANT_STATUS=FAIL` with `FTN_UNIT_INVARIANT_TOTAL_ANOMALIES=34578` (`Logs/ftn_probe_runs/ftn_unit_invariant_scan_20260810T221757Z_anomalies.csv`); `FTN_CAL_MATRIX_STATUS=PASS`. |
| 2026-08-11 | Daughter-plan second full rebuild gate cycle | Mixed (Pass/Fail/Pass) | `FTN_ARTIFACT_PROBE_STATUS=PASS`; `FTN_UNIT_INVARIANT_STATUS=FAIL` with `FTN_UNIT_INVARIANT_TOTAL_ANOMALIES=13227` and `FTN_UNIT_INVARIANT_MISSING_UNIT_ROWS=543` (`Logs/ftn_probe_runs/ftn_unit_invariant_scan_20260811T000040Z_anomalies.csv`); `FTN_CAL_MATRIX_STATUS=PASS`. |
| 2026-08-11 | Daughter-plan third full rebuild gate cycle | Pass | `gate_runner=master_exit_0`; `gate_runner=gate1_exit_0`; `gate_runner=gate2_exit_0`; `gate_runner=gate3_exit_0`; `FTN_UNIT_INVARIANT_TOTAL_ANOMALIES=0`; `FTN_UNIT_INVARIANT_MISSING_UNIT_ROWS=0`; `FTN_CAL_MATRIX_STATUS=PASS`. Summary: `Logs/ftn_probe_runs/ftn_unit_invariant_scan_20260811T005911Z_summary.csv`. |
| 2026-08-11 | Parent blocker review after daughter completion | Ready to Resume | Parent pause condition cleared; next work starts at Step 3 (structured resolver contract). |
| 2026-08-11 | Parent preflight gate rerun before Step 3 coding | Pass | Chained command reran artifact currentity, unit invariant, and calendar matrix probes. Markers: `preflight_gate=artifact_currentity_exit_0`, `preflight_gate=unit_invariant_exit_0`, `preflight_gate=calendar_matrix_exit_0`; `FTN_UNIT_INVARIANT_TOTAL_ANOMALIES=0`; `FTN_CAL_MATRIX_STATUS=PASS`. Latest invariant summary: `Logs/ftn_probe_runs/ftn_unit_invariant_scan_20260811T140858Z_summary.csv`. |
| 2026-08-11 | Step 3/4 scaffolding tranche (`resolve_display_unit`, VP wrapper, guardrail event sink) | In progress | Added row-first display-unit resolver contract plus `unit_guardrail_record_event()` helpers in `Programs/app_source/server/02_partner_and_notes.R`. Parse validation succeeded via `Rscript --vanilla -e "tryCatch({ parse(file='Programs/app_source/server/02_partner_and_notes.R'); ... })"`. |
| 2026-08-11 | Step 6 first contained surface wiring (comparison plot) | In progress | Updated `Programs/app_source/server/04_comparison_plots.R` to include resolved unit text in main current/reference hover value labels. Parse validation succeeded via `Rscript --vanilla -e "tryCatch({ parse(file='Programs/app_source/server/04_comparison_plots.R'); ... })"`. |
| 2026-08-11 | Step 4/5 comparison context and cache-key tranche | In progress | Added comparison-plot unit-resolution context capture + `unit_guardrail_record_event()` emission in `Programs/app_source/server/04_comparison_plots.R`, and added `main_tabs_panel` to `comparison_plot` bindCache dependencies for tab-scoped unit-label safety. Parse validation succeeded via `Rscript --vanilla -e "tryCatch({ parse(file='Programs/app_source/server/04_comparison_plots.R'); ... })"`. |
| 2026-08-11 | Step 6 custom-panel + overlay wiring tranche | In progress | Updated shared `build_weekly_metric_comparison_plot()` and `comparison_overlay_plot` series builder in `Programs/app_source/server/04_comparison_plots.R` to emit output-scoped unit guardrail events and render unit-aware value hover text for panel traces. Parse validation succeeded via `Rscript --vanilla -e "tryCatch({ parse(file='Programs/app_source/server/04_comparison_plots.R'); ... })"`. |
| 2026-08-11 | Step 5 comparison cache inventory checkpoint | In progress | Cache inventory grep of `Programs/app_source/server/04_comparison_plots.R` found one bindCache assignment (`output$comparison_plot <- comparison_plot_render %>% bindCache(...)`); custom panel outputs currently render without bindCache in this file, so no additional cache discriminators were required in this tranche. |
| 2026-08-11 | Step 6 YTD overlay unit-label wiring tranche | In progress | Updated `build_vp_ytd_unit_value_overlay()` in `Programs/app_source/server/04_comparison_plots.R` to resolve and emit output-scoped `ytd_unit_value` unit context events and include resolved units in YTD hover text. Parse validation succeeded via `Rscript --vanilla -e "tryCatch({ parse(file='Programs/app_source/server/04_comparison_plots.R'); ... })"`. |
| 2026-08-11 | Step 7 first contained trendline wiring tranche | In progress | Updated `output$timeseries_plot` in `Programs/app_source/server/05_trend_and_heatmap.R` to resolve vp_trade unit-value display units with output-scoped context (`output_id = timeseries_plot`) and emit guardrail events through `unit_guardrail_record_event()`. Parse validation succeeded via `Rscript --vanilla -e "tryCatch({ parse(file='Programs/app_source/server/05_trend_and_heatmap.R'); ... })"`. |
| 2026-08-11 | Step 7 heatmap unit-label + event tranche | In progress | Updated `output$heatmap_plot` in `Programs/app_source/server/05_trend_and_heatmap.R` to resolve vp_trade unit-value display units with output-scoped context (`output_id = heatmap_plot`), emit guardrail events, and render unit-aware heatmap value hover text. Parse validation succeeded via `Rscript --vanilla -e "tryCatch({ parse(file='Programs/app_source/server/05_trend_and_heatmap.R'); ... })"`. |
| 2026-08-11 | Step 5 trend/heatmap cache-key discriminator tranche | In progress | Updated `historical_trend_plot_base_cache_key()` and bindCache dependencies for `timeseries_plot` and `heatmap_plot` in `Programs/app_source/server/05_trend_and_heatmap.R` to include `census_value_unit_choice`, ensuring cached unit labels/hovers invalidate on value-unit selection changes. Parse validation succeeded via `Rscript --vanilla -e "tryCatch({ parse(file='Programs/app_source/server/05_trend_and_heatmap.R'); ... })"`. |
| 2026-08-11 | Step 3 helper-level resolver/event fixture | Pass | Added `System/Testing/ftn_validated_unit_guardrail_fixture.R` and ran `C:/Program Files/R/R-4.5.1/bin/Rscript.exe --vanilla System/Testing/ftn_validated_unit_guardrail_fixture.R`; rerun emitted `FTN_UNIT_GUARDRAIL_FIXTURE_STATUS=PASS`. Fixture asserts clean `Dollars per pound`, clean `Dollars per gallon`, mixed-unit anomaly, missing-unit anomaly, partial missing labels, fallback/non-unit metric, multi-metric, deterministic event message, event payload, and duplicate-event dedupe. |
| 2026-08-11 | Step 8 map plot + map-summary unit guardrail wiring | In progress / Parse Pass | Updated `Programs/app_source/server/05_trend_and_heatmap.R` with `map_unit_resolution_rows()`, `resolve_map_display_unit()`, and `map_unit_guardrail_warning_text()`. `map_plot` now records output-scoped unit guardrail events and uses resolved artifact units for subtitle/hover/colorbar labels. `map_note_block` exposes deterministic warning text for mixed/missing unit-value anomalies. Map summary outputs add unit-aware captions and record events for `psd_map_summary_table_current`, `psd_map_summary_table_comparison`, `non_psd_map_summary_table_current`, or `non_psd_map_summary_table_comparison` without changing table columns. Parse validation emitted `trend_heatmap_parse_ok`. Editor diagnostics remain noisy for sourced server chunks (`input`, `session`, and helper globals reported as unresolved); no diagnostics were reported for the new fixture or ledger file. |
| 2026-08-11 | Step 8 map note scoping repair | Pass | Review after the Step 8 parse pass found a runtime-only defect: `map_note_block` used `source_choice` without defining it locally. Added a local `source_choice <- current_source_choice_safe(...)` and routed unit-label basis/value-unit calls through it. Focused parse validation emitted `trend_heatmap_parse_ok`. |
| 2026-08-11 | Step 8 map-summary source-choice tightening | Pass | Tightened `render_map_summary_table_widget()` to use a local safe `source_choice` for PSD detection and unit/basis resolution instead of raw `input$data_source_choice`. Focused parse validation emitted `trend_heatmap_parse_ok`. |
| 2026-08-11 | Post-map validation chain rerun | Pass | Chained command completed after Step 8 map/map-summary wiring: `FTN_UNIT_GUARDRAIL_FIXTURE_STATUS=PASS`; `FTN_ARTIFACT_PROBE_STATUS=PASS`; `FTN_UNIT_INVARIANT_STATUS=PASS`; `FTN_UNIT_INVARIANT_TOTAL_ANOMALIES=0`; `FTN_UNIT_INVARIANT_MISSING_UNIT_ROWS=0`; `FTN_UNIT_INVARIANT_MIXED_VOLUME_ROWS=0`; `FTN_CAL_MATRIX_STATUS=PASS`; `FTN_SHINY_SMOKE_STATUS=PASS`. Latest invariant summary: `Logs/ftn_probe_runs/ftn_unit_invariant_scan_20260811T150745Z_summary.csv`. |
| 2026-08-11 | Step 9 data-tab and summary-caption tranche | Pass | Added explicit display-unit captions to `summary_table`, `psd_time_series_summary_table`, and `raw_data_table` while preserving existing table schemas. For vp_trade `unit_value`/`ytd_unit_value`, captions prefer resolver-derived labels and now emit output-scoped guardrail events for `summary_table` and `raw_data_table`. Focused parse validation emitted `comparison_plots_parse_ok` and `trend_heatmap_parse_ok`. |
| 2026-08-11 | Step 10 pace-analysis display alignment tranche | Pass | Added shared `pace_metric_unit_label()` helper and applied explicit unit labels to pace KPI text, pace target notes, pace plot trace names/hover/title/y-axis, and pace gauge headings in `Programs/app_source/server/06_pace_analysis_and_reset.R`. Focused parse validation emitted `pace_analysis_parse_ok`. |
| 2026-08-11 | Step 11 UI guardrail probe scaffold + candidate discovery | In progress | Added `System/Testing/ftn_validated_unit_display_ui_guardrail.R` to extract Plotly fields (`layout.title.text`, `layout.yaxis.title.text`, `data[].name`, `data[].hovertemplate`, `data[].hovertext`, `data[].text`, `data[].colorbar.title.text`) and table captions for comparison, heatmap, map, data tab, and pace. Artifact discovery selected deterministic export candidates: pound context (`Fruit and tree nuts` / `Citrus` / `Fresh` / `Citrus fruit, other` / `All`) and gallon context (`Fruit and tree nuts` / `Citrus` / `Juice` / `Citrus fruit, other` / `All`). Parse validation emitted `ftn_unit_display_ui_guardrail_parse_ok`; full run is active after startup hardening. |
| 2026-08-11 | Step 11 UI guardrail probe stabilization cycle | Mixed -> Pass | First mirrored-architecture full run completed and failed with `FTN_UNIT_UI_GUARDRAIL_STATUS=FAIL` (`total_checks=30`, `failure_count=8`; artifacts: `Logs/ftn_probe_runs/ftn_unit_display_ui_guardrail_20260811T162201Z_summary.csv`, `_checks.csv`, `_failures.csv`). Failures isolated to comparison title unit omission and map assertions still reading share-mode hover/colorbar fields. Applied targeted fixes: (1) `Programs/app_source/server/04_comparison_plots.R` now appends explicit display unit to `comparison_plot` title text; (2) probe map phase now explicitly forces `map_comparison_mode='current'` and `map_measure_mode='quantity_value'`, and evaluates text/hover field availability without assuming `data[].text` population. Intermediate rerun still failed while map mode forcing used select-choice assumptions (`ftn_unit_display_ui_guardrail_20260811T163228Z_*`), then final rerun passed fully with `FTN_UNIT_UI_GUARDRAIL_STATUS=PASS`, `FTN_UNIT_UI_GUARDRAIL_TOTAL_CHECKS=34`, `FTN_UNIT_UI_GUARDRAIL_FAILURE_COUNT=0`, `FTN_UNIT_UI_GUARDRAIL_GALLON_REACHABLE=TRUE` (summary: `Logs/ftn_probe_runs/ftn_unit_display_ui_guardrail_20260811T164018Z_summary.csv`; checks: `Logs/ftn_probe_runs/ftn_unit_display_ui_guardrail_20260811T164018Z_checks.csv`). |
| 2026-08-11 | Post-stabilization artifact currentity rerun | Pass | `FTN_ARTIFACT_PROBE_STATUS=PASS`; artifact row count `2510061`; metadata app rows matched artifact rows; source signature unchanged. |
| 2026-08-11 | Post-stabilization invariant rerun | Pass | `FTN_UNIT_INVARIANT_STATUS=PASS`; `FTN_UNIT_INVARIANT_TOTAL_ANOMALIES=0`; `FTN_UNIT_INVARIANT_MISSING_UNIT_ROWS=0`; `FTN_UNIT_INVARIANT_MIXED_VOLUME_ROWS=0`; summary: `Logs/ftn_probe_runs/ftn_unit_invariant_scan_20260811T164635Z_summary.csv`. |
| 2026-08-11 | Post-stabilization calendar matrix rerun | Pass | `FTN_CAL_MATRIX_STATUS=PASS`; both Bananas and Oranges candidate rows passed with expected month signature + axis-title alignment. |
| 2026-08-11 | Post-stabilization Shiny smoke rerun | Pass | `FTN_SHINY_SMOKE_STATUS=PASS`; VP trade source remained selected and FTN controls/titles visible while legacy panes remained hidden. |
| 2026-08-11 | Step 12 final go/no-go review | Go | All required gates now pass in current state: invariant scan zero anomalies, UI unit-display guardrail pass (`34/34`), gallon candidate reachable, helper fixture pass, and core regressions (artifact currentity, calendar matrix, Shiny smoke) passing. |
| 2026-08-11 | Post-go map summary caption cleanup (user-requested) | Pass | Removed map-summary unit sentence caption (`[Trade Flow] Unit Value shown in [unit].`) from `render_map_summary_table_widget()` in `Programs/app_source/server/05_trend_and_heatmap.R` while preserving anomaly warning caption behavior when present. Focused parse validation emitted `trend_heatmap_parse_ok`. |
| 2026-08-11 | Post-go map note source sentence update (user-requested) | Pass | Updated `output$map_note_block` in `Programs/app_source/server/05_trend_and_heatmap.R` so the Map note now prepends a Census-source sentence with trade-flow-aware wording: export uses `U.S. exports by destination country`, import uses `U.S. imports by country of origin`, followed by the existing display-mode note text. Focused parse validation emitted `trend_heatmap_parse_ok`. |

## Manual Rollup Mixed-Commodity Checklist

Historical baseline snapshot from the failing artifact. The latest production candidate invariant summary (`ftn_unit_invariant_scan_20260811T164635Z_summary.csv`) reports zero anomalies; the checklist below is retained for audit context only.

High-priority renderable commodities, ranked by renderable mixed contexts:

| CommodityName | Renderable contexts | Mixed contexts | Trades | Hierarchy combinations | Notes |
| --- | ---: | ---: | --- | ---: | --- |
| Grapes | 28,137 | 38,718 | export/import | 6 | Largest blocker; Noncitrus and rollup-all contexts. |
| Limes | 2,112 | 4,491 | export/import | 6 | Citrus and rollup-all contexts. |
| Grapefruit | 1,620 | 3,558 | export/import | 6 | Citrus and rollup-all contexts; confirmed Bahamas example has pound/gallon rows in same MY period. |
| Oranges | 1,536 | 5,526 | export/import | 6 | Citrus and rollup-all contexts. |
| Lemons | 348 | 1,128 | import | 3 | Import-side Citrus rollup contexts. |
| Cherries | 327 | 1,755 | import | 3 | Import-side Noncitrus rollup contexts. |

Full unique commodity-name universe from rollup mixed-unit anomalies:

- Apples
- Blueberries
- Cherries
- Citrus fruit, other
- Cranberries
- Grapefruit
- Grapes
- Lemons
- Limes
- Mangoes
- Noncitrus fruit, other
- Oranges
- Pears
- Pineapples
- Raspberries

Generated manual-review artifacts:

- `Logs/ftn_probe_runs/ftn_rollup_mixed_commodity_checklist_summary.csv` - rollup mixed-unit contexts by trade, group, subgroup, commodity, and priority.
- `Logs/ftn_probe_runs/ftn_rollup_mixed_commodity_checklist_renderable_by_level.csv` - renderable mixed contexts split by rollup level.
- `Logs/ftn_probe_runs/ftn_rollup_mixed_renderable_commodity_names.csv` - ranked high-priority commodity checklist.
- `Logs/ftn_probe_runs/ftn_rollup_mixed_renderable_commodity_names.txt` - plain-text high-priority commodity names.
- `Logs/ftn_probe_runs/ftn_rollup_mixed_all_commodity_names.csv` - all unique commodity names from rollup anomalies.
- `Logs/ftn_probe_runs/ftn_rollup_mixed_all_commodity_names.txt` - plain-text full commodity list.

## Blockers and Failed Attempts

- Resolved: the production artifact mixed/missing unit-value blocker was cleared by the daughter-plan final cycle, which passed all chained gates with zero invariant anomalies.
- Historical baseline (resolved): `System/Processed Data/vp_trade_monthly_pre.rds` contained rollup-all unit-value contexts with both `Dollars per gallon` and `Dollars per pound` in the same renderable market-year/analysis-month point.
- Historical baseline concentration (resolved): `segment_all`, `subgroup_all`, and `group_all` each accounted for 25,467 anomaly records in the baseline anomaly CSV.
- Historical progression (resolved): after the first daughter correction cycle, point-grain anomalies were eliminated while remaining anomalies were concentrated in visualization-year/series rollup `All` contexts.
- Historical representative context (resolved): export / Fruit and tree nuts / Citrus / `__vp_rollup_all_market_segment__` / Grapefruit / All / Bahamas / MY 2018 / analysis month 2 had two rows in one renderable point: one `Thousand pounds` / `Dollars per pound`, one `Thousand gallons` / `Dollars per gallon`; both rows had `vp_volume_family_mixed = FALSE`.
- Initial run of `System/Testing/ftn_validated_unit_invariant_scan.R` failed with a data.table evaluation issue from invalid `.data` usage. The probe was patched to use data.table-native access and now runs to completion.
- A direct anomaly profiling command initially failed with `xtfrm.data.frame` while sorting/printing anomaly summaries. The command was replaced with narrower data.table and PowerShell summaries, producing the manual-check CSV/TXT artifacts listed above.
- Post-revert helper fixture recreation initially failed before assertions because `sys.frame(1)$ofile` is not reliable under bare `Rscript`. The fixture was patched to discover its own path via `commandArgs()` and then passed.
- Step 8 map helper review found a possible zero-length `selected_market_year` runtime edge after the first parse pass. The helper was tightened with an explicit one-value finite-year guard and re-parse passed.
- Step 8 map note review found `source_choice` was referenced before local assignment in `map_note_block`; patched before finalizing the tranche and parse validation passed.
- Step 8 summary-widget review tightened unit-resolution source handling to use `current_source_choice_safe(...)` consistently during source transitions; parse validation passed.
- Initial Step 11 UI probe launch failed with `Reason: On CRAN`; fixed by setting `Sys.setenv(NOT_CRAN = "true")` before app launch, matching existing FTN smoke probe behavior.
- Second Step 11 UI probe launch failed with `Input 'vp_trade_flow_choice' has no available choices`; fixed by adding required-control DOM waits and choice-population polling before setting inputs.
- Static editor diagnostics for `Programs/app_source/server/05_trend_and_heatmap.R` remain noisy because this server chunk is sourced into an environment where `input`, `session`, and many helper functions exist; parse validation is the reliable gate for this file in batch context.
- Known potential blockers to watch:
  - Production mixed-unit anomaly in a reachable visualization context.
  - Production missing-unit anomaly for non-missing unit-value rows.
  - No reachable production liquid/gallon candidate for Shiny UI validation.
  - Unit metadata dropped before aggregation in plot paths.
  - Stale cached labels or warnings because cache keys omit selected metric/unit-resolution state.

## Deferred Work

- No deferred work is approved yet.
- Any future desire to add table unit columns, change unit-conversion policy, redesign UI structure, or rename internal `vp_` contracts belongs in a separate approved tranche.

## Final Summary

This tranche is complete and is marked Go.

In plain terms: the app now consistently tells users what unit each displayed value is using (for example, dollars per pound vs dollars per gallon) across comparison plots, trend/heatmap surfaces, map/map-summary outputs, data captions, and pace labels where applicable. The guardrail architecture was kept row-first and output-scoped, and no metric math, conversion policy, table schema, control IDs, or source/artifact contracts were changed.

The biggest risk investigated was the historical mixed-unit rollup blocker that previously produced impossible contexts (pound and gallon labels in one renderable context). That blocker was cleared earlier by the daughter-plan correction and reconfirmed in the latest invariant rerun: zero mixed-unit anomalies and zero missing-unit anomalies in production candidate data. After that, the major debugging effort was probe stability and map-mode determinism. The final mirrored-architecture UI probe now passes end-to-end (`FTN_UNIT_UI_GUARDRAIL_STATUS=PASS`, `34/34` checks) for both pound and gallon candidates, and regression probes (artifact currentity, calendar matrix, Shiny smoke) are passing in the current code state.
