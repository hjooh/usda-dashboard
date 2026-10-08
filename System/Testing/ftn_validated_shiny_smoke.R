if (!requireNamespace("shinytest2", quietly = TRUE)) {
  stop("Package 'shinytest2' is required for ftn_validated_shiny_smoke.R", call. = FALSE)
}

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

to_bool <- function(value) {
  if (identical(value, TRUE)) return(TRUE)
  if (identical(value, FALSE)) return(FALSE)
  identical(tolower(trimws(as.character(value %||% ""))), "true")
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

text_visible <- function(app, text_value) {
  script <- sprintf(
    "(function(){ var wanted = '%s'; var wantedNorm = String(wanted || '').trim().toLowerCase(); var docs = [document]; for (var i = 0; i < window.frames.length; i++) { try { if (window.frames[i].document) docs.push(window.frames[i].document); } catch (e) {} } function isVisible(el, docRef) { if (!el) return false; var node = el; while (node && node !== docRef.body) { var w = docRef.defaultView || window; var style = w.getComputedStyle(node); if (style && (style.display === 'none' || style.visibility === 'hidden' || style.opacity === '0')) return false; node = node.parentElement; } return true; } for (var j = 0; j < docs.length; j++) { try { var nodes = docs[j].querySelectorAll('*'); for (var k = 0; k < nodes.length; k++) { var txt = (nodes[k].textContent || '').trim().toLowerCase(); if (txt === wantedNorm && isVisible(nodes[k], docs[j])) return true; } } catch (e) {} } return false; })();",
    text_value
  )
  value <- tryCatch(app$get_js(script), error = function(...) FALSE)
  to_bool(value)
}

label_visible <- function(app, label_text) {
  script <- sprintf(
    "(function(){ var wanted = '%s'; var docs = [document]; for (var i = 0; i < window.frames.length; i++) { try { if (window.frames[i].document) docs.push(window.frames[i].document); } catch (e) {} } function isVisible(el, docRef) { if (!el) return false; var node = el; while (node && node !== docRef.body) { var w = docRef.defaultView || window; var style = w.getComputedStyle(node); if (style && (style.display === 'none' || style.visibility === 'hidden' || style.opacity === '0')) return false; node = node.parentElement; } return true; } for (var j = 0; j < docs.length; j++) { try { var labels = docs[j].querySelectorAll('label'); for (var k = 0; k < labels.length; k++) { var txt = (labels[k].textContent || '').trim(); if (txt === wanted && isVisible(labels[k], docs[j])) return true; } } catch (e) {} } return false; })();",
    label_text
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

get_body_snippet <- function(app, width = 320L) {
  script <- sprintf(
    "(function(){ var t = (document.body && document.body.innerText) ? document.body.innerText : ''; return String(t).substring(0, %d); })();",
    as.integer(width)
  )
  value <- tryCatch(as.character(app$get_js(script) %||% ""), error = function(...) "")
  gsub("[\r\n]+", " ", value)
}

safe_wait_for_idle <- function(app, timeout = 120000) {
  tryCatch({
    app$wait_for_idle(timeout = timeout)
    TRUE
  }, error = function(...) {
    FALSE
  })
}

wait_for_dom_id <- function(app, id, timeout_sec = 180, poll_sec = 0.5) {
  deadline <- Sys.time() + timeout_sec
  repeat {
    if (dom_exists(app, id)) {
      return(TRUE)
    }
    if (Sys.time() >= deadline) {
      return(FALSE)
    }
    Sys.sleep(poll_sec)
  }
}

wait_for_select_choices <- function(app, input_id, timeout_sec = 180, poll_sec = 0.5) {
  deadline <- Sys.time() + timeout_sec
  repeat {
    values <- get_select_choices(app, input_id)
    if (length(values) > 0L) {
      return(values)
    }
    if (Sys.time() >= deadline) {
      return(character(0))
    }
    Sys.sleep(poll_sec)
  }
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

wait_for_select_value <- function(app, input_id, timeout_sec = 60, poll_sec = 0.5) {
  deadline <- Sys.time() + timeout_sec
  repeat {
    value <- get_select_current_value(app, input_id)
    if (nzchar(value)) return(value)
    if (Sys.time() >= deadline) return("")
    Sys.sleep(poll_sec)
  }
}

wait_for_source_state <- function(app, timeout_sec = 180, poll_sec = 0.5) {
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

repo_root <- resolve_repo_root()
Sys.setenv(NOT_CRAN = "true")

required_controls <- c(
  "data_source_choice",
  "vp_trade_flow_choice",
  "vp_group_choice",
  "vp_subgroup_choice",
  "vp_market_segment_choice",
  "vp_commodity_name_choice",
  "commodity_choice",
  "country_choice"
)

app <- NULL
id_wait <- NULL
launch_diagnostics <- character(0)

for (attempt in seq_len(3L)) {
  app_name <- paste0("ftn_validated_smoke_", attempt, "_", as.integer(as.numeric(Sys.time())))
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

  invisible(safe_wait_for_idle(app_candidate, timeout = 30000))
  id_candidate <- wait_for_required_ids(app_candidate, required_controls, timeout_sec = 90)
  if (isTRUE(id_candidate$ok)) {
    app <- app_candidate
    id_wait <- id_candidate
    break
  }

  body_snippet <- get_body_snippet(app_candidate)
  id_sample <- paste(utils::head(id_candidate$ids, 30L), collapse = ",")
  launch_diagnostics <- c(
    launch_diagnostics,
    paste0("attempt=", attempt, "|body=", body_snippet, "|ids=", id_sample)
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

control_presence <- stats::setNames(required_controls %in% id_wait$ids, required_controls)

source_state <- wait_for_source_state(app, timeout_sec = 180)
source_choices <- source_state$source_choices
trade_flow_choices <- wait_for_select_choices(app, "vp_trade_flow_choice", timeout_sec = 45)
source_input_value <- source_state$source_input_value
source_select_value <- source_state$source_select_value
source_js_input_value <- source_state$source_js_input_value
source_effective_value <- source_state$source_effective_value

group_choices <- wait_for_select_choices(app, "vp_group_choice", timeout_sec = 45)
subgroup_choices <- wait_for_select_choices(app, "vp_subgroup_choice", timeout_sec = 45)
segment_choices <- wait_for_select_choices(app, "vp_market_segment_choice", timeout_sec = 45)
top_commodity_choices <- wait_for_select_choices(app, "vp_commodity_name_choice", timeout_sec = 45)
type_choices <- wait_for_select_choices(app, "commodity_choice", timeout_sec = 45)

source_has_vp_trade_choice <- source_state$source_has_vp_trade_choice
source_value_is_vp_trade <- source_state$source_value_is_vp_trade
group_has_ftn <- any(tolower(group_choices) == "fruit and tree nuts")
subgroup_has_ftn_values <- any(tolower(subgroup_choices) %in% c("citrus", "noncitrus"))
segment_has_values <- length(segment_choices) > 0L
top_commodity_has_values <- length(top_commodity_choices) > 0L
top_commodity_has_ftn <- any(tolower(top_commodity_choices) %in% c("almonds", "oranges"))
type_has_all <- "All" %in% type_choices
type_has_non_all <- length(setdiff(type_choices, "All")) > 0L

ftn_trade_visible <-
  text_visible(app, "FTN Trade") ||
  text_visible(app, "Fruit and Tree Nut Trade") ||
  text_visible(app, "USDA-ERS Fruit and Tree Nut Trade Analysis Tool")
ftn_title_visible <- text_visible(app, "USDA-ERS Fruit and Tree Nut Trade Analysis Tool")
type_label_visible <- label_visible(app, "Type:") || label_visible(app, "Type")

legacy_vp_trade_visible <- text_visible(app, "VP Trade")
legacy_vegetable_pulse_visible <- text_visible(app, "Vegetable and Pulse")

if (!all(control_presence)) {
  stop(
    paste0(
      "Missing required controls: ",
      paste(names(control_presence)[!control_presence], collapse = ", ")
    ),
    call. = FALSE
  )
}

if (!isTRUE(source_value_is_vp_trade)) {
  stop(
    paste0(
      "Source selection did not resolve to vp_trade. ",
      "source_input_value=", source_input_value,
      "|source_select_value=", source_select_value,
      "|source_js_input_value=", source_js_input_value,
      "|source_effective_value=", source_effective_value,
      "|source_choices=", paste(source_choices, collapse = "|")
    ),
    call. = FALSE
  )
}
if (!isTRUE(group_has_ftn)) stop("Group dropdown does not include 'Fruit and tree nuts'.", call. = FALSE)
if (!isTRUE(subgroup_has_ftn_values)) stop("Subgroup dropdown missing expected FTN values (Citrus/Noncitrus).", call. = FALSE)
if (!isTRUE(segment_has_values)) stop("Market segment dropdown has no values.", call. = FALSE)
if (!isTRUE(top_commodity_has_values)) stop("Commodity dropdown has no values.", call. = FALSE)
if (!isTRUE(top_commodity_has_ftn)) stop("Commodity dropdown missing expected FTN values (Almonds/Oranges).", call. = FALSE)
if (!isTRUE(type_has_all)) stop("Type dropdown does not include 'All'.", call. = FALSE)
if (!isTRUE(type_has_non_all)) stop("Type dropdown does not include non-All FTN options.", call. = FALSE)
if (!isTRUE(ftn_trade_visible)) stop("FTN Trade label is not visible.", call. = FALSE)
if (!isTRUE(ftn_title_visible)) stop("FTN app title is not visible.", call. = FALSE)
if (!isTRUE(type_label_visible)) stop("Type label is not visible.", call. = FALSE)
if (isTRUE(legacy_vp_trade_visible)) stop("Legacy VP Trade label is still visible in the UI.", call. = FALSE)
if (isTRUE(legacy_vegetable_pulse_visible)) stop("Legacy Vegetable and Pulse wording is still visible in the UI.", call. = FALSE)

cat("FTN_SHINY_SMOKE_STATUS=PASS\n")
cat("FTN_SHINY_SOURCE_CHOICES=", paste(source_choices, collapse = "|"), "\n", sep = "")
cat("FTN_SHINY_SOURCE_INPUT_VALUE=", source_input_value, "\n", sep = "")
cat("FTN_SHINY_SOURCE_SELECT_VALUE=", source_select_value, "\n", sep = "")
cat("FTN_SHINY_SOURCE_JS_INPUT_VALUE=", source_js_input_value, "\n", sep = "")
cat("FTN_SHINY_SOURCE_EFFECTIVE_VALUE=", source_effective_value, "\n", sep = "")
cat("FTN_SHINY_SOURCE_HAS_VP_TRADE_CHOICE=", source_has_vp_trade_choice, "\n", sep = "")
cat("FTN_SHINY_SOURCE_VALUE_IS_VP_TRADE=", source_value_is_vp_trade, "\n", sep = "")
cat("FTN_SHINY_GROUP_HAS_FTN=", group_has_ftn, "\n", sep = "")
cat("FTN_SHINY_SUBGROUP_CHOICES=", paste(utils::head(subgroup_choices, 20L), collapse = "|"), "\n", sep = "")
cat("FTN_SHINY_SEGMENT_CHOICES=", paste(utils::head(segment_choices, 20L), collapse = "|"), "\n", sep = "")
cat("FTN_SHINY_TOP_COMMODITY_CHOICES=", paste(utils::head(top_commodity_choices, 20L), collapse = "|"), "\n", sep = "")
cat("FTN_SHINY_TYPE_CHOICES=", paste(utils::head(type_choices, 20L), collapse = "|"), "\n", sep = "")
cat("FTN_SHINY_FTN_TRADE_VISIBLE=", ftn_trade_visible, "\n", sep = "")
cat("FTN_SHINY_FTN_TITLE_VISIBLE=", ftn_title_visible, "\n", sep = "")
cat("FTN_SHINY_LEGACY_VP_VISIBLE=", legacy_vp_trade_visible, "\n", sep = "")
cat("FTN_SHINY_LEGACY_VEGPULSE_VISIBLE=", legacy_vegetable_pulse_visible, "\n", sep = "")