# VP Branch K: Hierarchy Cache Architecture Plan

Date: 2026-08-03
Branch: main
Status: Closed and rolled up to the VP performance hotspot parent. K-A delivered a behavior-safe shared resolved hierarchy context cache and several attribution/output-settling cleanup slices, but did not produce the large repeated-use/tab-readiness win needed for usability. K-R closed the larger artifact hypothesis: embedded rollup bulk is a material startup/artifact-load lever, with two close-sequence startup pairs improving from 85051 ms to 59815 ms and from 111341 ms to 74559 ms under the performance-only minimal-rollup candidate, while tab-only results remained inconclusive. Outstanding Branch K conditional paths are deferred. The next recommended architecture direction is a separate aggressive lazy partition plan: small startup shell, commodity-level native partitions loaded on demand, and commodity/context rollup sidecars.
Parent ledger: `VP Clone/Code Review/2026-07-29_vp_performance_hotspot_recovery_plan.md`
Prior branch context: `VP Clone/Code Review/2026-07-31_vp_branch_j_vp_only_source_state_cleanup_plan.md`
Readiness context: `VP Clone/Code Review/2026-08-01_vp_branch_j_hierarchy_cascade_readiness_plan.md`

## Purpose

Branch K is a hierarchy cascade and cache architecture performance branch for the VP Shiny app. The current AP is not usable enough: tab initialization and tab switches commonly take about 5-10 seconds, while the aspiration target for usable AP interactions is roughly 1-3 seconds.

This branch starts from the assumption that hierarchy cascade filtering, cache identity, provider/partition behavior, app-level output settling, and artifact load are all hypotheses to test. The existing AP cache/partition strategy is not protected architecture. It should be reused if evidence shows it is adequate, repaired if evidence shows it is fragmented or over-invalidating, and redesigned if evidence shows it is a controlling bottleneck.

Branch K does not need to reach the full 1-3 second target in one tranche. Each accepted tranche must either materially reduce a named user-visible wait or produce evidence that redirects work toward the next highest-leverage bottleneck.

After reviewing the parent plan and daughter evidence, the active Branch K thesis is now narrower and more actionable: a hierarchy action should behave more like one transaction. It should produce one stable resolved hierarchy context, one stable downstream invalidation wave, and minimal duplicate recomputation across display-month, type-choice, quantity-unit, mixed-volume, filtered-data, summary/projection, map, and tab-readiness consumers. This is a shared hierarchy cascade/fanout refactor, not a provider-cache rewrite and not another broad Plotly attribution branch.

## Guardrails and Product Invariants

- Preserve visible AP workflows unless the user explicitly approves a UX change for usability.
- Preserve visible tabs, labels, hierarchy controls, top bar, sidebar behavior, hidden VP-only source state, and core Current/Data/Summary/CCT workflows.
- Keep VP-only source behavior compatible with the Branch J closeout contract.
- Do not treat existing provider APIs, direct-filter fallback, or partition shape as permanent constraints if they are proven bottlenecks.
- During migration, preserve source-identity checks, index-bounds checks, stale/mismatch refusal behavior, and artifact-missing fallback.
- Do not reopen `comparison_plot_base_cache_key()` unless a separate mini-tranche proves comparison cache identity is implicated and defines a hard rollback trigger.
- Use MYC only as a limited smoke/regression surface unless the user explicitly asks to focus on MYC.
- Do not claim a global speed win unless comparable user-visible timings improve.
- Keep implementation evidence append-only in this ledger.

## Working Hypotheses

K-0 hypothesis:
- The current post-Branch J app still spends too much time during tab initialization, tab switching, and hierarchy/sidebar cascade settling for AP to feel usable.

Cache architecture hypothesis:
- The current cache/partition strategy may be adequate, insufficient, fragmented, over-invalidating, under-keyed, disk-bound, memory-heavy, or itself a bottleneck. Branch K must measure this before choosing the implementation path.

Hierarchy hypothesis:
- Raw row filtering may not be the only or largest remaining cost. Repeated context discovery, cache-key churn, provider fallback, metadata lookup, display-month/type/quantity helper churn, output settling, or artifact load may dominate visible readiness.

Shared cascade/fanout hypothesis:
- The most plausible next implementation target is the hierarchy cascade as a transaction/fanout problem. A single group/subgroup/segment action currently appears to trigger multiple sibling consumers that rediscover related hierarchy context, rebuild related choices, and settle downstream outputs separately. Even if htmlwidget readiness remains a separate residual bottleneck, reducing hierarchy fanout should improve one of the worst user-visible paths and may reduce background drain that makes tab readiness feel slower.

Cheap falsifying checks:
- If a narrow K-0.5 fanout pass does not show repeated sibling consumers, duplicate context discovery, cache-key churn, or avoidable output invalidation around hierarchy changes, do not proceed with a broad shared hierarchy refactor.
- If K-0.5 shows the hierarchy fanout exists but provider/partition disk work remains secondary, proceed with shared cascade/context refactor before provider redesign.
- If K-0.5 unexpectedly shows provider/partition behavior is the dominant user-visible wait, Branch K may escalate to provider/cache architecture work with the existing Path C guardrails.
- If K-0.5 shows only htmlwidget readiness with no hierarchy fanout leverage, pivot to an output-settling branch rather than forcing hierarchy refactor.

## Source-Of-Truth Ledger Contract

- This file is the source-of-truth implementation ledger for Branch K.
- The parent performance ledger remains the broad VP performance recovery ledger and should be updated at Branch K closeout or a major accepted checkpoint.
- Branch J remains closed. Do not reopen Branch J for hierarchy/cache architecture work.
- Update this ledger after every pass before moving to the next pass.
- Record files touched, parse markers, commands/probes, labels, output paths, runtime/fallback JSONLs, cache-state labels, logging manifests, runtime summaries, blockers, failed attempts, rejected approaches, decisions, manual validation notes, and Git checkpoint status.
- Do not create a paired results markdown file unless explicitly requested.

## Measurement Model

- North-star usability target: tab initialization and tab-switch interactions should move from the current 5-10 second range toward roughly 1-3 seconds.
- K-0 must record both user-visible timings and helper/provider/runtime internals.
- Keep startup-lane evidence separate from post-warm interaction-lane evidence.
- For decisive hierarchy/cache gates, prefer paired `warm_partition_disk` and `warm_session` evidence.
- Do not use `unknown_cache_state` for new acceptance claims except as legacy context.
- For decisive hierarchy/cache gates, require two consecutive PASS runs or explicitly classify the discrepancy. Allow one clean retry only for known browser-startup/control-hydration flakiness.
- Runtime log summaries must use exact JSONL paths printed by accepted probes, including fallback paths when requested runtime files do not materialize.
- Maintain a per-run logging manifest: requested runtime path, actual runtime path, probe label, session id if available, cache-state label, and summarized input paths.
- Record output-settling time where available separately from helper-level timing so helper wins are not mistaken for full usability success.

## Architecture Decision Paths

Branch K must choose an implementation path after K-0/K-0.5 evidence. Multiple paths may be used sequentially, but each pass must name its path and rollback trigger.

| Path | When to choose | Implementation direction | Key risk |
|---|---|---|---|
| A. Shared hierarchy cascade/fanout refactor | Hierarchy actions trigger repeated sibling consumers, duplicate context discovery, cache-key churn, or avoidable downstream invalidation | Create/reuse one stable resolved hierarchy transaction/context boundary and feed display-month, type-choice, quantity-unit, mixed-volume, filtered-data, summary/projection, and map consumers from it where contract-safe | Broad refactor can create stale cache state or reset hierarchy controls if keys/preserve-input semantics are wrong |
| A1. Targeted reuse | Existing cache/partition strategy is mostly sound and one or two consumers dominate fanout | Reuse or minimally extend `vp_trade_context_entry()` / `vp_trade_context_metadata_entry()` and thread explicit additive context | Too small to move user-visible latency |
| B. Cache-key/schema repair | Cache identity over-invalidates, under-specifies, mixes diagnostics with behavior, or fragments equivalent contexts | Define canonical behavior/cache identity and schema version where needed | Stale data or excessive invalidation |
| C. Provider/partition redesign | Partition lookup, disk reads, manifest shape, cache misses, or direct fallback dominate visible latency | Redesign partition grain, index strategy, manifest/schema, and runtime reader around proven access patterns | Correctness, artifact size, memory, startup |
| D. Build/pipeline metadata or aggregation | Stable runtime discovery/aggregation is repeatedly recomputed and can safely move out of Shiny | Build hierarchy metadata, row-index manifests, calendar/display signatures, or safe pre-aggregates | Startup/artifact growth or semantic drift |
| E. Pivot away from filtering | Hierarchy/cache work is not controlling latency | Move to Shiny/htmlwidget/output-settling or startup/artifact-load branch | Wasted time if filtering remains under-measured |

## Step Ledger

| Step | Phase | Work | Status | Evidence / Files | Gate / Next Action |
|---|---|---|---|---|---|
| K-0 | Baseline / contract | Capture fresh post-Branch J baseline, logging manifest, cache-state labels, hierarchy/sidebar contract, startup and tab interaction evidence | Complete | `warm_partition_disk` probes passed: hierarchy/sidebar, hierarchy transition, canonical, tab-only, startup guard. Warm-session confirmation passed for hierarchy transition and tab-only. Runtime summaries generated from exact JSONLs. See Evidence Ledger. | Proceed to narrow K-0.5 hierarchy fanout attribution; do not start with provider/partition redesign. |
| K-0.5 | Narrow hierarchy fanout attribution | Confirm the exact sibling consumers, duplicate context discovery, cache-key churn, and avoidable downstream invalidation triggered by one hierarchy action | Complete for first gate | Instrumentation added to `02_partner_and_notes.R`, `03_core_reactives_and_ui.R`, `04_comparison_plots.R`, and `vp_perf_summarize_runtime_logs.R`. Parse marker: `PARSE_OK_BRANCH_K_K05_FANOUT_ALL`. Probe failed on source-switch stability/final missing controls but completed hierarchy waits; fallback fanout summary confirms repeated sibling consumers within hierarchy generations. See K-0.5 evidence. | Proceed to K-A. Keep probe reliability caveat and rerun hierarchy/sidebar after first behavior slice. |
| K-1 | Architecture decision | Choose Path A/A1/B/C/D/E based on K-0.5 evidence and record threshold, expected user-visible win, rollback trigger, and checkpoint location | Complete for first implementation path | Decision: Path A is accepted as the next implementation path. Path C provider redesign is not the first move. Path E output-settling remains a residual branch, not the immediate default. | Implement the smallest shared hierarchy cascade slice and validate with hierarchy/sidebar first. |
| K-A | Shared hierarchy cascade/fanout refactor | Establish one stable resolved hierarchy context/invalidation boundary and reuse it across repeated downstream consumers | First slice implemented; broadened validation complete; display-month and map bottom-panel cleanup complete | Added bounded `vp_resolved_hierarchy_cache` in `02_partner_and_notes.R`. Sidebar rerun PASS: total 144855 ms, hierarchy 55869 ms. Canonical PASS=13, total 240920 ms. Tab-only PASS=4, total 130557 ms. Display-month hit throttle tab-only PASS=4, total 134731 ms, with display-month hit churn reduced but Map/Current visible-ready worse. Map bottom-panel suspend tab-only PASS=4, total 144490 ms, with gated-skip churn down from 8 to 1 but total wall clock worse. | Keep resolved-context slice. Keep display-month throttle only as logging cleanup. Keep map bottom-panel suspension as behavior-safe output-settling cleanup unless a follow-up probe shows PSD/source transition regression. Do not claim a branch-wide speed win. Next slice should target year-filter/summary/output fanout or output settling. |
| K-A1 | Targeted reuse | Reuse/minimally extend existing VP trade context metadata if fanout is localized and current caches are mostly sound | Deferred | Superseded by K-A first slice plus K-R evidence that artifact/working-set architecture is the larger next lever. | Revisit only inside a future architecture plan if commodity-partition provider APIs expose a small metadata reuse target. |
| K-B | Cache-key/schema repair | Repair behavior/cache identity if invalidation/key variance controls latency | Deferred | No narrow cache-key/schema repair was selected after K-A/K-R. | Revisit only if the next lazy partition plan finds stale/over-invalidating partition cache identity. |
| K-C | Provider/partition redesign | Redesign provider/partition/index behavior if it dominates latency | Deferred into next architecture plan | K-R proved artifact bulk and active working-set size are larger than another small Provider v3 repair. | Carry forward as aggressive lazy partition architecture, not as an incremental Branch K patch. |
| K-D | Build/pipeline metadata | Move proven stable discovery/aggregation out of Shiny if contract-safe | Deferred into next architecture plan | K-R supports moving startup shell metadata, partition indexes, and rollup sidecar manifests to build time, but this needs a separate design. | Include in the future shell/commodity-partition/rollup-sidecar plan. |
| K-E | Pivot | Close K as negative attribution if hierarchy/cache is not controlling usability | Complete as redirect | K-A produced behavior-safe but insufficient small wins; K-R identified a larger startup/artifact-load lever. | Branch K closes as redirect to a bigger data-architecture plan. |
| K-R | Rollup ablation granddaughter | Test whether embedded VP rollup rows inflate the main runtime artifact enough to affect startup, provider work, hierarchy/filter lag, tab switching, or tab paint | Complete / closed | `VP Clone/Code Review/2026-08-03_vp_branch_k_rollup_ablation_experiment_plan.md`; K-R6 startup pairs and tab-only pairs; K-R8 closeout | Roll-up complete. Embedded rollup bulk is a startup/artifact-load lever; tab-only benefit remains unproven; recommend lazy partition architecture. |
| K-8 | Closeout | Summarize accepted work, failures, speed results, residual risk, and next target | Complete | This ledger and parent performance ledger | Branch K is closed. Pause before creating the next standalone architecture plan. |

## K-0 Baseline Commands

Use the R 4.5.1 executable already used by prior tranches. Exact output paths and fallback runtime JSONLs must be copied into the evidence ledger after each accepted run.

```powershell
& "C:\Program Files\R\R-4.5.1\bin\Rscript.exe" "System/Testing/vp_perf_probe_hierarchy_sidebar_cascade.R" --label=step21_branch_k_hierarchy_sidebar_baseline --cache-state=warm_partition_disk --runtime-perf=true
& "C:\Program Files\R\R-4.5.1\bin\Rscript.exe" "System/Testing/vp_perf_probe_hierarchy_transition.R" --label=step21_branch_k_hierarchy_transition_baseline --cache-state=warm_partition_disk --runtime-perf=true
& "C:\Program Files\R\R-4.5.1\bin\Rscript.exe" "System/Testing/vp_perf_probe_single_action_latency.R" --label=step21_branch_k_canonical_baseline --scenario=canonical --cache-state=warm_partition_disk --runtime-perf=true
& "C:\Program Files\R\R-4.5.1\bin\Rscript.exe" "System/Testing/vp_perf_probe_single_action_latency.R" --label=step21_branch_k_tab_only_baseline --scenario=tab_only --cache-state=warm_partition_disk --runtime-perf=true
& "C:\Program Files\R\R-4.5.1\bin\Rscript.exe" "System/Testing/vp_perf_probe_startup.R" --label=step21_branch_k_startup_guard_baseline --cache-state=warm_partition_disk --runtime-perf=true --target-tab="Current vs. Average"
```

Warm-session reruns should be added after the first K-0 pass if the probes support the label cleanly and the first-pass evidence indicates cache-state sensitivity.

## Verification Requirements

1. Before app-code edits, run K-0 probes with comparable cache state and record exact CSV/JSONL outputs in this ledger.
2. For decisive hierarchy/cache gates, prefer paired `warm_partition_disk` and `warm_session` evidence.
3. If cache/provider attribution is insufficient, add temporary or dev-only probes before optimizing.
4. After each source edit pass, parse touched R files using Rscript and record the parse marker.
5. After any hierarchy/cache change, run `vp_perf_probe_hierarchy_sidebar_cascade.R` before wider source edits.
6. Require hydrated child-control evidence and final canonical hierarchy path assertions, not just DOM wrapper presence or output visibility.
7. After each accepted tranche, run canonical, tab-only, startup guard, and focused Current/Data/Summary/CCT validation.
8. For provider/build metadata changes, run provider probes, artifact-present/artifact-missing fallback checks, stale/mismatch refusal checks, and manifest/schema-version checks.
9. Run a bounded repeated-action soak before accepting broad cache/provider changes, capturing churn, cache growth, provider mode distribution, and memory watermark trend.
10. Summarize runtime logs only from exact JSONL paths printed by accepted probes.
11. Run `git diff --check` for touched source, testing, and plan files.
12. Use diagnostics on touched files, interpreting known Shiny/global-symbol static-analysis noise only after parse/probes pass.
13. Include manual VP validation before closeout, especially hierarchy path selection and visible AP usability.

## Blockers and Refinements

1. Missing Branch K ledger is resolved by this file; K-0 baseline remains the first active blocker.
2. Probe reliability remains a blocker if hierarchy readiness is judged from wrapper presence. Use target-membership waits, hydrated child-control evidence, and two-pass decisive gates.
3. Cache-state comparability is a blocker for speed claims. Keep `unknown_cache_state` out of new acceptance evidence and keep startup-lane rows separate from warm interaction rows.
4. Runtime log path ambiguity is a blocker for reproducibility. Record requested and actual runtime paths for every accepted probe run.
5. Broad provider redesign is allowed but high risk. It needs evidence that provider/partition behavior is a dominant user-visible wait, plus checkpointed artifact design, runtime reader, fallback, and validation tranches.
6. Build/pipeline artifacts can silently worsen startup. Any Path D work must measure artifact size, load time, schema compatibility, and artifact-missing fallback.
7. Windows/OneDrive file locking can corrupt or delay artifact writes. Provider/build redesign must use atomic writes or explicit refusal/retry behavior.
8. Long-session drift is under-covered by one-shot probes. Add a bounded repeated-action soak before accepting broad cache/provider changes.
9. Previously rejected comparison-cache work remains excluded unless a separate mini-tranche proves it is implicated and defines rollback criteria.
10. Checkpoint discipline is mandatory after probe-contract edits, cache-key/schema edits, provider/plumbing edits, and before broadening validation.

## Evidence Ledger

### K-0 Ledger Creation - 2026-08-03

- Created this Branch K source-of-truth ledger before app-code edits.
- Active next action was to run K-0 baseline probes and record exact outputs/runtime JSONLs.
- No source files changed for Branch K yet.

### K-0 Evidence Review / Recenter Decision - 2026-08-03

Reviewed the parent hotspot plan and the completed daughter plan evidence before choosing the next Branch K direction.

Lessons carried forward:
- Provider/partition redesign is not the first Branch K move. Step 9 reduced provider disk-cache time materially, and K-0 confirms provider/filter timing is measurable but not the top user-visible wait.
- Output/htmlwidget readiness remains real, but Branch G/H/I already spent substantial effort proving that the tab shell is cheap, broad hidden-output warming is bad, removing `Plotly.redraw()` is bad, and simple Trend/Heatmap payload/server-complexity reduction is not proven. Another broad attribution tranche would likely repeat that work.
- Hierarchy actions remain among the worst user-visible paths. K-0 still shows group/subgroup choices in the 20-26 second range and hierarchy stages around 57-67 seconds.
- Branch E and Branch F proved that hierarchy/reactive cascade work can produce substantive elapsed-time wins, but residual churn remains across display-month, type-choice, quantity-unit, mixed-volume, filtered-data, summary/projection, year-filter, and map surfaces.

Decision:
- Recenter Branch K on a shared hierarchy cascade/fanout refactor. The working target is not raw row filtering and not provider disk I/O. The working target is that one hierarchy action should settle through one stable resolved hierarchy context and one controlled downstream invalidation wave instead of many sibling consumers rediscovering and invalidating related state independently.
- Run only a narrow K-0.5 fanout attribution gate before app-code edits. The gate should confirm which consumers participate in the hierarchy fanout and where the smallest safe shared-context boundary belongs. If the gate confirms fanout, proceed to K-A. If it falsifies fanout, record the negative finding and pivot.

### K-0 First-Pass Baseline - 2026-08-03

Cache state: `warm_partition_disk`.

Probe status:
- Hierarchy/sidebar cascade PASS.
	- Output: `VP Clone/Logs/vp_perf_probe_hierarchy_sidebar_cascade_step21_branch_k_hierarchy_sidebar_baseline_20260803T135524Z.csv`
	- Requested runtime log: `VP Clone/Logs/vp_runtime_perf_hierarchy_sidebar_step21_branch_k_hierarchy_sidebar_baseline_20260803T135524Z.jsonl`
	- Fallback inputs: `VP Clone/Logs/vp_runtime_perf_b2e7ded2de562a1a2f2b9670ae52b50f.jsonl` and `VP Clone/Logs/vp_runtime_perf_proc_20260803T135538Z_29268.jsonl`
	- Total: 194781 ms.
	- Hierarchy stage: 67274 ms.
	- Trade flow: 13196 ms.
	- Group choice: 24233 ms.
	- Subgroup choice: 25945 ms.
	- Segment choice: 14112 ms.
- Hierarchy transition PASS.
	- Output: `VP Clone/Logs/vp_perf_probe_hierarchy_transition_step21_branch_k_hierarchy_transition_baseline_20260803T135849Z.csv`
	- Requested runtime log: `VP Clone/Logs/vp_runtime_perf_hierarchy_transition_step21_branch_k_hierarchy_transition_baseline_20260803T135849Z.jsonl`
	- Total: 156756 ms.
	- Hierarchy stage: 57073 ms.
	- Group choice: 20609 ms.
	- Subgroup choice: 22944 ms.
	- Segment choice: 11786 ms.
- Canonical single-action PASS=13.
	- Output: `VP Clone/Logs/vp_perf_probe_single_action_latency_step21_branch_k_canonical_baseline_20260803T140132Z.csv`
	- Requested runtime log: `VP Clone/Logs/vp_runtime_perf_single_action_step21_branch_k_canonical_baseline_20260803T140132Z.jsonl`
	- Fallback inputs: `VP Clone/Logs/vp_runtime_perf_proc_20260803T140136Z_33736.jsonl` and `VP Clone/Logs/vp_runtime_perf_81cb0e418b16a8c0c41ffbd9822ff5cd.jsonl`
	- Total: 206497 ms.
	- Visible-ready timings: group to Dry pulses 15463 ms; subgroup to Dried beans 14480 ms; segment to Dried 82 ms; commodity specific to all 2636 ms; Historical Trend tab 9780 ms; Heatmap tab 10434 ms; Map tab 11736 ms; Current return 8557 ms; pending-tab Historical Trend 11106 ms; return Current after pending tab 10148 ms.
- Tab-only single-action PASS=4.
	- Output: `VP Clone/Logs/vp_perf_probe_single_action_latency_step21_branch_k_tab_only_baseline_20260803T140517Z.csv`
	- Requested runtime log: `VP Clone/Logs/vp_runtime_perf_single_action_step21_branch_k_tab_only_baseline_20260803T140517Z.jsonl`
	- Fallback inputs: `VP Clone/Logs/vp_runtime_perf_dfd8123cdd8b89ca19396cf06abb7513.jsonl` and `VP Clone/Logs/vp_runtime_perf_proc_20260803T140525Z_31740.jsonl`
	- Total: 138178 ms.
	- Visible-ready timings: Historical Trend 8490 ms; Heatmap 8396 ms; Map 10377 ms; Current 7469 ms.
- Startup guard PASS.
	- Output: `VP Clone/Logs/vp_perf_probe_startup_step21_branch_k_startup_guard_baseline_20260803T140742Z.csv`
	- Requested runtime log: `VP Clone/Logs/vp_runtime_perf_startup_step21_branch_k_startup_guard_baseline_20260803T140742Z.jsonl`
	- Fallback inputs: `VP Clone/Logs/vp_runtime_perf_dfd8123cdd8b89ca19396cf06abb7513.jsonl`, `VP Clone/Logs/vp_runtime_perf_proc_20260803T140525Z_31740.jsonl`, `VP Clone/Logs/vp_runtime_perf_886ea8da980c6e9094ee5ad1ba0e5cb0.jsonl`, and `VP Clone/Logs/vp_runtime_perf_proc_20260803T140745Z_16764.jsonl`
	- Total: 79167 ms.
	- Startup ready: 78574 ms.
	- Output wait: 17 ms.

Runtime summary:
- Label: `step21_branch_k_k0_runtime_summary`.
- Summary files:
	- `VP Clone/Logs/vp_perf_runtime_summary_step21_branch_k_k0_runtime_summary_20260803T140914Z_files.csv`
	- `VP Clone/Logs/vp_perf_runtime_summary_step21_branch_k_k0_runtime_summary_20260803T140914Z_events.csv`
	- `VP Clone/Logs/vp_perf_runtime_summary_step21_branch_k_k0_runtime_summary_20260803T140914Z_timed.csv`
	- `VP Clone/Logs/vp_perf_runtime_summary_step21_branch_k_k0_runtime_summary_20260803T140914Z_key_delta.csv`
	- `VP Clone/Logs/vp_perf_runtime_summary_step21_branch_k_k0_runtime_summary_20260803T140914Z_churn.csv`
	- `VP Clone/Logs/vp_perf_runtime_summary_step21_branch_k_k0_runtime_summary_20260803T140914Z_partition.csv`
	- `VP Clone/Logs/vp_perf_runtime_summary_step21_branch_k_k0_runtime_summary_20260803T140914Z_memory.csv`
- Runtime files summarized: 8.
- Runtime records summarized: 1780.
- Top timed rows:
	- `client_perf|tab_shown`: count 8, total 85.735 seconds, median 10.9425 seconds, max 12.461 seconds.
	- `client_perf|tab_after_paint`: count 14, total 79.973 seconds, max 20.815 seconds.
	- `client_perf|main_tabs_mount`: count 4, total 79.692 seconds, median 19.884 seconds.
	- `startup_init(total_pre_ui)`: count 4, total 78.6787 seconds, median 18.42955 seconds, max 25.2348 seconds.
	- `startup_init(load_vp_trade_monthly_data)`: count 4, total 60.0661 seconds, median 14.5508 seconds, max 18.1858 seconds.
	- `startup_init(load_vp_trade_monthly_data): artifact_read`: count 4, total 58.1989 seconds, median 14.12655 seconds, max 17.5907 seconds.
	- `filter_vp_rows_for_resolved_hierarchy()` partition-provider mode: count 137, total 8.7705 seconds, median 0.046 seconds, p95 0.21004 seconds, max 0.3118 seconds.
	- `artifact_signature(build_file_signature)`: count 136, total 5.4429 seconds.
	- `projection_data()`: count 30, total 4.8905 seconds.
	- `summary_table`: count 27, total 4.0137 seconds.
	- `filtered_data()`: count 8, total 3.3396 seconds.
	- `filtered_data_for_country()`: count 8, total 3.0258 seconds.
- Partition summary:
	- `memory_cache`: 124 events, total 0.6767 seconds.
	- `disk_cache`: 13 events, total 1.8372 seconds.
- Top churn rows include display-month mapping cache hits, map bottom-panel gated skips, year-filter sync observer, summary table execution, filtered-data hierarchy filtering, mixed-volume-family checks, quantity-unit context, and type-choice base values.

Interpretation:
- The first-pass baseline confirms the AP usability gap: tab-only visible-ready waits are 7.469-10.377 seconds, versus the 1-3 second aspiration target.
- Hierarchy cascade remains expensive in probe time: hierarchy transition stage is 57.073 seconds and hierarchy/sidebar hierarchy stage is 67.274 seconds.
- Runtime timed attribution does not show provider row filtering alone as the dominant cost. Partition-provider filtering totals 8.7705 seconds across 137 calls, while client tab paint/mount and startup artifact load dominate top timed rows.
- Provider disk-cache time is not the main first-pass bottleneck by itself: 13 disk-cache events total 1.8372 seconds, while memory-cache provider events total 0.6767 seconds.
- Startup/artifact load is a major separate lane: `load_vp_trade_monthly_data` and artifact read total about 60.0661 and 58.1989 seconds across four sessions.
- K-0 first pass was not sufficient by itself for final architecture decision because Branch K requires a second pass or warm-session confirmation for decisive hierarchy/cache gates.

### K-0 Warm-Session Confirmation - 2026-08-03

Cache state: `warm_session`.

Probe status:
- Hierarchy transition PASS.
	- Output: `VP Clone/Logs/vp_perf_probe_hierarchy_transition_step21_branch_k_hierarchy_transition_warm_session_confirm_20260803T141020Z.csv`
	- Requested runtime log: `VP Clone/Logs/vp_runtime_perf_hierarchy_transition_step21_branch_k_hierarchy_transition_warm_session_confirm_20260803T141020Z.jsonl`
	- Total: 170990 ms.
	- Hierarchy stage: 63798 ms.
	- Trade flow: 12938 ms.
	- Group choice: 25716 ms.
	- Subgroup choice: 23039 ms.
	- Segment choice: 13273 ms.
- Tab-only single-action PASS=4.
	- Output: `VP Clone/Logs/vp_perf_probe_single_action_latency_step21_branch_k_tab_only_warm_session_confirm_20260803T141314Z.csv`
	- Requested runtime log: `VP Clone/Logs/vp_runtime_perf_single_action_step21_branch_k_tab_only_warm_session_confirm_20260803T141314Z.jsonl`
	- Fallback inputs: `VP Clone/Logs/vp_runtime_perf_14f24a77dac3b255bfdb1d1eab94714c.jsonl` and `VP Clone/Logs/vp_runtime_perf_proc_20260803T141319Z_21360.jsonl`
	- Total: 141914 ms.
	- Visible-ready timings: Historical Trend 9054 ms; Heatmap 8780 ms; Map 13127 ms; Current 8027 ms.

Runtime summary:
- Label: `step21_branch_k_k0_warm_session_confirm_runtime_summary`.
- Summary files:
	- `VP Clone/Logs/vp_perf_runtime_summary_step21_branch_k_k0_warm_session_confirm_runtime_summary_20260803T141543Z_files.csv`
	- `VP Clone/Logs/vp_perf_runtime_summary_step21_branch_k_k0_warm_session_confirm_runtime_summary_20260803T141543Z_events.csv`
	- `VP Clone/Logs/vp_perf_runtime_summary_step21_branch_k_k0_warm_session_confirm_runtime_summary_20260803T141543Z_timed.csv`
	- `VP Clone/Logs/vp_perf_runtime_summary_step21_branch_k_k0_warm_session_confirm_runtime_summary_20260803T141543Z_key_delta.csv`
	- `VP Clone/Logs/vp_perf_runtime_summary_step21_branch_k_k0_warm_session_confirm_runtime_summary_20260803T141543Z_churn.csv`
	- `VP Clone/Logs/vp_perf_runtime_summary_step21_branch_k_k0_warm_session_confirm_runtime_summary_20260803T141543Z_partition.csv`
	- `VP Clone/Logs/vp_perf_runtime_summary_step21_branch_k_k0_warm_session_confirm_runtime_summary_20260803T141543Z_memory.csv`
- Runtime files summarized: 2.
- Runtime records summarized: 373.
- Top timed rows:
	- `client_perf|tab_shown`: count 3, total 33.575 seconds, median 9.918 seconds, max 14.167 seconds.
	- `startup_init(total_pre_ui)`: count 1, total 20.6605 seconds.
	- `client_perf|tab_after_paint`: count 5, total 20.106 seconds, max 19.985 seconds.
	- `client_perf|main_tabs_mount`: count 1, total 19.963 seconds.
	- `startup_init(load_vp_trade_monthly_data)`: count 1, total 16.032 seconds.
	- `startup_init(load_vp_trade_monthly_data): artifact_read`: count 1, total 15.5651 seconds.
	- `filter_vp_rows_for_resolved_hierarchy()` partition-provider mode: count 22, total 1.7153 seconds, median 0.05145 seconds, max 0.361 seconds.
	- `vp_partition_provider_slice()` disk cache: count 2, total 0.5314 seconds.

Interpretation:
- Warm-session confirmation agrees with K-0 first pass: tab-only visible-ready waits remain about 8.027-13.127 seconds, still far above the 1-3 second aspiration.
- Hierarchy transition remains expensive in probe stage timing, but runtime logs still do not identify provider/partition row filtering as the dominant timed bucket.
- The highest timed buckets remain client tab shown/after-paint/main-tabs mount and startup artifact loading.
- First architecture implication: do not start Branch K with Path C provider/partition redesign. Provider redesign remains allowed later if a narrower attribution pass proves it controls a user-visible wait, but K-0 evidence does not support it as the first implementation move.
- Current recommended next action: K-0.5/K-1 attribution around client tab paint/main-tabs mount/output settling and startup artifact load, with display-month/year-filter/summary churn as secondary candidates. This may become Path E pivot or a focused output/startup tranche rather than hierarchy cache architecture edits.

### K-0.5 Fanout Attribution Instrumentation and First Gate - 2026-08-03

Files changed:
- `VP Clone/Programs/app_source/server/02_partner_and_notes.R`
  - Added `vp_hierarchy_fanout_context()` beside the hierarchy nonce state.
  - Added hierarchy generation, last-changed input, resolved hierarchy signature, resolved hierarchy tokens, trade flow, commodity name, and commodity detail to existing `filter_vp_rows_for_resolved_hierarchy_*` cache-body events.
  - Added the same fanout context to `data_frequency_ui_rendered`.
- `VP Clone/Programs/app_source/server/03_core_reactives_and_ui.R`
  - Added fanout context to display-month mapping cache hit/miss events.
- `VP Clone/Programs/app_source/server/04_comparison_plots.R`
  - Added fanout context to `summary_table_executed`.
- `VP Clone/System/Testing/vp_perf_summarize_runtime_logs.R`
  - Added `_fanout.csv` output grouping cache-body churn by runtime session, hierarchy generation, last-changed input, hierarchy signature, event name, filter purpose, and active tab.
  - Fixed a summarizer robustness bug where fallback runtime JSONLs with missing elapsed columns aborted in `add_runtime_labels()`.

Validation:
- First source slice parse marker: `PARSE_OK_BRANCH_K_K05_FANOUT_CONTEXT_02`.
- All touched R files parse marker: `PARSE_OK_BRANCH_K_K05_FANOUT_ALL`.
- Summarizer fallback fix parse marker: `PARSE_OK_BRANCH_K_K05_SUMMARIZER_FALLBACK`.

Focused probe:
- Command label: `step21_branch_k_k05_fanout_attribution_hierarchy_transition`.
- Cache state: `warm_partition_disk`.
- Status: FAIL, but hierarchy stages completed.
- Output: `VP Clone/Logs/vp_perf_probe_hierarchy_transition_step21_branch_k_k05_fanout_attribution_hierarchy_transition_20260803T143328Z.csv`.
- Requested runtime log: `VP Clone/Logs/vp_runtime_perf_hierarchy_transition_step21_branch_k_k05_fanout_attribution_hierarchy_transition_20260803T143328Z.jsonl`.
- Actual fallback app runtime input: `VP Clone/Logs/vp_runtime_perf_214f7b647092b4d9f274385c30266702.jsonl`.
- Matching process runtime log also written: `VP Clone/Logs/vp_runtime_perf_proc_20260803T143343Z_32284.jsonl`.
- Total: 187101 ms.
- Startup ready: 64939 ms.
- Source switch: 30210 ms, `wait_ok=FALSE`.
- Trade flow: 34232 ms, `wait_ok=TRUE`.
- Hierarchy stage: 57604 ms.
- Group choice: 20192 ms.
- Subgroup choice: 22392 ms.
- Segment choice: 10926 ms.
- Error: `missing_controls:data_source_choice|vp_trade_flow_choice|vp_group_choice|vp_subgroup_choice|vp_market_segment_choice|country_choice|main_tabs_panel || source_switch:wait_failed:An error occurred while waiting for Shiny to be stable`.

Runtime summary from fallback app log:
- Label: `step21_branch_k_k05_fanout_attribution_hierarchy_transition_fallback_app`.
- Summary files:
	- `VP Clone/Logs/vp_perf_runtime_summary_step21_branch_k_k05_fanout_attribution_hierarchy_transition_fallback_app_20260803T143744Z_files.csv`
	- `VP Clone/Logs/vp_perf_runtime_summary_step21_branch_k_k05_fanout_attribution_hierarchy_transition_fallback_app_20260803T143744Z_events.csv`
	- `VP Clone/Logs/vp_perf_runtime_summary_step21_branch_k_k05_fanout_attribution_hierarchy_transition_fallback_app_20260803T143744Z_timed.csv`
	- `VP Clone/Logs/vp_perf_runtime_summary_step21_branch_k_k05_fanout_attribution_hierarchy_transition_fallback_app_20260803T143744Z_key_delta.csv`
	- `VP Clone/Logs/vp_perf_runtime_summary_step21_branch_k_k05_fanout_attribution_hierarchy_transition_fallback_app_20260803T143744Z_churn.csv`
	- `VP Clone/Logs/vp_perf_runtime_summary_step21_branch_k_k05_fanout_attribution_hierarchy_transition_fallback_app_20260803T143744Z_fanout.csv`
	- `VP Clone/Logs/vp_perf_runtime_summary_step21_branch_k_k05_fanout_attribution_hierarchy_transition_fallback_app_20260803T143744Z_partition.csv`
	- `VP Clone/Logs/vp_perf_runtime_summary_step21_branch_k_k05_fanout_attribution_hierarchy_transition_fallback_app_20260803T143744Z_memory.csv`
- Runtime files summarized: 1.
- Runtime records summarized: 170.
- Top timed rows in this fallback app log: `client_perf|tab_after_paint` 23.623 seconds, `client_perf|main_tabs_mount` 23.596 seconds, `client_perf|plotly_resize` 0.123 seconds.
- Top churn rows: `display_month_mapping_cache_hit` count 15, `summary_table_executed` count 11, `map_bottom_panel_ui_gated_skip` count 10, `filter_vp_rows_for_resolved_hierarchy_filtered_data` count 9, `data_frequency_ui_rendered` count 8.

Fanout evidence:
- The new `_fanout.csv` groups sibling work by hierarchy generation/signature and confirms the shared cascade/fanout hypothesis for the first gate.
- Generation 3 (`vp_market_segment_choice`) includes repeated display-month cache hits/misses, comparison commodity choices, summary-table execution, filtered-data hierarchy filtering, data-frequency UI render, mixed-volume-family check, quantity-unit context, type-choice base values, and display-month mapping filtering under related signatures.
- Generation 4 (`vp_group_choice`) includes display-month cache hits/misses, summary-table execution, data-frequency UI render, display-month mapping filtering, filtered-data hierarchy filtering, mixed-volume-family check, quantity-unit context, and type-choice base values under group/subgroup transition signatures.
- Generation 5 (`vp_subgroup_choice`) includes display-month cache hits/misses, summary-table execution, data-frequency UI render, display-month mapping filtering, filtered-data hierarchy filtering, mixed-volume-family check, quantity-unit context, and type-choice base values under subgroup/segment transition signatures.
- Some non-instrumented cache-body events still lack hierarchy fields, including `map_bottom_panel_ui_gated_skip`, `type_choice_base_values_cache_hit/miss`, `year_filter_sync_observer`, and `vp_hierarchy_change_nonce_bumped`. These are not blockers for the first K-A slice, but they are useful candidates if later attribution needs tighter grouping.

Interpretation:
- K-0.5 does not provide a clean PASS speed run because the source-switch wait failed and final controls were missing, so it must not be used as an accepted performance improvement baseline.
- K-0.5 does provide enough fanout attribution to choose Path A. The hierarchy waves contain repeated sibling consumers and duplicate context/cache activity around display-month, filtered data, quantity units, mixed volume, type choices, summary, and sidebar/UI render surfaces.
- Provider/partition redesign remains allowed later, but this pass again points first toward shared hierarchy context/invalidation control rather than provider disk/cache redesign.
- Proceed to K-A with a conservative shared resolved hierarchy context boundary. The first behavior slice should reduce repeated context resolution/fanout without changing visible hierarchy controls or cache correctness.

### K-A First Slice: Resolved Hierarchy Context Cache - 2026-08-03

Implementation:
- File changed: `VP Clone/Programs/app_source/server/02_partner_and_notes.R`.
- Added a bounded session-local `vp_resolved_hierarchy_cache` keyed by normalized group/subgroup/segment choices, faceted hierarchy flag, and rollup token values.
- Added `vp_resolved_hierarchy_cache_key()`, `vp_resolved_hierarchy_cache_get()`, `vp_resolved_hierarchy_cache_set()`, and throttled `vp_resolved_hierarchy_cache_hit_milestone()` helpers using the existing local cache style.
- Updated `resolve_vp_hierarchy_tokens()` to return cached resolved hierarchy context when available, and to cache misses after canonicalization.
- Kept all existing call sites and visible behavior unchanged. This slice intentionally avoids threading a new argument through all consumers until the first shared boundary proves safe.

Validation:
- Parse marker after first cache implementation: `PARSE_OK_BRANCH_K_KA_RESOLVED_HIERARCHY_CACHE_02`.
- First hierarchy/sidebar probe after implementation passed but exposed instrumentation noise.
	- Label: `step21_branch_k_ka_resolved_hierarchy_context_cache_sidebar`.
	- Output: `VP Clone/Logs/vp_perf_probe_hierarchy_sidebar_cascade_step21_branch_k_ka_resolved_hierarchy_context_cache_sidebar_20260803T144033Z.csv`.
	- Fallback inputs: `VP Clone/Logs/vp_runtime_perf_proc_20260803T144048Z_2000.jsonl` and `VP Clone/Logs/vp_runtime_perf_28250e1418c459d58ef01d771a16b9a7.jsonl`.
	- Status: PASS.
	- Total: 208197 ms.
	- Hierarchy stage: 63952 ms.
	- Runtime summary: `VP Clone/Logs/vp_perf_runtime_summary_step21_branch_k_ka_resolved_hierarchy_context_cache_sidebar_20260803T144407Z_*`.
	- Runtime summary showed `vp_resolved_hierarchy_context_cache_hit` count 902, which confirmed heavy repeated resolution but made the logger itself too noisy for acceptance.
- Repair: throttled resolved-context cache hit logging to per-key milestone counts while preserving normal miss logging.
- Parse marker after throttling: `PARSE_OK_BRANCH_K_KA_RESOLVED_HIERARCHY_CACHE_THROTTLED_02`.
- Hierarchy/sidebar rerun after throttling:
	- Label: `step21_branch_k_ka_resolved_hierarchy_context_cache_sidebar_rerun`.
	- Output: `VP Clone/Logs/vp_perf_probe_hierarchy_sidebar_cascade_step21_branch_k_ka_resolved_hierarchy_context_cache_sidebar_rerun_20260803T144546Z.csv`.
	- Requested runtime log: `VP Clone/Logs/vp_runtime_perf_hierarchy_sidebar_step21_branch_k_ka_resolved_hierarchy_context_cache_sidebar_rerun_20260803T144547Z.jsonl`.
	- Fallback inputs: `VP Clone/Logs/vp_runtime_perf_proc_20260803T144549Z_30108.jsonl` and `VP Clone/Logs/vp_runtime_perf_694f639f736566336662b452d6326ddc.jsonl`.
	- Status: PASS.
	- Total: 144855 ms.
	- Hierarchy stage: 55869 ms.
	- Trade flow: 11588 ms.
	- Group choice: 20486 ms.
	- Subgroup choice: 21491 ms.
	- Segment choice: 10830 ms.
- Runtime summary after throttling:
	- Label: `step21_branch_k_ka_resolved_hierarchy_context_cache_sidebar_rerun`.
	- Summary files:
	- `VP Clone/Logs/vp_perf_runtime_summary_step21_branch_k_ka_resolved_hierarchy_context_cache_sidebar_rerun_20260803T144820Z_files.csv`
	- `VP Clone/Logs/vp_perf_runtime_summary_step21_branch_k_ka_resolved_hierarchy_context_cache_sidebar_rerun_20260803T144820Z_events.csv`
	- `VP Clone/Logs/vp_perf_runtime_summary_step21_branch_k_ka_resolved_hierarchy_context_cache_sidebar_rerun_20260803T144820Z_timed.csv`
	- `VP Clone/Logs/vp_perf_runtime_summary_step21_branch_k_ka_resolved_hierarchy_context_cache_sidebar_rerun_20260803T144820Z_key_delta.csv`
	- `VP Clone/Logs/vp_perf_runtime_summary_step21_branch_k_ka_resolved_hierarchy_context_cache_sidebar_rerun_20260803T144820Z_churn.csv`
	- `VP Clone/Logs/vp_perf_runtime_summary_step21_branch_k_ka_resolved_hierarchy_context_cache_sidebar_rerun_20260803T144820Z_fanout.csv`
	- `VP Clone/Logs/vp_perf_runtime_summary_step21_branch_k_ka_resolved_hierarchy_context_cache_sidebar_rerun_20260803T144820Z_partition.csv`
	- `VP Clone/Logs/vp_perf_runtime_summary_step21_branch_k_ka_resolved_hierarchy_context_cache_sidebar_rerun_20260803T144820Z_memory.csv`
	- Runtime records summarized: 460, down from 1355 in the noisy first K-A run.
	- Top churn after throttling: `vp_resolved_hierarchy_context_cache_hit` count 24, `display_month_mapping_cache_hit` count 17, `summary_table_executed` count 11, `map_bottom_panel_ui_gated_skip` count 10, `filter_vp_rows_for_resolved_hierarchy_filtered_data` count 9.

Interpretation:
- The first K-A slice is behavior-safe for the hierarchy/sidebar contract based on the rerun PASS.
- The rerun is directionally better than the K-0 sidebar baseline: total 144855 ms versus 194781 ms, and hierarchy stage 55869 ms versus 67274 ms. This is not yet enough for an accepted branch-wide speed claim because only one post-repair sidebar run has been collected and canonical/tab-only validation is still pending.
- The initial noisy run was useful evidence: 902 resolved-context cache hits confirmed the repeated hierarchy-resolution fanout K-A targets. The throttled rerun kept that evidence visible without overloading runtime logs.
- Next K-A decision: either broaden validation with canonical/tab-only probes for this slice or use the new fanout/churn summaries to implement the next smallest consumer reuse slice. Do not proceed to provider redesign based on this evidence.

### K-A Broadened Validation: Canonical and Tab-Only - 2026-08-03

Canonical single-action validation:
- Label: `step21_branch_k_ka_resolved_hierarchy_context_cache_canonical`.
- Scenario: `canonical`.
- Cache state: `warm_partition_disk`.
- Status: PASS=13.
- Output: `VP Clone/Logs/vp_perf_probe_single_action_latency_step21_branch_k_ka_resolved_hierarchy_context_cache_canonical_20260803T145309Z.csv`.
- Requested runtime log: `VP Clone/Logs/vp_runtime_perf_single_action_step21_branch_k_ka_resolved_hierarchy_context_cache_canonical_20260803T145309Z.jsonl`.
- Fallback inputs: `VP Clone/Logs/vp_runtime_perf_proc_20260803T145314Z_5928.jsonl` and `VP Clone/Logs/vp_runtime_perf_8fb4e8eda0684385b416a02439645ad7.jsonl`.
- Total: 240920 ms.
- Action-level visible-ready timings:
	- Group all to Dry pulses: 20443 ms.
	- Subgroup all to Dried beans: 18878 ms.
	- Segment all to Dried: 89 ms visible-ready, but 11917 ms full idle.
	- Commodity all to specific: 3083 ms.
	- Commodity specific to all: 2005 ms.
	- Historical Trend tab: 8988 ms.
	- Heatmap tab: 9354 ms.
	- Map tab: 11384 ms.
	- Current tab return: 8961 ms.
	- Pending-tab Historical Trend: 10899 ms.
	- Current return after pending tab: 8769 ms.
- Runtime summary label: `step21_branch_k_ka_resolved_hierarchy_context_cache_canonical`.
- Runtime summary files:
	- `VP Clone/Logs/vp_perf_runtime_summary_step21_branch_k_ka_resolved_hierarchy_context_cache_canonical_20260803T145720Z_files.csv`
	- `VP Clone/Logs/vp_perf_runtime_summary_step21_branch_k_ka_resolved_hierarchy_context_cache_canonical_20260803T145720Z_events.csv`
	- `VP Clone/Logs/vp_perf_runtime_summary_step21_branch_k_ka_resolved_hierarchy_context_cache_canonical_20260803T145720Z_timed.csv`
	- `VP Clone/Logs/vp_perf_runtime_summary_step21_branch_k_ka_resolved_hierarchy_context_cache_canonical_20260803T145720Z_key_delta.csv`
	- `VP Clone/Logs/vp_perf_runtime_summary_step21_branch_k_ka_resolved_hierarchy_context_cache_canonical_20260803T145720Z_churn.csv`
	- `VP Clone/Logs/vp_perf_runtime_summary_step21_branch_k_ka_resolved_hierarchy_context_cache_canonical_20260803T145720Z_fanout.csv`
	- `VP Clone/Logs/vp_perf_runtime_summary_step21_branch_k_ka_resolved_hierarchy_context_cache_canonical_20260803T145720Z_partition.csv`
	- `VP Clone/Logs/vp_perf_runtime_summary_step21_branch_k_ka_resolved_hierarchy_context_cache_canonical_20260803T145720Z_memory.csv`
- Runtime records summarized: 723.
- Top timed rows: `client_perf|tab_shown` count 5 total 53.326 seconds; `startup_init(total_pre_ui)` 27.559 seconds; `startup_init(load_vp_trade_monthly_data)` 21.772 seconds; artifact read 21.062 seconds; `client_perf|tab_after_paint` count 7 total 19.187 seconds.
- Top churn rows: display-month mapping cache hit on Current count 33; resolved hierarchy context cache hit count 27; display-month mapping cache hit on Map count 19; map bottom-panel gated skip count 18; year-filter sync observer count 17.

Tab-only validation:
- Label: `step21_branch_k_ka_resolved_hierarchy_context_cache_tab_only`.
- Scenario: `tab_only`.
- Cache state: `warm_partition_disk`.
- Status: PASS=4.
- Output: `VP Clone/Logs/vp_perf_probe_single_action_latency_step21_branch_k_ka_resolved_hierarchy_context_cache_tab_only_20260803T145731Z.csv`.
- Requested runtime log: `VP Clone/Logs/vp_runtime_perf_single_action_step21_branch_k_ka_resolved_hierarchy_context_cache_tab_only_20260803T145731Z.jsonl`.
- Fallback inputs: `VP Clone/Logs/vp_runtime_perf_a4763cd1c965489f551e3437c38222a4.jsonl` and `VP Clone/Logs/vp_runtime_perf_proc_20260803T145734Z_14960.jsonl`.
- Total: 130557 ms.
- Visible-ready timings: Historical Trend 10873 ms; Heatmap 9175 ms; Map 12007 ms; Current 7931 ms.
- Runtime summary label: `step21_branch_k_ka_resolved_hierarchy_context_cache_tab_only`.
- Runtime summary files:
	- `VP Clone/Logs/vp_perf_runtime_summary_step21_branch_k_ka_resolved_hierarchy_context_cache_tab_only_20260803T145948Z_files.csv`
	- `VP Clone/Logs/vp_perf_runtime_summary_step21_branch_k_ka_resolved_hierarchy_context_cache_tab_only_20260803T145948Z_events.csv`
	- `VP Clone/Logs/vp_perf_runtime_summary_step21_branch_k_ka_resolved_hierarchy_context_cache_tab_only_20260803T145948Z_timed.csv`
	- `VP Clone/Logs/vp_perf_runtime_summary_step21_branch_k_ka_resolved_hierarchy_context_cache_tab_only_20260803T145948Z_key_delta.csv`
	- `VP Clone/Logs/vp_perf_runtime_summary_step21_branch_k_ka_resolved_hierarchy_context_cache_tab_only_20260803T145948Z_churn.csv`
	- `VP Clone/Logs/vp_perf_runtime_summary_step21_branch_k_ka_resolved_hierarchy_context_cache_tab_only_20260803T145948Z_fanout.csv`
	- `VP Clone/Logs/vp_perf_runtime_summary_step21_branch_k_ka_resolved_hierarchy_context_cache_tab_only_20260803T145948Z_partition.csv`
	- `VP Clone/Logs/vp_perf_runtime_summary_step21_branch_k_ka_resolved_hierarchy_context_cache_tab_only_20260803T145948Z_memory.csv`
- Runtime records summarized: 383.
- Top timed rows: `client_perf|tab_shown` count 3 total 34.176 seconds; `client_perf|tab_after_paint` count 5 total 17.780 seconds; `client_perf|main_tabs_mount` 17.652 seconds; `startup_init(total_pre_ui)` 16.234 seconds; `startup_init(load_vp_trade_monthly_data)` 12.667 seconds.
- Top churn rows: display-month mapping cache hit on Map count 19; display-month mapping cache hit on Current count 16; map bottom-panel gated skip count 8; summary-table execution count 7; year-filter sync observer count 7.

Broadened validation interpretation:
- Behavior safety improved: hierarchy/sidebar, canonical, and tab-only probes all pass with the resolved hierarchy context cache slice active.
- The speed story is mixed. Sidebar rerun and tab-only total are directionally better than K-0 baselines, but canonical total regressed from 206497 ms to 240920 ms and tab visible-ready timings remain roughly 7.9-12.0 seconds.
- This supports keeping the K-A resolved hierarchy context cache as a safe foundation and attribution aid, but it does not justify a branch-wide speed-win claim by itself.
- Runtime churn still points to display-month mapping cache hits, year-filter sync, map bottom-panel skips, summary-table execution, and output/tab paint as the next likely K-A targets.
- Provider/partition redesign is still not the next move based on these broadened probes.

### K-A Follow-Up: Display-Month Cache Hit Logging Throttle - 2026-08-03

Implementation:
- File changed: `VP Clone/Programs/app_source/server/03_core_reactives_and_ui.R`.
- Added `display_month_mapping_cache_hit_counts` and `display_month_mapping_cache_hit_milestone()`.
- Changed display-month cache hit logging to record per-key milestone hits only, mirroring the resolved hierarchy context cache hit throttling pattern.
- Behavior contract: mapping values and cache keys are unchanged; only repeated cache-hit logging is throttled.

Validation:
- Parse marker: `PARSE_OK_BRANCH_K_KA_DISPLAY_MONTH_HIT_THROTTLE_03`.
- Tab-only probe label: `step21_branch_k_ka_display_month_hit_throttle_tab_only`.
- Status: PASS=4.
- Output: `VP Clone/Logs/vp_perf_probe_single_action_latency_step21_branch_k_ka_display_month_hit_throttle_tab_only_20260803T150239Z.csv`.
- Requested runtime log: `VP Clone/Logs/vp_runtime_perf_single_action_step21_branch_k_ka_display_month_hit_throttle_tab_only_20260803T150239Z.jsonl`.
- Fallback inputs: `VP Clone/Logs/vp_runtime_perf_2aa22f66e1619688ce8c245ee6c57955.jsonl` and `VP Clone/Logs/vp_runtime_perf_proc_20260803T150242Z_30264.jsonl`.
- Total: 134731 ms.
- Visible-ready timings: Historical Trend 8812 ms; Heatmap 8132 ms; Map 17873 ms; Current 10854 ms.
- Runtime summary label: `step21_branch_k_ka_display_month_hit_throttle_tab_only`.
- Runtime summary files:
	- `VP Clone/Logs/vp_perf_runtime_summary_step21_branch_k_ka_display_month_hit_throttle_tab_only_20260803T150501Z_files.csv`
	- `VP Clone/Logs/vp_perf_runtime_summary_step21_branch_k_ka_display_month_hit_throttle_tab_only_20260803T150501Z_events.csv`
	- `VP Clone/Logs/vp_perf_runtime_summary_step21_branch_k_ka_display_month_hit_throttle_tab_only_20260803T150501Z_timed.csv`
	- `VP Clone/Logs/vp_perf_runtime_summary_step21_branch_k_ka_display_month_hit_throttle_tab_only_20260803T150501Z_key_delta.csv`
	- `VP Clone/Logs/vp_perf_runtime_summary_step21_branch_k_ka_display_month_hit_throttle_tab_only_20260803T150501Z_churn.csv`
	- `VP Clone/Logs/vp_perf_runtime_summary_step21_branch_k_ka_display_month_hit_throttle_tab_only_20260803T150501Z_fanout.csv`
	- `VP Clone/Logs/vp_perf_runtime_summary_step21_branch_k_ka_display_month_hit_throttle_tab_only_20260803T150501Z_partition.csv`
	- `VP Clone/Logs/vp_perf_runtime_summary_step21_branch_k_ka_display_month_hit_throttle_tab_only_20260803T150501Z_memory.csv`
- Runtime records summarized: 348, down from 383 in the prior K-A tab-only run.
- Top churn after throttle: map bottom-panel gated skip count 8; summary-table execution count 7; year-filter sync observer count 7; display-month mapping cache hit on Current count 5; filtered-data hierarchy filtering count 5.

Interpretation:
- The throttle achieved its narrow instrumentation goal: display-month mapping cache-hit events dropped from the prior tab-only top rows (`Map` count 19 and `Current` count 16) to a single top `Current` row count 5, and total runtime records dropped from 383 to 348.
- It did not improve user-visible tab readiness. Historical Trend and Heatmap improved versus the prior K-A tab-only run, but Map regressed from 12007 ms to 17873 ms and Current regressed from 7931 ms to 10854 ms.
- Keep this as logging cleanup if the goal is cleaner attribution, but do not count it as a performance tranche.
- The remaining top churn shifted toward map bottom-panel gating, summary table execution, year-filter sync, filtered-data hierarchy filtering, and output/tab paint. The next performance slice should target one of those behavior surfaces rather than further display-month hit logging.

### K-A Follow-Up: Map Bottom-Panel Hidden Suspension - 2026-08-03

Implementation:
- File changed: `VP Clone/Programs/app_source/server/05_trend_and_heatmap.R`.
- Changed `outputOptions(output, "map_bottom_panel_ui", suspendWhenHidden = FALSE)` to `suspendWhenHidden = TRUE`.
- Local hypothesis: the map bottom-panel UI was being kept live while hidden, causing repeated `map_bottom_panel_ui_gated_skip` executions during non-Map tab transitions. Suspending it while hidden should reduce this hidden output churn while still allowing the Map bottom panel to render when the Map tab is selected.
- Behavior risk: PSD source transitions also use the bottom panel, so this slice should remain provisional until a PSD/source-transition-focused smoke probe or manual check confirms no transition regression.

Validation:
- Parse marker: `PARSE_OK_BRANCH_K_KA_MAP_BOTTOM_PANEL_SUSPEND_05`.
- Tab-only probe label: `step21_branch_k_ka_map_bottom_panel_suspend_tab_only`.
- Scenario: `tab_only`.
- Cache state: `warm_partition_disk`.
- Status: PASS=4.
- Output: `VP Clone/Logs/vp_perf_probe_single_action_latency_step21_branch_k_ka_map_bottom_panel_suspend_tab_only_20260803T150749Z.csv`.
- Requested runtime log: `VP Clone/Logs/vp_runtime_perf_single_action_step21_branch_k_ka_map_bottom_panel_suspend_tab_only_20260803T150749Z.jsonl`.
- Fallback inputs: `VP Clone/Logs/vp_runtime_perf_278969794bbe2deae8aa46a2b1f3039c.jsonl` and `VP Clone/Logs/vp_runtime_perf_proc_20260803T150752Z_24588.jsonl`.
- Total: 144490 ms.
- Visible-ready timings: Historical Trend 9733 ms; Heatmap 9149 ms; Map 11665 ms; Current 8339 ms.
- Runtime summary label: `step21_branch_k_ka_map_bottom_panel_suspend_tab_only`.
- Runtime summary files:
	- `VP Clone/Logs/vp_perf_runtime_summary_step21_branch_k_ka_map_bottom_panel_suspend_tab_only_20260803T151022Z_files.csv`
	- `VP Clone/Logs/vp_perf_runtime_summary_step21_branch_k_ka_map_bottom_panel_suspend_tab_only_20260803T151022Z_events.csv`
	- `VP Clone/Logs/vp_perf_runtime_summary_step21_branch_k_ka_map_bottom_panel_suspend_tab_only_20260803T151022Z_timed.csv`
	- `VP Clone/Logs/vp_perf_runtime_summary_step21_branch_k_ka_map_bottom_panel_suspend_tab_only_20260803T151022Z_key_delta.csv`
	- `VP Clone/Logs/vp_perf_runtime_summary_step21_branch_k_ka_map_bottom_panel_suspend_tab_only_20260803T151022Z_churn.csv`
	- `VP Clone/Logs/vp_perf_runtime_summary_step21_branch_k_ka_map_bottom_panel_suspend_tab_only_20260803T151022Z_fanout.csv`
	- `VP Clone/Logs/vp_perf_runtime_summary_step21_branch_k_ka_map_bottom_panel_suspend_tab_only_20260803T151022Z_partition.csv`
	- `VP Clone/Logs/vp_perf_runtime_summary_step21_branch_k_ka_map_bottom_panel_suspend_tab_only_20260803T151022Z_memory.csv`
- Runtime records summarized: 341, down from 348 in the display-month throttle tab-only run and down from 383 in the first K-A tab-only run.
- Direct churn effect: `map_bottom_panel_ui_gated_skip` fell from count 8 in the previous tab-only run to count 1, and `map_bottom_panel_ui_executed` appeared count 2, confirming the panel still rendered when needed.
- Top churn after this slice: summary table execution count 7; year-filter sync observer count 7; display-month mapping cache hit on Current count 5; filtered-data hierarchy filtering count 5; data-frequency UI rendered count 4.

Interpretation:
- The local hypothesis was partially confirmed: hidden/gated map bottom-panel churn dropped substantially, and the Map tab still passed visible-ready checks.
- This is not a clean performance win. Total tab-only probe time worsened from 134731 ms in the display-month throttle run to 144490 ms, and it is worse than the first K-A tab-only total of 130557 ms. Historical Trend and Heatmap were also slower than the immediately prior tab-only run, while Map improved materially versus the display-month throttle run and was slightly better than the first K-A tab-only Map leg.
- Keep the change only as a behavior-safe output-settling cleanup if subsequent PSD/source-transition validation passes. Do not cite it as evidence that hidden-output suspension alone fixes AP tab readiness.
- The next K-A target should move to the remaining repeated active consumers: `summary_table_executed`, `year_filter_sync_observer`, filtered-data hierarchy filtering, or broader output/tab paint readiness.

### K-A Rejected Attempt: Year-Filter Lazy Sync Guard - 2026-08-03

Attempted implementation:
- File temporarily changed and then reverted: `VP Clone/Programs/app_source/server/03_core_reactives_and_ui.R`.
- Added an early return in the Historical Trend `year_filter_sync_observer` so that, once `year_filter_sync_signature()` was established, non-Historical tab changes would return before touching `filtered_data()` unless the Historical Trend tab needed an empty-selection reapply.
- Local hypothesis: tab-only transitions were repeatedly waking the year-filter observer, rebuilding year choices, and then discovering the update was a no-op. Deferring that work off the Historical Trend tab might reduce tab-only background churn without changing visible Historical Trend behavior.

Validation before revert:
- Parse marker before probe: `PARSE_OK_BRANCH_K_KA_YEAR_FILTER_LAZY_SYNC_03`.
- Tab-only probe label: `step21_branch_k_ka_year_filter_lazy_sync_tab_only`.
- Status: PASS=4.
- Output: `VP Clone/Logs/vp_perf_probe_single_action_latency_step21_branch_k_ka_year_filter_lazy_sync_tab_only_20260803T151248Z.csv`.
- Requested runtime log: `VP Clone/Logs/vp_runtime_perf_single_action_step21_branch_k_ka_year_filter_lazy_sync_tab_only_20260803T151248Z.jsonl`.
- Fallback inputs: `VP Clone/Logs/vp_runtime_perf_84f0ff5643c0526a968229d9afa78596.jsonl` and `VP Clone/Logs/vp_runtime_perf_proc_20260803T151252Z_22904.jsonl`.
- Total: 147289 ms.
- Visible-ready timings: Historical Trend 9514 ms; Heatmap 8875 ms; Map 13410 ms; Current 10959 ms.
- Runtime summary files:
	- `VP Clone/Logs/vp_perf_runtime_summary_step21_branch_k_ka_year_filter_lazy_sync_tab_only_20260803T151527Z_files.csv`
	- `VP Clone/Logs/vp_perf_runtime_summary_step21_branch_k_ka_year_filter_lazy_sync_tab_only_20260803T151527Z_events.csv`
	- `VP Clone/Logs/vp_perf_runtime_summary_step21_branch_k_ka_year_filter_lazy_sync_tab_only_20260803T151527Z_timed.csv`
	- `VP Clone/Logs/vp_perf_runtime_summary_step21_branch_k_ka_year_filter_lazy_sync_tab_only_20260803T151527Z_key_delta.csv`
	- `VP Clone/Logs/vp_perf_runtime_summary_step21_branch_k_ka_year_filter_lazy_sync_tab_only_20260803T151527Z_churn.csv`
	- `VP Clone/Logs/vp_perf_runtime_summary_step21_branch_k_ka_year_filter_lazy_sync_tab_only_20260803T151527Z_fanout.csv`
	- `VP Clone/Logs/vp_perf_runtime_summary_step21_branch_k_ka_year_filter_lazy_sync_tab_only_20260803T151527Z_partition.csv`
	- `VP Clone/Logs/vp_perf_runtime_summary_step21_branch_k_ka_year_filter_lazy_sync_tab_only_20260803T151527Z_memory.csv`
- Runtime records summarized: 335, down from 341 in the map bottom-panel suspend run and 348 in the display-month throttle run.
- Top churn after the attempted guard: summary table execution count 7; display-month mapping cache hit on Current count 5; filtered-data hierarchy filtering count 5; data-frequency UI rendered count 4; type-choice base-values cache hit count 4.

Decision:
- Reverted the year-filter lazy sync guard because it worsened total tab-only wall time versus both the map bottom-panel suspend run and the display-month throttle run, and it increased behavior risk around first Historical Trend sync/reapply for only a small runtime-record reduction.
- Parse marker after revert: `PARSE_OK_BRANCH_K_KA_YEAR_FILTER_LAZY_SYNC_REVERTED_03`.
- Rejected interpretation: `year_filter_sync_observer` churn is useful attribution but deferring its sync off-tab is not currently a safe speed lever. Do not retry this exact guard without a more direct Historical Trend behavior contract/probe.

### K-A Rejected Attempt: Summary Table `bindCache()` - 2026-08-03

Attempted implementation:
- File temporarily changed and then reverted: `VP Clone/Programs/app_source/server/04_comparison_plots.R`.
- Added `bindCache()` to `output$summary_table` using the neighboring comparison plot cache key plus table-specific decimal state.
- Local hypothesis: `summary_table_executed` was the top remaining active churn row, and the sibling comparison plot already used the same stable cache-key family. Binding the rendered summary table to the same data/projection inputs might avoid repeated table recomputation on tab-only transitions.

Failed parse attempt:
- The first patch accidentally matched an earlier `result })` shape inside `build_psd_map_analysis_info()` and inserted the cache block at the wrong location.
- Parse failed with `Programs/app_source/server/04_comparison_plots.R:92:6: unexpected ')'`.
- Repair: removed the misplaced block and reinserted the cache at the actual `output$summary_table` closing boundary.
- Parse marker after repair: `PARSE_OK_BRANCH_K_KA_SUMMARY_TABLE_BINDCACHE_04`.

Validation before revert:
- Tab-only probe label: `step21_branch_k_ka_summary_table_bindcache_tab_only`.
- Status: PASS=4.
- Output: `VP Clone/Logs/vp_perf_probe_single_action_latency_step21_branch_k_ka_summary_table_bindcache_tab_only_20260803T151753Z.csv`.
- Requested runtime log: `VP Clone/Logs/vp_runtime_perf_single_action_step21_branch_k_ka_summary_table_bindcache_tab_only_20260803T151753Z.jsonl`.
- Fallback inputs: `VP Clone/Logs/vp_runtime_perf_a7a0805b06ae31ca22e31578d3ad8305.jsonl` and `VP Clone/Logs/vp_runtime_perf_proc_20260803T151756Z_34968.jsonl`.
- Total: 135968 ms.
- Visible-ready timings: Historical Trend 9400 ms; Heatmap 10081 ms; Map 10864 ms; Current 8264 ms.
- Runtime summary files:
	- `VP Clone/Logs/vp_perf_runtime_summary_step21_branch_k_ka_summary_table_bindcache_tab_only_20260803T152015Z_files.csv`
	- `VP Clone/Logs/vp_perf_runtime_summary_step21_branch_k_ka_summary_table_bindcache_tab_only_20260803T152015Z_events.csv`
	- `VP Clone/Logs/vp_perf_runtime_summary_step21_branch_k_ka_summary_table_bindcache_tab_only_20260803T152015Z_timed.csv`
	- `VP Clone/Logs/vp_perf_runtime_summary_step21_branch_k_ka_summary_table_bindcache_tab_only_20260803T152015Z_key_delta.csv`
	- `VP Clone/Logs/vp_perf_runtime_summary_step21_branch_k_ka_summary_table_bindcache_tab_only_20260803T152015Z_churn.csv`
	- `VP Clone/Logs/vp_perf_runtime_summary_step21_branch_k_ka_summary_table_bindcache_tab_only_20260803T152015Z_fanout.csv`
	- `VP Clone/Logs/vp_perf_runtime_summary_step21_branch_k_ka_summary_table_bindcache_tab_only_20260803T152015Z_partition.csv`
	- `VP Clone/Logs/vp_perf_runtime_summary_step21_branch_k_ka_summary_table_bindcache_tab_only_20260803T152015Z_memory.csv`
- Runtime records summarized: 341.
- Top churn after the attempted cache: `summary_table_executed` count 7; `year_filter_sync_observer` count 7; display-month mapping cache hit on Current count 5; filtered-data hierarchy filtering count 5; data-frequency UI rendered count 4.

Decision:
- Reverted the summary-table `bindCache()` slice because it did not reduce `summary_table_executed` churn. The visible timings were mixed and the cache-key complexity was not justified without direct execution-count improvement.
- Parse marker after revert: `PARSE_OK_BRANCH_K_KA_SUMMARY_TABLE_BINDCACHE_REVERTED_04`.
- Rejected interpretation: the repeated summary-table execution is probably caused by invalidated upstream dependencies or output invalidation waves, not by a missing simple render-level cache on `output$summary_table`.

### K-R Granddaughter Ledger Creation - 2026-08-03

Created `VP Clone/Code Review/2026-08-03_vp_branch_k_rollup_ablation_experiment_plan.md` as the Branch K granddaughter source of truth for the rollup ablation experiment.

Scope delegated to K-R:
- Test whether embedded VP rollup rows materially inflate `vp_trade_monthly_pre.rds` file size, object size, artifact read time, partition-provider work, startup, hierarchy/filter lag, tab switching, or tab paint.
- Start with safe explicit-path artifact-load and provider probes.
- Treat app-level candidate timing as conditional on a currentity-safe setup that proves no fallback rebuild occurred.
- Keep native-only artifacts measurement-only and minimal-rollup artifacts performance-only unless a later redesign branch proves correctness.

Branch K parent contract:
- Do not duplicate the detailed K-R plan in this ledger.
- Roll accepted K-R findings, rejected hypotheses, exact probe outputs, and the recommended next architecture path back into this ledger at K-R closeout or a major accepted checkpoint.

### K-R Closeout Roll-Up - 2026-08-03

Detailed source of truth:
- `VP Clone/Code Review/2026-08-03_vp_branch_k_rollup_ablation_experiment_plan.md`.

Accepted findings rolled up from K-R:
- Rollup rows are about 70.5% of the canonical `vp_trade_monthly_pre.rds` rows: 1491692 of 2115868 rows.
- Reduced native/minimal-rollup artifacts are about 48.1 MB on disk and 252.5 MB in memory versus about 167.0 MB and 847.8 MB for the full artifact.
- Read-only reduced artifacts loaded in about 3.3 seconds versus about 10.4-12.1 seconds for canonical/full-copy artifacts.
- Fair default provider disk-hit scenarios improved to about 0.8 seconds for reduced artifacts versus about 1.8-2.1 seconds for full artifacts.
- App-level startup improvement repeated in K-R6: pair 1 improved from 85051 ms to 59815 ms, and pair 2 improved from 111341 ms to 74559 ms.

Rejected or bounded findings:
- Minimal-rollup is semantically invalid/performance-only. It cannot be shipped or used as correctness evidence.
- K-R6 did not prove a stable tab-only/tab-paint win: pair 1 candidate tab-only was slower, while pair 2 candidate tab-only was faster.
- Do not delete production rollups. The rollups preserve real all-selection semantics and need a safer relocation/lazy-loading architecture.
- Do not keep spending Branch K effort on small K-A fanout/output-settling slices as the main performance strategy. They were useful, but not big enough.

Architecture recommendation:
- Branch K recommends a separate aggressive lazy partition architecture plan after this closeout pause.
- The plan should be broader than a rollup sidecar alone: startup should read a small shell/metadata artifact, commodity-level native partitions should load on demand, and commodity/context rollup sidecars should load only when strict all-selection semantics require them.
- This direction attacks startup load, active working-set size, hierarchy/filter cascade breadth, provider metadata work, and reactive invalidation fanout.
- Required safety work includes a partition-bundle manifest/currentity contract, build-time partition/index outputs, deterministic commodity-switch sequencing, explicit global/all-commodity aggregate paths, and parity tests against the current full artifact for all-selection, mixed-volume, unit-value, summary, map, trend, and heatmap contexts.

## Bugs / Blockers / Failed Attempts / Rejected Approaches

- K-0.5 first combined patch attempt failed before applying because the patch repeated the same file header. Resolution: split `02_partner_and_notes.R` into a first slice and validate before editing adjacent files.
- K-0.5 parse-check command had three quoting/syntax failed attempts before the successful PowerShell-safe form. These failures were command construction errors, not R file parse failures.
- K-0.5 hierarchy-transition probe failed on source-switch stability and final missing-control checks even though it completed hierarchy stages. Treat the output as attribution evidence only, not as a PASS performance baseline.
- K-0.5 requested named runtime JSONL did not materialize. Resolution: summarized the latest matching fallback app runtime log, `VP Clone/Logs/vp_runtime_perf_214f7b647092b4d9f274385c30266702.jsonl`.
- K-0.5 runtime summarizer initially failed on the fallback app runtime log because missing elapsed columns produced zero-length vectors in `add_runtime_labels()`. Resolution: added `safe_numeric_column()` and reran summary successfully.
- K-A first resolved-context cache probe initially logged every cache hit, creating 902 `vp_resolved_hierarchy_context_cache_hit` events in one sidebar run. Resolution: throttled hit logging to per-key milestone counts and reran hierarchy/sidebar successfully.
- K-A display-month cache-hit throttle reduced logging churn but did not improve user-visible tab readiness. It should be treated as attribution cleanup, not as a speed win.
- K-A map bottom-panel hidden suspension reduced direct gated-skip churn and preserved tab-only Map readiness, but worsened total tab-only probe wall time. Treat it as provisional output-settling cleanup pending PSD/source-transition validation, not as a speed win.
- K-A year-filter lazy sync guard reduced runtime records slightly but worsened tab-only wall time and increased behavior risk; it was reverted after parse/probe/summary evidence.
- K-A summary-table `bindCache()` first patch landed at the wrong `result })` boundary and caused a parse failure; repaired placement parsed, but runtime validation did not reduce `summary_table_executed`, so the slice was reverted.
- K-R rejected native-only and minimal-rollup artifacts as production candidates. They were measurement tools only.
- K-R rejected claiming a tab-only win from rollup ablation because the two app-level pairs flipped direction.
- Outstanding Branch K conditional paths K-A1, K-B, K-C, and K-D are deferred rather than implemented in this branch. The provider/build portions should be reconsidered only inside a new lazy partition architecture plan.

## Final Summary

Branch K is closed and rolled up to the VP performance hotspot parent. K-0.5 confirmed that one hierarchy action fans out across repeated sibling consumers, and K-A delivered the first shared resolved hierarchy context cache.

The first K-A slice was behavior-safe across hierarchy/sidebar, canonical, and tab-only probes. It improved the sidebar and tab-only totals relative to K-0 baselines, but canonical regressed and tab switches remained well above the 1-3 second target, so it is a foundation slice rather than the usability win we need. Display-month hit logging and map bottom-panel hidden-suspension follow-ups cleaned up runtime attribution/output churn but did not produce a clean tab-readiness win.

K-R then tested whether embedded VP rollup rows and artifact size were a larger lever. The answer is yes for startup/artifact-load and not yet proven for tab-only responsiveness. Rollup rows are about 70.5% of the canonical artifact rows, and the performance-only minimal-rollup candidate repeatedly improved startup-to-ready by about 25.2 seconds and 36.8 seconds in two close-sequence pairs. The same candidate is not correctness-valid, and tab-only evidence flipped direction between pairs.

Branch K therefore closes with a redirect rather than another small patch. Outstanding conditional Branch K paths are deferred. The recommended next work is a new, separate aggressive lazy partition architecture plan: a small startup shell/metadata artifact, commodity-level native partitions loaded on demand, and commodity/context rollup sidecars loaded only when strict all-selection semantics require them. That plan should preserve current rollup semantics while reducing startup load, active working-set size, hierarchy/filter cascade breadth, and reactive invalidation fanout.