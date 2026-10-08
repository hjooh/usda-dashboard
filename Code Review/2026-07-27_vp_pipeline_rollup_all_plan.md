# VP Pipeline Rollup All Plan

Date: 2026-07-27
Branch: main
Status: Active IN PROGRESS. This file is the source of truth for VP rollup plus runtime performance recovery implementation.

## Purpose

This tranche implements deterministic VP hierarchy rollups in the build pipeline and deterministic app-side resolver mapping for all-selection paths. The goal is to remove no-filter all-selection behavior that can produce mixed subordinate rows, duplicate-grain artifacts in downstream tabs, and inconsistent values between Current vs Historical, Historical Trendlines, Pace, and MYC.

## Scope

Included:
- VP additive rollups for Volume and Value under strict parent-child path rules.
- Option A only: generate rollups for UI-reachable all-selection paths.
- Deterministic VP resolver for Group/Subgroup/Market Segment all-selection behavior.
- MYC country mode and type mode protections against rollup-plus-subordinate double count.
- Cache-key hardening on touched VP bindCache surfaces.
- Startup compatibility checks for required VP rollup schema fields.
- Unit Value hide contract in aggregate rollup contexts.
- Deterministic validation fixtures in VP smoke checks.

Excluded:
- CommodityName-wide all rollups (no all-commodity UI path in this tranche).
- Weighted aggregate Unit Value calculation.
- Non-VP behavior changes.
- Full rollup lattice beyond strict parent-child matrix.

## Source-Of-Truth Ledger Contract

- This file is the active implementation ledger and must be updated after each step/tranche.
- Record failed attempts, rejected approaches, blockers, and bug discoveries here.
- Keep command/evidence summaries concise and deterministic.
- No paired results markdown unless explicitly requested.

## Critical Audit Findings

- Existing VP artifact creates Type All rows only at narrow native hierarchy grain.
- VP all-selections can behave as no-filter in app paths, causing mixed-grain rows.
- Some tabs defensively collapse duplicates; others render row-grain directly.
- MYC share/table paths can double count if rollup and subordinate rows both contribute.
- Future source growth increases importance of strict schema and deterministic resolver behavior.

## Guardrails

- Keep changes VP-scoped and minimize unrelated refactors.
- Prefer pipeline rollups plus resolver mapping over tab-specific ad hoc aggregation patches.
- Keep Current vs Historical behavior as regression baseline.
- Enforce strict parent-child selection matrix only.
- Keep Unit Value unavailable in aggregate rollup contexts.

## Selection Path Matrix

Resolved strict parent-child paths only:
- Path P0 (native): Group specific, Subgroup specific, Market Segment specific.
- Path P1 (segment all): Group specific, Subgroup specific, Market Segment all.
- Path P2 (subgroup all): Group specific, Subgroup all, Market Segment all.
- Path P3 (group all): Group all, Subgroup all, Market Segment all.

Disallowed sparse combinations in this tranche:
- Group all with specific Subgroup.
- Group all with specific Market Segment.
- Group specific with Subgroup all and specific Market Segment.

## Step Ledger

| Step | Work | Status | Notes |
|---|---|---|---|
| 1 | Create source-of-truth ledger | Complete | This file created before implementation edits. |
| 2 | Implement VP pipeline sentinel/rollup schema | Complete | `vp_data_utils.R` now emits sentinel-tagged strict-path P0/P1/P2/P3 rollups, schema metadata, mixed-volume flags, and builder floor metadata; builder version bumped to `vp_trade_artifact_2026_07_28_v5` after mixed-YTD suppression fix. |
| 3 | Wire deterministic VP resolver in app filters | Complete | Shared resolver integrated across main VP filters and custom-comparison helpers; trend and heatmap use `filtered_data()` and the only direct `base_data_converted()` hit in `05_trend_and_heatmap.R` is NASS-specific. |
| 4 | Apply custom-type and MYC pre-sum safeguards | Complete | MYC rollup precedence applied in `02_partner_and_notes.R`; custom type materialization now excludes rollup sentinel rows in `global.R`. |
| 5 | Apply Unit Value aggregate-hide enforcement | Complete | Aggregate Unit Value and mixed-volume-family metric gating added in VP metric-choice path in `02_partner_and_notes.R`. |
| 6 | Cache-key hardening across touched VP surfaces | Complete | `global.R` cache data version includes VP metadata artifact and custom-country signatures; comparison plus trend/heatmap plot cache keys now include resolved VP hierarchy filters/path and custom-country definitions. |
| 7 | Validation and fixture updates | In progress | Rebuilt artifact validation passed after builder `vp_trade_artifact_2026_07_28_v5`: 2,115,868 rows, all rollup levels present, 25,518 mixed-volume rollup rows with suppressed monthly/YTD volume. Full smoke rerun still pending. |
| 8 | Repair VP launcher progress feedback | Not started | Launcher window disappearance is tabled unless it recurs; add reliable rebuild progress feedback because the UI progress area does not advance while long rebuild work is running. |
| 9 | Final ledger closeout summary | Not started | Lay summary with outcomes and blockers. |
| 10 | Launch performance recovery tranche in ledger | Complete | Added explicit runtime-performance tranche, decision gates, and handoff sequencing to this source-of-truth file before code changes. |
| 11 | Add structured runtime PERF sink | Complete | Runtime sink implemented in `app_source/global.R` with flag/env gating, session-scoped JSONL output under `Logs`, memory snapshots, and integration in `log_perf()`, `record_cache_body_execution()`, and `record_cache_key_delta()`. |
| 12 | Create lightweight VP smoke/perf scenario | Complete | Added `System/Testing/vp_lightweight_perf_smoke.R` with minimal assertions and timed VP interaction path; emits raw/summary CSVs for median comparisons. |
| 13 | Collect baseline lightweight perf (3 runs) | Complete | Baseline rerun captured with label `baseline_pre_opt_20260728_rerun`: 2 PASS and 1 FAIL (stability timeout at startup idle gate). Median/range recorded from PASS runs in tranche notes. |
| 14 | Vertical slice provider + partition loading | Complete | Added VP partition provider abstraction and disk-backed hierarchy slice loading for the VP resolved hierarchy path; provider is now used by `filter_vp_rows_for_resolved_hierarchy()` with direct-filter fallback. |
| 15 | Partition manifest and fallback rules | Complete | Added partition manifest, top-level/source compatibility checks, per-slice entry validation, disk-cache row/column checks, and materialize-on-missing/stale/corrupt fallback logging. Focused probe passed. |
| 16 | Post-slice perf rerun and gate decision | Complete | Post-slice benchmark (`post_slice_20260728`) completed with 2 PASS, 1 FAIL (missing `country_choice` control in run 3). PASS-run medians improved substantially vs baseline; gate decision is Continue with Step 15 hardening and benchmark stability follow-up. |
| 17 | Startup default polish | Complete | Corrected VP source-entry handoff so startup resolves to `ytd_exports` / Accumulated Exports and `lbs` / Pounds even when stale Shiny inputs are present. App startup probe passed. |

## Phase Plan

Phase A: Pipeline schema and rollup generation
- Introduce collision-safe internal VP rollup sentinels.
- Add rollup provenance fields and rollup schema version.
- Extend rollup builder to strict path matrix.
- Preserve additive Value rollups.
- Preserve Unit Value unavailability on aggregate rows.

Phase B: App deterministic resolver
- Add one shared VP resolver for hierarchy selection.
- Canonicalize sparse selections to strict matrix.
- Route filtered VP data paths through resolver filters.

Phase C: Custom and MYC safety
- Exclude rollup sentinel rows from custom type materialization.
- Apply MYC pre-sum exclusion so one resolved grain contributes.

Phase D: UX and cache
- Enforce Unit Value hide contract in aggregate contexts.
- Extend bindCache keys where resolver context changes outputs.

Phase E: Validation
- Run parse and VP smoke checks.
- Add deterministic fixture assertions.
- Record performance and residual risk notes.

## Verification and Validation Targets

- Required VP rollup schema fields exist and are populated.
- Strict path rollups produce one row per resolved display grain.
- No mixed rollup/subordinate contribution in MYC sums.
- Unit Value not selectable in aggregate rollup contexts.
- Cache invalidates when VP resolver context or custom definitions change.
- Historical Trendlines and MYC values remain deterministic.

## Bugs, Blockers, Failed Attempts, Rejected Approaches

- Recenter note after reboot (2026-07-28): this plan was moved from the Almond code-review directory into `VP Clone/Code Review`; continue using this moved file as the only source-of-truth ledger.
- User rebuild evidence (2026-07-27 console pasted on 2026-07-28): `Master_VP.R` selected VP Trade Artifact and App UI Metadata updates, rebuilt `vp_trade_monthly_pre.rds` with 2,115,868 rows, rebuilt `app_ui_metadata_pre.rds` with 217 metadata rows, reported `VP_MASTER_STATUS=PASS`, `VP_MASTER_LAUNCH_APP=TRUE`, and then app startup reported `load_vp_trade_monthly_data` currentity `current=TRUE` with 2,115,868 rows and `load_app_ui_metadata` currentity `current=TRUE` with 217 rows.
- Open launcher/window symptom (2026-07-28): after the rebuild console reached Shiny startup and render/perf logs, the user did not see either the VP launcher window or the Shiny app window. The console excerpt does not show an explicit crash or R error; investigate whether the launcher closes before app launch, browser auto-open is suppressed, app is only available at the printed localhost URL, or a post-render reactive error ended the session.
- Additional launcher clue (2026-07-28): launching without rebuilding does not show the missing-window issue. This narrows suspicion to the long rebuild path inside the hosted launcher session rather than general app startup or processed-artifact currentity.
- Launcher issue tabled (2026-07-28): user observed the launcher window disappear once during rebuild and suspects either stalled progress feedback or memory pressure. After closing/reopening to free memory, the launcher did not disappear again. Do not chase the disappearance further now; retain a dedicated progress-bar repair step because the launcher progress UI does not visibly advance while rebuild work advances in the console.
- Validation bug found after recenter (2026-07-28): focused artifact/schema check failed because mixed-volume rollup rows had `monthlyexports = NA` and `unit_value = NA` as intended, but still carried finite `ytd_exports`. Root cause was `vp_build_app_data()` replacing missing monthly volume with zero during YTD accumulation after mixed monthly rollup suppression. Fixed by blanking cumulative YTD volume from the first mixed-volume month onward within each trade/commodity/country/market-year group and bumping VP trade artifact builder/floor to `vp_trade_artifact_2026_07_28_v5` so stale v4 artifacts are not treated as current.
- Resolver/cache closure (2026-07-28): trend and heatmap plot bodies read VP data through `filtered_data()`, which routes through the shared deterministic VP resolver. Cache hardening pass added resolved VP hierarchy filters/path and `custom_country_cache_key()` to comparison and trend/heatmap plot cache keys. Focused parse and cache-key content checks passed for `04_comparison_plots.R` and `05_trend_and_heatmap.R`.
- Failed attempt: first patch attempt against `05_trend_and_heatmap.R` rejected due stale context mismatch; resolved by applying the VP resolver integration in the current helper location under `03_core_reactives_and_ui.R` and continuing with targeted anchors.
- Resolved validation blocker: `vp_shinytest_smoke.R` initially failed at `assert_vp_rollup_schema_and_potato_contract()` because on-disk `vp_trade_monthly_pre.rds` was still the older schema and lacked new rollup fields. User local rebuild subsequently produced a current 2,115,868-row, 56-column artifact with rollup fields.
- Resolved runtime blocker: VP startup was rebuilding the trade artifact because app startup expected no extra signatures while `vp_build_trade_artifact()` wrote a `builder_version` extra signature. Startup now expects `builder_version = vp_artifact_builder_version`, and user PERF logs show `load_vp_trade_monthly_data` currentity status `current` with no rebuild.
- Resolved launcher blocker: `Master_VP.R` was script-first and rebuilt data before app launch. It now follows the Almond launcher pattern with a Shiny launcher, no-update launch path, `VP_MASTER_UPDATES`, and metadata/trade update choices.
- Resolved parse blocker: a malformed edit in `server/02_partner_and_notes.R` broke `output$data_frequency_ui` around `data_frequency_inline`. The block was repaired and diagnostics are clean.
- Performance diagnosis: startup was slow primarily because `vp_trade_monthly_pre.rds` is a 2.1M-row artifact that takes about 13 seconds to read, and missing `app_ui_metadata_pre.rds` forced an additional 11-12 second runtime metadata fallback. The metadata fallback has been made cheap by compacting to distinct country rows, and a VP-local metadata builder now writes `app_ui_metadata_pre.rds` as a current processed artifact.

## Tranche Execution Notes (2026-07-27)

- Implemented pipeline contract and schema fields in `vp_data_utils.R`:
	- rollup sentinels, rollup schema version, strict path rollups, mixed volume-family context tagging.
	- startup-facing metadata includes builder floor and rollup required fields.
- Implemented startup fail-fast rollup contract checks in `app_source/global.R`:
	- builder floor resolution from manifest.
	- explicit schema/field/level checks for VP rollup artifact compatibility.
- Implemented app resolver integrations:
	- shared canonical resolver and strict hierarchy filtering in `server/02_partner_and_notes.R`.
	- commodity/type/custom panel VP filter paths moved to shared resolver in `server/01_state_and_custom_types.R` and `server/03_core_reactives_and_ui.R`.
- Implemented safety rules:
	- MYC precedence filter to prevent rollup plus subordinate contribution.
	- custom type materialization excludes `vp_is_rollup == TRUE` rows from ingredient base.
	- aggregate Unit Value and mixed-volume metric hide behavior.
- Added smoke assertions in `System/Testing/vp_shinytest_smoke.R`:
	- required rollup columns present.
	- schema version token present.
	- level coverage includes native/segment_all/subgroup_all/group_all.
	- mixed-volume rollup rows carry NA volume metrics.
	- deterministic Potato export/import rollup rows exist and do not carry finite Unit Value.
- Repaired VP launch/currentity/performance path:
	- `Master_VP.R` now mirrors Almond launcher behavior: headless no-env runs do no rebuilds; interactive launcher can run selected updates and launch the app; `VP_MASTER_UPDATES=metadata` validates as PASS.
	- `Programs/Build_App_UI_Metadata.R` added for VP and writes manifest-managed `System/Processed Data/app_ui_metadata_pre.rds` from current VP trade artifact country rows.
	- `app_source/global.R` now aligns VP trade currentity with the builder extra signature, avoids empty-notes `user` warnings, and filters unavailable `missing` country-harmonization signatures out of VP app-metadata currentity extras.
	- Metadata build validation passed: `VP_APP_UI_METADATA_BUILD_STATUS=PASS`, `APP_UI_METADATA_SOURCE_COUNT=1`, `APP_UI_METADATA_SOURCE_ENTRIES=vp_trade`.
	- Metadata currentity validation passed: `VP_APP_UI_METADATA_CURRENT=TRUE`, `VP_APP_UI_METADATA_REASON=current`.
	- The generated `VP Clone/System/Processed Data/app_ui_metadata_pre.rds` is intentionally untracked processed data, matching the repo's local artifact pattern.

## Recenter Notes (2026-07-28)

- Current artifact state from user console: VP trade artifact and app UI metadata artifact are rebuilt and current. Startup reads the processed VP trade artifact in about 10.1 seconds and total pre-UI startup is about 13.5 seconds.
- Current startup behavior from user console: app enters `vp_trade` defaults, renders the main tabs, country and commodity controls, summary table, and comparison plot. No traceback, error, or explicit session-ended line appears in the pasted output. User reports launch-without-rebuild works normally.
- Immediate next checks before more rollup code edits: inspect `Master_VP.R` long rebuild handoff behavior, confirm whether the app remains reachable at the printed localhost URL after launch, and rerun the focused VP smoke/schema validation against the rebuilt artifact.
- Mixed-volume YTD fix validation: synthetic `vp_build_app_data()` check passed after the fix, confirming mixed month YTD is `NA` and later YTD remains `NA` after a mixed-volume month while earlier clean YTD remains finite. On-disk artifact must be rebuilt with builder `v5` before the focused artifact/schema check can pass.
- Rebuilt artifact validation (2026-07-28): focused check passed with `VP_ARTIFACT_ROWS=2115868`, `VP_ARTIFACT_COLS=56`, `VP_BUILDER_VERSION=vp_trade_artifact_2026_07_28_v5`, `VP_ROLLUP_LEVELS=group_all|native|segment_all|subgroup_all`, `VP_MIXED_ROLLUP_ROWS=25518`, and `VP_METADATA_ROWS=217`. Mixed-volume rollup rows now have suppressed monthly and YTD volume on disk.

## Performance Recovery Tranche (2026-07-28)

### Goal

Reduce post-initialization runtime churn to acceptable levels. If churn cannot be dramatically reduced, reverting the rollup plan remains in scope.

### Sequencing

1. Expand runtime PERF visibility first.
2. Build and run a very lightweight perf benchmark scenario (3 baseline runs).
3. Implement a vertical slice that combines provider abstraction and partition-backed loading for one high-value VP path.
4. Rerun the lightweight scenario 3 times and compare medians before widening migration.

### Decision Gates

- No fixed runtime targets yet; initial acceptance uses relative improvement and churn reduction.
- First optimization gate is the post-vertical-slice benchmark comparison (not abstraction-only).
- Continue, narrow, or revert based on measured median improvement, repeated reactive churn counts, and memory pressure.

### Lightweight Benchmark Contract

- Scope: startup/readiness plus one VP interaction path only.
- Minimum interactions: VP source active, one trade-flow change, one all-to-specific hierarchy change, country refresh, Current vs Average render, Historical Trend render, Heatmap render.
- Run count: 3 runs before optimization and 3 runs after each major optimization tranche.
- Metrics: median/range for total scenario time, selected action timings, repeated execution counts, and memory snapshots.

### Technical Direction

- Recommended path: Option C with vertical-slice correction.
- Build provider abstraction and partitioned-loading implementation together for the first high-value path.
- Keep monolithic artifact for compatibility during migration, but require manifest integrity checks and explicit fallback behavior.

### Deferred and Non-Blocking

- Launcher disappearance remains tabled unless recurrence is observed.
- Launcher progress feedback repair remains in scope but does not block PERF diagnosis and vertical-slice lazy loading.

### Tranche Execution Notes (2026-07-28)

- Implemented runtime PERF helpers in `Programs/app_source/global.R`:
	- `perf_truthy()`, `runtime_perf_enabled()`, `runtime_perf_session_id()`, `runtime_perf_log_path()`, `runtime_perf_memory_snapshot()`, and `runtime_perf_record()`.
	- Runtime sink is gated by option/env (`vp_perf_runtime`/`VP_PERF_RUNTIME`) and supports optional file override (`vp_perf_runtime_log_file`/`VP_PERF_RUNTIME_LOG_FILE`).
	- Runtime output writes JSONL-style entries under `VP Clone/Logs/` by default and includes timestamp, event, session id, pid, cache details, and memory snapshots.
- Wired runtime sink into existing instrumentation surfaces:
	- `log_perf()` now records runtime events even when console PERF logging is disabled.
	- `record_cache_body_execution()` and `record_cache_key_delta()` now emit runtime events with execution count and changed cache fields.
- Added first-pass client/server action correlation wiring:
	- `ui.R` now tracks `action_id`, `mutation_seq`, `action_reason`, and `action_elapsed_ms` for client PERF emissions.
	- Action boundaries now start on key input changes and main-tab clicks.
	- `server/02_partner_and_notes.R` `log_client_perf()` now carries correlated action fields and emits structured runtime PERF events even when console PERF logging is disabled.
- Validation performed:
	- Quiet parse checks passed for `Programs/app_source/global.R`, `Programs/app_source/server/02_partner_and_notes.R`, and `Programs/app_source/ui.R` (`PARSE_OK_RUNTIME_PERF_SLICE`).
	- Quiet parse check passed for `System/Testing/vp_lightweight_perf_smoke.R` (`PARSE_OK_VP_LIGHTWEIGHT_PERF_SMOKE`).
- Baseline execution evidence:
	- First baseline attempt (`baseline_pre_opt_20260728`) failed 3/3 because `vp_trade_monthly_pre.rds` and `app_ui_metadata_pre.rds` were missing from `System/Processed Data` at run time.
	- Rerun after artifact restore (`baseline_pre_opt_20260728_rerun`) completed with `PASS=2`, `FAIL=1` and emitted:
		- `VP Clone/Logs/vp_lightweight_perf_raw_baseline_pre_opt_20260728_rerun_20260728T143747Z.csv`
		- `VP Clone/Logs/vp_lightweight_perf_summary_baseline_pre_opt_20260728_rerun_20260728T143747Z.csv`
	- Run 3 failure mode: shinytest2 startup stability timeout (`Shiny app did not become stable in 120000ms`) while app remained in busy/idle churn during initialization.
- Vertical-slice implementation evidence:
	- Added provider abstraction and partition-backed hierarchy slice loader in `Programs/app_source/global.R`:
		- `vp_partition_provider_enabled()`, `vp_partition_get_hierarchy_slice()`, and `vp_partition_provider_filter_rows()`.
		- Disk-backed partition cache path: `System/Processed Data/vp_trade_partitions/vp_trade_partition_provider_v1/<builder_version>/`.
		- Session memory cache (`vp_partition_cache_env`) plus on-disk reuse.
		- Toggle controls: option `vp_partition_provider_enabled` and env `VP_PARTITION_PROVIDER_ENABLED`.
	- Routed VP hierarchy filtering through provider in `Programs/app_source/server/02_partner_and_notes.R` `filter_vp_rows_for_resolved_hierarchy()` with safe fallback to direct filtering if provider errors.
	- Quiet parse check passed for modified files (`PARSE_OK_VP_PARTITION_PROVIDER_SLICE`).
- Post-slice execution evidence:
	- Post-slice benchmark run label `post_slice_20260728` completed with `PASS=2`, `FAIL=1` and emitted:
		- `VP Clone/Logs/vp_lightweight_perf_raw_post_slice_20260728_20260728T150157Z.csv`
		- `VP Clone/Logs/vp_lightweight_perf_summary_post_slice_20260728_20260728T150157Z.csv`
	- Run 3 failure mode: `Missing expected controls: country_choice` during startup control presence gate.
- Partition manifest/fallback hardening evidence:
	- Added manifest helpers in `Programs/app_source/global.R`:
		- `vp_partition_manifest_path()`, `vp_partition_manifest_base()`, `vp_partition_manifest_compatible()`, `vp_partition_read_manifest()`, and `vp_partition_write_manifest()`.
		- Manifest stores schema version, provider version, VP builder version, source artifact basename, source artifact signature, timestamps, and per-slice entries.
		- Per-slice entries store file name, file size, row count, column count, trade flow, resolved hierarchy filters, and materialization time.
	- Provider now uses disk cache only when top-level manifest metadata and per-slice metadata match current runtime context.
	- Missing, stale, incompatible, unreadable, or row/column-mismatched partition files fall back to direct materialization and rewrite the partition/manifest when possible.
	- Runtime PERF event `vp_partition_provider_slice()` now reports `mode`, `fallback_reason`, `manifest_reason`, row count, and partition file name.
	- Validation passed:
		- Quiet parse check: `PARSE_OK_VP_PARTITION_MANIFEST_SLICE`.
		- Focused provider probe: `VP_PARTITION_MANIFEST_PROBE_PASS`, covering manifest write, disk-cache reuse, and corrupt-partition fallback on a tiny VP-shaped data frame.
- Startup default polish evidence:
	- Initial attempt only changed central fallback defaults, but user launch logs showed stale Shiny inputs still initialized VP to `monthlyvalue` / Monthly Value and `us_tons` / US Tons.
	- Root cause: `monthlyvalue` is a valid VP metric and the mixed-volume aggregate guard filtered out `ytd_exports`, so `observe(metric_choice reconcile)` preserved the stale value metric. Separately, the unit observer stamped the stale initial unit as a valid non-PSD unit before VP source-entry defaults could replace it.
	- Added one-shot VP source-entry defaults for metric and unit, consumed by the existing reconcile observers.
	- Allowed `ytd_exports` to remain available during the VP source-entry default handoff, while keeping normal mixed-volume metric hiding for non-default contexts.
	- Changed `default_unit_choice_for_context()` non-special-source fallback and `current_unit_choice_safe()` direct fallback from `us_tons` to `lbs`.
	- Validation passed:
		- `PARSE_OK_VP_STARTUP_DEFAULTS_AND_PARTITION_FILENAME`.
		- `VP_STARTUP_DEFAULTS_PROBE_PASS` with `data_source_choice=vp_trade`, `metric_choice=ytd_exports`, and `unit_choice=lbs`.
- Partition filename follow-up from user startup log:
	- User log showed `partition_save_error` and a Windows `gzfile` warning for a long partition path containing every hierarchy token.
	- Shortened physical partition filenames to `slice__<hash>.rds`; readable hierarchy keys remain in the partition manifest.
	- Validation passed: `VP_PARTITION_SHORT_FILENAME_PROBE_PASS` with sample file `slice__7c862b415f1ff6ff.rds`.
- Gate decision (Step 16):
	- Continue with optimization path (do not revert) based on strong median improvement in PASS runs.
	- Narrow immediate next work to Step 15 partition manifest/integrity plus benchmark stability hardening so 3/3 post-slice runs are deterministic.
- Remaining work for this tranche segment:
	- Stabilize lightweight benchmark startup/control gate to eliminate intermittent `country_choice` control-missing failures.
	- Re-run a small post-hardening validation or benchmark probe after startup gate cleanup.

### Lightweight Benchmark Script Notes (2026-07-28)

- New script: `VP Clone/System/Testing/vp_lightweight_perf_smoke.R`.
- Purpose: lightweight performance smoke and median timing capture without the heavyweight end-to-end smoke path.
- Scenario coverage:
	- startup/readiness idle gate,
	- VP source activation,
	- trade-flow change,
	- all-to-specific hierarchy transition,
	- country choice refresh,
	- Current vs Average render,
	- Historical Trend render,
	- Heatmap render.
- Output artifacts:
	- raw run-level timings CSV under `VP Clone/Logs/`.
	- summary CSV with median/min/max metrics under `VP Clone/Logs/`.
	- status lines in terminal for pass/fail and output file paths.
- Runtime PERF compatibility:
	- supports `--runtime-perf=true|false` and defaults to enabling runtime PERF logging for benchmark runs.

### Baseline Lightweight Perf Results (2026-07-28)

- Benchmark label: `baseline_pre_opt_20260728_rerun`.
- Outcome: 3 runs attempted, 2 PASS, 1 FAIL (startup stability timeout).
- Metric medians/ranges from PASS runs (`run_count=2`):
	- `startup_ready_ms`: median 108004 ms, range 103859-112149 ms.
	- `source_switch_ms`: median 531 ms, range 522-540 ms.
	- `trade_flow_ms`: median 51414.5 ms, range 41648-61181 ms.
	- `hierarchy_change_ms`: median 213855.5 ms, range 152178-275533 ms.
	- `country_refresh_ms`: median 26111.5 ms, range 20197-32026 ms.
	- `current_vs_average_ms`: median 533.5 ms, range 521-546 ms.
	- `historical_trend_ms`: median 24341 ms, range 20618-28064 ms.
	- `heatmap_ms`: median 23999 ms, range 19516-28482 ms.
	- `total_scenario_ms`: median 523453 ms, range 418053-628853 ms.
- Resolved-path sanity:
	- PASS runs resolved to `Group=Dry pulses`, `Subgroup=Dried beans`, `MarketSegment=Dried`, and `resolved_path_ok=TRUE`.

### Post-Slice Lightweight Perf Results (2026-07-28)

- Benchmark label: `post_slice_20260728`.
- Outcome: 3 runs attempted, 2 PASS, 1 FAIL (`Missing expected controls: country_choice`).
- Metric medians/ranges from PASS runs (`run_count=2`):
	- `startup_ready_ms`: median 74666 ms, range 74231-75101 ms.
	- `source_switch_ms`: median 543.5 ms, range 543-544 ms.
	- `trade_flow_ms`: median 30880.5 ms, range 28821-32940 ms.
	- `hierarchy_change_ms`: median 139158 ms, range 127646-150670 ms.
	- `country_refresh_ms`: median 16907 ms, range 16607-17207 ms.
	- `current_vs_average_ms`: median 557 ms, range 556-558 ms.
	- `historical_trend_ms`: median 22796 ms, range 21904-23688 ms.
	- `heatmap_ms`: median 21531 ms, range 20704-22358 ms.
	- `total_scenario_ms`: median 396888.5 ms, range 374905-418872 ms.
- Baseline vs post-slice median deltas (PASS-run medians):
	- `total_scenario_ms`: 523453 -> 396888.5 (about 24.2% faster).
	- `startup_ready_ms`: 108004 -> 74666 (about 30.9% faster).
	- `trade_flow_ms`: 51414.5 -> 30880.5 (about 39.9% faster).
	- `hierarchy_change_ms`: 213855.5 -> 139158 (about 34.9% faster).
	- `country_refresh_ms`: 26111.5 -> 16907 (about 35.2% faster).
	- `historical_trend_ms`: 24341 -> 22796 (about 6.3% faster).
	- `heatmap_ms`: 23999 -> 21531 (about 10.3% faster).
	- `source_switch_ms`: 531 -> 543.5 (slower by 12.5 ms, about 2.4%).
	- `current_vs_average_ms`: 533.5 -> 557 (slower by 23.5 ms, about 4.4%).
- Gate result:
	- Improvement is large enough to proceed; keep provider/partition slice and move to manifest/integrity hardening (Step 15) before broader expansion.

## Open Questions and Deferred Decisions

- CommodityName-wide all rollups remain deferred to future tranche with explicit UI path.

## Summary

Pending. This section will be completed at closeout with plain-language scope, outcomes, and major blocker/bug work.
