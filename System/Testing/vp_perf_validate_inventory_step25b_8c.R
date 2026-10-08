`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0L) y else x
}

parse_arg_value <- function(args, key, default = NULL) {
  prefix <- paste0("--", key, "=")
  hits <- args[startsWith(args, prefix)]
  if (length(hits) == 0L) return(default)
  sub(prefix, "", hits[[length(hits)]], fixed = TRUE)
}

normalize_bool <- function(x) {
  normalized <- tolower(trimws(as.character(x)))
  normalized %in% c("true", "t", "1", "yes", "y")
}

normalize_text <- function(x) {
  out <- trimws(as.character(x))
  out[is.na(out)] <- ""
  out
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

  stop("Could not resolve repository root for Step 25B inventory validation.", call. = FALSE)
}

collapse_reasons <- function(reason_matrix) {
  apply(reason_matrix, 1L, function(row) {
    reasons <- names(row)[as.logical(row)]
    if (length(reasons) == 0L) "ok" else paste(reasons, collapse = "|")
  })
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

  inventory_arg <- trimws(as.character(parse_arg_value(args, "inventory", default = "")))
  if (!nzchar(inventory_arg)) {
    stop("Missing required --inventory argument.", call. = FALSE)
  }

  inventory_path <- normalizePath(file.path(vp_clone_dir, inventory_arg), winslash = "/", mustWork = FALSE)
  if (!file.exists(inventory_path)) {
    inventory_path <- normalizePath(inventory_arg, winslash = "/", mustWork = FALSE)
  }
  if (!file.exists(inventory_path)) {
    stop(sprintf("Inventory file not found: %s", inventory_arg), call. = FALSE)
  }

  label <- trimws(as.character(parse_arg_value(args, "label", default = "step25b_tranche8c_inventory_validation")))

  inventory <- utils::read.csv(inventory_path, stringsAsFactors = FALSE, check.names = FALSE)
  if (!is.data.frame(inventory) || nrow(inventory) == 0L) {
    stop("Inventory file is empty.", call. = FALSE)
  }

  required_cols <- c(
    "lane", "pair_run_label", "manifest_path", "probe_type", "run_id", "session_id", "label", "scenario", "cache_state", "role",
    "runtime_log_path", "output_csv_path", "status", "base_status",
    "decision_summary_csv", "decision_details_csv", "decision_file_csv",
    "manifest_exists", "runtime_log_exists", "output_csv_exists",
    "decision_summary_exists", "decision_details_exists", "decision_file_exists",
    "runtime_log_nonzero", "output_csv_nonzero", "label_consistent_with_lane",
    "comparison_validity_app_ref", "comparison_validity_probe", "comparison_validity_runtime_enabled",
    "comparison_validity_acceptance_mode", "comparison_validity_cache_state", "comparison_validity_scenario",
    "integrity_status", "integrity_reason"
  )

  missing_cols <- setdiff(required_cols, names(inventory))
  if (length(missing_cols) > 0L) {
    stop(sprintf("Inventory missing required columns: %s", paste(missing_cols, collapse = ", ")), call. = FALSE)
  }

  text_app_ref <- normalize_text(inventory$comparison_validity_app_ref)
  text_probe <- normalize_text(inventory$comparison_validity_probe)
  text_lane <- normalize_text(inventory$lane)
  text_cache <- normalize_text(inventory$comparison_validity_cache_state)
  text_scenario <- normalize_text(inventory$comparison_validity_scenario)
  text_role <- normalize_text(inventory$role)
  text_integrity <- tolower(normalize_text(inventory$integrity_status))

  bool_manifest_exists <- normalize_bool(inventory$manifest_exists)
  bool_runtime_exists <- normalize_bool(inventory$runtime_log_exists)
  bool_output_exists <- normalize_bool(inventory$output_csv_exists)
  bool_decision_summary_exists <- normalize_bool(inventory$decision_summary_exists)
  bool_decision_details_exists <- normalize_bool(inventory$decision_details_exists)
  bool_decision_file_exists <- normalize_bool(inventory$decision_file_exists)
  bool_runtime_nonzero <- normalize_bool(inventory$runtime_log_nonzero)
  bool_output_nonzero <- normalize_bool(inventory$output_csv_nonzero)
  bool_lane_label_consistent <- normalize_bool(inventory$label_consistent_with_lane)
  bool_runtime_enabled <- normalize_bool(inventory$comparison_validity_runtime_enabled)
  bool_acceptance_mode <- normalize_bool(inventory$comparison_validity_acceptance_mode)

  reason_matrix <- cbind(
    app_ref_missing = !nzchar(text_app_ref),
    probe_mismatch = text_probe != inventory$probe_type,
    cache_state_mismatch = text_cache != text_lane,
    scenario_missing = !nzchar(text_scenario),
    role_invalid = !(text_role %in% c("baseline", "candidate")),
    runtime_enabled_false = !bool_runtime_enabled,
    acceptance_mode_false = !bool_acceptance_mode,
    manifest_missing = !bool_manifest_exists,
    runtime_log_missing = !bool_runtime_exists,
    output_csv_missing = !bool_output_exists,
    decision_summary_missing = !bool_decision_summary_exists,
    decision_details_missing = !bool_decision_details_exists,
    decision_file_missing = !bool_decision_file_exists,
    runtime_log_zero = !bool_runtime_nonzero,
    output_csv_zero = !bool_output_nonzero,
    label_lane_inconsistent = !bool_lane_label_consistent,
    integrity_not_ok = text_integrity != "ok"
  )

  reasons <- collapse_reasons(reason_matrix)
  validation_ok <- reasons == "ok"

  detail <- data.frame(
    lane = inventory$lane,
    pair_run_label = inventory$pair_run_label,
    probe_type = inventory$probe_type,
    role = inventory$role,
    run_id = inventory$run_id,
    runtime_log_path = inventory$runtime_log_path,
    integrity_status = inventory$integrity_status,
    validation_status = ifelse(validation_ok, "ok", "quarantine"),
    validation_reason = reasons,
    stringsAsFactors = FALSE
  )

  lane_counts <- aggregate(list(row_count = detail$run_id), list(lane = detail$lane), length)
  probe_counts <- aggregate(list(row_count = detail$run_id), list(probe_type = detail$probe_type), length)
  role_counts <- aggregate(list(row_count = detail$run_id), list(role = detail$role), length)
  lane_probe_role_counts <- aggregate(list(row_count = detail$run_id), list(lane = detail$lane, probe_type = detail$probe_type, role = detail$role), length)

  reason_counts <- as.data.frame(table(detail$validation_reason), stringsAsFactors = FALSE)
  names(reason_counts) <- c("validation_reason", "row_count")
  reason_counts <- reason_counts[order(-reason_counts$row_count, reason_counts$validation_reason), , drop = FALSE]

  summary <- data.frame(
    metric = c(
      "total_rows",
      "ok_rows",
      "quarantine_rows",
      "integrity_ok_rows",
      "integrity_quarantine_rows",
      "comparison_validity_complete_rows"
    ),
    value = c(
      nrow(detail),
      sum(detail$validation_status == "ok"),
      sum(detail$validation_status == "quarantine"),
      sum(text_integrity == "ok"),
      sum(text_integrity == "quarantine"),
      sum(nzchar(text_app_ref) & bool_runtime_enabled & bool_acceptance_mode & (text_cache == text_lane) & nzchar(text_scenario))
    ),
    stringsAsFactors = FALSE
  )

  timestamp_token <- format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC")
  prefix <- file.path(logs_dir, paste0("vp_perf_acceptance_inventory_validation_", label, "_", timestamp_token))

  detail_path <- paste0(prefix, "_detail.csv")
  summary_path <- paste0(prefix, "_summary.csv")
  reason_path <- paste0(prefix, "_reasons.csv")
  lane_path <- paste0(prefix, "_lane_counts.csv")
  probe_path <- paste0(prefix, "_probe_counts.csv")
  role_path <- paste0(prefix, "_role_counts.csv")
  lane_probe_role_path <- paste0(prefix, "_lane_probe_role_counts.csv")
  json_path <- paste0(prefix, ".json")

  utils::write.csv(detail, detail_path, row.names = FALSE, na = "")
  utils::write.csv(summary, summary_path, row.names = FALSE, na = "")
  utils::write.csv(reason_counts, reason_path, row.names = FALSE, na = "")
  utils::write.csv(lane_counts, lane_path, row.names = FALSE, na = "")
  utils::write.csv(probe_counts, probe_path, row.names = FALSE, na = "")
  utils::write.csv(role_counts, role_path, row.names = FALSE, na = "")
  utils::write.csv(lane_probe_role_counts, lane_probe_role_path, row.names = FALSE, na = "")

  json_written <- write_json(
    list(
      label = label,
      inventory_path = inventory_path,
      total_rows = nrow(detail),
      ok_rows = sum(detail$validation_status == "ok"),
      quarantine_rows = sum(detail$validation_status == "quarantine"),
      detail_csv = normalizePath(detail_path, winslash = "/", mustWork = FALSE),
      summary_csv = normalizePath(summary_path, winslash = "/", mustWork = FALSE),
      reasons_csv = normalizePath(reason_path, winslash = "/", mustWork = FALSE),
      lane_counts_csv = normalizePath(lane_path, winslash = "/", mustWork = FALSE),
      probe_counts_csv = normalizePath(probe_path, winslash = "/", mustWork = FALSE),
      role_counts_csv = normalizePath(role_path, winslash = "/", mustWork = FALSE),
      lane_probe_role_counts_csv = normalizePath(lane_probe_role_path, winslash = "/", mustWork = FALSE)
    ),
    json_path
  )

  cat("VP_PERF_8C_STEP25B_START\n")
  cat(sprintf("VP_PERF_8C_STEP25B_LABEL=%s\n", label))
  cat(sprintf("VP_PERF_8C_STEP25B_INVENTORY=%s\n", inventory_path))
  cat(sprintf("VP_PERF_8C_STEP25B_TOTAL_ROWS=%d\n", nrow(detail)))
  cat(sprintf("VP_PERF_8C_STEP25B_OK_ROWS=%d\n", sum(detail$validation_status == "ok")))
  cat(sprintf("VP_PERF_8C_STEP25B_QUARANTINE_ROWS=%d\n", sum(detail$validation_status == "quarantine")))
  cat(sprintf("VP_PERF_8C_STEP25B_DETAIL_CSV=%s\n", normalizePath(detail_path, winslash = "/", mustWork = FALSE)))
  cat(sprintf("VP_PERF_8C_STEP25B_SUMMARY_CSV=%s\n", normalizePath(summary_path, winslash = "/", mustWork = FALSE)))
  cat(sprintf("VP_PERF_8C_STEP25B_REASONS_CSV=%s\n", normalizePath(reason_path, winslash = "/", mustWork = FALSE)))
  cat(sprintf("VP_PERF_8C_STEP25B_LANE_COUNTS_CSV=%s\n", normalizePath(lane_path, winslash = "/", mustWork = FALSE)))
  cat(sprintf("VP_PERF_8C_STEP25B_PROBE_COUNTS_CSV=%s\n", normalizePath(probe_path, winslash = "/", mustWork = FALSE)))
  cat(sprintf("VP_PERF_8C_STEP25B_ROLE_COUNTS_CSV=%s\n", normalizePath(role_path, winslash = "/", mustWork = FALSE)))
  cat(sprintf("VP_PERF_8C_STEP25B_LANE_PROBE_ROLE_COUNTS_CSV=%s\n", normalizePath(lane_probe_role_path, winslash = "/", mustWork = FALSE)))
  if (json_written && file.exists(json_path)) {
    cat(sprintf("VP_PERF_8C_STEP25B_JSON=%s\n", normalizePath(json_path, winslash = "/", mustWork = FALSE)))
  }
  cat("VP_PERF_8C_STEP25B_COMPLETE\n")
}

main()
