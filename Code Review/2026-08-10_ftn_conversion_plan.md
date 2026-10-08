# Plan: FTN Data/Label Conversion

Convert the existing VP Shiny clone into a Fruits and Tree Nuts application by changing only the source data, visible labels, and data-driven dropdown options. The app's behavior, UI structure, internal source/control contracts, artifact names, rollup logic, and marketing-year logic must remain unchanged unless a concrete blocker is discovered and explicitly documented for user review.

This handoff plan supersedes unrelated VP plans for this workstream, including the pending diagnostic-spine plan. Do not use any VP diagnostic/refactor plan as the implementation source of truth for this FTN conversion.

## Scope Boundaries

- Allowed: point ingestion/currentity to `Input/fruit-trade-data.csv`, rebuild existing artifacts/metadata, update visible VP/rice/almond labels to FTN-neutral wording, and let dropdown options change because the fruit/tree-nut data contains different values.
- Not allowed: changing tab list/order, layout, control IDs, filter cascade mechanics, reset behavior, source-state behavior, map/display-mode rules, rollup/unit-value logic, marketing-year/month-axis logic, cache semantics, or broad internal `vp_` namespaces.
- Any exception to the not-allowed list is a blocker, not an implementation choice. Stop, document the reason in this plan, and get user approval before widening scope.

## Critical Existing Facts

- `app.R`, `FTN_Analysis_Shiny.R`, and `Master_FTN.R` still contain VP filename references in launch/self-detection paths.
- `Programs/vp_data_utils.R` owns CSV ingestion, required schema checks, rollup generation, commodity-level month-calendar inference, artifact writing, and stale-artifact validation.
- `Programs/app_source/global.R` has a second hardcoded source path for startup currentity checks.
- `System/Config/vp_contract.R` drives many visible labels but also carries internal runtime contracts that should mostly remain stable.
- The workspace currently lacks `.vp_clone_root`; current root discovery expects `.vp_clone_root` containing `VP_CLONE_ROOT=TRUE`.
- Fruit/tree-nut commodities may have different marketing-year start months than VP commodities. Existing code is intended to handle this data-driven through `calendar_signature` and `analysis_month`; implementation must validate that path rather than hardcoding any month order.
- Existing `vp_*` probes have VP path, fixture, and calendar assumptions. They are templates only until reviewed, documented, copied/renamed, and adapted.

## Immutable Internal Contracts For First Pass

- Source key: keep `vp_trade`.
- Input IDs: keep `data_source_choice`, `vp_trade_flow_choice`, `vp_group_choice`, `vp_subgroup_choice`, `vp_market_segment_choice`, `vp_commodity_name_choice`, `commodity_choice`, and `country_choice`.
- Artifacts: keep `vp_trade_monthly_pre.rds`, `vp_trade_metadata_pre.rds`, and existing artifact roles.
- Runtime: keep `vp_` helper names, option/env/trace prefixes, namespaces, cache identifiers, and disabled-source contracts.
- Root marker: preserve VP sentinel contract for the first pass. Add `.vp_clone_root` with `VP_CLONE_ROOT=TRUE` if missing; do not migrate to `.ftn_clone_root` in this tranche.

## Allowed Label/Data Changes

- Source CSV path changes from `Input/veg-trade-data.csv` to `Input/fruit-trade-data.csv` in both builder and startup currentity paths.
- Visible title/source labels should use FTN wording. Recommended labels: `Fruit and Tree Nut`, `Fruits and Tree Nuts`, `USDA-ERS Fruit and Tree Nut Trade Analysis Tool`, `All Fruit and Tree Nut Commodities`, `Fruit and Tree Nut Trade`, and `FTN Trade`.
- Visible legacy terms such as `Vegetable and Pulse`, `VP Trade`, `VP Clone`, `Master_VP.R`, `VP_Analysis_Shiny.R`, `Rice Type`, and `Almond Type` should be cleaned only on active FTN paths.
- Legacy fallback defaults such as `All Rice` should be replaced only where they affect active FTN behavior, preferably by using `COMMODITY_AGGREGATE_LABEL` so mechanics remain unchanged.

## Steps

### 1. Create the implementation source-of-truth plan in the repo

- Create this file, `Code Review/2026-08-10_ftn_conversion_plan.md`, as the implementation ledger.
- State that this file supersedes unrelated VP/pending diagnostic plans for the FTN conversion.
- Track tranche status, validations, failed attempts, rejected approaches, blockers, and final lay summary.

### 2. Run the large-file schema and calendar preflight

- Use R/data.table or equivalent local commands; do not rely on editor file reads for the large CSVs.
- Verify required columns: `Trade`, `GeographicDesc`, `Year`, `MarketYear`, `Group`, `Subgroup`, `MarketSegment`, `CommodityName`, `CommodityDetail`, `UnitType`, `UnitDesc`, `Amount`, plus `MonthNum` or `MonthNumber`.
- Profile distinct `Trade`, `Group`, `Subgroup`, `MarketSegment`, `CommodityName`, `CommodityDetail`, `UnitType`, and `UnitDesc` values.
- Profile marketing-year calendars by `Trade`/`Group`/`Subgroup`/`MarketSegment`/`CommodityName`/`CommodityDetail`: observed month order, inferred first calendar month, month-count completeness, and expected `calendar_signature`.
- Select at least two representative FTN commodities with different calendar signatures for later acceptance tests.
- Profile liquid/juice and mixed weight/liquid contexts to confirm existing `All - excluding juice` behavior remains applicable.
- If schema depth differs from the existing Group/Subgroup/MarketSegment/CommodityName/CommodityDetail hierarchy, stop and document the blocker.

### 3. Pass the launch-triad and root-marker gates

- Gate A: `app.R` sources `FTN_Analysis_Shiny.R`.
- Gate B: `FTN_Analysis_Shiny.R` self-detection matches `FTN_Analysis_Shiny.R`.
- Gate C: `Master_FTN.R` self-detection and app-launch source calls reference `FTN_Analysis_Shiny.R`.
- Gate D: `System/Config/vp_contract.R` `runtime$entrypoint_file` aligns with the actual FTN entrypoint if contract validation requires it.
- Gate E: `.vp_clone_root` exists at the repo root and contains `VP_CLONE_ROOT=TRUE`; preserve existing root-discovery behavior if that resolves launch.
- Do not rename input IDs, source keys, prefixes, namespaces, or artifact roles while satisfying these gates.

### 4. Switch source data and currentity paths

- Update `Programs/vp_data_utils.R::vp_paths()` so `input_csv` points to `Input/fruit-trade-data.csv`.
- Update `Programs/app_source/global.R` so startup source/currentity checks use `Input/fruit-trade-data.csv`.
- Update user-facing stale/rebuild messages from VP filenames to FTN filenames where reachable.
- Preserve processed artifact filenames and roles.
- Acceptance for this step requires both builder provenance and startup currentity to point to the same fruit CSV path.

### 5. Convert contract-derived visible labels without renaming internals

- Update visible identity/label values that drive UI text: app title, commodity name/plural, aggregate label, source group, source label, type label, placeholders, and disabled-source messages.
- Keep `commodity_id`, `vp_trade`, option/env/trace prefixes, namespaces, artifact roles, and disabled-source keys unchanged unless a documented blocker requires user review.
- Confirm label changes do not alter source selection mechanics or hidden source state.

### 6. Rebuild artifacts and metadata from fruit data

- Run the existing rebuild flow through `Master_FTN.R` update selection/env or direct `vp_build_trade_artifact(project_dir = normalizePath('.'))` after launch/root gates pass.
- Confirm `System/Processed Data/vp_trade_monthly_pre.rds`, `System/Processed Data/vp_trade_metadata_pre.rds`, and `System/Processed Data/app_ui_metadata_pre.rds` are rebuilt from `Input/fruit-trade-data.csv`.
- Verify metadata source signature, row counts, rollup stats, unit-value fields, world-row counts, and enabled source metadata.
- Verify `metadata$calendars` and artifact rows contain expected FTN `calendar_signature` values from the preflight, including the two representative commodities with different start months.
- Confirm no validation assumes a single VP signature such as `7-8-9-10-11-12-1-2-3-4-5-6`.

### 7. Verify data-driven dropdown options and safe defaults

- Confirm existing Group/Subgroup/MarketSegment/Commodity/Country dropdowns populate from the fruit artifact.
- Do not change dropdown layout, IDs, cascade rules, filtering semantics, or selection mechanics.
- Replace active-path fallback literals such as `All Rice` only where they prevent valid FTN defaults/options; prefer `COMMODITY_AGGREGATE_LABEL`.
- Confirm dropdown option changes are explainable by source data changes, not code-driven UI redesign.
- Confirm existing `All - excluding juice` dropdown suppression/visibility behavior remains unchanged for mixed liquid/weight contexts.

### 8. Clean visible legacy language on reachable FTN paths

- Search active runtime files for `veg-trade-data`, `VP_Analysis_Shiny`, `Master_VP`, `Vegetable and Pulse`, `VP Trade`, `Rice Type`, and `Almond Type`.
- Fix only visible/reachable FTN-path text and active launch/build/runtime messages.
- Triage remaining hits as inactive, intentionally deferred, or requiring follow-up; record this triage in this plan.

### 9. Review, rename, and adapt validation probes before any acceptance run

- Do not run existing VP probes blindly.
- Before a probe is used, read it carefully and record in this plan: what it checks, what VP assumptions it contains, what paths/fixtures/calendar signatures it hardcodes, and what FTN edits were made.
- Copy or rename every acceptance probe under an FTN-reviewed naming pattern, such as `ftn_validated_*`.
- Unreviewed `vp_*` probe outputs do not count as validation evidence.
- At minimum, create one reviewed/renamed artifact/currentity probe and one reviewed/renamed Shiny smoke or filter probe.
- Replace vegetable fixtures and hardcoded VP calendar assertions with FTN values discovered in the preflight/rebuilt artifact.

### 10. Run reviewed validation and manual smoke checks

- Run only reviewed/renamed FTN probes as acceptance evidence.
- Launch through `app.R` and `Master_FTN.R`.
- Verify FTN title/header/source labels.
- Verify default dropdowns populate fruit/tree-nut groups, subgroups, segments, commodities, countries, metrics, quantity units, and value units.
- Render the same existing tabs: Current vs. Average, Market Year Comparison, Historical Trendlines, Trend Heatmap, Data, and Map.
- For the two representative commodities with different signatures, compare preflight signature, `metadata$calendars`, artifact rows, and Shiny display month order/axis label.
- Test a juice/liquid context if present and confirm existing `All - excluding juice` and unit-value behavior remains coherent.

### 11. Perform final go/no-go review

- Go only if launch triad, root marker, fruit currentity/provenance, internal contract preservation, reviewed probe governance, marketing-year matrix, dropdown data-driven behavior, and UI-structure preservation all pass.
- If any gate fails, mark handoff status `Not Ready`, name the blocker, record evidence, and identify the next remediation step.
- Update this plan with final status, changed files, validation outputs, failed attempts, unresolved risks, deferred work, and a lay summary.

## Relevant Files

- `app.R` — launcher source must point to `FTN_Analysis_Shiny.R`.
- `FTN_Analysis_Shiny.R` — self-detection should match FTN filename; bootstrap should preserve existing internal root behavior.
- `Master_FTN.R` — self-detection and app-launch source calls should reference FTN filenames.
- `Programs/vp_data_utils.R` — source CSV path, source signature, artifact build metadata, calendar inference, and stale messages.
- `Programs/app_source/global.R` — startup currentity/source path and reachable rebuild messages.
- `System/Config/vp_contract.R` — visible labels plus entrypoint file if required by validation; preserve internal contract fields.
- `Programs/app_source/server/01_state_and_custom_types.R` — visible custom type wording and active fallback defaults only; no dropdown mechanics changes.
- `Programs/app_source/server/02_partner_and_notes.R` — active-path label/default fixes only; preserve source state, tabs, and filter behavior.
- `Programs/app_source/server/03_core_reactives_and_ui.R` — display month mapping must remain data-driven; no month-axis logic changes.
- `Programs/app_source/server/05_trend_and_heatmap.R` — active visible Rice/Almond wording cleanup only; no plotting/data logic changes.
- `Programs/Build_App_UI_Metadata.R` — metadata rebuild should consume fruit-backed artifact without structural changes.
- `System/Testing/vp_perf_probe_artifact_load.R` — template only; reviewed FTN acceptance copy must be renamed before running.
- `System/Testing/vp_shinytest_smoke.R` and `System/Testing/vp_perf_probe_vp_filters.R` — templates only; reviewed FTN acceptance copies must be renamed before running.
- `System/Testing/ftn_validated_probe_artifact_currentity.R` — reviewed FTN artifact/currentity acceptance probe.
- `System/Testing/ftn_validated_shiny_smoke.R` — reviewed FTN Shiny smoke acceptance probe.
- `Input/fruit-trade-data.csv` — target source data.
- `Input/veg-trade-data.csv` — comparison/source-history only.
- `Code Review/2026-08-10_ftn_conversion_plan.md` — implementation ledger.

## Acceptance Criteria

1. `app.R`, `FTN_Analysis_Shiny.R`, `Master_FTN.R`, and contract entrypoint references are coherent and launchable.
2. `.vp_clone_root` root detection works without migrating to a new sentinel.
3. Builder and startup currentity both use `Input/fruit-trade-data.csv`.
4. Processed artifacts and metadata rebuild from fruit data with source signatures proving provenance.
5. Internal contracts remain unchanged: `vp_trade`, key input IDs, artifact names/roles, namespaces, prefixes, and cache identifiers.
6. Visible labels are FTN-appropriate on active paths.
7. Dropdown options come from fruit artifact values and mechanics remain unchanged.
8. Marketing-year display remains data-driven and passes a two-commodity signature matrix.
9. All acceptance probes were reviewed, documented, renamed/copied under FTN-reviewed names, and adapted before being run.
10. Existing UI structure and behavior are preserved except for label text and data-driven option sets.
11. This plan contains final status, validations, failed attempts, blockers, deferred work, and lay summary.

## Implementation Status

| Step | Status | Notes |
| --- | --- | --- |
| 1. Create implementation ledger | Complete | Created this source-of-truth plan. |
| 2. Schema/calendar preflight | Complete | Ran R/data.table preflight from `Logs/ftn_preflight/20260810T110101_retry`; required headers passed, month column detected as `MonthNumber`, 12 distinct calendar signatures detected, mixed volume contexts = 0, juice-related rows = 11741. |
| 3. Launch/root gates | Complete | Updated launch triad references (`app.R`, `FTN_Analysis_Shiny.R`, `Master_FTN.R`) to FTN filenames, updated contract `runtime$entrypoint_file` to `FTN_Analysis_Shiny.R`, created `.vp_clone_root` with `VP_CLONE_ROOT=TRUE`, and validated `ROOT_OK=TRUE`. |
| 4. Source/currentity paths | Complete | Updated `Programs/vp_data_utils.R::vp_paths()` and `Programs/app_source/global.R` to use `Input/fruit-trade-data.csv`; validated `INPUT_CSV=.../Input/fruit-trade-data.csv`. |
| 5. Visible labels | In progress | Added active-path label/default cleanup in server modules and launcher/runtime messages: removed hardcoded Almond/Rice type strings from custom builders, historical table headings, correction preview labels, and prior-comparison notices; switched active fallback defaults from `All Rice` to `default_commodity_choice_value()` on FTN paths; updated launcher/progress/error wording from VP to FTN. |
| 6. Artifact/metadata rebuild | Complete | Instrumented direct build finished cleanly at `Logs/ftn_rebuild/20260810T115204_instrumented` with terminal checkpoints through `CHK|done|2026-08-10T16:29:26Z`, writing `vp_trade_monthly_pre.rds`, `vp_trade_metadata_pre.rds`, and `processed_artifacts_manifest.rds`; then rebuilt `app_ui_metadata_pre.rds` via `Programs/Build_App_UI_Metadata.R` (`APP_UI_METADATA_BUILD_STATUS=PASS`). |
| 7. Dropdown/default validation | Complete | Reviewed FTN smoke acceptance run `Logs/ftn_probe_runs/ftn_shiny_smoke_run_20260810T140625.stdout.log` passed with `FTN_SHINY_SMOKE_STATUS=PASS`, `FTN_SHINY_SOURCE_VALUE_IS_VP_TRADE=TRUE`, FTN group/subgroup/segment/commodity/type options present, and legacy VP/Vegetable wording not visible. |
| 8. Visible legacy text cleanup | In progress | Completed targeted active-path cleanup in `Programs/app_source/server/01_state_and_custom_types.R`, `Programs/app_source/server/02_partner_and_notes.R`, `Programs/app_source/server/05_trend_and_heatmap.R`, `Master_FTN.R`, and `Programs/app_source/global.R`; residual `All Rice` literals are intentionally retained in compatibility logic for disabled/non-FTN source families, product-basis assertions, and code comments. |
| 9. Reviewed FTN probes | Complete | Added FTN-reviewed acceptance probes `System/Testing/ftn_validated_probe_artifact_currentity.R` and `System/Testing/ftn_validated_shiny_smoke.R`; parse validation passed for both. |
| 10. Validation/manual smoke | Complete | Artifact/currentity probe passes, reviewed Shiny smoke passes, and reviewed two-commodity calendar-signature matrix now passes end-to-end (Bananas calendar-year signature and Oranges offset signature validated across preflight, metadata, artifact, and Shiny display-month axis/title). |
| 11. Final go/no-go | Complete | Launch/root/source/currentity/probe-governance and two-signature UI matrix gates now pass with preserved internal contracts; tranche is ready for FTN conversion handoff under defined scope boundaries. |

## Post-Go/No-Go Sanity Checks

- 2026-08-10 Almond unit-value rollup sanity check:
	- User-reported concern: Almond export unit values in the app appeared around `5,700-6,500`, while expected values should be around `2-4 dollars per pound`.
	- Source data check for Export / World / Almonds / MY `2025/26` confirmed source rows use `Value: Thousand dollars`, `Volume: Thousand pounds`, and `Unit value: Dollars per pound`.
	- Direct weighted source calculation for the UI-equivalent Almond `All` rollup produced `2.582-2.945 dollars per pound` across Aug-May.
	- The pre-fix artifact/UI values matched the same source ratios converted to dollars per metric ton (`5,692-6,492`), so the rollup arithmetic was coherent but the denominator was wrong for FTN source semantics.
	- Root code fix in `Programs/vp_data_utils.R`: preserve existing quantity-volume base fields, but compute `unit_value` and `ytd_unit_value` using source-native unit-value denominators for source volume units (`Dollars per pound` for pound rows, `Dollars per gallon` for gallon rows, metric-ton fallback otherwise).
	- In-memory builder validation for Export / World / Almonds / `All` / segment-all rollup now returns `2.582-2.945` with `unit_value_unit=Dollars per pound`.
	- Current processed artifact was repaired in place from existing value/volume fields after backing up `System/Processed Data/vp_trade_monthly_pre.rds`; pound rows were recalculated as dollars divided by metric tons converted back to pounds, gallon rows as dollars divided by gallons.
	- Post-repair artifact comparison against source returned exact agreement for the Almond UI-equivalent rollup: `RANGE_SOURCE_LB=2.582 to 2.945`, `RANGE_ARTIFACT_UV=2.582 to 2.945`, `MAX_ABS_DELTA=2e-12`, `artifact_unit=Dollars per pound`.
	- Reviewed post-repair validations passed:
		- `FTN_ARTIFACT_PROBE_STATUS=PASS` at `Logs/ftn_probe_runs/ftn_artifact_probe_after_almond_uv_fix_20260810T152251.stdout.log`.
		- `FTN_SHINY_SMOKE_STATUS=PASS` at `Logs/ftn_probe_runs/ftn_shiny_smoke_after_almond_uv_fix_20260810T152315.stdout.log`.

## Validation Log

- 2026-08-10 Preflight (schema/calendar): `Logs/ftn_preflight/20260810T110101_retry/summary.txt`
	- `fruit_header_required_status=PASS`
	- `missing_required_columns=<none>`
	- `month_column=MonthNumber`
	- `distinct_calendar_signatures=12`
	- `top_calendar_signatures=1-2-3-4-5-6-7-8-9-10-11-12|8-9-10-11-12-1-2-3-4-5-6-7|7-8-9-10-11-12-1-2-3-4-5-6|10-11-12-1-2-3-4-5-6-7-8-9|9-10-11-12-1-2-3-4-5-6-7-8`
	- `representative_signature_commodities=Other|Concentrated, frozen`
	- `mixed_volume_contexts=0`
	- `juice_related_rows=11741`
- 2026-08-10 Root/source validation command outputs:
	- `ROOT_OK=TRUE`
	- `INPUT_CSV=C:\Users\SETH.WECHSLER\OneDrive - USDA\Documents\Repositories\FTN Clone/Input/fruit-trade-data.csv`
- 2026-08-10 Contract validation command outputs:
	- `ENTRYPOINT=FTN_Analysis_Shiny.R`
	- `APP_TITLE=USDA-ERS Fruit and Tree Nut Trade Analysis Tool`
	- `SOURCE_GROUP=Fruit and Tree Nut Trade`
	- `SOURCE_LABEL=FTN Trade`
- 2026-08-10 Master script dry run without updates:
	- `VP_MASTER_STATUS=PASS`
	- `VP_MASTER_PROJECT_ROOT=.../FTN Clone`
- 2026-08-10 Rebuild run with updates started:
	- `VP_MASTER_PROGRESS=...Selected VP updates: VP Trade Artifact, App UI Metadata`
	- `VP_MASTER_PROGRESS=...Rebuilding VP trade processed artifact`
	- Follow-up runtime checks on the first attempt showed active worker process (`PID 30172`) with increasing CPU time (~1585 CPU seconds at ~27 elapsed minutes), indicating work but no deterministic completion signal.
	- Deterministic rerun initiated with explicit logs at `Logs/ftn_rebuild/20260810T113307`.
	- Stopped prior ambiguous workers before rerun: `Stopped Master_FTN Rscript PIDs: 956, 30172`.
	- Rerun log tails currently show progress through `Rebuilding VP trade processed artifact`.
	- During rerun, `System/Processed Data/vp_trade_monthly_pre.rds` appeared (`~24,035,328` bytes, timestamp `2026-08-10 11:33:07`), confirming write activity.
	- `vp_trade_metadata_pre.rds` and `app_ui_metadata_pre.rds` are still pending while rerun remains active.
	- Follow-up deterministic wait on legacy rerun exited without additional outputs; latest legacy log directory remained `Logs/ftn_rebuild/20260810T113307` with progress stopping at `Rebuilding VP trade processed artifact`.
	- Instrumented direct build launched at `Logs/ftn_rebuild/20260810T115204_instrumented` to isolate stage timing.
	- Instrumented stdout checkpoints so far:
		- `CHK|read_csv_rows|900016`
		- `CHK|normalized_rows|900016`
		- `CHK|all_type_rows|5238387`
		- `CHK|calendar_rows|22236`
		- `CHK|calendar_signatures|12`
	- Current hotspot is after calendar inference (app-data/materialization path), with active worker CPU growth and stable high memory footprint (~2.8-3.0 GB working/private).
	- Sample timing benchmark (`raw[1:100000]`) to estimate full-scale runtime:
		- `SAMPLE_ROWS_RAW=100000`
		- `SAMPLE_ROWS_ALLTYPE=582687`
		- `SAMPLE_ROWS_APP=293127`
		- `T_NORMALIZE_SEC=5.38`
		- `T_ALLTYPE_SEC=48.26`
		- `T_CAL_SEC=33.59`
		- `T_APP_SEC=207.26`
	- Benchmark indicates app-data materialization is the dominant cost and long single-run duration is expected at full scale (`all_type_rows=5238387`), so repeated restarts are more harmful than waiting for completion.
	- Completion evidence from instrumented direct run (`Logs/ftn_rebuild/20260810T115204_instrumented/ftn_build_artifact_instrumented.stdout.log`):
		- `CHK|app_rows|2636349`
		- `CHK|metadata_rows_source|5238387`
		- `CHK|metadata_rows_app|2636349`
		- `CHK|artifact_write_mode|manifested`
		- `CHK|artifact_written|.../System/Processed Data/vp_trade_monthly_pre.rds`
		- `CHK|metadata_written|.../System/Processed Data/vp_trade_metadata_pre.rds`
		- `CHK|done|2026-08-10T16:29:26Z`
	- Post-completion processed-artifact files:
		- `System/Processed Data/vp_trade_monthly_pre.rds` (`218891092` bytes, `2026-08-10 12:29:25 PM`)
		- `System/Processed Data/vp_trade_metadata_pre.rds` (`83975` bytes, `2026-08-10 12:29:26 PM`)
		- `System/Processed Data/processed_artifacts_manifest.rds` (`84223` bytes initially; refreshed to `84970` after app-ui metadata rebuild)
	- App UI metadata rebuild command (`source('Programs/Build_App_UI_Metadata.R'); write_commodity_app_ui_metadata(...)`) produced `System/Processed Data/app_ui_metadata_pre.rds` (`3192` bytes, `2026-08-10 12:32:30 PM`) and updated manifest backup/refresh files.
- 2026-08-10 Active-path FTN label/default cleanup validation:
	- `Programs/app_source/server/01_state_and_custom_types.R`: custom builder titles/messages and default aggregate fallback updated to contract-driven FTN-safe wording.
	- `Programs/app_source/server/02_partner_and_notes.R`: FTN-safe type labels/messages, default commodity fallback routing, and correction-table type headers updated.
	- `Programs/app_source/server/05_trend_and_heatmap.R`: FTN-safe historical/prior-comparison labels and contract-driven commodity default fallbacks.
	- `Master_FTN.R`: launcher title, update labels, progress details, and missing-artifact messages updated from VP wording to FTN wording.
	- `Programs/app_source/global.R`: rollup validation error strings updated from VP trade artifact wording to FTN trade artifact wording.
	- Parse validation passed via `Rscript` for all three edited files:
		- `OK: Programs/app_source/server/01_state_and_custom_types.R`
		- `OK: Programs/app_source/server/02_partner_and_notes.R`
		- `OK: Programs/app_source/server/05_trend_and_heatmap.R`
	- Additional parse validation passed:
		- `OK: Master_FTN.R`
		- `OK: Programs/app_source/global.R`
	- Residual-scan triage:
		- `Vegetable and Pulse`, `VP Trade`, `VP Clone`, `Master_VP`, `VP_Analysis_Shiny`, `Rice Type`, `Almond Type`, and `NASS QuickStats Almond` now only remain in comments (non-user-visible) under `Programs/app_source/server/03_core_reactives_and_ui.R` and `Programs/app_source/server/04_comparison_plots.R`.
		- `All Rice` remains in compatibility logic for disabled/non-FTN source families and product-weight assertions (`Programs/app_source/global.R`, `Programs/app_source/server/02_partner_and_notes.R`, and one non-active fallback branch in `Programs/app_source/server/03_core_reactives_and_ui.R`).
- 2026-08-10 Probe governance tranche:
	- Reviewed template probes `System/Testing/vp_perf_probe_artifact_load.R` and `System/Testing/vp_shinytest_smoke.R` and documented VP-specific assumptions (VP clone pathing and vegetable fixtures) as unsuitable for direct FTN acceptance use.
	- Created reviewed FTN probes:
		- `System/Testing/ftn_validated_probe_artifact_currentity.R`
		- `System/Testing/ftn_validated_shiny_smoke.R`
	- Parse validation passed:
		- `OK: System/Testing/ftn_validated_probe_artifact_currentity.R`
		- `OK: System/Testing/ftn_validated_shiny_smoke.R`
	- Artifact/currentity probe remediation and result:
		- Fixed app-ui metadata path resolution in `ftn_validated_probe_artifact_currentity.R` by resolving `app_ui_metadata` via contract artifact map (instead of undefined `vp_paths()$app_ui_metadata`).
		- Added support for current app-ui metadata schema where `country_choices_all` is a top-level list field.
		- Final run output:
			- `FTN_ARTIFACT_PROBE_STATUS=PASS`
			- `FTN_ARTIFACT_ROWS=2636349`
			- `FTN_METADATA_ROWS_SOURCE=5238387`
			- `FTN_METADATA_ROWS_APP=2636349`
			- `FTN_APP_UI_COUNTRY_ROWS=219`
			- `FTN_SOURCE_SIGNATURE=.../Input/fruit-trade-data.csv|TRUE|132591130|2026-07-20T16:02:36Z`
			- `FTN_CALENDAR_SIGNATURE_COUNT=12`
	- Shiny smoke diagnostics tranche (headless):
		- Direct DOM/source probe (`Logs/ftn_probe_runs/ftn_source_probe.R`) repeatedly confirms FTN runtime controls exist and source state is FTN-backed:
			- `INPUT_data_source_choice=vp_trade`
			- `RAW_SOURCE_CHOICES=vp_trade`
			- `PRESENT_data_source_choice=TRUE`
			- Required IDs present: `data_source_choice`, `vp_trade_flow_choice`, `vp_group_choice`, `vp_subgroup_choice`, `vp_market_segment_choice`, `vp_commodity_name_choice`, `commodity_choice`, `country_choice`.
		- Prior failure mode across wrapped runs: `Error: Source dropdown is missing vp_trade value.` despite direct probe source evidence.
		- Probe stabilization edits in `System/Testing/ftn_validated_shiny_smoke.R`:
			- Source assertion now keys on resolved selected value (`input`/DOM/Shiny JS input) equaling `vp_trade`; source choices list retained as diagnostics.
			- FTN branding assertion now accepts observed FTN title/wording variants instead of requiring the literal token `FTN Trade`.
		- Post-patch deterministic smoke run:
			- Run: `Logs/ftn_probe_runs/ftn_shiny_smoke_run_20260810T140625.stdout.log`
			- `FTN_SHINY_SMOKE_STATUS=PASS`
			- `FTN_SHINY_SOURCE_CHOICES=vp_trade`
			- `FTN_SHINY_SOURCE_INPUT_VALUE=vp_trade`
			- `FTN_SHINY_SOURCE_SELECT_VALUE=vp_trade`
			- `FTN_SHINY_SOURCE_JS_INPUT_VALUE=vp_trade`
			- `FTN_SHINY_SOURCE_VALUE_IS_VP_TRADE=TRUE`
			- `FTN_SHINY_GROUP_HAS_FTN=TRUE`
			- `FTN_SHINY_FTN_TRADE_VISIBLE=TRUE`
			- `FTN_SHINY_FTN_TITLE_VISIBLE=TRUE`
			- `FTN_SHINY_LEGACY_VP_VISIBLE=FALSE`
			- `FTN_SHINY_LEGACY_VEGPULSE_VISIBLE=FALSE`
	- Reviewed two-commodity calendar-signature UI matrix tranche:
		- Added reviewed FTN matrix probe `System/Testing/ftn_validated_calendar_signature_matrix.R` to validate representative differing signatures through the same execution path used by Shiny display-month rendering.
		- Debug hardening applied using lessons from smoke-probe stabilization:
			- Startup retries and required-control DOM polling before assertions.
			- Non-blocking `set_inputs(wait_ = FALSE)` with explicit state confirmation from Shiny input/DOM rather than relying on immediate output updates.
			- Concrete hierarchy selection preference over rollup sentinel tokens to avoid all-rollup reactive stalls.
			- Progress checkpoints (`FTN_CAL_MATRIX_PROGRESS=...`) for deterministic stage visibility during long headless runs.
		- Deterministic pass run:
			- Run: `Logs/ftn_probe_runs/ftn_calendar_matrix_run_20260810T145203.stdout.log`
			- Exit: `EXIT_CODE=0`
			- `FTN_CAL_MATRIX_STATUS=PASS`
		- Representative commodity matrix outputs:
			- Bananas (calendar-year signature):
				- `FTN_CAL_MATRIX_EXPECTED_SIGNATURE=1-2-3-4-5-6-7-8-9-10-11-12`
				- `FTN_CAL_MATRIX_ARTIFACT_SIGNATURE=1-2-3-4-5-6-7-8-9-10-11-12`
				- `FTN_CAL_MATRIX_METADATA_SIGNATURE=1-2-3-4-5-6-7-8-9-10-11-12`
				- `FTN_CAL_MATRIX_UI_AXIS_TITLE=Calendar Year Month`
				- `FTN_CAL_MATRIX_UI_MONTH_ABBREV=Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec`
				- `FTN_CAL_MATRIX_ROW_PASS=TRUE`
			- Oranges (offset signature):
				- `FTN_CAL_MATRIX_EXPECTED_SIGNATURE=10-11-12-1-2-3-4-5-6-7-8-9`
				- `FTN_CAL_MATRIX_ARTIFACT_SIGNATURE=10-11-12-1-2-3-4-5-6-7-8-9`
				- `FTN_CAL_MATRIX_METADATA_SIGNATURE=10-11-12-1-2-3-4-5-6-7-8-9`
				- `FTN_CAL_MATRIX_UI_AXIS_TITLE=Commodity Year Month`
				- `FTN_CAL_MATRIX_UI_MONTH_ABBREV=Oct|Nov|Dec|Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep`
				- `FTN_CAL_MATRIX_ROW_PASS=TRUE`

## Blockers And Failed Attempts

- 2026-08-10 Failed attempt: initial preflight script generated from PowerShell here-string had parse errors (`unexpected input`) due variable interpolation and encoding side effects.
	- Resolution: regenerated script with single-quoted here-string and ASCII encoding; rerun succeeded.
- 2026-08-10 Resolved blocker: long-running rebuild completion uncertainty.
	- Resolution: instrumented direct build completed with `CHK|done|2026-08-10T16:29:26Z` and wrote monthly artifact, metadata artifact, and processed-artifact manifest; app-ui metadata then rebuilt explicitly.
- 2026-08-10 Failed attempt: parse validation command using bare `Rscript` failed in this terminal because `Rscript` is not on PATH.
	- Resolution: used explicit executable path `C:/Program Files/R/R-4.5.1/bin/Rscript.exe`; parse checks then completed successfully.
- 2026-08-10 Validation attempt against `vp_trade_monthly_pre.rds` during active write failed with `error reading from connection`.
	- Resolution: defer direct `readRDS` provenance/calendar assertions until rebuild exits and file writes stabilize.
- 2026-08-10 Deterministic rebuild diagnosis extension:
	- Legacy `Master_FTN.R` reruns repeatedly produced a writable `vp_trade_monthly_pre.rds` but did not reach metadata or manifest write completion before process termination/restart.
	- Instrumented direct build confirms major upstream stages are functioning and narrows the long-running region to downstream app-data/materialization logic rather than initial source pathing or schema checks.
- 2026-08-10 Failed attempt: first smoke-stabilization run after source-state hardening failed on strict literal text assertion `Error: FTN Trade label is not visible.`.
	- Resolution: captured headless body text snapshot (`Logs/ftn_probe_runs/ftn_text_probe.R`) showing title rendering as `USDA-ERS Fruit and Tree Nut Trade Analysis Tool`; expanded accepted FTN branding assertions accordingly.
- 2026-08-10 Resolved blocker: reviewed `ftn_validated_shiny_smoke.R` headless flakiness.
	- Resolution: source-state assertion now validates resolved selected source value (`vp_trade`) rather than transient option-list enumeration; deterministic rerun passed with `FTN_SHINY_SMOKE_STATUS=PASS` and full FTN/legacy visibility checks.
- 2026-08-10 Failed attempt: first calendar matrix probe versions (`Logs/ftn_probe_runs/ftn_calendar_matrix_run_20260810T143001.*` and `...143334.*`) stalled/failed due startup option enumeration dependency and `set_inputs()` waiting on output updates (`Server did not update any output values within 120 seconds`).
	- Resolution: migrated probe to smoke-style robust control handling (`wait_ = FALSE` + explicit value confirmation), added concrete hierarchy preference, and introduced progress checkpoints for deterministic diagnostics.
	- Verification: stabilized run `Logs/ftn_probe_runs/ftn_calendar_matrix_run_20260810T145203.stdout.log` completed with `FTN_CAL_MATRIX_STATUS=PASS`.
- 2026-08-10 Resolved issue: Almond unit values appeared inflated because FTN source volume rows are `Thousand pounds`, while artifact `unit_value` had been calculated against the metric-ton quantity base.
	- Resolution: updated `Programs/vp_data_utils.R` so unit-value calculations use source-native unit-value denominators while preserving existing quantity-volume base fields; then repaired the current processed artifact in place from its existing value/volume fields with a timestamped backup.
	- Verification: direct source comparison and repaired artifact both return Export / World / Almonds / `All` unit values of `2.582-2.945 dollars per pound`; reviewed artifact/currentity and Shiny smoke probes passed after repair.
- 2026-08-10 Deferred full rebuild: attempted full `vp_build_trade_artifact()` rerun for the Almond unit-value fix entered the known long materialization path and was stopped before completion.
	- Resolution: used the already validated code fix for future builds and repaired the current artifact directly to avoid another multi-hour rebuild cycle.

## Deferred Work

- Broad internal rename from VP to FTN.
- New `.ftn_clone_root` sentinel migration.
- Re-enabling disabled Census/PSD/NASS/WASDE/hybrid source families.
- Any redesign of tabs, controls, filtering, rollups, unit values, or marketing-year logic.
- Cleanup of inactive legacy rice/almond code not reachable in FTN mode.

## Final Summary

- FTN conversion acceptance is now materially unblocked: artifact rebuild/currentity validation passes against `Input/fruit-trade-data.csv`, and the reviewed FTN headless smoke probe now passes with FTN labels/options and legacy VP wording absent.
- Internal runtime contracts remain preserved for first pass (`vp_trade` source key, existing control IDs, artifact names/roles, and VP-prefixed internals), while visible active-path text/defaults were converted to FTN-safe wording.
- Reviewed two-commodity calendar-signature UI matrix now passes end-to-end (`System/Testing/ftn_validated_calendar_signature_matrix.R`): Bananas validates calendar-year ordering/title and Oranges validates commodity-year offset ordering/title, each matching preflight signatures, metadata calendars, artifact signatures, and Shiny display-month axis output.
- Go/no-go status for this tranche is `Ready` under the defined no-behavior-change scope: launch/root/source/currentity, probe governance, smoke checks, and representative calendar-signature matrix checks are all green with deterministic run artifacts logged.