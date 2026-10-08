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

  stop("Could not resolve repository root for Step 25D attribution audit.", call. = FALSE)
}

safe_numeric <- function(x) {
  suppressWarnings(as.numeric(x))
}

normalize_event_signature <- function(event, tag, name, summary_label) {
  event <- trimws(as.character(event))
  tag <- trimws(as.character(tag))
  name <- trimws(as.character(name))
  summary_label <- trimws(as.character(summary_label))
  paste(event, tag, name, summary_label, sep = "||")
}

load_required_csv <- function(path_label, raw_path, vp_clone_dir) {
  p <- normalizePath(raw_path, winslash = "/", mustWork = FALSE)
  if (!file.exists(p)) {
    p <- normalizePath(file.path(vp_clone_dir, raw_path), winslash = "/", mustWork = FALSE)
  }
  if (!file.exists(p)) {
    stop(sprintf("Required %s file not found: %s", path_label, raw_path), call. = FALSE)
  }
  list(
    path = p,
    data = utils::read.csv(p, stringsAsFactors = FALSE, check.names = FALSE)
  )
}

main <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  repo_root <- resolve_repo_root(getwd())
  vp_clone_dir <- file.path(repo_root, "VP Clone")
  logs_dir <- file.path(vp_clone_dir, "Logs")
  dir.create(logs_dir, recursive = TRUE, showWarnings = FALSE)

  detail_arg <- trimws(as.character(parse_arg_value(args, "detail", default = "")))
  summary_arg <- trimws(as.character(parse_arg_value(args, "summary", default = "")))
  runs_arg <- trimws(as.character(parse_arg_value(args, "runs", default = "")))
  window_conf_arg <- trimws(as.character(parse_arg_value(args, "window-confidence", default = "")))
  gate_arg <- trimws(as.character(parse_arg_value(args, "inconclusive-gate", default = "")))
  label <- trimws(as.character(parse_arg_value(args, "label", default = "step25d_attribution_audit")))

  if (!nzchar(detail_arg) || !nzchar(summary_arg) || !nzchar(runs_arg) || !nzchar(window_conf_arg) || !nzchar(gate_arg)) {
    stop("Missing required arguments: --detail, --summary, --runs, --window-confidence, --inconclusive-gate", call. = FALSE)
  }

  detail_loaded <- load_required_csv("detail", detail_arg, vp_clone_dir)
  summary_loaded <- load_required_csv("summary", summary_arg, vp_clone_dir)
  runs_loaded <- load_required_csv("runs", runs_arg, vp_clone_dir)
  window_loaded <- load_required_csv("window-confidence", window_conf_arg, vp_clone_dir)
  gate_loaded <- load_required_csv("inconclusive-gate", gate_arg, vp_clone_dir)

  detail_df <- detail_loaded$data
  summary_df <- summary_loaded$data
  runs_df <- runs_loaded$data
  window_df <- window_loaded$data
  gate_df <- gate_loaded$data

  if (nrow(detail_df) == 0L || nrow(summary_df) == 0L || nrow(runs_df) == 0L || nrow(window_df) == 0L || nrow(gate_df) == 0L) {
    stop("At least one required input CSV is empty; cannot run attribution audit.", call. = FALSE)
  }

  detail_df$attributed_elapsed_ms <- safe_numeric(detail_df$attributed_elapsed_ms)
  detail_df$event_elapsed_ms <- safe_numeric(detail_df$event_elapsed_ms)
  detail_df$gap_allocated_ms <- safe_numeric(detail_df$gap_allocated_ms)
  detail_df$multi_match <- as.logical(detail_df$multi_match)
  detail_df$multi_match[is.na(detail_df$multi_match)] <- FALSE
  detail_df$is_synthetic_gap <- tolower(trimws(as.character(detail_df$event))) == "gap_allocation"
  detail_df$signature <- normalize_event_signature(
    detail_df$event,
    detail_df$tag,
    detail_df$name,
    detail_df$summary_label
  )

  class_agg <- aggregate(
    list(
      row_count = detail_df$signature,
      total_attributed_ms = detail_df$attributed_elapsed_ms,
      observed_attributed_ms = ifelse(detail_df$is_synthetic_gap, 0, detail_df$attributed_elapsed_ms),
      synthetic_attributed_ms = ifelse(detail_df$is_synthetic_gap, detail_df$attributed_elapsed_ms, 0),
      total_gap_allocated_ms = detail_df$gap_allocated_ms
    ),
    by = list(
      lane = detail_df$lane,
      role = detail_df$role,
      probe_type = detail_df$probe_type,
      run_id = detail_df$run_id,
      window = detail_df$window,
      bucket = detail_df$bucket,
      bucket_candidates = detail_df$bucket_candidates,
      multi_match = detail_df$multi_match,
      event = detail_df$event,
      tag = detail_df$tag,
      name = detail_df$name,
      summary_label = detail_df$summary_label,
      signature = detail_df$signature,
      is_synthetic_gap = detail_df$is_synthetic_gap
    ),
    FUN = function(x) {
      if (is.numeric(x)) return(sum(x, na.rm = TRUE))
      length(x)
    }
  )

  class_agg <- class_agg[order(class_agg$lane, class_agg$role, class_agg$window, -class_agg$total_attributed_ms), , drop = FALSE]

  bucket_agg <- aggregate(
    list(
      total_attr_ms = detail_df$attributed_elapsed_ms,
      observed_attr_ms = ifelse(detail_df$is_synthetic_gap, 0, detail_df$attributed_elapsed_ms),
      synthetic_attr_ms = ifelse(detail_df$is_synthetic_gap, detail_df$attributed_elapsed_ms, 0)
    ),
    by = list(
      lane = detail_df$lane,
      role = detail_df$role,
      window = detail_df$window,
      bucket = detail_df$bucket
    ),
    FUN = function(x) sum(x, na.rm = TRUE)
  )

  bucket_totals <- aggregate(
    list(
      window_total_attr_ms = bucket_agg$total_attr_ms,
      window_observed_attr_ms = bucket_agg$observed_attr_ms,
      window_synthetic_attr_ms = bucket_agg$synthetic_attr_ms
    ),
    by = list(
      lane = bucket_agg$lane,
      role = bucket_agg$role,
      window = bucket_agg$window
    ),
    FUN = function(x) sum(x, na.rm = TRUE)
  )

  window_bucket <- merge(
    bucket_agg,
    bucket_totals,
    by = c("lane", "role", "window"),
    all.x = TRUE
  )
  window_bucket$total_attr_share <- ifelse(window_bucket$window_total_attr_ms > 0, window_bucket$total_attr_ms / window_bucket$window_total_attr_ms, NA_real_)
  window_bucket$observed_attr_share <- ifelse(window_bucket$window_observed_attr_ms > 0, window_bucket$observed_attr_ms / window_bucket$window_observed_attr_ms, NA_real_)
  window_bucket$synthetic_attr_share <- ifelse(window_bucket$window_synthetic_attr_ms > 0, window_bucket$synthetic_attr_ms / window_bucket$window_synthetic_attr_ms, NA_real_)
  window_bucket <- window_bucket[order(window_bucket$lane, window_bucket$role, window_bucket$window, -window_bucket$total_attr_share), , drop = FALSE]

  runs_conf <- runs_df[, c(
    "lane", "pair_run_label", "role", "probe_type", "run_id",
    "bucket_confidence", "detail_bucket_confidence", "detail_gap_allocated_share",
    "detail_synthetic_wait_share", "window_boundary_confidence", "window_boundary_warning",
    "window_boundary_warning_reason", "action_start_source", "visible_milestone_source",
    "run_inconclusive", "run_inconclusive_reason"
  ), drop = FALSE]

  window_conf_rollup <- aggregate(
    list(
      action_window_count = ifelse(window_df$window == "action_window", 1, 0),
      action_window_inconclusive_count = ifelse(window_df$window == "action_window" & as.logical(window_df$window_inconclusive), 1, 0),
      action_window_gap_warning_count = ifelse(window_df$window == "action_window" & as.logical(window_df$window_gap_warning), 1, 0),
      action_window_synthetic_wait_warning_count = ifelse(window_df$window == "action_window" & as.logical(window_df$window_synthetic_wait_warning), 1, 0),
      post_visible_count = ifelse(window_df$window == "post_visible_idle", 1, 0),
      post_visible_inconclusive_count = ifelse(window_df$window == "post_visible_idle" & as.logical(window_df$window_inconclusive), 1, 0),
      post_visible_gap_warning_count = ifelse(window_df$window == "post_visible_idle" & as.logical(window_df$window_gap_warning), 1, 0),
      post_visible_synthetic_wait_warning_count = ifelse(window_df$window == "post_visible_idle" & as.logical(window_df$window_synthetic_wait_warning), 1, 0),
      mean_action_window_detail_confidence = ifelse(window_df$window == "action_window", safe_numeric(window_df$detail_bucket_confidence), NA_real_),
      mean_post_visible_detail_confidence = ifelse(window_df$window == "post_visible_idle", safe_numeric(window_df$detail_bucket_confidence), NA_real_)
    ),
    by = list(
      lane = window_df$lane,
      pair_run_label = window_df$pair_run_label,
      role = window_df$role,
      probe_type = window_df$probe_type,
      run_id = window_df$run_id
    ),
    FUN = function(x) {
      if (is.numeric(x)) {
        if (all(is.na(x))) return(NA_real_)
        return(sum(x, na.rm = TRUE))
      }
      sum(x)
    }
  )

  if (nrow(window_conf_rollup) > 0L) {
    action_vals <- aggregate(
      list(mean_action_window_detail_confidence = safe_numeric(window_df$detail_bucket_confidence)),
      by = list(
        lane = window_df$lane,
        pair_run_label = window_df$pair_run_label,
        role = window_df$role,
        probe_type = window_df$probe_type,
        run_id = window_df$run_id,
        window = window_df$window
      ),
      FUN = function(x) if (all(is.na(x))) NA_real_ else mean(x, na.rm = TRUE)
    )

    action_only <- action_vals[action_vals$window == "action_window", c("lane", "pair_run_label", "role", "probe_type", "run_id", "mean_action_window_detail_confidence"), drop = FALSE]
    post_only <- action_vals[action_vals$window == "post_visible_idle", c("lane", "pair_run_label", "role", "probe_type", "run_id", "mean_action_window_detail_confidence"), drop = FALSE]
    names(post_only)[names(post_only) == "mean_action_window_detail_confidence"] <- "mean_post_visible_detail_confidence"

    window_conf_rollup <- merge(window_conf_rollup, action_only, by = c("lane", "pair_run_label", "role", "probe_type", "run_id"), all.x = TRUE)
    window_conf_rollup <- merge(window_conf_rollup, post_only, by = c("lane", "pair_run_label", "role", "probe_type", "run_id"), all.x = TRUE)

    drop_cols <- intersect(c("mean_action_window_detail_confidence.x", "mean_action_window_detail_confidence.y", "mean_post_visible_detail_confidence.x", "mean_post_visible_detail_confidence.y"), names(window_conf_rollup))
    if (length(drop_cols) > 0L) {
      for (col_name in drop_cols) {
        if (!(col_name %in% c("mean_action_window_detail_confidence", "mean_post_visible_detail_confidence"))) {
          window_conf_rollup[[col_name]] <- NULL
        }
      }
    }
  }

  conf_compare <- merge(
    runs_conf,
    window_conf_rollup,
    by = c("lane", "pair_run_label", "role", "probe_type", "run_id"),
    all.x = TRUE
  )

  conf_compare$action_window_inconclusive_share <- ifelse(
    conf_compare$action_window_count > 0,
    conf_compare$action_window_inconclusive_count / conf_compare$action_window_count,
    NA_real_
  )
  conf_compare$post_visible_inconclusive_share <- ifelse(
    conf_compare$post_visible_count > 0,
    conf_compare$post_visible_inconclusive_count / conf_compare$post_visible_count,
    NA_real_
  )
  conf_compare$action_window_gap_warning_share <- ifelse(
    conf_compare$action_window_count > 0,
    conf_compare$action_window_gap_warning_count / conf_compare$action_window_count,
    NA_real_
  )
  conf_compare$action_window_synthetic_wait_warning_share <- ifelse(
    conf_compare$action_window_count > 0,
    conf_compare$action_window_synthetic_wait_warning_count / conf_compare$action_window_count,
    NA_real_
  )
  conf_compare$post_visible_gap_warning_share <- ifelse(
    conf_compare$post_visible_count > 0,
    conf_compare$post_visible_gap_warning_count / conf_compare$post_visible_count,
    NA_real_
  )
  conf_compare$post_visible_synthetic_wait_warning_share <- ifelse(
    conf_compare$post_visible_count > 0,
    conf_compare$post_visible_synthetic_wait_warning_count / conf_compare$post_visible_count,
    NA_real_
  )

  conf_compare <- conf_compare[order(conf_compare$lane, conf_compare$role, conf_compare$run_id), , drop = FALSE]

  summary_payload <- list(
    label = label,
    detail_rows = nrow(detail_df),
    summary_rows = nrow(summary_df),
    run_rows = nrow(runs_df),
    window_confidence_rows = nrow(window_df),
    inconclusive_gate_rows = nrow(gate_df),
    classification_rows = nrow(class_agg),
    window_bucket_rows = nrow(window_bucket),
    confidence_comparison_rows = nrow(conf_compare),
    input_paths = list(
      detail_csv = normalizePath(detail_loaded$path, winslash = "/", mustWork = FALSE),
      summary_csv = normalizePath(summary_loaded$path, winslash = "/", mustWork = FALSE),
      runs_csv = normalizePath(runs_loaded$path, winslash = "/", mustWork = FALSE),
      window_confidence_csv = normalizePath(window_loaded$path, winslash = "/", mustWork = FALSE),
      inconclusive_gate_csv = normalizePath(gate_loaded$path, winslash = "/", mustWork = FALSE)
    )
  )

  timestamp_token <- format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC")
  prefix <- file.path(logs_dir, paste0("vp_perf_acceptance_decomposition_", label, "_", timestamp_token))

  class_path <- paste0(prefix, "_classification_audit.csv")
  window_bucket_path <- paste0(prefix, "_window_bucket.csv")
  conf_compare_path <- paste0(prefix, "_confidence_comparison.csv")
  summary_json_path <- paste0(prefix, "_audit_summary.json")

  utils::write.csv(class_agg, class_path, row.names = FALSE, na = "")
  utils::write.csv(window_bucket, window_bucket_path, row.names = FALSE, na = "")
  utils::write.csv(conf_compare, conf_compare_path, row.names = FALSE, na = "")

  if (requireNamespace("jsonlite", quietly = TRUE)) {
    writeLines(jsonlite::toJSON(summary_payload, pretty = TRUE, auto_unbox = TRUE), summary_json_path)
  }

  cat("VP_PERF_8C_STEP25D_ATTRIBUTION_AUDIT_START\n")
  cat(sprintf("VP_PERF_8C_STEP25D_ATTRIBUTION_AUDIT_LABEL=%s\n", label))
  cat(sprintf("VP_PERF_8C_STEP25D_ATTRIBUTION_AUDIT_DETAIL=%s\n", normalizePath(detail_loaded$path, winslash = "/", mustWork = FALSE)))
  cat(sprintf("VP_PERF_8C_STEP25D_ATTRIBUTION_AUDIT_SUMMARY=%s\n", normalizePath(summary_loaded$path, winslash = "/", mustWork = FALSE)))
  cat(sprintf("VP_PERF_8C_STEP25D_ATTRIBUTION_AUDIT_RUNS=%s\n", normalizePath(runs_loaded$path, winslash = "/", mustWork = FALSE)))
  cat(sprintf("VP_PERF_8C_STEP25D_ATTRIBUTION_AUDIT_WINDOW_CONFIDENCE=%s\n", normalizePath(window_loaded$path, winslash = "/", mustWork = FALSE)))
  cat(sprintf("VP_PERF_8C_STEP25D_ATTRIBUTION_AUDIT_INCONCLUSIVE_GATE=%s\n", normalizePath(gate_loaded$path, winslash = "/", mustWork = FALSE)))
  cat(sprintf("VP_PERF_8C_STEP25D_ATTRIBUTION_AUDIT_CLASSIFICATION_CSV=%s\n", normalizePath(class_path, winslash = "/", mustWork = FALSE)))
  cat(sprintf("VP_PERF_8C_STEP25D_ATTRIBUTION_AUDIT_WINDOW_BUCKET_CSV=%s\n", normalizePath(window_bucket_path, winslash = "/", mustWork = FALSE)))
  cat(sprintf("VP_PERF_8C_STEP25D_ATTRIBUTION_AUDIT_CONFIDENCE_COMPARISON_CSV=%s\n", normalizePath(conf_compare_path, winslash = "/", mustWork = FALSE)))
  if (file.exists(summary_json_path)) {
    cat(sprintf("VP_PERF_8C_STEP25D_ATTRIBUTION_AUDIT_SUMMARY_JSON=%s\n", normalizePath(summary_json_path, winslash = "/", mustWork = FALSE)))
  }
  cat("VP_PERF_8C_STEP25D_ATTRIBUTION_AUDIT_COMPLETE\n")
}

main()
