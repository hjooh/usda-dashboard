`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0L) y else x
}

parse_arg_value <- function(args, key, default = NULL) {
  prefix <- paste0("--", key, "=")
  hits <- args[startsWith(args, prefix)]
  if (length(hits) == 0L) return(default)
  sub(prefix, "", hits[[length(hits)]], fixed = TRUE)
}

is_truthy <- function(value, default = FALSE) {
  if (is.null(value) || length(value) == 0L || all(is.na(value))) return(default)
  normalized <- tolower(trimws(as.character(value[[1L]])))
  if (!nzchar(normalized)) return(default)
  normalized %in% c("1", "true", "yes", "y", "on")
}

resolve_repo_root <- function(start_dir = getwd()) {
  start_dir <- normalizePath(start_dir, winslash = "/", mustWork = FALSE)
  candidates <- vapply(0:8, function(level) {
    normalizePath(do.call(file.path, as.list(c(start_dir, rep("..", level)))), winslash = "/", mustWork = FALSE)
  }, character(1))

  for (candidate in unique(candidates)) {
    if (file.exists(file.path(candidate, "VP Clone", ".vp_clone_root"))) {
      return(candidate)
    }
    if (file.exists(file.path(candidate, ".vp_clone_root")) && basename(candidate) == "VP Clone") {
      return(dirname(candidate))
    }
  }

  stop("Could not resolve repository root for VP artifact load probe.", call. = FALSE)
}

to_int_ms <- function(start_time, end_time = Sys.time()) {
  elapsed_seconds <- suppressWarnings(as.numeric(difftime(end_time, start_time, units = "secs")))
  if (!is.finite(elapsed_seconds)) return(NA_integer_)
  as.integer(round(elapsed_seconds * 1000))
}

valid_cache_states <- c("cold_artifact", "warm_partition_disk", "warm_session", "unknown_cache_state")

normalize_cache_state <- function(value) {
  candidate <- trimws(as.character(value %||% "unknown_cache_state"))
  if (!nzchar(candidate) || !(candidate %in% valid_cache_states)) return("unknown_cache_state")
  candidate
}

source_shared_harmonization_utils <- function(repo_root) {
  shared_path <- file.path(repo_root, "VP Clone", "Programs", "shared_source_harmonization_utils.R")
  if (!file.exists(shared_path)) {
    stop(sprintf("Shared harmonization utilities file does not exist: %s", shared_path), call. = FALSE)
  }
  source(shared_path, local = .GlobalEnv)
  invisible(TRUE)
}

vp_artifact_builder_version <- "vp_trade_artifact_2026_07_28_v6"
vp_artifact_builder_floor <- "vp_trade_artifact_2026_07_28_v6"
vp_all_type_label <- "All"
vp_rollup_schema_version <- "vp_rollup_schema_2026_07_28_v1"

vp_rollup_required_fields <- function() {
  c("vp_rollup_level", "vp_rollup_path", "vp_is_rollup", "vp_volume_family_mixed", "vp_mixed_source_replacement", "vp_rollup_schema_version")
}

required_internal_metric_cols_probe <- function() {
  c(
    "monthlyexports", "monthlyexports_rough_eq",
    "ytd_exports", "ytd_exports_rough_eq",
    "total_commitment", "total_commitment_rough_eq",
    "outstandingSales", "outstandingSales_rough_eq",
    "grossNewSales", "grossNewSales_rough_eq",
    "currentMYNetSales", "currentMYNetSales_rough_eq",
    "nextMYOutstandingSales", "nextMYOutstandingSales_rough_eq",
    "nextMYNetSales", "nextMYNetSales_rough_eq"
  )
}

required_census_internal_metric_cols_probe <- function() {
  c(
    required_internal_metric_cols_probe(),
    "monthlyvalue", "monthlyvalue_rough_eq",
    "ytd_value", "ytd_value_rough_eq"
  )
}

vp_builder_version_rank <- function(version) {
  value <- trimws(as.character(version %||% ""))
  if (length(value) == 0L || !nzchar(value[[1L]])) return(NA_real_)
  value <- value[[1L]]

  match_groups <- regexec("([0-9]{4})_([0-9]{2})_([0-9]{2})_v([0-9]+)$", value)
  parts <- regmatches(value, match_groups)[[1L]]
  if (length(parts) != 5L) return(NA_real_)

  year <- suppressWarnings(as.integer(parts[[2L]]))
  month <- suppressWarnings(as.integer(parts[[3L]]))
  day <- suppressWarnings(as.integer(parts[[4L]]))
  patch <- suppressWarnings(as.integer(parts[[5L]]))
  if (!all(is.finite(c(year, month, day, patch)))) return(NA_real_)

  date_rank <- as.numeric(year) * 10000 + as.numeric(month) * 100 + as.numeric(day)
  date_rank * 1000 + as.numeric(patch)
}

resolve_vp_manifest_builder_version <- function(manifest_entry) {
  if (is.null(manifest_entry) || !is.list(manifest_entry)) {
    return(NA_character_)
  }

  entry_names <- trimws(as.character(manifest_entry$extra_signature_names %||% character(0)))
  entry_values <- trimws(as.character(manifest_entry$extra_signatures %||% character(0)))
  builder_idx <- which(entry_names == "builder_version")
  if (length(builder_idx) > 0 && length(entry_values) >= builder_idx[[1]]) {
    candidate <- entry_values[[builder_idx[[1]]]]
    if (!is.na(candidate) && nzchar(candidate)) {
      return(candidate)
    }
  }

  metadata <- manifest_entry$artifact_metadata
  metadata_builder <- trimws(as.character(metadata$builder_version %||% NA_character_))
  if (length(metadata_builder) > 0 && !is.na(metadata_builder[[1]]) && nzchar(metadata_builder[[1]])) {
    return(metadata_builder[[1]])
  }

  NA_character_
}

validate_vp_trade_rollup_contract_probe <- function(vp_data, project_dir, artifact_path) {
  required_cols <- unique(c(
    vp_rollup_required_fields(),
    c("Group", "Subgroup", "MarketSegment", "commodity", "Trade", "unit_value", "unit_value_unit", "ytd_unit_value", "ytd_unit_value_unit")
  ))
  missing_cols <- setdiff(required_cols, names(vp_data))
  if (length(missing_cols) > 0L) {
    stop(sprintf("VP trade artifact is missing required rollup fields: %s", paste(missing_cols, collapse = ", ")), call. = FALSE)
  }

  schema_values <- unique(trimws(as.character(vp_data$vp_rollup_schema_version %||% character(0))))
  schema_values <- schema_values[!is.na(schema_values) & nzchar(schema_values)]
  if (!(vp_rollup_schema_version %in% schema_values)) {
    stop(sprintf("VP trade artifact rollup schema mismatch. Expected %s.", vp_rollup_schema_version), call. = FALSE)
  }

  has_rollup_rows <- any(!is.na(vp_data$vp_is_rollup) & as.logical(vp_data$vp_is_rollup), na.rm = TRUE)
  has_required_levels <- all(c("segment_all", "subgroup_all", "group_all") %in% unique(trimws(as.character(vp_data$vp_rollup_level))))
  if (!isTRUE(has_rollup_rows) || !isTRUE(has_required_levels)) {
    stop("VP trade artifact rollup levels are incomplete.", call. = FALSE)
  }

  manifest_entry <- tryCatch(
    read_processed_artifact_manifest_entry(project_dir, artifact_path),
    error = function(...) NULL
  )
  builder_version <- resolve_vp_manifest_builder_version(manifest_entry)
  builder_rank <- vp_builder_version_rank(builder_version)
  floor_rank <- vp_builder_version_rank(vp_artifact_builder_floor)

  if (!is.finite(floor_rank)) {
    stop("VP startup builder floor configuration is invalid.", call. = FALSE)
  }
  if (!is.finite(builder_rank) || builder_rank < floor_rank) {
    stop(sprintf("VP trade artifact builder version is missing or below floor (artifact=%s, floor=%s).", builder_version %||% "<missing>", vp_artifact_builder_floor), call. = FALSE)
  }

  invisible(TRUE)
}

vp_partition_hash_probe <- function(values) {
  normalized <- trimws(as.character(values %||% character(0)))
  raw_values <- utf8ToInt(paste(normalized, collapse = "|"))
  if (length(raw_values) == 0L) return("0000000000000000")

  mod1 <- 2147483647
  mod2 <- 2147483629
  h1 <- 0
  h2 <- 0
  for (idx in seq_along(raw_values)) {
    value <- as.numeric(raw_values[[idx]])
    h1 <- (h1 * 131 + value + idx) %% mod1
    h2 <- (h2 * 137 + value + idx * 17) %% mod2
  }

  paste0(sprintf("%08x", as.integer(h1)), sprintf("%08x", as.integer(h2)))
}

vp_partition_source_fingerprint_probe <- function(vp_rows) {
  if (!is.data.frame(vp_rows) || nrow(vp_rows) == 0L) return("empty_source")
  fingerprint_columns <- intersect(
    c("Trade", "Group", "Subgroup", "MarketSegment", "CommodityName", "commodity", "date", "Year", "Month"),
    names(vp_rows)
  )
  if (length(fingerprint_columns) == 0L) fingerprint_columns <- names(vp_rows)[seq_len(min(4L, length(names(vp_rows))))]

  sample_count <- min(257L, nrow(vp_rows))
  sample_rows <- unique(as.integer(round(seq(1L, nrow(vp_rows), length.out = sample_count))))
  sampled_values <- unlist(
    lapply(fingerprint_columns, function(column_name) {
      paste(column_name, trimws(as.character(vp_rows[[column_name]][sample_rows] %||% "")), sep = "=")
    }),
    use.names = FALSE
  )

  vp_partition_hash_probe(c(nrow(vp_rows), ncol(vp_rows), names(vp_rows), sampled_values))
}

vp_partition_source_identity_probe <- function(vp_rows, artifact_path) {
  list(
    source_signature = build_file_signature(artifact_path),
    source_row_count = if (is.data.frame(vp_rows)) nrow(vp_rows) else NA_integer_,
    source_col_count = if (is.data.frame(vp_rows)) ncol(vp_rows) else NA_integer_,
    source_column_hash = if (is.data.frame(vp_rows)) vp_partition_hash_probe(names(vp_rows)) else "not_data_frame",
    source_row_order_fingerprint = vp_partition_source_fingerprint_probe(vp_rows)
  )
}

vp_partition_mark_canonical_source_probe <- function(vp_rows, artifact_path) {
  if (!is.data.frame(vp_rows)) return(vp_rows)
  attr(vp_rows, "vp_partition_canonical_source_token") <- paste(
    "vp_trade_monthly",
    vp_artifact_builder_version,
    basename(artifact_path),
    build_file_signature(artifact_path),
    sep = "|"
  )
  attr(vp_rows, "vp_partition_source_identity") <- vp_partition_source_identity_probe(vp_rows, artifact_path)
  vp_rows
}

timed_step <- function(expr) {
  start_time <- Sys.time()
  value <- force(expr)
  list(value = value, elapsed_ms = to_int_ms(start_time))
}

normalize_token_list <- function(value, default = character()) {
  if (is.null(value) || length(value) == 0L || all(is.na(value))) return(default)
  tokens <- unlist(strsplit(as.character(value[[1L]]), ",", fixed = TRUE), use.names = FALSE)
  tokens <- trimws(tokens)
  tokens[nzchar(tokens)]
}

probe_safe_file_token <- function(value) {
  token <- tolower(trimws(as.character(value %||% "artifact")))
  token <- gsub("[^a-z0-9_]+", "_", token)
  token <- gsub("(^_+|_+$)", "", token)
  if (!nzchar(token)) "artifact" else token
}

default_narrow_shape_columns <- function(artifact) {
  preferred <- unique(c(
    "Year", "Month", "date", "Trade", "Group", "Subgroup", "MarketSegment",
    "CommodityName", "CommodityDetail", "commodity", "partner", "Partner",
    "quantity", "quantity_unit", "unit_value", "unit_value_unit",
    "ytd_quantity", "ytd_quantity_unit", "ytd_unit_value", "ytd_unit_value_unit",
    vp_rollup_required_fields()
  ))
  intersect(preferred, names(artifact))
}

make_narrow_shape_artifact <- function(artifact, shape_columns = character()) {
  if (!is.data.frame(artifact)) return(artifact)
  columns <- unique(c(shape_columns, default_narrow_shape_columns(artifact)))
  columns <- intersect(columns, names(artifact))
  if (length(columns) == 0L) return(artifact[0L])
  artifact[, columns, drop = FALSE]
}

vp_startup_companion_required_columns <- function() {
  unique(c(
    required_census_internal_metric_cols_probe(),
    vp_rollup_required_fields(),
    "Group", "Subgroup", "MarketSegment", "CommodityName", "CommodityDetail", "commodity", "Trade",
    "country", "countryDescription",
    "market_year", "analysis_month", "MonthNum", "month_abbrev", "month_name", "calendar_signature",
    "calendar_year", "calendar_month", "month", "period_label", "report_date", "week_ending_date",
    "unit_value", "unit_value_unit", "ytd_unit_value", "ytd_unit_value_unit",
    "quantity", "quantity_unit", "ytd_quantity", "ytd_quantity_unit",
    "volume_unit_family", "source_volume_unit"
  ))
}

build_vp_startup_companion_artifact_probe <- function(artifact, shape_columns = character()) {
  if (!is.data.frame(artifact)) return(artifact)
  columns <- unique(c(vp_startup_companion_required_columns(), shape_columns))
  columns <- intersect(columns, names(artifact))
  artifact[, columns, drop = FALSE]
}

collapse_probe_values <- function(values, max_values = 60L) {
  values <- unique(trimws(as.character(values %||% character(0))))
  values <- values[!is.na(values) & nzchar(values)]
  if (length(values) == 0L) return(NA_character_)
  if (length(values) > max_values) values <- c(values[seq_len(max_values)], sprintf("...+%d", length(values) - max_values))
  paste(values, collapse = "|")
}

probe_display_month_mapping_rows <- function(rows) {
  required_cols <- c("analysis_month", "MonthNum", "month_abbrev", "month_name", "calendar_signature")
  if (!is.data.frame(rows) || !all(required_cols %in% names(rows)) || nrow(rows) == 0L) return(0L)

  work <- rows[!is.na(rows$analysis_month) & !is.na(rows$MonthNum) & !is.na(rows$month_abbrev) & !is.na(rows$month_name), required_cols, drop = FALSE]
  if (nrow(work) == 0L) return(0L)

  signatures <- trimws(as.character(work$calendar_signature))
  signatures <- signatures[!is.na(signatures) & nzchar(signatures)]
  if (length(signatures) > 0L) {
    dominant_signature <- names(sort(table(signatures), decreasing = TRUE))[[1L]]
    work <- work[trimws(as.character(work$calendar_signature)) == dominant_signature, , drop = FALSE]
  }

  work$analysis_month <- suppressWarnings(as.integer(work$analysis_month))
  work$MonthNum <- suppressWarnings(as.integer(work$MonthNum))
  work <- work[!is.na(work$analysis_month) & !is.na(work$MonthNum), , drop = FALSE]
  work <- work[order(work$analysis_month), , drop = FALSE]
  work <- work[!duplicated(work$analysis_month), , drop = FALSE]

  if (nrow(work) == 12L && identical(work$analysis_month, 1:12)) 12L else nrow(work)
}

probe_current_vs_average_smoke <- function(rows) {
  required_cols <- c("Trade", "country", "commodity", "market_year", "analysis_month", "monthlyexports")
  if (!is.data.frame(rows) || !all(required_cols %in% names(rows)) || nrow(rows) == 0L) {
    return(list(ok = FALSE, filtered_rows = 0L, recent_year = NA_real_, periods = 0L, reason = "missing_required_columns"))
  }

  work <- rows
  if ("Trade" %in% names(work)) {
    trade_rows <- work[trimws(as.character(work$Trade)) == "export", , drop = FALSE]
    if (nrow(trade_rows) > 0L) work <- trade_rows
  }
  if ("country" %in% names(work)) {
    country_values <- unique(trimws(as.character(work$country)))
    country_values <- country_values[!is.na(country_values) & nzchar(country_values)]
    country_choice <- if ("GRAND_TOTAL" %in% country_values) "GRAND_TOTAL" else country_values[[1L]]
    work <- work[trimws(as.character(work$country)) == country_choice, , drop = FALSE]
  }
  if ("commodity" %in% names(work)) {
    commodity_values <- unique(trimws(as.character(work$commodity)))
    commodity_values <- commodity_values[!is.na(commodity_values) & nzchar(commodity_values)]
    commodity_choice <- if (vp_all_type_label %in% commodity_values) vp_all_type_label else commodity_values[[1L]]
    work <- work[trimws(as.character(work$commodity)) == commodity_choice, , drop = FALSE]
  }

  if (nrow(work) == 0L) {
    return(list(ok = FALSE, filtered_rows = 0L, recent_year = NA_real_, periods = 0L, reason = "empty_after_default_filter"))
  }

  recent_year <- suppressWarnings(max(as.numeric(work$market_year), na.rm = TRUE))
  if (!is.finite(recent_year)) {
    return(list(ok = FALSE, filtered_rows = nrow(work), recent_year = NA_real_, periods = 0L, reason = "missing_recent_year"))
  }
  recent_rows <- work[suppressWarnings(as.numeric(work$market_year)) == recent_year, , drop = FALSE]
  periods <- sort(unique(suppressWarnings(as.integer(recent_rows$analysis_month))))
  periods <- periods[!is.na(periods)]
  metric_values <- suppressWarnings(as.numeric(work$monthlyexports))
  has_signal <- any(!is.na(metric_values) & metric_values != 0)

  list(
    ok = isTRUE(length(periods) > 0L && has_signal),
    filtered_rows = nrow(work),
    recent_year = recent_year,
    periods = length(periods),
    reason = if (has_signal) "ok" else "no_metric_signal"
  )
}

probe_companion_artifact_contract <- function(artifact_path, cache_state, label, output_root, cleanup, shape_columns = character()) {
  artifact_path <- normalizePath(artifact_path, winslash = "/", mustWork = FALSE)
  if (!file.exists(artifact_path)) {
    stop(sprintf("Artifact file does not exist: %s", artifact_path), call. = FALSE)
  }

  timestamp_token <- format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC")
  output_dir <- file.path(output_root, paste0(probe_safe_file_token(label), "_", timestamp_token))
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

  baseline_read_step <- timed_step(readRDS(artifact_path))
  artifact <- baseline_read_step$value
  companion <- build_vp_startup_companion_artifact_probe(artifact, shape_columns = shape_columns)
  candidate_path <- file.path(output_dir, "vp_trade_startup_companion_candidate_uncompressed.rds")

  missing_global_contract_cols <- setdiff(required_census_internal_metric_cols_probe(), names(companion))
  missing_rollup_contract_cols <- setdiff(vp_rollup_required_fields(), names(companion))
  missing_current_view_cols <- setdiff(
    c("Trade", "Group", "Subgroup", "MarketSegment", "CommodityName", "commodity", "country", "countryDescription", "market_year", "analysis_month", "monthlyexports"),
    names(companion)
  )
  missing_display_month_cols <- setdiff(c("analysis_month", "MonthNum", "month_abbrev", "month_name", "calendar_signature"), names(companion))
  missing_quantity_context_cols <- setdiff(c("vp_volume_family_mixed", "volume_unit_family", "source_volume_unit"), names(companion))

  rollup_contract_status <- "PASS"
  rollup_contract_error <- NA_character_
  tryCatch(
    validate_vp_trade_rollup_contract_probe(companion, project_dir = dirname(dirname(dirname(artifact_path))), artifact_path = artifact_path),
    error = function(error) {
      rollup_contract_status <<- "FAIL"
      rollup_contract_error <<- conditionMessage(error)
    }
  )

  display_month_rows <- probe_display_month_mapping_rows(companion)
  current_smoke <- probe_current_vs_average_smoke(companion)
  full_identity <- vp_partition_source_identity_probe(artifact, artifact_path = artifact_path)
  companion_identity <- vp_partition_source_identity_probe(companion, artifact_path = artifact_path)
  provider_full_replacement_safe <- identical(full_identity, companion_identity)
  omitted_columns <- setdiff(names(artifact), names(companion))

  write_step <- timed_step(saveRDS(companion, candidate_path, compress = FALSE))
  candidate_info <- file.info(candidate_path)
  read_step <- timed_step(readRDS(candidate_path))
  read_companion <- read_step$value
  candidate_exists_after_cleanup <- file.exists(candidate_path)
  cleanup_status <- "kept"
  if (isTRUE(cleanup)) {
    cleanup_status <- tryCatch({
      if (file.exists(candidate_path)) unlink(candidate_path, force = TRUE)
      if (file.exists(candidate_path)) "failed" else "removed"
    }, error = function(error) paste("error", conditionMessage(error), sep = ": "))
    candidate_exists_after_cleanup <- file.exists(candidate_path)
    remaining_files <- list.files(output_dir, all.files = FALSE, no.. = TRUE)
    if (length(remaining_files) == 0L) unlink(output_dir, recursive = TRUE, force = TRUE)
  }

  source_object_size_mb <- as.numeric(utils::object.size(artifact)) / (1024 * 1024)
  companion_object_size_mb <- as.numeric(utils::object.size(companion)) / (1024 * 1024)
  candidate_size_mb <- as.numeric(candidate_info$size[[1L]]) / (1024 * 1024)

  row <- data.frame(
    status = if (identical(rollup_contract_status, "PASS") && length(missing_global_contract_cols) == 0L && length(missing_current_view_cols) == 0L && isTRUE(current_smoke$ok)) "PASS" else "WARN",
    error_message = NA_character_,
    cache_state = cache_state,
    process_id = Sys.getpid(),
    source_artifact_path = artifact_path,
    candidate_artifact_path = normalizePath(candidate_path, winslash = "/", mustWork = FALSE),
    cleanup_status = cleanup_status,
    candidate_exists_after_cleanup = candidate_exists_after_cleanup,
    baseline_read_elapsed_ms = baseline_read_step$elapsed_ms,
    candidate_write_elapsed_ms = write_step$elapsed_ms,
    candidate_read_elapsed_ms = read_step$elapsed_ms,
    read_speedup_vs_current = if (is.finite(read_step$elapsed_ms) && read_step$elapsed_ms > 0) baseline_read_step$elapsed_ms / read_step$elapsed_ms else NA_real_,
    source_rows = nrow(artifact),
    source_cols = ncol(artifact),
    source_object_size_mb = source_object_size_mb,
    companion_rows = nrow(companion),
    companion_cols = ncol(companion),
    companion_object_size_mb = companion_object_size_mb,
    companion_object_size_ratio = companion_object_size_mb / source_object_size_mb,
    candidate_file_size_mb = candidate_size_mb,
    source_current_file_size_mb = as.numeric(file.info(artifact_path)$size[[1L]]) / (1024 * 1024),
    rollup_contract_status = rollup_contract_status,
    rollup_contract_error = rollup_contract_error,
    missing_global_contract_cols = collapse_probe_values(missing_global_contract_cols),
    missing_rollup_contract_cols = collapse_probe_values(missing_rollup_contract_cols),
    missing_current_view_cols = collapse_probe_values(missing_current_view_cols),
    missing_display_month_cols = collapse_probe_values(missing_display_month_cols),
    missing_quantity_context_cols = collapse_probe_values(missing_quantity_context_cols),
    display_month_mapping_rows = display_month_rows,
    current_view_smoke_ok = isTRUE(current_smoke$ok),
    current_view_smoke_reason = current_smoke$reason %||% NA_character_,
    current_view_filtered_rows = current_smoke$filtered_rows %||% NA_integer_,
    current_view_recent_year = current_smoke$recent_year %||% NA_real_,
    current_view_periods = current_smoke$periods %||% NA_integer_,
    provider_full_replacement_safe = provider_full_replacement_safe,
    provider_identity_reason = if (isTRUE(provider_full_replacement_safe)) "identity_matches_full_source" else "source_identity_changes_expected_for_companion",
    omitted_columns_count = length(omitted_columns),
    omitted_columns = collapse_probe_values(omitted_columns),
    companion_columns = collapse_probe_values(names(companion), max_values = 120L),
    read_back_rows = if (is.data.frame(read_companion)) nrow(read_companion) else NA_integer_,
    read_back_cols = if (is.data.frame(read_companion)) ncol(read_companion) else NA_integer_,
    stringsAsFactors = FALSE
  )

  rm(artifact, companion, read_companion)
  invisible(gc())
  row
}

serialization_variant_spec <- function(variant_name, artifact, shape_columns = character()) {
  switch(
    variant_name,
    existing_current = list(
      variant_name = "existing_current",
      artifact_shape = "current_full",
      serialization = "existing_rds",
      compress_arg = "existing",
      object = artifact,
      should_write = FALSE
    ),
    full_uncompressed = list(
      variant_name = "full_uncompressed",
      artifact_shape = "full",
      serialization = "rds",
      compress_arg = "FALSE",
      object = artifact,
      should_write = TRUE,
      compress = FALSE
    ),
    full_gzip = list(
      variant_name = "full_gzip",
      artifact_shape = "full",
      serialization = "rds",
      compress_arg = "gzip",
      object = artifact,
      should_write = TRUE,
      compress = "gzip"
    ),
    narrow_uncompressed = list(
      variant_name = "narrow_uncompressed",
      artifact_shape = "narrow_default_columns",
      serialization = "rds",
      compress_arg = "FALSE",
      object = make_narrow_shape_artifact(artifact, shape_columns = shape_columns),
      should_write = TRUE,
      compress = FALSE
    ),
    narrow_gzip = list(
      variant_name = "narrow_gzip",
      artifact_shape = "narrow_default_columns",
      serialization = "rds",
      compress_arg = "gzip",
      object = make_narrow_shape_artifact(artifact, shape_columns = shape_columns),
      should_write = TRUE,
      compress = "gzip"
    ),
    stop(sprintf("Unknown serialization A/B variant: %s", variant_name), call. = FALSE)
  )
}

probe_serialization_variant <- function(spec, artifact_path, output_dir, cache_state, baseline_read_elapsed_ms, baseline_file_size_mb, cleanup) {
  status <- "PASS"
  error_message <- NA_character_
  write_elapsed_ms <- NA_integer_
  read_elapsed_ms <- NA_integer_
  cleanup_status <- "not_applicable"
  variant_path <- artifact_path
  read_object <- NULL
  variant_info <- NULL
  start_time <- Sys.time()

  tryCatch({
    if (isTRUE(spec$should_write)) {
      variant_path <- file.path(output_dir, paste0(spec$variant_name, ".rds"))
      write_step <- timed_step(saveRDS(spec$object, variant_path, compress = spec$compress))
      write_elapsed_ms <- write_step$elapsed_ms
      variant_info <- file.info(variant_path)

      read_step <- timed_step(readRDS(variant_path))
      read_object <- read_step$value
      read_elapsed_ms <- read_step$elapsed_ms
    } else {
      read_elapsed_ms <- baseline_read_elapsed_ms
      variant_info <- file.info(variant_path)
      read_object <- spec$object
    }
  }, error = function(error) {
    status <<- "FAIL"
    error_message <<- conditionMessage(error)
  })

  is_data_frame <- is.data.frame(read_object)
  file_size_mb <- if (!is.null(variant_info) && nrow(variant_info) > 0L && !is.na(variant_info$size[[1L]])) {
    as.numeric(variant_info$size[[1L]]) / (1024 * 1024)
  } else {
    NA_real_
  }

  if (isTRUE(spec$should_write) && isTRUE(cleanup)) {
    cleanup_status <- tryCatch({
      if (file.exists(variant_path)) unlink(variant_path, force = TRUE)
      if (file.exists(variant_path)) "failed" else "removed"
    }, error = function(error) paste("error", conditionMessage(error), sep = ": "))
  } else if (isTRUE(spec$should_write)) {
    cleanup_status <- "kept"
  }

  row <- data.frame(
    variant_name = spec$variant_name,
    status = status,
    error_message = error_message,
    cache_state = cache_state,
    process_id = Sys.getpid(),
    artifact_shape = spec$artifact_shape,
    serialization = spec$serialization,
    compress_arg = spec$compress_arg,
    source_artifact_path = normalizePath(artifact_path, winslash = "/", mustWork = FALSE),
    variant_artifact_path = normalizePath(variant_path, winslash = "/", mustWork = FALSE),
    variant_file_exists_after_cleanup = file.exists(variant_path),
    cleanup_status = cleanup_status,
    write_elapsed_ms = write_elapsed_ms,
    read_elapsed_ms = read_elapsed_ms,
    total_elapsed_ms = to_int_ms(start_time),
    file_size_mb = file_size_mb,
    file_size_ratio_vs_current = if (is.finite(file_size_mb) && is.finite(baseline_file_size_mb) && baseline_file_size_mb > 0) file_size_mb / baseline_file_size_mb else NA_real_,
    read_speedup_vs_current = if (is.finite(read_elapsed_ms) && is.finite(baseline_read_elapsed_ms) && read_elapsed_ms > 0) baseline_read_elapsed_ms / read_elapsed_ms else NA_real_,
    rows = if (isTRUE(is_data_frame)) nrow(read_object) else NA_integer_,
    cols = if (isTRUE(is_data_frame)) ncol(read_object) else NA_integer_,
    object_size_mb = if (!is.null(read_object)) as.numeric(utils::object.size(read_object)) / (1024 * 1024) else NA_real_,
    class = if (!is.null(read_object)) paste(class(read_object), collapse = "|") else NA_character_,
    stringsAsFactors = FALSE
  )

  rm(read_object)
  invisible(gc())
  row
}

probe_serialization_ab <- function(artifact_path, cache_state, label, output_root, variants, cleanup, shape_columns = character()) {
  artifact_path <- normalizePath(artifact_path, winslash = "/", mustWork = FALSE)
  if (!file.exists(artifact_path)) {
    stop(sprintf("Artifact file does not exist: %s", artifact_path), call. = FALSE)
  }

  timestamp_token <- format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC")
  output_dir <- file.path(output_root, paste0(probe_safe_file_token(label), "_", timestamp_token))
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

  baseline_info <- file.info(artifact_path)
  baseline_file_size_mb <- as.numeric(baseline_info$size[[1L]]) / (1024 * 1024)
  baseline_read_step <- timed_step(readRDS(artifact_path))
  artifact <- baseline_read_step$value
  baseline_read_elapsed_ms <- baseline_read_step$elapsed_ms

  variant_names <- unique(c("existing_current", variants))
  rows <- lapply(variant_names, function(variant_name) {
    spec <- serialization_variant_spec(variant_name, artifact = artifact, shape_columns = shape_columns)
    probe_serialization_variant(
      spec = spec,
      artifact_path = artifact_path,
      output_dir = output_dir,
      cache_state = cache_state,
      baseline_read_elapsed_ms = baseline_read_elapsed_ms,
      baseline_file_size_mb = baseline_file_size_mb,
      cleanup = cleanup
    )
  })

  rm(artifact)
  invisible(gc())

  raw_df <- do.call(rbind, rows)
  if (isTRUE(cleanup)) {
    remaining_files <- list.files(output_dir, all.files = FALSE, no.. = TRUE)
    if (length(remaining_files) == 0L) unlink(output_dir, recursive = TRUE, force = TRUE)
  }
  raw_df
}

probe_artifact_load <- function(artifact_path, metadata_path, source_path, cache_state, run_index, project_dir, decompose) {
  artifact_path <- normalizePath(artifact_path, winslash = "/", mustWork = FALSE)
  metadata_path <- normalizePath(metadata_path, winslash = "/", mustWork = FALSE)
  source_path <- normalizePath(source_path, winslash = "/", mustWork = FALSE)
  artifact_info <- if (file.exists(artifact_path)) file.info(artifact_path) else NULL
  metadata_info <- if (file.exists(metadata_path)) file.info(metadata_path) else NULL

  start_time <- Sys.time()
  status <- "PASS"
  error_message <- NA_character_
  artifact <- NULL
  currentity <- NULL
  currentity_elapsed_ms <- NA_integer_
  read_elapsed_ms <- NA_integer_
  contract_validation_elapsed_ms <- NA_integer_
  canonical_mark_elapsed_ms <- NA_integer_
  artifact_signature_elapsed_ms <- NA_integer_
  source_signature_elapsed_ms <- NA_integer_
  metadata_signature_elapsed_ms <- NA_integer_
  cache_version_signature_sample_elapsed_ms <- NA_integer_
  artifact_signature <- NA_character_
  source_signature <- NA_character_
  metadata_signature <- NA_character_
  marked_object_size_mb <- NA_real_

  tryCatch({
    if (!file.exists(artifact_path)) {
      stop(sprintf("Artifact file does not exist: %s", artifact_path), call. = FALSE)
    }
    if (isTRUE(decompose)) {
      if (exists("clear_file_signature_cache", mode = "function")) clear_file_signature_cache()
      currentity_step <- timed_step(diagnose_processed_artifact_currentity(
        artifact_path = artifact_path,
        project_dir = project_dir,
        source_paths = source_path,
        extra_signatures = c(builder_version = vp_artifact_builder_version)
      ))
      currentity <- currentity_step$value
      currentity_elapsed_ms <- currentity_step$elapsed_ms
      if (!isTRUE(currentity$current)) {
        stop(sprintf("Artifact is not current: %s", currentity$reason %||% "unknown"), call. = FALSE)
      }

      read_step <- timed_step(readRDS(artifact_path))
      artifact <- read_step$value
      read_elapsed_ms <- read_step$elapsed_ms

      contract_step <- timed_step(validate_vp_trade_rollup_contract_probe(artifact, project_dir = project_dir, artifact_path = artifact_path))
      contract_validation_elapsed_ms <- contract_step$elapsed_ms

      canonical_step <- timed_step(vp_partition_mark_canonical_source_probe(artifact, artifact_path = artifact_path))
      artifact <- canonical_step$value
      canonical_mark_elapsed_ms <- canonical_step$elapsed_ms
      marked_object_size_mb <- as.numeric(utils::object.size(artifact)) / (1024 * 1024)

      artifact_signature_step <- timed_step(build_file_signature(artifact_path))
      artifact_signature <- artifact_signature_step$value
      artifact_signature_elapsed_ms <- artifact_signature_step$elapsed_ms

      source_signature_step <- timed_step(build_file_signature(source_path))
      source_signature <- source_signature_step$value
      source_signature_elapsed_ms <- source_signature_step$elapsed_ms

      metadata_signature_step <- timed_step(build_file_signature(metadata_path))
      metadata_signature <- metadata_signature_step$value
      metadata_signature_elapsed_ms <- metadata_signature_step$elapsed_ms

      cache_version_signature_sample_elapsed_ms <- sum(c(artifact_signature_elapsed_ms, source_signature_elapsed_ms, metadata_signature_elapsed_ms), na.rm = TRUE)
    } else {
      read_step <- timed_step(readRDS(artifact_path))
      artifact <- read_step$value
      read_elapsed_ms <- read_step$elapsed_ms
    }
  }, error = function(error) {
    status <<- "FAIL"
    error_message <<- conditionMessage(error)
  })

  total_elapsed_ms <- to_int_ms(start_time)
  is_data_frame <- is.data.frame(artifact)

  data.frame(
    run_index = run_index,
    status = status,
    error_message = error_message,
    cache_state = cache_state,
    decompose = isTRUE(decompose),
    process_id = Sys.getpid(),
    artifact_path = artifact_path,
    artifact_exists = file.exists(artifact_path),
    artifact_size_mb = if (!is.null(artifact_info)) as.numeric(artifact_info$size) / (1024 * 1024) else NA_real_,
    artifact_modified_time = if (!is.null(artifact_info)) as.character(artifact_info$mtime) else NA_character_,
    metadata_path = metadata_path,
    metadata_exists = file.exists(metadata_path),
    metadata_size_mb = if (!is.null(metadata_info)) as.numeric(metadata_info$size) / (1024 * 1024) else NA_real_,
    source_path = source_path,
    source_exists = file.exists(source_path),
    source_size_mb = if (file.exists(source_path)) as.numeric(file.info(source_path)$size) / (1024 * 1024) else NA_real_,
    currentity_elapsed_ms = currentity_elapsed_ms,
    currentity_current = isTRUE(currentity$current),
    currentity_reason = currentity$reason %||% NA_character_,
    read_elapsed_ms = read_elapsed_ms,
    contract_validation_elapsed_ms = contract_validation_elapsed_ms,
    canonical_mark_elapsed_ms = canonical_mark_elapsed_ms,
    artifact_signature_elapsed_ms = artifact_signature_elapsed_ms,
    source_signature_elapsed_ms = source_signature_elapsed_ms,
    metadata_signature_elapsed_ms = metadata_signature_elapsed_ms,
    cache_version_signature_sample_elapsed_ms = cache_version_signature_sample_elapsed_ms,
    total_elapsed_ms = total_elapsed_ms,
    rows = if (isTRUE(is_data_frame)) nrow(artifact) else NA_integer_,
    cols = if (isTRUE(is_data_frame)) ncol(artifact) else NA_integer_,
    object_size_mb = if (!is.null(artifact)) as.numeric(utils::object.size(artifact)) / (1024 * 1024) else NA_real_,
    marked_object_size_mb = marked_object_size_mb,
    artifact_signature_prefix = substr(artifact_signature, 1L, 24L),
    source_signature_prefix = substr(source_signature, 1L, 24L),
    metadata_signature_prefix = substr(metadata_signature, 1L, 24L),
    class = if (!is.null(artifact)) paste(class(artifact), collapse = "|") else NA_character_,
    stringsAsFactors = FALSE
  )
}

main <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  repo_root <- resolve_repo_root(getwd())
  source_shared_harmonization_utils(repo_root)
  vp_clone_dir <- file.path(repo_root, "VP Clone")
  logs_dir <- file.path(vp_clone_dir, "Logs")
  dir.create(logs_dir, recursive = TRUE, showWarnings = FALSE)

  label <- trimws(as.character(parse_arg_value(args, "label", default = "artifact_load")))
  if (!nzchar(label)) label <- "artifact_load"
  runs <- suppressWarnings(as.integer(parse_arg_value(args, "runs", default = "1")))
  if (!is.finite(runs) || is.na(runs) || runs < 1L) runs <- 1L
  cache_state <- normalize_cache_state(parse_arg_value(args, "cache-state", default = "unknown_cache_state"))
  decompose <- is_truthy(parse_arg_value(args, "decompose", default = "true"), default = TRUE)
  serialization_ab <- is_truthy(parse_arg_value(args, "serialization-ab", default = "false"), default = FALSE)
  companion_contract <- is_truthy(parse_arg_value(args, "companion-contract", default = "false"), default = FALSE)
  ab_cleanup <- is_truthy(parse_arg_value(args, "ab-cleanup", default = "true"), default = TRUE)
  ab_variants <- normalize_token_list(
    parse_arg_value(args, "ab-variants", default = "full_uncompressed,narrow_uncompressed"),
    default = c("full_uncompressed", "narrow_uncompressed")
  )
  shape_columns <- normalize_token_list(parse_arg_value(args, "shape-columns", default = ""), default = character())

  artifact_path <- parse_arg_value(
    args,
    "artifact",
    default = file.path(vp_clone_dir, "System", "Processed Data", "vp_trade_monthly_pre.rds")
  )
  metadata_path <- parse_arg_value(
    args,
    "metadata",
    default = file.path(vp_clone_dir, "System", "Processed Data", "vp_trade_metadata_pre.rds")
  )
  source_path <- parse_arg_value(
    args,
    "source",
    default = file.path(vp_clone_dir, "Input", "veg-trade-data.csv")
  )
  ab_output_root <- parse_arg_value(
    args,
    "ab-output-root",
    default = file.path(logs_dir, "vp_perf_artifact_serialization_ab_disposable")
  )
  companion_output_root <- parse_arg_value(
    args,
    "companion-output-root",
    default = file.path(logs_dir, "vp_perf_artifact_companion_contract_disposable")
  )

  timestamp_token <- format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC")
  raw_path <- file.path(logs_dir, paste0("vp_perf_probe_artifact_load_", label, "_", timestamp_token, ".csv"))

  cat("VP_PERF_ARTIFACT_LOAD_PROBE_START\n")
  cat(sprintf("VP_PERF_ARTIFACT_LOAD_LABEL=%s\n", label))
  cat(sprintf("VP_PERF_ARTIFACT_LOAD_RUNS=%d\n", runs))
  cat(sprintf("VP_PERF_ARTIFACT_LOAD_CACHE_STATE=%s\n", cache_state))
  cat(sprintf("VP_PERF_ARTIFACT_LOAD_DECOMPOSE=%s\n", if (isTRUE(decompose)) "TRUE" else "FALSE"))

  if (isTRUE(companion_contract)) {
    cat("VP_PERF_ARTIFACT_LOAD_MODE=companion_contract\n")
    cat(sprintf("VP_PERF_ARTIFACT_LOAD_COMPANION_CLEANUP=%s\n", if (isTRUE(ab_cleanup)) "TRUE" else "FALSE"))
    cat(sprintf("VP_PERF_ARTIFACT_LOAD_COMPANION_OUTPUT_ROOT=%s\n", normalizePath(companion_output_root, winslash = "/", mustWork = FALSE)))

    raw_df <- probe_companion_artifact_contract(
      artifact_path = artifact_path,
      cache_state = cache_state,
      label = label,
      output_root = companion_output_root,
      cleanup = ab_cleanup,
      shape_columns = shape_columns
    )
    utils::write.csv(raw_df, raw_path, row.names = FALSE)

    cat(sprintf(
      "VP_PERF_ARTIFACT_LOAD_COMPANION_RESULT=%s|baseline_read=%sms|candidate_read=%sms|cols=%s|provider_full_replacement_safe=%s|cleanup=%s\n",
      raw_df$status[[1L]],
      raw_df$baseline_read_elapsed_ms[[1L]],
      raw_df$candidate_read_elapsed_ms[[1L]],
      raw_df$companion_cols[[1L]],
      raw_df$provider_full_replacement_safe[[1L]],
      raw_df$cleanup_status[[1L]]
    ))
    if (!identical(raw_df$rollup_contract_status[[1L]], "PASS")) {
      cat(sprintf("VP_PERF_ARTIFACT_LOAD_COMPANION_ROLLUP_ERROR=%s\n", raw_df$rollup_contract_error[[1L]]))
    }

    cat(sprintf("VP_PERF_ARTIFACT_LOAD_OUTPUT=%s\n", normalizePath(raw_path, winslash = "/", mustWork = FALSE)))
    cat("VP_PERF_ARTIFACT_LOAD_PROBE_COMPLETE\n")
    return(invisible(raw_df))
  }

  if (isTRUE(serialization_ab)) {
    cat("VP_PERF_ARTIFACT_LOAD_MODE=serialization_ab\n")
    cat(sprintf("VP_PERF_ARTIFACT_LOAD_AB_VARIANTS=%s\n", paste(unique(c("existing_current", ab_variants)), collapse = ",")))
    cat(sprintf("VP_PERF_ARTIFACT_LOAD_AB_CLEANUP=%s\n", if (isTRUE(ab_cleanup)) "TRUE" else "FALSE"))
    cat(sprintf("VP_PERF_ARTIFACT_LOAD_AB_OUTPUT_ROOT=%s\n", normalizePath(ab_output_root, winslash = "/", mustWork = FALSE)))

    raw_df <- probe_serialization_ab(
      artifact_path = artifact_path,
      cache_state = cache_state,
      label = label,
      output_root = ab_output_root,
      variants = ab_variants,
      cleanup = ab_cleanup,
      shape_columns = shape_columns
    )
    utils::write.csv(raw_df, raw_path, row.names = FALSE)

    for (row_index in seq_len(nrow(raw_df))) {
      cat(sprintf(
        "VP_PERF_ARTIFACT_LOAD_AB_RESULT=%s|%s|write=%sms|read=%sms|size=%sMB|cleanup=%s\n",
        raw_df$variant_name[[row_index]],
        raw_df$status[[row_index]],
        raw_df$write_elapsed_ms[[row_index]],
        raw_df$read_elapsed_ms[[row_index]],
        round(raw_df$file_size_mb[[row_index]], 3),
        raw_df$cleanup_status[[row_index]]
      ))
    }

    cat(sprintf("VP_PERF_ARTIFACT_LOAD_OUTPUT=%s\n", normalizePath(raw_path, winslash = "/", mustWork = FALSE)))
    cat("VP_PERF_ARTIFACT_LOAD_PROBE_COMPLETE\n")
    return(invisible(raw_df))
  }

  rows <- lapply(seq_len(runs), function(run_index) {
    cat(sprintf("VP_PERF_ARTIFACT_LOAD_RUN_BEGIN=%d\n", run_index))
    row <- probe_artifact_load(
      artifact_path = artifact_path,
      metadata_path = metadata_path,
      source_path = source_path,
      cache_state = cache_state,
      run_index = run_index,
      project_dir = vp_clone_dir,
      decompose = decompose
    )
    cat(sprintf(
      "VP_PERF_ARTIFACT_LOAD_RUN_STATUS=%d|%s|read=%sms|total=%sms\n",
      run_index,
      row$status[[1L]],
      row$read_elapsed_ms[[1L]],
      row$total_elapsed_ms[[1L]]
    ))
    if (identical(row$status[[1L]], "FAIL")) {
      cat(sprintf("VP_PERF_ARTIFACT_LOAD_RUN_ERROR=%d|%s\n", run_index, row$error_message[[1L]]))
    }
    row
  })

  raw_df <- do.call(rbind, rows)
  utils::write.csv(raw_df, raw_path, row.names = FALSE)

  cat(sprintf("VP_PERF_ARTIFACT_LOAD_OUTPUT=%s\n", normalizePath(raw_path, winslash = "/", mustWork = FALSE)))
  cat("VP_PERF_ARTIFACT_LOAD_PROBE_COMPLETE\n")
}

main()