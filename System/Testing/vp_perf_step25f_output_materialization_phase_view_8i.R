parse_arg_value <- function(args, key, default = NULL) {
  prefix <- paste0("--", key, "=")
  hits <- args[startsWith(args, prefix)]
  if (length(hits) == 0L) return(default)
  sub(prefix, "", hits[[length(hits)]], fixed = TRUE)
}

`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0L) y else x
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

  stop("Could not resolve repository root for 8I output/materialization phase view.", call. = FALSE)
}

resolve_existing_path <- function(path_arg, vp_clone_dir, label) {
  path_arg <- trimws(as.character(path_arg %||% ""))
  if (!nzchar(path_arg)) stop(sprintf("Missing required --%s argument.", label), call. = FALSE)

  path <- normalizePath(path_arg, winslash = "/", mustWork = FALSE)
  if (!file.exists(path)) {
    path <- normalizePath(file.path(vp_clone_dir, path_arg), winslash = "/", mustWork = FALSE)
  }
  if (!file.exists(path)) stop(sprintf("%s file not found: %s", label, path_arg), call. = FALSE)
  path
}

safe_numeric <- function(value) {
  suppressWarnings(as.numeric(value))
}

safe_int <- function(value) {
  suppressWarnings(as.integer(value))
}

first_non_empty <- function(values) {
  normalized <- trimws(as.character(values %||% character(0)))
  normalized <- normalized[!is.na(normalized) & nzchar(normalized)]
  if (length(normalized) == 0L) return(NA_character_)
  normalized[[1L]]
}

first_non_na_number <- function(values) {
  normalized <- safe_numeric(values)
  normalized <- normalized[is.finite(normalized)]
  if (length(normalized) == 0L) return(NA_real_)
  normalized[[1L]]
}

median_numeric <- function(values) {
  normalized <- safe_numeric(values)
  normalized <- normalized[is.finite(normalized)]
  if (length(normalized) == 0L) return(NA_real_)
  as.numeric(stats::median(normalized))
}

quantile_numeric <- function(values, probability) {
  normalized <- safe_numeric(values)
  normalized <- normalized[is.finite(normalized)]
  if (length(normalized) == 0L) return(NA_real_)
  as.numeric(stats::quantile(normalized, probs = probability, names = FALSE, type = 7))
}

add_missing_cols <- function(df, columns) {
  for (column in columns) {
    if (!column %in% names(df)) df[[column]] <- NA
  }
  df
}

require_cols <- function(df, columns, df_name) {
  missing <- setdiff(columns, names(df))
  if (length(missing) > 0L) {
    stop(sprintf("%s missing required columns: %s", df_name, paste(missing, collapse = ", ")), call. = FALSE)
  }
}

normalize_path_or_blank <- function(path) {
  path <- trimws(as.character(path %||% ""))
  if (!nzchar(path)) return("")
  normalizePath(path, winslash = "/", mustWork = FALSE)
}

infer_lane <- function(label) {
  label <- as.character(label %||% "")
  if (grepl("__baseline__", label, fixed = TRUE)) return("baseline")
  if (grepl("__candidate__", label, fixed = TRUE)) return("candidate")
  NA_character_
}

infer_iteration <- function(label) {
  label <- as.character(label %||% "")
  hit <- regmatches(label, regexpr("iter[0-9]+", label))
  if (length(hit) == 0L || identical(hit, character(0)) || !nzchar(hit)) return(NA_integer_)
  safe_int(sub("iter", "", hit, fixed = TRUE))[[1L]]
}

valid_gap <- function(start_ms, end_ms) {
  start <- safe_numeric(start_ms)[[1L]]
  end <- safe_numeric(end_ms)[[1L]]
  if (!is.finite(start) || !is.finite(end)) return(NA_real_)
  end - start
}

parse_timeline_events <- function(value) {
  raw <- as.character(value %||% "")
  if (!nzchar(raw)) {
    return(data.frame(event = character(0), ms = numeric(0), output_id = character(0), matched = logical(0)))
  }

  parts <- strsplit(raw, ";", fixed = TRUE)[[1L]]
  rows <- lapply(parts, function(part) {
    match <- regexec("^([^@]+)@(-?[0-9]+)#([^#]*)#([01])$", part)
    parsed <- regmatches(part, match)[[1L]]
    if (length(parsed) != 5L) return(NULL)

    data.frame(
      event = parsed[[2L]],
      ms = safe_numeric(parsed[[3L]])[[1L]],
      output_id = parsed[[4L]],
      matched = identical(parsed[[5L]], "1"),
      stringsAsFactors = FALSE
    )
  })
  rows <- Filter(Negate(is.null), rows)
  if (length(rows) == 0L) {
    return(data.frame(event = character(0), ms = numeric(0), output_id = character(0), matched = logical(0)))
  }

  out <- do.call(rbind, rows)
  out <- out[order(out$ms), , drop = FALSE]
  rownames(out) <- NULL
  out
}

first_timeline_ms <- function(events, event_name, output_id, min_ms = NA_real_) {
  if (!is.data.frame(events) || nrow(events) == 0L) return(NA_real_)
  subset <- events[events$event == event_name & events$output_id == output_id & events$matched %in% TRUE, , drop = FALSE]
  if (is.finite(min_ms)) {
    subset <- subset[is.finite(subset$ms) & subset$ms >= min_ms, , drop = FALSE]
  }
  if (nrow(subset) == 0L) return(NA_real_)
  first_non_na_number(subset$ms)
}

timeline_useful_ready_ms <- function(plotly_afterplot_ms, loading_cleared_ms) {
  values <- safe_numeric(c(plotly_afterplot_ms, loading_cleared_ms))
  if (!all(is.finite(values))) return(NA_real_)
  max(values)
}

read_server_anchor_values <- function(runtime_log_path, target_tab, target_output_id) {
  empty <- data.frame(
    server_anchor_render_start_ms = NA_real_,
    server_anchor_inputs_resolved_ms = NA_real_,
    server_anchor_plot_object_built_ms = NA_real_,
    server_anchor_render_returned_ms = NA_real_,
    server_anchor_complete = FALSE,
    server_anchor_row_count = 0L,
    stringsAsFactors = FALSE
  )

  runtime_log_path <- normalize_path_or_blank(runtime_log_path)
  if (!nzchar(runtime_log_path) || !file.exists(runtime_log_path)) return(empty)
  if (!requireNamespace("jsonlite", quietly = TRUE)) return(empty)

  lines <- tryCatch(readLines(runtime_log_path, warn = FALSE, encoding = "UTF-8"), error = function(...) character(0))
  if (length(lines) == 0L) return(empty)

  rows <- lapply(lines, function(line) {
    parsed <- tryCatch(jsonlite::fromJSON(line, simplifyVector = TRUE), error = function(...) NULL)
    if (is.null(parsed) || !is.list(parsed)) return(NULL)
    if (!identical(as.character(parsed$event %||% ""), "server_output_anchor")) return(NULL)
    if (!identical(as.character(parsed$target_output_id %||% ""), target_output_id)) return(NULL)
    if (!identical(as.character(parsed$tab %||% ""), target_tab)) return(NULL)
    if (!identical(as.character(parsed$action_reason %||% parsed$request_action_reason %||% ""), paste0("tab_click:", target_tab))) return(NULL)

    data.frame(
      tag = as.character(parsed$tag %||% NA_character_),
      elapsed_ms = safe_numeric(parsed$elapsed_ms %||% NA_real_)[[1L]],
      stringsAsFactors = FALSE
    )
  })
  rows <- Filter(Negate(is.null), rows)
  if (length(rows) == 0L) return(empty)

  anchors <- do.call(rbind, rows)
  value_for_tag <- function(tag) first_non_na_number(anchors$elapsed_ms[anchors$tag == tag])
  out <- data.frame(
    server_anchor_render_start_ms = value_for_tag("boundary_server_output_render_start"),
    server_anchor_inputs_resolved_ms = value_for_tag("boundary_server_output_inputs_resolved"),
    server_anchor_plot_object_built_ms = value_for_tag("boundary_server_output_plot_object_built"),
    server_anchor_render_returned_ms = value_for_tag("boundary_server_output_render_returned"),
    server_anchor_complete = FALSE,
    server_anchor_row_count = nrow(anchors),
    stringsAsFactors = FALSE
  )
  out$server_anchor_complete <- all(is.finite(unlist(out[1, c(
    "server_anchor_render_start_ms",
    "server_anchor_inputs_resolved_ms",
    "server_anchor_plot_object_built_ms",
    "server_anchor_render_returned_ms"
  )], use.names = FALSE)))
  out
}

build_action_rows <- function(manifest, target_tab, target_output_id) {
  single <- manifest[as.character(manifest$probe_type %||% "") == "single_action", , drop = FALSE]
  if (nrow(single) == 0L) stop("Manifest contains no single_action rows.", call. = FALSE)

  rows <- list()
  required_probe_cols <- c(
    "action_id", "action_kind", "status", "target_value", "output_id", "target_output_id",
    "total_action_ms", "visible_ready_ms", "full_idle_ms", "visible_milestone_ms",
    "output_render_start_ms", "output_inputs_resolved_ms", "output_plot_object_built_ms", "output_render_returned_ms",
    "output_client_value_received_ms", "output_widget_inserted_marker_ms", "output_main_svg_inserted_marker_ms",
    "output_plotly_afterplot_marker_ms", "output_loading_cleared_marker_ms", "output_useful_ready_ms",
    "gap_render_start_to_inputs_resolved_ms", "gap_inputs_resolved_to_plot_object_built_ms",
    "gap_plot_object_built_to_render_returned_ms", "gap_render_returned_to_client_value_received_ms",
    "gap_client_value_received_to_widget_inserted_ms", "gap_widget_inserted_to_plotly_afterplot_marker_ms",
    "gap_plotly_afterplot_marker_to_loading_cleared_ms", "gap_loading_cleared_to_useful_ready_ms",
    "gap_visible_milestone_to_useful_ready_ms", "output_owner", "surface", "output_outcome", "useful_ready_rule",
    "timeline_events"
  )

  for (index in seq_len(nrow(single))) {
    output_path <- normalize_path_or_blank(single$output_csv_path[[index]])
    if (!nzchar(output_path) || !file.exists(output_path)) {
      stop(sprintf("Missing single-action output CSV for run_id=%s: %s", single$run_id[[index]], output_path), call. = FALSE)
    }

    probe <- utils::read.csv(output_path, stringsAsFactors = FALSE, check.names = FALSE)
    probe <- add_missing_cols(probe, required_probe_cols)

    current <- probe[
      as.character(probe$action_kind %||% "") == "tab_settled" &
        as.character(probe$target_value %||% "") == target_tab &
        as.character(probe$output_id %||% probe$target_output_id %||% "") == target_output_id,
      ,
      drop = FALSE
    ]
    if (nrow(current) != 1L) {
      stop(sprintf("Expected exactly one %s/%s action row in %s; found %s", target_tab, target_output_id, basename(output_path), nrow(current)), call. = FALSE)
    }

    anchors <- read_server_anchor_values(single$runtime_log_path[[index]], target_tab, target_output_id)

    render_start <- safe_numeric(current$output_render_start_ms)[[1L]]
    inputs_resolved <- safe_numeric(current$output_inputs_resolved_ms)[[1L]]
    plot_built <- safe_numeric(current$output_plot_object_built_ms)[[1L]]
    render_returned <- safe_numeric(current$output_render_returned_ms)[[1L]]
    client_value <- safe_numeric(current$output_client_value_received_ms)[[1L]]
    widget_inserted <- safe_numeric(current$output_widget_inserted_marker_ms)[[1L]]
    main_svg <- safe_numeric(current$output_main_svg_inserted_marker_ms)[[1L]]
    afterplot <- safe_numeric(current$output_plotly_afterplot_marker_ms)[[1L]]
    loading_cleared <- safe_numeric(current$output_loading_cleared_marker_ms)[[1L]]
    useful_ready <- safe_numeric(current$output_useful_ready_ms)[[1L]]

    timeline_events <- parse_timeline_events(current$timeline_events[[1L]])
    timeline_target_shiny_value <- first_timeline_ms(timeline_events, "shiny_value_output", target_output_id)
    timeline_widget_after_shiny <- first_timeline_ms(timeline_events, "widget_inserted", target_output_id, min_ms = timeline_target_shiny_value)
    timeline_main_svg_after_shiny <- first_timeline_ms(timeline_events, "main_svg_inserted", target_output_id, min_ms = timeline_target_shiny_value)
    timeline_plotly_afterplot_after_shiny <- first_timeline_ms(timeline_events, "plotly_afterplot", target_output_id, min_ms = timeline_target_shiny_value)
    timeline_loading_cleared_after_shiny <- first_timeline_ms(timeline_events, "loading_indicator_cleared", target_output_id, min_ms = timeline_target_shiny_value)
    timeline_readiness_after_shiny <- first_timeline_ms(timeline_events, "readiness_predicate_passed", target_output_id, min_ms = timeline_target_shiny_value)
    timeline_useful_ready_after_shiny <- timeline_useful_ready_ms(timeline_plotly_afterplot_after_shiny, timeline_loading_cleared_after_shiny)

    row <- data.frame(
      lane = infer_lane(single$label[[index]]),
      iteration = infer_iteration(single$label[[index]]),
      manifest_label = as.character(single$label[[index]]),
      run_id = as.character(single$run_id[[index]]),
      session_id = as.character(single$session_id[[index]]),
      status = as.character(current$status[[1L]]),
      target_value = as.character(current$target_value[[1L]]),
      output_id = as.character(current$output_id[[1L]]),
      target_output_id = as.character(current$target_output_id[[1L]]),
      output_owner = as.character(current$output_owner[[1L]]),
      surface = as.character(current$surface[[1L]]),
      output_outcome = as.character(current$output_outcome[[1L]]),
      useful_ready_rule = as.character(current$useful_ready_rule[[1L]]),
      total_action_ms = safe_numeric(current$total_action_ms)[[1L]],
      visible_ready_ms = safe_numeric(current$visible_ready_ms)[[1L]],
      full_idle_ms = safe_numeric(current$full_idle_ms)[[1L]],
      visible_milestone_ms = safe_numeric(current$visible_milestone_ms)[[1L]],
      output_render_start_ms = render_start,
      output_inputs_resolved_ms = inputs_resolved,
      output_plot_object_built_ms = plot_built,
      output_render_returned_ms = render_returned,
      output_client_value_received_ms = client_value,
      output_widget_inserted_marker_ms = widget_inserted,
      output_main_svg_inserted_marker_ms = main_svg,
      output_plotly_afterplot_marker_ms = afterplot,
      output_loading_cleared_marker_ms = loading_cleared,
      output_useful_ready_ms = useful_ready,
      server_render_ms = valid_gap(render_start, render_returned),
      server_inputs_resolved_ms = safe_numeric(current$gap_render_start_to_inputs_resolved_ms)[[1L]],
      server_plot_build_ms = safe_numeric(current$gap_inputs_resolved_to_plot_object_built_ms)[[1L]],
      server_return_finalize_ms = safe_numeric(current$gap_plot_object_built_to_render_returned_ms)[[1L]],
      render_returned_to_shiny_value_ms = safe_numeric(current$gap_render_returned_to_client_value_received_ms)[[1L]],
      client_value_to_widget_ms = safe_numeric(current$gap_client_value_received_to_widget_inserted_ms)[[1L]],
      widget_to_main_svg_ms = valid_gap(widget_inserted, main_svg),
      widget_to_plotly_afterplot_ms = safe_numeric(current$gap_widget_inserted_to_plotly_afterplot_marker_ms)[[1L]],
      plotly_afterplot_to_loading_cleared_ms = safe_numeric(current$gap_plotly_afterplot_marker_to_loading_cleared_ms)[[1L]],
      loading_cleared_to_useful_ready_ms = safe_numeric(current$gap_loading_cleared_to_useful_ready_ms)[[1L]],
      visible_milestone_to_useful_ready_ms = safe_numeric(current$gap_visible_milestone_to_useful_ready_ms)[[1L]],
      timeline_target_shiny_value_ms = timeline_target_shiny_value,
      timeline_target_widget_after_shiny_ms = timeline_widget_after_shiny,
      timeline_target_main_svg_after_shiny_ms = timeline_main_svg_after_shiny,
      timeline_target_plotly_afterplot_after_shiny_ms = timeline_plotly_afterplot_after_shiny,
      timeline_target_loading_cleared_after_shiny_ms = timeline_loading_cleared_after_shiny,
      timeline_target_useful_ready_after_shiny_ms = timeline_useful_ready_after_shiny,
      timeline_target_readiness_predicate_after_shiny_ms = timeline_readiness_after_shiny,
      corrected_shiny_value_to_widget_ms = valid_gap(timeline_target_shiny_value, timeline_widget_after_shiny),
      corrected_shiny_value_to_main_svg_ms = valid_gap(timeline_target_shiny_value, timeline_main_svg_after_shiny),
      corrected_widget_to_plotly_afterplot_ms = valid_gap(timeline_widget_after_shiny, timeline_plotly_afterplot_after_shiny),
      corrected_shiny_value_to_loading_cleared_ms = valid_gap(timeline_target_shiny_value, timeline_loading_cleared_after_shiny),
      corrected_loading_cleared_to_useful_ready_ms = valid_gap(timeline_loading_cleared_after_shiny, timeline_useful_ready_after_shiny),
      corrected_shiny_value_to_useful_ready_ms = valid_gap(timeline_target_shiny_value, timeline_useful_ready_after_shiny),
      corrected_visible_milestone_to_useful_ready_ms = valid_gap(safe_numeric(current$visible_milestone_ms)[[1L]], timeline_useful_ready_after_shiny),
      corrected_useful_ready_to_readiness_predicate_ms = valid_gap(timeline_useful_ready_after_shiny, timeline_readiness_after_shiny),
      output_csv_path = output_path,
      runtime_log_path = normalize_path_or_blank(single$runtime_log_path[[index]]),
      stringsAsFactors = FALSE
    )
    rows[[length(rows) + 1L]] <- cbind(row, anchors, stringsAsFactors = FALSE)
  }

  out <- do.call(rbind, rows)
  out <- out[order(out$lane, out$iteration), , drop = FALSE]
  rownames(out) <- NULL
  out
}

phase_summary_for_group <- function(rows, lane_label) {
  phase_columns <- c(
    "server_render_ms",
    "server_inputs_resolved_ms",
    "server_plot_build_ms",
    "server_return_finalize_ms",
    "render_returned_to_shiny_value_ms",
    "client_value_to_widget_ms",
    "widget_to_main_svg_ms",
    "widget_to_plotly_afterplot_ms",
    "plotly_afterplot_to_loading_cleared_ms",
    "loading_cleared_to_useful_ready_ms",
    "visible_milestone_to_useful_ready_ms",
    "corrected_shiny_value_to_widget_ms",
    "corrected_shiny_value_to_main_svg_ms",
    "corrected_widget_to_plotly_afterplot_ms",
    "corrected_shiny_value_to_loading_cleared_ms",
    "corrected_loading_cleared_to_useful_ready_ms",
    "corrected_shiny_value_to_useful_ready_ms",
    "corrected_visible_milestone_to_useful_ready_ms",
    "corrected_useful_ready_to_readiness_predicate_ms"
  )

  medians <- vapply(phase_columns, function(column) median_numeric(rows[[column]]), numeric(1))
  phase_candidates <- medians[c(
    "server_render_ms",
    "render_returned_to_shiny_value_ms",
    "client_value_to_widget_ms",
    "widget_to_main_svg_ms",
    "widget_to_plotly_afterplot_ms",
    "plotly_afterplot_to_loading_cleared_ms",
    "loading_cleared_to_useful_ready_ms"
  )]
  dominant_phase <- NA_character_
  finite_candidates <- phase_candidates[is.finite(phase_candidates)]
  if (length(finite_candidates) > 0L) {
    dominant_name <- names(finite_candidates)[[which.max(finite_candidates)]]
    if (is.character(dominant_name) && nzchar(dominant_name)) {
      dominant_phase <- dominant_name
    }
  }

  data.frame(
    lane = lane_label,
    run_count = nrow(rows),
    pass_count = sum(as.character(rows$status) == "PASS", na.rm = TRUE),
    server_anchor_complete_count = sum(isTRUE(rows$server_anchor_complete) | rows$server_anchor_complete == TRUE, na.rm = TRUE),
    median_total_action_ms = median_numeric(rows$total_action_ms),
    median_visible_ready_ms = median_numeric(rows$visible_ready_ms),
    median_full_idle_ms = median_numeric(rows$full_idle_ms),
    median_output_useful_ready_ms = median_numeric(rows$output_useful_ready_ms),
    median_server_render_ms = medians[["server_render_ms"]],
    median_server_inputs_resolved_ms = medians[["server_inputs_resolved_ms"]],
    median_server_plot_build_ms = medians[["server_plot_build_ms"]],
    median_server_return_finalize_ms = medians[["server_return_finalize_ms"]],
    median_render_returned_to_shiny_value_ms = medians[["render_returned_to_shiny_value_ms"]],
    median_client_value_to_widget_ms = medians[["client_value_to_widget_ms"]],
    median_widget_to_main_svg_ms = medians[["widget_to_main_svg_ms"]],
    median_widget_to_plotly_afterplot_ms = medians[["widget_to_plotly_afterplot_ms"]],
    median_plotly_afterplot_to_loading_cleared_ms = medians[["plotly_afterplot_to_loading_cleared_ms"]],
    median_loading_cleared_to_useful_ready_ms = medians[["loading_cleared_to_useful_ready_ms"]],
    median_visible_milestone_to_useful_ready_ms = medians[["visible_milestone_to_useful_ready_ms"]],
    median_timeline_target_shiny_value_ms = median_numeric(rows$timeline_target_shiny_value_ms),
    median_timeline_target_widget_after_shiny_ms = median_numeric(rows$timeline_target_widget_after_shiny_ms),
    median_timeline_target_main_svg_after_shiny_ms = median_numeric(rows$timeline_target_main_svg_after_shiny_ms),
    median_timeline_target_plotly_afterplot_after_shiny_ms = median_numeric(rows$timeline_target_plotly_afterplot_after_shiny_ms),
    median_timeline_target_loading_cleared_after_shiny_ms = median_numeric(rows$timeline_target_loading_cleared_after_shiny_ms),
    median_timeline_target_useful_ready_after_shiny_ms = median_numeric(rows$timeline_target_useful_ready_after_shiny_ms),
    median_timeline_target_readiness_predicate_after_shiny_ms = median_numeric(rows$timeline_target_readiness_predicate_after_shiny_ms),
    median_corrected_shiny_value_to_widget_ms = medians[["corrected_shiny_value_to_widget_ms"]],
    median_corrected_shiny_value_to_main_svg_ms = medians[["corrected_shiny_value_to_main_svg_ms"]],
    median_corrected_widget_to_plotly_afterplot_ms = medians[["corrected_widget_to_plotly_afterplot_ms"]],
    median_corrected_shiny_value_to_loading_cleared_ms = medians[["corrected_shiny_value_to_loading_cleared_ms"]],
    median_corrected_loading_cleared_to_useful_ready_ms = medians[["corrected_loading_cleared_to_useful_ready_ms"]],
    median_corrected_shiny_value_to_useful_ready_ms = medians[["corrected_shiny_value_to_useful_ready_ms"]],
    median_corrected_visible_milestone_to_useful_ready_ms = medians[["corrected_visible_milestone_to_useful_ready_ms"]],
    median_corrected_useful_ready_to_readiness_predicate_ms = medians[["corrected_useful_ready_to_readiness_predicate_ms"]],
    p25_output_useful_ready_ms = quantile_numeric(rows$output_useful_ready_ms, 0.25),
    p75_output_useful_ready_ms = quantile_numeric(rows$output_useful_ready_ms, 0.75),
    dominant_phase_by_median = dominant_phase,
    output_outcomes = paste(sort(unique(trimws(as.character(rows$output_outcome)))), collapse = "|"),
    useful_ready_rules = paste(sort(unique(trimws(as.character(rows$useful_ready_rule)))), collapse = "|"),
    stringsAsFactors = FALSE
  )
}

build_summary <- function(action_rows) {
  lanes <- c("baseline", "candidate")
  rows <- lapply(lanes, function(lane) {
    subset <- action_rows[action_rows$lane == lane, , drop = FALSE]
    if (nrow(subset) == 0L) return(NULL)
    phase_summary_for_group(subset, lane)
  })
  rows <- Filter(Negate(is.null), rows)
  rows[[length(rows) + 1L]] <- phase_summary_for_group(action_rows, "all")
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

main <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  label <- trimws(as.character(parse_arg_value(args, "label", default = "tranche8i_output_materialization_phase_view")))
  manifest_arg <- parse_arg_value(args, "manifest", default = "")
  target_tab <- trimws(as.character(parse_arg_value(args, "target-tab", default = "Current vs. Average")))
  target_output_id <- trimws(as.character(parse_arg_value(args, "target-output-id", default = "comparison_plot")))

  repo_root <- resolve_repo_root()
  vp_clone_dir <- file.path(repo_root, "VP Clone")
  if (!dir.exists(vp_clone_dir) && basename(repo_root) == "VP Clone") {
    vp_clone_dir <- repo_root
  }
  logs_dir <- file.path(vp_clone_dir, "Logs")
  dir.create(logs_dir, recursive = TRUE, showWarnings = FALSE)

  manifest_path <- resolve_existing_path(manifest_arg, vp_clone_dir, "manifest")
  manifest <- utils::read.csv(manifest_path, stringsAsFactors = FALSE, check.names = FALSE)
  require_cols(manifest, c("probe_type", "label", "run_id", "session_id", "runtime_log_path", "output_csv_path"), "manifest")

  action_rows <- build_action_rows(manifest, target_tab = target_tab, target_output_id = target_output_id)
  summary <- build_summary(action_rows)

  expected_rows <- sum(as.character(manifest$probe_type %||% "") == "single_action")
  coverage <- data.frame(
    label = label,
    manifest_path = normalizePath(manifest_path, winslash = "/", mustWork = FALSE),
    target_tab = target_tab,
    target_output_id = target_output_id,
    expected_single_action_runs = expected_rows,
    action_rows = nrow(action_rows),
    baseline_rows = sum(action_rows$lane == "baseline", na.rm = TRUE),
    candidate_rows = sum(action_rows$lane == "candidate", na.rm = TRUE),
    pass_rows = sum(as.character(action_rows$status) == "PASS", na.rm = TRUE),
    server_anchor_complete_rows = sum(isTRUE(action_rows$server_anchor_complete) | action_rows$server_anchor_complete == TRUE, na.rm = TRUE),
    stringsAsFactors = FALSE
  )

  timestamp_token <- format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC")
  prefix <- file.path(logs_dir, paste0("vp_perf_output_materialization_phase_view_", label, "_", timestamp_token))
  action_path <- paste0(prefix, "_action_rows.csv")
  summary_path <- paste0(prefix, "_lane_summary.csv")
  coverage_path <- paste0(prefix, "_coverage.csv")

  utils::write.csv(action_rows, action_path, row.names = FALSE, na = "")
  utils::write.csv(summary, summary_path, row.names = FALSE, na = "")
  utils::write.csv(coverage, coverage_path, row.names = FALSE, na = "")

  cat(sprintf("VP_PERF_8I_OUTPUT_MATERIALIZATION_PHASE_VIEW_LABEL=%s\n", label))
  cat(sprintf("VP_PERF_8I_OUTPUT_MATERIALIZATION_PHASE_VIEW_ACTION_ROWS=%s\n", normalizePath(action_path, winslash = "/", mustWork = FALSE)))
  cat(sprintf("VP_PERF_8I_OUTPUT_MATERIALIZATION_PHASE_VIEW_SUMMARY=%s\n", normalizePath(summary_path, winslash = "/", mustWork = FALSE)))
  cat(sprintf("VP_PERF_8I_OUTPUT_MATERIALIZATION_PHASE_VIEW_COVERAGE=%s\n", normalizePath(coverage_path, winslash = "/", mustWork = FALSE)))
  cat(sprintf("VP_PERF_8I_OUTPUT_MATERIALIZATION_PHASE_VIEW_ROWS=%s\n", nrow(action_rows)))
  cat(sprintf("VP_PERF_8I_OUTPUT_MATERIALIZATION_PHASE_VIEW_ANCHOR_COMPLETE_ROWS=%s\n", coverage$server_anchor_complete_rows[[1L]]))
}

main()