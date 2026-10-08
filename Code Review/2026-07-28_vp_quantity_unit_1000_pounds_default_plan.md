# VP Quantity Unit 1000 Pounds Default Plan

Date: 2026-07-28
Branch: main
Status: Implementation complete with targeted validation. This file is the source of truth for adding 1000 Pounds to Quantity Unit choices and making VP startup default to that unit.

## Purpose

Add a `1000 Pounds` Quantity Unit option and default the VP app to that native volume unit on initialization.

## Scope

Included:
- Quantity Unit dropdown choices.
- Unit conversion, label, and helper support for the new unit code.
- VP startup/source-entry default behavior.
- Focused parse and helper validation.

Excluded:
- Data artifact rebuilds.
- Value Unit dropdowns.
- Non-quantity metric logic beyond keeping existing metric-specific safeguards intact.

## Technical Strategy

- Introduce a stable unit code for 1000 Pounds: `thousand_lbs`.
- Add `1000 Pounds` to shared quantity-unit choice vectors.
- Convert metric-ton values to 1000 Pounds as `MT * 2204.62 / 1000`.
- Convert pound-native NASS values to 1000 Pounds using a 1000-pound denominator.
- Default VP source entry to `thousand_lbs` while preserving valid user selections after initialization.

## Step Ledger

| Step | Work | Status | Notes |
|---|---|---|---|
| 1 | Create implementation ledger | Complete | This file created before code edits. |
| 2 | Locate quantity-unit choices/defaults/conversions | Complete | Controlling code found in `VP Clone/Programs/app_source/server/02_partner_and_notes.R`. |
| 3 | Add 1000 Pounds unit support | Complete | Added menu value, VP default, conversion, label, and helper assertions. |
| 4 | Validate targeted behavior | Complete | Parse check passed; focused text/probe check returned `UNIT_1000_POUNDS_PROBE_OK`. |
| 5 | Record evidence and close ledger summary | Complete | Evidence and residual risk documented below. |

## Audit Checklist

- Choice audit: `1000 Pounds` appears in quantity unit choices.
- Default audit: VP initialization resolves to `thousand_lbs` rather than stale `lbs`.
- Conversion audit: 1 MT converts to 2.20462 in 1000 Pounds.
- Label audit: `get_unit_label("thousand_lbs")` returns `1000 Pounds`.
- Regression audit: existing Pounds and Million Pounds behavior remains unchanged.

## Working Notes

- Existing data signal columns include `quantity_1000_lb`, but app unit UI/conversion code had no `thousand_lbs` unit code before this tranche.
- Two early focused-probe attempts failed because PowerShell/R inline quoting mangled variables or quoted paths. These were command-construction failures, not app-code failures.
- A simplified PowerShell-safe focused probe passed after reducing quote-heavy literal matching.

## Validation Evidence

- Parse check:
	- Command parsed both edited files: `VP Clone/Programs/app_source/server/02_partner_and_notes.R` and `VP Clone/Programs/app_source/ui.R`.
	- Result: `PARSE_OK`
- Focused 1000 Pounds probe:
	- Checked parse success plus source presence for `1000 Pounds`, `thousand_lbs`, VP default-selection path, conversion formula `mt_values * 2204.62 / 1000`, and UI documentation note.
	- Result: `UNIT_1000_POUNDS_PROBE_OK`
- Static diagnostics:
	- `ui.R` reported no diagnostics.
	- `02_partner_and_notes.R` reports pre-existing Shiny-context global diagnostics (`input`, `session`, `%>%`, app helper functions). No new syntax errors were found by R parse.

## Implementation Notes

- Added `"1000 Pounds" = "thousand_lbs"` to shared quantity unit choices and WASDE quantity choices.
- Added `vp_trade` default unit resolution to `thousand_lbs`.
- Updated VP source-entry default-pending logic so startup/source-entry forces `thousand_lbs`, then clears once the input has landed there.
- Added conversion support:
	- General MT conversion: `MT * 2204.62 / 1000`.
	- PSD yield quantity conversion: `2204.62 / 1000`.
	- WASDE MT-per-unit conversion: `1000 * 0.00045359237`.
	- NASS pound-native denominator: `1000` pounds per `thousand_lbs`.
- Added display label: `1000 Pounds`.
- Added helper assertions for the new unit conversion and label.

## Residual Risk

- A browser-level startup assertion was not run because the available VP smoke harness is broader and has recently produced long-running buffered output.
- Risk is moderate-low: startup default logic was changed at the same existing VP default-pending control points that previously forced `lbs`, and targeted parse/probe checks passed.

## Final Summary (Lay Terms)

- What changed:
	- The Quantity Unit dropdown now includes `1000 Pounds`.
	- When the VP app initializes or enters the VP Trade source, it now aims for `1000 Pounds` instead of plain `Pounds`.
- Why this matters:
	- VP trade volume is often naturally reported at the thousand-pound scale, so tables and plots should start in a more native unit.
- What stayed the same:
	- Existing `Pounds`, `Million Pounds`, metric-ton, kilogram, US ton, and CWT options remain available.
	- User-selected valid units can still be retained after initialization.
- What was checked:
	- Both edited R files parse successfully.
	- A focused probe confirmed the new choice, default token, conversion formula, label, and UI note are wired in source.