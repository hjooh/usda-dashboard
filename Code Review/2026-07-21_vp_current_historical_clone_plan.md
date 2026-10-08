# VP Current vs. Historical Clone Plan

Date: 2026-07-21
Branch: main
Status: Active. Step 1 setup scaffold and ledger creation are complete and validated. This is the single source-of-truth implementation ledger for the VP Current vs. Historical clone under `VP Clone`. No paired results markdown will be created unless explicitly requested.

## Purpose

Build a smaller VP Shiny app under `VP Clone` using the mature almond app as the template, but keep phase 1 focused on the Census-style Current vs. Historical experience. The VP app will read a refreshed local monthly CSV from `VP Clone/Input/veg-trade-data.csv`, convert it into fast local R artifacts through `Master_VP.R`, and launch a Shiny app that exposes VP Group, Subgroup, MarketSegment, Trade Flow, Commodity Type, Country, Quantity Unit, and Value Unit controls.

The goal is to preserve the useful Current vs. Historical workflow and its projection/figure behavior while removing unrelated Notes functionality and old data-source integrations that VP does not need. Future VP feature tabs may be added later, but phase 1 should surface only Current vs. Historical.

## Scope

Included in phase 1:

- Preserve the existing `VP Clone/Input/veg-trade-data.csv` file.
- Create VP-specific app directories under `VP Clone`.
- Create VP app entrypoints, configuration, artifact builder, metadata builder, server/UI modules, and harnesses as needed.
- Build local processed R artifacts from the monthly CSV.
- Add `Master_VP.R` as the local artifact rebuild and launch orchestrator.
- Implement Current vs. Historical using VP data and VP controls.
- Remove Notes functionality from the VP app.
- Retain custom type and custom country builder functionality, scoped to `vp_trade`.
- Remove or exclude Export Sales, PSD, WASDE, and other non-VP data-source integration code from active VP startup/server paths.
- Exclude Census Corrections unless separately requested later.
- Keep clean documented extension seams for future VP feature tabs: Historical Trendlines, Map, Monthly Heatmap, Data, Custom Comparison Tool, Market Year Comparison Tool, and Pace Analysis Tool.

Excluded from phase 1:

- Data download pipelines or network pulls.
- Export Sales, PSD, WASDE, NASS, Hybrid, or Census source integrations as data sources.
- Notes UI, Notes persistence, Notes server observers, and Notes validation.
- Census Corrections.
- Surfacing future feature tabs in the UI.
- Rebuilding the original almond app.

## Source-Of-Truth Ledger Contract

- Treat this file as the implementation source of truth from the first edit onward.
- Update this plan after every step, tranche, source edit group, failed attempt, failed validation, blocker, changed assumption, rejected approach, successful validation, and final closeout.
- Record concise command lines or validation names and important `KEY=VALUE` evidence where practical.
- Do not create a paired `_results.md` file unless explicitly requested.
- During implementation chat, respond code-only without explanation. The detailed progress record belongs in this markdown file.
- After implementation completes, provide a short chat summary only.
- Keep the Step Ledger, Implementation Plan, Verification/Validation Targets, Decisions, Bugs / Rejected Approaches, Blockers, Follow-Up Avoidance Review, Closeout Checklist, and Summary synchronized.

## Critical Audit Findings

- Existing `VP Clone/Input/veg-trade-data.csv` must be preserved. Do not recreate or overwrite the VP root.
- The VP CSV is large, so implementation must use large-file-friendly readers and avoid editor read tools for the full file.
- Copied almond startup code initializes paths and may source helpers for disabled source families before UI/server gates run. VP must prune or gate disabled-source startup work rather than copy unused Export Sales/PSD/WASDE code just to satisfy startup.
- Existing server modules contain many direct checks and fallbacks for `export_sales`, `census`, `hybrid`, `psd`, `wasde`, and `nass`. VP must route retained generic logic to `vp_trade` and remove old active source fallbacks.
- Removing the visible Data Source dropdown is not enough. Launch-critical paths must either receive a hidden initialized `data_source_choice = vp_trade` or use safe source helpers that default to `vp_trade`.
- Existing trade-flow logic is source-specific (`census_trade_flow_choice` and `hybrid_trade_flow_choice`). VP needs explicit `vp_trade_flow_choice` routing or a tested compatibility alias.
- `CommodityDetail` alone may collide across `Group`, `Subgroup`, `MarketSegment`, or `CommodityName`; submitted commodity values must be stable composite keys.
- Month order must be materialized as a stable commodity-specific 12-period calendar from the CSV month field and `MarketYear`, with override support for ambiguous cases. The source CSV uses `MonthNumber`; the adapter must accept this alias and normalize it into the app-facing month field.
- World rows should use the CSV `World` row when available, normalized to internal `GRAND_TOTAL`. Derived World totals should remain fallback/diagnostic only.
- VP value metrics must use value conversion, not quantity or basis conversion.
- VP volume and rate units are mixed: the CSV includes `Thousand pounds`, `Thousand gallons`, `Dollars per pound`, and `Dollars per gallon`. Volume conversion must branch by `UnitDesc`; do not blindly convert all Volume rows from thousand pounds to metric tons.
- Basis UI is removed, but basis conversion must also be bypassed or proven identity for `vp_trade`.
- Notes must be removed entirely.
- Custom type and custom country builders should be retained under VP labels, VP scopes, and VP persistence namespaces.
- Unknown custom scopes must not normalize back to `export_sales`.
- Blank or NA Group/Subgroup/MarketSegment values must be normalized to stable sentinels with readable labels.
- Cache keys must include all VP filter dimensions and artifact/month-calendar signatures.
- Projection and figure helpers must use commodity-specific calendars rather than hardcoded monthly assumptions.

## Guardrails

- Preserve the input CSV.
- Keep source changes under `VP Clone` unless editing root Code Review plans or reading root almond templates.
- Treat root almond files as read-only templates unless a deliberate shared-core edit is separately justified.
- Prefer pruning unused source-integration code over carrying disabled source-family dependencies into VP.
- Keep future feature-tab extension seams documented, but do not surface those tabs in phase 1.
- Do not retain Census Corrections.
- Remove Notes rather than hiding it.
- Keep custom type/custom country builder functionality and validate it against VP data.
- Keep implementation focused on Current vs. Historical launch and behavior.
- Update this plan before moving to the next tranche.

## Potential Blockers

- The large VP CSV may have unexpected schema, blank category fields, inconsistent units, or missing World rows.
- Startup may fail if copied `global.R` expects disabled-source helper files or artifacts.
- Custom builder formulas may depend on old commodity/country assumptions and need VP-specific parsing scope.
- Existing projection code may assume fixed 12-month behavior or rice/export-sales metrics.
- Shiny browser harnesses may be timing-sensitive.
- Missing R packages or local environment configuration may block live app smoke tests.

## Step Ledger

| Step | Work | Status | Notes |
|---|---|---|---|
| 1 | Create VP directory scaffold and source-of-truth plan. | Complete | Created VP scaffold directories while preserving `VP Clone/Input/veg-trade-data.csv`. Created this plan. |
| 2 | Validate setup gate before app behavior edits. | Complete | Setup validation passed: `VP_SETUP_GATE_STATUS=True`, no missing required directories, input CSV exists, and no required plan sections are missing. |
| 3 | Audit VP CSV schema and values. | Complete | `data.table::fread()` audit passed with `MonthNumber` as the month-column alias. CSV has 725,068 rows, 13 columns, Export/Import trades, UnitType values `Unit value|Value|Volume`, UnitDesc values `Dollars per gallon|Dollars per pound|Thousand dollars|Thousand gallons|Thousand pounds`, 94,758 World rows, no blank Group/Subgroup/MarketSegment/CommodityName/CommodityDetail/GeographicDesc values, month values 1-12, MarketYear 2017-2026, 222 commodity keys, 213 keys with at least one complete 12-month year, and 9 keys without a complete year. |
| 4 | Scaffold VP app runtime. | Complete | Added VP root sentinel, VP-owned utilities, `Almond_Analysis_Shiny_VP.R`, `app.R`, and app source files under `VP Clone/Programs/app_source`. |
| 5 | Build VP contract/config. | Complete | Runtime config is VP-local: `vp_trade` artifact only, app labels, cache version, custom builder files, fixed Monthly frequency, and only the Current vs. Historical tab visible. |
| 6 | Build VP CSV adapter and processed artifacts. | Complete | `vp_build_trade_artifact()` normalizes `MonthNumber`, creates composite commodity keys, infers commodity calendars, branches pound/gallon volume conversion, builds cumulative value/volume, writes artifact/metadata, validates source currentity, and builds with zero warnings. |
| 7 | Add `Master_VP.R` launcher. | Complete | `Master_VP.R` rebuilds local artifacts and launches the VP app interactively; noninteractive validation rebuilt 346,741 processed rows. |
| 8 | Implement VP UI and server routing. | Complete | Replaced Data Source with Group/Subgroup/Market Segment/Commodity controls, fixed Data Frequency at Monthly, removed Basis and Notes, retained Quantity Unit and Value Unit, retained custom type and country builders, and wired Current vs. Historical plot/table routing to `vp_trade`. |
| 9 | Implement cache/projection/figure calendar strategy. | Complete | VP cache version includes builder, source CSV signature, and calendar signature. Plot month order uses commodity calendars from the artifact. Projection remains out of Unit Value/rate paths. |
| 10 | Prune unused source integrations and future visible tabs. | Complete | VP app code has no Notes, Census Corrections, Export Sales, PSD, WASDE, or Basis references. Future feature-tab seams are documented in `vp_app_config.R` but only Current vs. Historical is visible. |
| 11 | Run validation harnesses and live smoke. | Complete | Ran artifact/source harness, launcher validation, app source validation, live HTTP smoke, and forbidden-source scan. |
| 12 | Final closeout. | Complete | Final ledger update complete; final chat summary pending. |

## Implementation Plan

1. Setup and ledger gate.
   - Preserve `VP Clone/Input/veg-trade-data.csv`.
   - Create missing VP directories.
   - Create this source-of-truth plan.
   - Validate required sections and source-of-truth rules.

2. CSV audit.
   - Read only headers and summarized samples with a large-file-friendly R/data.table approach.
   - Validate required columns: `Trade`, `GeographicDesc`, `Year`, month column (`MonthNum` or `MonthNumber`), `MarketYear`, `Group`, `Subgroup`, `MarketSegment`, `CommodityName`, `CommodityDetail`, `UnitType`, `UnitDesc`, and `Amount`.
   - Record unit coverage, trade-flow coverage, blank category fields, World rows, and month-calendar patterns.

3. Scaffold VP app runtime.
   - Copy/adapt the minimal almond runtime needed for Current vs. Historical and custom builders.
   - Add VP root sentinel, entrypoint, options/env prefixes, cache/custom namespace isolation, and app source structure.
   - Remove or gate startup work for Export Sales, PSD, WASDE, and other absent sources.

4. VP contract and metadata design.
   - Define `vp_trade` as the only active source family.
   - Define app labels, source profile, artifacts, feature flags, tab allowlist, and custom builder namespaces.
   - Exclude Notes and Census Corrections.
   - Document future VP feature-tab extension seams.

5. VP adapter/artifact builder.
   - Normalize trade flow, geography, category fields, commodity keys, month calendars, units, and metrics.
   - Build app-facing monthly and cumulative volume/value metrics.
   - Preserve Unit Value internally only if safe; keep it out of cumulative/projection paths unless a rate profile is implemented.
   - Write processed artifacts and metadata/currentity signatures.

6. Master launcher.
   - Create `Master_VP.R` and VP launcher utilities.
   - Support `vp_trade`, `metadata`, `all`, and `none` update choices.
   - Rebuild local artifacts only; do not download data.

7. UI/server implementation.
   - Replace Data Source with Group/Subgroup/MarketSegment.
   - Add explicit VP Trade Flow input routing.
   - Fix source/frequency defaults for hidden/internal inputs.
   - Remove Notes.
   - Retain and relabel custom type/custom country builders for VP.
   - Remove Basis UI and enforce identity/no basis conversion.

8. Cache/projection/figure implementation.
   - Include all VP filters, artifact signatures, and month-calendar signatures in cache keys.
   - Generalize projection helpers to commodity-specific calendars.
   - Ensure figure labels, hover text, historical averages, and projections use the same calendar contract.

9. Pruning and future-tab seam review.
   - Ensure active startup/server paths do not depend on Export Sales/PSD/WASDE/Notes/Census Corrections.
   - Keep future VP feature-tab seams documented but hidden.

10. Validation and closeout.
   - Run focused harnesses, parse checks, live browser smoke if available, and manual inspection.
   - Update this plan with evidence, bugs, rejected approaches, blockers, residual risks, and final Summary.

## Verification / Validation Targets

- Setup gate: VP directories exist, input CSV preserved, and this plan contains all required sections.
- Schema audit: required columns, month-column alias, unit types/descriptions, trade flows, World rows, blank category values, and month-order patterns recorded.
- Artifact builder: processed artifact and metadata written; currentity detects missing/stale/incompatible CSV.
- Adapter contract: app-facing data has unique keys, correct cumulative math, correct World mapping, and nonempty defaults.
- Master launcher: no-update, `vp_trade`, metadata, all, and launch-disabled modes work without network pulls.
- Startup dependency: VP startup does not require absent Export Sales/PSD/WASDE support files.
- UI contract: Current vs. Historical only visible; Notes absent; Census Corrections absent; future feature tabs hidden; Group/Subgroup/MarketSegment and VP Trade Flow controls work.
- Custom builders: custom type and custom country builders use VP labels, VP choices, VP namespaces, and no export-sales fallback.
- Cache contract: dropdown changes, artifact rebuilds, and month-calendar changes invalidate relevant caches.
- Projection/figure contract: at least two commodity calendars produce correct x-axis order and projection endpoints.
- Unit conversion: pound-based volume, gallon-based volume, value, and unit-value/rate handling are correct; Unit Value is not accumulated or projected unless explicitly enabled.
- Browser smoke: default launch renders nonempty plot/table and no `Insufficient data for this selection`.
- Pruning/static scan: active VP startup/server paths do not reference Export Sales, PSD, WASDE, Notes, Census Corrections, or visible future-tab outputs except explicitly justified generic helpers.
- Closeout: follow-up avoidance review and lay Summary are complete.

## Relevant Files

- `VP Clone/Input/veg-trade-data.csv` - refreshed monthly VP source CSV; must be preserved.
- `VP Clone` - new VP app root.
- `VP Clone/Almond_Analysis_Shiny_VP.R` - VP Shiny entrypoint.
- `VP Clone/Master_VP.R` - VP local artifact rebuild and launch entrypoint.
- `VP Clone/app.R` - VP app runner for `shiny::runApp()`.
- `VP Clone/Programs/vp_data_utils.R` - VP CSV adapter, artifact builder, conversion helpers, currentity checks, and custom builder persistence.
- `VP Clone/Programs/app_source/global.R` - VP app startup globals.
- `VP Clone/Programs/app_source/ui.R` - VP Current vs. Historical UI.
- `VP Clone/Programs/app_source/server.R` - VP Current vs. Historical server logic.
- `VP Clone/System/Config/vp_app_config.R` - VP source family, visible tab, future tab, and custom-builder config.
- `VP Clone/System/Testing/Harnesses/vp_smoke_checks.R` - repeatable VP artifact/source smoke harness.
- `VP Clone/Code Review/2026-07-21_vp_current_historical_clone_plan.md` - this source-of-truth implementation ledger.
- `Almond_Analysis_Shiny.R` - almond entrypoint template.
- `Master.R` - almond master launcher template.
- `Programs/master_launch_utils.R` - almond launcher utility template.
- `Programs/app_source/global.R` - almond startup/template surface to adapt carefully.
- `Programs/app_source/server/01_state_and_custom_types.R` - commodity/custom type/custom country state template.
- `Programs/app_source/server/02_partner_and_notes.R` - controls/units/metrics template; Notes must be removed in VP.
- `Programs/app_source/server/03_core_reactives_and_ui.R` - country/filter/projection support template.
- `Programs/app_source/server/04_comparison_plots.R` - Current vs. Historical plot template.
- `Programs/shared_core/commodity_contract_utils.R` - contract helper template.
- `System/Config/commodity_contract.R` - almond contract template.

## Decisions

- Use one Code Review plan file as the implementation ledger; no paired results file unless requested.
- Preserve the existing VP input CSV.
- Phase 1 shows only Current vs. Historical.
- Keep extension seams for future VP versions of Historical Trendlines, Map, Monthly Heatmap, Data, Custom Comparison Tool, Market Year Comparison Tool, and Pace Analysis Tool.
- Exclude Census Corrections.
- Remove Notes.
- Retain custom type and custom country builders.
- Do not keep Export Sales, PSD, or WASDE source-integration code in active VP startup/server paths.
- Use local artifact rebuilds only; no download pipeline.
- Treat CSV `MarketYear` as authoritative.
- Accept `MonthNumber` as the observed VP CSV month-column name and normalize it into app-facing month fields.
- Fill blank CSV `MarketYear` values from `Year` before calendar inference so legacy monthly rows remain usable without warnings.
- Use source CSV `World` rows whenever available.
- Remove Basis UI and make basis conversion identity/bypassed for VP.
- Keep Unit Value out of cumulative/projection paths until a safe rate profile exists.

## Bugs / Rejected Approaches

- Setup validation first attempted from the active handoff memory with an overlong memory range before implementation; the durable implementation setup gate used the Code Review plan and filesystem checks instead.
- First artifact build failed because `fifelse()` was called without a `data.table::` namespace; fixed by using `data.table::fifelse()`.
- Artifact build then emitted 63 `no non-missing arguments to max` warnings from rows with blank `MarketYear`; fixed by filling missing `MarketYear` from `Year` before calendar inference.

## Blockers

- None active yet.

## Evidence Log

- 2026-07-21 Setup scaffold: created VP-specific directories under `VP Clone` while preserving existing `VP Clone/Input/veg-trade-data.csv`.
- 2026-07-21 Setup gate validation command emitted `VP_SETUP_GATE_STATUS=True`, `VP_SETUP_GATE_INPUT_CSV_EXISTS=True`, and no missing directory or section values.
- 2026-07-21 CSV schema audit first failed because the plan expected `MonthNum` while the CSV header contains `MonthNumber`; rerun accepted `MonthNumber` as the alias and emitted `VP_CSV_AUDIT_REQUIRED_STATUS=TRUE`.
- 2026-07-21 CSV audit evidence: 725,068 rows; 13 columns; trades `Export|Import`; UnitType `Unit value|Value|Volume`; UnitDesc `Dollars per gallon|Dollars per pound|Thousand dollars|Thousand gallons|Thousand pounds`; World rows 94,758; no blank category/geography fields; months 1-12; MarketYear 2017-2026; 222 commodity keys; 213 keys with complete-year coverage; 9 keys without complete-year coverage.
- 2026-07-21 VP utility source validation emitted `VP_DATA_UTILS_SOURCE_STATUS=TRUE`.
- 2026-07-21 VP artifact validation emitted `VP_ARTIFACT_BUILD_STATUS=TRUE`, `VP_ARTIFACT_WARNING_COUNT=0`, `VP_ARTIFACT_ROWS=346741`, and `VP_ARTIFACT_MONTH_COLUMN=MonthNumber`.
- 2026-07-21 VP app source validation emitted `VP_APP_SOURCE_STATUS=TRUE`; `VP Clone/app.R` source validation emitted `VP_APP_R_SOURCE_STATUS=TRUE`.
- 2026-07-21 `Master_VP.R` noninteractive validation rebuilt the artifact and printed `VP processed artifact rebuilt: 346741 rows`.
- 2026-07-21 live Shiny smoke on `http://127.0.0.1:4747` emitted `VP_HTTP_STATUS=200`, `VP_HTTP_HAS_TITLE=True`, and `VP_HTTP_HAS_MONTHLY=True`.
- 2026-07-21 repeatable smoke harness emitted `VP_SMOKE_ARTIFACT_BUILD=TRUE`, `VP_SMOKE_WARNING_COUNT=0`, `VP_SMOKE_ROWS=346741`, `VP_SMOKE_MONTH_COLUMN=MonthNumber`, `VP_SMOKE_CURRENTITY=TRUE`, and `VP_SMOKE_APP_SOURCE=TRUE`.
- 2026-07-21 forbidden-source scan under `VP Clone/**` returned no matches for Notes/floating notes, Census Corrections, Export Sales, PSD, WASDE, or Basis.
- 2026-07-21 future-tab seam scan confirmed `vp_app_config.R` contains `source_family = "vp_trade"`, visible `current_historical`, and future tab IDs for trendlines, map, heatmap, data, custom comparison, market-year comparison, and pace analysis.
- 2026-07-21 restarted latest VP app on `http://127.0.0.1:4747`; HTTP smoke again emitted `VP_HTTP_STATUS=200`, `VP_HTTP_HAS_TITLE=True`, and `VP_HTTP_HAS_MONTHLY=True`.
- 2026-07-21 editor diagnostics reported no errors for the new VP entrypoint, launcher, utility, UI, and server files.

## Follow-Up Avoidance Review

Initial prevention gates carried into implementation:

- Fresh-launch defaults must be proven in a clean session.
- Artifact and metadata freshness must be proven after rebuild.
- Dropdown labels and submitted values must both be tested.
- Reset/carryover state must be tested separately from first-entry defaults.
- Rendered browser checks must confirm the actual UI, not just source contracts.
- Cache keys must include every new VP filter dimension.
- Source-routing scans must prove old source fallbacks are removed or inactive.
- Notes and Census Corrections must be absent.
- Future feature-tab seams must be documented but not visible.

## Closeout Checklist

- [x] VP directory scaffold exists and input CSV is preserved.
- [x] This plan has been updated after each tranche so far.
- [x] VP CSV schema audit completed.
- [x] VP artifacts and metadata build successfully.
- [x] `Master_VP.R` rebuild/launch workflow works.
- [x] Current vs. Historical UI renders with VP controls.
- [x] Notes removed.
- [x] Custom type and custom country builders retained and validated.
- [x] Export Sales/PSD/WASDE active startup/server paths removed or gated.
- [x] Future feature-tab seams documented and hidden.
- [x] Census Corrections excluded.
- [x] Focused harnesses pass.
- [x] Browser/manual smoke completed or blocker recorded.
- [x] Bugs, rejected approaches, blockers, and residual risks documented.
- [x] Follow-Up Avoidance Review completed.
- [x] Final Summary completed.

## Summary

The VP clone is implemented as a smaller, VP-specific Shiny app under `VP Clone`. It preserves the monthly CSV input, rebuilds fast local R artifacts from that CSV, and launches through `Master_VP.R` or `app.R`. The first screen is the VP Current vs. Historical tab with Group, Subgroup, Market Segment, Commodity, Trade Flow, Country, Metric, fixed Monthly frequency, Quantity Unit, Value Unit, and historical-year controls.

The adapter handles the real CSV schema, including `MonthNumber`, blank `MarketYear` fallback, World rows, pound and gallon volumes, value rows, and unit-value rows. Notes, Census Corrections, Export Sales, PSD, WASDE, and Basis are absent from VP runtime code. Future VP tabs are documented as config seams but are not visible.

Validation passed for artifact rebuild/currentity, app source, launcher rebuild, forbidden-source scan, and a live HTTP smoke test. No active blockers are present.
