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

emit_probe <- function(key, value = NULL) {
  if (is.null(value)) {
    cat(sprintf("VP_PERF_TAB_FILTER_%s\n", key))
  } else {
    cat(sprintf("VP_PERF_TAB_FILTER_%s=%s\n", key, value))
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

  stop("Could not resolve repository root for VP tab/filter probe.", call. = FALSE)
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

get_select_choices <- function(app, input_id) {
  script <- sprintf(
    "(function(){ var id='%s'; var docs=[document]; for (var i=0;i<window.frames.length;i++){ try{ if(window.frames[i].document) docs.push(window.frames[i].document);}catch(e){} } for (var j=0;j<docs.length;j++){ try{ var el=docs[j].getElementById(id); if(!el) continue; if (el.selectize && el.selectize.options) { var vals=Object.keys(el.selectize.options).map(function(x){ return (x || '').trim(); }).filter(function(x){ return x.length>0; }); return vals.join('|||'); } if (el.options) { var out=[]; for (var k=0;k<el.options.length;k++){ out.push((el.options[k].value || '').trim()); } return out.join('|||'); } }catch(e){} } return ''; })();",
    input_id
  )
  out <- tryCatch(as.character(app$get_js(script) %||% ""), error = function(...) "")
  if (!nzchar(out)) return(character(0))
  values <- strsplit(out, "\\|\\|\\|", fixed = FALSE)[[1L]]
  values <- trimws(values)
  values[nzchar(values)]
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
    "(function(){ var id='%s'; var docs=[document]; for (var i=0;i<window.frames.length;i++){ try{ if(window.frames[i].document) docs.push(window.frames[i].document);}catch(e){} } for (var j=0;j<docs.length;j++){ try{ var el=docs[j].getElementById(id); if(!el) continue; var rect=el.getBoundingClientRect(); var style=docs[j].defaultView.getComputedStyle(el); var visible=style.display!=='none' && style.visibility!=='hidden' && Number(style.opacity || 1)>0 && rect.width>0 && rect.height>0; var widgets=el.querySelectorAll('.plotly.html-widget,.html-widget,.dataTables_wrapper,table.dataTable').length; var text=(el.textContent || '').trim().length; return ['true', visible ? 'true' : 'false', Math.round(rect.width), Math.round(rect.height), widgets, text].join('|'); }catch(e){} } return 'false|false|0|0|0|0'; })();",
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

timed_set_input <- function(app, stage_name, input_id, value, timeout_ms) {
  emit_probe("STAGE_BEGIN", stage_name)
  stage_start <- Sys.time()
  set_ok <- TRUE
  set_message <- ""
  wait_result <- list(ok = NA, message = "not_started")

  tryCatch(
    set_input_no_wait(app, input_id, value),
    error = function(error) {
      set_ok <<- FALSE
      set_message <<- conditionMessage(error)
    }
  )

  if (isTRUE(set_ok)) {
    wait_result <- soft_wait_for_idle(app, timeout_ms = timeout_ms)
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
      stage_name,
      "|set_ok=", isTRUE(result$set_ok),
      "|wait_ok=", isTRUE(result$wait_ok),
      "|elapsed_ms=", result$elapsed_ms
    )
  )
  result
}

timed_select_tab <- function(app, stage_name, target_tab, output_id, timeout_ms, output_timeout_ms) {
  emit_probe("STAGE_BEGIN", stage_name)
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

  tab_wait <- if (isTRUE(set_ok)) {
    wait_for_condition(
      paste0(stage_name, "_selected"),
      timeout_ms = timeout_ms,
      predicate = function() identical(get_main_tab_value(app), target_tab)
    )
  } else {
    list(ok = FALSE, message = set_message, elapsed_ms = NA_integer_)
  }

  output_wait <- if (isTRUE(set_ok) && isTRUE(tab_wait$ok)) {
    wait_for_condition(
      paste0(stage_name, "_output_ready"),
      timeout_ms = output_timeout_ms,
      predicate = function() {
        snapshot <- output_snapshot(app, output_id)
        isTRUE(snapshot$present) && isTRUE(snapshot$visible)
      }
    )
  } else {
    list(ok = FALSE, message = "tab_not_selected", elapsed_ms = NA_integer_)
  }

  snapshot <- output_snapshot(app, output_id)
  result <- list(
    elapsed_ms = to_int_ms(stage_start),
    set_ok = isTRUE(set_ok),
    set_message = gsub("\n", " | ", set_message, fixed = TRUE),
    tab_wait_ok = isTRUE(tab_wait$ok),
    tab_wait_message = tab_wait$message,
    output_wait_ok = isTRUE(output_wait$ok),
    output_wait_message = output_wait$message,
    output_present = isTRUE(snapshot$present),
    output_visible = isTRUE(snapshot$visible),
    output_width = snapshot$width,
    output_height = snapshot$height,
    output_widget_count = snapshot$widget_count,
    output_text_length = snapshot$text_length,
    final_tab = get_main_tab_value(app)
  )
  emit_probe(
    "STAGE_END",
    paste0(
      stage_name,
      "|set_ok=", isTRUE(result$set_ok),
      "|tab_wait_ok=", isTRUE(result$tab_wait_ok),
      "|output_wait_ok=", isTRUE(result$output_wait_ok),
      "|elapsed_ms=", result$elapsed_ms
    )
  )
  result
}

pick_specific_choice <- function(choices, preferred = character(0), excluded = c("__all__", "All", "")) {
  candidate_values <- choices[!(choices %in% excluded)]
  for (preferred_value in preferred) {
    if (preferred_value %in% candidate_values) return(preferred_value)
  }
  if (length(candidate_values) == 0L) return(NA_character_)
  candidate_values[[1L]]
}

stage_problem <- function(stage_name, stage_result) {
  problems <- character(0)
  if (!isTRUE(stage_result$set_ok)) {
    problems <- c(problems, paste(stage_name, "set_failed", stage_result$set_message, sep = ":"))
  }
  if (!isTRUE(stage_result$wait_ok)) {
    problems <- c(problems, paste(stage_name, "wait_failed", stage_result$wait_message, sep = ":"))
  }
  problems
}

tab_problem <- function(stage_name, stage_result) {
  problems <- character(0)
  if (!isTRUE(stage_result$set_ok)) {
    problems <- c(problems, paste(stage_name, "set_failed", stage_result$set_message, sep = ":"))
  }
  if (!isTRUE(stage_result$tab_wait_ok)) {
    problems <- c(problems, paste(stage_name, "tab_wait_failed", stage_result$tab_wait_message, sep = ":"))
  }
  if (!isTRUE(stage_result$output_wait_ok)) {
    problems <- c(problems, paste(stage_name, "output_wait_failed", stage_result$output_wait_message, sep = ":"))
  }
  problems
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

run_probe <- function(app_dir, label, cache_state, logs_dir, runtime_enabled, stage_timeout_ms, startup_timeout_ms, output_timeout_ms) {
  timestamp_token <- format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC")
  runtime_log_path <- file.path(logs_dir, paste0("vp_runtime_perf_tab_filter_", label, "_", timestamp_token, ".jsonl"))
  Sys.setenv(VP_PERF_RUNTIME = if (isTRUE(runtime_enabled)) "true" else "false")
  Sys.setenv(VP_PERF_RUNTIME_MEMORY_MODE = "off")
  Sys.setenv(VP_PERF_RUNTIME_LOG_FILE = normalizePath(runtime_log_path, winslash = "/", mustWork = FALSE))
  Sys.setenv(NOT_CRAN = "true")
  options(vp_perf_runtime = isTRUE(runtime_enabled))

  required_controls <- c(
    "data_source_choice",
    "vp_trade_flow_choice",
    "vp_group_choice",
    "vp_subgroup_choice",
    "vp_market_segment_choice",
    "country_choice",
    "commodity_choice",
    "metric_choice",
    "main_tabs_panel"
  )

  probe_start <- Sys.time()
  app_stopped <- FALSE
  emit_probe("STAGE_BEGIN", "appdriver_start")
  app <- shinytest2::AppDriver$new(
    app_dir = app_dir,
    name = paste0("vp_perf_tab_filter_", label),
    load_timeout = startup_timeout_ms,
    timeout = max(startup_timeout_ms, stage_timeout_ms, output_timeout_ms)
  )
  emit_probe("STAGE_END", "appdriver_start")
  on.exit(if (!isTRUE(app_stopped)) try(app$stop(), silent = TRUE), add = TRUE)

  emit_probe("STAGE_BEGIN", "startup_wait")
  startup_wait <- soft_wait_for_idle(app, timeout_ms = startup_timeout_ms)
  emit_probe("STAGE_END", paste0("startup_wait|ok=", isTRUE(startup_wait$ok)))
  startup_ready_ms <- to_int_ms(probe_start)

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

  source_stage <- timed_set_input(app, "source_switch", "data_source_choice", "vp_trade", timeout_ms = stage_timeout_ms)
  current_stage <- timed_select_tab(app, "tab_current_after_source", "Current vs. Average", "comparison_plot", timeout_ms = stage_timeout_ms, output_timeout_ms = output_timeout_ms)
  trade_stage <- timed_set_input(app, "trade_flow", "vp_trade_flow_choice", "import", timeout_ms = stage_timeout_ms)

  hierarchy_start <- Sys.time()
  group_reset_stage <- timed_set_input(app, "group_reset", "vp_group_choice", "__all__", timeout_ms = stage_timeout_ms)
  subgroup_reset_stage <- timed_set_input(app, "subgroup_reset", "vp_subgroup_choice", "__all__", timeout_ms = stage_timeout_ms)
  segment_reset_stage <- timed_set_input(app, "segment_reset", "vp_market_segment_choice", "__all__", timeout_ms = stage_timeout_ms)

  emit_probe("STAGE_BEGIN", "read_group_choices")
  group_choices <- get_select_choices(app, "vp_group_choice")
  group_target <- pick_specific_choice(group_choices, preferred = c("Dry pulses"))
  emit_probe("STAGE_END", paste0("read_group_choices|choices=", length(group_choices)))
  group_stage <- if (!is.na(group_target)) {
    timed_set_input(app, "group_choice", "vp_group_choice", group_target, timeout_ms = stage_timeout_ms)
  } else {
    list(elapsed_ms = NA_integer_, set_ok = FALSE, set_message = "No non-all group target", wait_ok = FALSE, wait_message = "not_started")
  }

  emit_probe("STAGE_BEGIN", "read_subgroup_choices")
  subgroup_choices <- get_select_choices(app, "vp_subgroup_choice")
  subgroup_target <- pick_specific_choice(subgroup_choices, preferred = c("Dried beans"))
  emit_probe("STAGE_END", paste0("read_subgroup_choices|choices=", length(subgroup_choices)))
  subgroup_stage <- if (!is.na(subgroup_target)) {
    timed_set_input(app, "subgroup_choice", "vp_subgroup_choice", subgroup_target, timeout_ms = stage_timeout_ms)
  } else {
    list(elapsed_ms = NA_integer_, set_ok = FALSE, set_message = "No non-all subgroup target", wait_ok = FALSE, wait_message = "not_started")
  }

  emit_probe("STAGE_BEGIN", "read_segment_choices")
  segment_choices <- get_select_choices(app, "vp_market_segment_choice")
  segment_target <- pick_specific_choice(segment_choices, preferred = c("Dried"))
  emit_probe("STAGE_END", paste0("read_segment_choices|choices=", length(segment_choices)))
  segment_stage <- if (!is.na(segment_target)) {
    timed_set_input(app, "segment_choice", "vp_market_segment_choice", segment_target, timeout_ms = stage_timeout_ms)
  } else {
    list(elapsed_ms = NA_integer_, set_ok = FALSE, set_message = "No non-all segment target", wait_ok = FALSE, wait_message = "not_started")
  }
  hierarchy_change_ms <- to_int_ms(hierarchy_start)

  current_after_filter_stage <- timed_select_tab(app, "tab_current_after_filter", "Current vs. Average", "comparison_plot", timeout_ms = stage_timeout_ms, output_timeout_ms = output_timeout_ms)
  trend_stage <- timed_select_tab(app, "tab_historical_trend", "Historical Trend", "timeseries_plot", timeout_ms = stage_timeout_ms, output_timeout_ms = output_timeout_ms)
  heatmap_stage <- timed_select_tab(app, "tab_heatmap", "Heatmap", "heatmap_plot", timeout_ms = stage_timeout_ms, output_timeout_ms = output_timeout_ms)
  map_stage <- timed_select_tab(app, "tab_map", "Map", "map_plot", timeout_ms = stage_timeout_ms, output_timeout_ms = output_timeout_ms)
  return_current_stage <- timed_select_tab(app, "tab_return_current", "Current vs. Average", "comparison_plot", timeout_ms = stage_timeout_ms, output_timeout_ms = output_timeout_ms)

  emit_probe("STAGE_BEGIN", "read_final_state")
  final_state_start <- Sys.time()
  resolved_group <- get_input_value(app, "vp_group_choice")
  resolved_subgroup <- get_input_value(app, "vp_subgroup_choice")
  resolved_segment <- get_input_value(app, "vp_market_segment_choice")
  resolved_trade_flow <- get_input_value(app, "vp_trade_flow_choice")
  resolved_source <- get_input_value(app, "data_source_choice")
  final_tab <- get_main_tab_value(app)
  comparison_snapshot <- output_snapshot(app, "comparison_plot")
  summary_snapshot <- output_snapshot(app, "summary_table")
  timeseries_snapshot <- output_snapshot(app, "timeseries_plot")
  heatmap_snapshot <- output_snapshot(app, "heatmap_plot")
  map_snapshot <- output_snapshot(app, "map_plot")
  map_bottom_snapshot <- output_snapshot(app, "map_bottom_panel_ui")
  emit_probe("STAGE_END", paste0("read_final_state|elapsed_ms=", to_int_ms(final_state_start)))

  emit_probe("STAGE_BEGIN", "app_stop")
  try(app$stop(), silent = TRUE)
  app_stopped <- TRUE
  emit_probe("STAGE_END", "app_stop")

  probe_end <- Sys.time()
  runtime_log_candidates <- find_runtime_logs(
    logs_dir = logs_dir,
    start_time = probe_start,
    end_time = probe_end,
    requested_runtime_log_path = runtime_log_path
  )
  fallback_input <- paste(runtime_log_candidates, collapse = "|")
  resolved_path_ok <- all(c(resolved_group, resolved_subgroup, resolved_segment) != "__all__")
  final_tab_is_current <- identical(final_tab, "Current vs. Average")

  problems <- c(
    if (!isTRUE(startup_wait$ok)) paste("startup_wait_failed", startup_wait$message, sep = ":") else character(0),
    if (!isTRUE(controls_wait$ok)) paste("required_controls_wait_failed", controls_wait$message, sep = ":") else character(0),
    if (length(missing_controls) > 0L) paste("missing_controls", paste(missing_controls, collapse = "|"), sep = ":") else character(0),
    stage_problem("source_switch", source_stage),
    stage_problem("trade_flow", trade_stage),
    stage_problem("group_reset", group_reset_stage),
    stage_problem("subgroup_reset", subgroup_reset_stage),
    stage_problem("segment_reset", segment_reset_stage),
    stage_problem("group_choice", group_stage),
    stage_problem("subgroup_choice", subgroup_stage),
    stage_problem("segment_choice", segment_stage),
    tab_problem("tab_current_after_source", current_stage),
    tab_problem("tab_current_after_filter", current_after_filter_stage),
    tab_problem("tab_historical_trend", trend_stage),
    tab_problem("tab_heatmap", heatmap_stage),
    tab_problem("tab_map", map_stage),
    tab_problem("tab_return_current", return_current_stage),
    if (!isTRUE(resolved_path_ok)) "resolved_path_not_specific" else character(0),
    if (!isTRUE(final_tab_is_current)) paste("final_tab_not_current", final_tab %||% "<null>", sep = ":") else character(0)
  )
  problems <- problems[nzchar(problems)]

  set_stages_ok <- all(vapply(
    list(source_stage, trade_stage, group_reset_stage, subgroup_reset_stage, segment_reset_stage, group_stage, subgroup_stage, segment_stage),
    function(stage_result) isTRUE(stage_result$set_ok),
    logical(1)
  ))
  tab_stages_ok <- all(vapply(
    list(current_stage, current_after_filter_stage, trend_stage, heatmap_stage, map_stage, return_current_stage),
    function(stage_result) isTRUE(stage_result$set_ok) && isTRUE(stage_result$tab_wait_ok) && isTRUE(stage_result$output_wait_ok),
    logical(1)
  ))
  wait_stages_ok <- isTRUE(startup_wait$ok) && isTRUE(controls_wait$ok) && all(vapply(
    list(source_stage, trade_stage, group_reset_stage, subgroup_reset_stage, segment_reset_stage, group_stage, subgroup_stage, segment_stage),
    function(stage_result) isTRUE(stage_result$wait_ok),
    logical(1)
  )) && isTRUE(tab_stages_ok)

  status <- if (isTRUE(set_stages_ok) && isTRUE(resolved_path_ok) && length(missing_controls) == 0L && isTRUE(final_tab_is_current)) {
    if (isTRUE(wait_stages_ok)) "PASS" else "PARTIAL"
  } else {
    "FAIL"
  }

  data.frame(
    label = label,
    status = status,
    cache_state = cache_state,
    error_message = if (length(problems) > 0L) paste(problems, collapse = " || ") else NA_character_,
    probe_start = as.character(probe_start),
    probe_end = as.character(probe_end),
    runtime_enabled = isTRUE(runtime_enabled),
    runtime_log_path = normalizePath(runtime_log_path, winslash = "/", mustWork = FALSE),
    runtime_log_exists = file.exists(runtime_log_path),
    runtime_log_candidates = fallback_input,
    runtime_log_candidates_count = length(runtime_log_candidates),
    fallback_input = fallback_input,
    startup_ready_ms = startup_ready_ms,
    source_switch_ms = source_stage$elapsed_ms,
    trade_flow_ms = trade_stage$elapsed_ms,
    hierarchy_change_ms = hierarchy_change_ms,
    tab_current_after_source_ms = current_stage$elapsed_ms,
    tab_current_after_filter_ms = current_after_filter_stage$elapsed_ms,
    tab_historical_trend_ms = trend_stage$elapsed_ms,
    tab_heatmap_ms = heatmap_stage$elapsed_ms,
    tab_map_ms = map_stage$elapsed_ms,
    tab_return_current_ms = return_current_stage$elapsed_ms,
    total_probe_ms = to_int_ms(probe_start, probe_end),
    startup_wait_ok = isTRUE(startup_wait$ok),
    controls_wait_ok = isTRUE(controls_wait$ok),
    source_wait_ok = isTRUE(source_stage$wait_ok),
    trade_wait_ok = isTRUE(trade_stage$wait_ok),
    group_reset_wait_ok = isTRUE(group_reset_stage$wait_ok),
    subgroup_reset_wait_ok = isTRUE(subgroup_reset_stage$wait_ok),
    segment_reset_wait_ok = isTRUE(segment_reset_stage$wait_ok),
    group_wait_ok = isTRUE(group_stage$wait_ok),
    subgroup_wait_ok = isTRUE(subgroup_stage$wait_ok),
    segment_wait_ok = isTRUE(segment_stage$wait_ok),
    current_after_source_output_wait_ok = isTRUE(current_stage$output_wait_ok),
    current_after_filter_output_wait_ok = isTRUE(current_after_filter_stage$output_wait_ok),
    historical_trend_output_wait_ok = isTRUE(trend_stage$output_wait_ok),
    heatmap_output_wait_ok = isTRUE(heatmap_stage$output_wait_ok),
    map_output_wait_ok = isTRUE(map_stage$output_wait_ok),
    return_current_output_wait_ok = isTRUE(return_current_stage$output_wait_ok),
    missing_controls = paste(missing_controls, collapse = "|"),
    initial_source = initial_source,
    resolved_source = resolved_source,
    resolved_trade_flow = resolved_trade_flow,
    resolved_group = resolved_group,
    resolved_subgroup = resolved_subgroup,
    resolved_segment = resolved_segment,
    resolved_path_ok = isTRUE(resolved_path_ok),
    initial_tab = initial_tab,
    final_tab = final_tab,
    final_tab_is_current = isTRUE(final_tab_is_current),
    group_choices_count = length(group_choices),
    subgroup_choices_count = length(subgroup_choices),
    segment_choices_count = length(segment_choices),
    group_target = group_target,
    subgroup_target = subgroup_target,
    segment_target = segment_target,
    comparison_plot_present = isTRUE(comparison_snapshot$present),
    comparison_plot_visible = isTRUE(comparison_snapshot$visible),
    comparison_plot_widget_count = comparison_snapshot$widget_count,
    summary_table_present = isTRUE(summary_snapshot$present),
    summary_table_visible = isTRUE(summary_snapshot$visible),
    summary_table_widget_count = summary_snapshot$widget_count,
    timeseries_plot_present = isTRUE(timeseries_snapshot$present),
    timeseries_plot_visible = isTRUE(timeseries_snapshot$visible),
    timeseries_plot_widget_count = timeseries_snapshot$widget_count,
    heatmap_plot_present = isTRUE(heatmap_snapshot$present),
    heatmap_plot_visible = isTRUE(heatmap_snapshot$visible),
    heatmap_plot_widget_count = heatmap_snapshot$widget_count,
    map_plot_present = isTRUE(map_snapshot$present),
    map_plot_visible = isTRUE(map_snapshot$visible),
    map_plot_widget_count = map_snapshot$widget_count,
    map_bottom_panel_present = isTRUE(map_bottom_snapshot$present),
    map_bottom_panel_visible = isTRUE(map_bottom_snapshot$visible),
    map_bottom_panel_widget_count = map_bottom_snapshot$widget_count,
    stringsAsFactors = FALSE
  )
}

failure_row <- function(label, cache_state, error_message) {
  data.frame(
    label = label,
    status = "FAIL",
    cache_state = cache_state,
    error_message = error_message,
    runtime_log_path = NA_character_,
    runtime_log_candidates = NA_character_,
    fallback_input = NA_character_,
    startup_ready_ms = NA_integer_,
    hierarchy_change_ms = NA_integer_,
    tab_historical_trend_ms = NA_integer_,
    tab_heatmap_ms = NA_integer_,
    tab_map_ms = NA_integer_,
    tab_return_current_ms = NA_integer_,
    total_probe_ms = NA_integer_,
    stringsAsFactors = FALSE
  )
}

main <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  label <- trimws(as.character(parse_arg_value(args, "label", default = "tab_switch_filtering")))
  if (!nzchar(label)) label <- "tab_switch_filtering"
  cache_state <- trimws(as.character(parse_arg_value(args, "cache-state", default = "unknown_cache_state")))
  if (!nzchar(cache_state)) cache_state <- "unknown_cache_state"
  runtime_enabled <- is_truthy(parse_arg_value(args, "runtime-perf", default = "true"), default = TRUE)
  stage_timeout_ms <- suppressWarnings(as.integer(parse_arg_value(args, "stage-timeout-ms", default = "30000")))
  startup_timeout_ms <- suppressWarnings(as.integer(parse_arg_value(args, "startup-timeout-ms", default = "120000")))
  output_timeout_ms <- suppressWarnings(as.integer(parse_arg_value(args, "output-timeout-ms", default = "45000")))
  if (!is.finite(stage_timeout_ms) || is.na(stage_timeout_ms) || stage_timeout_ms < 1000L) stage_timeout_ms <- 30000L
  if (!is.finite(startup_timeout_ms) || is.na(startup_timeout_ms) || startup_timeout_ms < 1000L) startup_timeout_ms <- 120000L
  if (!is.finite(output_timeout_ms) || is.na(output_timeout_ms) || output_timeout_ms < 1000L) output_timeout_ms <- 45000L

  repo_root <- resolve_repo_root(getwd())
  vp_clone_dir <- file.path(repo_root, "VP Clone")
  logs_dir <- file.path(vp_clone_dir, "Logs")
  dir.create(logs_dir, recursive = TRUE, showWarnings = FALSE)

  timestamp_token <- format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC")
  output_path <- file.path(logs_dir, paste0("vp_perf_probe_tab_switch_filtering_", label, "_", timestamp_token, ".csv"))

  cat("VP_PERF_TAB_FILTER_PROBE_START\n")
  cat(sprintf("VP_PERF_TAB_FILTER_LABEL=%s\n", label))
  cat(sprintf("VP_PERF_TAB_FILTER_CACHE_STATE=%s\n", cache_state))
  cat(sprintf("VP_PERF_TAB_FILTER_RUNTIME_ENABLED=%s\n", if (isTRUE(runtime_enabled)) "TRUE" else "FALSE"))

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
      stage_timeout_ms = stage_timeout_ms,
      startup_timeout_ms = startup_timeout_ms,
      output_timeout_ms = output_timeout_ms
    ),
    error = function(error) failure_row(label, cache_state, conditionMessage(error))
  )

  utils::write.csv(result, output_path, row.names = FALSE, na = "")

  cat(sprintf("VP_PERF_TAB_FILTER_STATUS=%s\n", result$status[[1L]]))
  cat(sprintf("VP_PERF_TAB_FILTER_OUTPUT=%s\n", normalizePath(output_path, winslash = "/", mustWork = FALSE)))
  cat(sprintf("VP_PERF_TAB_FILTER_RUNTIME_LOG=%s\n", result$runtime_log_path[[1L]] %||% ""))
  cat(sprintf("VP_PERF_TAB_FILTER_FALLBACK_INPUT=%s\n", result$fallback_input[[1L]] %||% ""))
  cat(sprintf("VP_PERF_TAB_FILTER_TOTAL_MS=%s\n", result$total_probe_ms[[1L]] %||% NA_integer_))
  cat(sprintf("VP_PERF_TAB_FILTER_HIERARCHY_MS=%s\n", result$hierarchy_change_ms[[1L]] %||% NA_integer_))
  cat(sprintf("VP_PERF_TAB_FILTER_TREND_MS=%s\n", result$tab_historical_trend_ms[[1L]] %||% NA_integer_))
  cat(sprintf("VP_PERF_TAB_FILTER_HEATMAP_MS=%s\n", result$tab_heatmap_ms[[1L]] %||% NA_integer_))
  cat(sprintf("VP_PERF_TAB_FILTER_MAP_MS=%s\n", result$tab_map_ms[[1L]] %||% NA_integer_))
  cat(sprintf("VP_PERF_TAB_FILTER_RETURN_CURRENT_MS=%s\n", result$tab_return_current_ms[[1L]] %||% NA_integer_))
  if (!identical(result$status[[1L]], "PASS")) {
    cat(sprintf("VP_PERF_TAB_FILTER_ERROR=%s\n", result$error_message[[1L]] %||% ""))
  }
  cat("VP_PERF_TAB_FILTER_PROBE_COMPLETE\n")
}

main()
