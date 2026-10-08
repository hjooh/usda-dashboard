library(shinytest2)
`%||%` <- function(x, y) if (is.null(x) || length(x) == 0L) y else x
app <- AppDriver$new(app_dir = file.path('VP Clone'), name = 'vp_dried_state_loop', load_timeout = 120000, timeout = 120000)
on.exit(try(app$stop(), silent = TRUE), add = TRUE)
wait_soft <- function(timeout=5000){
  ok <- TRUE; msg <- ''
  tryCatch(app$wait_for_idle(timeout = timeout), error = function(e){ok <<- FALSE; msg <<- conditionMessage(e)})
  list(ok=ok,msg=msg)
}
get_state <- function(){
  vals <- app$get_values(input=c('vp_group_choice','vp_subgroup_choice','vp_market_segment_choice','vp_commodity_name_choice','commodity_choice','country_choice'))
  c(
    group=as.character(vals$input[['vp_group_choice']] %||% ''),
    subgroup=as.character(vals$input[['vp_subgroup_choice']] %||% ''),
    segment=as.character(vals$input[['vp_market_segment_choice']] %||% ''),
    vpname=as.character(vals$input[['vp_commodity_name_choice']] %||% ''),
    type=as.character(vals$input[['commodity_choice']] %||% ''),
    country=as.character(vals$input[['country_choice']] %||% '')
  )
}
ignore <- wait_soft(60000)
app$set_inputs(vp_trade_flow_choice='export', wait_=FALSE); ignore <- wait_soft(120000)
app$set_inputs(vp_group_choice='__all__', wait_=FALSE); ignore <- wait_soft(120000)
app$set_inputs(vp_subgroup_choice='__all__', wait_=FALSE); ignore <- wait_soft(120000)
app$set_inputs(vp_market_segment_choice='Dried', wait_=FALSE)
for (i in 1:12) {
  res <- wait_soft(7000)
  s <- get_state()
  cat('LOOP=', i, '|ok=', res$ok, '|segment=', s[['segment']], '|vpname=', s[['vpname']], '|type=', s[['type']], '|country=', s[['country']], '\n', sep='')
}
