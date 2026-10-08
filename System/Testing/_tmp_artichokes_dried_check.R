d <- readRDS(file.path('VP Clone','System','Processed Data','vp_trade_monthly_pre.rds'))
if ('vp_is_rollup' %in% names(d)) d <- d[!( !is.na(d$vp_is_rollup) & as.logical(d$vp_is_rollup) ), , drop=FALSE]
m <- d$Trade=='export' & d$MarketSegment=='Dried'
cat('Dried_export_rows=', sum(m, na.rm=TRUE), '\n', sep='')
cat('Has_Artichokes=', any(as.character(d$CommodityName[m])=='Artichokes'), '\n', sep='')
cat('Has_Austrian_winter_peas=', any(as.character(d$CommodityName[m])=='Austrian winter peas'), '\n', sep='')
