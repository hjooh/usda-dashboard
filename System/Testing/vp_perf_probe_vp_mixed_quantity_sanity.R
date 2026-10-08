`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0L) y else x
}

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

  stop("Could not resolve repository root for VP mixed/non-mixed sanity probe.", call. = FALSE)
}

to_int_ms <- function(start_time, end_time = Sys.time()) {
  elapsed_seconds <- suppressWarnings(as.numeric(difftime(end_time, start_time, units = "secs")))
  if (!is.finite(elapsed_seconds)) return(NA_integer_)
  as.integer(round(elapsed_seconds * 1000))
}

safe_trim <- function(x) {
  out <- trimws(as.character(x %||% ""))
  out[is.na(out)] <- ""
  out
}

emit_probe <- function(key, value = NULL) {
  if (is.null(value)) {
    cat(sprintf("VP_PERF_MIXED_QUANTITY_SANITY_%s\n", key))
  } else {
    cat(sprintf("VP_PERF_MIXED_QUANTITY_SANITY_%s=%s\n", key, value))
  }
  flush.console()
}

normalize_cache_state <- function(value) {
  valid_cache_states <- c("cold_artifact", "warm_partition_disk", "warm_session", "unknown_cache_state")
  candidate <- trimws(as.character(value %||% "unknown_cache_state"))
  if (!nzchar(candidate) || !(candidate %in% valid_cache_states)) return("unknown_cache_state")
  candidate
}

extract_column <- function(rows, column_name, default = NA) {
  if (!is.data.frame(rows) || !(column_name %in% names(rows))) {
    return(rep(default, if (is.data.frame(rows)) nrow(rows) else 0L))
  }
  rows[[column_name]]
}

volume_family_from_rows <- function(rows) {
  if (!is.data.frame(rows) || nrow(rows) == 0L) return("unknown")

  if ("vp_volume_family_mixed" %in% names(rows)) {
    mixed_flags <- as.logical(rows[["vp_volume_family_mixed"]])
    mixed_flags[is.na(mixed_flags)] <- FALSE
    if (any(mixed_flags)) return("mixed")
  }

  family_values <- character(0)
  if ("volume_unit_family" %in% names(rows)) {
    family_values <- tolower(safe_trim(rows[["volume_unit_family"]]))
    family_values <- family_values[family_values %in% c("liquid", "weight")]
  }

  family_values <- unique(family_values)
  if (length(family_values) == 1L) return(family_values[[1L]])
  if (length(family_values) > 1L) return("mixed")
  "unknown"
}

context_rows <- function(artifact, context) {
  if (!is.null(context$row_indices) && length(context$row_indices) > 0L) {
    return(artifact[context$row_indices, , drop = FALSE])
  }

  keep <-
    tolower(safe_trim(artifact[["Trade"]])) == context$trade &
    safe_trim(artifact[["Group"]]) == context$group &
    safe_trim(artifact[["Subgroup"]]) == context$subgroup &
    safe_trim(artifact[["MarketSegment"]]) == context$segment &
    safe_trim(artifact[["CommodityName"]]) == context$commodity_name &
    safe_trim(artifact[["commodity"]]) == context$commodity_detail &
    safe_trim(artifact[["country"]]) == context$country

  artifact[keep, , drop = FALSE]
}

pick_context_candidates <- function(artifact) {
  required <- c("Trade", "Group", "Subgroup", "MarketSegment", "CommodityName", "commodity", "country", "vp_volume_family_mixed")
  missing <- setdiff(required, names(artifact))
  if (length(missing) > 0L) {
    stop(sprintf("Artifact missing required columns: %s", paste(missing, collapse = ", ")), call. = FALSE)
  }

  trade <- tolower(safe_trim(artifact[["Trade"]]))
  group <- safe_trim(artifact[["Group"]])
  subgroup <- safe_trim(artifact[["Subgroup"]])
  segment <- safe_trim(artifact[["MarketSegment"]])
  commodity_name <- safe_trim(artifact[["CommodityName"]])
  commodity_detail <- safe_trim(artifact[["commodity"]])
  country <- safe_trim(artifact[["country"]])
  mixed <- as.logical(artifact[["vp_volume_family_mixed"]])
  mixed[is.na(mixed)] <- FALSE
  family <- tolower(safe_trim(extract_column(artifact, "volume_unit_family", default = "unknown")))
  family[!(family %in% c("liquid", "weight"))] <- "unknown"

  valid <-
    trade %in% c("export", "import") &
    country == "GRAND_TOTAL" &
    nzchar(group) &
    nzchar(subgroup) &
    nzchar(segment) &
    nzchar(commodity_name) &
    nzchar(commodity_detail)

  mixed_idx <- which(valid & mixed & trade == "export")
  if (length(mixed_idx) == 0L) mixed_idx <- which(valid & mixed)
  if (length(mixed_idx) == 0L) stop("No mixed VP context candidate found in artifact.", call. = FALSE)

  mixed_pick <- mixed_idx[[1L]]
  target_trade <- trade[[mixed_pick]]
  nonmixed_idx <- which(valid & !mixed & trade == target_trade & family %in% c("liquid", "weight"))
  if (length(nonmixed_idx) == 0L) nonmixed_idx <- which(valid & !mixed & family %in% c("liquid", "weight"))
  if (length(nonmixed_idx) == 0L) nonmixed_idx <- which(valid & !mixed)
  if (length(nonmixed_idx) == 0L) stop("No non-mixed VP context candidate found in artifact.", call. = FALSE)

  context_indices <- function(index) {
    which(
      trade == trade[[index]] &
        group == group[[index]] &
        subgroup == subgroup[[index]] &
        segment == segment[[index]] &
        commodity_name == commodity_name[[index]] &
        commodity_detail == commodity_detail[[index]] &
        country == country[[index]]
    )
  }

  build_context <- function(index) {
    list(
      trade = trade[[index]],
      group = group[[index]],
      subgroup = subgroup[[index]],
      segment = segment[[index]],
      commodity_name = commodity_name[[index]],
      commodity_detail = commodity_detail[[index]],
      country = country[[index]],
      family = family[[index]],
      mixed = isTRUE(mixed[[index]]),
      row_indices = context_indices(index)
    )
  }

  list(mixed = build_context(mixed_pick), nonmixed = build_context(nonmixed_idx[[1L]]))
}

metrics_suppressed_for_rows <- function(rows) {
  mixed_flags <- as.logical(extract_column(rows, "vp_volume_family_mixed", default = FALSE))
  mixed_flags[is.na(mixed_flags)] <- FALSE
  if (!any(mixed_flags)) return(TRUE)

  monthly_exports <- suppressWarnings(as.numeric(extract_column(rows, "monthlyexports", default = NA_real_)))
  ytd_exports <- suppressWarnings(as.numeric(extract_column(rows, "ytd_exports", default = NA_real_)))

  all(is.na(monthly_exports[mixed_flags])) && all(is.na(ytd_exports[mixed_flags]))
}

unit_expectations <- function(family) {
  if (identical(family, "liquid")) {
    return(list(
      quantity_available = TRUE,
      default_unit = "thousand_gallons",
      choices = "thousand_gallons|gallons",
      unavailable_reason_expected = FALSE
    ))
  }

  if (identical(family, "weight")) {
    return(list(
      quantity_available = TRUE,
      default_unit = "thousand_lbs",
      choices = "million_cwt|thousand_mt|mt|kg|thousand_kg|us_tons|thousand_lbs|lbs|cwt|mil_lbs",
      unavailable_reason_expected = FALSE
    ))
  }

  if (identical(family, "mixed")) {
    return(list(
      quantity_available = FALSE,
      default_unit = NA_character_,
      choices = "",
      unavailable_reason_expected = TRUE
    ))
  }

  list(
    quantity_available = FALSE,
    default_unit = NA_character_,
    choices = "",
    unavailable_reason_expected = TRUE
  )
}

run_probe <- function(artifact_path, label, cache_state) {
  probe_start <- Sys.time()
  emit_probe("STAGE_BEGIN", "artifact_load")
  artifact_load_start <- Sys.time()
  artifact <- readRDS(artifact_path)
  artifact_load_ms <- to_int_ms(artifact_load_start)
  emit_probe("STAGE_END", paste0("artifact_load|elapsed_ms=", artifact_load_ms, "|rows=", nrow(artifact)))

  emit_probe("STAGE_BEGIN", "pick_context_candidates")
  contexts <- pick_context_candidates(artifact)
  emit_probe("STAGE_END", "pick_context_candidates")

  mixed_rows <- context_rows(artifact, contexts$mixed)
  nonmixed_rows <- context_rows(artifact, contexts$nonmixed)
  mixed_family <- volume_family_from_rows(mixed_rows)
  nonmixed_family <- volume_family_from_rows(nonmixed_rows)
  mixed_units <- unit_expectations(mixed_family)
  nonmixed_units <- unit_expectations(nonmixed_family)

  mixed_metric_block_ok <- identical(mixed_family, "mixed") && metrics_suppressed_for_rows(mixed_rows)
  mixed_quantity_ok <- !isTRUE(mixed_units$quantity_available) && isTRUE(mixed_units$unavailable_reason_expected)
  nonmixed_metric_block_ok <- !identical(nonmixed_family, "mixed")
  nonmixed_quantity_ok <- isTRUE(nonmixed_units$quantity_available) && nonmixed_units$default_unit %in% strsplit(nonmixed_units$choices, "|", fixed = TRUE)[[1L]]
  unsupported_metric_family <- "unknown"
  unsupported_metric_ok <- identical(unsupported_metric_family, "unknown")

  checks <- c(
    mixed_rows_found = nrow(mixed_rows) > 0L,
    mixed_context_flagged = identical(mixed_family, "mixed"),
    mixed_metric_block_ok = mixed_metric_block_ok,
    mixed_quantity_ok = mixed_quantity_ok,
    nonmixed_rows_found = nrow(nonmixed_rows) > 0L,
    nonmixed_context_not_mixed = !identical(nonmixed_family, "mixed"),
    nonmixed_metric_block_ok = nonmixed_metric_block_ok,
    nonmixed_quantity_ok = nonmixed_quantity_ok,
    unsupported_metric_ok = unsupported_metric_ok
  )

  failed_checks <- names(checks)[!checks]
  status <- if (length(failed_checks) == 0L) "PASS" else "FAIL"

  data.frame(
    label = label,
    status = status,
    cache_state = cache_state,
    error_message = if (length(failed_checks) > 0L) paste(failed_checks, collapse = "|") else NA_character_,
    runtime_log_path = NA_character_,
    artifact_path = normalizePath(artifact_path, winslash = "/", mustWork = FALSE),
    artifact_load_ms = artifact_load_ms,
    mixed_trade = contexts$mixed$trade,
    mixed_group = contexts$mixed$group,
    mixed_subgroup = contexts$mixed$subgroup,
    mixed_segment = contexts$mixed$segment,
    mixed_commodity_name = contexts$mixed$commodity_name,
    mixed_commodity_detail = contexts$mixed$commodity_detail,
    mixed_country = contexts$mixed$country,
    mixed_rows = nrow(mixed_rows),
    mixed_family = mixed_family,
    mixed_metric_block_ok = isTRUE(mixed_metric_block_ok),
    mixed_quantity_ok = isTRUE(mixed_quantity_ok),
    mixed_default_unit = mixed_units$default_unit,
    mixed_unit_choices = mixed_units$choices,
    mixed_unavailable_reason_expected = isTRUE(mixed_units$unavailable_reason_expected),
    nonmixed_trade = contexts$nonmixed$trade,
    nonmixed_group = contexts$nonmixed$group,
    nonmixed_subgroup = contexts$nonmixed$subgroup,
    nonmixed_segment = contexts$nonmixed$segment,
    nonmixed_commodity_name = contexts$nonmixed$commodity_name,
    nonmixed_commodity_detail = contexts$nonmixed$commodity_detail,
    nonmixed_country = contexts$nonmixed$country,
    nonmixed_rows = nrow(nonmixed_rows),
    nonmixed_family = nonmixed_family,
    nonmixed_metric_block_ok = isTRUE(nonmixed_metric_block_ok),
    nonmixed_quantity_ok = isTRUE(nonmixed_quantity_ok),
    nonmixed_default_unit = nonmixed_units$default_unit,
    nonmixed_unit_choices = nonmixed_units$choices,
    nonmixed_unavailable_reason_expected = isTRUE(nonmixed_units$unavailable_reason_expected),
    unsupported_metric_family = unsupported_metric_family,
    unsupported_metric_ok = isTRUE(unsupported_metric_ok),
    total_probe_ms = to_int_ms(probe_start),
    stringsAsFactors = FALSE
  )
}

main <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  repo_root <- resolve_repo_root(getwd())
  app_dir <- file.path(repo_root, "VP Clone")
  logs_dir <- file.path(app_dir, "Logs")
  dir.create(logs_dir, recursive = TRUE, showWarnings = FALSE)

  label <- trimws(as.character(parse_arg_value(args, "label", default = "mixed_quantity_sanity")))
  if (!nzchar(label)) label <- "mixed_quantity_sanity"
  cache_state <- normalize_cache_state(parse_arg_value(args, "cache-state", default = "unknown_cache_state"))
  artifact_path <- normalizePath(parse_arg_value(args, "artifact", default = file.path(app_dir, "System", "Processed Data", "vp_trade_monthly_pre.rds")), winslash = "/", mustWork = FALSE)

  timestamp_token <- format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC")
  output_path <- file.path(logs_dir, sprintf("vp_perf_probe_vp_mixed_quantity_sanity_%s_%s.csv", label, timestamp_token))

  emit_probe("PROBE_START")
  emit_probe("LABEL", label)
  emit_probe("CACHE_STATE", cache_state)
  emit_probe("MODE", "artifact_contract")

  result <- tryCatch(
    run_probe(artifact_path = artifact_path, label = label, cache_state = cache_state),
    error = function(error) {
      data.frame(
        label = label,
        status = "FAIL",
        cache_state = cache_state,
        error_message = conditionMessage(error),
        runtime_log_path = NA_character_,
        artifact_path = artifact_path,
        artifact_load_ms = NA_integer_,
        total_probe_ms = NA_integer_,
        stringsAsFactors = FALSE
      )
    }
  )

  utils::write.csv(result, output_path, row.names = FALSE, na = "")

  emit_probe("STATUS", result$status[[1L]])
  emit_probe("OUTPUT", normalizePath(output_path, winslash = "/", mustWork = FALSE))
  emit_probe("TOTAL_MS", result$total_probe_ms[[1L]] %||% NA_integer_)
  if (!identical(result$status[[1L]], "PASS")) {
    emit_probe("ERROR", result$error_message[[1L]] %||% "")
  }
  emit_probe("PROBE_COMPLETE")
}

main()