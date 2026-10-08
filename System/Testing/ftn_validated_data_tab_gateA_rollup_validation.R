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
  stop("Package 'data.table' is required for ftn_validated_data_tab_gateA_rollup_validation.R", call. = FALSE)
}

progress <- function(msg) {
  cat("FTN_DATA_TAB_GATEA_PROGRESS=", msg, "\n", sep = "")
  flush.console()
}

safe_chr <- function(value) {
  out <- trimws(as.character(value %||% ""))
  out[is.na(out)] <- ""
  out
}

non_rollup_token <- function(value) {
  values <- safe_chr(value)
  nzchar(values) & !grepl("^__vp_rollup_all_", values)
}

market_year_int <- function(value) {
  value_chr <- safe_chr(value)
  out <- suppressWarnings(as.integer(value_chr))
  slash_match <- grepl("^[0-9]{4}/[0-9]{2}$", value_chr)
  if (any(slash_match, na.rm = TRUE)) {
    start_year <- suppressWarnings(as.integer(substr(value_chr[slash_match], 1L, 4L)))
    end_suffix <- suppressWarnings(as.integer(substr(value_chr[slash_match], 6L, 7L)))
    century <- floor(start_year / 100L) * 100L
    end_year <- century + end_suffix
    end_year[end_year < start_year] <- end_year[end_year < start_year] + 100L
    out[slash_match] <- end_year
  }
  leading_match <- is.na(out) & grepl("^[0-9]{4}", value_chr)
  out[leading_match] <- suppressWarnings(as.integer(substr(value_chr[leading_match], 1L, 4L)))
  out
}

metric_check <- function(checks, metric_name, artifact_col, source_col, broader_col) {
  work <- data.table::copy(checks)
  work[, metric := metric_name]
  work[, artifact_value := get(artifact_col)]
  work[, source_exact_value := get(source_col)]
  work[, source_broader_value := get(broader_col)]
  work[, delta_exact := artifact_value - source_exact_value]
  work[, abs_delta_exact := abs(delta_exact)]
  work[, delta_broader := artifact_value - source_broader_value]
  work[, abs_delta_broader := abs(delta_broader)]
  work[, exact_available := !is.na(source_exact_value)]
  work[, broader_available := !is.na(source_broader_value)]
  work[, broader_differs := broader_available & exact_available & abs(source_broader_value - source_exact_value) > 1e-6]
  work[, matches_exact := exact_available & abs_delta_exact <= 1e-6]
  work[, matches_broader := broader_available & abs_delta_broader <= 1e-6]
  work[, leakage_match := broader_differs & matches_broader & !matches_exact]
  work[, missing_source := !exact_available]
  work[, mismatch := exact_available & !matches_exact]
  work[, reason := ""]
  work[missing_source == TRUE, reason := "missing_source_exact"]
  work[mismatch == TRUE, reason := "source_exact_mismatch"]
  work[leakage_match == TRUE, reason := "matches_broader_cross_segment_total"]
  work[
    missing_source == TRUE | mismatch == TRUE | leakage_match == TRUE,
    .SD,
    .SDcols = c(
      "metric", "reason", "Trade", "Group", "Subgroup", "MarketSegment", "CommodityName",
      "CommodityDetail", "country", "countryDescription", "market_year", "analysis_month",
      "calendar_year", "calendar_month", "artifact_value", "source_exact_value", "source_broader_value",
      "delta_exact", "abs_delta_exact", "delta_broader", "abs_delta_broader",
      "broader_segment_count", "broader_differs", "matches_exact", "matches_broader", "leakage_match"
    )
  ]
}

repo_root <- resolve_repo_root()
artifact_path <- file.path(repo_root, "System", "Processed Data", "vp_trade_monthly_pre.rds")
source_path <- file.path(repo_root, "Input", "fruit-trade-data.csv")

if (!file.exists(artifact_path)) {
  stop(paste0("Missing artifact: ", artifact_path, ". Run Master_FTN.R with VP_MASTER_UPDATES=vp_trade,metadata first."), call. = FALSE)
}
if (!file.exists(source_path)) {
  stop(paste0("Missing source CSV: ", source_path), call. = FALSE)
}

progress("load_artifact")
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

progress("load_source")
source_dt <- data.table::fread(source_path)
artifact_dt <- data.table::as.data.table(artifact_df)

required_artifact_cols <- c(
  "Trade", "Group", "Subgroup", "MarketSegment", "CommodityName", "CommodityDetail",
  "country", "countryDescription", "market_year", "analysis_month", "calendar_year", "calendar_month",
  "vp_is_rollup", "monthlyexports", "ytd_exports", "monthlyvalue", "ytd_value"
)
required_source_cols <- c(
  "Trade", "GeographicDesc", "Year", "MonthNumber", "MarketYear", "Group", "Subgroup",
  "MarketSegment", "CommodityName", "CommodityDetail", "UnitType", "UnitDesc", "Amount"
)

missing_artifact_cols <- setdiff(required_artifact_cols, names(artifact_dt))
missing_source_cols <- setdiff(required_source_cols, names(source_dt))
if (length(missing_artifact_cols) > 0L) {
  stop(paste0("Artifact is missing required Gate A columns: ", paste(missing_artifact_cols, collapse = ", ")), call. = FALSE)
}
if (length(missing_source_cols) > 0L) {
  stop(paste0("Source CSV is missing required Gate A columns: ", paste(missing_source_cols, collapse = ", ")), call. = FALSE)
}

progress(paste0("artifact_rows=", nrow(artifact_dt)))
progress(paste0("source_rows=", nrow(source_dt)))

artifact_all <- artifact_dt[
  (is.na(vp_is_rollup) | vp_is_rollup == FALSE) &
    non_rollup_token(Group) &
    non_rollup_token(Subgroup) &
    non_rollup_token(MarketSegment) &
    safe_chr(CommodityDetail) == "All" &
    nzchar(safe_chr(Trade)) &
    nzchar(safe_chr(countryDescription)) &
    nzchar(safe_chr(CommodityName)) &
    !is.na(market_year) &
    !is.na(analysis_month) &
    !is.na(calendar_year) &
    !is.na(calendar_month),
  .(
    Trade = tolower(safe_chr(Trade)),
    Group = safe_chr(Group),
    Subgroup = safe_chr(Subgroup),
    MarketSegment = safe_chr(MarketSegment),
    CommodityName = safe_chr(CommodityName),
    CommodityDetail = safe_chr(CommodityDetail),
    country = safe_chr(country),
    countryDescription = safe_chr(countryDescription),
    market_year = as.integer(market_year),
    analysis_month = as.integer(analysis_month),
    calendar_year = as.integer(calendar_year),
    calendar_month = as.integer(calendar_month),
    monthlyexports = as.numeric(monthlyexports),
    ytd_exports = as.numeric(ytd_exports),
    monthlyvalue = as.numeric(monthlyvalue),
    ytd_value = as.numeric(ytd_value)
  )
]

if (nrow(artifact_all) == 0L) {
  stop("Gate A artifact Type=All filter returned zero rows.", call. = FALSE)
}

progress(paste0("artifact_all_rows=", nrow(artifact_all)))

source_detail <- source_dt[
  safe_chr(UnitType) %in% c("Volume", "Value") & nzchar(safe_chr(CommodityDetail)),
  .(
    Trade = tolower(safe_chr(Trade)),
    Group = safe_chr(Group),
    Subgroup = safe_chr(Subgroup),
    MarketSegment = safe_chr(MarketSegment),
    CommodityName = safe_chr(CommodityName),
    countryDescription = safe_chr(GeographicDesc),
    market_year = market_year_int(MarketYear),
    calendar_year = as.integer(Year),
    calendar_month = as.integer(MonthNumber),
    source_detail = safe_chr(CommodityDetail),
    UnitType = safe_chr(UnitType),
    UnitDesc = safe_chr(UnitDesc),
    Amount = as.numeric(Amount)
  )
]
source_detail[, source_volume_base := data.table::fifelse(
  UnitType == "Volume" & grepl("gallon", tolower(UnitDesc)),
  Amount * 1000,
  data.table::fifelse(UnitType == "Volume", Amount * 0.45359237, NA_real_)
)]
source_detail[, source_value_dollars := data.table::fifelse(
  UnitType == "Value" & tolower(UnitDesc) == "thousand dollars",
  Amount * 1000,
  data.table::fifelse(UnitType == "Value", Amount, NA_real_)
)]

source_monthly_exact <- source_detail[, .(
  source_monthlyexports = sum(source_volume_base, na.rm = TRUE),
  source_monthlyvalue = sum(source_value_dollars, na.rm = TRUE),
  source_detail_count = data.table::uniqueN(source_detail),
  exact_source_row_count = .N
), by = .(Trade, Group, Subgroup, MarketSegment, CommodityName, countryDescription, market_year, calendar_year, calendar_month)]
source_monthly_exact[, CommodityDetail := "All"]

source_monthly_broader <- source_detail[, .(
  broader_monthlyexports = sum(source_volume_base, na.rm = TRUE),
  broader_monthlyvalue = sum(source_value_dollars, na.rm = TRUE),
  broader_segment_count = data.table::uniqueN(MarketSegment),
  broader_detail_count = data.table::uniqueN(source_detail),
  broader_source_row_count = .N
), by = .(Trade, Group, Subgroup, CommodityName, countryDescription, market_year, calendar_year, calendar_month)]
source_monthly_broader[, CommodityDetail := "All"]

exact_keys <- c(
  "Trade", "Group", "Subgroup", "MarketSegment", "CommodityName", "CommodityDetail",
  "countryDescription", "market_year", "calendar_year", "calendar_month"
)
broader_keys <- setdiff(exact_keys, "MarketSegment")

checks <- source_monthly_exact[artifact_all, on = exact_keys]
checks <- source_monthly_broader[checks, on = broader_keys]

missing_exact_count <- checks[is.na(source_monthlyexports) & is.na(source_monthlyvalue), .N]
progress(paste0("monthly_checks=", nrow(checks), "|missing_exact=", missing_exact_count))

monthly_anomalies <- data.table::rbindlist(list(
  metric_check(checks, "monthlyexports", "monthlyexports", "source_monthlyexports", "broader_monthlyexports"),
  metric_check(checks, "monthlyvalue", "monthlyvalue", "source_monthlyvalue", "broader_monthlyvalue")
), fill = TRUE)

source_for_ytd <- checks[
  !is.na(source_monthlyexports) | !is.na(source_monthlyvalue),
  .(
    Trade, Group, Subgroup, MarketSegment, CommodityName, CommodityDetail, countryDescription,
    market_year, calendar_year, calendar_month, analysis_month,
    source_monthlyexports = data.table::fifelse(is.na(source_monthlyexports), 0, source_monthlyexports),
    source_monthlyvalue = data.table::fifelse(is.na(source_monthlyvalue), 0, source_monthlyvalue),
    broader_monthlyexports = data.table::fifelse(is.na(broader_monthlyexports), 0, broader_monthlyexports),
    broader_monthlyvalue = data.table::fifelse(is.na(broader_monthlyvalue), 0, broader_monthlyvalue)
  )
]
data.table::setorder(source_for_ytd, Trade, Group, Subgroup, MarketSegment, CommodityName, CommodityDetail, countryDescription, market_year, analysis_month, calendar_year, calendar_month)
source_for_ytd[, source_ytd_exports := cumsum(source_monthlyexports), by = .(Trade, Group, Subgroup, MarketSegment, CommodityName, CommodityDetail, countryDescription, market_year)]
source_for_ytd[, source_ytd_value := cumsum(source_monthlyvalue), by = .(Trade, Group, Subgroup, MarketSegment, CommodityName, CommodityDetail, countryDescription, market_year)]

source_broader_for_ytd <- unique(source_for_ytd[, .(
  Trade, Group, Subgroup, CommodityName, CommodityDetail, countryDescription, market_year,
  calendar_year, calendar_month, analysis_month, broader_monthlyexports, broader_monthlyvalue
)])
source_broader_for_ytd <- source_broader_for_ytd[, .(
  broader_monthlyexports = max(broader_monthlyexports, na.rm = TRUE),
  broader_monthlyvalue = max(broader_monthlyvalue, na.rm = TRUE)
), by = .(Trade, Group, Subgroup, CommodityName, CommodityDetail, countryDescription, market_year, calendar_year, calendar_month, analysis_month)]
data.table::setorder(source_broader_for_ytd, Trade, Group, Subgroup, CommodityName, CommodityDetail, countryDescription, market_year, analysis_month, calendar_year, calendar_month)
source_broader_for_ytd[, broader_ytd_exports := cumsum(broader_monthlyexports), by = .(Trade, Group, Subgroup, CommodityName, CommodityDetail, countryDescription, market_year)]
source_broader_for_ytd[, broader_ytd_value := cumsum(broader_monthlyvalue), by = .(Trade, Group, Subgroup, CommodityName, CommodityDetail, countryDescription, market_year)]

ytd_exact_keys <- c(exact_keys, "analysis_month")
ytd_broader_keys <- c(broader_keys, "analysis_month")
ytd_checks <- source_for_ytd[, .(
  Trade, Group, Subgroup, MarketSegment, CommodityName, CommodityDetail, countryDescription,
  market_year, calendar_year, calendar_month, analysis_month, source_ytd_exports, source_ytd_value
)][artifact_all, on = ytd_exact_keys]
ytd_checks <- source_broader_for_ytd[, .(
  Trade, Group, Subgroup, CommodityName, CommodityDetail, countryDescription,
  market_year, calendar_year, calendar_month, analysis_month, broader_ytd_exports, broader_ytd_value
)][ytd_checks, on = ytd_broader_keys]
ytd_checks[, broader_segment_count := checks$broader_segment_count]

ytd_anomalies <- data.table::rbindlist(list(
  metric_check(ytd_checks, "ytd_exports", "ytd_exports", "source_ytd_exports", "broader_ytd_exports"),
  metric_check(ytd_checks, "ytd_value", "ytd_value", "source_ytd_value", "broader_ytd_value")
), fill = TRUE)

anomaly_dt <- data.table::rbindlist(list(monthly_anomalies, ytd_anomalies), fill = TRUE)
metric_order <- c("monthlyexports", "monthlyvalue", "ytd_exports", "ytd_value")
summary_dt <- data.table::rbindlist(lapply(metric_order, function(metric_name) {
  metric_anomalies <- anomaly_dt[metric == metric_name]
  data.table::data.table(
    metric = metric_name,
    checked_context_count = nrow(artifact_all),
    anomaly_count = nrow(metric_anomalies),
    missing_source_count = metric_anomalies[reason == "missing_source_exact", .N],
    source_exact_mismatch_count = metric_anomalies[reason == "source_exact_mismatch", .N],
    leakage_match_count = metric_anomalies[reason == "matches_broader_cross_segment_total", .N]
  )
}), fill = TRUE)

total_anomalies <- sum(summary_dt$anomaly_count, na.rm = TRUE)
total_leakage_matches <- sum(summary_dt$leakage_match_count, na.rm = TRUE)
status <- if (total_anomalies == 0L) "PASS" else "FAIL"

run_stamp <- format(as.POSIXct(Sys.time(), tz = "UTC"), "%Y%m%dT%H%M%SZ")
output_dir <- file.path(repo_root, "Logs", "ftn_probe_runs")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
summary_path <- file.path(output_dir, paste0("ftn_data_tab_gateA_rollup_validation_", run_stamp, "_summary.csv"))
anomaly_path <- file.path(output_dir, paste0("ftn_data_tab_gateA_rollup_validation_", run_stamp, "_anomalies.csv"))
checks_path <- file.path(output_dir, paste0("ftn_data_tab_gateA_rollup_validation_", run_stamp, "_checks_sample.csv"))

data.table::fwrite(summary_dt, summary_path)
data.table::fwrite(utils::head(checks, 500L), checks_path)
if (nrow(anomaly_dt) > 0L) {
  data.table::fwrite(anomaly_dt, anomaly_path)
}

cat("FTN_DATA_TAB_GATEA_STATUS=", status, "\n", sep = "")
cat("FTN_DATA_TAB_GATEA_ARTIFACT_PATH=", artifact_path, "\n", sep = "")
cat("FTN_DATA_TAB_GATEA_SOURCE_PATH=", source_path, "\n", sep = "")
cat("FTN_DATA_TAB_GATEA_CHECKED_CONTEXTS=", nrow(artifact_all), "\n", sep = "")
cat("FTN_DATA_TAB_GATEA_SUMMARY_PATH=", summary_path, "\n", sep = "")
cat("FTN_DATA_TAB_GATEA_ANOMALY_PATH=", if (nrow(anomaly_dt) > 0L) anomaly_path else "", "\n", sep = "")
cat("FTN_DATA_TAB_GATEA_CHECKS_SAMPLE_PATH=", checks_path, "\n", sep = "")
cat("FTN_DATA_TAB_GATEA_TOTAL_ANOMALIES=", total_anomalies, "\n", sep = "")
cat("FTN_DATA_TAB_GATEA_TOTAL_LEAKAGE_MATCHES=", total_leakage_matches, "\n", sep = "")

for (row_idx in seq_len(nrow(summary_dt))) {
  row <- summary_dt[row_idx]
  prefix <- paste0("FTN_DATA_TAB_GATEA_", toupper(row$metric))
  cat(prefix, "_CHECKED_CONTEXTS=", row$checked_context_count, "\n", sep = "")
  cat(prefix, "_ANOMALIES=", row$anomaly_count, "\n", sep = "")
  cat(prefix, "_MISSING_SOURCE=", row$missing_source_count, "\n", sep = "")
  cat(prefix, "_SOURCE_EXACT_MISMATCH=", row$source_exact_mismatch_count, "\n", sep = "")
  cat(prefix, "_LEAKAGE_MATCHES=", row$leakage_match_count, "\n", sep = "")
}

if (nrow(anomaly_dt) > 0L) {
  preview_cols <- intersect(c(
    "metric", "reason", "Trade", "Group", "Subgroup", "MarketSegment", "CommodityName",
    "CommodityDetail", "countryDescription", "market_year", "analysis_month", "calendar_year", "calendar_month",
    "artifact_value", "source_exact_value", "source_broader_value", "delta_exact", "abs_delta_exact",
    "broader_segment_count", "matches_exact", "matches_broader", "leakage_match"
  ), names(anomaly_dt))
  preview_rows <- utils::head(anomaly_dt[, ..preview_cols], 12L)
  cat("FTN_DATA_TAB_GATEA_ANOMALY_PREVIEW_START\n")
  utils::write.table(preview_rows, row.names = FALSE, sep = "|", quote = FALSE)
  cat("FTN_DATA_TAB_GATEA_ANOMALY_PREVIEW_END\n")
  stop(paste0("Gate A failed with ", total_anomalies, " source-bounded rollup anomalies. See ", anomaly_path), call. = FALSE)
}

progress("status_pass")
