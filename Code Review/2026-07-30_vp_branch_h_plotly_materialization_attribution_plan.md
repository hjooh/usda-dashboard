# VP Branch H Plotly Materialization Attribution Plan

Date: 2026-07-30
Branch: main
Status: Closed / attribution-only Branch H. This daughter plan remains the detailed Branch H evidence ledger. Branch G remains closed. Parent-plan closeout is complete. Probe timeline attribution produced tab-only, revisit, lightweight lifecycle, and resize-state baselines. App code was edited only for measurement payload fields, not behavior optimization.

## Purpose

Branch H is a measurement-first follow-up to Branch G. Branch G proved that the VP app's manual-feel tab problem is not primarily the tab click shell itself: real tab clicks and tab paint events were cheap, while settled tab Plotly/widget readiness clustered around 10 seconds. Branch H exists to attribute that 10-second window before making another product-code optimization.

The target is the path between tab activation and a truly ready Plotly/htmlwidget output. Branch H must determine whether the delay lives in server render work, Shiny/htmlwidget output delivery, hidden-output invalidation, widget DOM insertion, Plotly draw/afterplot, resize/redraw ordering, readiness-predicate sequencing, probe overhead, or residual tab/client observer churn.

This plan is intentionally detailed because implementation may be delayed. A future coder should be able to resume from this file without replaying chat history.

## Scope

Included:
- Create this daughter source-of-truth ledger before Branch H probe or product-code edits.
- Recenter on the parent performance plan after Branch G closeout.
- Preserve Branch G as closed and accepted as a measurement tranche.
- Add action-scoped browser/client timeline attribution for tab-to-Plotly readiness.
- Prefer probe-only instrumentation before touching app product code.
- Run a narrow tab-only Branch H baseline before any full canonical action rerun.
- Compare probe timeline fields with existing runtime PERF plot, tab, resize, cache, and provider summaries.
- Separate first-visit tab materialization from revisit tab-switch behavior where cheap.
- Treat attribution-only closeout as a successful outcome if no low-risk product branch is proven.

Excluded until evidence proves otherwise:
- Extending Branch G as a product-code branch.
- Startup/artifact/data-format work. Startup remains intentionally deferred for repeated-use latency unless Branch H proves it affects tab readiness during ordinary use.
- Broad hidden-output warming. Branch G tested and rejected unsuspending Trend/Heatmap hidden Plotly outputs.
- Removing `Plotly.redraw()` as a first fix. Branch G tested and rejected that path.
- Broad `bindCache()` rewrites, tabset architecture changes, JS throttling, loading polish, or cosmetic waiting states.
- Making display-month/year-filter/summary churn the first Branch H target. Those remain secondary full-idle candidates, not the primary explanation for the 10-second tab readiness finding.
- A paired results markdown file unless explicitly requested.

## Parent Plan Linkage

Parent plan: `VP Clone/Code Review/2026-07-29_vp_performance_hotspot_recovery_plan.md`.

Current parent state after Branch H delegation:
- Step 14 Branch G is complete as a measurement branch with no accepted product-code branch.
- Step 15 Branch H Plotly materialization attribution is active and delegated to this file.
- Step 16 build-time aggregation instrumentation/tuning is deferred.
- Step 17 narrower artifacts/data formats is deferred.
- Step 18 final validation and Summary is not started.

Required parent update at Branch H closeout:
- Keep Step 14 Branch G closed.
- Record Branch H outcome, labels, output CSVs, fallback JSONLs, runtime summary CSVs, accepted/rejected changes, residual blockers, and next recommendation in the parent.
- Keep build-time aggregation and artifact/data-format work deferred unless Branch H evidence changes that priority.

This daughter plan owns detailed Branch H implementation notes. The parent should contain only the compact delegation and later closeout summary.

## Source-Of-Truth Ledger Contract

- This file is the active source of truth for Branch H once parent delegation is added.
- Update this file after every Branch H step or tranche before moving to the next tranche.
- Record files touched, commands/probes, labels, cache states, runtime log paths, fallback JSONL inputs, summary CSVs, action IDs, timeline fields, visible/client/full-idle timings, final selected states, output attribution quality, stale-output checks, browser diagnostics, provider summaries, branch decisions, bugs, blockers, failed attempts, rejected approaches, and validation gates.
- Keep parent-plan updates limited to delegation and closeout while this daughter is active.
- Preserve enough detail for delayed implementation or context compaction.

## Baseline Evidence

Closed Branch G daughter plan:
- `VP Clone/Code Review/2026-07-30_vp_branch_g_perceived_interaction_latency_single_action_plan.md`.
- Accepted source change: `VP Clone/System/Testing/vp_perf_probe_single_action_latency.R`.
- Branch G created a single-action perceived-latency probe with real tab anchor clicks, per-action rows, visible-ready timing, client-interaction-ready timing, full-idle timing, browser diagnostics, final selected-state snapshots, stale-output checks, requested runtime log paths, and exact fallback runtime log discovery.
- Branch G hardened the probe after discovering that Plotly widgets mounted on the output root were not counted by the original descendant-only snapshot logic.
- Hardened plot readiness requires widget/Plotly markers for plot outputs rather than generic nonempty text.

Branch G hardened baseline:
- Label: `step14_branch_g_single_action_plotly_ready_baseline`.
- Status: `PASS=11`.
- Output CSV: `VP Clone/Logs/vp_perf_probe_single_action_latency_step14_branch_g_single_action_plotly_ready_baseline_20260730T171015Z.csv`.
- Requested runtime log path did not materialize.
- Exact fallback runtime input: `VP Clone/Logs/vp_runtime_perf_proc_20260730T171032Z_40560.jsonl|VP Clone/Logs/vp_runtime_perf_96221a8012f7e368dc621348ccddaca8.jsonl`.
- Runtime summaries: `VP Clone/Logs/vp_perf_runtime_summary_runtime_logs_20260730T171441Z_*.csv`.

Branch G timing interpretation:
- Commodity visible readiness was fast in the canonical run: about 63-71ms.
- Hierarchy visible readiness was fast in the canonical run: about 58-98ms.
- Hierarchy/filter full-idle tails remained long: about 10-22s in the canonical actions.
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
- Removing `Plotly.redraw()` from the `forcePlotlyResize` client handler worsened settled tab readiness to roughly 11.7-16.2s and was reverted.
- Gating hidden Pace default-target work caused partial rows, required-control wait timeouts, output visible-ready timeouts, and full-idle timeouts; it was reverted.
- Unsuspending hidden Trend/Heatmap Plotly outputs regressed to `PARTIAL=11`, with visible-ready timeouts and idle failures, and was reverted.

Post-closeout marketing-year/display-month decision context:
- Almond marketing-year start metadata is already largely config/pipeline-backed through `market_year_start_month = 8L` in `VP Clone/System/Config/commodity_contract.R`.
- VP artifacts already carry processed fields including `market_year`, `analysis_month`, `MonthNum`, `month_abbrev`, `month_name`, and `calendar_signature`.
- Runtime `current_display_month_mapping()` derives context-specific VP trade display-month mappings from processed VP rows and session-caches them.
- Prior Branch C evidence showed `calendar_signature` varies by trade, group, subgroup, market segment, and some commodity-name contexts, so broad display-month shortcuts are unsafe without narrow keys.
- Branch G churn showed display-month mapping is frequently touched, mostly as cache hits, but timed evidence does not make it the primary driver of 10s tab readiness. Keep it as a secondary full-idle candidate only.

## Branch H Baseline Evidence

Tab-only first-pass baseline:
- Label: `step15_branch_h_plotly_timeline_tab_baseline`.
- Scenario: `tab_only`.
- Cache state: `warm_partition_disk`.
- Status: `PASS=4`.
- Output CSV: `VP Clone/Logs/vp_perf_probe_single_action_latency_step15_branch_h_plotly_timeline_tab_baseline_20260730T180048Z.csv`.
- Requested runtime log path: `VP Clone/Logs/vp_runtime_perf_single_action_step15_branch_h_plotly_timeline_tab_baseline_20260730T180048Z.jsonl`.
- Exact fallback runtime input: `VP Clone/Logs/vp_runtime_perf_1710ae04414dc3a4ccb1210895bdb0bd.jsonl|VP Clone/Logs/vp_runtime_perf_proc_20260730T180052Z_21124.jsonl`.
- Runtime summary prefix: `VP Clone/Logs/vp_perf_runtime_summary_step15_branch_h_plotly_timeline_tab_baseline_runtime_20260730T180343Z_*.csv`.
- Runtime summary counts: 2 files, 409 records.
- Probe total elapsed: 166442ms.

Tab-only first-pass timings:

| Action | Visible ready | Client ready | Full idle | Tab shown | Main SVG | Loading clear | Readiness mark | Client echo |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Historical Trend | 12384ms | 12687ms | 13197ms | 15ms | 12182ms | 12182ms | 12379ms | 12681ms |
| Heatmap | 12277ms | 12582ms | 13108ms | 22ms | 12021ms | 12022ms | 12266ms | 12570ms |
| Map | 14803ms | 14839ms | 15361ms | 20ms | 11141ms | 11076ms | 14795ms | 14827ms |
| Current vs. Average | 9689ms | 9760ms | 10549ms | 54ms | 0ms | 9499ms | 9676ms | 9746ms |

Tab-only revisit baseline:
- Label: `step15_branch_h_plotly_timeline_tab_revisit_baseline`.
- Scenario: `tab_only_revisit`.
- Cache state: `warm_partition_disk`.
- Status: `PASS=8`.
- Output CSV: `VP Clone/Logs/vp_perf_probe_single_action_latency_step15_branch_h_plotly_timeline_tab_revisit_baseline_20260730T180439Z.csv`.
- Requested runtime log path: `VP Clone/Logs/vp_runtime_perf_single_action_step15_branch_h_plotly_timeline_tab_revisit_baseline_20260730T180439Z.jsonl`.
- Exact fallback runtime input: `VP Clone/Logs/vp_runtime_perf_c03840c76b5bec3c6a62796931188dfb.jsonl|VP Clone/Logs/vp_runtime_perf_proc_20260730T180443Z_1572.jsonl`.
- Runtime summary prefix: `VP Clone/Logs/vp_perf_runtime_summary_step15_branch_h_plotly_timeline_tab_revisit_baseline_runtime_20260730T180825Z_*.csv`.
- Runtime summary counts: 2 files, 487 records.
- Probe total elapsed: 212640ms.

Tab-only revisit timings:

| Action | Visible ready | Client ready | Full idle | Tab shown | Main SVG | Loading clear | Readiness mark | Client echo |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Historical Trend first pass | 10643ms | 10706ms | 11228ms | 20ms | 10449ms | 10449ms | 10631ms | 10691ms |
| Heatmap first pass | 10612ms | 10902ms | 11422ms | 27ms | 10387ms | 10387ms | 10599ms | 10899ms |
| Map first pass | 13382ms | 13450ms | 13977ms | 14ms | 10195ms | 10146ms | 13363ms | 13419ms |
| Current first pass | 9361ms | 9663ms | 10173ms | 48ms | 0ms | 9118ms | 9351ms | 9652ms |
| Historical Trend revisit | 17916ms | 17971ms | 18489ms | 21ms | 0ms | 17721ms | 17900ms | 17950ms |
| Heatmap revisit | 13880ms | 14198ms | 14720ms | 27ms | 0ms | 13631ms | 13872ms | 14191ms |
| Map revisit | 11428ms | 11725ms | 12241ms | 50ms | 0ms | 11034ms | 11420ms | 11718ms |
| Current revisit | 11959ms | 12006ms | 12784ms | 50ms | 0ms | 11741ms | 11942ms | 11990ms |

Initial Branch H interpretation:
- Both Branch H runs reproduce slow tab readiness without product-code edits. The first-pass run shows visible-ready delays from about 9.7s to 14.8s; the revisit run shows repeated tab switches from about 11.4s to 17.9s. This disconfirms a simple one-time hidden-widget materialization explanation.
- Tab shell and paint are consistently early relative to output readiness. `tab_shown` is about 14-54ms in these rows, while readiness remains many seconds later.
- Widget/htmlwidget roots generally exist at action start (`widget_inserted_ms=0` on all rows), so the delay is not initial widget-root insertion.
- For first-pass Historical Trend and Heatmap, `.main-svg` insertion and loading-indicator clearance land near the visible-ready delay, which keeps Plotly materialization in scope.
- For Map, `.main-svg` and loading-clear can appear several seconds before the readiness predicate, especially in the first-pass run. That points to additional readiness/output-state settling after initial SVG creation.
- For Current vs. Average and revisit rows, `.main-svg` may already exist at action start while loading-indicator clearance and readiness still occur around the visible-ready delay. That points away from first SVG insertion alone and toward redraw/loading-state/output-settling behavior.
- Existing runtime summary does not show server plot rendering as a 10s elapsed bucket. In the first-pass run, `timeseries_plot` logged about 0.119s and `map_plot` totaled about 0.902s across 3 rows; `observeEvent(main_tabs_panel)` totaled about 0.054s. In the revisit run, top timed rows remain client tab events and startup, while the visible-ready delays are many seconds.
- Runtime churn still shows display-month mapping, summary table, year-filter sync, and map-bottom-panel activity, but this remains secondary full-idle/background churn unless correlated to visible readiness by narrower evidence.
- Event attribution caveat: `timeline_shiny_value_output_ms`, `timeline_plotly_afterplot_ms`, and `timeline_plotly_relayout_ms` are blank in all Branch H rows. Each row also reports `timeline_unattributed_event_count=2` and `timeline_mismatched_event_count=2`. Missing Shiny/Plotly lifecycle marks are evidence-quality gaps and should be investigated before treating afterplot/relayout absence as a product fact.
- Current best decision: do not make an app-code optimization yet. The next diagnostic should refine event attribution for `shiny:value`/Plotly lifecycle marks or inspect resize/loading-state ordering with a very small probe-only/app-level instrumentation addition, then rerun a narrow tab baseline.

Lightweight lifecycle attribution probe:
- Label: `step15_branch_h_light_lifecycle_attribution_probe`.
- Scenario: `tab_only`.
- Cache state: `warm_partition_disk`.
- Status: `PASS=4`.
- Output CSV: `VP Clone/Logs/vp_perf_probe_single_action_latency_step15_branch_h_light_lifecycle_attribution_probe_20260730T181801Z.csv`.
- Requested runtime log path: `VP Clone/Logs/vp_runtime_perf_single_action_step15_branch_h_light_lifecycle_attribution_probe_20260730T181801Z.jsonl`.
- Exact fallback runtime input: `VP Clone/Logs/vp_runtime_perf_5fc822e9572d4091ec7151a3728d62ab.jsonl|VP Clone/Logs/vp_runtime_perf_proc_20260730T181805Z_25576.jsonl`.
- Runtime summary prefix: `VP Clone/Logs/vp_perf_runtime_summary_step15_branch_h_light_lifecycle_attribution_probe_runtime_20260730T182053Z_*.csv`.
- Runtime summary counts: 2 files, 373 records.
- Probe total elapsed: 164011ms.

Lightweight lifecycle timings:

| Action | Visible ready | Shiny value | Afterplot | Main SVG | Loading clear | Readiness mark | Client echo |
|---|---:|---:|---:|---:|---:|---:|---:|
| Historical Trend | 11116ms | 10912ms | 10983ms | 10983ms | 10983ms | 11108ms | 11157ms |
| Heatmap | 11165ms | 10883ms | 10973ms | 10972ms | 10972ms | 11163ms | 11189ms |
| Map | 14584ms | 10946ms | 11185ms | 11021ms | 10948ms | 14578ms | 14877ms |
| Current vs. Average | 8981ms | 8783ms | 99ms | 0ms | 8792ms | 8972ms | 9297ms |

Lightweight lifecycle interpretation:
- The successful lightweight lifecycle run preserves the original timing shape better than the failed direct-binding probe: Trend and Heatmap remain about 11.1s visible-ready, Map about 14.6s, and Current about 9.0s.
- The previously missing `shiny:value` and `plotly_afterplot` marks now populate for all rows. `plotly_relayout` only appears for Current in the failed direct-binding run and remains absent in the successful lightweight run, so relayout is not yet a reliable attribution signal.
- Trend and Heatmap now attribute the delay to late Shiny/htmlwidget/Plotly delivery and materialization: `shiny:value`, `plotly_afterplot`, `.main-svg`, loading-clear, and readiness all occur around 10.9-11.2s.
- Map separates into two windows: first Shiny/htmlwidget/Plotly materialization appears around 10.9-11.2s, but readiness does not pass until 14.6s. That suggests additional Map output churn or readiness-state settling after the first afterplot/SVG.
- Current has early afterplot/main SVG but late `shiny:value`, loading-clear, and readiness around 8.8-9.0s, which points to redraw/loading-state/output-settling rather than first SVG insertion.
- Event quality improved but remains imperfect: unattributed and mismatched counts rose because Shiny and Plotly lifecycle events from adjacent outputs are now captured. The matched expected-output timeline marks are useful, but event counts should not be interpreted as exact workload counts.
- Current best branch decision remains no product-code edit. The strongest next attribution target is resize/loading-state/output-settling, especially Map post-afterplot readiness delay and Current late loading-clear despite existing SVG.

Resize-state attribution probe:
- Label: `step15_branch_h_resize_state_attribution_probe`.
- Scenario: `tab_only`.
- Cache state: `warm_partition_disk`.
- Status: `PASS=4`.
- App measurement edit: `VP Clone/Programs/app_source/ui.R` now adds target output state fields to existing `client_perf_plotly_resize` and `client_perf_plotly_resize_skipped` payloads. It does not change resize/redraw behavior.
- Output CSV: `VP Clone/Logs/vp_perf_probe_single_action_latency_step15_branch_h_resize_state_attribution_probe_20260730T182222Z.csv`.
- Requested runtime log path: `VP Clone/Logs/vp_runtime_perf_single_action_step15_branch_h_resize_state_attribution_probe_20260730T182222Z.jsonl`.
- Exact fallback runtime input: `VP Clone/Logs/vp_runtime_perf_2f90e5d9c28996da7161742f81c37950.jsonl|VP Clone/Logs/vp_runtime_perf_proc_20260730T182226Z_38920.jsonl`.
- Runtime summary prefix: `VP Clone/Logs/vp_perf_runtime_summary_step15_branch_h_resize_state_attribution_probe_runtime_20260730T182503Z_*.csv`.
- Runtime summary counts: 2 files, 373 records.
- Probe total elapsed: 149992ms.

Resize-state timings:

| Action | Visible ready | Shiny value | Afterplot | Main SVG | Loading clear | Readiness mark |
|---|---:|---:|---:|---:|---:|---:|
| Historical Trend | 10878ms | 10623ms | 10701ms | 10701ms | 10701ms | 10868ms |
| Heatmap | 8394ms | 8109ms | 8178ms | 8177ms | 8177ms | 8387ms |
| Map | 12843ms | 9835ms | 9986ms | 9886ms | 9836ms | 12832ms |
| Current vs. Average | 8640ms | 8364ms | 88ms | 0ms | 8370ms | 8630ms |

Resize-state runtime interpretation:
- Runtime `plotly_resize` rows show the resize custom message is not reaching the browser immediately after tab click. The first relevant rows reported client `action_elapsed_ms` around 7.2-9.1s for Historical Trend, Heatmap, and Map, shortly before the `shiny:value`/afterplot/readiness window.
- For Historical Trend, Heatmap, and Map, the target output was present, visible, and had one widget at resize time, but `target_main_svg_count_before=0`, `target_loading_indicator_count_before=2`, and `resized_count=0`. After resize and after paint, those fields remained unchanged. This means the handler was firing while the target was still loading and before a usable Plotly graph SVG existed; it did not successfully resize/redraw a graph for those actions.
- For the first Current resize row, the target was also present and visible but had no main SVG and still had loading indicators, with `resized_count=0`.
- A later Current resize row saw `main_svg_count=3` and `resized_count=1` while `target_visible=false` and loading indicators still present, consistent with resize/redraw work happening out of phase with the final visible-ready condition.
- This evidence weakens `forcePlotlyResize` cost as the primary 8-14s latency driver. The handler itself still takes only about 123-158ms in runtime logs. The more important finding is ordering: the custom message is delivered late and usually before the expected output has a ready graph to resize.
- Current best branch decision remains measurement-only. A product change to resize ordering is not yet safe because the delay appears upstream of resize handler execution for Trend/Heatmap and only partially explains Map/Current post-materialization readiness.

## Technical Read

Primary probe anchor:
- `VP Clone/System/Testing/vp_perf_probe_single_action_latency.R`.
- Relevant functions:
  - `install_browser_observers()` installs count-only browser observers for `shiny:busy`, `shiny:idle`, input changes, `plotly_afterplot`, `plotly_relayout`, and body `MutationObserver` activity.
  - `output_snapshot()` records output presence, visibility, dimensions, widget count, text length, Plotly node counts, SVG counts, loading indicators, and per-output afterplot counts.
  - `browser_diagnostics()` records DOM node count, shiny-busy count, Plotly/widget counts, busy/idle/input/afterplot/relayout/mutation counters.
  - `snapshot_ready()` and `is_output_ready()` implement Plotly-aware readiness.
  - `measure_action()` records target acceptance, visible readiness, client interaction readiness, full idle, output snapshot, final state, browser diagnostics, and runtime log metadata.
  - `run_probe()` currently runs hierarchy, commodity, settled tab, and tab-while-pending actions.

Client/UI surfaces:
- `VP Clone/Programs/app_source/ui.R`.
- Relevant client paths:
  - `perfState`, `beginPerfAction()`, and `emitClientPerf()` provide existing client PERF plumbing.
  - Main-tab click handler records `lastTabClickedAt`, `lastTabName`, and starts a perf action.
  - `shown.bs.tab` handler emits `client_perf_tab_shown` and `client_perf_tab_after_paint`.
  - `forcePlotlyResize` custom message handler debounces 120ms, checks active tab, finds visible `.plotly.html-widget` nodes, dispatches window `resize`, calls `Plotly.Plots.resize(this)`, then calls `Plotly.redraw(this)` if available, and emits coarse `client_perf_plotly_resize` with elapsed time, resized count, and visible widget count.
- Branch G already proved that simply removing `Plotly.redraw()` worsens readiness. Resize/redraw sequencing remains inspectable, but not as a first unmeasured fix.

Server client-PERF and tab surfaces:
- `VP Clone/Programs/app_source/server/02_partner_and_notes.R`.
- Relevant paths:
  - `log_client_perf()` enriches client PERF events with source switch fields, server source, server tab, request action id, mutation sequence, and action reason, then writes runtime `client_perf` records.
  - `observeEvent(input$main_tabs_panel)` handles tab-driven frequency changes and sends `forcePlotlyResize` when `should_send_plotly_resize_for_tab(active_tab, source_choice)` is true.
  - `forcePlotlyResize` is sent immediately after tab input changes on the server, then debounced by 120ms in the browser. A resize event may be premature if the target output is still hidden or zero-sized.
  - `output$main_tabs`, `main_tabs_render_nonce`, `current_main_tab_safe()`, `is_effective_map_tab_active()`, and `should_send_plotly_resize_for_tab()` are related tab/readiness surfaces.

Server Plotly output surfaces:
- `VP Clone/Programs/app_source/server/04_comparison_plots.R`:
  - `output$comparison_plot <- renderPlotly(...)`.
  - Active-tab gate through `is_current_vs_average_output_active()`.
  - `comparison_plot_gated_skip` and `comparison_plot_executed` counters.
  - `log_perf("comparison_plot", start_time)` before returning `out`.
  - `bindCache(...)` with extensive base and extension cache keys.
- `VP Clone/Programs/app_source/server/05_trend_and_heatmap.R`:
  - `output$timeseries_plot <- renderPlotly(...)` with `timeseries_plot_executed`, `log_perf("timeseries_plot", start_time)`, and `bindCache(...)`.
  - `output$heatmap_plot <- renderPlotly(...)` with `heatmap_plot_executed`, `log_perf("heatmap_plot", start_time)`, and `bindCache(...)`.
  - `output$map_plot <- renderPlotly(...)` with active Map gating through `is_effective_map_tab_active()`, `map_plot_gated_skip`, `map_plot_executed`, and `finalize_map_plot()` logging `map_plot` or `psd_map_plot`.

Runtime summarizer:
- `VP Clone/System/Testing/vp_perf_summarize_runtime_logs.R`.
- Use `--input=...` with exact fallback JSONL paths separated by `|`.
- Do not use `--log=...`; repository memory notes say it is ignored and defaults to latest logs.

## Local Hypothesis And Cheap Disconfirmation

Local hypothesis:
- Branch G's 10s tab readiness delay is real enough to investigate but not yet attributed. The most likely controlling path is between tab activation and Plotly/htmlwidget readiness, not raw tab switching, Provider v3 disk reads, startup artifact loading, or marketing-year start determination.

Cheap disconfirmation checks:
- If action-scoped browser timeline marks show output nonzero size, widget insertion, `.main-svg`, and/or visually usable state materially earlier than Branch G `visible_ready_ms`, then the readiness predicate is too conservative and must be fixed before product-code work.
- If relevant server `log_perf()` plot buckets are near the 10s window and execution/cache counters show real render execution, target server plot data/render work.
- If server render is small but matching `shiny:value`, DOM mutation, or widget insertion is late, target Shiny/htmlwidget output delivery or hidden-output invalidation.
- If widget insertion is early but `.main-svg` or `plotly_afterplot` is late, target Plotly materialization.
- If resize/redraw fires while the target output is hidden or zero-sized, target resize ordering rather than resize cost.

## Guardrails

Measurement guardrails:
- Keep Branch H measurement-first. Do not begin product-code optimization until the timeline attributes the 10s window.
- Use action-scoped timeline reset before every measured action.
- Tag every browser timeline mark with `action_id`, expected output id, and target tab.
- Record both matched and unmatched output attribution for events.
- Record missing or unattributed event counts explicitly; do not silently interpret missing events as absent work.
- Keep browser observer work minimal. MutationObserver and frequent DOM polling can perturb the timing being measured.
- Do not compare browser `performance.now()` absolute values to R `Sys.time()` absolute values. Use browser-relative marks within an action, and use runtime logs only as coarse corroboration by action/window.

Correctness guardrails:
- Preserve final source/trade-flow/hierarchy/commodity/country/metric/tab path.
- Preserve Current-vs-Average, Historical Trend, Heatmap, and Map behavior.
- Preserve final output-state consistency; no stale-output acceptance.
- Preserve Provider v3 behavior, direct-filter fallback, source identity checks, source-signature checks, row-order/source refusal, memory/disk cache health, and Map readiness.
- Preserve MYCT unless touched paths require targeted sanity checks.

Product-code guardrails:
- Product-code changes are optional in Branch H. Attribution-only closeout is acceptable and expected unless the baseline identifies a clear, low-risk branch.
- Make at most one small product-code experiment after attribution.
- Revert any experiment that worsens readiness, causes PARTIAL rows, breaks full idle, invalidates output correctness, increases instrumentation ambiguity, or leaves rejected app-code diffs.
- Do not remove `Plotly.redraw()` as a first fix.
- Do not warm broad hidden outputs.
- Do not pivot to startup/artifact work without explicit parent-plan amendment and evidence.

Runtime and generated-artifact guardrails:
- Requested runtime log paths often do not materialize. Exact fallback JSONLs remain authoritative.
- Record all output CSVs, runtime fallback inputs, and summary CSVs.
- Treat `VP Clone/Logs`, `VP Clone/System/Cache`, and generated `VP Clone/System/Processed Data` outputs as evidence unless explicitly approved as source changes.

## Measurement Model

Existing Branch G windows to preserve:
- `visible_ready_ms`: elapsed time from action start until primary output appears stable and selected-state checks pass.
- `client_interaction_ready_ms`: elapsed time until a lightweight follow-up client echo succeeds.
- `full_idle_ms`: elapsed time until Shiny idle/wait-for-idle succeeds.

New Branch H action-scoped timeline fields should include, where available:
- `timeline_action_zero_ms` or equivalent action-start anchor.
- `tab_click_accepted_ms`.
- `tab_shown_ms`.
- `tab_after_paint_ms`.
- `shiny_busy_first_ms`.
- `shiny_idle_last_ms`.
- `shiny_value_output_ms` for the expected output id.
- `output_first_mutation_ms` for the expected output id.
- `output_visible_nonzero_ms`.
- `widget_inserted_ms`.
- `main_svg_inserted_ms`.
- `plotly_afterplot_ms`.
- `plotly_relayout_ms`.
- `loading_indicator_cleared_ms`.
- `readiness_predicate_passed_ms`.
- `client_echo_ready_ms`.
- `resize_or_relayout_seen_ms` if probe-only JS can capture it.
- Compact `timeline_events` serialized field for detailed marks.

Attribution quality fields should include:
- Expected output id.
- Nearest output/root id for each output-related event family.
- Expected-id match flags.
- Unattributed event counts.
- Missing expected event flags.
- Observer event totals.

Resize-order fields should include, where available:
- Coarse `client_perf_plotly_resize` presence for the action/window.
- Resize elapsed time from runtime PERF.
- Resize active tab.
- Visible widget count.
- Resized count.
- Whether target output was visible and nonzero-sized when resize/relayout was observed.
- App-level message receipt, debounce fire, resize start/end, redraw start/end, and handler end only if probe-only evidence justifies app instrumentation.

## Step Ledger

| Step | Phase | Work | Status | Evidence / Files | Gate / Next Action |
|---|---|---|---|---|---|
| 1 | A | Create Branch H daughter plan | Complete | Added this file as a pause-safe source-of-truth plan. Initial validation passed: `git diff --check` clean and `get_errors` found no diagnostics. | Parent delegation complete. |
| 2 | A | Update parent plan delegation | Complete | Parent file `VP Clone/Code Review/2026-07-29_vp_performance_hotspot_recovery_plan.md` now marks Step 15 Branch H active, keeps Step 14 Branch G closed, and shifts deferred build/artifact/final rows to Steps 16-18. | Handoff validation complete; proceed to probe instrumentation when implementation resumes. |
| 3 | A | Validate plan handoff | Complete | `get_errors` found no diagnostics for parent and daughter plans; `git diff --check` produced no output for both files after parent delegation. | Begin Branch H probe-only timeline attribution. |
| 4 | B/C | Add action-scoped timeline probe fields | Complete (initial probe-only instrumentation) | Edited `VP Clone/System/Testing/vp_perf_probe_single_action_latency.R`. Added action-scoped browser timeline helpers, action reset, event attribution fields, output milestone marking, readiness/client echo marks, timeline columns in each action row, and a default-preserving `--scenario=canonical|tab_only|tab_only_revisit` switch for Branch H tab-only baselines. | Run tab-only Branch H baseline after worktree checks. |
| 5 | C | Validate probe parse and overhead | Complete (parse/diagnostics only; overhead not independently isolated) | Parse markers: `PARSE_OK_BRANCH_H_TIMELINE_HELPERS`, `PARSE_OK_BRANCH_H_TIMELINE_ROWS`, and `PARSE_OK_BRANCH_H_SCENARIO_SWITCH`. `get_errors` found no diagnostics for the probe. Branch H timing shape stayed consistent with Branch G, but no separate observer-overhead A/B was run. | Baseline evidence recorded in Step 6. |
| 6 | E | Run tab-only Branch H baseline | Complete | Ran `step15_branch_h_plotly_timeline_tab_baseline` with `--scenario=tab_only`, `warm_partition_disk`, runtime PERF on; `PASS=4`; output CSV and exact fallback runtime summary recorded in Branch H Baseline Evidence. Also ran `step15_branch_h_plotly_timeline_tab_revisit_baseline` with `--scenario=tab_only_revisit`; `PASS=8`. | Step 7 initial attribution complete; no product-code edit yet. |
| 7 | F | Attribute 10s window | Complete | Lightweight lifecycle probe `step15_branch_h_light_lifecycle_attribution_probe` passed 4/4 and populated `shiny:value`/`plotly_afterplot`. Resize-state probe `step15_branch_h_resize_state_attribution_probe` passed 4/4 and showed resize messages arrive late, while target outputs are still loading/no-SVG, and usually perform `resized_count=0`. Trend/Heatmap delay clusters at late Shiny/htmlwidget/afterplot/main-SVG/loading-clear. Map has first materialization near 10s but readiness near 12.8-14.6s. Current has early SVG/afterplot but late Shiny value/loading-clear/readiness. | Close Branch H attribution-only unless a narrowly scoped output-settling branch is requested. |
| 8 | G | Optional product-code experiment | Deferred | No safe product-code branch selected. A direct Plotly-node binding probe (`step15_branch_h_lifecycle_attribution_probe`) regressed to `PARTIAL=1|PASS=3` and was backed out before the successful lightweight run. Resize-state instrumentation found ordering evidence but not a safe optimization: resize cost is small, delivery is late, and targets usually have no ready SVG at handler time. Current evidence does not justify repeating rejected Branch G changes or broad hidden-output warming. | Proceed to Branch H closeout and parent recenter. |
| 9 | H | Closeout and parent recenter | Complete | Daughter Summary completed and parent Step 15 recentered with Branch H attribution-only outcome, labels, touched files, validation markers, and next recommendation. | Branch H closed. Next parent-plan target should be selected explicitly; no product-code performance branch accepted from Branch H. |

## Phase Plan

Phase A: Parent recenter and daughter handoff
- Create this daughter plan.
- Update the parent plan to delegate Branch H when implementation resumes.
- Validate markdown and diff hygiene before probe edits.

Phase B: Baseline framing
- Record Branch G evidence and rejected product-code experiments.
- Explicitly frame Branch H as attribution-first, not optimization-first.
- Preserve startup/artifact and display-month churn as deferred/secondary unless Branch H evidence changes priority.

Phase C: Probe timeline instrumentation
- Extend `vp_perf_probe_single_action_latency.R` with optional Branch H timeline fields or fork a sibling probe if safer.
- Add action-scoped reset, action id tagging, expected output id, target tab, and per-action relative timing marks.
- Add output-event attribution rules and missing/unattributed event counts.
- Add resize-order fields observable from probe-only JS and runtime logs.
- Add instrumentation-overhead guard.
- Parse-check before running Shiny probes.

Phase D: App-level instrumentation only if needed
- First attempt probe-only marks.
- Add app-level `forcePlotlyResize` internals only if probe-only evidence and existing coarse client PERF implicate resize/redraw ordering.
- If app instrumentation is added, route through existing `emitClientPerf()` and `log_client_perf()` plumbing and parse-check touched files.

Phase E: Branch H baseline run
- Run first baseline as tab-only diagnostic, not full Branch G canonical actions.
- Recommended label: `step15_branch_h_plotly_timeline_tab_baseline`.
- Include Current -> Historical Trend -> Heatmap -> Map -> Current.
- Add one optional tab-while-pending Historical Trend action if settled tab sequence is clean.
- Include first-visit versus revisit pass if cheap.
- Record cache state, output CSV, requested runtime path, exact fallback JSONLs, and summary CSVs.

Phase F: Attribution decision
- Attribute the 10s window using the decision gates below.
- Close attribution-only if no product branch is safe.

Phase G: Optional product-code experiment
- Make one small experiment only after attribution.
- Validate with a separate post label, exact runtime summaries, correctness checks, provider health, `get_errors`, and `git diff --check`.
- Revert failures before any second experiment.

Phase H: Closeout
- Complete this Summary.
- Update parent plan with Branch H outcome and next recommendation.

## Candidate Branches And Decision Gates

Branch H-0 attribution-only closeout:
- Default acceptable outcome.
- Select if the timeline identifies the controlling layer but no low-risk product edit is safe yet, or if the first tranche only proves a probe/readiness correction is needed.

Branch H-1 readiness-predicate/probe correction:
- Select if output nonzero size, widget insertion, `.main-svg`, `plotly_afterplot`, or visually usable state appears materially before Branch G `visible_ready_ms`.
- Acceptance requires a corrected probe/readiness definition and rerun, not an app-code performance claim.

Branch H-2 server render/data branch:
- Select only if relevant `log_perf()` plot buckets are near the 10s readiness delay and execution/cache counters show real render work.
- Candidate surfaces: `comparison_plot`, `timeseries_plot`, `heatmap_plot`, `map_plot`, summary/projection dependencies, filtered data dependencies, or plot trace construction.

Branch H-3 Shiny/htmlwidget output delivery branch:
- Select if server render finishes early but matching `shiny:value`, output DOM mutation, or widget insertion is late.
- Candidate surfaces may include Shiny output invalidation, hidden-tab output delivery, htmlwidget serialization/delivery, or output suspension behavior.
- Do not repeat broad hidden-output warming unless a much narrower output and timing gate is proven.

Branch H-4 Plotly materialization branch:
- Select if widget insertion is early but `.main-svg` or `plotly_afterplot` is late.
- Candidate future product options may include output simplification, trace reduction, deferred secondary plot features, or different Plotly lifecycle handling.

Branch H-5 resize/redraw sequencing branch:
- Select only if `forcePlotlyResize`, `Plotly.Plots.resize`, or `Plotly.redraw` timing/order explains the delay.
- Specific evidence could include resize firing while target output is hidden/zero-sized, repeated resize/redraw loops through the delay, or resize/redraw spanning a material portion of the 10s window.
- Do not simply remove `Plotly.redraw()`; Branch G rejected that.

Branch H-6 DOM/main-tabs observer branch:
- Select only if main-tabs mount/profile/mutation events continue through the delay and correlate with output readiness.
- Treat tabset architecture work as high blast-radius and late-stage.

Branch H-7 full-idle churn branch:
- Select only if tab Plotly readiness attribution is no longer the primary blocker or is already explained.
- Candidate residual surfaces include `summary_table`, year-filter sync, display-month mapping, `filtered_data`, type-choice churn, and provider/key-delta activity.

## Verification And Validation Targets

Plan validation:
- `get_errors` for this daughter plan.
- `git diff --check -- "VP Clone/Code Review/2026-07-30_vp_branch_h_plotly_materialization_attribution_plan.md"`.
- Direct trailing-whitespace scan for this daughter plan.

Probe parse:
- `C:\Program Files\R\R-4.5.1\bin\Rscript.exe -e "invisible(parse(file='VP Clone/System/Testing/vp_perf_probe_single_action_latency.R')); cat('PARSE_OK_BRANCH_H_SINGLE_ACTION_TIMELINE_PROBE\n')"`.

App-code parse if touched:
- Parse `VP Clone/Programs/app_source/ui.R` if client instrumentation is added.
- Parse `VP Clone/Programs/app_source/server/02_partner_and_notes.R` if client PERF server handling is added.
- Parse `VP Clone/Programs/app_source/server/04_comparison_plots.R` or `05_trend_and_heatmap.R` if plot-output code is touched.

Baseline run:
- Recommended label: `step15_branch_h_plotly_timeline_tab_baseline`.
- Runtime PERF enabled.
- Cache state explicit, normally `warm_partition_disk`.
- Record output CSV, requested runtime log path, exact fallback JSONLs, and summary CSVs.

Runtime summary:
- `VP Clone/System/Testing/vp_perf_summarize_runtime_logs.R --input=<exact_jsonl_1>|<exact_jsonl_2>`.
- Record timed, churn, key-delta, partition, memory, files, events, and client PERF outputs.

Correctness:
- Final source/trade-flow/hierarchy/commodity/country/metric/tab path matches target action.
- Output readiness corresponds to final selected state.
- No stale output accepted.
- Map remains nonempty/ready if Map output is touched or measured.

Provider health:
- No new direct-filter fallback.
- No source-signature mismatch.
- No source-identity/source-order refusal.
- Memory/disk cache modes remain healthy.

Instrumentation health:
- Timeline event counts recorded.
- Missing/unattributed event counts recorded.
- Timeline observer does not materially change the Branch G timing shape before product-code conclusions.

Worktree checks:
- `get_errors` for touched files.
- `git diff --check` for touched source/plan files.
- Generated artifact/log review.

## Bugs, Blockers, Failed Attempts, Rejected Approaches

Known action-correlation blocker:
- Cumulative observer counts are not enough. Branch H requires action-scoped reset, action id tagging, expected output id, target tab, and relative timestamps.

Known output-attribution blocker:
- Shiny, DOM, and Plotly events may not resolve cleanly to the intended output id. Record nearest id, expected-id match, and unattributed counts.

Known probe-overhead blocker:
- MutationObserver and frequent DOM polling can perturb timing. Keep observer work minimal and validate probe overhead.

Known readiness-predicate blocker:
- The existing Branch G predicate may lag visual usability. Branch H must record earlier visual milestones and be willing to repair the probe before app code.

Known resize-order blocker:
- `forcePlotlyResize` is sent immediately after tab input changes and debounced client-side. Resize before target output visibility may be premature rather than slow.

Known cache-interpretation blocker:
- Small server plot timers may reflect cache behavior. Large readiness delays still need execution/cache context before concluding the server is innocent.

Known first-visit blocker:
- Initial materialization of hidden Plotly widgets may differ from revisits. Branch H should separate first-visit and revisit timing where cheap.

Known missing-event blocker:
- Plotly events may fail to fire for a usable plot or may fire on nested nodes. Missing marks are evidence quality issues, not automatic app faults.

Known runtime-log blocker:
- Requested runtime log paths may not materialize. Exact fallback JSONLs and summarizer outputs are required.

Rejected from Branch H first response:
- Extending Branch G directly as product-code work.
- Startup/artifact pivot.
- Broad hidden-output warming.
- Removing `Plotly.redraw()`.
- Broad `bindCache()` wrappers.
- Tabset architecture rewrite.
- Display-month/year-filter/summary churn as first Branch H target.

## Tranche Execution Notes

- 2026-07-30 Tranche A draft handoff:
  - Created this daughter plan only.
  - Parent-plan delegation completed after initial daughter creation: parent Step 15 now points to this Branch H daughter plan, Branch G remains closed at Step 14, and deferred build/artifact/final rows shifted to Steps 16-18.
  - Probe-only timeline instrumentation started in `VP Clone/System/Testing/vp_perf_probe_single_action_latency.R`.
  - No product app code has been edited for Branch H.
  - Handoff validation completed after parent delegation: `get_errors` found no diagnostics for parent and daughter plans; `git diff --check` produced no output for both files.
  - Initial probe edit details:
    - Added action-scoped browser timeline state with reset per action, expected output id, target tab, event list, unattributed event count, and mismatched event count.
    - Added passive marks for `shiny:busy`, `shiny:idle`, `shiny:value`, tab shown/after-paint, output mutations, output visible/nonzero state, widget insertion, `.main-svg`, `plotly_afterplot`, `plotly_relayout`, loading-indicator clearance, readiness predicate pass, target accepted, and client echo ready.
    - Added `timeline_*` columns to each action row through `flatten_prefixed("timeline", timeline)`.
    - Added `--scenario=canonical|tab_only|tab_only_revisit`; default remains `canonical` for Branch G compatibility, while Branch H can run a narrow tab-only baseline.
  - Initial probe validation:
    - Parse marker after helper edit: `PARSE_OK_BRANCH_H_TIMELINE_HELPERS`.
    - Parse marker after action-row wiring: `PARSE_OK_BRANCH_H_TIMELINE_ROWS`.
    - Parse marker after scenario switch: `PARSE_OK_BRANCH_H_SCENARIO_SWITCH`.
    - `get_errors` found no diagnostics for the edited probe.
  - Current caveat: no Shiny baseline has been run yet, so instrumentation overhead and timeline event quality are unmeasured.
  - Next action after pause: run a Branch H tab-only baseline, preferably label `step15_branch_h_plotly_timeline_tab_baseline` with `--scenario=tab_only` first, then consider `--scenario=tab_only_revisit` if the first pass is clean.

- 2026-07-30 Tranche B tab-only and revisit baselines:
  - Ran Branch H first-pass tab baseline with label `step15_branch_h_plotly_timeline_tab_baseline`, scenario `tab_only`, cache state `warm_partition_disk`, runtime PERF enabled, `stage-timeout-ms=30000`, `startup-timeout-ms=120000`, `output-timeout-ms=20000`, and `full-idle-timeout-ms=30000`.
  - First-pass status: `PASS=4`; output CSV `VP Clone/Logs/vp_perf_probe_single_action_latency_step15_branch_h_plotly_timeline_tab_baseline_20260730T180048Z.csv`; exact fallback runtime input `VP Clone/Logs/vp_runtime_perf_1710ae04414dc3a4ccb1210895bdb0bd.jsonl|VP Clone/Logs/vp_runtime_perf_proc_20260730T180052Z_21124.jsonl`; runtime summary prefix `VP Clone/Logs/vp_perf_runtime_summary_step15_branch_h_plotly_timeline_tab_baseline_runtime_20260730T180343Z_*.csv`.
  - First-pass result: Historical Trend visible/client/idle `12384/12687/13197ms`; Heatmap `12277/12582/13108ms`; Map `14803/14839/15361ms`; Current vs. Average `9689/9760/10549ms`.
  - First-pass timeline: tab shown/paint and output mutation are early; Trend/Heatmap main SVG and loading-clear arrive near 12s; Map main SVG/loading-clear arrive around 11.1s but readiness waits until 14.8s; Current had widget/main SVG at action start but output visibility/loading-clear/readiness near 9.5-9.7s.
  - Ran optional revisit baseline with label `step15_branch_h_plotly_timeline_tab_revisit_baseline`, scenario `tab_only_revisit`, cache state `warm_partition_disk`, runtime PERF enabled, same timeout envelope.
  - Revisit status: `PASS=8`; output CSV `VP Clone/Logs/vp_perf_probe_single_action_latency_step15_branch_h_plotly_timeline_tab_revisit_baseline_20260730T180439Z.csv`; exact fallback runtime input `VP Clone/Logs/vp_runtime_perf_c03840c76b5bec3c6a62796931188dfb.jsonl|VP Clone/Logs/vp_runtime_perf_proc_20260730T180443Z_1572.jsonl`; runtime summary prefix `VP Clone/Logs/vp_perf_runtime_summary_step15_branch_h_plotly_timeline_tab_revisit_baseline_runtime_20260730T180825Z_*.csv`.
  - Revisit result: first-pass rows remain slow (`9361-13382ms` visible-ready), and repeated rows remain slow or worse (`11428-17916ms` visible-ready). This argues against a simple first materialization-only explanation.
  - Runtime interpretation: server plot buckets are not near the 10s delay in the summarized runtime logs. First-pass top plot/server rows include `timeseries_plot` about 0.119s, `map_plot` about 0.902s across 3 rows, and `observeEvent(main_tabs_panel)` about 0.054s total. Top timed rows are dominated by client tab events and startup buckets, while startup remains out of repeated-use scope.
  - Churn interpretation: display-month mapping cache hits, summary table execution, year-filter sync, and map-bottom-panel UI churn persist, but they remain secondary full-idle/background candidates until correlated with visible-ready delay.
  - Evidence-quality gap: all Branch H rows have blank `timeline_shiny_value_output_ms`, `timeline_plotly_afterplot_ms`, and `timeline_plotly_relayout_ms`, plus two unattributed and two mismatched events. Inspecting serialized timeline edges confirmed most output DOM marks are attributed to the expected output id, but Shiny/Plotly lifecycle event attribution still needs refinement.
  - Branch decision: no product-code edit selected. Next safe work is a small attribution-only refinement around `shiny:value`, Plotly afterplot/relayout capture, resize ordering, and loading-state transitions, followed by the same narrow tab baseline. Attribution-only closeout is acceptable if that refinement still does not identify a low-risk app branch.

- 2026-07-30 Tranche C lightweight lifecycle attribution refinement:
  - Edited `VP Clone/System/Testing/vp_perf_probe_single_action_latency.R` only; app product code remains untouched.
  - First attempted direct Plotly-node lifecycle binding inside the probe. Label `step15_branch_h_lifecycle_attribution_probe` produced `PARTIAL=1|PASS=3`, with Map visible-ready timeout and 15-18s visible-ready for the passing rows. This probe-side approach was rejected as too perturbing and backed out.
  - Kept the lower-overhead parts: Shiny event metadata attribution, document/jQuery `shiny:value` capture, and document/jQuery Plotly lifecycle capture without binding handlers directly onto every discovered Plotly node.
  - Validation after repair: parse marker `PARSE_OK_BRANCH_H_LIGHT_LIFECYCLE_OBSERVERS`; `get_errors` found no diagnostics for the edited probe.
  - Successful run label `step15_branch_h_light_lifecycle_attribution_probe`, scenario `tab_only`, cache state `warm_partition_disk`, runtime PERF enabled, status `PASS=4`.
  - Successful output CSV `VP Clone/Logs/vp_perf_probe_single_action_latency_step15_branch_h_light_lifecycle_attribution_probe_20260730T181801Z.csv`; exact fallback runtime input `VP Clone/Logs/vp_runtime_perf_5fc822e9572d4091ec7151a3728d62ab.jsonl|VP Clone/Logs/vp_runtime_perf_proc_20260730T181805Z_25576.jsonl`; runtime summary prefix `VP Clone/Logs/vp_perf_runtime_summary_step15_branch_h_light_lifecycle_attribution_probe_runtime_20260730T182053Z_*.csv`.
  - Successful result: Historical Trend visible/client/idle `11116/11165/11674ms`; Heatmap `11165/11191/11712ms`; Map `14584/14884/15399ms`; Current vs. Average `8981/9306/9822ms`.
  - Successful lifecycle marks: Trend `shiny:value=10912ms`, `afterplot=10983ms`, `main_svg=10983ms`, `loading_clear=10983ms`; Heatmap `10883/10973/10972/10972ms`; Map `10946/11185/11021/10948ms` but readiness `14578ms`; Current `shiny:value=8783ms`, `afterplot=99ms`, `main_svg=0ms`, `loading_clear=8792ms`.
  - Branch decision after Tranche C: no product-code edit yet. The controlling layer is narrower: Trend/Heatmap are late Shiny/htmlwidget/Plotly materialization; Map and Current require resize/loading-state/output-settling attribution after initial SVG/afterplot evidence.

- 2026-07-30 Tranche D resize-state attribution:
  - Edited `VP Clone/Programs/app_source/ui.R` to add target output state fields to existing client PERF resize payloads. The edit records target output id, presence, visibility, dimensions, widget count, main SVG count, and loading-indicator count before resize, after resize, and after paint. Resize/redraw behavior was not changed.
  - Parse validation after UI edit: `PARSE_OK_BRANCH_H_RESIZE_STATE_UI`.
  - Ran `step15_branch_h_resize_state_attribution_probe`, scenario `tab_only`, cache state `warm_partition_disk`, runtime PERF enabled, status `PASS=4`.
  - Output CSV `VP Clone/Logs/vp_perf_probe_single_action_latency_step15_branch_h_resize_state_attribution_probe_20260730T182222Z.csv`; exact fallback runtime input `VP Clone/Logs/vp_runtime_perf_2f90e5d9c28996da7161742f81c37950.jsonl|VP Clone/Logs/vp_runtime_perf_proc_20260730T182226Z_38920.jsonl`; runtime summary prefix `VP Clone/Logs/vp_perf_runtime_summary_step15_branch_h_resize_state_attribution_probe_runtime_20260730T182503Z_*.csv`.
  - Successful result: Historical Trend visible/client/idle `10878/11182/11705ms`; Heatmap `8394/8421/8941ms`; Map `12843/13138/13660ms`; Current vs. Average `8640/9200/9721ms`.
  - Resize payload finding: for Historical Trend, Heatmap, Map, and the first Current resize event, target outputs were present and visible with one widget, but `target_main_svg_count_before=0`, `target_loading_indicator_count_before=2`, and `resized_count=0`; after resize/paint the target state was unchanged. A later Current row had `main_svg_count=3` and `resized_count=1` while target visibility was false and loading indicators remained.
  - Branch decision after Tranche D: close Branch H attribution-only unless the user wants a separate product branch. Resize ordering is implicated as out-of-phase, but not as an obvious low-risk fix for the main delay. Stronger evidence points to late Shiny/htmlwidget/Plotly delivery for Trend/Heatmap and post-materialization output-settling/readiness for Map/Current.

## Summary

Branch H was a measurement branch for the slow tab switches that Branch G exposed. The goal was to find out what happens during the roughly 9-15 second wait between clicking a tab and having the Plotly/htmlwidget output truly ready, before trying another optimization.

The main finding is that the tab shell itself is not the bottleneck. Tab shown/paint events happen quickly, and the widget roots often exist almost immediately. The long wait is later: for Historical Trend and Heatmap, Shiny value delivery, Plotly afterplot, main SVG creation, loading-clear, and readiness all cluster in the late window. For Map, the first Shiny/Plotly materialization appears earlier, around 10-11s, but the readiness predicate does not pass until several seconds later. For Current vs. Average, an SVG/afterplot can already exist early, but Shiny value/loading-clear/readiness still arrive late.

Resize/redraw ordering is out of phase but not a proven low-risk fix. The existing resize custom message often reaches the browser late in the action window, while the target output is still loading and has no main SVG, and the handler usually records `resized_count=0`. The handler cost itself is small, so simply changing or removing resize/redraw is not justified by this evidence. Branch G already showed that removing `Plotly.redraw()` worsened readiness.

No product-code performance optimization was accepted in Branch H. The accepted source changes are measurement-only: the single-action probe now has action-scoped timeline/lifecycle fields and `ui.R` reports extra target-output state in existing resize PERF payloads. A direct Plotly-node binding attempt inside the probe was rejected because it perturbed timing and produced a partial run.

Validation passed for the closed branch: the final probe and UI files parse cleanly, `get_errors` reports no diagnostics for the touched Branch H files, `git diff --check` is clean, and the final resize-state tab-only probe passed 4/4. The next recommended direction is attribution-only closeout unless a separate product branch is explicitly chosen. If continuing product work, the strongest candidates are narrower output-settling investigation for Map/Current or a deeper Shiny/htmlwidget delivery path for Trend/Heatmap, not startup, broad hidden-output warming, or generic Plotly redraw removal.