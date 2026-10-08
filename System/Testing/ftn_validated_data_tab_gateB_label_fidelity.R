if (!requireNamespace("shinytest2", quietly = TRUE)) {
  stop("Package 'shinytest2' is required for ftn_validated_data_tab_gateB_label_fidelity.R", call. = FALSE)
}
if (!requireNamespace("data.table", quietly = TRUE)) {
  stop("Package 'data.table' is required for ftn_validated_data_tab_gateB_label_fidelity.R", call. = FALSE)
}
if (!requireNamespace("jsonlite", quietly = TRUE)) {
  stop("Package 'jsonlite' is required for ftn_validated_data_tab_gateB_label_fidelity.R", call. = FALSE)
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

safe_chr <- function(value) {
  out <- trimws(as.character(value %||% ""))
  out[is.na(out)] <- ""
  out
}

non_rollup_token <- function(value) {
  values <- safe_chr(value)
  nzchar(values) & !grepl("^__vp_rollup_all_", values)
}

collapse_preview <- function(values, max_n = 10L) {
  values <- safe_chr(values)
  values <- values[nzchar(values)]
  if (length(values) == 0L) {
    return("")
  }
  unique_values <- unique(values)
  paste(utils::head(unique_values, max_n), collapse = " || ")
}

probe_progress <- function(label, details = NULL) {
  if (!is.null(details) && nzchar(trimws(as.character(details)))) {
    cat("FTN_DATA_TAB_GATEB_PROGRESS=", label, "|", details, "\n", sep = "")
  } else {
    cat("FTN_DATA_TAB_GATEB_PROGRESS=", label, "\n", sep = "")
  }
  flush.console()
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

tab_choice_available <- function(app, tab_value) {
  script <- sprintf(
    "(function(){ var wanted='%s'; var docs=[document]; for (var i=0;i<window.frames.length;i++){ try{ if(window.frames[i].document) docs.push(window.frames[i].document); }catch(e){} } for (var j=0;j<docs.length;j++){ try{ var nodes=docs[j].querySelectorAll('[data-value]'); for (var k=0;k<nodes.length;k++){ var v=String(nodes[k].getAttribute('data-value') || '').trim(); if(v === wanted) return true; } }catch(e){} } return false; })();",
    tab_value
  )
  to_bool(run_js(app, script))
}

get_data_table_columns <- function(app, output_id) {
  script <- sprintf(
    "(function(){ var id = '%s'; var docs = [document]; for (var i = 0; i < window.frames.length; i++) { try { if (window.frames[i].document) docs.push(window.frames[i].document); } catch (e) {} } for (var j = 0; j < docs.length; j++) { try { var root = docs[j].getElementById(id); if (!root) continue; var headers = root.querySelectorAll('table thead th'); if (!headers || headers.length === 0) continue; var vals = []; for (var k = 0; k < headers.length; k++) { vals.push((headers[k].textContent || '').trim()); } return vals.join('|||'); } catch (e) {} } return ''; })();",
    output_id
  )

  out <- run_js(app, script)
  raw <- as.character(out %||% "")
  if (!nzchar(raw)) {
    return(character(0))
  }
  parts <- strsplit(raw, "\\|\\|\\|", fixed = FALSE)[[1]]
  parts <- trimws(parts)
  parts[nzchar(parts)]
}

wait_for_data_table_columns <- function(app, output_id = "raw_data_table", timeout_sec = 90, poll_sec = 0.5) {
  deadline <- Sys.time() + timeout_sec
  repeat {
    cols <- get_data_table_columns(app, output_id)
    if (length(cols) > 0L) {
      return(cols)
    }
    if (Sys.time() >= deadline) {
      return(character(0))
    }
    Sys.sleep(poll_sec)
  }
}

get_data_table_payload <- function(app, output_id = "raw_data_table") {
  script <- sprintf(
    "(function(){ var id='%s'; var docs=[document]; for (var i=0;i<window.frames.length;i++){ try{ if(window.frames[i].document) docs.push(window.frames[i].document); }catch(e){} } function clean(v){ if(v===null||v===undefined) return ''; var txt=String(v); txt=txt.replace(/<[^>]*>/g,' '); txt=txt.replace(/\\s+/g,' ').trim(); return txt; } for (var j=0;j<docs.length;j++){ try{ var root=docs[j].getElementById(id); if(!root) continue; var table=root.querySelector('table'); if(!table) continue; var headers=[]; var ths=table.querySelectorAll('thead th'); for (var h=0; h<ths.length; h++){ headers.push(clean(ths[h].textContent || '')); } if(window.jQuery && window.jQuery.fn && window.jQuery.fn.dataTable){ try{ var api=window.jQuery(table).DataTable(); if(api){ var apiHeaders=api.columns().header().toArray().map(function(x){ return clean(x && x.textContent ? x.textContent : ''); }); if(apiHeaders.length>0) headers=apiHeaders; var rawRows=api.rows({search:'applied'}).data().toArray(); var rows=[]; for (var r=0; r<rawRows.length; r++){ var row=rawRows[r]; if(Array.isArray(row)){ rows.push(row.map(clean)); } else if(row && typeof row==='object'){ var vals=[]; for (var c=0; c<headers.length; c++){ var key=headers[c]; vals.push(clean(row[key])); } rows.push(vals); } else { rows.push([clean(row)]); } } return JSON.stringify({columns: headers, rows: rows, mode: 'datatable_api'}); } }catch(e){} } var domRows=[]; var trs=table.querySelectorAll('tbody tr'); for (var tr=0; tr<trs.length; tr++){ var tds=trs[tr].querySelectorAll('td'); if(!tds || tds.length===0) continue; var vals=[]; for (var c=0; c<tds.length; c++){ vals.push(clean(tds[c].textContent || '')); } domRows.push(vals); } return JSON.stringify({columns: headers, rows: domRows, mode: 'dom'}); }catch(e){} } return ''; })();",
    output_id
  )

  raw <- trimws(as.character(run_js(app, script) %||% ""))
  if (!nzchar(raw)) {
    return(NULL)
  }

  tryCatch(
    jsonlite::fromJSON(raw, simplifyVector = TRUE),
    error = function(...) NULL
  )
}

payload_row_count <- function(payload) {
  rows <- payload$rows %||% NULL
  if (is.null(rows)) {
    return(0L)
  }
  if (is.data.frame(rows) || is.matrix(rows)) {
    return(nrow(rows))
  }
  if (is.list(rows)) {
    return(length(rows))
  }
  0L
}

wait_for_data_table_payload <- function(app, output_id = "raw_data_table", timeout_sec = 90, poll_sec = 0.5) {
  deadline <- Sys.time() + timeout_sec
  last_payload <- NULL

  repeat {
    payload <- get_data_table_payload(app, output_id)
    if (!is.null(payload)) {
      last_payload <- payload
      cols <- safe_chr(payload$columns %||% character(0))
      row_count <- payload_row_count(payload)
      if (length(cols) > 0L && row_count > 0L) {
        return(payload)
      }
    }

    if (Sys.time() >= deadline) {
      return(last_payload)
    }

    Sys.sleep(poll_sec)
  }
}

payload_rows_to_table <- function(payload) {
  cols <- safe_chr(payload$columns %||% character(0))
  rows <- payload$rows %||% NULL

  if (length(cols) == 0L || is.null(rows)) {
    return(data.table::data.table())
  }

  dt <- if (is.data.frame(rows) || is.matrix(rows)) {
    data.table::as.data.table(rows)
  } else if (is.list(rows)) {
    row_list <- lapply(rows, function(row) {
      vals <- safe_chr(unlist(row, recursive = TRUE, use.names = FALSE))
      as.list(vals)
    })
    data.table::rbindlist(row_list, fill = TRUE)
  } else {
    data.table::data.table()
  }

  if (nrow(dt) == 0L) {
    return(data.table::data.table())
  }

  if (ncol(dt) < length(cols)) {
    for (idx in (ncol(dt) + 1L):length(cols)) {
      dt[[paste0("V", idx)]] <- ""
    }
  }

  if (ncol(dt) > length(cols)) {
    dt <- dt[, seq_along(cols), with = FALSE]
  }

  data.table::setnames(dt, cols)
  for (column_name in names(dt)) {
    dt[[column_name]] <- safe_chr(dt[[column_name]])
  }

  dt
}

build_gateb_contexts <- function(artifact_dt) {
  required_cols <- c("Trade", "Group", "Subgroup", "MarketSegment", "CommodityName", "vp_is_rollup")
  missing_required <- setdiff(required_cols, names(artifact_dt))
  if (length(missing_required) > 0L) {
    stop(
      paste0("Artifact is missing required Gate B context columns: ", paste(missing_required, collapse = ", ")),
      call. = FALSE
    )
  }

  detail_col <- if ("commodity" %in% names(artifact_dt)) {
    "commodity"
  } else if ("CommodityDetail" %in% names(artifact_dt)) {
    "CommodityDetail"
  } else {
    ""
  }

  country_col <- if ("countryDescription" %in% names(artifact_dt)) {
    "countryDescription"
  } else if ("country" %in% names(artifact_dt)) {
    "country"
  } else {
    ""
  }

  if (!nzchar(detail_col)) {
    stop("Artifact is missing both 'commodity' and 'CommodityDetail' columns for Gate B context selection.", call. = FALSE)
  }
  if (!nzchar(country_col)) {
    stop("Artifact is missing both 'countryDescription' and 'country' columns for Gate B context selection.", call. = FALSE)
  }

  candidates <- artifact_dt[
    (is.na(vp_is_rollup) | vp_is_rollup == FALSE) &
      non_rollup_token(Group) &
      non_rollup_token(Subgroup) &
      non_rollup_token(MarketSegment) &
      tolower(safe_chr(Trade)) %in% c("export", "import") &
      safe_chr(CommodityName) == "Apples" &
      safe_chr(MarketSegment) == "Dried" &
      safe_chr(get(detail_col)) == "All",
    .(
      Trade = tolower(safe_chr(Trade)),
      Group = safe_chr(Group),
      Subgroup = safe_chr(Subgroup),
      MarketSegment = safe_chr(MarketSegment),
      CommodityName = safe_chr(CommodityName),
      CommodityDetail = safe_chr(get(detail_col)),
      CountryDescription = safe_chr(get(country_col)),
      market_year = suppressWarnings(as.integer(market_year %||% NA_integer_)),
      analysis_month = suppressWarnings(as.integer(analysis_month %||% NA_integer_))
    )
  ]

  candidates <- candidates[
    nzchar(Group) &
      nzchar(Subgroup) &
      nzchar(MarketSegment) &
      nzchar(CommodityName) &
      nzchar(CommodityDetail)
  ]

  if (nrow(candidates) == 0L) {
    stop("No non-rollup VP artifact rows found for Apples + Dried + All under export/import contexts.", call. = FALSE)
  }

  data.table::setorder(candidates, Trade, Group, Subgroup, CommodityName, CountryDescription, market_year, analysis_month)
  selected <- candidates[, .SD[1L], by = Trade]

  required_trades <- c("export", "import")
  missing_trades <- setdiff(required_trades, selected$Trade)
  if (length(missing_trades) > 0L) {
    trade_counts <- candidates[, .N, by = Trade]
    stop(
      paste0(
        "Gate B fixture selection could not find required trades: ",
        paste(missing_trades, collapse = ", "),
        ". Available counts: ",
        paste(paste0(trade_counts$Trade, "=", trade_counts$N), collapse = " | ")
      ),
      call. = FALSE
    )
  }

  selected[, context_name := paste0(Trade, "_apples_dried_all")]
  selected[]
}

choose_metric_for_context <- function(app, preferred = c("ytd_exports", "monthlyexports", "ytd_value", "monthlyvalue", "unit_value")) {
  metric_choices <- wait_for_select_choices(app, "metric_choice", timeout_sec = 60)
  if (length(metric_choices) == 0L) {
    return(resolve_effective_input_value(app, "metric_choice"))
  }

  pick <- preferred[preferred %in% metric_choices]
  if (length(pick) > 0L) {
    return(pick[[1L]])
  }

  metric_choices[[1L]]
}

apply_vp_context <- function(app, context_row) {
  context_name <- trim_scalar(context_row$context_name)
  expected_trade <- trim_scalar(context_row$Trade)
  expected_group <- trim_scalar(context_row$Group)
  expected_subgroup <- trim_scalar(context_row$Subgroup)
  expected_segment <- trim_scalar(context_row$MarketSegment)
  expected_commodity_name <- trim_scalar(context_row$CommodityName)
  expected_detail <- trim_scalar(context_row$CommodityDetail, default = "All")
  expected_country <- trim_scalar(context_row$CountryDescription, default = "")

  probe_progress("context_start", context_name)

  source_set <- set_input_and_confirm(app, "data_source_choice", "vp_trade", timeout_sec = 90)
  if (!isTRUE(source_set$ok)) {
    stop(
      paste0("Could not set data_source_choice='vp_trade'. current_value=", source_set$current_value),
      call. = FALSE
    )
  }

  trade_set <- set_input_and_confirm(app, "vp_trade_flow_choice", expected_trade, timeout_sec = 90)
  if (!isTRUE(trade_set$ok)) {
    stop(
      paste0("Could not set vp_trade_flow_choice='", expected_trade, "'. current_value=", trade_set$current_value),
      call. = FALSE
    )
  }

  probe_progress("context_phase", paste0(context_name, "|data_frequency_monthly"))
  try(set_input_by_name(app, "data_frequency", "monthly", wait_ = FALSE), silent = TRUE)
  invisible(safe_wait_for_idle(app, timeout = 60000))

  probe_progress("context_phase", paste0(context_name, "|hierarchy_set"))
  group_set <- set_input_and_confirm(app, "vp_group_choice", expected_group, timeout_sec = 90)
  subgroup_set <- set_input_and_confirm(app, "vp_subgroup_choice", expected_subgroup, timeout_sec = 90)
  segment_set <- set_input_and_confirm(app, "vp_market_segment_choice", expected_segment, timeout_sec = 90)
  commodity_name_set <- set_input_and_confirm(app, "vp_commodity_name_choice", expected_commodity_name, timeout_sec = 90)

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
  target_detail <- if (expected_detail %in% detail_choices) {
    expected_detail
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
  target_country <- if ("GRAND_TOTAL" %in% country_choices) {
    "GRAND_TOTAL"
  } else if (nzchar(expected_country) && expected_country %in% country_choices) {
    expected_country
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

  target_metric <- choose_metric_for_context(app)
  if (nzchar(target_metric)) {
    metric_set <- set_input_and_confirm(app, "metric_choice", target_metric, timeout_sec = 90)
    if (!isTRUE(metric_set$ok)) {
      stop(
        paste0("Could not set metric_choice='", target_metric, "'. current_value=", metric_set$current_value),
        call. = FALSE
      )
    }
  }

  if (isTRUE(tab_choice_available(app, "Data"))) {
    data_tab_set <- set_input_and_confirm(app, "main_tabs_panel", "Data", timeout_sec = 45)
    if (!isTRUE(data_tab_set$ok)) {
      try(set_input_by_name(app, "main_tabs_panel", "Data", wait_ = FALSE), silent = TRUE)
      safe_wait_for_idle(app, timeout = 60000)
    }
  } else {
    stop("Data tab is not available in the rendered app session.", call. = FALSE)
  }

  list(
    expected_trade = expected_trade,
    expected_group = expected_group,
    expected_subgroup = expected_subgroup,
    expected_segment = expected_segment,
    expected_commodity_name = expected_commodity_name,
    expected_detail = target_detail,
    expected_country = target_country,
    metric_choice = target_metric
  )
}

run_context_checks <- function(app, context_row) {
  checks <- data.table::data.table(
    context = character(0),
    phase = character(0),
    field = character(0),
    expected = character(0),
    observed = character(0),
    passed = logical(0)
  )

  failure_rows <- data.table::data.table(
    context = character(0),
    reason = character(0),
    Trade = character(0),
    Group = character(0),
    Subgroup = character(0),
    MarketSegment = character(0),
    CommodityName = character(0),
    CommodityDetail = character(0),
    GeographicDesc = character(0),
    Year = character(0),
    MonthNumber = character(0),
    MarketYear = character(0),
    Amount = character(0)
  )

  add_check <- function(context_name, phase, field, expected, observed, passed) {
    checks <<- data.table::rbindlist(
      list(
        checks,
        data.table::data.table(
          context = as.character(context_name),
          phase = as.character(phase),
          field = as.character(field),
          expected = as.character(expected),
          observed = as.character(observed),
          passed = isTRUE(passed)
        )
      ),
      fill = TRUE
    )
  }

  append_failures <- function(context_name, reason, dt, mask) {
    if (!is.logical(mask) || length(mask) != nrow(dt) || !any(mask, na.rm = TRUE)) {
      return(invisible(NULL))
    }

    local <- data.table::data.table(
      context = context_name,
      reason = reason,
      Trade = if ("Trade" %in% names(dt)) safe_chr(dt$Trade) else "",
      Group = if ("Group" %in% names(dt)) safe_chr(dt$Group) else "",
      Subgroup = if ("Subgroup" %in% names(dt)) safe_chr(dt$Subgroup) else "",
      MarketSegment = if ("MarketSegment" %in% names(dt)) safe_chr(dt$MarketSegment) else "",
      CommodityName = if ("CommodityName" %in% names(dt)) safe_chr(dt$CommodityName) else "",
      CommodityDetail = if ("CommodityDetail" %in% names(dt)) safe_chr(dt$CommodityDetail) else "",
      GeographicDesc = if ("GeographicDesc" %in% names(dt)) safe_chr(dt$GeographicDesc) else "",
      Year = if ("Year" %in% names(dt)) safe_chr(dt$Year) else "",
      MonthNumber = if ("MonthNumber" %in% names(dt)) safe_chr(dt$MonthNumber) else "",
      MarketYear = if ("MarketYear" %in% names(dt)) safe_chr(dt$MarketYear) else "",
      Amount = if ("Amount" %in% names(dt)) safe_chr(dt$Amount) else ""
    )

    local <- local[mask]
    if (nrow(local) > 250L) {
      local <- local[1:250]
    }

    failure_rows <<- data.table::rbindlist(list(failure_rows, local), fill = TRUE)
    invisible(NULL)
  }

  context_name <- trim_scalar(context_row$context_name)
  context_state <- apply_vp_context(app, context_row)

  if (!nzchar(trim_scalar(context_state$metric_choice))) {
    add_check(
      context_name,
      "context",
      "metric_choice_selected",
      "non-empty metric choice",
      "",
      FALSE
    )
  }

  probe_progress("context_phase", paste0(context_name, "|raw_data_payload"))
  raw_payload <- wait_for_data_table_payload(app, "raw_data_table", timeout_sec = 90)
  raw_columns <- if (is.null(raw_payload)) character(0) else safe_chr(raw_payload$columns %||% character(0))
  raw_dt <- if (is.null(raw_payload)) data.table::data.table() else payload_rows_to_table(raw_payload)

  required_raw_cols <- c(
    "Trade", "GeographicDesc", "Year", "MonthNumber", "MarketYear",
    "Group", "Subgroup", "MarketSegment", "CommodityName", "CommodityDetail",
    "UnitType", "UnitDesc", "Amount"
  )

  add_check(
    context_name,
    "raw_data_table",
    "required_columns_present",
    paste(required_raw_cols, collapse = " | "),
    paste(raw_columns, collapse = " | "),
    all(required_raw_cols %in% raw_columns)
  )

  add_check(
    context_name,
    "raw_data_table",
    "row_count_nonzero",
    "> 0",
    as.character(nrow(raw_dt)),
    nrow(raw_dt) > 0L
  )

  required_label_cols <- c("Trade", "Group", "Subgroup", "MarketSegment", "CommodityName", "CommodityDetail")
  add_check(
    context_name,
    "raw_data_table",
    "required_label_columns_present",
    paste(required_label_cols, collapse = " | "),
    paste(raw_columns, collapse = " | "),
    all(required_label_cols %in% raw_columns)
  )

  summary_row <- data.table::data.table(
    context = context_name,
    selected_trade = context_state$expected_trade,
    selected_group = context_state$expected_group,
    selected_subgroup = context_state$expected_subgroup,
    selected_market_segment = context_state$expected_segment,
    selected_commodity_name = context_state$expected_commodity_name,
    selected_commodity_detail = context_state$expected_detail,
    selected_country = context_state$expected_country,
    metric_choice = context_state$metric_choice,
    raw_data_row_count = nrow(raw_dt),
    unique_market_segment_count = 0L,
    unique_market_segment_values = "",
    unique_commodity_detail_values = "",
    market_segment_semicolon_rows = 0L,
    market_segment_token_rows = 0L,
    segment_mismatch_rows = 0L,
    detail_mismatch_rows = 0L,
    group_mismatch_rows = 0L,
    subgroup_mismatch_rows = 0L,
    trade_mismatch_rows = 0L
  )

  if (nrow(raw_dt) > 0L && all(required_label_cols %in% names(raw_dt))) {
    trade_values <- tolower(safe_chr(raw_dt$Trade))
    group_values <- safe_chr(raw_dt$Group)
    subgroup_values <- safe_chr(raw_dt$Subgroup)
    segment_values <- safe_chr(raw_dt$MarketSegment)
    commodity_name_values <- safe_chr(raw_dt$CommodityName)
    detail_values <- safe_chr(raw_dt$CommodityDetail)

    expected_trade <- tolower(trim_scalar(context_state$expected_trade))
    expected_group <- trim_scalar(context_state$expected_group)
    expected_subgroup <- trim_scalar(context_state$expected_subgroup)
    expected_segment <- trim_scalar(context_state$expected_segment)
    expected_commodity_name <- trim_scalar(context_state$expected_commodity_name)
    expected_detail <- trim_scalar(context_state$expected_detail)
    expected_detail_lower <- tolower(expected_detail)

    detail_ok_mask <- if (expected_detail_lower %in% c("all", "__all__")) {
      grepl("^all(\\s*-\\s*excluding\\s*juice)?$", tolower(detail_values))
    } else {
      detail_values == expected_detail
    }
    detail_expected_display <- if (expected_detail_lower %in% c("all", "__all__")) {
      "All or All - excluding juice"
    } else {
      expected_detail
    }

    trade_mismatch_mask <- trade_values != expected_trade
    group_mismatch_mask <- group_values != expected_group
    subgroup_mismatch_mask <- subgroup_values != expected_subgroup
    segment_mismatch_mask <- segment_values != expected_segment
    commodity_name_mismatch_mask <- commodity_name_values != expected_commodity_name
    detail_mismatch_mask <- !detail_ok_mask

    market_segment_semicolon_mask <- grepl(";", segment_values, fixed = TRUE)
    market_segment_token_mask <- grepl("^__vp_rollup_all_", segment_values)
    commodity_detail_semicolon_mask <- grepl(";", detail_values, fixed = TRUE)
    commodity_detail_token_mask <- grepl("^__vp_rollup_all_", detail_values)

    summary_row$unique_market_segment_count <- length(unique(segment_values))
    summary_row$unique_market_segment_values <- collapse_preview(segment_values)
    summary_row$unique_commodity_detail_values <- collapse_preview(detail_values)
    summary_row$market_segment_semicolon_rows <- sum(market_segment_semicolon_mask, na.rm = TRUE)
    summary_row$market_segment_token_rows <- sum(market_segment_token_mask, na.rm = TRUE)
    summary_row$segment_mismatch_rows <- sum(segment_mismatch_mask, na.rm = TRUE)
    summary_row$detail_mismatch_rows <- sum(detail_mismatch_mask, na.rm = TRUE)
    summary_row$group_mismatch_rows <- sum(group_mismatch_mask, na.rm = TRUE)
    summary_row$subgroup_mismatch_rows <- sum(subgroup_mismatch_mask, na.rm = TRUE)
    summary_row$trade_mismatch_rows <- sum(trade_mismatch_mask, na.rm = TRUE)

    add_check(
      context_name,
      "raw_data_table",
      "all_trade_values_match_selected",
      expected_trade,
      collapse_preview(trade_values),
      !any(trade_mismatch_mask)
    )
    add_check(
      context_name,
      "raw_data_table",
      "all_group_values_match_selected",
      expected_group,
      collapse_preview(group_values),
      !any(group_mismatch_mask)
    )
    add_check(
      context_name,
      "raw_data_table",
      "all_subgroup_values_match_selected",
      expected_subgroup,
      collapse_preview(subgroup_values),
      !any(subgroup_mismatch_mask)
    )
    add_check(
      context_name,
      "raw_data_table",
      "all_market_segment_values_match_selected",
      expected_segment,
      collapse_preview(segment_values),
      !any(segment_mismatch_mask)
    )
    add_check(
      context_name,
      "raw_data_table",
      "all_commodity_name_values_match_selected",
      expected_commodity_name,
      collapse_preview(commodity_name_values),
      !any(commodity_name_mismatch_mask)
    )
    add_check(
      context_name,
      "raw_data_table",
      "all_commodity_detail_values_match_selected",
      detail_expected_display,
      collapse_preview(detail_values),
      !any(detail_mismatch_mask)
    )
    add_check(
      context_name,
      "raw_data_table",
      "market_segment_no_semicolon_join",
      "0 rows with ';'",
      as.character(sum(market_segment_semicolon_mask, na.rm = TRUE)),
      !any(market_segment_semicolon_mask)
    )
    add_check(
      context_name,
      "raw_data_table",
      "market_segment_no_rollup_token",
      "0 rows with __vp_rollup_all_ prefix",
      as.character(sum(market_segment_token_mask, na.rm = TRUE)),
      !any(market_segment_token_mask)
    )
    add_check(
      context_name,
      "raw_data_table",
      "commodity_detail_no_semicolon_join",
      "0 rows with ';'",
      as.character(sum(commodity_detail_semicolon_mask, na.rm = TRUE)),
      !any(commodity_detail_semicolon_mask)
    )
    add_check(
      context_name,
      "raw_data_table",
      "commodity_detail_no_rollup_token",
      "0 rows with __vp_rollup_all_ prefix",
      as.character(sum(commodity_detail_token_mask, na.rm = TRUE)),
      !any(commodity_detail_token_mask)
    )

    append_failures(context_name, "trade_mismatch", raw_dt, trade_mismatch_mask)
    append_failures(context_name, "group_mismatch", raw_dt, group_mismatch_mask)
    append_failures(context_name, "subgroup_mismatch", raw_dt, subgroup_mismatch_mask)
    append_failures(context_name, "market_segment_mismatch", raw_dt, segment_mismatch_mask)
    append_failures(context_name, "market_segment_semicolon_join", raw_dt, market_segment_semicolon_mask)
    append_failures(context_name, "market_segment_rollup_token", raw_dt, market_segment_token_mask)
    append_failures(context_name, "commodity_name_mismatch", raw_dt, commodity_name_mismatch_mask)
    append_failures(context_name, "commodity_detail_mismatch", raw_dt, detail_mismatch_mask)
    append_failures(context_name, "commodity_detail_semicolon_join", raw_dt, commodity_detail_semicolon_mask)
    append_failures(context_name, "commodity_detail_rollup_token", raw_dt, commodity_detail_token_mask)
  }

  list(checks = checks, failures = failure_rows, summary = summary_row)
}

repo_root <- resolve_repo_root()
Sys.setenv(NOT_CRAN = "true")
artifact_path <- file.path(repo_root, "System", "Processed Data", "vp_trade_monthly_pre.rds")

if (!file.exists(artifact_path)) {
  stop(
    paste0("Missing artifact: ", artifact_path, ". Run Master_FTN.R with VP_MASTER_UPDATES=vp_trade,metadata first."),
    call. = FALSE
  )
}

probe_progress("load_artifact")
artifact_object <- readRDS(artifact_path)
artifact_df <- if (is.data.frame(artifact_object)) {
  artifact_object
} else if (is.list(artifact_object) && is.data.frame(artifact_object$data)) {
  artifact_object$data
} else {
  data.frame()
}

if (!is.data.frame(artifact_df) || nrow(artifact_df) == 0L) {
  stop("VP trade artifact has no rows for Gate B fixture selection.", call. = FALSE)
}

artifact_dt <- data.table::as.data.table(artifact_df)
contexts_dt <- build_gateb_contexts(artifact_dt)
probe_progress("context_fixture_count", as.character(nrow(contexts_dt)))

required_controls <- c(
  "data_source_choice",
  "main_tabs_panel",
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
  probe_progress("launch_attempt", as.character(attempt))
  app_name <- paste0("ftn_data_tab_gateB_label_fidelity_", attempt, "_", as.integer(as.numeric(Sys.time())))
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
    probe_progress("launch_attempt_ready", as.character(attempt))
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

all_checks <- data.table::data.table(
  context = character(0),
  phase = character(0),
  field = character(0),
  expected = character(0),
  observed = character(0),
  passed = logical(0)
)
all_failures <- data.table::data.table(
  context = character(0),
  reason = character(0),
  Trade = character(0),
  Group = character(0),
  Subgroup = character(0),
  MarketSegment = character(0),
  CommodityName = character(0),
  CommodityDetail = character(0),
  GeographicDesc = character(0),
  Year = character(0),
  MonthNumber = character(0),
  MarketYear = character(0),
  Amount = character(0)
)
all_summaries <- data.table::data.table()

for (idx in seq_len(nrow(contexts_dt))) {
  context_row <- contexts_dt[idx]
  context_name <- trim_scalar(context_row$context_name)
  probe_progress("context_dispatch", paste0(context_name, "|", idx, "_of_", nrow(contexts_dt)))

  context_result <- run_context_checks(app, context_row)
  all_checks <- data.table::rbindlist(list(all_checks, context_result$checks), fill = TRUE)
  all_failures <- data.table::rbindlist(list(all_failures, context_result$failures), fill = TRUE)
  all_summaries <- data.table::rbindlist(list(all_summaries, context_result$summary), fill = TRUE)
}

failure_checks <- all_checks[passed == FALSE]
status <- if (nrow(failure_checks) == 0L) "PASS" else "FAIL"
probe_progress("complete", paste0("status=", status, "|checks=", nrow(all_checks), "|failures=", nrow(failure_checks)))

log_dir <- file.path(repo_root, "Logs", "ftn_probe_runs")
dir.create(log_dir, recursive = TRUE, showWarnings = FALSE)
ts <- format(as.POSIXct(Sys.time(), tz = "UTC"), "%Y%m%dT%H%M%SZ", tz = "UTC")
checks_path <- file.path(log_dir, paste0("ftn_data_tab_gateB_label_fidelity_", ts, "_checks.csv"))
summary_path <- file.path(log_dir, paste0("ftn_data_tab_gateB_label_fidelity_", ts, "_summary.csv"))
failure_path <- if (nrow(all_failures) > 0L) file.path(log_dir, paste0("ftn_data_tab_gateB_label_fidelity_", ts, "_failures.csv")) else ""

if (nrow(all_summaries) == 0L) {
  all_summaries <- data.table::data.table(
    context = character(0),
    selected_trade = character(0),
    selected_group = character(0),
    selected_subgroup = character(0),
    selected_market_segment = character(0),
    selected_commodity_name = character(0),
    selected_commodity_detail = character(0),
    selected_country = character(0),
    metric_choice = character(0),
    raw_data_row_count = integer(0),
    unique_market_segment_count = integer(0),
    unique_market_segment_values = character(0),
    unique_commodity_detail_values = character(0),
    market_segment_semicolon_rows = integer(0),
    market_segment_token_rows = integer(0),
    segment_mismatch_rows = integer(0),
    detail_mismatch_rows = integer(0),
    group_mismatch_rows = integer(0),
    subgroup_mismatch_rows = integer(0),
    trade_mismatch_rows = integer(0)
  )
}

summary_meta <- data.table::data.table(
  status = status,
  context_count = nrow(contexts_dt),
  total_checks = nrow(all_checks),
  failed_checks = nrow(failure_checks),
  failure_rows = nrow(all_failures),
  checks_path = checks_path,
  failures_path = failure_path,
  artifact_path = artifact_path,
  timestamp_utc = ts
)

all_summaries[, `:=`(
  status = summary_meta$status[[1L]],
  context_count = summary_meta$context_count[[1L]],
  total_checks = summary_meta$total_checks[[1L]],
  failed_checks = summary_meta$failed_checks[[1L]],
  failure_rows = summary_meta$failure_rows[[1L]],
  checks_path = summary_meta$checks_path[[1L]],
  failures_path = summary_meta$failures_path[[1L]],
  artifact_path = summary_meta$artifact_path[[1L]],
  timestamp_utc = summary_meta$timestamp_utc[[1L]]
)]

data.table::fwrite(all_checks, checks_path)
data.table::fwrite(all_summaries, summary_path)
if (nrow(all_failures) > 0L) {
  data.table::fwrite(all_failures, failure_path)
}

cat("FTN_DATA_TAB_GATEB_STATUS=", status, "\n", sep = "")
cat("FTN_DATA_TAB_GATEB_CONTEXT_COUNT=", nrow(contexts_dt), "\n", sep = "")
cat("FTN_DATA_TAB_GATEB_TOTAL_CHECKS=", nrow(all_checks), "\n", sep = "")
cat("FTN_DATA_TAB_GATEB_FAILURE_COUNT=", nrow(failure_checks), "\n", sep = "")
cat("FTN_DATA_TAB_GATEB_FAILURE_ROWS=", nrow(all_failures), "\n", sep = "")
cat("FTN_DATA_TAB_GATEB_SUMMARY_PATH=", summary_path, "\n", sep = "")
cat("FTN_DATA_TAB_GATEB_CHECKS_PATH=", checks_path, "\n", sep = "")
cat("FTN_DATA_TAB_GATEB_FAILURE_PATH=", failure_path, "\n", sep = "")

if (!identical(status, "PASS")) {
  preview <- utils::head(all_failures, 15L)
  cat("FTN_DATA_TAB_GATEB_FAILURE_PREVIEW_START\n")
  utils::write.table(preview, row.names = FALSE, sep = "|", quote = FALSE)
  cat("FTN_DATA_TAB_GATEB_FAILURE_PREVIEW_END\n")
  stop("Gate B label-fidelity probe detected failing checks. See failure artifacts.", call. = FALSE)
}
