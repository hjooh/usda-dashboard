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

  stop("Could not resolve repository root for VP display-month signature variance probe.", call. = FALSE)
}

signature_count_by_keys <- function(data, keys) {
  grouped <- aggregate(data["calendar_signature"], data[keys], function(value) length(unique(value)))
  names(grouped)[[ncol(grouped)]] <- "signature_count"
  grouped$signature_count <- as.integer(grouped$signature_count)
  grouped
}

main <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  label <- trimws(as.character(parse_arg_value(args, "label", default = "display_month_signature_variance")))
  if (!nzchar(label)) label <- "display_month_signature_variance"

  repo_root <- resolve_repo_root(getwd())
  vp_clone_dir <- file.path(repo_root, "VP Clone")
  logs_dir <- file.path(vp_clone_dir, "Logs")
  dir.create(logs_dir, recursive = TRUE, showWarnings = FALSE)

  artifact_path <- file.path(vp_clone_dir, "System", "Processed Data", "vp_trade_monthly_pre.rds")
  timestamp_token <- format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC")
  summary_path <- file.path(logs_dir, paste0("vp_display_month_signature_variance_", label, "_", timestamp_token, "_summary.csv"))
  detail_path <- file.path(logs_dir, paste0("vp_display_month_signature_variance_", label, "_", timestamp_token, "_detail.csv"))

  probe_start <- Sys.time()
  status <- "PASS"
  error_message <- NA_character_

  result <- tryCatch({
    source_data <- readRDS(artifact_path)
    required_cols <- c(
      "Trade", "Group", "Subgroup", "MarketSegment", "CommodityName", "commodity",
      "calendar_signature"
    )
    missing_cols <- setdiff(required_cols, names(source_data))
    if (length(missing_cols) > 0L) {
      stop(paste("Missing required columns:", paste(missing_cols, collapse = ", ")), call. = FALSE)
    }

    data <- unique(source_data[required_cols])
    data$calendar_signature <- trimws(as.character(data$calendar_signature))
    data <- data[!is.na(data$calendar_signature) & nzchar(data$calendar_signature), , drop = FALSE]

    key_levels <- list(
      trade = c("Trade"),
      group = c("Trade", "Group"),
      subgroup = c("Trade", "Group", "Subgroup"),
      market_segment = c("Trade", "Group", "Subgroup", "MarketSegment"),
      commodity_name = c("Trade", "Group", "Subgroup", "MarketSegment", "CommodityName"),
      commodity_detail = c("Trade", "Group", "Subgroup", "MarketSegment", "CommodityName", "commodity")
    )

    detail_parts <- list()
    summary <- do.call(rbind, lapply(names(key_levels), function(level_name) {
      grouped <- signature_count_by_keys(data, key_levels[[level_name]])
      grouped$level <- level_name
      for (key_name in setdiff(required_cols, c(key_levels[[level_name]], "calendar_signature"))) {
        grouped[[key_name]] <- NA_character_
      }
      detail_parts[[level_name]] <<- grouped[c("level", required_cols[required_cols != "calendar_signature"], "signature_count")]
      data.frame(
        label = label,
        level = level_name,
        contexts = nrow(grouped),
        contexts_with_multiple_signatures = sum(grouped$signature_count > 1L),
        max_signature_count = max(grouped$signature_count),
        stringsAsFactors = FALSE
      )
    }))

    detail <- do.call(rbind, detail_parts)
    detail <- detail[detail$signature_count > 1L, , drop = FALSE]
    detail <- detail[c("level", setdiff(names(detail), "level"))]

    utils::write.csv(summary, summary_path, row.names = FALSE, na = "")
    utils::write.csv(detail, detail_path, row.names = FALSE, na = "")
    summary
  }, error = function(error) {
    status <<- "FAIL"
    error_message <<- conditionMessage(error)
    data.frame(
      label = label,
      level = NA_character_,
      contexts = NA_integer_,
      contexts_with_multiple_signatures = NA_integer_,
      max_signature_count = NA_integer_,
      stringsAsFactors = FALSE
    )
  })

  elapsed_ms <- as.integer(round(as.numeric(difftime(Sys.time(), probe_start, units = "secs")) * 1000))

  cat("VP_DISPLAY_MONTH_SIGNATURE_VARIANCE_START\n")
  cat(sprintf("VP_DISPLAY_MONTH_SIGNATURE_VARIANCE_STATUS=%s\n", status))
  cat(sprintf("VP_DISPLAY_MONTH_SIGNATURE_VARIANCE_LABEL=%s\n", label))
  cat(sprintf("VP_DISPLAY_MONTH_SIGNATURE_VARIANCE_ELAPSED_MS=%s\n", elapsed_ms))
  cat(sprintf("VP_DISPLAY_MONTH_SIGNATURE_VARIANCE_SUMMARY=%s\n", normalizePath(summary_path, winslash = "/", mustWork = FALSE)))
  cat(sprintf("VP_DISPLAY_MONTH_SIGNATURE_VARIANCE_DETAIL=%s\n", normalizePath(detail_path, winslash = "/", mustWork = FALSE)))
  if (!identical(status, "PASS")) {
    cat(sprintf("VP_DISPLAY_MONTH_SIGNATURE_VARIANCE_ERROR=%s\n", error_message %||% ""))
  } else {
    print(result)
  }
  cat("VP_DISPLAY_MONTH_SIGNATURE_VARIANCE_COMPLETE\n")

  if (!identical(status, "PASS")) quit(status = 1L)
}

main()