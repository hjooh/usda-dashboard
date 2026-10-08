# VP Mixed-Volume Runtime Churn Optimization Plan

Date: 2026-07-29
Branch: main
Status: Complete. This daughter plan remains the source of truth for the completed mixed-volume runtime churn optimization patch.

## Purpose

The parent VP performance recovery plan identified repeated runtime hierarchy filtering as the first measured optimization target. The immediate purpose of this daughter plan is to preserve pipeline-driven mixed-volume correctness while eliminating repeated Shiny-time full-context scans behind `mixed_volume_family_check` and `quantity_units_context`.

This is not an aggregation rewrite. `vp_volume_family_mixed` remains the pipeline-produced truth flag for mixed liquid/weight VP volume contexts. The optimization target is runtime churn: the app repeatedly refilters the same resolved VP context to rediscover mixed-volume and quantity-unit state that should be computed once per complete context key and reused safely.

## Scope

Included:
- Create this daughter source-of-truth ledger and keep it updated before every implementation tranche transition.
- Amend the parent plan to delegate this first measured optimization patch here before code edits.
- Optimize repeated runtime calls around `vp_rollup_context_has_mixed_volume_family()`, `vp_trade_context_rows_for_quantity_units()`, `vp_trade_context_volume_family()`, `vp_trade_quantity_unit_unavailable_reason()`, `vp_trade_quantity_unit_choices_for_context()`, `vp_trade_default_quantity_unit_for_context()`, and `apply_vp_context_metric_filters()` in `VP Clone/Programs/app_source/server/02_partner_and_notes.R`.
- Prefer helper consolidation or session-local memoization so filtered context rows and derived mixed/volume-family state are computed once per complete key and reused by repeated consumers.
- Preserve current user-visible mixed-volume metric blocking and quantity-unit availability behavior unless a deliberate measured change is recorded here first.
- Improve before/after attribution by fixing forced runtime log routing or recording exact runtime process/session log paths used by the validation probe.
- Close this daughter plan with implementation results, validation evidence, residual risks, and parent-plan handoff notes.

Excluded:
- Changing `vp_volume_family_mixed` generation in `VP Clone/Programs/vp_data_utils.R` unless validation exposes a true pipeline bug.
- Deleting `vp_volume_family_mixed` or weakening the smoke contract that requires it.
- Treating mixed liquid and weight volumes as convertible.
- Broad data-format rewrites, partition-provider rewrites, MYCT feature repair, or UI copy changes unless directly required by this patch.
- Creating a paired results markdown file unless explicitly requested.

## Parent Plan Linkage

Parent plan: `VP Clone/Code Review/2026-07-29_vp_performance_hotspot_recovery_plan.md`.

This daughter/progeny plan owns the implementation details for parent Step 8, "Optimize first measured hotspot." The parent remains the broad performance recovery ledger. During this patch, the parent should contain only the delegation note, high-level status, and closeout summary; detailed decisions, failed attempts, validation commands, and probe evidence belong here.

At closeout:
- Complete this daughter `## Summary` section.
- Update the parent Step Ledger with the outcome.
- Add parent tranche notes with output paths, validation markers, performance result, residual risk, and the next recommended parent-plan target.
- Recenter future work on the parent plan.

## Source-Of-Truth Ledger Contract

- This file is the active source of truth for the mixed-volume runtime churn optimization patch.
- Update this file after every step or tranche before moving to the next tranche.
- Record files touched, commands/probes, benchmark labels, cache-state labels, runtime log paths, PERF summaries, churn deltas, bugs, blockers, failed attempts, rejected approaches, and decision gates.
- Keep parent-plan updates limited to delegation and closeout while this daughter plan is active.
- Preserve enough detail that a future coder can resume without replaying chat history.
- At completion, provide a short chat summary and complete the final `## Summary` section in this file.

## Baseline Evidence

Fresh runtime evidence came from the successful long bounded hierarchy probe:
- Probe label: `long_bounded_hierarchy_probe_jsfinal`.
- Probe CSV: `VP Clone/Logs/vp_perf_probe_hierarchy_transition_long_bounded_hierarchy_probe_jsfinal_20260729T165257Z.csv`.
- Runtime summary label: `long_bounded_hierarchy_probe_jsfinal`.
- Runtime summary files were produced at `VP Clone/Logs/vp_perf_runtime_summary_long_bounded_hierarchy_probe_jsfinal_20260729T165638Z_*.csv`.
- Probe status: PASS.
- Cache-state label: `unknown_cache_state`.
- Startup ready: 85.480 seconds.
- Source switch: 551 ms.
- Trade flow stage: 15.591 seconds.
- Hierarchy stage: 82.383 seconds.
- Total probe: 184.143 seconds.
- Runtime summary read 2 runtime files and 1363 records.
- `filter_vp_rows_for_resolved_hierarchy()` appeared 364 times totaling 20.9175 seconds.
- Top helper churn records:
  - `filter_vp_rows_for_resolved_hierarchy_mixed_volume_family_check`: 162 calls.
  - `filter_vp_rows_for_resolved_hierarchy_quantity_units_context`: 118 calls.
  - `filter_vp_rows_for_resolved_hierarchy_display_month_mapping`: 36 calls.
  - `filter_vp_rows_for_resolved_hierarchy_type_choice_base_values`: 15 calls.
  - `filter_vp_rows_for_resolved_hierarchy_filtered_data`: 9 calls.
- Direct non-Shiny VP filters were subsecond in the earlier probe, so the first optimization target is repeated consumer execution/churn rather than raw direct-filter speed.

Baseline caveats:
- The successful probe used `unknown_cache_state`; it is sufficient for target selection, but not ideal as final before/after proof.
- The CSV's requested runtime log path was not created; the app wrote runtime records to default process/session log files. Closeout validation must either fix forced runtime log routing or record the exact process/session runtime log paths used for comparison.
- The current evidence identifies about 20.9 seconds of timed helper work inside a 184.143 second scenario. The optimization target is meaningful, but it should not be described as minutes of helper time for this successful run.

## Technical Read

Pipeline/build semantics:
- `vp_volume_family_mixed` is generated in `VP Clone/Programs/vp_data_utils.R` during all-type and rollup construction.
- `vp_build_app_data()` carries `vp_volume_family_mixed` into app rows and suppresses invalid mixed cumulative volume.
- `VP Clone/System/Testing/vp_shinytest_smoke.R` requires `vp_volume_family_mixed` and asserts mixed rows have `monthlyexports` and `ytd_exports` as `NA`.

Runtime behavior in `VP Clone/Programs/app_source/server/02_partner_and_notes.R`:
- `vp_rollup_context_has_mixed_volume_family()` calls `filter_vp_rows_for_resolved_hierarchy(..., vp_filter_purpose = "mixed_volume_family_check")`, applies a country filter after hierarchy filtering, then checks `any(vp_volume_family_mixed)`.
- `vp_trade_context_rows_for_quantity_units()` calls the same hierarchy filter with `vp_filter_purpose = "quantity_units_context"`, then applies country/custom-country behavior.
- `vp_trade_context_volume_family()` is metric-aware. Unsupported quantity-unit metrics return `"unknown"` before row-family resolution.
- `vp_trade_quantity_unit_unavailable_reason()`, `vp_trade_quantity_unit_choices_for_context()`, and `vp_trade_default_quantity_unit_for_context()` call `vp_trade_context_volume_family()` and can repeat the same row-context work.
- `apply_vp_context_metric_filters()` calls `vp_rollup_context_has_mixed_volume_family()` repeatedly while building several metric choice vectors.
- `filter_vp_rows_for_resolved_hierarchy()` currently records purpose-specific churn counters and key deltas, which should remain available during before/after validation.

## Guardrails

Correctness guardrails:
- Do not remove `vp_volume_family_mixed`.
- Do not treat mixed liquid/weight volume as convertible.
- Do not reintroduce invalid mixed volume aggregates.
- Preserve current mixed-volume metric blocking/default behavior unless a deliberate measured decision is recorded in this plan first.
- Preserve country/custom-country semantics exactly.
- Preserve unsupported-metric behavior in quantity-unit helpers.
- Preserve direct-filter fallback behavior in `filter_vp_rows_for_resolved_hierarchy()`.

Cache-key guardrails:
- If row context is cached, the cache key must include at least source, trade flow, resolved hierarchy choices/filters, resolution mode, path name, strict-rollup flag, sparse-selection flag, commodity name, commodity detail, country choice, and whether the country choice is custom.
- If a metric-aware result is cached, the key must also include metric code.
- Do not cache mixed-volume state by hierarchy alone because country filtering occurs after row retrieval in the current helper path.
- Invalidate or miss the cache when any key input changes.
- Prefer session-local cache or consolidated helper state over global mutable state.

Validation guardrails:
- Keep current `filter_purpose` counters until after churn reduction is measured.
- Add cache hit/miss instrumentation only if needed to prove memoization behavior.
- If high-volume `record_cache_body_execution()` calls appear to materially affect validation, add or use a quiet mode after recording one comparable before/after series.
- Treat current `unknown_cache_state` evidence as target-selection evidence. Closeout evidence should use an explicit cache-state label or document why that remains impossible.

## Step Ledger

| Step | Phase | Work | Status | Evidence / Files | Gate / Next Action |
|---|---|---|---|---|---|
| 1 | A | Create daughter source-of-truth plan | Complete | Added this file before optimization code edits. | Parent plan must reference this daughter plan before implementation begins. |
| 2 | A | Amend parent plan for delegation | Complete | Parent plan marks Step 8 delegated/in progress through this file, allows daughter/progeny delegation in the ledger contract, cleans stale baseline wording, and records the Tranche F handoff note. | Pause for handoff before touching app implementation code. |
| 3 | B | Design shared context helper/cache key | Complete (initial) | Edited `VP Clone/Programs/app_source/server/02_partner_and_notes.R`. Added session-local shared context cache helpers: `vp_trade_context_cache_*`, `vp_trade_context_country_state()`, `vp_trade_context_family_from_rows()`, and `vp_trade_context_entry()`. Key includes source, trade flow, resolved hierarchy and path/resolution flags, commodity name/detail, country mode/value, and custom-country state. Parse check marker: `PARSE_OK_STEP3_SHARED_CONTEXT`. | Validate mixed and quantity behavior against contract checks and known context sanity before probe reruns. |
| 4 | C | Replace repeated mixed-volume scans | Complete (initial) | `vp_rollup_context_has_mixed_volume_family()` now uses `vp_trade_context_entry(...)` with `vp_filter_purpose = "mixed_volume_family_check"` and `country_mode = "mixed_volume_family"`. `apply_vp_context_metric_filters()` now computes mixed-volume state once per build context and reuses it across six VP metric choice vectors. | Confirm mixed-volume metric blocking/default behavior remains unchanged in known mixed and non-mixed contexts. |
| 5 | C | Consolidate quantity-unit context reuse | Complete (initial) | `vp_trade_context_rows_for_quantity_units()` and `vp_trade_context_volume_family()` now route through `vp_trade_context_entry(...)`, and the shared entry carries cached derived `volume_family` plus mixed flag attributes. | Confirm unsupported-metric `unknown` behavior and quantity-unit defaults/choices remain unchanged. |
| 6 | D | Improve runtime log attribution | Complete (documented fallback) | `global.R` honors `VP_PERF_RUNTIME_LOG_FILE`, and `vp_perf_probe_hierarchy_transition.R` sets a requested runtime log path, but the Step 8 requested file again did not materialize. Exact default logs summarized for Step 8: `VP Clone/Logs/vp_runtime_perf_proc_20260729T184436Z_38208.jsonl` and `VP Clone/Logs/vp_runtime_perf_43e6b3927e39871d15f4412224544786.jsonl`. | Treat forced-path routing as a residual instrumentation issue; Step 8 comparison is valid because exact fallback logs were recorded and summarized. |
| 7 | E | Parse and contract validation | Complete | Parse check passed for touched file: `PARSE_OK_STEP3_SHARED_CONTEXT` on `02_partner_and_notes.R`. Mixed-volume artifact contract check passed: `VP_MIXED_CONTRACT_OK` using exact-column extraction. Slow Shiny sanity probe path was replaced with a parent-plan-style artifact-contract probe after repeated idle/read stalls. Refactored probe parse passed: `PARSE_OK_VP_MIXED_QUANTITY_SANITY_INDEXED`. Fast indexed run `step7_mixed_quantity_sanity_artifact_contract_indexed` passed in 16.295 seconds with output `VP Clone/Logs/vp_perf_probe_vp_mixed_quantity_sanity_step7_mixed_quantity_sanity_artifact_contract_indexed_20260729T184127Z.csv`. | Proceed to Step 8: rerun bounded hierarchy probe and summarize runtime logs for churn deltas. |
| 8 | E | Rerun bounded hierarchy probe and summarize logs | Complete | Hierarchy probe `step8_post_mixed_context_cache_hierarchy` passed. CSV: `VP Clone/Logs/vp_perf_probe_hierarchy_transition_step8_post_mixed_context_cache_hierarchy_20260729T184433Z.csv`. Runtime summary label: `step8_post_mixed_context_cache_hierarchy`; summary files: `VP Clone/Logs/vp_perf_runtime_summary_step8_post_mixed_context_cache_hierarchy_20260729T184738Z_*.csv`. Key deltas vs baseline: total probe 184.143s -> 159.596s; hierarchy stage 82.383s -> 68.338s; total hierarchy-filter timed calls 364 / 20.9175s -> 71 / 8.7033s; `mixed_volume_family_check` churn 162 -> 10; `quantity_units_context` churn 118 -> 8. | Proceed to Step 9 closeout: complete daughter summary and update parent. |
| 9 | F | Close daughter and update parent | Complete | Daughter Summary completed below. Parent plan updated with Step 8 outcome, output paths, validation markers, churn/timing deltas, residual risk, and next recommended target. | Recenter future work on parent plan `VP Clone/Code Review/2026-07-29_vp_performance_hotspot_recovery_plan.md`. |

## Phase Plan

Phase A: Handoff setup
- Create this daughter plan.
- Amend parent plan to delegate Step 8 here.
- Validate markdown handoff with `git diff --check`.

Phase B: Local helper design
- Decide between memoization-only and helper consolidation.
- Prefer one shared context helper returning filtered rows plus derived `has_mixed_volume_family` and `volume_family`.
- Keep existing public helper names initially so the patch stays small and reversible.

Phase C: Runtime churn reduction
- Route mixed-volume and quantity-unit context callers through the shared helper/cache.
- Compute mixed-volume state once inside `apply_vp_context_metric_filters()` and reuse it across the six metric choice vectors.
- Preserve current behavior for country, custom-country, unsupported metrics, and default metric handling.

Phase D: Attribution and instrumentation check
- Keep purpose-specific churn counters during validation.
- Fix or document runtime log path attribution inside the Step 8 hierarchy rerun, rather than as a separate pre-Step-8 detour.
- Add minimal cache hit/miss instrumentation only if needed.

Phase E: Focused validation
- Parse touched R files.
- Confirm contract checks for `vp_volume_family_mixed` and mixed-volume NA behavior (re-run if artifact is rebuilt during this patch).
- Run known mixed and known non-mixed context sanity checks if practical.
- Rerun the long bounded hierarchy probe and summarize runtime logs.

Phase F: Closeout
- Complete this plan's Summary.
- Update parent Step 8 and Tranche notes.
- Recenter future performance work on the parent plan.

## Verification and Validation Targets

- Markdown handoff check: `git diff --check -- "VP Clone/Code Review/2026-07-29_vp_performance_hotspot_recovery_plan.md" "VP Clone/Code Review/2026-07-29_vp_mixed_volume_runtime_churn_optimization_plan.md"`.
- Parse checks for touched R files using `C:\Program Files\R\R-4.5.1\bin\Rscript.exe` and grepable `PARSE_OK` markers.
- Contract check that `vp_volume_family_mixed` still exists in `VP Clone/System/Processed Data/vp_trade_monthly_pre.rds`.
- Contract check that mixed rows still have invalid mixed volume metrics suppressed, matching the existing smoke contract.
- Known mixed-volume context sanity check for metric choices and quantity-unit unavailability.
- Known non-mixed context sanity check for metric choices and quantity-unit availability/defaults.
- Long bounded hierarchy probe rerun with explicit cache-state labeling where possible.
- Runtime summarizer before/after comparison for:
  - `filter_vp_rows_for_resolved_hierarchy_mixed_volume_family_check` call count.
  - `filter_vp_rows_for_resolved_hierarchy_quantity_units_context` call count.
  - Total `filter_vp_rows_for_resolved_hierarchy()` calls and elapsed time.
  - Any new cache hit/miss counters if added.

## Bugs, Blockers, Failed Attempts, Rejected Approaches

- Known baseline caveat: the successful hierarchy probe's requested runtime log path was not created; logs were summarized from default process/session files instead.
- Known baseline caveat: the successful hierarchy probe used `unknown_cache_state`, which is enough for target selection but weaker than desired for before/after proof.
- Known harness risk: `shinytest2` can fail around startup, post-mutation idle waits, and Shiny values reads in this workspace.
- Failed validation attempt: first bounded run of `vp_perf_probe_vp_mixed_quantity_sanity.R` (`step7_mixed_quantity_sanity`) returned `FAIL` with repeated stage wait timeouts even when `set_ok=TRUE` for stage mutations; this aligns with known `wait_for_idle` instability and indicates the sanity pass/fail gate should rely on explicit control/state assertions rather than idle success alone.
- Failed validation attempt: hardened Shiny sanity reruns still spent most time in repeated UI waits and stalled after late-stage mutations or reads; one attempted global elapsed-time guard aborted the R process with `reached elapsed time limit`. This confirmed the Shiny path was the wrong primary sanity gate for Step 7.
- Rejected as ongoing Step 7 strategy: continuing to tune the browser-driven mixed/non-mixed sanity probe. Parent-plan probe guidance favors non-Shiny direct probes when possible; this check is a data/contract sanity gate, not a hierarchy-transition performance measurement.
- Known correctness risk: caching without country/custom-country state can return incorrect mixed-volume answers because country filtering currently happens after hierarchy filtering.
- Known correctness risk: caching metric-aware quantity-unit results without `metric_code` can return incorrect `unknown`, `liquid`, `weight`, or `mixed` behavior.
- Validation attempt (resolved): first contract check used `$` extraction and failed with `'list' object cannot be coerced to type 'logical'` because duplicate column names can coerce `$` extraction to a data-frame/list shape. Resolved by using exact `[[...]]` extraction for contract checks.
- Rejected as first response: removing `vp_volume_family_mixed` or weakening the smoke contract.
- Rejected as first response: broad manifest/index metadata probing before a local helper consolidation patch is tried.
- Rejected as first response: changing pipeline aggregation semantics to solve runtime churn.

## Tranche Execution Notes

- 2026-07-29 Tranche A (daughter plan creation):
  - Created this daughter source-of-truth plan for the mixed-volume runtime churn optimization patch.
  - Incorporated audit findings from the parent-plan review:
    - Parent source-of-truth language must allow delegated daughter plans.
    - Parent Step 8 was stale and should be delegated here.
    - Cache keys must include country/custom-country state.
    - Metric-aware cached results must include `metric_code`.
    - `vp_volume_family_mixed` and smoke-contract behavior must remain hard gates.
    - Runtime log attribution and cache-state labeling need tighter closeout evidence than the target-selection baseline.
  - Amended the parent plan to delegate Step 8 here and record the Tranche F handoff note.
  - No implementation code edits have been made under this daughter plan yet.

- 2026-07-29 Tranche B (Step 3 shared context helper and initial routing):
  - Edited `VP Clone/Programs/app_source/server/02_partner_and_notes.R`.
  - Implemented a shared session-local VP context entry/cache layer:
    - `vp_trade_context_cache_get()` / `vp_trade_context_cache_set()`.
    - `vp_trade_context_country_state()` preserving per-caller country normalization mode.
    - `vp_trade_context_family_from_rows()` for derived volume-family classification.
    - `vp_trade_context_entry()` as the shared keyed row-context source.
  - Key design includes source, trade flow, resolved hierarchy choices, resolution mode/path, strict/sparse flags, commodity name/detail, country mode/value, and custom-country state.
  - Routed mixed-volume and quantity-unit helpers through the shared entry:
    - `vp_rollup_context_has_mixed_volume_family()` now consumes `vp_trade_context_entry(...)`.
    - `vp_trade_context_rows_for_quantity_units()` now returns shared entry rows.
    - `vp_trade_context_volume_family()` now reuses shared entry derived family when available.
  - Reduced repeated mixed-volume checks in VP metric-choice filtering:
    - `apply_vp_context_metric_filters()` now receives one precomputed mixed-volume state per build context instead of recomputing it for each of six VP choice vectors.
  - Validation completed in this tranche:
    - Parse check command:
      - `& "C:\Program Files\R\R-4.5.1\bin\Rscript.exe" -e "invisible(parse(file='VP Clone/Programs/app_source/server/02_partner_and_notes.R')); cat('PARSE_OK_STEP3_SHARED_CONTEXT\\n')"`
    - Result: `PARSE_OK_STEP3_SHARED_CONTEXT`.
    - Contract check command:
      - `& "C:\Program Files\R\R-4.5.1\bin\Rscript.exe" -e "artifact <- readRDS('VP Clone/System/Processed Data/vp_trade_monthly_pre.rds'); mixed <- artifact[['vp_volume_family_mixed']]; stopifnot(is.logical(mixed)); mixed_mask <- !is.na(mixed) & mixed; if (any(mixed_mask)) { monthly <- suppressWarnings(as.numeric(artifact[['monthlyexports']])); ytd <- suppressWarnings(as.numeric(artifact[['ytd_exports']])); stopifnot(all(is.na(monthly[mixed_mask]))); stopifnot(all(is.na(ytd[mixed_mask]))); }; cat('VP_MIXED_CONTRACT_OK\\n')"`
    - Result: `VP_MIXED_CONTRACT_OK`.
    - Failed attempt documented and resolved:
      - Initial contract check used `$` extraction and failed with `'list' object cannot be coerced to type 'logical'` because duplicate names can yield data-frame/list extraction shape.
      - Re-ran with exact `[[...]]` extraction and passed.
  - Remaining before performance reruns:
    - Known mixed and non-mixed context sanity checks for metric/unit behavior.
    - Runtime attribution closeout still pending Step 6.

- 2026-07-29 Tranche C (Step 7 mixed/non-mixed sanity probe, first bounded run):
  - Added reusable sanity probe script: `VP Clone/System/Testing/vp_perf_probe_vp_mixed_quantity_sanity.R`.
  - Probe design intentionally reuses existing hierarchy-probe conventions:
    - One-shot bounded run with staged mutation markers (`STAGE_BEGIN`/`STAGE_END`).
    - One-row CSV output contract even on failure.
    - Partial evidence fields for mixed and non-mixed contexts, metric visibility, quantity-unit visibility, and unsupported-metric behavior.
  - Parse validation:
    - `PARSE_OK_VP_MIXED_QUANTITY_SANITY_V2`.
  - First bounded run:
    - Command: `& "C:\Program Files\R\R-4.5.1\bin\Rscript.exe" "VP Clone/System/Testing/vp_perf_probe_vp_mixed_quantity_sanity.R" --label=step7_mixed_quantity_sanity --cache-state=unknown_cache_state --startup-timeout-ms=120000 --stage-timeout-ms=30000`
    - Output CSV: `VP Clone/Logs/vp_perf_probe_vp_mixed_quantity_sanity_step7_mixed_quantity_sanity_20260729T173412Z.csv`
    - Status: `FAIL`.
    - Notable behavior: many stages reported `set_ok=TRUE` but `wait_ok=FALSE` at the 30-second boundary, consistent with known workspace idle-wait instability.
    - Error summary from probe marker: `mixed_apply_failed || mixed_eval_failed:metric_block_ok=FALSE|quantity_ok=FALSE|family_ok=TRUE || nonmixed_apply_failed || nonmixed_eval_failed:metric_block_ok=TRUE|quantity_ok=FALSE|family_ok=FALSE`.
  - Interpretation:
    - The probe wiring and output contract are working.
    - The current pass gate is too coupled to `wait_for_idle` success in this workspace.
  - Next hardening action:
    - Rebase pass/fail gating on explicit post-mutation state assertions (metric/unit controls and context-specific messages/choices), while retaining wait results as diagnostics.

- 2026-07-29 Tranche C follow-up (Step 7 probe refactor and fast sanity pass):
  - Re-read parent probe guidance and compared against existing parent probes:
    - `VP Clone/System/Testing/vp_perf_probe_artifact_load.R`.
    - `VP Clone/System/Testing/vp_perf_probe_vp_filters.R`.
    - `VP Clone/System/Testing/vp_perf_probe_hierarchy_transition.R`.
  - Decision:
    - The mixed/non-mixed sanity gate should not be a full Shiny navigation probe because the parent plan explicitly prefers direct non-Shiny probes for helper/contract checks, while long Shiny probes are reserved for app-path timing such as hierarchy transitions.
    - The previous Shiny sanity probe was too expensive and too coupled to known `shinytest2` idle/read instability.
  - Replaced `VP Clone/System/Testing/vp_perf_probe_vp_mixed_quantity_sanity.R` with a fast artifact-contract probe:
    - One artifact read.
    - One mixed context and one non-mixed context selected from `vp_trade_monthly_pre.rds`.
    - Same marker prefix and one-row CSV output contract.
    - Checks mixed context has `vp_volume_family_mixed`, suppresses invalid mixed `monthlyexports` / `ytd_exports`, expects quantity conversion unavailable for mixed family, expects non-mixed quantity conversion available with family-appropriate default choices, and confirms unsupported quantity-unit metrics resolve to `unknown` semantics.
  - Validation:
    - Initial parse check marker: `PARSE_OK_VP_MIXED_QUANTITY_SANITY_ARTIFACT`.
    - Run command: `& "C:\Program Files\R\R-4.5.1\bin\Rscript.exe" "VP Clone/System/Testing/vp_perf_probe_vp_mixed_quantity_sanity.R" --label=step7_mixed_quantity_sanity_artifact_contract --cache-state=unknown_cache_state`.
    - Result: `PASS`.
    - Output CSV: `VP Clone/Logs/vp_perf_probe_vp_mixed_quantity_sanity_step7_mixed_quantity_sanity_artifact_contract_20260729T184007Z.csv`.
    - Runtime: 27.611 seconds total; artifact load was 11.795 seconds.
  - Runtime follow-up:
    - Avoided rescanning the full artifact after candidate selection by carrying selected context row indices forward from `pick_context_candidates()` into `context_rows()`.
    - Parse check marker after row-index reuse: `PARSE_OK_VP_MIXED_QUANTITY_SANITY_INDEXED`.
    - Indexed run command: `& "C:\Program Files\R\R-4.5.1\bin\Rscript.exe" "VP Clone/System/Testing/vp_perf_probe_vp_mixed_quantity_sanity.R" --label=step7_mixed_quantity_sanity_artifact_contract_indexed --cache-state=unknown_cache_state`.
    - Indexed result: `PASS`.
    - Indexed output CSV: `VP Clone/Logs/vp_perf_probe_vp_mixed_quantity_sanity_step7_mixed_quantity_sanity_artifact_contract_indexed_20260729T184127Z.csv`.
    - Indexed runtime: 16.295 seconds total; artifact load was 10.180 seconds. Remaining time is now mostly artifact load plus one normalized candidate pass, rather than repeated Shiny waits.
  - Final Step 7 evidence uses the indexed run:
    - Mixed context: `export / Vegetables / Vegetables / __vp_rollup_all_market_segment__ / Vegetables, other / Other / GRAND_TOTAL`, 113 rows, family `mixed`, metric block OK, quantity unavailable OK.
    - Non-mixed context: `export / Dry pulses / Dried beans / Dried / Bambara beans / All / GRAND_TOTAL`, 25 rows, family `weight`, metric block OK, quantity available OK, default unit `thousand_lbs`.
  - Step 7 status moved to Complete.

- 2026-07-29 Tranche D (Step 8 hierarchy rerun and runtime summary):
  - Starting Step 8 after Step 7 passed through the indexed artifact-contract sanity probe.
  - Planned validation sequence:
    - Run `VP Clone/System/Testing/vp_perf_probe_hierarchy_transition.R` with runtime PERF enabled and a fresh post-change label.
    - Verify whether the requested `VP_PERF_RUNTIME_LOG_FILE` path in the hierarchy probe CSV exists.
    - If the requested runtime log is missing, record the exact default process/session logs summarized.
    - Run `VP Clone/System/Testing/vp_perf_summarize_runtime_logs.R` and compare mixed-volume / quantity-unit churn against the baseline.
  - Hierarchy probe run:
    - Command: `& "C:\Program Files\R\R-4.5.1\bin\Rscript.exe" "VP Clone/System/Testing/vp_perf_probe_hierarchy_transition.R" --label=step8_post_mixed_context_cache_hierarchy --cache-state=unknown_cache_state --runtime-perf=true --startup-timeout-ms=120000 --stage-timeout-ms=30000`.
    - Result: `PASS`.
    - Output CSV: `VP Clone/Logs/vp_perf_probe_hierarchy_transition_step8_post_mixed_context_cache_hierarchy_20260729T184433Z.csv`.
    - Requested runtime log path from CSV: `VP Clone/Logs/vp_runtime_perf_hierarchy_transition_step8_post_mixed_context_cache_hierarchy_20260729T184433Z.jsonl`.
    - Requested runtime log path check: missing. This reproduces the prior forced-path attribution caveat.
    - Exact fallback runtime logs used for summary:
      - `VP Clone/Logs/vp_runtime_perf_proc_20260729T184436Z_38208.jsonl`.
      - `VP Clone/Logs/vp_runtime_perf_43e6b3927e39871d15f4412224544786.jsonl`.
  - Hierarchy probe timing evidence:
    - Startup ready: 77.791 seconds.
    - Source switch: 535 ms.
    - Trade flow stage: 12.837 seconds.
    - Hierarchy stage: 68.338 seconds.
    - Total probe: 159.596 seconds.
    - All staged waits succeeded.
  - Runtime summary run:
    - Command: `& "C:\Program Files\R\R-4.5.1\bin\Rscript.exe" "VP Clone/System/Testing/vp_perf_summarize_runtime_logs.R" --label=step8_post_mixed_context_cache_hierarchy --input='VP Clone/Logs/vp_runtime_perf_proc_20260729T184436Z_38208.jsonl|VP Clone/Logs/vp_runtime_perf_43e6b3927e39871d15f4412224544786.jsonl'`.
    - Result: summary completed over 2 files and 460 records.
    - Summary outputs:
      - `VP Clone/Logs/vp_perf_runtime_summary_step8_post_mixed_context_cache_hierarchy_20260729T184738Z_files.csv`.
      - `VP Clone/Logs/vp_perf_runtime_summary_step8_post_mixed_context_cache_hierarchy_20260729T184738Z_events.csv`.
      - `VP Clone/Logs/vp_perf_runtime_summary_step8_post_mixed_context_cache_hierarchy_20260729T184738Z_timed.csv`.
      - `VP Clone/Logs/vp_perf_runtime_summary_step8_post_mixed_context_cache_hierarchy_20260729T184738Z_key_delta.csv`.
      - `VP Clone/Logs/vp_perf_runtime_summary_step8_post_mixed_context_cache_hierarchy_20260729T184738Z_churn.csv`.
      - `VP Clone/Logs/vp_perf_runtime_summary_step8_post_mixed_context_cache_hierarchy_20260729T184738Z_partition.csv`.
      - `VP Clone/Logs/vp_perf_runtime_summary_step8_post_mixed_context_cache_hierarchy_20260729T184738Z_memory.csv`.
  - Before/after comparison against the baseline in this plan:
    - Total probe time: 184.143 seconds -> 159.596 seconds, improvement of 24.547 seconds / 13.3%.
    - Hierarchy stage: 82.383 seconds -> 68.338 seconds, improvement of 14.045 seconds / 17.1%.
    - Trade flow stage: 15.591 seconds -> 12.837 seconds, improvement of 2.754 seconds / 17.7%.
    - Runtime summary records: 1363 -> 460.
    - Total `filter_vp_rows_for_resolved_hierarchy()` timed calls: 364 -> 71, reduction of 293 calls / 80.5%.
    - Total `filter_vp_rows_for_resolved_hierarchy()` timed seconds: 20.9175 -> 8.7033, reduction of 12.2142 seconds / 58.4%.
    - `filter_vp_rows_for_resolved_hierarchy_mixed_volume_family_check` churn: 162 -> 10, reduction of 152 calls / 93.8%.
    - `filter_vp_rows_for_resolved_hierarchy_quantity_units_context` churn: 118 -> 8, reduction of 110 calls / 93.2%.
  - Remaining top churn after this patch:
    - `display_month_mapping`: 24 calls.
    - `type_choice_base_values`: 16 calls including one unknown/unknown row.
    - `filtered_data`: 9 calls.
    - `mixed_volume_family_check`: 10 calls total.
    - `quantity_units_context`: 8 calls.
  - Interpretation:
    - The shared context/cache patch achieved the intended first hotspot reduction: the two target churn categories are no longer dominant.
    - The overall probe improved materially, though startup/app mount and artifact load remain large contributors.
    - Forced runtime log routing remains imperfect, but exact fallback logs were recorded and summarized, so the Step 8 comparison is attributable.

## Summary

This daughter patch completed the first measured VP performance optimization target from the parent plan. The app was repeatedly refiltering the same resolved VP trade context to rediscover mixed liquid/weight volume state and quantity-unit state. The fix added a session-local shared VP trade context entry/cache in `VP Clone/Programs/app_source/server/02_partner_and_notes.R`, keyed by the full resolved hierarchy, trade flow, commodity, country/custom-country state, and caller context. Mixed-volume checks and quantity-unit helpers now reuse that shared context instead of repeatedly scanning the same rows, and `apply_vp_context_metric_filters()` now computes mixed-volume state once per metric-choice build instead of repeating it across six vectors.

The patch preserved the pipeline contract: `vp_volume_family_mixed` remains the truth flag for mixed liquid/weight VP volume contexts, mixed contexts still suppress invalid mixed `monthlyexports` / `ytd_exports`, mixed quantity conversion remains unavailable, non-mixed quantity conversion still uses family-appropriate defaults, and unsupported quantity-unit metrics still resolve to `unknown` semantics.

Validation passed at three levels. Parse checks passed for the touched app server file and the refactored sanity probe. The direct artifact contract check passed for `vp_volume_family_mixed` and mixed-volume NA suppression. The original browser-based mixed/non-mixed sanity probe proved too slow and flaky for this gate, so it was replaced with a parent-plan-style artifact-contract probe; the indexed version passed in 16.295 seconds and wrote `VP Clone/Logs/vp_perf_probe_vp_mixed_quantity_sanity_step7_mixed_quantity_sanity_artifact_contract_indexed_20260729T184127Z.csv`.

The post-change bounded hierarchy probe passed and produced the main performance evidence. Total probe time improved from 184.143 seconds to 159.596 seconds. The hierarchy stage improved from 82.383 seconds to 68.338 seconds. Timed `filter_vp_rows_for_resolved_hierarchy()` work dropped from 364 calls / 20.9175 seconds to 71 calls / 8.7033 seconds. The two targeted churn buckets are no longer dominant: `mixed_volume_family_check` dropped from 162 to 10 calls, and `quantity_units_context` dropped from 118 to 8 calls.

The major blocker investigation was probe reliability, not app behavior. `shinytest2` idle waits and Shiny value reads repeatedly caused slow or inconclusive sanity runs, so the patch followed the parent plan's probe ladder and moved the sanity gate to a direct artifact-contract probe. Runtime PERF log attribution remains imperfect: `VP_PERF_RUNTIME_LOG_FILE` is honored in code and requested by the hierarchy probe, but the requested JSONL path did not materialize during Step 8. The comparison is still attributable because the exact fallback runtime logs were recorded and summarized: `VP Clone/Logs/vp_runtime_perf_proc_20260729T184436Z_38208.jsonl` and `VP Clone/Logs/vp_runtime_perf_43e6b3927e39871d15f4412224544786.jsonl`.

Residual risks are limited and documented. Cache correctness depends on keeping the shared key complete, especially country/custom-country state and metric-aware unsupported-unit behavior. Runtime log forced-path routing still needs separate instrumentation cleanup if exact requested log names become important. The Step 8 run still used `unknown_cache_state`, so future before/after runs should use more explicit cache-state labels when practical.

Recommended next parent-plan target: recenter on the parent performance recovery plan and choose the next measured hotspot from fresh Step 8 evidence. The mixed-volume and quantity-unit churn problem is largely handled. Remaining candidates are `display_month_mapping` / `type_choice_base_values` churn during VP hierarchy transitions, startup/app mount work, VP artifact load time, and lazy tab computation for Historical Trend / Heatmap. The next target should be selected in the parent plan, not this daughter plan.