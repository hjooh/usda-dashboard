# VP Commodity Partition and Rollup Sidecar Architecture Plan

Date: 2026-08-03

## Purpose

This plan defines the next VP/AP performance architecture investigation: move VP trade runtime access away from one global startup-loaded data frame and toward an indexed provider store made of a small startup shell, commodity native partitions, and separate rollup sidecars.

The current full VP trade artifact remains the correctness oracle throughout this branch. The candidate architecture is opt-in until it passes parity, performance, memory, soak, and fallback/rollback gates.

The important sequencing decision is that implementation does not start with sidecar generation. It starts with compatibility, currentity, rollout-control, and acceptance-harness hardening. Those contracts are required before sidecar timing or correctness evidence can be trusted.

## Hypothesis

- Current startup and reactive invalidation costs are dominated by treating loaded VP trade data as one global data frame that includes native rows plus a large rollup payload.
- A provider-backed indexed store can reduce startup artifact read time, reduce per-interaction working set size, and keep existing UI contracts stable if provider calls return the same data frame shape as the current full-artifact filter.
- The cheapest falsifiable implementation is a compatibility facade plus one provider seam that proves lazy slices are equivalent to full-artifact slices. Sidecar files are useful only after that boundary is explicit.

## Target Startup Path

1. Load app shell, UI metadata, source-state/currentity metadata, provider manifest bundle, and choice scaffolds needed for the landing screen.
2. Do not load the full VP trade artifact into the startup-critical path for lazy-sidecar mode.
3. Load only the default commodity native partition and required landing-context sidecars.
4. Load additional rollup sidecars lazily for selected commodity/context, hierarchy rollup, country/all-country, unit/display mode, and tab data needs.
5. Cache loaded partitions and sidecars by canonical source signature plus canonical selection key.

## Path To Move Away From

1. Reading the full VP trade artifact as one global startup-critical object.
2. Keeping native rows and all rollup rows embedded in the same startup artifact.
3. Running tab computations over an app-wide loaded VP data frame when the active view only needs one commodity or a narrow hierarchy context.
4. Letting reactive invalidations depend on a global data object whose size and identity change more broadly than the active view requires.
5. Making acceptance claims from runs where fallback, cache state, runtime log identity, or fixture selection is ambiguous.

## Phase 0: Branch Guardrails and Source Of Truth

1. Use this file as the implementation source of truth. Update it after every implementation tranche, failed attempt, rejected approach, validation result, and blocker investigation.
2. Add branch-level acceptance criteria before code changes: correctness parity against the full artifact, startup speed gates, interaction speed gates, cache-hit expectations, memory-footprint comparison, soak behavior, concurrency behavior, and rollback triggers.
3. Define opt-in experiment controls before wiring behavior: use a new lazy-sidecar provider mode plus isolated artifact/provider root. Do not rely on canonical RDS swapping because prior plans flagged currentity and fallback rebuild contamination risk.
4. Explicitly distinguish modes in flags and telemetry:
   - Production/full artifact mode.
   - Existing legacy provider mode.
   - New lazy commodity partition plus rollup sidecar mode.
   - Diagnostic mode where fallback and partial probe results may be inspected but cannot support acceptance claims.

## Phase 1: Compatibility Facade And Direct-Global Inventory

1. Inventory direct dependencies on the startup-loaded VP global data object across global and server code before changing startup load behavior.
2. Classify each consumer:
   - Can immediately route through the existing provider/filter seam.
   - Needs metadata or choice scaffolding only.
   - Needs a full data-frame compatibility facade.
   - Must remain full-artifact-only during the prototype.
3. Define a compatibility facade that preserves the current data-frame contract for consumers while allowing selected reads to be resolved by lazy provider requests.
4. Prevent the branch from succeeding by accident while still loading the full artifact in lazy mode. Add an explicit lazy-startup forbidden-dependency rule: lazy-sidecar startup may not require full VP rows except in diagnostic fallback.
5. Route first lazy adoption through the existing hierarchy/filter seam, not through broad tab rewrites. The likely first server path remains hierarchy resolution and VP row filtering, then `filtered_data_for_country`.
6. Keep direct global-data consumers in compatibility mode until their dependency has an explicit migration or exclusion decision.

## Phase 2: Architecture Specs Before Sidecar Generation

1. Define the startup shell schema:
   - Required eager objects.
   - Required columns.
   - UI choice scaffolds.
   - Source/currentity metadata.
   - Provider manifest bundle pointer.
   - Maximum startup payload budget.
   - Forbidden dependencies on full VP rows.
2. Define the sidecar key/schema specification before any build work. The spec must map existing hierarchy path semantics, strict rollup contexts, faceted/native behavior, country/all-country tokens, commodity tokens, source/trade flow, unit/display modes, date/current-vs-average needs, and fallback behavior into explicit keys.
3. Define sidecar categories:
   - Commodity native partition: non-rollup rows for one commodity.
   - Commodity hierarchy rollup sidecar: all-selection rollups for group/subgroup/market segment within a commodity.
   - Commodity country/all-country rollup sidecar: country-specific and all-country semantics.
   - Mixed-volume sidecar: rows needed to preserve mixed quantity, unit value, and YTD unit value behavior.
   - Tab-data sidecar only if row-level provider slices are not sufficient for a specific tab after parity testing.
   - Cross-commodity sidecar for true all-commodity or cross-commodity views, if present.
4. Define a manifest-of-manifests bundle contract. Shell, native partitions, rollup sidecars, metadata, provider version, builder version, schema version, source signature, row counts, file paths, file hashes, and created timestamps must validate as one coherent bundle.
5. Reject partial-current bundles before enabling lazy-sidecar mode for a session. Source-signature mismatch, stale sidecar, missing required sidecar, schema mismatch, or builder-version mismatch must disable candidate mode or move to explicitly logged diagnostic fallback.
6. Preserve Provider v3 safety behavior: strict source identity checks, stale/mismatch refusal, direct-filter fallback only where bounded and logged, and explicit missing-sidecar failure modes for acceptance runs.
7. Adopt hybrid sidecar building as the starting assumption:
   - Ahead-of-time for shell/default/high-value required sidecars.
   - Diagnostic-only on-demand materialization until locking, currentity, and fallback behavior are proven.
   - No production on-demand materialization until concurrency behavior passes explicit gates.

## Phase 3: Acceptance Harness Hardening First

1. Harden acceptance probes before using them for architecture decisions.
2. Acceptance mode must reject `PARTIAL` status.
3. Acceptance mode must prohibit `unknown_cache_state`.
4. Acceptance mode must require deterministic fixture selection.
5. Acceptance mode must fail if expected runtime logs are missing.
6. Add a run acceptance manifest for every acceptance run:
   - Run ID.
   - Scenario IDs.
   - Exact probe inputs.
   - Exact runtime log file paths.
   - Artifact signatures.
   - Provider mode.
   - Cache-state enforcement results.
   - Fixture selections.
   - Output file paths.
7. Bind runtime summaries to exact run IDs and exact emitted runtime log file paths. Modification-time discovery may remain only for diagnostic mode and must be labeled diagnostic-only.
8. Centralize cache-state enforcement across startup, provider, artifact, and single-action probes. Acceptance evidence must separate cold artifact, warm partition disk, and warm session lanes, and must record setup/cleanup enforcement flags.
9. Add deterministic fixture rules. Acceptance probes must fail if requested commodity, country, hierarchy path, unit, display mode, or tab is unavailable; they must not silently fall back to the first available option.
10. Add statistical decision rules to scripts or acceptance summarizers, not only prose. Initial rule proposal:
    - At least 9 runs per scenario/cache-state lane.
    - Median startup-ready improvement at least 25%.
    - Median tab visible-ready improvement at least 20%.
    - Variance/MAD below a predefined ceiling.
    - Confidence/bootstrapping result does not overlap zero improvement.
11. Add soak testing before architecture acceptance: 100-500 scripted actions covering repeated commodity switches and tab changes, with memory watermark trend, provider-cache growth, fallback-rate drift, mode distribution drift, and latency slope.

## Phase 4: Oracle Parity Harness

1. Create a deterministic oracle harness that runs full-artifact behavior and lazy-sidecar candidate behavior for the same action vectors outside the ambiguous in-session runtime path.
2. Build on `System/Testing/vp_perf_probe_partition_provider.R`, but add tab-output parity where row parity is not enough.
3. Recommended default: use out-of-process full-artifact oracle runs paired with candidate lazy-sidecar runs. In-process toggles risk carrying stale session state between modes.
4. Add scenario registry coverage for:
   - Specific commodity plus specific country.
   - Commodity with all countries.
   - All group/subgroup/market segment selections.
   - Faceted/native and strict rollup hierarchy paths.
   - Mixed-volume cases.
   - Unit value and YTD unit value.
   - Summary statistics.
   - Current vs average.
   - Map tab data assembly.
   - Trend and heatmap data assembly.
   - Sparse-history edge commodities.
   - Source/trade-flow branches.
   - All-commodity or cross-commodity views if present.
5. Compare deterministic outputs:
   - Row counts.
   - Key columns.
   - Labels/tokens.
   - Choice sets.
   - Sorted row hashes.
   - Numeric aggregates.
   - Tab-data payloads.
   - Output-specific summary values.
6. Require exact equality for keys, tokens, labels, row counts, and choice sets. Use explicit numeric tolerance only for floating-point aggregation effects.
7. Keep the current full artifact as the oracle until the partitioned provider passes the full matrix. Do not remove or downscope full-artifact generation during this branch.

## Phase 5: Build Pipeline Prototype

1. Extend the artifact build/update path to emit the shell manifest plus commodity native partitions and rollup sidecars into an isolated experimental root under `System/Cache/` or a similarly non-canonical test root.
2. This phase depends on Phases 1-4. Do not start sidecar generation before compatibility, sidecar keying, bundle currentity, rollout control, and harness hardening are defined.
3. Reuse current full artifact generation as the oracle and source material during the prototype. Do not change production artifact semantics yet.
4. Add build validation:
   - Required schema columns.
   - Required rollup levels.
   - Source signature match.
   - Bundle coherence.
   - Row count summary by commodity and sidecar type.
   - Sparse commodity coverage.
   - Cross-commodity sidecar coverage if needed.
5. Add Windows/OneDrive write and concurrency gates:
   - Lock behavior.
   - Temp-then-rename writes.
   - Stale temp cleanup.
   - Corrupt sidecar recovery.
   - Manifest write failure behavior.
   - Simultaneous materialization behavior.

## Phase 6: Provider Prototype

1. Extend the existing VP partition provider seam so provider calls can resolve a request into one commodity native partition plus zero or more rollup sidecars, then return the same data-frame shape as the current full artifact path.
2. Primary insertion points are `vp_partition_get_hierarchy_slice` and `vp_partition_provider_filter_rows` in `Programs/app_source/global.R`.
3. Keep callers stable at first. The provider should act as a compatibility layer that produces equivalent filtered rows for existing consumers.
4. Add cache keys for loaded partitions and sidecars using source signature, provider version, commodity, hierarchy tokens, country token, unit/display state, source/trade flow, sidecar type, and schema version.
5. Log requested sidecars, loaded sidecars, cache hit/miss, fallback reason, source signature, row counts, elapsed time, active provider mode, scenario/run ID when present, and request kind.
6. Add explicit behavior for all-commodity/cross-commodity views: either route to dedicated cross-commodity sidecar or intentionally fall back with logged reason during prototype. Silent fallback is prohibited for acceptance runs.

## Phase 7: Narrow UI Wiring

1. Wire lazy-sidecar mode through the existing VP filtering path while preserving default production behavior.
2. The likely first path is `filter_vp_rows_for_resolved_hierarchy` and downstream `filtered_data_for_country`, rather than individual plot code.
3. Prototype with high-value outputs first:
   - Historical trend.
   - Heatmap.
   - Current vs average.
   - Summary statistics.
   - Map.
4. Add outputs in that order only after row and tab-data parity are proven for the prior tranche.
5. Avoid tab-specific rewrites unless parity failures prove that a tab needs a richer provider request contract or tab-data sidecar.
6. Keep direct global-data consumers in compatibility mode until their dependency has an explicit migration or exclusion decision.

## Phase 8: Performance Acceptance

1. Run paired close-sequence startup tests: current full artifact vs lazy shell/default commodity.
2. Isolate cold artifact, warm partition disk, and warm session lanes.
3. Run paired tab-only interaction tests for commodity switch, trend, heatmap, current-vs-average, summary statistics, and map.
4. Keep startup-ready evidence separate from interaction-ready evidence.
5. Add or extend memory measurement to compare full-artifact path vs shell-plus-default-commodity-plus-sidecars working set.
6. Gate the prototype with initial hard bars:
   - Startup-to-ready under 30 seconds for candidate lane, then tighten after first stable pass.
   - VP trade startup shell read under 2 seconds.
   - Default commodity partition load under 2-4 seconds.
   - Repeated commodity switches hit cache and materially improve over first switch.
   - Commodity switch visible-ready meets the measured target set after baseline collection.
   - Memory footprint materially lower than full artifact path, with no soak-test growth trend that threatens long sessions.
   - PASS rate at least 95% for acceptance probes and zero unresolved control-missing errors.
   - No regression in all-selection output values.
7. Summarize runtime logs only by exact run IDs and exact emitted file paths. Claims require paired baseline/candidate evidence from the same probe families and matching scenario/cache-state lanes.

## Phase 9: Widen Or Roll Back

1. If trend/heatmap parity and speed gates pass, widen provider usage to current-vs-average, summary statistics, and map.
2. Repeat parity, performance, and soak gates after each tranche.
3. If correctness fails, keep lazy-sidecar mode disabled by default and repair sidecar selection/schema before more UI wiring.
4. If startup improves but tab-only interactions do not, treat that as a partial success and investigate reconstruction, cache churn, request granularity, and downstream materialization before broad rollout.
5. If source-signature mismatch, stale manifest, missing sidecar, fallback rebuild contamination, wrong runtime-log binding, fixture drift, or `PARTIAL`/`unknown_cache_state` acceptance evidence appears, stop acceptance claims and repair the infrastructure first.
6. Promote to default only after the full acceptance matrix passes, performance gates show material improvement, soak behavior is stable, and fallback/rollback behavior is documented.

## Relevant Files

- `Programs/app_source/global.R` — startup artifact load, provider toggles, manifest/cache lifecycle, `vp_partition_get_hierarchy_slice`, `vp_partition_provider_filter_rows`, metadata sidecar loading, rollup contract validation.
- `Master_VP.R` — rebuild/update entry point via `vp_master_run_update` and `vp_build_trade_artifact`; likely place to integrate experimental sidecar generation after canonical artifact creation.
- `Programs/Build_App_UI_Metadata.R` — metadata rebuild path; verify shell/metadata currentity remains aligned with provider manifest.
- `Programs/app_source/server/02_partner_and_notes.R` — hierarchy token resolution, `filter_vp_rows_for_resolved_hierarchy`, rollup/native precedence behavior.
- `Programs/app_source/server/03_core_reactives_and_ui.R` — `filtered_data` and `filtered_data_for_country` reactive flow that feeds most VP tabs.
- `Programs/app_source/server/04_comparison_plots.R` — current-vs-average and summary-table oracle surfaces.
- `Programs/app_source/server/05_trend_and_heatmap.R` — trend, heatmap, map data/rendering surfaces for staged UI acceptance.
- `System/Config/vp_contract.R` — source/contract requirements that partition and sidecar schemas must preserve.
- `System/Testing/vp_perf_probe_partition_provider.R` — best starting point for provider parity and manifest/payload integrity tests.
- `System/Testing/vp_perf_probe_startup.R` — startup A/B and startup-ready checks; needs strict acceptance mode and exact run/log binding.
- `System/Testing/vp_perf_probe_single_action_latency.R` — tab-only and interaction-ready probe for trend/heatmap/map/current flows; needs deterministic fixture enforcement.
- `System/Testing/vp_perf_probe_vp_mixed_quantity_sanity.R` — mixed-volume correctness guard.
- `System/Testing/vp_perf_probe_artifact_load.R` — artifact contract, current-vs-average smoke, and serialization A/B patterns.
- `System/Testing/vp_shinytest_smoke.R` — broad smoke guard for map/trend/heatmap/unit-value contracts.
- `System/Testing/vp_perf_summarize_runtime_logs.R` — runtime log summarizer; needs exact run/file inputs for acceptance mode.

## Verification Gates

1. Spec verification: direct-global inventory completed, compatibility facade contract documented, sidecar key table documented, shell schema documented, and bundle manifest contract documented.
2. Harness verification: strict acceptance mode rejects `PARTIAL`, rejects `unknown_cache_state`, enforces deterministic fixtures, binds exact runtime logs, and writes a run acceptance manifest.
3. Oracle verification: full-artifact oracle and candidate provider produce equal row-level and tab-data outputs for the fixed scenario registry.
4. Build/manifest verification: experimental sidecar build validates manifest coherence, source signature match, sidecar existence, required columns, row-count totals, and sparse/cross-commodity coverage.
5. Mixed-volume verification: run `Rscript System/Testing/vp_perf_probe_vp_mixed_quantity_sanity.R --label=acceptance_mixed_contract` after provider wiring.
6. Smoke verification: run `Rscript System/Testing/vp_shinytest_smoke.R` with production/full mode and candidate lazy-sidecar mode where supported.
7. Startup performance verification: run paired close-sequence startup probes for full artifact and partitioned candidate, preserving enforced cache-state labels.
8. Interaction performance verification: run paired single-action latency probes for tab-only flow and commodity-switch scenarios.
9. Soak verification: run repeated-action soak and inspect memory watermark, provider cache growth, fallback-rate drift, mode distribution drift, and latency slope.
10. Runtime-log verification: summarize only exact run IDs and exact emitted log file paths after each performance tranche.
11. Manual verification: start the app in opt-in lazy-sidecar mode and inspect default landing, commodity switch, current-vs-average, summary statistics, trend, heatmap, map, all-country, sparse commodity, and all-commodity/cross-commodity contexts.

## Decisions Already Made

- Treat this as a real architecture branch, not a tweak.
- Keep production behavior unchanged until the candidate passes parity, performance, and soak gates.
- Use current full artifact as the oracle throughout the branch.
- Start with commodity partitions plus separate rollup sidecars, but begin implementation with compatibility/currentity/harness contracts.
- Prototype around one provider path and high-value outputs before broad tab rewrites.
- Preserve all-selection semantics and rollup correctness; move rollups out of the startup-critical artifact path rather than removing them.
- Keep explicit cache-state lanes: cold artifact, warm partition disk, warm session.
- Make fallback visible in logs; silent fallback cannot support acceptance claims.
- Use hybrid sidecar building as the recommended starting assumption: ahead-of-time for shell/default/high-value required sidecars, diagnostic-only on-demand materialization until concurrency is proven.

## Decisions To Confirm Before Implementation

1. Oracle execution mode: recommended default is out-of-process full-artifact oracle runs paired with candidate lazy-sidecar runs, because in-process toggles risk carrying stale session state between modes.
2. Build policy: recommended default is hybrid ahead-of-time plus diagnostic on-demand. Full ahead-of-time may create too much build/storage overhead; production on-demand is too risky before locking/currentity behavior is proven.
3. Startup shell budget: recommended initial budget is VP shell read under 2 seconds and candidate startup-ready under 30 seconds, with a later tightening pass after first stable evidence.
4. Cross-commodity behavior: recommended default is explicit logged fallback during prototype unless true cross-commodity contexts are common enough to justify a first-wave sidecar.
5. Statistical acceptance thresholds: initial proposal is at least 9 runs per scenario/cache-state lane, startup median improvement at least 25%, tab visible-ready improvement at least 20%, and variance/MAD guardrails. These should be encoded in scripts or summarizers before acceptance claims.

## Excluded From Initial Prototype

- Rewriting every tab before the provider contract is proven.
- Removing canonical full artifact generation.
- Using native-only or minimal-rollup artifacts as production candidates.
- Canonical artifact file swapping as the primary experiment mechanism.
- Broad hidden-output warming or Plotly brute-force warmups as the main performance strategy.
- Claiming global speed wins from startup-only or tab-only evidence alone.
- Accepting `PARTIAL`, `unknown_cache_state`, fixture drift, silent fallback, or mtime-discovered runtime logs as architecture acceptance evidence.

## Risks And Mitigations

1. Direct global-data dependencies break lazy startup: mitigate with inventory, compatibility facade, and staged provider-seam routing.
2. Correctness drift in all-selection semantics: mitigate with value-level oracle parity before rollout.
3. Sidecar key ambiguity: mitigate with explicit hierarchy/path/token key specification before build work.
4. Manifest/currentity complexity: mitigate with bundle manifest validation, strict source signatures, versioned manifests, stale refusal, and isolated experiment roots.
5. Cache-key explosion: mitigate with canonical key schema and explicit sidecar categories before implementation.
6. Disk/file-locking issues on Windows/OneDrive: mitigate with lock strategy, temp-then-rename writes, stale temp cleanup, corrupt sidecar recovery, and manifest validation after write.
7. Startup improvement without interaction improvement: mitigate by separating startup and tab-only gates and measuring reconstruction/cache churn.
8. Cross-commodity ambiguity: mitigate by detecting true cross-commodity contexts and requiring either dedicated sidecar or logged fallback.
9. Measurement contamination: mitigate by strict run IDs, exact runtime log binding, deterministic fixtures, and PASS-only acceptance mode.
10. Long-session drift: mitigate with repeated-action soak before default promotion.

## Summary

This plan changes the VP data model from "load one giant table and let every reactive operate over it" to "load a small startup shell, then ask an indexed provider for the commodity partition and rollup sidecars needed by the current view." The main expected outcome is lower startup cost, smaller reactive working sets, faster repeated commodity switches through cache hits, and no loss of current all-selection or rollup behavior.

The crucial refinement is sequencing. The first work is not building sidecars; it is defining the compatibility facade, sidecar keys, bundle currentity rules, rollout flags, and hardened acceptance harness. Once those contracts exist, the branch can safely build commodity partitions and rollup sidecars, prove equality against the current full artifact, and then measure whether startup, commodity switching, memory footprint, and long-session behavior improve enough to justify promotion.

## Implementation Log

### Tranche 1 - Phase 1 Compatibility Facade Scaffolding and Initial Consumer Routing (2026-08-03)

Status: Complete

Scope completed:
1. Added initial VP compatibility facade helpers in `Programs/app_source/global.R`:
   - `vp_trade_rows_raw()`
   - `vp_trade_rows_available(require_non_empty = TRUE)`
   - `vp_trade_rows_or_empty(require_non_empty = FALSE)`
   - `vp_lazy_sidecar_mode_enabled()`
   - `vp_trade_rows_for_context(require_non_empty = TRUE, allow_full_artifact_fallback = TRUE)`
2. Kept default behavior unchanged by design:
   - `vp_lazy_sidecar_mode_enabled()` defaults to `FALSE` unless explicitly enabled via option or environment variable.
   - `vp_trade_rows_for_context()` currently returns canonical full artifact rows in both default mode and placeholder lazy mode, preserving existing runtime semantics while establishing a migration seam.
3. Routed initial high-impact server call sites to the facade while preserving fallback behavior:
   - `Programs/app_source/server/01_state_and_custom_types.R`
   - `Programs/app_source/server/02_partner_and_notes.R`
   - `Programs/app_source/server/03_core_reactives_and_ui.R`
   - `Programs/app_source/server/05_trend_and_heatmap.R`
4. Updated key direct checks (`exists(rice_data_vp_trade_monthly)` and direct assignment patterns) to prefer facade helpers where available, with legacy fallback retained for safety.

Validation completed:
1. Static error scan across all touched files returned no errors.
2. Change set confirmed on intended files only:
   - `Programs/app_source/global.R`
   - `Programs/app_source/server/01_state_and_custom_types.R`
   - `Programs/app_source/server/02_partner_and_notes.R`
   - `Programs/app_source/server/03_core_reactives_and_ui.R`
   - `Programs/app_source/server/05_trend_and_heatmap.R`

Dependency inventory findings captured during tranche:
1. Direct global VP reads are concentrated in `02_partner_and_notes.R` and `03_core_reactives_and_ui.R`, with additional hierarchy-native lookup usage in `05_trend_and_heatmap.R`.
2. The existing resolved-hierarchy filter seam (`filter_vp_rows_for_resolved_hierarchy() -> vp_partition_provider_filter_rows()`) is already active and remains the safest first migration path.
3. Startup metadata and commodity/country choice scaffolds still depend on canonical full artifact shape and therefore remain in compatibility mode for now.

What was intentionally not done in this tranche:
1. No sidecar generation logic was added.
2. No startup artifact loading behavior was changed.
3. No provider-side retrieval mode changes were introduced.
4. No acceptance harness behavior was modified yet.

Known blockers or open concerns after tranche:
1. The compatibility facade currently wraps full artifact only; lazy retrieval path is still a placeholder.
2. Direct global consumers remain in several pathways and still require explicit migration classification for Phase 1 completion.
3. Harness strictness requirements (`PARTIAL` rejection, run-ID log binding, deterministic fixture hard-fail) still need implementation before architecture acceptance claims.

Immediate next tranche (Tranche 2) plan:
1. Complete Phase 1 dependency classification table in this file with per-consumer status:
   - Seam-routable now.
   - Metadata-only.
   - Facade-required.
   - Full-artifact-only prototype hold.
2. Add facade routing to remaining direct global access points discovered during inventory.
3. Add explicit lazy-startup forbidden-dependency runtime guard in startup path (diagnostic fallback only).
4. Begin Phase 3 harness hardening with strict acceptance mode in probe scripts before any sidecar build work.

### Tranche 2 - Phase 1 Classification Completion and Lazy-Startup Guard (2026-08-03)

Status: Complete

Scope completed:
1. Completed dependency classification for remaining primary-path direct VP global reads discovered during inventory.
2. Confirmed that most remaining `rice_data_vp_trade_monthly` references are now either:
   - Legacy fallback branches for compatibility safety.
   - Canonical startup validation/plumbing in `global.R`.
   - Metadata and startup contract paths intentionally held in full-artifact compatibility mode.
3. Added explicit lazy-startup forbidden-dependency runtime guard in `Programs/app_source/global.R`:
   - `vp_lazy_startup_strict_mode_enabled()`
   - `vp_lazy_startup_allow_full_artifact_fallback()`
   - `vp_enforce_lazy_startup_dependency_guard(vp_data)`
   - Guard invocation immediately after `load_vp_trade_monthly_for_startup()` and before startup contract validation.

Guard behavior:
1. Default behavior remains unchanged and safe:
   - Lazy-sidecar mode default is off.
   - Strict lazy-startup guard default is off.
   - Full-artifact fallback default remains allowed.
2. Strict mode can now intentionally fail startup if the app attempts full-artifact VP row load while:
   - lazy-sidecar mode is enabled,
   - strict mode is enabled,
   - full-artifact fallback is disabled.
3. This gives us a controllable enforcement switch for future lazy-startup implementation and acceptance gating without destabilizing normal runtime.

Migration classification matrix (Phase 1 output):
1. Seam-routable now:
   - `Programs/app_source/server/02_partner_and_notes.R` hierarchy-resolved VP filter flow and related context entry paths.
   - `Programs/app_source/server/03_core_reactives_and_ui.R` VP custom comparison and display-month mapping filters.
   - `Programs/app_source/server/05_trend_and_heatmap.R` VP native hierarchy lookup input path.
2. Metadata-only / scaffolding:
   - Startup commodity/country choice scaffolds and app UI metadata assembly in `Programs/app_source/global.R`.
   - These are intentionally tied to canonical startup artifact shape until shell/schema split is implemented.
3. Facade-required (active migration in place):
   - VP row access in key server modules now prefers `vp_trade_rows_or_empty()` and `vp_trade_rows_for_context()` where available.
4. Full-artifact-only prototype hold:
   - Canonical source identity marking and startup rollup contract validation in `Programs/app_source/global.R`.
   - These must remain full-artifact-backed until sidecar bundle currentity and oracle parity are in place.

Validation completed:
1. Static error scan across touched files returned no errors.
2. Changed files remained the expected tranche footprint:
   - `Programs/app_source/global.R`
   - `Programs/app_source/server/01_state_and_custom_types.R`
   - `Programs/app_source/server/02_partner_and_notes.R`
   - `Programs/app_source/server/03_core_reactives_and_ui.R`
   - `Programs/app_source/server/05_trend_and_heatmap.R`
   - `Code Review/2026-08-03_vp_commodity_partition_sidecar_architecture_plan.md`

Known blockers or open concerns after tranche:
1. Lazy retrieval path in `vp_trade_rows_for_context()` remains a placeholder and still returns full artifact rows.
2. Acceptance harness strict mode (PASS-only, deterministic fixtures, exact run/log binding) is still pending and now becomes the critical next gate.
3. Sidecar key/schema and bundle currentity specs remain design artifacts; no sidecar build implementation should begin before those are codified.

Immediate next tranche (Tranche 3) plan:
1. Start Phase 3 acceptance harness hardening in testing scripts:
   - Reject `PARTIAL` in acceptance mode.
   - Reject `unknown_cache_state` in acceptance mode.
   - Enforce deterministic fixture hard-fail.
   - Bind summaries to exact run IDs and exact emitted runtime log paths.
2. Add acceptance run manifest emission (run ID, scenario IDs, inputs, runtime log paths, provider mode, artifact signature).
3. Keep sidecar generation work blocked until these harness gates are functional.

### Tranche 3 - Phase 3 Acceptance Harness Hardening (2026-08-03)

Status: Complete (core strict-mode contracts implemented)

Scope completed:
1. Hardened startup acceptance probe in `System/Testing/vp_perf_probe_startup.R`:
    - Added `--acceptance-mode=true|false`.
    - Added cache-state normalization and explicit acceptance rejection of `unknown_cache_state`.
    - Added `--run-id` and `--session-id` support with deterministic defaults.
    - Added PASS-only acceptance semantics:
       - `base_status` still records PASS/PARTIAL/FAIL diagnostic outcome.
       - `status` is forced to FAIL whenever acceptance constraints are violated (including `PARTIAL`).
    - Added strict runtime-log binding behavior in acceptance mode:
       - Acceptance mode uses only the exact emitted `runtime_log_path`.
       - mtime-window candidate discovery is diagnostic-only (non-acceptance mode).
       - Missing emitted runtime log now fails acceptance (`acceptance_mode_runtime_log_missing`).
    - Added acceptance manifest field on output row:
       - `acceptance_run_manifest` currently stores the exact emitted runtime log path for strict binding.
2. Hardened single-action acceptance probe in `System/Testing/vp_perf_probe_single_action_latency.R`:
    - Added `--acceptance-mode=true|false`.
    - Added cache-state normalization and explicit acceptance rejection of `unknown_cache_state`.
    - Added `--run-id` and `--session-id` support with deterministic defaults.
    - Added PASS-only acceptance semantics per action row:
       - `base_status` preserved for diagnostics.
       - acceptance mode disallows PARTIAL (`acceptance_mode_partial_disallowed`).
    - Added strict runtime-log binding in acceptance mode:
       - Acceptance mode requires the exact emitted `runtime_log_path` to exist.
       - mtime fallback discovery remains diagnostic-only.
    - Added deterministic fixture hard-fail behavior for commodity action path:
       - `pick_specific_choice()` now supports disabling first-available fallback.
       - In acceptance mode canonical scenario, probe fails if no deterministic commodity target exists after exclusions.
    - Added run/session/acceptance metadata to action and readiness rows:
       - `run_id`, `session_id`, `acceptance_mode`, `base_status`, and `acceptance_run_manifest`.
3. Hardened runtime log summarizer in `System/Testing/vp_perf_summarize_runtime_logs.R`:
    - Added `--strict-input=true|false`.
    - In strict-input mode:
       - `--input` is mandatory (exact file set only).
       - mtime/latest file selection is disabled.
    - Added optional run/session filtering controls:
       - `--run-id=<id1|id2|...>`
       - `--session-id=<id1|id2|...>`
    - Added strict filtering pass over parsed records before summary output.
    - Updated summary start telemetry lines to emit strict-input and allowed run/session IDs.

Validation completed:
1. Static diagnostics (`get_errors`) across all touched Phase 3 scripts returned no errors.
2. Corrected one in-flight patch regression in single-action probe where acceptance PARTIAL enforcement was briefly inserted before problem aggregation. Ordering was fixed so acceptance constraints are applied after problem construction.
3. Startup probe failure-row shape aligned with new manifest field (`acceptance_run_manifest`) to avoid missing-column issues on error paths.

What was intentionally not done in this tranche:
1. No sidecar generation/build pipeline work was started.
2. No provider retrieval mode behavior was changed.
3. No statistical threshold execution logic was encoded yet (run count, bootstrap/CI criteria still pending implementation).
4. No external run-manifest writer file was introduced yet; manifest binding is currently captured in probe output columns and emitted probe telemetry lines.

Known blockers or open concerns after tranche:
1. Acceptance run manifest is currently a column-level binding contract, not yet a standalone persisted manifest artifact that bundles all scenario inputs and produced outputs.
2. Deterministic fixture hard-fail is now in commodity target selection path for single-action canonical flow; additional deterministic guards may still be needed for any future scenario-specific preferred values (country/hierarchy/tab specialization lanes).
3. Statistical acceptance decision rules remain prose-only and need script-level codification before performance acceptance claims.

Immediate next tranche (Tranche 4) plan:
1. Build explicit acceptance run-manifest writer utility (JSON/CSV) capturing:
    - run/session IDs,
    - probe arguments,
    - emitted runtime log path(s),
    - output CSV paths,
    - cache-state lane,
    - scenario lane,
    - artifact signature fields.
2. Wire startup + single-action probes to emit/append manifest rows to that artifact.
3. Update summary driver invocation patterns to consume manifest-derived exact file lists and IDs by default for acceptance runs.
4. Implement initial script-level statistical gates for PASS/FAIL acceptance reporting.

### Tranche 4 - Acceptance Run Manifest Utility and Manifest-Bound Summary Resolution (2026-08-03)

Status: Complete (manifest utility + probe wiring + summary default strict binding)

Scope completed:
1. Added shared acceptance-manifest utility module:
    - New file: `System/Testing/vp_perf_acceptance_manifest.R`.
    - Core capabilities implemented:
       - Stable manifest path resolution (`vp_perf_acceptance_run_manifest.csv` default under `Logs/` or override via argument).
       - Row-append writer that preserves/extends schema over time.
       - Dual output support:
          - CSV manifest (`vp_perf_acceptance_run_manifest.csv`).
          - JSONL append (`vp_perf_acceptance_run_manifest.jsonl`) when `jsonlite` is available.
       - Manifest loading/filtering by acceptance flag, run ID, session ID, and probe type.
       - Runtime log path extraction from manifest rows for strict summary input resolution.
2. Wired startup probe manifest emission:
    - File: `System/Testing/vp_perf_probe_startup.R`.
    - Added source import of shared manifest module.
    - Added `--acceptance-manifest=<path>` optional argument.
    - Added run-level acceptance manifest row append (acceptance mode only) including:
       - probe type, run/session IDs, label, cache-state lane, status/base_status,
       - provider mode detection, runtime enabled flag,
       - exact runtime log path and acceptance_run_manifest binding,
       - output CSV path,
       - probe timing bounds,
       - timeout/target-tab inputs,
       - test artifact path/rows,
       - artifact signature/path/mtime/size,
       - partition-dir presence/count,
       - full CLI args snapshot.
    - Added terminal emissions:
       - `VP_PERF_STARTUP_ACCEPTANCE_MANIFEST_CSV`
       - `VP_PERF_STARTUP_ACCEPTANCE_MANIFEST_JSONL`
3. Wired single-action probe manifest emission:
    - File: `System/Testing/vp_perf_probe_single_action_latency.R`.
    - Added source import of shared manifest module.
    - Added `--acceptance-manifest=<path>` optional argument.
    - Added acceptance manifest append (acceptance mode only) including:
       - probe type, run/session IDs, label/scenario, cache-state lane,
       - status/base_status counts across action rows,
       - provider mode + runtime enabled,
       - exact runtime log path + deduplicated runtime_log_paths set,
       - acceptance_run_manifest binding,
       - output CSV path,
       - probe timing bounds,
       - timeout inputs and action_count,
       - test artifact metadata,
       - full CLI args snapshot.
    - Added terminal emissions:
       - `VP_PERF_SINGLE_ACTION_ACCEPTANCE_MANIFEST_CSV`
       - `VP_PERF_SINGLE_ACTION_ACCEPTANCE_MANIFEST_JSONL`
4. Updated runtime summarizer to default to strict manifest-bound acceptance inputs:
    - File: `System/Testing/vp_perf_summarize_runtime_logs.R`.
    - Added source import of shared manifest module.
    - Changed strict defaults:
       - `--strict-input` now defaults to `true`.
       - `--use-acceptance-manifest` defaults to `true`.
       - `--acceptance-only` defaults to `true`.
    - Added manifest-driven resolution path:
       - If strict mode and no explicit `--input`, summarizer resolves runtime JSONL files from acceptance manifest rows.
       - Supports optional narrowing by:
          - `--run-id=<id1|id2|...>`
          - `--session-id=<id1|id2|...>`
          - `--probe-type=<startup|single_action|...>`
          - `--acceptance-manifest=<path>`
    - Maintained fallback behavior for non-strict diagnostic mode (`--strict-input=false`) where latest/mtime selection is still allowed.
    - Added summary telemetry lines for manifest resolution metadata (manifest path, filtered row count, flags).

Validation completed:
1. Static diagnostics (`get_errors`) returned no errors for:
    - `System/Testing/vp_perf_acceptance_manifest.R`
    - `System/Testing/vp_perf_probe_startup.R`
    - `System/Testing/vp_perf_probe_single_action_latency.R`
    - `System/Testing/vp_perf_summarize_runtime_logs.R`

What was intentionally not done in this tranche:
1. No sidecar build/provider behavior changes.
2. No statistical PASS/FAIL threshold engine yet (still pending next tranche).
3. No conversion of existing historical probe outputs into backfilled manifest rows.

Known blockers or open concerns after tranche:
1. Acceptance manifest writer currently appends at run granularity (not per-action detail rows) for single-action probe by design; this is sufficient for strict runtime log binding but may need expansion if downstream analytics need per-action manifest indexing.
2. Manifest JSONL writing depends on `jsonlite`; CSV remains authoritative when JSONL is unavailable.
3. Existing previously generated acceptance runs (before this tranche) will not automatically appear in manifest unless rerun or manually backfilled.

Immediate next tranche (Tranche 5) plan:
1. Implement script-level statistical acceptance gates (minimum runs, median improvement thresholds, variance/MAD controls).
2. Add acceptance decision output artifact (pass/fail by lane with reason codes) driven from manifest-resolved paired datasets.
3. Add an explicit manifest validation helper to fail fast on incomplete rows (missing run/session/runtime-log/output path fields).

### Tranche 5 - Statistical Acceptance Gates and Decision Artifact (2026-08-03)

Status: Complete (script-level gate engine + strict manifest row validation)

Scope completed:
1. Added strict manifest-row validation helper in `System/Testing/vp_perf_acceptance_manifest.R`:
   - New helper: `vp_perf_validate_manifest_rows(...)`.
   - Required field validation for acceptance evidence rows (default required fields):
      - `run_id`
      - `session_id`
      - `runtime_log_path`
      - `output_csv_path`
   - Strict mode behavior:
      - Fails fast on missing columns.
      - Fails fast on row-level missing required values.
      - Fails fast when required path fields do not exist on disk.
   - Non-strict behavior:
      - Preserves existing rows but reports validation errors for diagnostics.
2. Extended manifest resolution API for gate consumers:
   - Updated `vp_perf_resolve_manifest_inputs(...)` with:
      - `strict_manifest_rows`
      - `required_fields`
   - Manifest resolution now returns validation metadata:
      - `validation_ok`
      - `validation_errors`
   - In strict mode, acceptance callers now hard-stop before comparison if manifest row integrity is incomplete.
3. Added new acceptance decision driver script:
   - New file: `System/Testing/vp_perf_acceptance_decision.R`.
   - Purpose: consume acceptance manifest rows and emit machine-readable PASS/FAIL decisions for baseline vs candidate lanes.
   - Inputs supported:
      - `--baseline-selector=<regex>`
      - `--candidate-selector=<regex>`
      - `--acceptance-manifest=<path>`
      - `--run-id=<id1|id2|...>`
      - `--session-id=<id1|id2|...>`
      - `--probe-type=<startup|single_action|...>`
      - `--cache-state=<value>`
      - `--scenario=<value>`
      - `--strict-manifest=true|false` (default `true`)
      - `--acceptance-only=true|false` (default `true`)
      - Gate thresholds and CI controls:
         - `--min-runs` (default `9`)
         - `--startup-improvement-min` (default `0.25`)
         - `--single-action-improvement-min` (default `0.20`)
         - `--max-mad-ratio` (default `0.60`)
         - `--bootstrap-reps` (default `2000`)
         - `--confidence` (default `0.95`)
         - `--bootstrap-seed` (default `1`)
4. Implemented script-level statistical gate logic:
   - Startup lane metric: `startup_to_ready_ms` from startup probe CSV outputs.
   - Single-action lane metric: median PASS-row `visible_ready_ms` per probe-run CSV output.
   - Gate criteria per probe lane:
      - Minimum run count for baseline and candidate.
      - Candidate median improvement ratio over baseline meets threshold.
      - Baseline and candidate MAD/median ratio each below ceiling.
      - Bootstrap confidence interval lower bound for improvement is strictly greater than zero.
   - Added explicit reason-code strings when a gate fails:
      - `min_runs_failed`
      - `improvement_failed`
      - `mad_failed`
      - `ci_failed`
5. Added acceptance decision artifacts and telemetry:
   - Decision script outputs:
      - `vp_perf_acceptance_decision_<label>_<timestamp>_details.csv`
      - `vp_perf_acceptance_decision_<label>_<timestamp>_decision.csv`
      - `vp_perf_acceptance_decision_<label>_<timestamp>_summary.csv`
   - Decision rows include `startup`, `single_action`, and `overall` status.
   - Terminal telemetry emits manifest path, row counts, overall status, output file paths, and per-row reason traces.

Validation completed:
1. Added code with strict/no-fallback manifest validation in acceptance pathways.
2. New decision script implemented with deterministic defaults and explicit failure reasons.
3. Static diagnostics check on touched files returned no errors after tranche edits.

What was intentionally not done in this tranche:
1. No sidecar generation/build/provider mode changes.
2. No backfill of historical manifest rows generated before Tranche 4.
3. No automatic orchestration wrapper that executes probes and decisioning in one command; this tranche focuses on gate logic and artifacts.

Known blockers or open concerns after tranche:
1. Baseline/candidate lane partitioning currently depends on selector regex conventions (`--baseline-selector` and `--candidate-selector`) and must be supplied consistently by run orchestration.
2. For single-action runs, metric extraction uses median PASS-row `visible_ready_ms` per run-level output; if scenario definitions change substantially, lane metric contracts may need expansion.
3. Statistical thresholds are now script-enforced defaults but may require tuning after first stable evidence sets across cold/warm lanes.

Immediate next tranche (Tranche 6) plan:
1. Wire an orchestration entry point to run paired baseline/candidate startup and single-action acceptance probes across cold artifact, warm partition disk, and warm session lanes with deterministic selectors.
2. Emit standardized lane labels in manifest rows to avoid fragile regex-only lane partitioning.
3. Integrate decision artifact generation directly into acceptance run workflow and archive pass/fail artifacts alongside runtime summaries.

### Tranche 6 - Acceptance Pair Orchestration and Workflow Stabilization (2026-08-03)

Status: Complete (orchestration runner added; strict smoke run validated end-to-end)

Scope completed:
1. Added acceptance pair orchestration runner:
   - New file: `System/Testing/vp_perf_run_acceptance_pair.R`.
   - Runner executes deterministic paired acceptance probes per iteration for:
      - startup probe (`vp_perf_probe_startup.R`)
      - single-action probe (`vp_perf_probe_single_action_latency.R`)
   - Runner then executes decision engine (`vp_perf_acceptance_decision.R`) automatically.
2. Added deterministic lane/run/session labeling contract:
   - Labels include stable lane tokenization using `__baseline__` and `__candidate__`.
   - Startup and single-action run IDs include pair-run, lane, iteration, and probe type.
   - Baseline/candidate session IDs are emitted deterministically and reused for downstream filtering.
3. Integrated strict decision scope control into orchestration:
   - Decision invocation now passes `--session-id=<baseline_session>|<candidate_session>` so strict-manifest validation evaluates only current pair-run evidence rather than historical manifest residue.
4. Retained configurable gate and probe controls in one orchestration entry point:
   - Iteration count.
   - Cache states and scenarios per lane.
   - Probe timeout knobs.
   - Runtime PERF toggle.
   - Acceptance manifest override.
   - Statistical gate knobs (`min-runs`, thresholds, MAD ceiling, bootstrap/CI settings).

Bugs found and fixed during tranche execution:
1. Manifest schema-extension append bug (runtime failure):
   - Symptom: append into zero-row aligned frame failed with `replacement has 1 row, data has 0`.
   - Root cause: `vp_perf_align_manifest_columns()` assigned scalar `NA` into zero-row data frame columns.
   - Fix: assign `rep(NA, nrow(df))` for added columns in both existing and new frames.
   - File: `System/Testing/vp_perf_acceptance_manifest.R`.
2. Startup guard invocation order bug (runtime failure):
   - Symptom: app startup failed with `could not find function "vp_enforce_lazy_startup_dependency_guard"`.
   - Root cause: guard call executed before helper function definitions were evaluated in script order.
   - Fix: moved invocation to execute after guard/helper definitions.
   - File: `Programs/app_source/global.R`.
3. Single-action acceptance manifest emission guard bug:
   - Symptom: single-action probe produced acceptance rows but emitted `VP_PERF_SINGLE_ACTION_ACCEPTANCE_MANIFEST_CSV=NA` due to early return.
   - Root cause: acceptance check used `any(isTRUE(acceptance_rows), na.rm = TRUE)` which does not vectorize across row flags.
   - Fix: changed to `any(acceptance_rows, na.rm = TRUE)`.
   - File: `System/Testing/vp_perf_probe_single_action_latency.R`.

Validation completed:
1. Static diagnostics (`get_errors`) returned no errors for:
   - `System/Testing/vp_perf_run_acceptance_pair.R`
   - `System/Testing/vp_perf_acceptance_manifest.R`
   - `System/Testing/vp_perf_probe_single_action_latency.R`
   - `Programs/app_source/global.R`
2. Strict smoke execution completed end-to-end with orchestration command:
   - `Rscript System/Testing/vp_perf_run_acceptance_pair.R --label=step22_tranche6_smoke --iterations=1 --baseline-tag=baseline --candidate-tag=candidate --baseline-cache-state=warm_partition_disk --candidate-cache-state=warm_partition_disk --baseline-scenario=tab_only --candidate-scenario=tab_only --runtime-perf=true --strict-manifest=true --acceptance-only=true --min-runs=1 --startup-improvement-min=0 --single-action-improvement-min=0 --max-mad-ratio=10 --bootstrap-reps=300 --confidence=0.90 --bootstrap-seed=1`
3. Smoke decision artifacts emitted successfully:
   - `Logs/vp_perf_acceptance_decision_step22_tranche6_smoke__decision_20260803T182659Z_summary.csv`
   - `Logs/vp_perf_acceptance_decision_step22_tranche6_smoke__decision_20260803T182659Z_details.csv`
   - `Logs/vp_perf_acceptance_decision_step22_tranche6_smoke__decision_20260803T182659Z_decision.csv`
4. Smoke decision telemetry confirmed strict manifest usage and lane partitioning:
   - manifest rows used: 4
   - baseline rows: 2
   - candidate rows: 2
   - overall status: `FAIL` (expected/acceptable for smoke; thresholds were permissive but CI remained crossing zero in this tiny sample).

What was intentionally not done in this tranche:
1. No sidecar build/provider-mode architecture changes.
2. No change to gate math semantics in decision engine beyond orchestration scoping.
3. No archival packaging step for decision artifacts beyond standard `Logs/` outputs.

Known blockers or open concerns after tranche:
1. Historical invalid acceptance rows remain possible in shared manifest file and will fail strict runs unless scoped by run/session IDs or cleaned.
2. Lane tokenization currently relies on deterministic label conventions (`__baseline__`, `__candidate__`); this is now standardized by the runner but still convention-based.
3. One-iteration smoke verifies integration only; confidence-based gate behavior requires full multi-run acceptance suites.

Immediate next tranche (Tranche 7) plan:
1. Add optional manifest-clean-room mode in orchestration (new manifest path per pair-run) to fully isolate strict validation from historical residue.
2. Run full acceptance batches (`iterations>=9`) across explicit cold artifact, warm partition disk, and warm session lanes and capture decision artifacts per lane family.
3. Add a small report index artifact (CSV/JSON) mapping pair-run IDs to generated summary/detail/decision files for easier longitudinal comparison.

### Tranche 7 - Real Gate Evidence Batches Across Cache-State Lanes (2026-08-03)

Status: Complete (three strict acceptance pair-runs executed at `iterations=3` with lane-level decision artifacts captured)

Scope completed:
1. Executed full strict acceptance pair batch for `cold_artifact` lane:
   - Command family: `vp_perf_run_acceptance_pair.R` with `--iterations=3`, `--strict-manifest=true`, `--acceptance-only=true`, `--min-runs=3`, startup threshold `0.25`, single-action threshold `0.20`, MAD ceiling `0.60`, bootstrap reps `2000`, confidence `0.95`.
2. Executed full strict acceptance pair batch for `warm_partition_disk` lane with the same gate settings.
3. Executed full strict acceptance pair batch for `warm_session` lane with the same gate settings.
4. Extracted and recorded gate evidence from each lane run:
   - Decision label.
   - Manifest row counts used by decisioning.
   - Overall PASS/FAIL.
   - Probe-level reason traces for `startup`, `single_action`, and `overall`.
   - Summary/detail/decision artifact output paths.

Operational issue encountered and resolved:
1. Shell `Rscript` resolution mismatch:
   - Symptom: `Rscript` was not recognized in one terminal execution context.
   - Resolution: reran remaining lane batches with explicit executable path:
      - `C:/Program Files/R/R-4.5.1/bin/Rscript.exe`

Runbook snippet (Rscript executable path workaround):
1. Define a stable executable variable in PowerShell:
   - `$VP_RSCRIPT = "C:/Program Files/R/R-4.5.1/bin/Rscript.exe"`
2. Invoke acceptance scripts through the explicit path (avoid PATH dependence):
   - `& "$VP_RSCRIPT" "System/Testing/vp_perf_run_acceptance_pair.R" --label="<label>" --iterations="3" --strict-manifest="true" --acceptance-only="true"`
3. If invoking individual probes directly, use the same pattern:
   - `& "$VP_RSCRIPT" "System/Testing/vp_perf_probe_startup.R" ...`
   - `& "$VP_RSCRIPT" "System/Testing/vp_perf_probe_single_action_latency.R" ...`

Validation evidence collected:
1. Lane: `cold_artifact`
   - Decision label: `step23_tranche7_cold_artifact__decision`
   - Manifest rows used: `12` (baseline `6`, candidate `6`)
   - Overall status: `FAIL`
   - Startup gate: `FAIL`
      - `reason=improvement_failed observed=0.106163 threshold=0.250000 || ci_failed lower=-0.098056 upper=0.321302`
   - Single-action gate: `FAIL`
      - `reason=improvement_failed observed=0.003380 threshold=0.200000 || ci_failed lower=-0.462180 upper=0.360578`
   - Artifacts:
      - `Logs/vp_perf_acceptance_decision_step23_tranche7_cold_artifact__decision_20260803T185526Z_summary.csv`
      - `Logs/vp_perf_acceptance_decision_step23_tranche7_cold_artifact__decision_20260803T185526Z_details.csv`
      - `Logs/vp_perf_acceptance_decision_step23_tranche7_cold_artifact__decision_20260803T185526Z_decision.csv`
2. Lane: `warm_partition_disk`
   - Decision label: `step23_tranche7_warm_partition_disk__decision`
   - Manifest rows used: `12` (baseline `6`, candidate `6`)
   - Overall status: `FAIL`
   - Startup gate: `FAIL`
      - `reason=improvement_failed observed=-0.088728 threshold=0.250000 || ci_failed lower=-0.512063 upper=0.361733`
   - Single-action gate: `FAIL`
      - `reason=improvement_failed observed=-0.389353 threshold=0.200000 || ci_failed lower=-0.725408 upper=0.159554`
   - Artifacts:
      - `Logs/vp_perf_acceptance_decision_step23_tranche7_warm_partition_disk__decision_20260803T191940Z_summary.csv`
      - `Logs/vp_perf_acceptance_decision_step23_tranche7_warm_partition_disk__decision_20260803T191940Z_details.csv`
      - `Logs/vp_perf_acceptance_decision_step23_tranche7_warm_partition_disk__decision_20260803T191940Z_decision.csv`
3. Lane: `warm_session`
   - Decision label: `step23_tranche7_warm_session__decision`
   - Manifest rows used: `12` (baseline `6`, candidate `6`)
   - Overall status: `FAIL`
   - Startup gate: `FAIL`
      - `reason=improvement_failed observed=0.045480 threshold=0.250000 || ci_failed lower=-0.036936 upper=0.513689`
   - Single-action gate: `FAIL`
      - `reason=improvement_failed observed=0.086231 threshold=0.200000`
   - Artifacts:
      - `Logs/vp_perf_acceptance_decision_step23_tranche7_warm_session__decision_20260803T194248Z_summary.csv`
      - `Logs/vp_perf_acceptance_decision_step23_tranche7_warm_session__decision_20260803T194248Z_details.csv`
      - `Logs/vp_perf_acceptance_decision_step23_tranche7_warm_session__decision_20260803T194248Z_decision.csv`

Interpretation notes:
1. All three lanes failed strict acceptance gates in this run set.
2. Failure pattern is driven by insufficient observed improvement against configured thresholds and confidence support (CI lower bounds not strictly above zero where evaluated).
3. Because baseline and candidate were executed with symmetric cache-state settings in this tranche, low/near-zero improvement outcomes are expected and useful as a control signal validating gate strictness.

What was intentionally not done in this tranche:
1. No threshold relaxation or gate semantic changes.
2. No candidate-side optimization override artifact injection for this evidence pass.
3. No iterations increase beyond `3` for this first real multi-lane evidence set.

Immediate next tranche (Tranche 8) plan:
1. Add manifest clean-room mode to pair runner so each pair-run can validate against isolated manifest files.
2. Run baseline vs true optimization-candidate comparisons (non-symmetric lanes/artifacts) to produce meaningful improvement signals against strict thresholds.
3. Emit an index/report artifact mapping lane, pair-run ID, and decision output files for longitudinal acceptance tracking.

### Tranche 8 - Kickoff (2026-08-03)

Status: In progress

Kickoff decision:
1. Tranche 7 is closed as complete control-evidence validation.
2. Begin Tranche 8 with manifest clean-room mode first, then run non-symmetric baseline vs candidate acceptance batches.

Implementation update (Tranche 8A - manifest clean-room mode):
1. Added optional clean-room manifest support in `System/Testing/vp_perf_run_acceptance_pair.R`.
2. New orchestration arguments:
   - `--manifest-clean-room=true|false` (default `false`)
   - `--manifest-clean-room-dir=<path>` (optional output directory for run-scoped manifest)
3. Behavior when clean-room mode is enabled:
   - Runner creates a run-scoped acceptance manifest path:
      - `vp_perf_acceptance_run_manifest_<pair_run_id>.csv`
   - Manifest path is passed to startup probe, single-action probe, and decision script so strict validation resolves only run-local evidence.
   - Any pre-existing CSV/JSONL at the run-scoped path is removed before probe execution to guarantee clean-room isolation.
4. Added orchestration telemetry:
   - `VP_PERF_ACCEPTANCE_PAIR_MANIFEST_CLEAN_ROOM=TRUE|FALSE`
   - `VP_PERF_ACCEPTANCE_PAIR_ACCEPTANCE_MANIFEST=<resolved_path>`

Validation completed for 8A:
1. Static diagnostics (`get_errors`) on `System/Testing/vp_perf_run_acceptance_pair.R` returned no errors after clean-room implementation.

Next execution step (Tranche 8B):
1. Run non-symmetric baseline vs candidate lane batches with clean-room manifest mode enabled.
2. Capture lane-level decision artifacts and compare against Tranche 7 control outcomes.

Execution update (Tranche 8B - first non-symmetric clean-room run):
1. Regenerated rollup-ablation artifacts to ensure valid override paths:
   - Command: `System/Testing/vp_perf_prepare_rollup_ablation_artifacts.R`
   - Output root:
      - `Logs/rollup_ablation/20260803T200502Z/`
   - Baseline artifact:
      - `Logs/rollup_ablation/20260803T200502Z/vp_trade_monthly_full_copy.rds`
   - Candidate artifact:
      - `Logs/rollup_ablation/20260803T200502Z/vp_trade_monthly_minimal_rollup_contract.rds`
2. Initial Tranche 8B run (`step24_tranche8_non_symmetric_warm_partition_disk`) failed in strict decisioning:
   - Root cause: one candidate single-action probe row had missing `runtime_log_path` in clean-room manifest due to transient runtime-log write error (`Permission denied`).
   - Strict validator correctly blocked decision artifact creation with:
      - `Acceptance manifest validation failed: row=4;missing_field:runtime_log_path`
3. Reran with fresh label and explicit nested Rscript path (`--rscript=C:/Program Files/R/R-4.5.1/bin/Rscript.exe`) to reduce command-path drift and file contention:
   - Label: `step24b_tranche8_non_symmetric_warm_partition_disk`
   - Clean-room manifest:
      - `Logs/acceptance_clean_room/vp_perf_acceptance_run_manifest_step24b_tranche8_non_symmetric_warm_partition_disk_20260803T202638Z.csv`
   - Decision completed and emitted artifacts.

Tranche 8B evidence (warm_partition_disk, non-symmetric full-copy vs minimal-rollup):
1. Decision label:
   - `step24b_tranche8_non_symmetric_warm_partition_disk__decision`
2. Overall status:
   - `FAIL`
3. Startup gate:
   - `FAIL`
   - `reason=improvement_failed observed=0.230289 threshold=0.250000`
4. Single-action gate:
   - `FAIL`
   - `reason=improvement_failed observed=-0.017157 threshold=0.200000 || ci_failed lower=-0.031874 upper=0.237598`
5. Overall reason row:
   - `reason=improvement_failed observed=0.230289 threshold=0.250000 || improvement_failed observed=-0.017157 threshold=0.200000 || ci_failed lower=-0.031874 upper=0.237598`
6. Decision artifacts:
   - `Logs/vp_perf_acceptance_decision_step24b_tranche8_non_symmetric_warm_partition_disk__decision_20260803T204616Z_summary.csv`
   - `Logs/vp_perf_acceptance_decision_step24b_tranche8_non_symmetric_warm_partition_disk__decision_20260803T204616Z_details.csv`
   - `Logs/vp_perf_acceptance_decision_step24b_tranche8_non_symmetric_warm_partition_disk__decision_20260803T204616Z_decision.csv`

Interpretation (8B initial lane):
1. Clean-room manifest isolation is functioning as designed and strict validation caught a transient evidence-integrity issue before decisioning.
2. After rerun integrity was restored, candidate still failed strict thresholds:
   - startup improvement came close but below required 25%,
   - single-action showed no positive improvement under this candidate construction.

Immediate next 8B actions:
1. Repeat non-symmetric clean-room runs for `cold_artifact` and `warm_session` lanes using the same full-copy vs minimal-rollup artifact pair.
2. Emit an index/report artifact mapping lane, pair-run label, clean-room manifest path, and decision artifact files.

Execution update (Tranche 8B - additional lanes completed):
1. Ran non-symmetric clean-room batch for `cold_artifact` lane:
   - Label: `step24c_tranche8_non_symmetric_cold_artifact`
   - Clean-room manifest:
      - `Logs/acceptance_clean_room/vp_perf_acceptance_run_manifest_step24c_tranche8_non_symmetric_cold_artifact_20260803T205712Z.csv`
2. Ran non-symmetric clean-room batch for `warm_session` lane:
   - Label: `step24d_tranche8_non_symmetric_warm_session`
   - Clean-room manifest:
      - `Logs/acceptance_clean_room/vp_perf_acceptance_run_manifest_step24d_tranche8_non_symmetric_warm_session_20260803T211729Z.csv`

Tranche 8B evidence (new lanes):
1. Lane: `cold_artifact`
   - Decision label: `step24c_tranche8_non_symmetric_cold_artifact__decision`
   - Overall status: `FAIL`
   - Startup gate: `FAIL`
      - `reason=improvement_failed observed=0.217518 threshold=0.250000`
   - Single-action gate: `FAIL`
      - `reason=improvement_failed observed=-0.092744 threshold=0.200000 || ci_failed lower=-0.143712 upper=0.261666`
   - Artifacts:
      - `Logs/vp_perf_acceptance_decision_step24c_tranche8_non_symmetric_cold_artifact__decision_20260803T211722Z_summary.csv`
      - `Logs/vp_perf_acceptance_decision_step24c_tranche8_non_symmetric_cold_artifact__decision_20260803T211722Z_details.csv`
      - `Logs/vp_perf_acceptance_decision_step24c_tranche8_non_symmetric_cold_artifact__decision_20260803T211722Z_decision.csv`
2. Lane: `warm_session`
   - Decision label: `step24d_tranche8_non_symmetric_warm_session__decision`
   - Overall status: `FAIL`
   - Startup gate: `FAIL`
      - `reason=improvement_failed observed=0.203583 threshold=0.250000`
   - Single-action gate: `FAIL`
      - `reason=improvement_failed observed=0.035534 threshold=0.200000 || ci_failed lower=-0.065413 upper=0.172599`
   - Artifacts:
      - `Logs/vp_perf_acceptance_decision_step24d_tranche8_non_symmetric_warm_session__decision_20260803T213723Z_summary.csv`
      - `Logs/vp_perf_acceptance_decision_step24d_tranche8_non_symmetric_warm_session__decision_20260803T213723Z_details.csv`
      - `Logs/vp_perf_acceptance_decision_step24d_tranche8_non_symmetric_warm_session__decision_20260803T213723Z_decision.csv`

Cross-lane interim interpretation (8B):
1. All three non-symmetric lanes now completed (`warm_partition_disk`, `cold_artifact`, `warm_session`) with clean-room strict evidence.
2. Startup improvements are materially positive but remain below the 25% acceptance threshold in all lanes.
3. Single-action improvements are near zero or negative with CI lower bounds below zero, so strict single-action gates continue to fail.

Immediate next 8B action:
1. Emit the planned index/report artifact mapping lane, pair-run label, clean-room manifest file, and decision summary/detail/decision outputs.

Execution update (Tranche 8B - index/report artifact emitted):
1. Emitted consolidated acceptance index/report artifacts covering all completed non-symmetric clean-room lanes:
   - `Logs/vp_perf_acceptance_index_step24b_step24d_20260803T213927Z.csv`
   - `Logs/vp_perf_acceptance_index_step24b_step24d_20260803T213927Z.json`
2. Artifact contents map, per lane:
   - `lane`
   - `pair_run_label`
   - `clean_room_manifest_csv`
   - `decision_summary_csv`
   - `decision_details_csv`
   - `decision_file_csv`
3. Included lane rows:
   - `warm_partition_disk` (`step24b_tranche8_non_symmetric_warm_partition_disk`)
   - `cold_artifact` (`step24c_tranche8_non_symmetric_cold_artifact`)
   - `warm_session` (`step24d_tranche8_non_symmetric_warm_session`)

Tranche 8B completion note:
1. The planned index/report artifact emission step is complete.

### Tranche 8C - Single-Action Bottleneck Decomposition (2026-08-03)

Status: In progress

Objective:
1. Execute a focused diagnostic tranche that explains why Tranche 8B non-symmetric runs improved startup but failed strict single-action gates.
2. Produce reproducible, auditable bottleneck attribution across lane-local baseline/candidate pairs before selecting the next architecture implementation tranche.
3. Carry forward prior performance lessons while explicitly preventing re-entry into previously rejected optimization paths without fresh evidence.

Execution posture:
1. Tranche 8C is diagnostic only; it is not an acceptance-pass tranche.
2. No gate relaxation, no candidate promotion, and no broad app optimization changes are permitted in this tranche.
3. Claims must be based on exact-path clean-room evidence and explicit comparison-validity controls.

Phase 0 - Source-of-truth and 8B closure
1. Keep this file as the implementation source of truth and update it after each 8C step, emitted artifact, failed attempt, and blocker.
2. Close 8B explicitly as evidence-complete:
   - clean-room manifest mode delivered,
   - non-symmetric three-lane batch completed,
   - index/report artifacts emitted.
3. Record 8B decision:
   - minimal-rollup artifact override is rejected as a standalone interaction-performance candidate,
   - startup gains (~20-23%) remained below 25% threshold,
   - single-action failed in all lanes.

Phase 1 - Comparison validity and inventory
1. Use index root:
   - `Logs/vp_perf_acceptance_index_step24b_step24d_20260803T213927Z.csv`
2. Build 8C inventory artifact from index + clean-room manifests with one row per manifest probe row (startup and single_action).
3. Required inventory fields:
   - lane, pair_run_label, manifest_path,
   - probe_type, run_id, session_id, label, scenario, cache_state,
   - runtime_log_path, output_csv_path,
   - baseline_or_candidate role,
   - decision_summary_csv, decision_details_csv, decision_file_csv,
   - provider_mode, artifact override fields, target_tab,
   - status/base_status.
4. Add comparison-validity fields per row:
   - app_ref (working tree/commit snapshot at analysis time),
   - probe_script path,
   - runtime/logging mode,
   - scenario parameters (where available),
   - lane and role consistency checks.
5. Add artifact-integrity chain per row:
   - manifest_exists,
   - runtime_log_exists,
   - decision_files_exist,
   - nonzero-size checks,
   - label/path consistency checks,
   - `integrity_status` (`ok` / `quarantine`).
6. Quarantine rows with failed integrity from bottleneck conclusions and record reason.

Phase 2 - Lesson register with reopen criteria
1. Carry forward lessons:
   - lane-separated attribution,
   - hierarchy transaction boundaries,
   - narrow signature-keyed display/mixed-volume logic,
   - provider mode attribution,
   - visible-ready vs after-paint vs post-idle separation,
   - deterministic fixtures and exact runtime log binding.
2. Keep these as rejected/lower-value by default for 8C:
   - broad derived `bindCache` wrapping,
   - hidden output warming / broad unsuspend,
   - Plotly redraw removal as first-line tactic,
   - canonical artifact swapping as acceptance mechanism,
   - provider disk-cache micro-optimization as primary lever,
   - incremental fanout tweaks without request-shape narrowing.
3. Reopen criteria required for any rejected tactic:
   - named new evidence,
   - threshold crossing,
   - explicit decision note and rollback condition.

Phase 3 - Runtime decomposition design
1. Extend or add summarizer logic (preferred seam: `System/Testing/vp_perf_summarize_runtime_logs.R`) using exact runtime log paths from 8C inventory.
2. Use deterministic bucket mapping with first-match precedence and explicit spill buckets:
   - `carryover_startup_load`
   - `provider_filter`
   - `hierarchy_fanout`
   - `tab_server_materialization`
   - `display_unit_mixed`
   - `client_lifecycle`
   - `post_visible_idle`
   - `transition_wait`
   - `client_wait`
   - `multi_match`
   - `unclassified`
3. Split each run into windows:
   - `carryover_pre_action`
   - `action_window`
   - `post_visible_idle`
4. Claims about next implementation target must prioritize `action_window`; carryover and post-visible are context/separate optimization targets.
5. Emit explicit timing fields:
   - `event_elapsed_ms`
   - `gap_allocated_ms`
   - `attributed_elapsed_ms`
6. Gap allocation rules:
   - same-bucket gap -> same bucket,
   - cross-bucket gap -> `transition_wait`,
   - pending client milestone gap -> `client_wait`,
   - after first visible/after-paint gap -> `post_visible_idle` unless stronger rule applies.
7. Required summary statistics by lane/role/window/bucket:
   - count,
   - total event elapsed,
   - total allocated gap,
   - total attributed elapsed,
   - median,
   - p90,
   - p95,
   - MAD,
   - max,
   - first_ts,
   - last_ts,
   - failure/timeout and exclusion counts.
8. Emit confidence/coverage fields:
   - `unclassified_event_count`
   - `multi_match_event_count`
   - `unclassified_attributed_ms`
   - `bucket_confidence`
9. If unclassified/multi-match attribution exceeds threshold, mark lane as inconclusive instead of forcing attribution.

Phase 4 - Cross-lane diagnosis and representativeness
1. Compare baseline vs candidate within each lane first, then cross-lane patterns.
2. Apply explicit exclusion/outlier policy:
   - missing files,
   - integrity quarantine,
   - comparison-validity violation,
   - timeout/probe failure,
   - incomplete milestone chain.
3. Preserve exclusion reason counts in emitted artifacts.
4. Diagnose dominant causes among:
   - provider/request shape,
   - hierarchy cascade,
   - tab server materialization,
   - client/Plotly lifecycle,
   - post-ready churn,
   - harness/probe artifact,
   - mixed dominance,
   - inconclusive.
5. Run representativeness checkpoint:
   - Current vs. Average is initial scope,
   - if not representative of known user pain, add one supplementary diagnostic scenario (likely trend/heatmap or map) before next-tranche recommendation.

Phase 5 - Instrumentation only when triggered
1. Instrument only when trigger criteria are met:
   - high unclassified/multi-match,
   - missing milestone pairing,
   - missing client/server coupling,
   - low bucket confidence,
   - inability to isolate action window.
2. Before widening instrumentation, run perturbation check (off vs on) on same lane/scenario.
3. Abort/reduce instrumentation if it materially perturbs:
   - median/p90 action-window latency,
   - failure rate,
   - milestone ordering.
4. Preferred instrumentation order:
   - `Programs/app_source/server/03_core_reactives_and_ui.R`
   - `Programs/app_source/server/02_partner_and_notes.R`
   - `Programs/app_source/server/04_comparison_plots.R`
   - `Programs/app_source/server/05_trend_and_heatmap.R`
   - `Programs/app_source/ui.R`

Phase 6 - Recommendation gate
1. Choose next tranche only if decision-confidence rubric passes:
   - dominant bucket is lane-consistent in at least 2 of 3 lanes,
   - exceeds runner-up by agreed margin,
   - reproduces across iterations,
   - remains valid after exclusions and integrity checks.
2. If confidence is mixed/low, emit no-decision outcome and define smallest follow-up diagnostic tranche.
3. Do not claim acceptance pass from 8C outputs.

Handoff-ready first implementation steps
1. Step 25A: emit 8C inventory artifact from current 8B index/manifests with integrity + provenance fields.
2. Step 25B: validate 25A coverage and quarantine behavior.
3. Step 25C: implement/run first deterministic decomposition pass on one known runtime log, then widen to all single-action logs.

Expected 8C artifacts
1. Inventory CSV (+ optional JSON) with provenance and integrity status.
2. Decomposition detail CSV.
3. Decomposition summary CSV/JSON.
4. Decision-note artifact or plan section naming dominant/mixed/inconclusive bottleneck with confidence rationale.

Stop conditions
1. Failed integrity chain or comparison-validity violation.
2. Excessive unclassified/multi-match attribution.
3. Missing action-window milestone boundaries.
4. Instrumentation perturbation beyond threshold.
5. Mixed/low-confidence evidence with no justified dominant bucket.

Non-goals (Tranche 8C)
1. Broad app optimization edits.
2. Broad rerun of acceptance batches by default.
3. Acceptance gate changes or threshold relaxation.
4. Candidate mode promotion.
5. Reopening rejected tactics without explicit reopen criteria.

Execution update (Tranche 8C - Step 25A inventory emitted):
1. Emitted first 8C inventory artifacts from the 8B index + clean-room manifests:
   - `Logs/vp_perf_acceptance_inventory_step25a_tranche8c_20260803T215536Z.csv`
   - `Logs/vp_perf_acceptance_inventory_step25a_tranche8c_20260803T215536Z.json`
2. Inventory schema includes required provenance and integrity fields:
   - lane/pair-run/manifest linkage,
   - probe row context (`probe_type`, `run_id`, `session_id`, `label`, `scenario`, `cache_state`, role),
   - evidence paths (`runtime_log_path`, `output_csv_path`, decision artifacts),
   - comparison-validity context (`comparison_validity_*`),
   - integrity outputs (`integrity_status`, `integrity_reason`, existence/nonzero checks).
3. Coverage and integrity summary:
   - total rows: `36`
   - lane split: `warm_partition_disk=12`, `cold_artifact=12`, `warm_session=12`
   - integrity `ok`: `36`
   - integrity `quarantine`: `0`
4. This satisfies 8C entry requirements for Phase 1 inventory/integrity and enables Step 25B validation and Step 25C decomposition work.

Execution update (Tranche 8C - Step 25B inventory contract validation):
1. Added a formal Step 25B validator script:
   - `System/Testing/vp_perf_validate_inventory_step25b_8c.R`
2. Emitted Step 25B validation artifacts:
   - `Logs/vp_perf_acceptance_inventory_validation_step25b_tranche8c_validation_20260804T132702Z_detail.csv`
   - `Logs/vp_perf_acceptance_inventory_validation_step25b_tranche8c_validation_20260804T132702Z_summary.csv`
   - `Logs/vp_perf_acceptance_inventory_validation_step25b_tranche8c_validation_20260804T132702Z_reasons.csv`
   - `Logs/vp_perf_acceptance_inventory_validation_step25b_tranche8c_validation_20260804T132702Z_lane_counts.csv`
   - `Logs/vp_perf_acceptance_inventory_validation_step25b_tranche8c_validation_20260804T132702Z_probe_counts.csv`
   - `Logs/vp_perf_acceptance_inventory_validation_step25b_tranche8c_validation_20260804T132702Z_role_counts.csv`
   - `Logs/vp_perf_acceptance_inventory_validation_step25b_tranche8c_validation_20260804T132702Z_lane_probe_role_counts.csv`
   - `Logs/vp_perf_acceptance_inventory_validation_step25b_tranche8c_validation_20260804T132702Z.json`
3. Step 25B contract outcomes:
   - `total_rows=36`
   - `ok_rows=36`
   - `quarantine_rows=0`
   - `integrity_ok_rows=36`
   - `integrity_quarantine_rows=0`
   - `comparison_validity_complete_rows=36`
4. Coverage matrix check passed:
   - all lane/probe/role cells populated at `3` rows each
   - lanes: `cold_artifact`, `warm_partition_disk`, `warm_session`
   - probes: `startup`, `single_action`
   - roles: `baseline`, `candidate`
5. Validation reasons output contains only `ok` (`row_count=36`); no quarantine reasons were emitted.

Execution update (Tranche 8C - Step 25C deterministic decomposition):
1. Added Step 25C decomposition runner:
   - `System/Testing/vp_perf_decompose_single_action_8c.R`
2. Performed single-log smoke run and emitted first smoke artifacts:
   - `Logs/vp_perf_acceptance_decomposition_step25c_smoke_single_log_20260804T132429Z_detail.csv`
   - `Logs/vp_perf_acceptance_decomposition_step25c_smoke_single_log_20260804T132429Z_summary.csv`
   - `Logs/vp_perf_acceptance_decomposition_step25c_smoke_single_log_20260804T132429Z_runs.csv`
   - `Logs/vp_perf_acceptance_decomposition_step25c_smoke_single_log_20260804T132429Z_summary.json`
3. Found and fixed a Step 25C smoke defect before widening:
   - symptom: summary `first_ts_utc` / `last_ts_utc` fields showed `Inf` / `-Inf` in smoke output,
   - root cause: summary stage referenced `ts_utc_posix` while detail rows did not carry the field,
   - fix: carry normalized `ts_utc_posix` into detail rows and compute time ranges with finite-time guards,
   - verification: rerun smoke with clean timestamps via:
      - `Logs/vp_perf_acceptance_decomposition_step25c_smoke_single_log_fix1_20260804T132543Z_detail.csv`
      - `Logs/vp_perf_acceptance_decomposition_step25c_smoke_single_log_fix1_20260804T132543Z_summary.csv`
      - `Logs/vp_perf_acceptance_decomposition_step25c_smoke_single_log_fix1_20260804T132543Z_runs.csv`
      - `Logs/vp_perf_acceptance_decomposition_step25c_smoke_single_log_fix1_20260804T132543Z_summary.json`
4. Widened to all single-action rows (integrity `ok` only) and emitted full Step 25C artifacts:
   - `Logs/vp_perf_acceptance_decomposition_step25c_tranche8c_all_single_action_20260804T132712Z_detail.csv`
   - `Logs/vp_perf_acceptance_decomposition_step25c_tranche8c_all_single_action_20260804T132712Z_summary.csv`
   - `Logs/vp_perf_acceptance_decomposition_step25c_tranche8c_all_single_action_20260804T132712Z_runs.csv`
   - `Logs/vp_perf_acceptance_decomposition_step25c_tranche8c_all_single_action_20260804T132712Z_summary.json`
5. Full Step 25C run coverage summary:
   - selected inventory rows: `18` (`single_action` only)
   - decomposition detail rows: `11,466`
   - run rows: `18`
   - summary rows: `132`
6. Added Step 25C rollup helper for lane/bucket interpretation:
   - `System/Testing/vp_perf_step25c_bucket_rollup_8c.R`
7. Emitted Step 25C rollup artifacts:
   - `Logs/vp_perf_acceptance_decomposition_step25c_tranche8c_all_single_action_rollup_20260804T132948Z_action_bucket.csv`
   - `Logs/vp_perf_acceptance_decomposition_step25c_tranche8c_all_single_action_rollup_20260804T132948Z_lane_delta.csv`
   - `Logs/vp_perf_acceptance_decomposition_step25c_tranche8c_all_single_action_rollup_20260804T132948Z_lane_confidence.csv`
8. Action-window baseline vs candidate attributed-time deltas by lane:
   - `cold_artifact`: baseline `135837.100` ms -> candidate `106174.600` ms (`-29662.500` ms, `21.8368%` improvement)
   - `warm_partition_disk`: baseline `110270.900` ms -> candidate `102429.600` ms (`-7841.300` ms, `7.1109%` improvement)
   - `warm_session`: baseline `115651.100` ms -> candidate `108019.600` ms (`-7631.500` ms, `6.5987%` improvement)
9. Action-window composition pattern is lane-consistent and dominated by:
   - `client_lifecycle` (~47-56% share)
   - `transition_wait` (~24-31% share)
   - `client_wait` (~18-20% share)
   - all remaining buckets individually near or below low-single-digit share.
10. Coverage/confidence diagnostic from run-level rollup:
   - mean `bucket_confidence` by lane: ~`0.666` to `0.676`
   - max `unclassified_attributed_ms` by lane: ~`34,391` to `36,715` ms.
11. Step 25C status: completed as diagnostic decomposition tranche with deterministic artifacts and documented smoke defect repair; no acceptance-gate claims made.

Execution update (Tranche 8C - explicit inconclusive-threshold gate wired into Step 25C decomposition):
1. Implemented explicit inconclusive-threshold gate logic in:
   - `System/Testing/vp_perf_decompose_single_action_8c.R`
2. Added new CLI arguments with clamped [0,1] numeric handling:
   - `--inconclusive-min-bucket-confidence` (default `0.70`)
   - `--inconclusive-max-unclassified-share` (default `0.20`)
   - `--inconclusive-max-lane-inconclusive-share` (default `0.34`)
   - `--fail-on-inconclusive=true|false` (default `false`)
3. Added run-level inconclusive attribution fields to `_runs.csv`:
   - `run_total_attributed_ms`
   - `unclassified_attributed_share`
   - `run_inconclusive`
   - `run_inconclusive_reason`
   - plus emitted threshold fields for provenance.
4. Added lane-level gate summary artifact:
   - `*_inconclusive_gate.csv`
   - columns include run counts, inconclusive counts/share, lane threshold fields, lane-level gate flag, and lane-level reason.
5. Added summary JSON/terminal telemetry fields for gate observability:
   - `inconclusive_gate_rows`
   - `inconclusive_run_count`, `inconclusive_run_share`
   - `inconclusive_lane_count`, `inconclusive_lane_share`
   - threshold echoes and fail-mode echo.
6. Added optional hard-fail behavior:
   - when `--fail-on-inconclusive=true`, script writes artifacts then stops with explicit failing lane list if any lane is inconclusive.
7. Validation run (non-failing mode) executed successfully:
   - Command label: `step25c_tranche8c_all_single_action_with_inconclusive_gate`
   - Inventory: `Logs/vp_perf_acceptance_inventory_step25a_tranche8c_20260803T215536Z.csv`
   - Outputs:
      - `Logs/vp_perf_acceptance_decomposition_step25c_tranche8c_all_single_action_with_inconclusive_gate_20260804T135723Z_detail.csv`
      - `Logs/vp_perf_acceptance_decomposition_step25c_tranche8c_all_single_action_with_inconclusive_gate_20260804T135723Z_summary.csv`
      - `Logs/vp_perf_acceptance_decomposition_step25c_tranche8c_all_single_action_with_inconclusive_gate_20260804T135723Z_runs.csv`
      - `Logs/vp_perf_acceptance_decomposition_step25c_tranche8c_all_single_action_with_inconclusive_gate_20260804T135723Z_inconclusive_gate.csv`
      - `Logs/vp_perf_acceptance_decomposition_step25c_tranche8c_all_single_action_with_inconclusive_gate_20260804T135723Z_summary.json`
   - Telemetry summary:
      - `inconclusive_run_count=17/18` (`0.944444`)
      - `inconclusive_lane_count=6/6` (`1.000000`)
8. Validation run (hard-fail mode) confirmed stop behavior:
   - Command label: `step25c_tranche8c_all_single_action_with_inconclusive_gate_failcheck`
   - `--fail-on-inconclusive=true`
   - Script halted with expected error and explicit failing lanes list:
      - `Inconclusive gate failed for 6 lane(s): warm_partition_disk/baseline, warm_partition_disk/candidate, cold_artifact/baseline, cold_artifact/candidate, warm_session/baseline, warm_session/candidate`
9. Tranche 8C interpretation update:
   - Step 25C decomposition now has enforceable confidence guardrails that prevent overconfident bottleneck claims when attribution quality is weak.
   - Current thresholds classify this 8C run set as broadly inconclusive, which is consistent with previously observed high unattributed/background churn.

Execution update (Tranche 8C - Step 25D attribution hardening implementation):
1. Implemented Step 25D attribution hardening in:
   - `System/Testing/vp_perf_decompose_single_action_8c.R`
2. Added detail-derived/window-scoped confidence artifact and metrics:
   - new output: `*_window_confidence.csv`
   - per run/window metrics include:
      - detail total attributed ms,
      - observed-event attributed ms,
      - synthetic gap attributed ms,
      - gap allocated share,
      - synthetic wait (`transition_wait`/`client_wait`) attributed ms and share,
      - unclassified + multi-match attributed ms/share,
      - observed-row and detail-level bucket confidence,
      - window inconclusive + reasons,
      - gap and synthetic-wait warning flags + reasons.
3. Added milestone/window boundary provenance fields to run and window confidence outputs:
   - `action_start_source`
   - `visible_milestone_source`
   - `window_boundary_confidence`
   - `window_boundary_warning`
   - `window_boundary_warning_reason`
4. Added additive Step 25D telemetry (without changing Step 25C hard-fail semantics):
   - action-window/post-visible inconclusive counts and shares,
   - action-window/post-visible gap warning shares,
   - action-window/post-visible synthetic-wait warning shares,
   - window warning thresholds.
5. Added new optional warning thresholds:
   - `--window-gap-warning-threshold` (default `0.50`)
   - `--window-synthetic-wait-warning-threshold` (default `0.40`)
   - existing run/lane inconclusive threshold args and `--fail-on-inconclusive` behavior remain intact.

Execution update (Tranche 8C - Step 25D audit script added):
1. Added exact-path attribution audit script:
   - `System/Testing/vp_perf_step25d_attribution_audit_8c.R`
2. Script requires explicit artifact path arguments (no latest-file discovery):
   - `--detail`
   - `--summary`
   - `--runs`
   - `--window-confidence`
   - `--inconclusive-gate`
3. Emitted Step 25D audit artifact family:
   - `*_classification_audit.csv`
   - `*_window_bucket.csv`
   - `*_confidence_comparison.csv`
   - `*_audit_summary.json` (when `jsonlite` available)

Bug found and fixed during Step 25D implementation:
1. Regression symptom:
   - full decomposition detail row count dropped from baseline `11,466` to `11,448` in first 25D full run.
2. Root cause:
   - initial provenance helper logic changed milestone selection precedence relative to Step 25C behavior by preferring source-specific buckets before earliest-match selection across the combined candidate set.
3. Fix:
   - restored original timestamp-selection semantics (earliest matching event across combined candidate conditions) while preserving provenance labels.
4. Verification after fix:
   - full detail rows returned to `11,466`.
   - run rows `18`, summary rows `132`.
   - inconclusive run/lane outcomes remained `17/18` and `6/6` respectively.

Step 25D validation runs and artifacts:
1. Smoke run (single selected log):
   - label: `step25d_smoke_max1`
   - outputs:
      - `Logs/vp_perf_acceptance_decomposition_step25d_smoke_max1_20260804T143848Z_detail.csv`
      - `Logs/vp_perf_acceptance_decomposition_step25d_smoke_max1_20260804T143848Z_summary.csv`
      - `Logs/vp_perf_acceptance_decomposition_step25d_smoke_max1_20260804T143848Z_runs.csv`
      - `Logs/vp_perf_acceptance_decomposition_step25d_smoke_max1_20260804T143848Z_inconclusive_gate.csv`
      - `Logs/vp_perf_acceptance_decomposition_step25d_smoke_max1_20260804T143848Z_window_confidence.csv`
      - `Logs/vp_perf_acceptance_decomposition_step25d_smoke_max1_20260804T143848Z_summary.json`
2. Initial full run (pre-fix; regression capture run):
   - label: `step25d_tranche8c_all_single_action`
   - recorded for defect traceability; replaced for baseline-compat validation by fix run below.
3. Full run after fix (baseline-compatible):
   - label: `step25d_tranche8c_all_single_action_fix1`
   - outputs:
      - `Logs/vp_perf_acceptance_decomposition_step25d_tranche8c_all_single_action_fix1_20260804T144412Z_detail.csv`
      - `Logs/vp_perf_acceptance_decomposition_step25d_tranche8c_all_single_action_fix1_20260804T144412Z_summary.csv`
      - `Logs/vp_perf_acceptance_decomposition_step25d_tranche8c_all_single_action_fix1_20260804T144412Z_runs.csv`
      - `Logs/vp_perf_acceptance_decomposition_step25d_tranche8c_all_single_action_fix1_20260804T144412Z_inconclusive_gate.csv`
      - `Logs/vp_perf_acceptance_decomposition_step25d_tranche8c_all_single_action_fix1_20260804T144412Z_window_confidence.csv`
      - `Logs/vp_perf_acceptance_decomposition_step25d_tranche8c_all_single_action_fix1_20260804T144412Z_summary.json`
   - telemetry highlights:
      - `selected_rows=18`
      - `detail_rows=11466`
      - `inconclusive_run_count=17` (`0.944444`)
      - `inconclusive_lane_count=6` (`1.000000`)
      - `action_window_inconclusive_share=0.000000`
      - `action_window_gap_warning_share=0.555556`
      - `action_window_synthetic_wait_warning_share=0.944444`
      - `post_visible_inconclusive_share=1.000000`
      - `post_visible_gap_warning_share=0.833333`
4. Full run hard-fail check after fix:
   - label: `step25d_tranche8c_all_single_action_fix1_failcheck`
   - `--fail-on-inconclusive=true`
   - expected stop reproduced with explicit lane list:
      - `warm_partition_disk/baseline`
      - `warm_partition_disk/candidate`
      - `cold_artifact/baseline`
      - `cold_artifact/candidate`
      - `warm_session/baseline`
      - `warm_session/candidate`
5. Step 25D audit run (exact-path) on fixed full outputs:
   - label: `step25d_tranche8c_all_single_action_fix1_audit`
   - outputs:
      - `Logs/vp_perf_acceptance_decomposition_step25d_tranche8c_all_single_action_fix1_audit_20260804T144836Z_classification_audit.csv`
      - `Logs/vp_perf_acceptance_decomposition_step25d_tranche8c_all_single_action_fix1_audit_20260804T144836Z_window_bucket.csv`
      - `Logs/vp_perf_acceptance_decomposition_step25d_tranche8c_all_single_action_fix1_audit_20260804T144836Z_confidence_comparison.csv`
      - `Logs/vp_perf_acceptance_decomposition_step25d_tranche8c_all_single_action_fix1_audit_20260804T144836Z_audit_summary.json`

Tranche 8C interpretation update after Step 25D:
1. Step 25C run/lane inconclusive outcomes remain unchanged under Step 25D, confirming hard-fail gate stability.
2. Step 25D adds split-confidence visibility that separates low direct action-window unclassified attribution from high synthetic wait/gap dominance.
3. Evidence now supports a stronger measurement claim:
   - action-window windows are not inconclusive under direct unclassified/multi-match thresholds,
   - but they are heavily warning-flagged for synthetic wait share,
   - post-visible windows remain fully inconclusive/high-gap-dominant,
   - therefore bottleneck recommendation must remain diagnostic and avoid over-claiming root cause from wait buckets alone.

Execution update (Tranche 8D - explicit boundary instrumentation discovery, implementation, and perturbation smoke):
1. Implemented feature-gated client boundary instrumentation in:
   - `Programs/app_source/ui.R`
   - Added `perfBoundaryMarkersEnabled` in `window.riceClientDebug` bootstrap payload.
   - Added `emitBoundaryMarker(boundary, payload)` wrapper that reuses `emitClientPerf` action context.
   - Added marker emits at existing lifecycle points (no behavior changes):
      - `action_begin` in `beginPerfAction()` (skips `initial_mount`),
      - `tab_click_dispatched` on main-tab click,
      - `tab_shown` on Bootstrap tab shown event,
      - `tab_after_paint` in `setTimeout(..., 0)` after tab shown,
      - `visible_ready` after plotly resize/paint when target output is present and visible.
2. Implemented server-side boundary ingestion in:
   - `Programs/app_source/server/02_partner_and_notes.R`
   - Added `normalize_client_perf_boundary_tag()` to sanitize marker names.
   - Added `observeEvent(input$client_perf_boundary_marker, ...)` to log normalized tags as `boundary_*` via existing `log_client_perf()` runtime path.
3. Added server boundary marker emits (feature-gated) at high-value completion points:
   - `Programs/app_source/server/02_partner_and_notes.R`
      - `boundary_server_main_tabs_observer_complete` emitted at end of `observeEvent(input$main_tabs_panel, ...)` after frequency/resize decisions.
      - `boundary_server_plotly_resize_recorded` emitted on `client_perf_plotly_resize` ingestion with target output metadata.
   - `Programs/app_source/server/03_core_reactives_and_ui.R`
      - `boundary_server_filtered_data_for_country_blocked` emitted on blocked-return path.
      - `boundary_server_filtered_data_for_country_complete` emitted on successful filtered-data completion.
   - `Programs/app_source/server/04_comparison_plots.R`
      - `boundary_server_summary_table_null` emitted on null-return path.
      - `boundary_server_summary_table_complete` emitted at summary table completion.
4. Added shared runtime toggle helper in:
   - `Programs/app_source/global.R`
   - `perf_boundary_markers_enabled()` resolves options/env (`vp|almond|rice` + `VP_PERF_BOUNDARY_MARKERS`) without modifying default behavior.
5. Added probe-level toggle plumbing in:
   - `System/Testing/vp_perf_probe_single_action_latency.R`
   - New CLI flag: `--perf-boundary-markers=true|false` (default `false`).
   - Probe now sets env and options for marker mode:
      - `VP_PERF_BOUNDARY_MARKERS`
      - `options(vp_perf_boundary_markers, rice_perf_boundary_markers)`
   - Probe output CSV and acceptance-manifest row now include `perf_boundary_markers_enabled` for provenance.
6. Added decomposition compatibility for boundary markers in:
   - `System/Testing/vp_perf_decompose_single_action_8c.R`
   - `classify_bucket()` now recognizes boundary tags under `client_lifecycle` (additive only).
   - `resolve_action_start()` now prefers `client_perf|boundary_action_begin` when boundary markers are present.
   - `resolve_visible_milestone()` now accepts `action_start_ts` and prefers boundary milestones (`boundary_visible_ready`, fallback `boundary_tab_after_paint`) after action start when markers are present.
   - `derive_window_boundary_quality()` treats boundary-derived action/visible sources as high-confidence primary sources.
7. Blocker encountered and resolved during 8D smoke execution:
   - Initial probe execution failed because `Rscript` was unavailable on PATH in shell context.
   - Resolved by using explicit executable path:
      - `C:/Program Files/R/R-4.5.1/bin/Rscript.exe`
   - This blocker is environmental, not code-related.
8. Perturbation smoke runs executed (tab-only scenario; warm session):
   - Boundary markers OFF:
      - Label: `tranche8d_boundary_off_smoke`
      - Output: `Logs/vp_perf_probe_single_action_latency_tranche8d_boundary_off_smoke_20260804T150934Z.csv`
      - Runtime log: `Logs/vp_runtime_perf_single_action_tranche8d_boundary_off_smoke_20260804T150935Z.jsonl`
      - Status counts: `FAIL=1|PASS=3`
      - Noted failure reason: `visible_not_ready:timeout` (heatmap action in this single diagnostic pass).
   - Boundary markers ON (initial):
      - Label: `tranche8d_boundary_on_smoke`
      - Output: `Logs/vp_perf_probe_single_action_latency_tranche8d_boundary_on_smoke_20260804T151418Z.csv`
      - Runtime log: `Logs/vp_runtime_perf_single_action_tranche8d_boundary_on_smoke_20260804T151418Z.jsonl`
      - Status counts: `PASS=4`
      - Boundary-tag count check: OFF log `0`, ON log `24`.
9. Bug found and fixed during 8D instrumentation rollout:
   - Symptom: `boundary_visible_ready` markers were missing in first ON validation run.
   - Root cause: overly strict UI-side readiness gate required non-zero widget/SVG counts; some tabs satisfy visual readiness without matching that exact structure at marker time.
   - Fix: relax `visible_ready` emit condition to `target present + visible` (marker-only change; no UI behavior changes).
10. Post-fix validation reruns:
   - ON rerun v2:
      - Label: `tranche8d_boundary_on_smoke_v2`
      - Output: `Logs/vp_perf_probe_single_action_latency_tranche8d_boundary_on_smoke_v2_20260804T152300Z.csv`
      - Runtime log: `Logs/vp_runtime_perf_single_action_tranche8d_boundary_on_smoke_v2_20260804T152300Z.jsonl`
      - Status: `PASS=4`
      - Verified new server boundary tags present; `visible_ready` still absent in this run.
   - ON rerun v3 (after readiness-condition relaxation):
      - Label: `tranche8d_boundary_on_smoke_v3`
      - Output: `Logs/vp_perf_probe_single_action_latency_tranche8d_boundary_on_smoke_v3_20260804T152624Z.csv`
      - Runtime log: `Logs/vp_runtime_perf_single_action_tranche8d_boundary_on_smoke_v3_20260804T152625Z.jsonl`
      - Status: `PASS=4`
      - Boundary tag distribution:
         - `boundary_action_begin=12`
         - `boundary_tab_click_dispatched=4`
         - `boundary_tab_shown=4`
         - `boundary_tab_after_paint=4`
         - `boundary_visible_ready=4`
         - `boundary_server_main_tabs_observer_complete=5`
         - `boundary_server_plotly_resize_recorded=5`
         - `boundary_server_summary_table_complete=4`
11. Decomposition smoke verification of boundary-source uptake:
   - Built exact-path two-row inventory (baseline OFF vs candidate ON-v3):
      - `Logs/vp_perf_acceptance_inventory_tranche8d_boundary_smoke_v3_20260804.csv`
   - Ran decomposition:
      - Label: `tranche8d_boundary_smoke_v3`
      - Outputs:
         - `Logs/vp_perf_acceptance_decomposition_tranche8d_boundary_smoke_v3_20260804T152940Z_detail.csv`
         - `Logs/vp_perf_acceptance_decomposition_tranche8d_boundary_smoke_v3_20260804T152940Z_summary.csv`
         - `Logs/vp_perf_acceptance_decomposition_tranche8d_boundary_smoke_v3_20260804T152940Z_runs.csv`
         - `Logs/vp_perf_acceptance_decomposition_tranche8d_boundary_smoke_v3_20260804T152940Z_inconclusive_gate.csv`
         - `Logs/vp_perf_acceptance_decomposition_tranche8d_boundary_smoke_v3_20260804T152940Z_window_confidence.csv`
         - `Logs/vp_perf_acceptance_decomposition_tranche8d_boundary_smoke_v3_20260804T152940Z_summary.json`
   - Provenance confirmation from `_runs.csv`:
      - baseline/off run: `action_start_source=observeevent_data_source_choice`, `visible_milestone_source=client_main_tabs_mount`
      - candidate/on-v3 run: `action_start_source=client_boundary_action_begin`, `visible_milestone_source=client_boundary_tab_after_paint`
      - both retained `window_boundary_confidence=high` in this smoke pair.
12. Tranche 8D status:
   - Complete for instrumentation discovery/implementation smoke scope.
   - Explicit boundary events now exist and are feature-gated, probe-toggleable, logged through runtime telemetry, and consumed by decomposition boundary-source resolution.
   - No production-default behavior changes introduced; marker mode remains opt-in and disabled by default.

Tranche 8D interpretation update:
1. Boundary instrumentation materially improves provenance specificity for start/visible milestones when enabled, without changing decomposition hard-fail or inconclusive-gate semantics.
2. Evidence quality is improved for attribution interpretation because action/visible boundaries can now be tied to explicit client/server transition markers rather than broad fallbacks.
3. A single OFF diagnostic smoke had one heatmap visible-ready timeout; ON/v2/v3 runs all passed in this narrow sample. This is insufficient for acceptance claims and should be treated as diagnostic variance until replicated across controlled paired lanes.

Execution update addendum (Tranche 8D - same-revision OFF vs ON final check):
1. Re-ran OFF lane after final instrumentation patches to keep perturbation evidence on same code revision:
   - Label: `tranche8d_boundary_off_smoke_v3`
   - Output: `Logs/vp_perf_probe_single_action_latency_tranche8d_boundary_off_smoke_v3_20260804T153156Z.csv`
   - Runtime log: `Logs/vp_runtime_perf_single_action_tranche8d_boundary_off_smoke_v3_20260804T153157Z.jsonl`
   - Status counts: `PASS=4`
   - Boundary-tag count check: `0`
2. ON lane reference (final marker wiring):
   - Label: `tranche8d_boundary_on_smoke_v3`
   - Output: `Logs/vp_perf_probe_single_action_latency_tranche8d_boundary_on_smoke_v3_20260804T152624Z.csv`
   - Runtime log: `Logs/vp_runtime_perf_single_action_tranche8d_boundary_on_smoke_v3_20260804T152625Z.jsonl`
   - Status counts: `PASS=4`
   - Boundary tags present with expected families (client + server + visible-ready).
3. Final same-revision perturbation timing comparison (tab-only action set; warm session):
   - Visible-ready delta (`ON - OFF`) by action:
      - `tab_settled_historical_trend`: `-488` ms
      - `tab_settled_heatmap`: `-1030` ms
      - `tab_settled_map`: `-3971` ms
      - `tab_settled_current`: `+1629` ms
   - Aggregate visible-ready delta:
      - mean: `-965` ms
      - median: `-759` ms
   - Interpretation: no evidence of marker-induced slowdown in this narrow smoke; variability remains action-dependent and sample size is too small for acceptance claims.
4. Final exact-path decomposition smoke for same-revision OFF vs ON-v3:
   - Inventory: `Logs/vp_perf_acceptance_inventory_tranche8d_boundary_smoke_final_20260804.csv`
   - Label: `tranche8d_boundary_smoke_final`
   - Outputs:
      - `Logs/vp_perf_acceptance_decomposition_tranche8d_boundary_smoke_final_20260804T153459Z_detail.csv`
      - `Logs/vp_perf_acceptance_decomposition_tranche8d_boundary_smoke_final_20260804T153459Z_summary.csv`
      - `Logs/vp_perf_acceptance_decomposition_tranche8d_boundary_smoke_final_20260804T153459Z_runs.csv`
      - `Logs/vp_perf_acceptance_decomposition_tranche8d_boundary_smoke_final_20260804T153459Z_inconclusive_gate.csv`
      - `Logs/vp_perf_acceptance_decomposition_tranche8d_boundary_smoke_final_20260804T153459Z_window_confidence.csv`
      - `Logs/vp_perf_acceptance_decomposition_tranche8d_boundary_smoke_final_20260804T153459Z_summary.json`
5. Final provenance confirmation from final `_runs.csv`:
   - OFF baseline:
      - `action_start_source=observeevent_data_source_choice`
      - `visible_milestone_source=client_main_tabs_mount`
   - ON candidate:
      - `action_start_source=client_boundary_action_begin`
      - `visible_milestone_source=client_boundary_tab_after_paint`
   - Both runs retained `window_boundary_confidence=high` with `window_boundary_warning_reason=ok_primary_sources`.
6. Tranche 8D closure note:
   - Initial OFF heatmap timeout did not reproduce on same-revision OFF rerun and is now recorded as transient diagnostic variance.
   - 8D remains diagnostic instrumentation work; acceptance-grade claims still require paired multi-run lane replication and statistical summarization.
7. Post-addendum refinement and verification:
   - Refined decomposition visible-milestone precedence in `System/Testing/vp_perf_decompose_single_action_8c.R` so boundary mode prefers `boundary_visible_ready` over `boundary_tab_after_paint` when both are present after action start.
   - Re-ran same-revision final decomposition:
      - Label: `tranche8d_boundary_smoke_final_v2`
      - Outputs:
         - `Logs/vp_perf_acceptance_decomposition_tranche8d_boundary_smoke_final_v2_20260804T153715Z_detail.csv`
         - `Logs/vp_perf_acceptance_decomposition_tranche8d_boundary_smoke_final_v2_20260804T153715Z_summary.csv`
         - `Logs/vp_perf_acceptance_decomposition_tranche8d_boundary_smoke_final_v2_20260804T153715Z_runs.csv`
         - `Logs/vp_perf_acceptance_decomposition_tranche8d_boundary_smoke_final_v2_20260804T153715Z_inconclusive_gate.csv`
         - `Logs/vp_perf_acceptance_decomposition_tranche8d_boundary_smoke_final_v2_20260804T153715Z_window_confidence.csv`
         - `Logs/vp_perf_acceptance_decomposition_tranche8d_boundary_smoke_final_v2_20260804T153715Z_summary.json`
   - Final provenance confirmation from v2 `_runs.csv`:
      - OFF baseline remained `action_start_source=observeevent_data_source_choice`, `visible_milestone_source=client_main_tabs_mount`.
      - ON candidate advanced to `action_start_source=client_boundary_action_begin`, `visible_milestone_source=client_boundary_visible_ready`.

Execution update (Tranche 8E - Step 26 marker passthrough wiring and startup parity):
1. Implemented pair-runner boundary marker passthrough in `System/Testing/vp_perf_run_acceptance_pair.R`:
   - Added pair-level CLI flag parse: `--perf-boundary-markers=true|false` (default `false`).
   - Added runner telemetry line: `VP_PERF_ACCEPTANCE_PAIR_PERF_BOUNDARY_MARKERS=TRUE|FALSE`.
   - Passed `perf-boundary-markers` to both startup probe calls.
   - Passed `perf-boundary-markers` to both single-action probe calls.
2. Implemented startup probe marker toggle parity in `System/Testing/vp_perf_probe_startup.R`:
   - Added startup CLI parse: `--perf-boundary-markers=true|false` (default `false`).
   - Wired runtime env toggle: `VP_PERF_BOUNDARY_MARKERS`.
   - Wired runtime options parity:
      - `options(vp_perf_boundary_markers=..., rice_perf_boundary_markers=...)`
   - Added startup probe telemetry line:
      - `VP_PERF_STARTUP_PERF_BOUNDARY_MARKERS_ENABLED=TRUE|FALSE`.
   - Added startup output field: `perf_boundary_markers_enabled`.
   - Added startup acceptance-manifest field: `perf_boundary_markers_enabled`.
3. Static diagnostics:
   - `System/Testing/vp_perf_run_acceptance_pair.R`: no errors.
   - `System/Testing/vp_perf_probe_startup.R`: no errors.
4. OFF smoke run executed (clean-room pair; marker mode false):
   - Command:
      - `C:/Program Files/R/R-4.5.1/bin/Rscript.exe System/Testing/vp_perf_run_acceptance_pair.R --label=tranche8e_marker_passthrough_off_smoke --iterations=1 --runtime-perf=true --perf-boundary-markers=false --manifest-clean-room=true --manifest-clean-room-dir=Logs --strict-manifest=true --acceptance-only=true --rscript="C:/Program Files/R/R-4.5.1/bin/Rscript.exe"`
   - Pair metadata:
      - `VP_PERF_ACCEPTANCE_PAIR_RUN_ID=tranche8e_marker_passthrough_off_smoke_20260804T160611Z`
      - clean-room manifest:
         - `Logs/vp_perf_acceptance_run_manifest_tranche8e_marker_passthrough_off_smoke_20260804T160611Z.csv`
         - `Logs/vp_perf_acceptance_run_manifest_tranche8e_marker_passthrough_off_smoke_20260804T160611Z.jsonl`
   - Manifest row verification (all rows present, marker field carried):
      - startup baseline/candidate rows: `status=PASS`, `perf_boundary_markers_enabled=FALSE`.
      - single-action baseline/candidate rows: `status=PASS=4`, `perf_boundary_markers_enabled=FALSE`.
   - Runtime boundary-tag verification (single-action logs):
      - `Logs/vp_runtime_perf_single_action_tranche8e_marker_passthrough_off_smoke__baseline__single_action_iter01_20260804T160904Z.jsonl`: `boundary_count=0`
      - `Logs/vp_runtime_perf_single_action_tranche8e_marker_passthrough_off_smoke__candidate__single_action_iter01_20260804T161128Z.jsonl`: `boundary_count=0`
   - Decision stage output:
      - `Logs/vp_perf_acceptance_decision_tranche8e_marker_passthrough_off_smoke__decision_20260804T161403Z_summary.csv`
      - `Logs/vp_perf_acceptance_decision_tranche8e_marker_passthrough_off_smoke__decision_20260804T161403Z_details.csv`
      - `Logs/vp_perf_acceptance_decision_tranche8e_marker_passthrough_off_smoke__decision_20260804T161403Z_decision.csv`
      - expected `FAIL` due `min_runs` gate (`iterations=1`, threshold `9`); this is diagnostic and expected.
5. ON smoke run executed (clean-room pair; marker mode true):
   - Command:
      - `C:/Program Files/R/R-4.5.1/bin/Rscript.exe System/Testing/vp_perf_run_acceptance_pair.R --label=tranche8e_marker_passthrough_on_smoke --iterations=1 --runtime-perf=true --perf-boundary-markers=true --manifest-clean-room=true --manifest-clean-room-dir=Logs --strict-manifest=true --acceptance-only=true --rscript="C:/Program Files/R/R-4.5.1/bin/Rscript.exe"`
   - Pair metadata:
      - `VP_PERF_ACCEPTANCE_PAIR_RUN_ID=tranche8e_marker_passthrough_on_smoke_20260804T161405Z`
      - clean-room manifest:
         - `Logs/vp_perf_acceptance_run_manifest_tranche8e_marker_passthrough_on_smoke_20260804T161405Z.csv`
         - `Logs/vp_perf_acceptance_run_manifest_tranche8e_marker_passthrough_on_smoke_20260804T161405Z.jsonl`
   - Manifest row verification (all rows present, marker field carried):
      - startup baseline/candidate rows: `status=PASS`, `perf_boundary_markers_enabled=TRUE`.
      - single-action baseline/candidate rows: `status=PASS=4`, `perf_boundary_markers_enabled=TRUE`.
   - Runtime boundary-tag verification (single-action logs):
      - `Logs/vp_runtime_perf_single_action_tranche8e_marker_passthrough_on_smoke__baseline__single_action_iter01_20260804T161705Z.jsonl`: `boundary_count=42`
      - `Logs/vp_runtime_perf_single_action_tranche8e_marker_passthrough_on_smoke__candidate__single_action_iter01_20260804T161934Z.jsonl`: `boundary_count=42`
   - Decision stage output:
      - `Logs/vp_perf_acceptance_decision_tranche8e_marker_passthrough_on_smoke__decision_20260804T162152Z_summary.csv`
      - `Logs/vp_perf_acceptance_decision_tranche8e_marker_passthrough_on_smoke__decision_20260804T162152Z_details.csv`
      - `Logs/vp_perf_acceptance_decision_tranche8e_marker_passthrough_on_smoke__decision_20260804T162152Z_decision.csv`
      - expected `FAIL` due `min_runs` gate (`iterations=1`, threshold `9`); this is diagnostic and expected.
6. Startup output schema parity verification:
   - Verified startup output CSV now includes `perf_boundary_markers_enabled`.
   - Verified this field appears in both OFF and ON startup output files.
7. Tranche 8E Step 26 status:
   - Complete for marker passthrough wiring and startup parity.
   - OFF/ON toggle behavior is now controllable from the pair runner and reflected in startup/single-action outputs and manifests.
   - Boundary-tag behavior matches expected mode:
      - OFF: zero boundary tags in single-action runtime logs.
      - ON: boundary tags present in single-action runtime logs.
8. Remaining 8E work not yet implemented in this step:
   - strict context validation beyond current manifest-core checks,
   - runtime-log identity validation (content-level run/session/probe binding),
   - dedicated manifest-to-inventory helper or fully codified manual inventory recipe,
   - replicated multi-iteration OFF/ON cohorts and decomposition/audit comparisons.

Execution update (Tranche 8E - Step 27 Phase 3 preflight/context + runtime-log identity validation):
1. Implemented shared Phase 3 validators in `System/Testing/vp_perf_acceptance_manifest.R`:
   - Added context/status helper utilities:
      - `vp_perf_normalize_bool(...)`
      - `vp_perf_status_is_clean(...)`
   - Added pair manifest preflight/context validator:
      - `vp_perf_validate_pair_manifest_context(...)`
      - Validates one manifest row per expected `(probe_type, run_id, session_id)`.
      - Enforces acceptance-mode rows, label/scenario/cache-state parity, runtime/perf-boundary-marker parity, clean status/base_status, and runtime/output file presence + nonzero size.
      - Emits row-level reasons (e.g., `manifest_row_missing`, `scenario_mismatch`, `status_not_clean`, `runtime_log_missing`).
   - Added runtime-log content identity validator:
      - `vp_perf_validate_runtime_log_identity(...)`
      - Parses JSONL records and validates content-level identity binding using per-record fields:
         - `probe_run_id`
         - `probe_session_id`
         - `probe_type`
         - `probe_label`
      - Also validates runtime log parse health and file integrity (`exists`, `nonzero`, parsed records present).
      - Emits explicit reason tokens (e.g., `probe_run_id_no_match`, `probe_session_id_mismatch`, `probe_type_missing`).
2. Added runtime-record identity fields at emission source in `Programs/app_source/global.R`:
   - Added `runtime_perf_probe_identity_payload()`.
   - `runtime_perf_record(...)` now includes probe identity payload in every runtime JSONL record when runtime perf is enabled:
      - `probe_run_id`
      - `probe_session_id`
      - `probe_type`
      - `probe_label`
      - `probe_cache_state`
3. Added probe-side identity env wiring so runtime logs carry deterministic probe metadata:
   - `System/Testing/vp_perf_probe_startup.R` now sets:
      - `VP_PERF_PROBE_TYPE=startup`
      - `VP_PERF_PROBE_LABEL=<label>`
      - `VP_PERF_CACHE_STATE=<cache_state>`
   - `System/Testing/vp_perf_probe_single_action_latency.R` now sets:
      - `VP_PERF_PROBE_TYPE=single_action`
      - `VP_PERF_PROBE_LABEL=<label>`
      - `VP_PERF_CACHE_STATE=<cache_state>`
4. Wired strict preflight/context + identity gate into pair orchestration before decision stage in `System/Testing/vp_perf_run_acceptance_pair.R`:
   - Imported shared manifest module.
   - Added expected-context builder for deterministic pair rows:
      - `build_expected_context_rows(...)`
   - Added Phase 3 preflight executor:
      - `run_phase3_preflight(...)`
      - Loads clean-room manifest rows for current `pair_run_id` and probes (`startup`, `single_action`).
      - Runs context validator + runtime identity validator and aggregates results.
   - Added new runner args:
      - `--strict-context-validation=true|false` (default `true`)
      - `--strict-runtime-identity=true|false` (default `true`)
   - Added new pair telemetry:
      - `VP_PERF_ACCEPTANCE_PAIR_STRICT_CONTEXT_VALIDATION`
      - `VP_PERF_ACCEPTANCE_PAIR_STRICT_RUNTIME_IDENTITY`
      - `VP_PERF_ACCEPTANCE_PAIR_PREFLIGHT_MANIFEST_PATH`
      - `VP_PERF_ACCEPTANCE_PAIR_PREFLIGHT_MANIFEST_ROWS`
      - `VP_PERF_ACCEPTANCE_PAIR_PREFLIGHT_EXPECTED_ROWS`
      - `VP_PERF_ACCEPTANCE_PAIR_PREFLIGHT_CONTEXT_STATUS`
      - `VP_PERF_ACCEPTANCE_PAIR_PREFLIGHT_CONTEXT_FAIL_COUNT`
      - `VP_PERF_ACCEPTANCE_PAIR_PREFLIGHT_IDENTITY_STATUS`
      - `VP_PERF_ACCEPTANCE_PAIR_PREFLIGHT_IDENTITY_FAIL_COUNT`
      - plus conditional `..._CONTEXT_ERRORS` and `..._IDENTITY_ERRORS` payload lines.
   - Added fail-fast behavior:
      - pair run now stops before invoking `vp_perf_acceptance_decision.R` if strict preflight/context or strict runtime identity validation fails.
5. Static diagnostics:
   - No errors in changed files:
      - `System/Testing/vp_perf_acceptance_manifest.R`
      - `System/Testing/vp_perf_run_acceptance_pair.R`
      - `System/Testing/vp_perf_probe_startup.R`
      - `System/Testing/vp_perf_probe_single_action_latency.R`
      - `Programs/app_source/global.R`
6. Validation run (ON smoke, clean-room, strict Phase 3 gates enabled):
   - Command:
      - `C:/Program Files/R/R-4.5.1/bin/Rscript.exe System/Testing/vp_perf_run_acceptance_pair.R --label=tranche8e_phase3_preflight_identity_smoke --iterations=1 --runtime-perf=true --perf-boundary-markers=true --manifest-clean-room=true --manifest-clean-room-dir=Logs --strict-manifest=true --strict-context-validation=true --strict-runtime-identity=true --acceptance-only=true --rscript="C:/Program Files/R/R-4.5.1/bin/Rscript.exe"`
   - Pair run id:
      - `tranche8e_phase3_preflight_identity_smoke_20260804T163117Z`
   - Clean-room manifest:
      - `Logs/vp_perf_acceptance_run_manifest_tranche8e_phase3_preflight_identity_smoke_20260804T163117Z.csv`
      - `Logs/vp_perf_acceptance_run_manifest_tranche8e_phase3_preflight_identity_smoke_20260804T163117Z.jsonl`
   - Preflight telemetry outcome:
      - `VP_PERF_ACCEPTANCE_PAIR_PREFLIGHT_MANIFEST_ROWS=4`
      - `VP_PERF_ACCEPTANCE_PAIR_PREFLIGHT_EXPECTED_ROWS=4`
      - `VP_PERF_ACCEPTANCE_PAIR_PREFLIGHT_CONTEXT_STATUS=PASS`
      - `VP_PERF_ACCEPTANCE_PAIR_PREFLIGHT_CONTEXT_FAIL_COUNT=0`
      - `VP_PERF_ACCEPTANCE_PAIR_PREFLIGHT_IDENTITY_STATUS=PASS`
      - `VP_PERF_ACCEPTANCE_PAIR_PREFLIGHT_IDENTITY_FAIL_COUNT=0`
   - Decision stage executed after preflight pass (expected overall `FAIL` at iterations=1 due `min_runs=9`).
7. Validation run (OFF smoke, clean-room, strict Phase 3 gates enabled):
   - Command:
      - `C:/Program Files/R/R-4.5.1/bin/Rscript.exe System/Testing/vp_perf_run_acceptance_pair.R --label=tranche8e_phase3_preflight_identity_smoke_off --iterations=1 --runtime-perf=true --perf-boundary-markers=false --manifest-clean-room=true --manifest-clean-room-dir=Logs --strict-manifest=true --strict-context-validation=true --strict-runtime-identity=true --acceptance-only=true --rscript="C:/Program Files/R/R-4.5.1/bin/Rscript.exe"`
   - Pair run id:
      - `tranche8e_phase3_preflight_identity_smoke_off_20260804T163852Z`
   - Clean-room manifest:
      - `Logs/vp_perf_acceptance_run_manifest_tranche8e_phase3_preflight_identity_smoke_off_20260804T163852Z.csv`
      - `Logs/vp_perf_acceptance_run_manifest_tranche8e_phase3_preflight_identity_smoke_off_20260804T163852Z.jsonl`
   - Preflight telemetry outcome:
      - `VP_PERF_ACCEPTANCE_PAIR_PREFLIGHT_MANIFEST_ROWS=4`
      - `VP_PERF_ACCEPTANCE_PAIR_PREFLIGHT_EXPECTED_ROWS=4`
      - `VP_PERF_ACCEPTANCE_PAIR_PREFLIGHT_CONTEXT_STATUS=PASS`
      - `VP_PERF_ACCEPTANCE_PAIR_PREFLIGHT_CONTEXT_FAIL_COUNT=0`
      - `VP_PERF_ACCEPTANCE_PAIR_PREFLIGHT_IDENTITY_STATUS=PASS`
      - `VP_PERF_ACCEPTANCE_PAIR_PREFLIGHT_IDENTITY_FAIL_COUNT=0`
   - Decision stage executed after preflight pass (expected overall `FAIL` at iterations=1 due `min_runs=9`).
8. Step 27 status:
   - Complete: strict Phase 3 preflight/context gate and runtime-log content identity validation are now enforced before decisioning in pair orchestration.
   - The gate is proven to pass in both ON and OFF marker smoke runs under clean-room manifests.
9. Remaining 8E work after Step 27:
   - dedicated manifest-to-inventory helper or fully codified manual inventory recipe for replicated cohorts,
   - replicated multi-iteration OFF/ON cohorts under strict preflight/identity gates,
   - decomposition (`Step 25C`) and attribution audit (`Step 25D`) comparisons on replicated OFF/ON evidence.

Execution update (Tranche 8E - Step 28 replicated strict OFF/ON inventory, decomposition, and audit):
1. Replicated strict OFF cohort completed before this update and is now captured as source evidence:
   - Pair label: `tranche8e_phase3_preflight_identity_cohort_off_i9`.
   - Manifest:
      - `Logs/vp_perf_acceptance_run_manifest_tranche8e_phase3_preflight_identity_cohort_off_i9_20260804T165614Z.csv`
   - Decision artifacts:
      - `Logs/vp_perf_acceptance_decision_tranche8e_phase3_preflight_identity_cohort_off_i9__decision_20260804T181530Z_summary.csv`
      - `Logs/vp_perf_acceptance_decision_tranche8e_phase3_preflight_identity_cohort_off_i9__decision_20260804T181530Z_details.csv`
      - `Logs/vp_perf_acceptance_decision_tranche8e_phase3_preflight_identity_cohort_off_i9__decision_20260804T181530Z_decision.csv`
   - Evidence status:
      - manifest rows: `36` (`9` iterations x baseline/candidate x startup/single-action),
      - strict context preflight: `PASS`, fail count `0`,
      - strict runtime identity preflight: `PASS`, fail count `0`,
      - decision: `FAIL` due statistical/threshold decisioning, not due preflight or identity failure.
2. Replicated strict ON cohort required one recovery loop before usable evidence:
   - Initial ON i9 run exposed a strict preflight context failure on one non-clean row:
      - `tranche8e_phase3_preflight_identity_cohort_on_i9_20260804T181543Z__baseline__iter02__single_action`
      - manifest status mix: `FAIL=1|PASS=3`, base status mix: `PARTIAL=1|PASS=3`,
      - probe error payload included `visible_not_ready:timeout || acceptance_mode_partial_disallowed`.
   - Focused retry of the failing ON single-action path passed (`PASS=4`).
   - Full ON i9 rerun then completed with strict gates passing:
      - Pair label: `tranche8e_phase3_preflight_identity_cohort_on_i9_rerun`.
      - Manifest:
         - `Logs/vp_perf_acceptance_run_manifest_tranche8e_phase3_preflight_identity_cohort_on_i9_rerun_20260804T193603Z.csv`
      - Decision artifacts:
         - `Logs/vp_perf_acceptance_decision_tranche8e_phase3_preflight_identity_cohort_on_i9_rerun__decision_20260804T204525Z_summary.csv`
         - `Logs/vp_perf_acceptance_decision_tranche8e_phase3_preflight_identity_cohort_on_i9_rerun__decision_20260804T204525Z_details.csv`
         - `Logs/vp_perf_acceptance_decision_tranche8e_phase3_preflight_identity_cohort_on_i9_rerun__decision_20260804T204525Z_decision.csv`
      - Evidence status:
         - manifest rows: `36`,
         - strict context preflight: `PASS`, fail count `0`,
         - strict runtime identity preflight: `PASS`, fail count `0`,
         - decision: `FAIL` due statistical/threshold decisioning, not due preflight or identity failure.
3. Rejected brittle ad hoc inventory construction after a failed PowerShell attempt:
   - Symptom: repeated `Method invocation failed because [System.Management.Automation.PSObject] does not contain a method named 'op_Addition'.`
   - Root cause: `$rows += [pscustomobject]...` inside a function was not reliable for this generated inventory flow.
   - Decision: replace one-off PowerShell row accumulation with a reusable R helper that emits the existing Step 25B-compatible inventory schema.
4. Added reusable manifest-to-inventory helper:
   - New script:
      - `System/Testing/vp_perf_acceptance_manifest_to_inventory.R`
   - Inputs:
      - `--index=<csv>` with one row per evidence cohort,
      - `--label=<label>`,
      - `--app-ref=<reference>`,
      - `--include-startup=true|false`.
   - Output contract:
      - Emits the full required Step 25B inventory columns, including manifest/runtime/output/decision file existence and nonzero checks, comparison validity fields, role inference, and `integrity_status` / `integrity_reason`.
      - Adds optional interpretation columns `marker_mode` and `marker_lane` while preserving the existing validator convention that `lane` equals the cache-state lane.
5. Helper validation and fix loop:
   - First helper run produced a structurally complete inventory with `72` rows and `72` helper-level OK rows, but Step 25B quarantined all rows:
      - validation reason: `cache_state_mismatch`,
      - cause: the initial index used marker lanes (`marker_off`, `marker_on`) in `lane`, while the existing validator expects `comparison_validity_cache_state == lane`.
   - Fix applied:
      - kept `lane=warm_partition_disk`,
      - added marker interpretation via `marker_mode=off|on` and `marker_lane=marker_off|marker_on`,
      - kept OFF/ON separation through `pair_run_label`, which Step 25C/25D already preserve in grouping keys.
6. Final Step 28 index and inventory artifacts:
   - Index:
      - `Logs/vp_perf_acceptance_index_tranche8e_off_on_i9_phase3_strict_20260804.csv`
   - Final helper output:
      - `Logs/vp_perf_acceptance_inventory_tranche8e_off_on_i9_phase3_strict_20260804T205358Z.csv`
      - `Logs/vp_perf_acceptance_inventory_tranche8e_off_on_i9_phase3_strict_20260804T205358Z.json`
   - Helper terminal summary:
      - rows: `72`,
      - OK rows: `72`,
      - quarantine rows: `0`.
7. Step 25B validation on final inventory:
   - Command used:
      - `C:/Program Files/R/R-4.5.1/bin/Rscript.exe System/Testing/vp_perf_validate_inventory_step25b_8c.R --inventory=Logs/vp_perf_acceptance_inventory_tranche8e_off_on_i9_phase3_strict_20260804T205358Z.csv --label=tranche8e_off_on_i9_phase3_strict_validation`
   - Result:
      - total rows: `72`,
      - OK rows: `72`,
      - quarantine rows: `0`.
   - Validation artifacts:
      - `Logs/vp_perf_acceptance_inventory_validation_tranche8e_off_on_i9_phase3_strict_validation_20260804T205404Z_detail.csv`
      - `Logs/vp_perf_acceptance_inventory_validation_tranche8e_off_on_i9_phase3_strict_validation_20260804T205404Z_summary.csv`
      - `Logs/vp_perf_acceptance_inventory_validation_tranche8e_off_on_i9_phase3_strict_validation_20260804T205404Z_reasons.csv`
      - `Logs/vp_perf_acceptance_inventory_validation_tranche8e_off_on_i9_phase3_strict_validation_20260804T205404Z_lane_counts.csv`
      - `Logs/vp_perf_acceptance_inventory_validation_tranche8e_off_on_i9_phase3_strict_validation_20260804T205404Z_probe_counts.csv`
      - `Logs/vp_perf_acceptance_inventory_validation_tranche8e_off_on_i9_phase3_strict_validation_20260804T205404Z_role_counts.csv`
      - `Logs/vp_perf_acceptance_inventory_validation_tranche8e_off_on_i9_phase3_strict_validation_20260804T205404Z_lane_probe_role_counts.csv`
      - `Logs/vp_perf_acceptance_inventory_validation_tranche8e_off_on_i9_phase3_strict_validation_20260804T205404Z.json`
8. Step 25C decomposition on final validated inventory:
   - Command used:
      - `C:/Program Files/R/R-4.5.1/bin/Rscript.exe System/Testing/vp_perf_decompose_single_action_8c.R --inventory=Logs/vp_perf_acceptance_inventory_tranche8e_off_on_i9_phase3_strict_20260804T205358Z.csv --label=tranche8e_off_on_i9_phase3_strict`
   - Result:
      - selected rows: `36` single-action rows,
      - detail rows: `20698`,
      - run rows: `36`,
      - summary rows: `96`.
   - Decomposition artifacts:
      - `Logs/vp_perf_acceptance_decomposition_tranche8e_off_on_i9_phase3_strict_20260804T205414Z_detail.csv`
      - `Logs/vp_perf_acceptance_decomposition_tranche8e_off_on_i9_phase3_strict_20260804T205414Z_summary.csv`
      - `Logs/vp_perf_acceptance_decomposition_tranche8e_off_on_i9_phase3_strict_20260804T205414Z_runs.csv`
      - `Logs/vp_perf_acceptance_decomposition_tranche8e_off_on_i9_phase3_strict_20260804T205414Z_inconclusive_gate.csv`
      - `Logs/vp_perf_acceptance_decomposition_tranche8e_off_on_i9_phase3_strict_20260804T205414Z_window_confidence.csv`
      - `Logs/vp_perf_acceptance_decomposition_tranche8e_off_on_i9_phase3_strict_20260804T205414Z_summary.json`
9. Step 25C action-window interpretation from the replicated strict OFF/ON evidence:
   - OFF action-window total attributed time:
      - baseline: `479318.0 ms`,
      - candidate: `441223.4 ms`.
   - ON rerun action-window total attributed time:
      - baseline: `315287.3 ms`,
      - candidate: `300084.8 ms`.
   - Boundary marker identity improvement is visible in runtime source fields:
      - OFF baseline/candidate action start source: `observeevent_data_source_choice`; visible milestone source: `client_main_tabs_mount`.
      - ON baseline/candidate action start source: `client_boundary_action_begin`; visible milestone source: `client_boundary_visible_ready`.
10. Step 25C confidence caveat:
   - The action window itself was not marked inconclusive:
      - action-window inconclusive count: `0`,
      - action-window inconclusive share: `0.000000`.
   - The run-level inconclusive gate still flagged most runs because unclassified/action attribution share remained above the default threshold:
      - overall inconclusive run count: `35` of `36`, share `0.972222`,
      - lane/role inconclusive rows: `4` of `4`, share `1.000000`.
   - Role-level run confidence summary:
      - OFF baseline: `9/9` inconclusive, mean bucket confidence `0.7087`, mean unclassified share `0.2745`.
      - OFF candidate: `9/9` inconclusive, mean bucket confidence `0.7032`, mean unclassified share `0.2803`.
      - ON rerun baseline: `9/9` inconclusive, mean bucket confidence `0.7490`, mean unclassified share `0.2310`.
      - ON rerun candidate: `8/9` inconclusive, mean bucket confidence `0.7667`, mean unclassified share `0.2150`.
   - Interpretation:
      - Boundary markers materially improve attribution boundary source quality and lower action-window attributed totals in this evidence set.
      - The strict decision should not claim full attribution confidence yet because the default run-level inconclusive gate is still dominated by unclassified share.
11. Step 25D exact-path attribution audit completed:
   - Command used exact Step 25C output paths for detail, summary, runs, window-confidence, and inconclusive-gate inputs.
   - Audit artifacts:
      - `Logs/vp_perf_acceptance_decomposition_tranche8e_off_on_i9_phase3_strict_audit_20260804T205836Z_classification_audit.csv`
      - `Logs/vp_perf_acceptance_decomposition_tranche8e_off_on_i9_phase3_strict_audit_20260804T205836Z_window_bucket.csv`
      - `Logs/vp_perf_acceptance_decomposition_tranche8e_off_on_i9_phase3_strict_audit_20260804T205836Z_confidence_comparison.csv`
      - `Logs/vp_perf_acceptance_decomposition_tranche8e_off_on_i9_phase3_strict_audit_20260804T205836Z_audit_summary.json`
12. Documentation and analysis command notes:
   - Two inline `Rscript -e` summary attempts failed during plan-prep because nested PowerShell/R quoting stripped or misread `$` column references and CSV path quoting.
   - The failed summary attempts did not affect generated evidence artifacts; the compact summary was instead produced with `Import-Csv` over the already-written Step 25C outputs.
13. Step 28 status:
   - Complete for the accepted recommendation:
      - helper implemented,
      - replicated strict OFF/ON i9 evidence inventoried,
      - inventory validated by Step 25B,
      - Step 25C decomposition run,
      - Step 25D audit run,
      - confidence caveats recorded.
14. Remaining 8E work after Step 28:
   - Decide whether to refine attribution classification / unclassified-share thresholds before treating Step 25C run-level gates as acceptance-grade.
   - Optionally run additional replicated OFF/ON cohorts only after deciding whether the next question is statistical stability or attribution-classification completeness.
   - Continue architecture work with the strict preflight/identity gate enabled for all future acceptance pair runs.

Summary in plain terms:
- We now have a reusable way to turn strict acceptance manifests into the inventory files used by the decomposition/audit tools.
- The existing replicated OFF and ON cohorts are no longer loose log piles; they are validated, exact-path evidence sets.
- The ON boundary markers are working and improve the action-boundary source fields, but the attribution classifier still leaves enough time unclassified that the evidence should be treated as diagnostic/decomposition evidence rather than final acceptance proof.

Execution update (Tranche 8F - Step 29 attribution classifier refinement pass 1 on frozen strict OFF/ON i9 corpus):
1. Scope and controls for this step:
   - Objective: reduce attribution ambiguity on the existing strict OFF/ON i9 evidence by classifier refinement only.
   - Fixed corpus reused without regeneration:
      - `Logs/vp_perf_acceptance_inventory_tranche8e_off_on_i9_phase3_strict_20260804T205358Z.csv`.
   - Guardrails held constant:
      - no new cohorts,
      - no threshold changes,
      - no window-resolution changes,
      - no gap-allocation logic changes,
      - no Step 25D aggregation/schema changes.
2. Baseline diagnostic snapshot captured before edits from existing Step 28 artifacts:
   - Baseline decomposition summary (`tranche8e_off_on_i9_phase3_strict`):
      - selected rows: `36`,
      - detail rows: `20698`,
      - run rows: `36`,
      - inconclusive run count/share: `35/36` (`0.9722`),
      - inconclusive lane count/share: `4/4` (`1.0000`).
   - Dominant unclassified signatures by total attributed ms (from Step 25D classification audit):
      - `client_perf||tab_shown||||tab_shown` (`1356771 ms`),
      - `log_perf||summary_table||||summary_table` (`122432.3003 ms`),
      - `client_perf||boundary_server_summary_table_complete||||boundary_server_summary_table_complete` (`55117.9998 ms`),
      - `log_perf||historical_avg()||||historical_avg()` (`34612.3996 ms`),
      - `log_perf||observeEvent(source_or_trade_flow -> custom_panel_reconcile)||||observeEvent(source_or_trade_flow -> custom_panel_reconcile)` (`34242.6 ms`),
      - `log_perf||projection_data()||||projection_data()` (`31053.2010 ms`),
      - `log_perf||reconcile_custom_comparison_non_metric_targets()||||reconcile_custom_comparison_non_metric_targets()` (`29680.1995 ms`),
      - `log_perf||pace_historical_avg()||||pace_historical_avg()` (`22273.6997 ms`),
      - `log_perf||current_year_data()||||current_year_data()` (`10637.1004 ms`),
      - `log_perf||most_recent()||||most_recent()` (`5100.4996 ms`).
   - Dominant multi-match signatures by total attributed ms:
      - `log_perf||filter_vp_rows_for_resolved_hierarchy()||||filter_vp_rows_for_resolved_hierarchy()` (`97436.4002 ms`),
      - `cache_body_execution||||filter_vp_rows_for_resolved_hierarchy_mixed_volume_family_check||` (`10372.9992 ms`),
      - `cache_body_execution||||filter_vp_rows_for_resolved_hierarchy_type_choice_base_values||` (`7813.0007 ms`).
3. Implementation edits applied in `System/Testing/vp_perf_decompose_single_action_8c.R`:
   - Refined `classify_bucket(...)` with narrow event/tag/signature-oriented coverage for high-impact unclassified patterns:
      - mapped `tab_shown` family into `client_lifecycle`,
      - mapped summary/materialization markers (`summary_table`, `boundary_server_summary_table_complete`, `historical_avg()`, `projection_data()`, `pace_historical_avg()`, `current_year_data()`, `most_recent()`, `reconcile_custom_comparison_non_metric_targets()`) into `tab_server_materialization`,
      - mapped `observeEvent(source_or_trade_flow -> custom_panel_reconcile)` and selected hierarchy context markers into `hierarchy_fanout`,
      - mapped startup-load data init signatures (`hybrid_data_init(...)`, `wasde_data_init(...)`, `nass_data_init(...)`, `psd_data_init(...)`) into `carryover_startup_load`.
   - Added targeted collision handling:
      - removed known `provider_filter`/`hierarchy_fanout` overlap for `filter_vp_rows_for_resolved_hierarchy*` signatures,
      - resolved `boundary_server_summary_table_complete` dual-match toward `tab_server_materialization`.
   - Preserved output schema and surrounding decomposition mechanics.
4. Failed attempt and correction during implementation:
   - Initial malformed `apply_patch` hunk caused an unintended duplicate block around `classify_bucket(...)`.
   - Detected immediately by source re-read.
   - Corrected with a full function replacement patch in the next edit.
   - Final parse and diagnostics confirmed script health after correction.
5. Static diagnostics and parse guard:
   - Parse command:
      - `C:/Program Files/R/R-4.5.1/bin/Rscript.exe -e "parse(file='System/Testing/vp_perf_decompose_single_action_8c.R'); cat('PARSE_OK\\n')"`
   - Result:
      - `PARSE_OK`.
   - Diagnostics:
      - no errors in `System/Testing/vp_perf_decompose_single_action_8c.R`.
6. Step 25B rerun on unchanged frozen inventory:
   - Command:
      - `C:/Program Files/R/R-4.5.1/bin/Rscript.exe System/Testing/vp_perf_validate_inventory_step25b_8c.R --inventory=Logs/vp_perf_acceptance_inventory_tranche8e_off_on_i9_phase3_strict_20260804T205358Z.csv --label=tranche8e_off_on_i9_phase3_strict_validation_refine1`
   - Result:
      - total rows: `72`,
      - OK rows: `72`,
      - quarantine rows: `0`.
   - Validation artifacts:
      - `Logs/vp_perf_acceptance_inventory_validation_tranche8e_off_on_i9_phase3_strict_validation_refine1_20260804T211510Z_detail.csv`
      - `Logs/vp_perf_acceptance_inventory_validation_tranche8e_off_on_i9_phase3_strict_validation_refine1_20260804T211510Z_summary.csv`
      - `Logs/vp_perf_acceptance_inventory_validation_tranche8e_off_on_i9_phase3_strict_validation_refine1_20260804T211510Z_reasons.csv`
      - `Logs/vp_perf_acceptance_inventory_validation_tranche8e_off_on_i9_phase3_strict_validation_refine1_20260804T211510Z_lane_counts.csv`
      - `Logs/vp_perf_acceptance_inventory_validation_tranche8e_off_on_i9_phase3_strict_validation_refine1_20260804T211510Z_probe_counts.csv`
      - `Logs/vp_perf_acceptance_inventory_validation_tranche8e_off_on_i9_phase3_strict_validation_refine1_20260804T211510Z_role_counts.csv`
      - `Logs/vp_perf_acceptance_inventory_validation_tranche8e_off_on_i9_phase3_strict_validation_refine1_20260804T211510Z_lane_probe_role_counts.csv`
      - `Logs/vp_perf_acceptance_inventory_validation_tranche8e_off_on_i9_phase3_strict_validation_refine1_20260804T211510Z.json`
7. Step 25C rerun (`refine1`) on the same inventory:
   - Command:
      - `C:/Program Files/R/R-4.5.1/bin/Rscript.exe System/Testing/vp_perf_decompose_single_action_8c.R --inventory=Logs/vp_perf_acceptance_inventory_tranche8e_off_on_i9_phase3_strict_20260804T205358Z.csv --label=tranche8e_off_on_i9_phase3_strict_refine1`
   - Result:
      - selected rows: `36`,
      - detail rows: `20752`,
      - run rows: `36`,
      - summary rows: `96`,
      - inconclusive run count/share: `0/36` (`0.000000`),
      - inconclusive lane count/share: `0/4` (`0.000000`).
   - Artifacts:
      - `Logs/vp_perf_acceptance_decomposition_tranche8e_off_on_i9_phase3_strict_refine1_20260804T211513Z_detail.csv`
      - `Logs/vp_perf_acceptance_decomposition_tranche8e_off_on_i9_phase3_strict_refine1_20260804T211513Z_summary.csv`
      - `Logs/vp_perf_acceptance_decomposition_tranche8e_off_on_i9_phase3_strict_refine1_20260804T211513Z_runs.csv`
      - `Logs/vp_perf_acceptance_decomposition_tranche8e_off_on_i9_phase3_strict_refine1_20260804T211513Z_inconclusive_gate.csv`
      - `Logs/vp_perf_acceptance_decomposition_tranche8e_off_on_i9_phase3_strict_refine1_20260804T211513Z_window_confidence.csv`
      - `Logs/vp_perf_acceptance_decomposition_tranche8e_off_on_i9_phase3_strict_refine1_20260804T211513Z_summary.json`
8. Step 25D rerun (`refine1_audit`) on exact Step 25C outputs:
   - Command:
      - `C:/Program Files/R/R-4.5.1/bin/Rscript.exe System/Testing/vp_perf_step25d_attribution_audit_8c.R --detail=Logs/vp_perf_acceptance_decomposition_tranche8e_off_on_i9_phase3_strict_refine1_20260804T211513Z_detail.csv --summary=Logs/vp_perf_acceptance_decomposition_tranche8e_off_on_i9_phase3_strict_refine1_20260804T211513Z_summary.csv --runs=Logs/vp_perf_acceptance_decomposition_tranche8e_off_on_i9_phase3_strict_refine1_20260804T211513Z_runs.csv --window-confidence=Logs/vp_perf_acceptance_decomposition_tranche8e_off_on_i9_phase3_strict_refine1_20260804T211513Z_window_confidence.csv --inconclusive-gate=Logs/vp_perf_acceptance_decomposition_tranche8e_off_on_i9_phase3_strict_refine1_20260804T211513Z_inconclusive_gate.csv --label=tranche8e_off_on_i9_phase3_strict_refine1_audit`
   - Audit artifacts:
      - `Logs/vp_perf_acceptance_decomposition_tranche8e_off_on_i9_phase3_strict_refine1_audit_20260804T212046Z_classification_audit.csv`
      - `Logs/vp_perf_acceptance_decomposition_tranche8e_off_on_i9_phase3_strict_refine1_audit_20260804T212046Z_window_bucket.csv`
      - `Logs/vp_perf_acceptance_decomposition_tranche8e_off_on_i9_phase3_strict_refine1_audit_20260804T212046Z_confidence_comparison.csv`
      - `Logs/vp_perf_acceptance_decomposition_tranche8e_off_on_i9_phase3_strict_refine1_audit_20260804T212046Z_audit_summary.json`
9. Optional Step 25C rollup executed:
   - Command:
      - `C:/Program Files/R/R-4.5.1/bin/Rscript.exe System/Testing/vp_perf_step25c_bucket_rollup_8c.R --runs=Logs/vp_perf_acceptance_decomposition_tranche8e_off_on_i9_phase3_strict_refine1_20260804T211513Z_runs.csv --summary=Logs/vp_perf_acceptance_decomposition_tranche8e_off_on_i9_phase3_strict_refine1_20260804T211513Z_summary.csv --label=tranche8e_off_on_i9_phase3_strict_refine1_rollup`
   - Rollup artifacts:
      - `Logs/vp_perf_acceptance_decomposition_tranche8e_off_on_i9_phase3_strict_refine1_rollup_20260804T212049Z_action_bucket.csv`
      - `Logs/vp_perf_acceptance_decomposition_tranche8e_off_on_i9_phase3_strict_refine1_rollup_20260804T212049Z_lane_delta.csv`
      - `Logs/vp_perf_acceptance_decomposition_tranche8e_off_on_i9_phase3_strict_refine1_rollup_20260804T212049Z_lane_confidence.csv`
10. Deterministic before/after comparison (PowerShell `Import-Csv` method):
   - Run inconclusive:
      - before: `35/36`,
      - after: `0/36`.
   - Role-group run means (`bucket_confidence`, `unclassified_attributed_share`):
      - OFF baseline: `0.708704` / `0.274545` -> `0.995660` / `0.002761`.
      - OFF candidate: `0.703191` / `0.280260` -> `0.996223` / `0.002330`.
      - ON rerun baseline: `0.749037` / `0.230963` -> `0.994538` / `0.002306`.
      - ON rerun candidate: `0.766688` / `0.214992` -> `0.995120` / `0.001931`.
   - Observed-event shares (excluding synthetic `gap_allocation` rows):
      - OFF baseline: observed unclassified share `0.275729 -> 0.002769`; observed multi-match share `0.016814 -> 0.001522`.
      - OFF candidate: observed unclassified share `0.277845 -> 0.002315`; observed multi-match share `0.016445 -> 0.001431`.
      - ON rerun baseline: observed unclassified share `0.231374 -> 0.002294`; observed multi-match share `0.020025 -> 0.003147`.
      - ON rerun candidate: observed unclassified share `0.213618 -> 0.001921`; observed multi-match share `0.018309 -> 0.002972`.
11. Remaining high-impact signatures after pass 1:
   - Unclassified top residuals:
      - `cache_body_execution||||custom_countries_enriched||` (`9701.9997 ms`),
      - `log_perf||country_choice_ui()||||country_choice_ui()` (`3876.2 ms`),
      - `log_perf||pace_census_anchor_info()||||pace_census_anchor_info()` (`1331.7 ms`).
   - Multi-match top residuals:
      - `cache_body_execution||||filter_vp_rows_for_resolved_hierarchy_mixed_volume_family_check||` (`10372.9992 ms`),
      - `cache_key_delta||||filter_vp_rows_for_resolved_hierarchy_mixed_volume_family_check||` (`4288.0001 ms`).
12. Step 29 decision and confidence notes:
   - Classifier-first pass succeeded under fixed evidence and unchanged thresholds.
   - Run-level and lane-level inconclusive gates are now clear in this corpus.
   - Major ambiguity reductions came from explicit remapping of formerly dominant unclassified signatures and resolving known provider/hierarchy overlap on key filter signatures.
   - Synthetic wait and gap-warning signals remain present (action-window gap and synthetic-wait warning shares remain `1.0000`), so the result should still be interpreted as attribution quality improvement, not proof that runtime path complexity disappeared.
13. Handoff recommendation after Step 29:
   - Proceed to one small hardening pass only if needed for residual signatures (`custom_countries_enriched`, `country_choice_ui`, `pace_census_anchor_info`, remaining hierarchy-related multi-match cache-body/cache-key signatures).
   - If no further classifier hardening is required, run a fresh replicated OFF/ON cohort on unchanged thresholds to verify the improved measurement layer is stable on new evidence.

Summary in plain terms:
- Tranche 8F pass 1 successfully improved the attribution ruler on the exact same strict OFF/ON i9 evidence without changing thresholds or rerunning cohorts.
- The largest unclassified and multi-match contributors were largely removed from the critical path, and inconclusive run gating cleared in this corpus.
- Remaining work is now focused on residual signature cleanup and confirming stability on a fresh cohort rather than broad decomposition logic changes.

Execution update (Tranche 8F - Step 30 tiny residual hardening pass on frozen strict OFF/ON i9 corpus):
1. Scope and controls for this pass:
   - Objective: perform one final narrow classifier hardening pass for the residual signatures identified in Step 29.
   - Frozen corpus reused unchanged:
      - `Logs/vp_perf_acceptance_inventory_tranche8e_off_on_i9_phase3_strict_20260804T205358Z.csv`.
   - Guardrails held constant:
      - no cohort regeneration,
      - no threshold changes,
      - no decomposition window/gap logic changes,
      - no Step 25D schema or aggregation changes.
2. Tiny classifier edits applied in `System/Testing/vp_perf_decompose_single_action_8c.R`:
   - Added explicit hierarchy mapping for residual unclassified signatures:
      - `country_choice_ui`,
      - `pace_census_anchor_info`.
   - Broadened `custom_countries_enriched` matcher to accept optional `()` suffix:
      - from `custom_countries_enriched()` only
      - to `custom_countries_enriched` and `custom_countries_enriched()` forms.
   - Added one targeted collision rule:
      - when `filter_vp_rows_for_resolved_hierarchy*` is present and both `provider_filter` + `display_unit_mixed` match, force attribution to `provider_filter` (drop `display_unit_mixed`) to remove residual multi-match churn.
   - Preserved all other classifier/decomposition behavior.
3. Parse and diagnostics guardrails:
   - Parse command:
      - `C:/Program Files/R/R-4.5.1/bin/Rscript.exe -e "invisible(parse(file='System/Testing/vp_perf_decompose_single_action_8c.R')); cat('PARSE_OK\\n')"`
   - Result:
      - `PARSE_OK`.
   - Diagnostics:
      - no errors in `System/Testing/vp_perf_decompose_single_action_8c.R`.
4. Step 25B rerun on the same frozen inventory (`refine2`):
   - Command:
      - `C:/Program Files/R/R-4.5.1/bin/Rscript.exe System/Testing/vp_perf_validate_inventory_step25b_8c.R --inventory=Logs/vp_perf_acceptance_inventory_tranche8e_off_on_i9_phase3_strict_20260804T205358Z.csv --label=tranche8e_off_on_i9_phase3_strict_validation_refine2`
   - Result:
      - total rows: `72`,
      - OK rows: `72`,
      - quarantine rows: `0`.
   - Artifacts:
      - `Logs/vp_perf_acceptance_inventory_validation_tranche8e_off_on_i9_phase3_strict_validation_refine2_20260804T212543Z_detail.csv`
      - `Logs/vp_perf_acceptance_inventory_validation_tranche8e_off_on_i9_phase3_strict_validation_refine2_20260804T212543Z_summary.csv`
      - `Logs/vp_perf_acceptance_inventory_validation_tranche8e_off_on_i9_phase3_strict_validation_refine2_20260804T212543Z_reasons.csv`
      - `Logs/vp_perf_acceptance_inventory_validation_tranche8e_off_on_i9_phase3_strict_validation_refine2_20260804T212543Z_lane_counts.csv`
      - `Logs/vp_perf_acceptance_inventory_validation_tranche8e_off_on_i9_phase3_strict_validation_refine2_20260804T212543Z_probe_counts.csv`
      - `Logs/vp_perf_acceptance_inventory_validation_tranche8e_off_on_i9_phase3_strict_validation_refine2_20260804T212543Z_role_counts.csv`
      - `Logs/vp_perf_acceptance_inventory_validation_tranche8e_off_on_i9_phase3_strict_validation_refine2_20260804T212543Z_lane_probe_role_counts.csv`
      - `Logs/vp_perf_acceptance_inventory_validation_tranche8e_off_on_i9_phase3_strict_validation_refine2_20260804T212543Z.json`
5. Step 25C rerun on the same inventory (`refine2`):
   - Command:
      - `C:/Program Files/R/R-4.5.1/bin/Rscript.exe System/Testing/vp_perf_decompose_single_action_8c.R --inventory=Logs/vp_perf_acceptance_inventory_tranche8e_off_on_i9_phase3_strict_20260804T205358Z.csv --label=tranche8e_off_on_i9_phase3_strict_refine2`
   - Result:
      - selected rows: `36`,
      - detail rows: `20752`,
      - run rows: `36`,
      - summary rows: `96`,
      - inconclusive run count/share: `0/36` (`0.000000`),
      - inconclusive lane count/share: `0/4` (`0.000000`).
   - Artifacts:
      - `Logs/vp_perf_acceptance_decomposition_tranche8e_off_on_i9_phase3_strict_refine2_20260804T212549Z_detail.csv`
      - `Logs/vp_perf_acceptance_decomposition_tranche8e_off_on_i9_phase3_strict_refine2_20260804T212549Z_summary.csv`
      - `Logs/vp_perf_acceptance_decomposition_tranche8e_off_on_i9_phase3_strict_refine2_20260804T212549Z_runs.csv`
      - `Logs/vp_perf_acceptance_decomposition_tranche8e_off_on_i9_phase3_strict_refine2_20260804T212549Z_inconclusive_gate.csv`
      - `Logs/vp_perf_acceptance_decomposition_tranche8e_off_on_i9_phase3_strict_refine2_20260804T212549Z_window_confidence.csv`
      - `Logs/vp_perf_acceptance_decomposition_tranche8e_off_on_i9_phase3_strict_refine2_20260804T212549Z_summary.json`
6. Step 25D rerun on exact `refine2` outputs:
   - Command:
      - `C:/Program Files/R/R-4.5.1/bin/Rscript.exe System/Testing/vp_perf_step25d_attribution_audit_8c.R --detail=Logs/vp_perf_acceptance_decomposition_tranche8e_off_on_i9_phase3_strict_refine2_20260804T212549Z_detail.csv --summary=Logs/vp_perf_acceptance_decomposition_tranche8e_off_on_i9_phase3_strict_refine2_20260804T212549Z_summary.csv --runs=Logs/vp_perf_acceptance_decomposition_tranche8e_off_on_i9_phase3_strict_refine2_20260804T212549Z_runs.csv --window-confidence=Logs/vp_perf_acceptance_decomposition_tranche8e_off_on_i9_phase3_strict_refine2_20260804T212549Z_window_confidence.csv --inconclusive-gate=Logs/vp_perf_acceptance_decomposition_tranche8e_off_on_i9_phase3_strict_refine2_20260804T212549Z_inconclusive_gate.csv --label=tranche8e_off_on_i9_phase3_strict_refine2_audit`
   - Artifacts:
      - `Logs/vp_perf_acceptance_decomposition_tranche8e_off_on_i9_phase3_strict_refine2_audit_20260804T213150Z_classification_audit.csv`
      - `Logs/vp_perf_acceptance_decomposition_tranche8e_off_on_i9_phase3_strict_refine2_audit_20260804T213150Z_window_bucket.csv`
      - `Logs/vp_perf_acceptance_decomposition_tranche8e_off_on_i9_phase3_strict_refine2_audit_20260804T213150Z_confidence_comparison.csv`
      - `Logs/vp_perf_acceptance_decomposition_tranche8e_off_on_i9_phase3_strict_refine2_audit_20260804T213150Z_audit_summary.json`
7. Deterministic residual-signature delta (`refine1` -> `refine2`):
   - `custom_countries_enriched` unclassified attributed total:
      - `9701.9997 ms` -> `0.0000 ms`.
   - `country_choice_ui` bucket assignment:
      - unclassified `3876.2 ms` -> hierarchy_fanout `3876.2 ms`.
   - `pace_census_anchor_info` bucket assignment:
      - unclassified `1331.7 ms` -> hierarchy_fanout `1331.7 ms`.
   - `filter_vp_rows_for_resolved_hierarchy_mixed_volume_family_check` multi-match attributed total:
      - `14660.9993 ms` -> `0.0000 ms`.
8. Deterministic share delta (`refine1` -> `refine2`):
   - Overall observed-event unclassified share (excluding `gap_allocation`):
      - `0.0023082` -> `0.0002006`.
   - Overall observed-event multi-match share:
      - `0.0023193` -> `0.0000000`.
   - Pair/role observed shares:
      - OFF baseline: unclassified `0.0027688 -> 0.0000970`; multi-match `0.0015223 -> 0.0000000`.
      - OFF candidate: unclassified `0.0023147 -> 0.0001050`; multi-match `0.0014306 -> 0.0000000`.
      - ON baseline: unclassified `0.0022938 -> 0.0002962`; multi-match `0.0031471 -> 0.0000000`.
      - ON candidate: unclassified `0.0019213 -> 0.0002737`; multi-match `0.0029720 -> 0.0000000`.
   - Pair/role run means:
      - OFF baseline: bucket confidence `0.995660 -> 0.999901`; mean unclassified share `0.0027608 -> 0.0000987`.
      - OFF candidate: bucket confidence `0.996223 -> 0.999894`; mean unclassified share `0.0023296 -> 0.0001055`.
      - ON baseline: bucket confidence `0.994538 -> 0.999705`; mean unclassified share `0.0023062 -> 0.0002954`.
      - ON candidate: bucket confidence `0.995120 -> 0.999728`; mean unclassified share `0.0019308 -> 0.0002723`.
   - Inconclusive runs remained `0/36` in both refine passes.
9. Residual signatures after pass 2:
   - Top nonzero unclassified signatures now:
      - `client_perf||boundary_server_main_tabs_observer_complete||||boundary_server_main_tabs_observer_complete` (`791.0 ms`),
      - `log_perf||observe(panel commodity correction)||||observe(panel commodity correction)` (`495.9 ms`),
      - `log_perf||apply_custom_comparison_panel_targets()||||apply_custom_comparison_panel_targets()` (`139.1 ms`),
      - `log_perf||observeEvent(data_source_choice:psd_entry_ui_updates)||||observeEvent(data_source_choice:psd_entry_ui_updates)` (`22.4 ms`).
   - No nonzero multi-match signatures remained in `refine2` classification audit.
10. Failed attempt and correction during Step 30 analysis extraction:
   - Initial PowerShell comparison one-liner failed with:
      - `An empty pipe element is not allowed.`
   - Corrected by refactoring into explicit intermediate variables before formatting/output steps.
11. Step 30 decision:
   - This final tiny hardening pass achieved the intended residual cleanup objective on the frozen corpus while preserving all gating and threshold settings.
   - Classifier quality is now materially tighter than Step 29 pass 1, with observed multi-match effectively eliminated and unclassified shares reduced by another order of magnitude.

Summary in plain terms:
- The final tiny hardening pass did exactly what it was supposed to do: it removed the remaining high-impact residual ambiguity without changing the evidence set or moving thresholds.
- The main leftover unclassified time is now small and concentrated in a short, explicit list of low-volume signatures.
- The measurement layer for this corpus is now in a handoff-ready state for fresh OFF/ON cohort confirmation runs.

Execution update (Tranche 8G - fresh strict OFF/ON cohort confirmation on unchanged thresholds):
1. Scope and controls for this tranche:
   - Objective: confirm that Step 30 measurement-layer cleanup holds on fresh replicated evidence.
   - Thresholds and decision controls held unchanged:
      - `min-runs=9`,
      - `startup-improvement-min=0.25`,
      - `single-action-improvement-min=0.20`,
      - `max-mad-ratio=0.60`,
      - `bootstrap-reps=2000`,
      - `confidence=0.95`,
      - `bootstrap-seed=1`.
   - Strict controls held enabled throughout:
      - clean-room manifests,
      - strict manifest validation,
      - strict context preflight,
      - strict runtime identity preflight,
      - acceptance-only mode.
2. Fresh strict OFF cohort status (already completed before this tranche update):
   - Pair label: `tranche8g_phase3_preflight_identity_cohort_off_i9_fresh`.
   - Manifest:
      - `Logs/vp_perf_acceptance_run_manifest_tranche8g_phase3_preflight_identity_cohort_off_i9_fresh_20260804T214449Z.csv`
   - Decision artifacts:
      - `Logs/vp_perf_acceptance_decision_tranche8g_phase3_preflight_identity_cohort_off_i9_fresh__decision_20260804T225103Z_summary.csv`
      - `Logs/vp_perf_acceptance_decision_tranche8g_phase3_preflight_identity_cohort_off_i9_fresh__decision_20260804T225103Z_details.csv`
      - `Logs/vp_perf_acceptance_decision_tranche8g_phase3_preflight_identity_cohort_off_i9_fresh__decision_20260804T225103Z_decision.csv`
   - Integrity and decision status:
      - strict context preflight `PASS` (`0` fails),
      - strict runtime identity `PASS` (`0` fails),
      - decision `FAIL` from threshold/CI gates (not from preflight/identity).
3. Fresh strict ON cohort failure and recovery loop:
   - Initial ON run (`tranche8g_phase3_preflight_identity_cohort_on_i9_fresh`) halted pre-decision with:
      - `VP_PERF_ACCEPTANCE_PAIR_PREFLIGHT_CONTEXT_STATUS=FAIL`,
      - `VP_PERF_ACCEPTANCE_PAIR_PREFLIGHT_CONTEXT_FAIL_COUNT=1`,
      - context errors: `status_not_clean|base_status_not_clean`.
   - Failing manifest row isolated in:
      - `Logs/vp_perf_acceptance_run_manifest_tranche8g_phase3_preflight_identity_cohort_on_i9_fresh_20260804T225115Z.csv`
   - Failing row details:
      - `probe_type=single_action`,
      - `run_id=tranche8g_phase3_preflight_identity_cohort_on_i9_fresh_20260804T225115Z__candidate__iter04__single_action`,
      - `status=FAIL=1|PASS=3`,
      - `base_status=PARTIAL=1|PASS=3`.
   - Recovery action:
      - full ON fresh rerun with unchanged controls and thresholds:
      - label `tranche8g_phase3_preflight_identity_cohort_on_i9_fresh_rerun`.
   - ON rerun outputs:
      - manifest:
         - `Logs/vp_perf_acceptance_run_manifest_tranche8g_phase3_preflight_identity_cohort_on_i9_fresh_rerun_20260804T235927Z.csv`
      - decision artifacts:
         - `Logs/vp_perf_acceptance_decision_tranche8g_phase3_preflight_identity_cohort_on_i9_fresh_rerun__decision_20260805T010718Z_summary.csv`
         - `Logs/vp_perf_acceptance_decision_tranche8g_phase3_preflight_identity_cohort_on_i9_fresh_rerun__decision_20260805T010718Z_details.csv`
         - `Logs/vp_perf_acceptance_decision_tranche8g_phase3_preflight_identity_cohort_on_i9_fresh_rerun__decision_20260805T010718Z_decision.csv`
   - ON rerun integrity and decision status:
      - strict context preflight `PASS` (`0` fails),
      - strict runtime identity `PASS` (`0` fails),
      - decision `FAIL` from threshold/CI gates (not from preflight/identity).
4. Fresh OFF/ON index and inventory generation:
   - Created fresh OFF/ON index:
      - `Logs/vp_perf_acceptance_index_tranche8g_off_on_i9_phase3_strict_fresh_20260805.csv`
      - lane held as `warm_partition_disk` for Step 25B schema compatibility,
      - marker interpretation carried in `marker_mode=off|on` and `marker_lane=marker_off|marker_on`.
   - Ran helper:
      - `System/Testing/vp_perf_acceptance_manifest_to_inventory.R`
   - Helper outputs:
      - `Logs/vp_perf_acceptance_inventory_tranche8g_off_on_i9_phase3_strict_fresh_20260805T010816Z.csv`
      - `Logs/vp_perf_acceptance_inventory_tranche8g_off_on_i9_phase3_strict_fresh_20260805T010816Z.json`
   - Helper summary:
      - rows `72`,
      - helper `ok_rows=72`,
      - helper `quarantine_rows=0`.
5. Step 25B validation on fresh inventory:
   - Command:
      - `C:/Program Files/R/R-4.5.1/bin/Rscript.exe System/Testing/vp_perf_validate_inventory_step25b_8c.R --inventory=Logs/vp_perf_acceptance_inventory_tranche8g_off_on_i9_phase3_strict_fresh_20260805T010816Z.csv --label=tranche8g_off_on_i9_phase3_strict_fresh_validation`
   - Result:
      - total rows `72`,
      - `ok_rows=72`,
      - `quarantine_rows=0`.
   - Artifacts:
      - `Logs/vp_perf_acceptance_inventory_validation_tranche8g_off_on_i9_phase3_strict_fresh_validation_20260805T010820Z_detail.csv`
      - `Logs/vp_perf_acceptance_inventory_validation_tranche8g_off_on_i9_phase3_strict_fresh_validation_20260805T010820Z_summary.csv`
      - `Logs/vp_perf_acceptance_inventory_validation_tranche8g_off_on_i9_phase3_strict_fresh_validation_20260805T010820Z_reasons.csv`
      - `Logs/vp_perf_acceptance_inventory_validation_tranche8g_off_on_i9_phase3_strict_fresh_validation_20260805T010820Z_lane_counts.csv`
      - `Logs/vp_perf_acceptance_inventory_validation_tranche8g_off_on_i9_phase3_strict_fresh_validation_20260805T010820Z_probe_counts.csv`
      - `Logs/vp_perf_acceptance_inventory_validation_tranche8g_off_on_i9_phase3_strict_fresh_validation_20260805T010820Z_role_counts.csv`
      - `Logs/vp_perf_acceptance_inventory_validation_tranche8g_off_on_i9_phase3_strict_fresh_validation_20260805T010820Z_lane_probe_role_counts.csv`
      - `Logs/vp_perf_acceptance_inventory_validation_tranche8g_off_on_i9_phase3_strict_fresh_validation_20260805T010820Z.json`
6. Step 25C decomposition on fresh validated inventory:
   - Command:
      - `C:/Program Files/R/R-4.5.1/bin/Rscript.exe System/Testing/vp_perf_decompose_single_action_8c.R --inventory=Logs/vp_perf_acceptance_inventory_tranche8g_off_on_i9_phase3_strict_fresh_20260805T010816Z.csv --label=tranche8g_off_on_i9_phase3_strict_fresh`
   - Result:
      - selected rows `36` (single_action),
      - detail rows `20754`,
      - run rows `36`,
      - summary rows `96`,
      - inconclusive run count/share `0/36` (`0.000000`),
      - inconclusive lane count/share `0/4` (`0.000000`),
      - action-window inconclusive count/share `0/36` (`0.000000`).
   - Artifacts:
      - `Logs/vp_perf_acceptance_decomposition_tranche8g_off_on_i9_phase3_strict_fresh_20260805T010825Z_detail.csv`
      - `Logs/vp_perf_acceptance_decomposition_tranche8g_off_on_i9_phase3_strict_fresh_20260805T010825Z_summary.csv`
      - `Logs/vp_perf_acceptance_decomposition_tranche8g_off_on_i9_phase3_strict_fresh_20260805T010825Z_runs.csv`
      - `Logs/vp_perf_acceptance_decomposition_tranche8g_off_on_i9_phase3_strict_fresh_20260805T010825Z_inconclusive_gate.csv`
      - `Logs/vp_perf_acceptance_decomposition_tranche8g_off_on_i9_phase3_strict_fresh_20260805T010825Z_window_confidence.csv`
      - `Logs/vp_perf_acceptance_decomposition_tranche8g_off_on_i9_phase3_strict_fresh_20260805T010825Z_summary.json`
7. Step 25D exact-path attribution audit on fresh Step 25C outputs:
   - Command:
      - `C:/Program Files/R/R-4.5.1/bin/Rscript.exe System/Testing/vp_perf_step25d_attribution_audit_8c.R --detail=Logs/vp_perf_acceptance_decomposition_tranche8g_off_on_i9_phase3_strict_fresh_20260805T010825Z_detail.csv --summary=Logs/vp_perf_acceptance_decomposition_tranche8g_off_on_i9_phase3_strict_fresh_20260805T010825Z_summary.csv --runs=Logs/vp_perf_acceptance_decomposition_tranche8g_off_on_i9_phase3_strict_fresh_20260805T010825Z_runs.csv --window-confidence=Logs/vp_perf_acceptance_decomposition_tranche8g_off_on_i9_phase3_strict_fresh_20260805T010825Z_window_confidence.csv --inconclusive-gate=Logs/vp_perf_acceptance_decomposition_tranche8g_off_on_i9_phase3_strict_fresh_20260805T010825Z_inconclusive_gate.csv --label=tranche8g_off_on_i9_phase3_strict_fresh_audit`
   - Artifacts:
      - `Logs/vp_perf_acceptance_decomposition_tranche8g_off_on_i9_phase3_strict_fresh_audit_20260805T011301Z_classification_audit.csv`
      - `Logs/vp_perf_acceptance_decomposition_tranche8g_off_on_i9_phase3_strict_fresh_audit_20260805T011301Z_window_bucket.csv`
      - `Logs/vp_perf_acceptance_decomposition_tranche8g_off_on_i9_phase3_strict_fresh_audit_20260805T011301Z_confidence_comparison.csv`
      - `Logs/vp_perf_acceptance_decomposition_tranche8g_off_on_i9_phase3_strict_fresh_audit_20260805T011301Z_audit_summary.json`
8. Fresh-evidence decision metric snapshot (unchanged thresholds):
   - OFF (`tranche8g_phase3_preflight_identity_cohort_off_i9_fresh`):
      - startup improvement ratio `0.026428` vs threshold `0.250000` (FAIL), CI `[-0.055335, 0.094248]`.
      - single-action improvement ratio `-0.025307` vs threshold `0.200000` (FAIL), CI `[-0.117371, 0.056714]`.
   - ON rerun (`tranche8g_phase3_preflight_identity_cohort_on_i9_fresh_rerun`):
      - startup improvement ratio `-0.004473` vs threshold `0.250000` (FAIL), CI `[-0.090712, 0.089795]`.
      - single-action improvement ratio `-0.018535` vs threshold `0.200000` (FAIL), CI `[-0.146126, 0.085559]`.
9. Fresh-evidence measurement-layer stability snapshot:
   - Step 25C run-level confidence remains high and stable on fresh evidence:
      - mean run `bucket_confidence=0.999814`,
      - mean run `unclassified_attributed_share=0.000186`,
      - max run `unclassified_attributed_share=0.000317`.
   - Inconclusive gate file confirms zero lane-role inconclusive groups (`0/4`).
   - `multi_match` residual remained eliminated in fresh detail outputs (`0` rows, `0 ms` total attributed).
   - Boundary source behavior remains clean and mode-consistent:
      - OFF runs: action source `observeevent_data_source_choice`, visible source `client_main_tabs_mount`.
      - ON rerun runs: action source `client_boundary_action_begin`, visible source `client_boundary_visible_ready`.
10. Tranche 8G decision:
   - The Step 30 measurement-layer cleanup holds on fresh strict OFF/ON evidence under unchanged thresholds and strict controls.
   - Acceptance performance gates continue to fail for this cohort pair, but failure reason remains performance-threshold/CI shortfall rather than evidence-integrity or attribution-quality collapse.
   - ON strict recovery loop is now documented and repeatable: isolate non-clean row, rerun fresh ON cohort, then proceed with index -> inventory -> Step 25B -> Step 25C -> Step 25D.

Summary in plain terms:
- Fresh strict OFF and ON evidence reproduced the same measurement quality improvements seen on the frozen corpus.
- The hardening remained stable: inconclusive gates stayed clear and multi-match remained effectively eliminated.
- The remaining blockers are still performance-threshold outcomes, not instrumentation or attribution integrity.

Execution update (Tranche 8H - fresh Step 25C bucket rollup and next-target recommendation):
1. Scope and inputs:
   - Objective: use the fresh Step 25C outputs from Tranche 8G to identify the next implementation target from action-window bucket evidence.
   - Input runs:
      - `Logs/vp_perf_acceptance_decomposition_tranche8g_off_on_i9_phase3_strict_fresh_20260805T010825Z_runs.csv`
   - Input summary:
      - `Logs/vp_perf_acceptance_decomposition_tranche8g_off_on_i9_phase3_strict_fresh_20260805T010825Z_summary.csv`
2. Rollup command executed:
   - `C:/Program Files/R/R-4.5.1/bin/Rscript.exe System/Testing/vp_perf_step25c_bucket_rollup_8c.R --runs=Logs/vp_perf_acceptance_decomposition_tranche8g_off_on_i9_phase3_strict_fresh_20260805T010825Z_runs.csv --summary=Logs/vp_perf_acceptance_decomposition_tranche8g_off_on_i9_phase3_strict_fresh_20260805T010825Z_summary.csv --label=tranche8g_off_on_i9_phase3_strict_fresh_rollup`
3. Rollup artifacts emitted:
   - `Logs/vp_perf_acceptance_decomposition_tranche8g_off_on_i9_phase3_strict_fresh_rollup_20260805T130922Z_action_bucket.csv`
   - `Logs/vp_perf_acceptance_decomposition_tranche8g_off_on_i9_phase3_strict_fresh_rollup_20260805T130922Z_lane_delta.csv`
   - `Logs/vp_perf_acceptance_decomposition_tranche8g_off_on_i9_phase3_strict_fresh_rollup_20260805T130922Z_lane_confidence.csv`
4. Rollup confidence check:
   - run count: `36`,
   - mean bucket confidence: `0.999814`,
   - max unclassified attributed time: `67.9 ms`.
   - This confirms the fresh bucket rollup is not being driven by unresolved classifier ambiguity.
5. Action-window bucket shares by role:
   - Baseline total attributed time: `679784.5 ms`.
      - `client_lifecycle`: `234316.0 ms` (`34.47%`),
      - `transition_wait`: `196784.0 ms` (`28.95%`),
      - `client_wait`: `100133.0 ms` (`14.73%`),
      - `hierarchy_fanout`: `89673.4 ms` (`13.19%`),
      - `tab_server_materialization`: `27698.3 ms` (`4.07%`),
      - `provider_filter`: `20659.4 ms` (`3.04%`).
   - Candidate total attributed time: `687072.2 ms`.
      - `client_lifecycle`: `233125.0 ms` (`33.93%`),
      - `transition_wait`: `208691.0 ms` (`30.37%`),
      - `client_wait`: `97249.0 ms` (`14.15%`),
      - `hierarchy_fanout`: `89089.5 ms` (`12.97%`),
      - `tab_server_materialization`: `26972.5 ms` (`3.93%`),
      - `provider_filter`: `21175.7 ms` (`3.08%`).
6. Lane delta:
   - baseline total: `679784.5 ms`,
   - candidate total: `687072.2 ms`,
   - delta: `+7287.7 ms`,
   - improvement percent: `-1.07%`.
   - Interpretation: marker-enabled candidate evidence is slightly slower in aggregate for this rollup, and the increase is mostly in wait/lifecycle timing rather than provider or materialization buckets.
7. Next-target recommendation:
   - Do not make provider filtering or broad sidecar generation the next implementation target from this evidence.
      - `provider_filter` is only about `3%` of attributed action-window time.
      - `tab_server_materialization` is only about `4%`.
      - Optimizing those first is unlikely to move strict single-action gates.
   - Prioritize a narrow client lifecycle / wait-boundary tranche.
      - Combined `client_lifecycle + transition_wait + client_wait` accounts for about `78%` of action-window time in both baseline and candidate.
      - This is now the dominant reproducible bucket family on fresh strict evidence.
8. Proposed next tranche:
   - Tranche 8I should split the dominant client-side lifecycle and wait time into a more actionable target before changing broad server/provider code.
   - Recommended focus:
      - instrument or decompose the tab switch visible-ready path around Plotly/client render lifecycle,
      - separate real browser/render work from synthetic `transition_wait` and `client_wait` gaps,
      - identify whether the first implementation edit should target client readiness signaling, Plotly render churn, or server-to-client output completion ordering.
   - Candidate files for the next narrow investigation:
      - `Programs/app_source/ui.R`,
      - `Programs/app_source/server/04_comparison_plots.R`,
      - `Programs/app_source/server/05_trend_and_heatmap.R`,
      - boundary marker handling in `Programs/app_source/server/02_partner_and_notes.R` only if readiness provenance needs refinement.
9. Stop/reopen criteria for 8I:
   - Reopen provider/cache-side work only if a narrower client/wait split shows that wait time is actually masking server/provider output readiness.
   - Reopen hierarchy fanout only if client/wait split falls below hierarchy fanout or shows hierarchy-triggered output churn as the primary cause.
   - Do not relax acceptance thresholds or treat the current rollup as an acceptance pass.

Summary in plain terms:
- The fresh rollup says the main problem is not data filtering or sidecar/provider lookup time.
- Most of the measured action-window time is now in the client lifecycle and waits around tab/output readiness.
- The next useful target is a small client-lifecycle/readiness tranche that turns those wait buckets into a concrete implementation edit.

Execution update (Tranche 8I - daughter plan kickoff and implementation start):
1. Tranche 8I implementation kickoff status:
   - Started.
2. Daughter plan created for detailed execution ledger:
   - `Code Review/2026-08-05_vp_tranche8i_client_readiness_split_plan.md`
3. Parent/child planning contract for 8I:
   - parent remains this architecture plan for branch-level decisions and tranche rollups,
   - daughter plan holds the full step ledger, failed attempts, artifact lists, command templates, guardrails, and closeout detail.
4. 8I scope confirmed at kickoff:
   - measurement-first client lifecycle/readiness split,
   - immutable reuse of fresh 8G/8H decomposition and rollup artifacts as baseline,
   - marker-provenance refinement only if read-only split cannot separate real client/render work from synthetic waits,
   - one small reversible implementation candidate only after explicit actionability gate,
   - no threshold relaxation or broad provider/cache/sidecar optimization in this tranche.
5. Immediate next action:
   - run Phase 1 read-only split over fresh 8G detail/runs baseline and emit the 8I derivative split artifacts defined in the daughter plan.

Summary in plain terms:
- Tranche 8I is now formally started.
- The new daughter plan is the implementation ledger for this tranche, while this parent plan remains the architecture source of truth.
- Next execution step is read-only evidence splitting, not optimization edits.

Execution update (Tranche 8I - Phase 1 read-only split complete and gate decision):
1. Added a dedicated read-only split helper:
   - `System/Testing/vp_perf_step25c_client_readiness_split_8i.R`
2. Ran Phase 1 split on immutable fresh 8G evidence:
   - detail input: `Logs/vp_perf_acceptance_decomposition_tranche8g_off_on_i9_phase3_strict_fresh_20260805T010825Z_detail.csv`
   - runs input: `Logs/vp_perf_acceptance_decomposition_tranche8g_off_on_i9_phase3_strict_fresh_20260805T010825Z_runs.csv`
   - label: `tranche8i_client_readiness_split_existing_8g`
3. Emitted 8I derivative artifacts:
   - `Logs/vp_perf_client_readiness_split_tranche8i_client_readiness_split_existing_8g_20260805T135916Z_signature.csv`
   - `Logs/vp_perf_client_readiness_split_tranche8i_client_readiness_split_existing_8g_20260805T135916Z_gap_context.csv`
   - `Logs/vp_perf_client_readiness_split_tranche8i_client_readiness_split_existing_8g_20260805T135916Z_role_pair_summary.csv`
4. Phase 1 actionability snapshot:
   - OFF action-window remains mixed but client_lifecycle-led (~48-49%) with transition_wait second (~30-32%).
   - ON action-window is now clearly transition_wait-dominant (~53% in both baseline and candidate), with client_lifecycle second (~33%).
5. Gate decision:
   - Actionability gate passed.
   - Proceed to one small implementation hypothesis targeting reducible transition/wait path behavior.
   - Do not expand marker-provenance first; keep it as fallback if the initial implementation hypothesis fails to move dominant wait behavior or exposes ownership ambiguity.

Summary in plain terms:
- 8I Phase 1 produced the planned read-only split artifacts and identified a dominant actionable wait family.
- Next step is a single small implementation hypothesis against transition/wait behavior, then smoke validation.

Execution update (Tranche 8I - Phase 3 probe, strict OFF/ON validation, and rollback):
1. Implemented one small reversible hypothesis after Phase 1 actionability gate:
   - objective: reduce reducible tab transition wait by lowering main-tab resize debounce.
   - touched files:
      - `Programs/app_source/ui.R` (temporary optional `forcePlotlyResize` delay input)
      - `Programs/app_source/server/02_partner_and_notes.R` (temporary `resize_delay_ms=60` for main-tab resize dispatch only)
2. Narrow smoke gate passed:
   - `Logs/vp_perf_probe_single_action_latency_tranche8i_client_readiness_phase3_resize_delay60_smoke_20260805T140221Z.csv`
   - `PASS=4`.
3. Strict replicated ON cohort (markers ON, unchanged thresholds) completed with clean preflight but failed decision gate:
   - manifest: `Logs/vp_perf_acceptance_run_manifest_tranche8i_client_readiness_acceptance_i9_resize_delay60_20260805T140720Z.csv`
   - decision summary/detail/decision:
      - `Logs/vp_perf_acceptance_decision_tranche8i_client_readiness_acceptance_i9_resize_delay60__decision_20260805T151839Z_summary.csv`
      - `Logs/vp_perf_acceptance_decision_tranche8i_client_readiness_acceptance_i9_resize_delay60__decision_20260805T151839Z_details.csv`
      - `Logs/vp_perf_acceptance_decision_tranche8i_client_readiness_acceptance_i9_resize_delay60__decision_20260805T151839Z_decision.csv`
   - startup median moved from `81156` to `83953` ms (`-3.446%` improvement ratio).
   - single-action median moved from `9396` to `10451.5` ms (`-11.234%` improvement ratio).
4. Strict OFF cohort needed contamination recovery before a clean pair was available:
   - first OFF run had one contaminated single-action row (`FAIL=1|PASS=3`, `PARTIAL=1|PASS=3`) and failed strict preflight.
   - OFF rerun1 had one startup `status=FAIL` row and failed strict preflight.
   - OFF rerun2 (higher startup/stage/output/full-idle timeouts only; thresholds unchanged) passed strict preflight and produced clean decision artifacts:
      - manifest: `Logs/vp_perf_acceptance_run_manifest_tranche8i_client_readiness_acceptance_i9_resize_delay60_off_rerun2_20260805T174508Z.csv`
      - decision: `Logs/vp_perf_acceptance_decision_tranche8i_client_readiness_acceptance_i9_resize_delay60_off_rerun2__decision_20260805T184740Z_decision.csv`
   - OFF rerun2 still failed thresholds:
      - startup improvement ratio `+0.146%` (below `25%` gate),
      - single-action improvement ratio `-0.853%`.
5. Built exact-path post-edit OFF/ON attribution chain:
   - index: `Logs/vp_perf_acceptance_index_tranche8i_off_on_i9_resize_delay60_20260805.csv`
   - inventory: `Logs/vp_perf_acceptance_inventory_tranche8i_off_on_i9_resize_delay60_inventory_20260805T184802Z.csv`
   - decomposition: `Logs/vp_perf_acceptance_decomposition_tranche8i_off_on_i9_resize_delay60_decomp_20260805T184822Z_detail.csv`; `Logs/vp_perf_acceptance_decomposition_tranche8i_off_on_i9_resize_delay60_decomp_20260805T184822Z_runs.csv`; `Logs/vp_perf_acceptance_decomposition_tranche8i_off_on_i9_resize_delay60_decomp_20260805T184822Z_summary.csv`
   - rollup: `Logs/vp_perf_acceptance_decomposition_tranche8i_off_on_i9_resize_delay60_rollup_20260805T185320Z_action_bucket.csv`; `Logs/vp_perf_acceptance_decomposition_tranche8i_off_on_i9_resize_delay60_rollup_20260805T185320Z_lane_delta.csv`; `Logs/vp_perf_acceptance_decomposition_tranche8i_off_on_i9_resize_delay60_rollup_20260805T185320Z_lane_confidence.csv`
   - audit: `Logs/vp_perf_acceptance_decomposition_tranche8i_off_on_i9_resize_delay60_audit_20260805T185322Z_audit_summary.json`
   - 8I split rerun: `Logs/vp_perf_client_readiness_split_tranche8i_client_readiness_split_resize_delay60_20260805T185337Z_role_pair_summary.csv`
6. Post-edit rollup outcome:
   - warm_partition_disk action-window baseline `634557.2` ms vs candidate `657130.2` ms.
   - delta `+22573.0` ms (`-3.56%` improvement).
   - dominant buckets remained client/wait heavy; ON transition_wait share increased from `52.34%` to `55.22%`.
7. Tranche decision:
   - reject this probe as a performance optimization target.
   - rollback completed for both touched files; parse checks clean after rollback.
   - keep Tranche 8I open for next single reversible hypothesis targeting transition-wait ownership/order rather than debounce reduction.

Summary in plain terms:
- The first 8I implementation probe was safe and reversible but did not improve strict startup or single-action gates.
- Clean strict OFF/ON post-edit evidence shows action-window time increased and ON transition wait got worse.
- The probe was rolled back; the next 8I target should stay narrow and focus on transition-wait ownership/readiness ordering, with marker-provenance still reserved as fallback.

Execution update (Tranche 8I - client-owned main-tab resize ordering probe, strict validation, and rollback):
1. Implemented a narrow 8I probe to shift main-tab resize request ownership from server observer dispatch to client post-activation scheduling while preserving MYC-specific server sends.
2. Touched files during probe:
   - `Programs/app_source/ui.R` (temporary shared resize queue helper, client-owned tab dispatch path, source tagging),
   - `Programs/app_source/server/02_partner_and_notes.R` (temporary removal of main-tab observer resize send only).
3. Parse/diagnostics gate after edit:
   - parse checks passed for both files,
   - no editor diagnostics errors on touched files.
4. Tab-only smoke gate passed:
   - `Logs/vp_perf_probe_single_action_latency_tranche8i_client_readiness_client_owned_resize_smoke_20260805T192403Z.csv` (`PASS=4`).
5. Smoke mechanism evidence (runtime log):
   - runtime: `Logs/vp_runtime_perf_single_action_tranche8i_client_readiness_client_owned_resize_smoke_20260805T192403Z.jsonl`,
   - `plotly_resize` count `4`, skipped count `0`, duplicate tab-action resize pairs `0`,
   - source tag counts: `client_tab_post_activation=4`,
   - tab coverage: Historical Trend/Heatmap/Map/Current each `1`.
6. Strict replicated OFF/ON acceptance pair completed with unchanged thresholds:
   - manifest: `Logs/vp_perf_acceptance_run_manifest_tranche8i_client_readiness_acceptance_i9_client_owned_resize_20260805T192720Z.csv`,
   - decision: `Logs/vp_perf_acceptance_decision_tranche8i_client_readiness_acceptance_i9_client_owned_resize__decision_20260805T202932Z_decision.csv`,
   - preflight/context/identity clean (`36/36` rows),
   - overall gate: FAIL,
   - startup improvement observed `0.021228` (threshold `0.25`),
   - single-action improvement observed `-0.097304` (threshold `0.20`).
7. Exact-path evidence chain emitted:
   - index: `Logs/vp_perf_acceptance_index_tranche8i_off_on_i9_client_owned_resize_20260805.csv`,
   - inventory: `Logs/vp_perf_acceptance_inventory_tranche8i_off_on_i9_client_owned_resize_inventory_20260805T203021Z.csv`,
   - Step 25B summary: `Logs/vp_perf_acceptance_inventory_validation_tranche8i_off_on_i9_client_owned_resize_validation_20260805T203034Z_summary.csv`,
   - decomposition detail/runs/summary: `Logs/vp_perf_acceptance_decomposition_tranche8i_off_on_i9_client_owned_resize_decomp_20260805T203036Z_detail.csv`; `Logs/vp_perf_acceptance_decomposition_tranche8i_off_on_i9_client_owned_resize_decomp_20260805T203036Z_runs.csv`; `Logs/vp_perf_acceptance_decomposition_tranche8i_off_on_i9_client_owned_resize_decomp_20260805T203036Z_summary.csv`,
   - Step 25D audit: `Logs/vp_perf_acceptance_decomposition_tranche8i_off_on_i9_client_owned_resize_audit_20260805T203324Z_audit_summary.json`,
   - Step 25C rollup: `Logs/vp_perf_acceptance_decomposition_tranche8i_off_on_i9_client_owned_resize_rollup_20260805T203325Z_action_bucket.csv`; `Logs/vp_perf_acceptance_decomposition_tranche8i_off_on_i9_client_owned_resize_rollup_20260805T203325Z_lane_delta.csv`; `Logs/vp_perf_acceptance_decomposition_tranche8i_off_on_i9_client_owned_resize_rollup_20260805T203325Z_lane_confidence.csv`,
   - 8I split rerun: `Logs/vp_perf_client_readiness_split_tranche8i_client_readiness_split_client_owned_resize_20260805T203337Z_role_pair_summary.csv`.
8. Rollup outcome:
   - warm_partition_disk action-window baseline `298786.6000` ms,
   - candidate `299860.1004` ms,
   - delta `+1073.5003` ms (`-0.3593%` improvement),
   - ON transition_wait share did not improve (`51.91%` -> `52.05%`).
9. Tranche decision:
   - reject this probe,
   - rollback completed for both touched product files,
   - parse checks clean after rollback,
   - keep 8I open for the next narrow transition-wait ownership/readiness target.

Summary in plain terms:
- The client-owned main-tab resize ordering probe passed smoke and produced clean mechanism evidence, but it failed strict replicated acceptance.
- Post-edit action-window time increased slightly and ON transition-wait share did not improve.
- The probe was rolled back, and tranche 8I remains open for the next small reversible hypothesis.
