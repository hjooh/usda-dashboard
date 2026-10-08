d <- readRDS(file.path('VP Clone','System','Processed Data','vp_trade_monthly_pre.rds'))
if ('vp_is_rollup' %in% names(d)) {
  d <- d[!( !is.na(d$vp_is_rollup) & as.logical(d$vp_is_rollup) ), , drop=FALSE]
}
ms <- as.character(d$MarketSegment)
mask <- !is.na(ms) & ms == 'Dried'
tr <- as.character(d$Trade)
cat('TOTAL_Dried=', sum(mask), '\n', sep='')
cat('EXPORT_Dried=', sum(mask & tr=='export'), '\n', sep='')
cat('IMPORT_Dried=', sum(mask & tr=='import'), '\n', sep='')
cat('COMMODITY_NAMES_EXPORT=', length(unique(as.character(d$CommodityName[mask & tr=='export']))), '\n', sep='')
