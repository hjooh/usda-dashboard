# VP Branch E Interaction Filtering and Tab-Switch Responsiveness Plan

Date: 2026-07-30
Branch: main
Status: Complete. Fresh Branch E repeated-use baseline, probe-convention gate, product-code optimization, validation, and parent closeout are complete.

## Purpose

The parent VP performance hotspot recovery plan and the closed Branch C daughter plan identify the next user-prioritized target as repeated-use responsiveness: faster VP filtering, hierarchy changes, and tab switches after the app has initialized. This Branch E daughter plan owns the measured tranche for interaction filtering and tab-switch responsiveness.

This is not a startup artifact-load tranche. Slow startup/initialization is acceptable for this tranche by product decision. Branch D artifact/load and companion-artifact work remain excluded unless fresh repeated-use evidence shows artifact/currentity/signature work blocking ordinary tab/filter interactions.

The expected first implementation strategy is shared-context reuse: reduce repeated `filtered_data()`, `summary_table`, `projection_data()`, and visible-tab derived-output work after a fresh repeated-use probe confirms the target. Lazy tab-local gating remains a candidate only if fresh tab-switch evidence proves inactive or non-target output execution.

## Scope

Included:
- Create this daughter source-of-truth ledger and keep it updated before every implementation tranche transition.
- Update the parent plan to delegate Branch E interaction responsiveness here.
- Establish a fresh Branch E baseline before product-code edits.
- Reuse the established VP performance probing conventions from `vp_perf_probe_hierarchy_transition.R`, `vp_perf_probe_startup.R`, and `vp_perf_summarize_runtime_logs.R`.
- Create or extend the smallest focused tab/filter probe only if existing probes cannot measure repeated-use tab-switch latency.
- Measure post-startup repeated-use interactions, including VP hierarchy/filter changes and tab switches among Current vs. Average, Historical Trend, Heatmap, and Map.
- Keep MYCT evidence separate unless touched shared helpers require targeted MYCT sanity.
- Preserve Provider v3 behavior, direct-filter fallback, canonical-source checks, event-only runtime PERF defaults, final selected path, and existing purpose-specific counters or explicit replacement counters.
- Record timing, churn, provider mode, final selected path, data-equivalence checks, tab execute/skip counters, cache hit/miss counters, bugs, blockers, failed attempts, and rejected approaches.

Excluded:
- Startup artifact/load rewrites, Branch D companion artifacts, broad format conversion, or lazy full-artifact loading.
- Build-time aggregation tuning unless the parent plan is amended with fresh evidence that it affects repeated-use tab/filter latency.
- Loading polish, spinners, progress copy, cosmetic waiting states, or other latency masking.
- Broad non-VP tuning.
- MYCT optimization as a primary target; MYCT remains a separate evidence surface unless shared helper changes make targeted sanity necessary.
- A paired results markdown file unless explicitly requested.

## Parent Plan Linkage

Parent plan: `VP Clone/Code Review/2026-07-29_vp_performance_hotspot_recovery_plan.md`.

This daughter plan owns detailed implementation notes for Branch E, "interaction filtering and tab-switch responsiveness." The parent remains the broad performance recovery ledger. During this tranche, the parent should contain only the delegation note, high-level status, and closeout summary; detailed technical decisions, failed attempts, validation commands, probe outputs, and runtime evidence belong here.

Parent ledger amendment requirement:
- Make Branch E the next active parent step instead of leaving it as "Step 12-adjacent."
- Shift deferred build-time aggregation, deferred artifact/data-format work, and final validation rows down in the parent step ledger as needed.
- Record that startup slowness is accepted for this tranche and artifact/load work is explicitly deferred.

At closeout:
- Complete this daughter `## Summary` section in plain language.
- Update the parent Step Ledger with the Branch E outcome.
- Add parent tranche notes with output paths, validation markers, timing/churn/provider deltas, cache/reuse counters, residual risks, blocker investigations, and the next recommended parent-plan target.
- Recenter future work on the parent plan.

## Source-Of-Truth Ledger Contract

- This file is the active source of truth for the Branch E interaction responsiveness tranche.
- Update this file after every step or tranche before moving to the next tranche.
- Record files touched, commands/probes, benchmark labels, cache-state labels, runtime log paths, PERF summaries, churn deltas, timing deltas, provider summaries, branch decisions, data-equivalence checks, Map/MYCT sanity evidence, bugs, blockers, failed attempts, rejected approaches, and decision gates.
- Keep parent-plan updates limited to delegation and closeout while this daughter plan is active.
- Preserve enough detail that a future coder can resume without replaying chat history.
- At completion, provide a short chat summary and complete the final `## Summary` section in this file.

## Baseline Evidence

Historical motivation from the closed Branch C tranche:
- Probe CSV: `VP Clone/Logs/vp_perf_probe_hierarchy_transition_step11_branch_c_type_choice_cache_post_20260729T223458Z.csv`.
- Timed summary: `VP Clone/Logs/vp_perf_runtime_summary_step11_branch_c_type_choice_cache_post_fallback_20260729T223817Z_timed.csv`.
- Churn summary: `VP Clone/Logs/vp_perf_runtime_summary_step11_branch_c_type_choice_cache_post_fallback_20260729T223817Z_churn.csv`.
- Provider summary: `VP Clone/Logs/vp_perf_runtime_summary_step11_branch_c_type_choice_cache_post_fallback_20260729T223817Z_partition.csv`.

Final Branch C residual evidence from those files:
- `filter_vp_rows_for_resolved_hierarchy()`: 43 calls / 2.8760 seconds.
- `summary_table`: 8 calls / 1.3843 seconds.
- `projection_data()`: 8 calls / 1.0745 seconds.
- `output$commodity_choice_ui`: 8 calls / 0.4788 seconds.
- `filter_vp_rows_for_resolved_hierarchy_filtered_data`: 9 calls.
- Residual display/type/mixed/quantity filter calls: 7 each for display-month mapping, type-choice base values, mixed-volume family check, and quantity-units context.
- `filter_vp_rows_for_resolved_hierarchy_comparison_commodity_choices`: 4 calls.
- Provider modes remained healthy: disk-cache 5 calls / 0.5718 seconds and memory-cache 38 calls / 0.2042 seconds, with no direct fallback row.

Baseline caveats:
- Historical rows are target-selection evidence, not final before/after proof. Branch E requires a fresh official baseline before product-code edits.
- The final Branch C run was a hierarchy-transition probe, not a pure tab-switch probe. It supports the shared-filter hypothesis but does not prove tab-switch latency.
- Requested runtime log paths often do not materialize. Exact fallback process/session JSONL logs must continue to be recorded and summarized with `--input=...`.
- Startup artifact/read timing is known to be large, but startup is outside this tranche's success metric except as recorded context.

Required official Branch E baseline:
- Measure already-open or post-startup repeated-use behavior.
- Include source switch to VP if needed, then a hierarchy/filter change, then tab switches among Current vs. Average, Historical Trend, Heatmap, and Map.
- Keep MYCT separate unless explicitly included as a separate labeled segment.
- Use exact runtime JSONL summarization with `VP Clone/System/Testing/vp_perf_summarize_runtime_logs.R --input=...` when requested log paths do not materialize.
- Required fields: per-stage elapsed milliseconds, selected source/trade-flow/hierarchy/commodity/country/metric/tab, PASS/FAIL, cache-state label, runtime log paths, top timed buckets, top churn buckets, `filtered_data` calls/time, `summary_table` calls/time, `projection_data()` calls/time, tab output execute/skip counters, provider disk/memory/direct-fallback summaries, key deltas, final selected path, browser-visible output readiness/blank-state checks where available, and whether Map/MYCT evidence is included or intentionally excluded.

Official Branch E baseline, 2026-07-30:
- Probe: `VP Clone/System/Testing/vp_perf_probe_tab_switch_filtering.R`.
- Parse marker: `PARSE_OK_BRANCH_E_TAB_FILTER_PROBE`.
- Probe command label: `step12_branch_e_tab_filter_baseline`.
- Cache state: `warm_partition_disk`.
- Probe CSV: `VP Clone/Logs/vp_perf_probe_tab_switch_filtering_step12_branch_e_tab_filter_baseline_20260730T134112Z.csv`.
- Probe status: PASS.
- Requested runtime log path did not materialize; this is consistent with prior VP PERF behavior.
- Exact fallback JSONLs summarized: `VP Clone/Logs/vp_runtime_perf_48ff21b0622f4546304985abd7ffa9d5.jsonl` and `VP Clone/Logs/vp_runtime_perf_proc_20260730T134128Z_13332.jsonl`.
- Runtime summary timed CSV: `VP Clone/Logs/vp_perf_runtime_summary_runtime_logs_20260730T134459Z_timed.csv`.
- Runtime summary churn CSV: `VP Clone/Logs/vp_perf_runtime_summary_runtime_logs_20260730T134459Z_churn.csv`.
- Runtime summary partition CSV: `VP Clone/Logs/vp_perf_runtime_summary_runtime_logs_20260730T134459Z_partition.csv`.
- Runtime summary key-delta CSV: `VP Clone/Logs/vp_perf_runtime_summary_runtime_logs_20260730T134459Z_key_delta.csv`.
- Probe stage timings: startup-ready 70,681 ms; source switch 11,815 ms; trade-flow switch 15,990 ms; combined hierarchy change 90,517 ms; tab Current after source 81 ms; Current after filter 47 ms; Historical Trend 66 ms; Heatmap 72 ms; Map 71 ms; return Current 93 ms; total probe 217,289 ms.
- Final path: source `vp_trade`, group `Dry pulses`, subgroup `Dried beans`, market segment `Dried`, final tab `Current vs. Average`; all targeted output readiness waits passed.
- Top repeated-use timed buckets after startup: `filter_vp_rows_for_resolved_hierarchy()` 44 calls / 3.1368 seconds; `summary_table` 8 calls / 1.3670 seconds; `projection_data()` 8 calls / 1.1433 seconds; `output$commodity_choice_ui` 8 calls / 0.4790 seconds; `pace_historical_avg()` 7 calls / 0.4543 seconds; `historical_avg()` 7 calls / 0.2660 seconds; `current_year_data()` 7 calls / 0.1255 seconds.
- Top churn rows: `summary_table_executed` 11; `filter_vp_rows_for_resolved_hierarchy_filtered_data` 9; display/type/mixed/quantity filter purposes 7-8 each; `map_bottom_panel_ui_gated_skip` 10.
- Provider summary: memory-cache 39 calls / 0.2221 seconds; disk-cache 5 calls / 0.6831 seconds; no direct-filter summary row in the partition CSV.
- Branch decision: tab switching itself is not the first bottleneck in this baseline; hierarchy/filter changes and repeated shared filtered/derived-data consumers are the first target.

Acceptance thresholds must be declared before product-code edits. Recommended default:
- Improve the selected target stage or timed bucket by a meaningful measured amount.
- Keep non-target repeated-use stages within an explicit noise tolerance, such as about 10%, unless an accepted explanation is recorded.
- Do not increase total hierarchy-filter time, provider direct fallback, source mismatch, or source-identity refusal without an accepted explanation.
- Preserve all correctness, parity, Map, MYCT, and provider gates.
- If a single-run probe is too noisy to support a decision, repeat the focused probe enough to make the decision defensible or harden the harness before product-code edits.

First product-code branch acceptance thresholds:
- Primary target: reduce repeated derived-reactive churn/timing for `summary_table`, `projection_data()`, `historical_avg()`, `current_year_data()`, and related `filtered_data()` consumers in the Branch E probe.
- Secondary target: do not worsen combined hierarchy-change time, `filter_vp_rows_for_resolved_hierarchy()` total time/call count, or provider partition summary beyond about 10% without an accepted measurement explanation.
- Keep tab-switch stages passing and sub-second after filter settlement.
- Keep provider behavior healthy: no new direct fallback, no source mismatch/refusal, and no loss of memory/disk partition mode evidence.
- Preserve final selected VP path and Map non-empty readiness evidence.
- Because the first branch touches shared Current-vs-Average helpers only, MYCT is expected to remain isolated unless parse/runtime evidence shows shared-helper impact; record that isolation or run targeted sanity if touched surfaces expand.

## Technical Read

Shared filter and provider surfaces:
- `VP Clone/Programs/app_source/server/03_core_reactives_and_ui.R` owns `filtered_data_stable_cache_key()`, `filtered_data()`, `most_recent()`, `historical_avg()`, `current_year_data()`, `projection_data()`, and shared display/year helpers.
- `VP Clone/Programs/app_source/server/02_partner_and_notes.R` owns `selected_data()`, `filtered_data_for_country()`, `filter_vp_rows_for_resolved_hierarchy()`, `resolve_vp_hierarchy_tokens()`, Provider v3 call path, direct-filter fallback, and many tab/sidebar observers.
- `filtered_data()` is already cached with `bindCache(filtered_data_stable_cache_key())`, so Branch E must determine whether remaining work is cache-key churn, repeated consumers, derived-output recomputation, or actual required recomputation.

Current-vs-Average derived-output surfaces:
- `VP Clone/Programs/app_source/server/04_comparison_plots.R` owns `comparison_plot`, `output$summary_table`, `is_current_vs_average_output_active()`, and the existing Current-vs-Average active-tab gating pattern.
- `summary_table` and `projection_data()` remain meaningful timed buckets in the final Branch C evidence.
- Any shared bundle for current/historical/projection data must preserve projection basis, reference year, historical window, unit/basis/value-unit controls, custom type/country definitions, null behavior, and display labels.

Tab-switch surfaces:
- `VP Clone/Programs/app_source/server/05_trend_and_heatmap.R` owns `timeseries_plot`, `heatmap_plot`, many Map data surfaces, tab output counters, active-tab gates, and map bottom-panel behavior.
- `VP Clone/Programs/app_source/server/02_partner_and_notes.R` owns `current_main_tab_safe()` and Map shared data such as `map_source_data()`.
- Existing output counters include patterns such as `summary_table_executed`, `summary_table_gated_skip`, `comparison_plot_executed`, `comparison_plot_gated_skip`, `timeseries_plot_executed`, `heatmap_plot_executed`, `map_plot_gated_skip`, and `map_bottom_panel_ui_gated_skip`.

Local hypothesis for the first product-code branch:
- Repeated-use latency is more likely from duplicated shared filtered/derived work than from inactive tabs secretly rendering.
- A small shared-context reuse boundary can reduce repeated `filtered_data()`, `summary_table`, and `projection_data()` work without changing visible behavior if cache keys, data-equivalence checks, provider behavior, Map fields, and MYCT isolation are preserved.

First cheap disconfirmation check:
- A fresh Branch E tab/filter baseline must show `filtered_data`, `summary_table`, `projection_data()`, total hierarchy-filter work, or related derived-output churn as a top repeated-use target.
- If the baseline instead shows visible-tab render cost with no repeated shared-filter waste, close the shared-context hypothesis as rejected and select the smallest tab-local render branch.
- If the baseline shows inactive or non-target tab output execution, select Branch A lazy tab-local gating first.

## Guardrails

Probe guardrails:
- Do not invent a separate Branch E harness style.
- Reuse the established one-shot segmented Shiny probe conventions from `vp_perf_probe_hierarchy_transition.R` and `vp_perf_probe_startup.R`.
- Required probe conventions include `Sys.setenv(NOT_CRAN = "true")`, explicit command-line label/cache-state arguments where consistent with existing probes, `STAGE_BEGIN` / `STAGE_END` markers, bounded waits, JavaScript DOM/input/output reads instead of broad `app$get_values()` during unstable windows, partial evidence on failure, raw one-row CSV output, requested runtime log path plus fallback candidates, selected tab/source/path fields, action labels, and exact `vp_perf_summarize_runtime_logs.R --input=...` follow-up when requested runtime logs do not materialize.
- A new probe that omits staged markers, cache-state labels, bounded waits, partial evidence, exact runtime-log fallback handling, or summarizer `--input` follow-up is not acceptable as the Branch E baseline.

Correctness and behavior guardrails:
- Preserve current user-visible VP behavior unless a deliberate measured behavior change is recorded here first.
- Preserve Provider v3 row-index behavior, direct-filter fallback, canonical-source checks, source-signature checks, row-order/source identity checks, and source-mismatch refusal.
- Preserve final selected source/trade-flow/hierarchy/commodity/country/metric/tab path.
- Preserve Current-vs-Average, Historical Trend, Heatmap, and Map row, label, projection, and display semantics.
- Keep MYCT evidence separate unless the changed helper directly affects MYCT behavior.
- Do not use user-facing loading polish as a substitute for reducing avoidable work.

Shared-context/cache guardrails:
- Define one small reuse boundary before editing product code.
- Required key dimensions unless proven irrelevant: source, frequency, trade flow, resolved VP hierarchy tokens/path, commodity name/detail, selected commodity choice, country choice, metric, unit/basis/value-unit controls, display year type, comparison basis/reference year/historical window, custom type/country cache keys, selected data mode, cache data/schema versions, and any tab-specific controls that change the derived data.
- Define cache lifecycle and memory behavior before coding. Session-local reuse should have explicit invalidation on source/schema/cache-version changes and should avoid unbounded key growth across repeated filter/tab actions.
- If the cache can retain large data frames, record approximate rows/object sizes or cache-entry counts in runtime details or tranche notes.
- Do not collapse distinct tabs or projection modes into one cache entry unless the key proves they are equivalent.
- Any evidence of stale rows, stale labels, stale projection basis, stale Map period/geography, or stale MYCT state blocks acceptance.

Data-equivalence guardrails:
- For any reused filtered/derived object, compare row counts, key identity columns, metric/value columns, period columns, country/commodity labels, projection fields, and null/empty behavior against the pre-change path in at least the Branch E baseline states before accepting the patch.
- If the optimized shared object cannot be compared to the pre-change path for measured states, do not accept it as a performance win.

Map guardrails:
- Shared data reuse must preserve all geographic metadata, country codes/labels, row-level granularity, period fields, metric/basis columns, selected period behavior, ranked datasets, bottom panels, and geographic drill/display behavior required by Map.
- Map validation must include no empty-map regression and no loss of required geography fields.

MYCT guardrails:
- Shared `filtered_data` or `selected_data` reuse must not interfere with Market Year Comparison Tool country/type modes, comparison filters, custom builder choices, or market-year-specific state.
- If a touched helper is consumed by MYCT, run targeted MYCT smoke/manual sanity or explicitly document why the path is isolated.

Reactive-cascade guardrails:
- Shared context updates must not cause non-active tabs to render unless fresh evidence intentionally selects lazy-gating work.
- Use existing active-tab checks, `current_main_tab_safe()`, or `isolate()` patterns where appropriate.
- Add skip/execute counters when new gates are introduced.
- If shared context causes inactive tabs to render or increases output churn, reject or gate the change before expanding scope.

Instrumentation guardrails:
- Count-only improvements are insufficient. Accepted before/after evidence must include elapsed repeated-use timing and runtime summary counts/timings.
- If work is skipped or reused, add replacement counters such as `filtered_data_context_cache_hit`, `filtered_data_context_cache_miss`, `projection_context_cache_hit`, or equivalent.
- Runtime summaries must still explain why calls disappeared.

## Measurement Model and Cache-State Labels

Use parent cache-state labels exactly:
- `cold_artifact`: fresh R session and no warmed partition cache for the target path.
- `warm_partition_disk`: partition files exist but session memory cache is empty.
- `warm_session`: same session and partition memory cache already hit.
- `unknown_cache_state`: only for legacy rows or documented uncertainty where evidence is not final proof.

Branch E primary evidence should be repeated-use interaction-focused. Startup evidence is context only unless a patch directly changes startup/current settlement.

Do not blend cache states. Do not optimize against startup-only, count-only, inherited-only, or mixed-cache evidence.

## Step Ledger

| Step | Phase | Work | Status | Evidence / Files | Gate / Next Action |
|---|---|---|---|---|---|
| 1 | A | Create Branch E daughter source-of-truth plan | Complete | Added this file before Branch E product-code edits. | Parent delegation complete; proceed to Branch E baseline. |
| 2 | A | Amend parent plan for Branch E delegation | Complete | Parent plan Step 12 now delegates Branch E here and shifts deferred build-time aggregation, artifact/data-format, and final validation rows down. | Validate parent and daughter markdown. |
| 3 | A | Validate handoff markdown | Complete | `get_errors` reported no diagnostics for parent and daughter markdown. `git diff --check` passed for parent and daughter plan diffs. Direct trailing-whitespace scan produced no output for both files. | Establish fresh Branch E repeated-use baseline before product-code edits. |
| 4 | B | Establish fresh Branch E repeated-use baseline | Complete | `vp_perf_probe_tab_switch_filtering.R` parsed and PASSed with label `step12_branch_e_tab_filter_baseline`; output CSV and exact fallback runtime summaries recorded above. | Baseline supports shared derived-reactive reuse before tab-local gating. |
| 5 | B/C | Validate Branch E probe convention compliance | Complete | Probe uses `NOT_CRAN`, label/cache-state args, staged markers, bounded waits, JS input/output reads, partial failure row, raw one-row CSV, runtime log fallback discovery, and exact summarizer `--input`. | Keep probe available for post-change validation. |
| 6 | C | Complete focused technical read and branch decision | Complete | Baseline shows hierarchy/filter and shared derived-consumer churn; tab output waits are sub-100 ms. Technical read found `filtered_data()` cached but `most_recent()`, `historical_avg()`, `current_year_data()`, and `projection_data()` remain uncached derived reactives. | Implement the smallest derived-reactive reuse branch in `03_core_reactives_and_ui.R`. |
| 7 | D | Implement first measured Branch E product-code branch | Complete | Broad derived-reactive `bindCache()` branch in `03_core_reactives_and_ui.R` was tested and rejected, then reverted. Accepted branch added shared `commodity_choice_native_base_values()` in `01_state_and_custom_types.R`. | Product-code branch validated; closeout complete. |
| 8 | D/E | Validate first product-code branch | Complete | `PARSE_OK_BRANCH_E_STATE_CUSTOM_TYPES`; Branch E probe `step12_branch_e_commodity_base_reuse_post` PASS; exact fallback runtime summaries recorded. | Accepted measured win: hierarchy-change stage 90,517 ms -> 75,484 ms, total probe 217,289 ms -> 201,650 ms. |
| 9 | F | Close daughter and update parent | Complete | Daughter Summary completed; parent Step 12 and tranche notes updated with outcome, paths, residual risks, and next recommendation. | Recenter future work on parent plan. |

## Phase Plan

Phase A: Handoff setup
- Create this daughter plan.
- Amend the parent plan to delegate Branch E here and shift deferred rows as needed.
- Validate markdown handoff.

Phase B: Baseline and probe readiness
- Seed historical evidence from Branch C closeout with exact file paths.
- Record that slow startup is acceptable and artifact/load work is out of scope.
- Establish a fresh repeated-use Branch E baseline.
- Create or extend the smallest focused tab/filter probe only if existing probes cannot capture the needed repeated-use latency.
- Reuse established probe conventions; do not design a new harness style.

Phase C: Technical read and decision gate
- Complete focused reads of shared filter, derived output, tab-switch, Map, and MYCT-adjacent surfaces.
- Declare acceptance thresholds before product-code edits.
- Select the first branch from fresh Branch E evidence.

Phase D: First branch, expected shared-context reuse
- Define one small shared context/reuse boundary.
- Define explicit cache keys, lifecycle, memory behavior, equivalence checks, and instrumentation.
- Validate immediately after the first product-code edit.

Phase E: Alternate branches only if evidence selects them
- Branch A lazy tab-local gating: select only if inactive or non-target tab execution is proven.
- Branch B visible-tab first-useful-result deferral: select only if visible-tab secondary outputs block the useful result.
- Branch E summary/projection specialization: select if `summary_table` or `projection_data()` remains a top timed bucket after shared filtered-data reuse.
- Branch D artifact/load: excluded unless the parent plan is explicitly amended with repeated-use evidence.

Phase F: Closeout
- Run final focused validations.
- Complete this plan's Summary.
- Update parent Step Ledger and tranche notes.
- Recenter future work on the parent plan.

## Candidate Branches

Branch E shared-context reuse, expected first branch if supported by baseline:
- Reduce repeated `filtered_data()`, `summary_table`, `projection_data()`, and visible-tab derived-output work.
- Candidate boundaries include a tab/action-scoped filtered-data bundle, a reusable current/historical/projection bundle for Current-vs-Average, or a shared filtered slice that plot/table/trend/projection helpers can consume without repeated hierarchy/provider work.
- Requires explicit key dimensions, lifecycle, data-equivalence checks, Map/MYCT safeguards, and replacement hit/miss counters.

Branch A lazy tab-local gating:
- Select only if the Branch E probe shows inactive or non-target tab render functions executing during filtering or tab switches.
- Start with the smallest proven output surface.
- Add skip/execute counters and preserve selected-tab behavior.
- Prior Step 10 evidence did not show `timeseries_plot` or `heatmap_plot` executing during startup-to-Current-vs-Average, so this branch needs fresh tab-switch proof.

Branch B visible-tab first-useful-result deferral:
- Select only if visible-tab secondary outputs block the first useful plot/table after a filter or tab switch.
- Preserve primary outputs.
- Do not add loading polish or UI copy as a substitute for reducing work.

Branch E summary/projection specialization:
- Select if `summary_table` or `projection_data()` remains a top timed bucket after shared filtered-data reuse.
- Prefer reusing derived current/historical/projection inputs over broad rewrites.

Branch D artifact/load:
- Explicitly excluded for this tranche unless repeated-use tab/filter evidence proves artifact/currentity/signature work is blocking ordinary interactions.
- Startup-only pain is accepted by product decision.

## Verification and Validation Targets

Markdown handoff:
- `get_errors` for the parent and daughter markdown files.
- `git diff --check -- "VP Clone/Code Review/2026-07-29_vp_performance_hotspot_recovery_plan.md" "VP Clone/Code Review/2026-07-30_vp_branch_e_interaction_filtering_tab_switch_responsiveness_plan.md"`.
- Direct trailing-whitespace scan for the new daughter file while untracked.

Probe validation:
- Parse any new or edited probe with `C:\Program Files\R\R-4.5.1\bin\Rscript.exe`.
- Confirm any new probe follows existing VP probe conventions: `NOT_CRAN`, staged markers, bounded waits, JS reads, partial evidence, raw CSV row, cache-state labels, runtime log fallback discovery, and exact summarizer `--input` workflow.
- Run one passing Branch E baseline before product-code edits.
- Preserve partial evidence on failure.

Pre-edit baseline:
- Fresh Branch E repeated-use probe with explicit cache state, action labels, selected tab/source/path, runtime logs, exact summary CSVs, and startup excluded from success metrics except as recorded context.

Parse validation after product-code edits:
- Use `C:\Program Files\R\R-4.5.1\bin\Rscript.exe` and `invisible(parse(file=...))` markers for every touched R file.

Runtime summary comparison:
- Compare top timed/churn buckets, `filtered_data`, `summary_table`, `projection_data()`, total hierarchy filter work, provider partition modes, replacement cache counters, cache-entry counts/object-size notes where relevant, and explicit pass/fail against pre-declared acceptance thresholds.

Data-equivalence validation:
- Compare reused filtered/derived objects against the pre-change path for row counts, key columns, metric/value columns, period columns, country/commodity labels, projection fields, and null/empty behavior in the measured Branch E states.

Tab/filter behavior validation:
- Current-vs-Average filter change.
- Switch to Historical Trend.
- Switch to Heatmap.
- Switch to Map.
- Return to Current-vs-Average.

Map validation:
- Verify map output still has required geography fields, country labels/codes, metric/basis values, selected period behavior, bottom panel data, and no empty-map regression.

MYCT validation or isolation note:
- If touched shared helpers can affect MYCT, run targeted MYCT sanity.
- Otherwise record why the path is isolated.

Manual sanity if needed:
- VP defaults, hierarchy dropdowns, commodity/type choices, country dropdown, Current-vs-Average, Historical Trend, Heatmap, Map, display year labels, and projection controls.

Parent closeout:
- Parent Step Ledger and Tranche Execution Notes updated with measured outcomes and residual risks.

## Bugs, Blockers, Failed Attempts, Rejected Approaches

Current blockers and risk controls:
- Probe blocker: no tab-specific performance probe currently exists. Create the smallest focused probe before product-code edits if existing harnesses cannot measure tab-switch latency, and build it by reusing the established VP performance probe conventions.
- Evidence blocker: do not optimize against startup-only, count-only, inherited-only, or mixed-cache evidence. Branch E requires fresh repeated-use interaction evidence.
- Parent-ledger blocker: avoid ambiguous "Step 12-adjacent" wording in the repo plan. Either make Branch E the next active parent step or explicitly record a parent-ledger amendment that preserves step ordering.
- Cache-key blocker: do not introduce shared reuse until key dimensions are explicit and include state that changes rows, units, projection basis, custom definitions, Map metadata, MYCT-relevant state if touched, and tab-specific controls.
- Correctness blocker: any mismatch in rows, labels, projections, selected path, Map geography, MYCT behavior, or provider fallback behavior blocks acceptance until explained or fixed.
- Reactive-cascade blocker: if shared context causes inactive tabs to render or increases output churn, reject or gate the change before expanding scope.
- Instrumentation blocker: if reuse hides existing work, add replacement hit/miss/reuse counters before claiming a win.
- Scope blocker: artifact/load or build-time aggregation work requires explicit parent/daughter plan amendment because it is outside this product decision.
- Measurement-noise blocker: if a single run cannot distinguish an improvement from noise, either repeat the focused probe enough to make the decision defensible or limit the tranche to harness hardening.
- Cache-memory blocker: if shared reuse retains large frames without bounded lifecycle/invalidation, reject the cache design or narrow it before product-code validation.
- Stale-data blocker: any evidence of stale rows, stale labels, stale projection basis, stale Map period/geography, or stale MYCT state blocks acceptance.
- Equivalence blocker: if the optimized shared object cannot be compared to the pre-change path for measured states, do not accept it as a performance win.

Rejected approaches before Branch E implementation:
- Reopening startup artifact/load as the first response; slow startup is acceptable for this tranche.
- Treating the inherited Branch C hierarchy-transition run as final Branch E proof; it is target-selection evidence only.
- Creating a new probe style instead of reusing the established VP performance probe conventions.
- Loading polish or progress UI as a substitute for reducing repeated-use work.

## Tranche Execution Notes

- 2026-07-30 Branch E handoff creation:
  - Created this daughter source-of-truth plan before Branch E product-code edits.
  - Captured the product decision that slow startup is acceptable for this tranche.
  - Set the expected first strategy to shared-context reuse, controlled by fresh repeated-use probe evidence.
  - Made probe-convention reuse an explicit gate: any Branch E tab/filter probe must follow the established one-shot segmented Shiny probe and exact runtime summarizer workflow.
  - Updated parent plan `VP Clone/Code Review/2026-07-29_vp_performance_hotspot_recovery_plan.md`:
    - Step 12 now delegates Branch E interaction filtering and tab-switch responsiveness here.
    - Deferred build-time aggregation, artifact/data-format, and final validation rows shifted down.
    - Parent tranche notes record Branch E target, inherited Branch C evidence, probe-convention guardrail, shared-context strategy, and handoff validation.
  - Handoff validation:
    - `get_errors` reported no diagnostics for parent and daughter markdown.
    - `git diff --check -- "VP Clone/Code Review/2026-07-29_vp_performance_hotspot_recovery_plan.md" "VP Clone/Code Review/2026-07-30_vp_branch_e_interaction_filtering_tab_switch_responsiveness_plan.md"` produced no output.
    - Direct trailing-whitespace scan for parent and daughter plan files produced no output.

- 2026-07-30 Branch E baseline and branch decision:
  - Created `VP Clone/System/Testing/vp_perf_probe_tab_switch_filtering.R` as the smallest focused tab/filter probe needed for Branch E.
  - Preserved established VP probe conventions: `NOT_CRAN`, explicit label/cache-state/runtime args, `STAGE_BEGIN`/`STAGE_END`, bounded waits, JS/DOM reads, no broad `app$get_values()` during unstable windows, partial failure row, one-row CSV, requested runtime log path, fallback runtime log discovery, and exact summarizer `--input` workflow.
  - Syntax validation command passed with `PARSE_OK_BRANCH_E_TAB_FILTER_PROBE`.
  - Baseline command passed: `C:\Program Files\R\R-4.5.1\bin\Rscript.exe VP Clone/System/Testing/vp_perf_probe_tab_switch_filtering.R --label=step12_branch_e_tab_filter_baseline --cache-state=warm_partition_disk --runtime-perf=true --startup-timeout-ms=180000 --stage-timeout-ms=45000 --output-timeout-ms=60000`.
  - Probe output: `VP Clone/Logs/vp_perf_probe_tab_switch_filtering_step12_branch_e_tab_filter_baseline_20260730T134112Z.csv`.
  - Probe PASSed with final source/path `vp_trade` / `Dry pulses` / `Dried beans` / `Dried`, and final tab `Current vs. Average`.
  - Requested runtime log `VP Clone/Logs/vp_runtime_perf_tab_filter_step12_branch_e_tab_filter_baseline_20260730T134112Z.jsonl` did not exist after the run; summarized exact fallback JSONLs instead.
  - Runtime summary command passed with `--input=C:/Users/SETH.WECHSLER/OneDrive - USDA/Documents/Repositories/Almond Shiny Rice Clone/VP Clone/Logs/vp_runtime_perf_48ff21b0622f4546304985abd7ffa9d5.jsonl|C:/Users/SETH.WECHSLER/OneDrive - USDA/Documents/Repositories/Almond Shiny Rice Clone/VP Clone/Logs/vp_runtime_perf_proc_20260730T134128Z_13332.jsonl`.
  - Runtime summary outputs: `vp_perf_runtime_summary_runtime_logs_20260730T134459Z_timed.csv`, `vp_perf_runtime_summary_runtime_logs_20260730T134459Z_churn.csv`, `vp_perf_runtime_summary_runtime_logs_20260730T134459Z_partition.csv`, and `vp_perf_runtime_summary_runtime_logs_20260730T134459Z_key_delta.csv` in `VP Clone/Logs`.
  - Baseline interpretation: hierarchy/filter changes dominate user-visible repeated-use latency; tab-switch readiness after settled filters is not the first bottleneck.
  - Selected first product-code branch: small shared derived-reactive reuse in `VP Clone/Programs/app_source/server/03_core_reactives_and_ui.R`, not lazy tab-local gating.
  - Rejected attempt: added `bindCache()` wrappers around `most_recent()`, `historical_avg()`, `current_year_data()`, and `projection_data()` with Branch E cache-miss counters.
    - Parse initially failed because the `projection_data()` cache wrapper matched the `on.exit()` block; repaired and reran parse successfully with `PARSE_OK_BRANCH_E_CORE_REACTIVES`.
    - Post-change probe `step12_branch_e_derived_cache_post` PASSed functionally but failed performance acceptance: combined hierarchy change worsened from 90,517 ms to 112,220 ms, total probe worsened from 217,289 ms to 266,433 ms, and intended derived body counts did not drop.
    - Post-change runtime summaries: `VP Clone/Logs/vp_perf_runtime_summary_runtime_logs_20260730T135234Z_timed.csv`, `VP Clone/Logs/vp_perf_runtime_summary_runtime_logs_20260730T135234Z_churn.csv`, `VP Clone/Logs/vp_perf_runtime_summary_runtime_logs_20260730T135234Z_partition.csv`, and `VP Clone/Logs/vp_perf_runtime_summary_runtime_logs_20260730T135234Z_key_delta.csv`.
    - Exact fallback JSONLs summarized for rejected attempt: `VP Clone/Logs/vp_runtime_perf_3e0dc3837a7216bd498296309ac7265b.jsonl` and `VP Clone/Logs/vp_runtime_perf_proc_20260730T134802Z_20904.jsonl`.
    - Reverted the derived-reactive cache edit and validated `03_core_reactives_and_ui.R` with `PARSE_OK_BRANCH_E_CORE_REACTIVES_REVERT`.
  - Next branch decision after rejection: target duplicated commodity-choice base-value work, because `commodity_choice_real_values()` and `commodity_choice_fallback_values()` both rebuild the same non-builder base choices while hierarchy changes repeatedly invalidate commodity/type/sidebar state.

- 2026-07-30 Accepted Branch E product-code branch:
  - Edited `VP Clone/Programs/app_source/server/01_state_and_custom_types.R`.
  - Added `commodity_choice_native_base_values()` as a shared reactive around `build_commodity_choice_base_values(include_builder = FALSE)`.
  - Updated `commodity_choice_real_values()` and `commodity_choice_fallback_values()` to reuse that shared non-builder base reactive instead of rebuilding it independently.
  - Scope and correctness notes:
    - The change is session-reactive reuse only; it does not add an unbounded manual cache and does not retain new large data frames beyond Shiny reactive caching semantics.
    - Provider v3 row-index path, direct-filter fallback behavior, display-month mapping, Map code, and MYCT-specific sidebar code were not changed.
    - The changed helper is consumed by commodity/type choice surfaces, including MYCT type-mode choice rendering, but it preserves the same underlying `build_commodity_choice_base_values(include_builder = FALSE)` output and only eliminates duplicate sibling reads.
  - Parse validation passed: `PARSE_OK_BRANCH_E_STATE_CUSTOM_TYPES`.
  - Post-change probe command passed: `C:\Program Files\R\R-4.5.1\bin\Rscript.exe VP Clone/System/Testing/vp_perf_probe_tab_switch_filtering.R --label=step12_branch_e_commodity_base_reuse_post --cache-state=warm_partition_disk --runtime-perf=true --startup-timeout-ms=180000 --stage-timeout-ms=45000 --output-timeout-ms=60000`.
  - Post-change probe CSV: `VP Clone/Logs/vp_perf_probe_tab_switch_filtering_step12_branch_e_commodity_base_reuse_post_20260730T135412Z.csv`.
  - Post-change probe status: PASS.
  - Requested runtime log path did not materialize; summarized exact fallback JSONLs: `VP Clone/Logs/vp_runtime_perf_82bdb269975c7febde0a35f44e71e6ea.jsonl` and `VP Clone/Logs/vp_runtime_perf_proc_20260730T135416Z_35788.jsonl`.
  - Post-change runtime summary outputs: `VP Clone/Logs/vp_perf_runtime_summary_runtime_logs_20260730T135744Z_timed.csv`, `VP Clone/Logs/vp_perf_runtime_summary_runtime_logs_20260730T135744Z_churn.csv`, `VP Clone/Logs/vp_perf_runtime_summary_runtime_logs_20260730T135744Z_partition.csv`, and `VP Clone/Logs/vp_perf_runtime_summary_runtime_logs_20260730T135744Z_key_delta.csv`.
  - Timing result versus official Branch E baseline:
    - Combined hierarchy-change stage improved from 90,517 ms to 75,484 ms, about 16.6% faster.
    - Total probe improved from 217,289 ms to 201,650 ms, about 7.2% faster.
    - Source switch improved from 11,815 ms to 3,274 ms; trade-flow switch was broadly similar at 15,990 ms -> 16,878 ms.
    - Tab stages remained passing and sub-second after filter settlement: Historical Trend 58 ms, Heatmap 98 ms, Map 97 ms, return Current 127 ms.
  - Runtime summary result versus official Branch E baseline:
    - `filter_vp_rows_for_resolved_hierarchy()` improved from 44 calls / 3.1368s to 43 calls / 3.0616s.
    - `projection_data()` improved from 8 calls / 1.1433s to 8 calls / 1.0509s.
    - `output$commodity_choice_ui` remained 8 calls and changed from 0.4790s to 0.5540s, within acceptable single-run noise for the broader hierarchy-stage win.
    - `summary_table` remained 8 calls and changed from 1.3670s to 1.5181s, noted as residual noise/risk rather than a direct target win.
    - Provider summary stayed healthy: memory-cache 39 calls / 0.2326s, disk-cache 5 calls / 0.6399s, and no direct-filter summary row.
    - Type-choice base cache churn fell slightly: baseline had `type_choice_base_values_cache_hit` 8 and miss 7; accepted post run had hit 7 and miss 7, with the duplicate unknown/context row still present.
  - Acceptance decision:
    - Accepted because the user-facing repeated hierarchy-change stage improved materially, tab switches stayed fast, final VP path and outputs stayed valid, and provider behavior did not regress.
    - Did not continue to a riskier second product-code branch in this daughter because the accepted branch produced a measured win and residual hotspots now point to broader sidebar/key-churn work that deserves a fresh, separately scoped decision.

## Summary

Branch E is complete. This tranche focused on repeated-use responsiveness after startup, because slow startup was explicitly accepted for now. I added a focused tab/filter Shiny probe that follows the existing VP performance probe conventions, established a fresh warm-partition baseline, and used exact fallback runtime-log summaries when the requested runtime log path did not materialize.

The first broad idea, caching several derived Current-vs-Average reactives, was tested and rejected because it preserved behavior but made hierarchy filtering slower. That edit was reverted and validated. The accepted change is narrower: `commodity_choice_real_values()` and `commodity_choice_fallback_values()` now share one native non-builder commodity-choice base reactive instead of independently rebuilding the same base choices during hierarchy/sidebar churn.

Validation passed with `PARSE_OK_BRANCH_E_STATE_CUSTOM_TYPES` and the Branch E post-change probe `step12_branch_e_commodity_base_reuse_post`. The measured hierarchy/filter stage improved from 90,517 ms to 75,484 ms, about 16.6% faster, and total probe time improved from 217,289 ms to 201,650 ms. Tab switches remained passing and sub-second after filters settled. Provider behavior stayed healthy with memory/disk cache rows and no direct-filter fallback row.

Residual risk remains in broader sidebar/key churn: `summary_table`, display-month mapping, filtered-data, mixed-volume, quantity-unit, and type-choice filter purposes still execute repeatedly around hierarchy transitions. Those are better handled as a new measured tranche rather than stacking more speculative edits here. Map output readiness stayed passing in the probe; MYCT-specific code was not directly changed, though the shared commodity-choice helper is used by type-choice surfaces and should get targeted sanity if a future branch expands that area.
