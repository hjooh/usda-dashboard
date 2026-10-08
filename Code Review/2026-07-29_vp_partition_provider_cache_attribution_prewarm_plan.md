# VP Partition-Provider Cache Attribution and Prewarm Plan

Date: 2026-07-29
Branch: main
Status: Complete. This daughter plan remains the source of truth for the completed VP partition-provider disk-cache attribution, metadata, and row-index partition-shape patch.

## Purpose

The parent VP performance hotspot recovery plan selected VP partition-provider disk-cache attribution and reuse/prewarm as the next measured Step 9 target. The immediate purpose of this daughter plan is to reduce remaining hierarchy-transition runtime cost from partition-provider disk-cache reads, but only after improving attribution enough to tie each provider slice to caller purpose, request kind, resolved hierarchy context, provider mode, cache state, and runtime evidence.

The implementation posture is attribution first, then the smallest measured provider/cache or partition-shape change supported by that attribution. Metadata/index work was correct but only a limited performance win, so the active implementation branch is Option 3A Provider v3 row-index serialization: store compact row-index payloads on disk, reconstruct ordinary data frames from the resident VP monthly artifact for existing consumers, and keep metadata-only behavior from the v2 branch. This is not a startup rewrite, app-mount rewrite, lazy-tab tranche, broad prewarm tranche, lazy-row-object tranche, or UI loading-polish tranche.

## Scope

Included:
- Create this daughter source-of-truth ledger and keep it updated before every implementation tranche transition.
- Amend the parent plan to delegate parent Step 9 here before implementation code edits.
- Add or improve provider-slice attribution for resolved hierarchy context and caller purpose where practical.
- Create or recover a focused direct non-Shiny partition-provider probe before optimization timing comparisons.
- Add deterministic provider cache-state control for probe scenarios.
- Preserve direct-filter fallback, provider disable behavior, manifest integrity checks, and cache-state labeling.
- Use the runtime summarizer to compare provider modes, provider elapsed time, hierarchy-filter timed totals, churn counters, and key deltas.
- Run one bounded hierarchy Shiny probe only as app-path integration confirmation after direct provider evidence exists.
- Implement bounded reuse, prewarm, request de-duplication, call-site context reuse, or partition serialization A/B work only after attribution identifies the disk-hit slices and likely user-visible benefit.
- Implement Option 3A row-index partition serialization only after recording the metadata branch as correct but insufficient and preserving direct-probe-first validation.
- Prove canonical resident source eligibility before row-index reuse. If that cannot be done reliably, keep row-index mode probe-only and do not wire it into app-path provider retrieval.
- Measure v2 full-frame partition read time, v3 row-index payload read time, and reconstruction time separately for the five Step 6 disk-hit slices before Shiny validation.
- Close this daughter plan with implementation results, validation evidence, residual risks, and parent-plan handoff notes.

Excluded:
- Loading polish, loading spinners, progress copy, cosmetic waiting states, or any UI latency-masking work.
- Broad VP artifact format rewrites as the first response.
- Lazy row objects, manifest-inlined indices, idle prewarm, broad prewarm, cache eviction, UI debounce, and loading polish in the first Option 3A tranche.
- Startup/app-mount tuning unless Step 9 evidence conclusively falsifies the provider/cache target and the parent plan is amended.
- Lazy tab or MYCT optimization work.
- Non-VP tuning.
- Full-path repeated shinytest smoke as the primary performance gate.
- Creating a paired results markdown file unless explicitly requested.

## Parent Plan Linkage

Parent plan: `VP Clone/Code Review/2026-07-29_vp_performance_hotspot_recovery_plan.md`.

This daughter/progeny plan owns detailed implementation notes for parent Step 9, "Optimize second measured hotspot/cache/provider tranche." The parent remains the broad performance recovery ledger. During this patch, the parent should contain only the delegation note, high-level status, and closeout summary; detailed technical decisions, failed attempts, validation commands, probe outputs, and runtime evidence belong here.

At closeout:
- Complete this daughter `## Summary` section in plain language.
- Update the parent Step Ledger with the Step 9 outcome.
- Add parent tranche notes with output paths, validation markers, timing/churn/partition deltas, residual risks, blocker investigations, and the next recommended parent-plan target.
- Recenter future work on the parent plan.

## Source-Of-Truth Ledger Contract

- This file is the active source of truth for the VP partition-provider disk-cache attribution and reuse/prewarm patch.
- Update this file after every step or tranche before moving to the next tranche.
- Record files touched, commands/probes, benchmark labels, cache-state labels, runtime log paths, PERF summaries, partition-mode deltas, churn deltas, bugs, blockers, failed attempts, rejected approaches, and decision gates.
- Keep parent-plan updates limited to delegation and closeout while this daughter plan is active.
- Preserve enough detail that a future coder can resume without replaying chat history.
- At completion, provide a short chat summary and complete the final `## Summary` section in this file.

## Baseline Evidence

Step 9 target selection came from the Step 8 post-mixed-context-cache hierarchy evidence:
- Hierarchy probe label: `step8_post_mixed_context_cache_hierarchy`.
- Probe CSV: `VP Clone/Logs/vp_perf_probe_hierarchy_transition_step8_post_mixed_context_cache_hierarchy_20260729T184433Z.csv`.
- Runtime summary label: `step8_post_mixed_context_cache_hierarchy`.
- Runtime summary files: `VP Clone/Logs/vp_perf_runtime_summary_step8_post_mixed_context_cache_hierarchy_20260729T184738Z_*.csv`.
- Probe status: PASS.
- Total probe: 159.596 seconds.
- Hierarchy stage: 68.338 seconds.
- `filter_vp_rows_for_resolved_hierarchy()`: 71 calls / 8.7033 seconds.
- Provider memory cache: 66 calls / 0.0859 seconds total.
- Provider disk cache: 5 calls / 5.6491 seconds total.
- Remaining nearby churn: `display_month_mapping` 24 calls, `type_choice_base_values` 15 VP calls plus one unknown/unknown row, `filtered_data` 9 calls, and `comparison_commodity_choices` 4 calls.

Baseline caveats:
- Current provider disk-cache records expose provider mode, row count, and partition file, but not caller purpose, active tab, request kind, action/session context, or full resolved hierarchy context.
- The requested Step 8 runtime JSONL path did not materialize. Exact fallback process/session logs were recorded and summarized instead.
- Step 8 partition evidence observed `memory_cache` and `disk_cache`, but the implementation can also emit `materialized` and `direct_fallback`; this daughter plan must preserve visibility into all modes.
- The current evidence is strong enough to choose the target, but not enough to safely choose between provider prewarm, request de-duplication, call-site context reuse, or partition serialization changes.

## Technical Read

Provider implementation surface in `VP Clone/Programs/app_source/global.R`:
- `vp_partition_provider_enabled()` controls provider enablement.
- `vp_partition_provider_dir()` and `vp_partition_manifest_path()` define the partition file and manifest locations.
- `vp_partition_file_name()` hashes trade flow and hierarchy filters into short Windows-safe filenames.
- `vp_partition_get_hierarchy_slice()` retrieves provider slices, records `vp_partition_provider_slice()` PERF events, and currently logs provider mode and partition metadata.
- `vp_partition_provider_filter_rows()` calls `vp_partition_get_hierarchy_slice()` and then applies commodity name/detail filters.
- The provider already uses process-level `vp_partition_cache_env`; global provider cache state is part of the current design.

Provider call site in `VP Clone/Programs/app_source/server/02_partner_and_notes.R`:
- `filter_vp_rows_for_resolved_hierarchy()` calls `vp_partition_provider_filter_rows()` when `resolved$use_partition_provider` is true.
- The call site already knows the caller context needed for attribution: `filter_purpose`, active tab, source, trade flow, group/subgroup/market segment filters, resolution mode, strict/sparse flags, path name, input rows, and output rows.
- The current technical gap is that these caller/context fields do not flow into `vp_partition_provider_slice()` timing records.

Function-signature recommendation:
- Implement attribution through explicit signature/context plumbing, not indirect global state.
- Pass a provider context list or named context arguments from `filter_vp_rows_for_resolved_hierarchy()` into `vp_partition_provider_filter_rows()`.
- Pass the same context into `vp_partition_get_hierarchy_slice()`.
- Include safe scalar context fields in all practical `vp_partition_provider_slice()` log branches: `memory_cache`, `disk_cache`, `materialized`, and `direct_fallback`.
- Recommended context fields: `filter_purpose`, `active_tab`, `source`, `request_kind`, `trade_flow`, `group_filter`, `subgroup_filter`, `market_segment_filter`, `resolution_mode`, `strict_rollup_context`, `sparse_selection`, `path_name`, and optional action/session identifiers if already available.
- Keep added context logging low-overhead and scalar; do not log large vectors, data frames, row payloads, or complete choice lists.

Selected Step 7 implementation branch:
- Primary branch: Option 1, lightweight provider metadata/index for VP partition slices.
- Fallback branch: Option 3, measured partition/data-shape change only if metadata/index cannot answer hot questions exactly or does not reduce app-runtime cold-slice disk cost.
- The metadata/index branch must be implemented and validated before any partition/data-shape fallback code edits.
- The two prior quick Step 7 branches remain rejected and reverted: direct mixed-volume boolean scan by itself, and in-memory `type_choice_base_values` rewrite.

Metadata contract for Option 1:
- Metadata key must remain provider-slice granularity: `trade_flow`, `group_filter`, `subgroup_filter`, and `market_segment_filter`, using the same provider key path as `vp_partition_cache_key()` / `vp_partition_entry_key()`.
- Initial metadata fields should include `metadata_schema_version`, `row_count`, `col_count`, `unique_volume_families`, `volume_family`, `has_mixed_volume_family`, and compact commodity/detail sub-indexes where needed for correctness.
- `unique_volume_families` is the canonical correctness field. `volume_family` and `has_mixed_volume_family` are derived convenience fields, not the only source of truth.
- Recommended sub-index granularity: per `CommodityName`, and optionally per `CommodityName` plus `commodity`, with `row_count`, `unique_volume_families`, `volume_family`, `has_mixed_volume_family`, and available details.
- Country/custom-country must not be added to the provider partition key. Country may be represented only as optional compact metadata if direct equivalence probes prove it is necessary, correct, and small.
- Metadata states must be explicit: `metadata_current`, `metadata_missing`, `metadata_stale`, `metadata_insufficient`, `metadata_unavailable`, and `metadata_not_definitive`.
- Definitive metadata rule: if the relevant slice or sub-index has exactly one `unique_volume_families` value, metadata may answer family questions; if it has multiple values and no narrower sub-index applies, metadata must return insufficient/not-definitive and fall back to the existing row path.
- Metadata helpers must use resolved provider filters, not raw UI tokens, and must return unavailable/insufficient if required columns such as `volume_unit_family`, `source_volume_unit`, `CommodityName`, or `commodity` are absent.

Provider metadata helper recommendation:
- Add a provider helper in `VP Clone/Programs/app_source/global.R` that reads one manifest metadata entry without reading the partition RDS.
- Suggested shape: `vp_partition_get_hierarchy_metadata(trade_flow, group_filter, subgroup_filter, market_segment_filter, provider_context = NULL)`.
- The helper should return a structured list with `ok`, `reason`, `metadata_state`, `metadata`, `entry_key`, `partition_file`, and enough context fields to support runtime attribution.
- The helper must log a distinct PERF event such as `vp_partition_provider_metadata()` with request kind, filter purpose, provider context, manifest reason, metadata state, and metadata sufficiency.
- The metadata helper must never silently fall back to reading full rows. If metadata is insufficient, missing, stale, not definitive, or unavailable, the caller must explicitly fall back to the existing row path so runtime logs stay intelligible.

## Guardrails

Correctness and fallback guardrails:
- Preserve direct-filter fallback behavior.
- Preserve provider disable behavior.
- Preserve manifest compatibility/integrity checks and stale/missing manifest handling.
- Do not weaken partition-entry validation or silently trust stale partition files.
- Keep changes VP-scoped.
- Preserve current user-visible VP behavior unless a deliberate measured behavior change is recorded here first.

Provider granularity guardrails:
- Provider reuse/prewarm must respect provider-slice granularity: trade flow plus resolved hierarchy filters.
- Do not mix country/custom-country, commodity/detail, metric, or quantity-unit state into the provider partition key unless the provider contract is deliberately redesigned and validated.
- Consumer-level filters may still run after provider slice retrieval. Attribution should decide whether the fix belongs inside provider reuse/prewarm or in server-side shared context routing.
- If disk reads concentrate in `display_month_mapping`, `type_choice_base_values`, or `filtered_data`, the fix may belong in `02_partner_and_notes.R` context reuse rather than global provider prewarm.

Provider cache-state guardrails:
- The provider already uses process-level `vp_partition_cache_env`; do not pretend global cache state is absent.
- Avoid stale-cache behavior, cross-session pollution, and unbounded memory growth.
- Do not add a cache eviction scheme unless probe output shows meaningful process-memory growth.
- If memory growth appears material, consider a bounded cache policy only as a separate measured follow-up inside this daughter plan.

Metadata/cache guardrails:
- Versioned metadata population is required. Materialization-only metadata is not enough for existing partition files unless the branch forces a versioned rebuild or runs a controlled metadata backfill.
- Preferred metadata population strategy: bump `vp_partition_provider_version` or manifest `schema_version` for the metadata branch so old entries cannot be mistaken for metadata-capable entries.
- Alternative metadata population strategy, only if the version bump is rejected: add a direct backfill probe/tool that reads existing partitions once, computes metadata, validates parity, and rewrites the manifest with a new metadata schema marker.
- Add a write-path verification helper or direct probe assertion equivalent to `vp_partition_verify_manifest_metadata(partition_rows, manifest_entry)` so generated metadata cannot drift silently from partition rows.
- Metadata-only and row-returning context entries must not share the same `vp_trade_context_cache` key unless the cached object contains real rows and metadata. Include request shape (`metadata_only` / `require_rows`) in the cache key or maintain separate metadata cache storage.
- Default caller behavior must remain row-returning. Existing callers should receive real rows unless they explicitly opt into metadata-only behavior.
- Add atomic partition and manifest writes for Windows/OneDrive safety: write to a temporary file in the same directory, then rename into place.
- Add a lazy process-level manifest cache with mtime/signature/version invalidation, not startup preloading. Metadata lookup may call the manifest many times; repeated manifest `readRDS()` calls should not become a new small I/O hotspot.
- Keep metadata build cost visible. Direct probes should record manifest size, metadata entry size where feasible, metadata lookup time, and full-row read time.
- Provider-level request de-duplication may be considered only as provider/cache plumbing if repeated identical user-hit metadata/row requests occur in one reactive burst. Do not implement UI debounce or visible timing changes in this branch.

Prewarm guardrails:
- Do not implement prewarm until attribution identifies the disk-hit slices and likely user-visible benefit.
- If prewarm is added, provider logs must distinguish `user_hit`, `prewarm`, and `probe` request kinds before judging success.
- Prewarm must not synchronously block the same hierarchy mutation that triggers it. A synchronous prewarm can simply move disk latency earlier in the same user action.
- Prewarm candidates must be derived from already-valid hierarchy choices/slices, not guessed strings.
- Start with a tiny bounded set of predictable slices if next-depth prewarm is tested.
- Prove prewarm reduces user-hit latency without increasing total churn or app startup work.

Partition serialization guardrails:
- RDS decompression may contribute to Windows disk-cache latency.
- Test `saveRDS(..., compress = FALSE)` only as a focused A/B branch after attribution/probe setup.
- Treat compression changes as a partition-cache format decision, not part of the first attribution patch.
- Preserve manifest compatibility and stale/missing manifest handling if partition serialization is changed.

Option 3 fallback guardrails:
- Non-definitive metadata should first fall back to the existing row path for correctness. Escalate to Option 3 only if that fallback path remains frequent/expensive enough that Option 1 does not reduce cold-slice disk time in app runtime.
- Fallback trigger: metadata cannot answer hot questions exactly without becoming too large/complex, or the metadata branch does not reduce cold-slice disk time in app runtime.
- Fallback variant A: row-index serialization, storing integer row indices into resident `rice_data_vp_trade_monthly` instead of full data frames. This requires strict source-signature and row-count immutability validation.
- Active fallback variant A: row-index serialization, storing structured integer row-index payloads for canonical resident `rice_data_vp_trade_monthly` instead of full data frames. This requires strict source identity, source signature, source row count, stable row-order eligibility, index bounds, file-size, row-count, and metadata validation.
- Fallback variant B: column-subset partitions for common provider consumers, with full-row fallback for uncommon columns if necessary.
- Fallback variant C: commodity-level partition granularity, adding `CommodityName` to the key only if metadata/sub-indexes cannot handle commodity-specific correctness and file-count growth is acceptable.
- Fallback variant D: summary/header partitions beside full partitions if manifest size becomes unwieldy.
- Avoid repeating compression-only fallback unless new evidence contradicts the Step 7 A/B result.
- Any Option 3 fallback must increment `vp_partition_provider_version`, manifest schema, or artifact builder version to avoid stale reuse, and must prove direct equivalence to `vp_partition_filter_direct()` for every tested slice.
- Row-index payloads must preserve the public row-returning provider contract. Existing callers still receive data frames; lazy row objects are out of scope for this tranche.
- Do not rely on manifest source signature alone. It proves the persisted source artifact, not that an arbitrary `vp_rows` argument has the same row order.
- Add a source-mismatch/stale-index direct probe case that intentionally changes row order or row count and verifies Provider v3 refuses row-index reuse instead of returning wrong rows.
- Do not hard-code a heavy-slice threshold before measurement. Large slices may be the best disk-saving candidates even though reconstruction allocation can be expensive.
- Consider manifest-inlined indices only as a measured follow-up for tiny slices after base v3 works; do not put indices broadly in the manifest in the first tranche.

UI guardrail:
- No loading polish belongs in this plan.
- Do not add visible UI elements, copy, spinners, progress indicators, or loading states as part of this daughter patch.
- If prewarm changes app behavior timing, verify manually that ordinary source/trade/hierarchy changes still render expected controls and outputs.

## Measurement Model and Cache-State Labels

Every provider probe, hierarchy probe, and benchmark row must identify cache state:

- `cold_artifact`: fresh R session and no warmed partition cache for the target path.
- `warm_partition_disk`: partition files exist but the process memory cache is empty.
- `warm_session`: same process/session and provider memory cache already hit.
- `unknown_cache_state`: only allowed for legacy baseline rows or explicitly documented harness/cache-state uncertainty where the evidence is used for target selection rather than final before/after proof.

Rules:
- Record whether partition files were preserved, cleared, created, or stale/corrupt by design.
- Record whether process memory cache was cleared or preserved.
- Do not blend cold, warm-partition-disk, and warm-session timings into one median without labels.
- Prefer separate output files or scenario labels for distinct cache states.
- Record generated artifact/cache state before performance comparisons.
- Record exact runtime files actually summarized, whether they are requested paths or fallback process/session paths.

## Smoke and Harness Strategy

All probes and harnesses must follow the parent plan and completed daughter-plan conventions. Do not waste time tuning brittle full-path or idle-dependent Shiny probes for checks that can be proven through direct provider/artifact contracts.

Primary layer: focused direct non-Shiny provider probe.
- Because no `VP Clone/System/Testing/vp_perf_probe*partition*` file currently exists, this daughter plan includes creating or recovering one before optimization comparisons.
- Proposed file: `VP Clone/System/Testing/vp_perf_probe_partition_provider.R`.
- It should follow the style of existing probes such as `vp_perf_probe_vp_filters.R`, `vp_perf_probe_artifact_load.R`, and `vp_perf_probe_vp_mixed_quantity_sanity.R`.
- It must emit deterministic CSV output.
- It must emit grepable parse and success markers.
- It must label cache state for every row.
- It must record whether partition files were preserved, cleared, created, or intentionally stale.
- It must record whether process memory cache was cleared or preserved.
- It must be able to exercise at least `warm_partition_disk` and `warm_session` behavior.
- Where feasible, it should also exercise missing/stale partition scenarios as separate rows or documented follow-up cases.

Required direct provider probe output fields:
- `label`.
- `timestamp`.
- `cache_state`.
- `request_kind`.
- `provider_mode`.
- `fallback_reason`.
- `manifest_reason`.
- `elapsed_seconds`.
- `rows`.
- `partition_file`.
- `trade_flow`.
- `group_filter`.
- `subgroup_filter`.
- `market_segment_filter`.
- `commodity_name`.
- `commodity_detail`.
- `filter_purpose`.
- `active_tab`.
- `source`.
- `resolution_mode`.
- `strict_rollup_context`.
- `sparse_selection`.
- `path_name`.
- `partition_files_state`.
- `memory_cache_state`.
- `status`.

Recommended provider probe output fields where cheap:
- Provider cache entry count.
- Approximate total cached rows.
- Object size estimate.
- Partition file size.
- Manifest status.
- R process id.
- Runtime log file path or exact fallback runtime log paths.

Runtime log and summarizer requirements:
- Provider attribution must preserve and summarize all provider modes: `memory_cache`, `disk_cache`, `materialized`, and `direct_fallback`.
- Preserve `fallback_reason` and `manifest_reason` in provider records and summaries.
- Runtime summaries should compare partition modes, provider elapsed time, hierarchy-filter elapsed totals, churn counters, and key deltas.
- Known issue: requested `VP_PERF_RUNTIME_LOG_FILE` may not materialize. If so, exact fallback process/session logs must be recorded and summarized.
- Where practical, automate fallback runtime-log discovery in probes or summarizer scripts so validation does not require manual assembly of process/session JSONL paths.

Direct metadata equivalence probe requirements:
- Add a direct metadata equivalence mode to `VP Clone/System/Testing/vp_perf_probe_partition_provider.R`, or create `VP Clone/System/Testing/vp_perf_probe_partition_metadata.R` if separation is clearer.
- The probe must compare metadata answers from the manifest against answers computed from full partition rows for the five Step 6 disk-hit slices.
- Required checks: row counts match; `unique_volume_families`, `volume_family`, and `has_mixed_volume_family` match full rows; commodity/detail sub-index answers match full row filtering for the known Step 6 contexts; metadata-definitive and metadata-insufficient decisions match the intended fallback rules.
- Required fields: `label`, `cache_state`, `request_kind`, `entry_key`, `partition_file`, `metadata_state`, `metadata_definitive`, `elapsed_ms_metadata`, `elapsed_ms_full_rows`, `rows`, `commodity_name`, `commodity_detail`, `unique_volume_families_metadata`, `unique_volume_families_full`, `volume_family_metadata`, `volume_family_full`, `has_mixed_metadata`, `has_mixed_full`, `manifest_size_bytes`, `metadata_size_bytes`, `file_size_bytes`, and `status`.
- Add heavy-slice detection to probes and fallback criteria. Record `row_count`, `file_size_bytes`, metadata size, and full read time; treat very large slices such as the 267,151-row export rollup as Option 3 candidates if metadata cannot avoid repeated full reads.

Secondary layer: one-shot segmented Shiny integration probe.
- Use `VP Clone/System/Testing/vp_perf_probe_hierarchy_transition.R` for app-path confirmation after direct provider evidence exists.
- Keep it one-shot and segmented.
- Use bounded staged waits, explicit visible/control/output checks, stage markers, one raw CSV row, runtime PERF logs, and partial evidence on timeout.
- Do not use full-path repeated smoke as the primary gate.

## Step Ledger

| Step | Phase | Work | Status | Evidence / Files | Gate / Next Action |
|---|---|---|---|---|---|
| 1 | A | Create daughter source-of-truth plan | Complete | Added this file before Step 9 implementation code edits. | Parent plan must delegate Step 9 here before implementation begins. |
| 2 | A | Amend parent plan for Step 9 delegation | Complete | Parent Step 9 is `Delegated / in progress`, references this daughter plan, and says detailed Step 9 implementation should continue here. Parent Tranche I records the handoff and guardrails. | Keep parent updates limited to closeout unless Step 9 scope changes. |
| 3 | B | Define provider attribution fields and signature path | Complete (design) | Verified current code path: `filter_vp_rows_for_resolved_hierarchy()` -> `vp_partition_provider_filter_rows()` -> `vp_partition_get_hierarchy_slice()`. Provider logs currently record mode/rows/partition metadata, while the server call site already has `filter_purpose`, source, active tab, resolved hierarchy filters, resolution mode, strict/sparse flags, path name, and commodity filters. | Next step is Step 4: create or recover the focused direct provider probe before provider/cache optimization. No reuse/prewarm implementation until baseline attribution runs. |
| 4 | C | Create or recover focused direct provider probe | Complete | Added `VP Clone/System/Testing/vp_perf_probe_partition_provider.R`. Parse marker: `PARSE_OK_VP_PARTITION_PROVIDER_PROBE`. Initial harness validation CSV: `VP Clone/Logs/vp_perf_probe_partition_provider_step4_partition_provider_probe_initial_20260729T191834Z.csv`. | Probe exists, parses, and produces deterministic disk-cache and memory-cache rows. |
| 5 | C | Run baseline provider attribution | Complete (initial direct baseline) | Baseline CSV: `VP Clone/Logs/vp_perf_probe_partition_provider_step5_baseline_provider_attribution_20260729T191858Z.csv`. Default provider slice: `import / Dry pulses / Dried beans / Dried / Bambara beans / All`; run 1 `warm_partition_disk` = `disk_cache` 175ms / 211 rows; run 2 `warm_session` = `memory_cache` 2ms / 211 rows. | Direct provider mechanics are validated. Real app-caller attribution still requires provider context plumbing before optimization choice. |
| 6 | D | Add provider caller-context attribution plumbing | Complete | Edited `VP Clone/Programs/app_source/global.R` and `VP Clone/Programs/app_source/server/02_partner_and_notes.R`. Added scalar `provider_context` plumbing from `filter_vp_rows_for_resolved_hierarchy()` into `vp_partition_provider_filter_rows()` and `vp_partition_get_hierarchy_slice()`. Parse marker: `PARSE_OK_PROVIDER_CONTEXT_PLUMBING`. Hierarchy probe `step6_provider_context_plumbing_hierarchy` passed; exact fallback runtime logs summarized. | Context is now present in raw provider runtime records. Step 7 should use this evidence to choose the smallest optimization branch; current evidence points to `mixed_volume_family_check` as the disk-hit caller. |
| 7 | D/E | Implement smallest supported provider/cache or call-site reuse change | Complete | Candidate actions must be selected from Step 6 attributed evidence. Tested and rejected a direct mixed-volume boolean predicate branch: it avoided `mixed_volume_family_check` provider reads, but disk reads shifted to `type_choice_base_values` / `quantity_units_context` and the direct scans added 3.7685s. Tested and rejected an in-memory `type_choice_base_values` branch because the hierarchy probe failed to resolve the final segment. RDS compression A/B also did not justify a full-data-frame format change. Option 1 lightweight provider metadata/index was implemented and validated as correct, but the passing app run still had five cold provider disk reads totaling 5.1963s. Option 3A Provider v3 row-index serialization is implemented in `global.R` and the direct probe, with canonical-source eligibility, split read/reconstruction timing, row-content parity, metadata parity, selected metadata parity, source-mismatch refusal, and source-identity fast path. | Complete. Recenter on the parent plan for the next measured hotspot. |
| 8 | E | Rerun focused provider probe and bounded hierarchy probe | Complete | Direct selected-parity probe passed: `VP Clone/Logs/vp_perf_probe_partition_provider_step7_metadata_step6_disk_hit_slices_signature_aligned_20260729T201910Z.csv`. Passing metadata hierarchy probe: `VP Clone/Logs/vp_perf_probe_hierarchy_transition_step7_metadata_signature_aligned_hierarchy_20260729T201950Z.csv`. Option 3A materialization/direct parity probe passed: `VP Clone/Logs/vp_perf_probe_partition_provider_step7_option3_row_index_step6_slices_20260729T204819Z.csv`. Option 3A disk-cache direct probe passed: `VP Clone/Logs/vp_perf_probe_partition_provider_step7_option3_row_index_step6_slices_disk_20260729T204922Z.csv`. Clean Option 3A app-path confirmation: `VP Clone/Logs/vp_perf_probe_hierarchy_transition_step7_option3_row_index_fast_source_confirm_20260729T210115Z.csv`; exact fallback runtime logs summarized in `VP Clone/Logs/vp_perf_runtime_summary_step7_option3_row_index_fast_source_confirm_exact_20260729T210410Z_*.csv`. | Complete. |
| 9 | F | Close daughter and update parent | Complete in daughter; parent update pending in parent file | Daughter Summary completed below with output paths, validation markers, performance deltas, residual risks, and next target recommendation. | Update parent Step 9 and tranche notes, then recenter future work on parent plan. |

## Phase Plan

Phase A: Handoff setup
- Create this daughter plan.
- Amend the parent plan to delegate Step 9 here.
- Validate markdown handoff with `git diff --check`.

Phase B: Attribution design
- Read the provider implementation and call-site integration.
- Define context fields to pass through provider signatures.
- Preserve low-overhead scalar logging.
- Do not begin reuse/prewarm work before attribution shape is documented.

Phase C: Probe/harness creation and baseline attribution
- Create or recover `vp_perf_probe_partition_provider.R`.
- Build deterministic cache-state controls for warm-partition-disk and warm-session scenarios.
- Run direct provider baseline attribution.
- Summarize exact runtime logs with the existing summarizer.

Phase D: Measured optimization
- Add provider caller-context attribution plumbing first so app runtime logs can tie provider slices to caller purpose and resolved hierarchy context.
- Selected branch: Option 1 lightweight provider metadata/index for metadata-only context questions.
- Fallback branch: Option 3 partition/data-shape change, only after metadata/index is tested or proven insufficient.
- Add provider metadata entry construction, metadata-only helper access, direct metadata equivalence probe coverage, and metadata-only consumer wiring only where row payloads are not required.
- Active Option 3A branch: bump provider/manifest storage compatibility to v3, write structured row-index payloads instead of full data-frame partitions, reconstruct ordinary data frames for existing consumers, and preserve v2 metadata-only semantics.
- Add a canonical-source eligibility helper. If source identity, source signature, row count, or stable row-order eligibility cannot be proven, row-index reuse must refuse and fall back rather than guessing.
- Add direct probe fields for v2 full-frame read time, v3 payload read time, reconstruction time, source eligibility, payload schema/storage mode, index count, max index, and source-mismatch refusal.
- Preserve default row-returning behavior and cache-key separation for metadata-only versus row-returning requests.
- Avoid broad prewarm, idle prewarm, eviction, lazy row objects, manifest-inlined indices, compression-only fallback, startup, app-mount, choice-list rewrites, UI debounce, or UI changes unless evidence and this plan are amended first.

Phase E: Focused validation
- Parse touched R files.
- Rerun focused provider probe with comparable labels and cache-state handling.
- Rerun bounded hierarchy transition probe for integration confirmation.
- Summarize runtime logs and compare partition/timed/churn/key-delta outputs.

Phase F: Closeout
- Complete this plan's Summary.
- Update parent Step 9 and Tranche notes.
- Recenter future performance work on the parent plan.

## Verification and Validation Targets

Markdown validation:
- `git diff --check -- "VP Clone/Code Review/2026-07-29_vp_performance_hotspot_recovery_plan.md" "VP Clone/Code Review/2026-07-29_vp_partition_provider_cache_attribution_prewarm_plan.md"`.

Parse checks:
- Use explicit Rscript path on this workstation: `C:\Program Files\R\R-4.5.1\bin\Rscript.exe`.
- Use grepable `PARSE_OK` markers.
- For quick parse probes, wrap `parse(file=...)` in `invisible(...)` to avoid huge expression dumps.
- Prefer short temporary R scripts over fragile PowerShell inline `-e` strings when commands contain `$`.

Direct provider probe validation:
- Parse marker for `vp_perf_probe_partition_provider.R`.
- Baseline CSV with controlled cache state.
- Post-change CSV with the same scenario labels and cache-state handling.
- Explicit output paths recorded in this daughter plan.
- Metadata equivalence CSV before app wiring, including metadata/full-row parity, metadata state, definitive/insufficient decisions, manifest size, metadata size, heavy-slice fields, and full read versus metadata lookup timings.
- Row-index provider CSV before Shiny wiring, including parity for all five Step 6 slices, source eligibility, stale row-order or changed-row-count refusal, v2 full-frame read timing, v3 payload read timing, reconstruction timing, payload/index fields, metadata parity, selected metadata parity, and heavy-slice fields.

Runtime summarizer validation:
- Use `VP Clone/System/Testing/vp_perf_summarize_runtime_logs.R`.
- Summarize exact runtime files actually written, whether requested path or fallback path.
- Compare partition, timed, churn, and key-delta outputs.

Shiny integration validation:
- Use `VP Clone/System/Testing/vp_perf_probe_hierarchy_transition.R` after direct provider evidence exists.
- Do not retry repeatedly through idle-dependent failures unless the failure itself is the app-path behavior under investigation.

Manual sanity:
- No loading polish in this plan.
- If prewarm changes app behavior timing, verify manually that ordinary source/trade/hierarchy changes still render expected controls and outputs.
- Do not add visible UI elements, copy, spinners, or loading states as part of this daughter patch.

## Bugs, Blockers, Failed Attempts, Rejected Approaches

Known blockers and risks:
- Missing provider probe: no `VP Clone/System/Testing/vp_perf_probe*partition*` file currently exists, despite the parent plan listing a partition-provider probe as part of the harness ladder.
- Attribution gap: current provider PERF records lack caller purpose, active tab, request kind, action/session context, and full resolved hierarchy context.
- Runtime-log routing caveat: requested `VP_PERF_RUNTIME_LOG_FILE` may not materialize; exact fallback process/session logs must be recorded and summarized when that happens.
- Shiny harness risk: `shinytest2` idle waits/value reads can stall in this workspace even when controls/outputs mutate successfully.
- Cache-state risk: provider comparisons are invalid if warm-partition-disk and warm-session rows are blended or mislabeled.
- Prewarm risk: synchronous prewarm can move latency earlier in the same user action rather than reducing perceived latency.
- Memory risk: broad prewarm can grow process-level `vp_partition_cache_env`; measure before adding eviction or broad warming.
- Windows/R risk: PowerShell inline `Rscript -e` commands with `$` are fragile; prefer short temporary R scripts for complex validation commands.
- Metadata granularity risk: slice-level metadata may be too coarse for commodity/detail/country-specific answers. Metadata must answer only when definitive at the relevant granularity or fall back to rows.
- Cache ghost risk: metadata-only entries can poison row-returning cache entries if request shape is not separated in cache keys or storage.
- Manifest population risk: existing partitions will not have metadata unless the branch uses versioned rebuild/materialization or a controlled backfill.
- Windows/OneDrive file-locking risk: direct partition/manifest writes can fail or leave partial RDS files without atomic write behavior.
- Runtime-log validation risk: fallback process/session log discovery remains partly manual unless probes or summarizer scripts automate it.
- Heavy-slice risk: very large slices, such as the 267,151-row export rollup, may remain expensive if metadata cannot avoid repeated full reads.

Rejected as first response:
- Loading polish, spinners, progress copy, or UI waiting-state work.
- Broad artifact-format rewrite.
- Startup/app-mount tuning without stronger attribution.
- Lazy tab/MYCT work inside this daughter plan.
- Full-path repeated smoke as the primary gate.
- Broad provider prewarm before direct attribution.
- Cache eviction before memory evidence.
- RDS compression changes before a focused A/B branch.
- Global-state attribution hacks instead of explicit provider signature/context plumbing.
- Direct mixed-volume boolean scan as the Step 7 optimization by itself. Validation showed it shifted first disk reads to later consumers and added direct-scan time rather than eliminating the cold-slice cost.
- In-memory `type_choice_base_values` rewrite as a quick Step 7 branch. It looked locally plausible because type choice only needs commodity/detail values, but the app-path hierarchy probe failed to settle on the final segment, so the branch was reverted rather than carried forward.

## Tranche Execution Notes

- 2026-07-29 Tranche A (daughter plan creation):
  - Created this daughter source-of-truth plan for parent Step 9 before Step 9 implementation code edits.
  - Incorporated the user-approved target selection: VP partition-provider disk-cache attribution and reuse/prewarm around hierarchy transitions.
  - Folded in technical, function-oriented, blocker-oriented, probe, cache-safety, Windows/R, and validation recommendations from the pre-handoff audit.
  - Explicitly excluded loading polish and UI waiting-state work from this daughter plan.
  - Recorded the first implementation gate: create or recover a focused direct non-Shiny provider probe with deterministic cache-state control before optimizing provider/cache behavior.
  - No implementation code edits have been made under this daughter plan yet.

- 2026-07-29 Tranche B (Steps 2 and 3 delegation check + attribution design):
  - Completed Step 2 parent delegation check:
    - Parent plan `VP Clone/Code Review/2026-07-29_vp_performance_hotspot_recovery_plan.md` marks Step 9 as `Delegated / in progress`.
    - Parent Step 9 names this daughter plan as the owner for implementation details.
    - Parent Tranche I records the handoff, probe requirements, provider signature/context guardrails, request-kind logging, provider-mode summarization, and the no-loading-polish boundary.
  - Completed Step 3 attribution design by rereading the current provider and call-site code:
    - Provider retrieval function: `vp_partition_get_hierarchy_slice(vp_rows, trade_flow, group_filter, subgroup_filter, market_segment_filter)` in `VP Clone/Programs/app_source/global.R`.
    - Provider public helper: `vp_partition_provider_filter_rows(vp_rows, trade_flow, group_filter, subgroup_filter, market_segment_filter, commodity_name = NULL, commodity_detail = NULL)`.
    - Server call site: `filter_vp_rows_for_resolved_hierarchy()` in `VP Clone/Programs/app_source/server/02_partner_and_notes.R`.
    - Current provider logs include `mode`, `rows`, and, for disk/materialized paths, `fallback_reason`, `manifest_reason`, and `partition_file`.
    - Current memory-cache and direct-fallback provider log branches do not include partition file or caller context.
    - The server call site already builds `filter_context_key` with source, active tab, filter purpose, trade flow, selected hierarchy choices, commodity name/detail, resolution mode, path name, strict-rollup flag, and sparse-selection flag.
  - Step 3 design decision:
    - Add a small scalar provider context argument in the implementation tranche rather than relying on global state.
    - Proposed call path: pass `provider_context = list(...)` from `filter_vp_rows_for_resolved_hierarchy()` into `vp_partition_provider_filter_rows()`, then into `vp_partition_get_hierarchy_slice()`.
    - Proposed provider context fields for first implementation: `filter_purpose`, `active_tab`, `source`, `request_kind`, `trade_flow`, `group_filter`, `subgroup_filter`, `market_segment_filter`, `commodity_name`, `commodity_detail`, `resolution_mode`, `strict_rollup_context`, `sparse_selection`, and `path_name`.
    - Include the context in every practical `vp_partition_provider_slice()` branch: `memory_cache`, `disk_cache`, `materialized`, and `direct_fallback`.
    - Keep fields scalar and low-overhead; do not log row payloads, vectors, or large choice lists.
  - Gate decision:
    - Proceed next to Step 4, creating or recovering `VP Clone/System/Testing/vp_perf_probe_partition_provider.R`.
    - Do not implement provider prewarm, request de-duplication, cache eviction, or partition serialization changes until direct provider baseline attribution exists.

- 2026-07-29 Tranche C (Steps 4 and 5 direct provider probe + initial baseline):
  - Created focused direct non-Shiny provider probe: `VP Clone/System/Testing/vp_perf_probe_partition_provider.R`.
  - Probe design follows the established parent/daughter harness conventions:
    - Standalone Rscript harness, no browser launch.
    - Deterministic CSV output under `VP Clone/Logs`.
    - Cache-state labels per row.
    - Request-kind field with current value `probe`.
    - Provider mode, fallback reason, manifest reason, elapsed time, partition file, hierarchy filters, commodity filters, caller-placeholder fields, partition-file state, memory-cache state, provider cache entry count, total cached rows, and cache size estimate.
  - Validation:
    - Parse marker: `PARSE_OK_VP_PARTITION_PROVIDER_PROBE`.
    - Step 4 harness CSV: `VP Clone/Logs/vp_perf_probe_partition_provider_step4_partition_provider_probe_initial_20260729T191834Z.csv`.
    - Step 4 result: PASS; run 1 `disk_cache` 175ms / 211 rows; run 2 `memory_cache` 2ms / 211 rows.
  - Step 5 initial direct baseline:
    - CSV: `VP Clone/Logs/vp_perf_probe_partition_provider_step5_baseline_provider_attribution_20260729T191858Z.csv`.
    - Artifact load: 11.400s.
    - Scenario: `default_provider_slice` = `import / Dry pulses / Dried beans / Dried / Bambara beans / All`.
    - Run 1: `cache_state = warm_partition_disk`, `provider_mode = disk_cache`, `manifest_reason = manifest_current`, elapsed 175ms, output rows 211, partition file `slice__619ba8315752b098.rds`, partition size about 1.885 MB.
    - Run 2: `cache_state = warm_session`, `provider_mode = memory_cache`, elapsed 2ms, output rows 211.
    - Provider cache estimate after run: 1 entry, 30,280 cached provider-slice rows before commodity filtering, about 12.278 MB.
  - Interpretation:
    - The direct provider probe successfully distinguishes warm-partition-disk from warm-session behavior and confirms the provider memory path is much faster for the tested slice.
    - This direct baseline validates provider mechanics, but it uses synthetic caller fields (`provider_probe`) and therefore cannot yet identify app runtime callers.
  - Gate decision:
    - Proceed to Step 6 provider caller-context attribution plumbing.
    - Do not choose prewarm, request de-duplication, cache eviction, or partition serialization changes until app runtime provider records include caller context.

- 2026-07-29 Tranche D (Step 6 provider caller-context attribution plumbing):
  - Edited `VP Clone/Programs/app_source/global.R`:
    - Added `vp_partition_context_scalar()` and `vp_partition_context_details()` helpers for low-overhead scalar provider context logging.
    - Added optional `provider_context = NULL` to `vp_partition_get_hierarchy_slice()`.
    - Added optional `provider_context = NULL` to `vp_partition_provider_filter_rows()`.
    - Included context details in `vp_partition_provider_slice()` records for `direct_fallback`, `memory_cache`, `disk_cache`, and `materialized` branches.
    - Added `partition_file` to memory-cache and direct-fallback provider records where the path can be derived.
    - Did not change provider cache keys, manifest validation, partition read/write behavior, or fallback behavior.
  - Edited `VP Clone/Programs/app_source/server/02_partner_and_notes.R`:
    - Built scalar `provider_context` inside `filter_vp_rows_for_resolved_hierarchy()` from the already-existing `filter_context_key` and resolved hierarchy values.
    - Passed that context into `vp_partition_provider_filter_rows()`.
    - First context fields: `request_kind`, `filter_purpose`, `active_tab`, `source`, `trade_flow`, `group_filter`, `subgroup_filter`, `market_segment_filter`, `commodity_name`, `commodity_detail`, `resolution_mode`, `strict_rollup_context`, `sparse_selection`, and `path_name`.
  - Validation:
    - App parse marker: `PARSE_OK_PROVIDER_CONTEXT_PLUMBING` for `global.R` and `02_partner_and_notes.R`.
    - Bounded hierarchy probe passed with label `step6_provider_context_plumbing_hierarchy`.
    - Probe CSV: `VP Clone/Logs/vp_perf_probe_hierarchy_transition_step6_provider_context_plumbing_hierarchy_20260729T192049Z.csv`.
    - Probe result: PASS, cache state `warm_partition_disk`, total 200.013s, hierarchy 76.367s.
    - Requested runtime log path again did not materialize despite being reported by the probe.
    - Exact fallback logs summarized:
      - `VP Clone/Logs/vp_runtime_perf_proc_20260729T192104Z_28084.jsonl`.
      - `VP Clone/Logs/vp_runtime_perf_c186acdfe804bb7fd2aa75ec97fc5aa4.jsonl`.
    - Runtime summary outputs: `VP Clone/Logs/vp_perf_runtime_summary_step6_provider_context_plumbing_hierarchy_20260729T192437Z_*.csv`.
  - Runtime summary evidence:
    - Runtime summary read 2 files / 460 records.
    - `filter_vp_rows_for_resolved_hierarchy()` total: 71 calls / 10.9800s.
    - Provider partition summary: 5 disk-cache calls / 7.3614s total; 66 memory-cache calls / 0.3449s total.
    - Top churn remained `display_month_mapping` 24, `type_choice_base_values` 15, `filtered_data` 9, `mixed_volume_family_check` 9, and `quantity_units_context` 8.
  - Raw provider attribution check:
    - Provider records now include `request_kind`, `filter_purpose`, `active_tab`, `source`, trade flow, hierarchy filters, commodity fields, resolution mode, strict/sparse flags, and path name.
    - All five disk-cache records were attributed to `mixed_volume_family_check`.
    - Disk-cache records:
      - 3.7069s, `mixed_volume_family_check`, `unknown` / `unknown`, export rollup `P3_group_all`, file `slice__3144c44c208d70b8.rds`, 267,151 rows.
      - 2.0265s, `mixed_volume_family_check`, Current vs. Average / `vp_trade`, import rollup `P3_group_all`, commodity Artichokes, file `slice__39f0667435560dd5.rds`, 228,529 rows.
      - 0.3666s, `mixed_volume_family_check`, Current vs. Average / `vp_trade`, import Dry pulses group rollup, commodity Artichokes, file `slice__3a64269c693ee8d0.rds`, 41,985 rows.
      - 0.3257s, `mixed_volume_family_check`, Current vs. Average / `vp_trade`, import Dry pulses / Dried beans subgroup rollup, commodity Austrian winter peas, file `slice__6a8d361a1769f996.rds`, 30,280 rows.
      - 0.9357s, `mixed_volume_family_check`, Current vs. Average / `vp_trade`, import Dry pulses / Dried beans / Dried, commodity Bambara beans, file `slice__619ba8315752b098.rds`, 30,280 rows.
  - Interpretation:
    - Step 6 attribution plumbing succeeded: provider disk reads can now be tied to app caller purpose and resolved hierarchy context.
    - The next optimization should not target generic provider memory hits; those remain fast.
    - The next optimization choice should focus on why `mixed_volume_family_check` is the first user-hit consumer for each cold hierarchy slice, and whether that cost can be reduced by targeted call-site reuse or bounded non-blocking prewarm without simply moving synchronous disk latency earlier.
  - Gate decision:
    - Proceed to Step 7 only after selecting the smallest evidence-backed change.
    - Do not add broad prewarm, cache eviction, or RDS compression in response to this Step 6 result.

- 2026-07-29 Tranche E (Step 7 candidate probes and rejected direct mixed-check branch):
  - Ran a focused RDS compression A/B probe against the five Step 6 disk-cache partition files.
    - Output CSV: `VP Clone/Logs/vp_perf_probe_partition_rds_compression_ab_step7_candidate_20260729T192707Z.csv`.
    - Result: uncompressed reads were only modestly faster while file sizes grew roughly 9-11x.
    - Decision: reject partition RDS compression as the next small Step 7 change.
  - Ran a focused direct mixed-volume boolean scan probe against the five Step 6 disk-cache contexts.
    - Output CSV: `VP Clone/Logs/vp_perf_probe_mixed_boolean_scan_step7_candidate_20260729T192728Z.csv`.
    - Result: direct scans were individually cheap for the tested contexts: 54ms, 89ms, 86ms, 69ms, and 141ms.
    - Decision: test a small app-code branch that answers `mixed_volume_family_check` directly from in-memory artifact columns before falling back to the shared context path.
  - Implemented and validated the direct mixed-check candidate, then reverted it after the app-path probe falsified the stronger hypothesis.
    - Candidate parse marker: `PARSE_OK_STEP7_MIXED_DIRECT_CHECK`.
    - Candidate hierarchy probe: `step7_mixed_direct_check_hierarchy`.
    - Candidate probe CSV: `VP Clone/Logs/vp_perf_probe_hierarchy_transition_step7_mixed_direct_check_hierarchy_20260729T192801Z.csv`.
    - Candidate exact fallback logs summarized:
      - `VP Clone/Logs/vp_runtime_perf_proc_20260729T192804Z_38600.jsonl`.
      - `VP Clone/Logs/vp_runtime_perf_87b904ee992eba70b837315d558cc9dd.jsonl`.
    - Candidate runtime summary outputs: `VP Clone/Logs/vp_perf_runtime_summary_step7_mixed_direct_check_hierarchy_20260729T193056Z_*.csv`.
    - Candidate hierarchy probe result: PASS, total 160.712s, hierarchy 70.253s.
    - Candidate partition summary: 5 disk-cache calls / 5.6839s and 56 memory-cache calls / 0.2754s.
    - Candidate added direct-check work: `vp_mixed_volume_family_direct_check()` 30 calls / 3.7685s.
    - Candidate disk-cache attribution shifted rather than disappeared:
      - 2.4632s `type_choice_base_values` for export rollup `slice__3144c44c208d70b8.rds`.
      - 1.9113s `quantity_units_context` for import rollup `slice__39f0667435560dd5.rds`.
      - 0.3155s `quantity_units_context` for import Dry pulses group rollup `slice__3a64269c693ee8d0.rds`.
      - 0.2602s `quantity_units_context` for import Dry pulses / Dried beans subgroup rollup `slice__6a8d361a1769f996.rds`.
      - 0.7337s `quantity_units_context` for import Dry pulses / Dried beans / Dried `slice__619ba8315752b098.rds`.
    - Revert validation marker: `PARSE_OK_STEP7_DIRECT_CHECK_REVERTED`.
  - Interpretation:
    - `mixed_volume_family_check` was the first user-hit consumer for cold provider slices, not the sole reason those slices were needed.
    - A narrow direct boolean replacement does not remove the underlying cold-slice reads; it mostly moves them to the next consumer and adds scan overhead.
    - The next successful Step 7 branch likely needs a broader design than a single boolean call-site patch: either lightweight provider metadata/indexes for several context questions, a carefully bounded non-blocking prewarm, or a partition/data-shape change.
  - Gate decision:
    - Keep the successful Step 6 attribution plumbing and direct provider probe.
    - Keep the direct mixed-check candidate reverted.
    - Step 7 remains in progress; select the next branch explicitly before more app-code optimization edits.

- 2026-07-29 Tranche F (Step 7 rejected type-choice in-memory branch):
  - Investigated the Step 7 candidate suggested by the shifted disk-cache attribution from the rejected direct mixed-check branch.
  - Local hypothesis:
    - `build_commodity_choice_base_values()` in `VP Clone/Programs/app_source/server/01_state_and_custom_types.R` reads a full provider slice for `type_choice_base_values` only to derive VP commodity/detail choice values.
    - Replacing that call with existing in-memory `vp_native_rows_for_choice_lists()` / `vp_filter_rows_for_hierarchy_choices()` helpers might remove the export rollup provider disk read without changing visible choices.
  - Candidate edit:
    - Temporarily changed the VP branch of `build_commodity_choice_base_values()` to filter `rice_data_vp_trade_monthly` in memory by trade flow and hierarchy choices rather than calling `filter_vp_rows_for_resolved_hierarchy(..., vp_filter_purpose = "type_choice_base_values")`.
  - Candidate validation:
    - Parse marker: `PARSE_OK_STEP7_TYPE_CHOICE_IN_MEMORY`.
    - Hierarchy probe label: `step7_type_choice_in_memory_hierarchy`.
    - Probe CSV: `VP Clone/Logs/vp_perf_probe_hierarchy_transition_step7_type_choice_in_memory_hierarchy_20260729T193312Z.csv`.
    - Reported runtime log path: `VP Clone/Logs/vp_runtime_perf_hierarchy_transition_step7_type_choice_in_memory_hierarchy_20260729T193312Z.jsonl`.
    - Exact fallback logs observed for the failed run:
      - `VP Clone/Logs/vp_runtime_perf_proc_20260729T193315Z_26480.jsonl`.
      - `VP Clone/Logs/vp_runtime_perf_0783c5a3166fe251ddfe0cdb71aa03e9.jsonl`.
    - Probe result: FAIL, total 202.082s, hierarchy 91.805s.
    - Failure details: group/subgroup/segment waits failed; final state resolved `Dry pulses` / `Dried beans` / `__all__` while target segment was `Dried`; `resolved_path_ok = FALSE`.
  - Revert validation:
    - Reverted the candidate change in `01_state_and_custom_types.R`.
    - Parse marker after revert: `PARSE_OK_STEP7_TYPE_CHOICE_REVERTED`.
  - Interpretation:
    - Even though the candidate was plausible from a provider-disk perspective, it touched a live choice-building path and failed the app-path hierarchy probe.
    - Do not reattempt this as a quick patch. If type-choice reads are targeted again, first design a narrower contract for choice-list metadata with direct equivalence checks on emitted choices before Shiny integration.
  - Gate decision:
    - Keep this candidate reverted.
    - Step 7 remains in progress with no accepted optimization beyond Step 6 attribution plumbing.
    - Next acceptable branches need a focused design/probe first: lightweight provider metadata/index, bounded non-blocking prewarm with request-kind evidence, or a measured partition/data-shape change.

- 2026-07-29 Tranche G (Step 7 metadata/index branch selection and implementation guardrails):
  - Selected Option 1 lightweight provider metadata/index as the next Step 7 implementation branch.
  - Reserved Option 3 partition/data-shape change as the measured fallback if metadata cannot answer hot questions exactly or does not reduce app-runtime cold-slice disk cost.
  - Folded the implementation audit recommendations into this daughter source-of-truth plan before metadata code edits.
  - Added the explicit metadata contract:
    - Provider-slice key remains `trade_flow`, `group_filter`, `subgroup_filter`, and `market_segment_filter`.
    - `unique_volume_families` is the canonical correctness field.
    - `volume_family` and `has_mixed_volume_family` are derived convenience fields.
    - Commodity/detail sub-indexes may be added only where required for correctness and measured to remain compact.
    - Metadata states and definitive/insufficient fallback rules must be explicit.
  - Added manifest/versioning guardrails:
    - Metadata population must use a versioned rebuild/materialization path or a controlled metadata backfill.
    - Old partition manifest entries must not be treated as metadata-capable.
    - Generated metadata must be verified against partition rows.
  - Added caller/cache guardrails:
    - Default caller behavior remains row-returning.
    - Metadata-only callers must opt in through request shape such as `metadata_only` or `require_rows = FALSE`.
    - Metadata-only cache entries must not share row-returning cache keys unless rows are present.
  - Added operational guardrails:
    - Atomic partition/manifest writes for Windows/OneDrive safety.
    - Lazy process-level manifest caching with invalidation, not startup preloading.
    - Provider-level request de-duplication only if evidence shows repeated identical provider/cache requests.
    - No UI debounce, no loading polish, and no visible UI timing changes.
  - Added validation gates:
    - Direct metadata equivalence probe before app wiring.
    - Manifest size/read-time and metadata lookup timing.
    - Heavy-slice detection and Option 3 fallback criteria.
    - Automated fallback runtime-log discovery where practical.
  - Gate decision:
    - Proceed to metadata/index implementation only after this markdown update validates.
    - Do not implement Option 3 fallback code until Option 1 evidence shows metadata is insufficient.

- 2026-07-29 Tranche H (Step 7 provider metadata scaffold and direct probe validation):
  - Edited `VP Clone/Programs/app_source/global.R` for the provider-side metadata scaffold:
    - Added `vp_partition_manifest_schema_version <- "vp_trade_partition_manifest_v2"` and `vp_partition_metadata_schema_version <- "vp_trade_partition_metadata_v1"`.
    - Bumped `vp_partition_provider_version` to `vp_trade_partition_provider_v2` so old manifest entries are not treated as metadata-capable.
    - Added lazy process-level manifest caching keyed by manifest path, mtime, size, provider version, builder version, and artifact signature.
    - Added atomic `saveRDS()` helper for partition and manifest writes.
    - Added slice metadata builders for row count, column count, `unique_volume_families`, derived `volume_family`, derived `has_mixed_volume_family`, and compact `CommodityName` / `CommodityName + commodity` sub-indexes.
    - Added manifest-entry metadata validation and metadata-state helpers.
    - Added `vp_partition_get_hierarchy_metadata()` to read manifest metadata without reading the partition RDS and log `vp_partition_provider_metadata()` PERF records.
  - Edited `VP Clone/System/Testing/vp_perf_probe_partition_provider.R` for direct metadata coverage:
    - Default provider version changed to `vp_trade_partition_provider_v2`.
    - Probe materialization now writes v2 partition files plus v2 manifest entries with metadata.
    - Probe output now records `metadata_state`, `metadata_definitive`, `metadata_parity`, `metadata_lookup_ms`, `full_rows_metadata_ms`, metadata/full unique family fields, metadata/full mixed flags, full-slice row/column counts, manifest size, metadata object size, and heavy-slice flag.
    - Fixed warm-session reporting so cached full-slice rows emit `metadata_from_memory_cache` and parity fields instead of appearing as metadata unavailable.
  - Validation:
    - Parse marker for provider scaffold and probe together: `PARSE_OK_PROVIDER_METADATA_AND_PROBE`.
    - Probe correction parse marker: `PARSE_OK_PROVIDER_METADATA_PROBE_WARM_SESSION`.
    - `get_errors` reported no diagnostics for `global.R` or `vp_perf_probe_partition_provider.R`.
    - Initial v2 metadata scaffold probe: `VP Clone/Logs/vp_perf_probe_partition_provider_step7_metadata_scaffold_provider_probe_20260729T200501Z.csv`.
    - Initial probe result: PASS; run 1 materialized a new v2 partition in 5.216s, wrote manifest metadata, and reported `metadata_current`, `metadata_definitive = TRUE`, `metadata_parity = TRUE`, 30,280 full-slice rows, 211 commodity-filtered rows, manifest size about 0.0013 MB, metadata size about 0.0592 MB.
    - Rerun probe after v2 partition existed: `VP Clone/Logs/vp_perf_probe_partition_provider_step7_metadata_scaffold_provider_probe_rerun_20260729T200610Z.csv`.
    - Rerun result: PASS; run 1 `warm_partition_disk` = `disk_cache` 457ms with `metadata_current`, `metadata_definitive = TRUE`, `metadata_parity = TRUE`, `metadata_lookup_ms = 6`, and full-row metadata computation 115ms; run 2 `warm_session` = `memory_cache` 4ms with `metadata_from_memory_cache`, `metadata_definitive = TRUE`, and `metadata_parity = TRUE`.
  - Interpretation:
    - Provider metadata construction and manifest-read access are correct for the default tested slice.
    - Metadata size is small relative to the partition file and cached row object for the tested slice.
    - This validates proceeding to app consumer wiring, but only through explicit metadata-only request shape and cache separation.
  - Gate decision:
    - Proceed to metadata-only consumer wiring in `VP Clone/Programs/app_source/server/02_partner_and_notes.R`.
    - Preserve row-returning behavior by default.
    - Do not implement Option 3 partition/data-shape fallback unless app-runtime evidence shows the metadata path is insufficient.

- 2026-07-29 Tranche I (Step 7 metadata consumer wiring, selected parity probe, and app-path measurement):
  - Edited `VP Clone/Programs/app_source/server/02_partner_and_notes.R`:
    - Added separate `vp_trade_context_metadata_cache` storage and order/limit tracking so metadata-only entries cannot poison row-returning context cache entries.
    - Added metadata cache get/set helpers that accept list metadata entries but never require or store row payloads.
    - Added `vp_trade_context_metadata_entry()` for explicit metadata-only context requests.
    - Added `require_rows = TRUE` to `vp_trade_context_entry()` and included `rows_required` in the row-context cache key.
    - `require_rows = FALSE` now routes to the metadata-only helper rather than the row cache.
    - Metadata helper refuses non-VP, disabled-provider, non-provider, and country-filtered contexts, returning unavailable/insufficient so callers fall back to rows.
    - Metadata helper uses provider manifest metadata and commodity/detail sub-indexes only when the selected metadata has exactly one canonical `unique_volume_families` value.
    - `vp_rollup_context_has_mixed_volume_family()` now tries metadata first and falls back to the original row path when metadata is unavailable, insufficient, or not definitive.
    - `vp_trade_context_volume_family()` now tries metadata first when `context_rows` is not supplied and falls back to the original row path when metadata is unavailable, insufficient, or not definitive.
  - Edited `VP Clone/System/Testing/vp_perf_probe_partition_provider.R`:
    - Added built-in `--scenario-set=step6_disk_hit_slices` covering the five Step 6 disk-hit partition files.
    - Corrected that scenario set to use app rollup provider tokens (`__vp_rollup_all_group__`, `__vp_rollup_all_subgroup__`, `__vp_rollup_all_market_segment__`) instead of blank filters.
    - Added selected commodity/detail metadata parity fields: `selected_metadata_state`, `selected_metadata_definitive`, `selected_metadata_parity`, selected metadata/full unique family fields, selected volume family fields, selected mixed flags, and selected row count.
    - Made metadata parity mismatches fail the probe.
    - Added `source_signature` to the direct-probe manifest schema so probe-written manifests are compatible with the app's `vp_partition_manifest_compatible()` check.
  - Validation markers:
    - `PARSE_OK_METADATA_CACHE_STATE`.
    - `PARSE_OK_METADATA_CONTEXT_HELPERS`.
    - `PARSE_OK_METADATA_CONSUMER_WIRING`.
    - `PARSE_OK_METADATA_WIRING_AND_STEP6_PROBE_SET`.
    - `PARSE_OK_STEP6_PROBE_ROLLUP_TOKENS`.
    - `PARSE_OK_SELECTED_METADATA_PARITY_PROBE`.
    - `PARSE_OK_PROBE_SOURCE_SIGNATURE`.
    - `get_errors` reported no diagnostics for touched R files after each parse checkpoint.
    - `git diff --check` passed for touched code/plan files.
  - Direct probe evidence:
    - Initial expanded five-slice probe with blank rollup filters passed internally but did not match Step 6 partition files; rejected as a probe scenario bug, not performance evidence.
    - Corrected selected-parity probe: `VP Clone/Logs/vp_perf_probe_partition_provider_step7_metadata_step6_disk_hit_slices_selected_parity_20260729T201336Z.csv`.
    - Signature-aligned direct probe: `VP Clone/Logs/vp_perf_probe_partition_provider_step7_metadata_step6_disk_hit_slices_signature_aligned_20260729T201910Z.csv`.
    - Signature-aligned direct probe result: PASS; all five first runs were `disk_cache`, all second runs were `memory_cache`, and slice plus selected metadata parity passed.
    - Selected metadata interpretation from the parity probe:
      - Export rollup remained selected-non-definitive (`weight|liquid`) and correctly falls back for family questions.
      - Import rollup with Artichokes selected metadata was definitive `weight` and parity passed.
      - Dry pulses / Artichokes and Dried beans / Austrian winter peas had empty selected row sets; selected metadata was insufficient/empty and fallback behavior is correct.
      - Bambara beans / All selected metadata was definitive `weight` and parity passed.
  - App-path validation:
    - First hierarchy probe after consumer wiring: `VP Clone/Logs/vp_perf_probe_hierarchy_transition_step7_metadata_consumer_wiring_hierarchy_20260729T201421Z.csv`.
    - First hierarchy probe ended `FAIL` due to harness/missing-control condition, but final hierarchy path still resolved to `Dry pulses / Dried beans / Dried`.
    - Exact fallback runtime log for the failed run: `VP Clone/Logs/vp_runtime_perf_proc_20260729T201436Z_5984.jsonl`.
    - Exact runtime summary for the failed run: `VP Clone/Logs/vp_perf_runtime_summary_step7_metadata_consumer_wiring_hierarchy_exact_20260729T201821Z_*.csv`.
    - Failed-run blocker found: the direct probe manifest lacked `source_signature`, so the app rejected it as `manifest_stale_or_incompatible` and materialized v2 partitions. This was fixed in the probe.
    - Passing hierarchy probe after source-signature alignment: `VP Clone/Logs/vp_perf_probe_hierarchy_transition_step7_metadata_signature_aligned_hierarchy_20260729T201950Z.csv`.
    - Passing hierarchy result: PASS, total 158.029s, hierarchy 71.019s, final path resolved correctly.
    - Requested runtime log path again did not materialize.
    - Exact fallback runtime log summarized: `VP Clone/Logs/vp_runtime_perf_proc_20260729T201953Z_39320.jsonl`.
    - Exact runtime summary outputs: `VP Clone/Logs/vp_perf_runtime_summary_step7_metadata_signature_aligned_hierarchy_exact_20260729T202240Z_*.csv`.
  - Runtime summary evidence for the passing run:
    - Runtime summary read 1 file / 312 records.
    - `filter_vp_rows_for_resolved_hierarchy()`: 68 calls / 7.9634s total, down from Step 6's 71 calls / 10.9800s.
    - `vp_partition_provider_metadata()`: 4 calls / 0.8153s total.
    - Provider partition summary: 5 disk-cache calls / 5.1963s total; 63 memory-cache calls / 0.2598s total.
    - Compared with Step 6, provider disk-cache time improved from 7.3614s to 5.1963s and memory-cache calls dropped from 66 to 63.
    - Compared with the Step 8 parent baseline, provider disk-cache time improved only modestly from 5.6491s to 5.1963s.
  - Interpretation:
    - The metadata branch is correct and preserves default row-returning behavior.
    - It is a limited win, not the big win target: it avoids some metadata-answerable mixed/quantity context row pulls, but the app still needs five cold provider slice reads for row-consuming paths such as choice/display/filter consumers.
    - Option 1 by itself does not eliminate the cold-slice disk hotspot.
    - Option 3 should now be treated as the next measured fallback candidate, with row-index serialization the most plausible first variant because the artifact is already resident and the remaining cost is reading full slice data frames from disk.
  - Gate decision:
    - Keep the metadata branch and probe improvements.
    - Do not call the Step 9 target complete yet.
    - Next implementation tranche should either start Option 3 row-index partition fallback or explicitly stop with this limited metadata result and hand the decision back to the parent plan.

- 2026-07-29 Tranche J (Step 7 Option 3A Provider v3 row-index implementation and direct validation):
  - Updated this daughter plan before code edits to make Option 3A the active implementation branch after the metadata branch proved correct but insufficient.
  - Edited `VP Clone/Programs/app_source/global.R`:
    - Bumped provider compatibility to `vp_trade_partition_provider_v3` and manifest compatibility to `vp_trade_partition_manifest_v3`.
    - Added structured payload schema `vp_trade_partition_payload_v1`.
    - Added canonical-source identity and eligibility helpers using source signature, row count, column count, column hash, sampled row-order fingerprint, and a canonical source token on `rice_data_vp_trade_monthly`.
    - Changed Provider v3 materialization to write row-index payloads instead of full data frames.
    - Changed Provider v3 disk-cache reads to read payloads, validate source identity and index bounds, reconstruct ordinary data frames from the resident canonical source, and preserve public row-returning behavior.
    - Preserved the v2 metadata semantics in manifest entries and runtime logging.
    - Added runtime timing fields for partition payload read and row reconstruction plus storage/source/index fields.
  - Edited `VP Clone/System/Testing/vp_perf_probe_partition_provider.R`:
    - Default provider version is now `vp_trade_partition_provider_v3` while preserving a v2 partition directory for full-frame read timing comparisons.
    - Added version-aware manifest schema selection, source identity/fingerprint helpers, row-index payload build/validate/restore helpers, and Provider v3 manifest-entry fields.
    - Added CSV fields for `storage_mode`, `payload_schema_version`, source identity, `index_count`, `max_index`, `v2_full_frame_read_ms`, `v3_payload_read_ms`, `reconstruction_ms`, `row_content_parity`, `source_mismatch_refused`, and `source_mismatch_reason`.
    - Added an intentional source-mismatch check that changes the source row count and requires payload validation to refuse reuse.
  - Validation:
    - Parse marker after helper work: `PARSE_OK_PROBE_ROW_INDEX_HELPERS`.
    - Parse marker after Provider v3/probe wiring: `PARSE_OK_ROW_INDEX_PROVIDER_AND_PROBE`.
    - `get_errors` reported no diagnostics for `global.R` or `vp_perf_probe_partition_provider.R`.
    - Option 3A materialization/direct parity probe passed: `VP Clone/Logs/vp_perf_probe_partition_provider_step7_option3_row_index_step6_slices_20260729T204819Z.csv`.
    - Option 3A disk-cache direct probe passed: `VP Clone/Logs/vp_perf_probe_partition_provider_step7_option3_row_index_step6_slices_disk_20260729T204922Z.csv`.
  - Direct disk-cache evidence from `step7_option3_row_index_step6_slices_disk`:
    - All five rows used `provider_mode = disk_cache`, `storage_mode = row_index`, `payload_schema_version = vp_trade_partition_payload_v1`, `row_content_parity = TRUE`, `source_mismatch_refused = TRUE`, `metadata_parity = TRUE`, and `selected_metadata_parity = TRUE`.
    - Export rollup: v2 full-frame read 1785ms, v3 payload read 10ms, reconstruction 94ms, v3 payload file about 0.542 MB.
    - Import rollup: v2 full-frame read 1336ms, v3 payload read 12ms, reconstruction 78ms, v3 payload file about 0.464 MB.
    - Import Dry pulses group rollup: v2 full-frame read 231ms, v3 payload read 4ms, reconstruction 13ms, v3 payload file about 0.085 MB.
    - Import Dry pulses / Dried beans subgroup rollup: v2 full-frame read 149ms, v3 payload read 4ms, reconstruction 9ms, v3 payload file about 0.062 MB.
    - Import Dry pulses / Dried beans / Dried segment: v2 full-frame read 143ms, v3 payload read 3ms, reconstruction 11ms, v3 payload file about 0.062 MB.
  - Interpretation:
    - The direct Provider v3 row-index contract passed the hard correctness gate before Shiny: payload reads are much smaller/faster than v2 full-frame reads, reconstruction preserves row content, metadata remains correct, selected metadata remains correct, and mismatched source identity is refused.
    - Direct probe elapsed time still includes validation-only direct filters and metadata computations, so the split timing fields are the meaningful partition-shape evidence.
  - Gate decision:
    - Proceed to one bounded Shiny hierarchy probe with runtime PERF enabled.
    - Summarize exact fallback runtime logs if the requested runtime path does not materialize.
  - App-path validation and fast-source follow-up:
    - First Option 3A hierarchy probe passed: `VP Clone/Logs/vp_perf_probe_hierarchy_transition_step7_option3_row_index_hierarchy_20260729T205040Z.csv`; total 191.097s, hierarchy 73.033s, final path resolved correctly.
    - The reported runtime log path did not materialize. Exact fallback logs summarized:
      - `VP Clone/Logs/vp_runtime_perf_proc_20260729T205056Z_25504.jsonl`.
      - `VP Clone/Logs/vp_runtime_perf_431107a756499d0ccdbb0f8317476fd2.jsonl`.
      - Summary outputs: `VP Clone/Logs/vp_perf_runtime_summary_step7_option3_row_index_hierarchy_exact_20260729T205416Z_*.csv`.
    - First Option 3A runtime summary showed the intended disk-cache win but exposed a new memory-cache regression:
      - Provider disk-cache: 5 calls / 1.1763s, down from the metadata branch's 5 calls / 5.1963s.
      - Provider memory-cache: 63 calls / 5.1814s, far slower than the metadata branch's 63 calls / 0.2598s.
    - Root cause hypothesis and fix:
      - `vp_partition_get_hierarchy_slice()` computed full source eligibility, including source signature and sampled source fingerprint, before the provider memory-cache short-circuit.
      - Added a source-signature cache and canonical-source identity fast path in `global.R` so already-marked `rice_data_vp_trade_monthly` can prove eligibility from stored identity without recomputing the fingerprint on every memory-cache hit.
    - Validation after fast-source fix:
      - Parse marker: `PARSE_OK_SOURCE_IDENTITY_FAST_PATH`.
      - Cleanup parse marker: `PARSE_OK_SOURCE_IDENTITY_FAST_PATH_CLEAN`.
      - `get_errors` reported no diagnostics for `global.R`.
      - First fast-source hierarchy run: `VP Clone/Logs/vp_perf_probe_hierarchy_transition_step7_option3_row_index_fast_source_hierarchy_20260729T205523Z.csv`; status `PARTIAL` because `shinytest2` idle waits failed after subgroup/segment choices, but final path resolved correctly to `Dry pulses / Dried beans / Dried`. Exact fallback runtime logs were summarized in `VP Clone/Logs/vp_perf_runtime_summary_step7_option3_row_index_fast_source_hierarchy_exact_20260729T205828Z_*.csv` and showed provider disk-cache 5 calls / 0.5827s plus memory-cache 69 calls / 0.3200s.
      - User noted possible local CPU interference during the PARTIAL run, so the probe was rerun with the same app path and a longer bounded stage timeout.
      - Clean confirmation hierarchy probe passed: `VP Clone/Logs/vp_perf_probe_hierarchy_transition_step7_option3_row_index_fast_source_confirm_20260729T210115Z.csv`; total 158.424s, hierarchy 72.163s, final path resolved correctly.
      - The reported confirmation runtime log path did not materialize. Exact fallback logs summarized:
        - `VP Clone/Logs/vp_runtime_perf_proc_20260729T210119Z_34896.jsonl`.
        - `VP Clone/Logs/vp_runtime_perf_ff63212a6929b338ad74c09be15a4055.jsonl`.
        - Summary outputs: `VP Clone/Logs/vp_perf_runtime_summary_step7_option3_row_index_fast_source_confirm_exact_20260729T210410Z_*.csv`.
    - Clean confirmation runtime summary:
      - `filter_vp_rows_for_resolved_hierarchy()`: 68 calls / 3.7256s, improved from the metadata branch's 68 calls / 7.9634s and Step 6's 71 calls / 10.9800s.
      - Provider disk-cache: 5 calls / 0.7681s, improved from metadata branch 5.1963s, Step 6 7.3614s, and parent Step 8 baseline 5.6491s.
      - Provider memory-cache: 63 calls / 0.2883s, back near the metadata branch's 0.2598s and far below the first Option 3A run's 5.1814s.
      - Probe total: 158.424s; hierarchy stage: 72.163s. Total/hierarchy remained comparable to the metadata branch because remaining time is now outside provider disk I/O and includes startup/client/harness work.
    - Final closeout validation:
      - Parse marker: `PARSE_OK_STEP9_PROVIDER_CLOSEOUT` for `global.R`, `02_partner_and_notes.R`, `vp_perf_probe_partition_provider.R`, and `vp_perf_probe_hierarchy_transition.R`.
      - `get_errors` reported no diagnostics for those four R files.
      - `git diff --check` passed for touched code and plan files.
  - Interpretation:
    - Option 3A produced the targeted big provider-disk win without breaking app-path hierarchy resolution.
    - Row-index partitions reduced the five cold provider disk-cache reads from roughly 5.2s in the metadata branch to 0.77s in the clean confirmation run.
    - Source-safety checks are now strict enough for row-index reuse and cheap enough not to poison memory-cache hits.
    - The next parent-plan target should move away from provider disk reads and toward the remaining top timed/churn areas, especially startup/client mount cost and repeated display/type/filter consumers.

## Summary

Step 9 targeted the VP partition provider because earlier runtime logs showed that a few cold disk-cache reads were still expensive even though warm memory-cache reads were cheap. The first work in this daughter plan made those reads attributable to real app callers, then tested smaller ideas before changing the partition shape.

The metadata/index branch was correct and useful but not enough: it preserved row-returning behavior and answered some metadata-only questions, yet the app still had five cold provider disk reads totaling about 5.1963s in the passing metadata run. That triggered Option 3A.

Option 3A changed VP partition files from full saved data frames to compact row-index payloads. The app still receives ordinary data frames, but disk-cache reads now load integer row indexes and reconstruct rows from the already-resident canonical VP monthly artifact. The implementation includes strict source identity checks, row-order fingerprinting, index bounds checks, payload schema/version gates, metadata parity, and source-mismatch refusal so stale row indexes cannot silently return wrong rows.

Direct probes passed before Shiny validation. The five Step 6 disk-hit slices all had row-content parity, metadata parity, selected metadata parity, and source-mismatch refusal. Split timings showed the meaningful change: the two largest full-frame reads were 1785ms and 1336ms in v2, while their v3 payload reads were 10ms and 12ms with reconstruction under 100ms.

The bounded Shiny confirmation passed after the source-identity fast path fix. In the clean confirmation runtime summary, provider disk-cache time fell to 5 calls / 0.7681s, down from 5.1963s in the metadata branch and 7.3614s in Step 6. Provider memory-cache time remained healthy at 63 calls / 0.2883s. The broader hierarchy stage stayed around 72s, which means the provider disk hotspot is no longer the main blocker; remaining time is now dominated by startup/client mount work and other repeated display/type/filter consumers.

Major investigated blockers included a direct-probe manifest missing `source_signature`, a rejected direct mixed-volume boolean branch that shifted disk reads instead of removing them, a rejected type-choice in-memory branch that broke hierarchy resolution, an RDS compression A/B that was not worth the file-size cost, and a first Option 3A app run that exposed expensive source-eligibility checks before the memory-cache short-circuit. The source-eligibility cost was fixed with cached source signatures and a canonical identity fast path.

Recommended next parent-plan target: recenter on the parent VP performance plan and choose the next measured hotspot from the latest runtime summaries. Provider disk reads are now substantially reduced, so the next big win is likely outside partition disk I/O: startup/client mount cost, lazy tab behavior, or repeated display/type/filter churn.
