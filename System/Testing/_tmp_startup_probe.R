library(shinytest2)
`%||%` <- function(x, y) if (is.null(x) || length(x) == 0L) y else x
app <- AppDriver$new(app_dir = file.path('VP Clone'), name = 'vp_startup_probe', load_timeout = 120000, timeout = 120000)
on.exit(try(app$stop(), silent = TRUE), add = TRUE)
idle_ok <- TRUE
idle_msg <- ''
tryCatch({ app$wait_for_idle(timeout = 60000) }, error = function(e) { idle_ok <<- FALSE; idle_msg <<- conditionMessage(e) })
dom_exists <- function(id) {
  script <- sprintf("(function(){ var id='%s'; var docs=[document]; for (var i=0;i<window.frames.length;i++){ try{ if(window.frames[i].document) docs.push(window.frames[i].document);}catch(e){} } for (var j=0;j<docs.length;j++){ try{ if(docs[j].getElementById(id)!==null) return true; } catch(e){} } return false; })();", id)
  out <- app$get_js(script)
  if (identical(out, TRUE)) return(TRUE)
  tolower(trimws(as.character(out %||% ''))) == 'true'
}
vals <- app$get_values(input = c('data_source_choice','country_choice','vp_group_choice','vp_subgroup_choice','vp_market_segment_choice','main_tabs_panel'))
cat('PROBE_IDLE_OK=', idle_ok, '\n', sep='')
if (!idle_ok) cat('PROBE_IDLE_MSG=', gsub('\n',' | ', idle_msg), '\n', sep='')
cat('PROBE_DATA_SOURCE=', as.character(vals$input[['data_source_choice']] %||% ''), '\n', sep='')
cat('PROBE_MAIN_TAB=', as.character(vals$input[['main_tabs_panel']] %||% ''), '\n', sep='')
cat('PROBE_DOM_COUNTRY=', dom_exists('country_choice'), '\n', sep='')
cat('PROBE_DOM_VP_GROUP=', dom_exists('vp_group_choice'), '\n', sep='')
cat('PROBE_DOM_VP_SUBGROUP=', dom_exists('vp_subgroup_choice'), '\n', sep='')
cat('PROBE_DOM_VP_SEGMENT=', dom_exists('vp_market_segment_choice'), '\n', sep='')
