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

  stop("Could not resolve repository root for client readiness split.", call. = FALSE)
}

safe_numeric <- function(x) {
  suppressWarnings(as.numeric(x))
}

coalesce_chr <- function(...) {
  vals <- list(...)
  for (v in vals) {
    if (!is.null(v)) {
      out <- as.character(v)
      out[is.na(out)] <- ""
      return(out)
    }
  }
  character(0)
}

as_logical <- function(x, default = FALSE) {
  if (is.null(x) || length(x) == 0L || is.na(x)) return(default)
  val <- tolower(trimws(as.character(x[[1L]])))
  if (!nzchar(val)) return(default)
  val %in% c("1", "true", "t", "yes", "y", "on")
}

require_cols <- function(df, cols, df_name) {
  missing <- setdiff(cols, names(df))
  if (length(missing) > 0L) {
    stop(sprintf("%s missing required columns: %s", df_name, paste(missing, collapse = ", ")), call. = FALSE)
  }
}

collapse_top_candidates <- function(x, top_n = 3L) {
  x <- x[nzchar(x)]
  if (length(x) == 0L) return("")
  counts <- sort(table(x), decreasing = TRUE)
  top <- head(names(counts), top_n)
  paste(top, collapse = " | ")
}

normalize_source <- function(event, tag, name, summary_label, bucket_candidates) {
  event <- tolower(trimws(event))
  tag <- tolower(trimws(tag))
  name <- tolower(trimws(name))
  summary_label <- tolower(trimws(summary_label))
  bucket_candidates <- tolower(trimws(bucket_candidates))

  if (grepl("boundary_", tag, fixed = TRUE) || grepl("client_boundary_", tag, fixed = TRUE)) return("boundary_marker")
  if (grepl("client_perf", event, fixed = TRUE) || grepl("client_", tag, fixed = TRUE)) return("client_marker")
  if (grepl("log_perf", event, fixed = TRUE)) return("server_log_perf")
  if (grepl("cache_", event, fixed = TRUE) || grepl("cache_", tag, fixed = TRUE)) return("cache_signal")
  if (grepl("summary_table|historical_avg|projection_data|pace_historical_avg|current_year_data|most_recent", summary_label) ||
      grepl("summary_table|historical_avg|projection_data|pace_historical_avg|current_year_data|most_recent", name)) return("server_materialization")
  if (grepl("provider_filter", bucket_candidates, fixed = TRUE)) return("provider_related")
  "other"
}

parse_bucket_candidates <- function(x) {
  x <- trimws(as.character(x))
  x[x == ""] <- NA_character_
  out <- strsplit(ifelse(is.na(x), "", x), "\\|", fixed = FALSE)
  lapply(out, function(vals) {
    vals <- trimws(vals)
    vals <- vals[nzchar(vals)]
    unique(vals)
  })
}

main <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  repo_root <- resolve_repo_root(getwd())
  vp_clone_dir <- file.path(repo_root, "VP Clone")
  logs_dir <- file.path(vp_clone_dir, "Logs")
  dir.create(logs_dir, recursive = TRUE, showWarnings = FALSE)

  detail_arg <- trimws(as.character(parse_arg_value(args, "detail", default = "")))
  runs_arg <- trimws(as.character(parse_arg_value(args, "runs", default = "")))
  label <- trimws(as.character(parse_arg_value(args, "label", default = "tranche8i_client_readiness_split")))
  top_n <- suppressWarnings(as.integer(parse_arg_value(args, "top-n", default = "25")))
  if (is.na(top_n) || top_n <= 0L) top_n <- 25L
  include_post_visible <- as_logical(parse_arg_value(args, "include-post-visible", default = "true"), default = TRUE)

  if (!nzchar(detail_arg) || !nzchar(runs_arg)) {
    stop("Missing required --detail and/or --runs arguments.", call. = FALSE)
  }

  detail_path <- normalizePath(detail_arg, winslash = "/", mustWork = FALSE)
  if (!file.exists(detail_path)) {
    detail_path <- normalizePath(file.path(vp_clone_dir, detail_arg), winslash = "/", mustWork = FALSE)
  }
  runs_path <- normalizePath(runs_arg, winslash = "/", mustWork = FALSE)
  if (!file.exists(runs_path)) {
    runs_path <- normalizePath(file.path(vp_clone_dir, runs_arg), winslash = "/", mustWork = FALSE)
  }

  if (!file.exists(detail_path)) stop(sprintf("Detail file not found: %s", detail_arg), call. = FALSE)
  if (!file.exists(runs_path)) stop(sprintf("Runs file not found: %s", runs_arg), call. = FALSE)

  detail <- utils::read.csv(detail_path, stringsAsFactors = FALSE, check.names = FALSE)
  runs <- utils::read.csv(runs_path, stringsAsFactors = FALSE, check.names = FALSE)

  if (nrow(detail) == 0L) stop("Detail file has no rows.", call. = FALSE)
  if (nrow(runs) == 0L) stop("Runs file has no rows.", call. = FALSE)

  require_cols(detail, c(
    "lane", "pair_run_label", "role", "run_id", "window", "bucket",
    "event", "tag", "name", "summary_label", "attributed_elapsed_ms",
    "gap_allocated_ms", "bucket_candidates", "multi_match", "ts_utc"
  ), "detail")
  require_cols(runs, c(
    "pair_run_label", "role", "run_id", "visible_ts_utc", "action_start_ts_utc",
    "visible_milestone_source", "action_start_source", "runtime_log_path"
  ), "runs")

  detail$event <- coalesce_chr(detail$event)
  detail$tag <- coalesce_chr(detail$tag)
  detail$name <- coalesce_chr(detail$name)
  detail$summary_label <- coalesce_chr(detail$summary_label)
  detail$bucket <- coalesce_chr(detail$bucket)
  detail$window <- coalesce_chr(detail$window)
  detail$pair_run_label <- coalesce_chr(detail$pair_run_label)
  detail$role <- coalesce_chr(detail$role)
  detail$lane <- coalesce_chr(detail$lane)
  detail$run_id <- coalesce_chr(detail$run_id)
  detail$bucket_candidates <- coalesce_chr(detail$bucket_candidates)
  detail$multi_match <- as.logical(detail$multi_match)
  detail$multi_match[is.na(detail$multi_match)] <- FALSE
  detail$attributed_elapsed_ms <- safe_numeric(detail$attributed_elapsed_ms)
  detail$attributed_elapsed_ms[is.na(detail$attributed_elapsed_ms)] <- 0
  detail$gap_allocated_ms <- safe_numeric(detail$gap_allocated_ms)
  detail$gap_allocated_ms[is.na(detail$gap_allocated_ms)] <- 0

  detail$signature <- ifelse(
    nzchar(detail$summary_label),
    detail$summary_label,
    ifelse(nzchar(detail$name), detail$name,
      ifelse(nzchar(detail$tag), detail$tag,
        ifelse(nzchar(detail$event), detail$event, "<unknown>")))
  )

  detail$source <- mapply(
    normalize_source,
    event = detail$event,
    tag = detail$tag,
    name = detail$name,
    summary_label = detail$summary_label,
    bucket_candidates = detail$bucket_candidates,
    USE.NAMES = FALSE
  )

  detail$marker_mode <- ifelse(grepl("_cohort_on_", detail$pair_run_label, ignore.case = TRUE), "on",
    ifelse(grepl("_cohort_off_", detail$pair_run_label, ignore.case = TRUE), "off", "unknown"))

  keep_buckets <- c("client_lifecycle", "transition_wait", "client_wait")
  keep_windows <- c("action_window", if (isTRUE(include_post_visible)) "post_visible_idle" else character(0))
  split_df <- detail[detail$bucket %in% keep_buckets & detail$window %in% keep_windows, , drop = FALSE]

  if (nrow(split_df) == 0L) {
    stop("No rows after filtering to client/wait buckets and selected windows.", call. = FALSE)
  }

  window_totals <- aggregate(
    list(window_total_attributed_ms = split_df$attributed_elapsed_ms),
    list(pair_run_label = split_df$pair_run_label, role = split_df$role, window = split_df$window),
    sum,
    na.rm = TRUE
  )

  cww_totals <- aggregate(
    list(client_wait_family_total_ms = split_df$attributed_elapsed_ms),
    list(pair_run_label = split_df$pair_run_label, role = split_df$role),
    sum,
    na.rm = TRUE
  )

  group_sig <- list(
    lane = split_df$lane,
    pair_run_label = split_df$pair_run_label,
    marker_mode = split_df$marker_mode,
    role = split_df$role,
    window = split_df$window,
    bucket = split_df$bucket,
    event = split_df$event,
    tag = split_df$tag,
    name = split_df$name,
    summary_label = split_df$summary_label,
    source = split_df$source,
    signature = split_df$signature
  )

  sig_agg <- aggregate(
    list(
      row_count = rep(1L, nrow(split_df)),
      total_attributed_ms = split_df$attributed_elapsed_ms,
      total_gap_allocated_ms = split_df$gap_allocated_ms,
      multi_match_row_count = as.integer(split_df$multi_match)
    ),
    group_sig,
    sum,
    na.rm = TRUE
  )

  # Replace first/last timestamps using min/max character ordering for UTC strings.
  ts_by_sig_min <- aggregate(
    list(first_ts_utc = split_df$ts_utc),
    group_sig,
    function(x) {
      vals <- sort(as.character(x))
      vals[[1L]]
    }
  )
  ts_by_sig_max <- aggregate(
    list(last_ts_utc = split_df$ts_utc),
    group_sig,
    function(x) {
      vals <- sort(as.character(x), decreasing = TRUE)
      vals[[1L]]
    }
  )

  key_cols <- c("lane", "pair_run_label", "marker_mode", "role", "window", "bucket", "event", "tag", "name", "summary_label", "source", "signature")
  sig_agg <- merge(sig_agg, ts_by_sig_min, by = key_cols, all.x = TRUE, suffixes = c("", "_min"))
  sig_agg <- merge(sig_agg, ts_by_sig_max, by = key_cols, all.x = TRUE, suffixes = c("", "_max"))

  sig_agg$bucket_share <- NA_real_
  sig_agg$client_wait_family_share <- NA_real_

  sig_agg <- merge(sig_agg, window_totals, by = c("pair_run_label", "role", "window"), all.x = TRUE)
  sig_agg <- merge(sig_agg, cww_totals, by = c("pair_run_label", "role"), all.x = TRUE)

  sig_agg$bucket_share <- ifelse(sig_agg$window_total_attributed_ms > 0,
    sig_agg$total_attributed_ms / sig_agg$window_total_attributed_ms,
    NA_real_)
  sig_agg$client_wait_family_share <- ifelse(sig_agg$client_wait_family_total_ms > 0,
    sig_agg$total_attributed_ms / sig_agg$client_wait_family_total_ms,
    NA_real_)

  # Keep top signatures per pair/role/window/bucket by attributed time.
  order_idx <- order(
    sig_agg$pair_run_label,
    sig_agg$role,
    sig_agg$window,
    sig_agg$bucket,
    -sig_agg$total_attributed_ms,
    -sig_agg$row_count
  )
  sig_agg <- sig_agg[order_idx, , drop = FALSE]
  sig_agg$rank_in_bucket <- ave(
    sig_agg$total_attributed_ms,
    sig_agg$pair_run_label,
    sig_agg$role,
    sig_agg$window,
    sig_agg$bucket,
    FUN = function(x) seq_along(x)
  )
  sig_top <- sig_agg[sig_agg$rank_in_bucket <= top_n, , drop = FALSE]

  runs$key <- paste(runs$pair_run_label, runs$role, runs$run_id, sep = "||")
  run_to_visible <- setNames(as.character(runs$visible_ts_utc), runs$key)
  run_to_action <- setNames(as.character(runs$action_start_ts_utc), runs$key)
  run_to_vis_source <- setNames(as.character(runs$visible_milestone_source), runs$key)
  run_to_action_source <- setNames(as.character(runs$action_start_source), runs$key)

  split_df$key <- paste(split_df$pair_run_label, split_df$role, split_df$run_id, sep = "||")
  split_df$visible_ts_utc <- run_to_visible[split_df$key]
  split_df$action_start_ts_utc <- run_to_action[split_df$key]
  split_df$visible_milestone_source <- run_to_vis_source[split_df$key]
  split_df$action_start_source <- run_to_action_source[split_df$key]

  split_df$event_posix <- suppressWarnings(as.POSIXct(split_df$ts_utc, tz = "UTC"))
  split_df$visible_posix <- suppressWarnings(as.POSIXct(split_df$visible_ts_utc, tz = "UTC"))
  split_df$action_posix <- suppressWarnings(as.POSIXct(split_df$action_start_ts_utc, tz = "UTC"))

  split_df$wait_location <- ifelse(
    split_df$window == "post_visible_idle",
    "post_visible",
    ifelse(!is.na(split_df$visible_posix) & !is.na(split_df$event_posix) & split_df$event_posix <= split_df$visible_posix,
      "pre_visible",
      ifelse(!is.na(split_df$visible_posix) & !is.na(split_df$event_posix) & split_df$event_posix > split_df$visible_posix,
        "post_visible",
        "unknown"))
  )

  split_df$gap_context <- ifelse(
    split_df$bucket == "transition_wait",
    "transition_gap",
    ifelse(split_df$bucket == "client_wait", "client_wait_gap", "client_lifecycle_event")
  )

  split_df$bucket_candidate_top <- vapply(parse_bucket_candidates(split_df$bucket_candidates), collapse_top_candidates, character(1))

  group_gap <- list(
    lane = split_df$lane,
    pair_run_label = split_df$pair_run_label,
    marker_mode = split_df$marker_mode,
    role = split_df$role,
    window = split_df$window,
    bucket = split_df$bucket,
    gap_context = split_df$gap_context,
    wait_location = split_df$wait_location,
    visible_milestone_source = split_df$visible_milestone_source,
    action_start_source = split_df$action_start_source,
    from_event_signature = split_df$signature,
    to_event_signature = split_df$bucket_candidate_top
  )

  gap_agg <- aggregate(
    list(
      row_count = rep(1L, nrow(split_df)),
      total_attributed_ms = split_df$attributed_elapsed_ms,
      total_gap_allocated_ms = split_df$gap_allocated_ms
    ),
    group_gap,
    sum,
    na.rm = TRUE
  )

  role_pair_summary <- aggregate(
    list(
      total_attributed_ms = split_df$attributed_elapsed_ms,
      total_gap_allocated_ms = split_df$gap_allocated_ms,
      row_count = rep(1L, nrow(split_df)),
      pre_visible_ms = ifelse(split_df$wait_location == "pre_visible", split_df$attributed_elapsed_ms, 0),
      post_visible_ms = ifelse(split_df$wait_location == "post_visible", split_df$attributed_elapsed_ms, 0),
      server_complete_to_client_visible_ms = ifelse(split_df$source == "boundary_marker" & split_df$wait_location == "pre_visible", split_df$attributed_elapsed_ms, 0)
    ),
    list(
      lane = split_df$lane,
      pair_run_label = split_df$pair_run_label,
      marker_mode = split_df$marker_mode,
      role = split_df$role,
      window = split_df$window,
      bucket = split_df$bucket
    ),
    sum,
    na.rm = TRUE
  )

  role_pair_totals <- aggregate(
    list(total_window_ms = split_df$attributed_elapsed_ms),
    list(pair_run_label = split_df$pair_run_label, role = split_df$role, window = split_df$window),
    sum,
    na.rm = TRUE
  )
  role_pair_summary <- merge(role_pair_summary, role_pair_totals, by = c("pair_run_label", "role", "window"), all.x = TRUE)
  role_pair_summary$share <- ifelse(role_pair_summary$total_window_ms > 0,
    role_pair_summary$total_attributed_ms / role_pair_summary$total_window_ms,
    NA_real_)

  timestamp_token <- format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC")
  prefix <- file.path(logs_dir, paste0("vp_perf_client_readiness_split_", label, "_", timestamp_token))

  sig_path <- paste0(prefix, "_signature.csv")
  gap_path <- paste0(prefix, "_gap_context.csv")
  role_pair_path <- paste0(prefix, "_role_pair_summary.csv")

  sig_top <- sig_top[order(sig_top$pair_run_label, sig_top$role, sig_top$window, sig_top$bucket, sig_top$rank_in_bucket), , drop = FALSE]
  gap_agg <- gap_agg[order(gap_agg$pair_run_label, gap_agg$role, gap_agg$window, gap_agg$bucket, -gap_agg$total_attributed_ms), , drop = FALSE]
  role_pair_summary <- role_pair_summary[order(role_pair_summary$pair_run_label, role_pair_summary$role, role_pair_summary$window, -role_pair_summary$total_attributed_ms), , drop = FALSE]

  utils::write.csv(sig_top, sig_path, row.names = FALSE, na = "")
  utils::write.csv(gap_agg, gap_path, row.names = FALSE, na = "")
  utils::write.csv(role_pair_summary, role_pair_path, row.names = FALSE, na = "")

  cat("VP_PERF_8I_CLIENT_READINESS_SPLIT_START\n")
  cat(sprintf("VP_PERF_8I_CLIENT_READINESS_SPLIT_LABEL=%s\n", label))
  cat(sprintf("VP_PERF_8I_CLIENT_READINESS_SPLIT_DETAIL=%s\n", normalizePath(detail_path, winslash = "/", mustWork = FALSE)))
  cat(sprintf("VP_PERF_8I_CLIENT_READINESS_SPLIT_RUNS=%s\n", normalizePath(runs_path, winslash = "/", mustWork = FALSE)))
  cat(sprintf("VP_PERF_8I_CLIENT_READINESS_SPLIT_INPUT_ROWS=%d\n", nrow(split_df)))
  cat(sprintf("VP_PERF_8I_CLIENT_READINESS_SPLIT_SIGNATURE_ROWS=%d\n", nrow(sig_top)))
  cat(sprintf("VP_PERF_8I_CLIENT_READINESS_SPLIT_GAP_CONTEXT_ROWS=%d\n", nrow(gap_agg)))
  cat(sprintf("VP_PERF_8I_CLIENT_READINESS_SPLIT_ROLE_PAIR_ROWS=%d\n", nrow(role_pair_summary)))
  cat(sprintf("VP_PERF_8I_CLIENT_READINESS_SPLIT_SIGNATURE_CSV=%s\n", normalizePath(sig_path, winslash = "/", mustWork = FALSE)))
  cat(sprintf("VP_PERF_8I_CLIENT_READINESS_SPLIT_GAP_CONTEXT_CSV=%s\n", normalizePath(gap_path, winslash = "/", mustWork = FALSE)))
  cat(sprintf("VP_PERF_8I_CLIENT_READINESS_SPLIT_ROLE_PAIR_CSV=%s\n", normalizePath(role_pair_path, winslash = "/", mustWork = FALSE)))
  cat("VP_PERF_8I_CLIENT_READINESS_SPLIT_COMPLETE\n")
}

main()
