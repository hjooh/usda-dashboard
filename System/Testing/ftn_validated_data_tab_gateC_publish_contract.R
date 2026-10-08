if (!requireNamespace("shinytest2", quietly = TRUE)) {
  stop("Package 'shinytest2' is required for ftn_validated_data_tab_gateC_publish_contract.R", call. = FALSE)
}
if (!requireNamespace("data.table", quietly = TRUE)) {
  stop("Package 'data.table' is required for ftn_validated_data_tab_gateC_publish_contract.R", call. = FALSE)
}
if (!requireNamespace("jsonlite", quietly = TRUE)) {
  stop("Package 'jsonlite' is required for ftn_validated_data_tab_gateC_publish_contract.R", call. = FALSE)
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
    cat("FTN_DATA_TAB_GATEC_PROGRESS=", label, "|", details, "\n", sep = "")
  } else {
    cat("FTN_DATA_TAB_GATEC_PROGRESS=", label, "\n", sep = "")
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

get_select_choice_label <- function(app, input_id, selected_value) {
  selected_value <- trim_scalar(selected_value)
  if (!nzchar(selected_value)) {
    return("")
  }

  script <- sprintf(
    "(function(){ var id='%s'; var selected='%s'; var docs=[document]; for (var i=0;i<window.frames.length;i++){ try{ if(window.frames[i].document) docs.push(window.frames[i].document); }catch(e){} } for (var j=0;j<docs.length;j++){ try{ var el=docs[j].getElementById(id); if(!el) continue; if(el.selectize && el.selectize.options){ var opt=el.selectize.options[selected]; if(opt){ if(opt.text) return String(opt.text).trim(); if(opt.label) return String(opt.label).trim(); } } if(el.options){ for(var k=0;k<el.options.length;k++){ if(String(el.options[k].value || '').trim() === selected){ return String(el.options[k].text || '').trim(); } } } }catch(e){} } return ''; })();",
    input_id,
    selected_value
  )

  trim_scalar(run_js(app, script), default = "")
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

list_csv_files <- function(path) {
  if (!dir.exists(path)) {
    return(character(0))
  }
  files <- list.files(path, pattern = "\\\\.csv$", full.names = TRUE)
  if (length(files) == 0L) {
    return(character(0))
  }
  normalizePath(files, winslash = "/", mustWork = FALSE)
}

find_new_publish_file <- function(before_files, after_files, before_latest_time = as.POSIXct("1970-01-01", tz = "UTC")) {
  new_files <- setdiff(after_files, before_files)

  if (length(new_files) == 0L && length(after_files) > 0L) {
    info <- file.info(after_files)
    recent_mask <- !is.na(info$mtime) & info$mtime > before_latest_time
    new_files <- after_files[recent_mask]
  }

  if (length(new_files) == 0L) {
    return("")
  }

  info <- file.info(new_files)
  if (nrow(info) == 0L || all(is.na(info$mtime))) {
    return(new_files[[length(new_files)]])
  }

  new_files[[which.max(info$mtime)]]
}

capture_published_csv <- function(app, publish_dir, timeout_sec = 120, poll_sec = 0.5) {
  if (!dir.exists(publish_dir)) {
    dir.create(publish_dir, recursive = TRUE, showWarnings = FALSE)
  }

  before_files <- list_csv_files(publish_dir)
  before_latest <- as.POSIXct("1970-01-01 00:00:00", tz = "UTC")
  if (length(before_files) > 0L) {
    before_info <- file.info(before_files)
    if (nrow(before_info) > 0L && any(!is.na(before_info$mtime))) {
      before_latest <- max(before_info$mtime, na.rm = TRUE)
    }
  }

  poll_for_candidate <- function(wait_timeout_sec) {
    deadline <- Sys.time() + wait_timeout_sec
    repeat {
      after_files <- list_csv_files(publish_dir)
      candidate <- find_new_publish_file(before_files, after_files, before_latest_time = before_latest)
      if (nzchar(candidate) && file.exists(candidate)) {
        return(candidate)
      }

      if (Sys.time() >= deadline) {
        return("")
      }

      Sys.sleep(poll_sec)
    }
  }

  trigger_publish <- function(strategy = c("set_click", "js_click")) {
    strategy <- match.arg(strategy)
    if (identical(strategy, "set_click")) {
      try(set_input_by_name(app, "publish_filtered_data", "click", wait_ = FALSE), silent = TRUE)
      safe_wait_for_idle(app, timeout = 120000)
      return(invisible(NULL))
    }

    click_script <- "(function(){ var id='publish_filtered_data'; var docs=[document]; for (var i=0;i<window.frames.length;i++){ try{ if(window.frames[i].document) docs.push(window.frames[i].document);}catch(e){} } for (var j=0;j<docs.length;j++){ try{ var el=docs[j].getElementById(id); if(!el) continue; if (typeof el.click === 'function') { el.click(); return true; } }catch(e){} } return false; })();"
    try(run_js(app, click_script), silent = TRUE)
    safe_wait_for_idle(app, timeout = 120000)
    invisible(NULL)
  }

  first_wait <- max(10, min(45, as.integer(timeout_sec * 0.4)))
  second_wait <- max(10, min(45, as.integer(timeout_sec * 0.35)))
  final_wait <- max(10, timeout_sec - first_wait - second_wait)

  trigger_publish("set_click")
  candidate <- poll_for_candidate(first_wait)
  if (nzchar(candidate) && file.exists(candidate)) {
    return(candidate)
  }

  trigger_publish("js_click")
  candidate <- poll_for_candidate(second_wait)
  if (nzchar(candidate) && file.exists(candidate)) {
    return(candidate)
  }

  candidate <- poll_for_candidate(final_wait)
  if (nzchar(candidate) && file.exists(candidate)) {
    return(candidate)
  }

  ""
}

parse_amount_numeric <- function(values) {
  raw <- safe_chr(values)
  raw <- gsub(",", "", raw, fixed = TRUE)
  suppressWarnings(as.numeric(raw))
}

read_published_csv <- function(path) {
  if (!nzchar(path) || !file.exists(path)) {
    return(data.table::data.table())
  }

  out <- tryCatch(
    data.table::fread(path, colClasses = "character"),
    error = function(...) NULL
  )

  if (is.null(out)) {
    out <- tryCatch(
      data.table::as.data.table(read.csv(path, stringsAsFactors = FALSE, check.names = FALSE, colClasses = "character")),
      error = function(...) data.table::data.table()
    )
  }

  for (column_name in names(out)) {
    out[[column_name]] <- safe_chr(out[[column_name]])
  }

  out
}

build_baseline_context <- function(artifact_dt) {
  required_cols <- c("Trade", "Group", "Subgroup", "MarketSegment", "CommodityName", "vp_is_rollup")
  missing_required <- setdiff(required_cols, names(artifact_dt))
  if (length(missing_required) > 0L) {
    stop(
      paste0("Artifact is missing required Gate C context columns: ", paste(missing_required, collapse = ", ")),
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
    stop("Artifact is missing both 'commodity' and 'CommodityDetail' columns for Gate C context selection.", call. = FALSE)
  }
  if (!nzchar(country_col)) {
    stop("Artifact is missing both 'countryDescription' and 'country' columns for Gate C context selection.", call. = FALSE)
  }

  candidates <- artifact_dt[
    (is.na(vp_is_rollup) | vp_is_rollup == FALSE) &
      non_rollup_token(Group) &
      non_rollup_token(Subgroup) &
      non_rollup_token(MarketSegment) &
      tolower(safe_chr(Trade)) == "export" &
      safe_chr(CommodityName) == "Apples" &
      safe_chr(MarketSegment) == "Dried" &
      safe_chr(get(detail_col)) == "All",
    .(
      Trade = "export",
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
    stop("No non-rollup VP artifact rows found for export apples + dried + all baseline context.", call. = FALSE)
  }

  data.table::setorder(candidates, Group, Subgroup, CommodityName, CountryDescription, market_year, analysis_month)
  baseline <- candidates[1L]
  baseline[, context_name := "export_apples_dried_all_baseline"]
  baseline[]
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

resolve_expected_vp_metric_label <- function(metric_code, trade_flow = "export") {
  flow <- if (identical(trade_flow, "import")) "import" else "export"
  lookup <- c(
    monthlyexports = if (identical(flow, "import")) "Monthly Imports" else "Monthly Exports",
    ytd_exports = if (identical(flow, "import")) "Accumulated Imports" else "Accumulated Exports",
    total_commitment = "Total Commitment",
    outstandingSales = "Outstanding Sales",
    grossNewSales = "Gross New Sales",
    currentMYNetSales = "Current MY Net Sales",
    nextMYOutstandingSales = "Next MY Outstanding Sales",
    nextMYNetSales = "Next MY Net Sales",
    monthlyvalue = if (identical(flow, "import")) "Monthly Imports Value" else "Monthly Value",
    ytd_value = if (identical(flow, "import")) "Accumulated Imports Value" else "Accumulated Value",
    unit_value = if (identical(flow, "import")) "Import Unit Value" else "Export Unit Value",
    ytd_unit_value = if (identical(flow, "import")) "Accumulated Import Unit Value" else "Accumulated Export Unit Value"
  )

  label <- unname(lookup[[metric_code]])
  label <- trim_scalar(label)
  if (!nzchar(label)) trim_scalar(metric_code, default = "Metric") else label
}

apply_vp_context <- function(app, context_row) {
  context_name <- trim_scalar(context_row$context_name)
  expected_trade <- trim_scalar(context_row$Trade, default = "export")
  expected_group <- trim_scalar(context_row$Group)
  expected_subgroup <- trim_scalar(context_row$Subgroup)
  expected_segment <- trim_scalar(context_row$MarketSegment)
  expected_commodity_name <- trim_scalar(context_row$CommodityName)
  expected_detail <- trim_scalar(context_row$CommodityDetail, default = "All")

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
  } else if (length(country_choices) > 0L) {
    country_choices[[1L]]
  } else {
    ""
  }

  if (!nzchar(target_country)) {
    stop("No country_choice values available for baseline context.", call. = FALSE)
  }

  country_set <- set_input_and_confirm(app, "country_choice", target_country, timeout_sec = 60)
  if (!isTRUE(country_set$ok)) {
    stop(
      paste0("Could not set country_choice='", target_country, "'. current_value=", country_set$current_value),
      call. = FALSE
    )
  }

  target_metric <- choose_metric_for_context(app)
  if (!nzchar(target_metric)) {
    stop("No metric_choice value available for baseline context.", call. = FALSE)
  }

  metric_set <- set_input_and_confirm(app, "metric_choice", target_metric, timeout_sec = 90)
  if (!isTRUE(metric_set$ok)) {
    stop(
      paste0("Could not set metric_choice='", target_metric, "'. current_value=", metric_set$current_value),
      call. = FALSE
    )
  }

  metric_label <- resolve_expected_vp_metric_label(target_metric, trade_flow = expected_trade)

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
    metric_choice = target_metric,
    metric_label = metric_label
  )
}

normalize_for_amount_compare <- function(dt, key_cols, amount_col = "Amount") {
  if (!is.data.frame(dt) || nrow(dt) == 0L) {
    return(data.table::data.table())
  }

  if (!all(c(key_cols, amount_col) %in% names(dt))) {
    return(data.table::data.table())
  }

  out <- data.table::copy(data.table::as.data.table(dt))
  for (column_name in key_cols) {
    out[[column_name]] <- safe_chr(out[[column_name]])
  }
  out[, AmountValue := parse_amount_numeric(get(amount_col))]
  out[, compare_row_id := seq_len(.N), by = key_cols]
  out
}

compare_amount_tables <- function(left_dt, right_dt, key_cols, amount_col = "Amount", tolerance = 1e-6) {
  left_norm <- normalize_for_amount_compare(left_dt, key_cols = key_cols, amount_col = amount_col)
  right_norm <- normalize_for_amount_compare(right_dt, key_cols = key_cols, amount_col = amount_col)

  if (nrow(left_norm) == 0L || nrow(right_norm) == 0L) {
    return(list(
      merged = data.table::data.table(),
      missing_left = data.table::data.table(),
      missing_right = data.table::data.table(),
      mismatches = data.table::data.table()
    ))
  }

  compare_keys <- c(key_cols, "compare_row_id")
  merged <- merge(
    left_norm[, c(compare_keys, "AmountValue"), with = FALSE],
    right_norm[, c(compare_keys, "AmountValue"), with = FALSE],
    by = compare_keys,
    all = TRUE,
    suffixes = c("_left", "_right")
  )

  missing_left <- merged[is.na(AmountValue_left)]
  missing_right <- merged[is.na(AmountValue_right)]
  mismatches <- merged[
    !is.na(AmountValue_left) & !is.na(AmountValue_right) & abs(AmountValue_left - AmountValue_right) > tolerance
  ]

  list(
    merged = merged,
    missing_left = missing_left,
    missing_right = missing_right,
    mismatches = mismatches
  )
}

run_gatec_checks <- function(app, context_row, publish_dir) {
  checks <- data.table::data.table(
    context = character(0),
    phase = character(0),
    field = character(0),
    expected = character(0),
    observed = character(0),
    passed = logical(0)
  )

  failures <- data.table::data.table(
    context = character(0),
    reason = character(0),
    Trade = character(0),
    GeographicDesc = character(0),
    Year = character(0),
    MonthNumber = character(0),
    MarketYear = character(0),
    Group = character(0),
    Subgroup = character(0),
    MarketSegment = character(0),
    CommodityName = character(0),
    CommodityDetail = character(0),
    UnitType = character(0),
    UnitDesc = character(0),
    compare_row_id = character(0),
    amount_left = character(0),
    amount_right = character(0)
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

  append_compare_failures <- function(context_name, reason, compare_dt) {
    if (!is.data.frame(compare_dt) || nrow(compare_dt) == 0L) {
      return(invisible(NULL))
    }

    local <- data.table::copy(data.table::as.data.table(compare_dt))
    local[, context := context_name]
    local[, reason := reason]

    required_cols <- c(
      "context", "reason",
      "Trade", "GeographicDesc", "Year", "MonthNumber", "MarketYear",
      "Group", "Subgroup", "MarketSegment", "CommodityName", "CommodityDetail", "UnitType", "UnitDesc",
      "compare_row_id", "AmountValue_left", "AmountValue_right"
    )

    for (column_name in required_cols) {
      if (!(column_name %in% names(local))) {
        local[[column_name]] <- NA
      }
    }

    local <- local[, .(
      context,
      reason,
      Trade = safe_chr(Trade),
      GeographicDesc = safe_chr(GeographicDesc),
      Year = safe_chr(Year),
      MonthNumber = safe_chr(MonthNumber),
      MarketYear = safe_chr(MarketYear),
      Group = safe_chr(Group),
      Subgroup = safe_chr(Subgroup),
      MarketSegment = safe_chr(MarketSegment),
      CommodityName = safe_chr(CommodityName),
      CommodityDetail = safe_chr(CommodityDetail),
      UnitType = safe_chr(UnitType),
      UnitDesc = safe_chr(UnitDesc),
      compare_row_id = safe_chr(compare_row_id),
      amount_left = safe_chr(AmountValue_left),
      amount_right = safe_chr(AmountValue_right)
    )]

    if (nrow(local) > 250L) {
      local <- local[1:250]
    }

    failures <<- data.table::rbindlist(list(failures, local), fill = TRUE)
    invisible(NULL)
  }

  context_name <- trim_scalar(context_row$context_name)
  state <- apply_vp_context(app, context_row)

  probe_progress("context_phase", paste0(context_name, "|raw_data_pre_publish"))
  pre_payload <- wait_for_data_table_payload(app, "raw_data_table", timeout_sec = 90)
  pre_cols <- if (is.null(pre_payload)) character(0) else safe_chr(pre_payload$columns %||% character(0))
  pre_dt <- if (is.null(pre_payload)) data.table::data.table() else payload_rows_to_table(pre_payload)

  required_raw_cols <- c(
    "Trade", "GeographicDesc", "Year", "MonthNumber", "MarketYear",
    "Group", "Subgroup", "MarketSegment", "CommodityName", "CommodityDetail",
    "UnitType", "UnitDesc", "Amount"
  )

  add_check(
    context_name,
    "raw_data_table_pre",
    "required_columns_present",
    paste(required_raw_cols, collapse = " | "),
    paste(pre_cols, collapse = " | "),
    all(required_raw_cols %in% pre_cols)
  )

  add_check(
    context_name,
    "raw_data_table_pre",
    "variable_column_absent",
    "Variable absent",
    as.character("Variable" %in% pre_cols),
    !("Variable" %in% pre_cols)
  )

  add_check(
    context_name,
    "raw_data_table_pre",
    "row_count_nonzero",
    "> 0",
    as.character(nrow(pre_dt)),
    nrow(pre_dt) > 0L
  )

  probe_progress("context_phase", paste0(context_name, "|publish_first"))
  publish_path_1 <- capture_published_csv(app, publish_dir, timeout_sec = 120)
  published_1 <- read_published_csv(publish_path_1)

  probe_progress("context_phase", paste0(context_name, "|publish_second"))
  publish_path_2 <- capture_published_csv(app, publish_dir, timeout_sec = 120)
  published_2 <- read_published_csv(publish_path_2)

  add_check(
    context_name,
    "publish_files",
    "first_publish_file_created",
    "non-empty existing file path",
    publish_path_1,
    nzchar(publish_path_1) && file.exists(publish_path_1)
  )
  add_check(
    context_name,
    "publish_files",
    "second_publish_file_created",
    "non-empty existing file path",
    publish_path_2,
    nzchar(publish_path_2) && file.exists(publish_path_2)
  )

  app_output_dir_js <- trim_scalar(run_js(app, "(function(){ try { if(window.Shiny && Shiny.shinyapp && Shiny.shinyapp.$inputValues){ var v = Shiny.shinyapp.$inputValues['app_output_dir']; if(v !== undefined && v !== null) return String(v); } } catch(e){} return ''; })();"), default = "")
  add_check(
    context_name,
    "publish_files",
    "app_output_dir_probe",
    "informational",
    app_output_dir_js,
    TRUE
  )

  output_recent_files <- list_csv_files(publish_dir)
  output_recent_tail <- if (length(output_recent_files) > 0L) {
    paste(utils::tail(output_recent_files, 5L), collapse = " || ")
  } else {
    ""
  }
  add_check(
    context_name,
    "publish_files",
    "output_recent_csv_snapshot",
    "informational",
    output_recent_tail,
    TRUE
  )

  assess_publish_contract <- function(published_dt, publish_path, tag_label) {
    cols <- names(published_dt)

    add_check(
      context_name,
      tag_label,
      "row_count_nonzero",
      "> 0",
      as.character(nrow(published_dt)),
      nrow(published_dt) > 0L
    )

    add_check(
      context_name,
      tag_label,
      "variable_column_present",
      "TRUE",
      as.character("Variable" %in% cols),
      "Variable" %in% cols
    )

    variable_count <- sum(cols == "Variable")
    add_check(
      context_name,
      tag_label,
      "variable_column_once",
      "1",
      as.character(variable_count),
      identical(variable_count, 1L)
    )

    variable_is_final <- length(cols) > 0L && identical(utils::tail(cols, 1L), "Variable")
    add_check(
      context_name,
      tag_label,
      "variable_is_final_column",
      "TRUE",
      as.character(variable_is_final),
      isTRUE(variable_is_final)
    )

    pre_cols_present <- all(pre_cols %in% cols)
    add_check(
      context_name,
      tag_label,
      "pre_schema_columns_retained",
      "TRUE",
      as.character(pre_cols_present),
      isTRUE(pre_cols_present)
    )

    pre_cols_ordered_match <- FALSE
    if (length(pre_cols) > 0L && length(cols) >= length(pre_cols)) {
      pre_cols_ordered_match <- identical(cols[seq_len(length(pre_cols))], pre_cols)
    }
    add_check(
      context_name,
      tag_label,
      "pre_schema_order_retained_before_variable",
      "TRUE",
      as.character(pre_cols_ordered_match),
      isTRUE(pre_cols_ordered_match)
    )

    variable_values <- if ("Variable" %in% cols) safe_chr(published_dt$Variable) else character(0)
    unique_variable_values <- unique(variable_values[nzchar(variable_values)])
    add_check(
      context_name,
      tag_label,
      "variable_values_nonempty",
      "TRUE",
      as.character(length(unique_variable_values) > 0L),
      length(unique_variable_values) > 0L
    )
    add_check(
      context_name,
      tag_label,
      "variable_values_singleton",
      "1",
      as.character(length(unique_variable_values)),
      identical(length(unique_variable_values), 1L)
    )

    expected_metric_label <- trim_scalar(state$metric_label)
    observed_variable_label <- if (length(unique_variable_values) > 0L) unique_variable_values[[1L]] else ""
    add_check(
      context_name,
      tag_label,
      "variable_matches_selected_metric_label",
      expected_metric_label,
      observed_variable_label,
      nzchar(expected_metric_label) && identical(observed_variable_label, expected_metric_label)
    )

    add_check(
      context_name,
      tag_label,
      "publish_path_recorded",
      "non-empty",
      publish_path,
      nzchar(publish_path)
    )
  }

  assess_publish_contract(published_1, publish_path_1, "publish_csv_1")
  assess_publish_contract(published_2, publish_path_2, "publish_csv_2")

  probe_progress("context_phase", paste0(context_name, "|raw_data_post_publish"))
  post_payload <- wait_for_data_table_payload(app, "raw_data_table", timeout_sec = 90)
  post_cols <- if (is.null(post_payload)) character(0) else safe_chr(post_payload$columns %||% character(0))
  post_dt <- if (is.null(post_payload)) data.table::data.table() else payload_rows_to_table(post_payload)

  add_check(
    context_name,
    "raw_data_table_post",
    "schema_unchanged_vs_pre",
    paste(pre_cols, collapse = " | "),
    paste(post_cols, collapse = " | "),
    identical(post_cols, pre_cols)
  )
  add_check(
    context_name,
    "raw_data_table_post",
    "variable_column_absent",
    "Variable absent",
    as.character("Variable" %in% post_cols),
    !("Variable" %in% post_cols)
  )
  add_check(
    context_name,
    "raw_data_table_post",
    "row_count_unchanged_vs_pre",
    as.character(nrow(pre_dt)),
    as.character(nrow(post_dt)),
    identical(nrow(post_dt), nrow(pre_dt))
  )

  key_cols <- c(
    "Trade", "GeographicDesc", "Year", "MonthNumber", "MarketYear",
    "Group", "Subgroup", "MarketSegment", "CommodityName", "CommodityDetail",
    "UnitType", "UnitDesc"
  )

  available_screen_keys <- intersect(key_cols, intersect(names(pre_dt), names(post_dt)))
  if (length(available_screen_keys) > 0L && "Amount" %in% names(pre_dt) && "Amount" %in% names(post_dt)) {
    screen_compare <- compare_amount_tables(pre_dt, post_dt, key_cols = available_screen_keys, amount_col = "Amount")

    add_check(
      context_name,
      "raw_data_table_post",
      "amount_compare_missing_left",
      "0",
      as.character(nrow(screen_compare$missing_left)),
      nrow(screen_compare$missing_left) == 0L
    )
    add_check(
      context_name,
      "raw_data_table_post",
      "amount_compare_missing_right",
      "0",
      as.character(nrow(screen_compare$missing_right)),
      nrow(screen_compare$missing_right) == 0L
    )
    add_check(
      context_name,
      "raw_data_table_post",
      "amount_values_unchanged_vs_pre",
      "0 mismatches",
      as.character(nrow(screen_compare$mismatches)),
      nrow(screen_compare$mismatches) == 0L
    )

    append_compare_failures(context_name, "screen_post_missing_left", screen_compare$missing_left)
    append_compare_failures(context_name, "screen_post_missing_right", screen_compare$missing_right)
    append_compare_failures(context_name, "screen_post_amount_mismatch", screen_compare$mismatches)
  }

  available_publish_keys <- intersect(key_cols, intersect(names(published_1), names(published_2)))
  if (length(available_publish_keys) > 0L && "Amount" %in% names(published_1) && "Amount" %in% names(published_2)) {
    publish_compare <- compare_amount_tables(published_1, published_2, key_cols = available_publish_keys, amount_col = "Amount")

    add_check(
      context_name,
      "publish_cross_run",
      "row_count_unchanged_across_publishes",
      as.character(nrow(published_1)),
      as.character(nrow(published_2)),
      identical(nrow(published_1), nrow(published_2))
    )
    add_check(
      context_name,
      "publish_cross_run",
      "amount_compare_missing_left",
      "0",
      as.character(nrow(publish_compare$missing_left)),
      nrow(publish_compare$missing_left) == 0L
    )
    add_check(
      context_name,
      "publish_cross_run",
      "amount_compare_missing_right",
      "0",
      as.character(nrow(publish_compare$missing_right)),
      nrow(publish_compare$missing_right) == 0L
    )
    add_check(
      context_name,
      "publish_cross_run",
      "amount_values_unchanged_across_publishes",
      "0 mismatches",
      as.character(nrow(publish_compare$mismatches)),
      nrow(publish_compare$mismatches) == 0L
    )

    append_compare_failures(context_name, "publish_cross_run_missing_left", publish_compare$missing_left)
    append_compare_failures(context_name, "publish_cross_run_missing_right", publish_compare$missing_right)
    append_compare_failures(context_name, "publish_cross_run_amount_mismatch", publish_compare$mismatches)
  }

  summary <- data.table::data.table(
    context = context_name,
    selected_trade = state$expected_trade,
    selected_group = state$expected_group,
    selected_subgroup = state$expected_subgroup,
    selected_market_segment = state$expected_segment,
    selected_commodity_name = state$expected_commodity_name,
    selected_commodity_detail = state$expected_detail,
    selected_country = state$expected_country,
    metric_choice = state$metric_choice,
    expected_metric_label = state$metric_label,
    pre_screen_rows = nrow(pre_dt),
    post_screen_rows = nrow(post_dt),
    publish_rows_first = nrow(published_1),
    publish_rows_second = nrow(published_2),
    publish_path_first = publish_path_1,
    publish_path_second = publish_path_2,
    pre_schema_columns = paste(pre_cols, collapse = "|"),
    post_schema_columns = paste(post_cols, collapse = "|"),
    failure_row_count = nrow(failures)
  )

  list(
    checks = checks,
    failures = failures,
    summary = summary
  )
}

repo_root <- resolve_repo_root()
Sys.setenv(NOT_CRAN = "true")
artifact_path <- file.path(repo_root, "System", "Processed Data", "vp_trade_monthly_pre.rds")
publish_dir <- file.path(repo_root, "Output")

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
  stop("VP trade artifact has no rows for Gate C fixture selection.", call. = FALSE)
}

artifact_dt <- data.table::as.data.table(artifact_df)
context_dt <- build_baseline_context(artifact_dt)
probe_progress("context_fixture_count", as.character(nrow(context_dt)))

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
  "metric_choice",
  "publish_filtered_data"
)

app <- NULL
launch_diagnostics <- character(0)

for (attempt in seq_len(3L)) {
  probe_progress("launch_attempt", as.character(attempt))
  app_name <- paste0("ftn_data_tab_gateC_publish_contract_", attempt, "_", as.integer(as.numeric(Sys.time())))
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
  id_wait <- wait_for_required_ids(app_candidate, required_controls, timeout_sec = 120)
  if (isTRUE(id_wait$ok)) {
    probe_progress("launch_attempt_ready", as.character(attempt))
    app <- app_candidate
    break
  }

  launch_diagnostics <- c(
    launch_diagnostics,
    paste0("attempt=", attempt, "|ids=", paste(utils::head(id_wait$ids, 40L), collapse = ","))
  )
  try(app_candidate$stop(), silent = TRUE)
}

if (is.null(app)) {
  stop(
    paste0(
      "FTN app did not render required controls before timeout. ",
      "Launch diagnostics: ", paste(launch_diagnostics, collapse = " || ")
    ),
    call. = FALSE
  )
}
on.exit(app$stop(), add = TRUE)

result <- run_gatec_checks(app, context_dt[1L], publish_dir)
checks <- result$checks
failures <- result$failures
summary <- result$summary

failure_checks <- checks[passed == FALSE]
status <- if (nrow(failure_checks) == 0L) "PASS" else "FAIL"
probe_progress("complete", paste0("status=", status, "|checks=", nrow(checks), "|failures=", nrow(failure_checks)))

log_dir <- file.path(repo_root, "Logs", "ftn_probe_runs")
dir.create(log_dir, recursive = TRUE, showWarnings = FALSE)
ts <- format(as.POSIXct(Sys.time(), tz = "UTC"), "%Y%m%dT%H%M%SZ", tz = "UTC")
checks_path <- file.path(log_dir, paste0("ftn_data_tab_gateC_publish_contract_", ts, "_checks.csv"))
summary_path <- file.path(log_dir, paste0("ftn_data_tab_gateC_publish_contract_", ts, "_summary.csv"))
failure_path <- if (nrow(failures) > 0L) file.path(log_dir, paste0("ftn_data_tab_gateC_publish_contract_", ts, "_failures.csv")) else ""

summary_meta <- data.table::data.table(
  status = status,
  context_count = 1L,
  total_checks = nrow(checks),
  failed_checks = nrow(failure_checks),
  failure_rows = nrow(failures),
  checks_path = checks_path,
  failures_path = failure_path,
  artifact_path = artifact_path,
  publish_dir = publish_dir,
  timestamp_utc = ts
)

summary[, `:=`(
  status = summary_meta$status[[1L]],
  context_count = summary_meta$context_count[[1L]],
  total_checks = summary_meta$total_checks[[1L]],
  failed_checks = summary_meta$failed_checks[[1L]],
  failure_rows = summary_meta$failure_rows[[1L]],
  checks_path = summary_meta$checks_path[[1L]],
  failures_path = summary_meta$failures_path[[1L]],
  artifact_path = summary_meta$artifact_path[[1L]],
  publish_dir = summary_meta$publish_dir[[1L]],
  timestamp_utc = summary_meta$timestamp_utc[[1L]]
)]

data.table::fwrite(checks, checks_path)
data.table::fwrite(summary, summary_path)
if (nrow(failures) > 0L) {
  data.table::fwrite(failures, failure_path)
}

cat("FTN_DATA_TAB_GATEC_STATUS=", status, "\n", sep = "")
cat("FTN_DATA_TAB_GATEC_TOTAL_CHECKS=", nrow(checks), "\n", sep = "")
cat("FTN_DATA_TAB_GATEC_FAILURE_COUNT=", nrow(failure_checks), "\n", sep = "")
cat("FTN_DATA_TAB_GATEC_FAILURE_ROWS=", nrow(failures), "\n", sep = "")
cat("FTN_DATA_TAB_GATEC_SUMMARY_PATH=", summary_path, "\n", sep = "")
cat("FTN_DATA_TAB_GATEC_CHECKS_PATH=", checks_path, "\n", sep = "")
cat("FTN_DATA_TAB_GATEC_FAILURE_PATH=", failure_path, "\n", sep = "")

if (!identical(status, "PASS")) {
  preview <- utils::head(failure_checks, 20L)
  cat("FTN_DATA_TAB_GATEC_FAILURE_PREVIEW_START\n")
  utils::write.table(preview, row.names = FALSE, sep = "|", quote = FALSE)
  cat("FTN_DATA_TAB_GATEC_FAILURE_PREVIEW_END\n")
  stop("Gate C publish-contract probe detected failing checks. See failure artifacts.", call. = FALSE)
}
