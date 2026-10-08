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

parse_double_arg <- function(args, key, default = NA_real_) {
  raw <- parse_arg_value(args, key, default = as.character(default))
  value <- suppressWarnings(as.numeric(raw))
  if (!is.finite(value) || is.na(value)) return(default)
  value
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

  stop("Could not resolve repository root for 8C single-action decomposition.", call. = FALSE)
}

safe_numeric <- function(x) {
  suppressWarnings(as.numeric(x))
}

safe_ratio <- function(numerator, denominator) {
  if (!is.finite(numerator) || !is.finite(denominator) || denominator <= 0) return(NA_real_)
  numerator / denominator
}

coerce_posix_utc <- function(x) {
  if (inherits(x, "POSIXt")) {
    return(as.POSIXct(x, tz = "UTC"))
  }

  values <- as.character(x)
  out <- suppressWarnings(as.POSIXct(values, tz = "UTC", format = "%Y-%m-%d %H:%M:%OS"))

  needs_alt <- is.na(out)
  if (any(needs_alt)) {
    out_alt <- suppressWarnings(as.POSIXct(values[needs_alt], tz = "UTC", format = "%Y-%m-%dT%H:%M:%OSZ"))
    out[needs_alt] <- out_alt
  }

  needs_fallback <- is.na(out)
  if (any(needs_fallback)) {
    out_fallback <- suppressWarnings(as.POSIXct(values[needs_fallback], tz = "UTC"))
    out[needs_fallback] <- out_fallback
  }

  out
}

safe_time_range <- function(ts_values) {
  if (length(ts_values) == 0L) {
    return(c(NA_character_, NA_character_))
  }

  ts_posix <- coerce_posix_utc(ts_values)
  ts_posix <- ts_posix[is.finite(as.numeric(ts_posix))]
  if (length(ts_posix) == 0L) {
    return(c(NA_character_, NA_character_))
  }

  c(
    format(min(ts_posix), "%Y-%m-%d %H:%M:%OS", tz = "UTC"),
    format(max(ts_posix), "%Y-%m-%d %H:%M:%OS", tz = "UTC")
  )
}

read_runtime_log <- function(path) {
  lines <- readLines(path, warn = FALSE)
  lines <- lines[nzchar(trimws(lines))]
  if (length(lines) == 0L) return(data.frame())

  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop("Package jsonlite is required for 8C decomposition.", call. = FALSE)
  }

  parsed <- lapply(seq_along(lines), function(index) {
    item <- tryCatch(
      jsonlite::fromJSON(lines[[index]], simplifyVector = FALSE),
      error = function(e) list(.parse_error = conditionMessage(e))
    )
    item$.line_number <- index
    item
  })

  all_names <- unique(unlist(lapply(parsed, names), use.names = FALSE))
  rows <- lapply(parsed, function(item) {
    out <- setNames(vector("list", length(all_names)), all_names)
    for (nm in all_names) {
      value <- item[[nm]]
      if (is.null(value) || length(value) == 0L) {
        out[[nm]] <- NA
      } else if (is.list(value) && !is.data.frame(value)) {
        out[[nm]] <- paste(vapply(value, function(z) as.character(z[[1L]] %||% ""), character(1)), collapse = "|")
      } else if (length(value) > 1L) {
        out[[nm]] <- paste(as.character(value), collapse = "|")
      } else {
        out[[nm]] <- value[[1L]]
      }
    }
    as.data.frame(out, stringsAsFactors = FALSE, check.names = FALSE)
  })

  out <- do.call(rbind, rows)
  out$.source_file <- basename(path)
  out
}

first_ts_for <- function(df, predicate) {
  if (nrow(df) == 0L) return(as.POSIXct(NA))
  idx <- which(predicate)
  if (length(idx) == 0L) return(as.POSIXct(NA))
  df$ts_utc_posix[min(idx)]
}

resolve_action_start <- function(df, event, tag) {
  if (nrow(df) == 0L) {
    return(list(ts = as.POSIXct(NA), source = "missing"))
  }

  tag_lower <- tolower(as.character(tag %||% ""))
  event_lower <- tolower(as.character(event %||% ""))

  has_boundary_markers <- any(event_lower == "client_perf" & grepl("^boundary_", tag_lower))

  if (isTRUE(has_boundary_markers)) {
    boundary_idx <- which(event_lower == "client_perf" & tag_lower == "boundary_action_begin")
    if (length(boundary_idx) > 0L) {
      return(list(ts = df$ts_utc_posix[min(boundary_idx)], source = "client_boundary_action_begin"))
    }
  }

  combined_idx <- which(
    grepl("observeevent\\(data_source_choice\\)", tag_lower, perl = TRUE) |
      grepl("observeevent\\(main_tabs_panel\\)", tag_lower, perl = TRUE)
  )
  if (length(combined_idx) > 0L) {
    chosen_idx <- min(combined_idx)
    chosen_tag <- tag_lower[[chosen_idx]]
    source <- if (grepl("observeevent\\(data_source_choice\\)", chosen_tag, perl = TRUE)) {
      "observeevent_data_source_choice"
    } else {
      "observeevent_main_tabs_panel"
    }
    return(list(ts = df$ts_utc_posix[chosen_idx], source = source))
  }

  client_perf_idx <- which(event_lower == "client_perf")
  if (length(client_perf_idx) > 0L) {
    return(list(ts = df$ts_utc_posix[min(client_perf_idx)], source = "client_perf_fallback"))
  }

  finite_ts <- df$ts_utc_posix[is.finite(as.numeric(df$ts_utc_posix))]
  if (length(finite_ts) > 0L) {
    return(list(ts = min(finite_ts), source = "first_runtime_event_fallback"))
  }

  list(ts = as.POSIXct(NA), source = "missing")
}

resolve_visible_milestone <- function(df, event, tag, action_start_ts = as.POSIXct(NA)) {
  if (nrow(df) == 0L) {
    return(list(ts = as.POSIXct(NA), source = "missing"))
  }

  event_lower <- tolower(as.character(event %||% ""))
  tag_lower <- tolower(as.character(tag %||% ""))

  has_boundary_markers <- any(event_lower == "client_perf" & grepl("^boundary_", tag_lower))
  has_action_start <- is.finite(as.numeric(action_start_ts))

  if (isTRUE(has_boundary_markers)) {
    boundary_visible_ready_idx <- which(event_lower == "client_perf" & tag_lower == "boundary_visible_ready")
    if (isTRUE(has_action_start) && length(boundary_visible_ready_idx) > 0L) {
      boundary_visible_ready_idx <- boundary_visible_ready_idx[df$ts_utc_posix[boundary_visible_ready_idx] >= action_start_ts]
    }
    if (length(boundary_visible_ready_idx) > 0L) {
      chosen_idx <- min(boundary_visible_ready_idx)
      return(list(ts = df$ts_utc_posix[chosen_idx], source = "client_boundary_visible_ready"))
    }

    boundary_tab_after_paint_idx <- which(event_lower == "client_perf" & tag_lower == "boundary_tab_after_paint")
    if (isTRUE(has_action_start) && length(boundary_tab_after_paint_idx) > 0L) {
      boundary_tab_after_paint_idx <- boundary_tab_after_paint_idx[df$ts_utc_posix[boundary_tab_after_paint_idx] >= action_start_ts]
    }
    if (length(boundary_tab_after_paint_idx) > 0L) {
      chosen_idx <- min(boundary_tab_after_paint_idx)
      return(list(ts = df$ts_utc_posix[chosen_idx], source = "client_boundary_tab_after_paint"))
    }

    boundary_fallback_idx <- which(event_lower == "client_perf" & tag_lower %in% c("tab_after_paint", "main_tabs_mount"))
    if (isTRUE(has_action_start) && length(boundary_fallback_idx) > 0L) {
      boundary_fallback_idx <- boundary_fallback_idx[df$ts_utc_posix[boundary_fallback_idx] >= action_start_ts]
    }
    if (length(boundary_fallback_idx) > 0L) {
      chosen_idx <- min(boundary_fallback_idx)
      chosen_tag <- tag_lower[[chosen_idx]]
      source <- if (identical(chosen_tag, "tab_after_paint")) {
        "client_tab_after_paint"
      } else {
        "client_main_tabs_mount"
      }
      return(list(ts = df$ts_utc_posix[chosen_idx], source = source))
    }
  }

  combined_visible_idx <- which(event_lower == "client_perf" & tag_lower %in% c("tab_after_paint", "main_tabs_mount"))
  if (length(combined_visible_idx) > 0L) {
    chosen_idx <- min(combined_visible_idx)
    chosen_tag <- tag_lower[[chosen_idx]]
    source <- if (identical(chosen_tag, "tab_after_paint")) {
      "client_tab_after_paint"
    } else {
      "client_main_tabs_mount"
    }
    return(list(ts = df$ts_utc_posix[chosen_idx], source = source))
  }

  output_idx <- which(tag_lower == "output$main_tabs")
  if (length(output_idx) > 0L) {
    return(list(ts = df$ts_utc_posix[min(output_idx)], source = "output_main_tabs_fallback"))
  }

  list(ts = as.POSIXct(NA), source = "missing")
}

derive_window_boundary_quality <- function(action_source, visible_source) {
  action_source <- trimws(as.character(action_source %||% "missing"))
  visible_source <- trimws(as.character(visible_source %||% "missing"))

  issues <- character(0)
  confidence <- "high"

  if (identical(action_source, "missing")) {
    issues <- c(issues, "action_missing")
    confidence <- "low"
  }
  if (identical(visible_source, "missing")) {
    issues <- c(issues, "visible_missing")
    confidence <- "low"
  }

  if (identical(action_source, "first_runtime_event_fallback")) {
    issues <- c(issues, "action_fallback_first_runtime_event")
    confidence <- "low"
  } else if (identical(action_source, "client_perf_fallback") && confidence != "low") {
    issues <- c(issues, "action_fallback_client_perf")
    confidence <- "medium"
  } else if (identical(action_source, "client_boundary_action_begin") && confidence != "low") {
    confidence <- "high"
  }

  if (identical(visible_source, "output_main_tabs_fallback") && confidence != "low") {
    issues <- c(issues, "visible_fallback_output_main_tabs")
    confidence <- "medium"
  } else if (visible_source %in% c("client_boundary_visible_ready", "client_boundary_tab_after_paint") && confidence != "low") {
    confidence <- "high"
  }

  reason <- if (length(issues) == 0L) "ok_primary_sources" else paste(unique(issues), collapse = " | ")

  list(
    confidence = confidence,
    warning = confidence != "high",
    reason = reason
  )
}

normalize_label <- function(event, tag, name) {
  tag <- trimws(as.character(tag %||% ""))
  name <- trimws(as.character(name %||% ""))
  event <- trimws(as.character(event %||% ""))
  if (nzchar(tag)) return(tag)
  if (nzchar(name)) return(name)
  if (nzchar(event)) return(event)
  "unknown"
}

classify_bucket <- function(event_text) {
  rules <- list(
    output_boundary_provenance = c(
      "boundary_output_client_value_received",
      "boundary_output_widget_inserted",
      "boundary_output_main_svg_inserted",
      "boundary_output_plotly_afterplot",
      "boundary_output_loading_cleared",
      "boundary_output_useful_ready"
    ),
    client_lifecycle = c(
      "\\|client_perf\\|",
      "main_tabs_profile",
      "main_tabs_profile_recovery",
      "main_tabs_mount",
      "tab_after_paint",
      "plotly_resize",
      "boundary_action_begin",
      "boundary_tab_click_dispatched",
      "boundary_tab_shown",
      "tab_shown",
      "boundary_tab_after_paint",
      "boundary_visible_ready"
    ),
    provider_filter = c(
      "vp_partition_provider_metadata\\(\\)",
      "vp_partition_provider_slice\\(\\)",
      "filter_vp_rows_for_resolved_hierarchy\\(\\)",
      "filter_vp_rows_for_resolved_hierarchy_"
    ),
    hierarchy_fanout = c(
      "vp_hierarchy_change_nonce_bumped",
      "vp_resolved_hierarchy_context_",
      "observeevent\\(main_tabs_panel\\)",
      "observeevent\\(data_source_choice\\)",
      "observeevent\\(source_or_trade_flow -> custom_panel_reconcile\\)",
      "data_frequency_ui_rendered",
      "commodity_choice_ui",
      "country_choice_ui",
      "pace_census_anchor_info",
      "year_filter_sync_observer",
      "(^|\\|)custom_countries_enriched(\\(\\))?(\\||$)",
      "(^|\\|)custom_types_enriched\\(\\)(\\||$)",
      "(^|\\|)type_choice_base_values_cache_(hit|miss)(\\||$)"
    ),
    tab_server_materialization = c(
      "output\\$main_tabs",
      "summary_table_executed",
      "(^|\\|)summary_table(\\||$)",
      "boundary_server_summary_table_complete",
      "reconcile_custom_comparison_non_metric_targets\\(\\)",
      "(^|\\|)historical_avg\\(\\)(\\||$)",
      "(^|\\|)projection_data\\(\\)(\\||$)",
      "(^|\\|)pace_historical_avg\\(\\)(\\||$)",
      "(^|\\|)current_year_data\\(\\)(\\||$)",
      "(^|\\|)most_recent\\(\\)(\\||$)",
      "comparison_plot",
      "trend",
      "heatmap",
      "map_"
    ),
    display_unit_mixed = c("display_month", "quantity_units_context", "mixed_volume_family_check", "metric_choice reconcile", "unit"),
    carryover_startup_load = c(
      "startup_init",
      "artifact_signature",
      "cache_setup",
      "vp_perf_test_artifact_override",
      "hybrid_data_init\\(",
      "wasde_data_init\\(",
      "nass_data_init\\(",
      "psd_data_init\\("
    )
  )

  candidates <- character(0)
  for (bucket in names(rules)) {
    pats <- rules[[bucket]]
    match_any <- any(vapply(pats, function(p) grepl(p, event_text, ignore.case = TRUE, perl = TRUE), logical(1)))
    if (isTRUE(match_any)) candidates <- c(candidates, bucket)
  }

  # Avoid known provider/hierarchy collision on filter signatures.
  if (
    "provider_filter" %in% candidates &&
    "hierarchy_fanout" %in% candidates &&
    grepl("filter_vp_rows_for_resolved_hierarchy", event_text, ignore.case = TRUE, perl = TRUE)
  ) {
    candidates <- setdiff(candidates, "hierarchy_fanout")
  }

  # Keep hierarchy provider filter events out of mixed-unit bucket overlap.
  if (
    "provider_filter" %in% candidates &&
    "display_unit_mixed" %in% candidates &&
    grepl("filter_vp_rows_for_resolved_hierarchy", event_text, ignore.case = TRUE, perl = TRUE)
  ) {
    candidates <- setdiff(candidates, "display_unit_mixed")
  }

  # Treat summary table completion boundaries as server materialization, not lifecycle.
  if (
    "client_lifecycle" %in% candidates &&
    "tab_server_materialization" %in% candidates &&
    grepl("boundary_server_summary_table_complete", event_text, ignore.case = TRUE, perl = TRUE)
  ) {
    candidates <- setdiff(candidates, "client_lifecycle")
  }

  if (length(candidates) == 0L) {
    return(list(bucket = "unclassified", candidates = "unclassified", multi_match = FALSE))
  }

  uniq_candidates <- unique(candidates)
  list(
    bucket = uniq_candidates[[1L]],
    candidates = paste(uniq_candidates, collapse = "|"),
    multi_match = length(uniq_candidates) > 1L
  )
}

compute_window <- function(ts, action_start_ts, visible_ts) {
  if (!is.finite(as.numeric(ts))) return("carryover_pre_action")

  if (is.na(action_start_ts)) return("carryover_pre_action")
  if (ts < action_start_ts) return("carryover_pre_action")

  if (is.na(visible_ts)) return("action_window")
  if (ts <= visible_ts) return("action_window")
  "post_visible_idle"
}

compute_gap_bucket <- function(curr_bucket, next_bucket, curr_window, next_window, visible_ts_present) {
  if (identical(curr_window, "post_visible_idle") || identical(next_window, "post_visible_idle")) {
    return("post_visible_idle")
  }

  if (identical(curr_bucket, next_bucket)) return(curr_bucket)

  if (!isTRUE(visible_ts_present)) {
    return("transition_wait")
  }

  if (identical(curr_bucket, "client_lifecycle") || identical(next_bucket, "client_lifecycle")) {
    return("client_wait")
  }

  "transition_wait"
}

summarize_group <- function(df) {
  if (nrow(df) == 0L) return(data.frame())

  keys <- unique(df[, c("lane", "pair_run_label", "role", "probe_type", "window", "bucket"), drop = FALSE])
  rows <- vector("list", nrow(keys))

  for (i in seq_len(nrow(keys))) {
    key <- keys[i, , drop = FALSE]
    subset <- df[
      df$lane == key$lane &
      df$pair_run_label == key$pair_run_label &
      df$role == key$role &
      df$probe_type == key$probe_type &
      df$window == key$window &
      df$bucket == key$bucket,
      , drop = FALSE
    ]

    event_vals <- safe_numeric(subset$event_elapsed_ms)
    event_vals <- event_vals[is.finite(event_vals)]
    gap_vals <- safe_numeric(subset$gap_allocated_ms)
    gap_vals <- gap_vals[is.finite(gap_vals)]
    attr_vals <- safe_numeric(subset$attributed_elapsed_ms)
    attr_vals <- attr_vals[is.finite(attr_vals)]
    ts_values <- if ("ts_utc_posix" %in% names(subset)) subset$ts_utc_posix else subset$ts_utc
    ts_range <- safe_time_range(ts_values)

    rows[[i]] <- data.frame(
      lane = key$lane,
      pair_run_label = key$pair_run_label,
      role = key$role,
      probe_type = key$probe_type,
      window = key$window,
      bucket = key$bucket,
      event_count = nrow(subset),
      count_with_event_elapsed = length(event_vals),
      total_event_elapsed_ms = if (length(event_vals) > 0L) sum(event_vals) else NA_real_,
      total_gap_allocated_ms = if (length(gap_vals) > 0L) sum(gap_vals) else NA_real_,
      total_attributed_elapsed_ms = if (length(attr_vals) > 0L) sum(attr_vals) else NA_real_,
      median_event_elapsed_ms = if (length(event_vals) > 0L) as.numeric(stats::median(event_vals)) else NA_real_,
      p90_event_elapsed_ms = if (length(event_vals) > 0L) as.numeric(stats::quantile(event_vals, probs = 0.90, names = FALSE, na.rm = TRUE)) else NA_real_,
      p95_event_elapsed_ms = if (length(event_vals) > 0L) as.numeric(stats::quantile(event_vals, probs = 0.95, names = FALSE, na.rm = TRUE)) else NA_real_,
      mad_event_elapsed_ms = if (length(event_vals) > 0L) as.numeric(stats::mad(event_vals, center = stats::median(event_vals), constant = 1.4826)) else NA_real_,
      max_event_elapsed_ms = if (length(event_vals) > 0L) max(event_vals) else NA_real_,
      first_ts_utc = ts_range[[1L]],
      last_ts_utc = ts_range[[2L]],
      multi_match_event_count = sum(subset$multi_match, na.rm = TRUE),
      unclassified_event_count = sum(subset$bucket == "unclassified", na.rm = TRUE),
      stringsAsFactors = FALSE
    )
  }

  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

summarize_inconclusive_gate <- function(run_df, min_bucket_confidence, max_unclassified_share, max_lane_inconclusive_share) {
  if (!is.data.frame(run_df) || nrow(run_df) == 0L) {
    return(data.frame(
      lane = character(0),
      pair_run_label = character(0),
      role = character(0),
      probe_type = character(0),
      run_count = integer(0),
      inconclusive_run_count = integer(0),
      inconclusive_run_share = numeric(0),
      mean_bucket_confidence = numeric(0),
      mean_unclassified_attributed_share = numeric(0),
      min_bucket_confidence_threshold = numeric(0),
      max_unclassified_share_threshold = numeric(0),
      max_lane_inconclusive_share_threshold = numeric(0),
      lane_inconclusive = logical(0),
      lane_inconclusive_reason = character(0),
      stringsAsFactors = FALSE
    ))
  }

  keys <- unique(run_df[, c("lane", "pair_run_label", "role", "probe_type"), drop = FALSE])
  rows <- vector("list", nrow(keys))

  for (i in seq_len(nrow(keys))) {
    key <- keys[i, , drop = FALSE]
    subset <- run_df[
      run_df$lane == key$lane &
      run_df$pair_run_label == key$pair_run_label &
      run_df$role == key$role &
      run_df$probe_type == key$probe_type,
      , drop = FALSE
    ]

    run_count <- nrow(subset)
    inconclusive_flags <- as.logical(subset$run_inconclusive)
    inconclusive_flags[is.na(inconclusive_flags)] <- FALSE
    inconclusive_run_count <- sum(inconclusive_flags)
    inconclusive_run_share <- if (run_count > 0L) inconclusive_run_count / run_count else NA_real_

    conf_vals <- safe_numeric(subset$bucket_confidence)
    conf_vals <- conf_vals[is.finite(conf_vals)]
    unclassified_share_vals <- safe_numeric(subset$unclassified_attributed_share)
    unclassified_share_vals <- unclassified_share_vals[is.finite(unclassified_share_vals)]

    lane_inconclusive <- is.finite(inconclusive_run_share) && inconclusive_run_share > max_lane_inconclusive_share
    lane_reason <- if (isTRUE(lane_inconclusive)) {
      sprintf(
        "inconclusive_run_share_above_threshold(%.4f>%.4f)",
        inconclusive_run_share,
        max_lane_inconclusive_share
      )
    } else {
      "ok"
    }

    rows[[i]] <- data.frame(
      lane = key$lane,
      pair_run_label = key$pair_run_label,
      role = key$role,
      probe_type = key$probe_type,
      run_count = run_count,
      inconclusive_run_count = inconclusive_run_count,
      inconclusive_run_share = inconclusive_run_share,
      mean_bucket_confidence = if (length(conf_vals) > 0L) mean(conf_vals) else NA_real_,
      mean_unclassified_attributed_share = if (length(unclassified_share_vals) > 0L) mean(unclassified_share_vals) else NA_real_,
      min_bucket_confidence_threshold = min_bucket_confidence,
      max_unclassified_share_threshold = max_unclassified_share,
      max_lane_inconclusive_share_threshold = max_lane_inconclusive_share,
      lane_inconclusive = isTRUE(lane_inconclusive),
      lane_inconclusive_reason = lane_reason,
      stringsAsFactors = FALSE
    )
  }

  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

summarize_window_confidence <- function(
    detail_df,
    run_df,
    min_bucket_confidence,
    max_unclassified_share,
    window_gap_warning_threshold,
    window_synthetic_wait_warning_threshold) {
  if (!is.data.frame(detail_df) || nrow(detail_df) == 0L) {
    return(data.frame(
      lane = character(0),
      pair_run_label = character(0),
      role = character(0),
      probe_type = character(0),
      run_id = character(0),
      window = character(0),
      detail_total_attributed_ms = numeric(0),
      observed_event_attributed_ms = numeric(0),
      synthetic_gap_attributed_ms = numeric(0),
      gap_allocated_ms_total = numeric(0),
      gap_allocated_share = numeric(0),
      synthetic_wait_attributed_ms = numeric(0),
      synthetic_wait_share = numeric(0),
      unclassified_attributed_ms = numeric(0),
      unclassified_attributed_share = numeric(0),
      multi_match_attributed_ms = numeric(0),
      multi_match_attributed_share = numeric(0),
      observed_row_bucket_confidence = numeric(0),
      detail_bucket_confidence = numeric(0),
      run_bucket_confidence = numeric(0),
      run_unclassified_attributed_share = numeric(0),
      window_inconclusive = logical(0),
      window_inconclusive_reason = character(0),
      window_gap_warning = logical(0),
      window_gap_warning_reason = character(0),
      window_synthetic_wait_warning = logical(0),
      window_synthetic_wait_warning_reason = character(0),
      window_boundary_confidence = character(0),
      window_boundary_warning = logical(0),
      window_boundary_warning_reason = character(0),
      action_start_source = character(0),
      visible_milestone_source = character(0),
      inconclusive_min_bucket_confidence = numeric(0),
      inconclusive_max_unclassified_share = numeric(0),
      window_gap_warning_threshold = numeric(0),
      window_synthetic_wait_warning_threshold = numeric(0),
      stringsAsFactors = FALSE
    ))
  }

  keys <- unique(detail_df[, c("lane", "pair_run_label", "role", "probe_type", "run_id", "window"), drop = FALSE])
  rows <- vector("list", nrow(keys))

  for (i in seq_len(nrow(keys))) {
    key <- keys[i, , drop = FALSE]
    subset <- detail_df[
      detail_df$lane == key$lane &
      detail_df$pair_run_label == key$pair_run_label &
      detail_df$role == key$role &
      detail_df$probe_type == key$probe_type &
      detail_df$run_id == key$run_id &
      detail_df$window == key$window,
      , drop = FALSE
    ]

    run_meta <- run_df[
      run_df$lane == key$lane &
      run_df$pair_run_label == key$pair_run_label &
      run_df$role == key$role &
      run_df$probe_type == key$probe_type &
      run_df$run_id == key$run_id,
      , drop = FALSE
    ]

    attr_vals <- safe_numeric(subset$attributed_elapsed_ms)
    gap_vals <- safe_numeric(subset$gap_allocated_ms)
    bucket_vals <- as.character(subset$bucket)
    event_vals <- tolower(trimws(as.character(subset$event %||% "")))
    multi_match_flags <- as.logical(subset$multi_match)
    multi_match_flags[is.na(multi_match_flags)] <- FALSE
    is_synthetic_gap <- event_vals == "gap_allocation"

    detail_total_attr <- sum(attr_vals, na.rm = TRUE)
    observed_event_attr <- sum(attr_vals[!is_synthetic_gap], na.rm = TRUE)
    synthetic_gap_attr <- sum(attr_vals[is_synthetic_gap], na.rm = TRUE)
    gap_total <- sum(gap_vals, na.rm = TRUE)
    synthetic_wait_attr <- sum(attr_vals[is_synthetic_gap & bucket_vals %in% c("transition_wait", "client_wait")], na.rm = TRUE)

    unclassified_attr <- sum(attr_vals[bucket_vals == "unclassified"], na.rm = TRUE)
    multi_match_attr <- sum(attr_vals[multi_match_flags], na.rm = TRUE)
    observed_unclassified_attr <- sum(attr_vals[!is_synthetic_gap & bucket_vals == "unclassified"], na.rm = TRUE)
    observed_multi_match_attr <- sum(attr_vals[!is_synthetic_gap & multi_match_flags], na.rm = TRUE)

    unclassified_share <- safe_ratio(unclassified_attr, detail_total_attr)
    multi_match_share <- safe_ratio(multi_match_attr, detail_total_attr)
    gap_share <- safe_ratio(gap_total, detail_total_attr)
    synthetic_wait_share <- safe_ratio(synthetic_wait_attr, detail_total_attr)

    observed_conf <- if (is.finite(observed_event_attr) && observed_event_attr > 0) {
      max(0, min(1, 1 - ((observed_unclassified_attr + observed_multi_match_attr) / observed_event_attr)))
    } else {
      NA_real_
    }

    detail_conf <- if (is.finite(detail_total_attr) && detail_total_attr > 0) {
      max(0, min(1, 1 - ((unclassified_attr + multi_match_attr) / detail_total_attr)))
    } else {
      NA_real_
    }

    window_reasons <- character(0)
    if (!is.finite(detail_conf) || is.na(detail_conf)) {
      window_reasons <- c(window_reasons, "detail_bucket_confidence_missing")
    } else if (detail_conf < min_bucket_confidence) {
      window_reasons <- c(
        window_reasons,
        sprintf("detail_bucket_confidence_below_threshold(%.4f<%.4f)", detail_conf, min_bucket_confidence)
      )
    }

    if (!is.finite(unclassified_share) || is.na(unclassified_share)) {
      window_reasons <- c(window_reasons, "window_unclassified_share_missing")
    } else if (unclassified_share > max_unclassified_share) {
      window_reasons <- c(
        window_reasons,
        sprintf("window_unclassified_share_above_threshold(%.4f>%.4f)", unclassified_share, max_unclassified_share)
      )
    }

    gap_warning <- is.finite(gap_share) && gap_share > window_gap_warning_threshold
    synthetic_wait_warning <- is.finite(synthetic_wait_share) && synthetic_wait_share > window_synthetic_wait_warning_threshold

    gap_warning_reason <- if (isTRUE(gap_warning)) {
      sprintf("gap_allocated_share_above_threshold(%.4f>%.4f)", gap_share, window_gap_warning_threshold)
    } else {
      "ok"
    }
    synthetic_wait_warning_reason <- if (isTRUE(synthetic_wait_warning)) {
      sprintf("synthetic_wait_share_above_threshold(%.4f>%.4f)", synthetic_wait_share, window_synthetic_wait_warning_threshold)
    } else {
      "ok"
    }

    run_bucket_conf <- if (nrow(run_meta) > 0L) safe_numeric(run_meta$bucket_confidence[[1L]]) else NA_real_
    run_unclassified_share <- if (nrow(run_meta) > 0L) safe_numeric(run_meta$unclassified_attributed_share[[1L]]) else NA_real_

    boundary_confidence <- if (nrow(run_meta) > 0L) as.character(run_meta$window_boundary_confidence[[1L]]) else "missing"
    boundary_reason <- if (nrow(run_meta) > 0L) as.character(run_meta$window_boundary_warning_reason[[1L]]) else "missing_run_meta"
    boundary_warning <- !(tolower(boundary_confidence) %in% c("high"))

    action_start_source <- if (nrow(run_meta) > 0L) as.character(run_meta$action_start_source[[1L]]) else "missing"
    visible_source <- if (nrow(run_meta) > 0L) as.character(run_meta$visible_milestone_source[[1L]]) else "missing"

    rows[[i]] <- data.frame(
      lane = key$lane,
      pair_run_label = key$pair_run_label,
      role = key$role,
      probe_type = key$probe_type,
      run_id = key$run_id,
      window = key$window,
      detail_total_attributed_ms = detail_total_attr,
      observed_event_attributed_ms = observed_event_attr,
      synthetic_gap_attributed_ms = synthetic_gap_attr,
      gap_allocated_ms_total = gap_total,
      gap_allocated_share = gap_share,
      synthetic_wait_attributed_ms = synthetic_wait_attr,
      synthetic_wait_share = synthetic_wait_share,
      unclassified_attributed_ms = unclassified_attr,
      unclassified_attributed_share = unclassified_share,
      multi_match_attributed_ms = multi_match_attr,
      multi_match_attributed_share = multi_match_share,
      observed_row_bucket_confidence = observed_conf,
      detail_bucket_confidence = detail_conf,
      run_bucket_confidence = run_bucket_conf,
      run_unclassified_attributed_share = run_unclassified_share,
      window_inconclusive = length(window_reasons) > 0L,
      window_inconclusive_reason = if (length(window_reasons) > 0L) paste(window_reasons, collapse = " | ") else "ok",
      window_gap_warning = isTRUE(gap_warning),
      window_gap_warning_reason = gap_warning_reason,
      window_synthetic_wait_warning = isTRUE(synthetic_wait_warning),
      window_synthetic_wait_warning_reason = synthetic_wait_warning_reason,
      window_boundary_confidence = boundary_confidence,
      window_boundary_warning = isTRUE(boundary_warning),
      window_boundary_warning_reason = boundary_reason,
      action_start_source = action_start_source,
      visible_milestone_source = visible_source,
      inconclusive_min_bucket_confidence = min_bucket_confidence,
      inconclusive_max_unclassified_share = max_unclassified_share,
      window_gap_warning_threshold = window_gap_warning_threshold,
      window_synthetic_wait_warning_threshold = window_synthetic_wait_warning_threshold,
      stringsAsFactors = FALSE
    )
  }

  out <- do.call(rbind, rows)
  out <- out[order(out$lane, out$role, out$run_id, out$window), , drop = FALSE]
  rownames(out) <- NULL
  out
}

main <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  repo_root <- resolve_repo_root(getwd())
  vp_clone_dir <- file.path(repo_root, "VP Clone")
  logs_dir <- file.path(vp_clone_dir, "Logs")
  dir.create(logs_dir, recursive = TRUE, showWarnings = FALSE)

  inventory_arg <- trimws(as.character(parse_arg_value(args, "inventory", default = "")))
  if (!nzchar(inventory_arg)) {
    stop("Missing required --inventory argument for 8C decomposition.", call. = FALSE)
  }

  inventory_path <- normalizePath(file.path(vp_clone_dir, inventory_arg), winslash = "/", mustWork = FALSE)
  if (!file.exists(inventory_path)) {
    inventory_path <- normalizePath(inventory_arg, winslash = "/", mustWork = FALSE)
  }
  if (!file.exists(inventory_path)) {
    stop(sprintf("Inventory file not found: %s", inventory_arg), call. = FALSE)
  }

  label <- trimws(as.character(parse_arg_value(args, "label", default = "step25c_tranche8c_decomposition")))
  max_logs <- suppressWarnings(as.integer(parse_arg_value(args, "max-logs", default = "0")))
  if (!is.finite(max_logs) || is.na(max_logs) || max_logs < 0L) max_logs <- 0L

  inconclusive_min_bucket_confidence <- parse_double_arg(args, "inconclusive-min-bucket-confidence", default = 0.70)
  inconclusive_max_unclassified_share <- parse_double_arg(args, "inconclusive-max-unclassified-share", default = 0.20)
  inconclusive_max_lane_inconclusive_share <- parse_double_arg(args, "inconclusive-max-lane-inconclusive-share", default = 0.34)
  window_gap_warning_threshold <- parse_double_arg(args, "window-gap-warning-threshold", default = 0.50)
  window_synthetic_wait_warning_threshold <- parse_double_arg(args, "window-synthetic-wait-warning-threshold", default = 0.40)
  fail_on_inconclusive <- is_truthy(parse_arg_value(args, "fail-on-inconclusive", default = "false"), default = FALSE)

  if (!is.finite(inconclusive_min_bucket_confidence) || is.na(inconclusive_min_bucket_confidence)) inconclusive_min_bucket_confidence <- 0.70
  if (!is.finite(inconclusive_max_unclassified_share) || is.na(inconclusive_max_unclassified_share)) inconclusive_max_unclassified_share <- 0.20
  if (!is.finite(inconclusive_max_lane_inconclusive_share) || is.na(inconclusive_max_lane_inconclusive_share)) inconclusive_max_lane_inconclusive_share <- 0.34
  if (!is.finite(window_gap_warning_threshold) || is.na(window_gap_warning_threshold)) window_gap_warning_threshold <- 0.50
  if (!is.finite(window_synthetic_wait_warning_threshold) || is.na(window_synthetic_wait_warning_threshold)) window_synthetic_wait_warning_threshold <- 0.40

  inconclusive_min_bucket_confidence <- max(0, min(1, inconclusive_min_bucket_confidence))
  inconclusive_max_unclassified_share <- max(0, min(1, inconclusive_max_unclassified_share))
  inconclusive_max_lane_inconclusive_share <- max(0, min(1, inconclusive_max_lane_inconclusive_share))
  window_gap_warning_threshold <- max(0, min(1, window_gap_warning_threshold))
  window_synthetic_wait_warning_threshold <- max(0, min(1, window_synthetic_wait_warning_threshold))

  single_log_path <- trimws(as.character(parse_arg_value(args, "single-log-path", default = "")))
  include_startup <- is_truthy(parse_arg_value(args, "include-startup", default = "false"), default = FALSE)

  inventory <- utils::read.csv(inventory_path, stringsAsFactors = FALSE, check.names = FALSE)
  if (!is.data.frame(inventory) || nrow(inventory) == 0L) {
    stop("Inventory file has no rows.", call. = FALSE)
  }

  if (!include_startup) {
    inventory <- inventory[inventory$probe_type == "single_action", , drop = FALSE]
  }

  inventory <- inventory[inventory$integrity_status == "ok", , drop = FALSE]

  if (nzchar(single_log_path)) {
    norm_single <- normalizePath(single_log_path, winslash = "/", mustWork = FALSE)
    inventory <- inventory[normalizePath(inventory$runtime_log_path, winslash = "/", mustWork = FALSE) == norm_single, , drop = FALSE]
  }

  if (max_logs > 0L && nrow(inventory) > max_logs) {
    inventory <- inventory[seq_len(max_logs), , drop = FALSE]
  }

  if (nrow(inventory) == 0L) {
    stop("No inventory rows selected for decomposition.", call. = FALSE)
  }

  timestamp_token <- format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC")
  prefix <- file.path(logs_dir, paste0("vp_perf_acceptance_decomposition_", label, "_", timestamp_token))

  detail_rows <- list()
  run_rows <- list()
  row_index <- 0L

  for (i in seq_len(nrow(inventory))) {
    meta <- inventory[i, , drop = FALSE]
    runtime_path <- normalizePath(meta$runtime_log_path[[1L]], winslash = "/", mustWork = FALSE)
    if (!file.exists(runtime_path)) {
      next
    }

    runtime_df <- read_runtime_log(runtime_path)
    if (nrow(runtime_df) == 0L) {
      next
    }

    ts_utc <- as.character(runtime_df$ts_utc %||% NA_character_)
    ts_posix <- suppressWarnings(as.POSIXct(ts_utc, tz = "UTC", format = "%Y-%m-%dT%H:%M:%OSZ"))
    fallback_posix <- suppressWarnings(as.POSIXct(ts_utc, tz = "UTC"))
    ts_posix[is.na(ts_posix)] <- fallback_posix[is.na(ts_posix)]
    runtime_df$ts_utc_posix <- ts_posix

    event <- as.character(runtime_df$event %||% "")
    tag <- as.character(runtime_df$tag %||% "")
    name <- as.character(runtime_df$name %||% "")
    label_text <- mapply(normalize_label, event = event, tag = tag, name = name, USE.NAMES = FALSE)

    elapsed_seconds <- safe_numeric(runtime_df$elapsed_seconds)
    elapsed_ms <- safe_numeric(runtime_df$elapsed_ms)
    action_elapsed_ms <- safe_numeric(runtime_df$action_elapsed_ms)

    event_elapsed_ms <- rep(NA_real_, nrow(runtime_df))
    has_seconds <- is.finite(elapsed_seconds)
    has_elapsed_ms <- is.finite(elapsed_ms)
    has_action_ms <- is.finite(action_elapsed_ms)
    event_elapsed_ms[has_seconds] <- elapsed_seconds[has_seconds] * 1000
    event_elapsed_ms[!has_seconds & has_elapsed_ms] <- elapsed_ms[!has_seconds & has_elapsed_ms]
    event_elapsed_ms[!has_seconds & !has_elapsed_ms & has_action_ms] <- action_elapsed_ms[!has_seconds & !has_elapsed_ms & has_action_ms]

    event_text <- tolower(paste(event, tag, name, label_text, sep = "|"))
    bucket_info <- lapply(event_text, classify_bucket)
    bucket <- vapply(bucket_info, function(x) x$bucket, character(1))
    bucket_candidates <- vapply(bucket_info, function(x) x$candidates, character(1))
    multi_match <- vapply(bucket_info, function(x) x$multi_match, logical(1))

    action_start_info <- resolve_action_start(runtime_df, event = event, tag = tag)
    action_start_ts <- action_start_info$ts
    action_start_source <- action_start_info$source

    visible_info <- resolve_visible_milestone(runtime_df, event = event, tag = tag, action_start_ts = action_start_ts)
    visible_ts <- visible_info$ts
    visible_source <- visible_info$source

    window_boundary_info <- derive_window_boundary_quality(action_start_source, visible_source)

    window <- vapply(runtime_df$ts_utc_posix, function(ts) compute_window(ts, action_start_ts, visible_ts), character(1))

    gap_allocated_ms <- rep(0, nrow(runtime_df))
    gap_bucket <- rep("", nrow(runtime_df))

    synthetic_gap_attributed_ms <- 0
    synthetic_wait_attributed_ms <- 0

    if (nrow(runtime_df) > 1L) {
      ord <- order(runtime_df$ts_utc_posix, na.last = TRUE)
      runtime_df <- runtime_df[ord, , drop = FALSE]
      event <- event[ord]
      tag <- tag[ord]
      name <- name[ord]
      label_text <- label_text[ord]
      event_elapsed_ms <- event_elapsed_ms[ord]
      bucket <- bucket[ord]
      bucket_candidates <- bucket_candidates[ord]
      multi_match <- multi_match[ord]
      window <- window[ord]
      event_text <- event_text[ord]
      gap_allocated_ms <- gap_allocated_ms[ord]
      gap_bucket <- gap_bucket[ord]

      for (j in seq_len(nrow(runtime_df) - 1L)) {
        ts_curr <- runtime_df$ts_utc_posix[[j]]
        ts_next <- runtime_df$ts_utc_posix[[j + 1L]]
        if (!is.finite(as.numeric(ts_curr)) || !is.finite(as.numeric(ts_next))) next
        gap_ms <- as.numeric(difftime(ts_next, ts_curr, units = "secs")) * 1000
        if (!is.finite(gap_ms) || gap_ms <= 0) next

        gb <- compute_gap_bucket(
          curr_bucket = bucket[[j]],
          next_bucket = bucket[[j + 1L]],
          curr_window = window[[j]],
          next_window = window[[j + 1L]],
          visible_ts_present = !is.na(visible_ts)
        )

        if (identical(gb, bucket[[j]])) {
          gap_allocated_ms[[j]] <- gap_allocated_ms[[j]] + gap_ms
          gap_bucket[[j]] <- gb
        } else {
          synthetic_gap_attributed_ms <- synthetic_gap_attributed_ms + gap_ms
          if (gb %in% c("transition_wait", "client_wait")) {
            synthetic_wait_attributed_ms <- synthetic_wait_attributed_ms + gap_ms
          }

          row_index <- row_index + 1L
          detail_rows[[row_index]] <- data.frame(
            lane = meta$lane[[1L]],
            pair_run_label = meta$pair_run_label[[1L]],
            role = meta$role[[1L]],
            probe_type = meta$probe_type[[1L]],
            run_id = meta$run_id[[1L]],
            runtime_log_path = runtime_path,
            event = "gap_allocation",
            tag = paste0("gap:", gb),
            name = "",
            summary_label = "gap_allocation",
            bucket = gb,
            bucket_candidates = gb,
            multi_match = FALSE,
            window = window[[j]],
            ts_utc = as.character(ts_curr),
            ts_utc_posix = as.character(ts_curr),
            event_elapsed_ms = 0,
            gap_allocated_ms = gap_ms,
            attributed_elapsed_ms = gap_ms,
            stringsAsFactors = FALSE
          )
        }
      }
    }

    attributed_elapsed_ms <- ifelse(is.finite(event_elapsed_ms), event_elapsed_ms, 0) + gap_allocated_ms

    run_total_attr <- sum(attributed_elapsed_ms, na.rm = TRUE)
    run_unclassified_attr <- sum(attributed_elapsed_ms[bucket == "unclassified"], na.rm = TRUE)
    run_multi_match_attr <- sum(attributed_elapsed_ms[multi_match], na.rm = TRUE)
    run_bad_attr <- run_unclassified_attr +
      run_multi_match_attr
    run_conf <- if (is.finite(run_total_attr) && run_total_attr > 0) max(0, min(1, 1 - (run_bad_attr / run_total_attr))) else NA_real_
    run_unclassified_share <- if (is.finite(run_total_attr) && run_total_attr > 0) run_unclassified_attr / run_total_attr else NA_real_

    same_bucket_gap_allocated_ms <- sum(gap_allocated_ms, na.rm = TRUE)
    detail_total_attributed_ms <- run_total_attr + synthetic_gap_attributed_ms
    detail_gap_allocated_ms <- same_bucket_gap_allocated_ms + synthetic_gap_attributed_ms
    detail_gap_allocated_share <- safe_ratio(detail_gap_allocated_ms, detail_total_attributed_ms)
    detail_unclassified_attributed_ms <- run_unclassified_attr
    detail_unclassified_attributed_share <- safe_ratio(detail_unclassified_attributed_ms, detail_total_attributed_ms)
    detail_multi_match_attributed_ms <- run_multi_match_attr
    detail_bucket_confidence <- if (is.finite(detail_total_attributed_ms) && detail_total_attributed_ms > 0) {
      max(0, min(1, 1 - ((detail_unclassified_attributed_ms + detail_multi_match_attributed_ms) / detail_total_attributed_ms)))
    } else {
      NA_real_
    }
    detail_synthetic_wait_share <- safe_ratio(synthetic_wait_attributed_ms, detail_total_attributed_ms)

    run_inconclusive_reasons <- character(0)
    if (!is.finite(run_conf) || is.na(run_conf)) {
      run_inconclusive_reasons <- c(run_inconclusive_reasons, "bucket_confidence_missing")
    } else if (run_conf < inconclusive_min_bucket_confidence) {
      run_inconclusive_reasons <- c(
        run_inconclusive_reasons,
        sprintf("bucket_confidence_below_threshold(%.4f<%.4f)", run_conf, inconclusive_min_bucket_confidence)
      )
    }

    if (!is.finite(run_unclassified_share) || is.na(run_unclassified_share)) {
      run_inconclusive_reasons <- c(run_inconclusive_reasons, "unclassified_share_missing")
    } else if (run_unclassified_share > inconclusive_max_unclassified_share) {
      run_inconclusive_reasons <- c(
        run_inconclusive_reasons,
        sprintf("unclassified_share_above_threshold(%.4f>%.4f)", run_unclassified_share, inconclusive_max_unclassified_share)
      )
    }

    run_inconclusive <- length(run_inconclusive_reasons) > 0L

    row_index <- row_index + 1L
    detail_rows[[row_index]] <- data.frame(
      lane = meta$lane[[1L]],
      pair_run_label = meta$pair_run_label[[1L]],
      role = meta$role[[1L]],
      probe_type = meta$probe_type[[1L]],
      run_id = meta$run_id[[1L]],
      runtime_log_path = runtime_path,
      event = event,
      tag = tag,
      name = name,
      summary_label = label_text,
      bucket = bucket,
      bucket_candidates = bucket_candidates,
      multi_match = multi_match,
      window = window,
      ts_utc = as.character(runtime_df$ts_utc_posix),
      ts_utc_posix = as.character(runtime_df$ts_utc_posix),
      event_elapsed_ms = event_elapsed_ms,
      gap_allocated_ms = gap_allocated_ms,
      attributed_elapsed_ms = attributed_elapsed_ms,
      stringsAsFactors = FALSE
    )

    run_rows[[length(run_rows) + 1L]] <- data.frame(
      lane = meta$lane[[1L]],
      pair_run_label = meta$pair_run_label[[1L]],
      role = meta$role[[1L]],
      probe_type = meta$probe_type[[1L]],
      run_id = meta$run_id[[1L]],
      runtime_log_path = runtime_path,
      action_start_ts_utc = as.character(action_start_ts),
      action_start_source = action_start_source,
      visible_ts_utc = as.character(visible_ts),
      visible_milestone_source = visible_source,
      has_visible_milestone = !is.na(visible_ts),
      window_boundary_confidence = as.character(window_boundary_info$confidence),
      window_boundary_warning = isTRUE(window_boundary_info$warning),
      window_boundary_warning_reason = as.character(window_boundary_info$reason),
      event_count = nrow(runtime_df),
      unclassified_event_count = sum(bucket == "unclassified", na.rm = TRUE),
      multi_match_event_count = sum(multi_match, na.rm = TRUE),
      run_total_attributed_ms = run_total_attr,
      observed_row_bucket_confidence = run_conf,
      unclassified_attributed_ms = run_unclassified_attr,
      unclassified_attributed_share = run_unclassified_share,
      bucket_confidence = run_conf,
      detail_total_attributed_ms = detail_total_attributed_ms,
      detail_gap_allocated_ms = detail_gap_allocated_ms,
      detail_gap_allocated_share = detail_gap_allocated_share,
      detail_synthetic_gap_attributed_ms = synthetic_gap_attributed_ms,
      detail_synthetic_wait_attributed_ms = synthetic_wait_attributed_ms,
      detail_synthetic_wait_share = detail_synthetic_wait_share,
      detail_unclassified_attributed_ms = detail_unclassified_attributed_ms,
      detail_unclassified_attributed_share = detail_unclassified_attributed_share,
      detail_multi_match_attributed_ms = detail_multi_match_attributed_ms,
      detail_bucket_confidence = detail_bucket_confidence,
      inconclusive_min_bucket_confidence = inconclusive_min_bucket_confidence,
      inconclusive_max_unclassified_share = inconclusive_max_unclassified_share,
      run_inconclusive = run_inconclusive,
      run_inconclusive_reason = if (run_inconclusive) paste(run_inconclusive_reasons, collapse = " | ") else "ok",
      stringsAsFactors = FALSE
    )
  }

  if (length(detail_rows) == 0L) {
    stop("No decomposed rows were produced.", call. = FALSE)
  }

  detail <- do.call(rbind, detail_rows)
  run_summary <- if (length(run_rows) > 0L) do.call(rbind, run_rows) else data.frame()

  summary <- summarize_group(detail)
  if (nrow(summary) > 0L) {
    summary <- summary[order(summary$lane, summary$role, summary$window, -safe_numeric(summary$total_attributed_elapsed_ms)), , drop = FALSE]
  }

  inconclusive_gate <- summarize_inconclusive_gate(
    run_df = run_summary,
    min_bucket_confidence = inconclusive_min_bucket_confidence,
    max_unclassified_share = inconclusive_max_unclassified_share,
    max_lane_inconclusive_share = inconclusive_max_lane_inconclusive_share
  )

  window_confidence <- summarize_window_confidence(
    detail_df = detail,
    run_df = run_summary,
    min_bucket_confidence = inconclusive_min_bucket_confidence,
    max_unclassified_share = inconclusive_max_unclassified_share,
    window_gap_warning_threshold = window_gap_warning_threshold,
    window_synthetic_wait_warning_threshold = window_synthetic_wait_warning_threshold
  )

  count_true <- function(flags) {
    out <- as.logical(flags)
    out[is.na(out)] <- FALSE
    sum(out)
  }

  action_window_df <- if (nrow(window_confidence) > 0L) window_confidence[window_confidence$window == "action_window", , drop = FALSE] else data.frame()
  post_visible_df <- if (nrow(window_confidence) > 0L) window_confidence[window_confidence$window == "post_visible_idle", , drop = FALSE] else data.frame()
  carryover_df <- if (nrow(window_confidence) > 0L) window_confidence[window_confidence$window == "carryover_pre_action", , drop = FALSE] else data.frame()

  action_window_inconclusive_count <- if (nrow(action_window_df) > 0L) count_true(action_window_df$window_inconclusive) else 0L
  action_window_inconclusive_share <- if (nrow(action_window_df) > 0L) action_window_inconclusive_count / nrow(action_window_df) else NA_real_
  post_visible_inconclusive_count <- if (nrow(post_visible_df) > 0L) count_true(post_visible_df$window_inconclusive) else 0L
  post_visible_inconclusive_share <- if (nrow(post_visible_df) > 0L) post_visible_inconclusive_count / nrow(post_visible_df) else NA_real_

  action_window_gap_warning_count <- if (nrow(action_window_df) > 0L) count_true(action_window_df$window_gap_warning) else 0L
  action_window_gap_warning_share <- if (nrow(action_window_df) > 0L) action_window_gap_warning_count / nrow(action_window_df) else NA_real_
  action_window_synthetic_wait_warning_count <- if (nrow(action_window_df) > 0L) count_true(action_window_df$window_synthetic_wait_warning) else 0L
  action_window_synthetic_wait_warning_share <- if (nrow(action_window_df) > 0L) action_window_synthetic_wait_warning_count / nrow(action_window_df) else NA_real_

  post_visible_gap_warning_count <- if (nrow(post_visible_df) > 0L) count_true(post_visible_df$window_gap_warning) else 0L
  post_visible_gap_warning_share <- if (nrow(post_visible_df) > 0L) post_visible_gap_warning_count / nrow(post_visible_df) else NA_real_
  post_visible_synthetic_wait_warning_count <- if (nrow(post_visible_df) > 0L) count_true(post_visible_df$window_synthetic_wait_warning) else 0L
  post_visible_synthetic_wait_warning_share <- if (nrow(post_visible_df) > 0L) post_visible_synthetic_wait_warning_count / nrow(post_visible_df) else NA_real_

  inconclusive_run_count <- if (nrow(run_summary) > 0L) {
    flags <- as.logical(run_summary$run_inconclusive)
    flags[is.na(flags)] <- FALSE
    sum(flags)
  } else {
    0L
  }
  inconclusive_run_share <- if (nrow(run_summary) > 0L) inconclusive_run_count / nrow(run_summary) else NA_real_
  inconclusive_lane_count <- if (nrow(inconclusive_gate) > 0L) {
    flags <- as.logical(inconclusive_gate$lane_inconclusive)
    flags[is.na(flags)] <- FALSE
    sum(flags)
  } else {
    0L
  }
  inconclusive_lane_share <- if (nrow(inconclusive_gate) > 0L) inconclusive_lane_count / nrow(inconclusive_gate) else NA_real_

  detail_path <- paste0(prefix, "_detail.csv")
  summary_path <- paste0(prefix, "_summary.csv")
  run_path <- paste0(prefix, "_runs.csv")
  inconclusive_gate_path <- paste0(prefix, "_inconclusive_gate.csv")
  window_confidence_path <- paste0(prefix, "_window_confidence.csv")
  summary_json_path <- paste0(prefix, "_summary.json")

  utils::write.csv(detail, detail_path, row.names = FALSE, na = "")
  utils::write.csv(summary, summary_path, row.names = FALSE, na = "")
  utils::write.csv(run_summary, run_path, row.names = FALSE, na = "")
  utils::write.csv(inconclusive_gate, inconclusive_gate_path, row.names = FALSE, na = "")
  utils::write.csv(window_confidence, window_confidence_path, row.names = FALSE, na = "")

  summary_payload <- list(
    label = label,
    inventory_path = inventory_path,
    selected_inventory_rows = nrow(inventory),
    detail_rows = nrow(detail),
    run_rows = nrow(run_summary),
    summary_rows = nrow(summary),
    inconclusive_gate_rows = nrow(inconclusive_gate),
    window_confidence_rows = nrow(window_confidence),
    action_window_rows = nrow(action_window_df),
    post_visible_rows = nrow(post_visible_df),
    carryover_rows = nrow(carryover_df),
    action_window_inconclusive_count = action_window_inconclusive_count,
    action_window_inconclusive_share = action_window_inconclusive_share,
    post_visible_inconclusive_count = post_visible_inconclusive_count,
    post_visible_inconclusive_share = post_visible_inconclusive_share,
    action_window_gap_warning_count = action_window_gap_warning_count,
    action_window_gap_warning_share = action_window_gap_warning_share,
    action_window_synthetic_wait_warning_count = action_window_synthetic_wait_warning_count,
    action_window_synthetic_wait_warning_share = action_window_synthetic_wait_warning_share,
    post_visible_gap_warning_count = post_visible_gap_warning_count,
    post_visible_gap_warning_share = post_visible_gap_warning_share,
    post_visible_synthetic_wait_warning_count = post_visible_synthetic_wait_warning_count,
    post_visible_synthetic_wait_warning_share = post_visible_synthetic_wait_warning_share,
    inconclusive_run_count = inconclusive_run_count,
    inconclusive_run_share = inconclusive_run_share,
    inconclusive_lane_count = inconclusive_lane_count,
    inconclusive_lane_share = inconclusive_lane_share,
    inconclusive_min_bucket_confidence = inconclusive_min_bucket_confidence,
    inconclusive_max_unclassified_share = inconclusive_max_unclassified_share,
    inconclusive_max_lane_inconclusive_share = inconclusive_max_lane_inconclusive_share,
    window_gap_warning_threshold = window_gap_warning_threshold,
    window_synthetic_wait_warning_threshold = window_synthetic_wait_warning_threshold,
    fail_on_inconclusive = isTRUE(fail_on_inconclusive),
    detail_csv = normalizePath(detail_path, winslash = "/", mustWork = FALSE),
    summary_csv = normalizePath(summary_path, winslash = "/", mustWork = FALSE),
    runs_csv = normalizePath(run_path, winslash = "/", mustWork = FALSE),
    inconclusive_gate_csv = normalizePath(inconclusive_gate_path, winslash = "/", mustWork = FALSE),
    window_confidence_csv = normalizePath(window_confidence_path, winslash = "/", mustWork = FALSE)
  )
  if (requireNamespace("jsonlite", quietly = TRUE)) {
    writeLines(jsonlite::toJSON(summary_payload, pretty = TRUE, auto_unbox = TRUE), summary_json_path)
  }

  cat("VP_PERF_8C_DECOMP_START\n")
  cat(sprintf("VP_PERF_8C_DECOMP_LABEL=%s\n", label))
  cat(sprintf("VP_PERF_8C_DECOMP_INVENTORY=%s\n", inventory_path))
  cat(sprintf("VP_PERF_8C_DECOMP_SELECTED_ROWS=%d\n", nrow(inventory)))
  cat(sprintf("VP_PERF_8C_DECOMP_DETAIL_ROWS=%d\n", nrow(detail)))
  cat(sprintf("VP_PERF_8C_DECOMP_RUN_ROWS=%d\n", nrow(run_summary)))
  cat(sprintf("VP_PERF_8C_DECOMP_SUMMARY_ROWS=%d\n", nrow(summary)))
  cat(sprintf("VP_PERF_8C_DECOMP_DETAIL_CSV=%s\n", normalizePath(detail_path, winslash = "/", mustWork = FALSE)))
  cat(sprintf("VP_PERF_8C_DECOMP_SUMMARY_CSV=%s\n", normalizePath(summary_path, winslash = "/", mustWork = FALSE)))
  cat(sprintf("VP_PERF_8C_DECOMP_RUNS_CSV=%s\n", normalizePath(run_path, winslash = "/", mustWork = FALSE)))
  cat(sprintf("VP_PERF_8C_DECOMP_INCONCLUSIVE_GATE_CSV=%s\n", normalizePath(inconclusive_gate_path, winslash = "/", mustWork = FALSE)))
  cat(sprintf("VP_PERF_8C_DECOMP_WINDOW_CONFIDENCE_CSV=%s\n", normalizePath(window_confidence_path, winslash = "/", mustWork = FALSE)))
  cat(sprintf("VP_PERF_8C_DECOMP_INCONCLUSIVE_RUN_COUNT=%d\n", inconclusive_run_count))
  cat(sprintf("VP_PERF_8C_DECOMP_INCONCLUSIVE_RUN_SHARE=%s\n", ifelse(is.finite(inconclusive_run_share), sprintf("%.6f", inconclusive_run_share), "NA")))
  cat(sprintf("VP_PERF_8C_DECOMP_INCONCLUSIVE_LANE_COUNT=%d\n", inconclusive_lane_count))
  cat(sprintf("VP_PERF_8C_DECOMP_INCONCLUSIVE_LANE_SHARE=%s\n", ifelse(is.finite(inconclusive_lane_share), sprintf("%.6f", inconclusive_lane_share), "NA")))
  cat(sprintf("VP_PERF_8C_DECOMP_ACTION_WINDOW_INCONCLUSIVE_COUNT=%d\n", action_window_inconclusive_count))
  cat(sprintf("VP_PERF_8C_DECOMP_ACTION_WINDOW_INCONCLUSIVE_SHARE=%s\n", ifelse(is.finite(action_window_inconclusive_share), sprintf("%.6f", action_window_inconclusive_share), "NA")))
  cat(sprintf("VP_PERF_8C_DECOMP_ACTION_WINDOW_GAP_WARNING_SHARE=%s\n", ifelse(is.finite(action_window_gap_warning_share), sprintf("%.6f", action_window_gap_warning_share), "NA")))
  cat(sprintf("VP_PERF_8C_DECOMP_ACTION_WINDOW_SYNTHETIC_WAIT_WARNING_SHARE=%s\n", ifelse(is.finite(action_window_synthetic_wait_warning_share), sprintf("%.6f", action_window_synthetic_wait_warning_share), "NA")))
  cat(sprintf("VP_PERF_8C_DECOMP_POST_VISIBLE_INCONCLUSIVE_COUNT=%d\n", post_visible_inconclusive_count))
  cat(sprintf("VP_PERF_8C_DECOMP_POST_VISIBLE_INCONCLUSIVE_SHARE=%s\n", ifelse(is.finite(post_visible_inconclusive_share), sprintf("%.6f", post_visible_inconclusive_share), "NA")))
  cat(sprintf("VP_PERF_8C_DECOMP_POST_VISIBLE_GAP_WARNING_SHARE=%s\n", ifelse(is.finite(post_visible_gap_warning_share), sprintf("%.6f", post_visible_gap_warning_share), "NA")))
  cat(sprintf("VP_PERF_8C_DECOMP_POST_VISIBLE_SYNTHETIC_WAIT_WARNING_SHARE=%s\n", ifelse(is.finite(post_visible_synthetic_wait_warning_share), sprintf("%.6f", post_visible_synthetic_wait_warning_share), "NA")))
  cat(sprintf("VP_PERF_8C_DECOMP_FAIL_ON_INCONCLUSIVE=%s\n", ifelse(isTRUE(fail_on_inconclusive), "TRUE", "FALSE")))
  cat(sprintf("VP_PERF_8C_DECOMP_INCONCLUSIVE_MIN_BUCKET_CONFIDENCE=%.6f\n", inconclusive_min_bucket_confidence))
  cat(sprintf("VP_PERF_8C_DECOMP_INCONCLUSIVE_MAX_UNCLASSIFIED_SHARE=%.6f\n", inconclusive_max_unclassified_share))
  cat(sprintf("VP_PERF_8C_DECOMP_INCONCLUSIVE_MAX_LANE_INCONCLUSIVE_SHARE=%.6f\n", inconclusive_max_lane_inconclusive_share))
  cat(sprintf("VP_PERF_8C_DECOMP_WINDOW_GAP_WARNING_THRESHOLD=%.6f\n", window_gap_warning_threshold))
  cat(sprintf("VP_PERF_8C_DECOMP_WINDOW_SYNTHETIC_WAIT_WARNING_THRESHOLD=%.6f\n", window_synthetic_wait_warning_threshold))
  if (file.exists(summary_json_path)) {
    cat(sprintf("VP_PERF_8C_DECOMP_SUMMARY_JSON=%s\n", normalizePath(summary_json_path, winslash = "/", mustWork = FALSE)))
  }

  if (isTRUE(fail_on_inconclusive) && inconclusive_lane_count > 0L) {
    failing <- inconclusive_gate[as.logical(inconclusive_gate$lane_inconclusive), c("lane", "role"), drop = FALSE]
    failing_labels <- if (nrow(failing) > 0L) paste(paste0(failing$lane, "/", failing$role), collapse = ", ") else "unknown"
    stop(sprintf("Inconclusive gate failed for %d lane(s): %s", inconclusive_lane_count, failing_labels), call. = FALSE)
  }

  cat("VP_PERF_8C_DECOMP_COMPLETE\n")
}

main()
