`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0L) y else x
}

parse_arg_value <- function(args, key, default = NULL) {
  prefix <- paste0("--", key, "=")
  hits <- args[startsWith(args, prefix)]
  if (length(hits) == 0L) return(default)
  sub(prefix, "", hits[[length(hits)]], fixed = TRUE)
}

is_truthy <- function(x, default = FALSE) {
  if (is.null(x) || length(x) == 0L || is.na(x)) return(default)
  normalized <- tolower(trimws(as.character(x[[1L]])))
  if (!nzchar(normalized)) return(default)
  normalized %in% c("1", "true", "t", "yes", "y", "on")
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

  stop("Could not resolve repository root for acceptance manifest inventory helper.", call. = FALSE)
}

resolve_path <- function(path, vp_clone_dir) {
  path <- trimws(as.character(path %||% ""))
  if (!nzchar(path)) return("")
  if (file.exists(path)) return(normalizePath(path, winslash = "/", mustWork = FALSE))
  candidate <- file.path(vp_clone_dir, path)
  if (file.exists(candidate)) return(normalizePath(candidate, winslash = "/", mustWork = FALSE))
  normalizePath(path, winslash = "/", mustWork = FALSE)
}

path_exists <- function(path) {
  nzchar(path) && file.exists(path)
}

path_nonzero <- function(path) {
  if (!path_exists(path)) return(FALSE)
  isTRUE(file.info(path)$size > 0)
}

first_existing_col <- function(df, cols, default = "") {
  for (col in cols) {
    if (col %in% names(df)) return(df[[col]])
  }
  rep(default, nrow(df))
}

infer_role <- function(label, run_id, session_id) {
  text <- paste(label, run_id, session_id, sep = " ")
  if (grepl("__baseline__|baseline", text, ignore.case = TRUE)) return("baseline")
  if (grepl("__candidate__|candidate", text, ignore.case = TRUE)) return("candidate")
  ""
}

collapse_reasons <- function(reasons) {
  reasons <- reasons[nzchar(reasons)]
  if (length(reasons) == 0L) "ok" else paste(unique(reasons), collapse = "|")
}

build_inventory_rows <- function(index_row, vp_clone_dir, app_ref, include_startup) {
  manifest_path <- resolve_path(index_row$clean_room_manifest_csv %||% index_row$manifest_path %||% "", vp_clone_dir)
  if (!file.exists(manifest_path)) {
    stop(sprintf("Manifest file not found for pair_run_label=%s: %s", index_row$pair_run_label %||% "", manifest_path), call. = FALSE)
  }

  manifest <- utils::read.csv(manifest_path, stringsAsFactors = FALSE, check.names = FALSE)
  if (!is.data.frame(manifest) || nrow(manifest) == 0L) {
    stop(sprintf("Manifest has no rows: %s", manifest_path), call. = FALSE)
  }

  if (!include_startup) {
    manifest <- manifest[as.character(manifest$probe_type %||% "") == "single_action", , drop = FALSE]
  }

  if (nrow(manifest) == 0L) return(data.frame())

  decision_summary <- resolve_path(index_row$decision_summary_csv %||% "", vp_clone_dir)
  decision_details <- resolve_path(index_row$decision_details_csv %||% "", vp_clone_dir)
  decision_file <- resolve_path(index_row$decision_file_csv %||% "", vp_clone_dir)

  runtime_paths <- vapply(as.character(manifest$runtime_log_path %||% ""), resolve_path, character(1), vp_clone_dir = vp_clone_dir)
  output_paths <- vapply(as.character(manifest$output_csv_path %||% ""), resolve_path, character(1), vp_clone_dir = vp_clone_dir)

  roles <- mapply(
    infer_role,
    label = as.character(manifest$label %||% ""),
    run_id = as.character(manifest$run_id %||% ""),
    session_id = as.character(manifest$session_id %||% ""),
    USE.NAMES = FALSE
  )

  runtime_exists <- vapply(runtime_paths, path_exists, logical(1))
  output_exists <- vapply(output_paths, path_exists, logical(1))
  runtime_nonzero <- vapply(runtime_paths, path_nonzero, logical(1))
  output_nonzero <- vapply(output_paths, path_nonzero, logical(1))
  decision_summary_exists <- path_exists(decision_summary)
  decision_details_exists <- path_exists(decision_details)
  decision_file_exists <- path_exists(decision_file)

  integrity_reasons <- vapply(seq_len(nrow(manifest)), function(i) {
    collapse_reasons(c(
      if (!file.exists(manifest_path)) "manifest_missing" else "",
      if (!runtime_exists[[i]]) "runtime_log_missing" else "",
      if (!output_exists[[i]]) "output_csv_missing" else "",
      if (!decision_summary_exists) "decision_summary_missing" else "",
      if (!decision_details_exists) "decision_details_missing" else "",
      if (!decision_file_exists) "decision_file_missing" else "",
      if (runtime_exists[[i]] && !runtime_nonzero[[i]]) "runtime_log_zero" else "",
      if (output_exists[[i]] && !output_nonzero[[i]]) "output_csv_zero" else "",
      if (!roles[[i]] %in% c("baseline", "candidate")) "role_unresolved" else ""
    ))
  }, character(1))

  scenario <- as.character(manifest$scenario %||% "")
  cache_state <- as.character(manifest$cache_state %||% "")
  lane <- as.character(index_row$lane %||% "")
  if (!nzchar(lane)) {
    unique_cache_states <- unique(cache_state[nzchar(cache_state)])
    lane <- if (length(unique_cache_states) == 1L) unique_cache_states[[1L]] else ""
  }
  marker_mode <- as.character(index_row$marker_mode %||% "")
  marker_lane <- as.character(index_row$marker_lane %||% marker_mode %||% "")
  runtime_enabled <- first_existing_col(manifest, c("runtime_enabled", "runtime_perf_enabled"), default = "")
  acceptance_mode <- first_existing_col(manifest, c("acceptance_mode"), default = "")

  data.frame(
    lane = lane,
    pair_run_label = as.character(index_row$pair_run_label %||% ""),
    marker_mode = marker_mode,
    marker_lane = marker_lane,
    manifest_path = manifest_path,
    probe_type = as.character(manifest$probe_type %||% ""),
    run_id = as.character(manifest$run_id %||% ""),
    session_id = as.character(manifest$session_id %||% ""),
    label = as.character(manifest$label %||% ""),
    scenario = scenario,
    cache_state = cache_state,
    role = roles,
    runtime_log_path = runtime_paths,
    output_csv_path = output_paths,
    status = as.character(manifest$status %||% ""),
    base_status = as.character(manifest$base_status %||% ""),
    decision_summary_csv = decision_summary,
    decision_details_csv = decision_details,
    decision_file_csv = decision_file,
    provider_mode = as.character(manifest$provider_mode %||% ""),
    artifact_signature = as.character(manifest$artifact_signature %||% ""),
    artifact_path = as.character(manifest$artifact_path %||% ""),
    test_vp_trade_artifact = as.character(manifest$test_vp_trade_artifact %||% ""),
    test_vp_trade_artifact_path = as.character(manifest$test_vp_trade_artifact_path %||% ""),
    target_tab = as.character(manifest$target_tab %||% ""),
    perf_boundary_markers_enabled = as.character(manifest$perf_boundary_markers_enabled %||% ""),
    manifest_exists = file.exists(manifest_path),
    runtime_log_exists = runtime_exists,
    output_csv_exists = output_exists,
    decision_summary_exists = decision_summary_exists,
    decision_details_exists = decision_details_exists,
    decision_file_exists = decision_file_exists,
    runtime_log_nonzero = runtime_nonzero,
    output_csv_nonzero = output_nonzero,
    label_consistent_with_lane = nzchar(as.character(index_row$pair_run_label %||% "")) & grepl(as.character(index_row$pair_run_label %||% ""), as.character(manifest$label %||% ""), fixed = TRUE),
    comparison_validity_app_ref = app_ref,
    comparison_validity_probe = as.character(manifest$probe_type %||% ""),
    comparison_validity_runtime_enabled = runtime_enabled,
    comparison_validity_acceptance_mode = acceptance_mode,
    comparison_validity_cache_state = lane,
    comparison_validity_scenario = scenario,
    integrity_status = ifelse(integrity_reasons == "ok", "ok", "quarantine"),
    integrity_reason = integrity_reasons,
    stringsAsFactors = FALSE
  )
}

write_json <- function(payload, path) {
  if (!requireNamespace("jsonlite", quietly = TRUE)) return(FALSE)
  writeLines(jsonlite::toJSON(payload, pretty = TRUE, auto_unbox = TRUE), path)
  TRUE
}

main <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  repo_root <- resolve_repo_root(getwd())
  vp_clone_dir <- file.path(repo_root, "VP Clone")
  logs_dir <- file.path(vp_clone_dir, "Logs")
  dir.create(logs_dir, recursive = TRUE, showWarnings = FALSE)

  index_arg <- trimws(as.character(parse_arg_value(args, "index", default = "")))
  if (!nzchar(index_arg)) {
    stop("Missing required --index argument.", call. = FALSE)
  }

  label <- trimws(as.character(parse_arg_value(args, "label", default = "acceptance_inventory")))
  app_ref <- trimws(as.character(parse_arg_value(args, "app-ref", default = "working_tree")))
  include_startup <- is_truthy(parse_arg_value(args, "include-startup", default = "true"), default = TRUE)

  index_path <- resolve_path(index_arg, vp_clone_dir)
  if (!file.exists(index_path)) {
    stop(sprintf("Index file not found: %s", index_arg), call. = FALSE)
  }

  index <- utils::read.csv(index_path, stringsAsFactors = FALSE, check.names = FALSE)
  if (!is.data.frame(index) || nrow(index) == 0L) {
    stop("Index file has no rows.", call. = FALSE)
  }

  required_cols <- c("lane", "pair_run_label", "clean_room_manifest_csv", "decision_summary_csv", "decision_details_csv", "decision_file_csv")
  missing_cols <- setdiff(required_cols, names(index))
  if (length(missing_cols) > 0L) {
    stop(sprintf("Index missing required columns: %s", paste(missing_cols, collapse = ", ")), call. = FALSE)
  }

  row_list <- lapply(seq_len(nrow(index)), function(i) build_inventory_rows(index[i, , drop = FALSE], vp_clone_dir, app_ref, include_startup))
  inventory <- do.call(rbind, row_list)
  if (!is.data.frame(inventory) || nrow(inventory) == 0L) {
    stop("No inventory rows were produced.", call. = FALSE)
  }

  timestamp_token <- format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC")
  prefix <- file.path(logs_dir, paste0("vp_perf_acceptance_inventory_", label, "_", timestamp_token))
  csv_path <- paste0(prefix, ".csv")
  json_path <- paste0(prefix, ".json")

  utils::write.csv(inventory, csv_path, row.names = FALSE, na = "")
  json_written <- write_json(
    list(
      label = label,
      index_path = normalizePath(index_path, winslash = "/", mustWork = FALSE),
      inventory_csv = normalizePath(csv_path, winslash = "/", mustWork = FALSE),
      total_rows = nrow(inventory),
      ok_rows = sum(inventory$integrity_status == "ok"),
      quarantine_rows = sum(inventory$integrity_status == "quarantine"),
      include_startup = include_startup,
      app_ref = app_ref
    ),
    json_path
  )

  cat("VP_PERF_ACCEPTANCE_MANIFEST_TO_INVENTORY_START\n")
  cat(sprintf("VP_PERF_ACCEPTANCE_MANIFEST_TO_INVENTORY_LABEL=%s\n", label))
  cat(sprintf("VP_PERF_ACCEPTANCE_MANIFEST_TO_INVENTORY_INDEX=%s\n", normalizePath(index_path, winslash = "/", mustWork = FALSE)))
  cat(sprintf("VP_PERF_ACCEPTANCE_MANIFEST_TO_INVENTORY_ROWS=%d\n", nrow(inventory)))
  cat(sprintf("VP_PERF_ACCEPTANCE_MANIFEST_TO_INVENTORY_OK_ROWS=%d\n", sum(inventory$integrity_status == "ok")))
  cat(sprintf("VP_PERF_ACCEPTANCE_MANIFEST_TO_INVENTORY_QUARANTINE_ROWS=%d\n", sum(inventory$integrity_status == "quarantine")))
  cat(sprintf("VP_PERF_ACCEPTANCE_MANIFEST_TO_INVENTORY_CSV=%s\n", normalizePath(csv_path, winslash = "/", mustWork = FALSE)))
  if (json_written && file.exists(json_path)) {
    cat(sprintf("VP_PERF_ACCEPTANCE_MANIFEST_TO_INVENTORY_JSON=%s\n", normalizePath(json_path, winslash = "/", mustWork = FALSE)))
  }
  cat("VP_PERF_ACCEPTANCE_MANIFEST_TO_INVENTORY_COMPLETE\n")
}

main()