# VP Mixed Rollups And Unit Values Implementation Plan

## Objective
Implement VP mixed liquid/weight rollup cleanup so mixed contexts such as tomatoes replace the old mixed `All` row with `All - excluding juice`, aggregate value and volume from weight-family rows only, calculate monthly and accumulated unit values from totals, and expose accumulated unit value as an optional Current vs Historical overlay.

## Decisions
- Mixed rollup values exclude juice too; value numerator and volume denominator must cover the same weight-family rows.
- Mixed rollups replace the old `All` row with `All - excluding juice`; commodities without juice keep `All`.
- Add `ytd_unit_value`, but keep it plot-only/internal in this tranche rather than a broad sidebar or Summary Statistics metric.
- Juice unit values are native dollars per gallon.
- No gallon-to-pound conversion is introduced.

## Risk Guardrails
- Implement one detail-key helper for both native synthetic `All` rows and strict rollups.
- Match Value rows to eligible weight-family Volume detail keys; do not classify Value rows by `UnitDesc`.
- Stop and inspect if finite unmatched Value rows appear broad or unexpectedly large.
- Bump builder/schema metadata together with startup validation.
- Include the YTD overlay checkbox in plot cache keys.
- Keep `ytd_unit_value` limited to artifact/internal pass-through, Current vs Historical overlay, hover/export reconstruction where needed, and tests.

## Implementation Log
- Created ledger before code edits.
- Updated `VP Clone/Programs/vp_data_utils.R` builder/schema constants to v6 / `vp_rollup_schema_2026_07_28_v1`.
- Added `All - excluding juice` label constant and `vp_mixed_source_replacement` required rollup field.
- Added shared native all-type aggregation helper that labels mixed liquid/weight contexts as `All - excluding juice` and filters mixed replacement rows to weight-family Volume detail keys plus matching Value detail keys.
- Refactored strict rollups so each rollup level synthesizes its own `All` or `All - excluding juice` aggregate from detail rows at that level, instead of inheriting lower-level aggregate labels.
- After the first user-side rebuild, artifact probing and UI inspection showed Tomatoes still had the old `All` type alongside `All - excluding juice`. Root cause: mixed replacement filtering kept all Volume rows for an eligible detail key, so details with both pounds and gallons could still carry liquid Volume into the replacement aggregate. Patched the helper to retain only weight-family Volume rows for mixed replacements while still matching Value rows by eligible weight-family detail key.
- Replaced averaged source `Unit value` merge with calculated `unit_value = monthly_value_dollars / monthly_volume_base` and `ytd_unit_value = ytd_value_dollars / ytd_volume_base`, guarded against missing/zero denominators.
- Added `ytd_unit_value` to VP metric definitions and column mapping.
- Updated startup validation in `VP Clone/Programs/app_source/global.R` to require `unit_value`, `unit_value_unit`, `ytd_unit_value`, and `ytd_unit_value_unit` along with the new rollup schema field.
- Updated VP server metric handling so `unit_value` is no longer suppressed for rollup contexts and both `unit_value`/`ytd_unit_value` bypass quantity conversion.
- Added a VP monthly Unit Value checkbox, `show_ytd_unit_value_overlay`, near the Current vs Historical plot.
- Added Current vs Historical YTD unit-value overlay traces and included the checkbox in the comparison plot cache key.
- Added `ytd_unit_value` pass-through handling in core VP/custom-country metric lists.
- Updated VP display/export reconstruction to classify `ytd_unit_value` as `Unit value`.
- Updated VP smoke-test artifact assertions for calculated unit values and the new schema token.
- Added VP smoke-test markers for the YTD unit-value overlay control and `Current YTD unit value` trace in a monthly VP Unit Value context.
- Patched `VP Clone/Programs/app_source/server/01_state_and_custom_types.R` so VP Type dropdown choices suppress `All` whenever `All - excluding juice` is present in the resolved VP hierarchy. This handles the UI choice-list layer separately from the row-level artifact contract.

## Validation Log
- `vp_data_utils.R` parse passed after each builder slice with `PARSE_OK`.
- Synthetic mixed native probe passed: mixed Tomato-style rows emit native `All - excluding juice`, do not emit native `All`, and exclude juice Value/Volume from the replacement row.
- Synthetic unit-value probe passed after scoping to native rows: replacement row monthly volume/value and `unit_value`/`ytd_unit_value` equal value divided by weight-family base volume; unit label is `Dollars per metric ton`.
- Synthetic strict mixed-rollup probe passed: when a commodity has one mixed juice segment and one non-juice weight segment, the broader segment-all rollup emits `All - excluding juice`, does not emit a competing `All`, and includes the non-juice weight segment in the replacement aggregate.
- Rebuild attempt with bare `Master_VP.R` skipped because no update flags were selected; retry with `VP_MASTER_UPDATES=vp_trade` was stopped before completion after the strict rollup inheritance edge was identified.
- Direct `vp_build_trade_artifact()` rebuild started from current source after stopping orphaned stale Rscript processes, but was paused/stopped at user request so the user can run the rebuild locally. No Rscript rebuild processes were left running by this session.
- Latest pre-rebuild validation checkpoint: combined parse passed for all touched R files and synthetic VP probes passed for mixed strict rollups plus calculated monthly/YTD unit values.
- Post-rebuild artifact probe caught replacement rows with `vp_volume_family_mixed == TRUE` and missing weight volume, matching the UI symptom where Tomatoes still showed both `All` and `All - excluding juice`.
- After patching mixed replacement Volume filtering, synthetic VP probes passed again, including an assertion that no gallon/liquid Volume row survives in the `All - excluding juice` replacement aggregate.
- Combined parse passed again for all touched R files after the follow-up helper fix. Ready for another user-side VP artifact rebuild.
- User rebuilt the VP dataset after the follow-up helper fix. Post-rebuild artifact probe passed: rebuilt artifact has current v6 builder/schema metadata, 14,967 `All - excluding juice` rows, 2,364 Tomato replacement contexts, zero competing Tomato `All` rows in those contexts, no mixed-family flags on replacement rows, calculated `unit_value` checked across 2,105,317 rows, and calculated `ytd_unit_value` checked across 2,097,961 rows.
- User still saw `All` in the Tomato Type dropdown after artifact validation. Root cause was UI choice construction: the dropdown gathers all available type labels for the resolved VP commodity hierarchy across the artifact, so a global/nonreplacement `All` could still appear even though it did not compete with `All - excluding juice` in the same row contexts. Added dropdown-level filtering and validated with `VP_TOMATO_CHOICE_FILTER_PROBE_OK`.
- Final combined parse passed after the dropdown patch for `vp_data_utils.R`, `global.R`, `01_state_and_custom_types.R`, `02_partner_and_notes.R`, `03_core_reactives_and_ui.R`, `04_comparison_plots.R`, `05_trend_and_heatmap.R`, and `vp_shinytest_smoke.R`.
- One initial inline R probe failed due PowerShell quoting; reran through a temporary R script.
- One initial unit-value probe counted strict rollup copies as well as the native row; diagnostic showed builder output was correct, and the scoped native assertion passed.
- Combined parse passed for `vp_data_utils.R`, `global.R`, `02_partner_and_notes.R`, `03_core_reactives_and_ui.R`, `04_comparison_plots.R`, `05_trend_and_heatmap.R`, and `vp_shinytest_smoke.R` with `PARSE_OK`.

## Final Summary
- Pending.
