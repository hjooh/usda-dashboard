# VP Branch J: VP-Only Source-State Cleanup Plan

Date: 2026-07-31
Branch: main
Status: Branch J closeout complete. J-1 through J-7 and J-2a are accepted after automated validation and user manual validation. J-1R/J-1.5 source-authority/profile experiments remain rejected/reverted with no retained source diff. The delegated hierarchy/sidebar cascade readiness blocker is accepted in `VP Clone/Code Review/2026-08-01_vp_branch_j_hierarchy_cascade_readiness_plan.md` after probe-side target-membership waits, automated gates, and user manual validation on 2026-08-01. J-2b comparison-cache retry is deferred/not recommended because prior comparison-cache experiments regressed readiness and no new J-2a evidence justified reopening that risk.
Parent ledger: `VP Clone/Code Review/2026-07-29_vp_performance_hotspot_recovery_plan.md`

## Purpose

Branch J is a source-state cleanup branch for the VP Shiny app. The app's runtime product scope is now clarified: the current VP app ingests and displays the VP CSV-derived trade data only. PSD, NASS, Census, Hybrid, WASDE, and other source-switching paths are clone remnants unless they are actively supporting a visible VP tab.

The purpose is to remove hidden/dead multi-source machinery that can contribute avoidable reactive churn, cache-key churn, source-shell refresh work, and stale-output guard work while preserving the visible VP application exactly as it exists today.

This is not a feature-removal branch. Every visible tab, top-bar control, sidebar control, label, layout, and workflow must remain intact unless a later explicit user decision changes that requirement.

## Guardrails and Product Invariants

These are hard gates for implementation and adversarial review. They mirror the parent plan's bias toward measured, scoped tranches and add Branch J-specific UI preservation rules.

- Keep Branch J VP-scoped. Do not preserve PSD/NASS/Census/Hybrid/WASDE behavior as product behavior unless a local trace proves that branch supports a visible VP workflow.
- Measure before optimizing. Record baseline, pass-level validation, manual confirmation, and closeout evidence before advancing to the next pass.
- Prefer small tab-scoped passes over broad source-state rewrites.
- Do not start with observer deletion. Source authority, fixed hidden ghost input behavior, tab profile logic, and active cache keys must stabilize first.
- Preserve direct-filter fallback and Provider v3 manifest/source identity protections.
- Do not use user-facing loading polish as a substitute for removing avoidable source-state churn.
- Add rollback/disable shims where needed, but prefer minimal VP-only compatibility shims over restoring multi-source behavior.
- Do not carry a known manual regression across a Git checkpoint.

- The visible top bar format, order, labels, defaults, and behavior must be preserved:
  - Group
  - Subgroup
  - Market Segment
  - reset button
  - Commodity
  - Trade Flow
  - Data Frequency
- The visible sidebar format, controls, labels, defaults, and behavior must be preserved.
- All visible tabs must remain present, in the same order, with the same user-facing titles and functions:
  - Current vs. Historical
  - Historical Trendlines
  - Map
  - Monthly Heatmap
  - Data
  - Custom Comparison Tool
  - Market Year Comparison Tool
  - Pace Analysis Tool
- Internal tab values must also be preserved because server logic, client JavaScript, and probes use these values:
  - `Current vs. Average`
  - `Historical Trend`
  - `Map`
  - `Heatmap`
  - `Data`
  - `Custom Comparison Tool`
  - `Market Year Comparison Tool`
  - `Pace Analysis Tool`
- The app must continue to display the ingested VP data on every visible tab.
- VP Provider v3 source identity, VP hierarchy tokens, source provenance protections, and partition-provider integrity must be preserved.
- The hidden `data_source_choice` DOM/input node must not be fully removed in the first Branch J implementation. Branch J should retain a fixed hidden VP-only ghost input with the single value `vp_trade` while moving server authority to contract-backed helpers.

## Working Hypothesis

Because `System/Config/vp_contract.R` enables only `vp_trade`, active PSD/NASS/Census/Hybrid/WASDE source branching is dead product state for this app and likely contributes avoidable reactive invalidation, cache-key churn, and tab/source-shell work.

A cheap falsifying check is a baseline/post pair using the existing single-action and hierarchy-sidebar probes. If cleanup removes source churn but does not improve, preserve, or clarify readiness/correctness, then source-state machinery is not the controlling bottleneck. In that case Branch J can still close as cleanup/attribution-only if visible VP behavior is preserved and dead machinery is safely removed.

Branch J does not need to solve the 9-10 second Plotly/htmlwidget readiness issue to be successful. If tab readiness remains slow after source churn is reduced, the next branch should target Shiny/htmlwidget delivery/output settling.

## Source-Of-Truth Ledger Contract

- This file is the source-of-truth implementation ledger for Branch J once the parent plan delegates the branch.
- The parent plan remains the broad VP performance-recovery ledger and must be updated at Branch J closeout with outcome, output paths, validation markers, residual risk, and next recommended target.
- The active J-1R hierarchy/sidebar cascade blocker is delegated to `VP Clone/Code Review/2026-08-01_vp_branch_j_hierarchy_cascade_readiness_plan.md`. Keep detailed hierarchy-cascade diagnosis, probe readiness refinements, instrumentation notes, rejected H-pass approaches, and acceptance evidence in that grand-daughter plan until the blocker is resolved.
- Update this daughter ledger after every pass before moving to the next pass.
- Record files touched, parse markers, commands/probes, benchmark labels, output paths, PERF summaries, cache-state labels, manual validation notes, Git checkpoint status, bugs, blockers, failed attempts, rejected approaches, and decision gates.
- Keep implementation chat brief; detailed progress belongs in this file.
- Do not create a paired results markdown file unless explicitly requested.
- Preserve prior evidence append-only. Reopened J-0/J-1/J-2 work must add new rows, labels, runtime summaries, notes, and conclusions rather than overwriting or reinterpreting the accepted J-0 through J-7 records.

## Baseline Audit Findings

- The VP contract enables only `vp_trade`; all non-VP source pathways are clone remnants unless locally proven to support a visible VP workflow.
- The current visible app has eight VP data tabs that must remain visible and functional: Current vs. Historical, Historical Trendlines, Map, Monthly Heatmap, Data, Custom Comparison Tool, Market Year Comparison Tool, and Pace Analysis Tool.
- Visible tab titles and internal tab values differ for at least Current vs. Historical / `Current vs. Average` and Monthly Heatmap / `Heatmap`. Both are contracts.
- Client JavaScript and several probes still query or set `data_source_choice`; full DOM removal is unsafe in Branch J.
- Hardcoded `export_sales` defaults remain in active server surfaces and can behave as shadow source contracts during startup/error fallback if not replaced carefully.
- `06_pace_analysis_and_reset.R` is high-risk because visible VP Pace/MYC workflows may still use clone-era helper names.
- Branch I evidence showed Trend/Heatmap server construction and raw complexity are not the main explanation for 9-10 second tab readiness, so Branch J should be judged on source-state cleanup and visible behavior preservation, not on solving Plotly readiness by itself.

## Critical Audit Amendments

These amendments are the result of pre-implementation review and must be treated as implementation constraints.

- Preserve visible tab titles and internal tab values separately. The screenshot's user-facing names are not always the internal `tabPanel(value=...)` strings used by `allowed_main_tabs_for_source()`, `target_main_tab_for_source()`, client readiness code, and probes.
- Do not fully remove the hidden `data_source_choice` DOM node in Branch J. Client JavaScript and several probes still query or set it directly. The safer target is a fixed hidden VP-only ghost input with one value, `vp_trade`.
- Treat hardcoded `export_sales` defaults as shadow source contracts. Replace active VP-path fallbacks with contract-backed `vp_trade` defaults through `runtime_default_source_choice()` / `current_source_choice_safe()` rather than leaving legacy defaults that can activate during startup or error recovery.
- Distinguish active logic from diagnostic logging. Replace direct `input$data_source_choice` reads where they control behavior, cache keys, tab eligibility, data paths, or helper branches. Diagnostic payloads may retain source fields only if they report the contract-backed VP source consistently.
- Treat `06_pace_analysis_and_reset.R` as high-risk. Visible VP Pace Analysis and Market Year Comparison behavior may use clone-era helper names. Preserve visible behavior first; only remove unreachable non-VP branches after a local trace proves the helper is not used by a visible VP workflow.
- Prefer tab-scoped cleanup passes over one broad source-state sweep. After each pass, stop for manual app validation of the affected visible tab(s), record the result in this ledger, and create a Git progress checkpoint if the pass is accepted.

## Scope

Included:
- VP-only source identity simplification.
- Dead source observer removal after source authority/cache/tab guards are stable.
- Cache-key thinning for active VP paths.
- Main-tab shell/profile simplification.
- Client-side stale-source/profile guard simplification where VP shell readiness remains protected.
- Probe updates required when `data_source_choice` becomes a fixed hidden VP-only ghost input.
- Tab-scoped manual validation and Git checkpoints after accepted passes.

Excluded:
- Visible UI redesign.
- Visible tab removal, visible control removal, visible label changes, visible tab reorder, or feature decommissioning.
- Broad artifact format changes.
- Provider v3 identity rewrites.
- Build-time aggregation tuning.
- Plotly/htmlwidget delivery rewrites.
- User-facing loading polish.
- Preserving PSD/NASS/Census/Hybrid/WASDE behavior as product behavior.
- Paired results markdown unless explicitly requested.

## Step Ledger

This table is the compact execution map. The detailed pass map and step notes below remain the implementation detail; this table records where each pass stands, what evidence controls it, and what must happen before moving on.

| Step | Phase | Work | Status | Evidence / Files | Gate / Next Action |
|---|---|---|---|---|---|
| J-0 | Ledger / baseline | Create Branch J daughter ledger, amend parent, capture baseline probes, and record tab title/value inventory | Complete | This plan and parent plan updated. Baseline parse markers clean. Branch J canonical baseline PASS=11; tab-only baseline PASS=4; hierarchy/sidebar baseline PASS. Runtime summaries generated from exact JSONLs. Performance baseline: canonical total 217199 ms; tab-only total 160504 ms; hierarchy/sidebar total 163540 ms; baseline tab visible-ready timings were Historical Trend 13360 ms, Heatmap 9755 ms, Map 14729 ms, and Current return 10196 ms. Source-remnant classification and tab inventory recorded below. No source-code cleanup has started. | Ready for J-1 source shell edits after user accepts the J-0 evidence. Pass 0 plan-only checkpoint is optional unless user requests it. |
| J-1 | Global shell | Source authority, runtime source defaults, fixed hidden VP-only `data_source_choice` ghost input, tab value/profile helpers, and top bar/sidebar no-visible-change baseline | Accepted | Touched `02_partner_and_notes.R` only. Parse checks clean. Startup PASS, tab-only PASS=4, hierarchy/sidebar PASS. Runtime summary generated. Performance summary: tab-only total increased from 160504 ms baseline to 200879 ms; hierarchy/sidebar total increased from 163540 ms to 204220 ms; hierarchy-change total increased from 61620 ms to 71051 ms. Top bar hidden source ghost input remains rendered through the original contract-backed helper path; server authority now returns fixed `vp_trade`. User manual validation accepted 2026-07-31. | Proceed to J-2. Automated timing regressed versus J-0, but the cleanup benefit and visible app behavior were accepted by the user for this pass. Git checkpoint still pending user action. |
| J-2 | Core shared surfaces | Current vs. Historical and Data shared filter/data surfaces | Accepted | Final source diff is limited to `03_core_reactives_and_ui.R`: `filtered_data_stable_cache_key()` no longer carries impossible Census/Hybrid/WASDE/NASS cache dimensions on the VP path. `04_comparison_plots.R` was explored but restored to no final diff. Parse checks clean. Canonical probe PASS=11. Targeted Data-tab smoke passed. Runtime summary generated. Performance summary: final canonical total was 319162 ms with first group visible-ready 15396 ms and Current return visible-ready 13184 ms; this is cache-key-sensitive correctness/attribution evidence, not a clean speed win. User manual validation accepted 2026-07-31. | Proceed to J-3. Performance comparison remains cache-key-sensitive and should not be treated as a clean speed regression/win without repeated settled-cache probes. Git checkpoint still pending user action. |
| J-3 | Trend / Heatmap | Historical Trendlines and Monthly Heatmap source fallback/cache-key cleanup | Accepted | Final source diff is limited to `05_trend_and_heatmap.R`: `historical_trend_plot_base_cache_key()` and its Trend/Heatmap `bindCache()` calls no longer carry impossible Census/Hybrid/WASDE/NASS cache dimensions on the VP path. Parse clean. Tab-only probe PASS=4, and settled rerun PASS=4. Runtime summary generated from exact settled fallback JSONLs. Performance summary: settled tab-only total was 200160 ms; visible-ready timings were Historical Trend 15286 ms, Heatmap 14392 ms, Map 16749 ms, and Current return 12071 ms. This did not show a speed win versus the J-0 tab-only baseline. User manual validation accepted 2026-07-31. | Proceed to J-4. Performance comparison remains cache-key-sensitive and should not be treated as a clean speed regression/win without repeated settled-cache probes. Git checkpoint still pending user action. |
| J-4 | Map | Map source fallback/cache-key/bottom-panel cleanup | Accepted | Final source diff is limited to `02_partner_and_notes.R`: `map_runtime_stable_data_cache_key()` no longer carries impossible Census/Hybrid/WASDE/NASS/PSD-only cache dimensions on the VP path. `04_comparison_plots.R` and Map render/body logic were inspected but not edited. Parse clean. Tab-only probe PASS=4, and settled rerun PASS=4. Runtime summary generated from exact settled fallback JSONLs. Performance summary: settled tab-only total was 194500 ms; Map visible-ready was 19615 ms, while Historical Trend was 15518 ms, Heatmap 12778 ms, and Current return 11865 ms. This remains slower than the J-0 tab-only baseline overall and does not establish a speed win. User manual validation accepted 2026-07-31. | Proceed to J-5. Performance comparison remains cache-key-sensitive and should not be treated as a clean speed regression/win without repeated settled-cache probes. Git checkpoint still pending user action. |
| J-5 | Custom Comparison | Custom Comparison Tool inherited-source cleanup | Accepted | Source diff covers `04_comparison_plots.R`, `03_core_reactives_and_ui.R`, `01_state_and_custom_types.R`, and `02_partner_and_notes.R`: Custom Comparison plot outputs now use a local `cct_runtime_source_choice()` wrapper around the canonical VP source authority for runtime source logging and overlay display helper calls, and VP panel commodity-name arguments no longer branch on the hidden `input$data_source_choice`. Manual-review follow-ups removed legacy "rice type" wording from the visible Custom Comparison right/top-right/bottom-left/bottom-right type dropdown labels and added Custom Comparison-only invalid Type / VP Commodity synchronization after hierarchy changes. The sensitive shared `comparison_plot_base_cache_key()` was intentionally left unchanged after prior J-2 readiness failures. Parse clean. Focused CCT-only `shinytest2` smoke passed: Custom Comparison opened, quick-apply title/button and VP panel commodity controls were present, and Apply Commodity synced right/grid panel commodity selectors using candidate `Asparagus`. Label follow-up parse passed and targeted text search found no remaining affected visible labels. Focused hierarchy-sync smoke passed: changing Group to Dry pulses moved VP Commodity from `Artichokes` to `Austrian winter peas`, left Type at `All`, and kept `hist_years` finite at `1`. User manual validation accepted 2026-07-31 with: "J-5 Seems fine. Let's continue". | Proceed to J-6. Git checkpoint still pending user action. |
| J-6 | MYC | Market Year Comparison Tool inherited-source cleanup | Accepted | Final source edit is limited to `Programs/app_source/server/02_partner_and_notes.R`: MYC cutoff trace payload, `partner_snapshot()`, MYC type-mode hybrid helper/display-map helper/leaf-set helper, `build_myc_comparison_basis_bundle()`, and `partner_share_data()` now use canonical `current_source_choice_safe()` instead of hidden `input$data_source_choice` as authority. `03_core_reactives_and_ui.R` and `06_pace_analysis_and_reset.R` were inspected but not edited in this tranche. Parse clean with `PARSE_OK_BRANCH_J_PASS6_MYC_SOURCE_CLEANUP` and final parse marker `PARSE_OK_BRANCH_J_PASS6_FINAL_MYC_SOURCE_CLEANUP`. Bounded MYC control/state smoke passed: `VP_MYC_SMOKE_J6_PASS=TRUE`, country-mode partner choices `19`, type-mode partner choices `2`, and cutoff value `5` in both modes. Over-broad plot/visibility readiness checks were intentionally not pursued because MYC is known slow/buggy and not fully tuned. User manual validation accepted 2026-07-31 with: "Great! J-6 looks fine to me." | Proceed to J-7. Git checkpoint still pending user action. |
| J-7 | Pace | Pace Analysis Tool inherited-source cleanup | Accepted | Source edits touched `06_pace_analysis_and_reset.R`, `05_trend_and_heatmap.R`, and `02_partner_and_notes.R`. Pace-owned PSD/WASDE target-source UI/state/default-target branches were removed, Pace plot/source labels now use canonical VP source authority, orphaned Pace-specific PSD/WASDE helper definitions were removed after call-site search proved no callers remained, and focused Pace smoke passed. User manual validation accepted 2026-08-01: Pace Analysis Tool seems to be working properly. | Proceed under reopened plan; J-0R is already complete and J-1R readiness/probe instability remains the active blocker. Git checkpoint still pending user action. |
| J-0R | Reopened baseline | Intermediate post-J-7/pre-reopen baseline, no source edits | Complete | B0 evidence appended. VP quantity sanity PASS. Canonical single-action baseline `PARTIAL=1|PASS=10` because first group-change visible-ready timed out; this is the current post-J-7/pre-reopen baseline state, not a source-change regression. Tab-only PASS=4. Hierarchy/sidebar PASS. Runtime summaries generated from exact printed fallback JSONLs. | Proceed to J-1R readiness/probe blocker resolution with B0 as the immediate comparison point. |
| J-1R | Reopened shell authority / readiness | Source authority hardening and top/sidebar readiness instability | Readiness accepted; source-authority experiments rejected | Two source-authority experiments and three readiness experiments were tried and reverted. Readiness investigation showed `country_choice`/`commodity_choice` required-control timeouts are a nested-sidebar-output scheduling issue, not primarily a country-sort computation issue. Unsuspending both nested sidebar outputs fixed required-control presence but worsened tab visible-ready timing. Commodity-only unsuspend preserved tab-only PASS=4 but broke the hierarchy cascade: final subgroup/segment stayed `__all__`. Grand-daughter H-1 automated evidence added target-membership waits to the hierarchy/sidebar and canonical probes with no product-source edit; startup PASS, tab-only PASS=4, canonical PASS=13, and hierarchy/sidebar PASS twice with final path `Dry pulses / Dried beans / Dried`. User manual validation accepted 2026-08-01: the app is functioning properly. | The hierarchy/sidebar readiness blocker is closed as probe-readiness repair, not product-source repair. Resume Branch J cleanup from the source-authority/J-1R decision point using the updated readiness probes. Keep the rejected source-authority edits out unless separately re-scoped. |
| J-1.5 | Shell/profile parity | Client/server source-shell and main-tab profile parity | Deferred after rejected/reverted attempt | Candidate files: `02_partner_and_notes.R` and `ui.R`. Keep visible tabs, titles, internal values, top bar, and sidebar unchanged while removing dead multi-source profile branches only where local trace proves they cannot affect visible VP workflows. First attempt changed only main-tabs/source-shell diagnostic authority, but the broader shell probes did not meet the accepted H-1/B0 gate, so the source edit was reverted. | Do not replay broad J-1R shell edits or the rejected diagnostic-authority path without separately re-scoping `output$main_tabs` render-source authority. Proceed to J-2a shared Current/Data/filter cleanup with shell/profile parity explicitly deferred. |
| J-2a | Shared Current/Data/filter cleanup | Reopened shared VP data/filter cleanup after J-6/J-7 helper removal | Accepted | Source diff limited to `03_core_reactives_and_ui.R`: shared filtered-data helpers and Current/Summary helper logging now use canonical VP source attribution instead of `export_sales` hidden-input fallbacks; `current_year_data()` uses canonical source for its PSD/monthly frequency guard. Parse clean. Startup/Current PASS after one known intermittent missing-control first-run failure and clean retry; expanded startup PASS; Data smoke passed twice with source `vp_trade` and raw table text length `2634`; bounded CCT/Pace downstream smoke passed. MYC validation was intentionally not chased because MYC is a known buggy surface and the first over-broad downstream validator failure was control-state brittleness, not J-2a source-edit evidence. Comparison cache keys were not touched. User manual validation accepted 2026-08-01: everything is looking good. | Proceed to J-8 closeout. Keep MYC as deferred/manual-risk only unless the user asks to spend time there. |
| J-2b | Optional comparison-cache experiment | Isolated reversible retry of comparison cache-key cleanup | Deferred / not recommended | Candidate file would have been `04_comparison_plots.R`, but prior J-2 comparison-cache experiments caused readiness regressions and J-2a produced no new evidence justifying a retry. | Do not run in Branch J closeout. Only reopen later as a separate reversible experiment with a narrow cache-key churn hypothesis and hard rollback rule. |
| J-8 | Closeout | Final Branch J validation and parent/daughter summary | Complete | Final probes passed: VP quantity sanity `step20_branch_j_vp_contract_post` PASS; canonical `step20_branch_j_source_state_post` PASS=13, total 210273 ms; tab-only `step20_branch_j_tab_only_post` PASS=4, total 121700 ms; hierarchy/sidebar `step20_branch_j_hierarchy_sidebar_post` PASS, total 125906 ms, hierarchy 46925 ms. Runtime summaries generated from exact fallback JSONLs for canonical, tab-only, and hierarchy/sidebar. Final parse/diagnostic/hygiene checks recorded below. Parent plan summarized with outcome and next target recommendation. | Branch J closed as source-state cleanup/attribution with visible behavior preserved. Remaining likely bottleneck is Shiny/htmlwidget/output settling or startup/artifact load, not source-state cleanup. |

## Mandatory Pass Map

Implementation must follow this pass map unless new evidence shows a different dependency. Any deviation must be recorded here with the reason.

### Pass 0: Ledger and Baseline Only

Goal:
- Create this daughter ledger.
- Amend the parent ledger.
- Capture baseline probes before Branch J source-code cleanup.
- Record visible tab title/value inventory before source-code cleanup.

Required evidence:
- Parent plan delegates Branch J and pauses before implementation.
- Baseline probe outputs and exact fallback/runtime JSONLs are recorded.
- Tab inventory lists visible titles and internal values.

Manual check:
- Not required before baselines unless the app state is suspected to have drifted.

Git checkpoint:
- Optional after plan-only changes; required before source-code implementation if the user wants to checkpoint the plan.

### Pass 1: Global Shell / Source Authority

Goal:
- Harden `current_source_choice_safe()` and runtime source defaults.
- Preserve helper names/signatures used by existing code.
- Establish contract-backed `vp_trade` as server authority.
- Convert `data_source_choice` to a hidden fixed VP-only ghost input as a Pass 1 exit gate, not a later cleanup.
- Simplify tab value/profile helpers without changing visible tabs or internal values.
- Confirm top bar/sidebar no-visible-change baseline.

Likely files:
- `Programs/app_source/server/02_partner_and_notes.R`
- `Programs/app_source/global.R`
- `Programs/app_source/ui.R`
- relevant `System/Testing/vp_perf_probe_*.R` files if probe source assumptions change

Manual check:
- App opens.
- Top bar and sidebar match current format.
- Every visible tab is present in the same order.
- Browser console has no new source/profile/null-access errors.

Automated check:
- Probes that touch `data_source_choice` either continue to see the fixed hidden `vp_trade` value or treat setting it to `vp_trade` as an optional/no-op action.
- Browser/client diagnostics show no new `data_source_choice`, main-tab profile, source-shell refresh, jQuery selector, or null-access errors.

Checkpoint rule:
- Do not proceed to Pass 2 until parse checks, focused automated validation, manual confirmation, and Git checkpoint are complete.

### Pass 2: Current vs. Historical and Data Shared Surfaces

Goal:
- Clean active source fallbacks and cache-key dimensions affecting:
  - `comparison_plot`
  - `summary_table`
  - `raw_data_table`
  - shared selected/filter data surfaces

Manual check:
- Current vs. Historical opens and output responds to top bar/sidebar controls.
- Summary Statistics remains present and functional.
- Data tab opens and displays the filtered VP dataset.

### Pass 3: Historical Trendlines and Monthly Heatmap

Goal:
- Clean Trend/Heatmap source fallbacks, labels, active cache-key dimensions, and dead source guards.
- Preserve Plotly controls, output meaning, historical-average behavior, year controls, display options, heatmap title, labels, and hover behavior.

Manual check:
- Historical Trendlines renders and responds to year/display options and top/sidebar filters.
- Monthly Heatmap renders and responds to top/sidebar filters.

### Pass 4: Map

Goal:
- Clean Map source fallbacks, labels, bottom-panel source guards, and active cache-key dimensions.
- Preserve map output, map note blocks, and map bottom panel behavior.

Manual check:
- Map renders.
- Map responds to top bar/sidebar filters.
- No visible source-remnant controls appear.

### Pass 5: Custom Comparison Tool

Goal:
- Trace inherited helper use before cleanup.
- Remove only dead source branches that do not affect the visible VP comparison workflow.
- Preserve quick apply buttons, comparison controls, and outputs.

Manual check:
- Custom Comparison Tool opens.
- Quick apply buttons still work.
- Outputs update with VP data.

Automated check:
- Add or adapt a lightweight smoke assertion for this pass before accepting source cleanup. At minimum, the app must navigate to `Custom Comparison Tool`, find expected controls, and observe at least one expected output/control-ready signal without stale-source errors.

### Pass 6: Market Year Comparison Tool

Goal:
- Trace MYC helper use before cleanup.
- Refactor active helper internals as VP-owned behavior rather than deleting clone-era helpers.
- Preserve mode controls, sidebar interactions, and VP outputs.

Manual check:
- Market Year Comparison Tool opens.
- MYC controls and outputs still work with VP data.

Automated check:
- Add or adapt a lightweight smoke assertion for this pass before accepting source cleanup. At minimum, the app must navigate to `Market Year Comparison Tool`, find expected mode controls, and observe at least one expected output/control-ready signal without stale-source errors.

### Pass 7: Pace Analysis Tool

Goal:
- Treat `06_pace_analysis_and_reset.R` as high-risk.
- Remove only locally proven unreachable non-VP branches.
- Preserve Pace controls, active-year logic, output calculations, labels, and VP output behavior.

Manual check:
- Pace Analysis Tool opens.
- Pace controls and outputs still work with VP data.

Automated check:
- Add or adapt a lightweight smoke assertion for this pass before accepting source cleanup. At minimum, the app must navigate to `Pace Analysis Tool`, find expected controls, and observe at least one expected output/control-ready signal without stale-source errors.

## Reopened J-0/J-1/J-2 Addendum

This addendum reopens the early Branch J source-state work because J-6 and J-7 removed later helper dependencies that made some original J-1/J-2 cleanup candidates too risky at the time. It is an additive plan only: previous Branch J evidence remains intact, accepted records remain accepted, and new probes must use fresh labels and exact output paths.

### Evidence Preservation Rules

- Do not overwrite, rename, delete, or collapse the original J-0 through J-7 evidence rows, runtime summaries, parse markers, failed attempts, or manual validation notes.
- Treat `J-0R` as B0: the post-J-7/pre-reopen intermediate baseline. Reopened implementation should compare post results against both B0 and original J-0, but B0 is the controlling immediate before/after point.
- Use unique labels and exact fallback/runtime JSONLs for every reopened probe. Do not use broad runtime-log wildcards for before/after claims.
- Keep generated Shiny artifacts cleanup targeted. Remove only untracked smoke/probe artifacts that were produced by the current validation run, and do not remove tracked cache files.
- If Chromote/AppDriver fails before app assertions with environment errors such as `code: -32000, message: Not allowed`, retry once after checking for leftover browser/R processes and record the failure as infrastructure, not app behavior, unless the retry reproduces an app assertion failure.

### Reopened Scope

| Reopened step | Scope | Explicit exclusions |
|---|---|---|
| J-0R | Measurement-only B0 baseline after J-7 and before reopened source edits. | No source edits, no probe semantics changes beyond recreating focused validators if needed. |
| J-1R | Server source authority, raw hidden-source reads, source defaults, source-shell refresh state, and adversarial hidden-source spoofing. | Do not remove the hidden `data_source_choice` DOM/input node. Do not change visible top/sidebar format. |
| J-1.5 | Client/server main-tab profile parity and source-shell readiness expectations. | Do not change visible tab titles, order, or internal tab values. |
| J-2a | Shared Current/Data/filter cleanup in active VP data paths after later helper removals. | Do not edit `comparison_plot_base_cache_key()` in this step. Do not mass-delete every `export_sales` token. |
| J-2b | Optional isolated comparison cache-key retry. | Do not run unless J-1R/J-1.5/J-2a pass and a narrow rollback-ready hypothesis is recorded. |

### Required Labels

J-0R B0 labels:
- `step20_branch_j_j0r_intermediate_canonical`
- `step20_branch_j_j0r_intermediate_tab_only`
- `step20_branch_j_j0r_intermediate_hierarchy_sidebar`
- `step20_branch_j_j0r_intermediate_vp_quantity_sanity`

Post-reopen labels:
- `step20_branch_j_reopen_j1_j2_post_canonical`
- `step20_branch_j_reopen_j1_j2_post_tab_only`
- `step20_branch_j_reopen_j1_j2_post_hierarchy_sidebar`
- `step20_branch_j_reopen_j1_j2_post_vp_quantity_sanity`

Focused later-tab smoke labels may be recreated as temporary validators, but their output markers must be unique to the reopened pass and appended to this ledger before deletion.

### Source-Token Classification Gate

Before source removal in J-1R/J-2a, classify each remaining source token touched by the pass:
- `remove`: locally proven dead for visible VP workflows.
- `keep`: active VP compatibility shim or visible-workflow dependency.
- `defer`: uncertain or sensitive path requiring a separate focused test.

`export_sales` is not globally dead. Some occurrences are active context keys or legacy stable identifiers, so every touched occurrence needs an allowlist/defer decision before editing.

### Reopened Validation Gates

- Run J-0R first with no source edits and append B0 probe output paths and exact fallback/runtime JSONLs.
- After J-1R/J-1.5, run startup, tab-only, hierarchy/sidebar, and an adversarial hidden-source test that attempts to spoof the hidden input away from `vp_trade` and confirms server authority remains VP-only.
- After J-2a, validate Current vs. Historical and Data first, then rerun focused CCT/MYC/Pace smokes because those tabs consume shared selected/filter data.
- Repeat or settle runtime probes when cache state is noisy. Mark cache state explicitly and avoid treating single cache-sensitive runs as clean speed wins or losses.
- Pause after each reopened implementation tranche for manual validation and Git checkpoint decision before proceeding.

### Reopened Manual Checklist

- Top bar and sidebar format, labels, order, defaults, and behavior remain unchanged.
- All visible tabs remain present in the same order and continue to display ingested VP data.
- Current vs. Historical, Summary Statistics, Data, CCT, MYC, and Pace workflows still respond to top/sidebar filters.
- Browser console has no new source/profile/null-access errors.
- Removed non-VP controls or helper paths do not leave visible holes, blank placeholders, or stale labels.

## Phase Plan

Phase J-0: Ledger and baseline recenter
- Create this daughter ledger.
- Amend the parent ledger.
- Capture baseline probes and exact fallback/runtime JSONLs.
- Record visible tab title/internal value inventory before source-code cleanup.

Phase J-1: Global source shell hardening
- Establish contract-backed `vp_trade` source authority.
- Convert `data_source_choice` to a fixed hidden VP-only ghost input as a Pass 1 exit gate.
- Simplify source/tab profile helpers without changing visible tabs or internal tab values.
- Validate top bar/sidebar no-visible-change behavior.

Phase J-2: Shared active VP data/filter cleanup
- Thin active VP cache keys.
- Remove active legacy source fallbacks in shared selected/filter data paths.
- Validate Current vs. Historical and Data first because they are better-covered core surfaces.

Phase J-3: Output/tab-specific cleanup
- Move tab by tab through Trend/Heatmap, Map, Custom Comparison, MYC, and Pace.
- Add or adapt lightweight smoke assertions for Custom Comparison, MYC, and Pace before accepting those passes.
- Stop after each pass for user manual validation and Git checkpoint.

Phase J-4: Confirmation and closeout
- Run final focused probes, exact runtime summaries, diagnostics, and hygiene checks.
- Update this daughter ledger and summarize the outcome into the parent plan.

## Detailed Step Notes

1. Create and seed this Branch J daughter ledger before source edits.
   - Add date, branch/status, purpose, scope, guardrails, pass map, validation commands, adversarial review checklist, and Summary placeholder.
   - Update the parent `Code Review/2026-07-29_vp_performance_hotspot_recovery_plan.md` to delegate Branch J and pause before implementation.
   - Record that the user clarified only the VP CSV-backed source is real and all visible tabs display VP data.

2. Inventory and classify all source-remnant references before source-code removal.
   - Search `Programs/app_source/**/*.R`, `System/Testing/**/*.R`, and `System/Config/**/*.R` for:
     - `input$data_source_choice`
     - `current_source_choice_safe`
     - `startup_ui_source_choices`
     - `startup_ui_source_values`
     - `source_switch_epoch`
     - `psd_transition`
     - `nass`
     - `census`
     - `hybrid`
     - `wasde`
     - `export_sales`
     - `expectedMainTabsProfileForSource`
     - `client_source_surface_refresh_request`
   - Classify each reference as one of:
     - VP authority to preserve
     - compatibility shim to replace or keep temporarily
     - source-remnant observer to remove
     - UI branch to collapse internally
     - cache-key field to thin
     - probe assumption to update
     - diagnostic-only field
     - non-target feature code to defer
   - Record the classification table in this ledger before code edits.

3. Capture Branch J baseline evidence.
   - Parse-check candidate files before edits if recent changes are dirty:
     - `Programs/app_source/server/02_partner_and_notes.R`
     - `Programs/app_source/server/03_core_reactives_and_ui.R`
     - `Programs/app_source/ui.R`
     - any probe files to be touched
   - Run single-action canonical baseline from repository root:
     - `C:\Program Files\R\R-4.5.1\bin\Rscript.exe "System/Testing/vp_perf_probe_single_action_latency.R" --label=step20_branch_j_source_state_baseline --scenario=canonical --cache-state=warm_partition_disk --runtime-perf=true`
   - Run tab-only baseline if canonical passes or if tab readiness is the main comparison:
     - `C:\Program Files\R\R-4.5.1\bin\Rscript.exe "System/Testing/vp_perf_probe_single_action_latency.R" --label=step20_branch_j_tab_only_baseline --scenario=tab_only --cache-state=warm_partition_disk --runtime-perf=true`
   - Run hierarchy-sidebar baseline:
     - `C:\Program Files\R\R-4.5.1\bin\Rscript.exe "System/Testing/vp_perf_probe_hierarchy_sidebar_cascade.R" --label=step20_branch_j_hierarchy_sidebar_baseline --cache-state=warm_partition_disk --runtime-perf=true`
   - Summarize exact fallback/runtime JSONLs from each run:
     - `C:\Program Files\R\R-4.5.1\bin\Rscript.exe "System/Testing/vp_perf_summarize_runtime_logs.R" --label=<summary_label> --input=<exact jsonl paths separated by |>`
   - Record PASS/PARTIAL counts, output CSVs, fallback JSONLs, runtime summaries, selected source values, source-switch/source-profile events, `data_frequency_ui_rendered` counts, key-delta fields, visible timings, and full-idle timings.

4. Establish a single VP source authority and remove legacy fallback defaults.
   - In `Programs/app_source/server/02_partner_and_notes.R`, simplify `current_source_choice_safe()` so it returns the normalized contract default `vp_trade` and no longer treats `input$data_source_choice` as source authority.
   - Preserve the helper name and function signature.
   - Harden `runtime_default_source_choice()`, `runtime_visible_source_values()`, and `normalize_runtime_source_choice()` so fallback paths cannot silently return `export_sales` in this VP app when the contract is present.
   - Prefer contract-backed `startup_default_ui_source(default = "vp_trade")` and `startup_ui_source_values()`.
   - In `Programs/app_source/global.R`, keep `startup_ui_source_choices()`, `startup_ui_source_values()`, and `startup_default_ui_source()` contract-backed. Add only narrow VP hardening if server helper fallback remains vulnerable.
   - Do not mass-replace every `export_sales` string. First replace active behavior fallbacks in source authority, tab eligibility, cache keys, data paths, and plot/helper source decisions. Leave inert historical labels or non-executed branch strings until their owner pass.
   - Parse-check immediately after this pass.

5. Thin VP cache keys and key-delta surfaces.
   - This must happen after source authority and before broad observer removal.
   - In `Programs/app_source/server/03_core_reactives_and_ui.R`, simplify `filtered_data_stable_cache_key()` around VP-only dimensions.
   - Preserve:
     - source identity as `vp_trade`
     - `vp_trade_flow_choice`
     - VP hierarchy tokens from `resolve_vp_hierarchy_tokens()`
     - VP commodity name/detail choices
     - data/schema version
     - country
     - data frequency
     - display-year type
     - metric
     - unit
     - basis
     - custom types/countries
     - custom scope
     - MYC selected-data mode if still used by VP comparison paths
   - Remove or convert to constants outside active VP keys:
     - `census_trade_flow_choice`
     - `hybrid_trade_flow_choice`
     - `hybrid_mode_choice`
     - `census_value_unit_choice`
     - WASDE lock fields
     - NASS lock/state/year-type fields
     - PSD-only transition dimensions
   - Search neighboring cache-key builders in `03_core_reactives_and_ui.R`, `04_comparison_plots.R`, `05_trend_and_heatmap.R`, and `06_pace_analysis_and_reset.R`.
   - Thin only keys that are active for VP and still carry dead source dimensions.

6. Simplify `output$data_frequency_ui` internally while preserving the visible top bar.
   - Remove precomputed Census/Hybrid/NASS/PSD branches from `output$data_frequency_ui` only where they do not affect the visible VP controls.
   - Preserve Group, Subgroup, Market Segment, reset button, Commodity, Trade Flow, and Data Frequency exactly.
   - Keep VP faceted hierarchy logic, `vp_hierarchy_change_nonce()`, `vp_hierarchy_last_changed()`, `vp_reset_hierarchy_filters`, VP native choice-list filtering, and Branch F render-stabilization counters.
   - Keep `data_source_choice` as a hidden fixed VP-only ghost selector.
   - Remove only non-visible/dead helper text and mode controls for PSD/NASS/Census/Hybrid.

7. Collapse main-tab source profile logic to the VP shell while preserving every visible tab.
   - Simplify `output$main_tabs` so VP tabs are rendered directly rather than through generic `show_non_psd_tabs` source profiling.
   - Preserve visible tab titles and internal values exactly.
   - Keep or simplify `allowed_main_tabs_for_source()`, `resizeable_main_tabs_for_source()`, `normalize_main_tab_for_source()`, `target_main_tab_for_source()`, `main_tabs_profile_for_source()`, and `main_tabs_expected_count_for_source()` so they return VP tab values/count directly and no longer route through PSD/WASDE/NASS profiles.
   - In `Programs/app_source/ui.R`, simplify `expectedMainTabsProfileForSource()` and related main-tab profile snapshots around VP-only expectations.
   - Preserve safe tab selection, readiness snapshots, and PERF event payloads until post-validation proves they are unnecessary.
   - Remove client checks that specifically watch for PSD/weekly/source-remnant artifacts only if replaced by VP shell readiness checks.

8. Remove source-switch and source-specific observers in small batches.
   - Remove or disable observers that only handle impossible source transitions:
     - `observeEvent(input$data_source_choice, ...)` source-switch engine
     - PSD transition target-state builders
     - NASS state sync observers
     - Census/Hybrid trade-flow source-mode observers
     - WASDE/NASS lock observers
     - source-shell refresh requests whose only purpose is multi-source mismatch recovery
   - Preserve non-source VP observers:
     - hierarchy choice cascades
     - VP trade-flow changes
     - commodity/detail changes
     - country/type refresh
     - metric/unit/basis changes
     - summary table controls
     - Trend/Heatmap controls
     - VP Custom Comparison controls
     - MYC controls
     - Pace controls
   - After each observer batch, parse-check and run the cheapest discriminating Shiny probe.
   - If removal causes startup hydration failure, stale outputs, missing controls, or PARTIAL rows, reinstate a minimal VP-only compatibility shim rather than restoring multi-source behavior.

9. Verify fixed hidden `data_source_choice` ghost-input compatibility after source cleanup.
   - Search again for direct `input$data_source_choice` reads.
   - Replace active VP paths with `current_source_choice_safe()` or local `source_choice <- current_source_choice_safe()` where the read controls behavior, cache keys, tab eligibility, data filtering, or source-specific helper branches.
    - Confirm the hidden DOM/input node for `data_source_choice` remains present and fixed to `vp_trade`. The conversion itself is a required Pass 1 exit gate; this step is a later compatibility audit, not permission to defer ghost-input safety until after observer removal.
   - Update probes so setting `data_source_choice` to `vp_trade` is optional/no-op and final source assertions accept the fixed ghost value:
     - `System/Testing/vp_perf_probe_single_action_latency.R`
     - `System/Testing/vp_perf_probe_hierarchy_sidebar_cascade.R`
     - `System/Testing/vp_perf_probe_hierarchy_transition.R`
     - `System/Testing/vp_perf_probe_startup.R`
     - `System/Testing/vp_perf_probe_tab_switch_filtering.R`
   - Do not remove the DOM node entirely in Branch J.
   - Parse-check source and testing files, then inspect browser console logs from probe/manual run for `Uncaught TypeError`, missing jQuery selector assumptions, or null `data_source_choice` access.

10. Audit `06_pace_analysis_and_reset.R` and comparison-tool source remnants without deleting visible VP tab functionality.
    - Identify PSD/Census/export-sales-only PACE/MYC helpers that are unreachable for `vp_trade`.
    - Treat clone-era helper names as ambiguous until traced.
    - If a helper such as a Pace/MYC anchor, display label, basis bundle, context key, or target-year function is used by a visible VP tab, keep it and refactor only the source-branch internals needed to make it VP-owned.
    - Preserve Custom Comparison Tool, Market Year Comparison Tool, and Pace Analysis Tool UI and function.
    - Validate with canonical single-action and manual smoke notes rather than relying only on parse checks.

11. Validate each tab-scoped cleanup pass before moving to the next pass.
    - After each cleanup pass, run parse checks for every touched R file with explicit markers such as `PARSE_OK_BRANCH_J_<PASS_NAME>`.
    - Run the cheapest automated probe covering the affected surface:
      - hierarchy-sidebar for top bar/sidebar changes
      - `tab_only` single-action for tab shell/profile/output readiness
      - canonical single-action for broad state changes
      - `vp_perf_probe_vp_mixed_quantity_sanity.R` for quantity/unit/metric behavior
      - pass-specific lightweight smoke assertions for Custom Comparison Tool, Market Year Comparison Tool, and Pace Analysis Tool before accepting cleanup in those tabs
    - Summarize exact fallback/runtime JSONLs when runtime PERF is enabled.
    - Stop after automated validation and wait for user manual app confirmation.
    - Record user confirmation, issues, screenshots/manual notes, and Git checkpoint status in this ledger.
    - If manual validation finds a regression, repair or revert only that pass before proceeding.

12. Run final Branch J validation and acceptance decision.
    - Run parse checks for every touched R file with explicit markers.
    - Run:
      - `System/Testing/vp_perf_probe_vp_mixed_quantity_sanity.R --label=step20_branch_j_vp_contract_post`
      - `System/Testing/vp_perf_probe_single_action_latency.R --label=step20_branch_j_source_state_post --scenario=canonical --cache-state=warm_partition_disk --runtime-perf=true`
      - `System/Testing/vp_perf_probe_single_action_latency.R --label=step20_branch_j_tab_only_post --scenario=tab_only --cache-state=warm_partition_disk --runtime-perf=true`
      - `System/Testing/vp_perf_probe_hierarchy_sidebar_cascade.R --label=step20_branch_j_hierarchy_sidebar_post --cache-state=warm_partition_disk --runtime-perf=true`
    - Summarize exact fallback/runtime JSONLs.
    - Run `get_errors` on touched files.
    - Run `git diff --check` on touched source, testing, and plan files.

13. Close Branch J in this daughter ledger and parent ledger.
    - Daughter Summary should explain in lay terms what source machinery was removed, what compatibility shims remain, what probes passed/failed, whether timing improved, and what bottleneck remains.
    - Parent ledger should record Branch J outcome, output paths, fallback JSONLs, runtime summaries, parse markers, residual risk, and next recommended target.

## Acceptance Gates

All accepted passes and final closeout must satisfy these gates unless a deviation is explicitly recorded and accepted by the user.

- All required parse checks pass.
- Automated probes for the affected surface PASS, or a probe limitation is recorded and manual validation explicitly covers the gap.
- Selected/final source is always `vp_trade`.
- No missing required VP controls.
- All visible tab titles remain present, named the same, ordered the same, and functional.
- Internal tab values remain unchanged.
- Top bar and sidebar format/function remain unchanged.
- Browser console has no new `data_source_choice`, jQuery selector, null-access, main-tab profile, or source-shell refresh errors.
- No stale-output flags.
- VP Provider v3/source identity protections remain intact.
- VP hierarchy tokens and hierarchy cache separation remain intact.
- No regression over baseline greater than 10% or 1000 ms on core visible readiness without a documented and accepted cleanup benefit.
- Legacy source key-delta fields disappear or become constant where targeted.
- Source-switch/profile mismatch events are reduced or absent where targeted.
- `vp_perf_probe_vp_mixed_quantity_sanity.R` still passes when quantity/unit/metric behavior is touched or at final closeout.
- Manual app validation confirms the affected visible tab(s), top bar, and sidebar still work.
- A Git progress checkpoint is created after each accepted pass before the next pass begins.

## Adversarial Code Review Checklist

A reviewer should challenge the implementation with these questions before accepting any pass.

### Product/UX Preservation

- Did any visible tab title change?
- Did any internal tab value change?
- Did tab order change?
- Did any visible tab disappear or become unreachable?
- Did the top bar change in format, label, order, default, or behavior?
- Did the sidebar change in format, label, order, default, or behavior?
- Did any visible tool become less functional, especially Custom Comparison Tool, Market Year Comparison Tool, or Pace Analysis Tool?

### Source Authority

- Is `vp_trade` the single runtime source authority?
- Does server authority come from contract-backed helpers rather than the hidden input?
- Does the hidden `data_source_choice` ghost input remain available to client JS and probes?
- Can any active fallback still return `export_sales`, `census`, `hybrid`, `nass`, `wasde`, or `psd` during VP startup or error recovery?

### Cache and Reactivity

- Were only active VP cache-key dimensions changed?
- Were VP hierarchy tokens preserved?
- Were Provider v3 source identity protections preserved?
- Did removed key dimensions actually correspond to impossible source states?
- Did cache-key churn shrink or become more stable in runtime summaries?
- Did observer deletion happen only after source authority and cache keys were stable?

### Client and Probe Safety

- Do `ui.R` source/profile readiness handlers still avoid null-access errors?
- Does the browser console stay clean after startup and tab switching?
- Were probes updated to treat the fixed hidden source input as optional/no-op rather than removed?
- Do final source assertions still confirm `vp_trade`?

### Tab-Specific Behavior

- For Current vs. Historical, do comparison plot, summary statistics, projections, units, metric labels, and sidebar controls still work?
- For Data, does the raw data table match the selected VP filters?
- For Historical Trendlines, do year controls, display options, historical average, projections, labels, and hover behavior still work?
- For Monthly Heatmap, do period/year matrix, labels, hover behavior, and top/sidebar filters still work?
- For Map, do map output, map note block, and bottom panel still work?
- For Custom Comparison Tool, do quick apply buttons, locks, side/top selections, and outputs still work?
- For Market Year Comparison Tool, do mode controls and comparison outputs still work?
- For Pace Analysis Tool, do active-year logic, target calculations, controls, labels, and outputs still work?

### Evidence and Rollback

- Was the pass small enough to revert without disturbing unrelated accepted passes?
- Did the ledger record parse/probe/manual/Git checkpoint evidence?
- Were rejected approaches and regressions recorded?
- If timing did not improve, did the pass still remove dead source machinery without changing visible VP behavior?

## Relevant Files

- `VP Clone/Code Review/2026-07-29_vp_performance_hotspot_recovery_plan.md` - parent source-of-truth performance ledger.
- `VP Clone/Code Review/2026-07-31_vp_branch_j_vp_only_source_state_cleanup_plan.md` - this daughter implementation ledger.
- `VP Clone/System/Config/vp_contract.R` - contract evidence that only `vp_trade` is enabled.
- `VP Clone/Programs/app_source/global.R` - startup source-choice helpers and contract-backed defaults.
- `VP Clone/Programs/app_source/server/02_partner_and_notes.R` - source helper, source-switch machinery, top bar, main tabs, tab helpers, source-specific guards.
- `VP Clone/Programs/app_source/server/03_core_reactives_and_ui.R` - `filtered_data_stable_cache_key()`, selected/filter data cache keys, country/choice observers, source-specific key dimensions.
- `VP Clone/Programs/app_source/server/04_comparison_plots.R` - comparison output source guards, labels, map paths, cache keys.
- `VP Clone/Programs/app_source/server/05_trend_and_heatmap.R` - Trend/Heatmap source guards, labels, cache keys, Plotly outputs.
- `VP Clone/Programs/app_source/server/06_pace_analysis_and_reset.R` - Pace/MYC source-remnant inventory; preserve visible VP Pace and MYC behavior.
- `VP Clone/Programs/app_source/ui.R` - client main-tab profile/source-shell readiness and refresh diagnostics.
- `VP Clone/System/Testing/vp_perf_probe_single_action_latency.R` - canonical/tab-only readiness validation.
- `VP Clone/System/Testing/vp_perf_probe_hierarchy_sidebar_cascade.R` - hierarchy/sidebar/source-shell validation.
- `VP Clone/System/Testing/vp_perf_probe_hierarchy_transition.R` - older hierarchy source/input probe that may require ghost-input compatibility.
- `VP Clone/System/Testing/vp_perf_probe_startup.R` - startup/source readiness probe that may require ghost-input compatibility.
- `VP Clone/System/Testing/vp_perf_probe_tab_switch_filtering.R` - tab/filter source-input probe that may require ghost-input compatibility.
- `VP Clone/System/Testing/vp_perf_probe_vp_mixed_quantity_sanity.R` - VP unit/quantity contract regression check.
- `VP Clone/System/Testing/vp_perf_summarize_runtime_logs.R` - exact fallback/runtime JSONL summarizer.

## Source-Remnant Classification Inventory

Captured before Branch J source-code edits on 2026-07-31.

| Surface | References Found | Classification | Branch J Handling |
|---|---|---|---|
| `Programs/app_source/global.R` | `startup_ui_source_choices()`, `startup_ui_source_values()`, `startup_default_ui_source()`, contract helpers, PSD transition logging option names | VP authority to preserve; diagnostic compatibility | Keep contract-backed startup helpers. Do not remove logging option compatibility during J-1. |
| `Programs/app_source/server/01_state_and_custom_types.R` | `active_source_choice()`, custom scope fallbacks, Census/Hybrid reset notices, source-specific custom type code | Mixed active compatibility and non-target custom-type code | Defer broad cleanup. J-1 may harden `active_source_choice()` only if required by source authority. Do not remove visible VP custom behavior. |
| `Programs/app_source/server/02_partner_and_notes.R` | `current_source_choice_safe()`, runtime source defaults, `data_source_choice` top-bar hidden selector, source-switch epoch/PSD transition machinery, main-tab profile helpers, top bar/sidebar renderers, many `export_sales` defaults | Primary J-1 authority/shell target plus later observer-removal target | J-1 changes source authority, fixed hidden ghost input, and tab profile helpers first. Source-switch/PSD transition observer removal waits until after authority/cache gates. |
| `Programs/app_source/server/03_core_reactives_and_ui.R` | `filtered_data_stable_cache_key()`, selected/filter data paths, non-VP key fields, `input$data_source_choice` diagnostic/details reads | Pass J-2 active VP cache-key/data-path target | Thin only active VP cache keys and source fallbacks after J-1. Preserve VP hierarchy tokens, commodity/detail, country, metric, unit, basis, versions, and custom/MYC context. |
| `Programs/app_source/server/04_comparison_plots.R` | comparison plot/map labels, map data paths, `input$data_source_choice` direct reads, PSD/Census label branches | Pass J-2/J-4 output-path target | Clean Current/Data and Map source fallbacks in tab-scoped passes. Preserve visible labels/output semantics unless proven source-remnant-only. |
| `Programs/app_source/server/05_trend_and_heatmap.R` | Trend/Heatmap key dimensions and source fallbacks including Census/Hybrid/NASS/WASDE/PSD fields | Pass J-3 target | Thin active VP Trend/Heatmap key fields only after J-1/J-2. Preserve Branch I instrumentation and output behavior. |
| `Programs/app_source/server/06_pace_analysis_and_reset.R` | `pace_census_*` helpers, `export_sales` fallbacks, `current_source_choice_safe()` calls, Pace/MYC context keys | High-risk Pass J-6/J-7 inherited-helper target | Trace visible MYC/Pace use before removal. Clone-era helper names are not dead-code proof. |
| `Programs/app_source/ui.R` | `expectedMainTabsProfileForSource()`, `mainTabsProfileSnapshot()`, `sourceShellSnapshot()`, `client_source_surface_refresh_request`, direct `data_source_choice` reads | Client compatibility and later VP shell simplification | Keep readiness/snapshot protection in J-1. Simplify around VP-only expectations only after fixed ghost input and server authority are stable. |
| `System/Testing/*.R` | Probes require/read/set `data_source_choice`; startup/tab/hierarchy probes assert source presence/value | Probe compatibility shim to update only when needed | Branch J keeps the DOM/input node. Setting `data_source_choice` to `vp_trade` remains accepted as a no-op compatibility action. |

## Visible Tab Title / Internal Value Inventory

Captured before Branch J source-code edits on 2026-07-31 from `output$main_tabs` / `allowed_main_tabs_for_source()` contracts.

| Order | Visible Title | Internal Value | Preservation Requirement |
|---|---|---|---|
| 1 | Current vs. Historical | `Current vs. Average` | Preserve title, value, order, filters, plot, and Summary Statistics behavior. |
| 2 | Historical Trendlines | `Historical Trend` | Preserve title, value, order, year controls, display options, labels, hover, and historical average/projection behavior. |
| 3 | Map | `Map` | Preserve title, value, order, map output, note block, bottom panel, and top/sidebar filtering. |
| 4 | Monthly Heatmap | `Heatmap` | Preserve title, value, order, matrix output, labels, hover, and top/sidebar filtering. |
| 5 | Data | `Data` | Preserve title, value, order, and raw filtered VP dataset display. |
| 6 | Custom Comparison Tool | `Custom Comparison Tool` | Preserve title, value, order, quick apply buttons, controls, and outputs. |
| 7 | Market Year Comparison Tool | `Market Year Comparison Tool` | Preserve title, value, order, mode controls, sidebar interactions, and VP outputs. |
| 8 | Pace Analysis Tool | `Pace Analysis Tool` | Preserve title, value, order, active-year logic, target calculations, controls, labels, and outputs. |

## Measurement Model and Cache-State Labels

Every Branch J probe or benchmark row must identify cache state using the parent-plan labels.

- `cold_artifact`: fresh R session and no warmed partition cache for the target path.
- `warm_partition_disk`: partition files exist but session memory cache is empty.
- `warm_session`: same session and partition memory cache already hit.
- `unknown_cache_state`: only allowed for explicitly documented harness/cache uncertainty where the evidence is used for target selection rather than final before/after proof.

Rules:
- Record whether partition directories, logs, generated artifacts, and browser state were cleared or preserved.
- Do not blend cold and warm timings into one median without labeling.
- Prefer separate output files or scenario labels for cold and warm probes.
- Use exact fallback/runtime JSONL paths from each probe when summarizing runtime evidence.

## Verification and Validation Targets

- Parse each touched R file immediately after the relevant pass before widening to another file group.
- Run focused automated probes for the affected surface after each source/probe edit pass.
- For Custom Comparison Tool, Market Year Comparison Tool, and Pace Analysis Tool, add or adapt lightweight smoke assertions before accepting cleanup in those tabs.
- Use exact runtime JSONL summaries when runtime PERF is enabled.
- Run `get_errors` on touched files.
- Run `git diff --check` on all touched plan, source, and testing files for the current pass.
- Stop after each accepted source-code pass for user manual validation and Git progress checkpoint before continuing.

## Verification Command Examples

Use repository root as the working directory unless noted.

### Parse Checks

Use targeted parse checks after each touched R file. Example shape:

```powershell
& "C:\Program Files\R\R-4.5.1\bin\Rscript.exe" -e "invisible(parse(file='Programs/app_source/server/02_partner_and_notes.R')); cat('PARSE_OK_BRANCH_J_PARTNER_NOTES\n')"
```

Use distinct markers for each pass, for example:
- `PARSE_OK_BRANCH_J_PASS1_SOURCE_AUTHORITY`
- `PARSE_OK_BRANCH_J_PASS2_CURRENT_DATA`
- `PARSE_OK_BRANCH_J_PASS3_TREND_HEATMAP`
- `PARSE_OK_BRANCH_J_PASS4_MAP`
- `PARSE_OK_BRANCH_J_PASS5_CUSTOM_COMPARISON`
- `PARSE_OK_BRANCH_J_PASS6_MYC`
- `PARSE_OK_BRANCH_J_PASS7_PACE`

### Baseline Probes

```powershell
& "C:\Program Files\R\R-4.5.1\bin\Rscript.exe" "System/Testing/vp_perf_probe_single_action_latency.R" --label=step20_branch_j_source_state_baseline --scenario=canonical --cache-state=warm_partition_disk --runtime-perf=true
& "C:\Program Files\R\R-4.5.1\bin\Rscript.exe" "System/Testing/vp_perf_probe_single_action_latency.R" --label=step20_branch_j_tab_only_baseline --scenario=tab_only --cache-state=warm_partition_disk --runtime-perf=true
& "C:\Program Files\R\R-4.5.1\bin\Rscript.exe" "System/Testing/vp_perf_probe_hierarchy_sidebar_cascade.R" --label=step20_branch_j_hierarchy_sidebar_baseline --cache-state=warm_partition_disk --runtime-perf=true
```

### Post Probes

```powershell
& "C:\Program Files\R\R-4.5.1\bin\Rscript.exe" "System/Testing/vp_perf_probe_vp_mixed_quantity_sanity.R" --label=step20_branch_j_vp_contract_post
& "C:\Program Files\R\R-4.5.1\bin\Rscript.exe" "System/Testing/vp_perf_probe_single_action_latency.R" --label=step20_branch_j_source_state_post --scenario=canonical --cache-state=warm_partition_disk --runtime-perf=true
& "C:\Program Files\R\R-4.5.1\bin\Rscript.exe" "System/Testing/vp_perf_probe_single_action_latency.R" --label=step20_branch_j_tab_only_post --scenario=tab_only --cache-state=warm_partition_disk --runtime-perf=true
& "C:\Program Files\R\R-4.5.1\bin\Rscript.exe" "System/Testing/vp_perf_probe_hierarchy_sidebar_cascade.R" --label=step20_branch_j_hierarchy_sidebar_post --cache-state=warm_partition_disk --runtime-perf=true
```

### Runtime Summaries

Use exact fallback/runtime JSONL paths printed by each probe. Do not summarize broad wildcards when making before/after claims.

```powershell
& "C:\Program Files\R\R-4.5.1\bin\Rscript.exe" "System/Testing/vp_perf_summarize_runtime_logs.R" --label=<label> --input="<jsonl1>|<jsonl2>"
```

### Hygiene

Run `git diff --check` on all touched plan, source, and testing files for the current pass. Do not rely on the fixed plan-only example below after source-code implementation starts.

```powershell
git diff --check -- "Code Review/2026-07-31_vp_branch_j_vp_only_source_state_cleanup_plan.md" "Code Review/2026-07-29_vp_performance_hotspot_recovery_plan.md"
```

Also run `get_errors` on touched files after plan/source/probe edits. For source/probe implementation passes, replace the fixed example paths with the actual touched file list.

## Evidence Ledger

This section must be updated during implementation.

| Pass | Status | Source Files | Parse Marker(s) | Probe Label(s) | Runtime Summary | Manual Validation | Git Checkpoint | Notes |
|---|---|---|---|---|---|---|---|---|
| Pass 0 | Complete | This plan; parent plan; read-only baseline probes | `PARSE_OK_BRANCH_J_BASELINE_PARTNER_NOTES`; `PARSE_OK_BRANCH_J_BASELINE_CORE_REACTIVES`; `PARSE_OK_BRANCH_J_BASELINE_UI`; `PARSE_OK_BRANCH_J_BASELINE_PROBES`; markdown diagnostics clean | `step20_branch_j_source_state_baseline` PASS=11; `step20_branch_j_tab_only_baseline` PASS=4; `step20_branch_j_hierarchy_sidebar_baseline` PASS | Runtime summary latest CSV sets: `vp_perf_runtime_summary_step20_branch_j_source_state_baseline_runtime_summary_20260731T174601Z_*`; `vp_perf_runtime_summary_step20_branch_j_tab_only_baseline_runtime_summary_20260731T174608Z_*`; `vp_perf_runtime_summary_step20_branch_j_hierarchy_sidebar_baseline_runtime_summary_20260731T174612Z_*` | Not required for J-0; no source behavior changed | Optional plan checkpoint pending user action | Parent delegation complete. Source-remnant classification and tab inventory recorded. No source-code cleanup has started. |
| Pass 1 | Accepted | `Programs/app_source/server/02_partner_and_notes.R` | `PARSE_OK_BRANCH_J_PASS1_PARTNER_NOTES_SOURCE_AUTHORITY`; `PARSE_OK_BRANCH_J_PASS1_PARTNER_NOTES_REPAIR`; `PARSE_OK_BRANCH_J_PASS1_GHOST_INPUT_BINDING_REPAIR`; `PARSE_OK_BRANCH_J_PASS1_DIRECT_SOURCE_AUTHORITY`; `PARSE_OK_BRANCH_J_PASS1_TOP_SOURCE_GHOST_RESTORE`; `PARSE_OK_BRANCH_J_PASS1_LITERAL_SOURCE_AUTHORITY`; `PARSE_OK_BRANCH_J_PASS1_FINAL_SOURCE` | Final accepted-candidate probes: `step20_branch_j_pass1_source_shell_startup_final` PASS; `step20_branch_j_pass1_source_shell_tab_only_final` PASS=4; `step20_branch_j_pass1_source_shell_hierarchy_sidebar_literal_authority` PASS | `Logs/vp_perf_runtime_summary_step20_branch_j_pass1_source_shell_final_runtime_summary_20260731T183826Z_*` | User reported: "Looks okay on this end." Manual acceptance recorded 2026-07-31. | Pending user action | Server source authority now returns fixed `vp_trade`; runtime source fallback helpers no longer fall back to `export_sales`; hidden source ghost input remains rendered by original contract-backed top-bar helper. Automated correctness probes pass; timing regression over J-0 is accepted for this pass so J-2 can begin. |
| Pass 2 | Accepted | `Programs/app_source/server/03_core_reactives_and_ui.R` | `PARSE_OK_BRANCH_J_PASS2_CORE_SHARED_KEYS`; `PARSE_OK_BRANCH_J_PASS2_COMPARISON_KEYS`; `PARSE_OK_BRANCH_J_PASS2_CORE_SHARED_KEYS_REPAIR`; `PARSE_OK_BRANCH_J_PASS2_COMPARISON_KEYS_REPAIR`; `PARSE_OK_BRANCH_J_PASS2_CORE_ONLY_REPAIR`; `PARSE_OK_BRANCH_J_PASS2_COMPARISON_RESTORED` | Final accepted-candidate probe: `step20_branch_j_pass2_core_shared_key_only` PASS=11. Targeted inline Data-tab smoke: `PASS_BRANCH_J_PASS2_DATA_TAB_SMOKE` with snapshot `true|true|703|1543|2|2385|Data`. Rejected probes: `step20_branch_j_pass2_current_data_shared_keys` PARTIAL=1/PASS=10; rerun PARTIAL=1/PASS=10; `step20_branch_j_pass2_current_data_shared_keys_repair` PARTIAL=11. | `Logs/vp_perf_runtime_summary_step20_branch_j_pass2_core_shared_key_only_runtime_summary_20260731T192159Z_*` | User reported: "J-2 seems okay." Manual acceptance recorded 2026-07-31. | Pending user action | Final diff removes dead Census/Hybrid/WASDE/NASS dimensions from `filtered_data_stable_cache_key()` only. Comparison plot cache-key cleanup was attempted and rejected after readiness degraded; `04_comparison_plots.R` has no final source diff. Timing evidence is cache-key-sensitive and should be read as correctness/attribution evidence unless repeated settled-cache probes agree. |
| Pass 3 | Accepted | `Programs/app_source/server/05_trend_and_heatmap.R` | `PARSE_OK_BRANCH_J_PASS3_TREND_HEATMAP_KEYS` | `step20_branch_j_pass3_trend_heatmap_keys` PASS=4; settled rerun `step20_branch_j_pass3_trend_heatmap_keys_settled` PASS=4 | `Logs/vp_perf_runtime_summary_step20_branch_j_pass3_trend_heatmap_keys_settled_20260731T193715Z_*` | User reported: "So far so good!" Manual acceptance recorded 2026-07-31. | Pending user action | Final diff removes dead Census/Hybrid/WASDE/NASS dimensions from `historical_trend_plot_base_cache_key()` and both Trend/Heatmap `bindCache()` expressions. Settled runtime summary used the three existing fallback app-runtime JSONLs emitted by the settled probe; the primary single-action runtime path printed by the probe was not present on disk when summarized. Timing evidence is cache-key-sensitive and should be read as correctness/attribution evidence unless repeated settled-cache probes agree. |
| Pass 4 | Accepted | `Programs/app_source/server/02_partner_and_notes.R` | `PARSE_OK_BRANCH_J_PASS4_MAP_RUNTIME_KEY` | `step20_branch_j_pass4_map_runtime_key` PASS=4; settled rerun `step20_branch_j_pass4_map_runtime_key_settled` PASS=4 | `Logs/vp_perf_runtime_summary_step20_branch_j_pass4_map_runtime_key_settled_20260731T195157Z_*` | User reported: "Map tab still looks great." Manual acceptance recorded 2026-07-31. | Pending user action | Final diff removes dead Census/Hybrid/WASDE/NASS/PSD-only dimensions from `map_runtime_stable_data_cache_key()`. `04_comparison_plots.R` was inspected but not edited because the actual Map runtime key lives in `02_partner_and_notes.R` and the prior J-2 comparison-key cleanup attempt showed comparison keys are readiness-sensitive. Timing evidence is cache-key-sensitive and should be read as correctness/attribution evidence unless repeated settled-cache probes agree. |
| Pass 5 | Accepted | `Programs/app_source/server/04_comparison_plots.R`; `Programs/app_source/server/03_core_reactives_and_ui.R`; `Programs/app_source/server/01_state_and_custom_types.R`; `Programs/app_source/server/02_partner_and_notes.R` | `PARSE_OK_BRANCH_J_PASS5_CCT_SOURCE_CLEANUP`; temporary smoke validator parse marker `PARSE_OK_BRANCH_J_PASS5_CCT_SMOKE_TMP`; `PARSE_OK_BRANCH_J_PASS5_CCT_LABEL_FIX`; `PARSE_OK_BRANCH_J_PASS5_CCT_HIST_SLIDER_SYNC`; temporary hierarchy-sync validator parse marker `PARSE_OK_BRANCH_J_PASS5_CCT_HIERARCHY_SYNC_TMP`; final parse marker `PARSE_OK_BRANCH_J_PASS5_FINAL_CCT_FOLLOWUPS` | Focused CCT-only `shinytest2` smoke passed with `VP_CCT_SMOKE_J5_PASS=TRUE` and `VP_CCT_SMOKE_J5_CANDIDATE=Asparagus`; targeted label text search found no remaining `Right panel rice type`, `Top-right rice type`, `Bottom-left rice type`, or `Bottom-right rice type` strings; focused hierarchy-sync smoke passed with `VP_CCT_HIERARCHY_SYNC_PASS=TRUE`, initial Commodity `Artichokes`, post-Dry-pulses Commodity `Austrian winter peas`, Type `All`, and `hist_years=1`; final parse and `git diff --check` passed | User reported: "J-5 Seems fine. Let's continue". Manual acceptance recorded 2026-07-31. | Pending user action | Final diff removes direct hidden-source-input control from Custom Comparison plot-output source logging, VP panel commodity argument gating, and overlay helper source calls. Manual-review follow-ups remove legacy rice wording from Custom Comparison panel type dropdown labels and synchronize stale Custom Comparison Type / VP Commodity inputs when top-bar hierarchy changes make their current values invalid. The temporary validators `System/Testing/vp_cct_smoke_j5_tmp.R` and `System/Testing/vp_cct_hierarchy_sync_tmp.R` were added only for focused smokes and then deleted. The first attempted CCT-only `Rscript -e` smoke failed before R started because PowerShell parsed JavaScript `||` in the one-liner; file-based validators resolved that shell quoting/parsing issue. `get_errors` is clean for `02_partner_and_notes.R`, `03_core_reactives_and_ui.R`, `04_comparison_plots.R`, and this plan; it still reports existing Shiny/global-symbol static-analysis noise for `01_state_and_custom_types.R`, while executable parse/smoke/text checks pass and `git diff --check` is clean. |
| Pass 6 | Accepted | `Programs/app_source/server/02_partner_and_notes.R`; temporary validator `System/Testing/vp_myc_smoke_j6_tmp.R` added and deleted | `PARSE_OK_BRANCH_J_PASS6_MYC_SOURCE_CLEANUP`; temporary validator markers `PARSE_OK_BRANCH_J_PASS6_MYC_SMOKE_TMP`, `PARSE_OK_BRANCH_J_PASS6_MYC_SMOKE_TMP_REPAIR`, `PARSE_OK_BRANCH_J_PASS6_MYC_SMOKE_TMP_DIAG`, `PARSE_OK_BRANCH_J_PASS6_MYC_SMOKE_TMP_BOUNDED`; final source marker `PARSE_OK_BRANCH_J_PASS6_FINAL_MYC_SOURCE_CLEANUP` | Bounded focused MYC smoke passed with `VP_MYC_SMOKE_J6_PASS=TRUE`, country-mode choices `19`, type-mode choices `2`, country cutoff `5`, and type cutoff `5`. Rejected/over-broad smoke checks: visible cutoff control and plot readiness were not pursued after diagnostics showed server-side MYC controls were populated while the visibility check was brittle and MYC is known slow/buggy. | Not generated | User reported: "Great! J-6 looks fine to me." Manual acceptance recorded 2026-07-31. | Pending user action | Market Year Comparison Tool. Final diff canonicalizes source authority in MYC-owned snapshot/share/type-mode helper paths and MYC trace/perf source payloads. `06_pace_analysis_and_reset.R` proved to be Pace-owned despite nearby shared comparison controls, so it was left for J-7 unless future MYC validation proves otherwise. Temporary smoke validator was deleted after passing bounded validation. Smoke-generated untracked partition artifacts were removed; an accidental broad cache cleanup was immediately corrected with `git restore -- System/Cache`, and final status confirmed only this ledger and `02_partner_and_notes.R` remain changed. |
| Pass 7 | Awaiting manual validation | `Programs/app_source/server/06_pace_analysis_and_reset.R`; `Programs/app_source/server/05_trend_and_heatmap.R`; `Programs/app_source/server/02_partner_and_notes.R`; temporary validator `System/Testing/vp_pace_smoke_j7_tmp.R` added and deleted | `PARSE_OK_BRANCH_J_PASS7_PACE_PSD_INITIAL`; `PARSE_OK_BRANCH_J_PASS7_PACE_PSD_OBSERVERS`; `PARSE_OK_BRANCH_J_PASS7_PACE_PSD_WASDE_CLEANUP`; `PARSE_OK_BRANCH_J_PASS7_PACE_NO_PSD_WASDE_REMAINDERS`; `PARSE_OK_BRANCH_J_PASS7_PACE_SHARED_PSD_REMOVAL`; `PARSE_OK_BRANCH_J_PASS7_PACE_SHARED_WASDE_REMOVAL`; `PARSE_OK_BRANCH_J_PASS7_PACE_UI_SHARED_SOURCE_CLEANUP`; temporary validator markers `PARSE_OK_BRANCH_J_PASS7_PACE_SMOKE_TMP`, `PARSE_OK_BRANCH_J_PASS7_PACE_SMOKE_TMP_DIAG`, `PARSE_OK_BRANCH_J_PASS7_PACE_SMOKE_TMP_CLICK_NAV`, `PARSE_OK_BRANCH_J_PASS7_PACE_SMOKE_TMP_RADIO_VALUE`; final touched-source marker `PARSE_OK_BRANCH_J_PASS7_FINAL_TOUCHED_SOURCE` | Focused Pace smoke passed with `VP_PACE_SMOKE_J7_PASS=TRUE`, tab `Pace Analysis Tool`, projection source `historical`, target note text showing the historical-average note, KPI present `TRUE`, plot present `TRUE`, and DOM ids confirming `pace_projection_source`, target buttons, `pace_target_note`, `pace_kpi_ui`, `pace_gauges_combined_ui`, `pace_plot`, and `pace_hist_note`. Final targeted remnant searches were empty and final `git diff --check` was clean. | Not generated | Pending; user reported during validation that they can manually navigate to Pace, see the Year-End Projections block, and toggle projection type. | Pending user action | Pace Analysis Tool. Source cleanup removed Pace PSD estimate state/helpers/observers/UI output, simplified default target notes to historical-only VP behavior, removed impossible WASDE/Hybrid plot labels, removed the dead `pace_target_source_ui` UI placeholder, and deleted orphaned Pace-specific PSD/WASDE helper definitions after search proved no callers remained. Targeted remnant searches found no `pace_psd`, `pace_use_psd`, `Use PSD Estimate`, Pace helper names, or direct hidden-source-input references in the Pace owner file. Temporary validator was deleted after passing. `get_errors` is clean for this plan, `02_partner_and_notes.R`, and `06_pace_analysis_and_reset.R`; `05_trend_and_heatmap.R` still reports known Shiny/global-symbol static-analysis noise while executable parse is clean. |

| Pass J-0R | Complete | This plan; read-only B0 probes | Markdown diagnostics and `git diff --check` pending after ledger update | `step20_branch_j_j0r_intermediate_vp_quantity_sanity` PASS; `step20_branch_j_j0r_intermediate_canonical` PARTIAL=1/PASS=10; `step20_branch_j_j0r_intermediate_tab_only` PASS=4; `step20_branch_j_j0r_intermediate_hierarchy_sidebar` PASS | Runtime summaries generated: `step20_branch_j_j0r_intermediate_canonical_runtime_summary` at 20260731T223652Z; `step20_branch_j_j0r_intermediate_tab_only_runtime_summary` at 20260731T223701Z; `step20_branch_j_j0r_intermediate_hierarchy_sidebar_runtime_summary` at 20260731T223708Z | Not required for no-source-edit B0; J-7 manual validation still pending separately | Pending user action | B0 is the immediate post-J-7/pre-reopen baseline. Canonical partial is current baseline state caused by a first group-change visible-ready timeout, not a reopened source-edit regression. |
| Pass 7 manual acceptance addendum | Accepted | This plan | Not applicable | Existing Pass 7 focused Pace smoke remains controlling automated evidence | Not generated | User manual validation accepted 2026-08-01: Pace Analysis Tool seems to be working properly. | Pending user action | This addendum supersedes the stale manual-validation caveat in the original Pass 7 evidence row above. |
| Pass J-1R attempt 1 | Rejected / reverted | `Programs/app_source/server/02_partner_and_notes.R`; `Programs/app_source/ui.R`; temporary validator `System/Testing/vp_source_spoof_smoke_j1r_tmp.R` | `PARSE_OK_BRANCH_J_J1R_MAIN_TABS_SOURCE_AUTHORITY`; temporary validator markers through `PARSE_OK_BRANCH_J_J1R_SOURCE_SPOOF_SMOKE_TMP_POST_WAIT`; revert marker `PARSE_OK_BRANCH_J_J1R_SOURCE_AUTHORITY_REVERT` | Adversarial spoof smoke passed with `VP_SOURCE_SPOOF_SMOKE_J1R_PASS=TRUE`; startup `step20_branch_j_j1r_source_authority_startup` FAIL; tab-only `step20_branch_j_j1r_source_authority_tab_only` PARTIAL=2/PASS=2; hierarchy/sidebar `step20_branch_j_j1r_source_authority_hierarchy_sidebar` FAIL; post-revert tab-only `step20_branch_j_j1r_source_authority_revert_tab_only` PARTIAL=4 | Runtime summary generated for rejected tab-only attempt: `step20_branch_j_j1r_source_authority_tab_only_runtime_summary` at 20260731T231030Z | Not accepted | Pending user action | Source edit was reverted; no final product-source diff remains from this attempt. The spoof smoke proved the risk is real and testable, but the main-tabs render/profile edit is too readiness-sensitive to carry forward without a narrower repair. |
| Pass J-1R attempt 2 | Rejected / reverted | `Programs/app_source/server/02_partner_and_notes.R`; temporary validator `System/Testing/vp_source_spoof_smoke_j1r_tmp.R` added and deleted | `PARSE_OK_BRANCH_J_J1R_SOURCE_GHOST_GUARD`; `PARSE_OK_BRANCH_J_J1R_SOURCE_GHOST_GUARD_FALLBACK`; temporary spoof marker `PARSE_OK_BRANCH_J_J1R_SOURCE_SPOOF_SMOKE_TMP`; revert marker `PARSE_OK_BRANCH_J_J1R_SOURCE_GUARD_REVERT` | Guard/fallback spoof smoke passed: initial and post-spoof shell both `vp_trade`/`non_psd`, expected count 8, all eight VP tabs present; startup `step20_branch_j_j1r_source_guard_startup` FAIL then settled rerun `step20_branch_j_j1r_source_guard_startup_settled` PASS; tab-only `step20_branch_j_j1r_source_guard_tab_only` PARTIAL=3/PASS=1 and settled rerun `step20_branch_j_j1r_source_guard_tab_only_settled` PARTIAL=2/PASS=2; hierarchy/sidebar `step20_branch_j_j1r_source_guard_hierarchy_sidebar` FAIL and settled rerun `step20_branch_j_j1r_source_guard_hierarchy_sidebar_settled` FAIL | Runtime summaries not generated for attempt 2 because source edit was rejected on broader readiness probes | Not accepted | Pending user action | Narrow hidden-source guard fixed the direct spoof state but still could not satisfy broader readiness gates against B0. Product-source edit and temporary validator were reverted/deleted; no final product-source diff remains. |
| Pass J-1R readiness attempt 1 | Rejected / reverted | `Programs/app_source/server/03_core_reactives_and_ui.R` | `PARSE_OK_BRANCH_J_J1R_COUNTRY_SORT_STARTUP_FALLBACK`; revert marker included in `PARSE_OK_BRANCH_J_J1R_READINESS_DIFF_REPAIR` | Startup `step20_branch_j_j1r_country_sort_startup_fallback_startup` FAIL with missing `country_choice|commodity_choice` while comparison plot was visible | Not generated | Not accepted | Pending user action | Allowing `country_choice_options()` to render before `country_sort` exists did not fix required-control initialization. This falsified the country-sort gating hypothesis. Source edit was reverted. |
| Pass J-1R readiness attempt 2 | Rejected / reverted | `Programs/app_source/server/01_state_and_custom_types.R`; `Programs/app_source/server/03_core_reactives_and_ui.R` | `PARSE_OK_BRANCH_J_J1R_SIDEBAR_OUTPUT_UNSUSPEND`; revert marker `PARSE_OK_BRANCH_J_J1R_READINESS_EXPERIMENT_REVERT`; repair marker `PARSE_OK_BRANCH_J_J1R_READINESS_DIFF_REPAIR` | Startup `step20_branch_j_j1r_sidebar_unsuspend_startup` PASS with required controls present; tab-only `step20_branch_j_j1r_sidebar_unsuspend_tab_only` PARTIAL=4. Runtime summary `step20_branch_j_j1r_sidebar_unsuspend_tab_only_runtime_summary` generated at 20260801T003516Z. | Runtime summary `Logs/vp_perf_runtime_summary_step20_branch_j_j1r_sidebar_unsuspend_tab_only_runtime_summary_20260801T003516Z_*` | Not accepted | Pending user action | Unsuspending both nested sidebar outputs fixed the startup required-control gate but worsened tab visible-ready timing, so it was too blunt. Source edit was reverted. |
| Pass J-1R readiness attempt 3 | Rejected / reverted | `Programs/app_source/server/01_state_and_custom_types.R` | `PARSE_OK_BRANCH_J_J1R_COMMODITY_ONLY_UNSUSPEND`; revert marker `PARSE_OK_BRANCH_J_J1R_COMMODITY_ONLY_REVERT` | Startup `step20_branch_j_j1r_commodity_only_unsuspend_startup` PASS; tab-only `step20_branch_j_j1r_commodity_only_unsuspend_tab_only` PASS=4; hierarchy/sidebar `step20_branch_j_j1r_commodity_only_unsuspend_hierarchy_sidebar` FAIL with `resolved_path_not_canonical` because final Group was `Dry pulses` but final Subgroup and Market Segment remained `__all__`. Runtime summary `step20_branch_j_j1r_commodity_only_unsuspend_hierarchy_runtime_summary` generated at 20260801T005125Z. | Runtime summary `Logs/vp_perf_runtime_summary_step20_branch_j_j1r_commodity_only_unsuspend_hierarchy_runtime_summary_20260801T005125Z_*` | Not accepted | Pending user action | Commodity-only unsuspend is the best readiness result so far, but it is not acceptable because it destabilizes the dependent hierarchy cascade. Source edit was reverted; no final source diff remains. |
| Pass J-1.5 attempt 1 | Rejected / reverted | `Programs/app_source/server/02_partner_and_notes.R` | `PARSE_OK_BRANCH_J_J15_PROFILE_DIAGNOSTIC_AUTHORITY`; `PARSE_OK_BRANCH_J_J15_PROFILE_DIAGNOSTIC_AUTHORITY_REPAIR`; revert marker `PARSE_OK_BRANCH_J_J15_PROFILE_DIAGNOSTIC_AUTHORITY_REVERT` | Startup first run `step20_branch_j_j15_profile_diag_startup` FAIL with missing `country_choice|commodity_choice`, clean retry `step20_branch_j_j15_profile_diag_startup_r2` PASS; canonical first run `step20_branch_j_j15_profile_diag_canonical` PARTIAL=11/PASS=2; repaired canonical `step20_branch_j_j15_profile_diag_canonical_repair` PARTIAL=3/PASS=10; tab-only `step20_branch_j_j15_profile_diag_tab_only` PARTIAL=1/PASS=3. | Runtime summaries not generated before rejection. Exact probe outputs and fallback JSONLs were printed by each run; primary canonical repair JSONL did not materialize, matching the known runtime-log path risk. | Not accepted | Pending user action | Attempted to move main-tabs/source-shell diagnostic authority toward canonical VP source without touching `output$main_tabs`. This proved too coupled to profile recovery/readiness: the first version caused severe canonical partials, and the repaired version still failed to meet accepted H-1/B0 gates. Source edit was reverted; no final source diff remains. |
| Pass J-2a source attribution | Accepted | `Programs/app_source/server/03_core_reactives_and_ui.R`; temporary validators `System/Testing/vp_j2a_data_smoke_tmp.R` and `System/Testing/vp_j2a_downstream_smoke_tmp.R` added and deleted | `PARSE_OK_BRANCH_J_J2A_FILTERED_DATA_SOURCE_ATTRIBUTION`; `PARSE_OK_BRANCH_J_J2A_CURRENT_SUMMARY_SOURCE_ATTRIBUTION`; temporary validator markers `PARSE_OK_BRANCH_J_J2A_DATA_SMOKE_TMP`, `PARSE_OK_BRANCH_J_J2A_DATA_SMOKE_TMP_R2`, `PARSE_OK_BRANCH_J_J2A_DOWNSTREAM_SMOKE_TMP`, `PARSE_OK_BRANCH_J_J2A_DOWNSTREAM_SMOKE_TMP_CCT_PACE` | Startup first run `step20_branch_j_j2a_filtered_data_source_attr_startup` FAIL with known intermittent missing `country_choice|commodity_choice`; clean retry `step20_branch_j_j2a_filtered_data_source_attr_startup_r2` PASS; expanded startup `step20_branch_j_j2a_current_summary_source_attr_startup` PASS; Data smoke passed twice with `VP_J2A_DATA_SMOKE_PASS=TRUE|active_tab=Data|source=vp_trade|table_text_len=2634`; bounded CCT/Pace downstream smoke passed with `VP_J2A_DOWNSTREAM_SMOKE_PASS=TRUE|myc=skipped_known_buggy_surface|cct_candidate=Artichokes|pace_projection=historical|pace_target=5,274|pace_note_len=136|pace_kpi_len=747` | Not generated | User manual validation accepted 2026-08-01: everything is looking good. | Pending user action | Final diff is source-attribution/fallback cleanup only. `filtered_data_for_country()`, `filtered_data()`, `most_recent()`, `historical_avg()`, and `current_year_data()` now report/use canonical VP source where this pass touched active Current/Data/shared helper paths. `comparison_plot_base_cache_key()` and broader comparison cache keys were intentionally left unchanged. The first over-broad downstream validator failed on MYC/control-state brittleness and radio/selectize reads (`cct_candidate=NA`, MYC mode `<null>`, Pace projection `<null>`); per user guidance, MYC was not chased and the validator was narrowed to CCT/Pace. Temporary validators were deleted after use. |
| Pass J-8 closeout | Complete | This plan; parent plan; `Programs/app_source/server/03_core_reactives_and_ui.R`; read-only final probes and runtime summaries | Final source parse marker `PARSE_OK_BRANCH_J_J2A_FINAL_CORE_REACTIVES`; final closeout parse markers pending in hygiene notes | `step20_branch_j_vp_contract_post` PASS; `step20_branch_j_source_state_post` PASS=13; `step20_branch_j_tab_only_post` PASS=4; `step20_branch_j_hierarchy_sidebar_post` PASS | Runtime summaries generated: `Logs/vp_perf_runtime_summary_step20_branch_j_source_state_post_runtime_summary_20260801T231534Z_*`; `Logs/vp_perf_runtime_summary_step20_branch_j_tab_only_post_runtime_summary_20260801T231542Z_*`; `Logs/vp_perf_runtime_summary_step20_branch_j_hierarchy_sidebar_post_runtime_summary_20260801T231547Z_*` | User accepted J-2a and moved to J-8 on 2026-08-01. | Pending user action | Final closeout preserved visible behavior and closed Branch J as cleanup/attribution work. Final canonical total 210273 ms; tab-only total 121700 ms; hierarchy/sidebar total 125906 ms with hierarchy stage 46925 ms. Compared with J-0R B0, final canonical improved from PARTIAL=1/PASS=10 to PASS=13, tab-only improved from 160847 ms to 121700 ms, and hierarchy/sidebar improved from 158374 ms / 61962 ms hierarchy to 125906 ms / 46925 ms hierarchy. These are good closeout results but still cache/session sensitive; Branch J should not claim a broad speed win over all historical baselines. |

## Bugs, Blockers, Failed Attempts, Rejected Approaches

- Known blocker to avoid: starting with observer deletion. Source authority, ghost input, tab profile logic, and active cache keys must stabilize before observers are removed.
- Known blocker to avoid: removing `data_source_choice` from the DOM. Keep the hidden fixed VP-only ghost input in Branch J.
- Known blocker to avoid: changing tab titles or internal tab values. Both are contracts.
- Known blocker to avoid: treating clone-era helper names as dead-code proof. Trace active VP use first.
- Known risk: probes and client JavaScript have direct `data_source_choice` dependencies.
- Known risk: runtime log requested paths often do not materialize; use exact fallback JSONLs printed by probes.
- Known risk: Shiny idle can be noisy; prefer explicit readiness, visible controls, output checks, and manual confirmation.
- Failed attempt recorded 2026-07-31: a three-probe wrapper timed out at 120 seconds and was killed after the canonical baseline had produced one PASS, one visible-ready PARTIAL, and had started the third action. No output artifacts were flushed by that wrapper. Resolution: reran canonical, tab-only, and hierarchy/sidebar baselines as standalone commands with full wait.
- J-1 failed attempt recorded 2026-07-31: broad first-pass source-shell simplification also changed tab/profile helpers and client profile expectation. Startup and hierarchy/sidebar passed, but tab-only degraded to `PARTIAL=2|PASS=2`. Resolution: restored tab/profile helpers and client profile function to original behavior.
- J-1 failed attempt recorded 2026-07-31: changing hidden `data_source_choice` to `selectize = FALSE` did not clear the tab-only Map timeout. Resolution: restored the original selectize binding for the hidden ghost input.
- J-1 failed attempt recorded 2026-07-31: using `runtime_default_source_choice()` inside `current_source_choice_safe()` allowed tab-only to pass but hierarchy/sidebar failed once with `resolved_path_not_canonical`. Resolution: restored top-bar source ghost construction to the original contract-backed renderer and changed `current_source_choice_safe()` to return fixed `vp_trade` directly.
- J-1 residual risk: final probes pass, but final J-1 timing remains slower than J-0 baseline. Tab-only total increased from 160504 ms to 200879 ms; hierarchy/sidebar total increased from 163540 ms to 204220 ms; hierarchy-change total increased from 61620 ms to 71051 ms. This violates the timing gate unless the cleanup benefit is explicitly accepted after manual validation.
- J-2 failed attempt recorded 2026-07-31: initial cache-key cleanup also normalized/thinned `comparison_plot_base_cache_key()` in `04_comparison_plots.R`. Canonical probe degraded to `PARTIAL=1|PASS=10`, repeatedly timing out the first group-change visible-ready check near the 20 second threshold. Resolution: stop treating comparison plot cache-key cleanup as part of J-2 and restore the comparison file.
- J-2 failed attempt recorded 2026-07-31: a partial comparison-key repair restored dead non-VP fields but kept normalized VP values in the comparison base key. Canonical probe degraded further to `PARTIAL=11` with stale-output/full-idle failures. Resolution: restore `comparison_plot_base_cache_key()` completely to its pre-J-2 expression shape and retain only `filtered_data_stable_cache_key()` cleanup.
- Reopened-plan update failed attempt recorded 2026-07-31: the first planning patch attempt failed before editing files because the patch tool rejected duplicate update headers for this ledger path. Resolution: retry with a single update block per file and record the failed planning-patch attempt here.
- J-1R failed attempt recorded 2026-07-31: making the main-tabs server/client shell prefer canonical VP authority over the raw hidden source input passed the direct hidden-source spoof smoke but broader startup/tab-only/hierarchy probes regressed. Resolution: revert the product-source edit, preserve the spoof smoke evidence, clean only generated untracked cache artifacts, and choose a narrower J-1R target.
- J-1R failed attempt recorded 2026-07-31: a narrower hidden-source guard plus VP fallback corrected direct spoofing, but tab-only and hierarchy/sidebar probes still failed or stayed partial after settled reruns. Resolution: revert the product-source edit, delete the temporary spoof validator, and stop J-1R source edits pending probe/readiness investigation or a different narrower cleanup target.
- J-1R readiness attempt recorded 2026-08-01: letting `country_choice_options()` fall back to alpha sort before `country_sort` exists did not fix startup required-control timeouts; `country_choice` and `commodity_choice` were still missing while `comparison_plot` was visible. Resolution: revert the source edit and keep investigating the wrapper/nested-output scheduling path.
- J-1R readiness attempt recorded 2026-08-01: unsuspending both `commodity_choice_ui` and `country_choice_ui` made startup required controls appear, proving the blocker is nested sidebar output scheduling, but it worsened tab-only visible readiness to PARTIAL=4. Resolution: revert the broad unsuspend edit and test a narrower commodity-only initialization path if continuing.
- J-1R readiness attempt recorded 2026-08-01: unsuspending only `commodity_choice_ui` improved startup and tab-only behavior, but hierarchy/sidebar failed because dependent subgroup/segment choices did not resolve before the probe set them; final path was `Dry pulses / __all__ / __all__` instead of `Dry pulses / Dried beans / Dried`. Resolution: revert the source edit and stop J-1R on a refined hierarchy-cascade readiness blocker.
- J-1.5 failed attempt recorded 2026-08-01: moving main-tabs/source-shell diagnostic authority and safe-select/source-shell logging toward canonical `current_source_choice_safe()` was not enough to be behavior-neutral. The first version used canonical source for profile mismatch recovery and degraded canonical to `PARTIAL=11|PASS=2`. A repair kept recovery aligned to the raw render source and logged canonical source separately, improving canonical to `PARTIAL=3|PASS=10`, but tab-only still degraded to `PARTIAL=1|PASS=3`. Resolution: revert the source edit, record the attempt, and do not replay this diagnostic-authority path unless `output$main_tabs` render-source authority is separately re-scoped.
- J-2a validation attempt recorded 2026-08-01: first startup after the filtered-data source-attribution edit failed with missing `country_choice|commodity_choice` while the comparison plot was visible, matching the known intermittent required-control startup pattern. Resolution: reran once without further source edits; retry passed, and the expanded Current/Summary startup later passed.
- J-2a validation attempt recorded 2026-08-01: an over-broad temporary downstream smoke tried to validate CCT, MYC, and Pace together and failed on brittle control-state reads (`cct_candidate=NA`, MYC mode `<null>`, Pace radio value `<null>`) while still showing populated default output state. Resolution: per user guidance that MYC is buggy and should not consume validation time, narrowed the temporary downstream validator to CCT/Pace only, fixed radio input reads, explicitly skipped MYC, reran successfully, and deleted the validator.
- J-2 probe note recorded 2026-07-31: a first inline Data-tab smoke reached the visible raw data table but failed because the smoke read only the hidden `main_tabs_panel` value, which was blank in that browser state. Resolution: reran the inline smoke using the active-tab fallback pattern from the repo probes; it passed with active tab `Data` and visible `raw_data_table`.
- J-4 scope correction recorded 2026-07-31: the plan's likely J-4 file listed `04_comparison_plots.R`, but local inspection showed the actual Map runtime source cache key is owned by `02_partner_and_notes.R`, while `map_plot` and bottom-panel render logic live in `05_trend_and_heatmap.R`. Resolution: keep J-4 source edit limited to the owning Map runtime key and leave comparison plot cache keys/render bodies untouched.
- J-5 validation attempt recorded 2026-07-31: the full existing `vp_shinytest_smoke.R` was started because it contains Custom Comparison quick-apply assertions, but it did not emit a final sentinel in the available terminal buffer and was killed before completion to avoid waiting on a broad smoke suite. Resolution: replace it with a narrower CCT-only smoke that checks only the controls and quick-apply behavior touched by J-5.
- J-5 validation attempt recorded 2026-07-31: a first inline CCT-only `Rscript -e` smoke failed before R started because PowerShell parsed JavaScript `||` tokens embedded in the one-liner. Resolution: moved the same focused smoke into a temporary R file, parsed it, ran it successfully, and deleted the temporary file.
- J-5 manual-review issue recorded 2026-07-31: Custom Comparison top-right, bottom-left, and bottom-right type dropdown labels still said "rice type". Resolution: changed the affected visible right/top-right/bottom-left/bottom-right panel labels to neutral "type" wording and validated parse plus targeted text search.
- J-5 manual-review/perf-log issue recorded 2026-07-31: Custom Comparison hierarchy changes could temporarily leave a stale VP Commodity/Type context feeding the shared historical slider and historical-average paths. The pasted perf log showed `group_filter=Dry pulses` while downstream work still carried `commodity_name=Artichokes`, later settling to `Austrian winter peas`. Resolution: added Custom Comparison-only invalid Type correction in `01_state_and_custom_types.R` and invalid VP Commodity correction in `02_partner_and_notes.R`; focused hierarchy-sync smoke confirmed the Dry pulses transition settles to `Austrian winter peas`, Type `All`, and finite `hist_years=1`.
- J-6 scope/risk note recorded 2026-07-31: user flagged the MYC tab, especially Country Analysis Mode, as very buggy and approved trying the cleanup while deferring if problems appear before broad MYC patches. Resolution for this pass: keep J-6 limited to source-authority cleanup and do not repair unrelated MYC interaction defects unless they are directly caused by the J-6 edit.
- J-6 trace correction recorded 2026-07-31: `06_pace_analysis_and_reset.R` initially looked like a MYC candidate because it owns shared historical/projection controls and many source fallbacks, but focused render-output search showed it is Pace output code (`pace_*` outputs) rather than the MYC output owner. Resolution: leave Pace-only cleanup for J-7 and focus J-6 on the MYC helper block in `02_partner_and_notes.R`.
- J-6 patch attempt recorded 2026-07-31: first `apply_patch` failed with `Update File Error: Duplicate Path` because the same file was specified twice in one patch. Second retry failed with an `origIndex` ordering error because chunks were not in file order. Resolution: applied the same narrow source-authority edit as one file update with chunks ordered by file position; no source changes were made by the failed attempts.
- J-6 validation attempt recorded 2026-07-31: the first focused MYC smoke was too strict for the known slow/buggy MYC surface. It waited for `partner_show` visibility even though selectize hides the original input; after that repair, it still required visible `myc_cutoff_period` and plot readiness. Diagnostic output showed the important server-side state had populated (`main_tab=Market Year Comparison Tool`, `mode=country`, `partner_present=TRUE`, `partner_choices=19`, `cutoff_present=TRUE`, `cutoff_value=5`, `label_countries=TRUE`) while `cutoff_visible=FALSE`. Resolution: do not chase MYC UI visibility/plot slowness in Branch J; replace the smoke with bounded control/state assertions for mode switch, partner choice population, and cutoff value.
- J-6 cleanup correction recorded 2026-07-31: after the MYC smoke, untracked partition artifacts were removed from `System/Processed Data/vp_trade_partitions`, but an overly broad `System/Cache/*.rds` cleanup also deleted tracked cache files. Resolution: immediately restored tracked cache files with `git restore -- System/Cache`; follow-up status showed only this ledger and `02_partner_and_notes.R` remain changed.
- J-7 validation attempt recorded 2026-07-31: the first focused Pace smoke reached the Pace tab but timed out waiting for `pace_projection_source`. User manual observation confirmed the Pace tab was navigable and the Year-End Projections block was visible/toggleable in the app. Resolution: treat the first failure as a validator navigation/DOM-read problem, add visible-tab click fallback, and keep the projection assertion.
- J-7 validation attempt recorded 2026-07-31: after click navigation, the focused Pace smoke found the projection DOM but failed because the validator read a Shiny radio group container like a scalar input. Resolution: update the temporary validator input getter to read checked radio children; rerun passed.
- J-7 validation environment note recorded 2026-07-31: one rerun failed during `shinytest2::AppDriver`/Chromote initialization with `code: -32000, message: Not allowed` before any app assertion. Process inspection found no orphaned test R/Chromote process. Resolution: rerun once after inspection; the focused Pace smoke passed.
- J-7 artifact cleanup recorded 2026-07-31: after the focused Pace smoke passed, the temporary validator was deleted and untracked `System/Cache/*.rds` files created by Shiny/cache activity were removed with targeted `git clean -f -- System/Cache`. Local untracked processed-data artifacts were left untouched because they are app build/cache artifacts and may be useful for startup.

## Tranche Execution Notes

- 2026-07-31 J-0R reopened baseline start:
  - User instructed the agent to recenter on Branch J, begin, and keep moving from step to step where possible while stopping for genuine blockers.
  - J-0R opened as a measurement-only B0 baseline after J-7 source cleanup and before any reopened J-1/J-2 source edits.
  - J-7 Pace manual validation is still explicitly pending in this ledger; the agent may proceed with no-source-edit measurement work, but any source implementation should continue to record the pending manual-gate caveat unless the user later accepts J-7.
  - Worktree check before J-0R showed a pre-existing untracked `System/Processed Data/` directory. It was left untouched under the targeted artifact-cleanup rule.
- 2026-07-31 J-0R B0 baseline completion:
  - VP quantity sanity PASS with label `step20_branch_j_j0r_intermediate_vp_quantity_sanity`; output `Logs/vp_perf_probe_vp_mixed_quantity_sanity_step20_branch_j_j0r_intermediate_vp_quantity_sanity_20260731T222547Z.csv`; total 16102 ms; cache state reported as `unknown_cache_state` by the artifact-contract probe.
  - Canonical single-action B0 completed as `PARTIAL=1|PASS=10` with label `step20_branch_j_j0r_intermediate_canonical`; output `Logs/vp_perf_probe_single_action_latency_step20_branch_j_j0r_intermediate_canonical_20260731T222608Z.csv`; total 286022 ms; error `visible_not_ready:timeout` on the first group-change visible-ready check. Exact fallback JSONLs: `Logs/vp_runtime_perf_proc_20260731T222621Z_31888.jsonl|Logs/vp_runtime_perf_9700abb89aeb27946f7db7ba8bf6a1da.jsonl`.
  - Tab-only B0 PASS=4 with label `step20_branch_j_j0r_intermediate_tab_only`; output `Logs/vp_perf_probe_single_action_latency_step20_branch_j_j0r_intermediate_tab_only_20260731T223106Z.csv`; total 160847 ms; visible-ready timings were Historical Trend 10119 ms, Heatmap 9101 ms, Map 12083 ms, and Current return 9316 ms. Exact fallback JSONLs: `Logs/vp_runtime_perf_1809107e1c41ca060a62337c4f2c57b4.jsonl|Logs/vp_runtime_perf_proc_20260731T223111Z_33800.jsonl`.
  - Hierarchy/sidebar B0 PASS with label `step20_branch_j_j0r_intermediate_hierarchy_sidebar`; output `Logs/vp_perf_probe_hierarchy_sidebar_cascade_step20_branch_j_j0r_intermediate_hierarchy_sidebar_20260731T223354Z.csv`; total 158374 ms; hierarchy 61962 ms; group choice 23802 ms; subgroup choice 23181 ms; segment choice 12940 ms. Exact fallback JSONLs: `Logs/vp_runtime_perf_1809107e1c41ca060a62337c4f2c57b4.jsonl|Logs/vp_runtime_perf_proc_20260731T223111Z_33800.jsonl|Logs/vp_runtime_perf_dc1aed543b2bef498da9587a5222b97d.jsonl|Logs/vp_runtime_perf_proc_20260731T223357Z_33000.jsonl`.
  - Runtime summaries generated from the exact printed fallback JSONLs: `Logs/vp_perf_runtime_summary_step20_branch_j_j0r_intermediate_canonical_runtime_summary_20260731T223652Z_{files,events,timed,key_delta,churn,partition,memory}.csv`, `Logs/vp_perf_runtime_summary_step20_branch_j_j0r_intermediate_tab_only_runtime_summary_20260731T223701Z_{files,events,timed,key_delta,churn,partition,memory}.csv`, and `Logs/vp_perf_runtime_summary_step20_branch_j_j0r_intermediate_hierarchy_sidebar_runtime_summary_20260731T223708Z_{files,events,timed,key_delta,churn,partition,memory}.csv`.
  - Runtime summary highlights: canonical top timed rows were client tab events and startup VP monthly artifact load; canonical top churn rows were display-month mapping cache hits, map bottom-panel gated skips, year-filter sync, and summary table execution. Tab-only and hierarchy/sidebar summaries showed the same broad churn families.
- 2026-07-31 J-1R source-authority experiment 1 rejected and reverted:
  - Local hypothesis: `output$main_tabs`, the main-tabs normalization observer, and client main-tabs/source-shell snapshots still used raw `input$data_source_choice` / hidden-input values for shell authority even though `current_source_choice_safe()` is fixed to `vp_trade`; changing those shell paths to canonical VP authority should prevent hidden-source spoofing from switching main tab profile without changing normal visible behavior.
  - First patch attempts failed before editing because the patch tool rejected duplicate file headers and then out-of-order chunks for `02_partner_and_notes.R`; the successful retry kept chunks in file order.
  - Source edit touched `Programs/app_source/server/02_partner_and_notes.R` and `Programs/app_source/ui.R`, then parsed cleanly with `PARSE_OK_BRANCH_J_J1R_MAIN_TABS_SOURCE_AUTHORITY`. `ui.R` diagnostics were clean; `02_partner_and_notes.R` continued to show known Shiny/server-fragment global-symbol static-analysis noise; `git diff --check` was clean.
  - Temporary validator `System/Testing/vp_source_spoof_smoke_j1r_tmp.R` was created. Initial run failed before app assertions because `NOT_CRAN` was not set. Follow-up repairs added `NOT_CRAN`, softened polling waits, switched the snapshot payload to JSON, and softened the post-spoof wait; parse markers passed for each repair and diagnostics stayed clean.
  - Final adversarial smoke passed: after forcing hidden `data_source_choice` to `psd`, the DOM input value became `psd` but the main-tabs shell remained `data-main-tabs-source=vp_trade`, `data-main-tabs-profile=non_psd`, expected count `8`, and all eight VP tabs remained present with no PSD-only tabs.
  - Broader validation did not support accepting the edit: startup probe `step20_branch_j_j1r_source_authority_startup` failed because `country_choice` and `commodity_choice` did not appear before timeout; tab-only probe `step20_branch_j_j1r_source_authority_tab_only` degraded to `PARTIAL=2|PASS=2`; hierarchy/sidebar probe `step20_branch_j_j1r_source_authority_hierarchy_sidebar` failed with `resolved_path_not_canonical`.
  - The source edit was reverted by inverse patch. Revert parse passed with `PARSE_OK_BRANCH_J_J1R_SOURCE_AUTHORITY_REVERT`, and `git diff --check` was clean for `02_partner_and_notes.R` and `ui.R`. `git diff --stat` then showed no tracked source diff for those files.
  - A post-revert tab-only probe `step20_branch_j_j1r_source_authority_revert_tab_only` still reported `PARTIAL=4`, indicating the late browser/probe environment was noisy after heavy concurrent runs rather than proving a retained product-source diff. Process inspection found no leftover AppDriver R/Shiny process; R processes were VS Code R extension services and Edge looked like the normal user profile. Untracked `System/Cache/*.rds` artifacts generated by probes were removed with targeted `git clean -f -- System/Cache`, leaving logs and pre-existing `System/Processed Data/` untouched.
- 2026-07-31 J-1R source-authority experiment 2 rejected and reverted:
  - Narrower hypothesis: keep the existing main-tabs render/profile path intact, but add a high-priority hidden `data_source_choice` guard that resets any non-`vp_trade` value back to the fixed VP-only ghost input choice. This should address the spoofing risk without changing normal main-tabs rendering.
  - Initial guard parsed with `PARSE_OK_BRANCH_J_J1R_SOURCE_GHOST_GUARD`, but the spoof smoke showed the hidden input reset while the main-tabs shell could still stamp `data-main-tabs-source=export_sales` before input initialization. A small fallback repair changed the main-tabs raw-input fallback from legacy `export_sales` to `runtime_default_source_choice()` and parsed with `PARSE_OK_BRANCH_J_J1R_SOURCE_GHOST_GUARD_FALLBACK`.
  - Final spoof smoke passed for the guard/fallback experiment: initial and post-spoof snapshots both showed `input_source=vp_trade`, `shell_source=vp_trade`, `shell_profile=non_psd`, expected count `8`, all eight VP tabs present, no missing tabs, and no PSD-only tabs.
  - Broader validation still did not support acceptance. Startup first failed after cache cleanup because `country_choice` and `commodity_choice` were missing, then settled startup passed. Tab-only stayed partial after settled rerun: `step20_branch_j_j1r_source_guard_tab_only` PARTIAL=3/PASS=1 and `step20_branch_j_j1r_source_guard_tab_only_settled` PARTIAL=2/PASS=2. Hierarchy/sidebar failed both times: `step20_branch_j_j1r_source_guard_hierarchy_sidebar` and `step20_branch_j_j1r_source_guard_hierarchy_sidebar_settled`, with canonical-path/readiness errors.
  - Because broader readiness gates did not recover to B0, the guard/fallback source edit was reverted and the temporary spoof validator was deleted. Revert parse passed with `PARSE_OK_BRANCH_J_J1R_SOURCE_GUARD_REVERT`; `git diff --check` was clean; `git diff --stat` showed no tracked diff for `02_partner_and_notes.R`, `ui.R`, or the temporary validator.
  - J-1R is now blocked rather than accepted: the hidden-source spoofing risk is real and directly testable, but the source-shell/main-tabs path is too readiness-sensitive under current probes to change safely without first investigating probe/readiness instability or choosing a different, narrower source-token cleanup target.
  - Final cleanup/validation: regenerated untracked `System/Cache/*.rds` files were removed with targeted `git clean -f -- System/Cache`; evidence logs and pre-existing `System/Processed Data/` were left untouched. Final diagnostics were clean for this ledger and `ui.R`; `02_partner_and_notes.R` continued to show known Shiny/server-fragment global-symbol noise. Final `git diff --check` was clean, and tracked diff was ledger-only.
- 2026-08-01 J-1R readiness/probe instability investigation:
  - User asked to resolve J-1R readiness/probe instability first because top bar/sidebar initialization is taking a long time and may reveal a real speed improvement.
  - B0 vs failed J-1R tab-only evidence showed that bad runs were not dominated by one R render body; Shiny output value and Plotly/svg readiness arrived much later, and `main_tabs_mount` / tab-after-paint timings were also later. Startup failures specifically missed `country_choice` and `commodity_choice` while `comparison_plot` could already be visible.
  - Read-only inspection found `country_choice` and `commodity_choice` are nested inside `output$market_year_compare_filters_ui`; `market_year_compare_filters_ui` is unsuspended, but nested `commodity_choice_ui` and `country_choice_ui` are normally suspended by Shiny visibility/scheduling rules. B0 runtime evidence showed `country_choice_ui()` itself is fast once executed.
  - Experiment 1 allowed `country_choice_options()` to proceed before `country_sort` existed by using an alpha fallback. Startup still failed with missing `country_choice|commodity_choice`, so country-sort gating was not the primary blocker. The edit was reverted.
  - Experiment 2 unsuspended both nested sidebar outputs. Startup required controls appeared, proving nested-output scheduling is involved, but tab-only degraded to PARTIAL=4. The edit was too broad and was reverted.
  - Experiment 3 unsuspended only `commodity_choice_ui`. Startup passed and tab-only passed with PASS=4, but hierarchy/sidebar failed because dependent subgroup/segment choices did not resolve before the probe set them; final hierarchy path was `Dry pulses / __all__ / __all__`. The edit was reverted.
  - Current conclusion: there is a real readiness issue in the sidebar dependency chain, but the acceptable fix is not simply unsuspending nested outputs. The next investigation should focus on the hierarchy cascade and probe sequencing around dependent Group/Subgroup/Market Segment choices before more Branch J source cleanup.

- 2026-08-01 J-7 manual acceptance:
  - User manually confirmed the Pace Analysis Tool seems to be working properly.
  - J-7 Pace Analysis Tool inherited-source cleanup is accepted after automated validation and user manual validation.
  - Git checkpoint remains pending user action.

- 2026-07-31 Planning handoff:
  - Created this Branch J daughter ledger and amended the parent ledger to delegate Step 20 / Branch J.
  - Incorporated user clarification that the VP app has one real source (`vp_trade`) and that all visible tabs, top bar, sidebar format, and workflows display VP data and must be preserved exactly.
  - Incorporated critical audit findings: fixed hidden VP-only `data_source_choice` ghost-input conversion is a Pass 1 exit gate; high-risk inherited tabs need lightweight smoke assertions; hygiene must cover all touched files; Pass 0 plan-only checkpointing is optional.
  - No Branch J source-code cleanup has started.
  - Validation at handoff: markdown diagnostics clean and plan-file `git diff --check` clean.
- 2026-07-31 J-0 baseline completion:
  - Parse baselines passed for `02_partner_and_notes.R`, `03_core_reactives_and_ui.R`, `ui.R`, `vp_perf_probe_single_action_latency.R`, and `vp_perf_probe_hierarchy_sidebar_cascade.R`.
  - Canonical single-action baseline completed with PASS=11. Output CSV: `Logs/vp_perf_probe_single_action_latency_step20_branch_j_source_state_baseline_20260731T174059Z.csv`. Runtime JSONLs: `Logs/vp_runtime_perf_single_action_step20_branch_j_source_state_baseline_20260731T174059Z.jsonl`, `Logs/vp_runtime_perf_proc_20260731T173810Z_22500.jsonl`, `Logs/vp_runtime_perf_proc_20260731T174103Z_8620.jsonl`, `Logs/vp_runtime_perf_8ababc658137265c92581843a4eb0c2b.jsonl`. Notable timings: first hierarchy action visible-ready 19543 ms / full-idle 20164 ms; Trend tab visible-ready 8370 ms; Heatmap 8642 ms; Map 10538 ms; Current 7901 ms; total probe 217199 ms.
  - Tab-only baseline completed with PASS=4. Output CSV: `Logs/vp_perf_probe_single_action_latency_step20_branch_j_tab_only_baseline_20260731T173515Z.csv`. Runtime JSONLs: `Logs/vp_runtime_perf_single_action_step20_branch_j_tab_only_baseline_20260731T173516Z.jsonl`, `Logs/vp_runtime_perf_a0d66f3290347fef0abbf62982edfafa.jsonl`, `Logs/vp_runtime_perf_proc_20260731T173520Z_28532.jsonl`. Visible-ready timings: Historical Trend 13360 ms; Heatmap 9755 ms; Map 14729 ms; Current 10196 ms; total probe 160504 ms.
  - Hierarchy/sidebar baseline completed PASS. Output CSV: `Logs/vp_perf_probe_hierarchy_sidebar_cascade_step20_branch_j_hierarchy_sidebar_baseline_20260731T173806Z.csv`. Runtime JSONLs: `Logs/vp_runtime_perf_hierarchy_sidebar_step20_branch_j_hierarchy_sidebar_baseline_20260731T173806Z.jsonl`, `Logs/vp_runtime_perf_3230cb4a32c855c39078ce12848d9d6e.jsonl`, `Logs/vp_runtime_perf_proc_20260731T173810Z_22500.jsonl`. Notable timings: hierarchy total 61620 ms; group choice 24665 ms; subgroup choice 22906 ms; segment choice 11922 ms; total probe 163540 ms.
  - Runtime summaries generated successfully from exact JSONLs. Latest summary CSV families: `Logs/vp_perf_runtime_summary_step20_branch_j_source_state_baseline_runtime_summary_20260731T174601Z_*`, `Logs/vp_perf_runtime_summary_step20_branch_j_tab_only_baseline_runtime_summary_20260731T174608Z_*`, and `Logs/vp_perf_runtime_summary_step20_branch_j_hierarchy_sidebar_baseline_runtime_summary_20260731T174612Z_*`.
  - Runtime summary highlights: source-state canonical key deltas include `map_runtime_source_cache_key` changes in `vp_commodity_detail|commodity` and `filter_vp_rows_for_resolved_hierarchy_filtered_data` changes in `commodity_detail`; tab-only key deltas include map runtime source key changes in `vp_commodity_detail|commodity|metric` and `vp_commodity_name|unit`; hierarchy/sidebar key deltas include `map_runtime_source_cache_key` changes in `vp_commodity_name` and display-month mapping changes in `commodity_name`. Partition summaries show memory-cache and disk-cache activity for all three baselines with memory snapshots off.
  - Source-remnant classification and visible tab title/internal value inventory are now recorded above.
  - No source-code cleanup has started.
- 2026-07-31 J-1 source-shell implementation candidate:
  - Final source-code change is intentionally narrow and limited to `Programs/app_source/server/02_partner_and_notes.R`.
  - `current_source_choice_safe()` now returns fixed `vp_trade`, making server-side source authority independent of the hidden input.
  - `runtime_default_source_choice()`, `runtime_visible_source_values()`, and `normalize_runtime_source_choice()` now harden empty/error fallbacks toward `vp_trade` instead of `export_sales` when contract helpers are unavailable or return no enabled values.
  - Hidden `data_source_choice` remains rendered by the original top-bar contract-backed helper path and remains compatible with probes/client JS. No full DOM removal was attempted.
  - Broader tab/profile helper simplification was tried and rejected for J-1 after tab-only degraded to `PARTIAL=2|PASS=2`; those helper changes were reverted.
  - Parse validation passed with markers listed in the Evidence Ledger. `get_errors` returned the existing Shiny/global-symbol diagnostic noise for `02_partner_and_notes.R`; executable parse checks are clean and no source diagnostics were actionable for this local edit.
  - Final startup probe passed. Output CSV: `Logs/vp_perf_probe_startup_step20_branch_j_pass1_source_shell_startup_final_20260731T183624Z.csv`. Runtime JSONLs: `Logs/vp_runtime_perf_startup_step20_branch_j_pass1_source_shell_startup_final_20260731T183624Z.jsonl`, `Logs/vp_runtime_perf_proc_20260731T183630Z_33536.jsonl`, `Logs/vp_runtime_perf_0fea44f937eeb2445ae349a3f68e3ff2.jsonl`. Startup row confirms initial/final source `vp_trade`, required controls present, and comparison plot visible.
  - Final tab-only probe passed with PASS=4. Output CSV: `Logs/vp_perf_probe_single_action_latency_step20_branch_j_pass1_source_shell_tab_only_final_20260731T183255Z.csv`. Runtime JSONLs: `Logs/vp_runtime_perf_single_action_step20_branch_j_pass1_source_shell_tab_only_final_20260731T183255Z.jsonl`, `Logs/vp_runtime_perf_569c4dfed00b301bb9afa37bef1ed642.jsonl`, `Logs/vp_runtime_perf_proc_20260731T183300Z_32592.jsonl`. Visible-ready timings: Historical Trend 15978 ms; Heatmap 14165 ms; Map 20415 ms; Current 12718 ms; total probe 200879 ms.
  - Final hierarchy/sidebar probe passed. Output CSV: `Logs/vp_perf_probe_hierarchy_sidebar_cascade_step20_branch_j_pass1_source_shell_hierarchy_sidebar_literal_authority_20260731T182913Z.csv`. Runtime JSONLs: `Logs/vp_runtime_perf_hierarchy_sidebar_step20_branch_j_pass1_source_shell_hierarchy_sidebar_literal_authority_20260731T182913Z.jsonl`, `Logs/vp_runtime_perf_5ce0c1105f0e71fcf9162bed35ebf741.jsonl`, `Logs/vp_runtime_perf_proc_20260731T182920Z_24324.jsonl`. Notable timings: hierarchy total 71051 ms; group choice 27141 ms; subgroup choice 27277 ms; segment choice 14445 ms; total probe 204220 ms.
  - Final runtime summary generated successfully. CSV families: `Logs/vp_perf_runtime_summary_step20_branch_j_pass1_source_shell_final_runtime_summary_20260731T183826Z_*`. Top timed rows include `startup_init(total_pre_ui)`, `tab_after_paint`, `main_tabs_mount`, and VP monthly artifact read/load. Top churn rows include display-month mapping cache hits and summary/map bottom panel events.
  - Acceptance caveat: automated correctness probes pass, but timing is worse than J-0 beyond the plan's normal regression threshold. Manual validation and explicit acceptance are required before Git checkpoint and J-2.
- 2026-07-31 J-1 manual acceptance and J-2 start:
  - User manual validation accepted J-1 with: "Looks okay on this end. Please move to J-2".
  - J-1 timing regression remains documented and accepted for this pass.
  - J-2 opened for Current vs. Historical and Data shared filter/data surfaces.
- 2026-07-31 J-2 core shared key implementation candidate:
  - Final source-code change is intentionally narrow and limited to `Programs/app_source/server/03_core_reactives_and_ui.R`.
  - `filtered_data_stable_cache_key()` now removes impossible non-VP dimensions from the active VP shared data key: Census trade flow, Hybrid trade flow/mode, Census value unit, WASDE locks, and NASS lock/state/year-type fields.
  - Preserved in the key: fixed source identity via `current_source_choice_safe()`, VP trade flow, VP hierarchy selections and resolved hierarchy tokens, VP commodity name/detail, data/schema versions, commodity, country, data frequency, display-year type, metric, unit, basis, custom types/countries, custom scope, and MYC selected-data mode.
  - `Programs/app_source/server/04_comparison_plots.R` was explored for `comparison_plot_base_cache_key()` thinning but has no final source diff. The comparison cache cleanup was rejected after automated readiness degraded.
  - Parse validation passed for the touched/explored files with markers listed in the Evidence Ledger.
  - Final canonical single-action probe passed with PASS=11. Output CSV: `Logs/vp_perf_probe_single_action_latency_step20_branch_j_pass2_core_shared_key_only_20260731T190954Z.csv`. Runtime JSONLs: `Logs/vp_runtime_perf_single_action_step20_branch_j_pass2_core_shared_key_only_20260731T190954Z.jsonl`, `Logs/vp_runtime_perf_proc_20260731T191002Z_17368.jsonl`, `Logs/vp_runtime_perf_94528315219a44ca72ce816cde0c1dff.jsonl`. Notable timings: first group visible-ready 15396 ms; Current return visible-ready 13184 ms; total probe 319162 ms.
  - Targeted inline Data-tab smoke passed without creating a new probe file. It set `data_source_choice = vp_trade`, switched to `main_tabs_panel = Data`, and confirmed visible `raw_data_table` with snapshot `true|true|703|1543|2|2385|Data`.
  - Final runtime summary generated successfully. CSV families: `Logs/vp_perf_runtime_summary_step20_branch_j_pass2_core_shared_key_only_runtime_summary_20260731T192159Z_*`. Top timed rows include client tab events and startup VP monthly artifact load; top churn rows include display-month mapping cache hits, map bottom panel gated skips, year filter sync, and summary table executions.
  - Hygiene: `git diff --check` clean for touched source/plan files. `get_errors` is clean for `04_comparison_plots.R` and this plan; `03_core_reactives_and_ui.R` still reports pre-existing static-analysis noise for Shiny/global/dplyr symbols, while executable parse/probe validation is clean.
  - Acceptance caveat at the time: automated validation passed, but user manual validation was still required for Current vs. Historical, Summary Statistics, Data tab, top/sidebar filtering, and browser console before J-3.
- 2026-07-31 J-2 manual acceptance and J-3 start:
  - User manual validation accepted J-2 with: "J-2 seems okay. Let's move to J-3".
  - J-2 timing evidence remains documented as cache-key-sensitive; performance comparisons should use repeated settled-cache probes when cache key shape changes.
  - J-3 opened for Historical Trendlines and Monthly Heatmap source fallback/cache-key cleanup.
- 2026-07-31 J-3 Trend/Heatmap cache-key implementation candidate:
  - Final source-code change is intentionally narrow and limited to `Programs/app_source/server/05_trend_and_heatmap.R`.
  - `historical_trend_plot_base_cache_key()` now removes impossible non-VP dimensions from the active VP Trend/Heatmap key: Census trade flow, Hybrid trade flow/mode, Census value unit, WASDE locks, and NASS lock/state/year-type fields.
  - Preserved in the key: fixed source identity, VP trade flow, VP hierarchy selections and resolved hierarchy tokens, VP commodity name/detail, data/schema versions, commodity, country, data frequency, display-year type, metric, unit, basis, custom types/countries, and Trend-specific extension fields for year filters, historical average, projections, SD bands, and width bucket.
  - Both `timeseries_plot` and `heatmap_plot` `bindCache()` expressions were updated to match the thinned base key. No Trend/Heatmap render-body behavior, visible controls, labels, hover construction, projection logic, historical-average logic, or display-month logic was intentionally changed.
  - Parse validation passed with `PARSE_OK_BRANCH_J_PASS3_TREND_HEATMAP_KEYS`.
  - First tab-only probe passed with PASS=4. Output CSV: `Logs/vp_perf_probe_single_action_latency_step20_branch_j_pass3_trend_heatmap_keys_20260731T192957Z.csv`. Runtime JSONL printed by the probe: `Logs/vp_runtime_perf_single_action_step20_branch_j_pass3_trend_heatmap_keys_20260731T192957Z.jsonl`. Fallback runtime JSONLs: `Logs/vp_runtime_perf_fc21d9ebece5fb3c3de1e5bab6be1cff.jsonl`, `Logs/vp_runtime_perf_proc_20260731T193003Z_22396.jsonl`. Visible-ready timings: Historical Trend 16024 ms; Heatmap 14312 ms; Map 18885 ms; Current 12268 ms; total probe 200247 ms.
  - Settled tab-only rerun passed with PASS=4. Output CSV: `Logs/vp_perf_probe_single_action_latency_step20_branch_j_pass3_trend_heatmap_keys_settled_20260731T193325Z.csv`. Runtime JSONL printed by the probe: `Logs/vp_runtime_perf_single_action_step20_branch_j_pass3_trend_heatmap_keys_settled_20260731T193326Z.jsonl`. Fallback runtime JSONLs: `Logs/vp_runtime_perf_proc_20260731T193003Z_22396.jsonl`, `Logs/vp_runtime_perf_3a76ae5092d95be898bafe8401eec02d.jsonl`, `Logs/vp_runtime_perf_proc_20260731T193332Z_32972.jsonl`. Visible-ready timings: Historical Trend 15286 ms; Heatmap 14392 ms; Map 16749 ms; Current 12071 ms; total probe 200160 ms.
  - Settled runtime summary generated successfully from the exact existing fallback runtime JSONLs. CSV families: `Logs/vp_perf_runtime_summary_step20_branch_j_pass3_trend_heatmap_keys_settled_20260731T193715Z_*`. The primary single-action runtime path printed by the settled probe was not present on disk when summarized, so the summary used the three app-runtime fallback JSONLs listed above. Top timed rows include startup pre-UI, tab client events, and VP monthly artifact read/load. Top churn rows include display-month mapping cache hits, map bottom-panel gated skips, summary table execution, and year-filter sync observer events.
  - Hygiene: `git diff --check` clean for `05_trend_and_heatmap.R`. `get_errors` still reports existing Shiny/global-symbol static-analysis noise for this server fragment, while executable parse/probe validation is clean.
  - Acceptance caveat: automated validation passes, but user manual validation is still required for Historical Trendlines, Monthly Heatmap, top/sidebar filtering, year/display/projection options, labels/hover, and browser console before J-4.
- 2026-07-31 J-3 manual acceptance and J-4 start:
  - User manual validation accepted J-3 with: "So far so good! Let's move on to J-4".
  - J-3 timing evidence remains documented as cache-key-sensitive; the pass is accepted as behavior-preserving cleanup rather than a demonstrated speed win.
  - J-4 opened for Map source fallback/cache-key/bottom-panel cleanup.
- 2026-07-31 J-4 Map runtime cache-key implementation candidate:
  - Final source-code change is intentionally narrow and limited to `Programs/app_source/server/02_partner_and_notes.R`.
  - Local inspection showed the actual Map runtime source cache key is `map_runtime_stable_data_cache_key()` in `02_partner_and_notes.R`; `map_plot` and `map_bottom_panel_ui` live in `05_trend_and_heatmap.R`; `04_comparison_plots.R` has map-adjacent analysis helpers but was not the direct Map runtime-key owner for this pass.
  - `map_runtime_stable_data_cache_key()` now removes impossible non-VP dimensions from the active VP Map key: Census trade flow, Hybrid trade flow/mode, Census/WASDE/NASS value-unit/lock fields, PSD yield lock, and PSD area-unit fields.
  - Preserved in the key: fixed source identity, data frequency, display-year type, VP trade flow, VP hierarchy selections and resolved hierarchy tokens, VP commodity name/detail, commodity, metric, unit, basis, custom types, and data/schema versions.
  - No Map render-body behavior, bottom-panel render-body behavior, visible controls, labels, hover construction, or Map summary table logic was intentionally changed.
  - Parse validation passed with `PARSE_OK_BRANCH_J_PASS4_MAP_RUNTIME_KEY`.
  - First tab-only probe passed with PASS=4. Output CSV: `Logs/vp_perf_probe_single_action_latency_step20_branch_j_pass4_map_runtime_key_20260731T194500Z.csv`. Runtime JSONL printed by the probe: `Logs/vp_runtime_perf_single_action_step20_branch_j_pass4_map_runtime_key_20260731T194500Z.jsonl`. Fallback runtime JSONLs: `Logs/vp_runtime_perf_2ffa764cc42f1b4898d7e37d3bb2bfc6.jsonl`, `Logs/vp_runtime_perf_proc_20260731T194508Z_1420.jsonl`. Visible-ready timings: Historical Trend 14851 ms; Heatmap 14235 ms; Map 17179 ms; Current 12458 ms; total probe 202699 ms.
  - Settled tab-only rerun passed with PASS=4. Output CSV: `Logs/vp_perf_probe_single_action_latency_step20_branch_j_pass4_map_runtime_key_settled_20260731T194832Z.csv`. Runtime JSONL printed by the probe: `Logs/vp_runtime_perf_single_action_step20_branch_j_pass4_map_runtime_key_settled_20260731T194832Z.jsonl`. Fallback runtime JSONLs: `Logs/vp_runtime_perf_a9e1cca5edac3d74b3bbd506a8d24428.jsonl`, `Logs/vp_runtime_perf_proc_20260731T194837Z_22376.jsonl`. Visible-ready timings: Historical Trend 15518 ms; Heatmap 12778 ms; Map 19615 ms; Current 11865 ms; total probe 194500 ms.
  - Settled runtime summary generated successfully from the exact existing fallback runtime JSONLs. CSV families: `Logs/vp_perf_runtime_summary_step20_branch_j_pass4_map_runtime_key_settled_20260731T195157Z_*`. The primary single-action runtime path printed by the settled probe was not present on disk when summarized, so the summary used the two app-runtime fallback JSONLs listed above. Top timed rows include tab client events, startup pre-UI, main-tabs mount, and VP monthly artifact read/load. Top churn rows include display-month mapping cache hits, map bottom-panel gated skips, summary table execution, and year-filter sync observer events.
  - Hygiene: `git diff --check` clean for `02_partner_and_notes.R` and this plan. `get_errors` is clean for this plan and still reports existing Shiny/global-symbol static-analysis noise for `02_partner_and_notes.R`, while executable parse/probe validation is clean.
  - Acceptance caveat: automated validation passes, but user manual validation is still required for Map output, Map Summary Table/bottom panel, top/sidebar filtering, labels/hover, and browser console before J-5.
- 2026-07-31 J-4 manual acceptance and J-5 start:
  - User manual validation accepted J-4 with: "Map tab still looks great. Let's proceed!".
  - J-4 timing evidence remains documented as cache-key-sensitive; the pass is accepted as behavior-preserving cleanup rather than a demonstrated speed win.
  - J-5 opened for Custom Comparison Tool inherited-source cleanup.
- 2026-07-31 J-5 Custom Comparison implementation candidate:
  - Final source-code change is intentionally narrow and limited to `Programs/app_source/server/04_comparison_plots.R`.
  - Local inspection showed the Custom Comparison output path is owned by `comparison_left_plot`, `comparison_right_plot`, `metric_grid_plot_1` through `metric_grid_plot_4`, and `comparison_overlay_plot`; the shared `comparison_plot_base_cache_key()` is adjacent but also controls Current vs. Historical and was left unchanged because prior J-2 edits there degraded readiness.
  - Added local helper `cct_runtime_source_choice()` as a small wrapper around `current_source_choice_safe(default = "vp_trade")` for Custom Comparison output source attribution.
  - Replaced Custom Comparison plot-output `log_perf(... source = input$data_source_choice ...)` payloads with the canonical runtime source value.
  - Removed hidden-source-input conditional gating from right/grid VP commodity-name arguments; the VP app's canonical runtime source is fixed to `vp_trade`, so the visible Custom Comparison VP panel commodity selectors are always the active path.
  - Reused the canonical runtime source in overlay display-year helper calls instead of rereading `input$data_source_choice` with legacy `export_sales` fallback.
  - No Custom Comparison UI layout, quick-apply observer, selector choices, plot body construction, output IDs, or shared comparison cache-key expression was intentionally changed.
  - Parse validation passed with `PARSE_OK_BRANCH_J_PASS5_CCT_SOURCE_CLEANUP`.
  - Focused CCT-only `shinytest2` smoke passed. It opened `Custom Comparison Tool`, found `Quick Apply Side and Top Bar Selection`, found `custom_comp_apply_top_commodity`, found `vp_commodity_name_right_2up`, `vp_commodity_name_grid_3`, and `vp_commodity_name_grid_4`, clicked Apply Commodity, and confirmed all three panel commodity selectors synced to candidate `Asparagus`.
  - A broader run of `System/Testing/vp_shinytest_smoke.R` was attempted first because it already contains CCT quick-apply assertions, but it was killed before completion after no final sentinel appeared in the available terminal buffer. This was rejected as too broad for J-5's immediate validation need.
  - A first one-line version of the focused smoke failed before R started because PowerShell parsed embedded JavaScript `||` tokens. The same check was moved into temporary file `System/Testing/vp_cct_smoke_j5_tmp.R`, parsed with `PARSE_OK_BRANCH_J_PASS5_CCT_SMOKE_TMP`, passed, and the temporary file was deleted.
  - Hygiene: `git diff --check` clean for `04_comparison_plots.R` and this plan. `get_errors` is clean for this plan and still reports existing Shiny/global-symbol static-analysis noise for `04_comparison_plots.R`, while executable parse/smoke validation is clean.
  - Acceptance caveat: automated validation passes, but user manual validation is still required for Custom Comparison Tool opening/rendering, quick apply buttons, VP panel controls, output updates, top/sidebar filtering, and browser console before J-6.
- 2026-07-31 J-5 Custom Comparison label follow-up:
  - User found a manual-review issue: the Custom Comparison top-right, bottom-left, and bottom-right type dropdown title labels still referenced Rice.
  - Source-code change is limited to `Programs/app_source/server/03_core_reactives_and_ui.R`.
  - Updated visible Custom Comparison type dropdown labels from "Right panel rice type:", "Top-right rice type:", "Bottom-left rice type:", and "Bottom-right rice type:" to "Right panel type:", "Top-right type:", "Bottom-left type:", and "Bottom-right type:" across the overlay/non-overlay and spacer-label variants.
  - Parse validation passed with `PARSE_OK_BRANCH_J_PASS5_CCT_LABEL_FIX`.
  - Targeted text search found no remaining affected visible label strings: `Right panel rice type`, `Top-right rice type`, `Bottom-left rice type`, or `Bottom-right rice type`.
  - `get_errors` still reports existing Shiny/global-symbol static-analysis noise for `03_core_reactives_and_ui.R`, while executable parse/text validation is clean.
  - Acceptance caveat remains: user manual validation is still required for Custom Comparison Tool corrected labels and behavior before J-6.
- 2026-07-31 J-5 Custom Comparison historical-slider stale-state follow-up:
  - User reported a historical slider glitch from a Custom Comparison perf log.
  - Local perf-log interpretation: during a hierarchy change to Dry pulses, several `historical_avg()` / `pace_historical_avg()` paths still saw stale `commodity_name=Artichokes` before the UI later settled to `Austrian winter peas`. The shared `hist_years` slider is expected on Custom Comparison; the concerning behavior was the transient invalid data context feeding shared historical calculations.
  - First mitigation added a Custom Comparison-only invalid `commodity_choice` correction in `Programs/app_source/server/01_state_and_custom_types.R`, updating the top-bar Type to the resolved fallback when the current Type is not valid for the active CCT context.
  - A second, more direct mitigation added a Custom Comparison-only invalid `vp_commodity_name_choice` correction in `Programs/app_source/server/02_partner_and_notes.R`, updating the top-bar VP Commodity after Custom Comparison hierarchy/trade-flow changes when the current Commodity is no longer among `custom_comparison_vp_commodity_name_choices()`.
  - Parse validation passed with `PARSE_OK_BRANCH_J_PASS5_CCT_HIST_SLIDER_SYNC` for the touched source files.
  - Temporary validator `System/Testing/vp_cct_hierarchy_sync_tmp.R` was created for a focused browser smoke, parsed with `PARSE_OK_BRANCH_J_PASS5_CCT_HIERARCHY_SYNC_TMP`, and produced no static diagnostics.
  - Focused hierarchy-sync smoke passed with `VP_CCT_HIERARCHY_SYNC_PASS=TRUE`: initial VP Commodity was `Artichokes`; after setting Group to `Dry pulses`, VP Commodity became `Austrian winter peas`, Type was `All`, and `hist_years` remained finite at `1`.
  - Temporary validator `System/Testing/vp_cct_hierarchy_sync_tmp.R` was deleted after the passing run.
  - Final parse validation across `01_state_and_custom_types.R`, `02_partner_and_notes.R`, `03_core_reactives_and_ui.R`, and `04_comparison_plots.R` passed with `PARSE_OK_BRANCH_J_PASS5_FINAL_CCT_FOLLOWUPS`.
  - Final hygiene validation: `git diff --check` clean for the touched J-5 source files and this plan. `get_errors` clean for `02_partner_and_notes.R`, `03_core_reactives_and_ui.R`, `04_comparison_plots.R`, and this plan; `01_state_and_custom_types.R` still reports existing Shiny/global-symbol static-analysis noise, while executable parse/smoke checks are clean.
  - Post-smoke artifact cleanup: removed 236 untracked `System/Cache/*.rds` files generated by the focused Shiny smoke. Existing Branch J log/runtime artifacts and processed data artifacts were left untouched.
  - Acceptance caveat remains: user manual validation should specifically include Custom Comparison hierarchy changes, VP Commodity moving away from stale Artichokes, Type staying valid, historical slider stability, output updates, and browser console review before J-6.
- 2026-07-31 J-5 manual acceptance and J-6 start:
  - User manual validation accepted J-5 with: "J-5 Seems fine. Let's continue".
  - J-5 Custom Comparison source cleanup, label cleanup, and historical-slider stale-state follow-up are accepted.
  - J-6 opened for Market Year Comparison Tool inherited-source cleanup.
- 2026-07-31 J-6 MYC source-authority first edit:
  - User risk guidance recorded: MYC Country Analysis Mode is known buggy; J-6 should try the source cleanup but may defer if focused validation exposes pre-existing MYC defects outside this pass.
  - Local trace found `06_pace_analysis_and_reset.R` contains many source fallbacks but owns Pace outputs, not MYC outputs. It was inspected and left untouched for J-7 unless MYC validation proves a dependency.
  - Local trace found the active MYC helper owner in `02_partner_and_notes.R`: `myc_cutoff_controls_ui`, `partner_snapshot()`, `is_myc_hybrid_type_mode_active()`, `get_myc_native_display_map()`, `get_myc_native_leaf_set()`, `build_myc_comparison_basis_bundle()`, and `partner_share_data()`.
  - First patch attempt failed with a duplicate-path patch-tool error; second patch attempt failed with an out-of-order chunk error. Both failed before editing source. The successful retry kept chunks in file order.
  - Source edit: `02_partner_and_notes.R` now uses `current_source_choice_safe()` as the MYC source authority in the traced MYC helper/logging paths instead of consulting hidden `input$data_source_choice` directly.
  - Parse validation passed for `02_partner_and_notes.R` with `PARSE_OK_BRANCH_J_PASS6_MYC_SOURCE_CLEANUP`.
  - Temporary validator `System/Testing/vp_myc_smoke_j6_tmp.R` was created for focused browser validation and parsed with `PARSE_OK_BRANCH_J_PASS6_MYC_SMOKE_TMP`.
  - Initial smoke failed because it required visibility of the original selectize-backed `partner_show` element; that element exists but is hidden by selectize. The validator was repaired and parsed with `PARSE_OK_BRANCH_J_PASS6_MYC_SMOKE_TMP_REPAIR`.
  - Repaired smoke still failed on a too-strict visible cutoff/plot readiness expectation. Diagnostic parse marker `PARSE_OK_BRANCH_J_PASS6_MYC_SMOKE_TMP_DIAG` passed; diagnostic output showed MYC had populated the key server-side state: main tab `Market Year Comparison Tool`, mode `country`, `partner_show` present with 19 choices, `myc_cutoff_period` present with value `5`, and country label present, while `cutoff_visible=FALSE`.
  - User reiterated MYC is very slow and not fully tuned/debugged; validation scope was trimmed to avoid working on this tab unnecessarily.
  - Bounded validator parse passed with `PARSE_OK_BRANCH_J_PASS6_MYC_SMOKE_TMP_BOUNDED`.
  - Bounded MYC control/state smoke passed with `VP_MYC_SMOKE_J6_PASS=TRUE`, `VP_MYC_SMOKE_J6_COUNTRY_MODE_CHOICES=19`, `VP_MYC_SMOKE_J6_TYPE_MODE_CHOICES=2`, `VP_MYC_SMOKE_J6_COUNTRY_MODE_CUTOFF=5`, and `VP_MYC_SMOKE_J6_TYPE_MODE_CUTOFF=5`.
  - Temporary validator `System/Testing/vp_myc_smoke_j6_tmp.R` was deleted after the bounded smoke passed.
  - Final source parse passed with `PARSE_OK_BRANCH_J_PASS6_FINAL_MYC_SOURCE_CLEANUP`.
  - Final hygiene validation: `git diff --check` clean for `02_partner_and_notes.R` and this plan; markdown diagnostics clean for this plan. `get_errors` on `02_partner_and_notes.R` still reports known Shiny/global-symbol static-analysis noise, while executable parse/smoke checks are clean.
  - Post-smoke artifact cleanup: removed untracked partition artifacts under `System/Processed Data/vp_trade_partitions`. An overly broad cache cleanup temporarily deleted tracked `System/Cache/*.rds` files, then `git restore -- System/Cache` immediately restored them. Follow-up status confirmed only this plan and `02_partner_and_notes.R` remain changed.
  - User manual validation accepted J-6 with: "Great! J-6 looks fine to me."
- 2026-07-31 J-7 Pace Analysis start:
  - J-7 opened for Pace Analysis Tool inherited-source cleanup.
  - User risk guidance recorded: older versions of the Pace tab explicitly pulled from PSD and/or WASDE data sources/layers, and any helpers associated with that process should be removed if locally proven unreachable in the VP-only app because they may slow the app.
  - Starting hypothesis: Pace source fallback helpers in `06_pace_analysis_and_reset.R` still preserve clone-era PSD/WASDE branches even though Branch J runtime source authority is fixed to `vp_trade`; the cheap disconfirming check is a local search/read showing those helpers still feed visible VP Pace outputs or are already unreachable/unused.
  - Initial source cleanup removed Pace PSD estimate state/helpers, toggle context state, PSD default-target logic, PSD toggle observers, and `output$pace_target_source_ui` from `06_pace_analysis_and_reset.R`.
  - Pace data/default-target/context paths now use `current_source_choice_safe()` as canonical VP source authority and historical default target behavior; hidden `input$data_source_choice` fallback/source branching was removed from the Pace owner file.
  - Pace target note was simplified to historical/single-reference-year notes only, preserving the visible target explanation without PSD estimate messaging.
  - Pace plot labels and PERF details were simplified to VP-owned source authority. Impossible WASDE/Hybrid label branches were removed, including the WASDE-only `total_commitment` label.
  - Source parse validations passed with `PARSE_OK_BRANCH_J_PASS7_PACE_PSD_INITIAL`, `PARSE_OK_BRANCH_J_PASS7_PACE_PSD_OBSERVERS`, `PARSE_OK_BRANCH_J_PASS7_PACE_PSD_WASDE_CLEANUP`, and `PARSE_OK_BRANCH_J_PASS7_PACE_NO_PSD_WASDE_REMAINDERS`.
  - Local search after Pace owner cleanup found no `pace_psd`, `pace_use_psd`, `Use PSD`, `PSD`, `WASDE`, `wasde`, or direct `input$data_source_choice` remnants in `06_pace_analysis_and_reset.R`.
  - Cross-file call-site search showed `get_pace_psd_estimate_info()`, `get_pace_wasde_target_info()`, and `normalize_pace_wasde_target_commodity()` remained only inside their own definitions/log strings in `05_trend_and_heatmap.R`; no active caller remained.
  - Removed those orphaned Pace-specific PSD/WASDE helper definitions from `05_trend_and_heatmap.R` while preserving non-Pace PSD history/table/map helpers in that shared fragment.
  - Removed the dead `uiOutput("pace_target_source_ui")` placeholder from the Pace tab UI in `02_partner_and_notes.R` after its server output was deleted.
  - Final touched-source parse passed with `PARSE_OK_BRANCH_J_PASS7_PACE_SHARED_PSD_REMOVAL`, `PARSE_OK_BRANCH_J_PASS7_PACE_SHARED_WASDE_REMOVAL`, and `PARSE_OK_BRANCH_J_PASS7_PACE_UI_SHARED_SOURCE_CLEANUP`.
  - Targeted helper/UI search found no remaining `pace_target_source_ui`, `pace_use_psd_estimate`, `Use PSD Estimate`, `get_pace_psd_estimate_info()`, `get_pace_wasde_target_info()`, or `normalize_pace_wasde_target_commodity()` references under `Programs/app_source/**`.
  - Temporary focused validator `System/Testing/vp_pace_smoke_j7_tmp.R` parsed with `PARSE_OK_BRANCH_J_PASS7_PACE_SMOKE_TMP`, then diagnostic/click-navigation/radio-value repairs parsed with `PARSE_OK_BRANCH_J_PASS7_PACE_SMOKE_TMP_DIAG`, `PARSE_OK_BRANCH_J_PASS7_PACE_SMOKE_TMP_CLICK_NAV`, and `PARSE_OK_BRANCH_J_PASS7_PACE_SMOKE_TMP_RADIO_VALUE`.
  - First smoke failed on a too-brittle projection-source wait despite the user confirming the visible app could navigate to Pace and toggle Year-End Projections. After validator click-navigation and Shiny radio-value repairs, focused Pace smoke passed with `VP_PACE_SMOKE_J7_PASS=TRUE`.
  - Passing smoke evidence: active tab `Pace Analysis Tool`, projection source `historical`, target note text `Note: Default target is the year-end historical average (based on the Historical Years slider). Change it to test alternative scenarios.`, KPI present `TRUE`, plot present `TRUE`, and DOM ids included `pace_projection_source`, target buttons, `pace_target_note`, `pace_kpi_ui`, `pace_gauges_combined_ui`, `pace_plot`, and `pace_hist_note`.
  - The same smoke asserted removed PSD controls/text were absent: no `pace_target_source_ui`, no `pace_use_psd_estimate`, and no visible `Use PSD Estimate` text.
  - Temporary validator was deleted after passing. Untracked `System/Cache/*.rds` files created by Shiny/cache activity were removed; untracked local processed-data artifacts were left untouched.
  - Final touched-source parse passed with `PARSE_OK_BRANCH_J_PASS7_FINAL_TOUCHED_SOURCE`.
  - Final targeted remnant searches were empty for Pace PSD/WASDE helper/UI names under `Programs/app_source/**` and for `pace_psd`, `pace_use_psd`, `Use PSD`, `PSD`, `WASDE`, `wasde`, and direct `input$data_source_choice` remnants in `06_pace_analysis_and_reset.R`.
  - Final `git diff --check` was clean for this plan plus `02_partner_and_notes.R`, `05_trend_and_heatmap.R`, and `06_pace_analysis_and_reset.R`.
  - `get_errors` was clean for this plan, `02_partner_and_notes.R`, and `06_pace_analysis_and_reset.R`. `05_trend_and_heatmap.R` still reports known static-analysis noise for Shiny/server-fragment globals; executable parse/smoke checks are the controlling validation for this pass.
- 2026-08-01 J-2a shared Current/Data/filter source-attribution slice:
  - Local hypothesis: active shared Current/Data helpers still report or branch on hidden-input/`export_sales` fallbacks even though Branch J server authority is VP-only; replacing only those touched fallback reads with `current_source_choice_safe(default = input$data_source_choice %||% "vp_trade")` should improve source attribution without changing visible VP data behavior.
  - Source edit touched only `Programs/app_source/server/03_core_reactives_and_ui.R`. `filtered_data_for_country()` and `filtered_data()` now use canonical source attribution for cache-body/log details and the NASS branch check. `most_recent()`, `historical_avg()`, and `current_year_data()` now use canonical source in performance details; `current_year_data()` also uses the canonical source for its PSD/monthly frequency guard.
  - Parse passed with `PARSE_OK_BRANCH_J_J2A_FILTERED_DATA_SOURCE_ATTRIBUTION` and, after the Current/Summary helper extension, `PARSE_OK_BRANCH_J_J2A_CURRENT_SUMMARY_SOURCE_ATTRIBUTION`.
  - Startup/Current first run `step20_branch_j_j2a_filtered_data_source_attr_startup` failed with known intermittent missing controls; output `Logs/vp_perf_probe_startup_step20_branch_j_j2a_filtered_data_source_attr_startup_20260801T175031Z.csv`; fallback JSONLs `Logs/vp_runtime_perf_proc_20260801T175046Z_21972.jsonl|Logs/vp_runtime_perf_6d5bdb394de07d2d15ac1031bad24475.jsonl`. Clean retry `step20_branch_j_j2a_filtered_data_source_attr_startup_r2` passed; output `Logs/vp_perf_probe_startup_step20_branch_j_j2a_filtered_data_source_attr_startup_r2_20260801T175236Z.csv`; fallback JSONLs `Logs/vp_runtime_perf_ab80d50cbfbdebfea9b345c37c8491e4.jsonl|Logs/vp_runtime_perf_proc_20260801T175243Z_4652.jsonl`.
  - Expanded startup/Current run `step20_branch_j_j2a_current_summary_source_attr_startup` passed; output `Logs/vp_perf_probe_startup_step20_branch_j_j2a_current_summary_source_attr_startup_20260801T180025Z.csv`; runtime log `Logs/vp_runtime_perf_startup_step20_branch_j_j2a_current_summary_source_attr_startup_20260801T180025Z.jsonl`; fallback JSONLs `Logs/vp_runtime_perf_5bbe792fd9751f0f5e83e90fb88db793.jsonl|Logs/vp_runtime_perf_proc_20260801T180035Z_31608.jsonl`.
  - Temporary Data-tab smoke parsed with `PARSE_OK_BRANCH_J_J2A_DATA_SMOKE_TMP` and `PARSE_OK_BRANCH_J_J2A_DATA_SMOKE_TMP_R2`, passed twice with `VP_J2A_DATA_SMOKE_PASS=TRUE|active_tab=Data|source=vp_trade|table_text_len=2634`, and was deleted.
  - Temporary downstream smoke first parsed with `PARSE_OK_BRANCH_J_J2A_DOWNSTREAM_SMOKE_TMP` but failed as over-broad because MYC/control-state reads are brittle on this known buggy surface. Per user instruction not to waste time validating MYC, the validator was narrowed to CCT/Pace only, parsed with `PARSE_OK_BRANCH_J_J2A_DOWNSTREAM_SMOKE_TMP_CCT_PACE`, passed with `VP_J2A_DOWNSTREAM_SMOKE_PASS=TRUE|myc=skipped_known_buggy_surface|cct_candidate=Artichokes|pace_projection=historical|pace_target=5,274|pace_note_len=136|pace_kpi_len=747`, and was deleted.
  - No comparison cache keys, projection helper contracts, country-choice observers, or shell/profile logic were edited in J-2a. User manual validation accepted J-2a on 2026-08-01 with: "Everything is looking good to me."
- 2026-08-01 J-2b deferral decision:
  - J-2b was not run. Prior J-2 comparison-cache experiments against `comparison_plot_base_cache_key()` caused readiness regressions, and J-2a did not produce new runtime evidence that comparison-cache cleanup is now low-risk or likely to improve performance.
  - Recommendation accepted for Branch J closeout: keep J-2b deferred unless a future branch records a narrow comparison-key churn hypothesis, a cheap disconfirming probe, and a hard rollback rule.
- 2026-08-01 J-8 Branch J closeout:
  - VP quantity sanity passed with label `step20_branch_j_vp_contract_post`; output `Logs/vp_perf_probe_vp_mixed_quantity_sanity_step20_branch_j_vp_contract_post_20260801T230656Z.csv`; total 21858 ms; cache state `unknown_cache_state` by the artifact-contract probe.
  - Canonical single-action closeout passed with label `step20_branch_j_source_state_post`; output `Logs/vp_perf_probe_single_action_latency_step20_branch_j_source_state_post_20260801T230725Z.csv`; total 210273 ms; status `PASS=13`; exact fallback JSONLs `Logs/vp_runtime_perf_proc_20260801T230736Z_31556.jsonl|Logs/vp_runtime_perf_9c18a2d4c7f6c2dc17e449fa160b7e52.jsonl`. Key visible-ready timings: group Dry pulses 15663 ms, subgroup Dried beans 8741 ms, Historical Trend 6758 ms, Heatmap 6795 ms, Map 9233 ms, Current return 6538 ms, pending-tab Historical Trend 8672 ms, and final Current return 7689 ms.
  - Tab-only closeout passed with label `step20_branch_j_tab_only_post`; output `Logs/vp_perf_probe_single_action_latency_step20_branch_j_tab_only_post_20260801T231110Z.csv`; total 121700 ms; status `PASS=4`; visible-ready timings were Historical Trend 9416 ms, Heatmap 7788 ms, Map 10534 ms, and Current return 7436 ms; exact fallback JSONLs `Logs/vp_runtime_perf_009adcc644b4dfc9d74d0927dccfb40c.jsonl|Logs/vp_runtime_perf_proc_20260801T231112Z_6780.jsonl`.
  - Hierarchy/sidebar closeout passed with label `step20_branch_j_hierarchy_sidebar_post`; output `Logs/vp_perf_probe_hierarchy_sidebar_cascade_step20_branch_j_hierarchy_sidebar_post_20260801T231317Z.csv`; total 125906 ms; hierarchy 46925 ms; group choice 17624 ms; subgroup choice 16524 ms; segment choice 9854 ms; exact fallback JSONLs `Logs/vp_runtime_perf_009adcc644b4dfc9d74d0927dccfb40c.jsonl|Logs/vp_runtime_perf_proc_20260801T231112Z_6780.jsonl|Logs/vp_runtime_perf_4592b3002e54c0161754acb9c238de97.jsonl|Logs/vp_runtime_perf_proc_20260801T231321Z_20064.jsonl`.
  - Runtime summaries generated from exact fallback JSONLs. CSV families: `Logs/vp_perf_runtime_summary_step20_branch_j_source_state_post_runtime_summary_20260801T231534Z_*`, `Logs/vp_perf_runtime_summary_step20_branch_j_tab_only_post_runtime_summary_20260801T231542Z_*`, and `Logs/vp_perf_runtime_summary_step20_branch_j_hierarchy_sidebar_post_runtime_summary_20260801T231547Z_*`.
  - Runtime summary highlights: final canonical top timed rows were client tab events, startup pre-UI, and VP monthly artifact load; top churn remained display-month mapping cache hits, map bottom-panel gated skips, year-filter sync, and summary table execution. Tab-only and hierarchy/sidebar showed the same broad residual churn families.
  - Outcome: Branch J succeeded as VP-only source-state cleanup and attribution hardening. It preserved visible VP behavior, removed or neutralized many clone-era source branches, and improved final reopened-B0 probe stability/timing, but remaining latency is still dominated by startup/artifact load and Shiny/htmlwidget/output-settling families rather than source switching.
  - Next recommendation: do not run J-2b inside Branch J. Recenter on a new branch for Shiny/htmlwidget/output settling if repeated-use readiness remains the priority, or on startup/artifact-load work only if startup becomes the explicit priority.

## Decisions

- PSD/NASS/Census/Hybrid/WASDE paths are clone remnants for this VP app unless locally proven to support a visible VP workflow.
- All visible tabs are in scope for preservation, not decommissioning.
- The fixed hidden VP-only `data_source_choice` ghost input is accepted for Branch J.
- Fixed hidden VP-only `data_source_choice` ghost-input conversion is a Pass 1 exit gate. Later source-input work is compatibility auditing, not delayed conversion.
- The Mandatory Pass Map is the implementation sequence unless new dependency evidence is recorded.
- After each accepted source-code pass, pause for user manual confirmation and Git progress checkpoint before the next pass. Pass 0 plan-only checkpointing is optional unless the user requests it.
- Branch J may close as cleanup/attribution-only if timing does not improve but VP behavior remains correct and dead machinery is safely removed.

## Summary

Branch J is complete. In plain terms, this branch cleaned up the VP app so the running app consistently treats `vp_trade` as the real source instead of letting old PSD/NASS/Census/Hybrid/WASDE/export-sales clone paths keep acting like live product state. The visible app was preserved: all tabs, top-bar controls, sidebar controls, tab names, and VP workflows stayed intact, and the hidden `data_source_choice` compatibility input remains as a fixed VP-only ghost input for client/probe safety.

Accepted source cleanup covered the global source authority, selected shared cache/source keys, Trend/Heatmap and Map source-key dimensions, Custom Comparison inherited source reads, MYC helper/logging source authority, Pace PSD/WASDE remnants, and the reopened J-2a shared Current/Data/filter source-attribution path. Rejected or deferred work was also important: J-1R/J-1.5 source-shell/profile experiments were reverted after readiness regressions, and J-2b comparison-cache cleanup was not run because prior `comparison_plot_base_cache_key()` experiments degraded readiness and no new evidence justified reopening that risk.

Final validation passed. VP quantity sanity passed, canonical single-action passed `PASS=13`, tab-only passed `PASS=4`, and hierarchy/sidebar passed. Final closeout timings were canonical total 210273 ms, tab-only total 121700 ms, and hierarchy/sidebar total 125906 ms with hierarchy stage 46925 ms. Versus reopened B0, the final probes were more stable and faster on tab-only and hierarchy/sidebar, but the evidence remains cache/session sensitive and Branch J should be described as cleanup/attribution with some favorable closeout timings, not a universal speed win. Runtime summaries still point to client tab/htmlwidget timing, startup VP artifact load, display-month mapping cache hits, map bottom-panel gated skips, year-filter sync, and summary table churn as residual families. The recommended next target is a separate Shiny/htmlwidget/output-settling branch for repeated-use readiness, or startup/artifact-load work only if startup becomes the explicit priority.
