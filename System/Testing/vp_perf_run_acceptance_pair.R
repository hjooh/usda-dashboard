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

`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0L) y else x
}

source(file.path("System", "Testing", "vp_perf_acceptance_manifest.R"), local = TRUE)

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

  stop("Could not resolve repository root for VP acceptance orchestration.", call. = FALSE)
}

escape_shell_value <- function(value) {
  value <- as.character(value %||% "")
  value <- gsub('"', '\\"', value, fixed = TRUE)
  paste0('"', value, '"')
}

run_rscript <- function(rscript_exe, script_path, args_named) {
  parts <- c(escape_shell_value(rscript_exe), escape_shell_value(script_path))
  if (length(args_named) > 0L) {
    for (name in names(args_named)) {
      parts <- c(parts, paste0("--", name, "=", escape_shell_value(args_named[[name]])))
    }
  }
  command <- paste(parts, collapse = " ")

  cat(sprintf("VP_PERF_ACCEPTANCE_PAIR_EXEC=%s\n", command))
  status <- suppressWarnings(system(command, ignore.stdout = FALSE, ignore.stderr = FALSE))
  if (!identical(status, 0L)) {
    stop(sprintf("Command failed with status %s: %s", status, command), call. = FALSE)
  }
}

build_probe_label <- function(label, lane, probe) {
  paste(c(label, lane, probe), collapse = "__")
}

lane_suffix_token <- function(tag_value) {
  token <- trimws(as.character(tag_value %||% ""))
  if (!nzchar(token)) return(NA_character_)
  paste0("__", token, "__")
}

infer_lane_from_label <- function(label_value, baseline_tag, candidate_tag) {
  label_value <- trimws(as.character(label_value %||% ""))
  baseline_token <- lane_suffix_token(baseline_tag)
  candidate_token <- lane_suffix_token(candidate_tag)

  if (!is.na(baseline_token) && grepl(baseline_token, label_value, fixed = TRUE)) return("baseline")
  if (!is.na(candidate_token) && grepl(candidate_token, label_value, fixed = TRUE)) return("candidate")
  NA_character_
}

build_expected_context_rows <- function(
    pair_run_id,
    iterations,
    label,
    baseline_tag,
    candidate_tag,
    baseline_cache_state,
    candidate_cache_state,
  baseline_comparison_plot_cache_off,
  candidate_comparison_plot_cache_off,
    baseline_scenario,
    candidate_scenario,
    runtime_perf,
    perf_boundary_markers) {
  rows <- list()
  row_index <- 0L
  runtime_enabled_value <- is_truthy(runtime_perf, default = TRUE)
  boundary_markers_value <- is_truthy(perf_boundary_markers, default = FALSE)
  baseline_cache_off_value <- is_truthy(baseline_comparison_plot_cache_off, default = FALSE)
  candidate_cache_off_value <- is_truthy(candidate_comparison_plot_cache_off, default = FALSE)

  for (iter_index in seq_len(iterations)) {
    iter_token <- sprintf("iter%02d", iter_index)

    baseline_startup_label <- build_probe_label(label, baseline_tag, paste0("startup_", iter_token))
    candidate_startup_label <- build_probe_label(label, candidate_tag, paste0("startup_", iter_token))
    baseline_action_label <- build_probe_label(label, baseline_tag, paste0("single_action_", iter_token))
    candidate_action_label <- build_probe_label(label, candidate_tag, paste0("single_action_", iter_token))

    row_index <- row_index + 1L
    rows[[row_index]] <- data.frame(
      lane = "baseline",
      probe_type = "startup",
      run_id = paste(pair_run_id, baseline_tag, iter_token, "startup", sep = "__"),
      session_id = paste(pair_run_id, baseline_tag, sep = "__"),
      label = baseline_startup_label,
      scenario = "startup_current_tab",
      cache_state = baseline_cache_state,
      comparison_plot_cache_off = baseline_cache_off_value,
      comparison_plot_cache_mode = if (isTRUE(baseline_cache_off_value)) "final_output_cache_off" else "final_output_cache_on",
      final_output_bindcache_enabled = !baseline_cache_off_value,
      runtime_enabled = runtime_enabled_value,
      perf_boundary_markers_enabled = boundary_markers_value,
      stringsAsFactors = FALSE
    )

    row_index <- row_index + 1L
    rows[[row_index]] <- data.frame(
      lane = "candidate",
      probe_type = "startup",
      run_id = paste(pair_run_id, candidate_tag, iter_token, "startup", sep = "__"),
      session_id = paste(pair_run_id, candidate_tag, sep = "__"),
      label = candidate_startup_label,
      scenario = "startup_current_tab",
      cache_state = candidate_cache_state,
      comparison_plot_cache_off = candidate_cache_off_value,
      comparison_plot_cache_mode = if (isTRUE(candidate_cache_off_value)) "final_output_cache_off" else "final_output_cache_on",
      final_output_bindcache_enabled = !candidate_cache_off_value,
      runtime_enabled = runtime_enabled_value,
      perf_boundary_markers_enabled = boundary_markers_value,
      stringsAsFactors = FALSE
    )

    row_index <- row_index + 1L
    rows[[row_index]] <- data.frame(
      lane = "baseline",
      probe_type = "single_action",
      run_id = paste(pair_run_id, baseline_tag, iter_token, "single_action", sep = "__"),
      session_id = paste(pair_run_id, baseline_tag, sep = "__"),
      label = baseline_action_label,
      scenario = baseline_scenario,
      cache_state = baseline_cache_state,
      comparison_plot_cache_off = baseline_cache_off_value,
      comparison_plot_cache_mode = if (isTRUE(baseline_cache_off_value)) "final_output_cache_off" else "final_output_cache_on",
      final_output_bindcache_enabled = !baseline_cache_off_value,
      runtime_enabled = runtime_enabled_value,
      perf_boundary_markers_enabled = boundary_markers_value,
      stringsAsFactors = FALSE
    )

    row_index <- row_index + 1L
    rows[[row_index]] <- data.frame(
      lane = "candidate",
      probe_type = "single_action",
      run_id = paste(pair_run_id, candidate_tag, iter_token, "single_action", sep = "__"),
      session_id = paste(pair_run_id, candidate_tag, sep = "__"),
      label = candidate_action_label,
      scenario = candidate_scenario,
      cache_state = candidate_cache_state,
      comparison_plot_cache_off = candidate_cache_off_value,
      comparison_plot_cache_mode = if (isTRUE(candidate_cache_off_value)) "final_output_cache_off" else "final_output_cache_on",
      final_output_bindcache_enabled = !candidate_cache_off_value,
      runtime_enabled = runtime_enabled_value,
      perf_boundary_markers_enabled = boundary_markers_value,
      stringsAsFactors = FALSE
    )
  }

  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

run_phase3_preflight <- function(
    logs_dir,
    acceptance_manifest_path,
    expected_context_rows,
    pair_run_id,
    strict_context_validation,
    strict_runtime_identity,
    baseline_tag,
    candidate_tag) {
  pair_run_id <- trimws(as.character(pair_run_id %||% ""))

  manifest_loaded <- vp_perf_load_manifest(logs_dir = logs_dir, manifest_path_arg = acceptance_manifest_path)
  manifest_rows <- manifest_loaded$data
  if (!is.data.frame(manifest_rows)) {
    manifest_rows <- data.frame(stringsAsFactors = FALSE)
  }

  if (nrow(manifest_rows) > 0L) {
    probe_values <- trimws(as.character(manifest_rows$probe_type %||% ""))
    manifest_rows <- manifest_rows[probe_values %in% c("startup", "single_action"), , drop = FALSE]
  }

  if (nrow(manifest_rows) > 0L && "run_id" %in% names(manifest_rows) && nzchar(pair_run_id)) {
    run_values <- trimws(as.character(manifest_rows$run_id %||% ""))
    manifest_rows <- manifest_rows[startsWith(run_values, pair_run_id), , drop = FALSE]
  }

  if (nrow(manifest_rows) > 0L && "label" %in% names(manifest_rows)) {
    lanes <- vapply(as.character(manifest_rows$label %||% ""), infer_lane_from_label, character(1), baseline_tag = baseline_tag, candidate_tag = candidate_tag)
    manifest_rows$lane <- lanes
  } else {
    manifest_rows$lane <- character(0)
  }

  context_validation <- vp_perf_validate_pair_manifest_context(
    manifest_df = manifest_rows,
    expected_rows = expected_context_rows,
    strict = FALSE
  )

  identity_validation <- vp_perf_validate_runtime_log_identity(
    manifest_df = context_validation$rows,
    strict = FALSE
  )

  telemetry <- list(
    manifest_path = normalizePath(manifest_loaded$path, winslash = "/", mustWork = FALSE),
    manifest_rows_total = nrow(manifest_rows),
    expected_rows_total = nrow(expected_context_rows),
    context_ok = isTRUE(context_validation$ok),
    context_error_count = length(context_validation$errors),
    identity_ok = isTRUE(identity_validation$ok),
    identity_error_count = length(identity_validation$errors),
    strict_context_validation = isTRUE(strict_context_validation),
    strict_runtime_identity = isTRUE(strict_runtime_identity)
  )

  overall_ok <- isTRUE(context_validation$ok) && isTRUE(identity_validation$ok)
  if (isTRUE(strict_context_validation) && !isTRUE(context_validation$ok)) overall_ok <- FALSE
  if (isTRUE(strict_runtime_identity) && !isTRUE(identity_validation$ok)) overall_ok <- FALSE

  list(
    ok = isTRUE(overall_ok),
    telemetry = telemetry,
    context = context_validation,
    identity = identity_validation
  )
}

main <- function() {
  args <- commandArgs(trailingOnly = TRUE)

  label <- trimws(as.character(parse_arg_value(args, "label", default = "acceptance_pair")))
  if (!nzchar(label)) label <- "acceptance_pair"

  iterations <- suppressWarnings(as.integer(parse_arg_value(args, "iterations", default = "9")))
  if (!is.finite(iterations) || is.na(iterations) || iterations < 1L) iterations <- 9L

  startup_target_tab <- trimws(as.character(parse_arg_value(args, "startup-target-tab", default = "Current vs. Average")))
  if (!nzchar(startup_target_tab)) startup_target_tab <- "Current vs. Average"

  baseline_tag <- trimws(as.character(parse_arg_value(args, "baseline-tag", default = "baseline")))
  candidate_tag <- trimws(as.character(parse_arg_value(args, "candidate-tag", default = "candidate")))
  if (!nzchar(baseline_tag)) baseline_tag <- "baseline"
  if (!nzchar(candidate_tag)) candidate_tag <- "candidate"

  baseline_cache_state <- trimws(as.character(parse_arg_value(args, "baseline-cache-state", default = "warm_partition_disk")))
  candidate_cache_state <- trimws(as.character(parse_arg_value(args, "candidate-cache-state", default = "warm_partition_disk")))
  baseline_comparison_plot_cache_off <- if (is_truthy(parse_arg_value(args, "baseline-comparison-plot-cache-off", default = "false"), default = FALSE)) "true" else "false"
  candidate_comparison_plot_cache_off <- if (is_truthy(parse_arg_value(args, "candidate-comparison-plot-cache-off", default = "false"), default = FALSE)) "true" else "false"

  baseline_scenario <- trimws(as.character(parse_arg_value(args, "baseline-scenario", default = "tab_only")))
  candidate_scenario <- trimws(as.character(parse_arg_value(args, "candidate-scenario", default = "tab_only")))

  baseline_artifact <- trimws(as.character(parse_arg_value(args, "baseline-test-vp-trade-artifact", default = "")))
  candidate_artifact <- trimws(as.character(parse_arg_value(args, "candidate-test-vp-trade-artifact", default = "")))

  startup_timeout_ms <- trimws(as.character(parse_arg_value(args, "startup-timeout-ms", default = "120000")))
  stage_timeout_ms <- trimws(as.character(parse_arg_value(args, "stage-timeout-ms", default = "30000")))
  output_timeout_ms <- trimws(as.character(parse_arg_value(args, "output-timeout-ms", default = "30000")))
  full_idle_timeout_ms <- trimws(as.character(parse_arg_value(args, "full-idle-timeout-ms", default = "30000")))

  runtime_perf <- if (is_truthy(parse_arg_value(args, "runtime-perf", default = "true"), default = TRUE)) "true" else "false"
  perf_boundary_markers <- if (is_truthy(parse_arg_value(args, "perf-boundary-markers", default = "false"), default = FALSE)) "true" else "false"
  acceptance_manifest <- trimws(as.character(parse_arg_value(args, "acceptance-manifest", default = "")))
  manifest_clean_room <- is_truthy(parse_arg_value(args, "manifest-clean-room", default = "false"), default = FALSE)
  manifest_clean_room_dir <- trimws(as.character(parse_arg_value(args, "manifest-clean-room-dir", default = "")))

  min_runs <- trimws(as.character(parse_arg_value(args, "min-runs", default = "9")))
  startup_improvement_min <- trimws(as.character(parse_arg_value(args, "startup-improvement-min", default = "0.25")))
  single_action_improvement_min <- trimws(as.character(parse_arg_value(args, "single-action-improvement-min", default = "0.20")))
  max_mad_ratio <- trimws(as.character(parse_arg_value(args, "max-mad-ratio", default = "0.60")))
  bootstrap_reps <- trimws(as.character(parse_arg_value(args, "bootstrap-reps", default = "2000")))
  confidence <- trimws(as.character(parse_arg_value(args, "confidence", default = "0.95")))
  bootstrap_seed <- trimws(as.character(parse_arg_value(args, "bootstrap-seed", default = "1")))

  strict_manifest <- if (is_truthy(parse_arg_value(args, "strict-manifest", default = "true"), default = TRUE)) "true" else "false"
  acceptance_only <- if (is_truthy(parse_arg_value(args, "acceptance-only", default = "true"), default = TRUE)) "true" else "false"
  strict_context_validation <- is_truthy(parse_arg_value(args, "strict-context-validation", default = "true"), default = TRUE)
  strict_runtime_identity <- is_truthy(parse_arg_value(args, "strict-runtime-identity", default = "true"), default = TRUE)

  rscript_exe <- trimws(as.character(parse_arg_value(args, "rscript", default = Sys.getenv("VP_RSCRIPT", unset = "Rscript"))))
  if (!nzchar(rscript_exe)) rscript_exe <- "Rscript"

  repo_root <- resolve_repo_root(getwd())
  vp_clone_dir <- file.path(repo_root, "VP Clone")
  logs_dir <- file.path(vp_clone_dir, "Logs")
  dir.create(logs_dir, recursive = TRUE, showWarnings = FALSE)

  startup_script <- normalizePath(file.path(vp_clone_dir, "System", "Testing", "vp_perf_probe_startup.R"), winslash = "/", mustWork = TRUE)
  action_script <- normalizePath(file.path(vp_clone_dir, "System", "Testing", "vp_perf_probe_single_action_latency.R"), winslash = "/", mustWork = TRUE)
  decision_script <- normalizePath(file.path(vp_clone_dir, "System", "Testing", "vp_perf_acceptance_decision.R"), winslash = "/", mustWork = TRUE)

  pair_run_id <- paste0(label, "_", format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC"))

  resolved_acceptance_manifest <- acceptance_manifest
  if (isTRUE(manifest_clean_room)) {
    manifest_base_dir <- logs_dir
    if (nzchar(manifest_clean_room_dir)) {
      manifest_base_dir <- normalizePath(manifest_clean_room_dir, winslash = "/", mustWork = FALSE)
    } else if (nzchar(resolved_acceptance_manifest)) {
      manifest_base_dir <- dirname(normalizePath(resolved_acceptance_manifest, winslash = "/", mustWork = FALSE))
    }

    dir.create(manifest_base_dir, recursive = TRUE, showWarnings = FALSE)
    resolved_acceptance_manifest <- normalizePath(
      file.path(manifest_base_dir, paste0("vp_perf_acceptance_run_manifest_", pair_run_id, ".csv")),
      winslash = "/",
      mustWork = FALSE
    )

    resolved_manifest_jsonl <- sub("\\.csv$", ".jsonl", resolved_acceptance_manifest, ignore.case = TRUE)
    if (file.exists(resolved_acceptance_manifest)) file.remove(resolved_acceptance_manifest)
    if (file.exists(resolved_manifest_jsonl)) file.remove(resolved_manifest_jsonl)
  }

  cat("VP_PERF_ACCEPTANCE_PAIR_START\n")
  cat(sprintf("VP_PERF_ACCEPTANCE_PAIR_LABEL=%s\n", label))
  cat(sprintf("VP_PERF_ACCEPTANCE_PAIR_RUN_ID=%s\n", pair_run_id))
  cat(sprintf("VP_PERF_ACCEPTANCE_PAIR_ITERATIONS=%d\n", iterations))
  cat(sprintf("VP_PERF_ACCEPTANCE_PAIR_BASELINE_TAG=%s\n", baseline_tag))
  cat(sprintf("VP_PERF_ACCEPTANCE_PAIR_CANDIDATE_TAG=%s\n", candidate_tag))
  cat(sprintf("VP_PERF_ACCEPTANCE_PAIR_PERF_BOUNDARY_MARKERS=%s\n", toupper(perf_boundary_markers)))
  cat(sprintf("VP_PERF_ACCEPTANCE_PAIR_MANIFEST_CLEAN_ROOM=%s\n", if (isTRUE(manifest_clean_room)) "TRUE" else "FALSE"))
  cat(sprintf("VP_PERF_ACCEPTANCE_PAIR_ACCEPTANCE_MANIFEST=%s\n", resolved_acceptance_manifest))
  cat(sprintf("VP_PERF_ACCEPTANCE_PAIR_STRICT_CONTEXT_VALIDATION=%s\n", if (isTRUE(strict_context_validation)) "TRUE" else "FALSE"))
  cat(sprintf("VP_PERF_ACCEPTANCE_PAIR_STRICT_RUNTIME_IDENTITY=%s\n", if (isTRUE(strict_runtime_identity)) "TRUE" else "FALSE"))
  cat(sprintf("VP_PERF_ACCEPTANCE_PAIR_BASELINE_COMPARISON_PLOT_CACHE_OFF=%s\n", toupper(baseline_comparison_plot_cache_off)))
  cat(sprintf("VP_PERF_ACCEPTANCE_PAIR_CANDIDATE_COMPARISON_PLOT_CACHE_OFF=%s\n", toupper(candidate_comparison_plot_cache_off)))

  for (index in seq_len(iterations)) {
    iter_token <- sprintf("iter%02d", index)

    baseline_startup_label <- build_probe_label(label, baseline_tag, paste0("startup_", iter_token))
    candidate_startup_label <- build_probe_label(label, candidate_tag, paste0("startup_", iter_token))
    baseline_action_label <- build_probe_label(label, baseline_tag, paste0("single_action_", iter_token))
    candidate_action_label <- build_probe_label(label, candidate_tag, paste0("single_action_", iter_token))

    run_rscript(
      rscript_exe = rscript_exe,
      script_path = startup_script,
      args_named = c(
        label = baseline_startup_label,
        `cache-state` = baseline_cache_state,
        `runtime-perf` = runtime_perf,
        `perf-boundary-markers` = perf_boundary_markers,
        `target-tab` = startup_target_tab,
        `acceptance-mode` = "true",
        `run-id` = paste(pair_run_id, baseline_tag, iter_token, "startup", sep = "__"),
        `session-id` = paste(pair_run_id, baseline_tag, sep = "__"),
        `startup-timeout-ms` = startup_timeout_ms,
        `stage-timeout-ms` = stage_timeout_ms,
        `output-timeout-ms` = output_timeout_ms,
        `acceptance-manifest` = resolved_acceptance_manifest,
        `test-vp-trade-artifact` = baseline_artifact,
        `comparison-plot-cache-off` = baseline_comparison_plot_cache_off
      )
    )

    run_rscript(
      rscript_exe = rscript_exe,
      script_path = startup_script,
      args_named = c(
        label = candidate_startup_label,
        `cache-state` = candidate_cache_state,
        `runtime-perf` = runtime_perf,
        `perf-boundary-markers` = perf_boundary_markers,
        `target-tab` = startup_target_tab,
        `acceptance-mode` = "true",
        `run-id` = paste(pair_run_id, candidate_tag, iter_token, "startup", sep = "__"),
        `session-id` = paste(pair_run_id, candidate_tag, sep = "__"),
        `startup-timeout-ms` = startup_timeout_ms,
        `stage-timeout-ms` = stage_timeout_ms,
        `output-timeout-ms` = output_timeout_ms,
        `acceptance-manifest` = resolved_acceptance_manifest,
        `test-vp-trade-artifact` = candidate_artifact,
        `comparison-plot-cache-off` = candidate_comparison_plot_cache_off
      )
    )

    run_rscript(
      rscript_exe = rscript_exe,
      script_path = action_script,
      args_named = c(
        label = baseline_action_label,
        `scenario` = baseline_scenario,
        `cache-state` = baseline_cache_state,
        `runtime-perf` = runtime_perf,
        `perf-boundary-markers` = perf_boundary_markers,
        `acceptance-mode` = "true",
        `run-id` = paste(pair_run_id, baseline_tag, iter_token, "single_action", sep = "__"),
        `session-id` = paste(pair_run_id, baseline_tag, sep = "__"),
        `startup-timeout-ms` = startup_timeout_ms,
        `stage-timeout-ms` = stage_timeout_ms,
        `output-timeout-ms` = output_timeout_ms,
        `full-idle-timeout-ms` = full_idle_timeout_ms,
        `acceptance-manifest` = resolved_acceptance_manifest,
        `test-vp-trade-artifact` = baseline_artifact,
        `comparison-plot-cache-off` = baseline_comparison_plot_cache_off
      )
    )

    run_rscript(
      rscript_exe = rscript_exe,
      script_path = action_script,
      args_named = c(
        label = candidate_action_label,
        `scenario` = candidate_scenario,
        `cache-state` = candidate_cache_state,
        `runtime-perf` = runtime_perf,
        `perf-boundary-markers` = perf_boundary_markers,
        `acceptance-mode` = "true",
        `run-id` = paste(pair_run_id, candidate_tag, iter_token, "single_action", sep = "__"),
        `session-id` = paste(pair_run_id, candidate_tag, sep = "__"),
        `startup-timeout-ms` = startup_timeout_ms,
        `stage-timeout-ms` = stage_timeout_ms,
        `output-timeout-ms` = output_timeout_ms,
        `full-idle-timeout-ms` = full_idle_timeout_ms,
        `acceptance-manifest` = resolved_acceptance_manifest,
        `test-vp-trade-artifact` = candidate_artifact,
        `comparison-plot-cache-off` = candidate_comparison_plot_cache_off
      )
    )
  }

  expected_context_rows <- build_expected_context_rows(
    pair_run_id = pair_run_id,
    iterations = iterations,
    label = label,
    baseline_tag = baseline_tag,
    candidate_tag = candidate_tag,
    baseline_cache_state = baseline_cache_state,
    candidate_cache_state = candidate_cache_state,
    baseline_comparison_plot_cache_off = baseline_comparison_plot_cache_off,
    candidate_comparison_plot_cache_off = candidate_comparison_plot_cache_off,
    baseline_scenario = baseline_scenario,
    candidate_scenario = candidate_scenario,
    runtime_perf = runtime_perf,
    perf_boundary_markers = perf_boundary_markers
  )

  preflight <- run_phase3_preflight(
    logs_dir = logs_dir,
    acceptance_manifest_path = resolved_acceptance_manifest,
    expected_context_rows = expected_context_rows,
    pair_run_id = pair_run_id,
    strict_context_validation = strict_context_validation,
    strict_runtime_identity = strict_runtime_identity,
    baseline_tag = baseline_tag,
    candidate_tag = candidate_tag
  )

  context_detail <- preflight$context$detail
  identity_detail <- preflight$identity$detail

  context_fail_count <- if (is.data.frame(context_detail) && nrow(context_detail) > 0L) {
    sum(!as.logical(context_detail$validation_ok), na.rm = TRUE)
  } else {
    0L
  }
  identity_fail_count <- if (is.data.frame(identity_detail) && nrow(identity_detail) > 0L) {
    sum(!as.logical(identity_detail$validation_ok), na.rm = TRUE)
  } else {
    0L
  }

  cat(sprintf("VP_PERF_ACCEPTANCE_PAIR_PREFLIGHT_MANIFEST_PATH=%s\n", preflight$telemetry$manifest_path %||% ""))
  cat(sprintf("VP_PERF_ACCEPTANCE_PAIR_PREFLIGHT_MANIFEST_ROWS=%d\n", as.integer(preflight$telemetry$manifest_rows_total %||% 0L)))
  cat(sprintf("VP_PERF_ACCEPTANCE_PAIR_PREFLIGHT_EXPECTED_ROWS=%d\n", as.integer(preflight$telemetry$expected_rows_total %||% 0L)))
  cat(sprintf("VP_PERF_ACCEPTANCE_PAIR_PREFLIGHT_CONTEXT_STATUS=%s\n", if (isTRUE(preflight$telemetry$context_ok)) "PASS" else "FAIL"))
  cat(sprintf("VP_PERF_ACCEPTANCE_PAIR_PREFLIGHT_CONTEXT_FAIL_COUNT=%d\n", as.integer(context_fail_count)))
  cat(sprintf("VP_PERF_ACCEPTANCE_PAIR_PREFLIGHT_IDENTITY_STATUS=%s\n", if (isTRUE(preflight$telemetry$identity_ok)) "PASS" else "FAIL"))
  cat(sprintf("VP_PERF_ACCEPTANCE_PAIR_PREFLIGHT_IDENTITY_FAIL_COUNT=%d\n", as.integer(identity_fail_count)))

  if (length(preflight$context$errors) > 0L) {
    cat(sprintf("VP_PERF_ACCEPTANCE_PAIR_PREFLIGHT_CONTEXT_ERRORS=%s\n", paste(unique(preflight$context$errors), collapse = " || ")))
  }
  if (length(preflight$identity$errors) > 0L) {
    cat(sprintf("VP_PERF_ACCEPTANCE_PAIR_PREFLIGHT_IDENTITY_ERRORS=%s\n", paste(unique(preflight$identity$errors), collapse = " || ")))
  }

  if (!isTRUE(preflight$ok)) {
    stop("Phase 3 preflight/context or runtime-log identity validation failed before decision stage.", call. = FALSE)
  }

  decision_label <- paste0(label, "__decision")
  baseline_session_id <- paste(pair_run_id, baseline_tag, sep = "__")
  candidate_session_id <- paste(pair_run_id, candidate_tag, sep = "__")
  run_rscript(
    rscript_exe = rscript_exe,
    script_path = decision_script,
    args_named = c(
      label = decision_label,
      `baseline-selector` = paste0("__", baseline_tag, "__"),
      `candidate-selector` = paste0("__", candidate_tag, "__"),
      `session-id` = paste(c(baseline_session_id, candidate_session_id), collapse = "|"),
      `acceptance-manifest` = resolved_acceptance_manifest,
      `acceptance-only` = acceptance_only,
      `strict-manifest` = strict_manifest,
      `min-runs` = min_runs,
      `startup-improvement-min` = startup_improvement_min,
      `single-action-improvement-min` = single_action_improvement_min,
      `max-mad-ratio` = max_mad_ratio,
      `bootstrap-reps` = bootstrap_reps,
      `confidence` = confidence,
      `bootstrap-seed` = bootstrap_seed
    )
  )

  cat(sprintf("VP_PERF_ACCEPTANCE_PAIR_DECISION_LABEL=%s\n", decision_label))
  cat("VP_PERF_ACCEPTANCE_PAIR_COMPLETE\n")
}

main()