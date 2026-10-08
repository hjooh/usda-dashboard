# VP Performance Hotspot Recovery Plan

Date: 2026-07-29
Branch: main
Status: Paused after Branch K closeout. Step 21 Branch K hierarchy/cache and K-R rollup ablation are closed and rolled up from `VP Clone/Code Review/2026-08-03_vp_branch_k_hierarchy_cache_architecture_plan.md` and `VP Clone/Code Review/2026-08-03_vp_branch_k_rollup_ablation_experiment_plan.md`. Branch K delivered a behavior-safe shared hierarchy context slice but no large repeated-use/tab-readiness win. K-R proved embedded rollup bulk is a material startup/artifact-load lever, but did not prove a stable tab-only win. Outstanding Branch K conditional paths are deferred. The next recommended work is a new separate aggressive lazy partition architecture plan: small startup shell, commodity-level native partitions loaded on demand, and commodity/context rollup sidecars. Pause here before creating that new plan. This file is the source of truth for VP app performance hotspot recovery implementation.

## Purpose

Recent VP aggregation and rollup work made the app functionally much stronger, but the app now has unacceptable runtime latency in ordinary use. The purpose of this tranche is to make performance logging safe enough to trust, identify measured hotspots, and pursue large runtime wins without drifting into broad unmeasured rewrites.

The immediate user-visible pain points are startup readiness, trade-flow changes, hierarchy changes, country/type choice refreshes, Historical Trend, Heatmap, and the Market Year Comparison Tool (MYCT). MYCT is tracked as a separate timing/debug area so its remaining issues do not contaminate core VP hierarchy, trend, and heatmap performance medians.

This file supersedes the performance-recovery notes inside `2026-07-27_vp_pipeline_rollup_all_plan.md` as the active implementation ledger. The 2026-07-27 rollup plan remains historical context for the rollup, partition-provider, and post-slice benchmark evidence.

## Scope

Included:
- New VP Code Review source-of-truth implementation ledger.
- Low-overhead runtime PERF changes, especially removing `gc()` observer effects from ordinary runtime logging.
- PERF JSONL summarizer with timed-event, untimed-event, cache churn, key-delta, and partition-mode reporting.
- New lightweight probe harnesses that can produce useful evidence while the app is still too slow for full repeated smoke tests.
- Targeted runtime attribution for expensive consumers and reactive churn.
- Measured provider/cache/reactive optimizations selected from PERF evidence.
- Validation after each tranche with plan updates before proceeding.
- Separate MYCT timing/debug probe coverage.

Excluded:
- Broad non-VP tuning.
- Unrelated Almond/Rice behavior changes.
- Full MYCT feature repair unless performance instrumentation exposes a direct blocker.
- Unmeasured data-format rewrites.
- User-facing loading/UX polish as the first response to slow code.
- Paired results markdown unless explicitly requested.

## Source-Of-Truth Ledger Contract

- This file is the broad source-of-truth implementation tracker for the VP performance recovery tranche.
- Narrow daughter/progeny plans may temporarily own patch-level implementation details only when this parent plan explicitly delegates the patch before code edits.
- Daughter plans must be summarized back into this parent plan at closeout with outcome, output paths, validation markers, residual risk, and the next recommended parent-plan target.
- Update this file after every step and tranche before moving to the next tranche.
- Record files touched, commands/probes, benchmark labels, output paths, PERF summaries, cache-state labels, bugs, blockers, failed attempts, rejected approaches, and decision gates.
- Keep command and evidence summaries concise but deterministic.
- Keep implementation chat brief; detailed progress belongs in this file.
- At completion, provide a short chat summary and complete the final `## Summary` section in this file.
- Do not create a paired results markdown file unless explicitly requested.

## Baseline Audit Findings

- Post-slice PASS-run medians from `post_slice_20260728` evidence:
  - `startup_ready_ms`: 74666 ms.
  - `source_switch_ms`: 543.5 ms.
  - `trade_flow_ms`: 30880.5 ms.
  - `hierarchy_change_ms`: 139158 ms.
  - `country_refresh_ms`: 16907 ms.
  - `current_vs_average_ms`: 557 ms.
  - `historical_trend_ms`: 22796 ms.
  - `heatmap_ms`: 21531 ms.
  - `total_scenario_ms`: 396888.5 ms.
- The first partition/provider slice improved total scenario time by about 24.2%, and trade-flow, hierarchy, and country refresh medians improved materially. Absolute timings remain too slow for interactive work.
- Historical baseline risk at file creation: runtime PERF risked distorting results because `runtime_perf_record()` snapshotted memory and called `gc()` for every structured runtime event. Tranche B resolved the default observer effect by making routine memory snapshots opt-in.
- Existing 3-run full-path smoke is not reliable while the app is this slow. Prior runs had 2 PASS / 1 FAIL, startup/control-gate instability, and timeout-prone full-path behavior.
- Current high-level suspicion: remaining wins are likely from broader partition/provider reuse, reactive churn reduction, lazy tab work, and reducing repeated large-frame scans/copies.
- Live dirty-worktree, generated-artifact, cache, and log state were captured at the start of Tranche A. Continue recapturing state before before/after comparisons where cache or generated artifacts matter.

## Guardrails

- Fix runtime PERF observer effect before adding high-volume instrumentation.
- Measure before optimizing each candidate path.
- Keep changes VP-scoped.
- Prefer small measured tranches over broad rewrites.
- Preserve direct-filter fallback and manifest integrity for partition/provider work.
- Add rollback/disable switches for experimental optimizations where feasible.
- Do not optimize build-time aggregation before logs prove it contributes to user-visible runtime latency or startup rebuilds.
- Keep MYCT evidence separate from core VP hierarchy/trend/heatmap medians until stable.
- Treat `wait_for_idle()` as suspect; prefer explicit visible state, control, and output checks.
- Do not use user-facing loading polish as a substitute for reducing avoidable work.

## Measurement Model and Cache-State Labels

Every probe or benchmark row must identify cache state:

- `cold_artifact`: fresh R session and no warmed partition cache for the target path.
- `warm_partition_disk`: partition files exist but session memory cache is empty.
- `warm_session`: same session and partition memory cache already hit.
- `unknown_cache_state`: only allowed for legacy baseline rows or explicitly documented harness/cache-state uncertainty where the evidence is used for target selection rather than final before/after proof.

Rules:
- Record whether partition directories, logs, or generated artifacts were cleared or preserved.
- Do not blend cold and warm timings into one median without labeling.
- Prefer separate output files or scenario labels for cold and warm probes.
- Record generated artifact/cache state before performance comparisons.

## Smoke and Harness Strategy

Do not use the current 3-run full-path shinytest smoke as the primary performance gate while the app is slow. The current full-path approach waits for idle after every mutation, uses 120000 ms waits, repeats the entire path, and turns app latency into timeout noise.

First layer: non-Shiny function probes.
- `VP Clone/System/Testing/vp_perf_probe_artifact_load.R`
- `VP Clone/System/Testing/vp_perf_probe_partition_provider.R`
- `VP Clone/System/Testing/vp_perf_probe_vp_filters.R`
- `VP Clone/System/Testing/vp_perf_summarize_runtime_logs.R`

These probes should load processed artifacts or source utilities directly, time artifact load, direct filtering, partition provider hit/miss paths, and runtime log summaries without launching a browser.

Second layer: one-shot segmented Shiny probes.
- `VP Clone/System/Testing/vp_perf_probe_startup.R`
- `VP Clone/System/Testing/vp_perf_probe_hierarchy_transition.R`
- `VP Clone/System/Testing/vp_perf_probe_country_type_choices.R`
- `VP Clone/System/Testing/vp_perf_probe_tabs.R`
- `VP Clone/System/Testing/vp_perf_probe_myct_entry.R`

One-shot probe rules:
- Perform one narrow action family.
- Write one raw CSV row plus runtime PERF logs.
- Exit after the segment; no 3-run loop initially.
- Use bounded staged waits and DOM/control/output presence checks instead of relying only on full Shiny idle.
- On timeout, report partial evidence: last completed stage, elapsed time, visible controls, selected source/tab, latest PERF log path, and app/session identifiers where available.

Reintroduce multi-run medians only after the relevant one-shot probe completes reliably below timeout. At that point, run three repetitions for that narrow probe, not the full app path. Full-path 3-run smoke becomes a late confirmation gate after major wins.

## PERF JSONL Summarizer Contract

Build the summarizer immediately after fixing the `gc()` observer effect.

The summarizer must handle:
- Timed `log_perf` records with `tag` and `elapsed_seconds`.
- Untimed `cache_body_execution` records by `name`, `count`, source, consumer, active tab, and other details.
- `cache_key_delta` records by `name`, changed fields, changed count, source, metric, and action/session fields when available.
- Partition events by mode (`materialized`, `disk_cache`, `memory_cache`, fallback/error modes), fallback reason, rows, elapsed time, and partition file.
- Memory high-water markers only when memory sampling is enabled.

Summary output should include:
- Count, median, p95, max, and total elapsed where elapsed exists.
- Top untimed event counts.
- Repeated executions per action/session when action fields are present.
- Top cache-key changed fields.
- Partition provider mode distribution and fallback reasons.

## Reactive Churn Metrics

Track repeated work per action, not only elapsed time.

Candidate counters:
- `selected_data()` executions.
- `base_data_converted()` executions.
- `filtered_data_for_country()` calls.
- `country_choice_options()` executions.
- Type-choice refreshes.
- Partition provider calls by mode.
- Cache-key changed fields per user action.
- Tab output render attempts.
- MYCT entry/type-country mode calls.

Add consumer labels wherever expensive data is read so a slow event can be tied to the caller. Use churn reduction as a decision gate alongside timing improvements.

## Runtime/UI Recommendations

- Defer user-facing loading polish until unavoidable waits are identified.
- Consider a dev-only PERF status surface later: source, active tab, action id, latest expensive event, selected cache/partition mode, and latest PERF log path.
- Prefer lazy tab computation: Historical Trend, Heatmap, and MYCT should not eagerly trigger heavy work during unrelated source/hierarchy changes if avoidable.
- Keep visible user behavior unchanged unless performance investigation proves a UI/state change is needed.

## Function-Level Recommendations

- Prefer pure helper probes before Shiny probes when possible.
- Use non-Shiny probes to time artifact load, direct filtering, partition provider hit/miss, and candidate helper functions.
- Preserve direct-filter fallback for every partition-backed provider expansion.
- Do not replace `vp_detail_match_key()` or tune build-time aggregation until build-stage logs prove it matters to visible app performance or startup rebuilds.

## Step Ledger

This ledger is the compact execution map. The tranche notes below remain the detailed evidence log; this table records where each step stands, what evidence controls it, and what must happen before moving on.

| Step | Phase | Work | Status | Evidence / Files | Gate / Next Action |
|---|---|---|---|---|---|
| 1 | A | Create source-of-truth ledger in VP Code Review | Complete | Added this file as the active implementation tracker before app-code edits. Validated with `git diff --check`. | Keep this file updated before every tranche transition. |
| 2 | A | Baseline evidence capture and audit refresh | Complete | Captured dirty-worktree, log, cache, and generated-artifact state: `global.R` modified by this tranche, this plan untracked, existing untracked `VP Clone/System/Processed Data/`, 45 runtime PERF JSONL logs, and 12 partition-cache files. Prior benchmark medians remain in Baseline Audit Findings. | Continue labeling new probe rows with cache state; do not compare cold/warm evidence without labels. |
| 3 | B | Reduce runtime PERF observer overhead | Complete (targeted) | Edited `VP Clone/Programs/app_source/global.R`. Added event-only default memory payload plus opt-in `off`/`sample`/`full` memory snapshot modes. Validation markers: `PARSE_OK_RUNTIME_PERF_MEMORY_MODE`, `RUNTIME_PERF_MEMORY_MODE_PROBE_OK`, and later `PARSE_OK_PERF_IMPLEMENTATION_SLICE`. | Treat default runtime PERF as safe enough for event/churn logging; use sampled/full memory only for explicit diagnostics. |
| 4 | C | Add PERF JSONL summarizer | Complete (expanded once) | Added `VP Clone/System/Testing/vp_perf_summarize_runtime_logs.R`. Initial run read 3 logs / 966 records and emitted files/events/timed/key-delta/partition/memory CSVs. Later expanded to `_churn.csv` and top-churn console output. Validation markers: `PARSE_OK_VP_PERF_SUMMARIZER`, `PARSE_OK_VP_PERF_SUMMARIZER_CHURN`. | Use summarizer after any fresh Shiny probe to rank timed buckets, helper churn, key deltas, and partition modes. |
| 5 | C | Add lightweight probe harnesses and demote full smoke | In progress | Added and validated `vp_perf_probe_artifact_load.R` and `vp_perf_probe_vp_filters.R`. Artifact load: 15.239s, 2,115,868 rows, about 847.8 MB in memory. Direct filters: import/all 801ms, Dry pulses 806ms, Dried beans/Dried 738ms. Added `vp_perf_probe_hierarchy_transition.R`; parse passed, `NOT_CRAN` guard fixed, defensive browser reads added, stage markers added, default per-stage wait lowered to 30s, and final-state reads switched to JavaScript. Long bounded hierarchy run passed: startup 85.480s, source switch 551ms, trade flow 15.591s, hierarchy 82.383s, total 184.143s. | Hierarchy probe is now usable for bounded single-run evidence. Partition-provider non-Shiny probe remains pending. Full 3-run smoke stays demoted. |
| 6 | D | Add targeted runtime consumer attribution and churn counters | Complete (initial) | Edited `VP Clone/Programs/app_source/server/02_partner_and_notes.R`. Added purpose-specific `cache_body_execution` and `cache_key_delta` records inside `filter_vp_rows_for_resolved_hierarchy()`. Fresh long bounded hierarchy probe produced the new counter names. Top churn: `mixed_volume_family_check` 162, `quantity_units_context` 118, `display_month_mapping` 36, `type_choice_base_values` 15, `filtered_data` 9. Timed helper total: 364 calls / 20.918s. | Use this evidence to choose the first optimization target; likely repeated `mixed_volume_family_check` and `quantity_units_context` calls before touching direct-filter mechanics. |
| 7 | D/E | Run PERF overhead A/B and measured probe baseline | Not started | Planned comparison: runtime PERF off vs event-only runtime PERF on, with cache-state labels and identical narrow scenarios. Current blocker is segmented Shiny harness instability. | Start with non-Shiny probes and/or hardened one-shot Shiny hierarchy probe; only then compare overhead. |
| 8 | E | Optimize first measured hotspot | Complete | Daughter plan `VP Clone/Code Review/2026-07-29_vp_mixed_volume_runtime_churn_optimization_plan.md` closed. Added shared session-local VP trade context/cache in `02_partner_and_notes.R` and replaced slow mixed/non-mixed sanity Shiny probe with fast artifact-contract probe. Validation markers include `PARSE_OK_STEP3_SHARED_CONTEXT`, `VP_MIXED_CONTRACT_OK`, `PARSE_OK_VP_MIXED_QUANTITY_SANITY_INDEXED`, and passing hierarchy probe `step8_post_mixed_context_cache_hierarchy`. Main deltas: total probe 184.143s -> 159.596s; hierarchy stage 82.383s -> 68.338s; hierarchy-filter timed calls 364 / 20.9175s -> 71 / 8.7033s; `mixed_volume_family_check` 162 -> 10; `quantity_units_context` 118 -> 8. | Recenter on this parent plan. Forced runtime log path still did not materialize, but exact fallback logs were recorded and summarized. Next measured target should be selected from remaining Step 8 evidence. |
| 9 | E | Optimize second measured hotspot/cache/provider tranche | Complete | Daughter plan `VP Clone/Code Review/2026-07-29_vp_partition_provider_cache_attribution_prewarm_plan.md` is closed. Implemented provider context attribution, metadata/index support, and Provider v3 row-index partition payloads with strict canonical-source checks. Clean confirmation probe `step7_option3_row_index_fast_source_confirm` passed. Main deltas: provider disk-cache 5 calls / 5.1963s in the metadata branch -> 5 calls / 0.7681s after Provider v3; `filter_vp_rows_for_resolved_hierarchy()` 68 calls / 7.9634s -> 68 calls / 3.7256s; provider memory-cache remained healthy at 63 calls / 0.2883s. | Recenter on this parent plan. Provider disk reads are no longer the main blocker; next measured target should come from startup/client mount cost, lazy tab behavior, or remaining display/type/filter churn. |
| 10 | E/F | Reduce startup-to-Current-vs-Average settling pause | Closed / redirected | Daughter plan `VP Clone/Code Review/2026-07-29_vp_startup_current_vs_average_settling_plan.md` is closed. Added durable startup probe and extended direct artifact/load probe. Startup evidence confirmed artifact load dominates, but Branch D app-code options were deferred: full uncompressed serialization has poor file-size tradeoff, the 17-column narrow shape was not contract-safe, and the 50-column contract-safe companion cannot replace Provider v3 canonical source identity. | Branch C daughter plan created for the next interaction-feel tranche. |
| 11 | E/F | Reduce Branch C display/type/filter churn | Complete | Daughter plan `VP Clone/Code Review/2026-07-29_vp_branch_c_display_type_filter_churn_reduction_plan.md` is closed. Added display-month mapping session reuse and native VP type-choice base reuse with explicit hit/miss counters. Main interaction deltas: hierarchy-filter work 68 calls / 4.4468s -> 43 calls / 2.8760s; display-month filter calls 24 -> 7; type-choice filter calls 15 VP plus one unknown/unknown row -> 7 VP plus one unknown/unknown row. Startup/current regression guard passed. | Branch E daughter plan created for the next repeated-use interaction tranche. |
| 12 | E/F | Branch E interaction filtering and tab-switch responsiveness | Complete | Daughter plan `VP Clone/Code Review/2026-07-30_vp_branch_e_interaction_filtering_tab_switch_responsiveness_plan.md` is closed. Added focused Branch E tab/filter probe and accepted narrow commodity-choice base reuse in `01_state_and_custom_types.R`. Main deltas: hierarchy-change stage 90.517s -> 75.484s; total probe 217.289s -> 201.650s; tab switches stayed passing/sub-second after filter settlement; provider memory/disk cache remained healthy with no direct-filter summary row. Broad derived-reactive caching attempt was tested, worsened timing, and was reverted. | Recenter on this parent plan. Next measured target should be selected from remaining repeated sidebar/key churn, `summary_table`/display-month/filtered-data residuals, or deferred startup artifact work by explicit decision. |
| 13 | E/F | Branch F hierarchy/sidebar reactive cascade reduction | Complete | Daughter plan `VP Clone/Code Review/2026-07-30_vp_branch_f_hierarchy_sidebar_reactive_cascade_reduction_plan.md` is closed. Added split-stage Branch F probe `VP Clone/System/Testing/vp_perf_probe_hierarchy_sidebar_cascade.R`, attribution counters, and accepted hierarchy UI nonce/render-stabilization branch in `02_partner_and_notes.R`. Main deltas: corrected Branch F hierarchy settle 85.802s -> 57.531s; total probe 194.745s -> 152.598s; same-instrumentation hierarchy settle 75.253s -> 57.531s; `data_frequency_ui_rendered` 11 -> 8; provider memory/disk cache remained healthy. | Recenter on this parent plan. Manual app use still reports 5-6s tab/commodity waits and 10+s group/subgroup waits, so Step 14 now measures perceived single-action latency before more code tuning. |
| 14 | E/F | Branch G perceived interaction latency / single-action measurement | Complete (measurement branch; no accepted product-code branch) | Daughter plan `VP Clone/Code Review/2026-07-30_vp_branch_g_perceived_interaction_latency_single_action_plan.md` is closed for this tranche. Added `VP Clone/System/Testing/vp_perf_probe_single_action_latency.R`; valid hardened baseline `step14_branch_g_single_action_plotly_ready_baseline` passed 11/11 with real Plotly/widget readiness fields. Evidence: commodity/hierarchy visible readiness was fast, hierarchy/filter full-idle tails stayed long, and settled tab Plotly readiness clustered around 10.054-10.636s. Rejected and reverted three product-code experiments: remove Plotly redraw, gate hidden Pace default target, and unsuspend Trend/Heatmap hidden Plotly outputs. | Recenter on this parent plan. Next measured target should avoid broad hidden-output warming and target either the near-10s Plotly materialization delay or narrow full-idle churn from summary/display-month/year-filter surfaces. |
| 15 | E/F | Branch H Plotly materialization attribution | Complete (attribution branch; no accepted product-code optimization) | Daughter plan `VP Clone/Code Review/2026-07-30_vp_branch_h_plotly_materialization_attribution_plan.md` is closed. Edited `VP Clone/System/Testing/vp_perf_probe_single_action_latency.R` for action-scoped timeline/lifecycle attribution and `VP Clone/Programs/app_source/ui.R` for measurement-only resize-state payload fields. Valid labels: `step15_branch_h_plotly_timeline_tab_baseline` (`PASS=4`), `step15_branch_h_plotly_timeline_tab_revisit_baseline` (`PASS=8`), `step15_branch_h_light_lifecycle_attribution_probe` (`PASS=4`), and `step15_branch_h_resize_state_attribution_probe` (`PASS=4`). Final evidence: Trend/Heatmap delay clusters at late Shiny/htmlwidget/afterplot/main-SVG/loading-clear; Map materializes around 10s but readiness settles later; Current has early SVG/afterplot but late Shiny value/loading-clear/readiness. Resize messages arrive late and usually find loading/no-SVG targets with `resized_count=0`; resize cost itself is small. Rejected direct Plotly-node probe binding (`PARTIAL=1|PASS=3`). Final validation: `PARSE_OK_BRANCH_H_RESIZE_CLOSEOUT_FILES`, no `get_errors` diagnostics for touched files, and `git diff --check` clean. | Recentered. No Branch H product branch selected. Next target should be chosen explicitly: either close attribution-only, investigate Map/Current output settling, investigate Shiny/htmlwidget delivery for Trend/Heatmap, or return to deferred full-idle churn/startup only by explicit decision. |
| 16 | E/F | Branch I Trend/Heatmap materialization reduction | Complete (attribution branch; no accepted product-code optimization) | Daughter plan `VP Clone/Code Review/2026-07-30_vp_branch_i_trend_heatmap_materialization_reduction_plan.md` is closed. Added measurement-only Trend/Heatmap server complexity details in `VP Clone/Programs/app_source/server/05_trend_and_heatmap.R` and bounded passive Plotly complexity fields in `VP Clone/System/Testing/vp_perf_probe_single_action_latency.R`. Valid labels: `step16_branch_i_trend_heatmap_server_complexity_capture` (`PASS=4`) and `step16_branch_i_trend_heatmap_complexity_baseline` (`PASS=4`). Output CSVs: `VP Clone/Logs/vp_perf_probe_single_action_latency_step16_branch_i_trend_heatmap_server_complexity_capture_20260731T161908Z.csv` and `VP Clone/Logs/vp_perf_probe_single_action_latency_step16_branch_i_trend_heatmap_complexity_baseline_20260731T163305Z.csv`. Runtime summaries: `VP Clone/Logs/vp_perf_runtime_summary_step16_branch_i_trend_heatmap_server_complexity_capture_runtime_20260731T163120Z_*.csv` and `VP Clone/Logs/vp_perf_runtime_summary_step16_branch_i_trend_heatmap_complexity_baseline_runtime_20260731T164110Z_*.csv`. Evidence: server render work was small (`timeseries_plot` about 0.163s; `heatmap_plot` about 0.387s), warm cached Trend/Heatmap render bodies did not execute, and client complexity was not extreme enough to justify a semantic payload simplification. | Recentered. Next target should be a separate Shiny/htmlwidget delivery/output-settling branch for cached Trend/Heatmap readiness, or return to known full-idle churn surfaces only by explicit priority. |
| 17 | E/F | Consider build-time aggregation instrumentation/tuning | Deferred | Build-time aggregation remains rejected as a first response. No visible-runtime evidence currently points to build-stage aggregation as the top user-facing bottleneck. | Revisit only if startup/runtime logs show rebuild or artifact-generation work during app use. |
| 18 | E/F | Consider narrower artifacts or data formats | Deferred | Artifact load is materially expensive: about 167 MB on disk and about 848 MB in memory, with 11-15s direct read times. This is important but Branch D app-code work remains deferred after Step 10 probe-only investigation, and slow startup is accepted for the current repeated-use tranche. | Consider only after repeated-use provider/cache/churn/materialization work or with explicit parent-plan amendment; avoid unmeasured format rewrites. |
| 19 | F | Final validation and Summary | Deferred / superseded | The broad final-validation step is superseded by the Branch J and Branch K closeouts plus focused validation inside their daughter ledgers. A late full-path smoke remains impractical while the app is still above usability targets. | Revisit only after the next architecture plan produces a candidate implementation below narrow-probe timeout risk. |
| 20 | E/F | Branch J VP-only source-state cleanup and dead observer removal | Complete | Daughter plan `VP Clone/Code Review/2026-07-31_vp_branch_j_vp_only_source_state_cleanup_plan.md` is closed. J-1 through J-7 and reopened J-2a were accepted after automated and manual validation. J-1R/J-1.5 source-authority/profile experiments were rejected/reverted with no retained source diff. The delegated hierarchy/sidebar cascade plan `VP Clone/Code Review/2026-08-01_vp_branch_j_hierarchy_cascade_readiness_plan.md` is accepted as probe-readiness repair. Final J-8 validation passed: VP quantity sanity `step20_branch_j_vp_contract_post` PASS; canonical `step20_branch_j_source_state_post` PASS=13 / 210273 ms; tab-only `step20_branch_j_tab_only_post` PASS=4 / 121700 ms; hierarchy/sidebar `step20_branch_j_hierarchy_sidebar_post` PASS / 125906 ms with 46925 ms hierarchy stage. Runtime summaries generated from exact fallback JSONLs: `Logs/vp_perf_runtime_summary_step20_branch_j_source_state_post_runtime_summary_20260801T231534Z_*`, `Logs/vp_perf_runtime_summary_step20_branch_j_tab_only_post_runtime_summary_20260801T231542Z_*`, and `Logs/vp_perf_runtime_summary_step20_branch_j_hierarchy_sidebar_post_runtime_summary_20260801T231547Z_*`. | Branch J closes as cleanup/attribution with visible VP behavior preserved and favorable reopened-B0 closeout timings, but not as a universal speed win. Do not run J-2b inside Branch J; comparison-cache retry remains deferred unless a later branch records a narrow churn hypothesis and hard rollback rule. Next recommended parent target is Shiny/htmlwidget/output settling for repeated-use readiness, or startup/artifact-load work only if startup becomes explicit priority. |
| 21 | E/F | Branch K hierarchy/cache architecture and K-R rollup ablation closeout | Complete | Branch K parent `VP Clone/Code Review/2026-08-03_vp_branch_k_hierarchy_cache_architecture_plan.md`; K-R granddaughter `VP Clone/Code Review/2026-08-03_vp_branch_k_rollup_ablation_experiment_plan.md`. K-A accepted a shared resolved hierarchy context cache and rejected several small fanout/output-settling slices as insufficient. K-R showed rollup rows are about 70.5% of canonical rows, reduced artifacts read about 3x faster, and K-R6 startup-to-ready improved from 85051 ms to 59815 ms in pair 1 and from 111341 ms to 74559 ms in pair 2. K-R6 tab-only evidence was inconclusive because direction flipped between pairs. Validation for touched K/K-R ledgers and K-R source/probe files was clean in the daughter ledgers. | Pause before creating a new plan. Next recommended plan is aggressive lazy partition architecture: startup shell metadata, commodity-level native partitions loaded on demand, commodity/context rollup sidecars, partition-bundle currentity, and parity tests against the current full artifact. |

## Phase Plan

Phase A: Ledger and baseline recenter
- Create this source-of-truth file.
- Capture live git/cache/log/artifact state.
- Record prior evidence and current blockers.

Phase B: Safe instrumentation foundation
- Reduce runtime PERF observer overhead.
- Keep JSONL compatibility where possible.
- Add switches for memory diagnostics and experimental behavior.

Phase C: Probe harness ladder and summarizer
- Build PERF summarizer.
- Add non-Shiny probes.
- Add one-shot segmented Shiny probes.
- Keep full-path smoke as late confirmation only.

Phase D: Runtime attribution and reactive churn tracking
- Add consumer labels for expensive data reads.
- Track repeated executions per action/session.
- Summarize cache-key churn and partition provider modes.

Phase E: Measured optimization tranches
- Optimize the top measured hotspot first.
- Validate and update this plan.
- Move to the next measured hotspot only after evidence supports it.

Phase F: Confirmation, manual sanity checks, and closeout summary
- Run appropriate narrow probes and, if practical, late full-path smoke confirmation.
- Perform manual VP sanity checks.
- Complete `## Summary`.

## Verification and Validation Targets

- Parse checks for touched R files using `C:\Program Files\R\R-4.5.1\bin\Rscript.exe` and `PARSE_OK` markers.
- PERF overhead A/B: runtime PERF off vs event-only runtime PERF on; sampled/full memory diagnostics only after overhead is acceptable.
- Non-Shiny probes for artifact load, partition provider, direct VP filters, and JSONL summarization.
- One-shot segmented Shiny probes while the app is slow.
- Narrow 3-run medians only after a one-shot probe reliably completes below timeout.
- Full-path 3-run smoke only as final confirmation after major wins.
- Provider/manifest probes after partition changes: disk reuse, memory reuse, stale/corrupt fallback, and short Windows filenames.
- Manual sanity checks: VP defaults, hierarchy changes, country dropdown, Current vs Average, Historical Trend, Heatmap, and separated MYCT entry.

## Bugs, Blockers, Failed Attempts, Rejected Approaches

- Resolved blocker: `runtime_perf_record()` formerly called memory snapshot/`gc()` on every event; Tranche B changed default runtime PERF logging to event-only memory fields with opt-in sampled/full memory snapshots.
- Known blocker/risk: full-path 3-run shinytest smoke times out or becomes unstable while the app is slow.
- Known prior failure: lightweight perf had `2 PASS / 1 FAIL` and a `country_choice` missing control failure.
- Known prior failure: `shinytest2` idle behavior can be unstable in this workspace.
- Known prior failure from AP cleanup validation context: lightweight perf failed with `Error: Reason: On CRAN`.
- Known risk: Windows path-length/file-lock issues can affect partition files; keep hashed filenames and manifest-readable labels.
- Known risk: workspace/generated artifact state can confuse comparisons unless cache/log/artifact state is recorded.
- Known product/debug note: MYCT still needs additional debugging; keep it as a separate probe.
- Rejected as first response: broad UI loading polish before measuring unavoidable waits.
- Rejected as first response: build-time aggregation tuning before visible runtime evidence points there.
- Deferred after Branch K: small hierarchy fanout/cache-key/build-metadata slices that do not change the unit of data loaded by the app. They are unlikely to deliver the drastic improvement now needed.
- Rejected after K-R: deleting production rollup rows or shipping native-only/minimal-rollup artifacts. Rollups preserve real all-selection semantics; they need relocation/lazy loading, not removal.
- Deferred after K-R: claiming a tab-only win from rollup ablation. Startup/artifact-load evidence is strong; tab-only direction flipped between pairs.
- New preferred architecture direction after K-R: aggressive lazy partitioning with a shell metadata artifact, commodity-level native partitions, and commodity/context rollup sidecars. This should be planned separately before implementation.
- Failed validation attempt (resolved): first runtime PERF memory-mode probe parsed only the first 230 lines of `global.R`, cutting off `runtime_perf_record()` and failing with `unexpected end of input`.
- Failed validation attempt (resolved): second probe included the start of `cache_trace_enabled()` and again failed with `unexpected end of input`; corrected by using the exact helper prefix ending before line 265.
- Failed validation attempt (resolved): third probe used fragile escaped JSON patterns in a PowerShell inline R command and failed on string escaping; corrected by building quote characters inside R.

## Tranche Execution Notes

- 2026-07-29 Tranche A (ledger + baseline):
  - Created this source-of-truth ledger before app-code edits.
  - Seeded prior post-slice benchmark evidence from the historical rollup/performance ledger.
  - Focused ledger validation: `git diff --check -- "VP Clone/Code Review/2026-07-29_vp_performance_hotspot_recovery_plan.md"` produced no output.
  - Live state capture:
    - `git status --short` showed this tranche's modified `VP Clone/Programs/app_source/global.R`, new untracked plan file, and pre-existing/untracked `VP Clone/System/Processed Data/`.
    - Existing runtime PERF logs: 45 `vp_runtime_perf_*.jsonl` files under `VP Clone/Logs`.
    - Existing VP partition-cache files: 12 files under `VP Clone/System/Processed Data/vp_trade_partitions`.

- 2026-07-29 Tranche B (runtime PERF observer overhead):
  - Edited `VP Clone/Programs/app_source/global.R`.
  - Added runtime memory diagnostics controls:
    - `runtime_perf_memory_mode()` using option `vp_perf_runtime_memory_mode` or env `VP_PERF_RUNTIME_MEMORY_MODE`.
    - Modes: default `off`, opt-in `sample`, and opt-in `full`.
    - `runtime_perf_memory_sample_interval()` using option `vp_perf_runtime_memory_sample_interval` or env `VP_PERF_RUNTIME_MEMORY_SAMPLE_INTERVAL`, defaulting to 25.
    - `runtime_perf_memory_payload()` now emits memory schema fields on every event but only calls `runtime_perf_memory_snapshot()` when full/sample mode requests it.
  - Behavior change:
    - Default runtime PERF events keep memory fields as `NA` and add `memory_snapshot_mode`, `memory_snapshot_taken`, `memory_snapshot_interval`, and `memory_event_count`.
    - Routine runtime PERF logging no longer calls `gc()` by default.
  - Validation:
    - Parse check passed: `PARSE_OK_RUNTIME_PERF_MEMORY_MODE` for `global.R`.
    - Focused helper probe passed: `RUNTIME_PERF_MEMORY_MODE_PROBE_OK`, confirming `off` mode writes `memory_snapshot_taken=false` and sample mode with interval `1` writes `memory_snapshot_taken=true`.
    - Diff whitespace check passed for `global.R` and this plan file.

- 2026-07-29 Tranche C (PERF JSONL summarizer):
  - Added `VP Clone/System/Testing/vp_perf_summarize_runtime_logs.R`.
  - Summarizer behavior:
    - Reads latest or explicitly supplied `vp_runtime_perf_*.jsonl` files.
    - Handles timed `log_perf` and `client_perf` records through normalized elapsed seconds.
    - Handles untimed `cache_body_execution` and `cache_key_delta` records through count summaries.
    - Emits event, timed, key-delta, partition, memory, and file-summary CSVs under `VP Clone/Logs`.
  - Validation:
    - Parse check passed: `PARSE_OK_VP_PERF_SUMMARIZER`.
    - Runtime probe passed with `--latest=3 --label=implementation_probe`.
    - Probe read 3 runtime PERF files and 966 records.
    - Output artifacts:
      - `VP Clone/Logs/vp_perf_runtime_summary_implementation_probe_20260729T154446Z_files.csv`
      - `VP Clone/Logs/vp_perf_runtime_summary_implementation_probe_20260729T154446Z_events.csv`
      - `VP Clone/Logs/vp_perf_runtime_summary_implementation_probe_20260729T154446Z_timed.csv`
      - `VP Clone/Logs/vp_perf_runtime_summary_implementation_probe_20260729T154446Z_key_delta.csv`
      - `VP Clone/Logs/vp_perf_runtime_summary_implementation_probe_20260729T154446Z_partition.csv`
      - `VP Clone/Logs/vp_perf_runtime_summary_implementation_probe_20260729T154446Z_memory.csv`
    - Top timed signals printed by the probe:
      - `filter_vp_rows_for_resolved_hierarchy()` appeared as the largest total-time bucket in recent logs.
      - `startup_init(total_pre_ui)` remained visible.
      - Client `tab_after_paint` and `main_tabs_mount` were visible in the top timed output.
    - Diff whitespace check passed for the summarizer and this plan file.

- 2026-07-29 Tranche D (first lightweight non-Shiny probes):
  - Added `VP Clone/System/Testing/vp_perf_probe_artifact_load.R`.
  - Probe purpose:
    - Time direct `readRDS()` load of `VP Clone/System/Processed Data/vp_trade_monthly_pre.rds` without launching Shiny.
    - Record cache-state label, artifact and metadata file size, read elapsed time, rows, columns, object size, and class.
  - Validation:
    - Parse check passed: `PARSE_OK_VP_ARTIFACT_LOAD_PROBE`.
    - One-shot probe passed with `--label=implementation_probe --cache-state=unknown_cache_state`.
    - Output artifact: `VP Clone/Logs/vp_perf_probe_artifact_load_implementation_probe_20260729T154551Z.csv`.
    - Measured current artifact load:
      - Status: `PASS`.
      - Cache state: `unknown_cache_state`.
      - Artifact size: about 167.0 MB.
      - Read elapsed: 15239 ms.
      - Rows: 2,115,868.
      - Columns: 59.
      - In-memory object size: about 847.8 MB.
    - Diff whitespace check passed for the artifact probe and this plan file.
  - Added `VP Clone/System/Testing/vp_perf_probe_vp_filters.R`.
  - Probe purpose:
    - Time direct VP hierarchy filters against the processed VP trade artifact without launching Shiny.
    - Keep artifact load timing separate from filter timing.
  - Validation:
    - Parse check passed: `PARSE_OK_VP_FILTER_PROBE`.
    - One-shot probe passed with `--label=implementation_probe --cache-state=unknown_cache_state`.
    - Output artifact: `VP Clone/Logs/vp_perf_probe_vp_filters_implementation_probe_20260729T154705Z.csv`.
    - Artifact load in this probe: 11234 ms.
    - Direct filter timings:
      - `import_all`: 801 ms, 984,483 rows.
      - `import_dry_pulses`: 806 ms, 128,243 rows.
      - `import_dried_beans_dried`: 738 ms, 30,280 rows.
    - Interpretation:
      - Single direct filters are not free, but they are far smaller than the cumulative runtime totals seen in the JSONL summary.
      - Repeated execution/churn around hierarchy filtering is likely a major win target.
    - Diff whitespace check passed for the filter probe and this plan file.
  - Combined validation:
    - Parse check passed for all touched R files: `PARSE_OK_PERF_IMPLEMENTATION_SLICE`.
    - Current tracked diffstat reports `global.R` with 65 lines touched; new plan/probe/log artifacts are untracked and visible in `git status --short`.
    - New generated probe outputs under `VP Clone/Logs/` are intentionally retained as evidence for this tranche.

- 2026-07-29 Tranche E (first runtime churn attribution):
  - Edited `VP Clone/Programs/app_source/server/02_partner_and_notes.R`.
  - Added session-scoped `cache_body_execution` counters inside `filter_vp_rows_for_resolved_hierarchy()`.
  - Counter names are purpose-specific, using `filter_vp_rows_for_resolved_hierarchy_<filter_purpose>` so repeated helper calls can be grouped by consumer in runtime summaries.
  - Added `cache_key_delta` tracking for the same purpose-specific name with source, active tab, trade flow, hierarchy choices, commodity name/detail, resolution mode, path name, strict-rollup flag, and sparse-selection flag.
  - Local hypothesis:
    - Recent direct filters are under one second each, while app-level hierarchy-change totals are far larger; the next likely win is repeated execution/churn rather than a single direct-filter operation.
  - Validation:
    - Parse check passed for the touched server file: `PARSE_OK_VP_FILTER_CHURN_ATTRIBUTION`.
  - Follow-up needed:
    - Run a fresh narrow VP runtime probe so the new helper-specific counter names appear in JSONL evidence.
  - Extended `VP Clone/System/Testing/vp_perf_summarize_runtime_logs.R` for churn reporting.
  - Summarizer changes:
    - Added dedicated `_churn.csv` output grouped by `name`, `filter_purpose`, `source`, `active_tab`, and `runtime_session_id`.
    - Expanded key-delta grouping to include `filter_purpose`, `source`, and `active_tab`.
    - Added top-churn console output for quick inspection after runtime probes.
  - Validation:
    - Parse check passed: `PARSE_OK_VP_PERF_SUMMARIZER_CHURN`.
    - Backward-compatibility run passed with `--latest=3 --label=churn_attribution_probe`.
    - Probe read 3 runtime PERF files and 966 records.
    - Output artifacts:
      - `VP Clone/Logs/vp_perf_runtime_summary_churn_attribution_probe_20260729T155039Z_files.csv`
      - `VP Clone/Logs/vp_perf_runtime_summary_churn_attribution_probe_20260729T155039Z_events.csv`
      - `VP Clone/Logs/vp_perf_runtime_summary_churn_attribution_probe_20260729T155039Z_timed.csv`
      - `VP Clone/Logs/vp_perf_runtime_summary_churn_attribution_probe_20260729T155039Z_key_delta.csv`
      - `VP Clone/Logs/vp_perf_runtime_summary_churn_attribution_probe_20260729T155039Z_churn.csv`
      - `VP Clone/Logs/vp_perf_runtime_summary_churn_attribution_probe_20260729T155039Z_partition.csv`
      - `VP Clone/Logs/vp_perf_runtime_summary_churn_attribution_probe_20260729T155039Z_memory.csv`
    - Existing logs still show `filter_vp_rows_for_resolved_hierarchy()` as the top timed bucket, with 142 events totaling 214.596 seconds and another 262 events totaling 121.472 seconds across the latest-log sample.
    - Existing logs do not yet contain the new `filter_vp_rows_for_resolved_hierarchy_<filter_purpose>` counter names because they predate this server edit.
  - Added `VP Clone/System/Testing/vp_perf_probe_hierarchy_transition.R` as a one-shot segmented Shiny hierarchy-transition probe.
  - Probe design:
    - Forces runtime PERF to event-only memory mode.
    - Writes a known runtime JSONL path for the probe label.
    - Uses soft staged `wait_for_idle()` calls around source, trade-flow, and hierarchy changes.
    - Writes one CSV row even on partial or failed probe execution where possible.
  - Validation and first run:
    - Initial parse check passed: `PARSE_OK_VP_HIERARCHY_TRANSITION_PROBE`.
    - First execution failed immediately with the known `shinytest2` CRAN guard: `Error: Reason: On CRAN`.
    - Hardened the probe to set `NOT_CRAN=true` before `AppDriver` startup, matching `vp_shinytest_smoke.R`.
    - Parse check after that fix passed: `PARSE_OK_VP_HIERARCHY_TRANSITION_PROBE_NOT_CRAN`.
    - Second execution passed the CRAN guard but failed after a Chrome/websocket reconnect with `Shiny server returned 404 for values URL ... input=vp_group_choice ... Is shiny::runApp(test.mode = TRUE) enabled?`.
    - Failure CSV: `VP Clone/Logs/vp_perf_probe_hierarchy_transition_churn_attribution_probe_20260729T155244Z.csv`.
    - No `vp_runtime_perf_hierarchy_transition_*.jsonl` file was created for the failed run.
  - Current interpretation:
    - The Shiny/browser harness is still unstable enough that it can fail before producing runtime PERF evidence.
    - The next probe hardening should keep the intended one-row output contract but avoid failing the entire run when input-value or JavaScript inspection calls hit a lost Shiny session.
  - Additional hardening performed after the failed Shiny session read:
    - Updated browser inspection helpers in `vp_perf_probe_hierarchy_transition.R` so DOM checks, select-choice reads, and input-value reads return partial evidence instead of aborting when the Shiny session disappears.
    - Corrected startup timing output to record the startup wait elapsed time directly.
    - Parse check passed after the defensive helper update: `PARSE_OK_VP_HIERARCHY_TRANSITION_PROBE_HARDENED`.
    - Hardened rerun with `--label=churn_attribution_probe_hardened --cache-state=unknown_cache_state --runtime-perf=true --stage-timeout-ms=90000 --startup-timeout-ms=120000` produced startup output but no stage completion output before it was killed as too opaque for a lightweight harness.
    - No useful runtime JSONL was produced by that killed run.
  - Next hardening target:
    - Add explicit stage begin/end console markers.
    - Lower the default per-stage wait so the probe behaves as a lightweight segmented harness rather than another long opaque smoke.
    - Preserve one-row CSV output and partial evidence behavior.
  - Completed stage-marker hardening:
    - Added `emit_probe()` and explicit `STAGE_BEGIN` / `STAGE_END` console markers around AppDriver startup, startup wait, input mutations, and select-choice reads.
    - Updated staged input helper to report set/wait success and elapsed milliseconds at each stage boundary.
    - Changed `run_probe()` to honor `--runtime-perf=false` instead of always enabling runtime PERF.
    - Lowered the default `--stage-timeout-ms` from 90000 to 30000.
    - Parse check passed: `PARSE_OK_VP_HIERARCHY_TRANSITION_STAGE_MARKERS`.
    - Bounded validation run used `--label=stage_marker_probe --cache-state=unknown_cache_state --runtime-perf=false --stage-timeout-ms=10000 --startup-timeout-ms=30000`.
    - The validation run emitted `VP_PERF_HIERARCHY_TRANSITION_STAGE_BEGIN=appdriver_start`, failed at the expected 30s startup boundary, and wrote `VP Clone/Logs/vp_perf_probe_hierarchy_transition_stage_marker_probe_20260729T163854Z.csv`.
    - No `vp_runtime_perf_hierarchy_transition_stage_marker_probe_*.jsonl` file was created, confirming the runtime-off flag was honored for this run.
  - First longer bounded hierarchy run with runtime PERF enabled:
    - Command: `vp_perf_probe_hierarchy_transition.R --label=long_bounded_hierarchy_probe --cache-state=unknown_cache_state --runtime-perf=true --stage-timeout-ms=30000 --startup-timeout-ms=120000`.
    - Startup completed and all staged input mutations set successfully, but every mutation wait hit the 30s boundary.
    - The run then hung after `segment_choice` before writing its final CSV row; it was killed as a finalization-path blocker.
    - No probe CSV or runtime log matching `long_bounded_hierarchy_probe` was produced by the killed run.
  - Final-state hardening after the killed longer run:
    - Replaced final `app$get_values()` input reads with JavaScript value reads to avoid blocking on Shiny's data-object endpoint after all staged work has completed.
    - Added `read_final_state` stage begin/end markers.
    - Parse check passed: `PARSE_OK_VP_HIERARCHY_TRANSITION_FINAL_STATE_JS`.
  - Successful longer bounded hierarchy run:
    - Command: `vp_perf_probe_hierarchy_transition.R --label=long_bounded_hierarchy_probe_jsfinal --cache-state=unknown_cache_state --runtime-perf=true --stage-timeout-ms=30000 --startup-timeout-ms=120000`.
    - Status: `PASS`.
    - Output CSV: `VP Clone/Logs/vp_perf_probe_hierarchy_transition_long_bounded_hierarchy_probe_jsfinal_20260729T165257Z.csv`.
    - Stage timings:
      - `startup_ready_ms`: 85480.
      - `source_switch_ms`: 551.
      - `trade_flow_ms`: 15591.
      - `hierarchy_change_ms`: 82383.
      - `total_probe_ms`: 184143.
      - `read_final_state`: 33 ms.
    - Resolved path: source `vp_trade`, group `Dry pulses`, subgroup `Dried beans`, segment `Dried`, `resolved_path_ok=TRUE`.
    - The CSV's requested runtime log path was not created; the app wrote runtime records to the default process/session log files instead.
    - Runtime logs summarized with `--latest=2 --label=long_bounded_hierarchy_probe_jsfinal`.
    - Summarized JSONL files:
      - `VP Clone/Logs/vp_runtime_perf_proc_20260729T165301Z_27116.jsonl`.
      - `VP Clone/Logs/vp_runtime_perf_e4bcad706a7fe3ea17b5349c1b2dedf1.jsonl`.
    - Runtime summary output artifacts:
      - `VP Clone/Logs/vp_perf_runtime_summary_long_bounded_hierarchy_probe_jsfinal_20260729T165638Z_files.csv`
      - `VP Clone/Logs/vp_perf_runtime_summary_long_bounded_hierarchy_probe_jsfinal_20260729T165638Z_events.csv`
      - `VP Clone/Logs/vp_perf_runtime_summary_long_bounded_hierarchy_probe_jsfinal_20260729T165638Z_timed.csv`
      - `VP Clone/Logs/vp_perf_runtime_summary_long_bounded_hierarchy_probe_jsfinal_20260729T165638Z_key_delta.csv`
      - `VP Clone/Logs/vp_perf_runtime_summary_long_bounded_hierarchy_probe_jsfinal_20260729T165638Z_churn.csv`
      - `VP Clone/Logs/vp_perf_runtime_summary_long_bounded_hierarchy_probe_jsfinal_20260729T165638Z_partition.csv`
      - `VP Clone/Logs/vp_perf_runtime_summary_long_bounded_hierarchy_probe_jsfinal_20260729T165638Z_memory.csv`
    - Runtime summary evidence:
      - 2 runtime files, 1363 records.
      - Top timed records: `tab_after_paint` 21.669s, `main_tabs_mount` 21.650s, `filter_vp_rows_for_resolved_hierarchy()` 364 calls / 20.9175s total, `startup_init(total_pre_ui)` 16.0351s, `startup_init(load_vp_trade_monthly_data)` 12.9458s.
      - Partition provider timing: 4 disk-cache calls / 4.9716s total and 1 materialized call / 1.3963s.
      - Top helper churn records:
        - `filter_vp_rows_for_resolved_hierarchy_mixed_volume_family_check`: 162 calls.
        - `filter_vp_rows_for_resolved_hierarchy_quantity_units_context`: 118 calls.
        - `filter_vp_rows_for_resolved_hierarchy_display_month_mapping`: 36 calls.
        - `filter_vp_rows_for_resolved_hierarchy_type_choice_base_values`: 15 calls.
        - `filter_vp_rows_for_resolved_hierarchy_filtered_data`: 9 calls.
      - Key deltas mostly changed `commodity_name` for the helper-specific counters, plus VP hierarchy/trade-flow fields on `map_runtime_source_cache_key`.
    - Interpretation:
      - The new instrumentation successfully disaggregates helper churn by consumer.
      - The largest first optimization target is likely repeated `mixed_volume_family_check` and `quantity_units_context` calls during hierarchy/trade-flow transition, not raw direct-filter speed.

- 2026-07-29 Tranche F (daughter-plan handoff for first optimization patch):
  - Created and delegated Step 8 to `VP Clone/Code Review/2026-07-29_vp_mixed_volume_runtime_churn_optimization_plan.md`.
  - Rationale:
    - The successful long bounded hierarchy probe produced fresh helper-specific churn evidence.
    - Top helper churn was `mixed_volume_family_check` with 162 calls and `quantity_units_context` with 118 calls.
    - Total timed `filter_vp_rows_for_resolved_hierarchy()` work in that run was 364 calls / 20.9175 seconds, while direct non-Shiny filters were subsecond.
  - Scope decision:
    - The daughter plan is the active source of truth for this optimization patch.
    - This parent plan will not duplicate daughter implementation details while the daughter plan is active.
    - At daughter closeout, update this parent with implementation outcome, output paths, validation markers, churn/timing deltas, residual risk, and the next recommended parent-plan target.
  - Critical guardrails carried into the daughter plan:
    - Do not remove `vp_volume_family_mixed` or weaken the smoke contract.
    - Any shared/memoized context key must include country/custom-country state.
    - Any metric-aware cached result must include `metric_code`.
    - Closeout evidence should improve runtime log attribution and cache-state labeling beyond the current target-selection baseline.

- 2026-07-29 Tranche G (daughter-plan closeout for first optimization patch):
  - Closed daughter plan `VP Clone/Code Review/2026-07-29_vp_mixed_volume_runtime_churn_optimization_plan.md` and recentered future work here.
  - Implementation outcome:
    - Added shared session-local VP trade context/cache helpers in `VP Clone/Programs/app_source/server/02_partner_and_notes.R`.
    - Routed mixed-volume checks and quantity-unit context helpers through the shared entry.
    - Computed mixed-volume state once in `apply_vp_context_metric_filters()` instead of repeating it across six choice vectors.
    - Replaced the slow browser-based mixed/non-mixed sanity probe with an artifact-contract probe at `VP Clone/System/Testing/vp_perf_probe_vp_mixed_quantity_sanity.R`.
  - Validation markers and artifacts:
    - App parse marker: `PARSE_OK_STEP3_SHARED_CONTEXT`.
    - Mixed artifact contract marker: `VP_MIXED_CONTRACT_OK`.
    - Sanity probe parse marker: `PARSE_OK_VP_MIXED_QUANTITY_SANITY_INDEXED`.
    - Fast sanity CSV: `VP Clone/Logs/vp_perf_probe_vp_mixed_quantity_sanity_step7_mixed_quantity_sanity_artifact_contract_indexed_20260729T184127Z.csv`.
    - Passing hierarchy CSV: `VP Clone/Logs/vp_perf_probe_hierarchy_transition_step8_post_mixed_context_cache_hierarchy_20260729T184433Z.csv`.
    - Runtime summary outputs: `VP Clone/Logs/vp_perf_runtime_summary_step8_post_mixed_context_cache_hierarchy_20260729T184738Z_*.csv`.
  - Runtime log attribution:
    - Requested Step 8 runtime JSONL did not materialize, reproducing the prior forced-path caveat.
    - Exact fallback logs summarized:
      - `VP Clone/Logs/vp_runtime_perf_proc_20260729T184436Z_38208.jsonl`.
      - `VP Clone/Logs/vp_runtime_perf_43e6b3927e39871d15f4412224544786.jsonl`.
  - Performance outcome vs baseline:
    - Total probe time: 184.143s -> 159.596s, improvement of 24.547s / 13.3%.
    - Hierarchy stage: 82.383s -> 68.338s, improvement of 14.045s / 17.1%.
    - Trade flow stage: 15.591s -> 12.837s, improvement of 2.754s / 17.7%.
    - Runtime records summarized: 1363 -> 460.
    - Total `filter_vp_rows_for_resolved_hierarchy()` timed calls: 364 -> 71, reduction of 293 calls / 80.5%.
    - Total `filter_vp_rows_for_resolved_hierarchy()` timed seconds: 20.9175 -> 8.7033, reduction of 12.2142s / 58.4%.
    - `mixed_volume_family_check` churn: 162 -> 10, reduction of 152 calls / 93.8%.
    - `quantity_units_context` churn: 118 -> 8, reduction of 110 calls / 93.2%.
  - Interpretation:
    - The first measured hotspot patch succeeded: target mixed-volume and quantity-unit churn is no longer dominant.
    - Remaining post-change churn is led by `display_month_mapping` with 24 calls, `type_choice_base_values` with 16 calls including one unknown/unknown row, and `filtered_data` with 9 calls.
    - Larger elapsed-time buckets now include app mount/client paint, startup VP artifact load, and partition-provider disk-cache work.
  - Recommended next target:
    - Select the next measured parent-plan target from the Step 8 summary rather than continuing inside the daughter plan.
    - Good candidates are remaining hierarchy-choice churn (`display_month_mapping` / `type_choice_base_values`) if pursuing incremental interaction wins, or startup/app-mount/artifact-load work if pursuing the next larger user-visible win.

- 2026-07-29 Tranche H (Step 9 target selection from Step 8 evidence):
  - Recentered on parent Step 8 closeout evidence and inspected the Step 8 runtime summary outputs:
    - `VP Clone/Logs/vp_perf_runtime_summary_step8_post_mixed_context_cache_hierarchy_20260729T184738Z_timed.csv`.
    - `VP Clone/Logs/vp_perf_runtime_summary_step8_post_mixed_context_cache_hierarchy_20260729T184738Z_churn.csv`.
    - `VP Clone/Logs/vp_perf_runtime_summary_step8_post_mixed_context_cache_hierarchy_20260729T184738Z_partition.csv`.
    - `VP Clone/Logs/vp_perf_runtime_summary_step8_post_mixed_context_cache_hierarchy_20260729T184738Z_key_delta.csv`.
  - Evidence considered:
    - Targeted mixed-volume and quantity-unit churn is no longer dominant after Step 8.
    - Remaining top churn: `display_month_mapping` 24 calls, `type_choice_base_values` 15 VP calls plus one unknown/unknown row, `filtered_data` 9 calls.
    - Remaining hierarchy-filter timed work: 71 calls / 8.7033 seconds.
    - Partition-provider split: 66 memory-cache calls / 0.0859 seconds, 5 disk-cache calls / 5.6491 seconds.
    - Disk-cache slice reads are the most concentrated remaining server-side interaction cost inside the hierarchy path; memory-cache reuse is already fast once a slice is loaded.
    - Larger elapsed buckets remain startup/app mount and VP artifact load: `tab_after_paint` 22.164s, `main_tabs_mount` 22.143s, `startup_init(total_pre_ui)` 15.3501s, and VP artifact read 12.1906s.
  - Target decision:
    - Select VP partition-provider disk-cache attribution and reuse/prewarm as Step 9's next measured optimization target.
    - Treat remaining hierarchy-choice churn (`display_month_mapping`, `type_choice_base_values`, `filtered_data`) as the nearby consumer surface, but do not start by rewriting those consumers blindly.
  - Reasoning:
    - The provider path is narrower and more directly tied to the current hierarchy-transition probe than startup/client-mount/artifact-format work.
    - The measured disk-cache cost is large enough for another meaningful interaction win: 5 disk reads cost 5.6491 seconds, while 66 memory hits cost 0.0859 seconds.
    - Current provider slice logs expose `mode`, `rows`, and `partition_file`, but not caller `filter_purpose`, active tab, or resolved hierarchy context; attribution should be tightened before optimizing reuse/prewarm behavior.
    - Startup/app-mount/artifact-load work remains important, but it is broader and should stay deferred until the remaining provider/cache interaction target is measured or exhausted.
  - Proposed Step 9 first tranche:
    - Add narrow provider attribution or a focused non-Shiny provider probe so each `vp_partition_provider_slice()` record can be tied to resolved hierarchy filters and, where practical, caller purpose / active tab.
    - Rerun the bounded hierarchy probe or a focused provider probe to identify which slices hit disk during source/trade/hierarchy transitions.
    - Then choose the smallest safe reuse/prewarm change, such as warming predictable hierarchy slices after trade-flow/hierarchy changes or avoiding duplicate disk reads across related choice/display consumers.
  - Rejected for immediate Step 9:
    - Broad VP artifact format/narrowing rewrite. It may be a big startup win later, but Step 12 already marks that as a larger format/data-shape decision and Step 9 has a narrower measured provider/cache target.
    - Client app-mount tuning without more attribution. `main_tabs_mount` and `tab_after_paint` are large, but the current evidence does not yet identify the server/UI surface to change safely.

- 2026-07-29 Tranche I (Step 9 daughter-plan handoff):
  - Created and delegated Step 9 to `VP Clone/Code Review/2026-07-29_vp_partition_provider_cache_attribution_prewarm_plan.md`.
  - Scope decision:
    - The daughter plan is now the active source of truth for VP partition-provider disk-cache attribution and reuse/prewarm implementation details.
    - This parent plan will not duplicate detailed Step 9 implementation ledger content while the daughter plan is active.
    - At daughter closeout, update this parent with implementation outcome, output paths, validation markers, timing/churn/partition deltas, residual risks, blocker investigations, and the next recommended parent-plan target.
  - Required daughter-plan implementation posture:
    - Attribution first, then the smallest measured provider/cache or call-site reuse change.
    - Direct non-Shiny provider probe is the primary validator for provider/cache behavior.
    - Bounded Shiny hierarchy probe is integration confirmation only after direct provider evidence exists.
    - No loading polish, spinners, progress copy, cosmetic waiting states, or UI latency-masking work belongs in this daughter plan.
  - Critical technical guardrails carried into the daughter plan:
    - Create or recover `VP Clone/System/Testing/vp_perf_probe_partition_provider.R`; no `vp_perf_probe*partition*` file currently exists under `VP Clone/System/Testing/`.
    - Pass caller context explicitly from `filter_vp_rows_for_resolved_hierarchy()` into `vp_partition_provider_filter_rows()` and `vp_partition_get_hierarchy_slice()`; do not use indirect global-state attribution hacks.
    - Label provider request kind (`user_hit`, `prewarm`, or `probe`) before judging prewarm success.
    - Preserve and summarize all provider modes: `memory_cache`, `disk_cache`, `materialized`, and `direct_fallback`, including `fallback_reason` and `manifest_reason`.
    - Keep provider reuse/prewarm keyed to provider-slice granularity: trade flow plus resolved hierarchy filters. Treat country/custom-country, commodity/detail, metric, and quantity-unit behavior as consumer-layer concerns unless the provider contract is deliberately redesigned and validated.
    - Do not implement synchronous prewarm that simply moves disk-read latency earlier in the same hierarchy mutation.
    - Defer cache eviction and partition RDS compression changes until direct probe evidence justifies those branches.
  - Handoff validation:
    - Daughter markdown diagnostics: no errors found.
    - Daughter trailing-whitespace check marker: `TRAILING_WHITESPACE_OK_DAUGHTER_STEP9`.

- 2026-07-29 Tranche J (Step 9 daughter-plan closeout: Provider v3 row-index partitions):
  - Closed daughter plan `VP Clone/Code Review/2026-07-29_vp_partition_provider_cache_attribution_prewarm_plan.md` and recentered future work here.
  - Implementation outcome:
    - Added provider caller-context attribution for partition-provider slices.
    - Added a focused direct provider probe: `VP Clone/System/Testing/vp_perf_probe_partition_provider.R`.
    - Implemented provider metadata/index support so metadata-only context questions can avoid row reads when definitive.
    - Metadata branch was correct but insufficient: passing metadata app run still had five provider disk-cache reads totaling 5.1963s.
    - Implemented Provider v3 row-index partition payloads in `VP Clone/Programs/app_source/global.R`; existing callers still receive data frames reconstructed from resident canonical `rice_data_vp_trade_monthly`.
    - Added strict source identity, row-order fingerprint, source-signature, row/column count, column-hash, index-bounds, payload-schema, metadata-parity, and source-mismatch refusal checks.
    - Added cached source signatures and canonical-source identity fast path after the first Option 3A app run exposed expensive source checks before memory-cache hits.
  - Direct validation:
    - Parse markers included `PARSE_OK_ROW_INDEX_PROVIDER_AND_PROBE`, `PARSE_OK_SOURCE_IDENTITY_FAST_PATH`, and `PARSE_OK_SOURCE_IDENTITY_FAST_PATH_CLEAN`.
    - Option 3A materialization/direct parity probe passed: `VP Clone/Logs/vp_perf_probe_partition_provider_step7_option3_row_index_step6_slices_20260729T204819Z.csv`.
    - Option 3A disk-cache direct probe passed: `VP Clone/Logs/vp_perf_probe_partition_provider_step7_option3_row_index_step6_slices_disk_20260729T204922Z.csv`.
    - Direct split timings for the two largest slices: v2 full-frame reads 1785ms and 1336ms; v3 payload reads 10ms and 12ms; reconstruction 94ms and 78ms.
    - All five direct rows passed row-content parity, metadata parity, selected metadata parity, and source-mismatch refusal.
  - App-path validation:
    - Clean confirmation hierarchy probe passed: `VP Clone/Logs/vp_perf_probe_hierarchy_transition_step7_option3_row_index_fast_source_confirm_20260729T210115Z.csv`.
    - Confirmation result: PASS; total 158.424s; hierarchy 72.163s; final path resolved to `Dry pulses / Dried beans / Dried`.
    - Reported runtime log path again did not materialize. Exact fallback logs summarized:
      - `VP Clone/Logs/vp_runtime_perf_proc_20260729T210119Z_34896.jsonl`.
      - `VP Clone/Logs/vp_runtime_perf_ff63212a6929b338ad74c09be15a4055.jsonl`.
      - Runtime summary outputs: `VP Clone/Logs/vp_perf_runtime_summary_step7_option3_row_index_fast_source_confirm_exact_20260729T210410Z_*.csv`.
    - Final closeout validation:
      - Parse marker: `PARSE_OK_STEP9_PROVIDER_CLOSEOUT` for `global.R`, `02_partner_and_notes.R`, `vp_perf_probe_partition_provider.R`, and `vp_perf_probe_hierarchy_transition.R`.
      - `get_errors` reported no diagnostics for those four R files.
      - `git diff --check` passed for touched code and plan files.
  - Final runtime deltas:
    - Provider disk-cache: metadata branch 5 calls / 5.1963s -> Provider v3 confirmation 5 calls / 0.7681s.
    - Provider disk-cache vs Step 6: 7.3614s -> 0.7681s.
    - Provider disk-cache vs Step 8 parent baseline: 5.6491s -> 0.7681s.
    - `filter_vp_rows_for_resolved_hierarchy()`: metadata branch 68 calls / 7.9634s -> Provider v3 confirmation 68 calls / 3.7256s.
    - Provider memory-cache after fast-source fix: 63 calls / 0.2883s, comparable to the metadata branch's 0.2598s.
  - Blockers and rejected branches summarized from the daughter plan:
    - Direct mixed-volume boolean branch shifted disk reads to later consumers and added scan work, so it was reverted.
    - In-memory `type_choice_base_values` branch failed hierarchy resolution, so it was reverted.
    - RDS compression A/B produced only modest read wins with roughly 9-11x file growth, so it was rejected.
    - Direct probe manifests initially lacked `source_signature`, causing app-path manifest rejection; fixed in the probe.
    - First Option 3A app run exposed expensive source-eligibility checks on memory-cache hits; fixed with the canonical-source fast path.
  - Residual risks:
    - Requested runtime log paths still often do not materialize; exact fallback process/session logs must continue to be found and summarized with `--input`.
    - Row-index partitions depend on strict canonical-source identity. The current checks intentionally refuse mismatched source state rather than guessing.
    - Total hierarchy probe time did not drop in proportion to provider disk-cache time, which means the next major bottleneck is outside provider disk I/O.
  - Recommended next target:
    - Select the next measured hotspot from the latest summaries rather than continuing provider-disk work.
    - Good candidates are startup/client mount and VP artifact load for broad user-visible latency, or remaining display/type/filter churn for the next interaction-focused tranche.

- 2026-07-29 Tranche K (Step 10 target selection: startup-to-Current-vs-Average settling):
  - Recentered on the parent plan after Step 9 closeout.
  - User-observed pain point:
    - There is a long pause between app initialization and the app settling into the Current-vs-Historical / Current-vs-Average working view.
    - Goal is to make the app feel snappier and more usable, not just reduce a backend micro-timing that users cannot feel.
  - Evidence from the clean Step 9 confirmation runtime summary:
    - Probe CSV: `VP Clone/Logs/vp_perf_probe_hierarchy_transition_step7_option3_row_index_fast_source_confirm_20260729T210115Z.csv`.
    - Exact runtime summary outputs: `VP Clone/Logs/vp_perf_runtime_summary_step7_option3_row_index_fast_source_confirm_exact_20260729T210410Z_*.csv`.
    - `startup_init(total_pre_ui)`: 17.9289s.
    - `startup_init(load_vp_trade_monthly_data)`: 14.7170s.
    - `startup_init(load_vp_trade_monthly_data): artifact_read`: 14.3030s.
    - `client_perf main_tabs_mount`: 16.609s.
    - `client_perf tab_after_paint`: 16.632s.
    - `filter_vp_rows_for_resolved_hierarchy()`: 68 calls / 3.7256s after Provider v3, no longer the largest server-side blocker.
    - Provider disk-cache: 5 calls / 0.7681s; provider disk reads are no longer the next target.
    - Remaining Current-vs-Average churn: `display_month_mapping` 24 calls, `type_choice_base_values` 15 VP calls plus one unknown/unknown row, `filtered_data` 9 calls, `mixed_volume_family_check` 7 calls, and `quantity_units_context` 7 calls.
  - Target decision:
    - Step 10 target is startup-to-Current-vs-Average settlement: the time from app launch/readiness through first useful Current-vs-Average tab paint and stable controls/outputs.
    - Treat this as a combined startup/client/eager-render target, not a provider-disk tranche.
    - Use the app's actual tab label `Current vs. Average` in probes and code, while keeping the user's observed wording in this note.
  - Local hypothesis:
    - The perceived pause is likely dominated by two layers: the large VP monthly artifact read during startup, then eager client/server work while the main tab surface mounts and Current-vs-Average outputs settle.
    - Historical Trend, Heatmap, MYCT, Map, Data, and other non-active outputs may still be mounting or reacting during first-tab settlement; if so, lazy tab/output gating could make the app feel ready sooner without changing data correctness.
    - Remaining display/type/filter churn may also contribute, but it is now smaller than startup artifact read and client mount/paint buckets.
  - First implementation gate:
    - Create or recover a focused startup-to-current-tab-settle probe before app-code optimization.
    - Required probe milestones: appdriver start, startup ready, first `main_tabs_panel` value, Current-vs-Average tab selected/visible, `main_tabs_mount`, `tab_after_paint`, comparison plot/table presence, key controls present, and final settled state.
    - Required runtime evidence: exact fallback runtime logs summarized with `--input` if the requested runtime file does not materialize.
    - Required cache labels: at least `warm_partition_disk`; avoid blending startup artifact-read evidence with warm-session-only interaction evidence.
  - Candidate branches after the probe gate:
    - Lazy non-active tab/output gating if runtime logs show Historical Trend, Heatmap, MYCT, Map, or other non-active outputs rendering during first Current-vs-Average settlement.
    - Current-vs-Average first-paint deferral if expensive secondary outputs can wait until the first useful controls/primary output are visible.
    - Remaining display/type/filter churn reduction if startup-to-current probe shows repeated `display_month_mapping`, `type_choice_base_values`, or `filtered_data` work still dominates after mount.
    - Startup artifact/load narrowing only if the startup probe confirms the artifact read remains the user-visible blocker after lazy/eager work is separated; this is broader and should not be the first blind edit.
  - Rejected as immediate response:
    - Another provider-disk tranche; Step 9 reduced provider disk-cache time to under 1s.
    - Broad artifact format rewrite before separating startup read time from first-tab eager work.
    - User-facing loading polish as a substitute for reducing the pause.
    - Full-path repeated shinytest smoke as the primary gate while startup/settling remains slow.

- 2026-07-29 Tranche L (Step 10 daughter-plan handoff):
  - Created and delegated Step 10 to `VP Clone/Code Review/2026-07-29_vp_startup_current_vs_average_settling_plan.md`.
  - Scope decision:
    - The daughter plan is now the active source of truth for startup-to-Current-vs-Average settling probe creation and the first measured optimization patch.
    - This parent plan will not duplicate detailed Step 10 implementation ledger content while the daughter plan is active.
    - At daughter closeout, update this parent with implementation outcome, output paths, validation markers, startup/mount/churn deltas, residual risks, blocker investigations, and the next recommended parent-plan target.
  - Required daughter-plan implementation posture:
    - Create `VP Clone/System/Testing/vp_perf_probe_startup.R` before app-code optimization.
    - Use the proven segmented Shiny probe conventions from `vp_perf_probe_hierarchy_transition.R`: bounded staged waits, `STAGE_BEGIN` / `STAGE_END` markers, defensive JavaScript reads, partial evidence on timeout, raw CSV output, cache-state labels, and exact fallback runtime-log summarization.
    - Separate initial landing tab from any explicit navigation to the literal app tab label `Current vs. Average`.
    - Compare probe DOM/CSV milestones with client PERF records from `ui.R`, including `client_perf_main_tabs_mount`, `client_perf_tab_after_paint`, `client_perf_tab_shown`, and `client_perf_main_tabs_profile`.
    - Record artifact, partition, log, and session state before probe comparisons; do not blend `cold_artifact`, `warm_partition_disk`, and `warm_session` evidence.
  - Candidate branches after the startup probe gate:
    - Lazy non-active tab/output gating if runtime logs show Historical Trend, Heatmap, MYCT, Map, Data, or other non-active outputs rendering during first Current-vs-Average settlement.
    - Current-vs-Average first-paint deferral if secondary Current-vs-Average outputs delay the primary useful controls/output.
    - Remaining display/type/filter churn reduction if `display_month_mapping`, `type_choice_base_values`, or `filtered_data` still dominates after startup/mount separation.
    - Startup artifact/load narrowing only after explicit plan amendment if the startup probe proves artifact read remains the user-visible blocker after eager tab/output work is separated.
  - Rejected for immediate Step 10:
    - Another provider-disk tranche.
    - Broad artifact format rewrite before probe separation.
    - Loading polish, spinners, progress copy, or cosmetic wait states.
    - Full-path repeated shinytest smoke as the primary gate.

- 2026-07-29 Tranche M (Step 10 daughter-plan closeout and Branch C handoff):
  - Closed daughter plan `VP Clone/Code Review/2026-07-29_vp_startup_current_vs_average_settling_plan.md` and recentered future work here.
  - New/extended probes from the daughter tranche:
    - Added focused startup-to-Current-vs-Average probe: `VP Clone/System/Testing/vp_perf_probe_startup.R`.
    - Extended direct artifact/load probe: `VP Clone/System/Testing/vp_perf_probe_artifact_load.R`.
  - Key evidence:
    - Passing startup baseline: `VP Clone/Logs/vp_perf_probe_startup_step10_startup_current_settle_baseline_tab_fallback_20260729T213127Z.csv`.
    - Exact runtime summary outputs: `VP Clone/Logs/vp_perf_runtime_summary_step10_startup_current_settle_baseline_tab_fallback_20260729T213258Z_*.csv`.
    - Artifact decomposition probe: `VP Clone/Logs/vp_perf_probe_artifact_load_step10_branch_d_artifact_load_decomposition_20260729T213800Z.csv`.
    - Serialization/shape A/B probe: `VP Clone/Logs/vp_perf_probe_artifact_load_step10_branch_d_serialization_shape_ab_20260729T214207Z.csv`.
    - Companion-contract probe: `VP Clone/Logs/vp_perf_probe_artifact_load_step10_branch_d_companion_contract_probe_20260729T214751Z.csv`.
  - Daughter outcome:
    - Startup artifact read remains the largest startup bucket.
    - Full uncompressed serialization was rejected as the next app patch because it has a poor file-size tradeoff.
    - The 17-column narrow artifact was useful as a lower-bound probe but not contract-safe.
    - The 50-column contract-safe startup companion candidate passed probe checks and read faster than the full artifact, but it cannot replace the full Provider v3 canonical source identity and would add a new artifact/currentity/loader/consumer-routing contract for a narrow first-view benefit.
    - No app startup semantics were changed.
  - Decision:
    - Step 10 is closed as a measured investigation / redirection tranche, not as a startup-latency fix.
    - Next recommended target is Branch C display/type/filter churn reduction because it should improve repeated-use app feel beyond initial startup.
    - First local target should be VP display-month mapping churn; second target should be type-choice generation only after preserving hierarchy resolution and final selected path.
  - Validation markers from daughter closeout included:
    - `PARSE_OK_VP_STARTUP_SETTLE_PROBE_RECURSIVE_PARTITION_COUNT`.
    - `PARSE_OK_VP_ARTIFACT_LOAD_DECOMPOSE_FINAL`.
    - `PARSE_OK_VP_ARTIFACT_SERIALIZATION_AB_FINAL`.
    - `PARSE_OK_VP_COMPANION_CONTRACT_FINAL`.
    - `TRAILING_WHITESPACE_OK_VP_COMPANION_CONTRACT`.
    - `TRAILING_WHITESPACE_OK_STEP8_COMPLETE_STEP9_IN_PROGRESS`.
  - Residual risks:
    - Requested runtime log paths still often do not materialize; exact fallback process/session logs must continue to be summarized with `--input`.
    - Startup artifact read remains a large visible cost.
    - Branch C will not remove the initial artifact-load pause, but it is the better next target for broader interaction snappiness.

- 2026-07-29 Tranche N (Branch C daughter-plan handoff):
  - Created and delegated Step 11 to `VP Clone/Code Review/2026-07-29_vp_branch_c_display_type_filter_churn_reduction_plan.md`.
  - Scope decision:
    - The daughter plan is now the active source of truth for Branch C display/type/filter churn reduction.
    - This parent plan will not duplicate detailed Step 11 implementation ledger content while the daughter plan is active.
    - At daughter closeout, update this parent with implementation outcome, output paths, validation markers, timing/churn/provider deltas, residual risks, blocker investigations, and the next recommended parent-plan target.
  - Required daughter-plan implementation posture:
    - Establish a fresh official Branch C baseline before product-code edits.
    - Use `VP Clone/System/Testing/vp_perf_probe_hierarchy_transition.R` as the primary interaction-churn gate.
    - Use `VP Clone/System/Testing/vp_perf_probe_startup.R` only as a secondary startup/current-settlement regression guard unless a patch directly changes startup behavior.
    - Treat count-only improvements as insufficient; accepted evidence must include elapsed interaction timing and runtime churn/timing summaries.
    - Start with display-month mapping churn, preferably by call-site de-duplication before adding cache abstractions.
    - Run or document a direct `calendar_signature` variance check before any lookup fast path.
    - Preserve Provider v3 behavior, direct-filter fallback, canonical-source checks, final selected hierarchy/type path, and existing purpose-specific counters or explicit replacement cache hit/miss/reuse/skip counters.
  - Rejected for immediate Step 11:
    - Branch D startup artifact/load narrowing.
    - General display-month mapping cache before cache-key/signature behavior is proven.
    - Type-choice generation rewrite before display-month evidence and validation.
    - Loading polish, spinners, progress copy, or cosmetic wait states.

- 2026-07-29 Tranche O (Branch C daughter-plan closeout):
  - Closed daughter plan `VP Clone/Code Review/2026-07-29_vp_branch_c_display_type_filter_churn_reduction_plan.md` and recentered future work here.
  - Implementation outcome:
    - Added direct signature-variance probe `VP Clone/System/Testing/vp_perf_probe_display_month_signature_variance.R`.
    - Added optional precomputed display-month mapping arguments to axis/year-label helpers in `03_core_reactives_and_ui.R` and reused mappings at hot comparison/trend/heatmap call sites.
    - Added narrowly keyed display-month mapping session reuse with `display_month_mapping_cache_hit` and `display_month_mapping_cache_miss` counters.
    - Added native VP type-choice base reuse with `type_choice_base_values_cache_hit` and `type_choice_base_values_cache_miss` counters, while leaving custom type enrichment and builder-row handling outside the cache.
  - Key evidence:
    - Official Branch C baseline probe: `VP Clone/Logs/vp_perf_probe_hierarchy_transition_step11_branch_c_display_mapping_baseline_retry_20260729T221038Z.csv`.
    - Official baseline runtime summaries: `VP Clone/Logs/vp_perf_runtime_summary_step11_branch_c_display_mapping_baseline_retry_fallback_20260729T221357Z_*.csv`.
    - Signature variance summary: `VP Clone/Logs/vp_display_month_signature_variance_step11_branch_c_display_mapping_signature_variance_20260729T221548Z_summary.csv`.
    - Final interaction probe: `VP Clone/Logs/vp_perf_probe_hierarchy_transition_step11_branch_c_type_choice_cache_post_20260729T223458Z.csv`.
    - Final interaction runtime summaries: `VP Clone/Logs/vp_perf_runtime_summary_step11_branch_c_type_choice_cache_post_fallback_20260729T223817Z_*.csv`.
    - Startup/current regression guard: `VP Clone/Logs/vp_perf_probe_startup_step11_branch_c_startup_regression_guard_20260729T223845Z.csv`.
    - Startup/current runtime summaries: `VP Clone/Logs/vp_perf_runtime_summary_step11_branch_c_startup_regression_guard_fallback_20260729T224012Z_*.csv`.
  - Final interaction deltas vs official Branch C baseline:
    - Total probe time: 187.809s -> 181.157s.
    - Trade-flow stage: 14.410s -> 12.225s.
    - Hierarchy stage: 79.256s -> 77.939s.
    - `filter_vp_rows_for_resolved_hierarchy()`: 68 calls / 4.4468s -> 43 calls / 2.8760s.
    - `display_month_mapping` filter calls: 24 -> 7, with 17 display-month cache hits.
    - `type_choice_base_values` filter calls: 15 VP calls plus one unknown/unknown row -> 7 VP calls plus one unknown/unknown row, with 8 VP type-choice cache hits.
    - Provider modes remained healthy: memory-cache 38 calls / 0.2042s and disk-cache 5 calls / 0.5718s, with no direct fallback row.
  - Validation markers:
    - `PARSE_OK_VP_DISPLAY_MONTH_SIGNATURE_VARIANCE_PROBE_DETAIL_FIX`.
    - `PARSE_OK_BRANCH_C_DISPLAY_MONTH_DEDUP`.
    - `PARSE_OK_BRANCH_C_DISPLAY_MONTH_CACHE`.
    - `PARSE_OK_BRANCH_C_TYPE_CHOICE_CACHE`.
    - `PARSE_OK_BRANCH_C_FINAL_TOUCHED_R`.
    - `git diff --check` passed for touched R files and plan files.
  - Residual risks:
    - Requested runtime log paths still often do not materialize; exact fallback process/session logs must continue to be summarized with `--input`.
    - Branch C does not remove the initial artifact-load pause.
    - The type-choice cache validated in the measured hierarchy-transition path, but manual UI sanity for unusual custom-builder editing workflows remains a useful follow-up if custom type editing is exercised heavily.
  - Recommended next target:
    - Branch E interaction filtering and tab-switch responsiveness has been selected as the next repeated-use tranche. Startup artifact/load work remains deferred by product decision.

- 2026-07-30 Branch E handoff (interaction filtering + tab-switch responsiveness):
  - Created daughter plan `VP Clone/Code Review/2026-07-30_vp_branch_e_interaction_filtering_tab_switch_responsiveness_plan.md` as the source of truth for the next tranche.
  - Branch E target:
    - Faster repeated-use VP filtering, hierarchy changes, and tab switches after app initialization.
    - Startup slowness is accepted for this tranche; Branch D artifact/load and companion-artifact work remain excluded unless fresh repeated-use evidence changes the parent decision.
  - Inherited final Branch C target-selection evidence:
    - `filter_vp_rows_for_resolved_hierarchy()`: 43 calls / 2.8760s.
    - `summary_table`: 8 calls / 1.3843s.
    - `projection_data()`: 8 calls / 1.0745s.
    - `filter_vp_rows_for_resolved_hierarchy_filtered_data`: 9 calls.
    - Provider modes remained healthy: memory-cache 38 calls / 0.2042s and disk-cache 5 calls / 0.5718s, with no direct fallback row.
  - Branch E guardrails added in the daughter plan:
    - Reuse established VP performance probe conventions from `vp_perf_probe_hierarchy_transition.R`, `vp_perf_probe_startup.R`, and `vp_perf_summarize_runtime_logs.R`; do not invent a separate Branch E harness style.
    - Require a fresh repeated-use Branch E baseline before product-code edits.
    - Preserve Provider v3 behavior, direct-filter fallback, final selected path, Map geography/period/metric metadata, and MYCT behavior or documented isolation.
    - Require explicit cache keys, lifecycle/memory behavior, data-equivalence checks, replacement hit/miss/reuse counters, and acceptance thresholds before shared-context product-code edits.
  - Expected first strategy:
    - Shared-context reuse for `filtered_data()`, `summary_table`, `projection_data()`, and visible-tab derived-output work if the fresh Branch E baseline supports it.
    - Lazy tab-local gating only if fresh tab-switch evidence proves inactive or non-target output execution.
  - Handoff validation:
    - `get_errors` reported no diagnostics for the new daughter markdown.
    - Direct trailing-whitespace scan for the new daughter file produced no output.

- 2026-07-30 Branch E closeout (interaction filtering + tab-switch responsiveness):
  - Daughter plan closed: `VP Clone/Code Review/2026-07-30_vp_branch_e_interaction_filtering_tab_switch_responsiveness_plan.md`.
  - Probe/harness work:
    - Added `VP Clone/System/Testing/vp_perf_probe_tab_switch_filtering.R` using the established one-shot Shiny probe conventions: `NOT_CRAN`, staged markers, bounded waits, JS/DOM reads, one-row CSV output, cache-state label, requested runtime log path, fallback log discovery, and exact summarizer `--input` workflow.
    - Probe parse marker: `PARSE_OK_BRANCH_E_TAB_FILTER_PROBE`.
  - Official baseline:
    - Probe CSV: `VP Clone/Logs/vp_perf_probe_tab_switch_filtering_step12_branch_e_tab_filter_baseline_20260730T134112Z.csv`.
    - Exact fallback runtime summaries: `VP Clone/Logs/vp_perf_runtime_summary_runtime_logs_20260730T134459Z_*.csv`.
    - Baseline PASS, `warm_partition_disk`; hierarchy-change stage 90.517s; total probe 217.289s; Historical Trend 66ms, Heatmap 72ms, Map 71ms, return Current 93ms after filters settled.
  - Rejected branch:
    - Broad `bindCache()` wrappers around `most_recent()`, `historical_avg()`, `current_year_data()`, and `projection_data()` were tested in `03_core_reactives_and_ui.R`.
    - First parse failed because the patch attached a wrapper inside `projection_data()`'s `on.exit()` block; repaired and parsed, then rejected after probe `step12_branch_e_derived_cache_post` worsened hierarchy time 90.517s -> 112.220s and total probe 217.289s -> 266.433s.
    - Reverted and validated with `PARSE_OK_BRANCH_E_CORE_REACTIVES_REVERT`.
  - Accepted branch:
    - Edited `VP Clone/Programs/app_source/server/01_state_and_custom_types.R`.
    - Added shared `commodity_choice_native_base_values()` so `commodity_choice_real_values()` and `commodity_choice_fallback_values()` reuse the same non-builder native choice base instead of rebuilding it separately during hierarchy/sidebar churn.
    - Parse marker: `PARSE_OK_BRANCH_E_STATE_CUSTOM_TYPES`.
    - Post-change probe CSV: `VP Clone/Logs/vp_perf_probe_tab_switch_filtering_step12_branch_e_commodity_base_reuse_post_20260730T135412Z.csv`.
    - Exact fallback runtime summaries: `VP Clone/Logs/vp_perf_runtime_summary_runtime_logs_20260730T135744Z_*.csv`.
    - Accepted result: hierarchy-change stage improved 90.517s -> 75.484s, about 16.6%; total probe improved 217.289s -> 201.650s, about 7.2%; tab stages remained passing and sub-second after filter settlement.
    - Provider summary stayed healthy: memory-cache 39 calls / 0.2326s, disk-cache 5 calls / 0.6399s, and no direct-filter summary row.
  - Residual risks and next recommended target:
    - `summary_table`, display-month mapping, `filtered_data`, mixed-volume, quantity-unit, and type-choice purposes still churn around hierarchy transitions.
    - Map readiness remained passing in the probe. MYCT-specific code was not directly edited, but future work touching commodity/type choice surfaces should include targeted MYCT sanity.
    - Recommended next parent target: select a fresh measured tranche from remaining repeated sidebar/key churn or explicitly return to startup artifact/data-format work if startup becomes the priority again.

- 2026-07-30 Branch F handoff (hierarchy/sidebar reactive cascade reduction):
  - Created daughter plan `VP Clone/Code Review/2026-07-30_vp_branch_f_hierarchy_sidebar_reactive_cascade_reduction_plan.md` as the source of truth for the next tranche.
  - Branch F target:
    - Reduce the remaining repeated-use hierarchy/sidebar cascade after Branch E left the canonical hierarchy-change stage at 75.484s.
    - Keep startup artifact/load work deferred unless the user explicitly reprioritizes startup or fresh repeated-use evidence proves artifact/currentity/signature work blocks ordinary interaction.
  - Inherited Branch E evidence:
    - Accepted Branch E post-change probe: `VP Clone/Logs/vp_perf_probe_tab_switch_filtering_step12_branch_e_commodity_base_reuse_post_20260730T135412Z.csv`.
    - Exact fallback runtime summaries: `VP Clone/Logs/vp_perf_runtime_summary_runtime_logs_20260730T135744Z_*.csv`.
    - Hierarchy-change stage improved 90.517s -> 75.484s; total probe improved 217.289s -> 201.650s; tab hops remained passing/sub-second after filter settlement.
    - Provider v3 remained healthy: memory-cache 39 calls / 0.2326s, disk-cache 5 calls / 0.6399s, and no direct-filter summary row.
  - Branch F guardrails added in the daughter plan:
    - Prefer a narrowly named sibling split-stage probe such as `vp_perf_probe_hierarchy_sidebar_cascade.R` so the closed Branch E probe stays stable.
    - Require split reset/group/subgroup/segment timing and server/client/UI attribution before product-code edits.
    - Audit `output$data_frequency_ui`, `map_surface_refresh_nonce()`, hierarchy observers, commodity/type-choice surfaces, shared output consumers, and `ui.R` client events without assuming any one is the cause.
    - Treat `freezeReactiveValue()`/batched select updates, sidebar render stabilization, narrow resolved-token reuse, summary/projection bundling, and JS throttling as evidence-gated candidate branches in that order.
    - Preserve Provider v3 behavior, final selected path, Map readiness, MYCT legal state behavior, generated-artifact separation, and exact runtime fallback-log summarization.
  - Handoff validation:
    - `get_errors` reported no diagnostics for this parent plan or the Branch F daughter plan.
    - `git diff --check` passed for this parent plan and the Branch F daughter plan.
    - Direct trailing-whitespace scan produced no matches for this parent plan or the Branch F daughter plan.

- 2026-07-30 Branch F closeout (hierarchy/sidebar reactive cascade reduction):
  - Daughter plan closed: `VP Clone/Code Review/2026-07-30_vp_branch_f_hierarchy_sidebar_reactive_cascade_reduction_plan.md`.
  - Probe/harness work:
    - Added `VP Clone/System/Testing/vp_perf_probe_hierarchy_sidebar_cascade.R` as a sibling probe rather than editing the closed Branch E probe.
    - Probe parse markers: `PARSE_OK_BRANCH_F_HIERARCHY_SIDEBAR_PROBE` and `PARSE_OK_BRANCH_F_HIERARCHY_SIDEBAR_PROBE_RADIO_VALUE`.
    - Fixed a probe reader defect so Shiny `radioButtons()` values such as `vp_trade_flow_choice` are captured from checked child inputs.
  - Corrected Branch F baseline:
    - Probe CSV: `VP Clone/Logs/vp_perf_probe_hierarchy_sidebar_cascade_step13_branch_f_hierarchy_sidebar_baseline_rerun_20260730T143753Z.csv`.
    - Exact fallback runtime summaries: `VP Clone/Logs/vp_perf_runtime_summary_step13_branch_f_hierarchy_sidebar_baseline_rerun_20260730T144114Z_*.csv`.
    - Baseline PASS, `warm_partition_disk`; hierarchy settle 85.802s; total probe 194.745s; group reset 0.637s, subgroup reset 0.627s, segment reset 0.647s; group choice 31.879s, subgroup choice 30.670s, segment choice 21.265s.
    - Runtime result: `filter_vp_rows_for_resolved_hierarchy()` 44 / 3.0933s; `summary_table` 8 / 1.2730s; `projection_data()` 8 / 1.0416s; provider memory-cache 39 / 0.2538s and disk-cache 5 / 0.6574s.
  - Attribution branch:
    - Added counters `data_frequency_ui_rendered`, `map_surface_refresh_nonce_bumped`, and later `vp_hierarchy_change_nonce_bumped` in `VP Clone/Programs/app_source/server/02_partner_and_notes.R`.
    - Parse marker before behavior change: `PARSE_OK_BRANCH_F_ATTRIBUTION_COUNTERS`.
    - Post-counter probe CSV: `VP Clone/Logs/vp_perf_probe_hierarchy_sidebar_cascade_step13_branch_f_attribution_counters_post_20260730T144239Z.csv`.
    - Exact fallback runtime summaries: `VP Clone/Logs/vp_perf_runtime_summary_step13_branch_f_attribution_counters_post_20260730T144536Z_*.csv`.
    - Counter evidence selected Branch F-2: `data_frequency_ui_rendered` appeared 11 times for VP / Current vs. Average during the hierarchy path.
  - Accepted branch:
    - Edited `VP Clone/Programs/app_source/server/02_partner_and_notes.R`.
    - Added a hierarchy-change nonce and made `output$data_frequency_ui` depend on that nonce while reading raw hierarchy values with `isolate()`, reducing direct duplicate invalidations from hierarchy controls.
    - Parse marker: `PARSE_OK_BRANCH_F_HIERARCHY_UI_NONCE`.
    - Accepted post-change probe CSV: `VP Clone/Logs/vp_perf_probe_hierarchy_sidebar_cascade_step13_branch_f_hierarchy_ui_nonce_post_20260730T144632Z.csv`.
    - Exact fallback runtime summaries: `VP Clone/Logs/vp_perf_runtime_summary_step13_branch_f_hierarchy_ui_nonce_post_20260730T144910Z_*.csv`.
    - Accepted result versus corrected Branch F baseline: hierarchy settle 85.802s -> 57.531s; total probe 194.745s -> 152.598s; group choice 31.879s -> 21.111s; subgroup choice 30.670s -> 23.036s; segment choice 21.265s -> 11.454s.
    - Same-instrumentation comparison: hierarchy settle 75.253s -> 57.531s; total probe 171.290s -> 152.598s; `data_frequency_ui_rendered` 11 -> 8.
    - Final path stayed valid: `vp_trade` / `import` / `Dry pulses` / `Dried beans` / `Dried`; final tab `Current vs. Average`; comparison output visible.
    - Provider stayed healthy: memory-cache 39 / 0.1994s and disk-cache 5 / 0.5005s, with no direct-filter fallback row.
  - Final validation:
    - Parse marker: `PARSE_OK_BRANCH_F_ACCEPTED_SLICE`.
    - `get_errors` reported no diagnostics for touched server, probe, parent plan, or daughter plan files.
    - `git diff --check` produced no output for touched server, probe, parent plan, and daughter plan files.
  - Residual risks and next recommended target:
    - `summary_table`, display-month mapping, `filtered_data`, mixed-volume, quantity-unit, type-choice, and Map key-delta surfaces still churn around hierarchy transitions.
    - `summary_table` was noisier in the accepted single run, rising to 8 / 2.9708s, but remained small relative to the hierarchy-stage improvement.
    - Startup artifact load remains intentionally deferred unless the user reprioritizes startup.
    - Recommended next parent target: choose either another repeated-use churn tranche from the residual summary/display/type/filter/key-delta evidence or explicitly pivot to startup artifact/data-format work.

- 2026-07-30 Branch G handoff and closeout (perceived interaction latency / single-action measurement):
  - Created daughter plan `VP Clone/Code Review/2026-07-30_vp_branch_g_perceived_interaction_latency_single_action_plan.md` as the source of truth for the next tranche.
  - Branch G target:
    - Measure the manual symptoms now driving the work: 5-6 second tab transitions, 5-6 second commodity changes, and 10+ second group/subgroup waits.
    - Separate visible output readiness, actual client interaction readiness, and full Shiny idle so Branch G does not optimize tail-idle timing while leaving the app feeling blocked.
    - Test tab clicks both after settlement and while prior commodity/filter work is still draining.
  - Inherited Branch E/F evidence:
    - Branch E showed settled tab hops stayed passing/sub-second after filter settlement, while hierarchy-change timing remained large.
    - Branch F reduced corrected hierarchy settle 85.802s -> 57.531s and total probe 194.745s -> 152.598s, but manual repeated-use latency remains unacceptable.
  - Branch G guardrails added in the daughter plan:
    - Create `VP Clone/System/Testing/vp_perf_probe_single_action_latency.R` as a sibling probe rather than destabilizing closed Branch E/F probes.
    - Capture `action_id`, `visible_ready_ms`, `client_interaction_ready_ms`, `full_idle_ms`, final selected state, stale-output checks, browser diagnostics, provider health, and exact fallback runtime summaries for each action.
    - Treat commodity-change fast path as the first likely code branch if measurement confirms commodity latency is dominated by choice refresh or repeated shared reactives.
    - Do not start with broad `bindCache()`, JS throttling, tabset rewrites, startup/artifact rewrites, or loading polish.
    - Preserve Provider v3 behavior, final selected path, Map readiness, MYCT legal state behavior, generated-artifact separation, and exact runtime fallback-log summarization.
  - Branch G implementation and validation:
    - Added `VP Clone/System/Testing/vp_perf_probe_single_action_latency.R` with per-action `visible_ready_ms`, `client_interaction_ready_ms`, `full_idle_ms`, browser diagnostics, final-state snapshots, stale-output checks, runtime fallback discovery, and CSV output.
    - Corrected tab actions from programmatic input setting to real tab anchor clicks, then hardened output readiness to count widgets on the output root and require Plotly/widget markers for plot outputs.
    - Hardened valid baseline: `step14_branch_g_single_action_plotly_ready_baseline`, `PASS=11`, CSV `VP Clone/Logs/vp_perf_probe_single_action_latency_step14_branch_g_single_action_plotly_ready_baseline_20260730T171015Z.csv`.
    - Exact fallback runtime input: `VP Clone/Logs/vp_runtime_perf_proc_20260730T171032Z_40560.jsonl|VP Clone/Logs/vp_runtime_perf_96221a8012f7e368dc621348ccddaca8.jsonl`; summaries `VP Clone/Logs/vp_perf_runtime_summary_runtime_logs_20260730T171441Z_*.csv`.
    - Key finding: settled tab Plotly readiness is a real 10s-class output materialization wait in this probe, while tab shell click/paint itself is cheap. Commodity and hierarchy visible readiness stayed fast, but full-idle tails for hierarchy/filter actions remain long.
    - Rejected and reverted product-code branches: removing `Plotly.redraw()` worsened tab readiness; gating hidden Pace default target caused partial/timeouts; unsuspending Trend/Heatmap hidden Plotly outputs regressed to 11/11 PARTIAL.
  - Post-closeout marketing-year/display-month decision note:
    - Marketing-year start metadata is already largely config/pipeline-backed: the almond contract defines `market_year_start_month = 8L`, and VP artifacts already carry `market_year`, `analysis_month`, `MonthNum`, month labels, and `calendar_signature`.
    - Runtime display-month work is still context-specific for VP trade. `current_display_month_mapping()` derives and caches a 12-row mapping by source, trade flow, hierarchy resolution, commodity context, and fallback year type; prior Branch C evidence showed broad display-month shortcuts are unsafe because `calendar_signature` varies by context.
    - Branch G churn shows display-month mapping is touched often, mostly as cache hits, but timed evidence does not make it the primary driver of the 10s-class tab Plotly/widget readiness delay. Treat it as a narrow residual full-idle-churn candidate, not the next broad pipeline-migration target, unless a future probe isolates material cost in misses or year-filter/display-month sync.
  - Final validation:
    - Parse markers include `PARSE_OK_BRANCH_G_SINGLE_ACTION_PROBE_PLOTLY_READY`, `PARSE_OK_BRANCH_G_TREND_HEATMAP_UNSUSPEND_REVERTED`, and `PARSE_OK_BRANCH_G_FINAL_ACCEPTED_FILES`.
    - `get_errors` found no diagnostics for the daughter plan, probe, or final touched server file.
    - `git diff --check` produced no output for accepted Branch G files.
    - No rejected app-code experiment remains as a source diff.

- 2026-07-30 Branch H handoff (Plotly materialization attribution):
  - Created daughter plan `VP Clone/Code Review/2026-07-30_vp_branch_h_plotly_materialization_attribution_plan.md` as the source of truth for the next tranche.
  - Branch H target:
    - Keep Branch G closed and attribute the near-10s settled-tab Plotly/widget readiness window before product-code optimization.
    - Distinguish server render, Shiny/htmlwidget output delivery, widget DOM insertion, Plotly draw/afterplot, resize/redraw ordering, readiness-predicate timing, probe overhead, and residual tab/client observer churn.
    - Start with a tab-only timeline baseline rather than the full Branch G canonical action list.
  - Branch H guardrails:
    - Use action-scoped timeline reset, action id tagging, expected output id, target tab, nearest output/root id attribution, and missing/unattributed event counts.
    - Prefer probe-only instrumentation first. Add app-level `forcePlotlyResize` internals only if probe-only evidence and existing coarse `client_perf_plotly_resize` implicate resize/redraw ordering.
    - Treat attribution-only closeout as acceptable. Product-code work is optional and should happen only after attribution identifies a clear, low-risk controlling layer.
    - Keep startup/artifact work, broad hidden-output warming, `Plotly.redraw()` removal, and display-month/year-filter/summary churn out of the first Branch H target.
  - Closeout outcome:
    - Branch H later closed as attribution-only with no accepted product-code optimization.
    - Valid labels: `step15_branch_h_plotly_timeline_tab_baseline`, `step15_branch_h_plotly_timeline_tab_revisit_baseline`, `step15_branch_h_light_lifecycle_attribution_probe`, and `step15_branch_h_resize_state_attribution_probe`.
    - Final finding: Historical Trend and Heatmap delays cluster around late Shiny/htmlwidget/Plotly delivery and materialization; Map and Current have related but less clean output-settling behavior.
    - Rejected path carried forward: direct Plotly-node probe binding perturbed timing and produced partial results.

- 2026-07-30 Branch I handoff (Trend/Heatmap materialization reduction):
  - Created daughter plan `VP Clone/Code Review/2026-07-30_vp_branch_i_trend_heatmap_materialization_reduction_plan.md` as the source of truth for the next tranche.
  - Parent recenter:
    - Step 16 now delegates to Branch I.
    - Build-time aggregation shifts to Step 17.
    - Narrower artifacts/data formats shifts to Step 18.
    - Final validation/Summary shifts to Step 19.
  - Branch I target:
    - Make Historical Trend and Heatmap tabs feel usable by reducing visible Plotly/htmlwidget materialization latency.
    - Treat Shiny/htmlwidget delivery and Plotly materialization as the broad target.
    - Treat payload complexity as the first measurable suspect, not an assumed root cause.
  - Branch I guardrails:
    - Begin with safe server-side Trend/Heatmap complexity metrics and passive client/probe complexity fields.
    - Do not select a product-code simplification until the baseline proves a low-risk target.
    - Preserve Branch G/H rejected paths: no Plotly redraw removal, no broad hidden-output warming, and no direct Plotly-node binding.
    - Keep Map and Current as regression/comparison surfaces in this tranche.
  - Current pause point:
    - Planning handoff is the only intended work in this interaction.
    - Planning handoff validation passed: no `get_errors` diagnostics and `git diff --check` clean for parent/daughter plan files.
    - No Branch I source-code implementation has started.

- 2026-08-03 Branch K closeout and K-R rollup ablation roll-up:
  - Closed Branch K hierarchy/cache architecture ledger: `VP Clone/Code Review/2026-08-03_vp_branch_k_hierarchy_cache_architecture_plan.md`.
  - Closed K-R rollup ablation granddaughter ledger: `VP Clone/Code Review/2026-08-03_vp_branch_k_rollup_ablation_experiment_plan.md`.
  - Branch K implementation outcome:
    - K-A delivered a behavior-safe shared resolved hierarchy context cache.
    - The K-A foundation slice improved some sidebar/tab-only totals relative to K-0 baselines but did not produce a large repeated-use/tab-readiness win, and canonical validation regressed.
    - Display-month cache-hit logging, map bottom-panel hidden suspension, year-filter lazy sync, and summary-table bindCache attempts were classified as attribution/output-settling cleanup, rejected, or reverted when they did not move visible readiness enough.
  - K-R accepted findings:
    - Embedded rollup rows are about 70.5% of canonical VP trade artifact rows: 1491692 of 2115868 rows.
    - Reduced native/minimal-rollup artifacts are about 48.1 MB on disk and 252.5 MB in memory versus about 167.0 MB and 847.8 MB for the full artifact.
    - Read-only reduced artifacts loaded in about 3.3 seconds versus about 10.4-12.1 seconds for canonical/full-copy artifacts.
    - Fair default provider disk-hit scenarios improved to about 0.8 seconds for reduced artifacts versus about 1.8-2.1 seconds for full artifacts.
    - K-R6 app-level startup pairs repeatedly improved: 85051 ms to 59815 ms in pair 1 and 111341 ms to 74559 ms in pair 2.
  - K-R bounded findings:
    - Minimal-rollup is a semantically invalid/performance-only test artifact and cannot be shipped.
    - Tab-only evidence remained inconclusive because pair 1 candidate was slower and pair 2 candidate was faster.
    - Production rollups should not be deleted because they preserve all-selection semantics.
  - Deferred Branch K work:
    - K-A1 targeted reuse, K-B cache-key/schema repair, K-C incremental provider/partition redesign, and K-D build/pipeline metadata are deferred out of Branch K.
    - Provider and build portions should reappear only as part of a new lazy partition architecture plan, not as more small Branch K patches.
  - New recommended parent-plan direction:
    - Create a separate aggressive lazy partition architecture plan after this pause.
    - Startup should read a small shell/metadata artifact containing valid choices, hierarchy metadata, display metadata, source signatures, partition indexes, and compatibility state.
    - Runtime should load commodity-level native partitions on demand instead of loading all native VP trade rows at startup.
    - Strict all-selection contexts should load commodity/context rollup sidecars on demand rather than embedding all rollup rows in the startup artifact.
    - The partition bundle needs currentity/manifest validation, deterministic commodity-switch sequencing, provider-level caching, explicit all-commodity/global aggregate paths, and parity tests against the current full artifact for all-selection, mixed-volume, unit-value, summary, map, trend, and heatmap contexts.
    - This direction is expected to help startup with high confidence and tab/filter/hierarchy responsiveness with medium confidence by shrinking the active working set and reactive fanout. Plotly/browser-heavy tabs still need tab-by-tab measurement.
  - Pause point:
    - Do not create the new architecture plan in this closeout step.
    - Let this parent ledger stand as the rolled-up hotspot summary until the user starts the new plan.

## Summary

The performance recovery effort is paused after Branch K closeout. Several measured cleanup, attribution, and implementation branches are complete. Branch J clarified the VP app's runtime source contract and preserved visible behavior while tightening VP-only source authority. Branch K then tested whether another round of hierarchy/cache/output-settling edits could deliver the needed usability improvement, and K-R tested whether embedded rollup bulk was a larger startup/artifact-load lever.

Branch J final validation passed. VP quantity sanity passed, canonical single-action passed `PASS=13`, tab-only passed `PASS=4`, and hierarchy/sidebar passed. Final timings were canonical total 210273 ms, tab-only total 121700 ms, and hierarchy/sidebar total 125906 ms with 46925 ms in the hierarchy stage. Treat Branch J as a successful source-state cleanup and attribution branch with favorable closeout timings, not a universal performance win.

Branch K's first implementation slice, the shared resolved hierarchy context cache, was behavior-safe but not large enough. It improved some sidebar and tab-only totals relative to K-0 baselines, but canonical timing regressed and tab readiness stayed far above the 1-3 second usability target. Several follow-up fanout/output-settling edits either produced attribution cleanup only or were reverted. Outstanding Branch K conditional paths are deferred.

K-R materially changed the next-step recommendation. Embedded rollup rows are about 70.5% of the canonical VP trade artifact rows. Reduced artifacts read about 3x faster and use about 70% less memory. App-level K-R6 startup probes showed repeated wins of about 25.2 seconds and 36.8 seconds. Tab-only evidence did not stabilize, and minimal-rollup is not shippable, but the startup/artifact-load signal is too large to treat as a side issue.

The recommended next work is a new, separate aggressive lazy partition architecture plan. The goal is to stop treating loaded VP data as one giant global data frame. Startup should read a small shell/metadata artifact, load only the needed commodity-level native partition, and load commodity/context rollup sidecars only when strict all-selection semantics require them. This plan should preserve current rollup correctness while reducing startup load, active working-set size, hierarchy/filter cascade breadth, provider metadata work, and reactive invalidation fanout. The current pause point is intentional: do not create the new plan until the user explicitly starts it.