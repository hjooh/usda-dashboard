`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0L) y else x
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

first_existing_col <- function(df, candidates) {
  if (!is.data.frame(df)) return(NA_character_)
  nm <- names(df)
  low <- tolower(nm)
  for (cand in candidates) {
    idx <- which(low == tolower(cand))
    if (length(idx) > 0L) return(nm[idx[[1L]]])
  }
  NA_character_
}

dominant_signature <- function(df, sig_col = "calendar_signature") {
  if (!is.data.frame(df) || !(sig_col %in% names(df)) || nrow(df) == 0L) return(NA_character_)
  sig <- trimws(as.character(df[[sig_col]]))
  sig <- sig[!is.na(sig) & nzchar(sig)]
  if (length(sig) == 0L) return(NA_character_)
  tab <- sort(table(sig), decreasing = TRUE)
  as.character(names(tab)[[1L]])
}

signature_to_month_abbrev <- function(signature) {
  parts <- suppressWarnings(as.integer(strsplit(as.character(signature), "-", fixed = TRUE)[[1L]]))
  parts <- parts[!is.na(parts) & parts >= 1L & parts <= 12L]
  if (length(parts) != 12L) return(character(0))
  month.abb[parts]
}

safe_wait_for_idle <- function(app, timeout = 120000) {
  tryCatch({
    app$wait_for_idle(timeout = timeout)
    TRUE
  }, error = function(...) FALSE)
}

get_plot_axis <- function(app, output_id = "comparison_plot") {
  script <- sprintf(
    "(function(){ var id='%s'; var docs=[document]; for (var i=0;i<window.frames.length;i++){ try{ if(window.frames[i].document) docs.push(window.frames[i].document); } catch(e) {} } for (var j=0;j<docs.length;j++){ try{ var gd=docs[j].getElementById(id); if(!gd) continue; var xa=(gd.layout && gd.layout.xaxis)?gd.layout.xaxis:null; if(!xa) continue; var title=''; if (typeof xa.title === 'string') title=xa.title; else if (xa.title && xa.title.text) title=xa.title.text; var tt=[]; if (Array.isArray(xa.ticktext)) tt=xa.ticktext.map(function(v){ return String(v); }); return JSON.stringify({found:true, title:String(title||''), ticktext:tt}); } catch(e) {} } return JSON.stringify({found:false, title:'', ticktext:[]}); })();",
    output_id
  )
  raw <- tryCatch(as.character(app$get_js(script) %||% ""), error = function(...) "")
  if (!nzchar(raw)) {
    return(list(found = FALSE, title = "", ticktext = character(0)))
  }
  parsed <- tryCatch(jsonlite::fromJSON(raw), error = function(...) NULL)
  if (is.null(parsed)) {
    return(list(found = FALSE, title = "", ticktext = character(0)))
  }
  list(
    found = isTRUE(parsed$found),
    title = trimws(as.character(parsed$title %||% "")),
    ticktext = as.character(parsed$ticktext %||% character(0))
  )
}

poll_plot_axis <- function(app, output_id = "comparison_plot", timeout_sec = 90, poll_sec = 0.5) {
  deadline <- Sys.time() + timeout_sec
  last <- list(found = FALSE, title = "", ticktext = character(0))
  repeat {
    axis <- get_plot_axis(app, output_id = output_id)
    if (isTRUE(axis$found) && length(axis$ticktext) >= 12L && nzchar(axis$title)) {
      return(axis)
    }
    last <- axis
    if (Sys.time() >= deadline) {
      return(last)
    }
    Sys.sleep(poll_sec)
  }
}

ticktext_to_signature <- function(ticktext) {
  vals <- trimws(as.character(ticktext %||% character(0)))
  vals <- vals[!is.na(vals) & nzchar(vals)]
  if (length(vals) < 12L) return(NA_character_)
  vals <- vals[1:12]
  lookup <- stats::setNames(as.character(1:12), tolower(month.abb))
  num <- lookup[tolower(vals)]
  if (any(is.na(num))) return(NA_character_)
  paste(num, collapse = "-")
}

repo_root <- resolve_repo_root()
source(file.path(repo_root, "Programs", "vp_data_utils.R"), local = FALSE)

paths <- vp_paths(repo_root)
artifact_obj <- readRDS(paths$artifact)
artifact_df <- if (is.data.frame(artifact_obj)) artifact_obj else artifact_obj$data
metadata_obj <- readRDS(paths$metadata)
cal_df <- metadata_obj$calendars

trade_col_art <- first_existing_col(artifact_df, c("Trade"))
commodity_col_art <- first_existing_col(artifact_df, c("CommodityName"))
sig_col_art <- first_existing_col(artifact_df, c("calendar_signature"))

trade_col_cal <- first_existing_col(cal_df, c("Trade"))
commodity_col_cal <- first_existing_col(cal_df, c("CommodityName"))
sig_col_cal <- first_existing_col(cal_df, c("calendar_signature"))

if (any(is.na(c(trade_col_art, commodity_col_art, sig_col_art, trade_col_cal, commodity_col_cal, sig_col_cal)))) {
  stop("Missing required trade/commodity/signature columns in artifact or metadata calendars.", call. = FALSE)
}

preflight_summary <- file.path(repo_root, "Logs", "ftn_preflight", "20260810T110101_retry", "summary.txt")
preflight_signatures <- character(0)
if (file.exists(preflight_summary)) {
  lines <- readLines(preflight_summary, warn = FALSE)
  sig_line <- lines[grepl("^top_calendar_signatures=", lines)]
  if (length(sig_line) > 0L) {
    preflight_signatures <- trimws(strsplit(sub("^top_calendar_signatures=", "", sig_line[[1L]]), "\\|", perl = TRUE)[[1L]])
    preflight_signatures <- preflight_signatures[nzchar(preflight_signatures)]
  }
}

candidates <- data.frame(
  CommodityName = c("Bananas", "Oranges"),
  ExpectedSignature = c("1-2-3-4-5-6-7-8-9-10-11-12", "10-11-12-1-2-3-4-5-6-7-8-9"),
  stringsAsFactors = FALSE
)

Sys.setenv(NOT_CRAN = "true")
if (!requireNamespace("shinytest2", quietly = TRUE)) {
  stop("Package 'shinytest2' is required for calendar matrix probe.", call. = FALSE)
}
if (!requireNamespace("jsonlite", quietly = TRUE)) {
  stop("Package 'jsonlite' is required for calendar matrix probe.", call. = FALSE)
}

app <- shinytest2::AppDriver$new(
  app_dir = repo_root,
  name = paste0("ftn_calendar_matrix_", as.integer(as.numeric(Sys.time()))),
  load_timeout = 120000,
  timeout = 120000
)
on.exit(app$stop(), add = TRUE)
invisible(safe_wait_for_idle(app, timeout = 120000))

try(app$set_inputs(data_frequency = "monthly"), silent = TRUE)
try(app$set_inputs(data_source_choice = "vp_trade"), silent = TRUE)
invisible(safe_wait_for_idle(app, timeout = 120000))

all_pass <- TRUE
for (i in seq_len(nrow(candidates))) {
  commodity <- candidates$CommodityName[[i]]
  expected_signature <- candidates$ExpectedSignature[[i]]

  art_rows <- artifact_df[
    tolower(trimws(as.character(artifact_df[[trade_col_art]]))) == "export" &
      trimws(as.character(artifact_df[[commodity_col_art]])) == commodity,
    , drop = FALSE
  ]
  art_signature <- dominant_signature(art_rows, sig_col = sig_col_art)

  cal_rows <- cal_df[
    tolower(trimws(as.character(cal_df[[trade_col_cal]]))) == "export" &
      trimws(as.character(cal_df[[commodity_col_cal]])) == commodity,
    , drop = FALSE
  ]
  cal_signature <- dominant_signature(cal_rows, sig_col = sig_col_cal)

  # Drive Shiny controls to commodity scope.
  try(app$set_inputs(vp_group_choice = "__all__"), silent = TRUE)
  try(app$set_inputs(vp_subgroup_choice = "__all__"), silent = TRUE)
  try(app$set_inputs(vp_market_segment_choice = "__all__"), silent = TRUE)
  try(app$set_inputs(vp_commodity_name_choice = commodity), silent = TRUE)
  try(app$set_inputs(commodity_choice = "All"), silent = TRUE)
  try(app$set_inputs(data_frequency = "monthly"), silent = TRUE)
  invisible(safe_wait_for_idle(app, timeout = 120000))

  axis <- poll_plot_axis(app, output_id = "comparison_plot", timeout_sec = 120, poll_sec = 0.75)
  ui_title <- trimws(as.character(axis$title %||% ""))
  ui_tick <- as.character(axis$ticktext %||% character(0))
  ui_signature <- ticktext_to_signature(ui_tick)

  expected_axis_title <- if (identical(expected_signature, "1-2-3-4-5-6-7-8-9-10-11-12")) {
    "Calendar Year Month"
  } else {
    "Commodity Year Month"
  }

  preflight_has_signature <- expected_signature %in% preflight_signatures
  artifact_match <- identical(art_signature, expected_signature)
  metadata_match <- identical(cal_signature, expected_signature)
  ui_signature_match <- identical(ui_signature, expected_signature)
  ui_title_match <- identical(ui_title, expected_axis_title)

  row_pass <- all(c(preflight_has_signature, artifact_match, metadata_match, ui_signature_match, ui_title_match))
  if (!row_pass) all_pass <- FALSE

  cat("FTN_CAL_MATRIX_COMMODITY=", commodity, "\n", sep = "")
  cat("FTN_CAL_MATRIX_EXPECTED_SIGNATURE=", expected_signature, "\n", sep = "")
  cat("FTN_CAL_MATRIX_PREFLIGHT_HAS_SIGNATURE=", preflight_has_signature, "\n", sep = "")
  cat("FTN_CAL_MATRIX_ARTIFACT_SIGNATURE=", art_signature, "\n", sep = "")
  cat("FTN_CAL_MATRIX_METADATA_SIGNATURE=", cal_signature, "\n", sep = "")
  cat("FTN_CAL_MATRIX_UI_AXIS_TITLE=", ui_title, "\n", sep = "")
  cat("FTN_CAL_MATRIX_UI_MONTH_ABBREV=", paste(ui_tick[1:min(12L, length(ui_tick))], collapse = "|"), "\n", sep = "")
  cat("FTN_CAL_MATRIX_UI_SIGNATURE=", ui_signature, "\n", sep = "")
  cat("FTN_CAL_MATRIX_EXPECTED_AXIS_TITLE=", expected_axis_title, "\n", sep = "")
  cat("FTN_CAL_MATRIX_ROW_PASS=", row_pass, "\n", sep = "")
}

if (!all_pass) {
  stop("Calendar signature matrix validation failed for one or more commodities.", call. = FALSE)
}

cat("FTN_CAL_MATRIX_STATUS=PASS\n")
