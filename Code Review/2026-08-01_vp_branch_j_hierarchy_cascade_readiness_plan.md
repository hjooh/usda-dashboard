# VP Branch J: Hierarchy Cascade Readiness Plan

Date: 2026-08-01
Branch: main
Status: Accepted. H-1 probe-side target-membership waits restored reliable automated hierarchy/sidebar readiness evidence without product-source edits, H-4 automated gates passed, and H-5 manual validation was accepted by the user on 2026-08-01.
Parent ledger: `VP Clone/Code Review/2026-07-31_vp_branch_j_vp_only_source_state_cleanup_plan.md`
Grand-parent ledger: `VP Clone/Code Review/2026-07-29_vp_performance_hotspot_recovery_plan.md`

## Purpose

This grand-daughter plan isolates the Branch J hierarchy/sidebar readiness blocker from the broader VP-only source-state cleanup ledger.

The immediate goal is to determine whether the failing hierarchy/sidebar behavior is caused by probe sequencing, real Shiny render-order lag, product hierarchy state defects, or nested sidebar output scheduling. Branch J source-authority cleanup must remain frozen until this plan restores a reliable hierarchy/sidebar readiness gate.

This plan does not change visible VP product scope. All visible VP tabs, top bar controls, sidebar controls, labels, layout, defaults, and workflows must remain intact.

## Scope

Included:
- Hierarchy top-bar cascade readiness.
- Dependent choice availability for Group, Subgroup, Market Segment, and VP Commodity.
- Sidebar Commodity and Country control presence and hydration.
- Probe sequencing and target-membership waits.
- Targeted temporary instrumentation if probe-side waits do not explain the blocker.
- Narrow readiness repair only if instrumentation proves a real app-side defect.
- Evidence ledger updates, rejected approaches, blocker notes, and final lay Summary for this specific blocker.

Excluded:
- Visible tab removal, visible control removal, visible label changes, visible tab reorder, UI redesign, or feature decommissioning.
- Source-authority hardening, dead observer deletion, shell/profile cleanup, or cache-key thinning outside the hierarchy/sidebar readiness boundary.
- Pace, Market Year Comparison, Custom Comparison, Map, Trend/Heatmap, or Current/Data cleanup unless directly needed to validate hierarchy/sidebar readiness.
- Parent or grand-parent closeout updates before this blocker is resolved and accepted.

## Guardrails

- Preserve all visible VP app behavior. Visible tabs, top bar, sidebar controls, labels, order, defaults, and workflows are product behavior, not cleanup targets.
- Keep runtime source authority as `vp_trade`; do not revive PSD, NASS, Census, Hybrid, WASDE, or other non-VP product behavior.
- Keep the hidden fixed `data_source_choice` compatibility input unless a separate approved cleanup removes every dependency.
- Treat prior Branch J evidence as append-only. Do not overwrite accepted J-0 through J-7 evidence or rejected J-1R attempts.
- Use exact probe labels and exact runtime/fallback JSONL inputs when summarizing evidence. Do not summarize broad wildcards for before/after claims.
- If a product edit is attempted, make it small enough to revert as one tranche and validate immediately before expanding scope.
- Freeze broader J-1R, J-1.5, and J-2 cleanup until the hierarchy/sidebar cascade has a stable readiness contract and a passing probe.

## Current Evidence

- J-0R/B0 is the controlling baseline for this blocker. B0 recorded VP quantity sanity PASS, tab-only PASS=4, hierarchy/sidebar PASS, and canonical PARTIAL=1/PASS=10 with the first group-change visible-ready timeout.
- J-1R source-authority attempts passed direct hidden-source spoof checks but failed broader readiness, so they were reverted.
- Startup readiness sometimes failed because `country_choice` and `commodity_choice` were missing while `comparison_plot` was already visible. This proves that visible plot readiness and required-control presence are separate gates.
- Country-sort fallback did not fix missing sidebar controls.
- Unsuspending both nested sidebar outputs made control presence more reliable but worsened tab visible-ready timing, so broad unsuspend is rejected.
- Unsuspending only `commodity_choice_ui` made startup and tab-only pass, but hierarchy/sidebar failed with final path `Dry pulses / __all__ / __all__` instead of `Dry pulses / Dried beans / Dried`.
- The current likely issue is render-order/readiness sequencing around top-bar hierarchy `renderUI`, dependent choice hydration, and nested sidebar output scheduling.

## Working Hypotheses

1. Probe race: after an upstream group change, the probes set subgroup or segment before the dependent choices are available, so invalid values are ignored or normalized to `__all__`.
2. Product readiness: the app renders or preserves hierarchy controls in an order that leaves dependent choices stale too long, even for a real user or correctly waiting probe.
3. Sidebar boundary: nested sidebar outputs under `market_year_compare_filters_ui` are scheduled independently from the top-bar hierarchy cascade, so required-control presence and plot readiness can diverge.
4. Preserve-input normalization: the app may legitimately rewrite subgroup or segment to `__all__` during top-bar regeneration even if the probe waited.
5. Blunt unsuspend: permanently unsuspending both nested outputs is too expensive; any product repair should prefer a narrower readiness trigger or cascade-stabilization point.

## Critical Audit Amendments

These amendments are hard implementation constraints for this plan.

- Do not treat DOM presence as readiness. A valid gate must prove each dependent select/selectize control is hydrated with the intended choices before the probe or user workflow drives it.
- A probe-only change is acceptable only if it waits for real UI readiness that the product already exposes, and it must continue to assert final selected values, choice counts, control presence, and visible output readiness.
- A product-side change is unacceptable if it merely makes controls appear while worsening tab visible-ready timing, final hierarchy path, or broader startup/canonical gates.
- Ban structural edits inside `output$data_frequency_ui` until H-0/H-1 show whether the issue is probe sequencing. Before that, only read-only inspection or no-op/temporary instrumentation is allowed.
- If H-1 passes after probe waits, still run startup/canonical/tab-only gates and record choice hydration evidence so this plan does not mistake a less aggressive probe for a fixed app.
- If H-1 changes hierarchy/sidebar probe waits, the same readiness concept must be applied to the canonical hierarchy actions before H-4 acceptance, because canonical drives the same `Dry pulses -> Dried beans -> Dried` chain.
- If H-1 fails or remains intermittent, H-2 must instrument both server-side hierarchy state and client-visible choice hydration before any product repair.
- Treat `market_year_compare_filters_ui` readiness as insufficient by itself. The nested `commodity_choice_ui` and `country_choice_ui` outputs render independently, so wrapper presence does not prove child-control readiness.
- Treat fallback-rendered sidebar controls as non-acceptance evidence unless explicitly expected. A passing run must distinguish final hydrated choices from `used_fallback_choices`, guarded sync, or empty-transition states.

## Pass Map

### H-0: Baseline and Reproduction

Goal:
- Reproduce the current hierarchy/sidebar readiness behavior without product edits.
- Confirm whether current behavior matches B0 or is intermittent.

Required work:
- Run the hierarchy/sidebar probe against the current state with a unique label.
- Run startup, tab-only, and canonical probes if recent state is uncertain.
- Record exact output CSVs, runtime/fallback JSONLs, final hierarchy path, control presence, and any missing-control or canonical-path errors.
- Summarize exact runtime/fallback JSONLs only.

Exit gate:
- The blocker is reproduced or explicitly classified as intermittent/cache-state-sensitive.

### H-1: Probe-Side Cascade Waits

Goal:
- Test the cheapest falsifiable hypothesis: the probe is racing dependent hierarchy choices.

Required work:
- In `System/Testing/vp_perf_probe_hierarchy_sidebar_cascade.R`, inspect `hierarchy_snapshot()`, `timed_set_input_with_snapshot()`, required controls, choice-list extraction, and the reset/group/subgroup/segment sequence.
- Add or design explicit waits after setting group and subgroup so the probe re-reads the live downstream choice list and proceeds only when the intended downstream value is present, the upstream selected value is still the requested one, and that condition is stable across at least two polls.
- Record choice counts, available values or a representative sample, selected values, final hierarchy path, and required-control presence before and after each cascade step.
- Apply the same readiness concept to canonical hierarchy actions in `System/Testing/vp_perf_probe_single_action_latency.R` before H-4 acceptance, because canonical uses the same dependent hierarchy path.
- Do not weaken the probe by replacing final selected-value assertions with sleeps, broad timeouts, or counts-only checks.

Exit gate:
- If final path reaches `Dry pulses / Dried beans / Dried` without product edits, probe sequencing is likely the main defect, but acceptance still requires startup/canonical/tab-only gates and preserved assertions.
- If H-1 fails or remains intermittent, proceed to H-2.

### H-2: Product Readiness Instrumentation

Goal:
- Distinguish server-side hierarchy state, client-visible choice hydration, preserve-input normalization, and fallback-rendered child controls.

Required work:
- Add temporary, low-noise runtime markers around server-side hierarchy state generation and client-visible dependent choice hydration.
- Candidate server surfaces: `vp_hierarchy_last_changed()`, `vp_hierarchy_change_nonce()`, `vp_resolve_hierarchy_choice_state()`, `canonicalize_vp_hierarchy_selection()`, `resolve_vp_hierarchy_tokens()`, and `output$data_frequency_ui`.
- Candidate client/probe observations: available subgroup choices after group set, available segment choices after subgroup set, selected values after each set, and whether selectize/input state agrees with server-resolved tokens.
- Instrument the resolved selected group/subgroup/segment and the exact choice vectors seen by `vp_resolve_hierarchy_choice_state()`.
- Add commodity-side hydration evidence, not only country-side evidence. Country already has more ack/probe visibility; commodity needs symmetric observation so H-2 does not misattribute the blocker.
- Identify whether commodity or country child controls are fallback-rendered, guarded-sync-rendered, or empty-transition-rendered.

Exit gate:
- The plan can identify whether the server produces expected choices late but correctly, client hydration lags server state, fallback-rendered child controls are masking readiness, or canonicalization/preserve-input behavior leaves downstream controls at `__all__`.

### H-3: Product Readiness Repair

Goal:
- Repair only a proven app-side readiness defect.

Required work:
- Prefer the smallest readiness-specific repair near the controlling boundary.
- Candidate surfaces: `output$data_frequency_ui` and hierarchy-change observers in `Programs/app_source/server/02_partner_and_notes.R`; `output$market_year_compare_filters_ui` and output suspension settings; `output$commodity_choice_ui` in `Programs/app_source/server/01_state_and_custom_types.R`; `country_choice_ui_selection_state()` and `output$country_choice_ui` in `Programs/app_source/server/03_core_reactives_and_ui.R`.
- Avoid broad permanent unsuspend of both nested sidebar outputs unless every narrower approach fails and performance impact is explicitly accepted.
- Preserve visible UI exactly.

Exit gate:
- Product readiness improves without weakening final hierarchy assertions, without fallback-rendered child controls counting as success, and without regressing startup/canonical/tab-only gates relative to B0.

### H-4: Validation

Required gates:
- Startup probe.
- Hierarchy/sidebar probe.
- Canonical single-action probe.
- Tab-only probe.

Acceptance checks:
- Final canonical hierarchy path is `Dry pulses / Dried beans / Dried`, not `Dry pulses / __all__ / __all__`.
- `commodity_choice` and `country_choice` are present when required, hydrated with non-fallback choices, and not merely rendered by fallback/empty-transition state.
- Subgroup and segment target-membership checks are stable across at least two polls before dependent values are set.
- Tab-only remains PASS=4.
- Canonical single-action is at least no worse than B0 (`PARTIAL=1/PASS=10`) and ideally improves the first group-change visible-ready timeout.
- No visible tabs are removed, renamed, reordered, hidden, or functionally changed.
- Top bar and sidebar format/function remain unchanged.

### H-5: Manual Acceptance and Roll-Up

Required work:
- User manually confirms top-bar hierarchy cascade, sidebar commodity/country controls, reset/all-state navigation, specific-path navigation (`Dry pulses -> Dried beans -> Dried`), and all visible tabs still behave as before.
- Update this plan's Summary in lay terms: what failed, what was changed, what passed, and what remains risky.
- Update the Branch J parent ledger with concise outcome and whether J-1R can resume.
- Update the grand-parent performance ledger only after this blocker is resolved and accepted.

## Relevant Files

- `Code Review/2026-08-01_vp_branch_j_hierarchy_cascade_readiness_plan.md` - this grand-daughter source-of-truth plan.
- `Code Review/2026-07-31_vp_branch_j_vp_only_source_state_cleanup_plan.md` - parent Branch J ledger; keep only concise delegation/result pointers here.
- `Code Review/2026-07-29_vp_performance_hotspot_recovery_plan.md` - grand-parent performance ledger; update only after accepted resolution.
- `Programs/app_source/server/02_partner_and_notes.R` - top-bar hierarchy owner and sidebar wrapper.
- `Programs/app_source/server/01_state_and_custom_types.R` - sidebar type/commodity owner.
- `Programs/app_source/server/03_core_reactives_and_ui.R` - country and selected/filter data owner.
- `System/Testing/vp_perf_probe_hierarchy_sidebar_cascade.R` - primary hierarchy/sidebar readiness probe.
- `System/Testing/vp_perf_probe_single_action_latency.R` - canonical/tab-only readiness probe.
- `System/Testing/vp_perf_probe_startup.R` - startup required-control gate.
- `System/Testing/vp_perf_summarize_runtime_logs.R` - exact runtime/fallback summary tool.

## Verification Commands

Markdown hygiene after plan creation:

```powershell
Get-Item "Code Review/2026-08-01_vp_branch_j_hierarchy_cascade_readiness_plan.md", "Code Review/2026-07-31_vp_branch_j_vp_only_source_state_cleanup_plan.md"
git diff --check -- "Code Review/2026-08-01_vp_branch_j_hierarchy_cascade_readiness_plan.md" "Code Review/2026-07-31_vp_branch_j_vp_only_source_state_cleanup_plan.md"
```

H-0 baseline/repro:

```powershell
& "C:\Program Files\R\R-4.5.1\bin\Rscript.exe" "System/Testing/vp_perf_probe_hierarchy_sidebar_cascade.R" --label=step20_branch_j_hierarchy_readiness_h0_sidebar --cache-state=warm_partition_disk --runtime-perf=true
```

Startup gate:

```powershell
& "C:\Program Files\R\R-4.5.1\bin\Rscript.exe" "System/Testing/vp_perf_probe_startup.R" --label=step20_branch_j_hierarchy_readiness_startup --cache-state=warm_partition_disk --runtime-perf=true --target-tab="Current vs. Average"
```

Canonical single-action gate:

```powershell
& "C:\Program Files\R\R-4.5.1\bin\Rscript.exe" "System/Testing/vp_perf_probe_single_action_latency.R" --label=step20_branch_j_hierarchy_readiness_canonical --scenario=canonical --cache-state=warm_partition_disk --runtime-perf=true
```

Tab-only gate:

```powershell
& "C:\Program Files\R\R-4.5.1\bin\Rscript.exe" "System/Testing/vp_perf_probe_single_action_latency.R" --label=step20_branch_j_hierarchy_readiness_tab_only --scenario=tab_only --cache-state=warm_partition_disk --runtime-perf=true
```

Hierarchy/sidebar acceptance gate:

```powershell
& "C:\Program Files\R\R-4.5.1\bin\Rscript.exe" "System/Testing/vp_perf_probe_hierarchy_sidebar_cascade.R" --label=step20_branch_j_hierarchy_readiness_sidebar --cache-state=warm_partition_disk --runtime-perf=true
```

Runtime summary:

```powershell
& "C:\Program Files\R\R-4.5.1\bin\Rscript.exe" "System/Testing/vp_perf_summarize_runtime_logs.R" --label=<summary_label> --input=<exact jsonl paths separated by |>
```

## Evidence Ledger

This section must be updated during implementation.

| Pass | Status | Files Touched | Hypothesis Tested | Probe Label(s) | Output Files | Result | Key Metrics / Final Path | Decision / Notes |
|---|---|---|---|---|---|---|---|---|
| H-0 | Complete | This plan; read-only probes/logs | Baseline/repro without product edits | `step20_branch_j_hierarchy_readiness_h0_sidebar_r1`; `step20_branch_j_hierarchy_readiness_h0_sidebar_r2`; runtime summaries `step20_branch_j_hierarchy_readiness_h0_sidebar_r1_runtime_summary` and `step20_branch_j_hierarchy_readiness_h0_sidebar_r2_runtime_summary` | Probe CSVs: `Logs/vp_perf_probe_hierarchy_sidebar_cascade_step20_branch_j_hierarchy_readiness_h0_sidebar_r1_20260801T143421Z.csv`; `Logs/vp_perf_probe_hierarchy_sidebar_cascade_step20_branch_j_hierarchy_readiness_h0_sidebar_r2_20260801T143750Z.csv`. Runtime summaries: `Logs/vp_perf_runtime_summary_step20_branch_j_hierarchy_readiness_h0_sidebar_r1_runtime_summary_20260801T143734Z_*`; `Logs/vp_perf_runtime_summary_step20_branch_j_hierarchy_readiness_h0_sidebar_r2_runtime_summary_20260801T144008Z_*`. Exact fallback JSONLs recorded in the probe CSVs. | Two consecutive hierarchy/sidebar PASS runs | r1 total 173234 ms, hierarchy 58591 ms, group/subgroup/segment choice 21689/23702/11316 ms, final path `Dry pulses / Dried beans / Dried`; r2 total 130462 ms, hierarchy 47662 ms, group/subgroup/segment choice 18923/17190/9357 ms, final path `Dry pulses / Dried beans / Dried`. Required controls were present and no final-path failure reproduced. | H-0 establishes current baseline can pass twice under the existing probe, but it does not prove target-choice hydration before dependent values are set. Proceed to H-1 probe-side target-membership waits before any product-source edit. |
| H-1 | Accepted | `System/Testing/vp_perf_probe_hierarchy_sidebar_cascade.R`; `System/Testing/vp_perf_probe_single_action_latency.R`; this plan | Probe race / dependent-choice hydration waits | Parse markers `PARSE_OK_BRANCH_J_H1_HIERARCHY_SIDEBAR_TARGET_MEMBERSHIP`, `PARSE_OK_BRANCH_J_H1_SINGLE_ACTION_TARGET_MEMBERSHIP`, `PARSE_OK_BRANCH_J_H1_SINGLE_ACTION_TARGET_MEMBERSHIP_REPAIR`, `PARSE_OK_BRANCH_J_H1_SINGLE_ACTION_ROW_BIND_REPAIR`. Passing probes: `step20_branch_j_hierarchy_readiness_h1_sidebar_waits_r1`, `step20_branch_j_hierarchy_readiness_h1_sidebar_waits_r2`, `step20_branch_j_hierarchy_readiness_h1_canonical_waits_r3`, `step20_branch_j_hierarchy_readiness_h1_startup_waits_r1`, `step20_branch_j_hierarchy_readiness_h1_tab_only_waits_r1`. Runtime summaries generated for all accepted H-1 gates. | Accepted CSVs include `Logs/vp_perf_probe_hierarchy_sidebar_cascade_step20_branch_j_hierarchy_readiness_h1_sidebar_waits_r1_20260801T144210Z.csv`, `Logs/vp_perf_probe_hierarchy_sidebar_cascade_step20_branch_j_hierarchy_readiness_h1_sidebar_waits_r2_20260801T145929Z.csv`, `Logs/vp_perf_probe_single_action_latency_step20_branch_j_hierarchy_readiness_h1_canonical_waits_r3_20260801T145130Z.csv`, `Logs/vp_perf_probe_startup_step20_branch_j_hierarchy_readiness_h1_startup_waits_r1_20260801T145554Z.csv`, and `Logs/vp_perf_probe_single_action_latency_step20_branch_j_hierarchy_readiness_h1_tab_only_waits_r1_20260801T145703Z.csv`. Runtime summary prefixes: `step20_branch_j_hierarchy_readiness_h1_sidebar_waits_r1_runtime_summary_20260801T144449Z_*`, `step20_branch_j_hierarchy_readiness_h1_canonical_waits_r3_runtime_summary_20260801T145458Z_*`, `step20_branch_j_hierarchy_readiness_h1_startup_waits_r1_runtime_summary_20260801T145908Z_*`, `step20_branch_j_hierarchy_readiness_h1_tab_only_waits_r1_runtime_summary_20260801T145911Z_*`, and `step20_branch_j_hierarchy_readiness_h1_sidebar_waits_r2_runtime_summary_20260801T150141Z_*`. | H-1 probe-side waits passed all automated gates after local probe-row repairs | Hierarchy/sidebar r1 PASS: subgroup target present TRUE, choices count 5, stable polls 2; segment target present TRUE, choices count 2, stable polls 2; final path `Dry pulses / Dried beans / Dried`; total 147780 ms, hierarchy 58427 ms. Hierarchy/sidebar r2 PASS with the same readiness evidence and final path; total 118705 ms, hierarchy 45876 ms. Canonical r3 PASS=13, including readiness rows for subgroup and segment target membership; startup PASS; tab-only PASS=4. | H-1 proves the accepted probes were racing no visible app defect under current state: adding target-membership waits preserves final path and broad gates. No product-source edit was made. H-2/H-3 are not needed unless later resumed Branch J cleanup exposes a real app-side readiness defect. |
| H-2 | Deferred | Not touched | Server state vs client hydration vs preserve-input normalization | Not run | Not generated | Not needed after H-1 automated gates passed | H-1 produced explicit client-visible target-membership evidence without product edits. | Keep H-2 available only if manual validation, future H-4 repetition, or resumed source cleanup shows stale choices, fallback-rendered controls, or `__all__` normalization despite H-1 waits. |
| H-3 | Deferred | Not touched | Narrow product readiness repair if needed | Not run | Not generated | Not needed after H-1 automated gates passed | No real app-side readiness defect was proven in this tranche. | Do not edit product source for hierarchy readiness unless H-2 later proves an app-side defect. |
| H-4 | Accepted | H-1 probes and runtime logs | Accepted readiness validation | Same accepted H-1 startup, hierarchy/sidebar, canonical, and tab-only labels listed above | Same accepted H-1 CSVs and runtime summaries listed above | Startup PASS; hierarchy/sidebar PASS twice; canonical PASS=13; tab-only PASS=4 | Final canonical hierarchy path preserved; subgroup and segment target-membership checks stable across two polls before dependent values were set; required controls present; no visible tab/order/function source changes. | Automated acceptance gate is met and paired with H-5 manual acceptance. |
| H-5 | Accepted | This plan; parent/grand-parent ledgers updated | Manual acceptance and roll-up | User manual validation accepted 2026-08-01 | Not applicable | Accepted | User manually confirmed that the app is functioning properly. No product-source edits were made in this plan, so this acceptance closes the diagnosis/readiness gate rather than accepting an app-code behavior change. | Branch J may resume from the source-authority/J-1R decision point using the updated readiness probes. |

## Bugs, Blockers, Failed Attempts, Rejected Approaches

- Rejected before this plan: country-sort fallback did not fix missing sidebar controls.
- Rejected before this plan: unsuspending both nested sidebar outputs fixed required-control presence but worsened tab visible-ready timing.
- Rejected before this plan: unsuspending only `commodity_choice_ui` preserved startup and tab-only but broke canonical hierarchy final path (`Dry pulses / __all__ / __all__`).
- Rejected before this plan: J-1R source-authority edits passed direct spoof checks but regressed broader startup/tab-only/hierarchy readiness.
- H-1 rejected probe implementation attempt: `step20_branch_j_hierarchy_readiness_h1_canonical_waits_r1` failed after the subgroup readiness wait because the synthetic readiness row tried to flatten an empty list. Resolution: remove the empty timeline flatten from readiness rows and rerun with a fresh label.
- H-1 rejected probe implementation attempt: `step20_branch_j_hierarchy_readiness_h1_canonical_waits_r2` executed all action/readiness rows successfully, but final CSV assembly failed because synthetic readiness rows and normal action rows had different columns. Resolution: add mixed-row binding that unions/fills columns before writing the canonical probe result.
- Known blocker: wrapper readiness is not child-control readiness. `market_year_compare_filters_ui` can be ready while nested commodity/country controls are not.
- Known blocker: fallback-rendered controls can fake success. Acceptance must distinguish final hydrated choices from fallback/guarded/empty-transition state.
- Known blocker: preserve-input normalization can make a valid app-side reset look like a probe race; H-2 must distinguish these paths.
- Known risk: Chromote/AppDriver/browser startup can fail before app assertions. Run one clean retry and classify environmental failures separately unless they reproduce.
- Known risk: cache-state sensitivity and intermittent Shiny readiness can make one run misleading. Prefer two consecutive green hierarchy/sidebar runs when runtime cost is reasonable.
- Known risk: probe runs generate output CSVs, fallback JSONLs, runtime JSONLs, cache files, and processed-data artifacts. Cleanup must be targeted and must not remove tracked or user-created files.
- Known risk: Windows command quoting matters for arguments with spaces, especially `--target-tab="Current vs. Average"`.

## Implementation Blockers and Refinements

- Use unique probe labels for every run. Do not reuse H-0/H-1/H-4 labels across retries; append a retry or timestamp suffix and ledger which run is accepted.
- If a probe fails because of Chromote/AppDriver/browser startup rather than app assertions, run one clean retry and classify the first failure as environmental unless it reproduces.
- Because this issue has intermittent/cache-sensitive symptoms, acceptance should prefer two consecutive green runs for the decisive hierarchy/sidebar gate when runtime cost is reasonable. If only one run is practical, record that limitation as residual risk.
- Record generated artifacts deliberately: output CSVs, fallback JSONLs, runtime JSONLs, and any cache/log files created by probes.
- Before the first product-source edit, capture the current dirty-worktree/file-change state or create a Git checkpoint if the implementation flow supports it. Do not mix unrelated edits into hierarchy readiness evidence.
- If H-1/H-2 requires temporary instrumentation, give it an explicit removal or keep/quiet decision before closeout. Temporary counters should not silently become permanent unless they are useful future diagnostics.
- Manual validation should include both specific-path navigation and reset/all-state navigation, because preserve-input normalization bugs can appear in either direction.

## Decisions

- This blocker is delegated from the Branch J parent into this separate grand-daughter plan.
- Hierarchy/sidebar readiness blocks resumed J-1R source-authority cleanup.
- Start with probe-side dependent-choice waits because that is the cheapest falsifiable test and avoids unnecessary product churn.
- Do not treat broad output unsuspension as accepted evidence; it is rejected because it worsened tab readiness.
- Do not update the grand-parent performance ledger again until this blocker has an accepted result.

## Summary

This plan resolved the hierarchy/sidebar cascade blocker that stopped Branch J source cleanup. The core lesson was that control presence was not enough: after a Group or Subgroup change, the probes needed to wait until the downstream dropdown actually contained the intended target choice before setting the next dependent value.

The accepted change was probe-side only. No product-source code was changed. The hierarchy/sidebar and canonical probes now wait for target membership, stable upstream selection, and stable choice hydration before continuing. After that change, startup passed, tab-only passed, canonical passed with `PASS=13`, and the hierarchy/sidebar probe passed twice with the final path `Dry pulses / Dried beans / Dried`.

The user manually confirmed on 2026-08-01 that the app is functioning properly. H-2 product instrumentation and H-3 product repair remain deferred because no real app-side hierarchy/sidebar defect was proven. Branch J can resume using the updated readiness probes as the acceptance gate for future source-cleanup edits.
