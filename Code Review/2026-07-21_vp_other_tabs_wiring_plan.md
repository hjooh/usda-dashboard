# VP Other Tabs Wiring Plan

Date: 2026-07-21
Branch: main
Status: Active. This is the source-of-truth implementation ledger for wiring VP support across non-Current-vs-Historical tabs.

## Purpose

Connect the mature almond-derived tab surfaces in the VP app to the VP plumbing already established for Current vs. Historical, without redesigning tab UX or changing mature analytics behavior.

## Scope

Included:

- Keep Current vs. Historical as a frozen regression baseline.
- Wire VP-aware behavior for:
  - Historical Trendlines
  - Pace Analysis Tool
  - Map
  - Monthly Heatmap
  - Data
  - Custom Comparison Tool
  - Market Year Comparison Tool
- Preserve existing tab-level UI/behavior unless minimal source-scoped adaptation is required for VP top-bar/sidebar/data plumbing.
- Run parse and smoke validation per tranche.
- Pause for user confirmation after each tab is properly wired and validated.

Excluded:

- Redesigning tab UIs.
- Changing mature non-VP behavior for almond/rice, Census, Hybrid, PSD, WASDE, or NASS surfaces.
- Reopening Current vs. Historical behavior work unless the user explicitly unblocks a discovered regression.
- Creating paired results markdown unless explicitly requested.

## Source-Of-Truth Ledger Contract

- This file is the active implementation ledger for this tranche.
- Update this file after every step, tranche, edit group, failed attempt, validation run, blocker, bug discovery, rejected approach, user-confirmation pause, and closeout.
- Keep implementation chat terse/code-only where practical; write detailed rationale and evidence here.
- Keep the final Summary lay-friendly and complete.

## Critical Audit Findings

- The target tabs already appear in the VP tab renderer; this is a wiring/validation task, not a tab-creation task.
- Current vs. Historical is functioning and must remain frozen unless explicitly unblocked by the user.
- Several outputs share helper/cache paths; shared edits can unintentionally affect already-working surfaces.
- Historical Trendlines and Heatmap both depend on `historical_trend_plot_base_cache_key()`.
- Map uses VP dimensions in cache keys, but map source filtering still requires verification that top `CommodityName` scope is applied before sidebar Type/detail filtering.
- Pace import/export routing must be explicitly proven for VP contexts.
- Unit-family handling (pounds vs gallons) remains a high-risk data correctness area.

## Guardrails

- Do not modify Current vs. Historical behavior unless user explicitly unblocks a discovered regression.
- Prefer source-scoped changes; avoid broad helper refactors when minimal changes suffice.
- Do not remove or hide mature controls unless proven broken for VP and no source-scoped fix exists.
- Preserve VP contracts already established:
  - hidden `data_source_choice = vp_trade`
  - monthly-only VP frequency behavior
  - top `CommodityName` vs sidebar Type/`CommodityDetail` split
  - artifact-backed Type `All` default/reset behavior
- Update this ledger before moving between tranches.

## Step Ledger

| Step | Work | Status | Notes |
|---|---|---|---|
| 1 | Create source-of-truth plan ledger. | Complete | Created this file as active implementation ledger for VP other-tabs wiring. |
| 2 | Baseline preflight parse/smoke. | Complete | Parse checks pass for targeted server/test files using explicit `Rscript` path; baseline VP smoke passes with expected VP contract markers. |
| 3 | Historical Trendlines wiring and validation. | Complete (User Confirmed) | User manually confirmed Historical Trendlines working after `month_abbrev` fix; phase closed and logged. |
| 4 | Pace Analysis Tool wiring and validation. | Complete (User Confirmed) | Step 4 tranche validations passed and user confirmed Pace Analysis Tool is working correctly; phase closed before Step 5. |
| 5 | Map wiring and validation. | Complete (User Confirmed) | User confirmed Step 5 completion; Map tranche closed after CY/MY label cleanup and Austrian winter peas country-dropdown cache repair with green parse/smoke evidence. |
| 6 | Monthly Heatmap wiring and validation. | Complete (User Confirmed) | User confirmed Step 6 completion after CY/MY year-label parity and VP Analysis Info basis suppression; parse/smoke gate remained green. |
| 7 | Data tab wiring and validation. | Complete (User Confirmed) | User confirmed Data tab behavior looked good after CSV-schema parity (`Trade`..`Amount`) and green smoke markers. |
| 8 | Custom Comparison Tool wiring and validation. | Complete (User Confirmed) | User confirmed Step 8 complete after VP panel commodity controls, quick-apply/layout polish, projection/scale-lock bugfix, and green parse/smoke evidence. |
| 9 | Market Year Comparison Tool wiring and validation. | In Progress | Tranche 9A kickoff: documentation cleanup plus diagnostic MYC smoke instrumentation/validation started. |
| 10 | Cross-tab cleanup and closeout. | Not Started | Final pass, summary, residual risks. |

## Implementation Plan

### Phase 0: Shared Preflight and Setup

1. Confirm this file remains the active source-of-truth ledger.
2. Run baseline parse checks on key VP app files.
3. Run baseline `vp_shinytest_smoke.R` and record outputs.
4. Add smoke helper utilities only if required for stable tab-by-tab validation.
5. Begin implementation with Historical Trendlines only.

### Phase 1: Historical Trendlines (First)

1. Audit and harden VP dimensions in `historical_trend_plot_base_cache_key()`.
2. Validate `output$timeseries_plot` uses VP month mapping/axis behavior.
3. Validate year filter behavior for VP contexts.
4. Preserve existing controls unless proven broken for VP.
5. Extend smoke for July-first and January-first fixtures.
6. Run manual browser checks for refresh/reset/staleness.
7. Pause for user confirmation before moving to Pace.

### Phase 2: Pace Analysis Tool (Second)

1. Validate VP metric eligibility and labels.
2. Validate pace year anchoring for VP.
3. Explicitly prove VP import trade-flow routing in Pace.
4. Validate projection/KPI/target reset behavior.
5. Smoke + manual checks.
6. Pause for user confirmation before moving to Map.

Status: In Progress.

Close State Update (2026-07-22): Complete (User Confirmed).

### Phase 2A: Cross-Cutting Stability Fixes Before Pace

1. Normalize perf logging option gate so VP launch setting `vp_perf_log` enables `[PERF]` output.
2. Guard VP sidebar Type custom-builder sentinel path so transition states with zero valid VP Type choices do not auto-open the modal.
3. Preserve intentional Custom Type Builder access from VP sidebar Type and preserve MYC builder action behavior.
4. Add lightweight transition diagnostics for suppressed/opened builder sentinel handling.
5. Run parse + VP smoke validation and log evidence before entering Pace.

Status: Complete (User Confirmed).

### Phase 3: Map

1. Audit map cache/source/data pipeline for VP split filtering.
2. Validate map metric choices/current vs comparison mode.
3. Validate map summary outputs and refresh behavior.
4. Smoke + manual checks.
5. Pause for user confirmation before moving to Monthly Heatmap.

Status: Complete (User Confirmed).

### Phase 4: Monthly Heatmap

1. Validate VP monthly mapping and signatures.
2. Validate no shared-cache regression from Historical Trendlines changes.
3. Smoke + manual checks.
4. Pause for user confirmation before moving to Data.

Status: In Progress.

Close State Update (2026-07-22): Complete (User Confirmed).

### Phase 5: Data

1. Validate table columns/rows under VP filters.
2. Validate publish behavior safely/non-destructively.
3. Smoke + manual checks.
4. Pause for user confirmation before moving to Custom Comparison.

Status: Complete (User Confirmed).

### Phase 6: Custom Comparison Tool

1. Validate panel defaults, quick-apply actions, and cache behavior.
2. Validate custom Type/country behavior under VP semantics.
3. Smoke + manual checks.
4. Pause for user confirmation before moving to MYC.

Status: In Progress.

### Phase 7: Market Year Comparison Tool

1. Validate mode switching and table/plot behavior.
2. Validate share denominator behavior for Type-specific vs All contexts.
3. Smoke + manual checks.
4. Pause for user confirmation before final cleanup.

Status: In Progress.

### Phase 8: Cross-Tab Cleanup

1. Full parse + smoke sweep.
2. Current vs. Historical regression gate check.
3. Final manual pass across all tabs.
4. Closeout Summary in lay terms.

## Verification / Validation Targets

- Baseline parse and smoke are recorded before tab edits.
- Current vs. Historical remains unchanged unless user explicitly unblocks a bug fix.
- Per-tab smoke assertions prove nonempty outputs and correct VP semantics.
- VP import/export routing is proven where relevant (especially Pace and Map).
- Top `CommodityName` scope and sidebar Type/detail filtering remain distinct and correct.
- No weight conversion leaks into gallon-family contexts.
- Shared helper/cache edits are regression-checked for impacted surfaces.
- Reset behavior returns to expected VP defaults.

## Relevant Files

- `VP Clone/Code Review/2026-07-21_vp_other_tabs_wiring_plan.md`
- `VP Clone/Code Review/2026-07-21_vp_almond_parity_current_historical_plan.md`
- `VP Clone/Programs/app_source/server/02_partner_and_notes.R`
- `VP Clone/Programs/app_source/server/03_core_reactives_and_ui.R`
- `VP Clone/Programs/app_source/server/04_comparison_plots.R`
- `VP Clone/Programs/app_source/server/05_trend_and_heatmap.R`
- `VP Clone/Programs/app_source/server/06_pace_analysis_and_reset.R`
- `VP Clone/Programs/vp_data_utils.R`
- `VP Clone/System/Testing/vp_shinytest_smoke.R`
- `VP Clone/System/Config/vp_contract.R`

## Decisions

- Implement tab-by-tab in this order: Historical Trendlines, Pace, Map, Monthly Heatmap, Data, Custom Comparison, MYC.
- Pause for user confirmation after each tab is validated.
- Keep this as single-plan ledger (no paired results file unless requested).
- Prefer source-scoped fixes over broad refactors.

## Bugs / Rejected Approaches

- Historical Trend smoke tab-discovery false start: initial probe used `get_select_choices("main_tabs_panel")`, which is selectize-oriented and returned false negatives for tabset detection in this harness context.
- Replaced with DOM `data-value` tab discovery helper. Tab detection became reliable (`VP_HISTORICAL_TAB_AVAILABLE=TRUE`), but downstream year-filter and Plotly trace/axis introspection remained inconclusive in this headless run (`VP_HISTORICAL_YEAR_FILTER_NONEMPTY=FALSE`, empty axis/title markers). Treated as a harness-observability limitation rather than a product blocker for this tranche.
- User confirmation failed for Historical Trendlines on 2026-07-22. Runtime console showed `renderPlotly` failure in `output$timeseries_plot`: `object 'month_abbrev' not found` inside `hover_period_text = paste0("Month: ", month_abbrev)`. Root cause was a local monthly-branch join collision: VP `filtered_data()` can already include `month_abbrev`, so `left_join(display_month_mapping, by = "analysis_month")` can suffix mapping columns and leave no bare `month_abbrev` for the mutate expression.
- Rejected broad helper rewrite for the Historical Trendlines bug. The fix is local to the monthly Trendlines path: join a narrowed mapping with `display_month_abbrev = month_abbrev` and build hover text from that dedicated column with a period fallback.
- Rejected removal of Custom Type Builder from VP sidebar Type choices. User requirement is to preserve intentional builder access; implemented source-scoped guard only for empty-real-choice VP transition states.
- Rejected broad MYC builder-path refactor in this tranche. No direct evidence it causes the dry-pulse sidebar auto-trigger; retained MYC behavior and limited fix scope to sidebar Type sentinel handling.
- First Custom Type Builder trigger guard was too narrow. User PERF log showed Type UI rendered `selected=null, choices=0`, then later rendered `selected=__custom_builder__, choices=2`; by observer time, valid choices had repopulated, so the original `length(valid_choices) == 0` guard no longer suppressed the modal.
- Rejected relying only on `myc_transition_trace_safe()` for builder diagnostics because it is gated by `rice_myc_transition_log`, not `vp_perf_log`; added PERF-visible diagnostics for the revised suppression/open paths.

## Blockers / Stop Conditions

- Current vs. Historical regression discovered (requires user unblock before edit).
- Mature-tab behavior drift requiring redesign rather than plumbing.
- VP import/export ambiguity unresolved in a tab.
- `CommodityName` vs Type/detail filtering ambiguity unresolved.
- Unit-family conversion ambiguity (weight conversion applied to gallons).
- Shared-helper blast radius cannot be source-scoped/regression-proven.
- Artifact contract gap blocks tab semantics.
- Smoke instability prevents reliable pass/fail interpretation.

## Evidence Log

- 2026-07-21 Created this source-of-truth other-tabs wiring ledger.
- 2026-07-21 Entered phased implementation order, validation gates, blockers, and confirmation checkpoints.
- 2026-07-21 Baseline preflight parse and smoke started.
  - Initial parse and smoke attempts failed because `Rscript` was not on active PowerShell `PATH`.
  - Resolved by locating explicit executable path: `C:\Program Files\R\R-4.5.1\bin\Rscript.exe`.
  - Parse checks passed:
    - `PARSE_OK::VP Clone/Programs/app_source/server/02_partner_and_notes.R`
    - `PARSE_OK::VP Clone/Programs/app_source/server/03_core_reactives_and_ui.R`
    - `PARSE_OK::VP Clone/Programs/app_source/server/04_comparison_plots.R`
    - `PARSE_OK::VP Clone/Programs/app_source/server/05_trend_and_heatmap.R`
    - `PARSE_OK::VP Clone/Programs/app_source/server/06_pace_analysis_and_reset.R`
    - `PARSE_OK::VP Clone/Programs/vp_data_utils.R`
    - `PARSE_OK::VP Clone/System/Testing/vp_shinytest_smoke.R`
  - Baseline smoke pass markers (selected):
    - `VP_SHINYTEST_IDLE=TRUE`
    - `VP_INPUT_DATA_SOURCE=vp_trade`
    - `VP_INPUT_FREQUENCY=monthly`
    - `VP_INPUT_MAIN_COMMODITY=All`
    - `VP_LABEL_GROUP_VISIBLE=TRUE`
    - `VP_LABEL_SUBGROUP_VISIBLE=TRUE`
    - `VP_LABEL_MARKET_SEGMENT_VISIBLE=TRUE`
    - `VP_LABEL_COMMODITY_VISIBLE=TRUE`
    - `VP_LABEL_TYPE_VISIBLE=TRUE`
    - `VP_OUTPUT_SUMMARY_TABLE_PRESENT=TRUE`
    - `VP_FIXTURE_MONTH_AXIS_FIRST_IS_JAN=TRUE`
    - `VP_AUSTRIAN_WINTER_PEAS_EXPORT_WORLD_JULY_FIRST=TRUE`
  - Baseline warnings observed:
    - `package 'shinytest2' was built under R version 4.5.3`
    - `package 'testthat' was built under R version 4.5.2`
    - No blocker from warnings at this stage.
- 2026-07-21 Phase 1 (Historical Trendlines) implementation edits applied in `VP Clone/Programs/app_source/server/05_trend_and_heatmap.R`.
  - Updated `historical_trend_plot_base_cache_key()` with VP dimensions to stabilize Historical Trendlines/Heatmap cache separation under VP top-control changes:
    - `vp_trade_flow_choice`
    - `vp_group_choice`
    - `vp_subgroup_choice`
    - `vp_market_segment_choice`
    - `vp_commodity_name_choice`
    - `vp_commodity_detail_choice`
  - Added the same VP dimensions to both shared `bindCache(...)` sites:
    - `output$timeseries_plot`
    - `output$heatmap_plot`
- 2026-07-21 Phase 1 validation run.
  - Parse checks passed after edits:
    - `PARSE_OK:05_trend_and_heatmap.R`
    - `PARSE_OK:vp_shinytest_smoke.R`
  - Extended VP smoke harness diagnostics in `VP Clone/System/Testing/vp_shinytest_smoke.R` for Historical Trend tab visibility/year-filter/axis/trace sampling.
  - Smoke rerun passed baseline VP contract markers and emitted Historical Trend diagnostics:
    - `VP_HISTORICAL_TAB_AVAILABLE=TRUE`
    - `VP_HISTORICAL_YEAR_FILTER_PRESENT=TRUE`
    - `VP_HISTORICAL_YEAR_FILTER_NONEMPTY=FALSE`
    - `VP_HISTORICAL_MONTH_AXIS_FIRST_LABEL=`
    - `VP_HISTORICAL_CURRENT_TRACE_COUNT=0`
    - `VP_HISTORICAL_X_AXIS_TITLE=`
  - Interpretation: wiring patch validated by parse + non-regressive smoke pass; Historical tab probe diagnostics are retained as visibility markers and require manual UI confirmation in the user checkpoint.
- 2026-07-22 User confirmation bug report for Historical Trendlines.
  - Console error received from manual app check:
    - `Warning: Error in mutate: In argument: hover_period_text = paste0("Month: ", month_abbrev)`
    - `Caused by error: object 'month_abbrev' not found`
    - Stack pointed to `renderPlotly` in `VP Clone/Programs/app_source/server/05_trend_and_heatmap.R` around the monthly Trendlines data prep.
  - Applied fix in `VP Clone/Programs/app_source/server/05_trend_and_heatmap.R`:
    - Created `display_month_labels <- display_month_mapping %>% select(analysis_month, display_month_abbrev = month_abbrev)`.
    - Joined `display_month_labels` instead of the full mapping in the monthly Trendlines branch.
    - Built `hover_period_text` from `display_month_abbrev`, falling back to `Period <analysis_month>` if unavailable.
  - Focused validation after fix:
    - `PARSE_OK:05_trend_and_heatmap.R`
    - VP smoke completed with no `month_abbrev` Trendlines crash.
    - Historical Trend diagnostics improved from blank plot markers to rendered plot markers:
      - `VP_HISTORICAL_TAB_AVAILABLE=TRUE`
      - `VP_HISTORICAL_YEAR_FILTER_PRESENT=TRUE`
      - `VP_HISTORICAL_MONTH_AXIS_FIRST_LABEL=Sep`
      - `VP_HISTORICAL_CURRENT_TRACE_COUNT=1`
      - `VP_HISTORICAL_X_AXIS_TITLE=Commodity Year Month`
    - Remaining smoke limitation: `VP_HISTORICAL_YEAR_FILTER_NONEMPTY=FALSE` remains a headless checkbox-choice introspection weakness, not the runtime crash reported by the user.
- 2026-07-22 User confirmed Historical Trendlines is working properly after the `month_abbrev` fix. Step 3 moved to complete.
- 2026-07-22 Phase 2A stability fixes before Pace applied.
  - `VP Clone/Programs/app_source/global.R`:
    - Updated `perf_log_enabled()` to honor `vp_perf_log` while preserving `almond_perf_log` and `rice_perf_log` compatibility aliases.
  - `VP Clone/Programs/app_source/server/01_state_and_custom_types.R`:
    - Hardened `observeEvent(input$commodity_choice, ...)` builder sentinel branch.
    - Added VP-specific suppression when `active_source_choice() == "vp_trade"` and `commodity_choice_fallback_values()` is empty.
    - Preserved intentional builder access when valid VP choices exist.
    - Added trace markers:
      - `custom_builder_suppressed_empty_vp_choices`
      - `custom_builder_modal_opened`
  - Validation after Phase 2A edits:
    - `PARSE_OK:global.R`
    - `PARSE_OK:01_state_and_custom_types.R`
    - VP smoke rerun pass markers (selected):
      - `VP_SHINYTEST_IDLE=TRUE`
      - `VP_INPUT_DATA_SOURCE=vp_trade`
      - `VP_INPUT_MAIN_COMMODITY=All`
      - `VP_OUTPUT_SUMMARY_TABLE_PRESENT=TRUE`
      - `VP_HISTORICAL_TAB_AVAILABLE=TRUE`
      - `VP_HISTORICAL_CURRENT_TRACE_COUNT=1`
      - `VP_RESET_TYPE_TO_ALL=TRUE`
      - `VP_AUSTRIAN_WINTER_PEAS_EXPORT_WORLD_JULY_FIRST=TRUE`
  - Remaining risk to confirm manually:
    - Intermittent dry-pulse auto-trigger path depends on reactive timing and may not deterministically reproduce in headless smoke; requires manual confirmation checkpoint before Pace.
- 2026-07-22 User reported Custom Type Builder still auto-triggered after first guard.
  - PERF log diagnosis:
    - `output$commodity_choice_ui` rendered `selected=null, choices=0` for VP Type during transition.
    - Later, the same UI rendered `selected=__custom_builder__, choices=2`.
    - Several outputs ran with `commodity=__custom_builder__`, proving the stale sentinel was preserved as selected after valid choices repopulated.
  - Root cause refinement:
    - Original guard only suppressed when `length(commodity_choice_fallback_values()) == 0` inside the observer.
    - By the time `observeEvent(input$commodity_choice, ...)` handled `__custom_builder__`, fallback choices had repopulated, so the modal-open branch remained eligible.
    - `output$commodity_choice_ui` also treated `CUSTOM_BUILDER_CHOICE` as a valid selected value, preserving the stale sentinel during repopulation.
  - Second patch applied in `VP Clone/Programs/app_source/server/01_state_and_custom_types.R`:
    - Added `vp_type_empty_choice_transition <- reactiveVal(FALSE)`.
    - Mark the transition when VP Type renders with zero real fallback choices.
    - In `output$commodity_choice_ui`, detect stale VP builder selection after such a transition and replace it with `All` or the first valid real fallback when available.
    - In `observeEvent(input$commodity_choice, ...)`, suppress modal opening if the builder sentinel arrives while the VP empty-choice transition marker is pending, even if valid choices have already repopulated.
    - Added PERF-visible logs:
      - `custom_builder_suppressed_vp_transition`
      - `custom_builder_modal_opened`
  - Validation after second patch:
    - `PARSE_OK:01_state_and_custom_types.R`
    - VP smoke rerun passed with existing VP contract markers, including `VP_SHINYTEST_IDLE=TRUE`, `VP_RESET_TYPE_TO_ALL=TRUE`, and `VP_AUSTRIAN_WINTER_PEAS_EXPORT_WORLD_JULY_FIRST=TRUE`.
  - Remaining manual checkpoint:
    - User should retry the dry-pulse dropdown/filter sequence and confirm no unintended builder modal opens.
    - User should intentionally select Custom Type Builder from Type and confirm the modal still opens.
- 2026-07-22 User confirmed second patch resolved the custom builder auto-trigger issue and intentional builder selection behavior remains acceptable.
- 2026-07-22 Stability checkpoint (Phase 2A) closed. Implementation focus moved to Step 4 (Pace Analysis Tool).
- 2026-07-22 Step 4 (Pace) tranche-1 plumbing hardening and validation.
  - `VP Clone/Programs/app_source/server/06_pace_analysis_and_reset.R`:
    - Hardened `pace_resolved_trade_flow()` call to pass both census and VP flow values into `effective_trade_flow_for_source(...)`:
      - before: `effective_trade_flow_for_source(source_choice, input$census_trade_flow_choice)`
      - after: `effective_trade_flow_for_source(source_choice, input$census_trade_flow_choice, input$vp_trade_flow_choice)`
    - Expanded `build_pace_context_key()` to include VP top-bar filtering dimensions so Pace target default/reset context invalidates correctly when VP top controls change:
      - `vp_trade_flow_choice` (VP-only key component)
      - `vp_group_choice`
      - `vp_subgroup_choice`
      - `vp_market_segment_choice`
      - `vp_commodity_name_choice`
  - `VP Clone/System/Testing/vp_shinytest_smoke.R`:
    - Added Pace smoke probes and emitted markers:
      - Pace tab availability and plot render signal markers.
      - VP import routing evidence for Pace via plot-title introspection.
      - Pace target mutate-and-reset behavior markers.
      - Pace projection-source post-reset marker.
    - New emitted markers:
      - `VP_PACE_TAB_AVAILABLE`
      - `VP_PACE_MONTH_AXIS_FIRST_LABEL`
      - `VP_PACE_CURRENT_TRACE_PRESENT`
      - `VP_PACE_X_AXIS_TITLE`
      - `VP_PACE_PLOT_TITLE`
      - `VP_PACE_IMPORT_TITLE_CONTAINS_IMPORTS`
      - `VP_PACE_TARGET_CHANGED_BEFORE_RESET`
      - `VP_PACE_TARGET_REVERTED_AFTER_RESET`
      - `VP_PACE_TARGET_AFTER_RESET`
      - `VP_PACE_PROJECTION_SOURCE_AFTER_RESET`
      - `VP_PACE_PROJECTION_SOURCE_IS_HISTORICAL`
  - Validation evidence:
    - Parse checks passed:
      - `PARSE_OK:06_pace_analysis_and_reset.R`
      - `PARSE_OK:vp_shinytest_smoke.R`
    - VP smoke pass markers (selected):
      - `VP_SHINYTEST_IDLE=TRUE`
      - `VP_INPUT_DATA_SOURCE=vp_trade`
      - `VP_ARTICHOKE_TRADE_FLOW=import`
      - `VP_PACE_TAB_AVAILABLE=TRUE`
      - `VP_PACE_CURRENT_TRACE_PRESENT=TRUE`
      - `VP_PACE_PLOT_TITLE=Trajectory to Target for Year-to-Date Imports - World - All`
      - `VP_PACE_IMPORT_TITLE_CONTAINS_IMPORTS=TRUE`
      - `VP_PACE_TARGET_CHANGED_BEFORE_RESET=TRUE`
      - `VP_PACE_TARGET_REVERTED_AFTER_RESET=TRUE`
      - `VP_PACE_PROJECTION_SOURCE_AFTER_RESET=historical`
      - `VP_PACE_PROJECTION_SOURCE_IS_HISTORICAL=TRUE`
  - Step 4 checkpoint state:
    - Automated parse/smoke gate for this tranche is green.
    - Awaiting user manual Pace confirmation before advancing to Step 5 (Map), per governance gate.
- 2026-07-22 User manual checkpoint completed: Pace Analysis Tool confirmed working correctly.
  - User confirmation: "I can confirm that the Pace Analysis Tool appears to be working correctly."
  - Step 4 moved from In Progress -> Complete (User Confirmed).
- 2026-07-22 Cross-viz note language repair before Step 5 (MY -> CY where calendar-year context applies).
  - User-reported issue:
    - Multiple viz notes referenced `MY` even when the active viz calendar context is calendar-year specific.
  - Applied source-scoped fix in `VP Clone/Programs/app_source/server/03_core_reactives_and_ui.R`:
    - Added `is_calendar_year_display_context(source_choice)` helper for VP calendar-signature detection.
    - Updated `build_display_year_short_prefix(...)` to emit `CY ` in calendar-year VP contexts, while preserving `FY ` and `MY ` behavior elsewhere.
    - Updated weekly note year-family text in `build_weekly_axis_label_note()` to emit `calendar year` when the same calendar-year context is active.
  - Validation evidence:
    - Parse checks passed:
      - `PARSE_OK:03_core_reactives_and_ui.R`
      - `PARSE_OK:06_pace_analysis_and_reset.R`
      - `PARSE_OK:vp_shinytest_smoke.R`
    - VP smoke rerun passed with Step 4 markers still green, including:
      - `VP_SHINYTEST_IDLE=TRUE`
      - `VP_PACE_TAB_AVAILABLE=TRUE`
      - `VP_PACE_CURRENT_TRACE_PRESENT=TRUE`
      - `VP_PACE_IMPORT_TITLE_CONTAINS_IMPORTS=TRUE`
      - `VP_PACE_TARGET_REVERTED_AFTER_RESET=TRUE`
  - Scope note:
    - This change intentionally centralizes year-family labeling through existing shared helpers rather than editing many tab-specific note strings directly.
- 2026-07-22 Step 5 (Map) tranche-1 wiring and label cleanup.
  - `VP Clone/Programs/app_source/server/05_trend_and_heatmap.R`:
    - Added/used Map year-label profile helpers for CY/MY-aware Map text:
      - `map_year_label_profile(...)`
      - `build_map_display_year_label(...)`
      - `build_map_display_year_field_label(...)`
      - `build_map_total_share_label(...)`
      - `build_display_year_share_field_label(...)`
      - `build_map_display_year_descriptor(...)`
    - Rewired Map plot titles, hover labels, colorbar labels, note descriptors, comparison baseline labels, and summary-table year/share labels to resolve through the Map year-label profile.
    - Removed user-facing FY/Fiscal display behavior from the Map profile; VP/non-calendar contexts now label years as MY, per user clarification that this dataset has no fiscal years.
    - Made Map render-path year labels pass the resolved `source_choice` explicitly so title/hover/colorbar text use the same source context.
  - `VP Clone/Programs/app_source/server/02_partner_and_notes.R`:
    - Changed the non-PSD Map sidebar year dropdown from hardcoded `Market Year:` to a dynamic label based on `build_map_display_year_field_label(...)`.
    - Resolved user-observed mismatch where the Map plot title displayed `CY 2026` while the sidebar control still said `Market Year:`.
  - `VP Clone/Programs/app_source/server/03_core_reactives_and_ui.R`:
    - Hardened calendar-year detection with `is_calendar_month_mapping(...)`, including a Jan-through-Dec month mapping fallback when explicit calendar signature metadata is absent.
    - Updated shared display labels so VP calendar-year contexts use `CY`, while all non-calendar contexts display as `MY` rather than `FY`.
    - Updated weekly note terminology so non-calendar contexts say `marketing year`; removed `fiscal year` note text.
  - `VP Clone/Programs/app_source/server/04_comparison_plots.R` and `VP Clone/Programs/app_source/server/05_trend_and_heatmap.R`:
    - Removed remaining user-facing `Fiscal Year`/`FY` display branches in Map analysis/heatmap-style year labels so display text is CY or MY only.
  - `VP Clone/System/Testing/vp_shinytest_smoke.R`:
    - Added `get_input_label_text(...)` helper for direct sidebar label introspection.
    - Added Map smoke markers for Artichokes CY title/sidebar alignment:
      - `VP_MAP_FIXTURE_PLOT_TITLE`
      - `VP_MAP_FIXTURE_TITLE_CONTAINS_CY`
      - `VP_MAP_ARTICHOKE_YEAR_CONTROL_LABEL`
      - `VP_MAP_ARTICHOKE_YEAR_CONTROL_LABEL_IS_CALENDAR`
    - Reset VP top grouping filters to `__all__` before the Artichokes Map probe so the CY check targets the same live context shown in the user screenshot.
  - Failed/ambiguous validation attempts and interpretation:
    - Initial Map smoke fixture used a Dry pulses/Bambara beans context that retained MY semantics; it was not a valid proof for the Artichokes CY mismatch reported by the user.
    - First Artichokes smoke attempt still reported MY because stale VP top filters from the prior Dry pulses fixture remained active. Resetting `vp_group_choice`, `vp_subgroup_choice`, and `vp_market_segment_choice` before the Artichokes probe resolved this harness issue.
    - Plotly axis-title probes remain blank for choropleth maps; retained as non-blocking harness-observability limitation because title/sidebar markers provide the relevant Map evidence.
  - Validation evidence after final patch:
    - Parse checks passed:
      - `PARSE_OK:02_partner_and_notes.R`
      - `PARSE_OK:03_core_reactives_and_ui.R`
      - `PARSE_OK:04_comparison_plots.R`
      - `PARSE_OK:05_trend_and_heatmap.R`
      - `PARSE_OK:vp_shinytest_smoke.R`
    - VP smoke pass markers (selected):
      - `VP_SHINYTEST_IDLE=TRUE`
      - `VP_MAP_TAB_AVAILABLE=TRUE`
      - `VP_MAP_EXPORT_PLOT_TITLE=Accumulated Exports - All - CY 2026...`
      - `VP_MAP_IMPORT_PLOT_TITLE=Accumulated Imports - All - CY 2026...`
      - `VP_MAP_FIXTURE_TITLE_CONTAINS_CY=TRUE`
      - `VP_MAP_ARTICHOKE_YEAR_CONTROL_LABEL=Calendar Year:`
      - `VP_MAP_ARTICHOKE_YEAR_CONTROL_LABEL_IS_CALENDAR=TRUE`
      - `VP_MAP_EXPORT_TITLE_CONTAINS_EXPORTS=TRUE`
      - `VP_MAP_IMPORT_TITLE_CONTAINS_IMPORTS=TRUE`
      - Pace regression markers remained green, including `VP_PACE_TAB_AVAILABLE=TRUE` and `VP_PACE_TARGET_REVERTED_AFTER_RESET=TRUE`.
  - Step 5 checkpoint state:
    - Automated parse/smoke gate for Map tranche is green.
    - Awaiting user manual Map confirmation before advancing to Step 6 (Monthly Heatmap), per governance gate.

- 2026-07-22 Step 5 follow-up: Austrian winter peas Map/current-country mismatch investigation and correction.
  - User report:
    - In Map, `Dry pulses` / `Austrian winter peas` / `Export` / `Accumulated Exports` / Type `All` / MY 2026 showed Taiwan only.
    - Current vs. Historical country dropdown showed Canada, Mexico, Aruba, and other partners, suggesting the Map might be dropping accumulated export partners.
    - User also flagged accumulated value as likely subject to the same issue.
  - Initial hypothesis and rejected approach:
    - Hypothesis: Map current-mode cumulative metrics might be using an exact latest-period snapshot instead of latest-available-by-country, which would drop countries without rows in the most recent month.
    - A first one-off R artifact query failed before returning useful data due path/quoting (`The system cannot find the file specified`). This was a command construction failure, not data evidence.
    - A corrected artifact query showed that, for the processed VP artifact and active context, `commodity == "All"`, MY 2026, export, Austrian winter peas has one positive accumulated export partner: Taiwan at analysis month 10. There were no positive Canada/Mexico/Aruba rows for that active context.
    - A second artifact query across both `All` and detail `Austrian winter peas` rows confirmed the same result: Taiwan is the only positive accumulated export/value partner in the current artifact for that exact active selection.
    - Therefore the Map was not dropping Canada/Mexico/Aruba; the dropdown was leaking stale/broader VP country choices.
  - Root cause:
    - `country_choice_options()` correctly computes choices from selected active data for ranked dropdown branches, but its `bindCache(...)` key did not include VP top-bar dimensions (`vp_trade_flow_choice`, `vp_group_choice`, `vp_subgroup_choice`, `vp_market_segment_choice`, `vp_commodity_name_choice`).
    - After switching from another VP context to Austrian winter peas, the country dropdown could reuse a cached broad VP country list even though the active selected data had only Taiwan plus World/custom-builder.
    - This created the apparent mismatch: the Map reflected active data, while the dropdown reflected a stale or too-broad cache result.
  - Patch applied:
    - `VP Clone/Programs/app_source/server/03_core_reactives_and_ui.R`:
      - Added VP top-bar dimensions to the `country_choice_options()` cache key.
      - Added a VP-specific post-sort country filter so non-MYC VP country choices are restricted to countries present in the active selected data, preserving `GRAND_TOTAL` and custom-country choices.
    - `VP Clone/System/Testing/vp_shinytest_smoke.R`:
      - Added an Austrian winter peas export smoke probe that resets VP dimensions to `Dry pulses` / `__all__` / `__all__` / `Austrian winter peas`, Type `All`, then inspects `country_choice`.
      - Added markers proving Taiwan remains available and Canada/Mexico/Aruba are excluded for this active selection.
  - Validation evidence:
    - Focused parse passed:
      - `PARSE_OK:03_core_reactives_and_ui.R`
      - `PARSE_OK:vp_shinytest_smoke.R`
    - Full VP smoke passed with prior Map/Pace markers still green and new Austrian winter peas markers green:
      - `VP_SHINYTEST_IDLE=TRUE`
      - `VP_MAP_TAB_AVAILABLE=TRUE`
      - `VP_MAP_FIXTURE_TITLE_CONTAINS_CY=TRUE`
      - `VP_MAP_ARTICHOKE_YEAR_CONTROL_LABEL=Calendar Year:`
      - `VP_AWD_COUNTRY_CHOICES_INCLUDE_TAIWAN=TRUE`
      - `VP_AWD_COUNTRY_CHOICES_EXCLUDE_CANADA=TRUE`
      - `VP_AWD_COUNTRY_CHOICES_EXCLUDE_MEXICO=TRUE`
      - `VP_AWD_COUNTRY_CHOICES_EXCLUDE_ARUBA=TRUE`
      - `VP_PACE_TARGET_REVERTED_AFTER_RESET=TRUE`
    - Non-blocking warnings persisted from package build-version differences (`shinytest2`, `testthat`); these were present before and do not indicate app failure.
  - Step 5 checkpoint state:
    - Automated parse/smoke gate remains green after the country-dropdown cache repair.
    - The Map and Current vs. Historical dropdown now agree for the Austrian winter peas active selection: Taiwan is included; Canada, Mexico, and Aruba are excluded because they are not present as positive accumulated partners in the current processed artifact.
    - Awaiting user manual Map confirmation before advancing to Step 6 (Monthly Heatmap), per governance gate.

- 2026-07-22 User manual checkpoint completed: Step 5 Map confirmed.
  - User confirmation: "Fantastic stuff. Mark 5 complete and move to step 6 please"
  - Step 5 moved from In Progress -> Complete (User Confirmed).

- 2026-07-22 Step 6 (Monthly Heatmap) tranche-1 kickoff: CY/MY year-label parity and smoke baseline.
  - `VP Clone/Programs/app_source/server/05_trend_and_heatmap.R`:
    - Updated Heatmap year rendering to use shared CY/MY context helpers:
      - Replaced hardcoded `heatmap_year_prefix <- "MY "` with `build_display_year_short_prefix(source_choice = source_choice)`.
      - Replaced hardcoded y-axis title `"Market Year"` with context-aware label:
        - `"Calendar Year"` when `is_calendar_year_display_context(source_choice = source_choice)` is true.
        - `"Market Year"` otherwise.
    - This aligns Heatmap year labeling with existing VP calendar-signature logic already used in Map and shared notes.
  - `VP Clone/System/Testing/vp_shinytest_smoke.R`:
    - Added Monthly Heatmap tranche smoke probes and markers:
      - `VP_HEATMAP_TAB_AVAILABLE`
      - `VP_HEATMAP_PLOT_TITLE`
      - `VP_HEATMAP_TITLE_CONTAINS_HEATMAP`
      - `VP_HEATMAP_YEAR_AXIS_TITLE`
      - `VP_HEATMAP_YEAR_AXIS_IS_CALENDAR`
    - Probe context mirrors existing Map CY fixture discipline:
      - VP export flow
      - VP top filters reset to `__all__`
      - top commodity `Artichokes`
      - sidebar Type `All`
      - country `GRAND_TOTAL`
  - Validation evidence:
    - Parse checks passed:
      - `PARSE_OK:05_trend_and_heatmap.R`
      - `PARSE_OK:vp_shinytest_smoke.R`
    - VP smoke pass markers (selected):
      - `VP_SHINYTEST_IDLE=TRUE`
      - `VP_HEATMAP_TAB_AVAILABLE=TRUE`
      - `VP_HEATMAP_PLOT_TITLE=All - World<br>Monthly Accumulated Exports Heatmap`
      - `VP_HEATMAP_TITLE_CONTAINS_HEATMAP=TRUE`
      - `VP_HEATMAP_YEAR_AXIS_TITLE=Calendar Year`
      - `VP_HEATMAP_YEAR_AXIS_IS_CALENDAR=TRUE`
      - Existing Map/Pace guards remained green (`VP_MAP_FIXTURE_TITLE_CONTAINS_CY=TRUE`, `VP_PACE_TARGET_REVERTED_AFTER_RESET=TRUE`).
  - Step 6 checkpoint state:
    - Tranche-1 automated parse/smoke gate is green.
    - Step 6 remains In Progress pending additional Monthly Heatmap checks and user manual confirmation gate.

- 2026-07-22 Step 6 follow-up: suppress VP basis wording in sidebar Analysis Info.
  - User clarification:
    - VP data has no recorded basis field or basis semantics.
    - The sidebar Analysis Info section should never show basis wording for VP, regardless of active tab.
  - Investigation findings:
    - `VP Clone/Programs/vp_data_utils.R` does not create or propagate a `basis`, `basis_choice`, or `basis_profile` data column for VP artifacts.
    - `vp_identity` exists only as a compatibility/default basis choice in `VP Clone/System/Config/vp_contract.R`; it is not VP source data metadata.
    - `show_basis_choice(...)` in `VP Clone/Programs/app_source/server/02_partner_and_notes.R` already returns `FALSE` for `source_choice == "vp_trade"`, so the visible basis control is correctly hidden.
    - The leak came from Analysis Info measurement text: `output$data_summary` and Map/other sidebar summaries call `get_metric_measurement_label(...)`, which delegated non-value VP quantity metrics to generic basis-aware measurement formatting.
  - Patch applied:
    - `VP Clone/Programs/app_source/server/02_partner_and_notes.R`:
      - Added a VP-specific branch in `get_metric_measurement_label(...)` before the generic basis-aware formatter.
      - VP `unit_value` still displays `Native Unit Value`.
      - VP value metrics display only value unit labels.
      - VP quantity metrics display only the selected unit label, e.g. `US Tons`, with no basis/equivalent suffix.
    - `VP Clone/Programs/app_source/server/04_comparison_plots.R`:
      - Earlier local Analysis Info measurement path now passes through the same effective metric/source variables; final VP basis suppression is enforced centrally in `get_metric_measurement_label(...)`.
    - `VP Clone/System/Testing/vp_shinytest_smoke.R`:
      - Added `VP_HEATMAP_ANALYSIS_INFO` marker to expose Heatmap sidebar Analysis Info text.
      - Added `VP_HEATMAP_ANALYSIS_INFO_EXCLUDES_BASIS` marker, checking that the Heatmap Analysis Info text excludes `basis`, `equivalent`, and `vp_identity` wording.
  - Validation evidence:
    - Parse checks passed:
      - `PARSE_OK:02_partner_and_notes.R`
      - `PARSE_OK:04_comparison_plots.R`
      - `PARSE_OK:vp_shinytest_smoke.R`
    - VP smoke pass markers (selected):
      - `VP_SHINYTEST_IDLE=TRUE`
      - `VP_MAP_EXPORT_PLOT_TITLE=Accumulated Exports - All - CY 2026<br><sup>Variable: Accumulated Exports | Measurement: US Tons</sup>`
      - `VP_MAP_IMPORT_PLOT_TITLE=Accumulated Imports - All - CY 2026<br><sup>Variable: Accumulated Imports | Measurement: US Tons</sup>`
      - `VP_HEATMAP_ANALYSIS_INFO=Latest Year: 2026 | Months with data: 1, 2, 3, 4, 5 | Historical years: 1 | Measurement: US Tons`
      - `VP_HEATMAP_ANALYSIS_INFO_EXCLUDES_BASIS=TRUE`
      - Existing Step 4/5 guards remained green, including `VP_PACE_TARGET_REVERTED_AFTER_RESET=TRUE` and `VP_MAP_FIXTURE_TITLE_CONTAINS_CY=TRUE`.
  - Step 6 checkpoint state:
    - Automated parse/smoke gate remains green after the Analysis Info basis suppression fix.
    - Step 6 remains In Progress pending user manual confirmation before moving to Step 7 (Data).

- 2026-07-22 User manual checkpoint completed: Step 6 Monthly Heatmap confirmed.
  - User confirmation: "I can confirm that step 6 is complete. We should move on to step 7."
  - Step 6 moved from In Progress -> Complete (User Confirmed).

- 2026-07-22 Step 7 (Data) tranche-1 kickoff: VP Data tab schema aligned to CSV contract.
  - Requirement clarified by user:
    - "I'd like the schema in this data layer to match the schema in the csv input please."
  - Source schema baseline captured from `VP Clone/Input/veg-trade-data.csv`:
    - `Trade`, `GeographicDesc`, `Year`, `MonthNumber`, `MarketYear`, `Group`, `Subgroup`, `MarketSegment`, `CommodityName`, `CommodityDetail`, `UnitType`, `UnitDesc`, `Amount`.
  - `VP Clone/Programs/app_source/server/05_trend_and_heatmap.R`:
    - Added VP-specific `data_tab_dataset()` branch (non-VP behavior unchanged) that now emits CSV-style columns in exact order:
      - `Trade` from processed `Trade` (title-cased).
      - `GeographicDesc` from `countryDescription` with `GRAND_TOTAL -> World` mapping.
      - `Year` from `calendar_year`.
      - `MonthNumber` from `MonthNum` (fallback `month`).
      - `MarketYear` from `market_year`.
      - `Group`, `Subgroup`, `MarketSegment`, `CommodityName` from like-named processed fields.
      - `CommodityDetail` from `commodity` (fallback `CommodityDetail`).
      - `UnitType` from selected metric family (`Volume`, `Value`, `Unit value`).
      - `UnitDesc` from native processed unit descriptor fields keyed by metric:
        - volume metrics -> `source_volume_unit`
        - value metrics -> `source_value_unit`
        - unit-value metric -> `unit_value_unit`
      - `Amount` from the active selected metric column.
    - Removed VP legacy display-schema output (`MY`, `Month #`, `Country`, `Unit`, `Basis`) by returning CSV-style schema for VP branch.
    - Updated VP `raw_data_table` default sort to `Year` desc then `MonthNumber` desc.
  - `VP Clone/System/Testing/vp_shinytest_smoke.R`:
    - Added Data-tab schema probes and markers:
      - `VP_DATA_TAB_AVAILABLE`
      - `VP_DATA_SCHEMA_HAS_CSV_COLUMNS`
      - `VP_DATA_SCHEMA_HAS_LEGACY_COLUMNS`
      - `VP_DATA_TABLE_COLUMNS`
    - Initial attempt used `app$get_values(output = 'raw_data_table')` for column names; returned blank in this harness context.
    - Repaired probe by reading rendered DataTable header cells from DOM via `app$get_js(...)` helper (`get_data_table_columns`).
  - Validation evidence:
    - Parse checks passed:
      - `PARSE_OK:05_trend_and_heatmap.R`
      - `PARSE_OK:vp_shinytest_smoke.R`
    - VP smoke pass markers (selected):
      - `VP_SHINYTEST_IDLE=TRUE`
      - `VP_DATA_TAB_AVAILABLE=TRUE`
      - `VP_DATA_SCHEMA_HAS_CSV_COLUMNS=TRUE`
      - `VP_DATA_SCHEMA_HAS_LEGACY_COLUMNS=FALSE`
      - `VP_DATA_TABLE_COLUMNS=Trade|GeographicDesc|Year|MonthNumber|MarketYear|Group|Subgroup|MarketSegment|CommodityName|CommodityDetail|UnitType|UnitDesc|Amount`
      - Prior Step 4/5/6 guards remained green (including `VP_PACE_TARGET_REVERTED_AFTER_RESET=TRUE`, `VP_MAP_FIXTURE_TITLE_CONTAINS_CY=TRUE`, `VP_HEATMAP_ANALYSIS_INFO_EXCLUDES_BASIS=TRUE`).
  - Step 7 checkpoint state:
    - Tranche-1 automated parse/smoke gate is green.
    - Awaiting user manual Data tab confirmation before moving to Step 8 (Custom Comparison).

- 2026-07-22 User manual checkpoint completed: Step 7 Data tab confirmed.
  - User confirmation: "Data tab behavior looks good!"
  - Step 7 moved from In Progress -> Complete (User Confirmed).

- 2026-07-22 Step 8 (Custom Comparison Tool) tranche-1 kickoff: VP panel commodity controls + quick-apply commodity.
  - User requirements implemented:
    - Add Commodity dropdowns to CCT upper-right, bottom-left, and bottom-right panels in VP mode.
    - Add `Apply Commodity` action to the CCT quick-apply bar.
    - Relabel quick-apply container to `Quick Apply Side and Top Bar Selection`.
  - Implementation edits:
    - `VP Clone/Programs/app_source/server/01_state_and_custom_types.R`:
      - Extended `panel_state` with:
        - `vp_commodity_name_right_2up`
        - `vp_commodity_name_grid_3`
        - `vp_commodity_name_grid_4`
      - Added observers for each new panel commodity input.
    - `VP Clone/Programs/app_source/server/06_pace_analysis_and_reset.R`:
      - Extended reset path to repopulate new panel VP commodity state fields from top-bar VP commodity selection.
    - `VP Clone/Programs/app_source/server/02_partner_and_notes.R`:
      - Added helpers:
        - `custom_comparison_vp_commodity_name_choices()`
        - `resolve_custom_comparison_vp_commodity_name()`
      - Extended reconcile/reset targets to include new panel VP commodity fields.
      - Added `observeEvent(input$custom_comp_apply_top_commodity, ...)` to apply top-bar commodity to right/grid-3/grid-4 panels.
      - Updated quick-apply title to `Quick Apply Side and Top Bar Selection`.
      - Added `custom_comp_apply_top_commodity` button with label `Apply Commodity`.
    - `VP Clone/Programs/app_source/server/03_core_reactives_and_ui.R`:
      - Added VP panel commodity/type choice helpers and VP panel-filtered data path for CCT:
        - `custom_comparison_vp_commodity_name_choices()`
        - `resolve_custom_comparison_vp_commodity_name()`
        - `custom_comparison_panel_vp_type_choices(...)`
        - `filtered_vp_data_for_custom_panel(...)`
      - Added VP panel commodity selectors in CCT UI for right/grid-3/grid-4.
      - Updated `filtered_data_for_country(...)` signature to accept `vp_commodity_name_code` and route VP panel requests through the VP-specific filter path.
    - `VP Clone/Programs/app_source/server/04_comparison_plots.R`:
      - Extended plot/data plumbing to pass panel `vp_commodity_name_code` through panel renderers and overlay builder.
      - Included panel VP commodity names in overlay trace labels (VP path) and cache keys.
    - `VP Clone/System/Testing/vp_shinytest_smoke.R`:
      - Added CCT markers:
        - `VP_CCT_TAB_AVAILABLE`
        - `VP_CCT_QUICK_APPLY_TITLE_HAS_SIDE_TOP`
        - `VP_CCT_APPLY_COMMODITY_BUTTON_PRESENT`
        - `VP_CCT_VP_PANEL_COMMODITY_CONTROLS_PRESENT`
        - `VP_CCT_VP_PANEL_COMMODITY_SYNCED_AFTER_APPLY`
        - `VP_CCT_TOP_PANEL_COMMODITY_AFTER_APPLY`
      - Initial title probe false-negative root cause:
        - Marker used `label_visible(...)`, but the quick-apply title is rendered as panel heading text, not a `label` element.
      - Harness correction:
        - Added `text_visible(...)` helper and updated title check to accept either label-match or text-match visibility.
  - Validation evidence:
    - Parse checks passed:
      - `PARSE_OK:01_state_and_custom_types.R`
      - `PARSE_OK:02_partner_and_notes.R`
      - `PARSE_OK:03_core_reactives_and_ui.R`
      - `PARSE_OK:04_comparison_plots.R`
      - `PARSE_OK:06_pace_analysis_and_reset.R`
      - `PARSE_OK:vp_shinytest_smoke.R`
    - VP smoke pass markers (selected):
      - `VP_DATA_SCHEMA_HAS_CSV_COLUMNS=TRUE`
      - `VP_CCT_TAB_AVAILABLE=TRUE`
      - `VP_CCT_QUICK_APPLY_TITLE_HAS_SIDE_TOP=TRUE`
      - `VP_CCT_APPLY_COMMODITY_BUTTON_PRESENT=TRUE`
      - `VP_CCT_VP_PANEL_COMMODITY_CONTROLS_PRESENT=TRUE`
      - `VP_CCT_VP_PANEL_COMMODITY_SYNCED_AFTER_APPLY=TRUE`
      - `VP_CCT_TOP_PANEL_COMMODITY_AFTER_APPLY=Asparagus`
      - Prior Step 4/5/6 guards remained green, including:
        - `VP_PACE_TARGET_REVERTED_AFTER_RESET=TRUE`
        - `VP_MAP_FIXTURE_TITLE_CONTAINS_CY=TRUE`
        - `VP_HEATMAP_ANALYSIS_INFO_EXCLUDES_BASIS=TRUE`
  - Step 8 checkpoint state:
    - Tranche-1 automated parse/smoke gate is green.
    - Awaiting user manual CCT confirmation before moving to Step 9 (MYC).

- 2026-07-22 Step 8 CCT follow-up polish: quick-apply and panel-control ordering.
  - User-requested UI adjustments implemented:
    - Quick Apply buttons reordered to:
      - Row 1: `Apply Commodity`, `Apply Type`
      - Row 2: `Apply Country`, `Apply Variable`
      - Row 3: `Top 3 Partners`, `Reset Defaults`
    - Removed full-width styling from `Reset Defaults` so it matches the other quick-apply buttons.
    - Reordered visible CCT panel controls for right/top-right, bottom-left, and bottom-right panels:
      - Row 1: panel Commodity, panel Type
      - Row 2: panel Metric, panel Country
    - Updated hidden spacer controls for left/top-left comparison panels to preserve visual alignment with the new two-row selector stack.
  - Validation evidence:
    - Parse checks passed:
      - `PARSE_OK:02_partner_and_notes.R`
      - `PARSE_OK:03_core_reactives_and_ui.R`
      - `PARSE_OK:vp_shinytest_smoke.R`
    - VP smoke CCT markers remained green:
      - `VP_CCT_TAB_AVAILABLE=TRUE`
      - `VP_CCT_QUICK_APPLY_TITLE_HAS_SIDE_TOP=TRUE`
      - `VP_CCT_APPLY_COMMODITY_BUTTON_PRESENT=TRUE`
      - `VP_CCT_VP_PANEL_COMMODITY_CONTROLS_PRESENT=TRUE`
      - `VP_CCT_VP_PANEL_COMMODITY_SYNCED_AFTER_APPLY=TRUE`
      - `VP_CCT_TOP_PANEL_COMMODITY_AFTER_APPLY=Asparagus`
    - Baseline VP guards remained green in the same run, including Data schema, Pace reset, Map CY label, Heatmap basis suppression, Reset, Share contract, and Austrian winter peas checks.
  - Step 8 checkpoint state:
    - Automated parse/smoke gate remains green after the layout polish.
    - Awaiting user manual CCT confirmation before moving to Step 9 (MYC).

- 2026-07-22 Step 8 CCT bugfix: projection and locked-scale failure with broad VP commodity contexts.
  - User-provided runtime log showed repeated CCT plot errors:
    - `Warning: Error in ||: 'length = 5' in coercion to 'logical(1)'`
    - Primary stack: `compute_projection(...)` in `VP Clone/Programs/app_source/server/04_comparison_plots.R`.
    - Secondary stacks through `top_left_y_range_debounced()` were downstream repeats caused by the scale-lock range reactive rebuilding the same failing top-left plot.
  - Root cause:
    - CCT top-left plot/projection path assumed one current value per `market_year`/`analysis_month` period.
    - VP broad contexts such as Type `All` can legitimately return multiple rows per period across several `CommodityName` records.
    - `current_value <- ... pull(current_value)` therefore returned a vector of multiple values, and `is.na(current_value)` produced multiple logical values inside a scalar `||` guard.
  - Patch applied in `VP Clone/Programs/app_source/server/04_comparison_plots.R`:
    - Added local scalar helpers for period aggregation:
      - `sum_metric_or_na(...)`
      - `first_date_or_na(...)`
    - Aggregated current-year plot rows by `analysis_month`/`market_year` before plotting.
    - Aggregated historical rows by `market_year`/`analysis_month` before computing historical average/range.
    - Aggregated projection-panel rows by `market_year`/`analysis_month` before `compute_projection(...)` current-period, historical-pattern, and linear-fit calculations.
  - Validation evidence:
    - Parse checks passed:
      - `PARSE_OK:04_comparison_plots.R`
      - `PARSE_OK:vp_shinytest_smoke.R`
    - VP smoke CCT markers remained green:
      - `VP_CCT_TAB_AVAILABLE=TRUE`
      - `VP_CCT_QUICK_APPLY_TITLE_HAS_SIDE_TOP=TRUE`
      - `VP_CCT_APPLY_COMMODITY_BUTTON_PRESENT=TRUE`
      - `VP_CCT_VP_PANEL_COMMODITY_CONTROLS_PRESENT=TRUE`
      - `VP_CCT_VP_PANEL_COMMODITY_SYNCED_AFTER_APPLY=TRUE`
      - `VP_CCT_TOP_PANEL_COMMODITY_AFTER_APPLY=Asparagus`
    - Baseline VP guards remained green in the same run, including Data schema, Pace reset, Map CY label, Heatmap basis suppression, Reset, Share contract, and Austrian winter peas checks.
  - Step 8 checkpoint state:
    - Automated parse/smoke gate remains green after the projection/scale-lock repair.
    - Awaiting user manual CCT confirmation before moving to Step 9 (MYC).

- 2026-07-22 User manual checkpoint completed: Step 8 Custom Comparison Tool confirmed.
  - User confirmation: "As far as I can tell, step 8 is complete. It looks wired correctly."
  - Step 8 moved from In Progress -> Complete (User Confirmed).

- 2026-07-22 Step 9 (MYC) tranche-9A kickoff.
  - Documentation cleanup completed in this ledger:
    - removed duplicate Phase 4 `Close State Update (2026-07-22): Complete (User Confirmed).` line.
    - moved Step 9 and Phase 7 status to In Progress.
  - Implementation started with diagnostic MYC smoke instrumentation before behavior edits, per cache-first/evidence-first guardrails.

- 2026-07-22 Step 9 (MYC) tranche-9A implementation and validation attempt.
  - Implemented diagnostic smoke instrumentation in `VP Clone/System/Testing/vp_shinytest_smoke.R`:
    - Added artifact-backed MYC fixture discovery helper (`find_vp_myc_type_mode_fixture(...)`) for deterministic VP context logging.
    - Added MYC smoke marker variables for tab availability, partner selector choice inventory, MYC plot/title/legend metadata, and table schema presence.
    - Added `VP_MYC_*` marker emissions to the smoke output block for tranche evidence capture.
    - Added plot legend title helper (`get_plotly_legend_title(...)`) to inspect MYC legend semantics in smoke.
  - Validation evidence (successful):
    - Parse checks passed repeatedly after each MYC smoke tranche patch:
      - `VP_SMOKE_PARSE_OK=TRUE` (multiple runs) for `VP Clone/System/Testing/vp_shinytest_smoke.R`.
  - Validation blocker (active):
    - Full `vp_shinytest_smoke.R` execution did not complete inside automation windows after MYC instrumentation; runs were interrupted/timed out before final marker dump.
    - First instrumentation attempt likely induced reactive churn in MYC selection paths; probe block was reduced to read-only diagnostics (no partner selection writes, no MYC mode toggling) to reduce feedback-loop risk.
    - Even with reduced probe, smoke completion remained non-deterministic in this environment due to long-running `Rscript`/`shiny::runApp('VP Clone')` process state and terminal tooling timeout behavior.
    - Operational evidence captured during investigation:
      - repeated long-running `Rscript.exe` pairs for `vp_shinytest_smoke.R`.
      - stale background `shiny::runApp('VP Clone', ...)` processes from prior sessions (ports `4747`, `3842`) present and repeatedly cleaned.
      - redirected smoke logs (`_tmp_step9a_smoke*.log`) showed only startup warnings (`Loading required package: testthat`, package build-version warnings) before abort/timeout handling paths.
  - Interim conclusion:
    - Tranche 9A code instrumentation is in place and parse-stable.
    - End-to-end smoke completion for this tranche remains blocked by execution stability in current runtime session; MYC behavior wiring changes are intentionally deferred until stable smoke completion evidence can be collected.
  - Next tranche entry criteria:
    - obtain one clean full smoke completion (with `VP_SHINYTEST_IDLE=TRUE` and new `VP_MYC_*` lines emitted) after runtime cleanup.
    - then proceed to tranche-9B server/UI behavior fixes with marker-driven diffs.

- 2026-07-22 Step 9 (MYC) tranche-9A focused probe follow-up (deterministic baseline capture).
  - To avoid unstable full-harness runtime behavior, executed a focused MYC-only probe script:
    - `VP Clone/System/Testing/_tmp_myc_probe_run.R`
  - Parse/status:
    - `MYC_PROBE_PARSE_OK=TRUE`
    - `VP_MYC_PROBE_OK=TRUE`
  - Marker evidence captured from focused probe run:
    - `VP_MYC_TAB_AVAILABLE=TRUE`
    - `VP_MYC_PARTNER_SHOW_CHOICES=` (empty)
    - `VP_MYC_PARTNER_SHOW_NON_ACTION_CHOICES=` (empty)
    - `VP_MYC_PARTNER_SHOW_HAS_CHOICES=FALSE`
    - `VP_MYC_PLOT_TITLE=` (empty)
    - `VP_MYC_PLOT_LEGEND_TITLE=` (empty)
    - `VP_MYC_PLOT_X_AXIS_TITLE=` (empty)
    - `VP_MYC_PLOT_TRACE_COUNT=0`
    - `VP_MYC_TABLE_COLUMNS=` (empty)
    - `VP_MYC_TABLE_HAS_COLUMNS=FALSE`
    - `VP_MYC_MEASURE_MODE_INPUT_PRESENT=TRUE`
    - `VP_MYC_COMPARISON_MODE_INPUT_PRESENT=TRUE`
  - Interpretation:
    - MYC UI controls are present and tab is reachable.
    - MYC data surfaces (partner choices, plot traces, table columns) are not populating in this baseline path, giving a clear tranche-9B starting defect signature.
  - Next action:
    - enter tranche 9B server/reactive wiring diagnosis using this marker baseline (priority: `partner_show` choices population and `partner_share_data()` / `market_year_partner_plot_state()` readiness chain).

- 2026-07-22 Step 9 (MYC) user-facing evidence superseded the headless probe interpretation.
  - User provided browser screenshots and runtime PERF log showing the Market Year Comparison Tool loads correctly in the visible app.
  - User-facing evidence observed:
    - MYC tab is reachable and active.
    - Sidebar controls render for Type Analysis / country display mode.
    - `partner_show` is populated with country selections (`Canada`, `Mexico`, `Aruba`, `Jamaica`, `Sint Maarten`).
    - stacked partner plot renders with title `Accumulated Exports through May - All`, partner legend, visible bars, and `All Other` grouping.
    - Market Year Table renders with `Country`, `Unit/Basis`, `CY 2023`, `CY 2024`, `CY 2025`, `Historical Avg`, and `CY 2026` columns.
  - Runtime PERF evidence from the user log confirms the server chain is healthy after tab activation:
    - `partner_share_data(): status=ok, source=vp_trade, comparison_mode=country, metric=ytd_exports, rows=38, eligible_partners=18, default_selection=5, auto_display_partners=6, displayed_years=4`.
    - `market_year_partner_plot_state(): status=ok, plot_rows=29, display_partners=5, current_all_other_present=TRUE, historical_all_other_present=TRUE`.
    - `myc_market_year_table: status=ok, rows=7, cols=7, mode=value, comparison_mode=current, current_year_header=CY 2026, baseline_header=Historical Avg`.
    - `partner_share_plot: source=vp_trade, metric=ytd_exports, rows=29, partners=6`.
  - Revised interpretation:
    - The earlier focused probe markers (`partner_show` empty, plot/table empty) were a headless timing/observability artifact, not a product wiring failure.
    - MYC baseline country-comparison path appears user-facing functional.
    - Remaining Step 9 validation should focus on targeted manual confirmation and any mode-switch/table-mode edge cases, not broad server-chain repair.

- 2026-07-22 Step 9 (MYC) validation strategy reset: use live tracing / PERF logs for focused validation.
  - Removed the brittle MYC-specific smoke probes from `VP Clone/System/Testing/vp_shinytest_smoke.R` after user-facing evidence showed they were timing-sensitive and misleading.
  - Restored standard VP smoke harness passed after cleanup:
    - `VP_SHINYTEST_IDLE=TRUE`
    - `VP_CCT_VP_PANEL_COMMODITY_SYNCED_AFTER_APPLY=TRUE`
    - `VP_AWD_COUNTRY_CHOICES_INCLUDE_TAIWAN=TRUE`
    - `VP_RESET_TYPE_TO_ALL=TRUE`
    - `VP_RESET_COUNTRY_TO_WORLD=TRUE`
    - `VP_AUSTRIAN_WINTER_PEAS_EXPORT_WORLD_JULY_FIRST=TRUE`
  - Existing live-tracing hooks available for MYC-focused validation:
    - `options(rice_myc_transition_log = TRUE)` enables `[MYC_TRACE]` transition/sidebar-selection diagnostics.
    - `options(rice_myc_selectize_probe = TRUE)` enables MYC selectize probe paths for `partner_show` client/server selection inspection.
    - PERF log lines already expose the core server readiness chain: `partner_share_data()`, `market_year_partner_plot_state()`, `myc_market_year_table`, and `partner_share_plot`.
  - Recommended validation log packet for MYC manual checks:
    - switch into MYC default Type Analysis / country display mode.
    - toggle Country Analysis mode and back.
    - change `Analyze through month`.
    - toggle Market Year Table `Shares` and `Comparison`.
    - optionally select/remove one partner in `partner_show`.
    - capture PERF/MYC trace lines around those actions, especially any `status=empty`, `status=no_share_data`, `metric_missing`, or selectize/client probe mismatch events.

- 2026-07-22 Step 9 (MYC) tranche-9B user-observed commodity-switch and label issues.
  - User reported three real MYC sidebar defects during live validation:
    - after switching VP commodity name to Asparagus, MYC required pressing Reset before proper country choices appeared.
    - MYC mode labelled `Country Analysis` (type-comparison mode, stacked bars by type) showed only `All` in the show-types selector.
    - MYC sidebar text still contained clone leftovers: almond-specific show-types text, almond reset note text, and `Sort Rice Types By:`.
  - Live trace reproduced the core type-mode symptom before repair:
    - `comparison_mode=type`, `commodity=All`, `partner_choices=1`, `display_partner_sample=All`.
    - `partner_share_data(): status=ok ... comparison_mode=type ... eligible_partners=1 ... default_selection=1`.
    - selectize probe showed `choice_count=2` only because one choice was the action row and the sole real value was `All`.
  - Root-cause interpretation:
    - MYC had a commodity-change reset observer for country-comparison mode only; type-comparison mode did not receive the same reseed path after commodity changes.
    - VP Trade base-data conversion filtered to the current `commodity_choice` detail even in MYC type-comparison mode, so type mode could compare only the selected aggregate/detail instead of all details within the selected VP commodity name.
    - UI metadata still used rice/almond-era labels in MYC type mode.
  - Code changes in `VP Clone/Programs/app_source/server/02_partner_and_notes.R`:
    - Generic MYC type-mode labels: `Type`, `Show types separately:`, `Click in the box to choose types.`, `Unselected types are grouped into All Other.`, and `Type to search types...`.
    - Generic MYC sort label: `Sort Types By:`.
    - Commodity-change reset observer now handles both MYC comparison modes (`country` and `type`).
    - Added VP commodity-name-change reset observer for MYC when source is `vp_trade`.
    - In MYC type-comparison mode, VP Trade base-data conversion no longer filters to the current commodity detail; it keeps the selected VP commodity-name universe so the show-types selector can populate with all available details/types.
  - Validation evidence so far:
    - `PARSE_OK:02_partner_and_notes.R` after label/reset edits.
    - `PARSE_OK:02_partner_and_notes.R` after VP type-mode data-path edit.
    - VS Code diagnostics: no errors found in `02_partner_and_notes.R`.
    - Fresh traced app launched with PERF/MYC tracing on `http://127.0.0.1:4747` for focused user confirmation.
    - Fresh live trace after repair shows MYC type-comparison mode now populates multiple type choices for Asparagus without needing Reset:
      - `partner_repopulation_observer_exit ... partner_choices=4, resolved_selection_size=3`.
      - `display_partner_sample=All | Asparagus | Unspecified`.
      - `partner_share_data(): status=ok ... comparison_mode=type ... rows=28, eligible_partners=4, default_selection=3, auto_display_partners=3`.
      - `market_year_partner_plot_state(): status=ok ... plot_rows=20, display_partners=3, current_all_other_present=TRUE, historical_all_other_present=TRUE`.
      - `myc_market_year_table: status=ok, rows=5, cols=7`.
      - selectize client/server probe matched: `choice_count=5`, `client_selected_values=All|Asparagus|Unspecified`, `server_selected_values=All|Asparagus|Unspecified`.
    - Clone-label cleanup grep passed for the reported MYC labels:
      - no remaining `Show almond types`, `almond types`, or `Sort Rice Types` text in `02_partner_and_notes.R`.
      - expected generic labels present: `Show types separately:` and `Sort Types By:`.
    - Standard VP smoke passed after repair:
      - `VP_SHINYTEST_IDLE=TRUE`.
      - `VP_CCT_VP_PANEL_COMMODITY_SYNCED_AFTER_APPLY=TRUE`.
      - `VP_CCT_TOP_PANEL_COMMODITY_AFTER_APPLY=Asparagus`.
      - `VP_AWD_COUNTRY_CHOICES_INCLUDE_TAIWAN=TRUE`.
      - `VP_RESET_TYPE_TO_ALL=TRUE`.
      - `VP_RESET_COUNTRY_TO_WORLD=TRUE`.
      - `VP_AUSTRIAN_WINTER_PEAS_EXPORT_WORLD_JULY_FIRST=TRUE`.
  - Pending validation:
    - user manual check: confirm `Show types separately` has multiple type choices without pressing Reset and clone labels are gone in the visible app.

- 2026-07-22 Step 9 (MYC) tranche-9C aggregate `All` boundary correction.
  - User clarified expected behavior:
    - VP Trade detail `All` should remain selectable in the normal sidebar and other tabs.
    - `All` should not appear as a selectable comparison type in the MYC type-comparison (`Country Analysis`) show-types selector.
    - `All` should not be counted as one of the stacked type components in that MYC calculation.
  - Initial attempted repair was too broad:
    - removed `All` from app-facing VP detail choices globally.
    - smoke showed this changed non-MYC behavior (`VP_INPUT_MAIN_COMMODITY=Globe`, reset type no longer `All`).
    - rejected because it violated the clarified contract.
  - Corrected implementation:
    - restored non-MYC VP detail choices so `All` remains selectable/default outside MYC.
    - restored Custom Comparison Tool panel type choices so `All` remains available there.
    - retained MYC type-mode-only exclusion in `commodity_choice_values()` by removing VP detail `All` only when `main_tabs_panel == Market Year Comparison Tool` and `market_year_compare_mode == type`.
    - retained MYC type calculation guard in `partner_snapshot()` so aggregate display labels are filtered from comparison items before `partner_share_data()` / plot/table state is built.
  - Validation evidence:
    - Parse checks passed for touched files:
      - `01_state_and_custom_types.R`
      - `02_partner_and_notes.R`
      - `03_core_reactives_and_ui.R`
      - `vp_shinytest_smoke.R`
    - VS Code diagnostics: no errors in touched files.
    - Standard VP smoke passed after narrowing:
      - `VP_SHINYTEST_IDLE=TRUE`
      - non-MYC contract restored: `VP_INPUT_MAIN_COMMODITY=All`, `VP_SIDEBAR_HAS_ALL_TYPE=TRUE`, `VP_SIDEBAR_DEFAULTS_TO_ALL=TRUE`, `VP_RESET_TYPE_TO_ALL=TRUE`.
      - existing regression markers still green: `VP_CCT_VP_PANEL_COMMODITY_SYNCED_AFTER_APPLY=TRUE`, `VP_AWD_COUNTRY_CHOICES_INCLUDE_TAIWAN=TRUE`, `VP_AUSTRIAN_WINTER_PEAS_EXPORT_WORLD_JULY_FIRST=TRUE`.
    - Fresh traced app restarted on `http://127.0.0.1:4747` for MYC-only visual confirmation.

- 2026-07-22 Step 9 (MYC) tranche-9C follow-up: VP aggregate label `All` was still visible in MYC type mode.
  - User observed `All` still present in MYC `Country Analysis` / show-types selector after the narrowed patch and suggested cache purge/rebuild as a possibility.
  - Diagnosis:
    - Not treated as an artifact-cache issue.
    - The MYC type-mode calculation already used `partner_snapshot()` to filter aggregate display labels via `is_all_rice_display_label(...)`.
    - That predicate covered `All Rice` variants but did not cover the VP Trade aggregate detail label `All`, so VP `All` survived into `comparison_item`, `partner_share_data()`, and the show-types selectize choices.
  - Fix:
    - Added plain `All` to `is_all_rice_display_label(...)` in `02_partner_and_notes.R`.
    - This keeps non-MYC sidebar behavior intact while excluding VP aggregate `All` from MYC type-comparison items.
  - Validation evidence:
    - `PARSE_OK:02_partner_and_notes.R`.
    - VS Code diagnostics: no errors in `02_partner_and_notes.R`.
    - Standard VP smoke passed after the filter update, preserving non-MYC contract:
      - `VP_INPUT_MAIN_COMMODITY=All`.
      - `VP_SIDEBAR_HAS_ALL_TYPE=TRUE`.
      - `VP_SIDEBAR_DEFAULTS_TO_ALL=TRUE`.
      - `VP_RESET_TYPE_TO_ALL=TRUE`.
      - `VP_SHINYTEST_IDLE=TRUE` and core regression markers green.
    - Fresh traced app restarted on `http://127.0.0.1:4747` so visible-browser MYC validation uses the updated code path.

- 2026-07-22 Step 9 (MYC) tranche-9D commodity-switch blank-state repair in `Country Analysis` / type mode.
  - User reported that MYC type mode looked correct initially (`All` absent, totals no longer aggregating it), but switching top commodity while staying in `Country Analysis` blanked the screen.
  - Live trace evidence:
    - after commodity switch, `filtered_data(): source=vp_trade ... commodity=Asparagus, rows=0`.
    - `panel_commodity_correction` detected the stale sidebar detail was invalid for the new top commodity: `commodity_choice_invalid=TRUE`, `current_choice=Asparagus`, `valid_choices=1`, `valid_choices_sample=Globe`, `fallback=Globe`.
    - correction scope was `hidden_panel_only` with `input_updates=0`, so the observer computed the right fallback but did not update the visible/sidebar `commodity_choice` in MYC type mode.
    - subsequent MYC reset cleared `partner_show`; final client probe showed `choice_count=0`, `client_selected_count=0`, `server_selected_count=0`.
  - Root cause:
    - top commodity changes can make the current sidebar type/detail illegal under the new VP commodity-name universe.
    - existing panel correction repaired hidden CCT panel state but did not repair the main `commodity_choice` input while MYC type mode was active.
    - MYC type mode then ran through a transient no-data / no-legal-choice state and left the client selectize empty.
  - Fix in `01_state_and_custom_types.R`:
    - when `main_tabs_panel == Market Year Comparison Tool`, `market_year_compare_mode == type`, and `commodity_choice` is invalid for current `commodity_choice_fallback_values()`, call `mark_myc_automatic_commodity_fallback(...)` and `updateSelectizeInput(session, "commodity_choice", selected = fallback)`.
    - incremented the correction input-update counter so trace/PERF output reflects that the visible input was repaired, not only hidden panel state.
  - Validation evidence:
    - `PARSE_OK:01_state_and_custom_types.R`.
    - VS Code diagnostics: no errors in `01_state_and_custom_types.R`.
    - Standard VP smoke passed after the transition fix, preserving non-MYC `All` behavior:
      - `VP_INPUT_MAIN_COMMODITY=All`.
      - `VP_SIDEBAR_HAS_ALL_TYPE=TRUE`.
      - `VP_SIDEBAR_DEFAULTS_TO_ALL=TRUE`.
      - `VP_RESET_TYPE_TO_ALL=TRUE`.
      - `VP_SHINYTEST_IDLE=TRUE` and existing CCT/AWD/reset/share markers green.
    - Fresh traced app restarted on `http://127.0.0.1:4747` for repeat manual commodity-switch validation.

- 2026-07-22 Step 9 (MYC) tranche-9D follow-up: automatic fallback still triggered a late clear.
  - User reported the blank-state issue recurred after the visible `commodity_choice` fallback repair.
  - Live trace showed the fallback repair was partly working:
    - `panel_commodity_correction ... input_updates=1, commodity_choice_invalid=TRUE, current_choice=Globe, valid_choices=3, valid_choices_sample=Asparagus | Prepared or preserved, unspecified | Unspecified, correction_scope=visible_inputs`.
    - MYC repopulated successfully at first: `update_partner_show_input ... choices=4, selected=2`, `display_partner_sample=Asparagus | Unspecified`, `myc_market_year_table: status=ok`.
  - Failure that remained:
    - the programmatic fallback commodity change then fired the normal MYC `input$commodity_choice` observer.
    - because it looked like a non-manual commodity change, the observer ran `reset_mode=default_reseed`.
    - that late reseed called `clear_partner_show_input(...)` after valid show-types values were already present, ending with client probe `choice_count=0`, `client_selected_count=0`, `server_selected_count=0`.
  - Fix in `02_partner_and_notes.R`:
    - MYC `input$commodity_choice` observer now detects type-mode automatic commodity fallback values via `is_myc_automatic_commodity_value(input$commodity_choice)`.
    - for that branch, it uses `reset_mode="preserve_legal_current_context"` instead of `default_reseed`, preventing the late force-default clear after the fallback has landed.
  - Validation evidence:
    - Parse checks passed for `01_state_and_custom_types.R` and `02_partner_and_notes.R`.
    - VS Code diagnostics: no errors in those files.
    - Standard VP smoke passed after the guard; non-MYC `All` behavior remains green (`VP_INPUT_MAIN_COMMODITY=All`, `VP_SIDEBAR_HAS_ALL_TYPE=TRUE`, `VP_RESET_TYPE_TO_ALL=TRUE`).
    - Fresh traced app restarted on `http://127.0.0.1:4747` for another manual commodity-switch validation pass.

- 2026-07-22 Step 9 (MYC) tranche-9D second follow-up: stale detail event still reached `default_reseed`.
  - User reported another recurrence of the MYC type-mode blank-state after the automatic-fallback preserve branch.
  - Fresh live trace showed the previous guard was not sufficient:
    - visible fallback repair fired and selected a legal detail for the new VP commodity-name universe.
    - MYC briefly repopulated successfully (`update_partner_show_input ... choices=4, selected=2`; plot/table state returned `status=ok`).
    - a later `input$commodity_choice` event still ran `perform_myc_partner_selection_reset_enter ... reset_mode=default_reseed` and `clear_partner_show_input`, leaving the final selectize probe empty.
  - Revised root-cause interpretation:
    - the destructive event can be a stale/invalid detail event before the automatic fallback marker is visible to the observer, or an automatic fallback event that should not reseed at all.
    - relying only on `is_myc_automatic_commodity_value(...)` at reset-mode selection time was too late and too narrow for Shiny's reactive ordering during top commodity switches.
  - Fix in `02_partner_and_notes.R`:
    - the MYC `input$commodity_choice` observer now performs an early type-mode validity check against `commodity_choice_fallback_values()`.
    - if the current detail is not legal for the current top commodity, it logs `commodity_choice_observer_waiting_for_type_fallback` and returns before any `partner_show` reset can run.
    - if the current detail is an automatic MYC fallback value, it logs `commodity_choice_observer_skip_automatic_type_fallback` and returns before any `partner_show` reset can run.
    - normal valid user-driven type changes still use the existing manual-selection preserve/default-reseed logic.
  - Validation evidence:
    - `PARSE_OK:02_partner_and_notes.R`.
    - VS Code diagnostics: no errors in `02_partner_and_notes.R`.
    - Standard VP smoke passed after the stronger early-return guard:
      - `VP_SHINYTEST_IDLE=TRUE`.
      - non-MYC `All` contract remains green: `VP_INPUT_MAIN_COMMODITY=All`, `VP_SIDEBAR_HAS_ALL_TYPE=TRUE`, `VP_SIDEBAR_DEFAULTS_TO_ALL=TRUE`, `VP_RESET_TYPE_TO_ALL=TRUE`.
      - existing cross-tab guards remained green: `VP_CCT_VP_PANEL_COMMODITY_SYNCED_AFTER_APPLY=TRUE`, `VP_AWD_COUNTRY_CHOICES_INCLUDE_TAIWAN=TRUE`, `VP_AUSTRIAN_WINTER_PEAS_EXPORT_WORLD_JULY_FIRST=TRUE`.
    - Old traced app terminal was stopped and a fresh traced app was started on `http://127.0.0.1:4747` with `vp_perf_log`, `rice_myc_transition_log`, and `rice_myc_selectize_probe` enabled for repeat manual validation.
  - Pending validation:
    - user hard-refresh and repeat MYC `Country Analysis` top commodity switch.
    - expected trace should show either the new early-return markers or a normal valid transition, with no late `default_reseed` / `clear_partner_show_input` ending in `choice_count=0`.

- 2026-07-22 Step 9 (MYC) tranche-9D third follow-up: early-return guard trace error made the app look stalled.
  - User clicked through the requested MYC commodity-switch path and reported they could not tell if the app had stalled or crashed.
  - Liveness check showed the R process was still present/listening on port `4747`, so this was not a full process crash.
  - Live trace identified a server observer error during the new stale-detail early-return branch:
    - `Warning: Error in collapse_partner_values: could not find function "collapse_partner_values"`.
    - error source: `observeEvent(input$commodity_choice)` while building the diagnostic `valid_choice_sample` for `commodity_choice_observer_waiting_for_type_fallback`.
  - Interpretation:
    - the selection-state fix was still structurally correct, but the diagnostic trace payload called a helper that was not available in this server scope.
    - this could interrupt the commodity observer during the exact transition path we were trying to validate, making the UI appear stuck even though the process stayed alive.
  - Fix in `02_partner_and_notes.R`:
    - replaced the trace-only `collapse_partner_values(head(valid_commodity_values, 5L))` call with base R `paste(head(valid_commodity_values, 5L), collapse = " | ")`.
    - no selection/reset semantics changed.
  - Validation evidence:
    - `PARSE_OK:02_partner_and_notes.R`.
    - VS Code diagnostics: no errors in `02_partner_and_notes.R`.
    - Standard VP smoke passed after the trace-only fix:
      - `VP_SHINYTEST_IDLE=TRUE`.
      - non-MYC `All` contract remains green: `VP_INPUT_MAIN_COMMODITY=All`, `VP_SIDEBAR_HAS_ALL_TYPE=TRUE`, `VP_SIDEBAR_DEFAULTS_TO_ALL=TRUE`, `VP_RESET_TYPE_TO_ALL=TRUE`.
      - existing CCT/AWD/reset/share regression markers remained green.
    - Previous traced app was stopped because it had loaded the old observer code; a fresh traced app restart is in progress on `http://127.0.0.1:4747`.

- 2026-07-22 Step 9 (MYC) tranche-9D fourth follow-up: screenshot showed settled selector with blank outputs.
  - User provided a screenshot after the repeated MYC `Country Analysis` commodity-switch path.
  - Visible state in the screenshot:
    - top commodity was `Artichokes`.
    - MYC mode was `Country Analysis` / internal type mode.
    - `Show types separately` had settled on `Globe (100.0%)`.
    - plot/table output area below the controls was blank/missing, with no visible in-app exception banner in the captured viewport.
  - Live trace immediately before this showed no fresh R exception and no empty selectize terminal state:
    - `commodity_choice_observer_waiting_for_type_fallback` fired successfully after the trace-only helper fix.
    - final selectize probe remained populated with `choice_count=2`, `client_selected_values=Globe`, `server_selected_values=Globe`.
    - `partner_share_data()`, `market_year_partner_plot_state()`, `myc_market_year_table`, and `partner_share_plot` had returned `status=ok` during the transition.
  - Revised hypothesis:
    - the direct `commodity_choice` observer was now protected, but the top `vp_commodity_name_choice` observer could still run `default_reseed` while the visible detail fallback was stale or automatic.
    - that top-level reset could clear/reseed `partner_show` at the wrong point in the same transition window, producing the screenshot's settled-control / blank-output state.
  - Fix in `02_partner_and_notes.R`:
    - added the same MYC type-mode legality guard to `observeEvent(input$vp_commodity_name_choice, ...)`.
    - if the current detail is not legal for the new top commodity, the observer logs `vp_commodity_name_observer_waiting_for_type_fallback` and returns before resetting `partner_show`.
    - if the current detail is an automatic MYC fallback value, the observer logs `vp_commodity_name_observer_skip_automatic_type_fallback` and returns before resetting `partner_show`.
  - Validation evidence:
    - `PARSE_OK:02_partner_and_notes.R`.
    - VS Code diagnostics: no errors in `02_partner_and_notes.R`.
    - Standard VP smoke passed after the top-commodity observer guard, including `VP_SHINYTEST_IDLE=TRUE` and preserved non-MYC `All` markers.
    - Old traced app was stopped and a fresh traced app is listening on `http://127.0.0.1:4747` with MYC/PERF/selectize tracing enabled for repeat validation.

- 2026-07-22 Step 9 (MYC) tranche-9D fifth follow-up: server renders data but client output region remains blank.
  - User reported the blank-output symptom persists after the top-commodity guard and also occurs in an R-launched app instance, ruling out a browser-only issue.
  - Screenshot evidence after switching to top commodity `Asparagus`:
    - MYC `Country Analysis` mode remained selected.
    - `Show types separately` contained `Asparagus (92.8%)`.
    - plot/table output region below the controls remained blank/missing.
  - Live trace from the fixed traced instance showed the server-side data chain is healthy after the transition:
    - `partner_share_data(): status=ok ... comparison_mode=type ... rows=8, eligible_partners=3, default_selection=2, auto_display_partners=2`.
    - `market_year_partner_plot_state(): status=ok ... plot_rows=9, display_partners=2`.
    - `myc_market_year_table: status=ok, rows=4, cols=5`.
    - `partner_share_plot: source=vp_trade, metric=ytd_exports, rows=9, partners=3`.
    - final client/server selectize probe matched: `choice_count=4`, `client_selected_values=Asparagus|Unspecified`, `server_selected_values=Asparagus|Unspecified`.
  - Interpretation:
    - the active defect has shifted from server data/reset state to output DOM/client binding/visibility: controls repopulate and server render functions execute, but visible plot/table containers do not return.
  - Diagnostic instrumentation added:
    - extended the existing `rice_myc_selectize_probe` diagnostic channel with `request_myc_output_probe(...)` in `02_partner_and_notes.R`.
    - output probes are requested after `clear_partner_show_input(...)` and `update_partner_show_input(...)`.
    - added `captureMycOutputProbe` client handler in `ui.R` to report existence, visibility, width, height, display, visibility style, child count, and text length for:
      - `#partner_share_plot_scroll_container`.
      - `#partner_share_plot_width_container`.
      - `#partner_share_plot`.
      - `#myc_market_year_table`.
    - added server receiver `input$client_myc_output_probe` to log the measurements as `[MYC_TRACE] event=client_myc_output_probe`.
  - Validation evidence:
    - `PARSE_OK:myc_probe_files` for `02_partner_and_notes.R` and `ui.R`.
    - VS Code diagnostics: no errors in those files.
    - Standard VP smoke passed after probe instrumentation, preserving non-MYC `All` and cross-tab regression markers.
    - Probe-enabled traced app restart is in progress on `http://127.0.0.1:4747`.

- 2026-07-22 Step 9 (MYC) tranche-9D output-probe trace result.
  - User repeated the MYC `Country Analysis` commodity-switch path after the output DOM probe was loaded.
  - Live trace remained server-healthy:
    - `partner_share_data(): status=ok ... comparison_mode=type ... rows=8, eligible_partners=3, default_selection=2, auto_display_partners=2`.
    - `market_year_partner_plot_state(): status=ok ... plot_rows=9, display_partners=2`.
    - `myc_market_year_table: status=ok, rows=4, cols=5`.
    - `partner_share_plot: source=vp_trade, metric=ytd_exports, rows=9, partners=3`.
    - selectize probe matched client/server values: `Asparagus|Unspecified`.
  - New client output probe showed MYC output DOM nodes are present and visible after the transition:
    - `plot_scroll=exists=TRUE,visible=TRUE,width=686,height=612,display=block,visibility=visible,children=1,text=249`.
    - `plot_width=exists=TRUE,visible=TRUE,width=686,height=600,display=block,visibility=visible,children=1,text=249`.
    - `plot=exists=TRUE,visible=TRUE,width=686,height=600,display=block,visibility=visible,children=1,text=249`.
    - `table=exists=TRUE,visible=TRUE,width=686,height=209,display=block,visibility=visible,children=1,text=160`.
  - Interpretation:
    - The previous blank-output diagnosis is now narrower: server rendering is complete, Shiny output bindings exist, and the browser DOM reports nonzero visible plot/table containers.
    - If the viewport still appears blank in screenshots, next checks should focus on viewport scroll position/cropping, visual content styling/foreground/background contrast, Plotly canvas/SVG child rendering, or whether the visible capture is above the output region rather than the outputs being absent.

- 2026-07-22 Step 9 (MYC) tranche-9D sixth follow-up: stabilize plot output container ownership.
  - User screenshot still showed the plot area absent above `Market Year Table`, despite server render and client DOM probes reporting nonzero visible plot/table containers.
  - Additional local checks found only one `partner_share_plot` output ID, so duplicate stale output IDs were unlikely.
  - Working hypothesis:
    - the dynamic `uiOutput("partner_share_plot_scroll_ui")` wrapper could be removed/recreated during the same reactive transition that updates `partner_show`, leaving the active tab visually missing the plot container even though Shiny/DOM probes could observe an output node.
    - anchoring the Plotly output in static tab UI should make the output binding ownership stable across commodity/type transitions.
  - Fix:
    - replaced `uiOutput("partner_share_plot_scroll_ui")` in the MYC tab body with a static `div` containing `plotlyOutput("partner_share_plot", width="100%", height="600px")` inside the same scroll/width container IDs.
    - changed the old `output$partner_share_plot_scroll_ui` renderer to return `NULL`, avoiding a second owner for the same plot/container IDs.
  - Validation evidence:
    - `PARSE_OK:myc_static_plot_container` for `02_partner_and_notes.R` and `05_trend_and_heatmap.R`.
    - VS Code diagnostics: no errors in the touched files.
    - Grep check found no remaining `uiOutput("partner_share_plot_scroll_ui")` and only the static `plotlyOutput("partner_share_plot")` placement in the MYC tab body.
    - Standard VP smoke passed after the static-container change, preserving non-MYC `All` and cross-tab regression markers.
    - Traced app restart is in progress on `http://127.0.0.1:4747` for manual validation of the static output container.

- 2026-07-22 Step 9 (MYC) tranche-9D seventh follow-up: static plot container remains blank, force Plotly resize after MYC updates.
  - User reported the issue is still not resolved after the static plot container change.
  - New screenshot showed:
    - stable blank vertical plot region above the table section.
    - `Show types separately` populated with `Asparagus (92.8%)` and `Unspecified (4.5%)`.
    - sort controls visible below the selectize, indicating sidebar repopulation is stable.
  - Fresh trace after the static-container change still showed healthy server data and nonzero client output containers:
    - `partner_share_data(): status=ok`.
    - `market_year_partner_plot_state(): status=ok`.
    - `partner_share_plot: ... rows=9, partners=3`.
    - client output probe: `plot=exists=TRUE,visible=TRUE,width=703,height=600,... text=249`.
  - Revised interpretation:
    - MYC now has a stable output container, but Plotly content appears visually blank after the transition.
    - Next likely issue is Plotly hydration/resize/draw timing rather than missing Shiny data or missing DOM.
  - Fix/diagnostic change:
    - after `clear_partner_show_input(...)` and `update_partner_show_input(...)`, send the existing `forcePlotlyResize` client message for `Market Year Comparison Tool`.
    - extended the MYC output DOM probe to count Plotly internals: `.plotly`, `.main-svg`, `.barlayer path`, and `.legend` nodes.
    - extended server trace logging to include those counts in `client_myc_output_probe`.
  - Validation evidence:
    - `PARSE_OK:myc_plotly_resize_probe` for `02_partner_and_notes.R` and `ui.R`.
    - VS Code diagnostics: no errors in those files.
    - Standard VP smoke passed after the Plotly resize/probe update.
    - Traced app restart is in progress on `http://127.0.0.1:4747` for manual validation.

- 2026-07-22 Step 9 (MYC) tranche-9D eighth follow-up: Plotly SVG and bars exist but remain visually blank.
  - User repeated validation after resize trigger; screen still went blank in the MYC plot region.
  - Fresh trace showed the resize handler did run:
    - `[PERF][client] plotly_resize ... resized_count=1, visible_widget_count=1`.
  - Deeper DOM probe showed Plotly internals exist after the transition:
    - `plot=exists=TRUE,visible=TRUE,width=918,height=600,... plotly=1,svg=3,bars=9,legend=1`.
    - table remains visible with nonzero dimensions.
  - Interpretation:
    - Plotly is not merely an empty widget shell: SVGs, legend, and bar path nodes exist.
    - The problem is now narrowed to visual draw/geometry/style: drawn nodes are present but not visible in the user capture, likely due to offscreen/clipped/zero-sized/transparent bars or incomplete repaint.
  - Fix/diagnostic change:
    - strengthened the existing client `forcePlotlyResize` handler to call `Plotly.redraw(...)` after `Plotly.Plots.resize(...)` for visible widgets.
    - added delayed post-redraw MYC output probes after both `clear_partner_show_input(...)` and `update_partner_show_input(...)`.
    - extended DOM probe to report first bar bounding box and style (`first_bar_width`, `first_bar_height`, `first_bar_fill`, `first_bar_opacity`).
    - extended server logging to include those bar geometry/style fields.
  - Validation evidence:
    - `PARSE_OK:myc_plotly_redraw_probe` for `02_partner_and_notes.R` and `ui.R`.
    - VS Code diagnostics: no errors in those files.
    - Standard VP smoke passed after redraw/bar-probe changes.
    - Traced app restart is in progress on `http://127.0.0.1:4747`.

- 2026-07-22 Step 9 (MYC) sidebar-state pivot and patch audit.
  - New user-observed clue:
    - after switching the VP top commodity while in MYC `Country Analysis` / internal type mode, the `Comparison Basis`, `Years for Historical Average`, and `Analyze through month` controls disappear from the sidebar while the show-types selector remains present.
    - This makes the old Plotly-only hypothesis insufficient; the blank plot/table region is now treated as downstream until sidebar state is proven healthy.
  - Revised working hypothesis:
    - `comparison_basis_ui` depends on `reference_year_choices()`, which still derives years from hidden/sidebar `input$commodity_choice` via `filtered_data_for_country("GRAND_TOTAL", input$commodity_choice, ...)`.
    - In MYC type mode, that hidden detail value can be automatic/stale/transitional during top commodity switches while the real comparison universe should be the selected VP top commodity's non-aggregate detail set.
    - `myc_cutoff_controls_ui` depends on `partner_snapshot()` and cutoff period choices, so it must be traced alongside comparison-basis state before more plot fixes are attempted.
  - Patch retention audit:
    - retain generic MYC labels and MYC-only aggregate `All` exclusion unless later tests contradict them; they match user-facing clone cleanup and the clarified `All` contract.
    - keep automatic commodity fallback/observer guards provisionally; they solved stale-selection symptoms but may interact with the shared comparison controls through hidden `commodity_choice` dependencies.
    - treat MYC output DOM probes, Plotly internals/bar probes, and partner-selection-triggered Plotly redraws as likely diagnostic debt unless a final validated root cause still needs them.
    - remove the hard-coded top-bar helper text `Market Year Comparison Tool uses weekly data only.` as a Rice-clone artifact during cleanup.
  - Implementation tranche started:
    - add gated MYC trace instrumentation for `reference_year_choices()`, `comparison_basis_ui`, and `myc_cutoff_controls_ui` before behavior repair.
    - classify whether the sidebar controls render `NULL`, render empty, error/silent-abort, or are rendered server-side but hidden/removed client-side.
  - Tranche validation:
    - Parse check passed for `02_partner_and_notes.R` and `03_core_reactives_and_ui.R` with marker `PARSE_OK:myc_sidebar_trace`.
    - Standard VP smoke passed after the trace-only instrumentation.
    - Important preserved smoke markers include `VP_INPUT_MAIN_COMMODITY=All`, `VP_SIDEBAR_HAS_ALL_TYPE=TRUE`, `VP_SIDEBAR_DEFAULTS_TO_ALL=TRUE`, `VP_RESET_TYPE_TO_ALL=TRUE`, `VP_CCT_VP_PANEL_COMMODITY_SYNCED_AFTER_APPLY=TRUE`, and `VP_AUSTRIAN_WINTER_PEAS_EXPORT_WORLD_JULY_FIRST=TRUE`.
    - Traced app launch on port `4747` failed because the port was already in use; launch on port `4751` reached `Listening` but then exited; launch on port `4753` is running and should be used for the next manual MYC reproduction.
  - First manual reproduction trace after this patch:
    - MYC type-mode partner selector client/server state matched (`Asparagus|Unspecified` selected, four choices available).
    - Existing output probe showed the MYC plot/table DOM nodes were present and visible after the switch: plot scroll/width/plot containers existed with nonzero size, SVG/bar/legend nodes existed, and the table existed with nonzero text.
    - This trace still did not directly measure the sidebar output containers for `comparison_basis_ui` and `myc_cutoff_controls_ui`, so it could not prove whether the user-observed missing controls were server-empty, client-hidden, or replaced.
  - Follow-up instrumentation:
    - extended `captureMycOutputProbe` in `ui.R` to also report `#comparison_basis_ui` and `#myc_cutoff_controls_ui` container existence, visibility, dimensions, child count, and text length.
    - extended the server `client_myc_output_probe` trace in `02_partner_and_notes.R` to log those sidebar container summaries.
    - Parse check passed with marker `PARSE_OK:myc_sidebar_client_probe`.
    - Standard VP smoke passed after the sidebar container probe extension, preserving the same non-MYC `All` and CCT/AWD/reset markers.
    - Restarted traced app on `http://127.0.0.1:4753` with the expanded sidebar probe active.
  - Second manual reproduction trace with sidebar container probe:
    - User screenshot still showed the `Comparison Basis` radio block missing while MYC type selector remained visible.
    - Probe classified the issue as server-output clearing rather than a missing DOM mount: `#comparison_basis_ui` and `#myc_cutoff_controls_ui` containers existed, but after the switch both had `children=0`, `text=0`, and `height=0`.
    - Plot and table containers still existed with nonzero dimensions and content, so sidebar output invalidation remains the controlling symptom.
  - Behavior fix:
    - changed `reference_year_choices()` in `03_core_reactives_and_ui.R` so MYC `Country Analysis` / internal type mode derives year choices from `selected_data()` instead of requiring hidden/stale `input$commodity_choice` and `filtered_data_for_country("GRAND_TOTAL", input$commodity_choice, ...)`.
    - The new branch logs `reference_year_choices_ready` with `branch=myc_type_selected_data` so the next trace can verify it is active.
  - Validation after behavior fix:
    - Parse check passed with marker `PARSE_OK:myc_reference_years_fix`.
    - Standard VP smoke passed after the reference-year fix, preserving non-MYC `All`, reset, CCT, AWD, and Austrian winter peas markers.
  - Follow-up validation after reference-year fix:
    - User reported the comparison selector block still disappeared after hard refresh and repeat commodity switch.
    - Trace showed `comparison_basis_ui` and `myc_cutoff_controls_ui` were populated immediately after `update_partner_show_input`, then both were emptied by the delayed post-redraw probe (`children=0`, `text=0`, `height=0`).
    - Because `myc_cutoff_controls_ui` should always return a wrapper on the MYC tab, this points beyond a pure year-choice value issue and toward Shiny output suspension/clearing during sidebar redraw.
  - Additional behavior fix:
    - added `outputOptions(output, "comparison_basis_ui", suspendWhenHidden = FALSE)` in `03_core_reactives_and_ui.R`.
    - added `outputOptions(output, "myc_cutoff_controls_ui", suspendWhenHidden = FALSE)` in `02_partner_and_notes.R`.
    - This matches the existing always-live treatment for `market_year_compare_filters_ui` and tests whether the two independent sidebar outputs were being suspended/cleared during the MYC transition.
  - Validation after suspension fix:
    - Parse check passed with marker `PARSE_OK:myc_sidebar_suspend_fix`.
    - Standard VP smoke passed after the output suspension fix, preserving the same non-MYC `All`, reset, CCT, AWD, and Austrian winter peas markers.

## Closeout Checklist

- [x] Baseline parse/smoke logged.
- [x] Historical Trendlines wired, validated, and user-confirmed.
- [x] Pace wired, validated, and user-confirmed.
- [x] Map wired, validated, and user-confirmed.
- [x] Monthly Heatmap wired, validated, and user-confirmed.
- [x] Data wired, validated, and user-confirmed.
- [x] Custom Comparison wired, validated, and user-confirmed.
- [ ] MYC wired, validated, and user-confirmed.
- [ ] Final cross-tab regression pass complete.
- [ ] Summary finalized.

## Summary

Pending implementation. This section will be updated at closeout with a layman-friendly summary of scope, outcome, tab-by-tab status, bugs investigated, blockers encountered, and how they were resolved or deferred.