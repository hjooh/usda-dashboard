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

  stop("Could not resolve repository root for VP filter probe.", call. = FALSE)
}

to_int_ms <- function(start_time, end_time = Sys.time()) {
  elapsed_seconds <- suppressWarnings(as.numeric(difftime(end_time, start_time, units = "secs")))
  if (!is.finite(elapsed_seconds)) return(NA_integer_)
  as.integer(round(elapsed_seconds * 1000))
}

valid_cache_states <- c("cold_artifact", "warm_partition_disk", "warm_session", "unknown_cache_state")

normalize_cache_state <- function(value) {
  candidate <- trimws(as.character(value %||% "unknown_cache_state"))
  if (!nzchar(candidate) || !(candidate %in% valid_cache_states)) return("unknown_cache_state")
  candidate
}

normalize_filter_value <- function(value) {
  candidate <- trimws(as.character(value %||% ""))
  candidate <- candidate[!is.na(candidate)]
  if (length(candidate) == 0L || !nzchar(candidate[[1L]]) || identical(candidate[[1L]], "__all__")) {
    return(NA_character_)
  }
  candidate[[1L]]
}

build_scenarios <- function(args) {
  scenario_arg <- trimws(as.character(parse_arg_value(args, "scenario", default = "")))
  if (nzchar(scenario_arg)) {
    parts <- strsplit(scenario_arg, "\\|", fixed = FALSE)[[1L]]
    parts <- c(parts, rep("", max(0L, 5L - length(parts))))
    return(data.frame(
      scenario = parts[[1L]] %||% "custom",
      trade_flow = normalize_filter_value(parts[[2L]]),
      group = normalize_filter_value(parts[[3L]]),
      subgroup = normalize_filter_value(parts[[4L]]),
      market_segment = normalize_filter_value(parts[[5L]]),
      stringsAsFactors = FALSE
    ))
  }

  data.frame(
    scenario = c("import_all", "import_dry_pulses", "import_dried_beans_dried"),
    trade_flow = c("import", "import", "import"),
    group = c(NA_character_, "Dry pulses", "Dry pulses"),
    subgroup = c(NA_character_, NA_character_, "Dried beans"),
    market_segment = c(NA_character_, NA_character_, "Dried"),
    stringsAsFactors = FALSE
  )
}

apply_direct_filter <- function(vp_rows, trade_flow, group, subgroup, market_segment) {
  out <- vp_rows
  if (!is.na(trade_flow) && "Trade" %in% names(out)) {
    out <- out[out$Trade == trade_flow, , drop = FALSE]
  }
  if (!is.na(group) && "Group" %in% names(out)) {
    out <- out[out$Group == group, , drop = FALSE]
  }
  if (!is.na(subgroup) && "Subgroup" %in% names(out)) {
    out <- out[out$Subgroup == subgroup, , drop = FALSE]
  }
  if (!is.na(market_segment) && "MarketSegment" %in% names(out)) {
    out <- out[out$MarketSegment == market_segment, , drop = FALSE]
  }
  out
}

probe_filter_scenario <- function(vp_rows, scenario_row, cache_state, artifact_load_elapsed_ms) {
  start_time <- Sys.time()
  status <- "PASS"
  error_message <- NA_character_
  out <- NULL

  tryCatch({
    out <- apply_direct_filter(
      vp_rows = vp_rows,
      trade_flow = scenario_row$trade_flow[[1L]],
      group = scenario_row$group[[1L]],
      subgroup = scenario_row$subgroup[[1L]],
      market_segment = scenario_row$market_segment[[1L]]
    )
  }, error = function(error) {
    status <<- "FAIL"
    error_message <<- conditionMessage(error)
  })

  elapsed_ms <- to_int_ms(start_time)
  data.frame(
    scenario = scenario_row$scenario[[1L]],
    status = status,
    error_message = error_message,
    cache_state = cache_state,
    artifact_load_elapsed_ms = artifact_load_elapsed_ms,
    filter_elapsed_ms = elapsed_ms,
    trade_flow = scenario_row$trade_flow[[1L]],
    group = scenario_row$group[[1L]],
    subgroup = scenario_row$subgroup[[1L]],
    market_segment = scenario_row$market_segment[[1L]],
    rows = if (!is.null(out)) nrow(out) else NA_integer_,
    cols = if (!is.null(out)) ncol(out) else NA_integer_,
    object_size_mb = if (!is.null(out)) as.numeric(utils::object.size(out)) / (1024 * 1024) else NA_real_,
    stringsAsFactors = FALSE
  )
}

main <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  repo_root <- resolve_repo_root(getwd())
  vp_clone_dir <- file.path(repo_root, "VP Clone")
  logs_dir <- file.path(vp_clone_dir, "Logs")
  dir.create(logs_dir, recursive = TRUE, showWarnings = FALSE)

  label <- trimws(as.character(parse_arg_value(args, "label", default = "vp_filters")))
  if (!nzchar(label)) label <- "vp_filters"
  cache_state <- normalize_cache_state(parse_arg_value(args, "cache-state", default = "unknown_cache_state"))
  artifact_path <- parse_arg_value(
    args,
    "artifact",
    default = file.path(vp_clone_dir, "System", "Processed Data", "vp_trade_monthly_pre.rds")
  )
  artifact_path <- normalizePath(artifact_path, winslash = "/", mustWork = FALSE)
  scenarios <- build_scenarios(args)

  timestamp_token <- format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC")
  raw_path <- file.path(logs_dir, paste0("vp_perf_probe_vp_filters_", label, "_", timestamp_token, ".csv"))

  cat("VP_PERF_VP_FILTER_PROBE_START\n")
  cat(sprintf("VP_PERF_VP_FILTER_LABEL=%s\n", label))
  cat(sprintf("VP_PERF_VP_FILTER_CACHE_STATE=%s\n", cache_state))
  cat(sprintf("VP_PERF_VP_FILTER_SCENARIOS=%d\n", nrow(scenarios)))

  load_start <- Sys.time()
  vp_rows <- readRDS(artifact_path)
  artifact_load_elapsed_ms <- to_int_ms(load_start)
  cat(sprintf("VP_PERF_VP_FILTER_ARTIFACT_LOAD_MS=%s\n", artifact_load_elapsed_ms))

  rows <- lapply(seq_len(nrow(scenarios)), function(index) {
    scenario_row <- scenarios[index, , drop = FALSE]
    cat(sprintf("VP_PERF_VP_FILTER_SCENARIO_BEGIN=%s\n", scenario_row$scenario[[1L]]))
    row <- probe_filter_scenario(vp_rows, scenario_row, cache_state, artifact_load_elapsed_ms)
    cat(sprintf("VP_PERF_VP_FILTER_SCENARIO_STATUS=%s|%s|%sms|rows=%s\n", row$scenario[[1L]], row$status[[1L]], row$filter_elapsed_ms[[1L]], row$rows[[1L]]))
    row
  })

  raw_df <- do.call(rbind, rows)
  utils::write.csv(raw_df, raw_path, row.names = FALSE)

  cat(sprintf("VP_PERF_VP_FILTER_OUTPUT=%s\n", normalizePath(raw_path, winslash = "/", mustWork = FALSE)))
  cat("VP_PERF_VP_FILTER_PROBE_COMPLETE\n")
}

main()