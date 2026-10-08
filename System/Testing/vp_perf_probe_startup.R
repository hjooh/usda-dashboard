library(shinytest2)
source(file.path("System", "Testing", "vp_perf_acceptance_manifest.R"), local = TRUE)

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

normalize_cache_state <- function(value, default = "unknown_cache_state") {
  normalized <- trimws(as.character(value %||% default))
  if (!nzchar(normalized)) return(default)
  normalized
}

normalize_comparison_plot_cache_off <- function(value, default = FALSE) {
  isTRUE(is_truthy(value, default = default))
}

comparison_plot_cache_mode_from_flag <- function(cache_off) {
  if (isTRUE(cache_off)) "final_output_cache_off" else "final_output_cache_on"
}

is_unknown_cache_state <- function(value) {
  identical(tolower(normalize_cache_state(value)), "unknown_cache_state")
}

emit_probe <- function(key, value = NULL) {
  if (is.null(value)) {
    cat(sprintf("VP_PERF_STARTUP_%s\n", key))
  } else {
    cat(sprintf("VP_PERF_STARTUP_%s=%s\n", key, value))
  }
  flush.console()
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

  stop("Could not resolve repository root for VP startup probe.", call. = FALSE)
}

safe_file_mtime <- function(path) {
  if (!file.exists(path)) return(NA_character_)
  as.character(file.info(path)$mtime)
}

safe_file_size <- function(path) {
  if (!file.exists(path)) return(NA_real_)
  as.numeric(file.info(path)$size)
}

safe_dir_file_count <- function(path, pattern = NULL) {
  if (!dir.exists(path)) return(NA_integer_)
  length(list.files(path, pattern = pattern, full.names = TRUE, recursive = TRUE))
}

safe_rds_row_count <- function(path) {
  if (is.null(path) || !nzchar(path) || !file.exists(path)) return(NA_integer_)
  object <- tryCatch(readRDS(path), error = function(...) NULL)
  if (is.data.frame(object)) return(nrow(object))
  if (is.list(object)) return(length(object))
  NA_integer_
}

dom_exists <- function(app, id_value) {
  script <- sprintf(
    "(function(){ var id = '%s'; var docs=[document]; for (var i=0;i<window.frames.length;i++){ try{ if(window.frames[i].document) docs.push(window.frames[i].document);}catch(e){} } for (var j=0;j<docs.length;j++){ try{ if(docs[j].getElementById(id)!==null) return true; } catch(e){} } return false; })();",
    id_value
  )
  out <- tryCatch(app$get_js(script), error = function(...) FALSE)
  if (identical(out, TRUE)) return(TRUE)
  identical(tolower(trimws(as.character(out %||% ""))), "true")
}

get_input_value <- function(app, input_id) {
  script <- sprintf(
    "(function(){ var id='%s'; var docs=[document]; for (var i=0;i<window.frames.length;i++){ try{ if(window.frames[i].document) docs.push(window.frames[i].document);}catch(e){} } for (var j=0;j<docs.length;j++){ try{ var el=docs[j].getElementById(id); if(!el) continue; if (el.selectize && el.selectize.getValue) return String(el.selectize.getValue() || ''); if (typeof el.value !== 'undefined') return String(el.value || ''); }catch(e){} } return ''; })();",
    input_id
  )
  value <- tryCatch(as.character(app$get_js(script) %||% ""), error = function(...) "")
  value <- trimws(value[[1L]] %||% "")
  if (!nzchar(value)) return(NA_character_)
  value
}

get_main_tab_value <- function(app) {
  script <- "(function(){ var docs=[document]; for (var i=0;i<window.frames.length;i++){ try{ if(window.frames[i].document) docs.push(window.frames[i].document);}catch(e){} } for (var j=0;j<docs.length;j++){ try{ var doc=docs[j]; var input=doc.getElementById('main_tabs_panel'); if(input && typeof input.value !== 'undefined' && String(input.value || '').trim().length>0) return String(input.value || '').trim(); var root=doc.getElementById('main_tabs'); var scope=root || doc; var active=scope.querySelector('.tabbable > .nav > li.active > a, .tabbable > .nav-tabs > li.active > a, .nav > li.active > a, .nav-tabs > li.active > a'); if(active){ var dataValue=active.getAttribute('data-value'); if(dataValue && dataValue.trim().length>0) return dataValue.trim(); var text=(active.textContent || '').trim(); if(text.length>0) return text; } }catch(e){} } return ''; })();"
  value <- tryCatch(as.character(app$get_js(script) %||% ""), error = function(...) "")
  value <- trimws(value[[1L]] %||% "")
  if (!nzchar(value)) return(NA_character_)
  value
}

output_snapshot <- function(app, output_id) {
  script <- sprintf(
    "(function(){ var id='%s'; var docs=[document]; for (var i=0;i<window.frames.length;i++){ try{ if(window.frames[i].document) docs.push(window.frames[i].document);}catch(e){} } for (var j=0;j<docs.length;j++){ try{ var el=docs[j].getElementById(id); if(!el) continue; var rect=el.getBoundingClientRect(); var style=docs[j].defaultView.getComputedStyle(el); var visible=style.display!=='none' && style.visibility!=='hidden' && Number(style.opacity || 1)>0 && rect.width>0 && rect.height>0; var widgets=el.querySelectorAll('.plotly.html-widget,.html-widget').length; var text=(el.textContent || '').trim().length; return ['true', visible ? 'true' : 'false', Math.round(rect.width), Math.round(rect.height), widgets, text].join('|'); }catch(e){} } return 'false|false|0|0|0|0'; })();",
    output_id
  )
  raw <- tryCatch(as.character(app$get_js(script) %||% "false|false|0|0|0|0"), error = function(...) "false|false|0|0|0|0")
  parts <- strsplit(raw[[1L]], "|", fixed = TRUE)[[1L]]
  parts <- c(parts, rep("", 6L))[seq_len(6L)]
  list(
    present = identical(parts[[1L]], "true"),
    visible = identical(parts[[2L]], "true"),
    width = suppressWarnings(as.integer(parts[[3L]])),
    height = suppressWarnings(as.integer(parts[[4L]])),
    widget_count = suppressWarnings(as.integer(parts[[5L]])),
    text_length = suppressWarnings(as.integer(parts[[6L]]))
  )
}

soft_wait_for_idle <- function(app, timeout_ms) {
  wait_ok <- TRUE
  wait_message <- ""
  tryCatch(
    app$wait_for_idle(timeout = timeout_ms),
    error = function(error) {
      wait_ok <<- FALSE
      wait_message <<- conditionMessage(error)
    }
  )

  list(ok = wait_ok, message = gsub("\n", " | ", wait_message, fixed = TRUE))
}

wait_for_condition <- function(stage_name, timeout_ms, predicate, interval_ms = 500L) {
  emit_probe("STAGE_BEGIN", stage_name)
  stage_start <- Sys.time()
  ok <- FALSE
  message <- "timeout"

  repeat {
    check <- tryCatch(predicate(), error = function(error) {
      message <<- conditionMessage(error)
      FALSE
    })
    if (isTRUE(check)) {
      ok <- TRUE
      message <- "ok"
      break
    }
    if (to_int_ms(stage_start) >= timeout_ms) break
    Sys.sleep(max(interval_ms, 50L) / 1000)
  }

  result <- list(ok = isTRUE(ok), message = message, elapsed_ms = to_int_ms(stage_start))
  emit_probe("STAGE_END", paste0(stage_name, "|ok=", isTRUE(result$ok), "|elapsed_ms=", result$elapsed_ms))
  result
}

set_input_no_wait <- function(app, input_id, value) {
  args <- c(setNames(list(value), input_id), list(wait_ = FALSE))
  do.call(app$set_inputs, args)
}

timed_select_tab <- function(app, target_tab, timeout_ms) {
  emit_probe("STAGE_BEGIN", "select_current_vs_average")
  stage_start <- Sys.time()
  set_ok <- TRUE
  set_message <- ""
  tryCatch(
    set_input_no_wait(app, "main_tabs_panel", target_tab),
    error = function(error) {
      set_ok <<- FALSE
      set_message <<- conditionMessage(error)
    }
  )

  wait_result <- if (isTRUE(set_ok)) {
    wait_for_condition(
      "wait_current_vs_average_selected",
      timeout_ms = timeout_ms,
      predicate = function() identical(get_main_tab_value(app), target_tab)
    )
  } else {
    list(ok = FALSE, message = set_message, elapsed_ms = NA_integer_)
  }

  result <- list(
    elapsed_ms = to_int_ms(stage_start),
    set_ok = isTRUE(set_ok),
    set_message = gsub("\n", " | ", set_message, fixed = TRUE),
    wait_ok = isTRUE(wait_result$ok),
    wait_message = wait_result$message
  )
  emit_probe(
    "STAGE_END",
    paste0(
      "select_current_vs_average|set_ok=", isTRUE(result$set_ok),
      "|wait_ok=", isTRUE(result$wait_ok),
      "|elapsed_ms=", result$elapsed_ms
    )
  )
  result
}

find_runtime_logs <- function(logs_dir, start_time, end_time, requested_runtime_log_path = NULL) {
  paths <- list.files(logs_dir, pattern = "^vp_runtime_perf_.*\\.jsonl$", full.names = TRUE)
  if (!is.null(requested_runtime_log_path) && file.exists(requested_runtime_log_path)) {
    paths <- unique(c(paths, requested_runtime_log_path))
  }
  paths <- paths[file.exists(paths)]
  if (length(paths) == 0L) return(character(0))

  info <- file.info(paths)
  start_bound <- start_time - 10
  end_bound <- end_time + 60
  candidates <- paths[!is.na(info$mtime) & info$mtime >= start_bound & info$mtime <= end_bound]
  candidates <- candidates[order(file.info(candidates)$mtime)]
  normalizePath(candidates, winslash = "/", mustWork = FALSE)
}

safe_record_value <- function(record, field) {
  value <- record[[field]]
  if (is.null(value) || length(value) == 0L) return(NA_character_)
  as.character(value[[1L]])
}

read_json_record <- function(line) {
  if (!requireNamespace("jsonlite", quietly = TRUE)) return(NULL)
  tryCatch(jsonlite::fromJSON(line, simplifyVector = FALSE), error = function(...) NULL)
}

extract_client_perf <- function(paths) {
  empty <- list(
    main_tabs_mount_ms = NA_integer_,
    tab_after_paint_ms = NA_integer_,
    tab_shown_ms = NA_integer_,
    main_tabs_mount_tab = NA_character_,
    tab_after_paint_tab = NA_character_,
    tab_shown_tab = NA_character_,
    main_tabs_profile_count = NA_integer_
  )
  paths <- paths[file.exists(paths)]
  if (length(paths) == 0L || !requireNamespace("jsonlite", quietly = TRUE)) return(empty)

  records <- list()
  for (path in paths) {
    lines <- readLines(path, warn = FALSE)
    lines <- lines[nzchar(trimws(lines))]
    parsed <- lapply(lines, read_json_record)
    parsed <- parsed[!vapply(parsed, is.null, logical(1))]
    records <- c(records, parsed)
  }
  if (length(records) == 0L) return(empty)

  label_for <- function(record) {
    fields <- c(safe_record_value(record, "event"), safe_record_value(record, "tag"), safe_record_value(record, "name"))
    paste(fields[!is.na(fields) & nzchar(fields)], collapse = "|")
  }
  labels <- vapply(records, label_for, character(1))
  elapsed_for <- function(record) {
    elapsed_ms <- suppressWarnings(as.numeric(record$elapsed_ms %||% NA_real_))
    if (is.finite(elapsed_ms)) return(as.integer(round(elapsed_ms)))
    action_elapsed_ms <- suppressWarnings(as.numeric(record$action_elapsed_ms %||% NA_real_))
    if (is.finite(action_elapsed_ms)) return(as.integer(round(action_elapsed_ms)))
    NA_integer_
  }
  tab_for <- function(record) as.character(record$tab %||% record$main_tabs_panel %||% NA_character_)

  pick_last <- function(pattern) {
    hits <- grep(pattern, labels, fixed = TRUE)
    if (length(hits) == 0L) return(NULL)
    records[[hits[[length(hits)]]]]
  }

  mount_record <- pick_last("main_tabs_mount")
  paint_record <- pick_last("tab_after_paint")
  shown_record <- pick_last("tab_shown")
  profile_count <- length(grep("main_tabs_profile", labels, fixed = TRUE))

  list(
    main_tabs_mount_ms = if (is.null(mount_record)) NA_integer_ else elapsed_for(mount_record),
    tab_after_paint_ms = if (is.null(paint_record)) NA_integer_ else elapsed_for(paint_record),
    tab_shown_ms = if (is.null(shown_record)) NA_integer_ else elapsed_for(shown_record),
    main_tabs_mount_tab = if (is.null(mount_record)) NA_character_ else tab_for(mount_record),
    tab_after_paint_tab = if (is.null(paint_record)) NA_character_ else tab_for(paint_record),
    tab_shown_tab = if (is.null(shown_record)) NA_character_ else tab_for(shown_record),
    main_tabs_profile_count = profile_count
  )
}

run_probe <- function(app_dir, label, cache_state, logs_dir, runtime_enabled, perf_boundary_markers_enabled, stage_timeout_ms, startup_timeout_ms, output_timeout_ms, target_tab, test_vp_trade_artifact = "", acceptance_mode = FALSE, run_id = NA_character_, session_id = NA_character_, comparison_plot_cache_off = FALSE) {
  timestamp_token <- format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC")
  runtime_log_path <- file.path(logs_dir, paste0("vp_runtime_perf_startup_", label, "_", timestamp_token, ".jsonl"))
  artifact_path <- file.path(app_dir, "System", "Processed Data", "vp_trade_monthly_pre.rds")
  partition_dir <- file.path(app_dir, "System", "Processed Data", "vp_trade_partitions")
  test_vp_trade_artifact <- trimws(as.character(test_vp_trade_artifact %||% ""))
  test_vp_trade_artifact_path <- if (nzchar(test_vp_trade_artifact)) normalizePath(test_vp_trade_artifact, winslash = "/", mustWork = FALSE) else ""
  test_vp_trade_artifact_rows <- safe_rds_row_count(test_vp_trade_artifact_path)

  Sys.setenv(VP_PERF_RUNTIME = if (isTRUE(runtime_enabled)) "true" else "false")
  Sys.setenv(VP_PERF_RUNTIME_MEMORY_MODE = "off")
  Sys.setenv(VP_PERF_RUNTIME_LOG_FILE = normalizePath(runtime_log_path, winslash = "/", mustWork = FALSE))
  Sys.setenv(VP_PERF_BOUNDARY_MARKERS = if (isTRUE(perf_boundary_markers_enabled)) "true" else "false")
  Sys.setenv(VP_PERF_RUN_ID = as.character(run_id %||% ""))
  Sys.setenv(VP_PERF_SESSION_ID = as.character(session_id %||% ""))
  Sys.setenv(VP_PERF_PROBE_TYPE = "startup")
  Sys.setenv(VP_PERF_PROBE_LABEL = as.character(label %||% ""))
  Sys.setenv(VP_PERF_CACHE_STATE = as.character(cache_state %||% ""))
  Sys.setenv(VP_PERF_COMPARISON_PLOT_CACHE_OFF = if (isTRUE(comparison_plot_cache_off)) "true" else "false")
  Sys.setenv(NOT_CRAN = "true")
  if (nzchar(test_vp_trade_artifact_path)) {
    Sys.setenv(VP_PERF_TEST_ARTIFACT_OVERRIDE_ENABLED = "true")
    Sys.setenv(VP_PERF_TEST_VP_TRADE_ARTIFACT = test_vp_trade_artifact_path)
  } else {
    Sys.unsetenv("VP_PERF_TEST_ARTIFACT_OVERRIDE_ENABLED")
    Sys.unsetenv("VP_PERF_TEST_VP_TRADE_ARTIFACT")
  }
  options(
    vp_perf_runtime = isTRUE(runtime_enabled),
    vp_perf_boundary_markers = isTRUE(perf_boundary_markers_enabled),
    rice_perf_boundary_markers = isTRUE(perf_boundary_markers_enabled)
  )

  required_controls <- c("data_source_choice", "country_choice", "commodity_choice", "metric_choice", "main_tabs_panel")
  probe_start <- Sys.time()
  app_stopped <- FALSE

  emit_probe("STAGE_BEGIN", "appdriver_start")
  app <- shinytest2::AppDriver$new(
    app_dir = app_dir,
    name = paste0("vp_perf_startup_", label),
    load_timeout = startup_timeout_ms,
    timeout = max(startup_timeout_ms, stage_timeout_ms, output_timeout_ms)
  )
  emit_probe("STAGE_END", "appdriver_start")
  on.exit(if (!isTRUE(app_stopped)) try(app$stop(), silent = TRUE), add = TRUE)

  emit_probe("STAGE_BEGIN", "startup_wait")
  startup_wait <- soft_wait_for_idle(app, timeout_ms = startup_timeout_ms)
  emit_probe("STAGE_END", paste0("startup_wait|ok=", isTRUE(startup_wait$ok)))
  startup_to_ready_ms <- to_int_ms(probe_start)

  controls_wait <- wait_for_condition(
    "required_controls_present",
    timeout_ms = stage_timeout_ms,
    predicate = function() all(vapply(required_controls, function(id_value) dom_exists(app, id_value), logical(1)))
  )
  missing_controls <- required_controls[!vapply(required_controls, function(id_value) dom_exists(app, id_value), logical(1))]

  emit_probe("STAGE_BEGIN", "read_initial_state")
  initial_tab <- get_main_tab_value(app)
  initial_source <- get_input_value(app, "data_source_choice")
  emit_probe("STAGE_END", paste0("read_initial_state|tab=", initial_tab %||% ""))

  landed_on_target <- identical(initial_tab, target_tab)
  tab_stage <- if (isTRUE(landed_on_target)) {
    list(elapsed_ms = 0L, set_ok = TRUE, set_message = "already_selected", wait_ok = TRUE, wait_message = "already_selected")
  } else {
    timed_select_tab(app, target_tab = target_tab, timeout_ms = stage_timeout_ms)
  }

  output_wait <- wait_for_condition(
    "comparison_plot_visible",
    timeout_ms = output_timeout_ms,
    predicate = function() {
      snapshot <- output_snapshot(app, "comparison_plot")
      isTRUE(snapshot$present) && isTRUE(snapshot$visible)
    }
  )

  emit_probe("STAGE_BEGIN", "read_final_state")
  final_state_start <- Sys.time()
  final_tab <- get_main_tab_value(app)
  final_source <- get_input_value(app, "data_source_choice")
  comparison_snapshot <- output_snapshot(app, "comparison_plot")
  timeseries_snapshot <- output_snapshot(app, "timeseries_plot")
  heatmap_snapshot <- output_snapshot(app, "heatmap_plot")
  emit_probe("STAGE_END", paste0("read_final_state|elapsed_ms=", to_int_ms(final_state_start)))

  emit_probe("STAGE_BEGIN", "app_stop")
  try(app$stop(), silent = TRUE)
  app_stopped <- TRUE
  emit_probe("STAGE_END", "app_stop")

  probe_end <- Sys.time()
  runtime_log_candidates <- if (isTRUE(acceptance_mode)) {
    if (file.exists(runtime_log_path)) {
      normalizePath(runtime_log_path, winslash = "/", mustWork = FALSE)
    } else {
      character(0)
    }
  } else {
    find_runtime_logs(
      logs_dir = logs_dir,
      start_time = probe_start,
      end_time = probe_end,
      requested_runtime_log_path = runtime_log_path
    )
  }
  fallback_input <- paste(runtime_log_candidates, collapse = "|")
  client_perf <- extract_client_perf(runtime_log_candidates)

  final_tab_is_target <- identical(final_tab, target_tab)
  comparison_plot_present <- isTRUE(comparison_snapshot$present)
  comparison_plot_visible <- isTRUE(comparison_snapshot$visible)
  problems <- c(
    if (!isTRUE(startup_wait$ok)) paste("startup_wait_failed", startup_wait$message, sep = ":") else character(0),
    if (!isTRUE(controls_wait$ok)) paste("required_controls_wait_failed", controls_wait$message, sep = ":") else character(0),
    if (length(missing_controls) > 0L) paste("missing_controls", paste(missing_controls, collapse = "|"), sep = ":") else character(0),
    if (!isTRUE(tab_stage$set_ok)) paste("tab_set_failed", tab_stage$set_message, sep = ":") else character(0),
    if (!isTRUE(tab_stage$wait_ok)) paste("tab_wait_failed", tab_stage$wait_message, sep = ":") else character(0),
    if (!isTRUE(output_wait$ok)) paste("comparison_plot_wait_failed", output_wait$message, sep = ":") else character(0),
    if (!isTRUE(final_tab_is_target)) paste("final_tab_not_target", final_tab %||% "<null>", sep = ":") else character(0),
    if (!isTRUE(comparison_plot_present)) "comparison_plot_absent" else character(0),
    if (!isTRUE(comparison_plot_visible)) "comparison_plot_not_visible" else character(0)
  )
  problems <- problems[nzchar(problems)]

  base_status <- if (
    length(missing_controls) == 0L &&
      isTRUE(final_tab_is_target) &&
      isTRUE(comparison_plot_present) &&
      isTRUE(comparison_plot_visible) &&
      isTRUE(tab_stage$set_ok)
  ) {
    if (isTRUE(startup_wait$ok) && isTRUE(controls_wait$ok) && isTRUE(tab_stage$wait_ok) && isTRUE(output_wait$ok)) "PASS" else "PARTIAL"
  } else {
    "FAIL"
  }

  if (isTRUE(acceptance_mode) && identical(base_status, "PARTIAL")) {
    problems <- c(problems, "acceptance_mode_partial_disallowed")
  }
  if (isTRUE(acceptance_mode) && length(runtime_log_candidates) == 0L) {
    problems <- c(problems, "acceptance_mode_runtime_log_missing")
  }

  problems <- unique(problems[nzchar(problems)])
  status <- if (length(problems) == 0L && identical(base_status, "PASS")) "PASS" else "FAIL"

  data.frame(
    run_id = run_id,
    session_id = session_id,
    label = label,
    status = status,
    base_status = base_status,
    acceptance_mode = isTRUE(acceptance_mode),
    cache_state = cache_state,
    comparison_plot_cache_off = isTRUE(comparison_plot_cache_off),
    comparison_plot_cache_mode = comparison_plot_cache_mode_from_flag(comparison_plot_cache_off),
    comparison_plot_cache_mode_source = "probe_cli_env",
    final_output_bindcache_enabled = !isTRUE(comparison_plot_cache_off),
    error_message = if (length(problems) > 0L) paste(problems, collapse = " || ") else NA_character_,
    probe_start = as.character(probe_start),
    probe_end = as.character(probe_end),
    runtime_enabled = isTRUE(runtime_enabled),
    perf_boundary_markers_enabled = isTRUE(perf_boundary_markers_enabled),
    runtime_log_path = normalizePath(runtime_log_path, winslash = "/", mustWork = FALSE),
    runtime_log_exists = file.exists(runtime_log_path),
    acceptance_run_manifest = if (isTRUE(acceptance_mode)) normalizePath(runtime_log_path, winslash = "/", mustWork = FALSE) else NA_character_,
    runtime_log_candidates = fallback_input,
    runtime_log_candidates_count = length(runtime_log_candidates),
    fallback_input = fallback_input,
    artifact_path = normalizePath(artifact_path, winslash = "/", mustWork = FALSE),
    artifact_exists = file.exists(artifact_path),
    artifact_size_bytes = safe_file_size(artifact_path),
    artifact_mtime = safe_file_mtime(artifact_path),
    test_vp_trade_artifact_path = test_vp_trade_artifact_path,
    test_vp_trade_artifact_exists = nzchar(test_vp_trade_artifact_path) && file.exists(test_vp_trade_artifact_path),
    test_vp_trade_artifact_rows = test_vp_trade_artifact_rows,
    partition_dir = normalizePath(partition_dir, winslash = "/", mustWork = FALSE),
    partition_dir_exists = dir.exists(partition_dir),
    partition_file_count = safe_dir_file_count(partition_dir, pattern = "\\.rds$"),
    startup_to_ready_ms = startup_to_ready_ms,
    controls_present_ms = controls_wait$elapsed_ms,
    tab_switch_to_current_vs_average_ms = tab_stage$elapsed_ms,
    comparison_plot_visible_ms = output_wait$elapsed_ms,
    total_probe_ms = to_int_ms(probe_start, probe_end),
    startup_wait_ok = isTRUE(startup_wait$ok),
    controls_wait_ok = isTRUE(controls_wait$ok),
    tab_set_ok = isTRUE(tab_stage$set_ok),
    tab_wait_ok = isTRUE(tab_stage$wait_ok),
    output_wait_ok = isTRUE(output_wait$ok),
    target_tab = target_tab,
    initial_tab = initial_tab,
    landed_on_target_tab = isTRUE(landed_on_target),
    final_tab = final_tab,
    final_tab_is_target = isTRUE(final_tab_is_target),
    initial_source = initial_source,
    final_source = final_source,
    missing_controls = paste(missing_controls, collapse = "|"),
    comparison_plot_present = comparison_plot_present,
    comparison_plot_visible = comparison_plot_visible,
    comparison_plot_width = comparison_snapshot$width,
    comparison_plot_height = comparison_snapshot$height,
    comparison_plot_widget_count = comparison_snapshot$widget_count,
    comparison_plot_text_length = comparison_snapshot$text_length,
    timeseries_plot_present = isTRUE(timeseries_snapshot$present),
    timeseries_plot_visible = isTRUE(timeseries_snapshot$visible),
    heatmap_plot_present = isTRUE(heatmap_snapshot$present),
    heatmap_plot_visible = isTRUE(heatmap_snapshot$visible),
    client_perf_main_tabs_mount_ms = client_perf$main_tabs_mount_ms,
    client_perf_main_tabs_mount_tab = client_perf$main_tabs_mount_tab,
    client_perf_tab_after_paint_ms = client_perf$tab_after_paint_ms,
    client_perf_tab_after_paint_tab = client_perf$tab_after_paint_tab,
    client_perf_tab_shown_ms = client_perf$tab_shown_ms,
    client_perf_tab_shown_tab = client_perf$tab_shown_tab,
    client_perf_main_tabs_profile_count = client_perf$main_tabs_profile_count,
    stringsAsFactors = FALSE
  )
}

write_acceptance_manifest <- function(logs_dir, result, label, cache_state, target_tab, stage_timeout_ms, startup_timeout_ms, output_timeout_ms, args, runtime_enabled, test_vp_trade_artifact, manifest_path_arg = "") {
  if (!isTRUE(result$acceptance_mode[[1L]])) {
    return(list(manifest_csv = NA_character_, manifest_jsonl = NA_character_))
  }

  artifact_signature <- paste(
    c(
      as.character(result$artifact_path[[1L]] %||% ""),
      as.character(result$artifact_mtime[[1L]] %||% ""),
      as.character(result$artifact_size_bytes[[1L]] %||% "")
    ),
    collapse = "|"
  )

  row <- data.frame(
    created_at_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    probe_type = "startup",
    run_id = as.character(result$run_id[[1L]] %||% ""),
    session_id = as.character(result$session_id[[1L]] %||% ""),
    label = label,
    scenario = "startup_current_tab",
    acceptance_mode = isTRUE(result$acceptance_mode[[1L]]),
    cache_state = cache_state,
    comparison_plot_cache_off = isTRUE(result$comparison_plot_cache_off[[1L]]),
    comparison_plot_cache_mode = as.character(result$comparison_plot_cache_mode[[1L]] %||% comparison_plot_cache_mode_from_flag(FALSE)),
    comparison_plot_cache_mode_source = as.character(result$comparison_plot_cache_mode_source[[1L]] %||% "probe_cli_env"),
    final_output_bindcache_enabled = isTRUE(result$final_output_bindcache_enabled[[1L]]),
    status = as.character(result$status[[1L]] %||% ""),
    base_status = as.character(result$base_status[[1L]] %||% ""),
    provider_mode = vp_perf_detect_provider_mode(),
    runtime_enabled = isTRUE(runtime_enabled),
    perf_boundary_markers_enabled = isTRUE(result$perf_boundary_markers_enabled[[1L]]),
    runtime_log_path = as.character(result$runtime_log_path[[1L]] %||% ""),
    acceptance_run_manifest = as.character(result$acceptance_run_manifest[[1L]] %||% ""),
    runtime_log_candidates = as.character(result$runtime_log_candidates[[1L]] %||% ""),
    output_csv_path = as.character(result$output_csv_path[[1L]] %||% ""),
    probe_start = as.character(result$probe_start[[1L]] %||% ""),
    probe_end = as.character(result$probe_end[[1L]] %||% ""),
    target_tab = target_tab,
    stage_timeout_ms = as.integer(stage_timeout_ms),
    startup_timeout_ms = as.integer(startup_timeout_ms),
    output_timeout_ms = as.integer(output_timeout_ms),
    test_vp_trade_artifact = as.character(test_vp_trade_artifact %||% ""),
    test_vp_trade_artifact_path = as.character(result$test_vp_trade_artifact_path[[1L]] %||% ""),
    test_vp_trade_artifact_rows = as.character(result$test_vp_trade_artifact_rows[[1L]] %||% ""),
    artifact_signature = artifact_signature,
    artifact_path = as.character(result$artifact_path[[1L]] %||% ""),
    artifact_exists = as.logical(result$artifact_exists[[1L]] %||% FALSE),
    artifact_mtime = as.character(result$artifact_mtime[[1L]] %||% ""),
    artifact_size_bytes = as.character(result$artifact_size_bytes[[1L]] %||% ""),
    partition_dir = as.character(result$partition_dir[[1L]] %||% ""),
    partition_dir_exists = as.logical(result$partition_dir_exists[[1L]] %||% FALSE),
    partition_file_count = as.character(result$partition_file_count[[1L]] %||% ""),
    args = vp_perf_join_args(args),
    stringsAsFactors = FALSE
  )

  vp_perf_append_manifest_row(logs_dir = logs_dir, row_df = row, manifest_path_arg = manifest_path_arg)
}

failure_row <- function(label, cache_state, error_message, acceptance_mode = FALSE, run_id = NA_character_, session_id = NA_character_, comparison_plot_cache_off = FALSE) {
  data.frame(
    run_id = run_id,
    session_id = session_id,
    label = label,
    status = "FAIL",
    base_status = "FAIL",
    acceptance_mode = isTRUE(acceptance_mode),
    cache_state = cache_state,
    comparison_plot_cache_off = isTRUE(comparison_plot_cache_off),
    comparison_plot_cache_mode = comparison_plot_cache_mode_from_flag(comparison_plot_cache_off),
    comparison_plot_cache_mode_source = "probe_cli_env",
    final_output_bindcache_enabled = !isTRUE(comparison_plot_cache_off),
    error_message = error_message,
    runtime_log_path = NA_character_,
    acceptance_run_manifest = NA_character_,
    runtime_log_candidates = NA_character_,
    fallback_input = NA_character_,
    startup_to_ready_ms = NA_integer_,
    tab_switch_to_current_vs_average_ms = NA_integer_,
    comparison_plot_visible_ms = NA_integer_,
    total_probe_ms = NA_integer_,
    stringsAsFactors = FALSE
  )
}

main <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  label <- trimws(as.character(parse_arg_value(args, "label", default = "startup_current_settle")))
  if (!nzchar(label)) label <- "startup_current_settle"
  cache_state <- normalize_cache_state(parse_arg_value(args, "cache-state", default = "unknown_cache_state"))
  acceptance_mode <- is_truthy(parse_arg_value(args, "acceptance-mode", default = "false"), default = FALSE)
  if (isTRUE(acceptance_mode) && is_unknown_cache_state(cache_state)) {
    stop("Acceptance mode requires explicit --cache-state (not unknown_cache_state).", call. = FALSE)
  }

  timestamp_token <- format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC")
  run_id <- trimws(as.character(parse_arg_value(args, "run-id", default = "")))
  if (!nzchar(run_id)) run_id <- paste0("startup_", label, "_", timestamp_token)
  session_id <- trimws(as.character(parse_arg_value(args, "session-id", default = run_id)))
  if (!nzchar(session_id)) session_id <- run_id
  target_tab <- trimws(as.character(parse_arg_value(args, "target-tab", default = "Current vs. Average")))
  if (!nzchar(target_tab)) target_tab <- "Current vs. Average"
  test_vp_trade_artifact <- trimws(as.character(parse_arg_value(args, "test-vp-trade-artifact", default = "")))
  runtime_enabled <- is_truthy(parse_arg_value(args, "runtime-perf", default = "true"), default = TRUE)
  perf_boundary_markers_enabled <- is_truthy(parse_arg_value(args, "perf-boundary-markers", default = "false"), default = FALSE)
  comparison_plot_cache_off <- normalize_comparison_plot_cache_off(parse_arg_value(args, "comparison-plot-cache-off", default = "false"), default = FALSE)
  manifest_path_arg <- trimws(as.character(parse_arg_value(args, "acceptance-manifest", default = "")))
  stage_timeout_ms <- suppressWarnings(as.integer(parse_arg_value(args, "stage-timeout-ms", default = "30000")))
  startup_timeout_ms <- suppressWarnings(as.integer(parse_arg_value(args, "startup-timeout-ms", default = "120000")))
  output_timeout_ms <- suppressWarnings(as.integer(parse_arg_value(args, "output-timeout-ms", default = "30000")))
  if (!is.finite(stage_timeout_ms) || is.na(stage_timeout_ms) || stage_timeout_ms < 1000L) stage_timeout_ms <- 30000L
  if (!is.finite(startup_timeout_ms) || is.na(startup_timeout_ms) || startup_timeout_ms < 1000L) startup_timeout_ms <- 120000L
  if (!is.finite(output_timeout_ms) || is.na(output_timeout_ms) || output_timeout_ms < 1000L) output_timeout_ms <- 30000L

  repo_root <- resolve_repo_root(getwd())
  vp_clone_dir <- file.path(repo_root, "VP Clone")
  logs_dir <- file.path(vp_clone_dir, "Logs")
  dir.create(logs_dir, recursive = TRUE, showWarnings = FALSE)

  output_path <- file.path(logs_dir, paste0("vp_perf_probe_startup_", label, "_", timestamp_token, ".csv"))

  cat("VP_PERF_STARTUP_PROBE_START\n")
  cat(sprintf("VP_PERF_STARTUP_RUN_ID=%s\n", run_id))
  cat(sprintf("VP_PERF_STARTUP_SESSION_ID=%s\n", session_id))
  cat(sprintf("VP_PERF_STARTUP_LABEL=%s\n", label))
  cat(sprintf("VP_PERF_STARTUP_CACHE_STATE=%s\n", cache_state))
  cat(sprintf("VP_PERF_STARTUP_ACCEPTANCE_MODE=%s\n", if (isTRUE(acceptance_mode)) "TRUE" else "FALSE"))
  cat(sprintf("VP_PERF_STARTUP_RUNTIME_ENABLED=%s\n", if (isTRUE(runtime_enabled)) "TRUE" else "FALSE"))
  cat(sprintf("VP_PERF_STARTUP_PERF_BOUNDARY_MARKERS_ENABLED=%s\n", if (isTRUE(perf_boundary_markers_enabled)) "TRUE" else "FALSE"))
  cat(sprintf("VP_PERF_STARTUP_COMPARISON_PLOT_CACHE_OFF=%s\n", if (isTRUE(comparison_plot_cache_off)) "TRUE" else "FALSE"))
  cat(sprintf("VP_PERF_STARTUP_TARGET_TAB=%s\n", target_tab))

  if (!isTRUE(runtime_enabled)) {
    Sys.setenv(VP_PERF_RUNTIME = "false")
    options(vp_perf_runtime = FALSE)
  }

  result <- tryCatch(
    run_probe(
      app_dir = vp_clone_dir,
      label = label,
      cache_state = cache_state,
      logs_dir = logs_dir,
      runtime_enabled = runtime_enabled,
      perf_boundary_markers_enabled = perf_boundary_markers_enabled,
      stage_timeout_ms = stage_timeout_ms,
      startup_timeout_ms = startup_timeout_ms,
      output_timeout_ms = output_timeout_ms,
      target_tab = target_tab,
      test_vp_trade_artifact = test_vp_trade_artifact,
      acceptance_mode = acceptance_mode,
      run_id = run_id,
      session_id = session_id,
      comparison_plot_cache_off = comparison_plot_cache_off
    ),
    error = function(error) failure_row(label, cache_state, conditionMessage(error), acceptance_mode = acceptance_mode, run_id = run_id, session_id = session_id, comparison_plot_cache_off = comparison_plot_cache_off)
  )

  result$comparison_plot_cache_off <- isTRUE(comparison_plot_cache_off)
  result$comparison_plot_cache_mode <- comparison_plot_cache_mode_from_flag(comparison_plot_cache_off)
  result$comparison_plot_cache_mode_source <- "probe_cli_env"
  result$final_output_bindcache_enabled <- !isTRUE(comparison_plot_cache_off)

  result$output_csv_path <- normalizePath(output_path, winslash = "/", mustWork = FALSE)

  utils::write.csv(result, output_path, row.names = FALSE, na = "")

  manifest_write <- write_acceptance_manifest(
    logs_dir = logs_dir,
    result = result,
    label = label,
    cache_state = cache_state,
    target_tab = target_tab,
    stage_timeout_ms = stage_timeout_ms,
    startup_timeout_ms = startup_timeout_ms,
    output_timeout_ms = output_timeout_ms,
    args = args,
    runtime_enabled = runtime_enabled,
    test_vp_trade_artifact = test_vp_trade_artifact,
    manifest_path_arg = manifest_path_arg
  )

  cat(sprintf("VP_PERF_STARTUP_STATUS=%s\n", result$status[[1L]]))
  cat(sprintf("VP_PERF_STARTUP_OUTPUT=%s\n", normalizePath(output_path, winslash = "/", mustWork = FALSE)))
  cat(sprintf("VP_PERF_STARTUP_RUNTIME_LOG=%s\n", result$runtime_log_path[[1L]] %||% ""))
  cat(sprintf("VP_PERF_STARTUP_ACCEPTANCE_RUN_MANIFEST=%s\n", result$acceptance_run_manifest[[1L]] %||% ""))
  cat(sprintf("VP_PERF_STARTUP_ACCEPTANCE_MANIFEST_CSV=%s\n", manifest_write$manifest_csv %||% ""))
  cat(sprintf("VP_PERF_STARTUP_ACCEPTANCE_MANIFEST_JSONL=%s\n", manifest_write$manifest_jsonl %||% ""))
  cat(sprintf("VP_PERF_STARTUP_COMPARISON_PLOT_CACHE_MODE=%s\n", result$comparison_plot_cache_mode[[1L]] %||% comparison_plot_cache_mode_from_flag(FALSE)))
  cat(sprintf("VP_PERF_STARTUP_FALLBACK_INPUT=%s\n", result$fallback_input[[1L]] %||% ""))
  cat(sprintf("VP_PERF_STARTUP_TOTAL_MS=%s\n", result$total_probe_ms[[1L]] %||% NA_integer_))
  cat(sprintf("VP_PERF_STARTUP_STARTUP_READY_MS=%s\n", result$startup_to_ready_ms[[1L]] %||% NA_integer_))
  cat(sprintf("VP_PERF_STARTUP_TAB_SWITCH_MS=%s\n", result$tab_switch_to_current_vs_average_ms[[1L]] %||% NA_integer_))
  cat(sprintf("VP_PERF_STARTUP_OUTPUT_WAIT_MS=%s\n", result$comparison_plot_visible_ms[[1L]] %||% NA_integer_))
  if (!identical(result$status[[1L]], "PASS")) {
    cat(sprintf("VP_PERF_STARTUP_ERROR=%s\n", result$error_message[[1L]] %||% ""))
  }
  cat("VP_PERF_STARTUP_PROBE_COMPLETE\n")
}

main()