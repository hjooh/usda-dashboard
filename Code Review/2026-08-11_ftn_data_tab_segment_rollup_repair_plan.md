# Plan: FTN Data Tab Segment Rollup Repair and Publish Variable Validation

Repair VP Trade Data-tab row-scope label fidelity for selected Market Segment plus Type = All contexts, validate rollup correctness through gated probes, and add a CSV-export-only Variable column for Data-tab publishes. This plan is the implementation source of truth for this tranche and must be updated after every tranche with status, commands, probe evidence, failed attempts, blockers, rejected approaches, and final lay summary.

## Handoff Status

- Status: Paused Before Gate B (checkpoint requested); Gate A has been reopened, reworked, and now passes with source-bounded evidence.
- Prior handoff context: repo-memory handoff for Data-tab segment rollup fidelity is accepted and recentered into this ledger.
- Active source-of-truth ledger: this file, `Code Review/2026-08-11_ftn_data_tab_segment_rollup_repair_plan.md`.
- Supersession rule: for this tranche, use this file instead of session-only notes as the execution ledger.
- First implementation action completed: the source-of-truth ledger is created and seeded with probe standards, scope boundaries, gates, and step ledger.
- Primary stop condition: if Gate A detects artifact rollup leakage or source-bounded Type = All mismatches for additive metrics, stop display-transform edits and re-scope to builder/filter remediation.
- Current pause point: stop before Gate B authoring/execution. Resume boundary is Step 5.
- Gate A latest run artifacts:
   - `Logs/ftn_probe_runs/ftn_data_tab_gateA_rollup_validation_20260811T190420Z_summary.csv`
   - `Logs/ftn_probe_runs/ftn_data_tab_gateA_rollup_validation_20260811T190420Z_checks_sample.csv`
   - anomaly path empty for latest passing run.

## Source-of-Truth Ledger Contract

- Update this file before and after each tranche.
- Record exact commands run, probe outputs, artifact paths, and pass/fail markers.
- Record failed attempts, rejected fixes, and blockers without deletion; keep append-only history.
- If a gate fails, mark status Not Ready for downstream steps and document the remediation path.
- Keep one active ledger only for this tranche; if a daughter plan is created later, link it here and state pause/resume conditions.

## Scope Boundaries

- Allowed: Data-tab label-fidelity repair for VP Trade selected-segment Type = All contexts, Gate A and Gate B validation probes, and Data-tab CSV-export-only Variable column append with explicit metric-label context.
- Allowed: focused helper usage from existing server files where required for explicit metric label computation.
- Not allowed: metric math or conversion-policy changes, broad rollup artifact rebuild redesign, source-key changes, table-schema changes in on-screen Data tab, control-ID changes, or global writer-contract changes unless a documented blocker is proven.
- Out of scope unless explicitly expanded: Market Year Comparison Tool export path.

## Critical Existing Facts

- Current risky remap path is in `Programs/app_source/server/05_trend_and_heatmap.R` where native hierarchy lookup is keyed by Trade + CommodityName + CommodityDetail and can collapse hierarchy values.
- Known overwrite hotspot is the VP Data-tab remap block in `data_tab_dataset()` where Group/Subgroup/MarketSegment are coalesced from native lookup.
- `publish_data_tab_dataset()` currently publishes Data-tab output without a CSV-only Variable column.
- Explicit metric labeling helpers already exist in `Programs/app_source/server/02_partner_and_notes.R` through `effective_trade_flow_for_source()` and `get_metric_label_for_context()`.
- Artifact for rollup checks is `System/Processed Data/vp_trade_monthly_pre.rds`.
- Existing FTN validated probes already run on this infrastructure and are the required architecture templates for new probes.

## Probe Modeling Standard

All new probes in this tranche must model the validated FTN AP pattern established after 2026-08-10.

### Primary Templates

- `System/Testing/ftn_validated_unit_display_ui_guardrail.R`
- `System/Testing/ftn_validated_calendar_signature_matrix.R`

### Supporting Conventions

- `System/Testing/ftn_validated_shiny_smoke.R`
- `System/Testing/ftn_validated_probe_artifact_currentity.R`
- `System/Testing/ftn_validated_unit_invariant_scan.R`

### Required Probe Architecture

1. Bootstrap determinism:
   - Resolve repo root by marker discovery, not hardcoded workstation paths.
   - Gate required dependencies early with explicit stop messages.
   - Use deterministic launch retries and required-control polling with explicit timeout ceilings.
2. Deterministic interaction:
   - Use `set_inputs(wait_ = FALSE)` with explicit value-confirmation loops.
   - Set control order as trade/source/frequency first, then hierarchy cascade, then type/country/metric.
   - Do not assert state before control confirmation and data readiness checks.
3. Evidence contract:
   - Emit machine-parseable progress checkpoints.
   - Write timestamped summary/check/failure artifacts under `Logs/ftn_probe_runs/`.
   - Return strict non-zero exit on failed assertions.
4. Assertion contract:
   - Fail fast with diagnostic payload that identifies context and mismatch details.
   - Include row counts/context counts/anomaly counts where applicable.

### Anti-Patterns To Avoid

- Hardcoded local paths or legacy VP clone path assumptions.
- One-shot no-poll assertions immediately after control sets.
- Log-only scripts without structured summary/check/failure artifacts.
- Wait-only synchronization that does not confirm effective control values.

## Gate Framework

- Gate A (artifact/pre-transform rollup correctness): artifact concrete selected-segment `CommodityDetail = All` rows must match raw source detail-row sums at the same Trade/Group/Subgroup/MarketSegment/CommodityName/country/market-year/month scope after applying builder-equivalent source-unit normalization and source market-year parsing. Broader totals with MarketSegment removed are computed as leakage guards; exact-scope mismatches, missing source matches, or matches to broader cross-segment totals fail the gate.
- Gate B (post-transform Data-tab label fidelity): selected segment plus Type = All outputs retain row-scope MarketSegment and approved CommodityDetail semantics; no semicolon-joined MarketSegment labels.
- Gate C (publish contract): Data-tab CSV publish adds Variable as final column exactly once; on-screen Data-tab schema remains unchanged; row counts and Amount values are unchanged for baseline contexts.

## Implementation Steps

### 1. Create source-of-truth ledger

- Create this file as the active execution ledger for this tranche.
- Dependency: none.

### 2. Capture baseline context and publish shape

- Baseline scenario: VP Trade, Export, Market Segment = Dried, Commodity = Apples, Type = All, Variable = Accumulated Exports.
- Capture row count, Amount values, MarketSegment labels, CommodityDetail labels, and current published CSV column set.
- Dependency: step 1.

### 3. Author Gate A probe (artifact rollup leakage)

- Add a new validated probe under `System/Testing/` using FTN probe architecture standards from this plan.
- Validate additive metrics only: `ytd_exports`, `monthlyexports`, `ytd_value`, `monthlyvalue`.
- Required keys: Trade, Group, Subgroup, MarketSegment, CommodityName, country, market_year, analysis_month.
- Include segment-leakage comparison against broader totals with MarketSegment removed.
- Dependency: step 2.

### 4. Run Gate A and ledger results

- Execute Gate A probe with explicit Rscript command.
- If Gate A fails, stop downstream label edits and document remediation scope.
- Dependency: step 3.

### 5. Author Gate B probe (post-transform label fidelity)

- Add a new validated probe under `System/Testing/` using FTN probe architecture standards.
- Exercise transformed Data-tab output for selected-segment Type = All contexts.
- Assert MarketSegment equals selected segment, CommodityDetail semantics are preserved, and semicolon-joined MarketSegment does not appear.
- Dependency: steps 2 and 4 passing.

### 6. Run Gate B and ledger results

- Execute Gate B probe and record structured output artifacts.
- Dependency: step 5.

### 7. Implement Data-tab label-fidelity repair

- Modify `Programs/app_source/server/05_trend_and_heatmap.R` in `data_tab_dataset()` VP branch.
- Preserve row-scope hierarchy labels after rollup-token normalization.
- Limit native lookup fallback to true missing-label cases.
- Dependency: Gate A pass and Gate B evidence.

### 8. Implement CSV-export-only Variable column

- Modify `publish_data_tab_dataset()` in `Programs/app_source/server/05_trend_and_heatmap.R`.
- Append `Variable` as final publish column only.
- Compute label explicitly via `get_metric_label_for_context()` with explicit source/trade-flow context resolution.
- Dependency: step 7 or in parallel once Gate A passes.

### 9. Author and run Gate C publish verification probe

- Add probe coverage for CSV-only Variable behavior and unchanged on-screen schema.
- Assert Variable appears exactly once at final column position in Data-tab CSV output.
- Assert baseline row counts and Amount values remain unchanged for baseline scenario.
- Dependency: step 8.

### 10. Parse and regression checks

- Parse-check edited server files.
- Run focused regressions: artifact currentity/smoke probes and relevant FTN validated probes.
- Dependency: steps 7-9.

### 11. Manual UI verification

- Validate Export and Import selected-segment Type = All contexts.
- Validate All Market Segments behavior for no unintended cross-segment list labeling.
- Confirm no numeric drift from baseline scenario.
- Dependency: step 10.

### 12. Final go/no-go and closeout

- Go only if Gates A, B, and C pass and regression checks are acceptable.
- If any gate fails, keep status Not Ready and ledger blocker remediation.
- Add final plain-language summary with scope, outcomes, blocker work, and deferred items.
- Dependency: step 11.

## Relevant Files

- `Code Review/2026-08-11_ftn_data_tab_segment_rollup_repair_plan.md` - active source-of-truth implementation ledger.
- `Code Review/2026-08-10_ftn_visualization_unit_display_guardrail_plan.md` - upstream FTN execution-ledger conventions and context.
- `Code Review/2026-08-10_ftn_rollup_all_excluding_juice_correction_plan.md` - pass/fail iteration and blocker logging model.
- `Code Review/2026-08-10_ftn_conversion_plan.md` - FTN conversion-era acceptance and closeout conventions.
- `Programs/app_source/server/05_trend_and_heatmap.R` - primary implementation target for label remap and publish payload.
- `Programs/app_source/server/02_partner_and_notes.R` - explicit metric-label context helpers.
- `System/Processed Data/vp_trade_monthly_pre.rds` - Gate A artifact source.
- `System/Testing/ftn_validated_unit_display_ui_guardrail.R` - primary probe template architecture.
- `System/Testing/ftn_validated_calendar_signature_matrix.R` - primary multi-surface probe template architecture.
- `System/Testing/ftn_validated_shiny_smoke.R` - supporting deterministic smoke-probe conventions.
- `System/Testing/ftn_validated_probe_artifact_currentity.R` - supporting gate conventions.
- `System/Testing/ftn_validated_unit_invariant_scan.R` - supporting artifact-summary conventions.
- `Logs/ftn_probe_runs/` - canonical probe artifact destination.

## Acceptance Criteria

1. This plan file is the active source-of-truth ledger for the tranche and is updated after every tranche.
2. Probe modeling standards are explicit and aligned to validated FTN AP probe templates.
3. Gate A has zero additive-metric segment-leakage anomalies for tested contexts.
4. Gate B confirms row-scope Data-tab labels for selected-segment Type = All contexts.
5. Gate C confirms Data-tab CSV Variable final-column behavior with unchanged on-screen Data-tab schema.
6. Baseline row counts and Amount values remain unchanged for validated contexts.
7. Regression/smoke checks pass or unchanged pre-existing failures are explicitly documented.
8. Final ledger includes failed attempts, blockers, rejected approaches, and lay summary.

## Critical Guardrails

- Do not change metric math unless Gate A proves artifact-level defects that require explicit re-scope.
- Do not change on-screen Data-tab schema while adding publish-only Variable.
- Do not modify global publish-writer contracts unless a blocker is proven.
- Do not broaden scope into unrelated export paths.
- Do use deterministic probe architecture and structured artifacts for every new probe in this tranche.

## Implementation Status

| Step | Status | Notes |
| --- | --- | --- |
| 1. Create source-of-truth ledger | Complete | Created this plan as the active execution ledger and seeded guardrails/gates/probe standards. |
| 2. Capture baseline context and publish shape | Complete | Baseline context and publish shape were captured through Gate C pre/post on-screen Data-tab payload checks plus user-validated manual publish-output experiments for the Step 8 contract. |
| 3. Author Gate A probe | Complete | Added `System/Testing/ftn_validated_data_tab_gateA_rollup_validation.R` modeled on validated FTN probe architecture. |
| 4. Run Gate A | Complete | Reopened and reworked after review. Latest source-bounded run reports `FTN_DATA_TAB_GATEA_STATUS=PASS`, `FTN_DATA_TAB_GATEA_CHECKED_CONTEXTS=355051`, `FTN_DATA_TAB_GATEA_TOTAL_ANOMALIES=0`, and `FTN_DATA_TAB_GATEA_TOTAL_LEAKAGE_MATCHES=0`. |
| 5. Author Gate B probe | Complete | Added `System/Testing/ftn_validated_data_tab_gateB_label_fidelity.R` using FTN validated probe architecture, deterministic set/confirm control driving, and structured artifacts. |
| 6. Run Gate B | Complete | Initial revised Gate B run failed as expected on semicolon-joined MarketSegment labels; after Step 7 repair, Gate B passed with `FTN_DATA_TAB_GATEB_STATUS=PASS`, `FTN_DATA_TAB_GATEB_TOTAL_CHECKS=26`, `FTN_DATA_TAB_GATEB_FAILURE_COUNT=0`. |
| 7. Implement Data-tab label-fidelity repair | Complete | Patched `data_tab_dataset()` VP hierarchy remap in `Programs/app_source/server/05_trend_and_heatmap.R` to preserve row-scope labels and use native lookup only as fallback for missing values. |
| 8. Implement CSV-export-only Variable column | Complete | Updated `publish_data_tab_dataset()` to append `Variable` exactly once as the final publish column, with explicit context-resolved metric labeling via `get_metric_label_for_context(...)` and `effective_trade_flow_for_source(...)`; on-screen Data-tab schema unchanged. |
| 9. Author and run Gate C probe | Complete (manual-evidence accepted) | Added `System/Testing/ftn_validated_data_tab_gateC_publish_contract.R` and executed multiple runs; automated probe remains blocked on publish-file detection (`publish_path` empty), but manual experiment validation confirmed published datasets follow the intended Gate C contract. |
| 10. Parse and regression checks | Complete | Parse checks passed (`Programs/app_source/server/05_trend_and_heatmap.R`, `Programs/app_source/server/02_partner_and_notes.R`); regression probes passed: artifact currentity (`FTN_ARTIFACT_PROBE_STATUS=PASS`), shiny smoke (`FTN_SHINY_SMOKE_STATUS=PASS`), calendar signature matrix (`FTN_CAL_MATRIX_STATUS=PASS`), and unit invariant scan (`FTN_UNIT_INVARIANT_STATUS=PASS`, summary `Logs/ftn_probe_runs/ftn_unit_invariant_scan_20260811T211353Z_summary.csv`). |
| 11. Manual UI verification | Complete | User-reported manual experiments validated published dataset behavior for the current tranche scope. |
| 12. Final go/no-go and closeout | Complete | GO decision recorded for tranche scope. Gate A and Gate B are automated PASS, Step 8 behavior is accepted via hybrid evidence (automated on-screen invariance plus manual publish-output validation), and Step 10 regression coverage is PASS. |

## Validation Targets

- Parse check command:
  - `C:/Program Files/R/R-4.5.1/bin/Rscript.exe --vanilla -e "tryCatch({ parse(file='Programs/app_source/server/05_trend_and_heatmap.R'); parse(file='Programs/app_source/server/02_partner_and_notes.R'); cat('parse_ok\\n') }, error=function(e){ cat(conditionMessage(e), '\\n'); quit(status=1) })"`
- Regression probes:
  - `C:/Program Files/R/R-4.5.1/bin/Rscript.exe --vanilla System/Testing/ftn_validated_probe_artifact_currentity.R`
  - `C:/Program Files/R/R-4.5.1/bin/Rscript.exe --vanilla System/Testing/ftn_validated_shiny_smoke.R`
  - `C:/Program Files/R/R-4.5.1/bin/Rscript.exe --vanilla System/Testing/ftn_validated_calendar_signature_matrix.R`
  - `C:/Program Files/R/R-4.5.1/bin/Rscript.exe --vanilla System/Testing/ftn_validated_unit_invariant_scan.R`

## Bugs, Blockers, Failed Attempts, Rejected Approaches

- Active blockers:
   - No blocking tranche defects remain for accepted scope.
   - Open follow-up (non-blocking): Gate C shinytest publish-file detection is still unreliable in-session and should be improved before using Gate C as a strict automation gate.
- Failed attempts and fixes:
   - Initial Gate A execution failed due `%chin%` operator usage in script context; corrected to `%in%`.
   - Second Gate A execution failed due data.table row-selector usage on bare logical symbols; corrected to explicit boolean column comparisons.
   - First Gate A criterion treated all constituent mismatches as blocking and produced high anomaly counts (`84178`), which was too strict for sparse-detail contexts; revised to blocking-vs-diagnostic split while preserving full anomaly artifact output.
   - Code review found the blocking-vs-diagnostic Gate A pass was not convincing against the original Gate A claim, so Gate A was reopened before Gate B.
   - First source-bounded Gate A rewrite incorrectly assumed raw source contained `CommodityDetail = All` rows; source has detail rows only, so the probe was corrected to sum source detail rows within the selected segment.
   - Second source-bounded Gate A run compared raw source units directly to artifact metrics and failed due unit-scale mismatch; corrected by applying builder-equivalent source normalization (`Thousand pounds` to metric tons via `Amount * 0.45359237`, gallons via `Amount * 1000`, and `Thousand dollars` via `Amount * 1000`).
   - Third source-bounded Gate A run failed missing-source joins due MarketYear parsing; corrected source `YYYY/YY` strings to artifact ending-year convention (for example `2023/24` -> `2024`).
   - First Gate B run failed due probe-side summary assembly bug (`merge.data.table(..., by = NULL)` requires non-empty join keys); corrected by direct metadata column assignment.
   - Second Gate B run still failed, but only because probe logic assumed Data-tab publish output path behavior; Gate B scope was tightened to read transformed Data-tab rows directly from `raw_data_table` DataTables payload and reserve publish path checks for Gate C.
   - Revised Gate B run produced true product failures: selected-segment contexts showed semicolon-joined `MarketSegment` labels (`Dried; Fresh; Juice` and `Dried; Fresh; Juice; Prepared or preserved`) while other row-scope fields remained correct.
   - Applied Step 7 repair by reversing hierarchy coalesce precedence in VP Data-tab remap so row-scope fallback labels remain authoritative and native lookup is fallback-only for missing labels; subsequent Gate B run passed.
   - Initial Gate C implementation failed to detect publish output files even after publish trigger attempts; checks showed on-screen Data-tab schema and Amount values remained stable while all publish-path assertions failed due empty detected file paths.
   - Gate C was iteratively hardened with fallback publish-trigger strategy and deterministic VP metric-label expectation mapping (`Accumulated Exports` for `ytd_exports`), but publish-file detection still remained empty in probe session and continues as active blocker.
- Rejected approaches (pre-committed):
  - Display-only normalization if Gate A reveals artifact-level leakage.
  - Broad writer-contract changes before proving necessity.
  - Ad-hoc probe scripts without deterministic FTN-style architecture and structured artifacts.

## Tranche Execution Notes

- 2026-08-11: Created source-of-truth ledger and codified mandatory FTN probe-modeling standard for all new probes in this tranche.
- 2026-08-11: Established three-gate validation model (Gate A artifact math, Gate B post-transform labels, Gate C publish contract) and go/no-go dependencies.
- 2026-08-11: Implemented Gate A probe at `System/Testing/ftn_validated_data_tab_gateA_rollup_validation.R` with FTN-style bootstrap, progress markers, structured artifacts, and fail-fast behavior.
- 2026-08-11: Gate A initial runs surfaced script-level defects (`%chin%` and selector scoping), both corrected and revalidated.
- 2026-08-11: Latest Gate A run returned `FTN_DATA_TAB_GATEA_STATUS=PASS`, `FTN_DATA_TAB_GATEA_BLOCKING_ANOMALIES=0`, and diagnostic anomaly artifact output for future interpretation.
- 2026-08-11: Execution paused by request before Gate B authoring/execution.
- 2026-08-11: Gate A evidence reviewed and found insufficient because pass/fail logic had narrowed after diagnostics showed broad mismatches.
- 2026-08-11: Reworked Gate A probe to compare artifact selected-segment `All` rows against raw source detail-row sums at exact segment scope, with builder-equivalent unit normalization, ending-year MarketYear parsing, YTD cumulative reconstruction, and broader cross-segment leakage guards.
- 2026-08-11: Latest reworked Gate A run passed with `FTN_DATA_TAB_GATEA_CHECKED_CONTEXTS=355051`, zero missing-source rows, zero exact-source mismatches, zero YTD mismatches, and zero broader-total leakage matches. Evidence: `Logs/ftn_probe_runs/ftn_data_tab_gateA_rollup_validation_20260811T190420Z_summary.csv`.
- 2026-08-11: Authored Gate B probe `System/Testing/ftn_validated_data_tab_gateB_label_fidelity.R` with FTN-style launch retries, required-control polling, set/confirm loops, row-level Data-tab extraction via DataTables payload, and structured checks/summary/failures artifacts.
- 2026-08-11: Gate B evidence run before code repair failed with `FTN_DATA_TAB_GATEB_STATUS=FAIL`, `FTN_DATA_TAB_GATEB_FAILURE_COUNT=4`, and showed selected-segment `MarketSegment` mismatches (`Dried` expected vs semicolon-joined values) for both export and import contexts. Evidence: `Logs/ftn_probe_runs/ftn_data_tab_gateB_label_fidelity_20260811T194022Z_summary.csv`, `Logs/ftn_probe_runs/ftn_data_tab_gateB_label_fidelity_20260811T194022Z_checks.csv`, `Logs/ftn_probe_runs/ftn_data_tab_gateB_label_fidelity_20260811T194022Z_failures.csv`.
- 2026-08-11: Implemented Step 7 Data-tab repair in `Programs/app_source/server/05_trend_and_heatmap.R` by switching VP hierarchy remap coalesce order (`fallback` first, `native` second) for Group/Subgroup/MarketSegment.
- 2026-08-11: Gate B post-repair rerun passed with `FTN_DATA_TAB_GATEB_STATUS=PASS`, `FTN_DATA_TAB_GATEB_CONTEXT_COUNT=2`, `FTN_DATA_TAB_GATEB_TOTAL_CHECKS=26`, `FTN_DATA_TAB_GATEB_FAILURE_COUNT=0`, `FTN_DATA_TAB_GATEB_FAILURE_ROWS=0`. Evidence: `Logs/ftn_probe_runs/ftn_data_tab_gateB_label_fidelity_20260811T194815Z_summary.csv`, `Logs/ftn_probe_runs/ftn_data_tab_gateB_label_fidelity_20260811T194815Z_checks.csv`.
- 2026-08-11: Gate B confirmation rerun after final probe lint cleanup remained green with `FTN_DATA_TAB_GATEB_STATUS=PASS`, `FTN_DATA_TAB_GATEB_TOTAL_CHECKS=26`, and `FTN_DATA_TAB_GATEB_FAILURE_COUNT=0`. Evidence: `Logs/ftn_probe_runs/ftn_data_tab_gateB_label_fidelity_20260811T195742Z_summary.csv`, `Logs/ftn_probe_runs/ftn_data_tab_gateB_label_fidelity_20260811T195742Z_checks.csv`.
- 2026-08-11: Implemented Step 8 in `publish_data_tab_dataset()` (`Programs/app_source/server/05_trend_and_heatmap.R`) to append a CSV-export-only `Variable` column as the final column position, dedupe pre-existing `Variable` if present, and compute the value from `get_metric_label_for_context(...)` using explicit source/trade-flow context resolved through `effective_trade_flow_for_source(...)`.
- 2026-08-11: Parse validation for Step 8 change passed (`parse(file='Programs/app_source/server/05_trend_and_heatmap.R')` returned `parse_ok`).
- 2026-08-11: Authored Gate C probe `System/Testing/ftn_validated_data_tab_gateC_publish_contract.R` with FTN-style deterministic launch/control driving, direct Data-tab payload capture, dual publish attempts, and structured checks/summary/failure artifacts.
- 2026-08-11: Gate C run `20260811T201759Z` failed (`FTN_DATA_TAB_GATEC_STATUS=FAIL`, `FTN_DATA_TAB_GATEC_TOTAL_CHECKS=31`, `FTN_DATA_TAB_GATEC_FAILURE_COUNT=22`) because publish files were not detected (`publish_path` empty) despite successful pre/post on-screen schema and Amount invariance checks. Evidence: `Logs/ftn_probe_runs/ftn_data_tab_gateC_publish_contract_20260811T201759Z_summary.csv`, `Logs/ftn_probe_runs/ftn_data_tab_gateC_publish_contract_20260811T201759Z_checks.csv`.
- 2026-08-11: Gate C reruns after trigger hardening and diagnostics (`20260811T202901Z`, `20260811T203904Z`, `20260811T204837Z`) remained blocked on publish-file detection; latest status `FAIL` with `total_checks=33`, `failed_checks=22`, and invariant checks still passing. Evidence: `Logs/ftn_probe_runs/ftn_data_tab_gateC_publish_contract_20260811T204837Z_summary.csv`, `Logs/ftn_probe_runs/ftn_data_tab_gateC_publish_contract_20260811T204837Z_checks.csv`.
- 2026-08-11: User completed additional manual publish experiments and confirmed published datasets are correct for the Step 8/Gate C contract; tranche evidence now uses hybrid acceptance (automated on-screen invariance plus manual publish-output validation) while automation-only publish-path detection remains an instrumentation gap.
- 2026-08-11: Step 10 parse and regression pass executed (without rerunning Gate C per request): parse checks returned `parse_ok`; `System/Testing/ftn_validated_probe_artifact_currentity.R` returned `FTN_ARTIFACT_PROBE_STATUS=PASS`; `System/Testing/ftn_validated_shiny_smoke.R` returned `FTN_SHINY_SMOKE_STATUS=PASS`; `System/Testing/ftn_validated_calendar_signature_matrix.R` returned `FTN_CAL_MATRIX_STATUS=PASS`; `System/Testing/ftn_validated_unit_invariant_scan.R` returned `FTN_UNIT_INVARIANT_STATUS=PASS` with summary at `Logs/ftn_probe_runs/ftn_unit_invariant_scan_20260811T211353Z_summary.csv`.
- 2026-08-11: Step 12 closeout completed with GO decision for tranche scope. Acceptance is based on Gate A automated PASS, Gate B automated PASS, Step 8 contract validated through user manual publish experiments plus automated on-screen invariance checks, and Step 10 regression PASS.

## Final Summary (Plain Terms)

This tranche fixed a real Data-tab labeling defect and added the requested publish-only `Variable` column behavior without changing what users see on screen in the Data tab.

Validation outcomes are strong for accepted scope. Gate A passed with zero source-bounded rollup anomalies, Gate B passed after the row-scope label repair, and Step 10 parse and regression probes all passed. For Gate C, the automation harness still has a publish-file detection gap, but manual experiments confirmed published datasets follow the intended Step 8 contract, so closeout uses hybrid evidence.

Go/no-go outcome is GO for this tranche scope. The only remaining item is a non-blocking follow-up to harden Gate C publish detection so future runs can rely on a strict automation-only verdict.
