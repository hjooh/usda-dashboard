library(shinytest2)
app <- AppDriver$new(app_dir = file.path('VP Clone'), name = 'vp_idle_probe', load_timeout = 120000, timeout = 120000)
on.exit(try(app$stop(), silent = TRUE), add = TRUE)
probe_wait <- function(tag) {
  ok <- TRUE
  msg <- ''
  t0 <- Sys.time()
  tryCatch(app$wait_for_idle(timeout = 60000), error = function(e) { ok <<- FALSE; msg <<- conditionMessage(e) })
  dt <- as.numeric(difftime(Sys.time(), t0, units='secs'))
  cat('IDLE_PROBE_', tag, '=', ok, '|', sprintf('%.2f', dt), '|', gsub('\n',' ', msg), '\n', sep='')
}
probe_wait('startup')
app$set_inputs(vp_trade_flow_choice='import', wait_ = FALSE)
probe_wait('after_trade')
app$set_inputs(vp_group_choice='__all__', wait_ = FALSE)
probe_wait('after_group')
app$set_inputs(vp_subgroup_choice='__all__', wait_ = FALSE)
probe_wait('after_subgroup')
app$set_inputs(vp_market_segment_choice='__all__', wait_ = FALSE)
probe_wait('after_segment')
