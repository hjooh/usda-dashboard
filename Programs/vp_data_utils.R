vp_artifact_builder_version <- "vp_trade_artifact_2026_07_28_v6"
vp_artifact_builder_floor <- "vp_trade_artifact_2026_07_28_v6"
vp_all_type_label <- "All"
vp_all_excluding_juice_label <- "All - excluding juice"
vp_rollup_schema_version <- "vp_rollup_schema_2026_07_28_v1"
vp_rollup_group_token <- "__vp_rollup_all_group__"
vp_rollup_subgroup_token <- "__vp_rollup_all_subgroup__"
vp_rollup_market_segment_token <- "__vp_rollup_all_market_segment__"

vp_rollup_required_fields <- function() {
  c("vp_rollup_level", "vp_rollup_path", "vp_is_rollup", "vp_volume_family_mixed", "vp_mixed_source_replacement", "vp_rollup_schema_version")
}

`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0L) y else x
}

vp_first <- function(x, default = character(0)) {
  if (is.null(x) || length(x) == 0L || is.na(x[[1]])) default else x[[1]]
}

vp_normalize_path <- function(path) {
  normalizePath(path, winslash = "/", mustWork = FALSE)
}

vp_is_root <- function(path) {
  marker <- file.path(path, ".vp_clone_root")
  file.exists(marker) && any(readLines(marker, warn = FALSE) == "VP_CLONE_ROOT=TRUE")
}

vp_find_root <- function(start_dir = getwd()) {
  starts <- unique(c(vp_normalize_path(start_dir), vp_normalize_path(getwd())))
  candidates <- unique(unlist(lapply(starts, function(base_dir) {
    vapply(0:8, function(level) {
      vp_normalize_path(do.call(file.path, as.list(c(base_dir, rep("..", level)))))
    }, character(1))
  }), use.names = FALSE))

  for (candidate in candidates) {
    if (vp_is_root(candidate)) return(candidate)
  }
  stop("Could not locate FTN clone root marker (.vp_clone_root).", call. = FALSE)
}

vp_paths <- function(project_dir = vp_find_root()) {
  list(
    project_dir = project_dir,
    input_csv = file.path(project_dir, "Input", "fruit-trade-data.csv"),
    processed_dir = file.path(project_dir, "System", "Processed Data"),
    artifact = file.path(project_dir, "System", "Processed Data", "vp_trade_monthly_pre.rds"),
    metadata = file.path(project_dir, "System", "Processed Data", "vp_trade_metadata_pre.rds"),
    custom_types = file.path(project_dir, "System", "CustomTypes", "vp_custom_types.csv"),
    custom_countries = file.path(project_dir, "System", "CustomCountries", "vp_custom_countries.csv")
  )
}

vp_require_packages <- function(packages) {
  missing <- packages[!vapply(packages, requireNamespace, logical(1), quietly = TRUE)]
  if (length(missing) > 0L) {
    stop(sprintf("Missing required R packages: %s", paste(missing, collapse = ", ")), call. = FALSE)
  }
  invisible(TRUE)
}

vp_file_signature <- function(path) {
  if (!file.exists(path)) {
    return(list(path = vp_normalize_path(path), exists = FALSE, size = NA_real_, mtime = NA_character_))
  }
  info <- file.info(path)
  list(
    path = vp_normalize_path(path),
    exists = TRUE,
    size = unname(as.numeric(info$size)),
    mtime = format(as.POSIXct(info$mtime, tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  )
}

vp_signature_string <- function(signature) {
  paste(signature$path, signature$exists, signature$size, signature$mtime, sep = "|")
}

vp_required_columns <- function() {
  c("Trade", "GeographicDesc", "Year", "MarketYear", "Group", "Subgroup", "MarketSegment", "CommodityName", "CommodityDetail", "UnitType", "UnitDesc", "Amount")
}

vp_detect_month_column <- function(names) {
  if ("MonthNum" %in% names) return("MonthNum")
  if ("MonthNumber" %in% names) return("MonthNumber")
  NA_character_
}

vp_clean_text <- function(x, unspecified = "Unspecified") {
  value <- trimws(as.character(x %||% NA_character_))
  value[is.na(value) | !nzchar(value)] <- unspecified
  value
}

vp_slug <- function(x) {
  value <- tolower(vp_clean_text(x, unspecified = "unspecified"))
  value <- gsub("[^a-z0-9]+", "_", value)
  value <- gsub("(^_+|_+$)", "", value)
  value[!nzchar(value)] <- "unspecified"
  value
}

vp_build_commodity_key <- function(trade, group, subgroup, market_segment, commodity_name, commodity_detail) {
  paste(vp_slug(trade), vp_slug(group), vp_slug(subgroup), vp_slug(market_segment), vp_slug(commodity_name), vp_slug(commodity_detail), sep = "__")
}

vp_builder_version_rank <- function(version) {
  value <- trimws(as.character(version %||% ""))
  if (length(value) == 0L || !nzchar(value[[1L]])) return(NA_real_)
  value <- value[[1L]]

  match_groups <- regexec("([0-9]{4})_([0-9]{2})_([0-9]{2})_v([0-9]+)$", value)
  parts <- regmatches(value, match_groups)[[1L]]
  if (length(parts) != 5L) return(NA_real_)

  year <- suppressWarnings(as.integer(parts[[2L]]))
  month <- suppressWarnings(as.integer(parts[[3L]]))
  day <- suppressWarnings(as.integer(parts[[4L]]))
  patch <- suppressWarnings(as.integer(parts[[5L]]))
  if (!all(is.finite(c(year, month, day, patch)))) return(NA_real_)

  date_rank <- as.numeric(year) * 10000 + as.numeric(month) * 100 + as.numeric(day)
  date_rank * 1000 + as.numeric(patch)
}

vp_rollup_token_values <- function() {
  c(vp_rollup_group_token, vp_rollup_subgroup_token, vp_rollup_market_segment_token)
}

vp_assert_rollup_token_safety <- function(rows) {
  vp_require_packages("data.table")
  dt <- data.table::as.data.table(rows)
  token_values <- vp_rollup_token_values()
  token_columns <- intersect(c("Group", "Subgroup", "MarketSegment", "CommodityName", "CommodityDetail"), names(dt))

  if (length(token_columns) == 0L || nrow(dt) == 0L) {
    return(invisible(TRUE))
  }

  for (column_name in token_columns) {
    values <- trimws(as.character(dt[[column_name]] %||% character(0)))
    if (any(values %in% token_values, na.rm = TRUE)) {
      stop(
        sprintf(
          "VP rollup sentinel collision detected in source column %s. Rename source labels before build.",
          column_name
        ),
        call. = FALSE
      )
    }
  }

  invisible(TRUE)
}

vp_parse_market_year <- function(market_year) {
  value <- trimws(as.character(market_year %||% NA_character_))
  value[is.na(value) | !nzchar(value)] <- NA_character_
  parsed <- suppressWarnings(as.integer(value))

  slash_matches <- regexec("^([0-9]{4})\\s*/\\s*([0-9]{1,4})$", value)
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

vp_month_cycle <- function(start_month) {
  start_month <- suppressWarnings(as.integer(start_month))
  if (length(start_month) != 1L || is.na(start_month) || start_month < 1L || start_month > 12L) {
    start_month <- 1L
  }
  c(seq.int(start_month, 12L), if (start_month > 1L) seq.int(1L, start_month - 1L) else integer(0L))
}

vp_read_csv <- function(csv_path) {
  vp_require_packages("data.table")
  dt <- data.table::fread(csv_path, showProgress = FALSE)
  month_col <- vp_detect_month_column(names(dt))
  missing <- setdiff(vp_required_columns(), names(dt))
  if (is.na(month_col)) missing <- c(missing, "MonthNum_or_MonthNumber")
  if (length(missing) > 0L) {
    stop(sprintf("VP CSV missing required columns: %s", paste(missing, collapse = ", ")), call. = FALSE)
  }
  data.table::setnames(dt, month_col, "MonthNum")
  attr(dt, "month_column") <- month_col
  dt
}

vp_infer_month_calendars <- function(rows) {
  vp_require_packages("data.table")
  dt <- data.table::as.data.table(rows)
  key_cols <- c("commodity_key", "Trade", "Group", "Subgroup", "MarketSegment", "CommodityName", "CommodityDetail")
  unique_months <- unique(dt[
    !is.na(MarketYear) & !is.na(Year) & !is.na(MonthNum),
    c(key_cols, "country", "country_label", "MarketYear", "Year", "MonthNum"),
    with = FALSE
  ])
  calendar_list <- vector("list", 0L)
  keys <- unique(unique_months[, key_cols, with = FALSE])

  for (idx in seq_len(nrow(keys))) {
    key_row <- keys[idx]
    key_value <- key_row$commodity_key[[1]]
    all_key_months <- unique_months[commodity_key == key_value]
    world_key_months <- all_key_months[country == "GRAND_TOTAL"]
    if (nrow(world_key_months) > 0L) {
      key_months <- world_key_months
      source_scope <- "world"
    } else {
      key_months <- all_key_months
      source_scope <- "all_countries_fallback"
    }

    year_counts <- key_months[, .(
      months = data.table::uniqueN(MonthNum),
      first_calendar_year = min(Year, na.rm = TRUE),
      first_calendar_month = MonthNum[order(Year, MonthNum)][[1]]
    ), by = MarketYear]
    complete_years <- year_counts[months == 12L, MarketYear]
    if (length(complete_years) > 0L) {
      selected_year <- max(complete_years, na.rm = TRUE)
    } else {
      counts <- year_counts[order(-months, -MarketYear)]
      selected_year <- counts$MarketYear[[1]]
    }
    selected <- key_months[MarketYear == selected_year][order(Year, MonthNum)]
    observed_month_order <- unique(as.integer(selected$MonthNum))
    if (length(observed_month_order) == 12L) {
      month_order <- observed_month_order
    } else {
      month_order <- vp_month_cycle(observed_month_order[[1]] %||% 1L)
    }
    month_order <- month_order[seq_len(12L)]
    calendar <- data.table::data.table(
      commodity_key = key_value,
      analysis_month = seq_along(month_order),
      MonthNum = month_order,
      month_abbrev = month.abb[month_order],
      month_name = month.name[month_order],
      calendar_source_market_year = selected_year,
      calendar_source_scope = source_scope,
      calendar_source_months = length(observed_month_order),
      calendar_complete = length(complete_years) > 0L
    )
    for (column in setdiff(key_cols, "commodity_key")) {
      calendar[[column]] <- key_row[[column]][[1]]
    }
    calendar_list[[length(calendar_list) + 1L]] <- calendar
  }

  calendars <- data.table::rbindlist(calendar_list, fill = TRUE)
  calendars[, calendar_signature := paste(MonthNum, collapse = "-"), by = commodity_key]
  calendars[]
}

vp_normalize_source_rows <- function(dt) {
  vp_require_packages("data.table")
  rows <- data.table::copy(data.table::as.data.table(dt))
  rows[, Trade := data.table::fifelse(tolower(vp_clean_text(Trade)) == "import", "import", "export")]
  for (column in c("Group", "Subgroup", "MarketSegment", "CommodityName", "CommodityDetail", "UnitType", "UnitDesc", "GeographicDesc")) {
    rows[, (column) := vp_clean_text(get(column))]
  }
  rows[, country := data.table::fifelse(GeographicDesc == "World", "GRAND_TOTAL", GeographicDesc)]
  rows[, country_label := data.table::fifelse(country == "GRAND_TOTAL", "World", GeographicDesc)]
  rows[, Year := suppressWarnings(as.integer(Year))]
  rows[, MonthNum := suppressWarnings(as.integer(MonthNum))]
  rows[, MarketYear := vp_parse_market_year(MarketYear)]
  rows[is.na(MarketYear), MarketYear := Year]
  rows[, Amount := suppressWarnings(as.numeric(Amount))]
  rows[, commodity_key := vp_build_commodity_key(Trade, Group, Subgroup, MarketSegment, CommodityName, CommodityDetail)]
  rows[is.na(MonthNum) | MonthNum < 1L | MonthNum > 12L, MonthNum := NA_integer_]
  rows
}

vp_all_type_labels <- function() {
  c(vp_all_type_label, vp_all_excluding_juice_label)
}

vp_sum_amount <- function(amount) {
  amount_values <- suppressWarnings(as.numeric(amount))
  if (any(is.finite(amount_values))) sum(amount_values, na.rm = TRUE) else NA_real_
}

vp_pick_year <- function(year_values) {
  years <- suppressWarnings(as.integer(year_values))
  years <- years[!is.na(years)]
  if (length(years) == 0L) return(NA_integer_)
  as.integer(max(years))
}

vp_detail_match_key <- function(dt, key_cols) {
  if (nrow(dt) == 0L) return(character(0))
  do.call(paste, c(lapply(dt[, key_cols, with = FALSE], as.character), sep = "\r"))
}

vp_prepare_all_type_aggregation_rows <- function(detail_rows) {
  vp_require_packages("data.table")
  rows <- data.table::copy(data.table::as.data.table(detail_rows))
  if ("vp_mixed_source_replacement" %in% names(rows)) {
    rows[, vp_mixed_source_replacement := NULL]
  }
  if (nrow(rows) == 0L) {
    rows[, vp_mixed_source_replacement := logical(0)]
    return(rows)
  }

  context_cols <- c(
    "Trade", "GeographicDesc", "country", "country_label",
    "Year", "MonthNum", "MarketYear",
    "Group", "Subgroup", "MarketSegment", "CommodityName"
  )
  detail_key_cols <- c(context_cols, "CommodityDetail")

  volume_rows <- data.table::copy(rows[UnitType == "Volume"])
  if (nrow(volume_rows) == 0L) {
    rows[, `:=`(CommodityDetail = vp_all_type_label, vp_mixed_source_replacement = FALSE)]
    return(rows)
  }

  volume_rows[, volume_family := vp_volume_family(UnitDesc)]
  family_status <- volume_rows[, .(
    has_weight_volume = any(volume_family == "weight", na.rm = TRUE),
    has_liquid_volume = any(volume_family == "liquid", na.rm = TRUE)
  ), by = context_cols]
  family_status[, `:=`(
    vp_mixed_source_replacement = has_weight_volume & has_liquid_volume,
    aggregate_detail = data.table::fifelse(has_weight_volume & has_liquid_volume, vp_all_excluding_juice_label, vp_all_type_label)
  )]

  rows <- family_status[, c(context_cols, "vp_mixed_source_replacement", "aggregate_detail"), with = FALSE][rows, on = context_cols]
  rows[is.na(vp_mixed_source_replacement), `:=`(vp_mixed_source_replacement = FALSE, aggregate_detail = vp_all_type_label)]

  eligible_weight_keys <- unique(vp_detail_match_key(volume_rows[volume_family == "weight"], detail_key_cols))
  rows[, vp_detail_key := vp_detail_match_key(.SD, detail_key_cols), .SDcols = detail_key_cols]
  rows <- rows[!vp_mixed_source_replacement | vp_detail_key %in% eligible_weight_keys]
  rows[UnitType == "Volume", vp_volume_row_family := vp_volume_family(UnitDesc)]
  rows <- rows[!vp_mixed_source_replacement | UnitType != "Volume" | vp_volume_row_family == "weight"]
  rows[, CommodityDetail := aggregate_detail]
  rows[, c("aggregate_detail", "vp_detail_key", "vp_volume_row_family") := NULL]
  rows[]
}

vp_append_all_type_rows <- function(rows) {
  vp_require_packages("data.table")
  dt <- data.table::copy(data.table::as.data.table(rows))
  if (nrow(dt) == 0L) {
    return(dt)
  }

  vp_assert_rollup_token_safety(dt)

  detail_rows <- dt[!(CommodityDetail %in% vp_all_type_labels())]
  if (nrow(detail_rows) == 0L) {
    return(detail_rows)
  }

  additive_types <- c("Volume", "Value")
  synth_group_cols <- c(
    "Trade", "GeographicDesc", "country", "country_label",
    "Year", "MonthNum", "MarketYear",
    "Group", "Subgroup", "MarketSegment", "CommodityName",
    "CommodityDetail", "vp_mixed_source_replacement", "UnitType", "UnitDesc"
  )

  synthetic_source <- vp_prepare_all_type_aggregation_rows(detail_rows)
  synthetic_all <- synthetic_source[UnitType %in% additive_types, .(
    Amount = vp_sum_amount(Amount)
  ), by = synth_group_cols]

  native_rows <- detail_rows
  if (nrow(synthetic_all) > 0L) {
    native_rows <- data.table::rbindlist(list(native_rows, synthetic_all), use.names = TRUE, fill = TRUE)
  }
  native_rows[is.na(vp_mixed_source_replacement), vp_mixed_source_replacement := FALSE]

  native_rows[, `:=`(
    vp_rollup_level = "native",
    vp_rollup_path = "P0_native",
    vp_is_rollup = FALSE,
    vp_volume_family_mixed = FALSE,
    vp_rollup_schema_version = vp_rollup_schema_version
  )]

  make_rollup_rows <- function(source_rows, rollup_level, rollup_path, roll_group_all = FALSE, roll_subgroup_all = FALSE, roll_market_segment_all = FALSE) {
    roll_rows <- data.table::copy(source_rows)
    if (nrow(roll_rows) == 0L) {
      return(roll_rows)
    }

    if (isTRUE(roll_group_all)) roll_rows[, Group := vp_rollup_group_token]
    if (isTRUE(roll_subgroup_all)) roll_rows[, Subgroup := vp_rollup_subgroup_token]
    if (isTRUE(roll_market_segment_all)) roll_rows[, MarketSegment := vp_rollup_market_segment_token]

    roll_rows <- roll_rows[!(CommodityDetail %in% vp_all_type_labels())]
    if (nrow(roll_rows) == 0L) {
      return(roll_rows)
    }
    strict_all_source <- vp_prepare_all_type_aggregation_rows(roll_rows)
    roll_rows <- data.table::rbindlist(list(roll_rows, strict_all_source), use.names = TRUE, fill = TRUE)
    roll_rows[is.na(vp_mixed_source_replacement), vp_mixed_source_replacement := FALSE]

    rollup_key_cols <- c(
      "Trade", "GeographicDesc", "country", "country_label",
      "Year", "MonthNum", "MarketYear",
      "Group", "Subgroup", "MarketSegment", "CommodityName", "CommodityDetail"
    )
    amount_group_cols <- c(rollup_key_cols, "UnitType", "UnitDesc")

    result_chunks <- list()

    rollup_status <- roll_rows[, .(
      vp_mixed_source_replacement = any(as.logical(vp_mixed_source_replacement), na.rm = TRUE)
    ), by = rollup_key_cols]

    value_rows <- roll_rows[UnitType == "Value", {
      .(Amount = vp_sum_amount(Amount))
    }, by = amount_group_cols]
    if (nrow(value_rows) > 0L) {
      result_chunks[[length(result_chunks) + 1L]] <- value_rows
    }

    volume_rows <- roll_rows[UnitType == "Volume"]
    family_status <- data.table::data.table()
    if (nrow(volume_rows) > 0L) {
      volume_rows[, volume_family := vp_volume_family(UnitDesc)]
      family_status <- volume_rows[, .(
        vp_volume_family_mixed = data.table::uniqueN(volume_family[!is.na(volume_family) & nzchar(volume_family)]) > 1L
      ), by = rollup_key_cols]

      volume_clean <- volume_rows[family_status[vp_volume_family_mixed == FALSE], on = rollup_key_cols, nomatch = 0L]
      if (nrow(volume_clean) > 0L) {
        volume_agg <- volume_clean[, {
          .(Amount = vp_sum_amount(Amount))
        }, by = amount_group_cols]

        if (nrow(volume_agg) > 0L) {
          result_chunks[[length(result_chunks) + 1L]] <- volume_agg
        }
      }
    }

    if (length(result_chunks) == 0L) {
      return(data.table::data.table())
    }

    rollup_rows <- data.table::rbindlist(result_chunks, use.names = TRUE, fill = TRUE)
    if (nrow(family_status) > 0L) {
      rollup_rows <- family_status[rollup_rows, on = rollup_key_cols]
    }
    rollup_rows <- rollup_status[rollup_rows, on = rollup_key_cols]
    rollup_rows[is.na(vp_volume_family_mixed), vp_volume_family_mixed := FALSE]
    rollup_rows[is.na(vp_mixed_source_replacement), vp_mixed_source_replacement := FALSE]

    rollup_rows[, `:=`(
      vp_rollup_level = rollup_level,
      vp_rollup_path = rollup_path,
      vp_is_rollup = TRUE,
      vp_rollup_schema_version = vp_rollup_schema_version
    )]

    rollup_rows[]
  }

  rollup_segment_all <- make_rollup_rows(
    source_rows = native_rows,
    rollup_level = "segment_all",
    rollup_path = "P1_segment_all",
    roll_market_segment_all = TRUE
  )
  rollup_subgroup_all <- make_rollup_rows(
    source_rows = native_rows,
    rollup_level = "subgroup_all",
    rollup_path = "P2_subgroup_all",
    roll_subgroup_all = TRUE,
    roll_market_segment_all = TRUE
  )
  rollup_group_all <- make_rollup_rows(
    source_rows = native_rows,
    rollup_level = "group_all",
    rollup_path = "P3_group_all",
    roll_group_all = TRUE,
    roll_subgroup_all = TRUE,
    roll_market_segment_all = TRUE
  )

  all_rows <- data.table::rbindlist(
    list(native_rows, rollup_segment_all, rollup_subgroup_all, rollup_group_all),
    use.names = TRUE,
    fill = TRUE
  )
  all_rows[, commodity_key := vp_build_commodity_key(Trade, Group, Subgroup, MarketSegment, CommodityName, CommodityDetail)]

  all_rows[]
}

vp_route_display_grain_mixed_all_rows <- function(rows, calendars) {
  vp_require_packages("data.table")
  dt <- data.table::copy(data.table::as.data.table(rows))
  cal <- data.table::copy(data.table::as.data.table(calendars))
  if (nrow(dt) == 0L || nrow(cal) == 0L) {
    return(dt)
  }

  required_cols <- c(
    "commodity_key", "MonthNum", "Trade", "country", "country_label", "MarketYear", "Year",
    "Group", "Subgroup", "MarketSegment", "CommodityName", "CommodityDetail", "UnitType", "UnitDesc", "Amount"
  )
  if (!all(required_cols %in% names(dt))) {
    return(dt)
  }

  if (!("vp_rollup_level" %in% names(dt))) dt[, vp_rollup_level := "native"]
  if (!("vp_rollup_path" %in% names(dt))) dt[, vp_rollup_path := "P0_native"]
  if (!("vp_mixed_source_replacement" %in% names(dt))) dt[, vp_mixed_source_replacement := FALSE]

  target_rollup_levels <- c("segment_all", "subgroup_all", "group_all")
  dt[, vp_row_id := .I]

  candidate_rows <- dt[
    vp_rollup_level %in% target_rollup_levels
  ]
  if (nrow(candidate_rows) == 0L) {
    dt[, vp_row_id := NULL]
    group_cols <- setdiff(names(dt), "Amount")
    dt <- dt[, .(Amount = vp_sum_amount(Amount)), by = group_cols]
    return(dt[])
  }

  calendar_map <- unique(cal[, .(commodity_key, MonthNum, analysis_month)])
  candidate_rows <- calendar_map[candidate_rows, on = .(commodity_key, MonthNum)]
  candidate_rows <- candidate_rows[!is.na(analysis_month)]

  if (nrow(candidate_rows) == 0L) {
    dt[, vp_row_id := NULL]
    group_cols <- setdiff(names(dt), "Amount")
    dt <- dt[, .(Amount = vp_sum_amount(Amount)), by = group_cols]
    return(dt[])
  }

  replaced_ids <- unique(candidate_rows$vp_row_id)

  route_mixed_context <- function(input_dt, context_cols) {
    volume_rows <- input_dt[UnitType == "Volume"]
    if (nrow(volume_rows) == 0L) {
      return(input_dt)
    }

    volume_rows[, volume_family := vp_volume_family(UnitDesc)]
    mixed_contexts <- volume_rows[, .(
      has_weight = any(volume_family == "weight", na.rm = TRUE),
      has_liquid = any(volume_family == "liquid", na.rm = TRUE)
    ), by = context_cols][has_weight & has_liquid, ..context_cols]

    if (nrow(mixed_contexts) == 0L) {
      return(input_dt)
    }

    mixed_rows <- input_dt[mixed_contexts, on = context_cols, nomatch = 0L]
    if (nrow(mixed_rows) == 0L) {
      return(input_dt)
    }

    mixed_volume <- mixed_rows[UnitType == "Volume"]
    mixed_volume[, volume_family := vp_volume_family(UnitDesc)]
    eligible_cols <- unique(c(context_cols, "Year", "MonthNum"))
    eligible_weight_rows <- unique(mixed_volume[volume_family == "weight", ..eligible_cols])

    keep_volume <- mixed_volume[volume_family == "weight", .(vp_row_id)]
    keep_value <- mixed_rows[UnitType == "Value"][eligible_weight_rows, on = eligible_cols, nomatch = 0L][, .(vp_row_id)]
    keep_ids <- unique(c(keep_volume$vp_row_id, keep_value$vp_row_id))

    routed_rows <- mixed_rows[vp_row_id %in% keep_ids]
    input_dt <- input_dt[!(vp_row_id %in% mixed_rows$vp_row_id)]

    if (nrow(routed_rows) > 0L) {
      routed_rows[CommodityDetail == vp_all_type_label, CommodityDetail := vp_all_excluding_juice_label]
      routed_rows[, vp_mixed_source_replacement := TRUE]
      routed_rows[, commodity_key := vp_build_commodity_key(Trade, Group, Subgroup, MarketSegment, CommodityName, CommodityDetail)]
      drop_cols <- intersect(c("volume_family"), names(routed_rows))
      if (length(drop_cols) > 0L) {
        routed_rows[, (drop_cols) := NULL]
      }
      input_dt <- data.table::rbindlist(list(input_dt, routed_rows), use.names = TRUE, fill = TRUE)
    }

    input_dt
  }

  year_context_cols <- c(
    "Trade", "country", "country_label", "MarketYear",
    "Group", "Subgroup", "MarketSegment", "CommodityName", "CommodityDetail",
    "vp_rollup_level", "vp_rollup_path"
  )
  series_context_cols <- c(
    "Trade", "country", "country_label",
    "Group", "Subgroup", "MarketSegment", "CommodityName", "CommodityDetail",
    "vp_rollup_level", "vp_rollup_path"
  )

  candidate_rows <- route_mixed_context(candidate_rows, year_context_cols)
  candidate_rows <- route_mixed_context(candidate_rows, series_context_cols)

  candidate_rows[, analysis_month := NULL]
  dt <- dt[!(vp_row_id %in% replaced_ids)]
  dt <- data.table::rbindlist(list(dt, candidate_rows), use.names = TRUE, fill = TRUE)

  dt[, vp_row_id := NULL]
  group_cols <- setdiff(names(dt), "Amount")
  dt <- dt[, .(Amount = vp_sum_amount(Amount)), by = group_cols]
  dt[]
}

vp_volume_family <- function(unit_desc) {
  unit <- tolower(vp_clean_text(unit_desc, unspecified = ""))
  ifelse(grepl("gallon", unit), "liquid", "weight")
}

vp_volume_base_value <- function(amount, unit_desc) {
  family <- vp_volume_family(unit_desc)
  ifelse(family == "liquid", amount * 1000, amount * 0.45359237)
}

vp_unit_value_volume_value <- function(amount, unit_desc) {
  unit <- tolower(vp_clean_text(unit_desc, unspecified = ""))
  data.table::fifelse(
    grepl("gallon", unit),
    data.table::fifelse(grepl("thousand", unit), amount * 1000, amount),
    data.table::fifelse(grepl("pound", unit), data.table::fifelse(grepl("thousand", unit), amount * 1000, amount), vp_volume_base_value(amount, unit_desc))
  )
}

vp_unit_value_unit_label <- function(unit_desc) {
  unit <- tolower(vp_clean_text(unit_desc, unspecified = ""))
  data.table::fifelse(
    grepl("gallon", unit),
    "Dollars per gallon",
    data.table::fifelse(grepl("pound", unit), "Dollars per pound", "Dollars per metric ton")
  )
}

vp_market_month_name <- function(month_number) {
  labels <- month.abb[month_number]
  labels[is.na(month_number) | month_number < 1L | month_number > 12L] <- NA_character_
  labels
}

vp_build_app_data <- function(rows, calendars) {
  vp_require_packages("data.table")
  dt <- data.table::copy(data.table::as.data.table(rows))
  cal <- data.table::copy(data.table::as.data.table(calendars))
  dt <- cal[, .(commodity_key, MonthNum, analysis_month, month_abbrev, month_name, calendar_signature, calendar_source_market_year, calendar_source_scope, calendar_source_months, calendar_complete)][
    dt,
    on = .(commodity_key, MonthNum)
  ]

  if (!("vp_rollup_level" %in% names(dt))) dt[, vp_rollup_level := "native"]
  if (!("vp_rollup_path" %in% names(dt))) dt[, vp_rollup_path := "P0_native"]
  if (!("vp_is_rollup" %in% names(dt))) dt[, vp_is_rollup := FALSE]
  if (!("vp_volume_family_mixed" %in% names(dt))) dt[, vp_volume_family_mixed := FALSE]
  if (!("vp_mixed_source_replacement" %in% names(dt))) dt[, vp_mixed_source_replacement := FALSE]
  if (!("vp_rollup_schema_version" %in% names(dt))) dt[, vp_rollup_schema_version := vp_rollup_schema_version]

  key_cols <- c(
    "Trade", "Group", "Subgroup", "MarketSegment", "CommodityName", "CommodityDetail",
    "commodity_key", "country", "country_label", "MarketYear", "analysis_month",
    "MonthNum", "month_abbrev", "month_name", "calendar_signature", "calendar_source_market_year",
    "calendar_source_scope", "calendar_source_months", "calendar_complete",
    "vp_rollup_level", "vp_rollup_path", "vp_is_rollup", "vp_rollup_schema_version"
  )

  context_state <- dt[, .(
    Year = vp_pick_year(Year),
    vp_volume_family_mixed = any(as.logical(vp_volume_family_mixed), na.rm = TRUE),
    vp_mixed_source_replacement = any(as.logical(vp_mixed_source_replacement), na.rm = TRUE)
  ), by = key_cols]

  volume <- dt[UnitType == "Volume", {
    volume_family_values <- vp_volume_family(UnitDesc)
    valid_families <- volume_family_values[!is.na(Amount) & !is.na(volume_family_values) & nzchar(volume_family_values)]
    mixed_detected <- data.table::uniqueN(valid_families) > 1L
    has_amount <- any(!is.na(Amount))
    idx <- if (has_amount) which.max(!is.na(Amount)) else NA_integer_
    picked_unit <- if (is.na(idx)) NA_character_ else (UnitDesc[[idx]] %||% NA_character_)
    picked_family <- if (is.na(picked_unit) || !nzchar(picked_unit)) NA_character_ else vp_volume_family(picked_unit)
    picked_unit_value <- if (is.na(picked_unit) || !nzchar(picked_unit)) NA_character_ else vp_unit_value_unit_label(picked_unit)

    list(
      monthly_volume_base = if (mixed_detected) NA_real_ else vp_sum_amount(vp_volume_base_value(Amount, UnitDesc)),
      volume_unit_family = if (mixed_detected) NA_character_ else picked_family,
      source_volume_unit = if (mixed_detected) NA_character_ else picked_unit,
      monthly_unit_value_volume_base = if (mixed_detected) NA_real_ else vp_sum_amount(vp_unit_value_volume_value(Amount, UnitDesc)),
      unit_value_unit = if (mixed_detected) NA_character_ else picked_unit_value,
      vp_volume_family_mixed_detected = mixed_detected
    )
  }, by = key_cols]

  value <- dt[UnitType == "Value", .(
    monthly_value_dollars = vp_sum_amount(ifelse(tolower(UnitDesc) == "thousand dollars", Amount * 1000, Amount)),
    source_value_unit = {
      has_amount <- any(!is.na(Amount))
      if (!has_amount) NA_character_ else (UnitDesc[[which.max(!is.na(Amount))]] %||% NA_character_)
    }
  ), by = key_cols]

  app <- Reduce(function(left, right) merge(left, right, by = key_cols, all = TRUE), list(context_state, volume, value))
  app[is.na(vp_volume_family_mixed_detected), vp_volume_family_mixed_detected := FALSE]
  app[, vp_volume_family_mixed := as.logical(vp_volume_family_mixed | vp_volume_family_mixed_detected)]
  app[, vp_volume_family_mixed_detected := NULL]
  app[is.na(vp_mixed_source_replacement), vp_mixed_source_replacement := FALSE]
  app[vp_volume_family_mixed == TRUE, `:=`(
    monthly_volume_base = NA_real_,
    volume_unit_family = NA_character_,
    source_volume_unit = NA_character_,
    monthly_unit_value_volume_base = NA_real_,
    unit_value_unit = NA_character_
  )]

  data.table::setorder(app, Trade, Group, Subgroup, MarketSegment, CommodityName, CommodityDetail, country, MarketYear, analysis_month)
  app[, ytd_volume_base := {
    mixed_seen <- cumsum(replace(as.logical(vp_volume_family_mixed), is.na(vp_volume_family_mixed), FALSE)) > 0L
    if (all(is.na(monthly_volume_base))) {
      rep(NA_real_, .N)
    } else {
      cumulative_volume <- cumsum(replace(monthly_volume_base, is.na(monthly_volume_base), 0))
      cumulative_volume[mixed_seen] <- NA_real_
      cumulative_volume
    }
  }, by = .(Trade, commodity_key, country, MarketYear)]
  app[, ytd_value_dollars := cumsum(replace(monthly_value_dollars, is.na(monthly_value_dollars), 0)), by = .(Trade, commodity_key, country, MarketYear)]
  app[, ytd_unit_value_volume_base := {
    mixed_seen <- cumsum(replace(as.logical(vp_volume_family_mixed), is.na(vp_volume_family_mixed), FALSE)) > 0L
    if (all(is.na(monthly_unit_value_volume_base))) {
      rep(NA_real_, .N)
    } else {
      cumulative_volume <- cumsum(replace(monthly_unit_value_volume_base, is.na(monthly_unit_value_volume_base), 0))
      cumulative_volume[mixed_seen] <- NA_real_
      cumulative_volume
    }
  }, by = .(Trade, commodity_key, country, MarketYear)]
  app[, unit_value := data.table::fifelse(
    is.finite(monthly_value_dollars) & is.finite(monthly_unit_value_volume_base) & monthly_unit_value_volume_base != 0,
    monthly_value_dollars / monthly_unit_value_volume_base,
    NA_real_
  )]
  app[, ytd_unit_value := data.table::fifelse(
    is.finite(ytd_value_dollars) & is.finite(ytd_unit_value_volume_base) & ytd_unit_value_volume_base != 0,
    ytd_value_dollars / ytd_unit_value_volume_base,
    NA_real_
  )]
  app[is.na(volume_unit_family) | !nzchar(volume_unit_family), unit_value_unit := NA_character_]
  app[, ytd_unit_value_unit := unit_value_unit]
  app[, ytd_unit_value_unit := {
    labels <- as.character(ytd_unit_value_unit)
    out <- labels
    last_label <- NA_character_
    for (idx in seq_along(out)) {
      current_label <- labels[[idx]]
      if (!is.na(current_label) && nzchar(current_label)) {
        last_label <- current_label
      }
      if (is.finite(ytd_unit_value[[idx]]) && (is.na(out[[idx]]) || !nzchar(out[[idx]]))) {
        out[[idx]] <- last_label
      }
    }
    out
  }, by = .(Trade, commodity_key, country, MarketYear)]

  app[, commodity := CommodityDetail]
  app[, countryDescription := country_label]
  app[, country_source_code := country]
  app[, market_year := as.integer(MarketYear)]
  app[, calendar_year := as.integer(Year)]
  app[, calendar_month := as.integer(MonthNum)]
  app[, month := as.integer(MonthNum)]
  app[, market_month := as.integer(analysis_month)]
  app[, market_month_name := vp_market_month_name(MonthNum)]
  app[, monthlyexports := monthly_volume_base]
  app[, monthlyexports_rough_eq := monthlyexports]
  app[, ytd_exports := ytd_volume_base]
  app[, ytd_exports_rough_eq := ytd_exports]
  app[, total_commitment := ytd_exports]
  app[, total_commitment_rough_eq := total_commitment]
  app[, outstandingSales := NA_real_]
  app[, outstandingSales_rough_eq := outstandingSales]
  app[, grossNewSales := monthlyexports]
  app[, grossNewSales_rough_eq := grossNewSales]
  app[, currentMYNetSales := monthlyexports]
  app[, currentMYNetSales_rough_eq := currentMYNetSales]
  app[, nextMYOutstandingSales := NA_real_]
  app[, nextMYOutstandingSales_rough_eq := nextMYOutstandingSales]
  app[, nextMYNetSales := NA_real_]
  app[, nextMYNetSales_rough_eq := nextMYNetSales]
  app[, monthlyvalue := monthly_value_dollars]
  app[, monthlyvalue_rough_eq := monthlyvalue]
  app[, ytd_value := ytd_value_dollars]
  app[, ytd_value_rough_eq := ytd_value]

  ordered_cols <- c(
    "commodity", "country", "countryDescription", "country_source_code",
    "market_year", "calendar_year", "calendar_month", "month", "market_month", "analysis_month", "market_month_name",
    "monthlyexports", "monthlyexports_rough_eq", "ytd_exports", "ytd_exports_rough_eq",
    "total_commitment", "total_commitment_rough_eq", "outstandingSales", "outstandingSales_rough_eq",
    "grossNewSales", "grossNewSales_rough_eq", "currentMYNetSales", "currentMYNetSales_rough_eq",
    "nextMYOutstandingSales", "nextMYOutstandingSales_rough_eq", "nextMYNetSales", "nextMYNetSales_rough_eq",
    "monthlyvalue", "monthlyvalue_rough_eq", "ytd_value", "ytd_value_rough_eq",
    "Trade", "Group", "Subgroup", "MarketSegment", "CommodityName", "CommodityDetail", "commodity_key",
    "MonthNum", "month_abbrev", "month_name", "calendar_signature", "calendar_source_market_year", "calendar_source_scope", "calendar_source_months", "calendar_complete",
    "vp_rollup_level", "vp_rollup_path", "vp_is_rollup", "vp_volume_family_mixed", "vp_mixed_source_replacement", "vp_rollup_schema_version",
    "volume_unit_family", "source_volume_unit", "source_value_unit", "unit_value", "unit_value_unit", "ytd_unit_value", "ytd_unit_value_unit"
  )
  app[, ..ordered_cols]
}

vp_build_metadata <- function(source_rows, app_data, calendars, csv_path, month_column) {
  rollup_counts <- if ("vp_rollup_level" %in% names(source_rows)) {
    as.list(table(source_rows$vp_rollup_level, useNA = "ifany"))
  } else {
    list()
  }

  mixed_volume_contexts <- if (all(c("vp_volume_family_mixed", "Trade", "Group", "Subgroup", "MarketSegment", "CommodityName", "CommodityDetail", "country", "MarketYear", "MonthNum") %in% names(source_rows))) {
    data.table::as.data.table(source_rows)[vp_volume_family_mixed == TRUE, data.table::uniqueN(paste(Trade, Group, Subgroup, MarketSegment, CommodityName, CommodityDetail, country, MarketYear, MonthNum, sep = "|"))]
  } else {
    0L
  }

  signature <- vp_file_signature(csv_path)
  list(
    builder_version = vp_artifact_builder_version,
    builder_floor = vp_artifact_builder_floor,
    built_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    source_signature = signature,
    source_signature_string = vp_signature_string(signature),
    month_column = month_column,
    rollup_schema_version = vp_rollup_schema_version,
    rollup_required_fields = vp_rollup_required_fields(),
    rollup_tokens = list(
      group = vp_rollup_group_token,
      subgroup = vp_rollup_subgroup_token,
      market_segment = vp_rollup_market_segment_token
    ),
    rollup_counts = rollup_counts,
    rollup_rows = if ("vp_is_rollup" %in% names(source_rows)) sum(as.logical(source_rows$vp_is_rollup), na.rm = TRUE) else 0L,
    mixed_volume_contexts = mixed_volume_contexts,
    rows_source = nrow(source_rows),
    rows_app = nrow(app_data),
    trades = sort(unique(source_rows$Trade)),
    unit_types = sort(unique(source_rows$UnitType)),
    unit_desc = sort(unique(source_rows$UnitDesc)),
    world_rows = sum(source_rows$country == "GRAND_TOTAL", na.rm = TRUE),
    commodity_keys = data.table::uniqueN(source_rows$commodity_key),
    calendars = calendars,
    calendar_signature = paste(sort(unique(calendars$calendar_signature)), collapse = "|")
  )
}

vp_build_trade_artifact <- function(project_dir = vp_find_root()) {
  paths <- vp_paths(project_dir)
  dir.create(paths$processed_dir, recursive = TRUE, showWarnings = FALSE)
  raw <- vp_read_csv(paths$input_csv)
  month_column <- attr(raw, "month_column") %||% "MonthNum"
  source_rows <- vp_normalize_source_rows(raw)
  source_rows <- vp_append_all_type_rows(source_rows)
  calendars <- vp_infer_month_calendars(source_rows)
  source_rows <- vp_route_display_grain_mixed_all_rows(source_rows, calendars)
  calendars <- vp_infer_month_calendars(source_rows)
  app_data <- vp_build_app_data(source_rows, calendars)
  metadata <- vp_build_metadata(source_rows, app_data, calendars, paths$input_csv, month_column)
  artifact <- as.data.frame(app_data)
  if (exists("write_processed_artifact", mode = "function")) {
    write_processed_artifact(
      data = artifact,
      artifact_path = paths$artifact,
      project_dir = project_dir,
      source_paths = paths$input_csv,
      extra_signatures = c(builder_version = vp_artifact_builder_version),
      artifact_metadata = metadata
    )
  } else {
    saveRDS(artifact, paths$artifact)
  }
  saveRDS(metadata, paths$metadata)
  invisible(artifact)
}

vp_read_trade_artifact <- function(project_dir = vp_find_root(), require_current = TRUE) {
  paths <- vp_paths(project_dir)
  if (!file.exists(paths$artifact)) {
    stop("FTN processed artifact is missing. Run Master_FTN.R or vp_build_trade_artifact() first.", call. = FALSE)
  }
  artifact <- readRDS(paths$artifact)
  if (require_current) {
    current_signature <- vp_signature_string(vp_file_signature(paths$input_csv))
    artifact_signature <- artifact$metadata$source_signature_string %||% ""
    if (!identical(current_signature, artifact_signature)) {
      stop("FTN processed artifact is stale relative to the input CSV. Rebuild with Master_FTN.R.", call. = FALSE)
    }
  }
  artifact
}

vp_metric_defs <- function() {
  data.frame(
    metric = c("monthly_volume", "ytd_volume", "monthly_value", "ytd_value", "unit_value", "ytd_unit_value"),
    label = c("Monthly Volume", "Accumulated Volume", "Monthly Value", "Accumulated Value", "Unit Value", "Accumulated Unit Value"),
    type = c("quantity", "quantity", "value", "value", "rate", "rate"),
    stringsAsFactors = FALSE
  )
}

vp_metric_column <- function(metric) {
  switch(metric,
    monthly_volume = "monthly_volume_base",
    ytd_volume = "ytd_volume_base",
    monthly_value = "monthly_value_dollars",
    ytd_value = "ytd_value_dollars",
    unit_value = "unit_value",
    ytd_unit_value = "ytd_unit_value",
    "monthly_volume_base"
  )
}

vp_metric_type <- function(metric) {
  defs <- vp_metric_defs()
  defs$type[match(metric, defs$metric)] %||% "quantity"
}

vp_quantity_unit_choices <- function(volume_family) {
  if (identical(volume_family, "liquid")) {
    c("Gallons" = "gallons", "Thousand gallons" = "thousand_gallons")
  } else {
    c("Metric tons" = "metric_tons", "Thousand metric tons" = "thousand_metric_tons", "U.S. tons" = "us_tons", "Thousand pounds" = "thousand_pounds")
  }
}

vp_value_unit_choices <- function() {
  c("Dollars" = "dollars", "Thousand dollars" = "thousand_dollars", "Million dollars" = "million_dollars")
}

vp_convert_quantity <- function(value, unit, volume_family) {
  if (identical(volume_family, "liquid")) {
    return(switch(unit,
      thousand_gallons = value / 1000,
      gallons = value,
      value
    ))
  }
  switch(unit,
    thousand_metric_tons = value / 1000,
    us_tons = value * 1.10231131,
    thousand_pounds = value / 0.45359237,
    metric_tons = value,
    value
  )
}

vp_convert_value <- function(value, unit) {
  switch(unit,
    thousand_dollars = value / 1000,
    million_dollars = value / 1000000,
    dollars = value,
    value
  )
}

vp_unit_label <- function(unit) {
  labels <- c(
    gallons = "Gallons",
    thousand_gallons = "Thousand gallons",
    metric_tons = "Metric tons",
    thousand_metric_tons = "Thousand metric tons",
    us_tons = "U.S. tons",
    thousand_pounds = "Thousand pounds",
    dollars = "Dollars",
    thousand_dollars = "Thousand dollars",
    million_dollars = "Million dollars"
  )
  labels[[unit]] %||% unit
}

vp_safe_read_csv <- function(path, columns) {
  if (!file.exists(path)) {
    return(data.frame(matrix(ncol = length(columns), nrow = 0, dimnames = list(NULL, columns)), stringsAsFactors = FALSE))
  }
  out <- tryCatch(utils::read.csv(path, stringsAsFactors = FALSE), error = function(e) NULL)
  if (is.null(out)) {
    return(data.frame(matrix(ncol = length(columns), nrow = 0, dimnames = list(NULL, columns)), stringsAsFactors = FALSE))
  }
  for (column in setdiff(columns, names(out))) out[[column]] <- character(nrow(out))
  out[, columns, drop = FALSE]
}

vp_load_custom_types <- function(project_dir = vp_find_root()) {
  path <- vp_paths(project_dir)$custom_types
  vp_safe_read_csv(path, c("name", "commodity_keys", "created_at"))
}

vp_save_custom_type <- function(name, commodity_keys, project_dir = vp_find_root()) {
  paths <- vp_paths(project_dir)
  dir.create(dirname(paths$custom_types), recursive = TRUE, showWarnings = FALSE)
  existing <- vp_load_custom_types(project_dir)
  row <- data.frame(name = name, commodity_keys = paste(commodity_keys, collapse = "|"), created_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"), stringsAsFactors = FALSE)
  existing <- existing[existing$name != name, , drop = FALSE]
  utils::write.csv(rbind(existing, row), paths$custom_types, row.names = FALSE)
}

vp_load_custom_countries <- function(project_dir = vp_find_root()) {
  path <- vp_paths(project_dir)$custom_countries
  vp_safe_read_csv(path, c("name", "countries", "created_at"))
}

vp_save_custom_country <- function(name, countries, project_dir = vp_find_root()) {
  paths <- vp_paths(project_dir)
  dir.create(dirname(paths$custom_countries), recursive = TRUE, showWarnings = FALSE)
  existing <- vp_load_custom_countries(project_dir)
  row <- data.frame(name = name, countries = paste(countries, collapse = "|"), created_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"), stringsAsFactors = FALSE)
  existing <- existing[existing$name != name, , drop = FALSE]
  utils::write.csv(rbind(existing, row), paths$custom_countries, row.names = FALSE)
}
