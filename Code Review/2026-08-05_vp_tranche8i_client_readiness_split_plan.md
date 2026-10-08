# VP Tranche 8I Client Readiness Split Plan

Date: 2026-08-05
Status: In progress
Parent Plan: `Code Review/2026-08-03_vp_commodity_partition_sidecar_architecture_plan.md`

## Purpose

This daughter plan defines the Tranche 8I implementation path under the parent architecture plan. The parent remains the source of truth for branch-level decisions; this file is the detailed execution ledger for 8I.

The goal of Tranche 8I is to split the dominant fresh action-window `client_lifecycle + transition_wait + client_wait` mass into a concrete, reversible implementation target before any broad provider/cache/sidecar optimization work.

## Scope

In scope:
1. Read-only decomposition of fresh 8G detail evidence into actionable client/wait sub-families.
2. Marker-provenance refinement only if read-only split cannot separate real client/render work from synthetic waits.
3. One small reversible implementation candidate only after a clear actionability gate is met.
4. Strict validation and exact-path evidence chain before any acceptance claim.

Out of scope:
1. Threshold relaxation.
2. Broad provider/cache/sidecar implementation.
3. Broad hidden-output warming or Plotly brute-force warmups.
4. Production-default behavior changes without explicit evidence and review.

## Parent Rollup Contract

1. This file holds detailed step logs, failed attempts, evidence artifacts, and decision gates.
2. The parent plan receives concise rollups at these gates:
   - daughter plan created,
   - read-only split complete,
   - marker-provenance decision,
   - first implementation candidate selected/rejected,
   - validation/acceptance outcome,
   - final recommendation.

## Baseline Evidence (Immutable Inputs)

Treat these as immutable baseline evidence for 8I; do not overwrite or reinterpret except through newly labeled derivative outputs.

1. `Logs/vp_perf_acceptance_decomposition_tranche8g_off_on_i9_phase3_strict_fresh_20260805T010825Z_runs.csv`
2. `Logs/vp_perf_acceptance_decomposition_tranche8g_off_on_i9_phase3_strict_fresh_20260805T010825Z_summary.csv`
3. `Logs/vp_perf_acceptance_decomposition_tranche8g_off_on_i9_phase3_strict_fresh_20260805T010825Z_detail.csv`
4. `Logs/vp_perf_acceptance_decomposition_tranche8g_off_on_i9_phase3_strict_fresh_20260805T010825Z_window_confidence.csv`
5. `Logs/vp_perf_acceptance_decomposition_tranche8g_off_on_i9_phase3_strict_fresh_20260805T010825Z_inconclusive_gate.csv`
6. `Logs/vp_perf_acceptance_decomposition_tranche8g_off_on_i9_phase3_strict_fresh_rollup_20260805T130922Z_action_bucket.csv`
7. `Logs/vp_perf_acceptance_decomposition_tranche8g_off_on_i9_phase3_strict_fresh_rollup_20260805T130922Z_lane_delta.csv`
8. `Logs/vp_perf_acceptance_decomposition_tranche8g_off_on_i9_phase3_strict_fresh_rollup_20260805T130922Z_lane_confidence.csv`

## Baseline Facts (From Tranche 8G/8H)

1. Mean bucket confidence: `0.999814`.
2. Max unclassified attributed time: `67.9 ms`.
3. Baseline action-window total: `679784.5 ms`.
4. Candidate action-window total: `687072.2 ms`.
5. Candidate delta: `+7287.7 ms` (`-1.07%` improvement).
6. Combined `client_lifecycle + transition_wait + client_wait` share: about `78%`.
7. `provider_filter` share: about `3%`.
8. `tab_server_materialization` share: about `4%`.

## Guardrails

1. No acceptance threshold relaxation.
2. No candidate promotion.
3. No broad provider/cache/sidecar optimization in 8I.
4. No broad hidden-output warming or brute-force Plotly warmups.
5. No production-default behavior changes.
6. No acceptance claims from diagnostic-only instrumentation.
7. No latest-file discovery when exact paths are available.

Strict evidence controls for any replicated cohort/probe evidence:
1. Clean-room manifest.
2. Strict manifest validation.
3. Strict context validation.
4. Strict runtime identity validation.
5. Acceptance-only mode.
6. Deterministic fixtures.
7. Exact runtime-log path binding.
8. Explicit cache-state lane labels.
9. PASS-only evidence for acceptance claims.

## Reopen Criteria

1. Reopen provider/cache work only if client/wait split shows wait time masking server/provider readiness.
2. Reopen hierarchy fanout only if client/wait split shows hierarchy-triggered churn as primary cause.
3. Reopen broad Plotly optimization only if render lifecycle is isolated as dominant actionable sub-bucket.
4. Reopen broad server materialization only if server completion markers dominate after client/wait splitting.
5. Reopen threshold discussion only after a true implementation change plus repeated strict evidence still shows narrow gate misses with high measurement quality.

## Actionability Gate

A client/wait sub-family is actionable only if at least one condition is met:
1. It is at least `25%` of action-window attributed time.
2. It is at least `2x` the runner-up within `client_lifecycle + transition_wait + client_wait`.
3. It appears stably in both baseline and candidate role groups and maps to a concrete ownership surface.

A sub-family is not actionable if:
1. It is mostly synthetic gap allocation with no source ownership.
2. It appears only in one outlier run.
3. It cannot be mapped to client, server-output, render lifecycle, or readiness-signaling ownership.

## Execution Phases

### Phase 0: Plan Setup
1. Keep this daughter file as the detailed ledger.
2. Ensure parent rollup section exists and is current.

### Phase 1: Read-Only Split
1. Run a read-only split over the immutable fresh 8G detail/runs artifacts.
2. Label family: `tranche8i_client_readiness_split_existing_8g`.

Required derivative artifacts:
1. `Logs/vp_perf_client_readiness_split_tranche8i_client_readiness_split_existing_8g_<timestamp>_signature.csv`
2. `Logs/vp_perf_client_readiness_split_tranche8i_client_readiness_split_existing_8g_<timestamp>_gap_context.csv`
3. `Logs/vp_perf_client_readiness_split_tranche8i_client_readiness_split_existing_8g_<timestamp>_role_pair_summary.csv`

Required split dimensions:
1. Top `client_lifecycle` signatures by attributed ms.
2. Top `transition_wait` signatures/gap contexts.
3. Top `client_wait` signatures/gap contexts.
4. Split by `pair_run_label` and `role`.
5. Action-window vs post-visible.
6. OFF broad-source vs ON boundary-source signatures.
7. Wait location: pre-visible, post-visible, server-complete-to-client-visible.

Gate:
1. If actionable dominant sub-family exists, proceed to small implementation or marker edit.
2. If split is still synthetic/non-actionable, go to Phase 2 (marker-provenance only).
3. If no dominant signal exists, log no-decision diagnostic outcome and stop implementation.

### Phase 2: Marker-Provenance (Only If Needed)
1. Instrument only when Phase 1 cannot separate real client/render work from synthetic waits.
2. Target order:
   - `Programs/app_source/ui.R`
   - `Programs/app_source/server/04_comparison_plots.R`
   - `Programs/app_source/server/05_trend_and_heatmap.R`
   - `Programs/app_source/server/02_partner_and_notes.R` (only if ingestion/refinement is needed)
3. Instrumentation must be feature-gated and disabled by default.
4. No UI behavior changes and no broad observer expansion.

Validation after instrumentation:
1. Parse/static checks on touched files.
2. OFF/ON narrow smoke with markers off/on.
3. Exact-path decomposition on smoke outputs.
4. Perturbation check before using marker-on evidence for interpretation.

### Phase 3: One Small Implementation Candidate
1. Choose exactly one reversible implementation candidate after a passed actionability gate.
2. Record explicit hypothesis, expected bucket movement, and rollback condition before editing.
3. Do not combine instrumentation and optimization in one acceptance claim unless marker neutrality is already shown.

### Phase 4: Verification Loop
1. Validate changed code with parse/errors.
2. Run narrow single-action smoke first.
3. If smoke is promising, run strict replicated OFF/ON acceptance pair with unchanged thresholds.
4. Build exact-path evidence chain: index -> inventory -> Step 25B -> Step 25C -> Step 25D -> rollup.
5. Keep startup-ready and interaction-ready claims separate.

### Phase 5: Companion Ownership View
1. Build a companion ownership view over the exact 8I wait-boundary diagnostic cohort before any additional repair attempt.
2. Use the completed strict evidence chain from `tranche8i_wait_boundary_ownership_i9` as the first input cohort.
3. Keep `System/Testing/vp_perf_decompose_single_action_8c.R` attribution rules unchanged in this phase.
4. Join decomposition gaps, runtime boundary markers, and single-action probe timeline columns to identify per-tab ownership of dominant waits.
5. Classify ownership separately for Historical Trend, Heatmap, Map, and Current vs. Average.
6. Required classifications:
   - premature visible boundary / decomposition-boundary-owned,
   - output or Plotly materialization owned,
   - readiness/client-echo owned,
   - server observer/send owned,
   - resize transport/handler owned,
   - guardrail/helper gate suspected,
   - mixed/no-decision.
7. Do not choose another behavior optimization until this view identifies a stable owner or explicitly returns no-decision.

### Phase 6: Guardrail/Helper Inventory And Targeted Diagnostic Pass
1. After the companion ownership view, run a read-only inventory of guards/helper gates that could contribute to lag, churn, retries, skips, stale-state correction, or hidden waits.
2. This inventory is evidence-guided: prioritize surfaces implicated by the ownership view rather than instrumenting broadly.
3. Candidate guardrail/helper families:
   - tab/profile alignment helpers,
   - source-shell mismatch recovery,
   - safe tab selection and retry loops,
   - stale output checks,
   - active-tab mismatch skips,
   - debounce/throttle queues,
   - source-switch epoch staleness checks,
   - hidden/visibility checks,
   - readiness predicates,
   - cache/provider short-circuit or deferral guards,
   - observer guards such as `req(...)`, early `return()`, `ignoreInit`, and source/tab eligibility checks.
4. Inventory output should classify each guard/helper by:
   - file/function/surface,
   - condition evaluated,
   - possible outcomes (`pass`, `skip`, `defer`, `retry`, `recover`, `normalize`, `suppress`),
   - likely affected tab/source/output,
   - existing runtime marker coverage,
   - missing marker fields,
   - expected lag/churn symptom if it is active.
5. Instrument only the highest-leverage guardrails selected from the inventory.
6. Any guardrail instrumentation must be feature-gated behind existing boundary-marker controls and must emit structured fields:
   - guard name,
   - outcome,
   - reason code,
   - tab/source/epoch/action id,
   - target output id when available,
   - attempt/retry count when available,
   - elapsed ms when the guard wraps a wait/retry/defer loop.
7. Validation for guardrail instrumentation must repeat the marker perturbation protocol before using marker-on evidence for interpretation.
8. This phase may propose a repair only after the targeted diagnostic pass maps a guard/helper to a concrete ownership surface and passes perturbation checks.

### Phase 7: Priority Output/Materialization Diagnostic Tranche
1. Run this as a diagnostic-only marker tranche, not an optimization.
2. Mandatory first target: Current vs. Average (`comparison_plot`).
3. Optional same-tranche targets: Historical Trend (`timeseries_plot`) and Map (`map_plot`) only if the shared marker/helper edit is small and does not widen risk materially.
4. Defer Heatmap useful-readiness/boundary markers unless priority-output markers leave the main question unresolved or show the same boundary issue.
5. Falsifiable hypothesis:
   - Current vs. Average wait is dominated by either server-side `comparison_plot` construction or client-side Plotly materialization after Shiny value delivery,
   - it is not primarily resize transport, tab switching, or generic guardrail churn.
6. Measure phase boundaries with bridge markers that connect existing perf/trace infrastructure:
   - server render start,
   - data/reactive inputs resolved,
   - plot object built,
   - server render returned,
   - browser `shiny:value` for target output received,
   - widget inserted,
   - main SVG inserted,
   - Plotly `afterplot`,
   - loading cleared,
   - diagnostic useful-output-ready.
7. Treat clock domains explicitly:
   - server-render internal durations are high-confidence server-clock deltas,
   - browser-to-browser materialization gaps are high-confidence browser-clock deltas,
   - server-to-browser absolute gaps are lower-confidence ordering/provenance evidence unless a same-clock anchor exists.
8. Define join confidence for every ownership claim:
   - exact: target output id + action id/request id,
   - strong: target output id + tab + runtime log/run id + event ordering,
   - weak: timestamp/order only.
9. Do not base a repair decision on weak joins.
10. Preserve existing behavior and lifecycle semantics:
   - no `outputOptions(...)` changes,
   - no hidden-output warming,
   - no `bindCache(...)` changes,
   - no output definition behavior changes,
   - no readiness predicate changes,
   - no decomposition-rule changes,
   - no resize behavior changes.

## Command Templates

Diagnostic smoke (markers OFF):
```powershell
C:/Program Files/R/R-4.5.1/bin/Rscript.exe System/Testing/vp_perf_probe_single_action_latency.R --label=tranche8i_client_readiness_marker_smoke_off --scenario=tab_only --cache-state=warm_partition_disk --runtime-perf=true --perf-boundary-markers=false
```

Diagnostic smoke (markers ON):
```powershell
C:/Program Files/R/R-4.5.1/bin/Rscript.exe System/Testing/vp_perf_probe_single_action_latency.R --label=tranche8i_client_readiness_marker_smoke_on --scenario=tab_only --cache-state=warm_partition_disk --runtime-perf=true --perf-boundary-markers=true
```

Strict replicated pair (post-smoke implementation candidate):
```powershell
C:/Program Files/R/R-4.5.1/bin/Rscript.exe System/Testing/vp_perf_run_acceptance_pair.R --label=tranche8i_client_readiness_acceptance_i9_<target> --iterations=9 --runtime-perf=true --perf-boundary-markers=<true|false|controlled> --manifest-clean-room=true --manifest-clean-room-dir=Logs --strict-manifest=true --strict-context-validation=true --strict-runtime-identity=true --acceptance-only=true --baseline-cache-state=warm_partition_disk --candidate-cache-state=warm_partition_disk --baseline-scenario=tab_only --candidate-scenario=tab_only --min-runs=9 --startup-improvement-min=0.25 --single-action-improvement-min=0.20 --max-mad-ratio=0.60 --bootstrap-reps=2000 --confidence=0.95 --bootstrap-seed=1 --rscript="C:/Program Files/R/R-4.5.1/bin/Rscript.exe"
```

Companion wait-boundary ownership view:
```powershell
C:/Program Files/R/R-4.5.1/bin/Rscript.exe System/Testing/vp_perf_step25e_wait_boundary_ownership_view_8i.R --label=tranche8i_wait_boundary_ownership_i9 --inventory="Logs/vp_perf_acceptance_inventory_tranche8i_off_on_i9_wait_boundary_ownership_inventory_20260805T221113Z.csv" --detail="Logs/vp_perf_acceptance_decomposition_tranche8i_off_on_i9_wait_boundary_ownership_decomp_20260805T221136Z_detail.csv" --runs="Logs/vp_perf_acceptance_decomposition_tranche8i_off_on_i9_wait_boundary_ownership_decomp_20260805T221136Z_runs.csv"
```

Priority output/materialization marker smoke (markers OFF):
```powershell
C:/Program Files/R/R-4.5.1/bin/Rscript.exe System/Testing/vp_perf_probe_single_action_latency.R --label=tranche8i_output_materialization_marker_smoke_off --scenario=tab_only --cache-state=warm_partition_disk --runtime-perf=true --perf-boundary-markers=false
```

Priority output/materialization marker smoke (markers ON):
```powershell
C:/Program Files/R/R-4.5.1/bin/Rscript.exe System/Testing/vp_perf_probe_single_action_latency.R --label=tranche8i_output_materialization_marker_smoke_on --scenario=tab_only --cache-state=warm_partition_disk --runtime-perf=true --perf-boundary-markers=true
```

## Step Ledger

| Step | Phase | Work | Status | Evidence/Files | Gate/Next Action |
|---|---|---|---|---|---|
| 8I-01 | Phase 0 | Create daughter plan and register guardrails/baseline | Complete | `Code Review/2026-08-05_vp_tranche8i_client_readiness_split_plan.md` | Roll up kickoff to parent plan |
| 8I-02 | Phase 1 | Run read-only split over fresh 8G detail/runs | Complete | `Logs/vp_perf_client_readiness_split_tranche8i_client_readiness_split_existing_8g_20260805T135916Z_signature.csv`; `Logs/vp_perf_client_readiness_split_tranche8i_client_readiness_split_existing_8g_20260805T135916Z_gap_context.csv`; `Logs/vp_perf_client_readiness_split_tranche8i_client_readiness_split_existing_8g_20260805T135916Z_role_pair_summary.csv` | Evaluate actionability gate |
| 8I-03 | Phase 1 Gate | Choose path: implementation candidate vs marker-provenance vs no-decision | Complete | `Logs/vp_perf_client_readiness_split_tranche8i_client_readiness_split_existing_8g_20260805T135916Z_role_pair_summary.csv` | Proceed to one small implementation hypothesis; marker-provenance not first next step |
| 8I-04 | Phase 2 | Marker-provenance refinement if needed | Complete | `Programs/app_source/ui.R`; `Programs/app_source/server/02_partner_and_notes.R`; `Logs/vp_perf_probe_single_action_latency_tranche8i_wait_boundary_ownership_marker_smoke_off_20260805T205319Z.csv`; `Logs/vp_perf_probe_single_action_latency_tranche8i_wait_boundary_ownership_marker_smoke_on_20260805T205541Z.csv` | Marker perturbation smoke passed; proceed to probe output augmentation |
| 8I-05 | Phase 3 | Apply one small reversible implementation candidate | Complete | `Programs/app_source/ui.R`; `Programs/app_source/server/02_partner_and_notes.R`; `Logs/vp_perf_probe_single_action_latency_tranche8i_client_readiness_phase3_resize_delay60_smoke_20260805T140221Z.csv` | Proceeded to strict replicated OFF/ON |
| 8I-06 | Phase 4 | Strict replicated validation and full evidence chain | Complete | `Logs/vp_perf_acceptance_index_tranche8i_off_on_i9_resize_delay60_20260805.csv`; `Logs/vp_perf_acceptance_inventory_tranche8i_off_on_i9_resize_delay60_inventory_20260805T184802Z.csv`; `Logs/vp_perf_acceptance_decomposition_tranche8i_off_on_i9_resize_delay60_decomp_20260805T184822Z_runs.csv`; `Logs/vp_perf_acceptance_decomposition_tranche8i_off_on_i9_resize_delay60_decomp_20260805T184822Z_summary.csv`; `Logs/vp_perf_acceptance_decomposition_tranche8i_off_on_i9_resize_delay60_rollup_20260805T185320Z_action_bucket.csv`; `Logs/vp_perf_client_readiness_split_tranche8i_client_readiness_split_resize_delay60_20260805T185337Z_role_pair_summary.csv` | Probe rejected; rollback complete; move to next hypothesis |
| 8I-07 | Phase 7 | Parent rollup + daughter closeout summary | Complete | Parent tranche update + this daughter summary | Tranche remains open for next single hypothesis |
| 8I-08 | Phase 3/4 | Apply refined client-owned main-tab resize ordering probe + strict validation | Complete | `Programs/app_source/ui.R`; `Programs/app_source/server/02_partner_and_notes.R`; `Logs/vp_perf_probe_single_action_latency_tranche8i_client_readiness_client_owned_resize_smoke_20260805T192403Z.csv`; `Logs/vp_perf_acceptance_decision_tranche8i_client_readiness_acceptance_i9_client_owned_resize__decision_20260805T202932Z_decision.csv`; `Logs/vp_perf_acceptance_decomposition_tranche8i_off_on_i9_client_owned_resize_rollup_20260805T203325Z_action_bucket.csv`; `Logs/vp_perf_client_readiness_split_tranche8i_client_readiness_split_client_owned_resize_20260805T203337Z_role_pair_summary.csv` | Probe rejected on strict evidence; rollback complete |
| 8I-09 | Phase 2/3 | Implement wait-boundary ownership instrumentation tranche: resize request id chain + boundary/gap probe columns | Complete | `Programs/app_source/server/02_partner_and_notes.R`; `Programs/app_source/ui.R`; `System/Testing/vp_perf_probe_single_action_latency.R`; `Logs/vp_perf_probe_single_action_latency_tranche8i_wait_boundary_ownership_marker_smoke_off_20260805T205319Z.csv`; `Logs/vp_perf_probe_single_action_latency_tranche8i_wait_boundary_ownership_marker_smoke_on_20260805T205541Z.csv`; `Logs/vp_perf_probe_single_action_latency_tranche8i_wait_boundary_ownership_marker_smoke_on_augmented_20260805T210123Z.csv`; `Logs/vp_runtime_perf_single_action_tranche8i_wait_boundary_ownership_marker_smoke_on_20260805T205541Z.jsonl`; `Logs/vp_runtime_perf_single_action_tranche8i_wait_boundary_ownership_marker_smoke_on_augmented_20260805T210123Z.jsonl` | Continue with strict replicated diagnostic pair (`i9`) using markers ON and exact-path ownership chain |
| 8I-10 | Phase 5/6 | Run strict replicated wait-boundary ownership pair and full exact-path evidence chain | Complete | `Logs/vp_perf_acceptance_run_manifest_tranche8i_wait_boundary_ownership_i9_20260805T210755Z.csv`; `Logs/vp_perf_acceptance_decision_tranche8i_wait_boundary_ownership_i9__decision_20260805T221047Z_decision.csv`; `Logs/vp_perf_acceptance_index_tranche8i_off_on_i9_wait_boundary_ownership_20260805.csv`; `Logs/vp_perf_acceptance_inventory_tranche8i_off_on_i9_wait_boundary_ownership_inventory_20260805T221113Z.csv`; `Logs/vp_perf_acceptance_inventory_validation_tranche8i_off_on_i9_wait_boundary_ownership_validation_20260805T221125Z_summary.csv`; `Logs/vp_perf_acceptance_decomposition_tranche8i_off_on_i9_wait_boundary_ownership_decomp_20260805T221136Z_runs.csv`; `Logs/vp_perf_acceptance_decomposition_tranche8i_off_on_i9_wait_boundary_ownership_audit_20260805T221543Z_audit_summary.json`; `Logs/vp_perf_acceptance_decomposition_tranche8i_off_on_i9_wait_boundary_ownership_rollup_20260805T221544Z_action_bucket.csv`; `Logs/vp_perf_client_readiness_split_tranche8i_client_readiness_split_wait_boundary_ownership_20260805T221553Z_role_pair_summary.csv` | Companion ownership view completed in 8I-12; use per-tab classification to target next diagnostic inventory |
| 8I-11 | Phase 5/6 | Fold guardrail/helper diagnostic direction into plan after ownership view | Complete | `Code Review/2026-08-05_vp_tranche8i_client_readiness_split_plan.md` | Ownership evidence now available; inventory should be evidence-guided, not broad |
| 8I-12 | Phase 5 | Build and run companion wait-boundary ownership view helper | Complete | `System/Testing/vp_perf_step25e_wait_boundary_ownership_view_8i.R`; `Logs/vp_perf_wait_boundary_ownership_view_tranche8i_wait_boundary_ownership_i9_20260806T132650Z_action_rows.csv`; `Logs/vp_perf_wait_boundary_ownership_view_tranche8i_wait_boundary_ownership_i9_20260806T132650Z_tab_summary.csv`; `Logs/vp_perf_wait_boundary_ownership_view_tranche8i_wait_boundary_ownership_i9_20260806T132650Z_coverage.csv` | Start evidence-guided guardrail/helper inventory: Heatmap boundary/readiness gates first, output/Plotly materialization surfaces for Current vs. Average, Historical Trend, and Map |
| 8I-13 | Phase 6 | Read-only inventory of ownership-implicated guardrails/helpers | Complete | `Programs/app_source/ui.R`; `Programs/app_source/server/02_partner_and_notes.R`; `Programs/app_source/server/04_comparison_plots.R`; `Programs/app_source/server/05_trend_and_heatmap.R`; `System/Testing/vp_perf_probe_single_action_latency.R` | Superseded by 8I-14 priority decision: Current vs. Average output/materialization first; Heatmap boundary/readiness deferred |
| 8I-14 | Phase 7 | Fold logic-audit refinements into priority output/materialization diagnostic plan | Complete | `Code Review/2026-08-05_vp_tranche8i_client_readiness_split_plan.md`; `/memories/session/plan.md` | Implement `comparison_plot` bridge-marker tranche first; extend to `timeseries_plot` and `map_plot` only if the shared helper remains narrow |
| 8I-15 | Phase 7 | Prepare handoff packet for output/materialization diagnostic implementation | Complete | `Code Review/2026-08-05_vp_tranche8i_client_readiness_split_plan.md`; `/memories/session/plan.md` | Next implementer starts with `comparison_plot` marker chain, OFF/ON smoke, and marker-completeness audit before any strict pair |
| 8I-16 | Phase 7 | Implement `comparison_plot` bridge-marker tranche and smoke-validate OFF/ON behavior | Complete | `Programs/app_source/ui.R`; `Programs/app_source/server/04_comparison_plots.R`; `System/Testing/vp_perf_probe_single_action_latency.R`; `Logs/vp_perf_probe_single_action_latency_tranche8i_output_materialization_marker_smoke_off_rerun1_20260806T142348Z.csv`; `Logs/vp_perf_probe_single_action_latency_tranche8i_output_materialization_marker_smoke_on_rerun2_20260806T142010Z.csv`; `Logs/vp_runtime_perf_single_action_tranche8i_output_materialization_marker_smoke_off_rerun1_20260806T142348Z.jsonl`; `Logs/vp_runtime_perf_single_action_tranche8i_output_materialization_marker_smoke_on_rerun2_20260806T142010Z.jsonl` | Followed by 8I-17 narrow same-clock server-anchor refinement prior to strict pair |
| 8I-17 | Phase 7 | Add narrow same-clock server-anchor fallback for `comparison_plot` server output phases and validate ON smoke | Complete | `Programs/app_source/server/04_comparison_plots.R`; `System/Testing/vp_perf_probe_single_action_latency.R`; `Logs/vp_perf_probe_single_action_latency_tranche8i_output_materialization_marker_smoke_on_server_anchor_rerun1_20260806T144641Z.csv`; `Logs/vp_runtime_perf_single_action_tranche8i_output_materialization_marker_smoke_on_server_anchor_rerun1_20260806T144641Z.jsonl` | Server phase columns now accept same-clock `elapsed_ms` anchor values from runtime `server_output_anchor`; next decision is strict replicated diagnostic pair (`tranche8i_output_materialization_i9`) |
| 8I-18 | Phase 5/6 | Run strict replicated output/materialization diagnostic pair (`tranche8i_output_materialization_i9`) on refined same-clock baseline | Complete | `Logs/vp_perf_acceptance_run_manifest_tranche8i_output_materialization_i9_20260806T145630Z.csv`; `Logs/vp_perf_acceptance_run_manifest_tranche8i_output_materialization_i9_20260806T145630Z.jsonl`; `Logs/vp_perf_acceptance_decision_tranche8i_output_materialization_i9__decision_20260806T160935Z_decision.csv`; `Logs/vp_perf_acceptance_decision_tranche8i_output_materialization_i9__decision_20260806T160935Z_summary.csv`; `Logs/vp_perf_acceptance_decision_tranche8i_output_materialization_i9__decision_20260806T160935Z_details.csv` | Strict preflight checks passed; decision gate failed (no required startup/single-action improvement), so tranche remains diagnostic-only and no optimization promotion |
| 8I-19 | Phase 7 | Build exact-path Current vs. Average output/materialization phase view over strict i9 cohort | Complete | `System/Testing/vp_perf_step25f_output_materialization_phase_view_8i.R`; `Logs/vp_perf_output_materialization_phase_view_tranche8i_output_materialization_i9_current_phase_view_corrected2_20260806T161924Z_action_rows.csv`; `Logs/vp_perf_output_materialization_phase_view_tranche8i_output_materialization_i9_current_phase_view_corrected2_20260806T161924Z_lane_summary.csv`; `Logs/vp_perf_output_materialization_phase_view_tranche8i_output_materialization_i9_current_phase_view_corrected2_20260806T161924Z_coverage.csv` | Current wait is dominated by delayed target Shiny value delivery/output invalidation timing, not post-value widget insertion, main SVG insertion, Plotly afterplot, loading-cleared, or useful-ready; next target is server/output invalidation and Shiny delivery provenance for `comparison_plot` |
| 8I-20 | Phase 0/1/2 | Inventory-first supersession + first delivery-provenance implementation slice (`comparison_plot` cache-key/non-render-body markers) | Complete | `Code Review/2026-08-05_vp_tranche8i_client_readiness_split_plan.md`; `Programs/app_source/server/04_comparison_plots.R`; `System/Testing/vp_perf_probe_single_action_latency.R`; `Logs/vp_perf_probe_single_action_latency_tranche8i_comparison_delivery_marker_smoke_off_implstart_rerun5_20260806T174542Z.csv`; `Logs/vp_perf_probe_single_action_latency_tranche8i_comparison_delivery_marker_smoke_on_implstart_rerun5_20260806T174852Z.csv`; `Logs/vp_runtime_perf_single_action_tranche8i_comparison_delivery_marker_smoke_off_implstart_rerun5_20260806T174542Z.jsonl`; `Logs/vp_runtime_perf_single_action_tranche8i_comparison_delivery_marker_smoke_on_implstart_rerun5_20260806T174852Z.jsonl` | Validation passed; OFF marker absence and ON provenance-field population confirmed; proceed to next delivery-provenance slice |
| 8I-21 | Phase 7 | Implement narrow cache-key timing/action-join refinement (`comparison_plot`) and smoke-validate OFF/ON | Complete | `Programs/app_source/server/04_comparison_plots.R`; `System/Testing/vp_perf_probe_single_action_latency.R`; `Logs/vp_perf_probe_single_action_latency_tranche8i_output_materialization_timing_anchor_smoke_off_impl2_20260806T182555Z.csv`; `Logs/vp_perf_probe_single_action_latency_tranche8i_output_materialization_timing_anchor_smoke_on_impl2_20260806T182826Z.csv`; `Logs/vp_runtime_perf_single_action_tranche8i_output_materialization_timing_anchor_smoke_off_impl2_20260806T182555Z.jsonl`; `Logs/vp_runtime_perf_single_action_tranche8i_output_materialization_timing_anchor_smoke_on_impl2_20260806T182826Z.jsonl` | OFF/ON marker-neutrality and parser integrity gates passed; ON now emits deterministic join-confidence/clock-basis/candidate metadata but action-id and same-clock elapsed remain unavailable on selected Current rows, so ownership remains diagnostic-only |
| 8I-22 | Phase 7 | Implement observable downstream provenance tranche for `comparison_plot` and smoke-validate OFF/ON | Complete | `Programs/app_source/server/04_comparison_plots.R`; `System/Testing/vp_perf_probe_single_action_latency.R`; `Logs/vp_perf_probe_single_action_latency_tranche8i_comparison_observable_downstream_smoke_off_rerun1_20260806T193343Z.csv`; `Logs/vp_runtime_perf_single_action_tranche8i_comparison_observable_downstream_smoke_off_rerun1_20260806T193343Z.jsonl`; `Logs/vp_perf_probe_single_action_latency_tranche8i_comparison_observable_downstream_smoke_on_rerun1_20260806T192830Z.csv`; `Logs/vp_runtime_perf_single_action_tranche8i_comparison_observable_downstream_smoke_on_rerun1_20260806T192831Z.jsonl` | OFF/ON parser and smoke gates passed; downstream fields now report explicit missing-reason/outcome evidence when render/flush markers are absent (`cache_hit_or_body_bypass_possible`), so ownership remains diagnostic-only and next target is non-render-body invalidation/scheduling provenance |
| 8I-23 | Phase 7 | Implement post-cache-key/pre-`shiny:value` flush-cycle provenance marker for `comparison_plot` and smoke-validate OFF/ON | Complete | `Programs/app_source/server/04_comparison_plots.R`; `System/Testing/vp_perf_probe_single_action_latency.R`; `Logs/vp_perf_probe_single_action_latency_tranche8i_comparison_post_cache_flush_smoke_off_rerun2_20260806T200835Z.csv`; `Logs/vp_runtime_perf_single_action_tranche8i_comparison_post_cache_flush_smoke_off_rerun2_20260806T200836Z.jsonl`; `Logs/vp_perf_probe_single_action_latency_tranche8i_comparison_post_cache_flush_smoke_on_rerun2_20260806T201158Z.csv`; `Logs/vp_runtime_perf_single_action_tranche8i_comparison_post_cache_flush_smoke_on_rerun2_20260806T201158Z.jsonl` | Final OFF/ON smoke passed (`PASS=4` each); OFF markers stayed absent, ON emitted 10 cache-key and 10 post-cache markers, and Current joined one post-cache marker at `-276 ms` versus browser `shiny:value` at `11139 ms`, localizing the remaining wait after the post-cache-key flush boundary |
| 8I-24 | Phase 5/6/7 | Run strict replicated ON diagnostic cohort for post-cache-key marker chain and exact-path evidence stack (`tranche8i_comparison_post_cache_flush_i9`) | Complete | `Code Review/2026-08-05_vp_tranche8i_client_readiness_split_plan.md`; `Logs/vp_perf_acceptance_run_manifest_tranche8i_comparison_post_cache_flush_i9_20260806T203836Z.csv`; `Logs/vp_perf_acceptance_run_manifest_tranche8i_comparison_post_cache_flush_i9_20260806T203836Z.jsonl`; `Logs/vp_perf_acceptance_decision_tranche8i_comparison_post_cache_flush_i9__decision_20260806T215240Z_decision.csv`; `Logs/vp_perf_acceptance_decision_tranche8i_comparison_post_cache_flush_i9__decision_20260806T215240Z_summary.csv`; `Logs/vp_perf_acceptance_decision_tranche8i_comparison_post_cache_flush_i9__decision_20260806T215240Z_details.csv`; `Logs/vp_perf_acceptance_index_tranche8i_off_on_i9_comparison_post_cache_flush_20260806.csv`; `Logs/vp_perf_acceptance_inventory_tranche8i_off_on_i9_comparison_post_cache_flush_inventory_20260806T215313Z.csv`; `Logs/vp_perf_acceptance_inventory_validation_tranche8i_off_on_i9_comparison_post_cache_flush_validation_20260806T215317Z_summary.csv`; `Logs/vp_perf_acceptance_decomposition_tranche8i_off_on_i9_comparison_post_cache_flush_decomp_20260806T215323Z_detail.csv`; `Logs/vp_perf_acceptance_decomposition_tranche8i_off_on_i9_comparison_post_cache_flush_decomp_20260806T215323Z_runs.csv`; `Logs/vp_perf_acceptance_decomposition_tranche8i_off_on_i9_comparison_post_cache_flush_decomp_20260806T215323Z_summary.csv`; `Logs/vp_perf_acceptance_decomposition_tranche8i_off_on_i9_comparison_post_cache_flush_decomp_20260806T215323Z_window_confidence.csv`; `Logs/vp_perf_acceptance_decomposition_tranche8i_off_on_i9_comparison_post_cache_flush_decomp_20260806T215323Z_inconclusive_gate.csv`; `Logs/vp_perf_acceptance_decomposition_tranche8i_off_on_i9_comparison_post_cache_flush_audit_20260806T220056Z_audit_summary.json`; `Logs/vp_perf_acceptance_decomposition_tranche8i_off_on_i9_comparison_post_cache_flush_rollup_20260806T220058Z_action_bucket.csv`; `Logs/vp_perf_output_materialization_phase_view_tranche8i_comparison_post_cache_flush_i9_current_phase_view_20260806T220113Z_action_rows.csv`; `Logs/vp_perf_output_materialization_phase_view_tranche8i_comparison_post_cache_flush_i9_current_phase_view_20260806T220113Z_lane_summary.csv`; `Logs/vp_perf_output_materialization_phase_view_tranche8i_comparison_post_cache_flush_i9_current_phase_view_20260806T220113Z_coverage.csv`; `Logs/vp_perf_tranche8i_24_current_marker_quality_rows_20260806T2207Z.csv` | Strict preflight identity/context gates passed, index bootstrap + exact-path chain completed, Step 25B quarantine rows were `0`, and Current marker-quality gate passed (`18/18`, `100%`, `medium_action_window_join`) with late browser value receipt; repair-search target remains output invalidation/scheduling/cache-hit delivery and still diagnostic-only |

| 8I-25 | Phase 6/7 | Implement targeted `comparison_plot` delivery-provenance diagnostic markers for active eligibility, real `onFlushed` ordering, cache/body-bypass outcome, dependency snapshots, and exact action context | Complete | `Programs/app_source/server/04_comparison_plots.R`; `System/Testing/vp_perf_probe_single_action_latency.R`; `Logs/vp_perf_acceptance_run_manifest_tranche8i_comparison_delivery_provenance_i9_20260807T150715Z.csv`; `Logs/vp_perf_acceptance_decomposition_tranche8i_off_on_i9_comparison_delivery_provenance_decomp_20260807T163154Z_runs.csv`; `Logs/vp_perf_output_materialization_phase_view_tranche8i_comparison_delivery_provenance_i9_current_phase_view_20260807T163521Z_lane_summary.csv` | Exact marker-quality gate passed for Current (`18/18` strong exact joins, candidate count `1`); generic decomposition vocabulary was stale for new output-boundary markers and is corrected in 8I-26 |
| 8I-26 | Phase 4/7 | Frozen-evidence classifier cleanup for 8I output boundary marker vocabulary | Complete | `System/Testing/vp_perf_decompose_single_action_8c.R`; `Logs/vp_perf_acceptance_decomposition_tranche8i_comparison_delivery_provenance_classifier_cleanup1_20260807T164903Z_runs.csv`; `Logs/vp_perf_acceptance_decomposition_tranche8i_comparison_delivery_provenance_classifier_cleanup1_audit_20260807T165343Z_audit_summary.json`; `Logs/vp_perf_acceptance_decomposition_tranche8i_comparison_delivery_provenance_classifier_cleanup1_rollup_20260807T165345Z_action_bucket.csv` | Measurement-layer confidence recovered without rerunning Shiny: residual unclassified ~`0.03%`; dominant former unclassified mass is now explicit diagnostic `output_boundary_provenance`, not a repair owner |
| 8I-27 | Phase 6/7 | Implement comparison-plot final-output cache ablation wiring + runtime lane-identity hardening + current-only smoke stabilization | Complete | `Programs/app_source/server/04_comparison_plots.R`; `Programs/app_source/global.R`; `System/Testing/vp_perf_probe_single_action_latency.R`; `System/Testing/vp_perf_probe_startup.R`; `System/Testing/vp_perf_run_acceptance_pair.R`; `System/Testing/vp_perf_acceptance_manifest.R`; `Logs/vp_perf_probe_single_action_latency_tranche8j_comparison_cache_on_smoke_20260807T175750Z.csv`; `Logs/vp_runtime_perf_single_action_tranche8j_comparison_cache_on_smoke_20260807T175750Z.jsonl`; `Logs/vp_perf_probe_single_action_latency_tranche8j_comparison_cache_off_smoke_20260807T180126Z.csv`; `Logs/vp_runtime_perf_single_action_tranche8j_comparison_cache_off_smoke_20260807T180126Z.jsonl`; `Logs/vp_perf_probe_startup_tranche8j_startup_cache_off_smoke_20260807T180438Z.csv`; `Logs/vp_runtime_perf_startup_tranche8j_startup_cache_off_smoke_20260807T180439Z.jsonl`; `Logs/vp_perf_probe_single_action_latency_tranche8j_comparison_cache_on_smoke_current_only_20260807T181246Z.csv`; `Logs/vp_runtime_perf_single_action_tranche8j_comparison_cache_on_smoke_current_only_20260807T181246Z.jsonl`; `Logs/vp_perf_probe_single_action_latency_tranche8j_comparison_cache_off_smoke_current_only_20260807T181449Z.csv`; `Logs/vp_runtime_perf_single_action_tranche8j_comparison_cache_off_smoke_current_only_20260807T181449Z.jsonl` | Standard `tab_only` smoke remains noisy (`FAIL` rows on non-current tabs), but current-only cache ON/OFF smoke is stable (`PASS=1` each); next gate is strict ON/OFF pair with `--baseline-scenario=tab_current_only` and `--candidate-scenario=tab_current_only` |
| 8I-28 | Phase 5/6/7 | Run strict current-only ON/OFF pair, execute exact-path chain, and harden Step25F dominant-phase guard | Complete | `System/Testing/vp_perf_step25f_output_materialization_phase_view_8i.R`; `Logs/vp_perf_acceptance_run_manifest_tranche8j_comparison_cache_on_off_current_only_i1_20260807T181804Z.csv`; `Logs/vp_perf_acceptance_run_manifest_tranche8j_comparison_cache_on_off_current_only_i1_retry1_20260807T182630Z.csv`; `Logs/vp_perf_acceptance_decision_tranche8j_comparison_cache_on_off_current_only_i1_retry1__decision_20260807T183333Z_decision.csv`; `Logs/vp_perf_acceptance_index_tranche8j_off_on_i1_comparison_cache_on_off_current_only_retry1_20260807.csv`; `Logs/vp_perf_acceptance_inventory_tranche8j_off_on_i1_comparison_cache_on_off_current_only_retry1_inventory_20260807T183559Z.csv`; `Logs/vp_perf_acceptance_inventory_validation_tranche8j_off_on_i1_comparison_cache_on_off_current_only_retry1_validation_20260807T183604Z_summary.csv`; `Logs/vp_perf_acceptance_decomposition_tranche8j_off_on_i1_comparison_cache_on_off_current_only_retry1_decomp_20260807T183611Z_runs.csv`; `Logs/vp_perf_acceptance_decomposition_tranche8j_off_on_i1_comparison_cache_on_off_current_only_retry1_audit_20260807T183635Z_audit_summary.json`; `Logs/vp_perf_acceptance_decomposition_tranche8j_off_on_i1_comparison_cache_on_off_current_only_retry1_rollup_20260807T183641Z_action_bucket.csv`; `Logs/vp_perf_output_materialization_phase_view_tranche8j_comparison_cache_on_off_current_only_i1_retry1_current_phase_view_20260807T183727Z_lane_summary.csv` | Attempt 1 failed strict preflight from candidate startup control timeout; retry with wider timeouts passed strict context/runtime identity and full Step25 chain (`0` quarantine rows), but decision remains threshold-FAIL at `n=1` (diagnostic-only lane, no optimization claim) |

## Execution Update (8I-16)

1. Scope implemented (diagnostic-only, `comparison_plot` mandatory first):
   - no behavior change to `outputOptions(...)`, hidden-output semantics, `bindCache(...)`, readiness predicates, decomposition rules, thresholds, or resize behavior,
   - no Heatmap-first expansion,
   - Historical Trend/Map not instrumented in this first pass.
2. Client marker implementation in `Programs/app_source/ui.R`:
   - added scoped output-state helpers for target output inspection,
   - added `comparison_plot` output boundary markers:
      - `boundary_output_client_value_received`,
      - `boundary_output_widget_inserted`,
      - `boundary_output_main_svg_inserted`,
      - `boundary_output_plotly_afterplot`,
      - `boundary_output_loading_cleared`,
      - `boundary_output_useful_ready` with `useful_ready_rule = plotly_afterplot_and_loading_cleared`,
   - added per-action/per-phase marker dedupe keying to prevent duplicate marker storms.
3. Server diagnostic implementation in `Programs/app_source/server/04_comparison_plots.R`:
   - added guarded boundary logging for render phase/outcome semantics:
      - `boundary_server_output_render_start`,
      - `boundary_server_output_inputs_resolved`,
      - `boundary_server_output_plot_object_built`,
      - `boundary_server_output_render_returned`,
   - added explicit cache-body outcome evidence via `record_cache_body_execution(...)` details:
      - `comparison_plot_gated_skip` with `output_outcome = active_gate_skip`,
      - `comparison_plot_executed` with `output_outcome = render_body_executed`,
      - `comparison_plot_empty_state_return` with `output_outcome = empty_state_return`,
      - `comparison_plot_normal_return` with `output_outcome = normal_plot_return`.
4. Probe augmentation in `System/Testing/vp_perf_probe_single_action_latency.R`:
   - extended runtime parsing for new marker payload fields (`target_output_id`, `output_owner`, `surface`, `phase`, `output_outcome`, `useful_ready_rule`),
   - added cache-body runtime parsing and action-row enrichment for `comparison_plot` outcome evidence,
   - added output/materialization timing columns and derived gaps:
      - `output_client_value_received_ms`,
      - `output_widget_inserted_marker_ms`,
      - `output_main_svg_inserted_marker_ms`,
      - `output_plotly_afterplot_marker_ms`,
      - `output_loading_cleared_marker_ms`,
      - `output_useful_ready_ms`,
      - plus rendered-to-client and useful-ready gap fields,
   - tightened event selection to action-scoped target-output rows to prevent stale cross-action contamination.
5. Validation executed:
   - parse checks:
      - `PARSE_OK_UI` (`Programs/app_source/ui.R`),
      - `PARSE_OK_04` (`Programs/app_source/server/04_comparison_plots.R`),
      - `PARSE_OK_PROBE` (`System/Testing/vp_perf_probe_single_action_latency.R`),
   - editor diagnostics: no errors for touched files,
   - marker OFF smoke rerun:
      - `Logs/vp_perf_probe_single_action_latency_tranche8i_output_materialization_marker_smoke_off_rerun1_20260806T142348Z.csv`,
      - `Logs/vp_runtime_perf_single_action_tranche8i_output_materialization_marker_smoke_off_rerun1_20260806T142348Z.jsonl`,
      - status: `PASS=4`,
      - new output/materialization marker tags absent,
   - marker ON smoke rerun:
      - `Logs/vp_perf_probe_single_action_latency_tranche8i_output_materialization_marker_smoke_on_rerun2_20260806T142010Z.csv`,
      - `Logs/vp_runtime_perf_single_action_tranche8i_output_materialization_marker_smoke_on_rerun2_20260806T142010Z.jsonl`,
      - status: `PASS=4`,
      - `tab_settled_current` row shows populated `comparison_plot` client marker chain and `useful_ready_rule`.
6. Evidence nuance (important for interpretation):
   - server render phase markers can be absent on cache-hit return paths because cached `renderPlotly` returns bypass body execution,
   - cache-body execution events now provide explicit `comparison_plot` path outcome evidence so server-marker absence is not misread as missing instrumentation.
7. Gate decision after implementation:
   - bridge-marker tranche is implemented and smoke-neutral,
   - next choice is either:
      - run strict replicated diagnostic pair (`tranche8i_output_materialization_i9`) using this implementation, or
      - add one narrow same-clock server-anchor refinement if higher confidence on server sub-phase timing is required before pair execution.

## Execution Update (8I-17)

1. Scope implemented (narrow diagnostic refinement only):
   - no behavior changes to outputs, cache semantics, readiness predicates, decomposition rules, thresholds, or resize behavior,
   - refinement limited to `comparison_plot` server phase anchoring confidence.
2. Server-side refinement in `Programs/app_source/server/04_comparison_plots.R`:
   - enhanced `emit_comparison_plot_boundary(...)` to emit a runtime fallback event per boundary marker:
      - `event = server_output_anchor`,
      - `tag = boundary_<boundary_name>`,
      - includes `target_output_id`, `tab`, `source`, and same-clock `elapsed_ms` already computed from render start,
      - includes `action_reason = tab_click:<active_tab>` when not already supplied.
3. Probe refinement in `System/Testing/vp_perf_probe_single_action_latency.R`:
   - added `parse_runtime_server_output_anchor_events(...)` to parse runtime fallback rows,
   - action-scoped and output-scoped server-anchor subsets now feed output phase extraction,
   - server output phase columns now prefer same-clock `elapsed_ms` from `server_output_anchor` and fall back to legacy marker path only when needed:
      - `output_render_start_ms`,
      - `output_inputs_resolved_ms`,
      - `output_plot_object_built_ms`,
      - `output_render_returned_ms`.
4. Validation executed:
   - ON smoke rerun command:
      - `C:/Program Files/R/R-4.5.1/bin/Rscript.exe System/Testing/vp_perf_probe_single_action_latency.R --label=tranche8i_output_materialization_marker_smoke_on_server_anchor_rerun1 --scenario=tab_only --cache-state=warm_partition_disk --runtime-perf=true --perf-boundary-markers=true`,
   - outputs:
      - `Logs/vp_perf_probe_single_action_latency_tranche8i_output_materialization_marker_smoke_on_server_anchor_rerun1_20260806T144641Z.csv`,
      - `Logs/vp_runtime_perf_single_action_tranche8i_output_materialization_marker_smoke_on_server_anchor_rerun1_20260806T144641Z.jsonl`,
   - run status: `PASS=4`.
5. Evidence highlights:
   - runtime log contains explicit `server_output_anchor` rows for `comparison_plot` server phases with same-clock `elapsed_ms`:
      - `boundary_server_output_render_start` (`elapsed_ms` observed: `24`),
      - `boundary_server_output_inputs_resolved` (`elapsed_ms` observed: `358`),
      - `boundary_server_output_plot_object_built` (`elapsed_ms` observed: `612`),
      - `boundary_server_output_render_returned` (`elapsed_ms` observed: `685`),
      - all with `action_reason = tab_click:Current vs. Average` and `target_output_id = comparison_plot`.
   - corresponding `tab_settled_current` CSV row contains populated server phase columns aligned to same-clock anchors (`24`, `358`, `612`, `685`).
6. Interpretation impact:
   - this removes reliance on repeated cross-clock timestamp subtraction for server phase columns when same-clock elapsed anchors are available,
   - preserves existing fallbacks for robustness and keeps the refinement diagnostic-only.

## Execution Update (8I-18)

1. Strict replicated pair executed on refined baseline:
   - command:
      - `C:/Program Files/R/R-4.5.1/bin/Rscript.exe System/Testing/vp_perf_run_acceptance_pair.R --label=tranche8i_output_materialization_i9 --iterations=9 --runtime-perf=true --perf-boundary-markers=true --manifest-clean-room=true --manifest-clean-room-dir=Logs --strict-manifest=true --strict-context-validation=true --strict-runtime-identity=true --acceptance-only=true --baseline-cache-state=warm_partition_disk --candidate-cache-state=warm_partition_disk --baseline-scenario=tab_only --candidate-scenario=tab_only --min-runs=9 --startup-improvement-min=0.25 --single-action-improvement-min=0.20 --max-mad-ratio=0.60 --bootstrap-reps=2000 --confidence=0.95 --bootstrap-seed=1 --rscript=\"C:/Program Files/R/R-4.5.1/bin/Rscript.exe\"`.
2. Strict preflight/identity gates:
   - manifest rows: `36/36` expected,
   - context validation: `PASS` (`0` failures),
   - runtime identity validation: `PASS` (`0` failures).
3. Acceptance decision outcome:
   - overall: `FAIL`,
   - startup gate: `FAIL` (`improvement_ratio=0.068176`, threshold `0.25`, CI lower `-0.033785`),
   - single-action gate: `FAIL` (`improvement_ratio=-0.018257`, threshold `0.20`, CI lower `-0.155027`).
4. Decision artifacts:
   - `Logs/vp_perf_acceptance_decision_tranche8i_output_materialization_i9__decision_20260806T160935Z_decision.csv`,
   - `Logs/vp_perf_acceptance_decision_tranche8i_output_materialization_i9__decision_20260806T160935Z_summary.csv`,
   - `Logs/vp_perf_acceptance_decision_tranche8i_output_materialization_i9__decision_20260806T160935Z_details.csv`.
5. Interpretation for tranche state:
   - the refined same-clock instrumentation and strict identity/context gates held,
   - no evidence of required performance improvement for optimization promotion,
   - keep tranche in diagnostic posture and treat this run as evidence capture rather than repair acceptance.

## Execution Update (8I-19)

1. Focused post-run diagnostic view added:
   - helper: `System/Testing/vp_perf_step25f_output_materialization_phase_view_8i.R`,
   - input manifest: `Logs/vp_perf_acceptance_run_manifest_tranche8i_output_materialization_i9_20260806T145630Z.csv`,
   - target: `tab_settled_current` / `Current vs. Average` / `comparison_plot`,
   - output scope: exact manifest-bound `18` single-action rows (`9` baseline, `9` candidate).
2. Validation and helper correction:
   - parse check passed (`PARSE_OK_STEP25F`) and editor diagnostics were clean,
   - first helper pass showed stale early `plotly_afterplot` events can precede target Shiny value and produce misleading negative widget-to-afterplot gaps,
   - helper was corrected to parse `timeline_events` and compute target-matched phases at or after `shiny_value_output` for `comparison_plot`.
3. Final artifacts:
   - action rows: `Logs/vp_perf_output_materialization_phase_view_tranche8i_output_materialization_i9_current_phase_view_corrected2_20260806T161924Z_action_rows.csv`,
   - lane summary: `Logs/vp_perf_output_materialization_phase_view_tranche8i_output_materialization_i9_current_phase_view_corrected2_20260806T161924Z_lane_summary.csv`,
   - coverage: `Logs/vp_perf_output_materialization_phase_view_tranche8i_output_materialization_i9_current_phase_view_corrected2_20260806T161924Z_coverage.csv`.
4. Coverage:
   - expected single-action runs: `18`,
   - action rows recovered: `18`,
   - pass rows: `18`,
   - complete same-clock `server_output_anchor` chains in this strict cohort: `0`.
5. Corrected Current vs. Average phase medians:
   - baseline:
      - total action `9964` ms,
      - visible ready `8765` ms,
      - target `comparison_plot` Shiny value `8469` ms,
      - target widget/main SVG after Shiny value `8469` ms,
      - target Plotly afterplot/useful-ready after Shiny value `8505` ms,
      - corrected Shiny value to useful-ready `43` ms,
      - corrected visible milestone to useful-ready `8401` ms,
      - useful-ready to readiness predicate `164` ms.
   - candidate:
      - total action `10644` ms,
      - visible ready `9282` ms,
      - target `comparison_plot` Shiny value `9099` ms,
      - target widget/main SVG after Shiny value `9099` ms,
      - target Plotly afterplot/useful-ready after Shiny value `9144` ms,
      - corrected Shiny value to useful-ready `44` ms,
      - corrected visible milestone to useful-ready `9000` ms,
      - useful-ready to readiness predicate `148` ms.
   - all rows:
      - total action `10242.5` ms,
      - visible ready `8908.5` ms,
      - target `comparison_plot` Shiny value `8656.5` ms,
      - target widget/main SVG after Shiny value `8679.5` ms,
      - target Plotly afterplot/useful-ready after Shiny value `8699.5` ms,
      - corrected Shiny value to useful-ready `43.5` ms,
      - corrected visible milestone to useful-ready `8594` ms,
      - useful-ready to readiness predicate `156` ms.
6. Interpretation:
   - post-Shiny-value browser materialization is not the dominant owner in this cohort: widget insertion and main SVG are immediate at/near target Shiny value, Plotly afterplot follows roughly `35-38` ms later, and useful-ready follows roughly `43-44` ms after target Shiny value,
   - the long wait sits before target `comparison_plot` Shiny value delivery, with median target Shiny value around `8.5-9.1` seconds after the action,
   - same-clock server render anchors are absent in this strict cohort, likely because the repeated tab-settled actions frequently use cached/previous render paths where render-body boundary anchors are not emitted,
   - next diagnostic target should shift from browser Plotly materialization to `comparison_plot` invalidation/delivery provenance: why the target output value is not delivered until roughly `8.5-9.1` seconds after the tab action, including active-output gating, cache-hit delivery, upstream reactive invalidation, and output scheduling markers.

## Execution Update (8I-20)

1. Supersession and scope lock:
   - this step supersedes the older 8I-15 marker-first wording with an inventory-first `comparison_plot` delivery-provenance pass,
   - scope remains diagnostic-only and `comparison_plot`-only,
   - no behavior changes to `bindCache(...)`, output semantics, readiness predicates, or decomposition rules.
2. Inventory conclusions applied before edits:
   - render-body markers (`server_output_anchor`) are valuable when body executes but can be absent on cache-hit/body-bypass paths,
   - first non-render-body candidate is cache-key evaluation provenance on the `comparison_plot` `bindCache(...)` path,
   - risk identified: `comparison_plot_base_cache_key()` is referenced many times in the key expression, so naive in-helper markers could create marker storms.
3. First implementation slice (non-render-body provenance):
   - `Programs/app_source/server/04_comparison_plots.R`:
      - added deduped cache-key delivery-provenance marker helper for `comparison_plot`,
      - emits structured payload fields (`target_output_id`, `surface`, `phase`, `output_outcome`, `guard_name`, `reason_code`, `fires_when`, active gate/cache-key context fields),
      - emits through existing runtime/client perf plumbing (`runtime_perf_record` / `log_client_perf`) under boundary-marker gating,
      - added targeted observer to emit `boundary_comparison_cache_key_evaluated` on cache-key-relevant state changes with dedupe keying to limit churn.
   - `System/Testing/vp_perf_probe_single_action_latency.R`:
      - extended runtime parser payload coverage for the new provenance fields,
      - included `boundary_comparison_cache_key_evaluated` in marker tags,
      - mapped marker fields into action rows for `tab_settled_current` interpretation.
4. Validation target for this step:
   - parse checks and editor diagnostics on touched files,
   - marker OFF/ON smoke for `comparison_plot` with perturbation checks,
   - verify new fields populate action rows without duplicate marker storms,
   - if dedupe/churn risk appears high, reduce marker surface before strict pair.

5. Implementation/debugging refinements completed in this step:
   - startup blocker fix in `Programs/app_source/server/04_comparison_plots.R`:
      - guarded non-render-body observer against transient empty `data_source_choice` state,
      - switched observer to `ignoreInit=TRUE` for startup safety,
      - resolved startup failure (`Error in if: argument is of length zero`) on the `comparison_plot_base_cache_key()` path.
   - marker emission cleanup:
      - removed duplicate dual-write `client_perf` path so `log_client_perf(...)` is preferred and fallback to `runtime_perf_record(...)` is used only when needed,
      - removed duplicate `output_outcome` payload key to prevent ambiguous `.1` serialization fields.
   - dedupe refinement:
      - added tab-visit epoch state so dedupe keys remain stable within a tab visit but allow one emission on later revisits,
      - this prevents premature suppression of `Current vs. Average` revisit provenance while keeping emissions bounded.
   - probe attribution fix in `System/Testing/vp_perf_probe_single_action_latency.R`:
      - cache-key marker rows lack `action_elapsed_ms`, so strict action-window filtering could drop them,
      - added nearest-event selection for `boundary_comparison_cache_key_evaluated` per tab action (target-output and tab scoped), then mapped provenance fields from that selected event.

6. Final validation executed (rerun5, exact artifacts):
   - parse + diagnostics:
      - `PARSE_OK_04` (`Programs/app_source/server/04_comparison_plots.R`),
      - `PARSE_OK_PROBE` (`System/Testing/vp_perf_probe_single_action_latency.R`),
      - editor diagnostics: no errors in touched files.
   - marker OFF smoke:
      - `Logs/vp_perf_probe_single_action_latency_tranche8i_comparison_delivery_marker_smoke_off_implstart_rerun5_20260806T174542Z.csv`,
      - `Logs/vp_runtime_perf_single_action_tranche8i_comparison_delivery_marker_smoke_off_implstart_rerun5_20260806T174542Z.jsonl`,
      - status: `PASS=4`,
      - `boundary_comparison_cache_key_evaluated` count: `0`.
   - marker ON smoke:
      - `Logs/vp_perf_probe_single_action_latency_tranche8i_comparison_delivery_marker_smoke_on_implstart_rerun5_20260806T174852Z.csv`,
      - `Logs/vp_runtime_perf_single_action_tranche8i_comparison_delivery_marker_smoke_on_implstart_rerun5_20260806T174852Z.jsonl`,
      - status: `PASS=4`,
      - `boundary_comparison_cache_key_evaluated` count: `10`.

7. ON-row provenance verification (`tab_settled_current`, `comparison_plot`):
   - `target_output_id=comparison_plot`,
   - `surface=comparison_cache_key`,
   - `phase=cache_key_eval`,
   - `active_gate_outcome=active`,
   - `fires_when=cache_key_eval`,
   - `guard_name=comparison_plot_bindcache_key`,
   - `reason_code=deduped_cache_key_eval`,
   - cache-key fields populated (example from selected row): `cache_key_source=vp_trade`, `cache_key_metric=ytd_exports`, `cache_key_country=GRAND_TOTAL`, `cache_key_commodity=All`, `cache_key_frequency=monthly`.

8. Emission-volume note (diagnostic posture):
   - ON runtime distribution for `boundary_comparison_cache_key_evaluated`: `Current vs. Average=6`, `Historical Trend=1`, `Heatmap=1`, `Map=2`.
   - this remains bounded for smoke and did not produce startup regressions or PASS degradation, but indicates cross-tab cache-key observer activity that should be considered when choosing the next narrow provenance slice.

9. Gate outcome:
   - 8I-20 validation gate passed,
   - tranche remains diagnostic-only with no behavior optimization promotion,
   - next action is to select the next inventory-guided non-render-body delivery-provenance marker slice (or tighten observer scope if cross-tab noise is judged too high for strict-pair interpretation).

## Planning Update (8I-21)

1. Recent evidence reassessment:
   - 8I-19 corrected the earlier broad output/materialization label for Current vs. Average:
      - target `comparison_plot` `shiny:value` arrives late, around `8.5-9.1` seconds after the action in the strict `tranche8i_output_materialization_i9` cohort,
      - once the browser receives the target value, widget insertion and main SVG insertion are immediate or near-immediate,
      - Plotly `afterplot`, loading-cleared, and diagnostic useful-ready follow quickly, roughly `35-44` ms after target value receipt,
      - therefore browser Plotly materialization after target value receipt is not the dominant owner of the Current wait.
   - 8I-20 made the first non-render-body delivery-provenance surface observable:
      - `boundary_comparison_cache_key_evaluated` is feature-gated and absent when markers are OFF,
      - ON smoke produced bounded marker volume (`10` total marker rows) and populated `tab_settled_current` provenance fields,
      - the selected Current row carried `target_output_id=comparison_plot`, `surface=comparison_cache_key`, `phase=cache_key_eval`, `active_gate_outcome=active`, `guard_name=comparison_plot_bindcache_key`, and cache-key context fields.
2. Conclusion from 8I-19 plus 8I-20:
   - the dominant Current delay is upstream of browser materialization and before target `comparison_plot` value delivery,
   - cache-key evaluation is now observable and attributable enough for smoke-level provenance,
   - 8I-20 does not yet prove cache-key evaluation causes the delay because cache-key marker rows can lack `action_elapsed_ms` and currently rely on nearest-event selection by target output, tab, and timestamp/order,
   - marker presence alone is not a repair signal and not an ownership conclusion.
3. Remaining technical uncertainty:
   - whether the cache-key marker can be joined to a single action instance using exact action identity (`action_id`/`mutation_seq` or request equivalents),
   - whether any cache-key timing can be expressed on the same client action clock as target `shiny:value`,
   - whether server/runtime timestamp ordering is the only available provenance for this server-side observer,
   - whether multiple cache-key candidates in the same action window could hide an early-evaluation-plus-delayed-delivery pattern behind a selected-latest heuristic,
   - whether bounded cross-tab cache-key observer activity (`Current vs. Average=6`, `Historical Trend=1`, `Heatmap=1`, `Map=2` in ON smoke) affects strict-cohort interpretation.
4. 8I-21 objective:
   - before another strict cohort or any repair, refine the cache-key provenance evidence standard so each Current action reports action-join confidence, clock basis, candidate count, earliest/latest/selected cache-key timing or ordering, and a cache-key-to-value gap only when clock-compatible.
5. 8I-21 non-goals:
   - no repair,
   - no `bindCache(...)` changes,
   - no marker emission inside `comparison_plot_base_cache_key()` or `comparison_plot_extension_cache_key()`,
   - no output definition changes,
   - no hidden-output warming,
   - no readiness predicate changes,
   - no resize behavior changes,
   - no decomposition/threshold changes,
   - no expansion to Historical Trend, Map, or Heatmap.
6. Required field semantics for the next implementation pass:
   - `action_elapsed_ms`: client action-clock elapsed value when present on runtime rows,
   - `client_action_elapsed_ms`: fallback client action-clock elapsed value used by some server-ingested client payload paths,
   - `cache_key_eval_action_ms`: only a true client action-clock elapsed value for the selected cache-key marker; never server-inferred elapsed,
   - `cache_key_earliest_action_ms`, `cache_key_latest_action_ms`, `cache_key_selected_action_ms`: action-clock values only when `clock_basis = same_client_clock`,
   - `cache_key_earliest_epoch_ms`, `cache_key_latest_epoch_ms`, `cache_key_selected_epoch_ms`: runtime timestamp ordering fields when action-clock values are unavailable,
   - `cache_key_eval_to_value_gap_ms`: computed only when both sides use compatible action-clock elapsed values,
   - `cache_key_candidate_count`: number of target-output/same-action-or-window candidates considered for the Current action,
   - `cache_key_selection_reason`: deterministic reason for selected candidate.
7. Required join and clock labels:
   - join confidence values: `strong_exact_action_join`, `medium_action_window_join`, `weak_timestamp_only`, `no_marker`,
   - clock basis values: `same_client_clock`, `strong_exact_action_join_no_elapsed`, `server_epoch_inferred`, `mixed_or_unknown`, `weak_timestamp_only`.
8. Deterministic attribution contract:
   - prefer exact action-instance joins over timestamp-nearest attribution,
   - build the cache-key candidate set using exact action id/mutation when available,
   - otherwise use a medium action window from action start minus `250 ms` through target `shiny:value` plus `250 ms`,
   - otherwise fall back to weak timestamp-only attribution,
   - always report candidate count, earliest candidate, latest candidate, and selected candidate,
   - when multiple candidates exist, selected-latest-before-value may be retained for legacy comparability, but ownership interpretation must use earliest/latest distributions as well.
9. Candidate integrity checks for 8I-21:
   - `cache_key_candidate_count >= 1` when a marker exists,
   - selected candidate belongs to the earliest/latest envelope where comparable,
   - `cache_key_selection_reason` is populated when `cache_key_candidate_count > 1`,
   - `same_client_clock` is allowed only when a real action-clock elapsed source exists,
   - `weak_timestamp_only` and server-inferred timing cannot produce ownership-decisive gap values.
10. Validation gates before any strict cohort:
   - parse checks and editor diagnostics must pass for every touched file,
   - marker OFF smoke must keep `boundary_comparison_cache_key_evaluated` count at `0`,
   - marker ON smoke must remain bounded, produce at least one `boundary_comparison_cache_key_evaluated` candidate for `tab_settled_current`, preserve existing 8I-20 cache-key fields, and populate tranche-critical join/clock/candidate schema fields,
   - the probe must not silently fill all new tranche-critical fields with `NA`,
   - existing output/materialization fields must remain populated as before.
11. Strict-cohort interpretation gate:
   - ownership interpretation requires at least `90%` of all Current action rows in the strict cohort denominator, including missing-marker rows, to have `strong_exact_action_join` or `medium_action_window_join`,
   - rows with `weak_timestamp_only`, `mixed_or_unknown`, `no_marker`, or uncomputable clock basis must be excluded from ownership conclusions and counted as non-qualifying.
12. Decision rules after 8I-21 evidence:
   - if earliest/latest cache-key evaluation is close to the action while target `shiny:value` remains much later in the same cohort, cache-key evaluation is probably not the dominant owner and the next target becomes Shiny output scheduling/cache-hit delivery after key evaluation,
   - if earliest/latest cache-key evaluation is itself late and near target `shiny:value`, the next diagnostic target becomes late invalidation or late scheduling of cache-key dependencies,
   - if earliest is early but latest is late, treat the result as repeated invalidation/cross-tab/dependency churn until candidate counts and selection reasons explain the Current action,
   - if confidence coverage remains below the `90%` gate, do not choose a repair; add one narrower provenance marker where the chain breaks.
13. Handoff status:
   - 8I-21 implementation is complete and remains diagnostic-only,
   - exact 8I-20 field inspection confirmed that selected `boundary_comparison_cache_key_evaluated` rows may carry `request_action_reason` but can lack exact `action_id`, `mutation_seq`, and same-clock elapsed fields,
   - probe attribution now reports deterministic candidate-set evidence (`join_confidence`, `clock_basis`, candidate count, selection reason, earliest/latest/selected ordering fields) while preserving OFF/ON marker neutrality,
   - same-clock cache-key-to-value gaps remain intentionally `NA` when client action-clock elapsed is unavailable; no synthetic same-clock timing is inferred from server epoch order.

## Execution Update (8I-21)

1. Scope implemented (narrow diagnostic-only refinement):
   - no behavior changes to `bindCache(...)`, output semantics, readiness predicates, decomposition rules, thresholds, or resize behavior,
   - no instrumentation added inside cache-key helper functions,
   - edits limited to `Programs/app_source/server/04_comparison_plots.R` and `System/Testing/vp_perf_probe_single_action_latency.R`.
2. Server-side refinement in `Programs/app_source/server/04_comparison_plots.R`:
   - extended `boundary_comparison_cache_key_evaluated` payload with:
      - `cache_key_eval_action_reason`,
      - `clock_basis = server_epoch_inferred`,
   - preserved deduped observer behavior and tab-visit epoch churn controls from 8I-20.
3. Probe/parser refinement in `System/Testing/vp_perf_probe_single_action_latency.R`:
   - fixed vector/scalar normalization defect in cache-key candidate matching:
      - replaced scalar `clean_id_value(...)` use on vector fields with row-wise `normalize_id_vector(...)`.
   - expanded result-row mapping for 8I-21 tranche-critical fields:
      - `cache_key_eval_join_confidence`, `cache_key_eval_clock_basis`, `cache_key_candidate_count`,
      - `cache_key_selection_reason`,
      - `cache_key_earliest_action_ms`, `cache_key_latest_action_ms`, `cache_key_selected_action_ms`,
      - `cache_key_earliest_epoch_ms`, `cache_key_latest_epoch_ms`, `cache_key_selected_epoch_ms`,
      - `cache_key_eval_to_value_gap_ms` with explicit same-clock gating.
   - retained deterministic candidate selection contract:
      - exact action-id/request-id candidate preference when available,
      - medium action-window fallback,
      - weak timestamp-only fallback with explicit labeling.
4. Defect encountered and corrected during implementation:
   - OFF smoke initially failed CSV write with `unimplemented type 'list' in 'EncodeElement'`,
   - root cause: `cache_key_candidate_count` was assigned per-row but not predeclared in required integer columns,
   - fix: added `cache_key_candidate_count` to `required_int_columns`, restoring scalar integer column semantics and CSV write compatibility.
5. Validation executed:
   - parse checks:
      - `PARSE_OK_04` (`Programs/app_source/server/04_comparison_plots.R`),
      - `PARSE_OK_PROBE` (`System/Testing/vp_perf_probe_single_action_latency.R`),
   - editor diagnostics: no errors in touched files,
   - OFF smoke (`--perf-boundary-markers=false`):
      - `Logs/vp_perf_probe_single_action_latency_tranche8i_output_materialization_timing_anchor_smoke_off_impl2_20260806T182555Z.csv`,
      - `Logs/vp_runtime_perf_single_action_tranche8i_output_materialization_timing_anchor_smoke_off_impl2_20260806T182555Z.jsonl`,
      - status: `PASS=4`,
      - `tab_settled_current`: `cache_key_eval_join_confidence=no_marker`, `cache_key_eval_clock_basis=no_marker`, `cache_key_candidate_count=0`.
   - ON smoke (`--perf-boundary-markers=true`):
      - `Logs/vp_perf_probe_single_action_latency_tranche8i_output_materialization_timing_anchor_smoke_on_impl2_20260806T182826Z.csv`,
      - `Logs/vp_runtime_perf_single_action_tranche8i_output_materialization_timing_anchor_smoke_on_impl2_20260806T182826Z.jsonl`,
      - status: `PASS=4`,
      - `tab_settled_current`: `cache_key_eval_join_confidence=weak_timestamp_only`, `cache_key_eval_clock_basis=server_epoch_inferred`, `cache_key_candidate_count=6`, `cache_key_selection_reason=latest_before_value_with_multiple_candidates`, `request_action_reason=tab_click:Current vs. Average`, `cache_key_eval_action_reason=tab_click:Current vs. Average`.
6. Interpretation and gate impact:
   - 8I-21 succeeded at attribution transparency (confidence labels, clock labels, candidate-envelope evidence) and preserved marker neutrality/performance smoke health,
   - selected Current rows still lack exact action identity (`request_action_id`/`request_mutation_seq`) and same-clock action elapsed for cache-key events,
   - therefore `cache_key_eval_action_ms`, action-clock earliest/latest/selected values, and `cache_key_eval_to_value_gap_ms` remain intentionally `NA` in this cohort,
   - ownership remains diagnostic-only; no repair promotion is allowed from this evidence alone.
7. Next diagnostic decision gate after 8I-21:
   - if strict-cohort Current coverage reaches the required confidence threshold (`strong_exact_action_join` or `medium_action_window_join`) using this schema, proceed to strict interpretation,
   - otherwise add one narrower provenance micro-step at the chain break where exact action identity or same-clock elapsed is currently absent.

## Execution Update (8I-22)

1. Scope implemented (diagnostic-only observable downstream provenance):
   - no `bindCache(...)` changes,
   - no output definition behavior changes,
   - no hidden-output warming,
   - no `outputOptions(...)` changes,
   - no readiness predicate changes,
   - no resize behavior changes,
   - no decomposition/threshold changes,
   - no expansion beyond `comparison_plot`.
2. Server implementation in `Programs/app_source/server/04_comparison_plots.R`:
   - added bounded flush-cycle marker state (`comparison_flush_marker_seen`) reset on tab-visit epoch changes,
   - hardened `emit_comparison_plot_boundary(...)` payload merge so explicit details override defaults without duplicate key ambiguity,
   - added `register_flush_cycle_observed_marker(...)` with:
      - marker gate short-circuit when boundary markers are disabled,
      - dedupe key scoped to tab/source/visit epoch/output outcome,
      - bounded state reset guard to avoid unbounded growth,
      - `session$onFlushed(..., once=TRUE)` emission path,
      - explicit `observability_class = flush_cycle_observed`, `flush_scope = session_flush_cycle`, and guard/reason fields,
      - explicit tab/action context captured at registration time and passed as payload.
   - invoked bounded flush-cycle registration on all `comparison_plot` return paths:
      - active gate skip,
      - empty state return,
      - normal plot return.
3. Probe/parser implementation in `System/Testing/vp_perf_probe_single_action_latency.R`:
   - extended `parse_runtime_server_output_anchor_events(...)` to parse `observability_class`, `flush_scope`, and `output_anchor_clock`,
   - added marker tag coverage for `boundary_server_output_flush_cycle_observed`,
   - added downstream output fields with schema predeclaration:
      - `output_flush_cycle_observed_ms`,
      - `output_flush_cycle_observability_class`,
      - `output_flush_cycle_scope`,
      - `output_flush_cycle_join_confidence`,
      - `output_flush_cycle_clock_basis`,
      - `output_flush_cycle_marker_count`,
      - `output_downstream_marker_missing_reason`,
      - `downstream_render_body_outcome`,
      - `downstream_render_body_marker_count`,
   - implemented explicit missing-reason logic for absent downstream markers,
   - added downstream schema non-list assertions before CSV write path,
   - preserved existing 8I-21 cache-key join/clock/candidate fields and existing output/materialization fields.
4. Validation executed (final pair on final code state):
   - parse checks:
      - `PARSE_OK_04` (`Programs/app_source/server/04_comparison_plots.R`),
      - `PARSE_OK_PROBE` (`System/Testing/vp_perf_probe_single_action_latency.R`),
   - editor diagnostics: no errors in touched files,
   - OFF smoke:
      - `Logs/vp_perf_probe_single_action_latency_tranche8i_comparison_observable_downstream_smoke_off_rerun1_20260806T193343Z.csv`,
      - `Logs/vp_runtime_perf_single_action_tranche8i_comparison_observable_downstream_smoke_off_rerun1_20260806T193343Z.jsonl`,
      - `PASS=4`,
      - `boundary_server_output_flush_cycle_observed` count `0`,
      - `boundary_comparison_cache_key_evaluated` count `0`.
   - ON smoke:
      - `Logs/vp_perf_probe_single_action_latency_tranche8i_comparison_observable_downstream_smoke_on_rerun1_20260806T192830Z.csv`,
      - `Logs/vp_runtime_perf_single_action_tranche8i_comparison_observable_downstream_smoke_on_rerun1_20260806T192831Z.jsonl`,
      - `PASS=4`,
      - `boundary_server_output_flush_cycle_observed` count `0`,
      - `boundary_comparison_cache_key_evaluated` count `10`.
5. ON evidence snapshot for Current (`tab_settled_current`):
   - `output_flush_cycle_marker_count=0`,
   - `output_downstream_marker_missing_reason=cache_hit_or_body_bypass_possible`,
   - `downstream_render_body_outcome=NA`,
   - `downstream_render_body_marker_count=0`,
   - `cache_key_eval_join_confidence=weak_timestamp_only`,
   - `cache_key_eval_clock_basis=server_epoch_inferred`,
   - `cache_key_candidate_count=6`.
6. Interpretation and gate impact:
   - implementation succeeded technically (schema, parser, smoke health, marker gating, and explicit missing-reason reporting),
   - in this smoke pair, observable downstream render/flush markers were not recovered for Current and are now explicitly classified as likely cache-hit/body-bypass context rather than silent NA,
   - ownership remains diagnostic-only and unresolved;
   - next diagnostic target should move to a narrower non-render-body output invalidation/scheduling provenance marker at the post-cache-key/pre-`shiny:value` break.

## Execution Update (8I-23)

1. Scope implemented (diagnostic-only post-cache-key/pre-`shiny:value` provenance):
   - no `bindCache(...)` changes,
   - no cache-key expression changes,
   - no output definition behavior changes,
   - no hidden-output warming,
   - no `outputOptions(...)` changes,
   - no readiness predicate changes,
   - no resize behavior changes,
   - no decomposition/threshold changes,
   - no expansion beyond `comparison_plot`.
2. Server implementation in `Programs/app_source/server/04_comparison_plots.R`:
   - added bounded post-cache flush marker state (`comparison_cache_flush_marker_seen`) reset with the tab-visit epoch state,
   - added `emit_comparison_server_output_anchor(...)` for non-render-body observable server anchors,
   - added `register_comparison_cache_flush_observed_marker(...)` with marker gating, cache-key-scoped dedupe, `session$onFlushed(..., once = TRUE)` registration outside the render body, and explicit post-cache observability/clock/guard fields,
   - invoked the post-cache flush registration immediately after `boundary_comparison_cache_key_evaluated` emission in the cache-key observer path.
3. Probe/parser implementation in `System/Testing/vp_perf_probe_single_action_latency.R`:
   - added post-cache-key output fields for elapsed timing, marker count, observability class, scope, join confidence, clock basis, and missing reason,
   - parsed and preserved `cache_flush_registration_key`,
   - kept old render-body flush-cycle fields scoped to `boundary_server_output_flush_cycle_observed` only so `output_flush_cycle_marker_count` is not polluted by the new post-cache marker,
   - attributed post-cache markers from all server anchors for the same `comparison_plot`/tab/action window, independent of whether render-body downstream markers existed,
   - widened only the post-cache server-anchor pre-action tolerance to 1000 ms to preserve observed client/server clock skew near the action boundary,
   - preserved explicit clock labels and join confidence (`medium_action_window_join`, `server_elapsed_ms`) rather than treating the marker as same-clock client action evidence.
4. Parser bug found and fixed during validation:
   - first smoke pair passed (`PASS=4` OFF and ON) and showed marker gating was correct, but the ON Current CSV row did not join the runtime post-cache marker,
   - inspection showed ON runtime emitted 10 `boundary_comparison_post_cache_key_flush_observed` markers and 6 were for `Current vs. Average`, so the absence was parser attribution, not server marker absence,
   - local fixes separated the new marker from the old downstream flush bucket, moved candidate selection outside the older render-flush guard, and preserved a small negative cross-clock offset instead of dropping it as `NA`,
   - no-main re-augmentation of the existing ON artifact confirmed the fix before the final smoke pair: Current joined one post-cache marker at `-330 ms` versus browser value receipt at `10427 ms`.
5. Validation executed (final pair on final code state):
   - parse checks: `PARSE_OK_PROBE`; prior post-edit `PARSE_OK_04` remained clean,
   - editor diagnostics: no errors in touched R files,
   - OFF smoke: `Logs/vp_perf_probe_single_action_latency_tranche8i_comparison_post_cache_flush_smoke_off_rerun2_20260806T200835Z.csv`; `Logs/vp_runtime_perf_single_action_tranche8i_comparison_post_cache_flush_smoke_off_rerun2_20260806T200836Z.jsonl`; `PASS=4`; post-cache marker count `0`; cache-key marker count `0`,
   - ON smoke: `Logs/vp_perf_probe_single_action_latency_tranche8i_comparison_post_cache_flush_smoke_on_rerun2_20260806T201158Z.csv`; `Logs/vp_runtime_perf_single_action_tranche8i_comparison_post_cache_flush_smoke_on_rerun2_20260806T201158Z.jsonl`; `PASS=4`; post-cache marker count `10`; cache-key marker count `10`.
6. ON evidence snapshot for Current (`tab_settled_current`):
   - `status=PASS`, `visible_ready_ms=11334`, `client_interaction_ready_ms=11364`, `full_idle_ms=12598`,
   - `timeline_shiny_value_output_ms=11101`, `output_client_value_received_ms=11139`,
   - `cache_key_candidate_count=6`, `cache_key_eval_join_confidence=weak_timestamp_only`, `cache_key_eval_clock_basis=server_epoch_inferred`,
   - `output_post_cache_key_flush_observed_ms=-276`, `output_post_cache_key_flush_marker_count=1`, `output_post_cache_key_flush_join_confidence=medium_action_window_join`, `output_post_cache_key_flush_clock_basis=server_elapsed_ms`, `output_post_cache_key_marker_missing_reason=NA`,
   - `output_flush_cycle_marker_count=0`, `output_downstream_marker_missing_reason=cache_hit_or_body_bypass_possible`.
7. Interpretation and gate impact:
   - the cheapest discriminating check produced the needed signal,
   - the `comparison_plot` cache-key observer can register an observable server flush boundary around the action window even when render-body downstream markers remain absent,
   - in the final Current row, that post-cache-key flush boundary appears near the start of the action window (`-276 ms`, medium action-window join) while browser `shiny:value` receipt is still late (`11139 ms`),
   - therefore the remaining wait is unlikely to be downstream browser/Plotly materialization and is also not explained by absence of an observable server flush boundary after cache-key evaluation,
   - the unresolved owner is now narrower: output invalidation/scheduling/cache-hit delivery between the post-cache-key flush boundary and browser `shiny:value` delivery,
   - ownership remains diagnostic-only; no repair promotion is allowed from this smoke alone,
   - next step should be a strict replicated diagnostic cohort using this marker schema before any behavioral repair is proposed.

## Execution Plan (8I-24)

1. Scope and intent:
   - run a strict replicated ON diagnostic cohort for the 8I-23 post-cache-key/pre-`shiny:value` marker chain,
   - this is not an optimization pass and not a strict OFF/ON perturbation test,
   - prior OFF/ON smoke remains the marker-neutrality guardrail,
   - 8I-24 objective is reproducibility and attribution-quality, not repair.
2. Strict pair command shape:
   - label: `tranche8i_comparison_post_cache_flush_i9`,
   - runner: `System/Testing/vp_perf_run_acceptance_pair.R`,
   - controls: clean-room manifest, strict manifest validation, strict context validation, strict runtime identity validation, acceptance-only mode, warm partition disk lanes, unchanged thresholds,
   - explicit runner path: `--rscript="C:/Program Files/R/R-4.5.1/bin/Rscript.exe"`.
3. Preflight gates before strict run:
   - parse checks must pass for:
      - `Programs/app_source/server/04_comparison_plots.R`,
      - `System/Testing/vp_perf_probe_single_action_latency.R`,
   - editor diagnostics must be clean for touched files.
4. Exact-path artifact capture rules:
   - capture emitted strict-run paths from terminal output and verify each path exists before downstream use,
   - required strict artifacts:
      - clean-room run manifest CSV and JSONL,
      - decision CSV,
      - decision summary CSV,
      - decision details CSV,
      - relevant runtime/output paths,
   - no unconstrained latest-file discovery.
5. Mandatory acceptance-index bootstrap before Step 25A:
   - create an explicit index CSV from strict artifacts,
   - required columns:
      - `lane`,
      - `pair_run_label`,
      - `clean_room_manifest_csv`,
      - `decision_summary_csv`,
      - `decision_details_csv`,
      - `decision_file_csv`,
   - verify required columns and file existence before Step 25A.
6. Exact-path evidence stack execution:
   - Step 25A inventory:
      - `System/Testing/vp_perf_acceptance_manifest_to_inventory.R` with exact `--index`,
   - Step 25B validation:
      - `System/Testing/vp_perf_validate_inventory_step25b_8c.R`,
   - Step 25C decomposition:
      - `System/Testing/vp_perf_decompose_single_action_8c.R`,
   - Step 25D attribution audit with all required Step 25C outputs:
      - `--detail`,
      - `--summary`,
      - `--runs`,
      - `--window-confidence`,
      - `--inconclusive-gate`,
   - Step 25C rollup:
      - `System/Testing/vp_perf_step25c_bucket_rollup_8c.R` with exact `runs` and `summary`.
7. Step 25F Current view gate and fallback:
   - run `System/Testing/vp_perf_step25f_output_materialization_phase_view_8i.R` only after:
      - Step 25B confirms no quarantined single-action rows,
      - all selected `output_csv_path` files exist,
   - target:
      - `--target-tab="Current vs. Average"`,
      - `--target-output-id=comparison_plot`,
   - if Step 25F fails due missing output CSVs or non-unique Current/`comparison_plot` rows, produce the marker-quality summary directly from strict probe CSV/runtime JSONL paths first; helper extension is optional and must remain narrow.
8. Marker-quality metric source contract:
   - probe CSV authoritative fields:
      - `output_post_cache_key_flush_marker_count`,
      - `output_post_cache_key_flush_join_confidence`,
      - `output_post_cache_key_flush_clock_basis`,
      - `output_post_cache_key_marker_missing_reason`,
      - `output_post_cache_key_flush_observed_ms`,
      - `output_client_value_received_ms`,
      - `cache_key_candidate_count`,
      - `cache_key_eval_join_confidence`,
      - `cache_key_eval_clock_basis`,
      - `output_flush_cycle_marker_count`,
      - `output_downstream_marker_missing_reason`,
   - Step 25F authoritative phase field example:
      - `timeline_target_shiny_value_ms` and corrected post-value browser gaps,
   - runtime JSONL authoritative for raw marker counts and payload sanity.
9. Field-existence gate before aggregation:
   - verify each required field exists in its declared source before summary generation,
   - do not silently substitute similarly named fields across sources (for example `timeline_shiny_value_output_ms` versus Step 25F `timeline_target_shiny_value_ms`).
10. Interpretation gate before naming a repair-search target:
   - require at least 90% of strict Current rows to have `output_post_cache_key_flush_join_confidence` of `medium_action_window_join` or better,
   - require bounded marker counts and non-missing critical fields,
   - rows with `weak_timestamp_only`, `mixed_or_unknown`, `no_marker`, or blank critical fields are non-qualifying,
   - if gate fails, stop and add/refine one narrower provenance marker; do not repair.
11. Decision-output caution:
   - acceptance decision files in this tranche are strict-run integrity/context artifacts first and performance artifacts second because both lanes are diagnostic/unchanged behavior,
   - do not infer optimization success or failure from acceptance decision output alone.
12. Ledger expectations while executing 8I-24:
   - record every command, emitted artifact, existence check, failure/rerun, and fallback path,
   - keep exact paths only,
   - include final plain-language conclusion in this file.

## Execution Update (8I-24)

1. Scope executed:
   - strict replicated ON diagnostic cohort for post-cache-key provenance reproducibility only,
   - no behavior changes and no repair,
   - `comparison_plot` focus preserved.
2. Preflight validation:
   - `PARSE_OK_04` and `PARSE_OK_PROBE` passed,
   - editor diagnostics were clean for touched files.
3. Strict cohort execution (`tranche8i_comparison_post_cache_flush_i9`):
   - run manifest emitted:
      - `Logs/vp_perf_acceptance_run_manifest_tranche8i_comparison_post_cache_flush_i9_20260806T203836Z.csv`,
      - `Logs/vp_perf_acceptance_run_manifest_tranche8i_comparison_post_cache_flush_i9_20260806T203836Z.jsonl`,
   - strict preflight in runner:
      - manifest rows `36/36`,
      - context `PASS`,
      - runtime identity `PASS`,
   - decision artifacts emitted:
      - `Logs/vp_perf_acceptance_decision_tranche8i_comparison_post_cache_flush_i9__decision_20260806T215240Z_decision.csv`,
      - `Logs/vp_perf_acceptance_decision_tranche8i_comparison_post_cache_flush_i9__decision_20260806T215240Z_summary.csv`,
      - `Logs/vp_perf_acceptance_decision_tranche8i_comparison_post_cache_flush_i9__decision_20260806T215240Z_details.csv`.
4. Index bootstrap and path verification:
   - created exact-path index:
      - `Logs/vp_perf_acceptance_index_tranche8i_off_on_i9_comparison_post_cache_flush_20260806.csv`,
   - required columns present:
      - `lane`, `pair_run_label`, `clean_room_manifest_csv`, `decision_summary_csv`, `decision_details_csv`, `decision_file_csv`,
   - referenced path checks passed (`INDEX_MISSING_PATH_COUNT=0`).
5. Exact-path evidence stack:
   - Step 25A inventory:
      - `Logs/vp_perf_acceptance_inventory_tranche8i_off_on_i9_comparison_post_cache_flush_inventory_20260806T215313Z.csv`,
      - `OK_ROWS=72`, `QUARANTINE_ROWS=0`,
   - Step 25B validation:
      - `Logs/vp_perf_acceptance_inventory_validation_tranche8i_off_on_i9_comparison_post_cache_flush_validation_20260806T215317Z_summary.csv`,
      - `OK_ROWS=72`, `QUARANTINE_ROWS=0`,
   - Step 25C decomposition:
      - `Logs/vp_perf_acceptance_decomposition_tranche8i_off_on_i9_comparison_post_cache_flush_decomp_20260806T215323Z_detail.csv`,
      - `Logs/vp_perf_acceptance_decomposition_tranche8i_off_on_i9_comparison_post_cache_flush_decomp_20260806T215323Z_runs.csv`,
      - `Logs/vp_perf_acceptance_decomposition_tranche8i_off_on_i9_comparison_post_cache_flush_decomp_20260806T215323Z_summary.csv`,
      - `Logs/vp_perf_acceptance_decomposition_tranche8i_off_on_i9_comparison_post_cache_flush_decomp_20260806T215323Z_window_confidence.csv`,
      - `Logs/vp_perf_acceptance_decomposition_tranche8i_off_on_i9_comparison_post_cache_flush_decomp_20260806T215323Z_inconclusive_gate.csv`,
      - decomposition reported `SELECTED_ROWS=36`, `DETAIL_ROWS=24660`, `RUN_ROWS=36`,
   - Step 25D audit:
      - `Logs/vp_perf_acceptance_decomposition_tranche8i_off_on_i9_comparison_post_cache_flush_audit_20260806T220056Z_audit_summary.json`,
   - Step 25C rollup:
      - `Logs/vp_perf_acceptance_decomposition_tranche8i_off_on_i9_comparison_post_cache_flush_rollup_20260806T220058Z_action_bucket.csv`.
6. Current-specific phase view:
   - `Logs/vp_perf_output_materialization_phase_view_tranche8i_comparison_post_cache_flush_i9_current_phase_view_20260806T220113Z_action_rows.csv`,
   - `Logs/vp_perf_output_materialization_phase_view_tranche8i_comparison_post_cache_flush_i9_current_phase_view_20260806T220113Z_lane_summary.csv`,
   - `Logs/vp_perf_output_materialization_phase_view_tranche8i_comparison_post_cache_flush_i9_current_phase_view_20260806T220113Z_coverage.csv`,
   - helper reported `ROWS=18`, `ANCHOR_COMPLETE_ROWS=0`.
7. Strict Current marker-quality summary (probe CSV authoritative fields):
   - rows: `18` (`baseline=9`, `candidate=9`),
   - summary file:
      - `Logs/vp_perf_tranche8i_24_current_marker_quality_rows_20260806T2207Z.csv`,
   - post-cache marker count distribution:
      - `output_post_cache_key_flush_marker_count=1` for all `18/18` rows,
   - post-cache join-confidence distribution:
      - `medium_action_window_join` for `18/18` rows,
   - post-cache clock-basis distribution:
      - `server_elapsed_ms` for `18/18` rows,
   - downstream missing reason:
      - `cache_hit_or_body_bypass_possible` for `18/18` rows,
   - post-cache observed timing:
      - min `-599`, max `-194`, mean `-284` ms,
   - browser value timing:
      - `output_client_value_received_ms` min `7367`, max `13312`, mean `9258.8889` ms,
      - `timeline_shiny_value_output_ms` min `7323`, max `13252`, mean `9217.7778` ms,
   - cache-key context remained:
      - `cache_key_candidate_count=6` on Current rows,
      - cache-key join fields remained in weak/server-inferred class from earlier tranche logic.
8. Gate decision for 8I-24:
   - 90% Current join-confidence gate passed:
      - qualified rows `18/18` (`100%`),
   - marker counts were bounded and critical fields were present,
   - strict evidence reproduces the smoke signal: an observable post-cache boundary appears near the action boundary while browser target value remains much later.
9. Interpretation and next target:
   - this supports the narrowed repair-search target:
      - output invalidation/scheduling/cache-hit delivery between post-cache flush boundary and browser `shiny:value`,
   - post-value browser/Plotly materialization remains unlikely to be dominant in this chain,
   - still diagnostic-only: no repair promotion is allowed from this tranche by itself.
10. Decision-output caveat:
   - acceptance decision remained `FAIL` on performance thresholds, but in this tranche those outputs are strict-run integrity/context artifacts first and do not negate the diagnostic marker-quality conclusion above.

## Execution Plan (8I-25)

1. Scope and objective:
   - diagnostic-only targeted `comparison_plot` delivery-provenance tranche,
   - objective is observable delivery ordering after cache-key evaluation, not a direct scheduler/send-timing claim,
   - no repair, no optimization claim, no `bindCache(...)` change, no `outputOptions(...)` change, no hidden-output warming, no output behavior change, no readiness/resize/decomposition/threshold change.
2. Guard/helper inventory status:
   - 8I-13 already built a broad ownership-guided guard/helper inventory,
   - 8I-25 is not a broad re-inventory,
   - this step is a targeted `comparison_plot` delivery-lag guard/provenance pass focused on active eligibility, real Shiny flush ordering, cache/body-bypass outcomes, and cheap dependency snapshots.
3. Implementation anchors:
   - `Programs/app_source/server/04_comparison_plots.R`:
      - `is_current_vs_average_output_active()`,
      - `current_main_tab_safe()`,
      - cache-key observer emitting `boundary_comparison_cache_key_evaluated`,
      - `register_comparison_cache_flush_observed_marker(...)`,
      - `output$comparison_plot <- renderPlotly(...)`,
      - `emit_comparison_plot_boundary(...)`,
      - `register_flush_cycle_observed_marker(...)`,
      - `record_cache_body_execution(...)` outcome sites,
      - `bindCache(...)` key dimensions.
   - `System/Testing/vp_perf_probe_single_action_latency.R`:
      - runtime marker parsers,
      - `augment_result_with_wait_boundary_markers(...)`,
      - required scalar schema columns and downstream schema guards.
4. Emitter/parser field contract before strict interpretation:
   - every new field must have declared source marker/event, output column name, scalar type, default value, missing reason field, allowed values, `request_action_id` availability, `request_mutation_seq` availability, `action_reason` availability, `target_output_id`, `clock_basis`, and evidence class (`exact`, `medium_action_window`, or `order_only`),
   - no list columns are allowed in probe output,
   - clock basis must be recorded exactly and not silently promoted.
5. First implementation slice:
   - enrich existing feature-gated cache-key/onFlushed marker payloads rather than adding a broad observer,
   - add active eligibility result/reason fields around the cache-key observer,
   - add cheap scalar dependency snapshot fields available from existing cache-key values,
   - preserve honest cache/body-bypass labels unless a true cache-hit hook is found,
   - only call a marker `flush` when tied to actual `session$onFlushed(..., once = TRUE)`.
6. Parser/schema slice:
   - parse new payload fields into single-action rows,
   - predeclare all new row fields in `required_int_columns` or `required_char_columns`,
   - add explicit missing/unavailable reason fields,
   - preserve existing 8I-20 through 8I-24 fields.
7. Validation gates before smoke:
   - parse `Programs/app_source/server/04_comparison_plots.R`,
   - parse `System/Testing/vp_perf_probe_single_action_latency.R`,
   - editor diagnostics clean for touched files.
8. OFF smoke gate:
   - run `vp_perf_probe_single_action_latency.R` with markers OFF,
   - require `PASS=4`, no new 8I-25 marker tags in runtime JSONL, no ON-only fields populated except explicit defaults/missing values, and no loss of existing output/materialization/post-cache fields.
9. ON smoke gate:
   - run `vp_perf_probe_single_action_latency.R` with markers ON,
   - require `PASS=4`, bounded marker counts, exactly one Current/`comparison_plot` row, populated active eligibility fields, explicit dependency/invalidation reason fields, real `onFlushed` marker evidence when available, and no duplicate marker storms.
10. Stop conditions before strict cohort:
   - blank active eligibility fields without reasons,
   - unbounded marker counts,
   - OFF marker leakage,
   - list-typed dependency snapshots,
   - mislabeled clock basis,
   - cache-hit/body-bypass labels that overclaim direct truth,
   - no medium-or-better exploratory join for Current row.
11. Strict cohort if smoke passes:
   - label `tranche8i_comparison_delivery_provenance_i9`,
   - `--iterations=9`, runtime perf ON, markers ON, clean-room manifest, strict manifest/context/runtime identity validation, acceptance-only mode, warm partition disk lanes, unchanged thresholds, explicit Rscript path.
12. Exact-path chain after strict cohort:
   - verify emitted paths,
   - create validated index,
   - Step 25A inventory,
   - Step 25B validation with quarantine rows `0`,
   - Step 25C decomposition,
   - Step 25D audit,
   - Step 25C rollup,
   - Step25F for corrected browser `shiny:value` and post-value phase timing only.
13. Strict marker-quality gates:
   - eligibility completeness: at least `90%` of strict Current rows have explicit active/inactive result plus reason,
   - flush/onFlushed exploratory quality: at least `90%` have bounded marker counts, medium-or-better join, and explicit clock basis,
   - dependency snapshot quality: at least `90%` have scalar values or explicit unavailable/deferred reasons,
   - decisive repair gate: exact action identity or `candidate_count=1` is required for the marker family used decisively; medium action-window joins alone are exploratory and require one narrower marker before repair.
14. Narrow exact-action marker before strict cohort:
   - before running the strict replicated cohort, add one probe-owned exact action context marker path,
   - the single-action probe should send its exact `action_id`, target input/value, target output, and target tab to Shiny immediately before dispatching the action,
   - `comparison_plot` cache-key/onFlushed markers should attach that exact action context only when boundary markers are enabled and the context is locally applicable to the active tab/output,
   - emitted fields must remain scalar and must explicitly report `exact_action_context_status`, `exact_action_context_source`, `exact_action_context_evidence_class`, and `exact_action_context_missing_reason`,
   - the parser must treat matching marker `request_action_id`/row `action_id` as `strong_exact_action_join` while keeping clock basis honest,
   - if smoke shows the exact context is unavailable, stale, or still ambiguous, strict cohort remains blocked and interpretation stays exploratory.
15. Decision branches:
   - late/inactive eligibility points to tab/source/profile alignment or active-output gating,
   - early eligibility and early real onFlushed evidence with late `shiny:value` points to exploratory Shiny output delivery/cache-hit-body-bypass ordering after flush,
   - late dependency snapshots point to upstream reactive invalidation/state alignment,
   - late render-body execution points to render/data construction,
   - failed confidence gates point to one narrower marker, not repair.

## Execution Update (8I-25)

1. Scope implemented in first diagnostic slice:
   - behavior-neutral marker/schema enrichment only,
   - `comparison_plot` only,
   - no `bindCache(...)`, `outputOptions(...)`, hidden-output warming, output behavior, readiness, resize, decomposition, or threshold changes.
2. Server marker enrichment in `Programs/app_source/server/04_comparison_plots.R`:
   - enriched the existing cache-key observer payload for `boundary_comparison_cache_key_evaluated`,
   - enriched the existing `register_comparison_cache_flush_observed_marker(...)` payload for `boundary_comparison_post_cache_key_flush_observed`,
   - added scalar active eligibility fields:
      - `active_gate_result`,
      - `active_gate_reason`,
      - `active_gate_tab_safe`,
      - `active_gate_raw_tab`,
      - `active_gate_clock_basis`,
      - `active_gate_evidence_class`,
   - added scalar dependency snapshot fields:
      - `dependency_snapshot_status`,
      - `dependency_snapshot_reason`,
      - `dependency_snapshot_clock_basis`,
      - `dependency_snapshot_evidence_class`,
   - preserved the existing feature gate and existing marker volume controls.
3. Probe/parser enrichment in `System/Testing/vp_perf_probe_single_action_latency.R`:
   - parsed the new active eligibility and dependency snapshot fields from both `client_perf` and `server_output_anchor` runtime rows,
   - mapped the fields into single-action CSV rows,
   - predeclared the new fields as scalar character columns,
   - added them to the defensive downstream schema guard,
   - fixed a local parser defect exposed during smoke: `server_output_anchor` rows now preserve `clock_basis`, `request_action_reason`, `action_id`, `mutation_seq`, `request_action_id`, and `request_mutation_seq` so post-cache/onFlushed evidence does not silently fall back to `output_anchor_clock`.
4. Validation after edits:
   - parse check passed for `Programs/app_source/server/04_comparison_plots.R` (`PARSE_OK_04`),
   - parse check passed for `System/Testing/vp_perf_probe_single_action_latency.R` (`PARSE_OK_PROBE`),
   - editor diagnostics reported no errors for both touched files.
5. OFF smoke validation:
   - command label: `tranche8i_comparison_delivery_provenance_smoke_off`,
   - output CSV:
      - `Logs/vp_perf_probe_single_action_latency_tranche8i_comparison_delivery_provenance_smoke_off_20260807T134246Z.csv`,
   - runtime JSONL:
      - `Logs/vp_runtime_perf_single_action_tranche8i_comparison_delivery_provenance_smoke_off_20260807T134247Z.jsonl`,
   - result: `PASS=4`,
   - new fields existed in the CSV and were blank for all `4` rows while markers were OFF,
   - runtime marker leakage check found no `boundary_comparison_cache_key_evaluated`, `boundary_comparison_post_cache_key_flush_observed`, `active_gate_result`, or `dependency_snapshot_status` entries.
6. ON smoke validation:
   - first ON smoke passed but exposed the clock-basis parser defect described above,
   - final ON rerun label: `tranche8i_comparison_delivery_provenance_smoke_on_rerun1`,
   - output CSV:
      - `Logs/vp_perf_probe_single_action_latency_tranche8i_comparison_delivery_provenance_smoke_on_rerun1_20260807T135600Z.csv`,
   - runtime JSONL:
      - `Logs/vp_runtime_perf_single_action_tranche8i_comparison_delivery_provenance_smoke_on_rerun1_20260807T135600Z.jsonl`,
   - result: `PASS=4`,
   - marker counts remained bounded:
      - `boundary_comparison_cache_key_evaluated=10`,
      - `boundary_comparison_post_cache_key_flush_observed=10`.
7. Final ON Current row evidence (`tab_settled_current`, `comparison_plot`):
   - `active_gate_result=active`,
   - `active_gate_reason=active`,
   - `active_gate_tab_safe=Current vs. Average`,
   - `active_gate_raw_tab=Current vs. Average`,
   - `active_gate_clock_basis=server_epoch_inferred`,
   - `active_gate_evidence_class=medium_action_window`,
   - `dependency_snapshot_status=cache_key_snapshot_available`,
   - `dependency_snapshot_reason=cache_key_observer_snapshot`,
   - `dependency_snapshot_clock_basis=server_epoch_inferred`,
   - `dependency_snapshot_evidence_class=order_only`,
   - `output_post_cache_key_flush_marker_count=1`,
   - `output_post_cache_key_flush_join_confidence=medium_action_window_join`,
   - `output_post_cache_key_flush_clock_basis=server_epoch_inferred`,
   - `output_post_cache_key_flush_observed_ms=-249`,
   - `output_client_value_received_ms=8671`,
   - `timeline_shiny_value_output_ms=8656`,
   - `cache_key_candidate_count=6`,
   - `output_downstream_marker_missing_reason=cache_hit_or_body_bypass_possible`.
8. Interpretation and gate state:
   - first 8I-25 smoke gate passed after the parser clock-basis correction,
   - active eligibility is observable and active on the final Current smoke row,
   - dependency snapshot provenance is scalar and explicitly order-only,
   - post-cache/onFlushed evidence now preserves its true clock basis (`server_epoch_inferred`) rather than appearing as same-clock elapsed evidence,
   - evidence remains diagnostic-only and exploratory because cache-key candidate count is still `6` and join confidence remains medium/action-window based.
9. Next action:
   - user chose to add one narrower exact-action marker before strict cohort rather than proceed directly on exploratory medium-join evidence,
   - next implementation slice should add probe-owned exact action context to the cache-key/onFlushed marker path and require smoke evidence of `strong_exact_action_join` or an explicit unavailable/stale reason,
   - strict cohort label should remain `tranche8i_comparison_delivery_provenance_i9` after the exact-action smoke gate passes,
   - decisive repair remains disallowed unless later evidence supplies exact action identity or a single unambiguous candidate for the marker family used decisively.

## Execution Update (8I-25 Exact Action Marker)

1. Scope implemented:
   - added one narrower diagnostic-only exact-action marker path before strict cohort,
   - kept the slice feature-gated by `--perf-boundary-markers=true|false`,
   - no `bindCache(...)`, `outputOptions(...)`, hidden-output warming, output behavior, readiness, resize, decomposition, or threshold changes.
2. Probe-owned exact action context:
   - `System/Testing/vp_perf_probe_single_action_latency.R` now sends `vp_perf_probe_action_context` through browser-side `Shiny.setInputValue(...)` immediately before dispatching each measured action when boundary markers are ON,
   - the payload uses the probe CSV row `action_id` as the exact action identity and includes target input, target value, target output, target tab, context source, status, evidence class, and missing reason,
   - mutation sequence remains explicitly unavailable because the probe timeline does not currently own a per-action mutation sequence.
3. Server marker enrichment:
   - `Programs/app_source/server/04_comparison_plots.R` now reads the probe action context only when boundary markers are enabled,
   - the context is attached to existing `boundary_comparison_cache_key_evaluated` and real `boundary_comparison_post_cache_key_flush_observed` marker payloads only when locally applicable to `comparison_plot` and the active tab,
   - new scalar fields include:
      - `exact_action_context_status`,
      - `exact_action_context_source`,
      - `exact_action_context_evidence_class`,
      - `exact_action_context_missing_reason`,
      - `exact_action_context_target_id`,
      - `exact_action_context_target_value`,
      - `exact_action_context_target_output_id`,
      - `exact_action_context_target_tab`.
4. Parser/schema update:
   - parsed exact action context fields from both `client_perf` and `server_output_anchor` runtime rows,
   - added the fields to scalar output/schema guards,
   - tightened post-cache/onFlushed join classification so matching marker `request_action_id` and row `action_id` produce `strong_exact_action_join`, while clock basis remains unchanged.
5. Failed attempt and repair:
   - first ON smoke surfaced a local implementation defect: `shinytest2::set_inputs()` cannot set synthetic input `vp_perf_probe_action_context` without a DOM input binding,
   - repaired by sending the same payload with browser-side `Shiny.setInputValue(..., {priority: 'event'})`, then reran parse and smoke validation.
6. Validation:
   - parse check passed for `Programs/app_source/server/04_comparison_plots.R` (`PARSE_OK_04`),
   - parse check passed for `System/Testing/vp_perf_probe_single_action_latency.R` (`PARSE_OK_PROBE`),
   - editor diagnostics reported no errors for both touched R files before smoke, and no errors for the probe after the post-cache join repair.
7. OFF smoke validation:
   - command label: `tranche8i_exact_action_context_smoke_off`,
   - output CSV:
      - `Logs/vp_perf_probe_single_action_latency_tranche8i_exact_action_context_smoke_off_20260807T144255Z.csv`,
   - runtime JSONL:
      - `Logs/vp_runtime_perf_single_action_tranche8i_exact_action_context_smoke_off_20260807T144255Z.jsonl`,
   - result: `PASS=4`,
   - exact-action context fields were blank with markers OFF,
   - `cache_key_eval_join_confidence=no_marker`, `cache_key_candidate_count=0`, and marker leakage count was `0`.
8. Final ON smoke validation:
   - final ON rerun label: `tranche8i_exact_action_context_smoke_on_rerun2`,
   - output CSV:
      - `Logs/vp_perf_probe_single_action_latency_tranche8i_exact_action_context_smoke_on_rerun2_20260807T145623Z.csv`,
   - runtime JSONL:
      - `Logs/vp_runtime_perf_single_action_tranche8i_exact_action_context_smoke_on_rerun2_20260807T145623Z.jsonl`,
   - result: `PASS=4`,
   - marker counts remained bounded:
      - `boundary_comparison_cache_key_evaluated=10`,
      - `boundary_comparison_post_cache_key_flush_observed=10`,
      - runtime lines containing `exact_action_context_status=20`.
9. Final ON Current row evidence (`tab_settled_current`, `comparison_plot`):
   - `action_id=tranche8i_exact_action_context_smoke_on_rerun2_04_tab_settled_current`,
   - `request_action_id=tranche8i_exact_action_context_smoke_on_rerun2_04_tab_settled_current`,
   - `cache_key_eval_action_id=tranche8i_exact_action_context_smoke_on_rerun2_04_tab_settled_current`,
   - `cache_key_eval_join_confidence=strong_exact_action_join`,
   - `cache_key_candidate_count=1`,
   - `cache_key_selection_reason=exact_action_join_single_candidate`,
   - `cache_key_eval_clock_basis=server_epoch_inferred`,
   - `exact_action_context_status=available`,
   - `exact_action_context_source=single_action_probe`,
   - `exact_action_context_evidence_class=exact_probe_action_context`,
   - `exact_action_context_target_id=main_tabs_panel`,
   - `exact_action_context_target_value=Current vs. Average`,
   - `exact_action_context_target_output_id=comparison_plot`,
   - `exact_action_context_target_tab=Current vs. Average`,
   - `output_post_cache_key_flush_join_confidence=strong_exact_action_join`,
   - `output_post_cache_key_flush_marker_count=1`,
   - `output_post_cache_key_flush_clock_basis=server_epoch_inferred`,
   - `output_post_cache_key_flush_observed_ms=-700`,
   - `output_client_value_received_ms=19107`,
   - `timeline_shiny_value_output_ms=19010`.
10. Interpretation and gate state:
   - the narrower marker resolved the prior smoke ambiguity for Current from `medium_action_window_join` with `cache_key_candidate_count=6` to `strong_exact_action_join` with `cache_key_candidate_count=1`,
   - the post-cache/onFlushed marker now joins exactly to the probe-owned Current action as well,
   - timing remains cross-clock/order evidence (`server_epoch_inferred`), so this does not become a same-clock scheduler timing claim,
   - strict replicated cohort is now the next diagnostic gate, still without repair or optimization claims.

## Execution Update (8I-25 Strict Cohort)

1. Strict cohort execution:
   - command executed:
      - `C:/Program Files/R/R-4.5.1/bin/Rscript.exe System/Testing/vp_perf_run_acceptance_pair.R --label=tranche8i_comparison_delivery_provenance_i9 --iterations=9 --runtime-perf=true --perf-boundary-markers=true --manifest-clean-room=true --strict-manifest=true --strict-context-validation=true --strict-runtime-identity=true --acceptance-only=true --baseline-cache-state=warm_partition_disk --candidate-cache-state=warm_partition_disk --baseline-scenario=tab_only --candidate-scenario=tab_only --rscript=C:/Program Files/R/R-4.5.1/bin/Rscript.exe`
   - pair run id:
      - `tranche8i_comparison_delivery_provenance_i9_20260807T150715Z`.
2. Strict preflight and identity gates:
   - `VP_PERF_ACCEPTANCE_PAIR_PREFLIGHT_MANIFEST_PATH=C:/Users/SETH.WECHSLER/OneDrive - USDA/Documents/Repositories/VP Clone/Logs/vp_perf_acceptance_run_manifest_tranche8i_comparison_delivery_provenance_i9_20260807T150715Z.csv`,
   - `VP_PERF_ACCEPTANCE_PAIR_PREFLIGHT_MANIFEST_ROWS=36`,
   - `VP_PERF_ACCEPTANCE_PAIR_PREFLIGHT_EXPECTED_ROWS=36`,
   - `VP_PERF_ACCEPTANCE_PAIR_PREFLIGHT_CONTEXT_STATUS=PASS`,
   - `VP_PERF_ACCEPTANCE_PAIR_PREFLIGHT_CONTEXT_FAIL_COUNT=0`,
   - `VP_PERF_ACCEPTANCE_PAIR_PREFLIGHT_IDENTITY_STATUS=PASS`,
   - `VP_PERF_ACCEPTANCE_PAIR_PREFLIGHT_IDENTITY_FAIL_COUNT=0`.
3. Strict acceptance decision artifacts:
   - decision label:
      - `tranche8i_comparison_delivery_provenance_i9__decision`,
   - summary CSV:
      - `Logs/vp_perf_acceptance_decision_tranche8i_comparison_delivery_provenance_i9__decision_20260807T162829Z_summary.csv`,
   - detail CSV:
      - `Logs/vp_perf_acceptance_decision_tranche8i_comparison_delivery_provenance_i9__decision_20260807T162829Z_details.csv`,
   - decision CSV:
      - `Logs/vp_perf_acceptance_decision_tranche8i_comparison_delivery_provenance_i9__decision_20260807T162829Z_decision.csv`,
   - overall status:
      - `VP_PERF_ACCEPTANCE_DECISION_OVERALL_STATUS=FAIL`.
4. Strict decision rows (terminal-reported):
   - `startup|FAIL|reason=improvement_failed observed=-0.053774 threshold=0.250000 || ci_failed lower=-0.273640 upper=0.165487`,
   - `single_action|FAIL|reason=improvement_failed observed=-0.038546 threshold=0.200000 || ci_failed lower=-0.182766 upper=0.230202`,
   - `overall|FAIL|reason=improvement_failed observed=-0.053774 threshold=0.250000 || ci_failed lower=-0.273640 upper=0.165487 || improvement_failed observed=-0.038546 threshold=0.200000 || ci_failed lower=-0.182766 upper=0.230202`.
5. Strict marker-quality aggregation (Current, `comparison_plot`):
   - strict manifest single-action rows: `18`, startup rows: `18`,
   - verified all `18` single-action output CSV paths exist,
   - aggregated Current rows across strict single-action outputs: `18`,
   - cache-key join confidence:
      - `strong_exact_action_join=18/18`,
   - post-cache/onFlushed join confidence:
      - `strong_exact_action_join=18/18`,
   - exact action context status:
      - `available=18/18`,
   - cache-key candidate count:
      - `min=1`, `max=1`, `mean=1`.
6. Strict interpretation for this tranche:
   - strict acceptance remains `FAIL` on unchanged performance thresholds (expected for diagnostic-only, behavior-neutral instrumentation),
   - strict marker-quality evidence now satisfies the decisive exact-action attribution requirement for Current `comparison_plot` in this cohort,
   - the remaining lag attribution remains a delivery-ordering diagnostic problem between post-cache/onFlushed and browser `shiny:value`, not an implementation optimization claim.
7. Next action:
   - proceed with the exact-path chain from this strict cohort (Step25A/25B/25C/25D/25C rollup and Step25F browser-phase view alignment) using this run manifest and decision artifacts as the authoritative strict inputs.

## Execution Update (8I-25 Exact-Path Chain)

1. Index bootstrap:
   - created exact-path index:
      - `Logs/vp_perf_acceptance_index_tranche8i_off_on_i9_comparison_delivery_provenance_20260807.csv`,
   - required index references existed:
      - `INDEX_MISSING_PATH_COUNT=0`.
2. Step25A inventory:
   - command label:
      - `tranche8i_off_on_i9_comparison_delivery_provenance_inventory`,
   - output CSV:
      - `Logs/vp_perf_acceptance_inventory_tranche8i_off_on_i9_comparison_delivery_provenance_inventory_20260807T163141Z.csv`,
   - output JSON:
      - `Logs/vp_perf_acceptance_inventory_tranche8i_off_on_i9_comparison_delivery_provenance_inventory_20260807T163141Z.json`,
   - rows: `36`,
   - OK rows: `36`,
   - quarantine rows: `0`.
3. Step25B validation:
   - command label:
      - `tranche8i_off_on_i9_comparison_delivery_provenance_validation`,
   - summary CSV:
      - `Logs/vp_perf_acceptance_inventory_validation_tranche8i_off_on_i9_comparison_delivery_provenance_validation_20260807T163147Z_summary.csv`,
   - detail CSV:
      - `Logs/vp_perf_acceptance_inventory_validation_tranche8i_off_on_i9_comparison_delivery_provenance_validation_20260807T163147Z_detail.csv`,
   - reason CSV:
      - `Logs/vp_perf_acceptance_inventory_validation_tranche8i_off_on_i9_comparison_delivery_provenance_validation_20260807T163147Z_reasons.csv`,
   - rows: `36`,
   - OK rows: `36`,
   - quarantine rows: `0`,
   - comparison-validity complete rows: `36`.
4. Step25C decomposition:
   - command label:
      - `tranche8i_off_on_i9_comparison_delivery_provenance_decomp`,
   - detail CSV:
      - `Logs/vp_perf_acceptance_decomposition_tranche8i_off_on_i9_comparison_delivery_provenance_decomp_20260807T163154Z_detail.csv`,
   - summary CSV:
      - `Logs/vp_perf_acceptance_decomposition_tranche8i_off_on_i9_comparison_delivery_provenance_decomp_20260807T163154Z_summary.csv`,
   - runs CSV:
      - `Logs/vp_perf_acceptance_decomposition_tranche8i_off_on_i9_comparison_delivery_provenance_decomp_20260807T163154Z_runs.csv`,
   - window-confidence CSV:
      - `Logs/vp_perf_acceptance_decomposition_tranche8i_off_on_i9_comparison_delivery_provenance_decomp_20260807T163154Z_window_confidence.csv`,
   - inconclusive-gate CSV:
      - `Logs/vp_perf_acceptance_decomposition_tranche8i_off_on_i9_comparison_delivery_provenance_decomp_20260807T163154Z_inconclusive_gate.csv`,
   - selected rows: `18`,
   - detail rows: `12330`,
   - run rows: `18`,
   - summary rows: `50`,
   - inconclusive run count: `18/18`,
   - action-window inconclusive count: `18/18`,
   - post-visible inconclusive count: `18/18`,
   - bucket-confidence min: `0.264784`, mean: `0.283478`.
5. Step25D attribution audit:
   - command label:
      - `tranche8i_off_on_i9_comparison_delivery_provenance_audit`,
   - classification audit CSV:
      - `Logs/vp_perf_acceptance_decomposition_tranche8i_off_on_i9_comparison_delivery_provenance_audit_20260807T163505Z_classification_audit.csv`,
   - window-bucket CSV:
      - `Logs/vp_perf_acceptance_decomposition_tranche8i_off_on_i9_comparison_delivery_provenance_audit_20260807T163505Z_window_bucket.csv`,
   - confidence-comparison CSV:
      - `Logs/vp_perf_acceptance_decomposition_tranche8i_off_on_i9_comparison_delivery_provenance_audit_20260807T163505Z_confidence_comparison.csv`,
   - audit summary JSON:
      - `Logs/vp_perf_acceptance_decomposition_tranche8i_off_on_i9_comparison_delivery_provenance_audit_20260807T163505Z_audit_summary.json`.
6. Step25C rollup:
   - command label:
      - `tranche8i_off_on_i9_comparison_delivery_provenance_rollup`,
   - action-bucket CSV:
      - `Logs/vp_perf_acceptance_decomposition_tranche8i_off_on_i9_comparison_delivery_provenance_rollup_20260807T163506Z_action_bucket.csv`,
   - lane-delta CSV:
      - `Logs/vp_perf_acceptance_decomposition_tranche8i_off_on_i9_comparison_delivery_provenance_rollup_20260807T163506Z_lane_delta.csv`,
   - lane-confidence CSV:
      - `Logs/vp_perf_acceptance_decomposition_tranche8i_off_on_i9_comparison_delivery_provenance_rollup_20260807T163506Z_lane_confidence.csv`,
   - top baseline action-window buckets:
      - `unclassified=70.93%`,
      - `client_wait=9.34%`,
      - `hierarchy_fanout=7.40%`,
      - `client_lifecycle=5.06%`,
      - `transition_wait=2.85%`,
   - top candidate action-window buckets:
      - `unclassified=70.94%`,
      - `client_wait=9.29%`,
      - `hierarchy_fanout=7.71%`,
      - `client_lifecycle=5.09%`,
      - `transition_wait=2.64%`.
7. Step25F Current phase view:
   - command label:
      - `tranche8i_comparison_delivery_provenance_i9_current_phase_view`,
   - action rows CSV:
      - `Logs/vp_perf_output_materialization_phase_view_tranche8i_comparison_delivery_provenance_i9_current_phase_view_20260807T163521Z_action_rows.csv`,
   - lane summary CSV:
      - `Logs/vp_perf_output_materialization_phase_view_tranche8i_comparison_delivery_provenance_i9_current_phase_view_20260807T163521Z_lane_summary.csv`,
   - coverage CSV:
      - `Logs/vp_perf_output_materialization_phase_view_tranche8i_comparison_delivery_provenance_i9_current_phase_view_20260807T163521Z_coverage.csv`,
   - rows: `18`,
   - pass rows: `18`,
   - complete server-anchor rows: `0`,
   - baseline median target `shiny:value`: `9645 ms`,
   - candidate median target `shiny:value`: `10675 ms`,
   - all-row median target `shiny:value`: `10435 ms`,
   - all-row corrected median `shiny:value -> widget`: `42 ms`,
   - all-row corrected median `widget -> plotly_afterplot`: `3 ms`,
   - all-row corrected median `shiny:value -> useful_ready`: `58 ms`.
8. Interpretation:
   - exact-path identity and file-integrity gates passed (`0` quarantined rows),
   - initial generic Step25C bucket output was inconclusive for this cohort and mostly unclassified because the classifier vocabulary did not yet recognize the new 8I `boundary_output_*` diagnostic marker family; this is corrected in 8I-26 without changing the app or rerunning the cohort,
   - the exact-action marker-quality result from the strict cohort remains the decisive provenance finding: cache-key and post-cache/onFlushed markers join exactly for `18/18` Current rows with candidate count `1`,
   - Step25F again confirms post-browser-value work is small: the target `shiny:value` arrives around `9.6-10.7 s`, then widget/useful-ready completes in roughly tens of milliseconds,
   - the next repair-search target remains the unobserved delivery/invalidation/cache-hit scheduling gap after the exact post-cache/onFlushed boundary and before browser `shiny:value` receipt.

## Execution Update (8I-26 Classifier Cleanup)

1. Scope executed:
   - frozen-evidence measurement-layer cleanup only,
   - no Shiny cohort rerun, no app behavior change, no acceptance threshold change, no decomposition window/gap logic change, and no repair claim.
2. Local hypothesis tested:
   - the high `unclassified` share in the 8I-25 Step25C output was caused by stale classifier vocabulary for newly added 8I output boundary markers, not by a collapse of the Tranche 8F/8G attribution cleanup.
3. Classifier edit:
   - `System/Testing/vp_perf_decompose_single_action_8c.R` now maps the following marker signatures to a distinct diagnostic bucket, `output_boundary_provenance`:
      - `boundary_output_client_value_received`,
      - `boundary_output_widget_inserted`,
      - `boundary_output_main_svg_inserted`,
      - `boundary_output_plotly_afterplot`,
      - `boundary_output_loading_cleared`,
      - `boundary_output_useful_ready`.
   - these markers are intentionally not mapped to an existing ownership bucket such as `client_lifecycle` or `tab_server_materialization`, because their role is phase/provenance observation rather than proof of root-cause ownership.
4. Validation before rerun:
   - parse check passed: `PARSE_OK_STEP25C_CLASSIFIER`,
   - editor diagnostics reported no errors for `System/Testing/vp_perf_decompose_single_action_8c.R`.
5. Frozen Step25C rerun:
   - command label: `tranche8i_comparison_delivery_provenance_classifier_cleanup1`,
   - inventory input: `Logs/vp_perf_acceptance_inventory_tranche8i_off_on_i9_comparison_delivery_provenance_inventory_20260807T163141Z.csv`,
   - detail CSV: `Logs/vp_perf_acceptance_decomposition_tranche8i_comparison_delivery_provenance_classifier_cleanup1_20260807T164903Z_detail.csv`,
   - summary CSV: `Logs/vp_perf_acceptance_decomposition_tranche8i_comparison_delivery_provenance_classifier_cleanup1_20260807T164903Z_summary.csv`,
   - runs CSV: `Logs/vp_perf_acceptance_decomposition_tranche8i_comparison_delivery_provenance_classifier_cleanup1_20260807T164903Z_runs.csv`,
   - inconclusive gate CSV: `Logs/vp_perf_acceptance_decomposition_tranche8i_comparison_delivery_provenance_classifier_cleanup1_20260807T164903Z_inconclusive_gate.csv`,
   - window confidence CSV: `Logs/vp_perf_acceptance_decomposition_tranche8i_comparison_delivery_provenance_classifier_cleanup1_20260807T164903Z_window_confidence.csv`.
6. Step25C rerun outcome:
   - selected rows: `18`,
   - run rows: `18`,
   - inconclusive run count/share: `0/18` (`0.000000`),
   - inconclusive lane count/share: `0/2` (`0.000000`),
   - action-window inconclusive share: `0.000000`,
   - action-window gap warning share: `0.000000`,
   - action-window synthetic-wait warning share: `0.000000`.
7. Step25D and rollup artifacts:
   - classification audit CSV: `Logs/vp_perf_acceptance_decomposition_tranche8i_comparison_delivery_provenance_classifier_cleanup1_audit_20260807T165343Z_classification_audit.csv`,
   - window bucket CSV: `Logs/vp_perf_acceptance_decomposition_tranche8i_comparison_delivery_provenance_classifier_cleanup1_audit_20260807T165343Z_window_bucket.csv`,
   - confidence comparison CSV: `Logs/vp_perf_acceptance_decomposition_tranche8i_comparison_delivery_provenance_classifier_cleanup1_audit_20260807T165343Z_confidence_comparison.csv`,
   - audit summary JSON: `Logs/vp_perf_acceptance_decomposition_tranche8i_comparison_delivery_provenance_classifier_cleanup1_audit_20260807T165343Z_audit_summary.json`,
   - action-bucket rollup CSV: `Logs/vp_perf_acceptance_decomposition_tranche8i_comparison_delivery_provenance_classifier_cleanup1_rollup_20260807T165345Z_action_bucket.csv`,
   - lane-delta rollup CSV: `Logs/vp_perf_acceptance_decomposition_tranche8i_comparison_delivery_provenance_classifier_cleanup1_rollup_20260807T165345Z_lane_delta.csv`,
   - lane-confidence rollup CSV: `Logs/vp_perf_acceptance_decomposition_tranche8i_comparison_delivery_provenance_classifier_cleanup1_rollup_20260807T165345Z_lane_confidence.csv`,
   - artifact existence check: `12/12` expected files present, `0` missing.
8. Before/after confidence comparison:
   - old baseline: `9/9` inconclusive, mean bucket confidence `0.281088`, mean unclassified share `0.718912`,
   - old candidate: `9/9` inconclusive, mean bucket confidence `0.285869`, mean unclassified share `0.714131`,
   - cleanup baseline: `0/9` inconclusive, mean bucket confidence `0.999721`, mean unclassified share `0.000279`,
   - cleanup candidate: `0/9` inconclusive, mean bucket confidence `0.999715`, mean unclassified share `0.000285`.
9. Cleanup action-window bucket interpretation:
   - baseline `output_boundary_provenance`: `900539.9998 ms` (`70.9042%`),
   - candidate `output_boundary_provenance`: `838880.0002 ms` (`70.9163%`),
   - baseline residual `unclassified`: `350.1 ms` (`0.0276%`),
   - candidate residual `unclassified`: `323.2 ms` (`0.0273%`).
10. Interpretation:
   - the user concern was correct: prior Tranche 8F/8G work had effectively eliminated the old unclassified-action problem,
   - the 8I-25 `~71%` unclassified rollup was a classifier-vocabulary mismatch introduced by the new output boundary marker family,
   - classifier confidence is now back near the 8G/8H quality level on the frozen 8I cohort,
   - the large `output_boundary_provenance` share is diagnostic marker mass, not a root-cause owner and not an optimization target by itself,
   - the decisive repair-search target remains unchanged: the still-unobserved delivery/invalidation/cache-hit scheduling interval after the exact post-cache/onFlushed boundary and before browser `shiny:value` receipt.

## Planning Update (8I-22)

1. Recent evidence and ownership conclusion:
   - 8I-19 remains the decisive Current vs. Average localization evidence:
      - the long wait is before target `comparison_plot` `shiny:value` delivery,
      - browser work after target value receipt is fast: widget/main SVG insertion is immediate or near-immediate, and Plotly/useful-ready follows in roughly tens of milliseconds,
      - therefore post-value Plotly materialization is not the dominant owner for Current in the strict `tranche8i_output_materialization_i9` cohort.
   - 8I-20 made the first non-render-body `comparison_plot` delivery-provenance surface observable:
      - `boundary_comparison_cache_key_evaluated` is feature-gated and absent when boundary markers are OFF,
      - ON smoke produced bounded marker volume and populated cache-key provenance fields for `tab_settled_current`,
      - cache-key marker rows remain observer-level provenance, not proof of delay ownership.
   - 8I-21 improved evidence honesty rather than ownership:
      - selected Current rows now report join confidence, clock basis, candidate count, selection reason, and earliest/latest/selected timing or ordering fields,
      - the ON Current smoke row still resolves as `weak_timestamp_only` with `server_epoch_inferred` timing and `cache_key_candidate_count=6`,
      - exact action identity and same-client-clock elapsed remain unavailable for the selected cache-key event, so same-clock cache-key-to-value gap ownership remains intentionally uncomputed.
2. Conclusion after reassessment:
   - forcing more exact action identity into the cache-key observer is likely lower-yield unless an obvious existing action-context hook is found,
   - the higher-probability next diagnostic is one step downstream from cache-key evaluation, closer to the known missing interval before browser `shiny:value`,
   - the next tranche should ask whether observable server-side render/body, cache/body outcome, or bounded flush-cycle evidence occurs early or late relative to target browser value receipt,
   - if the observable server-side boundary is early but browser value remains late, the next target becomes the server-to-browser/client-receipt gap with clock-domain caveats,
   - if the observable server-side boundary is late or absent on cache-hit/body-bypass paths, the next target becomes output invalidation/scheduling or cache-hit delivery provenance before any repair.
3. Logic-audit corrections folded into the 8I-22 plan:
   - do not use marker names or conclusions that imply direct access to Shiny scheduler enqueue, per-output send queue, transport queue, or wire-send internals unless implementation identifies a true hook,
   - rename the tranche from broad delivery/scheduling claims to observable downstream provenance,
   - treat `session$onFlushed(...)` as session-flush-cycle evidence only; it is not proof that `comparison_plot` was sent over the wire,
   - keep server-clock, browser/action-clock, and mixed/order-only evidence separated; cross-domain elapsed gaps must remain `NA` unless a same-clock bridge exists,
   - require downstream join-confidence coverage before ownership interpretation; marker presence alone is insufficient,
   - make cache-hit/body-bypass outcome coverage a first-class gate before interpreting missing render-body markers,
   - require explicit missing-phase reasons instead of silently filling downstream fields with `NA`.
4. Technical-detail audit conclusions for handoff readiness:
   - exact marker names must match existing parser tags; existing code/parser use `boundary_server_output_plot_object_built`, not `boundary_server_output_plot_built`,
   - new metadata fields such as `observability_class`, `flush_scope`, and downstream clock-basis fields must be added to `parse_runtime_server_output_anchor_events(...)` and `marker_output_fields` or they will be dropped,
   - any flush-cycle marker must capture tab/action/source/output context at registration time and pass it explicitly when the callback fires; callback-time fallback derivation is not acceptable because tab/action state may have changed,
   - `session$onFlushed(...)` use must short-circuit when markers are OFF, use `once=TRUE` when available, use a bounded dedupe key scoped by action/context plus `target_output_id` plus phase/outcome, and define a bounded reset policy,
   - all `comparison_plot` return/outcome paths must be accounted for: active gate skip, empty state return, normal plot return, and cache-hit/body-bypass/render-body absence,
   - new probe fields should avoid semantic collision with existing `output_outcome`; use names such as `downstream_render_body_outcome`, `output_flush_cycle_scope`, and `output_downstream_marker_missing_reason`,
   - every new probe field must be predeclared in the correct type schema and asserted as non-list before CSV write,
   - if `System/Testing/vp_perf_step25f_output_materialization_phase_view_8i.R` is extended, it needs its own required-column/schema update rather than relying on probe schema assumptions.
5. 8I-22 objective:
   - add only defensible observable-boundary provenance for `comparison_plot` after cache-key evidence and before browser value receipt,
   - preserve existing render/body markers and cache-body outcome evidence,
   - optionally add one bounded flush-cycle marker if the implementation can do so without callback churn or overclaiming,
   - surface downstream marker presence, missing reasons, observability class, join confidence, clock basis, and outcome path in the single-action probe.
6. 8I-22 non-goals:
   - no repair,
   - no `bindCache(...)` changes,
   - no output definition behavior changes,
   - no marker emission inside `comparison_plot_base_cache_key()` or `comparison_plot_extension_cache_key()`,
   - no hidden-output warming,
   - no `outputOptions(...)` changes,
   - no readiness predicate changes,
   - no resize behavior changes,
   - no decomposition/threshold changes,
   - no expansion to Historical Trend, Map, or Heatmap.
7. Required implementation anchors:
   - `Programs/app_source/server/04_comparison_plots.R`:
      - `output$comparison_plot <- renderPlotly(...)`,
      - `emit_comparison_plot_boundary(...)`,
      - existing render phase markers including `boundary_server_output_plot_object_built`,
      - existing `record_cache_body_execution(...)` outcome evidence,
      - existing `boundary_comparison_cache_key_evaluated` observer for context only.
   - `Programs/app_source/server/02_partner_and_notes.R`:
      - reference existing `log_client_perf(...)`, `server_output_anchor`, request/action enrichment, and `session$onFlushed(...)` usage patterns.
   - `System/Testing/vp_perf_probe_single_action_latency.R`:
      - extend `parse_runtime_server_output_anchor_events(...)`, `marker_output_fields`, marker tag lists, result schema initialization, downstream marker selection, schema assertions, and `tab_settled_current` row enrichment.
   - `System/Testing/vp_perf_step25f_output_materialization_phase_view_8i.R`:
      - extend only after smoke proves the new fields are useful and only with exact required-column/schema updates.
8. Required candidate fields for the probe output:
   - `output_flush_cycle_observed_ms`,
   - `output_flush_cycle_observability_class`,
   - `output_flush_cycle_scope`,
   - `output_flush_cycle_join_confidence`,
   - `output_flush_cycle_clock_basis`,
   - `output_flush_cycle_marker_count`,
   - `output_downstream_marker_missing_reason`,
   - `downstream_render_body_outcome`,
   - `downstream_render_body_marker_count`.
9. Validation gates before any strict cohort:
   - parse checks and editor diagnostics for every touched R file,
   - marker OFF smoke label: `tranche8i_comparison_observable_downstream_smoke_off`, with zero new observable downstream markers,
   - marker ON smoke label: `tranche8i_comparison_observable_downstream_smoke_on`, with bounded marker volume and either defensible downstream evidence or explicit missing/outcome reason for `tab_settled_current`,
   - existing 8I-21 cache-key fields and existing browser output/materialization fields remain populated/labeled,
   - new downstream fields exist, have expected type families, and are not list columns,
   - server-clock/order, browser/action-clock, and mixed/order-only values are labeled separately,
   - perturbation comparison against the immediately prior comparable smoke shape shows no material regression in PASS count, action count, marker count, or Current output/materialization field presence,
   - stop before strict cohort if marker volume/churn is ambiguous, all new fields are blank without explicit missing reasons, downstream joins are mostly weak, or flush callbacks cannot be bounded.
10. Decision rules after 8I-22 evidence:
   - if observable render/body or flush-cycle evidence is early while browser `boundary_output_client_value_received` is late, the next target is the unobserved server-to-browser/client-receipt gap, with clock-domain caveats,
   - if observable render/body or flush-cycle evidence is late and close in order to `shiny:value`, the next target is output invalidation/scheduling, dependency readiness, or cache-hit/body-bypass delivery before observable flush,
   - if cache-key evidence is early, render/body markers are absent due cache-hit/body-bypass, and browser value is late, add one narrower non-render-body output invalidation/scheduling marker instead of inferring from absence,
   - if joins remain weak or clock basis remains mixed/unknown, stop before repair and add one narrower provenance marker at the chain break,
   - no performance acceptance or repair recommendation is allowed from this diagnostic step alone.
11. Pause/handoff status:
   - 8I-22 implementation is complete and remains diagnostic-only,
   - the active implementation source of truth is this ledger,
   - the next work item is a narrower non-render-body output invalidation/scheduling provenance marker where the chain currently breaks.

## Handoff Packet (8I-15)

### Current State
1. Tranche 8I is still open and diagnostic-first.
2. Two optimization-style resize hypotheses were rejected and rolled back on strict evidence.
3. Wait-boundary ownership evidence now points away from resize transport as the main owner for the user-priority tabs.
4. Companion ownership classification recovered `18/18` single-action runs and `72` action rows.
5. Current vs. Average, Historical Trend, and Map were classified as output/Plotly-materialization owned in baseline and candidate cohorts.
6. Heatmap showed a real premature visible-boundary/readiness issue, but it is lower priority for the next pass.

### Start Here
1. Implement only the diagnostic bridge-marker tranche.
2. Mandatory first output: Current vs. Average `comparison_plot` in `Programs/app_source/server/04_comparison_plots.R`.
3. Add Historical Trend `timeseries_plot` and Map `map_plot` only if the shared marker helper stays small and does not change validation risk.
4. Do not instrument Heatmap first.
5. Do not run a broad guardrail/helper inventory first.
6. Do not attempt a performance repair until marker evidence splits ownership cleanly.

### Implementation Anchors
1. Server render markers:
   - `Programs/app_source/server/04_comparison_plots.R`, `output$comparison_plot <- renderPlotly(...)`,
   - optional later: `Programs/app_source/server/05_trend_and_heatmap.R`, `output$timeseries_plot <- renderPlotly(...)`,
   - optional later: `Programs/app_source/server/05_trend_and_heatmap.R`, `output$map_plot <- renderPlotly(...)` and `finalize_map_plot(...)`.
2. Shared server/client context:
   - `Programs/app_source/server/02_partner_and_notes.R`, existing boundary-marker ingestion and runtime perf context.
3. Browser materialization markers:
   - `Programs/app_source/ui.R`, reuse `emitBoundaryMarker(...)`, `emitClientPerf(...)`, `shiny:value`, targeted DOM/output-state checks, `plotly_afterplot`, and loading-cleared state.
4. Probe parsing:
   - `System/Testing/vp_perf_probe_single_action_latency.R`, extend marker parsing and per-action derived gap columns without changing pass/fail criteria.

### Required Marker Chain
1. Server-clock phases:
   - render start,
   - data/reactive inputs resolved,
   - plot object built,
   - render returned.
2. Browser-clock phases:
   - target-output `shiny:value` received,
   - widget inserted,
   - main SVG inserted,
   - Plotly `afterplot`,
   - loading cleared,
   - diagnostic useful-output-ready.
3. Outcome/status fields:
   - active-gate skip,
   - empty-state return,
   - normal plot return,
   - cache-body execution path observed when existing `record_cache_body_execution(...)` evidence is available.

### Interpretation Rules
1. Server render/reactive owned if most wait is inside same-clock render phases.
2. Client delivery/insertion owned if server render returns quickly but `shiny:value`, widget insertion, or main SVG insertion is late.
3. Plotly materialization owned if widget insertion is timely but `plotly_afterplot`, main SVG, or useful-ready is late.
4. Loading/readiness semantics owned if Plotly materialization is timely but loading-cleared or useful-ready is late.
5. Server-to-browser absolute gaps are lower-confidence provenance/order evidence unless anchored; do not treat them as precise elapsed durations.
6. Every ownership claim must carry join confidence:
   - exact: target output id plus action id/request id,
   - strong: target output id plus tab plus runtime log/run id plus event ordering,
   - weak: timestamp/order only.
7. Weak joins cannot drive a repair decision.

### Validation And Stop Gates
1. Parse every touched R file immediately after the first substantive edit.
2. Run editor diagnostics on touched files.
3. Run marker OFF smoke and confirm the new output/materialization markers are absent.
4. Run marker ON smoke and confirm the expected `comparison_plot` chain is present.
5. Confirm no duplicate marker storms.
6. Confirm no loss of existing probe columns, timeline markers, readiness markers, or tab-only PASS rows.
7. Stop before strict pair if any marker chain is missing, ambiguous, duplicated, or only weakly joinable.
8. Run a strict replicated diagnostic pair only after smoke and marker-completeness checks pass.

### Non-Negotiable Behavior Constraints
1. No `outputOptions(...)` changes.
2. No hidden-output warming.
3. No `bindCache(...)` changes.
4. No output definition behavior changes.
5. No readiness predicate changes.
6. No decomposition-rule changes.
7. No threshold changes.
8. No resize behavior changes.

### Handoff Decision
The next implementation pass should be a narrow diagnostic marker implementation, not a repair. The first actionable question is whether `comparison_plot` wait is server-render/reactive owned, client delivery/insertion owned, Plotly materialization owned, loading/readiness-semantics owned, or still unexplained. That answer determines whether the following tranche inspects comparison data/reactive/cache construction, browser Plotly materialization, or guardrail/helper churn.

## Execution Update (8I-14)

1. Recommendation refined after logic audit:
   - do not run broad guardrail/helper inventory next,
   - do not lead with Heatmap boundary/readiness despite its real premature-boundary signal,
   - prioritize Current vs. Average because `comparison_plot` is the strongest and highest-priority output/materialization-owned case,
   - add Historical Trend and Map only when the same marker vocabulary/helper can cover them with small incremental risk.
2. Narrow diagnostic hypothesis:
   - Current vs. Average wait is dominated by either server-side `comparison_plot` construction or client-side Plotly materialization after Shiny value delivery,
   - not resize transport, tab switching, or generic guardrail churn.
3. Technical-detail audit conclusions:
   - `comparison_plot` is mandatory first; `timeseries_plot` and `map_plot` are optional same-tranche extensions after the marker chain is coherent,
   - server render internal deltas and browser-to-browser materialization deltas can support timing claims,
   - server-to-browser absolute gaps are provenance/order evidence unless a same-clock anchor is available,
   - `client value received` must mean browser `shiny:value` for the target output id, not DOM insertion or widget binding,
   - `useful-output-ready` must remain diagnostic-only and must emit the rule used, for example `useful_ready_rule = plotly_afterplot_and_loading_cleared`,
   - any marker ownership claim must carry join confidence (`exact`, `strong`, or `weak`), and weak joins cannot drive a repair decision.
4. Required behavior-preservation constraints:
   - no `outputOptions(...)` changes,
   - no hidden-output warming,
   - no `bindCache(...)` changes,
   - no output definition behavior changes,
   - no readiness predicate changes,
   - no decomposition-rule changes,
   - no resize behavior changes.
5. First-pass marker chain should stay minimal:
   - server render start,
   - data/reactive inputs resolved,
   - plot object built,
   - server render returned,
   - browser `shiny:value` for target output received,
   - widget inserted,
   - main SVG inserted,
   - Plotly `afterplot`,
   - loading cleared,
   - diagnostic useful-output-ready.
6. Required output outcome statuses:
   - active-gate skip,
   - empty-state return,
   - normal plot return,
   - cache-body execution path observed if available from existing `record_cache_body_execution(...)` evidence.
7. Validation additions beyond smoke PASS/FAIL:
   - marker OFF smoke must not emit the new output/materialization boundary markers,
   - marker ON smoke must emit the expected `comparison_plot` marker chain,
   - Historical Trend and Map markers must either be present or explicitly out-of-scope for the first pass,
   - check for duplicate marker storms before interpreting timing,
   - no loss of existing timeline/readiness fields.
8. Decision rule for next implementation pass:
   - if server render is dominant, inspect `current_year_data()`, `historical_avg()`, `projection_data()`, cache keys, and plot construction next,
   - if client materialization is dominant, inspect browser Shiny delivery, widget insertion, Plotly `afterplot`, and loading/readiness semantics next,
   - if neither accounts for the gap, then inventory guardrails/helpers around stale output, hidden output, active-tab gating, and readiness predicates.

## Execution Update (8I-13)

1. Scope:
   - read-only inventory only,
   - no product-code instrumentation or behavior changes in this step,
   - inventory guided by 8I-12 ownership view rather than broad guardrail scanning.
2. Heatmap boundary/readiness inventory target:
   - owner signal: Heatmap is mostly `premature visible boundary / decomposition-boundary-owned`, baseline `9/9`, candidate `7/9`, median visible-to-readiness about `600` ms,
   - primary file/function: `Programs/app_source/ui.R`, `forcePlotlyResize` custom message handler,
   - relevant conditions/outcomes:
      - target output id mapping maps Heatmap to `heatmap_plot`,
      - active-tab mismatch emits `client_perf_plotly_resize_skipped` and returns,
      - visible widgets are filtered by `:visible`, width, and height before `Plotly.Plots.resize(...)`,
      - after-paint snapshot emits target presence, visibility, widget count, main SVG count, and loading indicator count,
      - current boundary markers can prove visibility and resize provenance but do not yet prove useful heatmap readiness.
3. Heatmap readiness predicate/probe inventory target:
   - primary file/function: `System/Testing/vp_perf_probe_single_action_latency.R`, browser timeline and readiness predicate markers,
   - relevant markers: `output_visible_nonzero`, `widget_inserted`, `main_svg_inserted`, `plotly_afterplot`, `plotly_relayout`, `loading_indicator_cleared`, `readiness_predicate_passed`, `client_echo_ready`,
   - suspected missing distinction: whether Heatmap is considered ready because a visible Plotly shell/SVG exists even when useful heatmap cells or afterplot completion lag behind.
4. Main-tab/profile guardrail inventory target:
   - primary file/function: `Programs/app_source/ui.R`, `selectMainTabWhenProfileReady(...)`,
   - relevant outcomes: `skipped_no_target`, retry, `timeout_not_ready`, `skipped_stale_target`, `timeout_tab_missing`, `error`, `applied`,
   - current coverage: emits `client_perf_main_tabs_safe_select` and profile snapshots,
   - possible symptom: hidden retries or stale-target skips can shift the apparent tab wait boundary without showing as output materialization.
5. Source-shell refresh guardrail inventory target:
   - primary client functions: `sourceShellSnapshot(...)`, `sourceSurfaceRefreshNeeded(...)`, `maybeRequestSourceSurfaceRefresh(...)` in `Programs/app_source/ui.R`,
   - primary server observer: `observeEvent(input$client_source_surface_refresh_request, ...)` in `Programs/app_source/server/02_partner_and_notes.R`,
   - relevant outcomes: client request suppressed by rate limiting/count limit, server `skipped_validation`, server `applied`, server `skipped_attempt_limit`,
   - current scope relevance: strongest for Map/source-shell churn, not first Heatmap target unless ownership view later implicates source/profile mismatch.
6. Server tab normalization/eligibility inventory target:
   - primary functions: `current_main_tab_safe(...)`, `normalized_raw_main_tab(...)`, `is_effective_map_tab_active(...)` in `Programs/app_source/server/02_partner_and_notes.R`,
   - relevant outcomes: transition override, normalized raw tab, Map active/inactive,
   - current scope relevance: important for Map and source transition diagnostics; not the leading owner for Current vs. Average or Heatmap in 8I-12.
7. Server main-tab observer inventory target:
   - primary observer: `observeEvent(input$main_tabs_panel, ...)` in `Programs/app_source/server/02_partner_and_notes.R`,
   - relevant conditions/outcomes:
      - returns on null tab,
      - returns during active PSD source transition,
      - may update data frequency,
      - sends `forcePlotlyResize` only when `should_send_plotly_resize_for_tab(...)` allows it,
      - emits `boundary_server_plotly_resize_sent` and `boundary_server_main_tabs_observer_complete`,
   - 8I-12 interpretation: server observer/send is not a dominant owner, so this remains supporting provenance rather than first repair target.
8. Output/materialization inventory targets:
   - Current vs. Average: `Programs/app_source/server/04_comparison_plots.R`, `output$comparison_plot <- renderPlotly(...)`, gated by `is_current_vs_average_output_active()` and returning `NULL` on inactive tab; strongest output-owned case with median visible-to-readiness about `7.5` seconds and output materialization about `7.3` to `7.5` seconds,
   - Historical Trend: `Programs/app_source/server/05_trend_and_heatmap.R`, `output$timeseries_plot <- renderPlotly(...)`, returns PSD empty state, no-data empty states, and logs complexity details before returning the Plotly object,
   - Map: `Programs/app_source/server/05_trend_and_heatmap.R`, `output$map_plot <- renderPlotly(...)`, gated by `is_effective_map_tab_active(...)`, sets `map_plot_click_ready(FALSE)` on gated skip and `map_plot_click_ready(TRUE)` in finalization,
   - Heatmap: `Programs/app_source/server/05_trend_and_heatmap.R`, `output$heatmap_plot <- renderPlotly(...)`, builds a stable heatmap matrix and logs complexity details, but 8I-12 suggests its main issue is boundary/readiness classification rather than raw output render ownership.
9. Recommended targeted marker tranche, superseded by 8I-14 priority refinement:
   - first: Current vs. Average output/materialization completion markers around `comparison_plot`,
   - optional same-tranche extension: Historical Trend `timeseries_plot` and Map `map_plot` if the shared marker helper remains narrow,
   - deferred: Heatmap-specific readiness markers around `heatmap_plot` useful readiness unless priority-output evidence leaves the main question unresolved,
   - supporting only if needed: safe-tab/select and source-shell refresh guard outcomes with reason codes, attempt counts, request ids, tab/source/profile, target output id, and elapsed ms.
10. Next gate:
   - do not start broad instrumentation,
   - choose one targeted marker tranche from this inventory,
   - define the falsifiable hypothesis and perturbation/smoke protocol before editing product code.

## Execution Update (8I-12)

1. Added helper:
   - `System/Testing/vp_perf_step25e_wait_boundary_ownership_view_8i.R`.
2. Helper contract:
   - consumes exact-path Step 25B inventory, Step 25C detail, and Step 25C runs files,
   - reads the single-action probe output CSVs from `output_csv_path`,
   - joins augmented marker/gap probe columns back to decomposition run context,
   - emits action-row, tab-summary, and coverage CSVs,
   - fails if single-action probe outputs or per-run target-tab coverage are missing.
3. Validation:
   - editor diagnostics: no errors for the new helper,
   - R parse command exited successfully,
   - helper run completed successfully against the exact 8I-10 cohort.
4. Coverage result:
   - single-action runs recovered: `18/18`,
   - action rows recovered: `72`,
   - target tabs per run: `4/4`,
   - target tabs: Current vs. Average, Heatmap, Historical Trend, Map,
   - min/max action rows per run: `4/4`.
5. Output artifacts:
   - `Logs/vp_perf_wait_boundary_ownership_view_tranche8i_wait_boundary_ownership_i9_20260806T132650Z_action_rows.csv`,
   - `Logs/vp_perf_wait_boundary_ownership_view_tranche8i_wait_boundary_ownership_i9_20260806T132650Z_tab_summary.csv`,
   - `Logs/vp_perf_wait_boundary_ownership_view_tranche8i_wait_boundary_ownership_i9_20260806T132650Z_coverage.csv`.
6. Per-tab ownership summary:
   - baseline Current vs. Average: output or Plotly materialization owned (`9/9`), median total action `8708` ms, median visible-to-readiness `7743` ms, median output materialization `7489` ms,
   - candidate Current vs. Average: output or Plotly materialization owned (`9/9`), median total action `8501` ms, median visible-to-readiness `7515` ms, median output materialization `7333` ms,
   - baseline Historical Trend: output or Plotly materialization owned (`9/9`), median total action `9814` ms, median visible-to-readiness `811` ms, median output materialization `631` ms,
   - candidate Historical Trend: output or Plotly materialization owned (`9/9`), median total action `9761` ms, median visible-to-readiness `803` ms, median output materialization `630` ms,
   - baseline Map: output or Plotly materialization owned (`9/9`), median total action `11202` ms, median visible-to-readiness `672` ms, median output materialization `597` ms,
   - candidate Map: output or Plotly materialization owned (`9/9`), median total action `10737` ms, median visible-to-readiness `708` ms, median output materialization `568` ms,
   - baseline Heatmap: premature visible boundary / decomposition-boundary-owned (`9/9`), median total action `9033` ms, median visible-to-readiness `604` ms, median output materialization `422` ms,
   - candidate Heatmap: premature visible boundary / decomposition-boundary-owned (`7/9`) and output or Plotly materialization owned (`2/9`), median total action `8923` ms, median visible-to-readiness `618` ms, median output materialization `424` ms.
7. Interpretation:
   - resize transport/handler is not the dominant owner in this view,
   - server observer/send is not the dominant owner in this view,
   - Current vs. Average is the strongest output/materialization-owned case because the visible-to-readiness wait is about `7.5` seconds and is almost entirely explained by output materialization columns,
   - Historical Trend and Map also classify as output/materialization-owned, but their visible-to-readiness windows are much smaller than Current vs. Average,
   - Heatmap is the strongest premature-boundary/decomposition-boundary case and should be the first target for readiness/boundary guardrail inventory.
8. Next diagnostic inventory scope:
   - primary: Heatmap readiness predicates, visible boundary selection, tab/profile alignment, active-tab mismatch skips, hidden/visibility checks, and any stale-output or readiness helper that can let `boundary_visible_ready` fire before useful readiness,
   - secondary: Current vs. Average, Historical Trend, and Map output/Plotly materialization surfaces, including plot/render completion markers, output insertion, afterplot timing, loading-cleared timing, and any guards that defer or retry output finalization,
   - do not pursue a resize-ordering repair based on this evidence.

## Execution Update (8I-11)

1. Direction added after 8I-10 evidence review:
   - finish the companion wait-boundary ownership view before starting another repair attempt,
   - use that ownership evidence to drive a targeted guardrail/helper inventory,
   - do not broadly instrument every guardrail/helper surface without evidence from the ownership view.
2. Rationale:
   - the strict 8I-10 diagnostic chain is clean, but the latest split shifted dominance toward `client_wait + client_lifecycle`, with `transition_wait` no longer the only large action-window bucket,
   - decomposition still reports `action_window_gap_warning_share=1.000000`, which means hidden defers/skips/retries/guards may still be contributing to apparent waits or churn,
   - guardrail/helper instrumentation is more useful after the ownership view tells us which tabs/windows need explanation.
3. Added plan phases:
   - Phase 5: Companion Ownership View,
   - Phase 6: Guardrail/Helper Inventory And Targeted Diagnostic Pass.
4. Guardrail/helper candidate families documented:
   - tab/profile alignment helpers,
   - source-shell mismatch recovery,
   - safe tab selection and retry loops,
   - stale output checks,
   - active-tab mismatch skips,
   - debounce/throttle queues,
   - source-switch epoch staleness checks,
   - hidden/visibility checks,
   - readiness predicates,
   - cache/provider short-circuit or deferral guards,
   - observer guards such as `req(...)`, early `return()`, `ignoreInit`, and source/tab eligibility checks.
5. Guardrail/helper instrumentation rule:
   - inventory first,
   - instrument only high-leverage surfaces selected by ownership evidence,
   - keep markers feature-gated behind existing boundary-marker controls,
   - repeat marker perturbation validation before using marker-on evidence.
6. Current next gate remains unchanged:
   - implement companion transition-wait ownership view helper over exact 8I-10 cohort,
   - classify per-tab ownership,
   - then choose the next diagnostic pass or repair based on that classification.

## Execution Update (8I-10)

1. Strict replicated diagnostic pair (`i9`, markers ON, unchanged thresholds):
   - manifest: `Logs/vp_perf_acceptance_run_manifest_tranche8i_wait_boundary_ownership_i9_20260805T210755Z.csv`.
   - preflight/context/identity: PASS (`36/36` rows used).
   - decision artifacts:
      - `Logs/vp_perf_acceptance_decision_tranche8i_wait_boundary_ownership_i9__decision_20260805T221047Z_summary.csv`
      - `Logs/vp_perf_acceptance_decision_tranche8i_wait_boundary_ownership_i9__decision_20260805T221047Z_details.csv`
      - `Logs/vp_perf_acceptance_decision_tranche8i_wait_boundary_ownership_i9__decision_20260805T221047Z_decision.csv`.
   - decision: FAIL on improvement thresholds (expected and acceptable for diagnostic tranche):
      - startup observed improvement `0.027804` vs threshold `0.25`,
      - single-action observed improvement `0.012679` vs threshold `0.20`.
2. Exact-path inventory/validation chain:
   - index: `Logs/vp_perf_acceptance_index_tranche8i_off_on_i9_wait_boundary_ownership_20260805.csv`.
   - inventory: `Logs/vp_perf_acceptance_inventory_tranche8i_off_on_i9_wait_boundary_ownership_inventory_20260805T221113Z.csv`.
   - Step 25B summary: `Logs/vp_perf_acceptance_inventory_validation_tranche8i_off_on_i9_wait_boundary_ownership_validation_20260805T221125Z_summary.csv`.
   - Step 25B result: `OK_ROWS=36`, `QUARANTINE_ROWS=0`.
3. Decomposition/audit/rollup chain:
   - decomposition detail/runs/summary:
      - `Logs/vp_perf_acceptance_decomposition_tranche8i_off_on_i9_wait_boundary_ownership_decomp_20260805T221136Z_detail.csv`
      - `Logs/vp_perf_acceptance_decomposition_tranche8i_off_on_i9_wait_boundary_ownership_decomp_20260805T221136Z_runs.csv`
      - `Logs/vp_perf_acceptance_decomposition_tranche8i_off_on_i9_wait_boundary_ownership_decomp_20260805T221136Z_summary.csv`.
   - decomposition gate outputs:
      - `Logs/vp_perf_acceptance_decomposition_tranche8i_off_on_i9_wait_boundary_ownership_decomp_20260805T221136Z_window_confidence.csv`
      - `Logs/vp_perf_acceptance_decomposition_tranche8i_off_on_i9_wait_boundary_ownership_decomp_20260805T221136Z_inconclusive_gate.csv`.
   - Step 25D audit outputs:
      - `Logs/vp_perf_acceptance_decomposition_tranche8i_off_on_i9_wait_boundary_ownership_audit_20260805T221543Z_classification_audit.csv`
      - `Logs/vp_perf_acceptance_decomposition_tranche8i_off_on_i9_wait_boundary_ownership_audit_20260805T221543Z_window_bucket.csv`
      - `Logs/vp_perf_acceptance_decomposition_tranche8i_off_on_i9_wait_boundary_ownership_audit_20260805T221543Z_confidence_comparison.csv`
      - `Logs/vp_perf_acceptance_decomposition_tranche8i_off_on_i9_wait_boundary_ownership_audit_20260805T221543Z_audit_summary.json`.
   - Step 25C rollup outputs:
      - `Logs/vp_perf_acceptance_decomposition_tranche8i_off_on_i9_wait_boundary_ownership_rollup_20260805T221544Z_action_bucket.csv`
      - `Logs/vp_perf_acceptance_decomposition_tranche8i_off_on_i9_wait_boundary_ownership_rollup_20260805T221544Z_lane_delta.csv`
      - `Logs/vp_perf_acceptance_decomposition_tranche8i_off_on_i9_wait_boundary_ownership_rollup_20260805T221544Z_lane_confidence.csv`.
   - 8I split rerun outputs:
      - `Logs/vp_perf_client_readiness_split_tranche8i_client_readiness_split_wait_boundary_ownership_20260805T221553Z_signature.csv`
      - `Logs/vp_perf_client_readiness_split_tranche8i_client_readiness_split_wait_boundary_ownership_20260805T221553Z_gap_context.csv`
      - `Logs/vp_perf_client_readiness_split_tranche8i_client_readiness_split_wait_boundary_ownership_20260805T221553Z_role_pair_summary.csv`.
4. Cohort-level numeric outcomes:
   - action-window lane totals (`warm_partition_disk`): baseline `282080.5996` ms, candidate `282897.6002` ms, delta `+817.0006` ms, improvement `-0.2896%`.
   - lane confidence (`warm_partition_disk`): run count `18`, mean bucket confidence `0.9990837588`, max unclassified attributed time `293.3` ms.
   - decomposition gates: inconclusive run share `0.000000`; action-window gap warning share `1.000000`; action-window synthetic-wait warning share `0.000000`.
5. 8I client/wait action-window split (role-pair summary):
   - baseline action-window total `158404.9997` ms:
      - client_wait `78695.9999` ms (`49.6803%`),
      - client_lifecycle `57440.9997` ms (`36.2621%`),
      - transition_wait `22268.0001` ms (`14.0576%`).
   - candidate action-window total `159251.9989` ms:
      - client_wait `80155.0009` ms (`50.3322%`),
      - client_lifecycle `56527.9996` ms (`35.4959%`),
      - transition_wait `22568.9983` ms (`14.1719%`).
   - interpretation at this gate: transition_wait share did not decrease; dominant action-window share remains client_wait + client_lifecycle; no evidence yet of performance improvement.
6. Command-shape failures corrected during this step:
   - first Step 25B invocation used incorrect inventory timestamp (`221838`); reran with exact emitted inventory path (`221113`).
   - first Step 25D/rollup/split invocation used incorrect decomposition timestamp (`221142`); reran with exact emitted decomposition path (`221136`).
7. Outcome and next gate:
   - strict diagnostic evidence chain is complete and clean for ownership analysis.
   - no acceptance claim is made (decision FAIL is expected for diagnostic-only tranche).
   - next step is to implement companion transition-wait ownership view helper on this exact cohort and classify ownership per tab before any further behavior optimization.

## Execution Update (8I-09)

1. Hypothesis and scope:
   - dominant ON `transition_wait` ownership likely requires explicit visibility-to-readiness boundary evidence,
   - resize transport timing is treated as secondary provenance evidence,
   - this tranche is additive instrumentation and probe-output expansion only (no behavior tuning).
2. Server instrumentation edits (`Programs/app_source/server/02_partner_and_notes.R`):
   - added main-tab resize request sequence state and deterministic `resize_request_id` generator,
   - added `boundary_server_plotly_resize_sent` marker with `tab`, `source`, `resize_request_id`, and observer elapsed time,
   - propagated `resize_request_id` through `forcePlotlyResize` message payload,
   - included `resize_request_id` in existing `boundary_server_main_tabs_observer_complete` and `boundary_server_plotly_resize_recorded` payloads.
3. Client instrumentation edits (`Programs/app_source/ui.R`):
   - preserved existing `forcePlotlyResize` behavior (`120 ms` debounce, active-tab mismatch skip, visible widget filtering, resize/redraw path),
   - added boundary markers: `boundary_plotly_resize_handler_enter`, `boundary_plotly_resize_handler_flush`, `boundary_plotly_resize_after_paint_snapshot`,
   - propagated `resize_request_id` into `client_perf_plotly_resize_skipped`, `client_perf_plotly_resize`, and `boundary_visible_ready` payloads.
4. Probe output augmentation (`System/Testing/vp_perf_probe_single_action_latency.R`):
   - added runtime-log augmentation path that parses `client_perf` runtime events and maps tab actions to boundary markers,
   - added boundary columns: `server_main_tabs_observer_complete_ms`, `server_plotly_resize_sent_ms`, `plotly_resize_handler_enter_ms`, `plotly_resize_handler_flush_ms`, `plotly_resize_after_paint_snapshot_ms`, `boundary_visible_ready_ms`, `resize_request_id`,
   - added derived gap columns centered on visible-milestone-to-readiness and server/resize chain intervals.
5. Parse and diagnostics checks:
   - `PARSE_OK_UI`, `PARSE_OK_02`, and `PARSE_OK_PROBE`,
   - no editor diagnostics errors for touched files.
6. Marker perturbation smoke evidence:
   - OFF: `Logs/vp_perf_probe_single_action_latency_tranche8i_wait_boundary_ownership_marker_smoke_off_20260805T205319Z.csv` (`PASS=4`),
   - ON: `Logs/vp_perf_probe_single_action_latency_tranche8i_wait_boundary_ownership_marker_smoke_on_20260805T205541Z.csv` (`PASS=4`).
7. Marker-chain verification in runtime logs:
   - verified presence of `boundary_server_plotly_resize_sent`, `boundary_plotly_resize_handler_enter`, `boundary_plotly_resize_handler_flush`, `boundary_plotly_resize_after_paint_snapshot`, and `boundary_visible_ready`,
   - verified shared `resize_request_id` continuity across server send, handler markers, `plotly_resize`, and boundary-visible markers for each tab action.
8. Augmented probe smoke evidence:
   - ON (augmented): `Logs/vp_perf_probe_single_action_latency_tranche8i_wait_boundary_ownership_marker_smoke_on_augmented_20260805T210123Z.csv` (`PASS=4`),
   - runtime log: `Logs/vp_runtime_perf_single_action_tranche8i_wait_boundary_ownership_marker_smoke_on_augmented_20260805T210123Z.jsonl`.
9. Augmented output validation:
   - confirmed expected augmented boundary/gap columns are present in the emitted CSV,
   - confirmed `resize_request_id` and boundary timing columns are populated for tab actions.
10. Outcome and next gate:
   - instrumentation tranche succeeded without behavior regressions in smoke,
   - proceed to strict replicated diagnostic pair (`i9`) with markers ON,
   - then execute exact-path inventory -> validation -> decomposition -> ownership chain to classify per-tab wait-boundary ownership.

## Execution Update (8I-08)

1. Hypothesis and scope:
   - server-owned main-tab resize dispatch timing is out of phase with useful client output readiness,
   - moving only main-tab resize request ownership to client post-activation scheduling can reduce ON `transition_wait` share,
   - this is an ordering/ownership probe, not debounce tuning, redraw removal, or broad render optimization.
2. Implemented edit shape:
   - `Programs/app_source/ui.R`:
      - factored resize execution into shared queue helper used by both message-driven and client-tab dispatch paths,
      - added client-owned dispatch from main-tab `shown.bs.tab` -> `setTimeout(0)` -> bounded `requestAnimationFrame` chain,
      - added `resize_request_source` and `source_choice` payload fields on resize events,
      - left debounce (`120 ms`), mismatch-skip behavior, visible widget filtering, `window.dispatchEvent(new Event('resize'))`, `Plotly.Plots.resize(...)`, and `Plotly.redraw(...)` intact.
   - `Programs/app_source/server/02_partner_and_notes.R`:
      - removed only the main-tab observer `forcePlotlyResize` send,
      - retained eligibility accounting (`resize_requested`) for diagnostics,
      - left MYC-specific `forcePlotlyResize` sends unchanged.
3. Parse and diagnostics status:
   - `PARSE_OK_UI` and `PARSE_OK_02` after edit,
   - no editor diagnostics errors for touched files.
4. Narrow smoke result:
   - command label: `tranche8i_client_readiness_client_owned_resize_smoke`
   - probe output: `Logs/vp_perf_probe_single_action_latency_tranche8i_client_readiness_client_owned_resize_smoke_20260805T192403Z.csv`
   - runtime log: `Logs/vp_runtime_perf_single_action_tranche8i_client_readiness_client_owned_resize_smoke_20260805T192403Z.jsonl`
   - status: `PASS=4`.
5. Smoke mechanism evidence checks:
   - resize events: `4`, skipped resize events: `0`, duplicate tab-action resize pairs: `0`,
   - resize source counts: `client_tab_post_activation=4`,
   - tab coverage: Historical Trend `1`, Heatmap `1`, Map `1`, Current vs. Average `1`,
   - useful-work payload captured for all actions; observed `resized_count=0` on Historical/Heatmap/Map and `resized_count=1` on Current vs. Average.
6. Strict replicated acceptance pair (`i9`, markers ON, unchanged thresholds):
   - run manifest: `Logs/vp_perf_acceptance_run_manifest_tranche8i_client_readiness_acceptance_i9_client_owned_resize_20260805T192720Z.csv`
   - decision artifacts:
      - `Logs/vp_perf_acceptance_decision_tranche8i_client_readiness_acceptance_i9_client_owned_resize__decision_20260805T202932Z_summary.csv`
      - `Logs/vp_perf_acceptance_decision_tranche8i_client_readiness_acceptance_i9_client_owned_resize__decision_20260805T202932Z_details.csv`
      - `Logs/vp_perf_acceptance_decision_tranche8i_client_readiness_acceptance_i9_client_owned_resize__decision_20260805T202932Z_decision.csv`
   - preflight/context/identity: PASS (`36/36` rows used),
   - decision gate: FAIL,
   - startup improvement observed `0.021228` (threshold `0.25`),
   - single-action improvement observed `-0.097304` (threshold `0.20`).
7. Exact-path evidence chain (command-shape corrections logged):
   - created index: `Logs/vp_perf_acceptance_index_tranche8i_off_on_i9_client_owned_resize_20260805.csv`,
   - inventory: `Logs/vp_perf_acceptance_inventory_tranche8i_off_on_i9_client_owned_resize_inventory_20260805T203021Z.csv`,
   - Step 25B summary: `Logs/vp_perf_acceptance_inventory_validation_tranche8i_off_on_i9_client_owned_resize_validation_20260805T203034Z_summary.csv`,
   - decomposition: `Logs/vp_perf_acceptance_decomposition_tranche8i_off_on_i9_client_owned_resize_decomp_20260805T203036Z_detail.csv`; `Logs/vp_perf_acceptance_decomposition_tranche8i_off_on_i9_client_owned_resize_decomp_20260805T203036Z_runs.csv`; `Logs/vp_perf_acceptance_decomposition_tranche8i_off_on_i9_client_owned_resize_decomp_20260805T203036Z_summary.csv`,
   - Step 25D audit summary: `Logs/vp_perf_acceptance_decomposition_tranche8i_off_on_i9_client_owned_resize_audit_20260805T203324Z_audit_summary.json`,
   - Step 25C rollup: `Logs/vp_perf_acceptance_decomposition_tranche8i_off_on_i9_client_owned_resize_rollup_20260805T203325Z_action_bucket.csv`; `Logs/vp_perf_acceptance_decomposition_tranche8i_off_on_i9_client_owned_resize_rollup_20260805T203325Z_lane_delta.csv`; `Logs/vp_perf_acceptance_decomposition_tranche8i_off_on_i9_client_owned_resize_rollup_20260805T203325Z_lane_confidence.csv`,
   - 8I split rerun: `Logs/vp_perf_client_readiness_split_tranche8i_client_readiness_split_client_owned_resize_20260805T203337Z_role_pair_summary.csv`.
8. Post-edit rollup interpretation:
   - warm_partition_disk action-window baseline `298786.6000` ms,
   - warm_partition_disk action-window candidate `299860.1004` ms,
   - delta `+1073.5003` ms, improvement `-0.3593%`.
9. ON action-window bucket movement (8I split rerun):
   - baseline: transition_wait `51.91%`, client_lifecycle `34.11%`, client_wait `13.99%`,
   - candidate: transition_wait `52.05%`, client_lifecycle `33.72%`, client_wait `14.24%`.
10. Decision and rollback:
   - probe rejected on strict evidence (startup and single-action gate failures plus action-window increase),
   - reverted probe edits in:
      - `Programs/app_source/ui.R`
      - `Programs/app_source/server/02_partner_and_notes.R`
   - parse checks after rollback passed for both files.
11. Execution notes and minor failures handled during this step:
   - first inventory command used manifest instead of required `--index` input; corrected by creating explicit index file,
   - first Step 25B rerun referenced a wrong timestamped inventory filename; corrected to emitted exact path,
   - first Step 25D/rollup command attempt used incomplete/mismatched arguments/timestamps; rerun with exact emitted decomposition paths and required flags.

12. Expected movement checklist:
   - ON `transition_wait` decreases versus rejected resize-delay60 evidence,
   - some resize work may shift to client-lifecycle attribution,
   - total ON action-window must not increase,
   - no per-tab readiness regression on Current vs. Average, Historical Trend, Heatmap, or Map.
13. Outcome against expected movement:
   - FAIL: ON `transition_wait` did not decrease,
   - FAIL: total ON action-window increased,
   - no threshold relaxation attempted,
   - rollback executed.

## Execution Update (8I-05 / 8I-06 / 8I-07)

1. First implementation hypothesis selected (small and reversible):
   - target: reduce reducible tab-transition wait by lowering client `forcePlotlyResize` debounce for main-tab dispatch path.
   - edit shape:
      - added optional client delay support in `Programs/app_source/ui.R` for `forcePlotlyResize`,
      - sent `resize_delay_ms = 60` only from `observeEvent(main_tabs_panel)` path in `Programs/app_source/server/02_partner_and_notes.R`.
2. Narrow smoke result:
   - command label: `tranche8i_client_readiness_phase3_resize_delay60_smoke`
   - output: `Logs/vp_perf_probe_single_action_latency_tranche8i_client_readiness_phase3_resize_delay60_smoke_20260805T140221Z.csv`
   - status: `PASS=4` (tab-only smoke passed).
3. Strict replicated ON cohort result (markers ON, unchanged thresholds):
   - acceptance manifest: `Logs/vp_perf_acceptance_run_manifest_tranche8i_client_readiness_acceptance_i9_resize_delay60_20260805T140720Z.csv`
   - decision: `Logs/vp_perf_acceptance_decision_tranche8i_client_readiness_acceptance_i9_resize_delay60__decision_20260805T151839Z_decision.csv`
   - gate: FAIL.
   - startup median: baseline `81156` ms vs candidate `83953` ms (`-3.446%` improvement ratio).
   - single-action median: baseline `9396` ms vs candidate `10451.5` ms (`-11.234%` improvement ratio).
4. Strict replicated OFF cohort recovery chain:
   - first OFF run (`tranche8i_client_readiness_acceptance_i9_resize_delay60_off`) failed preflight due one contaminated single-action row (`FAIL=1|PASS=3`, `PARTIAL=1|PASS=3`).
   - OFF rerun1 failed preflight due one startup row `status=FAIL`.
   - OFF rerun2 used higher timeouts (`startup=180000`, `stage=60000`, `output=60000`, `full-idle=60000`) and passed strict preflight/context/identity.
   - clean OFF decision: `Logs/vp_perf_acceptance_decision_tranche8i_client_readiness_acceptance_i9_resize_delay60_off_rerun2__decision_20260805T184740Z_decision.csv`.
   - gate: FAIL.
   - startup median: baseline `70371` ms vs candidate `70268` ms (`+0.146%` improvement ratio; below threshold `0.25`).
   - single-action median: baseline `8326` ms vs candidate `8397` ms (`-0.853%` improvement ratio).
5. Exact-path post-edit OFF/ON chain emitted (clean):
   - index: `Logs/vp_perf_acceptance_index_tranche8i_off_on_i9_resize_delay60_20260805.csv`
   - inventory: `Logs/vp_perf_acceptance_inventory_tranche8i_off_on_i9_resize_delay60_inventory_20260805T184802Z.csv`
   - Step 25B summary: `Logs/vp_perf_acceptance_inventory_validation_tranche8i_off_on_i9_resize_delay60_validation_20260805T184821Z_summary.csv`
   - decomposition detail/runs/summary: `Logs/vp_perf_acceptance_decomposition_tranche8i_off_on_i9_resize_delay60_decomp_20260805T184822Z_detail.csv`; `Logs/vp_perf_acceptance_decomposition_tranche8i_off_on_i9_resize_delay60_decomp_20260805T184822Z_runs.csv`; `Logs/vp_perf_acceptance_decomposition_tranche8i_off_on_i9_resize_delay60_decomp_20260805T184822Z_summary.csv`
   - rollup: `Logs/vp_perf_acceptance_decomposition_tranche8i_off_on_i9_resize_delay60_rollup_20260805T185320Z_action_bucket.csv`; `Logs/vp_perf_acceptance_decomposition_tranche8i_off_on_i9_resize_delay60_rollup_20260805T185320Z_lane_delta.csv`; `Logs/vp_perf_acceptance_decomposition_tranche8i_off_on_i9_resize_delay60_rollup_20260805T185320Z_lane_confidence.csv`
   - audit: `Logs/vp_perf_acceptance_decomposition_tranche8i_off_on_i9_resize_delay60_audit_20260805T185322Z_audit_summary.json`
   - 8I split rerun: `Logs/vp_perf_client_readiness_split_tranche8i_client_readiness_split_resize_delay60_20260805T185337Z_role_pair_summary.csv`
6. Post-edit rollup interpretation:
   - action-window lane delta: baseline `634557.2` ms, candidate `657130.2` ms, delta `+22573.0` ms, improvement `-3.56%`.
   - bucket movement remained wait/lifecycle-heavy:
      - baseline transition_wait share `30.57%`, candidate `31.05%`,
      - baseline client_lifecycle share `30.45%`, candidate `30.16%`,
      - baseline client_wait share `14.86%`, candidate `14.25%`.
   - ON split remained transition-wait dominant and worsened candidate share:
      - ON baseline transition_wait `52.34%`, ON candidate `55.22%`.
7. Decision and rollback:
   - hypothesis rejected on strict evidence.
   - reverted probe edits in:
      - `Programs/app_source/ui.R`
      - `Programs/app_source/server/02_partner_and_notes.R`
   - parse checks after rollback passed for both files.
8. Recommended next target (8I next hypothesis):
   - keep marker-provenance expansion as fallback.
   - next small reversible target should focus on reducing ON `transition_wait` without increasing ON action-window total, likely by tightening readiness trigger ordering around `tab_shown` / `tab_after_paint` vs server `visible_ready` path rather than reducing a global resize delay.
   - preserve strict OFF/ON pair protocol with clean-room manifests and unchanged thresholds.

## Execution Update (8I-02 / 8I-03)

1. Implemented a dedicated read-only split helper:
   - `System/Testing/vp_perf_step25c_client_readiness_split_8i.R`
2. Ran the helper on immutable fresh 8G inputs:
   - detail: `Logs/vp_perf_acceptance_decomposition_tranche8g_off_on_i9_phase3_strict_fresh_20260805T010825Z_detail.csv`
   - runs: `Logs/vp_perf_acceptance_decomposition_tranche8g_off_on_i9_phase3_strict_fresh_20260805T010825Z_runs.csv`
   - label: `tranche8i_client_readiness_split_existing_8g`
3. Phase 1 artifacts emitted:
   - `Logs/vp_perf_client_readiness_split_tranche8i_client_readiness_split_existing_8g_20260805T135916Z_signature.csv`
   - `Logs/vp_perf_client_readiness_split_tranche8i_client_readiness_split_existing_8g_20260805T135916Z_gap_context.csv`
   - `Logs/vp_perf_client_readiness_split_tranche8i_client_readiness_split_existing_8g_20260805T135916Z_role_pair_summary.csv`
4. Key action-window split outcomes:
   - OFF baseline action-window shares:
      - client_lifecycle `48.99%`,
      - transition_wait `29.88%`,
      - client_wait `21.13%`.
   - OFF candidate action-window shares:
      - client_lifecycle `47.86%`,
      - transition_wait `31.95%`,
      - client_wait `20.19%`.
   - ON rerun baseline action-window shares:
      - transition_wait `52.98%`,
      - client_lifecycle `33.25%`,
      - client_wait `13.77%`.
   - ON rerun candidate action-window shares:
      - transition_wait `53.78%`,
      - client_lifecycle `32.98%`,
      - client_wait `13.25%`.
5. Gate decision (8I-03):
   - Actionability gate met.
   - A dominant sub-family is already explicit in fresh evidence (`transition_wait`, ON action-window about `53%`, above the `25%` threshold and greater than runner-up).
   - Next step should proceed to one small implementation hypothesis targeting reducible wait/transition path behavior, not immediate marker-provenance expansion.
   - Marker-provenance remains available as fallback if the first implementation hypothesis cannot reduce the dominant wait path or reveals ownership ambiguity.

## Blockers And Risks

1. Fresh detail artifacts may not expose enough source/context for an actionable split.
   - Mitigation: read-only split first; marker-provenance only if needed.
2. Instrumentation may perturb timing.
   - Mitigation: OFF/ON perturbation smoke before interpretation.
3. Synthetic wait may remain dominant but non-actionable.
   - Mitigation: no-decision diagnostic closeout permitted.
4. OneDrive/Windows file locking may contaminate logs/manifests.
   - Mitigation: clean-room manifests, strict preflight checks, rerun contaminated cohorts.
5. Quoting brittleness in one-liner summaries.
   - Mitigation: prefer helper script or simple `Import-Csv` pipelines.

## Relevant Files

1. `Code Review/2026-08-03_vp_commodity_partition_sidecar_architecture_plan.md`
2. `System/Testing/vp_perf_decompose_single_action_8c.R`
3. `System/Testing/vp_perf_step25c_bucket_rollup_8c.R`
4. `System/Testing/vp_perf_acceptance_manifest_to_inventory.R`
5. `System/Testing/vp_perf_validate_inventory_step25b_8c.R`
6. `System/Testing/vp_perf_step25d_attribution_audit_8c.R`
7. `Programs/app_source/ui.R`
8. `Programs/app_source/server/04_comparison_plots.R`
9. `Programs/app_source/server/05_trend_and_heatmap.R`
10. `Programs/app_source/server/02_partner_and_notes.R`

## Verification Checklist

1. Daughter plan exists with parent reference, scope, guardrails, immutable baseline, actionability gate, command templates, and summary placeholder.
2. Parent plan receives kickoff rollup pointing to this daughter plan.
3. Phase 1 derivative split artifacts are generated from exact 8G inputs.
4. Any instrumentation passes perturbation neutrality before interpretation.
5. Any implementation edit passes smoke before strict replicated acceptance.
6. Final recommendation cites exact artifact paths.

## Execution Update (8I-27)

1. Scope implemented (diagnostic-only cache ablation framework, `comparison_plot` final output only):
   - objective: make cache ON/OFF lane identity explicit and deterministic without global cache disable,
   - no decomposition-threshold changes,
   - no broad readiness or resize behavior refactors,
   - no optimization claim.
2. Server output wiring update (`Programs/app_source/server/04_comparison_plots.R`):
   - added comparison-plot cache-mode helpers and explicit cache-off resolver,
   - switched final output assignment to conditional branch:
      - cache ON path: existing `bindCache(...)` key usage unchanged,
      - cache OFF path: final output assignment without `bindCache(...)`,
   - propagated explicit mode fields into marker payloads and server-output provenance fields:
      - `comparison_plot_cache_off`,
      - `comparison_plot_cache_mode`,
      - `comparison_plot_cache_mode_source`,
      - `final_output_bindcache_enabled`.
3. Probe and orchestrator plumbing updates:
   - `System/Testing/vp_perf_probe_single_action_latency.R`:
      - added `--comparison-plot-cache-off` arg parse and env propagation,
      - added cache-mode fields to action rows and acceptance manifest writes,
      - added focused scenario `tab_current_only` to isolate Current vs. Average tab-settled action from non-current-tab readiness noise.
   - `System/Testing/vp_perf_probe_startup.R`:
      - added `--comparison-plot-cache-off` arg parse/env propagation and mode fields in startup outputs.
   - `System/Testing/vp_perf_run_acceptance_pair.R`:
      - added baseline/candidate cache-off args and forwarding to startup + single-action probes,
      - expected-context row builder now includes cache-off/mode/bindcache expectations.
   - `System/Testing/vp_perf_acceptance_manifest.R`:
      - context validator now checks optional expected cache mode fields,
      - mismatch reasons include cache-off/mode/bindcache mismatches.
4. Runtime lane-identity hardening:
   - `Programs/app_source/global.R`:
      - runtime probe identity payload now includes:
         - `probe_comparison_plot_cache_off`,
         - `probe_comparison_plot_cache_mode`.
   - `System/Testing/vp_perf_acceptance_manifest.R`:
      - runtime identity validation now checks runtime-log values against expected manifest cache-off/mode when present,
      - emits explicit mismatch reasons and counts for cache-off/mode identity failures.
5. Validation commands and parse outcomes:
   - parse checks passed:
      - `PARSE_OK_GLOBAL` (`Programs/app_source/global.R`),
      - `PARSE_OK_MANIFEST` (`System/Testing/vp_perf_acceptance_manifest.R`),
      - `PARSE_OK_SINGLE_ACTION` (`System/Testing/vp_perf_probe_single_action_latency.R`),
   - editor diagnostics: no errors in touched files.
6. Smoke evidence (standard tab-only lane):
   - cache ON (`tab_only`):
      - `Logs/vp_perf_probe_single_action_latency_tranche8j_comparison_cache_on_smoke_20260807T175750Z.csv`,
      - `Logs/vp_runtime_perf_single_action_tranche8j_comparison_cache_on_smoke_20260807T175750Z.jsonl`,
      - status counts: `FAIL=4`.
   - cache OFF (`tab_only`):
      - `Logs/vp_perf_probe_single_action_latency_tranche8j_comparison_cache_off_smoke_20260807T180126Z.csv`,
      - `Logs/vp_runtime_perf_single_action_tranche8j_comparison_cache_off_smoke_20260807T180126Z.jsonl`,
      - status counts: `FAIL=3`, `PASS=1`.
   - startup OFF smoke:
      - `Logs/vp_perf_probe_startup_tranche8j_startup_cache_off_smoke_20260807T180438Z.csv`,
      - `Logs/vp_runtime_perf_startup_tranche8j_startup_cache_off_smoke_20260807T180439Z.jsonl`,
      - status counts: `PASS=1`.
   - mode fields were consistent in these artifacts:
      - ON lane: `comparison_plot_cache_off=FALSE`, `comparison_plot_cache_mode=final_output_cache_on`, `final_output_bindcache_enabled=TRUE`,
      - OFF lane: `comparison_plot_cache_off=TRUE`, `comparison_plot_cache_mode=final_output_cache_off`, `final_output_bindcache_enabled=FALSE`.
7. Smoke evidence (current-only stabilization lane):
   - cache ON (`tab_current_only`):
      - `Logs/vp_perf_probe_single_action_latency_tranche8j_comparison_cache_on_smoke_current_only_20260807T181246Z.csv`,
      - `Logs/vp_runtime_perf_single_action_tranche8j_comparison_cache_on_smoke_current_only_20260807T181246Z.jsonl`,
      - status counts: `PASS=1`.
   - cache OFF (`tab_current_only`):
      - `Logs/vp_perf_probe_single_action_latency_tranche8j_comparison_cache_off_smoke_current_only_20260807T181449Z.csv`,
      - `Logs/vp_runtime_perf_single_action_tranche8j_comparison_cache_off_smoke_current_only_20260807T181449Z.jsonl`,
      - status counts: `PASS=1`.
   - interpretation:
      - non-current-tab actions are the dominant source of smoke instability in standard `tab_only` runs for this tranche,
      - current-only lane is stable and preserves cache-mode observability.
8. Failures and fixes during this step:
   - command quoting failures in PowerShell parse/summarization one-liners were corrected (quoted Rscript path and avoided `$` interpolation pitfalls),
   - no product-code rollback required; all code changes remained valid.
9. Next gate (explicit):
   - run strict replicated ON/OFF pair using current-only scenario to remove non-current-tab smoke churn:
      - `--baseline-scenario=tab_current_only`,
      - `--candidate-scenario=tab_current_only`,
      - paired with explicit baseline/candidate cache-off flags,
   - then execute exact-path chain (Step25A/25B/25C/25D/rollup/Step25F) only if strict preflight/context/runtime identity all pass.

## Execution Update (8I-28)

1. Scope executed:
   - strict current-only ON/OFF acceptance pair in the cache-ablation lane,
   - exact-path chain run on the strict-pair retry artifact set,
   - narrow Step25F hardening edit to prevent dominant-phase selection crashes when all phase candidates are non-finite for a group,
   - no optimization claim and no acceptance-threshold change.
2. Strict pair attempt 1 (current-only ON/OFF):
   - command label:
      - `tranche8j_comparison_cache_on_off_current_only_i1`,
   - run manifest:
      - `Logs/vp_perf_acceptance_run_manifest_tranche8j_comparison_cache_on_off_current_only_i1_20260807T181804Z.csv`,
   - preflight outcome:
      - context: `FAIL` (`status_not_clean|base_status_not_clean`),
      - runtime identity: `PASS`,
   - blocker detail:
      - candidate startup row failed required-controls wait in this run (`country_choice|commodity_choice` timeout), so decision stage was correctly blocked by strict preflight gate.
3. Strict pair retry (stabilized timeouts):
   - command label:
      - `tranche8j_comparison_cache_on_off_current_only_i1_retry1`,
   - run manifest:
      - `Logs/vp_perf_acceptance_run_manifest_tranche8j_comparison_cache_on_off_current_only_i1_retry1_20260807T182630Z.csv`,
   - preflight outcome:
      - manifest rows: `4/4` expected,
      - context: `PASS` (`0` failures),
      - runtime identity: `PASS` (`0` failures),
   - strict decision artifacts:
      - summary: `Logs/vp_perf_acceptance_decision_tranche8j_comparison_cache_on_off_current_only_i1_retry1__decision_20260807T183333Z_summary.csv`,
      - detail: `Logs/vp_perf_acceptance_decision_tranche8j_comparison_cache_on_off_current_only_i1_retry1__decision_20260807T183333Z_details.csv`,
      - decision: `Logs/vp_perf_acceptance_decision_tranche8j_comparison_cache_on_off_current_only_i1_retry1__decision_20260807T183333Z_decision.csv`,
   - decision rows:
      - startup: `FAIL` (`improvement_ratio=0.070035`, threshold `0.25`, CI lower `-18.836528`, upper `0.959071`),
      - single_action: `FAIL` (`improvement_ratio=-0.076923`, threshold `0.20`, CI lower `-16.805000`, upper `0.935075`),
      - overall: `FAIL`.
4. Exact-path chain bootstrap for retry artifacts:
   - created acceptance index:
      - `Logs/vp_perf_acceptance_index_tranche8j_off_on_i1_comparison_cache_on_off_current_only_retry1_20260807.csv`,
   - index columns populated per contract:
      - lane, pair_run_label, clean_room_manifest_csv, decision_summary_csv, decision_details_csv, decision_file_csv.
5. Step25A inventory:
   - label:
      - `tranche8j_off_on_i1_comparison_cache_on_off_current_only_retry1_inventory`,
   - inventory CSV:
      - `Logs/vp_perf_acceptance_inventory_tranche8j_off_on_i1_comparison_cache_on_off_current_only_retry1_inventory_20260807T183559Z.csv`,
   - inventory JSON:
      - `Logs/vp_perf_acceptance_inventory_tranche8j_off_on_i1_comparison_cache_on_off_current_only_retry1_inventory_20260807T183559Z.json`,
   - rows: `4`,
   - OK rows: `4`,
   - quarantine rows: `0`.
6. Step25B validation:
   - label:
      - `tranche8j_off_on_i1_comparison_cache_on_off_current_only_retry1_validation`,
   - summary CSV:
      - `Logs/vp_perf_acceptance_inventory_validation_tranche8j_off_on_i1_comparison_cache_on_off_current_only_retry1_validation_20260807T183604Z_summary.csv`,
   - detail CSV:
      - `Logs/vp_perf_acceptance_inventory_validation_tranche8j_off_on_i1_comparison_cache_on_off_current_only_retry1_validation_20260807T183604Z_detail.csv`,
   - reasons CSV:
      - `Logs/vp_perf_acceptance_inventory_validation_tranche8j_off_on_i1_comparison_cache_on_off_current_only_retry1_validation_20260807T183604Z_reasons.csv`,
   - totals:
      - total rows: `4`,
      - OK rows: `4`,
      - quarantine rows: `0`,
      - comparison-validity-complete rows: `4`.
7. Step25C decomposition:
   - label:
      - `tranche8j_off_on_i1_comparison_cache_on_off_current_only_retry1_decomp`,
   - detail CSV:
      - `Logs/vp_perf_acceptance_decomposition_tranche8j_off_on_i1_comparison_cache_on_off_current_only_retry1_decomp_20260807T183611Z_detail.csv`,
   - summary CSV:
      - `Logs/vp_perf_acceptance_decomposition_tranche8j_off_on_i1_comparison_cache_on_off_current_only_retry1_decomp_20260807T183611Z_summary.csv`,
   - runs CSV:
      - `Logs/vp_perf_acceptance_decomposition_tranche8j_off_on_i1_comparison_cache_on_off_current_only_retry1_decomp_20260807T183611Z_runs.csv`,
   - window confidence CSV:
      - `Logs/vp_perf_acceptance_decomposition_tranche8j_off_on_i1_comparison_cache_on_off_current_only_retry1_decomp_20260807T183611Z_window_confidence.csv`,
   - inconclusive gate CSV:
      - `Logs/vp_perf_acceptance_decomposition_tranche8j_off_on_i1_comparison_cache_on_off_current_only_retry1_decomp_20260807T183611Z_inconclusive_gate.csv`,
   - selected rows: `2`,
   - run rows: `2`,
   - detail rows: `738`,
   - summary rows: `42`,
   - run inconclusive count: `0/2`,
   - lane inconclusive count: `0`.
8. Step25D attribution audit:
   - label:
      - `tranche8j_off_on_i1_comparison_cache_on_off_current_only_retry1_audit`,
   - classification audit CSV:
      - `Logs/vp_perf_acceptance_decomposition_tranche8j_off_on_i1_comparison_cache_on_off_current_only_retry1_audit_20260807T183635Z_classification_audit.csv`,
   - window bucket CSV:
      - `Logs/vp_perf_acceptance_decomposition_tranche8j_off_on_i1_comparison_cache_on_off_current_only_retry1_audit_20260807T183635Z_window_bucket.csv`,
   - confidence comparison CSV:
      - `Logs/vp_perf_acceptance_decomposition_tranche8j_off_on_i1_comparison_cache_on_off_current_only_retry1_audit_20260807T183635Z_confidence_comparison.csv`,
   - audit summary JSON:
      - `Logs/vp_perf_acceptance_decomposition_tranche8j_off_on_i1_comparison_cache_on_off_current_only_retry1_audit_20260807T183635Z_audit_summary.json`.
9. Step25C rollup:
   - label:
      - `tranche8j_off_on_i1_comparison_cache_on_off_current_only_retry1_rollup`,
   - action bucket CSV:
      - `Logs/vp_perf_acceptance_decomposition_tranche8j_off_on_i1_comparison_cache_on_off_current_only_retry1_rollup_20260807T183641Z_action_bucket.csv`,
   - lane delta CSV:
      - `Logs/vp_perf_acceptance_decomposition_tranche8j_off_on_i1_comparison_cache_on_off_current_only_retry1_rollup_20260807T183641Z_lane_delta.csv`,
   - lane confidence CSV:
      - `Logs/vp_perf_acceptance_decomposition_tranche8j_off_on_i1_comparison_cache_on_off_current_only_retry1_rollup_20260807T183641Z_lane_confidence.csv`,
   - candidate action-window top shares:
      - `client_lifecycle=64.23%`,
      - `transition_wait=31.39%`,
      - `client_wait=2.09%`,
      - `hierarchy_fanout=1.11%`,
      - `unclassified=0.22%`.
10. Step25F execution and hardening:
   - initial Step25F run failed with dominant-phase selection error when all candidate medians were non-finite for one summary group,
   - narrow fix applied in `System/Testing/vp_perf_step25f_output_materialization_phase_view_8i.R`:
      - compute dominant phase only from finite candidates; return `NA` otherwise,
      - no change to timeline extraction, row selection, or artifact schema,
   - parse check passed: `PARSE_OK_STEP25F`,
   - successful rerun artifacts:
      - action rows: `Logs/vp_perf_output_materialization_phase_view_tranche8j_comparison_cache_on_off_current_only_i1_retry1_current_phase_view_20260807T183727Z_action_rows.csv`,
      - lane summary: `Logs/vp_perf_output_materialization_phase_view_tranche8j_comparison_cache_on_off_current_only_i1_retry1_current_phase_view_20260807T183727Z_lane_summary.csv`,
      - coverage: `Logs/vp_perf_output_materialization_phase_view_tranche8j_comparison_cache_on_off_current_only_i1_retry1_current_phase_view_20260807T183727Z_coverage.csv`,
   - coverage metrics:
      - expected single-action runs: `2`,
      - action rows: `2`,
      - pass rows: `2`,
      - server-anchor-complete rows: `1`.
11. Interpretation at this gate:
   - strict context/runtime identity pipeline is now proven for current-only ON/OFF under stabilized timeouts,
   - strict decision remains threshold-FAIL at `n=1`, which is expectedly non-actionable for optimization claims in this diagnostic tranche,
   - exact-path integrity chain is clean (`0` quarantined rows), so attribution evidence remains valid for ongoing diagnostic narrowing,
   - Step25F guard hardening removes a brittle summary crash without changing measurement semantics.
12. Next action recommendation:
   - run strict replicated current-only ON/OFF cohort (`i9`) with stabilized timeout envelope,
   - repeat exact-path chain on that cohort,
   - only then assess whether cache-off lane materially shifts Current timeline components beyond noise bands.

## Conclusion Update (8I-28 Cache-Off Attribution Lesson)

1. What cache-off was expected to prove:
   - working hypothesis: if final-output `bindCache(...)` was hiding the `comparison_plot` render body, then disabling that cache layer should force ordinary render/function execution and make the long Current delay attributable to visible server/render/function spans.
2. What actually improved:
   - cache-off materially improved lane identity and evidence integrity:
      - cache ON vs. cache OFF rows now carry explicit mode fields,
      - runtime identity validation checks those mode fields,
      - current-only smoke showed both lanes can pass cleanly,
      - exact-path inventory/validation stayed clean with `0` quarantine rows.
   - this means attribution of *which experimental lane produced a row* is now stronger and less ambiguous.
3. What did not improve enough:
   - cache-off did not turn the long delay into a clearly owned function span,
   - the delay still did not collapse into server-render, Plotly materialization, or another ordinary measured phase,
   - Step25F remained partially anchor-limited for this small current-only cohort, and the successful rerun produced valid integrity evidence but not a decisive function owner.
4. Corrected interpretation:
   - the mistaken assumption was that disabling final-output cache would automatically expose hidden time as render-body/function time,
   - the evidence instead suggests the important gap is still a delivery/invalidation/scheduling interval before browser `shiny:value` receipt,
   - that interval can persist even when final-output caching is disabled because upstream reactive invalidation, dependency readiness, Shiny output scheduling, and provider/data cache layers are not made function-owned merely by bypassing the final output `bindCache(...)`.
5. Practical implication:
   - cache-off is useful as a lane-control and attribution-integrity diagnostic,
   - cache-off alone is not sufficient as a function-ownership diagnostic for this delay,
   - the next attribution improvement should instrument or profile the upstream `comparison_plot` dependency chain and output invalidation/scheduling path directly, rather than expecting another cache toggle or boundary marker to name the owner.
6. Updated next diagnostic direction:
   - preserve the current cache-mode lane identity checks,
   - add narrowly scoped function/reactive ownership timing around the `comparison_plot` dependencies that decide dirtiness, compute inputs, and hand the value to Shiny delivery,
   - include output invalidation/scheduling markers if available,
   - continue to treat performance-decision output as non-promotional unless a true implementation change passes strict replicated evidence.

## Summary (Plain Terms)

Tranche 8I still rejects repair promotion and remains in diagnostic proof mode. Current vs. Average evidence continues to show the long wait before target `comparison_plot` Shiny value delivery, with fast browser/Plotly materialization after value receipt. 8I-20 made cache-key evaluation observable on the `comparison_plot` `bindCache(...)` path; 8I-21 made that evidence more honest by adding join-confidence, clock-basis, candidate-count, and earliest/latest/selected reporting. 8I-22 smoke-validated observable downstream provenance and made absent render/flush markers explicit as `cache_hit_or_body_bypass_possible` instead of silent `NA`. 8I-23 then added the cheapest post-cache-key/pre-`shiny:value` discriminator: a non-render-body `session$onFlushed(...)` marker registered from the cache-key observer. The final OFF/ON smoke pair stayed healthy (`PASS=4` each), OFF markers stayed absent, ON emitted 10 cache-key and 10 post-cache markers, and the Current row joined one post-cache marker near the action boundary (`output_post_cache_key_flush_observed_ms=-276`, `medium_action_window_join`, `server_elapsed_ms`) while browser value receipt remained late (`output_client_value_received_ms=11139`). This points away from browser/Plotly materialization and away from simple absence of an observable server flush boundary; the remaining diagnostic owner is narrower: output invalidation/scheduling/cache-hit delivery between the post-cache-key flush boundary and browser `shiny:value`. Ownership remains diagnostic-only; the next step is a strict replicated diagnostic cohort using this marker schema before any behavioral repair is proposed.
