library(shiny)
library(tidyverse)
library(DT)
library(plotly)

format_perf_detail_value <- function(value) {
  if (length(value) == 0 || is.null(value)) return("null")

  value <- value[[1]]
  if (is.na(value)) return("NA")
  if (inherits(value, "POSIXt")) return(format(value, tz = "UTC", usetz = TRUE))

  as.character(value)
}

perf_elapsed_ms <- function(start_time, end_time = Sys.time()) {
  if (is.null(start_time)) return(NA_integer_)

  elapsed_seconds <- suppressWarnings(as.numeric(difftime(end_time, start_time, units = "secs")))
  if (!is.finite(elapsed_seconds)) return(NA_integer_)

  as.integer(round(elapsed_seconds * 1000))
}

perf_log_enabled <- function() {
  isTRUE(getOption("vp_perf_log", default = FALSE)) ||
    isTRUE(getOption("almond_perf_log", default = FALSE)) ||
    isTRUE(getOption("rice_perf_log", default = FALSE))
}

perf_truthy <- function(value, default = FALSE) {
  if (is.null(value) || length(value) == 0 || all(is.na(value))) return(default)
  normalized <- tolower(trimws(as.character(value[[1]])))
  if (!nzchar(normalized)) return(default)
  normalized %in% c("1", "true", "yes", "y", "on")
}

runtime_perf_enabled <- function() {
  isTRUE(getOption("vp_perf_runtime", default = FALSE)) ||
    isTRUE(getOption("almond_perf_runtime", default = FALSE)) ||
    isTRUE(getOption("rice_perf_runtime", default = FALSE)) ||
    perf_truthy(Sys.getenv("VP_PERF_RUNTIME", unset = ""), default = FALSE)
}

perf_boundary_markers_enabled <- function() {
  isTRUE(getOption("vp_perf_boundary_markers", default = FALSE)) ||
    isTRUE(getOption("almond_perf_boundary_markers", default = FALSE)) ||
    isTRUE(getOption("rice_perf_boundary_markers", default = FALSE)) ||
    perf_truthy(Sys.getenv("VP_PERF_BOUNDARY_MARKERS", unset = ""), default = FALSE)
}

runtime_perf_session_id <- function(session = NULL) {
  if (!is.null(session) && !is.null(session$userData)) {
    existing_id <- session$userData$runtime_perf_session_id
    if (is.character(existing_id) && length(existing_id) > 0L && nzchar(existing_id[[1L]])) {
      return(existing_id[[1L]])
    }

    session_token <- tryCatch(as.character(session$token %||% ""), error = function(...) "")
    session_token <- trimws(session_token)
    if (!nzchar(session_token)) {
      session_token <- sprintf("sess_%s", as.integer(stats::runif(1L, min = 1e7, max = 9e7)))
    }
    session$userData$runtime_perf_session_id <- session_token
    return(session_token)
  }

  existing_id <- getOption("vp_perf_runtime_session_id", default = "")
  existing_id <- trimws(as.character(existing_id %||% ""))
  if (nzchar(existing_id)) {
    return(existing_id)
  }

  generated_id <- paste0(
    "proc_",
    format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC"),
    "_",
    Sys.getpid()
  )
  options(vp_perf_runtime_session_id = generated_id)
  generated_id
}

runtime_perf_project_root <- function() {
  candidate <- ""
  if (exists("base_dir", inherits = TRUE)) {
    candidate <- tryCatch(get("base_dir", inherits = TRUE), error = function(...) "")
  }
  candidate <- trimws(as.character(candidate %||% ""))
  if (nzchar(candidate)) {
    return(normalizePath(candidate, winslash = "/", mustWork = FALSE))
  }

  normalizePath(getwd(), winslash = "/", mustWork = FALSE)
}

runtime_perf_log_path <- function(session = NULL) {
  option_override <- getOption("vp_perf_runtime_log_file", default = "")
  env_override <- Sys.getenv("VP_PERF_RUNTIME_LOG_FILE", unset = "")
  path_override <- trimws(as.character(option_override %||% ""))
  if (!nzchar(path_override)) {
    path_override <- trimws(as.character(env_override %||% ""))
  }
  if (nzchar(path_override)) {
    return(normalizePath(path_override, winslash = "/", mustWork = FALSE))
  }

  root <- runtime_perf_project_root()
  session_id <- gsub("[^A-Za-z0-9_-]", "_", runtime_perf_session_id(session = session))
  file.path(root, "Logs", paste0("vp_runtime_perf_", session_id, ".jsonl"))
}

runtime_perf_memory_mode <- function() {
  option_override <- getOption("vp_perf_runtime_memory_mode", default = NULL)
  env_override <- Sys.getenv("VP_PERF_RUNTIME_MEMORY_MODE", unset = "")
  raw_mode <- trimws(as.character(option_override %||% env_override %||% ""))
  if (!nzchar(raw_mode)) return("off")

  normalized <- tolower(raw_mode[[1L]])
  if (normalized %in% c("full", "always", "all", "true", "1", "yes", "on")) return("full")
  if (normalized %in% c("sample", "sampled", "sampling")) return("sample")
  "off"
}

runtime_perf_memory_sample_interval <- function() {
  option_override <- getOption("vp_perf_runtime_memory_sample_interval", default = NULL)
  env_override <- Sys.getenv("VP_PERF_RUNTIME_MEMORY_SAMPLE_INTERVAL", unset = "")
  raw_interval <- trimws(as.character(option_override %||% env_override %||% ""))
  interval <- suppressWarnings(as.integer(raw_interval[[1L]] %||% NA_integer_))
  if (!is.finite(interval) || is.na(interval) || interval < 1L) return(25L)
  interval
}

runtime_perf_memory_event_count <- function(session = NULL) {
  if (!is.null(session) && !is.null(session$userData)) {
    current_count <- session$userData$runtime_perf_memory_event_count
    next_count <- if (is.null(current_count)) 1L else as.integer(current_count) + 1L
    session$userData$runtime_perf_memory_event_count <- next_count
    return(next_count)
  }

  current_count <- getOption("vp_perf_runtime_memory_event_count", default = 0L)
  next_count <- suppressWarnings(as.integer(current_count)) + 1L
  if (!is.finite(next_count) || is.na(next_count)) next_count <- 1L
  options(vp_perf_runtime_memory_event_count = next_count)
  next_count
}

runtime_perf_empty_memory_snapshot <- function() {
  list(
    memory_size_mb = NA_real_,
    gc_ncells_used = NA_real_,
    gc_vcells_used = NA_real_,
    gc_ncells_mb = NA_real_,
    gc_vcells_mb = NA_real_
  )
}

runtime_perf_memory_snapshot <- function() {
  memory_size_mb <- suppressWarnings(tryCatch(as.numeric(memory.size()), error = function(...) NA_real_))
  gc_stats <- tryCatch(gc(), error = function(...) NULL)

  gc_ncells_used <- NA_real_
  gc_vcells_used <- NA_real_
  gc_ncells_mb <- NA_real_
  gc_vcells_mb <- NA_real_

  if (is.matrix(gc_stats) && nrow(gc_stats) >= 2L && ncol(gc_stats) >= 2L) {
    if ("Ncells" %in% rownames(gc_stats) && "Vcells" %in% rownames(gc_stats) && "used" %in% colnames(gc_stats)) {
      gc_ncells_used <- suppressWarnings(as.numeric(gc_stats["Ncells", "used"]))
      gc_vcells_used <- suppressWarnings(as.numeric(gc_stats["Vcells", "used"]))
    }

    mb_cols <- grep("\\(Mb\\)", colnames(gc_stats), value = TRUE)
    if (length(mb_cols) > 0L) {
      mb_col <- mb_cols[[1L]]
      if ("Ncells" %in% rownames(gc_stats) && "Vcells" %in% rownames(gc_stats)) {
        gc_ncells_mb <- suppressWarnings(as.numeric(gc_stats["Ncells", mb_col]))
        gc_vcells_mb <- suppressWarnings(as.numeric(gc_stats["Vcells", mb_col]))
      }
    }
  }

  list(
    memory_size_mb = memory_size_mb,
    gc_ncells_used = gc_ncells_used,
    gc_vcells_used = gc_vcells_used,
    gc_ncells_mb = gc_ncells_mb,
    gc_vcells_mb = gc_vcells_mb
  )
}

runtime_perf_memory_payload <- function(session = NULL) {
  mode <- runtime_perf_memory_mode()
  event_count <- runtime_perf_memory_event_count(session = session)
  interval <- runtime_perf_memory_sample_interval()
  take_snapshot <- identical(mode, "full") || (identical(mode, "sample") && event_count %% interval == 0L)

  c(
    list(
      memory_snapshot_mode = mode,
      memory_snapshot_taken = isTRUE(take_snapshot),
      memory_snapshot_interval = if (identical(mode, "sample")) interval else NA_integer_,
      memory_event_count = event_count
    ),
    if (isTRUE(take_snapshot)) runtime_perf_memory_snapshot() else runtime_perf_empty_memory_snapshot()
  )
}

runtime_perf_normalize_payload <- function(payload = list()) {
  if (is.null(payload) || length(payload) == 0L) return(list())

  payload_names <- names(payload)
  if (is.null(payload_names)) {
    payload_names <- rep("", length(payload))
  }

  unnamed_idx <- !nzchar(payload_names)
  if (any(unnamed_idx)) {
    payload_names[unnamed_idx] <- paste0("detail_", seq_len(sum(unnamed_idx)))
  }
  names(payload) <- payload_names

  payload[!vapply(payload, is.null, logical(1))]
}

runtime_perf_probe_identity_payload <- function() {
  probe_run_id <- trimws(Sys.getenv("VP_PERF_RUN_ID", unset = ""))
  probe_session_id <- trimws(Sys.getenv("VP_PERF_SESSION_ID", unset = ""))
  probe_type <- trimws(Sys.getenv("VP_PERF_PROBE_TYPE", unset = ""))
  probe_label <- trimws(Sys.getenv("VP_PERF_PROBE_LABEL", unset = ""))
  probe_cache_state <- trimws(Sys.getenv("VP_PERF_CACHE_STATE", unset = ""))
  probe_comparison_plot_cache_off <- trimws(Sys.getenv("VP_PERF_COMPARISON_PLOT_CACHE_OFF", unset = ""))

  comparison_plot_cache_off <- if (nzchar(probe_comparison_plot_cache_off)) {
    perf_truthy(probe_comparison_plot_cache_off, default = FALSE)
  } else {
    FALSE
  }

  payload <- list(
    probe_run_id = if (nzchar(probe_run_id)) probe_run_id else NULL,
    probe_session_id = if (nzchar(probe_session_id)) probe_session_id else NULL,
    probe_type = if (nzchar(probe_type)) probe_type else NULL,
    probe_label = if (nzchar(probe_label)) probe_label else NULL,
    probe_cache_state = if (nzchar(probe_cache_state)) probe_cache_state else NULL,
    probe_comparison_plot_cache_off = if (nzchar(probe_comparison_plot_cache_off)) comparison_plot_cache_off else NULL,
    probe_comparison_plot_cache_mode = if (nzchar(probe_comparison_plot_cache_off)) {
      if (isTRUE(comparison_plot_cache_off)) "final_output_cache_off" else "final_output_cache_on"
    } else {
      NULL
    }
  )

  payload[!vapply(payload, is.null, logical(1))]
}

runtime_perf_record <- function(event, details = list(), session = NULL) {
  if (!isTRUE(runtime_perf_enabled())) return(invisible(FALSE))

  event_name <- trimws(as.character(event %||% ""))
  if (!nzchar(event_name)) return(invisible(FALSE))

  payload <- c(
    list(
      ts_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%OS3Z", tz = "UTC"),
      event = event_name,
      runtime_session_id = runtime_perf_session_id(session = session),
      pid = Sys.getpid()
    ),
    runtime_perf_probe_identity_payload(),
    runtime_perf_memory_payload(session = session),
    details %||% list()
  )
  payload <- runtime_perf_normalize_payload(payload)

  payload_line <- tryCatch({
    if (requireNamespace("jsonlite", quietly = TRUE)) {
      as.character(jsonlite::toJSON(payload, auto_unbox = TRUE, null = "null", na = "null"))
    } else {
      paste(
        names(payload),
        vapply(payload, format_perf_detail_value, character(1)),
        sep = "=",
        collapse = ","
      )
    }
  }, error = function(...) {
    paste(
      names(payload),
      vapply(payload, format_perf_detail_value, character(1)),
      sep = "=",
      collapse = ","
    )
  })

  log_path <- runtime_perf_log_path(session = session)
  log_dir <- dirname(log_path)
  if (nzchar(log_dir)) {
    dir.create(log_dir, recursive = TRUE, showWarnings = FALSE)
  }
  cat(payload_line, "\n", sep = "", file = log_path, append = TRUE)

  invisible(TRUE)
}

cache_trace_enabled <- function() {
  isTRUE(getOption("almond_cache_trace_log", default = FALSE)) ||
    isTRUE(getOption("rice_cache_trace_log", default = FALSE))
}

psd_transition_log_enabled <- function() {
  isTRUE(getOption("almond_psd_transition_log", default = FALSE)) ||
    isTRUE(getOption("rice_psd_transition_log", default = FALSE))
}

trace_file_path <- function() {
  trace_file <- as.character(getOption("almond_trace_file", default = "") %||% "")
  trace_file <- trimws(trace_file)
  if (nzchar(trace_file)) {
    return(trace_file)
  }

  trace_file <- as.character(getOption("rice_trace_file", default = "") %||% "")
  trimws(trace_file)
}

log_perf <- function(tag, start_time, details = NULL) {
  perf_console_enabled <- isTRUE(perf_log_enabled())
  perf_runtime_enabled <- isTRUE(runtime_perf_enabled())
  if (!perf_console_enabled && !perf_runtime_enabled) return()

  elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))

  detail_suffix <- ""
  if (!is.null(details) && length(details) > 0) {
    detail_pairs <- paste(
      names(details),
      vapply(details, format_perf_detail_value, character(1)),
      sep = "="
    )
    detail_suffix <- paste0(" | ", paste(detail_pairs, collapse = ", "))
  }

  if (perf_console_enabled) {
    message(sprintf("[PERF] %s: %.3f seconds%s", tag, elapsed, detail_suffix))
  }

  if (perf_runtime_enabled) {
    runtime_perf_record(
      event = "log_perf",
      details = c(
        list(tag = as.character(tag), elapsed_seconds = elapsed),
        details %||% list()
      )
    )
  }
}

record_cache_body_execution <- function(session = NULL, name, details = list()) {
  name <- as.character(name %||% "")
  if (!nzchar(name)) return(invisible(NA_integer_))

  count <- NA_integer_
  if (!is.null(session) && !is.null(session$userData)) {
    counter_env <- session$userData$cache_body_execution_counts
    if (!is.environment(counter_env)) {
      counter_env <- new.env(parent = emptyenv())
      session$userData$cache_body_execution_counts <- counter_env
    }

    current_count <- counter_env[[name]]
    count <- if (is.null(current_count)) 1L else as.integer(current_count) + 1L
    counter_env[[name]] <- count
  }

  if (cache_trace_enabled()) {
    trace_details <- c(list(name = name, count = count), details %||% list())
    log_trace("CACHE_BODY", trace_details)
  }

  runtime_perf_record(
    event = "cache_body_execution",
    session = session,
    details = c(
      list(name = name, count = count),
      details %||% list()
    )
  )

  invisible(count)
}

record_cache_key_delta <- function(session = NULL, name, key, details = list()) {
  name <- as.character(name %||% "")
  if (!nzchar(name) || is.null(key)) return(invisible(character(0)))
  if (is.null(session) || is.null(session$userData)) return(invisible(character(0)))

  key_trace_env <- session$userData$cache_key_trace_state
  if (!is.environment(key_trace_env)) {
    key_trace_env <- new.env(parent = emptyenv())
    session$userData$cache_key_trace_state <- key_trace_env
  }

  previous_key <- key_trace_env[[name]]
  key_trace_env[[name]] <- key

  if (is.null(previous_key)) return(invisible(names(key) %||% character(0)))

  key_fields <- union(names(previous_key), names(key))
  changed_fields <- key_fields[vapply(
    key_fields,
    function(field_name) !identical(previous_key[[field_name]], key[[field_name]]),
    logical(1)
  )]

  if (cache_trace_enabled() && length(changed_fields) > 0) {
    trace_details <- c(
      list(
        name = name,
        changed_fields = paste(changed_fields, collapse = "|"),
        changed_count = length(changed_fields)
      ),
      details %||% list()
    )
    log_trace("CACHE_KEY_DELTA", trace_details)
  }

  if (length(changed_fields) > 0) {
    runtime_perf_record(
      event = "cache_key_delta",
      session = session,
      details = c(
        list(
          name = name,
          changed_fields = paste(changed_fields, collapse = "|"),
          changed_count = length(changed_fields)
        ),
        details %||% list()
      )
    )
  }

  invisible(changed_fields)
}

log_trace <- function(prefix, payload = list()) {
  if (is.null(payload) || length(payload) == 0) return(invisible(NULL))

  detail_pairs <- paste(
    names(payload),
    vapply(payload, format_perf_detail_value, character(1)),
    sep = "="
  )

  trace_line <- sprintf("[%s] %s", prefix, paste(detail_pairs, collapse = ", "))
  message(trace_line)

  trace_file <- trace_file_path()
  if (nzchar(trace_file)) {
    trace_path <- normalizePath(trace_file, winslash = "/", mustWork = FALSE)
    trace_dir <- dirname(trace_path)
    if (nzchar(trace_dir)) {
      dir.create(trace_dir, recursive = TRUE, showWarnings = FALSE)
    }
    cat(trace_line, "\n", sep = "", file = trace_path, append = TRUE)
  }

  invisible(NULL)
}

build_named_col_classes <- function(numeric_cols = character(), text_cols = character(), logical_cols = character(), date_cols = character()) {
  c(
    stats::setNames(rep("numeric", length(numeric_cols)), numeric_cols),
    stats::setNames(rep("character", length(text_cols)), text_cols),
    stats::setNames(rep("logical", length(logical_cols)), logical_cols),
    stats::setNames(rep("character", length(date_cols)), date_cols)
  )
}

assert_unique_rows_by_key <- function(df, key_cols, dataset_label) {
  duplicate_rows <- df %>%
    group_by(across(all_of(key_cols))) %>%
    filter(n() > 1L) %>%
    ungroup()

  if (nrow(duplicate_rows) == 0L) {
    return(df)
  }

  duplicate_key_preview <- duplicate_rows %>%
    distinct(across(all_of(key_cols))) %>%
    head(5)

  stop(
    paste0(
      dataset_label,
      " contains duplicate rows for key columns ",
      paste(key_cols, collapse = ", "),
      ". Example duplicate keys: ",
      paste(apply(duplicate_key_preview, 1, function(row) paste(row, collapse = " | ")), collapse = "; ")
    ),
    call. = FALSE
  )
}

global_startup_total_start_time <- Sys.time()

# Load data
# Construct absolute paths with a fallback when rstudioapi isn't available (e.g., run via Master.R)
get_script_dir <- function() {
  ctx <- tryCatch(rstudioapi::getActiveDocumentContext()$path, error = function(...) NULL)
  if (!is.null(ctx) && nzchar(ctx)) return(dirname(ctx))

  ofile <- tryCatch(sys.frames()[[1]]$ofile, error = function(...) NULL)
  if (!is.null(ofile) && nzchar(ofile)) {
    return(dirname(normalizePath(ofile, winslash = "\\", mustWork = FALSE)))
  }

  ca <- commandArgs(trailingOnly = FALSE)
  file_arg <- "--file="
  script_path <- ca[grepl(file_arg, ca)]
  if (length(script_path) > 0) {
    path <- sub(file_arg, "", script_path[[1]])
    if (nzchar(path)) {
      return(dirname(normalizePath(path, winslash = "\\", mustWork = FALSE)))
    }
  }

  normalizePath(getwd(), winslash = "\\", mustWork = FALSE)
}

script_dir <- get_script_dir()
startup_commodity_contract <- get0("commodity_contract", inherits = TRUE)
if (!is.list(startup_commodity_contract)) {
  stop("Commodity contract must be loaded before cloned global.R startup.", call. = FALSE)
}
validate_commodity_contract(startup_commodity_contract)

find_project_root <- function(start_dir) {
  project_root <- find_commodity_project_root(start_dir, startup_commodity_contract, max_depth = 8L)
  validate_commodity_project_root(project_root, startup_commodity_contract)
  normalizePath(project_root, winslash = "\\", mustWork = TRUE)
}

base_dir <- find_project_root(script_dir)
reference_dir <- file.path(base_dir, "System", "Reference")

startup_artifact_path <- function(role) {
  contract_artifact_path(startup_commodity_contract, role, base_dir)
}

startup_source_enabled <- function(source_family, usage = "runtime") {
  contract_source_enabled(startup_commodity_contract, source_family, usage = usage)
}

startup_census_fiscal_year_enabled <- function(usage = c("runtime", "build", "ui")) {
  usage <- match.arg(usage)
  contract_census_fiscal_year_enabled(startup_commodity_contract, usage = usage)
}

startup_source_paths <- function(source_family, paths, usage = "runtime") {
  if (!startup_source_enabled(source_family, usage = usage)) {
    return(character())
  }

  normalizePath(paths, winslash = "\\", mustWork = FALSE)
}

startup_app_title <- function() {
  contract_app_title(startup_commodity_contract)
}

startup_aggregate_label <- function() {
  contract_aggregate_label(startup_commodity_contract)
}

startup_reserved_names <- function() {
  contract_reserved_names(startup_commodity_contract)
}

startup_ui_source_choices <- function(include_disabled = FALSE) {
  contract_ui_source_choices(startup_commodity_contract, include_disabled = include_disabled)
}

startup_ui_source_values <- function(include_disabled = FALSE) {
  contract_ui_source_values(startup_commodity_contract, include_disabled = include_disabled)
}

startup_default_ui_source <- function(default = NULL) {
  contract_default_ui_source(startup_commodity_contract, default = default)
}

startup_namespace_value <- function(key, default) {
  value <- startup_commodity_contract$namespaces[[key]] %||% default
  value <- trimws(as.character(value[[1]] %||% default))
  if (nzchar(value)) value else default
}

APP_TITLE_LABEL <- startup_app_title()
COMMODITY_AGGREGATE_LABEL <- startup_aggregate_label()
COMMODITY_RESERVED_NAMES <- startup_reserved_names()
COMMODITY_TYPE_LABEL <- contract_label(startup_commodity_contract, "commodity_type_label")
COMMODITY_TYPE_PLACEHOLDER <- contract_label(startup_commodity_contract, "commodity_type_placeholder")
COMMODITY_DISABLED_SOURCE_MESSAGE <- contract_label(startup_commodity_contract, "disabled_source_message")
NOTES_FILE_PREFIX <- startup_namespace_value("notes_namespace", "notes")
CUSTOM_TYPES_FILE_PREFIX <- startup_namespace_value("custom_types_namespace", "custom_types")
CUSTOM_COUNTRIES_FILE_PREFIX <- startup_namespace_value("custom_countries_namespace", "custom_countries")
CORRECTIONS_FILE_PREFIX <- startup_namespace_value("corrections_namespace", "census_corrections")

startup_psd_app_commodity_label <- function() {
  label <- startup_commodity_contract$psd$app_commodity_label %||% startup_commodity_contract$identity$aggregate_label
  label <- trimws(as.character(label[[1]]))
  if (nzchar(label)) label else startup_aggregate_label()
}

startup_psd_app_commodity_group <- function() {
  label <- startup_commodity_contract$psd$app_commodity_group %||% startup_psd_app_commodity_label()
  label <- trimws(as.character(label[[1]]))
  if (nzchar(label)) label else startup_psd_app_commodity_label()
}

startup_psd_basis_profile <- function(default = "milled_basis") {
  profile <- startup_commodity_contract$psd$basis_profile %||% default
  profile <- trimws(as.character(profile[[1]] %||% default))
  if (nzchar(profile)) profile else default
}

psd_prior_release_comparison_enabled <- function(default = TRUE) {
  flag <- tryCatch(startup_commodity_contract$psd$prior_release_comparison_enabled, error = function(...) NULL)
  if (is.null(flag) || length(flag) == 0L) {
    return(isTRUE(default))
  }

  flag <- flag[[1L]]
  if (is.logical(flag) && !is.na(flag)) {
    return(isTRUE(flag))
  }

  flag <- tolower(trimws(as.character(flag %||% "")))
  if (!nzchar(flag)) {
    return(isTRUE(default))
  }

  flag %in% c("true", "t", "1", "yes", "y")
}

startup_psd_expected_metric_ids <- function(default = character()) {
  metric_ids <- startup_commodity_contract$psd$expected_native_metric_ids %||% default
  metric_ids <- trimws(as.character(metric_ids))
  metric_ids[nzchar(metric_ids)]
}

resolve_rice_hs_workbook_path <- function(project_dir = base_dir) {
  normalizePath(startup_artifact_path("hs_reference_workbook"), winslash = "\\", mustWork = FALSE)
}

load_rice_hs_reference_sheet <- function(sheet_name, workbook_path = resolve_rice_hs_workbook_path()) {
  if (is.null(workbook_path) || !file.exists(workbook_path)) {
    stop("Commodity HS workbook is not available for this clone.", call. = FALSE)
  }

  readxl::read_excel(workbook_path, sheet = sheet_name)
}

rice_hs_workbook_path <- resolve_rice_hs_workbook_path()
vp_trade_csv_path <- file.path(base_dir, "Input", "fruit-trade-data.csv")
app_output_dir <- file.path(base_dir, "Output")
monthly_path <- file.path(base_dir, "Output", "FAS ESR data", "export_sales_monthly.csv")
weekly_path <- file.path(base_dir, "Output", "FAS ESR data", "weekly_data.csv")
census_exports_path <- character()
census_imports_path <- character()
census_corrections_input_path <- startup_artifact_path("corrections_registry")
country_harmonization_dir <- file.path(base_dir, "Programs", "Country Harmonization Programs (Hybrid)")
country_baseline_table_path <- file.path(country_harmonization_dir, "country_harmonization_baseline.csv")
country_review_table_path <- file.path(country_harmonization_dir, "country_mapping_review_table.csv")
country_review_generator_path <- file.path(country_harmonization_dir, "generate_country_mapping_review_table.R")
country_harmonization_readme_path <- file.path(base_dir, "Documentation", "README_country_harmonization_hybrid.txt")
hybrid_monthly_path <- file.path(app_output_dir, "rice_data_hybrid_monthly.csv")
hybrid_import_monthly_path <- file.path(app_output_dir, "rice_data_hybrid_import_monthly.csv")
hybrid_weekly_imputed_path <- file.path(app_output_dir, "rice_data_hybrid_weekly_imputed.csv")
psd_raw_preferred_path <- character()
psd_metadata_preferred_path <- character()
nass_raw_preferred_path <- character()
wasde_raw_path <- file.path(base_dir, "Output", "WASDE data", "wasde_rice.csv")
wasde_waob_release_history_raw_path <- file.path(base_dir, "Output", "WASDE data", "wasde_rice_waob_releases.csv")
shared_source_utils_path <- file.path(base_dir, "Programs", "shared_source_harmonization_utils.R")

startup_stage_start_time <- Sys.time()
source(shared_source_utils_path, local = TRUE)

hybrid_market_month_name_lookup <- c(
  "August", "September", "October", "November", "December", "January",
  "February", "March", "April", "May", "June", "July"
)

required_hybrid_provenance_cols <- c(
  "market_month", "market_month_name",
  "hybrid_type", "hybrid_formula_id", "hybrid_formula_text",
  "source_systems_used", "raw_census_variables_used",
  "raw_export_sales_variables_used", "adjusted_variables_used",
  "adjustment_flags", "adjustment_notes",
  "hybrid_quantity_cwt_rough_eq", "hybrid_pre_clamp_cwt_rough_eq",
  "final_adjusted_hybrid_cwt_rough_eq",
  "census_all_rice_raw_cwt_rough_eq", "census_all_rice_adjusted_cwt_rough_eq",
  "census_rough_rice_raw_cwt_rough_eq", "census_rough_rice_adjusted_cwt_rough_eq",
  "census_milled_msg_raw_cwt_rough_eq", "census_milled_msg_adjusted_cwt_rough_eq",
  "export_rough_msg_raw_cwt_rough_eq", "export_rough_msg_adjusted_cwt_rough_eq",
  "hybrid_missing_component_count", "hybrid_negative_clamp_flag"
)

required_hybrid_weekly_metadata_cols <- c(
  "weekly_hybrid_mode", "weekly_data_segment",
  "is_imputed_weekly", "is_export_sales_extension",
  "splice_boundary_flag", "imputation_weight",
  "monthly_reconciliation_analysis_month", "monthly_reconciliation_months"
)

log_perf(
  "startup_init(source_utils)",
  startup_stage_start_time,
  details = list(
    shared_source_utils = basename(shared_source_utils_path)
  )
)

processed_data_dir <- get_processed_data_dir(base_dir)
psd_raw_path <- psd_raw_preferred_path
psd_metadata_path <- psd_metadata_preferred_path
nass_raw_path <- nass_raw_preferred_path
nass_processed_csv_path <- file.path(base_dir, "Output", "NASS data", "nass_almond_annual_processed.csv")
weekly_prepped_path <- startup_artifact_path("export_sales_weekly")
weekly_fiscal_prepped_path <- startup_artifact_path("export_sales_weekly_fiscal")
monthly_prepped_path <- startup_artifact_path("export_sales_monthly")
monthly_fiscal_prepped_path <- startup_artifact_path("export_sales_monthly_fiscal")
vp_trade_monthly_prepped_path <- startup_artifact_path("vp_trade_monthly")
vp_trade_metadata_prepped_path <- file.path(base_dir, "System", "Processed Data", "vp_trade_metadata_pre.rds")
census_exports_prepped_path <- startup_artifact_path("census_exports_monthly")
census_exports_fiscal_prepped_path <- startup_artifact_path("census_exports_monthly_fiscal")
census_imports_prepped_path <- startup_artifact_path("census_imports_monthly")
census_imports_fiscal_prepped_path <- startup_artifact_path("census_imports_monthly_fiscal")
hybrid_monthly_prepped_path <- startup_artifact_path("hybrid_export_monthly")
hybrid_monthly_fiscal_prepped_path <- startup_artifact_path("hybrid_export_monthly_fiscal")
hybrid_import_monthly_prepped_path <- startup_artifact_path("hybrid_import_monthly")
hybrid_import_monthly_fiscal_prepped_path <- startup_artifact_path("hybrid_import_monthly_fiscal")
hybrid_weekly_imputed_prepped_path <- startup_artifact_path("hybrid_weekly_imputed")
hybrid_weekly_imputed_fiscal_prepped_path <- startup_artifact_path("hybrid_weekly_imputed_fiscal")
psd_marketing_year_prepped_path <- startup_artifact_path("psd_marketing_year")
psd_historical_records_prepped_path <- startup_artifact_path("psd_historical_records")
nass_annual_prepped_path <- startup_artifact_path("nass_annual")
nass_state_lookup_prepped_path <- startup_artifact_path("nass_state_lookup")
nass_shellout_factors_prepped_path <- startup_artifact_path("nass_shellout_factors")
nass_historical_records_prepped_path <- startup_artifact_path("nass_historical_records")
psd_release_archive_manifest_path <- get_psd_release_archive_manifest_path(base_dir)
psd_revision_delta_prepped_path <- startup_artifact_path("psd_revision_delta")
wasde_marketing_year_prepped_path <- startup_artifact_path("wasde_marketing_year")
wasde_historical_records_prepped_path <- startup_artifact_path("wasde_historical_records")
wasde_release_history_prepped_path <- startup_artifact_path("wasde_release_history")
wasde_revision_delta_prepped_path <- startup_artifact_path("wasde_revision_delta")
app_ui_metadata_prepped_path <- startup_artifact_path("app_ui_metadata")
app_ui_metadata_source_paths <- startup_source_paths("vp_trade", vp_trade_csv_path)
startup_artifact_manifest <- list(
  hs_reference_workbook = rice_hs_workbook_path,
  app_ui_metadata = app_ui_metadata_prepped_path,
  export_sales_weekly = weekly_prepped_path,
  export_sales_monthly = monthly_prepped_path,
  census_exports_monthly = census_exports_prepped_path,
  census_imports_monthly = census_imports_prepped_path,
  psd_marketing_year = psd_marketing_year_prepped_path,
  psd_historical_records = psd_historical_records_prepped_path,
  nass_annual = nass_annual_prepped_path,
  nass_state_lookup = nass_state_lookup_prepped_path,
  nass_shellout_factors = nass_shellout_factors_prepped_path,
  nass_historical_records = nass_historical_records_prepped_path,
  wasde_marketing_year = wasde_marketing_year_prepped_path,
  hybrid_export_monthly = hybrid_monthly_prepped_path
)

# System-level persistence directory (peer to Output/Programs)
system_dir <- file.path(base_dir, "System")
notes_dir <- dirname(startup_artifact_path("notes"))
custom_types_dir <- dirname(startup_artifact_path("custom_types"))
cache_dir <- startup_artifact_path("cache")
census_corrections_dir <- dirname(startup_artifact_path("corrections_registry"))
census_corrections_audit_path <- startup_artifact_path("corrections_audit")
census_corrections_state_marker_path <- file.path(census_corrections_dir, paste0(CORRECTIONS_FILE_PREFIX, "_active.flag"))

startup_stage_start_time <- Sys.time()
for (path_dir in c(system_dir, reference_dir, notes_dir, custom_types_dir, cache_dir, census_corrections_dir, processed_data_dir, app_output_dir)) {
  if (!dir.exists(path_dir)) dir.create(path_dir, recursive = TRUE)
}

# User-specific notes directory and user ID
user_id <- Sys.info()[["user"]]
user_notes_path <- file.path(notes_dir, paste0(NOTES_FILE_PREFIX, "_", user_id, ".csv"))

user_custom_types_path <- file.path(custom_types_dir, paste0(CUSTOM_TYPES_FILE_PREFIX, "_", user_id, ".csv"))
user_custom_types_census_reset_marker_path <- file.path(custom_types_dir, paste0(CUSTOM_TYPES_FILE_PREFIX, "_census_reset_", user_id, ".flag"))
user_custom_types_hybrid_reset_marker_path <- file.path(custom_types_dir, paste0(CUSTOM_TYPES_FILE_PREFIX, "_hybrid_reset_", user_id, ".flag"))
user_custom_countries_path <- file.path(custom_types_dir, paste0(CUSTOM_COUNTRIES_FILE_PREFIX, "_", user_id, ".csv"))

CUSTOM_BUILDER_CHOICE <- "__custom_builder__"
CUSTOM_RESERVED_NAMES <- COMMODITY_RESERVED_NAMES
CUSTOM_COUNTRY_BUILDER_CHOICE <- "__custom_country_builder__"
CUSTOM_COUNTRY_RESERVED_NAMES <- c("World", "Grand Total", "GRAND_TOTAL", "Custom")
CUSTOM_COUNTRY_CHOICE_PREFIX <- "CUSTOM_COUNTRY::"

is_custom_country_choice_value <- function(value) {
  candidate <- trimws(as.character(value %||% ""))
  if (length(candidate) == 0L || !nzchar(candidate[[1L]])) return(FALSE)
  startsWith(candidate[[1L]], CUSTOM_COUNTRY_CHOICE_PREFIX)
}

build_custom_country_choice_value <- function(custom_name) {
  name_value <- trimws(as.character(custom_name %||% ""))
  name_value <- name_value[!is.na(name_value) & nzchar(name_value)]
  if (length(name_value) == 0L) return(CUSTOM_COUNTRY_CHOICE_PREFIX)
  paste0(CUSTOM_COUNTRY_CHOICE_PREFIX, name_value[[1L]])
}

parse_custom_country_choice_name <- function(choice_value) {
  candidate <- trimws(as.character(choice_value %||% ""))
  candidate <- candidate[!is.na(candidate) & nzchar(candidate)]
  if (length(candidate) == 0L) return(NULL)

  candidate <- candidate[[1L]]
  if (!startsWith(candidate, CUSTOM_COUNTRY_CHOICE_PREFIX)) return(NULL)

  parsed_name <- substring(candidate, nchar(CUSTOM_COUNTRY_CHOICE_PREFIX) + 1L)
  parsed_name <- trimws(parsed_name)
  if (!nzchar(parsed_name)) return(NULL)
  parsed_name
}

log_perf(
  "startup_init(system_paths)",
  startup_stage_start_time,
  details = list(user_id = user_id)
)

# Load all user notes files on startup or explicit refresh.
load_all_notes <- function(notes_dir, perf_context = "startup_init(load_all_notes)", file_prefix = NOTES_FILE_PREFIX) {
  list_files_start_time <- Sys.time()
  notes_file_pattern <- paste0("^", file_prefix, "_(.*)\\.csv$")
  files <- list.files(notes_dir, pattern = notes_file_pattern, full.names = TRUE)
  log_perf(
    paste0(perf_context, ":list_files"),
    list_files_start_time,
    details = list(files = length(files))
  )

  read_csvs_start_time <- Sys.time()
  notes_list <- lapply(files, function(f) {
    tryCatch({
      df <- normalize_notes_df(read.csv(f, stringsAsFactors = FALSE), include_user = TRUE)
      if (!"user" %in% names(df)) df$user <- basename(f)
      df$user <- sub(notes_file_pattern, "\\1", basename(f))
      df
    }, error = function(e) {
      empty_notes_df(include_user = TRUE)
    })
  })
  log_perf(
    paste0(perf_context, ":read_csvs"),
    read_csvs_start_time,
    details = list(files = length(notes_list))
  )

  bind_rows_start_time <- Sys.time()
  notes_df <- if (length(notes_list) == 0L) {
    empty_notes_df(include_user = TRUE)
  } else {
    bind_rows(notes_list)
  }
  log_perf(
    paste0(perf_context, ":bind_rows"),
    bind_rows_start_time,
    details = list(rows = nrow(notes_df), files = length(notes_list))
  )

  notes_df
}

write_csv_with_backup_replace <- function(data, target_file, row.names = FALSE, fileEncoding = "", na = "NA", perf_context = "write_csv_with_backup_replace") {
  total_start_time <- Sys.time()
  target_dir <- dirname(target_file)
  if (!dir.exists(target_dir)) dir.create(target_dir, recursive = TRUE)

  temp_file <- tempfile(pattern = paste0(basename(target_file), "_"), tmpdir = target_dir, fileext = ".tmp")
  backup_file <- paste0(target_file, ".bak")
  backup_created <- FALSE
  write_succeeded <- FALSE

  on.exit({
    if (file.exists(temp_file)) file.remove(temp_file)
    if (backup_created && file.exists(backup_file) && file.exists(target_file)) file.remove(backup_file)
  }, add = TRUE)

  temp_write_start_time <- Sys.time()
  tryCatch({
    write.csv(data, temp_file, row.names = row.names, fileEncoding = fileEncoding, na = na)
    write_succeeded <- TRUE
  }, error = function(e) {
    log_perf(
      paste0(perf_context, ":write_temp_failed"),
      temp_write_start_time,
      details = list(file = basename(target_file), error = conditionMessage(e))
    )
    stop(sprintf("Failed writing temporary CSV for %s: %s", basename(target_file), conditionMessage(e)), call. = FALSE)
  })
  log_perf(
    paste0(perf_context, ":write_temp"),
    temp_write_start_time,
    details = list(file = basename(target_file), rows = nrow(data))
  )

  if (!isTRUE(write_succeeded) || !file.exists(temp_file)) {
    stop(sprintf("Temporary CSV write did not produce a file for %s.", basename(target_file)), call. = FALSE)
  }

  replace_start_time <- Sys.time()
  if (file.exists(target_file)) {
    if (file.exists(backup_file) && !file.remove(backup_file)) {
      stop(sprintf("Could not clear prior backup file for %s.", basename(target_file)), call. = FALSE)
    }

    if (!file.rename(target_file, backup_file)) {
      stop(sprintf("Could not move existing file to backup before replacing %s.", basename(target_file)), call. = FALSE)
    }
    backup_created <- TRUE
  }

  if (!file.rename(temp_file, target_file)) {
    if (backup_created && file.exists(backup_file)) {
      file.rename(backup_file, target_file)
    }
    stop(sprintf("Could not replace %s with the new CSV file.", basename(target_file)), call. = FALSE)
  }

  if (!file.exists(target_file)) {
    if (backup_created && file.exists(backup_file)) {
      file.rename(backup_file, target_file)
    }
    stop(sprintf("Replacement write completed without creating %s.", basename(target_file)), call. = FALSE)
  }

  if (backup_created && file.exists(backup_file) && !file.remove(backup_file)) {
    stop(sprintf("Replaced %s but could not remove the backup file.", basename(target_file)), call. = FALSE)
  }

  log_perf(
    paste0(perf_context, ":replace"),
    replace_start_time,
    details = list(file = basename(target_file), backup_created = backup_created)
  )
  log_perf(
    perf_context,
    total_start_time,
    details = list(file = basename(target_file), rows = nrow(data), backup_created = backup_created)
  )

  invisible(target_file)
}

NOTES_SCHEMA_VERSION <- "2"
NOTES_SOURCE_FAMILIES <- c("domestic", "global")
notes_schema_version_path <- file.path(notes_dir, paste0(".", NOTES_FILE_PREFIX, "_schema_version"))

empty_notes_df <- function(include_user = FALSE) {
  notes_df <- data.frame(
    country = character(),
    source_family = character(),
    note = character(),
    last_updated = character(),
    stringsAsFactors = FALSE
  )

  if (isTRUE(include_user)) {
    notes_df$user <- character()
    notes_df <- notes_df[, c("country", "source_family", "note", "last_updated", "user")]
  }

  notes_df
}

normalize_notes_source_family <- function(values, default = "domestic") {
  normalized_default <- tolower(trimws(as.character(default)))
  if (length(normalized_default) == 0 || !nzchar(normalized_default[[1]]) || !(normalized_default[[1]] %in% NOTES_SOURCE_FAMILIES)) {
    normalized_default <- "domestic"
  } else {
    normalized_default <- normalized_default[[1]]
  }

  normalized_values <- tolower(trimws(as.character(values)))
  normalized_values[is.na(normalized_values) | !nzchar(normalized_values)] <- normalized_default
  normalized_values[!(normalized_values %in% NOTES_SOURCE_FAMILIES)] <- normalized_default
  normalized_values
}

normalize_notes_country_lookup_key <- function(values) {
  cleaned_values <- trimws(as.character(values))
  cleaned_values[is.na(cleaned_values)] <- ""
  cleaned_values <- gsub("\\s+", " ", cleaned_values)
  tolower(cleaned_values)
}

build_notes_country_code_lookup <- function() {
  source_priority_lookup <- c(psd = 1L, wasde = 1L, census = 2L, export_sales = 3L, hybrid = 4L)
  display_fallback_priority <- length(source_priority_lookup) + 1L
  lookup_frames <- list()

  append_lookup_rows <- function(lookup_values, canonical_values, source_priorities) {
    lookup_frames[[length(lookup_frames) + 1L]] <<- data.frame(
      lookup_key = normalize_notes_country_lookup_key(lookup_values),
      canonical_country_code = trimws(as.character(canonical_values)),
      source_priority = as.integer(source_priorities),
      stringsAsFactors = FALSE
    )
  }

  canonical_map <- get0("country_canonical_map", inherits = TRUE)
  if (is.data.frame(canonical_map) && nrow(canonical_map) > 0) {
    map_sources <- trimws(as.character(canonical_map$source))
    map_priorities <- unname(source_priority_lookup[map_sources])
    map_priorities[is.na(map_priorities)] <- length(source_priority_lookup) + 1L

    append_lookup_rows(canonical_map$canonical_country_code, canonical_map$canonical_country_code, map_priorities)
    append_lookup_rows(canonical_map$legacy_country_code, canonical_map$canonical_country_code, map_priorities)
    append_lookup_rows(canonical_map$canonical_country_label, canonical_map$canonical_country_code, map_priorities)
    append_lookup_rows(canonical_map$legacy_country_label, canonical_map$canonical_country_code, map_priorities)
  }

  display_choices <- get0("country_display_names", inherits = TRUE)
  if (!is.null(display_choices) && length(display_choices) > 0) {
    append_lookup_rows(names(display_choices), unname(display_choices), rep.int(display_fallback_priority, length(display_choices)))
  }

  display_lookup <- get0("country_display_name_lookup", inherits = TRUE)
  if (
    !is.null(display_lookup) && length(display_lookup) > 0 &&
    !is.null(display_choices) && length(display_choices) > 0
  ) {
    display_labels <- as.character(unname(display_lookup))
    preferred_codes <- unname(display_choices[display_labels])
    keep_rows <- !is.na(preferred_codes) & nzchar(preferred_codes)

    if (any(keep_rows)) {
      append_lookup_rows(
        names(display_lookup)[keep_rows],
        preferred_codes[keep_rows],
        rep.int(display_fallback_priority, sum(keep_rows))
      )
    }
  }

  if (length(lookup_frames) == 0) {
    return(stats::setNames(character(), character()))
  }

  lookup_df <- do.call(rbind, lookup_frames)
  keep_rows <-
    !is.na(lookup_df$lookup_key) & nzchar(lookup_df$lookup_key) &
    !is.na(lookup_df$canonical_country_code) & nzchar(lookup_df$canonical_country_code)
  lookup_df <- lookup_df[keep_rows, , drop = FALSE]

  if (nrow(lookup_df) == 0) {
    return(stats::setNames(character(), character()))
  }

  lookup_df <- lookup_df[order(lookup_df$source_priority, lookup_df$lookup_key, lookup_df$canonical_country_code), , drop = FALSE]
  lookup_df <- lookup_df[!duplicated(lookup_df$lookup_key), , drop = FALSE]

  stats::setNames(lookup_df$canonical_country_code, lookup_df$lookup_key)
}

canonicalize_notes_country_codes <- function(values) {
  cleaned_values <- trimws(as.character(values))
  cleaned_values[is.na(cleaned_values)] <- ""

  if (length(cleaned_values) == 0) {
    return(cleaned_values)
  }

  normalized_lookup_keys <- normalize_notes_country_lookup_key(cleaned_values)
  canonicalized_values <- cleaned_values
  world_mask <- normalized_lookup_keys %in% c("grand_total", "grand total", "world")
  canonicalized_values[world_mask] <- "GRAND_TOTAL"

  country_code_lookup <- build_notes_country_code_lookup()
  if (length(country_code_lookup) > 0) {
    matched_codes <- unname(country_code_lookup[normalized_lookup_keys])
    matched_mask <- !is.na(matched_codes) & nzchar(matched_codes)
    canonicalized_values[matched_mask] <- matched_codes[matched_mask]
  }

  canonicalized_values
}

dedupe_normalized_notes_df <- function(normalized_notes, include_user = FALSE) {
  if (!is.data.frame(normalized_notes) || nrow(normalized_notes) == 0) {
    return(normalized_notes)
  }

  key_cols <- c("country", "source_family")
  if (isTRUE(include_user) && "user" %in% names(normalized_notes)) {
    key_cols <- c(key_cols, "user")
  }

  key_values <- lapply(normalized_notes[key_cols], function(column_values) {
    cleaned_values <- as.character(column_values)
    cleaned_values[is.na(cleaned_values)] <- ""
    cleaned_values
  })
  row_keys <- do.call(paste, c(key_values, sep = "\r"))
  keep_rows <- !duplicated(row_keys, fromLast = TRUE)
  normalized_notes[keep_rows, , drop = FALSE]
}

normalize_notes_df <- function(notes_df, include_user = FALSE, default_source_family = "domestic") {
  if (is.null(notes_df) || !is.data.frame(notes_df)) {
    return(empty_notes_df(include_user = include_user))
  }

  normalized_notes <- notes_df

  if (!"country" %in% names(normalized_notes)) normalized_notes$country <- character(nrow(normalized_notes))
  if (!"source_family" %in% names(normalized_notes)) normalized_notes$source_family <- default_source_family
  if (!"note" %in% names(normalized_notes)) normalized_notes$note <- character(nrow(normalized_notes))
  if (!"last_updated" %in% names(normalized_notes)) normalized_notes$last_updated <- character(nrow(normalized_notes))
  if (isTRUE(include_user) && !"user" %in% names(normalized_notes)) normalized_notes$user <- character(nrow(normalized_notes))

  normalized_notes$country <- canonicalize_notes_country_codes(normalized_notes$country)
  normalized_notes$source_family <- normalize_notes_source_family(normalized_notes$source_family, default = default_source_family)
  normalized_notes$note <- as.character(normalized_notes$note)
  normalized_notes$last_updated <- as.character(normalized_notes$last_updated)

  if (isTRUE(include_user)) {
    normalized_notes$user <- trimws(as.character(normalized_notes$user))
  }

  keep_rows <- !is.na(normalized_notes$country) & nzchar(normalized_notes$country)
  normalized_notes <- normalized_notes[keep_rows, , drop = FALSE]
  normalized_notes <- dedupe_normalized_notes_df(normalized_notes, include_user = include_user)

  output_cols <- c("country", "source_family", "note", "last_updated")
  if (isTRUE(include_user)) output_cols <- c(output_cols, "user")

  normalized_notes[, output_cols, drop = FALSE]
}

ensure_notes_schema_reset <- function(notes_dir, schema_version_path = notes_schema_version_path, schema_version = NOTES_SCHEMA_VERSION, file_prefix = NOTES_FILE_PREFIX) {
  if (!dir.exists(notes_dir)) dir.create(notes_dir, recursive = TRUE)

  current_schema_version <- if (file.exists(schema_version_path)) {
    tryCatch(readLines(schema_version_path, warn = FALSE, n = 1), error = function(e) "")
  } else {
    ""
  }

  if (identical(current_schema_version, schema_version)) {
    return(invisible(FALSE))
  }

  notes_files <- list.files(notes_dir, pattern = paste0("^", file_prefix, "_.*\\.csv$"), full.names = TRUE)
  for (notes_file in notes_files) {
    write_csv_with_backup_replace(empty_notes_df(), notes_file, row.names = FALSE, na = "")
  }

  writeLines(schema_version, schema_version_path, useBytes = TRUE)
  invisible(TRUE)
}

# Save notes for the current user only
save_user_notes <- function(notes_df, notes_file, perf_context = "save_user_notes") {
  normalized_notes <- normalize_notes_df(notes_df)
  write_csv_with_backup_replace(normalized_notes, notes_file, row.names = FALSE, na = "", perf_context = paste0(perf_context, ":write_csv"))
}

# On app launch, load all notes
startup_stage_start_time <- Sys.time()
ensure_notes_schema_reset(notes_dir)
all_notes_df <- load_all_notes(notes_dir)
log_perf(
  "startup_init(load_all_notes)",
  startup_stage_start_time,
  details = list(
    rows = nrow(all_notes_df),
    users = if ("user" %in% names(all_notes_df)) dplyr::n_distinct(all_notes_df$user) else 0L
  )
)
# COUNTRY NOTES MANAGEMENT
# ============================================================================
# Helper function to load existing notes from CSV
load_notes <- function(notes_file) {
  if (file.exists(notes_file)) {
    tryCatch({
      notes_df <- read.csv(notes_file, stringsAsFactors = FALSE)
      return(normalize_notes_df(notes_df))
    }, error = function(e) {
      # If file is corrupted, return empty dataframe
      return(empty_notes_df())
    })
  } else {
    # Create empty dataframe with correct structure
    return(empty_notes_df())
  }
}

# Helper function to save notes to CSV
save_notes <- function(notes_df, notes_file, perf_context = "save_notes") {
  normalized_notes <- normalize_notes_df(notes_df)
  write_csv_with_backup_replace(normalized_notes, notes_file, row.names = FALSE, na = "", perf_context = paste0(perf_context, ":write_csv"))
}

empty_correction_map_reference <- function() {
  tibble(
    `Trade Flow` = character(),
    `HS code` = character(),
    `HS Display Label` = character(),
    RiceType = character(),
    `RiceType Display Label` = character(),
    Correction_UI_Active = logical(),
    `Display Group` = character(),
    `Display Order` = integer(),
    `Equivalent Default` = character(),
    `Unit Default` = character()
  )
}

load_correction_map_reference <- function(workbook_path = rice_hs_workbook_path) {
  empty_reference <- empty_correction_map_reference()

  if (is.null(workbook_path) || !file.exists(workbook_path)) {
    return(empty_reference)
  }

  tryCatch({
    workbook_sheets <- readxl::excel_sheets(workbook_path)
    if (!("Correction_Map" %in% workbook_sheets)) {
      return(empty_reference)
    }

    reference_df <- readxl::read_excel(workbook_path, sheet = "Correction_Map")
    required_cols <- names(empty_reference)

    for (col_name in required_cols) {
      if (!col_name %in% names(reference_df)) reference_df[[col_name]] <- empty_reference[[col_name]]
    }

    reference_df %>%
      transmute(
        `Trade Flow` = trimws(as.character(.data[["Trade Flow"]])),
        `HS code` = trimws(as.character(.data[["HS code"]])),
        `HS Display Label` = trimws(as.character(.data[["HS Display Label"]])),
        RiceType = trimws(as.character(.data$RiceType)),
        `RiceType Display Label` = trimws(as.character(.data[["RiceType Display Label"]])),
        Correction_UI_Active = normalize_correction_active(.data$Correction_UI_Active, default = FALSE),
        `Display Group` = trimws(as.character(.data[["Display Group"]])),
        `Display Order` = suppressWarnings(as.integer(.data[["Display Order"]])),
        `Equivalent Default` = trimws(as.character(.data[["Equivalent Default"]])),
        `Unit Default` = trimws(as.character(.data[["Unit Default"]]))
      ) %>%
      arrange(.data[["Trade Flow"]], .data[["Display Group"]], .data[["Display Order"]], .data[["HS code"]])
  }, error = function(e) {
    empty_reference
  })
}

normalize_correction_active <- function(values, default = TRUE) {
  normalized <- tolower(trimws(as.character(values)))
  normalized[is.na(normalized)] <- ""

  out <- dplyr::case_when(
    normalized %in% c("true", "t", "1", "yes", "y", "active") ~ TRUE,
    normalized %in% c("false", "f", "0", "no", "n", "archived", "inactive") ~ FALSE,
    normalized == "" ~ isTRUE(default),
    TRUE ~ isTRUE(default)
  )

  as.logical(out)
}

empty_census_corrections_registry <- function() {
  data.frame(
    `Correction ID` = integer(),
    Active = logical(),
    `Trade Flow` = character(),
    `Month start` = integer(),
    `Year start` = integer(),
    `Month end` = integer(),
    `Year end` = integer(),
    Country = character(),
    RiceType = character(),
    `HS code` = character(),
    Volume = numeric(),
    Unit = character(),
    Equivalent = character(),
    Reason = character(),
    `Created At` = character(),
    `Created By` = character(),
    `Updated At` = character(),
    `Updated By` = character(),
    `Archived At` = character(),
    `Archived By` = character(),
    `Archive Reason` = character(),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
}

default_census_corrections_registry_column <- function(col_name, row_count) {
  switch(
    col_name,
    `Correction ID` = rep(NA_integer_, row_count),
    Active = rep(NA, row_count),
    `Month start` = rep(NA_integer_, row_count),
    `Year start` = rep(NA_integer_, row_count),
    `Month end` = rep(NA_integer_, row_count),
    `Year end` = rep(NA_integer_, row_count),
    Volume = rep(NA_real_, row_count),
    rep(NA_character_, row_count)
  )
}

normalize_census_corrections_registry <- function(registry_df) {
  template <- empty_census_corrections_registry()
  required_cols <- names(template)
  row_count <- nrow(registry_df)

  for (col_name in required_cols) {
    if (!col_name %in% names(registry_df)) {
      registry_df[[col_name]] <- default_census_corrections_registry_column(col_name, row_count)
    }
  }

  registry_df %>%
    transmute(
      `Correction ID` = suppressWarnings(as.integer(.data[["Correction ID"]])),
      Active = normalize_correction_active(.data$Active, default = TRUE),
      `Trade Flow` = trimws(as.character(.data[["Trade Flow"]])),
      `Month start` = suppressWarnings(as.integer(.data[["Month start"]])),
      `Year start` = suppressWarnings(as.integer(.data[["Year start"]])),
      `Month end` = suppressWarnings(as.integer(.data[["Month end"]])),
      `Year end` = suppressWarnings(as.integer(.data[["Year end"]])),
      Country = trimws(as.character(.data$Country)),
      RiceType = trimws(as.character(.data$RiceType)),
      `HS code` = trimws(as.character(.data[["HS code"]])),
      Volume = suppressWarnings(as.numeric(.data$Volume)),
      Unit = trimws(as.character(.data$Unit)),
      Equivalent = trimws(as.character(.data$Equivalent)),
      Reason = trimws(as.character(.data$Reason)),
      `Created At` = trimws(as.character(.data[["Created At"]])),
      `Created By` = trimws(as.character(.data[["Created By"]])),
      `Updated At` = trimws(as.character(.data[["Updated At"]])),
      `Updated By` = trimws(as.character(.data[["Updated By"]])),
      `Archived At` = trimws(as.character(.data[["Archived At"]])),
      `Archived By` = trimws(as.character(.data[["Archived By"]])),
      `Archive Reason` = trimws(as.character(.data[["Archive Reason"]]))
    ) %>%
    filter(
      if_any(
        all_of(c("Trade Flow", "Country", "RiceType", "HS code")),
        ~ nzchar(replace_na(as.character(.x), ""))
      ) |
        !is.na(.data[["Correction ID"]])
    ) %>%
    arrange(desc(.data$Active), .data[["Trade Flow"]], .data$Country, .data[["HS code"]], .data[["Correction ID"]])
}

load_census_corrections_registry <- function(registry_file = census_corrections_input_path) {
  if (!file.exists(registry_file)) return(empty_census_corrections_registry())

  tryCatch({
    registry_df <- read.csv(registry_file, stringsAsFactors = FALSE, check.names = FALSE, colClasses = "character")
    normalized_registry <- normalize_census_corrections_registry(registry_df)

    missing_ids <- is.na(normalized_registry[["Correction ID"]])
    if (any(missing_ids)) {
      next_ids <- seq_len(sum(missing_ids))
      current_max <- suppressWarnings(max(normalized_registry[["Correction ID"]], na.rm = TRUE))
      if (!is.finite(current_max)) current_max <- 0L
      normalized_registry[["Correction ID"]][missing_ids] <- current_max + next_ids
    }

    normalized_registry
  }, error = function(e) {
    empty_census_corrections_registry()
  })
}

write_census_corrections_registry <- function(registry_df, registry_file = census_corrections_input_path) {
  normalized_registry <- normalize_census_corrections_registry(registry_df)
  if (!dir.exists(dirname(registry_file))) dir.create(dirname(registry_file), recursive = TRUE)
  write_csv_with_backup_replace(
    normalized_registry,
    registry_file,
    row.names = FALSE,
    fileEncoding = "UTF-8",
    na = ""
  )
  invisible(normalized_registry)
}

next_census_correction_id <- function(registry_df) {
  existing_ids <- suppressWarnings(as.integer(registry_df[["Correction ID"]]))
  existing_ids <- existing_ids[is.finite(existing_ids)]
  if (length(existing_ids) == 0) return(1L)
  max(existing_ids) + 1L
}

upsert_census_correction_record <- function(registry_df, record, editor = user_id, now = Sys.time()) {
  record_df <- as.data.frame(record, stringsAsFactors = FALSE, check.names = FALSE)
  normalized_registry <- normalize_census_corrections_registry(registry_df)
  template <- empty_census_corrections_registry()[0, ]

  for (col_name in names(template)) {
    if (!col_name %in% names(record_df)) record_df[[col_name]] <- NA
  }

  record_df <- normalize_census_corrections_registry(record_df)
  timestamp_chr <- format(now, "%Y-%m-%d %H:%M:%S")
  correction_id <- record_df[["Correction ID"]][1]

  if (is.na(correction_id)) {
    correction_id <- next_census_correction_id(normalized_registry)
    record_df[["Correction ID"]][1] <- correction_id
    record_df[["Created At"]][1] <- timestamp_chr
    record_df[["Created By"]][1] <- editor
  } else {
    existing_row <- normalized_registry %>% filter(.data[["Correction ID"]] == correction_id)
    if (nrow(existing_row) > 0) {
      if (!nzchar(record_df[["Created At"]][1])) record_df[["Created At"]][1] <- existing_row[["Created At"]][1]
      if (!nzchar(record_df[["Created By"]][1])) record_df[["Created By"]][1] <- existing_row[["Created By"]][1]
    } else {
      if (!nzchar(record_df[["Created At"]][1])) record_df[["Created At"]][1] <- timestamp_chr
      if (!nzchar(record_df[["Created By"]][1])) record_df[["Created By"]][1] <- editor
    }
  }

  record_df$Active[1] <- normalize_correction_active(record_df$Active[1], default = TRUE)
  record_df[["Updated At"]][1] <- timestamp_chr
  record_df[["Updated By"]][1] <- editor

  if (isTRUE(record_df$Active[1])) {
    record_df[["Archived At"]][1] <- ""
    record_df[["Archived By"]][1] <- ""
    record_df[["Archive Reason"]][1] <- ""
  }

  normalized_registry <- normalized_registry %>% filter(.data[["Correction ID"]] != correction_id)
  bind_rows(normalized_registry, record_df) %>% normalize_census_corrections_registry()
}

archive_census_correction_records <- function(registry_df, correction_ids, editor = user_id, now = Sys.time(), archive_reason = "") {
  normalized_registry <- normalize_census_corrections_registry(registry_df)
  target_ids <- suppressWarnings(as.integer(correction_ids))
  target_ids <- target_ids[is.finite(target_ids)]
  if (length(target_ids) == 0) return(normalized_registry)

  timestamp_chr <- format(now, "%Y-%m-%d %H:%M:%S")

  normalized_registry %>%
    mutate(
      Active = if_else(.data[["Correction ID"]] %in% target_ids, FALSE, .data$Active),
      `Updated At` = if_else(.data[["Correction ID"]] %in% target_ids, timestamp_chr, .data[["Updated At"]]),
      `Updated By` = if_else(.data[["Correction ID"]] %in% target_ids, editor, .data[["Updated By"]]),
      `Archived At` = if_else(.data[["Correction ID"]] %in% target_ids, timestamp_chr, .data[["Archived At"]]),
      `Archived By` = if_else(.data[["Correction ID"]] %in% target_ids, editor, .data[["Archived By"]]),
      `Archive Reason` = if_else(.data[["Correction ID"]] %in% target_ids, archive_reason, .data[["Archive Reason"]])
    ) %>%
    normalize_census_corrections_registry()
}

restore_census_correction_records <- function(registry_df, correction_ids, editor = user_id, now = Sys.time()) {
  normalized_registry <- normalize_census_corrections_registry(registry_df)
  target_ids <- suppressWarnings(as.integer(correction_ids))
  target_ids <- target_ids[is.finite(target_ids)]
  if (length(target_ids) == 0) return(normalized_registry)

  timestamp_chr <- format(now, "%Y-%m-%d %H:%M:%S")

  normalized_registry %>%
    mutate(
      Active = if_else(.data[["Correction ID"]] %in% target_ids, TRUE, .data$Active),
      `Updated At` = if_else(.data[["Correction ID"]] %in% target_ids, timestamp_chr, .data[["Updated At"]]),
      `Updated By` = if_else(.data[["Correction ID"]] %in% target_ids, editor, .data[["Updated By"]]),
      `Archived At` = if_else(.data[["Correction ID"]] %in% target_ids, "", .data[["Archived At"]]),
      `Archived By` = if_else(.data[["Correction ID"]] %in% target_ids, "", .data[["Archived By"]]),
      `Archive Reason` = if_else(.data[["Correction ID"]] %in% target_ids, "", .data[["Archive Reason"]])
    ) %>%
    normalize_census_corrections_registry()
}

empty_census_corrections_audit <- function() {
  data.frame(
    correction_row_id = integer(),
    applied_at = character(),
    trade_flow = character(),
    country = character(),
    rice_type = character(),
    hs_code = character(),
    input_volume = numeric(),
    input_unit = character(),
    input_equivalent = character(),
    normalized_unadjusted_mt_delta = numeric(),
    normalized_raw_volume_delta = numeric(),
    normalized_rough_eq_delta = numeric(),
    start_year = integer(),
    start_month = integer(),
    end_year = integer(),
    end_month = integer(),
    matched_row_count = integer(),
    affected_month_span = character(),
    target_file = character(),
    before_total_raw_volume = numeric(),
    after_total_raw_volume = numeric(),
    before_total_rough_eq_volume = numeric(),
    after_total_rough_eq_volume = numeric(),
    total_raw_delta_applied = numeric(),
    total_rough_eq_delta_applied = numeric(),
    stringsAsFactors = FALSE
  )
}

load_census_corrections_audit <- function(audit_file) {
  if (!file.exists(audit_file)) return(empty_census_corrections_audit())

  tryCatch({
    audit_df <- read.csv(audit_file, stringsAsFactors = FALSE, check.names = FALSE)
    required_cols <- names(empty_census_corrections_audit())
    for (col_name in required_cols) {
      if (!col_name %in% names(audit_df)) audit_df[[col_name]] <- empty_census_corrections_audit()[[col_name]]
    }

    audit_df %>%
      transmute(
        correction_row_id = suppressWarnings(as.integer(.data$correction_row_id)),
        applied_at = as.character(.data$applied_at),
        trade_flow = trimws(as.character(.data$trade_flow)),
        country = trimws(as.character(.data$country)),
        rice_type = trimws(as.character(.data$rice_type)),
        hs_code = trimws(as.character(.data$hs_code)),
        input_volume = suppressWarnings(as.numeric(.data$input_volume)),
        input_unit = trimws(as.character(.data$input_unit)),
        input_equivalent = trimws(as.character(.data$input_equivalent)),
        normalized_unadjusted_mt_delta = suppressWarnings(as.numeric(.data$normalized_unadjusted_mt_delta)),
        normalized_raw_volume_delta = suppressWarnings(as.numeric(.data$normalized_raw_volume_delta)),
        normalized_rough_eq_delta = suppressWarnings(as.numeric(.data$normalized_rough_eq_delta)),
        start_year = suppressWarnings(as.integer(.data$start_year)),
        start_month = suppressWarnings(as.integer(.data$start_month)),
        end_year = suppressWarnings(as.integer(.data$end_year)),
        end_month = suppressWarnings(as.integer(.data$end_month)),
        matched_row_count = suppressWarnings(as.integer(.data$matched_row_count)),
        affected_month_span = trimws(as.character(.data$affected_month_span)),
        target_file = trimws(as.character(.data$target_file)),
        before_total_raw_volume = suppressWarnings(as.numeric(.data$before_total_raw_volume)),
        after_total_raw_volume = suppressWarnings(as.numeric(.data$after_total_raw_volume)),
        before_total_rough_eq_volume = suppressWarnings(as.numeric(.data$before_total_rough_eq_volume)),
        after_total_rough_eq_volume = suppressWarnings(as.numeric(.data$after_total_rough_eq_volume)),
        total_raw_delta_applied = suppressWarnings(as.numeric(.data$total_raw_delta_applied)),
        total_rough_eq_delta_applied = suppressWarnings(as.numeric(.data$total_rough_eq_delta_applied))
      )
  }, error = function(e) {
    empty_census_corrections_audit()
  })
}

clear_census_corrections_state <- function(audit_file = census_corrections_audit_path,
                                           marker_file = census_corrections_state_marker_path) {
  if (file.exists(audit_file)) file.remove(audit_file)
  if (file.exists(marker_file)) file.remove(marker_file)
  invisible(NULL)
}

startup_stage_start_time <- Sys.time()
country_canonical_map <- build_country_canonical_map(
  baseline_table_path = country_baseline_table_path,
  review_table_path = country_review_table_path,
  review_generator_path = country_review_generator_path,
  readme_path = country_harmonization_readme_path
)
log_perf(
  "startup_init(build_country_canonical_map)",
  startup_stage_start_time,
  details = list(rows = nrow(country_canonical_map))
)

sanitize_filename_component <- function(value, max_length = 60L) {
  value_chr <- if (is.null(value) || length(value) == 0) "" else as.character(value[[1]])
  value_chr <- trimws(value_chr)
  if (!nzchar(value_chr)) value_chr <- "unknown"

  sanitized <- value_chr %>%
    stringr::str_replace_all("[^A-Za-z0-9]+", "_") %>%
    stringr::str_replace_all("_+", "_") %>%
    stringr::str_replace_all("^_+|_+$", "")

  if (!nzchar(sanitized)) sanitized <- "unknown"
  if (nchar(sanitized) > max_length) sanitized <- substr(sanitized, 1L, max_length)
  sanitized
}

build_publish_timestamp <- function(now = Sys.time()) {
  fractional_seconds <- sprintf("%03d", as.integer((as.numeric(now) %% 1) * 1000))
  paste0(format(now, "%Y%m%d_%H%M%S"), "_", fractional_seconds)
}

build_published_data_filename <- function(user_id, metric_label, commodity_label, country_label,
                                          timestamp = build_publish_timestamp(), extension = "csv") {
  parts <- c(
    sanitize_filename_component(user_id, max_length = 40L),
    sanitize_filename_component(metric_label, max_length = 60L),
    sanitize_filename_component(commodity_label, max_length = 60L),
    sanitize_filename_component(country_label, max_length = 60L),
    sanitize_filename_component(timestamp, max_length = 24L)
  )

  paste0(paste(parts, collapse = "__"), ".", extension)
}

publish_data_to_csv <- function(data, metric_label, commodity_label, country_label,
                                output_dir = app_output_dir, publisher_id = user_id,
                                timestamp = build_publish_timestamp()) {
  if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)

  file_name <- build_published_data_filename(
    user_id = publisher_id,
    metric_label = metric_label,
    commodity_label = commodity_label,
    country_label = country_label,
    timestamp = timestamp
  )
  output_path <- file.path(output_dir, file_name)

  write.csv(data, output_path, row.names = FALSE)
  output_path
}

plotly_empty_state <- function(plot_title = NULL) {
  plotly_empty(type = "scatter", mode = "lines") %>%
    layout(
      title = plot_title,
      xaxis = list(visible = FALSE, showgrid = FALSE, zeroline = FALSE),
      yaxis = list(visible = FALSE, showgrid = FALSE, zeroline = FALSE),
      showlegend = FALSE
    )
}

load_custom_types <- function(custom_types_file, census_reset_marker_file = NULL, hybrid_reset_marker_file = NULL) {
  empty_df <- data.frame(
    custom_name = character(),
    formula = character(),
    normalized_formula = character(),
    source_scope = character(),
    created_at = character(),
    updated_at = character(),
    version = character(),
    stringsAsFactors = FALSE
  )
  attr(empty_df, "census_reset_removed_count") <- 0L
  attr(empty_df, "hybrid_reset_removed_count") <- 0L

  if (!file.exists(custom_types_file)) return(empty_df)

  tryCatch({
    df <- read.csv(custom_types_file, stringsAsFactors = FALSE)
    required_cols <- c("custom_name", "formula", "normalized_formula", "source_scope", "created_at", "updated_at", "version")
    for (col_name in required_cols) {
      if (!col_name %in% names(df)) df[[col_name]] <- ""
    }

    census_scope_reset_applied <- !is.null(census_reset_marker_file) && file.exists(census_reset_marker_file)
    hybrid_scope_reset_applied <- !is.null(hybrid_reset_marker_file) && file.exists(hybrid_reset_marker_file)

    normalize_scope_token <- function(scope_value) {
      token <- tolower(trimws(as.character(scope_value)))
      token <- gsub("[^a-z0-9]+", "_", token)
      token <- gsub("_+", "_", token)
      token <- gsub("^_|_$", "", token)
      token
    }

    normalized_df <- df %>%
      mutate(
        custom_name = trimws(.data$custom_name),
        formula = trimws(.data$formula),
        normalized_formula = trimws(.data$normalized_formula),
        source_scope_raw = trimws(as.character(.data$source_scope)),
        source_scope_token = vapply(.data$source_scope_raw, normalize_scope_token, character(1)),
        is_hybrid_scope = startsWith(.data$source_scope_token, "hybrid"),
        source_scope = dplyr::case_when(
          .data$source_scope_token %in% c("export_sales", "census_export", "census_import", "hybrid_export", "hybrid_import", "psd", "wasde") ~ .data$source_scope_token,
          TRUE ~ "export_sales"
        ),
        created_at = as.character(.data$created_at),
        updated_at = as.character(.data$updated_at),
        version = as.character(.data$version)
      ) %>%
      filter(nzchar(.data$custom_name), nzchar(.data$formula)) %>%
      distinct(custom_name, source_scope, .keep_all = TRUE)

    census_scopes <- c("census", "census_export", "census_import")
    census_removed_count <- 0L
    hybrid_removed_count <- 0L

    if (!census_scope_reset_applied) {
      census_removed_count <- sum(normalized_df$source_scope_token %in% census_scopes, na.rm = TRUE)
      if (census_removed_count > 0) {
        normalized_df <- normalized_df %>%
          filter(!(.data$source_scope_token %in% census_scopes))
      }

      if (!is.null(census_reset_marker_file)) {
        tryCatch({
          writeLines(as.character(Sys.time()), census_reset_marker_file)
        }, error = function(e) {
          invisible(NULL)
        })
      }

    }

    if (!hybrid_scope_reset_applied && !is.null(hybrid_reset_marker_file)) {
      hybrid_removed_count <- sum(normalized_df$is_hybrid_scope, na.rm = TRUE)
      if (hybrid_removed_count > 0) {
        normalized_df <- normalized_df %>%
          filter(!.data$is_hybrid_scope)
      }

      tryCatch({
        writeLines(as.character(Sys.time()), hybrid_reset_marker_file)
      }, error = function(e) {
        invisible(NULL)
      })
    }

    if (census_removed_count > 0 || hybrid_removed_count > 0) {
      # Persist one-time scope resets so users can recreate clean flow-specific types.
      save_custom_types(
        as.data.frame(normalized_df %>% select(-all_of(c("source_scope_raw", "source_scope_token", "is_hybrid_scope"))), stringsAsFactors = FALSE),
        custom_types_file
      )
    }

    result_df <- normalized_df %>%
      select(-all_of(c("source_scope_raw", "source_scope_token", "is_hybrid_scope")))
    attr(result_df, "census_reset_removed_count") <- as.integer(census_removed_count)
    attr(result_df, "hybrid_reset_removed_count") <- as.integer(hybrid_removed_count)
    result_df
  }, error = function(e) {
    empty_df
  })
}

save_custom_types <- function(custom_types_df, custom_types_file) {
  write_csv_with_backup_replace(custom_types_df, custom_types_file, row.names = FALSE)
}

normalize_custom_definition_scope <- function(scope_value, default_scope = "export_sales") {
  scope_token <- tolower(trimws(as.character(scope_value %||% default_scope)[[1]] %||% default_scope))
  scope_token <- gsub("[^a-z0-9]+", "_", scope_token)
  scope_token <- gsub("_+", "_", scope_token)
  scope_token <- gsub("^_|_$", "", scope_token)

  if (identical(scope_token, "census")) return("census_export")
  if (identical(scope_token, "hybrid")) return("hybrid_export")
  if (scope_token %in% c("export_sales", "census_export", "census_import", "hybrid_export", "hybrid_import", "psd", "wasde", "nass")) {
    return(scope_token)
  }

  default_scope
}

empty_custom_countries_df <- function() {
  data.frame(
    custom_country_id = character(),
    custom_name = character(),
    formula = character(),
    normalized_formula = character(),
    source_scope = character(),
    created_at = character(),
    updated_at = character(),
    version = character(),
    stringsAsFactors = FALSE
  )
}

build_deterministic_custom_country_id <- function(custom_name, normalized_formula, source_scope) {
  seed <- paste(
    tolower(trimws(as.character(custom_name %||% ""))),
    tolower(trimws(as.character(normalized_formula %||% ""))),
    tolower(trimws(as.character(source_scope %||% ""))),
    sep = "||"
  )

  chars <- utf8ToInt(enc2utf8(seed))
  if (length(chars) == 0) {
    return("cc_00000000")
  }

  mod_value <- 4294967291
  hash_value <- 2166136261
  for (code_value in chars) {
    hash_value <- (hash_value * 16777619 + as.numeric(code_value)) %% mod_value
  }

  hi <- floor(hash_value / 65536)
  lo <- hash_value %% 65536
  paste0("cc_", sprintf("%04x%04x", hi, lo))
}

load_custom_countries <- function(custom_countries_file) {
  empty_df <- empty_custom_countries_df()
  if (!file.exists(custom_countries_file)) return(empty_df)

  tryCatch({
    loaded_df <- read.csv(custom_countries_file, stringsAsFactors = FALSE)
    required_cols <- names(empty_df)
    for (col_name in required_cols) {
      if (!col_name %in% names(loaded_df)) loaded_df[[col_name]] <- ""
    }

    normalized_df <- loaded_df %>%
      transmute(
        custom_country_id = trimws(as.character(.data$custom_country_id)),
        custom_name = trimws(as.character(.data$custom_name)),
        formula = trimws(as.character(.data$formula)),
        normalized_formula = trimws(as.character(.data$normalized_formula)),
        source_scope = vapply(as.character(.data$source_scope), normalize_custom_definition_scope, character(1), default_scope = "export_sales"),
        created_at = as.character(.data$created_at),
        updated_at = as.character(.data$updated_at),
        version = as.character(.data$version)
      ) %>%
      filter(nzchar(.data$custom_name), nzchar(.data$formula)) %>%
      mutate(custom_name_key = tolower(.data$custom_name)) %>%
      arrange(.data$source_scope, .data$custom_name_key, dplyr::desc(.data$updated_at), dplyr::desc(.data$created_at)) %>%
      distinct(.data$source_scope, .data$custom_name_key, .keep_all = TRUE) %>%
      mutate(
        normalized_formula = if_else(nzchar(.data$normalized_formula), .data$normalized_formula, .data$formula),
        custom_country_id = if_else(
          nzchar(.data$custom_country_id),
          .data$custom_country_id,
          mapply(
            build_deterministic_custom_country_id,
            custom_name = .data$custom_name,
            normalized_formula = .data$normalized_formula,
            source_scope = .data$source_scope,
            USE.NAMES = FALSE
          )
        ),
        version = if_else(nzchar(.data$version), .data$version, "1")
      ) %>%
      select(-.data$custom_name_key)

    as.data.frame(normalized_df, stringsAsFactors = FALSE)
  }, error = function(...) {
    empty_df
  })
}

save_custom_countries <- function(custom_countries_df, custom_countries_file) {
  write_csv_with_backup_replace(custom_countries_df, custom_countries_file, row.names = FALSE)
}

custom_country_context_key_for_scope <- function(source_scope, frequency = "monthly") {
  normalized_scope <- normalize_custom_definition_scope(source_scope)
  frequency_value <- tolower(trimws(as.character(frequency %||% "monthly")[[1]] %||% "monthly"))

  if (identical(normalized_scope, "export_sales")) {
    return(if (identical(frequency_value, "weekly")) "export_sales_weekly" else "export_sales_monthly")
  }
  if (identical(normalized_scope, "census_export")) return("census_export")
  if (identical(normalized_scope, "census_import")) return("census_import")
  if (identical(normalized_scope, "hybrid_export")) {
    return(if (identical(frequency_value, "weekly")) "hybrid_weekly_imputed" else "hybrid_export_monthly")
  }
  if (identical(normalized_scope, "hybrid_import")) return("hybrid_import_monthly")
  if (identical(normalized_scope, "psd")) return("psd")
  if (identical(normalized_scope, "wasde")) return("wasde")

  if (identical(normalized_scope, "nass")) return("nass")
  "export_sales_monthly"
}

custom_country_native_choice_map <- function(source_scope, frequency = "monthly") {
  context_key <- custom_country_context_key_for_scope(source_scope, frequency = frequency)
  context_choices <- get_country_display_names_for_context(context_key)
  if (length(context_choices) == 0) {
    context_choices <- country_display_names
  }

  context_choices
}

build_custom_country_lookup <- function(source_scope, frequency = "monthly") {
  native_choices <- custom_country_native_choice_map(source_scope, frequency = frequency)
  if (length(native_choices) == 0) {
    return(list(
      lookup_table = data.frame(lookup_key = character(), canonical_country_code = character(), stringsAsFactors = FALSE),
      ambiguous_keys = character(),
      native_choices = native_choices
    ))
  }

  label_values <- names(native_choices)
  code_values <- unname(native_choices)

  lookup_rows <- bind_rows(
    tibble::tibble(
      lookup_key = normalize_notes_country_lookup_key(label_values),
      canonical_country_code = code_values,
      lookup_source = "label"
    ),
    tibble::tibble(
      lookup_key = normalize_notes_country_lookup_key(code_values),
      canonical_country_code = code_values,
      lookup_source = "code"
    ),
    tibble::tibble(
      lookup_key = c("world", "grand total", "grand_total"),
      canonical_country_code = "GRAND_TOTAL",
      lookup_source = "world_alias"
    )
  ) %>%
    filter(!is.na(.data$lookup_key), nzchar(.data$lookup_key), !is.na(.data$canonical_country_code), nzchar(.data$canonical_country_code))

  ambiguous_keys <- lookup_rows %>%
    group_by(.data$lookup_key) %>%
    summarise(code_count = n_distinct(.data$canonical_country_code), .groups = "drop") %>%
    filter(.data$code_count > 1) %>%
    pull(.data$lookup_key)

  prioritized_rows <- lookup_rows %>%
    mutate(
      lookup_priority = dplyr::case_when(
        .data$lookup_source == "code" ~ 1L,
        .data$lookup_source == "label" ~ 2L,
        .data$lookup_source == "world_alias" ~ 3L,
        TRUE ~ 9L
      )
    ) %>%
    arrange(.data$lookup_key, .data$lookup_priority, .data$canonical_country_code) %>%
    distinct(.data$lookup_key, .keep_all = TRUE) %>%
    select(.data$lookup_key, .data$canonical_country_code)

  list(
    lookup_table = as.data.frame(prioritized_rows, stringsAsFactors = FALSE),
    ambiguous_keys = as.character(ambiguous_keys),
    native_choices = native_choices
  )
}

canonicalize_custom_country_tokens_strict <- function(token_values, source_scope, frequency = "monthly") {
  raw_tokens <- trimws(as.character(token_values %||% character()))
  if (length(raw_tokens) == 0) {
    return(list(
      canonical_tokens = character(),
      missing_tokens = character(),
      ambiguous_tokens = character(),
      lookup = build_custom_country_lookup(source_scope, frequency)
    ))
  }

  lookup_bundle <- build_custom_country_lookup(source_scope, frequency = frequency)
  lookup_table <- lookup_bundle$lookup_table
  lookup_named <- if (nrow(lookup_table) > 0) {
    stats::setNames(lookup_table$canonical_country_code, lookup_table$lookup_key)
  } else {
    stats::setNames(character(), character())
  }

  lookup_keys <- normalize_notes_country_lookup_key(raw_tokens)
  matched_codes <- unname(lookup_named[lookup_keys])
  matched_codes[lookup_keys %in% c("world", "grand total", "grand_total")] <- "GRAND_TOTAL"

  ambiguous_mask <- lookup_keys %in% lookup_bundle$ambiguous_keys
  missing_mask <- is.na(matched_codes) | !nzchar(matched_codes)

  canonical_tokens <- matched_codes
  canonical_tokens[ambiguous_mask | missing_mask] <- NA_character_

  list(
    canonical_tokens = canonical_tokens,
    missing_tokens = unique(raw_tokens[missing_mask & !ambiguous_mask]),
    ambiguous_tokens = unique(raw_tokens[ambiguous_mask]),
    lookup = lookup_bundle
  )
}

rewrite_custom_country_formula_tokens <- function(formula_text, token_replacements) {
  token_replacements <- token_replacements %||% stats::setNames(character(), character())
  parsed_tokens <- tokenize_custom_formula(formula_text)

  rebuilt_parts <- vapply(parsed_tokens, function(token_item) {
    token_type <- token_item$type
    token_value <- token_item$value

    if (identical(token_type, "commodity")) {
      replacement <- token_replacements[[token_value]] %||% token_value
      return(paste0("{", replacement, "}"))
    }

    token_value
  }, character(1))

  paste(rebuilt_parts, collapse = " ")
}

parse_custom_country_formula <- function(formula_text, source_scope, frequency = "monthly", custom_country_names = character(), max_chars = 1000L, max_tokens = 200L, max_abs_coef = 1e6) {
  parsed_tokens <- tokenize_custom_formula(formula_text)
  commodity_tokens <- vapply(parsed_tokens, function(token_item) {
    if (identical(token_item$type, "commodity")) token_item$value else NA_character_
  }, character(1))
  commodity_tokens <- commodity_tokens[!is.na(commodity_tokens)]
  normalized_token_keys <- normalize_notes_country_lookup_key(commodity_tokens)

  custom_name_values <- trimws(as.character(custom_country_names %||% character()))
  custom_name_values <- custom_name_values[!is.na(custom_name_values) & nzchar(custom_name_values)]
  custom_name_lookup <- stats::setNames(custom_name_values, normalize_notes_country_lookup_key(custom_name_values))

  custom_token_mask <- normalized_token_keys %in% names(custom_name_lookup)
  native_tokens <- commodity_tokens[!custom_token_mask]
  native_resolution <- canonicalize_custom_country_tokens_strict(native_tokens, source_scope = source_scope, frequency = frequency)

  if (length(native_resolution$ambiguous_tokens) > 0) {
    stop(
      paste0(
        "Formula contains ambiguous country token(s): ",
        paste(native_resolution$ambiguous_tokens, collapse = ", "),
        ". Use explicit canonical country codes."
      ),
      call. = FALSE
    )
  }

  if (length(native_resolution$missing_tokens) > 0) {
    stop(
      paste0(
        "Formula contains unknown country token(s): ",
        paste(native_resolution$missing_tokens, collapse = ", "),
        "."
      ),
      call. = FALSE
    )
  }

  token_replacements <- stats::setNames(character(), character())
  if (length(native_tokens) > 0) {
    token_replacements[native_tokens] <- native_resolution$canonical_tokens
  }

  referenced_custom_countries <- character()
  if (length(commodity_tokens) > 0 && length(custom_name_lookup) > 0) {
    custom_mask <- normalized_token_keys %in% names(custom_name_lookup)
    if (any(custom_mask)) {
      custom_tokens <- commodity_tokens[custom_mask]
      resolved_custom_names <- unname(custom_name_lookup[normalized_token_keys[custom_mask]])
      custom_marker_tokens <- paste0("custom:", tolower(resolved_custom_names))
      token_replacements[custom_tokens] <- custom_marker_tokens
      referenced_custom_countries <- unique(resolved_custom_names)
    }
  }

  rewritten_formula <- rewrite_custom_country_formula_tokens(formula_text, token_replacements = token_replacements)
  allowed_terms <- unique(c(
    unname(native_resolution$lookup$native_choices),
    paste0("custom:", tolower(custom_name_values))
  ))
  allowed_terms <- allowed_terms[!is.na(allowed_terms) & nzchar(allowed_terms)]

  parsed <- parse_custom_formula(
    formula_text = rewritten_formula,
    native_commodities = allowed_terms,
    max_chars = max_chars,
    max_tokens = max_tokens,
    max_abs_coef = max_abs_coef
  )

  referenced_custom_keys <- parsed$referenced_commodities[startsWith(parsed$referenced_commodities, "custom:")]
  referenced_custom_countries <- unique(c(
    referenced_custom_countries,
    sub("^custom:", "", referenced_custom_keys)
  ))

  referenced_country_codes <- parsed$referenced_commodities[!startsWith(parsed$referenced_commodities, "custom:")]

  list(
    coefficients = parsed$coefficients,
    referenced_countries = referenced_country_codes,
    referenced_custom_countries = referenced_custom_countries,
    normalized_formula = parsed$normalized_formula,
    rewritten_formula = rewritten_formula,
    is_zero_formula = parsed$is_zero_formula
  )
}

detect_custom_country_cycles <- function(custom_country_defs) {
  if (!is.data.frame(custom_country_defs) || nrow(custom_country_defs) == 0) {
    return(list(has_cycle = FALSE, cycles = character(), cycle_nodes = character()))
  }

  defs_df <- as_tibble(custom_country_defs) %>%
    transmute(
      custom_name = trimws(as.character(.data$custom_name)),
      custom_name_key = tolower(trimws(as.character(.data$custom_name))),
      referenced_custom_countries = .data$referenced_custom_countries
    ) %>%
    filter(!is.na(.data$custom_name_key), nzchar(.data$custom_name_key))

  if (nrow(defs_df) == 0) {
    return(list(has_cycle = FALSE, cycles = character(), cycle_nodes = character()))
  }

  adjacency <- stats::setNames(vector("list", length = nrow(defs_df)), defs_df$custom_name_key)
  display_name_lookup <- stats::setNames(defs_df$custom_name, defs_df$custom_name_key)

  for (row_index in seq_len(nrow(defs_df))) {
    from_key <- defs_df$custom_name_key[[row_index]]
    refs <- defs_df$referenced_custom_countries[[row_index]]
    refs <- tolower(trimws(as.character(refs %||% character())))
    refs <- unique(refs[!is.na(refs) & nzchar(refs)])
    adjacency[[from_key]] <- refs[refs %in% names(adjacency)]
  }

  visit_state <- stats::setNames(rep.int(0L, length(adjacency)), names(adjacency))
  active_stack <- character()
  cycle_signatures <- character()
  cycle_nodes <- character()

  visit_node <- function(node_key) {
    visit_state[[node_key]] <<- 1L
    active_stack <<- c(active_stack, node_key)

    next_nodes <- adjacency[[node_key]]
    for (next_key in next_nodes) {
      next_state <- visit_state[[next_key]]

      if (identical(next_state, 0L)) {
        visit_node(next_key)
      } else if (identical(next_state, 1L)) {
        start_idx <- match(next_key, active_stack)
        cycle_keys <- c(active_stack[start_idx:length(active_stack)], next_key)
        cycle_nodes <<- c(cycle_nodes, cycle_keys)
        cycle_labels <- unname(display_name_lookup[cycle_keys])
        cycle_labels[is.na(cycle_labels) | !nzchar(cycle_labels)] <- cycle_keys[is.na(cycle_labels) | !nzchar(cycle_labels)]
        cycle_signatures <<- c(cycle_signatures, paste(cycle_labels, collapse = " -> "))
      }
    }

    active_stack <<- active_stack[-length(active_stack)]
    visit_state[[node_key]] <<- 2L
  }

  for (node_key in names(adjacency)) {
    if (identical(visit_state[[node_key]], 0L)) {
      visit_node(node_key)
    }
  }

  unique_cycles <- unique(cycle_signatures)
  list(
    has_cycle = length(unique_cycles) > 0,
    cycles = unique_cycles,
    cycle_nodes = unique(cycle_nodes)
  )
}

build_rice_type_choices <- function(native_commodities, custom_names, include_builder = TRUE) {
  aggregate_label <- COMMODITY_AGGREGATE_LABEL
  order_with_aggregate_first <- function(values) {
    choice_values <- trimws(as.character(values %||% character()))
    choice_labels <- names(values)
    if (is.null(choice_labels) || length(choice_labels) != length(choice_values)) {
      choice_labels <- choice_values
    }
    choice_labels <- trimws(as.character(choice_labels))
    blank_labels <- is.na(choice_labels) | !nzchar(choice_labels)
    choice_labels[blank_labels] <- choice_values[blank_labels]
    keep <- !is.na(choice_values) & nzchar(choice_values)
    choice_values <- choice_values[keep]
    choice_labels <- choice_labels[keep]
    if (length(choice_values) == 0L) return(stats::setNames(character(0), character(0)))

    first_idx <- !duplicated(choice_values)
    choice_values <- choice_values[first_idx]
    choice_labels <- choice_labels[first_idx]
    ordered_idx <- order(choice_values)
    if (aggregate_label %in% choice_values) {
      aggregate_idx <- which(choice_values == aggregate_label)[[1L]]
      ordered_idx <- c(aggregate_idx, setdiff(ordered_idx, aggregate_idx))
    }

    stats::setNames(choice_values[ordered_idx], choice_labels[ordered_idx])
  }

  native_values <- order_with_aggregate_first(native_commodities)
  custom_values <- order_with_aggregate_first(custom_names[!custom_names %in% unname(native_values)])

  base_choices <- native_values
  custom_choices <- custom_values

  if (isTRUE(include_builder)) {
    c(base_choices, custom_choices, "Custom" = CUSTOM_BUILDER_CHOICE)
  } else {
    c(base_choices, custom_choices)
  }
}

group_rice_type_choices <- function(flat_choices, custom_names, include_builder = TRUE, builder_group_label = "Actions") {
  if (length(flat_choices) == 0) {
    return(flat_choices)
  }

  choice_labels <- names(flat_choices)
  choice_values <- unname(flat_choices)
  if (is.null(choice_labels)) {
    choice_labels <- choice_values
  }

  custom_values <- unique(as.character(custom_names))
  builder_mask <- !is.na(choice_values) & choice_values == CUSTOM_BUILDER_CHOICE
  custom_mask <- !builder_mask & !is.na(choice_values) & choice_values %in% custom_values
  native_mask <- !builder_mask & !custom_mask

  grouped_choices <- list()

  if (any(native_mask)) {
    grouped_choices[["Native Types"]] <- stats::setNames(choice_values[native_mask], choice_labels[native_mask])
  }

  if (any(custom_mask)) {
    grouped_choices[["Custom Types"]] <- stats::setNames(choice_values[custom_mask], choice_labels[custom_mask])
  }

  if (isTRUE(include_builder) && any(builder_mask)) {
    grouped_choices[[builder_group_label]] <- stats::setNames(choice_values[builder_mask], choice_labels[builder_mask])
  }

  if (length(grouped_choices) == 0) {
    return(flat_choices)
  }

  grouped_choices
}

tokenize_custom_formula <- function(formula_text) {
  tokens <- list()
  text <- as.character(formula_text)
  i <- 1L
  n <- nchar(text)

  while (i <= n) {
    current <- substr(text, i, i)

    if (grepl("\\s", current)) {
      i <- i + 1L
      next
    }

    if (current %in% c("+", "-", "*", "(", ")")) {
      tokens[[length(tokens) + 1L]] <- list(type = "op", value = current)
      i <- i + 1L
      next
    }

    remaining <- substr(text, i, n)

    if (grepl("^[0-9]+(\\.[0-9]+)?", remaining)) {
      match <- regmatches(remaining, regexpr("^[0-9]+(\\.[0-9]+)?", remaining))
      tokens[[length(tokens) + 1L]] <- list(type = "number", value = match)
      i <- i + nchar(match)
      next
    }

    if (current == "{") {
      close_pos <- regexpr("}", substr(text, i + 1L, n), fixed = TRUE)
      if (close_pos[1] == -1) {
        stop("Missing closing } for commodity token.", call. = FALSE)
      }

      token_value <- substr(text, i + 1L, i + close_pos[1] - 1L)
      token_value <- trimws(token_value)
      if (!nzchar(token_value)) {
        stop("Empty commodity token {} is not allowed.", call. = FALSE)
      }

      tokens[[length(tokens) + 1L]] <- list(type = "commodity", value = token_value)
      i <- i + close_pos[1] + 1L
      next
    }

    if (current == "/") {
      stop("Division is not supported in custom formulas.", call. = FALSE)
    }

    stop(paste0("Invalid token at position ", i, ". Use {Commodity Name} for operands."), call. = FALSE)
  }

  tokens
}

parse_custom_formula <- function(formula_text, native_commodities, max_chars = 1000L, max_tokens = 200L, max_abs_coef = 1e6) {
  formula_trim <- trimws(as.character(formula_text))
  if (!nzchar(formula_trim)) stop("Formula cannot be empty.", call. = FALSE)
  if (nchar(formula_trim) > max_chars) stop("Formula is too long.", call. = FALSE)

  tokens <- tokenize_custom_formula(formula_trim)
  if (length(tokens) == 0L) stop("Formula cannot be empty.", call. = FALSE)
  if (length(tokens) > max_tokens) stop("Formula has too many tokens.", call. = FALSE)

  output_queue <- list()
  operator_stack <- list()

  precedence <- function(op) {
    if (op == "u-") return(3L)
    if (op == "*") return(2L)
    if (op %in% c("+", "-")) return(1L)
    0L
  }

  right_assoc <- function(op) op == "u-"

  prev_type <- "start"
  for (tok in tokens) {
    if (tok$type %in% c("number", "commodity")) {
      output_queue[[length(output_queue) + 1L]] <- tok
      prev_type <- tok$type
      next
    }

    if (tok$type == "op" && tok$value == "(") {
      operator_stack[[length(operator_stack) + 1L]] <- list(type = "op", value = "(")
      prev_type <- "lparen"
      next
    }

    if (tok$type == "op" && tok$value == ")") {
      found_lparen <- FALSE
      while (length(operator_stack) > 0L) {
        top <- operator_stack[[length(operator_stack)]]
        operator_stack <- operator_stack[-length(operator_stack)]
        if (top$value == "(") {
          found_lparen <- TRUE
          break
        }
        output_queue[[length(output_queue) + 1L]] <- top
      }
      if (!found_lparen) stop("Unbalanced parentheses.", call. = FALSE)
      prev_type <- "rparen"
      next
    }

    if (tok$type == "op" && tok$value %in% c("+", "-", "*")) {
      op_value <- tok$value
      if (op_value == "-" && prev_type %in% c("start", "op", "lparen")) op_value <- "u-"
      if (op_value == "*" && prev_type %in% c("start", "op", "lparen")) {
        stop("Operator * cannot appear here.", call. = FALSE)
      }

      while (length(operator_stack) > 0L) {
        top <- operator_stack[[length(operator_stack)]]
        if (top$value == "(") break

        current_prec <- precedence(op_value)
        top_prec <- precedence(top$value)
        if (top_prec > current_prec || (top_prec == current_prec && !right_assoc(op_value))) {
          output_queue[[length(output_queue) + 1L]] <- top
          operator_stack <- operator_stack[-length(operator_stack)]
        } else {
          break
        }
      }

      operator_stack[[length(operator_stack) + 1L]] <- list(type = "op", value = op_value)
      prev_type <- "op"
      next
    }
  }

  while (length(operator_stack) > 0L) {
    top <- operator_stack[[length(operator_stack)]]
    operator_stack <- operator_stack[-length(operator_stack)]
    if (top$value == "(") stop("Unbalanced parentheses.", call. = FALSE)
    output_queue[[length(output_queue) + 1L]] <- top
  }

  make_scalar <- function(value) list(kind = "scalar", value = value, refs = character())
  make_terms <- function(coeffs, refs = names(coeffs)) {
    coeff_names <- names(coeffs)
    coeffs <- as.numeric(coeffs)
    names(coeffs) <- coeff_names
    list(kind = "terms", coeffs = coeffs, refs = unique(refs))
  }

  combine_terms <- function(a, b, sign = 1) {
    keys <- union(names(a$coeffs), names(b$coeffs))
    out <- setNames(rep(0, length(keys)), keys)
    out[names(a$coeffs)] <- out[names(a$coeffs)] + a$coeffs
    out[names(b$coeffs)] <- out[names(b$coeffs)] + sign * b$coeffs
    make_terms(out, refs = union(a$refs, b$refs))
  }

  scale_terms <- function(terms, factor) {
    make_terms(terms$coeffs * factor, refs = terms$refs)
  }

  eval_stack <- list()
  for (tok in output_queue) {
    if (tok$type == "number") {
      numeric_value <- suppressWarnings(as.numeric(tok$value))
      if (!is.finite(numeric_value)) stop("Coefficient must be a finite number.", call. = FALSE)
      eval_stack[[length(eval_stack) + 1L]] <- make_scalar(numeric_value)
      next
    }

    if (tok$type == "commodity") {
      if (!(tok$value %in% native_commodities)) {
        stop(paste0("Unknown commodity token: {", tok$value, "}"), call. = FALSE)
      }
      eval_stack[[length(eval_stack) + 1L]] <- make_terms(setNames(1, tok$value), refs = tok$value)
      next
    }

    if (tok$type == "op" && tok$value == "u-") {
      if (length(eval_stack) < 1L) stop("Invalid unary minus placement.", call. = FALSE)
      top <- eval_stack[[length(eval_stack)]]
      eval_stack <- eval_stack[-length(eval_stack)]
      if (top$kind == "scalar") {
        eval_stack[[length(eval_stack) + 1L]] <- make_scalar(-top$value)
      } else {
        eval_stack[[length(eval_stack) + 1L]] <- scale_terms(top, -1)
      }
      next
    }

    if (length(eval_stack) < 2L) stop("Malformed formula.", call. = FALSE)
    right <- eval_stack[[length(eval_stack)]]
    eval_stack <- eval_stack[-length(eval_stack)]
    left <- eval_stack[[length(eval_stack)]]
    eval_stack <- eval_stack[-length(eval_stack)]

    if (tok$value == "+") {
      if (left$kind == "scalar" || right$kind == "scalar") {
        stop("Standalone scalar terms are not allowed; coefficients must multiply a commodity token.", call. = FALSE)
      }
      eval_stack[[length(eval_stack) + 1L]] <- combine_terms(left, right, sign = 1)
      next
    }

    if (tok$value == "-") {
      if (left$kind == "scalar" || right$kind == "scalar") {
        stop("Standalone scalar terms are not allowed; coefficients must multiply a commodity token.", call. = FALSE)
      }
      eval_stack[[length(eval_stack) + 1L]] <- combine_terms(left, right, sign = -1)
      next
    }

    if (tok$value == "*") {
      if (left$kind == "terms" && right$kind == "terms") {
        stop("Multiplication between commodity terms is not supported.", call. = FALSE)
      }
      if (left$kind == "scalar" && right$kind == "scalar") {
        eval_stack[[length(eval_stack) + 1L]] <- make_scalar(left$value * right$value)
      } else if (left$kind == "scalar" && right$kind == "terms") {
        eval_stack[[length(eval_stack) + 1L]] <- scale_terms(right, left$value)
      } else if (left$kind == "terms" && right$kind == "scalar") {
        eval_stack[[length(eval_stack) + 1L]] <- scale_terms(left, right$value)
      }
      next
    }
  }

  if (length(eval_stack) != 1L) stop("Malformed formula.", call. = FALSE)
  parsed <- eval_stack[[1L]]
  if (parsed$kind != "terms") {
    stop("Formula must resolve to commodity terms.", call. = FALSE)
  }

  if (any(!is.finite(parsed$coeffs))) {
    stop("Formula produced non-finite coefficients.", call. = FALSE)
  }

  if (any(abs(parsed$coeffs) > max_abs_coef)) {
    stop("Coefficient magnitude exceeds allowed bounds.", call. = FALSE)
  }

  referenced <- unique(parsed$refs)
  if (length(referenced) == 0L) stop("Formula must reference at least one commodity.", call. = FALSE)

  non_zero <- parsed$coeffs[abs(parsed$coeffs) > 1e-12]
  if (length(non_zero) == 0L) {
    non_zero <- setNames(0, referenced[1])
  }

  normalized_terms <- vapply(names(non_zero), function(name) {
    coef <- non_zero[[name]]
    paste0(format(coef, trim = TRUE, scientific = FALSE), "*{", name, "}")
  }, character(1L))

  normalized_formula <- paste(normalized_terms, collapse = " + ")

  list(
    coefficients = parsed$coeffs,
    referenced_commodities = referenced,
    normalized_formula = normalized_formula,
    is_zero_formula = all(abs(parsed$coeffs) <= 1e-12)
  )
}

product_basis_empty_registry <- function() {
  data.frame(
    source_scope = character(),
    commodity = character(),
    product_basis_code = character(),
    product_basis_label = character(),
    product_to_rough_factor = numeric(),
    basis_source = character(),
    derived_flag = logical(),
    basis_note = character(),
    stringsAsFactors = FALSE
  )
}

normalize_product_basis_scope <- function(source_scope) {
  token <- tolower(trimws(as.character(source_scope %||% "export_sales")[[1]]))
  token <- gsub("[^a-z0-9]+", "_", token)
  token <- gsub("_+", "_", token)
  token <- gsub("^_|_$", "", token)

  if (identical(token, "census")) return("census_export")
  if (identical(token, "hybrid")) return("hybrid_export")
  if (token %in% c("export_sales", "census_export", "census_import", "hybrid_export", "hybrid_import", "psd", "wasde")) {
    return(token)
  }

  "export_sales"
}

product_basis_label_for_code <- function(code) {
  code <- as.character(code)
  label_lookup <- c(
    rough = "Rough product-weight",
    brown = "Brown product-weight",
    milled = "Milled product-weight",
    mixed = "Mixed/variable product-weight",
    unknown = "Unknown product-weight"
  )

  out <- unname(label_lookup[code])
  out[is.na(out) | !nzchar(out)] <- label_lookup[["unknown"]]
  out
}

product_basis_factor_for_code <- function(code) {
  code <- as.character(code)
  factor_lookup <- c(
    rough = 1,
    brown = 1.25,
    milled = 1.42857142857143,
    mixed = NA_real_,
    unknown = NA_real_
  )

  out <- unname(factor_lookup[code])
  out[is.na(out) & !(code %in% c("mixed", "unknown"))] <- NA_real_
  out
}

product_basis_quantity_columns <- function(source_scope) {
  scope <- normalize_product_basis_scope(source_scope)
  switch(
    scope,
    census_export = list(product_col = "monthlyvolume", rough_col = "monthlyvolume_rough_eq"),
    census_import = list(product_col = "monthlyvolume", rough_col = "monthlyvolume_rough_eq"),
    hybrid_export = list(product_col = "monthlyexports", rough_col = "monthlyexports_rough_eq"),
    hybrid_import = list(product_col = "monthlyexports", rough_col = "monthlyexports_rough_eq"),
    export_sales = list(product_col = "monthlyexports", rough_col = "monthlyexports_rough_eq"),
    list(product_col = "monthlyexports", rough_col = "monthlyexports_rough_eq")
  )
}

resolve_product_basis_quantity_columns <- function(df, source_scope) {
  if (!is.data.frame(df) || nrow(df) == 0) return(NULL)

  preferred <- product_basis_quantity_columns(source_scope)
  product_candidates <- unique(c(preferred$product_col, "monthlyvolume", "monthlyexports"))
  rough_candidates <- unique(c(preferred$rough_col, paste0(product_candidates, "_rough_eq"), "monthlyvolume_rough_eq", "monthlyexports_rough_eq"))

  for (product_col in product_candidates) {
    if (!(product_col %in% names(df))) next

    paired_rough <- paste0(product_col, "_rough_eq")
    candidate_roughs <- unique(c(if (product_col == preferred$product_col) preferred$rough_col else paired_rough, paired_rough, rough_candidates))
    for (rough_col in candidate_roughs) {
      if (rough_col %in% names(df)) {
        return(list(product_col = product_col, rough_col = rough_col))
      }
    }
  }

  NULL
}

classify_product_basis_factors <- function(factors, tolerance = 0.035) {
  factors <- suppressWarnings(as.numeric(factors))
  factors <- factors[is.finite(factors) & factors > 0]

  if (length(factors) == 0) {
    return(list(code = "unknown", factor = NA_real_, basis_source = "insufficient_quantity_data"))
  }

  factor_codes <- vapply(factors, function(factor_value) {
    if (abs(factor_value - 1) <= tolerance) return("rough")
    if (abs(factor_value - 1.25) <= tolerance) return("brown")
    if (abs(factor_value - 1.42857142857143) <= tolerance) return("milled")
    "unknown"
  }, character(1))

  known_codes <- unique(factor_codes[factor_codes != "unknown"])
  if (length(known_codes) == 1 && all(factor_codes %in% c(known_codes, "unknown"))) {
    return(list(
      code = known_codes[[1]],
      factor = product_basis_factor_for_code(known_codes[[1]]),
      basis_source = "ratio_inference"
    ))
  }

  if (length(known_codes) > 1) {
    return(list(code = "mixed", factor = NA_real_, basis_source = "ratio_inference"))
  }

  list(code = "unknown", factor = stats::median(factors, na.rm = TRUE), basis_source = "ratio_inference")
}

normalize_product_basis_registry <- function(registry_df) {
  empty_df <- product_basis_empty_registry()
  if (!is.data.frame(registry_df) || nrow(registry_df) == 0) return(empty_df)

  out <- as.data.frame(registry_df, stringsAsFactors = FALSE)
  for (col_name in names(empty_df)) {
    if (!col_name %in% names(out)) out[[col_name]] <- empty_df[[col_name]]
  }

  out <- out[, names(empty_df), drop = FALSE]
  out$source_scope <- vapply(out$source_scope, normalize_product_basis_scope, character(1))
  out$commodity <- trimws(as.character(out$commodity))
  out$product_basis_code <- tolower(trimws(as.character(out$product_basis_code)))
  out$product_basis_code[!(out$product_basis_code %in% c("rough", "brown", "milled", "mixed", "unknown"))] <- "unknown"
  out$product_basis_label <- product_basis_label_for_code(out$product_basis_code)
  out$product_to_rough_factor <- suppressWarnings(as.numeric(out$product_to_rough_factor))
  missing_factor <- is.na(out$product_to_rough_factor)
  out$product_to_rough_factor[missing_factor] <- product_basis_factor_for_code(out$product_basis_code[missing_factor])
  out$basis_source <- trimws(as.character(out$basis_source))
  out$basis_source[!nzchar(out$basis_source)] <- "metadata"
  out$derived_flag <- as.logical(out$derived_flag)
  out$derived_flag[is.na(out$derived_flag)] <- FALSE
  out$basis_note <- trimws(as.character(out$basis_note))

  out %>%
    filter(nzchar(.data$commodity)) %>%
    distinct(.data$source_scope, .data$commodity, .keep_all = TRUE)
}

infer_product_basis_registry <- function(df, source_scope, explicit_registry = NULL) {
  scope <- normalize_product_basis_scope(source_scope)
  explicit_registry <- normalize_product_basis_registry(explicit_registry)
  explicit_registry <- explicit_registry %>% filter(.data$source_scope == scope)

  df_commodities <- if (is.data.frame(df) && "commodity" %in% names(df)) {
    sort(unique(trimws(as.character(df$commodity))))
  } else {
    character()
  }
  df_commodities <- df_commodities[!is.na(df_commodities) & nzchar(df_commodities)]
  commodity_values <- sort(unique(c(df_commodities, explicit_registry$commodity)))
  if (length(commodity_values) == 0) return(product_basis_empty_registry())

  quantity_cols <- resolve_product_basis_quantity_columns(df, scope)
  inferred_rows <- lapply(commodity_values, function(commodity_name) {
    explicit_row <- explicit_registry %>% filter(.data$commodity == commodity_name)
    if (nrow(explicit_row) > 0) {
      return(explicit_row[1, , drop = FALSE])
    }

    if (is.null(quantity_cols) || !is.data.frame(df) || nrow(df) == 0) {
      return(data.frame(
        source_scope = scope,
        commodity = commodity_name,
        product_basis_code = "unknown",
        product_basis_label = product_basis_label_for_code("unknown"),
        product_to_rough_factor = NA_real_,
        basis_source = "missing_quantity_columns",
        derived_flag = FALSE,
        basis_note = "Product basis could not be inferred from available quantity columns.",
        stringsAsFactors = FALSE
      ))
    }

    commodity_df <- df %>% filter(.data$commodity == commodity_name)
    product_values <- suppressWarnings(as.numeric(commodity_df[[quantity_cols$product_col]]))
    rough_values <- suppressWarnings(as.numeric(commodity_df[[quantity_cols$rough_col]]))
    valid_idx <- is.finite(product_values) & is.finite(rough_values) & abs(product_values) > 1e-9
    factors <- rough_values[valid_idx] / product_values[valid_idx]
    classification <- classify_product_basis_factors(factors)
    basis_note <- if (identical(classification$code, "unknown")) {
      paste0("Product basis inferred as unknown from ", quantity_cols$product_col, " and ", quantity_cols$rough_col, ".")
    } else if (identical(classification$code, "mixed")) {
      paste0("Product basis appears mixed or variable from ", quantity_cols$product_col, " and ", quantity_cols$rough_col, ".")
    } else {
      paste0("Product basis inferred from ", quantity_cols$product_col, " and ", quantity_cols$rough_col, ".")
    }

    data.frame(
      source_scope = scope,
      commodity = commodity_name,
      product_basis_code = classification$code,
      product_basis_label = product_basis_label_for_code(classification$code),
      product_to_rough_factor = classification$factor,
      basis_source = classification$basis_source,
      derived_flag = FALSE,
      basis_note = basis_note,
      stringsAsFactors = FALSE
    )
  })

  normalize_product_basis_registry(bind_rows(inferred_rows))
}

product_basis_summary_for_refs <- function(referenced_commodities, registry_df, coefficients = NULL, max_components = 6L) {
  refs <- unique(trimws(as.character(referenced_commodities)))
  refs <- refs[!is.na(refs) & nzchar(refs)]
  registry_df <- normalize_product_basis_registry(registry_df)

  if (length(refs) == 0) {
    components <- data.frame(
      commodity = character(),
      coefficient = numeric(),
      product_basis_code = character(),
      product_basis_label = character(),
      derived_flag = logical(),
      basis_note = character(),
      stringsAsFactors = FALSE
    )
    return(list(components = components, codes = character(), summary = "", mixed = FALSE))
  }

  coefficient_values <- rep(NA_real_, length(refs))
  if (!is.null(coefficients) && length(coefficients) > 0) {
    coefficient_values <- suppressWarnings(as.numeric(coefficients[refs]))
  }

  components <- lapply(seq_along(refs), function(idx) {
    ref_name <- refs[[idx]]
    registry_row <- registry_df %>% filter(.data$commodity == ref_name)
    if (nrow(registry_row) == 0) {
      registry_row <- data.frame(
        product_basis_code = "unknown",
        product_basis_label = product_basis_label_for_code("unknown"),
        derived_flag = FALSE,
        basis_note = "Product basis metadata was not found for this component.",
        stringsAsFactors = FALSE
      )
    }

    data.frame(
      commodity = ref_name,
      coefficient = coefficient_values[[idx]],
      product_basis_code = registry_row$product_basis_code[[1]],
      product_basis_label = registry_row$product_basis_label[[1]],
      derived_flag = isTRUE(registry_row$derived_flag[[1]]),
      basis_note = registry_row$basis_note[[1]],
      stringsAsFactors = FALSE
    )
  }) %>%
    bind_rows()

  codes <- unique(components$product_basis_code)
  mixed <- length(setdiff(codes, "unknown")) > 1 || any(codes %in% c("mixed", "unknown"), na.rm = TRUE)
  display_components <- head(components, max_components)
  summary_text <- paste(
    paste0(display_components$commodity, ": ", display_components$product_basis_label),
    collapse = "; "
  )
  if (nrow(components) > nrow(display_components)) {
    summary_text <- paste0(summary_text, "; and ", nrow(components) - nrow(display_components), " more")
  }

  list(
    components = components,
    codes = codes,
    summary = summary_text,
    mixed = mixed
  )
}

# Math trick natively substituted in code to keep dplyr C++ optimisation


na_preserving_sum <- function(value) {
  sum(value, na.rm = TRUE) * (NA_real_ ^ (sum(!is.na(value)) == 0))
}

analysis_month_to_calendar_month <- function(analysis_month) {
  ifelse(analysis_month <= 5L, analysis_month + 7L, analysis_month - 5L)
}

analysis_month_to_calendar_year <- function(market_year, analysis_month) {
  calendar_month <- analysis_month_to_calendar_month(analysis_month)
  ifelse(calendar_month >= 8L, market_year, market_year + 1L)
}

normalize_non_psd_year_type <- function(year_type, default = "marketing") {
  candidate <- trimws(as.character(year_type %||% default))
  candidate <- candidate[!is.na(candidate) & nzchar(candidate)]

  if (length(candidate) == 0) {
    return(default)
  }

  normalized <- tolower(candidate[[1]])
  if (normalized %in% c("marketing", "fiscal")) {
    normalized
  } else {
    default
  }
}

non_psd_year_type_choices <- function() {
  c(
    "Marketing Year (Aug-Jul)" = "marketing",
    "Fiscal Year (Oct-Sep)" = "fiscal"
  )
}

calendar_month_to_fiscal_period <- function(calendar_month) {
  calendar_month_num <- suppressWarnings(as.integer(calendar_month))

  ifelse(
    is.na(calendar_month_num),
    NA_integer_,
    ifelse(calendar_month_num >= 10L, calendar_month_num - 9L, calendar_month_num + 3L)
  )
}

calendar_month_to_fiscal_year_start <- function(calendar_year, calendar_month) {
  calendar_year_num <- suppressWarnings(as.integer(calendar_year))
  calendar_month_num <- suppressWarnings(as.integer(calendar_month))

  ifelse(
    is.na(calendar_year_num) | is.na(calendar_month_num),
    NA_integer_,
    ifelse(calendar_month_num >= 10L, calendar_year_num, calendar_year_num - 1L)
  )
}

month_mapping_for_year_type <- function(year_type = "marketing") {
  resolved_year_type <- normalize_non_psd_year_type(year_type, default = "marketing")

  if (!identical(resolved_year_type, "fiscal")) {
    return(month_mapping)
  }

  tibble::tribble(
    ~analysis_month, ~month_name, ~month_abbrev,
    1L, "October", "Oct",
    2L, "November", "Nov",
    3L, "December", "Dec",
    4L, "January", "Jan",
    5L, "February", "Feb",
    6L, "March", "Mar",
    7L, "April", "Apr",
    8L, "May", "May",
    9L, "June", "Jun",
    10L, "July", "Jul",
    11L, "August", "Aug",
    12L, "September", "Sep"
  )
}

na_preserving_cumsum <- function(value) {
  numeric_value <- suppressWarnings(as.numeric(value))

  if (length(numeric_value) == 0) {
    return(numeric_value)
  }

  if (all(is.na(numeric_value))) {
    return(rep(NA_real_, length(numeric_value)))
  }

  cumsum(dplyr::coalesce(numeric_value, 0))
}

resolve_non_psd_fiscal_cumulative_group_cols <- function(df, frequency = NULL, source_choice = NULL) {
  if (!is.data.frame(df) || nrow(df) == 0) {
    return(character(0))
  }

  resolved_frequency <- trimws(as.character(frequency %||% ""))
  resolved_frequency <- resolved_frequency[!is.na(resolved_frequency) & nzchar(resolved_frequency)]
  resolved_frequency <- if (length(resolved_frequency) > 0) resolved_frequency[[1]] else if ("week_ending_date" %in% names(df)) "weekly" else "monthly"

  resolved_source <- trimws(as.character(source_choice %||% ""))
  resolved_source <- resolved_source[!is.na(resolved_source) & nzchar(resolved_source)]
  resolved_source <- if (length(resolved_source) > 0) resolved_source[[1]] else ""

  weekly_hybrid_mode_values <- if ("weekly_hybrid_mode" %in% names(df)) {
    unique(as.character(df$weekly_hybrid_mode[!is.na(df$weekly_hybrid_mode)]))
  } else {
    character(0)
  }

  is_weekly_imputed_hybrid <- identical(resolved_source, "hybrid") &&
    identical(resolved_frequency, "weekly") &&
    "week_ending_date" %in% names(df) &&
    (
      "weekly_data_segment" %in% names(df) ||
        any(weekly_hybrid_mode_values == "weekly_imputed", na.rm = TRUE)
    )

  if (isTRUE(is_weekly_imputed_hybrid)) {
    hybrid_group_cols <- intersect(c("country", "commodity", "market_year"), names(df))
    if (length(hybrid_group_cols) > 0) {
      return(hybrid_group_cols)
    }
  }

  grouping_candidates <- c(
    "source", "frequency", "country", "countryDescription", "country_source_code",
    "country_legacy_code", "countryDescription_legacy", "canonical_review_row_id",
    "commodity", "commodity_group", "hybrid_source_tag", "hybrid_component_source",
    "weekly_data_segment", "market_year"
  )
  group_cols <- intersect(grouping_candidates, names(df))
  if (length(group_cols) == 0) {
    group_cols <- intersect(c("country", "commodity", "market_year"), names(df))
  }

  group_cols
}

build_fiscal_week_lookup_from_dates <- function(week_ending_date) {
  week_lookup <- tibble::tibble(
    week_ending_date = as.Date(week_ending_date)
  ) %>%
    filter(!is.na(.data$week_ending_date)) %>%
    distinct() %>%
    mutate(
      week_start_date = .data$week_ending_date - lubridate::days(6),
      calendar_year = suppressWarnings(as.integer(lubridate::year(.data$week_ending_date))),
      calendar_month = suppressWarnings(as.integer(lubridate::month(.data$week_ending_date))),
      fiscal_market_year = calendar_month_to_fiscal_year_start(.data$calendar_year, .data$calendar_month),
      start_calendar_year = suppressWarnings(as.integer(lubridate::year(.data$week_start_date))),
      start_calendar_month = suppressWarnings(as.integer(lubridate::month(.data$week_start_date))),
      same_calendar_month = .data$start_calendar_month == .data$calendar_month & .data$start_calendar_year == .data$calendar_year,
      current_month_overlap_days = dplyr::if_else(
        .data$same_calendar_month,
        7L,
        7L - as.integer(lubridate::ceiling_date(.data$week_start_date, unit = "month") - .data$week_start_date)
      ),
      current_month_share = .data$current_month_overlap_days / 7
    ) %>%
    arrange(.data$fiscal_market_year, .data$week_ending_date) %>%
    group_by(.data$fiscal_market_year) %>%
    mutate(
      fiscal_analysis_month = dplyr::row_number(),
      fiscal_analysis_month = pmin(.data$fiscal_analysis_month, 52L)
    ) %>%
    ungroup()

  week_lookup
}

apply_fiscal_boundary_week_adjustment <- function(df, fiscal_week_lookup) {
  if (!is.data.frame(df) || nrow(df) == 0 || !is.data.frame(fiscal_week_lookup) || nrow(fiscal_week_lookup) == 0) {
    return(df)
  }

  visible_week_counts <- df %>%
    distinct(market_year, analysis_month, week_ending_date) %>%
    count(.data$market_year, name = "visible_weeks")

  recent_year <- suppressWarnings(max(visible_week_counts$market_year, na.rm = TRUE))
  if (!is.finite(recent_year)) {
    return(df)
  }

  problem_years <- visible_week_counts %>%
    filter(.data$market_year < recent_year, .data$visible_weeks == 51L) %>%
    pull(.data$market_year)

  if (length(problem_years) == 0) {
    return(df)
  }

  boundary_weeks <- fiscal_week_lookup %>%
    filter(
      .data$fiscal_market_year %in% (problem_years + 1L),
      .data$fiscal_analysis_month == 1L,
      !.data$same_calendar_month,
      .data$calendar_month == 10L,
      .data$current_month_share > 0,
      .data$current_month_share < 1
    ) %>%
    transmute(
      next_fiscal_market_year = .data$fiscal_market_year,
      prior_fiscal_market_year = .data$fiscal_market_year - 1L,
      analysis_month = .data$fiscal_analysis_month,
      week_ending_date = .data$week_ending_date,
      retain_share = .data$current_month_share,
      carry_back_share = 1 - .data$current_month_share,
      synthetic_week_ending_date = as.Date(sprintf("%04d-09-30", .data$calendar_year)),
      synthetic_calendar_year = .data$calendar_year
    )

  valid_prior_years <- boundary_weeks %>%
    count(.data$prior_fiscal_market_year, name = "candidate_count") %>%
    filter(.data$candidate_count == 1L) %>%
    pull(.data$prior_fiscal_market_year)

  if (length(valid_prior_years) == 0) {
    return(df)
  }

  boundary_weeks <- boundary_weeks %>%
    filter(.data$prior_fiscal_market_year %in% valid_prior_years)

  split_value_cols <- intersect(
    c(
      "monthlyexports",
      "monthlyexports_rough_eq",
      "monthlyimports",
      "monthlyvalue",
      "monthlyvalue_rough_eq",
      "hybrid_quantity_cwt_rough_eq",
      "hybrid_pre_clamp_cwt_rough_eq",
      "final_adjusted_hybrid_cwt_rough_eq",
      "imputation_weight"
    ),
    names(df)
  )

  if (length(split_value_cols) == 0) {
    return(df)
  }

  rows_with_id <- df %>%
    mutate(
      week_ending_date = as.Date(.data$week_ending_date),
      .boundary_row_id = seq_len(n())
    )

  affected_rows <- rows_with_id %>%
    inner_join(
      boundary_weeks,
      by = c("market_year" = "next_fiscal_market_year", "analysis_month", "week_ending_date")
    )

  if (nrow(affected_rows) == 0) {
    return(df)
  }

  retained_rows <- affected_rows %>%
    mutate(
      splice_boundary_flag = TRUE,
      across(all_of(split_value_cols), ~ .x * .data$retain_share)
    )

  synthetic_rows <- affected_rows %>%
    mutate(
      market_year = .data$prior_fiscal_market_year,
      analysis_month = 52L,
      week_ending_date = .data$synthetic_week_ending_date,
      calendar_month = 9L,
      calendar_year = .data$synthetic_calendar_year,
      splice_boundary_flag = TRUE,
      across(all_of(split_value_cols), ~ .x * .data$carry_back_share)
    )

  if ("monthly_reconciliation_analysis_month" %in% names(synthetic_rows)) {
    synthetic_rows$monthly_reconciliation_analysis_month <- 12L
  }
  if ("monthly_reconciliation_months" %in% names(synthetic_rows)) {
    synthetic_rows$monthly_reconciliation_months <- "12"
  }
  if ("market_month" %in% names(synthetic_rows)) {
    synthetic_rows$market_month <- 12L
  }
  if ("market_month_name" %in% names(synthetic_rows)) {
    synthetic_rows$market_month_name <- "September"
  }

  bind_rows(
    rows_with_id %>% filter(!(.data$.boundary_row_id %in% affected_rows$.boundary_row_id)),
    retained_rows,
    synthetic_rows
  ) %>%
    select(all_of(names(df)))
}

apply_non_psd_year_type_view <- function(df, year_type = "marketing", frequency = NULL, source_choice = NULL) {
  if (!is.data.frame(df) || nrow(df) == 0) {
    return(df)
  }

  resolved_year_type <- normalize_non_psd_year_type(year_type, default = "marketing")
  if (!identical(resolved_year_type, "fiscal")) {
    return(df)
  }

  if (!is.null(source_choice) && identical(source_choice, "psd")) {
    return(df)
  }

  out <- df
  resolved_frequency <- trimws(as.character(frequency %||% ""))
  resolved_frequency <- resolved_frequency[!is.na(resolved_frequency) & nzchar(resolved_frequency)]
  resolved_frequency <- if (length(resolved_frequency) == 0) {
    if ("week_ending_date" %in% names(out)) "weekly" else "monthly"
  } else {
    resolved_frequency[[1]]
  }

  if (!(resolved_frequency %in% c("weekly", "monthly"))) {
    resolved_frequency <- if ("week_ending_date" %in% names(out)) "weekly" else "monthly"
  }

  if (identical(resolved_frequency, "weekly") && "week_ending_date" %in% names(out)) {
    week_dates <- as.Date(out$week_ending_date)
    valid_week_dates <- !is.na(week_dates) & is.finite(as.numeric(week_dates))

    if (any(valid_week_dates)) {
      week_lookup <- build_fiscal_week_lookup_from_dates(week_dates[valid_week_dates])

      out <- out %>%
        mutate(week_ending_date = as.Date(.data$week_ending_date)) %>%
        left_join(
          week_lookup %>%
            transmute(
              week_ending_date,
              fiscal_market_year = .data$fiscal_market_year,
              fiscal_analysis_month = .data$fiscal_analysis_month,
              fiscal_calendar_year = .data$calendar_year,
              fiscal_calendar_month = .data$calendar_month
            ),
          by = "week_ending_date"
        )

      out$market_year <- dplyr::coalesce(
        suppressWarnings(as.integer(out$fiscal_market_year)),
        suppressWarnings(as.integer(out$market_year))
      )
      out$analysis_month <- dplyr::coalesce(
        suppressWarnings(as.integer(out$fiscal_analysis_month)),
        suppressWarnings(as.integer(out$analysis_month))
      )

      if ("calendar_year" %in% names(out)) {
        out$calendar_year <- dplyr::coalesce(
          suppressWarnings(as.integer(out$calendar_year)),
          suppressWarnings(as.integer(out$fiscal_calendar_year))
        )
      } else {
        out$calendar_year <- suppressWarnings(as.integer(out$fiscal_calendar_year))
      }

      if ("calendar_month" %in% names(out)) {
        out$calendar_month <- dplyr::coalesce(
          suppressWarnings(as.integer(out$calendar_month)),
          suppressWarnings(as.integer(out$fiscal_calendar_month))
        )
      } else {
        out$calendar_month <- suppressWarnings(as.integer(out$fiscal_calendar_month))
      }

      out$fiscal_market_year <- NULL
      out$fiscal_analysis_month <- NULL
      out$fiscal_calendar_year <- NULL
      out$fiscal_calendar_month <- NULL

      out <- apply_fiscal_boundary_week_adjustment(out, week_lookup)
    }
  } else {
    current_market_year <- suppressWarnings(as.integer(out$market_year))
    current_analysis_month <- suppressWarnings(as.integer(out$analysis_month))

    fallback_calendar_month <- suppressWarnings(as.integer(analysis_month_to_calendar_month(current_analysis_month)))
    fallback_calendar_year <- suppressWarnings(as.integer(analysis_month_to_calendar_year(current_market_year, current_analysis_month)))

    existing_calendar_month <- if ("calendar_month" %in% names(out)) {
      suppressWarnings(as.integer(out$calendar_month))
    } else {
      rep(NA_integer_, nrow(out))
    }
    existing_calendar_year <- if ("calendar_year" %in% names(out)) {
      suppressWarnings(as.integer(out$calendar_year))
    } else {
      rep(NA_integer_, nrow(out))
    }

    out$calendar_month <- dplyr::coalesce(existing_calendar_month, fallback_calendar_month)
    out$calendar_year <- dplyr::coalesce(existing_calendar_year, fallback_calendar_year)

    out$market_year <- calendar_month_to_fiscal_year_start(out$calendar_year, out$calendar_month)
    out$analysis_month <- calendar_month_to_fiscal_period(out$calendar_month)
  }

  group_cols <- resolve_non_psd_fiscal_cumulative_group_cols(
    df = out,
    frequency = resolved_frequency,
    source_choice = source_choice
  )

  order_cols <- intersect(c("analysis_month", "week_ending_date", "calendar_month"), names(out))

  cumulative_metric_sources <- c(
    ytd_exports = "monthlyexports",
    ytd_exports_rough_eq = "monthlyexports_rough_eq",
    ytd_imports = "monthlyimports",
    ytd_value = "monthlyvalue",
    ytd_value_rough_eq = "monthlyvalue_rough_eq"
  )
  cumulative_targets <- names(cumulative_metric_sources)[
    names(cumulative_metric_sources) %in% names(out) &
      cumulative_metric_sources %in% names(out)
  ]

  if (length(cumulative_targets) > 0 && length(group_cols) > 0 && length(order_cols) > 0) {
    out <- out %>%
      arrange(across(all_of(unique(c(group_cols, order_cols))))) %>%
      group_by(across(all_of(group_cols)))

    for (target_col in cumulative_targets) {
      source_col <- cumulative_metric_sources[[target_col]]
      out <- out %>% mutate(!!target_col := na_preserving_cumsum(.data[[source_col]]))
    }

    out <- out %>% ungroup()
  }

  commitment_cols <- intersect(
    c(
      "total_commitment", "total_commitment_rough_eq",
      "outstandingSales", "outstandingSales_rough_eq",
      "grossNewSales", "grossNewSales_rough_eq",
      "currentMYNetSales", "currentMYNetSales_rough_eq",
      "nextMYOutstandingSales", "nextMYOutstandingSales_rough_eq",
      "nextMYNetSales", "nextMYNetSales_rough_eq"
    ),
    names(out)
  )
  if (length(commitment_cols) > 0) {
    for (col_name in commitment_cols) {
      out[[col_name]] <- rep(NA_real_, nrow(out))
    }
  }

  out
}

materialize_custom_monthly_rows <- function(weighted, group_cols, present_metrics, custom_name) {
  additive_metric_sources <- c(
    "monthlyexports",
    "monthlyexports_rough_eq",
    "monthlyvalue",
    "monthlyvalue_rough_eq"
  )
  cumulative_metric_sources <- c(
    "ytd_exports" = "monthlyexports",
    "ytd_exports_rough_eq" = "monthlyexports_rough_eq",
    "ytd_value" = "monthlyvalue",
    "ytd_value_rough_eq" = "monthlyvalue_rough_eq"
  )

  rebuilt_cumulative_metrics <- names(cumulative_metric_sources)[
    names(cumulative_metric_sources) %in% present_metrics & cumulative_metric_sources %in% present_metrics
  ]
  passthrough_metrics <- setdiff(present_metrics, rebuilt_cumulative_metrics)

  summarised <- weighted %>%
    group_by(across(all_of(group_cols))) %>%
    summarise(
      across(all_of(passthrough_metrics), na_preserving_sum),
      .groups = "drop"
    ) %>%
    mutate(
      commodity = custom_name,
      .existing_row = TRUE
    )

  if (!("analysis_month" %in% names(summarised))) {
    return(summarised %>% select(-.existing_row))
  }

  time_group_cols <- setdiff(group_cols, c("analysis_month", "market_month", "calendar_month", "calendar_year"))
  if (length(time_group_cols) == 0) {
    time_group_cols <- c("market_year", "country", "countryDescription", "commodity")
    time_group_cols <- intersect(time_group_cols, names(summarised))
  }

  completed <- summarised %>%
    group_by(across(all_of(time_group_cols))) %>%
    tidyr::complete(analysis_month = seq_len(max(analysis_month, na.rm = TRUE))) %>%
    ungroup() %>%
    mutate(
      commodity = dplyr::coalesce(.data$commodity, custom_name),
      .existing_row = !is.na(.data$.existing_row)
    )

  if ("market_month" %in% names(completed)) {
    completed <- completed %>%
      mutate(market_month = dplyr::coalesce(.data$market_month, .data$analysis_month))
  }
  if ("calendar_month" %in% names(completed)) {
    completed <- completed %>%
      mutate(
        calendar_month = dplyr::coalesce(
          .data$calendar_month,
          analysis_month_to_calendar_month(as.integer(.data$analysis_month))
        )
      )
  }
  if ("calendar_year" %in% names(completed)) {
    completed <- completed %>%
      mutate(
        calendar_year = dplyr::coalesce(
          .data$calendar_year,
          analysis_month_to_calendar_year(as.integer(.data$market_year), as.integer(.data$analysis_month))
        )
      )
  }

  additive_metrics <- intersect(additive_metric_sources, names(completed))
  if (length(additive_metrics) > 0) {
    completed <- completed %>%
      mutate(
        across(
          all_of(additive_metrics),
          ~ ifelse(!.data$.existing_row & is.na(.x), 0, .x)
        )
      )
  }

  if (length(rebuilt_cumulative_metrics) > 0) {
    completed <- completed %>%
      arrange(across(all_of(time_group_cols)), .data$analysis_month) %>%
      group_by(across(all_of(time_group_cols)))

    for (target_metric in rebuilt_cumulative_metrics) {
      source_metric <- cumulative_metric_sources[[target_metric]]
      completed <- completed %>%
        mutate(!!target_metric := cumsum(dplyr::coalesce(.data[[source_metric]], 0)))
    }

    completed <- completed %>%
      ungroup()
  }

  completed %>%
    select(-.existing_row)
}


materialize_custom_commodities <- function(base_df, custom_defs, metric_cols) {
  if (!is.data.frame(custom_defs) || nrow(custom_defs) == 0) return(base_df)

  materialize_base_df <- base_df
  if ("vp_is_rollup" %in% names(materialize_base_df)) {
    rollup_mask <- !is.na(materialize_base_df$vp_is_rollup) & as.logical(materialize_base_df$vp_is_rollup)
    materialize_base_df <- materialize_base_df[!rollup_mask, , drop = FALSE]
  }

  if (!is.data.frame(materialize_base_df) || nrow(materialize_base_df) == 0) {
    return(base_df)
  }

  common_key_candidates <- c("market_year", "analysis_month", "country", "countryDescription")
  monthly_key_candidates <- c("calendar_month", "calendar_year")
  present_metrics <- intersect(metric_cols, names(materialize_base_df))
  if (length(present_metrics) == 0) return(base_df)

  custom_rows <- list()
  for (i in seq_len(nrow(custom_defs))) {
    custom_name <- custom_defs$custom_name[[i]]
    parsed <- custom_defs$parsed[[i]]
    coeffs <- parsed$coefficients
    refs <- parsed$referenced_commodities

    slice_df <- materialize_base_df %>%
      filter(.data$commodity %in% refs) %>%
      mutate(.coef = coeffs[.data$commodity])

    if (nrow(slice_df) == 0) next

    has_weekly_date <-
      "week_ending_date" %in% names(slice_df) &&
      any(!is.na(slice_df$week_ending_date))
    group_cols <- intersect(common_key_candidates, names(slice_df))
    if (!has_weekly_date) {
      group_cols <- c(group_cols, intersect(monthly_key_candidates, names(slice_df)))
    }

    if (length(group_cols) == 0) next

    weighted <- slice_df %>%
      mutate(across(all_of(present_metrics), ~ suppressWarnings(as.numeric(.x)) * .data$.coef))

    if (has_weekly_date) {
      summarised <- weighted %>%
        group_by(across(all_of(group_cols))) %>%
        summarise(
          across(all_of(present_metrics), ~ (sum(.x, na.rm = TRUE) * (NA_real_ ^ (sum(!is.na(.x)) == 0)))),
          week_ending_date = safe_max_date(.data$week_ending_date),
          .groups = "drop"
        ) %>%
        mutate(commodity = custom_name)
    } else {
      summarised <- materialize_custom_monthly_rows(
        weighted = weighted,
        group_cols = group_cols,
        present_metrics = present_metrics,
        custom_name = custom_name
      )
    }

    custom_rows[[length(custom_rows) + 1L]] <- summarised
  }

  if (length(custom_rows) == 0) return(base_df)
  bind_rows(base_df, bind_rows(custom_rows))
}

# Helper function to get note for a specific country
get_note <- function(country_code, notes_df, source_family = "domestic") {
  normalized_notes <- normalize_notes_df(notes_df)
  canonical_country_code <- canonicalize_notes_country_codes(country_code)
  if (length(canonical_country_code) == 0 || !nzchar(canonical_country_code[[1]])) {
    return("")
  }
  canonical_country_code <- canonical_country_code[[1]]
  normalized_source_family <- normalize_notes_source_family(source_family)[1]
  row <- normalized_notes[
    normalized_notes$country == canonical_country_code &
      normalized_notes$source_family == normalized_source_family,
    ,
    drop = FALSE
  ]
  if (nrow(row) > 0) {
    return(row$note[1])
  }
  return("")
}

# Helper function to update or add a note
update_note <- function(country_code, note_text, notes_df, source_family = "domestic") {
  normalized_notes <- normalize_notes_df(notes_df)
  canonical_country_code <- canonicalize_notes_country_codes(country_code)
  if (length(canonical_country_code) == 0 || !nzchar(canonical_country_code[[1]])) {
    return(normalized_notes)
  }
  canonical_country_code <- canonical_country_code[[1]]
  normalized_source_family <- normalize_notes_source_family(source_family)[1]
  row_idx <- which(
    normalized_notes$country == canonical_country_code &
      normalized_notes$source_family == normalized_source_family
  )
  if (length(row_idx) > 0) {
    # Update existing note
    normalized_notes$note[row_idx[1]] <- note_text
    normalized_notes$last_updated[row_idx[1]] <- as.character(Sys.time())
  } else {
    # Add new note
    new_row <- data.frame(
      country = canonical_country_code,
      source_family = normalized_source_family,
      note = note_text,
      last_updated = as.character(Sys.time()),
      stringsAsFactors = FALSE
    )
    normalized_notes <- rbind(normalized_notes, new_row)
  }

  normalize_notes_df(normalized_notes)
}

startup_source_header_checks <- list()

record_startup_source_header_check <- function(source_family, file_label, mode, path) {
  entry_name <- paste(source_family, file_label, sep = ":")
  startup_source_header_checks[[entry_name]] <<- list(
    source_family = source_family,
    file_label = file_label,
    mode = mode,
    path = path
  )

  option_name <- contract_option_name(startup_commodity_contract, "startup_source_header_checks")
  options(stats::setNames(list(startup_source_header_checks), option_name))
  invisible(startup_source_header_checks[[entry_name]])
}

assert_startup_source_headers <- function(source_family, path, required_cols, file_label) {
  if (!startup_source_enabled(source_family)) {
    record_startup_source_header_check(
      source_family = source_family,
      file_label = file_label,
      mode = "contract_disabled",
      path = path
    )
    return(FALSE)
  }

  assert_required_columns(path, required_cols, file_label)
  record_startup_source_header_check(
    source_family = source_family,
    file_label = file_label,
    mode = "checked",
    path = path
  )
  TRUE
}

assert_startup_source_available <- function(source_family, path, file_label) {
  if (!startup_source_enabled(source_family)) {
    record_startup_source_header_check(
      source_family = source_family,
      file_label = file_label,
      mode = "contract_disabled",
      path = path
    )
    return(FALSE)
  }

  if (!file.exists(path)) {
    stop(sprintf("%s source artifact is missing: %s", file_label, path), call. = FALSE)
  }
  record_startup_source_header_check(
    source_family = source_family,
    file_label = file_label,
    mode = "available",
    path = path
  )
  TRUE
}

startup_stage_start_time <- Sys.time()
source_header_check_results <- c(
  assert_startup_source_headers("export_sales", weekly_path, required_weekly_source_cols, "weekly_data.csv"),
  assert_startup_source_headers("export_sales", monthly_path, required_monthly_source_cols, "export_sales_monthly.csv"),
  assert_startup_source_available("census_exports", census_exports_path, "census_exports_raw"),
  assert_startup_source_available("census_imports", census_imports_path, "census_imports_raw")
)
log_perf(
  "startup_init(assert_source_headers)",
  startup_stage_start_time,
  details = list(
    files = length(source_header_check_results),
    checked = sum(source_header_check_results),
    skipped = sum(!source_header_check_results)
  )
)

artifact_extra_signatures <- function(artifact_family) {
  signatures <- build_processed_artifact_extra_signatures(
    artifact_family = artifact_family,
    baseline_table_path = country_baseline_table_path,
    review_table_path = country_review_table_path
  )

  if (identical(artifact_family, "app_ui_metadata") && exists("vp_artifact_builder_version", inherits = TRUE)) {
    signatures <- signatures[!processed_artifact_signatures_unavailable(signatures)]
    signatures <- c(signatures, vp_trade_builder_version = vp_artifact_builder_version)
  }

  signatures
}

startup_data_load_modes <- list()

record_startup_data_load_mode <- function(dataset_name, mode, artifact_path, source_paths, rows, cols, currentity_current = NA, currentity_reason = NA_character_, currentity_detail = NA_character_, currentity_source_ids = character(), currentity_source_signatures = character(), currentity_extra_signature_names = character(), currentity_extra_signatures = character()) {
  startup_data_load_modes[[dataset_name]] <<- list(
    dataset_name = dataset_name,
    mode = mode,
    artifact_path = artifact_path,
    source_paths = source_paths,
    rows = rows,
    cols = cols,
    currentity_current = currentity_current,
    currentity_reason = currentity_reason,
    currentity_detail = currentity_detail,
    currentity_source_ids = currentity_source_ids,
    currentity_source_signatures = currentity_source_signatures,
    currentity_extra_signature_names = currentity_extra_signature_names,
    currentity_extra_signatures = currentity_extra_signatures
  )

  options(rice_startup_data_load_modes = startup_data_load_modes)
  invisible(startup_data_load_modes[[dataset_name]])
}

currentity_field <- function(processed_read, field_name) {
  if (is.null(processed_read$currentity) || is.null(processed_read$currentity[[field_name]])) {
    return(character())
  }
  unname(as.character(processed_read$currentity[[field_name]]))
}

startup_object_row_count <- function(object) {
  if (is.data.frame(object)) return(nrow(object))
  if (is.list(object) && is.data.frame(object$country_choices_all)) return(nrow(object$country_choices_all))
  if (is.list(object)) return(length(object))

  NA_integer_
}

startup_object_col_count <- function(object) {
  if (is.data.frame(object)) return(ncol(object))
  if (is.list(object) && is.data.frame(object$country_choices_all)) return(ncol(object$country_choices_all))
  if (is.list(object)) return(length(names(object)))

  NA_integer_
}

load_processed_or_csv_dataset <- function(dataset_name, tag, artifact_path, source_paths, fallback_loader, extra_signatures = character()) {
  start_time <- Sys.time()

  processed_read <- read_processed_artifact_with_status(
    artifact_path = artifact_path,
    project_dir = base_dir,
    source_paths = source_paths,
    extra_signatures = extra_signatures,
    perf_label = tag
  )
  processed_data <- processed_read$data

  if (!is.null(processed_data)) {
    processed_rows <- startup_object_row_count(processed_data)
    processed_cols <- startup_object_col_count(processed_data)
    record_startup_data_load_mode(
      dataset_name = dataset_name,
      mode = "processed_artifact",
      artifact_path = artifact_path,
      source_paths = source_paths,
      rows = processed_rows,
      cols = processed_cols,
      currentity_current = processed_read$current,
      currentity_reason = processed_read$reason,
      currentity_detail = processed_read$detail,
      currentity_source_ids = currentity_field(processed_read, "expected_source_ids"),
      currentity_source_signatures = currentity_field(processed_read, "expected_source_signatures"),
      currentity_extra_signature_names = currentity_field(processed_read, "expected_extra_signature_names"),
      currentity_extra_signatures = currentity_field(processed_read, "expected_extra_signatures")
    )

    log_perf(
      tag,
      start_time,
      details = list(
        mode = "processed_artifact",
        path = basename(artifact_path),
        source_count = length(source_paths),
        currentity_current = isTRUE(processed_read$current),
        currentity_reason = processed_read$reason,
        rows = processed_rows,
        cols = processed_cols
      )
    )
    return(processed_data)
  }

  dataset <- fallback_loader()
  dataset_rows <- startup_object_row_count(dataset)
  dataset_cols <- startup_object_col_count(dataset)
  record_startup_data_load_mode(
    dataset_name = dataset_name,
    mode = "csv_fallback",
    artifact_path = artifact_path,
    source_paths = source_paths,
    rows = dataset_rows,
    cols = dataset_cols,
    currentity_current = processed_read$current,
    currentity_reason = processed_read$reason,
    currentity_detail = processed_read$detail,
    currentity_source_ids = currentity_field(processed_read, "expected_source_ids"),
    currentity_source_signatures = currentity_field(processed_read, "expected_source_signatures"),
    currentity_extra_signature_names = currentity_field(processed_read, "expected_extra_signature_names"),
    currentity_extra_signatures = currentity_field(processed_read, "expected_extra_signatures")
  )

  log_perf(
    tag,
    start_time,
    details = list(
      mode = "csv_fallback",
      path = basename(artifact_path),
      source_count = length(source_paths),
      currentity_current = isTRUE(processed_read$current),
      currentity_reason = processed_read$reason,
      rows = dataset_rows,
      cols = dataset_cols
    )
  )
  dataset
}

load_startup_dataset_for_source <- function(source_family, dataset_name, tag, artifact_path, source_paths, fallback_loader, disabled_loader = NULL, extra_signatures = character(), dataset_enabled = TRUE, dataset_disabled_reason = NULL) {
  if (!startup_source_enabled(source_family)) {
    start_time <- Sys.time()
    dataset <- if (is.function(disabled_loader)) disabled_loader() else tibble::tibble()
    dataset_rows <- startup_object_row_count(dataset)
    dataset_cols <- startup_object_col_count(dataset)

    record_startup_data_load_mode(
      dataset_name = dataset_name,
      mode = "contract_disabled",
      artifact_path = artifact_path,
      source_paths = character(),
      rows = dataset_rows,
      cols = dataset_cols,
      currentity_current = NA,
      currentity_reason = paste0(source_family, "_contract_disabled")
    )

    log_perf(
      tag,
      start_time,
      details = list(
        mode = "contract_disabled",
        source_family = source_family,
        rows = dataset_rows,
        cols = dataset_cols
      )
    )
    return(dataset)
  }

  if (!isTRUE(dataset_enabled)) {
    start_time <- Sys.time()
    dataset <- if (is.function(disabled_loader)) disabled_loader() else tibble::tibble()
    dataset_rows <- startup_object_row_count(dataset)
    dataset_cols <- startup_object_col_count(dataset)
    disabled_reason <- dataset_disabled_reason
    if (is.null(disabled_reason) || length(disabled_reason) == 0L || !nzchar(as.character(disabled_reason[[1]]))) {
      disabled_reason <- paste0(dataset_name, "_feature_disabled")
    }

    record_startup_data_load_mode(
      dataset_name = dataset_name,
      mode = "feature_disabled",
      artifact_path = artifact_path,
      source_paths = character(),
      rows = dataset_rows,
      cols = dataset_cols,
      currentity_current = NA,
      currentity_reason = as.character(disabled_reason[[1]])
    )

    log_perf(
      tag,
      start_time,
      details = list(
        mode = "feature_disabled",
        source_family = source_family,
        rows = dataset_rows,
        cols = dataset_cols
      )
    )
    return(dataset)
  }

  load_processed_or_csv_dataset(
    dataset_name = dataset_name,
    tag = tag,
    artifact_path = artifact_path,
    source_paths = source_paths,
    fallback_loader = fallback_loader,
    extra_signatures = extra_signatures
  )
}

vp_perf_test_artifact_override_path <- function(dataset_name) {
  if (!identical(dataset_name, "vp_trade_monthly")) return(NA_character_)
  if (!isTRUE(runtime_perf_enabled())) return(NA_character_)
  if (!isTRUE(perf_truthy(Sys.getenv("VP_PERF_TEST_ARTIFACT_OVERRIDE_ENABLED", unset = ""), default = FALSE))) return(NA_character_)

  override_path <- trimws(Sys.getenv("VP_PERF_TEST_VP_TRADE_ARTIFACT", unset = ""))
  if (!nzchar(override_path)) return(NA_character_)

  normalizePath(override_path, winslash = "/", mustWork = FALSE)
}

load_vp_trade_monthly_for_startup <- function() {
  override_path <- vp_perf_test_artifact_override_path("vp_trade_monthly")
  if (is.na(override_path) || !nzchar(override_path)) {
    return(load_startup_dataset_for_source(
      source_family = "vp_trade",
      dataset_name = "vp_trade_monthly",
      tag = "startup_init(load_vp_trade_monthly_data)",
      artifact_path = vp_trade_monthly_prepped_path,
      source_paths = startup_source_paths("vp_trade", vp_trade_csv_path),
      extra_signatures = c(builder_version = vp_artifact_builder_version),
      fallback_loader = function() {
        as.data.frame(vp_build_trade_artifact(base_dir))
      },
      disabled_loader = empty_monthly_source_dataset
    ))
  }

  start_time <- Sys.time()
  if (!file.exists(override_path)) {
    stop(sprintf("VP performance test artifact override does not exist: %s", override_path), call. = FALSE)
  }

  candidate_data <- readRDS(override_path)
  candidate_rows <- startup_object_row_count(candidate_data)
  candidate_cols <- startup_object_col_count(candidate_data)
  record_startup_data_load_mode(
    dataset_name = "vp_trade_monthly",
    mode = "perf_test_artifact_override",
    artifact_path = override_path,
    source_paths = startup_source_paths("vp_trade", vp_trade_csv_path),
    rows = candidate_rows,
    cols = candidate_cols,
    currentity_current = NA,
    currentity_reason = "perf_test_artifact_override"
  )

  log_perf(
    "startup_init(load_vp_trade_monthly_data)",
    start_time,
    details = list(
      mode = "perf_test_artifact_override",
      path = basename(override_path),
      source_count = length(startup_source_paths("vp_trade", vp_trade_csv_path)),
      currentity_current = NA,
      currentity_reason = "perf_test_artifact_override",
      rows = candidate_rows,
      cols = candidate_cols
    )
  )
  runtime_perf_record(
    event = "vp_perf_test_artifact_override",
    details = list(
      dataset_name = "vp_trade_monthly",
      artifact_path = override_path,
      rows = candidate_rows,
      cols = candidate_cols,
      fallback_rebuild = FALSE
    )
  )
  candidate_data
}

add_empty_columns <- function(dataset, numeric_cols = character(), character_cols = character(), logical_cols = character()) {
  for (column_name in unique(character_cols)) {
    if (!column_name %in% names(dataset)) dataset[[column_name]] <- character()
  }
  for (column_name in unique(numeric_cols)) {
    if (!column_name %in% names(dataset)) dataset[[column_name]] <- numeric()
  }
  for (column_name in unique(logical_cols)) {
    if (!column_name %in% names(dataset)) dataset[[column_name]] <- logical()
  }

  dataset
}

empty_internal_metric_cols <- c(
  "monthlyexports", "monthlyexports_rough_eq",
  "ytd_exports", "ytd_exports_rough_eq",
  "monthlyimports", "monthlyimports_rough_eq",
  "ytd_imports", "ytd_imports_rough_eq",
  "total_commitment", "total_commitment_rough_eq",
  "outstandingSales", "outstandingSales_rough_eq",
  "grossNewSales", "grossNewSales_rough_eq",
  "currentMYNetSales", "currentMYNetSales_rough_eq",
  "nextMYOutstandingSales", "nextMYOutstandingSales_rough_eq",
  "nextMYNetSales", "nextMYNetSales_rough_eq"
)

empty_census_value_metric_cols <- c(
  "monthlyvalue", "monthlyvalue_rough_eq",
  "ytd_value", "ytd_value_rough_eq"
)

empty_weekly_export_sales_dataset <- function(include_all_na_group_flag = TRUE) {
  dataset <- tibble::tibble(
    week_ending_date = as.Date(character()),
    commodity = character(),
    country = character(),
    countryDescription = character()
  )

  hybrid_text_cols <- c(
    "hybrid_type", "hybrid_formula_id", "hybrid_formula_text",
    "source_systems_used", "raw_census_variables_used",
    "raw_export_sales_variables_used", "adjusted_variables_used",
    "adjustment_flags", "adjustment_notes"
  )
  hybrid_weekly_logical_cols <- c("is_imputed_weekly", "is_export_sales_extension", "splice_boundary_flag")
  hybrid_weekly_numeric_cols <- c("imputation_weight", "monthly_reconciliation_analysis_month", "monthly_reconciliation_months")

  dataset <- add_empty_columns(
    dataset,
    numeric_cols = c(required_weekly_source_cols, empty_internal_metric_cols, empty_census_value_metric_cols, setdiff(required_hybrid_provenance_cols, c("market_month_name", hybrid_text_cols, "hybrid_negative_clamp_flag")), hybrid_weekly_numeric_cols),
    character_cols = c("country_source_code", "countryDescription", "market_month_name", hybrid_text_cols, setdiff(required_hybrid_weekly_metadata_cols, c(hybrid_weekly_logical_cols, hybrid_weekly_numeric_cols))),
    logical_cols = c("hybrid_negative_clamp_flag", hybrid_weekly_logical_cols)
  )

  if (isTRUE(include_all_na_group_flag)) {
    dataset$all_na_group_flag <- logical()
  }

  dataset
}

empty_monthly_source_dataset <- function() {
  dataset <- tibble::tibble(
    commodity = character(),
    country = character(),
    countryDescription = character(),
    country_source_code = character(),
    market_year = integer(),
    calendar_year = integer(),
    calendar_month = integer(),
    month = integer(),
    market_month = integer(),
    analysis_month = integer(),
    market_month_name = character()
  )

  hybrid_text_cols <- c(
    "hybrid_type", "hybrid_formula_id", "hybrid_formula_text",
    "source_systems_used", "raw_census_variables_used",
    "raw_export_sales_variables_used", "adjusted_variables_used",
    "adjustment_flags", "adjustment_notes"
  )

  add_empty_columns(
    dataset,
    numeric_cols = c(required_monthly_source_cols, empty_internal_metric_cols, empty_census_value_metric_cols, setdiff(required_hybrid_provenance_cols, c("market_month_name", hybrid_text_cols, "hybrid_negative_clamp_flag")), required_hybrid_weekly_metadata_cols),
    character_cols = c("country_source_code", "countryDescription", "market_month_name", hybrid_text_cols, setdiff(required_hybrid_weekly_metadata_cols, c("is_imputed_weekly", "is_export_sales_extension", "splice_boundary_flag", "imputation_weight", "monthly_reconciliation_analysis_month", "monthly_reconciliation_months"))),
    logical_cols = c("hybrid_negative_clamp_flag", "is_imputed_weekly", "is_export_sales_extension", "splice_boundary_flag")
  )
}

empty_marketing_year_source_dataset <- function() {
  dataset <- tibble::tibble(
    commodity = character(),
    country = character(),
    countryDescription = character(),
    market_year = integer()
  )

  psd_cols <- if (exists("psd_metric_column_map", inherits = TRUE) && exists("psd_basis_pair_metric_cols", inherits = TRUE)) {
    psd_basis_cols <- if (identical(startup_psd_basis_profile(), "shelled_basis")) {
      character()
    } else {
      c("psd_milling_rate", paste0(psd_basis_pair_metric_cols, "_rough_eq"))
    }
    c("country_source_code", unname(psd_metric_column_map), psd_basis_cols)
  } else {
    character()
  }
  wasde_cols <- if (exists("wasde_required_processed_cols", inherits = TRUE)) wasde_required_processed_cols else character()

  add_empty_columns(
    dataset,
    numeric_cols = c(psd_cols, "analysis_month", "calendar_year", "calendar_month", "release_year", "release_month", "current_report_year", "current_report_month", "attribute_id", "unit_id", "value_raw", "value_canonical"),
    character_cols = c(wasde_cols, "country_source_code")
  )
}

empty_nass_annual_source_dataset <- function() {
  tibble::tibble(
    source = character(),
    frequency = character(),
    commodity = character(),
    commodity_group = character(),
    country = character(),
    countryDescription = character(),
    country_source_code = character(),
    geography_level = character(),
    state_alpha = character(),
    state_name = character(),
    state_fips_code = character(),
    market_year = integer(),
    calendar_year = integer(),
    annual_year_type = character(),
    reference_period_desc = character(),
    reference_period_type = character(),
    analysis_month = integer(),
    calendar_month = integer(),
    release_year = integer(),
    release_month = integer(),
    metric_id = character(),
    metric_source_id = character(),
    metric_label = character(),
    short_desc = character(),
    statisticcat_desc = character(),
    class_desc = character(),
    prodn_practice_desc = character(),
    util_practice_desc = character(),
    domain_desc = character(),
    domaincat_desc = character(),
    unit = character(),
    value_raw = numeric(),
    value_canonical = numeric(),
    nass_acres_bearing = numeric(),
    nass_yield = numeric(),
    nass_production_shelled_lb = numeric(),
    nass_price_received_per_lb = numeric(),
    nass_production_shelled_value = numeric()
  )
}

empty_nass_state_lookup_dataset <- function() {
  tibble::tibble(
    country = character(),
    countryDescription = character(),
    country_source_code = character(),
    geography_level = character(),
    state_alpha = character(),
    state_name = character(),
    state_fips_code = character(),
    is_national_aggregate = logical()
  )
}

empty_nass_shellout_factor_dataset <- function() {
  tibble::tibble(
    source = character(),
    factor_family = character(),
    commodity = character(),
    country = character(),
    countryDescription = character(),
    country_source_code = character(),
    factor_application_scope = character(),
    market_year = integer(),
    calendar_year = integer(),
    annual_year_type = character(),
    reference_period_desc = character(),
    reference_period_type = character(),
    analysis_month = integer(),
    calendar_month = integer(),
    formula_era = character(),
    shell_out_factor = numeric(),
    factor_status = character(),
    authoritative_geography_level = character(),
    authoritative_country = character(),
    authoritative_countryDescription = character(),
    numerator_short_desc = character(),
    numerator_value_raw = numeric(),
    numerator_unit = character(),
    denominator_short_desc = character(),
    denominator_value_raw = numeric(),
    denominator_unit = character(),
    denominator_value_lb = numeric(),
    unit_conversion_multiplier = numeric(),
    unit_scale_proof = character(),
    qa_outside_plausibility = logical(),
    qa_national_state_comparison_status = character(),
    qa_note = character()
  )
}

build_lazy_processed_artifact_cache_component <- function(dataset_name, artifact_path, source_paths, extra_signatures = character()) {
  status <- diagnose_processed_artifact_currentity(
    artifact_path = artifact_path,
    project_dir = base_dir,
    source_paths = source_paths,
    extra_signatures = extra_signatures
  )

  paste(
    dataset_name,
    basename(artifact_path),
    as.character(isTRUE(status$current)),
    status$reason %||% "unknown",
    cache_component_values(status$expected_source_ids),
    cache_component_values(status$expected_source_signatures),
    cache_component_values(status$expected_extra_signature_names),
    cache_component_values(status$expected_extra_signatures),
    build_file_signature(artifact_path),
    sep = "||"
  )
}

psd_historical_records_cache_env <- new.env(parent = emptyenv())
nass_historical_records_cache_env <- new.env(parent = emptyenv())

load_psd_historical_records <- function() {
  if (exists("data", envir = psd_historical_records_cache_env, inherits = FALSE)) {
    return(get("data", envir = psd_historical_records_cache_env, inherits = FALSE))
  }

  start_time <- Sys.time()
  processed_read <- read_processed_artifact_with_status(
    artifact_path = psd_historical_records_prepped_path,
    project_dir = base_dir,
    source_paths = c(psd_raw_path, psd_metadata_path),
    extra_signatures = artifact_extra_signatures("psd_historical_records"),
    perf_label = "psd_historical_records_lazy_load"
  )

  records <- processed_read$data
  if (is.null(records) || !is.data.frame(records)) {
    records <- tibble::tibble()
  }

  assign("data", records, envir = psd_historical_records_cache_env)
  log_perf(
    "psd_historical_records_lazy_load",
    start_time,
    details = list(
      rows = nrow(records),
      cols = ncol(records),
      currentity_current = isTRUE(processed_read$current),
      currentity_reason = processed_read$reason %||% "unknown"
    )
  )

  records
}

load_nass_historical_records <- function() {
  if (exists("data", envir = nass_historical_records_cache_env, inherits = FALSE)) {
    return(get("data", envir = nass_historical_records_cache_env, inherits = FALSE))
  }

  start_time <- Sys.time()
  processed_read <- read_processed_artifact_with_status(
    artifact_path = nass_historical_records_prepped_path,
    project_dir = base_dir,
    source_paths = startup_source_paths("nass", nass_raw_path),
    extra_signatures = artifact_extra_signatures("nass_historical_records"),
    perf_label = "nass_historical_records_lazy_load"
  )

  records <- processed_read$data
  if (is.null(records) || !is.data.frame(records)) {
    records <- tibble::tibble()
  }

  assign("data", records, envir = nass_historical_records_cache_env)
  log_perf(
    "nass_historical_records_lazy_load",
    start_time,
    details = list(
      rows = nrow(records),
      cols = ncol(records),
      currentity_current = isTRUE(processed_read$current),
      currentity_reason = processed_read$reason %||% "unknown"
    )
  )

  records
}

psd_revision_delta_source_paths <- function() {
  manual_prior_metadata <- psd_revision_delta_manual_prior_metadata()
  if (!is.null(manual_prior_metadata)) {
    return(c(psd_marketing_year_prepped_path, manual_prior_metadata$csv_path))
  }

  source_paths <- c(psd_marketing_year_prepped_path)
  prior_entry <- tryCatch(
    select_psd_release_archive_entry(base_dir, artifact_role = "psd_rice_my_pre", max_release_key = Inf),
    error = function(...) NULL
  )
  prior_path <- if (!is.null(prior_entry)) prior_entry$archived_artifact_path else NA_character_
  if (!is.na(prior_path) && file.exists(prior_path)) {
    source_paths <- c(source_paths, prior_path)
  }
  source_paths
}

psd_revision_delta_manual_prior_metadata <- function() {
  entry <- tryCatch(
    read_processed_artifact_manifest_entry(base_dir, psd_revision_delta_prepped_path),
    error = function(...) NULL
  )
  metadata <- entry$artifact_metadata$manual_prior
  if (!is.list(metadata)) return(NULL)
  if (!identical(as.character(metadata$source_type), "manual_prior_psd_online_csv")) return(NULL)
  if (!isTRUE(metadata$manual_prior_mode)) return(NULL)
  if (is.null(metadata$csv_path) || !nzchar(as.character(metadata$csv_path))) return(NULL)
  metadata
}

psd_revision_delta_extra_signatures <- function() {
  manual_prior_metadata <- psd_revision_delta_manual_prior_metadata()
  if (!is.null(manual_prior_metadata)) {
    return(c(
      artifact_extra_signatures("psd_revision_delta"),
      manual_prior_mode = "TRUE",
      manual_prior_source_type = as.character(manual_prior_metadata$source_type),
      manual_prior_schema_version = as.character(manual_prior_metadata$schema_version),
      manual_prior_release_period = as.character(manual_prior_metadata$prior_release_period),
      manual_prior_world_status = as.character(manual_prior_metadata$world_status)
    ))
  }

  c(
    artifact_extra_signatures("psd_revision_delta"),
    psd_release_archive_manifest = build_file_signature(psd_release_archive_manifest_path)
  )
}

psd_revision_delta_cache_env <- new.env(parent = emptyenv())

load_psd_revision_delta <- function() {
  if (exists("data", envir = psd_revision_delta_cache_env, inherits = FALSE)) {
    return(get("data", envir = psd_revision_delta_cache_env, inherits = FALSE))
  }

  start_time <- Sys.time()
  processed_read <- read_processed_artifact_with_status(
    artifact_path = psd_revision_delta_prepped_path,
    project_dir = base_dir,
    source_paths = psd_revision_delta_source_paths(),
    extra_signatures = psd_revision_delta_extra_signatures(),
    perf_label = "psd_revision_delta_lazy_load"
  )

  records <- processed_read$data
  if (is.null(records) || !is.data.frame(records)) {
    records <- tibble::tibble()
  }

  assign("data", records, envir = psd_revision_delta_cache_env)
  log_perf(
    "psd_revision_delta_lazy_load",
    start_time,
    details = list(
      rows = nrow(records),
      cols = ncol(records),
      currentity_current = isTRUE(processed_read$current),
      currentity_reason = processed_read$reason %||% "unknown"
    )
  )

  records
}

wasde_historical_records_cache_env <- new.env(parent = emptyenv())

load_wasde_historical_records <- function() {
  if (exists("data", envir = wasde_historical_records_cache_env, inherits = FALSE)) {
    return(get("data", envir = wasde_historical_records_cache_env, inherits = FALSE))
  }

  start_time <- Sys.time()
  processed_read <- read_processed_artifact_with_status(
    artifact_path = wasde_historical_records_prepped_path,
    project_dir = base_dir,
    source_paths = c(wasde_raw_path),
    extra_signatures = artifact_extra_signatures("wasde_historical_records"),
    perf_label = "wasde_historical_records_lazy_load"
  )

  records <- processed_read$data
  if (is.null(records) || !is.data.frame(records)) {
    records <- tibble::tibble()
  }

  assign("data", records, envir = wasde_historical_records_cache_env)
  log_perf(
    "wasde_historical_records_lazy_load",
    start_time,
    details = list(
      rows = nrow(records),
      cols = ncol(records),
      currentity_current = isTRUE(processed_read$current),
      currentity_reason = processed_read$reason %||% "unknown"
    )
  )

  records
}

wasde_release_history_cache_env <- new.env(parent = emptyenv())

load_wasde_release_history <- function() {
  if (exists("data", envir = wasde_release_history_cache_env, inherits = FALSE)) {
    return(get("data", envir = wasde_release_history_cache_env, inherits = FALSE))
  }

  start_time <- Sys.time()
  processed_read <- read_processed_artifact_with_status(
    artifact_path = wasde_release_history_prepped_path,
    project_dir = base_dir,
    source_paths = c(wasde_waob_release_history_raw_path),
    extra_signatures = artifact_extra_signatures("wasde_release_history"),
    perf_label = "wasde_release_history_lazy_load"
  )

  records <- processed_read$data
  if (is.null(records) || !is.data.frame(records)) {
    records <- tibble::tibble()
  }

  assign("data", records, envir = wasde_release_history_cache_env)
  log_perf(
    "wasde_release_history_lazy_load",
    start_time,
    details = list(
      rows = nrow(records),
      cols = ncol(records),
      currentity_current = isTRUE(processed_read$current),
      currentity_reason = processed_read$reason %||% "unknown"
    )
  )

  records
}

wasde_revision_delta_cache_env <- new.env(parent = emptyenv())

load_wasde_revision_delta <- function() {
  if (exists("data", envir = wasde_revision_delta_cache_env, inherits = FALSE)) {
    return(get("data", envir = wasde_revision_delta_cache_env, inherits = FALSE))
  }

  start_time <- Sys.time()
  processed_read <- read_processed_artifact_with_status(
    artifact_path = wasde_revision_delta_prepped_path,
    project_dir = base_dir,
    source_paths = c(wasde_raw_path, wasde_waob_release_history_raw_path),
    extra_signatures = artifact_extra_signatures("wasde_revision_delta"),
    perf_label = "wasde_revision_delta_lazy_load"
  )

  records <- processed_read$data
  if (is.null(records) || !is.data.frame(records)) {
    records <- tibble::tibble()
  }

  assign("data", records, envir = wasde_revision_delta_cache_env)
  log_perf(
    "wasde_revision_delta_lazy_load",
    start_time,
    details = list(
      rows = nrow(records),
      cols = ncol(records),
      currentity_current = isTRUE(processed_read$current),
      currentity_reason = processed_read$reason %||% "unknown"
    )
  )

  records
}

rice_data_weekly_prepped <- load_startup_dataset_for_source(
  source_family = "export_sales",
  dataset_name = "weekly_export_sales",
  tag = "startup_init(weekly_prep)",
  artifact_path = weekly_prepped_path,
  source_paths = startup_source_paths("export_sales", c(weekly_path)),
  extra_signatures = artifact_extra_signatures("export_sales_weekly"),
  fallback_loader = function() {
    prepare_export_sales_weekly_data(
      weekly_path = weekly_path,
      country_canonical_map = country_canonical_map
    )
  },
  disabled_loader = function() {
    empty_weekly_export_sales_dataset(include_all_na_group_flag = TRUE)
  }
)

weekly_all_na_group_count <- (sum(rice_data_weekly_prepped$all_na_group_flag, na.rm = TRUE) * (NA_real_ ^ (sum(!is.na(rice_data_weekly_prepped$all_na_group_flag)) == 0)))
weekly_all_na_warning_message <- if (!is.na(weekly_all_na_group_count) && weekly_all_na_group_count > 0) {
  paste0(
    "Detected ",
    format(weekly_all_na_group_count, big.mark = ","),
    " weekly grouped records with all-NA source values. Affected values were set to missing and some projections/comparisons may be unavailable for those selections."
  )
} else {
  ""
}

rice_data_weekly <- rice_data_weekly_prepped %>%
  select(-all_na_group_flag)

rice_data_weekly_fiscal_prepped <- load_startup_dataset_for_source(
  source_family = "export_sales",
  dataset_name = "weekly_export_sales_fiscal",
  tag = "startup_init(weekly_fiscal_prep)",
  artifact_path = weekly_fiscal_prepped_path,
  source_paths = startup_source_paths("export_sales", c(weekly_path)),
  fallback_loader = function() {
    materialize_export_sales_weekly_fiscal_data(rice_data_weekly_prepped)
  },
  extra_signatures = artifact_extra_signatures("export_sales_weekly_fiscal"),
  disabled_loader = function() {
    empty_weekly_export_sales_dataset(include_all_na_group_flag = FALSE)
  }
)

rice_data_weekly_fiscal <- rice_data_weekly_fiscal_prepped %>%
  select(-any_of("all_na_group_flag"))

startup_stage_start_time <- Sys.time()
last_complete_period_info <- compute_last_complete_month_from_weekly(
  week_dates = rice_data_weekly_prepped$week_ending_date
)
most_recent_report_date <- last_complete_period_info$most_recent_report_date
last_complete_calendar_month <- last_complete_period_info$last_complete_calendar_month
last_complete_calendar_year <- last_complete_period_info$last_complete_calendar_year
log_perf(
  "startup_init(compute_last_complete_month_from_weekly)",
  startup_stage_start_time,
  details = list(most_recent_report_date = most_recent_report_date)
)

startup_stage_start_time <- Sys.time()
rice_data_monthly <- load_startup_dataset_for_source(
  source_family = "export_sales",
  dataset_name = "monthly_export_sales",
  tag = "startup_init(load_export_sales_monthly_data)",
  artifact_path = monthly_prepped_path,
  source_paths = startup_source_paths("export_sales", c(monthly_path, weekly_path)),
  extra_signatures = artifact_extra_signatures("export_sales_monthly"),
  fallback_loader = function() {
    load_export_sales_monthly_data(
      monthly_path = monthly_path,
      country_canonical_map = country_canonical_map,
      last_complete_calendar_year = last_complete_calendar_year,
      last_complete_calendar_month = last_complete_calendar_month
    )
  },
  disabled_loader = empty_monthly_source_dataset
)
rice_data_monthly_fiscal <- load_startup_dataset_for_source(
  source_family = "export_sales",
  dataset_name = "monthly_export_sales_fiscal",
  tag = "startup_init(load_export_sales_monthly_fiscal_data)",
  artifact_path = monthly_fiscal_prepped_path,
  source_paths = startup_source_paths("export_sales", c(monthly_path, weekly_path)),
  extra_signatures = artifact_extra_signatures("export_sales_monthly_fiscal"),
  fallback_loader = function() {
    materialize_non_psd_monthly_fiscal_data(
      rice_data_monthly,
      source_choice = "export_sales"
    )
  },
  disabled_loader = empty_monthly_source_dataset
)

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

validate_vp_trade_rollup_contract <- function(vp_data) {
  required_cols <- unique(c(vp_rollup_required_fields(), c("Group", "Subgroup", "MarketSegment", "commodity", "Trade", "unit_value", "unit_value_unit", "ytd_unit_value", "ytd_unit_value_unit")))
  missing_cols <- setdiff(required_cols, names(vp_data))
  if (length(missing_cols) > 0) {
    stop(
      paste0(
        "FTN trade artifact is missing required rollup fields: ",
        paste(missing_cols, collapse = ", "),
        ". Rebuild with Master_FTN.R."
      ),
      call. = FALSE
    )
  }

  schema_values <- unique(trimws(as.character(vp_data$vp_rollup_schema_version %||% character(0))))
  schema_values <- schema_values[!is.na(schema_values) & nzchar(schema_values)]
  if (!(vp_rollup_schema_version %in% schema_values)) {
    stop(
      paste0(
        "FTN trade artifact rollup schema mismatch. Expected ",
        vp_rollup_schema_version,
        ". Rebuild with Master_FTN.R."
      ),
      call. = FALSE
    )
  }

  has_rollup_rows <- any(!is.na(vp_data$vp_is_rollup) & as.logical(vp_data$vp_is_rollup), na.rm = TRUE)
  has_required_levels <- all(c("segment_all", "subgroup_all", "group_all") %in% unique(trimws(as.character(vp_data$vp_rollup_level))))
  if (!isTRUE(has_rollup_rows) || !isTRUE(has_required_levels)) {
    stop(
      "FTN trade artifact rollup levels are incomplete. Rebuild with Master_FTN.R.",
      call. = FALSE
    )
  }

  manifest_entry <- tryCatch(
    read_processed_artifact_manifest_entry(base_dir, vp_trade_monthly_prepped_path),
    error = function(...) NULL
  )
  builder_version <- resolve_vp_manifest_builder_version(manifest_entry)
  builder_rank <- vp_builder_version_rank(builder_version)
  floor_rank <- vp_builder_version_rank(vp_artifact_builder_floor)

  if (!is.finite(floor_rank)) {
    stop("VP startup builder floor configuration is invalid. Update vp_data_utils.R.", call. = FALSE)
  }

  if (!is.finite(builder_rank) || builder_rank < floor_rank) {
    stop(
      paste0(
        "FTN trade artifact builder version is missing or below floor (artifact=",
        if (!is.na(builder_version) && nzchar(builder_version)) builder_version else "<missing>",
        ", floor=",
        vp_artifact_builder_floor,
        "). Rebuild with Master_FTN.R."
      ),
      call. = FALSE
    )
  }

  invisible(TRUE)
}

rice_data_vp_trade_monthly <- load_vp_trade_monthly_for_startup()

validate_vp_trade_rollup_contract(rice_data_vp_trade_monthly)

vp_partition_truthy <- function(value, default = FALSE) {
  if (is.null(value) || length(value) == 0L || all(is.na(value))) return(default)
  normalized <- tolower(trimws(as.character(value[[1L]])))
  if (!nzchar(normalized)) return(default)
  normalized %in% c("1", "true", "yes", "y", "on")
}

vp_lazy_startup_strict_mode_enabled <- function() {
  option_value <- getOption("vp_lazy_startup_strict_mode_enabled", NULL)
  if (!is.null(option_value)) return(isTRUE(option_value))

  env_value <- Sys.getenv("VP_LAZY_STARTUP_STRICT_MODE_ENABLED", unset = "")
  if (!nzchar(env_value)) return(FALSE)
  vp_partition_truthy(env_value, default = FALSE)
}

vp_lazy_startup_allow_full_artifact_fallback <- function() {
  option_value <- getOption("vp_lazy_startup_allow_full_artifact_fallback", NULL)
  if (!is.null(option_value)) return(isTRUE(option_value))

  env_value <- Sys.getenv("VP_LAZY_STARTUP_ALLOW_FULL_ARTIFACT_FALLBACK", unset = "")
  if (!nzchar(env_value)) return(TRUE)
  vp_partition_truthy(env_value, default = TRUE)
}

vp_enforce_lazy_startup_dependency_guard <- function(vp_data) {
  if (!isTRUE(vp_lazy_sidecar_mode_enabled())) {
    return(invisible(TRUE))
  }

  if (!isTRUE(vp_lazy_startup_strict_mode_enabled())) {
    return(invisible(TRUE))
  }

  if (isTRUE(vp_lazy_startup_allow_full_artifact_fallback())) {
    return(invisible(TRUE))
  }

  vp_rows <- startup_object_row_count(vp_data)
  stop(
    paste0(
      "VP lazy startup strict mode is enabled and full-artifact fallback is disabled, ",
      "but startup attempted to load full VP rows (rows=", vp_rows, "). ",
      "Use diagnostic fallback only or implement lazy-sidecar startup retrieval first."
    ),
    call. = FALSE
  )
}

vp_trade_rows_raw <- function() {
  if (exists("rice_data_vp_trade_monthly", inherits = TRUE) && is.data.frame(rice_data_vp_trade_monthly)) {
    return(rice_data_vp_trade_monthly)
  }

  NULL
}

vp_trade_rows_available <- function(require_non_empty = TRUE) {
  vp_rows <- vp_trade_rows_raw()
  if (is.null(vp_rows)) {
    return(FALSE)
  }

  if (!isTRUE(require_non_empty)) {
    return(TRUE)
  }

  nrow(vp_rows) > 0L
}

vp_trade_rows_or_empty <- function(require_non_empty = FALSE) {
  vp_rows <- vp_trade_rows_raw()
  if (is.null(vp_rows)) {
    return(data.frame())
  }

  if (isTRUE(require_non_empty) && nrow(vp_rows) == 0L) {
    return(data.frame())
  }

  vp_rows
}

vp_lazy_sidecar_mode_enabled <- function() {
  option_value <- getOption("vp_lazy_sidecar_mode_enabled", NULL)
  if (!is.null(option_value)) return(isTRUE(option_value))

  env_value <- Sys.getenv("VP_LAZY_SIDECAR_MODE_ENABLED", unset = "")
  if (!nzchar(env_value)) return(FALSE)
  vp_partition_truthy(env_value, default = FALSE)
}

vp_enforce_lazy_startup_dependency_guard(rice_data_vp_trade_monthly)

vp_trade_rows_for_context <- function(require_non_empty = TRUE,
                                      allow_full_artifact_fallback = TRUE) {
  # Compatibility facade: keep full-artifact behavior unless lazy sidecar mode is explicitly enabled.
  if (!isTRUE(vp_lazy_sidecar_mode_enabled())) {
    return(vp_trade_rows_or_empty(require_non_empty = require_non_empty))
  }

  # Placeholder for lazy-sidecar retrieval path. Until that path is implemented,
  # return the canonical startup dataset and optionally allow fallback behavior.
  vp_rows <- vp_trade_rows_or_empty(require_non_empty = require_non_empty)
  if (!isTRUE(allow_full_artifact_fallback) && nrow(vp_rows) == 0L) {
    return(data.frame())
  }

  vp_rows
}

vp_partition_provider_enabled <- function() {
  option_value <- getOption("vp_partition_provider_enabled", NULL)
  if (!is.null(option_value)) return(isTRUE(option_value))

  env_value <- Sys.getenv("VP_PARTITION_PROVIDER_ENABLED", unset = "")
  if (!nzchar(env_value)) return(TRUE)
  vp_partition_truthy(env_value, default = TRUE)
}

vp_partition_provider_version <- "vp_trade_partition_provider_v3"
vp_partition_manifest_schema_version <- "vp_trade_partition_manifest_v3"
vp_partition_payload_schema_version <- "vp_trade_partition_payload_v1"
vp_partition_metadata_schema_version <- "vp_trade_partition_metadata_v1"
vp_partition_cache_env <- new.env(parent = emptyenv())
vp_partition_manifest_cache_env <- new.env(parent = emptyenv())

vp_partition_slug <- function(value, max_chars = 24L) {
  cleaned <- tolower(trimws(as.character(value %||% "na")))
  cleaned <- gsub("[^a-z0-9]+", "_", cleaned)
  cleaned <- gsub("^_+|_+$", "", cleaned)
  if (!nzchar(cleaned)) cleaned <- "na"
  substr(cleaned, 1L, max_chars)
}

vp_partition_hash <- function(values) {
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

vp_partition_provider_dir <- function() {
  file.path(
    base_dir,
    "System",
    "Processed Data",
    "vp_trade_partitions",
    vp_partition_provider_version,
    vp_artifact_builder_version
  )
}

vp_partition_manifest_path <- function() {
  file.path(vp_partition_provider_dir(), "vp_trade_partition_manifest.rds")
}

vp_partition_source_signature_cache_env <- new.env(parent = emptyenv())

vp_partition_source_signature <- function() {
  artifact_path <- normalizePath(vp_trade_monthly_prepped_path, winslash = "/", mustWork = FALSE)
  file_info <- if (file.exists(artifact_path)) file.info(artifact_path) else NULL
  cache_key <- paste(
    artifact_path,
    if (!is.null(file_info)) as.character(file_info$size[[1L]]) else "missing",
    if (!is.null(file_info)) as.character(file_info$mtime[[1L]]) else "missing",
    sep = "|"
  )
  cached <- vp_partition_source_signature_cache_env$signature
  if (is.list(cached) && identical(cached$key %||% NULL, cache_key)) {
    return(cached$value %||% "signature_unavailable")
  }

  signature <- tryCatch(
    build_file_signature(vp_trade_monthly_prepped_path),
    error = function(...) "signature_unavailable"
  )
  vp_partition_source_signature_cache_env$signature <- list(key = cache_key, value = signature)
  signature
}

vp_partition_source_identity <- function(vp_rows) {
  list(
    source_signature = vp_partition_source_signature(),
    source_row_count = if (is.data.frame(vp_rows)) nrow(vp_rows) else NA_integer_,
    source_col_count = if (is.data.frame(vp_rows)) ncol(vp_rows) else NA_integer_,
    source_column_hash = if (is.data.frame(vp_rows)) vp_partition_hash(names(vp_rows)) else "not_data_frame",
    source_row_order_fingerprint = vp_partition_source_fingerprint(vp_rows)
  )
}

vp_partition_canonical_source_identity <- function() {
  attr(rice_data_vp_trade_monthly, "vp_partition_source_identity", exact = TRUE)
}

vp_partition_canonical_source_token_value <- function() {
  attr(rice_data_vp_trade_monthly, "vp_partition_canonical_source_token", exact = TRUE)
}

vp_partition_source_fingerprint <- function(vp_rows) {
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

  vp_partition_hash(c(nrow(vp_rows), ncol(vp_rows), names(vp_rows), sampled_values))
}

vp_partition_canonical_source_token <- function() {
  paste(
    "vp_trade_monthly",
    vp_artifact_builder_version,
    basename(vp_trade_monthly_prepped_path),
    vp_partition_source_signature(),
    sep = "|"
  )
}

vp_partition_mark_canonical_source <- function(vp_rows) {
  if (!is.data.frame(vp_rows)) return(vp_rows)
  attr(vp_rows, "vp_partition_canonical_source_token") <- vp_partition_canonical_source_token()
  attr(vp_rows, "vp_partition_source_identity") <- vp_partition_source_identity(vp_rows)
  vp_rows
}

vp_partition_source_is_eligible <- function(vp_rows) {
  if (!is.data.frame(vp_rows)) return(list(ok = FALSE, reason = "source_not_data_frame", identity = vp_partition_source_identity(vp_rows)))
  stored_identity <- attr(vp_rows, "vp_partition_source_identity", exact = TRUE)
  stored_token <- attr(vp_rows, "vp_partition_canonical_source_token", exact = TRUE)
  canonical_identity <- vp_partition_canonical_source_identity()
  canonical_token <- vp_partition_canonical_source_token_value()

  if (is.list(stored_identity) && is.list(canonical_identity) && identical(stored_token %||% NA_character_, canonical_token %||% NA_character_) && identical(stored_identity, canonical_identity)) {
    return(list(ok = TRUE, reason = "source_eligible", identity = stored_identity))
  }

  source_identity <- vp_partition_source_identity(vp_rows)

  if (!identical(stored_token %||% NA_character_, canonical_token %||% NA_character_)) {
    return(list(ok = FALSE, reason = "source_token_mismatch", identity = source_identity))
  }
  if (!is.list(stored_identity)) {
    return(list(ok = FALSE, reason = "source_identity_missing", identity = source_identity))
  }
  for (field_name in names(source_identity)) {
    if (!identical(stored_identity[[field_name]] %||% NULL, source_identity[[field_name]])) {
      return(list(ok = FALSE, reason = paste0("source_", field_name, "_mismatch"), identity = source_identity))
    }
  }

  list(ok = TRUE, reason = "source_eligible", identity = source_identity)
}

rice_data_vp_trade_monthly <- vp_partition_mark_canonical_source(rice_data_vp_trade_monthly)

vp_partition_manifest_base <- function() {
  list(
    schema_version = vp_partition_manifest_schema_version,
    provider_version = vp_partition_provider_version,
    builder_version = vp_artifact_builder_version,
    source_artifact = basename(vp_trade_monthly_prepped_path),
    source_signature = vp_partition_source_signature(),
    created_at = as.character(Sys.time()),
    updated_at = as.character(Sys.time()),
    entries = list()
  )
}

vp_partition_manifest_compatible <- function(manifest) {
  is.list(manifest) &&
    identical(manifest$schema_version %||% NA_character_, vp_partition_manifest_schema_version) &&
    identical(manifest$provider_version %||% NA_character_, vp_partition_provider_version) &&
    identical(manifest$builder_version %||% NA_character_, vp_artifact_builder_version) &&
    identical(manifest$source_artifact %||% NA_character_, basename(vp_trade_monthly_prepped_path)) &&
    identical(manifest$source_signature %||% NA_character_, vp_partition_source_signature()) &&
    is.list(manifest$entries)
}

vp_partition_manifest_cache_clear <- function() {
  rm(list = ls(envir = vp_partition_manifest_cache_env, all.names = TRUE), envir = vp_partition_manifest_cache_env)
  invisible(TRUE)
}

vp_partition_atomic_save_rds <- function(object, path, compress = TRUE) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  temp_path <- tempfile(pattern = paste0(basename(path), "__"), tmpdir = dirname(path), fileext = ".tmp")
  save_ok <- tryCatch(
    {
      saveRDS(object, temp_path, compress = compress)
      TRUE
    },
    error = function(...) FALSE
  )
  if (!isTRUE(save_ok)) {
    if (file.exists(temp_path)) unlink(temp_path, force = TRUE)
    return(FALSE)
  }

  if (file.exists(path)) {
    unlink(path, force = TRUE)
  }
  rename_ok <- file.rename(temp_path, path)
  if (!isTRUE(rename_ok)) {
    if (file.exists(temp_path)) unlink(temp_path, force = TRUE)
    return(FALSE)
  }

  TRUE
}

vp_partition_read_manifest <- function() {
  manifest_path <- vp_partition_manifest_path()
  if (!file.exists(manifest_path)) {
    vp_partition_manifest_cache_clear()
    return(list(ok = FALSE, reason = "manifest_missing", manifest = vp_partition_manifest_base()))
  }

  manifest_info <- file.info(manifest_path)
  manifest_mtime <- suppressWarnings(as.numeric(manifest_info$mtime[[1L]]))
  manifest_size <- suppressWarnings(as.numeric(manifest_info$size[[1L]]))
  cached_manifest <- vp_partition_manifest_cache_env$manifest
  if (
    is.list(cached_manifest) &&
    identical(vp_partition_manifest_cache_env$path %||% NA_character_, manifest_path) &&
    identical(vp_partition_manifest_cache_env$mtime %||% NA_real_, manifest_mtime) &&
    identical(vp_partition_manifest_cache_env$size %||% NA_real_, manifest_size) &&
    vp_partition_manifest_compatible(cached_manifest)
  ) {
    return(list(ok = TRUE, reason = "manifest_current", manifest = cached_manifest, cache_state = "manifest_memory_cache"))
  }

  manifest <- tryCatch(readRDS(manifest_path), error = function(e) e)
  if (inherits(manifest, "error")) {
    vp_partition_manifest_cache_clear()
    return(list(ok = FALSE, reason = "manifest_read_error", manifest = vp_partition_manifest_base()))
  }
  if (!vp_partition_manifest_compatible(manifest)) {
    vp_partition_manifest_cache_clear()
    return(list(ok = FALSE, reason = "manifest_stale_or_incompatible", manifest = vp_partition_manifest_base()))
  }

  vp_partition_manifest_cache_env$path <- manifest_path
  vp_partition_manifest_cache_env$mtime <- manifest_mtime
  vp_partition_manifest_cache_env$size <- manifest_size
  vp_partition_manifest_cache_env$manifest <- manifest

  list(ok = TRUE, reason = "manifest_current", manifest = manifest, cache_state = "manifest_disk_read")
}

vp_partition_write_manifest <- function(manifest) {
  manifest$updated_at <- as.character(Sys.time())
  write_ok <- vp_partition_atomic_save_rds(manifest, vp_partition_manifest_path(), compress = TRUE)
  if (isTRUE(write_ok)) {
    vp_partition_manifest_cache_clear()
  }
  write_ok
}

vp_partition_file_size <- function(path) {
  info <- file.info(path)
  size <- suppressWarnings(as.numeric(info$size[[1L]]))
  if (is.finite(size)) size else NA_real_
}

vp_partition_entry_key <- function(trade_flow, group_filter, subgroup_filter, market_segment_filter) {
  vp_partition_cache_key(trade_flow, group_filter, subgroup_filter, market_segment_filter)
}

vp_partition_clean_family_values <- function(values) {
  family_values <- trimws(tolower(as.character(values %||% character(0))))
  family_values <- family_values[!is.na(family_values) & nzchar(family_values)]
  unique(family_values[family_values %in% c("liquid", "weight")])
}

vp_partition_volume_metadata_from_rows <- function(partition_rows) {
  if (!is.data.frame(partition_rows) || nrow(partition_rows) == 0L) {
    return(list(unique_volume_families = character(0), volume_family = "unknown", has_mixed_volume_family = FALSE))
  }

  mixed_from_flag <- FALSE
  if ("vp_volume_family_mixed" %in% names(partition_rows)) {
    mixed_flags <- as.logical(partition_rows$vp_volume_family_mixed)
    mixed_flags[is.na(mixed_flags)] <- FALSE
    mixed_from_flag <- any(mixed_flags)
  }

  family_values <- character(0)
  if ("volume_unit_family" %in% names(partition_rows)) {
    family_values <- vp_partition_clean_family_values(partition_rows$volume_unit_family)
  }

  if (isTRUE(mixed_from_flag) && length(family_values) < 2L) {
    volume_family <- "mixed"
  } else if (length(family_values) == 1L) {
    volume_family <- family_values[[1L]]
  } else if (length(family_values) > 1L) {
    volume_family <- "mixed"
  } else {
    volume_family <- "unknown"
  }

  list(
    unique_volume_families = family_values,
    volume_family = volume_family,
    has_mixed_volume_family = isTRUE(mixed_from_flag) || identical(volume_family, "mixed")
  )
}

vp_partition_metadata_subindex <- function(partition_rows, columns) {
  columns <- intersect(columns, names(partition_rows))
  if (!is.data.frame(partition_rows) || nrow(partition_rows) == 0L || length(columns) == 0L) {
    return(list())
  }

  split_key <- do.call(paste, c(partition_rows[columns], sep = "\r"))
  split_rows <- split(seq_len(nrow(partition_rows)), split_key, drop = TRUE)
  out <- lapply(split_rows, function(row_index) {
    rows <- partition_rows[row_index, , drop = FALSE]
    volume_metadata <- vp_partition_volume_metadata_from_rows(rows)
    values <- lapply(columns, function(column_name) trimws(as.character(rows[[column_name]][[1L]] %||% "")))
    names(values) <- columns
    c(
      values,
      list(
        row_count = nrow(rows),
        unique_volume_families = volume_metadata$unique_volume_families,
        volume_family = volume_metadata$volume_family,
        has_mixed_volume_family = volume_metadata$has_mixed_volume_family
      )
    )
  })
  names(out) <- names(split_rows)
  out
}

vp_partition_build_metadata <- function(partition_rows) {
  volume_metadata <- vp_partition_volume_metadata_from_rows(partition_rows)
  list(
    metadata_schema_version = vp_partition_metadata_schema_version,
    row_count = if (is.data.frame(partition_rows)) nrow(partition_rows) else 0L,
    col_count = if (is.data.frame(partition_rows)) ncol(partition_rows) else 0L,
    unique_volume_families = volume_metadata$unique_volume_families,
    volume_family = volume_metadata$volume_family,
    has_mixed_volume_family = volume_metadata$has_mixed_volume_family,
    commodity_name_index = vp_partition_metadata_subindex(partition_rows, c("CommodityName")),
    commodity_detail_index = vp_partition_metadata_subindex(partition_rows, c("CommodityName", "commodity")),
    built_at = as.character(Sys.time())
  )
}

vp_partition_build_entry <- function(partition_path,
                                     partition_rows,
                                     trade_flow,
                                     group_filter,
                                     subgroup_filter,
                                     market_segment_filter,
                                     payload = NULL,
                                     source_identity = NULL) {
  if (!is.list(source_identity)) source_identity <- vp_partition_source_identity(partition_rows)
  list(
    file_name = basename(partition_path),
    file_size_bytes = vp_partition_file_size(partition_path),
    storage_mode = if (is.list(payload)) payload$storage_mode %||% "row_index" else "row_index",
    payload_schema_version = if (is.list(payload)) payload$payload_schema_version %||% vp_partition_payload_schema_version else vp_partition_payload_schema_version,
    row_count = nrow(partition_rows),
    col_count = ncol(partition_rows),
    source_signature = source_identity$source_signature %||% NA_character_,
    source_row_count = source_identity$source_row_count %||% NA_integer_,
    source_col_count = source_identity$source_col_count %||% NA_integer_,
    source_column_hash = source_identity$source_column_hash %||% NA_character_,
    source_row_order_fingerprint = source_identity$source_row_order_fingerprint %||% NA_character_,
    index_count = if (is.list(payload)) length(payload$row_indices %||% integer(0)) else nrow(partition_rows),
    max_index = if (is.list(payload) && length(payload$row_indices %||% integer(0)) > 0L) max(payload$row_indices) else NA_integer_,
    trade_flow = trimws(as.character(trade_flow %||% "")),
    group_filter = trimws(as.character(group_filter %||% "")),
    subgroup_filter = trimws(as.character(subgroup_filter %||% "")),
    market_segment_filter = trimws(as.character(market_segment_filter %||% "")),
    metadata_schema_version = vp_partition_metadata_schema_version,
    metadata = vp_partition_build_metadata(partition_rows),
    materialized_at = as.character(Sys.time())
  )
}

vp_partition_entry_has_metadata <- function(entry) {
  is.list(entry) &&
    identical(entry$metadata_schema_version %||% NA_character_, vp_partition_metadata_schema_version) &&
    is.list(entry$metadata) &&
    identical(entry$metadata$metadata_schema_version %||% NA_character_, vp_partition_metadata_schema_version)
}

vp_partition_entry_matches <- function(entry, partition_path, trade_flow, group_filter, subgroup_filter, market_segment_filter) {
  is.list(entry) &&
    identical(entry$file_name %||% NA_character_, basename(partition_path)) &&
    identical(entry$trade_flow %||% NA_character_, trimws(as.character(trade_flow %||% ""))) &&
    identical(entry$group_filter %||% NA_character_, trimws(as.character(group_filter %||% ""))) &&
    identical(entry$subgroup_filter %||% NA_character_, trimws(as.character(subgroup_filter %||% ""))) &&
    identical(entry$market_segment_filter %||% NA_character_, trimws(as.character(market_segment_filter %||% ""))) &&
    file.exists(partition_path) &&
    isTRUE(is.finite(as.numeric(entry$file_size_bytes %||% NA_real_))) &&
    identical(as.numeric(entry$file_size_bytes), vp_partition_file_size(partition_path))
}

vp_partition_rows_match_entry <- function(partition_rows, entry) {
  is.data.frame(partition_rows) &&
    identical(nrow(partition_rows), as.integer(entry$row_count %||% NA_integer_)) &&
    identical(ncol(partition_rows), as.integer(entry$col_count %||% NA_integer_))
}

vp_partition_filter_indices <- function(vp_rows, trade_flow, group_filter, subgroup_filter, market_segment_filter) {
  row_indices <- seq_len(nrow(vp_rows))

  if ("Trade" %in% names(vp_rows) && !is.null(trade_flow) && nzchar(as.character(trade_flow[[1L]]))) {
    row_indices <- row_indices[vp_rows$Trade[row_indices] == as.character(trade_flow[[1L]])]
  }
  if ("Group" %in% names(vp_rows) && !is.null(group_filter) && nzchar(as.character(group_filter[[1L]]))) {
    row_indices <- row_indices[vp_rows$Group[row_indices] == as.character(group_filter[[1L]])]
  }
  if ("Subgroup" %in% names(vp_rows) && !is.null(subgroup_filter) && nzchar(as.character(subgroup_filter[[1L]]))) {
    row_indices <- row_indices[vp_rows$Subgroup[row_indices] == as.character(subgroup_filter[[1L]])]
  }
  if ("MarketSegment" %in% names(vp_rows) && !is.null(market_segment_filter) && nzchar(as.character(market_segment_filter[[1L]]))) {
    row_indices <- row_indices[vp_rows$MarketSegment[row_indices] == as.character(market_segment_filter[[1L]])]
  }

  as.integer(row_indices)
}

vp_partition_build_payload <- function(row_indices,
                                       source_identity,
                                       trade_flow,
                                       group_filter,
                                       subgroup_filter,
                                       market_segment_filter) {
  row_indices <- as.integer(row_indices %||% integer(0))
  list(
    storage_mode = "row_index",
    payload_schema_version = vp_partition_payload_schema_version,
    row_indices = row_indices,
    row_count = length(row_indices),
    source_signature = source_identity$source_signature %||% NA_character_,
    source_row_count = source_identity$source_row_count %||% NA_integer_,
    source_col_count = source_identity$source_col_count %||% NA_integer_,
    source_column_hash = source_identity$source_column_hash %||% NA_character_,
    source_row_order_fingerprint = source_identity$source_row_order_fingerprint %||% NA_character_,
    trade_flow = trimws(as.character(trade_flow %||% "")),
    group_filter = trimws(as.character(group_filter %||% "")),
    subgroup_filter = trimws(as.character(subgroup_filter %||% "")),
    market_segment_filter = trimws(as.character(market_segment_filter %||% "")),
    materialized_at = as.character(Sys.time())
  )
}

vp_partition_payload_matches_entry <- function(payload, entry, source_identity) {
  if (!is.list(payload)) return(list(ok = FALSE, reason = "payload_not_list"))
  if (!identical(payload$storage_mode %||% NA_character_, "row_index")) return(list(ok = FALSE, reason = "payload_storage_mode_mismatch"))
  if (!identical(payload$payload_schema_version %||% NA_character_, vp_partition_payload_schema_version)) return(list(ok = FALSE, reason = "payload_schema_mismatch"))
  if (!identical(entry$storage_mode %||% NA_character_, "row_index")) return(list(ok = FALSE, reason = "entry_storage_mode_mismatch"))
  if (!identical(entry$payload_schema_version %||% NA_character_, vp_partition_payload_schema_version)) return(list(ok = FALSE, reason = "entry_payload_schema_mismatch"))

  row_indices <- payload$row_indices %||% NULL
  if (!is.integer(row_indices)) return(list(ok = FALSE, reason = "payload_indices_not_integer"))
  if (any(is.na(row_indices))) return(list(ok = FALSE, reason = "payload_indices_missing"))
  if (!identical(length(row_indices), as.integer(entry$row_count %||% NA_integer_))) return(list(ok = FALSE, reason = "payload_row_count_mismatch"))
  if (!identical(payload$row_count %||% NA_integer_, length(row_indices))) return(list(ok = FALSE, reason = "payload_index_count_mismatch"))
  if (length(row_indices) > 0L && (min(row_indices) < 1L || max(row_indices) > as.integer(source_identity$source_row_count %||% NA_integer_))) {
    return(list(ok = FALSE, reason = "payload_index_bounds_mismatch"))
  }

  fields <- c("source_signature", "source_row_count", "source_col_count", "source_column_hash", "source_row_order_fingerprint")
  for (field_name in fields) {
    if (!identical(payload[[field_name]] %||% NULL, source_identity[[field_name]] %||% NULL)) {
      return(list(ok = FALSE, reason = paste0("payload_", field_name, "_mismatch")))
    }
    if (!identical(entry[[field_name]] %||% NULL, source_identity[[field_name]] %||% NULL)) {
      return(list(ok = FALSE, reason = paste0("entry_", field_name, "_mismatch")))
    }
  }

  list(ok = TRUE, reason = "payload_current")
}

vp_partition_restore_rows <- function(vp_rows, payload, entry, source_identity) {
  payload_status <- vp_partition_payload_matches_entry(payload, entry, source_identity)
  if (!isTRUE(payload_status$ok)) return(list(ok = FALSE, reason = payload_status$reason, rows = NULL))
  rows <- vp_rows[payload$row_indices, , drop = FALSE]
  if (!vp_partition_rows_match_entry(rows, entry)) return(list(ok = FALSE, reason = "restored_rows_entry_mismatch", rows = NULL))
  list(ok = TRUE, reason = "restored_rows_current", rows = rows)
}

vp_partition_verify_manifest_metadata <- function(partition_rows, entry) {
  if (!vp_partition_entry_has_metadata(entry)) return(FALSE)
  expected <- vp_partition_build_metadata(partition_rows)
  identical(expected$row_count, entry$metadata$row_count) &&
    identical(expected$col_count, entry$metadata$col_count) &&
    identical(sort(expected$unique_volume_families), sort(entry$metadata$unique_volume_families %||% character(0))) &&
    identical(expected$volume_family, entry$metadata$volume_family) &&
    identical(isTRUE(expected$has_mixed_volume_family), isTRUE(entry$metadata$has_mixed_volume_family))
}

vp_partition_cache_key <- function(trade_flow, group_filter, subgroup_filter, market_segment_filter) {
  paste(
    "slice",
    trimws(as.character(trade_flow %||% "")),
    trimws(as.character(group_filter %||% "")),
    trimws(as.character(subgroup_filter %||% "")),
    trimws(as.character(market_segment_filter %||% "")),
    sep = "|"
  )
}

vp_partition_file_name <- function(trade_flow, group_filter, subgroup_filter, market_segment_filter) {
  hash_token <- vp_partition_hash(c(trade_flow, group_filter, subgroup_filter, market_segment_filter))
  paste0("slice__", hash_token, ".rds")
}

vp_partition_filter_direct <- function(vp_rows, trade_flow, group_filter, subgroup_filter, market_segment_filter) {
  out <- vp_rows

  if ("Trade" %in% names(out) && !is.null(trade_flow) && nzchar(as.character(trade_flow[[1L]]))) {
    out <- out[out$Trade == as.character(trade_flow[[1L]]), , drop = FALSE]
  }
  if ("Group" %in% names(out) && !is.null(group_filter) && nzchar(as.character(group_filter[[1L]]))) {
    out <- out[out$Group == as.character(group_filter[[1L]]), , drop = FALSE]
  }
  if ("Subgroup" %in% names(out) && !is.null(subgroup_filter) && nzchar(as.character(subgroup_filter[[1L]]))) {
    out <- out[out$Subgroup == as.character(subgroup_filter[[1L]]), , drop = FALSE]
  }
  if ("MarketSegment" %in% names(out) && !is.null(market_segment_filter) && nzchar(as.character(market_segment_filter[[1L]]))) {
    out <- out[out$MarketSegment == as.character(market_segment_filter[[1L]]), , drop = FALSE]
  }

  out
}

vp_partition_metadata_state <- function(manifest_status, manifest_entry, partition_path, trade_flow, group_filter, subgroup_filter, market_segment_filter) {
  if (!isTRUE(manifest_status$ok)) return(manifest_status$reason %||% "metadata_unavailable")
  if (!vp_partition_entry_matches(manifest_entry, partition_path, trade_flow, group_filter, subgroup_filter, market_segment_filter)) {
    return("metadata_stale")
  }
  if (!vp_partition_entry_has_metadata(manifest_entry)) return("metadata_missing")
  "metadata_current"
}

vp_partition_context_scalar <- function(provider_context, name, default = NA_character_) {
  value <- provider_context[[name]] %||% default
  value <- trimws(as.character(value %||% default))
  if (length(value) == 0L || is.na(value[[1L]]) || !nzchar(value[[1L]])) default else value[[1L]]
}

vp_partition_context_details <- function(provider_context = NULL,
                                         trade_flow = NULL,
                                         group_filter = NULL,
                                         subgroup_filter = NULL,
                                         market_segment_filter = NULL) {
  if (!is.list(provider_context)) provider_context <- list()

  list(
    request_kind = vp_partition_context_scalar(provider_context, "request_kind", "user_hit"),
    filter_purpose = vp_partition_context_scalar(provider_context, "filter_purpose", "unknown"),
    active_tab = vp_partition_context_scalar(provider_context, "active_tab", "unknown"),
    source = vp_partition_context_scalar(provider_context, "source", "unknown"),
    trade_flow = vp_partition_context_scalar(provider_context, "trade_flow", trimws(as.character(trade_flow %||% ""))),
    group_filter = vp_partition_context_scalar(provider_context, "group_filter", trimws(as.character(group_filter %||% ""))),
    subgroup_filter = vp_partition_context_scalar(provider_context, "subgroup_filter", trimws(as.character(subgroup_filter %||% ""))),
    market_segment_filter = vp_partition_context_scalar(provider_context, "market_segment_filter", trimws(as.character(market_segment_filter %||% ""))),
    commodity_name = vp_partition_context_scalar(provider_context, "commodity_name", "<none>"),
    commodity_detail = vp_partition_context_scalar(provider_context, "commodity_detail", "<none>"),
    resolution_mode = vp_partition_context_scalar(provider_context, "resolution_mode", "unknown"),
    strict_rollup_context = isTRUE(provider_context$strict_rollup_context),
    sparse_selection = isTRUE(provider_context$sparse_selection),
    path_name = vp_partition_context_scalar(provider_context, "path_name", "unknown")
  )
}

vp_partition_get_hierarchy_slice <- function(vp_rows,
                                             trade_flow,
                                             group_filter,
                                             subgroup_filter,
                                             market_segment_filter,
                                             provider_context = NULL) {
  start_time <- Sys.time()
  context_details <- vp_partition_context_details(
    provider_context = provider_context,
    trade_flow = trade_flow,
    group_filter = group_filter,
    subgroup_filter = subgroup_filter,
    market_segment_filter = market_segment_filter
  )

  if (!is.data.frame(vp_rows) || nrow(vp_rows) == 0L) {
    return(data.frame())
  }

  partition_path <- file.path(
    vp_partition_provider_dir(),
    vp_partition_file_name(trade_flow, group_filter, subgroup_filter, market_segment_filter)
  )
  source_status <- vp_partition_source_is_eligible(vp_rows)
  source_identity <- source_status$identity

  has_partition_cols <- all(c("Trade", "Group", "Subgroup", "MarketSegment") %in% names(vp_rows))
  if (!isTRUE(vp_partition_provider_enabled()) || !isTRUE(has_partition_cols) || !isTRUE(source_status$ok)) {
    out <- vp_partition_filter_direct(vp_rows, trade_flow, group_filter, subgroup_filter, market_segment_filter)
    log_perf(
      "vp_partition_provider_slice()",
      start_time,
      details = c(list(
        mode = "direct_fallback",
        enabled = isTRUE(vp_partition_provider_enabled()),
        has_partition_cols = isTRUE(has_partition_cols),
        storage_mode = "direct_rows",
        source_eligible = isTRUE(source_status$ok),
        source_eligibility_reason = source_status$reason %||% NA_character_,
        rows = nrow(out),
        partition_file = basename(partition_path)
      ), context_details)
    )
    return(out)
  }

  cache_key <- vp_partition_cache_key(trade_flow, group_filter, subgroup_filter, market_segment_filter)
  if (exists(cache_key, envir = vp_partition_cache_env, inherits = FALSE)) {
    out <- get(cache_key, envir = vp_partition_cache_env, inherits = FALSE)
    log_perf(
      "vp_partition_provider_slice()",
      start_time,
      details = c(list(
        mode = "memory_cache",
        rows = nrow(out),
        partition_file = basename(partition_path)
      ), context_details)
    )
    return(out)
  }

  manifest_status <- vp_partition_read_manifest()
  manifest <- manifest_status$manifest
  entry_key <- vp_partition_entry_key(trade_flow, group_filter, subgroup_filter, market_segment_filter)
  manifest_entry <- manifest$entries[[entry_key]]

  out <- NULL
  mode <- "disk_cache"
  fallback_reason <- NA_character_
  partition_read_ms <- NA_integer_
  partition_restore_ms <- NA_integer_
  if (isTRUE(manifest_status$ok) && vp_partition_entry_matches(manifest_entry, partition_path, trade_flow, group_filter, subgroup_filter, market_segment_filter)) {
    read_start <- Sys.time()
    payload <- tryCatch(readRDS(partition_path), error = function(e) e)
    partition_read_ms <- perf_elapsed_ms(read_start)
    if (inherits(payload, "error")) {
      fallback_reason <- "partition_read_error"
    } else {
      restore_start <- Sys.time()
      restore_status <- vp_partition_restore_rows(vp_rows, payload, manifest_entry, source_identity)
      partition_restore_ms <- perf_elapsed_ms(restore_start)
      if (isTRUE(restore_status$ok)) {
        out <- restore_status$rows
      } else {
        fallback_reason <- restore_status$reason %||% "partition_entry_mismatch"
      }
    }
  } else {
    fallback_reason <- manifest_status$reason %||% "manifest_entry_missing_or_stale"
  }

  if (is.null(out)) {
    mode <- "materialized"
    row_indices <- vp_partition_filter_indices(vp_rows, trade_flow, group_filter, subgroup_filter, market_segment_filter)
    out <- vp_rows[row_indices, , drop = FALSE]
    payload <- vp_partition_build_payload(
      row_indices = row_indices,
      source_identity = source_identity,
      trade_flow = trade_flow,
      group_filter = group_filter,
      subgroup_filter = subgroup_filter,
      market_segment_filter = market_segment_filter
    )
    dir.create(dirname(partition_path), recursive = TRUE, showWarnings = FALSE)
    save_ok <- vp_partition_atomic_save_rds(payload, partition_path, compress = TRUE)

    if (isTRUE(save_ok)) {
      manifest$entries[[entry_key]] <- vp_partition_build_entry(
        partition_path = partition_path,
        partition_rows = out,
        trade_flow = trade_flow,
        group_filter = group_filter,
        subgroup_filter = subgroup_filter,
        market_segment_filter = market_segment_filter,
        payload = payload,
        source_identity = source_identity
      )
      vp_partition_write_manifest(manifest)
    } else {
      fallback_reason <- "partition_save_error"
    }
  }

  assign(cache_key, out, envir = vp_partition_cache_env)

  log_perf(
    "vp_partition_provider_slice()",
    start_time,
    details = c(list(
      mode = mode,
      fallback_reason = fallback_reason,
      manifest_reason = manifest_status$reason,
      storage_mode = "row_index",
      payload_schema_version = vp_partition_payload_schema_version,
      partition_read_ms = partition_read_ms,
      partition_restore_ms = partition_restore_ms,
      source_eligible = isTRUE(source_status$ok),
      source_eligibility_reason = source_status$reason %||% NA_character_,
      source_row_count = source_identity$source_row_count %||% NA_integer_,
      source_row_order_fingerprint = source_identity$source_row_order_fingerprint %||% NA_character_,
      rows = nrow(out),
      partition_file = basename(partition_path)
    ), context_details)
  )

  out
}

vp_partition_get_hierarchy_metadata <- function(trade_flow,
                                                group_filter,
                                                subgroup_filter,
                                                market_segment_filter,
                                                provider_context = NULL) {
  start_time <- Sys.time()
  context_details <- vp_partition_context_details(
    provider_context = provider_context,
    trade_flow = trade_flow,
    group_filter = group_filter,
    subgroup_filter = subgroup_filter,
    market_segment_filter = market_segment_filter
  )
  partition_path <- file.path(
    vp_partition_provider_dir(),
    vp_partition_file_name(trade_flow, group_filter, subgroup_filter, market_segment_filter)
  )
  entry_key <- vp_partition_entry_key(trade_flow, group_filter, subgroup_filter, market_segment_filter)
  manifest_status <- vp_partition_read_manifest()
  manifest_entry <- manifest_status$manifest$entries[[entry_key]]
  metadata_state <- vp_partition_metadata_state(manifest_status, manifest_entry, partition_path, trade_flow, group_filter, subgroup_filter, market_segment_filter)
  metadata <- if (identical(metadata_state, "metadata_current")) manifest_entry$metadata else NULL
  unique_families <- if (is.list(metadata)) metadata$unique_volume_families %||% character(0) else character(0)
  metadata_definitive <- length(unique_families) == 1L

  log_perf(
    "vp_partition_provider_metadata()",
    start_time,
    details = c(list(
      metadata_state = metadata_state,
      metadata_definitive = isTRUE(metadata_definitive),
      manifest_reason = manifest_status$reason,
      manifest_cache_state = manifest_status$cache_state %||% "unknown",
      entry_key = entry_key,
      partition_file = basename(partition_path),
      row_count = if (is.list(metadata)) metadata$row_count %||% NA_integer_ else NA_integer_,
      unique_volume_families = paste(unique_families, collapse = "|"),
      volume_family = if (is.list(metadata)) metadata$volume_family %||% "unknown" else "unknown",
      has_mixed_volume_family = if (is.list(metadata)) isTRUE(metadata$has_mixed_volume_family) else NA
    ), context_details)
  )

  list(
    ok = identical(metadata_state, "metadata_current"),
    reason = metadata_state,
    metadata_state = metadata_state,
    metadata_definitive = metadata_definitive,
    metadata = metadata,
    entry_key = entry_key,
    partition_file = basename(partition_path),
    manifest_reason = manifest_status$reason,
    manifest_cache_state = manifest_status$cache_state %||% "unknown"
  )
}

vp_partition_provider_filter_rows <- function(vp_rows,
                                              trade_flow,
                                              group_filter,
                                              subgroup_filter,
                                              market_segment_filter,
                                              commodity_name = NULL,
                                              commodity_detail = NULL,
                                              provider_context = NULL) {
  out <- vp_partition_get_hierarchy_slice(
    vp_rows = vp_rows,
    trade_flow = trade_flow,
    group_filter = group_filter,
    subgroup_filter = subgroup_filter,
    market_segment_filter = market_segment_filter,
    provider_context = provider_context
  )

  normalized_commodity_name <- trimws(as.character(commodity_name %||% character(0)))
  normalized_commodity_name <- normalized_commodity_name[!is.na(normalized_commodity_name) & nzchar(normalized_commodity_name)]
  if (length(normalized_commodity_name) > 0L && "CommodityName" %in% names(out)) {
    out <- out[out$CommodityName == normalized_commodity_name[[1L]], , drop = FALSE]
  }

  normalized_commodity_detail <- trimws(as.character(commodity_detail %||% character(0)))
  normalized_commodity_detail <- normalized_commodity_detail[!is.na(normalized_commodity_detail) & nzchar(normalized_commodity_detail)]
  if (length(normalized_commodity_detail) > 0L && "commodity" %in% names(out)) {
    out <- out[out$commodity == normalized_commodity_detail[[1L]], , drop = FALSE]
  }

  out
}

startup_stage_start_time <- Sys.time()
rice_data_census_monthly <- load_startup_dataset_for_source(
  source_family = "census_exports",
  dataset_name = "census_exports_monthly",
  tag = "startup_init(load_census_monthly_data_export)",
  artifact_path = census_exports_prepped_path,
  source_paths = startup_source_paths("census_exports", c(census_exports_path)),
  extra_signatures = artifact_extra_signatures("census_exports_monthly"),
  fallback_loader = function() {
    load_census_monthly_data(
      path = census_exports_path,
      country_canonical_map = country_canonical_map,
      trade_flow = "export"
    )
  },
  disabled_loader = empty_monthly_source_dataset
)
rice_data_census_monthly_fiscal <- load_startup_dataset_for_source(
  source_family = "census_exports",
  dataset_name = "census_exports_monthly_fiscal",
  tag = "startup_init(load_census_monthly_data_export_fiscal)",
  artifact_path = census_exports_fiscal_prepped_path,
  source_paths = startup_source_paths("census_exports", c(census_exports_path)),
  extra_signatures = artifact_extra_signatures("census_exports_monthly_fiscal"),
  fallback_loader = function() {
    materialize_non_psd_monthly_fiscal_data(
      rice_data_census_monthly,
      source_choice = "census"
    )
  },
  disabled_loader = empty_monthly_source_dataset,
  dataset_enabled = startup_census_fiscal_year_enabled("runtime"),
  dataset_disabled_reason = "census_exports_monthly_fiscal_feature_disabled"
)

startup_stage_start_time <- Sys.time()
rice_data_census_imports_monthly <- load_startup_dataset_for_source(
  source_family = "census_imports",
  dataset_name = "census_imports_monthly",
  tag = "startup_init(load_census_monthly_data_import)",
  artifact_path = census_imports_prepped_path,
  source_paths = startup_source_paths("census_imports", c(census_imports_path)),
  extra_signatures = artifact_extra_signatures("census_imports_monthly"),
  fallback_loader = function() {
    load_census_monthly_data(
      path = census_imports_path,
      country_canonical_map = country_canonical_map,
      trade_flow = "import"
    )
  },
  disabled_loader = empty_monthly_source_dataset
)
rice_data_census_imports_monthly_fiscal <- load_startup_dataset_for_source(
  source_family = "census_imports",
  dataset_name = "census_imports_monthly_fiscal",
  tag = "startup_init(load_census_monthly_data_import_fiscal)",
  artifact_path = census_imports_fiscal_prepped_path,
  source_paths = startup_source_paths("census_imports", c(census_imports_path)),
  extra_signatures = artifact_extra_signatures("census_imports_monthly_fiscal"),
  fallback_loader = function() {
    materialize_non_psd_monthly_fiscal_data(
      rice_data_census_imports_monthly,
      source_choice = "census"
    )
  },
  disabled_loader = empty_monthly_source_dataset,
  dataset_enabled = startup_census_fiscal_year_enabled("runtime"),
  dataset_disabled_reason = "census_imports_monthly_fiscal_feature_disabled"
)

commodity_data_census_exports_monthly <- rice_data_census_monthly
commodity_data_census_exports_monthly_fiscal <- rice_data_census_monthly_fiscal
commodity_data_census_imports_monthly <- rice_data_census_imports_monthly
commodity_data_census_imports_monthly_fiscal <- rice_data_census_imports_monthly_fiscal

load_hybrid_monthly_data <- function(path) {
  start_time <- Sys.time()

  if (!file.exists(path)) {
    stop(
      paste0(
        "Hybrid monthly artifact is missing at ",
        path,
        ". Run Master.R to generate Output/Hybrid artifacts before launching the app."
      ),
      call. = FALSE
    )
  }

  numeric_cols <- c(
    "market_year", "analysis_month", "market_month", "calendar_month", "calendar_year",
    "monthlyexports", "monthlyexports_rough_eq", "ytd_exports", "ytd_exports_rough_eq",
    "total_commitment", "total_commitment_rough_eq", "outstandingSales", "outstandingSales_rough_eq",
    "grossNewSales", "grossNewSales_rough_eq", "currentMYNetSales", "currentMYNetSales_rough_eq",
    "nextMYOutstandingSales", "nextMYOutstandingSales_rough_eq", "nextMYNetSales", "nextMYNetSales_rough_eq",
    "monthlyvalue", "monthlyvalue_rough_eq", "ytd_value", "ytd_value_rough_eq",
    "hybrid_quantity_cwt_rough_eq", "hybrid_pre_clamp_cwt_rough_eq", "final_adjusted_hybrid_cwt_rough_eq",
    "census_all_rice_raw_cwt_rough_eq", "census_all_rice_adjusted_cwt_rough_eq",
    "census_rough_rice_raw_cwt_rough_eq", "census_rough_rice_adjusted_cwt_rough_eq",
    "census_milled_msg_raw_cwt_rough_eq", "census_milled_msg_adjusted_cwt_rough_eq",
    "export_rough_msg_raw_cwt_rough_eq", "export_rough_msg_adjusted_cwt_rough_eq",
    "hybrid_missing_component_count"
  )

  text_cols <- c(
    "country", "countryDescription", "commodity", "hybrid_type", "hybrid_formula_id",
    "hybrid_formula_text", "source_systems_used", "raw_census_variables_used",
    "raw_export_sales_variables_used", "adjusted_variables_used", "adjustment_flags",
    "adjustment_notes"
  )

  logical_cols <- c("hybrid_negative_clamp_flag")

  out <- read.csv(
    path,
    stringsAsFactors = FALSE,
    check.names = FALSE,
    colClasses = build_named_col_classes(
      numeric_cols = numeric_cols,
      text_cols = text_cols,
      logical_cols = logical_cols,
      date_cols = c("week_ending_date", "market_month_name")
    )
  ) %>%
    mutate(
      across(any_of(text_cols), trimws),
      week_ending_date = as.Date(.data$week_ending_date),
      market_month = dplyr::coalesce(.data$market_month, .data$analysis_month),
      market_month_name = dplyr::coalesce(.data$market_month_name, hybrid_market_month_name_lookup[.data$market_month]),
      analysis_month = dplyr::coalesce(.data$analysis_month, .data$market_month),
      countryDescription = ifelse(.data$country == "GRAND_TOTAL", "World", .data$countryDescription)
    ) %>%
    arrange(market_year, analysis_month, commodity, country)

  log_perf(
    "load_hybrid_monthly_data()",
    start_time,
    details = list(path = basename(path), rows = nrow(out), cols = ncol(out))
  )

  out
}

load_hybrid_weekly_imputed_data <- function(path) {
  start_time <- Sys.time()

  if (!file.exists(path)) {
    stop(
      paste0(
        "Hybrid weekly-imputed artifact is missing at ",
        path,
        ". Run Master.R or Programs/Generate_Hybrid_Data.R to generate Output/Hybrid artifacts before launching the app."
      ),
      call. = FALSE
    )
  }

  numeric_cols <- c(
    "market_year", "analysis_month", "market_month", "calendar_month", "calendar_year",
    "monthlyexports", "monthlyexports_rough_eq", "ytd_exports", "ytd_exports_rough_eq",
    "total_commitment", "total_commitment_rough_eq", "outstandingSales", "outstandingSales_rough_eq",
    "grossNewSales", "grossNewSales_rough_eq", "currentMYNetSales", "currentMYNetSales_rough_eq",
    "nextMYOutstandingSales", "nextMYOutstandingSales_rough_eq", "nextMYNetSales", "nextMYNetSales_rough_eq",
    "monthlyvalue", "monthlyvalue_rough_eq", "ytd_value", "ytd_value_rough_eq",
    "hybrid_quantity_cwt_rough_eq", "hybrid_pre_clamp_cwt_rough_eq", "final_adjusted_hybrid_cwt_rough_eq",
    "census_all_rice_raw_cwt_rough_eq", "census_all_rice_adjusted_cwt_rough_eq",
    "census_rough_rice_raw_cwt_rough_eq", "census_rough_rice_adjusted_cwt_rough_eq",
    "census_milled_msg_raw_cwt_rough_eq", "census_milled_msg_adjusted_cwt_rough_eq",
    "export_rough_msg_raw_cwt_rough_eq", "export_rough_msg_adjusted_cwt_rough_eq",
    "hybrid_missing_component_count", "imputation_weight", "monthly_reconciliation_analysis_month"
  )

  text_cols <- c(
    "country", "countryDescription", "country_source_code", "commodity", "hybrid_type", "hybrid_formula_id",
    "hybrid_formula_text", "source_systems_used", "raw_census_variables_used",
    "raw_export_sales_variables_used", "adjusted_variables_used", "adjustment_flags",
    "adjustment_notes", "weekly_hybrid_mode", "weekly_data_segment", "monthly_reconciliation_months"
  )

  logical_cols <- c(
    "hybrid_negative_clamp_flag",
    "is_imputed_weekly",
    "is_export_sales_extension",
    "splice_boundary_flag"
  )

  out <- read.csv(
    path,
    stringsAsFactors = FALSE,
    check.names = FALSE,
    colClasses = build_named_col_classes(
      numeric_cols = numeric_cols,
      text_cols = text_cols,
      logical_cols = logical_cols,
      date_cols = c("week_ending_date", "market_month_name")
    )
  ) %>%
    mutate(
      across(any_of(text_cols), trimws),
      week_ending_date = as.Date(.data$week_ending_date),
      market_month_name = dplyr::coalesce(.data$market_month_name, hybrid_market_month_name_lookup[.data$market_month]),
      countryDescription = ifelse(.data$country == "GRAND_TOTAL", "World", .data$countryDescription)
    ) %>%
    arrange(market_year, analysis_month, commodity, country) %>%
    assert_unique_rows_by_key(
      key_cols = c("market_year", "analysis_month", "week_ending_date", "country", "commodity"),
      dataset_label = "Hybrid weekly-imputed artifact"
    )

  log_perf(
    "load_hybrid_weekly_imputed_data()",
    start_time,
    details = list(path = basename(path), rows = nrow(out), cols = ncol(out))
  )

  out
}

psd_metric_column_map_all <- c(
  area_harvested = "psd_area_harvested",
  beginning_stocks = "psd_beginning_stocks",
  production = "psd_production",
  rough_production = "psd_rough_production",
  imports = "psd_imports",
  ty_imports = "psd_ty_imports",
  ty_imports_from_us = "psd_ty_imports_from_us",
  total_supply = "psd_total_supply",
  exports = "psd_exports",
  ty_exports = "psd_ty_exports",
  yield = "psd_yield",
  domestic_consumption = "psd_domestic_consumption",
  ending_stocks = "psd_ending_stocks",
  total_distribution = "psd_total_distribution"
)
psd_metric_column_map <- psd_metric_column_map_all[
  names(psd_metric_column_map_all) %in% startup_psd_expected_metric_ids(names(psd_metric_column_map_all))
]

psd_basis_pair_metric_ids <- setdiff(names(psd_metric_column_map), c("rough_production", "yield"))
psd_basis_pair_metric_cols <- unname(psd_metric_column_map[psd_basis_pair_metric_ids])

psd_companion_metric_column_map_all <- c(
  area_harvested_rough_eq = "psd_area_harvested_rough_eq",
  beginning_stocks_rough_eq = "psd_beginning_stocks_rough_eq",
  production_rough_eq = "psd_production_rough_eq",
  imports_rough_eq = "psd_imports_rough_eq",
  ty_imports_rough_eq = "psd_ty_imports_rough_eq",
  ty_imports_from_us_rough_eq = "psd_ty_imports_from_us_rough_eq",
  total_supply_rough_eq = "psd_total_supply_rough_eq",
  exports_rough_eq = "psd_exports_rough_eq",
  ty_exports_rough_eq = "psd_ty_exports_rough_eq",
  domestic_consumption_rough_eq = "psd_domestic_consumption_rough_eq",
  ending_stocks_rough_eq = "psd_ending_stocks_rough_eq",
  total_distribution_rough_eq = "psd_total_distribution_rough_eq",
  yield_milled_eq = "psd_yield_milled_eq_prepped"
)
psd_companion_metric_column_map <- if (identical(startup_psd_basis_profile(), "shelled_basis")) {
  character()
} else {
  psd_companion_metric_column_map_all
}

psd_metric_value_scale_all <- c(
  area_harvested = 1,
  beginning_stocks = 1,
  production = 1,
  rough_production = 1,
  imports = 1,
  ty_imports = 1,
  ty_imports_from_us = 1,
  total_supply = 1,
  exports = 1,
  ty_exports = 1,
  yield = 1,
  domestic_consumption = 1,
  ending_stocks = 1,
  total_distribution = 1
)
psd_metric_value_scale <- psd_metric_value_scale_all[names(psd_metric_column_map)]

prepare_psd_app_marketing_year_data <- function(psd_long_data) {
  start_time <- Sys.time()

  assert_dataset_columns(psd_long_data, psd_required_processed_cols, "rice_data_psd_long")

  grouping_cols <- c(
    "source", "frequency", "commodity", "commodity_group", "country", "countryDescription", "country_source_code",
    "market_year", "analysis_month", "calendar_year", "calendar_month",
    "release_year", "release_month", "release_period"
  )
  psd_basis_profile <- startup_psd_basis_profile()

  metric_rows_start_time <- Sys.time()
  psd_metric_rows <- psd_long_data %>%
    filter(.data$normalized_metric_id %in% names(psd_metric_column_map)) %>%
    mutate(
      metric_col = unname(psd_metric_column_map[.data$normalized_metric_id]),
      metric_scale = unname(psd_metric_value_scale[.data$normalized_metric_id]),
      metric_value = .data$value_canonical * .data$metric_scale
    ) %>%
    distinct(across(all_of(c(grouping_cols, "metric_col"))), .keep_all = TRUE) %>%
    transmute(
      across(all_of(grouping_cols)),
      metric_col,
      metric_value,
      metric_provenance = .data$value_provenance,
      metric_provenance_note = .data$provenance_note,
      metric_world_source = .data$world_source,
      metric_components = .data$construction_components
    )
  log_perf(
    "prepare_psd_app_marketing_year_data(): metric_rows",
    metric_rows_start_time,
    details = list(rows = nrow(psd_metric_rows), metric_cols = dplyr::n_distinct(psd_metric_rows$metric_col))
  )

  companion_rows_start_time <- Sys.time()
  psd_companion_metric_rows <- psd_long_data %>%
    filter(.data$normalized_metric_id %in% names(psd_companion_metric_column_map)) %>%
    mutate(
      metric_col = unname(psd_companion_metric_column_map[.data$normalized_metric_id]),
      metric_value = .data$value_canonical
    ) %>%
    distinct(across(all_of(c(grouping_cols, "metric_col"))), .keep_all = TRUE) %>%
    transmute(
      across(all_of(grouping_cols)),
      metric_col,
      metric_value
    )

  milling_rate_rows <- if (identical(psd_basis_profile, "shelled_basis")) {
    psd_long_data[0, grouping_cols, drop = FALSE]
  } else {
    psd_long_data %>%
      filter(.data$normalized_metric_id == "milling_rate") %>%
      distinct(across(all_of(grouping_cols)), .keep_all = TRUE) %>%
      transmute(
        across(all_of(grouping_cols)),
        psd_milling_rate = .data$value_canonical
      )
  }
  log_perf(
    "prepare_psd_app_marketing_year_data(): companion_rows",
    companion_rows_start_time,
    details = list(
      companion_rows = nrow(psd_companion_metric_rows),
      companion_metric_cols = dplyr::n_distinct(psd_companion_metric_rows$metric_col),
      milling_rows = nrow(milling_rate_rows)
    )
  )

  pivot_start_time <- Sys.time()
  metric_wide <- psd_metric_rows %>%
    select(
      all_of(grouping_cols),
      metric_col,
      metric_value,
      metric_provenance,
      metric_provenance_note,
      metric_world_source,
      metric_components
    ) %>%
    tidyr::pivot_wider(
      names_from = metric_col,
      values_from = c(
        metric_value,
        metric_provenance,
        metric_provenance_note,
        metric_world_source,
        metric_components
      ),
      names_glue = "{metric_col}__{.value}"
    )

  metric_wide_names <- names(metric_wide)
  metric_wide_names <- sub("__metric_value$", "", metric_wide_names)
  metric_wide_names <- sub("__metric_provenance$", "_provenance", metric_wide_names)
  metric_wide_names <- sub("__metric_provenance_note$", "_provenance_note", metric_wide_names)
  metric_wide_names <- sub("__metric_world_source$", "_world_source", metric_wide_names)
  metric_wide_names <- sub("__metric_components$", "_construction_components", metric_wide_names)
  names(metric_wide) <- metric_wide_names

  metric_cols <- unname(psd_metric_column_map)
  metric_metadata_cols <- c(
    paste0(metric_cols, "_provenance"),
    paste0(metric_cols, "_provenance_note"),
    paste0(metric_cols, "_world_source"),
    paste0(metric_cols, "_construction_components")
  )

  value_wide <- metric_wide %>%
    select(all_of(grouping_cols), any_of(metric_cols))

  metric_metadata_wide <- metric_wide %>%
    select(all_of(grouping_cols), any_of(metric_metadata_cols))

  companion_value_wide <- psd_companion_metric_rows %>%
    select(all_of(grouping_cols), metric_col, metric_value) %>%
    tidyr::pivot_wider(names_from = metric_col, values_from = metric_value)
  log_perf(
    "prepare_psd_app_marketing_year_data(): pivot_wide",
    pivot_start_time,
    details = list(
      value_rows = nrow(value_wide),
      companion_rows = nrow(companion_value_wide),
      provenance_rows = nrow(metric_metadata_wide)
    )
  )

  join_start_time <- Sys.time()
  out <- value_wide %>%
    left_join(companion_value_wide, by = grouping_cols) %>%
    left_join(milling_rate_rows, by = grouping_cols) %>%
    left_join(metric_metadata_wide, by = grouping_cols) %>%
    mutate(
      commodity = startup_psd_app_commodity_label(),
      commodity_group = startup_psd_app_commodity_group(),
      countryDescription = ifelse(.data$country == "GRAND_TOTAL", "World", .data$countryDescription),
      psd_row_world_source = dplyr::coalesce(.data$psd_exports_world_source, .data$psd_production_world_source),
      psd_row_construction_components = dplyr::coalesce(.data$psd_exports_construction_components, .data$psd_production_construction_components)
    ) %>%
    arrange(.data$market_year, .data$analysis_month, .data$country)
  log_perf(
    "prepare_psd_app_marketing_year_data(): join_and_reshape",
    join_start_time,
    details = list(rows = nrow(out), cols = ncol(out))
  )

  basis_fill_start_time <- Sys.time()
  if (!identical(psd_basis_profile, "shelled_basis")) {
    out$psd_milling_rate <- suppressWarnings(as.numeric(out$psd_milling_rate))
    rough_from_milled_multiplier <- ifelse(
      !is.na(out$psd_milling_rate) & is.finite(out$psd_milling_rate) & out$psd_milling_rate > 0,
      10000 / out$psd_milling_rate,
      NA_real_
    )

    for (metric_col in psd_basis_pair_metric_cols) {
      companion_col <- paste0(metric_col, "_rough_eq")
      if (!(companion_col %in% names(out))) {
        out[[companion_col]] <- NA_real_
      }

      metric_values <- suppressWarnings(as.numeric(out[[metric_col]]))
      computed_rough_values <- metric_values * rough_from_milled_multiplier
      precomputed_rough_values <- suppressWarnings(as.numeric(out[[companion_col]]))
      out[[companion_col]] <- dplyr::coalesce(precomputed_rough_values, computed_rough_values)
    }

    out$psd_area_harvested_rough_eq <- dplyr::coalesce(
      suppressWarnings(as.numeric(out$psd_area_harvested_rough_eq)),
      suppressWarnings(as.numeric(out$psd_area_harvested))
    )

    native_yield_rough_values <- suppressWarnings(as.numeric(out$psd_yield))
    milled_from_rough_multiplier <- ifelse(
      !is.na(out$psd_milling_rate) & is.finite(out$psd_milling_rate) & out$psd_milling_rate > 0,
      out$psd_milling_rate / 10000,
      NA_real_
    )
    precomputed_milled_yield_values <- if ("psd_yield_milled_eq_prepped" %in% names(out)) {
      suppressWarnings(as.numeric(out$psd_yield_milled_eq_prepped))
    } else {
      rep(NA_real_, nrow(out))
    }

    out$psd_yield_rough_eq <- native_yield_rough_values
    out$psd_yield <- dplyr::coalesce(precomputed_milled_yield_values, native_yield_rough_values * milled_from_rough_multiplier)
  }
  log_perf(
    "prepare_psd_app_marketing_year_data(): basis_fill",
    basis_fill_start_time,
    details = list(rows = nrow(out), basis_profile = psd_basis_profile, basis_pair_cols = length(psd_basis_pair_metric_cols))
  )

  log_perf(
    "prepare_psd_app_marketing_year_data()",
    start_time,
    details = list(rows = nrow(out), cols = ncol(out))
  )

  out
}

prepare_psd_app_monthly_data <- function(psd_long_data) {
  prepare_psd_app_marketing_year_data(psd_long_data)
}

hybrid_init_start_time <- Sys.time()
rice_data_hybrid_monthly <- load_startup_dataset_for_source(
  source_family = "hybrid",
  dataset_name = "hybrid_monthly",
  tag = "hybrid_data_init(load_monthly)",
  artifact_path = hybrid_monthly_prepped_path,
  source_paths = startup_source_paths("hybrid", c(monthly_path, weekly_path, census_exports_path)),
  extra_signatures = artifact_extra_signatures("hybrid_monthly"),
  fallback_loader = function() load_hybrid_monthly_data(hybrid_monthly_path),
  disabled_loader = empty_monthly_source_dataset
)
rice_data_hybrid_monthly_fiscal <- load_startup_dataset_for_source(
  source_family = "hybrid",
  dataset_name = "hybrid_monthly_fiscal",
  tag = "hybrid_data_init(load_monthly_fiscal)",
  artifact_path = hybrid_monthly_fiscal_prepped_path,
  source_paths = startup_source_paths("hybrid", c(monthly_path, weekly_path, census_exports_path)),
  extra_signatures = artifact_extra_signatures("hybrid_monthly_fiscal"),
  fallback_loader = function() {
    materialize_non_psd_monthly_fiscal_data(
      rice_data_hybrid_monthly,
      source_choice = "hybrid"
    )
  },
  disabled_loader = empty_monthly_source_dataset
)
rice_data_hybrid_import_monthly <- load_startup_dataset_for_source(
  source_family = "hybrid",
  dataset_name = "hybrid_import_monthly",
  tag = "hybrid_data_init(load_import_monthly)",
  artifact_path = hybrid_import_monthly_prepped_path,
  source_paths = startup_source_paths("hybrid", c(census_imports_path)),
  extra_signatures = artifact_extra_signatures("hybrid_import_monthly"),
  fallback_loader = function() load_hybrid_monthly_data(hybrid_import_monthly_path),
  disabled_loader = empty_monthly_source_dataset
)
rice_data_hybrid_import_monthly_fiscal <- load_startup_dataset_for_source(
  source_family = "hybrid",
  dataset_name = "hybrid_import_monthly_fiscal",
  tag = "hybrid_data_init(load_import_monthly_fiscal)",
  artifact_path = hybrid_import_monthly_fiscal_prepped_path,
  source_paths = startup_source_paths("hybrid", c(census_imports_path)),
  extra_signatures = artifact_extra_signatures("hybrid_import_monthly_fiscal"),
  fallback_loader = function() {
    materialize_non_psd_monthly_fiscal_data(
      rice_data_hybrid_import_monthly,
      source_choice = "hybrid"
    )
  },
  disabled_loader = empty_monthly_source_dataset
)
rice_data_hybrid_weekly_imputed <- load_startup_dataset_for_source(
  source_family = "hybrid",
  dataset_name = "hybrid_weekly_imputed",
  tag = "hybrid_data_init(load_weekly)",
  artifact_path = hybrid_weekly_imputed_prepped_path,
  source_paths = startup_source_paths("hybrid", c(monthly_path, weekly_path, census_exports_path)),
  extra_signatures = artifact_extra_signatures("hybrid_weekly_imputed"),
  fallback_loader = function() load_hybrid_weekly_imputed_data(hybrid_weekly_imputed_path),
  disabled_loader = function() {
    empty_weekly_export_sales_dataset(include_all_na_group_flag = FALSE)
  }
)
rice_data_hybrid_weekly_imputed_fiscal <- load_startup_dataset_for_source(
  source_family = "hybrid",
  dataset_name = "hybrid_weekly_imputed_fiscal",
  tag = "hybrid_data_init(load_weekly_fiscal)",
  artifact_path = hybrid_weekly_imputed_fiscal_prepped_path,
  source_paths = startup_source_paths("hybrid", c(monthly_path, weekly_path, census_exports_path)),
  extra_signatures = artifact_extra_signatures("hybrid_weekly_imputed_fiscal"),
  fallback_loader = function() materialize_hybrid_weekly_imputed_fiscal_data(rice_data_hybrid_weekly_imputed),
  disabled_loader = function() {
    empty_weekly_export_sales_dataset(include_all_na_group_flag = FALSE)
  }
)
log_perf(
  "hybrid_data_init(load)",
  hybrid_init_start_time,
  details = list(
    monthly_rows = nrow(rice_data_hybrid_monthly),
    monthly_fiscal_rows = nrow(rice_data_hybrid_monthly_fiscal),
    import_monthly_rows = nrow(rice_data_hybrid_import_monthly),
    import_monthly_fiscal_rows = nrow(rice_data_hybrid_import_monthly_fiscal),
    weekly_rows = nrow(rice_data_hybrid_weekly_imputed),
    weekly_fiscal_rows = nrow(rice_data_hybrid_weekly_imputed_fiscal)
  )
)

psd_init_start_time <- Sys.time()
rice_data_psd_long <- load_startup_dataset_for_source(
  source_family = "psd",
  dataset_name = "psd_marketing_year_long",
  tag = "psd_data_init(load_long)",
  artifact_path = psd_marketing_year_prepped_path,
  source_paths = startup_source_paths("psd", c(psd_raw_path, psd_metadata_path)),
  extra_signatures = artifact_extra_signatures("psd_marketing_year_long"),
  fallback_loader = function() {
    load_psd_marketing_year_data(
      path = psd_raw_path,
      metadata_path = psd_metadata_path,
      country_canonical_map = country_canonical_map
    )
  },
  disabled_loader = empty_marketing_year_source_dataset
)
rice_data_psd_marketing_year <- if (startup_source_enabled("psd")) {
  prepare_psd_app_marketing_year_data(rice_data_psd_long)
} else {
  empty_marketing_year_source_dataset()
}
log_perf(
  "psd_data_init(load)",
  psd_init_start_time,
  details = list(
    long_rows = nrow(rice_data_psd_long),
      marketing_year_rows = nrow(rice_data_psd_marketing_year)
  )
)

wasde_init_start_time <- Sys.time()
rice_data_wasde_marketing_year <- load_startup_dataset_for_source(
  source_family = "wasde",
  dataset_name = "wasde_marketing_year",
  tag = "wasde_data_init(load)",
  artifact_path = wasde_marketing_year_prepped_path,
  source_paths = startup_source_paths("wasde", c(wasde_raw_path)),
  extra_signatures = artifact_extra_signatures("wasde_marketing_year"),
  fallback_loader = function() {
    load_wasde_marketing_year_data(
      path = wasde_raw_path,
      country_canonical_map = country_canonical_map
    )
  },
  disabled_loader = empty_marketing_year_source_dataset
)
log_perf(
  "wasde_data_init(load)",
  wasde_init_start_time,
  details = list(rows = nrow(rice_data_wasde_marketing_year))
)

nass_init_start_time <- Sys.time()
rice_data_nass_annual <- load_startup_dataset_for_source(
  source_family = "nass",
  dataset_name = "nass_annual",
  tag = "nass_data_init(load_annual)",
  artifact_path = nass_annual_prepped_path,
  source_paths = startup_source_paths("nass", nass_raw_path),
  extra_signatures = artifact_extra_signatures("nass_annual"),
  fallback_loader = function() {
    if (!file.exists(nass_processed_csv_path)) stop(sprintf("NASS processed CSV not found: %s", nass_processed_csv_path), call. = FALSE)
    read.csv(nass_processed_csv_path, stringsAsFactors = FALSE, check.names = FALSE)
  },
  disabled_loader = empty_nass_annual_source_dataset
)
rice_data_nass_state_lookup <- load_startup_dataset_for_source(
  source_family = "nass",
  dataset_name = "nass_state_lookup",
  tag = "nass_data_init(load_state_lookup)",
  artifact_path = nass_state_lookup_prepped_path,
  source_paths = startup_source_paths("nass", nass_raw_path),
  extra_signatures = artifact_extra_signatures("nass_state_lookup"),
  fallback_loader = function() {
    stop("Current NASS state lookup artifact is required when NASS is enabled.", call. = FALSE)
  },
  disabled_loader = empty_nass_state_lookup_dataset
)
rice_data_nass_shellout_factors <- load_startup_dataset_for_source(
  source_family = "nass",
  dataset_name = "nass_shellout_factors",
  tag = "nass_data_init(load_shellout_factors)",
  artifact_path = nass_shellout_factors_prepped_path,
  source_paths = startup_source_paths("nass", nass_raw_path),
  extra_signatures = artifact_extra_signatures("nass_shellout_factors"),
  fallback_loader = function() {
    stop("Current NASS shell-out factor artifact is required when NASS is enabled.", call. = FALSE)
  },
  disabled_loader = empty_nass_shellout_factor_dataset
)
log_perf(
  "nass_data_init(load)",
  nass_init_start_time,
  details = list(
    annual_rows = nrow(rice_data_nass_annual),
    state_lookup_rows = nrow(rice_data_nass_state_lookup),
    shellout_factor_rows = nrow(rice_data_nass_shellout_factors)
  )
)

required_internal_metric_cols <- c(
  "monthlyexports", "monthlyexports_rough_eq",
  "ytd_exports", "ytd_exports_rough_eq",
  "total_commitment", "total_commitment_rough_eq",
  "outstandingSales", "outstandingSales_rough_eq",
  "grossNewSales", "grossNewSales_rough_eq",
  "currentMYNetSales", "currentMYNetSales_rough_eq",
  "nextMYOutstandingSales", "nextMYOutstandingSales_rough_eq",
  "nextMYNetSales", "nextMYNetSales_rough_eq"
)

required_census_internal_metric_cols <- c(
  required_internal_metric_cols,
  "monthlyvalue", "monthlyvalue_rough_eq",
  "ytd_value", "ytd_value_rough_eq"
)

required_psd_internal_metric_cols <- c(
  "country_source_code",
  unname(psd_metric_column_map),
  if (identical(startup_psd_basis_profile(), "shelled_basis")) {
    character()
  } else {
    c("psd_milling_rate", paste0(psd_basis_pair_metric_cols, "_rough_eq"))
  }
)

startup_stage_start_time <- Sys.time()
assert_dataset_columns(rice_data_weekly, required_internal_metric_cols, "rice_data_weekly")
assert_dataset_columns(rice_data_monthly, required_monthly_source_cols, "rice_data_monthly")
assert_dataset_columns(rice_data_monthly_fiscal, required_monthly_source_cols, "rice_data_monthly_fiscal")
assert_dataset_columns(rice_data_vp_trade_monthly, required_census_internal_metric_cols, "rice_data_vp_trade_monthly")
assert_dataset_columns(rice_data_census_monthly, required_census_internal_metric_cols, "rice_data_census_monthly")
assert_dataset_columns(rice_data_census_monthly_fiscal, required_census_internal_metric_cols, "rice_data_census_monthly_fiscal")
assert_dataset_columns(rice_data_census_imports_monthly, required_census_internal_metric_cols, "rice_data_census_imports_monthly")
assert_dataset_columns(rice_data_census_imports_monthly_fiscal, required_census_internal_metric_cols, "rice_data_census_imports_monthly_fiscal")
assert_dataset_columns(rice_data_hybrid_monthly, c(required_census_internal_metric_cols, required_hybrid_provenance_cols), "rice_data_hybrid_monthly")
assert_dataset_columns(rice_data_hybrid_monthly_fiscal, c(required_census_internal_metric_cols, required_hybrid_provenance_cols), "rice_data_hybrid_monthly_fiscal")
assert_dataset_columns(rice_data_hybrid_import_monthly, c(required_census_internal_metric_cols, required_hybrid_provenance_cols), "rice_data_hybrid_import_monthly")
assert_dataset_columns(rice_data_hybrid_import_monthly_fiscal, c(required_census_internal_metric_cols, required_hybrid_provenance_cols), "rice_data_hybrid_import_monthly_fiscal")
assert_dataset_columns(rice_data_hybrid_weekly_imputed, c(required_census_internal_metric_cols, required_hybrid_provenance_cols, required_hybrid_weekly_metadata_cols), "rice_data_hybrid_weekly_imputed")
assert_dataset_columns(rice_data_psd_marketing_year, required_psd_internal_metric_cols, "rice_data_psd_marketing_year")
assert_dataset_columns(rice_data_wasde_marketing_year, wasde_required_processed_cols, "rice_data_wasde_marketing_year")
assert_dataset_columns(rice_data_nass_annual, names(empty_nass_annual_source_dataset()), "rice_data_nass_annual")
assert_dataset_columns(rice_data_nass_state_lookup, names(empty_nass_state_lookup_dataset()), "rice_data_nass_state_lookup")
assert_dataset_columns(rice_data_nass_shellout_factors, names(empty_nass_shellout_factor_dataset()), "rice_data_nass_shellout_factors")
log_perf(
  "startup_init(assert_internal_columns)",
  startup_stage_start_time,
  details = list(datasets = 17)
)

# Get unique values for filters (from monthly data)
startup_stage_start_time <- Sys.time()
native_commodities_vp_trade <- sort(unique(rice_data_vp_trade_monthly$commodity))
native_commodities_monthly <- if (startup_source_enabled("vp_trade")) native_commodities_vp_trade else sort(unique(rice_data_monthly$commodity))
native_commodities_weekly <- if (startup_source_enabled("vp_trade")) native_commodities_vp_trade else sort(unique(rice_data_weekly$commodity))
census_product_choices_for_rows <- function(rows, flow) {
  choices <- startup_commodity_contract$census$flows[[flow]]$product_choices %||% character()
  if (!is.data.frame(rows) || !"commodity" %in% names(rows)) {
    return(choices[0L])
  }

  available_values <- unique(trimws(as.character(rows$commodity)))
  choices[unname(choices) %in% available_values]
}
native_commodities_census_exports <- census_product_choices_for_rows(rice_data_census_monthly, "exports")
native_commodities_census_imports <- census_product_choices_for_rows(rice_data_census_imports_monthly, "imports")
native_commodities_census <- native_commodities_census_exports
native_commodities_psd <- c(COMMODITY_AGGREGATE_LABEL)
native_commodities_wasde <- c("All Rice", "Medium and Short Grain", "Long Grain")
native_commodities_hybrid_export <- c(
  "All Rice",
  "Rough Rice",
  "Milled Rice",
  "Rough Rice, MSG",
  "Rough Rice, Long Grain",
  "Milled, MSG",
  "Milled, Long Grain",
  "Medium/Short Grain (MSG)",
  "Long Grain"
)
native_commodities_hybrid_import <- c(
  "All Rice",
  "Medium/Short Grain (MSG)",
  "Long Grain"
)
hybrid_import_commodity_display_labels <- stats::setNames(character(), character())
native_commodities_hybrid <- native_commodities_hybrid_export
native_hybrid_parent_children_map <- list(
  "All Rice" = c("Rough Rice", "Milled Rice"),
  "Rough Rice" = c("Rough Rice, MSG", "Rough Rice, Long Grain"),
  "Milled Rice" = c("Milled, MSG", "Milled, Long Grain")
)
native_hybrid_nodes <- unique(c(
  names(native_hybrid_parent_children_map),
  unlist(native_hybrid_parent_children_map, use.names = FALSE)
))
native_hybrid_child_parent_map <- stats::setNames(
  rep(names(native_hybrid_parent_children_map), lengths(native_hybrid_parent_children_map)),
  unlist(native_hybrid_parent_children_map, use.names = FALSE)
)
native_hybrid_leaf_descendants_map <- local({
  descendant_map <- list()

  collect_leaf_descendants <- function(node_name) {
    child_nodes <- native_hybrid_parent_children_map[[node_name]]
    if (is.null(child_nodes) || length(child_nodes) == 0) {
      return(node_name)
    }

    unique(unlist(lapply(child_nodes, collect_leaf_descendants), use.names = FALSE))
  }

  for (node_name in native_hybrid_nodes) {
    descendant_map[[node_name]] <- collect_leaf_descendants(node_name)
  }

  descendant_map
})
native_hybrid_leaf_nodes <- sort(unique(unlist(native_hybrid_leaf_descendants_map, use.names = FALSE)))
native_hybrid_non_root_family_nodes <- setdiff(names(native_hybrid_parent_children_map), "All Rice")

native_hybrid_export_rollup_leaf_sets <- c(
  native_hybrid_leaf_descendants_map,
  list(
    "Medium/Short Grain (MSG)" = c("Rough Rice, MSG", "Milled, MSG"),
    "Long Grain" = c("Rough Rice, Long Grain", "Milled, Long Grain")
  )
)
native_hybrid_export_nodes <- unique(names(native_hybrid_export_rollup_leaf_sets))
native_hybrid_export_leaf_nodes <- native_hybrid_leaf_nodes
native_hybrid_export_parent_nodes <- setdiff(native_hybrid_export_nodes, native_hybrid_export_leaf_nodes)
native_hybrid_export_non_root_family_nodes <- setdiff(native_hybrid_export_parent_nodes, "All Rice")

get_native_hybrid_leaf_descendants <- function(node_name) {
  descendants <- native_hybrid_leaf_descendants_map[[node_name]]
  if (is.null(descendants)) character(0) else unique(descendants)
}

get_native_hybrid_export_leaf_descendants <- function(node_name) {
  descendants <- native_hybrid_export_rollup_leaf_sets[[node_name]]
  if (is.null(descendants)) character(0) else unique(descendants)
}

get_native_hybrid_parent <- function(node_name) {
  parent_name <- native_hybrid_child_parent_map[[node_name]]
  if (is.null(parent_name)) NA_character_ else parent_name
}

is_native_hybrid_node <- function(node_name) {
  !is.null(node_name) && length(node_name) == 1 && !is.na(node_name) && node_name %in% native_hybrid_nodes
}

is_native_hybrid_leaf <- function(node_name) {
  !is.null(node_name) && length(node_name) == 1 && !is.na(node_name) && node_name %in% native_hybrid_leaf_nodes
}

is_native_hybrid_export_node <- function(node_name) {
  !is.null(node_name) && length(node_name) == 1 && !is.na(node_name) && node_name %in% native_hybrid_export_nodes
}

is_native_hybrid_export_leaf <- function(node_name) {
  !is.null(node_name) && length(node_name) == 1 && !is.na(node_name) && node_name %in% native_hybrid_export_leaf_nodes
}

get_native_hybrid_export_family_parents <- function(node_name) {
  if (!is_native_hybrid_export_node(node_name)) return(character(0))
  node_leaves <- get_native_hybrid_export_leaf_descendants(node_name)
  if (length(node_leaves) == 0) return(character(0))

  parents <- native_hybrid_export_non_root_family_nodes[vapply(native_hybrid_export_non_root_family_nodes, function(parent_name) {
    parent_leaves <- get_native_hybrid_export_leaf_descendants(parent_name)
    length(parent_leaves) > 0 && all(node_leaves %in% parent_leaves)
  }, logical(1))]

  unique(parents)
}

get_native_hybrid_family_parent <- function(node_name) {
  if (!is_native_hybrid_node(node_name)) return(NA_character_)
  if (node_name %in% native_hybrid_non_root_family_nodes) return(node_name)

  parent_name <- get_native_hybrid_parent(node_name)
  if (is.na(parent_name) || identical(parent_name, "All Rice")) {
    return(NA_character_)
  }

  parent_name
}
native_commodities_all <- sort(unique(c(native_commodities_monthly, native_commodities_weekly)))
unique_commodities <- native_commodities_monthly

normalize_country_display_label <- function(label_value) {
  cleaned_label <- trimws(as.character(label_value))
  cleaned_label[!nzchar(cleaned_label)] <- NA_character_

  normalized_label <- canonical_country_label_from_code(cleaned_label)
  normalized_label[cleaned_label %in% c("WORLD", "World", "GRAND_TOTAL", "Grand Total", "GRAND TOTAL")] <- "World"
  normalized_label
}

choose_lookup_country_label <- function(country_code, country_labels, canonical_label_lookup) {
  cleaned_code <- trimws(as.character(country_code[[1]]))

  if (!nzchar(cleaned_code) || is.na(cleaned_code)) {
    return(NA_character_)
  }

  if (identical(cleaned_code, "GRAND_TOTAL")) {
    return("World")
  }

  canonical_candidate <- unname(canonical_label_lookup[cleaned_code])
  canonical_candidate <- normalize_country_display_label(canonical_candidate)
  canonical_candidate <- canonical_candidate[!is.na(canonical_candidate) & nzchar(canonical_candidate)]
  if (length(canonical_candidate) > 0) {
    return(canonical_candidate[[1]])
  }

  normalized_candidates <- normalize_country_display_label(country_labels)
  normalized_candidates <- unique(normalized_candidates[!is.na(normalized_candidates) & nzchar(normalized_candidates)])
  if (length(normalized_candidates) > 0) {
    return(normalized_candidates[order(nchar(normalized_candidates), normalized_candidates)][[1]])
  }

  fallback_label <- canonical_country_label_from_code(cleaned_code)
  if (is.na(fallback_label) || !nzchar(fallback_label)) {
    cleaned_code
  } else {
    fallback_label
  }
}

choose_lookup_country_code <- function(country_codes, source_priorities = NULL) {
  cleaned_codes <- trimws(as.character(country_codes))
  cleaned_codes <- cleaned_codes[!is.na(cleaned_codes) & nzchar(cleaned_codes)]

  if (length(cleaned_codes) == 0) {
    return(NA_character_)
  }

  if ("GRAND_TOTAL" %in% cleaned_codes) {
    return("GRAND_TOTAL")
  }

  if (is.null(source_priorities)) {
    source_priorities <- rep.int(Inf, length(cleaned_codes))
  }

  priority_values <- suppressWarnings(as.integer(source_priorities))
  priority_values[is.na(priority_values)] <- .Machine$integer.max

  choice_df <- data.frame(
    country = cleaned_codes,
    source_priority = priority_values,
    stringsAsFactors = FALSE
  )
  choice_df <- choice_df[!duplicated(choice_df$country), , drop = FALSE]
  choice_df <- choice_df[order(choice_df$source_priority, nchar(choice_df$country), choice_df$country), , drop = FALSE]

  choice_df$country[[1]]
}

build_country_choice_rows <- function(data, source_priority) {
  data %>%
    transmute(
      country = as.character(.data$country),
      countryDescription = as.character(.data$countryDescription)
    ) %>%
    filter(!is.na(.data$country), nzchar(.data$country)) %>%
    distinct(country, countryDescription) %>%
    mutate(source_priority = source_priority)
}

choose_context_country_code <- function(country_codes) {
  unique_codes <- unique(trimws(as.character(country_codes)))
  unique_codes <- unique_codes[nzchar(unique_codes)]

  if (length(unique_codes) == 0) return(NA_character_)
  if ("GRAND_TOTAL" %in% unique_codes) return("GRAND_TOTAL")

  unique_codes[order(-nchar(unique_codes), unique_codes)][1]
}

choose_context_country_label <- function(country_labels) {
  unique_labels <- unique(trimws(as.character(country_labels)))
  unique_labels <- unique_labels[nzchar(unique_labels)]

  if (length(unique_labels) == 0) return(NA_character_)
  if ("World" %in% unique_labels) return("World")

  unique_labels[order(nchar(unique_labels), unique_labels)][1]
}

build_context_country_display_names <- function(choice_rows, display_lookup) {
  if (is.null(choice_rows) || !is.data.frame(choice_rows) || nrow(choice_rows) == 0) {
    return(stats::setNames(character(), character()))
  }

  country <- trimws(as.character(choice_rows$country))
  country[is.na(country)] <- ""
  country_description <- trimws(as.character(choice_rows$countryDescription))
  country_description[is.na(country_description)] <- ""

  display_idx <- country %in% names(display_lookup)
  if (any(display_idx)) {
    country_description[display_idx] <- unname(display_lookup[country[display_idx]])
  }

  empty_description_idx <- is.na(country_description) | !nzchar(country_description)
  country_description[empty_description_idx] <- country[empty_description_idx]
  country_description[country == "GRAND_TOTAL"] <- "World"

  keep_idx <- !is.na(country) & nzchar(country) & !is.na(country_description) & nzchar(country_description)
  if (!any(keep_idx)) {
    return(stats::setNames(character(), character()))
  }

  pair_df <- unique(data.frame(
    country = country[keep_idx],
    countryDescription = country_description[keep_idx],
    stringsAsFactors = FALSE
  ))

  country_by_label <- vapply(
    split(pair_df$country, pair_df$countryDescription),
    choose_context_country_code,
    character(1)
  )
  label_df <- data.frame(
    countryDescription = names(country_by_label),
    country = unname(country_by_label),
    stringsAsFactors = FALSE
  )

  label_by_country <- vapply(
    split(label_df$countryDescription, label_df$country),
    choose_context_country_label,
    character(1)
  )
  out_df <- data.frame(
    country = names(label_by_country),
    countryDescription = unname(label_by_country),
    stringsAsFactors = FALSE
  )
  out_df <- out_df[order(out_df$countryDescription, out_df$country), , drop = FALSE]

  stats::setNames(out_df$country, out_df$countryDescription)
}

app_ui_metadata_country_rows <- function(source_data) {
  if (!is.data.frame(source_data) || nrow(source_data) == 0L || !all(c("country", "countryDescription") %in% names(source_data))) {
    return(data.frame(country = character(), countryDescription = character(), stringsAsFactors = FALSE))
  }

  source_data %>%
    transmute(
      country = trimws(as.character(.data$country)),
      countryDescription = trimws(as.character(.data$countryDescription))
    ) %>%
    filter(!is.na(.data$country), nzchar(.data$country)) %>%
    distinct(.data$country, .data$countryDescription) %>%
    as.data.frame(stringsAsFactors = FALSE)
}

build_app_ui_metadata_source_datasets <- function() {
  source_specs <- list(
    vp_trade = list(source_family = "vp_trade", data = rice_data_vp_trade_monthly, source_priority = 1L),
    psd = list(source_family = "psd", data = rice_data_psd_long, source_priority = 1L),
    nass = list(source_family = "nass", data = rice_data_nass_annual, source_priority = 1L),
    wasde = list(source_family = "wasde", data = rice_data_wasde_marketing_year, source_priority = 1L),
    census_export = list(source_family = "census_exports", data = rice_data_census_monthly, source_priority = 2L),
    census_import = list(source_family = "census_imports", data = rice_data_census_imports_monthly, source_priority = 2L),
    export_sales_monthly = list(source_family = "export_sales", data = rice_data_monthly, source_priority = 3L),
    export_sales_weekly = list(source_family = "export_sales", data = rice_data_weekly, source_priority = 3L),
    hybrid_export_monthly = list(source_family = "hybrid", data = rice_data_hybrid_monthly, source_priority = 4L),
    hybrid_import_monthly = list(source_family = "hybrid", data = rice_data_hybrid_import_monthly, source_priority = 4L),
    hybrid_weekly_imputed = list(source_family = "hybrid", data = rice_data_hybrid_weekly_imputed, source_priority = 4L)
  )

  enabled_specs <- source_specs[vapply(source_specs, function(source_spec) {
    startup_source_enabled(source_spec$source_family)
  }, logical(1))]

  stats::setNames(lapply(enabled_specs, function(source_spec) {
    list(
      data = app_ui_metadata_country_rows(source_spec$data),
      source_priority = source_spec$source_priority
    )
  }), names(enabled_specs))
}

build_runtime_app_ui_source_country_map <- function(source_datasets) {
  if (length(source_datasets) == 0L) return(empty_country_canonical_map())

  source_rows <- dplyr::bind_rows(lapply(names(source_datasets), function(source_name) {
    source_data <- source_datasets[[source_name]]$data
    if (!is.data.frame(source_data) || nrow(source_data) == 0L || !all(c("country", "countryDescription") %in% names(source_data))) {
      return(empty_country_canonical_map())
    }

    source_label <- trimws(as.character(source_data$countryDescription))
    if (isTRUE(app_ui_source_should_strip_country_code_prefix(source_name))) {
      source_label <- strip_app_ui_census_country_code_prefix(source_label)
    }
    source_data$countryDescription <- source_label

    source_data %>%
      dplyr::transmute(
        source = source_name,
        legacy_country_code = trimws(as.character(.data$country)),
        legacy_country_label = trimws(as.character(.data$countryDescription)),
        mapping_source_country_code = trimws(as.character(.data$country)),
        canonical_country_code = trimws(as.character(.data$country)),
        canonical_country_label = trimws(as.character(.data$countryDescription)),
        canonical_review_row_id = paste("RUNTIME_APP_UI_METADATA_SOURCE", source_name, trimws(as.character(.data$country)), sep = ":")
      )
  }))

  standardize_country_canonical_map(source_rows)
}

compose_runtime_app_ui_country_canonical_map <- function(source_datasets) {
  source_map <- build_runtime_app_ui_source_country_map(source_datasets)
  if (!is.data.frame(country_canonical_map) || nrow(country_canonical_map) == 0L) return(source_map)
  if (!is.data.frame(source_map) || nrow(source_map) == 0L) return(country_canonical_map)

  configured_keys <- paste(country_canonical_map$source, country_canonical_map$legacy_country_code, sep = "\r")
  source_keys <- paste(source_map$source, source_map$legacy_country_code, sep = "\r")
  source_missing_from_config <- source_map[!(source_keys %in% configured_keys), , drop = FALSE]
  standardize_country_canonical_map(dplyr::bind_rows(country_canonical_map, source_missing_from_config))
}

build_runtime_app_ui_metadata <- function() {
  source_datasets <- build_app_ui_metadata_source_datasets()
  materialize_app_ui_metadata(
    country_canonical_map = compose_runtime_app_ui_country_canonical_map(source_datasets),
    source_datasets = source_datasets
  )
}

empty_app_ui_metadata <- function() {
  list(
    country_canonical_label_lookup = stats::setNames(character(), character()),
    country_choice_row_sources = tibble::tibble(),
    country_choice_label_rows = tibble::tibble(),
    country_choices_all = tibble::tibble(),
    country_display_names = stats::setNames(character(), character()),
    country_display_name_lookup = stats::setNames(character(), character()),
    country_display_name_context_keys = character()
  )
}

load_app_ui_metadata_for_startup <- function() {
  if (length(app_ui_metadata_source_paths) == 0L) {
    metadata <- empty_app_ui_metadata()
    record_startup_data_load_mode(
      dataset_name = "app_ui_metadata",
      mode = "contract_disabled",
      artifact_path = app_ui_metadata_prepped_path,
      source_paths = character(),
      rows = startup_object_row_count(metadata),
      cols = startup_object_col_count(metadata),
      currentity_current = NA,
      currentity_reason = "all_metadata_sources_contract_disabled"
    )
    return(metadata)
  }

  load_processed_or_csv_dataset(
    dataset_name = "app_ui_metadata",
    tag = "startup_init(load_app_ui_metadata)",
    artifact_path = app_ui_metadata_prepped_path,
    source_paths = app_ui_metadata_source_paths,
    fallback_loader = build_runtime_app_ui_metadata,
    extra_signatures = artifact_extra_signatures("app_ui_metadata")
  )
}

display_lookup_start_time <- Sys.time()
app_ui_metadata <- load_app_ui_metadata_for_startup()

app_ui_metadata_required_fields <- c(
  "country_canonical_label_lookup",
  "country_choice_row_sources",
  "country_choice_label_rows",
  "country_choices_all",
  "country_display_names",
  "country_display_name_lookup",
  "country_display_name_context_keys"
)
if (!is.list(app_ui_metadata) || any(!app_ui_metadata_required_fields %in% names(app_ui_metadata))) {
  stop("App UI metadata artifact is missing required country lookup fields.", call. = FALSE)
}

country_canonical_label_lookup <- app_ui_metadata$country_canonical_label_lookup
country_choice_row_sources <- app_ui_metadata$country_choice_row_sources
country_choice_label_rows <- app_ui_metadata$country_choice_label_rows
country_choices_all <- app_ui_metadata$country_choices_all
country_display_names <- app_ui_metadata$country_display_names
country_display_name_lookup <- app_ui_metadata$country_display_name_lookup
country_display_name_context_keys <- app_ui_metadata$country_display_name_context_keys

app_ui_metadata_load_mode <- "unknown"
app_ui_metadata_load_entry <- startup_data_load_modes[["app_ui_metadata"]]
if (is.list(app_ui_metadata_load_entry) && !is.null(app_ui_metadata_load_entry$mode)) {
  app_ui_metadata_load_mode <- as.character(app_ui_metadata_load_entry$mode[[1]])
}

log_perf(
  "startup_init(build_display_lookups:country_choice_rows)",
  display_lookup_start_time,
  details = list(
    countries = nrow(country_choices_all),
    canonical_rows = length(country_canonical_label_lookup),
    context_maps = length(country_display_name_context_keys),
    metadata_mode = app_ui_metadata_load_mode
  )
)

display_lookup_start_time <- Sys.time()
country_display_names_by_context <- new.env(parent = emptyenv())
get_country_display_names_for_context <- function(context_key) {
  context_key <- trimws(as.character(context_key %||% ""))
  if (length(context_key) == 0 || !nzchar(context_key[[1]])) {
    return(stats::setNames(character(), character()))
  }
  context_key <- context_key[[1]]

  if (exists(context_key, envir = country_display_names_by_context, inherits = FALSE)) {
    return(get(context_key, envir = country_display_names_by_context, inherits = FALSE))
  }

  choice_rows <- country_choice_row_sources[[context_key]]
  result <- build_context_country_display_names(choice_rows, country_display_name_lookup)
  assign(context_key, result, envir = country_display_names_by_context)
  result
}
log_perf(
  "startup_init(build_display_lookups:display_name_maps)",
  display_lookup_start_time,
  details = list(
    country_codes = length(country_display_name_lookup),
    context_maps = length(country_display_name_context_keys),
    context_cache_mode = "lazy"
  )
)
log_perf(
  "startup_init(build_display_lookups)",
  startup_stage_start_time,
  details = list(countries = nrow(country_choices_all), commodities = length(native_commodities_all))
)

# Helper function to get display name for a country code
get_display_country <- function(country_code) {
  normalized_code <- trimws(as.character(country_code %||% ""))
  if (length(normalized_code) == 0 || !nzchar(normalized_code[[1]])) {
    return(country_code)
  }

  normalized_code <- normalized_code[[1]]
  if (isTRUE(is_custom_country_choice_value(normalized_code))) {
    parsed_custom_name <- parse_custom_country_choice_name(normalized_code)
    if (!is.null(parsed_custom_name) && nzchar(parsed_custom_name)) {
      return(parsed_custom_name)
    }
  }

  display_name <- unname(country_display_name_lookup[normalized_code])
  if (length(display_name) > 0 && !is.na(display_name[[1]]) && nzchar(display_name[[1]])) {
    return(display_name[[1]])
  }
  return(normalized_code)
}

# Month mapping for display (marketing year: August=1, September=2, ... July=12)
month_mapping <- tribble(
  ~analysis_month, ~month_name, ~month_abbrev,
  1, "August", "Aug",
  2, "September", "Sep",
  3, "October", "Oct",
  4, "November", "Nov",
  5, "December", "Dec",
  6, "January", "Jan",
  7, "February", "Feb",
  8, "March", "Mar",
  9, "April", "Apr",
  10, "May", "May",
  11, "June", "Jun",
  12, "July", "Jul"
)

build_default_weekly_x_axis_config <- function(max_week, axis_title = "Week Number", max_ticks = 12L) {
  max_week <- suppressWarnings(as.integer(max_week[[1]]))
  if (!is.finite(max_week) || is.na(max_week) || max_week < 1L) {
    max_week <- 1L
  }

  if (max_week <= max_ticks) {
    tick_positions <- seq_len(max_week)
  } else {
    step <- ceiling(max_week / (max_ticks - 1L))
    tick_positions <- unique(c(1L, seq.int(1L + step, max_week - 1L, by = step), max_week))
  }

  list(
    title = axis_title,
    tickvals = tick_positions,
    ticktext = paste0("W", tick_positions)
  )
}

build_weekly_x_axis_config_from_dates <- function(label_source_df,
                                                  axis_title = "Week Number",
                                                  month_label_style = c("abbrev", "full"),
                                                  include_latest_label = TRUE,
                                                  fallback_max_week = NULL,
                                                  year_type = "marketing") {
  month_label_style <- match.arg(month_label_style)
  effective_max_week <- suppressWarnings(as.integer(fallback_max_week[[1]]))
  resolved_year_type <- normalize_non_psd_year_type(year_type, default = "marketing")

  if (is.null(label_source_df) || nrow(label_source_df) == 0L) {
    return(build_default_weekly_x_axis_config(effective_max_week, axis_title = axis_title))
  }

  if (!("analysis_month" %in% names(label_source_df)) || !("week_ending_date" %in% names(label_source_df))) {
    return(build_default_weekly_x_axis_config(effective_max_week, axis_title = axis_title))
  }

  label_df <- label_source_df %>%
    transmute(
      analysis_month = suppressWarnings(as.integer(.data$analysis_month)),
      week_ending_date = as.Date(.data$week_ending_date)
    ) %>%
    filter(!is.na(.data$analysis_month), is.finite(.data$analysis_month)) %>%
    group_by(.data$analysis_month) %>%
    summarise(
      week_ending_date = if (all(is.na(.data$week_ending_date))) as.Date(NA) else max(.data$week_ending_date, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    arrange(.data$analysis_month)

  observed_max_week <- suppressWarnings(max(label_df$analysis_month, na.rm = TRUE))
  if (is.finite(observed_max_week) && !is.na(observed_max_week)) {
    if (!is.finite(effective_max_week) || is.na(effective_max_week)) {
      effective_max_week <- observed_max_week
    } else {
      effective_max_week <- max(effective_max_week, observed_max_week)
    }
  }

  if (nrow(label_df) == 0L) {
    return(build_default_weekly_x_axis_config(effective_max_week, axis_title = axis_title))
  }

  dated_labels <- label_df %>%
    filter(!is.na(.data$week_ending_date)) %>%
    mutate(
      month_key = format(.data$week_ending_date, "%Y-%m"),
      month_label = if (identical(month_label_style, "full")) {
        format(.data$week_ending_date, "%B")
      } else {
        format(.data$week_ending_date, "%b")
      },
      tick_label = paste0(.data$month_label, " (Week ", .data$analysis_month, ")")
    )

  month_ticks <- dated_labels %>%
    group_by(.data$month_key) %>%
    slice_min(order_by = .data$analysis_month, n = 1L, with_ties = FALSE) %>%
    ungroup() %>%
    select(analysis_month, tick_label)

  if (isTRUE(include_latest_label)) {
    latest_tick <- label_df %>%
      slice_max(order_by = .data$analysis_month, n = 1L, with_ties = FALSE)

    if (nrow(latest_tick) == 1L) {
      latest_date <- latest_tick$week_ending_date[[1]]
      latest_month_label <- if (!is.na(latest_date)) {
        if (identical(month_label_style, "full")) format(latest_date, "%B") else format(latest_date, "%b")
      } else {
        "Week"
      }

      latest_tick <- tibble(
        analysis_month = latest_tick$analysis_month,
        tick_label = paste0(latest_month_label, " (Week ", latest_tick$analysis_month, ")")
      )

      month_ticks <- bind_rows(month_ticks, latest_tick) %>%
        distinct(analysis_month, .keep_all = TRUE) %>%
        arrange(.data$analysis_month)
    }
  }

  if (is.finite(effective_max_week) && !is.na(effective_max_week) && effective_max_week >= 52L) {
    terminal_label <- if (identical(resolved_year_type, "fiscal")) {
      if (identical(month_label_style, "full")) {
        "September (Week 52)"
      } else {
        "Sep (Week 52)"
      }
    } else {
      if (identical(month_label_style, "full")) {
        "July (Week 52)"
      } else {
        "Jul (Week 52)"
      }
    }

    month_ticks <- bind_rows(
      month_ticks,
      tibble(
        analysis_month = 52L,
        tick_label = terminal_label
      )
    ) %>%
      distinct(analysis_month, .keep_all = TRUE) %>%
      arrange(.data$analysis_month)
  }

  if (nrow(month_ticks) == 0L) {
    fallback_week <- if (!is.null(effective_max_week) && is.finite(effective_max_week) && !is.na(effective_max_week)) effective_max_week else max(label_df$analysis_month, na.rm = TRUE)
    return(build_default_weekly_x_axis_config(fallback_week, axis_title = axis_title))
  }

  list(
    title = axis_title,
    tickvals = month_ticks$analysis_month,
    ticktext = month_ticks$tick_label
  )
}

harmonization_cache_mode <- dplyr::case_when(
  isFALSE(getOption("rice_use_canonical_country_map", TRUE)) ~ "canonical_map_disabled",
  harmonization_refresh_enabled() ~ "baseline_plus_refresh",
  TRUE ~ "baseline_only"
)

harmonization_cache_version_start_time <- Sys.time()
harmonization_cache_version <- paste(
  harmonization_cache_mode,
  build_file_signature(country_baseline_table_path),
  if (identical(harmonization_cache_mode, "baseline_plus_refresh")) build_file_signature(country_review_table_path) else "review_overlay_ignored",
  sep = "||"
)
log_perf(
  "startup_init(cache_setup:build_harmonization_cache_version)",
  harmonization_cache_version_start_time,
  details = list(
    mode = harmonization_cache_mode,
    review_overlay = identical(harmonization_cache_mode, "baseline_plus_refresh")
  )
)

cache_component_values <- function(values) {
  if (length(values) == 0) return("none")
  paste(as.character(values), collapse = "::")
}

cache_mode_field <- function(mode_entry, field_name) {
  field_value <- mode_entry[[field_name]]
  if (is.null(field_value)) return(character())
  unname(as.character(field_value))
}

build_file_metadata_cache_signature <- function(path) {
  if (!file.exists(path)) {
    return(paste("file", basename(path), "missing", sep = "|"))
  }

  file_info <- file.info(path)
  file_size <- suppressWarnings(as.numeric(file_info$size[[1]]))
  file_mtime <- suppressWarnings(as.numeric(file_info$mtime[[1]]))
  paste(
    "file",
    basename(path),
    "mtime_size",
    if (!is.na(file_mtime)) as.character(file_mtime) else "NA",
    if (!is.na(file_size)) as.character(file_size) else "NA",
    sep = "|"
  )
}

build_startup_dataset_cache_component <- function(dataset_name, fallback_paths = character()) {
  mode_entry <- startup_data_load_modes[[dataset_name]]

  if (is.null(mode_entry)) {
    fallback_signatures <- if (length(fallback_paths) > 0) {
      unname(vapply(fallback_paths, build_file_signature, character(1)))
    } else {
      character()
    }
    return(paste(dataset_name, "unloaded", cache_component_values(fallback_signatures), sep = "||"))
  }

  source_ids <- cache_mode_field(mode_entry, "currentity_source_ids")
  source_signatures <- cache_mode_field(mode_entry, "currentity_source_signatures")
  extra_signature_names <- cache_mode_field(mode_entry, "currentity_extra_signature_names")
  extra_signatures <- cache_mode_field(mode_entry, "currentity_extra_signatures")
  artifact_metadata <- build_file_metadata_cache_signature(as.character(mode_entry$artifact_path[[1]]))

  fallback_signatures <- character()
  if (!identical(as.character(mode_entry$mode[[1]]), "processed_artifact") || !isTRUE(mode_entry$currentity_current[[1]])) {
    fallback_signatures <- if (length(fallback_paths) > 0) {
      unname(vapply(fallback_paths, build_file_signature, character(1)))
    } else {
      character()
    }
  }

  paste(
    dataset_name,
    as.character(mode_entry$mode[[1]]),
    artifact_metadata,
    cache_component_values(source_ids),
    cache_component_values(source_signatures),
    cache_component_values(extra_signature_names),
    cache_component_values(extra_signatures),
    cache_component_values(fallback_signatures),
    as.character(mode_entry$rows[[1]]),
    as.character(mode_entry$cols[[1]]),
    sep = "||"
  )
}

startup_stage_start_time <- Sys.time()
cache_version_start_time <- Sys.time()
cache_schema_version <- "2026-07-vp-rollup-schema-v1"
cache_data_components <- c(
  build_startup_dataset_cache_component("weekly_export_sales", fallback_paths = weekly_path),
  build_startup_dataset_cache_component("weekly_export_sales_fiscal", fallback_paths = weekly_path),
  build_startup_dataset_cache_component("monthly_export_sales", fallback_paths = c(monthly_path, weekly_path)),
  build_startup_dataset_cache_component("vp_trade_monthly", fallback_paths = vp_trade_csv_path),
  build_startup_dataset_cache_component("census_exports_monthly", fallback_paths = census_exports_path),
  build_startup_dataset_cache_component("census_imports_monthly", fallback_paths = census_imports_path),
  build_startup_dataset_cache_component("hybrid_monthly", fallback_paths = hybrid_monthly_path),
  build_startup_dataset_cache_component("hybrid_import_monthly", fallback_paths = hybrid_import_monthly_path),
  build_startup_dataset_cache_component("hybrid_weekly_imputed", fallback_paths = hybrid_weekly_imputed_path),
  build_startup_dataset_cache_component("psd_marketing_year_long", fallback_paths = c(psd_raw_path, psd_metadata_path)),
  build_startup_dataset_cache_component("nass_annual", fallback_paths = nass_raw_path),
  build_startup_dataset_cache_component("nass_state_lookup", fallback_paths = nass_raw_path),
  build_startup_dataset_cache_component("nass_shellout_factors", fallback_paths = nass_raw_path),
  build_startup_dataset_cache_component("wasde_marketing_year", fallback_paths = wasde_raw_path),
  build_lazy_processed_artifact_cache_component(
    "wasde_release_history",
    artifact_path = wasde_release_history_prepped_path,
    source_paths = c(wasde_waob_release_history_raw_path),
    extra_signatures = artifact_extra_signatures("wasde_release_history")
  ),
  build_lazy_processed_artifact_cache_component(
    "wasde_revision_delta",
    artifact_path = wasde_revision_delta_prepped_path,
    source_paths = c(wasde_raw_path, wasde_waob_release_history_raw_path),
    extra_signatures = artifact_extra_signatures("wasde_revision_delta")
  ),
  build_lazy_processed_artifact_cache_component(
    "psd_revision_delta",
    artifact_path = psd_revision_delta_prepped_path,
    source_paths = psd_revision_delta_source_paths(),
    extra_signatures = psd_revision_delta_extra_signatures()
  ),
  build_lazy_processed_artifact_cache_component(
    "psd_historical_records",
    artifact_path = psd_historical_records_prepped_path,
    source_paths = c(psd_raw_path, psd_metadata_path),
    extra_signatures = artifact_extra_signatures("psd_historical_records")
  ),
  build_lazy_processed_artifact_cache_component(
    "nass_historical_records",
    artifact_path = nass_historical_records_prepped_path,
    source_paths = startup_source_paths("nass", nass_raw_path),
    extra_signatures = artifact_extra_signatures("nass_historical_records")
  ),
  build_lazy_processed_artifact_cache_component(
    "wasde_historical_records",
    artifact_path = wasde_historical_records_prepped_path,
    source_paths = c(wasde_raw_path),
    extra_signatures = artifact_extra_signatures("wasde_historical_records")
  ),
  harmonization_cache_version,
  build_file_signature(user_custom_types_path),
  build_file_signature(user_custom_countries_path),
  build_file_signature(vp_trade_metadata_prepped_path)
)
cache_data_version <- paste(cache_data_components, collapse = "||")
log_perf(
  "startup_init(cache_setup:build_cache_data_version)",
  cache_version_start_time,
  details = list(components = length(cache_data_components))
)

# Native caching for heavy renders
cache_backend_start_time <- Sys.time()
shinyOptions(cache = cachem::cache_disk(cache_dir))
log_perf(
  "startup_init(cache_setup:bind_cache_backend)",
  cache_backend_start_time,
  details = list(cache_dir = basename(cache_dir))
)
log_perf(
  "startup_init(cache_setup)",
  startup_stage_start_time,
  details = list(cache_schema_version = cache_schema_version)
)

log_perf(
  "startup_init(total_pre_ui)",
  global_startup_total_start_time,
  details = list(
    weekly_rows = nrow(rice_data_weekly),
    monthly_rows = nrow(rice_data_monthly),
    monthly_fiscal_rows = nrow(rice_data_monthly_fiscal),
    census_export_rows = nrow(rice_data_census_monthly),
    census_export_fiscal_rows = nrow(rice_data_census_monthly_fiscal),
    census_import_rows = nrow(rice_data_census_imports_monthly),
    census_import_fiscal_rows = nrow(rice_data_census_imports_monthly_fiscal),
    hybrid_rows = nrow(rice_data_hybrid_monthly),
    hybrid_fiscal_rows = nrow(rice_data_hybrid_monthly_fiscal),
    hybrid_import_rows = nrow(rice_data_hybrid_import_monthly),
    hybrid_import_fiscal_rows = nrow(rice_data_hybrid_import_monthly_fiscal)
  )
)

# UI ----

