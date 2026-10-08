if (!requireNamespace("shinytest2", quietly = TRUE)) {
  stop("Package 'shinytest2' is required for ftn_validated_unit_display_ui_guardrail.R", call. = FALSE)
}
if (!requireNamespace("jsonlite", quietly = TRUE)) {
  stop("Package 'jsonlite' is required for ftn_validated_unit_display_ui_guardrail.R", call. = FALSE)
}
if (!requireNamespace("data.table", quietly = TRUE)) {
  stop("Package 'data.table' is required for ftn_validated_unit_display_ui_guardrail.R", call. = FALSE)
}

`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0L) y else x
}

resolve_repo_root <- function(start_dir = getwd()) {
  start_dir <- normalizePath(start_dir, winslash = "/", mustWork = FALSE)
  candidates <- unique(c(
    start_dir,
    vapply(
      1:8,
      function(level) normalizePath(file.path(start_dir, paste(rep("..", level), collapse = "/")), winslash = "/", mustWork = FALSE),
      character(1)
    )
  ))

  for (candidate in candidates) {
    if (file.exists(file.path(candidate, ".vp_clone_root"))) {
      return(candidate)
    }
  }

  stop("Could not resolve FTN repository root (.vp_clone_root missing).", call. = FALSE)
}

to_bool <- function(value) {
  if (identical(value, TRUE)) return(TRUE)
  if (identical(value, FALSE)) return(FALSE)
  value_chr <- tolower(trimws(as.character(value %||% "")))
  identical(value_chr, "true")
}

trim_scalar <- function(value, default = "") {
  if (is.null(value) || length(value) == 0L) return(default)
  value_chr <- trimws(as.character(value[[1L]] %||% ""))
  if (!nzchar(value_chr)) default else value_chr
}

safe_wait_for_idle <- function(app, timeout = 120000) {
  tryCatch({
    app$wait_for_idle(timeout = timeout)
    TRUE
  }, error = function(...) FALSE)
}

run_js <- function(app, script) {
  tryCatch(app$get_js(script), error = function(...) "")
}

get_select_choices <- function(app, input_id) {
  script <- sprintf(
    "(function(){ var id = '%s'; var docs = [document]; for (var i = 0; i < window.frames.length; i++) { try { if (window.frames[i].document) docs.push(window.frames[i].document); } catch (e) {} } for (var j = 0; j < docs.length; j++) { try { var el = docs[j].getElementById(id); if (!el) continue; if (el.selectize && el.selectize.options) { var keys = Object.keys(el.selectize.options).map(function(x){ return String(x || '').trim(); }).filter(function(x){ return x.length > 0; }); if (keys.length > 0) return keys.join('|||'); } if (el.options) { var vals = []; for (var k = 0; k < el.options.length; k++) vals.push(String(el.options[k].value || '').trim()); return vals.join('|||'); } } catch (e) {} } return ''; })();",
    input_id
  )
  raw <- trimws(as.character(run_js(app, script) %||% ""))
  if (!nzchar(raw)) return(character(0))
  values <- strsplit(raw, "\\|\\|\\|", perl = TRUE)[[1L]]
  values <- trimws(values)
  values[nzchar(values)]
}

get_dom_ids <- function(app) {
  script <- "(function(){ var docs=[document]; for (var i=0;i<window.frames.length;i++){ try{ if(window.frames[i].document) docs.push(window.frames[i].document); }catch(e){} } var out=[]; for (var j=0;j<docs.length;j++){ try{ var nodes=docs[j].querySelectorAll('[id]'); for (var k=0;k<nodes.length;k++){ if(nodes[k].id) out.push(nodes[k].id); } }catch(e){} } var dedup=[]; var seen={}; for (var n=0;n<out.length;n++){ var key=out[n]; if(!seen[key]){ seen[key]=true; dedup.push(key); } } return dedup.join('|||'); })();"
  raw <- trimws(as.character(run_js(app, script) %||% ""))
  if (!nzchar(raw)) return(character(0))
  values <- strsplit(raw, "\\|\\|\\|", perl = TRUE)[[1L]]
  values <- trimws(values)
  values[nzchar(values)]
}

wait_for_select_choices <- function(app, input_id, timeout_sec = 90, poll_sec = 0.5) {
  deadline <- Sys.time() + timeout_sec
  repeat {
    choices <- get_select_choices(app, input_id)
    if (length(choices) > 0L) {
      return(choices)
    }
    if (Sys.time() >= deadline) {
      return(character(0))
    }
    Sys.sleep(poll_sec)
  }
}

wait_for_required_ids <- function(app, required_ids, timeout_sec = 120, poll_sec = 0.5) {
  deadline <- Sys.time() + timeout_sec
  last_ids <- character(0)
  repeat {
    ids <- get_dom_ids(app)
    if (length(ids) > 0L) {
      last_ids <- ids
      if (all(required_ids %in% ids)) {
        return(list(ok = TRUE, ids = ids))
      }
    }
    if (Sys.time() >= deadline) {
      return(list(ok = FALSE, ids = last_ids))
    }
    Sys.sleep(poll_sec)
  }
}

get_input_value <- function(app, input_id) {
  values <- tryCatch(app$get_values(), error = function(...) NULL)
  if (!is.list(values) || !is.list(values$input)) return("")
  value <- values$input[[input_id]]
  value <- trimws(as.character(value %||% ""))
  value <- value[!is.na(value) & nzchar(value)]
  if (length(value) == 0L) "" else value[[1L]]
}

get_shiny_input_value <- function(app, input_id) {
  script <- sprintf(
    "(function(){ try { if (window.Shiny && Shiny.shinyapp && Shiny.shinyapp.$inputValues) { var v = Shiny.shinyapp.$inputValues['%s']; if (v === undefined || v === null) return ''; return String(v).trim(); } } catch (e) {} return ''; })();",
    input_id
  )
  value <- tryCatch(as.character(run_js(app, script) %||% ""), error = function(...) "")
  value <- trimws(value)
  if (length(value) == 0L || !nzchar(value[[1L]])) "" else value[[1L]]
}

get_select_current_value <- function(app, input_id) {
  script <- sprintf(
    "(function(){ var id='%s'; var docs=[document]; for (var i=0;i<window.frames.length;i++){ try{ if(window.frames[i].document) docs.push(window.frames[i].document); } catch(e) {} } for (var j=0;j<docs.length;j++){ try{ var el=docs[j].getElementById(id); if(!el) continue; if(el.selectize && typeof el.selectize.getValue === 'function'){ var v = String(el.selectize.getValue() || '').trim(); if(v.length > 0) return v; } var raw = String(el.value || '').trim(); if(raw.length > 0) return raw; } catch(e) {} } return ''; })();",
    input_id
  )
  value <- tryCatch(as.character(run_js(app, script) %||% ""), error = function(...) "")
  value <- trimws(value)
  if (length(value) == 0L || !nzchar(value[[1L]])) "" else value[[1L]]
}

resolve_effective_input_value <- function(app, input_id) {
  values <- c(
    get_input_value(app, input_id),
    get_select_current_value(app, input_id),
    get_shiny_input_value(app, input_id)
  )
  values <- trimws(as.character(values %||% character(0)))
  values <- values[!is.na(values) & nzchar(values)]
  if (length(values) == 0L) "" else values[[1L]]
}

set_input_by_name <- function(app, input_id, value, wait_ = FALSE) {
  args <- list(wait_ = wait_)
  args[[input_id]] <- value
  do.call(app$set_inputs, args)
}

set_input_and_confirm <- function(app, input_id, value, timeout_sec = 90, poll_sec = 0.5) {
  deadline <- Sys.time() + timeout_sec
  last_value <- ""
  tried_set <- FALSE

  repeat {
    current_value <- resolve_effective_input_value(app, input_id)
    if (identical(current_value, value)) {
      return(list(ok = TRUE, current_value = current_value))
    }

    if (!isTRUE(tried_set) || Sys.time() >= (deadline - timeout_sec / 3)) {
      try(set_input_by_name(app, input_id, value, wait_ = FALSE), silent = TRUE)
      tried_set <- TRUE
    }

    Sys.sleep(poll_sec)
    current_value <- resolve_effective_input_value(app, input_id)
    last_value <- current_value

    if (identical(current_value, value)) {
      return(list(ok = TRUE, current_value = current_value))
    }

    if (Sys.time() >= deadline) {
      return(list(ok = FALSE, current_value = last_value))
    }
    Sys.sleep(poll_sec)
  }
}

wait_for_source_state <- function(app, timeout_sec = 120, poll_sec = 0.5) {
  deadline <- Sys.time() + timeout_sec
  last <- list(
    source_choices = character(0),
    source_input_value = "",
    source_select_value = "",
    source_js_input_value = "",
    source_effective_value = "",
    source_has_vp_trade_choice = FALSE,
    source_value_is_vp_trade = FALSE
  )

  repeat {
    source_choices <- get_select_choices(app, "data_source_choice")
    source_input_value <- get_input_value(app, "data_source_choice")
    source_select_value <- get_select_current_value(app, "data_source_choice")
    source_js_input_value <- get_shiny_input_value(app, "data_source_choice")

    candidates <- c(source_input_value, source_select_value, source_js_input_value)
    candidates <- trimws(as.character(candidates %||% character(0)))
    candidates <- candidates[!is.na(candidates) & nzchar(candidates)]
    source_effective_value <- if (length(candidates) > 0L) candidates[[1L]] else ""

    source_has_vp_trade_choice <- "vp_trade" %in% source_choices
    source_value_is_vp_trade <- any(candidates == "vp_trade")

    last <- list(
      source_choices = source_choices,
      source_input_value = source_input_value,
      source_select_value = source_select_value,
      source_js_input_value = source_js_input_value,
      source_effective_value = source_effective_value,
      source_has_vp_trade_choice = source_has_vp_trade_choice,
      source_value_is_vp_trade = source_value_is_vp_trade
    )

    if (isTRUE(source_value_is_vp_trade)) {
      return(last)
    }

    if (Sys.time() >= deadline) {
      return(last)
    }

    Sys.sleep(poll_sec)
  }
}

dom_exists <- function(app, id) {
  script <- sprintf(
    "(function(){ var id='%s'; var docs=[document]; for (var i=0;i<window.frames.length;i++){ try{ if(window.frames[i].document) docs.push(window.frames[i].document); }catch(e){} } for (var j=0;j<docs.length;j++){ try{ if(docs[j].getElementById(id) !== null) return true; }catch(e){} } return false; })();",
    id
  )
  to_bool(run_js(app, script))
}

tab_choice_available <- function(app, tab_value) {
  script <- sprintf(
    "(function(){ var wanted='%s'; var docs=[document]; for (var i=0;i<window.frames.length;i++){ try{ if(window.frames[i].document) docs.push(window.frames[i].document); }catch(e){} } for (var j=0;j<docs.length;j++){ try{ var nodes=docs[j].querySelectorAll('[data-value]'); for (var k=0;k<nodes.length;k++){ var v=String(nodes[k].getAttribute('data-value') || '').trim(); if(v === wanted) return true; } }catch(e){} } return false; })();",
    tab_value
  )
  to_bool(run_js(app, script))
}

set_input_value <- function(app, input_id, value, timeout = 120000) {
  args <- list(wait_ = FALSE)
  args[[input_id]] <- value
  do.call(app$set_inputs, args)
  safe_wait_for_idle(app, timeout = timeout)
}

select_with_fallback <- function(app, input_id, preferred_value = NULL, fallback_values = c("All", "__all__"), timeout = 120000) {
  selected <- trim_scalar(preferred_value, default = "")
  choices <- wait_for_select_choices(app, input_id, timeout_sec = 45)

  if (length(choices) == 0L) {
    if (nzchar(selected)) {
      tryCatch(
        set_input_value(app, input_id, selected, timeout = timeout),
        error = function(...) NULL
      )
      return(selected)
    }

    stop(sprintf("Input '%s' has no available choices and no preferred value was provided.", input_id), call. = FALSE)
  }

  if (!nzchar(selected) || !(selected %in% choices)) {
    fallback_match <- fallback_values[fallback_values %in% choices]
    selected <- if (length(fallback_match) > 0L) fallback_match[[1L]] else choices[[1L]]
  }

  set_input_value(app, input_id, selected, timeout = timeout)
  selected
}

get_plotly_snapshot <- function(app, output_id) {
  script <- sprintf(
    "(function(){\n      var id = '%s';\n      function docs(){\n        var out = [document];\n        for (var i = 0; i < window.frames.length; i++) {\n          try { if (window.frames[i].document) out.push(window.frames[i].document); } catch (e) {}\n        }\n        return out;\n      }\n      function txt(v){\n        if (v === null || v === undefined) return '';\n        if (typeof v === 'string') return v;\n        if (typeof v.text === 'string') return v.text;\n        return String(v);\n      }\n      var allDocs = docs();\n      for (var d = 0; d < allDocs.length; d++) {\n        try {\n          var root = allDocs[d].getElementById(id);\n          if (!root) continue;\n          var plotNode = root.querySelector('.js-plotly-plot') || root;\n          var data = [];\n          if (Array.isArray(plotNode.data) && plotNode.data.length > 0) {\n            data = plotNode.data;\n          } else if (Array.isArray(plotNode._fullData) && plotNode._fullData.length > 0) {\n            data = plotNode._fullData;\n          }\n          var layout = plotNode.layout || plotNode._fullLayout || {};\n          var names = [];\n          var hovertemplates = [];\n          var hovertexts = [];\n          var texts = [];\n          var colorbarTitles = [];\n          for (var i = 0; i < data.length; i++) {\n            var tr = data[i] || {};\n            if (tr.name !== undefined && tr.name !== null) names.push(String(tr.name));\n            if (tr.hovertemplate !== undefined && tr.hovertemplate !== null) hovertemplates.push(String(tr.hovertemplate));\n            if (Array.isArray(tr.hovertext) && tr.hovertext.length > 0 && tr.hovertext[0] !== null && tr.hovertext[0] !== undefined) {\n              hovertexts.push(String(tr.hovertext[0]));\n            } else if (tr.hovertext !== undefined && tr.hovertext !== null && typeof tr.hovertext !== 'object') {\n              hovertexts.push(String(tr.hovertext));\n            }\n            if (Array.isArray(tr.text) && tr.text.length > 0 && tr.text[0] !== null && tr.text[0] !== undefined) {\n              texts.push(String(tr.text[0]));\n            } else if (tr.text !== undefined && tr.text !== null && typeof tr.text !== 'object') {\n              texts.push(String(tr.text));\n            }\n            var cb = tr.colorbar || (tr.marker && tr.marker.colorbar) || null;\n            if (cb && cb.title !== undefined && cb.title !== null) {\n              var cbTitle = txt(cb.title);\n              if (cbTitle) colorbarTitles.push(cbTitle);\n            }\n          }\n          var annotations = [];\n          if (Array.isArray(layout.annotations)) {\n            for (var a = 0; a < layout.annotations.length; a++) {\n              var ann = layout.annotations[a] || {};\n              var annText = txt(ann.text !== undefined ? ann.text : ann);\n              if (annText) annotations.push(annText);\n            }\n          }\n          var out = {\n            output_id: id,\n            trace_count: data.length,\n            title: txt(layout.title),\n            yaxis_title: layout.yaxis ? txt(layout.yaxis.title) : '',\n            annotations: annotations,\n            trace_names: names,\n            hovertemplates: hovertemplates,\n            hovertexts: hovertexts,\n            texts: texts,\n            colorbar_titles: colorbarTitles\n          };\n          return JSON.stringify(out);\n        } catch (e) {}\n      }\n      return '';\n    })();",
    output_id
  )

  raw <- trimws(as.character(run_js(app, script) %||% ""))
  if (!nzchar(raw)) return(NULL)

  tryCatch(
    jsonlite::fromJSON(raw, simplifyVector = TRUE),
    error = function(...) NULL
  )
}

wait_for_plotly_snapshot <- function(app, output_id, timeout_sec = 90, poll_sec = 0.5) {
  deadline <- Sys.time() + timeout_sec
  last <- NULL
  repeat {
    snap <- get_plotly_snapshot(app, output_id)
    if (!is.null(snap)) {
      last <- snap
      trace_count <- suppressWarnings(as.integer(snap$trace_count %||% 0L))
      if (is.finite(trace_count) && trace_count > 0L) {
        return(snap)
      }
    }

    if (Sys.time() >= deadline) {
      return(last)
    }
    Sys.sleep(poll_sec)
  }
}

as_chr_vec <- function(value) {
  if (is.null(value)) return(character(0))
  out <- as.character(unlist(value, recursive = TRUE, use.names = FALSE))
  out <- trimws(out)
  out[nzchar(out)]
}

contains_token <- function(values, token) {
  values <- as_chr_vec(values)
  if (length(values) == 0L) return(FALSE)
  any(grepl(token, values, fixed = TRUE))
}

get_datatable_caption <- function(app, output_id) {
  script <- sprintf(
    "(function(){ var id = '%s'; var docs = [document]; for (var i = 0; i < window.frames.length; i++) { try { if (window.frames[i].document) docs.push(window.frames[i].document); } catch (e) {} } for (var j = 0; j < docs.length; j++) { try { var root = docs[j].getElementById(id); if (!root) continue; var cap = root.querySelector('table caption'); if (cap && cap.textContent) return String(cap.textContent).trim(); } catch (e) {} } return ''; })();",
    output_id
  )
  trimws(as.character(run_js(app, script) %||% ""))
}

pick_candidate <- function(dt, unit_label) {
  rows <- dt[
    Trade == "export" &
      !is.na(unit_value) &
      trimws(as.character(unit_value_unit)) == unit_label,
    .(
      Trade,
      Group,
      Subgroup,
      MarketSegment,
      CommodityName,
      commodity,
      countryDescription,
      market_year,
      analysis_month,
      unit_value_unit,
      ytd_unit_value_unit
    )
  ]

  if (nrow(rows) == 0L) {
    return(NULL)
  }

  rows <- rows[order(Group, Subgroup, MarketSegment, CommodityName, commodity, countryDescription, market_year, analysis_month)]
  as.list(rows[1L])
}

apply_vp_context <- function(app, candidate, metric_target = NULL) {
  candidate_trade <- trim_scalar(candidate$Trade, "export")
  candidate_group <- trim_scalar(candidate$Group, "")
  candidate_subgroup <- trim_scalar(candidate$Subgroup, "")
  candidate_segment <- trim_scalar(candidate$MarketSegment, "")
  candidate_commodity_name <- trim_scalar(candidate$CommodityName, "")
  candidate_detail <- trim_scalar(candidate$commodity, "All")
  candidate_country <- trim_scalar(candidate$countryDescription, "")

  emit_probe_progress("context_phase", "trade_flow_set")
  trade_flow_set <- set_input_and_confirm(app, "vp_trade_flow_choice", candidate_trade, timeout_sec = 90)
  if (!isTRUE(trade_flow_set$ok)) {
    stop(
      paste0("Could not set vp_trade_flow_choice='", candidate_trade, "'. current_value=", trade_flow_set$current_value),
      call. = FALSE
    )
  }

  emit_probe_progress("context_phase", "source_set_vp_trade")
  source_set <- set_input_and_confirm(app, "data_source_choice", "vp_trade", timeout_sec = 90)
  if (!isTRUE(source_set$ok)) {
    stop(
      paste0("Could not set data_source_choice='vp_trade'. current_value=", source_set$current_value),
      call. = FALSE
    )
  }

  emit_probe_progress("context_phase", "data_frequency_monthly_requested")
  try(set_input_by_name(app, "data_frequency", "monthly", wait_ = FALSE), silent = TRUE)
  invisible(safe_wait_for_idle(app, timeout = 60000))

  group_set <- set_input_and_confirm(app, "vp_group_choice", candidate_group, timeout_sec = 90)
  subgroup_set <- set_input_and_confirm(app, "vp_subgroup_choice", candidate_subgroup, timeout_sec = 90)
  segment_set <- set_input_and_confirm(app, "vp_market_segment_choice", candidate_segment, timeout_sec = 90)
  commodity_name_set <- set_input_and_confirm(app, "vp_commodity_name_choice", candidate_commodity_name, timeout_sec = 90)
  if (!isTRUE(group_set$ok) || !isTRUE(subgroup_set$ok) || !isTRUE(segment_set$ok) || !isTRUE(commodity_name_set$ok)) {
    stop(
      paste0(
        "Could not drive hierarchy controls. ",
        "group_ok=", group_set$ok, "|group_current=", group_set$current_value,
        "|subgroup_ok=", subgroup_set$ok, "|subgroup_current=", subgroup_set$current_value,
        "|segment_ok=", segment_set$ok, "|segment_current=", segment_set$current_value,
        "|commodity_name_ok=", commodity_name_set$ok, "|commodity_name_current=", commodity_name_set$current_value
      ),
      call. = FALSE
    )
  }

  detail_choices <- wait_for_select_choices(app, "commodity_choice", timeout_sec = 60)
  target_detail <- if (candidate_detail %in% detail_choices) {
    candidate_detail
  } else if ("All" %in% detail_choices) {
    "All"
  } else if ("__all__" %in% detail_choices) {
    "__all__"
  } else if (length(detail_choices) > 0L) {
    detail_choices[[1L]]
  } else {
    ""
  }
  if (!nzchar(target_detail)) {
    stop("No commodity_choice values available after hierarchy selection.", call. = FALSE)
  }
  detail_set <- set_input_and_confirm(app, "commodity_choice", target_detail, timeout_sec = 60)
  if (!isTRUE(detail_set$ok)) {
    stop(
      paste0("Could not set commodity_choice='", target_detail, "'. current_value=", detail_set$current_value),
      call. = FALSE
    )
  }

  country_choices <- wait_for_select_choices(app, "country_choice", timeout_sec = 60)
  target_country <- if (nzchar(candidate_country) && candidate_country %in% country_choices) {
    candidate_country
  } else if ("GRAND_TOTAL" %in% country_choices) {
    "GRAND_TOTAL"
  } else if (length(country_choices) > 0L) {
    country_choices[[1L]]
  } else {
    ""
  }
  if (nzchar(target_country)) {
    country_set <- set_input_and_confirm(app, "country_choice", target_country, timeout_sec = 60)
    if (!isTRUE(country_set$ok)) {
      stop(
        paste0("Could not set country_choice='", target_country, "'. current_value=", country_set$current_value),
        call. = FALSE
      )
    }
  }

  if (!is.null(metric_target) && nzchar(trimws(as.character(metric_target)))) {
    metric_set <- set_input_and_confirm(app, "metric_choice", metric_target, timeout_sec = 90)
    if (!isTRUE(metric_set$ok)) {
      stop(
        paste0("Could not set metric_choice='", metric_target, "'. current_value=", metric_set$current_value),
        call. = FALSE
      )
    }
  }
}

repo_root <- resolve_repo_root()
Sys.setenv(NOT_CRAN = "true")
artifact_path <- file.path(repo_root, "System", "Processed Data", "vp_trade_monthly_pre.rds")
if (!file.exists(artifact_path)) {
  stop(paste0("Artifact not found: ", artifact_path), call. = FALSE)
}

dt <- data.table::as.data.table(readRDS(artifact_path))
required_cols <- c("Trade", "Group", "Subgroup", "MarketSegment", "CommodityName", "commodity", "countryDescription", "unit_value", "unit_value_unit", "ytd_unit_value_unit", "market_year", "analysis_month")
missing_cols <- setdiff(required_cols, names(dt))
if (length(missing_cols) > 0L) {
  stop(sprintf("Missing required artifact columns: %s", paste(missing_cols, collapse = ", ")), call. = FALSE)
}

pound_candidate <- pick_candidate(dt, "Dollars per pound")
gallon_candidate <- pick_candidate(dt, "Dollars per gallon")

if (is.null(pound_candidate)) {
  stop("No reachable export candidate with unit_value_unit = Dollars per pound was found in the artifact.", call. = FALSE)
}

gallon_reachable <- !is.null(gallon_candidate)

required_controls <- c(
  "data_source_choice",
  "vp_trade_flow_choice",
  "vp_group_choice",
  "vp_subgroup_choice",
  "vp_market_segment_choice",
  "vp_commodity_name_choice",
  "commodity_choice",
  "country_choice",
  "metric_choice"
)

app <- NULL
id_wait <- NULL
launch_diagnostics <- character(0)

for (attempt in seq_len(3L)) {
  cat("FTN_UNIT_UI_GUARDRAIL_PROGRESS=launch_attempt=", attempt, "\n", sep = "")
  app_name <- paste0("ftn_unit_display_ui_guardrail_", attempt, "_", as.integer(as.numeric(Sys.time())))
  app_candidate <- tryCatch(
    shinytest2::AppDriver$new(
      app_dir = repo_root,
      name = app_name,
      load_timeout = 120000,
      timeout = 120000
    ),
    error = function(e) e
  )

  if (inherits(app_candidate, "error")) {
    launch_diagnostics <- c(launch_diagnostics, paste0("attempt=", attempt, "|create_error=", conditionMessage(app_candidate)))
    next
  }

  invisible(safe_wait_for_idle(app_candidate, timeout = 45000))
  id_candidate <- wait_for_required_ids(app_candidate, required_controls, timeout_sec = 120)
  if (isTRUE(id_candidate$ok)) {
    cat("FTN_UNIT_UI_GUARDRAIL_PROGRESS=launch_attempt_ready=", attempt, "\n", sep = "")
    app <- app_candidate
    id_wait <- id_candidate
    break
  }

  launch_diagnostics <- c(
    launch_diagnostics,
    paste0("attempt=", attempt, "|ids=", paste(utils::head(id_candidate$ids, 40L), collapse = ","))
  )
  try(app_candidate$stop(), silent = TRUE)
}

if (is.null(app) || is.null(id_wait) || !isTRUE(id_wait$ok)) {
  stop(
    paste0(
      "FTN app did not render required controls before timeout. ",
      "Launch diagnostics: ", paste(launch_diagnostics, collapse = " || ")
    ),
    call. = FALSE
  )
}
on.exit(app$stop(), add = TRUE)

initial_flow_set <- set_input_and_confirm(app, "vp_trade_flow_choice", "export", timeout_sec = 90)
if (!isTRUE(initial_flow_set$ok)) {
  stop(
    paste0("Could not initialize vp_trade_flow_choice='export'. current_value=", initial_flow_set$current_value),
    call. = FALSE
  )
}

initial_source_set <- set_input_and_confirm(app, "data_source_choice", "vp_trade", timeout_sec = 90)
if (!isTRUE(initial_source_set$ok)) {
  stop(
    paste0("Could not initialize data_source_choice='vp_trade'. current_value=", initial_source_set$current_value),
    call. = FALSE
  )
}

default_main_tab <- trim_scalar(tryCatch(app$get_values(input = "main_tabs_panel")$input$main_tabs_panel, error = function(...) ""), default = "")

checks <- data.table::data.table(
  context = character(0),
  output_id = character(0),
  field = character(0),
  expected = character(0),
  observed = character(0),
  passed = logical(0)
)

emit_probe_progress <- function(label, details = NULL) {
  if (!is.null(details) && nzchar(trimws(as.character(details)))) {
    cat("FTN_UNIT_UI_GUARDRAIL_PROGRESS=", label, "|", details, "\n", sep = "")
  } else {
    cat("FTN_UNIT_UI_GUARDRAIL_PROGRESS=", label, "\n", sep = "")
  }
}

add_check <- function(context, output_id, field, expected, observed, passed) {
  checks <<- rbind(
    checks,
    data.table::data.table(
      context = as.character(context),
      output_id = as.character(output_id),
      field = as.character(field),
      expected = as.character(expected),
      observed = as.character(observed),
      passed = isTRUE(passed)
    ),
    fill = TRUE
  )
}

ensure_map_measure_mode_quantity <- function(app) {
  comparison_mode_set <- set_input_and_confirm(app, "map_comparison_mode", "current", timeout_sec = 60)
  if (!isTRUE(comparison_mode_set$ok)) {
    stop(
      paste0("Could not set map_comparison_mode='current'. current_value=", comparison_mode_set$current_value),
      call. = FALSE
    )
  }

  mode_set <- set_input_and_confirm(app, "map_measure_mode", "quantity_value", timeout_sec = 60)
  if (!isTRUE(mode_set$ok)) {
    stop(
      paste0("Could not set map_measure_mode='quantity_value'. current_value=", mode_set$current_value),
      call. = FALSE
    )
  }

  list(
    map_comparison_mode = comparison_mode_set$current_value,
    map_measure_mode = mode_set$current_value
  )
}

run_context_checks <- function(context_name, candidate, expected_unit) {
  emit_probe_progress("context_start", paste0(context_name, "|", expected_unit))
  if (nzchar(default_main_tab)) {
    set_input_value(app, "main_tabs_panel", default_main_tab)
  }
  apply_vp_context(app, candidate, metric_target = "unit_value")

  emit_probe_progress("context_phase", paste0(context_name, "|comparison_plot"))
  comparison_snap <- wait_for_plotly_snapshot(app, "comparison_plot", timeout_sec = 90)
  if (is.null(comparison_snap)) {
    add_check(context_name, "comparison_plot", "snapshot_available", "non-null snapshot", "NULL", FALSE)
  } else {
    comp_title <- trim_scalar(comparison_snap$title)
    comp_yaxis <- trim_scalar(comparison_snap$yaxis_title)
    comp_hover <- as_chr_vec(comparison_snap$hovertemplates)
    comp_names <- as_chr_vec(comparison_snap$trace_names)

    add_check(context_name, "comparison_plot", "layout.title.text", expected_unit, comp_title, grepl(expected_unit, comp_title, fixed = TRUE))
    add_check(context_name, "comparison_plot", "layout.yaxis.title.text", expected_unit, comp_yaxis, grepl(expected_unit, comp_yaxis, fixed = TRUE))
    add_check(context_name, "comparison_plot", "data[].hovertemplate", expected_unit, paste(utils::head(comp_hover, 3L), collapse = " || "), contains_token(comp_hover, expected_unit))
    add_check(context_name, "comparison_plot", "data[].name", "non-empty trace names", paste(utils::head(comp_names, 5L), collapse = " || "), length(comp_names) > 0L)
  }

  summary_caption <- trim_scalar(get_datatable_caption(app, "summary_table"), default = "")
  add_check(context_name, "summary_table", "datatable.caption", "caption removed (empty)", summary_caption, !nzchar(summary_caption))

  if (tab_choice_available(app, "Heatmap")) {
    emit_probe_progress("context_phase", paste0(context_name, "|heatmap_plot"))
    set_input_value(app, "main_tabs_panel", "Heatmap")
    apply_vp_context(app, candidate, metric_target = "unit_value")
    heatmap_snap <- wait_for_plotly_snapshot(app, "heatmap_plot", timeout_sec = 90)
    if (is.null(heatmap_snap)) {
      add_check(context_name, "heatmap_plot", "snapshot_available", "non-null snapshot", "NULL", FALSE)
    } else {
      heatmap_title <- trim_scalar(heatmap_snap$title)
      heatmap_hover <- as_chr_vec(heatmap_snap$hovertemplates)
      heatmap_colorbar <- as_chr_vec(heatmap_snap$colorbar_titles)

      add_check(context_name, "heatmap_plot", "layout.title.text", expected_unit, heatmap_title, grepl(expected_unit, heatmap_title, fixed = TRUE))
      add_check(context_name, "heatmap_plot", "data[].hovertemplate", expected_unit, paste(utils::head(heatmap_hover, 3L), collapse = " || "), contains_token(heatmap_hover, expected_unit))
      add_check(context_name, "heatmap_plot", "data[].colorbar.title.text", expected_unit, paste(utils::head(heatmap_colorbar, 3L), collapse = " || "), contains_token(heatmap_colorbar, expected_unit))
    }
  } else {
    add_check(context_name, "heatmap_plot", "tab_available", "Heatmap tab available", "Heatmap tab not found", FALSE)
  }

  if (tab_choice_available(app, "Map")) {
    emit_probe_progress("context_phase", paste0(context_name, "|map_plot"))
    set_input_value(app, "main_tabs_panel", "Map")
    apply_vp_context(app, candidate, metric_target = "unit_value")
    map_mode_state <- ensure_map_measure_mode_quantity(app)
    map_snap <- wait_for_plotly_snapshot(app, "map_plot", timeout_sec = 120)
    if (is.null(map_snap)) {
      add_check(context_name, "map_plot", "snapshot_available", "non-null snapshot", "NULL", FALSE)
    } else {
      map_title <- trim_scalar(map_snap$title)
      map_hovertext <- as_chr_vec(map_snap$hovertexts)
      map_text <- as_chr_vec(map_snap$texts)
      map_colorbar <- as_chr_vec(map_snap$colorbar_titles)
      map_text_or_hover_values <- c(map_hovertext, map_text)

      add_check(context_name, "map_plot", "layout.title.text", expected_unit, map_title, grepl(expected_unit, map_title, fixed = TRUE))
      add_check(context_name, "map_plot", "data[].hovertext", expected_unit, paste(utils::head(map_hovertext, 3L), collapse = " || "), contains_token(map_hovertext, expected_unit))
      add_check(context_name, "map_plot", "data[].text_or_hovertext", expected_unit, paste(utils::head(map_text_or_hover_values, 3L), collapse = " || "), contains_token(map_text_or_hover_values, expected_unit))
      add_check(context_name, "map_plot", "data[].colorbar.title.text", expected_unit, paste(utils::head(map_colorbar, 3L), collapse = " || "), contains_token(map_colorbar, expected_unit))
      add_check(context_name, "map_plot", "map_comparison_mode", "current", map_mode_state$map_comparison_mode, identical(map_mode_state$map_comparison_mode, "current"))
      add_check(context_name, "map_plot", "map_measure_mode", "quantity_value", map_mode_state$map_measure_mode, identical(map_mode_state$map_measure_mode, "quantity_value"))
    }
  } else {
    add_check(context_name, "map_plot", "tab_available", "Map tab available", "Map tab not found", FALSE)
  }

  if (tab_choice_available(app, "Data")) {
    emit_probe_progress("context_phase", paste0(context_name, "|raw_data_table"))
    set_input_value(app, "main_tabs_panel", "Data")
    apply_vp_context(app, candidate, metric_target = "unit_value")
    raw_caption <- get_datatable_caption(app, "raw_data_table")
    add_check(context_name, "raw_data_table", "datatable.caption", expected_unit, raw_caption, grepl(expected_unit, raw_caption, fixed = TRUE))
  } else {
    add_check(context_name, "raw_data_table", "tab_available", "Data tab available", "Data tab not found", FALSE)
  }
}

emit_probe_progress("probe_phase", "run_context_checks_pound")
run_context_checks("pound", pound_candidate, "Dollars per pound")
if (gallon_reachable) {
  emit_probe_progress("probe_phase", "run_context_checks_gallon")
  run_context_checks("gallon", gallon_candidate, "Dollars per gallon")
}

if (tab_choice_available(app, "Pace Analysis Tool")) {
  emit_probe_progress("probe_phase", "pace_plot_checks")
  set_input_value(app, "main_tabs_panel", "Pace Analysis Tool")
  apply_vp_context(app, pound_candidate, metric_target = NULL)

  pace_metric_choices <- get_select_choices(app, "metric_choice")
  preferred_pace_metrics <- c("ytd_exports", "monthlyexports", "total_commitment", "currentMYNetSales")
  pace_metric <- preferred_pace_metrics[preferred_pace_metrics %in% pace_metric_choices]
  if (length(pace_metric) > 0L) {
    set_input_value(app, "metric_choice", pace_metric[[1L]])
  }

  pace_snap <- wait_for_plotly_snapshot(app, "pace_plot", timeout_sec = 90)
  if (is.null(pace_snap)) {
    add_check("pace", "pace_plot", "snapshot_available", "non-null snapshot", "NULL", FALSE)
  } else {
    pace_title <- trim_scalar(pace_snap$title)
    pace_yaxis <- trim_scalar(pace_snap$yaxis_title)
    pace_hover <- as_chr_vec(pace_snap$hovertemplates)
    pace_names <- as_chr_vec(pace_snap$trace_names)
    pace_unit <- ""
    if (grepl("\\(.*\\)", pace_yaxis)) {
      pace_unit <- sub("^.*\\((.*)\\).*$", "\\1", pace_yaxis)
    }

    add_check("pace", "pace_plot", "layout.yaxis.title.text", "Cumulative Value (...) includes explicit unit", pace_yaxis, grepl("\\(.*\\)", pace_yaxis))
    add_check("pace", "pace_plot", "layout.title.text", "title includes explicit unit", pace_title, grepl("\\(.*\\)", pace_title))
    add_check("pace", "pace_plot", "data[].name", "trace name includes explicit unit", paste(utils::head(pace_names, 5L), collapse = " || "), any(grepl("\\(.*\\)", pace_names)))

    if (nzchar(pace_unit)) {
      add_check("pace", "pace_plot", "data[].hovertemplate", paste0("contains ", pace_unit), paste(utils::head(pace_hover, 3L), collapse = " || "), contains_token(pace_hover, pace_unit))
    } else {
      add_check("pace", "pace_plot", "data[].hovertemplate", "contains extracted y-axis unit", paste(utils::head(pace_hover, 3L), collapse = " || "), FALSE)
    }
  }
} else {
  add_check("pace", "pace_plot", "tab_available", "Pace Analysis Tool tab available", "Pace Analysis Tool tab not found", FALSE)
}

failure_rows <- checks[passed == FALSE]
status <- if (nrow(failure_rows) == 0L) "PASS" else "FAIL"
emit_probe_progress("probe_phase", paste0("complete|status=", status, "|checks=", nrow(checks), "|failures=", nrow(failure_rows)))

log_dir <- file.path(repo_root, "Logs", "ftn_probe_runs")
dir.create(log_dir, recursive = TRUE, showWarnings = FALSE)

ts <- format(as.POSIXct(Sys.time(), tz = "UTC"), "%Y%m%dT%H%M%SZ", tz = "UTC")
checks_path <- file.path(log_dir, paste0("ftn_unit_display_ui_guardrail_", ts, "_checks.csv"))
summary_path <- file.path(log_dir, paste0("ftn_unit_display_ui_guardrail_", ts, "_summary.csv"))
failure_path <- if (nrow(failure_rows) > 0L) file.path(log_dir, paste0("ftn_unit_display_ui_guardrail_", ts, "_failures.csv")) else ""

summary_row <- data.frame(
  timestamp_utc = ts,
  status = status,
  total_checks = nrow(checks),
  failure_count = nrow(failure_rows),
  gallon_reachable = gallon_reachable,
  pound_group = trim_scalar(pound_candidate$Group),
  pound_subgroup = trim_scalar(pound_candidate$Subgroup),
  pound_segment = trim_scalar(pound_candidate$MarketSegment),
  pound_commodity_name = trim_scalar(pound_candidate$CommodityName),
  pound_detail = trim_scalar(pound_candidate$commodity),
  gallon_group = if (gallon_reachable) trim_scalar(gallon_candidate$Group) else "",
  gallon_subgroup = if (gallon_reachable) trim_scalar(gallon_candidate$Subgroup) else "",
  gallon_segment = if (gallon_reachable) trim_scalar(gallon_candidate$MarketSegment) else "",
  gallon_commodity_name = if (gallon_reachable) trim_scalar(gallon_candidate$CommodityName) else "",
  gallon_detail = if (gallon_reachable) trim_scalar(gallon_candidate$commodity) else "",
  stringsAsFactors = FALSE
)

utils::write.csv(checks, checks_path, row.names = FALSE, na = "")
utils::write.csv(summary_row, summary_path, row.names = FALSE, na = "")
if (nrow(failure_rows) > 0L) {
  utils::write.csv(failure_rows, failure_path, row.names = FALSE, na = "")
}

cat("FTN_UNIT_UI_GUARDRAIL_STATUS=", status, "\n", sep = "")
cat("FTN_UNIT_UI_GUARDRAIL_TOTAL_CHECKS=", nrow(checks), "\n", sep = "")
cat("FTN_UNIT_UI_GUARDRAIL_FAILURE_COUNT=", nrow(failure_rows), "\n", sep = "")
cat("FTN_UNIT_UI_GUARDRAIL_GALLON_REACHABLE=", gallon_reachable, "\n", sep = "")
cat("FTN_UNIT_UI_GUARDRAIL_SUMMARY_PATH=", summary_path, "\n", sep = "")
cat("FTN_UNIT_UI_GUARDRAIL_CHECKS_PATH=", checks_path, "\n", sep = "")
cat("FTN_UNIT_UI_GUARDRAIL_FAILURE_PATH=", failure_path, "\n", sep = "")

if (!identical(status, "PASS")) {
  stop("UI display-unit guardrail probe detected failing checks. See failure artifact.", call. = FALSE)
}
