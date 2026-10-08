source("Programs/vp_data_utils.R")
paths <- vp_paths(normalizePath("."))
obj <- readRDS(paths$artifact)
d <- if (is.data.frame(obj)) obj else obj$data

as_clean <- function(x) trimws(as.character(x))
d$Trade <- tolower(as_clean(d$Trade))
d$CommodityName <- as_clean(d$CommodityName)
d$calendar_signature <- as_clean(d$calendar_signature)

d <- d[!is.na(d$calendar_signature) & nzchar(d$calendar_signature) & !is.na(d$CommodityName) & nzchar(d$CommodityName), ]
d <- d[d$Trade == "export", ]

agg <- aggregate(list(rows = d$calendar_signature), list(CommodityName = d$CommodityName, signature = d$calendar_signature), length)
ord <- agg[order(agg$CommodityName, -agg$rows), ]
top <- ord[!duplicated(ord$CommodityName), ]

sig_counts <- sort(table(top$signature), decreasing = TRUE)
cat("TOP_SIGNATURE_COUNTS\n")
print(sig_counts)

cat("TOP_COMMODITY_SIGNATURES\n")
print(utils::head(top[order(top$signature, -top$rows), c("CommodityName", "signature", "rows")], 120))

# Keep two deterministic candidates for matrix: one calendar-year and one offset signature
calendar_candidate <- top[top$signature == "1-2-3-4-5-6-7-8-9-10-11-12", c("CommodityName", "signature", "rows")]
offset_candidate <- top[top$signature == "10-11-12-1-2-3-4-5-6-7-8-9", c("CommodityName", "signature", "rows")]

cat("CANDIDATE_CALENDAR\n")
print(utils::head(calendar_candidate[order(-calendar_candidate$rows), ], 15))
cat("CANDIDATE_OFFSET\n")
print(utils::head(offset_candidate[order(-offset_candidate$rows), ], 15))
