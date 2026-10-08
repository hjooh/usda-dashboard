source(file.path("System", "Testing", "vp_perf_acceptance_manifest.R"), local = TRUE)

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

  stop("Could not resolve repository root for VP PERF runtime log summarizer.", call. = FALSE)
}

safe_numeric <- function(value) {
  suppressWarnings(as.numeric(value))
}

safe_numeric_column <- function(value, n, default = NA_real_) {
  if (is.null(value) || length(value) == 0L) return(rep(default, n))
  out <- suppressWarnings(as.numeric(value))
  if (length(out) == 1L && n != 1L) out <- rep(out, n)
  if (length(out) != n) out <- rep(default, n)
  out
}

safe_character <- function(value, n, default = NA_character_) {
  if (is.null(value) || length(value) == 0L) return(rep(default, n))
  out <- as.character(value)
  if (length(out) == 1L && n != 1L) out <- rep(out, n)
  if (length(out) != n) out <- rep(default, n)
  out
}

safe_logical <- function(value, n, default = NA) {
  if (is.null(value) || length(value) == 0L) return(rep(default, n))
  out <- as.logical(value)
  if (length(out) == 1L && n != 1L) out <- rep(out, n)
  if (length(out) != n) out <- rep(default, n)
  out
}

normalize_scalar <- function(value) {
  if (is.null(value) || length(value) == 0L) return(NA)
  if (is.list(value) && !is.data.frame(value)) {
    if (length(value) == 1L) return(normalize_scalar(value[[1L]]))
    return(paste(vapply(value, function(item) as.character(normalize_scalar(item)), character(1)), collapse = "|"))
  }
  if (length(value) > 1L) return(paste(as.character(value), collapse = "|"))
  value[[1L]]
}

read_runtime_log_file <- function(path) {
  lines <- readLines(path, warn = FALSE)
  lines <- lines[nzchar(trimws(lines))]
  if (length(lines) == 0L) return(data.frame())

  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop("Package jsonlite is required to summarize VP runtime PERF logs.", call. = FALSE)
  }

  parsed <- lapply(seq_along(lines), function(index) {
    tryCatch(
      jsonlite::fromJSON(lines[[index]], simplifyVector = FALSE),
      error = function(error) list(.parse_error = conditionMessage(error))
    )
  })

  all_names <- unique(unlist(lapply(parsed, names), use.names = FALSE))
  if (length(all_names) == 0L) return(data.frame())

  rows <- lapply(seq_along(parsed), function(index) {
    item <- parsed[[index]]
    row <- setNames(vector("list", length(all_names)), all_names)
    for (field_name in all_names) {
      row[[field_name]] <- normalize_scalar(item[[field_name]])
    }
    row$.source_file <- basename(path)
    row$.line_number <- index
    as.data.frame(row, stringsAsFactors = FALSE, check.names = FALSE)
  })

  do.call(rbind, rows)
}

read_runtime_logs <- function(paths) {
  frames <- lapply(paths, read_runtime_log_file)
  frames <- frames[vapply(frames, nrow, integer(1)) > 0L]
  if (length(frames) == 0L) return(data.frame())

  all_names <- unique(unlist(lapply(frames, names), use.names = FALSE))
  frames <- lapply(frames, function(frame) {
    missing_cols <- setdiff(all_names, names(frame))
    for (missing_col in missing_cols) frame[[missing_col]] <- NA
    frame[, all_names, drop = FALSE]
  })

  do.call(rbind, frames)
}

filter_runtime_logs_by_ids <- function(df, allowed_run_ids = character(0), allowed_session_ids = character(0)) {
  if (nrow(df) == 0L) return(df)
  out <- df

  if (length(allowed_run_ids) > 0L && "run_id" %in% names(out)) {
    run_values <- trimws(as.character(out$run_id %||% ""))
    out <- out[run_values %in% allowed_run_ids, , drop = FALSE]
  }

  if (length(allowed_session_ids) > 0L && "session_id" %in% names(out)) {
    session_values <- trimws(as.character(out$session_id %||% ""))
    out <- out[session_values %in% allowed_session_ids, , drop = FALSE]
  }

  out
}

pick_latest_files <- function(paths, latest_arg) {
  if (length(paths) == 0L) return(paths)
  if (identical(tolower(latest_arg %||% ""), "all")) return(paths)

  latest_n <- suppressWarnings(as.integer(latest_arg %||% "10"))
  if (!is.finite(latest_n) || is.na(latest_n) || latest_n < 1L) latest_n <- 10L

  info <- file.info(paths)
  ordered_paths <- paths[order(info$mtime, decreasing = TRUE)]
  head(ordered_paths, latest_n)
}

metric_summary <- function(values) {
  values <- safe_numeric(values)
  values <- values[is.finite(values)]
  data.frame(
    count_with_elapsed = length(values),
    total_seconds = if (length(values) > 0L) sum(values) else NA_real_,
    median_seconds = if (length(values) > 0L) stats::median(values) else NA_real_,
    p95_seconds = if (length(values) > 0L) as.numeric(stats::quantile(values, probs = 0.95, names = FALSE, na.rm = TRUE)) else NA_real_,
    max_seconds = if (length(values) > 0L) max(values) else NA_real_,
    stringsAsFactors = FALSE
  )
}

summarize_by <- function(df, group_cols, value_col = NULL) {
  if (nrow(df) == 0L) return(data.frame())
  for (group_col in group_cols) {
    if (!group_col %in% names(df)) df[[group_col]] <- NA_character_
    df[[group_col]] <- safe_character(df[[group_col]], nrow(df), default = "")
    df[[group_col]][is.na(df[[group_col]])] <- ""
  }

  group_key <- interaction(df[, group_cols, drop = FALSE], drop = TRUE, sep = "\r")
  group_indices <- split(seq_len(nrow(df)), group_key)
  rows <- lapply(group_indices, function(indices) {
    group_values <- as.list(df[indices[[1L]], group_cols, drop = FALSE])
    names(group_values) <- group_cols
    base <- data.frame(group_values, stringsAsFactors = FALSE, check.names = FALSE)
    base$event_count <- length(indices)
    if (!is.null(value_col) && value_col %in% names(df)) {
      cbind(base, metric_summary(df[[value_col]][indices]))
    } else {
      base
    }
  })

  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

add_runtime_labels <- function(df) {
  n <- nrow(df)
  if (n == 0L) return(df)

  event <- safe_character(df$event, n)
  tag <- safe_character(df$tag, n)
  name <- safe_character(df$name, n)
  mode <- safe_character(df$mode, n)
  fallback_reason <- safe_character(df$fallback_reason, n)

  label <- ifelse(!is.na(tag) & nzchar(tag), tag, ifelse(!is.na(name) & nzchar(name), name, event))
  label[is.na(label) | !nzchar(label)] <- "unknown"
  df$summary_label <- label
  df$summary_mode <- ifelse(is.na(mode) | !nzchar(mode), "", mode)
  df$summary_fallback_reason <- ifelse(is.na(fallback_reason) | !nzchar(fallback_reason), "", fallback_reason)

  elapsed_seconds <- safe_numeric_column(df$elapsed_seconds, n)
  elapsed_ms <- safe_numeric_column(df$elapsed_ms, n)
  action_elapsed_ms <- safe_numeric_column(df$action_elapsed_ms, n)
  normalized <- elapsed_seconds
  normalized[!is.finite(normalized) & is.finite(elapsed_ms)] <- elapsed_ms[!is.finite(normalized) & is.finite(elapsed_ms)] / 1000
  normalized[!is.finite(normalized) & is.finite(action_elapsed_ms)] <- action_elapsed_ms[!is.finite(normalized) & is.finite(action_elapsed_ms)] / 1000
  df$elapsed_seconds_normalized <- normalized

  elapsed_source <- rep(NA_character_, n)
  elapsed_source[is.finite(elapsed_seconds)] <- "elapsed_seconds"
  elapsed_source[is.na(elapsed_source) & is.finite(elapsed_ms)] <- "elapsed_ms"
  elapsed_source[is.na(elapsed_source) & is.finite(action_elapsed_ms)] <- "action_elapsed_ms"
  df$elapsed_source <- elapsed_source

  df
}

write_csv <- function(df, path) {
  utils::write.csv(df, path, row.names = FALSE, na = "")
  path
}

main <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  repo_root <- resolve_repo_root(getwd())
  vp_clone_dir <- file.path(repo_root, "VP Clone")
  logs_dir <- file.path(vp_clone_dir, "Logs")
  dir.create(logs_dir, recursive = TRUE, showWarnings = FALSE)

  label <- trimws(as.character(parse_arg_value(args, "label", default = "runtime_logs")))
  if (!nzchar(label)) label <- "runtime_logs"
  latest_arg <- parse_arg_value(args, "latest", default = "10")
  input_arg <- parse_arg_value(args, "input", default = "")
  strict_input <- is_truthy(parse_arg_value(args, "strict-input", default = "true"), default = TRUE)
  use_acceptance_manifest <- is_truthy(parse_arg_value(args, "use-acceptance-manifest", default = "true"), default = TRUE)
  manifest_path_arg <- trimws(as.character(parse_arg_value(args, "acceptance-manifest", default = "")))
  acceptance_only <- is_truthy(parse_arg_value(args, "acceptance-only", default = "true"), default = TRUE)
  probe_type_arg <- parse_arg_value(args, "probe-type", default = "")
  probe_types <- vp_perf_split_pipe_values(probe_type_arg)
  run_id_arg <- parse_arg_value(args, "run-id", default = "")
  session_id_arg <- parse_arg_value(args, "session-id", default = "")
  allowed_run_ids <- vp_perf_split_pipe_values(run_id_arg)
  allowed_session_ids <- vp_perf_split_pipe_values(session_id_arg)

  manifest_resolution <- NULL
  if (isTRUE(strict_input) && isTRUE(use_acceptance_manifest) && !nzchar(trimws(input_arg %||% ""))) {
    manifest_resolution <- vp_perf_resolve_manifest_inputs(
      logs_dir = logs_dir,
      manifest_path_arg = manifest_path_arg,
      run_ids = allowed_run_ids,
      session_ids = allowed_session_ids,
      acceptance_only = acceptance_only,
      probe_types = probe_types
    )
    paths <- manifest_resolution$paths
    if (length(allowed_run_ids) == 0L) {
      allowed_run_ids <- manifest_resolution$run_ids
    }
    if (length(allowed_session_ids) == 0L) {
      allowed_session_ids <- manifest_resolution$session_ids
    }
  } else {
    paths <- if (nzchar(trimws(input_arg %||% ""))) {
      strsplit(input_arg, "\\|", fixed = FALSE)[[1L]]
    } else {
      list.files(logs_dir, pattern = "^vp_runtime_perf_.*\\.jsonl$", full.names = TRUE)
    }
  }

  paths <- normalizePath(paths[file.exists(paths)], winslash = "/", mustWork = FALSE)
  if (isTRUE(strict_input) && length(paths) == 0L) {
    stop("strict-input mode found no runtime log files from explicit input or acceptance manifest resolution.", call. = FALSE)
  }
  if (!isTRUE(strict_input)) {
    paths <- pick_latest_files(paths, latest_arg)
  }

  timestamp_token <- format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC")
  prefix <- file.path(logs_dir, paste0("vp_perf_runtime_summary_", label, "_", timestamp_token))

  cat("VP_PERF_RUNTIME_SUMMARY_START\n")
  cat(sprintf("VP_PERF_RUNTIME_SUMMARY_LABEL=%s\n", label))
  cat(sprintf("VP_PERF_RUNTIME_SUMMARY_STRICT_INPUT=%s\n", if (isTRUE(strict_input)) "TRUE" else "FALSE"))
  cat(sprintf("VP_PERF_RUNTIME_SUMMARY_USE_ACCEPTANCE_MANIFEST=%s\n", if (isTRUE(use_acceptance_manifest)) "TRUE" else "FALSE"))
  cat(sprintf("VP_PERF_RUNTIME_SUMMARY_ACCEPTANCE_ONLY=%s\n", if (isTRUE(acceptance_only)) "TRUE" else "FALSE"))
  cat(sprintf("VP_PERF_RUNTIME_SUMMARY_PROBE_TYPES=%s\n", paste(probe_types, collapse = "|")))
  cat(sprintf("VP_PERF_RUNTIME_SUMMARY_ALLOWED_RUN_IDS=%s\n", paste(allowed_run_ids, collapse = "|")))
  cat(sprintf("VP_PERF_RUNTIME_SUMMARY_ALLOWED_SESSION_IDS=%s\n", paste(allowed_session_ids, collapse = "|")))
  cat(sprintf("VP_PERF_RUNTIME_SUMMARY_ACCEPTANCE_MANIFEST=%s\n", if (is.null(manifest_resolution)) "" else manifest_resolution$manifest_path))
  cat(sprintf("VP_PERF_RUNTIME_SUMMARY_ACCEPTANCE_MANIFEST_ROWS=%s\n", if (is.null(manifest_resolution)) "" else nrow(manifest_resolution$rows)))
  cat(sprintf("VP_PERF_RUNTIME_SUMMARY_FILES=%d\n", length(paths)))

  if (length(paths) == 0L) {
    stop("No VP runtime PERF JSONL files found to summarize.", call. = FALSE)
  }

  raw_df <- add_runtime_labels(read_runtime_logs(paths))
  raw_df <- filter_runtime_logs_by_ids(raw_df, allowed_run_ids = allowed_run_ids, allowed_session_ids = allowed_session_ids)
  if (nrow(raw_df) == 0L) {
    stop("VP runtime PERF JSONL files contained no parseable records after strict filtering.", call. = FALSE)
  }

  file_summary <- data.frame(
    source_file = basename(paths),
    file_path = paths,
    file_size_bytes = as.numeric(file.info(paths)$size),
    modified_time = as.character(file.info(paths)$mtime),
    stringsAsFactors = FALSE
  )

  event_summary <- summarize_by(raw_df, c("event", "summary_label"))
  timed_df <- raw_df[is.finite(raw_df$elapsed_seconds_normalized), , drop = FALSE]
  timed_summary <- summarize_by(timed_df, c("event", "summary_label", "summary_mode", "elapsed_source"), "elapsed_seconds_normalized")
  if (nrow(timed_summary) > 0L) {
    timed_summary <- timed_summary[order(-timed_summary$total_seconds, -timed_summary$max_seconds), , drop = FALSE]
  }

  key_delta_df <- raw_df[identical(raw_df$event, "cache_key_delta") | raw_df$event == "cache_key_delta", , drop = FALSE]
  key_delta_summary <- summarize_by(key_delta_df, c("name", "changed_fields", "filter_purpose", "source", "active_tab"))
  if (nrow(key_delta_summary) > 0L) {
    key_delta_summary <- key_delta_summary[order(-key_delta_summary$event_count), , drop = FALSE]
  }

  cache_body_df <- raw_df[identical(raw_df$event, "cache_body_execution") | raw_df$event == "cache_body_execution", , drop = FALSE]
  churn_summary <- summarize_by(cache_body_df, c("name", "filter_purpose", "source", "active_tab", "runtime_session_id"))
  if (nrow(churn_summary) > 0L) {
    churn_summary <- churn_summary[order(-churn_summary$event_count), , drop = FALSE]
  }

  fanout_summary <- summarize_by(
    cache_body_df,
    c("runtime_session_id", "hierarchy_generation", "hierarchy_last_changed", "hierarchy_signature", "name", "filter_purpose", "active_tab")
  )
  if (nrow(fanout_summary) > 0L) {
    fanout_summary <- fanout_summary[order(fanout_summary$runtime_session_id, suppressWarnings(as.integer(fanout_summary$hierarchy_generation)), -fanout_summary$event_count), , drop = FALSE]
  }

  partition_df <- raw_df[grepl("vp_partition_provider_slice", raw_df$summary_label, fixed = TRUE), , drop = FALSE]
  partition_summary <- summarize_by(partition_df, c("summary_mode", "summary_fallback_reason"), "elapsed_seconds_normalized")
  if (nrow(partition_summary) > 0L) {
    partition_summary <- partition_summary[order(-partition_summary$event_count), , drop = FALSE]
  }

  memory_taken <- safe_logical(raw_df$memory_snapshot_taken, nrow(raw_df), default = NA)
  raw_df$memory_snapshot_taken_normalized <- memory_taken
  memory_summary <- summarize_by(raw_df, c("memory_snapshot_mode", "memory_snapshot_taken_normalized"))
  if (nrow(memory_summary) > 0L) {
    memory_summary <- memory_summary[order(-memory_summary$event_count), , drop = FALSE]
  }

  output_paths <- c(
    files = write_csv(file_summary, paste0(prefix, "_files.csv")),
    events = write_csv(event_summary, paste0(prefix, "_events.csv")),
    timed = write_csv(timed_summary, paste0(prefix, "_timed.csv")),
    key_delta = write_csv(key_delta_summary, paste0(prefix, "_key_delta.csv")),
    churn = write_csv(churn_summary, paste0(prefix, "_churn.csv")),
    fanout = write_csv(fanout_summary, paste0(prefix, "_fanout.csv")),
    partition = write_csv(partition_summary, paste0(prefix, "_partition.csv")),
    memory = write_csv(memory_summary, paste0(prefix, "_memory.csv"))
  )

  cat(sprintf("VP_PERF_RUNTIME_SUMMARY_RECORDS=%d\n", nrow(raw_df)))
  for (name in names(output_paths)) {
    cat(sprintf("VP_PERF_RUNTIME_SUMMARY_%s=%s\n", toupper(name), output_paths[[name]]))
  }

  if (nrow(timed_summary) > 0L) {
    top <- timed_summary[seq_len(min(5L, nrow(timed_summary))), , drop = FALSE]
    cat("VP_PERF_RUNTIME_SUMMARY_TOP_TIMED_BEGIN\n")
    for (index in seq_len(nrow(top))) {
      cat(sprintf(
        "TOP_TIMED=%s|%s|count=%s|total=%.3f|max=%.3f\n",
        top$event[[index]],
        top$summary_label[[index]],
        top$event_count[[index]],
        top$total_seconds[[index]],
        top$max_seconds[[index]]
      ))
    }
    cat("VP_PERF_RUNTIME_SUMMARY_TOP_TIMED_END\n")
  }

  if (nrow(churn_summary) > 0L) {
    top_churn <- churn_summary[seq_len(min(5L, nrow(churn_summary))), , drop = FALSE]
    cat("VP_PERF_RUNTIME_SUMMARY_TOP_CHURN_BEGIN\n")
    for (index in seq_len(nrow(top_churn))) {
      cat(sprintf(
        "TOP_CHURN=%s|purpose=%s|source=%s|tab=%s|session=%s|count=%s\n",
        top_churn$name[[index]],
        top_churn$filter_purpose[[index]],
        top_churn$source[[index]],
        top_churn$active_tab[[index]],
        top_churn$runtime_session_id[[index]],
        top_churn$event_count[[index]]
      ))
    }
    cat("VP_PERF_RUNTIME_SUMMARY_TOP_CHURN_END\n")
  }

  if (nrow(fanout_summary) > 0L) {
    top_fanout <- fanout_summary[seq_len(min(5L, nrow(fanout_summary))), , drop = FALSE]
    cat("VP_PERF_RUNTIME_SUMMARY_TOP_FANOUT_BEGIN\n")
    for (index in seq_len(nrow(top_fanout))) {
      cat(sprintf(
        "TOP_FANOUT=session=%s|generation=%s|last_changed=%s|name=%s|purpose=%s|tab=%s|count=%s\n",
        top_fanout$runtime_session_id[[index]],
        top_fanout$hierarchy_generation[[index]],
        top_fanout$hierarchy_last_changed[[index]],
        top_fanout$name[[index]],
        top_fanout$filter_purpose[[index]],
        top_fanout$active_tab[[index]],
        top_fanout$event_count[[index]]
      ))
    }
    cat("VP_PERF_RUNTIME_SUMMARY_TOP_FANOUT_END\n")
  }

  cat("VP_PERF_RUNTIME_SUMMARY_COMPLETE\n")
}

main()