# VP Branch F Hierarchy Sidebar Reactive Cascade Reduction Plan

Date: 2026-07-30
Branch: main
Status: Complete. Branch F accepted a measured hierarchy/sidebar render-stabilization branch and closed with parent closeout pending final validation.

## Purpose

The closed Branch E interaction responsiveness tranche improved repeated hierarchy/filter timing, but the remaining hierarchy/filter stage is still too slow for ordinary use. Branch E reduced the canonical Branch E hierarchy/filter stage from 90,517 ms to 75,484 ms, while tab hops after filter settlement stayed sub-second and Provider v3 stayed healthy.

This Branch F daughter plan owns the next measured tranche: hierarchy/sidebar reactive cascade reduction. The central hypothesis is that the remaining delay is not explained by one R-side timed helper alone. Named R-side runtime buckets explain only a small fraction of the 75,484 ms stage, so this tranche must first split the hierarchy stage into smaller measured windows and attribute both server-side reactive/sidebar churn and client/DOM/UI churn before selecting product-code edits.

This is not a startup artifact-load tranche. Slow startup/initialization remains deferred by product decision unless the user explicitly reprioritizes startup or fresh repeated-use evidence proves artifact/currentity/signature work blocks ordinary hierarchy/sidebar interaction.

## Scope

Included:
- Create this daughter source-of-truth ledger before Branch F product-code edits.
- Update the parent performance plan so Branch E remains closed and Branch F is delegated here as the next active measured tranche.
- Record pre-implementation dirty-worktree/generated-artifact state before plan and product-code edits.
- Seed Branch F baseline framing from closed Branch E evidence.
- Extend or fork the Branch E tab/filter probe into a Branch F hierarchy/sidebar cascade probe that splits the combined hierarchy stage.
- Attribute hierarchy/sidebar delay across server-side runtime churn, key deltas, provider modes, output readiness, and client/DOM/UI timing where available.
- Select the first product-code branch only after split-stage and runtime/client evidence identifies a defensible target.
- Preserve Provider v3 behavior, direct-filter fallback, canonical-source checks, event-only runtime PERF defaults, final selected path, Map readiness, and MYCT legal state behavior.
- Record timing, churn, key-delta, provider mode, client/UI evidence, final selected path, data-equivalence checks, Map/MYCT sanity or isolation, bugs, blockers, failed attempts, rejected approaches, and decision gates.

Excluded:
- Startup artifact/load rewrites, Branch D companion artifacts, broad format conversion, or lazy full-artifact loading unless explicitly reprioritized.
- Build-time aggregation tuning unless fresh runtime evidence proves build/rebuild work is blocking ordinary repeated-use hierarchy/sidebar interaction.
- Loading polish, spinners, progress copy, cosmetic waiting states, or other latency masking.
- Broad non-VP tuning.
- MYCT optimization as a primary target; MYCT remains a separate evidence surface unless touched shared helpers require targeted sanity.
- Reintroducing Branch E's rejected broad derived-reactive `bindCache()` wrappers without a materially different design and fresh evidence.
- A paired results markdown file unless explicitly requested.

## Parent Plan Linkage

Parent plan: `VP Clone/Code Review/2026-07-29_vp_performance_hotspot_recovery_plan.md`.

This daughter plan owns detailed implementation notes for Branch F, "hierarchy/sidebar reactive cascade reduction." The parent remains the broad performance recovery ledger. During this tranche, the parent should contain only the delegation note, high-level status, and closeout summary; detailed technical decisions, failed attempts, validation commands, probe outputs, and runtime evidence belong here.

Parent ledger amendment requirement:
- Keep Step 12 Branch E marked complete.
- Add or shift the next active parent step to delegate Branch F hierarchy/sidebar reactive cascade reduction here.
- Shift deferred build-time aggregation, artifact/data-format, and final validation rows down as needed.
- Record that startup slowness is still accepted for this tranche and artifact/load work remains explicitly deferred.

At closeout:
- Complete this daughter `## Summary` section in plain language.
- Update the parent Step Ledger with the Branch F outcome.
- Add parent tranche notes with output paths, validation markers, timing/churn/provider/client deltas, cache/reuse counters, residual risks, blocker investigations, and the next recommended parent-plan target.
- Recenter future work on the parent plan.

## Source-Of-Truth Ledger Contract

- This file is the active source of truth for the Branch F hierarchy/sidebar cascade tranche.
- Update this file after every step or tranche before moving to the next tranche.
- Record files touched, commands/probes, benchmark labels, cache-state labels, runtime log paths, PERF summaries, churn deltas, timing deltas, key-delta/client evidence, provider summaries, branch decisions, data-equivalence checks, Map/MYCT sanity evidence, bugs, blockers, failed attempts, rejected approaches, and decision gates.
- Keep parent-plan updates limited to delegation and closeout while this daughter plan is active.
- Preserve enough detail that a future coder can resume without replaying chat history.
- At completion, provide a short chat summary and complete the final `## Summary` section in this file.

## Baseline Evidence

Closed Branch E daughter plan:
- `VP Clone/Code Review/2026-07-30_vp_branch_e_interaction_filtering_tab_switch_responsiveness_plan.md`.

Official Branch E baseline:
- Probe: `VP Clone/System/Testing/vp_perf_probe_tab_switch_filtering.R`.
- Probe label: `step12_branch_e_tab_filter_baseline`.
- Cache state: `warm_partition_disk`.
- Probe CSV: `VP Clone/Logs/vp_perf_probe_tab_switch_filtering_step12_branch_e_tab_filter_baseline_20260730T134112Z.csv`.
- Probe status: PASS.
- Runtime timed CSV: `VP Clone/Logs/vp_perf_runtime_summary_runtime_logs_20260730T134459Z_timed.csv`.
- Runtime churn CSV: `VP Clone/Logs/vp_perf_runtime_summary_runtime_logs_20260730T134459Z_churn.csv`.
- Runtime partition CSV: `VP Clone/Logs/vp_perf_runtime_summary_runtime_logs_20260730T134459Z_partition.csv`.
- Runtime key-delta CSV: `VP Clone/Logs/vp_perf_runtime_summary_runtime_logs_20260730T134459Z_key_delta.csv`.
- Baseline timings: startup-ready 70,681 ms; source switch 11,815 ms; trade-flow switch 15,990 ms; combined hierarchy change 90,517 ms; tab Current after source 81 ms; Current after filter 47 ms; Historical Trend 66 ms; Heatmap 72 ms; Map 71 ms; return Current 93 ms; total probe 217,289 ms.
- Baseline interpretation: tab switching itself was not the first bottleneck; hierarchy/filter changes and repeated shared/sidebar derived work were the first target.

Accepted Branch E post-change evidence:
- Probe label: `step12_branch_e_commodity_base_reuse_post`.
- Cache state: `warm_partition_disk`.
- Probe CSV: `VP Clone/Logs/vp_perf_probe_tab_switch_filtering_step12_branch_e_commodity_base_reuse_post_20260730T135412Z.csv`.
- Probe status: PASS.
- Requested runtime log path did not materialize; exact fallback JSONLs summarized: `VP Clone/Logs/vp_runtime_perf_82bdb269975c7febde0a35f44e71e6ea.jsonl` and `VP Clone/Logs/vp_runtime_perf_proc_20260730T135416Z_35788.jsonl`.
- Runtime timed CSV: `VP Clone/Logs/vp_perf_runtime_summary_runtime_logs_20260730T135744Z_timed.csv`.
- Runtime churn CSV: `VP Clone/Logs/vp_perf_runtime_summary_runtime_logs_20260730T135744Z_churn.csv`.
- Runtime partition CSV: `VP Clone/Logs/vp_perf_runtime_summary_runtime_logs_20260730T135744Z_partition.csv`.
- Runtime key-delta CSV: `VP Clone/Logs/vp_perf_runtime_summary_runtime_logs_20260730T135744Z_key_delta.csv`.
- Timing result versus official Branch E baseline: combined hierarchy-change stage improved from 90,517 ms to 75,484 ms, about 16.6% faster; total probe improved from 217,289 ms to 201,650 ms, about 7.2% faster.
- Tab stages remained passing and sub-second after filter settlement: Historical Trend 58 ms, Heatmap 98 ms, Map 97 ms, return Current 127 ms.
- Provider summary stayed healthy: memory-cache 39 calls / 0.2326s, disk-cache 5 calls / 0.6399s, and no direct-filter summary row.
- Remaining timed buckets: `filter_vp_rows_for_resolved_hierarchy()` 43 calls / 3.0616s; `summary_table` 8 calls / 1.5181s; `projection_data()` 8 calls / 1.0509s; `output$commodity_choice_ui` 8 calls / 0.5540s.
- Remaining churn/key surfaces: `summary_table_executed`, `filter_vp_rows_for_resolved_hierarchy_filtered_data`, display-month mapping, mixed-volume family check, quantity-units context, type-choice base values, and map runtime source cache key deltas.

Branch F interpretation:
- The remaining 75,484 ms hierarchy/filter stage is much larger than the named R-side timed buckets.
- Branch F must not treat `filter_vp_rows_for_resolved_hierarchy()` total time alone as the bottleneck.
- The first Branch F task is measurement refinement: split hierarchy mutations and add enough runtime/client evidence to explain the stage before choosing a product-code target.

Pre-Branch-F worktree snapshot, 2026-07-30:
- `git status --short` before creating this plan showed generated/untracked cache and processed-data artifacts only: 22 untracked files under `VP Clone/System/Cache/` and untracked `VP Clone/System/Processed Data/`.
- No intended Branch F source files existed before this plan.
- Branch F probes are expected to create more runtime logs, cache files, and generated artifacts. Those output paths must be recorded as evidence and kept separate from intended source/plan changes.

## Technical Read

Server-side hierarchy/sidebar surfaces:
- `VP Clone/Programs/app_source/server/02_partner_and_notes.R` owns `resolve_vp_hierarchy_tokens()`, `vp_resolve_hierarchy_choice_state()`, `vp_filter_rows_for_hierarchy_choices()`, `filter_vp_rows_for_resolved_hierarchy()`, `current_main_tab_safe()`, `output$data_frequency_ui`, `vp_hierarchy_last_changed`, hierarchy observers, Map shared data, and custom comparison/MYCT-adjacent state.
- `output$data_frequency_ui` reads `map_surface_refresh_nonce()`, rebuilds hierarchy choice state, constructs VP hierarchy dropdown choices, and is configured with `suspendWhenHidden = FALSE`.
- `output$data_frequency_ui` is a candidate cascade surface, but not yet proven as the cause. Branch F must require render-generation/runtime/client evidence before selecting a UI stabilization branch.

Sidebar choice surfaces:
- `VP Clone/Programs/app_source/server/01_state_and_custom_types.R` owns `build_commodity_choice_base_values()`, `commodity_choice_native_base_values()`, `commodity_choice_real_values()`, `commodity_choice_fallback_values()`, `output$commodity_choice_ui`, type-choice base cache helpers, `vp_type_empty_choice_transition()`, and MYCT type-mode dependency.
- Branch E accepted `commodity_choice_native_base_values()` reuse. Branch F should not undo that change.
- Any change around commodity/type choice transitions must preserve `vp_type_empty_choice_transition()` and legal custom-builder/type fallback states.

Shared data/output consumers:
- `VP Clone/Programs/app_source/server/03_core_reactives_and_ui.R` owns `filtered_data_stable_cache_key()`, `filtered_data()`, `historical_avg()`, `current_year_data()`, `projection_data()`, and `comparison_hist_note`.
- `VP Clone/Programs/app_source/server/04_comparison_plots.R` owns `output$summary_table`, `comparison_plot`, and Current-vs-Average active-tab gating.
- `VP Clone/Programs/app_source/server/05_trend_and_heatmap.R` owns Historical Trend, Heatmap, Map outputs, tab gates, and map readiness surfaces.

Client-side surfaces:
- `VP Clone/Programs/app_source/ui.R` contains existing client performance events, MutationObserver blocks, and a change listener covering `vp_group_choice`, `vp_subgroup_choice`, and `vp_market_segment_choice`.
- JS/input throttling or debounce must remain a last resort, selected only if these events are proven to duplicate or prolong the measured hierarchy window.

Local hypothesis for the first Branch F product-code branch:
- The remaining delay is more likely a reactive/input-update cascade than one slow provider/helper.
- A first code branch should target the exact blocking substage discovered by the split Branch F probe.

First cheap disconfirmation check:
- A fresh Branch F split-stage probe must show whether reset, group, subgroup, segment, sidebar render, output readiness, or client/DOM mounting dominates the hierarchy window.
- If one timed helper dominates, select a helper-specific branch instead of a cascade branch.
- If client/DOM mounting dominates, select UI render stabilization or client-side investigation before server-side reuse.
- If attribution remains ambiguous, close the first tranche as probe hardening or measurement-only rather than editing product code speculatively.

## Guardrails

Probe and evidence guardrails:
- Prefer a narrowly named Branch F probe sibling such as `VP Clone/System/Testing/vp_perf_probe_hierarchy_sidebar_cascade.R` if that keeps the closed Branch E probe stable.
- If editing `VP Clone/System/Testing/vp_perf_probe_tab_switch_filtering.R`, preserve existing Branch E fields and labels for comparability.
- Reuse established VP probe conventions: `NOT_CRAN`, explicit label/cache-state/runtime args, `STAGE_BEGIN`/`STAGE_END`, bounded waits, JavaScript DOM/input/output reads, partial failure row, one-row CSV, requested runtime log path, fallback runtime log discovery, and exact summarizer `--input` workflow.
- Required Branch F probe fields include `group_reset_ms`, `subgroup_reset_ms`, `segment_reset_ms`, `group_choice_ms`, `subgroup_choice_ms`, `segment_choice_ms`, total hierarchy settle time, selected group/subgroup/segment after each mutation, choice counts after each mutation, final commodity/type/country selection, output readiness, and whether each wait ended by idle, explicit readiness, or timeout fallback.
- Add client/UI evidence instead of assuming R-side runtime summaries explain the whole stage. Capture existing `client_perf_main_tabs_mount` and `client_perf_tab_after_paint` events where available, add explicit DOM/output readiness timestamps around hierarchy mutations, and consider a lightweight counter for `output$data_frequency_ui` render generations and/or `map_surface_refresh_nonce()` changes.
- Treat client-perf rows as attribution evidence only when tied to the measured hierarchy window. Startup/client-mount rows outside the hierarchy window are context, not justification for a hierarchy patch.
- If a single run is too noisy, repeat only the narrow Branch F probe enough to decide the first target. Do not use the full-path smoke as the primary gate while latency remains high.

Runtime log guardrails:
- Requested runtime log paths may not materialize. This is expected in current VP PERF behavior.
- Exact fallback JSONLs and summarizer outputs are required for every accepted measurement.
- Use `VP Clone/System/Testing/vp_perf_summarize_runtime_logs.R --input=...`; separate multiple exact JSONL paths with `|`.

Correctness and behavior guardrails:
- Preserve current user-visible VP behavior unless a deliberate measured behavior change is recorded here first.
- Preserve Provider v3 row-index behavior, direct-filter fallback, canonical-source checks, source-signature checks, row-order/source identity checks, and source-mismatch refusal.
- Preserve final selected source/trade-flow/hierarchy/commodity/country/metric/tab path.
- Preserve Current-vs-Average, Historical Trend, Heatmap, and Map row, label, projection, and display semantics.
- Map validation must include output readiness and no empty-map regression. Any shared data reuse must preserve geography fields, period fields, labels, metric/basis values, selected period behavior, and bottom-panel data.
- Preserve MYCT or document isolation. If touched helpers are used by MYCT type/country mode, run targeted MYCT sanity or explicitly justify why the path is unchanged.

Reactive-cascade guardrails:
- `freezeReactiveValue()` or batched select updates can hide legal intermediate state changes. Acceptance requires final selected path, visible choices, and downstream outputs to match the intended hierarchy.
- Do not create observer loops or hide illegal intermediate states without proving final state correctness.
- Changing `output$data_frequency_ui` or `map_surface_refresh_nonce()` dependencies can affect non-VP sources, Map refresh behavior, and hidden-tab behavior. Narrow evidence and regression checks are required before altering those dependencies.
- Shared context updates must not cause non-active tabs to render unless fresh evidence intentionally selects lazy-gating work.

Instrumentation guardrails:
- Count-only reductions are insufficient. Accepted changes require elapsed timing improvement, runtime summary explanation, final selected-path correctness, Provider v3 health, Map readiness, and MYCT isolation/sanity as applicable.
- Add replacement counters for any skipped, coalesced, or reused work. Useful candidate counters include `data_frequency_ui_rendered`, hierarchy select update/coalesce counters, `commodity_choice_ui_rendered`, and any context/token hit/miss counters introduced by the branch.
- Runtime summaries must still explain why calls disappeared or moved.

Worktree and generated-artifact guardrails:
- Record the pre-implementation changed-file set before creating the daughter plan and before product-code edits.
- Existing unrelated diffs, generated logs, generated cache `.rds` files, and perf-option drift must be separated from intended Branch F source/plan changes.
- Branch F probes will create logs/cache/artifacts. Record output paths as evidence, but do not treat generated `System/Cache`, `System/Processed Data`, or runtime JSONL files as intended source changes unless explicitly approved.

Rejected-approach guardrails:
- Do not reintroduce broad derived-reactive `bindCache()` wrappers from Branch E.
- A summary/projection branch must reduce dependency fan-out or share a correctly keyed derived bundle; it must not merely add another cache layer.
- Do not start with lazy tab gating because Branch E tab hops were already fast and current evidence does not show inactive tab rendering as the first bottleneck.
- Do not start with JS/input throttling or debounce unless duplicate browser-side firing is proven and cannot be addressed safely server-side.

## Measurement Model and Cache-State Labels

Use parent cache-state labels exactly:
- `cold_artifact`: fresh R session and no warmed partition cache for the target path.
- `warm_partition_disk`: partition files exist but session memory cache is empty.
- `warm_session`: same session and partition memory cache already hit.
- `unknown_cache_state`: only for legacy rows or documented uncertainty where evidence is not final proof.

Branch F primary evidence should be repeated-use hierarchy/sidebar interaction-focused. Startup evidence is context only unless a patch directly changes startup/current settlement.

Do not blend cache states. Do not optimize against startup-only, count-only, inherited-only, or mixed-cache evidence.

## Step Ledger

| Step | Phase | Work | Status | Evidence / Files | Gate / Next Action |
|---|---|---|---|---|---|
| 1 | A | Create Branch F daughter source-of-truth plan | Complete | Added this file before Branch F product-code edits. Pre-plan `git status --short` recorded generated cache/processed-data artifacts only. | Parent delegation complete; proceed to split-stage probe work. |
| 2 | A | Amend parent plan for Branch F delegation | Complete | Parent plan Step 13 now delegates Branch F here and deferred rows shifted to Steps 14-16. | Keep detailed Branch F implementation notes in this daughter. |
| 3 | A | Validate handoff markdown | Complete | `get_errors` reported no diagnostics for parent/daughter plans; `git diff --check` passed; direct trailing-whitespace scan produced no matches. | Proceed to Branch F split-stage probe creation. |
| 4 | B | Create or extend split-stage Branch F probe | Complete | Added sibling probe `VP Clone/System/Testing/vp_perf_probe_hierarchy_sidebar_cascade.R`; parse marker `PARSE_OK_BRANCH_F_HIERARCHY_SIDEBAR_PROBE`; radio value reader repaired with `PARSE_OK_BRANCH_F_HIERARCHY_SIDEBAR_PROBE_RADIO_VALUE`. | Probe accepted as the Branch F measurement harness. |
| 5 | B | Establish fresh Branch F split-stage baseline | Complete | Corrected baseline probe `step13_branch_f_hierarchy_sidebar_baseline_rerun` PASS: hierarchy settle 85.802s; group reset 0.637s; subgroup reset 0.627s; segment reset 0.647s; group choice 31.879s; subgroup choice 30.670s; segment choice 21.265s; total 194.745s; final path `vp_trade` / `import` / `Dry pulses` / `Dried beans` / `Dried`. | Runtime summaries showed named R-side timed work still explained only a small fraction of hierarchy wait. |
| 6 | C | Complete focused technical read and branch decision | Complete | Added attribution counters for `data_frequency_ui_rendered` and `map_surface_refresh_nonce_bumped`. Post-counter probe `step13_branch_f_attribution_counters_post` PASS: hierarchy settle 75.253s; `data_frequency_ui_rendered` 11 rows. | Selected Branch F-2 sidebar choice render stabilization. |
| 7 | D/E | Implement first measured Branch F product-code branch | Complete | Edited `02_partner_and_notes.R`: added `vp_hierarchy_change_nonce`, `vp_hierarchy_change_nonce_bumped` counter, routed hierarchy observers through the nonce, and isolated direct hierarchy input reads inside `output$data_frequency_ui`. | Accepted because elapsed hierarchy stage improved and final path/provider behavior stayed healthy. |
| 8 | E | Validate first product-code branch | Complete | Post-change probe `step13_branch_f_hierarchy_ui_nonce_post` PASS: hierarchy settle 57.531s; total 152.598s; group choice 21.111s; subgroup choice 23.036s; segment choice 11.454s; `data_frequency_ui_rendered` fell to 8 VP/Current rows; provider memory-cache 39 / 0.1994s and disk-cache 5 / 0.5005s. Final validation markers: `PARSE_OK_BRANCH_F_ACCEPTED_SLICE`, no `get_errors`, and `git diff --check` no output. | Parent closeout and final summary complete this tranche. |
| 9 | F | Close daughter and update parent | Complete | Daughter Summary completed; parent closeout updated separately. Generated logs/cache artifacts recorded as evidence, not intended source changes. | Recenter future work on parent plan. |

## Phase Plan

Phase A: Handoff setup
- Create this daughter plan.
- Amend the parent plan to delegate Branch F here and shift deferred rows as needed.
- Validate markdown handoff.

Phase B: Baseline framing and measurement hardening
- Seed inherited evidence from closed Branch E.
- Record that slow startup is still accepted and artifact/load work is out of scope.
- Create or extend the smallest focused Branch F split-stage hierarchy/sidebar probe.
- Add server-side, key-delta, provider, output-readiness, and client/DOM evidence tied to the hierarchy window.
- Establish a fresh Branch F split-stage baseline before product-code edits.

Phase C: Technical read and decision gate
- Complete focused reads of hierarchy/sidebar, dynamic UI, commodity/type choices, shared output consumers, Map, MYCT, and client-side event surfaces.
- Declare acceptance thresholds before product-code edits.
- Select the first branch from fresh Branch F evidence.

Phase D: Candidate implementation branches, in recommended order
- Branch F-0 measurement-only tranche: accept if the probe split reveals the exact blocking substage and no product-code edit is safe yet.
- Branch F-1 hierarchy mutation coalescing/batched settlement: select if reset/group/subgroup/segment updates each force full sidebar/output settlement. Candidate mechanism: carefully placed `freezeReactiveValue()` around dependent hierarchy select inputs during server-side batch updates, plus explicit unfreeze/settle validation.
- Branch F-2 sidebar choice render stabilization: select if `output$data_frequency_ui`, `output$commodity_choice_ui`, type-choice base values, or related select choices re-render repeatedly for intermediate states. Specifically test whether `map_surface_refresh_nonce()` unnecessarily refreshes the full sidebar during non-Map hierarchy work.
- Branch F-3 narrow resolved-token reuse: select if key deltas show repeated `resolve_vp_hierarchy_tokens()` / `canonicalize_vp_hierarchy_selection()` work for the same input state. Keep this narrower than the existing Provider/context caches.
- Branch F-4 summary/projection derived-data bundling: select only if split-stage evidence shows `summary_table`/`projection_data()` dominate post-settlement cost. This must reduce dependency fan-out or share a correctly keyed derived bundle.
- Branch F-5 JS/input throttling or debounce: last resort, selected only if evidence shows duplicate browser events or rapid input bursts that cannot be addressed safely server-side.

Phase E: Acceptance thresholds and validation
- Primary threshold: reduce the targeted hierarchy substage or total hierarchy stage by a meaningful amount, with no material regression in tab hops, provider fallback, final selected path, or output readiness.
- Because the current stage is about 75s, the first branch should aim for a visible win rather than a sub-second micro-optimization.
- Validate after every product-code branch with parse checks, Branch F probe, exact runtime summarizer outputs, before/after timing and churn comparison, `get_errors`, and `git diff --check`.

Phase F: Closeout
- Close the daughter only after one accepted measured branch or a measurement-only conclusion with explicit next target.
- Update the parent plan with Branch F outcome, validation markers, paths, and next recommendation.
- Complete the daughter Summary in lay terms.

## Candidate Branches

Branch F-0 measurement-only tranche:
- Select if the split-stage probe still cannot identify a safe product-code target.
- Outcome can be accepted if it produces a reliable next target and avoids speculative edits.

Branch F-1 hierarchy mutation coalescing/batched settlement:
- Select if reset/group/subgroup/segment mutations each force full sidebar/output settlement.
- Candidate mechanism: carefully placed `freezeReactiveValue()` around dependent hierarchy select inputs during server-side batch updates.
- Must preserve legal choices, final selected path, visible choices, output readiness, and downstream data.

Branch F-2 sidebar choice render stabilization:
- Select if `output$data_frequency_ui`, `output$commodity_choice_ui`, type-choice base values, or related select choices re-render repeatedly for intermediate states.
- Prefer minimal render-generation reduction or choice-data reuse before broad dynamic-UI refactors.
- Specifically test whether `map_surface_refresh_nonce()` unnecessarily refreshes the full sidebar during non-Map hierarchy work.

Branch F-3 narrow resolved-token reuse:
- Select if key deltas show repeated `resolve_vp_hierarchy_tokens()` / `canonicalize_vp_hierarchy_selection()` work for the same input state.
- Keep narrower than existing Provider/context caches; do not duplicate prior shared context layers.

Branch F-4 summary/projection derived-data bundling:
- Select only if split-stage evidence shows `summary_table` or `projection_data()` dominates post-settlement cost.
- Must be materially different from Branch E's rejected broad `bindCache()` wrappers.
- Prefer reducing dependency fan-out or sharing a correctly keyed derived bundle over adding another cache layer.

Branch F-5 JS/input throttling or debounce:
- Select only if evidence shows duplicate browser events or rapid input bursts that cannot be addressed safely server-side.
- High stale-state risk; requires strict selected-path validation.

## Verification and Validation Targets

Markdown handoff:
- `get_errors` for parent and daughter markdown.
- `git diff --check -- "VP Clone/Code Review/2026-07-29_vp_performance_hotspot_recovery_plan.md" "VP Clone/Code Review/2026-07-30_vp_branch_f_hierarchy_sidebar_reactive_cascade_reduction_plan.md"`.
- Direct trailing-whitespace scan for parent and daughter plan files.

Probe validation:
- Parse any new or edited probe with `C:\Program Files\R\R-4.5.1\bin\Rscript.exe` and a grepable `PARSE_OK` marker.
- Confirm VP probe conventions are preserved.
- Run one passing Branch F split-stage baseline before product-code edits.
- Preserve partial evidence on failure.

Runtime summary comparison:
- Compare top timed/churn buckets, hierarchy substage timing, `filtered_data`, `summary_table`, `projection_data()`, total hierarchy filter work, provider partition modes, replacement counters, key deltas, client/UI evidence, final selected path, and explicit pass/fail against pre-declared thresholds.

Behavior validation:
- Final source/trade-flow/hierarchy/commodity/country/metric/tab path.
- Sidebar choices after every measured mutation.
- Current-vs-Average output readiness.
- Historical Trend output readiness.
- Heatmap output readiness.
- Map output readiness and no empty-map regression.
- MYCT validation or isolation note if touched helpers can affect MYCT.

Product-code validation:
- Parse checks for touched R files using `C:\Program Files\R\R-4.5.1\bin\Rscript.exe` and `invisible(parse(file=...))` markers.
- Focused Branch F probe with exact runtime fallback logs and summarizer outputs.
- `get_errors` for touched files.
- `git diff --check` for touched files.

Manual sanity if needed:
- VP defaults, hierarchy dropdowns, commodity/type choices, country dropdown, Current-vs-Average, Historical Trend, Heatmap, Map, display year labels, and projection controls.

Parent closeout:
- Parent Step Ledger and Tranche Execution Notes updated with measured outcomes and residual risks.

## Bugs, Blockers, Failed Attempts, Rejected Approaches

Current blockers and risk controls:
- Attribution blocker: the remaining hierarchy stage is much larger than named R-side timed buckets. Do not accept a product-code target until split-stage timing plus runtime/client evidence explains enough of the delay to choose a branch.
- Probe blocker: if the Branch F split probe cannot reliably distinguish reset/group/subgroup/segment settlement, close the first tranche as probe hardening rather than tuning code against ambiguous evidence.
- Dirty-worktree blocker: record the pre-implementation changed-file set before creating the daughter plan and before product-code edits. Existing unrelated diffs and generated artifacts must be separated from intended Branch F source/plan changes.
- Generated-artifact blocker: Branch F probes will create logs/cache/artifacts. Record output paths as evidence, but do not treat generated `System/Cache`, `System/Processed Data`, or runtime JSONL files as intended source changes unless explicitly approved.
- Runtime-log blocker: requested runtime log paths may not materialize. Exact fallback JSONLs and summarizer outputs are required for every accepted measurement.
- Client-evidence blocker: `client_perf_*` rows and DOM observations are only useful if tied to the measured hierarchy window.
- Coalescing blocker: `freezeReactiveValue()` or batched select updates can hide legal intermediate state changes. Acceptance requires final selected path, visible choices, and downstream outputs to match the intended hierarchy.
- Dynamic-UI blocker: changing `output$data_frequency_ui` or `map_surface_refresh_nonce()` dependencies can affect non-VP sources, Map refresh behavior, and hidden-tab behavior.
- MYCT blocker: any branch touching commodity/type choice transitions must preserve `vp_type_empty_choice_transition()` and custom-builder/type fallback behavior, or run targeted MYCT sanity before acceptance.
- Acceptance blocker: count-only reductions are insufficient.

Rejected approaches before Branch F implementation:
- Reopening startup artifact/load as the first response; slow startup is still accepted for this tranche.
- Treating `filter_vp_rows_for_resolved_hierarchy()` total time alone as the bottleneck.
- Reintroducing broad derived-reactive `bindCache()` wrappers from Branch E.
- Starting with lazy tab gating; Branch E tab hops are already fast and current evidence does not show inactive tab rendering as the first bottleneck.
- Starting with JS/input throttling or debounce before duplicate browser-side firing is proven.
- Loading polish or progress UI as a substitute for reducing repeated-use work.

Resolved implementation issues:
- Probe reader defect: the first Branch F probe captured the canonical hierarchy path but left `resolved_trade_flow` blank because `vp_trade_flow_choice` is a Shiny `radioButtons()` group. Fixed `get_input_value()` to read checked radio/checkbox child inputs, validated with `PARSE_OK_BRANCH_F_HIERARCHY_SIDEBAR_PROBE_RADIO_VALUE`, and reran the baseline.
- Attribution gap: the first corrected baseline showed group/subgroup/segment choice stages dominated elapsed time, but named R-side timed buckets remained too small. Added `data_frequency_ui_rendered` and `map_surface_refresh_nonce_bumped` counters before choosing a behavior branch.
- Accepted Branch F-2 branch: `data_frequency_ui_rendered` appeared 11 times in the post-counter run, selecting sidebar render stabilization over provider/cache tuning, summary/projection bundling, or JS throttling.
- Residual risk: `summary_table` single-run timed total rose to 2.9708s in the accepted post-change run, but it remained small relative to the hierarchy-stage improvement and stayed at 8 timed calls.

## Tranche Execution Notes

- 2026-07-30 Branch F handoff creation:
  - Created this daughter source-of-truth plan before Branch F product-code edits.
  - Captured the Branch E closeout interpretation: hierarchy/filter stage remains too slow after an accepted 16.6% improvement, while tab hops and Provider v3 behavior are healthy.
  - Made measurement hardening the first Branch F gate because named R-side timed buckets do not explain enough of the remaining 75,484 ms hierarchy stage.
  - Folded audit recommendations into the plan: client/DOM/UI evidence, stable Branch E probe handling, `output$data_frequency_ui` and `map_surface_refresh_nonce()` scrutiny, `freezeReactiveValue()` as evidence-gated candidate mechanism, MYCT legal-state guardrails, dirty-worktree handling, and generated-artifact separation.
  - Pre-plan `git status --short` showed generated/untracked cache and processed-data artifacts only: 22 untracked `VP Clone/System/Cache/*.rds` files and untracked `VP Clone/System/Processed Data/`.
  - Parent delegation complete: parent Step 13 now points to this Branch F daughter, with build-time aggregation, artifact/data-format, and final-validation rows deferred to Steps 14-16.
  - Handoff validation complete:
    - `get_errors` reported no diagnostics for the parent and daughter markdown files.
    - `git diff --check -- "VP Clone/Code Review/2026-07-29_vp_performance_hotspot_recovery_plan.md" "VP Clone/Code Review/2026-07-30_vp_branch_f_hierarchy_sidebar_reactive_cascade_reduction_plan.md"` produced no output.
    - Direct trailing-whitespace scan for the parent and daughter markdown files produced no matches.

- 2026-07-30 Branch F measurement and accepted render-stabilization branch:
  - Added sibling probe `VP Clone/System/Testing/vp_perf_probe_hierarchy_sidebar_cascade.R` rather than editing the closed Branch E probe.
  - Probe conventions preserved: `NOT_CRAN`, explicit label/cache-state/runtime args, `STAGE_BEGIN`/`STAGE_END`, bounded waits, JS DOM/input/output reads, one-row CSV, requested runtime log path, fallback runtime discovery, and exact summarizer `--input` workflow.
  - Probe parse markers:
    - `PARSE_OK_BRANCH_F_HIERARCHY_SIDEBAR_PROBE`.
    - `PARSE_OK_BRANCH_F_HIERARCHY_SIDEBAR_PROBE_RADIO_VALUE` after adding radio/checkbox value support.
  - First baseline before the radio-reader repair:
    - Probe CSV: `VP Clone/Logs/vp_perf_probe_hierarchy_sidebar_cascade_step13_branch_f_hierarchy_sidebar_baseline_20260730T143144Z.csv`.
    - Status: PASS, but `resolved_trade_flow` was blank due the probe reader defect.
    - Hierarchy settle 93.134s; group reset 0.636s; subgroup reset 0.652s; segment reset 0.659s; group choice 34.750s; subgroup choice 33.867s; segment choice 22.463s; total 224.527s.
    - Runtime summaries: `VP Clone/Logs/vp_perf_runtime_summary_step13_branch_f_hierarchy_sidebar_baseline_20260730T143542Z_*.csv`.
  - Corrected official Branch F baseline:
    - Probe CSV: `VP Clone/Logs/vp_perf_probe_hierarchy_sidebar_cascade_step13_branch_f_hierarchy_sidebar_baseline_rerun_20260730T143753Z.csv`.
    - Status: PASS.
    - Final path: `vp_trade` / `import` / `Dry pulses` / `Dried beans` / `Dried`; commodity `All`; country `GRAND_TOTAL`; final tab `Current vs. Average`; comparison output visible.
    - Timings: startup-ready 92.358s; source switch 0.669s; trade-flow 13.722s; group reset 0.637s; subgroup reset 0.627s; segment reset 0.647s; group choice 31.879s; subgroup choice 30.670s; segment choice 21.265s; hierarchy settle 85.802s; total 194.745s.
    - Exact fallback runtime JSONLs: `VP Clone/Logs/vp_runtime_perf_fd10f1bb106fb53b6d53f9989c0fb1f4.jsonl` and `VP Clone/Logs/vp_runtime_perf_proc_20260730T143757Z_14840.jsonl`.
    - Runtime summaries: `VP Clone/Logs/vp_perf_runtime_summary_step13_branch_f_hierarchy_sidebar_baseline_rerun_20260730T144114Z_*.csv`.
    - Runtime result: `filter_vp_rows_for_resolved_hierarchy()` 44 calls / 3.0933s; `summary_table` 8 / 1.2730s; `projection_data()` 8 / 1.0416s; provider memory-cache 39 / 0.2538s and disk-cache 5 / 0.6574s.
    - Interpretation: hierarchy choices, not reset steps, dominate elapsed time; named R-side timed buckets still explain only a small part of the wait.
  - Added attribution counters in `02_partner_and_notes.R`:
    - `data_frequency_ui_rendered` records dynamic top/sidebar UI renders with source, tab, map surface refresh generation, hierarchy generation, trade flow, hierarchy selections, and last-changed input.
    - `map_surface_refresh_nonce_bumped` records map surface refresh nonce changes.
    - Parse marker: `PARSE_OK_BRANCH_F_ATTRIBUTION_COUNTERS`.
  - Post-counter attribution run:
    - Probe CSV: `VP Clone/Logs/vp_perf_probe_hierarchy_sidebar_cascade_step13_branch_f_attribution_counters_post_20260730T144239Z.csv`.
    - Status: PASS; final path remained `vp_trade` / `import` / `Dry pulses` / `Dried beans` / `Dried`.
    - Timings: hierarchy settle 75.253s; total 171.290s; group choice 27.050s; subgroup choice 27.943s; segment choice 18.380s.
    - Exact fallback runtime JSONLs: `VP Clone/Logs/vp_runtime_perf_ac4d413bac6224b87b32afc6a364777a.jsonl` and `VP Clone/Logs/vp_runtime_perf_proc_20260730T144243Z_13296.jsonl`.
    - Runtime summaries: `VP Clone/Logs/vp_perf_runtime_summary_step13_branch_f_attribution_counters_post_20260730T144536Z_*.csv`.
    - Counter evidence: `data_frequency_ui_rendered` appeared 11 times for VP / Current vs. Average, selecting Branch F-2 sidebar choice render stabilization.
  - Accepted Branch F-2 implementation in `VP Clone/Programs/app_source/server/02_partner_and_notes.R`:
    - Added `vp_hierarchy_change_nonce` and `bump_vp_hierarchy_change_nonce()` with counter `vp_hierarchy_change_nonce_bumped`.
    - Routed `vp_group_choice`, `vp_subgroup_choice`, and `vp_market_segment_choice` observers through the nonce.
    - Made `output$data_frequency_ui` depend on the hierarchy nonce and read the raw hierarchy input values with `isolate()` to avoid direct duplicate render invalidations.
    - Left `map_surface_refresh_nonce()` instrumentation in place; the accepted branch did not change Map refresh semantics.
    - Parse marker: `PARSE_OK_BRANCH_F_HIERARCHY_UI_NONCE`.
  - Accepted post-change validation:
    - Probe CSV: `VP Clone/Logs/vp_perf_probe_hierarchy_sidebar_cascade_step13_branch_f_hierarchy_ui_nonce_post_20260730T144632Z.csv`.
    - Status: PASS.
    - Final path: `vp_trade` / `import` / `Dry pulses` / `Dried beans` / `Dried`; final tab `Current vs. Average`; comparison output visible.
    - Timings versus corrected official Branch F baseline: hierarchy settle 85.802s -> 57.531s; total 194.745s -> 152.598s; group choice 31.879s -> 21.111s; subgroup choice 30.670s -> 23.036s; segment choice 21.265s -> 11.454s.
    - Timings versus post-counter same-instrumentation run: hierarchy settle 75.253s -> 57.531s; total 171.290s -> 152.598s.
    - Exact fallback runtime JSONLs: `VP Clone/Logs/vp_runtime_perf_05afa8e122a12e074c4dc7499e4c9a7d.jsonl` and `VP Clone/Logs/vp_runtime_perf_proc_20260730T144636Z_11980.jsonl`.
    - Runtime summaries: `VP Clone/Logs/vp_perf_runtime_summary_step13_branch_f_hierarchy_ui_nonce_post_20260730T144910Z_*.csv`.
    - Counter evidence: `data_frequency_ui_rendered` fell from 11 to 8 VP / Current vs. Average rows; `vp_hierarchy_change_nonce_bumped` recorded 6 hierarchy input changes.
    - Provider remained healthy: memory-cache 39 / 0.1994s and disk-cache 5 / 0.5005s, with no direct-filter fallback row.
    - Named timed buckets remained small relative to elapsed hierarchy time: `filter_vp_rows_for_resolved_hierarchy()` 44 / 2.7246s; `projection_data()` 8 / 0.9669s; `output$commodity_choice_ui` 8 / 0.4494s.
    - Residual timed risk: `summary_table` remained 8 calls and rose to 2.9708s in this single run, but this did not offset the elapsed hierarchy-stage improvement.
  - Final focused validation:
    - Parse marker: `PARSE_OK_BRANCH_F_ACCEPTED_SLICE` for `02_partner_and_notes.R` and `vp_perf_probe_hierarchy_sidebar_cascade.R`.
    - `get_errors` reported no diagnostics for touched server, probe, parent plan, or daughter plan files.
    - `git diff --check` produced no output for touched server, probe, parent plan, and daughter plan files.
  - Worktree/generated-artifact state:
    - Intended source/plan changes: parent plan, Branch F daughter plan, `02_partner_and_notes.R`, and `vp_perf_probe_hierarchy_sidebar_cascade.R`.
    - Generated evidence retained under `VP Clone/Logs/`: Branch F probe CSVs, runtime JSONLs, and runtime summary CSVs listed above.
    - Additional untracked `VP Clone/System/Cache/*.rds` files and `VP Clone/System/Processed Data/` remain generated artifacts, not intended source changes.

## Summary

Branch F is complete. This tranche picked up where Branch E left off: the app could switch tabs quickly after filters settled, but changing the VP hierarchy still took far too long for normal repeated use. Instead of guessing at another cache, I added a new split-stage probe that measures reset, group, subgroup, and segment changes separately.

The split showed that reset steps were cheap, under one second each, while the real hierarchy choices were expensive. The corrected Branch F baseline took 85.802 seconds for the hierarchy stage: 31.879 seconds for group, 30.670 seconds for subgroup, and 21.265 seconds for segment. Runtime logs still showed that named R-side timed helpers explained only a small part of the wait, so I added counters for dynamic sidebar rendering and Map refresh invalidation before changing behavior.

Those counters showed `output$data_frequency_ui` rebuilding repeatedly during hierarchy changes. The accepted fix is a narrow render-stabilization change in `02_partner_and_notes.R`: hierarchy input observers now bump a dedicated hierarchy-change nonce, and `output$data_frequency_ui` depends on that nonce while reading raw hierarchy inputs with `isolate()`. This keeps the UI responsive to actual hierarchy changes but avoids direct duplicate invalidations from the same controls.

The accepted post-change probe passed. Hierarchy settle time improved from 85.802 seconds to 57.531 seconds, and total probe time improved from 194.745 seconds to 152.598 seconds. The same-instrumentation comparison also improved from 75.253 seconds to 57.531 seconds. The final path stayed correct: VP trade, import, Dry pulses, Dried beans, Dried, returning to Current vs. Average with comparison output visible. Provider v3 stayed healthy with memory and disk cache rows and no direct-filter fallback row.

Validation passed with `PARSE_OK_BRANCH_F_ACCEPTED_SLICE`, clean `get_errors`, clean `git diff --check`, and exact runtime fallback summaries. Residual risk remains in broader repeated churn: `summary_table`, display-month mapping, filtered data, mixed-volume, quantity-unit, type-choice, and Map key-delta surfaces still execute around hierarchy changes. Startup artifact loading also remains intentionally deferred.
