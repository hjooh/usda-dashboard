`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0L) y else x
}

parse_arg_value <- function(args, key, default = NULL) {
  prefix <- paste0("--", key, "=")
  hits <- args[startsWith(args, prefix)]
  if (length(hits) == 0L) return(default)
  sub(prefix, "", hits[[length(hits)]], fixed = TRUE)
}

resolve_vp_clone_dir <- function(start_dir = getwd()) {
  start_dir <- normalizePath(start_dir, winslash = "/", mustWork = FALSE)
  candidates <- vapply(0:8, function(level) {
    normalizePath(do.call(file.path, as.list(c(start_dir, rep("..", level)))), winslash = "/", mustWork = FALSE)
  }, character(1))

  for (candidate in unique(candidates)) {
    if (file.exists(file.path(candidate, ".vp_clone_root"))) {
      return(candidate)
    }
    nested_candidate <- file.path(candidate, "VP Clone")
    if (file.exists(file.path(nested_candidate, ".vp_clone_root"))) {
      return(normalizePath(nested_candidate, winslash = "/", mustWork = FALSE))
    }
  }

  stop("Could not resolve VP Clone root for rollup ablation prep.", call. = FALSE)
}

normalize_path <- function(path) {
  normalizePath(path, winslash = "/", mustWork = FALSE)
}

file_signature_row <- function(path, label) {
  info <- if (file.exists(path)) file.info(path) else NULL
  data.frame(
    label = label,
    path = normalize_path(path),
    exists = file.exists(path),
    size_bytes = if (!is.null(info)) as.numeric(info$size) else NA_real_,
    mtime_utc = if (!is.null(info)) format(as.POSIXct(info$mtime, tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC") else NA_character_,
    stringsAsFactors = FALSE
  )
}

safe_write_rds <- function(object, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  tmp_path <- tempfile(pattern = paste0(basename(path), "_"), tmpdir = dirname(path), fileext = ".tmp")
  on.exit(if (file.exists(tmp_path)) unlink(tmp_path), add = TRUE)
  saveRDS(object, tmp_path)
  if (!file.rename(tmp_path, path)) {
    if (!file.copy(tmp_path, path, overwrite = TRUE)) {
      stop(sprintf("Failed to move temporary RDS into place: %s", path), call. = FALSE)
    }
    unlink(tmp_path)
  }
  invisible(path)
}

required_rollup_fields <- function() {
  c(
    "vp_rollup_level", "vp_rollup_path", "vp_is_rollup", "vp_volume_family_mixed",
    "vp_mixed_source_replacement", "vp_rollup_schema_version"
  )
}

validate_rollup_contract_like_startup <- function(data) {
  required_cols <- unique(c(
    required_rollup_fields(),
    c("Group", "Subgroup", "MarketSegment", "commodity", "Trade", "unit_value", "unit_value_unit", "ytd_unit_value", "ytd_unit_value_unit")
  ))
  missing_cols <- setdiff(required_cols, names(data))
  if (length(missing_cols) > 0L) {
    stop(sprintf("missing required rollup fields: %s", paste(missing_cols, collapse = ", ")), call. = FALSE)
  }

  expected_schema <- "vp_rollup_schema_2026_07_28_v1"
  schema_values <- unique(trimws(as.character(data$vp_rollup_schema_version %||% character(0))))
  schema_values <- schema_values[!is.na(schema_values) & nzchar(schema_values)]
  if (!(expected_schema %in% schema_values)) {
    stop(sprintf("rollup schema mismatch: expected %s", expected_schema), call. = FALSE)
  }

  has_rollup_rows <- any(!is.na(data$vp_is_rollup) & as.logical(data$vp_is_rollup), na.rm = TRUE)
  has_required_levels <- all(c("segment_all", "subgroup_all", "group_all") %in% unique(trimws(as.character(data$vp_rollup_level))))
  if (!isTRUE(has_rollup_rows) || !isTRUE(has_required_levels)) {
    stop("rollup levels are incomplete", call. = FALSE)
  }

  TRUE
}

contract_status <- function(data) {
  error_message <- NA_character_
  status <- tryCatch(
    {
      validate_rollup_contract_like_startup(data)
      "PASS"
    },
    error = function(error) {
      error_message <<- conditionMessage(error)
      "FAIL"
    }
  )
  list(status = status, error = error_message)
}

collapse_counts <- function(values) {
  values <- as.character(values)
  values <- values[!is.na(values) & nzchar(values)]
  if (length(values) == 0L) return(NA_character_)
  counts <- sort(table(values), decreasing = TRUE)
  paste(sprintf("%s=%s", names(counts), as.integer(counts)), collapse = ";")
}

hierarchy_depth_counts <- function(data) {
  cols <- c("Group", "Subgroup", "MarketSegment")
  if (!all(cols %in% names(data))) return(NA_character_)
  depth <- rowSums(!is.na(data[, cols, drop = FALSE]) & nzchar(as.matrix(data[, cols, drop = FALSE])))
  collapse_counts(depth)
}

shape_row <- function(path, variant_name, classification, data = NULL) {
  if (is.null(data)) data <- readRDS(path)
  is_table <- is.data.frame(data)
  rollup_flag <- if (is_table && "vp_is_rollup" %in% names(data)) as.logical(data$vp_is_rollup) else rep(FALSE, if (is_table) nrow(data) else 0L)
  rollup_rows <- sum(!is.na(rollup_flag) & rollup_flag, na.rm = TRUE)
  row_count <- if (is_table) nrow(data) else NA_integer_
  contract <- if (is_table) contract_status(data) else list(status = "FAIL", error = "artifact is not a data frame")
  info <- file.info(path)

  data.frame(
    variant_name = variant_name,
    classification = classification,
    path = normalize_path(path),
    file_size_bytes = as.numeric(info$size),
    file_size_mb = as.numeric(info$size) / (1024 * 1024),
    object_size_mb = as.numeric(utils::object.size(data)) / (1024 * 1024),
    rows = row_count,
    cols = if (is_table) ncol(data) else NA_integer_,
    native_rows = if (is_table) row_count - rollup_rows else NA_integer_,
    rollup_rows = rollup_rows,
    rollup_share = if (is_table && row_count > 0L) rollup_rows / row_count else NA_real_,
    contract_status = contract$status,
    contract_error = contract$error,
    rollup_level_counts = if (is_table && "vp_rollup_level" %in% names(data)) collapse_counts(data$vp_rollup_level) else NA_character_,
    trade_counts = if (is_table && "Trade" %in% names(data)) collapse_counts(data$Trade) else NA_character_,
    unit_type_counts = if (is_table && "UnitType" %in% names(data)) collapse_counts(data$UnitType) else NA_character_,
    hierarchy_depth_counts = if (is_table) hierarchy_depth_counts(data) else NA_character_,
    stringsAsFactors = FALSE
  )
}

create_native_only <- function(data) {
  if (!("vp_is_rollup" %in% names(data))) {
    return(data)
  }
  rollup_flag <- as.logical(data$vp_is_rollup)
  data[is.na(rollup_flag) | !rollup_flag, , drop = FALSE]
}

create_minimal_rollup_contract <- function(data) {
  native <- create_native_only(data)
  if (!("vp_is_rollup" %in% names(data)) || !("vp_rollup_level" %in% names(data))) {
    stop("Cannot create minimal rollup contract candidate without vp_is_rollup and vp_rollup_level.", call. = FALSE)
  }

  rollup_flag <- as.logical(data$vp_is_rollup)
  rollup_rows <- data[!is.na(rollup_flag) & rollup_flag, , drop = FALSE]
  required_levels <- c("segment_all", "subgroup_all", "group_all")
  selected <- lapply(required_levels, function(level) {
    level_rows <- rollup_rows[trimws(as.character(rollup_rows$vp_rollup_level)) == level, , drop = FALSE]
    if (nrow(level_rows) == 0L) {
      stop(sprintf("Cannot create minimal rollup contract candidate; missing level %s.", level), call. = FALSE)
    }
    level_rows[1L, , drop = FALSE]
  })

  do.call(rbind, c(list(native), selected))
}

assert_output_root_safe <- function(output_root, processed_dir) {
  output_norm <- tolower(normalize_path(output_root))
  processed_norm <- tolower(normalize_path(processed_dir))
  if (startsWith(output_norm, processed_norm)) {
    stop("Refusing to write rollup ablation artifacts under System/Processed Data.", call. = FALSE)
  }
  invisible(TRUE)
}

main <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  vp_clone_dir <- resolve_vp_clone_dir(getwd())
  processed_dir <- file.path(vp_clone_dir, "System", "Processed Data")
  logs_dir <- file.path(vp_clone_dir, "Logs")

  label <- trimws(as.character(parse_arg_value(args, "label", default = "step21_branch_k_rollup_ablate_prepare")))
  if (!nzchar(label)) label <- "step21_branch_k_rollup_ablate_prepare"
  artifact_path <- normalize_path(parse_arg_value(args, "artifact", default = file.path(processed_dir, "vp_trade_monthly_pre.rds")))
  metadata_path <- normalize_path(parse_arg_value(args, "metadata", default = file.path(processed_dir, "vp_trade_metadata_pre.rds")))
  timestamp_token <- format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC")
  output_root <- normalize_path(parse_arg_value(args, "output-root", default = file.path(logs_dir, "rollup_ablation", timestamp_token)))

  assert_output_root_safe(output_root, processed_dir)
  dir.create(output_root, recursive = TRUE, showWarnings = FALSE)

  if (!file.exists(artifact_path)) {
    stop(sprintf("Artifact does not exist: %s", artifact_path), call. = FALSE)
  }

  full_copy_path <- file.path(output_root, "vp_trade_monthly_full_copy.rds")
  native_only_path <- file.path(output_root, "vp_trade_monthly_native_only.rds")
  minimal_rollup_path <- file.path(output_root, "vp_trade_monthly_minimal_rollup_contract.rds")
  metadata_copy_path <- file.path(output_root, "vp_trade_metadata_full_copy.rds")
  shape_path <- file.path(output_root, "rollup_ablation_shape.csv")
  signatures_path <- file.path(output_root, "rollup_ablation_signatures.csv")

  cat("VP_ROLLUP_ABLATION_PREP_START\n")
  cat(sprintf("VP_ROLLUP_ABLATION_PREP_LABEL=%s\n", label))
  cat(sprintf("VP_ROLLUP_ABLATION_PREP_ARTIFACT=%s\n", artifact_path))
  cat(sprintf("VP_ROLLUP_ABLATION_PREP_OUTPUT_ROOT=%s\n", output_root))

  source_data <- readRDS(artifact_path)
  if (!is.data.frame(source_data)) {
    stop("Canonical VP trade artifact is not a data frame.", call. = FALSE)
  }

  if (!file.copy(artifact_path, full_copy_path, overwrite = TRUE)) {
    stop(sprintf("Failed to copy canonical artifact to %s", full_copy_path), call. = FALSE)
  }
  if (file.exists(metadata_path) && !file.copy(metadata_path, metadata_copy_path, overwrite = TRUE)) {
    stop(sprintf("Failed to copy canonical metadata to %s", metadata_copy_path), call. = FALSE)
  }

  native_only <- create_native_only(source_data)
  minimal_rollup <- create_minimal_rollup_contract(source_data)

  safe_write_rds(native_only, native_only_path)
  safe_write_rds(minimal_rollup, minimal_rollup_path)

  shape <- do.call(rbind, list(
    shape_row(artifact_path, "baseline_canonical", "behavior_valid", source_data),
    shape_row(full_copy_path, "full_copy", "behavior_valid_copy"),
    shape_row(native_only_path, "native_only", "measurement_only", native_only),
    shape_row(minimal_rollup_path, "minimal_rollup_contract", "semantically_invalid_performance_only", minimal_rollup)
  ))
  utils::write.csv(shape, shape_path, row.names = FALSE)

  signatures <- do.call(rbind, list(
    file_signature_row(artifact_path, "source_artifact_before"),
    file_signature_row(metadata_path, "source_metadata_before"),
    file_signature_row(full_copy_path, "full_copy_artifact"),
    file_signature_row(metadata_copy_path, "full_copy_metadata"),
    file_signature_row(native_only_path, "native_only_artifact"),
    file_signature_row(minimal_rollup_path, "minimal_rollup_artifact"),
    file_signature_row(artifact_path, "source_artifact_after"),
    file_signature_row(metadata_path, "source_metadata_after")
  ))
  utils::write.csv(signatures, signatures_path, row.names = FALSE)

  cat(sprintf("VP_ROLLUP_ABLATION_PREP_SHAPE_OUTPUT=%s\n", normalize_path(shape_path)))
  cat(sprintf("VP_ROLLUP_ABLATION_PREP_SIGNATURES_OUTPUT=%s\n", normalize_path(signatures_path)))
  cat(sprintf("VP_ROLLUP_ABLATION_PREP_FULL_COPY_ARTIFACT=%s\n", normalize_path(full_copy_path)))
  cat(sprintf("VP_ROLLUP_ABLATION_PREP_NATIVE_ONLY_ARTIFACT=%s\n", normalize_path(native_only_path)))
  cat(sprintf("VP_ROLLUP_ABLATION_PREP_MINIMAL_ROLLUP_ARTIFACT=%s\n", normalize_path(minimal_rollup_path)))
  cat(sprintf("VP_ROLLUP_ABLATION_PREP_NATIVE_ONLY_ROWS=%s\n", nrow(native_only)))
  cat(sprintf("VP_ROLLUP_ABLATION_PREP_MINIMAL_ROLLUP_ROWS=%s\n", nrow(minimal_rollup)))
  cat("VP_ROLLUP_ABLATION_PREP_COMPLETE\n")

  invisible(shape)
}

main()
