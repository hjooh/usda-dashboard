rds_path <- file.path('VP Clone','System','Processed Data','vp_trade_monthly_pre.rds')
d <- readRDS(rds_path)
if ('vp_is_rollup' %in% names(d)) {
  mask <- !is.na(d$vp_is_rollup) & as.logical(d$vp_is_rollup)
  d <- d[!mask, , drop = FALSE]
}
for (col in c('Group','Subgroup','MarketSegment')) {
  x <- as.character(d[[col]])
  cat('COL=', col, '|N=', length(x), '\n', sep='')
  cat('BLANK_OR_NA=', sum(is.na(x) | trimws(x)==''), '\n', sep='')
  cat('TRIM_CHANGED=', sum(!is.na(x) & nzchar(x) & trimws(x) != x), '\n', sep='')
}
ms <- as.character(d$MarketSegment)
ms_trim <- trimws(ms)
idx_dried <- which(tolower(ms_trim) == 'dried')
cat('DRIED_ROWS_TRIM=', length(idx_dried), '\n', sep='')
if (length(idx_dried) > 0L) {
  raw_vals <- sort(unique(ms[idx_dried]))
  cat('DRIED_RAW_VALUES=', paste(raw_vals, collapse='|'), '\n', sep='')
  cat('DRIED_GROUPS=', length(unique(as.character(d$Group[idx_dried]))), '\n', sep='')
  cat('DRIED_SUBGROUPS=', length(unique(as.character(d$Subgroup[idx_dried]))), '\n', sep='')
}
exact_dried <- sum(ms == 'Dried', na.rm=TRUE)
cat('DRIED_ROWS_EXACT=', exact_dried, '\n', sep='')
