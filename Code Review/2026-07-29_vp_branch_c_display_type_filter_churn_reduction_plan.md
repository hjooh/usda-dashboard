# VP Branch C Display/Type/Filter Churn Reduction Plan

Date: 2026-07-29
Branch: main
Status: Closed. Branch C display-month and type-choice churn reductions are implemented and validated; parent closeout is complete.

## Purpose

The parent VP performance hotspot recovery plan and the closed Step 10 startup daughter plan selected Branch C as the next target: reduce remaining VP display/type/filter churn. This daughter plan owns the measured interaction-feel tranche that starts with VP display-month mapping churn, then considers type-choice generation only if fresh evidence still shows it as a top cost.

This is not a startup artifact-load fix. Branch D remains deferred because the contract-safe narrowed startup companion is complex, narrow in benefit, and not safe as a Provider v3 canonical-source replacement. Branch C should be judged as a repeated-use responsiveness improvement across source, hierarchy, commodity/type, country, metric, tab, and projection interactions.

## Scope

Included:
- Create this daughter source-of-truth ledger and keep it updated before every implementation tranche transition.
- Update the parent plan to delegate the Branch C implementation tranche here.
- Establish a fresh Branch C baseline before app-code edits.
- Use `VP Clone/System/Testing/vp_perf_probe_hierarchy_transition.R` as the primary interaction-churn gate.
- Use `VP Clone/System/Testing/vp_perf_probe_startup.R` only as a secondary startup/current-settlement regression guard unless a patch directly changes startup behavior.
- Start with VP display-month mapping churn in the owning server/helper path.
- Preserve Provider v3 behavior, direct-filter fallback, canonical-source checks, event-only runtime PERF defaults, existing purpose-specific counters, or explicit replacement counters.
- Consider type-choice generation only after display-month validation and only with explicit parity checks.
- Record timing, churn, provider mode, final selected path, fallback/null parity, bugs, blockers, failed attempts, and rejected approaches.

Excluded:
- Branch D artifact/currentity/loader rewrites.
- Replacing `rice_data_vp_trade_monthly` or changing Provider v3 canonical source identity.
- Loading polish, spinners, progress copy, or other latency masking.
- Broad non-VP tuning.
- Type-choice rewrites before the display-month tranche validates and fresh evidence warrants the risk.
- A paired results markdown file unless explicitly requested.

## Parent Plan Linkage

Parent plan: `VP Clone/Code Review/2026-07-29_vp_performance_hotspot_recovery_plan.md`.

This daughter plan owns detailed implementation notes for parent Step 11, "Reduce Branch C display/type/filter churn." The parent remains the broad performance recovery ledger. During this patch, the parent should contain only the delegation note, high-level status, and closeout summary; detailed technical decisions, failed attempts, validation commands, probe outputs, and runtime evidence belong here.

At closeout:
- Complete this daughter `## Summary` section in plain language.
- Update the parent Step Ledger with the Branch C outcome.
- Add parent tranche notes with output paths, validation markers, timing/churn/provider deltas, residual risks, blocker investigations, and the next recommended parent-plan target.
- Recenter future work on the parent plan.

## Source-Of-Truth Ledger Contract

- This file is the active source of truth for the Branch C display/type/filter churn patch.
- Update this file after every step or tranche before moving to the next tranche.
- Record files touched, commands/probes, benchmark labels, cache-state labels, runtime log paths, PERF summaries, churn deltas, timing deltas, provider summaries, bugs, blockers, failed attempts, rejected approaches, and decision gates.
- Keep parent-plan updates limited to delegation and closeout while this daughter plan is active.
- Preserve enough detail that a future coder can resume without replaying chat history.
- At completion, provide a short chat summary and complete the final `## Summary` section in this file.

## Baseline Evidence

Historical motivation from parent and Step 10 closeout:
- Step 9 Provider v3 confirmation probe: `VP Clone/Logs/vp_perf_probe_hierarchy_transition_step7_option3_row_index_fast_source_confirm_20260729T210115Z.csv`.
- Step 9 exact runtime summary outputs: `VP Clone/Logs/vp_perf_runtime_summary_step7_option3_row_index_fast_source_confirm_exact_20260729T210410Z_*.csv`.
- Step 9 remaining Current-vs-Average churn: `display_month_mapping` 24 calls, `type_choice_base_values` 15 VP calls plus one unknown/unknown row, `filtered_data` 9 calls, `mixed_volume_family_check` 7 calls, and `quantity_units_context` 7 calls.
- Step 10 startup baseline top churn: `filter_vp_rows_for_resolved_hierarchy_display_month_mapping` 9, `filter_vp_rows_for_resolved_hierarchy_filtered_data` 3, and `filter_vp_rows_for_resolved_hierarchy_type_choice_base_values` 2.
- Step 10 artifact/load evidence redirected away from Branch D app-code work for now.

Baseline caveat:
- Historical rows are target-selection evidence, not final before/after proof. This plan requires a fresh official Branch C baseline with a Branch C label before product-code edits.

Required official Branch C baseline:
- Primary probe: `VP Clone/System/Testing/vp_perf_probe_hierarchy_transition.R`.
- Preferred cache state for repeated-use interaction churn: `warm_session` when available and accurately labeled.
- Secondary guard: `VP Clone/System/Testing/vp_perf_probe_startup.R` under `warm_partition_disk` or the relevant startup label if a patch could affect startup/current settlement.
- Required summary: exact runtime JSONL paths with `VP Clone/System/Testing/vp_perf_summarize_runtime_logs.R --input=...` when requested runtime paths do not materialize.
- Required fields: elapsed interaction milliseconds, churn count deltas, purpose-specific calls/time, total `filter_vp_rows_for_resolved_hierarchy()` calls/time, Provider v3 disk/memory/direct-fallback summaries, source-mismatch/source-identity refusals if present, final source/trade-flow/hierarchy/commodity path, cache-state label, and PASS/FAIL status.

## Technical Read

Controlling display-month surfaces:
- `VP Clone/Programs/app_source/server/03_core_reactives_and_ui.R` owns `vp_display_month_mapping()`, `current_display_month_mapping()`, `current_display_month_axis_title()`, `is_calendar_year_display_context()`, and display-year helpers.
- `vp_display_month_mapping()` is a plain helper that reads Shiny inputs, calls `filter_vp_rows_for_resolved_hierarchy(..., vp_filter_purpose = "display_month_mapping")`, computes a dominant `calendar_signature`, and returns a 12-row mapping or `NULL`.
- `current_display_month_mapping()` calls `vp_display_month_mapping()` for VP and otherwise falls back to `month_mapping_for_year_type(current_display_year_type(...))`.
- `current_display_month_axis_title()` calls `current_display_month_mapping()` again, which can duplicate hierarchy filtering when mapping and axis title are both needed.
- Consumers include Current-vs-Average plots/tables, summary table behavior, Historical Trend, Heatmap, axis titles, and display-year labels.

Shared hierarchy/filter surface:
- `VP Clone/Programs/app_source/server/02_partner_and_notes.R` owns `filter_vp_rows_for_resolved_hierarchy()` and `resolve_vp_hierarchy_tokens()`.
- `filter_vp_rows_for_resolved_hierarchy()` records purpose-specific churn counters/key deltas, resolves hierarchy, tries Provider v3, falls back to direct filtering/stage A cache, filters commodity name/detail, and records timed events.
- Branch C must preserve Provider v3 row-index behavior, direct-filter fallback, and source-mismatch refusal behavior.

Type-choice surface:
- `VP Clone/Programs/app_source/server/01_state_and_custom_types.R` owns `build_commodity_choice_base_values()` and commodity/type choice update behavior.
- The type-choice path calls `filter_vp_rows_for_resolved_hierarchy(..., vp_filter_purpose = "type_choice_base_values")` and then derives `CommodityName` and detail choices.
- A prior in-memory type-choice branch failed because it did not preserve hierarchy resolution/final selected path. This surface is explicitly second, not first.

Local hypothesis for the first patch:
- Repeated display-month mapping work can be reduced by call-site de-duplication or narrowly keyed session/reactive reuse without changing selected tab/source/hierarchy behavior, display-month fallback behavior, or Provider v3 row-index semantics.

First cheap disconfirmation check:
- A fresh Branch C hierarchy-transition baseline and runtime summary must show display-month mapping as a meaningful count/time target. If display-month mapping is not a meaningful target, do not patch it; update this plan with the observed top Branch C target.

## Guardrails

Correctness guardrails:
- Preserve current user-visible VP behavior unless a deliberate measured behavior change is recorded here first.
- Preserve Provider v3 row-index behavior, direct-filter fallback, canonical-source checks, source-signature checks, row-order/source identity checks, and source-mismatch refusal.
- Preserve `current_display_month_mapping()` null/fallback semantics exactly.
- Preserve `month_mapping_for_year_type()` fallback behavior for non-VP and for VP cases where the VP mapping is invalid or unavailable.
- Preserve final selected hierarchy/type path.
- Keep MYCT evidence separate unless the changed helper directly affects MYCT behavior.

Measurement guardrails:
- Count-only improvements are insufficient. Accepted before/after evidence must include elapsed interaction timing and runtime summary counts/timings.
- Do not blend `cold_artifact`, `warm_partition_disk`, `warm_session`, and `unknown_cache_state` rows.
- Use exact fallback runtime log discovery and `--input=...` summarization when requested runtime paths do not materialize.
- If optimization skips the existing `display_month_mapping` filter call, add explicit replacement counters such as cache hit/miss/reuse/skip counters before claiming a measured win.

Display-month implementation guardrails:
- Prefer call-site de-duplication before adding cache abstractions.
- Prefer narrowly keyed session/reactive reuse before lookup fast paths.
- Use lookup fast paths only after a direct `calendar_signature` variance check proves the lookup is safe.
- Do not cache on raw transient inputs if settled/resolved hierarchy tokens or selected commodity path can change during the same reactive wave.
- Guard against stale input during startup, bookmarking, and input-settling cascades.

Type-choice guardrails:
- Touch type-choice generation only if display-month validation succeeds and fresh evidence still shows type-choice as a top target by count and timing.
- Preserve custom type builder behavior, fallback choice behavior, final selected `commodity_choice`, `CommodityName` fallback selection, `CommodityDetail`/`commodity` behavior, hierarchy resolution, and any `CUSTOM_BUILDER_CHOICE` row semantics.
- Do not repeat the rejected in-memory branch unless a parity check explicitly covers the previously failing final path.

## Measurement Model and Cache-State Labels

Use parent cache-state labels exactly:
- `cold_artifact`: fresh R session and no warmed partition cache for the target path.
- `warm_partition_disk`: partition files exist but session memory cache is empty.
- `warm_session`: same session and partition memory cache already hit.
- `unknown_cache_state`: only for legacy rows or documented uncertainty where evidence is not final proof.

Branch C primary evidence should be interaction-focused. The hierarchy-transition probe is the primary gate because Branch C is intended to improve repeated-use feel. Startup evidence is secondary unless a patch directly affects startup/current settlement.

## Step Ledger

| Step | Phase | Work | Status | Evidence / Files | Gate / Next Action |
|---|---|---|---|---|---|
| 1 | A | Create daughter source-of-truth plan | Complete | Added this file before Branch C app-code edits. | Update parent plan to delegate Branch C here. |
| 2 | A | Amend parent plan for Branch C delegation | Complete | Parent plan Step 11 delegates detailed Branch C work here. | Validate parent and daughter markdown. |
| 3 | A | Validate handoff markdown | Complete | `get_errors` reported no diagnostics for parent and daughter markdown. `git diff --check` passed. Direct trailing-whitespace marker: `TRAILING_WHITESPACE_OK_BRANCH_C_HANDOFF`. | Run fresh Branch C baseline before app-code edits. |
| 4 | B/C | Establish fresh Branch C baseline | Complete | Passing baseline label `step11_branch_c_display_mapping_baseline_retry`, cache state `warm_partition_disk`, PASS CSV, exact fallback runtime summary outputs, and failed first-attempt evidence recorded below. | Run display-month signature variance check before app-code edits. |
| 5 | B | Display-month signature variance check | Complete | Probe `vp_perf_probe_display_month_signature_variance.R` passed. Summary output shows signatures vary at trade/group/subgroup/market-segment/commodity-name levels but are single-signature at commodity detail. Lookup fast path is rejected for the first patch. | Implement call-site/helper de-duplication first. |
| 6 | D | Implement first display-month patch | Complete (iterated) | Initial call-site/helper de-duplication parsed but did not reduce target churn. Added narrowly keyed session reuse for `current_display_month_mapping()` with cache hit/miss counters. | Validate with the same hierarchy-transition probe and runtime summary. |
| 7 | D | Validate display-month patch | Complete | Post-cache probe passed. Display-month filter calls fell from 24 to 7 with 17 cache hits and 7 misses; total hierarchy-filter calls fell from 68 to 51 and total hierarchy-filter time fell from 4.4468s to 3.1304s. | Consider type-choice only if a safe narrow cache/parity gate is available. |
| 8 | E | Consider type-choice patch if warranted | Complete | Post-type-choice probe passed. Type-choice filter calls fell from 15 VP calls plus one unknown/unknown row to 7 VP calls plus one unknown/unknown row, with 8 VP cache hits and one additional unknown miss. | Run startup/current regression guard and final validation. |
| 9 | F | Close daughter and update parent | Complete | Startup/current regression guard passed, final validation markers recorded, Summary completed, and parent Step 11 closeout updated. | Recenter future work on the parent plan. |

## Phase Plan

Phase A: Handoff setup
- Create this daughter plan.
- Amend the parent plan to delegate Branch C here.
- Validate markdown handoff.

Phase B: Baseline and technical read
- Seed historical evidence from parent Step 10 closeout.
- Establish a fresh official Branch C baseline before app-code edits.
- Complete focused reads of display-month mapping, hierarchy filtering, and type-choice surfaces.
- Run or document a direct `calendar_signature` variance check before any lookup fast path.

Phase C: Measurement gate
- Use hierarchy-transition probe as the primary interaction gate.
- Extend harness only if it cannot expose elapsed interaction timing, display/type/filter counters, final selected path, provider modes, and fallback runtime logs.
- Update this plan with baseline evidence before app-code edits.

Phase D: First patch, display-month mapping churn
- Start with display-month mapping.
- Prefer implementation options in conservative order:
  - De-duplicate call sites that compute mapping and axis title/display-year context separately within the same render/helper path.
  - Use a narrowly keyed session/reactive cache in the owning server/helper scope if de-duplication is insufficient.
  - Add a purpose-specific lookup fast path only if `calendar_signature` variance proves the lookup is safe.
- Validate immediately after the first app-code edit.
- Do not start type-choice edits before display-month validation.

Phase E: Second patch, type-choice generation only if warranted
- Move to type-choice only if fresh post-display evidence still shows it as a top target by count and timing.
- Run parity checks before app-code edits.
- Preserve custom builder/fallback/final selected path behavior.

Phase F: Closeout
- Run final focused validations.
- Complete this plan's Summary.
- Update parent Step 11 and tranche notes.
- Recenter future work on the parent plan.

## Candidate Patches

Display-month option 1: call-site de-duplication.
- Compute mapping once in heavy render/helper paths that currently ask for mapping and axis-title/display-year context separately.
- Pass the mapping to local helpers or derive axis title from the already-computed mapping.
- This is the preferred first option because it has the smallest invalidation and stale-cache risk.

Display-month option 2: narrowly keyed session/reactive reuse.
- Use only if call-site de-duplication does not reduce the measured target enough.
- Required key dimensions unless proven irrelevant: source/source choice, VP trade flow, resolved group/subgroup/market segment, hierarchy resolution mode, sparse/strict rollup behavior, commodity name, commodity detail or selected `commodity_choice`, source/year-type fallback context used by `month_mapping_for_year_type()`, and any state that can change whether `current_display_month_mapping()` returns a VP 12-row mapping or the non-VP fallback.

Display-month option 3: lookup/table fast path.
- Use only if direct data evidence shows `calendar_signature` is globally constant or constant within a small explicit key.
- Must preserve fallback/null behavior and Provider v3 regression gates.

Type-choice option, only if warranted:
- Wrap choice-base values in a session/reactive cache keyed by settled hierarchy/trade-flow/source inputs, specialize choice-only generation using Provider v3 metadata only if parity proves exact, or reduce duplicate UI/reactive calls by sharing display/fallback/real choice values.

## Verification and Validation Targets

Markdown validation:
- `get_errors` for the parent and daughter markdown files.
- `git diff --check -- "VP Clone/Code Review/2026-07-29_vp_performance_hotspot_recovery_plan.md" "VP Clone/Code Review/2026-07-29_vp_branch_c_display_type_filter_churn_reduction_plan.md"`.
- Direct trailing-whitespace scan for the new daughter file while untracked.

Pre-edit baseline:
- Run a fresh Branch C hierarchy-transition baseline with explicit cache state and label.
- Summarize exact runtime logs using `VP Clone/System/Testing/vp_perf_summarize_runtime_logs.R --input=...`.
- Record elapsed timing, display/type/filter churn, provider modes, final path, and PASS/FAIL status in this plan.

Parse validation:
- Use `C:\Program Files\R\R-4.5.1\bin\Rscript.exe`.
- Wrap `parse(file=...)` in `invisible(...)`.
- Emit grepable markers for every touched R file.

Display-month parity:
- Representative contexts must produce the same 12-row mapping, same `NULL` vs fallback behavior, and same axis-title/display-year implications as the current implementation.
- Required matrix: export and import; all/all/all; group; subgroup; market segment; commodity name; commodity detail; sparse/strict rollup contexts; Current-vs-Average; Historical Trend; Heatmap; invalid/intermediate input states where fallback/null behavior matters.

Provider regression gate:
- Provider disk reads, direct-filter fallback, source-mismatch refusals, and source-identity failures must not increase unexpectedly.
- Any increase requires a documented cause and acceptance decision.

Runtime comparison:
- Compare elapsed interaction timing, `display_month_mapping`, `type_choice_base_values`, `filtered_data`, total `filter_vp_rows_for_resolved_hierarchy()` calls/time, provider partition modes, key deltas, and replacement mapping counters if added.

Manual sanity:
- If UI choice or display-month behavior changes, check VP source defaults, trade-flow switch, hierarchy dropdowns, commodity/type choices, Current vs. Average, Historical Trend, Heatmap, axis labels, and display-year labels.

## Bugs, Blockers, Failed Attempts, Rejected Approaches

Known blockers and risk controls:
- Timing evidence blocker: if probes cannot isolate elapsed interaction time and display/type/filter counters, extend the harness before product-code edits.
- Cache-key blocker: if the display-month mapping key cannot be explicit and stable across startup/bookmark/input-settling cascades, do not add a cache; use local call-site de-duplication instead.
- Signature-variance blocker: if `calendar_signature` varies in ways not captured by the selected context, do not use a lookup fast path.
- Instrumentation blocker: if optimization hides work by skipping the current filter call, add replacement hit/miss/reuse/skip counters before claiming a measured win.
- Provider blocker: any unexplained increase in provider disk reads, direct-filter fallback, source mismatches, or identity refusals blocks acceptance until explained.
- Type-choice blocker: if parity cannot preserve custom builder/fallback/final selected path behavior, defer type-choice work and close only the display-month tranche.
- Harness blocker: requested runtime logs may not materialize; rely on deterministic fallback discovery and exact `--input=...` summarization as in Step 10.

Rejected as first response:
- Branch D startup artifact/load narrowing.
- General `current_display_month_mapping()` cache before key/signature behavior is proven.
- Type-choice generation rewrite before display-month evidence and validation.
- Lookup fast path without direct `calendar_signature` variance proof.
- Loading polish or cosmetic wait states.

## Tranche Execution Notes

- 2026-07-29 Tranche A (Branch C daughter handoff):
  - Created this Branch C daughter source-of-truth plan before Branch C app-code edits.
  - Updated the parent plan to delegate Step 11 here.
  - Handoff validation passed:
    - `get_errors` reported no diagnostics for the parent and daughter markdown files.
    - `git diff --check` passed for the parent and daughter markdown files.
    - Direct trailing-whitespace marker: `TRAILING_WHITESPACE_OK_BRANCH_C_HANDOFF`.
  - Incorporated the accepted audit recommendations:
    - Branch C is an interaction responsiveness tranche, not a startup fix.
    - Primary success gate is the hierarchy-transition probe with timing plus churn evidence.
    - Startup probe is a secondary regression guard.
    - Display-month mapping starts with call-site de-duplication before cache abstractions.
    - Cache key, null/fallback behavior, signature variance, instrumentation, provider regression, and type-choice parity requirements are explicit.
  - No Branch C app-code edits have been made yet.

- 2026-07-29 Tranche B (fresh Branch C baseline):
  - First Branch C baseline attempt:
    - Probe label: `step11_branch_c_display_mapping_baseline`.
    - Cache-state label: `warm_session`.
    - Probe CSV: `VP Clone/Logs/vp_perf_probe_hierarchy_transition_step11_branch_c_display_mapping_baseline_20260729T220617Z.csv`.
    - Result: `FAIL`, but with useful runtime evidence.
    - Failure reason: the final path did not resolve to the intended market segment; final `vp_market_segment_choice` remained `__all__` after stage waits failed.
    - Requested runtime log path did not materialize.
    - Exact fallback logs summarized:
      - `VP Clone/Logs/vp_runtime_perf_proc_20260729T220632Z_39076.jsonl`.
      - `VP Clone/Logs/vp_runtime_perf_d4d078adb2653275cad0978ca8030796.jsonl`.
    - Runtime summary outputs: `VP Clone/Logs/vp_perf_runtime_summary_step11_branch_c_display_mapping_baseline_fallback_20260729T221027Z_*.csv`.
    - Top churn confirmed Branch C shape despite probe failure: `display_month_mapping` 27, `type_choice_base_values` 17, `filtered_data` 10.
  - Passing Branch C baseline retry:
    - Probe label: `step11_branch_c_display_mapping_baseline_retry`.
    - Cache-state label: `warm_partition_disk`.
    - Probe CSV: `VP Clone/Logs/vp_perf_probe_hierarchy_transition_step11_branch_c_display_mapping_baseline_retry_20260729T221038Z.csv`.
    - Result: `PASS`.
    - Probe timings: startup ready 93,497ms, source switch 539ms, trade flow 14,410ms, hierarchy change 79,256ms, total probe 187,809ms.
    - Final path resolved to VP trade / Dry pulses / Dried beans / Dried, with selected target choices matching final controls.
    - Requested runtime log path did not materialize.
    - Exact fallback logs summarized:
      - `VP Clone/Logs/vp_runtime_perf_proc_20260729T221041Z_27516.jsonl`.
      - `VP Clone/Logs/vp_runtime_perf_ed94a5116c81ae0e6d12d5948c5ad733.jsonl`.
    - Runtime summary outputs: `VP Clone/Logs/vp_perf_runtime_summary_step11_branch_c_display_mapping_baseline_retry_fallback_20260729T221357Z_*.csv`.
    - Runtime summary read 2 files / 450 records.
    - Top timed buckets included startup/client buckets plus `filter_vp_rows_for_resolved_hierarchy()` at 68 calls / 4.4468s and `summary_table` at 8 calls / 1.7665s.
    - Provider modes: 63 memory-cache calls / 0.3286s and 5 disk-cache calls / 0.6726s; no direct fallback row appeared in the partition summary.
    - Top churn: `display_month_mapping` 24, `type_choice_base_values` 15, `summary_table_executed` 11, `map_bottom_panel_ui_gated_skip` 10, `filtered_data` 9, `mixed_volume_family_check` 7, and `quantity_units_context` 7.
  - Interpretation:
    - The official before row confirms display-month mapping remains the top Branch C helper churn target.
    - The first app-code patch should stay focused on display-month mapping, preferably local call-site de-duplication before any cache abstraction.
    - Type-choice generation remains second because it is still high churn, but it is riskier and must wait for display-month validation.

- 2026-07-29 Tranche C (display-month signature variance check):
  - Added direct non-Shiny probe `VP Clone/System/Testing/vp_perf_probe_display_month_signature_variance.R` after an inline PowerShell/R command failed from quoting fragility.
  - First probe execution failed with a harness bug while combining grouping levels with different columns: `numbers of columns of arguments do not match`.
  - Fixed the probe detail output to normalize grouped levels to a common column set.
  - Validation passed:
    - `get_errors` reported no diagnostics for the new probe.
    - Parse marker after initial creation: `PARSE_OK_VP_DISPLAY_MONTH_SIGNATURE_VARIANCE_PROBE`.
    - Parse marker after detail fix: `PARSE_OK_VP_DISPLAY_MONTH_SIGNATURE_VARIANCE_PROBE_DETAIL_FIX`.
  - Passing probe label: `step11_branch_c_display_mapping_signature_variance`.
  - Summary output: `VP Clone/Logs/vp_display_month_signature_variance_step11_branch_c_display_mapping_signature_variance_20260729T221548Z_summary.csv`.
  - Detail output: `VP Clone/Logs/vp_display_month_signature_variance_step11_branch_c_display_mapping_signature_variance_20260729T221548Z_detail.csv`.
  - Result:
    - Trade: 2 contexts, 2 with multiple signatures, max 7 signatures.
    - Group: 6 contexts, 6 with multiple signatures, max 6 signatures.
    - Subgroup: 16 contexts, 10 with multiple signatures, max 6 signatures.
    - Market segment: 36 contexts, 20 with multiple signatures, max 6 signatures.
    - Commodity name: 496 contexts, 19 with multiple signatures, max 5 signatures.
    - Commodity detail: 1,624 contexts, 0 with multiple signatures, max 1 signature.
  - Interpretation:
    - A broad lookup fast path is not safe as the first patch because `calendar_signature` varies across common hierarchy contexts until commodity detail.
    - A commodity-detail-keyed lookup might be possible later, but it would still need explicit fallback/null parity and input-settling guards.
    - The first app-code patch should use helper/call-site de-duplication rather than lookup fast path or general cache.

- 2026-07-29 Tranche D (first display-month de-duplication patch):
  - Edited `VP Clone/Programs/app_source/server/03_core_reactives_and_ui.R`:
    - Added optional `display_month_mapping` arguments to `current_display_month_axis_title()`, `is_calendar_year_display_context()`, `build_display_year_short_prefix()`, `build_display_year_label()`, `build_single_reference_year_label()`, `build_current_year_trace_label()`, `build_historical_window_note_text()`, and `build_projection_basis_context()`.
    - Existing callers remain compatible because the new argument defaults to `NULL` and falls back to the existing `current_display_month_mapping()` behavior.
  - Edited `VP Clone/Programs/app_source/server/04_comparison_plots.R`:
    - Reused already-computed display-month mapping for axis title and current/reference year labels in hot comparison plot paths.
  - Edited `VP Clone/Programs/app_source/server/05_trend_and_heatmap.R`:
    - Reused already-computed display-month mapping for Historical Trend axis title and Heatmap axis/year context.
  - Local intent:
    - Reduce duplicate `current_display_month_mapping()` calls where mapping and axis/year labels are computed in the same render/helper path.
    - Avoid general caching and lookup fast paths for this initial patch.
  - Immediate validation passed:
    - `get_errors` reported no diagnostics for the three touched R files.
    - Parse marker: `PARSE_OK_BRANCH_C_DISPLAY_MONTH_DEDUP`.
  - Post-patch validation run:
    - Probe label: `step11_branch_c_display_mapping_dedup_post`.
    - Cache-state label: `warm_partition_disk`.
    - Probe CSV: `VP Clone/Logs/vp_perf_probe_hierarchy_transition_step11_branch_c_display_mapping_dedup_post_20260729T221941Z.csv`.
    - Result: `PASS`.
    - Requested runtime log path did not materialize.
    - Exact fallback logs summarized:
      - `VP Clone/Logs/vp_runtime_perf_proc_20260729T221944Z_26840.jsonl`.
      - `VP Clone/Logs/vp_runtime_perf_9f21ddbbd4f66b6f9399588b4aefc51a.jsonl`.
    - Runtime summary outputs: `VP Clone/Logs/vp_perf_runtime_summary_step11_branch_c_display_mapping_dedup_post_fallback_20260729T222311Z_*.csv`.
    - Result did not validate the first patch: display-month mapping churn increased from 24 to 32 and total hierarchy-filter calls increased from 68 to 76, while provider disk-cache remained healthy at 5 calls / 0.5819s.
  - Interpretation:
    - The helper/call-site de-duplication was safe syntactically but insufficient as a performance patch.
    - Continue within the same display-month slice with the planned narrowly keyed session reuse and explicit hit/miss instrumentation.

- 2026-07-29 Tranche E (narrow display-month session reuse):
  - Edited `VP Clone/Programs/app_source/server/03_core_reactives_and_ui.R`:
    - Added a session-local `display_month_mapping_cache` environment.
    - Added a cache key based on source/source choice, VP trade flow, resolved group/subgroup/market segment, resolution mode, path name, sparse/strict flags, commodity name, commodity detail, and fallback year type.
    - Added `display_month_mapping_cache_hit` and `display_month_mapping_cache_miss` counters via `record_cache_body_execution()`.
    - Cached the final mapping returned by `current_display_month_mapping()` for VP, including valid 12-row VP mappings and fallback mappings when VP mapping is invalid or unavailable.
    - Non-VP behavior remains uncached and unchanged.
  - Immediate validation passed:
    - `get_errors` reported no diagnostics for `03_core_reactives_and_ui.R`.
    - Parse marker: `PARSE_OK_BRANCH_C_DISPLAY_MONTH_CACHE`.
  - Post-cache validation run:
    - Probe label: `step11_branch_c_display_mapping_cache_post`.
    - Cache-state label: `warm_partition_disk`.
    - Probe CSV: `VP Clone/Logs/vp_perf_probe_hierarchy_transition_step11_branch_c_display_mapping_cache_post_20260729T222629Z.csv`.
    - Result: `PASS`.
    - Probe timings: startup ready 80,690ms, source switch 541ms, trade flow 12,563ms, hierarchy change 81,204ms, total probe 175,096ms.
    - Requested runtime log path did not materialize.
    - Exact fallback logs summarized:
      - `VP Clone/Logs/vp_runtime_perf_proc_20260729T222631Z_21380.jsonl`.
      - `VP Clone/Logs/vp_runtime_perf_012e066ae30dab7aec01953d60ec86b0.jsonl`.
    - Runtime summary outputs: `VP Clone/Logs/vp_perf_runtime_summary_step11_branch_c_display_mapping_cache_post_fallback_20260729T223002Z_*.csv`.
    - Runtime summary read 2 files / 423 records.
    - Main deltas vs official baseline:
      - Total probe time: 187,809ms -> 175,096ms.
      - Trade-flow stage: 14,410ms -> 12,563ms.
      - Hierarchy stage: 79,256ms -> 81,204ms.
      - `filter_vp_rows_for_resolved_hierarchy()` total calls/time: 68 / 4.4468s -> 51 / 3.1304s.
      - `display_month_mapping` filter calls: 24 -> 7.
      - Replacement instrumentation: `display_month_mapping_cache_hit` 17 and `display_month_mapping_cache_miss` 7.
      - Type-choice filter calls remained 15 VP calls plus one unknown/unknown row.
      - Provider modes remained healthy: memory-cache 46 calls / 0.2434s and disk-cache 5 calls / 0.5849s; no direct fallback row appeared in the partition summary.
  - Interpretation:
    - The display-month cache patch validates as the first Branch C win.
    - It reduced the target display-month filter churn while preserving explicit hit/miss evidence.
    - Remaining type-choice churn is now the largest uncached Branch C filter target, but it is riskier and requires a local parity gate before any edit.

- 2026-07-29 Tranche F (native VP type-choice base reuse):
  - Edited `VP Clone/Programs/app_source/server/01_state_and_custom_types.R`:
    - Added a session-local `vp_type_choice_base_cache` environment.
    - Added a type-choice base cache key based on active source, data source, VP trade flow, resolved group/subgroup/market segment, resolution mode, path name, sparse/strict flags, selected VP commodity name, and MYCT type-mode state.
    - Added `type_choice_base_values_cache_hit` and `type_choice_base_values_cache_miss` counters via `record_cache_body_execution()`.
    - Cached only the native VP detail choices after the existing hierarchy-filter and commodity-name fallback logic.
    - Left custom type enrichment and `include_builder` handling outside the cache so custom builder behavior remains evaluated at return time.
  - Immediate validation passed:
    - `get_errors` reported no diagnostics for `01_state_and_custom_types.R`.
    - Parse marker: `PARSE_OK_BRANCH_C_TYPE_CHOICE_CACHE`.
  - Acceptance is still pending the same hierarchy-transition probe and runtime summary.
  - Post-type-choice validation run:
    - Probe label: `step11_branch_c_type_choice_cache_post`.
    - Cache-state label: `warm_partition_disk`.
    - Probe CSV: `VP Clone/Logs/vp_perf_probe_hierarchy_transition_step11_branch_c_type_choice_cache_post_20260729T223458Z.csv`.
    - Result: `PASS`.
    - Probe timings: startup ready 90,330ms, source switch 545ms, trade flow 12,225ms, hierarchy change 77,939ms, total probe 181,157ms.
    - Requested runtime log path did not materialize.
    - Exact fallback logs summarized:
      - `VP Clone/Logs/vp_runtime_perf_proc_20260729T223501Z_32928.jsonl`.
      - `VP Clone/Logs/vp_runtime_perf_f9e1641c0eeccaf3c16956670b77eb96.jsonl`.
    - Runtime summary outputs: `VP Clone/Logs/vp_perf_runtime_summary_step11_branch_c_type_choice_cache_post_fallback_20260729T223817Z_*.csv`.
    - Runtime summary read 2 files / 415 records.
    - Main deltas vs official baseline:
      - Total probe time: 187,809ms -> 181,157ms.
      - Trade-flow stage: 14,410ms -> 12,225ms.
      - Hierarchy stage: 79,256ms -> 77,939ms.
      - `filter_vp_rows_for_resolved_hierarchy()` total calls/time: 68 / 4.4468s -> 43 / 2.8760s.
      - `display_month_mapping` filter calls: 24 -> 7, with 17 display-month cache hits and 7 misses.
      - `type_choice_base_values` filter calls: 15 VP calls plus one unknown/unknown row -> 7 VP calls plus one unknown/unknown row, with 8 VP cache hits and one additional unknown miss.
      - `filtered_data` calls stayed at 9.
      - Provider modes remained healthy: memory-cache 38 calls / 0.2042s and disk-cache 5 calls / 0.5718s; no direct fallback row appeared in the partition summary.
      - Final path remained VP trade / Dry pulses / Dried beans / Dried.
  - Interpretation:
    - The type-choice cache validates in the hierarchy-transition probe and preserves the final selected path in the measured scenario.
    - This completes the Branch C display/type/filter churn target for the current tranche unless startup/current regression guard fails.

- 2026-07-29 Tranche G (startup regression guard and closeout):
  - Final touched-R validation passed:
    - `get_errors` reported no diagnostics for `01_state_and_custom_types.R`, `03_core_reactives_and_ui.R`, `04_comparison_plots.R`, `05_trend_and_heatmap.R`, and `vp_perf_probe_display_month_signature_variance.R`.
    - Parse marker: `PARSE_OK_BRANCH_C_FINAL_TOUCHED_R`.
    - `git diff --check` passed for touched R files and plan files.
  - Startup/current regression guard passed:
    - Probe label: `step11_branch_c_startup_regression_guard`.
    - Cache-state label: `warm_partition_disk`.
    - Probe CSV: `VP Clone/Logs/vp_perf_probe_startup_step11_branch_c_startup_regression_guard_20260729T223845Z.csv`.
    - Result: `PASS`.
    - Startup ready: 80,558ms.
    - Initial and final tab: `Current vs. Average`; tab switch time 0ms.
    - Comparison plot visible wait: 22ms.
    - Total probe: 81,178ms.
    - Client PERF: `main_tabs_mount` 19,159ms and `tab_after_paint` 19,179ms, both on `Current vs. Average`.
    - Requested runtime log path did not materialize.
    - Exact fallback logs summarized:
      - `VP Clone/Logs/vp_runtime_perf_7034b13360b244e0536a95589b36b618.jsonl`.
      - `VP Clone/Logs/vp_runtime_perf_proc_20260729T223848Z_26368.jsonl`.
    - Runtime summary outputs: `VP Clone/Logs/vp_perf_runtime_summary_step11_branch_c_startup_regression_guard_fallback_20260729T224012Z_*.csv`.
    - Startup churn evidence: `display_month_mapping_cache_hit` 8, `display_month_mapping_cache_miss` 1, `type_choice_base_values_cache_hit` 1, `type_choice_base_values_cache_miss` 1, `display_month_mapping` filter call 1, `type_choice_base_values` filter call 1, and `filtered_data` 3.
    - Startup provider modes remained healthy: memory-cache 8 calls / 0.0690s and disk-cache 1 call / 0.2177s; no direct fallback row appeared in the partition summary.
  - Closeout decision:
    - Branch C daughter work is complete for this tranche.
    - Display-month and type-choice churn are both reduced with explicit replacement hit/miss instrumentation.
    - Startup/current regression guard passed.
    - Remaining repeated filter churn is led by `filtered_data`, mixed/quantity helper residuals, and comparison commodity choices, but those are smaller and should be selected from the parent plan with fresh evidence.

## Summary

This Branch C daughter plan reduced repeated VP display/type/filter work in the app's interaction path. The first target was display-month mapping, which had been repeatedly filtering the VP hierarchy data whenever plots, tables, axis titles, and year labels asked for month context. A direct signature-variance probe showed that broad lookup shortcuts were not safe because `calendar_signature` varies across trade, group, subgroup, market segment, and some commodity-name contexts. The implemented fix therefore used a narrowly keyed session cache with explicit hit/miss counters instead of a lookup fast path.

The second target was type-choice generation. After the display-month cache validated, type-choice remained the largest uncached Branch C filter counter. The implemented type-choice cache stores only the native VP detail choices after the existing hierarchy-filter and commodity-name fallback logic; custom type enrichment and builder-row handling still run at return time so custom behavior is preserved.

The main interaction probe improved the targeted counters. Compared with the official Branch C baseline, total `filter_vp_rows_for_resolved_hierarchy()` work fell from 68 calls / 4.4468s to 43 calls / 2.8760s. Display-month filter calls fell from 24 to 7, with 17 display-month cache hits. Type-choice filter calls fell from 15 VP calls plus one unknown/unknown row to 7 VP calls plus one unknown/unknown row, with 8 VP cache hits. Provider behavior stayed healthy: the final interaction run showed 38 memory-cache calls / 0.2042s and 5 disk-cache calls / 0.5718s, with no direct fallback row.

Validation passed for the touched R files, the hierarchy-transition integration probe, the runtime summarizer comparisons, and the startup/current regression guard. Requested runtime log paths still often did not materialize, but every validation used exact fallback process/session logs. Branch C does not remove the initial artifact-load pause; it improves repeated interaction responsiveness by avoiding redundant hierarchy filtering.