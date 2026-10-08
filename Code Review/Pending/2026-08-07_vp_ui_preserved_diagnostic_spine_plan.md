# VP UI-Preserved Diagnostic Spine Plan

Date: 2026-08-07
Status: Pending / handoff-ready. This plan is ready to become the implementation source of truth when work begins.
Branch: main
Repository: VP-Shiny

## Handoff Summary

This plan defines a parallel, opt-in VP diagnostic execution spine behind the current Shiny UI. The current UI is the product contract: same visible layout, tabs, labels, top bar, sidebar, defaults, and workflows. The rebuild target is the server/data execution path underneath it.

The first viable diagnostic slice must be rollup-correct Current vs Historical plus Summary Statistics. Rollups are not a late add-on; they are required for proper AP behavior and analyst experience. The diagnostic path should start deliberately simple and attributable, then reintroduce caches, provider partitions, sidecars, and readiness optimizations one layer at a time.

The current production app remains the oracle until the diagnostic spine passes UI parity, rollup-correct output parity, cache/provider isolation, performance attribution, soak, and manual gates.

The final goal is not to maintain two app spines forever. The final goal is a cleanly separated, well-attributed, fast AP that is optimized for performance behind the same UI. The old tangled production path should be retired surface by surface only after the replacement path proves correctness, attribution quality, performance, soak stability, manual usability, and rollback safety.

## Non-Negotiable Product Contract

- Preserve the current UI exactly unless the user explicitly approves a visible change.
- Do not remove, rename, reorder, hide, or simplify visible tabs.
- Do not change top bar layout, labels, defaults, or control order.
- Do not change sidebar layout, labels, defaults, or control order.
- Do not cut analyst workflows as a temporary implementation shortcut.
- Do not make the diagnostic mode visible in the UI; mode must be visible in telemetry and manifests instead.
- Keep the current production/default app path available and unchanged until promotion gates pass.

## Core Decisions

- Diagnostic mode is opt-in, fail-closed, immutable for a session, and distinguishable in telemetry and manifests.
- The first diagnostic output is Current vs Historical plus Summary Statistics with rollup-correct all-selection behavior.
- First-slice rollups use the current full artifact's embedded rollup rows. Sidecar or lazy rollup relocation is deferred until behavior parity exists.
- Production mode preserves existing provider/cache behavior. Diagnostic first slice forces direct rollup-correct filtering and treats provider use as a validation failure unless a later experiment explicitly changes that rule.
- Hybrid routing is allowed only as a UI-preservation tactic. Broad attribution claims require routed-surface isolation and cache/provider evidence.
- Existing probes and strict-evidence rules should be reused before creating a new harness, but probe and manifest schemas must carry execution mode.
- The diagnostic spine is a replacement candidate and measurement scaffold, not a permanent parallel product path. Every promoted diagnostic slice must name its retirement boundary: the old functions/reactives/cache paths it replaces, the temporary rollback path that remains, and the criteria for deleting or quarantining the old production code.

## Endgame And Retirement Strategy

The refactor should follow a strangler pattern rather than a demolition.

1. Build the diagnostic spine beside production.
2. Prove one rollup-correct behavior slice behind the same UI.
3. Optimize that slice inside the new spine until it is both well-attributed and fast enough for analyst use.
4. Promote that slice to the default production route behind a rollback flag.
5. Run parity, performance, soak, and manual validation through the promoted path.
6. Retire or quarantine only the old code for that promoted surface.
7. Repeat for Data, Trendlines, Heatmap, Map, and then the remaining tools.

Each promoted surface must have a retirement ledger entry with:
- New owner function/service/bundle.
- Old owner functions/reactives/output renderers/cache surfaces.
- Compatibility or rollback flag.
- Validation evidence required before default promotion.
- Validation evidence required before old-path deletion.
- Exact files and symbols that can be removed, quarantined, or left as oracle-only test helpers.

Do not leave diagnostic logic permanently as scattered `if diagnostic then ...` branches inside the old tangled spine. Temporary conditionals are acceptable during proof and parity work, but promoted slices should consolidate into named service boundaries so the old production path can be excised deliberately.

The desired endpoint is:
- Same AP UI.
- Rollup-correct analyst behavior.
- Clean service boundaries for data selection, rollup resolution, Current vs Historical bundles, tab data payloads, and rendering inputs.
- Explicit attribution at each major boundary.
- Performance layers that are intentional, measured, and removable.
- No hidden reliance on the legacy provider/cache/reactive tangle for promoted surfaces.

## Phase Plan

### Phase 0: Ledger And Branch Rules

1. Promote this pending file to the active implementation ledger when work begins.
2. Record that UI preservation is non-negotiable.
3. Record that the current app remains the correctness oracle and production/default path.
4. Record that diagnostic mode is opt-in only until parity, performance, soak, and manual gates pass.
5. Do not make source-code edits before the active ledger exists.

### Phase 1: Static And Dynamic UI Contract

Inventory and freeze the UI contract before execution-path changes.

Required contract surfaces:
- `Programs/app_source/ui.R` as the primary static UI contract.
- `Programs/app_source/server/02_partner_and_notes.R` dynamic UI renderers, especially `output$data_frequency_ui`, `output$market_year_compare_filters_ui`, and `output$main_tabs`.
- Client readiness message channels and tab/profile readiness telemetry.

The active ledger must include a dynamic UI appendix with:
- Canonical visible tab titles.
- Internal tab `value` strings.
- Required input/output IDs.
- Default selections.
- Control order.
- Choice-hydration rules for `vp_group_choice`, `vp_subgroup_choice`, `vp_market_segment_choice`, `vp_commodity_name_choice`, `commodity_choice`, and `country_choice`.

Required IDs to preserve include:
- `main_tabs`
- `data_source_choice`
- `vp_trade_flow_choice`
- `vp_group_choice`
- `vp_subgroup_choice`
- `vp_market_segment_choice`
- `vp_commodity_name_choice`
- `vp_reset_hierarchy_filters`
- `commodity_choice`
- `country_choice`
- `comparison_plot`
- `summary_table`
- `timeseries_plot`
- `heatmap_plot`
- `map_plot`
- `raw_data_table`

### Phase 2: Mode Bootstrap And Isolation Contract

Add an opt-in mode such as `VP_DIAGNOSTIC_SPINE=true`, `options(vp_diagnostic_spine = TRUE)`, or an equivalent local app/probe flag.

Rules:
- Read and freeze mode before diagnostic-sensitive startup work.
- Prefer app/bootstrap-level mode resolution before global/server initialization can warm caches or provider state.
- Runtime mode switching is out of scope.
- Default behavior must remain production.
- Diagnostic mode should reuse the current UI shell and dynamic UI builders.
- If a UI clone becomes unavoidable, clone the UI structure exactly and gate it with parity checks.
- Every runtime PERF event, probe output row, acceptance manifest row, and decomposition input row must carry `vp_execution_mode = production|diagnostic` or an equivalent field.

Recommended first technical spike:
- Add mode bootstrap.
- Propagate execution mode through one startup probe row.
- Propagate execution mode through one runtime PERF event.
- Validate this before output routing.

### Phase 2.5: Current Vs Historical Rollup Behavior Contract

Before implementing diagnostic Current vs Historical behavior, inventory the current production behavior and record it as the oracle contract.

Required behavior contract:
- Strict all-selection paths.
- Native row vs embedded rollup row precedence.
- Mixed-volume replacement.
- `All` vs `All - excluding juice` behavior.
- Unit Value hiding and availability.
- Country and all-country behavior.
- Display-month labels and order.
- Duplicate collapse rules.
- Projection/reference-year semantics if relevant.
- Fallback behavior.

Required pre-render comparison artifacts:
- Comparison plot data before Plotly construction.
- Summary table rows.
- Monthly values.
- Accumulated/YTD values.
- Display-month mapping.
- Selected hierarchy labels.
- Unit Value visibility and NA behavior.
- Rollup decision metadata.

Define a single Current vs Historical diagnostic bundle consumed by both `comparison_plot` and `summary_table`.

Required bundle fields:
- Resolved hierarchy context.
- Selected commodity/type/detail/country context.
- Current monthly series.
- Historical monthly series.
- Historical average/range inputs.
- Summary table rows.
- Display-month mapping.
- Unit Value flags.
- Rollup decision metadata.
- Timing metadata.

### Phase 3: Minimum Rollup-Correct VP Data Spine

Build a direct, transparent, rollup-correct data spine behind diagnostic mode.

Rules:
- Load the validated VP trade artifact through the existing startup/source contract.
- Preserve fail-closed `vp_trade` source policy.
- Use the current full artifact's embedded rollup rows for the first slice.
- Keep artifact schema and rollup contract assertions active.
- Preserve current rollup/native precedence semantics for all-selection contexts.
- Use existing canonical hierarchy helpers where safe: `canonicalize_vp_hierarchy_selection`, `resolve_vp_hierarchy_tokens`, and the minimum required logic currently inside `filter_vp_rows_for_resolved_hierarchy`.

Add a mode-aware dispatcher at the hierarchy filtering seam:
- Production mode preserves existing provider decision logic.
- Diagnostic first slice forces the direct branch.
- Each call logs mode, provider attempted, provider used, direct used, row counts, elapsed time, and fallback reason.
- Provider calls during first-slice diagnostic attribution are validation failures unless explicitly marked as a later experiment.

Time at least:
- Artifact/source load.
- Hierarchy resolution.
- Native row filtering.
- Rollup row selection.
- Country/type filtering.
- Output data assembly.

### Phase 4: Current Vs Historical First

Route Current vs Historical plus Summary Statistics through the diagnostic bundle first.

Rules:
- `comparison_plot` and `summary_table` must consume the same diagnostic bundle.
- Do not allow separate diagnostic reconstruction paths for plot and summary table.
- Validate strict all-selection paths, mixed-volume/all-excluding-juice behavior, Unit Value suppression/availability contracts, and country/all-country behavior in this first output slice.
- Do not introduce broad `bindCache`, provider partition calls, sidecar reads, hidden-output warming, or broad readiness changes in this phase.

Data tab follows only after Current vs Historical parity passes.

Data tab parity must include:
- Row counts.
- Visible hierarchy display columns.
- Native-label backfill.
- Rollup-token normalization.
- Fallback behavior when native lookup misses.

Unrouted tabs:
- Keep all tabs visible and in the same order.
- Recommended default: unrouted tabs continue using current production server paths for UI preservation.
- Classify this as UI-preservation hybrid mode only.
- First-slice attribution claims apply only to routed Current vs Historical/Summary work after unrelated production-path background activity is logged, isolated, or excluded.

### Phase 5: Attribution Before Speed Features

Add low-noise function boundary timings before optimization.

Every diagnostic-spine timing row should include enough fields to join by:
- Execution mode.
- Tab.
- Source.
- Hierarchy path.
- Commodity.
- Country.
- Unit/display mode.
- Cache/provider state.
- Action ID.
- Output ID.
- Current vs Historical bundle ID.

Avoid high-volume instrumentation until perturbation is checked.

### Phase 6: Cache, Provider, And Hybrid Routing Matrix

Before first timing claims, add a cache/provider matrix to the active ledger.

Required rows:
- Provider partition disk/memory cache.
- `bindCache` for filtered data.
- Comparison plot cache.
- Summary table cache if present.
- Hierarchy/context caches.
- Display-month mapping cache.
- Runtime/probe cache-state labels.
- Any diagnostic bundle cache.

For each layer record:
- Production behavior.
- Diagnostic first-slice behavior.
- Whether keys include execution mode.
- Whether the layer is bypassed or timed.
- Acceptance rule.

First-slice defaults:
- Provider cache bypassed.
- Broad `bindCache` bypassed or mode-keyed.
- Comparison output cache bypassed initially.
- Hierarchy/context cache either bypassed or explicitly timed and mode-keyed.
- Diagnostic runs must not silently reuse warmed production cache state.

### Phase 7: First-Slice Parity And Correctness

Run UI parity checks against production/default mode and diagnostic mode using existing smoke/probe patterns.

Validate:
- Visible tabs.
- Tab order.
- Labels.
- Top bar.
- Sidebar.
- Default selections.
- Required controls.
- Hierarchy/sidebar choice hydration.

Required fixed scenarios:
- Default.
- `Dry pulses / Dried beans / Dried`.
- Strict all-selection paths.
- Specific commodity/country.
- All-country.
- Type `All`.
- At least one mixed-volume case.
- At least one context where Unit Value should be hidden or transformed.

Compare:
- Pre-render plot data.
- Summary table rows.
- Monthly values.
- Accumulated/YTD values.
- Display month labels/order.
- Selected hierarchy labels.
- Unit Value visibility/NA behavior.
- Rollup decision metadata.
- Row counts.
- Key columns.
- Labels/tokens.
- Sorted row hashes where practical.
- Numeric aggregates with explicit tolerance only where needed.

### Phase 8: Expand One Output Family At A Time

Expansion order:
1. Historical Trendlines, only after rollup-correct Current vs Historical/Summary parity and Data row-inspection parity pass.
2. Monthly Heatmap after Trend parity passes.
3. Map after Heatmap parity passes.
4. Custom Comparison Tool, Market Year Comparison Tool, and Pace only after core VP Current/Data/Trend/Heatmap/Map spine is stable.

After each output family, rerun focused parity, correctness, cache-isolation, and attribution checks before widening.

### Phase 9: Generalize And Optimize Rollup-Correct Semantics

Rules:
- Keep the current full artifact as the oracle for all-selection semantics.
- Do not delete production rollups.
- Do not ship native-only or minimal-rollup artifacts as correctness candidates.
- After Current vs Historical proves the rollup-correct pattern, classify each additional diagnostic output context as native-only-safe, strict-rollup-required, mixed-volume-required, country/all-country-required, or cross-commodity-required.
- Preserve rollup correctness as each output family is routed.
- Time rollup selection/materialization separately from native filtering.
- Treat rollup bulk as a startup/artifact-load lever, but relocate or lazily load rollups only after the behavior-correct direct spine exists.

### Phase 10: Reintroduce Performance Architecture One Layer At A Time

Order:
1. Compare rollup-correct direct filtering with no cache/provider layers against the current app and record the cost baseline.
2. Add one cache layer only after direct-spine attribution is stable.
3. Add provider/partition behavior only after cache impact is understood.
4. Consider commodity native partitions and rollup sidecars only after the diagnostic spine proves which contexts need which data and bundle currentity/manifest rules are specified.

For every performance layer require:
- Rollback flag.
- Mode telemetry.
- Parity checks.
- Cache-isolation checks.
- Focused performance evidence.

### Phase 11: Acceptance, Soak, And Promotion Decision

Run strict production/default versus diagnostic/candidate acceptance pairs only after core output parity passes.

Keep these claims separate:
- Startup.
- Hierarchy/action.
- Tab-only.
- Manual usability.

Before promotion, run repeated-action soak for:
- Commodity switches.
- Hierarchy changes.
- Country changes.
- Tab switches.

Inspect:
- Memory watermark.
- Cache growth.
- Fallback rate.
- Execution-mode drift.
- Latency slope.

Promotion options:
- Keep diagnostic-only.
- Merge selected layers into production.
- Replace current server spine behind the same UI.
- Stop and preserve findings only.

### Phase 12: Legacy Spine Retirement

Run this phase only after a routed surface has been promoted and survived its validation window.

For each promoted surface:
1. Confirm the new spine owns the production route by default.
2. Confirm rollback flag behavior still works or explicitly record that rollback is no longer needed.
3. Re-run focused parity and manual checks after the rollback decision.
4. Identify old functions, reactives, observers, cache keys, provider hooks, and output renderers that are now unused by the promoted surface.
5. Classify each old component as deletable, quarantine-as-oracle, shared-still-needed, or deferred-risk.
6. Delete only the components classified as deletable.
7. Move any oracle-only helpers out of runtime execution paths or clearly mark them as test/diagnostic-only.
8. Re-run parse checks, focused probes, cache/provider isolation checks, and manual surface validation.

Retirement order should follow proven promotions:
1. Current vs Historical and Summary Statistics.
2. Data.
3. Historical Trendlines.
4. Monthly Heatmap.
5. Map.
6. Custom Comparison Tool.
7. Market Year Comparison Tool.
8. Pace Analysis Tool.

Old-spine retirement is successful only when the promoted surface no longer depends on the old tangled provider/cache/reactive path for routine production behavior and the remaining old code is either removed, quarantined as oracle/test support, or explicitly documented as still shared.

## Relevant Files

- `VP_Analysis_Shiny.R` - app entry point that sources global, UI, and server modules; likely mode bootstrap location.
- `Programs/app_source/ui.R` - primary static UI contract, client readiness JavaScript, message handlers, shell placeholders, and tab/profile readiness telemetry.
- `Programs/app_source/global.R` - VP startup artifact load, rollup contract validation, provider toggles, partition-provider functions, runtime PERF helpers, and startup source utilities.
- `Programs/app_source/server/02_partner_and_notes.R` - top-bar hierarchy owner, dynamic sidebar wrapper, source pinning, map source data, main tabs renderer, hierarchy canonicalization/token resolution, current `filter_vp_rows_for_resolved_hierarchy` path, and readiness recovery handlers.
- `Programs/app_source/server/03_core_reactives_and_ui.R` - `filtered_data_for_country`, `filtered_data`, `historical_avg`, country controls, and shared Current/Data surfaces.
- `Programs/app_source/server/04_comparison_plots.R` - Current vs Historical comparison plot, summary table, comparison cache surfaces, and first output family to route through the direct spine.
- `Programs/app_source/server/05_trend_and_heatmap.R` - Historical Trendlines, Monthly Heatmap, Map plot, Data tab dataset/table, and later routing targets.
- `Programs/app_source/server/06_pace_analysis_and_reset.R` - Pace/reset surfaces; defer routing until core VP spine stabilizes.
- `System/Config/vp_contract.R` - VP-only source contract and fail-closed startup policy to retain.
- `Programs/Build_App_UI_Metadata.R` - UI metadata build path; preserve unless a later phase explicitly proves metadata drift.
- `System/Testing/vp_shinytest_smoke.R` - broad UI/data smoke and parity markers.
- `System/Testing/vp_perf_probe_startup.R` - startup readiness and target-tab checks.
- `System/Testing/vp_perf_probe_single_action_latency.R` - tab-only/canonical action readiness and client materialization timing.
- `System/Testing/vp_perf_probe_hierarchy_sidebar_cascade.R` - hierarchy/sidebar readiness and dependent choice hydration gate.
- `System/Testing/vp_perf_probe_vp_filters.R` - direct VP filter scenarios and row-count checks.
- `System/Testing/vp_perf_probe_artifact_load.R` - artifact load, schema, and serialization decomposition.
- `System/Testing/vp_perf_probe_vp_mixed_quantity_sanity.R` - mixed quantity/unit-family correctness guard.
- `System/Testing/vp_perf_probe_display_month_signature_variance.R` - display-month/calendar signature drift guard.
- `System/Testing/vp_perf_run_acceptance_pair.R` - strict paired production/candidate performance runner.
- `System/Testing/vp_perf_acceptance_decision.R` - statistical decision and threshold reporting.
- `System/Testing/vp_perf_acceptance_manifest.R` - manifest, context, and runtime-identity validation helpers.
- `System/Testing/vp_perf_summarize_runtime_logs.R` - runtime JSONL summarizer; use exact emitted/fallback paths.
- `System/Testing/vp_perf_decompose_single_action_8c.R` and Step 25 helper scripts - decomposition/ownership views for action-window attribution after strict runs.

## Verification Checklist

1. Ledger hygiene: after creating or editing the active plan, run `git diff --check -- "Code Review/Pending/2026-08-07_vp_ui_preserved_diagnostic_spine_plan.md"` or the promoted active-plan path.
2. Parse checks: after each R edit, run `C:/Program Files/R/R-4.5.1/bin/Rscript.exe -e "parse(file='path/to/file.R'); cat('PARSE_OK_<label>\n')"` for touched R files.
3. Static diagnostics: use editor diagnostics for touched files after parse passes; interpret known Shiny/global-symbol noise only after executable checks pass.
4. Mode bootstrap verification: prove diagnostic mode is read before diagnostic-sensitive startup work, is immutable for the session, defaults to production, and appears in runtime PERF events, probe CSV rows, manifest rows, and decomposition inputs.
5. Baseline UI contract: run existing production/default `vp_shinytest_smoke.R`, `vp_perf_probe_startup.R`, `vp_perf_probe_hierarchy_sidebar_cascade.R`, and `vp_perf_probe_single_action_latency.R --scenario=canonical` before diagnostic routing claims.
6. Dynamic UI parity: with diagnostic mode enabled, assert same top/sidebar controls, tab list/order, internal values, visible labels, default selections, required controls, and hierarchy/sidebar choice hydration.
7. Rollup contract verification: before implementing the first diagnostic output, capture oracle values for strict all-selection paths, mixed-volume contexts, `All - excluding juice`, Unit Value hide/show behavior, country/all-country behavior, display-month labels/order, plot pre-render data, and summary table rows.
8. First diagnostic correctness: run rollup-correct direct filter, artifact load, mixed quantity, display-month signature, and focused Current vs Historical/Summary output comparisons against production/default mode before routing Data.
9. Cache/provider isolation: prove diagnostic first-slice runs do not use provider partition paths or warmed production cache state unless the plan has explicitly moved to a later performance-architecture experiment.
10. Runtime attribution: summarize only exact runtime JSONL paths printed by probes; if requested paths do not materialize, record exact fallback paths before summarizing.
11. Performance evidence: keep `cold_artifact`, `warm_partition_disk`, and `warm_session` lanes separate; reject `unknown_cache_state` for acceptance claims.
12. Strict acceptance: when ready, use `vp_perf_run_acceptance_pair.R` with clean-room manifest, strict manifest validation, strict context validation, strict runtime identity, deterministic fixtures, explicit execution-mode validation, and PASS-only evidence.
13. Decomposition: after strict pairs, run manifest-to-inventory, Step 25B, Step 25C, Step 25D, and 8I ownership/materialization views only from exact accepted artifacts.
14. Soak: before any production promotion, run repeated action sequences for hierarchy, commodity, country, and tab switches; inspect memory watermark, cache growth, fallback rate, execution-mode drift, and latency slope.
15. Manual validation: after each routed output family, manually inspect the same current UI: defaults, hierarchy path, reset, Current vs Historical, Summary Statistics, Data, Trendlines, Heatmap, Map, CCT, MYC, and Pace as relevant.
16. Retirement validation: before deleting old-spine code for a promoted surface, record the retirement boundary, prove the promoted path owns production behavior, verify rollback/quarantine status, run focused probes, and repeat manual validation after deletion.

## First Implementation Spike Recommendation

Start with the smallest non-behavioral spike:

1. Add diagnostic mode bootstrap.
2. Freeze execution mode for the app session.
3. Propagate execution mode through one runtime PERF event.
4. Propagate execution mode through one startup probe row.
5. Add the retirement-boundary ledger template for future promoted slices.
6. Validate default production behavior is unchanged.

Do not route Current vs Historical until this bootstrap and telemetry foundation is proven.

## Final Summary

This plan intentionally does not start by redesigning the visible app. It keeps the current AP UI as the product and rebuilds only the execution path underneath it. The first real behavior slice is Current vs Historical with rollups, because rollups are central to analyst use and correct all-selection behavior. The diagnostic spine should initially be slow if necessary, but it must be explainable: each major data and rendering step should be attributable before performance layers are reintroduced.
