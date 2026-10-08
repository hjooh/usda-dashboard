library(shinytest2)

`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0L) y else x
}

to_int_ms <- function(start_time, end_time = Sys.time()) {
  elapsed_seconds <- suppressWarnings(as.numeric(difftime(end_time, start_time, units = "secs")))
  if (!is.finite(elapsed_seconds)) return(NA_integer_)
  as.integer(round(elapsed_seconds * 1000))
}

is_truthy <- function(value, default = FALSE) {
  if (is.null(value) || length(value) == 0L || all(is.na(value))) return(default)
  normalized <- tolower(trimws(as.character(value[[1L]])))
  if (!nzchar(normalized)) return(default)
  normalized %in% c("1", "true", "yes", "y", "on")
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
    if (file.exists(file.path(candidate, ".vp_clone_root"))) {
      parent_dir <- dirname(candidate)
      if (basename(candidate) == "VP Clone") {
        return(parent_dir)
      }
    }
  }

  stop("Could not resolve repository root for VP lightweight perf smoke.", call. = FALSE)
}

dom_exists <- function(app, id_value) {
  script <- sprintf(
    "(function(){ var id = '%s'; var docs=[document]; for (var i=0;i<window.frames.length;i++){ try{ if(window.frames[i].document) docs.push(window.frames[i].document);}catch(e){} } for (var j=0;j<docs.length;j++){ try{ if(docs[j].getElementById(id)!==null) return true; } catch(e){} } return false; })();",
    id_value
  )
  out <- app$get_js(script)
  if (identical(out, TRUE)) return(TRUE)
  out_chr <- tolower(trimws(as.character(out %||% "")))
  identical(out_chr, "true")
}

get_select_choices <- function(app, input_id) {
  script <- sprintf(
    "(function(){ var id='%s'; var docs=[document]; for (var i=0;i<window.frames.length;i++){ try{ if(window.frames[i].document) docs.push(window.frames[i].document);}catch(e){} } for (var j=0;j<docs.length;j++){ try{ var el=docs[j].getElementById(id); if(!el) continue; if (el.selectize && el.selectize.options) { var vals=Object.keys(el.selectize.options).map(function(x){ return (x || '').trim(); }).filter(function(x){ return x.length>0; }); return vals.join('|||'); } if (el.options) { var out=[]; for (var k=0;k<el.options.length;k++){ out.push((el.options[k].value || '').trim()); } return out.join('|||'); } }catch(e){} } return ''; })();",
    input_id
  )
  out <- as.character(app$get_js(script) %||% "")
  if (!nzchar(out)) return(character(0))
  values <- strsplit(out, "\\|\\|\\|", fixed = FALSE)[[1L]]
  values <- trimws(values)
  values[nzchar(values)]
}

get_input_value <- function(app, input_id) {
  values <- app$get_values(input = c(input_id))
  val <- values$input[[input_id]]
  if (is.null(val) || length(val) == 0L) return(NA_character_)
  as.character(val[[1L]])
}

set_input_and_wait <- function(app, input_id, value, timeout_ms = 120000L) {
  args <- c(setNames(list(value), input_id), list(wait_ = FALSE))
  do.call(app$set_inputs, args)
  app$wait_for_idle(timeout = timeout_ms)
}

assert_controls_present <- function(app, ids) {
  missing_ids <- ids[!vapply(ids, function(id_value) dom_exists(app, id_value), logical(1))]
  if (length(missing_ids) > 0L) {
    stop(sprintf("Missing expected controls: %s", paste(missing_ids, collapse = ", ")), call. = FALSE)
  }
}

pick_specific_choice <- function(choices, preferred = character(0), excluded = c("__all__", "All", "")) {
  candidate_values <- choices[!(choices %in% excluded)]
  for (preferred_value in preferred) {
    if (preferred_value %in% candidate_values) return(preferred_value)
  }
  if (length(candidate_values) == 0L) return(NA_character_)
  candidate_values[[1L]]
}

pick_alternative_choice <- function(choices, current_value = NA_character_) {
  if (length(choices) == 0L) return(NA_character_)
  if (!is.na(current_value)) {
    alternatives <- choices[choices != current_value]
    if (length(alternatives) > 0L) return(alternatives[[1L]])
  }
  choices[[1L]]
}

run_lightweight_scenario <- function(run_index, app_dir) {
  scenario_start <- Sys.time()
  app <- shinytest2::AppDriver$new(
    app_dir = app_dir,
    name = sprintf("vp_lightweight_perf_%02d", run_index),
    load_timeout = 120000,
    timeout = 120000
  )
  on.exit(try(app$stop(), silent = TRUE), add = TRUE)

  timed_step <- function(expr) {
    step_start <- Sys.time()
    force(expr)
    to_int_ms(step_start)
  }

  startup_ready_ms <- timed_step(app$wait_for_idle(timeout = 120000))

  assert_controls_present(
    app,
    c(
      "data_source_choice",
      "vp_trade_flow_choice",
      "vp_group_choice",
      "vp_subgroup_choice",
      "vp_market_segment_choice",
      "country_choice",
      "main_tabs_panel"
    )
  )

  source_switch_ms <- timed_step(set_input_and_wait(app, "data_source_choice", "vp_trade"))
  trade_flow_ms <- timed_step(set_input_and_wait(app, "vp_trade_flow_choice", "import"))

  hierarchy_start <- Sys.time()
  set_input_and_wait(app, "vp_group_choice", "__all__")
  set_input_and_wait(app, "vp_subgroup_choice", "__all__")
  set_input_and_wait(app, "vp_market_segment_choice", "__all__")

  group_choices <- get_select_choices(app, "vp_group_choice")
  group_target <- pick_specific_choice(group_choices, preferred = c("Dry pulses"))
  if (!is.na(group_target)) {
    set_input_and_wait(app, "vp_group_choice", group_target)
  }

  subgroup_choices <- get_select_choices(app, "vp_subgroup_choice")
  subgroup_target <- pick_specific_choice(subgroup_choices, preferred = c("Dried beans"))
  if (!is.na(subgroup_target)) {
    set_input_and_wait(app, "vp_subgroup_choice", subgroup_target)
  }

  segment_choices <- get_select_choices(app, "vp_market_segment_choice")
  segment_target <- pick_specific_choice(segment_choices, preferred = c("Dried"))
  if (!is.na(segment_target)) {
    set_input_and_wait(app, "vp_market_segment_choice", segment_target)
  }
  hierarchy_change_ms <- to_int_ms(hierarchy_start)

  country_refresh_ms <- timed_step({
    country_sort_choices <- get_select_choices(app, "country_sort")
    if (length(country_sort_choices) > 0L) {
      current_sort <- get_input_value(app, "country_sort")
      sort_target <- pick_alternative_choice(country_sort_choices, current_value = current_sort)
      if (!is.na(sort_target)) {
        set_input_and_wait(app, "country_sort", sort_target)
      }
    } else {
      current_country <- get_input_value(app, "country_choice")
      country_choices <- get_select_choices(app, "country_choice")
      country_target <- pick_alternative_choice(country_choices, current_value = current_country)
      if (!is.na(country_target)) {
        set_input_and_wait(app, "country_choice", country_target)
      }
    }
  })

  current_vs_average_ms <- timed_step({
    set_input_and_wait(app, "main_tabs_panel", "Current vs. Average")
    if (!dom_exists(app, "comparison_plot")) {
      stop("Current vs. Average tab did not expose comparison_plot output.", call. = FALSE)
    }
  })

  historical_trend_ms <- timed_step({
    set_input_and_wait(app, "main_tabs_panel", "Historical Trend")
    if (!dom_exists(app, "timeseries_plot")) {
      stop("Historical Trend tab did not expose timeseries_plot output.", call. = FALSE)
    }
  })

  heatmap_ms <- timed_step({
    set_input_and_wait(app, "main_tabs_panel", "Heatmap")
    if (!dom_exists(app, "heatmap_plot")) {
      stop("Heatmap tab did not expose heatmap_plot output.", call. = FALSE)
    }
  })

  resolved_group <- get_input_value(app, "vp_group_choice")
  resolved_subgroup <- get_input_value(app, "vp_subgroup_choice")
  resolved_segment <- get_input_value(app, "vp_market_segment_choice")
  resolved_path_ok <- all(c(resolved_group, resolved_subgroup, resolved_segment) != "__all__")

  data.frame(
    run_index = run_index,
    status = "PASS",
    error_message = NA_character_,
    startup_ready_ms = startup_ready_ms,
    source_switch_ms = source_switch_ms,
    trade_flow_ms = trade_flow_ms,
    hierarchy_change_ms = hierarchy_change_ms,
    country_refresh_ms = country_refresh_ms,
    current_vs_average_ms = current_vs_average_ms,
    historical_trend_ms = historical_trend_ms,
    heatmap_ms = heatmap_ms,
    total_scenario_ms = to_int_ms(scenario_start),
    resolved_group = resolved_group,
    resolved_subgroup = resolved_subgroup,
    resolved_segment = resolved_segment,
    resolved_path_ok = isTRUE(resolved_path_ok),
    stringsAsFactors = FALSE
  )
}

run_scenario_safe <- function(run_index, app_dir) {
  tryCatch(
    run_lightweight_scenario(run_index, app_dir),
    error = function(e) {
      data.frame(
        run_index = run_index,
        status = "FAIL",
        error_message = as.character(conditionMessage(e)),
        startup_ready_ms = NA_integer_,
        source_switch_ms = NA_integer_,
        trade_flow_ms = NA_integer_,
        hierarchy_change_ms = NA_integer_,
        country_refresh_ms = NA_integer_,
        current_vs_average_ms = NA_integer_,
        historical_trend_ms = NA_integer_,
        heatmap_ms = NA_integer_,
        total_scenario_ms = NA_integer_,
        resolved_group = NA_character_,
        resolved_subgroup = NA_character_,
        resolved_segment = NA_character_,
        resolved_path_ok = FALSE,
        stringsAsFactors = FALSE
      )
    }
  )
}

build_summary_table <- function(raw_rows) {
  metric_cols <- c(
    "startup_ready_ms",
    "source_switch_ms",
    "trade_flow_ms",
    "hierarchy_change_ms",
    "country_refresh_ms",
    "current_vs_average_ms",
    "historical_trend_ms",
    "heatmap_ms",
    "total_scenario_ms"
  )

  summary_rows <- lapply(metric_cols, function(metric_name) {
    values <- suppressWarnings(as.numeric(raw_rows[[metric_name]]))
    values <- values[is.finite(values)]
    data.frame(
      metric = metric_name,
      run_count = length(values),
      median_ms = if (length(values) > 0L) as.numeric(stats::median(values, na.rm = TRUE)) else NA_real_,
      min_ms = if (length(values) > 0L) as.numeric(min(values, na.rm = TRUE)) else NA_real_,
      max_ms = if (length(values) > 0L) as.numeric(max(values, na.rm = TRUE)) else NA_real_,
      stringsAsFactors = FALSE
    )
  })

  summary_df <- do.call(rbind, summary_rows)
  summary_df$pass_runs <- sum(raw_rows$status == "PASS", na.rm = TRUE)
  summary_df$fail_runs <- sum(raw_rows$status == "FAIL", na.rm = TRUE)
  summary_df
}

main <- function() {
  args <- commandArgs(trailingOnly = TRUE)

  runs <- suppressWarnings(as.integer(parse_arg_value(args, "runs", default = "1")))
  if (!is.finite(runs) || is.na(runs) || runs < 1L) {
    stop("--runs must be a positive integer.", call. = FALSE)
  }

  enable_runtime <- is_truthy(parse_arg_value(args, "runtime-perf", default = "true"), default = TRUE)
  scenario_label <- trimws(as.character(parse_arg_value(args, "label", default = "baseline")))
  if (!nzchar(scenario_label)) scenario_label <- "baseline"

  repo_root <- resolve_repo_root(getwd())
  vp_clone_dir <- file.path(repo_root, "VP Clone")
  if (!dir.exists(vp_clone_dir)) {
    stop("Could not locate VP Clone directory from resolved repository root.", call. = FALSE)
  }

  if (isTRUE(enable_runtime)) {
    Sys.setenv(VP_PERF_RUNTIME = "true")
    options(vp_perf_runtime = TRUE)
  }

  logs_dir <- file.path(vp_clone_dir, "Logs")
  dir.create(logs_dir, recursive = TRUE, showWarnings = FALSE)
  timestamp_token <- format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC")
  raw_path <- file.path(logs_dir, paste0("vp_lightweight_perf_raw_", scenario_label, "_", timestamp_token, ".csv"))
  summary_path <- file.path(logs_dir, paste0("vp_lightweight_perf_summary_", scenario_label, "_", timestamp_token, ".csv"))

  cat("VP_LIGHTWEIGHT_PERF_START\n")
  cat(sprintf("VP_LIGHTWEIGHT_PERF_RUNS=%d\n", runs))
  cat(sprintf("VP_LIGHTWEIGHT_PERF_LABEL=%s\n", scenario_label))
  cat(sprintf("VP_LIGHTWEIGHT_PERF_RUNTIME_ENABLED=%s\n", if (isTRUE(enable_runtime)) "TRUE" else "FALSE"))

  run_rows <- vector("list", runs)
  for (run_index in seq_len(runs)) {
    cat(sprintf("VP_LIGHTWEIGHT_PERF_RUN_BEGIN=%d\n", run_index))
    run_rows[[run_index]] <- run_scenario_safe(run_index, app_dir = vp_clone_dir)
    cat(sprintf("VP_LIGHTWEIGHT_PERF_RUN_STATUS=%d|%s\n", run_index, run_rows[[run_index]]$status[[1L]]))
    if (identical(run_rows[[run_index]]$status[[1L]], "FAIL")) {
      cat(sprintf("VP_LIGHTWEIGHT_PERF_RUN_ERROR=%d|%s\n", run_index, run_rows[[run_index]]$error_message[[1L]]))
    }
  }

  raw_df <- do.call(rbind, run_rows)
  summary_df <- build_summary_table(raw_df)

  utils::write.csv(raw_df, raw_path, row.names = FALSE)
  utils::write.csv(summary_df, summary_path, row.names = FALSE)

  cat(sprintf("VP_LIGHTWEIGHT_PERF_RAW=%s\n", raw_path))
  cat(sprintf("VP_LIGHTWEIGHT_PERF_SUMMARY=%s\n", summary_path))
  cat(sprintf("VP_LIGHTWEIGHT_PERF_PASS_RUNS=%d\n", sum(raw_df$status == "PASS", na.rm = TRUE)))
  cat(sprintf("VP_LIGHTWEIGHT_PERF_FAIL_RUNS=%d\n", sum(raw_df$status == "FAIL", na.rm = TRUE)))
  cat("VP_LIGHTWEIGHT_PERF_COMPLETE\n")
}

main()