# VP Branch I Trend/Heatmap Materialization Reduction Plan

Date: 2026-07-30
Branch: main
Status: Closed / attribution-only measurement branch. Branch I source instrumentation and baselines are complete; no product-code simplification was selected.

## Purpose

Branch I is a measurement-first follow-up to Branch H. The goal is to make the VP app feel usable during repeated tab switching by reducing the delay between activating Historical Trend or Heatmap and seeing a ready Plotly/htmlwidget output.

The user priority is repeated-use latency, not startup. The controlling user framing is: slow startup/initialization is acceptable for now, but tab switches and filtering must feel faster. Manual symptoms included 5-6 second tab transitions, 5-6 second commodity changes, and group/subgroup waits of 10 seconds or more. Branch G and Branch H narrowed the next product target away from startup and toward tab-output readiness.

Branch I must not assume payload complexity is the cause. Branch H showed the suspicious window clusters around late Shiny/htmlwidget and Plotly materialization events: `shiny:value`, `plotly_afterplot`, `.main-svg`, loading-clear, and the readiness predicate. Payload complexity is the first measurable suspect because Historical Trend and Heatmap likely carry larger trace, point, cell, hover, annotation, and customdata surfaces than faster outputs. It is not yet a proven root cause.

This plan is intentionally detailed because implementation may be delayed or context may be compacted. A future coder should be able to resume from this file without replaying chat history.

## Scope

Included:
- Create this Branch I daughter source-of-truth ledger before Branch I source-code edits.
- Amend the parent plan so Branch I is Step 16 and the existing deferred rows shift down.
- Target Historical Trend and Heatmap first, because Branch H gave the cleanest attribution there.
- Add safe server-side complexity instrumentation around Trend and Heatmap only.
- Add passive client/probe complexity fields to the existing single-action latency probe.
- Run an official Branch I complexity/materialization baseline before any product simplification.
- Select at most one small product-code experiment only after the baseline identifies a low-risk target.
- Accept attribution-only closeout if no safe reduction is proven.
- Preserve Map and Current as comparison/regression surfaces.
- Preserve exact fallback runtime-log summarization and cache-state labeling.
- Keep the parent compact while this daughter owns detailed execution notes.

Excluded until evidence proves otherwise:
- Startup/artifact/data-format work. Startup remains deferred because the current priority is repeated-use feel.
- Build-time aggregation tuning.
- Broad hidden-output warming. Branch G rejected unsuspending hidden Trend/Heatmap Plotly outputs.
- Removing `Plotly.redraw()` from the resize handler. Branch G rejected that path because it worsened readiness.
- Tabset rewrites, generic loading polish, cosmetic waiting states, or broad JavaScript throttling.
- Making display-month/year-filter/summary churn the first Branch I target. Those remain secondary full-idle candidates unless new evidence ties them to visible readiness.
- Direct Plotly-node lifecycle binding in the probe. Branch H rejected that because it perturbed timing and produced a partial run.
- A paired results markdown file unless explicitly requested.

## Parent Plan Linkage

Parent plan: `VP Clone/Code Review/2026-07-29_vp_performance_hotspot_recovery_plan.md`.

Required parent state for Branch I handoff:
- Step 14 Branch G remains closed as a perceived-latency measurement branch with no accepted product-code branch.
- Step 15 Branch H remains closed as a Plotly materialization attribution branch with no accepted product-code optimization.
- Step 16 is Branch I Trend/Heatmap materialization reduction, delegated to this file.
- Step 17 is build-time aggregation instrumentation/tuning, deferred.
- Step 18 is narrower artifacts or data formats, deferred.
- Step 19 is final validation and Summary, not started.

Required parent update at Branch I closeout:
- Record Branch I outcome, labels, output CSVs, exact fallback JSONLs, runtime summary CSVs, accepted/rejected changes, validation markers, residual blockers, and next recommendation.
- Keep build-time aggregation and artifact/data-format work deferred unless Branch I evidence changes that priority.
- Complete the parent `## Summary` only at final performance-tranche closeout.

## Source-Of-Truth Ledger Contract

- This file is the active source of truth for Branch I once the parent delegation is added.
- Update this file after every Branch I step or tranche before moving to the next tranche.
- Record files touched, commands/probes, labels, cache states, runtime log paths, fallback JSONL inputs, summary CSVs, action IDs, visible/client/full-idle timings, timeline fields, complexity fields, final selected states, stale-output checks, browser diagnostics, provider summaries, branch decisions, bugs, blockers, failed attempts, rejected approaches, and validation gates.
- Keep parent-plan updates limited to delegation and closeout while this daughter is active.
- Preserve enough detail for delayed implementation or context compaction.

## Baseline Evidence

Closed Branch G daughter plan:
- `VP Clone/Code Review/2026-07-30_vp_branch_g_perceived_interaction_latency_single_action_plan.md`.
- Accepted source change: `VP Clone/System/Testing/vp_perf_probe_single_action_latency.R`.
- Branch G created the single-action perceived-latency probe with real tab anchor clicks, per-action rows, visible-ready timing, client-interaction-ready timing, full-idle timing, browser diagnostics, final selected-state snapshots, stale-output checks, requested runtime log paths, and exact fallback runtime log discovery.
- Branch G hardened plot readiness so Plotly widgets mounted on the output root are counted and plot outputs require widget/Plotly markers rather than generic nonempty text.

Branch G hardened baseline:
- Label: `step14_branch_g_single_action_plotly_ready_baseline`.
- Status: `PASS=11`.
- Output CSV: `VP Clone/Logs/vp_perf_probe_single_action_latency_step14_branch_g_single_action_plotly_ready_baseline_20260730T171015Z.csv`.
- Requested runtime log path did not materialize.
- Exact fallback runtime input: `VP Clone/Logs/vp_runtime_perf_proc_20260730T171032Z_40560.jsonl|VP Clone/Logs/vp_runtime_perf_96221a8012f7e368dc621348ccddaca8.jsonl`.
- Runtime summaries: `VP Clone/Logs/vp_perf_runtime_summary_runtime_logs_20260730T171441Z_*.csv`.

Branch G timing interpretation:
- Commodity visible readiness was fast in the canonical run, about 63-71ms.
- Hierarchy visible readiness was fast in the canonical run, about 58-98ms.
- Hierarchy/filter full-idle tails remained long, about 10-22s in the canonical actions.
- Settled tab Plotly readiness clustered near 10s:
  - Historical Trend: about 10.054s.
  - Heatmap: about 10.436s.
  - Map: about 10.636s.
  - Current vs. Average return: about 10.282s.
  - Tab while commodity pending Historical Trend: about 10.376s.
  - Return Current after pending tab: about 10.321s.
- Client tab shell/paint rows were cheap relative to the 10s output readiness delay.
- Runtime server-side plot buckets did not obviously explain the 10s tab readiness delay by elapsed server time.

Rejected Branch G product-code experiments:
- Removing `Plotly.redraw()` from `forcePlotlyResize` worsened settled tab readiness to roughly 11.7-16.2s and was reverted.
- Gating hidden Pace default-target work caused partial rows, required-control wait timeouts, output visible-ready timeouts, and full-idle timeouts; it was reverted.
- Unsuspending hidden Trend/Heatmap Plotly outputs regressed to `PARTIAL=11`, with visible-ready timeouts and idle failures; it was reverted.

Closed Branch H daughter plan:
- `VP Clone/Code Review/2026-07-30_vp_branch_h_plotly_materialization_attribution_plan.md`.
- Accepted source changes were measurement-only:
  - `VP Clone/System/Testing/vp_perf_probe_single_action_latency.R` for action-scoped timeline/lifecycle attribution.
  - `VP Clone/Programs/app_source/ui.R` for resize-state fields in existing client PERF payloads.
- Branch H closed as attribution-only. No product-code optimization was accepted.

Branch H valid labels:
- `step15_branch_h_plotly_timeline_tab_baseline`, scenario `tab_only`, `PASS=4`.
- `step15_branch_h_plotly_timeline_tab_revisit_baseline`, scenario `tab_only_revisit`, `PASS=8`.
- `step15_branch_h_light_lifecycle_attribution_probe`, scenario `tab_only`, `PASS=4`.
- `step15_branch_h_resize_state_attribution_probe`, scenario `tab_only`, `PASS=4`.

Branch H final interpretation:
- The tab shell itself is not the bottleneck. Tab shown/paint events are early relative to output readiness.
- Widget/htmlwidget roots generally exist early, so the delay is not just first widget-root insertion.
- Historical Trend and Heatmap delays cluster late around `shiny:value`, `plotly_afterplot`, `.main-svg`, loading-clear, and readiness.
- Map first Shiny/htmlwidget/Plotly materialization appears around 10-11s, but readiness can lag several more seconds.
- Current vs. Average can have early afterplot/main SVG but late Shiny value, loading-clear, and readiness, pointing to redraw/loading-state/output-settling rather than first SVG insertion alone.
- Existing runtime server plot timers remain small relative to visible readiness. In Branch H examples, `timeseries_plot` was around 0.119s and `map_plot` totaled under 1s across rows, while readiness waited many seconds.
- Resize-state instrumentation showed resize messages arrive late and usually find loading/no-SVG targets with `resized_count=0`. Resize cost itself is small and not a proven low-risk optimization target.
- Runtime churn still shows display-month mapping, summary table, year-filter sync, and map-bottom-panel activity, but those remain secondary full-idle/background candidates unless tied to visible readiness.
- Direct Plotly-node probe binding perturbed timing and produced `PARTIAL=1|PASS=3`; it was rejected and backed out.

Branch H closeout validation:
- Parse markers included `PARSE_OK_BRANCH_H_FINAL_CLOSEOUT` and `PARSE_OK_BRANCH_H_RESIZE_CLOSEOUT_FILES`.
- `get_errors` found no diagnostics for touched Branch H files.
- `git diff --check` was clean for final Branch H files.
- Final resize-state probe `step15_branch_h_resize_state_attribution_probe` passed `PASS=4`.

## Technical Read

Primary Branch I product/instrumentation surface:
- `VP Clone/Programs/app_source/server/05_trend_and_heatmap.R`.
- `output$timeseries_plot <- renderPlotly({ ... })` around the Historical Trend implementation.
- `output$heatmap_plot <- renderPlotly({ ... })` around the Heatmap implementation.
- Both outputs use `bindCache(...)`, so render-body instrumentation may not fire on cache hits.
- Existing render bodies already call `record_cache_body_execution(session, "timeseries_plot_executed")` or `record_cache_body_execution(session, "heatmap_plot_executed")` and `log_perf("timeseries_plot", start_time)` or `log_perf("heatmap_plot", start_time)`.

Historical Trend local surface:
- Builds `df_filtered`, `df_recent`, and `df_historical`.
- Builds `p <- plot_ly()`.
- Adds traces for historical years, current year, historical average, and projections.
- Adds annotations for projections and emphasis mode.
- Has frequency, selected-year, current-year, projection, average, marker, hover, and metric-label semantics that must not be silently changed.

Heatmap local surface:
- Builds `heatmap_base`, `heatmap_data`, `heatmap_matrix`, labels, and customdata.
- Computes quantile/custom colorscale details.
- Uses one Plotly heatmap trace, but one heatmap trace can still carry many cells and substantial customdata.
- Has frequency, period, year, metric, value, colorscale, and hover semantics that must not be silently changed.

Primary Branch I probe surface:
- `VP Clone/System/Testing/vp_perf_probe_single_action_latency.R`.
- Branch G/H fields already include `visible_ready_ms`, `client_interaction_ready_ms`, `full_idle_ms`, browser diagnostics, action timeline marks, resize-state fields, stale-output checks, selected-state checks, and scenarios `canonical`, `tab_only`, and `tab_only_revisit`.
- `output_snapshot()` currently records output presence/visibility/dimensions, widget count, text length, Plotly node count, main SVG count, SVG container count, loading count, and afterplot count.
- Branch I should extend this passively with Plotly complexity fields without binding to each Plotly node.

Runtime summarizer surface:
- `VP Clone/System/Testing/vp_perf_summarize_runtime_logs.R`.
- Use exact fallback JSONLs when requested runtime log paths do not materialize.
- Use `--input=<jsonl1>|<jsonl2>` for exact-file summaries.
- Do not use `--log`; repository memory notes it is ignored/defaults incorrectly.

## Local Hypothesis

Historical Trend and Heatmap are delayed somewhere in the Shiny/htmlwidget payload delivery and Plotly materialization path. Payload complexity is the first measurable suspect because these outputs likely contain larger trace, point, cell, hover/customdata, marker, annotation, and layout payloads than faster outputs.

This hypothesis is falsifiable. If complexity is not high relative to Map/Current or if reducing complexity does not move `visible_ready_ms`, `timeline_shiny_value_output_ms`, `timeline_plotly_afterplot_ms`, `.main-svg`, or loading-clear timing, then payload complexity is not the accepted fix.

## Disconfirmation Checks

- If Trend/Heatmap trace count, point/cell count, hover/customdata size, object size, or client-observed Plotly complexity are not large relative to faster outputs, do not optimize payload complexity first.
- If server-side timing or complexity records show real elapsed server construction work near the readiness delay, target server plot construction rather than browser materialization.
- If server construction remains small but `shiny:value` is late, target Shiny/htmlwidget delivery or cache/output-delivery behavior before Plotly drawing itself.
- If a smaller payload does not reduce `visible_ready_ms`, `timeline_shiny_value_output_ms`, `timeline_plotly_afterplot_ms`, `.main-svg` timing, or loading-clear timing, reject that product branch.
- If instrumentation materially changes timing or creates partial rows, reject or revert the instrumentation before judging product behavior.

## Guardrails

- No Branch I product-code edits before plan handoff validation.
- Preserve VP-scoped work only.
- Keep changes local to `05_trend_and_heatmap.R` and `vp_perf_probe_single_action_latency.R` unless evidence proves a shared helper is necessary.
- Do not touch Map or Current product behavior in the first Branch I product experiment.
- Do not remove `Plotly.redraw()` or alter resize behavior unless new Branch I evidence overturns Branch G/H.
- Do not warm hidden outputs broadly.
- Do not start startup/artifact work in this branch.
- Do not call heavy serialization or `plotly_build()` inside live `renderPlotly()` unless later evidence proves it is necessary and cheap enough.
- Do not bind directly to every Plotly node from the probe.
- Missing or inaccessible client complexity fields should be recorded as `NA`, not zero.
- Preserve Provider v3 health, direct-filter fallback behavior, source-signature checks, source-identity checks, row-order checks, and generated-artifact separation.
- Preserve final selected source/trade/hierarchy/commodity/country/metric/tab correctness.

## Measurement Model

Branch I must preserve Branch G/H timing fields:
- `visible_ready_ms`: elapsed time until the primary output appears stable and selected-state checks pass.
- `client_interaction_ready_ms`: elapsed time until a lightweight follow-up client echo succeeds.
- `full_idle_ms`: elapsed time until Shiny idle/wait-for-idle succeeds.
- `timeline_shiny_value_output_ms`.
- `timeline_plotly_afterplot_ms`.
- `timeline_main_svg_inserted_ms`.
- `timeline_loading_indicator_cleared_ms`.
- `timeline_readiness_predicate_passed_ms`.

Server-side Trend metrics to add near existing `log_perf()` or runtime detail surfaces:
- `n_input_rows`.
- `n_filtered_rows`.
- `n_recent_rows`.
- `n_historical_rows`.
- `n_years`.
- Expected trace count.
- Expected point count.
- Expected annotation count.
- `uses_markers`.
- `uses_hist_avg`.
- `uses_projection`.
- `emphasize_mode`.
- Frequency.
- Approximate hover/custom text character count where cheap.

Server-side Heatmap metrics to add near existing `log_perf()` or runtime detail surfaces:
- `n_input_rows`.
- `n_heatmap_base_rows`.
- `n_years`.
- `n_periods`.
- `n_cells`.
- `n_non_na_cells`.
- `customdata_cells`.
- Colorscale type/custom scale length.
- Frequency.
- Approximate hover/customdata text footprint where cheap.

Client/probe complexity metrics to add passively where available:
- `plotly_trace_count`.
- Estimated `plotly_point_count`.
- Estimated `plotly_cell_count` for matrix/heatmap traces.
- Bounded `plotly_array_value_count` from existing trace arrays.
- Bounded `plotly_text_chars_est` and `plotly_customdata_chars_est` from existing trace text/customdata fields.
- Main SVG count.
- Widget count.
- Loading count.
- Optional experimental JS heap fields if `performance.memory` exists.

Client point/cell estimate rule:
- Sum lengths of trace `x`, `y`, or `z` arrays where present.
- For heatmap, count matrix cells rather than treating one heatmap trace as simple.
- Use `NA` for missing or inaccessible values.

Cache instrumentation caveat:
- Because `renderPlotly() %>% bindCache(...)` may skip the render body on cache hits, server-side complexity metrics are authoritative only when `timeseries_plot_executed` or `heatmap_plot_executed` fires.
- Client-observed metrics are authoritative for cached delivery/materialization cases.
- Branch I must separate render-body/server-complexity capture from the official warm repeated-use baseline; missing server details in warm cached runs are expected evidence, not a failed run.
- Do not run full `JSON.stringify(el.data)` in the live browser probe; use bounded estimates so the probe does not add the browser main-thread latency it is measuring.

## Step Ledger

| Step | Phase | Work | Status | Evidence / Files | Gate / Next Action |
|---|---|---|---|---|---|
| I-1 | A | Create Branch I daughter plan | Complete | This file created as the detailed handoff ledger. | Amend parent plan and validate the planning handoff. |
| I-2 | A | Amend parent plan delegation | Complete | Parent adds Branch I as Step 16 and shifts deferred rows to Steps 17-19. | Keep implementation paused until user explicitly resumes. |
| I-3 | A | Validate plan handoff | Complete | `get_errors` found no diagnostics for parent/daughter plan files; `git diff --check` produced no output for parent/daughter plan files. | Next implementation step is Branch I-4 baseline framing, followed by instrumentation only after the pause ends. |
| I-4 | B | Record Branch H baseline framing | Complete | Branch H labels/findings and the Branch I audit amendments are recorded above; implementation started from the validated planning handoff on 2026-07-31. | Proceed with safe server-side complexity instrumentation. |
| I-5 | C | Add safe Trend/Heatmap server complexity instrumentation | Complete | `05_trend_and_heatmap.R`; added data-derived details to `log_perf("timeseries_plot", ...)` and `log_perf("heatmap_plot", ...)`; parse marker `PARSE_OK_BRANCH_I_TREND_HEATMAP_SOURCE`. | Proceed to passive client/probe complexity fields. |
| I-6 | D | Add passive client/probe complexity fields | Complete | `vp_perf_probe_single_action_latency.R`; added bounded Plotly complexity output columns; parse marker `PARSE_OK_BRANCH_I_COMPLEXITY_PROBE`; post-baseline confirmation found all required non-heap fields present and populated in both Branch I CSVs. | No additional Step I-6 work currently indicated. |
| I-7 | E | Run official Branch I complexity baseline | Complete | Labels `step16_branch_i_trend_heatmap_server_complexity_capture` and `step16_branch_i_trend_heatmap_complexity_baseline` both `PASS=4`; exact fallback runtime summaries recorded; optional revisit baseline skipped by user decision. | Select product branch or attribution-only closeout. |
| I-8 | F | Select product branch or attribution-only closeout | Complete | Selected Branch I-0 attribution-only. Evidence did not identify a clear low-risk Trend/Heatmap product simplification: server render work was small, warm cached render bodies did not fire, and client complexity was not extreme relative to comparison outputs. | Skip product experiment. |
| I-9 | G | Run one small product-code experiment | Skipped | No product-code experiment selected. | Preserve measurement-only source changes. |
| I-10 | H | Post validation and acceptance decision | Complete / not applicable | No product experiment, so no post-product probe was run. Validation rests on parse markers, `PASS=4` baseline probes, populated complexity fields, exact runtime summaries, `get_errors`, and `git diff --check`. | Close Branch I attribution-only. |
| I-11 | I | Daughter closeout and parent recenter | Complete | This file and parent plan updated. | Branch I closed; next recommendation is a separate Shiny/htmlwidget delivery/output-settling branch or return to full-idle churn by explicit priority. |

## Phase Plan

Phase A: Parent recenter and daughter handoff
1. Create this daughter plan under `VP Clone/Code Review/`.
2. Update the parent plan: keep Step 15 Branch H closed; add Branch I as new Step 16; shift build-time aggregation to Step 17, narrower artifacts/data formats to Step 18, and final validation/Summary to Step 19.
3. Validate the plan handoff with `get_errors` and `git diff --check` for the parent and Branch I daughter files before any source-code edits.

Phase B: Baseline framing and hypothesis
4. Record the controlling Branch H evidence: Trend/Heatmap tab shown/paint are fast, widget roots exist early, server plot timers are small, and the late readiness window aligns with `shiny:value`, `plotly_afterplot`, `.main-svg`, loading-clear, and readiness.
5. Keep the Branch I hypothesis careful: Historical Trend and Heatmap are delayed somewhere in the Shiny/htmlwidget payload delivery and Plotly materialization path. Payload complexity is the first measurable suspect, not a proven cause.
6. Preserve the disconfirmation checks listed above.

Phase C: Safe server-side complexity instrumentation
7. Inspect `05_trend_and_heatmap.R` and anchor instrumentation around `output$timeseries_plot` and `output$heatmap_plot` only.
8. Add safe, data-derived runtime details near existing `log_perf()` calls for `timeseries_plot` and `heatmap_plot`.
9. Define and implement exact Trend metrics listed in the measurement model.
10. Define and implement exact Heatmap metrics listed in the measurement model.
11. Record execution/cache context beside complexity metrics because `bindCache()` may skip render-body instrumentation.
12. Add helper functions only if they prevent meaningful duplication and remain local to the established surface.
13. Parse-check `05_trend_and_heatmap.R` immediately after instrumentation.

Phase D: Passive client/probe complexity metrics
14. Extend `vp_perf_probe_single_action_latency.R` with passive output snapshot fields.
15. Keep probe additions passive; do not bind directly to every Plotly node.
16. Estimate points/cells conservatively and use `NA` for missing values.
17. Preserve all Branch G/H timing, lifecycle, resize-state, selected-state, stale-output, and scenario fields.
18. Parse-check the probe with marker `PARSE_OK_BRANCH_I_COMPLEXITY_PROBE`.

Phase E: Official Branch I baselines
19. Run a Branch I server-complexity capture pass before judging product changes:
  - Probe: `VP Clone/System/Testing/vp_perf_probe_single_action_latency.R`.
  - Scenario: `--scenario=tab_only`.
  - Label: `step16_branch_i_trend_heatmap_server_complexity_capture`.
  - Cache state: `--cache-state=server_complexity_capture` or a more specific non-warm label recorded in this plan.
  - Runtime PERF: `--runtime-perf=true`.
  - Goal: observe at least one Trend/Heatmap render-body execution so server complexity details exist.
  - Do not delete disk caches unless explicitly approved as a measurement setup change.
  - If render-body counters do not fire, record that explicitly and proceed using client-observed complexity for cached delivery.
20. Run tab-only Branch I warm repeated-use complexity baseline:
    - Probe: `VP Clone/System/Testing/vp_perf_probe_single_action_latency.R`.
    - Scenario: `--scenario=tab_only`.
    - Label: `step16_branch_i_trend_heatmap_complexity_baseline`.
    - Cache state: `--cache-state=warm_partition_disk`.
    - Runtime PERF: `--runtime-perf=true`.
    - Timeout envelope: same as Branch H unless this plan records a justified change.
21. Record output CSV, requested runtime log path, exact fallback JSONLs, runtime summary prefix, status counts, and all complexity fields for each Branch I probe run.
22. Summarize exact fallback runtime logs with `vp_perf_summarize_runtime_logs.R --input=<jsonl1>|<jsonl2>`.
23. Compare Trend/Heatmap complexity against Map and Current rows from the same run, and treat absent server details in warm cached rows as cache-delivery evidence.
24. Optional: run `--scenario=tab_only_revisit` with label `step16_branch_i_trend_heatmap_complexity_revisit_baseline` if first materialization differs from revisits.

Phase F: Product branch decision gates
24. Select Branch I-0 attribution-only if complexity metrics do not identify a clear low-risk product reduction, if instrumentation materially changes timing, or if cached delivery remains the dominant unexplained gap.
25. Select Branch I-1 Trend trace/point/marker reduction if Historical Trend has high trace/point count or marker overhead and the existing visual contract can be preserved with a smaller payload.
26. Select Branch I-2 Trend hover/annotation reduction if repeated hover/custom text or annotations dominate the payload and can be simplified without removing essential analyst context.
27. Select Branch I-3 Heatmap hover/customdata/cell reduction if Heatmap has high matrix/customdata footprint or avoidable repeated metadata that can be reduced without changing displayed values.
28. Select Branch I-4 server plot construction reduction only if new server-side timers show real elapsed server work near the readiness delay.
29. Select Branch I-5 Shiny/htmlwidget delivery follow-up if complexity looks reasonable but `shiny:value` remains late despite small server work. This may require a separate daughter branch if implementation risk is high.
30. Do not select resize/redraw removal, broad hidden-output warming, tabset rewrite, startup artifact work, display-month migration, or generic loading polish as Branch I product branches.

Phase G: One small product-code experiment
31. Make at most one small product-code experiment after the baseline, selected from the gates above.
32. Keep the product edit local to `05_trend_and_heatmap.R` unless evidence proves a shared helper is necessary.
33. Preserve analyst semantics explicitly: selected years, current-year emphasis, monthly/weekly axis meaning, metric labels, hover meaning, commodity/country/source context, historical average/projection meaning, and Heatmap values must remain correct.
34. Record any visible simplification, such as historical lines without markers or shorter hover text, as a product decision in this plan.
35. Add explicit runtime counters/details for the product branch, such as `timeseries_plot_payload_reduced`, `heatmap_plot_payload_reduced`, or details on the existing plot timer.
36. Parse-check touched source immediately after the product edit.

Phase H: Post validation and acceptance
37. Rerun the same `tab_only` probe with post label `step16_branch_i_trend_heatmap_materialization_post`, same cache state, same timeout envelope, runtime PERF enabled, and exact fallback runtime summarization.
38. Acceptance threshold: at least 20% improvement or at least 2000ms reduction in `visible_ready_ms` for Historical Trend or Heatmap, with supporting movement in the expected complexity/materialization metric. The Trend/Heatmap improvement must also exceed same-run Map/Current movement by at least 15 percentage points or at least 1000ms unless this ledger records a concrete reason those comparison surfaces are invalid for the run. Smaller improvements may be recorded but should not be called the accepted fix without user approval.
39. Required no-regression gates: no PARTIAL rows; Current and Map still pass; no Map/Current visible-ready regression greater than 10% or 1000ms without explanation; no stale output accepted; final selected source/trade/hierarchy/commodity/country/metric/tab path is correct; Provider v3 health remains clean; no direct-filter fallback/source-signature/source-identity errors appear.
40. If the product experiment worsens readiness, produces partial rows, breaks correctness, fails to reduce measured complexity, or improves only a metric unrelated to readiness, revert it and record it as rejected before considering another branch.

Phase I: Closeout and parent recenter
41. Complete this daughter Summary in plain language: what was measured, whether payload/materialization was proven, what changed or was rejected, performance outcomes, validation status, residual risks, and next recommendation.
42. Update the parent plan with the compact Branch I outcome, labels, output CSVs, fallback JSONLs, runtime summary CSVs, accepted/rejected changes, validation markers, and next target recommendation.

## Candidate Branches

Branch I-0: Attribution-only closeout
- Choose if complexity metrics are not clearly high, instrumentation distorts timing, no safe semantic simplification is available, or cached delivery remains the dominant unexplained gap.
- This is an acceptable outcome. Do not force a product edit.

Branch I-1: Trend trace/point/marker reduction
- Choose only if Trend trace/point/marker complexity is high relative to faster surfaces.
- Candidate examples may include reducing marker payload for historical lines or avoiding duplicate point-level material where visual meaning remains intact.
- Must preserve selected-year, current-year, historical average, projection, frequency, metric, hover, and label semantics unless explicitly accepted as a visible product simplification.

Branch I-2: Trend hover/annotation reduction
- Choose only if hover/custom text or annotation payload dominates the measured surface.
- Candidate examples may include shorter hover text or fewer repeated annotation payloads.
- Must preserve essential analyst context.

Branch I-3: Heatmap hover/customdata/cell reduction
- Choose only if matrix/customdata footprint or avoidable repeated metadata is high.
- Candidate examples may include reducing repeated customdata while preserving displayed values and hover meaning.
- Must preserve Heatmap values, periods, years, frequency, metric labels, colorscale meaning, and country/commodity context.

Branch I-4: Server plot construction reduction
- Choose only if new server-side timing shows real elapsed work near the readiness delay.
- Candidate examples depend on measured server work and must remain local to Trend/Heatmap construction.

Branch I-5: Shiny/htmlwidget delivery follow-up
- Choose if complexity looks reasonable but `shiny:value` remains late despite small server work.
- This likely deserves a separate daughter branch if it requires broader Shiny/cache/htmlwidget delivery changes.

Rejected first branches:
- Resize/redraw removal.
- Broad hidden-output warming.
- Startup artifact/data-format rewrites.
- Display-month migration.
- Generic loading polish.
- Tabset rewrite.

## Verification

Planning handoff:
1. `get_errors` for the parent plan and this daughter plan.
2. `git diff --check -- "VP Clone/Code Review/2026-07-29_vp_performance_hotspot_recovery_plan.md" "VP Clone/Code Review/2026-07-30_vp_branch_i_trend_heatmap_materialization_reduction_plan.md"`.

Source parse after instrumentation/product edits:
1. `C:\Program Files\R\R-4.5.1\bin\Rscript.exe -e "invisible(parse(file='VP Clone/Programs/app_source/server/05_trend_and_heatmap.R')); cat('PARSE_OK_BRANCH_I_TREND_HEATMAP_SOURCE\n')"`.
2. `C:\Program Files\R\R-4.5.1\bin\Rscript.exe -e "invisible(parse(file='VP Clone/System/Testing/vp_perf_probe_single_action_latency.R')); cat('PARSE_OK_BRANCH_I_COMPLEXITY_PROBE\n')"`.

Baseline probe:
1. Run `step16_branch_i_trend_heatmap_server_complexity_capture` first, or explicitly record that render-body server metrics could not be captured without destructive cache changes.
2. Run `step16_branch_i_trend_heatmap_complexity_baseline` with `--scenario=tab_only`, `--cache-state=warm_partition_disk`, runtime PERF enabled, and record output CSV/requested runtime/fallback JSONLs.
3. Summarize exact fallback runtime JSONLs for each probe with `vp_perf_summarize_runtime_logs.R --input=<exact_jsonl_1>|<exact_jsonl_2>`.
4. Optional revisit baseline: `step16_branch_i_trend_heatmap_complexity_revisit_baseline` only if needed to separate first materialization from revisit behavior.

Post probe:
1. Run `step16_branch_i_trend_heatmap_materialization_post` with the same scenario/cache/timeouts after the product experiment.
2. Summarize exact fallback runtime JSONLs.
3. Apply acceptance and no-regression gates.

Correctness and health:
- Final tab/output state must match the target.
- No stale output accepted.
- Trend/Heatmap visuals remain semantically equivalent unless an explicit visible simplification was accepted.
- Map and Current still pass as regression surfaces.
- Provider health remains clean: no new direct-filter fallback, source-signature mismatch, source-identity refusal, row-order refusal, or Provider v3 memory/disk regression.
- Worktree checks: `get_errors`, `git diff --check`, and generated log/artifact review.

## Bugs, Blockers, Failed Attempts, Rejected Approaches

Known blockers and risk controls:
- Cache instrumentation blocker: `bindCache()` may prevent server-side metrics inside `renderPlotly()` from firing during cached output delivery. Mitigation: record execution counters and rely on client-observed complexity for cached cases.
- Instrumentation overhead blocker: live serialization, `plotly_build()`, or direct Plotly-node binding can perturb timing. Mitigation: use data-derived metrics first and passive client reads only.
- Causality blocker: payload complexity may correlate with delay without causing it. Mitigation: require both complexity reduction and readiness improvement before accepting a product branch.
- Semantic regression blocker: simplifying markers, hover text, annotations, projections, or heatmap cells can alter analyst meaning. Mitigation: document visible simplifications as product decisions and preserve core analytical semantics.
- Probe noise blocker: Shiny/browser timing is noisy. Mitigation: set explicit improvement thresholds and keep baseline/post scenario, cache state, and timeouts identical.
- Runtime-log blocker: requested runtime log paths often do not materialize. Mitigation: use exact fallback JSONLs and `--input=...` summaries.
- Scope creep blocker: Map/Current, startup, display-month churn, and resize behavior are tempting adjacent targets. Mitigation: keep them as regression/comparison surfaces unless Branch I closes or evidence explicitly changes priority.
- Product branch blocker: no safe reduction may emerge. Mitigation: attribution-only closeout is acceptable.

Prior rejected approaches carried forward:
- Removing `Plotly.redraw()` worsened readiness in Branch G.
- Broad hidden-output warming caused partial/timeouts in Branch G.
- Direct Plotly-node probe binding perturbed timing in Branch H.
- Display-month/pipeline migration is not the current target because existing evidence ties it more to residual full-idle churn than visible Trend/Heatmap materialization.
- Startup/artifact format work is deferred by user priority.

## Further Recommendations

- Add a non-Shiny companion probe only if live app metrics are ambiguous: load representative filtered data and construct Trend/Heatmap objects outside Shiny to estimate object size, trace count, point count, cell count, hover/customdata footprint, and plot construction time without browser timing noise.
- Consider a small reusable complexity summarizer for Plotly objects only after proving the first local metrics are useful; avoid broad abstraction before that.
- If Trend/Heatmap complexity is confirmed and a reduction succeeds, repeat the same measurement approach for Map/Current in a separate branch rather than expanding Branch I midstream.
- If complexity is not confirmed but `shiny:value` remains late, the next branch should investigate Shiny/htmlwidget output delivery/cache behavior rather than continuing plot simplification.
- Keep a manual visual sanity note for any accepted simplification; automated probes can prove readiness but not whether analysts still see the expected chart story.

## Tranche Execution Notes

- 2026-07-31 Branch I implementation start and audit amendments:
  - Resumed implementation from the validated planning handoff; no product simplification has been selected.
  - Completed I-4 by reaffirming Branch H framing: Trend/Heatmap delays cluster around late Shiny/htmlwidget and Plotly materialization events, while payload complexity remains only the first measurable suspect.
  - Added audit constraints before source instrumentation: preserve simple cache execution counters, put complexity details on existing `log_perf()` records, avoid browser-side full Plotly data serialization, separate server-complexity capture from warm repeated-use baseline, and require relative acceptance against same-run Map/Current movement.
  - Current implementation hypothesis: cheap data-derived server metrics plus bounded client-observed Plotly complexity estimates can disconfirm payload complexity without materially perturbing readiness timing.
  - Cheap disconfirmation check: parse checks must pass after instrumentation, and the first server-complexity capture must show whether render-body details are present before judging product behavior.

- 2026-07-31 Branch I server complexity instrumentation:
  - Edited `VP Clone/Programs/app_source/server/05_trend_and_heatmap.R` only.
  - Left `record_cache_body_execution(session, "timeseries_plot_executed")` and `record_cache_body_execution(session, "heatmap_plot_executed")` unchanged as simple execution counters.
  - Added Trend details on `log_perf("timeseries_plot", ...)`: `source_choice`, `frequency`, `n_input_rows`, `n_filtered_rows`, `n_recent_rows`, `n_historical_rows`, `n_selected_years`, `n_historical_years`, `expected_trace_count`, `expected_point_count`, `expected_annotation_count`, `uses_markers`, `uses_hist_avg`, `uses_projection`, `emphasize_mode`, `hist_window`, and `hover_text_chars_est`.
  - Added Heatmap details on `log_perf("heatmap_plot", ...)`: `source_choice`, `frequency`, `n_input_rows`, `n_heatmap_base_rows`, `n_years`, `n_periods`, `n_cells`, `n_non_na_cells`, `customdata_cells`, `colorscale_type`, `colorscale_length`, and `hover_customdata_chars_est`.
  - Validation passed: `PARSE_OK_BRANCH_I_TREND_HEATMAP_SOURCE`.

- 2026-07-31 Branch I passive probe complexity instrumentation:
  - Edited `VP Clone/System/Testing/vp_perf_probe_single_action_latency.R` only.
  - Extended `output_snapshot()` with passive bounded Plotly complexity estimates from existing `el.data`; no Plotly lifecycle binding, no direct node observers, and no full `JSON.stringify(el.data)` serialization were added.
  - Added action-row columns: `output_plotly_trace_count`, `output_plotly_point_count`, `output_plotly_cell_count`, `output_plotly_array_value_count`, `output_plotly_text_chars_est`, `output_plotly_customdata_chars_est`, `output_js_heap_used_size`, `output_js_heap_total_size`, and `output_js_heap_size_limit`.
  - Heap fields remain experimental and may be blank/`NA` when `performance.memory` is unavailable.
  - Validation passed: `PARSE_OK_BRANCH_I_COMPLEXITY_PROBE`.
  - Step I-6 recenter confirmation on 2026-07-31: `get_errors` found no diagnostics for the probe; the probe parsed successfully; both Branch I probe CSVs contained all new complexity columns; all required non-heap complexity fields were nonblank for all four rows in both CSVs; heap fields remained optional. No additional Step I-6 work is indicated before continuing Step I-7.

- 2026-07-31 Branch I server-complexity capture probe:
  - Started `step16_branch_i_trend_heatmap_server_complexity_capture` with `--scenario=tab_only`, `--cache-state=server_complexity_capture`, and `--runtime-perf=true`.
  - The execution wrapper timed out after 120000ms, but the R process continued in background terminal `39a74426-3105-43af-9c4a-03b9f4655e86` and completed successfully.
  - Final status counts: `PASS=4`.
  - Output CSV: `VP Clone/Logs/vp_perf_probe_single_action_latency_step16_branch_i_trend_heatmap_server_complexity_capture_20260731T161908Z.csv`.
  - Requested runtime log path: `VP Clone/Logs/vp_runtime_perf_single_action_step16_branch_i_trend_heatmap_server_complexity_capture_20260731T161908Z.jsonl`.
  - Exact fallback runtime input: `VP Clone/Logs/vp_runtime_perf_c038f8f47fbd99d7918b0982de561f11.jsonl|VP Clone/Logs/vp_runtime_perf_proc_20260731T161924Z_30132.jsonl`.
  - Total probe time: `257770ms`.
  - Exact fallback runtime summary outputs: `VP Clone/Logs/vp_perf_runtime_summary_step16_branch_i_trend_heatmap_server_complexity_capture_runtime_20260731T163120Z_*.csv`.
  - Partial markers observed so far: startup wait passed, required-controls wait timed out after 30231ms but setup continued, all eight canonical setup stages passed, `setup_current_output_ready` passed in 75ms.
  - Completed action rows: Historical Trend `PASS` with `visible_ready_ms=14400`, `client_interaction_ready_ms=14456`, `full_idle_ms=14976`; Heatmap `PASS` with `visible_ready_ms=17356`, `client_interaction_ready_ms=17676`, `full_idle_ms=18204`; Map `PASS` with `visible_ready_ms=20503`, `client_interaction_ready_ms=20571`, `full_idle_ms=21083`; Current vs. Average `PASS` with `visible_ready_ms=15600`, `client_interaction_ready_ms=15674`, `full_idle_ms=16541`.
  - New client complexity fields populated in the probe CSV. Historical Trend row: `output_plotly_trace_count=6`, `output_plotly_point_count=55`, `output_plotly_cell_count=0`, `output_plotly_array_value_count=163`, `output_plotly_text_chars_est=5882`, `output_plotly_customdata_chars_est=0`. Heatmap row: `output_plotly_trace_count=1`, `output_plotly_point_count=120`, `output_plotly_cell_count=120`, `output_plotly_array_value_count=154`, `output_plotly_text_chars_est=63`, `output_plotly_customdata_chars_est=74`. Map comparison row: `output_plotly_trace_count=2`, `output_plotly_point_count=20`, `output_plotly_cell_count=20`, `output_plotly_array_value_count=40`, `output_plotly_text_chars_est=2098`, `output_plotly_customdata_chars_est=119`. Current comparison row: `output_plotly_trace_count=4`, `output_plotly_point_count=44`, `output_plotly_cell_count=0`, `output_plotly_array_value_count=105`, `output_plotly_text_chars_est=1528`, `output_plotly_customdata_chars_est=0`.
  - New server details fired in `VP Clone/Logs/vp_runtime_perf_proc_20260731T161924Z_30132.jsonl`. `timeseries_plot` had `elapsed_seconds=0.1629`, `expected_trace_count=6`, `expected_point_count=55`, `hover_text_chars_est=530`, `n_input_rows=113`, `n_filtered_rows=41`, `n_recent_rows=5`, and `n_historical_rows=36`. `heatmap_plot` had `elapsed_seconds=0.3867`, `n_input_rows=113`, `n_heatmap_base_rows=120`, `n_cells=120`, `n_non_na_cells=113`, `customdata_cells=12`, and `hover_customdata_chars_est=74`.
  - Initial interpretation: render-body server construction is small relative to the 14-17s Trend/Heatmap visible-readiness waits in this capture run; Branch I should continue to the warm repeated-use baseline before selecting any product simplification.
  - Next action: run the official warm repeated-use baseline `step16_branch_i_trend_heatmap_complexity_baseline`.

- 2026-07-31 Branch I warm repeated-use baseline:
  - Started `step16_branch_i_trend_heatmap_complexity_baseline` with `--scenario=tab_only`, `--cache-state=warm_partition_disk`, and `--runtime-perf=true`.
  - The execution wrapper timed out after 120000ms, but the R process continued in background terminal `8f866910-ffc6-4e3e-b7b2-a459f5c8ae58` and completed successfully.
  - Final status counts: `PASS=4`.
  - Output CSV: `VP Clone/Logs/vp_perf_probe_single_action_latency_step16_branch_i_trend_heatmap_complexity_baseline_20260731T163305Z.csv`.
  - Requested runtime log path: `VP Clone/Logs/vp_runtime_perf_single_action_step16_branch_i_trend_heatmap_complexity_baseline_20260731T163305Z.jsonl`.
  - Exact fallback runtime input: `VP Clone/Logs/vp_runtime_perf_36dd99378d76c99755a1efd6f7fa40dc.jsonl|VP Clone/Logs/vp_runtime_perf_proc_20260731T163324Z_15484.jsonl`.
  - Total probe time: `164759ms`.
  - Exact fallback runtime summary outputs: `VP Clone/Logs/vp_perf_runtime_summary_step16_branch_i_trend_heatmap_complexity_baseline_runtime_20260731T164110Z_*.csv`; summarizer read 373 records and emitted files/events/timed/key-delta/churn/partition/memory CSVs.
  - Setup markers: startup wait passed, required-controls wait passed in 22702ms, all eight canonical setup stages passed, and `setup_current_output_ready` passed in 45ms.
  - Completed action rows: Historical Trend `PASS` with `visible_ready_ms=10025`, `client_interaction_ready_ms=10060`, `full_idle_ms=10576`; Heatmap `PASS` with `visible_ready_ms=9268`, `client_interaction_ready_ms=9292`, `full_idle_ms=9807`; Map `PASS` with `visible_ready_ms=13036`, `client_interaction_ready_ms=13342`, `full_idle_ms=13855`; Current vs. Average `PASS` with `visible_ready_ms=7463`, `client_interaction_ready_ms=7783`, `full_idle_ms=8303`.
  - New client complexity fields populated in the probe CSV. Historical Trend row: `output_plotly_trace_count=6`, `output_plotly_point_count=55`, `output_plotly_cell_count=0`, `output_plotly_array_value_count=163`, `output_plotly_text_chars_est=5882`, `output_plotly_customdata_chars_est=0`. Heatmap row: `output_plotly_trace_count=1`, `output_plotly_point_count=120`, `output_plotly_cell_count=120`, `output_plotly_array_value_count=154`, `output_plotly_text_chars_est=63`, `output_plotly_customdata_chars_est=74`. Map comparison row: `output_plotly_trace_count=2`, `output_plotly_point_count=20`, `output_plotly_cell_count=20`, `output_plotly_array_value_count=40`, `output_plotly_text_chars_est=2098`, `output_plotly_customdata_chars_est=119`. Current comparison row: `output_plotly_trace_count=4`, `output_plotly_point_count=44`, `output_plotly_cell_count=0`, `output_plotly_array_value_count=105`, `output_plotly_text_chars_est=1528`, `output_plotly_customdata_chars_est=0`.
  - Warm cached run server-detail check: `event == "log_perf"` with `tag` `timeseries_plot` or `heatmap_plot` was `0`, and `cache_body_execution` names `timeseries_plot_executed` or `heatmap_plot_executed` were `0` in `VP Clone/Logs/vp_runtime_perf_proc_20260731T163324Z_15484.jsonl`. Interpretation: `bindCache()` skipped Trend/Heatmap render bodies in the warm baseline, so warm-run server details are absent by design and client-observed complexity is authoritative for cached materialization.
  - Initial comparison: warm Historical Trend and Heatmap readiness were close to the established Branch G/H 10s cluster, while Map was slower and Current faster in the same run. Payload complexity was not obviously extreme: Trend had 6 traces/55 points and high text estimate; Heatmap had 1 trace/120 cells. This does not yet support a product simplification without additional evidence.
  - Recenter decision updated by user direction: skip the optional `tab_only_revisit` baseline and move on to the branch decision.

- 2026-07-31 Branch I decision and closeout:
  - Selected Branch I-0 attribution-only closeout. No product-code simplification was selected.
  - Reason: server-side Trend/Heatmap construction was small in the server-complexity capture run (`timeseries_plot` `elapsed_seconds=0.1629`; `heatmap_plot` `elapsed_seconds=0.3867`) compared with visible readiness waits of 14-17s in that same capture.
  - Warm cached repeated-use baseline confirmed `bindCache()` skipped Trend/Heatmap render bodies (`log_perf` rows and cache-body execution rows for Trend/Heatmap were both zero), so warm-run behavior is governed by cached delivery/materialization rather than server plot construction.
  - Client-observed complexity did not identify a clear low-risk payload simplification: warm Trend had 6 traces / 55 points / 5882 text-character estimate, Heatmap had 1 trace / 120 cells / 74 customdata-character estimate, Map had 2 traces / 20 cells, and Current had 4 traces / 44 points. The evidence does not isolate Trend/Heatmap payload complexity as the dominant readiness cause.
  - Rejected product branches for Branch I: Trend trace/marker/point reduction, Trend hover/annotation reduction, Heatmap customdata/cell reduction, and server plot construction reduction. Rejection basis is insufficient causal evidence and no clear low-risk semantic simplification target.
  - Carried forward as next recommendation: if the repeated-use priority remains Trend/Heatmap visible readiness, open a separate Shiny/htmlwidget delivery/output-settling branch focused on late `shiny:value`, `plotly_afterplot`, `.main-svg`, loading-clear, and readiness timing under cached delivery. If the product priority shifts, return to known full-idle churn surfaces such as summary/display-month/year-filter work.
  - Validation at closeout: source parse marker `PARSE_OK_BRANCH_I_TREND_HEATMAP_SOURCE`; probe parse marker `PARSE_OK_BRANCH_I_COMPLEXITY_PROBE`; server-complexity capture `PASS=4`; warm repeated-use baseline `PASS=4`; exact fallback runtime summaries recorded for both runs; `get_errors` found no diagnostics for the probe and ledger; known Shiny-scope static analyzer noise remains in `05_trend_and_heatmap.R` but targeted R parse passed; `git diff --check` was clean for touched source/ledger files.
  - Final validation markers: `PARSE_OK_BRANCH_I_FINAL_TREND_HEATMAP_SOURCE` and `PARSE_OK_BRANCH_I_FINAL_COMPLEXITY_PROBE`; `get_errors` found no diagnostics for the parent plan, daughter plan, or probe; final `git diff --check` was clean for `05_trend_and_heatmap.R`, `vp_perf_probe_single_action_latency.R`, the Branch I daughter plan, and the parent performance plan.

- 2026-07-30 Branch I plan creation:
  - Created this daughter plan as a self-contained handoff record before source-code implementation.
  - Recentered Branch I around Shiny/htmlwidget delivery and Plotly materialization, not assumed payload complexity.
  - Carried forward Branch G/H rejected approaches so future work does not repeat known bad branches.
  - Parent plan delegation was added: Branch I is Step 16; deferred build-time aggregation/artifact/final-validation rows shifted to Steps 17-19.
  - Planning handoff validation passed: `get_errors` found no diagnostics for the parent/daughter plan files, and `git diff --check` produced no output for those files.
  - This note is historical. Branch I implementation started on 2026-07-31; current active work is Step I-7 baseline/revisit measurement.

## Summary

Branch I closed as an attribution-only measurement branch. We added safe measurement to the Historical Trend and Heatmap server render bodies and passive client-side Plotly complexity fields to the single-action latency probe. No user-facing chart behavior was intentionally changed.

The measurements did not prove payload complexity or server plot construction as the cause of the slow Trend/Heatmap tab readiness. In the server-complexity capture run, Trend and Heatmap render-body work was small (`timeseries_plot` about 0.16s and `heatmap_plot` about 0.39s), while visible readiness still waited many seconds. In the warm repeated-use baseline, Trend and Heatmap render bodies did not execute at all because `bindCache()` served cached outputs, yet visible readiness still clustered near the established Branch G/H window. Client complexity also was not extreme enough to justify a semantic simplification branch by itself.

No product-code experiment was selected. The rejected Branch I product paths were Trend trace/marker/point reduction, Trend hover/annotation reduction, Heatmap customdata/cell reduction, and server plot construction reduction. The major blocker investigated was whether complexity was the low-risk cause; current evidence says it is not proven.

Recommended next target: a separate Shiny/htmlwidget delivery or output-settling branch for cached Trend/Heatmap readiness, focused on late `shiny:value`, `plotly_afterplot`, `.main-svg`, loading-clear, and readiness timing. If the priority shifts away from visible tab readiness, return to the known full-idle churn surfaces such as summary/display-month/year-filter work.