d <- readRDS(file.path('VP Clone','System','Processed Data','vp_trade_monthly_pre.rds'))
if ('vp_is_rollup' %in% names(d)) d <- d[!( !is.na(d$vp_is_rollup) & as.logical(d$vp_is_rollup) ), , drop=FALSE]
m <- d$Trade=='export' & d$MarketSegment=='Dried' & d$CommodityName=='Austrian winter peas'
cat('AWD_Dried_export_rows=', sum(m, na.rm=TRUE), '\n', sep='')
if (sum(m, na.rm=TRUE) > 0) {
  if ('CommodityDetail' %in% names(d)) {
    vals <- sort(unique(as.character(d$CommodityDetail[m])))
    vals <- vals[!is.na(vals) & nzchar(vals)]
    cat('AWD_Dried_CommodityDetail_count=', length(vals), '\n', sep='')
    cat('AWD_Dried_CommodityDetail_values=', paste(vals, collapse='|'), '\n', sep='')
  }
  vals2 <- sort(unique(as.character(d$commodity[m])))
  vals2 <- vals2[!is.na(vals2) & nzchar(vals2)]
  cat('AWD_Dried_commodity_count=', length(vals2), '\n', sep='')
  cat('AWD_Dried_commodity_values=', paste(vals2, collapse='|'), '\n', sep='')
}
