library(shinytest2)

assert_vp_awd_winter_peas_calendar <- function() {
  artifact_path <- file.path("VP Clone", "System", "Processed Data", "vp_trade_monthly_pre.rds")
  artifact <- readRDS(artifact_path)
  rows <- artifact[
    artifact$Trade == "export" &
      artifact$CommodityName == "Austrian winter peas" &
      artifact$commodity == "Austrian winter peas" &
      artifact$country == "GRAND_TOTAL" &
      artifact$market_year == 2026 &
      artifact$calendar_year == 2025 &
      artifact$MonthNum == 7,
    ,
    drop = FALSE
  ]

  stopifnot(
    nrow(rows) > 0L,
    all(rows$analysis_month == 1L),
    all(rows$month_abbrev == "Jul"),
    all(rows$calendar_signature == "7-8-9-10-11-12-1-2-3-4-5-6"),
    all(rows$calendar_source_scope == "world")
  )
}

assert_vp_all_type_artifact_contract <- function() {
  artifact_path <- file.path("VP Clone", "System", "Processed Data", "vp_trade_monthly_pre.rds")
  artifact <- readRDS(artifact_path)

  artichoke_all_rows <- artifact[
    artifact$Trade == "import" &
      artifact$CommodityName == "Artichokes" &
      artifact$commodity == "All",
    ,
    drop = FALSE
  ]

  stopifnot(nrow(artichoke_all_rows) > 0L)
  stopifnot(all(c("unit_value", "ytd_unit_value") %in% names(artichoke_all_rows)))

  finite_rate_rows <- is.finite(suppressWarnings(as.numeric(artichoke_all_rows$monthlyvalue))) &
    is.finite(suppressWarnings(as.numeric(artichoke_all_rows$monthlyexports))) &
    suppressWarnings(as.numeric(artichoke_all_rows$monthlyexports)) != 0
  if (any(finite_rate_rows, na.rm = TRUE)) {
    expected_unit_value <- suppressWarnings(as.numeric(artichoke_all_rows$monthlyvalue[finite_rate_rows])) /
      suppressWarnings(as.numeric(artichoke_all_rows$monthlyexports[finite_rate_rows]))
    actual_unit_value <- suppressWarnings(as.numeric(artichoke_all_rows$unit_value[finite_rate_rows]))
    stopifnot(all(abs(actual_unit_value - expected_unit_value) < 1e-6, na.rm = TRUE))
  }
}

find_vp_share_case <- function(artifact) {
  key_cols <- c("Trade", "Group", "Subgroup", "MarketSegment", "CommodityName", "market_year", "analysis_month")
  world_all <- artifact[
    artifact$commodity == "All" &
      artifact$country == "GRAND_TOTAL" &
      is.finite(suppressWarnings(as.numeric(artifact$ytd_exports))) &
      suppressWarnings(as.numeric(artifact$ytd_exports)) > 0,
    ,
    drop = FALSE
  ]

  if (nrow(world_all) == 0L) {
    stop("No World All rows found for share-case audit.")
  }

  for (i in seq_len(nrow(world_all))) {
    wr <- world_all[i, , drop = FALSE]
    mask_key <-
      artifact$Trade == wr$Trade &
      artifact$Group == wr$Group &
      artifact$Subgroup == wr$Subgroup &
      artifact$MarketSegment == wr$MarketSegment &
      artifact$CommodityName == wr$CommodityName &
      artifact$market_year == wr$market_year &
      artifact$analysis_month == wr$analysis_month

    country_all <- artifact[
      mask_key &
        artifact$commodity == "All" &
        artifact$country != "GRAND_TOTAL" &
        is.finite(suppressWarnings(as.numeric(artifact$ytd_exports))) &
        suppressWarnings(as.numeric(artifact$ytd_exports)) > 0,
      ,
      drop = FALSE
    ]
    if (nrow(country_all) == 0L) {
      next
    }

    for (j in seq_len(nrow(country_all))) {
      cr <- country_all[j, , drop = FALSE]
      detail_country <- artifact[
        mask_key &
          artifact$country == cr$country &
          artifact$commodity != "All" &
          is.finite(suppressWarnings(as.numeric(artifact$ytd_exports))) &
          suppressWarnings(as.numeric(artifact$ytd_exports)) > 0,
        ,
        drop = FALSE
      ]
      if (nrow(detail_country) == 0L) {
        next
      }

      detail_values <- unique(as.character(detail_country$commodity))
      detail_values <- detail_values[!is.na(detail_values) & nzchar(detail_values)]
      for (detail in detail_values) {
        world_detail <- artifact[
          mask_key &
            artifact$commodity == detail &
            artifact$country == "GRAND_TOTAL" &
            is.finite(suppressWarnings(as.numeric(artifact$ytd_exports))) &
            suppressWarnings(as.numeric(artifact$ytd_exports)) > 0,
          ,
          drop = FALSE
        ]
        if (nrow(world_detail) == 0L) {
          next
        }

        detail_country_row <- detail_country[detail_country$commodity == detail, , drop = FALSE][1, , drop = FALSE]
        return(list(
          key = wr[, key_cols, drop = FALSE],
          country = as.character(cr$country[[1]]),
          detail = detail,
          all_world = suppressWarnings(as.numeric(wr$ytd_exports[[1]])),
          all_country = suppressWarnings(as.numeric(cr$ytd_exports[[1]])),
          detail_world = suppressWarnings(as.numeric(world_detail$ytd_exports[[1]])),
          detail_country = suppressWarnings(as.numeric(detail_country_row$ytd_exports[[1]]))
        ))
      }
    }
  }

  stop("Could not find a share-case with valid All and detail country/world rows.")
}

assert_vp_type_specific_share_contract <- function() {
  artifact_path <- file.path("VP Clone", "System", "Processed Data", "vp_trade_monthly_pre.rds")
  artifact <- readRDS(artifact_path)
  share_case <- find_vp_share_case(artifact)

  stopifnot(
    is.finite(share_case$all_world), share_case$all_world > 0,
    is.finite(share_case$all_country), share_case$all_country >= 0,
    is.finite(share_case$detail_world), share_case$detail_world > 0,
    is.finite(share_case$detail_country), share_case$detail_country >= 0
  )

  share_all <- share_case$all_country / share_case$all_world
  share_detail <- share_case$detail_country / share_case$detail_world

  stopifnot(
    is.finite(share_all), share_all >= 0,
    is.finite(share_detail), share_detail >= 0,
    share_case$all_world + 1e-9 >= share_case$detail_world
  )

  list(
    context = paste(
      as.character(share_case$key$Trade[[1]]),
      as.character(share_case$key$Group[[1]]),
      as.character(share_case$key$Subgroup[[1]]),
      as.character(share_case$key$MarketSegment[[1]]),
      as.character(share_case$key$CommodityName[[1]]),
      paste0("MY", as.character(share_case$key$market_year[[1]])),
      paste0("M", as.character(share_case$key$analysis_month[[1]])),
      paste0("Country=", share_case$country),
      paste0("Detail=", share_case$detail),
      sep = " | "
    ),
    share_all = share_all,
    share_detail = share_detail
  )
}

assert_vp_rollup_schema_and_potato_contract <- function() {
  artifact_path <- file.path("VP Clone", "System", "Processed Data", "vp_trade_monthly_pre.rds")
  artifact <- readRDS(artifact_path)

  required_rollup_cols <- c(
    "vp_rollup_level", "vp_rollup_path", "vp_is_rollup",
    "vp_volume_family_mixed", "vp_mixed_source_replacement", "vp_rollup_schema_version",
    "unit_value", "unit_value_unit", "ytd_unit_value", "ytd_unit_value_unit"
  )
  stopifnot(all(required_rollup_cols %in% names(artifact)))

  schema_values <- unique(trimws(as.character(artifact$vp_rollup_schema_version)))
  schema_values <- schema_values[!is.na(schema_values) & nzchar(schema_values)]
  stopifnot("vp_rollup_schema_2026_07_28_v1" %in% schema_values)

  level_values <- unique(trimws(as.character(artifact$vp_rollup_level)))
  stopifnot(all(c("native", "segment_all", "subgroup_all", "group_all") %in% level_values))

  rollup_mask <- !is.na(artifact$vp_is_rollup) & as.logical(artifact$vp_is_rollup)
  stopifnot(any(rollup_mask))

  mixed_mask <- !is.na(artifact$vp_volume_family_mixed) & as.logical(artifact$vp_volume_family_mixed)
  if (any(mixed_mask)) {
    stopifnot(
      all(is.na(suppressWarnings(as.numeric(artifact$monthlyexports[mixed_mask])))),
      all(is.na(suppressWarnings(as.numeric(artifact$ytd_exports[mixed_mask]))))
    )
  }

  potato_mask <- grepl("potato", tolower(trimws(as.character(artifact$CommodityName))))
  potato_rows <- artifact[potato_mask, , drop = FALSE]
  stopifnot(nrow(potato_rows) > 0L)

  group_token <- "__vp_rollup_all_group__"
  subgroup_token <- "__vp_rollup_all_subgroup__"
  market_segment_token <- "__vp_rollup_all_market_segment__"

  for (trade_flow in c("export", "import")) {
    flow_rows <- potato_rows[tolower(trimws(as.character(potato_rows$Trade))) == trade_flow, , drop = FALSE]
    stopifnot(nrow(flow_rows) > 0L)

    flow_rollup_rows <- flow_rows[
      flow_rows$Group == group_token &
        flow_rows$Subgroup == subgroup_token &
        flow_rows$MarketSegment == market_segment_token &
        flow_rows$commodity == "All",
      ,
      drop = FALSE
    ]
    stopifnot(nrow(flow_rollup_rows) > 0L)

    finite_rate_rows <- is.finite(suppressWarnings(as.numeric(flow_rollup_rows$monthlyvalue))) &
      is.finite(suppressWarnings(as.numeric(flow_rollup_rows$monthlyexports))) &
      suppressWarnings(as.numeric(flow_rollup_rows$monthlyexports)) != 0
    if (any(finite_rate_rows, na.rm = TRUE)) {
      expected_unit_values <- suppressWarnings(as.numeric(flow_rollup_rows$monthlyvalue[finite_rate_rows])) /
        suppressWarnings(as.numeric(flow_rollup_rows$monthlyexports[finite_rate_rows]))
      actual_unit_values <- suppressWarnings(as.numeric(flow_rollup_rows$unit_value[finite_rate_rows]))
      stopifnot(all(abs(actual_unit_values - expected_unit_values) < 1e-6, na.rm = TRUE))
      finite_ytd_values <- is.finite(suppressWarnings(as.numeric(flow_rollup_rows$ytd_unit_value[finite_rate_rows])))
      finite_ytd_values[is.na(finite_ytd_values)] <- FALSE
      stopifnot(any(finite_ytd_values))
    }
  }
}

pick_input <- function(values, name) {
  value <- values$input[[name]]
  if (is.null(value) || length(value) == 0L) {
    return(NA_character_)
  }
  as.character(value[[1]])
}

assert_vp_awd_winter_peas_calendar()
assert_vp_all_type_artifact_contract()
share_contract <- assert_vp_type_specific_share_contract()
assert_vp_rollup_schema_and_potato_contract()

Sys.setenv(NOT_CRAN = "true")
app <- shinytest2::AppDriver$new(
  app_dir = file.path("VP Clone"),
  name = "vp_smoke",
  load_timeout = 60000,
  timeout = 60000
)
on.exit(app$stop(), add = TRUE)

app$wait_for_idle(timeout = 60000)

dom_exists <- function(id) {
  script <- sprintf("(function(){ var id = '%s'; var docs = [document]; for (var i = 0; i < window.frames.length; i++) { try { if (window.frames[i].document) docs.push(window.frames[i].document); } catch (e) {} } for (var j = 0; j < docs.length; j++) { try { if (docs[j].getElementById(id) !== null) return true; } catch (e) {} } return false; })();", id)
  out <- app$get_js(script)
  if (identical(out, TRUE)) {
    return(TRUE)
  }
  out_chr <- tolower(trimws(as.character(out %||% "")))
  identical(out_chr, "true")
}

dom_visible <- function(id) {
  script <- sprintf("(function(){ var id = '%s'; var docs = [document]; for (var i = 0; i < window.frames.length; i++) { try { if (window.frames[i].document) docs.push(window.frames[i].document); } catch (e) {} } for (var j = 0; j < docs.length; j++) { try { var el = docs[j].getElementById(id); if (!el) continue; var w = docs[j].defaultView || window; var style = w.getComputedStyle(el); if (!style) continue; var shown = style.display !== 'none' && style.visibility !== 'hidden' && style.opacity !== '0'; if (shown) return true; } catch (e) {} } return false; })();", id)
  out <- app$get_js(script)
  if (identical(out, TRUE)) {
    return(TRUE)
  }
  out_chr <- tolower(trimws(as.character(out %||% "")))
  identical(out_chr, "true")
}

label_visible <- function(label_text) {
  script <- sprintf(
    "(function(){ var wanted = '%s'; var docs = [document]; for (var i = 0; i < window.frames.length; i++) { try { if (window.frames[i].document) docs.push(window.frames[i].document); } catch (e) {} } function isVisible(el, docRef) { if (!el) return false; var node = el; while (node && node !== docRef.body) { var w = docRef.defaultView || window; var style = w.getComputedStyle(node); if (style && (style.display === 'none' || style.visibility === 'hidden' || style.opacity === '0')) return false; node = node.parentElement; } return true; } for (var j = 0; j < docs.length; j++) { try { var labels = docs[j].querySelectorAll('label'); for (var k = 0; k < labels.length; k++) { var txt = (labels[k].textContent || '').trim(); if (txt === wanted && isVisible(labels[k], docs[j])) return true; } } catch (e) {} } return false; })();",
    label_text
  )
  out <- app$get_js(script)
  if (identical(out, TRUE)) {
    return(TRUE)
  }
  out_chr <- tolower(trimws(as.character(out %||% "")))
  identical(out_chr, "true")
}

text_visible <- function(text_value) {
  script <- sprintf(
    "(function(){ var wanted = '%s'; var wantedNorm = String(wanted || '').trim().toLowerCase(); var docs = [document]; for (var i = 0; i < window.frames.length; i++) { try { if (window.frames[i].document) docs.push(window.frames[i].document); } catch (e) {} } function isVisible(el, docRef) { if (!el) return false; var node = el; while (node && node !== docRef.body) { var w = docRef.defaultView || window; var style = w.getComputedStyle(node); if (style && (style.display === 'none' || style.visibility === 'hidden' || style.opacity === '0')) return false; node = node.parentElement; } return true; } for (var j = 0; j < docs.length; j++) { try { var nodes = docs[j].querySelectorAll('*'); for (var k = 0; k < nodes.length; k++) { var txt = (nodes[k].textContent || '').trim().toLowerCase(); if (txt === wantedNorm && isVisible(nodes[k], docs[j])) return true; } } catch (e) {} } return false; })();",
    text_value
  )
  out <- app$get_js(script)
  if (identical(out, TRUE)) {
    return(TRUE)
  }
  out_chr <- tolower(trimws(as.character(out %||% "")))
  identical(out_chr, "true")
}

get_input_label_text <- function(input_id) {
  script <- sprintf(
    "(function(){ var id = '%s'; var docs = [document]; for (var i = 0; i < window.frames.length; i++) { try { if (window.frames[i].document) docs.push(window.frames[i].document); } catch (e) {} } for (var j = 0; j < docs.length; j++) { try { var el = docs[j].getElementById(id); if (!el) continue; var label = docs[j].querySelector('label[for=\\\"' + id + '\\\"]'); if (label) return (label.textContent || '').trim(); var parent = el.closest('.form-group') || el.parentElement; if (parent) { label = parent.querySelector('label'); if (label) return (label.textContent || '').trim(); } } catch (e) {} } return ''; })();",
    input_id
  )
  out <- app$get_js(script)
  trimws(as.character(out %||% ""))
}

get_select_choices <- function(input_id) {
  script <- sprintf(
    "(function(){ var id = '%s'; var docs = [document]; for (var i = 0; i < window.frames.length; i++) { try { if (window.frames[i].document) docs.push(window.frames[i].document); } catch (e) {} } for (var j = 0; j < docs.length; j++) { try { var el = docs[j].getElementById(id); if (!el) continue; if (el.selectize && el.selectize.options) { var optionKeys = Object.keys(el.selectize.options).map(function(x){ return (x || '').trim(); }).filter(function(x){ return x.length > 0; }); if (optionKeys.length > 0) return optionKeys.join('|||'); } if (el.options) { var vals = []; for (var k = 0; k < el.options.length; k++) { vals.push((el.options[k].value || '').trim()); } return vals.join('|||'); } } catch (e) {} } return ''; })();",
    input_id
  )
  out <- app$get_js(script)
  raw <- as.character(out %||% "")
  if (!nzchar(raw)) {
    return(character(0))
  }
  parts <- strsplit(raw, "\\|\\|\\|", fixed = FALSE)[[1]]
  parts <- trimws(parts)
  parts[nzchar(parts)]
}

get_data_table_columns <- function(output_id) {
  script <- sprintf(
    "(function(){ var id = '%s'; var docs = [document]; for (var i = 0; i < window.frames.length; i++) { try { if (window.frames[i].document) docs.push(window.frames[i].document); } catch (e) {} } for (var j = 0; j < docs.length; j++) { try { var root = docs[j].getElementById(id); if (!root) continue; var headers = root.querySelectorAll('table thead th'); if (!headers || headers.length === 0) continue; var vals = []; for (var k = 0; k < headers.length; k++) { vals.push((headers[k].textContent || '').trim()); } return vals.join('|||'); } catch (e) {} } return ''; })();",
    output_id
  )
  out <- app$get_js(script)
  raw <- as.character(out %||% "")
  if (!nzchar(raw)) {
    return(character(0))
  }
  parts <- strsplit(raw, "\\|\\|\\|", fixed = FALSE)[[1]]
  parts <- trimws(parts)
  parts[nzchar(parts)]
}

get_plotly_first_tick_label <- function(plot_id) {
  script <- sprintf(
    "(function(){ var id = '%s'; var docs = [document]; for (var i = 0; i < window.frames.length; i++) { try { if (window.frames[i].document) docs.push(window.frames[i].document); } catch (e) {} } for (var j = 0; j < docs.length; j++) { try { var container = docs[j].getElementById(id); if (!container) continue; var plotNode = container.querySelector('.js-plotly-plot') || container; var tick = null; if (plotNode.layout && plotNode.layout.xaxis && Array.isArray(plotNode.layout.xaxis.ticktext) && plotNode.layout.xaxis.ticktext.length > 0) { tick = plotNode.layout.xaxis.ticktext[0]; } if (!tick && plotNode._fullLayout && plotNode._fullLayout.xaxis && Array.isArray(plotNode._fullLayout.xaxis.ticktext) && plotNode._fullLayout.xaxis.ticktext.length > 0) { tick = plotNode._fullLayout.xaxis.ticktext[0]; } if (tick !== null && tick !== undefined) return String(tick); } catch (e) {} } return ''; })();",
    plot_id
  )
  out <- app$get_js(script)
  trimws(as.character(out %||% ""))
}

get_plotly_trace_name_count <- function(plot_id, trace_name) {
  script <- sprintf(
    "(function(){ var id = '%s'; var target = '%s'; var docs = [document]; for (var i = 0; i < window.frames.length; i++) { try { if (window.frames[i].document) docs.push(window.frames[i].document); } catch (e) {} } for (var j = 0; j < docs.length; j++) { try { var container = docs[j].getElementById(id); if (!container) continue; var plotNode = container.querySelector('.js-plotly-plot') || container; var data = []; if (plotNode.data && Array.isArray(plotNode.data)) { data = plotNode.data; } else if (plotNode._fullData && Array.isArray(plotNode._fullData)) { data = plotNode._fullData; } var count = 0; for (var k = 0; k < data.length; k++) { var nm = data[k] && data[k].name ? String(data[k].name).trim() : ''; if (nm === target) count++; } return String(count); } catch (e) {} } return '0'; })();",
    plot_id,
    trace_name
  )
  out <- app$get_js(script)
  suppressWarnings(as.integer(trimws(as.character(out %||% "0")))) %||% 0L
}

get_plotly_trace_prefix_count <- function(plot_id, trace_prefix) {
  script <- sprintf(
    "(function(){ var id = '%s'; var prefix = '%s'; var docs = [document]; for (var i = 0; i < window.frames.length; i++) { try { if (window.frames[i].document) docs.push(window.frames[i].document); } catch (e) {} } for (var j = 0; j < docs.length; j++) { try { var container = docs[j].getElementById(id); if (!container) continue; var plotNode = container.querySelector('.js-plotly-plot') || container; var data = []; if (plotNode.data && Array.isArray(plotNode.data)) { data = plotNode.data; } else if (plotNode._fullData && Array.isArray(plotNode._fullData)) { data = plotNode._fullData; } var count = 0; for (var k = 0; k < data.length; k++) { var nm = data[k] && data[k].name ? String(data[k].name).trim() : ''; if (nm.indexOf(prefix) === 0) count++; } return String(count); } catch (e) {} } return '0'; })();",
    plot_id,
    trace_prefix
  )
  out <- app$get_js(script)
  suppressWarnings(as.integer(trimws(as.character(out %||% "0")))) %||% 0L
}

get_plotly_axis_title <- function(plot_id, axis = "x") {
  axis <- if (identical(axis, "y")) "y" else "x"
  script <- sprintf(
    "(function(){ var id = '%s'; var axis = '%s'; var docs = [document]; for (var i = 0; i < window.frames.length; i++) { try { if (window.frames[i].document) docs.push(window.frames[i].document); } catch (e) {} } for (var j = 0; j < docs.length; j++) { try { var container = docs[j].getElementById(id); if (!container) continue; var plotNode = container.querySelector('.js-plotly-plot') || container; var key = axis === 'y' ? 'yaxis' : 'xaxis'; var ttl = ''; if (plotNode.layout && plotNode.layout[key] && plotNode.layout[key].title) { ttl = plotNode.layout[key].title.text || plotNode.layout[key].title || ''; } if ((!ttl || String(ttl).trim().length === 0) && plotNode._fullLayout && plotNode._fullLayout[key] && plotNode._fullLayout[key].title) { ttl = plotNode._fullLayout[key].title.text || plotNode._fullLayout[key].title || ''; } if (ttl !== null && ttl !== undefined) return String(ttl); } catch (e) {} } return ''; })();",
    plot_id,
    axis
  )
  out <- app$get_js(script)
  trimws(as.character(out %||% ""))
}

get_plotly_title <- function(plot_id) {
  script <- sprintf(
    "(function(){ var id = '%s'; var docs = [document]; for (var i = 0; i < window.frames.length; i++) { try { if (window.frames[i].document) docs.push(window.frames[i].document); } catch (e) {} } for (var j = 0; j < docs.length; j++) { try { var container = docs[j].getElementById(id); if (!container) continue; var plotNode = container.querySelector('.js-plotly-plot') || container; var ttl = ''; if (plotNode.layout && plotNode.layout.title) { ttl = plotNode.layout.title.text || plotNode.layout.title || ''; } if ((!ttl || String(ttl).trim().length === 0) && plotNode._fullLayout && plotNode._fullLayout.title) { ttl = plotNode._fullLayout.title.text || plotNode._fullLayout.title || ''; } if (ttl !== null && ttl !== undefined) return String(ttl); } catch (e) {} } return ''; })();",
    plot_id
  )
  out <- app$get_js(script)
  trimws(as.character(out %||% ""))
}

tab_choice_available <- function(tab_value) {
  script <- sprintf(
    "(function(){ var wanted = '%s'; var docs = [document]; for (var i = 0; i < window.frames.length; i++) { try { if (window.frames[i].document) docs.push(window.frames[i].document); } catch (e) {} } for (var j = 0; j < docs.length; j++) { try { var nodes = docs[j].querySelectorAll('[data-value]'); for (var k = 0; k < nodes.length; k++) { var v = (nodes[k].getAttribute('data-value') || '').trim(); if (v === wanted) return true; } } catch (e) {} } return false; })();",
    tab_value
  )
  out <- app$get_js(script)
  if (identical(out, TRUE)) {
    return(TRUE)
  }
  out_chr <- tolower(trimws(as.character(out %||% "")))
  identical(out_chr, "true")
}

has_all_values <- function(values, required_values) {
  if (length(required_values) == 0L) {
    return(TRUE)
  }
  all(required_values %in% values)
}

values <- app$get_values(input = c(
  "data_source_choice",
  "data_frequency",
  "vp_commodity_name_choice",
  "vp_market_segment_choice",
  "vp_group_choice",
  "vp_subgroup_choice",
  "commodity_choice",
  "basis_choice"
), output = c("summary_table"))

app$set_inputs(vp_trade_flow_choice = "import", wait_ = FALSE)
app$wait_for_idle(timeout = 60000)
app$set_inputs(vp_commodity_name_choice = "Artichokes", wait_ = FALSE)
app$wait_for_idle(timeout = 60000)

values_artichoke <- app$get_values(input = c(
  "vp_trade_flow_choice",
  "vp_commodity_name_choice",
  "commodity_choice"
))

top_commodity_choices <- get_select_choices("vp_commodity_name_choice")
detail_commodity_choices <- get_select_choices("commodity_choice")

expected_artichoke_details <- c(
  "Globe",
  "Prepared or preserved by vinegar",
  "Prepared or preserved, unspecified"
)

top_artichoke_value <- pick_input(values_artichoke, "vp_commodity_name_choice")
sidebar_artichoke_value <- pick_input(values_artichoke, "commodity_choice")
artichoke_trade_flow <- pick_input(values_artichoke, "vp_trade_flow_choice")

top_includes_globe <- "Globe" %in% top_commodity_choices
sidebar_has_expected_details <- has_all_values(detail_commodity_choices, expected_artichoke_details)
sidebar_is_detail_value <- !is.na(sidebar_artichoke_value) && nzchar(sidebar_artichoke_value) && sidebar_artichoke_value %in% detail_commodity_choices
top_and_sidebar_differ <- !is.na(top_artichoke_value) && !is.na(sidebar_artichoke_value) && !identical(top_artichoke_value, sidebar_artichoke_value)
sidebar_has_all <- "All" %in% detail_commodity_choices
sidebar_defaults_all <- identical(sidebar_artichoke_value, "All")

fixture_group <- "Dry pulses"
fixture_subgroup <- "Dried beans"
fixture_segment <- "Dried"
fixture_commodity_name <- "Bambara beans"
fixture_detail <- "Unspecified"

fixture_group_choices <- get_select_choices("vp_group_choice")
fixture_subgroup_choices <- get_select_choices("vp_subgroup_choice")
fixture_segment_choices <- get_select_choices("vp_market_segment_choice")
fixture_name_choices <- get_select_choices("vp_commodity_name_choice")

fixture_available <-
  fixture_group %in% fixture_group_choices &&
  fixture_subgroup %in% fixture_subgroup_choices &&
  fixture_segment %in% fixture_segment_choices &&
  fixture_commodity_name %in% fixture_name_choices

fixture_tick_first <- NA_character_
fixture_type_available <- FALSE
fixture_first_is_jan <- FALSE
historical_tab_available <- FALSE
historical_year_filter_present <- FALSE
historical_year_filter_nonempty <- FALSE
historical_month_tick_first <- NA_character_
historical_month_first_is_jan <- FALSE
historical_current_trace_count <- 0L
historical_x_axis_title <- NA_character_
historical_x_axis_is_month <- FALSE
pace_tab_available <- FALSE
pace_plot_tick_first <- NA_character_
pace_has_current_trace <- FALSE
pace_import_axis_title <- NA_character_
pace_plot_title <- NA_character_
pace_import_title_contains_imports <- FALSE
pace_reset_target_value <- NA_character_
pace_target_changed_before_reset <- FALSE
pace_target_reverted_after_reset <- FALSE
pace_projection_source_after_reset <- NA_character_
pace_projection_source_is_historical <- FALSE
map_tab_available <- FALSE
map_export_title <- NA_character_
map_export_title_contains_exports <- FALSE
map_export_year_field_label <- NA_character_
map_export_share_field_label <- NA_character_
map_import_title <- NA_character_
map_import_title_contains_imports <- FALSE
map_import_year_field_label <- NA_character_
map_import_share_field_label <- NA_character_
map_fixture_title <- NA_character_
map_fixture_title_contains_cy <- FALSE
map_artichoke_year_control_label <- NA_character_
map_artichoke_year_control_label_is_calendar <- FALSE
heatmap_tab_available <- FALSE
heatmap_plot_title <- NA_character_
heatmap_title_contains_heatmap <- FALSE
heatmap_y_axis_title <- NA_character_
heatmap_year_axis_is_calendar <- FALSE
heatmap_analysis_info <- NA_character_
heatmap_analysis_info_excludes_basis <- FALSE
data_tab_available <- FALSE
data_schema_has_csv_columns <- FALSE
data_schema_has_legacy_columns <- FALSE
data_table_columns <- character(0)
data_publish_metric_choice <- NA_character_
data_publish_created <- FALSE
data_publish_created_file <- NA_character_
data_publish_row_count <- NA_integer_
data_publish_hierarchy_cols_present <- FALSE
data_publish_has_rollup_tokens <- NA
data_publish_has_fallback_all_labels <- NA
data_publish_amount_has_gt2_decimals <- NA
cct_tab_available <- FALSE
cct_quick_apply_title_has_side_top <- FALSE
cct_apply_commodity_button_present <- FALSE
cct_vp_panel_commodity_controls_present <- FALSE
cct_vp_panel_commodity_synced_after_apply <- FALSE
cct_top_panel_commodity_choices <- character(0)
cct_top_panel_commodity_after_apply <- NA_character_
awd_country_choices <- character(0)
awd_country_choices_include_taiwan <- FALSE
awd_country_choices_exclude_canada <- FALSE
awd_country_choices_exclude_mexico <- FALSE
awd_country_choices_exclude_aruba <- FALSE
unit_value_overlay_control_present <- FALSE
unit_value_overlay_trace_present <- FALSE

if (isTRUE(fixture_available)) {
  app$set_inputs(vp_trade_flow_choice = "export", wait_ = FALSE)
  app$wait_for_idle(timeout = 60000)
  app$set_inputs(vp_group_choice = fixture_group, wait_ = FALSE)
  app$wait_for_idle(timeout = 60000)
  app$set_inputs(vp_subgroup_choice = fixture_subgroup, wait_ = FALSE)
  app$wait_for_idle(timeout = 60000)
  app$set_inputs(vp_market_segment_choice = fixture_segment, wait_ = FALSE)
  app$wait_for_idle(timeout = 60000)
  app$set_inputs(vp_commodity_name_choice = fixture_commodity_name, wait_ = FALSE)
  app$wait_for_idle(timeout = 60000)

  fixture_detail_choices <- get_select_choices("commodity_choice")
  fixture_type_available <- fixture_detail %in% fixture_detail_choices
  if (isTRUE(fixture_type_available)) {
    app$set_inputs(commodity_choice = fixture_detail, wait_ = FALSE)
    app$wait_for_idle(timeout = 60000)
  }

  fixture_tick_first <- get_plotly_first_tick_label("comparison_plot")
  fixture_first_is_jan <- identical(tolower(fixture_tick_first), "jan")

  metric_choices <- get_select_choices("metric_choice")
  if ("unit_value" %in% metric_choices) {
    app$set_inputs(metric_choice = "unit_value", wait_ = FALSE)
    app$wait_for_idle(timeout = 60000)
    unit_value_overlay_control_present <- dom_exists("show_ytd_unit_value_overlay")
    if (isTRUE(unit_value_overlay_control_present)) {
      app$set_inputs(show_ytd_unit_value_overlay = TRUE, wait_ = FALSE)
      app$wait_for_idle(timeout = 60000)
      unit_value_overlay_trace_present <- get_plotly_trace_name_count("comparison_plot", "Current YTD unit value") > 0L
    }
  }
}

app$set_inputs(vp_trade_flow_choice = "export", wait_ = FALSE)
app$wait_for_idle(timeout = 60000)
app$set_inputs(vp_group_choice = "Dry pulses", wait_ = FALSE)
app$wait_for_idle(timeout = 60000)
app$set_inputs(vp_subgroup_choice = "__all__", wait_ = FALSE)
app$wait_for_idle(timeout = 60000)
app$set_inputs(vp_market_segment_choice = "__all__", wait_ = FALSE)
app$wait_for_idle(timeout = 60000)
app$set_inputs(vp_commodity_name_choice = "Austrian winter peas", wait_ = FALSE)
app$wait_for_idle(timeout = 60000)
app$set_inputs(commodity_choice = "All", wait_ = FALSE)
app$wait_for_idle(timeout = 60000)

awd_country_choices <- get_select_choices("country_choice")
awd_country_choices_include_taiwan <- "Taiwan" %in% awd_country_choices
awd_country_choices_exclude_canada <- !("Canada" %in% awd_country_choices)
awd_country_choices_exclude_mexico <- !("Mexico" %in% awd_country_choices)
awd_country_choices_exclude_aruba <- !("Aruba" %in% awd_country_choices)

historical_tab_available <- tab_choice_available("Historical Trend")
if (isTRUE(historical_tab_available)) {
  app$set_inputs(main_tabs_panel = "Historical Trend", wait_ = FALSE)
  app$wait_for_idle(timeout = 60000)

  historical_year_filter_present <- dom_exists("year_filter")
  historical_year_filter_nonempty <- FALSE
  if (isTRUE(historical_year_filter_present)) {
    year_filter_values <- get_select_choices("year_filter")
    historical_year_filter_nonempty <- length(year_filter_values) > 0L
  }

  historical_month_tick_first <- get_plotly_first_tick_label("timeseries_plot")
  historical_month_first_is_jan <- identical(tolower(historical_month_tick_first), "jan")
  historical_current_trace_count <- get_plotly_trace_prefix_count("timeseries_plot", "Current (MY ")
  historical_x_axis_title <- get_plotly_axis_title("timeseries_plot", axis = "x")
  historical_x_axis_is_month <- identical(tolower(historical_x_axis_title), "month")
}

pace_tab_available <- tab_choice_available("Pace Analysis Tool")
if (isTRUE(pace_tab_available)) {
  app$set_inputs(main_tabs_panel = "Pace Analysis Tool", wait_ = FALSE)
  app$wait_for_idle(timeout = 60000)

  app$set_inputs(vp_trade_flow_choice = "import", wait_ = FALSE)
  app$wait_for_idle(timeout = 60000)
  app$set_inputs(
    vp_commodity_name_choice = "Artichokes",
    commodity_choice = "All",
    country_choice = "GRAND_TOTAL",
    wait_ = FALSE
  )
  app$wait_for_idle(timeout = 60000)

  pace_plot_tick_first <- get_plotly_first_tick_label("pace_plot")
  pace_has_current_trace <- get_plotly_trace_name_count("pace_plot", "Current Volume") > 0L
  pace_import_axis_title <- get_plotly_axis_title("pace_plot", axis = "x")
  pace_plot_title <- get_plotly_title("pace_plot")
  pace_import_title_contains_imports <- grepl("imports", tolower(pace_plot_title), fixed = TRUE)

  pace_before <- app$get_values(input = c("pace_target_single", "pace_projection_source"))
  pace_target_before <- pick_input(pace_before, "pace_target_single")

  app$set_inputs(pace_increase_10 = "click", wait_ = FALSE)
  app$wait_for_idle(timeout = 60000)
  pace_after_increase <- app$get_values(input = c("pace_target_single"))
  pace_target_after_increase <- pick_input(pace_after_increase, "pace_target_single")
  pace_target_changed_before_reset <- !identical(pace_target_before, pace_target_after_increase)

  app$set_inputs(pace_reset_target = "click", wait_ = FALSE)
  app$wait_for_idle(timeout = 60000)
  pace_after_reset <- app$get_values(input = c("pace_target_single", "pace_projection_source"))
  pace_reset_target_value <- pick_input(pace_after_reset, "pace_target_single")
  pace_target_reverted_after_reset <- identical(pace_target_before, pace_reset_target_value)
  pace_projection_source_after_reset <- pick_input(pace_after_reset, "pace_projection_source")
  pace_projection_source_is_historical <- identical(pace_projection_source_after_reset, "historical")
}

map_tab_available <- tab_choice_available("Map")
if (isTRUE(map_tab_available)) {
  app$set_inputs(main_tabs_panel = "Map", wait_ = FALSE)
  app$wait_for_idle(timeout = 60000)

  app$set_inputs(vp_trade_flow_choice = "export", wait_ = FALSE)
  app$wait_for_idle(timeout = 60000)
  app$set_inputs(vp_group_choice = "__all__", wait_ = FALSE)
  app$wait_for_idle(timeout = 60000)
  app$set_inputs(vp_subgroup_choice = "__all__", wait_ = FALSE)
  app$wait_for_idle(timeout = 60000)
  app$set_inputs(vp_market_segment_choice = "__all__", wait_ = FALSE)
  app$wait_for_idle(timeout = 60000)
  app$set_inputs(
    vp_commodity_name_choice = "Artichokes",
    commodity_choice = "All",
    wait_ = FALSE
  )
  app$wait_for_idle(timeout = 60000)

  if (isTRUE(dom_exists("country_choice"))) {
    app$set_inputs(country_choice = "GRAND_TOTAL", wait_ = FALSE)
  }
  app$wait_for_idle(timeout = 60000)

  map_export_title <- get_plotly_title("map_plot")
  map_fixture_title <- map_export_title
  map_fixture_title_contains_cy <- grepl(" CY ", map_fixture_title, fixed = TRUE)
  map_artichoke_year_control_label <- get_input_label_text("map_market_year")
  map_artichoke_year_control_label_is_calendar <- identical(map_artichoke_year_control_label, "Calendar Year:")
  map_export_title_contains_exports <- grepl("exports", tolower(map_export_title), fixed = TRUE)
  map_export_year_field_label <- get_plotly_axis_title("map_plot", axis = "x")
  map_export_share_field_label <- get_plotly_axis_title("map_plot", axis = "y")

  app$set_inputs(vp_trade_flow_choice = "import", wait_ = FALSE)
  app$wait_for_idle(timeout = 60000)

  map_import_title <- get_plotly_title("map_plot")
  map_import_title_contains_imports <- grepl("imports", tolower(map_import_title), fixed = TRUE)
  map_import_year_field_label <- get_plotly_axis_title("map_plot", axis = "x")
  map_import_share_field_label <- get_plotly_axis_title("map_plot", axis = "y")
}

heatmap_tab_available <- tab_choice_available("Heatmap")
if (isTRUE(heatmap_tab_available)) {
  app$set_inputs(main_tabs_panel = "Heatmap", wait_ = FALSE)
  app$wait_for_idle(timeout = 60000)

  app$set_inputs(vp_trade_flow_choice = "export", wait_ = FALSE)
  app$wait_for_idle(timeout = 60000)
  app$set_inputs(vp_group_choice = "__all__", wait_ = FALSE)
  app$wait_for_idle(timeout = 60000)
  app$set_inputs(vp_subgroup_choice = "__all__", wait_ = FALSE)
  app$wait_for_idle(timeout = 60000)
  app$set_inputs(vp_market_segment_choice = "__all__", wait_ = FALSE)
  app$wait_for_idle(timeout = 60000)
  app$set_inputs(
    vp_commodity_name_choice = "Artichokes",
    commodity_choice = "All",
    wait_ = FALSE
  )
  app$wait_for_idle(timeout = 60000)

  if (isTRUE(dom_exists("country_choice"))) {
    app$set_inputs(country_choice = "GRAND_TOTAL", wait_ = FALSE)
  }
  app$wait_for_idle(timeout = 60000)

  heatmap_plot_title <- get_plotly_title("heatmap_plot")
  heatmap_title_contains_heatmap <- grepl("heatmap", tolower(heatmap_plot_title), fixed = TRUE)
  heatmap_y_axis_title <- get_plotly_axis_title("heatmap_plot", axis = "y")
  heatmap_year_axis_is_calendar <- identical(heatmap_y_axis_title, "Calendar Year")

  heatmap_values <- app$get_values(output = c("data_summary"))
  heatmap_analysis_info <- as.character(heatmap_values$output$data_summary %||% "")
  heatmap_analysis_info_excludes_basis <- !grepl("basis|equivalent|vp_identity", tolower(heatmap_analysis_info))
}

data_tab_available <- tab_choice_available("Data")
if (isTRUE(data_tab_available)) {
  app$set_inputs(main_tabs_panel = "Data", wait_ = FALSE)
  app$wait_for_idle(timeout = 60000)

  data_table_columns <- get_data_table_columns("raw_data_table")

  required_csv_cols <- c(
    "Trade", "GeographicDesc", "Year", "MonthNumber", "MarketYear",
    "Group", "Subgroup", "MarketSegment", "CommodityName", "CommodityDetail",
    "UnitType", "UnitDesc", "Amount"
  )
  data_schema_has_csv_columns <- all(required_csv_cols %in% data_table_columns)
  data_schema_has_legacy_columns <- any(c("MY", "Month #", "Week", "Basis") %in% data_table_columns)

  metric_choices <- get_select_choices("metric_choice")
  if ("unit_value" %in% metric_choices) {
    app$set_inputs(metric_choice = "unit_value", wait_ = FALSE)
    app$wait_for_idle(timeout = 60000)
  }
  metric_values <- app$get_values(input = c("metric_choice"))
  data_publish_metric_choice <- pick_input(metric_values, "metric_choice")

  publish_dir <- file.path("VP Clone", "Output", "Custom Data")
  if (!dir.exists(publish_dir)) {
    dir.create(publish_dir, recursive = TRUE, showWarnings = FALSE)
  }
  before_publish_files <- list.files(publish_dir, pattern = "\\\\.csv$", full.names = TRUE)
  before_publish_mtime <- file.info(before_publish_files)$mtime
  before_publish_latest <- if (length(before_publish_mtime) > 0L && any(!is.na(before_publish_mtime))) {
    max(before_publish_mtime, na.rm = TRUE)
  } else {
    as.POSIXct("1970-01-01 00:00:00", tz = "UTC")
  }

  app$set_inputs(publish_filtered_data = "click", wait_ = FALSE)
  app$wait_for_idle(timeout = 60000)

  after_publish_files <- list.files(publish_dir, pattern = "\\\\.csv$", full.names = TRUE)
  new_publish_files <- setdiff(after_publish_files, before_publish_files)
  if (length(new_publish_files) == 0L && length(after_publish_files) > 0L) {
    after_publish_info <- file.info(after_publish_files)
    recent_mask <- !is.na(after_publish_info$mtime) & after_publish_info$mtime > before_publish_latest
    new_publish_files <- after_publish_files[recent_mask]
  }

  if (length(new_publish_files) > 0L) {
    new_publish_info <- file.info(new_publish_files)
    latest_idx <- if (nrow(new_publish_info) > 0L && any(!is.na(new_publish_info$mtime))) {
      which.max(new_publish_info$mtime)
    } else {
      length(new_publish_files)
    }
    data_publish_created_file <- new_publish_files[[latest_idx]]
    data_publish_created <- file.exists(data_publish_created_file)
  }

  if (isTRUE(data_publish_created)) {
    published_df <- tryCatch(
      read.csv(data_publish_created_file, stringsAsFactors = FALSE, check.names = FALSE, colClasses = "character"),
      error = function(...) data.frame()
    )

    data_publish_row_count <- nrow(published_df)
    required_publish_cols <- c("Group", "Subgroup", "MarketSegment", "Amount")
    data_publish_hierarchy_cols_present <- all(required_publish_cols %in% names(published_df))

    if (isTRUE(data_publish_hierarchy_cols_present) && nrow(published_df) > 0L) {
      hierarchy_values <- unlist(published_df[, c("Group", "Subgroup", "MarketSegment"), drop = FALSE], use.names = FALSE)
      hierarchy_values <- trimws(as.character(hierarchy_values))
      hierarchy_values <- hierarchy_values[!is.na(hierarchy_values)]

      data_publish_has_rollup_tokens <- any(grepl("^__vp_rollup_all_", hierarchy_values))
      data_publish_has_fallback_all_labels <- any(hierarchy_values %in% c("All Groups", "All Subgroups", "All Market Segments"))

      amount_values <- trimws(as.character(published_df$Amount %||% character(0)))
      amount_values <- amount_values[!is.na(amount_values) & nzchar(amount_values)]
      amount_values <- gsub(",", "", amount_values, fixed = TRUE)
      amount_values <- amount_values[!grepl("e\\\\+|e-", amount_values, ignore.case = TRUE)]
      decimal_places <- if (length(amount_values) > 0L) {
        ifelse(grepl("\\\\.", amount_values), nchar(sub("^[^.]*\\\\.", "", amount_values)), 0L)
      } else {
        integer(0)
      }
      data_publish_amount_has_gt2_decimals <- length(decimal_places) > 0L && any(decimal_places > 2L)
    }
  }

  stopifnot(
    isTRUE(data_publish_created),
    isTRUE(data_publish_hierarchy_cols_present),
    isTRUE(is.finite(data_publish_row_count) && data_publish_row_count > 0L),
    identical(data_publish_has_rollup_tokens, FALSE),
    identical(data_publish_has_fallback_all_labels, FALSE)
  )
  if (identical(data_publish_metric_choice, "unit_value")) {
    stopifnot(isTRUE(data_publish_amount_has_gt2_decimals))
  }
}

cct_tab_available <- tab_choice_available("Custom Comparison Tool")
if (isTRUE(cct_tab_available)) {
  app$set_inputs(main_tabs_panel = "Custom Comparison Tool", wait_ = FALSE)
  app$wait_for_idle(timeout = 60000)

  cct_quick_apply_title_has_side_top <-
    label_visible("Quick Apply Side and Top Bar Selection") ||
    text_visible("Quick Apply Side and Top Bar Selection")
  cct_apply_commodity_button_present <- dom_exists("custom_comp_apply_top_commodity")

  cct_vp_panel_commodity_controls_present <-
    dom_exists("vp_commodity_name_right_2up") &&
    dom_exists("vp_commodity_name_grid_3") &&
    dom_exists("vp_commodity_name_grid_4")

  cct_top_panel_commodity_choices <- get_select_choices("vp_commodity_name_right_2up")
  if (length(cct_top_panel_commodity_choices) >= 2) {
    candidate <- cct_top_panel_commodity_choices[[2]]
    app$set_inputs(vp_commodity_name_choice = candidate, wait_ = FALSE)
    app$wait_for_idle(timeout = 60000)
    app$set_inputs(custom_comp_apply_top_commodity = "click", wait_ = FALSE)
    app$wait_for_idle(timeout = 60000)

    cct_values_after <- app$get_values(input = c(
      "vp_commodity_name_right_2up",
      "vp_commodity_name_grid_3",
      "vp_commodity_name_grid_4"
    ))
    right_after <- pick_input(cct_values_after, "vp_commodity_name_right_2up")
    grid3_after <- pick_input(cct_values_after, "vp_commodity_name_grid_3")
    grid4_after <- pick_input(cct_values_after, "vp_commodity_name_grid_4")
    cct_top_panel_commodity_after_apply <- right_after
    cct_vp_panel_commodity_synced_after_apply <-
      identical(right_after, candidate) &&
      identical(grid3_after, candidate) &&
      identical(grid4_after, candidate)
  }
}

reset_type_is_all <- NA
reset_country_is_world <- NA

cat("VP_SHINYTEST_IDLE=TRUE\n")
cat("VP_DOM_DATA_SOURCE=", dom_exists("data_source_choice"), "\n", sep = "")
cat("VP_DOM_FREQUENCY=", dom_exists("data_frequency"), "\n", sep = "")
cat("VP_DOM_COMMODITY=", dom_exists("vp_commodity_name_choice"), "\n", sep = "")
cat("VP_DOM_MARKET_SEGMENT=", dom_exists("vp_market_segment_choice"), "\n", sep = "")
cat("VP_DOM_GROUP=", dom_exists("vp_group_choice"), "\n", sep = "")
cat("VP_DOM_SUBGROUP=", dom_exists("vp_subgroup_choice"), "\n", sep = "")
cat("VP_VISIBLE_DATA_SOURCE=", dom_visible("data_source_choice"), "\n", sep = "")
cat("VP_VISIBLE_FREQUENCY=", dom_visible("data_frequency"), "\n", sep = "")
cat("VP_VISIBLE_COMMODITY=", dom_visible("vp_commodity_name_choice"), "\n", sep = "")
cat("VP_VISIBLE_MARKET_SEGMENT=", dom_visible("vp_market_segment_choice"), "\n", sep = "")
cat("VP_VISIBLE_GROUP=", dom_visible("vp_group_choice"), "\n", sep = "")
cat("VP_VISIBLE_SUBGROUP=", dom_visible("vp_subgroup_choice"), "\n", sep = "")
cat("VP_LABEL_GROUP_VISIBLE=", label_visible("Group:"), "\n", sep = "")
cat("VP_LABEL_SUBGROUP_VISIBLE=", label_visible("Subgroup:"), "\n", sep = "")
cat("VP_LABEL_MARKET_SEGMENT_VISIBLE=", label_visible("Market Segment:"), "\n", sep = "")
cat("VP_LABEL_COMMODITY_VISIBLE=", label_visible("Commodity:"), "\n", sep = "")
cat("VP_LABEL_TYPE_VISIBLE=", (label_visible("Type") || label_visible("Type:")), "\n", sep = "")
cat("VP_LABEL_DATA_FREQUENCY_VISIBLE=", label_visible("Data Frequency:"), "\n", sep = "")
cat("VP_INPUT_DATA_SOURCE=", pick_input(values, "data_source_choice"), "\n", sep = "")
cat("VP_INPUT_FREQUENCY=", pick_input(values, "data_frequency"), "\n", sep = "")
cat("VP_INPUT_COMMODITY=", pick_input(values, "vp_commodity_name_choice"), "\n", sep = "")
cat("VP_INPUT_MARKET_SEGMENT=", pick_input(values, "vp_market_segment_choice"), "\n", sep = "")
cat("VP_INPUT_GROUP=", pick_input(values, "vp_group_choice"), "\n", sep = "")
cat("VP_INPUT_SUBGROUP=", pick_input(values, "vp_subgroup_choice"), "\n", sep = "")
cat("VP_INPUT_MAIN_COMMODITY=", pick_input(values, "commodity_choice"), "\n", sep = "")
cat("VP_INPUT_BASIS=", pick_input(values, "basis_choice"), "\n", sep = "")
cat("VP_OUTPUT_SUMMARY_TABLE_PRESENT=", !is.null(values$output$summary_table), "\n", sep = "")
cat("VP_ARTICHOKE_TOP_COMMODITY=", top_artichoke_value, "\n", sep = "")
cat("VP_ARTICHOKE_SIDEBAR_DETAIL=", sidebar_artichoke_value, "\n", sep = "")
cat("VP_ARTICHOKE_TRADE_FLOW=", artichoke_trade_flow, "\n", sep = "")
cat("VP_TOP_CHOICES_INCLUDE_GLOBE=", top_includes_globe, "\n", sep = "")
cat("VP_SIDEBAR_HAS_EXPECTED_ARTICHOKE_DETAILS=", sidebar_has_expected_details, "\n", sep = "")
cat("VP_SIDEBAR_VALUE_IS_DETAIL=", sidebar_is_detail_value, "\n", sep = "")
cat("VP_TOP_AND_SIDEBAR_DIFFER=", top_and_sidebar_differ, "\n", sep = "")
cat("VP_SIDEBAR_HAS_ALL_TYPE=", sidebar_has_all, "\n", sep = "")
cat("VP_SIDEBAR_DEFAULTS_TO_ALL=", sidebar_defaults_all, "\n", sep = "")
cat("VP_FIXTURE_AVAILABLE=", fixture_available, "\n", sep = "")
cat("VP_FIXTURE_TYPE_AVAILABLE=", fixture_type_available, "\n", sep = "")
cat("VP_FIXTURE_MONTH_AXIS_FIRST_LABEL=", fixture_tick_first, "\n", sep = "")
cat("VP_FIXTURE_MONTH_AXIS_FIRST_IS_JAN=", fixture_first_is_jan, "\n", sep = "")
cat("VP_UNIT_VALUE_OVERLAY_CONTROL_PRESENT=", unit_value_overlay_control_present, "\n", sep = "")
cat("VP_UNIT_VALUE_OVERLAY_TRACE_PRESENT=", unit_value_overlay_trace_present, "\n", sep = "")
cat("VP_HISTORICAL_TAB_AVAILABLE=", historical_tab_available, "\n", sep = "")
cat("VP_HISTORICAL_YEAR_FILTER_PRESENT=", historical_year_filter_present, "\n", sep = "")
cat("VP_HISTORICAL_YEAR_FILTER_NONEMPTY=", historical_year_filter_nonempty, "\n", sep = "")
cat("VP_HISTORICAL_MONTH_AXIS_FIRST_LABEL=", historical_month_tick_first, "\n", sep = "")
cat("VP_HISTORICAL_MONTH_AXIS_FIRST_IS_JAN=", historical_month_first_is_jan, "\n", sep = "")
cat("VP_HISTORICAL_CURRENT_TRACE_COUNT=", historical_current_trace_count, "\n", sep = "")
cat("VP_HISTORICAL_X_AXIS_TITLE=", historical_x_axis_title, "\n", sep = "")
cat("VP_HISTORICAL_X_AXIS_IS_MONTH=", historical_x_axis_is_month, "\n", sep = "")
cat("VP_PACE_TAB_AVAILABLE=", pace_tab_available, "\n", sep = "")
cat("VP_PACE_MONTH_AXIS_FIRST_LABEL=", pace_plot_tick_first, "\n", sep = "")
cat("VP_PACE_CURRENT_TRACE_PRESENT=", pace_has_current_trace, "\n", sep = "")
cat("VP_PACE_X_AXIS_TITLE=", pace_import_axis_title, "\n", sep = "")
cat("VP_PACE_PLOT_TITLE=", pace_plot_title, "\n", sep = "")
cat("VP_PACE_IMPORT_TITLE_CONTAINS_IMPORTS=", pace_import_title_contains_imports, "\n", sep = "")
cat("VP_PACE_TARGET_CHANGED_BEFORE_RESET=", pace_target_changed_before_reset, "\n", sep = "")
cat("VP_PACE_TARGET_REVERTED_AFTER_RESET=", pace_target_reverted_after_reset, "\n", sep = "")
cat("VP_PACE_TARGET_AFTER_RESET=", pace_reset_target_value, "\n", sep = "")
cat("VP_PACE_PROJECTION_SOURCE_AFTER_RESET=", pace_projection_source_after_reset, "\n", sep = "")
cat("VP_PACE_PROJECTION_SOURCE_IS_HISTORICAL=", pace_projection_source_is_historical, "\n", sep = "")
cat("VP_MAP_TAB_AVAILABLE=", map_tab_available, "\n", sep = "")
cat("VP_MAP_EXPORT_PLOT_TITLE=", map_export_title, "\n", sep = "")
cat("VP_MAP_EXPORT_TITLE_CONTAINS_EXPORTS=", map_export_title_contains_exports, "\n", sep = "")
cat("VP_MAP_IMPORT_PLOT_TITLE=", map_import_title, "\n", sep = "")
cat("VP_MAP_IMPORT_TITLE_CONTAINS_IMPORTS=", map_import_title_contains_imports, "\n", sep = "")
cat("VP_MAP_EXPORT_YEAR_FIELD_LABEL=", map_export_year_field_label, "\n", sep = "")
cat("VP_MAP_EXPORT_SHARE_FIELD_LABEL=", map_export_share_field_label, "\n", sep = "")
cat("VP_MAP_IMPORT_YEAR_FIELD_LABEL=", map_import_year_field_label, "\n", sep = "")
cat("VP_MAP_IMPORT_SHARE_FIELD_LABEL=", map_import_share_field_label, "\n", sep = "")
cat("VP_MAP_FIXTURE_PLOT_TITLE=", map_fixture_title, "\n", sep = "")
cat("VP_MAP_FIXTURE_TITLE_CONTAINS_CY=", map_fixture_title_contains_cy, "\n", sep = "")
cat("VP_MAP_ARTICHOKE_YEAR_CONTROL_LABEL=", map_artichoke_year_control_label, "\n", sep = "")
cat("VP_MAP_ARTICHOKE_YEAR_CONTROL_LABEL_IS_CALENDAR=", map_artichoke_year_control_label_is_calendar, "\n", sep = "")
cat("VP_HEATMAP_TAB_AVAILABLE=", heatmap_tab_available, "\n", sep = "")
cat("VP_HEATMAP_PLOT_TITLE=", heatmap_plot_title, "\n", sep = "")
cat("VP_HEATMAP_TITLE_CONTAINS_HEATMAP=", heatmap_title_contains_heatmap, "\n", sep = "")
cat("VP_HEATMAP_YEAR_AXIS_TITLE=", heatmap_y_axis_title, "\n", sep = "")
cat("VP_HEATMAP_YEAR_AXIS_IS_CALENDAR=", heatmap_year_axis_is_calendar, "\n", sep = "")
cat("VP_HEATMAP_ANALYSIS_INFO=", gsub("\n", " | ", heatmap_analysis_info), "\n", sep = "")
cat("VP_HEATMAP_ANALYSIS_INFO_EXCLUDES_BASIS=", heatmap_analysis_info_excludes_basis, "\n", sep = "")
cat("VP_DATA_TAB_AVAILABLE=", data_tab_available, "\n", sep = "")
cat("VP_DATA_SCHEMA_HAS_CSV_COLUMNS=", data_schema_has_csv_columns, "\n", sep = "")
cat("VP_DATA_SCHEMA_HAS_LEGACY_COLUMNS=", data_schema_has_legacy_columns, "\n", sep = "")
cat("VP_DATA_TABLE_COLUMNS=", paste(data_table_columns, collapse = "|"), "\n", sep = "")
cat("VP_DATA_PUBLISH_METRIC_CHOICE=", data_publish_metric_choice, "\n", sep = "")
cat("VP_DATA_PUBLISH_CREATED=", data_publish_created, "\n", sep = "")
cat("VP_DATA_PUBLISH_CREATED_FILE=", data_publish_created_file, "\n", sep = "")
cat("VP_DATA_PUBLISH_ROW_COUNT=", data_publish_row_count, "\n", sep = "")
cat("VP_DATA_PUBLISH_HIERARCHY_COLS_PRESENT=", data_publish_hierarchy_cols_present, "\n", sep = "")
cat("VP_DATA_PUBLISH_HAS_ROLLUP_TOKENS=", data_publish_has_rollup_tokens, "\n", sep = "")
cat("VP_DATA_PUBLISH_HAS_FALLBACK_ALL_LABELS=", data_publish_has_fallback_all_labels, "\n", sep = "")
cat("VP_DATA_PUBLISH_AMOUNT_HAS_GT2_DECIMALS=", data_publish_amount_has_gt2_decimals, "\n", sep = "")
cat("VP_CCT_TAB_AVAILABLE=", cct_tab_available, "\n", sep = "")
cat("VP_CCT_QUICK_APPLY_TITLE_HAS_SIDE_TOP=", cct_quick_apply_title_has_side_top, "\n", sep = "")
cat("VP_CCT_APPLY_COMMODITY_BUTTON_PRESENT=", cct_apply_commodity_button_present, "\n", sep = "")
cat("VP_CCT_VP_PANEL_COMMODITY_CONTROLS_PRESENT=", cct_vp_panel_commodity_controls_present, "\n", sep = "")
cat("VP_CCT_VP_PANEL_COMMODITY_SYNCED_AFTER_APPLY=", cct_vp_panel_commodity_synced_after_apply, "\n", sep = "")
cat("VP_CCT_TOP_PANEL_COMMODITY_AFTER_APPLY=", cct_top_panel_commodity_after_apply, "\n", sep = "")
cat("VP_AWD_COUNTRY_CHOICES_INCLUDE_TAIWAN=", awd_country_choices_include_taiwan, "\n", sep = "")
cat("VP_AWD_COUNTRY_CHOICES_EXCLUDE_CANADA=", awd_country_choices_exclude_canada, "\n", sep = "")
cat("VP_AWD_COUNTRY_CHOICES_EXCLUDE_MEXICO=", awd_country_choices_exclude_mexico, "\n", sep = "")
cat("VP_AWD_COUNTRY_CHOICES_EXCLUDE_ARUBA=", awd_country_choices_exclude_aruba, "\n", sep = "")
cat("VP_RESET_TYPE_CHOICE=", reset_type_choice, "\n", sep = "")
cat("VP_RESET_COUNTRY_CHOICE=", reset_country_choice, "\n", sep = "")
cat("VP_RESET_TYPE_TO_ALL=", reset_type_is_all, "\n", sep = "")
cat("VP_RESET_COUNTRY_TO_WORLD=", reset_country_is_world, "\n", sep = "")
cat("VP_SHARE_CONTRACT_CONTEXT=", share_contract$context, "\n", sep = "")
cat("VP_SHARE_CONTRACT_ALL=", sprintf("%.8f", share_contract$share_all), "\n", sep = "")
cat("VP_SHARE_CONTRACT_DETAIL=", sprintf("%.8f", share_contract$share_detail), "\n", sep = "")
cat("VP_AUSTRIAN_WINTER_PEAS_EXPORT_WORLD_JULY_FIRST=TRUE\n")
