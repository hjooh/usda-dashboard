library(shinytest2)
`%||%` <- function(x, y) if (is.null(x) || length(x) == 0L) y else x
app <- AppDriver$new(app_dir = file.path('VP Clone'), name = 'vp_type_transition_probe', load_timeout = 120000, timeout = 120000)
on.exit(try(app$stop(), silent = TRUE), add = TRUE)
wait_soft <- function(tag, timeout=10000) {
  ok <- TRUE; msg <- ''
  tryCatch(app$wait_for_idle(timeout = timeout), error = function(e){ ok <<- FALSE; msg <<- conditionMessage(e) })
  cat('SOFT_WAIT_', tag, '=', ok, '|', gsub('\n',' ', msg), '\n', sep='')
}
get_choices <- function(id){
  script <- sprintf("(function(){ var id='%s'; var docs=[document]; for (var i=0;i<window.frames.length;i++){ try{ if(window.frames[i].document) docs.push(window.frames[i].document);}catch(e){} } for (var j=0;j<docs.length;j++){ try{ var el=docs[j].getElementById(id); if(!el) continue; if (el.selectize && el.selectize.options){ var vals=Object.keys(el.selectize.options).map(function(x){return (x||'').trim();}).filter(function(x){return x.length>0;}); return vals.join('|||'); } if (el.options){ var out=[]; for (var k=0;k<el.options.length;k++){ out.push((el.options[k].value||'').trim()); } return out.join('|||'); } }catch(e){} } return ''; })();", id)
  out <- as.character(app$get_js(script) %||% '')
  if (!nzchar(out)) return(character(0))
  vals <- strsplit(out, '\\|\\|\\|', fixed = FALSE)[[1L]]
  vals <- trimws(vals)
  vals[nzchar(vals)]
}
print_state <- function(tag){
  vals <- app$get_values(input=c('vp_trade_flow_choice','vp_group_choice','vp_subgroup_choice','vp_market_segment_choice','vp_commodity_name_choice','commodity_choice'))
  type_choices <- get_choices('commodity_choice')
  cat('STATE_', tag, '|flow=', as.character(vals$input[['vp_trade_flow_choice']] %||% ''),
      '|group=', as.character(vals$input[['vp_group_choice']] %||% ''),
      '|subgroup=', as.character(vals$input[['vp_subgroup_choice']] %||% ''),
      '|segment=', as.character(vals$input[['vp_market_segment_choice']] %||% ''),
      '|vpname=', as.character(vals$input[['vp_commodity_name_choice']] %||% ''),
      '|type=', as.character(vals$input[['commodity_choice']] %||% ''),
      '|typeN=', length(type_choices),
      '|typeVals=', paste(type_choices, collapse='|'),
      '\n', sep='')
}
wait_soft('startup', 60000)
print_state('startup')
app$set_inputs(vp_trade_flow_choice='export', wait_=FALSE)
wait_soft('after_trade')
print_state('after_trade')
app$set_inputs(vp_group_choice='__all__', wait_=FALSE)
wait_soft('after_group')
print_state('after_group')
app$set_inputs(vp_subgroup_choice='__all__', wait_=FALSE)
wait_soft('after_subgroup')
print_state('after_subgroup')
app$set_inputs(vp_market_segment_choice='Dried', wait_=FALSE)
wait_soft('after_segment_1')
print_state('after_segment_1')
wait_soft('after_segment_2')
print_state('after_segment_2')
wait_soft('after_segment_3')
print_state('after_segment_3')
