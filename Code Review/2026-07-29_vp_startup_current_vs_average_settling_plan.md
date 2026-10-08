# VP Startup Current-vs-Average Settling Plan

Date: 2026-07-29
Branch: main
Status: Closed. Step 8 is complete, Step 9 closeout is complete, and future work is recentered on the parent plan with Branch C display/type/filter churn reduction as the recommended next target.

## Purpose

The parent VP performance hotspot recovery plan selected startup-to-Current-vs-Average settling as the next user-visible performance target. The immediate purpose of this daughter plan is to create trustworthy startup-to-first-useful-tab evidence before app-code optimization, then choose the smallest measured patch that reduces the pause between app launch/readiness and a settled `Current vs. Average` working view.

This is not another provider-disk tranche. Step 9 reduced provider disk-cache time below one second in the latest clean confirmation run. This plan treats Step 10 as a combined startup, client mount/paint, eager output, and Current-vs-Average reactive settlement problem. It explicitly separates artifact/load time from client mount/paint time, initial landing tab from explicit navigation to `Current vs. Average`, and non-active tab work from Current-vs-Average first-paint work.

## Scope

Included:
- Create this daughter source-of-truth ledger and keep it updated before every implementation tranche transition.
- Amend the parent plan to delegate parent Step 10 here before app-code optimization edits.
- Create `VP Clone/System/Testing/vp_perf_probe_startup.R` as the focused startup-to-current-tab-settle probe.
- Use the established one-shot segmented Shiny probe conventions that have already worked for hierarchy-transition evidence.
- Record cache-state labels, artifact/partition/log/session state, probe milestones, client PERF records, exact runtime logs, fallback runtime log candidates, churn counters, key deltas, and interpretation.
- Use the startup probe as the first gate before selecting lazy non-active tab/output gating, Current-vs-Average first-paint deferral, remaining display/type/filter churn reduction, or broader artifact/load work.
- Preserve provider v3 behavior, direct-filter fallback, event-only runtime PERF defaults, existing client PERF hooks, purpose-specific churn counters, and separated MYCT evidence.
- Close this daughter plan with implementation results, validation evidence, residual risks, and parent-plan handoff notes.

Excluded:
- Another provider-disk optimization tranche unless fresh Step 10 evidence unexpectedly points there.
- Broad artifact format, data-shape, narrowed-artifact, or lazy-load rewrites as the first response.
- Loading polish, loading spinners, progress copy, cosmetic waiting states, or any UI latency-masking work.
- Full-path repeated shinytest smoke as the primary performance gate.
- Continuing to tune `VP Clone/System/Testing/_tmp_startup_probe.R` as though it were a durable harness.
- Non-VP tuning.
- Creating a paired results markdown file unless explicitly requested.

## Parent Plan Linkage

Parent plan: `VP Clone/Code Review/2026-07-29_vp_performance_hotspot_recovery_plan.md`.

This daughter/progeny plan owns detailed implementation notes for parent Step 10, "Reduce startup-to-Current-vs-Average settling pause." The parent remains the broad performance recovery ledger. During this patch, the parent should contain only the delegation note, high-level status, and closeout summary; detailed technical decisions, failed attempts, validation commands, probe outputs, and runtime evidence belong here.

At closeout:
- Complete this daughter `## Summary` section in plain language.
- Update the parent Step Ledger with the Step 10 outcome.
- Add parent tranche notes with output paths, validation markers, startup/mount/churn deltas, residual risks, blocker investigations, and the next recommended parent-plan target.
- Recenter future work on the parent plan.

## Source-Of-Truth Ledger Contract

- This file is the active source of truth for the startup-to-Current-vs-Average settling patch.
- Update this file after every step or tranche before moving to the next tranche.
- Record files touched, commands/probes, benchmark labels, cache-state labels, artifact/partition/log/session state, runtime log paths, PERF summaries, client PERF records, churn deltas, bugs, blockers, failed attempts, rejected approaches, and decision gates.
- Keep parent-plan updates limited to delegation and closeout while this daughter plan is active.
- Preserve enough detail that a future coder can resume without replaying chat history.
- At completion, provide a short chat summary and complete the final `## Summary` section in this file.

## Baseline Evidence

Step 10 target selection came from the clean Step 9 Provider v3 confirmation evidence:
- Probe CSV: `VP Clone/Logs/vp_perf_probe_hierarchy_transition_step7_option3_row_index_fast_source_confirm_20260729T210115Z.csv`.
- Exact runtime summary outputs: `VP Clone/Logs/vp_perf_runtime_summary_step7_option3_row_index_fast_source_confirm_exact_20260729T210410Z_*.csv`.
- `startup_init(total_pre_ui)`: 17.9289 seconds.
- `startup_init(load_vp_trade_monthly_data)`: 14.7170 seconds.
- `startup_init(load_vp_trade_monthly_data): artifact_read`: 14.3030 seconds.
- `client_perf main_tabs_mount`: 16.609 seconds.
- `client_perf tab_after_paint`: 16.632 seconds.
- `filter_vp_rows_for_resolved_hierarchy()`: 68 calls / 3.7256 seconds after Provider v3.
- Provider disk-cache: 5 calls / 0.7681 seconds; provider disk reads are no longer the next target.
- Remaining Current-vs-Average churn: `display_month_mapping` 24 calls, `type_choice_base_values` 15 VP calls plus one unknown/unknown row, `filtered_data` 9 calls, `mixed_volume_family_check` 7 calls, and `quantity_units_context` 7 calls.

Baseline caveats:
- Durable `VP Clone/System/Testing/vp_perf_probe_startup.R` and `VP Clone/System/Testing/vp_perf_probe_tabs.R` do not currently exist, although the parent harness ladder listed them as intended probes.
- `VP Clone/System/Testing/_tmp_startup_probe.R` exists only as historical/remnant evidence. It uses full idle and `app$get_values()`, so it is not the durable probe pattern for this tranche.
- Requested runtime JSONL paths often do not materialize. Exact fallback process/session logs must continue to be discovered, recorded, and summarized with `--input=...`.
- The current target-selection evidence is strong enough to choose Step 10, but not enough to decide between lazy gating, first-paint deferral, churn reduction, or artifact/load work without a focused startup-to-current probe.

## Technical Read

Known startup and instrumentation surfaces:
- `VP Clone/Programs/app_source/global.R` contains startup artifact load behavior, provider v3 row-index support, and runtime PERF helper behavior.
- `VP Clone/Programs/app_source/ui.R` emits client PERF records including `client_perf_main_tabs_mount`, `client_perf_tab_after_paint`, `client_perf_tab_shown`, and `client_perf_main_tabs_profile`.
- Client `main_tabs_mount` and `tab_after_paint` use browser `pageLoadStartedAt` timing, while the probe will use AppDriver/process timing. The startup probe must compare both views instead of treating them as identical clocks.
- `VP Clone/Programs/app_source/server/02_partner_and_notes.R` owns main-tab normalization/default behavior and many Current-vs-Average state/reactive surfaces.
- The literal app tab label is `Current vs. Average`. Probe selectors and app code should use this label exactly.
- Source-dependent tab normalization can cause the app to land somewhere other than `Current vs. Average` under some source/profile conditions. The probe must record initial landing and time any explicit navigation separately.
- `VP Clone/Programs/app_source/server/04_comparison_plots.R` contains the Current-vs-Average primary comparison output surface, including `comparison_plot` and the existing `is_current_vs_average_output_active()` gating pattern.
- `VP Clone/Programs/app_source/server/05_trend_and_heatmap.R` contains likely non-active output surfaces, including `timeseries_plot` and `heatmap_plot`, that are priority suspects only if runtime logs show them executing during first Current-vs-Average settlement.
- `VP Clone/Programs/app_source/server/01_state_and_custom_types.R` contains type-choice behavior that may matter if `type_choice_base_values` remains top churn during startup settlement.

Local hypothesis:
- The perceived pause is likely dominated by two layers: the large VP monthly artifact read during startup, then eager client/server work while the main tab surface mounts and Current-vs-Average outputs settle.
- Historical Trend, Heatmap, MYCT, Map, Data, and other non-active outputs may still be mounting or reacting during first-tab settlement. If so, lazy tab/output gating could improve perceived readiness without changing data correctness.
- Remaining display/type/filter churn may also contribute, but it is now smaller than startup artifact read and client mount/paint buckets.

First falsification check:
- If a focused startup-to-current probe shows non-active tab/output work during first `Current vs. Average` settlement, prioritize lazy gating.
- If it shows Current-vs-Average-only repeated display/type/filter churn, reduce that churn.
- If it shows artifact read dominates after eager UI/reactive work is separated, require an explicit plan amendment before artifact/load work.

## Guardrails

Correctness and behavior guardrails:
- Preserve current user-visible VP behavior unless a deliberate measured behavior change is recorded here first.
- Preserve direct-filter fallback behavior.
- Preserve Provider v3 row-index safety checks and manifest/source-integrity behavior.
- Preserve runtime PERF event-only default and existing client PERF hooks.
- Keep MYCT evidence separate from core Step 10 comparisons unless MYCT itself is the gated surface under investigation.
- Do not use user-facing loading polish as a substitute for reducing avoidable work.

Probe guardrails:
- Create `VP Clone/System/Testing/vp_perf_probe_startup.R`; do not treat `_tmp_startup_probe.R` as the durable harness.
- Use the successful defensive pattern from `vp_perf_probe_hierarchy_transition.R`: `STAGE_BEGIN` / `STAGE_END` markers, bounded staged waits, JavaScript DOM/input reads, partial evidence, and one raw CSV row.
- Set `Sys.setenv(NOT_CRAN = "true")` before `AppDriver$new()`.
- Avoid blocking `app$get_values()` during high-latency startup or final-state windows.
- Use explicit DOM/control/output presence checks instead of relying on full Shiny idle.
- On timeout, report partial evidence: last completed stage, elapsed time, visible controls, selected source/tab, requested runtime log path, fallback runtime log candidates, and app/session identifiers where available.

Cache-state guardrails:
- Use parent cache-state labels precisely: `cold_artifact`, `warm_partition_disk`, `warm_session`, and `unknown_cache_state` only when uncertainty is explicit and evidence is not final proof.
- Do not imply that deleting partition directories creates a `cold_artifact` run. Artifact/session warmth and partition-cache warmth are separate.
- Record artifact file state, partition directory state, log state, and whether a fresh R/AppDriver session was used before each run.
- Do not blend `cold_artifact`, `warm_partition_disk`, and `warm_session` rows into one median.

Optimization guardrails:
- Select exactly one first optimization branch from the startup probe evidence.
- If Branch A lazy gating is selected, start with the smallest proven non-active output surface rather than gating every tab at once.
- If Branch C type-choice work is selected, avoid repeating the rejected in-memory type-choice branch from Step 9 unless a local falsification check preserves hierarchy resolution and final selected path.
- Do not proceed to Branch D artifact/load narrowing while non-active output execution, mount/paint gap, or Current-vs-Average churn remains a larger unexplained target.

## Measurement Model and Cache-State Labels

Every startup probe, runtime summary, and benchmark row must identify cache state:

- `cold_artifact`: fresh R session and no warmed partition cache for the target path.
- `warm_partition_disk`: partition files exist but session memory cache is empty.
- `warm_session`: same session and partition memory cache already hit.
- `unknown_cache_state`: only allowed for legacy baseline rows or explicitly documented harness/cache-state uncertainty where the evidence is used for target selection rather than final before/after proof.

Required state fields for the startup probe where practical:
- `cache_state`.
- `artifact_path` and artifact existence/mtime/size.
- Partition directory existence, file count, and whether files were preserved or cleared.
- Log directory state and probe-window runtime log candidates.
- R process id and app/probe label.
- Requested runtime log path.
- Exact fallback runtime log paths or a ready-to-copy `--input=...` string.

## Smoke and Harness Strategy

Primary gate: one-shot segmented Shiny startup probe.
- New file: `VP Clone/System/Testing/vp_perf_probe_startup.R`.
- The probe performs one narrow action family: app launch through first useful `Current vs. Average` settlement.
- The probe writes one raw CSV row plus runtime PERF logs where available.
- The probe exits after the segment; no 3-run loop initially.
- The probe uses bounded staged waits, DOM/control/output checks, and JavaScript reads rather than relying only on full Shiny idle.
- The probe records partial evidence on timeout or failure.

Required startup probe milestones and fields:
- Probe start and end timestamp.
- AppDriver start and end.
- Startup wait elapsed/status.
- Initial `main_tabs_panel` value.
- Whether the app already landed on `Current vs. Average`.
- Timed switch to `Current vs. Average` if needed.
- `startup_to_ready_ms` and `tab_switch_to_current_vs_average_ms` separately.
- `client_perf_main_tabs_mount`, `client_perf_tab_after_paint`, `client_perf_tab_shown`, and `client_perf_main_tabs_profile` records from runtime logs.
- Comparison primary output presence/visibility, likely `comparison_plot` after technical confirmation.
- Key controls present.
- Final selected tab/source state.
- Requested runtime log path and fallback runtime log candidates.
- Cache-state label and final status.

Runtime log fallback requirements:
- Record probe start/end timestamps.
- List recent `vp_runtime_perf_proc_*.jsonl` and session runtime logs modified during the probe window.
- Write likely fallback paths into the CSV when practical.
- Print a ready-to-copy summarizer argument such as `VP_PERF_STARTUP_FALLBACK_INPUT=path1|path2`.
- Use `VP Clone/System/Testing/vp_perf_summarize_runtime_logs.R --input=...` with exact fallback paths when the requested runtime JSONL does not materialize.

Secondary validation:
- Reintroduce multi-run medians only after the one-shot startup probe completes reliably below timeout.
- Run three repetitions for the narrow startup probe only after single-run stability, not the full app path.
- Full-path 3-run smoke remains a late confirmation gate after major wins.

## Step Ledger

| Step | Phase | Work | Status | Evidence / Files | Gate / Next Action |
|---|---|---|---|---|---|
| 1 | A | Create daughter source-of-truth plan | Complete | Added this file before Step 10 probe or app-code edits. | Parent plan must delegate Step 10 here before implementation begins. |
| 2 | A | Amend parent plan for Step 10 delegation | Complete | Parent Step 10 is `Delegated / in progress`, references this daughter plan, and Tranche L records the handoff and guardrails. | Run markdown/trailing-whitespace validation for parent and daughter plan. |
| 3 | A/B | Validate handoff markdown | Complete | `get_errors` reported no diagnostics for parent and daughter markdown. Parent `git diff --check` passed. Custom parent-plus-daughter trailing-whitespace check marker: `TRAILING_WHITESPACE_OK_STEP10_HANDOFF`. | Proceed to focused technical read before writing the startup probe. |
| 4 | B | Complete focused technical read | Complete (initial) | Confirmed `comparison_plot` in `04_comparison_plots.R` uses `is_current_vs_average_output_active()` plus skip/execute counters. Confirmed `timeseries_plot` and `heatmap_plot` in `05_trend_and_heatmap.R` are likely Branch A suspects because they record execute counters without an equivalent active-tab guard at render entry. Confirmed startup probe should reuse `vp_perf_probe_hierarchy_transition.R` helper patterns. | Create `vp_perf_probe_startup.R` before app-code optimization. |
| 5 | C | Create startup-to-current probe | Complete (initial) | Added `VP Clone/System/Testing/vp_perf_probe_startup.R`. Validation markers: no diagnostics, `PARSE_OK_VP_STARTUP_SETTLE_PROBE`, and `TRAILING_WHITESPACE_OK_VP_STARTUP_PROBE`. | Run baseline startup-to-current probe and summarize logs. |
| 6 | C | Run baseline startup-to-current probe | Complete (initial) | First run exposed a probe tab-read defect; fixed active-tab fallback. Passing baseline label `step10_startup_current_settle_baseline_tab_fallback` produced PASS CSV and exact runtime summary outputs. | Use baseline evidence for branch selection. |
| 7 | D | Choose first optimization branch | Complete (initial) | Baseline does not support Branch A for `timeseries_plot` / `heatmap_plot`; neither executed in the summary. Branch C churn is present but not dominant. Mount-to-paint gap is about 22ms, so Branch B is not the first target. Startup artifact/load remains the largest actionable branch, but requires an explicit Branch D technical-read amendment before app-code edits. | Do Branch D technical read/amendment before any artifact/load implementation. |
| 8 | E | Implement smallest measured patch | Complete | Probe-only Branch D decomposition, serialization/shape A/B, and companion-contract investigation completed the measured patch decision gate without an app-code semantic edit. Evidence files: `step10_branch_d_artifact_load_decomposition`, `step10_branch_d_serialization_shape_ab`, and `step10_branch_d_companion_contract_probe`. Branch D is deferred because a separate narrowed startup companion would be complex, narrow in benefit, and unsafe as a full Provider v3 replacement. | Move to Step 9 closeout. Recommended next parent-plan target is Branch C display/type/filter churn reduction, starting with display-month mapping and then type-choice generation. |
| 9 | F | Close daughter and update parent | Complete | Step 8 decision recorded: enough evidence exists to choose Branch C next and defer the narrowed startup object. Daughter Summary completed and parent plan updated with Step 10 closeout / Branch C handoff. | Recenter future work on the parent plan. |

## Phase Plan

Phase A: Handoff setup
- Create this daughter plan.
- Amend the parent plan to delegate Step 10 here.
- Validate markdown handoff.

Phase B: Baseline and technical read
- Seed evidence from parent Tranche K and Step 9 closeout.
- Confirm durable startup/tab probes do not exist and `_tmp_startup_probe.R` is only a remnant.
- Read only the nearby startup, tab, Current-vs-Average, type-choice, and non-active output surfaces needed to implement the probe safely.

Phase C: Probe gate
- Create `vp_perf_probe_startup.R` from the proven segmented Shiny probe pattern.
- Parse validate the probe.
- Run one baseline startup-to-current probe with explicit cache-state labeling.
- Summarize exact runtime logs, using deterministic fallback discovery when needed.
- Update this daughter plan before optimization.

Phase D: Decision gate
- Select exactly one first optimization branch from probe evidence.
- Reject unmeasured broad artifact/load work, provider-disk retreads, and loading polish.

Phase E: Measured optimization
- Make the smallest app-code edit for the selected branch.
- Validate immediately after the first substantive app-code edit.
- Update this plan after each tranche.

Phase F: Closeout
- Run final focused validations and targeted manual sanity.
- Complete this plan's Summary.
- Update parent Step 10 and tranche notes.
- Recenter future work on the parent plan.

## Candidate Branches

Branch A: Lazy non-active tab/output gating.
- Select if runtime logs show non-active tab render functions, output executions, or client paint events during first `Current vs. Average` settlement.
- Priority suspects from the current technical read are `timeseries_plot` and `heatmap_plot` in `VP Clone/Programs/app_source/server/05_trend_and_heatmap.R`, but the startup probe must confirm before edits.
- Gate heavy render functions by active tab and required inputs while preserving behavior when those tabs are selected.
- Add or preserve runtime instrumentation that proves skip vs execute behavior, such as `record_cache_body_execution(session, "<output>_gated_skip")` and `record_cache_body_execution(session, "<output>_executed")` where consistent with local style.

Branch B: Current-vs-Average first-paint deferral.
- Select if Current-vs-Average itself performs secondary output work before primary controls and the primary visible comparison output are useful.
- The likely primary gate is required controls plus `comparison_plot`, but the technical read must confirm actual primary and secondary output ids before any deferral edit.
- Reuse the existing `is_current_vs_average_output_active()` gating pattern in `VP Clone/Programs/app_source/server/04_comparison_plots.R` where appropriate.
- Do not add user-facing loading polish.

Branch C: Remaining display/type/filter churn reduction.
- Select if `display_month_mapping`, `type_choice_base_values`, `filter_vp_rows_for_resolved_hierarchy_type_choice_base_values`, or `filtered_data` dominate after startup/mount separation.
- Prefer local shared context reuse, choice-only helper specialization, or call-site de-duplication in the owning server/UI helper path.
- Preserve provider v3 behavior and existing purpose-specific churn counters for before/after evidence.
- If `type_choice_base_values` appears in the top-5 churn list during startup settlement, explicitly investigate whether choice generation can avoid full hierarchy-row filtering or be isolated from core first-paint work.

Branch D: Startup artifact/load narrowing.
- Select only if the probe proves artifact read remains the user-visible blocker after eager tab/output work and Current-vs-Average churn have been separated.
- Treat as a broader Step 12-adjacent branch requiring explicit plan amendment before data-format, artifact-shape, lazy-load, or narrowed-artifact rewrites.
- Do not proceed while client mount/paint gap, non-active output execution, or Current-vs-Average churn remains a larger unexplained target.

Rejected immediate branches:
- Another provider-disk tranche.
- Broad artifact format rewrite before probe separation.
- UI loading polish, spinners, progress copy, or cosmetic wait states.
- Full-path repeated shinytest smoke as the primary gate.
- Tuning `_tmp_startup_probe.R` as a durable harness.

## Branch D Technical-Read Amendment

Branch D is selected as the next investigation branch from the first startup baseline, but not yet as an app-code rewrite. The evidence supports artifact/load narrowing because:
- `startup_init(load_vp_trade_monthly_data): artifact_read` remains 14.1105s in the focused startup baseline.
- `startup_init(load_vp_trade_monthly_data)` totals 14.4944s, so the direct artifact read dominates that loader.
- `startup_init(total_pre_ui)` is 19.0984s, and client `main_tabs_mount` / `tab_after_paint` are about 20s from browser page-load timing.
- The mount-to-paint gap is about 22ms, which does not support first-paint deferral as the first patch.
- The exact startup summary does not show `timeseries_plot_executed` or `heatmap_plot_executed`, so the first lazy-gating target is not proven.
- Current-vs-Average churn is present but materially smaller than artifact/load time in this startup path.

Technical read findings:
- `global.R` loads `rice_data_vp_trade_monthly` with `load_startup_dataset_for_source(...)` using tag `startup_init(load_vp_trade_monthly_data)` and artifact path `vp_trade_monthly_prepped_path`.
- `load_startup_dataset_for_source()` delegates enabled sources to `load_processed_or_csv_dataset()`.
- `load_processed_or_csv_dataset()` calls `read_processed_artifact_with_status()` from `shared_source_harmonization_utils.R`, records currentity fields, logs the total loader time, and returns the processed artifact.
- `read_processed_artifact_with_status()` separately logs currentity checking and `artifact_read`; the baseline shows currentity is small compared with the full `readRDS()`.
- After load, startup validates the VP rollup contract, marks `rice_data_vp_trade_monthly` as the canonical Provider v3 source, builds partition source identity, and later includes VP artifact signatures in cache-data-version setup.
- Many server paths still expect the full in-memory `rice_data_vp_trade_monthly` data frame, including provider v3 reconstruction and Current-vs-Average VP filtering. A lazy full-artifact rewrite would therefore be high blast radius.

Branch D first implementation gate:
- Do not start by changing app startup semantics.
- First create or extend a direct non-Shiny artifact/load probe, likely `VP Clone/System/Testing/vp_perf_probe_artifact_load.R`, to decompose the VP startup load path outside Shiny.
- Required decomposition timings:
  - Currentity check for `vp_trade_monthly_pre.rds`.
  - Full `readRDS()` artifact read.
  - `validate_vp_trade_rollup_contract()`.
  - `vp_partition_mark_canonical_source()` / source identity creation.
  - `build_file_signature(vp_trade_monthly_prepped_path)` and any repeated startup cache-version signature work that can be isolated safely.
- Required output fields:
  - Cache-state label.
  - Artifact path, size, mtime, rows, columns, object size.
  - Step-level elapsed milliseconds.
  - Total elapsed milliseconds.
  - R process id and run label.
  - Status and error message.
- Optional A/B branches only after decomposition works:
  - Base R uncompressed RDS test in a temporary/generated probe path, recording write time, read time, file size, and cleanup status.
  - Alternative serialization/package availability check only if the package is already available or explicitly added through a measured dependency decision.
  - Narrow companion artifact or metadata artifact experiment only after direct evidence identifies exactly which startup consumers need less than the full data frame.
- Rejected for the first Branch D edit:
  - Replacing `rice_data_vp_trade_monthly` with a lazy object in app startup.
  - Changing Provider v3 source identity or row-index reconstruction semantics.
  - Broadly splitting the VP artifact without a direct probe proving the required startup subset and validation contract.
  - Shipping a larger uncompressed artifact unless the A/B result shows a meaningful startup win and the file-size tradeoff is explicitly accepted in this plan.

Branch D decomposition evidence:
- Extended direct non-Shiny probe: `VP Clone/System/Testing/vp_perf_probe_artifact_load.R`.
- Probe label: `step10_branch_d_artifact_load_decomposition`.
- Cache-state label: `warm_partition_disk`.
- Probe CSV: `VP Clone/Logs/vp_perf_probe_artifact_load_step10_branch_d_artifact_load_decomposition_20260729T213800Z.csv`.
- Result: `PASS`.
- Artifact: `VP Clone/System/Processed Data/vp_trade_monthly_pre.rds`, 167.0 MB on disk, 2,115,868 rows, 59 columns, 847.8 MB in memory.
- Source: `VP Clone/Input/veg-trade-data.csv`, 95.7 MB on disk.
- Currentity check: 378ms, `currentity_current = TRUE`, reason `current`.
- `readRDS()` artifact read: 11,995ms.
- Probe-only rollup contract validation mirror: 1,330ms.
- Probe-only canonical Provider v3 source marking/source identity mirror: 955ms.
- Artifact/source/metadata signature sample after currentity and marking warmed signature cache: 3ms / 4ms / 4ms; combined sample 11ms.
- Total direct decomposed path: 15,456ms.

Interpretation:
- The dominant direct cost is still full `readRDS()` of the 167 MB compressed artifact into an 848 MB data frame.
- Currentity and signature/cache-version work are small in this warm-signature direct run and are not the first app-code target.
- Contract validation and canonical marking are measurable but secondary; together they account for about 2.3s and should be preserved unless a later, narrower contract-safe strategy proves they can be avoided or moved.
- The next Branch D probe should compare serialization/artifact-shape options in generated temporary artifacts before changing startup semantics. Candidate first A/B: save/read an uncompressed or lower-compression RDS copy in a disposable probe path, record write time, read time, file size, cleanup status, and explicit file-size tradeoff.
- App startup semantics remain unchanged; this tranche touched only the testing probe and this plan.

Branch D serialization/artifact-shape A/B evidence:
- Extended direct non-Shiny probe: `VP Clone/System/Testing/vp_perf_probe_artifact_load.R` with opt-in `--serialization-ab=true` mode.
- Probe label: `step10_branch_d_serialization_shape_ab`.
- Cache-state label: `warm_partition_disk`.
- Probe CSV: `VP Clone/Logs/vp_perf_probe_artifact_load_step10_branch_d_serialization_shape_ab_20260729T214207Z.csv`.
- Disposable output root: `VP Clone/Logs/vp_perf_artifact_serialization_ab_disposable`; generated variant files were removed after timing.
- Result: `PASS` for all variants.
- Existing current compressed artifact:
  - File size: 167.0 MB.
  - Read time in this run: 17,661ms.
  - Shape: 2,115,868 rows, 59 columns, 847.8 MB in memory.
- Full uncompressed RDS variant:
  - Disposable write time: 21,834ms.
  - Read time: 12,918ms.
  - File size: 1,604.2 MB, about 9.61x the current artifact.
  - Read speedup vs current compressed baseline in this run: about 1.37x.
  - Cleanup status: removed.
- Narrow default-column uncompressed shape variant:
  - Disposable write time: 14,707ms.
  - Read time: 5,288ms.
  - File size: 622.0 MB, about 3.72x the current artifact.
  - Shape: 2,115,868 rows, 17 columns, 250.2 MB in memory.
  - Read speedup vs current compressed baseline in this run: about 3.34x.
  - Cleanup status: removed.

Interpretation:
- Full uncompressed serialization is measurable but not compelling as a first app-code patch: it saves about 4.7s of read time in this run but increases disk footprint by about 1.44 GB and would still leave a large startup read.
- The narrow-shape result is the better signal, but it is probe-only evidence. It proves that row count plus column width materially affects read time and in-memory size; it does not prove a safe app artifact because the app currently expects the full `rice_data_vp_trade_monthly` contract.
- The next Branch D investigation should define the minimum contract-safe startup companion artifact and identify exact startup consumers before writing or loading any narrowed artifact in app startup.
- App startup semantics remain unchanged; this tranche touched only the testing probe and this plan.

Branch D narrowed startup companion contract evidence:
- Extended direct non-Shiny probe: `VP Clone/System/Testing/vp_perf_probe_artifact_load.R` with opt-in `--companion-contract=true` mode.
- Probe label: `step10_branch_d_companion_contract_probe`.
- Cache-state label: `warm_partition_disk`.
- Probe CSV: `VP Clone/Logs/vp_perf_probe_artifact_load_step10_branch_d_companion_contract_probe_20260729T214751Z.csv`.
- Disposable output root: `VP Clone/Logs/vp_perf_artifact_companion_contract_disposable`; generated candidate artifact was removed after timing.
- Result: `PASS`.
- Candidate shape:
  - Full source: 2,115,868 rows, 59 columns, 847.8 MB in memory, current compressed file 167.0 MB.
  - Companion candidate: 2,115,868 rows, 50 columns, 734.6 MB in memory.
  - Omitted columns: `country_source_code`, `market_month`, `market_month_name`, `commodity_key`, `calendar_source_market_year`, `calendar_source_scope`, `calendar_source_months`, `calendar_complete`, and `source_value_unit`.
  - Candidate uncompressed disposable file size: 1,253.3 MB.
- Contract checks:
  - Rollup contract mirror: `PASS`.
  - Missing global Census/internal contract columns: none.
  - Missing rollup contract columns: none.
  - Missing Current-vs-Average smoke columns: none.
  - Missing display-month columns: none.
  - Missing quantity-context columns: none.
  - Display-month mapping smoke produced 12 rows.
  - Current-vs-Average default smoke passed with 24,291 filtered rows, recent year 2026, and 11 periods.
  - Read-back check matched candidate row/column shape: 2,115,868 rows and 50 columns.
- Timing:
  - Full current baseline `readRDS()` in this same run: 14,928ms.
  - Candidate disposable write time: 16,643ms.
  - Candidate uncompressed read time: 9,600ms.
  - Candidate read speedup vs full current baseline in this run: about 1.56x.
  - Cleanup status: removed.
- Provider/source identity check:
  - `provider_full_replacement_safe = FALSE`.
  - Reason: `source_identity_changes_expected_for_companion`.
  - Interpretation: the narrowed artifact should not replace `rice_data_vp_trade_monthly` as the full canonical Provider v3 source. Any app patch must load it as a separate startup companion object or explicitly adjust consumer contracts while preserving full-artifact Provider v3 identity and fallback behavior.

Interpretation:
- The earlier 17-column narrow A/B was useful as a lower-bound shape experiment, but it was not contract-safe.
- A contract-safe startup companion candidate is much wider at 50 columns, reducing memory from about 848 MB to about 735 MB and improving same-process read time from about 14.9s to 9.6s when uncompressed.
- The gain is real but smaller than the toy narrow shape; the next patch decision should weigh the 5.3s direct-read improvement against adding a separate companion artifact, loader, manifest/currentity path, and consumer routing.
- Because Provider v3 canonical source identity includes the full source column hash/count/fingerprint, a narrowed companion is safer as an auxiliary first-view/startup object than as a replacement for the full source.
- App startup semantics remain unchanged; this tranche touched only the testing probe and this plan.

## Verification and Validation Targets

Markdown validation:
- `git diff --check -- "VP Clone/Code Review/2026-07-29_vp_performance_hotspot_recovery_plan.md" "VP Clone/Code Review/2026-07-29_vp_startup_current_vs_average_settling_plan.md"` after parent delegation.
- Additional trailing-whitespace check for the untracked daughter file until git tracks it.

Probe parse validation:
- Use `C:\Program Files\R\R-4.5.1\bin\Rscript.exe`.
- Wrap `parse(file=...)` in `invisible(...)`.
- Emit a grepable marker such as `PARSE_OK_VP_STARTUP_SETTLE_PROBE`.

Startup probe validation:
- One-shot startup-to-current probe with explicit label and cache-state row.
- Deterministic CSV output under `VP Clone/Logs`.
- No fatal dependency on full Shiny idle.
- No high-latency `app$get_values()` final-state dependency.
- Runtime summary with `vp_perf_summarize_runtime_logs.R`; use exact `--input=` paths if requested runtime log file is missing, preferably from the probe-emitted fallback input string.

Post-patch validation:
- Parse check for every touched R file.
- Rerun the same startup-to-current probe and runtime summarizer.
- Compare startup artifact read, `client_perf_main_tabs_mount`, `client_perf_tab_after_paint`, `client_perf_tab_shown`, Current-vs-Average milestone timing, non-active output activity, `display_month_mapping`, `type_choice_base_values`, `filtered_data`, and provider partition summaries.
- Manual sanity for Current vs. Average first-load behavior and any gated tabs affected by lazy output gating, especially Historical Trend and Heatmap if Branch A touches them.

## Bugs, Blockers, Failed Attempts, Rejected Approaches

Known blockers and risks:
- Shiny session instability remains the main harness blocker. Control it with defensive JavaScript reads, bounded waits, stage markers, partial evidence, and avoiding `app$get_values()` during slow windows.
- Requested runtime log paths may not materialize. Control it with deterministic probe-window fallback log discovery and exact `--input=` summarization.
- Artifact read dominance can blur the optimization signal. Control it by separating artifact/load, AppDriver startup, client mount/paint, tab switch, and output settlement milestones instead of relying on one total elapsed time.
- Source-dependent tab normalization can blur startup and tab-switch timing. Control it by recording initial tab and timing any explicit switch to `Current vs. Average` separately.
- Cache-state ambiguity can invalidate comparisons. Control it by recording artifact, partition, session, and log state before each probe and never blending `cold_artifact`, `warm_partition_disk`, and `warm_session` rows into one median.
- Lazy gating can regress non-active tabs if validation only checks Current vs. Average. Control it with targeted manual sanity for every gated tab and runtime evidence that gated outputs execute when their tab is selected.
- Windows/R risk: PowerShell inline `Rscript -e` commands with `$` are fragile; prefer short temporary R scripts for complex validation commands.

Rejected as first response:
- Another provider-disk tranche; Step 9 reduced provider disk-cache time to under 1 second.
- Broad artifact format rewrite before separating startup read time from first-tab eager work.
- User-facing loading polish as a substitute for reducing the pause.
- Full-path repeated shinytest smoke as the primary gate while startup/settling remains slow.
- Continuing to tune `_tmp_startup_probe.R` as the durable probe.

## Tranche Execution Notes

- 2026-07-29 Tranche A (daughter plan creation):
  - Created this daughter source-of-truth plan for parent Step 10 before probe or app-code edits.
  - Incorporated accepted audit recommendations from the pre-handoff plan review:
    - Durable startup/tab probes do not currently exist and `vp_perf_probe_startup.R` must be created.
    - `_tmp_startup_probe.R` is only a remnant/selector hint and should not define the durable harness pattern.
    - Startup probe must copy the successful segmented/defensive pattern from `vp_perf_probe_hierarchy_transition.R`.
    - Runtime fallback log discovery must be deterministic and produce exact `--input=...` evidence for the summarizer.
    - Initial landing tab and explicit `Current vs. Average` navigation must be timed separately.
    - Cache-state language must distinguish artifact/session warmth from partition-cache warmth.
    - Lazy-gating and first-paint branches require concrete runtime evidence, not just a slow total elapsed time.
  - No probe or app-code edits have been made under this daughter plan yet.

- 2026-07-29 Tranche B (parent delegation):
  - Updated parent plan `VP Clone/Code Review/2026-07-29_vp_performance_hotspot_recovery_plan.md` to delegate Step 10 here.
  - Parent Step 10 is now `Delegated / in progress` and names this daughter plan as the detailed implementation owner.
  - Parent Tranche L records the handoff, startup probe requirements, cache-state requirements, client PERF comparison requirements, candidate branches, and rejected immediate branches.
  - No probe or app-code edits have been made under this daughter plan yet.

- 2026-07-29 Tranche C (handoff validation and technical-read start):
  - Handoff validation passed for the parent and daughter markdown files:
    - `get_errors` reported no diagnostics for both plans.
    - Parent tracked diff whitespace check passed: `git diff --check -- "VP Clone/Code Review/2026-07-29_vp_performance_hotspot_recovery_plan.md"` produced no output.
    - Parent-plus-daughter trailing-whitespace marker: `TRAILING_WHITESPACE_OK_STEP10_HANDOFF`.
  - Step 4 focused technical read is now in progress.
  - No probe or app-code edits have been made under this daughter plan yet.

- 2026-07-29 Tranche D (focused technical read):
  - Read the established segmented Shiny probe `VP Clone/System/Testing/vp_perf_probe_hierarchy_transition.R` and will reuse its successful harness patterns for the startup probe:
    - `STAGE_BEGIN` / `STAGE_END` console markers.
    - `NOT_CRAN=true` before `AppDriver$new()`.
    - Event-only runtime PERF memory mode.
    - Defensive JavaScript DOM/input reads.
    - Bounded staged waits and partial evidence on failure.
  - Confirmed Current-vs-Average primary output surface:
    - `VP Clone/Programs/app_source/server/04_comparison_plots.R` defines `is_current_vs_average_output_active()`.
    - `output$comparison_plot` already gates on that helper and records `comparison_plot_gated_skip` / `comparison_plot_executed` counters.
  - Confirmed likely non-active Branch A suspects:
    - `output$timeseries_plot` in `VP Clone/Programs/app_source/server/05_trend_and_heatmap.R` records `timeseries_plot_executed` at render entry and then calls `filtered_data()`.
    - `output$heatmap_plot` records `heatmap_plot_executed` at render entry and then calls `filtered_data()` plus display month/year helpers.
    - These are not optimization decisions yet; the startup probe must confirm whether they execute during first `Current vs. Average` settlement.
  - No app-code optimization edits have been made under this daughter plan yet.

- 2026-07-29 Tranche E (startup probe creation):
  - Added focused startup-to-Current-vs-Average probe: `VP Clone/System/Testing/vp_perf_probe_startup.R`.
  - Probe design follows the accepted Step 10 guardrails:
    - Standalone one-shot `shinytest2` harness.
    - `NOT_CRAN=true` before `AppDriver$new()`.
    - Event-only runtime PERF memory mode.
    - `STAGE_BEGIN` / `STAGE_END` markers around app start, startup wait, required controls, initial state, optional tab selection, output wait, final state, and app stop.
    - Defensive JavaScript DOM/input/output reads instead of final-state `app$get_values()`.
    - Separate `startup_to_ready_ms`, `tab_switch_to_current_vs_average_ms`, and `comparison_plot_visible_ms` fields.
    - Artifact, partition, runtime-log, fallback-log, client PERF, and output visibility fields in the CSV row.
    - Deterministic fallback runtime-log candidate discovery and `VP_PERF_STARTUP_FALLBACK_INPUT=...` console output.
  - Validation passed:
    - `get_errors` reported no diagnostics for the new probe file.
    - Parse marker: `PARSE_OK_VP_STARTUP_SETTLE_PROBE`.
    - Whitespace marker: `TRAILING_WHITESPACE_OK_VP_STARTUP_PROBE`.
  - No app-code optimization edits have been made under this daughter plan yet.

- 2026-07-29 Tranche F (startup baseline probe and branch interpretation):
  - First startup probe execution:
    - Command label: `step10_startup_current_settle_baseline`.
    - Cache state: `warm_partition_disk`.
    - Probe CSV: `VP Clone/Logs/vp_perf_probe_startup_step10_startup_current_settle_baseline_20260729T212850Z.csv`.
    - Result: `FAIL`, but with useful partial evidence.
    - Failure reason: `comparison_plot` was visible, but `main_tabs_panel` read as `NA`; the probe treated final tab as not target.
    - Interpretation: harness defect, not app-path failure. The hidden tab input was not a reliable tab-state source in this window.
  - Probe hardening after failed first run:
    - Added `get_main_tab_value()` with active nav/data-value/text fallback for `main_tabs_panel` reads.
    - Switched initial/final tab reads and tab-selection wait predicate to the fallback helper.
    - Parse marker: `PARSE_OK_VP_STARTUP_SETTLE_PROBE_TAB_FALLBACK`.
  - Passing startup probe execution:
    - Command label: `step10_startup_current_settle_baseline_tab_fallback`.
    - Cache state: `warm_partition_disk`.
    - Probe CSV: `VP Clone/Logs/vp_perf_probe_startup_step10_startup_current_settle_baseline_tab_fallback_20260729T213127Z.csv`.
    - Result: `PASS`.
    - Requested runtime log path did not materialize, continuing the known forced-path caveat.
    - Exact fallback runtime logs summarized:
      - `VP Clone/Logs/vp_runtime_perf_bb308b9fb662428d9fbdb0386f1ab085.jsonl`.
      - `VP Clone/Logs/vp_runtime_perf_proc_20260729T213130Z_27612.jsonl`.
    - Runtime summary outputs: `VP Clone/Logs/vp_perf_runtime_summary_step10_startup_current_settle_baseline_tab_fallback_20260729T213258Z_*.csv`.
  - Passing probe CSV evidence:
    - `startup_to_ready_ms`: 83,387.
    - `tab_switch_to_current_vs_average_ms`: 0; initial and final tab were both `Current vs. Average`.
    - `comparison_plot_visible_ms`: 31.
    - `total_probe_ms`: 83,996.
    - Initial/final source: `vp_trade`.
    - `comparison_plot_present = TRUE`, `comparison_plot_visible = TRUE`.
    - `timeseries_plot_present = TRUE`, `timeseries_plot_visible = FALSE`.
    - `heatmap_plot_present = TRUE`, `heatmap_plot_visible = FALSE`.
    - Client PERF fields in the probe row: `main_tabs_mount` 19,980ms and `tab_after_paint` 20,002ms, both on `Current vs. Average`.
  - Runtime summary evidence:
    - Runtime summary read 2 files / 191 records.
    - Top timed buckets:
      - `client_perf tab_after_paint`: 20.002s.
      - `client_perf main_tabs_mount`: 19.980s.
      - `startup_init(total_pre_ui)`: 19.0984s.
      - `startup_init(load_vp_trade_monthly_data)`: 14.4944s.
      - `startup_init(load_vp_trade_monthly_data): artifact_read`: 14.1105s.
    - Other timed buckets:
      - `filter_vp_rows_for_resolved_hierarchy()`: 18 calls / 1.3773s.
      - `summary_table`: 2 timed calls / 0.5929s.
      - `output$main_tabs`: 3 timed calls / 0.4351s.
      - Provider disk-cache: 1 call / 0.2438s.
      - Provider memory-cache: 17 calls / 0.1008s.
    - Top churn:
      - `filter_vp_rows_for_resolved_hierarchy_display_month_mapping`: 9.
      - `summary_table_executed`: 5.
      - `map_bottom_panel_ui_gated_skip`: 4.
      - `filter_vp_rows_for_resolved_hierarchy_filtered_data`: 3.
      - `filter_vp_rows_for_resolved_hierarchy_type_choice_base_values`: 2.
    - Key deltas were low volume: two `map_runtime_source_cache_key` rows and one each for mixed-volume and type-choice helper keys.
  - Branch interpretation:
    - Branch A lazy gating for `timeseries_plot` / `heatmap_plot` is not supported by this baseline. Search of the exact startup summary did not find `timeseries_plot_executed` or `heatmap_plot_executed`.
    - Branch B first-paint deferral is not supported as the first target by this baseline: `main_tabs_mount` 19.980s and `tab_after_paint` 20.002s differ by only about 22ms.
    - Branch C remaining display/type/filter churn is present but not dominant in this startup path: total hierarchy-filter time is 1.3773s, and top helper churn is much lower than in the earlier hierarchy-transition path.
    - Branch D startup artifact/load narrowing is now the evidence-backed next investigation branch, but app-code implementation must wait for an explicit Branch D technical-read amendment because artifact/load work is broader than output gating or local churn reduction.
  - Probe bookkeeping follow-up:
    - The passing probe row reported `partition_file_count = 0` because the first helper counted only top-level files, while partition files are nested by provider/artifact version.
    - Fixed `safe_dir_file_count()` to count recursively for future startup probe rows.
    - Parse marker after this bookkeeping fix: `PARSE_OK_VP_STARTUP_SETTLE_PROBE_RECURSIVE_PARTITION_COUNT`.
  - No app-code optimization edits have been made under this daughter plan yet.

- 2026-07-29 Tranche G (Branch D technical-read amendment):
  - Completed a focused read of the VP startup load path before artifact/load implementation.
  - Controlling path:
    - `global.R` calls `load_startup_dataset_for_source(...)` for `rice_data_vp_trade_monthly` with tag `startup_init(load_vp_trade_monthly_data)`.
    - `load_startup_dataset_for_source()` delegates to `load_processed_or_csv_dataset()` for enabled sources.
    - `load_processed_or_csv_dataset()` calls `read_processed_artifact_with_status()`.
    - `read_processed_artifact_with_status()` separately logs currentity check and `artifact_read` around `readRDS()`.
  - Post-load startup work includes VP rollup contract validation, canonical Provider v3 source identity marking, partition source signature behavior, and cache-data-version signature work.
  - Decision:
    - Branch D is selected only as the next investigation branch.
    - The first Branch D implementation gate must be a direct non-Shiny artifact/load decomposition probe, not an app startup semantic rewrite.
    - App-code optimization remains blocked until decomposition evidence identifies a small, safe, measurable change.
  - No app-code optimization edits have been made under this daughter plan yet.

- 2026-07-29 Tranche H (Branch D direct artifact/load decomposition probe):
  - Extended `VP Clone/System/Testing/vp_perf_probe_artifact_load.R` instead of changing app startup semantics.
  - Added decomposed direct timings for:
    - Currentity via `diagnose_processed_artifact_currentity()` using the VP raw CSV source path and `builder_version` extra signature.
    - Full `readRDS()` of `vp_trade_monthly_pre.rds`.
    - Probe-only mirror of `validate_vp_trade_rollup_contract()` including required fields, rollup levels, schema version, and builder-version floor check.
    - Probe-only mirror of canonical Provider v3 source marking/source identity creation.
    - Artifact/source/metadata signature samples to represent cache-version signature work that can be isolated safely.
  - Added output fields for process id, source artifact state, currentity status/reason, step-level milliseconds, total milliseconds, signature prefixes, and marked object size.
  - Validation passed:
    - `get_errors` reported no diagnostics for `VP Clone/System/Testing/vp_perf_probe_artifact_load.R`.
    - Parse marker after helper edit: `PARSE_OK_VP_ARTIFACT_LOAD_DECOMPOSE_HELPERS`.
    - Parse marker after option wiring: `PARSE_OK_VP_ARTIFACT_LOAD_DECOMPOSE_WIRED`.
  - Probe execution passed:
    - Command label: `step10_branch_d_artifact_load_decomposition`.
    - Cache state: `warm_partition_disk`.
    - Probe CSV: `VP Clone/Logs/vp_perf_probe_artifact_load_step10_branch_d_artifact_load_decomposition_20260729T213800Z.csv`.
    - Total direct decomposed path: 15,456ms.
    - Currentity: 378ms and current.
    - `readRDS()`: 11,995ms.
    - Contract validation mirror: 1,330ms.
    - Canonical source marking/source identity mirror: 955ms.
    - Signature/cache-version sample: 11ms after cache warming from currentity/marking.
  - Interpretation:
    - Full artifact deserialization is the largest direct cost and is the next evidence-backed target.
    - Currentity/signature/cache-version work should not be optimized first based on this run.
    - Contract validation and canonical marking are secondary but non-trivial; preserve them through any artifact strategy unless a later probe proves a contract-safe way to avoid repeated work.
    - Next recommended Branch D action is a probe-only serialization/artifact-shape A/B in disposable output paths before any app startup semantic edit.
  - No app-code optimization edits have been made under this daughter plan yet.

- 2026-07-29 Tranche I (Branch D disposable serialization/artifact-shape A/B probe):
  - Extended `VP Clone/System/Testing/vp_perf_probe_artifact_load.R` with opt-in serialization A/B mode instead of changing app startup semantics.
  - Added CLI options:
    - `--serialization-ab=true` to run the disposable A/B path.
    - `--ab-variants=...` to select variants; default tested variants are `full_uncompressed` and `narrow_uncompressed`, with `existing_current` always included as the baseline row.
    - `--ab-cleanup=true` to remove generated variant files after timing.
    - `--ab-output-root=...` for disposable generated artifacts.
    - `--shape-columns=...` for optional future narrow-shape column overrides.
  - Probe behavior:
    - Reads the current artifact once as the same-process baseline.
    - Writes disposable variants under `VP Clone/Logs/vp_perf_artifact_serialization_ab_disposable`.
    - Times write and read separately.
    - Records file size, file-size ratio vs current artifact, read speedup vs current artifact, rows, columns, object size, cleanup status, and whether variant files remained after cleanup.
    - Removes disposable variant files by default.
  - Validation passed before execution:
    - `get_errors` reported no diagnostics for `VP Clone/System/Testing/vp_perf_probe_artifact_load.R`.
    - Parse marker after helper edit: `PARSE_OK_VP_ARTIFACT_AB_HELPERS`.
    - Parse marker after option wiring: `PARSE_OK_VP_ARTIFACT_AB_WIRED`.
  - Probe execution passed:
    - Command label: `step10_branch_d_serialization_shape_ab`.
    - Cache state: `warm_partition_disk`.
    - Probe CSV: `VP Clone/Logs/vp_perf_probe_artifact_load_step10_branch_d_serialization_shape_ab_20260729T214207Z.csv`.
    - `existing_current`: 167.0 MB, read 17,661ms, 59 columns, 847.8 MB in memory.
    - `full_uncompressed`: write 21,834ms, read 12,918ms, 1,604.2 MB, 9.61x file-size ratio, 1.37x read speedup, cleanup removed.
    - `narrow_uncompressed`: write 14,707ms, read 5,288ms, 622.0 MB, 3.72x file-size ratio, 3.34x read speedup, 17 columns, 250.2 MB in memory, cleanup removed.
  - Interpretation:
    - Full uncompressed serialization alone is probably not a good first app patch because the file-size tradeoff is large relative to the read-time gain.
    - Narrow artifact shape is the stronger evidence-backed direction, but only after a technical read identifies the minimum startup contract and consumers.
    - No app-code optimization edits have been made under this daughter plan yet.

- 2026-07-29 Tranche J (Branch D contract-safe narrowed startup companion investigation):
  - Extended `VP Clone/System/Testing/vp_perf_probe_artifact_load.R` with opt-in companion-contract mode instead of changing app startup semantics.
  - Added CLI options:
    - `--companion-contract=true` to run the narrowed startup companion contract probe.
    - `--companion-output-root=...` for disposable generated companion artifacts.
    - Existing `--ab-cleanup=true` controls whether the generated companion candidate is removed after timing.
    - Existing `--shape-columns=...` can add future candidate columns without changing the probe again.
  - Probe behavior:
    - Reads the current full artifact once as the same-process baseline.
    - Builds a candidate companion column set from global Census/internal metrics, VP rollup contract fields, hierarchy/filter/display columns, country labels, unit-value fields, and unit-family context fields.
    - Checks the probe-only rollup contract mirror, global contract columns, Current-vs-Average smoke columns, display-month mapping columns, and quantity-context columns.
    - Runs a direct display-month mapping smoke and a default Current-vs-Average filtered-data smoke.
    - Computes Provider v3 source identity for the full source and candidate to verify whether the narrowed candidate can safely masquerade as the full canonical source.
    - Writes and reads a disposable uncompressed companion candidate, then removes it by default.
  - First execution failed because the standalone probe was missing `vp_all_type_label`; this was a harness defect, not a contract failure.
  - Fixed the probe-only constant and reran successfully.
  - Validation passed before execution/rerun:
    - `get_errors` reported no diagnostics for `VP Clone/System/Testing/vp_perf_probe_artifact_load.R`.
    - Parse marker after helper edit: `PARSE_OK_VP_COMPANION_CONTRACT_HELPERS`.
    - Parse marker after option wiring: `PARSE_OK_VP_COMPANION_CONTRACT_WIRED`.
    - Parse marker after missing-constant fix: `PARSE_OK_VP_COMPANION_CONTRACT_CONSTANT`.
  - Probe execution passed:
    - Command label: `step10_branch_d_companion_contract_probe`.
    - Cache state: `warm_partition_disk`.
    - Probe CSV: `VP Clone/Logs/vp_perf_probe_artifact_load_step10_branch_d_companion_contract_probe_20260729T214751Z.csv`.
    - Full current baseline read: 14,928ms.
    - Candidate write: 16,643ms.
    - Candidate read: 9,600ms.
    - Candidate read speedup: about 1.56x.
    - Candidate shape: 2,115,868 rows, 50 columns, 734.6 MB in memory, 1,253.3 MB uncompressed disposable file.
    - Contract checks passed with no missing global, rollup, Current-vs-Average smoke, display-month, or quantity-context columns.
    - Provider full replacement safety: `FALSE`, because source identity changes as expected for a narrowed companion.
    - Cleanup status: removed.
  - Interpretation:
    - A contract-safe startup companion is feasible as a separate object, but it is not small enough to justify a blind app startup patch.
    - Replacing `rice_data_vp_trade_monthly` directly would break or bypass Provider v3 canonical source identity assumptions.
    - A future app-code patch would need a new companion artifact role/currentity entry and explicit consumer routing for first-view/startup paths, with fallback to the full artifact for Provider v3 and later full-data consumers.
    - No app-code optimization edits have been made under this daughter plan yet.

- 2026-07-29 Tranche K (Step 8 completion and Step 9 handoff):
  - Decision: Step 8 is complete. The probe-only Branch D work provided enough evidence to choose the next target without shipping an artifact/startup semantic change.
  - Branch D is deferred rather than selected for an app-code patch:
    - Full uncompressed serialization has a poor file-size tradeoff.
    - The 17-column narrow artifact was a useful lower-bound probe but not contract-safe.
    - The contract-safe 50-column companion candidate is feasible but still large, only improves the startup/current-view path, and cannot replace the full Provider v3 canonical source identity.
    - A narrowed startup object would add a new artifact role, currentity/manifest path, loader, consumer routing, and fallback contract for a relatively narrow benefit.
  - Recommended next target: Branch C display/type/filter churn reduction.
    - This branch is expected to improve the app's repeated-use feel beyond first startup.
    - First local target should be VP display-month mapping churn, because it is shared by comparison plots/tables and repeatedly calls through hierarchy filtering.
    - Second target should be type-choice generation only after a local check preserves hierarchy resolution and final selected path.
  - Step 9 is now in progress:
    - Complete this daughter plan's Summary.
    - Update the parent Step 10 outcome and handoff notes.
    - Recenter future work on Branch C in the parent plan.

## Summary

This daughter plan created the Step 10 startup-to-Current-vs-Average evidence base and used it to choose the next target. We added a durable startup probe, hardened it after a tab-state harness failure, ran a passing startup baseline, summarized exact fallback runtime logs, and then decomposed the VP artifact/load path before making any startup semantic change.

The main finding is that startup is still dominated by loading the large VP monthly artifact, but the measured fixes available in that branch are not attractive enough for the next app-code tranche. Full uncompressed serialization reads somewhat faster but creates a very large file. A narrow 17-column probe was fast but not contract-safe. A contract-safe 50-column startup companion candidate worked as a separate object and read faster than the full artifact, but it would add a new artifact role, currentity/manifest path, loader, consumer routing, and fallback contract while helping mostly the first startup/current-view path. It also cannot safely replace the full Provider v3 canonical source because source identity changes.

The chosen handoff is therefore Branch C: reduce VP display/type/filter churn next. That branch is more likely to improve the app's repeated-use feel across source, hierarchy, commodity/type, country, metric, tab, and projection interactions. The first recommended target is VP display-month mapping churn, followed by type-choice generation only after a local check proves hierarchy resolution and selected path remain correct.

Files changed under this daughter plan include the new startup probe, the extended direct artifact/load probe, this plan, and the parent plan handoff. Important validation markers included startup probe parse checks, artifact probe parse checks, `PARSE_OK_VP_ARTIFACT_LOAD_DECOMPOSE_FINAL`, `PARSE_OK_VP_ARTIFACT_SERIALIZATION_AB_FINAL`, `PARSE_OK_VP_COMPANION_CONTRACT_FINAL`, and trailing-whitespace checks for the touched plan/probe files. No app startup semantics were changed, and no user-facing loading polish was added.

Residual risks remain: requested runtime log paths still often do not materialize, startup artifact read remains a large visible cost, and Branch C will not erase the initial artifact-load pause by itself. The next tranche should be scoped as an interaction-feel improvement, not a claim that all startup latency is solved.
