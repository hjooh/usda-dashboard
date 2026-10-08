library(data.table)

args <- commandArgs(trailingOnly = TRUE)
out_dir <- normalizePath(args[[1L]], winslash='/', mustWork=TRUE)
repo <- normalizePath('.', winslash='/', mustWork=TRUE)
fruit <- file.path(repo, 'Input', 'fruit-trade-data.csv')
veg <- file.path(repo, 'Input', 'veg-trade-data.csv')

required <- c('Trade','GeographicDesc','Year','MarketYear','Group','Subgroup','MarketSegment','CommodityName','CommodityDetail','UnitType','UnitDesc','Amount')

read_headers <- function(path) names(fread(path, nrows = 0, showProgress = FALSE))
headers_fruit <- read_headers(fruit)
headers_veg <- read_headers(veg)

month_col <- if ('MonthNum' %in% headers_fruit) 'MonthNum' else if ('MonthNumber' %in% headers_fruit) 'MonthNumber' else NA_character_
missing_required <- setdiff(required, headers_fruit)

select_cols <- unique(c(required, month_col))
dt <- fread(fruit, select = select_cols, showProgress = FALSE)
if (!('MonthNum' %in% names(dt)) && ('MonthNumber' %in% names(dt))) setnames(dt, 'MonthNumber', 'MonthNum')

clean_text <- function(x) {
  v <- trimws(as.character(x))
  v[is.na(v)] <- ''
  v
}

parse_market_year <- function(market_year) {
  value <- trimws(as.character(market_year))
  value[is.na(value) | !nzchar(value)] <- NA_character_
  parsed <- suppressWarnings(as.integer(value))

  slash_matches <- regexec('^([0-9]{4})\\s*/\\s*([0-9]{1,4})$', value)
  slash_parts <- regmatches(value, slash_matches)
  for (idx in seq_along(slash_parts)) {
    parts <- slash_parts[[idx]]
    if (length(parts) != 3L) next
    start_year <- suppressWarnings(as.integer(parts[[2]]))
    end_text <- parts[[3]]
    end_year <- suppressWarnings(as.integer(end_text))
    if (!is.finite(start_year) || !is.finite(end_year)) next
    if (nchar(end_text) < 4L) {
      end_year <- (start_year %/% 100L) * 100L + end_year
      if (end_year < start_year) end_year <- end_year + 100L
    }
    parsed[[idx]] <- end_year
  }
  as.integer(parsed)
}

for (col in c('Trade','GeographicDesc','Group','Subgroup','MarketSegment','CommodityName','CommodityDetail','UnitType','UnitDesc')) {
  dt[[col]] <- clean_text(dt[[col]])
}
dt[, Year := suppressWarnings(as.integer(Year))]
dt[, MonthNum := suppressWarnings(as.integer(MonthNum))]
dt[, MarketYearParsed := parse_market_year(MarketYear)]
dt[is.na(MarketYearParsed), MarketYearParsed := Year]
dt[MonthNum < 1L | MonthNum > 12L, MonthNum := NA_integer_]

dt[, commodity_key := paste(Trade, Group, Subgroup, MarketSegment, CommodityName, CommodityDetail, sep='\r')]

distinct_counts <- data.table(
  field = c('Trade','Group','Subgroup','MarketSegment','CommodityName','CommodityDetail','UnitType','UnitDesc'),
  distinct_n = c(
    uniqueN(dt$Trade), uniqueN(dt$Group), uniqueN(dt$Subgroup), uniqueN(dt$MarketSegment),
    uniqueN(dt$CommodityName), uniqueN(dt$CommodityDetail), uniqueN(dt$UnitType), uniqueN(dt$UnitDesc)
  )
)

month_rows <- unique(dt[
  !is.na(MarketYearParsed) & !is.na(Year) & !is.na(MonthNum),
  .(commodity_key, Trade, Group, Subgroup, MarketSegment, CommodityName, CommodityDetail, GeographicDesc, MarketYearParsed, Year, MonthNum)
])
month_rows[, country := fifelse(GeographicDesc == 'World', 'GRAND_TOTAL', GeographicDesc)]

key_rows <- unique(month_rows[, .(commodity_key, Trade, Group, Subgroup, MarketSegment, CommodityName, CommodityDetail)])
calendar_list <- vector('list', nrow(key_rows))

month_cycle <- function(start_month) {
  if (is.na(start_month) || start_month < 1L || start_month > 12L) start_month <- 1L
  c(seq.int(start_month, 12L), if (start_month > 1L) seq.int(1L, start_month - 1L) else integer(0L))
}

for (i in seq_len(nrow(key_rows))) {
  kr <- key_rows[i]
  kv <- kr$commodity_key[[1L]]
  all_key <- month_rows[commodity_key == kv]
  world_key <- all_key[country == 'GRAND_TOTAL']
  if (nrow(world_key) > 0L) {
    key_months <- world_key
    source_scope <- 'world'
  } else {
    key_months <- all_key
    source_scope <- 'all_countries_fallback'
  }

  year_counts <- key_months[, .(months = uniqueN(MonthNum)), by = MarketYearParsed]
  if (nrow(year_counts) == 0L) next

  complete_years <- year_counts[months == 12L, MarketYearParsed]
  if (length(complete_years) > 0L) {
    selected_year <- max(complete_years, na.rm = TRUE)
  } else {
    selected_year <- year_counts[order(-months, -MarketYearParsed)]$MarketYearParsed[[1L]]
  }

  selected <- key_months[MarketYearParsed == selected_year][order(Year, MonthNum)]
  observed_month_order <- unique(as.integer(selected$MonthNum))
  if (length(observed_month_order) == 0L) next

  if (length(observed_month_order) == 12L) {
    month_order <- observed_month_order
  } else {
    month_order <- month_cycle(observed_month_order[[1L]])
  }
  month_order <- month_order[seq_len(12L)]

  calendar_list[[i]] <- data.table(
    Trade = kr$Trade[[1L]],
    Group = kr$Group[[1L]],
    Subgroup = kr$Subgroup[[1L]],
    MarketSegment = kr$MarketSegment[[1L]],
    CommodityName = kr$CommodityName[[1L]],
    CommodityDetail = kr$CommodityDetail[[1L]],
    first_calendar_month = month_order[[1L]],
    calendar_source_scope = source_scope,
    calendar_source_months = length(observed_month_order),
    calendar_complete = length(complete_years) > 0L,
    calendar_signature = paste(month_order, collapse='-')
  )
}

cal <- rbindlist(calendar_list, fill = TRUE)
sig_summary <- if (nrow(cal) > 0L) cal[, .N, by = calendar_signature][order(-N)] else data.table(calendar_signature=character(), N=integer())
rep_candidates <- if (nrow(cal) > 0L) cal[, .N, by = .(calendar_signature, Trade, Group, Subgroup, MarketSegment, CommodityName, CommodityDetail, first_calendar_month, calendar_source_scope, calendar_source_months, calendar_complete)][order(calendar_signature, -N)] else data.table()
rep_selected <- if (nrow(rep_candidates) > 0L) rep_candidates[, .SD[1L], by = calendar_signature] else data.table()
if (nrow(rep_selected) > 2L) rep_selected <- rep_selected[order(-N)][1:2]

unit_desc_clean <- tolower(clean_text(dt$UnitDesc))
commodity_name_clean <- tolower(clean_text(dt$CommodityName))
commodity_detail_clean <- tolower(clean_text(dt$CommodityDetail))

dt[, volume_family := ifelse(grepl('gallon', unit_desc_clean), 'liquid', 'weight')]
vol_ctx <- dt[UnitType == 'Volume' & !is.na(MonthNum), .(
  has_weight = any(volume_family == 'weight'),
  has_liquid = any(volume_family == 'liquid')
), by = .(Trade, Group, Subgroup, MarketSegment, CommodityName, CommodityDetail, MarketYearParsed, MonthNum)]

mixed_volume_contexts <- vol_ctx[has_weight & has_liquid, .N]
juice_related_rows <- dt[grepl('juice', commodity_name_clean) | grepl('juice', commodity_detail_clean) | grepl('juice', unit_desc_clean), .N]

fwrite(data.table(dataset=c('fruit','veg'), column_count=c(length(headers_fruit), length(headers_veg))), file.path(out_dir, 'header_counts.csv'))
fwrite(data.table(column=required, present_in_fruit=required %in% headers_fruit), file.path(out_dir, 'required_columns_fruit.csv'))
fwrite(distinct_counts, file.path(out_dir, 'distinct_value_counts.csv'))
fwrite(sig_summary, file.path(out_dir, 'calendar_signature_summary.csv'))
fwrite(rep_selected, file.path(out_dir, 'calendar_signature_representatives.csv'))
fwrite(data.table(metric=c('mixed_volume_contexts','juice_related_rows'), value=c(mixed_volume_contexts, juice_related_rows)), file.path(out_dir, 'mixed_juice_summary.csv'))

summary_lines <- c(
  paste0('fruit_header_required_status=', ifelse(length(missing_required) == 0L, 'PASS', 'FAIL')),
  paste0('missing_required_columns=', if (length(missing_required) == 0L) '<none>' else paste(missing_required, collapse='|')),
  paste0('month_column=', ifelse(is.na(month_col), 'NONE', month_col)),
  paste0('distinct_calendar_signatures=', nrow(sig_summary)),
  paste0('top_calendar_signatures=', if (nrow(sig_summary) == 0L) '<none>' else paste(head(sig_summary$calendar_signature, 5L), collapse='|')),
  paste0('representative_signature_commodities=', if (nrow(rep_selected) == 0L) '<none>' else paste(rep_selected$CommodityDetail, collapse='|')),
  paste0('mixed_volume_contexts=', mixed_volume_contexts),
  paste0('juice_related_rows=', juice_related_rows),
  paste0('output_dir=', out_dir)
)
writeLines(summary_lines, file.path(out_dir, 'summary.txt'))
cat(paste(summary_lines, collapse='\n'))
