# VP Faceted Top Filters Implementation Plan

Date: 2026-07-28
Branch: main
Status: Focused implementation complete; reset alignment cluster polish applied; visual confirmation and broader smoke/perf validation remain open. This file is the source of truth for VP faceted top-filter implementation.

## Objective
Implement VP top-bar faceted hierarchy behavior so Group, Subgroup, and Market Segment can each be changed at any time, each narrows the others, and Commodity choices narrow accordingly while remaining downstream.

## Scope
Included:
- Independent faceted behavior for VP hierarchy controls: Group, Subgroup, Market Segment.
- Commodity choice narrowing based on current hierarchy filter context.
- Hierarchy reset button to the right of Market Segment.
- Strict rollup path preservation for strict all-selection paths.
- Sparse-selection native filtering path with resolver mode metadata.
- Cache key hardening for resolver-mode-sensitive surfaces.
- PERF instrumentation updates and smoke coverage updates.

Excluded in first pass:
- Dotted divider or additional visual separators beyond reset-button placement/spacing.
- Sparse faceted partition-materialization pipeline expansion.
- Non-VP source behavior changes.

## Decisions
- Sparse hierarchy selections use faceted native filtering semantics over native/non-rollup rows.
- Commodity is downstream of Group/Subgroup/Market Segment and does not narrow those three filters.
- On hierarchy conflicts, keep the changed hierarchy control and clear incompatible hierarchy siblings to All.
- Reset button acts as both function and visual separator between hierarchy filters and Commodity.
- Strict rollup paths continue to use existing partition-provider behavior.
- Sparse faceted mode bypasses partition materialization in first pass and filters in memory.
- Add a rollback-friendly feature flag for faceted hierarchy behavior.

## Risk Guardrails
- Do not partially migrate resolver logic; all downstream VP hierarchy consumers must use consistent semantics.
- Do not mix rollup rows with native rows in sparse faceted mode.
- Do not allow cache collisions between strict rollup and faceted native contexts.
- Do not expand partition-file cardinality for sparse faceted one-off combinations in first pass.
- Preserve existing All - excluding juice and mixed-volume unit-value protections.
- Keep release gated on parse, behavioral smoke checks, and hierarchy transition perf checks.

## Resolved Focused Blocker: Faceted Native Repeated Scans
The original Dried transition failure had two pieces. The zero-row/builder-sentinel path is mitigated: staged probes can now converge to `segment=Dried`, `vp_commodity_name=Austrian winter peas`, `type=All`, and non-empty summary output. The separate repeated-scan performance/reactive-stability defect was then diagnosed and repaired for the focused Dried tranche.

Latest user console evidence shows repeated full-table faceted direct scans after selecting `Market Segment = Dried`:
- `resolution_mode=faceted_native`
- `path_name=P0_faceted`
- `input_rows=2115868`
- repeated direct-filter elapsed times around 1-5 seconds
- alternating output row counts that appear to reflect different semantic layers, including a broad hierarchy/export/Dried slice around `91910` rows and a narrow effective top-commodity/detail slice around `278` rows.

This was not just a `country_choice` issue and was not residual `shinytest2::wait_for_idle()` noise. Purpose-tagged diagnostics showed repeated expensive recomputation across support/context callers, especially `mixed_volume_family_check` and `quantity_units_context`. The focused repair added a session-scoped Stage-A faceted hierarchy cache so identical hierarchy/trade slices are computed once and reused before Commodity/Type filtering. Post-cache evidence showed one miss around 2.72 seconds followed by repeated cache hits around 0.006-0.048 seconds, and the focused Dried output probe settled by loop 3 and stayed stable through loop 8 without heavy runtime JSON logging.

Residual limitation: broader smoke/perf validation remains deferred because the `shinytest2` harness can still report `wait_for_idle()` and control-discovery instability in this workspace. That is now treated as validation/harness work, not an active app-behavior blocker for the focused fix.

## Row-Slice Semantics by Caller
| Caller / Consumer | Intended row slice | Notes |
|---|---|---|
| Group choices | Native hierarchy-choice slice constrained by selected Subgroup, selected Market Segment, and trade flow; ignore current Group while building Group choices | Keeps the changed/sibling hierarchy menus mutually narrowing without forcing parent fallback. |
| Subgroup choices | Native hierarchy-choice slice constrained by selected Group, selected Market Segment, and trade flow; ignore current Subgroup while building Subgroup choices | Must preserve the most recently changed control when conflicts are resolved. |
| Market Segment choices | Native hierarchy-choice slice constrained by selected Group, selected Subgroup, and trade flow; ignore current Market Segment while building Segment choices | Dried-first and segment-first paths must not collapse back to strict fallback. |
| Top Commodity choices | Stage-A hierarchy slice plus trade flow, without stale top-Commodity filtering | Invalid browser values such as prior `Artichokes` under Dried must not restrict Commodity choices. |
| Type / CommodityDetail choices | Stage-A hierarchy slice plus effective top Commodity | Must prefer valid in-slice values and avoid treating `__custom_builder__` as a data filter. |
| Country choices | Recommended default: same effective selected-data context as the main data output | If a broader hierarchy-only country UX is desired later, document it as an explicit UX change before implementation. |
| Summary, plots, maps, trend, comparison, and pace outputs | Effective selected-data rows: hierarchy + trade flow + effective top Commodity + effective Type/detail + country/date/metric/panel filters | These callers should not each rescan the full VP artifact for the same stage-A hierarchy tuple. |

Broad counts such as `91910` and narrow counts such as `278` can both be correct when they correspond to different semantic layers. The bug is repeated expensive recomputation, weak caller-context visibility, and stale-state churn, not either row count in isolation.

## Shared Context and Cache Design
- Do not blindly memoize the whole `filter_vp_rows_for_resolved_hierarchy()` helper; callers use it for hierarchy-only rows, Commodity choices, Type/detail choices, country choices, and selected data. A generic cache risks hiding semantic mistakes.
- Split faceted sparse filtering into explicit stages:
	- Stage A: resolve trade flow + hierarchy + mode/path and produce the native faceted hierarchy slice once per distinct tuple.
	- Stage B: apply effective top Commodity and Type/detail filters to the Stage-A slice.
	- Stage C: apply final output filters such as country, date, metric, and panel-specific selectors.
- Recommended ownership: keep pure resolver/filter helpers near `filter_vp_rows_for_resolved_hierarchy()` in `02_partner_and_notes.R`; keep session-scoped reactive context ownership near core selected/base data and country consumers in `03_core_reactives_and_ui.R` if implementation confirms that is the narrowest owning surface.
- Use session-scoped reactive caching rather than a long-lived global data-frame cache to avoid quiet memory retention.
- Key the Stage-A cache by trade flow, resolver mode, resolved path, active Group/Subgroup/Market Segment filters, faceted feature-flag state, and VP artifact/source signature where available. Do not key large cached rowsets only by `nrow(vp_rows)`.
- Keep strict rollup paths on the existing partition provider. Only sparse `faceted_native` paths should use the shared native hierarchy-slice cache in this tranche.
- If shared context/cache still leaves sparse transitions too slow, design a later dedicated `faceted_native` index or partition namespace. Do not overload strict rollup partition-provider semantics.

## Diagnostic Requirements for Next Tranche
- Add a `caller` or `purpose` argument where feasible for diagnostic wrappers/helper calls; use `sys.calls()` only as temporary fallback evidence.
- Required caller buckets: hierarchy choice builder, top Commodity choice builder, Type choice builder, country choice builder, selected/base data, summary table, plots/maps/trend, comparison panels, and pace analysis.
- Log hierarchy tuple, effective top Commodity, effective Type/detail, trade flow, mode/path, input/output rows, elapsed time, and cache hit/miss.
- Keep verbose diagnostics behind an env/option flag such as `VP_FACETED_FILTER_DEBUG=true`, but retain a small permanent PERF summary for mode/path, rows, cache hit/miss, and elapsed time.

## Reset UI Decisions
- Remove the bottom sidebar `reset_btn` visible reset surface in this tranche.
- Keep `vp_reset_hierarchy_filters` hierarchy-only: it clears Group, Subgroup, and Market Segment, and must not clear Commodity, Type, country, date, or metric controls.
- If a full reset workflow is still needed later, add a distinct future `Reset All` control or equivalent. Do not overload the hierarchy reset icon.
- Refactor or remove `observeEvent(input$reset_btn, ...)` in `06_pace_analysis_and_reset.R` after verifying no tests/harnesses still rely on the old DOM id.
- Align the top reset button to the select input boxes, not the label text. Use CSS/class-based alignment, consistent input height, compact width, disabled state when all hierarchy filters are `__all__`, and a tooltip/title such as `Clear Group, Subgroup, and Market Segment`.

## Additional Blockers and Release Risks
- Decided for this tranche: country-choice semantics follow the same effective selected-data context as the main output unless a broader hierarchy-only country UX is requested later.
- Mitigated for current scope: stale browser input values after `renderUI` are corrected by server-side effective Commodity/Type handling and Stage-A hierarchy slicing. This remains a regression risk for future reactive refactors.
- Addressed for current immutable-session artifact assumption: Stage-A cache keys include input row count, resolver mode/path, trade flow, hierarchy filters, and faceted flag state. Future hardening can add an explicit artifact/source signature if VP artifacts can mutate within a session.
- Addressed for current scope: the bottom `reset_btn` was removed, the obsolete observer was deleted, and the smoke harness no longer targets the old DOM id. A future full reset should be a distinct `Reset All` workflow, not the hierarchy reset icon.
- Residual validation limitation: `shinytest2::wait_for_idle()` instability must not be treated as proof of app failure without explicit input/output state evidence.
- UI polish validation pending: the top hierarchy reset button now shares an explicit flex cluster with Group/Subgroup/Market Segment, uses the same 34px input height target, and leaves a larger gap before Commodity to show Commodity is downstream. Manual/screenshot confirmation remains open.

## Implementation Ledger
| Step | Work | Status | Notes |
|---|---|---|---|
| 1 | Create source-of-truth plan file in VP Clone Code Review | Complete | This file created before code edits. |
| 2 | Implement resolver mode contract (`strict_rollup` vs `faceted_native`) | Complete | Added mode-aware canonicalization plus feature-flag fallback (`vp_faceted_hierarchy_enabled`). |
| 3 | Implement hierarchy filtering branch in VP row filter helper | Complete | Strict path keeps provider filters; faceted/native path strips rollups and filters native rows in memory. |
| 4 | Rework top-bar hierarchy option building to mutual narrowing | Complete | Added shared hierarchy choice-state builder that preserves changed control and clears incompatible siblings. |
| 5 | Add reset button behavior and disabled-state UX | Complete | Added reset action button between Market Segment and Commodity with disabled-state behavior when already reset. |
| 6 | Apply resolver-aware cache key updates across VP surfaces | Complete | Added resolver-mode/path/cache-filter fragments to filtered data, country-choice, comparison, trend, map runtime, and pace context keys. |
| 7 | Add rollout flag, instrumentation, and branch logging | Complete | Added resolver feature flag and branch-level PERF logging (`filter_vp_rows_for_resolved_hierarchy()`) including mode and row counts. |
| 8 | Update smoke/perf coverage and run validation | Complete for focused tranche; broader smoke/perf deferred | Parse checks passed. Dried staged output probe converges and stays stable. Static reset validation passed. Stage-A PERF evidence shows repeated identical faceted native hierarchy slices now hit cache after one miss. Remaining: harden shinytest startup/idle harness for deterministic full smoke/perf pass in this environment. |
| 9 | Final summary and closeout | Complete for focused tranche | Lay summary below now distinguishes completed app behavior, repaired Dried performance issue, residual harness limitations, and reset alignment polish. |
| 10 | Add Dried repeated-scan diagnostics | Complete | Added `vp_filter_purpose` support, `VP_FACETED_FILTER_DEBUG`/`vp_faceted_filter_debug` gate, and caller labels for Type choices, quantity checks, base/filtered data, custom comparison panels, and display-month mapping. Parse-clean. |
| 11 | Define row-slice semantics by caller | Complete | Row-slice semantics table above served as the implementation contract; update if country-choice UX decision changes. |
| 12 | Implement shared faceted hierarchy context/cache | Complete | Added per-session Stage-A cache for faceted native hierarchy/trade slices before Commodity/Type filtering. Post-cache PERF shows one miss and subsequent hits around 0.01-0.05 seconds instead of repeated multi-second native scans. |
| 13 | Normalize effective commodity/type/country inputs from shared context | Mitigated for current scope | Dried transition is protected by effective server-side Commodity/Type handling and selected-data country semantics. Broader cross-consumer effective-value audit remains optional future hardening. |
| 14 | Guard downstream UI updates against reactive ping-pong | Mitigated for current scope | Transition probes now converge without builder-sentinel churn; broader updateSelectInput audit remains optional future hardening. |
| 15 | Remove bottom sidebar reset button | Complete | Removed sidebar `reset_btn`, deleted its now-unreachable server observer, and removed smoke-test targeting of the old DOM id. |
| 16 | Align top hierarchy reset button | Complete | Added `.vp-hierarchy-reset-control` CSS, removed blank-label alignment hack, aligned button to input boxes, and updated tooltip/title to `Clear Group, Subgroup, and Market Segment`. |
| 17 | Add before/after perf and reset UI validation | Complete | Parse checks pass; Dried staged output probe settles; reset_btn references removed from app source and smoke tests; post-cache PERF shows cache hits are fast after one Stage-A miss. |
| 18 | Update final lay Summary | Complete | Summary below explains zero-row fix, repaired repeated-scan issue, validation evidence, and residual limitations in plain language. |
| 19 | Polish top hierarchy reset alignment | Complete for cluster pass; visual confirmation pending | Group/Subgroup/Market Segment/reset now share an explicit flex cluster with 6px internal gaps, the reset uses the same 34px input-height target with label-offset alignment, and the cluster leaves a larger gap before Commodity. Manual/screenshot confirmation remains open. |

## Detailed Work Plan
1. Resolver and selection semantics
- Replace strict parent-forcing fallback in VP hierarchy canonicalization with mode-aware resolution.
- Return normalized selections and resolved mode metadata: raw selections, resolved filters, mode, resolved path.
- Keep strict rollup behavior for strict paths: All/All/All, Group/All/All, Group/Subgroup/All.
- Treat sparse combinations as faceted native mode.

2. VP hierarchy row filtering
- Update shared VP filter helper to branch by resolved mode.
- Strict mode: continue provider filtering through rollup sentinel filters.
- Faceted native mode: strip rollup rows and apply non-All hierarchy filters directly in memory.
- Preserve Trade Flow, CommodityName, and CommodityDetail filtering semantics after hierarchy resolution.

3. Top-bar choice construction
- Build one trade-flow-scoped native hierarchy frame per invalidation.
- Build Group choices using selected Subgroup + selected Segment constraints.
- Build Subgroup choices using selected Group + selected Segment constraints.
- Build Segment choices using selected Group + selected Subgroup constraints.
- Always include All choice first for each hierarchy menu.
- Rebuild Commodity choices from resolved hierarchy rows and preserve current selection when still valid.

4. Reset button and UI behavior
- Add compact reset action immediately after Market Segment and before Commodity.
- Tooltip/title: Reset hierarchy filters.
- Reset only Group/Subgroup/Market Segment to All.
- Add disabled state when all three hierarchy filters are already All.

5. Cache and performance
- Add resolver-mode-aware key components to VP-sensitive cache/bindCache surfaces.
- Ensure strict and sparse contexts cannot collide in cached outputs.
- Keep sparse path out of partition materialization in first pass.
- Add PERF details for mode branch, row counts, and hierarchy conflict-clearing behavior.

6. Rollout safety
- Add feature flag to allow temporary fallback to prior strict behavior.
- Gate completion on no unresolved fallback regressions, cache regressions, or material sparse-path latency regressions.

7. Faceted native stabilization tranche
- Completed: added diagnostics and reproduced the Dried repeated-scan log shape.
- Completed: implemented the shared Stage-A faceted hierarchy cache.
- Completed for current scope: moved Dried-sensitive Commodity/Type handling and selected-data country behavior onto effective server-side values.
- Mitigated for current scope: guarded transition behavior enough to avoid builder-sentinel churn in the focused Dried probe.
- Completed: removed the sidebar reset and added first-pass top hierarchy reset alignment.
- Completed: ran parse checks, targeted Dried probes, reset static validation, and before/after PERF comparison.

8. UI polish follow-up
- Completed cluster pass: grouped Group/Subgroup/Market Segment/reset into a shared flex cluster so the reset shares the same control geometry as the hierarchy dropdowns.
- The reset button uses the same 34px input-height target as the dropdown controls and a label-offset alignment calculation rather than a hard-coded pixel nudge.
- The hierarchy cluster keeps normal 6px internal gaps and leaves a larger gap before Commodity so Commodity reads as downstream/separate from the hierarchy controls.
- Acceptance target: the reset button top/center should visually align with the hierarchy select input boxes, and the gap from Market Segment to reset should match the spacing among Group/Subgroup/Market Segment controls.
- Preserve the hierarchy-only semantics, disabled state, and title `Clear Group, Subgroup, and Market Segment`.

9. Deferred / optional follow-up
- Run one additional sparse-path regression probe besides Dried, such as Subgroup-first or another Market Segment-first selection.
- Run one strict-rollup regression probe to confirm strict paths still use provider behavior.
- Harden the shinytest wait/control-discovery harness and rerun the full lightweight smoke/perf suite.
- Optionally strengthen Stage-A cache keys with an explicit VP artifact/source signature if artifacts can mutate within a session.

## Validation Plan
Completed focused validation:
- Parse checks for all touched R files.
- Direct artifact probes for export + Dried row counts, valid top commodities, Type choices, and country options.
- Focused Dried transition probe using staged waits and explicit state/output checks.
- Before/after PERF comparison for expensive faceted native scans, including caller-purpose evidence and Stage-A cache hit/miss timing.
- Reset cleanup static validation: bottom `reset_btn` absent from app source and smoke tests; top `vp_reset_hierarchy_filters` remains present.

Planned UI polish validation:
- Completed: parse `ui.R` and `02_partner_and_notes.R` after the reset-alignment CSS change.
- Pending: manual/screenshot check that the reset button aligns with the hierarchy select input boxes and that horizontal spacing from Market Segment to reset matches the hierarchy dropdown spacing.
- Confirm the title remains `Clear Group, Subgroup, and Market Segment` and the reset remains hierarchy-only.

Deferred validation:
- Resolver probes for strict and sparse path mappings beyond the focused Dried path.
- Hierarchy choice probes: subgroup-first and segment-first behavior without forced fallback.
- Commodity narrowing probe under additional sparse hierarchy contexts.
- Reset button behavior probe including disabled-state transitions.
- Lightweight perf smoke with sparse transition timing once the harness is stable.
- One additional sparse-path regression probe besides Dried, such as Subgroup-first or another Market Segment-first selection.
- One strict-rollup regression probe to confirm strict paths still use provider behavior and did not move onto faceted native scans.
- If `wait_for_idle()` fails, record explicit app-state/output evidence separately from idle-status evidence.

## Bugs, Blockers, Rejected Approaches
- Lightweight perf smoke initial run failed with `Reason: On CRAN`; rerun with `NOT_CRAN=true` moved past the gate.
- Lightweight perf smoke rerun failed with `Missing expected controls: country_choice` during control discovery. This is a known style of shinytest harness timing/visibility issue in this codebase and is recorded as an active validation blocker for this tranche.
- No syntax blockers encountered in touched implementation files after patches (`PARSE_OK`).
- Resolved focused blocker investigation (user-reported): selecting `Market Segment = Dried` could trigger prolonged non-settling loops with repeated expensive direct-filter passes.
- Root-cause findings:
	- Transient invalid top commodity under Dried (`Artichokes`) interacted with faceted filtering to produce repeated high-cost recomputes.
	- Type control could transiently collapse into builder-only state (`__custom_builder__`) during this transition, which amplified churn.
- Implemented mitigations:
	- In faceted/native filtering, treat `Type = All` as non-restrictive and ignore builder sentinel type values in row filtering.
	- Add faceted/native fallback logic so stale/invalid commodity name and detail selections are corrected to valid in-slice values before filtering.
	- Build VP Type choices from hierarchy-constrained rows first, then apply a valid top-commodity filter to prevent builder-only transient states.
- Current status after mitigation:
	- Transition-state probe now converges to stable values (`segment=Dried`, `vp_commodity_name=Austrian winter peas`, `type=All`) and repeated short waits pass after transient updates.
	- Hard `wait_for_idle(timeout=120000)` immediately after setting Dried can still fail in this environment, consistent with pre-existing shinytest startup/idle instability.
	- The later repeated-scan issue was diagnosed with purpose tags and repaired for the focused tranche by the Stage-A faceted hierarchy cache. Post-cache validation shows one expensive miss followed by fast cache hits for repeated identical hierarchy slices.
	- Remaining limitation is broader harness validation, not the focused Dried app behavior.
	- UI polish cluster pass is complete: the reset button was grouped with the hierarchy dropdowns, matched to the 34px input-height target, and separated from Commodity with a larger gap. Manual/screenshot confirmation remains open.

## Validation Log
- 2026-07-28: Created source-of-truth implementation ledger before code edits.
- 2026-07-28: Parse checkpoint after core code patch tranche:
	- `& "C:\Program Files\R\R-4.5.1\bin\Rscript.exe" -e "invisible(parse(file='VP Clone/Programs/app_source/server/02_partner_and_notes.R')); invisible(parse(file='VP Clone/Programs/app_source/server/03_core_reactives_and_ui.R')); invisible(parse(file='VP Clone/Programs/app_source/server/04_comparison_plots.R')); invisible(parse(file='VP Clone/Programs/app_source/server/05_trend_and_heatmap.R')); invisible(parse(file='VP Clone/Programs/app_source/server/06_pace_analysis_and_reset.R')); cat('PARSE_OK\n')"`
	- Result: `PARSE_OK`.
- 2026-07-28: Lightweight perf smoke attempt:
	- `& "C:\Program Files\R\R-4.5.1\bin\Rscript.exe" "VP Clone/System/Testing/vp_lightweight_perf_smoke.R" --runs=1 --label=faceted_impl_smoke`
	- Result: `FAIL` with `Reason: On CRAN`.
- 2026-07-28: Lightweight perf smoke retry with CRAN gate bypass:
	- `$env:NOT_CRAN='true'; & "C:\Program Files\R\R-4.5.1\bin\Rscript.exe" "VP Clone/System/Testing/vp_lightweight_perf_smoke.R" --runs=1 --label=faceted_impl_smoke`
	- Result: Run executes but reports `FAIL` with `Missing expected controls: country_choice`.
	- Artifacts:
		- `VP Clone/Logs/vp_lightweight_perf_raw_faceted_impl_smoke_20260728T194750Z.csv`
		- `VP Clone/Logs/vp_lightweight_perf_summary_faceted_impl_smoke_20260728T194750Z.csv`
- 2026-07-28: Targeted Dried segment data sanity probes:
	- Verified native VP rows contain `MarketSegment = Dried` with non-zero export/import row counts.
	- Verified `Artichokes` is not present under export + Dried while `Austrian winter peas` is present.
- 2026-07-28: Transition-state shiny probes after code fixes:
	- Repeated state probe showed transient updates but eventual stable state:
		- `segment=Dried`, `vpname=Austrian winter peas`, `type=All`, with Type choices `All|Austrian winter peas|__custom_builder__`.
	- Output probe confirmed non-empty summary output after convergence (`summary_present=TRUE`, stable summary payload length).
- 2026-07-28: Post-fix parse checkpoint:
	- `& "C:\Program Files\R\R-4.5.1\bin\Rscript.exe" -e "invisible(parse(file='VP Clone/Programs/app_source/server/01_state_and_custom_types.R')); invisible(parse(file='VP Clone/Programs/app_source/server/02_partner_and_notes.R')); cat('PARSE_OK\n')"`
	- Result: `PARSE_OK`.
- 2026-07-28: Faceted repeated-scan diagnostic instrumentation tranche:
	- Added optional `vp_filter_purpose` argument to `filter_vp_rows_for_resolved_hierarchy()` with default `unspecified` for backward compatibility.
	- Added `vp_faceted_filter_debug_enabled()` controlled by option `vp_faceted_filter_debug` or env var `VP_FACETED_FILTER_DEBUG`.
	- Permanent PERF details now include `filter_purpose`; verbose requested hierarchy/Commodity/Type inputs are included only when debug is enabled.
	- Labeled direct callers in `01_state_and_custom_types.R`, `02_partner_and_notes.R`, and `03_core_reactives_and_ui.R`.
	- Parse checkpoint: `& "C:\Program Files\R\R-4.5.1\bin\Rscript.exe" -e "invisible(parse(file='VP Clone/Programs/app_source/server/01_state_and_custom_types.R')); invisible(parse(file='VP Clone/Programs/app_source/server/02_partner_and_notes.R')); invisible(parse(file='VP Clone/Programs/app_source/server/03_core_reactives_and_ui.R')); cat('PARSE_OK\n')"`
	- Result: `PARSE_OK`.
- 2026-07-28: Purpose-tagged Dried baseline with runtime PERF enabled:
	- Command: `$env:NOT_CRAN='true'; $env:VP_FACETED_FILTER_DEBUG='true'; $env:VP_PERF_RUNTIME='true'; & "C:\Program Files\R\R-4.5.1\bin\Rscript.exe" "VP Clone/System/Testing/_tmp_dried_output_probe.R"`
	- Probe output still converged by loop 3: `segment=Dried`, `vpname=Austrian winter peas`, `type=All`, `summary_present=TRUE`.
	- Runtime PERF file: `VP Clone/Logs/vp_runtime_perf_proc_20260728T215042Z_28560.jsonl`.
	- Direct faceted repeated-scan summary before cache patch: `mixed_volume_family_check` produced 12 `direct_filter/faceted_native/P0_faceted/278` scans, `quantity_units_context` produced 4, `display_month_mapping` produced 1, and `filtered_data` produced 1.
	- Interpretation: repeated scans are mostly support/context checks reusing the same effective selected row slice, not only selected data rendering.
- 2026-07-28: Stage-A faceted hierarchy cache tranche:
	- Added per-session Stage-A cache in `02_partner_and_notes.R` keyed by input row count, resolver mode/path, trade flow, active hierarchy filters, and faceted feature-flag state.
	- Cache boundary is after native/trade/hierarchy filtering and before Commodity/Type filtering so distinct semantic row slices remain explicit.
	- Post-cache runtime PERF file: `VP Clone/Logs/vp_runtime_perf_proc_20260728T215643Z_2256.jsonl`.
	- Post-cache direct faceted summary showed one `stage_a_cache_hit=FALSE` miss for `mixed_volume_family_check`, followed by cache hits for repeated `mixed_volume_family_check`, `quantity_units_context`, `display_month_mapping`, `filtered_data`, and `type_choice_base_values` calls.
	- Post-cache elapsed times for direct faceted cache hits were roughly 0.006-0.048 seconds; the one cache miss was about 2.72 seconds.
	- Runtime JSON logging itself made the probe slow; the run was manually stopped after stable loop output was observed through loop 5.
- 2026-07-28: Reset UI cleanup tranche:
	- Removed bottom sidebar `reset_btn` from `ui.R`.
	- Removed the now-unreachable `observeEvent(input$reset_btn, ...)` full reset handler from `06_pace_analysis_and_reset.R`.
	- Updated `vp_shinytest_smoke.R` so it no longer clicks `reset_btn`.
	- Updated top hierarchy reset layout to use `.vp-hierarchy-reset-control`, align with select input boxes, and clarify title text.
- 2026-07-28: Parse checkpoint after cache/reset tranche:
	- `& "C:\Program Files\R\R-4.5.1\bin\Rscript.exe" -e "invisible(parse(file='VP Clone/Programs/app_source/server/01_state_and_custom_types.R')); invisible(parse(file='VP Clone/Programs/app_source/server/02_partner_and_notes.R')); invisible(parse(file='VP Clone/Programs/app_source/server/03_core_reactives_and_ui.R')); invisible(parse(file='VP Clone/Programs/app_source/server/06_pace_analysis_and_reset.R')); invisible(parse(file='VP Clone/Programs/app_source/ui.R')); invisible(parse(file='VP Clone/System/Testing/vp_shinytest_smoke.R')); cat('PARSE_OK\n')"`
	- Result: `PARSE_OK`.
- 2026-07-28: Focused post-cache Dried output probe without heavy runtime JSON logging:
	- Command: `$env:NOT_CRAN='true'; Remove-Item Env:VP_PERF_RUNTIME -ErrorAction SilentlyContinue; Remove-Item Env:VP_FACETED_FILTER_DEBUG -ErrorAction SilentlyContinue; & "C:\Program Files\R\R-4.5.1\bin\Rscript.exe" "VP Clone/System/Testing/_tmp_dried_output_probe.R"`
	- Result: converged by loop 3 and stayed stable through loop 8: `segment=Dried`, `vpname=Austrian winter peas`, `type=All`, `summary_present=TRUE`, `summary_len=3060`.
- 2026-07-28: Reset cleanup static validation:
	- Workspace search found no remaining `reset_btn` references in `VP Clone/Programs/app_source/**/*.R` or `VP Clone/System/Testing/**/*.R`.
	- Workspace search confirmed `vp_reset_hierarchy_filters` remains in `02_partner_and_notes.R` and `.vp-hierarchy-reset-control` CSS exists in `ui.R`.
- 2026-07-28: Final parse checkpoint for touched files:
	- `& "C:\Program Files\R\R-4.5.1\bin\Rscript.exe" -e "invisible(parse(file='VP Clone/Programs/app_source/server/01_state_and_custom_types.R')); invisible(parse(file='VP Clone/Programs/app_source/server/02_partner_and_notes.R')); invisible(parse(file='VP Clone/Programs/app_source/server/03_core_reactives_and_ui.R')); invisible(parse(file='VP Clone/Programs/app_source/server/06_pace_analysis_and_reset.R')); invisible(parse(file='VP Clone/Programs/app_source/ui.R')); invisible(parse(file='VP Clone/System/Testing/vp_shinytest_smoke.R')); cat('PARSE_OK\n')"`
	- Result: `PARSE_OK`.
- 2026-07-29: Ledger recenter and top reset CSS polish tranche:
	- Rewrote stale active-blocker, release-risk, implementation-ledger, validation-plan, bugs/blockers, and lay Summary language so this file matches the implemented/validated state.
	- Applied CSS-only reset alignment polish in `ui.R`: reduced `.vp-hierarchy-reset-control` width from 44px to 34px, removed centering slack, changed alignment to flex-start, and reduced top padding from 25px to 20px.
	- Parse checkpoint: `& "C:\Program Files\R\R-4.5.1\bin\Rscript.exe" -e "invisible(parse(file='VP Clone/Programs/app_source/ui.R')); invisible(parse(file='VP Clone/Programs/app_source/server/02_partner_and_notes.R')); cat('PARSE_OK\n')"`
	- Result: `PARSE_OK`.
	- Remaining: manual/screenshot confirmation that the reset button now aligns with the hierarchy select boxes and spacing.
- 2026-07-29: Second top reset alignment pass after screenshot review:
	- Grouped Group/Subgroup/Market Segment/reset inside a `top-filter-hierarchy-cluster` flex wrapper with 6px internal gaps and a 12px margin before Commodity.
	- Updated `.vp-hierarchy-reset-control` to use a fixed 34px flex basis/width and `padding-top: calc(1.2em + 6px)` so the button aligns to the dropdown input row using the same label height and margin contract.
	- Hardened the button geometry with 34px height/min-height, border-box sizing, zero margin, and centered icon line-height.
	- Parse checkpoint: `& "C:\Program Files\R\R-4.5.1\bin\Rscript.exe" -e "invisible(parse(file='VP Clone/Programs/app_source/ui.R')); invisible(parse(file='VP Clone/Programs/app_source/server/02_partner_and_notes.R')); cat('PARSE_OK\n')"`
	- Result: `PARSE_OK`.
	- Remaining: manual/screenshot confirmation of exact visual alignment.

## Summary
The VP top filters now support independent hierarchy selections: Group, Subgroup, and Market Segment can each be changed without forcing the old strict parent fallback, and Commodity remains downstream of those hierarchy choices.

The user-reported Dried transition was repaired in two layers. First, stale transition values such as the old Commodity under a new Dried segment and the custom-builder sentinel Type state were corrected so the app settles on valid values like `segment=Dried`, `vp_commodity_name=Austrian winter peas`, and `type=All` with a non-empty summary. Second, repeated full-table faceted native scans were reduced by a session-scoped Stage-A hierarchy cache: the first scan for a hierarchy/trade tuple can still be expensive, but repeated callers now reuse the cached hierarchy slice before Commodity/Type filtering.

The bottom sidebar reset button has been removed. The top reset remains hierarchy-only: it clears Group, Subgroup, and Market Segment, and does not clear Commodity, Type, country, date, or metric controls. The reset is now grouped with Group/Subgroup/Market Segment in an explicit hierarchy flex cluster, uses the same 34px input-height target as the dropdowns, and leaves a larger gap before Commodity so Commodity reads as downstream; manual/screenshot confirmation remains open.

Validation is complete for the focused tranche: touched files parse cleanly, focused Dried probes converge and stay stable, reset references were cleaned up, and before/after PERF evidence shows fast cache hits after one Stage-A miss. The remaining limitation is broader smoke/perf harness validation: this workspace still has `shinytest2::wait_for_idle()` and control-discovery instability, so full harness hardening and broader sparse/strict regression probes remain deferred follow-up rather than current blockers to the focused fix.

Cache-work clarification: the implemented shared cache is specifically the Stage-A faceted hierarchy cache. Stage A resolves trade flow, hierarchy filters, resolver mode/path, and native-row eligibility once per distinct hierarchy tuple. Stages B and C in the design are currently processing boundaries rather than separate shared cache layers. Stage B applies effective top Commodity and Type/detail filters to the Stage-A slice inside `filter_vp_rows_for_resolved_hierarchy()`. Stage C applies final output-level filters such as country, date, metric, panel, sort, comparison, map, trend, and pace context in downstream reactives and output surfaces; some of those downstream surfaces already have their own `bindCache()` keys, but there is no single shared Stage-C cache.

Recommended performance follow-up is evidence-driven rather than adding broad caches immediately. First, add PERF timing and row-count details around the Stage-B boundary: Stage-A rows, post-Commodity rows, post-Type/detail rows, and elapsed time for each part. If Stage B still repeats enough to matter, add a narrowly keyed Stage-B cache using Stage-A key plus effective CommodityName, effective CommodityDetail/Type, and Type sentinel/All semantics. If support callers remain noisy, prefer caching tiny purpose-specific results such as `mixed_volume_family_check` and `quantity_units_context` by effective VP tuple, country, metric, and unit context before caching more large rowsets. Optional hardening includes adding an explicit VP artifact/source signature to the Stage-A cache key if VP artifacts can mutate within a session, and only considering a native hierarchy index if profiling shows Stage-A cache misses remain frequent or too expensive.
