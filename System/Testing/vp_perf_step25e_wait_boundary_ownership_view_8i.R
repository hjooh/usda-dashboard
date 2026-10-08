parse_arg_value <- function(args, key, default = NULL) {
  prefix <- paste0("--", key, "=")
  hits <- args[startsWith(args, prefix)]
  if (length(hits) == 0L) return(default)
  sub(prefix, "", hits[[length(hits)]], fixed = TRUE)
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

  stop("Could not resolve repository root for 8I wait-boundary ownership view.", call. = FALSE)
}

safe_numeric <- function(x) {
  suppressWarnings(as.numeric(x))
}

coalesce_chr <- function(x) {
  out <- as.character(x)
  out[is.na(out)] <- ""
  out
}

require_cols <- function(df, cols, df_name) {
  missing <- setdiff(cols, names(df))
  if (length(missing) > 0L) {
    stop(sprintf("%s missing required columns: %s", df_name, paste(missing, collapse = ", ")), call. = FALSE)
  }
}

add_missing_cols <- function(df, cols) {
  for (col in cols) {
    if (!col %in% names(df)) df[[col]] <- NA
  }
  df
}

resolve_existing_path <- function(path_arg, vp_clone_dir, label) {
  path_arg <- trimws(as.character(path_arg))
  if (!nzchar(path_arg)) stop(sprintf("Missing required --%s argument.", label), call. = FALSE)

  path <- normalizePath(path_arg, winslash = "/", mustWork = FALSE)
  if (!file.exists(path)) {
    path <- normalizePath(file.path(vp_clone_dir, path_arg), winslash = "/", mustWork = FALSE)
  }
  if (!file.exists(path)) stop(sprintf("%s file not found: %s", label, path_arg), call. = FALSE)
  path
}

median_numeric <- function(x) {
  vals <- safe_numeric(x)
  vals <- vals[is.finite(vals)]
  if (length(vals) == 0L) return(NA_real_)
  as.numeric(stats::median(vals))
}

sum_numeric <- function(x) {
  vals <- safe_numeric(x)
  vals <- vals[is.finite(vals)]
  if (length(vals) == 0L) return(0)
  sum(vals)
}

positive_or_zero <- function(x) {
  val <- safe_numeric(x)[[1L]]
  if (!is.finite(val) || is.na(val) || val < 0) return(0)
  val
}

max_positive <- function(...) {
  vals <- unlist(list(...), use.names = FALSE)
  vals <- safe_numeric(vals)
  vals <- vals[is.finite(vals) & vals > 0]
  if (length(vals) == 0L) return(0)
  max(vals)
}

sum_positive <- function(...) {
  vals <- unlist(list(...), use.names = FALSE)
  vals <- safe_numeric(vals)
  vals <- vals[is.finite(vals) & vals > 0]
  if (length(vals) == 0L) return(0)
  sum(vals)
}

normalize_owner <- function(owner) {
  owner <- trimws(as.character(owner))
  owner[!nzchar(owner) | is.na(owner)] <- "mixed/no-decision"
  owner
}

classify_action_ownership <- function(row, threshold_ms) {
  visible_to_ready <- safe_numeric(row$gap_visible_milestone_to_readiness_predicate_passed_ms)[[1L]]
  total_action <- safe_numeric(row$total_action_ms)[[1L]]
  boundary_visible <- safe_numeric(row$boundary_visible_ready_ms)[[1L]]
  visible_milestone <- safe_numeric(row$visible_milestone_ms)[[1L]]

  output_ms <- max_positive(
    row$gap_visible_milestone_to_output_visible_nonzero_ms,
    row$gap_visible_milestone_to_widget_inserted_ms,
    row$gap_visible_milestone_to_main_svg_inserted_ms,
    row$gap_visible_milestone_to_plotly_afterplot_ms,
    row$gap_visible_milestone_to_loading_indicator_cleared_ms
  )
  client_echo_ms <- positive_or_zero(row$gap_readiness_predicate_passed_to_client_echo_ready_ms)
  resize_ms <- sum_positive(
    row$gap_resize_sent_to_handler_enter_ms,
    row$gap_handler_enter_to_handler_flush_ms,
    row$gap_handler_flush_to_after_paint_snapshot_ms,
    row$gap_handler_flush_to_boundary_visible_ready_ms
  )
  server_ms <- positive_or_zero(row$gap_server_main_tabs_observer_complete_to_resize_sent_ms)
  visible_wait_ms <- if (is.finite(visible_to_ready)) max(visible_to_ready, 0) else NA_real_
  unexplained_visible_wait_ms <- if (is.finite(visible_wait_ms)) {
    max(visible_wait_ms - max(output_ms, resize_ms, server_ms, 0), 0)
  } else {
    NA_real_
  }

  boundary_matches_visible <- is.finite(boundary_visible) && is.finite(visible_milestone) && abs(boundary_visible - visible_milestone) <= 50
  enough_wait <- is.finite(visible_wait_ms) && visible_wait_ms >= threshold_ms
  enough_echo <- client_echo_ms >= threshold_ms
  enough_output <- output_ms >= threshold_ms
  enough_resize <- resize_ms >= threshold_ms
  enough_server <- server_ms >= threshold_ms

  owner <- "mixed/no-decision"
  reason <- "no_dominant_wait_component"
  dominant_component_ms <- max(output_ms, client_echo_ms, resize_ms, server_ms, unexplained_visible_wait_ms, na.rm = TRUE)

  if (enough_resize && resize_ms >= max(output_ms, client_echo_ms, server_ms, unexplained_visible_wait_ms, na.rm = TRUE)) {
    owner <- "resize transport/handler owned"
    reason <- "resize_handler_or_transport_gap_dominates"
  } else if (enough_server && server_ms >= max(output_ms, client_echo_ms, resize_ms, unexplained_visible_wait_ms, na.rm = TRUE)) {
    owner <- "server observer/send owned"
    reason <- "server_observer_to_resize_send_gap_dominates"
  } else if (enough_output && (!is.finite(visible_wait_ms) || output_ms >= 0.50 * visible_wait_ms)) {
    owner <- "output or Plotly materialization owned"
    reason <- "post_visible_output_or_plotly_gap_explains_wait"
  } else if (enough_echo && (!is.finite(total_action) || client_echo_ms >= 0.20 * total_action)) {
    owner <- "readiness/client-echo owned"
    reason <- "client_echo_after_readiness_gap_is_large"
  } else if (enough_wait && boundary_matches_visible) {
    owner <- "premature visible boundary / decomposition-boundary-owned"
    reason <- "visible_boundary_precedes_readiness_without_stronger_specific_owner"
  } else if (enough_wait) {
    owner <- "guardrail/helper gate suspected"
    reason <- "visible_to_readiness_gap_has_no_specific_marker_owner"
  } else if (enough_echo) {
    owner <- "readiness/client-echo owned"
    reason <- "client_echo_gap_exceeds_threshold"
  }

  data.frame(
    output_materialization_ms = output_ms,
    client_echo_ms = client_echo_ms,
    resize_transport_handler_ms = resize_ms,
    server_observer_send_ms = server_ms,
    visible_to_readiness_ms = if (is.finite(visible_wait_ms)) visible_wait_ms else NA_real_,
    unexplained_visible_wait_ms = unexplained_visible_wait_ms,
    dominant_component_ms = if (is.finite(dominant_component_ms)) dominant_component_ms else NA_real_,
    boundary_matches_visible = boundary_matches_visible,
    ownership_class = owner,
    ownership_reason = reason,
    stringsAsFactors = FALSE
  )
}

read_probe_rows <- function(inventory, marker_threshold_ms) {
  optional_cols <- c(
    "action_index", "action_id", "action_name", "action_kind", "target_id", "target_value",
    "target_accepted_ok", "visible_ready_ok", "client_interaction_ready_ok", "total_action_ms",
    "visible_milestone_ms", "timeline_tab_after_paint_ms", "timeline_shiny_value_output_ms",
    "timeline_readiness_predicate_passed_ms", "timeline_client_echo_ready_ms",
    "server_main_tabs_observer_complete_ms", "server_plotly_resize_sent_ms",
    "plotly_resize_handler_enter_ms", "plotly_resize_handler_flush_ms",
    "plotly_resize_after_paint_snapshot_ms", "boundary_visible_ready_ms",
    "gap_visible_milestone_to_output_visible_nonzero_ms",
    "gap_visible_milestone_to_widget_inserted_ms",
    "gap_visible_milestone_to_main_svg_inserted_ms",
    "gap_visible_milestone_to_plotly_afterplot_ms",
    "gap_visible_milestone_to_loading_indicator_cleared_ms",
    "gap_visible_milestone_to_readiness_predicate_passed_ms",
    "gap_tab_after_paint_to_readiness_predicate_passed_ms",
    "gap_shiny_value_output_to_readiness_predicate_passed_ms",
    "gap_readiness_predicate_passed_to_client_echo_ready_ms",
    "gap_server_main_tabs_observer_complete_to_resize_sent_ms",
    "gap_resize_sent_to_handler_enter_ms", "gap_handler_enter_to_handler_flush_ms",
    "gap_handler_flush_to_after_paint_snapshot_ms", "gap_handler_flush_to_boundary_visible_ready_ms",
    "resize_request_id"
  )

  rows <- list()
  missing_outputs <- character(0)
  read_errors <- character(0)

  for (i in seq_len(nrow(inventory))) {
    output_path <- normalizePath(inventory$output_csv_path[[i]], winslash = "/", mustWork = FALSE)
    if (!file.exists(output_path)) {
      missing_outputs <- c(missing_outputs, inventory$run_id[[i]])
      next
    }

    probe <- tryCatch(
      utils::read.csv(output_path, stringsAsFactors = FALSE, check.names = FALSE),
      error = function(e) e
    )
    if (inherits(probe, "error")) {
      read_errors <- c(read_errors, sprintf("%s: %s", inventory$run_id[[i]], conditionMessage(probe)))
      next
    }
    if (!is.data.frame(probe) || nrow(probe) == 0L) next

    probe <- add_missing_cols(probe, optional_cols)
    require_cols(probe, c("target_value", "action_name"), sprintf("probe output %s", basename(output_path)))

    probe$lane <- inventory$lane[[i]]
    probe$pair_run_label <- inventory$pair_run_label[[i]]
    probe$marker_mode <- inventory$marker_mode[[i]]
    probe$role <- inventory$role[[i]]
    probe$run_id <- inventory$run_id[[i]]
    probe$session_id <- inventory$session_id[[i]]
    probe$runtime_log_path <- inventory$runtime_log_path[[i]]
    probe$output_csv_path <- inventory$output_csv_path[[i]]
    rows[[length(rows) + 1L]] <- probe
  }

  if (length(missing_outputs) > 0L) {
    stop(sprintf("Missing single-action output CSVs for runs: %s", paste(missing_outputs, collapse = ", ")), call. = FALSE)
  }
  if (length(read_errors) > 0L) {
    stop(sprintf("Could not read single-action output CSVs: %s", paste(read_errors, collapse = " | ")), call. = FALSE)
  }
  if (length(rows) == 0L) stop("No single-action probe rows could be read.", call. = FALSE)

  out <- do.call(rbind, rows)
  own <- do.call(rbind, lapply(seq_len(nrow(out)), function(i) classify_action_ownership(out[i, , drop = FALSE], marker_threshold_ms)))
  cbind(out, own, stringsAsFactors = FALSE)
}

build_decomposition_run_context <- function(detail, runs) {
  detail$attributed_elapsed_ms <- safe_numeric(detail$attributed_elapsed_ms)
  detail$gap_allocated_ms <- safe_numeric(detail$gap_allocated_ms)
  detail$bucket <- coalesce_chr(detail$bucket)
  detail$window <- coalesce_chr(detail$window)

  action_detail <- detail[detail$window == "action_window", , drop = FALSE]
  if (nrow(action_detail) == 0L) {
    return(runs[, c("pair_run_label", "role", "run_id", "runtime_log_path", "window_boundary_confidence", "window_boundary_warning", "window_boundary_warning_reason"), drop = FALSE])
  }

  bucket_totals <- aggregate(
    list(bucket_ms = action_detail$attributed_elapsed_ms),
    list(pair_run_label = action_detail$pair_run_label, role = action_detail$role, run_id = action_detail$run_id, bucket = action_detail$bucket),
    sum,
    na.rm = TRUE
  )

  keys <- unique(bucket_totals[, c("pair_run_label", "role", "run_id"), drop = FALSE])
  rows <- vector("list", nrow(keys))
  for (i in seq_len(nrow(keys))) {
    key <- keys[i, , drop = FALSE]
    subset <- bucket_totals[
      bucket_totals$pair_run_label == key$pair_run_label &
        bucket_totals$role == key$role &
        bucket_totals$run_id == key$run_id,
      , drop = FALSE
    ]
    bucket_map <- setNames(subset$bucket_ms, subset$bucket)
    rows[[i]] <- data.frame(
      pair_run_label = key$pair_run_label,
      role = key$role,
      run_id = key$run_id,
      decomp_action_window_ms = sum_numeric(subset$bucket_ms),
      decomp_client_lifecycle_ms = bucket_map[["client_lifecycle"]] %||% 0,
      decomp_client_wait_ms = bucket_map[["client_wait"]] %||% 0,
      decomp_transition_wait_ms = bucket_map[["transition_wait"]] %||% 0,
      decomp_tab_server_materialization_ms = bucket_map[["tab_server_materialization"]] %||% 0,
      decomp_unclassified_ms = bucket_map[["unclassified"]] %||% 0,
      stringsAsFactors = FALSE
    )
  }

  out <- do.call(rbind, rows)
  run_cols <- c(
    "pair_run_label", "role", "run_id", "runtime_log_path", "visible_milestone_source",
    "action_start_source", "window_boundary_confidence", "window_boundary_warning",
    "window_boundary_warning_reason", "detail_gap_allocated_share", "detail_synthetic_wait_share",
    "run_inconclusive", "run_inconclusive_reason"
  )
  runs <- add_missing_cols(runs, run_cols)
  merge(out, runs[, run_cols, drop = FALSE], by = c("pair_run_label", "role", "run_id"), all.x = TRUE)
}

`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0L || is.na(x)) y else x
}

owner_counts_text <- function(x) {
  x <- normalize_owner(x)
  counts <- sort(table(x), decreasing = TRUE)
  paste(paste(names(counts), as.integer(counts), sep = "="), collapse = "; ")
}

primary_owner <- function(x) {
  x <- normalize_owner(x)
  counts <- sort(table(x), decreasing = TRUE)
  names(counts)[[1L]]
}

primary_owner_share <- function(x) {
  x <- normalize_owner(x)
  counts <- sort(table(x), decreasing = TRUE)
  as.numeric(counts[[1L]]) / length(x)
}

summarize_by_tab <- function(rows) {
  groups <- unique(rows[, c("pair_run_label", "marker_mode", "role", "target_value"), drop = FALSE])
  out <- vector("list", nrow(groups))
  for (i in seq_len(nrow(groups))) {
    key <- groups[i, , drop = FALSE]
    subset <- rows[
      rows$pair_run_label == key$pair_run_label &
        rows$marker_mode == key$marker_mode &
        rows$role == key$role &
        rows$target_value == key$target_value,
      , drop = FALSE
    ]
    out[[i]] <- data.frame(
      pair_run_label = key$pair_run_label,
      marker_mode = key$marker_mode,
      role = key$role,
      target_value = key$target_value,
      action_row_count = nrow(subset),
      primary_ownership_class = primary_owner(subset$ownership_class),
      primary_ownership_share = primary_owner_share(subset$ownership_class),
      ownership_counts = owner_counts_text(subset$ownership_class),
      median_total_action_ms = median_numeric(subset$total_action_ms),
      median_visible_milestone_ms = median_numeric(subset$visible_milestone_ms),
      median_visible_to_readiness_ms = median_numeric(subset$visible_to_readiness_ms),
      median_output_materialization_ms = median_numeric(subset$output_materialization_ms),
      median_client_echo_ms = median_numeric(subset$client_echo_ms),
      median_resize_transport_handler_ms = median_numeric(subset$resize_transport_handler_ms),
      median_server_observer_send_ms = median_numeric(subset$server_observer_send_ms),
      median_unexplained_visible_wait_ms = median_numeric(subset$unexplained_visible_wait_ms),
      median_decomp_client_wait_ms = median_numeric(subset$decomp_client_wait_ms),
      median_decomp_client_lifecycle_ms = median_numeric(subset$decomp_client_lifecycle_ms),
      median_decomp_transition_wait_ms = median_numeric(subset$decomp_transition_wait_ms),
      median_detail_gap_allocated_share = median_numeric(subset$detail_gap_allocated_share),
      stringsAsFactors = FALSE
    )
  }
  out <- do.call(rbind, out)
  out[order(out$role, out$target_value), , drop = FALSE]
}

main <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  repo_root <- resolve_repo_root(getwd())
  vp_clone_dir <- file.path(repo_root, "VP Clone")
  logs_dir <- file.path(vp_clone_dir, "Logs")
  dir.create(logs_dir, recursive = TRUE, showWarnings = FALSE)

  inventory_path <- resolve_existing_path(parse_arg_value(args, "inventory", default = ""), vp_clone_dir, "inventory")
  detail_path <- resolve_existing_path(parse_arg_value(args, "detail", default = ""), vp_clone_dir, "detail")
  runs_path <- resolve_existing_path(parse_arg_value(args, "runs", default = ""), vp_clone_dir, "runs")
  label <- trimws(as.character(parse_arg_value(args, "label", default = "tranche8i_wait_boundary_ownership_view")))
  marker_threshold_ms <- safe_numeric(parse_arg_value(args, "marker-threshold-ms", default = "500"))[[1L]]
  if (!is.finite(marker_threshold_ms) || marker_threshold_ms < 0) marker_threshold_ms <- 500

  inventory <- utils::read.csv(inventory_path, stringsAsFactors = FALSE, check.names = FALSE)
  detail <- utils::read.csv(detail_path, stringsAsFactors = FALSE, check.names = FALSE)
  runs <- utils::read.csv(runs_path, stringsAsFactors = FALSE, check.names = FALSE)

  require_cols(inventory, c(
    "lane", "pair_run_label", "marker_mode", "probe_type", "run_id", "session_id", "role",
    "runtime_log_path", "output_csv_path", "integrity_status"
  ), "inventory")
  require_cols(detail, c("pair_run_label", "role", "run_id", "window", "bucket", "attributed_elapsed_ms", "gap_allocated_ms"), "detail")
  require_cols(runs, c("pair_run_label", "role", "run_id", "runtime_log_path"), "runs")

  single_inventory <- inventory[inventory$probe_type == "single_action" & inventory$integrity_status == "ok", , drop = FALSE]
  if (nrow(single_inventory) == 0L) stop("No ok single-action rows found in inventory.", call. = FALSE)

  action_rows <- read_probe_rows(single_inventory, marker_threshold_ms)
  run_context <- build_decomposition_run_context(detail, runs)
  action_rows <- merge(action_rows, run_context, by = c("pair_run_label", "role", "run_id"), all.x = TRUE, suffixes = c("", "_decomp"))

  action_rows$target_value <- coalesce_chr(action_rows$target_value)
  missing_target <- !nzchar(action_rows$target_value)
  if (any(missing_target)) {
    stop(sprintf("Probe rows missing target_value: %d", sum(missing_target)), call. = FALSE)
  }

  run_action_counts <- aggregate(
    list(action_rows = action_rows$target_value),
    list(role = action_rows$role, run_id = action_rows$run_id),
    length
  )
  zero_runs <- setdiff(single_inventory$run_id, unique(action_rows$run_id))
  if (length(zero_runs) > 0L) {
    stop(sprintf("No probe rows recovered for single-action runs: %s", paste(zero_runs, collapse = ", ")), call. = FALSE)
  }

  expected_tabs <- sort(unique(action_rows$target_value))
  tab_sets <- aggregate(
    list(tab_set = action_rows$target_value),
    list(role = action_rows$role, run_id = action_rows$run_id),
    function(x) paste(sort(unique(x)), collapse = "|")
  )
  expected_tab_set <- paste(expected_tabs, collapse = "|")
  inconsistent_tab_runs <- tab_sets$run_id[tab_sets$tab_set != expected_tab_set]
  if (length(inconsistent_tab_runs) > 0L) {
    stop(sprintf("Inconsistent target tab coverage for runs: %s", paste(inconsistent_tab_runs, collapse = ", ")), call. = FALSE)
  }

  tab_summary <- summarize_by_tab(action_rows)

  timestamp_token <- format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC")
  prefix <- file.path(logs_dir, paste0("vp_perf_wait_boundary_ownership_view_", label, "_", timestamp_token))
  row_path <- paste0(prefix, "_action_rows.csv")
  tab_path <- paste0(prefix, "_tab_summary.csv")
  coverage_path <- paste0(prefix, "_coverage.csv")

  coverage <- data.frame(
    pair_run_label = unique(single_inventory$pair_run_label),
    single_action_run_count = length(unique(single_inventory$run_id)),
    recovered_single_action_run_count = length(unique(action_rows$run_id)),
    action_row_count = nrow(action_rows),
    target_tab_count = length(expected_tabs),
    target_tabs = paste(expected_tabs, collapse = " | "),
    min_action_rows_per_run = min(run_action_counts$action_rows),
    max_action_rows_per_run = max(run_action_counts$action_rows),
    marker_threshold_ms = marker_threshold_ms,
    stringsAsFactors = FALSE
  )

  utils::write.csv(action_rows, row_path, row.names = FALSE, na = "")
  utils::write.csv(tab_summary, tab_path, row.names = FALSE, na = "")
  utils::write.csv(coverage, coverage_path, row.names = FALSE, na = "")

  cat("VP_PERF_8I_WAIT_BOUNDARY_OWNERSHIP_VIEW_START\n")
  cat(sprintf("VP_PERF_8I_WAIT_BOUNDARY_OWNERSHIP_VIEW_LABEL=%s\n", label))
  cat(sprintf("VP_PERF_8I_WAIT_BOUNDARY_OWNERSHIP_VIEW_INVENTORY=%s\n", normalizePath(inventory_path, winslash = "/", mustWork = FALSE)))
  cat(sprintf("VP_PERF_8I_WAIT_BOUNDARY_OWNERSHIP_VIEW_DETAIL=%s\n", normalizePath(detail_path, winslash = "/", mustWork = FALSE)))
  cat(sprintf("VP_PERF_8I_WAIT_BOUNDARY_OWNERSHIP_VIEW_RUNS=%s\n", normalizePath(runs_path, winslash = "/", mustWork = FALSE)))
  cat(sprintf("VP_PERF_8I_WAIT_BOUNDARY_OWNERSHIP_VIEW_SINGLE_ACTION_RUNS=%d\n", coverage$single_action_run_count))
  cat(sprintf("VP_PERF_8I_WAIT_BOUNDARY_OWNERSHIP_VIEW_ACTION_ROWS=%d\n", coverage$action_row_count))
  cat(sprintf("VP_PERF_8I_WAIT_BOUNDARY_OWNERSHIP_VIEW_TARGET_TABS=%s\n", coverage$target_tabs))
  cat(sprintf("VP_PERF_8I_WAIT_BOUNDARY_OWNERSHIP_VIEW_ACTION_ROWS_CSV=%s\n", normalizePath(row_path, winslash = "/", mustWork = FALSE)))
  cat(sprintf("VP_PERF_8I_WAIT_BOUNDARY_OWNERSHIP_VIEW_TAB_SUMMARY_CSV=%s\n", normalizePath(tab_path, winslash = "/", mustWork = FALSE)))
  cat(sprintf("VP_PERF_8I_WAIT_BOUNDARY_OWNERSHIP_VIEW_COVERAGE_CSV=%s\n", normalizePath(coverage_path, winslash = "/", mustWork = FALSE)))
  cat("VP_PERF_8I_WAIT_BOUNDARY_OWNERSHIP_VIEW_COMPLETE\n")
}

main()