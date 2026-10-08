# VP Branch K-R: Rollup Ablation Experiment Plan

Date: 2026-08-03
Branch: main
Status: Closed. K-R6 pair testing proved embedded rollup bulk is a material startup/artifact-load lever, but did not prove a stable tab-only/tab-paint win. K-R7 restore/cleanup was not required because no canonical processed artifacts were swapped or mutated. K-R8 closeout is complete and rolled up to the Branch K parent and the VP performance hotspot parent. The production recommendation is not to delete rollups; it is to investigate a more aggressive lazy partition architecture with a small startup shell, commodity-level native partitions, and commodity/context rollup sidecars.
Parent ledger: `VP Clone/Code Review/2026-08-03_vp_branch_k_hierarchy_cache_architecture_plan.md`
Historical rollup context: `VP Clone/Code Review/2026-07-27_vp_pipeline_rollup_all_plan.md`
Parent performance context: `VP Clone/Code Review/2026-07-29_vp_performance_hotspot_recovery_plan.md`
Related mixed-volume context: `VP Clone/Code Review/2026-07-29_vp_mixed_volume_runtime_churn_optimization_plan.md`
Readiness context: `VP Clone/Code Review/2026-08-01_vp_branch_j_hierarchy_cascade_readiness_plan.md`

## Purpose

K-R tests whether the VP pipeline rollup strategy made the main runtime artifact too large and whether that artifact size contributes to slow startup, top-bar/sidebar initialization, hierarchy and filtering lag, tab switching, and tab paint.

The working concern is that embedded strict rollup rows may have solved the all-selection semantics problem while inflating `vp_trade_monthly_pre.rds`, increasing RDS read time, in-memory object size, partition-provider overhead, hierarchy metadata work, and downstream output readiness. K-R is an experiment to prove, falsify, or bound that concern before Branch K spends more time on small fanout/churn edits.

K-R is not a production rollup redesign. A later redesign is warranted only if this experiment shows material artifact, provider, startup, or tab-readiness impact.

## Scope

In scope:
- VP trade artifact shape and size.
- Native-row versus rollup-row counts and ratios.
- RDS file size, read time, object size, contract-validation time, and canonical-mark time.
- Partition-provider behavior with explicit artifact paths and isolated partition directories.
- Startup and tab-only readiness only if a currentity-safe app-level candidate can be run.
- Clear classification of candidate artifacts as behavior-valid, measurement-only, or semantically invalid/performance-only.

Out of scope:
- Deleting rollups from the production artifact.
- Weakening production rollup validation.
- Changing visible all-selection semantics.
- Claiming correctness from native-only or minimal-rollup candidate artifacts.
- Redesigning the rollup architecture before K-R evidence shows material performance impact.
- Broad provider/partition redesign unless the K-R evidence specifically points there.

## Critical Audit Findings

1. Native-only artifacts are measurement-only.
	- Production startup calls `validate_vp_trade_rollup_contract()` and requires rollup fields, expected schema, at least one `vp_is_rollup` row, and all three levels: `segment_all`, `subgroup_all`, and `group_all`.
	- A pure native-only artifact is useful for artifact shape, artifact read, and some provider measurements, but it is not app-startable under current production validation.

2. Minimal-rollup artifacts are performance-only.
	- A minimal-rollup candidate may pass the startup contract while still producing incorrect all-selection values.
	- It can test whether most rollup-row bulk affects performance, but it cannot be accepted as a behavior/correctness candidate.

3. Naive canonical RDS swapping is rejected.
	- App startup checks artifact currentity and manifest/signature state before reading the RDS.
	- Swapping only `System/Processed Data/vp_trade_monthly_pre.rds` can cause startup to reject the candidate or fallback-rebuild the normal artifact, invalidating the timing evidence.
	- App-level candidate timing requires an isolated root, an explicit test-only artifact override, or a fully manifest/currentity-aware swap with proof that no fallback rebuild occurred.

4. Explicit-path probes are the safe first phase.
	- `System/Testing/vp_perf_probe_artifact_load.R` supports explicit `--artifact`, `--metadata`, and `--source` paths.
	- `System/Testing/vp_perf_probe_partition_provider.R` supports explicit `--artifact` and `--partition-dir` paths.
	- These probes can compare artifact variants without touching canonical app artifacts.

5. Provider scenarios need careful interpretation.
	- Strict rollup scenarios may fail or return no rows for native-only artifacts. That is contract evidence, not a clean provider-speed result.
	- K-R should include native/faceted provider scenarios if existing strict scenarios cannot provide a fair speed comparison.

## Hypotheses And Falsifying Checks

H1: Rollup rows materially inflate `vp_trade_monthly_pre.rds` file size, in-memory object size, and artifact read time.

H2: Rollup rows materially increase partition-provider row counts, manifest/payload work, or slice time.

H3: If a currentity-safe minimal-rollup app candidate can run, reducing rollup bulk improves startup, top/sidebar initialization, tab switching, or tab visible-ready timings.

Falsifying checks:
- If native-only and minimal-rollup variants do not materially reduce file size, object size, artifact read time, or provider work, stop K-R and reject rollup bloat as Branch K's next lever.
- If Phase 1 artifact/provider deltas are small, do not proceed to app-level candidate setup.
- If app-level candidate setup cannot be made currentity-safe without production-risky changes, stop and record the blocker rather than weakening validation.
- If app-level candidate startup/tab probes run but visible timings do not improve outside normal run variance, treat rollup bloat as a startup/filtering concern at most, not the tab-paint bottleneck.

Initial materiality guide:
- At least 20-30% lower artifact read time or object size, plus a visible startup or tab-ready improvement outside normal run variance for any claim that rollup bloat controls user-visible latency.

## Step Ledger

| Step | Phase | Work | Status | Evidence / Files | Gate / Next Action |
|---|---|---|---|---|---|
| K-R0 | Ledger setup | Create K-R granddaughter ledger and add a short Branch K pointer | Complete | This file; Branch K parent pointer added | Proceeded to K-R1. |
| K-R1 | Artifact prep | Build artifact-shape/prep script that creates full-copy, native-only, and minimal-rollup candidate artifacts under `Logs/rollup_ablation/<timestamp>/` | Complete | `System/Testing/vp_perf_prepare_rollup_ablation_artifacts.R`; outputs under `VP Clone/Logs/rollup_ablation/20260803T154625Z/` | Proceed to K-R2 artifact-load decomposition with explicit artifact paths. |
| K-R2 | Artifact load | Run artifact-load decomposition for baseline, full-copy, native-only, and minimal-rollup variants | Complete | `vp_perf_probe_artifact_load.R` outputs; see K-R2 evidence | Noncanonical decomposed probes hit `manifest_entry_missing`; read-only reduced artifacts load about 3x faster than canonical/full-copy. Proceed to K-R3. |
| K-R2.5 | Currentity strategy | Assess whether VP's single-source artifact/update model can use a simpler cache-reset/currentity strategy, and whether currentity affects startup, tab switches, or K-R app-candidate setup | Complete for first planning gate | K-R2 currentity timing; existing runtime currentity/signature summaries | Do not treat currentity as the direct tab-switch bottleneck. Keep it as an app-candidate blocker and possible later simplification. Proceed to K-R3. |
| K-R3 | Provider | Run partition-provider strict and native/faceted comparisons using explicit artifacts and isolated partition dirs | Complete | `vp_perf_probe_partition_provider.R` outputs; see K-R3 evidence | Strict rollup scenarios are semantically uneven for reduced artifacts. Default disk-hit scenario gives a fairer 211-row comparison and shows reduced artifacts are faster. Proceed to K-R4 gate. |
| K-R4 | Gate | Decide whether app-level candidate testing is justified by Phase 1 evidence | Complete | K-R1/K-R2/K-R2.5/K-R3 summaries; see K-R4 evidence | GO for K-R5 currentity-safe app candidate setup. Use performance-only candidate; do not claim correctness. |
| K-R5 | App candidate setup | Choose a currentity-safe app-level candidate path: isolated root, test-only artifact override, or manifest-aware swap | Complete | `Programs/app_source/global.R`; `System/Testing/vp_perf_probe_startup.R`; `System/Testing/vp_perf_probe_single_action_latency.R`; K-R5 smoke outputs | Explicit test-only artifact override implemented and proved with row-count/no-fallback evidence. Proceed to K-R6 paired app probes. |
| K-R6 | App probes | Run baseline/candidate startup and tab-only probes if K-R5 succeeds | Complete for two-pair first pass | Startup and single-action probe outputs; K-R6 evidence | Startup improvement repeated across both pairs. Tab-only results were not directionally stable. Proceed to K-R8 closeout/recommendation rather than production redesign. |
| K-R7 | Restore/cleanup | Restore and validate any canonical files touched | Not required | No canonical processed artifacts were swapped or mutated in K-R5/K-R6; candidate app probes used the explicit test-only override. | No restore action required. |
| K-R8 | Closeout | Summarize accepted findings, rejected hypotheses, blockers, and next architecture recommendation; roll up to Branch K | Complete | This ledger; Branch K parent summary; VP performance hotspot parent summary | K-R is closed. Pause before creating a new separate architecture plan. |

## Experiment Design

### Artifact Variants

All generated artifacts must be written under `Logs/rollup_ablation/<timestamp>/`.

Candidate artifacts:
- `vp_trade_monthly_full_copy.rds`: full copy of the canonical artifact. This controls for path/copy/serialization noise.
- `vp_trade_monthly_native_only.rds`: rows where `vp_is_rollup` is missing or false only, with all original columns preserved.
- `vp_trade_monthly_minimal_rollup_contract.rds`: native rows plus enough rollup rows to satisfy the production rollup-level contract. This candidate is semantically invalid/performance-only unless proven otherwise in a later redesign branch.
- `rollup_ablation_shape.csv`: shape and size summary for all variants.

Shape metrics:
- Artifact path.
- File size.
- Object size after `readRDS()`.
- Row count and column count.
- Native row count.
- Rollup row count.
- Rollup row share.
- Rows by `vp_rollup_level`.
- Rows by `Trade`.
- Rows by `UnitType`.
- Rows by hierarchy path or hierarchy depth if cheap to compute.
- Candidate classification: behavior-valid, measurement-only, or semantically invalid/performance-only.

### App-Level Candidate Options

Preferred option A: isolated root.
- Copy the minimum required `VP Clone` structure to `Logs/rollup_ablation/<timestamp>/isolated_root/`.
- Place candidate artifact, metadata, and manifest consistently in that root.
- Run startup/tab probes from the isolated root so production artifacts are untouched.

Option B: test-only artifact override.
- Add an explicit test-only artifact path override to the startup/single-action probe or startup path resolution.
- The override must be opt-in, fail closed, and impossible to activate in normal app startup by accident.

Option C: manifest-aware canonical swap.
- Use only if A/B are too costly.
- Backup and restore artifact, metadata, and manifest, not only the RDS.
- Prove currentity passed against the candidate and no fallback rebuild occurred.

Naive RDS-only swapping is not an acceptable app-level experiment.

## Command Plan

Use the R executable already used in Branch K validation:

```powershell
& "C:\Program Files\R\R-4.5.1\bin\Rscript.exe" "System/Testing/vp_perf_prepare_rollup_ablation_artifacts.R" --label=step21_branch_k_rollup_ablate_prepare
```

Artifact-load labels:
- `step21_branch_k_rollup_ablate_baseline_artifact`
- `step21_branch_k_rollup_ablate_fullcopy_artifact`
- `step21_branch_k_rollup_ablate_native_only_artifact`
- `step21_branch_k_rollup_ablate_minimal_rollup_artifact`

Command pattern:

```powershell
& "C:\Program Files\R\R-4.5.1\bin\Rscript.exe" "System/Testing/vp_perf_probe_artifact_load.R" --label=step21_branch_k_rollup_ablate_baseline_artifact --cache-state=cold_artifact --decompose=true --artifact="System/Processed Data/vp_trade_monthly_pre.rds" --metadata="System/Processed Data/vp_trade_metadata_pre.rds" --source="Input/veg-trade-data.csv"
```

Provider labels:
- `step21_branch_k_rollup_ablate_baseline_provider_strict`
- `step21_branch_k_rollup_ablate_native_only_provider_strict`
- `step21_branch_k_rollup_ablate_minimal_rollup_provider_strict`
- Optional native/faceted equivalents if a clean scenario set exists or is added.

Provider command pattern:

```powershell
& "C:\Program Files\R\R-4.5.1\bin\Rscript.exe" "System/Testing/vp_perf_probe_partition_provider.R" --label=step21_branch_k_rollup_ablate_baseline_provider_strict --cache-state=warm_partition_disk --runs=2 --scenario-set=step6_disk_hit_slices --artifact="System/Processed Data/vp_trade_monthly_pre.rds" --provider-version=vp_trade_partition_provider_v3 --builder-version=vp_trade_artifact_2026_07_28_v6 --partition-dir="Logs/tmp_partitions/rollup_ablation/baseline/v3/vp_trade_artifact_2026_07_28_v6"
```

App-level labels, only if currentity-safe setup exists:
- `step21_branch_k_rollup_ablate_startup_baseline`
- `step21_branch_k_rollup_ablate_tabonly_baseline`
- `step21_branch_k_rollup_ablate_startup_minimal_rollup`
- `step21_branch_k_rollup_ablate_tabonly_minimal_rollup`

Startup command pattern:

```powershell
& "C:\Program Files\R\R-4.5.1\bin\Rscript.exe" "System/Testing/vp_perf_probe_startup.R" --label=step21_branch_k_rollup_ablate_startup_baseline --cache-state=cold_artifact --runtime-perf=true --target-tab="Current vs. Average"
& "C:\Program Files\R\R-4.5.1\bin\Rscript.exe" "System/Testing/vp_perf_probe_startup.R" --label=step21_branch_k_rollup_ablate_startup_minimal_rollup --cache-state=test_artifact_override --runtime-perf=true --target-tab="Current vs. Average" --test-vp-trade-artifact="Logs/rollup_ablation/20260803T154625Z/vp_trade_monthly_minimal_rollup_contract.rds"
```

Tab-only command pattern:

```powershell
& "C:\Program Files\R\R-4.5.1\bin\Rscript.exe" "System/Testing/vp_perf_probe_single_action_latency.R" --label=step21_branch_k_rollup_ablate_tabonly_baseline --cache-state=warm_session --scenario=tab_only_revisit --runtime-perf=true
& "C:\Program Files\R\R-4.5.1\bin\Rscript.exe" "System/Testing/vp_perf_probe_single_action_latency.R" --label=step21_branch_k_rollup_ablate_tabonly_minimal_rollup --cache-state=test_artifact_override --scenario=tab_only_revisit --runtime-perf=true --test-vp-trade-artifact="Logs/rollup_ablation/20260803T154625Z/vp_trade_monthly_minimal_rollup_contract.rds"
```

## Verification And Safety Requirements

1. Parse all new or changed R scripts before running them.
2. The artifact-prep script must never write to `System/Processed Data/`.
3. Use exact artifact paths and isolated partition directories for all variant probes.
4. Require minimal-rollup contract PASS before app-level candidate consideration.
5. Do not run app-level candidate probes unless currentity/manifest behavior is solved.
6. If app-level candidate probes run, verify candidate row count in runtime logs and prove no fallback rebuild occurred.
7. Restore and validate any canonical files touched.
8. Use exact printed CSV and JSONL paths in ledger entries; do not summarize broad wildcards.
9. Record source artifact signatures before and after any app-level candidate setup.
10. Record whether each candidate is behavior-valid, measurement-only, or semantically invalid/performance-only.
11. Run `git diff --check` for touched source, testing, and plan files.
12. Use diagnostics on touched files.

## Blockers And Refinements

1. Currentity/manifest mismatch is the biggest blocker. Candidate app-level timing is invalid if startup rebuilds or rejects the candidate artifact.
2. Native-only strict rollup scenarios are expected to fail or return no rows. Classify that as contract evidence, not a provider-speed result.
3. Minimal-rollup candidates may pass contract while producing wrong all-selection values. Never use them for correctness claims.
4. Startup and tab probes have natural variance. Require paired close-sequence baseline/candidate runs, and consider at least two runs before accepting a visible timing claim.
5. Partition-provider cache contamination can hide or exaggerate differences. Use isolated partition dirs and do not reuse candidate directories across variants.
6. OneDrive/Windows file locking can make artifact copy/restore brittle. Prefer write-to-temp plus atomic rename where scripts create artifacts, and record restore checks.
7. Artifact-load gains can be compression or serialization effects rather than row-count effects. Full-copy control is required to separate path/copy/serialization noise from row ablation.
8. App-level candidate setup may be more work than justified. Gate it on material Phase 1 evidence instead of treating it as automatic.

## Recommendations

1. Prefer an explicit test-only artifact override or isolated root over canonical file swapping for app-level probes.
2. Add native/faceted provider scenarios if existing strict rollup scenarios cannot give a clean speed comparison.
3. Include shape metrics by hierarchy depth/path so the experiment can distinguish broad row bloat from specific all-selection path bloat.
4. Treat sidecar/lazy rollup architecture as the leading redesign candidate if K-R proves rollup bloat, because current rollups solve real semantic problems.
5. Keep K-R closeout focused on decision quality: prove rollups are a lever, falsify them, or identify the exact blocker to app-level proof.

## Decision Rules

- If artifact read/object size and startup improve materially, design a sidecar/lazy rollup architecture in a later branch or tranche.
- If artifact read improves but tab-only does not, treat rollups as startup/artifact-load work.
- If provider improves only for strict contexts, inspect partition/index shape before changing rollup semantics.
- If Phase 1 artifact/provider deltas are small, do not proceed to app-level candidate setup.
- If app-level candidate cannot be made currentity-safe without production-risky changes, stop and record the blocker rather than weakening validation.
- If no material deltas appear, reject rollup bloat as Branch K's next lever.

## K-R2.5 Currentity Strategy Assessment

Rationale:
- Currentity was more important in the Rice and Almond apps because multiple data sources could update on different schedules.
- VP currently has one primary source CSV for this artifact lane, so a source-update event may only need to invalidate/rebuild the VP artifact and reset related caches.
- K-R2 shows currentity is not the dominant canonical artifact-load cost by itself: currentity was 356 ms while `readRDS()` was 10032 ms in the decomposed canonical artifact-load probe.
- K-R2 also shows currentity/manifest strictness is a real experiment blocker for noncanonical candidate artifacts.

Questions to answer before app-level candidate timing:
1. Is VP currentity checked only during startup artifact reads, or can tab switches/repeated interactions trigger currentity/signature work?
2. Which runtime `artifact_signature(build_file_signature)` events are true currentity checks versus provider/cache identity checks?
3. Would a VP-specific single-source artifact epoch/cache-reset strategy preserve safety while simplifying app-level candidate testing and future production behavior?
4. If currentity is retained, should K-R5 use an isolated root, a test-only artifact override, or a manifest-aware candidate registration helper?

Evidence targets:
- Summarize existing runtime logs for `currentity_check`, `artifact_signature(build_file_signature)`, and `load_vp_trade_monthly_data` events.
- Compare startup logs with tab-only logs to identify whether currentity is startup-only.
- Use K-R2 artifact-load rows to keep currentity cost separate from artifact read/object materialization.

Decision rules:
- If currentity is startup-only and sub-second, do not treat it as a direct tab-switch bottleneck.
- If signature work recurs during interactions, classify whether it belongs to provider/cache identity rather than artifact currentity before changing currentity policy.
- If VP adopts a simpler single-source model later, preserve stale-artifact refusal at startup and make source-update cache reset explicit.
- Do not weaken production validation as part of K-R2.5. This slice can recommend a later simplification branch or a test-only override for K-R5.

## K-R Closeout Roll-Up Requirements

When K-R closes, update the Branch K parent ledger with:
- Accepted findings.
- Rejected hypotheses.
- Exact probe outputs.
- Exact runtime/fallback JSONL summaries.
- Any implementation blockers.
- Recommended next architecture path.

Keep this K-R ledger as the detailed source of truth. Branch K should receive only the executive summary and decision.

## Evidence Ledger

### K-R0 Ledger Creation - 2026-08-03

- Created this K-R granddaughter ledger under Branch K.
- Updated the Branch K parent ledger with a short pointer to this file.
- Next action was to create the artifact-shape/prep script.

### K-R1 Artifact Prep Script - 2026-08-03

Files changed:
- `VP Clone/System/Testing/vp_perf_prepare_rollup_ablation_artifacts.R`
	- Added a self-contained K-R prep script.
	- Resolves the VP Clone root from `.vp_clone_root`.
	- Reads the canonical `vp_trade_monthly_pre.rds` artifact.
	- Writes all generated files only under `Logs/rollup_ablation/<timestamp>/`.
	- Refuses output roots under `System/Processed Data/`.
	- Creates full-copy, native-only, and minimal-rollup contract candidate artifacts.
	- Writes `rollup_ablation_shape.csv` and `rollup_ablation_signatures.csv`.
	- Mirrors the startup rollup contract enough to classify candidate artifacts as PASS/FAIL for required rollup fields, schema, rollup rows, and required levels.

Validation:
- Parse marker: `PARSE_OK_BRANCH_KR1_PREP_SCRIPT`.
- Diff check: `git diff --check -- "System/Testing/vp_perf_prepare_rollup_ablation_artifacts.R"` completed with no output.

Run command:

```powershell
& "C:\Program Files\R\R-4.5.1\bin\Rscript.exe" "System/Testing/vp_perf_prepare_rollup_ablation_artifacts.R" --label=step21_branch_k_rollup_ablate_prepare
```

Generated output root:
- `VP Clone/Logs/rollup_ablation/20260803T154625Z/`

Generated files:
- Shape output: `VP Clone/Logs/rollup_ablation/20260803T154625Z/rollup_ablation_shape.csv`
- Signature output: `VP Clone/Logs/rollup_ablation/20260803T154625Z/rollup_ablation_signatures.csv`
- Full-copy artifact: `VP Clone/Logs/rollup_ablation/20260803T154625Z/vp_trade_monthly_full_copy.rds`
- Metadata full copy: `VP Clone/Logs/rollup_ablation/20260803T154625Z/vp_trade_metadata_full_copy.rds`
- Native-only artifact: `VP Clone/Logs/rollup_ablation/20260803T154625Z/vp_trade_monthly_native_only.rds`
- Minimal-rollup contract artifact: `VP Clone/Logs/rollup_ablation/20260803T154625Z/vp_trade_monthly_minimal_rollup_contract.rds`

Shape results:

| Variant | Classification | Rows | Rollup rows | Rollup share | File MB | Object MB | Contract |
|---|---|---:|---:|---:|---:|---:|---|
| baseline_canonical | behavior_valid | 2115868 | 1491692 | 70.5% | 167.0 | 847.8 | PASS |
| full_copy | behavior_valid_copy | 2115868 | 1491692 | 70.5% | 167.0 | 847.8 | PASS |
| native_only | measurement_only | 624176 | 0 | 0.0% | 48.1 | 252.5 | FAIL: rollup levels are incomplete |
| minimal_rollup_contract | semantically_invalid_performance_only | 624179 | 3 | 0.00048% | 48.1 | 252.5 | PASS |

Signature safety:
- Source artifact before: size 175113462 bytes, mtime `2026-07-28T18:57:39Z`.
- Source artifact after: size 175113462 bytes, mtime `2026-07-28T18:57:39Z`.
- Source metadata before: size 67629 bytes, mtime `2026-07-28T18:57:40Z`.
- Source metadata after: size 67629 bytes, mtime `2026-07-28T18:57:40Z`.
- Interpretation: K-R1 did not mutate canonical processed artifacts.

Interpretation:
- Rollup rows are a large artifact-shape signal: about 1.49M of 2.12M rows, or 70.5% of the canonical artifact.
- Removing rollup bulk reduces the RDS file from about 167 MB to about 48 MB and object size from about 848 MB to about 253 MB in the generated candidates.
- This supports proceeding to K-R2 artifact-load decomposition with explicit artifact paths.
- It does not yet prove a user-visible speed win, provider win, startup win, or tab-readiness win.

### K-R2 Artifact-Load Decomposition and Read-Only Probes - 2026-08-03

Probe contract finding:
- `vp_perf_probe_artifact_load.R --decompose=true` calls `diagnose_processed_artifact_currentity()` before reading the artifact.
- The canonical artifact passes this currentity check.
- Noncanonical explicit artifacts under `Logs/rollup_ablation/20260803T154625Z/` fail decomposed mode with `manifest_entry_missing` before `readRDS()`.
- This confirms the K-R audit blocker: app-level or currentity-aware candidate timing cannot use a naive noncanonical RDS path without manifest/currentity handling.

Commands run:

```powershell
& "C:\Program Files\R\R-4.5.1\bin\Rscript.exe" "System/Testing/vp_perf_probe_artifact_load.R" --label=step21_branch_k_rollup_ablate_baseline_artifact --cache-state=cold_artifact --decompose=true --artifact="System/Processed Data/vp_trade_monthly_pre.rds" --metadata="System/Processed Data/vp_trade_metadata_pre.rds" --source="Input/veg-trade-data.csv"
& "C:\Program Files\R\R-4.5.1\bin\Rscript.exe" "System/Testing/vp_perf_probe_artifact_load.R" --label=step21_branch_k_rollup_ablate_fullcopy_artifact --cache-state=cold_artifact --decompose=true --artifact="Logs/rollup_ablation/20260803T154625Z/vp_trade_monthly_full_copy.rds" --metadata="Logs/rollup_ablation/20260803T154625Z/vp_trade_metadata_full_copy.rds" --source="Input/veg-trade-data.csv"
& "C:\Program Files\R\R-4.5.1\bin\Rscript.exe" "System/Testing/vp_perf_probe_artifact_load.R" --label=step21_branch_k_rollup_ablate_baseline_artifact_readonly --cache-state=cold_artifact --decompose=false --artifact="System/Processed Data/vp_trade_monthly_pre.rds" --metadata="System/Processed Data/vp_trade_metadata_pre.rds" --source="Input/veg-trade-data.csv"
& "C:\Program Files\R\R-4.5.1\bin\Rscript.exe" "System/Testing/vp_perf_probe_artifact_load.R" --label=step21_branch_k_rollup_ablate_fullcopy_artifact_readonly --cache-state=cold_artifact --decompose=false --artifact="Logs/rollup_ablation/20260803T154625Z/vp_trade_monthly_full_copy.rds" --metadata="Logs/rollup_ablation/20260803T154625Z/vp_trade_metadata_full_copy.rds" --source="Input/veg-trade-data.csv"
& "C:\Program Files\R\R-4.5.1\bin\Rscript.exe" "System/Testing/vp_perf_probe_artifact_load.R" --label=step21_branch_k_rollup_ablate_native_only_artifact_readonly --cache-state=cold_artifact --decompose=false --artifact="Logs/rollup_ablation/20260803T154625Z/vp_trade_monthly_native_only.rds" --metadata="Logs/rollup_ablation/20260803T154625Z/vp_trade_metadata_full_copy.rds" --source="Input/veg-trade-data.csv"
& "C:\Program Files\R\R-4.5.1\bin\Rscript.exe" "System/Testing/vp_perf_probe_artifact_load.R" --label=step21_branch_k_rollup_ablate_minimal_rollup_artifact_readonly --cache-state=cold_artifact --decompose=false --artifact="Logs/rollup_ablation/20260803T154625Z/vp_trade_monthly_minimal_rollup_contract.rds" --metadata="Logs/rollup_ablation/20260803T154625Z/vp_trade_metadata_full_copy.rds" --source="Input/veg-trade-data.csv"
```

Output CSVs:
- Canonical decomposed: `VP Clone/Logs/vp_perf_probe_artifact_load_step21_branch_k_rollup_ablate_baseline_artifact_20260803T154906Z.csv`
- Full-copy decomposed: `VP Clone/Logs/vp_perf_probe_artifact_load_step21_branch_k_rollup_ablate_fullcopy_artifact_20260803T154924Z.csv`
- Canonical read-only: `VP Clone/Logs/vp_perf_probe_artifact_load_step21_branch_k_rollup_ablate_baseline_artifact_readonly_20260803T155024Z.csv`
- Full-copy read-only: `VP Clone/Logs/vp_perf_probe_artifact_load_step21_branch_k_rollup_ablate_fullcopy_artifact_readonly_20260803T154930Z.csv`
- Native-only read-only: `VP Clone/Logs/vp_perf_probe_artifact_load_step21_branch_k_rollup_ablate_native_only_artifact_readonly_20260803T154952Z.csv`
- Minimal-rollup read-only: `VP Clone/Logs/vp_perf_probe_artifact_load_step21_branch_k_rollup_ablate_minimal_rollup_artifact_readonly_20260803T155001Z.csv`

Decomposed results:

| Variant | Status | Currentity | Read ms | Contract ms | Canonical mark ms | Total ms | Notes |
|---|---|---|---:|---:|---:|---:|---|
| canonical | PASS | current | 10032 | 1247 | 559 | 12773 | Currentity-aware baseline. |
| full_copy | FAIL | manifest_entry_missing | NA | NA | NA | 497 | Expected currentity blocker for noncanonical explicit path. |

Read-only results, comparable mode:

| Variant | Status | Rows | File MB | Object MB | Read ms | Total ms |
|---|---|---:|---:|---:|---:|---:|
| canonical | PASS | 2115868 | 167.0 | 847.8 | 10449 | 10452 |
| full_copy | PASS | 2115868 | 167.0 | 847.8 | 12099 | 12102 |
| native_only | PASS | 624176 | 48.1 | 252.5 | 3375 | 3378 |
| minimal_rollup_contract | PASS | 624179 | 48.1 | 252.5 | 3286 | 3289 |

Interpretation:
- The read-only artifact-load signal is material: reduced artifacts read in about 3.3 seconds versus about 10.4-12.1 seconds for canonical/full-copy artifacts in the same probe mode.
- The full-copy control shows some path/copy/run variance, but it remains in the full artifact timing band, not the reduced artifact timing band.
- Native-only and minimal-rollup read-only probes do not prove app correctness, startup safety, or tab readiness.
- K-R2 strengthens the artifact-load hypothesis enough to continue to K-R3 provider probes with isolated partition dirs.
- K-R2 also confirms that app-level candidate probes remain blocked until currentity/manifest handling is solved.

### K-R2.5 Currentity Strategy Assessment - 2026-08-03

User hypothesis:
- The VP app now has one primary data source, unlike the Rice and Almond apps where multiple sources updated on different schedules.
- A simpler VP strategy may be sufficient: when the source updates, rebuild the VP artifact and reset relevant caches.
- The question is whether the current multi-source currentity strategy is adding meaningful startup/tab-switch cost or mainly blocking K-R app-candidate experiments.

Code path reviewed:
- `VP Clone/Programs/shared_source_harmonization_utils.R`
	- `build_file_signature()` hashes files and logs `artifact_signature(build_file_signature)`.
	- `diagnose_processed_artifact_currentity()` compares expected source path IDs, source signatures, extra signature names, and extra signatures against the processed artifact manifest.
	- `read_processed_artifact_with_status()` checks currentity before `readRDS()` and returns `data = NULL` on stale/missing/mismatched currentity.
- `VP Clone/Programs/app_source/global.R`
	- `load_processed_or_csv_dataset()` calls `read_processed_artifact_with_status()` during startup dataset loads.

Existing evidence reviewed:
- K-R2 canonical artifact-load decomposition:
	- Currentity check: 356 ms.
	- RDS read: 10032 ms.
	- Contract validation: 1247 ms.
	- Canonical mark: 559 ms.
	- Total: 12773 ms.
- Branch K runtime summaries:
	- `VP Clone/Logs/vp_perf_runtime_summary_step21_branch_k_k0_runtime_summary_20260803T140914Z_timed.csv`
	- `VP Clone/Logs/vp_perf_runtime_summary_step21_branch_k_k0_warm_session_confirm_runtime_summary_20260803T141543Z_timed.csv`
	- `VP Clone/Logs/vp_perf_runtime_summary_step21_branch_k_ka_resolved_hierarchy_context_cache_tab_only_20260803T145948Z_timed.csv`
	- `VP Clone/Logs/vp_perf_runtime_summary_step21_branch_k_ka_display_month_hit_throttle_tab_only_20260803T150501Z_timed.csv`
	- `VP Clone/Logs/vp_perf_runtime_summary_step21_branch_k_ka_map_bottom_panel_suspend_tab_only_20260803T151022Z_timed.csv`
	- `VP Clone/Logs/vp_perf_runtime_summary_step21_branch_k_ka_year_filter_lazy_sync_tab_only_20260803T151527Z_timed.csv`
	- `VP Clone/Logs/vp_perf_runtime_summary_step21_branch_k_ka_summary_table_bindcache_tab_only_20260803T152015Z_timed.csv`

Runtime-summary findings:
- K-0 combined summary: `startup_init(load_vp_trade_monthly_data): currentity_check` count 4, total 1.8127 seconds, median 0.41245 seconds. Artifact read count 4, total 58.1989 seconds, median 14.12655 seconds.
- Warm-session confirmation: VP currentity count 1, 0.4506 seconds. Artifact read count 1, 15.5651 seconds.
- K-A tab-only summaries consistently show VP currentity count 1 per app session, not repeated per tab switch.
- K-A tab-only currentity examples:
	- Resolved hierarchy context cache tab-only: currentity 0.3231 seconds; artifact read 12.3309 seconds.
	- Display-month hit throttle tab-only: currentity 0.2929 seconds; artifact read 11.8904 seconds.
	- Map bottom-panel suspend tab-only: currentity 0.3726 seconds; artifact read 15.8515 seconds.
	- Summary-table bindCache tab-only: currentity 0.2842 seconds; artifact read 12.0849 seconds.
- `artifact_signature(build_file_signature)` appears in the same runtime summaries, typically count 34 for a single app session and under about 0.75-1.44 seconds total in the reviewed single-session runs. K-0 combined summary had count 136 and total 5.4429 seconds across four sessions.

Interpretation:
- Currentity is not the dominant canonical VP artifact-load cost by itself. It is usually about 0.3-0.7 seconds per startup/session in reviewed evidence, while artifact read is about 11.8-21.1 seconds in the same runs.
- Existing tab-only summaries do not show currentity checks recurring on every tab switch; they show one startup currentity check per app session.
- File-signature work is visible and should not be ignored, but the recurring `artifact_signature(build_file_signature)` bucket is broader than VP artifact currentity. It likely includes startup currentity/signature work plus provider/cache identity signatures. Do not change currentity policy based on this bucket alone.
- The biggest currentity problem for K-R remains experimental validity: noncanonical candidate artifacts cannot be used in decomposed/app-level timing unless manifest/currentity handling is solved.
- A VP-specific single-source currentity simplification is plausible later, but it should be designed as a deliberate source-update/cache-reset policy, not as a K-R shortcut that weakens stale-artifact refusal.

K-R2.5 decision:
- Do not treat currentity as the direct tab-switch bottleneck.
- Do not weaken production currentity validation in K-R2.5.
- Keep currentity/manifest handling as a K-R5 app-candidate setup requirement.
- Prefer a test-only artifact override or isolated root for K-R5 if app-level candidate timing becomes justified.
- Record a possible later simplification branch: VP single-source artifact epoch plus explicit cache reset on source update.

### K-R3 Provider Probes - 2026-08-03

Purpose:
- Compare partition-provider behavior across canonical, full-copy, native-only, and minimal-rollup artifacts using explicit artifact paths and isolated partition directories.
- Separate strict all-rollup scenario behavior from fairer native-row provider comparisons.

Probe notes:
- `vp_perf_probe_partition_provider.R` reads the full artifact at probe startup and records `artifact_load_elapsed_ms` on every output row.
- First pass against an empty isolated partition directory materializes partitions, so `provider_mode = materialized` is expected.
- A second pass against the same default-scenario partition dirs captures `provider_mode = disk_cache` and is the fairer disk-hit comparison.
- Strict rollup scenarios are semantically uneven for native-only/minimal-rollup candidates because all-rollup contexts can return zero or only the three synthetic contract rows.

Strict scenario output CSVs:
- Canonical strict: `VP Clone/Logs/vp_perf_probe_partition_provider_step21_branch_k_rollup_ablate_baseline_provider_strict_20260803T155753Z.csv`
- Full-copy strict: `VP Clone/Logs/vp_perf_probe_partition_provider_step21_branch_k_rollup_ablate_fullcopy_provider_strict_20260803T155830Z.csv`
- Native-only strict: `VP Clone/Logs/vp_perf_probe_partition_provider_step21_branch_k_rollup_ablate_native_only_provider_strict_20260803T155910Z.csv`
- Minimal-rollup strict: `VP Clone/Logs/vp_perf_probe_partition_provider_step21_branch_k_rollup_ablate_minimal_rollup_provider_strict_20260803T155928Z.csv`

Default scenario output CSVs, first materialization pass:
- Canonical default: `VP Clone/Logs/vp_perf_probe_partition_provider_step21_branch_k_rollup_ablate_baseline_provider_default_20260803T155942Z.csv`
- Full-copy default: `VP Clone/Logs/vp_perf_probe_partition_provider_step21_branch_k_rollup_ablate_fullcopy_provider_default_20260803T160015Z.csv`
- Native-only default: `VP Clone/Logs/vp_perf_probe_partition_provider_step21_branch_k_rollup_ablate_native_only_provider_default_20260803T160043Z.csv`
- Minimal-rollup default: `VP Clone/Logs/vp_perf_probe_partition_provider_step21_branch_k_rollup_ablate_minimal_rollup_provider_default_20260803T160102Z.csv`

Default scenario output CSVs, second disk-hit pass:
- Canonical default disk-hit: `VP Clone/Logs/vp_perf_probe_partition_provider_step21_branch_k_rollup_ablate_baseline_provider_default_diskhit_20260803T160141Z.csv`
- Full-copy default disk-hit: `VP Clone/Logs/vp_perf_probe_partition_provider_step21_branch_k_rollup_ablate_fullcopy_provider_default_diskhit_20260803T160213Z.csv`
- Native-only default disk-hit: `VP Clone/Logs/vp_perf_probe_partition_provider_step21_branch_k_rollup_ablate_native_only_provider_default_diskhit_20260803T160241Z.csv`
- Minimal-rollup default disk-hit: `VP Clone/Logs/vp_perf_probe_partition_provider_step21_branch_k_rollup_ablate_minimal_rollup_provider_default_diskhit_20260803T160253Z.csv`

Strict scenario summary:

| Variant | Artifact load ms | Scenario set | Provider mode | Elapsed ms range | Row-count pattern | Interpretation |
|---|---:|---|---|---:|---|---|
| canonical | 9675 | 5 strict rollup scenarios | materialized | 1752-4145 | 267151, 2753, 0, 0, 211 | Behavior-valid strict baseline. |
| full_copy | 12585 | 5 strict rollup scenarios | materialized | 1499-4415 | 267151, 2753, 0, 0, 211 | Full-artifact control; similar slice band. |
| native_only | 3567 | 5 strict rollup scenarios | materialized | 363-686 | 0, 0, 0, 0, 211 | Not a fair strict comparison; all-rollup rows absent. |
| minimal_rollup_contract | 3615 | 5 strict rollup scenarios | materialized | 374-712 | 1, 0, 0, 0, 211 | Performance-only; strict all-rollup rows mostly absent. |

Default native-row scenario, first materialization pass:

| Variant | Artifact load ms | Provider mode | Elapsed ms | Rows | Full slice rows |
|---|---:|---|---:|---:|---:|
| canonical | 15486 | materialized | 2275 | 211 | 30280 |
| full_copy | 13532 | materialized | 1922 | 211 | 30280 |
| native_only | 3721 | materialized | 1090 | 211 | 30280 |
| minimal_rollup_contract | 2898 | materialized | 859 | 211 | 30280 |

Default native-row scenario, second disk-hit pass:

| Variant | Artifact load ms | Provider mode | Payload read ms | Reconstruction ms | Elapsed ms | Rows | Full slice rows |
|---|---:|---|---:|---:|---:|---:|---:|
| canonical | 12147 | disk_cache | 4 | 40 | 2130 | 211 | 30280 |
| full_copy | 14159 | disk_cache | 6 | 29 | 1756 | 211 | 30280 |
| native_only | 3193 | disk_cache | 3 | 35 | 814 | 211 | 30280 |
| minimal_rollup_contract | 3341 | disk_cache | 3 | 34 | 834 | 211 | 30280 |

Interpretation:
- K-R3 reinforces the artifact-load finding: provider probes pay full artifact load before slicing, and reduced artifacts load in about 2.9-3.7 seconds versus about 9.7-15.5 seconds for full artifacts across these runs.
- Strict all-rollup scenarios cannot be used as correctness-equivalent speed evidence for native-only/minimal-rollup candidates because the candidate rows are not semantically equivalent.
- The default 211-row native scenario is a fairer provider comparison. It shows reduced artifacts cut materialized provider elapsed time from about 1.9-2.3 seconds to about 0.9-1.1 seconds.
- The same default scenario in disk-cache mode shows reduced artifacts at about 0.8 seconds versus about 1.8-2.1 seconds for full artifacts, even though payload read/reconstruction are tiny. The residual elapsed difference likely comes from metadata lookup/full-row metadata/parity/source-identity work over the larger in-memory artifact, not disk payload read itself.
- K-R3 does not prove app-level tab readiness, but it confirms the rollup bloat hypothesis affects provider-adjacent work as well as raw artifact load.
- K-R4 should now decide whether the combined K-R1/K-R2/K-R3 material deltas justify K-R5 currentity-safe app-candidate setup.

### K-R4 Gate: Phase 1 Evidence Summary and Recommendation - 2026-08-03

Decision: GO for K-R5 currentity-safe app-level candidate setup.

Evidence summary:

| Evidence area | Baseline/full artifact | Reduced artifact | Interpretation |
|---|---:|---:|---|
| Row count | 2115868 rows | 624176-624179 rows | Rollup rows are about 70.5% of canonical rows. |
| RDS file size | 167.0 MB | 48.1 MB | Reduced artifacts are about 71% smaller on disk. |
| Object size | 847.8 MB | 252.5 MB | Reduced artifacts are about 70% smaller in memory. |
| Read-only artifact load | 10449-12099 ms | 3286-3375 ms | Reduced artifacts read about 3x faster. |
| Canonical decomposed read | 10032 ms | Not currentity-safe in decomposed mode | Currentity-aware baseline confirms full-artifact read cost. |
| Currentity cost | 356 ms in K-R2 canonical decomposition | Blocked for noncanonical artifacts | Currentity is not the main load cost, but blocks app-candidate setup. |
| Fair default provider disk-hit | 1756-2130 ms | 814-834 ms | Reduced artifacts are about 2x faster for equivalent 211-row provider scenario. |
| Strict rollup provider scenarios | Behavior-valid | Semantically uneven | Strict all-rollup scenarios are not fair speed evidence for reduced candidates. |

Materiality assessment:
- K-R's initial materiality guide was 20-30% lower artifact read/object size plus a visible startup/tab-ready improvement outside normal variance before claiming a user-visible win.
- Phase 1 clears the first half of that bar by a wide margin: file size, object size, read-only artifact load, and fair provider elapsed time all move materially.
- Phase 1 does not yet clear the second half of the bar because no app-level startup/tab-ready candidate probe has run.
- Therefore the correct gate decision is not a production redesign yet. It is a justified move to K-R5/K-R6 app-level candidate testing.

Recommendation:
- Proceed to K-R5.
- Use a currentity-safe, test-only app candidate setup. The best next path is an explicit test-only artifact override, because it is narrower than copying an isolated root and safer than canonical file swapping.
- Keep production currentity validation intact.
- Keep the minimal-rollup app candidate classified as semantically invalid/performance-only. It may answer whether artifact bulk affects startup/tab readiness; it must not be used for correctness acceptance.
- Require candidate row-count proof and no-fallback proof before running K-R6 app probes.
- Run paired close-sequence startup and tab-only probes in K-R6 if K-R5 succeeds.

Rejected K-R4 alternatives:
- Do not stop at K-R4. Phase 1 evidence is too material to reject rollup bloat now.
- Do not jump directly to a production sidecar/lazy-rollup redesign. App-level startup/tab readiness has not been measured.
- Do not use native-only as the app candidate. It fails the production rollup contract and cannot represent startup behavior.
- Do not use naive canonical RDS swapping. K-R2 already showed manifest/currentity checks would make that evidence unreliable.

### K-R5 Currentity-Safe App Candidate Setup - 2026-08-03

Decision:
- Implemented option B: explicit test-only artifact override.
- Did not use an isolated root because the override is narrower and sufficient for K-R6 probes.
- Did not use manifest-aware canonical swapping because it is riskier and unnecessary after the override proof.

Files changed:
- `VP Clone/Programs/app_source/global.R`
	- Added `vp_perf_test_artifact_override_path()`.
	- Added `load_vp_trade_monthly_for_startup()`.
	- Replaced the direct `load_startup_dataset_for_source()` assignment for `rice_data_vp_trade_monthly` with `load_vp_trade_monthly_for_startup()`.
	- The override applies only to `vp_trade_monthly`, only when runtime perf is enabled, and only when `VP_PERF_TEST_ARTIFACT_OVERRIDE_ENABLED` is truthy.
	- The override path comes from `VP_PERF_TEST_VP_TRADE_ARTIFACT` and fails closed if the file is missing.
	- Production currentity validation remains unchanged for normal startup.
	- The override records startup load mode `perf_test_artifact_override` and emits runtime event `vp_perf_test_artifact_override` with candidate rows, columns, artifact path, and `fallback_rebuild=false`.
	- Fixed `runtime_perf_log_path()` so an empty `vp_perf_runtime_log_file` option no longer masks the `VP_PERF_RUNTIME_LOG_FILE` environment override set by probes.
- `VP Clone/System/Testing/vp_perf_probe_startup.R`
	- Added `--test-vp-trade-artifact` argument.
	- Sets `VP_PERF_TEST_ARTIFACT_OVERRIDE_ENABLED=true` and `VP_PERF_TEST_VP_TRADE_ARTIFACT=<path>` only when the argument is provided.
	- Records `test_vp_trade_artifact_path`, `test_vp_trade_artifact_exists`, and `test_vp_trade_artifact_rows` in the output CSV.
- `VP Clone/System/Testing/vp_perf_probe_single_action_latency.R`
	- Added matching `--test-vp-trade-artifact` support and output columns for candidate path/existence/row count.
	- Sets and unsets the same explicit override environment variables.

Validation before smoke:
- Parse marker: `PARSE_OK_GLOBAL_KR5_GATE`.
- Parse marker: `PARSE_OK_STARTUP_PROBE_KR5_GATE`.
- Parse marker: `PARSE_OK_SINGLE_ACTION_PROBE_KR5_GATE`.
- Parse marker after runtime-log-path fix: `PARSE_OK_GLOBAL_KR5_LOGPATH`.
- Diagnostics: no errors for `global.R`, `vp_perf_probe_startup.R`, or `vp_perf_probe_single_action_latency.R`.
- Diff check: `git diff --check -- "Programs/app_source/global.R" "System/Testing/vp_perf_probe_startup.R" "System/Testing/vp_perf_probe_single_action_latency.R"` completed with no output.

First smoke attempt:

```powershell
& "C:\Program Files\R\R-4.5.1\bin\Rscript.exe" "System/Testing/vp_perf_probe_startup.R" --label=step21_branch_k_kR5_minimal_rollup_override_smoke --cache-state=test_artifact_override --runtime-perf=true --target-tab="Current vs. Average" --startup-timeout-ms=120000 --stage-timeout-ms=30000 --output-timeout-ms=30000 --test-vp-trade-artifact="Logs/rollup_ablation/20260803T154625Z/vp_trade_monthly_minimal_rollup_contract.rds"
```

First smoke output:
- CSV: `VP Clone/Logs/vp_perf_probe_startup_step21_branch_k_kR5_minimal_rollup_override_smoke_20260803T161130Z.csv`
- Generated startup runtime JSONL: `VP Clone/Logs/vp_runtime_perf_proc_20260803T161156Z_27396.jsonl`
- Cache/runtime JSONL: `VP Clone/Logs/vp_runtime_perf_94b481c34342799f68b0713ea334b44d.jsonl`
- Status: FAIL.
- Reason: `required_controls_wait_failed:timeout || missing_controls:country_choice|commodity_choice`.
- Important interpretation: this was not an override failure. The app rendered the target plot and the runtime log proved the candidate loaded with 624179 rows and `fallback_rebuild=false`. The failure came from the standard startup probe's shared-control expectations interacting with the semantically invalid minimal-rollup candidate.
- Instrumentation bug found: the probe-requested runtime log path did not exist because `runtime_perf_log_path()` preferred an empty option value over `VP_PERF_RUNTIME_LOG_FILE`. Fixed in K-R5.

Successful smoke command after runtime-log-path fix:

```powershell
& "C:\Program Files\R\R-4.5.1\bin\Rscript.exe" "System/Testing/vp_perf_probe_startup.R" --label=step21_branch_k_kR5_minimal_rollup_override_smoke_logpath --cache-state=test_artifact_override --runtime-perf=true --target-tab="Current vs. Average" --startup-timeout-ms=120000 --stage-timeout-ms=10000 --output-timeout-ms=30000 --test-vp-trade-artifact="Logs/rollup_ablation/20260803T154625Z/vp_trade_monthly_minimal_rollup_contract.rds"
```

Successful smoke outputs:
- CSV: `VP Clone/Logs/vp_perf_probe_startup_step21_branch_k_kR5_minimal_rollup_override_smoke_logpath_20260803T161426Z.csv`
- Runtime JSONL: `VP Clone/Logs/vp_runtime_perf_startup_step21_branch_k_kR5_minimal_rollup_override_smoke_logpath_20260803T161426Z.jsonl`
- Status: PASS.
- Candidate path recorded: `VP Clone/Logs/rollup_ablation/20260803T154625Z/vp_trade_monthly_minimal_rollup_contract.rds`.
- Candidate row count recorded in CSV: 624179.
- Runtime proof event: `vp_perf_test_artifact_override`.
- Runtime proof details: `dataset_name=vp_trade_monthly`, rows 624179, cols 59, `fallback_rebuild=false`.
- Startup load mode: `perf_test_artifact_override`.
- VP trade load elapsed in this smoke: 6.8555 seconds.
- No `startup_init(load_vp_trade_monthly_data): currentity_check` event occurred for the VP trade artifact in the override path, by design. Production currentity still applies when the test override is not explicitly enabled.
- Probe runtime log path is now correctly honored: `runtime_log_exists=TRUE`, `runtime_log_candidates_count=1`, and `fallback_input` equals the requested startup runtime JSONL.

K-R5 interpretation:
- K-R5 solves the app-candidate setup blocker without mutating canonical processed data.
- The implementation is fail-closed and opt-in: a normal app startup will not use a candidate artifact unless runtime perf is enabled, the explicit enable flag is true, and an explicit candidate artifact path is present.
- The candidate remains semantically invalid/performance-only. The PASS smoke proves the app/probe can run through the override path; it does not make the minimal-rollup artifact a correctness candidate.
- Timing from the K-R5 smoke should not be treated as the final performance answer. It is setup proof. K-R6 needs paired close-sequence baseline/candidate runs before any timing conclusion.

K-R6 recommendation:
- Run paired startup baseline and minimal-rollup candidate probes close together, preferably at least two pairs.
- Run paired tab-only baseline and minimal-rollup candidate probes using the same `--test-vp-trade-artifact` hook.
- Use K-R5 proof fields as acceptance gates for every candidate run: candidate path exists, row count is 624179, runtime event `vp_perf_test_artifact_override` is present, and `fallback_rebuild=false`.
- Treat any missing controls, empty outputs, or semantically odd all-selection behavior as candidate-validity limits rather than production correctness evidence.

### K-R6 App-Level Startup and Tab-Only Probes - 2026-08-03

Purpose:
- Test whether the material artifact/provider gains from K-R1 through K-R4 translate into app-level startup or tab-readiness gains.
- Use the K-R5 test-only override, not canonical artifact swapping.
- Require candidate proof on every candidate run before interpreting timings.

Commands run, pair 1:

```powershell
& "C:\Program Files\R\R-4.5.1\bin\Rscript.exe" "System/Testing/vp_perf_probe_startup.R" --label=step21_branch_k_kR6_pair1_startup_baseline --cache-state=baseline_currentity --runtime-perf=true --target-tab="Current vs. Average" --startup-timeout-ms=120000 --stage-timeout-ms=30000 --output-timeout-ms=30000
& "C:\Program Files\R\R-4.5.1\bin\Rscript.exe" "System/Testing/vp_perf_probe_startup.R" --label=step21_branch_k_kR6_pair1_startup_minimal_rollup --cache-state=test_artifact_override --runtime-perf=true --target-tab="Current vs. Average" --startup-timeout-ms=120000 --stage-timeout-ms=30000 --output-timeout-ms=30000 --test-vp-trade-artifact="Logs/rollup_ablation/20260803T154625Z/vp_trade_monthly_minimal_rollup_contract.rds"
& "C:\Program Files\R\R-4.5.1\bin\Rscript.exe" "System/Testing/vp_perf_probe_single_action_latency.R" --label=step21_branch_k_kR6_pair1_tabonly_baseline --cache-state=warm_session --scenario=tab_only_revisit --runtime-perf=true --startup-timeout-ms=120000 --stage-timeout-ms=30000 --output-timeout-ms=20000 --full-idle-timeout-ms=30000
& "C:\Program Files\R\R-4.5.1\bin\Rscript.exe" "System/Testing/vp_perf_probe_single_action_latency.R" --label=step21_branch_k_kR6_pair1_tabonly_minimal_rollup --cache-state=test_artifact_override --scenario=tab_only_revisit --runtime-perf=true --startup-timeout-ms=120000 --stage-timeout-ms=30000 --output-timeout-ms=20000 --full-idle-timeout-ms=30000 --test-vp-trade-artifact="Logs/rollup_ablation/20260803T154625Z/vp_trade_monthly_minimal_rollup_contract.rds"
```

Commands run, pair 2:

```powershell
& "C:\Program Files\R\R-4.5.1\bin\Rscript.exe" "System/Testing/vp_perf_probe_startup.R" --label=step21_branch_k_kR6_pair2_startup_baseline --cache-state=baseline_currentity --runtime-perf=true --target-tab="Current vs. Average" --startup-timeout-ms=120000 --stage-timeout-ms=30000 --output-timeout-ms=30000
& "C:\Program Files\R\R-4.5.1\bin\Rscript.exe" "System/Testing/vp_perf_probe_startup.R" --label=step21_branch_k_kR6_pair2_startup_minimal_rollup --cache-state=test_artifact_override --runtime-perf=true --target-tab="Current vs. Average" --startup-timeout-ms=120000 --stage-timeout-ms=30000 --output-timeout-ms=30000 --test-vp-trade-artifact="Logs/rollup_ablation/20260803T154625Z/vp_trade_monthly_minimal_rollup_contract.rds"
& "C:\Program Files\R\R-4.5.1\bin\Rscript.exe" "System/Testing/vp_perf_probe_single_action_latency.R" --label=step21_branch_k_kR6_pair2_tabonly_baseline --cache-state=warm_session --scenario=tab_only_revisit --runtime-perf=true --startup-timeout-ms=120000 --stage-timeout-ms=30000 --output-timeout-ms=20000 --full-idle-timeout-ms=30000
& "C:\Program Files\R\R-4.5.1\bin\Rscript.exe" "System/Testing/vp_perf_probe_single_action_latency.R" --label=step21_branch_k_kR6_pair2_tabonly_minimal_rollup --cache-state=test_artifact_override --scenario=tab_only_revisit --runtime-perf=true --startup-timeout-ms=120000 --stage-timeout-ms=30000 --output-timeout-ms=20000 --full-idle-timeout-ms=30000 --test-vp-trade-artifact="Logs/rollup_ablation/20260803T154625Z/vp_trade_monthly_minimal_rollup_contract.rds"
```

Output files:
- Pair 1 startup baseline CSV: `VP Clone/Logs/vp_perf_probe_startup_step21_branch_k_kR6_pair1_startup_baseline_20260803T162010Z.csv`
- Pair 1 startup baseline runtime: `VP Clone/Logs/vp_runtime_perf_startup_step21_branch_k_kR6_pair1_startup_baseline_20260803T162010Z.jsonl`
- Pair 1 startup candidate CSV: `VP Clone/Logs/vp_perf_probe_startup_step21_branch_k_kR6_pair1_startup_minimal_rollup_20260803T162142Z.csv`
- Pair 1 startup candidate runtime: `VP Clone/Logs/vp_runtime_perf_startup_step21_branch_k_kR6_pair1_startup_minimal_rollup_20260803T162142Z.jsonl`
- Pair 1 tab-only baseline CSV: `VP Clone/Logs/vp_perf_probe_single_action_latency_step21_branch_k_kR6_pair1_tabonly_baseline_20260803T162300Z.csv`
- Pair 1 tab-only baseline runtime: `VP Clone/Logs/vp_runtime_perf_single_action_step21_branch_k_kR6_pair1_tabonly_baseline_20260803T162300Z.jsonl`
- Pair 1 tab-only candidate CSV: `VP Clone/Logs/vp_perf_probe_single_action_latency_step21_branch_k_kR6_pair1_tabonly_minimal_rollup_20260803T162559Z.csv`
- Pair 1 tab-only candidate runtime: `VP Clone/Logs/vp_runtime_perf_single_action_step21_branch_k_kR6_pair1_tabonly_minimal_rollup_20260803T162600Z.jsonl`
- Pair 2 startup baseline CSV: `VP Clone/Logs/vp_perf_probe_startup_step21_branch_k_kR6_pair2_startup_baseline_20260803T163039Z.csv`
- Pair 2 startup baseline runtime: `VP Clone/Logs/vp_runtime_perf_startup_step21_branch_k_kR6_pair2_startup_baseline_20260803T163039Z.jsonl`
- Pair 2 startup candidate CSV: `VP Clone/Logs/vp_perf_probe_startup_step21_branch_k_kR6_pair2_startup_minimal_rollup_20260803T163243Z.csv`
- Pair 2 startup candidate runtime: `VP Clone/Logs/vp_runtime_perf_startup_step21_branch_k_kR6_pair2_startup_minimal_rollup_20260803T163243Z.jsonl`
- Pair 2 tab-only baseline CSV: `VP Clone/Logs/vp_perf_probe_single_action_latency_step21_branch_k_kR6_pair2_tabonly_baseline_20260803T163410Z.csv`
- Pair 2 tab-only baseline runtime: `VP Clone/Logs/vp_runtime_perf_single_action_step21_branch_k_kR6_pair2_tabonly_baseline_20260803T163410Z.jsonl`
- Pair 2 tab-only candidate CSV: `VP Clone/Logs/vp_perf_probe_single_action_latency_step21_branch_k_kR6_pair2_tabonly_minimal_rollup_20260803T163729Z.csv`
- Pair 2 tab-only candidate runtime: `VP Clone/Logs/vp_runtime_perf_single_action_step21_branch_k_kR6_pair2_tabonly_minimal_rollup_20260803T163729Z.jsonl`

Startup results:

| Pair | Variant | Status | Startup ready ms | Total probe ms | Output visible ms | Candidate rows |
|---|---|---|---:|---:|---:|---:|
| 1 | baseline | PASS | 85051 | 85796 | 21 | NA |
| 1 | minimal_rollup | PASS | 59815 | 60353 | 17 | 624179 |
| 2 | baseline | PASS | 111341 | 112070 | 23 | NA |
| 2 | minimal_rollup | PASS | 74559 | 75249 | 26 | 624179 |

Startup interpretation:
- Startup improvement repeated across both close-sequence pairs.
- Pair 1 startup-to-ready improved by 25236 ms, from 85051 ms to 59815 ms, about 29.7% faster.
- Pair 2 startup-to-ready improved by 36782 ms, from 111341 ms to 74559 ms, about 33.0% faster.
- Runtime logs show canonical baseline VP trade loads used normal currentity and artifact read:
	- Pair 1 baseline: currentity 0.4036 seconds, artifact read 15.7496 seconds, total `startup_init(load_vp_trade_monthly_data)` 16.1671 seconds, rows 2115868.
	- Pair 1 candidate: `perf_test_artifact_override` load 3.7316 seconds, rows 624179.
	- Pair 2 baseline: normal currentity/artifact path in the canonical runtime log; startup CSV confirms canonical path and no candidate rows.
	- Pair 2 candidate: `perf_test_artifact_override` load 4.8481 seconds, rows 624179.
- K-R6 therefore supports rollup bloat as a material startup/artifact-load lever.

Tab-only action results, visible-ready means across eight actions:

| Pair | Variant | Mean visible ready ms | Mean client ready ms | Mean full idle ms | Candidate rows |
|---|---|---:|---:|---:|---:|
| 1 | baseline | 8533.9 | 8705.9 | 9238.0 | NA |
| 1 | minimal_rollup | 10534.4 | 10646.1 | 11545.4 | 624179 |
| 2 | baseline | 10459.0 | 10590.6 | 11113.3 | NA |
| 2 | minimal_rollup | 7402.3 | 7562.1 | 8076.4 | 624179 |

Tab-only detailed interpretation:
- Pair 1 tab-only actions were slower on average under the minimal-rollup candidate.
- Pair 2 tab-only actions were faster on average under the minimal-rollup candidate.
- Because direction flips between pairs, K-R6 does not prove rollup bloat as a stable tab-only/tab-paint lever.
- The tab-only results may reflect warm-cache variance, browser/rendering variance, or the semantically invalid candidate changing downstream output complexity in ways that are not correctness-equivalent.
- Treat K-R6 tab-only as inconclusive rather than as a rejection of startup evidence.

Candidate proof:
- Every candidate CSV recorded `test_vp_trade_artifact_rows = 624179`.
- Candidate runtime logs emitted `vp_perf_test_artifact_override`.
- Candidate runtime logs recorded `perf_test_artifact_override` mode for `startup_init(load_vp_trade_monthly_data)`.
- Candidate runtime logs recorded `fallback_rebuild=false` in the override proof event.
- No canonical files were swapped or mutated for K-R6.

K-R6 decision:
- Accept: rollup artifact bulk is a material startup/artifact-load performance lever.
- Do not accept: minimal-rollup as a correctness candidate.
- Do not accept yet: rollup artifact bulk as a proven tab-paint/tab-only lever.
- Recommended next step is K-R8 closeout and Branch K roll-up, with a production recommendation to investigate sidecar/lazy rollup architecture for startup/artifact-load improvement rather than deleting rollups from the production artifact.

### K-R8 Closeout and Parent Roll-Up - 2026-08-03

Closeout decision:
- K-R is closed as an evidence and architecture-direction tranche.
- K-R7 restore/cleanup is not required because the app-level candidate path never swapped canonical processed artifacts. K-R5/K-R6 used an explicit test-only override with row-count and no-fallback proof.
- Detailed evidence remains in this ledger. The Branch K parent receives the executive summary and decision, and the VP performance hotspot parent receives the broader production architecture recommendation.

Accepted findings:
- Embedded rollup rows are a large artifact-shape signal: about 1.49M of 2.12M canonical rows, or about 70.5% of `vp_trade_monthly_pre.rds`.
- Reduced artifacts cut the RDS file from about 167 MB to about 48 MB and in-memory object size from about 848 MB to about 253 MB.
- Read-only reduced artifacts loaded in about 3.3 seconds versus about 10.4-12.1 seconds for canonical/full-copy artifacts.
- Fair default provider scenarios also improved for reduced artifacts, with disk-hit elapsed time around 0.8 seconds versus about 1.8-2.1 seconds for full artifacts.
- K-R6 startup improvement repeated in two close-sequence pairs: 85051 ms to 59815 ms in pair 1 and 111341 ms to 74559 ms in pair 2.

Rejected or bounded findings:
- Minimal-rollup is not a correctness candidate and must not be shipped as a production artifact.
- K-R6 tab-only results are inconclusive because pair 1 was slower for the candidate and pair 2 was faster.
- Immediate deletion of production rollup rows is rejected because the rollups preserve real all-selection semantics.
- Currentity is not the direct repeated tab-switch bottleneck in reviewed evidence, but it remains a safety boundary for artifact experiments and future partition-bundle validation.

Architecture recommendation:
- Do not continue with small Branch K fanout/output-settling edits as the next primary workstream.
- Do not create a production native-only or minimal-rollup artifact.
- The next architecture direction should be a separate, deliberately planned VP lazy partition architecture: a small startup shell/metadata artifact, commodity-level native partitions loaded on demand, and commodity/context rollup sidecars loaded only when strict all-selection semantics require them.
- The expected benefit is broader than rollup sidecar alone because it attacks startup artifact load, active working-set size, hierarchy/filter cascade breadth, provider metadata work, and reactive invalidation fanout.
- The main risk is correctness/orchestration complexity: controls must initialize from metadata, commodity changes need deterministic latest-request-wins behavior, all-commodity/global views need explicit aggregate paths, and the manifest/currentity contract must validate the whole partition bundle.

Pause point:
- K-R and Branch K should now roll up to the VP performance hotspot parent.
- No new standalone architecture plan should be created until after the user reviews the parent closeout and explicitly starts the next plan.

## Bugs / Blockers / Failed Attempts / Rejected Approaches

- Rejected before implementation: naive RDS-only canonical artifact swapping for app-level candidate probes.
- Rejected before implementation: treating native-only artifacts as app-startable under current production validation.
- Rejected before implementation: treating minimal-rollup candidate artifacts as correctness candidates.
- K-R2 full-copy decomposed probe failed with `manifest_entry_missing`; accepted as confirmation of the currentity blocker, not as a failed experiment.
- K-R2.5 rejected treating currentity as the direct tab-switch bottleneck based on current evidence. It remains an app-candidate blocker and possible future simplification target.
- K-R3 rejected strict all-rollup provider scenarios as fair semantic speed comparisons for native-only/minimal-rollup artifacts because most strict rollup rows are absent or reduced to contract stubs.
- K-R4 rejected stopping after Phase 1 because artifact and provider deltas are material enough to justify app-level candidate testing.
- K-R4 rejected jumping straight to production redesign because user-visible startup/tab readiness has not been measured with a candidate.
- K-R5 first startup smoke failed standard probe PASS criteria because the semantically invalid minimal-rollup candidate initially left `country_choice` and `commodity_choice` missing before the 30-second controls timeout. This did not falsify the override path; runtime proof still showed 624179 candidate rows and `fallback_rebuild=false`.
- K-R5 found and fixed a runtime-log-path instrumentation bug where an empty `vp_perf_runtime_log_file` option masked the probe-provided `VP_PERF_RUNTIME_LOG_FILE` env override.
- K-R5 rejected using the successful smoke timing as a final speed claim. The smoke is setup proof; K-R6 must run paired baseline/candidate probes.
- K-R6 rejected using pair 1 tab-only results alone because pair 2 flipped direction. Tab-only evidence is inconclusive.
- K-R6 rejected interpreting minimal-rollup output speed as correctness-equivalent behavior because the candidate is still semantically invalid/performance-only.
- K-R6 rejected immediate production deletion of rollup rows. The supported production direction is a sidecar/lazy rollup redesign investigation, not removing required all-selection semantics.

## Final Summary

K-R is closed. K-R1 created isolated full-copy, native-only, and minimal-rollup candidate artifacts without mutating canonical processed data. K-R2 showed a material read/object-size signal: reduced artifacts read in about 3.3 seconds versus about 10.4-12.1 seconds for full artifacts in read-only mode. K-R2.5 showed currentity is usually sub-second and startup/session-scoped in reviewed evidence, not a direct repeated tab-switch bottleneck. K-R3 showed reduced artifacts also improve fair default provider scenarios, including disk-hit elapsed time of about 0.8 seconds versus about 1.8-2.1 seconds for full artifacts. K-R5 implemented and proved a currentity-safe, test-only artifact override. K-R6 then showed a repeated startup win in two close-sequence pairs: startup-to-ready improved by about 25.2 seconds in pair 1 and about 36.8 seconds in pair 2. K-R6 did not show a stable tab-only win because pair 1 was slower for the candidate and pair 2 was faster. The practical conclusion is that embedded rollup bulk is a real startup/artifact-load lever, but the minimal-rollup candidate is not shippable and tab-paint benefit remains unproven. The recommended next architecture direction is more aggressive than a rollup sidecar alone: a small startup shell, commodity-level native partitions loaded on demand, and commodity/context rollup sidecars loaded only when strict all-selection semantics require them.
