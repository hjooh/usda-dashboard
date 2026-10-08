  # Shared reactive: country choices with sidebar sort/filter/label logic
  country_display_names_for_frequency <- reactive({
    start_time <- Sys.time()
    req(input$data_frequency)

    census_trade_flow <- if (!is.null(input$census_trade_flow_choice) && input$census_trade_flow_choice %in% c("export", "import")) {
      input$census_trade_flow_choice
    } else {
      "export"
    }

    source_choice <- current_source_choice_safe()
    hybrid_trade_flow <- if (!is.null(input$hybrid_trade_flow_choice) && input$hybrid_trade_flow_choice %in% c("export", "import")) {
      input$hybrid_trade_flow_choice
    } else {
      "export"
    }

    effective_trade_flow <- if (identical(source_choice, "census")) {
      census_trade_flow
    } else if (identical(source_choice, "hybrid")) {
      hybrid_trade_flow
    } else {
      "n/a"
    }

    context_key <- if (identical(source_choice, "census")) {
      if (identical(census_trade_flow, "import")) "census_import" else "census_export"
    } else if (identical(source_choice, "hybrid")) {
      if (identical(hybrid_trade_flow, "import")) {
        "hybrid_import_monthly"
      } else if (!is.null(input$hybrid_mode_choice) && identical(input$hybrid_mode_choice, "weekly_imputed")) {
        "hybrid_weekly_imputed"
      } else {
        "hybrid_export_monthly"
      }
    } else if (identical(source_choice, "psd")) {
      "psd"
    } else if (identical(source_choice, "wasde")) {
      "wasde"
    } else if (input$data_frequency == "monthly") {
      "export_sales_monthly"
    } else {
      "export_sales_weekly"
    }

    result <- get_country_display_names_for_context(context_key)

    log_perf(
      "country_display_names_for_frequency()",
      start_time,
      details = c(
        source_switch_epoch_fields(include_age = TRUE),
        list(
        source = source_choice,
        frequency = input$data_frequency,
        trade_flow = effective_trade_flow,
        context_key = context_key,
        choices = length(result)
        )
      )
    )

    result
  }) %>% bindCache(
    current_source_choice_safe(),
    input$data_frequency,
    if (!is.null(input$census_trade_flow_choice) && input$census_trade_flow_choice %in% c("export", "import")) input$census_trade_flow_choice else "export",
    if (!is.null(input$hybrid_trade_flow_choice) && input$hybrid_trade_flow_choice %in% c("export", "import")) input$hybrid_trade_flow_choice else "export",
    if (!is.null(input$hybrid_mode_choice)) input$hybrid_mode_choice else "standard"
  )

  resolve_wasde_country_code <- function(default = "U_S") {
    candidate_codes <- character(0)

    if (
      exists("rice_data_wasde_marketing_year", inherits = TRUE) &&
      is.data.frame(rice_data_wasde_marketing_year) &&
      "country" %in% names(rice_data_wasde_marketing_year)
    ) {
      candidate_codes <- trimws(as.character(rice_data_wasde_marketing_year$country))
      candidate_codes <- unique(candidate_codes[!is.na(candidate_codes) & nzchar(candidate_codes)])
    }

    preferred_codes <- c("U_S", "UNITED_STATES", "USA", "US")
    preferred_match <- preferred_codes[preferred_codes %in% candidate_codes]
    if (length(preferred_match) > 0) {
      return(preferred_match[[1]])
    }

    if (length(candidate_codes) > 0) {
      return(candidate_codes[[1]])
    }

    default
  }

  resolve_wasde_country_choice_vector <- function(country_choices = NULL) {
    resolved_code <- resolve_wasde_country_code()

    if (!is.null(country_choices) && length(country_choices) > 0) {
      choice_codes <- as.character(unname(country_choices))
      code_match_idx <- which(choice_codes == resolved_code)
      if (length(code_match_idx) > 0) {
        return(country_choices[code_match_idx[[1]]])
      }

      normalized_labels <- toupper(gsub("[^A-Z0-9]+", "", as.character(names(country_choices))))
      us_label_idx <- which(normalized_labels %in% c("US", "USA", "UNITEDSTATES"))
      if (length(us_label_idx) > 0) {
        return(country_choices[us_label_idx[[1]]])
      }
    }

    display_label <- unname(country_display_name_lookup[resolved_code])
    if (!(length(display_label) == 1 && !is.na(display_label) && nzchar(display_label))) {
      display_label <- if (identical(resolved_code, "U_S")) "U.S." else resolved_code
    }

    stats::setNames(resolved_code, display_label)
  }

  choose_psd_preferred_country_code <- function(country_codes) {
    unique_codes <- unique(trimws(as.character(country_codes)))
    unique_codes <- unique_codes[nzchar(unique_codes)]

    if (length(unique_codes) == 0) return(NA_character_)
    if ("GRAND_TOTAL" %in% unique_codes) return("GRAND_TOTAL")

    unique_codes[order(-nchar(unique_codes), unique_codes)][1]
  }

  choose_psd_preferred_country_label <- function(country_labels) {
    unique_labels <- unique(trimws(as.character(country_labels)))
    unique_labels <- unique_labels[nzchar(unique_labels)]

    if (length(unique_labels) == 0) return(NA_character_)
    if ("World" %in% unique_labels) return("World")

    unique_labels[order(nchar(unique_labels), unique_labels)][1]
  }

  normalize_psd_us_country_label <- function(country_code, country_label = NA_character_) {
    code <- trimws(as.character(country_code %||% ""))
    label <- trimws(as.character(country_label %||% ""))
    code <- if (length(code) > 0L && !is.na(code[[1L]])) code[[1L]] else ""
    label <- if (length(label) > 0L && !is.na(label[[1L]])) label[[1L]] else ""
    normalized_label <- toupper(gsub("[^A-Z0-9]+", "", label))
    normalized_code <- toupper(gsub("[^A-Z0-9]+", "", code))

    if (normalized_code %in% c("US", "USA") || normalized_label %in% c("US", "USA", "USTOTAL", "UNITEDSTATES")) {
      return("United States")
    }

    label
  }

  canonicalize_psd_country_pairs <- function(country_df) {
    if (!is.data.frame(country_df) || nrow(country_df) == 0) {
      return(data.frame(country = character(), country_label = character(), stringsAsFactors = FALSE))
    }

    country_df %>%
      transmute(
        country = dplyr::if_else(is.na(.data$country), "", trimws(as.character(.data$country))),
        countryDescription = dplyr::if_else(is.na(.data$countryDescription), "", trimws(as.character(.data$countryDescription)))
      ) %>%
      mutate(
        countryDescription = dplyr::if_else(
          .data$country %in% names(country_display_name_lookup),
          unname(country_display_name_lookup[.data$country]),
          .data$countryDescription
        ),
        countryDescription = dplyr::if_else(.data$countryDescription == "", .data$country, .data$countryDescription),
        countryDescription = dplyr::if_else(.data$country == "GRAND_TOTAL", "World", .data$countryDescription),
        countryDescription = purrr::map2_chr(.data$country, .data$countryDescription, normalize_psd_us_country_label)
      ) %>%
      filter(!is.na(.data$country), nzchar(.data$country), !is.na(.data$countryDescription), nzchar(.data$countryDescription)) %>%
      distinct(country, countryDescription) %>%
      group_by(.data$countryDescription) %>%
      summarise(country = choose_psd_preferred_country_code(.data$country), .groups = "drop") %>%
      group_by(.data$country) %>%
      summarise(country_label = choose_psd_preferred_country_label(.data$countryDescription), .groups = "drop") %>%
      arrange(.data$country_label, .data$country)
  }

  psd_country_selectize_options <- function() {
    list(
      placeholder = "Type to filter countries...",
      openOnFocus = TRUE,
      closeAfterSelect = TRUE,
      maxOptions = 250
    )
  }

  build_psd_country_choice_label <- function(country_code, country_label, share_lookup = NULL, metric_code = effective_main_metric()) {
    base_label <- normalize_psd_us_country_label(country_code, get_active_country_label(country_code, country_label))

    source_choice <- if (!is.null(input$data_source_choice)) input$data_source_choice else "export_sales"
    if (
      identical(country_code, "GRAND_TOTAL") ||
      is_psd_non_share_metric(metric_code = metric_code %||% NULL, source_choice = source_choice) ||
      is.null(share_lookup) ||
      !(country_code %in% names(share_lookup))
    ) {
      return(base_label)
    }

    share_pct <- unname(share_lookup[country_code])
    if (length(share_pct) == 0 || is.na(share_pct) || !is.finite(share_pct)) {
      return(base_label)
    }

    paste0(base_label, " (", sprintf("%.1f%%", share_pct * 100), ")")
  }

  build_psd_country_choice_vector <- function(ordered_df, share_lookup = NULL, metric_code = effective_main_metric()) {
    if (!is.data.frame(ordered_df) || nrow(ordered_df) == 0) {
      return(stats::setNames(character(0), character(0)))
    }

    country_codes <- trimws(as.character(ordered_df$country %||% character(0)))
    country_labels <- trimws(as.character(ordered_df$country_label %||% character(0)))

    keep_idx <- !is.na(country_codes) & nzchar(country_codes)
    if (!any(keep_idx)) {
      return(stats::setNames(character(0), character(0)))
    }

    country_codes <- country_codes[keep_idx]
    country_labels <- country_labels[keep_idx]
    base_labels <- mapply(
      function(country_code, country_label) normalize_psd_us_country_label(country_code, get_active_country_label(country_code, country_label)),
      country_codes,
      country_labels,
      USE.NAMES = FALSE
    )

    source_choice <- if (!is.null(input$data_source_choice)) input$data_source_choice else "export_sales"
    show_share_suffix <- !is_psd_non_share_metric(metric_code = metric_code %||% NULL, source_choice = source_choice)
    if (!isTRUE(show_share_suffix) || is.null(share_lookup) || length(share_lookup) == 0) {
      return(stats::setNames(country_codes, base_labels))
    }

    label_values <- base_labels
    share_idx <- country_codes != "GRAND_TOTAL" & country_codes %in% names(share_lookup)
    if (any(share_idx)) {
      share_values <- suppressWarnings(as.numeric(unname(share_lookup[country_codes[share_idx]])))
      valid_share_idx <- is.finite(share_values)
      if (any(valid_share_idx)) {
        share_positions <- which(share_idx)[valid_share_idx]
        label_values[share_positions] <- paste0(
          base_labels[share_positions],
          " (",
          sprintf("%.1f%%", share_values[valid_share_idx] * 100),
          ")"
        )
      }
    }

    stats::setNames(country_codes, label_values)
  }

  build_psd_custom_country_choice_vector <- function(custom_country_defs) {
    if (!is.data.frame(custom_country_defs) || nrow(custom_country_defs) == 0) {
      return(stats::setNames(character(0), character(0)))
    }

    defs_df <- as_tibble(custom_country_defs) %>%
      filter(.data$parse_ok) %>%
      transmute(
        custom_name = trimws(as.character(.data$custom_name)),
        custom_name_key = tolower(trimws(as.character(.data$custom_name)))
      ) %>%
      filter(!is.na(.data$custom_name), nzchar(.data$custom_name)) %>%
      arrange(.data$custom_name_key, .data$custom_name) %>%
      distinct(.data$custom_name_key, .keep_all = TRUE)

    if (nrow(defs_df) == 0) {
      return(stats::setNames(character(0), character(0)))
    }

    choice_values <- vapply(defs_df$custom_name, build_custom_country_choice_value, character(1))
    choice_labels <- paste0(defs_df$custom_name, " (Custom)")
    stats::setNames(choice_values, choice_labels)
  }

  build_psd_country_metric_frame <- function(metric_col, selected_commodity, extra_cols = character(0)) {
    start_time <- Sys.time()
    source_df <- rice_data_psd_marketing_year
    metric_col <- trimws(as.character(metric_col %||% character(0)))
    metric_col <- metric_col[!is.na(metric_col) & nzchar(metric_col)]
    selected_commodity <- trimws(as.character(selected_commodity %||% character(0)))
    selected_commodity <- selected_commodity[!is.na(selected_commodity) & nzchar(selected_commodity)]
    extra_cols <- trimws(as.character(extra_cols %||% character(0)))
    extra_cols <- unique(extra_cols[!is.na(extra_cols) & nzchar(extra_cols)])

    if (length(metric_col) == 0 || length(selected_commodity) == 0) {
      return(data.frame())
    }

    metric_col <- metric_col[[1]]
    selected_commodity <- selected_commodity[[1]]
    metric_defaults <- resolve_psd_metric_defaults(metric_col)
    metric_unit_choice <- current_psd_quantity_unit_choice_safe(
      default = metric_defaults$unit_choice,
      metric_code = metric_col,
      source_choice = "psd"
    )
    metric_area_unit_choice <- current_psd_area_unit_choice_safe(metric_defaults$area_unit_choice)

    if (
      is.null(source_df) ||
        !is.data.frame(source_df) ||
        nrow(source_df) == 0 ||
        !(metric_col %in% names(source_df))
    ) {
      return(data.frame())
    }

    required_cols <- unique(c(
      "country", "countryDescription", "commodity", "market_year", "analysis_month",
      metric_col, paste0(metric_col, "_rough_eq"), extra_cols
    ))
    required_cols <- required_cols[required_cols %in% names(source_df)]
    if (!all(c("country", "countryDescription", "commodity", "market_year", "analysis_month", metric_col) %in% required_cols)) {
      return(data.frame())
    }

    metric_source <- source_df[, required_cols, drop = FALSE] %>%
      filter(.data$commodity == selected_commodity)
    if (nrow(metric_source) == 0) {
      return(data.frame())
    }

    metric_values <- sanitize_numeric(metric_source[[metric_col]])
    rough_col <- paste0(metric_col, "_rough_eq")
    rough_values <- if (rough_col %in% names(metric_source)) {
      sanitize_numeric(metric_source[[rough_col]])
    } else {
      metric_values
    }

    converted_values <- if (is_psd_milling_rate_metric(metric_col)) {
      metric_values
    } else if (psd_yield_lock_active_for_metric(metric_col, "psd")) {
      unit_conversion(
        rough_values,
        metric_unit_choice,
        source_choice = "psd",
        metric_code = metric_col,
        area_unit_choice = metric_area_unit_choice
      )
    } else {
      basis_values <- basis_conversion(
        base_value = metric_values,
        rough_value = rough_values,
        basis_choice = current_basis_choice_safe(default = metric_defaults$basis_choice),
        source_choice = "psd"
      )
      unit_conversion(
        basis_values,
        metric_unit_choice,
        source_choice = "psd",
        metric_code = metric_col,
        area_unit_choice = metric_area_unit_choice
      )
    }

    metric_source[[metric_col]] <- sanitize_numeric(converted_values)

    log_perf(
      "build_psd_country_metric_frame()",
      start_time,
      details = c(
        source_switch_epoch_fields(include_age = TRUE),
        list(
          metric = metric_col,
          commodity = selected_commodity,
          rows = nrow(metric_source),
          source_mode = "psd_metric_only"
        )
      )
    )

    metric_source
  }

  custom_comparison_vp_commodity_name_choices <- function() {
    if (!identical(current_source_choice_safe(default = input$data_source_choice %||% "export_sales"), "vp_trade")) {
      return(stats::setNames(character(0), character(0)))
    }

    vp_rows <- if (exists("vp_trade_rows_or_empty", mode = "function")) {
      vp_trade_rows_or_empty(require_non_empty = FALSE)
    } else if (exists("rice_data_vp_trade_monthly", inherits = TRUE) && is.data.frame(rice_data_vp_trade_monthly)) {
      rice_data_vp_trade_monthly
    } else {
      data.frame()
    }
    if (nrow(vp_rows) == 0) {
      return(stats::setNames(character(0), character(0)))
    }

    if (exists("filter_vp_rows_for_resolved_hierarchy", mode = "function")) {
      vp_rows <- filter_vp_rows_for_resolved_hierarchy(
        vp_rows = vp_rows,
        vp_trade_flow_choice = input$vp_trade_flow_choice,
        vp_group_choice = input$vp_group_choice,
        vp_subgroup_choice = input$vp_subgroup_choice,
        vp_market_segment_choice = input$vp_market_segment_choice,
        vp_commodity_name_choice = NULL,
        vp_commodity_detail_choice = NULL,
        vp_filter_purpose = "comparison_commodity_choices"
      )
    } else {
      vp_all_choice <- "__all__"
      vp_trade_flow <- input$vp_trade_flow_choice %||% "export"
      vp_group <- input$vp_group_choice %||% vp_all_choice
      vp_subgroup <- input$vp_subgroup_choice %||% vp_all_choice
      vp_market_segment <- input$vp_market_segment_choice %||% vp_all_choice

      if (!is.null(vp_trade_flow) && "Trade" %in% names(vp_rows)) {
        vp_rows <- vp_rows[vp_rows$Trade == vp_trade_flow, , drop = FALSE]
      }
      if (!is.null(vp_group) && !identical(vp_group, vp_all_choice) && "Group" %in% names(vp_rows)) {
        vp_rows <- vp_rows[vp_rows$Group == vp_group, , drop = FALSE]
      }
      if (!is.null(vp_subgroup) && !identical(vp_subgroup, vp_all_choice) && "Subgroup" %in% names(vp_rows)) {
        vp_rows <- vp_rows[vp_rows$Subgroup == vp_subgroup, , drop = FALSE]
      }
      if (!is.null(vp_market_segment) && !identical(vp_market_segment, vp_all_choice) && "MarketSegment" %in% names(vp_rows)) {
        vp_rows <- vp_rows[vp_rows$MarketSegment == vp_market_segment, , drop = FALSE]
      }
    }

    commodity_values <- if ("CommodityName" %in% names(vp_rows)) sort(unique(as.character(vp_rows$CommodityName))) else character(0)
    commodity_values <- commodity_values[!is.na(commodity_values) & nzchar(commodity_values)]
    stats::setNames(commodity_values, commodity_values)
  }

  resolve_custom_comparison_vp_commodity_name <- function(preferred_commodity_name = NULL) {
    choices <- custom_comparison_vp_commodity_name_choices()
    values <- unique(unname(choices))
    values <- values[!is.na(values) & nzchar(values)]

    if (length(values) == 0) {
      fallback <- as.character(input$vp_commodity_name_choice %||% NA_character_)
      fallback <- fallback[!is.na(fallback) & nzchar(fallback)]
      if (length(fallback) == 0) return(NULL)
      return(fallback[[1]])
    }

    preferred <- as.character(preferred_commodity_name %||% character(0))
    preferred <- preferred[!is.na(preferred) & nzchar(preferred)]
    if (length(preferred) > 0 && preferred[[1]] %in% values) return(preferred[[1]])

    global_choice <- as.character(input$vp_commodity_name_choice %||% character(0))
    global_choice <- global_choice[!is.na(global_choice) & nzchar(global_choice)]
    if (length(global_choice) > 0 && global_choice[[1]] %in% values) return(global_choice[[1]])

    values[[1]]
  }

  custom_comparison_panel_vp_type_choices <- function(vp_commodity_name_value) {
    if (!identical(current_source_choice_safe(default = input$data_source_choice %||% "export_sales"), "vp_trade")) {
      return(group_rice_type_choices(
        flat_choices = commodity_choice_real_values(),
        custom_names = custom_types_enriched() %>% filter(.data$parse_ok) %>% pull(.data$custom_name),
        include_builder = FALSE
      ))
    }

    vp_rows <- if (exists("vp_trade_rows_or_empty", mode = "function")) {
      vp_trade_rows_or_empty(require_non_empty = FALSE)
    } else if (exists("rice_data_vp_trade_monthly", inherits = TRUE) && is.data.frame(rice_data_vp_trade_monthly)) {
      rice_data_vp_trade_monthly
    } else {
      data.frame()
    }

    if (nrow(vp_rows) == 0) {
      return(stats::setNames(character(0), character(0)))
    }

    panel_vp_commodity <- resolve_custom_comparison_vp_commodity_name(vp_commodity_name_value)

    if (exists("filter_vp_rows_for_resolved_hierarchy", mode = "function")) {
      vp_rows <- filter_vp_rows_for_resolved_hierarchy(
        vp_rows = vp_rows,
        vp_trade_flow_choice = input$vp_trade_flow_choice,
        vp_group_choice = input$vp_group_choice,
        vp_subgroup_choice = input$vp_subgroup_choice,
        vp_market_segment_choice = input$vp_market_segment_choice,
        vp_commodity_name_choice = panel_vp_commodity,
        vp_commodity_detail_choice = NULL,
        vp_filter_purpose = "comparison_type_choices"
      )
    } else {
      vp_all_choice <- "__all__"
      vp_trade_flow <- input$vp_trade_flow_choice %||% "export"
      vp_group <- input$vp_group_choice %||% vp_all_choice
      vp_subgroup <- input$vp_subgroup_choice %||% vp_all_choice
      vp_market_segment <- input$vp_market_segment_choice %||% vp_all_choice

      if (!is.null(vp_trade_flow) && "Trade" %in% names(vp_rows)) {
        vp_rows <- vp_rows[vp_rows$Trade == vp_trade_flow, , drop = FALSE]
      }
      if (!is.null(vp_group) && !identical(vp_group, vp_all_choice) && "Group" %in% names(vp_rows)) {
        vp_rows <- vp_rows[vp_rows$Group == vp_group, , drop = FALSE]
      }
      if (!is.null(vp_subgroup) && !identical(vp_subgroup, vp_all_choice) && "Subgroup" %in% names(vp_rows)) {
        vp_rows <- vp_rows[vp_rows$Subgroup == vp_subgroup, , drop = FALSE]
      }
      if (!is.null(vp_market_segment) && !identical(vp_market_segment, vp_all_choice) && "MarketSegment" %in% names(vp_rows)) {
        vp_rows <- vp_rows[vp_rows$MarketSegment == vp_market_segment, , drop = FALSE]
      }
      if (!is.null(panel_vp_commodity) && nzchar(panel_vp_commodity) && "CommodityName" %in% names(vp_rows)) {
        vp_rows <- vp_rows[vp_rows$CommodityName == panel_vp_commodity, , drop = FALSE]
      }
    }

    vp_detail_values <- if ("CommodityDetail" %in% names(vp_rows)) sort(unique(as.character(vp_rows$CommodityDetail))) else character(0)
    vp_detail_values <- vp_detail_values[!is.na(vp_detail_values) & nzchar(vp_detail_values)]
    if ("All" %in% vp_detail_values) {
      vp_detail_values <- c("All", vp_detail_values[vp_detail_values != "All"])
    }

    stats::setNames(vp_detail_values, vp_detail_values)
  }

  filtered_vp_data_for_custom_panel <- function(country_code, vp_commodity_name = NULL, commodity_detail = NULL, consumer = NULL) {
    resolved_country <- resolve_filtered_country_code(country_code)
    req(resolved_country)

    vp_rows <- if (exists("vp_trade_rows_or_empty", mode = "function")) {
      vp_trade_rows_or_empty(require_non_empty = FALSE)
    } else if (exists("rice_data_vp_trade_monthly", inherits = TRUE) && is.data.frame(rice_data_vp_trade_monthly)) {
      rice_data_vp_trade_monthly
    } else {
      data.frame()
    }
    if (nrow(vp_rows) == 0) return(data.frame())

    vp_trade_flow <- input$vp_trade_flow_choice %||% "export"
    panel_vp_commodity <- resolve_custom_comparison_vp_commodity_name(vp_commodity_name)
    panel_detail <- as.character(commodity_detail %||% input$commodity_choice %||% NA_character_)
    panel_detail <- panel_detail[!is.na(panel_detail) & nzchar(panel_detail)]
    panel_detail <- if (length(panel_detail) > 0) panel_detail[[1]] else NULL

    if (exists("filter_vp_rows_for_resolved_hierarchy", mode = "function")) {
      vp_rows <- filter_vp_rows_for_resolved_hierarchy(
        vp_rows = vp_rows,
        vp_trade_flow_choice = vp_trade_flow,
        vp_group_choice = input$vp_group_choice,
        vp_subgroup_choice = input$vp_subgroup_choice,
        vp_market_segment_choice = input$vp_market_segment_choice,
        vp_commodity_name_choice = panel_vp_commodity,
        vp_commodity_detail_choice = panel_detail,
        vp_filter_purpose = "comparison_panel_data"
      )
    } else {
      vp_all_choice <- "__all__"
      vp_group <- input$vp_group_choice %||% vp_all_choice
      vp_subgroup <- input$vp_subgroup_choice %||% vp_all_choice
      vp_market_segment <- input$vp_market_segment_choice %||% vp_all_choice

      if (!is.null(vp_trade_flow) && "Trade" %in% names(vp_rows)) {
        vp_rows <- vp_rows[vp_rows$Trade == vp_trade_flow, , drop = FALSE]
      }
      if (!is.null(vp_group) && !identical(vp_group, vp_all_choice) && "Group" %in% names(vp_rows)) {
        vp_rows <- vp_rows[vp_rows$Group == vp_group, , drop = FALSE]
      }
      if (!is.null(vp_subgroup) && !identical(vp_subgroup, vp_all_choice) && "Subgroup" %in% names(vp_rows)) {
        vp_rows <- vp_rows[vp_rows$Subgroup == vp_subgroup, , drop = FALSE]
      }
      if (!is.null(vp_market_segment) && !identical(vp_market_segment, vp_all_choice) && "MarketSegment" %in% names(vp_rows)) {
        vp_rows <- vp_rows[vp_rows$MarketSegment == vp_market_segment, , drop = FALSE]
      }
      if (!is.null(panel_vp_commodity) && nzchar(panel_vp_commodity) && "CommodityName" %in% names(vp_rows)) {
        vp_rows <- vp_rows[vp_rows$CommodityName == panel_vp_commodity, , drop = FALSE]
      }
      if (!is.null(panel_detail) && nzchar(panel_detail) && "commodity" %in% names(vp_rows)) {
        vp_rows <- vp_rows[vp_rows$commodity == panel_detail, , drop = FALSE]
      }
    }

    if (isTRUE(is_custom_country_choice_value(resolved_country))) {
      custom_country_defs <- tryCatch(custom_countries_enriched(), error = function(e) data.frame())
      vp_rows <- build_custom_country_filtered_data(
        source_df = vp_rows,
        custom_choice_value = resolved_country,
        custom_country_defs = custom_country_defs
      )
    } else {
      vp_rows <- vp_rows %>% filter(.data$country == resolved_country)
    }

    if (identical(input$data_frequency, "monthly")) {
      keep <- rep(FALSE, nrow(vp_rows))
      signal_metric_cols <- intersect(
        c("monthlyexports", "ytd_exports", "total_commitment", "monthlyvalue", "ytd_value", "unit_value", "ytd_unit_value"),
        names(vp_rows)
      )
      for (metric_col in signal_metric_cols) {
        keep <- keep | (!is.na(vp_rows[[metric_col]]) & vp_rows[[metric_col]] != 0)
      }
      vp_rows <- vp_rows[keep, , drop = FALSE]
    }

    metric_cols <- intersect(c("monthlyexports", "ytd_exports", "total_commitment", "outstandingSales", "grossNewSales", "currentMYNetSales", "nextMYOutstandingSales", "nextMYNetSales", "monthlyvalue", "ytd_value", "unit_value", "ytd_unit_value"), names(vp_rows))
    for (metric_col in metric_cols) {
      if (metric_col %in% c("unit_value", "ytd_unit_value")) {
        vp_rows[[metric_col]] <- sanitize_numeric(vp_rows[[metric_col]])
      } else if (is_census_value_metric(metric_col, source_choice = "vp_trade")) {
        vp_rows[[metric_col]] <- sanitize_numeric(value_unit_conversion(
          vp_rows[[metric_col]],
          current_census_value_unit_choice_safe(source_choice = "vp_trade", metric_code = metric_col),
          source_choice = "vp_trade",
          metric_code = metric_col
        ))
      } else if (isTRUE(vp_trade_metric_supports_quantity_units(metric_col))) {
        vp_rows[[metric_col]] <- sanitize_numeric(vp_trade_quantity_unit_conversion(
          value = vp_rows[[metric_col]],
          unit = current_unit_choice_safe(),
          volume_unit_family = if ("volume_unit_family" %in% names(vp_rows)) vp_rows$volume_unit_family else NULL,
          source_volume_unit = if ("source_volume_unit" %in% names(vp_rows)) vp_rows$source_volume_unit else NULL,
          vp_volume_family_mixed = if ("vp_volume_family_mixed" %in% names(vp_rows)) vp_rows$vp_volume_family_mixed else NULL
        ))
      } else {
        vp_rows[[metric_col]] <- sanitize_numeric(unit_conversion(
          vp_rows[[metric_col]],
          current_unit_choice_safe(),
          source_choice = "vp_trade",
          metric_code = metric_col,
          area_unit_choice = current_psd_area_unit_choice_safe(),
          basis_choice = current_basis_choice_safe(),
          value_unit_choice = current_census_value_unit_choice_safe(source_choice = "vp_trade", metric_code = metric_col),
          commodity_choice = panel_detail %||% input$commodity_choice,
          lock_context = "selected_metric"
        ))
      }
    }

    log_perf(
      "filtered_vp_data_for_custom_panel()",
      Sys.time(),
      details = list(
        consumer = as.character(consumer %||% "unknown"),
        country = resolved_country,
        vp_commodity_name = panel_vp_commodity %||% "NULL",
        commodity_detail = panel_detail %||% "NULL",
        rows = nrow(vp_rows)
      )
    )

    vp_rows
  }

  psd_canonical_country_state <- reactive({
    if (!identical(current_source_choice_safe(), "psd")) {
      return(list(
        ordered_df = data.frame(),
        share_lookup = NULL,
        metric_col = effective_main_metric()
      ))
    }

    metric_col <- effective_main_metric()
    selected_commodity <- trimws(as.character(input$commodity_choice %||% default_commodity_choice_value()))
    source_df <- build_psd_country_metric_frame(metric_col, selected_commodity)

    if (
      is.null(source_df) ||
      nrow(source_df) == 0 ||
      !nzchar(selected_commodity) ||
      !nzchar(metric_col) ||
      !(metric_col %in% names(source_df))
    ) {
      return(list(
        ordered_df = data.frame(),
        share_lookup = NULL,
        metric_col = metric_col
      ))
    }

    psd_df <- source_df %>%
      mutate(metric_value = suppressWarnings(as.numeric(.data[[metric_col]]))) %>%
      filter(is.finite(.data$metric_value))

    if (nrow(psd_df) == 0) {
      return(list(
        ordered_df = data.frame(),
        share_lookup = NULL,
        metric_col = metric_col
      ))
    }

    country_pairs <- canonicalize_psd_country_pairs(psd_df %>% select(country, countryDescription))
    recent_year <- suppressWarnings(max(psd_df$market_year, na.rm = TRUE))
    recent_df <- psd_df %>% filter(.data$market_year == recent_year)

    current_values_df <- data.frame(country = character(), current_value = numeric(), stringsAsFactors = FALSE)
    if (nrow(recent_df) > 0) {
      most_recent_period <- suppressWarnings(max(recent_df$analysis_month, na.rm = TRUE))
      recent_snapshot <- if (is.finite(most_recent_period)) {
        latest_available_snapshot_by_group(
          df = recent_df,
          group_col = "country",
          cutoff_period = most_recent_period
        )
      } else {
        recent_df
      }

      if (!is.null(recent_snapshot) && nrow(recent_snapshot) > 0) {
        current_values_df <- recent_snapshot %>%
          transmute(
            country = trimws(as.character(.data$country)),
            current_value = suppressWarnings(as.numeric(.data[[metric_col]]))
          ) %>%
          filter(!is.na(.data$country), nzchar(.data$country), is.finite(.data$current_value)) %>%
          group_by(.data$country) %>%
          summarise(current_value = dplyr::first(.data$current_value), .groups = "drop")
      }
    }

    non_world_values <- current_values_df %>%
      filter(.data$country != "GRAND_TOTAL", is.finite(.data$current_value), .data$current_value >= 0)
    total_value <- sum(non_world_values$current_value, na.rm = TRUE)

    ordered_df <- country_pairs %>%
      left_join(current_values_df, by = "country") %>%
      mutate(
        sort_group = dplyr::case_when(
          .data$country == "GRAND_TOTAL" ~ 0L,
          is.finite(.data$current_value) ~ 1L,
          TRUE ~ 2L
        ),
        sort_value = dplyr::coalesce(.data$current_value, -Inf),
        share_pct = dplyr::case_when(
          .data$country == "GRAND_TOTAL" ~ NA_real_,
          is.finite(total_value) & total_value > 0 & is.finite(.data$current_value) & .data$current_value >= 0 ~ .data$current_value / total_value,
          TRUE ~ NA_real_
        )
      ) %>%
      arrange(.data$sort_group, dplyr::desc(.data$sort_value), .data$country_label, .data$country)

    share_lookup <- ordered_df %>%
      filter(!is.na(.data$share_pct)) %>%
      {
        if (nrow(.) == 0) NULL else stats::setNames(.$share_pct, .$country)
      }

    list(
      ordered_df = ordered_df,
      share_lookup = share_lookup,
      metric_col = metric_col
    )
  }) %>% bindCache(
    current_source_choice_safe(),
    effective_main_metric(),
    input$commodity_choice,
    input$basis_choice,
    input$unit_choice,
    if (identical(current_source_choice_safe(), "census")) current_census_value_unit_choice_safe() else "n/a",
    input$psd_area_unit_choice,
    if (identical(current_source_choice_safe(), "nass")) current_nass_state_choice_safe() else "n/a",
    if (identical(current_source_choice_safe(), "nass")) current_nass_annual_year_type_safe() else "n/a"
  )

  nass_state_choice_options <- function() {
    source_df <- tryCatch(rice_data_nass_state_lookup, error = function(...) NULL)
    if (!is.data.frame(source_df) || nrow(source_df) == 0 || !("country" %in% names(source_df))) {
      return(c("U.S. Total" = "US"))
    }

    nass_state_display_label <- function(label, code = NULL) {
      label <- trimws(as.character(label %||% ""))
      code <- trimws(as.character(code %||% ""))
      if (length(label) == 0L || is.na(label[[1L]]) || !nzchar(label[[1L]])) {
        label <- code
      }

      label <- label[[1L]]
      code <- if (length(code) > 0L && !is.na(code[[1L]])) code[[1L]] else ""
      if (identical(toupper(code), "US") || toupper(label) %in% c("US TOTAL", "U.S. TOTAL", "UNITED STATES")) {
        return("U.S. Total")
      }

      if (identical(label, toupper(label))) {
        return(tools::toTitleCase(tolower(label)))
      }

      label
    }

    country_values <- trimws(as.character(source_df$country))
    label_values <- if ("countryDescription" %in% names(source_df)) {
      trimws(as.character(source_df$countryDescription))
    } else {
      country_values
    }
    is_aggregate <- if ("is_national_aggregate" %in% names(source_df)) {
      as.logical(source_df$is_national_aggregate)
    } else {
      country_values == "US"
    }
    is_aggregate[is.na(is_aggregate)] <- FALSE

    state_df <- tibble::tibble(
      country = country_values,
      label = label_values,
      is_aggregate = is_aggregate
    ) %>%
      filter(!is.na(.data$country), nzchar(.data$country)) %>%
      mutate(
        label = dplyr::if_else(is.na(.data$label) | !nzchar(.data$label), .data$country, .data$label),
        label = vapply(seq_along(.data$label), function(idx) nass_state_display_label(.data$label[[idx]], .data$country[[idx]]), character(1))
      ) %>%
      distinct(.data$country, .keep_all = TRUE) %>%
      arrange(!.data$is_aggregate, .data$label, .data$country)

    stats::setNames(state_df$country, state_df$label)
  }

  current_nass_state_choice_safe <- function(default = "US") {
    choices <- nass_state_choice_options()
    valid_values <- unname(choices)
    input_value <- tryCatch(input$nass_state_choice, error = function(...) NULL)
    input_value <- trimws(as.character(input_value %||% ""))
    input_value <- input_value[!is.na(input_value) & nzchar(input_value)]
    if (length(input_value) > 0L && input_value[[1L]] %in% valid_values) {
      return(input_value[[1L]])
    }

    if (!is.null(default) && default %in% valid_values) {
      return(default)
    }

    valid_values[[1L]]
  }

  nass_state_label_for_code <- function(country_code, default = country_code) {
    choices <- nass_state_choice_options()
    code <- trimws(as.character(country_code %||% ""))
    code <- code[!is.na(code) & nzchar(code)]
    if (length(code) == 0L) return(default)

    match_idx <- match(code[[1L]], unname(choices))
    if (!is.na(match_idx)) {
      label <- names(choices)[[match_idx]]
      if (!is.na(label) && nzchar(label)) return(label)
    }

    default
  }

  country_choice_options <- reactive({
    start_time <- Sys.time()
    req(input$commodity_choice, effective_main_metric(), input$country_sort, input$data_frequency)
    metric <- effective_main_metric()

    if (identical(current_source_choice_safe(), "nass")) {
      state_choices <- nass_state_choice_options()
      log_perf(
        "country_choice_options()",
        start_time,
        details = list(
          source = "nass",
          frequency = input$data_frequency,
          metric = metric,
          commodity = input$commodity_choice,
          choices = length(state_choices)
        )
      )
      return(state_choices)
    }

    emit_myc_country_choice_trace <- function(event, details = list()) {
      if (!identical(input$main_tabs_panel, "Market Year Comparison Tool")) return(invisible(NULL))
      if (!exists("myc_transition_trace", mode = "function")) return(invisible(NULL))

      myc_transition_trace(event, details = details)
      invisible(NULL)
    }

    collapse_trace_values <- function(values, max_items = 8L) {
      values <- unique(as.character(values %||% character(0)))
      if (length(values) == 0) return("<none>")

      values <- values[seq_len(min(length(values), max_items))]
      paste(values, collapse = " | ")
    }

    myc_country_mode_active <- identical(input$main_tabs_panel, "Market Year Comparison Tool") &&
      identical(market_year_comparison_mode(), "country")
    myc_type_mode_active <- identical(input$main_tabs_panel, "Market Year Comparison Tool") &&
      identical(market_year_comparison_mode(), "type")
    myc_active <- identical(input$main_tabs_panel, "Market Year Comparison Tool")
    effective_country_sort <- if (isTRUE(myc_type_mode_active)) {
      NULL
    } else {
      dplyr::case_when(
        identical(input$country_sort, "alphabetical") ~ "alpha",
        TRUE ~ input$country_sort
      )
    }

    country_choice_counter_recorded <- FALSE
    record_country_choice_counter <- function(sorted_countries = NULL,
                                              branch = effective_country_sort %||% "unknown",
                                              country_choice_data_source = "unknown",
                                              input_rows = NA_integer_,
                                              expensive_rank_work = FALSE,
                                              country_data_elapsed_ms = NA_integer_) {
      if (isTRUE(country_choice_counter_recorded)) return(invisible(NULL))
      country_choice_counter_recorded <<- TRUE

      record_cache_body_execution(
        session,
        "country_choice_options",
        details = list(
          source = if (!is.null(input$data_source_choice)) input$data_source_choice else "export_sales",
          frequency = input$data_frequency,
          metric = metric,
          commodity = input$commodity_choice,
          sort = input$country_sort,
          branch = branch,
          myc_country_mode = isTRUE(myc_country_mode_active),
          myc_type_mode = isTRUE(myc_type_mode_active),
          reverse = isTRUE(input$reverse_sort),
          top_filter = if (isTRUE(input$top5_only)) "top5" else if (isTRUE(input$top10_only)) "top10" else "none",
          rank_basis = country_choice_data_source,
          country_choice_data_source = country_choice_data_source,
          input_rows = input_rows,
          choices = length(sorted_countries %||% character(0)),
          expensive_rank_work = isTRUE(expensive_rank_work),
          country_data_elapsed_ms = country_data_elapsed_ms
        )
      )
    }

    custom_country_choice_bundle <- NULL
    get_custom_country_choice_bundle <- function() {
      if (!is.null(custom_country_choice_bundle)) {
        return(custom_country_choice_bundle)
      }

      valid_custom_country_defs <- tryCatch(
        custom_countries_enriched() %>% filter(.data$parse_ok),
        error = function(e) data.frame()
      )
      custom_country_choices <- build_psd_custom_country_choice_vector(valid_custom_country_defs)
      custom_country_choice_bundle <<- list(defs = valid_custom_country_defs, choices = custom_country_choices)
      custom_country_choice_bundle
    }

    append_custom_country_choices <- function(country_choices, custom_choices) {
      if (is.null(country_choices) || length(country_choices) == 0) {
        return(custom_choices)
      }
      if (is.null(custom_choices) || length(custom_choices) == 0) {
        return(country_choices)
      }

      country_values <- unname(country_choices)
      custom_values <- unname(custom_choices)
      keep_idx <- !(custom_values %in% country_values)
      custom_to_add <- custom_choices[keep_idx]

      if (length(custom_to_add) == 0) {
        return(country_choices)
      }

      c(country_choices, custom_to_add)
    }

    if (identical(current_source_choice_safe(), "psd")) {
      psd_state <- psd_canonical_country_state()
      sorted_countries <- build_psd_country_choice_vector(
        ordered_df = psd_state$ordered_df,
        share_lookup = psd_state$share_lookup,
        metric_code = metric
      )
      custom_country_bundle <- get_custom_country_choice_bundle()
      sorted_countries <- append_custom_country_choices(sorted_countries, custom_country_bundle$choices)

      record_country_choice_counter(
        sorted_countries = sorted_countries,
        branch = "psd_canonical",
        country_choice_data_source = "psd_canonical_plus_custom",
        input_rows = nrow(psd_state$ordered_df) + nrow(custom_country_bundle$defs),
        expensive_rank_work = FALSE,
        country_data_elapsed_ms = 0L
      )

      log_perf(
        "country_choice_options()",
        start_time,
        details = c(
          source_switch_epoch_fields(include_age = TRUE),
          list(
          source = "psd",
          frequency = input$data_frequency,
          commodity = input$commodity_choice,
          metric = metric,
          sort = "psd_canonical",
          custom_country_defs = nrow(custom_country_bundle$defs),
          custom_country_choices = length(custom_country_bundle$choices),
          myc_country_mode = FALSE,
          reverse = FALSE,
          top_filter = "none",
          input_rows = nrow(psd_state$ordered_df) + nrow(custom_country_bundle$defs),
          choices = length(sorted_countries),
          expensive_rank_work = FALSE,
          selected_data_elapsed_ms = 0L
          )
        )
      )

      return(sorted_countries)
    }

    if (identical(current_source_choice_safe(), "wasde")) {
      active_country_display_names <- country_display_names_for_frequency()
      if (is.null(active_country_display_names) || length(active_country_display_names) == 0) {
        active_country_display_names <- country_display_names
      }

      sorted_countries <- resolve_wasde_country_choice_vector(active_country_display_names)
      custom_country_bundle <- get_custom_country_choice_bundle()
      sorted_countries <- append_custom_country_choices(sorted_countries, custom_country_bundle$choices)

      record_country_choice_counter(
        sorted_countries = sorted_countries,
        branch = "wasde_fixed_us",
        country_choice_data_source = "wasde_canonical_plus_custom",
        input_rows = length(active_country_display_names) + nrow(custom_country_bundle$defs),
        expensive_rank_work = FALSE,
        country_data_elapsed_ms = 0L
      )

      log_perf(
        "country_choice_options()",
        start_time,
        details = c(
          source_switch_epoch_fields(include_age = TRUE),
          list(
            source = "wasde",
            frequency = input$data_frequency,
            commodity = input$commodity_choice,
            metric = metric,
            sort = "wasde_fixed_us",
            custom_country_defs = nrow(custom_country_bundle$defs),
            custom_country_choices = length(custom_country_bundle$choices),
            myc_country_mode = isTRUE(myc_country_mode_active),
            reverse = FALSE,
            top_filter = "none",
            input_rows = length(active_country_display_names) + nrow(custom_country_bundle$defs),
            choices = length(sorted_countries),
            expensive_rank_work = FALSE,
            country_choice_data_source = "wasde_canonical_plus_custom",
            country_data_elapsed_ms = 0L,
            selected_data_elapsed_ms = 0L
          )
        )
      )

      return(sorted_countries)
    }

    active_country_display_names <- country_display_names_for_frequency()
    if (is.null(active_country_display_names) || length(active_country_display_names) == 0) {
      active_country_display_names <- country_display_names
    }

    get_country_label <- function(country_code) {
      label <- names(active_country_display_names)[active_country_display_names == country_code]
      if (length(label) > 0 && !is.na(label[1]) && nzchar(label[1])) return(label[1])

      fallback <- names(country_display_names)[country_display_names == country_code]
      if (length(fallback) > 0 && !is.na(fallback[1]) && nzchar(fallback[1])) return(fallback[1])

      country_code
    }

    should_show_country_share_suffix <- function(metric_code = metric) {
      !is_psd_non_share_metric(
        metric_code = metric_code %||% NULL,
        source_choice = input$data_source_choice %||% "export_sales"
      )
    }

    build_country_choice_label <- function(country_code, share_lookup = NULL, metric_code = metric) {
      base_label <- get_country_label(country_code)
      if (identical(current_source_choice_safe(), "census")) {
        base_label <- strip_app_ui_census_country_code_prefix(base_label)
      }

      if (
        is.na(base_label) ||
          identical(country_code, "GRAND_TOTAL") ||
          !isTRUE(should_show_country_share_suffix(metric_code)) ||
          is.null(share_lookup) ||
          !(country_code %in% names(share_lookup))
      ) {
        return(base_label)
      }

      share_val <- unname(share_lookup[country_code])
      if (length(share_val) == 0 || is.na(share_val)) {
        return(base_label)
      }

      paste0(base_label, " (", sprintf("%.1f%%", share_val * 100), ")")
    }

    add_share_labels_to_country_choices <- function(country_choices, share_lookup = NULL) {
      if (is.null(country_choices) || length(country_choices) == 0) {
        return(country_choices)
      }

      country_codes <- unname(country_choices)

      stats::setNames(
        country_codes,
        vapply(country_codes, function(country_code) {
          build_country_choice_label(country_code, share_lookup = share_lookup, metric_code = metric)
        }, character(1))
      )
    }

    build_alphabetical_country_choices <- function(country_choices = active_country_display_names) {
      grand_total_idx <- which(country_choices == "GRAND_TOTAL")
      grand_total_choice <- if (length(grand_total_idx) > 0) {
        country_choices[grand_total_idx[[1]]]
      } else {
        stats::setNames("GRAND_TOTAL", "World")
      }
      other_countries <- country_choices[country_choices != "GRAND_TOTAL"]

      c(grand_total_choice, other_countries)
    }

    apply_myc_country_choice_filter <- function(sorted_countries) {
      if (!isTRUE(myc_country_mode_active)) {
        return(sorted_countries)
      }

      filtered_countries <- sorted_countries[unname(sorted_countries) != "GRAND_TOTAL"]
      if (length(filtered_countries) == 0) {
        filtered_countries <- active_country_display_names[active_country_display_names != "GRAND_TOTAL"]
      }

      filtered_countries
    }

    if (
      identical(effective_country_sort, "alpha") &&
        !isTRUE(myc_type_mode_active) &&
        !isTRUE(input$top5_only) &&
        !isTRUE(input$top10_only)
    ) {
      sorted_countries <- apply_myc_country_choice_filter(build_alphabetical_country_choices())
      custom_country_bundle <- get_custom_country_choice_bundle()
      sorted_countries <- append_custom_country_choices(sorted_countries, custom_country_bundle$choices)

      record_country_choice_counter(
        sorted_countries = sorted_countries,
        branch = "metadata_alpha",
        country_choice_data_source = "metadata",
        input_rows = nrow(custom_country_bundle$defs),
        expensive_rank_work = FALSE,
        country_data_elapsed_ms = 0L
      )

      emit_myc_country_choice_trace(
        "country_choice_options_result",
        details = list(
          comparison_mode = market_year_comparison_mode(),
          commodity = input$commodity_choice,
          country_basis_commodity = input$commodity_choice,
          effective_country_sort = effective_country_sort %||% "<null>",
          selected_country = input$country_choice %||% "<null>",
          choice_count = length(sorted_countries %||% character(0)),
          choice_sample = collapse_trace_values(unname(sorted_countries %||% character(0))),
          label_sample = collapse_trace_values(names(sorted_countries %||% character(0))),
          top_filter_active = FALSE,
          top_filter_sample = "<none>"
        )
      )

      log_perf(
        "country_choice_options()",
        start_time,
        details = c(
          source_switch_epoch_fields(include_age = TRUE),
          list(
          source = if (!is.null(input$data_source_choice)) input$data_source_choice else "export_sales",
          frequency = input$data_frequency,
          commodity = input$commodity_choice,
          metric = metric,
          sort = input$country_sort,
          myc_country_mode = isTRUE(myc_country_mode_active),
          reverse = isTRUE(input$reverse_sort),
          top_filter = "none",
          input_rows = 0L,
          choices = length(sorted_countries),
          expensive_rank_work = FALSE,
          country_choice_data_source = "metadata",
          country_data_elapsed_ms = 0L,
          selected_data_elapsed_ms = 0L
          )
        )
      )

      return(sorted_countries)
    }

    # Use a source-appropriate aggregate type as the country-share basis only in MYC type mode.
    country_basis_commodity <- if (isTRUE(myc_type_mode_active)) {
      if (identical(active_source_choice(), "vp_trade")) "All" else "All Rice"
    } else {
      input$commodity_choice
    }
    country_data_start_time <- Sys.time()
    country_basis_is_native <- country_basis_commodity %in% active_native_commodities()
    country_choice_data_source <- if (isTRUE(country_basis_is_native)) "base_data_converted" else "selected_data"
    selected_df <- if (isTRUE(country_basis_is_native)) {
      base_data_converted()
    } else {
      record_cache_body_execution(session, "selected_data_read_country_choice_options", details = list(source = input$data_source_choice %||% "export_sales", commodity = country_basis_commodity, metric = metric))
      selected_data()
    }
    country_data_elapsed_ms <- perf_elapsed_ms(country_data_start_time)
    df <- selected_df %>%
      filter(.data$commodity == country_basis_commodity)

    if (isTRUE(myc_type_mode_active) && nrow(df) == 0 && !identical(country_basis_commodity, input$commodity_choice)) {
      df <- selected_df %>%
        filter(.data$commodity == input$commodity_choice)
    }

    country_snapshot_mode_for_metric <- function(metric_col) {
      if (metric_col %in% projection_metric_choices_for_source()) {
        return("latest_available_by_country")
      }

      "exact_period"
    }

    build_non_myc_country_snapshot <- function(recent_data, metric_col, most_recent_period, metric_sensitive = FALSE) {
      snapshot_mode <- if (isTRUE(metric_sensitive)) {
        country_snapshot_mode_for_metric(metric_col)
      } else {
        "exact_period"
      }

      if (identical(snapshot_mode, "latest_available_by_country")) {
        return(latest_available_snapshot_by_group(
          df = recent_data,
          group_col = "country",
          cutoff_period = most_recent_period
        ))
      }

      recent_data %>% filter(.data$analysis_month == most_recent_period)
    }
    
    build_current_country_values <- function(metric_col, metric_sensitive = FALSE) {
      recent_year <- suppressWarnings(max(df$market_year, na.rm = TRUE))
      recent_data <- df %>%
        filter(.data$market_year == recent_year) %>%
        filter(.data$country != "GRAND_TOTAL")

      if (nrow(recent_data) == 0) {
        return(data.frame(country = character(), current_value = numeric(), stringsAsFactors = FALSE))
      }

      most_recent_period <- max(recent_data$analysis_month, na.rm = TRUE)

      current_snapshot <- if (isTRUE(myc_country_mode_active)) {
        latest_available_snapshot_by_group(
          df = recent_data,
          group_col = "country",
          cutoff_period = most_recent_period
        )
      } else {
        build_non_myc_country_snapshot(
          recent_data = recent_data,
          metric_col = metric_col,
          most_recent_period = most_recent_period,
          metric_sensitive = metric_sensitive
        )
      }

      if (nrow(current_snapshot) == 0) {
        return(data.frame(country = character(), current_value = numeric(), stringsAsFactors = FALSE))
      }

      current_snapshot %>%
        select(country, current_value = all_of(metric_col)) %>%
        filter(!is.na(.data$current_value), .data$current_value > 0) %>%
        group_by(.data$country) %>%
        summarise(current_value = sum(.data$current_value, na.rm = TRUE), .groups = "drop")
    }

    build_country_share_denominator <- function(metric_col, metric_sensitive = FALSE) {
      recent_year <- suppressWarnings(max(df$market_year, na.rm = TRUE))
      recent_data <- df %>%
        filter(.data$market_year == recent_year)

      if (nrow(recent_data) == 0) {
        return(NA_real_)
      }

      most_recent_period <- max(recent_data$analysis_month, na.rm = TRUE)
      current_snapshot <- if (isTRUE(myc_country_mode_active)) {
        latest_available_snapshot_by_group(
          df = recent_data,
          group_col = "country",
          cutoff_period = most_recent_period
        )
      } else {
        build_non_myc_country_snapshot(
          recent_data = recent_data,
          metric_col = metric_col,
          most_recent_period = most_recent_period,
          metric_sensitive = metric_sensitive
        )
      }

      if (nrow(current_snapshot) == 0 || !(metric_col %in% names(current_snapshot))) {
        return(NA_real_)
      }

      snapshot_values <- current_snapshot %>%
        select(country, current_value = all_of(metric_col)) %>%
        mutate(current_value = suppressWarnings(as.numeric(.data$current_value))) %>%
        filter(!is.na(.data$country), nzchar(.data$country), is.finite(.data$current_value), .data$current_value > 0) %>%
        group_by(.data$country) %>%
        summarise(current_value = sum(.data$current_value, na.rm = TRUE), .groups = "drop")

      world_value <- snapshot_values %>%
        filter(.data$country == "GRAND_TOTAL") %>%
        summarise(current_value = sum(.data$current_value, na.rm = TRUE), .groups = "drop") %>%
        pull(.data$current_value)
      if (length(world_value) > 0L && is.finite(world_value[[1L]]) && world_value[[1L]] > 0) {
        return(world_value[[1L]])
      }

      fallback_value <- snapshot_values %>%
        filter(.data$country != "GRAND_TOTAL") %>%
        summarise(current_value = sum(.data$current_value, na.rm = TRUE), .groups = "drop") %>%
        pull(.data$current_value)
      if (length(fallback_value) > 0L && is.finite(fallback_value[[1L]]) && fallback_value[[1L]] > 0) {
        return(fallback_value[[1L]])
      }

      NA_real_
    }

    build_country_share_lookup <- function(metric_col = "ytd_exports", metric_sensitive = FALSE) {
      current_vals <- build_current_country_values(metric_col, metric_sensitive = metric_sensitive)
      if (nrow(current_vals) == 0) {
        return(NULL)
      }

      share_denominator <- build_country_share_denominator(metric_col, metric_sensitive = metric_sensitive)
      if (!is.finite(share_denominator) || share_denominator <= 0) {
        return(NULL)
      }

      current_vals %>%
        mutate(share_pct = .data$current_value / share_denominator) %>%
        filter(!is.na(.data$share_pct)) %>%
        {
          stats::setNames(.$share_pct, .$country)
        }
    }

    value_sort_membership_metric_for <- function(metric_col) {
      if (isTRUE(myc_country_mode_active)) {
        return(NULL)
      }

      if (identical(metric_col, "monthlyexports") && "ytd_exports" %in% names(df)) {
        return("ytd_exports")
      }

      if (identical(metric_col, "monthlyvalue") && "ytd_value" %in% names(df)) {
        return("ytd_value")
      }

      NULL
    }

    build_value_sort_membership_codes <- function(metric_col) {
      membership_metric <- value_sort_membership_metric_for(metric_col)
      if (is.null(membership_metric)) {
        return(NULL)
      }

      membership_values <- build_current_country_values(membership_metric, metric_sensitive = TRUE)
      if (nrow(membership_values) == 0) {
        return(character(0))
      }

      available_non_grand <- unname(available_countries[available_countries != "GRAND_TOTAL"])
      membership_values %>%
        arrange(dplyr::desc(.data$current_value), .data$country) %>%
        pull(.data$country) %>%
        {
          unique(.[. %in% available_non_grand])
        }
    }

    build_value_sort_country_codes <- function(country_values, metric_col) {
      grand_total_code <- if ("GRAND_TOTAL" %in% unname(available_countries)) "GRAND_TOTAL" else character(0)
      available_non_grand <- unname(available_countries[available_countries != "GRAND_TOTAL"])
      ranked_codes <- if (!is.null(country_values) && nrow(country_values) > 0) {
        country_values %>%
          filter(.data$country != "GRAND_TOTAL") %>%
          pull(.data$country)
      } else {
        character(0)
      }
      membership_codes <- build_value_sort_membership_codes(metric_col)

      if (length(ranked_codes) == 0 && is.null(membership_codes)) {
        return(NULL)
      }

      unique(c(
        grand_total_code,
        ranked_codes[ranked_codes %in% available_non_grand],
        membership_codes[membership_codes %in% available_non_grand]
      ))
    }

    myc_type_country_share_lookup <- if (isTRUE(myc_type_mode_active)) {
      build_country_share_lookup("ytd_exports")
    } else {
      NULL
    }

    # Determine top partners filter (if enabled)
    top_countries <- NULL
    if (!isTRUE(myc_active) && nrow(df) > 0 && (isTRUE(input$top5_only) || isTRUE(input$top10_only))) {
      top_n <- if (isTRUE(input$top5_only)) 5 else 10  # top5 takes precedence

      top_country_values <- build_current_country_values("ytd_exports", metric_sensitive = TRUE)
      if (nrow(top_country_values) > 0) {
        top_countries <- top_country_values %>%
          arrange(dplyr::desc(.data$current_value), .data$country) %>%
          head(top_n) %>%
          dplyr::pull(.data$country)

        # Always include GRAND_TOTAL
        top_countries <- c("GRAND_TOTAL", top_countries)
      }
    }
    
    # Filter country_display_names if top filter is active
    available_countries <- if (!is.null(top_countries)) {
      active_country_display_names[active_country_display_names %in% top_countries]
    } else {
      active_country_display_names
    }

    build_type_mode_country_choices <- function(country_values, share_lookup = NULL) {
      grand_total_code <- if ("GRAND_TOTAL" %in% unname(available_countries)) "GRAND_TOTAL" else character(0)
      available_non_grand <- unname(available_countries[available_countries != "GRAND_TOTAL"])
      ranked_codes <- if (!is.null(country_values) && nrow(country_values) > 0) {
        country_values %>%
          arrange(dplyr::desc(.data$current_value), .data$country) %>%
          pull(.data$country)
      } else {
        character(0)
      }

      sorted_country_codes <- unique(c(
        grand_total_code,
        ranked_codes[ranked_codes %in% available_non_grand],
        available_non_grand
      ))

      add_share_labels_to_country_choices(
        stats::setNames(sorted_country_codes, sorted_country_codes),
        share_lookup
      )
    }

    myc_type_sorted_countries <- if (isTRUE(myc_type_mode_active)) {
      type_country_values <- build_current_country_values("ytd_exports")
      if (!is.null(top_countries) && nrow(type_country_values) > 0) {
        type_country_values <- type_country_values %>%
          filter(.data$country %in% top_countries)
      }

      emit_myc_country_choice_trace(
        "country_choice_type_ranking",
        details = list(
          commodity = input$commodity_choice,
          country_basis_commodity = country_basis_commodity,
          metric = metric,
          df_rows = nrow(df),
          ranked_country_count = nrow(type_country_values),
          ranked_country_sample = collapse_trace_values(type_country_values$country),
          ranked_value_sample = collapse_trace_values(type_country_values$current_value),
          share_lookup_sample = collapse_trace_values(
            if (is.null(myc_type_country_share_lookup)) character(0) else {
              sprintf(
                "%s=%.3f",
                names(myc_type_country_share_lookup)[seq_len(min(length(myc_type_country_share_lookup), 5L))],
                unname(myc_type_country_share_lookup[seq_len(min(length(myc_type_country_share_lookup), 5L))])
              )
            }
          ),
          top_filter_active = !is.null(top_countries),
          top_filter_sample = collapse_trace_values(top_countries)
        )
      )

      build_type_mode_country_choices(type_country_values, myc_type_country_share_lookup)
    } else {
      NULL
    }
    
    if (nrow(df) == 0) {
      # Fallback to alphabetical if no data
      # Put GRAND_TOTAL first, then alphabetical
      grand_total_name <- names(available_countries)[available_countries == "GRAND_TOTAL"]
      other_countries <- available_countries[available_countries != "GRAND_TOTAL"]
      sorted_countries <- c(
        setNames("GRAND_TOTAL", grand_total_name),
        other_countries
      )
      if (isTRUE(myc_type_mode_active)) {
        sorted_countries <- add_share_labels_to_country_choices(sorted_countries, myc_type_country_share_lookup)
      }
    } else if (isTRUE(myc_type_mode_active)) {
      sorted_countries <- myc_type_sorted_countries
    } else if (effective_country_sort == "alpha") {
      # Alphabetical sorting with GRAND_TOTAL first
      grand_total_name <- names(available_countries)[available_countries == "GRAND_TOTAL"]
      other_countries <- available_countries[available_countries != "GRAND_TOTAL"]
      sorted_countries <- c(
        setNames("GRAND_TOTAL", grand_total_name),
        other_countries
      )
      if (isTRUE(myc_type_mode_active)) {
        sorted_countries <- add_share_labels_to_country_choices(sorted_countries, myc_type_country_share_lookup)
      }
    } else if (effective_country_sort == "value") {
      # Sort by current metric value using the MYC snapshot rule only in MYC country mode.
      share_lookup <- build_country_share_lookup(metric, metric_sensitive = !isTRUE(myc_country_mode_active))

      current_vals <- build_current_country_values(metric, metric_sensitive = !isTRUE(myc_country_mode_active))
      if (nrow(current_vals) > 0) {
        current_vals <- if (isTRUE(input$reverse_sort)) {
          current_vals %>% arrange(.data$current_value, .data$country)
        } else {
          current_vals %>% arrange(dplyr::desc(.data$current_value), .data$country)
        }

        if (!is.null(top_countries)) {
          current_vals <- current_vals %>% filter(.data$country %in% top_countries)
        }
      }

      sorted_country_codes <- build_value_sort_country_codes(current_vals, metric)

      if (is.null(sorted_country_codes) || length(sorted_country_codes) == 0) {
        sorted_countries <- available_countries
      } else {
        sorted_countries <- setNames(
          sorted_country_codes,
          sapply(sorted_country_codes, function(country_code) {
            build_country_choice_label(country_code, share_lookup = share_lookup, metric_code = metric)
          })
        )
      }
    } else if (effective_country_sort == "pct_diff") {
      # Sort by % difference from historical average
      recent_year <- suppressWarnings(max(df$market_year, na.rm = TRUE))
      
      # Calculate most recent period with data
      recent_data <- df %>%
        filter(market_year == recent_year)
      
      if (nrow(recent_data) == 0) {
        sorted_countries <- active_country_display_names
      } else {
        most_recent_period <- max(recent_data$analysis_month, na.rm = TRUE)
        
        # Get historical average
        hist_window <- comparison_hist_years_committed()
        hist_years_vec <- historical_years_for_window(df$market_year, recent_year, hist_window)
        basis_mode <- input$projection_basis_mode
        ref_year <- input$projection_reference_year
          
        hist_avg_base <- if (identical(basis_mode, "single_year") && !is.null(ref_year)) {
          df %>% filter(market_year == as.numeric(ref_year))
        } else {
          df %>% filter(market_year %in% hist_years_vec)
        }

        hist_avg <- hist_avg_base %>%
          group_by(country, analysis_month) %>%
          summarise(avg_value = mean(.data[[metric]], na.rm = TRUE), .groups = "drop") %>%
          filter(analysis_month == most_recent_period)
        
        # Get current values
        current_vals <- recent_data %>%
          filter(analysis_month == most_recent_period) %>%
          select(country, current_value = all_of(metric))
        
        # Calculate % difference (signed, not absolute)
        country_scores <- current_vals %>%
          left_join(hist_avg, by = "country") %>%
          mutate(
            pct_diff = if_else(avg_value != 0 & !is.na(avg_value), 
                              (current_value - avg_value) / avg_value * 100, 
                              0)
          )
        
        # Sort based on reverse_sort checkbox
        if (isTRUE(input$reverse_sort)) {
          country_scores <- country_scores %>% arrange(pct_diff)  # Lowest first
        } else {
          country_scores <- country_scores %>% arrange(desc(pct_diff))  # Highest first
        }
        
        # Filter to top countries if applicable
        if (!is.null(top_countries)) {
          country_scores <- country_scores %>% filter(country %in% top_countries)
        }
        
        # Build sorted country list (GRAND_TOTAL first, then sorted)
        sorted_country_codes <- c(
          "GRAND_TOTAL",
          country_scores %>% filter(country != "GRAND_TOTAL") %>% pull(country)
        )
        
        # Map to display names with percentage differences
        sorted_countries <- setNames(
          sorted_country_codes,
          sapply(sorted_country_codes, function(c) {
            base_name <- get_country_label(c)
            if (c == "GRAND_TOTAL") {
              return(base_name)
            }
            # Get the pct_diff for this country
            country_pct <- country_scores %>% filter(country == c) %>% pull(pct_diff)
            if (length(country_pct) > 0 && !is.na(country_pct[1])) {
              sprintf("%s (%+.0f%%)", base_name, country_pct[1])
            } else {
              base_name
            }
          })
        )
      }
    } else if (effective_country_sort == "proj_diff") {
      # Sort by % difference between year-end projection and historical average
      # Projection type determined by input$proj_sort_type (historical or linear)
      # Only meaningful for cumulative metrics
      cumulative_metrics <- projection_metric_choices_for_source()
      use_linear <- isTRUE(input$proj_sort_type == "linear")
      
      if (!(metric %in% cumulative_metrics)) {
        # Fall back to alphabetical for non-cumulative metrics
        sorted_countries <- active_country_display_names[order(names(active_country_display_names))]
      } else {
        recent_year <- suppressWarnings(max(df$market_year, na.rm = TRUE))
        hist_window <- comparison_hist_years_committed()
        hist_years_vec <- historical_years_for_window(df$market_year, recent_year, hist_window)
        basis_mode <- input$projection_basis_mode
        ref_year <- input$projection_reference_year
        apply_country_projection_floor <- function(projected_value, current_value) {
          if (!(metric %in% cumulative_metrics)) return(projected_value)
          if (!is.finite(projected_value) || is.na(projected_value)) return(projected_value)
          if (!is.finite(current_value) || is.na(current_value)) return(projected_value)
          max(projected_value, current_value)
        }

        # Calculate projection and historical avg for each country
        all_countries <- unique(df$country)
        all_countries <- all_countries[all_countries != "GRAND_TOTAL"]
        
        # Split dataframe by country once to avoid N filter operations
        df_by_country <- split(df, df$country)

        country_scores <- lapply(all_countries, function(cty) {
          cty_df <- df_by_country[[cty]]
          if (is.null(cty_df) || nrow(cty_df) == 0) return(NULL)

          cty_current_with_value <- cty_df %>%
            filter(market_year == recent_year, !is.na(.data[[metric]]))
          if (nrow(cty_current_with_value) == 0) return(NULL)

          cty_current_period <- suppressWarnings(max(cty_current_with_value$analysis_month, na.rm = TRUE))
          if (!is.finite(cty_current_period)) return(NULL)

          cty_current_row <- cty_current_with_value %>%
            filter(analysis_month == cty_current_period)
          if (nrow(cty_current_row) == 0) return(NULL)

          cty_current_value <- sum(cty_current_row[[metric]], na.rm = TRUE)
          if (is.na(cty_current_value) || cty_current_value <= 0) return(NULL)

          # Determine total_periods PER COUNTRY - project to LAST week with historical data
          cty_hist_years_vec <- historical_years_for_window(cty_df$market_year, recent_year, hist_window)
          if (input$data_frequency == "monthly") {
            if (metric == "total_commitment") {
              cty_total_periods <- 11  # June
            } else {
              cty_total_periods <- 12  # July
            }
          } else {
            # For weekly, project to the last week with historical data in the hist_years window
            cty_hist_weeks_base <- if (identical(basis_mode, "single_year") && !is.null(ref_year)) {
              cty_df %>% filter(market_year == as.numeric(ref_year))
            } else {
              cty_df %>% filter(market_year %in% cty_hist_years_vec)
            }
            cty_hist_weeks <- cty_hist_weeks_base %>%
              pull(analysis_month) %>%
              unique()
            if (length(cty_hist_weeks) == 0) {
              return(NULL)  # No historical data for this country
            }
            cty_total_periods <- max(cty_hist_weeks, na.rm = TRUE)
          }
          
          # Calculate projection based on selected type
          if (use_linear) {
            # LINEAR FIT PROJECTION
            # Get current period data FOR THIS COUNTRY for linear fit
            cty_current_data <- cty_current_with_value
            
            if (nrow(cty_current_data) < 2) return(NULL)  # Need at least 2 points for linear fit
            
            # Get the first data point for this country
            first_point <- cty_current_data %>%
              filter(analysis_month == min(analysis_month))
            x_1 <- first_point$analysis_month[1]
            y_1 <- first_point[[metric]][1]
            
            # Fit linear model constrained to pass through first point
            # Transform: (y - y_1) ~ 0 + (x - x_1)
            cty_current_data <- cty_current_data %>%
              mutate(
                y_shifted = .data[[metric]] - y_1,
                x_shifted = analysis_month - x_1
              )
            
            fit <- lm(y_shifted ~ 0 + x_shifted, data = cty_current_data)
            slope <- coef(fit)[1]
            intercept <- y_1 - slope * x_1
            
            # Calculate linear projection: slope * total_periods + intercept
            cty_projection <- slope * cty_total_periods + intercept
            cty_projection <- max(cty_projection, 0)  # Ensure non-negative
            cty_projection <- apply_country_projection_floor(cty_projection, cty_current_value)
          } else {
            # HISTORICAL PATTERN PROJECTION
            # Get ALL historical years for projection (same as projection_data())
            cty_hist_all_years <- if (identical(basis_mode, "single_year") && !is.null(ref_year)) {
              cty_df %>% filter(market_year == as.numeric(ref_year))
            } else {
              cty_df %>% filter(market_year %in% cty_hist_years_vec)
            }
            cty_hist_complete <- cty_hist_all_years %>%
              group_by(market_year) %>%
              filter({
                valid_periods <- analysis_month[!is.na(analysis_month)]
                if (length(valid_periods) > 0) {
                  max(valid_periods) >= cty_total_periods - 1
                } else {
                  FALSE
                }
              }) %>%
              ungroup()
            
            # Calculate year-end projection using complete years (same as projection_data())
            if (nrow(cty_hist_complete) == 0) {
              cty_projection <- cty_current_value * (cty_total_periods / cty_current_period)
            } else {
              cty_final_values <- cty_hist_complete %>%
                filter(analysis_month == cty_total_periods, !is.na(.data[[metric]])) %>%
                group_by(market_year) %>%
                summarise(final_value = (sum(.data[[metric]], na.rm = TRUE) * (NA_real_ ^ (sum(!is.na(.data[[metric]])) == 0))), .groups = "drop")

              if (nrow(cty_final_values) == 0) {
                cty_projection <- cty_current_value * (cty_total_periods / cty_current_period)
              } else {
                cty_hist_at_period <- cty_hist_complete %>%
                  filter(analysis_month == cty_current_period, !is.na(.data[[metric]])) %>%
                  group_by(market_year) %>%
                  summarise(value_at_period = (sum(.data[[metric]], na.rm = TRUE) * (NA_real_ ^ (sum(!is.na(.data[[metric]])) == 0))), .groups = "drop") %>%
                  inner_join(cty_final_values, by = "market_year") %>%
                  mutate(pct_complete = value_at_period / final_value)
                
                cty_avg_pct <- mean(cty_hist_at_period$pct_complete, na.rm = TRUE)
                
                if (is.na(cty_avg_pct) || cty_avg_pct == 0) {
                  cty_projection <- cty_current_value * (cty_total_periods / cty_current_period)
                } else {
                  cty_projection <- cty_current_value / cty_avg_pct
                }
              }
            }
            cty_projection <- apply_country_projection_floor(cty_projection, cty_current_value)
          }
          
          # Calculate historical average using ONLY hist_years window at cty_total_periods
          # (same as historical_avg() reactive used in Summary Statistics)
          cty_hist_window <- if (identical(basis_mode, "single_year") && !is.null(ref_year)) {
            cty_df %>% filter(market_year == as.numeric(ref_year))
          } else {
            cty_df %>% filter(market_year %in% cty_hist_years_vec)
          }

          hist_final_values <- cty_hist_window %>%
            filter(analysis_month == cty_total_periods, !is.na(.data[[metric]])) %>%
            pull(.data[[metric]])
          
          if (length(hist_final_values) == 0) {
            hist_avg <- NA
          } else {
            hist_avg <- mean(hist_final_values, na.rm = TRUE)
          }
          
          # Calculate % difference
          if (is.na(hist_avg) || hist_avg == 0) {
            pct_diff <- NA
          } else {
            pct_diff <- (cty_projection - hist_avg) / hist_avg * 100
          }
          
          data.frame(country = cty, projection = cty_projection, hist_avg = hist_avg, pct_diff = pct_diff)
        })
        
        country_scores <- do.call(rbind, country_scores)
        
        if (is.null(country_scores) || nrow(country_scores) == 0) {
          sorted_countries <- active_country_display_names
        } else {
          # Sort based on reverse_sort checkbox
          if (isTRUE(input$reverse_sort)) {
            country_scores <- country_scores %>% arrange(pct_diff)  # Lowest first (biggest decrease from avg)
          } else {
            country_scores <- country_scores %>% arrange(desc(pct_diff))  # Highest first (biggest increase from avg)
          }
          
          # Filter to top countries if applicable
          if (!is.null(top_countries)) {
            country_scores <- country_scores %>% filter(country %in% top_countries)
          }
          
          # Build sorted country list with percentage differences in names
          sorted_country_codes <- c(
            "GRAND_TOTAL",
            country_scores %>% filter(country != "GRAND_TOTAL") %>% pull(country)
          )
          
          sorted_countries <- setNames(
            sorted_country_codes,
            sapply(sorted_country_codes, function(c) {
              base_name <- get_country_label(c)
              if (c == "GRAND_TOTAL") {
                return(base_name)
              }
              # Get the pct_diff for this country
              country_pct <- country_scores %>% filter(country == c) %>% pull(pct_diff)
              if (length(country_pct) > 0 && !is.na(country_pct[1])) {
                sprintf("%s (%+.0f%%)", base_name, country_pct[1])
              } else {
                base_name
              }
            })
          )
        }
      }
    }
    
    if (isTRUE(myc_country_mode_active)) {
      sorted_countries <- sorted_countries[unname(sorted_countries) != "GRAND_TOTAL"]

      if (length(sorted_countries) == 0) {
        sorted_countries <- active_country_display_names[active_country_display_names != "GRAND_TOTAL"]
      }
    }

    if (
      identical(current_source_choice_safe(), "census") &&
        !isTRUE(myc_country_mode_active) &&
        !("GRAND_TOTAL" %in% unname(sorted_countries %||% character(0))) &&
        "GRAND_TOTAL" %in% unname(active_country_display_names %||% character(0))
    ) {
      world_label <- names(active_country_display_names)[unname(active_country_display_names) == "GRAND_TOTAL"]
      world_label <- world_label[!is.na(world_label) & nzchar(world_label)]
      if (length(world_label) == 0L) {
        world_label <- "World"
      }
      sorted_countries <- c(stats::setNames("GRAND_TOTAL", world_label[[1L]]), sorted_countries)
    }

    if (identical(current_source_choice_safe(), "vp_trade") && !isTRUE(myc_country_mode_active)) {
      active_vp_country_codes <- unique(trimws(as.character(df$country %||% character(0))))
      active_vp_country_codes <- active_vp_country_codes[!is.na(active_vp_country_codes) & nzchar(active_vp_country_codes)]
      keep_vp_country_codes <- unique(c("GRAND_TOTAL", active_vp_country_codes))
      sorted_countries <- sorted_countries[unname(sorted_countries %||% character(0)) %in% keep_vp_country_codes]

      if (length(sorted_countries) == 0 && length(active_vp_country_codes) > 0) {
        sorted_countries <- stats::setNames(
          active_vp_country_codes,
          vapply(active_vp_country_codes, get_country_label, character(1))
        )
      }
    }

    custom_country_bundle <- get_custom_country_choice_bundle()
    sorted_countries <- append_custom_country_choices(sorted_countries, custom_country_bundle$choices)

    record_country_choice_counter(
      sorted_countries = sorted_countries,
      branch = effective_country_sort %||% "myc_type",
      country_choice_data_source = country_choice_data_source,
      input_rows = nrow(df) + nrow(custom_country_bundle$defs),
      expensive_rank_work = effective_country_sort %in% c("value", "pct_diff", "proj_diff") || isTRUE(myc_type_mode_active),
      country_data_elapsed_ms = country_data_elapsed_ms
    )

    emit_myc_country_choice_trace(
      "country_choice_options_result",
      details = list(
        comparison_mode = market_year_comparison_mode(),
        commodity = input$commodity_choice,
        country_basis_commodity = country_basis_commodity,
        effective_country_sort = effective_country_sort %||% "<null>",
        selected_country = input$country_choice %||% "<null>",
        choice_count = length(sorted_countries %||% character(0)),
        choice_sample = collapse_trace_values(unname(sorted_countries %||% character(0))),
        label_sample = collapse_trace_values(names(sorted_countries %||% character(0))),
        top_filter_active = !is.null(top_countries),
        top_filter_sample = collapse_trace_values(top_countries)
      )
    )

    log_perf(
      "country_choice_options()",
      start_time,
      details = c(
        source_switch_epoch_fields(include_age = TRUE),
        list(
        source = current_source_choice_safe(),
        frequency = input$data_frequency,
        commodity = input$commodity_choice,
        metric = metric,
        sort = input$country_sort,
        myc_country_mode = isTRUE(myc_country_mode_active),
        reverse = isTRUE(input$reverse_sort),
        top_filter = if (isTRUE(input$top5_only)) "top5" else if (isTRUE(input$top10_only)) "top10" else "none",
        input_rows = nrow(df),
        choices = length(sorted_countries),
        expensive_rank_work = effective_country_sort %in% c("value", "pct_diff", "proj_diff") || isTRUE(myc_type_mode_active),
        country_choice_data_source = country_choice_data_source,
        country_data_elapsed_ms = country_data_elapsed_ms,
        selected_data_elapsed_ms = if (identical(country_choice_data_source, "selected_data")) country_data_elapsed_ms else 0L
        )
      )
    )

    sorted_countries
  }) %>% bindCache(
    current_source_choice_safe(),
    current_non_psd_year_type_safe(source_choice = current_source_choice_safe(), default = "marketing"),
    input$data_frequency,
    if (!is.null(input$census_trade_flow_choice) && input$census_trade_flow_choice %in% c("export", "import")) input$census_trade_flow_choice else "export",
    if (!is.null(input$hybrid_trade_flow_choice) && input$hybrid_trade_flow_choice %in% c("export", "import")) input$hybrid_trade_flow_choice else "export",
    if (!is.null(input$hybrid_mode_choice)) input$hybrid_mode_choice else "standard",
    input$commodity_choice,
    effective_main_metric(),
    input$country_sort,
    isTRUE(input$reverse_sort),
    isTRUE(input$top5_only),
    isTRUE(input$top10_only),
    {
      sort_key <- input$country_sort %||% "value"
      sort_key <- if (identical(sort_key, "alphabetical")) "alpha" else sort_key
      if (sort_key %in% c("pct_diff", "proj_diff")) {
        paste(
          "projection_sort",
          comparison_hist_years_committed(),
          input$projection_basis_mode %||% "average",
          input$projection_reference_year %||% "none",
          input$proj_sort_type %||% "historical",
          sep = "|"
        )
      } else {
        "projection_sort_unused"
      }
    },
    input$unit_choice,
    input$basis_choice,
    if (identical(current_source_choice_safe(), "census")) current_census_value_unit_choice_safe() else "n/a",
    if (identical(current_source_choice_safe(), "vp_trade")) input$vp_trade_flow_choice %||% "export" else "n/a",
    if (identical(current_source_choice_safe(), "vp_trade")) input$vp_group_choice %||% "__all__" else "n/a",
    if (identical(current_source_choice_safe(), "vp_trade")) input$vp_subgroup_choice %||% "__all__" else "n/a",
    if (identical(current_source_choice_safe(), "vp_trade")) input$vp_market_segment_choice %||% "__all__" else "n/a",
    if (identical(current_source_choice_safe(), "vp_trade")) input$vp_commodity_name_choice %||% "__all__" else "n/a",
    {
      source_choice <- current_source_choice_safe()
      if (!identical(source_choice, "vp_trade") || !exists("resolve_vp_hierarchy_tokens", mode = "function")) {
        "n/a"
      } else {
        resolved_vp <- tryCatch(
          resolve_vp_hierarchy_tokens(
            vp_group_choice = input$vp_group_choice,
            vp_subgroup_choice = input$vp_subgroup_choice,
            vp_market_segment_choice = input$vp_market_segment_choice
          ),
          error = function(...) NULL
        )

        paste(
          resolved_vp$resolution_mode %||% "n/a",
          resolved_vp$path_name %||% "n/a",
          resolved_vp$cache_group_filter %||% "n/a",
          resolved_vp$cache_subgroup_filter %||% "n/a",
          resolved_vp$cache_market_segment_filter %||% "n/a",
          sep = "|"
        )
      }
    },
    custom_country_cache_key(),
    custom_types_cache_key(),
    input$main_tabs_panel,
    if (!is.null(input$market_year_compare_mode)) input$market_year_compare_mode else "country"
  )

  last_valid_sidebar_country <- reactiveVal("GRAND_TOTAL")

  materialize_sidebar_country_choice <- function(choice_value, legal_choices, base_choices = NULL) {
    normalized_choice <- as.character(choice_value %||% character(0))
    normalized_choice <- normalized_choice[!is.na(normalized_choice) & nzchar(normalized_choice)]
    if (length(normalized_choice) == 0) {
      return(NULL)
    }

    legal_values <- as.character(unname(legal_choices) %||% character(0))
    legal_values <- legal_values[!is.na(legal_values) & nzchar(legal_values)]
    if (length(legal_values) == 0) {
      return(NULL)
    }

    if (normalized_choice[[1]] %in% legal_values) {
      return(normalized_choice[[1]])
    }

    if (!exists("resolve_notes_country_choice", mode = "function")) {
      return(NULL)
    }

    resolved_choice <- tryCatch(
      resolve_notes_country_choice(
        normalized_choice[[1]],
        legal_choices,
        frequency_choices = legal_choices,
        base_choices = base_choices
      ),
      error = function(e) NULL
    )
    resolved_choice <- as.character(resolved_choice %||% character(0))
    resolved_choice <- resolved_choice[!is.na(resolved_choice) & nzchar(resolved_choice)]

    if (length(resolved_choice) == 0 || !(resolved_choice[[1]] %in% legal_values)) {
      return(NULL)
    }

    resolved_choice[[1]]
  }

  strip_psd_country_share_suffix <- function(value) {
    value <- trimws(as.character(value %||% ""))
    sub("\\s+\\([0-9]+(?:\\.[0-9]+)?%\\)$", "", value, perl = TRUE)
  }

  resolve_psd_country_code <- function(candidate, legal_choices, base_choices = NULL, default = NULL) {
    candidate_values <- as.character(candidate %||% character(0))
    candidate_values <- candidate_values[!is.na(candidate_values) & nzchar(trimws(candidate_values))]
    if (length(candidate_values) == 0) {
      return(default)
    }

    legal_codes <- unique(trimws(as.character(unname(legal_choices) %||% character(0))))
    legal_codes <- legal_codes[!is.na(legal_codes) & nzchar(legal_codes)]
    if (length(legal_codes) == 0) {
      return(default)
    }

    legal_labels <- trimws(as.character(names(legal_choices) %||% character(0)))
    legal_labels <- if (length(legal_labels) == length(legal_choices)) legal_labels else rep("", length(legal_choices))
    legal_choice_codes <- trimws(as.character(unname(legal_choices) %||% character(0)))

    resolve_one_candidate <- function(candidate_value) {
      candidate_value <- trimws(as.character(candidate_value %||% ""))
      if (!nzchar(candidate_value)) {
        return(NULL)
      }

      candidate_without_share <- strip_psd_country_share_suffix(candidate_value)
      candidate_variants <- unique(c(candidate_value, candidate_without_share))
      candidate_variants <- candidate_variants[nzchar(candidate_variants)]

      for (candidate_variant in candidate_variants) {
        if (candidate_variant %in% legal_codes) {
          return(candidate_variant)
        }
        if (identical(toupper(candidate_variant), "WORLD") && "GRAND_TOTAL" %in% legal_codes) {
          return("GRAND_TOTAL")
        }
      }

      for (candidate_variant in candidate_variants) {
        label_match <- which(legal_labels == candidate_variant)
        if (length(label_match) > 0) {
          matched_code <- legal_choice_codes[label_match[[1]]]
          if (!is.na(matched_code) && nzchar(matched_code) && matched_code %in% legal_codes) {
            return(matched_code)
          }
        }
      }

      upper_legal_codes <- toupper(legal_codes)
      upper_legal_labels <- toupper(legal_labels)
      for (candidate_variant in candidate_variants) {
        code_match <- match(toupper(candidate_variant), upper_legal_codes)
        if (!is.na(code_match)) {
          return(legal_codes[[code_match]])
        }

        label_match <- match(toupper(candidate_variant), upper_legal_labels)
        if (!is.na(label_match)) {
          matched_code <- legal_choice_codes[[label_match]]
          if (!is.na(matched_code) && nzchar(matched_code) && matched_code %in% legal_codes) {
            return(matched_code)
          }
        }
      }

      for (candidate_variant in candidate_variants) {
        resolved_choice <- materialize_sidebar_country_choice(candidate_variant, legal_choices, base_choices)
        if (!is.null(resolved_choice) && nzchar(resolved_choice) && resolved_choice %in% legal_codes) {
          return(resolved_choice)
        }
      }

      NULL
    }

    for (candidate_value in candidate_values) {
      resolved_value <- resolve_one_candidate(candidate_value)
      if (!is.null(resolved_value) && nzchar(resolved_value)) {
        return(resolved_value)
      }
    }

    default
  }

  observe({
    valid_countries <- tryCatch(country_choice_options(), error = function(e) NULL)
    if (is.null(valid_countries) || length(valid_countries) == 0) return()

    valid_country_values <- unique(as.character(unname(valid_countries) %||% character(0)))
    valid_country_values <- valid_country_values[!is.na(valid_country_values) & nzchar(valid_country_values)]
    if (length(valid_country_values) == 0) return()

      source_choice <- tryCatch(input$data_source_choice, error = function(...) NULL) %||% "export_sales"
      raw_main_tab <- tryCatch(input$main_tabs_panel, error = function(...) NULL) %||% NULL
    current_choice <- input$country_choice
    remembered_choice_before <- isolate(last_valid_sidebar_country())
    pending_choice <- isolate(pending_sidebar_country_target())
      sidebar_base_choices <- tryCatch(country_display_names_for_frequency(), error = function(...) NULL)
      if (is.null(sidebar_base_choices) || length(sidebar_base_choices) == 0) {
        sidebar_base_choices <- country_display_names
      }
      materialized_current_choice <- materialize_sidebar_country_choice(current_choice, valid_countries, sidebar_base_choices)
      materialized_remembered_choice <- materialize_sidebar_country_choice(remembered_choice_before, valid_countries, sidebar_base_choices)
      materialized_pending_choice <- materialize_sidebar_country_choice(pending_choice, valid_countries, sidebar_base_choices)
      if (!is.null(materialized_remembered_choice) && !identical(remembered_choice_before, materialized_remembered_choice)) {
        last_valid_sidebar_country(materialized_remembered_choice)
        remembered_choice_before <- materialized_remembered_choice
      }
      if (!is.null(materialized_pending_choice) && !identical(pending_choice, materialized_pending_choice)) {
        pending_sidebar_country_target(materialized_pending_choice)
        pending_choice <- materialized_pending_choice
      }
      transition_state <- tryCatch(current_psd_source_transition_state(), error = function(...) NULL)
      transition_choice <- as.character(transition_state$country %||% character(0))
      transition_choice <- transition_choice[!is.na(transition_choice) & nzchar(transition_choice)]
      canonical_choice <- if (exists("read_canonical_psd_country", mode = "function")) {
        isolate(read_canonical_psd_country())
      } else {
        NULL
      }
      canonical_choice <- as.character(canonical_choice %||% character(0))
      canonical_choice <- canonical_choice[!is.na(canonical_choice) & nzchar(canonical_choice)]
      guarded_choice <- pending_choice
      if ((is.null(guarded_choice) || !nzchar(guarded_choice)) && length(transition_choice) > 0) {
        guarded_choice <- transition_choice[[1]]
      }
      pending_transition_handoff <-
        !is.null(pending_choice) &&
        nzchar(pending_choice) &&
        length(transition_choice) > 0 &&
        identical(transition_choice[[1]], pending_choice)
      remembered_pending_world_conflict <-
        identical(current_choice, "GRAND_TOTAL") &&
        !is.null(pending_choice) &&
        nzchar(pending_choice) &&
        !identical(pending_choice, "GRAND_TOTAL") &&
        !is.null(remembered_choice_before) &&
        nzchar(remembered_choice_before) &&
        identical(remembered_choice_before, pending_choice)
      guarded_world_conflict <-
        identical(source_choice, "psd") &&
        identical(raw_main_tab, "Time Series Analysis Tool") &&
        identical(current_choice, "GRAND_TOTAL") &&
        !is.null(guarded_choice) &&
        nzchar(guarded_choice) &&
        !identical(guarded_choice, "GRAND_TOTAL") &&
        (
          identical(remembered_choice_before, guarded_choice) ||
            (length(canonical_choice) > 0 && identical(canonical_choice[[1]], guarded_choice))
        )
      guarded_world_conflict <- isTRUE(guarded_world_conflict) || isTRUE(remembered_pending_world_conflict)
    remembered_choice_after <- remembered_choice_before
    pending_choice_after <- pending_choice
    actions <- character(0)

      if (!is.null(materialized_remembered_choice) && !identical(materialized_remembered_choice, isolate(last_valid_sidebar_country()))) {
        actions <- c(actions, "materialize_remembered_choice")
      } else if (!is.null(materialized_remembered_choice) && !identical(remembered_choice_before, materialized_remembered_choice)) {
        actions <- c(actions, "materialize_remembered_choice")
      }
      if (!is.null(materialized_pending_choice) && !identical(pending_choice_after, isolate(pending_sidebar_country_target()))) {
        actions <- c(actions, "materialize_pending_choice")
      } else if (!is.null(materialized_pending_choice) && !identical(pending_choice, materialized_pending_choice)) {
        actions <- c(actions, "materialize_pending_choice")
      }

      effective_current_choice <- materialized_current_choice %||% current_choice
      preserve_pending_handoff <-
        isTRUE(pending_transition_handoff) ||
        (
          !is.null(pending_choice) &&
            nzchar(pending_choice) &&
            !is.null(current_choice) &&
            nzchar(current_choice) &&
            !identical(current_choice, effective_current_choice) &&
            identical(effective_current_choice, pending_choice)
        )
      skip_current_remember_for_pending_handoff <-
        isTRUE(preserve_pending_handoff) &&
        !is.null(pending_choice) &&
        nzchar(pending_choice) &&
        !identical(effective_current_choice, pending_choice)
      automatic_myc_country_fallback <-
        exists("is_myc_automatic_country_value", mode = "function") &&
        isTRUE(is_myc_automatic_country_value(effective_current_choice))

      if (!is.null(effective_current_choice) && effective_current_choice %in% valid_country_values && !isTRUE(guarded_world_conflict) && !isTRUE(skip_current_remember_for_pending_handoff) && !isTRUE(automatic_myc_country_fallback)) {
        if (exists("mark_myc_manual_country_choice", mode = "function")) {
          mark_myc_manual_country_choice(effective_current_choice)
        }
        last_valid_sidebar_country(effective_current_choice)
        remembered_choice_after <- effective_current_choice
        actions <- c(actions, "remember_current_choice")
      } else if (isTRUE(skip_current_remember_for_pending_handoff)) {
        actions <- c(actions, "skip_remember_pending_handoff")
      } else if (isTRUE(guarded_world_conflict)) {
        actions <- c(actions, "skip_remember_guarded_world")
      } else if (isTRUE(automatic_myc_country_fallback)) {
        actions <- c(actions, "skip_remember_automatic_myc_country")
    }

    if (!is.null(pending_choice) && nzchar(pending_choice)) {
      if (!(pending_choice %in% valid_country_values)) {
        pending_sidebar_country_target(NULL)
        pending_choice_after <- NULL
        actions <- c(actions, "clear_pending_invalid")
        } else if (isTRUE(guarded_world_conflict) && identical(pending_choice, guarded_choice)) {
          actions <- c(actions, "keep_pending_guarded_world")
      } else if (!is.null(effective_current_choice) && nzchar(effective_current_choice)) {
        current_matches_pending <- identical(current_choice, pending_choice)
        psd_sidebar_handoff_visible <-
          !identical(source_choice, "psd") ||
            identical(raw_main_tab, "Time Series Analysis Tool")
        if (
          (isTRUE(current_matches_pending) && isTRUE(psd_sidebar_handoff_visible)) ||
            (
              !isTRUE(preserve_pending_handoff) &&
                !is.null(remembered_choice_after) &&
                nzchar(remembered_choice_after) &&
                !identical(remembered_choice_after, pending_choice) &&
                !identical(effective_current_choice, remembered_choice_after)
            )
        ) {
          pending_sidebar_country_target(NULL)
          pending_choice_after <- NULL
          if (isTRUE(current_matches_pending)) {
            actions <- c(actions, "clear_pending_current_match")
          } else {
            actions <- c(actions, "clear_pending_sidebar_changed")
          }
        } else if (isTRUE(current_matches_pending)) {
          actions <- c(actions, "keep_pending_hidden_sidebar_match")
        } else {
          actions <- c(actions, "keep_pending")
        }
      } else {
        actions <- c(actions, "keep_pending")
      }
    }

    if (length(actions) == 0) {
      actions <- "idle"
    }

    psd_transition_trace(
      event = "sidebar_country_state_observer",
      reason = "sidebar_country_state",
      details = list(
        valid_country_count = length(valid_country_values),
        source_choice = source_choice,
        raw_main_tab = raw_main_tab,
        current_choice = current_choice,
        materialized_current_choice = materialized_current_choice,
        remembered_choice_before = remembered_choice_before,
        remembered_choice_after = remembered_choice_after,
        materialized_remembered_choice = materialized_remembered_choice,
        pending_choice_before = pending_choice,
        pending_choice_after = pending_choice_after,
        materialized_pending_choice = materialized_pending_choice,
        guarded_choice = guarded_choice,
        canonical_choice = if (length(canonical_choice) > 0) canonical_choice[[1]] else NULL,
        transition_choice = if (length(transition_choice) > 0) transition_choice[[1]] else NULL,
        pending_transition_handoff = pending_transition_handoff,
        preserve_pending_handoff = preserve_pending_handoff,
        remembered_pending_world_conflict = remembered_pending_world_conflict,
        guarded_world_conflict = guarded_world_conflict,
        actions = paste(actions, collapse = "|")
      ),
      dedupe_key = "sidebar_country_state_observer",
      dedupe_signature = build_transition_trace_signature(list(
        valid_country_count = length(valid_country_values),
        source_choice = source_choice,
        raw_main_tab = raw_main_tab,
        current_choice = current_choice,
        materialized_current_choice = materialized_current_choice,
        remembered_choice_before = remembered_choice_before,
        remembered_choice_after = remembered_choice_after,
        materialized_remembered_choice = materialized_remembered_choice,
        pending_choice_before = pending_choice,
        pending_choice_after = pending_choice_after,
        materialized_pending_choice = materialized_pending_choice,
        guarded_choice = guarded_choice,
        canonical_choice = if (length(canonical_choice) > 0) canonical_choice[[1]] else NULL,
        transition_choice = if (length(transition_choice) > 0) transition_choice[[1]] else NULL,
        pending_transition_handoff = pending_transition_handoff,
        preserve_pending_handoff = preserve_pending_handoff,
        remembered_pending_world_conflict = remembered_pending_world_conflict,
        guarded_world_conflict = guarded_world_conflict,
        actions = paste(actions, collapse = "|")
      ))
    )

    if (exists("complete_myc_sidebar_restore_if_ready", mode = "function")) {
      complete_myc_sidebar_restore_if_ready("country_choice_observed")
    }
  })

  resolve_country_choice_selection_state <- function(sorted_countries, current_choice, remembered_choice = NULL, pending_choice = NULL, myc_country_mode_active = FALSE, force_grand_total = FALSE, myc_country_analysis_initial_world = FALSE, force_grand_total_reason = NULL) {
    valid_choices <- as.character(sorted_countries %||% character(0))
    grand_total_available <- "GRAND_TOTAL" %in% valid_choices
    base_choices <- tryCatch(country_display_names_for_frequency(), error = function(...) NULL)
    if (is.null(base_choices) || length(base_choices) == 0) {
      base_choices <- country_display_names
    }
    materialized_pending_choice <- materialize_sidebar_country_choice(pending_choice, sorted_countries, base_choices)
    materialized_current_choice <- materialize_sidebar_country_choice(current_choice, sorted_countries, base_choices)
    materialized_remembered_choice <- materialize_sidebar_country_choice(remembered_choice, sorted_countries, base_choices)
    effective_pending_choice <- materialized_pending_choice %||% pending_choice
    effective_current_choice <- materialized_current_choice %||% current_choice
    effective_remembered_choice <- materialized_remembered_choice %||% remembered_choice
    pending_in_choices <- !is.null(effective_pending_choice) && effective_pending_choice %in% valid_choices
    current_in_choices <- !is.null(effective_current_choice) && effective_current_choice %in% valid_choices
    remembered_in_choices <- !is.null(effective_remembered_choice) && effective_remembered_choice %in% valid_choices
    first_available <- if (length(valid_choices) > 0) valid_choices[[1]] else NULL

    if (isTRUE(force_grand_total) && grand_total_available) {
      selected_country <- "GRAND_TOTAL"
      branch <- "force_grand_total"
    } else if (isTRUE(myc_country_analysis_initial_world) && grand_total_available) {
      selected_country <- "GRAND_TOTAL"
      branch <- "myc_initial_world"
    } else if (isTRUE(pending_in_choices)) {
      selected_country <- effective_pending_choice
      branch <- "pending_choice"
    } else if (isTRUE(current_in_choices)) {
      selected_country <- effective_current_choice
      branch <- "current_choice"
    } else if (isTRUE(remembered_in_choices)) {
      selected_country <- effective_remembered_choice
      branch <- "remembered_choice"
    } else if (isTRUE(myc_country_mode_active)) {
      selected_country <- first_available
      branch <- "myc_first_available"
    } else if (isTRUE(grand_total_available)) {
      selected_country <- "GRAND_TOTAL"
      branch <- "grand_total_fallback"
    } else {
      selected_country <- first_available
      branch <- "first_available"
    }

    psd_transition_trace(
      event = "resolve_country_choice_selection",
      reason = "country_choice_resolution",
      details = list(
        sorted_country_count = length(valid_choices),
        current_choice = current_choice,
        materialized_current_choice = materialized_current_choice,
        remembered_choice = remembered_choice,
        materialized_remembered_choice = materialized_remembered_choice,
        pending_choice = pending_choice,
        materialized_pending_choice = materialized_pending_choice,
        force_grand_total = force_grand_total,
        force_grand_total_reason = force_grand_total_reason,
        myc_country_analysis_initial_world = myc_country_analysis_initial_world,
        myc_country_mode_active = myc_country_mode_active,
        grand_total_available = grand_total_available,
        pending_in_choices = pending_in_choices,
        current_in_choices = current_in_choices,
        remembered_in_choices = remembered_in_choices,
        first_available = first_available,
        selected_country = selected_country,
        branch = branch
      ),
      dedupe_key = "resolve_country_choice_selection",
      dedupe_signature = build_transition_trace_signature(list(
        sorted_country_count = length(valid_choices),
        current_choice = current_choice,
        materialized_current_choice = materialized_current_choice,
        remembered_choice = remembered_choice,
        materialized_remembered_choice = materialized_remembered_choice,
        pending_choice = pending_choice,
        materialized_pending_choice = materialized_pending_choice,
        force_grand_total = force_grand_total,
        force_grand_total_reason = force_grand_total_reason,
        myc_country_analysis_initial_world = myc_country_analysis_initial_world,
        myc_country_mode_active = myc_country_mode_active,
        grand_total_available = grand_total_available,
        pending_in_choices = pending_in_choices,
        current_in_choices = current_in_choices,
        remembered_in_choices = remembered_in_choices,
        first_available = first_available,
        selected_country = selected_country,
        branch = branch
      ))
    )

    list(
      selected_country = selected_country,
      branch = branch,
      automatic = branch %in% c("force_grand_total", "myc_initial_world", "myc_first_available")
    )
  }

  resolve_country_choice_selection <- function(sorted_countries, current_choice, remembered_choice = NULL, pending_choice = NULL, myc_country_mode_active = FALSE, force_grand_total = FALSE, myc_country_analysis_initial_world = FALSE) {
    state <- resolve_country_choice_selection_state(
      sorted_countries = sorted_countries,
      current_choice = current_choice,
      remembered_choice = remembered_choice,
      pending_choice = pending_choice,
      myc_country_mode_active = myc_country_mode_active,
      force_grand_total = force_grand_total,
      myc_country_analysis_initial_world = myc_country_analysis_initial_world
    )

    state$selected_country
  }

  country_choice_ui_selection_state <- reactive({
    sorted_countries <- country_choice_options()
    source_choice <- current_source_choice_safe()
    raw_main_tab <- input$main_tabs_panel %||% NULL
    myc_country_mode_active <- identical(input$main_tabs_panel, "Market Year Comparison Tool") &&
      identical(market_year_comparison_mode(), "country")
    myc_country_analysis_initial_world_pending <- identical(input$main_tabs_panel, "Market Year Comparison Tool") &&
      identical(market_year_comparison_mode(), "type") &&
      !isTRUE(myc_country_analysis_default_applied())
    myc_type_mode_world_reset_pending <- identical(input$main_tabs_panel, "Market Year Comparison Tool") &&
      identical(market_year_comparison_mode(), "type") &&
      isTRUE(partner_selection_programmatic_world_reset())
    census_launch_world_default_pending <- isTRUE(census_launch_world_default_pending_flag()) &&
      identical(source_choice, "census") &&
      identical(raw_main_tab, "Current vs. Average") &&
      identical(input$commodity_choice %||% default_commodity_choice_value(), default_commodity_choice_value())

    force_grand_total_reason <- if (isTRUE(myc_type_mode_world_reset_pending)) {
      "myc_type_world_reset"
    } else if (isTRUE(census_launch_world_default_pending)) {
      "pending_census_launch_default"
    } else {
      "none"
    }

    used_fallback_choices <- FALSE
    if (is.null(sorted_countries) || length(sorted_countries) == 0) {
      fallback_countries <- country_display_names_for_frequency()
      if (is.null(fallback_countries) || length(fallback_countries) == 0) {
        fallback_countries <- country_display_names
      }

      if (isTRUE(myc_country_mode_active)) {
        fallback_countries <- fallback_countries[fallback_countries != "GRAND_TOTAL"]
      }

      sorted_countries <- fallback_countries
      used_fallback_choices <- TRUE
    }

    current_selection_state <- resolve_country_choice_selection_state(
      sorted_countries = sorted_countries,
      current_choice = input$country_choice,
      remembered_choice = isolate(last_valid_sidebar_country()),
      pending_choice = pending_sidebar_country_target(),
      myc_country_mode_active = myc_country_mode_active,
      force_grand_total = isTRUE(myc_type_mode_world_reset_pending) || isTRUE(census_launch_world_default_pending),
      myc_country_analysis_initial_world = myc_country_analysis_initial_world_pending,
      force_grand_total_reason = force_grand_total_reason
    )
    current_selection <- current_selection_state$selected_country

    pending_choice <- as.character(pending_sidebar_country_target() %||% character(0))
    pending_choice <- pending_choice[!is.na(pending_choice) & nzchar(pending_choice)]
    guarded_ui_sync <-
      identical(source_choice, "psd") &&
      identical(raw_main_tab, "Time Series Analysis Tool") &&
      identical(input$country_choice %||% NULL, "GRAND_TOTAL") &&
      length(pending_choice) > 0 &&
      !identical(pending_choice[[1]], "GRAND_TOTAL") &&
      identical(current_selection, pending_choice[[1]])

    list(
      sorted_countries = sorted_countries,
      source_choice = source_choice,
      raw_main_tab = raw_main_tab,
      myc_country_mode_active = myc_country_mode_active,
      myc_country_analysis_initial_world_pending = myc_country_analysis_initial_world_pending,
      myc_type_mode_world_reset_pending = myc_type_mode_world_reset_pending,
      census_launch_world_default_pending = census_launch_world_default_pending,
      used_fallback_choices = used_fallback_choices,
      current_selection_state = current_selection_state,
      current_selection = current_selection,
      pending_choice = pending_choice,
      guarded_ui_sync = guarded_ui_sync
    )
  })

  observe({
    selection_bundle <- country_choice_ui_selection_state()
    current_selection_state <- selection_bundle$current_selection_state
    current_selection <- selection_bundle$current_selection

    if (
      isTRUE(current_selection_state$automatic) &&
      !is.null(current_selection) &&
      nzchar(current_selection) &&
      exists("mark_myc_automatic_country_fallback", mode = "function")
    ) {
      mark_myc_automatic_country_fallback(current_selection, branch = current_selection_state$branch)
    }
  }, priority = 110)

  census_aggregate_world_default_applied <- reactiveVal(FALSE)
  census_launch_world_default_pending_flag <- reactiveVal(FALSE)

  observeEvent(input$data_source_choice, {
    source_choice <- current_source_choice_safe()
    if (identical(source_choice, "census")) {
      census_launch_world_default_pending_flag(TRUE)
      census_aggregate_world_default_applied(FALSE)
    } else {
      census_launch_world_default_pending_flag(FALSE)
      census_aggregate_world_default_applied(FALSE)
    }
  }, ignoreInit = FALSE)

  observe({
    selection_bundle <- country_choice_ui_selection_state()
    if (
      isTRUE(selection_bundle$census_launch_world_default_pending) &&
      identical(selection_bundle$source_choice, "census") &&
      identical(selection_bundle$raw_main_tab, "Current vs. Average") &&
      identical(selection_bundle$current_selection_state$branch, "force_grand_total")
    ) {
      if (!isTRUE(census_aggregate_world_default_applied())) {
        census_aggregate_world_default_applied(TRUE)
      }
      if (isTRUE(census_launch_world_default_pending_flag())) {
        census_launch_world_default_pending_flag(FALSE)
      }
    }
  }, priority = 108)

  observeEvent(list(
    input$data_source_choice,
    input$census_trade_flow_choice,
    input$commodity_choice,
    input$data_frequency,
    input$metric_choice,
    input$country_sort,
    input$reverse_sort,
    input$top5_only,
    input$top10_only,
    input$main_tabs_panel
  ), {
    if (isTRUE(census_aggregate_world_default_applied())) return()

    source_choice <- current_source_choice_safe(default = input$data_source_choice %||% "export_sales")
    if (!identical(source_choice, "census")) return()

    aggregate_label <- default_commodity_choice_value()
    if (!identical(input$commodity_choice %||% aggregate_label, aggregate_label)) return()

    census_countries <- tryCatch(country_choice_options(), error = function(e) NULL)
    census_country_values <- unname(census_countries %||% character(0))
    if (!("GRAND_TOTAL" %in% census_country_values)) return()

    updateSelectizeInput(session, "country_choice", choices = census_countries, selected = "GRAND_TOTAL")
    session$onFlushed(function() {
      session$sendCustomMessage(
        "setSelectizeOrShinyInputValue",
        list(
          inputId = "country_choice",
          value = "GRAND_TOTAL",
          trace = list(
            sync_reason = "census_aggregate_world_default",
            sync_phase = "source_commodity_sync",
            retry_until_match = TRUE,
            retry_delays_ms = c(40L, 120L, 260L)
          )
        )
      )
    }, once = TRUE)
    census_aggregate_world_default_applied(TRUE)
    census_launch_world_default_pending_flag(FALSE)
  }, ignoreInit = FALSE, priority = 105)

  # Reactive: render country dropdown with dynamic sorting
  output$country_choice_ui <- renderUI({
    country_choice_ui_start_time <- Sys.time()
    selection_bundle <- country_choice_ui_selection_state()
    sorted_countries <- selection_bundle$sorted_countries
    source_choice <- selection_bundle$source_choice
    raw_main_tab <- selection_bundle$raw_main_tab
    myc_country_mode_active <- selection_bundle$myc_country_mode_active
    myc_country_analysis_initial_world_pending <- selection_bundle$myc_country_analysis_initial_world_pending
    myc_type_mode_world_reset_pending <- selection_bundle$myc_type_mode_world_reset_pending
    census_launch_world_default_pending <- selection_bundle$census_launch_world_default_pending
    used_fallback_choices <- selection_bundle$used_fallback_choices
    current_selection <- selection_bundle$current_selection
    pending_choice <- selection_bundle$pending_choice
    guarded_ui_sync <- selection_bundle$guarded_ui_sync

    psd_transition_trace(
      event = "country_choice_ui_selection",
      reason = "country_choice_ui_render",
      details = list(
        sorted_country_count = length(sorted_countries %||% character(0)),
        selected_country = current_selection,
        current_choice = input$country_choice,
        remembered_choice = isolate(last_valid_sidebar_country()),
        pending_choice = if (length(pending_choice) > 0) pending_choice[[1]] else NULL,
        myc_country_mode_active = myc_country_mode_active,
        myc_type_mode_world_reset_pending = myc_type_mode_world_reset_pending,
        myc_country_analysis_initial_world_pending = myc_country_analysis_initial_world_pending,
        census_launch_world_default_pending = census_launch_world_default_pending,
        guarded_ui_sync = guarded_ui_sync,
        used_fallback_choices = used_fallback_choices,
        first_available = if (length(sorted_countries %||% character(0)) > 0) unname(sorted_countries[[1]]) else NULL
      ),
      dedupe_key = "country_choice_ui_selection",
      dedupe_signature = build_transition_trace_signature(list(
        sorted_country_count = length(sorted_countries %||% character(0)),
        selected_country = current_selection,
        current_choice = input$country_choice,
        remembered_choice = isolate(last_valid_sidebar_country()),
        pending_choice = if (length(pending_choice) > 0) pending_choice[[1]] else NULL,
        myc_country_mode_active = myc_country_mode_active,
        myc_type_mode_world_reset_pending = myc_type_mode_world_reset_pending,
        myc_country_analysis_initial_world_pending = myc_country_analysis_initial_world_pending,
        census_launch_world_default_pending = census_launch_world_default_pending,
        guarded_ui_sync = guarded_ui_sync,
        used_fallback_choices = used_fallback_choices,
        first_available = if (length(sorted_countries %||% character(0)) > 0) unname(sorted_countries[[1]]) else NULL
      ))
    )

    if (isTRUE(guarded_ui_sync)) {
      session$onFlushed(function() {
        current_input <- isolate(input$country_choice %||% NULL)
        if (!identical(current_input, current_selection)) {
          updateSelectizeInput(session, "country_choice", selected = current_selection)
          session$sendCustomMessage(
            "setSelectizeOrShinyInputValue",
            list(
              inputId = "country_choice",
              value = current_selection,
              trace = list(
                sync_reason = "country_choice_ui_guard_sync",
                sync_phase = "guarded_ui_sync",
                retry_until_match = TRUE,
                retry_delays_ms = c(40L, 120L, 260L)
              )
            )
          )
          if (exists("request_sidebar_country_probe", mode = "function")) {
            request_sidebar_country_probe("country_choice_ui_guard_sync", delay_ms = 320L)
          }
        }
      }, once = TRUE)
    }

    if (exists("request_sidebar_country_probe", mode = "function")) {
      request_sidebar_country_probe("country_choice_ui_render", delay_ms = 180L)
    }

    country_choice_selectize_options <- if (identical(current_source_choice_safe(), "psd")) {
      psd_country_selectize_options()
    } else {
      list(
        placeholder = "Type to filter countries...",
        openOnFocus = TRUE,
        closeAfterSelect = TRUE,
        maxOptions = 250
      )
    }

    if (isTRUE(guarded_ui_sync)) {
      current_selection_json <- jsonlite::toJSON(as.character(current_selection %||% ""), auto_unbox = TRUE)
      country_choice_selectize_options <- modifyList(
        country_choice_selectize_options,
        list(
          onInitialize = I(sprintf(
            "function() { var selectize = this; var nextValue = %s; window.setTimeout(function() { if (String(selectize.getValue() || '') !== String(nextValue || '')) { selectize.setValue(nextValue); } }, 0); }",
            current_selection_json
          ))
        )
      )
    }

    build_grouped_country_display_choices <- function(country_choices) {
      if (is.null(country_choices) || length(country_choices) == 0) {
        return(list(
          "Native Countries" = stats::setNames(character(0), character(0)),
          "Custom Countries" = stats::setNames(character(0), character(0)),
          "Actions" = stats::setNames(CUSTOM_COUNTRY_BUILDER_CHOICE, "Custom Country Builder...")
        ))
      }

      choice_values <- unname(country_choices)
      choice_labels <- names(country_choices)

      native_idx <- !vapply(choice_values, is_custom_country_choice_value, logical(1))
      custom_idx <- vapply(choice_values, is_custom_country_choice_value, logical(1))

      native_choices <- stats::setNames(choice_values[native_idx], choice_labels[native_idx])
      custom_choices <- stats::setNames(choice_values[custom_idx], choice_labels[custom_idx])

      list(
        "Native Countries" = native_choices,
        "Custom Countries" = custom_choices,
        "Actions" = stats::setNames(CUSTOM_COUNTRY_BUILDER_CHOICE, "Custom Country Builder...")
      )
    }

    display_countries <- if (identical(source_choice, "nass")) {
      sorted_countries
    } else {
      build_grouped_country_display_choices(sorted_countries)
    }

    country_choice_input <- selectizeInput(
      inputId = "country_choice",
      label = "Country:",
      choices = display_countries,
      selected = current_selection,
      multiple = FALSE,
      options = country_choice_selectize_options
    )

    country_choice_ui <- country_choice_input
    if (identical(source_choice, "nass")) {
      nass_state_choices <- nass_state_choice_options()
      selected_state <- current_nass_state_choice_safe(default = current_selection)
      session$onFlushed(function() {
        current_country_input <- isolate(input$country_choice %||% NULL)
        if (!identical(current_country_input, selected_state)) {
          updateSelectizeInput(session, "country_choice", selected = selected_state)
        }
      }, once = TRUE)

      country_choice_ui <- tagList(
        tags$div(
          id = "nass_state_choice_container",
          selectizeInput(
            inputId = "nass_state_choice",
            label = "State:",
            choices = nass_state_choices,
            selected = selected_state,
            multiple = FALSE,
            options = list(
              placeholder = "Type to filter states...",
              openOnFocus = TRUE,
              closeAfterSelect = TRUE,
              maxOptions = 250
            )
          )
        ),
        tags$div(
          id = "nass_country_choice_hidden_container",
          style = "display:none;",
          selectizeInput(
            inputId = "country_choice",
            label = "Country:",
            choices = nass_state_choices,
            selected = selected_state,
            multiple = FALSE,
            options = country_choice_selectize_options
          )
        )
      )
    }
    if (identical(source_choice, "wasde")) {
      session$onFlushed(function() {
        current_input <- isolate(input$country_choice %||% NULL)
        if (!identical(current_input, current_selection)) {
          updateSelectizeInput(session, "country_choice", selected = current_selection)
        }
      }, once = TRUE)

      country_choice_ui <- tags$div(
        id = "wasde_country_choice_hidden_container",
        style = "display:none;",
        country_choice_input
      )
    }

    log_perf(
      "country_choice_ui()",
      country_choice_ui_start_time,
      details = c(
        source_switch_epoch_fields(include_age = TRUE),
        list(
          source = source_choice,
          tab = raw_main_tab,
          sorted_country_count = length(sorted_countries %||% character(0)),
          selected_country = current_selection,
          used_fallback_choices = used_fallback_choices,
          guarded_ui_sync = guarded_ui_sync
        )
      )
    )

    country_choice_ui
  })

  observeEvent(input$nass_state_choice, {
    if (!identical(current_source_choice_safe(default = input$data_source_choice %||% "export_sales"), "nass")) return()
    selected_state <- current_nass_state_choice_safe()
    updateSelectizeInput(session, "country_choice", selected = selected_state)
  }, ignoreInit = TRUE)
  
  filtered_data_stable_cache_key <- function(country_choice = input$country_choice, commodity_choice = input$commodity_choice) {
    source_choice <- current_source_choice_safe(default = input$data_source_choice %||% "export_sales")
    data_frequency <- current_data_frequency_safe(default = input$data_frequency %||% "weekly")
    resolved_vp <- if (identical(source_choice, "vp_trade") && exists("resolve_vp_hierarchy_tokens", mode = "function")) {
      tryCatch(
        resolve_vp_hierarchy_tokens(
          vp_group_choice = input$vp_group_choice,
          vp_subgroup_choice = input$vp_subgroup_choice,
          vp_market_segment_choice = input$vp_market_segment_choice
        ),
        error = function(...) NULL
      )
    } else {
      NULL
    }
    commodity_key <- as.character(commodity_choice %||% NA_character_)
    country_key <- as.character(country_choice %||% NA_character_)
    custom_scope <- unique(c(
      input$commodity_choice,
      panel_state$commodity_right_2up,
      panel_state$commodity_grid_2,
      panel_state$commodity_grid_3,
      panel_state$commodity_grid_4
    ))
    custom_scope <- custom_scope[!is.na(custom_scope) & nzchar(custom_scope)]

    list(
      data_source_choice = source_choice,
      vp_trade_flow_choice = if (!is.null(input$vp_trade_flow_choice) && input$vp_trade_flow_choice %in% c("export", "import")) input$vp_trade_flow_choice else "export",
      vp_group_choice = if (!is.null(input$vp_group_choice)) input$vp_group_choice else "__all__",
      vp_subgroup_choice = if (!is.null(input$vp_subgroup_choice)) input$vp_subgroup_choice else "__all__",
      vp_market_segment_choice = if (!is.null(input$vp_market_segment_choice)) input$vp_market_segment_choice else "__all__",
      vp_resolution_mode = resolved_vp$resolution_mode %||% "n/a",
      vp_resolved_path = resolved_vp$path_name %||% "n/a",
      vp_resolved_group_filter = resolved_vp$cache_group_filter %||% "n/a",
      vp_resolved_subgroup_filter = resolved_vp$cache_subgroup_filter %||% "n/a",
      vp_resolved_market_segment_filter = resolved_vp$cache_market_segment_filter %||% "n/a",
      vp_commodity_name_choice = if (!is.null(input$vp_commodity_name_choice)) input$vp_commodity_name_choice else NA_character_,
      vp_commodity_detail_choice = if (!is.null(input$commodity_choice)) input$commodity_choice else NA_character_,
      cache_data_version = cache_data_version,
      cache_schema_version = cache_schema_version,
      commodity_choice = if (length(commodity_key) > 0) commodity_key[[1]] else NA_character_,
      country_choice = if (length(country_key) > 0) country_key[[1]] else NA_character_,
      data_frequency = data_frequency,
      display_year_type = current_display_year_type(source_choice = source_choice),
      metric = effective_main_metric(),
      unit_choice = current_unit_choice_safe(),
      basis_choice = resolve_basis_choice(
        if (length(commodity_key) > 0) commodity_key[[1]] else input$commodity_choice,
        current_basis_choice_safe(),
        current_main_tab_safe(),
        source_choice = source_choice
      ),
      custom_types = custom_types_cache_key(),
      custom_countries = custom_country_cache_key(),
      custom_scope = paste(sort(unique(custom_scope)), collapse = "|"),
      selected_data_mode = if (isTRUE(is_myc_type_mode_active())) "myc_type" else "standard"
    )
  }

    trace_myc_comparison_sidebar_state <- function(event, details = list()) {
      if (!identical(isolate(input$main_tabs_panel), "Market Year Comparison Tool")) {
        return(invisible(NULL))
      }

      tracer <- get0("myc_transition_trace", inherits = TRUE)
      if (!is.function(tracer)) {
        return(invisible(NULL))
      }

      tracer(event, details = details)
      invisible(NULL)
    }

# Add reactive to provide the available reference years
    reference_year_choices <- reactive({
      commodity_choice_value <- input$commodity_choice
      myc_type_mode_active <- identical(input$main_tabs_panel, "Market Year Comparison Tool") &&
        identical(input$market_year_compare_mode, "type")
      trace_myc_comparison_sidebar_state(
        "reference_year_choices_enter",
        details = list(
          source = isolate(current_source_choice_safe(default = input$data_source_choice %||% "export_sales")),
          mode = isolate(input$market_year_compare_mode %||% "<null>"),
          vp_commodity_name = isolate(input$vp_commodity_name_choice %||% "<null>"),
          commodity_choice = commodity_choice_value %||% "<null>",
          country_choice = isolate(input$country_choice %||% "<null>")
        )
      )

      if (isTRUE(myc_type_mode_active)) {
        df <- selected_data()
        if (is.null(df) || nrow(df) == 0) {
          trace_myc_comparison_sidebar_state(
            "reference_year_choices_empty",
            details = list(
              reason = if (is.null(df)) "myc_type_null_selected_data" else "myc_type_zero_selected_data_rows",
              commodity_choice = commodity_choice_value %||% "<null>",
              vp_commodity_name = isolate(input$vp_commodity_name_choice %||% "<null>")
            )
          )
          return(NULL)
        }

        years <- sort(unique(df$market_year), decreasing = TRUE)
        years <- years[!is.na(years)]
        trace_myc_comparison_sidebar_state(
          "reference_year_choices_ready",
          details = list(
            branch = "myc_type_selected_data",
            commodity_choice = commodity_choice_value %||% "<null>",
            vp_commodity_name = isolate(input$vp_commodity_name_choice %||% "<null>"),
            rows = nrow(df),
            years = length(years),
            year_sample = paste(head(years, 5L), collapse = " | ")
          )
        )

        return(years)
      }

      if (is.null(commodity_choice_value) || !nzchar(as.character(commodity_choice_value))) {
        trace_myc_comparison_sidebar_state(
          "reference_year_choices_abort",
          details = list(reason = "missing_commodity_choice")
        )
      }

      req(commodity_choice_value)
      df <- filtered_data_for_country("GRAND_TOTAL", commodity_choice_value, consumer = "reference_year_choices")
      if(is.null(df) || nrow(df) == 0) {
        trace_myc_comparison_sidebar_state(
          "reference_year_choices_empty",
          details = list(
            reason = if (is.null(df)) "null_df" else "zero_rows",
            commodity_choice = commodity_choice_value %||% "<null>"
          )
        )
        return(NULL)
      }

      years <- sort(unique(df$market_year), decreasing = TRUE)
      trace_myc_comparison_sidebar_state(
        "reference_year_choices_ready",
        details = list(
          commodity_choice = commodity_choice_value %||% "<null>",
          rows = nrow(df),
          years = length(years),
          year_sample = paste(head(years, 5L), collapse = " | ")
        )
      )

      years
    }) %>% bindCache(
      filtered_data_stable_cache_key(country_choice = "GRAND_TOTAL", commodity_choice = input$commodity_choice)
    )

    output$comparison_basis_ui <- renderUI({
      allowed_tabs <- c(
        "Current vs. Average",
        "Historical Trend",
        "Custom Comparison Tool",
        "Market Year Comparison Tool",
        "Pace Analysis Tool"
      )

      current_tab <- input$main_tabs_panel
      if (length(current_tab) != 1 || is.na(current_tab) || !nzchar(current_tab)) {
        trace_myc_comparison_sidebar_state(
          "comparison_basis_ui_return",
          details = list(branch = "missing_tab")
        )
        return(NULL)
      }

      if (!(current_tab %in% allowed_tabs)) {
        trace_myc_comparison_sidebar_state(
          "comparison_basis_ui_return",
          details = list(branch = "tab_not_allowed", tab = current_tab)
        )
        return(NULL)
      }

      trace_myc_comparison_sidebar_state(
        "comparison_basis_ui_before_years",
        details = list(
          tab = current_tab,
          source = isolate(current_source_choice_safe(default = input$data_source_choice %||% "export_sales")),
          mode = isolate(input$market_year_compare_mode %||% "<null>"),
          vp_commodity_name = isolate(input$vp_commodity_name_choice %||% "<null>"),
          commodity_choice = isolate(input$commodity_choice %||% "<null>"),
          country_choice = isolate(input$country_choice %||% "<null>")
        )
      )

      years <- reference_year_choices()
      comparison_state <- read_comparison_state_bundle_safe(
        surface = "standard",
        source_choice = current_source_choice_safe(),
        year_choices = years
      )
      selected_basis_mode <- comparison_state$basis_mode
      selected_ref_year <- comparison_state$reference_year
      selected_hist_years <- comparison_state$hist_years
      selected_hist_year_max <- available_hist_year_count(years)

      trace_myc_comparison_sidebar_state(
        "comparison_basis_ui_ready",
        details = list(
          tab = current_tab,
          years = length(years %||% numeric(0)),
          year_sample = paste(head(years %||% numeric(0), 5L), collapse = " | "),
          basis_mode = selected_basis_mode %||% "<null>",
          reference_year = selected_ref_year %||% "<null>",
          hist_years = selected_hist_years %||% "<null>",
          hist_year_max = selected_hist_year_max %||% "<null>"
        )
      )

      tagList(
        div(
          class = "sidebar-basis-block",
          radioButtons(
            inputId = "projection_basis_mode",
            label = "Comparison Basis:",
            choices = c("Multi-Year Average" = "average", "Single Reference Year" = "single_year"),
            selected = selected_basis_mode
          ),
          if (identical(selected_basis_mode, "single_year")) {
            div(
              class = "sidebar-basis-year",
              style = "margin-top: 5px !important;",
              selectInput(
                inputId = "projection_reference_year",
                label = "Select Reference Year:",
                choices = years,
                selected = selected_ref_year,
                width = "100%"
              )
            )
          } else {
            comparison_hist_slider(
              input_id = "hist_years",
              label = "Years for Historical Average:",
              hist_year_max = selected_hist_year_max,
              hist_years = selected_hist_years
            )
          }
        )
      )
    })

    outputOptions(output, "comparison_basis_ui", suspendWhenHidden = FALSE)

    observeEvent(
      list(input$projection_basis_mode, reference_year_choices()),
      {
        if (!identical(input$projection_basis_mode, "single_year")) {
          return()
        }

        years <- reference_year_choices()
        if (length(years) == 0) {
          return()
        }

        current_ref_year <- suppressWarnings(as.numeric(input$projection_reference_year))
        default_yr <- if (length(years) > 1) years[2] else years[1]

        if (length(current_ref_year) != 1 || !is.finite(current_ref_year) || !(current_ref_year %in% years)) {
          updateSelectInput(
            session,
            inputId = "projection_reference_year",
            choices = years,
            selected = default_yr
          )
        }
      },
      ignoreInit = FALSE
    )

    observeEvent(
      list(input$projection_basis_mode, input$projection_reference_year, comparison_hist_years_committed()),
      {
        if (identical(input$main_tabs_panel, "Map")) {
          return()
        }

        comparison_state <- read_comparison_state_bundle_safe(
          surface = "standard",
          source_choice = current_source_choice_safe(),
          year_choices = reference_year_choices(),
          hist_years_override = comparison_hist_years_committed()
        )

        set_remembered_comparison_state_bundle(
          source_choice = current_source_choice_safe(),
          basis_mode = comparison_state$basis_mode,
          reference_year = comparison_state$reference_year,
          hist_years = comparison_state$hist_years,
          year_choices = reference_year_choices()
        )
      },
      ignoreInit = TRUE
    )

    # Reactive: render projection controls UI (only for cumulative metrics)
    output$projection_controls_ui <- renderUI({
      hidden_tabs <- c("Market Year Comparison Tool", "Map", "Heatmap", "Data", "Time Series Analysis Tool")
      current_tab <- input$main_tabs_panel
      if (length(current_tab) != 1 || is.na(current_tab) || !nzchar(current_tab)) {
        return(NULL)
      }

      if (current_tab %in% hidden_tabs) {
        return(NULL)
      }

      req(effective_main_metric(), input$country_choice)
      metric <- effective_main_metric()

      cumulative_metrics <- projection_metric_choices_for_source()

      if (!(metric %in% cumulative_metrics)) {
        return(NULL)  # Don't show projection controls for non-cumulative metrics
      }

      if (identical(input$data_source_choice, "psd")) {
        return(
          tagList(
            div(
              class = "sidebar-projection-block",
              h4(class = "sidebar-projection-header pace-projection-header", "Year-End Projections"),
              div(class = "pace-header-spacer", style = "display: block; height: 8px;"),
              div(
                class = "sidebar-option-group pace-projection-options",
                if (identical(input$country_choice, "GRAND_TOTAL")) {
                  checkboxInput("show_linear_projection", "Show Linear Fit Projection", FALSE)
                } else {
                  checkboxInput("show_linear_projection_country", "Show Linear Fit Projection", FALSE)
                }
              )
            )
          )
        )
      }
      
      # Pace-only single-select projection source
      if (identical(input$main_tabs_panel, "Pace Analysis Tool")) {
        pace_choices <- c(
          "Show Linear Fit Projection" = "linear",
          "Show Historical Pattern Projection" = "historical"
        )

        selected_source <- if (!is.null(input$pace_projection_source) && input$pace_projection_source %in% pace_choices) {
          input$pace_projection_source
        } else {
          "historical"
        }

        return(
          tagList(
            div(
              class = "sidebar-projection-block",
              h4(class = "sidebar-projection-header pace-projection-header", "Year-End Projections"),
              div(class = "pace-header-spacer", style = "display: block; height: 8px;"),
              div(
                class = "sidebar-option-group pace-projection-options",
                radioButtons(
                  inputId = "pace_projection_source",
                  label = NULL,
                  choices = pace_choices,
                  selected = selected_source
                )
              )
            )
          )
        )
      }

      is_custom_context <- identical(input$main_tabs_panel, "Custom Comparison Tool")
      selected_show_linear_projection <- if (!is.null(isolate(input$show_linear_projection))) {
        isTRUE(isolate(input$show_linear_projection))
      } else {
        FALSE
      }
      selected_show_total_projection <- if (!is.null(isolate(input$show_total_projection))) {
        isTRUE(isolate(input$show_total_projection))
      } else {
          TRUE
      }
      selected_show_sum_projection <- if (!is.null(isolate(input$show_sum_projection))) {
        isTRUE(isolate(input$show_sum_projection))
      } else {
          FALSE
      }
      selected_show_projections <- if (!is.null(isolate(input$show_projections))) {
        isTRUE(isolate(input$show_projections))
      } else {
        TRUE
      }
      selected_show_linear_projection_country <- if (!is.null(isolate(input$show_linear_projection_country))) {
        isTRUE(isolate(input$show_linear_projection_country))
      } else {
        FALSE
      }

      # For Grand Total, show toggles for each projection type
      if (input$country_choice == "GRAND_TOTAL") {
        tagList(
          div(
            class = "sidebar-projection-block",
            h4(class = "sidebar-projection-header", "Year-End Projections"),
            div(class = "sidebar-option-group",
              checkboxInput(
                inputId = "show_linear_projection",
                label = "Show Linear Fit Projection",
                value = selected_show_linear_projection
              ),
              checkboxInput(
                inputId = "show_total_projection",
                label = "Show Historical Pattern Projection",
                value = selected_show_total_projection
              ),
              if (!is_custom_context) {
                checkboxInput(
                  inputId = "show_sum_projection",
                  label = "Show Sum of Countries Projection",
                  value = selected_show_sum_projection
                )
              }
            )
          )
        )
      } else {
        # For individual countries, show single toggle
        tagList(
          div(
            class = "sidebar-projection-block",
            h4(class = "sidebar-projection-header", "Year-End Projections"),
            div(class = "sidebar-option-group",
              checkboxInput(
                inputId = "show_projections",
                label = "Show Historical Pattern Projection",
                value = selected_show_projections
              )
            ),
            div(class = "sidebar-option-group",
              checkboxInput(
                inputId = "show_linear_projection_country",
                label = "Show Linear Fit Projection",
                value = selected_show_linear_projection_country
              )
            )
          )
      )
    }
  })
  
  # Reactive: render heatmap tab title based on frequency
  output$heatmap_tab_title <- renderText({
    if (input$data_frequency == "monthly") {
      "Monthly Heatmap"
    } else {
      "Weekly Heatmap"
    }
  })
  
  # Reactive: render comparison title based on frequency (no note here)
  output$comparison_title <- renderUI({
    title_text <- if (input$data_frequency == "monthly") {
      "Month-by-Month Comparison"
    } else {
      "Week-by-Week Comparison"
    }
    h3(title_text)
  })

  current_display_year_type <- function(source_choice = current_source_choice_safe(default = "export_sales")) {
    if (identical(source_choice, "psd")) {
      return("marketing")
    }

    resolved_year_type <- if (exists("current_non_psd_year_type_safe", mode = "function")) {
      current_non_psd_year_type_safe(source_choice = source_choice, default = "marketing")
    } else {
      input$year_type_choice
    }

    normalize_non_psd_year_type(resolved_year_type, default = "marketing")
  }

  vp_display_month_mapping <- function() {
    if (exists("vp_trade_rows_available", mode = "function") && !isTRUE(vp_trade_rows_available(require_non_empty = FALSE))) {
      return(NULL)
    }
    if (!exists("vp_trade_rows_available", mode = "function") && (!exists("rice_data_vp_trade_monthly", inherits = TRUE) || !is.data.frame(rice_data_vp_trade_monthly))) {
      return(NULL)
    }

    required_cols <- c(
      "analysis_month", "MonthNum", "month_abbrev", "month_name", "calendar_signature",
      "Trade", "Group", "Subgroup", "MarketSegment", "CommodityName", "commodity"
    )
    vp_rows <- if (exists("vp_trade_rows_for_context", mode = "function")) {
      vp_trade_rows_for_context(require_non_empty = FALSE)
    } else {
      rice_data_vp_trade_monthly
    }

    if (!all(required_cols %in% names(vp_rows))) {
      return(NULL)
    }

    vp_trade_flow <- if (!is.null(input$vp_trade_flow_choice) && input$vp_trade_flow_choice %in% c("export", "import")) {
      input$vp_trade_flow_choice
    } else {
      "export"
    }
    vp_commodity_name <- if (!is.null(input$vp_commodity_name_choice) && nzchar(input$vp_commodity_name_choice)) input$vp_commodity_name_choice else NULL
    vp_commodity_detail <- if (!is.null(input$commodity_choice) && nzchar(input$commodity_choice)) input$commodity_choice else NULL

    if (exists("filter_vp_rows_for_resolved_hierarchy", mode = "function")) {
      vp_rows <- filter_vp_rows_for_resolved_hierarchy(
        vp_rows = vp_rows,
        vp_trade_flow_choice = vp_trade_flow,
        vp_group_choice = input$vp_group_choice,
        vp_subgroup_choice = input$vp_subgroup_choice,
        vp_market_segment_choice = input$vp_market_segment_choice,
        vp_commodity_name_choice = vp_commodity_name,
        vp_commodity_detail_choice = vp_commodity_detail,
        vp_filter_purpose = "display_month_mapping"
      )
    } else {
      vp_group <- if (!is.null(input$vp_group_choice) && nzchar(input$vp_group_choice) && !identical(input$vp_group_choice, "__all__")) input$vp_group_choice else NULL
      vp_subgroup <- if (!is.null(input$vp_subgroup_choice) && nzchar(input$vp_subgroup_choice) && !identical(input$vp_subgroup_choice, "__all__")) input$vp_subgroup_choice else NULL
      vp_market_segment <- if (!is.null(input$vp_market_segment_choice) && nzchar(input$vp_market_segment_choice) && !identical(input$vp_market_segment_choice, "__all__")) input$vp_market_segment_choice else NULL

      vp_rows <- vp_rows %>% filter(.data$Trade == vp_trade_flow)
      if (!is.null(vp_group)) vp_rows <- vp_rows %>% filter(.data$Group == vp_group)
      if (!is.null(vp_subgroup)) vp_rows <- vp_rows %>% filter(.data$Subgroup == vp_subgroup)
      if (!is.null(vp_market_segment)) vp_rows <- vp_rows %>% filter(.data$MarketSegment == vp_market_segment)
      if (!is.null(vp_commodity_name)) vp_rows <- vp_rows %>% filter(.data$CommodityName == vp_commodity_name)
      if (!is.null(vp_commodity_detail)) vp_rows <- vp_rows %>% filter(.data$commodity == vp_commodity_detail)
    }

    if (nrow(vp_rows) == 0) {
      return(NULL)
    }

    signature_counts <- vp_rows %>%
      filter(!is.na(.data$calendar_signature), nzchar(as.character(.data$calendar_signature))) %>%
      count(.data$calendar_signature, sort = TRUE)
    if (nrow(signature_counts) > 0) {
      dominant_signature <- as.character(signature_counts$calendar_signature[[1]])
      vp_rows <- vp_rows %>% filter(.data$calendar_signature == dominant_signature)
    }

    mapped <- vp_rows %>%
      filter(!is.na(.data$analysis_month), !is.na(.data$MonthNum), !is.na(.data$month_abbrev), !is.na(.data$month_name)) %>%
      mutate(
        analysis_month = suppressWarnings(as.integer(.data$analysis_month)),
        MonthNum = suppressWarnings(as.integer(.data$MonthNum)),
        month_abbrev = as.character(.data$month_abbrev),
        month_name = as.character(.data$month_name),
        calendar_signature = as.character(.data$calendar_signature)
      ) %>%
      filter(!is.na(.data$analysis_month), !is.na(.data$MonthNum), nzchar(.data$month_abbrev), nzchar(.data$month_name)) %>%
      group_by(.data$analysis_month) %>%
      summarise(
        MonthNum = dplyr::first(.data$MonthNum),
        month_abbrev = dplyr::first(.data$month_abbrev),
        month_name = dplyr::first(.data$month_name),
        calendar_signature = dplyr::first(.data$calendar_signature),
        .groups = "drop"
      ) %>%
      arrange(.data$analysis_month)

    if (nrow(mapped) != 12 || !identical(mapped$analysis_month, 1:12)) {
      return(NULL)
    }

    mapped
  }

  display_month_mapping_cache <- new.env(parent = emptyenv())
  display_month_mapping_cache_hit_counts <- new.env(parent = emptyenv())

  display_month_mapping_cache_hit_milestone <- function(cache_key) {
    if (!nzchar(as.character(cache_key %||% ""))) return(NA_integer_)

    current_count <- get0(cache_key, envir = display_month_mapping_cache_hit_counts, inherits = FALSE, ifnotfound = 0L)
    next_count <- as.integer(current_count) + 1L
    assign(cache_key, next_count, envir = display_month_mapping_cache_hit_counts)

    if (next_count %in% c(1L, 2L, 5L, 10L, 25L, 50L, 100L, 250L, 500L, 1000L)) {
      return(next_count)
    }

    NA_integer_
  }

  normalize_display_month_cache_value <- function(value, default = "<none>") {
    value <- trimws(as.character(value %||% character(0)))
    value <- value[!is.na(value) & nzchar(value)]
    if (length(value) == 0L) return(default)
    value[[1L]]
  }

  encode_display_month_cache_value <- function(value) {
    value <- normalize_display_month_cache_value(value)
    paste0(nchar(value, type = "bytes"), ":", value)
  }

  current_display_month_cache_key <- function(source_choice) {
    source_choice <- normalize_display_month_cache_value(source_choice, default = "export_sales")
    resolved <- if (identical(source_choice, "vp_trade") && exists("resolve_vp_hierarchy_tokens", mode = "function")) {
      resolve_vp_hierarchy_tokens(
        vp_group_choice = input$vp_group_choice,
        vp_subgroup_choice = input$vp_subgroup_choice,
        vp_market_segment_choice = input$vp_market_segment_choice
      )
    } else {
      list(
        group_choice = input$vp_group_choice %||% vp_all_choice,
        subgroup_choice = input$vp_subgroup_choice %||% vp_all_choice,
        market_segment_choice = input$vp_market_segment_choice %||% vp_all_choice,
        resolution_mode = "raw_input",
        path_name = "raw_input",
        strict_rollup_context = FALSE,
        sparse_selection = FALSE
      )
    }

    parts <- list(
      source_choice = source_choice,
      data_source_choice = input$data_source_choice %||% "unknown",
      trade_flow = if (!is.null(input$vp_trade_flow_choice) && input$vp_trade_flow_choice %in% c("export", "import")) input$vp_trade_flow_choice else "export",
      group_choice = resolved$group_choice %||% vp_all_choice,
      subgroup_choice = resolved$subgroup_choice %||% vp_all_choice,
      market_segment_choice = resolved$market_segment_choice %||% vp_all_choice,
      resolution_mode = resolved$resolution_mode %||% "unknown",
      path_name = resolved$path_name %||% "unknown",
      strict_rollup_context = if (isTRUE(resolved$strict_rollup_context)) "TRUE" else "FALSE",
      sparse_selection = if (isTRUE(resolved$sparse_selection)) "TRUE" else "FALSE",
      commodity_name = input$vp_commodity_name_choice %||% "<none>",
      commodity_detail = input$commodity_choice %||% "<none>",
      fallback_year_type = current_display_year_type(source_choice = source_choice)
    )

    paste(vapply(parts, encode_display_month_cache_value, character(1)), collapse = "\036")
  }

  record_display_month_mapping_cache_event <- function(event_name, source_choice, cache_key, hit_count = NA_integer_) {
    if (!exists("record_cache_body_execution", mode = "function")) {
      return(invisible(NULL))
    }

    record_cache_body_execution(
      session,
      paste0("display_month_mapping_cache_", event_name),
      details = c(
        list(
          hit_count = hit_count,
          source = source_choice,
          active_tab = input$main_tabs_panel %||% "unknown",
          cache_key_prefix = substr(cache_key, 1L, 120L)
        ),
        if (exists("vp_hierarchy_fanout_context", mode = "function")) vp_hierarchy_fanout_context() else list()
      )
    )
    invisible(NULL)
  }

  current_display_month_mapping <- function(source_choice = current_source_choice_safe(default = "export_sales")) {
    if (identical(source_choice, "vp_trade")) {
      cache_key <- current_display_month_cache_key(source_choice)
      if (exists(cache_key, envir = display_month_mapping_cache, inherits = FALSE)) {
        hit_count <- display_month_mapping_cache_hit_milestone(cache_key)
        if (is.finite(hit_count)) {
          record_display_month_mapping_cache_event("hit", source_choice, cache_key, hit_count = hit_count)
        }
        return(get(cache_key, envir = display_month_mapping_cache, inherits = FALSE))
      }

      record_display_month_mapping_cache_event("miss", source_choice, cache_key)
      vp_mapping <- vp_display_month_mapping()
      if (!is.null(vp_mapping) && is.data.frame(vp_mapping) && nrow(vp_mapping) == 12) {
        assign(cache_key, vp_mapping, envir = display_month_mapping_cache)
        return(vp_mapping)
      }

      fallback_mapping <- month_mapping_for_year_type(current_display_year_type(source_choice = source_choice))
      assign(cache_key, fallback_mapping, envir = display_month_mapping_cache)
      return(fallback_mapping)
    }

    month_mapping_for_year_type(current_display_year_type(source_choice = source_choice))
  }

  is_calendar_month_mapping <- function(display_month_mapping) {
    if (is.null(display_month_mapping) || !is.data.frame(display_month_mapping) || nrow(display_month_mapping) == 0) {
      return(FALSE)
    }

    if ("calendar_signature" %in% names(display_month_mapping)) {
      signature_values <- unique(trimws(as.character(display_month_mapping$calendar_signature)))
      signature_values <- signature_values[!is.na(signature_values) & nzchar(signature_values)]
      if (length(signature_values) == 1L && identical(signature_values[[1L]], "1-2-3-4-5-6-7-8-9-10-11-12")) {
        return(TRUE)
      }
    }

    if (all(c("analysis_month", "MonthNum") %in% names(display_month_mapping))) {
      ordered_mapping <- display_month_mapping %>% arrange(.data$analysis_month)
      analysis_month <- suppressWarnings(as.integer(ordered_mapping$analysis_month))
      month_num <- suppressWarnings(as.integer(ordered_mapping$MonthNum))
      if (length(analysis_month) == 12L && length(month_num) == 12L &&
          identical(analysis_month, 1:12) && identical(month_num, 1:12)) {
        return(TRUE)
      }
    }

    FALSE
  }

  current_display_month_axis_title <- function(source_choice = current_source_choice_safe(default = "export_sales"), display_month_mapping = NULL) {
    if (identical(source_choice, "vp_trade")) {
      vp_mapping <- display_month_mapping
      if (is.null(vp_mapping)) {
        vp_mapping <- current_display_month_mapping(source_choice = source_choice)
      }
      if (isTRUE(is_calendar_month_mapping(vp_mapping))) {
        return("Calendar Year Month")
      }
      return("Commodity Year Month")
    }

    "Market Year Month"
  }

  is_calendar_year_display_context <- function(source_choice = current_source_choice_safe(default = "export_sales"), display_month_mapping = NULL) {
    if (!identical(source_choice, "vp_trade")) {
      return(FALSE)
    }

    if (is.null(display_month_mapping)) {
      display_month_mapping <- current_display_month_mapping(source_choice = source_choice)
    }
    isTRUE(is_calendar_month_mapping(display_month_mapping))
  }

  build_display_year_short_prefix <- function(source_choice = current_source_choice_safe(default = "export_sales"), display_month_mapping = NULL) {
    if (isTRUE(is_calendar_year_display_context(source_choice = source_choice, display_month_mapping = display_month_mapping))) {
      return("CY ")
    }

    "MY "
  }

  build_display_year_label <- function(year_value, source_choice = current_source_choice_safe(default = "export_sales"), display_month_mapping = NULL) {
    paste0(build_display_year_short_prefix(source_choice = source_choice, display_month_mapping = display_month_mapping), year_value)
  }

  build_single_reference_year_label <- function(ref_year, source_choice = current_source_choice_safe(default = "export_sales"), display_month_mapping = NULL) {
    paste0("Single Year Ref (", build_display_year_label(ref_year, source_choice = source_choice, display_month_mapping = display_month_mapping), ")")
  }

  build_current_year_trace_label <- function(year_value, source_choice = current_source_choice_safe(default = "export_sales"), display_month_mapping = NULL) {
    paste0("Current (", build_display_year_label(year_value, source_choice = source_choice, display_month_mapping = display_month_mapping), ")")
  }

  build_historical_window_note_text <- function(years_used, label_term = "Historical average", include_note_prefix = TRUE, source_choice = current_source_choice_safe(default = "export_sales"), display_month_mapping = NULL) {
    if (is.null(years_used) || length(years_used) == 0) {
      return(NULL)
    }

    prefix_text <- if (isTRUE(include_note_prefix)) "Note: " else ""

    if (length(years_used) == 1) {
      return(paste0(prefix_text, label_term, " based on ", build_display_year_label(years_used, source_choice = source_choice, display_month_mapping = display_month_mapping)))
    }

    paste0(
      prefix_text,
      label_term,
      " based on ",
      build_display_year_label(min(years_used), source_choice = source_choice, display_month_mapping = display_month_mapping),
      "-",
      build_display_year_label(max(years_used), source_choice = source_choice, display_month_mapping = display_month_mapping),
      " (", length(years_used), " years)"
    )
  }

  build_projection_basis_context <- function(basis_mode, ref_year, source_choice = current_source_choice_safe(default = "export_sales"), display_month_mapping = NULL) {
    if (identical(basis_mode, "single_year") && !is.null(ref_year)) {
      paste0("single reference year (", build_display_year_label(ref_year, source_choice = source_choice, display_month_mapping = display_month_mapping), ")")
    } else {
      paste0("historical window (", comparison_hist_years_committed(), " years)")
    }
  }

  build_weekly_axis_label_note <- function() {
    if (!identical(input$data_frequency, "weekly")) return(NULL)

    source_choice <- current_source_choice_safe()
    year_label <- if (isTRUE(is_calendar_year_display_context(source_choice = source_choice))) {
      "calendar year"
    } else {
      "marketing year"
    }

    tags$em(paste0("Weekly x-axis labels are based on week-ending dates from the current ", year_label, "."))
  }

  build_note_paragraph <- function(info_entries = list(), warning_entries = list()) {
    pieces <- list()

    append_entry <- function(entry) {
      if (is.null(entry)) return()
      if (length(pieces) > 0) {
        pieces[[length(pieces) + 1]] <<- tags$br()
      }
      pieces[[length(pieces) + 1]] <<- entry
    }

    for (entry in info_entries) append_entry(entry)
    for (entry in warning_entries) append_entry(entry)

    if (length(pieces) == 0) return(NULL)
    do.call(tags$p, pieces)
  }

  # Note under Current vs Average plot describing historical average window
  output$comparison_hist_note <- renderUI({
    hist_avg <- historical_avg()
    years_used <- attr(hist_avg, "years_used")
    warning_note <- get_product_weight_basis_note(input$commodity_choice, input$basis_choice)
    proj <- projection_data()
    source_choice <- current_source_choice_safe(default = input$data_source_choice %||% "export_sales")

    ensure_warning_prefix <- function(msg) {
      if (is.null(msg) || !nzchar(trimws(msg))) return(NULL)
      trimmed <- trimws(msg)
      if (startsWith(trimmed, "WARNING:")) trimmed else paste0("WARNING: ", trimmed)
    }

    warning_lines <- character()
    if (!is.null(proj)) {
      if (!is.null(proj$projection_warnings) && length(proj$projection_warnings) > 0) {
        warning_lines <- c(warning_lines, unlist(proj$projection_warnings, use.names = FALSE))
      } else if (!is.null(proj$projection_warning) && nzchar(trimws(proj$projection_warning))) {
        warning_lines <- c(warning_lines, proj$projection_warning)
      }

      hist_available <- isTRUE(proj$historical_available)
      linear_available <- isTRUE(proj$linear_available)

      if (identical(input$country_choice, "GRAND_TOTAL")) {
        if (isTRUE(input$show_total_projection) && !hist_available) {
          warning_lines <- c(warning_lines, "Selected historical projection is unavailable for the current filters.")
        }
        if (isTRUE(input$show_linear_projection) && !linear_available) {
          warning_lines <- c(warning_lines, "Selected linear projection is unavailable for the current filters.")
        }
      } else {
        if (isTRUE(input$show_projections) && !hist_available) {
          warning_lines <- c(warning_lines, "Selected historical projection is unavailable for the current filters.")
        }
        if (isTRUE(input$show_linear_projection_country) && !linear_available) {
          warning_lines <- c(warning_lines, "Selected linear projection is unavailable for the current filters.")
        }
      }
    }

    warning_lines <- unique(Filter(Negate(is.null), lapply(warning_lines, ensure_warning_prefix)))
    warning_lines <- warning_lines[!is.na(warning_lines) & nzchar(warning_lines)]

    if (is.null(years_used) || length(years_used) == 0) return(NULL)

    note_text <- build_historical_window_note_text(
      years_used = years_used,
      label_term = if (identical(input$projection_basis_mode, "single_year")) "Historical pattern" else "Historical average",
      include_note_prefix = TRUE,
      source_choice = source_choice
    )

    info_entries <- Filter(Negate(is.null), list(
      tags$em(note_text),
      if (identical(input$data_frequency, "weekly")) tags$em("To standardize year lengths, any volume reported in Week 53 or later is combined into Week 52."),
      build_weekly_axis_label_note()
    ))

    warning_entries <- Filter(Negate(is.null), c(
      if (identical(input$main_tabs_panel, "Custom Comparison Tool")) list(tags$em("Warning: Sum of Countries Projection is not available in the Custom Comparison Tool tab.")) else list(),
      if (!is.null(warning_note)) list(warning_note) else list(),
      lapply(warning_lines, function(msg) tags$span(style = "color:#856404; font-weight:600;", msg))
    ))

    build_note_paragraph(
      info_entries = info_entries,
      warning_entries = warning_entries
    )
  })

  # Note under Historical Trend plot describing historical average window
  output$historical_trend_note <- renderUI({
    hist_avg <- historical_avg()
    years_used <- attr(hist_avg, "years_used")
    warning_note <- get_product_weight_basis_note(input$commodity_choice, input$basis_choice)
    source_choice <- current_source_choice_safe(default = input$data_source_choice %||% "export_sales")

    if (is.null(years_used) || length(years_used) == 0) return(NULL)

    note_text <- build_historical_window_note_text(
      years_used = years_used,
      label_term = if (identical(input$projection_basis_mode, "single_year")) "Historical pattern" else "Historical average",
      include_note_prefix = TRUE,
      source_choice = source_choice
    )

    info_entries <- Filter(Negate(is.null), list(
      tags$em(note_text),
      if (identical(input$data_frequency, "weekly")) tags$em("To standardize year lengths, any volume reported in Week 53 or later is combined into Week 52."),
      build_weekly_axis_label_note()
    ))

    warning_entries <- Filter(Negate(is.null), c(
      if (identical(input$main_tabs_panel, "Custom Comparison Tool")) list(tags$em("Warning: Sum of Countries Projection is not available in the Custom Comparison Tool tab.")) else list(),
      if (!is.null(warning_note)) list(warning_note) else list()
    ))

    build_note_paragraph(
      info_entries = info_entries,
      warning_entries = warning_entries
    )
  })

  build_metric_comparison_hist_note_ui <- function() {
    hist_avg <- historical_avg()
    years_used <- attr(hist_avg, "years_used")
    warning_note <- get_product_weight_basis_note(input$commodity_choice, input$basis_choice)
    source_choice <- current_source_choice_safe(default = input$data_source_choice %||% "export_sales")

    if (is.null(years_used) || length(years_used) == 0) return(NULL)

    note_text <- build_historical_window_note_text(
      years_used = years_used,
      label_term = if (identical(input$projection_basis_mode, "single_year")) "Historical pattern" else "Historical average",
      include_note_prefix = FALSE,
      source_choice = source_choice
    )

    info_entries <- Filter(Negate(is.null), list(
      tags$em(note_text),
      if (identical(input$data_frequency, "weekly")) tags$em("To standardize year lengths, any volume reported in Week 53 or later is combined into Week 52."),
      build_weekly_axis_label_note()
    ))

    warning_entries <- Filter(Negate(is.null), c(
      if (identical(input$main_tabs_panel, "Custom Comparison Tool")) list(tags$em("Warning: Sum of Countries Projection is not available in the Custom Comparison Tool tab.")) else list(),
      if (!is.null(warning_note)) list(warning_note) else list()
    ))

    build_note_paragraph(
      info_entries = info_entries,
      warning_entries = warning_entries
    )
  }

  # Note near top of Country Comparison tab describing historical average window
  output$metric_comparison_hist_note <- renderUI({
    if (isTRUE(input$lock_to_top_left_scale) && isTRUE(input$overlay_visible_panels)) return(NULL)
    build_metric_comparison_hist_note_ui()
  })

  # Overlay-specific note positioned under the overlay visualization.
  output$metric_comparison_hist_note_overlay <- renderUI({
    if (!(isTRUE(input$lock_to_top_left_scale) && isTRUE(input$overlay_visible_panels))) return(NULL)
    build_metric_comparison_hist_note_ui()
  })

  output$heatmap_note_block <- renderUI({
    warning_note <- get_product_weight_basis_note(input$commodity_choice, input$basis_choice)

    tags$p(
      tags$em("Warmer colors (red/orange) indicate higher export volumes; cooler colors (blue) indicate lower volumes"),
      if (!is.null(warning_note)) list(
        tags$br(),
        warning_note
      ),
      if (identical(input$data_frequency, "weekly")) list(
        tags$br(),
        build_weekly_axis_label_note()
      )
    )
  })

  # Session-scoped state: apply OFF defaults for overlay toggles only on first overlay activation.
  overlay_defaults_initialized <- reactiveVal(FALSE)

  observeEvent(list(input$main_tabs_panel, input$lock_to_top_left_scale, input$overlay_visible_panels), {
    if (!identical(input$main_tabs_panel, "Custom Comparison Tool")) return()
    overlay_mode <- isTRUE(input$lock_to_top_left_scale) && isTRUE(input$overlay_visible_panels)
    if (!overlay_mode) return()
    if (isTRUE(overlay_defaults_initialized())) return()

    updateCheckboxInput(session, "overlay_show_hist_avg", value = FALSE)
    updateCheckboxInput(session, "overlay_show_projections", value = FALSE)
    overlay_defaults_initialized(TRUE)
  }, ignoreInit = FALSE)
  
  # Dynamic body for Country Comparison tab (2-up by default, optional 2x2 grid)
  output$metric_comparison_body <- renderUI({
    # Default to 2-up view when checkbox is not set
    show_grid <- isTRUE(input$show_metric_grid)
    overlay_mode <- isTRUE(input$lock_to_top_left_scale) && isTRUE(input$overlay_visible_panels)

    # Helper to reuse panel selections across sidebar-triggered re-renders
    get_panel_selection <- function(input_id, choices, default_val) {
      if (startsWith(input_id, "metric_")) {
        stored <- isolate(panel_state[[input_id]])
        current <- isolate(input[[input_id]])
        selected_metric <- if (!is.null(current)) current else stored
        return(sanitize_metric_for_choices(selected_metric, choices, preferred_metric = default_val))
      }

      stored <- isolate(panel_state[[input_id]])
      if (!is.null(stored) && stored %in% choices) return(stored)
      current <- isolate(input[[input_id]])
      if (!is.null(current) && current %in% choices) return(current)
      if (!is.null(default_val) && default_val %in% choices) return(default_val)
      if ("GRAND_TOTAL" %in% choices) return("GRAND_TOTAL")
      unname(choices[1])
    }

    # Country choices for panel-specific selectors mirror sidebar sorting/filtering/labels.
    panel_country_choices <- country_choice_options()
    if (is.null(panel_country_choices) || length(panel_country_choices) == 0) {
      panel_country_choices <- setNames("GRAND_TOTAL", "Grand Total")
    }

    default_panel_country <- if (!is.null(input$country_choice) && input$country_choice %in% panel_country_choices) {
      input$country_choice
    } else if ("GRAND_TOTAL" %in% panel_country_choices) {
      "GRAND_TOTAL"
    } else {
      unname(panel_country_choices[1])
    }

    # Rice type choices for panel-specific selectors (same as main Rice Type)
    panel_commodity_values <- commodity_choice_real_values()
    if (length(panel_commodity_values) == 0) {
      panel_commodity_values <- default_commodity_choice_named()
    }
    panel_commodity_choices <- group_rice_type_choices(
      flat_choices = panel_commodity_values,
      custom_names = custom_types_enriched() %>%
        filter(.data$parse_ok) %>%
        pull(.data$custom_name),
      include_builder = FALSE
    )

    panel_vp_commodity_name_choices <- custom_comparison_vp_commodity_name_choices()
    default_panel_vp_commodity_name <- resolve_custom_comparison_vp_commodity_name(input$vp_commodity_name_choice)

    panel_commodity_choices_right <- if (identical(current_source_choice_safe(default = input$data_source_choice %||% "export_sales"), "vp_trade")) {
      custom_comparison_panel_vp_type_choices(isolate(panel_state$vp_commodity_name_right_2up %||% input$vp_commodity_name_choice))
    } else {
      panel_commodity_choices
    }
    panel_commodity_choices_grid_3 <- if (identical(current_source_choice_safe(default = input$data_source_choice %||% "export_sales"), "vp_trade")) {
      custom_comparison_panel_vp_type_choices(isolate(panel_state$vp_commodity_name_grid_3 %||% input$vp_commodity_name_choice))
    } else {
      panel_commodity_choices
    }
    panel_commodity_choices_grid_4 <- if (identical(current_source_choice_safe(default = input$data_source_choice %||% "export_sales"), "vp_trade")) {
      custom_comparison_panel_vp_type_choices(isolate(panel_state$vp_commodity_name_grid_4 %||% input$vp_commodity_name_choice))
    } else {
      panel_commodity_choices
    }

    default_panel_commodity <- if (!is.null(input$commodity_choice) && input$commodity_choice %in% panel_commodity_values) {
      input$commodity_choice
    } else {
      aggregate_label <- default_commodity_choice_value()
      if (aggregate_label %in% panel_commodity_values) aggregate_label else unname(panel_commodity_values[1])
    }

    # Reuse the centralized metric legality rules for Custom Comparison selectors.
    valid_metrics <- custom_comparison_metric_choices()

    if (overlay_mode) {
      current_overlay_hist <- isolate(input$overlay_show_hist_avg)
      selected_overlay_hist <- if (!is.null(current_overlay_hist)) isTRUE(current_overlay_hist) else FALSE

      current_overlay_proj <- isolate(input$overlay_show_projections)
      selected_overlay_proj <- if (!is.null(current_overlay_proj)) isTRUE(current_overlay_proj) else FALSE

      if (!show_grid) {
        tagList(
          fluidRow(
            column(
              width = 12,
              div(
                style = "display: flex; align-items: flex-end; gap: 8px; flex-wrap: wrap;",
                div(
                  style = "flex: 0 0 auto;",
                  selectInput(
                    inputId = "metric_right",
                    label = "Right panel metric:",
                    choices = valid_metrics,
                    selected = get_panel_selection("metric_right", valid_metrics, "monthlyexports"),
                    width = "260px"
                  )
                ),
                div(
                  style = "flex: 0 0 auto;",
                  selectInput(
                    inputId = "country_right_2up",
                    label = "Right panel country:",
                    choices = panel_country_choices,
                    selected = get_panel_selection("country_right_2up", panel_country_choices, default_panel_country),
                    width = "260px"
                  )
                ),
                div(
                  style = "flex: 0 0 auto;",
                  selectInput(
                    inputId = "commodity_right_2up",
                    label = "Right panel type:",
                    choices = panel_commodity_choices_right,
                    selected = get_panel_selection("commodity_right_2up", panel_commodity_choices_right, default_panel_commodity),
                    width = "260px"
                  )
                ),
                if (identical(current_source_choice_safe(default = input$data_source_choice %||% "export_sales"), "vp_trade")) div(
                  style = "flex: 0 0 auto;",
                  selectInput(
                    inputId = "vp_commodity_name_right_2up",
                    label = "Right panel commodity:",
                    choices = panel_vp_commodity_name_choices,
                    selected = get_panel_selection("vp_commodity_name_right_2up", panel_vp_commodity_name_choices, default_panel_vp_commodity_name),
                    width = "260px"
                  )
                )
              )
            )
          ),
          fluidRow(
            column(
              width = 12,
              div(
                style = "display: flex; gap: 16px; margin-bottom: 6px;",
                checkboxInput(
                  inputId = "overlay_show_hist_avg",
                  label = "Overlay Historical Average",
                  value = selected_overlay_hist
                ),
                checkboxInput(
                  inputId = "overlay_show_projections",
                  label = "Overlay Year-End Projections",
                  value = selected_overlay_proj
                )
              )
            )
          ),
          fluidRow(
            column(
              width = 12,
              plotlyOutput("comparison_overlay_plot", height = "650px")
            )
          ),
          fluidRow(
            column(
              width = 12,
              uiOutput("metric_comparison_hist_note_overlay")
            )
          )
        )
      } else {
        tagList(
          fluidRow(
            column(
              width = 4,
              selectInput(
                inputId = "metric_right",
                label = "Top-right metric:",
                choices = valid_metrics,
                selected = get_panel_selection("metric_right", valid_metrics, "monthlyexports"),
                width = "100%"
              ),
              selectInput(
                inputId = "country_right_2up",
                label = "Top-right country:",
                choices = panel_country_choices,
                selected = get_panel_selection("country_right_2up", panel_country_choices, default_panel_country),
                width = "100%"
              ),
              selectInput(
                inputId = "commodity_right_2up",
                label = "Top-right type:",
                choices = panel_commodity_choices_right,
                selected = get_panel_selection("commodity_right_2up", panel_commodity_choices_right, default_panel_commodity),
                width = "100%"
              ),
              if (identical(current_source_choice_safe(default = input$data_source_choice %||% "export_sales"), "vp_trade")) selectInput(
                inputId = "vp_commodity_name_right_2up",
                label = "Top-right commodity:",
                choices = panel_vp_commodity_name_choices,
                selected = get_panel_selection("vp_commodity_name_right_2up", panel_vp_commodity_name_choices, default_panel_vp_commodity_name),
                width = "100%"
              )
            ),
            column(
              width = 4,
              selectInput(
                inputId = "metric_grid_3",
                label = "Bottom-left metric:",
                choices = valid_metrics,
                selected = get_panel_selection("metric_grid_3", valid_metrics, if ("outstandingSales" %in% valid_metrics) "outstandingSales" else "monthlyexports"),
                width = "100%"
              ),
              selectInput(
                inputId = "country_grid_3",
                label = "Bottom-left country:",
                choices = panel_country_choices,
                selected = get_panel_selection("country_grid_3", panel_country_choices, default_panel_country),
                width = "100%"
              ),
              selectInput(
                inputId = "commodity_grid_3",
                label = "Bottom-left type:",
                choices = panel_commodity_choices_grid_3,
                selected = get_panel_selection("commodity_grid_3", panel_commodity_choices_grid_3, default_panel_commodity),
                width = "100%"
              ),
              if (identical(current_source_choice_safe(default = input$data_source_choice %||% "export_sales"), "vp_trade")) selectInput(
                inputId = "vp_commodity_name_grid_3",
                label = "Bottom-left commodity:",
                choices = panel_vp_commodity_name_choices,
                selected = get_panel_selection("vp_commodity_name_grid_3", panel_vp_commodity_name_choices, default_panel_vp_commodity_name),
                width = "100%"
              )
            ),
            column(
              width = 4,
              selectInput(
                inputId = "metric_grid_4",
                label = "Bottom-right metric:",
                choices = valid_metrics,
                selected = get_panel_selection("metric_grid_4", valid_metrics, if ("total_commitment" %in% valid_metrics) "total_commitment" else if ("ytd_value" %in% valid_metrics) "ytd_value" else "monthlyexports"),
                width = "100%"
              ),
              selectInput(
                inputId = "country_grid_4",
                label = "Bottom-right country:",
                choices = panel_country_choices,
                selected = get_panel_selection("country_grid_4", panel_country_choices, default_panel_country),
                width = "100%"
              ),
              selectInput(
                inputId = "commodity_grid_4",
                label = "Bottom-right type:",
                choices = panel_commodity_choices_grid_4,
                selected = get_panel_selection("commodity_grid_4", panel_commodity_choices_grid_4, default_panel_commodity),
                width = "100%"
              ),
              if (identical(current_source_choice_safe(default = input$data_source_choice %||% "export_sales"), "vp_trade")) selectInput(
                inputId = "vp_commodity_name_grid_4",
                label = "Bottom-right commodity:",
                choices = panel_vp_commodity_name_choices,
                selected = get_panel_selection("vp_commodity_name_grid_4", panel_vp_commodity_name_choices, default_panel_vp_commodity_name),
                width = "100%"
              )
            )
          ),
          fluidRow(
            column(
              width = 12,
              div(
                style = "display: flex; gap: 16px; margin-bottom: 6px;",
                checkboxInput(
                  inputId = "overlay_show_hist_avg",
                  label = "Overlay Historical Average",
                  value = selected_overlay_hist
                ),
                checkboxInput(
                  inputId = "overlay_show_projections",
                  label = "Overlay Year-End Projections",
                  value = selected_overlay_proj
                )
              )
            )
          ),
          fluidRow(
            column(
              width = 12,
              plotlyOutput("comparison_overlay_plot", height = "700px")
            )
          ),
          fluidRow(
            column(
              width = 12,
              uiOutput("metric_comparison_hist_note_overlay")
            )
          )
        )
      }
    } else if (!show_grid) {
      # 2-up Comparison: left panel metric is controlled by main Variable to Analyze
      fluidRow(
        column(
          width = 6,
          # Invisible metric & country dropdowns to match spacing of right panel controls
          div(
            style = "display: flex; visibility: hidden; align-items: flex-end;",
            div(
              style = "flex: 0 0 auto; margin-right: 4px;",
              selectInput(
                  inputId = "commodity_left_dummy",
                  label = "Right panel type:",
                  choices = panel_commodity_choices,
                  selected = default_panel_commodity,
                width = "260px"
              )
            ),
              if (identical(current_source_choice_safe(default = input$data_source_choice %||% "export_sales"), "vp_trade")) div(
                style = "flex: 0 0 auto;",
                selectInput(
                  inputId = "vp_commodity_name_left_dummy",
                  label = "Right panel commodity:",
                  choices = panel_vp_commodity_name_choices,
                  selected = default_panel_vp_commodity_name,
                  width = "260px"
                )
              )
            ),
            div(
              style = "display: flex; visibility: hidden; align-items: flex-end; margin-top: -4px;",
              div(
                style = "flex: 0 0 auto; margin-right: 4px;",
                selectInput(
                  inputId = "metric_left_dummy",
                  label = "Right panel metric:",
                  choices = valid_metrics,
                  selected = "monthlyexports",
                  width = "260px"
                )
              ),
            div(
              style = "flex: 0 0 auto;",
              selectInput(
                inputId = "country_left_dummy",
                label = "Right panel country:",
                choices = panel_country_choices,
                selected = default_panel_country,
                width = "260px"
              )
            )
          ),
          plotlyOutput("comparison_left_plot", height = "500px")
        ),
        column(
          width = 6,
          div(
            style = "display: flex; align-items: flex-end;",
            if (identical(current_source_choice_safe(default = input$data_source_choice %||% "export_sales"), "vp_trade")) div(
              style = "flex: 0 0 auto; margin-right: 4px;",
              selectInput(
                inputId = "vp_commodity_name_right_2up",
                label = "Right panel commodity:",
                choices = panel_vp_commodity_name_choices,
                selected = get_panel_selection("vp_commodity_name_right_2up", panel_vp_commodity_name_choices, default_panel_vp_commodity_name),
                width = "260px"
              )
            ),
            div(
              style = "flex: 0 0 auto;",
              selectInput(
                inputId = "commodity_right_2up",
                label = "Right panel type:",
                choices = panel_commodity_choices_right,
                selected = get_panel_selection("commodity_right_2up", panel_commodity_choices_right, default_panel_commodity),
                width = "260px"
              )
            )
          ),
          div(
            style = "display: flex; align-items: flex-end; margin-top: -4px;",
            div(
              style = "flex: 0 0 auto; margin-right: 4px;",
              selectInput(
                inputId = "metric_right",
                label = "Right panel metric:",
                choices = valid_metrics,
                selected = get_panel_selection("metric_right", valid_metrics, "monthlyexports"),
                width = "260px"
              )
            ),
            div(
              style = "flex: 0 0 auto;",
              selectInput(
                inputId = "country_right_2up",
                label = "Right panel country:",
                choices = panel_country_choices,
                selected = get_panel_selection("country_right_2up", panel_country_choices, default_panel_country),
                width = "260px"
              )
            )
          ),
          plotlyOutput("comparison_right_plot", height = "500px")
        )
      )
    } else {
      # 4-panel grid (2x2) view; top-left metric is controlled by main Variable to Analyze
      tagList(
        fluidRow(
          column(
            width = 6,
            # Invisible metric & country dropdowns to match spacing of top-right controls
            div(
              style = "display: flex; visibility: hidden; align-items: flex-end;",
              div(
                style = "flex: 0 0 auto; margin-right: 4px;",
                selectInput(
                  inputId = "commodity_grid_1_dummy",
                  label = "Top-right type:",
                  choices = panel_commodity_choices,
                  selected = default_panel_commodity,
                  width = "260px"
                )
              ),
              if (identical(current_source_choice_safe(default = input$data_source_choice %||% "export_sales"), "vp_trade")) div(
                style = "flex: 0 0 auto;",
                selectInput(
                  inputId = "vp_commodity_name_grid_1_dummy",
                  label = "Top-right commodity:",
                  choices = panel_vp_commodity_name_choices,
                  selected = default_panel_vp_commodity_name,
                  width = "260px"
                )
              )
            ),
            div(
              style = "display: flex; visibility: hidden; align-items: flex-end; margin-top: -4px;",
              div(
                style = "flex: 0 0 auto; margin-right: 4px;",
                selectInput(
                  inputId = "metric_grid_1_dummy",
                  label = "Top-right metric:",
                  choices = valid_metrics,
                  selected = "monthlyexports",
                  width = "260px"
                )
              ),
              div(
                style = "flex: 0 0 auto;",
                selectInput(
                  inputId = "country_grid_1_dummy",
                  label = "Top-right country:",
                  choices = panel_country_choices,
                  selected = default_panel_country,
                  width = "260px"
                )
              )
            ),
            plotlyOutput("metric_grid_plot_1", height = "350px")
          ),
          column(
            width = 6,
            div(
              style = "display: flex; align-items: flex-end;",
              if (identical(current_source_choice_safe(default = input$data_source_choice %||% "export_sales"), "vp_trade")) div(
                style = "flex: 0 0 auto; margin-right: 4px;",
                selectInput(
                  inputId = "vp_commodity_name_right_2up",
                  label = "Top-right commodity:",
                  choices = panel_vp_commodity_name_choices,
                  selected = get_panel_selection("vp_commodity_name_right_2up", panel_vp_commodity_name_choices, default_panel_vp_commodity_name),
                  width = "260px"
                )
              ),
              div(
                style = "flex: 0 0 auto;",
                selectInput(
                  inputId = "commodity_right_2up",
                  label = "Top-right type:",
                  choices = panel_commodity_choices_right,
                  selected = get_panel_selection("commodity_right_2up", panel_commodity_choices_right, default_panel_commodity),
                  width = "260px"
                )
              )
            ),
            div(
              style = "display: flex; align-items: flex-end; margin-top: -4px;",
              div(
                style = "flex: 0 0 auto; margin-right: 4px;",
                selectInput(
                  inputId = "metric_right",
                  label = "Top-right metric:",
                  choices = valid_metrics,
                  selected = get_panel_selection("metric_right", valid_metrics, "monthlyexports"),
                  width = "260px"
                )
              ),
              div(
                style = "flex: 0 0 auto;",
                selectInput(
                  inputId = "country_right_2up",
                  label = "Top-right country:",
                  choices = panel_country_choices,
                  selected = get_panel_selection("country_right_2up", panel_country_choices, default_panel_country),
                  width = "260px"
                )
              )
            ),
            plotlyOutput("metric_grid_plot_2", height = "350px")
          )
        ),
        fluidRow(
          style = "margin-top: 50px;",
          column(
            width = 6,
            div(
              style = "display: flex; align-items: flex-end;",
              if (identical(current_source_choice_safe(default = input$data_source_choice %||% "export_sales"), "vp_trade")) div(
                style = "flex: 0 0 auto; margin-right: 4px;",
                selectInput(
                  inputId = "vp_commodity_name_grid_3",
                  label = "Bottom-left commodity:",
                  choices = panel_vp_commodity_name_choices,
                  selected = get_panel_selection("vp_commodity_name_grid_3", panel_vp_commodity_name_choices, default_panel_vp_commodity_name),
                  width = "260px"
                )
              ),
              div(
                style = "flex: 0 0 auto;",
                selectInput(
                  inputId = "commodity_grid_3",
                  label = "Bottom-left type:",
                  choices = panel_commodity_choices_grid_3,
                  selected = get_panel_selection("commodity_grid_3", panel_commodity_choices_grid_3, default_panel_commodity),
                  width = "260px"
                )
              )
            ),
            div(
              style = "display: flex; align-items: flex-end; margin-top: -4px;",
              div(
                style = "flex: 0 0 auto; margin-right: 4px;",
                selectInput(
                  inputId = "metric_grid_3",
                  label = "Bottom-left metric:",
                  choices = valid_metrics,
                  selected = get_panel_selection("metric_grid_3", valid_metrics, if ("outstandingSales" %in% valid_metrics) "outstandingSales" else "monthlyexports"),
                  width = "260px"
                )
              ),
              div(
                style = "flex: 0 0 auto;",
                selectInput(
                  inputId = "country_grid_3",
                  label = "Bottom-left country:",
                  choices = panel_country_choices,
                  selected = get_panel_selection("country_grid_3", panel_country_choices, default_panel_country),
                  width = "260px"
                )
              )
            ),
            plotlyOutput("metric_grid_plot_3", height = "350px")
          ),
          column(
            width = 6,
            div(
              style = "display: flex; align-items: flex-end;",
              if (identical(current_source_choice_safe(default = input$data_source_choice %||% "export_sales"), "vp_trade")) div(
                style = "flex: 0 0 auto; margin-right: 4px;",
                selectInput(
                  inputId = "vp_commodity_name_grid_4",
                  label = "Bottom-right commodity:",
                  choices = panel_vp_commodity_name_choices,
                  selected = get_panel_selection("vp_commodity_name_grid_4", panel_vp_commodity_name_choices, default_panel_vp_commodity_name),
                  width = "260px"
                )
              ),
              div(
                style = "flex: 0 0 auto;",
                selectInput(
                  inputId = "commodity_grid_4",
                  label = "Bottom-right type:",
                  choices = panel_commodity_choices_grid_4,
                  selected = get_panel_selection("commodity_grid_4", panel_commodity_choices_grid_4, default_panel_commodity),
                  width = "260px"
                )
              )
            ),
            div(
              style = "display: flex; align-items: flex-end; margin-top: -4px;",
              div(
                style = "flex: 0 0 auto; margin-right: 4px;",
                selectInput(
                  inputId = "metric_grid_4",
                  label = "Bottom-right metric:",
                  choices = valid_metrics,
                  selected = get_panel_selection("metric_grid_4", valid_metrics, if ("total_commitment" %in% valid_metrics) "total_commitment" else if ("ytd_value" %in% valid_metrics) "ytd_value" else "monthlyexports"),
                  width = "260px"
                )
              ),
              div(
                style = "flex: 0 0 auto;",
                selectInput(
                  inputId = "country_grid_4",
                  label = "Bottom-right country:",
                  choices = panel_country_choices,
                  selected = get_panel_selection("country_grid_4", panel_country_choices, default_panel_country),
                  width = "260px"
                )
              )
            ),
            plotlyOutput("metric_grid_plot_4", height = "350px")
          )
        )
      )
    }
  })
  
    resolve_filtered_country_code <- function(country_code) {
      resolved_country <- as.character(country_code %||% character(0))
      resolved_country <- resolved_country[!is.na(resolved_country) & nzchar(resolved_country)]

      if (length(resolved_country) == 0) {
        return(NULL)
      }

      resolved_country <- resolved_country[[1]]

      if (identical(resolved_country, CUSTOM_COUNTRY_BUILDER_CHOICE)) {
        return(NULL)
      }

      if (isTRUE(is_custom_country_choice_value(resolved_country))) {
        return(resolved_country)
      }

      if (
        identical(input$data_source_choice %||% "export_sales", "psd") &&
        exists("canonicalize_notes_country_codes", mode = "function")
      ) {
        canonical_country <- canonicalize_notes_country_codes(resolved_country)
        canonical_country <- as.character(canonical_country %||% character(0))
        canonical_country <- canonical_country[!is.na(canonical_country) & nzchar(canonical_country)]

        if (length(canonical_country) > 0) {
          resolved_country <- canonical_country[[1]]
        }
      }

      resolved_country
    }

  build_custom_country_filtered_data <- function(source_df, custom_choice_value, custom_country_defs) {
    if (!is.data.frame(source_df) || nrow(source_df) == 0) {
      return(data.frame())
    }

    target_custom_name <- parse_custom_country_choice_name(custom_choice_value)
    if (is.null(target_custom_name) || !nzchar(target_custom_name)) {
      return(data.frame())
    }

    defs_df <- as_tibble(custom_country_defs %||% data.frame()) %>%
      filter(.data$parse_ok) %>%
      mutate(custom_name_key = tolower(trimws(as.character(.data$custom_name)))) %>%
      filter(!is.na(.data$custom_name_key), nzchar(.data$custom_name_key)) %>%
      arrange(.data$custom_name_key, .data$custom_name) %>%
      distinct(.data$custom_name_key, .keep_all = TRUE)

    if (nrow(defs_df) == 0) {
      return(data.frame())
    }

    metric_cols <- intersect(
      c(
        "monthlyexports", "ytd_exports", "total_commitment",
        "outstandingSales", "grossNewSales", "currentMYNetSales",
        "nextMYOutstandingSales", "nextMYNetSales",
        "monthlyvalue", "ytd_value", "unit_value", "ytd_unit_value",
        unname(psd_metric_choices),
        unname(wasde_metric_catalog$metric_id),
        unname(nass_metric_choices)
      ),
      names(source_df)
    )
    if (length(metric_cols) == 0) {
      return(data.frame())
    }

    defs_by_key <- split(defs_df, defs_df$custom_name_key)
    visit_state <- stats::setNames(integer(0), character(0))
    memoized_frames <- list()

    evaluate_custom_country <- NULL
    build_from_terms <- function(def_row) {
      parsed <- def_row$parsed[[1]]
      if (is.null(parsed) || is.null(parsed$coefficients)) {
        return(data.frame())
      }

      coeffs <- parsed$coefficients
      coeff_keys <- names(coeffs %||% numeric(0))
      coeff_keys <- coeff_keys[!is.na(coeff_keys) & nzchar(coeff_keys)]
      if (length(coeff_keys) == 0) {
        return(data.frame())
      }

      weighted_components <- vector("list", length = 0)
      for (term_key in coeff_keys) {
        coef_value <- suppressWarnings(as.numeric(coeffs[[term_key]]))
        if (!is.finite(coef_value)) next

        if (startsWith(term_key, "custom:")) {
          ref_key <- sub("^custom:", "", term_key)
          term_df <- evaluate_custom_country(ref_key)
        } else {
          term_df <- source_df %>% filter(.data$country == term_key)
        }

        if (!is.data.frame(term_df) || nrow(term_df) == 0) next

        weighted_components[[length(weighted_components) + 1L]] <- term_df %>%
          mutate(across(all_of(metric_cols), ~ suppressWarnings(as.numeric(.x)) * coef_value))
      }

      if (length(weighted_components) == 0) {
        return(data.frame())
      }

      weighted_df <- bind_rows(weighted_components)
      if (nrow(weighted_df) == 0) {
        return(data.frame())
      }

      has_weekly_period <-
        "week_ending_date" %in% names(weighted_df) &&
        any(!is.na(weighted_df$week_ending_date))

      core_group_candidates <- c(
        "source", "frequency", "commodity", "commodity_group",
        "market_year", "analysis_month"
      )
      period_group_candidates <- if (isTRUE(has_weekly_period)) {
        c("week_ending_date")
      } else {
        c("market_month", "calendar_month", "calendar_year")
      }

      fallback_group_cols <- intersect(c("commodity", "market_year", "analysis_month"), names(weighted_df))
      if (isTRUE(has_weekly_period)) {
        fallback_group_cols <- unique(c(fallback_group_cols, intersect("week_ending_date", names(weighted_df))))
      }

      group_cols <- unique(c(
        intersect(c(core_group_candidates, period_group_candidates), names(weighted_df)),
        fallback_group_cols
      ))

      if (length(group_cols) > 0) {
        aggregated <- weighted_df %>%
          group_by(across(all_of(group_cols))) %>%
          summarise(
            across(
              all_of(metric_cols),
              ~ (sum(.x, na.rm = TRUE) * (NA_real_ ^ (sum(!is.na(.x)) == 0)))
            ),
            .groups = "drop"
          )
      } else {
        aggregated <- weighted_df %>%
          summarise(
            across(
              all_of(metric_cols),
              ~ (sum(.x, na.rm = TRUE) * (NA_real_ ^ (sum(!is.na(.x)) == 0)))
            )
          )
      }

      custom_label <- as.character(def_row$custom_name[[1]] %||% "")
      if (!nzchar(custom_label)) {
        custom_label <- target_custom_name
      }

      aggregated <- aggregated %>%
        mutate(country = build_custom_country_choice_value(custom_label))
      if ("countryDescription" %in% names(source_df)) {
        aggregated <- aggregated %>% mutate(countryDescription = custom_label)
      }

      missing_cols <- setdiff(names(source_df), names(aggregated))
      if (length(missing_cols) > 0) {
        for (missing_col in missing_cols) {
          aggregated[[missing_col]] <- NA
        }
      }

      aggregated %>% select(all_of(names(source_df)))
    }

    evaluate_custom_country <- function(custom_name_key) {
      custom_name_key <- tolower(trimws(as.character(custom_name_key %||% "")))
      custom_name_key <- custom_name_key[!is.na(custom_name_key) & nzchar(custom_name_key)]
      if (length(custom_name_key) == 0) {
        return(data.frame())
      }

      custom_name_key <- custom_name_key[[1]]

      if (!is.null(memoized_frames[[custom_name_key]])) {
        return(memoized_frames[[custom_name_key]])
      }

      current_state <- if (custom_name_key %in% names(visit_state)) visit_state[[custom_name_key]] else 0L
      if (identical(current_state, 1L)) {
        return(data.frame())
      }

      def_rows <- defs_by_key[[custom_name_key]]
      if (is.null(def_rows) || nrow(def_rows) == 0) {
        return(data.frame())
      }

      visit_state[[custom_name_key]] <<- 1L
      result_df <- build_from_terms(def_rows[1, , drop = FALSE])
      memoized_frames[[custom_name_key]] <<- result_df
      visit_state[[custom_name_key]] <<- 2L
      result_df
    }

    evaluate_custom_country(tolower(trimws(target_custom_name)))
  }

  # Helper: filter data for a specific country and rice type (used across views)
  filtered_data_for_country <- function(country_code, commodity_code = NULL, consumer = NULL, vp_commodity_name_code = NULL) {
    start_time <- Sys.time()
      resolved_country <- resolve_filtered_country_code(country_code)
      req(resolved_country)
    target_commodity <- if (is.null(commodity_code)) input$commodity_choice else commodity_code
    source_choice_safe <- current_source_choice_safe(default = input$data_source_choice %||% "vp_trade")
    consumer_label <- as.character(consumer %||% "unknown")
    consumer_label <- gsub("[^A-Za-z0-9_]+", "_", consumer_label)
    if (!nzchar(consumer_label)) consumer_label <- "unknown"
    record_cache_body_execution(
      session,
      "filtered_data_for_country",
      details = list(
        consumer = consumer_label,
        source = source_choice_safe,
        frequency = input$data_frequency,
        country = resolved_country,
        commodity = target_commodity
      )
    )
    if (!identical(consumer_label, "unknown")) {
      record_cache_body_execution(session, paste0("filtered_data_for_country_read_", consumer_label))
    }

    block_msg <- custom_type_block_message_for(target_commodity)
    if (!is.null(block_msg)) {
      if (isTRUE(perf_boundary_markers_enabled()) && exists("log_client_perf", mode = "function")) {
        log_client_perf(
          "boundary_server_filtered_data_for_country_blocked",
          list(
            boundary = "server_filtered_data_for_country_blocked",
            source = source_choice_safe,
            frequency = input$data_frequency,
            consumer = consumer_label,
            country = resolved_country,
            commodity = target_commodity,
            rows = 0,
            elapsed_ms = perf_elapsed_ms(start_time)
          )
        )
      }

      log_perf(
        "filtered_data_for_country()",
        start_time,
        details = list(
          source = source_choice_safe,
          frequency = input$data_frequency,
          consumer = consumer_label,
          country = resolved_country,
          commodity = target_commodity,
          blocked = TRUE,
          rows = 0
        )
      )

      return(data.frame())
    }

    record_cache_body_execution(session, "selected_data_read_filtered_data_for_country", details = list(consumer = consumer_label, source = source_choice_safe, commodity = target_commodity))

    if (identical(source_choice_safe, "vp_trade") && !is.null(vp_commodity_name_code) && nzchar(as.character(vp_commodity_name_code))) {
      return(filtered_vp_data_for_custom_panel(
        country_code = resolved_country,
        vp_commodity_name = vp_commodity_name_code,
        commodity_detail = target_commodity,
        consumer = consumer_label
      ))
    }

    source_df <- selected_data() %>%
      filter(commodity == target_commodity)

    if (!identical(source_choice_safe, "nass") && isTRUE(is_custom_country_choice_value(resolved_country))) {
      custom_country_defs <- tryCatch(custom_countries_enriched(), error = function(e) data.frame())
      df <- build_custom_country_filtered_data(
        source_df = source_df,
        custom_choice_value = resolved_country,
        custom_country_defs = custom_country_defs
      )
    } else {
      if (identical(source_choice_safe, "wasde")) {
        available_country_values <- trimws(as.character(source_df$country %||% character(0)))
        available_country_values <- unique(available_country_values[!is.na(available_country_values) & nzchar(available_country_values)])

        if (length(available_country_values) > 0 && !(resolved_country %in% available_country_values)) {
          normalized_resolved <- toupper(gsub("[^A-Z0-9]+", "", resolved_country))

          if (normalized_resolved %in% c("US", "USA", "UNITEDSTATES") && "GRAND_TOTAL" %in% available_country_values) {
            resolved_country <- "GRAND_TOTAL"
          } else if (normalized_resolved %in% c("GRANDTOTAL", "WORLD", "TOTAL") && "U_S" %in% available_country_values) {
            resolved_country <- "U_S"
          } else if ("GRAND_TOTAL" %in% available_country_values) {
            resolved_country <- "GRAND_TOTAL"
          } else {
            resolved_country <- available_country_values[[1]]
          }
        }
      }

      if (identical(source_choice_safe, "nass")) {
        resolved_country <- current_nass_state_choice_safe(default = resolved_country)
      }

      df <- source_df %>%
        filter(country == resolved_country)
    }
    
    # For monthly data, filter out rows with no signal across quantity/value metrics.
    # This preserves Census rows that may have value data with zero quantity while
    # remaining safe for schemas that do not include value columns.
    # For weekly data, keep all rows to preserve complete week history.
    if (identical(input$data_frequency, "monthly")) {
      keep <- rep(FALSE, nrow(df))
      signal_metric_cols <- intersect(
        c(
          "monthlyexports", "ytd_exports", "total_commitment",
          "monthlyvalue", "ytd_value",
          unname(psd_metric_choices),
          unname(wasde_metric_catalog$metric_id),
          unname(nass_metric_choices)
        ),
        names(df)
      )

      for (metric_col in signal_metric_cols) {
        keep <- keep | (!is.na(df[[metric_col]]) & df[[metric_col]] != 0)
      }

      df <- df[keep, , drop = FALSE]
    }

    append_latest_period_zero_row <- function(country_df, all_country_df) {
      metric_code <- effective_main_metric() %||% NULL
      membership_metric <- if (identical(metric_code, "monthlyexports") && "ytd_exports" %in% names(all_country_df)) {
        "ytd_exports"
      } else if (identical(metric_code, "monthlyvalue") && "ytd_value" %in% names(all_country_df)) {
        "ytd_value"
      } else {
        NULL
      }

      if (
        is.null(membership_metric) ||
          is.null(metric_code) ||
          !(metric_code %in% names(all_country_df)) ||
          identical(resolved_country, "GRAND_TOTAL") ||
          nrow(all_country_df) == 0
      ) {
        return(country_df)
      }

      current_year <- suppressWarnings(max(all_country_df$market_year, na.rm = TRUE))
      if (!is.finite(current_year)) {
        return(country_df)
      }

      all_current_year <- all_country_df %>%
        filter(.data$market_year == current_year, .data$country != "GRAND_TOTAL")
      if (nrow(all_current_year) == 0) {
        return(country_df)
      }

      global_latest_period <- suppressWarnings(max(all_current_year$analysis_month, na.rm = TRUE))
      if (!is.finite(global_latest_period)) {
        return(country_df)
      }

      country_current_year <- all_current_year %>%
        filter(.data$country == resolved_country)
      if (nrow(country_current_year) == 0) {
        return(country_df)
      }

      country_latest_period <- suppressWarnings(max(country_current_year$analysis_month, na.rm = TRUE))
      if (!is.finite(country_latest_period)) {
        return(country_df)
      }

      country_latest_row <- country_current_year %>%
        filter(.data$analysis_month == country_latest_period) %>%
        slice_tail(n = 1)
      membership_value <- country_latest_row[[membership_metric]][[1]]
      if (is.na(membership_value) || membership_value <= 0) {
        return(country_df)
      }

      zero_metric_cols <- if (identical(metric_code, "monthlyexports")) {
        intersect(c("monthlyexports", "monthlyexports_rough_eq"), names(country_df))
      } else {
        intersect(c("monthlyvalue", "monthlyvalue_rough_eq"), names(country_df))
      }

      has_latest_row <- nrow(country_df %>%
        filter(.data$market_year == current_year, .data$analysis_month == global_latest_period)) > 0

      if (has_latest_row) {
        latest_row_idx <- country_df$market_year == current_year & country_df$analysis_month == global_latest_period
        for (zero_metric_col in zero_metric_cols) {
          country_df[latest_row_idx & is.na(country_df[[zero_metric_col]]), zero_metric_col] <- 0
        }
        return(country_df)
      }

      template_row <- all_current_year %>%
        filter(.data$analysis_month == global_latest_period) %>%
        slice_tail(n = 1)
      if (nrow(template_row) == 0) {
        return(country_df)
      }

      synthetic_row <- country_latest_row
      synthetic_row$analysis_month <- global_latest_period
      period_context_cols <- intersect(
        c("week_ending_date", "calendar_year", "calendar_month", "month", "month_name", "month_abbrev", "period_label", "report_date"),
        names(synthetic_row)
      )
      for (period_col in period_context_cols) {
        synthetic_row[[period_col]] <- template_row[[period_col]][[1]]
      }

      zero_metric_cols <- intersect(zero_metric_cols, names(synthetic_row))
      for (zero_metric_col in zero_metric_cols) {
        synthetic_row[[zero_metric_col]] <- 0
      }

      bind_rows(country_df, synthetic_row) %>%
        arrange(.data$market_year, .data$analysis_month)
    }

    df <- append_latest_period_zero_row(df, source_df)

    if (isTRUE(perf_boundary_markers_enabled()) && exists("log_client_perf", mode = "function")) {
      log_client_perf(
        "boundary_server_filtered_data_for_country_complete",
        list(
          boundary = "server_filtered_data_for_country_complete",
          source = source_choice_safe,
          frequency = input$data_frequency,
          consumer = consumer_label,
          country = resolved_country,
          commodity = target_commodity,
          rows = nrow(df),
          elapsed_ms = perf_elapsed_ms(start_time)
        )
      )
    }
    
    log_perf(
      "filtered_data_for_country()",
      start_time,
      details = list(
        source = source_choice_safe,
        frequency = input$data_frequency,
        consumer = consumer_label,
        country = resolved_country,
        commodity = target_commodity,
        blocked = FALSE,
        rows = nrow(df)
      )
    )

    df
  }
  
  # Reactive: filter data based on inputs
  filtered_data <- reactive({
    start_time <- Sys.time()
    source_choice_safe <- current_source_choice_safe(default = input$data_source_choice %||% "vp_trade")
    resolved_country <- if (identical(source_choice_safe, "nass")) {
      current_nass_state_choice_safe()
    } else {
      resolve_filtered_country_code(input$country_choice)
    }
    req(resolved_country)  # Ensure country is selected before filtering
    result <- filtered_data_for_country(resolved_country, input$commodity_choice, consumer = "filtered_data")

    log_perf(
      "filtered_data()",
      start_time,
      details = list(
        source = source_choice_safe,
        frequency = input$data_frequency,
        country = resolved_country,
        commodity = input$commodity_choice,
        rows = nrow(result)
      )
    )

    result
  }) %>% bindCache(filtered_data_stable_cache_key())
  
  # Reactive: get most recent market year and month
  most_recent <- reactive({
    start_time <- Sys.time()
    source_choice_safe <- current_source_choice_safe(default = input$data_source_choice %||% "vp_trade")
    df <- filtered_data()
    if (nrow(df) == 0) {
      log_perf(
        "most_recent()",
        start_time,
        details = list(
          source = source_choice_safe,
          frequency = input$data_frequency,
          country = input$country_choice,
          commodity = input$commodity_choice,
          rows = 0,
          recent_year = "NULL"
        )
      )

      return(NULL)
    }
    
    max_year <- suppressWarnings(suppressWarnings(max(df$market_year, na.rm = TRUE)))
    if (!is.finite(max_year)) {
      log_perf(
        "most_recent()",
        start_time,
        details = list(
          source = source_choice_safe,
          frequency = input$data_frequency,
          country = input$country_choice,
          commodity = input$commodity_choice,
          rows = nrow(df),
          recent_year = "NULL"
        )
      )

      return(NULL)
    }
    
    df_recent <- df %>% filter(market_year == max_year)

    result <- list(
      year = max_year,
      months = sort(unique(df_recent$analysis_month))
    )

    log_perf(
      "most_recent()",
      start_time,
      details = list(
        source = source_choice_safe,
        frequency = input$data_frequency,
        country = input$country_choice,
        commodity = input$commodity_choice,
        rows = nrow(df),
        recent_year = max_year,
        periods = length(result$months)
      )
    )

    result
  })
  
  # Reactive: calculate historical average by month
  historical_avg <- reactive({
    start_time <- Sys.time()
    source_choice <- current_source_choice_safe(default = input$data_source_choice %||% "export_sales")
    if (identical(source_choice, "psd")) {
      log_perf(
        "historical_avg()",
        start_time,
        details = list(
          source = source_choice,
          frequency = input$data_frequency,
          country = input$country_choice,
          commodity = input$commodity_choice,
          metric = effective_main_metric(),
          rows = 0,
          status = "skipped_psd_source",
          basis_mode = input$projection_basis_mode,
          ref_year = input$projection_reference_year
        )
      )

      return(NULL)
    }

    req(effective_main_metric())
    metric <- effective_main_metric()
    df <- filtered_data()
    if (nrow(df) == 0) {
      log_perf(
        "historical_avg()",
        start_time,
        details = list(
          source = source_choice,
          frequency = input$data_frequency,
          country = input$country_choice,
          commodity = input$commodity_choice,
          metric = metric,
          rows = 0,
          basis_mode = input$projection_basis_mode,
          ref_year = input$projection_reference_year
        )
      )

      return(NULL)
    }

    if (!(metric %in% names(df))) {
      log_perf(
        "historical_avg()",
        start_time,
        details = list(
          source = source_choice,
          frequency = input$data_frequency,
          country = input$country_choice,
          commodity = input$commodity_choice,
          metric = metric,
          rows = nrow(df),
          basis_mode = input$projection_basis_mode,
          ref_year = input$projection_reference_year,
          status = "metric_missing_from_filtered_data"
        )
      )

      return(NULL)
    }

    recent <- most_recent()
    if (is.null(recent) || is.null(recent$year) || !is.finite(recent$year)) {
      log_perf(
        "historical_avg()",
        start_time,
        details = list(
          source = source_choice,
          frequency = input$data_frequency,
          country = input$country_choice,
          commodity = input$commodity_choice,
          metric = metric,
          rows = nrow(df),
          basis_mode = input$projection_basis_mode,
          ref_year = input$projection_reference_year
        )
      )

      return(NULL)
    }
    recent_year <- recent$year
    hist_window <- suppressWarnings(as.integer(comparison_hist_years_committed()))
    if (length(hist_window) != 1 || !is.finite(hist_window) || is.na(hist_window) || hist_window < 1) {
      hist_window <- 3L
    }
    hist_years_vec <- historical_years_for_window(df$market_year, recent_year, hist_window)
    
      basis_mode <- input$projection_basis_mode
      ref_year <- suppressWarnings(as.numeric(input$projection_reference_year))
      if (length(ref_year) != 1 || !is.finite(ref_year)) {
        ref_year <- NA_real_
      }
      if (identical(basis_mode, "single_year") && !is.finite(ref_year)) {
        available_ref_years <- reference_year_choices()
        default_ref_year <- if (length(available_ref_years) > 1) {
          available_ref_years[2]
        } else if (length(available_ref_years) == 1) {
          available_ref_years[1]
        } else {
          NA_real_
        }
        ref_year <- suppressWarnings(as.numeric(default_ref_year))
      }

      if (identical(basis_mode, "single_year") && is.finite(ref_year)) {
        hist_df <- df %>% filter(market_year == ref_year)
      } else {
        hist_df <- df %>%
          filter(market_year %in% hist_years_vec)
      }

    hist_period_df <- hist_df %>%
      group_by(.data$market_year, .data$analysis_month) %>%
      summarise(
        period_value = if (all(is.na(.data[[metric]]))) NA_real_ else sum(.data[[metric]], na.rm = TRUE),
        .groups = "drop"
      )

    years_used <- sort(unique(hist_period_df$market_year))

    result <- hist_period_df %>%
      group_by(.data$analysis_month) %>%
      summarise(
        avg_value = if (all(is.na(.data$period_value))) NA_real_ else mean(.data$period_value, na.rm = TRUE),
        min_value = if (all(is.na(.data$period_value))) NA_real_ else min(.data$period_value, na.rm = TRUE),
        max_value = if (all(is.na(.data$period_value))) NA_real_ else max(.data$period_value, na.rm = TRUE),
        sd_value = if (sum(!is.na(.data$period_value)) <= 1) NA_real_ else sd(.data$period_value, na.rm = TRUE),
        .groups = "drop"
      ) %>%
      arrange(analysis_month)

    attr(result, "years_used") <- years_used

    log_perf(
      "historical_avg()",
      start_time,
      details = list(
        source = source_choice,
        frequency = input$data_frequency,
        country = input$country_choice,
        commodity = input$commodity_choice,
        metric = metric,
        rows = nrow(df),
        hist_rows = nrow(hist_df),
        out_rows = nrow(result),
        basis_mode = basis_mode,
        ref_year = input$projection_reference_year
      )
    )

    result
  })
  
  # Reactive: get current year data
  current_year_data <- reactive({
    start_time <- Sys.time()
    req(effective_main_metric())
    source_choice <- current_source_choice_safe(default = input$data_source_choice %||% "vp_trade")
    df <- filtered_data()
    metric <- effective_main_metric()
    if (nrow(df) == 0) {
      log_perf(
        "current_year_data()",
        start_time,
        details = list(
          source = source_choice,
          frequency = input$data_frequency,
          country = input$country_choice,
          commodity = input$commodity_choice,
          metric = metric,
          rows = 0,
          recent_year = "NULL"
        )
      )

      return(NULL)
    }

    if (!(metric %in% names(df))) {
      log_perf(
        "current_year_data()",
        start_time,
        details = list(
          source = source_choice,
          frequency = input$data_frequency,
          country = input$country_choice,
          commodity = input$commodity_choice,
          metric = metric,
          rows = nrow(df),
          recent_year = "NULL",
          status = "metric_missing_from_filtered_data"
        )
      )

      return(NULL)
    }

    recent <- most_recent()
    if (is.null(recent) || is.null(recent$year) || !is.finite(recent$year)) {
      log_perf(
        "current_year_data()",
        start_time,
        details = list(
          source = source_choice,
          frequency = input$data_frequency,
          country = input$country_choice,
          commodity = input$commodity_choice,
          metric = metric,
          rows = nrow(df),
          recent_year = "NULL"
        )
      )

      return(NULL)
    }
    recent_year <- recent$year
    effective_frequency <- if (identical(source_choice, "psd")) "monthly" else input$data_frequency
    
    # For weekly data, include week_ending_date; for monthly, exclude it
    result <- if (identical(effective_frequency, "weekly") && "week_ending_date" %in% names(df)) {
      df %>%
        filter(market_year == recent_year) %>%
        group_by(.data$analysis_month, .data$market_year, .data$week_ending_date) %>%
        summarise(
          current_value = if (all(is.na(.data[[metric]]))) NA_real_ else sum(.data[[metric]], na.rm = TRUE),
          commodity = dplyr::first(.data$commodity),
          country = dplyr::first(.data$country),
          .groups = "drop"
        ) %>%
        arrange(analysis_month)
    } else {
      df %>%
        filter(market_year == recent_year) %>%
        group_by(.data$analysis_month, .data$market_year) %>%
        summarise(
          current_value = if (all(is.na(.data[[metric]]))) NA_real_ else sum(.data[[metric]], na.rm = TRUE),
          commodity = dplyr::first(.data$commodity),
          country = dplyr::first(.data$country),
          .groups = "drop"
        ) %>%
        arrange(analysis_month)
    }

    log_perf(
      "current_year_data()",
      start_time,
      details = list(
        source = source_choice,
        frequency = effective_frequency,
        country = input$country_choice,
        commodity = input$commodity_choice,
        metric = metric,
        rows = nrow(result),
        recent_year = recent_year
      )
    )

    result
  })

  # Shared helper: compute panel-aware historical/linear projection contract.
  # This helper is intentionally UI-agnostic so Custom Comparison can reuse it.
  compute_projection_contract_shared <- function(
    df_panel,
    metric_panel,
    recent_year,
    hist_years,
    basis_mode = NULL,
    ref_year = NULL,
    data_frequency = "weekly"
  ) {
    cumulative_metrics <- projection_metric_choices_for_source()
    if (!(metric_panel %in% cumulative_metrics)) return(NULL)
    if (is.null(df_panel) || nrow(df_panel) == 0) return(NULL)
    if (!(metric_panel %in% names(df_panel))) return(NULL)
    if (is.null(recent_year) || !is.finite(recent_year)) return(NULL)

    hist_base <- if (identical(basis_mode, "single_year") && !is.null(ref_year)) {
      df_panel %>% filter(market_year == as.numeric(ref_year))
    } else {
      hist_years_vec <- historical_years_for_window(df_panel$market_year, recent_year, hist_years)
      df_panel %>% filter(market_year %in% hist_years_vec)
    }

    total_periods <- if (identical(data_frequency, "monthly")) {
      if (identical(metric_panel, "total_commitment")) 11 else 12
    } else {
      hist_periods <- hist_base %>%
        pull(analysis_month) %>%
        unique()
      if (length(hist_periods) == 0) return(NULL)
      max(hist_periods, na.rm = TRUE)
    }

    current_panel <- df_panel %>%
      filter(market_year == recent_year) %>%
      select(analysis_month, value = all_of(metric_panel)) %>%
      dplyr::rename(current_value = value) %>%
      arrange(analysis_month)

    current_with_value <- current_panel %>% filter(!is.na(current_value))
    if (nrow(current_with_value) == 0) return(NULL)

    current_period <- max(current_with_value$analysis_month, na.rm = TRUE)
    current_value <- current_with_value %>%
      filter(analysis_month == current_period) %>%
      pull(current_value)

    if (length(current_value) == 0 || is.na(current_value)) return(NULL)

    projection_warning <- NULL
    projection_valid <- current_period <= total_periods
    if (!projection_valid) {
      projection_warning <- paste0(
        "Projection unavailable: current period (",
        current_period,
        ") is later than the last comparable period in the selected historical window (",
        total_periods,
        ")."
      )

      return(list(
        current_period = current_period,
        current_value = current_value,
        total_periods = total_periods,
        final_projection = NA_real_,
        linear_projection = NA_real_,
        linear_fit_data = NULL,
        country_sum_projection = NA_real_,
        projection_valid = FALSE,
        projection_warning = projection_warning,
        projection_warnings = projection_warning,
        historical_available = FALSE,
        sum_available = FALSE,
        linear_available = FALSE,
        data_frequency = data_frequency
      ))
    }

    complete_hist_years <- if (identical(data_frequency, "monthly")) {
      hist_base %>% filter(!is.na(analysis_month))
    } else {
      hist_base %>%
        group_by(market_year) %>%
        filter({
          valid_periods <- analysis_month[!is.na(analysis_month)]
          if (length(valid_periods) > 0) {
            max(valid_periods) >= total_periods - 1
          } else {
            FALSE
          }
        }) %>%
        ungroup()
    }

    if (nrow(complete_hist_years) == 0) {
      final_projection <- current_value * (total_periods / current_period)
    } else {
      year_period_values <- complete_hist_years %>%
        filter(!is.na(.data[[metric_panel]])) %>%
        group_by(market_year, analysis_month) %>%
        summarise(period_value = sum(.data[[metric_panel]], na.rm = TRUE), .groups = "drop")

      if (nrow(year_period_values) == 0) {
        final_projection <- current_value * (total_periods / current_period)
      } else {
        last_periods <- year_period_values %>%
          group_by(market_year) %>%
          summarise(last_hist_period = max(analysis_month, na.rm = TRUE), .groups = "drop")

        last_values <- year_period_values %>%
          inner_join(last_periods, by = "market_year") %>%
          filter(analysis_month == last_hist_period) %>%
          group_by(market_year) %>%
          summarise(last_period_value = sum(period_value, na.rm = TRUE), .groups = "drop")

        target_values <- year_period_values %>%
          filter(analysis_month == total_periods) %>%
          group_by(market_year) %>%
          summarise(target_period_value = sum(period_value, na.rm = TRUE), .groups = "drop")

        final_values <- last_values %>%
          left_join(target_values, by = "market_year") %>%
          mutate(final_value = ifelse(is.na(target_period_value), last_period_value, target_period_value)) %>%
          filter(!is.na(final_value)) %>%
          select(market_year, final_value)

        if (nrow(final_values) == 0) {
          final_projection <- current_value * (total_periods / current_period)
        } else {
          hist_at_current_period <- complete_hist_years %>%
            filter(analysis_month == current_period) %>%
            filter(!is.na(.data[[metric_panel]])) %>%
            group_by(market_year) %>%
            summarise(value_at_period = sum(.data[[metric_panel]], na.rm = TRUE), .groups = "drop") %>%
            inner_join(final_values, by = "market_year") %>%
            mutate(pct_complete = value_at_period / final_value)

          avg_pct_complete <- mean(hist_at_current_period$pct_complete, na.rm = TRUE)

          if (is.na(avg_pct_complete) || avg_pct_complete == 0) {
            final_projection <- current_value * (total_periods / current_period)
          } else {
            final_projection <- current_value / avg_pct_complete
          }
        }
      }
    }

    linear_projection <- NULL
    linear_fit_data <- NULL
    if (nrow(current_with_value) >= 2) {
      first_point <- current_with_value %>% filter(analysis_month == min(analysis_month))
      x_1 <- first_point$analysis_month[1]
      y_1 <- first_point$current_value[1]

      fit_data_transformed <- current_with_value %>%
        mutate(
          y_shifted = current_value - y_1,
          x_shifted = analysis_month - x_1
        )

      fit <- lm(y_shifted ~ 0 + x_shifted, data = fit_data_transformed)
      slope <- coef(fit)[1]
      intercept <- y_1 - slope * x_1

      linear_projection <- slope * total_periods + intercept
      linear_projection <- max(linear_projection, 0)

      y_pred <- slope * current_with_value$analysis_month + intercept
      ss_res <- sum((current_with_value$current_value - y_pred)^2)
      ss_tot <- sum((current_with_value$current_value - mean(current_with_value$current_value))^2)
      r_squared <- if (ss_tot > 0) 1 - (ss_res / ss_tot) else NA_real_

      linear_fit_data <- list(
        intercept = intercept,
        slope = slope,
        r_squared = r_squared,
        anchor_point = list(x = x_1, y = y_1)
      )
    }

    list(
      current_period = current_period,
      current_value = current_value,
      total_periods = total_periods,
      final_projection = final_projection,
      linear_projection = linear_projection,
      linear_fit_data = linear_fit_data,
      country_sum_projection = NULL,
      projection_valid = TRUE,
      projection_warning = projection_warning,
      projection_warnings = projection_warning,
      historical_available = !is.null(final_projection) && !is.na(final_projection),
      sum_available = FALSE,
      linear_available = !is.null(linear_projection) && !is.na(linear_projection)
    )
  }

  sum_warning_console_logged <- reactiveVal(FALSE)
  
  # Reactive: calculate year-end projections
  projection_data <- reactive({
    start_time <- Sys.time()
    source_choice <- current_source_choice_safe(default = input$data_source_choice %||% "export_sales")
    projection_perf_details <- list(
      source = source_choice,
      frequency = input$data_frequency,
      country = input$country_choice,
      commodity = input$commodity_choice,
      metric = effective_main_metric(),
      world_branch = FALSE,
      filtered_rows = NA_integer_,
      world_rows = NA_integer_,
      world_countries = NA_integer_
    )
    on.exit({
      log_perf("projection_data()", start_time, details = projection_perf_details)
    }, add = TRUE)

    if (identical(source_choice, "psd")) {
      projection_perf_details$status <- "skipped_psd_source"
      projection_perf_details$filtered_rows <- 0L
      return(NULL)
    }

    # Only calculate for cumulative metrics
    req(effective_main_metric())
    hist_window <- comparison_hist_years_committed()
    req(hist_window)
    metric <- effective_main_metric()
    projection_perf_details$metric <- metric
    cumulative_metrics <- projection_metric_choices_for_source()
    if (!(metric %in% cumulative_metrics)) return(NULL)

    df <- filtered_data()
    projection_perf_details$filtered_rows <- nrow(df)
    if (nrow(df) == 0) return(NULL)
    
    current <- current_year_data()
    if (is.null(current) || nrow(current) == 0) return(NULL)
    
    recent <- most_recent()
    if (is.null(recent) || is.null(recent$year) || !is.finite(recent$year)) return(NULL)
    recent_year <- recent$year
    hist_years_vec <- historical_years_for_window(df$market_year, recent_year, hist_window)
    
      basis_mode <- input$projection_basis_mode
      ref_year <- input$projection_reference_year

      # Determine total periods based on frequency and metric
      # Project to the LAST period that has historical average data
      if (identical(input$data_frequency, "monthly")) {
        # For total_commitment, project to June (month 11) since July data is 0/NA
        # For other cumulative metrics, project to July (month 12)
        if (metric == "total_commitment") {
          total_periods <- 11  # June
        } else {
          total_periods <- 12  # July
        }
      } else {
        # For weekly, project to the last week with historical data in the hist_years window
        hist_weeks_base <- if (identical(basis_mode, "single_year") && !is.null(ref_year)) {
          df %>% filter(market_year == as.numeric(ref_year))
        } else {
          df %>% filter(market_year %in% hist_years_vec)
        }

        hist_weeks <- hist_weeks_base %>%
          pull(analysis_month) %>%
          unique()
        if (length(hist_weeks) == 0) return(NULL)
        total_periods <- max(hist_weeks, na.rm = TRUE)
      }

      # Get the most recent period with valid (non-NA) data for the metric
    current_with_value <- current %>%
      filter(!is.na(current_value))
    
    if (nrow(current_with_value) == 0) return(NULL)
    
    current_period <- max(current_with_value$analysis_month, na.rm = TRUE)
    if (!is.finite(current_period)) return(NULL)
    if (current_period <= 0) return(NULL)
    current_value <- current_with_value %>%
      filter(analysis_month == current_period) %>%
      pull(current_value) %>%
      sum(na.rm = TRUE)
    
    if (length(current_value) == 0 || is.na(current_value)) return(NULL)

    warning_messages <- character()
    ensure_warning_prefix <- function(msg) {
      if (is.null(msg) || !nzchar(trimws(msg))) return(NULL)
      trimmed <- trimws(msg)
      if (startsWith(trimmed, "WARNING:")) trimmed else paste0("WARNING: ", trimmed)
    }
    add_warning <- function(msg) {
      prefixed <- ensure_warning_prefix(msg)
      if (!is.null(prefixed)) {
        warning_messages <<- c(warning_messages, prefixed)
      }
    }

    projection_warning <- NULL
    projection_valid <- current_period <= total_periods
    if (!projection_valid) {
      projection_warning <- ensure_warning_prefix(paste0(
        "Projection unavailable: current period (",
        current_period,
        ") is later than the last comparable period in the selected historical window (",
        total_periods,
        "). Increase historical years or choose a selection with more late-season history."
      ))

      return(list(
        current_period = current_period,
        current_value = current_value,
        total_periods = total_periods,
        final_projection = NA_real_,
        country_sum_projection = NA_real_,
        linear_projection = NA_real_,
        linear_fit_data = NULL,
        projection_valid = FALSE,
        projection_warning = projection_warning,
        projection_warnings = projection_warning,
        historical_available = FALSE,
        sum_available = FALSE,
        linear_available = FALSE
      ))
    }

    used_carry_forward_total <- FALSE
    unavailable_total <- FALSE
    used_carry_forward_sum <- FALSE
    skipped_countries_sum <- FALSE
    mixed_periods_sum <- FALSE
    sum_coverage_warning <- FALSE
    sum_floor_applied <- FALSE
    used_fallback_sum <- FALSE
    coverage_ratio <- NA_real_
    carry_forward_non_bucket_countries <- character(0)
    skipped_non_bucket_countries <- character(0)
    mixed_period_countries <- character(0)
    floor_countries <- character(0)
    fallback_countries <- character(0)
    projectable_non_bucket_countries <- character(0)
    non_projectable_non_bucket_countries <- character(0)
    excluded_overlap_non_bucket_countries <- character(0)
    excluded_overlap_sum <- FALSE
    benchmark_pct_complete_profile <- tibble(
      analysis_month = numeric(0),
      avg_pct_complete = numeric(0),
      comparable_years = integer(0)
    )
    min_reliable_comparable_years <- if (identical(basis_mode, "single_year") && !is.null(ref_year)) {
      1L
    } else if (identical(input$data_frequency, "weekly")) {
      2L
    } else {
      1L
    }

    basis_context <- build_projection_basis_context(
      basis_mode = basis_mode,
      ref_year = ref_year,
      source_choice = current_source_choice_safe(default = input$data_source_choice %||% "export_sales")
    )
    apply_country_projection_floor <- function(projected_value, current_value) {
      if (!(metric %in% cumulative_metrics)) return(projected_value)
      if (!is.finite(projected_value) || is.na(projected_value)) return(projected_value)
      if (!is.finite(current_value) || is.na(current_value)) return(projected_value)
      max(projected_value, current_value)
    }

    sum_projection_requested <- identical(input$country_choice, "GRAND_TOTAL") && (
      isTRUE(input$show_sum_projection) ||
        (identical(input$main_tabs_panel, "Pace Analysis Tool") && identical(input$pace_projection_source, "sum_of_countries"))
    )

    min_reliable_pct_complete_for <- function(period_idx) {
      if (!is.finite(period_idx) || is.na(period_idx) || !is.finite(total_periods) || is.na(total_periods) || total_periods <= 0) {
        return(NA_real_)
      }

      linear_baseline <- period_idx / total_periods
      if (identical(input$data_frequency, "weekly")) {
        max(0.01, linear_baseline * 0.1)
      } else {
        max(0.03, linear_baseline * 0.1)
      }
    }

    # Build effective endpoint values by market year.
    # If target period is missing, carry forward the last available historical period.
    effective_final_values_for <- function(hist_df) {
      if (nrow(hist_df) == 0) {
        return(tibble(
          market_year = numeric(0),
          last_hist_period = numeric(0),
          final_value = numeric(0),
          used_carry_forward = logical(0)
        ))
      }

      year_period_values <- hist_df %>%
        filter(!is.na(.data[[metric]])) %>%
        group_by(market_year, analysis_month) %>%
        summarise(period_value = sum(.data[[metric]], na.rm = TRUE), .groups = "drop")

      if (nrow(year_period_values) == 0) {
        return(tibble(
          market_year = numeric(0),
          last_hist_period = numeric(0),
          final_value = numeric(0),
          used_carry_forward = logical(0)
        ))
      }

      last_periods <- year_period_values %>%
        group_by(market_year) %>%
        summarise(last_hist_period = max(analysis_month, na.rm = TRUE), .groups = "drop")

      last_values <- year_period_values %>%
        inner_join(last_periods, by = "market_year") %>%
        filter(analysis_month == last_hist_period) %>%
        group_by(market_year, last_hist_period) %>%
        summarise(last_period_value = sum(period_value, na.rm = TRUE), .groups = "drop")

      target_values <- year_period_values %>%
        filter(analysis_month == total_periods) %>%
        group_by(market_year) %>%
        summarise(target_period_value = sum(period_value, na.rm = TRUE), .groups = "drop")

      last_values %>%
        left_join(target_values, by = "market_year") %>%
        mutate(
          used_carry_forward = is.na(target_period_value),
          final_value = ifelse(is.na(target_period_value), last_period_value, target_period_value)
        ) %>%
        filter(!is.na(final_value)) %>%
        select(market_year, last_hist_period, final_value, used_carry_forward)
    }

    build_benchmark_pct_complete_profile <- function(hist_df, final_values_df) {
      if (nrow(hist_df) == 0 || nrow(final_values_df) == 0) {
        return(tibble(
          analysis_month = numeric(0),
          avg_pct_complete = numeric(0),
          comparable_years = integer(0)
        ))
      }

      hist_df %>%
        filter(!is.na(.data[[metric]])) %>%
        group_by(market_year, analysis_month) %>%
        summarise(value_at_period = sum(.data[[metric]], na.rm = TRUE), .groups = "drop") %>%
        inner_join(final_values_df %>% select(market_year, final_value), by = "market_year") %>%
        mutate(pct_complete = .data$value_at_period / .data$final_value) %>%
        filter(is.finite(.data$pct_complete), !is.na(.data$pct_complete), .data$pct_complete > 0) %>%
        group_by(analysis_month) %>%
        summarise(
          avg_pct_complete = mean(.data$pct_complete, na.rm = TRUE),
          comparable_years = dplyr::n(),
          .groups = "drop"
        )
    }

    # --- Historical Pattern Projection ---
    hist_years_base <- if (identical(basis_mode, "single_year") && !is.null(ref_year)) {
      df %>% filter(market_year == as.numeric(ref_year))
    } else {
      df %>% filter(market_year %in% hist_years_vec)
    }

    hist_years_for_projection <- if (identical(input$data_frequency, "monthly")) {
      hist_years_base %>% filter(!is.na(analysis_month))
    } else {
      hist_years_base %>%
        group_by(market_year) %>%
        filter({
          valid_periods <- analysis_month[!is.na(analysis_month)]
          if (length(valid_periods) > 0) {
            max(valid_periods) >= total_periods - 1
          } else {
            FALSE
          }
        }) %>%
        ungroup()
    }

    if (nrow(hist_years_for_projection) == 0) {
      unavailable_total <- TRUE
      final_projection <- NA_real_
    } else {
      final_values <- effective_final_values_for(hist_years_for_projection)
      benchmark_pct_complete_profile <- build_benchmark_pct_complete_profile(hist_years_for_projection, final_values)

      if (nrow(final_values) == 0) {
        unavailable_total <- TRUE
        final_projection <- NA_real_
      } else {
        used_carry_forward_total <- any(final_values$used_carry_forward, na.rm = TRUE)

        hist_at_current_period <- hist_years_for_projection %>%
          filter(analysis_month == current_period) %>%
          filter(!is.na(.data[[metric]])) %>%
          group_by(market_year) %>%
          summarise(value_at_period = sum(.data[[metric]], na.rm = TRUE), .groups = "drop") %>%
          inner_join(final_values %>% select(market_year, final_value), by = "market_year") %>%
          mutate(pct_complete = value_at_period / final_value) %>%
          filter(is.finite(pct_complete), !is.na(pct_complete), pct_complete > 0)

        if (nrow(hist_at_current_period) == 0) {
          unavailable_total <- TRUE
          final_projection <- NA_real_
        } else {
          avg_pct_complete <- mean(hist_at_current_period$pct_complete, na.rm = TRUE)

          if (is.na(avg_pct_complete) || avg_pct_complete <= 0) {
            unavailable_total <- TRUE
            final_projection <- NA_real_
          } else {
            final_projection <- current_value / avg_pct_complete
          }
        }
      }
    }

    if (used_carry_forward_total) {
      add_warning(paste0(
        "Historical projection used a carry-forward endpoint from the last available historical period for ",
        basis_context,
        "."
      ))
    }
    if (unavailable_total) {
      add_warning("Historical projection is unavailable because comparable percent-complete values could not be computed.")
    }

    build_projection_contributor_summary <- function(base_df, metric_col) {
      empty_snapshot <- tibble(country = character(0), current_value = numeric(0))
      empty_latest <- tibble(country = character(0), latest_analysis_month = numeric(0))

      if (is.null(base_df) || nrow(base_df) == 0 || !(metric_col %in% names(base_df))) {
        return(list(
          current_rows = base_df,
          latest_period = NA_real_,
          latest_snapshot = empty_snapshot,
          total_current_value = NA_real_,
          share_snapshot = empty_snapshot %>% mutate(current_share = numeric(0)),
          contributor_latest = empty_latest
        ))
      }

      current_rows <- base_df %>%
        filter(.data$market_year == recent_year) %>%
        filter(!is.na(.data[[metric_col]]), !is.na(.data$analysis_month))

      if (nrow(current_rows) == 0) {
        return(list(
          current_rows = current_rows,
          latest_period = NA_real_,
          latest_snapshot = empty_snapshot,
          total_current_value = NA_real_,
          share_snapshot = empty_snapshot %>% mutate(current_share = numeric(0)),
          contributor_latest = empty_latest
        ))
      }

      latest_period <- suppressWarnings(max(current_rows$analysis_month, na.rm = TRUE))
      if (!is.finite(latest_period) || is.na(latest_period)) {
        return(list(
          current_rows = current_rows,
          latest_period = NA_real_,
          latest_snapshot = empty_snapshot,
          total_current_value = NA_real_,
          share_snapshot = empty_snapshot %>% mutate(current_share = numeric(0)),
          contributor_latest = empty_latest
        ))
      }

      latest_snapshot <- current_rows %>%
        filter(.data$analysis_month == latest_period) %>%
        group_by(.data$country) %>%
        summarise(current_value = sum(.data[[metric_col]], na.rm = TRUE), .groups = "drop") %>%
        filter(is.finite(.data$current_value), !is.na(.data$current_value), .data$current_value > 0)

      contributor_latest <- current_rows %>%
        group_by(.data$country) %>%
        summarise(latest_analysis_month = max(.data$analysis_month, na.rm = TRUE), .groups = "drop")

      total_current_value <- if (nrow(latest_snapshot) > 0) sum(latest_snapshot$current_value, na.rm = TRUE) else NA_real_
      share_snapshot <- if (nrow(latest_snapshot) > 0 && is.finite(total_current_value) && total_current_value > 0) {
        latest_snapshot %>%
          mutate(current_share = .data$current_value / total_current_value)
      } else {
        latest_snapshot %>% mutate(current_share = NA_real_)
      }

      list(
        current_rows = current_rows,
        latest_period = latest_period,
        latest_snapshot = latest_snapshot,
        total_current_value = total_current_value,
        share_snapshot = share_snapshot,
        contributor_latest = contributor_latest
      )
    }

    build_small_share_projection_df <- function(base_df, metric_col, extra_bucket_countries = character(0), contributor_summary = NULL) {
      helper_start_time <- Sys.time()
      helper_details <- list(
        metric = metric_col,
        base_rows = if (is.null(base_df)) 0L else nrow(base_df),
        distinct_countries = if (is.null(base_df) || !is.data.frame(base_df) || !("country" %in% names(base_df))) 0L else dplyr::n_distinct(base_df$country, na.rm = TRUE),
        extra_bucket_country_count = length(extra_bucket_countries),
        bucket_country_count = 0L,
        used = FALSE
      )
      on.exit({
        log_perf("projection_data(): build_small_share_projection_df", helper_start_time, details = helper_details)
      }, add = TRUE)

      small_share_threshold <- 0.01
      small_share_bucket_key <- "__SMALL_SHARE_LT1PCT__"
      extra_bucket_countries <- sort(unique(as.character(extra_bucket_countries[!is.na(extra_bucket_countries) & nzchar(extra_bucket_countries)])))
      contributor_summary <- contributor_summary %||% build_projection_contributor_summary(base_df, metric_col)

      if (is.null(base_df) || nrow(base_df) == 0) {
        return(list(
          df = base_df,
          used = length(extra_bucket_countries) > 0,
          bucket_key = small_share_bucket_key,
          threshold = small_share_threshold,
          small_share_countries = character(0),
          stale_bucket_countries = extra_bucket_countries,
          bucket_countries = extra_bucket_countries,
          small_share_country_count = 0,
          stale_bucket_country_count = length(extra_bucket_countries),
          bucket_country_count = length(extra_bucket_countries),
          bucket_share = NA_real_,
          stale_threshold_weeks = 3
        ))
      }

      if (!(metric_col %in% names(base_df))) {
        return(list(
          df = base_df,
          used = length(extra_bucket_countries) > 0,
          bucket_key = small_share_bucket_key,
          threshold = small_share_threshold,
          small_share_countries = character(0),
          stale_bucket_countries = extra_bucket_countries,
          bucket_countries = extra_bucket_countries,
          small_share_country_count = 0,
          stale_bucket_country_count = length(extra_bucket_countries),
          bucket_country_count = length(extra_bucket_countries),
          bucket_share = NA_real_,
          stale_threshold_weeks = 3
        ))
      }

      current_rows <- contributor_summary$current_rows

      if (nrow(current_rows) == 0) {
        return(list(
          df = base_df,
          used = length(extra_bucket_countries) > 0,
          bucket_key = small_share_bucket_key,
          threshold = small_share_threshold,
          small_share_countries = character(0),
          stale_bucket_countries = extra_bucket_countries,
          bucket_countries = extra_bucket_countries,
          small_share_country_count = 0,
          stale_bucket_country_count = length(extra_bucket_countries),
          bucket_country_count = length(extra_bucket_countries),
          bucket_share = NA_real_,
          stale_threshold_weeks = 3
        ))
      }

      latest_period <- contributor_summary$latest_period
      if (!is.finite(latest_period)) {
        return(list(
          df = base_df,
          used = length(extra_bucket_countries) > 0,
          bucket_key = small_share_bucket_key,
          threshold = small_share_threshold,
          small_share_countries = character(0),
          stale_bucket_countries = extra_bucket_countries,
          bucket_countries = extra_bucket_countries,
          small_share_country_count = 0,
          stale_bucket_country_count = length(extra_bucket_countries),
          bucket_country_count = length(extra_bucket_countries),
          bucket_share = NA_real_,
          stale_threshold_weeks = 3
        ))
      }

      latest_snapshot <- contributor_summary$latest_snapshot

      if (nrow(latest_snapshot) == 0) {
        return(list(
          df = base_df,
          used = length(extra_bucket_countries) > 0,
          bucket_key = small_share_bucket_key,
          threshold = small_share_threshold,
          small_share_countries = character(0),
          stale_bucket_countries = extra_bucket_countries,
          bucket_countries = extra_bucket_countries,
          small_share_country_count = 0,
          stale_bucket_country_count = length(extra_bucket_countries),
          bucket_country_count = length(extra_bucket_countries),
          bucket_share = NA_real_,
          stale_threshold_weeks = 3
        ))
      }

      total_current_value <- contributor_summary$total_current_value
      if (!is.finite(total_current_value) || total_current_value <= 0) {
        return(list(
          df = base_df,
          used = length(extra_bucket_countries) > 0,
          bucket_key = small_share_bucket_key,
          threshold = small_share_threshold,
          small_share_countries = character(0),
          stale_bucket_countries = extra_bucket_countries,
          bucket_countries = extra_bucket_countries,
          small_share_country_count = 0,
          stale_bucket_country_count = length(extra_bucket_countries),
          bucket_country_count = length(extra_bucket_countries),
          bucket_share = NA_real_,
          stale_threshold_weeks = 3
        ))
      }

      share_snapshot <- contributor_summary$share_snapshot

      small_share_countries <- share_snapshot %>%
        filter(!is.na(current_share), current_share < small_share_threshold) %>%
        pull(country)

      bucket_countries <- sort(unique(c(small_share_countries, extra_bucket_countries)))

      if (length(bucket_countries) == 0) {
        return(list(
          df = base_df,
          used = FALSE,
          bucket_key = small_share_bucket_key,
          threshold = small_share_threshold,
          small_share_countries = character(0),
          stale_bucket_countries = character(0),
          bucket_countries = character(0),
          small_share_country_count = 0,
          stale_bucket_country_count = 0,
          bucket_country_count = 0,
          bucket_share = NA_real_,
          stale_threshold_weeks = 3
        ))
      }

      helper_details$bucket_country_count <- length(bucket_countries)
      helper_details$used <- TRUE

      metric_columns <- intersect(
        c("monthlyexports", "ytd_exports", "ytd_value", "total_commitment", metric_col),
        names(base_df)
      )

      if (length(metric_columns) == 0) {
        return(list(
          df = base_df,
          used = length(bucket_countries) > 0,
          bucket_key = small_share_bucket_key,
          threshold = small_share_threshold,
          small_share_countries = sort(unique(small_share_countries)),
          stale_bucket_countries = extra_bucket_countries,
          bucket_countries = bucket_countries,
          small_share_country_count = length(unique(small_share_countries)),
          stale_bucket_country_count = length(extra_bucket_countries),
          bucket_country_count = length(bucket_countries),
          bucket_share = NA_real_,
          stale_threshold_weeks = 3
        ))
      }

      base_minimal <- base_df %>%
        select(any_of(c("country", "market_year", "analysis_month", "week_ending_date")), all_of(metric_columns))

      non_bucket_df <- base_minimal %>%
        filter(!(.data$country %in% bucket_countries))

      bucket_df <- base_minimal %>%
        filter(.data$country %in% bucket_countries) %>%
        mutate(country = small_share_bucket_key) %>%
        group_by(country, market_year, analysis_month) %>%
        summarise(
          week_ending_date = if ("week_ending_date" %in% names(cur_data_all())) {
            if (all(is.na(.data$week_ending_date))) as.Date(NA) else max(.data$week_ending_date, na.rm = TRUE)
          } else {
            as.Date(NA)
          },
          across(
            all_of(metric_columns),
            ~ (sum(.x, na.rm = TRUE) * (NA_real_ ^ (sum(!is.na(.x)) == 0)))
          ),
          .groups = "drop"
        )

      aggregated_df <- bind_rows(non_bucket_df, bucket_df)

      bucket_share <- share_snapshot %>%
        filter(country %in% small_share_countries) %>%
        summarise(total_share = sum(current_share, na.rm = TRUE)) %>%
        pull(total_share)

      list(
        df = aggregated_df,
        used = TRUE,
        bucket_key = small_share_bucket_key,
        threshold = small_share_threshold,
        small_share_countries = sort(unique(small_share_countries)),
        stale_bucket_countries = extra_bucket_countries,
        bucket_countries = bucket_countries,
        small_share_country_count = length(unique(small_share_countries)),
        stale_bucket_country_count = length(extra_bucket_countries),
        bucket_country_count = length(bucket_countries),
        bucket_share = bucket_share,
        stale_threshold_weeks = 3
      )
    }

    compute_stale_bucket_countries <- function(base_df, contributor_summary = NULL) {
      helper_start_time <- Sys.time()
      helper_details <- list(
        metric = metric,
        base_rows = if (is.null(base_df)) 0L else nrow(base_df),
        distinct_countries = if (is.null(base_df) || !is.data.frame(base_df) || !("country" %in% names(base_df))) 0L else dplyr::n_distinct(base_df$country, na.rm = TRUE),
        stale_bucket_country_count = 0L
      )
      on.exit({
        log_perf("projection_data(): compute_stale_bucket_countries", helper_start_time, details = helper_details)
      }, add = TRUE)
      contributor_summary <- contributor_summary %||% build_projection_contributor_summary(base_df, metric)

      if (!identical(input$data_frequency, "weekly")) return(character(0))
      if (is.null(base_df) || nrow(base_df) == 0) return(character(0))
      required_cols <- c("country", "market_year", "analysis_month", metric)
      if (!all(required_cols %in% names(base_df))) return(character(0))

      current_rows <- contributor_summary$current_rows

      if (nrow(current_rows) == 0) return(character(0))

      world_current_period <- contributor_summary$latest_period
      if (!is.finite(world_current_period) || is.na(world_current_period)) return(character(0))

      stale_cutoff_period <- world_current_period - 3

      contributor_latest <- contributor_summary$contributor_latest

      stale_countries <- contributor_latest %>%
        filter(is.finite(.data$latest_analysis_month), !is.na(.data$latest_analysis_month), .data$latest_analysis_month < stale_cutoff_period) %>%
        pull(.data$country) %>%
        as.character() %>%
        unique() %>%
        sort()

      helper_details$stale_bucket_country_count <- length(stale_countries)
      stale_countries
    }

    # --- Country-level sum projection (only for GRAND_TOTAL) ---
    country_sum_projection <- NULL
    small_share_bucket_used <- FALSE
    small_share_bucket_country_count <- 0
    small_share_bucket_share <- NA_real_
    small_share_bucket_threshold <- 0.01
    small_share_bucket_key <- "__SMALL_SHARE_LT1PCT__"
    small_share_bucket_countries <- character(0)

    format_country_contributors <- function(country_keys, bucket_key = NULL, max_items = 8) {
      if (is.null(country_keys) || length(country_keys) == 0) return(NULL)

      country_keys <- as.character(country_keys)
      country_keys <- country_keys[!is.na(country_keys) & nzchar(country_keys)]
      if (length(country_keys) == 0) return(NULL)

      display_keys <- country_keys
      if (!is.null(bucket_key) && length(bucket_key) == 1 && nzchar(bucket_key)) {
        display_keys <- ifelse(display_keys == bucket_key, "projection-only small-share bucket", display_keys)
      }

      display_keys <- sort(unique(display_keys))
      total_count <- length(display_keys)
      shown <- head(display_keys, max_items)
      shown_text <- paste(shown, collapse = ", ")

      if (total_count > max_items) {
        paste0(shown_text, ", and ", total_count - max_items, " more")
      } else {
        shown_text
      }
    }

    is_weekly_imputed_hybrid_projection <- function() {
      source_choice <- if (!is.null(input$data_source_choice)) input$data_source_choice else "export_sales"
      identical(source_choice, "hybrid") &&
        identical(input$data_frequency, "weekly") &&
        identical(hybrid_mode_choice(), "weekly_imputed")
    }

    projection_component_commodities <- function(commodity_name) {
      if (is.null(commodity_name) || !nzchar(commodity_name)) return(character(0))

      custom_def <- custom_types_enriched() %>%
        filter(.data$parse_ok, .data$custom_name == commodity_name)

      if (nrow(custom_def) == 0) {
        return(commodity_name)
      }

      refs <- custom_def$referenced_commodities[[1]]
      refs <- as.character(refs)
      refs[!is.na(refs) & nzchar(refs)]
    }

    weekly_imputed_allowed_countries_for_projection <- function(commodity_name, metric_col) {
      helper_start_time <- Sys.time()
      empty_result <- list(
        can_filter = FALSE,
        allowed_countries = character(0),
        eligible_country_count = 0L,
        component_commodities = character(0)
      )
      helper_details <- list(
        commodity = commodity_name,
        metric = metric_col,
        can_filter = FALSE,
        eligible_country_count = 0L,
        component_commodity_count = 0L,
        overlap_rows = 0L
      )
      on.exit({
        log_perf("projection_data(): weekly_imputed_allowed_countries_for_projection", helper_start_time, details = helper_details)
      }, add = TRUE)

      if (!is_weekly_imputed_hybrid_projection()) return(empty_result)

      raw_base_df <- base_data_converted()
      if (!is.data.frame(raw_base_df) || nrow(raw_base_df) == 0) return(empty_result)
      if (!(metric_col %in% names(raw_base_df))) return(empty_result)
      if (!("weekly_data_segment" %in% names(raw_base_df))) return(empty_result)

      component_commodities <- projection_component_commodities(commodity_name)
      component_commodities <- unique(component_commodities[!is.na(component_commodities) & nzchar(component_commodities)])
      helper_details$component_commodity_count <- length(component_commodities)
      if (length(component_commodities) == 0) return(empty_result)

      custom_def <- custom_types_enriched() %>%
        filter(.data$parse_ok, .data$custom_name == commodity_name)

      overlap_df <- raw_base_df %>%
        filter(.data$country != "GRAND_TOTAL") %>%
        filter(.data$commodity %in% component_commodities) %>%
        filter(is.na(.data$weekly_data_segment) | .data$weekly_data_segment != "observed_export_sales")
      helper_details$overlap_rows <- nrow(overlap_df)

      if (nrow(overlap_df) == 0) {
        empty_result$can_filter <- TRUE
        empty_result$component_commodities <- component_commodities
        helper_details$can_filter <- TRUE
        return(empty_result)
      }

      if (nrow(custom_def) > 0) {
        coeffs <- custom_def$parsed[[1]]$coefficients
        overlap_activity <- overlap_df %>%
          mutate(.component_value = suppressWarnings(as.numeric(.data[[metric_col]])) * coeffs[.data$commodity]) %>%
          group_by(.data$country, .data$market_year, .data$analysis_month) %>%
          summarise(
            .activity_value = sum(.data$.component_value, na.rm = TRUE) * (NA_real_ ^ (sum(!is.na(.data$.component_value)) == 0)),
            .groups = "drop"
          ) %>%
          group_by(.data$country) %>%
          summarise(
            has_overlap_activity = any(is.finite(.data$.activity_value) & !is.na(.data$.activity_value) & .data$.activity_value != 0),
            .groups = "drop"
          )
      } else {
        overlap_activity <- overlap_df %>%
          group_by(.data$country) %>%
          summarise(
            has_overlap_activity = any(is.finite(.data[[metric_col]]) & !is.na(.data[[metric_col]]) & .data[[metric_col]] != 0),
            .groups = "drop"
          )
      }

      allowed_countries <- overlap_activity %>%
        filter(.data$has_overlap_activity) %>%
        pull(.data$country) %>%
        as.character()

      result <- list(
        can_filter = TRUE,
        allowed_countries = sort(unique(allowed_countries[!is.na(allowed_countries) & nzchar(allowed_countries)])),
        eligible_country_count = length(unique(allowed_countries[!is.na(allowed_countries) & nzchar(allowed_countries)])),
        component_commodities = component_commodities
      )
      helper_details$can_filter <- result$can_filter
      helper_details$eligible_country_count <- result$eligible_country_count
      result
    }

    if (sum_projection_requested) {
      world_branch_start_time <- Sys.time()
      record_cache_body_execution(session, "selected_data_read_projection_data", details = list(source = input$data_source_choice %||% "export_sales", commodity = input$commodity_choice, metric = metric))
      base_proj_df <- selected_data() %>%
        filter(commodity == input$commodity_choice, country != "GRAND_TOTAL")
      projection_perf_details$world_branch <- TRUE
      projection_perf_details$world_rows <- nrow(base_proj_df)
      projection_perf_details$world_countries <- dplyr::n_distinct(base_proj_df$country, na.rm = TRUE)

      allowed_country_info <- weekly_imputed_allowed_countries_for_projection(input$commodity_choice, metric)
      if (is_weekly_imputed_hybrid_projection() && isTRUE(allowed_country_info$can_filter)) {
        pre_filter_countries <- sort(unique(base_proj_df$country[!is.na(base_proj_df$country) & nzchar(base_proj_df$country)]))
        allowed_countries <- allowed_country_info$allowed_countries

        if (length(allowed_countries) > 0) {
          base_proj_df <- base_proj_df %>%
            filter(.data$country %in% allowed_countries)
        } else {
          base_proj_df <- base_proj_df[0, , drop = FALSE]
        }

        excluded_overlap_non_bucket_countries <- sort(setdiff(pre_filter_countries, unique(base_proj_df$country)))
        excluded_overlap_sum <- length(excluded_overlap_non_bucket_countries) > 0
      }

      contributor_summary <- build_projection_contributor_summary(base_proj_df, metric)
      stale_bucket_countries <- compute_stale_bucket_countries(base_proj_df, contributor_summary = contributor_summary)
      small_share_info <- build_small_share_projection_df(base_proj_df, metric, extra_bucket_countries = stale_bucket_countries, contributor_summary = contributor_summary)
      base_proj_df <- small_share_info$df
      small_share_bucket_used <- isTRUE(small_share_info$used)
      small_share_bucket_key <- small_share_info$bucket_key
      small_share_bucket_country_count <- small_share_info$bucket_country_count
      small_share_bucket_share <- small_share_info$bucket_share
      small_share_bucket_threshold <- small_share_info$threshold
      small_share_bucket_countries <- small_share_info$bucket_countries
      stale_bucket_countries <- small_share_info$stale_bucket_countries
      stale_bucket_country_count <- small_share_info$stale_bucket_country_count
      small_share_only_country_count <- small_share_info$small_share_country_count

      all_countries <- unique(base_proj_df$country)

      country_loop_start_time <- Sys.time()
      country_results <- lapply(all_countries, function(cty) {
        cty_used_carry_forward <- FALSE
        cty_skipped <- FALSE
        cty_mixed_period <- FALSE
        cty_is_bucket <- identical(cty, small_share_bucket_key)

        make_cty_result <- function(
          value = NA_real_,
          used_carry_forward = FALSE,
          skipped = TRUE,
          used_fallback = FALSE,
          fallback_reason = NULL,
          floor_applied = FALSE,
          current_value = NA_real_,
          current_period = NA_real_,
          mixed_period = FALSE,
          avg_pct_complete = NA_real_,
          comparable_years = 0L
        ) {
          list(
            country = cty,
            is_small_share_bucket = cty_is_bucket,
            value = value,
            used_carry_forward = used_carry_forward,
            skipped = skipped,
            used_fallback = used_fallback,
            fallback_reason = fallback_reason,
            floor_applied = floor_applied,
            current_value = current_value,
            current_period = current_period,
            mixed_period = mixed_period,
            avg_pct_complete = avg_pct_complete,
            comparable_years = comparable_years
          )
        }

        cty_df <- base_proj_df %>% filter(country == cty)

        if (identical(input$data_frequency, "monthly")) {
          cumulative_cols <- intersect(c("ytd_exports", "ytd_value", "total_commitment"), names(cty_df))
          monthly_col <- if ("monthlyexports" %in% names(cty_df)) "monthlyexports" else if ("monthlyvalue" %in% names(cty_df)) "monthlyvalue" else NULL
          keep_mask <- rep(FALSE, nrow(cty_df))
          if (!is.null(monthly_col)) {
            keep_mask <- keep_mask | (!is.na(cty_df[[monthly_col]]) & cty_df[[monthly_col]] != 0)
          }
          if (length(cumulative_cols) > 0) {
            cumulative_mask <- Reduce(`|`, lapply(cumulative_cols, function(col_name) {
              !is.na(cty_df[[col_name]]) & cty_df[[col_name]] != 0
            }))
            keep_mask <- keep_mask | cumulative_mask
          }
          cty_df <- cty_df[keep_mask, , drop = FALSE]
        }

        if (nrow(cty_df) == 0) {
          return(make_cty_result())
        }

        cty_current <- cty_df %>% filter(market_year == recent_year)
        if (nrow(cty_current) == 0) {
          return(make_cty_result())
        }

        cty_current_with_value <- cty_current %>% filter(!is.na(.data[[metric]]))
        if (nrow(cty_current_with_value) == 0) {
          return(make_cty_result())
        }

        cty_current_period <- max(cty_current_with_value$analysis_month, na.rm = TRUE)
        if (!is.finite(cty_current_period)) {
          return(make_cty_result())
        }

        if (!isTRUE(all.equal(cty_current_period, current_period))) {
          cty_mixed_period <- TRUE
        }

        cty_current_row <- cty_current_with_value %>% filter(analysis_month == cty_current_period)
        if (nrow(cty_current_row) == 0) {
          return(make_cty_result(current_period = cty_current_period, mixed_period = cty_mixed_period))
        }

        cty_current_value <- sum(cty_current_row[[metric]], na.rm = TRUE)
        if (is.na(cty_current_value) || cty_current_value == 0) {
          return(make_cty_result(current_period = cty_current_period, mixed_period = cty_mixed_period))
        }

        fallback_profile_row <- benchmark_pct_complete_profile %>%
          filter(.data$analysis_month == cty_current_period)
        fallback_pct_complete <- if (nrow(fallback_profile_row) > 0) fallback_profile_row$avg_pct_complete[[1]] else NA_real_
        fallback_comparable_years <- if (nrow(fallback_profile_row) > 0) fallback_profile_row$comparable_years[[1]] else 0L

        cty_hist_base <- if (identical(basis_mode, "single_year") && !is.null(ref_year)) {
          cty_df %>% filter(market_year == as.numeric(ref_year))
        } else {
          cty_hist_years_vec <- historical_years_for_window(cty_df$market_year, recent_year, hist_window)
          cty_df %>% filter(market_year %in% cty_hist_years_vec)
        }

        cty_hist <- if (identical(input$data_frequency, "monthly")) {
          cty_hist_base %>% filter(!is.na(analysis_month))
        } else {
          cty_hist_base %>%
            group_by(market_year) %>%
            filter({
              valid_periods <- analysis_month[!is.na(analysis_month)]
              if (length(valid_periods) > 0) {
                max(valid_periods) >= total_periods - 1
              } else {
                FALSE
              }
            }) %>%
            ungroup()
        }

        cty_comparable_years <- 0L
        cty_avg_pct <- NA_real_
        fallback_reason <- if (cty_is_bucket) "projection_bucket" else NULL

        if (nrow(cty_hist) == 0) {
          fallback_reason <- fallback_reason %||% "no_historical_years"
        }

        cty_final_values <- if (nrow(cty_hist) > 0) {
          effective_final_values_for(cty_hist)
        } else {
          tibble(
            market_year = numeric(0),
            last_hist_period = numeric(0),
            final_value = numeric(0),
            used_carry_forward = logical(0)
          )
        }

        if (nrow(cty_final_values) == 0) {
          fallback_reason <- fallback_reason %||% "no_historical_endpoints"
        }

        cty_used_carry_forward <- any(cty_final_values$used_carry_forward, na.rm = TRUE)

        cty_hist_at_period <- if (nrow(cty_hist) > 0 && nrow(cty_final_values) > 0) {
          cty_hist %>%
            filter(analysis_month == cty_current_period) %>%
            filter(!is.na(.data[[metric]])) %>%
            group_by(market_year) %>%
            summarise(value_at_period = sum(.data[[metric]], na.rm = TRUE), .groups = "drop") %>%
            inner_join(cty_final_values %>% select(market_year, final_value), by = "market_year") %>%
            mutate(pct_complete = value_at_period / final_value) %>%
            filter(is.finite(pct_complete), !is.na(pct_complete), pct_complete > 0)
        } else {
          tibble(
            market_year = numeric(0),
            value_at_period = numeric(0),
            final_value = numeric(0),
            pct_complete = numeric(0)
          )
        }

        cty_comparable_years <- nrow(cty_hist_at_period)
        if (cty_comparable_years == 0) {
          fallback_reason <- fallback_reason %||% "no_comparable_periods"
        }

        if (cty_comparable_years > 0) {
          cty_avg_pct <- mean(cty_hist_at_period$pct_complete, na.rm = TRUE)
        }

        if (is.na(cty_avg_pct) || cty_avg_pct <= 0) {
          fallback_reason <- fallback_reason %||% "invalid_country_pace"
        }

        if (cty_comparable_years > 0 && cty_comparable_years < min_reliable_comparable_years) {
          fallback_reason <- fallback_reason %||% "thin_comparable_history"
        }

        min_reliable_pct_complete <- min_reliable_pct_complete_for(cty_current_period)
        if (
          is.null(fallback_reason) &&
          is.finite(min_reliable_pct_complete) &&
          !is.na(cty_avg_pct) &&
          is.finite(cty_avg_pct) &&
          cty_avg_pct < min_reliable_pct_complete
        ) {
          fallback_reason <- "implausibly_low_country_pace"
        }

        use_fallback <- !is.null(fallback_reason)
        if (use_fallback && (!is.finite(fallback_pct_complete) || is.na(fallback_pct_complete) || fallback_pct_complete <= 0)) {
          cty_skipped <- TRUE
          return(make_cty_result(
            used_carry_forward = cty_used_carry_forward,
            skipped = cty_skipped,
            used_fallback = FALSE,
            fallback_reason = fallback_reason,
            current_value = cty_current_value,
            current_period = cty_current_period,
            mixed_period = cty_mixed_period,
            avg_pct_complete = cty_avg_pct,
            comparable_years = cty_comparable_years
          ))
        }

        if (!use_fallback && (!is.finite(cty_avg_pct) || is.na(cty_avg_pct) || cty_avg_pct <= 0)) {
          cty_skipped <- TRUE
          return(make_cty_result(
            used_carry_forward = cty_used_carry_forward,
            skipped = cty_skipped,
            used_fallback = FALSE,
            fallback_reason = "invalid_country_pace",
            current_value = cty_current_value,
            current_period = cty_current_period,
            mixed_period = cty_mixed_period,
            avg_pct_complete = cty_avg_pct,
            comparable_years = cty_comparable_years
          ))
        }

        pct_complete_used <- if (use_fallback) fallback_pct_complete else cty_avg_pct
        comparable_years_used <- if (use_fallback) fallback_comparable_years else cty_comparable_years

        raw_projection <- cty_current_value / pct_complete_used
        floored_projection <- apply_country_projection_floor(raw_projection, cty_current_value)

        make_cty_result(
          value = floored_projection,
          used_carry_forward = cty_used_carry_forward,
          skipped = cty_skipped,
          used_fallback = use_fallback,
          fallback_reason = fallback_reason,
          floor_applied = is.finite(raw_projection) && is.finite(floored_projection) && (floored_projection > raw_projection),
          current_value = cty_current_value,
          current_period = cty_current_period,
          mixed_period = cty_mixed_period,
          avg_pct_complete = pct_complete_used,
          comparable_years = comparable_years_used
        )
      })
      log_perf(
        "projection_data(): world_country_results_loop",
        country_loop_start_time,
        details = list(
          metric = metric,
          countries = length(all_countries),
          base_rows = nrow(base_proj_df),
          stale_bucket_country_count = stale_bucket_country_count,
          bucket_country_count = small_share_bucket_country_count
        )
      )

      country_projections <- vapply(country_results, function(x) x$value, numeric(1))
      non_bucket_results <- Filter(function(x) !isTRUE(x$is_small_share_bucket), country_results)
      carry_forward_non_bucket_countries <- sort(unique(vapply(
        Filter(function(x) isTRUE(x$used_carry_forward), non_bucket_results),
        function(x) x$country,
        character(1)
      )))
      skipped_non_bucket_countries <- sort(unique(vapply(
        Filter(function(x) isTRUE(x$skipped), non_bucket_results),
        function(x) x$country,
        character(1)
      )))
      mixed_period_countries <- sort(unique(vapply(
        Filter(function(x) isTRUE(x$mixed_period), country_results),
        function(x) x$country,
        character(1)
      )))
      floor_countries <- sort(unique(vapply(
        Filter(function(x) isTRUE(x$floor_applied), country_results),
        function(x) x$country,
        character(1)
      )))
      fallback_results <- Filter(function(x) isTRUE(x$used_fallback), country_results)
      fallback_non_bucket_countries <- sort(unique(vapply(
        Filter(function(x) !isTRUE(x$is_small_share_bucket), fallback_results),
        function(x) x$country,
        character(1)
      )))
      fallback_reason_summary <- fallback_results %>%
        vapply(
          function(x) paste0(x$country, ":", ifelse(is.null(x$fallback_reason) || is.na(x$fallback_reason), "unknown", x$fallback_reason)),
          character(1)
        ) %>%
        unique() %>%
        sort()

      used_carry_forward_sum <- length(carry_forward_non_bucket_countries) > 0
      skipped_countries_sum <- length(skipped_non_bucket_countries) > 0
      mixed_periods_sum <- length(mixed_period_countries) > 0
      sum_floor_applied <- length(floor_countries) > 0
      used_fallback_sum <- length(fallback_results) > 0

      projectable_current_values <- vapply(country_results, function(x) x$current_value, numeric(1))
      projectable_current_total <- (sum(projectable_current_values, na.rm = TRUE) * (NA_real_ ^ (sum(!is.na(projectable_current_values)) == 0)))

      if (!is.na(projectable_current_total) && is.finite(current_value) && current_value > 0) {
        coverage_ratio <- projectable_current_total / current_value
        if (is.finite(coverage_ratio) && coverage_ratio < 0.9) {
          sum_coverage_warning <- TRUE
        }
      }

      projectable_non_bucket_countries <- sort(unique(vapply(
        Filter(function(x) !isTRUE(x$skipped) && !is.na(x$value) && is.finite(x$value), non_bucket_results),
        function(x) x$country,
        character(1)
      )))

      non_projectable_non_bucket_countries <- sort(unique(vapply(
        Filter(function(x) isTRUE(x$skipped) || is.na(x$value) || !is.finite(x$value), non_bucket_results),
        function(x) x$country,
        character(1)
      )))

      country_sum_projection <- (sum(country_projections, na.rm = TRUE) * (NA_real_ ^ (sum(!is.na(country_projections)) == 0)))
      log_perf(
        "projection_data(): world_sum_branch",
        world_branch_start_time,
        details = list(
          metric = metric,
          base_rows = nrow(base_proj_df),
          countries = length(all_countries),
          stale_bucket_country_count = stale_bucket_country_count,
          bucket_country_count = small_share_bucket_country_count,
          excluded_overlap_country_count = length(excluded_overlap_non_bucket_countries),
          country_sum_available = !is.null(country_sum_projection) && is.finite(country_sum_projection) && !is.na(country_sum_projection)
        )
      )
    }

    if (used_carry_forward_sum) {
      carry_forward_countries_text <- format_country_contributors(
        carry_forward_non_bucket_countries,
        bucket_key = small_share_bucket_key
      )
      add_warning(paste0(
        "Sum-of-countries projection used carry-forward endpoints for one or more countries in ",
        basis_context,
        ". Countries: ",
        carry_forward_countries_text,
        "."
      ))
    }
    if (excluded_overlap_sum) {
      excluded_countries_text <- format_country_contributors(excluded_overlap_non_bucket_countries)
      add_warning(paste0(
        "Sum-of-countries projection excluded one or more weekly-imputed Hybrid contributors because they only appear in the post-break Export Sales extension. Countries: ",
        excluded_countries_text,
        "."
      ))
    }
    if (skipped_countries_sum) {
      skipped_countries_text <- format_country_contributors(
        skipped_non_bucket_countries,
        bucket_key = small_share_bucket_key
      )
      add_warning(paste0(
        "Sum-of-countries projection skipped one or more countries due to insufficient comparable history. Countries: ",
        skipped_countries_text,
        "."
      ))
    }
    if (mixed_periods_sum) {
      mixed_period_countries_text <- format_country_contributors(
        mixed_period_countries,
        bucket_key = small_share_bucket_key
      )
      add_warning(paste0(
        "Sum-of-countries projection uses country-specific latest reporting periods due to uneven data timing. Countries: ",
        mixed_period_countries_text,
        "."
      ))
    }
    if (used_fallback_sum) {
      fallback_countries <- fallback_non_bucket_countries
      fallback_countries_text <- format_country_contributors(
        unique(c(fallback_non_bucket_countries, if (small_share_bucket_used) small_share_bucket_key else character(0))),
        bucket_key = small_share_bucket_key
      )
      add_warning(paste0(
        "Sum-of-countries projection used benchmark world pacing for one or more unreliable contributors. Countries: ",
        fallback_countries_text,
        "."
      ))
    }
    if (sum_coverage_warning) {
      add_warning("Sum-of-countries projection may be understated because projectable countries do not cover most of the current GRAND_TOTAL volume.")
    }
    if (sum_floor_applied) {
      floor_countries_text <- format_country_contributors(
        floor_countries,
        bucket_key = small_share_bucket_key
      )
      add_warning(paste0(
        "Sum-of-countries projection was floored to current accumulated values for one or more countries. Countries: ",
        floor_countries_text,
        "."
      ))
    }
    if (small_share_bucket_used && small_share_bucket_country_count > 0) {
      share_pct <- if (is.finite(small_share_bucket_share) && !is.na(small_share_bucket_share)) {
        sprintf("%.1f", 100 * small_share_bucket_share)
      } else {
        "NA"
      }

      bucket_countries_text <- format_country_contributors(small_share_bucket_countries)
      stale_countries_text <- format_country_contributors(stale_bucket_countries)

      add_warning(paste0(
        "Sum-of-countries projection aggregated a projection-only bucket with ",
        small_share_bucket_country_count,
        " total countries, including ",
        small_share_only_country_count,
        " countries below ",
        sprintf("%.1f", 100 * small_share_bucket_threshold),
        "% share (",
        share_pct,
        "% combined)",
        if (stale_bucket_country_count > 0) paste0(" and ", stale_bucket_country_count, " stale weekly contributors") else "",
        ".",
        if (!is.null(bucket_countries_text)) paste0(" Bucket countries: ", bucket_countries_text, ".") else "",
        if (!is.null(stale_countries_text) && stale_bucket_country_count > 0) paste0(" Stale contributors: ", stale_countries_text, ".") else ""
      ))
    }

    # Sum warnings are console-only; UI-facing warnings are scrubbed below.
    sum_warning_messages <- warning_messages[grepl("sum-of-countries projection", warning_messages, ignore.case = TRUE)]
    non_sum_warning_messages <- warning_messages[!grepl("sum-of-countries projection", warning_messages, ignore.case = TRUE)]

    # Console-only toggle for sum warnings; FALSE suppresses [SUM_WARNING] output only.
    should_log_sum_warnings <-
      isTRUE(getOption("rice_sum_warning_console", TRUE)) &&
      length(sum_warning_messages) > 0 &&
      !isTRUE(sum_warning_console_logged())
    if (should_log_sum_warnings) {
      message("[SUM_WARNING] Context: metric=", metric,
              "; commodity=", input$commodity_choice,
              "; country_choice=", input$country_choice,
              "; frequency=", input$data_frequency,
              "; basis_mode=", basis_mode,
              "; ref_year=", ifelse(is.null(ref_year), "NA", as.character(ref_year)),
              "; hist_years=", hist_window)
            if (excluded_overlap_sum) message("[SUM_WARNING] excluded_overlap_countries=", paste(excluded_overlap_non_bucket_countries, collapse = ", "))
      if (used_carry_forward_sum) message("[SUM_WARNING] carry_forward_countries=", paste(carry_forward_non_bucket_countries, collapse = ", "))
      if (skipped_countries_sum) message("[SUM_WARNING] skipped_countries=", paste(skipped_non_bucket_countries, collapse = ", "))
      if (mixed_periods_sum) message("[SUM_WARNING] mixed_period_countries=", paste(mixed_period_countries, collapse = ", "))
      if (used_fallback_sum) message("[SUM_WARNING] fallback_countries=", paste(fallback_countries, collapse = ", "))
      if (used_fallback_sum) message("[SUM_WARNING] fallback_reasons=", paste(fallback_reason_summary, collapse = ", "))
      if (sum_floor_applied) message("[SUM_WARNING] floor_countries=", paste(floor_countries, collapse = ", "))
      if (small_share_bucket_used) {
        message("[SUM_WARNING] bucket_members=", paste(small_share_bucket_countries, collapse = ", "))
        message("[SUM_WARNING] stale_bucket_members=", paste(stale_bucket_countries, collapse = ", "))
        message("[SUM_WARNING] bucket_country_count=", small_share_bucket_country_count,
                "; bucket_share=", ifelse(is.finite(small_share_bucket_share) && !is.na(small_share_bucket_share), as.character(signif(small_share_bucket_share, 6)), "NA"),
          "; bucket_threshold=", small_share_bucket_threshold,
          "; stale_bucket_country_count=", stale_bucket_country_count)
      }
      if (sum_coverage_warning) {
        message("[SUM_WARNING] coverage_ratio=", ifelse(is.finite(coverage_ratio) && !is.na(coverage_ratio), as.character(signif(coverage_ratio, 6)), "NA"))
        message("[SUM_WARNING] projectable_non_bucket_countries=", paste(projectable_non_bucket_countries, collapse = ", "))
        message("[SUM_WARNING] non_projectable_non_bucket_countries=", paste(non_projectable_non_bucket_countries, collapse = ", "))
      }
      for (msg in sum_warning_messages) {
        message("[SUM_WARNING] message=", msg)
      }
      sum_warning_console_logged(TRUE)
    }

    warning_messages <- unique(warning_messages[!is.na(warning_messages) & nzchar(warning_messages)])
    non_sum_warning_messages <- unique(non_sum_warning_messages[!is.na(non_sum_warning_messages) & nzchar(non_sum_warning_messages)])
    projection_warning <- if (length(non_sum_warning_messages) > 0) paste(non_sum_warning_messages, collapse = " ") else NULL
    
    # --- Linear Fit Projection ---
    # Fit a linear regression to current year data, constrained to pass through the first point
    linear_projection <- NULL
    linear_fit_data <- NULL
    
    # Include all non-NA values (including zeros) for fitting
    current_for_fit <- current_with_value %>%
      filter(!is.na(current_value))
    
    if (nrow(current_for_fit) >= 2) {
      # Get the first data point (including if it's 0)
      first_point <- current_for_fit %>%
        filter(analysis_month == min(analysis_month))
      x_1 <- first_point$analysis_month[1]
      y_1 <- first_point$current_value[1]
      
      # Transform data: fit y - y_1 = m * (x - x_1)
      # This is equivalent to: (y - y_1) ~ 0 + (x - x_1)
      fit_data_transformed <- current_for_fit %>%
        mutate(
          y_shifted = current_value - y_1,
          x_shifted = analysis_month - x_1
        )
      
      # Fit model without intercept on shifted data
      fit <- lm(y_shifted ~ 0 + x_shifted, data = fit_data_transformed)
      slope <- coef(fit)[1]
      
      # The intercept in original coordinates: y = mx + b, where line passes through (x_1, y_1)
      # y_1 = m * x_1 + b  =>  b = y_1 - m * x_1
      intercept <- y_1 - slope * x_1
      
      # Predict at year-end (total_periods)
      linear_projection <- slope * total_periods + intercept
      linear_projection <- max(linear_projection, 0)  # Ensure non-negative
      
      # Calculate R² for the fit
      y_pred <- slope * current_for_fit$analysis_month + intercept
      ss_res <- sum((current_for_fit$current_value - y_pred)^2)
      ss_tot <- sum((current_for_fit$current_value - mean(current_for_fit$current_value))^2)
      r_squared <- if (ss_tot > 0) 1 - (ss_res / ss_tot) else NA
      
      # Store fit data for plotting the line
      linear_fit_data <- list(
        intercept = intercept,
        slope = slope,
        r_squared = r_squared,
        anchor_point = list(x = x_1, y = y_1)
      )
    }
    
    historical_available <- !is.null(final_projection) && is.finite(final_projection) && !is.na(final_projection)
    sum_available <- identical(input$country_choice, "GRAND_TOTAL") && !is.null(country_sum_projection) && is.finite(country_sum_projection) && !is.na(country_sum_projection)
    linear_available <- !is.null(linear_projection) && is.finite(linear_projection) && !is.na(linear_projection)

    list(
      current_period = current_period,
      current_value = current_value,
      total_periods = total_periods,
      final_projection = final_projection,
      country_sum_projection = country_sum_projection,
      linear_projection = linear_projection,
      linear_fit_data = linear_fit_data,
      projection_valid = TRUE,
      projection_warning = projection_warning,
      projection_warnings = non_sum_warning_messages,
      historical_available = historical_available,
      sum_available = sum_available,
      linear_available = linear_available
    )
  })
  
  # Update year_filter choices and selection for Historical Trend using projection basis context.
  # Guard with a signature to prevent no-op updates from churning reactive invalidation and cache paths.
  year_filter_sync_signature <- reactiveVal(NULL)
  observeEvent(
    list(
      filtered_data()$market_year,
      input$main_tabs_panel,
      input$projection_basis_mode,
      input$projection_reference_year,
      comparison_hist_years_committed()
    ),
    {
      record_cache_body_execution(
        session,
        "year_filter_sync_observer",
        details = list(
          source = current_source_choice_safe(default = input$data_source_choice %||% "export_sales"),
          tab = input$main_tabs_panel %||% NA_character_,
          basis_mode = input$projection_basis_mode %||% NA_character_,
          reference_year = input$projection_reference_year %||% NA_character_,
          hist_years = comparison_hist_years_committed() %||% NA_integer_
        )
      )

      df <- filtered_data()
      if (is.null(df) || !is.data.frame(df) || nrow(df) == 0 || !("market_year" %in% names(df))) {
        updateCheckboxGroupInput(session, inputId = "year_filter", choices = numeric(0), selected = numeric(0))
        year_filter_sync_signature("choices=;selected=")
        return()
      }

      available_years <- sort(unique(suppressWarnings(as.numeric(df$market_year))), decreasing = TRUE)
      available_years <- available_years[is.finite(available_years)]

      if (length(available_years) == 0) {
        updateCheckboxGroupInput(session, inputId = "year_filter", choices = numeric(0), selected = numeric(0))
        year_filter_sync_signature("choices=;selected=")
        return()
      }

      recent_info <- most_recent()
      recent_year <- suppressWarnings(as.numeric(recent_info$year %||% NA_real_))
      if (!is.finite(recent_year) || !(recent_year %in% available_years)) {
        recent_year <- available_years[1]
      }

      basis_mode <- input$projection_basis_mode %||% "average"
      ref_year <- suppressWarnings(as.numeric(input$projection_reference_year))
      if (length(ref_year) != 1 || !is.finite(ref_year)) {
        ref_year <- NA_real_
      }
      hist_window <- suppressWarnings(as.integer(comparison_hist_years_committed()))
      if (length(hist_window) != 1 || !is.finite(hist_window) || is.na(hist_window) || hist_window < 1) {
        hist_window <- 3L
      }

      desired_years <- if (identical(basis_mode, "single_year") && is.finite(ref_year)) {
        unique(c(recent_year, ref_year))
      } else {
        hist_years_vec <- historical_years_for_window(available_years, recent_year, hist_window)
        unique(c(recent_year, hist_years_vec))
      }

      desired_years <- desired_years[is.finite(desired_years)]
      desired_years <- sort(unique(desired_years[desired_years %in% available_years]), decreasing = TRUE)
      if (length(desired_years) == 0) {
        fallback_n <- min(length(available_years), max(1, hist_window + 1))
        desired_years <- head(available_years, fallback_n)
      }

      selected_years <- sort(unique(desired_years), decreasing = TRUE)
      active_tab <- input$main_tabs_panel %||% NULL
      selected_year_inputs <- tryCatch(as.character(input$year_filter %||% character(0)), error = function(...) character(0))
      selected_year_inputs <- selected_year_inputs[nzchar(selected_year_inputs)]
      needs_reapply <- identical(active_tab, "Historical Trend") && length(selected_year_inputs) == 0

      sig <- paste0(
        "choices=", paste(available_years, collapse = "|"),
        ";selected=", paste(selected_years, collapse = "|")
      )

      if (!needs_reapply && identical(year_filter_sync_signature(), sig)) {
        return()
      }

      updateCheckboxGroupInput(
        session,
        inputId = "year_filter",
        choices = available_years,
        selected = selected_years
      )
      year_filter_sync_signature(sig)
    },
    ignoreInit = FALSE
  )

  # Keep Historical Trend Historical Average toggle synchronized with projection basis mode.
  # In single-year basis, force show_hist_avg off and restore prior user state on return.
  hist_avg_prev_state <- reactiveVal(TRUE)
  hist_avg_basis_last <- reactiveVal(NULL)
  observeEvent(
    list(input$projection_basis_mode, effective_main_metric(), input$show_hist_avg),
    {
      metric <- effective_main_metric()
      basis_mode <- input$projection_basis_mode
      current_show <- input$show_hist_avg

      if (is.null(metric) || is.null(current_show) || is.null(basis_mode) || !nzchar(basis_mode)) {
        return()
      }

      cumulative_metrics <- projection_metric_choices_for_source()
      if (!(metric %in% cumulative_metrics)) {
        hist_avg_basis_last(NULL)
        return()
      }

      prev_basis <- hist_avg_basis_last()

      if (identical(basis_mode, "single_year")) {
        # Save user preference exactly once when entering single-year mode.
        if (!identical(prev_basis, "single_year")) {
          hist_avg_prev_state(isTRUE(current_show))
        }

        if (isTRUE(current_show)) {
          updateCheckboxInput(session, "show_hist_avg", value = FALSE)
        }

        hist_avg_basis_last("single_year")
        return()
      }

      # Returning from single-year: restore prior preference.
      if (identical(prev_basis, "single_year")) {
        target <- isTRUE(hist_avg_prev_state())
        if (!identical(isTRUE(current_show), target)) {
          updateCheckboxInput(session, "show_hist_avg", value = target)
        }
      } else {
        # Track explicit user preference while not in single-year mode.
        hist_avg_prev_state(isTRUE(current_show))
      }

      hist_avg_basis_last(basis_mode)
    },
    ignoreInit = FALSE
  )
  

