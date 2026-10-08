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
    cat(sprintf("VP_PERF_HIERARCHY_TRANSITION_%s\n", key))
  } else {
    cat(sprintf("VP_PERF_HIERARCHY_TRANSITION_%s=%s\n", key, value))
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

  stop("Could not resolve repository root for VP hierarchy transition probe.", call. = FALSE)
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

pick_specific_choice <- function(choices, preferred = character(0), excluded = c("__all__", "All", "")) {
  candidate_values <- choices[!(choices %in% excluded)]
  for (preferred_value in preferred) {
    if (preferred_value %in% candidate_values) return(preferred_value)
  }
  if (length(candidate_values) == 0L) return(NA_character_)
  candidate_values[[1L]]
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

run_probe <- function(app_dir, label, cache_state, logs_dir, runtime_enabled, stage_timeout_ms, startup_timeout_ms) {
  timestamp_token <- format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC")
  runtime_log_path <- file.path(logs_dir, paste0("vp_runtime_perf_hierarchy_transition_", label, "_", timestamp_token, ".jsonl"))
  Sys.setenv(VP_PERF_RUNTIME = if (isTRUE(runtime_enabled)) "true" else "false")
  Sys.setenv(VP_PERF_RUNTIME_MEMORY_MODE = "off")
  Sys.setenv(VP_PERF_RUNTIME_LOG_FILE = normalizePath(runtime_log_path, winslash = "/", mustWork = FALSE))
  Sys.setenv(NOT_CRAN = "true")
  options(vp_perf_runtime = isTRUE(runtime_enabled))

  probe_start <- Sys.time()
  emit_probe("STAGE_BEGIN", "appdriver_start")
  app <- shinytest2::AppDriver$new(
    app_dir = app_dir,
    name = paste0("vp_perf_hierarchy_transition_", label),
    load_timeout = startup_timeout_ms,
    timeout = max(startup_timeout_ms, stage_timeout_ms)
  )
  emit_probe("STAGE_END", "appdriver_start")
  on.exit(try(app$stop(), silent = TRUE), add = TRUE)

  emit_probe("STAGE_BEGIN", "startup_wait")
  startup_wait <- soft_wait_for_idle(app, timeout_ms = startup_timeout_ms)
  emit_probe("STAGE_END", paste0("startup_wait|ok=", isTRUE(startup_wait$ok)))
  startup_ready_ms <- to_int_ms(probe_start)
  required_controls <- c(
    "data_source_choice",
    "vp_trade_flow_choice",
    "vp_group_choice",
    "vp_subgroup_choice",
    "vp_market_segment_choice",
    "country_choice",
    "main_tabs_panel"
  )
  missing_controls <- required_controls[!vapply(required_controls, function(id_value) dom_exists(app, id_value), logical(1))]

  source_stage <- timed_set_input(app, "source_switch", "data_source_choice", "vp_trade", timeout_ms = stage_timeout_ms)
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

  emit_probe("STAGE_BEGIN", "read_final_state")
  final_state_start <- Sys.time()
  resolved_group <- get_input_value(app, "vp_group_choice")
  resolved_subgroup <- get_input_value(app, "vp_subgroup_choice")
  resolved_segment <- get_input_value(app, "vp_market_segment_choice")
  resolved_trade_flow <- get_input_value(app, "vp_trade_flow_choice")
  resolved_source <- get_input_value(app, "data_source_choice")
  emit_probe("STAGE_END", paste0("read_final_state|elapsed_ms=", to_int_ms(final_state_start)))
  resolved_path_ok <- all(c(resolved_group, resolved_subgroup, resolved_segment) != "__all__")

  problems <- c(
    if (!isTRUE(startup_wait$ok)) paste("startup_wait_failed", startup_wait$message, sep = ":") else character(0),
    if (length(missing_controls) > 0L) paste("missing_controls", paste(missing_controls, collapse = "|"), sep = ":") else character(0),
    stage_problem("source_switch", source_stage),
    stage_problem("trade_flow", trade_stage),
    stage_problem("group_reset", group_reset_stage),
    stage_problem("subgroup_reset", subgroup_reset_stage),
    stage_problem("segment_reset", segment_reset_stage),
    stage_problem("group_choice", group_stage),
    stage_problem("subgroup_choice", subgroup_stage),
    stage_problem("segment_choice", segment_stage),
    if (!isTRUE(resolved_path_ok)) "resolved_path_not_specific" else character(0)
  )
  problems <- problems[nzchar(problems)]

  set_stages_ok <- all(vapply(
    list(source_stage, trade_stage, group_reset_stage, subgroup_reset_stage, segment_reset_stage, group_stage, subgroup_stage, segment_stage),
    function(stage_result) isTRUE(stage_result$set_ok),
    logical(1)
  ))
  wait_stages_ok <- isTRUE(startup_wait$ok) && all(vapply(
    list(source_stage, trade_stage, group_reset_stage, subgroup_reset_stage, segment_reset_stage, group_stage, subgroup_stage, segment_stage),
    function(stage_result) isTRUE(stage_result$wait_ok),
    logical(1)
  ))

  status <- if (isTRUE(set_stages_ok) && isTRUE(resolved_path_ok) && length(missing_controls) == 0L) {
    if (isTRUE(wait_stages_ok)) "PASS" else "PARTIAL"
  } else {
    "FAIL"
  }

  data.frame(
    label = label,
    status = status,
    cache_state = cache_state,
    error_message = if (length(problems) > 0L) paste(problems, collapse = " || ") else NA_character_,
    runtime_log_path = normalizePath(runtime_log_path, winslash = "/", mustWork = FALSE),
    startup_ready_ms = startup_ready_ms,
    source_switch_ms = source_stage$elapsed_ms,
    trade_flow_ms = trade_stage$elapsed_ms,
    hierarchy_change_ms = hierarchy_change_ms,
    total_probe_ms = to_int_ms(probe_start),
    startup_wait_ok = isTRUE(startup_wait$ok),
    source_wait_ok = isTRUE(source_stage$wait_ok),
    trade_wait_ok = isTRUE(trade_stage$wait_ok),
    group_reset_wait_ok = isTRUE(group_reset_stage$wait_ok),
    subgroup_reset_wait_ok = isTRUE(subgroup_reset_stage$wait_ok),
    segment_reset_wait_ok = isTRUE(segment_reset_stage$wait_ok),
    group_wait_ok = isTRUE(group_stage$wait_ok),
    subgroup_wait_ok = isTRUE(subgroup_stage$wait_ok),
    segment_wait_ok = isTRUE(segment_stage$wait_ok),
    missing_controls = paste(missing_controls, collapse = "|"),
    resolved_source = resolved_source,
    resolved_trade_flow = resolved_trade_flow,
    resolved_group = resolved_group,
    resolved_subgroup = resolved_subgroup,
    resolved_segment = resolved_segment,
    resolved_path_ok = isTRUE(resolved_path_ok),
    group_choices_count = length(group_choices),
    subgroup_choices_count = length(subgroup_choices),
    segment_choices_count = length(segment_choices),
    group_target = group_target,
    subgroup_target = subgroup_target,
    segment_target = segment_target,
    stringsAsFactors = FALSE
  )
}

main <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  label <- trimws(as.character(parse_arg_value(args, "label", default = "hierarchy_transition")))
  if (!nzchar(label)) label <- "hierarchy_transition"
  cache_state <- trimws(as.character(parse_arg_value(args, "cache-state", default = "unknown_cache_state")))
  if (!nzchar(cache_state)) cache_state <- "unknown_cache_state"
  runtime_enabled <- is_truthy(parse_arg_value(args, "runtime-perf", default = "true"), default = TRUE)
  stage_timeout_ms <- suppressWarnings(as.integer(parse_arg_value(args, "stage-timeout-ms", default = "30000")))
  startup_timeout_ms <- suppressWarnings(as.integer(parse_arg_value(args, "startup-timeout-ms", default = "120000")))
  if (!is.finite(stage_timeout_ms) || is.na(stage_timeout_ms) || stage_timeout_ms < 1000L) stage_timeout_ms <- 30000L
  if (!is.finite(startup_timeout_ms) || is.na(startup_timeout_ms) || startup_timeout_ms < 1000L) startup_timeout_ms <- 120000L

  repo_root <- resolve_repo_root(getwd())
  vp_clone_dir <- file.path(repo_root, "VP Clone")
  logs_dir <- file.path(vp_clone_dir, "Logs")
  dir.create(logs_dir, recursive = TRUE, showWarnings = FALSE)

  timestamp_token <- format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC")
  output_path <- file.path(logs_dir, paste0("vp_perf_probe_hierarchy_transition_", label, "_", timestamp_token, ".csv"))

  cat("VP_PERF_HIERARCHY_TRANSITION_PROBE_START\n")
  cat(sprintf("VP_PERF_HIERARCHY_TRANSITION_LABEL=%s\n", label))
  cat(sprintf("VP_PERF_HIERARCHY_TRANSITION_CACHE_STATE=%s\n", cache_state))
  cat(sprintf("VP_PERF_HIERARCHY_TRANSITION_RUNTIME_ENABLED=%s\n", if (isTRUE(runtime_enabled)) "TRUE" else "FALSE"))

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
      startup_timeout_ms = startup_timeout_ms
    ),
    error = function(error) {
      data.frame(
        label = label,
        status = "FAIL",
        cache_state = cache_state,
        error_message = conditionMessage(error),
        runtime_log_path = NA_character_,
        startup_ready_ms = NA_integer_,
        source_switch_ms = NA_integer_,
        trade_flow_ms = NA_integer_,
        hierarchy_change_ms = NA_integer_,
        total_probe_ms = NA_integer_,
        stringsAsFactors = FALSE
      )
    }
  )

  utils::write.csv(result, output_path, row.names = FALSE, na = "")

  cat(sprintf("VP_PERF_HIERARCHY_TRANSITION_STATUS=%s\n", result$status[[1L]]))
  cat(sprintf("VP_PERF_HIERARCHY_TRANSITION_OUTPUT=%s\n", normalizePath(output_path, winslash = "/", mustWork = FALSE)))
  cat(sprintf("VP_PERF_HIERARCHY_TRANSITION_RUNTIME_LOG=%s\n", result$runtime_log_path[[1L]] %||% ""))
  cat(sprintf("VP_PERF_HIERARCHY_TRANSITION_TOTAL_MS=%s\n", result$total_probe_ms[[1L]] %||% NA_integer_))
  cat(sprintf("VP_PERF_HIERARCHY_TRANSITION_HIERARCHY_MS=%s\n", result$hierarchy_change_ms[[1L]] %||% NA_integer_))
  if (!identical(result$status[[1L]], "PASS")) {
    cat(sprintf("VP_PERF_HIERARCHY_TRANSITION_ERROR=%s\n", result$error_message[[1L]] %||% ""))
  }
  cat("VP_PERF_HIERARCHY_TRANSITION_PROBE_COMPLETE\n")
}

main()