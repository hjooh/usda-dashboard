if (!requireNamespace("shinytest2", quietly = TRUE)) {
  stop("Package 'shinytest2' is required for ftn_validated_calendar_signature_matrix.R", call. = FALSE)
}
if (!requireNamespace("jsonlite", quietly = TRUE)) {
  stop("Package 'jsonlite' is required for ftn_validated_calendar_signature_matrix.R", call. = FALSE)
}

`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0L) y else x
}

progress <- function(msg) {
  cat("FTN_CAL_MATRIX_PROGRESS=", msg, "\n", sep = "")
  flush.console()
}

resolve_repo_root <- function(start_dir = getwd()) {
  start_dir <- normalizePath(start_dir, winslash = "/", mustWork = FALSE)
  candidates <- unique(c(
    start_dir,
    vapply(1:8, function(level) normalizePath(file.path(start_dir, paste(rep("..", level), collapse = "/")), winslash = "/", mustWork = FALSE), character(1))
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
  identical(tolower(trimws(as.character(value %||% ""))), "true")
}

safe_wait_for_idle <- function(app, timeout = 120000) {
  tryCatch({
    app$wait_for_idle(timeout = timeout)
    TRUE
  }, error = function(...) FALSE)
}

get_select_choices <- function(app, input_id) {
  script <- sprintf(
    "(function(){ var id = '%s'; var docs = [document]; for (var i = 0; i < window.frames.length; i++) { try { if (window.frames[i].document) docs.push(window.frames[i].document); } catch (e) {} } for (var j = 0; j < docs.length; j++) { try { var el = docs[j].getElementById(id); if (!el) continue; if (el.selectize && el.selectize.options) { var optionKeys = Object.keys(el.selectize.options).map(function(x){ return (x || '').trim(); }).filter(function(x){ return x.length > 0; }); if (optionKeys.length > 0) return optionKeys.join('|||'); } if (el.options) { var vals = []; for (var k = 0; k < el.options.length; k++) { vals.push((el.options[k].value || '').trim()); } return vals.join('|||'); } } catch (e) {} } return ''; })();",
    input_id
  )
  raw <- tryCatch(as.character(app$get_js(script) %||% ""), error = function(...) "")
  if (!nzchar(raw)) return(character(0))
  values <- strsplit(raw, "\\|\\|\\|", perl = TRUE)[[1L]]
  values <- trimws(values)
  values[nzchar(values)]
}

dom_exists <- function(app, id) {
  script <- sprintf(
    "(function(){ var id = '%s'; var docs = [document]; for (var i = 0; i < window.frames.length; i++) { try { if (window.frames[i].document) docs.push(window.frames[i].document); } catch (e) {} } for (var j = 0; j < docs.length; j++) { try { if (docs[j].getElementById(id) !== null) return true; } catch (e) {} } return false; })();",
    id
  )
  value <- tryCatch(app$get_js(script), error = function(...) FALSE)
  to_bool(value)
}

get_dom_ids <- function(app) {
  script <- "(function(){ var docs=[document]; for (var i=0;i<window.frames.length;i++){ try{ if(window.frames[i].document) docs.push(window.frames[i].document); } catch(e) {} } var out=[]; for (var j=0;j<docs.length;j++){ try{ var nodes=docs[j].querySelectorAll('[id]'); for (var k=0;k<nodes.length;k++){ if(nodes[k].id){ out.push(nodes[k].id); } } } catch(e) {} } var dedup=[]; var seen={}; for (var n=0;n<out.length;n++){ var key=out[n]; if(!seen[key]){ seen[key]=true; dedup.push(key); } } return dedup.join('|||'); })();"
  raw <- tryCatch(as.character(app$get_js(script) %||% ""), error = function(...) "")
  if (!nzchar(raw)) return(character(0))
  values <- strsplit(raw, "\\|\\|\\|", perl = TRUE)[[1L]]
  values <- trimws(values)
  values[nzchar(values)]
}

wait_for_required_ids <- function(app, required_ids, timeout_sec = 240, poll_sec = 0.5) {
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

wait_for_select_choices <- function(app, input_id, timeout_sec = 90, poll_sec = 0.5) {
  deadline <- Sys.time() + timeout_sec
  repeat {
    values <- get_select_choices(app, input_id)
    if (length(values) > 0L) return(values)
    if (Sys.time() >= deadline) return(character(0))
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
  value <- tryCatch(as.character(app$get_js(script) %||% ""), error = function(...) "")
  value <- trimws(value)
  if (length(value) == 0L || !nzchar(value[[1L]])) "" else value[[1L]]
}

get_select_current_value <- function(app, input_id) {
  script <- sprintf(
    "(function(){ var id='%s'; var docs=[document]; for (var i=0;i<window.frames.length;i++){ try{ if(window.frames[i].document) docs.push(window.frames[i].document); } catch(e) {} } for (var j=0;j<docs.length;j++){ try{ var el=docs[j].getElementById(id); if(!el) continue; if(el.selectize && typeof el.selectize.getValue === 'function'){ var v = String(el.selectize.getValue() || '').trim(); if(v.length > 0) return v; } var raw = String(el.value || '').trim(); if(raw.length > 0) return raw; } catch(e) {} } return ''; })();",
    input_id
  )
  value <- tryCatch(as.character(app$get_js(script) %||% ""), error = function(...) "")
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

    # Avoid long per-attempt idle waits; rely on direct value polling for confirmation.
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

set_select_value <- function(app, input_id, value, timeout_sec = 90, poll_sec = 0.5) {
  deadline <- Sys.time() + timeout_sec
  last_choices <- character(0)

  repeat {
    choices <- get_select_choices(app, input_id)
    if (length(choices) > 0L) {
      last_choices <- choices
      if (value %in% choices) {
        ok <- tryCatch({
          set_input_by_name(app, input_id, value)
          TRUE
        }, error = function(...) FALSE)
        if (isTRUE(ok)) {
          invisible(safe_wait_for_idle(app, timeout = 45000))
          return(list(ok = TRUE, choices = choices))
        }
      }
    }

    if (Sys.time() >= deadline) {
      return(list(ok = FALSE, choices = last_choices))
    }
    Sys.sleep(poll_sec)
  }
}

first_existing_col <- function(df, candidates) {
  if (!is.data.frame(df)) return(NA_character_)
  nm <- names(df)
  nm_lower <- tolower(nm)
  for (cand in candidates) {
    idx <- which(nm_lower == tolower(cand))
    if (length(idx) > 0L) {
      return(nm[idx[[1L]]])
    }
  }
  NA_character_
}

dominant_signature <- function(df, sig_col = "calendar_signature") {
  if (!is.data.frame(df) || nrow(df) == 0L || !(sig_col %in% names(df))) return(NA_character_)
  sig <- trimws(as.character(df[[sig_col]]))
  sig <- sig[!is.na(sig) & nzchar(sig)]
  if (length(sig) == 0L) return(NA_character_)
  tab <- sort(table(sig), decreasing = TRUE)
  as.character(names(tab)[[1L]])
}

pick_hierarchy_for_commodity <- function(
  artifact_df,
  trade_col,
  commodity_col,
  signature_col,
  group_col,
  subgroup_col,
  segment_col,
  commodity_name,
  expected_signature
) {
  work <- artifact_df[
    tolower(trimws(as.character(artifact_df[[trade_col]]))) == "export" &
      trimws(as.character(artifact_df[[commodity_col]])) == commodity_name,
    , drop = FALSE
  ]
  if (!is.data.frame(work) || nrow(work) == 0L) {
    return(NULL)
  }

  work_sig <- work[trimws(as.character(work[[signature_col]])) == expected_signature, , drop = FALSE]
  if (is.data.frame(work_sig) && nrow(work_sig) > 0L) {
    work <- work_sig
  }

  # Prefer concrete hierarchy rows over rollup sentinel rows to keep Shiny cascades responsive.
  rollup_tokens <- c(
    "__vp_rollup_all_group__",
    "__vp_rollup_all_subgroup__",
    "__vp_rollup_all_market_segment__",
    "__all__",
    "All"
  )
  work_concrete <- work[
    !(trimws(as.character(work[[group_col]])) %in% rollup_tokens) &
      !(trimws(as.character(work[[subgroup_col]])) %in% rollup_tokens) &
      !(trimws(as.character(work[[segment_col]])) %in% rollup_tokens),
    , drop = FALSE
  ]
  if (is.data.frame(work_concrete) && nrow(work_concrete) > 0L) {
    work <- work_concrete
  }

  group_vals <- trimws(as.character(work[[group_col]]))
  subgroup_vals <- trimws(as.character(work[[subgroup_col]]))
  segment_vals <- trimws(as.character(work[[segment_col]]))

  combo <- aggregate(
    list(rows = rep(1L, nrow(work))),
    list(group = group_vals, subgroup = subgroup_vals, segment = segment_vals),
    sum
  )
  combo <- combo[order(-combo$rows), , drop = FALSE]
  if (nrow(combo) == 0L) {
    return(NULL)
  }

  list(
    group = as.character(combo$group[[1L]]),
    subgroup = as.character(combo$subgroup[[1L]]),
    segment = as.character(combo$segment[[1L]])
  )
}

get_plot_axis <- function(app, output_id = "comparison_plot") {
  script <- sprintf(
    "(function(){ var id='%s'; var docs=[document]; for (var i=0;i<window.frames.length;i++){ try{ if(window.frames[i].document) docs.push(window.frames[i].document); } catch(e) {} } for (var j=0;j<docs.length;j++){ try{ var gd=docs[j].getElementById(id); if(!gd) continue; var xa=(gd.layout && gd.layout.xaxis)?gd.layout.xaxis:null; if(!xa) continue; var title=''; if (typeof xa.title === 'string') title=xa.title; else if (xa.title && xa.title.text) title=xa.title.text; var tt=[]; if (Array.isArray(xa.ticktext)) tt=xa.ticktext.map(function(v){ return String(v); }); return JSON.stringify({found:true, title:String(title||''), ticktext:tt, output:id}); } catch(e) {} } return JSON.stringify({found:false, title:'', ticktext:[], output:id}); })();",
    output_id
  )
  raw <- tryCatch(as.character(app$get_js(script) %||% ""), error = function(...) "")
  parsed <- tryCatch(jsonlite::fromJSON(raw), error = function(...) NULL)
  if (is.null(parsed)) {
    return(list(found = FALSE, title = "", ticktext = character(0), output = output_id))
  }
  list(
    found = isTRUE(parsed$found),
    title = trimws(as.character(parsed$title %||% "")),
    ticktext = as.character(parsed$ticktext %||% character(0)),
    output = as.character(parsed$output %||% output_id)
  )
}

poll_plot_axis <- function(app, output_ids = c("comparison_plot", "timeseries_plot", "heatmap_plot"), timeout_sec = 120, poll_sec = 0.75) {
  deadline <- Sys.time() + timeout_sec
  last <- list(found = FALSE, title = "", ticktext = character(0), output = "")
  repeat {
    for (output_id in output_ids) {
      axis <- get_plot_axis(app, output_id = output_id)
      if (isTRUE(axis$found) && length(axis$ticktext) >= 12L && nzchar(axis$title)) {
        return(axis)
      }
      last <- axis
    }

    if (Sys.time() >= deadline) {
      return(last)
    }
    Sys.sleep(poll_sec)
  }
}

ticktext_to_signature <- function(ticktext) {
  labels <- trimws(as.character(ticktext %||% character(0)))
  labels <- labels[!is.na(labels) & nzchar(labels)]
  if (length(labels) < 12L) return(NA_character_)
  labels <- labels[1:12]

  lookup <- stats::setNames(as.character(1:12), tolower(month.abb))
  month_nums <- lookup[tolower(labels)]
  if (any(is.na(month_nums))) return(NA_character_)
  paste(month_nums, collapse = "-")
}

read_preflight_signatures <- function(repo_root) {
  preflight_summary <- file.path(repo_root, "Logs", "ftn_preflight", "20260810T110101_retry", "summary.txt")
  if (!file.exists(preflight_summary)) {
    return(character(0))
  }

  lines <- readLines(preflight_summary, warn = FALSE)
  sig_line <- lines[grepl("^top_calendar_signatures=", lines)]
  if (length(sig_line) == 0L) {
    return(character(0))
  }

  vals <- strsplit(sub("^top_calendar_signatures=", "", sig_line[[1L]]), "\\|", perl = TRUE)[[1L]]
  vals <- trimws(vals)
  vals[nzchar(vals)]
}

repo_root <- resolve_repo_root()
source(file.path(repo_root, "Programs", "vp_data_utils.R"), local = FALSE)
progress("repo_root_resolved")

paths <- vp_paths(repo_root)
artifact_obj <- readRDS(paths$artifact)
artifact_df <- if (is.data.frame(artifact_obj)) artifact_obj else artifact_obj$data
metadata_obj <- readRDS(paths$metadata)
calendar_df <- metadata_obj$calendars
progress("artifact_and_metadata_loaded")

trade_col_art <- first_existing_col(artifact_df, c("Trade"))
commodity_col_art <- first_existing_col(artifact_df, c("CommodityName"))
signature_col_art <- first_existing_col(artifact_df, c("calendar_signature"))
group_col_art <- first_existing_col(artifact_df, c("Group"))
subgroup_col_art <- first_existing_col(artifact_df, c("Subgroup"))
segment_col_art <- first_existing_col(artifact_df, c("MarketSegment"))

trade_col_cal <- first_existing_col(calendar_df, c("Trade"))
commodity_col_cal <- first_existing_col(calendar_df, c("CommodityName"))
signature_col_cal <- first_existing_col(calendar_df, c("calendar_signature"))

if (any(is.na(c(
  trade_col_art, commodity_col_art, signature_col_art, group_col_art, subgroup_col_art, segment_col_art,
  trade_col_cal, commodity_col_cal, signature_col_cal
)))) {
  stop("Missing required trade/commodity/hierarchy/signature columns in artifact or metadata calendars.", call. = FALSE)
}

preflight_signatures <- read_preflight_signatures(repo_root)
progress(paste0("preflight_signatures_count=", length(preflight_signatures)))

candidates <- data.frame(
  CommodityName = c("Bananas", "Oranges"),
  ExpectedSignature = c("1-2-3-4-5-6-7-8-9-10-11-12", "10-11-12-1-2-3-4-5-6-7-8-9"),
  stringsAsFactors = FALSE
)

required_controls <- c(
  "data_source_choice",
  "vp_trade_flow_choice",
  "vp_group_choice",
  "vp_subgroup_choice",
  "vp_market_segment_choice",
  "vp_commodity_name_choice",
  "commodity_choice"
)

Sys.setenv(NOT_CRAN = "true")

app <- NULL
id_wait <- NULL
launch_diagnostics <- character(0)
for (attempt in seq_len(3L)) {
  progress(paste0("launch_attempt=", attempt))
  app_name <- paste0("ftn_validated_calendar_matrix_", attempt, "_", as.integer(as.numeric(Sys.time())))
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
    progress(paste0("launch_attempt_error=", attempt))
    launch_diagnostics <- c(launch_diagnostics, paste0("attempt=", attempt, "|create_error=", conditionMessage(app_candidate)))
    next
  }

  invisible(safe_wait_for_idle(app_candidate, timeout = 45000))
  id_candidate <- wait_for_required_ids(app_candidate, required_controls, timeout_sec = 120)
  if (isTRUE(id_candidate$ok)) {
    progress(paste0("launch_attempt_ready=", attempt))
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
progress("app_ready")

trade_flow_set <- set_input_and_confirm(app, "vp_trade_flow_choice", "export", timeout_sec = 90)
if (!isTRUE(trade_flow_set$ok)) {
  stop(
    paste0("Could not set vp_trade_flow_choice='export'. current_value=", trade_flow_set$current_value),
    call. = FALSE
  )
}
progress("trade_flow_set_export")

source_set <- set_input_and_confirm(app, "data_source_choice", "vp_trade", timeout_sec = 90)
if (!isTRUE(source_set$ok)) {
  stop(
    paste0("Could not set data_source_choice='vp_trade'. current_value=", source_set$current_value),
    call. = FALSE
  )
}
progress("source_set_vp_trade")

try(set_input_by_name(app, "data_frequency", "monthly"), silent = TRUE)
invisible(safe_wait_for_idle(app, timeout = 60000))
progress("data_frequency_monthly_requested")

all_pass <- TRUE

for (i in seq_len(nrow(candidates))) {
  commodity_name <- candidates$CommodityName[[i]]
  expected_signature <- candidates$ExpectedSignature[[i]]
  progress(paste0("candidate_start=", commodity_name))

  art_rows <- artifact_df[
    tolower(trimws(as.character(artifact_df[[trade_col_art]]))) == "export" &
      trimws(as.character(artifact_df[[commodity_col_art]])) == commodity_name,
    , drop = FALSE
  ]
  art_signature <- dominant_signature(art_rows, sig_col = signature_col_art)

  cal_rows <- calendar_df[
    tolower(trimws(as.character(calendar_df[[trade_col_cal]]))) == "export" &
      trimws(as.character(calendar_df[[commodity_col_cal]])) == commodity_name,
    , drop = FALSE
  ]
  cal_signature <- dominant_signature(cal_rows, sig_col = signature_col_cal)

  hierarchy <- pick_hierarchy_for_commodity(
    artifact_df = artifact_df,
    trade_col = trade_col_art,
    commodity_col = commodity_col_art,
    signature_col = signature_col_art,
    group_col = group_col_art,
    subgroup_col = subgroup_col_art,
    segment_col = segment_col_art,
    commodity_name = commodity_name,
    expected_signature = expected_signature
  )

  if (is.null(hierarchy)) {
    stop(paste0("Could not derive hierarchy for commodity: ", commodity_name), call. = FALSE)
  }
  progress(paste0("candidate_hierarchy=", commodity_name, "|", hierarchy$group, "|", hierarchy$subgroup, "|", hierarchy$segment))

  progress(paste0("candidate_set_group=", commodity_name, "|", hierarchy$group))
  group_set <- set_input_and_confirm(app, "vp_group_choice", hierarchy$group, timeout_sec = 90)
  progress(paste0("candidate_set_subgroup=", commodity_name, "|", hierarchy$subgroup))
  subgroup_set <- set_input_and_confirm(app, "vp_subgroup_choice", hierarchy$subgroup, timeout_sec = 90)
  progress(paste0("candidate_set_segment=", commodity_name, "|", hierarchy$segment))
  segment_set <- set_input_and_confirm(app, "vp_market_segment_choice", hierarchy$segment, timeout_sec = 90)
  progress(paste0("candidate_set_commodity_name=", commodity_name))
  commodity_name_set <- set_input_and_confirm(app, "vp_commodity_name_choice", commodity_name, timeout_sec = 90)

  if (!isTRUE(group_set$ok) || !isTRUE(subgroup_set$ok) || !isTRUE(segment_set$ok) || !isTRUE(commodity_name_set$ok)) {
    stop(
      paste0(
        "Could not drive hierarchy controls for ", commodity_name, ". ",
        "group_ok=", group_set$ok, "|group_current=", group_set$current_value,
        "|subgroup_ok=", subgroup_set$ok, "|subgroup_current=", subgroup_set$current_value,
        "|segment_ok=", segment_set$ok, "|segment_current=", segment_set$current_value,
        "|commodity_ok=", commodity_name_set$ok, "|commodity_current=", commodity_name_set$current_value
      ),
      call. = FALSE
    )
  }
  progress(paste0("candidate_hierarchy_controls_set=", commodity_name))

  type_choices <- wait_for_select_choices(app, "commodity_choice", timeout_sec = 60)
  target_type <- if ("All" %in% type_choices) "All" else if (length(type_choices) > 0L) type_choices[[1L]] else ""
  if (!nzchar(target_type)) {
    stop(paste0("No commodity_choice values available for commodity: ", commodity_name), call. = FALSE)
  }
  type_set <- set_input_and_confirm(app, "commodity_choice", target_type, timeout_sec = 60)
  if (!isTRUE(type_set$ok)) {
    stop(
      paste0("Could not set commodity_choice for ", commodity_name, ". current_value=", type_set$current_value),
      call. = FALSE
    )
  }
  progress(paste0("candidate_type_set=", commodity_name, "|", target_type))

  try(set_input_by_name(app, "data_frequency", "monthly"), silent = TRUE)
  invisible(safe_wait_for_idle(app, timeout = 90000))
  progress(paste0("candidate_wait_plot=", commodity_name))

  axis <- poll_plot_axis(app)
  ui_title <- trimws(as.character(axis$title %||% ""))
  ui_ticktext <- as.character(axis$ticktext %||% character(0))
  ui_signature <- ticktext_to_signature(ui_ticktext)
  expected_axis_title <- if (identical(expected_signature, "1-2-3-4-5-6-7-8-9-10-11-12")) "Calendar Year Month" else "Commodity Year Month"

  preflight_has_signature <- expected_signature %in% preflight_signatures
  artifact_match <- identical(art_signature, expected_signature)
  metadata_match <- identical(cal_signature, expected_signature)
  ui_signature_match <- identical(ui_signature, expected_signature)
  ui_title_match <- identical(ui_title, expected_axis_title)

  row_pass <- all(c(preflight_has_signature, artifact_match, metadata_match, ui_signature_match, ui_title_match))
  if (!isTRUE(row_pass)) {
    all_pass <- FALSE
  }
  progress(paste0("candidate_row_pass=", commodity_name, "|", row_pass))

  cat("FTN_CAL_MATRIX_COMMODITY=", commodity_name, "\n", sep = "")
  cat("FTN_CAL_MATRIX_EXPECTED_SIGNATURE=", expected_signature, "\n", sep = "")
  cat("FTN_CAL_MATRIX_HIERARCHY_GROUP=", hierarchy$group, "\n", sep = "")
  cat("FTN_CAL_MATRIX_HIERARCHY_SUBGROUP=", hierarchy$subgroup, "\n", sep = "")
  cat("FTN_CAL_MATRIX_HIERARCHY_SEGMENT=", hierarchy$segment, "\n", sep = "")
  cat("FTN_CAL_MATRIX_PREFLIGHT_HAS_SIGNATURE=", preflight_has_signature, "\n", sep = "")
  cat("FTN_CAL_MATRIX_ARTIFACT_SIGNATURE=", art_signature, "\n", sep = "")
  cat("FTN_CAL_MATRIX_METADATA_SIGNATURE=", cal_signature, "\n", sep = "")
  cat("FTN_CAL_MATRIX_UI_OUTPUT=", axis$output, "\n", sep = "")
  cat("FTN_CAL_MATRIX_UI_AXIS_TITLE=", ui_title, "\n", sep = "")
  cat("FTN_CAL_MATRIX_UI_MONTH_ABBREV=", paste(ui_ticktext[1:min(12L, length(ui_ticktext))], collapse = "|"), "\n", sep = "")
  cat("FTN_CAL_MATRIX_UI_SIGNATURE=", ui_signature, "\n", sep = "")
  cat("FTN_CAL_MATRIX_EXPECTED_AXIS_TITLE=", expected_axis_title, "\n", sep = "")
  cat("FTN_CAL_MATRIX_ROW_PASS=", row_pass, "\n", sep = "")
}

if (!isTRUE(all_pass)) {
  stop("Calendar signature matrix validation failed for one or more commodities.", call. = FALSE)
}

cat("FTN_CAL_MATRIX_STATUS=PASS\n")
progress("status_pass")