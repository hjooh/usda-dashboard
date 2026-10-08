`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0L) y else x
}

resolve_repo_root <- function(start_dir = getwd()) {
  start_dir <- normalizePath(start_dir, winslash = "/", mustWork = FALSE)
  candidates <- unique(c(
    start_dir,
    vapply(1:8, function(level) normalizePath(file.path(start_dir, paste(rep("..", level), collapse = "/")), winslash = "/", mustWork = FALSE), character(1))
  ))

  for (candidate in candidates) {
    if (file.exists(file.path(candidate, ".vp_clone_root"))) {
      return(candidate)
    }
  }

  stop("Could not resolve FTN repository root (.vp_clone_root missing).", call. = FALSE)
}

if (!requireNamespace("data.table", quietly = TRUE)) {
  stop("Package 'data.table' is required for ftn_validated_unit_invariant_scan.R", call. = FALSE)
}

as_first_string <- function(value, default = "") {
  values <- trimws(as.character(value %||% character(0)))
  values <- values[!is.na(values) & nzchar(values)]
  if (length(values) == 0L) default else values[[1L]]
}

existing_columns <- function(df, desired) {
  desired[desired %in% names(df)]
}

metric_scan_for_grain <- function(dt, metric_col, unit_col, grain_name, grain_keys) {
  metric_rows <- dt[!is.na(get(metric_col))]
  if (nrow(metric_rows) == 0L) {
    return(list(
      grain = grain_name,
      metric = metric_col,
      unit_field = unit_col,
      row_count = 0L,
      context_count = 0L,
      anomaly_count = 0L,
      anomalies = data.table::data.table()
    ))
  }

  work <- data.table::copy(metric_rows)
  work[, unit_value_text := trimws(as.character(get(unit_col)))]
  work[, unit_present := !is.na(unit_value_text) & nzchar(unit_value_text)]
  if ("vp_volume_family_mixed" %in% names(work)) {
    work[, mixed_volume_flag := as.logical(vp_volume_family_mixed)]
    work[is.na(mixed_volume_flag), mixed_volume_flag := FALSE]
  } else {
    work[, mixed_volume_flag := FALSE]
  }

  by_keys <- grain_keys
  if (length(by_keys) == 0L) {
    by_keys <- NULL
  }

  context_summary <- work[, .(
    row_count = .N,
    unit_count = data.table::uniqueN(unit_value_text[unit_present]),
    units = paste(sort(unique(unit_value_text[unit_present])), collapse = "|"),
    missing_unit_rows = sum(!unit_present, na.rm = TRUE),
    mixed_volume_rows = sum(mixed_volume_flag, na.rm = TRUE)
  ), by = by_keys]

  anomalies <- context_summary[unit_count > 1L | missing_unit_rows > 0L]
  if (nrow(anomalies) > 0L) {
    anomalies[, `:=`(
      grain = grain_name,
      metric = metric_col,
      unit_field = unit_col
    )]
  }

  list(
    grain = grain_name,
    metric = metric_col,
    unit_field = unit_col,
    row_count = nrow(work),
    context_count = nrow(context_summary),
    anomaly_count = nrow(anomalies),
    anomalies = anomalies
  )
}

repo_root <- resolve_repo_root()
artifact_path <- file.path(repo_root, "System", "Processed Data", "vp_trade_monthly_pre.rds")
if (!file.exists(artifact_path)) {
  stop(
    paste0("Missing artifact: ", artifact_path, ". Run Master_FTN.R with VP_MASTER_UPDATES=vp_trade,metadata first."),
    call. = FALSE
  )
}

artifact_object <- readRDS(artifact_path)
artifact_df <- if (is.data.frame(artifact_object)) {
  artifact_object
} else if (is.list(artifact_object) && is.data.frame(artifact_object$data)) {
  artifact_object$data
} else {
  data.frame()
}

if (!is.data.frame(artifact_df) || nrow(artifact_df) == 0L) {
  stop("vp_trade artifact has no rows.", call. = FALSE)
}

required_columns <- c("unit_value", "unit_value_unit", "ytd_unit_value", "ytd_unit_value_unit")
missing_required <- setdiff(required_columns, names(artifact_df))
if (length(missing_required) > 0L) {
  stop(
    paste0("Artifact is missing required unit-value columns: ", paste(missing_required, collapse = ", ")),
    call. = FALSE
  )
}

point_keys_desired <- c(
  "Trade", "Group", "Subgroup", "MarketSegment", "CommodityName", "CommodityDetail",
  "commodity", "country", "market_year", "analysis_month", "vp_rollup_level", "vp_rollup_path"
)
year_keys_desired <- setdiff(point_keys_desired, c("analysis_month"))
series_keys_desired <- setdiff(year_keys_desired, c("market_year"))

scan_columns <- unique(c(
  existing_columns(artifact_df, point_keys_desired),
  existing_columns(artifact_df, year_keys_desired),
  existing_columns(artifact_df, series_keys_desired),
  c("unit_value", "unit_value_unit", "ytd_unit_value", "ytd_unit_value_unit"),
  existing_columns(artifact_df, c("vp_volume_family_mixed"))
))

scan_dt <- data.table::as.data.table(artifact_df)[, ..scan_columns]

point_keys <- existing_columns(scan_dt, point_keys_desired)
year_keys <- existing_columns(scan_dt, year_keys_desired)
series_keys <- existing_columns(scan_dt, series_keys_desired)

scan_results <- list(
  metric_scan_for_grain(scan_dt, "unit_value", "unit_value_unit", "point", point_keys),
  metric_scan_for_grain(scan_dt, "ytd_unit_value", "ytd_unit_value_unit", "point", point_keys),
  metric_scan_for_grain(scan_dt, "unit_value", "unit_value_unit", "visualization_year", year_keys),
  metric_scan_for_grain(scan_dt, "ytd_unit_value", "ytd_unit_value_unit", "visualization_year", year_keys),
  metric_scan_for_grain(scan_dt, "unit_value", "unit_value_unit", "visualization_series", series_keys),
  metric_scan_for_grain(scan_dt, "ytd_unit_value", "ytd_unit_value_unit", "visualization_series", series_keys)
)

summary_dt <- data.table::rbindlist(lapply(scan_results, function(item) {
  data.table::data.table(
    grain = item$grain,
    metric = item$metric,
    unit_field = item$unit_field,
    row_count = as.integer(item$row_count),
    context_count = as.integer(item$context_count),
    anomaly_count = as.integer(item$anomaly_count)
  )
}), fill = TRUE)

anomaly_dt <- data.table::rbindlist(lapply(scan_results, function(item) item$anomalies), fill = TRUE)
if (nrow(anomaly_dt) > 0L) {
  data.table::setcolorder(
    anomaly_dt,
    unique(c(
      "grain", "metric", "unit_field", point_keys_desired,
      "row_count", "unit_count", "units", "missing_unit_rows", "mixed_volume_rows"
    ))[unique(c(
      "grain", "metric", "unit_field", point_keys_desired,
      "row_count", "unit_count", "units", "missing_unit_rows", "mixed_volume_rows"
    )) %in% names(anomaly_dt)]
  )
}

mixed_family_rows <- if ("vp_volume_family_mixed" %in% names(scan_dt)) {
  scan_dt[
    as.logical(vp_volume_family_mixed) == TRUE &
      (!is.na(unit_value) | !is.na(ytd_unit_value)),
    .N
  ]
} else {
  0L
}

missing_unit_rows_total <- scan_dt[
  (!is.na(unit_value) & (is.na(unit_value_unit) | !nzchar(trimws(as.character(unit_value_unit))))) |
    (!is.na(ytd_unit_value) & (is.na(ytd_unit_value_unit) | !nzchar(trimws(as.character(ytd_unit_value_unit))))),
  .N
]

liquid_candidates <- scan_dt[
  !is.na(unit_value) & trimws(as.character(unit_value_unit)) == "Dollars per gallon"
]
liquid_candidate_count <- nrow(liquid_candidates)

run_stamp <- format(as.POSIXct(Sys.time(), tz = "UTC"), "%Y%m%dT%H%M%SZ")
output_dir <- file.path(repo_root, "Logs", "ftn_probe_runs")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
summary_path <- file.path(output_dir, paste0("ftn_unit_invariant_scan_", run_stamp, "_summary.csv"))
anomaly_path <- file.path(output_dir, paste0("ftn_unit_invariant_scan_", run_stamp, "_anomalies.csv"))

data.table::fwrite(summary_dt, summary_path)
if (nrow(anomaly_dt) > 0L) {
  data.table::fwrite(anomaly_dt, anomaly_path)
}

total_anomaly_count <- sum(summary_dt$anomaly_count, na.rm = TRUE)
status_value <- if (total_anomaly_count == 0L) "PASS" else "FAIL"

cat("FTN_UNIT_INVARIANT_STATUS=", status_value, "\n", sep = "")
cat("FTN_UNIT_INVARIANT_ARTIFACT_PATH=", artifact_path, "\n", sep = "")
cat("FTN_UNIT_INVARIANT_ROW_COUNT=", nrow(scan_dt), "\n", sep = "")
cat("FTN_UNIT_INVARIANT_SUMMARY_PATH=", summary_path, "\n", sep = "")
cat("FTN_UNIT_INVARIANT_ANOMALY_PATH=", if (nrow(anomaly_dt) > 0L) anomaly_path else "", "\n", sep = "")
cat("FTN_UNIT_INVARIANT_TOTAL_CONTEXTS=", sum(summary_dt$context_count, na.rm = TRUE), "\n", sep = "")
cat("FTN_UNIT_INVARIANT_TOTAL_ANOMALIES=", total_anomaly_count, "\n", sep = "")
cat("FTN_UNIT_INVARIANT_MIXED_VOLUME_ROWS=", mixed_family_rows, "\n", sep = "")
cat("FTN_UNIT_INVARIANT_MISSING_UNIT_ROWS=", missing_unit_rows_total, "\n", sep = "")
cat("FTN_UNIT_INVARIANT_LIQUID_CANDIDATE_ROWS=", liquid_candidate_count, "\n", sep = "")

for (row_idx in seq_len(nrow(summary_dt))) {
  row <- summary_dt[row_idx]
  prefix <- paste0("FTN_UNIT_INVARIANT_", toupper(row$grain), "_", toupper(row$metric))
  cat(prefix, "_ROWS=", row$row_count, "\n", sep = "")
  cat(prefix, "_CONTEXTS=", row$context_count, "\n", sep = "")
  cat(prefix, "_ANOMALIES=", row$anomaly_count, "\n", sep = "")
}

if (nrow(anomaly_dt) > 0L) {
  preview_cols <- intersect(c(
    "grain", "metric", "Trade", "Group", "Subgroup", "MarketSegment",
    "CommodityName", "CommodityDetail", "commodity", "country", "market_year",
    "analysis_month", "vp_rollup_level", "vp_rollup_path",
    "unit_count", "units", "missing_unit_rows", "mixed_volume_rows"
  ), names(anomaly_dt))

  preview_rows <- utils::head(anomaly_dt[, ..preview_cols], 12L)
  cat("FTN_UNIT_INVARIANT_ANOMALY_PREVIEW_START\n")
  utils::write.table(preview_rows, row.names = FALSE, sep = "|", quote = FALSE)
  cat("FTN_UNIT_INVARIANT_ANOMALY_PREVIEW_END\n")

  stop(
    paste0(
      "Unit invariant scan failed with ", total_anomaly_count,
      " mixed/missing-unit visualization-context anomalies. See ", anomaly_path
    ),
    call. = FALSE
  )
}
