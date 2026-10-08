# VP Summary Statistics Reverse Month Order Plan

Date: 2026-07-28
Branch: main
Status: Implementation complete with targeted validation and documented residual risk. This file is the source of truth for implementing Current vs Historical Summary Statistics month-order reversal.

## Purpose

Reorder the monthly rows in the Current vs Historical Summary Statistics table so the latest available marketing-year month is shown first and the earliest marketing-year month is shown last.

## Scope

Included:
- Current vs Historical tab only.
- Summary Statistics table monthly row ordering only.
- Commodity-aware month ordering based on existing `analysis_month` mapping.

Excluded:
- Dropdown month ordering.
- Snapshot cutoff ordering.
- Comparison plot axis ordering.
- Non-VP tabs and non-VP app contracts.

## Source-Of-Truth Ledger Contract

- This file is the active implementation ledger and must be updated after each step/tranche.
- Record failed attempts, rejected approaches, blockers, and bug discoveries here.
- Keep evidence concise and deterministic.
- No paired results markdown unless explicitly requested.

## Technical Strategy

- Apply descending sort on `analysis_month` in the Summary Statistics monthly branch.
- Keep month-label mapping unchanged (`current_display_month_mapping` / VP calendar signatures).
- Preserve projection-row prepend behavior.

## Step Ledger

| Step | Work | Status | Notes |
|---|---|---|---|
| 1 | Create implementation ledger | Complete | This file created before code edits. |
| 2 | Implement monthly Summary Statistics row-order reversal | Complete | Monthly branch now applies descending sort when source is `census` or `vp_trade`. |
| 3 | Validate projection-row placement after reorder | Complete | Projection-row prepend remains intact via `summary_table <- bind_rows(proj_row, summary_table)`. |
| 4 | Run targeted regression validation | Complete (targeted) | Parse validation passed. Smoke harness was attempted and manually terminated after long-running buffered output (no deterministic failure signature captured). |
| 5 | Record evidence and close ledger summary | Complete | Evidence and residual risk documented below. |

## Audit Checklist

- Dependency audit: month labels remain joined by `analysis_month` before select/rename.
- Source-scope audit: VP runtime is `vp_trade` under contract.
- Projection interaction audit: projection rows prepended after table assembly.
- Calendar-variance audit: different commodity/type start months preserved by `analysis_month` semantics.
- Regression risk: change should remain localized to monthly summary branch.

## Working Notes

- Investigated unexpected large binary changes under `VP Clone/System/Processed Data` and partition artifacts during this implementation window.
- These artifacts were treated as unrelated to the summary-table ordering patch.
- User decision: continue implementation without reverting or modifying those unrelated artifacts.

## Validation Evidence

- Parse check (targeted):
	- Command: `Rscript -e "invisible(parse(file='VP Clone/Programs/app_source/server/04_comparison_plots.R')); cat('PARSE_OK\\n')"`
	- Result: `PARSE_OK`
- Logic verification in summary table renderer:
	- Monthly order condition includes VP source: `if (source_choice %in% c("census", "vp_trade")) { monthly_summary <- monthly_summary %>% arrange(desc(analysis_month)) }`
	- Projection rows still prepended after table assembly: `summary_table <- bind_rows(proj_row, summary_table)`
	- DT ordering remains disabled in table options (`ordering = FALSE`) so row sequence is preserved as assembled.

## Residual Risk

- Full end-to-end smoke confirmation did not finish cleanly in this session due long-running buffered harness output before manual termination.
- Risk impact is low-to-moderate for this specific patch because the change is localized to one monthly ordering conditional and does not alter joins, label mapping, or projection-row assembly.

## Final Summary (Lay Terms)

- What changed:
	- In the Current vs Historical Summary Statistics monthly table, VP monthly rows now display newest month first instead of marketing-year-start first.
- What stayed the same:
	- Month names still respect commodity/type-specific marketing-year mapping.
	- Projection rows remain pinned above the monthly rows.
	- Weekly logic and non-table surfaces were not changed.
- What was checked:
	- The edited server file parses successfully.
	- The key ordering and projection-row lines were verified in code.
- Noted caveat:
	- A long-running smoke harness was started and then terminated, so runtime validation is targeted rather than full-session exhaustive.
