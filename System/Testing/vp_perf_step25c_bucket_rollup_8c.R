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

  stop("Could not resolve repository root for Step 25C rollup.", call. = FALSE)
}

safe_numeric <- function(x) {
  suppressWarnings(as.numeric(x))
}

main <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  repo_root <- resolve_repo_root(getwd())
  vp_clone_dir <- file.path(repo_root, "VP Clone")
  logs_dir <- file.path(vp_clone_dir, "Logs")
  dir.create(logs_dir, recursive = TRUE, showWarnings = FALSE)

  runs_arg <- trimws(as.character(parse_arg_value(args, "runs", default = "")))
  summary_arg <- trimws(as.character(parse_arg_value(args, "summary", default = "")))
  label <- trimws(as.character(parse_arg_value(args, "label", default = "step25c_rollup")))

  if (!nzchar(runs_arg) || !nzchar(summary_arg)) {
    stop("Missing required --runs and/or --summary arguments.", call. = FALSE)
  }

  runs_path <- normalizePath(runs_arg, winslash = "/", mustWork = FALSE)
  if (!file.exists(runs_path)) {
    runs_path <- normalizePath(file.path(vp_clone_dir, runs_arg), winslash = "/", mustWork = FALSE)
  }
  summary_path <- normalizePath(summary_arg, winslash = "/", mustWork = FALSE)
  if (!file.exists(summary_path)) {
    summary_path <- normalizePath(file.path(vp_clone_dir, summary_arg), winslash = "/", mustWork = FALSE)
  }

  if (!file.exists(runs_path)) stop(sprintf("Runs file not found: %s", runs_arg), call. = FALSE)
  if (!file.exists(summary_path)) stop(sprintf("Summary file not found: %s", summary_arg), call. = FALSE)

  runs_df <- utils::read.csv(runs_path, stringsAsFactors = FALSE, check.names = FALSE)
  summary_df <- utils::read.csv(summary_path, stringsAsFactors = FALSE, check.names = FALSE)

  if (nrow(runs_df) == 0L || nrow(summary_df) == 0L) {
    stop("Runs or summary file is empty.", call. = FALSE)
  }

  summary_df$total_attributed_elapsed_ms <- safe_numeric(summary_df$total_attributed_elapsed_ms)

  action_df <- summary_df[summary_df$window == "action_window", , drop = FALSE]
  action_role_lane <- aggregate(
    list(total_attr_ms = action_df$total_attributed_elapsed_ms),
    list(lane = action_df$lane, role = action_df$role),
    sum,
    na.rm = TRUE
  )

  action_bucket <- aggregate(
    list(total_attr_ms = action_df$total_attributed_elapsed_ms),
    list(lane = action_df$lane, role = action_df$role, bucket = action_df$bucket),
    sum,
    na.rm = TRUE
  )

  action_bucket <- merge(action_bucket, action_role_lane, by = c("lane", "role"), suffixes = c("", "_role_total"), all.x = TRUE)
  action_bucket$bucket_share <- ifelse(action_bucket$total_attr_ms_role_total > 0, action_bucket$total_attr_ms / action_bucket$total_attr_ms_role_total, NA_real_)

  role_totals <- reshape(
    action_role_lane,
    idvar = "lane",
    timevar = "role",
    direction = "wide"
  )
  names(role_totals) <- sub("total_attr_ms\\.", "", names(role_totals), perl = TRUE)
  if (!"baseline" %in% names(role_totals)) role_totals$baseline <- NA_real_
  if (!"candidate" %in% names(role_totals)) role_totals$candidate <- NA_real_
  role_totals$delta_ms <- role_totals$candidate - role_totals$baseline
  role_totals$improvement_pct <- ifelse(is.finite(role_totals$baseline) & role_totals$baseline > 0, (role_totals$baseline - role_totals$candidate) / role_totals$baseline, NA_real_)

  conf_by_lane <- aggregate(
    list(
      run_count = runs_df$run_id,
      mean_bucket_confidence = safe_numeric(runs_df$bucket_confidence),
      max_unclassified_attributed_ms = safe_numeric(runs_df$unclassified_attributed_ms)
    ),
    list(lane = runs_df$lane),
    function(x) {
      if (is.numeric(x)) {
        if (all(is.na(x))) return(NA_real_)
        return(mean(x, na.rm = TRUE))
      }
      length(x)
    }
  )

  conf_by_lane$run_count <- aggregate(list(run_count = runs_df$run_id), list(lane = runs_df$lane), length)$run_count
  conf_by_lane$max_unclassified_attributed_ms <- aggregate(
    list(max_unclassified_attributed_ms = safe_numeric(runs_df$unclassified_attributed_ms)),
    list(lane = runs_df$lane),
    max,
    na.rm = TRUE
  )$max_unclassified_attributed_ms

  timestamp_token <- format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC")
  prefix <- file.path(logs_dir, paste0("vp_perf_acceptance_decomposition_", label, "_", timestamp_token))

  by_bucket_path <- paste0(prefix, "_action_bucket.csv")
  by_lane_path <- paste0(prefix, "_lane_delta.csv")
  conf_path <- paste0(prefix, "_lane_confidence.csv")

  action_bucket <- action_bucket[order(action_bucket$lane, action_bucket$role, -action_bucket$bucket_share, -action_bucket$total_attr_ms), , drop = FALSE]
  role_totals <- role_totals[order(role_totals$lane), , drop = FALSE]
  conf_by_lane <- conf_by_lane[order(conf_by_lane$lane), , drop = FALSE]

  utils::write.csv(action_bucket, by_bucket_path, row.names = FALSE, na = "")
  utils::write.csv(role_totals, by_lane_path, row.names = FALSE, na = "")
  utils::write.csv(conf_by_lane, conf_path, row.names = FALSE, na = "")

  cat("VP_PERF_8C_STEP25C_ROLLUP_START\n")
  cat(sprintf("VP_PERF_8C_STEP25C_ROLLUP_LABEL=%s\n", label))
  cat(sprintf("VP_PERF_8C_STEP25C_ROLLUP_RUNS=%s\n", normalizePath(runs_path, winslash = "/", mustWork = FALSE)))
  cat(sprintf("VP_PERF_8C_STEP25C_ROLLUP_SUMMARY=%s\n", normalizePath(summary_path, winslash = "/", mustWork = FALSE)))
  cat(sprintf("VP_PERF_8C_STEP25C_ROLLUP_ACTION_BUCKET_CSV=%s\n", normalizePath(by_bucket_path, winslash = "/", mustWork = FALSE)))
  cat(sprintf("VP_PERF_8C_STEP25C_ROLLUP_LANE_DELTA_CSV=%s\n", normalizePath(by_lane_path, winslash = "/", mustWork = FALSE)))
  cat(sprintf("VP_PERF_8C_STEP25C_ROLLUP_LANE_CONFIDENCE_CSV=%s\n", normalizePath(conf_path, winslash = "/", mustWork = FALSE)))
  cat("VP_PERF_8C_STEP25C_ROLLUP_COMPLETE\n")
}

main()
