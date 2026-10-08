`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0L) y else x
}

vp_perf_split_pipe_values <- function(value) {
  value <- trimws(as.character(value %||% ""))
  if (!nzchar(value)) return(character(0))
  parts <- strsplit(value, "\\|", fixed = FALSE)[[1L]]
  parts <- trimws(parts)
  parts[nzchar(parts)]
}

vp_perf_join_args <- function(args) {
  args <- as.character(args %||% character(0))
  if (length(args) == 0L) return("")
  paste(args, collapse = " ")
}

vp_perf_detect_provider_mode <- function() {
  env_mode <- trimws(Sys.getenv("VP_PARTITION_PROVIDER_MODE", unset = ""))
  if (nzchar(env_mode)) return(env_mode)

  option_mode <- trimws(as.character(getOption("vp_partition_provider_mode", "") %||% ""))
  if (nzchar(option_mode)) return(option_mode)

  lazy_env <- tolower(trimws(Sys.getenv("VP_LAZY_SIDECAR_MODE", unset = "false")))
  lazy_option <- isTRUE(getOption("vp_lazy_sidecar_mode", FALSE))
  if (lazy_option || identical(lazy_env, "true")) return("lazy_sidecar_candidate")

  "unspecified"
}

vp_perf_manifest_csv_path <- function(logs_dir, manifest_path_arg = "") {
  override <- trimws(as.character(manifest_path_arg %||% ""))
  if (nzchar(override)) {
    return(normalizePath(override, winslash = "/", mustWork = FALSE))
  }
  normalizePath(file.path(logs_dir, "vp_perf_acceptance_run_manifest.csv"), winslash = "/", mustWork = FALSE)
}

vp_perf_manifest_jsonl_path <- function(manifest_csv_path) {
  csv_path <- normalizePath(manifest_csv_path, winslash = "/", mustWork = FALSE)
  sub("\\.csv$", ".jsonl", csv_path, ignore.case = TRUE)
}

vp_perf_safe_read_csv <- function(path) {
  if (!file.exists(path)) return(data.frame(stringsAsFactors = FALSE))
  tryCatch(
    utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE),
    error = function(...) data.frame(stringsAsFactors = FALSE)
  )
}

vp_perf_normalize_manifest_df <- function(df) {
  if (!is.data.frame(df)) {
    stop("Manifest row input must be a data frame.", call. = FALSE)
  }
  if (nrow(df) != 1L) {
    stop("Manifest writer expects exactly one row per append.", call. = FALSE)
  }
  out <- df
  for (column_name in names(out)) {
    value <- out[[column_name]]
    if (length(value) == 0L) {
      out[[column_name]] <- NA
      next
    }
    if (length(value) > 1L) {
      out[[column_name]] <- paste(as.character(value), collapse = "|")
      next
    }
    out[[column_name]] <- value[[1L]]
  }
  out
}

vp_perf_align_manifest_columns <- function(existing_df, new_df) {
  all_names <- unique(c(names(existing_df), names(new_df)))

  if (ncol(existing_df) == 0L && length(all_names) > 0L) {
    existing_df <- as.data.frame(setNames(vector("list", length(all_names)), all_names), stringsAsFactors = FALSE)
    existing_df <- existing_df[0, , drop = FALSE]
  }

  for (column_name in setdiff(all_names, names(existing_df))) {
    existing_df[[column_name]] <- rep(NA, nrow(existing_df))
  }
  for (column_name in setdiff(all_names, names(new_df))) {
    new_df[[column_name]] <- rep(NA, nrow(new_df))
  }

  list(
    existing = existing_df[, all_names, drop = FALSE],
    new = new_df[, all_names, drop = FALSE]
  )
}

vp_perf_append_manifest_row <- function(logs_dir, row_df, manifest_path_arg = "") {
  if (!dir.exists(logs_dir)) {
    dir.create(logs_dir, recursive = TRUE, showWarnings = FALSE)
  }

  manifest_csv <- vp_perf_manifest_csv_path(logs_dir = logs_dir, manifest_path_arg = manifest_path_arg)
  manifest_jsonl <- vp_perf_manifest_jsonl_path(manifest_csv)

  normalized_row <- vp_perf_normalize_manifest_df(as.data.frame(row_df, stringsAsFactors = FALSE, check.names = FALSE))
  existing <- vp_perf_safe_read_csv(manifest_csv)
  aligned <- vp_perf_align_manifest_columns(existing, normalized_row)
  combined <- rbind(aligned$existing, aligned$new)

  utils::write.csv(combined, manifest_csv, row.names = FALSE, na = "")

  jsonl_written <- FALSE
  if (requireNamespace("jsonlite", quietly = TRUE)) {
    payload <- as.list(aligned$new[1, , drop = FALSE])
    line <- jsonlite::toJSON(payload, auto_unbox = TRUE, null = "null", na = "null")
    cat(line, "\n", file = manifest_jsonl, append = TRUE, sep = "")
    jsonl_written <- TRUE
  }

  list(
    manifest_csv = normalizePath(manifest_csv, winslash = "/", mustWork = FALSE),
    manifest_jsonl = if (isTRUE(jsonl_written)) normalizePath(manifest_jsonl, winslash = "/", mustWork = FALSE) else NA_character_
  )
}

vp_perf_load_manifest <- function(logs_dir, manifest_path_arg = "") {
  manifest_csv <- vp_perf_manifest_csv_path(logs_dir = logs_dir, manifest_path_arg = manifest_path_arg)
  list(path = manifest_csv, data = vp_perf_safe_read_csv(manifest_csv))
}

vp_perf_manifest_runtime_paths <- function(manifest_df) {
  if (!is.data.frame(manifest_df) || nrow(manifest_df) == 0L) return(character(0))

  path_columns <- c("runtime_log_path", "acceptance_run_manifest", "runtime_log_paths")
  available <- path_columns[path_columns %in% names(manifest_df)]
  if (length(available) == 0L) return(character(0))

  values <- unlist(manifest_df[, available, drop = FALSE], use.names = FALSE)
  values <- as.character(values)
  values <- values[!is.na(values) & nzchar(trimws(values))]
  if (length(values) == 0L) return(character(0))

  split_values <- unlist(lapply(values, vp_perf_split_pipe_values), use.names = FALSE)
  split_values <- split_values[nzchar(split_values)]
  unique(normalizePath(split_values, winslash = "/", mustWork = FALSE))
}

vp_perf_filter_manifest_rows <- function(manifest_df, run_ids = character(0), session_ids = character(0), acceptance_only = TRUE, probe_types = character(0)) {
  if (!is.data.frame(manifest_df) || nrow(manifest_df) == 0L) return(manifest_df)
  out <- manifest_df

  if (isTRUE(acceptance_only) && "acceptance_mode" %in% names(out)) {
    acceptance_values <- tolower(trimws(as.character(out$acceptance_mode %||% "")))
    out <- out[acceptance_values %in% c("true", "1"), , drop = FALSE]
  }

  if (length(run_ids) > 0L && "run_id" %in% names(out)) {
    run_values <- trimws(as.character(out$run_id %||% ""))
    out <- out[run_values %in% run_ids, , drop = FALSE]
  }

  if (length(session_ids) > 0L && "session_id" %in% names(out)) {
    session_values <- trimws(as.character(out$session_id %||% ""))
    out <- out[session_values %in% session_ids, , drop = FALSE]
  }

  if (length(probe_types) > 0L && "probe_type" %in% names(out)) {
    type_values <- trimws(as.character(out$probe_type %||% ""))
    out <- out[type_values %in% probe_types, , drop = FALSE]
  }

  out
}

vp_perf_validate_manifest_rows <- function(manifest_df, required_fields = c("run_id", "session_id", "runtime_log_path", "output_csv_path"), strict = TRUE, require_existing_paths = TRUE) {
  if (!is.data.frame(manifest_df) || nrow(manifest_df) == 0L) {
    return(list(ok = TRUE, rows = manifest_df, errors = character(0), invalid_rows = integer(0)))
  }

  required_fields <- unique(trimws(as.character(required_fields %||% character(0))))
  required_fields <- required_fields[nzchar(required_fields)]

  missing_columns <- setdiff(required_fields, names(manifest_df))
  if (length(missing_columns) > 0L) {
    message_text <- paste("missing_columns=", paste(missing_columns, collapse = "|"), sep = "")
    if (isTRUE(strict)) stop(paste("Acceptance manifest validation failed:", message_text), call. = FALSE)
    return(list(ok = FALSE, rows = manifest_df[0, , drop = FALSE], errors = message_text, invalid_rows = seq_len(nrow(manifest_df))))
  }

  row_invalid <- rep(FALSE, nrow(manifest_df))
  row_errors <- vector("list", nrow(manifest_df))

  for (field_name in required_fields) {
    values <- trimws(as.character(manifest_df[[field_name]] %||% ""))
    missing_value <- is.na(values) | !nzchar(values)
    if (any(missing_value)) {
      row_invalid <- row_invalid | missing_value
      for (index in which(missing_value)) {
        row_errors[[index]] <- c(row_errors[[index]], paste0("missing_field:", field_name))
      }
    }
  }

  if (isTRUE(require_existing_paths)) {
    for (path_field in c("runtime_log_path", "output_csv_path")) {
      if (!(path_field %in% required_fields)) next
      values <- trimws(as.character(manifest_df[[path_field]] %||% ""))
      present <- !is.na(values) & nzchar(values)
      missing_path <- present & !file.exists(values)
      if (any(missing_path)) {
        row_invalid <- row_invalid | missing_path
        for (index in which(missing_path)) {
          row_errors[[index]] <- c(row_errors[[index]], paste0("missing_path:", path_field))
        }
      }
    }
  }

  invalid_rows <- which(row_invalid)
  errors <- if (length(invalid_rows) > 0L) {
    vapply(invalid_rows, function(index) {
      sprintf("row=%d;%s", index, paste(unique(row_errors[[index]]), collapse = "|"))
    }, character(1))
  } else {
    character(0)
  }

  if (isTRUE(strict) && length(errors) > 0L) {
    stop(paste("Acceptance manifest validation failed:", paste(errors, collapse = " || ")), call. = FALSE)
  }

  list(
    ok = length(errors) == 0L,
    rows = if (isTRUE(strict)) manifest_df[!row_invalid, , drop = FALSE] else manifest_df,
    errors = errors,
    invalid_rows = invalid_rows
  )
}

vp_perf_resolve_manifest_inputs <- function(logs_dir, manifest_path_arg = "", run_ids = character(0), session_ids = character(0), acceptance_only = TRUE, probe_types = character(0), strict_manifest_rows = FALSE, required_fields = c("run_id", "session_id", "runtime_log_path", "output_csv_path")) {
  manifest <- vp_perf_load_manifest(logs_dir = logs_dir, manifest_path_arg = manifest_path_arg)
  filtered <- vp_perf_filter_manifest_rows(
    manifest_df = manifest$data,
    run_ids = run_ids,
    session_ids = session_ids,
    acceptance_only = acceptance_only,
    probe_types = probe_types
  )

  validation <- vp_perf_validate_manifest_rows(
    manifest_df = filtered,
    required_fields = required_fields,
    strict = isTRUE(strict_manifest_rows),
    require_existing_paths = isTRUE(strict_manifest_rows)
  )

  valid_rows <- validation$rows

  list(
    manifest_path = manifest$path,
    rows = valid_rows,
    paths = vp_perf_manifest_runtime_paths(valid_rows),
    run_ids = if ("run_id" %in% names(valid_rows)) unique(trimws(as.character(valid_rows$run_id))) else character(0),
    session_ids = if ("session_id" %in% names(valid_rows)) unique(trimws(as.character(valid_rows$session_id))) else character(0),
    validation_ok = isTRUE(validation$ok),
    validation_errors = validation$errors
  )
}

vp_perf_normalize_bool <- function(value, default = FALSE) {
  values <- trimws(tolower(as.character(value %||% "")))
  values <- values[!is.na(values) & nzchar(values)]
  if (length(values) == 0L) return(default)
  values[[1L]] %in% c("1", "true", "yes", "y", "on", "t")
}

vp_perf_status_is_clean <- function(value) {
  text <- trimws(tolower(as.character(value %||% "")))
  if (!nzchar(text)) return(FALSE)

  tokens <- vp_perf_split_pipe_values(text)
  if (length(tokens) == 0L) tokens <- text
  tokens <- trimws(tolower(tokens))
  tokens <- tokens[nzchar(tokens)]
  if (length(tokens) == 0L) return(FALSE)

  has_pass <- any(grepl("^pass", tokens, perl = TRUE))
  has_bad <- any(grepl("^(fail|partial|error|timeout|missing|unknown)", tokens, perl = TRUE))
  isTRUE(has_pass) && !isTRUE(has_bad)
}

vp_perf_validate_pair_manifest_context <- function(manifest_df, expected_rows, strict = TRUE) {
  if (!is.data.frame(expected_rows) || nrow(expected_rows) == 0L) {
    message_text <- "Expected context rows are required for pair manifest validation."
    if (isTRUE(strict)) stop(message_text, call. = FALSE)
    return(list(ok = FALSE, rows = data.frame(stringsAsFactors = FALSE), detail = data.frame(stringsAsFactors = FALSE), errors = message_text))
  }

  required_manifest_cols <- c(
    "probe_type", "run_id", "session_id", "label", "scenario", "cache_state",
    "status", "base_status", "acceptance_mode", "runtime_enabled",
    "perf_boundary_markers_enabled", "runtime_log_path", "output_csv_path"
  )
  missing_manifest_cols <- setdiff(required_manifest_cols, names(manifest_df))
  if (length(missing_manifest_cols) > 0L) {
    message_text <- paste("missing_manifest_columns", paste(missing_manifest_cols, collapse = "|"), sep = ":")
    if (isTRUE(strict)) stop(paste("Pair manifest context validation failed:", message_text), call. = FALSE)
    return(list(ok = FALSE, rows = data.frame(stringsAsFactors = FALSE), detail = data.frame(stringsAsFactors = FALSE), errors = message_text))
  }

  required_expected_cols <- c(
    "lane", "probe_type", "run_id", "session_id", "label",
    "scenario", "cache_state", "runtime_enabled", "perf_boundary_markers_enabled"
  )
  missing_expected_cols <- setdiff(required_expected_cols, names(expected_rows))
  if (length(missing_expected_cols) > 0L) {
    message_text <- paste("missing_expected_columns", paste(missing_expected_cols, collapse = "|"), sep = ":")
    if (isTRUE(strict)) stop(paste("Pair manifest context validation failed:", message_text), call. = FALSE)
    return(list(ok = FALSE, rows = data.frame(stringsAsFactors = FALSE), detail = data.frame(stringsAsFactors = FALSE), errors = message_text))
  }

  manifest_run <- trimws(as.character(manifest_df$run_id %||% ""))
  manifest_session <- trimws(as.character(manifest_df$session_id %||% ""))
  manifest_probe <- trimws(as.character(manifest_df$probe_type %||% ""))

  detail_rows <- vector("list", nrow(expected_rows))
  matched_rows <- vector("list", nrow(expected_rows))

  for (index in seq_len(nrow(expected_rows))) {
    expected <- expected_rows[index, , drop = FALSE]
    expected_lane <- trimws(as.character(expected$lane[[1L]] %||% ""))
    expected_probe <- trimws(as.character(expected$probe_type[[1L]] %||% ""))
    expected_run <- trimws(as.character(expected$run_id[[1L]] %||% ""))
    expected_session <- trimws(as.character(expected$session_id[[1L]] %||% ""))
    expected_label <- trimws(as.character(expected$label[[1L]] %||% ""))
    expected_scenario <- trimws(as.character(expected$scenario[[1L]] %||% ""))
    expected_cache <- trimws(as.character(expected$cache_state[[1L]] %||% ""))
    expected_comparison_cache_off <- if ("comparison_plot_cache_off" %in% names(expected)) {
      vp_perf_normalize_bool(expected$comparison_plot_cache_off[[1L]] %||% FALSE, default = FALSE)
    } else {
      NULL
    }
    expected_comparison_cache_mode <- if ("comparison_plot_cache_mode" %in% names(expected)) {
      trimws(as.character(expected$comparison_plot_cache_mode[[1L]] %||% ""))
    } else {
      NULL
    }
    expected_final_bindcache_enabled <- if ("final_output_bindcache_enabled" %in% names(expected)) {
      vp_perf_normalize_bool(expected$final_output_bindcache_enabled[[1L]] %||% TRUE, default = TRUE)
    } else {
      NULL
    }
    expected_runtime <- vp_perf_normalize_bool(expected$runtime_enabled[[1L]] %||% FALSE, default = FALSE)
    expected_markers <- vp_perf_normalize_bool(expected$perf_boundary_markers_enabled[[1L]] %||% FALSE, default = FALSE)

    matches <- which(
      manifest_run %in% expected_run &
        manifest_session %in% expected_session &
        manifest_probe %in% expected_probe
    )
    match_count <- length(matches)

    matched_row <- if (match_count >= 1L) manifest_df[matches[[1L]], , drop = FALSE] else manifest_df[0, , drop = FALSE]
    matched_rows[[index]] <- matched_row

    runtime_log_path <- if (nrow(matched_row) == 1L) trimws(as.character(matched_row$runtime_log_path[[1L]] %||% "")) else ""
    output_csv_path <- if (nrow(matched_row) == 1L) trimws(as.character(matched_row$output_csv_path[[1L]] %||% "")) else ""
    status_value <- if (nrow(matched_row) == 1L) trimws(as.character(matched_row$status[[1L]] %||% "")) else ""
    base_status_value <- if (nrow(matched_row) == 1L) trimws(as.character(matched_row$base_status[[1L]] %||% "")) else ""

    acceptance_mode_match <- nrow(matched_row) == 1L && isTRUE(vp_perf_normalize_bool(matched_row$acceptance_mode[[1L]] %||% FALSE, default = FALSE))
    label_match <- nrow(matched_row) == 1L && identical(trimws(as.character(matched_row$label[[1L]] %||% "")), expected_label)
    scenario_match <- nrow(matched_row) == 1L && identical(trimws(as.character(matched_row$scenario[[1L]] %||% "")), expected_scenario)
    cache_state_match <- nrow(matched_row) == 1L && identical(trimws(as.character(matched_row$cache_state[[1L]] %||% "")), expected_cache)
    comparison_cache_off_match <- if (is.null(expected_comparison_cache_off)) {
      TRUE
    } else {
      nrow(matched_row) == 1L && "comparison_plot_cache_off" %in% names(matched_row) &&
        identical(vp_perf_normalize_bool(matched_row$comparison_plot_cache_off[[1L]] %||% FALSE, default = FALSE), expected_comparison_cache_off)
    }
    comparison_cache_mode_match <- if (is.null(expected_comparison_cache_mode) || !nzchar(expected_comparison_cache_mode)) {
      TRUE
    } else {
      nrow(matched_row) == 1L && "comparison_plot_cache_mode" %in% names(matched_row) &&
        identical(trimws(as.character(matched_row$comparison_plot_cache_mode[[1L]] %||% "")), expected_comparison_cache_mode)
    }
    final_bindcache_enabled_match <- if (is.null(expected_final_bindcache_enabled)) {
      TRUE
    } else {
      nrow(matched_row) == 1L && "final_output_bindcache_enabled" %in% names(matched_row) &&
        identical(vp_perf_normalize_bool(matched_row$final_output_bindcache_enabled[[1L]] %||% FALSE, default = FALSE), expected_final_bindcache_enabled)
    }
    runtime_enabled_match <- nrow(matched_row) == 1L && identical(vp_perf_normalize_bool(matched_row$runtime_enabled[[1L]] %||% FALSE, default = FALSE), expected_runtime)
    markers_match <- nrow(matched_row) == 1L && identical(vp_perf_normalize_bool(matched_row$perf_boundary_markers_enabled[[1L]] %||% FALSE, default = FALSE), expected_markers)

    status_clean <- nrow(matched_row) == 1L && vp_perf_status_is_clean(status_value)
    base_status_clean <- nrow(matched_row) == 1L && vp_perf_status_is_clean(base_status_value)

    runtime_exists <- nzchar(runtime_log_path) && file.exists(runtime_log_path)
    output_exists <- nzchar(output_csv_path) && file.exists(output_csv_path)
    runtime_nonzero <- isTRUE(runtime_exists) && is.finite(file.info(runtime_log_path)$size[[1L]]) && file.info(runtime_log_path)$size[[1L]] > 0
    output_nonzero <- isTRUE(output_exists) && is.finite(file.info(output_csv_path)$size[[1L]]) && file.info(output_csv_path)$size[[1L]] > 0

    reason_tokens <- c(
      if (match_count == 0L) "manifest_row_missing" else character(0),
      if (match_count > 1L) "manifest_row_duplicated" else character(0),
      if (!isTRUE(acceptance_mode_match)) "acceptance_mode_mismatch" else character(0),
      if (!isTRUE(label_match)) "label_mismatch" else character(0),
      if (!isTRUE(scenario_match)) "scenario_mismatch" else character(0),
      if (!isTRUE(cache_state_match)) "cache_state_mismatch" else character(0),
      if (!isTRUE(comparison_cache_off_match)) "comparison_plot_cache_off_mismatch" else character(0),
      if (!isTRUE(comparison_cache_mode_match)) "comparison_plot_cache_mode_mismatch" else character(0),
      if (!isTRUE(final_bindcache_enabled_match)) "final_output_bindcache_enabled_mismatch" else character(0),
      if (!isTRUE(runtime_enabled_match)) "runtime_enabled_mismatch" else character(0),
      if (!isTRUE(markers_match)) "perf_boundary_markers_mismatch" else character(0),
      if (!isTRUE(status_clean)) "status_not_clean" else character(0),
      if (!isTRUE(base_status_clean)) "base_status_not_clean" else character(0),
      if (!isTRUE(runtime_exists)) "runtime_log_missing" else character(0),
      if (!isTRUE(runtime_nonzero)) "runtime_log_empty" else character(0),
      if (!isTRUE(output_exists)) "output_csv_missing" else character(0),
      if (!isTRUE(output_nonzero)) "output_csv_empty" else character(0)
    )
    reason_tokens <- unique(reason_tokens[nzchar(reason_tokens)])

    validation_ok <- length(reason_tokens) == 0L
    detail_rows[[index]] <- data.frame(
      lane = expected_lane,
      probe_type = expected_probe,
      run_id = expected_run,
      session_id = expected_session,
      label = expected_label,
      scenario = expected_scenario,
      cache_state = expected_cache,
      matched_row_count = match_count,
      acceptance_mode_match = isTRUE(acceptance_mode_match),
      label_match = isTRUE(label_match),
      scenario_match = isTRUE(scenario_match),
      cache_state_match = isTRUE(cache_state_match),
      comparison_plot_cache_off_match = isTRUE(comparison_cache_off_match),
      comparison_plot_cache_mode_match = isTRUE(comparison_cache_mode_match),
      final_output_bindcache_enabled_match = isTRUE(final_bindcache_enabled_match),
      runtime_enabled_match = isTRUE(runtime_enabled_match),
      perf_boundary_markers_match = isTRUE(markers_match),
      status_clean = isTRUE(status_clean),
      base_status_clean = isTRUE(base_status_clean),
      runtime_log_exists = isTRUE(runtime_exists),
      runtime_log_nonzero = isTRUE(runtime_nonzero),
      output_csv_exists = isTRUE(output_exists),
      output_csv_nonzero = isTRUE(output_nonzero),
      validation_ok = isTRUE(validation_ok),
      validation_reason = if (length(reason_tokens) > 0L) paste(reason_tokens, collapse = "|") else "ok",
      runtime_log_path = runtime_log_path,
      output_csv_path = output_csv_path,
      manifest_status = status_value,
      manifest_base_status = base_status_value,
      stringsAsFactors = FALSE
    )
  }

  detail <- do.call(rbind, detail_rows)
  rownames(detail) <- NULL
  valid_rows <- do.call(rbind, matched_rows)
  if (!is.data.frame(valid_rows)) {
    valid_rows <- data.frame(stringsAsFactors = FALSE)
  }

  errors <- detail$validation_reason[!as.logical(detail$validation_ok)]
  errors <- unique(errors[nzchar(errors)])
  ok <- nrow(detail) > 0L && all(as.logical(detail$validation_ok))

  if (isTRUE(strict) && !isTRUE(ok)) {
    stop(
      paste(
        "Pair manifest context validation failed:",
        paste(errors, collapse = " || ")
      ),
      call. = FALSE
    )
  }

  list(
    ok = isTRUE(ok),
    rows = valid_rows,
    detail = detail,
    errors = errors
  )
}

vp_perf_read_runtime_log_records <- function(runtime_log_path) {
  empty <- list(
    path = runtime_log_path,
    line_count = 0L,
    parsed_count = 0L,
    parse_error_count = 0L,
    records = list(),
    parse_errors = character(0)
  )

  runtime_log_path <- trimws(as.character(runtime_log_path %||% ""))
  if (!nzchar(runtime_log_path) || !file.exists(runtime_log_path)) {
    return(empty)
  }

  lines <- readLines(runtime_log_path, warn = FALSE)
  lines <- lines[nzchar(trimws(lines))]
  if (length(lines) == 0L) {
    empty$line_count <- 0L
    return(empty)
  }

  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    empty$line_count <- length(lines)
    empty$parse_error_count <- length(lines)
    empty$parse_errors <- "jsonlite_unavailable"
    return(empty)
  }

  parsed <- lapply(lines, function(line) {
    tryCatch(
      jsonlite::fromJSON(line, simplifyVector = FALSE),
      error = function(error) list(`.parse_error` = conditionMessage(error))
    )
  })

  parse_error_flags <- vapply(parsed, function(record) ".parse_error" %in% names(record), logical(1))
  records <- parsed[!parse_error_flags]
  parse_errors <- vapply(parsed[parse_error_flags], function(record) as.character(record[[".parse_error"]] %||% "parse_error"), character(1))

  list(
    path = runtime_log_path,
    line_count = length(lines),
    parsed_count = length(records),
    parse_error_count = length(parse_errors),
    records = records,
    parse_errors = unique(parse_errors)
  )
}

vp_perf_record_field_values <- function(records, field_name) {
  if (length(records) == 0L) return(character(0))
  values <- vapply(records, function(record) {
    value <- record[[field_name]]
    if (is.null(value) || length(value) == 0L) return("")
    raw <- trimws(as.character(value[[1L]] %||% ""))
    if (is.na(raw)) "" else raw
  }, character(1))
  values[!is.na(values)]
}

vp_perf_validate_runtime_log_identity <- function(manifest_df, strict = TRUE) {
  if (!is.data.frame(manifest_df) || nrow(manifest_df) == 0L) {
    message_text <- "Runtime identity validation requires at least one manifest row."
    if (isTRUE(strict)) stop(message_text, call. = FALSE)
    return(list(ok = FALSE, detail = data.frame(stringsAsFactors = FALSE), errors = message_text))
  }

  required_cols <- c("probe_type", "run_id", "session_id", "label", "runtime_log_path")
  missing_cols <- setdiff(required_cols, names(manifest_df))
  if (length(missing_cols) > 0L) {
    message_text <- paste("missing_manifest_columns", paste(missing_cols, collapse = "|"), sep = ":")
    if (isTRUE(strict)) stop(paste("Runtime identity validation failed:", message_text), call. = FALSE)
    return(list(ok = FALSE, detail = data.frame(stringsAsFactors = FALSE), errors = message_text))
  }

  detail_rows <- vector("list", nrow(manifest_df))
  for (index in seq_len(nrow(manifest_df))) {
    row <- manifest_df[index, , drop = FALSE]
    expected_probe <- trimws(as.character(row$probe_type[[1L]] %||% ""))
    expected_run <- trimws(as.character(row$run_id[[1L]] %||% ""))
    expected_session <- trimws(as.character(row$session_id[[1L]] %||% ""))
    expected_label <- trimws(as.character(row$label[[1L]] %||% ""))
    has_expected_cache_off <- "comparison_plot_cache_off" %in% names(row)
    expected_cache_off <- if (isTRUE(has_expected_cache_off)) {
      suppressWarnings(as.logical(row$comparison_plot_cache_off[[1L]]))
    } else {
      NA
    }
    has_expected_cache_mode <- "comparison_plot_cache_mode" %in% names(row)
    expected_cache_mode <- if (isTRUE(has_expected_cache_mode)) {
      trimws(as.character(row$comparison_plot_cache_mode[[1L]] %||% ""))
    } else {
      ""
    }
    runtime_log_path <- trimws(as.character(row$runtime_log_path[[1L]] %||% ""))

    file_exists <- nzchar(runtime_log_path) && file.exists(runtime_log_path)
    file_size <- if (isTRUE(file_exists)) suppressWarnings(as.numeric(file.info(runtime_log_path)$size[[1L]])) else NA_real_
    file_nonzero <- isTRUE(file_exists) && is.finite(file_size) && file_size > 0

    parsed <- vp_perf_read_runtime_log_records(runtime_log_path)
    records <- parsed$records

    runtime_session_ids <- vp_perf_record_field_values(records, "runtime_session_id")
    probe_run_ids <- vp_perf_record_field_values(records, "probe_run_id")
    probe_session_ids <- vp_perf_record_field_values(records, "probe_session_id")
    probe_types <- vp_perf_record_field_values(records, "probe_type")
    probe_labels <- vp_perf_record_field_values(records, "probe_label")
    probe_cache_off_values_raw <- vp_perf_record_field_values(records, "probe_comparison_plot_cache_off")
    probe_cache_mode_values <- vp_perf_record_field_values(records, "probe_comparison_plot_cache_mode")

    parse_probe_cache_off <- function(values) {
      if (length(values) == 0L) return(logical(0))
      out <- rep(NA, length(values))
      norm <- tolower(trimws(values))
      out[norm %in% c("true", "t", "1", "yes", "y", "on")] <- TRUE
      out[norm %in% c("false", "f", "0", "no", "n", "off")] <- FALSE
      out
    }
    probe_cache_off_values <- parse_probe_cache_off(probe_cache_off_values_raw)

    run_present <- nzchar(probe_run_ids)
    run_match <- run_present & probe_run_ids %in% expected_run
    run_mismatch <- run_present & !probe_run_ids %in% expected_run

    session_present <- nzchar(probe_session_ids)
    session_match <- session_present & probe_session_ids %in% expected_session
    session_mismatch <- session_present & !probe_session_ids %in% expected_session

    type_present <- nzchar(probe_types)
    type_match <- type_present & probe_types %in% expected_probe
    type_mismatch <- type_present & !probe_types %in% expected_probe

    label_present <- nzchar(probe_labels)
    label_match <- label_present & probe_labels %in% expected_label
    label_mismatch <- label_present & !probe_labels %in% expected_label

    cache_off_present <- !is.na(probe_cache_off_values)
    cache_off_match <- if (!isTRUE(has_expected_cache_off) || is.na(expected_cache_off)) {
      rep(FALSE, length(probe_cache_off_values))
    } else {
      cache_off_present & probe_cache_off_values %in% expected_cache_off
    }
    cache_off_mismatch <- if (!isTRUE(has_expected_cache_off) || is.na(expected_cache_off)) {
      rep(FALSE, length(probe_cache_off_values))
    } else {
      cache_off_present & !probe_cache_off_values %in% expected_cache_off
    }

    cache_mode_present <- nzchar(probe_cache_mode_values)
    cache_mode_match <- if (!isTRUE(has_expected_cache_mode) || !nzchar(expected_cache_mode)) {
      rep(FALSE, length(probe_cache_mode_values))
    } else {
      cache_mode_present & probe_cache_mode_values %in% expected_cache_mode
    }
    cache_mode_mismatch <- if (!isTRUE(has_expected_cache_mode) || !nzchar(expected_cache_mode)) {
      rep(FALSE, length(probe_cache_mode_values))
    } else {
      cache_mode_present & !probe_cache_mode_values %in% expected_cache_mode
    }

    reason_tokens <- c(
      if (!isTRUE(file_exists)) "runtime_log_missing" else character(0),
      if (!isTRUE(file_nonzero)) "runtime_log_empty" else character(0),
      if (parsed$line_count <= 0L) "runtime_log_no_lines" else character(0),
      if (parsed$parsed_count <= 0L) "runtime_log_no_parsed_records" else character(0),
      if (sum(nzchar(runtime_session_ids), na.rm = TRUE) <= 0L) "runtime_session_id_missing" else character(0),
      if (sum(run_present, na.rm = TRUE) <= 0L) "probe_run_id_missing" else character(0),
      if (sum(run_match, na.rm = TRUE) <= 0L) "probe_run_id_no_match" else character(0),
      if (sum(run_mismatch, na.rm = TRUE) > 0L) "probe_run_id_mismatch" else character(0),
      if (sum(session_present, na.rm = TRUE) <= 0L) "probe_session_id_missing" else character(0),
      if (sum(session_match, na.rm = TRUE) <= 0L) "probe_session_id_no_match" else character(0),
      if (sum(session_mismatch, na.rm = TRUE) > 0L) "probe_session_id_mismatch" else character(0),
      if (sum(type_present, na.rm = TRUE) <= 0L) "probe_type_missing" else character(0),
      if (sum(type_match, na.rm = TRUE) <= 0L) "probe_type_no_match" else character(0),
      if (sum(type_mismatch, na.rm = TRUE) > 0L) "probe_type_mismatch" else character(0),
      if (sum(label_present, na.rm = TRUE) <= 0L) "probe_label_missing" else character(0),
      if (sum(label_match, na.rm = TRUE) <= 0L) "probe_label_no_match" else character(0),
      if (sum(label_mismatch, na.rm = TRUE) > 0L) "probe_label_mismatch" else character(0),
      if (isTRUE(has_expected_cache_off) && !is.na(expected_cache_off) && sum(cache_off_present, na.rm = TRUE) <= 0L) "probe_comparison_plot_cache_off_missing" else character(0),
      if (isTRUE(has_expected_cache_off) && !is.na(expected_cache_off) && sum(cache_off_match, na.rm = TRUE) <= 0L) "probe_comparison_plot_cache_off_no_match" else character(0),
      if (isTRUE(has_expected_cache_off) && !is.na(expected_cache_off) && sum(cache_off_mismatch, na.rm = TRUE) > 0L) "probe_comparison_plot_cache_off_mismatch" else character(0),
      if (isTRUE(has_expected_cache_mode) && nzchar(expected_cache_mode) && sum(cache_mode_present, na.rm = TRUE) <= 0L) "probe_comparison_plot_cache_mode_missing" else character(0),
      if (isTRUE(has_expected_cache_mode) && nzchar(expected_cache_mode) && sum(cache_mode_match, na.rm = TRUE) <= 0L) "probe_comparison_plot_cache_mode_no_match" else character(0),
      if (isTRUE(has_expected_cache_mode) && nzchar(expected_cache_mode) && sum(cache_mode_mismatch, na.rm = TRUE) > 0L) "probe_comparison_plot_cache_mode_mismatch" else character(0)
    )
    reason_tokens <- unique(reason_tokens[nzchar(reason_tokens)])

    validation_ok <- length(reason_tokens) == 0L
    detail_rows[[index]] <- data.frame(
      probe_type = expected_probe,
      run_id = expected_run,
      session_id = expected_session,
      label = expected_label,
      runtime_log_path = runtime_log_path,
      runtime_log_exists = isTRUE(file_exists),
      runtime_log_nonzero = isTRUE(file_nonzero),
      runtime_log_size_bytes = if (is.finite(file_size)) as.numeric(file_size) else NA_real_,
      line_count = as.integer(parsed$line_count),
      parsed_record_count = as.integer(parsed$parsed_count),
      parse_error_count = as.integer(parsed$parse_error_count),
      runtime_session_id_count = sum(nzchar(runtime_session_ids), na.rm = TRUE),
      probe_run_id_present_count = sum(run_present, na.rm = TRUE),
      probe_run_id_match_count = sum(run_match, na.rm = TRUE),
      probe_run_id_mismatch_count = sum(run_mismatch, na.rm = TRUE),
      probe_session_id_present_count = sum(session_present, na.rm = TRUE),
      probe_session_id_match_count = sum(session_match, na.rm = TRUE),
      probe_session_id_mismatch_count = sum(session_mismatch, na.rm = TRUE),
      probe_type_present_count = sum(type_present, na.rm = TRUE),
      probe_type_match_count = sum(type_match, na.rm = TRUE),
      probe_type_mismatch_count = sum(type_mismatch, na.rm = TRUE),
      probe_label_present_count = sum(label_present, na.rm = TRUE),
      probe_label_match_count = sum(label_match, na.rm = TRUE),
      probe_label_mismatch_count = sum(label_mismatch, na.rm = TRUE),
      probe_comparison_plot_cache_off_present_count = sum(cache_off_present, na.rm = TRUE),
      probe_comparison_plot_cache_off_match_count = sum(cache_off_match, na.rm = TRUE),
      probe_comparison_plot_cache_off_mismatch_count = sum(cache_off_mismatch, na.rm = TRUE),
      probe_comparison_plot_cache_mode_present_count = sum(cache_mode_present, na.rm = TRUE),
      probe_comparison_plot_cache_mode_match_count = sum(cache_mode_match, na.rm = TRUE),
      probe_comparison_plot_cache_mode_mismatch_count = sum(cache_mode_mismatch, na.rm = TRUE),
      validation_ok = isTRUE(validation_ok),
      validation_reason = if (length(reason_tokens) > 0L) paste(reason_tokens, collapse = "|") else "ok",
      stringsAsFactors = FALSE
    )
  }

  detail <- do.call(rbind, detail_rows)
  rownames(detail) <- NULL
  errors <- detail$validation_reason[!as.logical(detail$validation_ok)]
  errors <- unique(errors[nzchar(errors)])
  ok <- nrow(detail) > 0L && all(as.logical(detail$validation_ok))

  if (isTRUE(strict) && !isTRUE(ok)) {
    stop(
      paste(
        "Runtime identity validation failed:",
        paste(errors, collapse = " || ")
      ),
      call. = FALSE
    )
  }

  list(
    ok = isTRUE(ok),
    detail = detail,
    errors = errors
  )
}
