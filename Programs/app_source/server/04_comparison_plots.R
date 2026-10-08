  map_analysis_display_mode_label <- function(display_mode) {
    if (identical(display_mode, "comparison")) {
      "Historical Comparison"
    } else {
      "Current Level"
    }
  }

  map_analysis_measurement_label <- function(metric_col, source_choice) {
    get_metric_measurement_label(
      metric_code = metric_col,
      source_choice = source_choice,
      unit_choice = input$unit_choice %||% "mt",
      basis_choice = effective_basis_choice_for_metric(
        metric_col,
        current_basis_choice_safe(),
        source_choice
      ),
      value_unit_choice = current_census_value_unit_choice_safe(),
      commodity_name = input$commodity_choice %||% default_commodity_choice_value(),
      active_tab = input$main_tabs_panel %||% "Map",
      area_unit_choice = current_psd_area_unit_choice_safe()
    )
  }

  format_map_analysis_info <- function(lines) {
    paste(lines[nzchar(lines)], collapse = "\n")
  }

  psd_market_year_coverage_line <- function(selected_market_year) {
    coverage_df <- map_source_data()
    year_value <- suppressWarnings(as.numeric(selected_market_year))

    if (is.null(coverage_df) || nrow(coverage_df) == 0 || !is.finite(year_value)) {
      return("PSD coverage: Unavailable")
    }

    coverage_info <- latest_psd_coverage_info(
      coverage_df %>% filter(.data$market_year == year_value)
    )

    paste0("PSD coverage for MY ", selected_market_year, ": ", coverage_info$full_label)
  }

  psd_matrix_year_window_line <- function(matrix_df) {
    year_cols <- names(matrix_df)[grepl("^\\d{4}$", names(matrix_df))]

    if (length(year_cols) == 0) {
      return("Market years shown: None")
    }

    paste0(
      "Market years shown: ",
      length(year_cols),
      " most recent available ",
      if (length(year_cols) == 1) "year" else "years"
    )
  }

  build_psd_map_analysis_info <- function() {
    map_display <- map_display_dataset()
    map_state <- map_display$map_state %||% list()

    if (!identical(map_state$status %||% NULL, "ok")) {
      return("No PSD map data available for this selection")
    }

    metric_col <- map_state$metric_col %||% ""
    metric_label <- get_active_metric_label(metric_col)
    measurement_label <- map_analysis_measurement_label(metric_col, "psd")
    bottom_view <- if (!is.null(psd_map_bottom_view_state()) && psd_map_bottom_view_state() %in% c("summary", "matrix")) {
      psd_map_bottom_view_state()
    } else {
      "summary"
    }

    if (identical(bottom_view, "matrix")) {
      matrix_state <- psd_map_matrix_dataset()
      selected_country <- matrix_state$selected_country %||% "GRAND_TOTAL"
      matrix_df <- matrix_state$matrix_df

      return(format_map_analysis_info(c(
        "Panel: Market Year Comparison Table",
        paste0("Country: ", psd_selected_country_label()),
        "Series: Latest available estimate by market year",
        psd_matrix_year_window_line(matrix_df),
        paste0("Metric: ", metric_label),
        paste0("Measurement: ", measurement_label),
        psd_matrix_country_coverage_note() %||% "Latest period covered in PSD data: Unavailable."
      )))
    }
    lines <- c(
      "Panel: Map Summary Table",
      paste0("Market Year: ", map_state$selected_market_year %||% "Unavailable"),
      paste0("Map Display: ", map_analysis_display_mode_label(map_display$mode %||% "current")),
      paste0("Metric: ", metric_label),
      paste0("Measurement: ", measurement_label),
      psd_market_year_coverage_line(map_state$selected_market_year %||% NA_character_)
    )

    if (identical(map_display$mode %||% NULL, "comparison")) {
      lines <- c(lines, paste0("Baseline: ", map_state$baseline_label %||% "Unavailable"))
    }

    format_map_analysis_info(lines)
  }

  build_non_psd_map_analysis_info <- function() {
    map_display <- map_display_dataset()
    map_state <- map_display$map_state %||% list()

    if (!identical(map_state$status %||% NULL, "ok")) {
      return("No map data available for this selection")
    }

    metric_col <- map_state$metric_col %||% ""
    year_label <- "Market Year"
    lines <- c(
      paste0(year_label, ": ", map_state$selected_market_year %||% "Unavailable"),
      paste0("Map Display: ", map_analysis_display_mode_label(map_display$mode %||% "current")),
      paste0("Period: ", map_state$selected_period_label %||% "Unavailable"),
      paste0("Metric: ", get_active_metric_label(metric_col)),
      paste0("Measurement: ", map_analysis_measurement_label(metric_col, input$data_source_choice %||% "export_sales"))
    )

    if (identical(map_display$mode %||% NULL, "comparison")) {
      lines <- c(lines, paste0("Baseline: ", map_state$baseline_label %||% "Unavailable"))
    }

    format_map_analysis_info(lines)
  }

  # Output: Data summary
  output$data_summary <- renderText({
    if (identical(input$data_source_choice, "psd") && identical(input$main_tabs_panel, "Time Series Analysis Tool")) {
      bundle <- psd_time_series_annual_bundle()
      if (!identical(bundle$status, "ok") || nrow(bundle$plot_df) == 0) {
        return("No PSD annual time series available for this selection")
      }

      latest_row <- bundle$plot_df %>%
        arrange(desc(.data$period_index)) %>%
        slice(1)

      latest_label <- if (nrow(latest_row) > 0) latest_row$period_label[[1]] else "N/A"
      trendline_status <- if (isTRUE(bundle$fit_available)) "Available" else "Unavailable"

      return(paste(
        "Latest Market Year:", latest_label, "\n",
        "Annual observations:", nrow(bundle$plot_df), "\n",
        "Metric:", bundle$metric_label, "\n",
        "Measurement:", bundle$unit_label, "\n",
        "OLS trendline:", trendline_status
      ))
    }

    if (identical(input$main_tabs_panel, "Map")) {
      if (identical(input$data_source_choice, "psd")) {
        return(build_psd_map_analysis_info())
      }

      return(build_non_psd_map_analysis_info())
    }

    df <- filtered_data()
    if (nrow(df) == 0) {
      return("No data available for this selection")
    }
    
    recent <- most_recent()
    period_label <- if (identical(comparison_effective_frequency(), "monthly")) "Months" else "Weeks"
    source_choice <- current_source_choice_safe(default = input$data_source_choice %||% "export_sales")
    metric_code <- effective_main_metric()
    effective_basis <- effective_basis_choice_for_metric(
      metric_code,
      current_basis_choice_safe(),
      source_choice
    )
    measurement_label <- get_metric_measurement_label(
      metric_code = metric_code,
      source_choice = source_choice,
      unit_choice = input$unit_choice,
      basis_choice = effective_basis,
      value_unit_choice = current_census_value_unit_choice_safe(),
      commodity_name = input$commodity_choice,
      active_tab = input$main_tabs_panel
    )
    paste(
      "Latest Year:", recent$year, "\n",
      paste0(period_label, " with data:"), paste(recent$months, collapse = ", "), "\n",
      "Historical years:", comparison_hist_years_committed(), "\n",
      "Measurement:", measurement_label
    )
  })

  get_custom_panel_metric <- function(input_id, preferred_metric) {
    current_value <- input[[input_id]]
    stored_value <- isolate(panel_state[[input_id]])
    selected_value <- if (!is.null(current_value)) current_value else stored_value
    sanitize_metric_for_choices(
      selected_value,
      custom_comparison_metric_choices(),
      preferred_metric = preferred_metric
    )
  }

  # Helper: build weekly comparison plot for a specific metric (used by Country Comparison tab)
  # Optional country_code and commodity_code allow panels to use different countries and rice types
  comparison_effective_single_reference_year <- function(hist_avg = NULL, years_used = NULL) {
    if (!identical(input$projection_basis_mode, "single_year")) {
      return(NA_real_)
    }

    candidate_years <- if (!is.null(years_used)) years_used else if (!is.null(hist_avg)) attr(hist_avg, "years_used") else NULL
    candidate_years <- sort(unique(suppressWarnings(as.numeric(candidate_years))))
    candidate_years <- candidate_years[is.finite(candidate_years)]
    if (length(candidate_years) == 1) {
      return(candidate_years[[1]])
    }

    ref_year <- suppressWarnings(as.numeric(input$projection_reference_year))
    if (length(ref_year) == 1 && is.finite(ref_year)) {
      return(ref_year)
    }

    NA_real_
  }

  comparison_reference_week_lookup_from_df <- function(df, effective_reference_year) {
    empty_lookup <- data.frame(
      analysis_month = numeric(0),
      reference_week_ending_date = as.Date(character(0))
    )

    if (is.null(df) || nrow(df) == 0 || !is.finite(effective_reference_year)) {
      return(empty_lookup)
    }

    required_cols <- c("market_year", "analysis_month", "week_ending_date")
    if (!all(required_cols %in% names(df))) {
      return(empty_lookup)
    }

    df %>%
      filter(.data$market_year == effective_reference_year, !is.na(.data$week_ending_date)) %>%
      mutate(reference_week_ending_date = as.Date(.data$week_ending_date)) %>%
      group_by(.data$analysis_month) %>%
      summarise(reference_week_ending_date = min(.data$reference_week_ending_date, na.rm = TRUE), .groups = "drop")
  }

  comparison_week_hover_text <- function(analysis_month, week_ending_date, include_na_date = FALSE) {
    ifelse(
      !is.na(week_ending_date),
      paste0("Week ", analysis_month, "<br>Week ending: ", format(as.Date(week_ending_date), "%m/%d/%Y")),
      ifelse(
        isTRUE(include_na_date),
        paste0("Week ", analysis_month, "<br>Week ending: NA"),
        paste0("Week ", analysis_month)
      )
    )
  }

  normalize_comparison_reference_week_shift <- function(value) {
    if (is.null(value) || length(value) == 0L) {
      value <- 0L
    }

    value <- suppressWarnings(as.integer(value[[1]]))
    if (is.na(value)) value <- 0L
    max(comparison_reference_week_shift_min, min(comparison_reference_week_shift_max, value))
  }

  comparison_reference_week_shift_status_text <- function(shift_value) {
    shift_value <- normalize_comparison_reference_week_shift(shift_value)
    ref_week_for_current_week_one <- 1L - shift_value
    shift_unit <- if (abs(shift_value) == 1L) "week" else "weeks"
    paste0(
      "Reference shift: ", shift_value, " ", shift_unit,
      " (Current W1 -> Ref W", ref_week_for_current_week_one, ")"
    )
  }

  comparison_shifted_reference_lookup_from_df <- function(df,
                                                          effective_reference_year,
                                                          metric_col,
                                                          shift_value,
                                                          analysis_month_values) {
    analysis_month_values <- suppressWarnings(as.integer(as.numeric(analysis_month_values)))
    analysis_month_values <- sort(unique(analysis_month_values[!is.na(analysis_month_values) & analysis_month_values > 0L]))

    empty_lookup <- data.frame(
      analysis_month = numeric(0),
      reference_analysis_month = numeric(0),
      reference_week_label = character(0),
      shifted_reference_value = numeric(0),
      shifted_reference_week_ending_date = as.Date(character(0))
    )

    if (length(analysis_month_values) == 0L) {
      return(empty_lookup)
    }

    shift_value <- normalize_comparison_reference_week_shift(shift_value)
    output_lookup <- data.frame(
      analysis_month = analysis_month_values,
      reference_analysis_month = analysis_month_values - shift_value,
      stringsAsFactors = FALSE
    ) %>%
      mutate(reference_week_label = paste0("Week ", .data$reference_analysis_month))

    required_cols <- c("market_year", "analysis_month", "week_ending_date", metric_col)
    if (is.null(df) || nrow(df) == 0 || !is.finite(effective_reference_year) || !all(required_cols %in% names(df))) {
      output_lookup$shifted_reference_value <- NA_real_
      output_lookup$shifted_reference_week_ending_date <- as.Date(NA)
      return(output_lookup)
    }

    reference_lookup <- df %>%
      filter(.data$market_year == effective_reference_year) %>%
      transmute(
        reference_analysis_month = as.integer(.data$analysis_month),
        shifted_reference_value = suppressWarnings(as.numeric(.data[[metric_col]])),
        shifted_reference_week_ending_date = as.Date(.data$week_ending_date)
      ) %>%
      group_by(.data$reference_analysis_month) %>%
      summarise(
        shifted_reference_value = {
          valid_values <- .data$shifted_reference_value[!is.na(.data$shifted_reference_value)]
          if (length(valid_values) == 0L) NA_real_ else mean(valid_values)
        },
        shifted_reference_week_ending_date = {
          valid_dates <- .data$shifted_reference_week_ending_date[!is.na(.data$shifted_reference_week_ending_date)]
          if (length(valid_dates) == 0L) as.Date(NA) else min(valid_dates)
        },
        .groups = "drop"
      )

    output_lookup %>%
      left_join(reference_lookup, by = "reference_analysis_month")
  }

  build_current_vs_historical_weekly_shift_frame <- function(current_df,
                                                             hist_avg_df,
                                                             reference_df,
                                                             effective_reference_year,
                                                             metric_col,
                                                             shift_value,
                                                             analysis_month_values = NULL) {
    empty_frame <- data.frame(
      analysis_month = numeric(0),
      current_value = numeric(0),
      week_ending_date = as.Date(character(0)),
      avg_value = numeric(0),
      min_value = numeric(0),
      max_value = numeric(0),
      sd_value = numeric(0),
      reference_analysis_month = numeric(0),
      reference_week_label = character(0),
      reference_week_ending_date = as.Date(character(0)),
      reference_value = numeric(0),
      reference_min_value = numeric(0),
      reference_max_value = numeric(0)
    )

    if (is.null(current_df) || is.null(hist_avg_df) || !("analysis_month" %in% names(hist_avg_df))) {
      return(empty_frame)
    }

    max_hist_week <- suppressWarnings(max(hist_avg_df$analysis_month, na.rm = TRUE))
    if (!is.finite(max_hist_week) || max_hist_week < 1) {
      return(empty_frame)
    }

    if (is.null(analysis_month_values)) {
      analysis_month_values <- seq_len(as.integer(max_hist_week))
    }

    analysis_month_values <- suppressWarnings(as.integer(as.numeric(analysis_month_values)))
    analysis_month_values <- sort(unique(analysis_month_values[!is.na(analysis_month_values) & analysis_month_values > 0L]))
    if (length(analysis_month_values) == 0L) {
      return(empty_frame)
    }

    weekly_frame <- data.frame(analysis_month = analysis_month_values) %>%
      left_join(current_df, by = "analysis_month") %>%
      left_join(hist_avg_df, by = "analysis_month")

    if (is.finite(effective_reference_year)) {
      shifted_lookup <- comparison_shifted_reference_lookup_from_df(
        df = reference_df,
        effective_reference_year = effective_reference_year,
        metric_col = metric_col,
        shift_value = shift_value,
        analysis_month_values = analysis_month_values
      )

      weekly_frame <- weekly_frame %>%
        left_join(shifted_lookup, by = "analysis_month") %>%
        mutate(
          reference_analysis_month = as.integer(.data$reference_analysis_month),
          reference_week_label = as.character(.data$reference_week_label),
          reference_week_ending_date = as.Date(.data$shifted_reference_week_ending_date),
          reference_value = .data$shifted_reference_value,
          reference_min_value = .data$shifted_reference_value,
          reference_max_value = .data$shifted_reference_value
        )
    } else {
      weekly_frame <- weekly_frame %>%
        mutate(
          reference_analysis_month = as.integer(.data$analysis_month),
          reference_week_label = paste0("Week ", .data$analysis_month),
          reference_week_ending_date = as.Date(NA),
          reference_value = .data$avg_value,
          reference_min_value = .data$min_value,
          reference_max_value = .data$max_value
        )
    }

    weekly_frame
  }

  build_weekly_metric_comparison_plot <- function(metric, country_code = NULL, commodity_code = NULL, y_range_override = NULL, vp_commodity_name_code = NULL) {
    # Allow both weekly and monthly data
    
    target_country <- if (is.null(country_code)) input$country_choice else country_code
    target_commodity <- if (is.null(commodity_code)) input$commodity_choice else commodity_code
    source_choice <- current_source_choice_safe(default = input$data_source_choice %||% "export_sales")
    effective_frequency <- if (source_choice %in% c("psd", "wasde")) "monthly" else input$data_frequency
    display_month_mapping <- current_display_month_mapping(source_choice = source_choice)
    display_month_axis_title <- current_display_month_axis_title(source_choice = source_choice, display_month_mapping = display_month_mapping)
    df <- filtered_data_for_country(
      target_country,
      target_commodity,
      consumer = "weekly_metric_comparison_plot",
      vp_commodity_name_code = vp_commodity_name_code
    )
    if (nrow(df) == 0) {
      return(plotly_empty_state(plot_title = "No data available for this selection"))
    }
    
    recent <- most_recent()
    if (is.null(recent)) {
      return(plotly_empty_state(plot_title = "No recent data available"))
    }
    
    recent_year <- recent$year
    hist_window <- comparison_hist_years_committed()
    hist_years_vec <- historical_years_for_window(df$market_year, recent_year, hist_window)

    sum_metric_or_na <- function(values) {
      values <- suppressWarnings(as.numeric(values))
      if (length(values) == 0 || all(is.na(values))) NA_real_ else sum(values, na.rm = TRUE)
    }

    first_date_or_na <- function(values) {
      values <- as.Date(values)
      values <- values[!is.na(values)]
      if (length(values) == 0) as.Date(NA) else min(values)
    }
    
    # Current year data for the chosen metric
    current <- if (identical(effective_frequency, "weekly") && "week_ending_date" %in% names(df)) {
      df %>%
        filter(market_year == recent_year) %>%
        select(analysis_month, market_year, week_ending_date, value = all_of(metric)) %>%
        group_by(analysis_month, market_year) %>%
        summarise(
          current_value = sum_metric_or_na(value),
          week_ending_date = first_date_or_na(week_ending_date),
          .groups = "drop"
        ) %>%
        arrange(analysis_month)
    } else {
      df %>%
        filter(market_year == recent_year) %>%
        select(analysis_month, market_year, value = all_of(metric)) %>%
        group_by(analysis_month, market_year) %>%
        summarise(
          current_value = sum_metric_or_na(value),
          .groups = "drop"
        ) %>%
        arrange(analysis_month)
    }
    
    # Historical average/reference year for the chosen metric
    reference_input_year <- suppressWarnings(as.numeric(input$projection_reference_year))
    hist_df <- if (identical(input$projection_basis_mode, "single_year") && length(reference_input_year) == 1 && is.finite(reference_input_year)) {
      df %>% filter(market_year == reference_input_year)
    } else {
      df %>% filter(market_year %in% hist_years_vec)
    }
    
    if (nrow(hist_df) == 0) {
      return(plotly_empty_state(plot_title = "Insufficient historical data for this metric"))
    }
    
    # Track which marketing years actually contributed to the historical average
    hist_years_used <- sort(unique(hist_df$market_year))
    effective_reference_year <- comparison_effective_single_reference_year(years_used = hist_years_used)

    hist_avg <- hist_df %>%
      select(market_year, analysis_month, value = all_of(metric)) %>%
      group_by(market_year, analysis_month) %>%
      summarise(value = sum_metric_or_na(value), .groups = "drop") %>%
      group_by(analysis_month) %>%
      summarise(
        avg_value = if (all(is.na(.data$value))) NA_real_ else mean(.data$value, na.rm = TRUE),
        min_value = if (all(is.na(.data$value))) NA_real_ else min(.data$value, na.rm = TRUE),
        max_value = if (all(is.na(.data$value))) NA_real_ else max(.data$value, na.rm = TRUE),
        .groups = "drop"
      )
    
    if (nrow(hist_avg) == 0) {
      return(plotly_empty_state(plot_title = "Insufficient historical data for this metric"))
    }
    
    if (identical(effective_frequency, "monthly")) {
      # Monthly: use all 12 months
      all_months <- display_month_mapping %>%
        select(analysis_month, month_name)
      
      comparison <- all_months %>%
        left_join(current, by = "analysis_month") %>%
        left_join(hist_avg, by = "analysis_month") %>%
        mutate(
          x_label = factor(month_name, levels = display_month_mapping$month_name),
          hover_period_text = paste0("Month: ", month_name),
          current_hover_period_text = hover_period_text,
          reference_hover_period_text = hover_period_text,
          x_numeric = as.numeric(analysis_month)
        ) %>%
        arrange(x_numeric)
    } else {
      # Weekly: create week labels
      max_hist_week <- max(hist_avg$analysis_month, na.rm = TRUE)
      all_weeks <- data.frame(analysis_month = 1:max_hist_week)
      reference_week_lookup <- comparison_reference_week_lookup_from_df(df, effective_reference_year)
      
      comparison <- all_weeks %>%
        left_join(current, by = "analysis_month") %>%
        left_join(hist_avg, by = "analysis_month") %>%
        left_join(reference_week_lookup, by = "analysis_month") %>%
        mutate(
          x_label = paste0("W", analysis_month),
          current_hover_period_text = comparison_week_hover_text(analysis_month, week_ending_date),
          reference_hover_period_text = if (identical(input$projection_basis_mode, "single_year") && is.finite(effective_reference_year)) {
            comparison_week_hover_text(analysis_month, reference_week_ending_date, include_na_date = TRUE)
          } else {
            paste0("Week ", analysis_month, "<br>Week ending: NA")
          },
          hover_period_text = current_hover_period_text,
          x_numeric = as.numeric(analysis_month)
        ) %>%
        arrange(x_numeric)
    }

    # Projection helper (per-panel, country/commodity aware)
    compute_projection <- function(df_panel, metric_panel, commodity_panel, country_panel) {
      cumulative_metrics <- projection_metric_choices_for_source(
        current_source_choice_safe(default = input$data_source_choice %||% "export_sales")
      )
      if (!(metric_panel %in% cumulative_metrics)) return(NULL)

      recent_year <- recent$year
      projection_panel <- df_panel %>%
        select(market_year, analysis_month, value = all_of(metric_panel)) %>%
        group_by(market_year, analysis_month) %>%
        summarise(value = sum_metric_or_na(value), .groups = "drop")

      hist_years_vec <- historical_years_for_window(projection_panel$market_year, recent_year, hist_window)

      # Determine total periods (weekly: last hist week available in window)
      hist_base <- if (identical(input$projection_basis_mode, "single_year") && !is.null(input$projection_reference_year)) {
        projection_panel %>% filter(market_year == as.numeric(input$projection_reference_year))
      } else {
        projection_panel %>% filter(market_year %in% hist_years_vec)
      }
      
      hist_weeks <- hist_base %>%
        pull(analysis_month) %>%
        unique()
      if (length(hist_weeks) == 0) return(NULL)
      total_periods <- max(hist_weeks, na.rm = TRUE)

      # Current year data
      current_panel <- projection_panel %>%
        filter(market_year == recent_year) %>%
        select(analysis_month, value) %>%
        dplyr::rename(current_value = value) %>%
        arrange(analysis_month)
      current_with_value <- current_panel %>% filter(!is.na(current_value))
      if (nrow(current_with_value) == 0) return(NULL)
      current_period <- max(current_with_value$analysis_month, na.rm = TRUE)
      current_value <- current_with_value %>% filter(analysis_month == current_period) %>% pull(current_value)
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
          projection_warning = projection_warning
        ))
      }

      # Historical Pattern
      complete_hist_years <- hist_base %>%
        group_by(market_year) %>%
        filter(max(analysis_month) >= total_periods - 1) %>%
        ungroup()

      if (nrow(complete_hist_years) == 0) {
        final_projection <- current_value * (total_periods / current_period)
      } else {
        final_values <- complete_hist_years %>%
          filter(analysis_month == total_periods) %>%
          filter(!is.na(.data$value)) %>%
          select(market_year, final_value = value)

        if (nrow(final_values) == 0) {
          final_projection <- current_value * (total_periods / current_period)
        } else {
          hist_at_current_period <- complete_hist_years %>%
            filter(analysis_month == current_period) %>%
            filter(!is.na(.data$value)) %>%
            select(market_year, value_at_period = value) %>%
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

      # Linear fit (anchor at first point)
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
        r_squared <- if (ss_tot > 0) 1 - (ss_res / ss_tot) else NA

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
        projection_warning = projection_warning
      )
    }
    
    current_year_label <- build_current_year_trace_label(recent_year, source_choice = source_choice, display_month_mapping = display_month_mapping)
    reference_year_label <- if (identical(input$projection_basis_mode, "single_year") && is.finite(effective_reference_year)) {
      build_single_reference_year_label(effective_reference_year, source_choice = source_choice, display_month_mapping = display_month_mapping)
    } else {
      paste0("Historical Avg (", hist_window, " yrs)")
    }

    metric_code_active <- trimws(as.character(metric %||% ""))
    metric_unit_label <- get_metric_measurement_label(
      metric_code = metric,
      source_choice = source_choice,
      unit_choice = input$unit_choice,
      basis_choice = input$basis_choice,
      value_unit_choice = current_census_value_unit_choice_safe(),
      commodity_name = target_commodity,
      active_tab = input$main_tabs_panel
    )

    if (identical(source_choice, "vp_trade") && metric_code_active %in% c("unit_value", "ytd_unit_value")) {
      custom_comparison_unit_context <- build_unit_resolution_context(
        tab_id = input$main_tabs_panel %||% current_main_tab_safe(),
        output_id = "weekly_metric_comparison_plot",
        source_choice = source_choice,
        metric_code = metric_code_active,
        trade_flow = input$vp_trade_flow_choice %||% "export",
        hierarchy_path = paste(
          input$vp_group_choice %||% "",
          input$vp_subgroup_choice %||% "",
          input$vp_market_segment_choice %||% "",
          vp_commodity_name_code %||% input$vp_commodity_name_choice %||% "",
          target_commodity %||% "",
          sep = "|"
        ),
        country_scope = target_country %||% "",
        market_scope = input$market_year_choice %||% "",
        rollup_level = input$vp_market_segment_choice %||% "",
        rollup_path = paste(
          input$vp_group_choice %||% "",
          input$vp_subgroup_choice %||% "",
          input$vp_market_segment_choice %||% "",
          sep = "|"
        ),
        run_id = "weekly_metric_comparison_unit_resolution"
      )

      custom_comparison_unit_resolution <- tryCatch(
        resolve_vp_trade_display_unit(
          metric_code = metric_code_active,
          rows = df,
          context = custom_comparison_unit_context
        ),
        error = function(...) NULL
      )

      if (is.list(custom_comparison_unit_resolution)) {
        unit_guardrail_record_event(
          unit_resolution = custom_comparison_unit_resolution,
          context = custom_comparison_unit_context
        )
        if (!is.null(custom_comparison_unit_resolution$label) && nzchar(custom_comparison_unit_resolution$label)) {
          metric_unit_label <- custom_comparison_unit_resolution$label
        }
      }
    }

    value_hover_prefix <- if (!is.null(metric_unit_label) && nzchar(metric_unit_label)) {
      paste0("Value (", metric_unit_label, "): ")
    } else {
      "Value: "
    }

    p <- plot_ly(comparison) %>%
      add_trace(
        x = ~x_numeric,
        y = ~current_value,
        text = ~current_hover_period_text,
        type = "scatter",
        mode = "lines+markers",
        name = current_year_label,
        line = list(color = "#d62728", width = 3),
        marker = list(size = 8),
        hovertemplate = paste0("<b>", current_year_label, "</b><br>%{text}<br>", value_hover_prefix, "%{y:.2f}<extra></extra>")
      ) %>%
      add_trace(
        x = ~x_numeric,
        y = ~avg_value,
        text = ~reference_hover_period_text,
        type = "scatter",
        mode = "lines+markers",
        name = reference_year_label,
        line = list(color = "#1f77b4", width = 2, dash = "dash"),
        marker = list(size = 6),
        hovertemplate = paste0("<b>", reference_year_label, "</b><br>%{text}<br>", value_hover_prefix, "%{y:.2f}<extra></extra>")
      ) %>%
      add_ribbons(
        x = ~x_numeric,
        ymin = ~min_value,
        ymax = ~max_value,
        name = "Historical Range",
        fillcolor = "rgba(31, 119, 184, 0.1)",
        line = list(color = "rgba(31, 119, 184, 0)")
      )
    
    metric_display_name <- paste0(
      get_metric_label_for_context(metric),
      " (",
      metric_unit_label,
      ")"
    )
    
    display_country <- if (identical(input$data_source_choice, "census") && identical(target_country, "GRAND_TOTAL")) {
      "World"
    } else {
      get_display_country(target_country)
    }
    
    # Title components
    title_metric <- get_metric_label_for_context(metric)
    title_country <- get_display_country(target_country)
    title_commodity <- get_commodity_display_label(target_commodity, input$basis_choice)
    title_text <- paste(title_metric, title_country, title_commodity, sep = " - ")

    # Optional projections
    proj <- compute_projection(df, metric, target_commodity, target_country)
    show_any_projection <- FALSE
    show_total <- FALSE
    show_sum <- FALSE
    show_linear <- FALSE
    is_custom_comparison_context <- identical(input$main_tabs_panel, "Custom Comparison Tool")

    if (!is.null(proj)) {
      projection_blocked <- !isTRUE(proj$projection_valid)

      if (projection_blocked) {
        show_total <- FALSE
        show_sum <- FALSE
        show_linear <- FALSE
      } else if (target_country == "GRAND_TOTAL") {
        show_total <- source_allows_historical_projection() && isTRUE(input$show_total_projection)
        show_sum <- source_allows_historical_projection() && !is_custom_comparison_context && isTRUE(input$show_sum_projection)
        show_linear <- isTRUE(input$show_linear_projection)

        # Compute sum-of-countries projection for Grand Total (Historical Pattern per country), safely
        if (show_sum) {
          proj$country_sum_projection <- tryCatch({
            recent_year_panel <- recent$year
            
            # Fetch all relevant data for the commodity ONCE
            record_cache_body_execution(session, "selected_data_read_weekly_metric_comparison_plot", details = list(source = input$data_source_choice %||% "export_sales", commodity = target_commodity, metric = metric))
            df_all <- selected_data() %>%
              filter(commodity == target_commodity, country != "GRAND_TOTAL")
            
            if (nrow(df_all) == 0) return(NULL)
            
            # --- 1. Identify valid countries and their most recent data point ---
            current_stats <- df_all %>%
              filter(market_year == recent_year_panel) %>%
              filter(!is.na(.data[[metric]])) %>%
              group_by(country) %>%
              summarise(
                current_period_cty = max(analysis_month, na.rm = TRUE),
                current_value_cty = .data[[metric]][which.max(analysis_month)],
                .groups = "drop"
              )
            # If no countries have current data, return NULL
            if (nrow(current_stats) == 0) return(NULL)
            
            # --- 2. Determine historical cutoff (max week) for each country ---
            # Used to determine 'total_periods' per country
            hist_years_panel_vec <- historical_years_for_window(df_all$market_year, recent_year_panel, hist_window)
            hist_all_base <- if (identical(input$projection_basis_mode, "single_year") && !is.null(input$projection_reference_year)) {
              df_all %>% filter(market_year == as.numeric(input$projection_reference_year))
            } else {
              df_all %>% filter(market_year %in% hist_years_panel_vec)
            }

            hist_stats <- hist_all_base %>%
              filter(!is.na(.data[[metric]])) %>%
              group_by(country) %>%
              summarise(
                total_periods_cty = max(analysis_month, na.rm = TRUE),
                .groups = "drop"
              )

            # Join current and historical metadata
            proj_base <- inner_join(current_stats, hist_stats, by = "country")
            if (nrow(proj_base) == 0) return(NULL)

            # --- 3. Compute Historical Completion Rates for all countries (Vectorized) ---
            # Instead of iterating, we process everything via joins.

            # Subset relevant history
            hist_data_subset <- hist_all_base %>%
              select(country, market_year, analysis_month, value = all_of(metric)) %>%
              filter(!is.na(value))
            
            # Step A: Identify complete years for each country
            # A year is complete if it has data up to the country's historical max week (total_periods_cty)
            # Create a lookup of required max week per country
            requirements <- proj_base %>% select(country, total_periods_cty)
            
            # Find max week per country-year
            year_max_weeks <- hist_data_subset %>%
              group_by(country, market_year) %>%
              summarise(max_w = max(analysis_month), .groups = "drop")
            
            # Filter to only complete years
            valid_years <- year_max_weeks %>%
              inner_join(requirements, by = "country") %>%
              filter(max_w >= total_periods_cty - 1) %>%
              select(country, market_year)
            
            # Step B: Get values at critical weeks (current week & final week) for valid years
            # Joined with proj_base to get the target weeks
            
            # Get Final Values (at total_periods_cty)
            final_vals <- hist_data_subset %>%
              inner_join(valid_years, by = c("country", "market_year")) %>%
              inner_join(proj_base %>% select(country, total_periods_cty), by = "country") %>%
              filter(analysis_month == total_periods_cty) %>%
              group_by(country, market_year) %>% summarise(final_val = (sum(value, na.rm = TRUE) * (NA_real_ ^ (sum(!is.na(value)) == 0))), .groups = "drop")
            
            # Get Period Values (at current_period_cty)
            period_vals <- hist_data_subset %>%
              inner_join(valid_years, by = c("country", "market_year")) %>%
              inner_join(proj_base %>% select(country, current_period_cty), by = "country") %>%
              filter(analysis_month == current_period_cty) %>%
              group_by(country, market_year) %>% summarise(period_val = (sum(value, na.rm = TRUE) * (NA_real_ ^ (sum(!is.na(value)) == 0))), .groups = "drop")
            
            # Step C: Calculate average completion rate per country
            country_factors <- inner_join(final_vals, period_vals, by = c("country", "market_year")) %>%
              mutate(pct = period_val / final_val) %>%
              group_by(country) %>%
              summarise(avg_pct = mean(pct, na.rm = TRUE), .groups = "drop") %>%
              filter(!is.na(avg_pct) & avg_pct > 0)
            
            # Step D: Apply projection
            # Join factors back to base. Use factor if available, else linear fallback.
            results <- proj_base %>%
              left_join(country_factors, by = "country") %>%
              mutate(
                linear_proj = current_value_cty * (total_periods_cty / current_period_cty),
                final_proj = ifelse(!is.na(avg_pct), 
                                    current_value_cty / avg_pct, 
                                    linear_proj)
              )
            
            (sum(results$final_proj, na.rm = TRUE) * (NA_real_ ^ (sum(!is.na(results$final_proj)) == 0)))
          }, error = function(e) {
            NULL
          })
        }
      } else {
        # Fallback logic: Use specific country toggles if available, otherwise use Grand Total toggles
        
        # 1. Historical Pattern
        if (!is.null(input$show_projections)) {
          show_total <- source_allows_historical_projection() && isTRUE(input$show_projections)
        } else if (!is.null(input$show_total_projection)) {
          show_total <- source_allows_historical_projection() && isTRUE(input$show_total_projection)
        } else {
          show_total <- source_allows_historical_projection()
        }

        # 2. Linear Fit
        if (!is.null(input$show_linear_projection_country) &&
            !is.null(input$projection_basis_mode) &&
            !is.null(input$projection_reference_year)) {
          show_linear <- isTRUE(input$show_linear_projection_country)
        } else if (!is.null(input$show_linear_projection)) {
          show_linear <- isTRUE(input$show_linear_projection)
        } else {
          show_linear <- FALSE
        }
      }
      show_any_projection <- show_total || show_linear || show_sum
    }

    # Consolidated annotations list to prevent overwriting
    all_annotations <- list()

    if (!is.null(proj) && !is.null(proj$projection_warning)) {
      all_annotations[[length(all_annotations) + 1]] <- list(
        text = paste0("<span style='color:#b45309'><b>", proj$projection_warning, "</b></span>"),
        x = 0.5,
        y = 1.01,
        xref = "paper",
        yref = "paper",
        xanchor = "center",
        yanchor = "bottom",
        showarrow = FALSE,
        align = "center",
        bgcolor = "rgba(255,243,205,0.9)",
        bordercolor = "#ffeeba",
        borderwidth = 1,
        font = list(size = 11)
      )
    }
    
    if (show_any_projection) {
      y_offsets <- list(total = 0, sum = -18, linear = -36)
      scorecard_entries <- list()

      if (show_total && !is.null(proj$final_projection)) {
        proj_line_data <- data.frame(
          x = c(proj$current_period, proj$total_periods),
          y = c(proj$current_value, proj$final_projection)
        )
        
        val_str <- format(round(proj$final_projection, 0), big.mark = ",")
        scorecard_entries[[length(scorecard_entries) + 1]] <- list(
          val = proj$final_projection,
          text = paste0("<span style='color:#2ca02c'><b>Year-End:</b> ", val_str, "</span>")
        )

        p <- p %>%
          add_trace(
            data = proj_line_data,
            x = ~x,
            y = ~y,
            type = "scatter",
            mode = "lines+markers",
            name = "Year-End Projection",
            showlegend = FALSE, # Hide from legend to save space
            line = list(color = "#2ca02c", width = 3, dash = "dash"),
            marker = list(size = 10, symbol = "diamond", color = "#2ca02c")
          )
      }

      if (show_sum && !is.null(proj$country_sum_projection)) {
        proj_line_sum <- data.frame(
          x = c(proj$current_period, proj$total_periods),
          y = c(proj$current_value, proj$country_sum_projection)
        )
        
        val_str <- format(round(proj$country_sum_projection, 0), big.mark = ",")
        scorecard_entries[[length(scorecard_entries) + 1]] <- list(
          val = proj$country_sum_projection,
          text = paste0("<span style='color:#9467bd'><b>Sum of Countries:</b> ", val_str, "</span>")
        )

        p <- p %>%
          add_trace(
            data = proj_line_sum,
            x = ~x,
            y = ~y,
            type = "scatter",
            mode = "lines+markers",
            name = "Sum of Countries",
            showlegend = FALSE, # Hide from legend to save space
            line = list(color = "#9467bd", width = 3, dash = "dot"),
            marker = list(size = 10, symbol = "square", color = "#9467bd")
          )
      }

      linear_fit_ready <-
        show_linear &&
        !is.null(proj$linear_projection) &&
        !is.null(proj$linear_fit_data) &&
        !is.null(proj$linear_fit_data$anchor_point) &&
        length(proj$linear_fit_data$anchor_point$x) == 1 &&
        length(proj$linear_fit_data$anchor_point$y) == 1 &&
        length(proj$linear_fit_data$intercept) == 1 &&
        length(proj$linear_fit_data$slope) == 1 &&
        length(proj$linear_fit_data$r_squared) == 1

      if (linear_fit_ready) {
        fit_data <- proj$linear_fit_data
        x_vals <- c(fit_data$anchor_point$x, proj$total_periods)
        y_vals <- c(fit_data$anchor_point$y, proj$linear_projection)

        proj_line_linear <- data.frame(x = x_vals, y = y_vals)
        if (fit_data$intercept >= 0) {
          eq_text <- sprintf("(y = %.1fx + %.0f)", fit_data$slope, fit_data$intercept)
        } else {
          eq_text <- sprintf("(y = %.1fx - %.0f)", fit_data$slope, abs(fit_data$intercept))
        }
        
        val_str <- format(round(proj$linear_projection, 0), big.mark = ",")
        scorecard_entries[[length(scorecard_entries) + 1]] <- list(
          val = proj$linear_projection,
          text = paste0("<span style='color:#ff7f0e'><b>Linear Fit:</b> ", val_str, " <span style='font-size:0.9em'>", eq_text, "</span></span>")
        )

        p <- p %>%
          add_trace(
            data = proj_line_linear,
            x = ~x,
            y = ~y,
            type = "scatter",
            mode = "lines",
            name = paste0("Linear Fit (R²=", round(fit_data$r_squared, 3), ")"),
            showlegend = FALSE, # Hide from legend to save space
            line = list(color = "#ff7f0e", width = 2, dash = "dashdot"),
            hovertemplate = paste0(
              "<b>%{text}</b><br>",
              "Week %{x}: %{y:,.0f}",
              "<extra>Linear Fit</extra>"
            ),
            text = eq_text  # Make equation available in hover
          )
      }

      # Add scorecard annotation
      if (length(scorecard_entries) > 0) {
        # Sort entries by projection value (descending) so highest is at top
        scorecard_entries <- scorecard_entries[order(sapply(scorecard_entries, function(x) x$val), decreasing = TRUE)]
        scorecard_text <- paste(sapply(scorecard_entries, function(x) x$text), collapse = "<br>")
        
        all_annotations[[length(all_annotations) + 1]] <- list(
          text = scorecard_text,
          x = 0.08,  # Shifted further right
          y = 0.98,
          xref = "paper",
          yref = "paper",
          xanchor = "left",
          yanchor = "top",
          showarrow = FALSE,
          align = "left",
          bgcolor = "rgba(255, 255, 255, 0.8)",
          bordercolor = "#e0e0e0",
          borderwidth = 1,
          font = list(size = 11)
        )
      }
    }

    # Use annotation for title to center over plot area (excluding legend)
    all_annotations[[length(all_annotations) + 1]] <- list(
      text = title_text,
      x = 0.5,
      y = 1.05,
      xref = "paper",
      yref = "paper",
      xanchor = "center",
      yanchor = "bottom",
      showarrow = FALSE,
      font = list(size = 14)
    )

    y_axis_config <- if (is.null(y_range_override)) {
      list(
        title = metric_display_name,
        rangemode = "tozero"
      )
    } else {
      list(
        title = metric_display_name,
        range = y_range_override
      )
    }

    x_axis_config <- if (identical(effective_frequency, "monthly")) {
      list(
        title = display_month_axis_title,
        tickvals = 1:12,
        ticktext = display_month_mapping$month_abbrev
      )
    } else {
      displayed_max_week <- max(comparison$analysis_month, na.rm = TRUE)
      if (!is.null(proj) && isTRUE(proj$projection_valid) && is.finite(proj$total_periods)) {
        displayed_max_week <- max(displayed_max_week, proj$total_periods, na.rm = TRUE)
      }

      build_weekly_x_axis_config_from_dates(
        label_source_df = current,
        axis_title = "Week Number",
        month_label_style = "abbrev",
        include_latest_label = TRUE,
        fallback_max_week = displayed_max_week,
        year_type = current_display_year_type(
          source_choice = current_source_choice_safe(default = input$data_source_choice %||% "export_sales")
        )
      )
    }

    p %>%
      layout(
        annotations = all_annotations,
        margin = list(t = 50, r = 20, b = 75, l = 70),
        xaxis = modifyList(x_axis_config, list(automargin = TRUE)),
        yaxis = modifyList(y_axis_config, list(automargin = TRUE)),
        hovermode = "x unified",
        showlegend = TRUE
      )
  }

  is_custom_comparison_output_active <- function() {
    identical(current_main_tab_safe(), "Custom Comparison Tool")
  }

  record_cct_plot_output_lifecycle <- function(output_name, state) {
    record_cache_body_execution(session, paste0(output_name, "_", state))
    record_cache_body_execution(session, paste0("cct_plot_output_", state))
  }

  cct_runtime_source_choice <- function() {
    current_source_choice_safe(default = "vp_trade")
  }

  top_left_y_range <- reactive({
    if (!isTRUE(input$lock_to_top_left_scale)) return(NULL)
    if (!is_custom_comparison_output_active()) {
      record_cache_body_execution(session, "cct_top_left_y_range_gated_skip")
      return(NULL)
    }
    record_cache_body_execution(session, "cct_top_left_y_range_executed")

    req(effective_main_metric())

    top_left_plot <- build_weekly_metric_comparison_plot(effective_main_metric())
    built <- tryCatch(plotly_build(top_left_plot), error = function(e) NULL)
    if (is.null(built) || is.null(built$x) || is.null(built$x$data)) return(NULL)

    y_values <- unlist(lapply(built$x$data, function(tr) tr$y), use.names = FALSE)
    y_values <- suppressWarnings(as.numeric(y_values))
    y_values <- y_values[is.finite(y_values)]
    if (length(y_values) == 0) return(NULL)

    ymax <- max(y_values, na.rm = TRUE)
    if (!is.finite(ymax)) return(NULL)

    # Keep a little headroom so lines don't sit against the top border.
    upper <- if (ymax <= 0) 1 else ymax * 1.02
    c(0, upper)
  })

  # Debounce lock-range updates so layout toggles settle before dependent panels render.
  top_left_y_range_debounced <- debounce(top_left_y_range, 200)

  # Output: Country Comparison plots (2-up view)
  output$comparison_left_plot <- renderPlotly({
    if (!is_custom_comparison_output_active()) {
      record_cct_plot_output_lifecycle("comparison_left_plot", "gated_skip")
      return(NULL)
    }
      start_time <- Sys.time()
    source_choice <- cct_runtime_source_choice()
    # Left panel metric is controlled by main Variable to Analyze selection
    req(effective_main_metric())
      record_cct_plot_output_lifecycle("comparison_left_plot", "executed")
      result <- build_weekly_metric_comparison_plot(effective_main_metric())
      log_perf(
        "comparison_left_plot",
        start_time,
        details = list(
          metric = effective_main_metric(),
          country = input$country_choice,
          commodity = input$commodity_choice,
          source = source_choice
        )
      )
      result
  })

  output$comparison_right_plot <- renderPlotly({
    if (!is_custom_comparison_output_active()) {
      record_cct_plot_output_lifecycle("comparison_right_plot", "gated_skip")
      return(NULL)
    }
      start_time <- Sys.time()
    source_choice <- cct_runtime_source_choice()
    req(input$metric_right, input$country_right_2up, input$commodity_right_2up)
    req(!isTRUE(input$show_metric_grid))
    record_cct_plot_output_lifecycle("comparison_right_plot", "executed")
    panel_metric <- get_custom_panel_metric("metric_right", "monthlyexports")
    locked_range <- top_left_y_range_debounced()
      result <- build_weekly_metric_comparison_plot(
      panel_metric,
      country_code = input$country_right_2up,
      commodity_code = input$commodity_right_2up,
      y_range_override = locked_range,
      vp_commodity_name_code = input$vp_commodity_name_right_2up %||% input$vp_commodity_name_choice
    )
      log_perf(
        "comparison_right_plot",
        start_time,
        details = list(
          metric = panel_metric,
          country = input$country_right_2up,
          commodity = input$commodity_right_2up,
          source = source_choice,
          lock_to_top_left_scale = isTRUE(input$lock_to_top_left_scale)
        )
      )
      result
  })

  # Output: Metric grid plots (user-selectable metrics)
  output$metric_grid_plot_1 <- renderPlotly({
    if (!is_custom_comparison_output_active()) {
      record_cct_plot_output_lifecycle("metric_grid_plot_1", "gated_skip")
      return(NULL)
    }
      start_time <- Sys.time()
    source_choice <- cct_runtime_source_choice()
    # Top-left grid metric is controlled by main Variable to Analyze selection
    req(effective_main_metric())
      record_cct_plot_output_lifecycle("metric_grid_plot_1", "executed")
      result <- build_weekly_metric_comparison_plot(effective_main_metric())
      log_perf(
        "metric_grid_plot_1",
        start_time,
        details = list(
          metric = effective_main_metric(),
          country = input$country_choice,
          commodity = input$commodity_choice,
          source = source_choice
        )
      )
      result
  })

  output$metric_grid_plot_2 <- renderPlotly({
    if (!is_custom_comparison_output_active()) {
      record_cct_plot_output_lifecycle("metric_grid_plot_2", "gated_skip")
      return(NULL)
    }
      start_time <- Sys.time()
    source_choice <- cct_runtime_source_choice()
    req(isTRUE(input$show_metric_grid))
    req(input$metric_right, input$country_right_2up, input$commodity_right_2up)
    record_cct_plot_output_lifecycle("metric_grid_plot_2", "executed")
    panel_metric <- get_custom_panel_metric("metric_right", "monthlyexports")
    locked_range <- top_left_y_range_debounced()
      result <- build_weekly_metric_comparison_plot(
      panel_metric,
      country_code = input$country_right_2up,
      commodity_code = input$commodity_right_2up,
      y_range_override = locked_range,
      vp_commodity_name_code = input$vp_commodity_name_right_2up %||% input$vp_commodity_name_choice
    )
      log_perf(
        "metric_grid_plot_2",
        start_time,
        details = list(
          metric = panel_metric,
          country = input$country_right_2up,
          commodity = input$commodity_right_2up,
          source = source_choice
        )
      )
      result
  })

  output$metric_grid_plot_3 <- renderPlotly({
    if (!is_custom_comparison_output_active()) {
      record_cct_plot_output_lifecycle("metric_grid_plot_3", "gated_skip")
      return(NULL)
    }
      start_time <- Sys.time()
    source_choice <- cct_runtime_source_choice()
    metric <- get_custom_panel_metric("metric_grid_3", "outstandingSales")
    req(input$country_grid_3, input$commodity_grid_3)
    record_cct_plot_output_lifecycle("metric_grid_plot_3", "executed")
    locked_range <- top_left_y_range_debounced()
      result <- build_weekly_metric_comparison_plot(
      metric,
      country_code = input$country_grid_3,
      commodity_code = input$commodity_grid_3,
      y_range_override = locked_range,
      vp_commodity_name_code = input$vp_commodity_name_grid_3 %||% input$vp_commodity_name_choice
    )
      log_perf(
        "metric_grid_plot_3",
        start_time,
        details = list(
          metric = metric,
          country = input$country_grid_3,
          commodity = input$commodity_grid_3,
          source = source_choice
        )
      )
      result
  })

  output$metric_grid_plot_4 <- renderPlotly({
    if (!is_custom_comparison_output_active()) {
      record_cct_plot_output_lifecycle("metric_grid_plot_4", "gated_skip")
      return(NULL)
    }
      start_time <- Sys.time()
    source_choice <- cct_runtime_source_choice()
    metric <- get_custom_panel_metric("metric_grid_4", if ("total_commitment" %in% custom_valid_metric_codes()) "total_commitment" else if ("ytd_value" %in% custom_valid_metric_codes()) "ytd_value" else "monthlyexports")
    req(input$country_grid_4, input$commodity_grid_4)
    record_cct_plot_output_lifecycle("metric_grid_plot_4", "executed")
    locked_range <- top_left_y_range_debounced()
      result <- build_weekly_metric_comparison_plot(
      metric,
      country_code = input$country_grid_4,
      commodity_code = input$commodity_grid_4,
      y_range_override = locked_range,
      vp_commodity_name_code = input$vp_commodity_name_grid_4 %||% input$vp_commodity_name_choice
    )
      log_perf(
        "metric_grid_plot_4",
        start_time,
        details = list(
          metric = metric,
          country = input$country_grid_4,
          commodity = input$commodity_grid_4,
          source = source_choice
        )
      )
      result
  })

  output$comparison_overlay_plot <- renderPlotly({
    if (!is_custom_comparison_output_active()) {
      record_cct_plot_output_lifecycle("comparison_overlay_plot", "gated_skip")
      return(NULL)
    }
      start_time <- Sys.time()
    req(effective_main_metric(), input$country_choice, input$commodity_choice)
    record_cct_plot_output_lifecycle("comparison_overlay_plot", "executed")

    source_choice <- cct_runtime_source_choice()
    effective_frequency <- comparison_effective_frequency()
    display_month_mapping <- current_display_month_mapping(source_choice = source_choice)
    display_month_axis_title <- current_display_month_axis_title(source_choice = source_choice, display_month_mapping = display_month_mapping)

    main_metric <- effective_main_metric()
    right_metric <- get_custom_panel_metric("metric_right", "monthlyexports")
    grid3_metric <- get_custom_panel_metric("metric_grid_3", "outstandingSales")
    grid4_metric <- get_custom_panel_metric("metric_grid_4", if ("total_commitment" %in% custom_valid_metric_codes()) "total_commitment" else if ("ytd_value" %in% custom_valid_metric_codes()) "ytd_value" else "monthlyexports")

    if (!(isTRUE(input$lock_to_top_left_scale) && isTRUE(input$overlay_visible_panels))) {
        result <- plotly_empty_state(plot_title = "Overlay mode is not active")
        log_perf(
          "comparison_overlay_plot",
          start_time,
          details = list(
            source = source_choice,
            show_metric_grid = isTRUE(input$show_metric_grid),
            overlay_visible_panels = isTRUE(input$overlay_visible_panels),
            rows = 0
          )
        )
        return(result)
    }

    show_grid <- isTRUE(input$show_metric_grid)

    recent <- most_recent()
    if (is.null(recent)) {
      result <- plotly_empty_state(plot_title = "No recent data available")
      log_perf(
        "comparison_overlay_plot",
        start_time,
        details = list(
          source = source_choice,
          show_metric_grid = isTRUE(input$show_metric_grid),
          overlay_visible_panels = isTRUE(input$overlay_visible_panels),
          rows = 0
        )
      )
      return(result)
    }

    build_overlay_series <- function(metric, country_code, commodity_code, panel_label, vp_commodity_name_code = NULL) {
      df_panel <- filtered_data_for_country(
        country_code,
        commodity_code,
        consumer = "comparison_overlay_plot",
        vp_commodity_name_code = vp_commodity_name_code
      )
      if (nrow(df_panel) == 0) return(NULL)

      metric_label <- get_metric_label_for_context(metric)
      metric_code_active <- trimws(as.character(metric %||% ""))
      metric_unit_label <- get_metric_measurement_label(
        metric_code = metric,
        source_choice = source_choice,
        unit_choice = input$unit_choice,
        basis_choice = input$basis_choice,
        value_unit_choice = current_census_value_unit_choice_safe(),
        commodity_name = commodity_code,
        active_tab = input$main_tabs_panel
      )

      if (identical(source_choice, "vp_trade") && metric_code_active %in% c("unit_value", "ytd_unit_value")) {
        overlay_unit_context <- build_unit_resolution_context(
          tab_id = input$main_tabs_panel %||% current_main_tab_safe(),
          output_id = "comparison_overlay_plot",
          source_choice = source_choice,
          metric_code = metric_code_active,
          trade_flow = input$vp_trade_flow_choice %||% "export",
          hierarchy_path = paste(
            input$vp_group_choice %||% "",
            input$vp_subgroup_choice %||% "",
            input$vp_market_segment_choice %||% "",
            vp_commodity_name_code %||% input$vp_commodity_name_choice %||% "",
            commodity_code %||% "",
            sep = "|"
          ),
          country_scope = country_code %||% "",
          market_scope = input$market_year_choice %||% "",
          rollup_level = input$vp_market_segment_choice %||% "",
          rollup_path = paste(
            input$vp_group_choice %||% "",
            input$vp_subgroup_choice %||% "",
            input$vp_market_segment_choice %||% "",
            sep = "|"
          ),
          run_id = "comparison_overlay_plot_unit_resolution"
        )

        overlay_unit_resolution <- tryCatch(
          resolve_vp_trade_display_unit(
            metric_code = metric_code_active,
            rows = df_panel,
            context = overlay_unit_context
          ),
          error = function(...) NULL
        )

        if (is.list(overlay_unit_resolution)) {
          unit_guardrail_record_event(
            unit_resolution = overlay_unit_resolution,
            context = overlay_unit_context
          )
          if (!is.null(overlay_unit_resolution$label) && nzchar(overlay_unit_resolution$label)) {
            metric_unit_label <- overlay_unit_resolution$label
          }
        }
      }

      series_base <- df_panel %>%
        filter(market_year == recent$year)

      if (identical(effective_frequency, "weekly") && "week_ending_date" %in% names(series_base)) {
        series <- series_base %>%
          select(analysis_month, week_ending_date, plot_value = all_of(metric))
      } else {
        series <- series_base %>%
          select(analysis_month, plot_value = all_of(metric)) %>%
          mutate(week_ending_date = as.Date(NA))
      }

      series <- series %>%
        left_join(display_month_mapping %>% select(analysis_month, month_abbrev), by = "analysis_month") %>%
        filter(!is.na(plot_value)) %>%
        arrange(analysis_month)

      if (nrow(series) == 0) return(NULL)

      series %>%
        mutate(
          trace_name = paste0(
            panel_label,
            ": ",
            metric_label,
            " | ",
            get_display_country(country_code),
            " | ",
            commodity_code,
            if (!is.null(vp_commodity_name_code) && nzchar(as.character(vp_commodity_name_code))) paste0(" | ", as.character(vp_commodity_name_code)) else ""
          ),
          metric_label = metric_label,
          hover_period_text = if (identical(effective_frequency, "weekly")) {
            ifelse(
              !is.na(week_ending_date),
              paste0("Week ", analysis_month, "<br>Week ending: ", format(week_ending_date, "%m/%d/%Y")),
              paste0("Week ", analysis_month)
            )
          } else {
            ifelse(
              !is.na(month_abbrev) & nzchar(month_abbrev),
              paste0("Month: ", month_abbrev),
              paste0("Period ", analysis_month)
            )
          },
          hover_value_text = if (!is.null(metric_unit_label) && nzchar(metric_unit_label)) {
            paste0("Value (", metric_unit_label, "): ", round(plot_value, 2))
          } else {
            paste0("Value: ", round(plot_value, 2))
          },
          hover_text = paste0(hover_period_text, "<br>", hover_value_text)
        )
    }

    panel_defs <- list(
      list(
        metric = main_metric,
        country = input$country_choice,
        commodity = input$commodity_choice,
        vp_commodity_name = input$vp_commodity_name_choice %||% NULL,
        label = "Top-left"
      )
    )

    if (!show_grid) {
      panel_defs <- c(panel_defs, list(
        list(
          metric = right_metric,
          country = if (!is.null(input$country_right_2up)) input$country_right_2up else "GRAND_TOTAL",
          commodity = if (!is.null(input$commodity_right_2up)) input$commodity_right_2up else default_commodity_choice_value(),
          vp_commodity_name = input$vp_commodity_name_right_2up %||% input$vp_commodity_name_choice,
          label = "Right"
        )
      ))
    } else {
      panel_defs <- c(panel_defs, list(
        list(
          metric = right_metric,
          country = if (!is.null(input$country_right_2up)) input$country_right_2up else "GRAND_TOTAL",
          commodity = if (!is.null(input$commodity_right_2up)) input$commodity_right_2up else default_commodity_choice_value(),
          vp_commodity_name = input$vp_commodity_name_right_2up %||% input$vp_commodity_name_choice,
          label = "Top-right"
        ),
        list(
          metric = grid3_metric,
          country = if (!is.null(input$country_grid_3)) input$country_grid_3 else "GRAND_TOTAL",
          commodity = if (!is.null(input$commodity_grid_3)) input$commodity_grid_3 else default_commodity_choice_value(),
          vp_commodity_name = input$vp_commodity_name_grid_3 %||% input$vp_commodity_name_choice,
          label = "Bottom-left"
        ),
        list(
          metric = grid4_metric,
          country = if (!is.null(input$country_grid_4)) input$country_grid_4 else "GRAND_TOTAL",
          commodity = if (!is.null(input$commodity_grid_4)) input$commodity_grid_4 else default_commodity_choice_value(),
          vp_commodity_name = input$vp_commodity_name_grid_4 %||% input$vp_commodity_name_choice,
          label = "Bottom-right"
        )
      ))
    }

    overlay_parts <- lapply(panel_defs, function(pdef) {
      build_overlay_series(
        pdef$metric,
        pdef$country,
        pdef$commodity,
        pdef$label,
        vp_commodity_name_code = if (identical(source_choice, "vp_trade")) pdef$vp_commodity_name else NULL
      )
    })
    overlay_parts <- overlay_parts[!vapply(overlay_parts, is.null, logical(1))]

    if (length(overlay_parts) == 0) {
      result <- plotly_empty_state(plot_title = "No current-year data available for overlay")
      log_perf(
        "comparison_overlay_plot",
        start_time,
        details = list(
          source = input$data_source_choice,
          show_metric_grid = isTRUE(input$show_metric_grid),
          overlay_visible_panels = isTRUE(input$overlay_visible_panels),
          rows = 0
        )
      )
      return(result)
    }

    overlay_df <- bind_rows(overlay_parts)

    p <- plot_ly()
    trace_names <- unique(overlay_df$trace_name)
    for (tn in trace_names) {
      df_tn <- overlay_df %>% filter(trace_name == tn)
      p <- p %>% add_trace(
        data = df_tn,
        x = ~analysis_month,
        y = ~plot_value,
        text = ~hover_text,
        type = "scatter",
        mode = "lines+markers",
        name = tn,
        hovertemplate = paste0("<b>", tn, "</b><br>%{text}<extra></extra>")
      )
    }

    max_period <- suppressWarnings(max(overlay_df$analysis_month, na.rm = TRUE))
    if (!is.finite(max_period)) max_period <- 1

    x_axis_config <- if (identical(effective_frequency, "monthly")) {
      list(
        title = display_month_axis_title,
        tickvals = 1:12,
        ticktext = display_month_mapping$month_abbrev
      )
    } else {
      build_weekly_x_axis_config_from_dates(
        label_source_df = overlay_df,
        axis_title = "Week Number",
        month_label_style = "abbrev",
        include_latest_label = TRUE,
        fallback_max_week = max_period,
        year_type = current_display_year_type(
          source_choice = source_choice
        )
      )
    }

    result <- p %>%
      layout(
        title = paste0(
          "Country Comparison Overlay (Current ",
          sub(" $", "", build_display_year_short_prefix(source_choice = source_choice)),
          " only) - ",
          get_commodity_display_label(input$commodity_choice, input$basis_choice)
        ),
        margin = list(t = 50, r = 20, b = 75, l = 70),
        xaxis = modifyList(x_axis_config, list(automargin = TRUE)),
        yaxis = list(
          title = paste0("Value (", get_metric_measurement_label(
            metric_code = effective_main_metric(),
            source_choice = source_choice,
            unit_choice = input$unit_choice,
            basis_choice = input$basis_choice,
            value_unit_choice = current_census_value_unit_choice_safe(),
            commodity_name = input$commodity_choice,
            active_tab = input$main_tabs_panel
          ), ")"),
          rangemode = "tozero",
          automargin = TRUE
        ),
        hovermode = "x unified",
        showlegend = TRUE
      )
    log_perf(
      "comparison_overlay_plot",
      start_time,
      details = list(
        source = source_choice,
        show_metric_grid = isTRUE(input$show_metric_grid),
        overlay_visible_panels = isTRUE(input$overlay_visible_panels),
        rows = nrow(overlay_df)
      )
    )
    result
  })
  
  comparison_plot_base_cache_key <- function() {
    source_choice <- current_source_choice_safe(default = input$data_source_choice %||% "export_sales")
    resolved_vp <- if (identical(source_choice, "vp_trade")) {
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

    list(
      data_source_choice = input$data_source_choice,
      census_trade_flow_choice = input$census_trade_flow_choice,
      hybrid_trade_flow_choice = input$hybrid_trade_flow_choice,
      vp_trade_flow_choice = input$vp_trade_flow_choice,
      vp_group_choice = input$vp_group_choice,
      vp_subgroup_choice = input$vp_subgroup_choice,
      vp_market_segment_choice = input$vp_market_segment_choice,
      vp_resolution_mode = resolved_vp$resolution_mode %||% "n/a",
      vp_resolved_group_filter = resolved_vp$cache_group_filter %||% "n/a",
      vp_resolved_subgroup_filter = resolved_vp$cache_subgroup_filter %||% "n/a",
      vp_resolved_market_segment_filter = resolved_vp$cache_market_segment_filter %||% "n/a",
      vp_resolved_path = resolved_vp$path_name %||% "n/a",
      vp_commodity_name_choice = input$vp_commodity_name_choice,
      vp_commodity_name_right_2up = input$vp_commodity_name_right_2up %||% "__none__",
      vp_commodity_name_grid_3 = input$vp_commodity_name_grid_3 %||% "__none__",
      vp_commodity_name_grid_4 = input$vp_commodity_name_grid_4 %||% "__none__",
      vp_commodity_detail_choice = input$commodity_choice,
      hybrid_mode_choice = if (!is.null(input$hybrid_mode_choice)) input$hybrid_mode_choice else "standard",
      cache_data_version = cache_data_version,
      cache_schema_version = cache_schema_version,
      commodity_choice = input$commodity_choice,
      country_choice = input$country_choice,
      metric = effective_main_metric(),
      main_tabs_panel = input$main_tabs_panel,
      display_year_type = current_display_year_type(
        source_choice = current_source_choice_safe(default = input$data_source_choice %||% "export_sales")
      ),
      data_frequency = input$data_frequency,
      comparison_hist_years = comparison_hist_years_committed(),
      unit_choice = input$unit_choice,
      basis_choice = input$basis_choice,
      census_value_unit_choice = if (input$data_source_choice %in% c("census", "nass")) {
        current_census_value_unit_choice_safe(source_choice = input$data_source_choice, metric_code = effective_main_metric())
      } else {
        "n/a"
      },
      wasde_price_lock = if (identical(input$data_source_choice, "wasde")) current_wasde_price_lock_input_safe() else "n/a",
      wasde_yield_lock = if (identical(input$data_source_choice, "wasde")) current_wasde_yield_lock_input_safe() else "n/a",
      nass_price_lock = if (identical(input$data_source_choice, "nass")) current_nass_price_lock_input_safe() else "n/a",
      nass_yield_lock = if (identical(input$data_source_choice, "nass")) current_nass_yield_lock_input_safe() else "n/a",
      custom_types = custom_types_cache_key(),
      custom_countries = custom_country_cache_key()
    )
  }

  comparison_plot_extension_cache_key <- function() {
    list(
      show_projections = input$show_projections,
      show_total_projection = input$show_total_projection,
      show_sum_projection = input$show_sum_projection,
      show_linear_projection = input$show_linear_projection,
      show_linear_projection_country = input$show_linear_projection_country,
      projection_basis_mode = input$projection_basis_mode,
      projection_reference_year = input$projection_reference_year,
      show_hist_avg = input$show_hist_avg,
      show_sd_bands = input$show_sd_bands,
      show_ytd_unit_value_overlay = input$show_ytd_unit_value_overlay,
      comparison_reference_week_shift = normalize_comparison_reference_week_shift(comparison_reference_week_shift())
    )
  }

  comparison_plot_cache_mode_details <- function() {
    env_value <- trimws(Sys.getenv("VP_PERF_COMPARISON_PLOT_CACHE_OFF", unset = ""))
    option_value <- getOption("vp_perf_comparison_plot_cache_off", default = NULL)

    if (nzchar(env_value)) {
      cache_off <- isTRUE(perf_truthy(env_value, default = FALSE))
      return(list(
        comparison_plot_cache_off = cache_off,
        comparison_plot_cache_mode = if (cache_off) "final_output_cache_off" else "final_output_cache_on",
        comparison_plot_cache_mode_source = "env:VP_PERF_COMPARISON_PLOT_CACHE_OFF",
        final_output_bindcache_enabled = !cache_off
      ))
    }

    if (!is.null(option_value)) {
      cache_off <- isTRUE(perf_truthy(option_value, default = FALSE))
      return(list(
        comparison_plot_cache_off = cache_off,
        comparison_plot_cache_mode = if (cache_off) "final_output_cache_off" else "final_output_cache_on",
        comparison_plot_cache_mode_source = "option:vp_perf_comparison_plot_cache_off",
        final_output_bindcache_enabled = !cache_off
      ))
    }

    list(
      comparison_plot_cache_off = FALSE,
      comparison_plot_cache_mode = "final_output_cache_on",
      comparison_plot_cache_mode_source = "default_cache_on",
      final_output_bindcache_enabled = TRUE
    )
  }

  comparison_plot_cache_off_enabled <- function() {
    isTRUE(comparison_plot_cache_mode_details()$comparison_plot_cache_off)
  }

  comparison_cache_marker_seen <- reactiveVal(new.env(parent = emptyenv()))
  comparison_flush_marker_seen <- reactiveVal(new.env(parent = emptyenv()))
  comparison_cache_flush_marker_seen <- reactiveVal(new.env(parent = emptyenv()))
  comparison_cache_tab_visit_epoch <- reactiveVal(0L)
  comparison_cache_last_tab <- reactiveVal(NA_character_)

  comparison_probe_action_context <- function(target_output_id = "comparison_plot", active_tab = NULL) {
    unavailable <- function(reason) {
      list(
        exact_action_context_status = "unavailable",
        exact_action_context_source = "single_action_probe",
        exact_action_context_evidence_class = "none",
        exact_action_context_missing_reason = reason
      )
    }

    if (!isTRUE(perf_boundary_markers_enabled())) return(unavailable("markers_disabled"))

    payload <- input$vp_perf_probe_action_context %||% NULL
    if (is.null(payload) || !is.list(payload)) return(unavailable("probe_context_missing"))

    probe_action_id <- trimws(as.character(payload$action_id %||% ""))
    probe_output_id <- trimws(as.character(payload$target_output_id %||% ""))
    probe_tab <- trimws(as.character(payload$target_tab %||% ""))
    current_tab <- trimws(as.character(active_tab %||% current_main_tab_safe() %||% ""))

    if (!nzchar(probe_action_id)) return(unavailable("probe_action_id_missing"))
    if (nzchar(target_output_id) && nzchar(probe_output_id) && !identical(probe_output_id, target_output_id)) {
      return(unavailable("probe_target_output_mismatch"))
    }
    if (nzchar(current_tab) && nzchar(probe_tab) && !identical(probe_tab, current_tab)) {
      return(unavailable("probe_target_tab_mismatch"))
    }

    list(
      action_id = probe_action_id,
      request_action_id = probe_action_id,
      mutation_seq = NA_character_,
      request_mutation_seq = NA_character_,
      exact_action_context_status = "available",
      exact_action_context_source = as.character(payload$context_source %||% "single_action_probe"),
      exact_action_context_evidence_class = as.character(payload$evidence_class %||% "exact_probe_action_context"),
      exact_action_context_missing_reason = NA_character_,
      exact_action_context_target_id = as.character(payload$target_id %||% NA_character_),
      exact_action_context_target_value = as.character(payload$target_value %||% NA_character_),
      exact_action_context_target_output_id = probe_output_id,
      exact_action_context_target_tab = probe_tab
    )
  }

  observeEvent(input$main_tabs_panel, {
    active_tab <- trimws(as.character(input$main_tabs_panel %||% ""))
    if (!nzchar(active_tab)) return(invisible(NULL))

    last_tab <- trimws(as.character(comparison_cache_last_tab() %||% ""))
    if (!identical(active_tab, last_tab)) {
      next_epoch <- suppressWarnings(as.integer(comparison_cache_tab_visit_epoch()))
      if (!is.finite(next_epoch) || is.na(next_epoch)) next_epoch <- 0L
      comparison_cache_tab_visit_epoch(next_epoch + 1L)
      comparison_cache_last_tab(active_tab)
      comparison_flush_marker_seen(new.env(parent = emptyenv()))
      comparison_cache_flush_marker_seen(new.env(parent = emptyenv()))
    }

    invisible(NULL)
  }, ignoreInit = FALSE)

  emit_comparison_server_output_anchor <- function(tag, details = list()) {
    if (!isTRUE(perf_boundary_markers_enabled())) return(invisible(FALSE))
    if (!exists("runtime_perf_record", mode = "function")) return(invisible(FALSE))

    runtime_perf_record(
      event = "server_output_anchor",
      session = session,
      details = c(
        source_switch_epoch_fields(include_age = TRUE),
        list(
          tag = as.character(tag),
          boundary = sub("^boundary_", "", as.character(tag %||% "")),
          target_output_id = "comparison_plot",
          output_owner = "comparison_plot",
          output_anchor_source = "comparison_plot_non_render_observable",
          output_anchor_clock = "server_elapsed_ms"
        ),
        comparison_plot_cache_mode_details(),
        details %||% list()
      )
    )

    invisible(TRUE)
  }

  register_comparison_cache_flush_observed_marker <- function(marker_key, output_outcome, extra_details = list()) {
    if (!isTRUE(perf_boundary_markers_enabled())) return(invisible(FALSE))

    marker_state <- comparison_cache_flush_marker_seen()
    if (!is.environment(marker_state)) {
      marker_state <- new.env(parent = emptyenv())
      comparison_cache_flush_marker_seen(marker_state)
    }

    marker_key <- as.character(marker_key %||% "")
    if (!nzchar(marker_key)) return(invisible(FALSE))
    dedupe_key <- paste("cache_flush", marker_key, sep = "|")
    if (isTRUE(marker_state[[dedupe_key]])) return(invisible(FALSE))
    marker_state[[dedupe_key]] <- TRUE

    marker_keys <- ls(marker_state, all.names = TRUE)
    if (length(marker_keys) > 512L) {
      marker_state <- new.env(parent = emptyenv())
      marker_state[[dedupe_key]] <- TRUE
      comparison_cache_flush_marker_seen(marker_state)
    }

    active_tab <- trimws(as.character(input$main_tabs_panel %||% ""))
    if (!nzchar(active_tab)) active_tab <- NULL
    source_value <- trimws(as.character(input$data_source_choice %||% ""))
    if (!nzchar(source_value)) source_value <- NULL
    tab_action_reason <- if (!is.null(active_tab)) paste0("tab_click:", active_tab) else NULL
    action_context <- comparison_probe_action_context(active_tab = active_tab)
    cache_mode_details <- comparison_plot_cache_mode_details()

    payload <- c(
      list(
        tab = active_tab,
        source = source_value,
        action_reason = tab_action_reason,
        request_action_reason = tab_action_reason,
        surface = "comparison_plot_non_render_delivery",
        phase = "post_cache_key_flush_cycle_observed",
        output_outcome = output_outcome,
        observability_class = "post_cache_key_flush_cycle_observed",
        flush_scope = "session_flush_cycle",
        clock_basis = "server_epoch_inferred",
        fires_when = "post_cache_key_flush_cycle",
        guard_name = "comparison_plot_cache_key_observer_onflushed",
        reason_code = "flush_after_cache_key_marker",
        cache_flush_registration_key = dedupe_key
      ),
      action_context,
      cache_mode_details,
      extra_details %||% list()
    )

    session$onFlushed(function() {
      emit_comparison_server_output_anchor(
        "boundary_comparison_post_cache_key_flush_observed",
        payload
      )
    }, once = TRUE)

    invisible(TRUE)
  }

  emit_comparison_cache_key_marker <- function(tag, details = list(), dedupe_key = NULL) {
    if (!isTRUE(perf_boundary_markers_enabled())) return(invisible(FALSE))

    marker_state <- comparison_cache_marker_seen()
    if (!is.environment(marker_state)) {
      marker_state <- new.env(parent = emptyenv())
      comparison_cache_marker_seen(marker_state)
    }

    if (is.null(dedupe_key)) {
      dedupe_key <- paste(
        as.character(input$main_tabs_panel %||% ""),
        as.character(input$data_source_choice %||% ""),
        as.character(tag %||% ""),
        sep = "|"
      )
    }

    dedupe_key <- as.character(dedupe_key %||% "")
    if (!nzchar(dedupe_key)) return(invisible(FALSE))
    if (isTRUE(marker_state[[dedupe_key]])) return(invisible(FALSE))
    marker_state[[dedupe_key]] <- TRUE

    active_tab <- as.character(input$main_tabs_panel %||% "")
    active_tab <- active_tab[!is.na(active_tab) & nzchar(trimws(active_tab))]
    active_tab <- if (length(active_tab) > 0L) trimws(active_tab[[1L]]) else NULL
    tab_action_reason <- if (!is.null(active_tab)) paste0("tab_click:", active_tab) else NULL
    action_context <- comparison_probe_action_context(active_tab = active_tab)

    payload <- c(
      list(
        target_output_id = "comparison_plot",
        output_owner = "comparison_plot",
        surface = "comparison_cache_key",
        phase = "cache_key_eval",
        tab = active_tab,
        source = input$data_source_choice %||% NULL,
        action_reason = tab_action_reason,
        cache_key_eval_action_reason = tab_action_reason,
        clock_basis = "server_epoch_inferred",
        fires_when = "cache_key_eval",
        output_outcome = "cache_key_evaluated",
        guard_name = "comparison_plot_bindcache_key",
        reason_code = "deduped_cache_key_eval",
        cache_key_cache_hit_truth = "not_observed"
      ),
      action_context,
      details %||% list()
    )

    if (exists("log_client_perf", mode = "function")) {
      log_client_perf(tag, payload)
    } else if (exists("runtime_perf_record", mode = "function")) {
      runtime_perf_record(
        event = "client_perf",
        session = session,
        details = c(
          list(tag = as.character(tag)),
          source_switch_epoch_fields(include_age = TRUE),
          payload
        )
      )
    }

    invisible(TRUE)
  }

  observeEvent(
    list(
      input$main_tabs_panel,
      input$data_source_choice,
      input$census_trade_flow_choice,
      input$hybrid_trade_flow_choice,
      input$vp_trade_flow_choice,
      input$vp_group_choice,
      input$vp_subgroup_choice,
      input$vp_market_segment_choice,
      input$vp_commodity_name_choice,
      input$commodity_choice,
      input$country_choice,
      input$metric_choice,
      input$data_frequency,
      input$show_projections,
      input$show_total_projection,
      input$show_sum_projection,
      input$show_linear_projection,
      input$show_linear_projection_country,
      input$projection_basis_mode,
      input$projection_reference_year,
      input$show_hist_avg,
      input$show_sd_bands,
      input$show_ytd_unit_value_overlay,
      comparison_reference_week_shift(),
      comparison_hist_years_committed()
    ),
    {
      if (!isTRUE(perf_boundary_markers_enabled())) {
        return(invisible(NULL))
      }

      source_choice <- input$data_source_choice %||% NULL
      if (is.null(source_choice) || length(source_choice) == 0L) {
        return(invisible(NULL))
      }
      source_choice <- trimws(as.character(source_choice[[1L]] %||% ""))
      if (!nzchar(source_choice)) {
        return(invisible(NULL))
      }

      base_key <- comparison_plot_base_cache_key()
      ext_key <- comparison_plot_extension_cache_key()
      cache_mode_details <- comparison_plot_cache_mode_details()
      cache_key_marker_semantics <- if (isTRUE(cache_mode_details$final_output_bindcache_enabled)) {
        "comparison_bindcache_key"
      } else {
        "key_state_only_when_final_cache_off"
      }
      active_outcome <- if (is_current_vs_average_output_active()) "active" else "inactive_gate_skip"
      active_tab_safe <- trimws(as.character(current_main_tab_safe() %||% ""))
      active_raw_tab <- trimws(as.character(input$main_tabs_panel %||% ""))
      active_reason <- if (identical(active_outcome, "active")) {
        "active"
      } else if (nzchar(active_tab_safe) || nzchar(active_raw_tab)) {
        "inactive_tab_mismatch"
      } else {
        "unknown_state"
      }
      dependency_snapshot_status <- "cache_key_snapshot_available"
      dependency_snapshot_reason <- "cache_key_observer_snapshot"

      marker_key <- paste(
        as.character(input$main_tabs_panel %||% ""),
        as.character(comparison_cache_tab_visit_epoch() %||% 0L),
        as.character(input$data_source_choice %||% ""),
        as.character(base_key$vp_resolved_path %||% "n/a"),
        as.character(base_key$commodity_choice %||% "n/a"),
        as.character(base_key$country_choice %||% "n/a"),
        as.character(base_key$metric %||% "n/a"),
        as.character(base_key$data_frequency %||% "n/a"),
        as.character(ext_key$projection_basis_mode %||% "n/a"),
        as.character(ext_key$projection_reference_year %||% "n/a"),
        as.character(ext_key$comparison_reference_week_shift %||% "n/a"),
        as.character(ext_key$show_projections %||% FALSE),
        as.character(ext_key$show_total_projection %||% FALSE),
        as.character(ext_key$show_sum_projection %||% FALSE),
        as.character(ext_key$show_linear_projection %||% FALSE),
        as.character(ext_key$show_linear_projection_country %||% FALSE),
        as.character(ext_key$show_hist_avg %||% FALSE),
        as.character(ext_key$show_sd_bands %||% FALSE),
        as.character(ext_key$show_ytd_unit_value_overlay %||% FALSE),
        sep = "|"
      )

      emit_comparison_cache_key_marker(
        tag = "boundary_comparison_cache_key_evaluated",
        dedupe_key = marker_key,
        details = list(
          active_gate_outcome = active_outcome,
          active_gate_result = active_outcome,
          active_gate_reason = active_reason,
          active_gate_tab_safe = active_tab_safe,
          active_gate_raw_tab = active_raw_tab,
          active_gate_clock_basis = "server_epoch_inferred",
          active_gate_evidence_class = "medium_action_window",
          comparison_plot_cache_off = isTRUE(cache_mode_details$comparison_plot_cache_off),
          comparison_plot_cache_mode = as.character(cache_mode_details$comparison_plot_cache_mode %||% "final_output_cache_on"),
          comparison_plot_cache_mode_source = as.character(cache_mode_details$comparison_plot_cache_mode_source %||% "unknown"),
          final_output_bindcache_enabled = isTRUE(cache_mode_details$final_output_bindcache_enabled),
          cache_key_marker_semantics = cache_key_marker_semantics,
          cache_key_cache_hit_truth = "not_observed",
          dependency_snapshot_status = dependency_snapshot_status,
          dependency_snapshot_reason = dependency_snapshot_reason,
          dependency_snapshot_clock_basis = "server_epoch_inferred",
          dependency_snapshot_evidence_class = "order_only",
          display_year_type = as.character(base_key$display_year_type %||% "n/a"),
          cache_key_source = as.character(base_key$data_source_choice %||% "n/a"),
          cache_key_metric = as.character(base_key$metric %||% "n/a"),
          cache_key_country = as.character(base_key$country_choice %||% "n/a"),
          cache_key_commodity = as.character(base_key$commodity_choice %||% "n/a"),
          cache_key_frequency = as.character(base_key$data_frequency %||% "n/a"),
          cache_key_hist_years = as.character(base_key$comparison_hist_years %||% "n/a"),
          cache_key_projection_basis_mode = as.character(ext_key$projection_basis_mode %||% "n/a"),
          cache_key_projection_reference_year = as.character(ext_key$projection_reference_year %||% "n/a"),
          cache_key_reference_week_shift = as.character(ext_key$comparison_reference_week_shift %||% "n/a"),
          cache_key_show_projections = isTRUE(ext_key$show_projections),
          cache_key_show_total_projection = isTRUE(ext_key$show_total_projection),
          cache_key_show_sum_projection = isTRUE(ext_key$show_sum_projection),
          cache_key_show_linear_projection = isTRUE(ext_key$show_linear_projection),
          cache_key_show_linear_projection_country = isTRUE(ext_key$show_linear_projection_country),
          cache_key_show_hist_avg = isTRUE(ext_key$show_hist_avg),
          cache_key_show_sd_bands = isTRUE(ext_key$show_sd_bands),
          cache_key_show_ytd_unit_value_overlay = isTRUE(ext_key$show_ytd_unit_value_overlay)
        )
      )

      register_comparison_cache_flush_observed_marker(
        marker_key = marker_key,
        output_outcome = active_outcome,
        extra_details = list(
          active_gate_outcome = active_outcome,
          active_gate_result = active_outcome,
          active_gate_reason = active_reason,
          active_gate_tab_safe = active_tab_safe,
          active_gate_raw_tab = active_raw_tab,
          active_gate_clock_basis = "server_epoch_inferred",
          active_gate_evidence_class = "medium_action_window",
          comparison_plot_cache_off = isTRUE(cache_mode_details$comparison_plot_cache_off),
          comparison_plot_cache_mode = as.character(cache_mode_details$comparison_plot_cache_mode %||% "final_output_cache_on"),
          comparison_plot_cache_mode_source = as.character(cache_mode_details$comparison_plot_cache_mode_source %||% "unknown"),
          final_output_bindcache_enabled = isTRUE(cache_mode_details$final_output_bindcache_enabled),
          cache_key_marker_semantics = cache_key_marker_semantics,
          cache_key_cache_hit_truth = "not_observed",
          dependency_snapshot_status = dependency_snapshot_status,
          dependency_snapshot_reason = dependency_snapshot_reason,
          dependency_snapshot_clock_basis = "server_epoch_inferred",
          dependency_snapshot_evidence_class = "order_only",
          display_year_type = as.character(base_key$display_year_type %||% "n/a"),
          cache_key_source = as.character(base_key$data_source_choice %||% "n/a"),
          cache_key_metric = as.character(base_key$metric %||% "n/a"),
          cache_key_country = as.character(base_key$country_choice %||% "n/a"),
          cache_key_commodity = as.character(base_key$commodity_choice %||% "n/a"),
          cache_key_frequency = as.character(base_key$data_frequency %||% "n/a")
        )
      )
    },
    ignoreInit = TRUE
  )

  build_vp_ytd_unit_value_overlay <- function(display_month_mapping, hist_avg) {
    if (!identical(current_source_choice_safe(default = input$data_source_choice %||% "export_sales"), "vp_trade")) return(NULL)
    if (!identical(comparison_effective_frequency(), "monthly")) return(NULL)
    if (!identical(effective_main_metric(), "unit_value")) return(NULL)
    if (!isTRUE(input$show_ytd_unit_value_overlay)) return(NULL)

    df <- filtered_data()
    if (!is.data.frame(df) || nrow(df) == 0 || !("ytd_unit_value" %in% names(df))) return(NULL)

    ytd_unit_label <- get_metric_measurement_label(
      metric_code = "ytd_unit_value",
      source_choice = "vp_trade",
      unit_choice = input$unit_choice,
      basis_choice = input$basis_choice,
      value_unit_choice = current_census_value_unit_choice_safe(),
      commodity_name = input$commodity_choice,
      active_tab = input$main_tabs_panel
    )

    ytd_overlay_unit_context <- build_unit_resolution_context(
      tab_id = input$main_tabs_panel %||% current_main_tab_safe(),
      output_id = "comparison_plot_ytd_overlay",
      source_choice = "vp_trade",
      metric_code = "ytd_unit_value",
      trade_flow = input$vp_trade_flow_choice %||% "export",
      hierarchy_path = paste(
        input$vp_group_choice %||% "",
        input$vp_subgroup_choice %||% "",
        input$vp_market_segment_choice %||% "",
        input$vp_commodity_name_choice %||% "",
        input$commodity_choice %||% "",
        sep = "|"
      ),
      country_scope = input$country_choice %||% "",
      market_scope = input$market_year_choice %||% "",
      rollup_level = input$vp_market_segment_choice %||% "",
      rollup_path = paste(
        input$vp_group_choice %||% "",
        input$vp_subgroup_choice %||% "",
        input$vp_market_segment_choice %||% "",
        sep = "|"
      ),
      run_id = "comparison_plot_ytd_overlay_unit_resolution"
    )

    ytd_overlay_unit_resolution <- tryCatch(
      resolve_vp_trade_display_unit(
        metric_code = "ytd_unit_value",
        rows = df,
        context = ytd_overlay_unit_context
      ),
      error = function(...) NULL
    )

    if (is.list(ytd_overlay_unit_resolution)) {
      unit_guardrail_record_event(
        unit_resolution = ytd_overlay_unit_resolution,
        context = ytd_overlay_unit_context
      )
      if (!is.null(ytd_overlay_unit_resolution$label) && nzchar(ytd_overlay_unit_resolution$label)) {
        ytd_unit_label <- ytd_overlay_unit_resolution$label
      }
    }

    ytd_hover_prefix <- if (!is.null(ytd_unit_label) && nzchar(ytd_unit_label)) {
      paste0("YTD Unit Value (", ytd_unit_label, "): ")
    } else {
      "YTD Unit Value: "
    }

    recent <- most_recent()
    if (is.null(recent) || is.null(recent$year) || !is.finite(recent$year)) return(NULL)
    recent_year <- recent$year
    years_used <- sort(unique(suppressWarnings(as.numeric(attr(hist_avg, "years_used")))))
    years_used <- years_used[is.finite(years_used)]

    collapse_ytd_rate <- function(values) {
      values <- suppressWarnings(as.numeric(values))
      if (all(is.na(values))) NA_real_ else mean(values, na.rm = TRUE)
    }

    current_ytd <- df %>%
      filter(.data$market_year == recent_year) %>%
      group_by(.data$analysis_month) %>%
      summarise(
        ytd_unit_value = collapse_ytd_rate(.data$ytd_unit_value),
        .groups = "drop"
      ) %>%
      left_join(display_month_mapping %>% select(analysis_month, month_name), by = "analysis_month") %>%
      mutate(
        x_numeric = as.numeric(.data$analysis_month),
        hover_text = paste0("Month: ", .data$month_name, "<br>", ytd_hover_prefix, round(.data$ytd_unit_value, 2))
      ) %>%
      arrange(.data$analysis_month)

    historical_ytd <- NULL
    if (length(years_used) > 0L) {
      historical_ytd <- df %>%
        filter(.data$market_year %in% years_used) %>%
        group_by(.data$market_year, .data$analysis_month) %>%
        summarise(period_ytd_unit_value = collapse_ytd_rate(.data$ytd_unit_value), .groups = "drop") %>%
        group_by(.data$analysis_month) %>%
        summarise(
          ytd_unit_value = collapse_ytd_rate(.data$period_ytd_unit_value),
          .groups = "drop"
        ) %>%
        left_join(display_month_mapping %>% select(analysis_month, month_name), by = "analysis_month") %>%
        mutate(
          x_numeric = as.numeric(.data$analysis_month),
          hover_text = paste0("Month: ", .data$month_name, "<br>", ytd_hover_prefix, round(.data$ytd_unit_value, 2))
        ) %>%
        arrange(.data$analysis_month)
    }

    list(current = current_ytd, historical = historical_ytd)
  }

  comparison_effective_frequency <- function() {
    if (input$data_source_choice %in% c("psd", "wasde")) "monthly" else input$data_frequency
  }

  is_current_vs_average_output_active <- function() {
    identical(current_main_tab_safe(), "Current vs. Average")
  }

  is_comparison_reference_week_shift_eligible <- function(hist_avg = NULL,
                                                          effective_frequency = comparison_effective_frequency(),
                                                          effective_reference_year = comparison_effective_single_reference_year(hist_avg = hist_avg)) {
    if (!is_current_vs_average_output_active()) {
      return(FALSE)
    }

    source_choice <- current_source_choice_safe(default = input$data_source_choice %||% "export_sales")
    if (identical(source_choice, "psd")) {
      return(FALSE)
    }

    if (!identical(effective_frequency, "weekly")) {
      return(FALSE)
    }

    if (!identical(input$projection_basis_mode, "single_year") || !is.finite(effective_reference_year)) {
      return(FALSE)
    }

    metric_code <- effective_main_metric()
    cumulative_metrics <- projection_metric_choices_for_source(source_choice)
    metric_code %in% cumulative_metrics
  }

  comparison_reference_week_shift_for_context <- function(hist_avg = NULL,
                                                          effective_frequency = comparison_effective_frequency(),
                                                          effective_reference_year = comparison_effective_single_reference_year(hist_avg = hist_avg)) {
    if (!is_comparison_reference_week_shift_eligible(
      hist_avg = hist_avg,
      effective_frequency = effective_frequency,
      effective_reference_year = effective_reference_year
    )) {
      return(0L)
    }

    normalize_comparison_reference_week_shift(comparison_reference_week_shift())
  }

  build_current_vs_historical_projection_row <- function(period_column,
                                                         period_label,
                                                         current_projection,
                                                         hist_avg_value,
                                                         diff_value,
                                                         pct_diff_value,
                                                         hist_sd_value,
                                                         comparison_value_label,
                                                         summary_table_digits,
                                                         weekly_projection_endpoint_label = NULL,
                                                         show_reference_week = FALSE,
                                                         show_reference_week_ending = FALSE) {
    row_values <- list()
    row_values[[period_column]] <- period_label
    if (identical(period_column, "Week")) {
      row_values[["Week Ending"]] <- weekly_projection_endpoint_label %||% "Year-End"
      if (isTRUE(show_reference_week)) {
        row_values[["Reference Week"]] <- "Year-End Projection"
      }
      if (isTRUE(show_reference_week_ending)) {
        row_values[["Reference Week Ending"]] <- "Year-End Projection"
      }
    }
    row_values[["Current Value"]] <- round(current_projection, summary_table_digits)
    row_values[[comparison_value_label]] <- round(hist_avg_value, summary_table_digits)
    row_values[["Difference"]] <- round(diff_value, summary_table_digits)
    row_values[["% Difference"]] <- round(pct_diff_value, summary_table_digits)
    row_values[["Std Dev"]] <- round(hist_sd_value, summary_table_digits)
    data.frame(row_values, check.names = FALSE)
  }

  normalize_monthly_current_vs_average_inputs <- function(current_df,
                                                          hist_avg_df,
                                                          source_choice,
                                                          country_choice,
                                                          consumer) {
    collapse_monthly_series <- function(df, value_cols) {
      if (!is.data.frame(df) || nrow(df) == 0 || !("analysis_month" %in% names(df))) {
        return(df)
      }

      value_cols <- intersect(value_cols, names(df))
      if (length(value_cols) == 0) {
        return(df %>% distinct(.data$analysis_month, .keep_all = TRUE))
      }

      df %>%
        group_by(.data$analysis_month) %>%
        summarise(
          across(
            all_of(value_cols),
            ~ (sum(.x, na.rm = TRUE) * (NA_real_ ^ (sum(!is.na(.x)) == 0)))
          ),
          .groups = "drop"
        )
    }

    current_monthly <- current_df %>%
      select(any_of(c("analysis_month", "current_value")))
    hist_avg_monthly <- hist_avg_df %>%
      select(any_of(c("analysis_month", "avg_value", "min_value", "max_value", "sd_value")))

    current_dup_months <- current_monthly %>%
      count(.data$analysis_month, name = "n") %>%
      filter(.data$n > 1)
    hist_dup_months <- hist_avg_monthly %>%
      count(.data$analysis_month, name = "n") %>%
      filter(.data$n > 1)

    if (nrow(current_dup_months) > 0 || nrow(hist_dup_months) > 0) {
      record_cache_body_execution(
        session,
        "summary_table_monthly_duplicate_guard_triggered",
        details = list(
          source = source_choice,
          country = country_choice,
          consumer = consumer,
          current_duplicate_months = nrow(current_dup_months),
          historical_duplicate_months = nrow(hist_dup_months)
        )
      )
    }

    list(
      current = collapse_monthly_series(current_monthly, c("current_value")),
      hist_avg = collapse_monthly_series(hist_avg_monthly, c("avg_value", "min_value", "max_value", "sd_value"))
    )
  }

  # Output: Comparison plot
  comparison_plot_render <- renderPlotly({
    emit_comparison_plot_boundary <- function(boundary_name, details = list()) {
      details <- details %||% list()
      if (!is.list(details)) details <- as.list(details)

      active_tab <- as.character(input$main_tabs_panel %||% "")
      active_tab <- active_tab[!is.na(active_tab) & nzchar(trimws(active_tab))]
      active_tab <- if (length(active_tab) > 0L) trimws(active_tab[[1L]]) else NULL
      tab_action_reason <- if (!is.null(active_tab)) paste0("tab_click:", active_tab) else NULL

      if (is.null(details$action_reason) && is.null(details$request_action_reason) && !is.null(tab_action_reason)) {
        details <- c(list(action_reason = tab_action_reason), details)
      }

      cache_mode_details <- comparison_plot_cache_mode_details()

      base_payload <- list(
        boundary = boundary_name,
        target_output_id = "comparison_plot",
        tab = active_tab,
        source = input$data_source_choice %||% NULL,
        comparison_plot_cache_off = isTRUE(cache_mode_details$comparison_plot_cache_off),
        comparison_plot_cache_mode = as.character(cache_mode_details$comparison_plot_cache_mode %||% "final_output_cache_on"),
        comparison_plot_cache_mode_source = as.character(cache_mode_details$comparison_plot_cache_mode_source %||% "unknown"),
        final_output_bindcache_enabled = isTRUE(cache_mode_details$final_output_bindcache_enabled)
      )

      detail_names <- names(details)
      if (!is.null(detail_names) && length(detail_names) > 0L) {
        base_payload[intersect(names(base_payload), detail_names)] <- NULL
      }
      base_payload <- c(base_payload, details)

      if (isTRUE(perf_boundary_markers_enabled()) && exists("runtime_perf_record", mode = "function")) {
        runtime_perf_record(
          event = "server_output_anchor",
          session = session,
          details = c(
            source_switch_epoch_fields(include_age = TRUE),
            list(
              tag = paste0("boundary_", boundary_name),
              output_anchor_source = "comparison_plot_server_render",
              output_anchor_clock = "server_elapsed_ms"
            ),
            base_payload
          )
        )
      }

      if (!isTRUE(perf_boundary_markers_enabled())) return(invisible(NULL))
      if (!exists("log_client_perf", mode = "function")) return(invisible(NULL))

      log_client_perf(
        paste0("boundary_", boundary_name),
        base_payload
      )
      invisible(NULL)
    }

    register_flush_cycle_observed_marker <- function(output_outcome, reason_code = "flush_cycle_observed", extra_details = list()) {
      if (!isTRUE(perf_boundary_markers_enabled())) {
        return(invisible(FALSE))
      }

      marker_state <- comparison_flush_marker_seen()
      if (!is.environment(marker_state)) {
        marker_state <- new.env(parent = emptyenv())
        comparison_flush_marker_seen(marker_state)
      }

      active_tab <- trimws(as.character(input$main_tabs_panel %||% ""))
      if (!nzchar(active_tab)) active_tab <- NULL
      source_value <- trimws(as.character(input$data_source_choice %||% ""))
      if (!nzchar(source_value)) source_value <- NULL
      visit_epoch <- suppressWarnings(as.integer(comparison_cache_tab_visit_epoch()))
      if (!is.finite(visit_epoch) || is.na(visit_epoch)) visit_epoch <- 0L

      dedupe_key <- paste(
        active_tab %||% "unknown_tab",
        source_value %||% "unknown_source",
        as.character(visit_epoch),
        as.character(output_outcome %||% "unknown_outcome"),
        sep = "|"
      )

      if (isTRUE(marker_state[[dedupe_key]])) {
        return(invisible(FALSE))
      }
      marker_state[[dedupe_key]] <- TRUE

      marker_keys <- ls(marker_state, all.names = TRUE)
      if (length(marker_keys) > 512L) {
        marker_state <- new.env(parent = emptyenv())
        marker_state[[dedupe_key]] <- TRUE
        comparison_flush_marker_seen(marker_state)
      }

      tab_action_reason <- if (!is.null(active_tab)) paste0("tab_click:", active_tab) else NULL
      cache_mode_details <- comparison_plot_cache_mode_details()
      payload <- c(
        list(
          output_owner = "comparison_plot",
          surface = "comparison_plot_observable_delivery",
          phase = "flush_cycle_observed",
          output_outcome = output_outcome,
          observability_class = "flush_cycle_observed",
          flush_scope = "session_flush_cycle",
          clock_basis = "server_elapsed_ms",
          tab = active_tab,
          source = source_value,
          action_reason = tab_action_reason,
          request_action_reason = tab_action_reason,
          fires_when = "post_flush_cycle",
          guard_name = "comparison_plot_onflushed_observer",
          reason_code = reason_code,
          flush_registration_key = dedupe_key
        ),
        cache_mode_details,
        extra_details %||% list()
      )

      session$onFlushed(function() {
        emit_comparison_plot_boundary(
          "server_output_flush_cycle_observed",
          payload
        )
      }, once = TRUE)

      invisible(TRUE)
    }

    start_time <- Sys.time()

    if (!is_current_vs_average_output_active()) {
      record_cache_body_execution(
        session,
        "comparison_plot_gated_skip",
        details = list(
          target_output_id = "comparison_plot",
          output_outcome = "active_gate_skip",
          tab = input$main_tabs_panel %||% NULL,
          source = input$data_source_choice %||% NULL
        )
      )
      emit_comparison_plot_boundary(
        "server_output_render_returned",
        list(
          output_outcome = "active_gate_skip",
          elapsed_ms = perf_elapsed_ms(start_time)
        )
      )
      register_flush_cycle_observed_marker(
        output_outcome = "active_gate_skip",
        reason_code = "flush_after_active_gate_skip"
      )
      return(NULL)
    }
    record_cache_body_execution(
      session,
      "comparison_plot_executed",
      details = list(
        target_output_id = "comparison_plot",
        output_outcome = "render_body_executed",
        tab = input$main_tabs_panel %||% NULL,
        source = input$data_source_choice %||% NULL
      )
    )

    emit_comparison_plot_boundary(
      "server_output_render_start",
      list(
        output_owner = "comparison_plot",
        surface = "comparison_plot",
        phase = "render_start",
        output_outcome = "render_started",
        elapsed_ms = perf_elapsed_ms(start_time)
      )
    )

    current <- current_year_data()
    hist_avg <- historical_avg()
    effective_frequency <- comparison_effective_frequency()
    source_choice <- current_source_choice_safe(default = input$data_source_choice %||% "export_sales")
    display_month_mapping <- current_display_month_mapping(source_choice = source_choice)
    display_month_axis_title <- current_display_month_axis_title(source_choice = source_choice, display_month_mapping = display_month_mapping)
    current_year_label <- build_current_year_trace_label(most_recent()$year, source_choice = source_choice, display_month_mapping = display_month_mapping)
    hist_window <- comparison_hist_years_committed()
    effective_reference_year <- comparison_effective_single_reference_year(hist_avg = hist_avg)
    reference_year_label <- if (identical(input$projection_basis_mode, "single_year") && is.finite(effective_reference_year)) {
      build_single_reference_year_label(effective_reference_year, source_choice = source_choice, display_month_mapping = display_month_mapping)
    } else {
      paste0("Historical Avg (", hist_window, " yrs)")
    }

    emit_comparison_plot_boundary(
      "server_output_inputs_resolved",
      list(
        output_owner = "comparison_plot",
        surface = "comparison_plot",
        phase = "inputs_resolved",
        frequency = effective_frequency,
        current_rows = if (is.data.frame(current)) nrow(current) else 0L,
        historical_rows = if (is.data.frame(hist_avg)) nrow(hist_avg) else 0L,
        elapsed_ms = perf_elapsed_ms(start_time)
      )
    )
    
    if (is.null(current) || is.null(hist_avg)) {
      record_cache_body_execution(
        session,
        "comparison_plot_empty_state_return",
        details = list(
          target_output_id = "comparison_plot",
          output_outcome = "empty_state_return",
          tab = input$main_tabs_panel %||% NULL,
          source = input$data_source_choice %||% NULL
        )
      )
      emit_comparison_plot_boundary(
        "server_output_render_returned",
        list(
          output_owner = "comparison_plot",
          surface = "comparison_plot",
          phase = "render_returned",
          output_outcome = "empty_state_return",
          elapsed_ms = perf_elapsed_ms(start_time)
        )
      )
      register_flush_cycle_observed_marker(
        output_outcome = "empty_state_return",
        reason_code = "flush_after_empty_state_return"
      )
      return(plotly_empty_state(plot_title = "Insufficient data for this selection"))
    }
    
    # Create labels based on data frequency
    if (identical(effective_frequency, "monthly")) {
      normalized_monthly <- normalize_monthly_current_vs_average_inputs(
        current_df = current,
        hist_avg_df = hist_avg,
        source_choice = source_choice,
        country_choice = input$country_choice,
        consumer = "comparison_plot"
      )
      current <- normalized_monthly$current
      hist_avg <- normalized_monthly$hist_avg

      # Monthly: use all 12 months
      all_months <- display_month_mapping %>%
        select(analysis_month, month_name)
      
      comparison <- all_months %>%
        left_join(current, by = "analysis_month") %>%
        left_join(hist_avg, by = "analysis_month") %>%
        mutate(
          reference_analysis_month = as.integer(.data$analysis_month),
          reference_week_label = NA_character_,
          reference_week_ending_date = as.Date(NA),
          reference_value = .data$avg_value,
          reference_min_value = .data$min_value,
          reference_max_value = .data$max_value,
          x_label = factor(month_name, levels = display_month_mapping$month_name),
          hover_period_text = paste0("Month: ", month_name),
          current_hover_period_text = hover_period_text,
          reference_hover_period_text = hover_period_text,
          x_numeric = as.numeric(analysis_month)
        )
    } else {
      # Weekly: create week labels and ensure proper numeric ordering
      single_reference_weekly <- identical(input$projection_basis_mode, "single_year") && is.finite(effective_reference_year)
      shift_value <- comparison_reference_week_shift_for_context(
        hist_avg = hist_avg,
        effective_frequency = effective_frequency,
        effective_reference_year = effective_reference_year
      )

      comparison <- build_current_vs_historical_weekly_shift_frame(
        current_df = current,
        hist_avg_df = hist_avg,
        reference_df = filtered_data(),
        effective_reference_year = if (single_reference_weekly) effective_reference_year else NA_real_,
        metric_col = effective_main_metric(),
        shift_value = shift_value
      ) %>%
        mutate(
          x_label = paste0("W", analysis_month),
          current_hover_period_text = comparison_week_hover_text(analysis_month, week_ending_date),
          reference_hover_period_text = if (single_reference_weekly) {
            comparison_week_hover_text(reference_analysis_month, reference_week_ending_date, include_na_date = TRUE)
          } else {
            paste0("Week ", analysis_month, "<br>Week ending: NA")
          },
          hover_period_text = current_hover_period_text,
          x_numeric = as.numeric(analysis_month)
        ) %>%
        arrange(x_numeric)
    }

    ytd_unit_value_overlay <- build_vp_ytd_unit_value_overlay(
      display_month_mapping = display_month_mapping,
      hist_avg = hist_avg
    )

    # Build base title with metric, country, and commodity for consistency across plots
    metric_code_active <- effective_main_metric()
    source_choice_active <- current_source_choice_safe(default = input$data_source_choice %||% "export_sales")
    metric_unit_label <- get_metric_measurement_label(
      metric_code = metric_code_active,
      source_choice = source_choice_active,
      unit_choice = input$unit_choice,
      basis_choice = input$basis_choice,
      value_unit_choice = current_census_value_unit_choice_safe(),
      commodity_name = input$commodity_choice,
      active_tab = input$main_tabs_panel
    )

    if (identical(source_choice_active, "vp_trade") && metric_code_active %in% c("unit_value", "ytd_unit_value")) {
      comparison_unit_context <- build_unit_resolution_context(
        tab_id = input$main_tabs_panel %||% current_main_tab_safe(),
        output_id = "comparison_plot",
        source_choice = source_choice_active,
        metric_code = metric_code_active,
        trade_flow = input$vp_trade_flow_choice %||% "export",
        hierarchy_path = paste(
          input$vp_group_choice %||% "",
          input$vp_subgroup_choice %||% "",
          input$vp_market_segment_choice %||% "",
          input$vp_commodity_name_choice %||% "",
          input$commodity_choice %||% "",
          sep = "|"
        ),
        country_scope = input$country_choice %||% "",
        market_scope = input$market_year_choice %||% "",
        rollup_level = input$vp_market_segment_choice %||% "",
        rollup_path = paste(
          input$vp_group_choice %||% "",
          input$vp_subgroup_choice %||% "",
          input$vp_market_segment_choice %||% "",
          sep = "|"
        ),
        run_id = "comparison_plot_unit_resolution"
      )

      comparison_unit_resolution <- tryCatch(
        resolve_vp_trade_display_unit(
          metric_code = metric_code_active,
          rows = current,
          context = comparison_unit_context
        ),
        error = function(...) NULL
      )

      if (is.list(comparison_unit_resolution)) {
        unit_guardrail_record_event(
          unit_resolution = comparison_unit_resolution,
          context = comparison_unit_context
        )
        if (!is.null(comparison_unit_resolution$label) && nzchar(comparison_unit_resolution$label)) {
          metric_unit_label <- comparison_unit_resolution$label
        }
      }
    }

    value_hover_prefix <- if (!is.null(metric_unit_label) && nzchar(metric_unit_label)) {
      paste0("Value (", metric_unit_label, "): ")
    } else {
      "Value: "
    }

    base_title <- paste(
      get_metric_label_for_context(effective_main_metric()),
      if (identical(input$data_source_choice, "census") && identical(input$country_choice, "GRAND_TOTAL")) "World" else get_display_country(input$country_choice),
      get_commodity_display_label(input$commodity_choice, input$basis_choice),
      sep = " - "
    )

    # Create plot
    p <- plot_ly(comparison) %>%
      add_trace(
        x = ~x_numeric,
        y = ~current_value,
        text = ~current_hover_period_text,
        type = "scatter",
        mode = "lines+markers",
        name = current_year_label,
        line = list(color = "#d62728", width = 3),
        marker = list(size = 8),
        hovertemplate = paste0("<b>", current_year_label, "</b><br>%{text}<br>", value_hover_prefix, "%{y:.2f}<extra></extra>")
      ) %>%
      add_trace(
        x = ~x_numeric,
        y = ~reference_value,
        text = ~reference_hover_period_text,
        type = "scatter",
        mode = "lines+markers",
        name = reference_year_label,
        line = list(color = "#1f77b4", width = 2, dash = "dash"),
        marker = list(size = 6),
        hovertemplate = paste0("<b>", reference_year_label, "</b><br>%{text}<br>", value_hover_prefix, "%{y:.2f}<extra></extra>")
      ) %>%
      add_ribbons(
        x = ~x_numeric,
        ymin = ~reference_min_value,
        ymax = ~reference_max_value,
        name = "Historical Range",
        fillcolor = "rgba(31, 119, 184, 0.1)",
        line = list(color = "rgba(31, 119, 184, 0)")
      )

    if (!is.null(ytd_unit_value_overlay) && is.data.frame(ytd_unit_value_overlay$current) && nrow(ytd_unit_value_overlay$current) > 0) {
      p <- p %>% add_trace(
        data = ytd_unit_value_overlay$current,
        x = ~x_numeric,
        y = ~ytd_unit_value,
        text = ~hover_text,
        type = "scatter",
        mode = "lines+markers",
        name = "Current YTD unit value",
        line = list(color = "#8c564b", width = 2, dash = "dot"),
        marker = list(size = 6),
        hovertemplate = "<b>Current YTD unit value</b><br>%{text}<extra></extra>"
      )
    }

    if (!is.null(ytd_unit_value_overlay) && is.data.frame(ytd_unit_value_overlay$historical) && nrow(ytd_unit_value_overlay$historical) > 0) {
      p <- p %>% add_trace(
        data = ytd_unit_value_overlay$historical,
        x = ~x_numeric,
        y = ~ytd_unit_value,
        text = ~hover_text,
        type = "scatter",
        mode = "lines+markers",
        name = "Historical avg YTD unit value",
        line = list(color = "#7f7f7f", width = 2, dash = "dot"),
        marker = list(size = 5),
        hovertemplate = "<b>Historical avg YTD unit value</b><br>%{text}<extra></extra>"
      )
    }

    proj <- NULL
    
    # Add projection line if enabled and applicable
    # For Grand Total: check individual projection toggles; for others: check show_projections
    show_any_projection <- if (input$country_choice == "GRAND_TOTAL") {
      (source_allows_historical_projection() && (isTRUE(input$show_total_projection) || isTRUE(input$show_sum_projection))) || isTRUE(input$show_linear_projection)
    } else {
      (source_allows_historical_projection() && isTRUE(input$show_projections)) || isTRUE(input$show_linear_projection_country)
    }

    # Keep a single-line title while making the displayed unit explicit.
    title_text_plot <- if (!is.null(metric_unit_label) && nzchar(metric_unit_label)) {
      paste0(base_title, " (", metric_unit_label, ")")
    } else {
      base_title
    }

    if (show_any_projection) {
      proj <- projection_data()
      if (!is.null(proj)) {
        # Determine which projections to show based on toggle settings
        show_total <- if (input$country_choice == "GRAND_TOTAL") {
          source_allows_historical_projection() && isTRUE(input$show_total_projection)
        } else {
          source_allows_historical_projection() && isTRUE(input$show_projections)
        }
        show_sum <- if (input$country_choice == "GRAND_TOTAL") {
          source_allows_historical_projection() && isTRUE(input$show_sum_projection)
        } else {
          FALSE
        }
        show_linear <- if (input$country_choice == "GRAND_TOTAL") {
          isTRUE(input$show_linear_projection)
        } else {
          isTRUE(input$show_linear_projection_country)
        }
        
        # Collect all projection values to sort and assign y-offsets
        proj_values <- list()
        if (show_total && !is.null(proj$final_projection) && !is.na(proj$final_projection)) {
          proj_values$total <- proj$final_projection
        }
        if (show_sum && !is.null(proj$country_sum_projection) && !is.na(proj$country_sum_projection)) {
          proj_values$sum <- proj$country_sum_projection
        }
        if (show_linear && !is.null(proj$linear_projection)) {
          proj_values$linear <- proj$linear_projection
        }
        
        # Sort projections by value (descending) and assign y-offsets to avoid overlap
        if (length(proj_values) > 1) {
          sorted_names <- names(sort(unlist(proj_values), decreasing = TRUE))
          y_offsets <- setNames(seq(0, -20 * (length(sorted_names) - 1), by = -20), sorted_names)
        } else {
          y_offsets <- setNames(0, names(proj_values))
        }
        
        # Show Total projection if enabled
        if (show_total && !is.null(proj$final_projection) && !is.na(proj$final_projection)) {
          # Create projection line from current period to end of year (Historical Pattern)
          proj_line_data <- data.frame(
            x = c(proj$current_period, proj$total_periods),
            y = c(proj$current_value, proj$final_projection)
          )
          
          # Determine label based on whether we have country sum projection
          proj_label <- if (!is.null(proj$country_sum_projection) && !is.na(proj$country_sum_projection)) {
            "Projection (Total)"
          } else {
            "Year-End Projection"
          }
          
          p <- p %>%
            add_trace(
              data = proj_line_data,
              x = ~x,
              y = ~y,
              type = "scatter",
              mode = "lines+markers",
              name = proj_label,
              line = list(color = "#2ca02c", width = 3, dash = "dash"),
              marker = list(size = 10, symbol = "diamond", color = "#2ca02c")
            ) %>%
            add_annotations(
              x = proj$total_periods,
              y = proj$final_projection,
              text = paste0("Hist: ", format(round(proj$final_projection, 0), big.mark = ",")),
              showarrow = FALSE,
              xanchor = "left",
              xshift = 10,
              yshift = ifelse("total" %in% names(y_offsets), y_offsets["total"], 0),
              font = list(color = "#2ca02c", size = 12)
            )
        }
        
        # Add country sum projection if available and enabled (GRAND_TOTAL only)
        if (!is.null(proj$country_sum_projection) && !is.na(proj$country_sum_projection) && show_sum) {
          proj_line_sum <- data.frame(
            x = c(proj$current_period, proj$total_periods),
            y = c(proj$current_value, proj$country_sum_projection)
          )
          
          p <- p %>%
            add_trace(
              data = proj_line_sum,
              x = ~x,
              y = ~y,
              type = "scatter",
              mode = "lines+markers",
              name = "Projection (Sum of Countries)",
              line = list(color = "#9467bd", width = 3, dash = "dot"),
              marker = list(size = 10, symbol = "square")
            ) %>%
            add_annotations(
              x = proj$total_periods,
              y = proj$country_sum_projection,
              text = paste0("Sum: ", format(round(proj$country_sum_projection, 0), big.mark = ",")),
              showarrow = FALSE,
              xanchor = "left",
              xshift = 10,
              yshift = ifelse("sum" %in% names(y_offsets), y_offsets["sum"], 0),
              font = list(color = "#9467bd", size = 12)
            )
        }
        
        # Add linear fit projection if enabled
        linear_fit_ready <-
          show_linear &&
          !is.null(proj$linear_projection) &&
          !is.null(proj$linear_fit_data) &&
          !is.null(proj$linear_fit_data$anchor_point) &&
          length(proj$linear_fit_data$anchor_point$x) == 1 &&
          length(proj$linear_fit_data$anchor_point$y) == 1 &&
          length(proj$linear_fit_data$intercept) == 1 &&
          length(proj$linear_fit_data$slope) == 1 &&
          length(proj$linear_fit_data$r_squared) == 1

        if (linear_fit_ready) {
          # Create the linear fit line from anchor point (first data point) to year-end
          fit_data <- proj$linear_fit_data
          x_vals <- c(fit_data$anchor_point$x, proj$total_periods)
          y_vals <- c(fit_data$anchor_point$y, proj$linear_projection)
          
          proj_line_linear <- data.frame(x = x_vals, y = y_vals)
          
          # Build equation string: (y = mx + b)
          if (fit_data$intercept >= 0) {
            eq_text <- sprintf("(y = %.1fx + %.0f)", fit_data$slope, fit_data$intercept)
          } else {
            eq_text <- sprintf("(y = %.1fx - %.0f)", fit_data$slope, abs(fit_data$intercept))
          }
          
          p <- p %>%
            add_trace(
              data = proj_line_linear,
              x = ~x,
              y = ~y,
              type = "scatter",
              mode = "lines",
              name = paste0("Linear Fit (R²=", round(fit_data$r_squared, 3), ")"),
              line = list(color = "#ff7f0e", width = 2, dash = "dashdot")
            ) %>%
            add_annotations(
              x = proj$total_periods,
              y = proj$linear_projection,
              text = paste0("Linear: ", format(round(proj$linear_projection, 0), big.mark = ","), "<br>", eq_text),
              showarrow = FALSE,
              xanchor = "left",
              align = "left",
              xshift = 10,
              yshift = ifelse("linear" %in% names(y_offsets), y_offsets["linear"], 0),
              font = list(color = "#ff7f0e", size = 12)
            )
        }
      }
    }
    
    # Setup x-axis labels
    if (identical(effective_frequency, "monthly")) {
      # For monthly, show month names on tick positions 1-12
      tick_positions <- 1:12
      tick_labels <- display_month_mapping$month_abbrev
      
      x_axis_config <- list(
        title = display_month_axis_title,
        tickvals = tick_positions,
        ticktext = tick_labels
      )
    } else {
      displayed_max_week <- max(comparison$analysis_month, na.rm = TRUE)
      if (!is.null(proj) && isTRUE(proj$projection_valid) && is.finite(proj$total_periods)) {
        displayed_max_week <- max(displayed_max_week, proj$total_periods, na.rm = TRUE)
      }

      x_axis_config <- build_weekly_x_axis_config_from_dates(
        label_source_df = current,
        axis_title = "Week Number",
        month_label_style = "abbrev",
        include_latest_label = TRUE,
        fallback_max_week = displayed_max_week,
        year_type = current_display_year_type(
          source_choice = current_source_choice_safe(default = input$data_source_choice %||% "export_sales")
        )
      )
    }
    
    # Get the display name for the selected metric
    metric_display_name <- paste0(
      get_metric_label_for_context(effective_main_metric()),
      " (",
      metric_unit_label,
      ")"
    )
    
    # Format country name for display
    display_country <- if (identical(input$data_source_choice, "census") && identical(input$country_choice, "GRAND_TOTAL")) {
      "World"
    } else {
      get_display_country(input$country_choice)
    }
    
    out <- p %>%
      layout(
        title = list(text = title_text_plot),
        xaxis = x_axis_config,
        yaxis = list(
          title = metric_display_name,
          rangemode = "tozero"
        ),
        hovermode = "x unified",
        showlegend = TRUE
      )

    emit_comparison_plot_boundary(
      "server_output_plot_object_built",
      list(
        output_owner = "comparison_plot",
        surface = "comparison_plot",
        phase = "plot_object_built",
        output_outcome = "normal_plot_return",
        comparison_rows = nrow(comparison),
        has_projection_data = !is.null(proj),
        elapsed_ms = perf_elapsed_ms(start_time)
      )
    )
    
    log_perf("comparison_plot", start_time)

    record_cache_body_execution(
      session,
      "comparison_plot_normal_return",
      details = list(
        target_output_id = "comparison_plot",
        output_outcome = "normal_plot_return",
        tab = input$main_tabs_panel %||% NULL,
        source = input$data_source_choice %||% NULL,
        comparison_rows = nrow(comparison)
      )
    )

    emit_comparison_plot_boundary(
      "server_output_render_returned",
      list(
        output_owner = "comparison_plot",
        surface = "comparison_plot",
        phase = "render_returned",
        output_outcome = "normal_plot_return",
        elapsed_ms = perf_elapsed_ms(start_time)
      )
    )

    register_flush_cycle_observed_marker(
      output_outcome = "normal_plot_return",
      reason_code = "flush_after_normal_plot_return"
    )

    out
  })

  if (isTRUE(comparison_plot_cache_off_enabled())) {
    output$comparison_plot <- comparison_plot_render
  } else {
    output$comparison_plot <- comparison_plot_render %>% bindCache(
      is_current_vs_average_output_active(),
      comparison_plot_base_cache_key()$data_source_choice,
      comparison_plot_base_cache_key()$census_trade_flow_choice,
      comparison_plot_base_cache_key()$hybrid_trade_flow_choice,
      comparison_plot_base_cache_key()$vp_trade_flow_choice,
      comparison_plot_base_cache_key()$vp_group_choice,
      comparison_plot_base_cache_key()$vp_subgroup_choice,
      comparison_plot_base_cache_key()$vp_market_segment_choice,
      comparison_plot_base_cache_key()$vp_resolution_mode,
      comparison_plot_base_cache_key()$vp_resolved_group_filter,
      comparison_plot_base_cache_key()$vp_resolved_subgroup_filter,
      comparison_plot_base_cache_key()$vp_resolved_market_segment_filter,
      comparison_plot_base_cache_key()$vp_resolved_path,
      comparison_plot_base_cache_key()$vp_commodity_name_choice,
      comparison_plot_base_cache_key()$vp_commodity_detail_choice,
      comparison_plot_base_cache_key()$hybrid_mode_choice,
      comparison_plot_base_cache_key()$cache_data_version,
      comparison_plot_base_cache_key()$cache_schema_version,
      comparison_plot_base_cache_key()$commodity_choice,
      comparison_plot_base_cache_key()$country_choice,
      comparison_plot_base_cache_key()$metric,
      comparison_plot_base_cache_key()$main_tabs_panel,
      comparison_plot_base_cache_key()$display_year_type,
      comparison_plot_base_cache_key()$data_frequency,
      comparison_plot_base_cache_key()$comparison_hist_years,
      comparison_plot_base_cache_key()$unit_choice,
      comparison_plot_base_cache_key()$basis_choice,
      comparison_plot_base_cache_key()$census_value_unit_choice,
      comparison_plot_base_cache_key()$wasde_price_lock,
      comparison_plot_base_cache_key()$wasde_yield_lock,
      comparison_plot_base_cache_key()$nass_price_lock,
      comparison_plot_base_cache_key()$nass_yield_lock,
      comparison_plot_extension_cache_key()$show_projections,
      comparison_plot_extension_cache_key()$show_total_projection,
      comparison_plot_extension_cache_key()$show_sum_projection,
      comparison_plot_extension_cache_key()$show_linear_projection,
      comparison_plot_extension_cache_key()$show_linear_projection_country,
      comparison_plot_extension_cache_key()$projection_basis_mode,
      comparison_plot_extension_cache_key()$projection_reference_year,
      comparison_plot_extension_cache_key()$show_hist_avg,
      comparison_plot_extension_cache_key()$show_sd_bands,
      comparison_plot_extension_cache_key()$show_ytd_unit_value_overlay,
      comparison_plot_extension_cache_key()$comparison_reference_week_shift,
      comparison_plot_base_cache_key()$custom_types,
      comparison_plot_base_cache_key()$custom_countries
    )
  }

  normalize_summary_table_value_digits <- function(value) {
    if (is.null(value) || length(value) == 0L) {
      value <- summary_table_value_digits_min
    }

    value <- suppressWarnings(as.integer(value[[1]]))
    if (is.na(value)) value <- summary_table_value_digits_min
    max(summary_table_value_digits_min, min(summary_table_value_digits_max, value))
  }

  observeEvent(input$summary_digits_decrease, {
    current_digits <- normalize_summary_table_value_digits(isolate(summary_table_value_digits()))
    summary_table_value_digits(max(summary_table_value_digits_min, current_digits - 1L))
  }, ignoreInit = TRUE)

  observeEvent(input$summary_digits_increase, {
    current_digits <- normalize_summary_table_value_digits(isolate(summary_table_value_digits()))
    summary_table_value_digits(min(summary_table_value_digits_max, current_digits + 1L))
  }, ignoreInit = TRUE)

  output$summary_digits_display <- renderText({
    paste0("Decimals: ", normalize_summary_table_value_digits(summary_table_value_digits()))
  })

  output$comparison_reference_week_shift_ui <- renderUI({
    hist_avg <- historical_avg()
    effective_frequency <- comparison_effective_frequency()
    effective_reference_year <- comparison_effective_single_reference_year(hist_avg = hist_avg)

    if (!is_comparison_reference_week_shift_eligible(
      hist_avg = hist_avg,
      effective_frequency = effective_frequency,
      effective_reference_year = effective_reference_year
    )) {
      return(NULL)
    }

    shift_value <- comparison_reference_week_shift_for_context(
      hist_avg = hist_avg,
      effective_frequency = effective_frequency,
      effective_reference_year = effective_reference_year
    )
    down_disabled <- shift_value <= comparison_reference_week_shift_min
    up_disabled <- shift_value >= comparison_reference_week_shift_max

    down_button <- actionButton(
      inputId = "comparison_reference_week_shift_decrease",
      label = NULL,
      icon = icon("minus"),
      class = "btn-default btn-sm",
      `aria-label` = "Shift reference weeks down"
    )
    if (isTRUE(down_disabled)) {
      down_button <- tagAppendAttributes(down_button, disabled = "disabled")
    }

    up_button <- actionButton(
      inputId = "comparison_reference_week_shift_increase",
      label = NULL,
      icon = icon("plus"),
      class = "btn-default btn-sm",
      `aria-label` = "Move reference weeks back up"
    )
    if (isTRUE(up_disabled)) {
      up_button <- tagAppendAttributes(up_button, disabled = "disabled")
    }

    div(
      style = "display: flex; align-items: center; gap: 6px; flex-wrap: wrap; margin-top: 8px;",
      down_button,
      up_button,
      span(
        comparison_reference_week_shift_status_text(shift_value),
        style = "font-size: 12px; color: #555; margin-left: 4px;"
      )
    )
  })

  observeEvent(input$comparison_reference_week_shift_decrease, {
    hist_avg <- isolate(historical_avg())
    effective_frequency <- isolate(comparison_effective_frequency())
    effective_reference_year <- isolate(comparison_effective_single_reference_year(hist_avg = hist_avg))

    if (!is_comparison_reference_week_shift_eligible(
      hist_avg = hist_avg,
      effective_frequency = effective_frequency,
      effective_reference_year = effective_reference_year
    )) {
      return()
    }

    current_shift <- normalize_comparison_reference_week_shift(isolate(comparison_reference_week_shift()))
    comparison_reference_week_shift(max(comparison_reference_week_shift_min, current_shift - 1L))
  }, ignoreInit = TRUE)

  observeEvent(input$comparison_reference_week_shift_increase, {
    hist_avg <- isolate(historical_avg())
    effective_frequency <- isolate(comparison_effective_frequency())
    effective_reference_year <- isolate(comparison_effective_single_reference_year(hist_avg = hist_avg))

    if (!is_comparison_reference_week_shift_eligible(
      hist_avg = hist_avg,
      effective_frequency = effective_frequency,
      effective_reference_year = effective_reference_year
    )) {
      return()
    }

    current_shift <- normalize_comparison_reference_week_shift(isolate(comparison_reference_week_shift()))
    comparison_reference_week_shift(min(comparison_reference_week_shift_max, current_shift + 1L))
  }, ignoreInit = TRUE)

  observeEvent(
    list(
      input$main_tabs_panel,
      input$data_source_choice,
      input$data_frequency,
      input$metric_choice,
      input$projection_basis_mode,
      input$projection_reference_year,
      input$hist_years,
      input$year_type_choice
    ),
    {
      hist_avg <- historical_avg()
      effective_frequency <- comparison_effective_frequency()
      effective_reference_year <- comparison_effective_single_reference_year(hist_avg = hist_avg)
      eligible <- is_comparison_reference_week_shift_eligible(
        hist_avg = hist_avg,
        effective_frequency = effective_frequency,
        effective_reference_year = effective_reference_year
      )
      current_shift <- normalize_comparison_reference_week_shift(isolate(comparison_reference_week_shift()))

      if (!isTRUE(eligible) && current_shift != 0L) {
        comparison_reference_week_shift(0L)
      }
    },
    ignoreInit = TRUE
  )

  # Output: Summary table
  output$summary_table <- renderDT({
    if (!is_current_vs_average_output_active()) {
      record_cache_body_execution(session, "summary_table_gated_skip")
      return(NULL)
    }
    record_cache_body_execution(
      session,
      "summary_table_executed",
      details = if (exists("vp_hierarchy_fanout_context", mode = "function")) vp_hierarchy_fanout_context() else list()
    )

    start_time <- Sys.time()
    value_digits <- normalize_summary_table_value_digits(summary_table_value_digits())
    current <- current_year_data()
    hist_avg <- historical_avg()
    effective_frequency <- comparison_effective_frequency()
    source_choice <- current_source_choice_safe(default = input$data_source_choice %||% "export_sales")
    metric_code <- effective_main_metric()
    effective_basis <- effective_basis_choice_for_metric(
      metric_code,
      current_basis_choice_safe(),
      source_choice
    )
    metric_unit_label <- get_metric_measurement_label(
      metric_code = metric_code,
      source_choice = source_choice,
      unit_choice = input$unit_choice,
      basis_choice = effective_basis,
      value_unit_choice = current_census_value_unit_choice_safe(source_choice = source_choice, metric_code = metric_code),
      commodity_name = input$commodity_choice,
      active_tab = input$main_tabs_panel
    )
    if (identical(source_choice, "vp_trade") && metric_code %in% c("unit_value", "ytd_unit_value")) {
      summary_unit_context <- build_unit_resolution_context(
        tab_id = input$main_tabs_panel %||% current_main_tab_safe(),
        output_id = "summary_table",
        source_choice = source_choice,
        metric_code = metric_code,
        trade_flow = input$vp_trade_flow_choice %||% "export",
        hierarchy_path = paste(
          input$vp_group_choice %||% "",
          input$vp_subgroup_choice %||% "",
          input$vp_market_segment_choice %||% "",
          input$vp_commodity_name_choice %||% "",
          input$commodity_choice %||% "",
          sep = "|"
        ),
        country_scope = input$country_choice %||% "",
        market_scope = input$market_year_choice %||% "",
        rollup_level = input$vp_market_segment_choice %||% "",
        rollup_path = paste(
          input$vp_group_choice %||% "",
          input$vp_subgroup_choice %||% "",
          input$vp_market_segment_choice %||% "",
          sep = "|"
        ),
        run_id = "summary_table_unit_resolution"
      )

      summary_unit_resolution <- tryCatch(
        resolve_vp_trade_display_unit(
          metric_code = metric_code,
          rows = filtered_data(),
          context = summary_unit_context
        ),
        error = function(...) NULL
      )

      if (is.list(summary_unit_resolution)) {
        unit_guardrail_record_event(
          unit_resolution = summary_unit_resolution,
          context = summary_unit_context
        )
        if (!is.null(summary_unit_resolution$label) && nzchar(summary_unit_resolution$label)) {
          metric_unit_label <- summary_unit_resolution$label
        }
      }
    }
    summary_caption <- NULL
    display_month_mapping <- current_display_month_mapping(source_choice = source_choice)
    show_any_projection <- if (input$country_choice == "GRAND_TOTAL") {
      (source_allows_historical_projection() && (isTRUE(input$show_total_projection) || isTRUE(input$show_sum_projection))) || isTRUE(input$show_linear_projection)
    } else {
      (source_allows_historical_projection() && isTRUE(input$show_projections)) || isTRUE(input$show_linear_projection_country)
    }
    
    if (is.null(current) || is.null(hist_avg)) {
      result <- NULL
      if (isTRUE(perf_boundary_markers_enabled()) && exists("log_client_perf", mode = "function")) {
        log_client_perf(
          "boundary_server_summary_table_null",
          list(
            boundary = "server_summary_table_null",
            source = input$data_source_choice,
            frequency = effective_frequency,
            rows = 0,
            projections = show_any_projection,
            elapsed_ms = perf_elapsed_ms(start_time)
          )
        )
      }

      log_perf(
        "summary_table",
        start_time,
        details = list(
          source = input$data_source_choice,
          frequency = effective_frequency,
          rows = 0,
          projections = show_any_projection
        )
      )
      return(result)
    }

    historical_years_used <- sort(unique(suppressWarnings(as.numeric(attr(hist_avg, "years_used")))))
    historical_years_used <- historical_years_used[is.finite(historical_years_used)]
    effective_reference_year <- NA_real_
    if (identical(input$projection_basis_mode, "single_year")) {
      if (length(historical_years_used) == 1) {
        effective_reference_year <- historical_years_used[[1]]
      } else {
        effective_reference_year <- suppressWarnings(as.numeric(input$projection_reference_year))
        if (length(effective_reference_year) != 1 || !is.finite(effective_reference_year)) {
          effective_reference_year <- NA_real_
        }
      }
    }
    is_single_reference_weekly <- identical(effective_frequency, "weekly") &&
      identical(input$projection_basis_mode, "single_year") &&
      is.finite(effective_reference_year)
    comparison_value_label <- if (isTRUE(is_single_reference_weekly)) {
      build_display_year_label(effective_reference_year, source_choice = source_choice)
    } else {
      "Historical Avg"
    }
    shift_value <- comparison_reference_week_shift_for_context(
      hist_avg = hist_avg,
      effective_frequency = effective_frequency,
      effective_reference_year = effective_reference_year
    )
    
    if (identical(effective_frequency, "monthly")) {
      normalized_monthly <- normalize_monthly_current_vs_average_inputs(
        current_df = current,
        hist_avg_df = hist_avg,
        source_choice = source_choice,
        country_choice = input$country_choice,
        consumer = "summary_table"
      )
      current_monthly <- normalized_monthly$current
      hist_avg_monthly <- normalized_monthly$hist_avg

      monthly_summary <- current_monthly %>%
        left_join(hist_avg_monthly, by = "analysis_month") %>%
        left_join(display_month_mapping, by = "analysis_month") %>%
        mutate(
          diff_from_avg = current_value - avg_value,
          pct_diff = ifelse(avg_value != 0, (diff_from_avg / avg_value) * 100, 0),
          month_label = month_name
        )

      if (source_choice %in% c("census", "vp_trade")) {
        monthly_summary <- monthly_summary %>%
          arrange(desc(analysis_month))
      }

      summary_table <- monthly_summary %>%
        select(
          month_label,
          current_value,
          avg_value,
          diff_from_avg,
          pct_diff,
          sd_value
        ) %>%
        dplyr::rename(
          "Month" = month_label,
          "Current Value" = current_value,
          "Historical Avg" = avg_value,
          "Difference" = diff_from_avg,
          "% Difference" = pct_diff,
          "Std Dev" = sd_value
        )
    } else {
      weekly_summary <- build_current_vs_historical_weekly_shift_frame(
        current_df = current,
        hist_avg_df = hist_avg,
        reference_df = filtered_data(),
        effective_reference_year = if (isTRUE(is_single_reference_weekly)) effective_reference_year else NA_real_,
        metric_col = effective_main_metric(),
        shift_value = shift_value,
        analysis_month_values = current$analysis_month
      ) %>%
        mutate(
          comparison_value = if (isTRUE(is_single_reference_weekly)) .data$reference_value else .data$avg_value,
          diff_from_avg = current_value - comparison_value,
          pct_diff = ifelse(comparison_value != 0, (diff_from_avg / comparison_value) * 100, 0),
          week_label = paste0("Week ", analysis_month),
          week_date = ifelse(!is.na(week_ending_date), format(as.Date(week_ending_date), "%m/%d/%Y"), NA_character_),
          reference_week_date = if (isTRUE(is_single_reference_weekly) && "reference_week_ending_date" %in% names(.)) {
            ifelse(!is.na(reference_week_ending_date), format(as.Date(reference_week_ending_date), "%m/%d/%Y"), NA_character_)
          } else {
            NA_character_
          },
          reference_week_label = if (isTRUE(is_single_reference_weekly) && "reference_week_label" %in% names(.)) {
            as.character(reference_week_label)
          } else {
            NA_character_
          },
          week_num_sort = analysis_month  # Keep for sorting
        ) %>%
        arrange(desc(week_num_sort))

      if (isTRUE(is_single_reference_weekly)) {
        summary_table <- weekly_summary %>%
          select(
            week_label,
            week_date,
            reference_week_label,
            reference_week_date,
            current_value,
            comparison_value,
            diff_from_avg,
            pct_diff,
            sd_value
          ) %>%
          dplyr::rename(
            "Week" = week_label,
            "Week Ending" = week_date,
            "Reference Week" = reference_week_label,
            "Reference Week Ending" = reference_week_date,
            "Current Value" = current_value,
            !!comparison_value_label := comparison_value,
            "Difference" = diff_from_avg,
            "% Difference" = pct_diff,
            "Std Dev" = sd_value
          )
      } else {
        summary_table <- weekly_summary %>%
          select(
            week_label,
            week_date,
            current_value,
            comparison_value,
            diff_from_avg,
            pct_diff,
            sd_value
          ) %>%
          dplyr::rename(
            "Week" = week_label,
            "Week Ending" = week_date,
            "Current Value" = current_value,
            "Historical Avg" = comparison_value,
            "Difference" = diff_from_avg,
            "% Difference" = pct_diff,
            "Std Dev" = sd_value
          )
      }
    }
    
    summary_table <- summary_table %>%
      mutate(
        across(where(is.numeric), ~round(., summary_table_value_digits_max))
      )
    
    # Add projection rows if enabled and applicable
    # For Grand Total: check individual projection toggles; for others: check show_projections
    if (show_any_projection) {
      proj <- projection_data()
      if (!is.null(proj)) {
        # Determine which projections to show based on toggle settings
        show_total <- if (input$country_choice == "GRAND_TOTAL") {
          source_allows_historical_projection() && isTRUE(input$show_total_projection)
        } else {
          source_allows_historical_projection() && isTRUE(input$show_projections)
        }
        show_sum <- if (input$country_choice == "GRAND_TOTAL") {
          source_allows_historical_projection() && isTRUE(input$show_sum_projection)
        } else {
          FALSE
        }
        
        # Get historical average at the final period
        hist_at_final <- hist_avg %>%
          filter(analysis_month == proj$total_periods)
        
        hist_final_avg <- if (nrow(hist_at_final) > 0) hist_at_final$avg_value else NA
        hist_final_sd <- if (nrow(hist_at_final) > 0) hist_at_final$sd_value else NA
        
        source_choice <- current_source_choice_safe(default = input$data_source_choice %||% "export_sales")
        display_year_type <- current_display_year_type(source_choice = source_choice)
        weekly_projection_endpoint_label <- if (identical(display_year_type, "fiscal")) "Sep 30" else "Year-End"

        make_projection_summary_row <- function(period_column, period_label, current_projection, hist_avg_value, diff_value, pct_diff_value, hist_sd_value) {
          build_current_vs_historical_projection_row(
            period_column = period_column,
            period_label = period_label,
            current_projection = current_projection,
            hist_avg_value = hist_avg_value,
            diff_value = diff_value,
            pct_diff_value = pct_diff_value,
            hist_sd_value = hist_sd_value,
            comparison_value_label = comparison_value_label,
            summary_table_digits = summary_table_value_digits_max,
            weekly_projection_endpoint_label = weekly_projection_endpoint_label,
            show_reference_week = is_single_reference_weekly,
            show_reference_week_ending = is_single_reference_weekly
          )
        }

        # Initialize empty proj_row
        proj_row <- NULL
        
        # Add Total projection row if enabled
        if (show_total && !is.null(proj$final_projection) && !is.na(proj$final_projection)) {
          # Calculate difference and % difference for projections
          diff_total <- if (!is.na(hist_final_avg)) proj$final_projection - hist_final_avg else NA
          pct_diff_total <- if (!is.na(hist_final_avg) && hist_final_avg != 0) {
            (diff_total / hist_final_avg) * 100
          } else {
            NA
          }
          
          # Determine label based on whether we have country sum projection
          proj_label <- if (!is.null(proj$country_sum_projection) && !is.na(proj$country_sum_projection)) {
            "PROJECTION (Total)"
          } else {
            "YEAR-END PROJECTION"
          }
          
          if (identical(effective_frequency, "monthly")) {
            proj_row <- make_projection_summary_row(
              "Month", proj_label, proj$final_projection, hist_final_avg, diff_total, pct_diff_total, hist_final_sd
            )
          } else {
            proj_row <- make_projection_summary_row(
              "Week", proj_label, proj$final_projection, hist_final_avg, diff_total, pct_diff_total, hist_final_sd
            )
          }
        }
        
        # Add country sum projection row if available and enabled
        if (!is.null(proj$country_sum_projection) && !is.na(proj$country_sum_projection) && show_sum) {
          diff_sum <- if (!is.na(hist_final_avg)) proj$country_sum_projection - hist_final_avg else NA
          pct_diff_sum <- if (!is.na(hist_final_avg) && hist_final_avg != 0) {
            (diff_sum / hist_final_avg) * 100
          } else {
            NA
          }
          
          if (identical(effective_frequency, "monthly")) {
            proj_row_sum <- make_projection_summary_row(
              "Month", "PROJECTION (Sum of Countries)", proj$country_sum_projection, hist_final_avg, diff_sum, pct_diff_sum, hist_final_sd
            )
          } else {
            proj_row_sum <- make_projection_summary_row(
              "Week", "PROJECTION (Sum of Countries)", proj$country_sum_projection, hist_final_avg, diff_sum, pct_diff_sum, hist_final_sd
            )
          }
          
          proj_row <- if (is.null(proj_row)) proj_row_sum else bind_rows(proj_row, proj_row_sum)
        }
        
        # Add linear projection row if available and checkbox is enabled
        show_linear <- if (input$country_choice == "GRAND_TOTAL") {
          isTRUE(input$show_linear_projection)
        } else {
          isTRUE(input$show_linear_projection_country)
        }
        
        if (!is.null(proj$linear_projection) && !is.na(proj$linear_projection) && show_linear) {
          diff_linear <- if (!is.na(hist_final_avg)) proj$linear_projection - hist_final_avg else NA
          pct_diff_linear <- if (!is.na(hist_final_avg) && hist_final_avg != 0) {
            (diff_linear / hist_final_avg) * 100
          } else {
            NA
          }
          
          # Include R² in the label
          r_sq_label <- if (!is.null(proj$linear_fit_data$r_squared)) {
            sprintf("LINEAR PROJECTION (R²=%.3f)", proj$linear_fit_data$r_squared)
          } else {
            "LINEAR PROJECTION"
          }
          
          if (identical(effective_frequency, "monthly")) {
            linear_row <- make_projection_summary_row(
              "Month", r_sq_label, proj$linear_projection, hist_final_avg, diff_linear, pct_diff_linear, hist_final_sd
            )
          } else {
            linear_row <- make_projection_summary_row(
              "Week", r_sq_label, proj$linear_projection, hist_final_avg, diff_linear, pct_diff_linear, hist_final_sd
            )
          }
          
          proj_row <- if (is.null(proj_row)) linear_row else bind_rows(proj_row, linear_row)
        }
        
        # Add projection rows at the top if any were created
        if (!is.null(proj_row)) {
          summary_table <- bind_rows(proj_row, summary_table)
        }
      }
    }

    summary_numeric_columns <- intersect(c("Current Value", comparison_value_label, "Difference", "Std Dev"), names(summary_table))
    
    result <- datatable(
      summary_table,
      caption = summary_caption,
      options = list(
        pageLength = 15,
        searching = FALSE,
        ordering = FALSE,  # Disable sorting to maintain projection at top
        dom = 'tip'
      ),
      rownames = FALSE
    ) %>%
      formatRound(
        columns = summary_numeric_columns,
        digits = value_digits,
        mark = ","
      ) %>%
      formatRound(
        columns = "% Difference",
        digits = 1,
        mark = ","
      ) %>%
      formatStyle(
        columns = "% Difference",
        background = styleInterval(
          c(-10, 0, 10),
          c("#f8d7da", "#fff3cd", "#d4edda", "#c3e6cb")
        )
      )
    log_perf(
      "summary_table",
      start_time,
      details = list(
        source = input$data_source_choice,
        frequency = input$data_frequency,
        rows = nrow(summary_table),
        projections = show_any_projection
      )
    )

    if (isTRUE(perf_boundary_markers_enabled()) && exists("log_client_perf", mode = "function")) {
      log_client_perf(
        "boundary_server_summary_table_complete",
        list(
          boundary = "server_summary_table_complete",
          source = input$data_source_choice,
          frequency = input$data_frequency,
          rows = nrow(summary_table),
          projections = show_any_projection,
          elapsed_ms = perf_elapsed_ms(start_time)
        )
      )
    }

    result
  })
  

