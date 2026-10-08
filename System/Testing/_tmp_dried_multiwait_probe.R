library(shinytest2)
app <- AppDriver$new(app_dir = file.path('VP Clone'), name = 'vp_dried_multiwait_probe', load_timeout = 120000, timeout = 120000)
on.exit(try(app$stop(), silent = TRUE), add = TRUE)
wait_tag <- function(tag, timeout=60000) {
  ok <- TRUE; msg <- ''
  t0 <- Sys.time()
  tryCatch(app$wait_for_idle(timeout=timeout), error=function(e){ok<<-FALSE; msg<<-conditionMessage(e)})
  dt <- as.numeric(difftime(Sys.time(), t0, units='secs'))
  cat('MW_', tag, '=', ok, '|', sprintf('%.2f', dt), '|', gsub('\n',' ', msg), '\n', sep='')
}
wait_tag('startup')
app$set_inputs(vp_trade_flow_choice='export', wait_=FALSE); wait_tag('after_trade', 120000)
app$set_inputs(vp_group_choice='__all__', wait_=FALSE); wait_tag('after_group', 120000)
app$set_inputs(vp_subgroup_choice='__all__', wait_=FALSE); wait_tag('after_subgroup', 120000)
app$set_inputs(vp_market_segment_choice='Dried', wait_=FALSE)
wait_tag('after_segment_1', 60000)
wait_tag('after_segment_2', 60000)
wait_tag('after_segment_3', 60000)
