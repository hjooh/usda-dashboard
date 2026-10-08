
  parse_pace_target <- reactive({
    raw <- input$pace_target_single
    if (is.null(raw) || !nzchar(trimws(raw))) return(NA_real_)

    digits_only <- gsub("[^0-9]", "", raw)
    if (!nzchar(digits_only)) return(NA_real_)

    suppressWarnings(as.numeric(digits_only))
  })

  set_pace_target <- function(value) {
    updateTextInput(session, "pace_target_single", value = format_pace_target(value))
  }

  pace_tab_active <- reactive({
    identical(current_main_tab_safe(), "Pace Analysis Tool")
  })

  get_pace_resolved_basis <- reactive({
    resolve_basis_choice(input$commodity_choice, input$basis_choice, current_main_tab_safe())
  })

  pace_metric_unit_label <- function(
    metric_code = effective_main_metric(),
    source_choice = current_source_choice_safe(),
    active_tab = current_main_tab_safe()
  ) {
    effective_basis <- effective_basis_choice_for_metric(
      metric_code,
      current_basis_choice_safe(),
      source_choice
    )
    get_metric_measurement_label(
      metric_code = metric_code,
      source_choice = source_choice,
      unit_choice = input$unit_choice,
      basis_choice = effective_basis,
      value_unit_choice = current_census_value_unit_choice_safe(source_choice = source_choice, metric_code = metric_code),
      commodity_name = input$commodity_choice,
      active_tab = active_tab
    )
  }

  pace_census_signal_columns <- function(trade_flow = "export", df = NULL) {
    if (identical(trade_flow, "import")) {
      candidates <- c("ytd_imports", "ytd_imports_rough_eq", "monthlyimports", "monthlyimports_rough_eq")
    } else {
      candidates <- c("ytd_exports", "ytd_exports_rough_eq", "monthlyexports", "monthlyexports_rough_eq")
    }

    candidates <- c(
      candidates,
      "quantity_kg",
      "quantity_1000_lb",
      "quantity_mt",
      "shelled_basis_1000_lb",
      "shelled_basis_mt",
      "trade_value"
    )

    if (is.null(df) || !is.data.frame(df)) return(candidates)
    intersect(candidates, names(df))
  }

  pace_filter_anchor_census_rows <- function(df) {
    if (is.null(df) || !is.data.frame(df) || nrow(df) == 0) return(df)

    candidate <- df
    if ("country" %in% names(candidate)) {
      country_values <- toupper(trimws(as.character(candidate$country)))
      world_idx <- country_values %in% c("GRAND_TOTAL", "WORLD")
      if (any(world_idx, na.rm = TRUE)) candidate <- candidate[world_idx, , drop = FALSE]
    }

    if ("commodity" %in% names(candidate)) {
      commodity_values <- trimws(as.character(candidate$commodity))
      all_rice_idx <- vapply(commodity_values, is_all_rice_display_label, logical(1))
      if (any(all_rice_idx, na.rm = TRUE)) candidate <- candidate[all_rice_idx, , drop = FALSE]
    }

    candidate
  }

  pace_census_dataset_ref <- function(trade_flow = "export") {
    if (identical(trade_flow, "import")) {
      return(list(name = "commodity_data_census_imports_monthly", data = commodity_data_census_imports_monthly))
    }

    list(name = "commodity_data_census_exports_monthly", data = commodity_data_census_exports_monthly)
  }

  pace_filtered_raw_max_year <- function() {
    df <- filtered_data()
    if (is.null(df) || nrow(df) == 0 || !("market_year" %in% names(df))) {
      return(NA_integer_)
    }

    raw_year <- suppressWarnings(max(df$market_year, na.rm = TRUE))
    if (!is.finite(raw_year)) return(NA_integer_)
    as.integer(raw_year)
  }

  pace_census_anchor_info <- reactive({
    start_time <- Sys.time()
    source_choice <- current_source_choice_safe()
    year_type <- current_display_year_type(source_choice = source_choice)
    trade_flow <- pace_resolved_trade_flow()
    raw_max_year <- pace_filtered_raw_max_year()

    fallback_result <- function(branch, reason, artifact_name = NA_character_, census_max_year = NA_integer_, census_signal_year = NA_integer_, signal_rows = 0L, selected_rows = 0L) {
      selected_year <- if (is.finite(raw_max_year)) raw_max_year else NA_integer_
      result <- list(
        selected_year = as.integer(selected_year),
        trade_flow = trade_flow,
        source_choice = source_choice,
        year_type = year_type,
        artifact_name = artifact_name,
        census_max_year = as.integer(census_max_year),
        census_signal_year = as.integer(census_signal_year),
        raw_filtered_max_year = as.integer(raw_max_year),
        rejected_newer_filtered_year = if (is.finite(raw_max_year) && is.finite(selected_year) && raw_max_year > selected_year) as.integer(raw_max_year) else NA_integer_,
        fallback_branch = branch,
        reason = reason,
        signal_rows = as.integer(signal_rows),
        selected_year_rows = as.integer(selected_rows)
      )

      log_perf(
        "pace_census_anchor_info()",
        start_time,
        details = result
      )

      result
    }

    if (!(source_choice %in% c("export_sales", "census", "hybrid"))) {
      return(fallback_result("filtered_data_raw_max", "source_not_census_anchor_eligible"))
    }

    if (!identical(year_type, "marketing")) {
      return(fallback_result("filtered_data_raw_max", "non_marketing_year_type"))
    }

    census_dataset <- pace_census_dataset_ref(trade_flow)
    artifact_name <- census_dataset$name
    census_df <- census_dataset$data
    if (!is.data.frame(census_df) || nrow(census_df) == 0 || !("market_year" %in% names(census_df))) {
      return(fallback_result("filtered_data_raw_max", "census_artifact_empty_or_missing_market_year", artifact_name = artifact_name))
    }

    anchor_rows <- pace_filter_anchor_census_rows(census_df)
    anchor_market_years <- suppressWarnings(as.numeric(anchor_rows$market_year))
    finite_years <- suppressWarnings(as.integer(anchor_market_years[is.finite(anchor_market_years)]))
    census_max_year <- if (length(finite_years) > 0) max(finite_years, na.rm = TRUE) else NA_integer_
    if (!is.finite(census_max_year)) {
      return(fallback_result("filtered_data_raw_max", "census_market_year_unusable", artifact_name = artifact_name))
    }

    signal_cols <- pace_census_signal_columns(trade_flow, anchor_rows)
    signal_year <- NA_integer_
    signal_rows <- 0L
    if (length(signal_cols) > 0) {
      signal_matrix <- as.data.frame(lapply(anchor_rows[signal_cols], function(value) suppressWarnings(as.numeric(value))))
      has_signal <- Reduce(`|`, lapply(signal_matrix, function(value) !is.na(value) & value != 0))
      signal_rows <- sum(has_signal, na.rm = TRUE)
      signal_years <- suppressWarnings(as.integer(anchor_market_years[has_signal & is.finite(anchor_market_years)]))
      if (length(signal_years) > 0) {
        signal_year <- max(signal_years, na.rm = TRUE)
      }
    }

    selected_year <- if (is.finite(signal_year)) signal_year else census_max_year
    selected_rows <- sum(suppressWarnings(as.integer(anchor_market_years)) == selected_year, na.rm = TRUE)
    branch <- if (is.finite(signal_year)) "census_signal_year" else "census_latest_finite_year"
    reason <- if (is.finite(signal_year)) "census_quantity_signal_available" else "no_census_quantity_signal_using_latest_finite_year"

    result <- list(
      selected_year = as.integer(selected_year),
      trade_flow = trade_flow,
      source_choice = source_choice,
      year_type = year_type,
      artifact_name = artifact_name,
      census_max_year = as.integer(census_max_year),
      census_signal_year = as.integer(signal_year),
      raw_filtered_max_year = as.integer(raw_max_year),
      rejected_newer_filtered_year = if (is.finite(raw_max_year) && raw_max_year > selected_year) as.integer(raw_max_year) else NA_integer_,
      fallback_branch = branch,
      reason = reason,
      signal_rows = as.integer(signal_rows),
      selected_year_rows = as.integer(selected_rows)
    )

    log_perf(
      "pace_census_anchor_info()",
      start_time,
      details = result
    )

    result
  })

  get_pace_active_year <- reactive({
    anchor_info <- pace_census_anchor_info()
    year_value <- suppressWarnings(as.integer(anchor_info$selected_year %||% NA_integer_))

    if (!is.finite(year_value)) {
      return(NA_integer_)
    }

    year_value
  })

  pace_historical_avg <- reactive({
    start_time <- Sys.time()
    source_choice <- current_source_choice_safe()

    req(effective_main_metric())
    metric <- effective_main_metric()
    df <- filtered_data()
    active_year <- get_pace_active_year()
    if (is.null(df) || nrow(df) == 0 || !(metric %in% names(df)) || !is.finite(active_year)) {
      log_perf(
        "pace_historical_avg()",
        start_time,
        details = list(
          source = source_choice,
          frequency = input$data_frequency,
          metric = metric,
          rows = if (is.null(df)) 0L else nrow(df),
          active_year = active_year,
          status = "unavailable"
        )
      )

      return(NULL)
    }

    hist_window <- suppressWarnings(as.integer(comparison_hist_years_committed()))
    if (length(hist_window) != 1 || !is.finite(hist_window) || is.na(hist_window) || hist_window < 1) {
      hist_window <- 3L
    }
    hist_years_vec <- historical_years_for_window(df$market_year, active_year, hist_window)

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

    hist_df <- if (identical(basis_mode, "single_year") && is.finite(ref_year)) {
      df %>% filter(market_year == ref_year)
    } else {
      df %>% filter(market_year %in% hist_years_vec)
    }

    years_used <- sort(unique(hist_df$market_year))
    result <- hist_df %>%
      group_by(analysis_month) %>%
      summarise(
        avg_value = if (all(is.na(.data[[metric]]))) NA_real_ else mean(.data[[metric]], na.rm = TRUE),
        min_value = if (all(is.na(.data[[metric]]))) NA_real_ else min(.data[[metric]], na.rm = TRUE),
        max_value = if (all(is.na(.data[[metric]]))) NA_real_ else max(.data[[metric]], na.rm = TRUE),
        sd_value = if (sum(!is.na(.data[[metric]])) <= 1) NA_real_ else sd(.data[[metric]], na.rm = TRUE),
        .groups = "drop"
      ) %>%
      arrange(analysis_month)

    attr(result, "years_used") <- years_used

    log_perf(
      "pace_historical_avg()",
      start_time,
      details = list(
        source = source_choice,
        frequency = input$data_frequency,
        metric = metric,
        rows = nrow(df),
        hist_rows = nrow(hist_df),
        out_rows = nrow(result),
        active_year = active_year,
        years_used = paste(years_used, collapse = ","),
        basis_mode = basis_mode,
        ref_year = input$projection_reference_year
      )
    )

    result
  })

  pace_current_year_data <- reactive({
    start_time <- Sys.time()
    req(effective_main_metric())
    df <- filtered_data()
    metric <- effective_main_metric()
    active_year <- get_pace_active_year()
    source_choice <- current_source_choice_safe()

    if (is.null(df) || nrow(df) == 0 || !(metric %in% names(df)) || !is.finite(active_year)) {
      log_perf(
        "pace_current_year_data()",
        start_time,
        details = list(
          source = source_choice,
          frequency = input$data_frequency,
          metric = metric,
          rows = if (is.null(df)) 0L else nrow(df),
          active_year = active_year,
          status = "unavailable"
        )
      )

      return(NULL)
    }

    effective_frequency <- input$data_frequency
    current_cols <- c("analysis_month", "market_year", metric, "commodity", "country")
    if (identical(effective_frequency, "weekly") && "week_ending_date" %in% names(df)) {
      current_cols <- c(current_cols, "week_ending_date")
    }

    result <- df %>%
      filter(market_year == active_year) %>%
      select(all_of(current_cols)) %>%
      dplyr::rename(current_value = all_of(metric)) %>%
      arrange(analysis_month)

    log_perf(
      "pace_current_year_data()",
      start_time,
      details = list(
        source = source_choice,
        frequency = effective_frequency,
        metric = metric,
        rows = nrow(result),
        active_year = active_year,
        raw_filtered_max_year = pace_census_anchor_info()$raw_filtered_max_year
      )
    )

    result
  })

  pace_projection_data <- reactive({
    start_time <- Sys.time()
    source_choice <- current_source_choice_safe()

    req(effective_main_metric())
    hist_window <- comparison_hist_years_committed()
    req(hist_window)
    metric <- effective_main_metric()
    df <- filtered_data()
    active_year <- get_pace_active_year()
    basis_mode <- input$projection_basis_mode
    ref_year <- input$projection_reference_year

    result <- compute_projection_contract_shared(
      df_panel = df,
      metric_panel = metric,
      recent_year = active_year,
      hist_years = hist_window,
      basis_mode = basis_mode,
      ref_year = ref_year,
      data_frequency = input$data_frequency
    )

    log_perf(
      "pace_projection_data()",
      start_time,
      details = list(
        source = source_choice,
        frequency = input$data_frequency,
        metric = metric,
        rows = if (is.null(df)) 0L else nrow(df),
        active_year = active_year,
        available = !is.null(result)
      )
    )

    result
  })

  pace_resolved_trade_flow <- reactive({
    source_choice <- current_source_choice_safe(default = "export_sales")

    if (!exists("effective_trade_flow_for_source", mode = "function")) {
      return("export")
    }

    resolved_trade_flow <- effective_trade_flow_for_source(
      source_choice,
      input$census_trade_flow_choice,
      input$vp_trade_flow_choice
    )
    if (identical(resolved_trade_flow, "import")) "import" else "export"
  })

  pace_default_target_info <- reactive({
    hist <- pace_historical_avg()
    hist_year_end <- NA_real_

    if (!is.null(hist) && nrow(hist) > 0 && "avg_value" %in% names(hist)) {
      hist_sorted <- hist %>% arrange(analysis_month)
      hist_year_end <- suppressWarnings(as.numeric(tail(hist_sorted$avg_value, 1)))
      if (!is.finite(hist_year_end)) {
        hist_year_end <- NA_real_
      }
    }

    year_type <- current_display_year_type(source_choice = current_source_choice_safe())

    list(
      available = is.finite(hist_year_end),
      value = hist_year_end,
      source = "historical",
      year_type = year_type,
      metric_label = if (identical(pace_resolved_trade_flow(), "import")) "Imports" else "Exports"
    )
  })

  build_pace_context_key <- function() {
    source_choice <- current_source_choice_safe()
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

    paste(
      source_choice,
      pace_resolved_trade_flow(),
      if (identical(source_choice, "vp_trade")) input$vp_trade_flow_choice else "n/a",
      if (!is.null(input$vp_group_choice)) input$vp_group_choice else "__all__",
      if (!is.null(input$vp_subgroup_choice)) input$vp_subgroup_choice else "__all__",
      if (!is.null(input$vp_market_segment_choice)) input$vp_market_segment_choice else "__all__",
      if (identical(source_choice, "vp_trade")) resolved_vp$resolution_mode %||% "n/a" else "n/a",
      if (identical(source_choice, "vp_trade")) resolved_vp$path_name %||% "n/a" else "n/a",
      if (identical(source_choice, "vp_trade")) resolved_vp$cache_group_filter %||% "n/a" else "n/a",
      if (identical(source_choice, "vp_trade")) resolved_vp$cache_subgroup_filter %||% "n/a" else "n/a",
      if (identical(source_choice, "vp_trade")) resolved_vp$cache_market_segment_filter %||% "n/a" else "n/a",
      if (!is.null(input$vp_commodity_name_choice)) input$vp_commodity_name_choice else "__all__",
      input$country_choice,
      input$commodity_choice,
      effective_main_metric(),
      input$data_frequency,
      current_display_year_type(source_choice = source_choice),
      get_pace_active_year(),
      comparison_hist_years_committed(),
      input$unit_choice,
      get_pace_resolved_basis(),
      "n/a",
      input$projection_basis_mode,
      input$projection_reference_year,
      "historical",
      sep = "_"
    )
  }

  compute_default_pace_target <- function() {
    default_info <- pace_default_target_info()
    if (is.null(default_info) || !isTRUE(default_info$available)) return(NA_real_)

    target_value <- suppressWarnings(as.numeric(default_info$value))
    if (!is.finite(target_value)) return(NA_real_)

    target_value
  }

  pace_projection_value <- reactive({
    req(pace_tab_active())

    proj <- pace_projection_data()
    if (is.null(proj)) return(list(value = NA_real_, source = "none"))

    raw_source <- if (!is.null(input$pace_projection_source)) {
      as.character(input$pace_projection_source)
    } else {
      NULL
    }

    selected_source <- if (identical(raw_source, "linear")) {
      "linear"
    } else {
      "historical"
    }

    preferred_value <- switch(
      selected_source,
      "linear" = proj$linear_projection,
      proj$final_projection
    )

    if (!is.null(preferred_value) && is.finite(preferred_value)) {
      return(list(value = preferred_value, source = selected_source, unavailable = FALSE))
    }

    list(value = NA_real_, source = selected_source, unavailable = TRUE)
  })

  observeEvent(
    pace_default_target_info(),
    {
    req(pace_tab_active())

    hist_year_end <- compute_default_pace_target()
    if (!is.finite(hist_year_end)) return()

    current_context <- build_pace_context_key()

    if (last_pace_context() != current_context) {
      set_pace_target(hist_year_end)
      last_pace_context(current_context)
    }
  },
  ignoreInit = FALSE
  )

  observeEvent(input$pace_reset_target, {
    req(pace_tab_active())

    hist_year_end <- compute_default_pace_target()
    if (!is.finite(hist_year_end)) return()

    set_pace_target(hist_year_end)
    last_pace_context(build_pace_context_key())
  })

  observeEvent(input$pace_increase_5, {
    req(pace_tab_active())

    target <- parse_pace_target()
    if (!is.finite(target) || target <= 0) return()

    set_pace_target(target * 1.05)
  })

  observeEvent(input$pace_increase_10, {
    req(pace_tab_active())

    target <- parse_pace_target()
    if (!is.finite(target) || target <= 0) return()

    set_pace_target(target * 1.10)
  })

  observeEvent(input$pace_decrease_5, {
    req(pace_tab_active())

    target <- parse_pace_target()
    if (!is.finite(target) || target <= 0) return()

    set_pace_target(target * 0.95)
  })

  observeEvent(input$pace_decrease_10, {
    req(pace_tab_active())

    target <- parse_pace_target()
    if (!is.finite(target) || target <= 0) return()

    set_pace_target(target * 0.90)
  })

  pace_analysis_data <- reactive({
    req(pace_tab_active())

    proj <- pace_projection_data()
    pace_proj <- pace_projection_value()
    current <- pace_current_year_data()
    hist <- pace_historical_avg()

    if (is.null(proj) || is.null(current) || nrow(current) == 0) return(NULL)

    target <- parse_pace_target()
    if (!is.finite(target) || target <= 0) target <- NA

    current_period <- proj$current_period
    total_periods <- proj$total_periods
    current_value <- proj$current_value
    projection_valid <- if (!is.null(proj$projection_valid)) isTRUE(proj$projection_valid) else TRUE
    projection_warning <- if (!is.null(proj$projection_warning)) proj$projection_warning else NULL
    selected_projection_source <- if (!is.null(pace_proj$source)) pace_proj$source else "historical"
    is_linear_mode <- identical(selected_projection_source, "linear")
    is_hist_like_mode <- !is_linear_mode

    base_projection <- suppressWarnings(as.numeric(pace_proj$value))
    if (!is.finite(base_projection)) base_projection <- NA_real_

    selected_source_unavailable <- isTRUE(pace_proj$unavailable) || is.na(base_projection)
    if (selected_source_unavailable) {
      selected_source_warning <- switch(
        selected_projection_source,
        "linear" = "Selected linear projection is unavailable for the current filters.",
        "Selected historical projection is unavailable for the current filters."
      )
      warning_parts <- unique(c(projection_warning, selected_source_warning))
      projection_warning <- paste(warning_parts[!is.na(warning_parts) & nzchar(warning_parts)], collapse = " ")
    }

    remaining_periods <- if (projection_valid) max(total_periods - current_period, 0) else 0
    current_realized_pace <- if (current_period > 0) current_value / current_period else NA_real_

    remaining_needed <- if (!is.na(target)) target - current_value else NA_real_
    required_pace <- if (!is.na(remaining_needed) && remaining_periods > 0) {
      remaining_needed / remaining_periods
    } else {
      NA_real_
    }

    period_unit <- if (input$data_frequency == "monthly") "Month" else "Week"
    
    # Calculate expected YTD target and expected path inputs by projection mode
    hist_expected_pct <- NA_real_
    hist_expected_vol <- NA_real_
    expected_target_pct <- NA_real_
    expected_target_vol <- NA_real_
    expected_ytd_pace <- NA_real_
    ytd_volume_diff <- NA_real_
    ytd_volume_diff_pct_expected <- NA_real_
    ytd_pace_diff <- NA_real_
    ytd_pace_diff_pct_expected <- NA_real_
    expected_volume_remaining <- NA_real_
    additional_volume_required_expected <- NA_real_
    additional_volume_required_expected_pct <- NA_real_
    expected_pace_remaining <- NA_real_
    pace_needed_pct <- NA_real_
    pct_target_attained <- if (!is.na(target) && target > 0) current_value / target else NA_real_

    if (projection_valid && !is.null(hist) && nrow(hist) > 0) {
      final_hist_val <- max(hist$avg_value, na.rm = TRUE)
      if (final_hist_val > 0) {
        hist <- hist %>%
          mutate(expected_pct = avg_value / final_hist_val) %>%
          mutate(expected_curve_vol = target * expected_pct)

        cur_period_hist <- hist %>% filter(analysis_month == current_period)
        if (nrow(cur_period_hist) > 0) {
          hist_expected_pct <- cur_period_hist$expected_pct[1]
          hist_expected_vol <- cur_period_hist$expected_curve_vol[1]
        }
      }
    }

    linear_expected_pct <- if (projection_valid && !is.na(total_periods) && total_periods > 0) current_period / total_periods else NA_real_
    linear_expected_vol <- if (!is.na(target) && is.finite(linear_expected_pct)) target * linear_expected_pct else NA_real_

    if (is_hist_like_mode) {
      expected_target_pct <- hist_expected_pct
      expected_target_vol <- hist_expected_vol
    } else {
      expected_target_pct <- linear_expected_pct
      expected_target_vol <- linear_expected_vol
    }

    if (!is.na(expected_target_vol) && current_period > 0) {
      expected_ytd_pace <- expected_target_vol / current_period
    }

    ytd_volume_diff <- if (!is.na(expected_target_vol) && is.finite(expected_target_vol) && is.finite(current_value)) {
      current_value - expected_target_vol
    } else {
      NA_real_
    }
    ytd_volume_diff_pct_expected <- if (!is.na(ytd_volume_diff) && is.finite(expected_target_vol) && expected_target_vol != 0) {
      ytd_volume_diff / expected_target_vol
    } else {
      NA_real_
    }

    ytd_pace_diff <- if (!is.na(expected_ytd_pace) && is.finite(expected_ytd_pace) && is.finite(current_realized_pace)) {
      current_realized_pace - expected_ytd_pace
    } else {
      NA_real_
    }
    ytd_pace_diff_pct_expected <- if (!is.na(ytd_pace_diff) && is.finite(expected_ytd_pace) && expected_ytd_pace != 0) {
      ytd_pace_diff / expected_ytd_pace
    } else {
      NA_real_
    }

    if (remaining_periods > 0) {
      expected_pace_remaining <- if (!is.na(base_projection)) {
        (base_projection - current_value) / remaining_periods
      } else {
        NA_real_
      }
    }

    expected_volume_remaining <- if (!is.na(base_projection) && !is.na(current_value)) {
      base_projection - current_value
    } else {
      NA_real_
    }

    additional_volume_required_expected <- if (!is.na(expected_volume_remaining) && !is.na(remaining_needed)) {
      remaining_needed - expected_volume_remaining
    } else {
      NA_real_
    }

    additional_volume_required_expected_pct <- if (!is.na(additional_volume_required_expected) &&
      !is.na(expected_volume_remaining) && is.finite(expected_volume_remaining) && expected_volume_remaining != 0) {
      additional_volume_required_expected / expected_volume_remaining
    } else {
      NA_real_
    }

    pace_needed_pct <- if (!is.na(required_pace) && !is.na(expected_pace_remaining) && expected_pace_remaining != 0) {
      (required_pace - expected_pace_remaining) / abs(expected_pace_remaining)
    } else {
      NA_real_
    }

    if (!projection_valid) {
      base_projection <- NA_real_
      required_pace <- NA_real_
      expected_ytd_pace <- NA_real_
      ytd_volume_diff <- NA_real_
      ytd_volume_diff_pct_expected <- NA_real_
      ytd_pace_diff <- NA_real_
      ytd_pace_diff_pct_expected <- NA_real_
      expected_volume_remaining <- NA_real_
      additional_volume_required_expected <- NA_real_
      additional_volume_required_expected_pct <- NA_real_
      expected_pace_remaining <- NA_real_
      pace_needed_pct <- NA_real_
      expected_target_pct <- NA_real_
      expected_target_vol <- NA_real_
      hist_expected_pct <- NA_real_
      hist_expected_vol <- NA_real_
    }

    projection_line_label <- switch(
      selected_projection_source,
      "linear" = "Year-End Projection (Linear Fit)",
      "Year-End Projection (Historical)"
    )
    path_line_label <- "Path to Target (User Target)"

    list(
      target = target,
      current_period = current_period,
      total_periods = total_periods,
      current_value = current_value,
      base_projection = base_projection,
      remaining_periods = remaining_periods,
      current_realized_pace = current_realized_pace,
      expected_ytd_pace = expected_ytd_pace,
      remaining_needed = remaining_needed,
      required_pace = required_pace,
      period_unit = period_unit,
      current_series = current,
      hist_series = hist,
      selected_projection_source = selected_projection_source,
      is_hist_like_mode = is_hist_like_mode,
      is_linear_mode = is_linear_mode,
      pct_target_attained = pct_target_attained,
      hist_expected_pct = hist_expected_pct,
      hist_expected_vol = hist_expected_vol,
      expected_target_pct = expected_target_pct,
      expected_target_vol = expected_target_vol,
      ytd_volume_diff = ytd_volume_diff,
      ytd_volume_diff_pct_expected = ytd_volume_diff_pct_expected,
      ytd_pace_diff = ytd_pace_diff,
      ytd_pace_diff_pct_expected = ytd_pace_diff_pct_expected,
      expected_volume_remaining = expected_volume_remaining,
      additional_volume_required_expected = additional_volume_required_expected,
      additional_volume_required_expected_pct = additional_volume_required_expected_pct,
      expected_pace_remaining = expected_pace_remaining,
      pace_needed_pct = pace_needed_pct,
      projection_line_label = projection_line_label,
      path_line_label = path_line_label,
      projection_valid = projection_valid,
      projection_warning = projection_warning,
      linear_total_commitment_warning = if (
        identical(effective_main_metric(), "total_commitment") &&
        identical(selected_projection_source, "linear")
      ) {
        "Warning: Linear Fit extends the current trend as a straight line, but Total Commitment is influenced by discrete bookings, cancellations, and timing effects. Because these dynamics are not linear, linear extrapolation can be misleading."
      } else {
        NULL
      }
    )
  })

  # Shared semantic color mapping used by Pace KPI values and progress bars.
  pace_status_color <- function(value, good_if_positive = TRUE) {
    if (is.na(value) || !is.finite(value)) return("#6c757d")
    if (value == 0) {
      "#000000"
    } else if ((value > 0 && good_if_positive) || (value < 0 && !good_if_positive)) {
      "#2ca02c"
    } else {
      "#d62728"
    }
  }

  output$pace_kpi_ui <- renderUI({
    pace <- pace_analysis_data()
    if (is.null(pace)) return(p(em("Insufficient data to compute pace analysis for the selected filters. Please ensure a cumulative metric is selected.")))
    if (is.na(pace$target)) return(p(em("Please enter a valid target volume to calculate pace requirements.")))

    unit_label <- pace_metric_unit_label()
    border_color <- if (pace$is_linear_mode) "#ff7f0e" else "#1f77b4"
    pace_gap <- if (!is.na(pace$required_pace) && !is.na(pace$expected_pace_remaining)) pace$required_pace - pace$expected_pace_remaining else NA_real_
    additional_pace_label <- if (identical(pace$period_unit, "Week")) {
      "Additional Weekly Pace Required: "
    } else {
      "Additional Monthly Pace Required: "
    }

    fmt_num <- function(value) {
      if (is.na(value) || !is.finite(value)) return("N/A")
      format(round(value, 0), big.mark = ",")
    }

    fmt_pct <- function(value) {
      if (is.na(value) || !is.finite(value)) return("N/A")
      paste0(round(value * 100, 1), "%")
    }

    signed_value <- function(value, suffix = "", good_if_positive = TRUE) {
      if (is.na(value) || !is.finite(value)) return("N/A")
      sign_char <- if (value > 0) "+" else ""
      color <- pace_status_color(value, good_if_positive)
      span(
        style = paste0("color: ", color, "; font-size:14px; font-weight:bold;"),
        paste0(sign_char, fmt_num(value), suffix)
      )
    }

    signed_pct <- function(value, good_if_positive = TRUE) {
      if (is.na(value) || !is.finite(value)) return("N/A")
      sign_char <- if (value > 0) "+" else ""
      color <- pace_status_color(value, good_if_positive)
      span(
        style = paste0("color: ", color, "; font-size:14px; font-weight:bold;"),
        paste0(sign_char, round(value * 100, 1), "%")
      )
    }

    current_realized_pace_text <- fmt_num(pace$current_realized_pace)
    expected_target_vol_text <- fmt_num(pace$expected_target_vol)
    expected_target_pct_text <- fmt_pct(pace$expected_target_pct)
    expected_ytd_pace_text <- fmt_num(pace$expected_ytd_pace)
    expected_pace_remaining_text <- fmt_num(pace$expected_pace_remaining)
    projected_year_end_volume_text <- fmt_num(pace$base_projection)
    year_end_target_volume_text <- fmt_num(pace$target)
    required_pace_text <- fmt_num(pace$required_pace)
    expected_volume_remaining_text <- fmt_num(pace$expected_volume_remaining)
    additional_volume_required_expected_display <- signed_value(pace$additional_volume_required_expected, paste0(" ", unit_label), good_if_positive = FALSE)
    additional_volume_required_expected_pct_display <- signed_pct(pace$additional_volume_required_expected_pct, good_if_positive = FALSE)

    additional_needed_display <- signed_value(pace_gap, paste0(" ", unit_label), good_if_positive = FALSE)
    pace_adjust_display <- signed_pct(pace$pace_needed_pct, good_if_positive = FALSE)

    period_unit_plural <- paste0(pace$period_unit, "s")
    expected_by_label <- sprintf("%% Volume Expected by %s %s: ", pace$period_unit, round(pace$current_period, 0))
    volume_achieved_by_label <- sprintf("%% Volume Achieved by %s %s: ", pace$period_unit, round(pace$current_period, 0))
    expected_ytd_pace_label <- if (identical(pace$period_unit, "Week")) {
      "Expected YTD Target Pace Per Week: "
    } else {
      "Expected YTD Target Pace Per Month: "
    }
    current_pace_label <- if (identical(pace$period_unit, "Week")) "Current Weekly Pace: " else "Current Monthly Pace: "
    expected_remaining_label <- sprintf("Expected Pace for the %s Remaining %s: ", fmt_num(pace$remaining_periods), period_unit_plural)
    required_remaining_label <- sprintf("Target Pace for the %s Remaining %s: ", fmt_num(pace$remaining_periods), period_unit_plural)

    kpi_line <- function(label = NULL, value = NULL, suffix = NULL) {
      has_label <- !is.null(label) && nzchar(label)
      has_value <- !is.null(value)

      if (!has_label && !has_value) {
        return(div(style = "min-height: 26px;"))
      }

      value_children <- list()
      if (has_value) {
        value_children <- c(value_children, list(value))
      }
      if (!is.null(suffix) && nzchar(suffix)) {
        value_children <- c(value_children, list(paste0(" ", suffix)))
      }

      children <- list()
      if (has_label) {
        children <- c(children, list(div(style = "display:block;", strong(label))))
      }
      if (length(value_children) > 0) {
        children <- c(children, list(do.call(div, c(list(style = "display:block; margin-top: 1px;"), value_children))))
      }

      do.call(div, c(list(style = "min-height: 26px; line-height: 1.25;"), children))
    }

    header_cell <- function(title) {
      div(
        style = paste0(
          "font-weight:bold; margin-top:0; margin-bottom:1px; padding-bottom:2px; font-size:14px; ",
          "border-bottom:2px solid ", border_color, "; min-height: 40px; display:flex; align-items:flex-end;"
        ),
        title
      )
    }

    current_col_lines <- list(
      kpi_line("Current Volume:", fmt_num(pace$current_value), unit_label),
      kpi_line(volume_achieved_by_label, fmt_pct(pace$pct_target_attained)),
      kpi_line(current_pace_label, current_realized_pace_text, unit_label),
      kpi_line()
    )

    target_col_lines <- list(
      kpi_line("Expected YTD Target Volume:", expected_target_vol_text, unit_label),
      kpi_line(expected_by_label, expected_target_pct_text),
      kpi_line(expected_ytd_pace_label, expected_ytd_pace_text, unit_label),
      kpi_line()
    )

    ytd_diff_col_lines <- list(
      kpi_line("Difference From YTD Export Volume:", signed_value(pace$ytd_volume_diff, paste0(" ", unit_label), good_if_positive = TRUE)),
      kpi_line("% Ahead/Behind Expected YTD Target Volume:", signed_pct(pace$ytd_volume_diff_pct_expected, good_if_positive = TRUE)),
      kpi_line("Difference From YTD Export Pace:", signed_value(pace$ytd_pace_diff, paste0(" ", unit_label), good_if_positive = TRUE)),
      kpi_line("% Ahead/Behind Expected YTD Target Pace:", signed_pct(pace$ytd_pace_diff_pct_expected, good_if_positive = TRUE))
    )

    pace_col_lines <- list(
      kpi_line(sprintf("Expected Volume for Remaining %ss:", pace$period_unit), expected_volume_remaining_text, unit_label),
      kpi_line(),
      kpi_line(expected_remaining_label, expected_pace_remaining_text, unit_label),
      kpi_line()
    )

    pace_analysis_col_lines <- list(
      kpi_line("Additional Volume Required:", additional_volume_required_expected_display),
      kpi_line("% Volume Adjustment Required:", additional_volume_required_expected_pct_display),
      kpi_line(additional_pace_label, additional_needed_display),
      kpi_line("% Pace Adjustment Required:", pace_adjust_display)
    )

    position_col_lines <- list(
      kpi_line(sprintf("Required Volume for Remaining %ss:", pace$period_unit), fmt_num(pace$remaining_needed), unit_label),
      kpi_line(sprintf("Number of Remaining %s:", period_unit_plural), fmt_num(pace$remaining_periods)),
      kpi_line(required_remaining_label, required_pace_text, unit_label),
      kpi_line()
    )

    tagList(
      tags$style(HTML(paste0(
        ".pace-kpi-grid { display: grid; grid-template-columns: repeat(6, minmax(0, 1fr)); column-gap: 14px; row-gap: 5px; position: relative; }",
        ".pace-kpi-grid::before { content: ''; position: absolute; top: 0; bottom: 0; left: 50%; transform: translateX(-1px); border-left: 2px dotted ", border_color, "; pointer-events: none; }"
      ))),
      div(
        class = "pace-kpi-shell",
        style = paste0("padding: 10px; background-color: #f8f9fa; border-radius: 5px; font-size: 14px; border-left: 5px solid ", border_color, ";"),
        div(
          class = "pace-kpi-grid",
          header_cell("YTD Target"),
          header_cell("Current Position"),
          header_cell("YTD Difference"),
          header_cell("End of Year Target"),
          header_cell("End of Year Projection"),
          header_cell("Year-End Target Analysis"),
          target_col_lines[[1]],
          current_col_lines[[1]],
          ytd_diff_col_lines[[1]],
          kpi_line("Year-End Target Volume:", year_end_target_volume_text, unit_label),
          kpi_line("Projected Year-End Volume:", projected_year_end_volume_text, unit_label),
          pace_analysis_col_lines[[1]],
          target_col_lines[[3]],
          current_col_lines[[3]],
          ytd_diff_col_lines[[3]],
          position_col_lines[[3]],
          pace_col_lines[[3]],
          pace_analysis_col_lines[[3]],
          target_col_lines[[2]],
          current_col_lines[[2]],
          kpi_line(),
          pace_col_lines[[2]],
          kpi_line(),
          kpi_line(),
          target_col_lines[[4]],
          current_col_lines[[4]],
          kpi_line(),
          kpi_line(),
          kpi_line(),
          kpi_line(),
          kpi_line(),
          kpi_line(),
          kpi_line(),
          pace_col_lines[[4]],
          position_col_lines[[4]],
          kpi_line()
        )
      )
    )
  })

  output$pace_target_note <- renderUI({
    basis_mode <- input$projection_basis_mode
    ref_year <- input$projection_reference_year
    source_choice <- current_source_choice_safe()
    unit_label <- pace_metric_unit_label(source_choice = source_choice)

    note_text <- if (identical(basis_mode, "single_year") && !is.null(ref_year)) {
      paste0(
        "Note: Default target is the year-end history based on ",
        build_display_year_label(ref_year, source_choice = source_choice),
        " (",
        unit_label,
        "). Change it to test alternative scenarios."
      )
    } else {
      paste0(
        "Note: Default target is the year-end historical average (based on the Historical Years slider) in ",
        unit_label,
        ". Change it to test alternative scenarios."
      )
    }

    tags$em(note_text)
  })

  output$pace_hist_note <- renderUI({
    pace <- pace_analysis_data()
    hist_avg <- pace_historical_avg()
    years_used <- attr(hist_avg, "years_used")
    warning_note <- get_product_weight_basis_note(input$commodity_choice, input$basis_choice)
      source_choice <- current_source_choice_safe()
      sum_projection_warning <- if (identical(input$main_tabs_panel, "Pace Analysis Tool")) {
        "Warning: Sum of Countries Projection is not available in the Pace Analysis Tool tab."
      } else {
        NULL
      }
    
    basis_mode <- input$projection_basis_mode
    effective_ref_year <- if (identical(basis_mode, "single_year") && length(years_used) == 1) {
      years_used[[1]]
    } else {
      input$projection_reference_year
    }
    label_term <- if (identical(basis_mode, "single_year")) "Historical pattern" else "Historical average"

    note_children <- list()

    if (!is.null(years_used) && length(years_used) > 0) {
      note_text <- build_historical_window_note_text(
        years_used = years_used,
        label_term = label_term,
        include_note_prefix = TRUE,
        source_choice = source_choice
      )

      note_children <- c(note_children, list(
        tags$p(
          tags$em(note_text),
          if (identical(input$data_frequency, "weekly")) list(
            tags$br(),
            tags$em("To standardize year lengths, any volume reported in Week 53 or later is combined into Week 52."),
            tags$br(),
            build_weekly_axis_label_note()
          ),
          if (!is.null(sum_projection_warning)) list(
            tags$br(),
            tags$em(sum_projection_warning)
          ),
          if (!is.null(warning_note)) list(
            tags$br(),
            warning_note
          ),
          if (identical(input$pace_projection_source, "historical")) list(
            tags$br(),
            tags$em(
              if (identical(basis_mode, "single_year") && !is.null(effective_ref_year)) {
                paste0(
                  "Note: Historical pattern projection uses the selected reference year (",
                  build_display_year_label(effective_ref_year, source_choice = source_choice),
                  ")."
                )
              } else {
                "Note: Historical pattern projection uses the selected historical average window."
              }
            )
          )
        )
      ))
    }

    warning_messages <- c(
      if (!is.null(pace$projection_warning) && nzchar(pace$projection_warning)) pace$projection_warning,
      if (!is.null(pace$linear_total_commitment_warning) && nzchar(pace$linear_total_commitment_warning)) pace$linear_total_commitment_warning
    )

    if (length(warning_messages) > 0) {
      warning_blocks <- lapply(seq_along(warning_messages), function(index) {
        div(
          style = paste0(
            "margin-top: ", if (index == 1 && length(note_children) == 0) "0" else "8px", "; ",
            "padding: 10px; background-color: #fff3cd; border: 1px solid #ffeeba; color: #856404; border-radius: 4px; font-size: 13px;"
          ),
          warning_messages[[index]]
        )
      })
      note_children <- c(note_children, warning_blocks)
    }

    if (length(note_children) == 0) return(NULL)
    do.call(tagList, note_children)
  })

  output$pace_plot <- renderPlotly({
    start_time <- Sys.time()
    pace <- pace_analysis_data()
    if (is.null(pace)) {
      result <- plotly_empty_state(plot_title = "Insufficient Data")
      log_perf(
        "pace_plot",
        start_time,
        details = list(
          source = current_source_choice_safe(),
          metric = effective_main_metric(),
          projection_valid = NA,
          current_period = NA,
          total_periods = NA
        )
      )
      return(result)
    }
    if (is.na(pace$target)) {
      result <- plotly_empty_state(plot_title = "Waiting for valid target...")
      log_perf(
        "pace_plot",
        start_time,
        details = list(
          source = current_source_choice_safe(),
          metric = effective_main_metric(),
          projection_valid = pace$projection_valid,
          current_period = pace$current_period,
          total_periods = pace$total_periods
        )
      )
      return(result)
    }

    current <- pace$current_series
    hist <- pace$hist_series
    metric_unit_label <- pace_metric_unit_label()
    pace_hover_template <- paste0("%{fullData.name}<br>Period: %{x}<br>Value: %{y:,.0f} ", metric_unit_label, "<extra></extra>")
    current_trace_name <- paste0("Current Volume (", metric_unit_label, ")")
    projection_trace_name <- paste0(pace$projection_line_label, " (", metric_unit_label, ")")
    path_trace_name <- paste0(pace$path_line_label, " (", metric_unit_label, ")")

    p <- plot_ly()

    p <- p %>% add_lines(
      data = current,
      x = ~analysis_month,
      y = ~current_value,
      name = current_trace_name,
      line = list(color = "#1f77b4", width = 3),
      hovertemplate = pace_hover_template
    )

    if (isTRUE(pace$projection_valid) && is.finite(pace$base_projection)) {
      p <- p %>% add_lines(
        x = c(pace$current_period, pace$total_periods),
        y = c(pace$current_value, pace$base_projection),
        name = projection_trace_name,
        line = list(color = "#2ca02c", width = 2, dash = "dot"),
        hovertemplate = pace_hover_template
      )
    }

    if (isTRUE(pace$projection_valid) && pace$is_hist_like_mode && !is.null(hist) && nrow(hist) > 0 && "expected_curve_vol" %in% names(hist)) {
      
      # Calculate proportional expected path starting from current value
      remaining_hist <- hist %>% filter(analysis_month >= pace$current_period)
      
      if (nrow(remaining_hist) > 1 && !is.na(pace$target)) {
        current_hist_val <- remaining_hist$avg_value[1]
        final_hist_val <- max(hist$avg_value, na.rm = TRUE)
        historical_gain_remaining <- final_hist_val - current_hist_val
        
        remaining_vol <- pace$target - pace$current_value
        
        remaining_hist <- remaining_hist %>%
          mutate(
            historical_gain_since_current = avg_value - current_hist_val,
            expected_curve_vol = if (historical_gain_remaining > 0) {
              pace$current_value + remaining_vol * (historical_gain_since_current / historical_gain_remaining)
            } else {
              pace$current_value
            }
          )
        
        p <- p %>% add_lines(
          data = remaining_hist,
          x = ~analysis_month,
          y = ~expected_curve_vol,
          name = path_trace_name,
          line = list(color = "#ff7f0e", width = 3, dash = "longdash"),
          hovertemplate = pace_hover_template
        )
      }
    } else if (isTRUE(pace$projection_valid)) {
      p <- p %>% add_lines(
        x = c(pace$current_period, pace$total_periods),
        y = c(pace$current_value, pace$target),
        name = path_trace_name,
        line = list(color = "#d62728", width = 3, dash = "longdash"),
        hovertemplate = pace_hover_template
      )
    }

    display_period_end <- max(pace$total_periods, pace$current_period, na.rm = TRUE)
    source_choice <- current_source_choice_safe()
    display_month_mapping <- current_display_month_mapping(source_choice = source_choice)
    display_month_axis_title <- current_display_month_axis_title(source_choice = source_choice)

    x_axis_config <- if (input$data_frequency == "monthly") {
      # Use display month mapping safely for the active source year-type mode.
      valid_map <- display_month_mapping %>% filter(analysis_month <= display_period_end)
      list(
        title = display_month_axis_title,
        tickmode = "array",
        tickvals = valid_map$analysis_month,
        ticktext = valid_map$month_abbrev,
        range = c(1, display_period_end + 0.2)
      )
    } else {
      modifyList(
        build_weekly_x_axis_config_from_dates(
          label_source_df = current %>% select(analysis_month, week_ending_date) %>% distinct(),
          axis_title = "Week Number",
          month_label_style = "abbrev",
          include_latest_label = TRUE,
          fallback_max_week = display_period_end,
          year_type = current_display_year_type(source_choice = source_choice)
        ),
        list(
        range = c(1, display_period_end + 1)
        )
      )
    }
    
    country_title <- get_display_country(input$country_choice)
    if (is.null(country_title)) country_title <- "Selected Country"
    pace_trade_flow <- pace_resolved_trade_flow()
    metric_titles <- c(
      "monthlyexports" = "Weekly Exports",
      "ytd_exports" = if (input$data_frequency == "monthly") {
        if (identical(pace_trade_flow, "import")) {
          "Year-to-Date Imports"
        } else {
          "Year-to-Date Exports"
        }
      } else {
        if (identical(pace_trade_flow, "import")) "Accumulated Imports" else "Accumulated Exports"
      },
      "total_commitment" = "Current MY Total Commitment",
      "outstandingSales" = "Outstanding Sales",
      "grossNewSales" = "Gross New Sales",
      "currentMYNetSales" = "Current MY Net Sales",
      "nextMYOutstandingSales" = "Next MY Outstanding Sales",
      "nextMYNetSales" = "Next MY Net Sales"
    )
    metric_title <- metric_titles[[effective_main_metric()]]
    if (is.null(metric_title) || is.na(metric_title) || metric_title == "") {
      metric_title <- effective_main_metric()
    }

    warning_annotation <- NULL

    result <- p %>%
      layout(
        title = paste(
          "Trajectory to Target for",
          metric_title,
          paste0("(", metric_unit_label, ")"),
          "-",
          country_title,
          "-",
          get_commodity_display_label(input$commodity_choice, input$basis_choice)
        ),
        xaxis = x_axis_config,
        yaxis = list(title = paste0("Cumulative Value (", metric_unit_label, ")")),
        annotations = warning_annotation,
        hovermode = "x unified",
        legend = list(
          orientation = "v",
          x = 0.05,
          y = 0.93,
          xanchor = "left",
          yanchor = "top",
          bgcolor = "rgba(255,255,255,0.75)",
          bordercolor = "rgba(0,0,0,0.15)",
          borderwidth = 1
        ),
        margin = list(t = 60, r = 30, l = 70, b = 60)
      )
    log_perf(
      "pace_plot",
      start_time,
      details = list(
        source = current_source_choice_safe(),
        metric = effective_main_metric(),
        projection_valid = pace$projection_valid,
        current_period = pace$current_period,
        total_periods = pace$total_periods
      )
    )
    result
  })

  output$pace_gauges_combined_ui <- renderUI({
    pace <- pace_analysis_data()
    if (is.null(pace) || is.na(pace$target) || pace$target <= 0) return(NULL)
    unit_label <- pace_metric_unit_label()
    pace_unit_per_period <- paste0(unit_label, " per ", tolower(pace$period_unit))

    if (!isTRUE(pace$projection_valid) || !is.finite(pace$base_projection)) {
      return(div(
        style = "margin-top: 8px; padding: 10px; background-color: #fff3cd; border: 1px solid #ffeeba; color: #856404; border-radius: 5px;",
        strong("Projection unavailable for current selection.")
      ))
    }

    pct_diff_commitment <- if (!is.na(pace$ytd_pace_diff_pct_expected)) {
      pace$ytd_pace_diff_pct_expected * 100
    } else {
      NA_real_
    }
    pct_diff_required <- if (!is.na(pace$pace_needed_pct)) pace$pace_needed_pct * 100 else NA_real_
    if (!is.finite(pct_diff_commitment) || !is.finite(pct_diff_required)) return(NULL)

    gauge_section <- function(title, pct_diff, bar_color) {
      bound_limit <- max(50, ceiling(abs(pct_diff) / 10) * 10)
      pct_width <- min((abs(pct_diff) / bound_limit) * 50, 50)
      pct_label <- paste0(if (pct_diff > 0) "+" else "", round(pct_diff, 1), "%")

      if (pct_diff >= 0) {
        flex_position <- sprintf("left: 50%%; width: %s%%; background-color: %s;", pct_width, bar_color)
        label_left <- sprintf("calc(50%% + %s%%)", pct_width / 2)
      } else {
        flex_position <- sprintf("right: 50%%; width: %s%%; background-color: %s;", pct_width, bar_color)
        label_left <- sprintf("calc(50%% - %s%%)", pct_width / 2)
      }

      div(
        h5(title, style = "margin-top: 0; margin-bottom: 6px; font-weight:bold; text-align: center; font-size: 13px;"),
        div(
          style = "position: relative; width: 100%; background-color: #e9ecef; border-radius: 8px; height: 14px; overflow: hidden; margin-top: 4px;",
          div(style = "position: absolute; left: 50%; top: 0; bottom: 0; width: 2px; background-color: #333; z-index: 10;"),
          div(
            style = sprintf("position: absolute; height: 100%%; transition: width 0.5s ease-in-out, right 0.5s ease-in-out, left 0.5s ease-in-out; %s", flex_position)
          ),
          div(
            style = sprintf("position: absolute; top: 50%%; left: %s; transform: translate(-50%%, -50%%); color: #ffffff; font-weight: bold; font-size: 11px; text-shadow: 0 0 2px rgba(0,0,0,0.6); white-space: nowrap; pointer-events: none; z-index: 20;", label_left),
            pct_label
          )
        ),
        div(style = "display: flex; justify-content: space-between; font-size: 11px; color: #555; margin-top: 3px;",
          span(paste0("-", bound_limit, "%")),
          span(style = "font-weight: bold;", "0%"),
          span(paste0("+", bound_limit, "%"))
        )
      )
    }

    commitment_title <- paste0("Current Percent Ahead/Behind YTD Target Pace (", pace_unit_per_period, ")")

    commitment_color <- pace_status_color(pct_diff_commitment, good_if_positive = TRUE)
    required_color <- pace_status_color(pct_diff_required, good_if_positive = FALSE)

    tagList(
      tags$style(HTML("\
        .pace-gauge-combined-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; }\
        @media (max-width: 1100px) {\
          .pace-gauge-combined-grid { grid-template-columns: 1fr; gap: 8px; }\
        }\
      ")),
      div(
        style = "margin-top: 6px; padding: 8px; background-color: #f8f9fa; border: 1px solid #ddd; border-radius: 5px;",
        div(
          class = "pace-gauge-combined-grid",
          gauge_section(commitment_title, pct_diff_commitment, commitment_color),
          gauge_section(paste0("Pace Change Needed to Hit Target (", pace_unit_per_period, ")"), pct_diff_required, required_color)
        )
      )
    )
  })

