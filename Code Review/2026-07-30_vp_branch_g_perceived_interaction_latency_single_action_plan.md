# VP Branch G Perceived Interaction Latency Single-Action Plan

Date: 2026-07-30
Branch: main
Status: Closed. Branch G produced an accepted single-action perceived-latency probe and rejected three product-code experiments. No product-code branch is accepted from this tranche.

## Purpose

Branch E and Branch F produced measured wins, but the VP app still feels too slow in ordinary manual use. The user now observes 5-6 second tab transitions, 5-6 second commodity changes, and 10+ second group/subgroup waits. Branch G therefore targets perceived single-action latency: when the user changes one filter, one commodity, or one tab, how long until the visible result is correct, how long until the next interaction is actually accepted, and how long until the Shiny session is fully idle.

This tranche must not reopen Branch E or Branch F. Branch E showed that settled tab hops can be sub-second after filter work has drained. Branch F reduced the hierarchy/sidebar cascade, with hierarchy settle improving from 85.802 seconds to 57.531 seconds, but named R-side timed buckets still explain only part of the remaining wait. Branch G starts from the manual symptom rather than from a broad cache or UI rewrite.

## Scope

Included:
- Create this daughter source-of-truth ledger before Branch G probe or product-code edits.
- Update the parent performance plan so Branch F stays closed and Branch G is delegated here as the next active measured tranche.
- Record the user's manual symptoms as the active baseline driver.
- Create or fork a focused single-action Shiny probe that measures visible readiness, actual client interactivity, and full Shiny idle separately.
- Capture action IDs, final selected state, stale-output guardrails, browser diagnostics, runtime fallback logs, and provider health for each measured action.
- Select the first product-code branch only after the Branch G baseline separates commodity latency, hierarchy latency, tab latency, client/main-thread latency, hidden reactive drain, and stale/queued server work.
- Preserve Provider v3 behavior, direct-filter fallback, source identity checks, current output semantics, Map readiness, and MYCT legal state behavior.
- Record timing, churn, key-delta, provider, client, DOM, Plotly/MutationObserver, final-state, stale-output, and validation evidence.

Excluded:
- Startup artifact/load rewrites unless the user explicitly reprioritizes startup or Branch G proves startup work blocks repeated-use interactions.
- Build-time aggregation tuning unless fresh runtime evidence proves build/rebuild work blocks ordinary app use.
- Loading polish, spinners, progress copy, or cosmetic waiting-state work as a substitute for reducing avoidable work.
- Broad non-VP tuning.
- Reintroducing Branch E's rejected broad derived-reactive `bindCache()` wrappers without materially different evidence and design.
- Tabset/component architecture rewrites unless settled tab clicks are independently slow and client/server evidence points directly there.
- A paired results markdown file unless explicitly requested.

## Parent Plan Linkage

Parent plan: `VP Clone/Code Review/2026-07-29_vp_performance_hotspot_recovery_plan.md`.

This daughter plan owns detailed Branch G implementation notes for perceived interaction latency and single-action measurement. The parent remains the broad performance-recovery ledger. During this tranche, the parent should contain only the delegation note, high-level status, and later closeout summary; detailed probe design, failed attempts, runtime outputs, product-code decisions, and validation evidence belong here.

Parent ledger amendment requirement:
- Keep Step 13 Branch F marked complete.
- Add a new active Step 14 delegating Branch G perceived interaction latency here.
- Shift deferred build-time aggregation, artifact/data-format, and final validation rows down as needed.
- Record that startup slowness is still deferred unless Branch G evidence changes that decision.

At closeout:
- Complete this daughter `## Summary` section in plain language.
- Update the parent Step Ledger with Branch G outcome, validation markers, output paths, timing/client/provider deltas, residual risks, and next recommendation.
- Recenter future work on the parent plan.

## Source-Of-Truth Ledger Contract

- This file is the active source of truth for the Branch G perceived-latency tranche.
- Update this file after every step or tranche before moving to the next tranche.
- Record files touched, commands/probes, benchmark labels, cache-state labels, runtime log paths, fallback JSONL inputs, summary CSVs, action IDs, visible-ready timings, client-interaction-ready timings, full-idle timings, final selected state, stale-output checks, browser diagnostics, provider summaries, branch decisions, bugs, blockers, failed attempts, rejected approaches, and decision gates.
- Keep parent-plan updates limited to delegation and closeout while this daughter plan is active.
- Preserve enough detail that a future coder can resume without replaying chat history.
- At completion, provide a short chat summary and complete the final `## Summary` section in this file.

## Baseline Evidence

Closed Branch E daughter plan:
- `VP Clone/Code Review/2026-07-30_vp_branch_e_interaction_filtering_tab_switch_responsiveness_plan.md`.
- Branch E accepted a narrow commodity-choice base reuse branch in `01_state_and_custom_types.R`.
- Branch E rejected broad derived-reactive `bindCache()` wrappers after they worsened timing.
- Official Branch E improvement: hierarchy-change stage 90.517s -> 75.484s; total probe 217.289s -> 201.650s.
- Branch E interpretation: settled tab switches stayed passing/sub-second after filter settlement, so tab latency observed manually may be prior reactive drain or client work rather than tab activation alone.

Closed Branch F daughter plan:
- `VP Clone/Code Review/2026-07-30_vp_branch_f_hierarchy_sidebar_reactive_cascade_reduction_plan.md`.
- Branch F added `VP Clone/System/Testing/vp_perf_probe_hierarchy_sidebar_cascade.R` and accepted a narrow hierarchy UI nonce/render-stabilization branch in `02_partner_and_notes.R`.
- Official Branch F improvement: corrected hierarchy settle 85.802s -> 57.531s; total probe 194.745s -> 152.598s; same-instrumentation hierarchy settle 75.253s -> 57.531s; `data_frequency_ui_rendered` 11 -> 8.
- Branch F interpretation: reset steps were cheap; hierarchy choices were expensive; named R-side timed buckets still explained only a small part of user-visible wait.

Manual Branch G baseline driver:
- User-observed Shiny behavior after Branch F: 5-6 second tab transitions, 5-6 second commodity changes, and 10+ second group/subgroup waits.
- Manual baseline note still to record before probe acceptance: browser, approximate click sequence, repeated-use versus first-use behavior, and whether clicks during waits are ignored, delayed, queued, or accepted but slow.

Pre-Branch-G worktree snapshot, 2026-07-30:
- `get_changed_files` before creating this plan showed generated/untracked VP partition cache artifacts under `VP Clone/System/Processed Data/vp_trade_partitions/vp_trade_partition_provider_v3/vp_trade_artifact_2026_07_28_v6/`, including slice `.rds` files and `vp_trade_partition_manifest.rds`.
- Those generated artifacts predate this Branch G source edit and are not intended Branch G source changes.
- Branch G probes are expected to create more logs/cache/artifacts. Record output paths as evidence and keep generated files separate from intended source/plan changes.

## Technical Read

Hierarchy/sidebar surfaces:
- `VP Clone/Programs/app_source/server/02_partner_and_notes.R` owns `output$data_frequency_ui`, `vp_hierarchy_change_nonce`, `vp_hierarchy_last_changed`, hierarchy observers, `vp_resolve_hierarchy_choice_state()`, `vp_filter_rows_for_hierarchy_choices()`, `filter_vp_rows_for_resolved_hierarchy()`, `map_surface_refresh_nonce()`, `bump_map_surface_refresh_nonce()`, `output$main_tabs`, `main_tabs_render_nonce`, and `log_client_perf()`.
- Branch F accepted hierarchy nonce/render stabilization here. Branch G must not undo it.

Commodity/type/country surfaces:
- `VP Clone/Programs/app_source/server/01_state_and_custom_types.R` owns `commodity_choice_native_base_values()`, `commodity_choice_real_values()`, `commodity_choice_fallback_values()`, `output$commodity_choice_ui`, and `vp_type_empty_choice_transition()`.
- `VP Clone/Programs/app_source/server/03_core_reactives_and_ui.R` owns `filtered_data_stable_cache_key()`, `filtered_data()`, `most_recent()`, `historical_avg()`, `current_year_data()`, `projection_data()`, `country_choice_options()`, and `custom_comparison_panel_vp_type_choices()`.
- If commodity changes dominate Branch G evidence, the first likely code branch should target commodity/type/country refresh or repeated `filtered_data`/summary/projection work before hierarchy or tabset architecture work.

Current-vs-Average and hidden-drain surfaces:
- `VP Clone/Programs/app_source/server/04_comparison_plots.R` owns `output$summary_table`, comparison plot output, and active-tab gating.
- Output gating is only acceptable if it reduces actual server/reactive work or safely decouples work from the next interaction. Hiding output while the session remains blocked is not an accepted win.

Tab and client surfaces:
- `VP Clone/Programs/app_source/server/05_trend_and_heatmap.R` owns Historical Trend, Heatmap, and Map outputs/readiness surfaces.
- `VP Clone/Programs/app_source/ui.R` owns client perf events, MutationObserver blocks, tab after-paint events, Plotly resize events, and hierarchy/commodity/tab change listeners.
- Branch G tab evidence must separate client-only tab activation/paint delay, server work triggered by tab activation, and prior reactive queue drain that blocks a tab click while work is pending.

Local hypothesis for the first Branch G code branch:
- The next safe code branch should be selected only after a single-action probe shows whether commodity changes, hierarchy changes, tab clicks while pending, or client interaction readiness is the dominant manual pain.
- If commodity changes reproduce the user's 5-6 second wait and runtime evidence points to commodity/type/country refresh or repeated shared reactives, choose commodity-change fast path first.

First cheap disconfirmation check:
- A fresh Branch G single-action probe must produce per-action `visible_ready_ms`, `client_interaction_ready_ms`, and `full_idle_ms` for canonical commodity, hierarchy, settled-tab, and tab-while-pending actions.
- If the probe cannot distinguish those windows, close the first tranche as measurement/probe hardening rather than optimizing ambiguous code.

## Guardrails

Probe and measurement guardrails:
- Create a new focused sibling probe, `VP Clone/System/Testing/vp_perf_probe_single_action_latency.R`, rather than destabilizing closed Branch E/F probes.
- Reuse established VP probe conventions: `NOT_CRAN`, explicit label/cache-state/runtime args, `STAGE_BEGIN`/`STAGE_END`, bounded waits, JS/DOM reads, partial failure evidence, one-row or per-action CSV output, requested runtime log path, fallback runtime log discovery, and exact summarizer `--input` workflow.
- Required readiness fields per action: `visible_ready_ms`, `client_interaction_ready_ms`, and `full_idle_ms`.
- Required identity fields per action: `action_id`, scenario/action name, source, trade flow, selected group/subgroup/segment, commodity, country, metric, tab, output signature if available, readiness status, timeout reason, and final selected path.
- Required client/browser fields where cheap: DOM node count before/after, `shiny-busy` duration, requestAnimationFrame or after-paint timestamp, primary output widget count, Plotly resize/relayout counts if available, MutationObserver/client event counts if available, and follow-up click/focus/input echo latency.
- Treat `wait_for_idle()` as tail-heavy and unstable. Use staged explicit readiness checks first, and record full idle separately.

Canonical scenario guardrails:
- Recommended canonical start: source `vp_trade`, trade flow `import`, tab `Current vs. Average`, commodity `All`, country `GRAND_TOTAL`.
- Required single actions: group `All -> Dry pulses`; subgroup `All -> Dried beans` after group is set; segment `All -> Dried`; commodity `All -> one valid in-slice commodity`; if cheap, commodity `specific -> All`; settled tab clicks Current -> Historical Trend -> Heatmap -> Map -> Current; tab click immediately after a filter or commodity mutation while work may still be draining.
- Record whether clicks during an action are ignored, queued, accepted but slow, or handled promptly.

Correctness guardrails:
- Preserve current user-visible VP behavior unless a deliberate measured behavior change is recorded here first.
- Preserve Provider v3 row-index behavior, direct-filter fallback, canonical-source checks, source-signature checks, row-order/source identity checks, and source-mismatch refusal.
- Preserve final selected source/trade-flow/hierarchy/commodity/country/metric/tab path.
- Preserve legal dropdown choices after every measured action; no snap-back to stale `All` or illegal intermediate values.
- Preserve Current-vs-Average, Historical Trend, Heatmap, and Map row, label, projection, and display semantics.
- Map validation must include output readiness and no empty-map regression if tab/output changes are touched.
- Preserve MYCT or document isolation. If touched helpers are used by MYCT type/country mode, run targeted MYCT sanity or explicitly justify why the path is unchanged.
- Any visible-ready/deferred-work branch must prove the visible output corresponds to the final selected state, not an earlier stale state.

Runtime and generated-artifact guardrails:
- Requested runtime log paths may not materialize. Exact fallback JSONLs and summarizer outputs are required for every accepted measurement.
- Use `VP Clone/System/Testing/vp_perf_summarize_runtime_logs.R --input=...`; separate multiple exact JSONL paths with `|`.
- Record generated probe/log/cache artifacts as evidence, but do not treat generated `Logs`, `System/Cache`, or `System/Processed Data` files as intended source changes unless explicitly approved.

Rejected-approach guardrails:
- Do not start with broad `bindCache()` wrappers.
- Do not start with JS throttling/debounce unless client evidence proves duplicate browser events dominate.
- Do not start with tabset architecture changes unless settled tab clicks are independently slow and `output$main_tabs`/DOM/client evidence points directly there.
- Do not accept count-only wins. Accepted changes require elapsed user-facing improvement, correctness, Provider v3 health, and relevant output readiness.

## Measurement Model and Cache-State Labels

Every Branch G probe row must identify cache state:

- `cold_artifact`: fresh R session and no warmed partition cache for the target path.
- `warm_partition_disk`: partition files exist but session memory cache is empty.
- `warm_session`: same session and partition memory cache already hit.
- `unknown_cache_state`: only allowed for target-selection or failed/partial evidence where the uncertainty is recorded.

Every measured action must identify readiness state:

- `visible_ready_ms`: elapsed time until the primary visible output appears stable and selected-state checks pass.
- `client_interaction_ready_ms`: elapsed time until a lightweight follow-up click/focus/input echo succeeds.
- `full_idle_ms`: elapsed time until Shiny busy/idle checks complete or timeout.

Do not blend actions, cache states, or readiness windows into one number. Branch G success is about perceived interaction readiness, not full-idle timing alone.

## Step Ledger

| Step | Phase | Work | Status | Evidence / Files | Gate / Next Action |
|---|---|---|---|---|---|
| 1 | A | Create Branch G daughter plan | Complete | Added this file before probe/product-code edits. | Parent delegation and markdown handoff validation complete. |
| 2 | A | Update parent plan delegation | Complete | Parent file `VP Clone/Code Review/2026-07-29_vp_performance_hotspot_recovery_plan.md` now marks Step 14 Branch G active and shifts deferred rows down. | Build Branch G single-action probe next. |
| 3 | A | Validate plan handoff | Complete | `get_errors` found no markdown diagnostics; `git diff --check` produced no output; direct trailing-whitespace scan produced no matches for parent and daughter plans. | Safe to proceed to probe code. |
| 4 | B | Build single-action perceived-latency probe | Complete (initial) | Added `VP Clone/System/Testing/vp_perf_probe_single_action_latency.R`. Validation markers: `PARSE_OK_BRANCH_G_SINGLE_ACTION_PROBE`; `get_errors` clean; `git diff --check` clean; direct trailing-whitespace scan clean. | Run Branch G baseline next. |
| 5 | B | Run Branch G measurement baseline | Complete | Valid baseline is `step14_branch_g_single_action_realclick_baseline`: 11/11 PASS; output CSV `VP Clone/Logs/vp_perf_probe_single_action_latency_step14_branch_g_single_action_realclick_baseline_20260730T164641Z.csv`; fallback runtime input `VP Clone/Logs/vp_runtime_perf_proc_20260730T164644Z_24084.jsonl|VP Clone/Logs/vp_runtime_perf_46895afccdcdfa4c64c2d479a966ece2.jsonl`; summaries `VP Clone/Logs/vp_perf_runtime_summary_runtime_logs_20260730T165034Z_*.csv`. | Baseline shows commodity/hierarchy visible readiness is fast, settled tab output readiness is slow, and hierarchy/filter full-idle tails remain long. |
| 6 | C | Focused technical read and first branch decision | Complete (initial) | Read tab/main-tabs, client perf, Plotly resize, Pace, and output gating surfaces. Rejected two product-code experiments after validation: removing Plotly redraw worsened tab readiness; gating inactive Pace default target caused widespread partial/timeouts. Both were reverted and parse-checked. | Do not accept product-code changes yet; next branch should target output/client render evidence, not broad provider/cache or Pace hidden-work gating. |
| 7 | D | Implement first measured code branch | Complete (no accepted product branch) | Probe implementation accepted; product-code experiments reverted. Added root-output widget counting and Plotly-specific output readiness fields; hardened baseline passed and confirmed real Plotly/widget readiness. Tested hidden-rendering Trend/Heatmap outputs; validation regressed to 11/11 PARTIAL and was reverted. Current intended source changes are the Branch G plan and probe only. | Next branch should avoid hidden-output warming and instead target the source of the near-10s Plotly materialization delay or narrow full-idle churn. |
| 8 | E | Closeout and parent recenter | Complete | Daughter summary and parent update completed. Post-closeout marketing-year/display-month diagnostic context added after the user question on 2026-07-30. | Keep Branch G closed; use this context to steer the next parent-plan tranche rather than reopening accepted Branch G files. |

## Phase Plan

Phase A: Handoff
- Create this daughter plan.
- Update the parent plan so Branch G is the active delegated tranche.
- Validate markdown before probe/product-code edits.

Phase B: Single-action measurement
- Create the Branch G probe.
- Measure canonical manual-like actions.
- Capture visible-ready, client-interaction-ready, full-idle, action ID, browser/client diagnostics, final state, stale-output checks, runtime fallback logs, and provider health.

Phase C: Target selection
- Read only the surfaces implicated by the Branch G baseline.
- Select the first code branch from evidence rather than manual symptom labels alone.

Phase D: Measured implementation
- Make the smallest product-code change that targets the measured cause.
- Validate with the same Branch G action(s), runtime summarizer, correctness checks, Provider v3 health, and worktree checks.

Phase E: Closeout
- Record accepted/rejected branches, output paths, validation markers, timing deltas, residual risks, and next recommendation.
- Update parent plan and complete the Summary.

## Candidate Branches

Branch G-0 measurement-only tranche:
- Accept if the new probe exposes the visible-ready/client-interaction-ready/full-idle gap but no product-code edit is safe yet.
- Required if current probes cannot represent manual interaction.

Branch G-1 commodity-change fast path:
- Select if 5-6 second commodity changes are dominated by commodity/type/country choice refresh or repeated `filtered_data`/summary/projection work.
- Prefer reuse or active-output dependency narrowing over broad caching.

Branch G-2 visible-ready and interaction-ready gating for Current-vs-Average:
- Select if primary output is usable before background drain but Shiny/browser remains blocked for the next interaction.
- Candidate surfaces include `summary_table`, projection/notes consumers, and non-visible secondary work.
- Acceptance requires reducing actual server/reactive work or safely decoupling it; hiding output is not enough.

Branch G-3 tab while busy stabilization:
- Select if settled tab clicks are fast but tab clicks while prior filter/commodity work drains are slow.
- Prefer reducing upstream drain before tab-specific code changes.

Branch G-4 hierarchy single-action coalescing:
- Select if one group/subgroup/segment action still triggers repeated render or choice rebuilds beyond Branch F's nonce path.
- Candidate mechanisms include finer-grained choice updates, carefully verified `freezeReactiveValue()` windows, or reduced destructive dynamic UI rebuilds.

Branch G-5 tabset/component stability:
- Select only if settled tab clicks are independently slow and evidence implicates `output$main_tabs`, `main_tabs_render_nonce`, DOM growth, MutationObserver churn, or Plotly resize/relayout work.
- Treat as a large UI architecture branch.

Branch G-6 startup/artifact pivot:
- Select only if explicitly reprioritized or Branch G proves startup/artifact work blocks repeated-use interactions.

## Verification and Validation Targets

- Daughter/parent handoff: markdown diagnostics where available, `git diff --check`, and direct trailing-whitespace scan.
- Probe parse: `C:\Program Files\R\R-4.5.1\bin\Rscript.exe -e "invisible(parse(file='VP Clone/System/Testing/vp_perf_probe_single_action_latency.R')); cat('PARSE_OK_BRANCH_G_SINGLE_ACTION_PROBE\n')"`.
- Branch G baseline: single-action probe PASS or PARTIAL with useful evidence, cache-state label, action IDs, final selected path, visible-ready timing, client-interaction-ready timing, full-idle timing, browser diagnostics, provider summary, and exact runtime fallback inputs.
- Runtime summaries: `VP Clone/System/Testing/vp_perf_summarize_runtime_logs.R --input=...` for exact JSONLs after every Shiny probe.
- Product-code parse: `invisible(parse(file=...))` with grepable `PARSE_OK` markers for every touched R file.
- Behavior checks: final path, sidebar choices, commodity/country/type choices, Current-vs-Average, Historical Trend, Heatmap, Map readiness, stale-output signatures, and MYCT sanity/isolation if touched.
- Provider v3 checks: memory/disk cache modes healthy, no direct-filter fallback regression, no source-identity/source-signature mismatch, no row-order/source refusal.
- Worktree checks: `get_errors`, `git diff --check`, and generated artifact review.

## Bugs, Blockers, Failed Attempts, Rejected Approaches

- Known perception mismatch blocker: existing probes can show settled tab hops as fast while manual tab clicks feel slow during background reactive drain. Branch G must measure tab clicks after settlement and while work is pending.
- Known interaction-ready blocker: visible DOM readiness can be misleading if Plotly/DT/MutationObserver work still blocks the browser main thread. Branch G must measure a follow-up interaction echo.
- Known probe-correlation blocker: without action IDs, runtime summaries may mix the target action with startup, prior drain, or later tab work.
- Known probe blocker: if the single-action probe cannot distinguish visible-ready, client-interaction-ready, and full-idle, the first tranche must harden the probe rather than tune code against ambiguous evidence.
- Known dynamic UI risk: changing `output$data_frequency_ui` or `output$main_tabs` can affect control identity, DOM stability, Map refresh, hidden-tab behavior, and non-VP sources.
- Known commodity correctness risk: commodity/type/country updates can transiently enter invalid states after hierarchy changes.
- Known hidden-work risk: reducing visible latency by merely hiding background work is not enough if the app remains blocked.
- Known stale-output risk: decoupling visible readiness from full idle can show stale data if selected-state/output-state consistency is not validated.
- Known runtime-log caveat: requested runtime log paths often do not materialize; exact fallback JSONLs remain required.
- Rejected as first response: broad `bindCache()` wrappers, JS throttling, tabset rewrite, startup/artifact pivot, or loading polish before Branch G measurement.
- Rejected product-code experiment, 2026-07-30: removed `Plotly.redraw()` from the `forcePlotlyResize` client handler while keeping `Plotly.Plots.resize()`. Validation label `step14_branch_g_realclick_no_plotly_redraw` worsened settled tab visible readiness to 11.673-16.227s and was reverted. Revert parse marker: `PARSE_OK_BRANCH_G_UI_REDRAW_RESTORED`.
- Rejected product-code experiment, 2026-07-30: gated `pace_default_target_info()` when the Pace tab was inactive to stop hidden `pace_historical_avg()` churn. Validation label `step14_branch_g_realclick_pace_gate` produced 10 PARTIAL rows, several output visible-ready timeouts, and full-idle timeouts. The change was reverted. Revert parse marker: `PARSE_OK_BRANCH_G_PACE_GATE_REVERTED`.

## Tranche Execution Notes

- 2026-07-30 Tranche A (Branch G daughter handoff):
  - Created this daughter plan from the refined session plan and closed Branch E/F evidence.
  - Active user symptoms recorded as the Branch G driver: 5-6 second tab transitions, 5-6 second commodity changes, and 10+ second group/subgroup waits.
  - Measurement requirement tightened around three windows: visible-ready, client-interaction-ready, and full-idle.
  - `get_changed_files` before plan creation showed generated/untracked VP partition provider v3 artifacts under `System/Processed Data`; these are not intended Branch G source changes.
  - Parent delegation completed: parent Step 14 now points to this Branch G daughter plan and deferred build/artifact/final rows were shifted down.
  - Handoff validation completed: `get_errors` found no markdown diagnostics; `git diff --check` produced no output; direct trailing-whitespace scan produced no matches for parent and daughter plans.
  - Next action: create `VP Clone/System/Testing/vp_perf_probe_single_action_latency.R` and parse-check it before any Shiny baseline run.

- 2026-07-30 Tranche B (single-action probe creation):
  - Added `VP Clone/System/Testing/vp_perf_probe_single_action_latency.R` as a new sibling probe, leaving the closed Branch E/F probes unchanged.
  - Probe design:
    - Emits one CSV row per measured action rather than one row for the whole scenario.
    - Records `action_id`, action kind, target input/value, optional pending trigger, final selected state, output snapshot, and stale-output guard fields.
    - Measures `visible_ready_ms`, `client_interaction_ready_ms`, and `full_idle_ms` separately for hierarchy, commodity, settled-tab, and tab-while-pending actions.
    - Installs cheap browser-side counters for DOM nodes, `shiny-busy`, input changes, MutationObserver events, and Plotly afterplot/relayout events where available.
    - Preserves the established requested runtime log path plus exact fallback-log discovery contract.
  - Validation:
    - Parse marker: `PARSE_OK_BRANCH_G_SINGLE_ACTION_PROBE`.
    - `get_errors` found no diagnostics for the new probe.
    - `git diff --check` produced no output for the new probe.
    - Direct trailing-whitespace scan produced no matches for the new probe.
  - Initial baseline note:
    - First baseline label `step14_branch_g_single_action_baseline` passed 11/11 rows, but tab actions used `set_inputs(main_tabs_panel=...)`, which was not manual-like enough for client action attribution.
    - Probe then changed tab actions to use tab anchor activation.
    - Second baseline label `step14_branch_g_single_action_clicktab_baseline` still used Bootstrap `.tab('show')`, which showed tabs but bypassed the app's click handler; this contaminated tab client action attribution.
    - Probe then changed tab actions again to dispatch the real anchor `click()` event.

- 2026-07-30 Tranche C (valid real-click baseline):
  - Probe hardening:
    - `click_main_tab_no_wait()` now dispatches the actual tab anchor click event for `main_tabs_panel` actions.
    - Parse marker after correction: `PARSE_OK_BRANCH_G_SINGLE_ACTION_PROBE`.
  - Valid measurement run:
    - Label: `step14_branch_g_single_action_realclick_baseline`.
    - Cache-state: `warm_partition_disk`.
    - Status: `PASS=11`.
    - Output CSV: `VP Clone/Logs/vp_perf_probe_single_action_latency_step14_branch_g_single_action_realclick_baseline_20260730T164641Z.csv`.
    - Requested runtime log path: `VP Clone/Logs/vp_runtime_perf_single_action_step14_branch_g_single_action_realclick_baseline_20260730T164641Z.jsonl` did not materialize.
    - Exact fallback runtime input: `VP Clone/Logs/vp_runtime_perf_proc_20260730T164644Z_24084.jsonl|VP Clone/Logs/vp_runtime_perf_46895afccdcdfa4c64c2d479a966ece2.jsonl`.
    - Runtime summary outputs: `VP Clone/Logs/vp_perf_runtime_summary_runtime_logs_20260730T165034Z_files.csv`, `_events.csv`, `_timed.csv`, `_key_delta.csv`, `_churn.csv`, `_partition.csv`, `_memory.csv`.
  - Action timing interpretation:
    - Hierarchy visible readiness was fast in this scenario: group 56ms, subgroup 82ms, segment 71ms.
    - Commodity visible readiness was fast in this scenario: `All -> Unspecified` 62ms and `Unspecified -> All` 72ms.
    - Settled tab output readiness was slow: Historical Trend 8.379s, Heatmap 9.856s, Map 9.443s, return to Current 8.648s.
    - Tab while commodity pending was visibly ready quickly at 103ms, but full idle remained long at 13.224s.
    - Hierarchy/filter full-idle tails remained long even when visible readiness was fast: group 20.431s, subgroup 21.579s, segment 10.867s.
  - Client/runtime interpretation:
    - Direct tab click shell/after-paint rows were small once the probe used real click events, so the tab shell itself is not the primary slow path.
    - Output-specific readiness still waited 8-10s on settled tab switches, suggesting Plotly/widget output render/readiness or output delivery rather than `output$main_tabs` shell activation.
    - Runtime summary top timed rows were client tab timing and startup; server-side plot render buckets were comparatively small.
    - Churn still showed repeated `summary_table_executed`, display-month mapping hits, year-filter sync observer activity, and provider slice/filter events, but those did not explain the settled tab output-readiness delay by elapsed server time.
  - Decision: do not select Provider v3, broad `bindCache()`, tabset rewrite, or startup/artifact work from this evidence.

- 2026-07-30 Tranche D (rejected product-code probes):
  - Product experiment 1: remove forced `Plotly.redraw()` from the `forcePlotlyResize` client handler in `VP Clone/Programs/app_source/ui.R` while preserving `Plotly.Plots.resize()`.
    - Parse marker after edit: `PARSE_OK_BRANCH_G_UI_PLOTLY_RESIZE`.
    - Validation label: `step14_branch_g_realclick_no_plotly_redraw`.
    - Result: worsened settled tab visible readiness to Historical Trend 13.547s, Heatmap 16.227s, Map 13.552s, Current 11.673s, return Current 12.801s.
    - Outcome: rejected and reverted.
    - Revert parse marker: `PARSE_OK_BRANCH_G_UI_REDRAW_RESTORED`.
  - Product experiment 2: gate `pace_default_target_info()` while the Pace tab is inactive in `VP Clone/Programs/app_source/server/06_pace_analysis_and_reset.R`.
    - Rationale: runtime churn showed `pace_historical_avg()` repeatedly even though the Pace tab was inactive.
    - Parse marker after edit: `PARSE_OK_BRANCH_G_PACE_INACTIVE_GATE`.
    - Validation label: `step14_branch_g_realclick_pace_gate`.
    - Result: validation degraded badly: `PARTIAL=10|PASS=1`, multiple output visible-ready timeouts, multiple full-idle timeouts, and required-controls wait timeout at startup.
    - Outcome: rejected and reverted; the app appears to rely on this chain being warm despite hidden Pace tab state.
    - Revert parse marker: `PARSE_OK_BRANCH_G_PACE_GATE_REVERTED`.
  - Current source status after rejected experiments: app-code edits are reverted; intended Branch G source changes are the daughter plan and `VP Clone/System/Testing/vp_perf_probe_single_action_latency.R`.
  - Next action: either harden the probe to split output-delivery/Plotly-afterplot/readiness timing per action, or choose a narrower output-render experiment that can be falsified by the valid real-click probe.

- 2026-07-30 Tranche E (probe hardening before next product-code branch):
  - Local hypothesis: the valid real-click baseline may still be under-instrumenting actual Plotly readiness because `output_snapshot()` counted only matching descendants. If a Plotly widget is mounted on the output root, the probe reports `output_widget_count = 0` while still declaring readiness from nonempty text.
  - Cheap disconfirming check: parse the probe and rerun the same single-action probe with the hardened output snapshot; if plot actions still pass and now show Plotly/widget counts, the previous output readiness windows are more trustworthy. If plot actions become PARTIAL/timeout, the prior baseline was too text-biased.
  - Probe changes:
    - Count selector matches on the output root as well as descendants.
    - Add per-output fields: `output_plotly_node_count`, `output_plotly_main_svg_count`, `output_plotly_svg_container_count`, `output_loading_indicator_count`, and `output_plotly_afterplot_count`.
    - Track `plotly_afterplot` by nearest output/root ID in the browser observer.
    - Require plot outputs to have a widget/Plotly marker instead of treating nonempty text alone as visible-ready.
    - Reuse the hardened readiness predicate for stale-output checks.
  - Validation after edit:
    - Parse marker: `PARSE_OK_BRANCH_G_SINGLE_ACTION_PROBE_PLOTLY_SNAPSHOT` after the root/output counter edit.
    - Parse marker: `PARSE_OK_BRANCH_G_SINGLE_ACTION_PROBE_PLOTLY_READY` after readiness predicate and CSV-row propagation.
    - `get_errors` found no diagnostics for the probe.
    - `git diff --check` and direct trailing-whitespace scan produced no output for the probe.
  - Next action: run label `step14_branch_g_single_action_plotly_ready_baseline` with the same canonical actions and runtime PERF enabled.
  - Hardened baseline result:
    - Label: `step14_branch_g_single_action_plotly_ready_baseline`.
    - Status: `PASS=11`.
    - Output CSV: `VP Clone/Logs/vp_perf_probe_single_action_latency_step14_branch_g_single_action_plotly_ready_baseline_20260730T171015Z.csv`.
    - Requested runtime log path: `VP Clone/Logs/vp_runtime_perf_single_action_step14_branch_g_single_action_plotly_ready_baseline_20260730T171015Z.jsonl` did not materialize.
    - Exact fallback runtime input: `VP Clone/Logs/vp_runtime_perf_proc_20260730T171032Z_40560.jsonl|VP Clone/Logs/vp_runtime_perf_96221a8012f7e368dc621348ccddaca8.jsonl`.
    - Runtime summaries: `VP Clone/Logs/vp_perf_runtime_summary_runtime_logs_20260730T171441Z_*.csv`.
  - Hardened baseline interpretation:
    - The prior `output_widget_count = 0` was a probe bug: final plot actions now report `output_widget_count=1`, `output_plotly_node_count=2`, and `output_plotly_main_svg_count=3`.
    - Commodity/hierarchy visible readiness remained fast: 58-98ms visible, with long full-idle tails for hierarchy actions.
    - Settled tab Plotly readiness clustered around 10.054-10.636s; tab while pending Historical Trend was 10.376s; return Current was 10.321s.
    - Runtime summary remained similar to the previous valid baseline: top timed rows were client tab/mount and startup; top churn was display-month mapping hits, map bottom-panel gated skips, year-filter sync, and summary table executions.
    - The evidence now supports treating the settled-tab delay as actual Plotly/widget materialization time, not merely text-based readiness.

- 2026-07-30 Tranche F (rejected hidden-render product-code branch):
  - Product experiment: add `outputOptions(output, "timeseries_plot", suspendWhenHidden = FALSE)` and `outputOptions(output, "heatmap_plot", suspendWhenHidden = FALSE)` after their cached `renderPlotly()` definitions in `VP Clone/Programs/app_source/server/05_trend_and_heatmap.R`.
  - Rationale: Historical Trend and Heatmap are not active-tab gated, unlike Map and Current; keeping their cached widgets materialized while hidden could reduce tab-switch Plotly readiness without rewriting active-tab gates.
  - Parse marker after edit: `PARSE_OK_BRANCH_G_TREND_HEATMAP_UNSUSPEND`.
  - Validation label: `step14_branch_g_plotly_ready_trend_heatmap_unsuspend`.
  - Result: rejected. Status counts regressed to `PARTIAL=11`; output CSV `VP Clone/Logs/vp_perf_probe_single_action_latency_step14_branch_g_plotly_ready_trend_heatmap_unsuspend_20260730T171627Z.csv`; fallback runtime input `VP Clone/Logs/vp_runtime_perf_proc_20260730T171633Z_20076.jsonl|VP Clone/Logs/vp_runtime_perf_e7cb62c61a36462c5b8acb2fb15f1b4e.jsonl`.
  - Failure details:
    - Early hierarchy/filter full-idle failed repeatedly.
    - Segment and commodity actions hit visible-ready timeouts or very slow readiness.
    - Historical Trend, Map, and Current settled tab actions hit visible-ready timeouts; Heatmap improved modestly to 9.130s but still PARTIAL.
    - Later tab-while-pending and return-current rows improved visible readiness to 2.451s and 3.377s, but this was not acceptable because the branch destabilized every row.
  - Outcome: reverted both `outputOptions()` lines.
  - Revert validation: `get_errors` clean for `05_trend_and_heatmap.R`; parse marker `PARSE_OK_BRANCH_G_TREND_HEATMAP_UNSUSPEND_REVERTED`.
  - Decision: do not use broad hidden-output warming as the next accepted optimization. It shifts work into filter/hierarchy paths and destabilizes idle/readiness.

- 2026-07-30 Post-closeout diagnostic note (marketing-year start / display-month mapping question):
  - User question: to what extent could determining the start of marketing years be driving wait/idle times, and should that work move to the data pipeline if it has not already?
  - Evidence read after Branch G closeout:
    - Almond marketing-year start metadata is already config-backed in `VP Clone/System/Config/commodity_contract.R`; Census and PSD both define `market_year_start_month = 8L`.
    - VP artifact contracts and probe helpers already expect processed calendar/display fields including `market_year`, `analysis_month`, `MonthNum`, `month_abbrev`, `month_name`, and `calendar_signature`.
    - Runtime `current_display_month_mapping()` in `VP Clone/Programs/app_source/server/03_core_reactives_and_ui.R` does not recompute marketing years from raw dates. For `vp_trade`, it derives a 12-row display-month mapping from processed VP rows and caches it by source, trade flow, hierarchy resolution, commodity-name/detail context, and fallback year type.
    - Prior Branch C evidence remains relevant: `calendar_signature` varies by trade, group, subgroup, market segment, and some commodity-name contexts, so broad display-month shortcuts are unsafe without a narrow key.
  - Branch G runtime interpretation:
    - The hardened baseline churn summary shows display-month mapping is touched frequently, mostly as cache hits: 33 hits on Current vs. Average, 19 on Map, 6 on Historical Trend, and 2 on Heatmap.
    - Misses were much lower: 8 `display_month_mapping_cache_miss` rows and 8 `filter_vp_rows_for_resolved_hierarchy_display_month_mapping` rows in the same fallback runtime summary.
    - Timed evidence does not identify display-month mapping as a primary elapsed-time bucket. All `filter_vp_rows_for_resolved_hierarchy()` purposes together totaled about 3.2285s, while Branch G tab Plotly/widget readiness remained near 10s per settled tab action.
  - Decision:
    - Marketing-year/display-month mapping may contribute to full-idle churn and should remain on the residual repeated-use list, especially together with year-filter sync and summary-table activity.
    - Current evidence does not support it as the main driver of the 10s-class tab output readiness found by Branch G.
    - Do not make a broad marketing-year-start pipeline migration the next product-code branch based only on Branch G. The start-month rule is already largely pipeline/config-backed; the remaining runtime issue is context-specific display-month lookup.
    - If pursued, the safer next branch is a narrow, evidence-gated optimization: instrument or precompute a keyed display-month mapping lookup by the same context dimensions currently used by `current_display_month_cache_key()`, rather than replacing the app logic with a single global month-start rule.

## Summary

Branch G is closed as a measurement and investigation tranche. The accepted change is a new single-action probe, `VP Clone/System/Testing/vp_perf_probe_single_action_latency.R`, plus this source-of-truth plan update. No product-code performance branch was accepted, because each tested product-code idea either made tab readiness worse or destabilized interaction readiness.

The probe now measures the app closer to manual use: it clicks real tab anchors, records one row per action, separates visible readiness from client interactivity and full Shiny idle, captures final selected state, and reports Plotly/widget readiness instead of relying on generic nonempty output text. The hardened valid baseline, `step14_branch_g_single_action_plotly_ready_baseline`, passed 11/11 rows and confirmed that the earlier `output_widget_count = 0` readings were a probe bug. Final plot outputs now show widget and Plotly markers.

The main finding is that the tab shell is not the slow part. Real tab clicks and client tab paint events are cheap, but the plot output becoming truly ready is still about 10 seconds for settled Historical Trend, Heatmap, Map, and Current tab actions in the hardened probe. Commodity and hierarchy visible readiness were fast in this canonical run, but hierarchy/filter actions still had long full-idle tails, so background reactive drain remains real even when the visible output looks ready.

Post-closeout review of the marketing-year/display-month path found that marketing-year start metadata is already mostly config/pipeline-backed, and VP artifacts already carry the processed month fields used by the app. The remaining runtime work is context-specific display-month lookup and cache reuse, not raw marketing-year-start determination. Display-month mapping appears as frequent churn in Branch G runtime logs, mostly cache hits, but timed evidence does not make it the primary explanation for the 10s-class tab readiness delay. It remains a reasonable narrow full-idle-churn candidate only if future evidence points there.

Three product-code experiments were rejected and reverted. Removing `Plotly.redraw()` made settled tab readiness worse. Gating hidden Pace default-target work caused partial rows and timeouts. Keeping hidden Trend/Heatmap Plotly outputs unsuspended caused every probe row to become PARTIAL, with visible-ready timeouts and idle failures, even though a couple of later tab rows improved. The next branch should not warm broad hidden outputs; it should target either the near-10s Plotly/widget materialization delay directly or a narrower full-idle churn source such as summary/display-month/year-filter work.

Final validation passed for the accepted files: probe and touched server file parsed, `get_errors` found no diagnostics for the daughter plan/probe/final server file, `git diff --check` produced no output for accepted Branch G files, and the rejected app-code experiments have no remaining source diff.