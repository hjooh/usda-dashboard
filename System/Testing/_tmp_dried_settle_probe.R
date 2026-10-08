library(shinytest2)
`%||%` <- function(x, y) if (is.null(x) || length(x) == 0L) y else x
app <- AppDriver$new(app_dir = file.path('VP Clone'), name = 'vp_dried_probe', load_timeout = 120000, timeout = 120000)
on.exit(try(app$stop(), silent = TRUE), add = TRUE)
probe_wait <- function(tag, timeout = 120000) {
  ok <- TRUE
  msg <- ''
  t0 <- Sys.time()
  tryCatch(app$wait_for_idle(timeout = timeout), error = function(e) { ok <<- FALSE; msg <<- conditionMessage(e) })
  dt <- as.numeric(difftime(Sys.time(), t0, units='secs'))
  cat('DRIED_WAIT_', tag, '=', ok, '|', sprintf('%.2f', dt), '|', gsub('\n',' ', msg), '\n', sep='')
  ok
}
get_select_choices <- function(input_id) {
  script <- sprintf("(function(){ var id='%s'; var docs=[document]; for (var i=0;i<window.frames.length;i++){ try{ if(window.frames[i].document) docs.push(window.frames[i].document);}catch(e){} } for (var j=0;j<docs.length;j++){ try{ var el=docs[j].getElementById(id); if(!el) continue; if (el.selectize && el.selectize.options) { var vals=Object.keys(el.selectize.options).map(function(x){ return (x || '').trim(); }).filter(function(x){ return x.length>0; }); return vals.join('|||'); } if (el.options) { var out=[]; for (var k=0;k<el.options.length;k++){ out.push((el.options[k].value || '').trim()); } return out.join('|||'); } }catch(e){} } return ''; })();", input_id)
  out <- as.character(app$get_js(script) %||% '')
  if (!nzchar(out)) return(character(0))
  vals <- strsplit(out, '\\|\\|\\|', fixed = FALSE)[[1L]]
  vals <- trimws(vals)
  vals[nzchar(vals)]
}
probe_wait('startup', 60000)
app$set_inputs(vp_trade_flow_choice='export', wait_=FALSE)
probe_wait('after_trade')
app$set_inputs(vp_group_choice='__all__', wait_=FALSE)
probe_wait('after_group')
app$set_inputs(vp_subgroup_choice='__all__', wait_=FALSE)
probe_wait('after_subgroup')
app$set_inputs(vp_market_segment_choice='Dried', wait_=FALSE)
ok_after_segment <- probe_wait('after_segment_dried')
vals <- app$get_values(input=c('vp_group_choice','vp_subgroup_choice','vp_market_segment_choice','vp_commodity_name_choice','commodity_choice','country_choice'))
vp_name_choices <- get_select_choices('vp_commodity_name_choice')
type_choices <- get_select_choices('commodity_choice')
country_choices <- get_select_choices('country_choice')
cat('DRIED_INPUT_GROUP=', as.character(vals$input[['vp_group_choice']] %||% ''), '\n', sep='')
cat('DRIED_INPUT_SUBGROUP=', as.character(vals$input[['vp_subgroup_choice']] %||% ''), '\n', sep='')
cat('DRIED_INPUT_SEGMENT=', as.character(vals$input[['vp_market_segment_choice']] %||% ''), '\n', sep='')
cat('DRIED_INPUT_VP_COMMODITY=', as.character(vals$input[['vp_commodity_name_choice']] %||% ''), '\n', sep='')
cat('DRIED_INPUT_TYPE=', as.character(vals$input[['commodity_choice']] %||% ''), '\n', sep='')
cat('DRIED_VP_COMMODITY_CHOICES=', length(vp_name_choices), '\n', sep='')
cat('DRIED_TYPE_CHOICES=', length(type_choices), '\n', sep='')
cat('DRIED_COUNTRY_CHOICES=', length(country_choices), '\n', sep='')
if (!ok_after_segment) quit(status = 2)
