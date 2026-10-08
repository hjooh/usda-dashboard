# VP AP Directory Cleanup Plan

Date: 2026-07-29
Branch: main
Status: Implementation complete with targeted validation; full smoke/perf evidence partially blocked by runtime harness behavior. This file is the source of truth for VP AP directory cleanup implementation.

## Purpose

Clean up VP app directory and output infrastructure so runtime behavior matches the VP contract reality:
- VP exports publish directly to `VP Clone/Output`.
- Obsolete output subdirectories (`Output/Custom Data`, `Output/Hybrid`) are not recreated.
- Unused hybrid generation utility is removed safely.
- Disabled raw artifact contract roles are removed only after startup code no longer requires them.

## Scope

Included:
- New source-of-truth implementation ledger in VP Code Review.
- Baseline inventory and reference audit.
- VP publish-output flattening to `VP Clone/Output` root.
- Removal of obsolete hybrid output scaffolding.
- Removal of `Programs/hybrid_generation_utils.R` with safe symbol replacement where needed.
- Decoupling disabled raw artifact role lookups in `global.R`.
- Pruning disabled raw artifact roles from `System/Config/vp_contract.R`.
- Low-risk disabled-source startup churn reduction where safe.
- Targeted parse/startup/reference/output validation.

Excluded:
- Broad deletion of shared server branches in `02_partner_and_notes.R` / `05_trend_and_heatmap.R` beyond low-risk targeted cleanup.
- Deletion of `shared_source_harmonization_utils.R`.
- Non-VP behavior changes.
- Almond contract/app changes.
- Paired results markdown file.

## Source-Of-Truth Ledger Contract

- This file is the active implementation ledger and must be updated after each step/tranche.
- Record failed attempts, rejected approaches, blockers, and bug discoveries here.
- Keep command/evidence summaries concise and deterministic.
- Keep this as the single implementation progress tracker.
- During implementation chat, use code-only responses; detailed progress is tracked in this file.
- After implementation completion, provide a short completion summary in chat.

## Baseline Audit Findings

- `VP Clone/Output` is empty.
- `VP Clone/Output/Custom Data/` is absent after user cleanup and should not be recreated.
- `VP Clone/Output/Hybrid/` should remain absent/empty and should not be recreated.
- `publish_data_to_csv()` in `Programs/app_source/global.R` defaults to `custom_data_dir`.
- Data and MYC publish helpers in `Programs/app_source/server/05_trend_and_heatmap.R` default to `custom_data_dir`.
- `Programs/hybrid_generation_utils.R` is sourced at startup.
- `required_hybrid_provenance_cols`, `required_hybrid_weekly_metadata_cols`, and `hybrid_market_month_name_lookup` are consumed in `global.R`; safe removal requires replacement definitions.
- `vp_contract.R` still defines disabled raw artifact roles:
  - `census_exports_raw`, `census_imports_raw`
  - `psd_lookup`, `psd_raw`, `psd_metadata`, `psd_summary`
  - `nass_raw`
- `contract_artifact_path()` is fail-closed for missing roles, so code-side decoupling must land before or with contract pruning.

## Current Implementation State

- `publish_data_to_csv()` now defaults to `app_output_dir` (`VP Clone/Output`).
- Data and MYC publish helpers now default to `app_output_dir`.
- Startup directory creation no longer includes `Output/Custom Data` or `Output/Hybrid`.
- `Programs/hybrid_generation_utils.R` is no longer sourced and has been removed.
- Hybrid constants used by `global.R` were inlined to preserve startup behavior.
- Disabled raw artifact roles were removed from `vp_contract.R`:
  - `census_exports_raw`, `census_imports_raw`
  - `psd_lookup`, `psd_raw`, `psd_metadata`, `psd_summary`
  - `nass_raw`
- Raw artifact path lookups tied to removed roles were removed from `global.R`; disabled source raw path variables now resolve to empty placeholders without contract role lookups.
- `app_ui_metadata_source_paths` is now VP-only (`vp_trade`).

## Guardrails

- Do not over-prune VP contract to only `vp_trade`, `custom_types`, and `cache`.
- Keep processed placeholder artifacts for disabled source families in this tranche.
- Keep `shared_source_harmonization_utils.R` in place.
- Avoid broad server surgery in this tranche.
- Keep changes VP-scoped and avoid Almond-side regressions.

## Step Ledger

| Step | Work | Status | Notes |
|---|---|---|---|
| 1 | Create source-of-truth ledger in VP Code Review | Complete | This file created before code edits. |
| 2 | Baseline inventory and reference audit | Complete | Captured git status, output directory state, and reference scan evidence below. |
| 3 | Flatten publish output to `VP Clone/Output` | Complete | `global.R` publish helper default switched to `app_output_dir`; server publish helpers switched to `app_output_dir`. |
| 4 | Remove obsolete output-directory recreation | Complete | Startup `dir.create` loop no longer includes custom/hybrid output directories. |
| 5 | Remove hybrid utility with safe symbol replacement | Complete | Inlined required hybrid constants in `global.R`, removed hybrid utility sourcing, deleted `Programs/hybrid_generation_utils.R`. |
| 6 | Decouple disabled raw-role lookups in `global.R` | Complete | Raw lookups guarded by `startup_source_enabled(...)`; VP-only app metadata source paths applied. |
| 7 | Prune disabled raw roles in `vp_contract.R` | Complete | Removed raw roles listed in scope after decoupling. |
| 8 | Low-risk startup churn cleanup and validation | Complete (targeted) | Parse/reference/path checks complete; contract validation passed; smoke/perf harness evidence partially blocked by environment behavior (`long-running smoke`, `Reason: On CRAN`). |
| 9 | Close ledger with final Summary | Complete | Final scope/outcome/blocker summary recorded below in lay terms. |

## Phase Plan

Phase A: Ledger and baseline
- Create ledger.
- Capture baseline evidence and audit references.

Phase B: Output flattening
- Route publish outputs to `VP Clone/Output` root.
- Stop obsolete output subdirectory recreation.

Phase C: Hybrid utility removal
- Replace required hybrid constants in `global.R`.
- Remove hybrid utility sourcing and delete file.

Phase D: Disabled raw-role contract alignment
- Remove/guard raw-role usage in `global.R`.
- Prune disabled raw roles from `vp_contract.R`.

Phase E: Validation and closeout
- Parse checks and startup/reference probes.
- Publish output and directory non-recreation checks.
- Optional smoke/perf checks if harness stability allows.
- Final summary and residual risk notes.

## Verification and Validation Targets

- Parse touched files:
  - `Programs/app_source/global.R`
  - `Programs/app_source/server/05_trend_and_heatmap.R`
  - `System/Config/vp_contract.R`
- Startup probe confirms no missing artifact-role failures after contract pruning.
- Reference checks confirm removal of active dependencies on:
  - `custom_data_dir`, `hybrid_output_dir`, `hybrid_generation_utils_path`
  - removed raw roles in `startup_artifact_path(...)`
- Output checks confirm publish files land in `VP Clone/Output` root.
- Directory checks confirm `Output/Custom Data` and `Output/Hybrid` are not recreated.
- Optional smoke/perf:
  - `System/Testing/vp_shinytest_smoke.R`
  - `System/Testing/vp_lightweight_perf_smoke.R`

## Bugs, Blockers, Failed Attempts, Rejected Approaches

- Baseline note: workspace is dirty before this tranche (`git status --short` showed deleted `Output/Custom Data` files and untracked `VP Clone/System/Processed Data/`). These are treated as pre-existing and not reverted.
- Implementation bug (resolved): first delete attempt for `Programs/hybrid_generation_utils.R` reported success but file remained on disk. A second explicit delete removed it correctly; status now shows the file deleted.
- Validation blocker (environment): `vp_shinytest_smoke.R` did not produce a deterministic pass/fail marker during this tranche and was manually terminated after extended idle runtime.
- Validation blocker (environment): `vp_lightweight_perf_smoke.R` halted with `Error: Reason: On CRAN` in this runtime context.
- Rejected for this tranche: broad shared-server deletion across disabled source families.
- Rejected for this tranche: pruning contract to only minimal VP roles.

## Tranche Execution Notes

- 2026-07-29 Tranche A (ledger + baseline):
  - Created this ledger as source-of-truth file.
  - Baseline command: `git status --short`.
    - Observed:
      - `D VP Clone/Output/Custom Data/SETH_WECHSLER__Accumulated_Exports__All__World__20260729_100903_395.csv`
      - `D VP Clone/Output/Custom Data/SETH_WECHSLER__Accumulated_Exports__All__World__20260729_102955_403.csv`
      - `?? VP Clone/System/Processed Data/`
  - Output inventory:
    - `VP Clone/Output` currently empty.
  - Reference scan highlights:
    - `global.R` still defines and uses `custom_data_dir`, `hybrid_output_dir`, and disabled raw artifact paths.
    - `05_trend_and_heatmap.R` publish helpers still default to `custom_data_dir`.
    - `global.R` consumes hybrid constants currently defined by `hybrid_generation_utils.R`.

- 2026-07-29 Tranche B-D (core code edits):
  - Edited files:
    - `Programs/app_source/global.R`
    - `Programs/app_source/server/05_trend_and_heatmap.R`
    - `System/Config/vp_contract.R`
    - `Programs/hybrid_generation_utils.R` (deleted)
  - Diffstat snapshot:
    - `global.R`: 66 lines touched
    - `05_trend_and_heatmap.R`: 4 lines touched
    - `hybrid_generation_utils.R`: deleted (1351 lines)
    - `vp_contract.R`: 7 lines removed
  - Parse validation:
    - `PARSE_OK` for `global.R`, `05_trend_and_heatmap.R`, `vp_contract.R`.
  - Contract validation:
    - `VP_CONTRACT_VALIDATE_OK` after raw role pruning.
  - Reference/path checks:
    - No `custom_data_dir`, `hybrid_output_dir`, or `hybrid_generation_utils_path` references remain in `Programs/app_source/**`.
    - `Output` currently empty.
    - `Output/Custom Data=False`, `Output/Hybrid=False` by `Test-Path` probe.

- 2026-07-29 Tranche E (validation in progress):
  - Parse recheck:
    - `PARSE_OK` for `global.R`, `05_trend_and_heatmap.R`, and `vp_contract.R`.
  - Contract schema recheck:
    - `VP_CONTRACT_VALIDATE_OK`.
  - Smoke harness attempt:
    - `Rscript VP Clone/System/Testing/vp_shinytest_smoke.R` entered long-running state after package-load warnings; no deterministic pass/fail marker captured yet in this tranche.
  - Lightweight perf attempt:
    - `Rscript VP Clone/System/Testing/vp_lightweight_perf_smoke.R` failed fast with:
      - `VP_LIGHTWEIGHT_PERF_START`
      - `VP_LIGHTWEIGHT_PERF_RUNS=1`
      - `VP_LIGHTWEIGHT_PERF_LABEL=baseline`
      - `VP_LIGHTWEIGHT_PERF_RUNTIME_ENABLED=TRUE`
      - `Error: Reason: On CRAN`
      - `Execution halted`
  - Validation interpretation:
    - Core code edits are parse-clean and contract-valid.
    - Full smoke/perf evidence remains partially blocked by harness/runtime environment behavior.

- 2026-07-29 Tranche F (final decoupling polish):
  - Removed lingering removed-role lookup calls from `global.R`:
    - `startup_artifact_path("census_exports_raw")`
    - `startup_artifact_path("census_imports_raw")`
    - `startup_artifact_path("psd_raw")`
    - `startup_artifact_path("psd_metadata")`
    - `startup_artifact_path("nass_raw")`
  - Set associated disabled source raw-path variables to empty placeholders.
  - Re-parse result: `PARSE_OK`.
  - Reference recheck:
    - No removed raw role tokens remain in `vp_contract.R`.
    - No `custom_data_dir`, `hybrid_output_dir`, or `hybrid_generation_utils_path` remain in `Programs/app_source/**`.

## Summary

Scope completed:
- Created and maintained this Code Review file as the source-of-truth implementation ledger.
- Flattened VP publish output so app publishing defaults now target `VP Clone/Output` root.
- Removed startup recreation paths for obsolete output directories (`Output/Custom Data`, `Output/Hybrid`).
- Removed `Programs/hybrid_generation_utils.R` and removed startup sourcing of that file.
- Preserved required hybrid column/name constants by inlining them into `global.R` so dependent startup paths remain valid.
- Removed disabled raw artifact roles from `System/Config/vp_contract.R`:
  - `census_exports_raw`, `census_imports_raw`
  - `psd_lookup`, `psd_raw`, `psd_metadata`, `psd_summary`
  - `nass_raw`
- Fully decoupled removed roles from `global.R` by removing raw-role `startup_artifact_path(...)` lookups and replacing those disabled raw-path variables with empty placeholders.

Outcome in plain terms:
- The VP app is now configured to save published output files directly into the main `Output` folder rather than old subfolders.
- The app no longer carries the hybrid-generation utility script that VP does not use.
- The VP contract and startup code are better aligned: removed raw roles are no longer requested during startup, which reduces stale-path churn and avoids fail-closed role lookup problems.

What deliberately did not change:
- Broad shared-server cleanup for disabled source families (Notes/PSD/NASS/WASDE/Census) was intentionally deferred to avoid risky regressions.
- `shared_source_harmonization_utils.R` was intentionally retained because shared startup/placeholder behavior still depends on it.

Validation outcome:
- Parse checks passed for all touched core files (`PARSE_OK`).
- VP contract schema validation passed after role pruning (`VP_CONTRACT_VALIDATE_OK`).
- Reference checks confirmed removal of key stale symbols and removed-role tokens in target files.
- Directory checks confirmed `Output/Custom Data` and `Output/Hybrid` are absent.

Bugs and blockers investigated/resolved:
- Resolved bug: the first delete attempt for `Programs/hybrid_generation_utils.R` reported success but the file remained on disk; a second explicit delete removed it.
- Blocker (environment): `vp_shinytest_smoke.R` entered a long-running idle state without deterministic pass/fail output in this session and was manually terminated.
- Blocker (environment): `vp_lightweight_perf_smoke.R` halted with `Error: Reason: On CRAN` in this runtime context.

Lay conclusion:
This cleanup successfully removed outdated VP plumbing and simplified where VP output is written, while keeping risk low by avoiding deep shared-server surgery. Most technical goals were completed and validated with parse/contract/reference checks. Full smoke/perf runtime proof is partially pending because of environment-specific harness behavior, not because of a detected syntax or contract failure in the implemented patch.
