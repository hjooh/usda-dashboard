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

safe_numeric <- function(value) {
  suppressWarnings(as.numeric(value))
}

safe_read_csv <- function(path) {
  if (!file.exists(path)) return(data.frame(stringsAsFactors = FALSE))
  tryCatch(
    utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE),
    error = function(...) data.frame(stringsAsFactors = FALSE)
  )
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

  stop("Could not resolve repository root for VP acceptance decision script.", call. = FALSE)
}

infer_probe_type <- function(row) {
  explicit <- trimws(as.character(row$probe_type %||% ""))
  if (nzchar(explicit)) return(explicit)

  candidate <- paste(
    trimws(as.character(row$output_csv_path %||% "")),
    trimws(as.character(row$label %||% "")),
    sep = "|"
  )

  if (grepl("startup", candidate, ignore.case = TRUE, perl = TRUE)) return("startup")
  if (grepl("single_action", candidate, ignore.case = TRUE, perl = TRUE)) return("single_action")
  "unknown"
}

row_matches_selector <- function(df, selector_regex) {
  if (!is.data.frame(df) || nrow(df) == 0L) return(logical(0))
  selector_regex <- trimws(as.character(selector_regex %||% ""))
  if (!nzchar(selector_regex)) return(rep(FALSE, nrow(df)))

  row_text <- apply(df, 1L, function(row) paste(as.character(row), collapse = "|"))
  grepl(selector_regex, row_text, ignore.case = TRUE, perl = TRUE)
}

extract_probe_metric <- function(csv_path, probe_type) {
  csv_path <- normalizePath(csv_path, winslash = "/", mustWork = FALSE)
  df <- safe_read_csv(csv_path)
  if (nrow(df) == 0L) {
    return(list(metric_ms = NA_real_, run_pass = FALSE, status_text = "missing_or_unreadable_csv", sample_count = 0L))
  }

  if (identical(probe_type, "startup")) {
    metric <- safe_numeric(df$startup_to_ready_ms[[1L]] %||% NA_real_)
    status_text <- as.character(df$status[[1L]] %||% "")
    run_pass <- identical(status_text, "PASS")
    return(list(metric_ms = metric, run_pass = run_pass, status_text = status_text, sample_count = 1L))
  }

  if (identical(probe_type, "single_action")) {
    status_values <- as.character(df$status %||% "")
    status_values[is.na(status_values)] <- ""
    pass_rows <- status_values %in% "PASS"
    visible_values <- safe_numeric(df$visible_ready_ms %||% NA_real_)
    visible_values <- visible_values[pass_rows & is.finite(visible_values)]
    metric <- if (length(visible_values) > 0L) stats::median(visible_values) else NA_real_
    run_pass <- nrow(df) > 0L && all(status_values %in% "PASS")
    status_text <- paste(names(table(status_values)), as.integer(table(status_values)), sep = "=", collapse = "|")
    return(list(metric_ms = metric, run_pass = run_pass, status_text = status_text, sample_count = length(visible_values)))
  }

  list(metric_ms = NA_real_, run_pass = FALSE, status_text = "unsupported_probe_type", sample_count = 0L)
}

mad_ratio <- function(values) {
  values <- safe_numeric(values)
  values <- values[is.finite(values)]
  if (length(values) == 0L) return(NA_real_)
  med <- stats::median(values)
  if (!is.finite(med) || med <= 0) return(NA_real_)
  stats::mad(values, center = med, constant = 1, na.rm = TRUE) / med
}

bootstrap_improvement_ci <- function(baseline_values, candidate_values, reps = 2000L, confidence = 0.95, seed = 1L) {
  baseline_values <- safe_numeric(baseline_values)
  baseline_values <- baseline_values[is.finite(baseline_values)]
  candidate_values <- safe_numeric(candidate_values)
  candidate_values <- candidate_values[is.finite(candidate_values)]

  if (length(baseline_values) == 0L || length(candidate_values) == 0L) {
    return(list(lower = NA_real_, upper = NA_real_, median = NA_real_))
  }

  baseline_median <- stats::median(baseline_values)
  if (!is.finite(baseline_median) || baseline_median <= 0) {
    return(list(lower = NA_real_, upper = NA_real_, median = NA_real_))
  }

  reps <- suppressWarnings(as.integer(reps))
  if (!is.finite(reps) || is.na(reps) || reps < 200L) reps <- 2000L
  confidence <- suppressWarnings(as.numeric(confidence))
  if (!is.finite(confidence) || is.na(confidence) || confidence <= 0 || confidence >= 1) confidence <- 0.95

  set.seed(as.integer(seed %||% 1L))
  samples <- replicate(reps, {
    baseline_sample <- sample(baseline_values, length(baseline_values), replace = TRUE)
    candidate_sample <- sample(candidate_values, length(candidate_values), replace = TRUE)
    med <- stats::median(baseline_sample)
    if (!is.finite(med) || med <= 0) return(NA_real_)
    (med - stats::median(candidate_sample)) / med
  })

  samples <- samples[is.finite(samples)]
  if (length(samples) == 0L) {
    return(list(lower = NA_real_, upper = NA_real_, median = NA_real_))
  }

  alpha <- (1 - confidence) / 2
  q <- stats::quantile(samples, probs = c(alpha, 1 - alpha), na.rm = TRUE, names = FALSE)
  list(lower = as.numeric(q[[1L]]), upper = as.numeric(q[[2L]]), median = stats::median(samples, na.rm = TRUE))
}

evaluate_probe_gate <- function(detail_df, probe_type, min_runs, improvement_threshold, max_mad_ratio, bootstrap_reps, confidence_level, bootstrap_seed) {
  subset_df <- detail_df[detail_df$probe_type %in% probe_type, , drop = FALSE]

  baseline_df <- subset_df[subset_df$lane %in% "baseline", , drop = FALSE]
  candidate_df <- subset_df[subset_df$lane %in% "candidate", , drop = FALSE]

  baseline_values <- safe_numeric(baseline_df$metric_ms)
  baseline_values <- baseline_values[is.finite(baseline_values)]
  candidate_values <- safe_numeric(candidate_df$metric_ms)
  candidate_values <- candidate_values[is.finite(candidate_values)]

  baseline_runs <- length(baseline_values)
  candidate_runs <- length(candidate_values)

  baseline_median <- if (baseline_runs > 0L) stats::median(baseline_values) else NA_real_
  candidate_median <- if (candidate_runs > 0L) stats::median(candidate_values) else NA_real_
  improvement_ratio <- if (is.finite(baseline_median) && baseline_median > 0 && is.finite(candidate_median)) {
    (baseline_median - candidate_median) / baseline_median
  } else {
    NA_real_
  }

  baseline_mad_ratio <- mad_ratio(baseline_values)
  candidate_mad_ratio <- mad_ratio(candidate_values)
  ci <- bootstrap_improvement_ci(
    baseline_values = baseline_values,
    candidate_values = candidate_values,
    reps = bootstrap_reps,
    confidence = confidence_level,
    seed = bootstrap_seed
  )

  baseline_pass_rate <- if (nrow(baseline_df) > 0L) mean(as.logical(baseline_df$run_pass %||% FALSE), na.rm = TRUE) else NA_real_
  candidate_pass_rate <- if (nrow(candidate_df) > 0L) mean(as.logical(candidate_df$run_pass %||% FALSE), na.rm = TRUE) else NA_real_

  min_runs_pass <- baseline_runs >= min_runs && candidate_runs >= min_runs
  improvement_pass <- is.finite(improvement_ratio) && improvement_ratio >= improvement_threshold
  mad_pass <- is.finite(baseline_mad_ratio) && is.finite(candidate_mad_ratio) &&
    baseline_mad_ratio <= max_mad_ratio && candidate_mad_ratio <= max_mad_ratio
  ci_pass <- is.finite(ci$lower) && ci$lower > 0

  all_pass <- isTRUE(min_runs_pass) && isTRUE(improvement_pass) && isTRUE(mad_pass) && isTRUE(ci_pass)

  reasons <- c(
    if (!isTRUE(min_runs_pass)) sprintf("min_runs_failed baseline=%d candidate=%d threshold=%d", baseline_runs, candidate_runs, min_runs) else character(0),
    if (!isTRUE(improvement_pass)) sprintf("improvement_failed observed=%.6f threshold=%.6f", improvement_ratio %||% NA_real_, improvement_threshold) else character(0),
    if (!isTRUE(mad_pass)) sprintf("mad_failed baseline=%.6f candidate=%.6f threshold=%.6f", baseline_mad_ratio %||% NA_real_, candidate_mad_ratio %||% NA_real_, max_mad_ratio) else character(0),
    if (!isTRUE(ci_pass)) sprintf("ci_failed lower=%.6f upper=%.6f", ci$lower %||% NA_real_, ci$upper %||% NA_real_) else character(0)
  )

  data.frame(
    probe_type = probe_type,
    gate_status = if (isTRUE(all_pass)) "PASS" else "FAIL",
    reason = if (length(reasons) > 0L) paste(reasons, collapse = " || ") else "",
    baseline_runs = baseline_runs,
    candidate_runs = candidate_runs,
    min_runs_required = min_runs,
    baseline_pass_rate = baseline_pass_rate,
    candidate_pass_rate = candidate_pass_rate,
    baseline_median_ms = baseline_median,
    candidate_median_ms = candidate_median,
    improvement_ratio = improvement_ratio,
    improvement_threshold = improvement_threshold,
    baseline_mad_ratio = baseline_mad_ratio,
    candidate_mad_ratio = candidate_mad_ratio,
    max_mad_ratio = max_mad_ratio,
    bootstrap_ci_lower = ci$lower,
    bootstrap_ci_upper = ci$upper,
    bootstrap_ci_median = ci$median,
    ci_confidence = confidence_level,
    ci_requires_lower_gt_zero = TRUE,
    stringsAsFactors = FALSE
  )
}

main <- function() {
  args <- commandArgs(trailingOnly = TRUE)

  label <- trimws(as.character(parse_arg_value(args, "label", default = "acceptance_decision")))
  if (!nzchar(label)) label <- "acceptance_decision"

  baseline_selector <- trimws(as.character(parse_arg_value(args, "baseline-selector", default = "baseline")))
  candidate_selector <- trimws(as.character(parse_arg_value(args, "candidate-selector", default = "candidate")))
  if (!nzchar(baseline_selector) || !nzchar(candidate_selector)) {
    stop("Both --baseline-selector and --candidate-selector are required.", call. = FALSE)
  }

  run_ids <- vp_perf_split_pipe_values(parse_arg_value(args, "run-id", default = ""))
  session_ids <- vp_perf_split_pipe_values(parse_arg_value(args, "session-id", default = ""))
  probe_types <- vp_perf_split_pipe_values(parse_arg_value(args, "probe-type", default = "startup|single_action"))
  if (length(probe_types) == 0L) probe_types <- c("startup", "single_action")

  strict_manifest <- is_truthy(parse_arg_value(args, "strict-manifest", default = "true"), default = TRUE)
  acceptance_only <- is_truthy(parse_arg_value(args, "acceptance-only", default = "true"), default = TRUE)
  manifest_path_arg <- trimws(as.character(parse_arg_value(args, "acceptance-manifest", default = "")))
  cache_state_filter <- trimws(as.character(parse_arg_value(args, "cache-state", default = "")))
  scenario_filter <- trimws(as.character(parse_arg_value(args, "scenario", default = "")))

  min_runs <- suppressWarnings(as.integer(parse_arg_value(args, "min-runs", default = "9")))
  if (!is.finite(min_runs) || is.na(min_runs) || min_runs < 1L) min_runs <- 9L

  startup_improvement_threshold <- suppressWarnings(as.numeric(parse_arg_value(args, "startup-improvement-min", default = "0.25")))
  if (!is.finite(startup_improvement_threshold) || is.na(startup_improvement_threshold)) startup_improvement_threshold <- 0.25

  single_action_improvement_threshold <- suppressWarnings(as.numeric(parse_arg_value(args, "single-action-improvement-min", default = "0.20")))
  if (!is.finite(single_action_improvement_threshold) || is.na(single_action_improvement_threshold)) single_action_improvement_threshold <- 0.20

  max_mad_ratio <- suppressWarnings(as.numeric(parse_arg_value(args, "max-mad-ratio", default = "0.60")))
  if (!is.finite(max_mad_ratio) || is.na(max_mad_ratio) || max_mad_ratio <= 0) max_mad_ratio <- 0.60

  bootstrap_reps <- suppressWarnings(as.integer(parse_arg_value(args, "bootstrap-reps", default = "2000")))
  if (!is.finite(bootstrap_reps) || is.na(bootstrap_reps) || bootstrap_reps < 200L) bootstrap_reps <- 2000L

  confidence_level <- suppressWarnings(as.numeric(parse_arg_value(args, "confidence", default = "0.95")))
  if (!is.finite(confidence_level) || is.na(confidence_level) || confidence_level <= 0 || confidence_level >= 1) confidence_level <- 0.95

  bootstrap_seed <- suppressWarnings(as.integer(parse_arg_value(args, "bootstrap-seed", default = "1")))
  if (!is.finite(bootstrap_seed) || is.na(bootstrap_seed)) bootstrap_seed <- 1L

  repo_root <- resolve_repo_root(getwd())
  vp_clone_dir <- file.path(repo_root, "VP Clone")
  logs_dir <- file.path(vp_clone_dir, "Logs")
  dir.create(logs_dir, recursive = TRUE, showWarnings = FALSE)

  manifest_resolution <- vp_perf_resolve_manifest_inputs(
    logs_dir = logs_dir,
    manifest_path_arg = manifest_path_arg,
    run_ids = run_ids,
    session_ids = session_ids,
    acceptance_only = acceptance_only,
    probe_types = probe_types,
    strict_manifest_rows = strict_manifest
  )

  manifest_rows <- manifest_resolution$rows
  if (isTRUE(strict_manifest) && nrow(manifest_rows) == 0L) {
    stop("No manifest rows matched filters in strict-manifest mode.", call. = FALSE)
  }

  if (nzchar(cache_state_filter) && "cache_state" %in% names(manifest_rows)) {
    manifest_rows <- manifest_rows[trimws(as.character(manifest_rows$cache_state %||% "")) %in% cache_state_filter, , drop = FALSE]
  }
  if (nzchar(scenario_filter) && "scenario" %in% names(manifest_rows)) {
    manifest_rows <- manifest_rows[trimws(as.character(manifest_rows$scenario %||% "")) %in% scenario_filter, , drop = FALSE]
  }

  if (nrow(manifest_rows) == 0L) {
    stop("No manifest rows remained after cache-state/scenario filtering.", call. = FALSE)
  }

  baseline_match <- row_matches_selector(manifest_rows, baseline_selector)
  candidate_match <- row_matches_selector(manifest_rows, candidate_selector)
  overlap <- baseline_match & candidate_match
  if (any(overlap)) {
    stop("Some manifest rows match both baseline-selector and candidate-selector; selectors must be mutually exclusive.", call. = FALSE)
  }

  baseline_rows <- manifest_rows[baseline_match, , drop = FALSE]
  candidate_rows <- manifest_rows[candidate_match, , drop = FALSE]
  if (nrow(baseline_rows) == 0L || nrow(candidate_rows) == 0L) {
    stop("Selectors did not produce both baseline and candidate row sets.", call. = FALSE)
  }

  extract_lane_details <- function(rows, lane_name) {
    row_list <- lapply(seq_len(nrow(rows)), function(index) {
      row <- rows[index, , drop = FALSE]
      output_csv_path <- trimws(as.character(row$output_csv_path[[1L]] %||% ""))
      probe_type <- infer_probe_type(row)
      extracted <- extract_probe_metric(output_csv_path, probe_type)
      data.frame(
        lane = lane_name,
        probe_type = probe_type,
        output_csv_path = output_csv_path,
        run_id = as.character(row$run_id[[1L]] %||% ""),
        session_id = as.character(row$session_id[[1L]] %||% ""),
        label = as.character(row$label[[1L]] %||% ""),
        scenario = as.character(row$scenario[[1L]] %||% ""),
        cache_state = as.character(row$cache_state[[1L]] %||% ""),
        provider_mode = as.character(row$provider_mode[[1L]] %||% ""),
        acceptance_mode = as.character(row$acceptance_mode[[1L]] %||% ""),
        status = as.character(row$status[[1L]] %||% ""),
        base_status = as.character(row$base_status[[1L]] %||% ""),
        metric_ms = extracted$metric_ms,
        run_pass = isTRUE(extracted$run_pass),
        metric_status_text = extracted$status_text,
        metric_sample_count = extracted$sample_count,
        stringsAsFactors = FALSE
      )
    })
    do.call(rbind, row_list)
  }

  detail_df <- rbind(
    extract_lane_details(baseline_rows, "baseline"),
    extract_lane_details(candidate_rows, "candidate")
  )

  detail_df <- detail_df[detail_df$probe_type %in% probe_types, , drop = FALSE]

  startup_gate <- evaluate_probe_gate(
    detail_df = detail_df,
    probe_type = "startup",
    min_runs = min_runs,
    improvement_threshold = startup_improvement_threshold,
    max_mad_ratio = max_mad_ratio,
    bootstrap_reps = bootstrap_reps,
    confidence_level = confidence_level,
    bootstrap_seed = bootstrap_seed
  )

  single_action_gate <- evaluate_probe_gate(
    detail_df = detail_df,
    probe_type = "single_action",
    min_runs = min_runs,
    improvement_threshold = single_action_improvement_threshold,
    max_mad_ratio = max_mad_ratio,
    bootstrap_reps = bootstrap_reps,
    confidence_level = confidence_level,
    bootstrap_seed = bootstrap_seed
  )

  gate_df <- rbind(startup_gate, single_action_gate)

  requested_gates <- gate_df[gate_df$probe_type %in% unique(probe_types), , drop = FALSE]
  overall_pass <- nrow(requested_gates) > 0L && all(requested_gates$gate_status %in% "PASS")

  overall_row <- data.frame(
    probe_type = "overall",
    gate_status = if (isTRUE(overall_pass)) "PASS" else "FAIL",
    reason = if (isTRUE(overall_pass)) "" else paste(stats::na.omit(requested_gates$reason[requested_gates$gate_status %in% "FAIL"]), collapse = " || "),
    baseline_runs = sum(requested_gates$baseline_runs, na.rm = TRUE),
    candidate_runs = sum(requested_gates$candidate_runs, na.rm = TRUE),
    min_runs_required = min_runs,
    baseline_pass_rate = NA_real_,
    candidate_pass_rate = NA_real_,
    baseline_median_ms = NA_real_,
    candidate_median_ms = NA_real_,
    improvement_ratio = NA_real_,
    improvement_threshold = NA_real_,
    baseline_mad_ratio = NA_real_,
    candidate_mad_ratio = NA_real_,
    max_mad_ratio = max_mad_ratio,
    bootstrap_ci_lower = NA_real_,
    bootstrap_ci_upper = NA_real_,
    bootstrap_ci_median = NA_real_,
    ci_confidence = confidence_level,
    ci_requires_lower_gt_zero = TRUE,
    stringsAsFactors = FALSE
  )

  decision_df <- rbind(gate_df, overall_row)

  timestamp_token <- format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC")
  output_prefix <- file.path(logs_dir, paste0("vp_perf_acceptance_decision_", label, "_", timestamp_token))

  detail_path <- paste0(output_prefix, "_details.csv")
  decision_path <- paste0(output_prefix, "_decision.csv")

  utils::write.csv(detail_df, detail_path, row.names = FALSE, na = "")
  utils::write.csv(decision_df, decision_path, row.names = FALSE, na = "")

  summary_df <- data.frame(
    label = label,
    strict_manifest = isTRUE(strict_manifest),
    acceptance_only = isTRUE(acceptance_only),
    baseline_selector = baseline_selector,
    candidate_selector = candidate_selector,
    probe_types = paste(probe_types, collapse = "|"),
    cache_state_filter = cache_state_filter,
    scenario_filter = scenario_filter,
    manifest_path = manifest_resolution$manifest_path,
    manifest_rows_used = nrow(manifest_rows),
    baseline_rows = nrow(baseline_rows),
    candidate_rows = nrow(candidate_rows),
    detail_rows = nrow(detail_df),
    decision_rows = nrow(decision_df),
    overall_status = if (isTRUE(overall_pass)) "PASS" else "FAIL",
    min_runs = min_runs,
    startup_improvement_threshold = startup_improvement_threshold,
    single_action_improvement_threshold = single_action_improvement_threshold,
    max_mad_ratio = max_mad_ratio,
    bootstrap_reps = bootstrap_reps,
    confidence_level = confidence_level,
    bootstrap_seed = bootstrap_seed,
    args = vp_perf_join_args(args),
    stringsAsFactors = FALSE
  )

  summary_path <- paste0(output_prefix, "_summary.csv")
  utils::write.csv(summary_df, summary_path, row.names = FALSE, na = "")

  cat("VP_PERF_ACCEPTANCE_DECISION_START\n")
  cat(sprintf("VP_PERF_ACCEPTANCE_DECISION_LABEL=%s\n", label))
  cat(sprintf("VP_PERF_ACCEPTANCE_DECISION_MANIFEST=%s\n", manifest_resolution$manifest_path))
  cat(sprintf("VP_PERF_ACCEPTANCE_DECISION_MANIFEST_ROWS_USED=%d\n", nrow(manifest_rows)))
  cat(sprintf("VP_PERF_ACCEPTANCE_DECISION_BASELINE_ROWS=%d\n", nrow(baseline_rows)))
  cat(sprintf("VP_PERF_ACCEPTANCE_DECISION_CANDIDATE_ROWS=%d\n", nrow(candidate_rows)))
  cat(sprintf("VP_PERF_ACCEPTANCE_DECISION_OVERALL_STATUS=%s\n", if (isTRUE(overall_pass)) "PASS" else "FAIL"))
  cat(sprintf("VP_PERF_ACCEPTANCE_DECISION_SUMMARY=%s\n", normalizePath(summary_path, winslash = "/", mustWork = FALSE)))
  cat(sprintf("VP_PERF_ACCEPTANCE_DECISION_DETAIL=%s\n", normalizePath(detail_path, winslash = "/", mustWork = FALSE)))
  cat(sprintf("VP_PERF_ACCEPTANCE_DECISION_FILE=%s\n", normalizePath(decision_path, winslash = "/", mustWork = FALSE)))
  for (index in seq_len(nrow(decision_df))) {
    cat(sprintf(
      "VP_PERF_ACCEPTANCE_DECISION_ROW=%s|%s|reason=%s\n",
      decision_df$probe_type[[index]],
      decision_df$gate_status[[index]],
      decision_df$reason[[index]] %||% ""
    ))
  }
  cat("VP_PERF_ACCEPTANCE_DECISION_COMPLETE\n")
}

main()