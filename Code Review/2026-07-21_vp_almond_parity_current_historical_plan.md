# VP Almond-Parity Current vs. Historical Plan

Date: 2026-07-21
Branch: main
Status: Active. This supersedes `VP Clone/Code Review/2026-07-21_vp_current_historical_clone_plan.md` for implementation work.

## Purpose

Build the VP Current vs. Historical app as a UI/functionality clone of the mature almond Current vs. Historical experience. Backend data-pipeline parity is out of scope: VP only needs local CSV-to-artifact processing sufficient to feed the almond-style UI and server behavior.

## Scope

Included:

- Preserve `VP Clone/Input/veg-trade-data.csv`.
- Supersede the lightweight VP scaffold because it does not match almond Current vs. Historical UI/functionality closely enough.
- Rebuild `VP Clone` from the mature almond runtime/module structure.
- Preserve almond Current vs. Historical layout and behavior: top shell, sidebar, controls, comparison plot, summary table, historical averages/range, projection controls/traces, reset, cache behavior, and custom type/custom country workflows.
- Replace only necessary visible controls: the visible Data Source selector region becomes Group, Subgroup, Market Segment, and Commodity dropdowns; top-bar Commodity values are sourced from `CommodityName`; sidebar Type remains `commodity_choice` sourced from filtered `CommodityDetail`; Basis is removed; Notes are removed; Data Frequency remains visible and fixed to Monthly.
- Use `vp_trade` as the internal source profile and local CSV artifact source.
- Keep future VP feature-tab seams hidden/documented.

Excluded:

- Backend data-pipeline parity with almond.
- Network downloads or online data pulls.
- Notes.
- Basis UI/conversion for VP.
- Census Corrections.
- Visible future tabs in phase 1.
- Export Sales, PSD, WASDE, NASS, Hybrid, or Census as VP data sources.

## Source-Of-Truth Ledger Contract

- This file is the implementation ledger from this point forward.
- Update this file after every tranche, edit group, failed attempt, validation, blocker, rejected approach, and closeout.
- Do not create a paired results markdown unless explicitly requested.
- Keep chat terse during implementation; details go here.
- Final Summary must be lay-friendly.

## Critical Audit Findings

- The prior VP scaffold is rejected as an implementation base because it recreated only a simplified Current vs. Historical surface, not the almond UI/functionality.
- Top-control substitution must happen inside almond `output$data_frequency_ui` / rendered `#data_frequency_ui`; adding VP controls elsewhere risks stale client/server source state and visual drift.
- Even when visible Data Source is removed, copied almond code and JavaScript still read `data_source_choice`; VP must keep hidden/initialized `data_source_choice = "vp_trade"` or fully refactor every consumer.
- `input$data_frequency` must remain initialized and Monthly in almond plumbing.
- VP has both pound and gallon volume rows. Gallons cannot be passed through almond weight-unit conversion.
- Group, Subgroup, Market Segment, and Commodity (`CommodityName`) are visible VP top controls; sidebar `commodity_choice` is filtered `CommodityDetail`; submitted commodity keys must include all required disambiguators.
- Cache/reset keys must include Group, Subgroup, Market Segment, `CommodityName` selector state, sidebar `CommodityDetail` selector state, trade flow, commodity key, artifact signature, and month-calendar signature.
- VP monthly month-label display must come from selected VP artifact calendar fields (`analysis_month`, `MonthNum`, `month_abbrev`, `month_name`, `calendar_signature`) rather than copied almond global August-start mapping.
- VP slash market-year labels must be parsed before artifact inference. Current `as.integer(MarketYear)` handling turns values such as `2025/26` into `NA`, then falls back to calendar `Year`, which can split one market year across two app years.
- VP market-year calendar inference should prefer `World` / `GRAND_TOTAL` rows for the selected trade and commodity context when available, then explicitly fall back to all partner rows only when World rows are absent.
- VP calendar inference must be trade-specific; import month coverage must not determine export month order for the same commodity/type.
- Removing old data-source code too aggressively may break generic Current vs. Historical helpers; prune only after source tests prove a branch is inactive or unnecessary.
- Rendered DOM/live-browser parity evidence is required because source scans alone did not catch the previous UI drift.

## Guardrails

- Preserve the input CSV.
- Do not touch unrelated `VPN Clone` status.
- Treat root almond files as read-only templates unless a shared-core edit is explicitly justified.
- Reuse almond Current vs. Historical modules and behavior; do not repair the simplified scaffold into another custom app.
- Keep future feature tabs hidden.
- Remove Notes rather than hiding it.
- Remove Basis visually and bypass it server-side.
- Keep custom type/custom country builders.
- Update this ledger before moving between tranches.

## Step Ledger

| Step | Work | Status | Notes |
|---|---|---|---|
| 1 | Create corrective parity ledger. | Complete | Created this plan and marked prior lightweight scaffold as superseded/rejected for parity implementation. |
| 2 | Archive lightweight scaffold. | Complete | Moved lightweight scaffold files into `VP Clone/_superseded_lightweight_scaffold_2026-07-21`; preserved `VP Clone/Input/veg-trade-data.csv`. |
| 3 | Rebuild VP root from almond runtime. | Complete | Copied almond `Programs/app_source`, server modules, shared core helper, shared utility dependencies, master launcher utility, and contract config into `VP Clone`; created VP root marker, VP-local Code Review directory, and almond-pattern VP entrypoints. |
| 4 | Add VP artifact/source contract. | Complete | Added `vp_contract.R`, preloaded it before copied `global.R`, and validated copied commodity root plus source startup. |
| 4a | Build VP local CSV artifact adapter. | Complete | `vp_data_utils.R` now emits direct data-frame monthly artifact columns compatible with copied Current vs Historical metrics; `Master_VP.R` writes manifest-backed artifact. |
| 4b | Wire copied Current vs Historical to VP source. | Complete | Added `vp_trade` startup loader, metadata inclusion, native commodity vectors, commodity scope helpers, and `base_data_converted()` monthly branch. |
| 5 | Adapt almond top shell and sidebar. | Complete | VP top controls now render in `data_frequency_ui` as Group/Subgroup/Market Segment/Commodity (`CommodityName` values); VP sidebar Commodity Detail remains `commodity_choice` from filtered `CommodityDetail`; VP Data Frequency is visible and fixed to Monthly beside Trade Flow; legacy `data_source_choice` stays hidden as compatibility state; Basis is suppressed and visible Notes buttons are suppressed for VP. |
| 6 | Route real comparison functionality. | In Progress | Comparison plot cache key now includes VP top controls (trade flow, group, subgroup, market segment, commodity), and VP monthly display month mapping now resolves from selected VP artifact calendar labels with fallback only when VP mapping is unavailable; browser-level visual parity check remains open. |
| 7 | Validate parity and data behavior. | In Progress | Parse checks pass (`PARSE_OK_01`, `PARSE_OK_02`, `PARSE_OK_03`, `PARSE_OK_04`, `PARSE_OK_SMOKE`); VP smoke confirms initialized top-control inputs, visible top-control labels, visible sidebar `Type` label, preserved CommodityName/CommodityDetail split semantics, and a non-August fixture where comparison x-axis starts at `Jan`. |
| 7a | Repair VP market-year calendar inference. | Complete | `vp_data_utils.R` now parses slash `MarketYear` labels as ending-year MY values, uses trade-specific commodity keys, infers calendars from World rows when available, pads incomplete calendars by inferred start-month cycle, rebuilds artifact version `v2`, and smoke asserts Austrian winter peas export/World starts in July. |
| 7b | Implement VP artifact-backed Type `All`. | Complete | Implemented artifact-backed additive (`Volume`, `Value`) `CommodityDetail = All` rows, forced VP Type fallback/reset to `All`, added VP-safe MYC type-mode country basis handling, rebuilt artifacts, and validated All/default/reset/share contracts in smoke and artifact audits. |
| 8 | Closeout. | In Progress | Evidence and tranche updates logged; remaining closeout is browser visual parity/reset verification and final Summary polish. |

## Implementation Plan

1. Archive the lightweight VP scaffold while preserving `VP Clone/Input/veg-trade-data.csv`.
2. Copy/adapt the mature almond runtime into `VP Clone` using the same module boundaries.
3. Add `vp_trade` source profile and hidden source/frequency compatibility state.
4. Build the VP local CSV artifact into almond-compatible monthly columns.
5. Adapt `output$data_frequency_ui` directly: replace visible Data Source with Group, Subgroup, Market Segment, and Commodity; source top Commodity choices from `CommodityName`; keep sidebar `commodity_choice` as filtered `CommodityDetail`; keep Data Frequency visible as Monthly; add VP trade flow.
6. Preserve almond sidebar layout and Current vs. Historical controls, removing only Notes and Basis.
7. Reuse copied comparison plot, summary table, projection, historical average, reset, and cache paths.
8. Add VP cache/reset dimensions and custom builder scope.
9. Run parity-first validation, then data correctness validation.

## Verification / Validation Targets

- Input CSV preserved.
- Prior scaffold archived or clearly superseded.
- VP app modules are copied/adapted from almond structure, not the simplified scaffold.
- Group/Subgroup/Market Segment/Commodity controls render inside `#data_frequency_ui`.
- Visible Data Source absent; hidden/compatible source state is `vp_trade`.
- Data frequency is visible as Monthly and initialized through almond plumbing.
- Top-bar Commodity choices reflect `CommodityName` values, not `CommodityDetail` values.
- Sidebar Commodity Detail choices reflect filtered `CommodityDetail` values under the selected Trade Flow/Group/Subgroup/Market Segment/CommodityName.
- Sidebar Type label is visible for VP while preserving `commodity_choice` input id and `CommodityDetail` value semantics.
- Market Segment selection participates in VP cascade filtering and downstream data selection.
- Basis absent; server-side basis conversion bypassed for VP.
- Notes absent from UI/server/persistence.
- Only Current vs. Historical visible.
- VP uses copied comparison plot and summary table paths.
- Default launch renders nonempty almond-style plot and summary table.
- Reset returns to VP defaults and does not fall back to export-sales/rice values.
- Cache keys include VP top controls, commodity key, country, unit choices, artifact signature, and calendar signature.
- VP monthly comparison x-axis labels follow selected VP artifact calendar order/labels and are not forced to August-first for non-August signatures.
- Pound and gallon quantity families are handled without cross-conversion errors.
- Custom type/custom country builders work under `vp_trade`.

## Relevant Files

- `Almond_Analysis_Shiny.R` - reference entrypoint/root-resolution pattern.
- `app.R` - reference app runner pattern.
- `Master.R` - reference master launcher pattern.
- `Programs/master_launch_utils.R` - reference launcher/update orchestration.
- `Programs/app_source/ui.R` - reference top shell/sidebar/client behavior.
- `Programs/app_source/global.R` - reference startup/source/metric/conversion behavior.
- `Programs/app_source/server/01_state_and_custom_types.R` - custom state and scope helpers.
- `Programs/app_source/server/02_partner_and_notes.R` - top controls, main tabs, units, source routing, Notes removal surface.
- `Programs/app_source/server/03_core_reactives_and_ui.R` - selected/filtered data, countries, projection controls, reset/state behavior.
- `Programs/app_source/server/04_comparison_plots.R` - actual Current vs. Historical plot/table/projection/cache behavior.
- `VP Clone/Input/veg-trade-data.csv` - VP local source CSV.
- `VP Clone/Code Review/2026-07-21_vp_current_historical_clone_plan.md` - superseded lightweight scaffold ledger.

## Decisions

- Supersede the lightweight scaffold.
- Almond app is authoritative for UI/functionality parity.
- Backend pipeline parity is out of scope.
- Data remains local CSV to R artifact.
- Visible Data Source becomes Group/Subgroup/Market Segment/Commodity inside `data_frequency_ui`.
- VP top Commodity selector remains labeled `Commodity` and binds to `CommodityName` values.
- VP sidebar `commodity_choice` remains the detail selector and binds to filtered `CommodityDetail` values; visible VP label is `Type`.
- VP Data Frequency stays visible and fixed to Monthly beside Trade Flow.
- VP monthly display month mapping is data-driven from selected VP calendar labels, with fallback to global year-type mapping only when VP mapping is unavailable.
- Slash `MarketYear` values are ending-year market years for VP artifact purposes (`2025/26` becomes `MY 2026`).
- World rows are the preferred source for VP market-year calendar inference when present for a trade/commodity/type context.
- VP market-year calendar inference is trade-specific so import and export calendars cannot contaminate each other.
- Hidden source compatibility state remains `vp_trade` unless every consumer is refactored and validated.
- Basis is removed and bypassed.
- Notes and Census Corrections are excluded.
- Unit Value/rate metrics stay out of cumulative/projection paths unless a safe profile is added.

## Bugs / Rejected Approaches

- Rejected: lightweight VP scaffold implemented a simplified custom interface and simplified plot/table rather than almond Current vs. Historical parity.

## Blockers

- No hard blockers. Remaining implementation risk is accidental drift from almond modules or stale source/reset/cache state, plus final browser-level visual parity verification.

## Evidence Log

- 2026-07-21 Created new parity ledger and marked the prior scaffold ledger as superseded for implementation.
- 2026-07-21 Scaffold archive validation emitted `VP_ARCHIVE_EXISTS=True`, `VP_INPUT_CSV_EXISTS=True`, and `VP_ARCHIVE_ITEM_COUNT=8`.
- 2026-07-21 Almond baseline copy emitted `VP_BASELINE_COPY_STATUS=True` and preserved `VP_INPUT_CSV_EXISTS=True`; restored validated `vp_data_utils.R`; created `.vp_clone_root`, `VP_Analysis_Shiny.R`, `app.R`, and `Master_VP.R`.
- 2026-07-21 First copied startup validation failed with `Commodity contract must be loaded before cloned global.R startup`; fixed by adding `vp_contract.R` and preloading contract utilities/contract before `global.R`.
- 2026-07-21 Root validation initially failed because the copied validator requires a clone-local `Code Review` directory; created `VP Clone/Code Review` and validated `VP_ROOT_VALID=TRUE`.
- 2026-07-21 VP entrypoint source validation emitted `VP_PARITY_SOURCE_STATUS=TRUE` after contract/root fixes.
- 2026-07-21 Revised VP artifact builder emitted almond-compatible monthly columns and rebuilt `vp_trade_monthly_pre.rds`; validation emitted `VP_MASTER_ARTIFACT_STATUS=TRUE` and `VP_MASTER_ARTIFACT_ROWS=346741`.
- 2026-07-21 Added VP startup loader and server routing; repeated source validations emitted `VP_PARITY_SOURCE_STATUS=TRUE`.
- 2026-07-21 First rendered `shinytest2` smoke attempt failed before app launch because PowerShell expanded `AppDriver$new` to `AppDriver(...)`; rerun with single-quoted R expression required.
- 2026-07-21 Second rendered `shinytest2` smoke attempt also failed before app launch because the inline custom `%||%` operator was mangled by shell parsing; rerun with plain helper function required.
- 2026-07-21 Third rendered `shinytest2` smoke attempt reached `shinytest2` but failed with `Reason: On CRAN`; rerun requires setting `NOT_CRAN=true` for the smoke process.
- 2026-07-21 Fourth rendered `shinytest2` smoke started with `VP_SHINYTEST_STARTED=TRUE`, but sampled top-control inputs returned `NA`; follow-up needs an idle wait and DOM presence check to distinguish delayed dynamic UI from missing controls.
- 2026-07-21 Fifth rendered `shinytest2` idle/DOM smoke failed before app validation because remaining `$` field access in the inline R expression was still parsed by PowerShell; rerun uses list indexing only.
- 2026-07-21 Created repeatable smoke script `VP Clone/System/Testing/vp_shinytest_smoke.R` to avoid fragile inline R/PowerShell quoting.
- 2026-07-21 Rendered smoke emitted `VP_SHINYTEST_IDLE=TRUE`, `VP_INPUT_DATA_SOURCE=vp_trade`, `VP_INPUT_FREQUENCY=monthly`, `VP_INPUT_COMMODITY=Artichokes`, `VP_INPUT_MAIN_COMMODITY=Globe`, and `VP_OUTPUT_SUMMARY_TABLE_PRESENT=TRUE`.
- 2026-07-21 Suppressed VP Basis visibility via `show_basis_choice()` and suppressed visible Notes buttons for VP sidebar/map rows; smoke still reports retained hidden `basis_choice=vp_identity`, which is acceptable as compatibility state but not a visible VP dropdown.
- 2026-07-21 Implemented VP top-bar control contract in `server/02`: Group/Subgroup/Market Segment/Commodity (`CommodityName`-bound), visible Monthly Data Frequency beside Trade Flow, and Market Segment-aware VP cascades/filters.
- 2026-07-21 Updated VP artifact mapping in `vp_data_utils.R` to set app `commodity := CommodityDetail`; rebuilt `vp_trade_monthly_pre.rds` and `vp_trade_metadata_pre.rds` (`VP_ARTIFACT_REBUILT`).
- 2026-07-21 Expanded cache coherence: added VP top-control dimensions to `comparison_plot_base_cache_key()` (`server/04`), `filtered_data_stable_cache_key()` (`server/03`), and `map_runtime_stable_data_cache_key()` (`server/02`).
- 2026-07-21 Parse validation passed for edited files (`PARSE_OK_02`, `PARSE_OK_03`, `PARSE_OK_04`, `PARSE_OK_VP_UTILS`).
- 2026-07-21 Updated `vp_shinytest_smoke.R` to probe DOM in iframe context and validate visible labels; smoke emitted `VP_LABEL_GROUP_VISIBLE=TRUE`, `VP_LABEL_SUBGROUP_VISIBLE=TRUE`, `VP_LABEL_MARKET_SEGMENT_VISIBLE=TRUE`, `VP_LABEL_COMMODITY_VISIBLE=TRUE`, `VP_LABEL_DATA_FREQUENCY_VISIBLE=TRUE`, `VP_INPUT_MARKET_SEGMENT=__all__`, and `VP_OUTPUT_SUMMARY_TABLE_PRESENT=TRUE`.
- 2026-07-21 Investigated commodity regression and identified root cause: top-bar `vp_commodity_name_choice` was populated from `CommodityDetail` and then synced into sidebar `commodity_choice`, collapsing name/detail semantics.
- 2026-07-21 Implemented selector split across copied almond modules: top-bar `vp_commodity_name_choice` now uses filtered `CommodityName`; sidebar `commodity_choice` choices now derive from filtered VP `CommodityDetail` in `server/01` while retaining custom type/custom builder pathways.
- 2026-07-21 Updated VP filtering in `server/02` (`base_data_converted()` and `country_sort_period_source_data()`): apply top-bar `CommodityName` filter first, then apply sidebar detail via app-wide `commodity` field (`commodity := CommodityDetail`).
- 2026-07-21 Split cache dimensions for VP commodity semantics: `map_runtime_stable_data_cache_key()` now includes both `vp_commodity_name` and `vp_commodity_detail`; `filtered_data_stable_cache_key()` and `comparison_plot_base_cache_key()` now include distinct name/detail keys.
- 2026-07-21 Parse validation passed after this tranche (`PARSE_OK_01`, `PARSE_OK_02`, `PARSE_OK_03`, `PARSE_OK_04`, `PARSE_OK_SMOKE`).
- 2026-07-21 Updated smoke to validate selectize option sets and Artichokes detail expectations under import flow; smoke emitted `VP_ARTICHOKE_TOP_COMMODITY=Artichokes`, `VP_ARTICHOKE_SIDEBAR_DETAIL=Globe`, `VP_ARTICHOKE_TRADE_FLOW=import`, `VP_TOP_CHOICES_INCLUDE_GLOBE=FALSE`, `VP_SIDEBAR_HAS_EXPECTED_ARTICHOKE_DETAILS=TRUE`, `VP_SIDEBAR_VALUE_IS_DETAIL=TRUE`, and `VP_TOP_AND_SIDEBAR_DIFFER=TRUE`.
- 2026-07-21 Ran disconfirming VP calendar profile against `vp_trade_monthly_pre.rds`: `VP_SIGNATURE_COUNT=9`, `VP_NON_AUG_SIGNATURE_ROWS=323`, representative non-August fixture `export | Dry pulses | Dried beans | Dried | Bambara beans | Unspecified | first=Jan(1)`.
- 2026-07-21 Implemented VP-specific month display mapping in `server/03_core_reactives_and_ui.R`: `current_display_month_mapping()` now uses selected VP rows (`analysis_month`, `MonthNum`, `month_abbrev`, `month_name`, `calendar_signature`) for `vp_trade`, with guarded fallback to existing year-type mapping.
- 2026-07-21 Implemented VP month-axis title behavior in `server/03_core_reactives_and_ui.R`: `Calendar Year Month` when signature is `1-2-3-4-5-6-7-8-9-10-11-12`, otherwise `Commodity Year Month` for `vp_trade`; non-VP behavior unchanged.
- 2026-07-21 Updated `server/02_partner_and_notes.R` month-name/month-abbrev lookups to consume shared `current_display_month_mapping()` when available so VP summary/sort period labels use the same data-driven calendar labels.
- 2026-07-21 Renamed VP sidebar `commodity_choice` visible label from Commodity Detail to `Type` in `server/01_state_and_custom_types.R` while preserving input id and `CommodityDetail` value semantics.
- 2026-07-21 Extended `VP Clone/System/Testing/vp_shinytest_smoke.R` to assert `VP_LABEL_TYPE_VISIBLE=TRUE` and month-axis fixture behavior; smoke emitted `VP_FIXTURE_AVAILABLE=TRUE`, `VP_FIXTURE_TYPE_AVAILABLE=TRUE`, `VP_FIXTURE_MONTH_AXIS_FIRST_LABEL=Jan`, `VP_FIXTURE_MONTH_AXIS_FIRST_IS_JAN=TRUE`.
- 2026-07-21 Parse validation passed after month-axis/Type tranche (`PARSE_OK_01`, `PARSE_OK_02`, `PARSE_OK_03`, `PARSE_OK_04`, `PARSE_OK_SMOKE`).
- 2026-07-21 Audited Austrian winter peas discrepancy and found the likely artifact root cause: `MarketYear` slash labels such as `2025/26` are currently coerced with `as.integer()`, become `NA`, and fall back to `Year`; implementation tranche 7a will repair parsing and World-row/trade-specific calendar inference before touching display consumers.
- 2026-07-21 Implemented VP artifact builder version `vp_trade_artifact_2026_07_21_v2`: added `vp_parse_market_year()` (`2025/26 -> 2026`, `1999/00 -> 2000`), made `commodity_key` trade-specific, and updated `vp_infer_month_calendars()` to prefer World rows and pad incomplete calendars by inferred start-month cycle.
- 2026-07-21 Rebuilt `vp_trade_monthly_pre.rds` and `vp_trade_metadata_pre.rds`; rebuild emitted `VP_MASTER_ARTIFACT_STATUS=TRUE` and `VP_MASTER_ARTIFACT_ROWS=346741`.
- 2026-07-21 Focused Austrian winter peas artifact assertion passed: export/World `MY 2026`, `calendar_year=2025`, `MonthNum=7` maps to `analysis_month=1`, `month_abbrev=Jul`, `calendar_signature=7-8-9-10-11-12-1-2-3-4-5-6`, `calendar_source_scope=world`.
- 2026-07-21 Scope/regression assertion passed: Austrian winter peas export and import have independent World-derived signatures (`export=7-8-9-10-11-12-1-2-3-4-5-6`, `import=8-9-10-11-12-1-2-3-4-5-6-7`), and a January-first VP fixture remains available (`Garlic`, `Dried, except powder or flour`, `1-2-3-4-5-6-7-8-9-10-11-12`).
- 2026-07-21 Added smoke regression in `VP Clone/System/Testing/vp_shinytest_smoke.R` for Austrian winter peas export/World July-first artifact behavior; parse checks passed (`PARSE_OK_VP_UTILS`, `PARSE_OK_SMOKE`).
- 2026-07-21 Full VP smoke passed after calendar inference repair and artifact rebuild; emitted existing selector/Type/month-axis evidence plus `VP_AUSTRIAN_WINTER_PEAS_EXPORT_WORLD_JULY_FIRST=TRUE`.
- 2026-07-21 Started tranche 7b (`VP artifact-backed Type All`): implementation begins with artifact synthesis of `CommodityDetail = All` additive rows plus VP Type default/reset/share validation updates.
- 2026-07-21 Implemented tranche 7b code changes:
	- `vp_data_utils.R`: bumped builder version to `vp_trade_artifact_2026_07_21_v3`; added `vp_all_type_label <- "All"`; added `vp_append_all_type_rows()` to synthesize additive All source rows (`Volume`, `Value`) before calendar inference; excluded All from the Unit Value rate branch; hard-forced `unit_value`/`unit_value_unit` to `NA` for All rows.
	- `server/01_state_and_custom_types.R`: VP Type choice ordering now places `All` first when present; VP fallback/default pathways now prefer `All`.
	- `server/06_pace_analysis_and_reset.R`: VP Reset sets `commodity_choice` to `All` when available.
	- `server/03_core_reactives_and_ui.R`: MYC type-mode country share basis now uses source-aware aggregate (`All` for VP, `All Rice` for non-VP) to avoid VP mismatch if the path is reached.
	- `vp_shinytest_smoke.R`: added artifact-level All contract assertions, sidebar default-to-All assertions, reset-to-All assertions, and a Type-specific share-contract fixture.
- 2026-07-21 Parse checks after tranche 7b edits passed (`PARSE_OK_VP_UTILS`, `PARSE_OK_01`, `PARSE_OK_03`, `PARSE_OK_06`, `PARSE_OK_SMOKE`).
- 2026-07-21 Rebuilt `vp_trade_monthly_pre.rds` and metadata with builder `v3`; rebuild emitted `VP_MASTER_ARTIFACT_STATUS=TRUE` and `VP_MASTER_ARTIFACT_ROWS=624176`.
- 2026-07-21 VP smoke after tranche 7b passed with new evidence:
	- `VP_INPUT_MAIN_COMMODITY=All`
	- `VP_SIDEBAR_HAS_ALL_TYPE=TRUE`
	- `VP_SIDEBAR_DEFAULTS_TO_ALL=TRUE`
	- `VP_RESET_TYPE_CHOICE=All`
	- `VP_RESET_TYPE_TO_ALL=TRUE`
	- `VP_RESET_COUNTRY_TO_WORLD=TRUE`
	- `VP_SHARE_CONTRACT_CONTEXT=export | Dry pulses | Dried beans | Dried | Bambara beans | MY2017 | M5 | Country=Canada | Detail=Unspecified`
	- `VP_SHARE_CONTRACT_ALL=1.00000000`
	- `VP_SHARE_CONTRACT_DETAIL=1.00000000`
	- existing calendar regression still passes: `VP_AUSTRIAN_WINTER_PEAS_EXPORT_WORLD_JULY_FIRST=TRUE`.
- 2026-07-21 Focused artifact contract audit after rebuild passed:
	- `VP_ALL_CONTEXT_DETAIL=181`
	- `VP_ALL_CONTEXT_WITH_ALL=181`
	- `VP_ALL_CONTEXT_MISSING=0`
	- `VP_ALL_UNIT_VALUE_FINITE_COUNT=0`
	- `VP_ALL_MIXED_VOLUME_FAMILY_CONTEXTS=0`

## Follow-Up Avoidance Review

Open gates:

- Rendered DOM parity, not just source parity; Shiny input/output smoke passes, but visual browser review remains.
- Reset Filters must be tested separately after a manual browser pass.
- Hidden source state must be validated.
- Quantity family conversion must be tested for both pounds and gallons; current artifact preserves volume family metadata but common quantity-unit conversion still assumes the copied metric-ton pathway.
- Cache invalidation was extended to VP control dimensions in key reactive cache paths; retain a browser pass to confirm no stale-panel edge cases remain.
- Pruning must not remove generic helper behavior required by Current vs. Historical.

## Closeout Checklist

- [x] Lightweight scaffold archived/superseded without losing input CSV.
- [x] Almond runtime/module structure copied/adapted.
- [x] VP artifact builder feeds almond-compatible monthly data.
- [x] Top controls implemented inside `data_frequency_ui` with split semantics (top Commodity = `CommodityName`; sidebar Type = filtered `CommodityDetail`) and visible Monthly frequency beside Trade Flow.
- [x] Real almond comparison table path reused in rendered smoke; plot/projection path is wired through copied modules and still needs browser visual confirmation.
- [x] Notes and Basis visible controls removed/bypassed for VP; hidden compatibility state remains where copied modules expect it.
- [x] VP monthly month-axis labels now use selected VP artifact calendar mapping; non-August fixture smoke confirms first tick label is data-driven (`Jan`) rather than hardcoded August.
- [x] VP artifact market-year inference now parses slash years, uses World-row calendar authority where available, and fixes Austrian winter peas export/World to July-first (`VP_AUSTRIAN_WINTER_PEAS_EXPORT_WORLD_JULY_FIRST=TRUE`).
- [x] Source, artifact, parse, and live Shiny smoke validations pass for this tranche; reset/custom-builder/browser visual parity remains a follow-up gate.
- [ ] Final Summary complete.

## Summary

The VP app has been rebuilt on top of the almond runtime instead of the rejected lightweight scaffold. It now starts through `VP_Analysis_Shiny.R`, builds a local R artifact from `Input/veg-trade-data.csv`, preloads a VP commodity contract, and routes the copied Current vs. Historical server path to the VP monthly trade data.

The top shell now shows the requested VP controls: `Group`, `Subgroup`, `Market Segment`, and `Commodity`, with top Commodity sourced from `CommodityName`. The sidebar remains `commodity_choice` sourced from filtered `CommodityDetail` values under selected top-bar dimensions, and the visible VP label is now `Type`. The right-side control group includes a visible monthly `Data Frequency` control beside `Trade Flow`. The copied server still receives hidden compatibility `data_source_choice = vp_trade`.

The VP artifact builder now reads slash market years correctly. A raw value like `2025/26` is treated as `MY 2026`, not discarded and replaced with calendar year. Calendar inference is now trade-specific and prefers `World` rows when they exist. This fixes Austrian winter peas export/World so Current vs. Historical data uses July as the first commodity-year month, with a July-first signature of `7-8-9-10-11-12-1-2-3-4-5-6`.

The VP artifact and app commodity mapping continue to use `CommodityDetail` for app-wide `commodity`, while VP filtering now applies top-bar `CommodityName` first and sidebar detail second. Cache keys were extended across `server/02`, `server/03`, and `server/04` to include both VP commodity dimensions (name and detail) so filter changes invalidate stale outputs.

The monthly display mapping bug is now corrected for VP Current vs. Historical behavior. For `vp_trade`, month labels and order are pulled from selected VP artifact calendar fields (`analysis_month`, `MonthNum`, `month_abbrev`, `month_name`, `calendar_signature`) rather than inheriting the copied almond August-start mapping. Smoke validation confirms a non-August fixture (`Bambara beans / Unspecified` under export Dry pulses) now starts at `Jan` on the comparison x-axis.

The major blocker was startup parity: the copied almond global required a valid commodity contract, clone root sentinel, helper utilities, and manifest-backed processed artifacts before any UI work could be safely tested. Those issues are resolved. Remaining risk is mostly visual/behavioral polish: browser parity for the plot/projection path, reset/cache validation, and careful treatment of VP gallon-based quantity units because the copied almond quantity conversion path assumes metric-ton-style quantity metrics.
