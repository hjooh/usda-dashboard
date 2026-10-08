  historical_trend_plot_base_cache_key <- function() {
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
      vp_trade_flow_choice = if (!is.null(input$vp_trade_flow_choice) && input$vp_trade_flow_choice %in% c("export", "import")) input$vp_trade_flow_choice else "export",
      vp_group_choice = if (!is.null(input$vp_group_choice)) input$vp_group_choice else "__all__",
      vp_subgroup_choice = if (!is.null(input$vp_subgroup_choice)) input$vp_subgroup_choice else "__all__",
      vp_market_segment_choice = if (!is.null(input$vp_market_segment_choice)) input$vp_market_segment_choice else "__all__",
      vp_resolution_mode = resolved_vp$resolution_mode %||% "n/a",
      vp_resolved_group_filter = resolved_vp$cache_group_filter %||% "n/a",
      vp_resolved_subgroup_filter = resolved_vp$cache_subgroup_filter %||% "n/a",
      vp_resolved_market_segment_filter = resolved_vp$cache_market_segment_filter %||% "n/a",
      vp_resolved_path = resolved_vp$path_name %||% "n/a",
      vp_commodity_name_choice = if (!is.null(input$vp_commodity_name_choice)) input$vp_commodity_name_choice else NA_character_,
      vp_commodity_detail_choice = if (!is.null(input$commodity_choice)) input$commodity_choice else NA_character_,
      cache_data_version = cache_data_version,
      cache_schema_version = cache_schema_version,
      commodity_choice = input$commodity_choice,
      country_choice = input$country_choice,
      data_frequency = input$data_frequency,
      display_year_type = current_display_year_type(
        source_choice = current_source_choice_safe(default = input$data_source_choice %||% "export_sales")
      ),
      metric = effective_main_metric(),
      unit_choice = input$unit_choice,
      area_unit_choice = current_psd_area_unit_choice_safe(),
      census_value_unit_choice = if (source_choice %in% c("census", "nass")) {
        current_census_value_unit_choice_safe(source_choice = source_choice, metric_code = effective_main_metric())
      } else {
        "n/a"
      },
      basis_choice = current_basis_choice_safe(),
      custom_types = custom_types_cache_key(),
      custom_countries = custom_country_cache_key()
    )
  }

  historical_trend_timeseries_cache_extension_key <- function() {
    list(
      selected_years = as.numeric(input$year_filter),
      show_hist_avg = input$show_hist_avg,
      emphasize_current_avg = input$emphasize_current_avg,
      comparison_hist_years = comparison_hist_years_committed(),
      projection_basis_mode = input$projection_basis_mode,
      projection_reference_year = input$projection_reference_year,
      show_total_projection = input$show_total_projection,
      show_sum_projection = input$show_sum_projection,
      show_linear_projection = input$show_linear_projection,
      show_projections = input$show_projections,
      show_linear_projection_country = input$show_linear_projection_country,
      show_sd_bands = input$show_sd_bands,
      width_bucket = {
        width_key <- suppressWarnings(as.numeric(session$clientData$output_timeseries_plot_width))
        if (!is.finite(width_key) || width_key <= 0) {
          1000L
        } else {
          as.integer(round(width_key / 25) * 25)
        }
      }
    )
  }

  # Output: Time series plot
  output$timeseries_plot <- renderPlotly({
    record_cache_body_execution(session, "timeseries_plot_executed")
    start_time <- Sys.time()
    source_choice <- current_source_choice_safe(default = input$data_source_choice %||% "export_sales")
    if (identical(source_choice, "psd")) {
      return(plotly_empty_state(plot_title = "Historical trend unavailable for PSD source"))
    }

    df <- filtered_data()
    
    if (nrow(df) == 0) {
      return(plotly_empty_state(plot_title = "No data available"))
    }
    
    metric <- effective_main_metric()
    selected_years <- as.numeric(input$year_filter)
    recent_year <- most_recent()$year
    hist_window <- comparison_hist_years_committed()
    display_month_mapping <- current_display_month_mapping(source_choice = source_choice)
    display_month_axis_title <- current_display_month_axis_title(source_choice = source_choice, display_month_mapping = display_month_mapping)
    census_import_mode <- identical(input$data_source_choice, "census") && identical(input$census_trade_flow_choice, "import")
    hybrid_import_mode <- identical(input$data_source_choice, "hybrid") &&
      identical(if (!is.null(input$hybrid_trade_flow_choice)) input$hybrid_trade_flow_choice else "export", "import")
    
    # Prepare data based on frequency
    if (input$data_frequency == "monthly") {
      display_month_labels <- display_month_mapping %>%
        select(analysis_month, display_month_abbrev = month_abbrev)
      df_filtered <- df %>%
        filter(market_year %in% selected_years) %>%
        left_join(display_month_labels, by = "analysis_month") %>%
        mutate(
          year_label = paste0("MY ", market_year),
          hover_period_text = ifelse(
            !is.na(display_month_abbrev) & nzchar(display_month_abbrev),
            paste0("Month: ", display_month_abbrev),
            paste0("Period ", analysis_month)
          ),
          x_numeric = analysis_month,
          is_recent = market_year == recent_year
        )
    } else {
      # For weekly, keep x_numeric as just the week number (1-53)
      # so all years overlay on the same x-axis
      df_filtered <- df %>%
        filter(market_year %in% selected_years) %>%
        mutate(
          year_label = paste0("MY ", market_year),
          hover_period_text = ifelse(
            !is.na(week_ending_date),
            paste0("Week ", analysis_month, "<br>Week ending: ", format(week_ending_date, "%m/%d/%Y")),
            paste0("Week ", analysis_month)
          ),
          x_numeric = analysis_month,
          is_recent = market_year == recent_year
        )
    }

    if (nrow(df_filtered) == 0) {
      return(plotly_empty_state(plot_title = "No data available for selected years"))
    }
    
    metric_code_active <- trimws(as.character(metric %||% ""))
    metric_unit_label <- get_metric_measurement_label(
      metric_code = metric,
      source_choice = source_choice,
      unit_choice = input$unit_choice,
      basis_choice = current_basis_choice_safe(),
      value_unit_choice = current_census_value_unit_choice_safe(
        source_choice = source_choice,
        metric_code = metric
      ),
      commodity_name = input$commodity_choice,
      active_tab = input$main_tabs_panel
    )

    if (identical(source_choice, "vp_trade") && metric_code_active %in% c("unit_value", "ytd_unit_value")) {
      timeseries_unit_context <- build_unit_resolution_context(
        tab_id = input$main_tabs_panel %||% current_main_tab_safe(),
        output_id = "timeseries_plot",
        source_choice = source_choice,
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
        market_scope = if (length(selected_years) > 0L) paste(sort(unique(selected_years)), collapse = "|") else "",
        rollup_level = input$vp_market_segment_choice %||% "",
        rollup_path = paste(
          input$vp_group_choice %||% "",
          input$vp_subgroup_choice %||% "",
          input$vp_market_segment_choice %||% "",
          sep = "|"
        ),
        run_id = "timeseries_plot_unit_resolution"
      )

      timeseries_unit_resolution <- tryCatch(
        resolve_vp_trade_display_unit(
          metric_code = metric_code_active,
          rows = df_filtered,
          context = timeseries_unit_context
        ),
        error = function(...) NULL
      )

      if (is.list(timeseries_unit_resolution)) {
        unit_guardrail_record_event(
          unit_resolution = timeseries_unit_resolution,
          context = timeseries_unit_context
        )
        if (!is.null(timeseries_unit_resolution$label) && nzchar(timeseries_unit_resolution$label)) {
          metric_unit_label <- timeseries_unit_resolution$label
        }
      }
    }

    metric_display_name <- paste0(
      get_metric_label_for_context(metric),
      " (",
      metric_unit_label,
      ")"
    )

    base_title <- paste(
      get_metric_label_for_context(metric),
      if (identical(input$data_source_choice, "census") && identical(input$country_choice, "GRAND_TOTAL")) "World" else get_display_country(input$country_choice),
      get_commodity_display_label(input$commodity_choice, current_basis_choice_safe()),
      sep = " - "
    )
    
    # Separate recent year from historical years
    df_recent <- df_filtered %>% filter(is_recent)
    df_historical <- df_filtered %>% filter(!is_recent)
    emphasize_mode <- isTRUE(input$emphasize_current_avg)
    
    p <- plot_ly()
    
    # Add historical years with default coloring
    if (nrow(df_historical) > 0) {
      if (emphasize_mode) {
        p <- p %>%
          add_trace(
            data = df_historical,
            x = ~x_numeric,
            y = ~get(metric),
            text = ~hover_period_text,
            split = ~year_label,
            type = "scatter",
            mode = "lines+markers",
            line = list(color = "rgba(140, 150, 165, 0.45)", width = 1.25),
            marker = list(size = 4, color = "rgba(140, 150, 165, 0.45)"),
            hovertemplate = if (input$data_frequency == "monthly") {
              ~paste0(
                "<b>%{fullData.name}</b><br>",
                hover_period_text, "<br>",
                metric_display_name, ": %{y:.2f}<extra></extra>"
              )
            } else {
              ~paste0(
                "<b>%{fullData.name}</b><br>",
                hover_period_text, "<br>",
                metric_display_name, ": %{y:.2f}<extra></extra>"
              )
            }
          )
      } else {
        p <- p %>%
          add_trace(
            data = df_historical,
            x = ~x_numeric,
            y = ~get(metric),
            text = ~hover_period_text,
            color = ~year_label,
            type = "scatter",
            mode = "lines+markers",
            hovertemplate = if (input$data_frequency == "monthly") {
              ~paste0(
                "<b>%{fullData.name}</b><br>",
                hover_period_text, "<br>",
                metric_display_name, ": %{y:.2f}<extra></extra>"
              )
            } else {
              ~paste0(
                "<b>%{fullData.name}</b><br>",
                hover_period_text, "<br>",
                metric_display_name, ": %{y:.2f}<extra></extra>"
              )
            }
          )
      }
    }
    
    # Add recent year with black line style
    if (nrow(df_recent) > 0) {
      p <- p %>%
        add_trace(
          data = df_recent,
          x = ~x_numeric,
          y = ~get(metric),
          text = ~hover_period_text,
          type = "scatter",
          mode = "lines+markers",
          name = paste0("Current (MY ", recent_year, ")"),
          line = list(color = "#d62728", width = 3),
          marker = list(size = 8, color = "#1f77b4"),
          hovertemplate = if (input$data_frequency == "monthly") {
            ~paste0(
              "<b>MY ", market_year, "</b><br>",
              hover_period_text, "<br>",
              metric_display_name, ": %{y:.2f}<extra></extra>"
            )
          } else {
            ~paste0(
              "<b>MY ", market_year, "</b><br>",
              hover_period_text, "<br>",
              metric_display_name, ": %{y:.2f}<extra></extra>"
            )
          }
        )
    }
    
    # Add historical average only when selected and not in cumulative single-year basis mode.
    cumulative_metrics <- c("ytd_exports", "total_commitment")
    allow_hist_avg <- isTRUE(input$show_hist_avg) &&
      !(metric %in% cumulative_metrics && identical(input$projection_basis_mode, "single_year"))

    if (allow_hist_avg) {
      hist_avg <- historical_avg()
      if (!is.null(hist_avg)) {
        if (input$data_frequency == "monthly") {
          hist_avg_plot <- hist_avg %>%
            mutate(
              x_numeric = analysis_month,
              month_abbrev = display_month_mapping$month_abbrev[suppressWarnings(as.integer(analysis_month))],
              hover_period_text = ifelse(
                !is.na(month_abbrev) & nzchar(month_abbrev),
                paste0("Month: ", month_abbrev),
                paste0("Period ", analysis_month)
              )
            )
        } else {
          hist_avg_plot <- hist_avg %>%
            left_join(
              df_recent %>% select(analysis_month, hover_period_text) %>% distinct(),
              by = "analysis_month"
            ) %>%
            mutate(
              x_numeric = analysis_month,
              hover_period_text = ifelse(
                is.na(hover_period_text),
                paste0("Week ", analysis_month),
                hover_period_text
              )
            )
        }
        
        p <- p %>%
          add_trace(
            data = hist_avg_plot,
            x = ~x_numeric,
            y = ~avg_value,
            text = ~hover_period_text,
            type = "scatter",
            mode = "lines+markers",
            name = paste0("Historical Avg (", hist_window, " yrs)"),
            line = list(color = "#1f77b4", width = 2, dash = "dash"),
            marker = list(size = 6, color = "#ff7f0e"),
            hovertemplate = ~paste0(
              "<b>", paste0("Historical Avg (", hist_window, " yrs)"), "</b><br>",
              hover_period_text, "<br>",
              metric_display_name, ": %{y:.2f}<extra></extra>"
            )
          )
      }
    }
    
    # Add projection line if enabled and applicable (for cumulative metrics)
    # For Grand Total: check individual projection toggles; for others: check show_projections
    show_any_projection <- if (input$country_choice == "GRAND_TOTAL") {
      isTRUE(input$show_total_projection) || isTRUE(input$show_sum_projection) || isTRUE(input$show_linear_projection)
    } else {
      isTRUE(input$show_projections) || isTRUE(input$show_linear_projection_country)
    }
    projection_label_x <- NA_real_
    
    if (show_any_projection) {
      proj <- projection_data()
      if (!is.null(proj)) {
        projection_label_x <- suppressWarnings(as.numeric(proj$total_periods))
        # Determine which projections to show based on toggle settings
        show_total <- if (input$country_choice == "GRAND_TOTAL") {
          isTRUE(input$show_total_projection)
        } else {
          isTRUE(input$show_projections)
        }
        show_sum <- if (input$country_choice == "GRAND_TOTAL") {
          isTRUE(input$show_sum_projection)
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
        if (show_total && !is.null(proj$final_projection)) {
          proj_values$total <- proj$final_projection
        }
        if (show_sum && !is.null(proj$country_sum_projection)) {
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
        if (show_total) {
          # Create projection line from current period to end of year (Historical Pattern)
          proj_line_data <- data.frame(
            x = c(proj$current_period, proj$total_periods),
            y = c(proj$current_value, proj$final_projection)
          )
          
          # Determine label based on whether we have country sum projection
          proj_label <- "Historical Pattern"
          
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
              text = paste0("Historical Pattern: ", format(round(proj$final_projection, 0), big.mark = ",")),
              showarrow = FALSE,
              xanchor = "left",
              xshift = 10,
              yshift = ifelse("total" %in% names(y_offsets), y_offsets["total"], 0),
              font = list(color = "#2ca02c", size = 12)
            )
        }
        
        # Add country sum projection if available and enabled (GRAND_TOTAL only)
        if (!is.null(proj$country_sum_projection) && show_sum) {
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
              name = "Sum of Countries",
              line = list(color = "#9467bd", width = 3, dash = "dot"),
              marker = list(size = 10, symbol = "square", color = "#9467bd")
            ) %>%
            add_annotations(
              x = proj$total_periods,
              y = proj$country_sum_projection,
              text = paste0("Sum of Countries: ", format(round(proj$country_sum_projection, 0), big.mark = ",")),
              showarrow = FALSE,
              xanchor = "left",
              xshift = 10,
              yshift = ifelse("sum" %in% names(y_offsets), y_offsets["sum"], 0),
              font = list(color = "#9467bd", size = 12)
            )
        }
        
        # Add linear fit projection if enabled
        if (show_linear && !is.null(proj$linear_projection)) {
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
              name = "Linear Fit",
              line = list(color = "#ff7f0e", width = 2, dash = "dashdot")
            ) %>%
            add_annotations(
              x = proj$total_periods,
              y = proj$linear_projection,
              text = paste0("Linear Fit: ", format(round(proj$linear_projection, 0), big.mark = ","), "<br>", eq_text),
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

    # In emphasis mode, label selected historical MY traces at their endpoints on the right margin.
    if (emphasize_mode && nrow(df_historical) > 0) {
      hist_endpoints <- df_historical %>%
        filter(!is.na(.data[[metric]]), !is.na(.data$x_numeric)) %>%
        group_by(.data$market_year, .data$year_label) %>%
        arrange(dplyr::desc(.data$x_numeric), .by_group = TRUE) %>%
        dplyr::slice_head(n = 1) %>%
        ungroup()

      if (nrow(hist_endpoints) > 0) {
        y_raw <- as.numeric(hist_endpoints[[metric]])
        y_range <- range(df_filtered[[metric]], na.rm = TRUE)
        y_span <- y_range[2] - y_range[1]
        if (!is.finite(y_span) || y_span <= 0) {
          y_span <- max(abs(y_raw), na.rm = TRUE)
        }
        if (!is.finite(y_span) || y_span <= 0) {
          y_span <- 1
        }

        min_gap <- y_span * 0.04
        if (!is.finite(min_gap) || min_gap <= 0) {
          min_gap <- 1
        }

        ord <- order(y_raw, decreasing = TRUE)
        y_adj_ord <- y_raw[ord]
        if (length(y_adj_ord) > 1) {
          for (i in 2:length(y_adj_ord)) {
            if ((y_adj_ord[i - 1] - y_adj_ord[i]) < min_gap) {
              y_adj_ord[i] <- y_adj_ord[i - 1] - min_gap
            }
          }
        }

        y_adj <- y_raw
        y_adj[ord] <- y_adj_ord
        hist_endpoints$label_y <- y_adj
        label_anchor_x <- if (is.finite(projection_label_x)) {
          projection_label_x
        } else {
          suppressWarnings(max(hist_endpoints$x_numeric, na.rm = TRUE))
        }

        for (i in seq_len(nrow(hist_endpoints))) {
          p <- p %>%
            add_annotations(
              x = label_anchor_x,
              y = hist_endpoints$label_y[i],
              text = as.character(hist_endpoints$year_label[i]),
              showarrow = FALSE,
              xanchor = "left",
              xshift = 10,
              font = list(color = "rgba(90, 100, 115, 0.95)", size = 11)
            )
        }
      }
    }
    
    # Setup x-axis based on frequency
    if (input$data_frequency == "monthly") {
      x_axis_config <- list(
        title = display_month_axis_title,
        tickvals = 1:12,
        ticktext = display_month_mapping$month_abbrev
      )
    } else {
      x_axis_config <- build_weekly_x_axis_config_from_dates(
        label_source_df = df_recent %>% select(analysis_month, week_ending_date) %>% distinct(),
        axis_title = "Week Number",
        month_label_style = "abbrev",
        include_latest_label = TRUE,
        fallback_max_week = max(52L, max(df_filtered$analysis_month, na.rm = TRUE), na.rm = TRUE),
        year_type = current_display_year_type(
          source_choice = current_source_choice_safe(default = input$data_source_choice %||% "export_sales")
        )
      )
    }
    
    # Format country name for display
    display_country <- get_display_country(input$country_choice)

    plot_width <- suppressWarnings(as.numeric(session$clientData$output_timeseries_plot_width))
    if (!is.finite(plot_width) || plot_width <= 0) {
      plot_width <- 1000
    }
    # Option 1: shared responsive right margin (100px at 1000px reference width).
    right_margin <- round(max(80, min(220, 100 * (plot_width / 1000))))
    
    out <- p %>%
      layout(
        title = base_title,
        xaxis = x_axis_config,
        yaxis = list(title = metric_display_name),
        hovermode = "x unified",
        legend = list(yanchor = "top", y = 0.99, xanchor = "left", x = 0.01),
        margin = list(r = right_margin)
      )

    projection_trace_count <- 0L
    projection_point_count <- 0L
    projection_annotation_count <- 0L
    if (exists("proj", inherits = FALSE) && !is.null(proj)) {
      if (isTRUE(get0("show_total", ifnotfound = FALSE)) && !is.null(proj$final_projection)) {
        projection_trace_count <- projection_trace_count + 1L
        projection_point_count <- projection_point_count + 2L
        projection_annotation_count <- projection_annotation_count + 1L
      }
      if (isTRUE(get0("show_sum", ifnotfound = FALSE)) && !is.null(proj$country_sum_projection)) {
        projection_trace_count <- projection_trace_count + 1L
        projection_point_count <- projection_point_count + 2L
        projection_annotation_count <- projection_annotation_count + 1L
      }
      if (isTRUE(get0("show_linear", ifnotfound = FALSE)) && !is.null(proj$linear_projection)) {
        projection_trace_count <- projection_trace_count + 1L
        projection_point_count <- projection_point_count + 2L
        projection_annotation_count <- projection_annotation_count + 1L
      }
    }

    hist_avg_rows <- if (exists("hist_avg_plot", inherits = FALSE) && !is.null(hist_avg_plot)) nrow(hist_avg_plot) else 0L
    hist_endpoint_count <- if (exists("hist_endpoints", inherits = FALSE) && !is.null(hist_endpoints)) nrow(hist_endpoints) else 0L
    historical_trace_count <- if (nrow(df_historical) > 0) length(unique(df_historical$year_label)) else 0L
    recent_trace_count <- if (nrow(df_recent) > 0) 1L else 0L
    hist_avg_trace_count <- if (hist_avg_rows > 0) 1L else 0L
    timeseries_complexity_details <- list(
      status = "ok",
      source_choice = source_choice,
      frequency = input$data_frequency,
      n_input_rows = nrow(df),
      n_filtered_rows = nrow(df_filtered),
      n_recent_rows = nrow(df_recent),
      n_historical_rows = nrow(df_historical),
      n_selected_years = length(unique(stats::na.omit(selected_years))),
      n_historical_years = if (nrow(df_historical) > 0) length(unique(stats::na.omit(df_historical$market_year))) else 0L,
      expected_trace_count = historical_trace_count + recent_trace_count + hist_avg_trace_count + projection_trace_count,
      expected_point_count = nrow(df_historical) + nrow(df_recent) + hist_avg_rows + projection_point_count,
      expected_annotation_count = hist_endpoint_count + projection_annotation_count,
      uses_markers = TRUE,
      uses_hist_avg = hist_avg_trace_count > 0L,
      uses_projection = projection_trace_count > 0L,
      emphasize_mode = emphasize_mode,
      hist_window = hist_window,
      hover_text_chars_est = sum(nchar(stats::na.omit(as.character(df_filtered$hover_period_text))), na.rm = TRUE) +
        if (hist_avg_rows > 0) sum(nchar(stats::na.omit(as.character(hist_avg_plot$hover_period_text))), na.rm = TRUE) else 0L
    )
    
    log_perf("timeseries_plot", start_time, details = timeseries_complexity_details)
    out
  }) %>% bindCache(
    historical_trend_plot_base_cache_key()$data_source_choice,
    historical_trend_plot_base_cache_key()$vp_trade_flow_choice,
    historical_trend_plot_base_cache_key()$vp_group_choice,
    historical_trend_plot_base_cache_key()$vp_subgroup_choice,
    historical_trend_plot_base_cache_key()$vp_market_segment_choice,
    historical_trend_plot_base_cache_key()$vp_resolution_mode,
    historical_trend_plot_base_cache_key()$vp_resolved_group_filter,
    historical_trend_plot_base_cache_key()$vp_resolved_subgroup_filter,
    historical_trend_plot_base_cache_key()$vp_resolved_market_segment_filter,
    historical_trend_plot_base_cache_key()$vp_resolved_path,
    historical_trend_plot_base_cache_key()$vp_commodity_name_choice,
    historical_trend_plot_base_cache_key()$vp_commodity_detail_choice,
    historical_trend_plot_base_cache_key()$cache_data_version,
    historical_trend_plot_base_cache_key()$cache_schema_version,
    historical_trend_plot_base_cache_key()$commodity_choice,
    historical_trend_plot_base_cache_key()$country_choice,
    historical_trend_plot_base_cache_key()$data_frequency,
    historical_trend_plot_base_cache_key()$display_year_type,
    historical_trend_plot_base_cache_key()$metric,
    historical_trend_timeseries_cache_extension_key()$selected_years,
    historical_trend_timeseries_cache_extension_key()$show_hist_avg,
    historical_trend_timeseries_cache_extension_key()$emphasize_current_avg,
    historical_trend_timeseries_cache_extension_key()$comparison_hist_years,
    historical_trend_plot_base_cache_key()$unit_choice,
    historical_trend_plot_base_cache_key()$census_value_unit_choice,
    historical_trend_plot_base_cache_key()$basis_choice,
    historical_trend_timeseries_cache_extension_key()$projection_basis_mode,
    historical_trend_timeseries_cache_extension_key()$projection_reference_year,
    historical_trend_timeseries_cache_extension_key()$show_total_projection,
    historical_trend_timeseries_cache_extension_key()$show_sum_projection,
    historical_trend_timeseries_cache_extension_key()$show_linear_projection,
    historical_trend_timeseries_cache_extension_key()$show_projections,
    historical_trend_timeseries_cache_extension_key()$show_linear_projection_country,
    historical_trend_timeseries_cache_extension_key()$show_sd_bands,
    historical_trend_plot_base_cache_key()$custom_types,
    historical_trend_plot_base_cache_key()$custom_countries,
    historical_trend_timeseries_cache_extension_key()$width_bucket
  )

  is_time_series_source_active <- function(
    source_choice = current_source_choice_safe(),
    active_tab = current_main_tab_safe()
  ) {
    identical(active_tab, "Time Series Analysis Tool") && source_choice %in% c("psd", "wasde", "nass")
  }

  map_wasde_time_series_metric_id <- function(metric_code = effective_main_metric()) {
    normalize_wasde_metric_id(metric_code)
  }

  wasde_default_milling_factor <- 1.42857142857143

  resolve_wasde_metric_basis_profile <- function(
    metric_code = effective_main_metric(),
    metric_id = map_wasde_time_series_metric_id(metric_code)
  ) {
    metric_id_value <- trimws(as.character(metric_id %||% ""))
    metric_id_value <- metric_id_value[!is.na(metric_id_value) & nzchar(metric_id_value)]
    metric_id_value <- if (length(metric_id_value) > 0) normalize_wasde_metric_id(metric_id_value[[1]]) else normalize_wasde_metric_id(metric_code)

    metric_code_value <- trimws(as.character(metric_code %||% ""))
    metric_code_value <- metric_code_value[!is.na(metric_code_value) & nzchar(metric_code_value)]
    metric_code_value <- if (length(metric_code_value) > 0) metric_code_value[[1]] else ""

    metric_id_scalar <- trimws(as.character(metric_id_value %||% ""))
    metric_id_scalar <- metric_id_scalar[!is.na(metric_id_scalar) & nzchar(metric_id_scalar)]
    metric_id_scalar <- if (length(metric_id_scalar) > 0) metric_id_scalar[[1]] else ""

    if (!nzchar(metric_id_scalar)) {
      fallback_metric_id <- gsub("^wasde_", "", metric_code_value)
      if (startsWith(fallback_metric_id, "qty_of_")) {
        fallback_metric_id <- sub("^qty_of_", "", fallback_metric_id)
      }
      metric_id_scalar <- trimws(fallback_metric_id)
    }

    if (!is_wasde_quantity_metric(metric_id_scalar)) {
      return("non_basis")
    }

    explicit_profiles <- c(
      "exports_milled_production" = "rough_eq"
    )
    explicit_profile <- if (nzchar(metric_id_scalar) && metric_id_scalar %in% names(explicit_profiles)) {
      unname(explicit_profiles[[metric_id_scalar]])
    } else {
      ""
    }
    if (!is.null(explicit_profile) && nzchar(explicit_profile)) {
      return(explicit_profile)
    }

    if (nzchar(metric_id_scalar) && grepl("milled", metric_id_scalar, fixed = TRUE)) {
      return("milled_eq")
    }

    "rough_eq"
  }

  normalize_wasde_milling_factor <- function(
    milling_rate_values,
    fallback_factor = wasde_default_milling_factor
  ) {
    rate_values <- sanitize_numeric(milling_rate_values)
    fallback_value <- sanitize_numeric(fallback_factor)
    if (!is.finite(fallback_value) || fallback_value <= 0) {
      fallback_value <- wasde_default_milling_factor
    }

    from_decimal <- ifelse(!is.na(rate_values) & rate_values > 0 & rate_values <= 1.5, 1 / rate_values, NA_real_)
    from_percent <- ifelse(!is.na(rate_values) & rate_values > 1.5 & rate_values <= 100, 100 / rate_values, NA_real_)
    from_basis_points <- ifelse(!is.na(rate_values) & rate_values > 100, 10000 / rate_values, NA_real_)

    resolved_factor <- dplyr::coalesce(from_decimal, from_percent, from_basis_points)
    resolved_factor <- ifelse(
      !is.na(resolved_factor) & is.finite(resolved_factor) & resolved_factor > 0 & resolved_factor < 10,
      resolved_factor,
      NA_real_
    )

    dplyr::coalesce(resolved_factor, fallback_value)
  }

  build_wasde_milling_lookup <- function(source_df, selected_commodity, selected_country) {
    required_cols <- c(
      "commodity", "country", "normalized_metric_id", "market_year", "value_canonical",
      "release_year", "release_month", "analysis_month"
    )
    if (
      is.null(source_df) || !is.data.frame(source_df) || nrow(source_df) == 0 ||
        !all(required_cols %in% names(source_df))
    ) {
      return(data.frame(
        market_year = integer(),
        wasde_milling_rate_value = numeric(),
        wasde_milling_factor = numeric(),
        wasde_milling_factor_source = character(),
        stringsAsFactors = FALSE
      ))
    }

    source_df %>%
      filter(
        .data$commodity == selected_commodity,
        .data$country == selected_country,
        .data$normalized_metric_id == "milling_rate"
      ) %>%
      transmute(
        market_year = suppressWarnings(as.integer(.data$market_year)),
        release_ord = suppressWarnings(as.integer(.data$release_year)) * 100L + suppressWarnings(as.integer(.data$release_month)),
        analysis_month = suppressWarnings(as.integer(.data$analysis_month)),
        wasde_milling_rate_value = sanitize_numeric(.data$value_canonical)
      ) %>%
      filter(!is.na(.data$market_year), is.finite(.data$wasde_milling_rate_value)) %>%
      arrange(desc(.data$release_ord), desc(.data$analysis_month)) %>%
      group_by(.data$market_year) %>%
      summarise(
        wasde_milling_rate_value = dplyr::first(.data$wasde_milling_rate_value),
        .groups = "drop"
      ) %>%
      mutate(
        wasde_milling_factor = normalize_wasde_milling_factor(.data$wasde_milling_rate_value),
        wasde_milling_factor_source = ifelse(
          is.finite(.data$wasde_milling_rate_value) & .data$wasde_milling_rate_value > 0,
          "wasde_milling_rate",
          "fallback_static"
        )
      ) %>%
      as.data.frame(stringsAsFactors = FALSE)
  }

  apply_wasde_basis_profile_conversion <- function(
    native_values,
    basis_choice,
    basis_profile = "rough_eq",
    milling_factors = wasde_default_milling_factor
  ) {
    native_values <- sanitize_numeric(native_values)
    factors <- sanitize_numeric(milling_factors)
    factors <- ifelse(
      !is.na(factors) & is.finite(factors) & factors > 0,
      factors,
      wasde_default_milling_factor
    )

    profile_values <- trimws(as.character(basis_profile %||% "rough_eq"))
    profile_values <- ifelse(is.na(profile_values) | !nzchar(profile_values), "rough_eq", profile_values)
    if (length(profile_values) == 1L && length(native_values) > 1L) {
      profile_values <- rep(profile_values, length(native_values))
    }

    resolved_basis <- trimws(as.character(basis_choice %||% "rough_eq"))
    resolved_basis <- resolved_basis[!is.na(resolved_basis) & nzchar(resolved_basis)]
    resolved_basis <- if (length(resolved_basis) > 0) resolved_basis[[1]] else "rough_eq"

    rough_values <- ifelse(profile_values == "milled_eq", native_values * factors, native_values)

    converted_values <- if (identical(resolved_basis, "milled_eq")) {
      ifelse(profile_values == "non_basis", native_values, rough_values / factors)
    } else if (identical(resolved_basis, "unadjusted")) {
      native_values
    } else {
      ifelse(profile_values == "non_basis", native_values, rough_values)
    }

    sanitize_numeric(converted_values)
  }

  convert_wasde_display_values <- function(
    values,
    metric_code,
    unit_choice,
    area_unit_choice,
    basis_choice,
    value_unit_choice,
    milling_factors = wasde_default_milling_factor,
    basis_profile = NULL,
    commodity_choice = input$commodity_choice %||% default_commodity_choice_value(),
    active_tab = "Time Series Analysis Tool",
    lock_context = "selected_metric"
  ) {
    metric_id <- normalize_wasde_metric_id(metric_code)
    if (is.null(metric_id) || !nzchar(metric_id)) {
      metric_id <- trimws(as.character(metric_code %||% ""))
    }

    # Percent-family metrics are already unitless and must remain invariant under unit/basis toggles.
    if (identical(wasde_metric_family_for_code(metric_id), "percent")) {
      return(sanitize_numeric(values))
    }

    effective_controls <- list(
      unit_choice = unit_choice,
      area_unit_choice = area_unit_choice,
      basis_choice = basis_choice,
      value_unit_choice = value_unit_choice,
      price_locked = FALSE,
      yield_locked = FALSE
    )
    effective_controls <- wasde_effective_conversion_controls(
      metric_code = metric_id,
      source_choice = "wasde",
      unit_choice = unit_choice,
      area_unit_choice = area_unit_choice,
      basis_choice = basis_choice,
      value_unit_choice = value_unit_choice,
      lock_context = lock_context
    )

    resolved_basis <- resolve_basis_choice(
      commodity_choice %||% default_commodity_choice_value(),
      effective_controls$basis_choice,
      active_tab = active_tab,
      source_choice = "wasde"
    )

    resolved_profile <- basis_profile
    if (is.null(resolved_profile) || length(resolved_profile) == 0L) {
      resolved_profile <- resolve_wasde_metric_basis_profile(metric_code = metric_id, metric_id = metric_id)
    }
    if (is_wasde_yield_metric(metric_id)) {
      resolved_profile <- "rough_eq"
    }

    basis_values <- apply_wasde_basis_profile_conversion(
      native_values = sanitize_numeric(values),
      basis_choice = resolved_basis,
      basis_profile = resolved_profile,
      milling_factors = milling_factors
    )

    unit_basis_choice <- if (is_wasde_quantity_metric(metric_id) || is_wasde_yield_metric(metric_id)) {
      "rough_eq"
    } else {
      resolved_basis
    }

    sanitize_numeric(unit_conversion(
      basis_values,
      effective_controls$unit_choice,
      source_choice = "wasde",
      metric_code = metric_id,
      area_unit_choice = effective_controls$area_unit_choice,
      basis_choice = unit_basis_choice,
      value_unit_choice = effective_controls$value_unit_choice,
      commodity_choice = commodity_choice,
      lock_context = "post_basis_conversion"
    ))
  }

  map_wasde_historical_metric_code <- function(metric_code = effective_main_metric()) {
    metric_id <- map_wasde_time_series_metric_id(metric_code)
    if (is.null(metric_id) || !nzchar(metric_id)) {
      return(NULL)
    }

    paste0("wasde_", metric_id)
  }

  map_wasde_historical_metric_to_ui_metric <- function(metric_code) {
    metric_code <- as.character(metric_code %||% "")
    metric_code <- metric_code[!is.na(metric_code) & nzchar(metric_code)]
    if (length(metric_code) == 0) {
      return(NULL)
    }

    normalize_wasde_metric_id(metric_code[[1]])
  }

  resolve_wasde_time_series_country_code <- function(
    requested_country = input$country_choice %||% "U_S",
    source_df = rice_data_wasde_marketing_year
  ) {
    requested_values <- trimws(as.character(requested_country %||% character(0)))
    requested_values <- requested_values[!is.na(requested_values) & nzchar(requested_values)]
    requested_code <- if (length(requested_values) > 0) requested_values[[1]] else "U_S"

    if (is.null(source_df) || !is.data.frame(source_df) || !("country" %in% names(source_df))) {
      return(requested_code)
    }

    available_codes <- trimws(as.character(source_df$country))
    available_codes <- unique(available_codes[!is.na(available_codes) & nzchar(available_codes)])
    if (length(available_codes) == 0) {
      return(requested_code)
    }

    if (requested_code %in% available_codes) {
      return(requested_code)
    }

    normalized_requested <- toupper(gsub("[^A-Z0-9]+", "", requested_code))

    if ("countryDescription" %in% names(source_df)) {
      normalized_labels <- toupper(gsub("[^A-Z0-9]+", "", trimws(as.character(source_df$countryDescription))))
      label_match_idx <- which(!is.na(normalized_labels) & normalized_labels == normalized_requested)
      if (length(label_match_idx) > 0) {
        matched_country <- trimws(as.character(source_df$country[label_match_idx[[1]]]))
        if (!is.na(matched_country) && nzchar(matched_country) && matched_country %in% available_codes) {
          return(matched_country)
        }
      }
    }

    if (normalized_requested %in% c("GRANDTOTAL", "WORLD", "TOTAL") && "U_S" %in% available_codes) {
      return("U_S")
    }

    if (exists("resolve_wasde_country_code", mode = "function")) {
      default_country <- resolve_wasde_country_code(default = available_codes[[1]])
      default_country <- trimws(as.character(default_country %||% character(0)))
      default_country <- default_country[!is.na(default_country) & nzchar(default_country)]
      if (length(default_country) > 0 && default_country[[1]] %in% available_codes) {
        return(default_country[[1]])
      }
    }

    if ("U_S" %in% available_codes) {
      return("U_S")
    }

    available_codes[[1]]
  }

  resolved_psd_app_commodity <- function(default = NULL) {
    fallback <- default %||% tryCatch(app_psd_commodity_label(), error = function(...) NULL) %||% default_commodity_choice_value()
    fallback_values <- trimws(as.character(fallback %||% character(0)))
    fallback_values <- fallback_values[!is.na(fallback_values) & nzchar(fallback_values)]
    fallback <- if (length(fallback_values) > 0L) fallback_values[[1L]] else default_commodity_choice_value()

    commodity_values <- trimws(as.character(input$commodity_choice %||% character(0)))
    commodity_values <- commodity_values[!is.na(commodity_values) & nzchar(commodity_values)]
    if (length(commodity_values) > 0L) commodity_values[[1L]] else fallback
  }

  build_psd_latest_market_year_rows <- function(
    selected_country = input$country_choice %||% "GRAND_TOTAL",
    selected_commodity = NULL,
    metric_code = effective_main_metric()
  ) {
    start_time <- Sys.time()
    requested_country_values <- trimws(as.character(selected_country %||% character(0)))
    requested_country_values <- requested_country_values[!is.na(requested_country_values) & nzchar(requested_country_values)]
    requested_country <- if (length(requested_country_values) > 0) requested_country_values[[1]] else "GRAND_TOTAL"

    commodity_values <- trimws(as.character(selected_commodity %||% character(0)))
    commodity_values <- commodity_values[!is.na(commodity_values) & nzchar(commodity_values)]
    commodity_value <- if (length(commodity_values) > 0) commodity_values[[1]] else resolved_psd_app_commodity()

    source_df <- rice_data_psd_marketing_year
    if (is.null(source_df) || !is.data.frame(source_df) || nrow(source_df) == 0) {
      log_perf(
        "build_psd_latest_market_year_rows()",
        start_time,
        details = list(metric = metric_code, requested_country = requested_country, country = requested_country, status = "empty_source", rows = 0)
      )
      return(data.frame())
    }

    source_country_pairs <- if (all(c("country", "countryDescription") %in% names(source_df))) {
      canonicalize_psd_country_pairs(source_df[, c("country", "countryDescription"), drop = FALSE])
    } else {
      data.frame(
        country = unique(as.character(source_df$country %||% character(0))),
        country_label = unique(as.character(source_df$country %||% character(0))),
        stringsAsFactors = FALSE
      )
    }
    source_country_pairs <- source_country_pairs[!is.na(source_country_pairs$country) & nzchar(source_country_pairs$country), , drop = FALSE]
    source_country_choices <- stats::setNames(source_country_pairs$country, source_country_pairs$country_label)
    resolved_country <- if (exists("resolve_psd_country_code", mode = "function")) {
      resolve_psd_country_code(requested_country, source_country_choices, base_choices = source_country_choices, default = NULL)
    } else {
      requested_country
    }

    if (is.null(resolved_country) || !nzchar(resolved_country)) {
      log_perf(
        "build_psd_latest_market_year_rows()",
        start_time,
        details = list(
          metric = metric_code,
          requested_country = requested_country,
          resolved_country = NULL,
          country = requested_country,
          status = "unresolved_country",
          rows = 0,
          source_mode = "psd_filtered_metric_frame"
        )
      )
      return(data.frame())
    }

    country_value <- resolved_country

    metric_cols <- intersect(unname(psd_metric_choices), names(source_df))
    identity_cols <- c(
      "country", "countryDescription", "commodity", "market_year", "analysis_month",
      "release_year", "release_month", "release_period"
    )
    required_cols <- unique(c(identity_cols, metric_cols, paste0(metric_cols, "_rough_eq")))
    required_cols <- required_cols[required_cols %in% names(source_df)]

    source_df <- source_df[, required_cols, drop = FALSE] %>%
      filter(.data$commodity == .env$commodity_value, .data$country == .env$country_value)

    if (nrow(source_df) == 0) {
      log_perf(
        "build_psd_latest_market_year_rows()",
        start_time,
        details = list(
          metric = metric_code,
          requested_country = requested_country,
          resolved_country = country_value,
          country = country_value,
          status = "empty_filtered_source",
          rows = 0,
          source_mode = "psd_filtered_metric_frame"
        )
      )
      return(data.frame())
    }

    resolved_basis <- active_resolved_basis()
    unit_choice <- current_unit_choice_safe(default = default_unit_choice_for_context(source_choice, effective_main_metric()))
    area_unit_choice <- current_psd_area_unit_choice_safe()

    for (metric_col in metric_cols) {
      metric_values <- sanitize_numeric(source_df[[metric_col]])
      rough_col <- paste0(metric_col, "_rough_eq")
      rough_values <- if (rough_col %in% names(source_df)) {
        sanitize_numeric(source_df[[rough_col]])
      } else {
        metric_values
      }

      converted_values <- if (is_psd_milling_rate_metric(metric_col)) {
        metric_values
      } else {
        basis_values <- basis_conversion(
          base_value = metric_values,
          rough_value = rough_values,
          basis_choice = resolved_basis,
          source_choice = "psd"
        )
        unit_conversion(
          basis_values,
          unit_choice,
          source_choice = "psd",
          metric_code = metric_col,
          area_unit_choice = area_unit_choice
        )
      }

      source_df[[metric_col]] <- sanitize_numeric(converted_values)
    }

    if (
      isTRUE(psd_yield_lock_active_for_metric(metric_code, "psd")) &&
        "psd_yield" %in% names(source_df) &&
        "psd_yield_rough_eq" %in% names(source_df)
    ) {
      source_df$psd_yield <- sanitize_numeric(unit_conversion(
        sanitize_numeric(source_df$psd_yield_rough_eq),
        unit_choice,
        source_choice = "psd",
        metric_code = "psd_yield",
        area_unit_choice = area_unit_choice
      ))
    }

    reduced_df <- reduce_psd_latest_market_year_estimates(source_df, group_cols = character()) %>%
      arrange(.data$market_year)

    log_perf(
      "build_psd_latest_market_year_rows()",
      start_time,
      details = list(
        metric = metric_code,
        requested_country = requested_country,
        resolved_country = country_value,
        country = country_value,
        rows = nrow(reduced_df),
        market_years = dplyr::n_distinct(reduced_df$market_year),
        source_mode = "psd_filtered_metric_frame",
        metric_cols = length(metric_cols)
      )
    )

    as.data.frame(reduced_df)
  }

  build_wasde_latest_market_year_rows <- function(
    selected_country = input$country_choice %||% "U_S",
    selected_commodity = input$commodity_choice %||% default_commodity_choice_value(),
    metric_code = effective_main_metric()
  ) {
    start_time <- Sys.time()
    requested_country_values <- trimws(as.character(selected_country %||% character(0)))
    requested_country_values <- requested_country_values[!is.na(requested_country_values) & nzchar(requested_country_values)]
    requested_country <- if (length(requested_country_values) > 0) requested_country_values[[1]] else "U_S"

    commodity_values <- trimws(as.character(selected_commodity %||% character(0)))
    commodity_values <- commodity_values[!is.na(commodity_values) & nzchar(commodity_values)]
    commodity_value <- if (length(commodity_values) > 0) commodity_values[[1]] else default_commodity_choice_value()

    source_df <- rice_data_wasde_marketing_year
    if (is.null(source_df) || !is.data.frame(source_df) || nrow(source_df) == 0) {
      log_perf(
        "build_wasde_latest_market_year_rows()",
        start_time,
        details = list(metric = metric_code, requested_country = requested_country, country = requested_country, status = "empty_source", rows = 0)
      )
      return(data.frame())
    }

    metric_id <- map_wasde_time_series_metric_id(metric_code)
    if (is.null(metric_id) || !nzchar(metric_id)) {
      log_perf(
        "build_wasde_latest_market_year_rows()",
        start_time,
        details = list(metric = metric_code, requested_country = requested_country, country = requested_country, status = "unsupported_metric", rows = 0)
      )
      return(data.frame())
    }

    country_value <- resolve_wasde_time_series_country_code(
      requested_country = requested_country,
      source_df = source_df
    )

    required_cols <- c(
      "country", "countryDescription", "commodity", "market_year", "analysis_month",
      "release_year", "release_month", "release_period", "normalized_metric_id", "value_canonical"
    )
    if (!all(required_cols %in% names(source_df))) {
      log_perf(
        "build_wasde_latest_market_year_rows()",
        start_time,
        details = list(metric = metric_code, requested_country = requested_country, country = requested_country, status = "missing_required_columns", rows = 0)
      )
      return(data.frame())
    }

    filtered_df <- source_df %>%
      filter(
        .data$commodity == commodity_value,
        .data$country == country_value,
        .data$normalized_metric_id == metric_id
      )

    if (nrow(filtered_df) == 0) {
      log_perf(
        "build_wasde_latest_market_year_rows()",
        start_time,
        details = list(
          metric = metric_code,
          mapped_metric_id = metric_id,
          requested_country = requested_country,
          resolved_country = country_value,
          country = country_value,
          status = "empty_filtered_source",
          rows = 0,
          source_mode = "wasde_filtered_long_frame"
        )
      )
      return(data.frame())
    }

    resolved_basis <- resolve_basis_choice(
      commodity_value,
      current_basis_choice_safe(default = default_basis_for_commodity(commodity_value, source_choice = "wasde")),
      active_tab = "Time Series Analysis Tool",
      source_choice = "wasde"
    )
    unit_choice <- current_unit_choice_safe(default = default_unit_choice_for_context("wasde", metric_code))
    value_unit_choice <- current_census_value_unit_choice_safe(
      default = input$value_unit_choice %||% default_value_unit_choice_for_context("wasde", metric_code),
      source_choice = "wasde",
      metric_code = metric_code
    )
    basis_profile <- resolve_wasde_metric_basis_profile(metric_code = metric_code, metric_id = metric_id)
    milling_lookup <- build_wasde_milling_lookup(source_df, commodity_value, country_value)

    filtered_df <- filtered_df %>%
      mutate(
        market_year = suppressWarnings(as.integer(.data$market_year)),
        value_canonical = sanitize_numeric(.data$value_canonical),
        basis_profile = basis_profile
      ) %>%
      left_join(milling_lookup, by = "market_year") %>%
      mutate(
        wasde_milling_factor = normalize_wasde_milling_factor(.data$wasde_milling_rate_value),
        wasde_milling_factor_source = dplyr::coalesce(.data$wasde_milling_factor_source, "fallback_static"),
        converted_metric_value = convert_wasde_display_values(
          values = .data$value_canonical,
          metric_code = metric_code,
          unit_choice = unit_choice,
          area_unit_choice = current_psd_area_unit_choice_safe(),
          basis_choice = resolved_basis,
          value_unit_choice = value_unit_choice,
          milling_factors = .data$wasde_milling_factor,
          basis_profile = .data$basis_profile,
          commodity_choice = commodity_value,
          active_tab = "Time Series Analysis Tool"
        )
      ) %>%
      transmute(
        country = .data$country,
        countryDescription = .data$countryDescription,
        commodity = .data$commodity,
        market_year = suppressWarnings(as.integer(.data$market_year)),
        analysis_month = suppressWarnings(as.integer(.data$analysis_month)),
        release_year = suppressWarnings(as.integer(.data$release_year)),
        release_month = suppressWarnings(as.integer(.data$release_month)),
        release_period = .data$release_period,
        !!metric_code := .data$converted_metric_value
      )

    reduced_df <- reduce_psd_latest_market_year_estimates(filtered_df, group_cols = character()) %>%
      arrange(.data$market_year)

    log_perf(
      "build_wasde_latest_market_year_rows()",
      start_time,
      details = list(
        metric = metric_code,
        mapped_metric_id = metric_id,
        requested_country = requested_country,
        resolved_country = country_value,
        country = country_value,
        rows = nrow(reduced_df),
        market_years = dplyr::n_distinct(reduced_df$market_year),
        basis_profile = basis_profile,
        fallback_factor_rows = sum(filtered_df$wasde_milling_factor_source == "fallback_static", na.rm = TRUE),
        source_mode = "wasde_filtered_long_frame"
      )
    )

    as.data.frame(reduced_df)
  }

  build_wasde_revision_pair_rows <- function(
    selected_country = input$country_choice %||% "U_S",
    selected_commodity = input$commodity_choice %||% default_commodity_choice_value(),
    metric_code = effective_main_metric(),
    value_digits = psd_time_series_summary_value_digits()
  ) {
    start_time <- Sys.time()
    requested_country_values <- trimws(as.character(selected_country %||% character(0)))
    requested_country_values <- requested_country_values[!is.na(requested_country_values) & nzchar(requested_country_values)]
    requested_country <- if (length(requested_country_values) > 0) requested_country_values[[1]] else "U_S"

    commodity_values <- trimws(as.character(selected_commodity %||% character(0)))
    commodity_values <- commodity_values[!is.na(commodity_values) & nzchar(commodity_values)]
    commodity_value <- if (length(commodity_values) > 0) commodity_values[[1]] else default_commodity_choice_value()

    source_df <- load_wasde_revision_delta()
    if (is.null(source_df) || !is.data.frame(source_df) || nrow(source_df) == 0) {
      log_perf(
        "build_wasde_revision_pair_rows()",
        start_time,
        details = list(metric = metric_code, requested_country = requested_country, country = requested_country, status = "empty_source", rows = 0)
      )
      return(data.frame())
    }

    metric_candidates <- unique(trimws(as.character(c(
      metric_code,
      map_wasde_time_series_metric_id(metric_code),
      sub("^qty_of_", "", as.character(metric_code %||% ""), perl = TRUE),
      sub("^wasde_", "", as.character(metric_code %||% ""), perl = TRUE)
    ))))
    metric_candidates <- metric_candidates[!is.na(metric_candidates) & nzchar(metric_candidates)]

    if (length(metric_candidates) == 0) {
      log_perf(
        "build_wasde_revision_pair_rows()",
        start_time,
        details = list(metric = metric_code, requested_country = requested_country, country = requested_country, status = "unsupported_metric", rows = 0)
      )
      return(data.frame())
    }

    required_cols <- c(
      "country", "countryDescription", "commodity", "market_year",
      "normalized_metric_id", "current_value_canonical", "prior_value_canonical",
      "current_release_year", "current_release_month", "current_release_period", "current_release_ord",
      "prior_release_year", "prior_release_month", "prior_release_period", "prior_release_ord",
      "prior_release_available"
    )
    if (!all(required_cols %in% names(source_df))) {
      log_perf(
        "build_wasde_revision_pair_rows()",
        start_time,
        details = list(metric = metric_code, requested_country = requested_country, country = requested_country, status = "missing_required_columns", rows = 0)
      )
      return(data.frame())
    }

    country_value <- resolve_wasde_time_series_country_code(
      requested_country = requested_country,
      source_df = source_df
    )

    filtered_df <- source_df %>%
      filter(
        .data$commodity == commodity_value,
        .data$country == country_value,
        .data$normalized_metric_id %in% metric_candidates
      )

    if (nrow(filtered_df) == 0) {
      log_perf(
        "build_wasde_revision_pair_rows()",
        start_time,
        details = list(
          metric = metric_code,
          mapped_metric_id = paste(metric_candidates, collapse = "|"),
          requested_country = requested_country,
          resolved_country = country_value,
          country = country_value,
          status = "empty_filtered_source",
          rows = 0,
          source_mode = "wasde_revision_delta_artifact"
        )
      )
      return(data.frame())
    }

    resolved_basis <- resolve_basis_choice(
      commodity_value,
      current_basis_choice_safe(default = default_basis_for_commodity(commodity_value, source_choice = "wasde")),
      active_tab = "Time Series Analysis Tool",
      source_choice = "wasde"
    )
    unit_choice <- current_unit_choice_safe(default = default_unit_choice_for_context("wasde", metric_code))
    value_unit_choice <- current_census_value_unit_choice_safe(
      default = input$value_unit_choice %||% default_value_unit_choice_for_context("wasde", metric_code),
      source_choice = "wasde",
      metric_code = metric_code
    )
    area_unit_choice <- current_psd_area_unit_choice_safe()
    basis_profile <- resolve_wasde_metric_basis_profile(
      metric_code = metric_code,
      metric_id = map_wasde_time_series_metric_id(metric_code)
    )
    milling_lookup <- build_wasde_milling_lookup(rice_data_wasde_marketing_year, commodity_value, country_value)
    fixed_value_digits <- psd_table_value_digits_for_formatter(value_digits)

    convert_wasde_revision_values <- function(values, milling_factors) {
      convert_wasde_display_values(
        values = values,
        metric_code = metric_code,
        unit_choice = unit_choice,
        area_unit_choice = area_unit_choice,
        basis_choice = resolved_basis,
        value_unit_choice = value_unit_choice,
        milling_factors = milling_factors,
        basis_profile = basis_profile,
        commodity_choice = commodity_value,
        active_tab = "Time Series Analysis Tool",
        lock_context = "mixed_row"
      )
    }

    release_period_label <- function(release_period, release_year, release_month) {
      release_period_clean <- trimws(as.character(release_period %||% ""))
      release_period_clean <- ifelse(is.na(release_period_clean), "", release_period_clean)
      fallback_label <- ifelse(
        !is.na(release_year) & !is.na(release_month),
        sprintf("%04d-%02d", suppressWarnings(as.integer(release_year)), suppressWarnings(as.integer(release_month))),
        NA_character_
      )

      ifelse(nzchar(release_period_clean), release_period_clean, fallback_label)
    }

    out <- filtered_df %>%
      mutate(
        market_year = suppressWarnings(as.integer(.data$market_year)),
        normalized_metric_id = normalize_wasde_metric_id(.data$normalized_metric_id),
        current_release_ord = suppressWarnings(as.integer(.data$current_release_ord)),
        prior_release_ord = suppressWarnings(as.integer(.data$prior_release_ord)),
        prior_release_available = dplyr::coalesce(as.logical(.data$prior_release_available), FALSE)
      ) %>%
      left_join(milling_lookup, by = "market_year") %>%
      mutate(
        wasde_basis_profile = basis_profile,
        wasde_milling_factor = normalize_wasde_milling_factor(.data$wasde_milling_rate_value),
        wasde_milling_factor_source = dplyr::coalesce(.data$wasde_milling_factor_source, "fallback_static"),
        current_value_display_numeric = convert_wasde_revision_values(.data$current_value_canonical, .data$wasde_milling_factor),
        prior_value_display_numeric = convert_wasde_revision_values(.data$prior_value_canonical, .data$wasde_milling_factor),
        revision_change_display_numeric = .data$current_value_display_numeric - .data$prior_value_display_numeric,
        revision_pct_change_display_numeric = dplyr::if_else(
          is.finite(.data$prior_value_display_numeric) & .data$prior_value_display_numeric != 0,
          (.data$revision_change_display_numeric / .data$prior_value_display_numeric) * 100,
          NA_real_
        ),
        period_label = paste0("MY ", .data$market_year),
        current_release_label = release_period_label(.data$current_release_period, .data$current_release_year, .data$current_release_month),
        prior_release_label = release_period_label(.data$prior_release_period, .data$prior_release_year, .data$prior_release_month),
        current_estimate_display = format_map_summary_value(.data$current_value_display_numeric, metric_code = metric_code, value_digits = fixed_value_digits),
        prior_wasde_display = format_map_summary_value(.data$prior_value_display_numeric, metric_code = metric_code, value_digits = fixed_value_digits),
        change_from_prior_display = format_map_summary_value(.data$revision_change_display_numeric, metric_code = metric_code, value_digits = fixed_value_digits),
        percent_change_display = format_fixed_display_value_preserve_zeros(.data$revision_pct_change_display_numeric, digits = 2L, blank_for_na = FALSE)
      ) %>%
      arrange(desc(.data$market_year), desc(.data$current_release_ord), desc(.data$prior_release_ord)) %>%
      transmute(
        period_label = .data$period_label,
        market_year = .data$market_year,
        country = .data$country,
        countryDescription = .data$countryDescription,
        commodity = .data$commodity,
        normalized_metric_id = .data$normalized_metric_id,
        current_release_label = .data$current_release_label,
        prior_release_label = .data$prior_release_label,
        prior_release_available = .data$prior_release_available,
        wasde_basis_profile = .data$wasde_basis_profile,
        wasde_milling_factor = .data$wasde_milling_factor,
        wasde_milling_factor_source = .data$wasde_milling_factor_source,
        current_estimate_display = .data$current_estimate_display,
        prior_wasde_display = .data$prior_wasde_display,
        change_from_prior_display = .data$change_from_prior_display,
        percent_change_display = .data$percent_change_display,
        current_value_display_numeric = .data$current_value_display_numeric,
        prior_value_display_numeric = .data$prior_value_display_numeric,
        revision_change_display_numeric = .data$revision_change_display_numeric,
        revision_pct_change_display_numeric = .data$revision_pct_change_display_numeric
      )

    log_perf(
      "build_wasde_revision_pair_rows()",
      start_time,
      details = list(
        metric = metric_code,
        mapped_metric_id = paste(metric_candidates, collapse = "|"),
        requested_country = requested_country,
        resolved_country = country_value,
        country = country_value,
        rows = nrow(out),
        prior_available_rows = sum(out$prior_release_available, na.rm = TRUE),
        basis_profile = basis_profile,
        fallback_factor_rows = sum(out$wasde_milling_factor_source == "fallback_static", na.rm = TRUE),
        source_mode = "wasde_revision_delta_artifact"
      )
    )

    as.data.frame(out)
  }

  build_wasde_revision_comparison_rows <- function(
    selected_country = input$country_choice %||% "U_S",
    selected_commodity = input$commodity_choice %||% default_commodity_choice_value()
  ) {
    start_time <- Sys.time()
    requested_country_values <- trimws(as.character(selected_country %||% character(0)))
    requested_country_values <- requested_country_values[!is.na(requested_country_values) & nzchar(requested_country_values)]
    requested_country <- if (length(requested_country_values) > 0) requested_country_values[[1]] else "U_S"

    commodity_values <- trimws(as.character(selected_commodity %||% character(0)))
    commodity_values <- commodity_values[!is.na(commodity_values) & nzchar(commodity_values)]
    commodity_value <- if (length(commodity_values) > 0) commodity_values[[1]] else default_commodity_choice_value()

    source_df <- load_wasde_revision_delta()
    if (is.null(source_df) || !is.data.frame(source_df) || nrow(source_df) == 0) {
      log_perf(
        "build_wasde_revision_comparison_rows()",
        start_time,
        details = list(requested_country = requested_country, country = requested_country, commodity = commodity_value, status = "empty_source", rows = 0)
      )
      return(data.frame())
    }

    required_cols <- c(
      "country", "countryDescription", "commodity", "market_year",
      "normalized_metric_id", "attribute_name", "canonical_unit",
      "current_value_canonical", "prior_value_canonical",
      "current_release_year", "current_release_month", "current_release_period", "current_release_ord",
      "prior_release_year", "prior_release_month", "prior_release_period", "prior_release_ord",
      "prior_release_available"
    )
    if (!all(required_cols %in% names(source_df))) {
      log_perf(
        "build_wasde_revision_comparison_rows()",
        start_time,
        details = list(requested_country = requested_country, country = requested_country, commodity = commodity_value, status = "missing_required_columns", rows = 0)
      )
      return(data.frame())
    }

    country_value <- resolve_wasde_time_series_country_code(
      requested_country = requested_country,
      source_df = source_df
    )

    visible_metric_ids <- unique(trimws(as.character(unname(get_metric_choices_for_context(
      active_tab = "Time Series Analysis Tool",
      source_choice = "wasde",
      data_frequency = "monthly"
    )))))
    visible_metric_ids <- visible_metric_ids[!is.na(visible_metric_ids) & nzchar(visible_metric_ids)]

    if (length(visible_metric_ids) == 0L) {
      log_perf(
        "build_wasde_revision_comparison_rows()",
        start_time,
        details = list(
          requested_country = requested_country,
          resolved_country = country_value,
          country = country_value,
          commodity = commodity_value,
          status = "empty_visible_metric_ids",
          rows = 0,
          source_mode = "wasde_revision_delta_artifact"
        )
      )
      return(data.frame())
    }

    normalize_wasde_metric_id_vector <- function(metric_values) {
      metric_values <- trimws(as.character(metric_values))
      vapply(metric_values, function(metric_value) {
        metric_id <- normalize_wasde_metric_id(metric_value)
        if (!is.null(metric_id) && length(metric_id) > 0L && !is.na(metric_id[[1L]]) && nzchar(metric_id[[1L]])) {
          return(metric_id[[1L]])
        }
        if (!is.na(metric_value) && nzchar(metric_value)) {
          return(metric_value)
        }
        NA_character_
      }, character(1), USE.NAMES = FALSE)
    }

    filtered_df <- source_df %>%
      mutate(
        market_year = suppressWarnings(as.integer(.data$market_year)),
        normalized_metric_id = normalize_wasde_metric_id_vector(.data$normalized_metric_id),
        current_release_ord = suppressWarnings(as.integer(.data$current_release_ord)),
        prior_release_ord = suppressWarnings(as.integer(.data$prior_release_ord)),
        prior_release_available = dplyr::coalesce(as.logical(.data$prior_release_available), FALSE)
      ) %>%
      filter(
        .data$commodity == commodity_value,
        .data$country == country_value,
        .data$prior_release_available
      )

    filtered_df <- filtered_df %>% filter(.data$normalized_metric_id %in% visible_metric_ids)

    filtered_df <- filtered_df %>% filter(is.finite(.data$market_year))

    if (nrow(filtered_df) == 0) {
      log_perf(
        "build_wasde_revision_comparison_rows()",
        start_time,
        details = list(
          requested_country = requested_country,
          resolved_country = country_value,
          country = country_value,
          commodity = commodity_value,
          status = "empty_filtered_source",
          visible_metric_count = length(visible_metric_ids),
          rows = 0,
          source_mode = "wasde_revision_delta_artifact"
        )
      )
      return(data.frame())
    }

    successful_min_year <- suppressWarnings(min(filtered_df$market_year, na.rm = TRUE))
    if (is.finite(successful_min_year)) {
      filtered_df <- filtered_df %>% filter(.data$market_year >= successful_min_year)
    }

    resolved_basis <- resolve_basis_choice(
      commodity_value,
      current_basis_choice_safe(default = default_basis_for_commodity(commodity_value, source_choice = "wasde")),
      active_tab = "Time Series Analysis Tool",
      source_choice = "wasde"
    )
    unit_choice <- current_unit_choice_safe(default = default_unit_choice_for_context("wasde", effective_main_metric()))
    area_unit_choice <- current_psd_area_unit_choice_safe()
    value_unit_choice <- current_census_value_unit_choice_safe(
      default = input$value_unit_choice %||% default_value_unit_choice_for_context("wasde", effective_main_metric()),
      source_choice = "wasde",
      metric_code = effective_main_metric()
    )
    comparison_value_digits <- psd_table_value_digits_for_formatter(wasde_prior_comparison_value_digits())
    milling_lookup <- build_wasde_milling_lookup(rice_data_wasde_marketing_year, commodity_value, country_value)

    release_period_label <- function(release_period, release_year, release_month) {
      release_period_clean <- trimws(as.character(release_period %||% ""))
      release_period_clean <- ifelse(is.na(release_period_clean), "", release_period_clean)
      fallback_label <- ifelse(
        !is.na(release_year) & !is.na(release_month),
        sprintf("%04d-%02d", suppressWarnings(as.integer(release_year)), suppressWarnings(as.integer(release_month))),
        NA_character_
      )

      ifelse(nzchar(release_period_clean), release_period_clean, fallback_label)
    }

    convert_wasde_comparison_values <- function(values, metric_ids, milling_factors) {
      values_num <- sanitize_numeric(values)
      metric_ids <- rep_len(as.character(metric_ids %||% character(0)), length(values_num))
      factors <- sanitize_numeric(milling_factors)
      factors <- ifelse(!is.na(factors) & is.finite(factors) & factors > 0, factors, wasde_default_milling_factor)

      converted <- vapply(seq_along(values_num), function(idx) {
        native_value <- values_num[[idx]]
        if (!is.finite(native_value)) {
          return(NA_real_)
        }

        metric_id <- normalize_wasde_metric_id(metric_ids[[idx]])
        if (is.null(metric_id) || is.na(metric_id) || !nzchar(metric_id)) {
          metric_id <- trimws(as.character(metric_ids[[idx]]))
        }

        converted_value <- convert_wasde_display_values(
          values = native_value,
          metric_code = metric_id,
          unit_choice = unit_choice,
          area_unit_choice = area_unit_choice,
          basis_choice = resolved_basis,
          value_unit_choice = value_unit_choice,
          milling_factors = factors[[idx]],
          commodity_choice = commodity_value,
          active_tab = "Time Series Analysis Tool",
          lock_context = "mixed_row"
        )

        sanitize_numeric(converted_value)[[1]]
      }, numeric(1))

      sanitize_numeric(converted)
    }

    out <- filtered_df %>%
      left_join(milling_lookup, by = "market_year") %>%
      mutate(
        wasde_milling_factor = normalize_wasde_milling_factor(.data$wasde_milling_rate_value),
        wasde_milling_factor_source = dplyr::coalesce(.data$wasde_milling_factor_source, "fallback_static"),
        attribute_label_source = {
          attribute_values <- trimws(as.character(.data$attribute_name %||% ""))
          attribute_values[is.na(attribute_values)] <- ""
          attribute_values
        },
        attribute_label = vapply(
          .data$normalized_metric_id,
          function(metric_id) {
            metric_label <- trimws(as.character(wasde_metric_label_for_code(metric_id) %||% ""))
            metric_label[is.na(metric_label)] <- ""
            metric_label[[1]]
          },
          character(1)
        ),
        attribute_label = ifelse(nzchar(.data$attribute_label), .data$attribute_label, .data$attribute_label_source),
        unit_display = mapply(
          function(metric_id, commodity_name) {
            get_measurement_label_for_commodity(
              unit = unit_choice,
              commodity_name = commodity_name,
              basis_choice = resolved_basis,
              active_tab = "Time Series Analysis Tool",
              metric_code = metric_id,
              source_choice = "wasde",
              area_unit_choice = area_unit_choice,
              value_unit_choice = value_unit_choice,
              lock_context = "mixed_row"
            )
          },
          .data$normalized_metric_id,
          .data$commodity,
          USE.NAMES = FALSE
        ),
        unit_display = {
          fallback_units <- vapply(.data$normalized_metric_id, function(metric_id) wasde_metric_unit_for_code(metric_id, default = "WASDE Unit"), character(1))
          ifelse(nzchar(trimws(as.character(.data$unit_display %||% ""))), .data$unit_display, fallback_units)
        },
        current_value_display_numeric = convert_wasde_comparison_values(
          .data$current_value_canonical,
          .data$normalized_metric_id,
          .data$wasde_milling_factor
        ),
        prior_value_display_numeric = convert_wasde_comparison_values(
          .data$prior_value_canonical,
          .data$normalized_metric_id,
          .data$wasde_milling_factor
        ),
        revision_change_display_numeric = .data$current_value_display_numeric - .data$prior_value_display_numeric,
        revision_pct_change_display_numeric = dplyr::if_else(
          is.finite(.data$prior_value_display_numeric) & .data$prior_value_display_numeric != 0,
          (.data$revision_change_display_numeric / .data$prior_value_display_numeric) * 100,
          NA_real_
        ),
        period_label = paste0("MY ", .data$market_year),
        current_release_label = release_period_label(.data$current_release_period, .data$current_release_year, .data$current_release_month),
        prior_release_label = release_period_label(.data$prior_release_period, .data$prior_release_year, .data$prior_release_month),
        current_estimate_display = mapply(
          function(value, metric_id) {
            format_map_summary_value(value, metric_code = metric_id, value_digits = comparison_value_digits)
          },
          .data$current_value_display_numeric,
          .data$normalized_metric_id,
          USE.NAMES = FALSE
        ),
        prior_wasde_display = mapply(
          function(value, metric_id) {
            format_map_summary_value(value, metric_code = metric_id, value_digits = comparison_value_digits)
          },
          .data$prior_value_display_numeric,
          .data$normalized_metric_id,
          USE.NAMES = FALSE
        ),
        change_from_prior_display = mapply(
          function(value, metric_id) {
            format_map_summary_value(value, metric_code = metric_id, value_digits = comparison_value_digits)
          },
          .data$revision_change_display_numeric,
          .data$normalized_metric_id,
          USE.NAMES = FALSE
        ),
        percent_change_display = ifelse(
          is.finite(.data$revision_pct_change_display_numeric),
          format_fixed_display_value_preserve_zeros(.data$revision_pct_change_display_numeric, digits = 2L, blank_for_na = TRUE),
          ""
        ),
        current_value_native = .data$current_value_display_numeric,
        prior_value_native = .data$prior_value_display_numeric,
        revision_change_native = .data$revision_change_display_numeric,
        revision_pct_change_native = .data$revision_pct_change_display_numeric
      ) %>%
      arrange(desc(.data$market_year), desc(.data$current_release_ord), desc(.data$prior_release_ord), .data$attribute_label) %>%
      transmute(
        period_label = .data$period_label,
        period_sort = .data$market_year,
        market_year = .data$market_year,
        country = .data$country,
        countryDescription = .data$countryDescription,
        commodity = .data$commodity,
        normalized_metric_id = .data$normalized_metric_id,
        attribute_label = .data$attribute_label,
        unit_display = .data$unit_display,
        current_estimate_display = .data$current_estimate_display,
        prior_wasde_display = .data$prior_wasde_display,
        change_from_prior_display = .data$change_from_prior_display,
        percent_change_display = .data$percent_change_display,
        current_release_label = .data$current_release_label,
        prior_release_label = .data$prior_release_label,
        prior_release_available = .data$prior_release_available,
        current_value_display_numeric = .data$current_value_display_numeric,
        prior_value_display_numeric = .data$prior_value_display_numeric,
        revision_change_display_numeric = .data$revision_change_display_numeric,
        revision_pct_change_display_numeric = .data$revision_pct_change_display_numeric,
        current_value_native = .data$current_value_native,
        prior_value_native = .data$prior_value_native,
        revision_change_native = .data$revision_change_native,
        revision_pct_change_native = .data$revision_pct_change_native
      )

    log_perf(
      "build_wasde_revision_comparison_rows()",
      start_time,
      details = list(
        requested_country = requested_country,
        resolved_country = country_value,
        country = country_value,
        commodity = commodity_value,
        rows = nrow(out),
        min_successful_market_year = successful_min_year,
        attribute_count = dplyr::n_distinct(out$normalized_metric_id),
        source_mode = "wasde_revision_delta_artifact"
      )
    )

    as.data.frame(out)
  }

  build_time_series_latest_market_year_rows <- function(
    selected_country = input$country_choice %||% "GRAND_TOTAL",
    selected_commodity = input$commodity_choice %||% default_commodity_choice_value(),
    metric_code = effective_main_metric(),
    source_choice = current_source_choice_safe()
  ) {
    if (identical(source_choice, "psd")) {
      return(build_psd_latest_market_year_rows(selected_country = selected_country, selected_commodity = selected_commodity, metric_code = metric_code))
    }

    if (identical(source_choice, "wasde")) {
      return(build_wasde_latest_market_year_rows(selected_country = selected_country, selected_commodity = selected_commodity, metric_code = metric_code))
    }

    if (identical(source_choice, "nass")) {
      nass_row_builder_start_time <- Sys.time()
      source_df <- tryCatch(
        base_data_converted(),
        error = function(...) tryCatch(rice_data_nass_annual, error = function(...) NULL)
      )
      metric_id <- trimws(as.character(metric_code %||% ""))
      metric_id <- metric_id[!is.na(metric_id) & nzchar(metric_id)]
      metric_id <- if (length(metric_id) > 0L) metric_id[[1L]] else default_metric_for_source("nass")
      metric_route <- if (exists("nass_metric_route_for_code", mode = "function")) {
        nass_metric_route_for_code(metric_id)
      } else {
        list(metric_id = nass_metric_row_id_for_code(metric_id), metric_source_ids = character(0), collapse_by_year = FALSE)
      }
      metric_row_id <- trimws(as.character(metric_route$metric_id %||% ""))
      metric_source_ids <- trimws(as.character(metric_route$metric_source_ids %||% character(0)))
      metric_source_ids <- metric_source_ids[!is.na(metric_source_ids) & nzchar(metric_source_ids)]
      country_value <- trimws(as.character(selected_country %||% "US"))
      country_value <- country_value[!is.na(country_value) & nzchar(country_value)]
      country_value <- if (length(country_value) > 0L) country_value[[1L]] else "US"
      commodity_value <- trimws(as.character(selected_commodity %||% default_commodity_choice_value()))
      commodity_value <- commodity_value[!is.na(commodity_value) & nzchar(commodity_value)]
      commodity_value <- if (length(commodity_value) > 0L) commodity_value[[1L]] else default_commodity_choice_value()
      metric_value_col <- if (metric_id %in% names(source_df)) metric_id else if ("value_canonical" %in% names(source_df)) "value_canonical" else NA_character_
      annual_year_type_value <- current_nass_annual_year_type_safe(metric_code = metric_id)

      if (!is.data.frame(source_df) || nrow(source_df) == 0 || is.na(metric_value_col) || !nzchar(metric_row_id)) {
        return(data.frame())
      }

      required_cols <- c("country", "commodity", "annual_year_type", "metric_id", "market_year", "calendar_year", "analysis_month")
      if (!all(required_cols %in% names(source_df))) {
        return(data.frame())
      }

      metric_row_mask <- if (exists("nass_metric_route_row_mask", mode = "function")) {
        nass_metric_route_row_mask(source_df, metric_id, collapse = TRUE)
      } else {
        !is.na(source_df$metric_id) & source_df$metric_id == metric_row_id
      }

      if (length(metric_row_mask) != nrow(source_df)) {
        metric_row_mask <- rep(FALSE, nrow(source_df))
      }

      select_latest_nass_rows_by_year <- function(rows_df) {
        if (!is.data.frame(rows_df)) {
          return(data.frame())
        }

        if (!("market_year" %in% names(rows_df))) rows_df$market_year <- NA_integer_
        if (!("calendar_year" %in% names(rows_df))) rows_df$calendar_year <- NA_integer_
        if (!("release_year" %in% names(rows_df))) rows_df$release_year <- NA_integer_
        if (!("release_month" %in% names(rows_df))) rows_df$release_month <- NA_integer_
        if (!("analysis_month" %in% names(rows_df))) rows_df$analysis_month <- NA_integer_

        rows_df %>%
          mutate(
            market_year_num = suppressWarnings(as.integer(.data$market_year)),
            calendar_year_num = suppressWarnings(as.integer(.data$calendar_year)),
            release_year_num = suppressWarnings(as.integer(.data$release_year)),
            release_month_num = suppressWarnings(as.integer(.data$release_month)),
            analysis_month_num = suppressWarnings(as.integer(.data$analysis_month)),
            period_year = dplyr::if_else(is.na(.data$market_year_num), .data$calendar_year_num, .data$market_year_num)
          ) %>%
          filter(!is.na(.data$period_year)) %>%
          arrange(
            dplyr::desc(.data$release_year_num),
            dplyr::desc(.data$release_month_num),
            dplyr::desc(.data$analysis_month_num),
            dplyr::desc(.data$calendar_year_num),
            dplyr::desc(.data$market_year_num)
          ) %>%
          group_by(.data$period_year) %>%
          dplyr::slice_head(n = 1) %>%
          ungroup()
      }

      build_nass_out_from_rows <- function(rows_df) {
        if (!is.data.frame(rows_df) || nrow(rows_df) == 0L) {
          return(data.frame())
        }

        market_year_values <- suppressWarnings(as.integer(rows_df$market_year))
        calendar_year_values <- suppressWarnings(as.integer(rows_df$calendar_year))
        period_year_values <- dplyr::if_else(is.na(market_year_values), calendar_year_values, market_year_values)
        out_df <- data.frame(
          source = rep("nass", nrow(rows_df)),
          commodity = rows_df$commodity,
          country = rows_df$country,
          countryDescription = if ("countryDescription" %in% names(rows_df)) rows_df$countryDescription else rows_df$country,
          market_year = period_year_values,
          calendar_year = calendar_year_values,
          analysis_month = suppressWarnings(as.integer(rows_df$analysis_month)),
          annual_year_type = rows_df$annual_year_type,
          reference_period_desc = if ("reference_period_desc" %in% names(rows_df)) rows_df$reference_period_desc else NA_character_,
          stringsAsFactors = FALSE
        )
        out_df[[metric_id]] <- sanitize_numeric(rows_df[[metric_value_col]])
        out_df <- out_df[!is.na(out_df$market_year), , drop = FALSE]
        out_df
      }

      row_index <- !is.na(source_df$country) & source_df$country == country_value &
        !is.na(source_df$commodity) & source_df$commodity == commodity_value &
        !is.na(source_df$annual_year_type) & source_df$annual_year_type == annual_year_type_value &
        metric_row_mask
      rows <- source_df[row_index, , drop = FALSE]

      apply_us_fallback <- identical(country_value, "US") && metric_id %in% c("nass_yield", "nass_yield_may_estimate")
      unresolved_fallback_years <- integer(0)
      fallback_applied <- FALSE
      fallback_filled_year_count <- 0L

      if (isTRUE(apply_us_fallback)) {
        rows_selected <- select_latest_nass_rows_by_year(rows)

        fallback_index <- !is.na(source_df$country) & source_df$country == "CA" &
          !is.na(source_df$commodity) & source_df$commodity == commodity_value &
          !is.na(source_df$annual_year_type) & source_df$annual_year_type == annual_year_type_value &
          metric_row_mask
        rows_fallback <- select_latest_nass_rows_by_year(source_df[fallback_index, , drop = FALSE])

        selected_summary <- rows_selected %>%
          transmute(
            period_year = suppressWarnings(as.integer(.data$period_year)),
            selected_value = sanitize_numeric(.data[[metric_value_col]]),
            selected_calendar_year = suppressWarnings(as.integer(.data$calendar_year_num)),
            selected_analysis_month = suppressWarnings(as.integer(.data$analysis_month_num)),
            selected_reference_period_desc = if ("reference_period_desc" %in% names(rows_selected)) as.character(.data$reference_period_desc) else NA_character_,
            selected_country_description = if ("countryDescription" %in% names(rows_selected)) as.character(.data$countryDescription) else NA_character_
          )

        fallback_summary <- rows_fallback %>%
          transmute(
            period_year = suppressWarnings(as.integer(.data$period_year)),
            fallback_value = sanitize_numeric(.data[[metric_value_col]]),
            fallback_calendar_year = suppressWarnings(as.integer(.data$calendar_year_num)),
            fallback_analysis_month = suppressWarnings(as.integer(.data$analysis_month_num)),
            fallback_reference_period_desc = if ("reference_period_desc" %in% names(rows_fallback)) as.character(.data$reference_period_desc) else NA_character_,
            fallback_country_description = if ("countryDescription" %in% names(rows_fallback)) as.character(.data$countryDescription) else NA_character_
          )

        merged_summary <- dplyr::full_join(selected_summary, fallback_summary, by = "period_year") %>%
          mutate(
            selected_present = is.finite(.data$selected_value),
            fallback_present = is.finite(.data$fallback_value),
            chosen_value = dplyr::coalesce(
              ifelse(.data$selected_present, .data$selected_value, NA_real_),
              ifelse(!.data$selected_present & .data$fallback_present, .data$fallback_value, NA_real_)
            ),
            chosen_calendar_year = dplyr::coalesce(
              ifelse(.data$selected_present, .data$selected_calendar_year, NA_integer_),
              ifelse(!.data$selected_present & .data$fallback_present, .data$fallback_calendar_year, NA_integer_)
            ),
            chosen_analysis_month = dplyr::coalesce(
              ifelse(.data$selected_present, .data$selected_analysis_month, NA_integer_),
              ifelse(!.data$selected_present & .data$fallback_present, .data$fallback_analysis_month, NA_integer_)
            ),
            chosen_reference_period_desc = dplyr::coalesce(
              ifelse(.data$selected_present, .data$selected_reference_period_desc, NA_character_),
              ifelse(!.data$selected_present & .data$fallback_present, .data$fallback_reference_period_desc, NA_character_)
            ),
            chosen_country_description = dplyr::coalesce(
              ifelse(.data$selected_present, .data$selected_country_description, NA_character_),
              ifelse(!.data$selected_present & .data$fallback_present, .data$fallback_country_description, NA_character_)
            )
          ) %>%
          arrange(.data$period_year)

        unresolved_fallback_years <- merged_summary$period_year[!merged_summary$selected_present & !merged_summary$fallback_present]
        unresolved_fallback_years <- sort(unique(suppressWarnings(as.integer(unresolved_fallback_years[is.finite(unresolved_fallback_years)]))))
        fallback_filled_year_count <- sum(!merged_summary$selected_present & merged_summary$fallback_present, na.rm = TRUE)
        fallback_applied <- nrow(merged_summary) > 0L

        rows <- data.frame(
          source = rep("nass", nrow(merged_summary)),
          commodity = rep(commodity_value, nrow(merged_summary)),
          country = rep(country_value, nrow(merged_summary)),
          countryDescription = dplyr::coalesce(merged_summary$chosen_country_description, rep(country_value, nrow(merged_summary))),
          market_year = merged_summary$period_year,
          calendar_year = merged_summary$chosen_calendar_year,
          analysis_month = merged_summary$chosen_analysis_month,
          annual_year_type = rep(annual_year_type_value, nrow(merged_summary)),
          reference_period_desc = merged_summary$chosen_reference_period_desc,
          stringsAsFactors = FALSE
        )
        rows[[metric_id]] <- sanitize_numeric(merged_summary$chosen_value)
      }

      if (nrow(rows) == 0L) {
        log_perf(
          "build_time_series_latest_market_year_rows(nass)",
          nass_row_builder_start_time,
          details = list(
            source_rows = nrow(source_df),
            matched_rows = 0L,
            out_rows = 0L,
            country = country_value,
            commodity = commodity_value,
            annual_year_type = annual_year_type_value,
            metric = metric_id,
            metric_route_id = metric_row_id,
            metric_route_sources = if (length(metric_source_ids) > 0L) paste(metric_source_ids, collapse = "|") else "<metric_only>",
            metric_value_col = metric_value_col,
            fallback_applied = fallback_applied,
            fallback_filled_years = fallback_filled_year_count,
            unresolved_fallback_years = if (length(unresolved_fallback_years) > 0L) paste(unresolved_fallback_years, collapse = "|") else ""
          )
        )
        return(data.frame())
      }

      out <- if (isTRUE(apply_us_fallback)) {
        rows[!is.na(rows$market_year), , drop = FALSE]
      } else {
        build_nass_out_from_rows(rows)
      }
      log_perf(
        "build_time_series_latest_market_year_rows(nass)",
        nass_row_builder_start_time,
        details = list(
          source_rows = nrow(source_df),
          matched_rows = nrow(rows),
          period_non_na = sum(!is.na(out$market_year)),
          value_non_na = sum(!is.na(out[[metric_id]])),
          out_rows = nrow(out),
          country = country_value,
          commodity = commodity_value,
          annual_year_type = annual_year_type_value,
          metric = metric_id,
          metric_route_id = metric_row_id,
          metric_route_sources = if (length(metric_source_ids) > 0L) paste(metric_source_ids, collapse = "|") else "<metric_only>",
          metric_value_col = metric_value_col,
          fallback_applied = fallback_applied,
          fallback_filled_years = fallback_filled_year_count,
          unresolved_fallback_years = if (length(unresolved_fallback_years) > 0L) paste(unresolved_fallback_years, collapse = "|") else ""
        )
      )
      attr(out, "nass_fallback_unresolved_years") <- unresolved_fallback_years
      attr(out, "nass_fallback_applied") <- isTRUE(fallback_applied)
      attr(out, "nass_fallback_filled_year_count") <- as.integer(fallback_filled_year_count)
      return(out[order(out$market_year), , drop = FALSE])
    }

    data.frame()
  }

  psd_time_series_annual_bundle_from_rows <- function(annual_rows, metric_col, selected_country, selected_commodity, source_choice = current_source_choice_safe()) {
    if (!is.data.frame(annual_rows) || nrow(annual_rows) == 0 || !(metric_col %in% names(annual_rows))) {
      return(list(status = "empty", metric_col = metric_col))
    }

      is_effectively_flat_psd_series <- function(values) {
        numeric_values <- suppressWarnings(as.numeric(values))
        numeric_values <- numeric_values[is.finite(numeric_values)]

        if (length(numeric_values) < 2) {
          return(FALSE)
        }

        series_span <- diff(range(numeric_values, na.rm = TRUE))
        reference_scale <- max(abs(numeric_values), na.rm = TRUE)
        tolerance <- max(1e-9, reference_scale * 1e-9)

        is.finite(series_span) && series_span <= tolerance
      }

    resolve_nass_period_month <- function(analysis_month, reference_period_desc) {
      month <- suppressWarnings(as.integer(analysis_month))
      reference_text <- toupper(trimws(as.character(reference_period_desc %||% "")))

      derived_month <- rep(NA_integer_, length(reference_text))
      for (idx in seq_along(month.abb)) {
        month_pattern <- toupper(month.abb[[idx]])
        month_name_pattern <- toupper(month.name[[idx]])
        matched <- grepl(month_pattern, reference_text, fixed = TRUE) | grepl(month_name_pattern, reference_text, fixed = TRUE)
        derived_month[matched] <- idx
      }

      ifelse(!is.na(month) & month >= 1L & month <= 12L, month, derived_month)
    }

    if (!("analysis_month" %in% names(annual_rows))) {
      annual_rows$analysis_month <- NA_integer_
    }
    if (!("reference_period_desc" %in% names(annual_rows))) {
      annual_rows$reference_period_desc <- NA_character_
    }
    if (!("annual_year_type" %in% names(annual_rows))) {
      annual_rows$annual_year_type <- NA_character_
    }

    plot_df <- annual_rows %>%
      transmute(
        market_year = suppressWarnings(as.integer(.data$market_year)),
        annual_year_type = trimws(as.character(.data$annual_year_type)),
        analysis_month = suppressWarnings(as.integer(.data$analysis_month)),
        reference_period_desc = trimws(as.character(.data$reference_period_desc)),
        period_month = if (identical(source_choice, "nass")) resolve_nass_period_month(.data$analysis_month, .data$reference_period_desc) else NA_integer_,
        is_forecast_period = identical(source_choice, "nass") & (
          tolower(.data$annual_year_type) == "forecast" |
            grepl("FORECAST", toupper(.data$reference_period_desc), fixed = TRUE)
        ),
        period_index = dplyr::if_else(
          .data$is_forecast_period & !is.na(.data$period_month),
          suppressWarnings(as.numeric(.data$market_year)) + (.data$period_month - 1) / 12,
          suppressWarnings(as.numeric(.data$market_year))
        ),
        period_label = dplyr::case_when(
          identical(source_choice, "nass") & .data$is_forecast_period & !is.na(.data$period_month) & tolower(.data$annual_year_type) == "marketing_year" ~ paste0("MY ", .data$market_year, " ", month.abb[.data$period_month]),
          identical(source_choice, "nass") & .data$is_forecast_period & !is.na(.data$period_month) ~ paste0(.data$market_year, " ", month.abb[.data$period_month]),
          identical(source_choice, "nass") & tolower(.data$annual_year_type) == "calendar_year" ~ paste0("CY ", .data$market_year),
          TRUE ~ paste0("MY ", .data$market_year)
        ),
        current_value = psd_display_numeric_value(
          suppressWarnings(as.numeric(.data[[metric_col]])),
          metric_code = metric_col
        )
      ) %>%
      filter(!is.na(.data$market_year), !is.na(.data$period_index), !is.na(.data$current_value)) %>%
      arrange(.data$period_index)

    if (nrow(plot_df) == 0) {
      return(list(status = "empty", metric_col = metric_col))
    }

    fit_df <- plot_df %>%
      filter(is.finite(.data$period_index), is.finite(.data$current_value))
    series_is_effectively_flat <- is_effectively_flat_psd_series(fit_df$current_value)

    fit_available <- FALSE
    fitted_df <- plot_df %>% transmute(period_index = .data$period_index, fitted_value = NA_real_)
    note_parts <- character(0)
    trendline_label <- "OLS Trendline"
    trendline_equation_text <- NULL

    if (nrow(fit_df) < 2 || dplyr::n_distinct(fit_df$period_index) < 2) {
      note_parts <- c(note_parts, "OLS trendline unavailable for the current selection because fewer than two annual observations are available.")
    } else if (isTRUE(series_is_effectively_flat)) {
      note_parts <- c(note_parts, "OLS trendline suppressed because the annual series is effectively flat.")
    } else {
      ols_fit <- tryCatch(
        stats::lm(current_value ~ period_index, data = fit_df),
        error = function(e) e
      )

      if (inherits(ols_fit, "error")) {
        note_parts <- c(note_parts, "OLS trendline unavailable for the current selection because the regression could not be estimated cleanly.")
      } else {
        fit_available <- TRUE
        fitted_df <- fit_df %>%
          transmute(
            period_index = .data$period_index,
            fitted_value = suppressWarnings(as.numeric(stats::fitted(ols_fit)))
          )

        coefficients <- tryCatch(stats::coef(ols_fit), error = function(e) c(`(Intercept)` = NA_real_, period_index = NA_real_))
        intercept_value <- suppressWarnings(as.numeric(coefficients[["(Intercept)"]] %||% NA_real_))
        slope_value <- suppressWarnings(as.numeric(coefficients[["period_index"]] %||% NA_real_))

        if (is.finite(intercept_value) && is.finite(slope_value)) {
          intercept_abs <- abs(intercept_value)
          intercept_sign <- if (intercept_value >= 0) "+" else "-"
          trendline_equation_text <- sprintf(
            "OLS Trendline Equation: y = %.2f*Market Year %s %.2f",
            slope_value,
            intercept_sign,
            intercept_abs
          )
        }
      }
    }

    plot_df <- plot_df %>%
      left_join(fitted_df, by = "period_index") %>%
      mutate(
        diff_from_trend = .data$current_value - .data$fitted_value,
        pct_diff_from_trend = dplyr::if_else(
          is.finite(.data$fitted_value) & .data$fitted_value != 0,
          (.data$diff_from_trend / .data$fitted_value) * 100,
          NA_real_
        )
      )

    metric_label <- get_metric_label_for_context(metric_col, source_choice = source_choice)
    safe_basis_choice <- if (identical(source_choice, "psd")) {
      current_psd_time_series_basis_choice_safe(metric_col, selected_commodity)
    } else {
      resolve_basis_choice(
        selected_commodity,
        current_basis_choice_safe(default = default_basis_for_commodity(selected_commodity, source_choice = source_choice)),
        active_tab = "Time Series Analysis Tool",
        source_choice = source_choice
      )
    }
    resolved_metric_basis <- safe_basis_choice
    unit_label <- get_measurement_label_for_commodity(
      unit = input$unit_choice %||% "thousand_mt",
      commodity_name = selected_commodity,
      basis_choice = resolved_metric_basis,
      active_tab = "Time Series Analysis Tool",
      metric_code = metric_col,
      source_choice = source_choice,
      area_unit_choice = current_psd_area_unit_choice_safe()
    )

    normalized_selected_country <- gsub("[^A-Z0-9]", "", toupper(as.character(selected_country %||% "")))
    title_country <- if (identical(source_choice, "nass")) {
      nass_state_label_for_code(selected_country, default = selected_country)
    } else if (identical(selected_country, "GRAND_TOTAL")) {
      "World"
    } else if (normalized_selected_country %in% c("US", "USA", "UNITEDSTATES")) {
      "United States"
    } else {
      get_display_country(selected_country)
    }
    title_commodity <- get_commodity_display_label(selected_commodity, safe_basis_choice)

    list(
      status = "ok",
      source_choice = source_choice,
      annual_value_scale_contract = "display_preconverted_in_bundle",
      metric_col = metric_col,
      metric_label = metric_label,
      unit_label = unit_label,
      selected_country = selected_country,
      selected_commodity = selected_commodity,
      base_title = paste(metric_label, title_country, title_commodity, sep = " - "),
      plot_df = plot_df,
      table_df = plot_df %>% arrange(desc(.data$period_index)),
      fit_available = fit_available,
      trendline_label = trendline_label,
      trendline_equation_text = trendline_equation_text,
      note_text = if (length(note_parts) > 0) paste(note_parts, collapse = " ") else NULL
    )
  }

  format_time_series_annual_display_value <- function(
    value,
    metric_code = NULL,
    source_choice = current_source_choice_safe(),
    min_significant_digits = 3L,
    value_digits = NULL
  ) {
    fixed_value_digits <- psd_table_value_digits_for_formatter(value_digits)
    numeric_value <- suppressWarnings(as.numeric(value))

    if (!is.null(fixed_value_digits)) {
      return(format_fixed_display_value_preserve_zeros(
        numeric_value,
        digits = fixed_value_digits,
        blank_for_na = FALSE
      ))
    }

    if (is_psd_milling_rate_metric(metric_code %||% NULL)) {
      return(format_fixed_display_value_preserve_zeros(
        numeric_value,
        digits = 2L,
        blank_for_na = FALSE
      ))
    }

    if (is_psd_yield_metric(metric_code %||% NULL)) {
      return(format_fixed_display_value(
        numeric_value,
        digits = 2L,
        blank_for_na = FALSE
      ))
    }

    if (identical(source_choice, "wasde") && identical(wasde_metric_family_for_code(metric_code %||% NULL), "percent")) {
      return(format_fixed_display_value_preserve_zeros(
        numeric_value,
        digits = 2L,
        blank_for_na = FALSE
      ))
    }

    format_significant_display_value(
      numeric_value,
      min_significant_digits = min_significant_digits,
      blank_for_na = FALSE
    )
  }

  build_time_series_annual_summary_rows <- function(
    bundle,
    value_digits = psd_time_series_summary_value_digits()
  ) {
    if (
      !is.list(bundle) ||
      !identical(bundle$status, "ok") ||
      is.null(bundle$table_df) ||
      !is.data.frame(bundle$table_df) ||
      nrow(bundle$table_df) == 0
    ) {
      return(data.frame())
    }

    source_choice <- bundle$source_choice %||% current_source_choice_safe()
    value_digits_fixed <- psd_table_value_digits_for_formatter(value_digits)

    summary_table <- bundle$table_df %>%
      transmute(
        "Period" = .data$period_label,
        "Unit" = bundle$unit_label,
        "Value" = format_time_series_annual_display_value(
          .data$current_value,
          metric_code = bundle$metric_col,
          source_choice = source_choice,
          value_digits = value_digits_fixed
        ),
        "Trendline Estimate" = format_time_series_annual_display_value(
          .data$fitted_value,
          metric_code = bundle$metric_col,
          source_choice = source_choice,
          value_digits = value_digits_fixed
        ),
        "Difference" = format_time_series_annual_display_value(
          .data$diff_from_trend,
          metric_code = bundle$metric_col,
          source_choice = source_choice,
          value_digits = value_digits_fixed
        ),
        "% Difference" = format_fixed_display_value_preserve_zeros(
          .data$pct_diff_from_trend,
          digits = 2L,
          blank_for_na = FALSE
        )
      )

    if (identical(source_choice, "wasde")) {
      summary_table$`Unit/Basis` <- bundle$unit_label
    }

    as.data.frame(summary_table, stringsAsFactors = FALSE)
  }

  psd_time_series_annual_bundle <- reactive({
    start_time <- Sys.time()
    source_choice <- current_source_choice_safe()
    if (!is_time_series_source_active(source_choice = source_choice, active_tab = current_main_tab_safe())) {
      log_perf(
        "psd_time_series_annual_bundle()",
        start_time,
        details = list(status = "unavailable", source = source_choice)
      )
      return(list(status = "unavailable"))
    }

    # current_psd_active_country() intentionally isolates sidebar reads; depend on this input for country-only drill-through.
    input$country_choice
    metric_col <- effective_main_metric()
    selected_country <- if (identical(source_choice, "psd")) {
      current_psd_active_country()
    } else if (identical(source_choice, "nass")) {
      current_nass_state_choice_safe()
    } else {
      country_values <- trimws(as.character(input$country_choice %||% character(0)))
      country_values <- country_values[!is.na(country_values) & nzchar(country_values)]
      requested_country <- if (length(country_values) > 0) country_values[[1]] else "U_S"
      resolve_wasde_time_series_country_code(requested_country = requested_country)
    }
    selected_commodity <- if (identical(source_choice, "nass")) {
      default_commodity_choice_value()
    } else {
      input$commodity_choice %||% default_commodity_choice_value()
    }
    annual_rows <- build_time_series_latest_market_year_rows(
      selected_country = selected_country,
      selected_commodity = selected_commodity,
      metric_code = metric_col,
      source_choice = source_choice
    )

    bundle <- psd_time_series_annual_bundle_from_rows(
      annual_rows = annual_rows,
      metric_col = metric_col,
      selected_country = selected_country,
      selected_commodity = selected_commodity,
      source_choice = source_choice
    )

    log_perf(
      "psd_time_series_annual_bundle()",
      start_time,
      details = list(
        status = bundle$status %||% "unknown",
        source = source_choice,
        metric = metric_col,
        country = selected_country,
        rows = if (!is.null(bundle$plot_df) && is.data.frame(bundle$plot_df)) nrow(bundle$plot_df) else 0
      )
    )

    bundle
  })

  output$psd_time_series_note_block <- renderUI({
    bundle <- psd_time_series_annual_bundle()

    if (!identical(bundle$status, "ok")) {
      return(NULL)
    }

    note_parts <- character(0)
    if (!is.null(bundle$trendline_equation_text) && nzchar(bundle$trendline_equation_text)) {
      note_parts <- c(note_parts, bundle$trendline_equation_text)
    }
    if (!is.null(bundle$note_text) && nzchar(bundle$note_text)) {
      note_parts <- c(note_parts, bundle$note_text)
    }

    if (identical(bundle$source_choice, "nass") && identical(bundle$metric_col, "nass_yield_may_estimate")) {
      note_parts <- c(
        note_parts,
        "Note: The May estimate revises the prior reported year (for example, May 2026 updates 2025); it is not a forecast. It is published in in-shell equivalents."
      )
    }

    if (identical(bundle$source_choice, "nass") && identical(bundle$metric_col, "nass_shellout_factor")) {
      note_parts <- c(
        note_parts,
        "Note: Shell-Out Factor is calculated from NASS production descriptors. For 2012-2017, ALMONDS, UTILIZED, SHELLED - PRODUCTION, MEASURED IN LB is divided by ALMONDS, UTILIZED, SHELLED - PRODUCTION, MEASURED IN TONS, IN SHELL BASIS multiplied by 2000. For 2018 onward, ALMONDS, SHELLED - PRODUCTION, MEASURED IN LB (fallback: ALMONDS, UTILIZED, SHELLED - PRODUCTION, MEASURED IN LB) is divided by ALMONDS, IN SHELL - PRODUCTION, MEASURED IN LB."
      )
    }

    if (length(note_parts) == 0) {
      return(NULL)
    }

    if (identical(bundle$source_choice, "nass")) {
      return(
        tags$div(
          style = "margin: 10px 0 0 0;",
          tags$strong("Notes"),
          tags$p(
            style = "margin: 4px 0 0 0;",
            tags$em(paste(note_parts, collapse = " "))
          )
        )
      )
    }

    tags$p(
      style = "margin: 10px 0 0 0;",
      tags$em(paste(note_parts, collapse = " "))
    )
  })

  resolve_time_series_historical_metric_code <- function(
    metric_code = effective_main_metric(),
    source_choice = current_source_choice_safe()
  ) {
    if (identical(source_choice, "wasde")) {
      return(map_wasde_historical_metric_code(metric_code))
    }

    metric_code
  }

  time_series_historical_default_window <- function(source_choice = current_source_choice_safe()) {
    if (identical(source_choice, "wasde")) {
      return("10")
    }

    if (identical(source_choice, "nass")) {
      return("5")
    }

    "record"
  }

  time_series_historical_bottom_view <- function(default = "summary") {
    bottom_view <- tryCatch(input$psd_time_series_bottom_view, error = function(...) NULL)
    bottom_view <- as.character(bottom_view %||% default)
    bottom_view <- bottom_view[!is.na(bottom_view) & nzchar(bottom_view)]
    if (length(bottom_view) == 0L) default else bottom_view[[1L]]
  }

  time_series_historical_selected_commodity <- function(selected_commodity = input$commodity_choice %||% default_commodity_choice_value()) {
    commodity_values <- trimws(as.character(selected_commodity %||% character(0)))
    commodity_values <- commodity_values[!is.na(commodity_values) & nzchar(commodity_values)]
    if (length(commodity_values) > 0L) commodity_values[[1L]] else default_commodity_choice_value()
  }

  resolve_time_series_historical_selected_year <- function(
    records,
    source_choice = current_source_choice_safe(default = input$data_source_choice %||% NULL),
    selected_commodity = input$commodity_choice %||% default_commodity_choice_value(),
    selected_metric_code = resolve_time_series_historical_metric_code(effective_main_metric(), source_choice = source_choice)
  ) {
    if (!is.data.frame(records) || nrow(records) == 0) {
      return(NA_integer_)
    }

    if (identical(source_choice, "wasde") && "commodity" %in% names(records)) {
      commodity_value <- time_series_historical_selected_commodity(selected_commodity)
      records <- records %>% filter(.data$commodity == .env$commodity_value)
      if (!is.data.frame(records) || nrow(records) == 0) {
        return(NA_integer_)
      }
    }

    if (identical(source_choice, "nass")) {
      if ("country" %in% names(records)) {
        records <- records %>% filter(.data$country == "US")
      }
      if (!is.data.frame(records) || nrow(records) == 0) {
        return(NA_integer_)
      }
    }

    available_years <- suppressWarnings(as.integer(records$market_year))
    available_years <- available_years[is.finite(available_years)]

    if (length(available_years) == 0) {
      return(NA_integer_)
    }

    latest_year <- suppressWarnings(max(available_years, na.rm = TRUE))
    if (identical(source_choice, "wasde")) {
      return(latest_year)
    }

    selected_year <- suppressWarnings(as.integer(input$psd_historical_records_year %||% NA_integer_))
    if (is.na(selected_year) || !(selected_year %in% available_years)) {
      return(latest_year)
    }

    selected_year
  }

  time_series_historical_selected_year <- reactive({
    source_choice <- current_source_choice_safe()
    records <- if (identical(source_choice, "wasde")) {
      load_wasde_historical_records()
    } else if (identical(source_choice, "nass")) {
      load_nass_historical_records()
    } else {
      load_psd_historical_records()
    }

    resolve_time_series_historical_selected_year(
      records = records,
      source_choice = source_choice,
      selected_commodity = if (identical(source_choice, "wasde")) time_series_historical_selected_commodity() else NULL,
      selected_metric_code = resolve_time_series_historical_metric_code(effective_main_metric(), source_choice = source_choice)
    )
  })

  historical_records_priority_scope_for_source <- function(source_choice = current_source_choice_safe(default = NULL)) {
    source_choice <- as.character(source_choice %||% character(0))
    source_choice <- source_choice[!is.na(source_choice) & nzchar(source_choice)]
    source_choice <- if (length(source_choice) > 0L) source_choice[[1L]] else NULL

    if (identical(source_choice, "psd")) return("psd")
    if (identical(source_choice, "wasde")) return("wasde")
    if (identical(source_choice, "nass")) return("nass")
    "non_time_series"
  }

  historical_records_priority_state_key <- function(scope = historical_records_priority_scope_for_source()) {
    paste0("psd_historical_records_prioritize_metric_state_", scope)
  }

  read_remembered_historical_records_priority <- function(scope = historical_records_priority_scope_for_source(), default = FALSE) {
    remembered_value <- session$userData[[historical_records_priority_state_key(scope)]]
    if (is.null(remembered_value) || length(remembered_value) == 0L) return(isTRUE(default))
    isTRUE(remembered_value)
  }

  write_remembered_historical_records_priority <- function(value, scope = historical_records_priority_scope_for_source()) {
    session$userData[[historical_records_priority_state_key(scope)]] <- isTRUE(value)
    invisible(isTRUE(value))
  }

  historical_records_selected_country_state_key <- function(scope = historical_records_priority_scope_for_source()) {
    paste0("psd_historical_records_selected_country_state_", scope)
  }

  historical_records_selected_year_state_key <- function(scope = historical_records_priority_scope_for_source()) {
    paste0("psd_historical_records_selected_year_state_", scope)
  }

  read_remembered_historical_records_selected_country <- function(scope = historical_records_priority_scope_for_source(), default = FALSE) {
    remembered_value <- session$userData[[historical_records_selected_country_state_key(scope)]]
    if (is.null(remembered_value) || length(remembered_value) == 0L) return(isTRUE(default))
    isTRUE(remembered_value)
  }

  write_remembered_historical_records_selected_country <- function(value, scope = historical_records_priority_scope_for_source()) {
    session$userData[[historical_records_selected_country_state_key(scope)]] <- isTRUE(value)
    invisible(isTRUE(value))
  }

  read_remembered_historical_records_selected_year <- function(scope = historical_records_priority_scope_for_source(), default = FALSE) {
    remembered_value <- session$userData[[historical_records_selected_year_state_key(scope)]]
    if (is.null(remembered_value) || length(remembered_value) == 0L) return(isTRUE(default))
    isTRUE(remembered_value)
  }

  write_remembered_historical_records_selected_year <- function(value, scope = historical_records_priority_scope_for_source()) {
    session$userData[[historical_records_selected_year_state_key(scope)]] <- isTRUE(value)
    invisible(isTRUE(value))
  }

  historical_records_reset_epoch <- reactiveVal(0L)

  mark_historical_records_reset_epoch <- function() {
    historical_records_reset_epoch(isolate(historical_records_reset_epoch()) + 1L)
    invisible(historical_records_reset_epoch())
  }

  mark_pending_historical_records_priority_update <- function(value, scope = historical_records_priority_scope_for_source()) {
    session$userData$pending_historical_records_priority_update <- list(
      value = isTRUE(value),
      scope = scope
    )
    invisible(isTRUE(value))
  }

  read_pending_historical_records_priority_update <- function() {
    session$userData$pending_historical_records_priority_update
  }

  clear_pending_historical_records_priority_update <- function() {
    session$userData$pending_historical_records_priority_update <- NULL
    invisible(NULL)
  }

  mark_pending_historical_records_selected_country_update <- function(value, scope = historical_records_priority_scope_for_source()) {
    session$userData$pending_historical_records_selected_country_update <- list(
      value = isTRUE(value),
      scope = scope
    )
    invisible(isTRUE(value))
  }

  read_pending_historical_records_selected_country_update <- function() {
    session$userData$pending_historical_records_selected_country_update
  }

  clear_pending_historical_records_selected_country_update <- function() {
    session$userData$pending_historical_records_selected_country_update <- NULL
    invisible(NULL)
  }

  mark_pending_historical_records_selected_year_update <- function(value, scope = historical_records_priority_scope_for_source()) {
    session$userData$pending_historical_records_selected_year_update <- list(
      value = isTRUE(value),
      scope = scope
    )
    invisible(isTRUE(value))
  }

  read_pending_historical_records_selected_year_update <- function() {
    session$userData$pending_historical_records_selected_year_update
  }

  clear_pending_historical_records_selected_year_update <- function() {
    session$userData$pending_historical_records_selected_year_update <- NULL
    invisible(NULL)
  }

  current_historical_records_priority_request <- function(source_choice = current_source_choice_safe(default = NULL), default = FALSE) {
    scope <- historical_records_priority_scope_for_source(source_choice)
    pending_update <- read_pending_historical_records_priority_update()
    if (!is.null(pending_update) && identical(pending_update$scope, scope)) {
      return(isTRUE(pending_update$value))
    }

    raw_value <- tryCatch(input$psd_historical_records_prioritize_metric, error = function(...) NULL)
    raw_scope <- session$userData$psd_historical_records_prioritize_metric_input_scope

    if (!is.null(raw_value) && length(raw_value) > 0L && identical(raw_scope, scope)) {
      return(isTRUE(raw_value))
    }

    read_remembered_historical_records_priority(scope, default = default)
  }

  current_historical_records_selected_country_request <- function(source_choice = current_source_choice_safe(default = NULL), default = FALSE) {
    scope <- historical_records_priority_scope_for_source(source_choice)
    if (!identical(scope, "psd")) return(FALSE)
    pending_update <- read_pending_historical_records_selected_country_update()
    if (!is.null(pending_update) && identical(pending_update$scope, scope)) {
      return(isTRUE(pending_update$value))
    }

    raw_value <- tryCatch(input$psd_historical_records_selected_country_only, error = function(...) NULL)
    raw_scope <- session$userData$psd_historical_records_selected_country_input_scope

    if (!is.null(raw_value) && length(raw_value) > 0L && identical(raw_scope, scope)) {
      return(isTRUE(raw_value))
    }

    read_remembered_historical_records_selected_country(scope, default = default)
  }

  current_historical_records_selected_year_request <- function(source_choice = current_source_choice_safe(default = NULL), default = FALSE) {
    scope <- historical_records_priority_scope_for_source(source_choice)
    pending_update <- read_pending_historical_records_selected_year_update()
    if (!is.null(pending_update) && identical(pending_update$scope, scope)) {
      return(isTRUE(pending_update$value))
    }

    raw_value <- tryCatch(input$psd_historical_records_selected_year_only, error = function(...) NULL)
    raw_scope <- session$userData$psd_historical_records_selected_year_input_scope

    if (!is.null(raw_value) && length(raw_value) > 0L && identical(raw_scope, scope)) {
      return(isTRUE(raw_value))
    }

    read_remembered_historical_records_selected_year(scope, default = default)
  }

  sync_historical_records_priority_input <- function(source_choice = current_source_choice_safe(default = NULL)) {
    scope <- historical_records_priority_scope_for_source(source_choice)
    if (!(scope %in% c("psd", "wasde", "nass"))) return(invisible(FALSE))

    target_value <- read_remembered_historical_records_priority(scope, default = FALSE)
    raw_value <- tryCatch(input$psd_historical_records_prioritize_metric, error = function(...) NULL)
    raw_scope <- session$userData$psd_historical_records_prioritize_metric_input_scope

    if (!is.null(raw_value) && length(raw_value) > 0L && identical(isTRUE(raw_value), target_value)) {
      if (!identical(raw_scope, scope)) {
        session$userData$psd_historical_records_prioritize_metric_input_scope <- scope
      }
      return(invisible(FALSE))
    }

    if (is.null(raw_value) || length(raw_value) == 0L) {
      return(invisible(FALSE))
    }

    mark_pending_historical_records_priority_update(target_value, scope)
    updateCheckboxInput(session, "psd_historical_records_prioritize_metric", value = target_value)
    invisible(TRUE)
  }

  sync_historical_records_selected_country_input <- function(source_choice = current_source_choice_safe(default = NULL)) {
    scope <- historical_records_priority_scope_for_source(source_choice)
    if (!identical(scope, "psd")) return(invisible(FALSE))

    target_value <- read_remembered_historical_records_selected_country(scope, default = FALSE)
    raw_value <- tryCatch(input$psd_historical_records_selected_country_only, error = function(...) NULL)
    raw_scope <- session$userData$psd_historical_records_selected_country_input_scope

    if (!is.null(raw_value) && length(raw_value) > 0L && identical(isTRUE(raw_value), target_value)) {
      if (!identical(raw_scope, scope)) {
        session$userData$psd_historical_records_selected_country_input_scope <- scope
      }
      return(invisible(FALSE))
    }

    if (is.null(raw_value) || length(raw_value) == 0L) {
      return(invisible(FALSE))
    }

    mark_pending_historical_records_selected_country_update(target_value, scope)
    updateCheckboxInput(session, "psd_historical_records_selected_country_only", value = target_value)
    invisible(TRUE)
  }

  sync_historical_records_selected_year_input <- function(source_choice = current_source_choice_safe(default = NULL)) {
    scope <- historical_records_priority_scope_for_source(source_choice)
    if (!(scope %in% c("psd", "wasde", "nass"))) return(invisible(FALSE))

    target_value <- read_remembered_historical_records_selected_year(scope, default = FALSE)
    raw_value <- tryCatch(input$psd_historical_records_selected_year_only, error = function(...) NULL)
    raw_scope <- session$userData$psd_historical_records_selected_year_input_scope

    if (!is.null(raw_value) && length(raw_value) > 0L && identical(isTRUE(raw_value), target_value)) {
      if (!identical(raw_scope, scope)) {
        session$userData$psd_historical_records_selected_year_input_scope <- scope
      }
      return(invisible(FALSE))
    }

    if (is.null(raw_value) || length(raw_value) == 0L) {
      return(invisible(FALSE))
    }

    mark_pending_historical_records_selected_year_update(target_value, scope)
    updateCheckboxInput(session, "psd_historical_records_selected_year_only", value = target_value)
    invisible(TRUE)
  }

  observeEvent(input$psd_historical_records_prioritize_metric, {
    source_choice <- current_source_choice_safe(default = input$data_source_choice %||% NULL)
    scope <- historical_records_priority_scope_for_source(source_choice)
    if (!(scope %in% c("psd", "wasde", "nass"))) return()

    input_value <- isTRUE(input$psd_historical_records_prioritize_metric)
    pending_update <- read_pending_historical_records_priority_update()
    if (!is.null(pending_update) && identical(pending_update$scope, scope)) {
      if (identical(isTRUE(pending_update$value), input_value)) {
        session$userData$psd_historical_records_prioritize_metric_input_scope <- scope
        clear_pending_historical_records_priority_update()
        return()
      }

      clear_pending_historical_records_priority_update()
    }

    session$userData$psd_historical_records_prioritize_metric_input_scope <- scope
    write_remembered_historical_records_priority(input_value, scope)
  }, ignoreInit = TRUE, priority = 100)

  observeEvent(input$psd_historical_records_selected_country_only, {
    source_choice <- current_source_choice_safe(default = input$data_source_choice %||% NULL)
    scope <- historical_records_priority_scope_for_source(source_choice)
    if (!identical(scope, "psd")) return()

    input_value <- isTRUE(input$psd_historical_records_selected_country_only)
    pending_update <- read_pending_historical_records_selected_country_update()
    if (!is.null(pending_update) && identical(pending_update$scope, scope)) {
      if (identical(isTRUE(pending_update$value), input_value)) {
        session$userData$psd_historical_records_selected_country_input_scope <- scope
        clear_pending_historical_records_selected_country_update()
        return()
      }

      clear_pending_historical_records_selected_country_update()
    }

    session$userData$psd_historical_records_selected_country_input_scope <- scope
    write_remembered_historical_records_selected_country(input_value, scope)
  }, ignoreInit = TRUE, priority = 100)

  observeEvent(input$psd_historical_records_selected_year_only, {
    source_choice <- current_source_choice_safe(default = input$data_source_choice %||% NULL)
    scope <- historical_records_priority_scope_for_source(source_choice)
    if (!(scope %in% c("psd", "wasde", "nass"))) return()

    input_value <- isTRUE(input$psd_historical_records_selected_year_only)
    pending_update <- read_pending_historical_records_selected_year_update()
    if (!is.null(pending_update) && identical(pending_update$scope, scope)) {
      if (identical(isTRUE(pending_update$value), input_value)) {
        session$userData$psd_historical_records_selected_year_input_scope <- scope
        clear_pending_historical_records_selected_year_update()
        return()
      }

      clear_pending_historical_records_selected_year_update()
    }

    session$userData$psd_historical_records_selected_year_input_scope <- scope
    write_remembered_historical_records_selected_year(input_value, scope)
  }, ignoreInit = TRUE, priority = 100)

  observeEvent(list(input$data_source_choice, input$main_tabs_panel, input$psd_time_series_bottom_view), {
    source_choice <- current_source_choice_safe(default = input$data_source_choice %||% NULL)
    if (!is_time_series_source_active(source_choice = source_choice, active_tab = current_main_tab_safe())) {
      return()
    }

    sync_historical_records_priority_input(source_choice)
    sync_historical_records_selected_year_input(source_choice)
    sync_historical_records_selected_country_input(source_choice)
  }, ignoreInit = FALSE)

  historical_records_mode_choices <- c("All-time records" = "all_time", "Selected year mode" = "as_of")

  current_historical_records_mode <- function(default = "all_time") {
    raw_value <- tryCatch(input$psd_historical_records_mode, error = function(...) NULL)
    raw_value <- as.character(raw_value %||% default)
    raw_value <- raw_value[!is.na(raw_value) & nzchar(raw_value)]
    value <- if (length(raw_value) > 0L) raw_value[[1L]] else default
    if (value %in% unname(historical_records_mode_choices)) value else default
  }

  current_historical_records_nass_hide_forecast <- function(source_choice = current_source_choice_safe(default = NULL), default = TRUE) {
    if (!identical(source_choice, "nass")) return(FALSE)
    raw_value <- tryCatch(input$psd_historical_records_nass_hide_forecast, error = function(...) NULL)
    if (is.null(raw_value) || length(raw_value) == 0L) return(isTRUE(default))
    isTRUE(raw_value)
  }

  is_nass_forecast_year_type <- function(annual_year_type) {
    tolower(trimws(as.character(annual_year_type))) == "forecast"
  }

  psd_historical_records_filter_cache_key <- reactive({
    source_choice <- current_source_choice_safe(default = input$data_source_choice %||% NULL)
    psd_native_basis_profile <- "n/a"
    if (identical(source_choice, "psd")) {
      native_profile <- tryCatch(startup_psd_basis_profile(default = "shelled_basis"), error = function(...) "shelled_basis")
      native_profile <- trimws(as.character(native_profile %||% "shelled_basis"))
      native_profile <- native_profile[!is.na(native_profile) & nzchar(native_profile)]
      psd_native_basis_profile <- if (length(native_profile) > 0L) native_profile[[1L]] else "shelled_basis"
    }
    historical_records_mode <- current_historical_records_mode()
    selected_metric_only <- current_historical_records_priority_request(source_choice)
    selected_year_only <- current_historical_records_selected_year_request(source_choice)
    effective_selected_year_only <- isTRUE(selected_year_only) && identical(historical_records_mode, "all_time")
    selected_country_only <- current_historical_records_selected_country_request(source_choice)
    nass_hide_forecast <- current_historical_records_nass_hide_forecast(source_choice)
    year_filter_active <- isTRUE(effective_selected_year_only) || identical(historical_records_mode, "as_of")
    list(
      cache_data_version = cache_data_version,
      contract_version = "psd_historical_records_filter_2026_07_09_native_basis_v2",
      source_choice = source_choice,
      record_mode = historical_records_mode,
      reset_epoch = historical_records_reset_epoch(),
      main_tab = current_main_tab_safe(selected_tab = input$main_tabs_panel %||% NULL),
      bottom_view = time_series_historical_bottom_view(),
      selected_commodity = if (identical(source_choice, "wasde")) time_series_historical_selected_commodity() else "n/a",
      nass_state_choice = "n/a",
      nass_annual_year_type = "n/a",
      selected_year = if (isTRUE(year_filter_active)) time_series_historical_selected_year() else "all",
      window = if (identical(historical_records_mode, "all_time")) "record" else input$psd_historical_records_window %||% time_series_historical_default_window(source_choice),
      direction = input$psd_historical_records_direction %||% "both",
      basis_profile = active_resolved_basis(),
      psd_native_basis_profile = psd_native_basis_profile,
      metric_code = effective_main_metric(),
      selected_metric_code = resolve_time_series_historical_metric_code(effective_main_metric(), source_choice = source_choice),
      selected_metric_only = isTRUE(selected_metric_only),
      requested_selected_year_only = isTRUE(selected_year_only),
      selected_year_only = isTRUE(effective_selected_year_only),
      selected_country_only = isTRUE(selected_country_only),
      nass_hide_forecast = isTRUE(nass_hide_forecast),
      selected_country_code = if (identical(source_choice, "psd")) current_psd_active_country() else "n/a"
    )
  })

  psd_historical_records_cache_key <- psd_historical_records_filter_cache_key

  psd_historical_records_display_cache_key <- reactive({
    source_choice <- current_source_choice_safe(default = input$data_source_choice %||% NULL)
    c(
      psd_historical_records_filter_cache_key(),
      list(
        display_contract_version = "psd_historical_records_display_2026_07_10_nass_unit_locks_v1",
        display_metric_code = effective_main_metric(),
        display_selected_metric_code = resolve_time_series_historical_metric_code(effective_main_metric(), source_choice = source_choice),
        value_digits = psd_historical_records_value_digits(),
        unit_choice = current_unit_choice_safe(default = "thousand_mt"),
        area_unit_choice = current_psd_area_unit_choice_safe(),
        value_unit_choice = if (identical(source_choice, "wasde")) {
          current_census_value_unit_choice_safe(
            default = input$value_unit_choice %||% default_value_unit_choice_for_context("wasde", effective_main_metric()),
            source_choice = "wasde",
            metric_code = effective_main_metric()
          )
        } else if (identical(source_choice, "nass")) {
          current_census_value_unit_choice_safe(
            default = input$value_unit_choice %||% default_value_unit_choice_for_context("nass", effective_main_metric()),
            source_choice = "nass",
            metric_code = effective_main_metric()
          )
        } else {
          "n/a"
        },
        nass_basis_choice = if (identical(source_choice, "nass")) active_resolved_basis() else "n/a",
        wasde_price_lock = if (identical(source_choice, "wasde")) current_wasde_price_lock_input_safe() else "n/a",
        wasde_yield_lock = if (identical(source_choice, "wasde")) current_wasde_yield_lock_input_safe() else "n/a",
        nass_price_lock = if (identical(source_choice, "nass")) current_nass_price_lock_input_safe() else "n/a",
        nass_yield_lock = if (identical(source_choice, "nass")) current_nass_yield_lock_input_safe() else "n/a"
      )
    )
  })

  psd_historical_records_empty <- function() {
    tibble::tibble()
  }

  psd_historical_records_filter_state <- reactive({
    historical_records_reset_epoch()
    source_choice <- current_source_choice_safe()
    active_tab <- current_main_tab_safe()
    historical_records_mode <- current_historical_records_mode()
    selected_year <- suppressWarnings(as.integer(time_series_historical_selected_year()))
    selected_window <- if (identical(historical_records_mode, "all_time")) "record" else input$psd_historical_records_window %||% time_series_historical_default_window(source_choice)
    selected_direction <- input$psd_historical_records_direction %||% "both"
    active_basis_profile <- active_resolved_basis()
    psd_native_basis_profile <- if (identical(source_choice, "psd")) {
      native_profile <- tryCatch(startup_psd_basis_profile(default = "shelled_basis"), error = function(...) "shelled_basis")
      native_profile <- trimws(as.character(native_profile %||% "shelled_basis"))
      native_profile <- native_profile[!is.na(native_profile) & nzchar(native_profile)]
      if (length(native_profile) > 0L) native_profile[[1L]] else "shelled_basis"
    } else {
      NA_character_
    }
    eligibility_basis_mode <- if (identical(source_choice, "psd")) "native_first" else "contextual"
    selected_metric <- effective_main_metric()
    selected_metric_code <- resolve_time_series_historical_metric_code(selected_metric, source_choice = source_choice)
    selected_metric_only <- current_historical_records_priority_request(source_choice)
    selected_year_only <- current_historical_records_selected_year_request(source_choice)
    effective_selected_year_only <- isTRUE(selected_year_only) && identical(historical_records_mode, "all_time")
    year_filter_active <- isTRUE(effective_selected_year_only) || identical(historical_records_mode, "as_of")
    selected_country_only <- identical(source_choice, "psd") && current_historical_records_selected_country_request(source_choice)
    nass_hide_forecast <- current_historical_records_nass_hide_forecast(source_choice)
    selected_country_code <- if (identical(source_choice, "psd")) current_psd_active_country() else NA_character_
    selected_commodity <- if (identical(source_choice, "wasde")) time_series_historical_selected_commodity() else NULL
    bottom_view <- time_series_historical_bottom_view()
    source_switch_fields <- tryCatch(source_switch_epoch_fields(include_age = TRUE), error = function(...) list())

    build_state <- function(
      records,
      status,
      reason,
      pre_metric_rows = 0L,
      strict_metric_rows = 0L,
      selected_metric_candidate_rows = 0L,
      effective_selected_metric_only = isTRUE(selected_metric_only),
      strict_filter_applied = isTRUE(selected_metric_only),
      strict_filter_eligible = isTRUE(selected_metric_only) && !is.null(selected_metric_code) && nzchar(selected_metric_code),
      strict_filter_empty_metric_code = FALSE,
      strict_filter_suppressed = FALSE,
      strict_filter_suppression_reason = NA_character_,
      fallback_eligible = FALSE,
      fallback_applied = FALSE,
      fallback_trigger_key = NULL
    ) {
      selected_commodity_scalar <- as.character(selected_commodity %||% NA_character_)
      selected_commodity_scalar <- selected_commodity_scalar[!is.na(selected_commodity_scalar)]
      selected_commodity_scalar <- if (length(selected_commodity_scalar) > 0L) selected_commodity_scalar[[1L]] else NA_character_

      selected_metric_code_scalar <- as.character(selected_metric_code %||% NA_character_)
      selected_metric_code_scalar <- selected_metric_code_scalar[!is.na(selected_metric_code_scalar)]
      selected_metric_code_scalar <- if (length(selected_metric_code_scalar) > 0L) selected_metric_code_scalar[[1L]] else NA_character_

      list(
        records = records,
        status = status,
        reason = reason,
        source_choice = source_choice,
        historical_records_mode = historical_records_mode,
        active_tab = active_tab,
        bottom_view = bottom_view,
        selected_year = selected_year,
        selected_window = selected_window,
        selected_direction = selected_direction,
        selected_commodity = selected_commodity_scalar,
        selected_metric_code = selected_metric_code_scalar,
        requested_selected_metric_only = isTRUE(selected_metric_only),
        selected_metric_only = isTRUE(selected_metric_only),
        requested_selected_year_only = isTRUE(selected_year_only),
        selected_year_only = isTRUE(effective_selected_year_only),
        year_filter_active = isTRUE(year_filter_active),
        selected_country_only = isTRUE(selected_country_only),
        nass_hide_forecast = isTRUE(nass_hide_forecast),
        selected_country_code = selected_country_code %||% NA_character_,
        active_basis_profile = active_basis_profile %||% NA_character_,
        psd_native_basis_profile = psd_native_basis_profile %||% NA_character_,
        eligibility_basis_mode = eligibility_basis_mode,
        effective_selected_metric_only = isTRUE(effective_selected_metric_only),
        strict_filter_applied = isTRUE(strict_filter_applied),
        strict_filter_eligible = isTRUE(strict_filter_eligible),
        strict_filter_empty_metric_code = isTRUE(strict_filter_empty_metric_code),
        strict_filter_suppressed = isTRUE(strict_filter_suppressed),
        strict_filter_suppression_reason = strict_filter_suppression_reason %||% NA_character_,
        pre_metric_rows = as.integer(pre_metric_rows),
        strict_metric_rows = as.integer(strict_metric_rows),
        selected_metric_candidate_rows = as.integer(selected_metric_candidate_rows),
        final_rows = if (is.data.frame(records)) nrow(records) else 0L,
        fallback_eligible = isTRUE(fallback_eligible),
        fallback_applied = isTRUE(fallback_applied),
        fallback_trigger_key = fallback_trigger_key,
        source_switch_fields = source_switch_fields
      )
    }

    if (!is_time_series_source_active(source_choice = source_choice, active_tab = active_tab)) {
      return(build_state(
        records = psd_historical_records_empty(),
        status = "inactive",
        reason = "inactive_tab_or_source"
      ))
    }

    records <- if (identical(source_choice, "wasde")) {
      load_wasde_historical_records()
    } else if (identical(source_choice, "nass")) {
      load_nass_historical_records()
    } else {
      load_psd_historical_records()
    }

    if (!is.data.frame(records) || nrow(records) == 0) {
      return(build_state(
        records = psd_historical_records_empty(),
        status = "empty_source",
        reason = "empty_source"
      ))
    }

    if (isTRUE(year_filter_active) && (is.na(selected_year) || !is.finite(selected_year))) {
      return(build_state(
        records = psd_historical_records_empty(),
        status = "empty_filtered",
        reason = "invalid_selected_year_when_filter_active"
      ))
    }

    if (identical(source_choice, "nass")) {
      if ("country" %in% names(records)) {
        records <- records %>% filter(.data$country == "US")
      }
    }

    profile_keep <- if (identical(source_choice, "wasde")) {
      "native"
    } else if (identical(source_choice, "nass")) {
      c("shelled_eq", "area", "rate", "value")
    } else {
      c(psd_native_basis_profile, "area", "rate")
    }

    pre_metric_records <- records %>%
      filter(
        if ("record_mode" %in% names(.)) .data$record_mode == .env$historical_records_mode else TRUE,
        .data$window_label == selected_window,
        .data$basis_profile %in% profile_keep
      )

    if (isTRUE(year_filter_active)) {
      pre_metric_records <- pre_metric_records %>% filter(.data$market_year == selected_year)
    }

    if (identical(source_choice, "nass") && isTRUE(nass_hide_forecast) && "annual_year_type" %in% names(pre_metric_records)) {
      pre_metric_records <- pre_metric_records[!is_nass_forecast_year_type(pre_metric_records$annual_year_type), , drop = FALSE]
    }

    if (identical(source_choice, "wasde") && "commodity" %in% names(pre_metric_records)) {
      pre_metric_records <- pre_metric_records %>% filter(.data$commodity == .env$selected_commodity)
    }

    if (identical(source_choice, "psd") && isTRUE(selected_country_only) && "country" %in% names(pre_metric_records)) {
      pre_metric_records <- pre_metric_records %>% filter(.data$country == .env$selected_country_code)
    }

    if (!identical(selected_direction, "both")) {
      pre_metric_records <- pre_metric_records %>% filter(.data$direction == selected_direction)
    }

    if (identical(source_choice, "wasde") && "metric_code" %in% names(pre_metric_records)) {
      visible_metric_ids <- unique(trimws(as.character(unname(get_metric_choices_for_context(
        active_tab = "Time Series Analysis Tool",
        source_choice = "wasde",
        data_frequency = "monthly"
      )))))
      visible_metric_ids <- visible_metric_ids[!is.na(visible_metric_ids) & nzchar(visible_metric_ids)]

      normalized_metric_ids <- vapply(
        as.character(pre_metric_records$metric_code),
        function(metric_code) normalize_wasde_metric_id(metric_code) %||% "",
        character(1)
      )

      pre_metric_records <- pre_metric_records[normalized_metric_ids %in% visible_metric_ids, , drop = FALSE]
    }

    if (identical(source_choice, "nass") && "metric_code" %in% names(pre_metric_records)) {
      visible_metric_ids <- unique(trimws(as.character(unname(nass_metric_choices))))
      visible_metric_ids <- visible_metric_ids[!is.na(visible_metric_ids) & nzchar(visible_metric_ids)]
      pre_metric_records <- pre_metric_records[trimws(as.character(pre_metric_records$metric_code)) %in% visible_metric_ids, , drop = FALSE]
    }

    pre_metric_rows <- if (is.data.frame(pre_metric_records)) nrow(pre_metric_records) else 0L
    strict_filter_eligible <- isTRUE(selected_metric_only) && !is.null(selected_metric_code) && nzchar(selected_metric_code)
    strict_filter_empty_metric_code <- isTRUE(selected_metric_only) && !isTRUE(strict_filter_eligible)
    selected_metric_candidate_records <- if (isTRUE(strict_filter_eligible)) {
      pre_metric_records %>% filter(.data$metric_code == selected_metric_code)
    } else {
      pre_metric_records[0, , drop = FALSE]
    }
    selected_metric_candidate_rows <- if (is.data.frame(selected_metric_candidate_records)) nrow(selected_metric_candidate_records) else 0L
    fallback_eligible <- identical(source_choice, "wasde") &&
      identical(bottom_view, "historical_records") &&
      isTRUE(selected_metric_only) &&
      isTRUE(strict_filter_eligible) &&
      pre_metric_rows > 0L &&
      selected_metric_candidate_rows == 0L
    fallback_applied <- isTRUE(fallback_eligible)
    effective_selected_metric_only <- isTRUE(selected_metric_only) && !isTRUE(fallback_applied)
    strict_filter_suppressed <- isTRUE(fallback_applied)
    strict_filter_suppression_reason <- if (isTRUE(strict_filter_suppressed)) "strict_metric_empty_autofallback" else NA_character_
    strict_metric_records <- if (isTRUE(effective_selected_metric_only)) {
      if (isTRUE(strict_filter_eligible)) selected_metric_candidate_records else pre_metric_records[0, , drop = FALSE]
    } else {
      pre_metric_records
    }
    strict_metric_rows <- selected_metric_candidate_rows
    final_records <- strict_metric_records

    if (!is.data.frame(final_records) || nrow(final_records) == 0L) {
      empty_reason <- if (isTRUE(strict_filter_empty_metric_code)) {
        "strict_metric_code_empty"
      } else if (isTRUE(selected_metric_only) && strict_metric_rows == 0L) {
        "strict_metric_no_rows"
      } else if (pre_metric_rows == 0L) {
        "pre_metric_empty"
      } else {
        "filtered_no_rows"
      }

      return(build_state(
        records = psd_historical_records_empty(),
        status = "empty_filtered",
        reason = empty_reason,
        pre_metric_rows = pre_metric_rows,
        strict_metric_rows = strict_metric_rows,
        selected_metric_candidate_rows = selected_metric_candidate_rows,
        effective_selected_metric_only = isTRUE(effective_selected_metric_only),
        strict_filter_applied = isTRUE(effective_selected_metric_only),
        strict_filter_eligible = isTRUE(strict_filter_eligible),
        strict_filter_empty_metric_code = isTRUE(strict_filter_empty_metric_code),
        strict_filter_suppressed = isTRUE(strict_filter_suppressed),
        strict_filter_suppression_reason = strict_filter_suppression_reason,
        fallback_eligible = isTRUE(fallback_eligible),
        fallback_applied = FALSE
      ))
    }

    fallback_trigger_key <- if (isTRUE(fallback_applied)) {
      paste(
        source_choice %||% "NA",
        selected_year %||% "NA",
        selected_window %||% "NA",
        selected_direction %||% "NA",
        selected_commodity %||% "NA",
        selected_metric_code %||% "NA",
        sep = "|"
      )
    } else {
      NULL
    }

    build_state(
      records = final_records,
      status = if (isTRUE(fallback_applied)) "strict_empty_autofallback" else "ok",
      reason = if (isTRUE(fallback_applied)) "strict_metric_empty_autofallback" else "rows_available",
      pre_metric_rows = pre_metric_rows,
      strict_metric_rows = strict_metric_rows,
      selected_metric_candidate_rows = selected_metric_candidate_rows,
      effective_selected_metric_only = isTRUE(effective_selected_metric_only),
      strict_filter_applied = isTRUE(effective_selected_metric_only),
      strict_filter_eligible = isTRUE(strict_filter_eligible),
      strict_filter_empty_metric_code = isTRUE(strict_filter_empty_metric_code),
      strict_filter_suppressed = isTRUE(strict_filter_suppressed),
      strict_filter_suppression_reason = strict_filter_suppression_reason,
      fallback_eligible = isTRUE(fallback_eligible),
      fallback_applied = isTRUE(fallback_applied),
      fallback_trigger_key = fallback_trigger_key
    )
  })

  psd_historical_records_filtered_rows <- reactive({
    start_time <- Sys.time()
    state <- psd_historical_records_filter_state()
    source_choice <- state$source_choice
    sort_zero_epsilon <- 1e-12
    wasde_sort_direction_label <- NA_character_
    records <- state$records
    selected_year <- state$selected_year
    selected_window <- state$selected_window
    selected_direction <- state$selected_direction
    selected_metric_code <- state$selected_metric_code
    selected_commodity <- state$selected_commodity

    if (!is.data.frame(records) || nrow(records) == 0) {
      log_perf(
        "psd_historical_records_filtered_rows",
        start_time,
        details = c(
          state$source_switch_fields,
          list(
            status = state$status,
            reason = state$reason,
            source = source_choice,
            tab = state$active_tab,
            bottom_view = state$bottom_view,
            selected_year = selected_year,
            selected_commodity = selected_commodity %||% NA_character_,
            window = selected_window,
            direction = selected_direction,
            metric_code = selected_metric_code %||% NA_character_,
            requested_selected_metric_only = isTRUE(state$requested_selected_metric_only),
            selected_metric_only = isTRUE(state$selected_metric_only),
            selected_year_only = isTRUE(state$selected_year_only),
            active_basis_profile = state$active_basis_profile %||% NA_character_,
            psd_native_basis_profile = state$psd_native_basis_profile %||% NA_character_,
            eligibility_basis_mode = state$eligibility_basis_mode %||% NA_character_,
            effective_selected_metric_only = isTRUE(state$effective_selected_metric_only),
            strict_filter_applied = isTRUE(state$strict_filter_applied),
            strict_filter_eligible = isTRUE(state$strict_filter_eligible),
            strict_filter_empty_metric_code = isTRUE(state$strict_filter_empty_metric_code),
            strict_filter_suppressed = isTRUE(state$strict_filter_suppressed),
            strict_filter_suppression_reason = state$strict_filter_suppression_reason %||% NA_character_,
            pre_metric_rows = state$pre_metric_rows,
            strict_metric_rows = state$strict_metric_rows,
            selected_metric_candidate_rows = state$selected_metric_candidate_rows,
            fallback_eligible = isTRUE(state$fallback_eligible),
            fallback_applied = isTRUE(state$fallback_applied),
            fallback_trigger_key = state$fallback_trigger_key %||% NA_character_,
            rows = 0
          )
        )
      )
      return(psd_historical_records_empty())
    }

    metric_rank_code <- if (!is.null(selected_metric_code) && nzchar(selected_metric_code)) selected_metric_code else ""

    records <- records %>%
      mutate(
        selected_metric_rank = ifelse(nzchar(metric_rank_code) & .data$metric_code == metric_rank_code, 1L, 0L),
        tied_rank = ifelse(!is.na(.data$is_tied_record) & .data$is_tied_record, 1L, 0L)
      )

    if (identical(source_choice, "wasde")) {
      # Keep startup sort keys row-aligned with visible rows by materializing signed percent values in-table first.
      records <- records %>%
        mutate(
          gap_pct_signed_sort = ifelse(
            .data$gap_pct_status == "ok" & !is.na(.data$gap_pct_vs_next_distinct),
            ifelse(.data$direction == "low", -abs(.data$gap_pct_vs_next_distinct), .data$gap_pct_vs_next_distinct),
            NA_real_
          )
        )

      non_zero_mask <- is.finite(records$gap_pct_signed_sort) & abs(records$gap_pct_signed_sort) > sort_zero_epsilon
      anchor_abs <- if (any(non_zero_mask)) max(abs(records$gap_pct_signed_sort[non_zero_mask]), na.rm = TRUE) else NA_real_
      anchor_candidates <- if (is.finite(anchor_abs)) {
        records$gap_pct_signed_sort[non_zero_mask & abs(abs(records$gap_pct_signed_sort) - anchor_abs) <= sort_zero_epsilon]
      } else {
        numeric(0)
      }

      pct_direction_sign <- if (!is.finite(anchor_abs)) {
        0L
      } else if (any(anchor_candidates > 0, na.rm = TRUE)) {
        1L
      } else if (any(anchor_candidates < 0, na.rm = TRUE)) {
        -1L
      } else {
        1L
      }

      wasde_sort_direction_label <- if (pct_direction_sign > 0L) {
        "positive_first"
      } else if (pct_direction_sign < 0L) {
        "negative_first"
      } else {
        "fallback"
      }

      records <- records %>%
        arrange(.data$direction, .data$metric_code, .data$countryDescription) %>%
        mutate(
          gap_pct_zero_last_flag = ifelse(!is.finite(.data$gap_pct_signed_sort) | abs(.data$gap_pct_signed_sort) <= sort_zero_epsilon, 1L, 0L),
          gap_pct_dynamic_sort = ifelse(
            .data$gap_pct_zero_last_flag == 1L,
            NA_real_,
            if (pct_direction_sign >= 0L) -.data$gap_pct_signed_sort else .data$gap_pct_signed_sort
          ),
          gap_pct_fallback_rank = dplyr::row_number()
        ) %>%
        arrange(
          .data$tied_rank,
          .data$gap_pct_zero_last_flag,
          .data$gap_pct_dynamic_sort,
          .data$gap_pct_fallback_rank,
          .data$direction,
          .data$metric_code,
          .data$countryDescription
        )
    } else {
      records <- records %>%
        mutate(
          gap_pct_sort = ifelse(.data$gap_pct_status == "ok" & !is.na(.data$gap_pct_vs_next_distinct), .data$gap_pct_vs_next_distinct, -Inf),
          gap_pct_signed_sort = ifelse(.data$gap_pct_status == "ok" & !is.na(.data$gap_pct_vs_next_distinct), .data$gap_pct_vs_next_distinct, NA_real_),
          gap_pct_zero_last_flag = ifelse(!is.finite(.data$gap_pct_signed_sort) | abs(.data$gap_pct_signed_sort) <= sort_zero_epsilon, 1L, 0L),
          gap_pct_dynamic_sort = NA_real_,
          gap_pct_fallback_rank = dplyr::row_number()
        ) %>%
        arrange(desc(.data$selected_metric_rank), .data$tied_rank, desc(.data$gap_pct_sort), .data$direction, .data$metric_code, .data$countryDescription)
    }

    log_perf(
      "psd_historical_records_filtered_rows",
      start_time,
      details = c(
        state$source_switch_fields,
        list(
          status = state$status,
          reason = state$reason,
          source = source_choice,
          tab = state$active_tab,
          bottom_view = state$bottom_view,
          selected_year = selected_year,
          selected_commodity = selected_commodity %||% NA_character_,
          window = selected_window,
          direction = selected_direction,
          metric_code = selected_metric_code %||% NA_character_,
          requested_selected_metric_only = isTRUE(state$requested_selected_metric_only),
          selected_metric_only = isTRUE(state$selected_metric_only),
          selected_year_only = isTRUE(state$selected_year_only),
          active_basis_profile = state$active_basis_profile %||% NA_character_,
          psd_native_basis_profile = state$psd_native_basis_profile %||% NA_character_,
          eligibility_basis_mode = state$eligibility_basis_mode %||% NA_character_,
          effective_selected_metric_only = isTRUE(state$effective_selected_metric_only),
          strict_filter_applied = isTRUE(state$strict_filter_applied),
          strict_filter_eligible = isTRUE(state$strict_filter_eligible),
          strict_filter_empty_metric_code = isTRUE(state$strict_filter_empty_metric_code),
          strict_filter_suppressed = isTRUE(state$strict_filter_suppressed),
          strict_filter_suppression_reason = state$strict_filter_suppression_reason %||% NA_character_,
          pre_metric_rows = state$pre_metric_rows,
          strict_metric_rows = state$strict_metric_rows,
          selected_metric_candidate_rows = state$selected_metric_candidate_rows,
          fallback_eligible = isTRUE(state$fallback_eligible),
          fallback_applied = isTRUE(state$fallback_applied),
          fallback_trigger_key = state$fallback_trigger_key %||% NA_character_,
          rows = nrow(records),
          startup_sort_direction = wasde_sort_direction_label %||% NA_character_
        )
      )
    )

    records
  }) %>% bindCache(psd_historical_records_filter_cache_key())

  psd_historical_records_convert_values <- function(
    values,
    metric_code,
    source_choice = current_source_choice_safe(),
    basis_choice = active_resolved_basis(),
    value_unit_choice = NULL,
    years = NULL,
    countries = NULL,
    annual_year_types = NULL
  ) {
    unit_choice <- current_unit_choice_safe(default = default_unit_choice_for_context(source_choice, metric_code))
    area_unit_choice <- current_psd_area_unit_choice_safe()

    if (identical(source_choice, "wasde")) {
      value_unit_choice <- if (!is.null(value_unit_choice) && length(value_unit_choice) > 0L) {
        resolve_census_value_unit_choice(
          value_unit_choice,
          default = default_value_unit_choice_for_context("wasde", metric_code),
          source_choice = "wasde",
          metric_code = metric_code
        )
      } else {
        current_census_value_unit_choice_safe(source_choice = "wasde", metric_code = metric_code)
      }

      return(convert_wasde_display_values(
        values = values,
        metric_code = metric_code,
        unit_choice = unit_choice,
        area_unit_choice = area_unit_choice,
        basis_choice = basis_choice,
        value_unit_choice = value_unit_choice,
        milling_factors = wasde_default_milling_factor,
        commodity_choice = time_series_historical_selected_commodity() %||% input$commodity_choice %||% default_commodity_choice_value(),
        active_tab = "Time Series Analysis Tool",
        lock_context = "historical_row"
      ))
    }

    if (identical(source_choice, "nass")) {
      value_unit_choice <- current_census_value_unit_choice_safe(source_choice = "nass", metric_code = metric_code)
      return(convert_nass_display_values(
        values = values,
        metric_code = metric_code,
        unit_choice = unit_choice,
        area_unit_choice = area_unit_choice,
        basis_choice = basis_choice,
        value_unit_choice = value_unit_choice,
        years = years,
        countries = countries,
        annual_year_types = annual_year_types,
        lock_context = "historical_row"
      ))
    }

    psd_values <- sanitize_numeric(values)
    if (!is_psd_area_metric(metric_code) && !is_psd_milling_rate_metric(metric_code)) {
      psd_values <- basis_conversion(
        base_value = psd_values,
        rough_value = psd_values,
        basis_choice = basis_choice,
        source_choice = "psd"
      )
    }

    unit_conversion(
      psd_values,
      unit_choice,
      source_choice = "psd",
      metric_code = metric_code,
      area_unit_choice = area_unit_choice,
      basis_choice = basis_choice
    )
  }

  psd_historical_records_convert_values_grouped <- function(
    values,
    metric_codes,
    basis_profiles,
    source_choice,
    value_unit_choice = NULL,
    years = NULL,
    countries = NULL,
    annual_year_types = NULL
  ) {
    values <- suppressWarnings(as.numeric(values))
    metric_codes <- as.character(metric_codes)
    basis_profiles <- as.character(basis_profiles)
    out <- rep(NA_real_, length(values))
    if (length(values) == 0L) return(out)

    group_keys <- paste(metric_codes, basis_profiles, sep = "\r")
    for (group_key in unique(group_keys)) {
      idx <- which(group_keys == group_key)
      if (length(idx) == 0L) next
      out[idx] <- psd_historical_records_convert_values(
        values[idx],
        metric_codes[[idx[[1L]]]],
        source_choice = source_choice,
        basis_choice = basis_profiles[[idx[[1L]]]],
        value_unit_choice = value_unit_choice,
        years = if (is.null(years)) NULL else years[idx],
        countries = if (is.null(countries)) NULL else countries[idx],
        annual_year_types = if (is.null(annual_year_types)) NULL else annual_year_types[idx]
      )
    }

    out
  }

  psd_historical_records_measurement_labels_grouped <- function(
    commodities,
    basis_profiles,
    metric_codes,
    source_choice,
    unit_choice,
    area_unit_choice,
    value_unit_choice = NULL
  ) {
    commodities <- as.character(commodities)
    basis_profiles <- as.character(basis_profiles)
    metric_codes <- as.character(metric_codes)
    out <- rep(NA_character_, length(metric_codes))
    if (length(metric_codes) == 0L) return(out)

    group_keys <- paste(commodities, basis_profiles, metric_codes, sep = "\r")
    for (group_key in unique(group_keys)) {
      idx <- which(group_keys == group_key)
      if (length(idx) == 0L) next
      out[idx] <- get_measurement_label_for_commodity(
        unit_choice,
        commodities[[idx[[1L]]]],
        basis_profiles[[idx[[1L]]]],
        active_tab = "Time Series Analysis Tool",
        metric_code = metric_codes[[idx[[1L]]]],
        source_choice = source_choice,
        area_unit_choice = area_unit_choice,
        value_unit_choice = value_unit_choice,
        lock_context = if (source_choice %in% c("wasde", "nass")) "historical_row" else "selected_metric"
      )
    }

    out
  }

  psd_historical_records_format_values_grouped <- function(values, metric_codes, value_digits) {
    metric_codes <- as.character(metric_codes)
    out <- rep(NA_character_, length(metric_codes))
    if (length(metric_codes) == 0L) return(out)

    for (metric_code in unique(metric_codes)) {
      idx <- which(metric_codes == metric_code)
      if (length(idx) == 0L) next
      out[idx] <- format_map_summary_value(
        values[idx],
        metric_code = metric_code,
        value_digits = value_digits
      )
    }

    out
  }

  psd_historical_records_search_term <- reactiveVal("")

  observeEvent(input$psd_historical_records_table_search, {
    payload <- input$psd_historical_records_table_search
    search_term <- if (is.list(payload)) payload$search else payload
    search_term <- as.character(search_term %||% "")
    search_term <- search_term[!is.na(search_term)]
    search_term <- if (length(search_term) > 0L) search_term[[1L]] else ""

    if (!identical(isolate(psd_historical_records_search_term()), search_term)) {
      psd_historical_records_search_term(search_term)
    }
  }, ignoreInit = TRUE)

  psd_historical_records_search_options <- function(options) {
    search_term <- isolate(as.character(psd_historical_records_search_term() %||% ""))
    search_term <- search_term[!is.na(search_term)]
    search_term <- if (length(search_term) > 0L) search_term[[1L]] else ""

    if (nzchar(search_term)) {
      options$search <- list(search = search_term, regex = FALSE, smart = TRUE)
    }

    options
  }

  psd_historical_records_search_callback <- function(callback = NULL) {
    callback_lines <- if (is.null(callback)) character(0) else as.character(callback)

    JS(
      "var psdHistoricalRecordsSearchKey = 'historical_records_table';",
      "window.psdHistoricalRecordsSearchMemory = window.psdHistoricalRecordsSearchMemory || {};",
      "var psdHistoricalRecordsSettings = table.settings && table.settings()[0] ? table.settings()[0] : {};",
      "var psdHistoricalRecordsInit = psdHistoricalRecordsSettings.oInit || {};",
      "var psdHistoricalRecordsInitialSearch = (psdHistoricalRecordsInit.search && psdHistoricalRecordsInit.search.search) || window.psdHistoricalRecordsSearchMemory[psdHistoricalRecordsSearchKey] || '';",
      "var psdHistoricalRecordsSearchBox = $(table.table().container()).find('div.dataTables_filter input, div.dt-search input');",
      "var psdHistoricalRecordsSearchPersistDelay = 300;",
      "var psdHistoricalRecordsSearchPersistTimer = null;",
      "function psdPushHistoricalRecordsSearch(value) {",
      "  value = value || '';",
      "  if (window.Shiny && Shiny.setInputValue) {",
      "    Shiny.setInputValue('psd_historical_records_table_search', {search: value, nonce: Date.now()}, {priority: 'event'});",
      "  }",
      "}",
      "function psdRememberHistoricalRecordsSearch(value, immediate) {",
      "  value = value || '';",
      "  window.psdHistoricalRecordsSearchMemory[psdHistoricalRecordsSearchKey] = value;",
      "  if (psdHistoricalRecordsSearchPersistTimer) { clearTimeout(psdHistoricalRecordsSearchPersistTimer); }",
      "  if (immediate) {",
      "    psdPushHistoricalRecordsSearch(value);",
      "  } else {",
      "    psdHistoricalRecordsSearchPersistTimer = setTimeout(function(){ psdPushHistoricalRecordsSearch(value); }, psdHistoricalRecordsSearchPersistDelay);",
      "  }",
      "}",
      "if (psdHistoricalRecordsInitialSearch && table.search() !== psdHistoricalRecordsInitialSearch) {",
      "  table.search(psdHistoricalRecordsInitialSearch);",
      "  if (psdHistoricalRecordsSearchBox.length) { psdHistoricalRecordsSearchBox.val(psdHistoricalRecordsInitialSearch); }",
      "  table.draw();",
      "} else if (psdHistoricalRecordsSearchBox.length && table.search()) {",
      "  psdHistoricalRecordsSearchBox.val(table.search());",
      "}",
      "if (psdHistoricalRecordsSearchBox.length) {",
      "  psdHistoricalRecordsSearchBox.off('.psdHistoricalRecordsSearchPersist').on('input.psdHistoricalRecordsSearchPersist keyup.psdHistoricalRecordsSearchPersist change.psdHistoricalRecordsSearchPersist', function(){",
      "    psdRememberHistoricalRecordsSearch($(this).val());",
      "  });",
      "}",
      "table.on('search.dt', function(){ psdRememberHistoricalRecordsSearch(table.search()); });",
      "psdRememberHistoricalRecordsSearch(table.search() || psdHistoricalRecordsInitialSearch || '', true);",
      callback_lines
    )
  }

  psd_historical_records_display_rows <- reactive({
    records <- psd_historical_records_filtered_rows()
    if (!is.data.frame(records) || nrow(records) == 0) return(psd_historical_records_empty())

    source_choice <- current_source_choice_safe()
    metric_label_lookup <- stats::setNames(names(psd_metric_choices), unname(psd_metric_choices))
    unit_choice <- current_unit_choice_safe(default = "thousand_mt")
    area_unit_choice <- current_psd_area_unit_choice_safe()
    value_unit_choice <- if (identical(source_choice, "wasde")) {
      current_census_value_unit_choice_safe(
        default = input$value_unit_choice %||% default_value_unit_choice_for_context("wasde", effective_main_metric()),
        source_choice = "wasde",
        metric_code = effective_main_metric()
      )
    } else if (identical(source_choice, "nass")) {
      current_census_value_unit_choice_safe(
        default = input$value_unit_choice %||% default_value_unit_choice_for_context("nass", effective_main_metric()),
        source_choice = "nass",
        metric_code = effective_main_metric()
      )
    } else {
      NULL
    }
    display_basis_profile <- if (identical(source_choice, "wasde")) {
      rep(active_resolved_basis(), nrow(records))
    } else if (identical(source_choice, "nass")) {
      active_basis <- active_resolved_basis()
      is_basis_metric <- vapply(records$metric_code, is_nass_basis_metric, logical(1), USE.NAMES = FALSE)
      ifelse(is_basis_metric, active_basis, records$basis_profile)
    } else {
      active_basis <- active_resolved_basis()
      is_basis_sensitive_metric <- !vapply(
        records$metric_code,
        function(metric_code) is_psd_area_metric(metric_code) || is_psd_milling_rate_metric(metric_code),
        logical(1),
        USE.NAMES = FALSE
      )
      ifelse(is_basis_sensitive_metric, active_basis, records$basis_profile)
    }

    gap_abs_display_values <- records$gap_abs
    gap_pct_display_values <- records$gap_pct_vs_next_distinct
    if (identical(source_choice, "wasde")) {
      gap_abs_display_values <- ifelse(records$direction == "low", -abs(gap_abs_display_values), gap_abs_display_values)
      gap_pct_display_values <- ifelse(records$direction == "low", -abs(gap_pct_display_values), gap_pct_display_values)
    }

    selected_display <- psd_historical_records_convert_values_grouped(
      records$selected_value,
      records$metric_code,
      display_basis_profile,
      source_choice = source_choice,
      value_unit_choice = value_unit_choice,
      years = records$market_year,
      countries = records$country,
      annual_year_types = records$annual_year_type
    )
    next_display <- psd_historical_records_convert_values_grouped(
      records$next_distinct_value,
      records$metric_code,
      display_basis_profile,
      source_choice = source_choice,
      value_unit_choice = value_unit_choice,
      years = records$next_distinct_year,
      countries = records$country,
      annual_year_types = records$annual_year_type
    )
    gap_display <- psd_historical_records_convert_values_grouped(
      gap_abs_display_values,
      records$metric_code,
      display_basis_profile,
      source_choice = source_choice,
      value_unit_choice = value_unit_choice,
      years = records$market_year,
      countries = records$country,
      annual_year_types = records$annual_year_type
    )

    metric_labels <- if (identical(source_choice, "wasde")) {
      vapply(
        records$metric_code,
        function(metric_code) wasde_metric_label_for_code(metric_code),
        character(1),
        USE.NAMES = FALSE
      )
    } else if (identical(source_choice, "nass")) {
      vapply(
        records$metric_code,
        function(metric_code) nass_metric_label_for_code(metric_code),
        character(1),
        USE.NAMES = FALSE
      )
    } else {
      mapped_labels <- unname(metric_label_lookup[records$metric_code])
      ifelse(is.na(mapped_labels), records$metric_code, mapped_labels)
    }

    measurement_labels <- psd_historical_records_measurement_labels_grouped(
      records$commodity,
      display_basis_profile,
      records$metric_code,
      source_choice = source_choice,
      unit_choice = unit_choice,
      area_unit_choice = area_unit_choice,
      value_unit_choice = value_unit_choice
    )
    historical_records_value_digits_fixed <- psd_table_value_digits_for_formatter(psd_historical_records_value_digits())
    selected_value_text <- psd_historical_records_format_values_grouped(
      selected_display,
      records$metric_code,
      historical_records_value_digits_fixed
    )
    next_value_text <- psd_historical_records_format_values_grouped(
      next_display,
      records$metric_code,
      historical_records_value_digits_fixed
    )
    gap_value_text <- psd_historical_records_format_values_grouped(
      gap_display,
      records$metric_code,
      historical_records_value_digits_fixed
    )

    notes <- dplyr::case_when(
      records$is_tied_record & !is.na(records$tie_peer_year) ~ paste0("Tied with ", records$tie_peer_year, " (", records$tie_count, " years)"),
      records$gap_pct_status == "initial_record" ~ "No prior distinct comparator",
      records$gap_pct_status == "undefined_zero_comparator" ~ "Percent difference undefined; comparator is zero",
      records$valid_comparison_count < records$actual_years_available ~ "Sparse valid comparison coverage",
      TRUE ~ ""
    )

    display_rows <- records %>%
      transmute(
        Record = dplyr::if_else(.data$direction == "high", "High", "Low"),
        Country = .data$countryDescription,
        Type = .data$commodity,
        Variable = metric_labels,
        `Unit/Basis` = measurement_labels,
        `Selected Year` = .data$market_year,
        `Selected Value` = selected_value_text,
        `Next Highest/Lowest Year` = ifelse(is.na(.data$next_distinct_year), "", as.character(.data$next_distinct_year)),
        `Next Highest/Lowest Value` = next_value_text,
        Difference = gap_value_text,
        `% Difference` = ifelse(.data$gap_pct_status == "ok", format_fixed_display_value_preserve_zeros(gap_pct_display_values, digits = 2L, blank_for_na = FALSE), ""),
        Coverage = paste0(.data$valid_comparison_count, "/", .data$actual_years_available),
        Notes = notes,
        `..country` = .data$country,
        `..commodity` = .data$commodity,
        `..metric_code` = .data$metric_code,
        `..basis_profile` = display_basis_profile,
        `..direction` = .data$direction,
        `..window` = .data$window_label,
        `..market_year` = .data$market_year,
        `..selected_value` = .data$selected_value,
        `..gap_pct_signed_value` = gap_pct_display_values,
        `..ties_last_sort` = .data$tied_rank,
        `..pct_difference_zero_last_flag` = .data$gap_pct_zero_last_flag,
        `..pct_difference_startup_sort` = .data$gap_pct_dynamic_sort,
        `..fallback_sort_rank` = .data$gap_pct_fallback_rank
      )

    if (identical(source_choice, "nass") && "annual_year_type" %in% names(records)) {
      year_type_display <- dplyr::case_when(
        records$annual_year_type == "calendar_year" ~ "Calendar Year",
        records$annual_year_type == "marketing_year" ~ "Marketing Year",
        records$annual_year_type == "forecast" ~ "Forecast",
        TRUE ~ stringr::str_to_title(gsub("_", " ", as.character(records$annual_year_type)))
      )
      display_rows <- display_rows %>% mutate(`Year Type` = year_type_display, .after = `Selected Year`)
    }

    display_rows <- display_rows %>%
      mutate(
        `..record_sort` = dplyr::case_when(
          .data$Record == "High" ~ 1L,
          .data$Record == "Low" ~ 2L,
          TRUE ~ 3L
        ),
        `..year_type_sort` = if ("Year Type" %in% names(.)) {
          dplyr::case_when(
            .data$`Year Type` == "Calendar Year" ~ 1L,
            .data$`Year Type` == "Marketing Year" ~ 2L,
            .data$`Year Type` == "Forecast" ~ 3L,
            TRUE ~ 4L
          )
        } else {
          1L
        }
      ) %>%
      arrange(.data$Variable, .data$`..year_type_sort`, .data$`..record_sort`, .data$Country, .data$Type, dplyr::desc(.data$`Selected Year`))

    display_rows
  }) %>% bindCache(psd_historical_records_display_cache_key())

  output$psd_historical_records_summary_ui <- renderUI({
    records <- psd_historical_records_filtered_rows()
    filter_state <- psd_historical_records_filter_state()
    source_choice <- current_source_choice_safe(default = input$data_source_choice %||% "export_sales")
    selected_year_value <- suppressWarnings(as.integer(time_series_historical_selected_year()))
    selected_year <- if (is.na(selected_year_value) || !is.finite(selected_year_value)) "selected year" else as.character(selected_year_value)
    selected_window <- input$psd_historical_records_window %||% time_series_historical_default_window(source_choice)
    selected_window_label <- if (identical(source_choice, "wasde") && identical(selected_window, "record")) "all years" else selected_window
    selected_direction <- input$psd_historical_records_direction %||% "both"

    if (!is.data.frame(records) || nrow(records) == 0) {
      direction_label <- if (identical(selected_direction, "both")) "records" else paste0(selected_direction, " records")
      return(div(
        style = "padding: 8px 0; color: #666; font-style: italic;",
        paste0("No ", direction_label, " found", if (isTRUE(filter_state$selected_year_only)) paste0(" for ", selected_year) else "", " in the ", selected_window_label, " window.")
      ))
    }

    summary_tokens <- list(
      tags$span(strong(nrow(records)), " records"),
      tags$span(strong(sum(records$direction == "high", na.rm = TRUE)), " highs"),
      tags$span(strong(sum(records$direction == "low", na.rm = TRUE)), " lows"),
      tags$span(strong(dplyr::n_distinct(records$country)), " countries"),
      tags$span(strong(dplyr::n_distinct(records$metric_code)), " variables"),
      tags$span(strong(dplyr::n_distinct(records$market_year)), " years"),
      tags$span(strong(sum(records$is_tied_record, na.rm = TRUE)), " ties")
    )

    active_filters <- c(
      if (isTRUE(filter_state$selected_metric_only)) "selected variable" else NULL,
      if (isTRUE(filter_state$selected_year_only)) "selected year" else NULL,
      if (isTRUE(filter_state$selected_country_only)) "selected country" else NULL
    )
    if (length(active_filters) > 0L) {
      summary_tokens <- c(
        summary_tokens,
        list(tags$span(style = "color: #666;", paste("Filtered to", paste(active_filters, collapse = ", "))))
      )
    }

    if (identical(source_choice, "psd")) {
      summary_tokens <- c(
        summary_tokens,
        list(tags$span(style = "color: #666;", "Records identified in native PSD basis; values shown in selected basis."))
      )
    }

    if (isTRUE(filter_state$fallback_applied)) {
      summary_tokens <- c(
        summary_tokens,
        list(tags$span(style = "color: #8a6d3b;", "Selected variable has no records for this window; showing all variables."))
      )
    }

    do.call(
      div,
      c(
        list(style = "display: flex; gap: 14px; flex-wrap: wrap; padding: 6px 0 8px 0; font-size: 12px; color: #333;"),
        summary_tokens
      )
    )
  })

  output$psd_time_series_bottom_panel_ui <- renderUI({
    source_choice <- current_source_choice_safe(default = input$data_source_choice %||% "export_sales")
    if (!is_time_series_source_active(source_choice = source_choice, active_tab = current_main_tab_safe())) {
      return(NULL)
    }

    summary_table_label <- if (identical(source_choice, "wasde")) {
      "WASDE time series summary table"
    } else if (identical(source_choice, "nass")) {
      "NASS time series summary table"
    } else {
      "PSD time series summary table"
    }
    historical_table_label <- if (identical(source_choice, "wasde")) {
      "WASDE historical records table"
    } else if (identical(source_choice, "nass")) {
      "NASS historical records table"
    } else {
      "PSD historical records table"
    }
    comparison_table_label <- "WASDE prior comparison table"
    psd_comparison_table_label <- "PSD prior comparison table"
    historical_window_label <- if (identical(source_choice, "wasde")) "Number of Years Analyzed:" else "Window:"
    historical_window_choices <- if (identical(source_choice, "wasde")) {
      c("5" = "5", "10" = "10", "20" = "20", "All years" = "record")
    } else {
      c("5" = "5", "10" = "10", "20" = "20", "Record" = "record")
    }
    historical_records_mode <- current_historical_records_mode()
    selected_historical_window <- as.character(input$psd_historical_records_window %||% time_series_historical_default_window(source_choice))
    selected_historical_window <- selected_historical_window[!is.na(selected_historical_window) & nzchar(selected_historical_window)]
    if (length(selected_historical_window) == 0L || !(selected_historical_window[[1L]] %in% unname(historical_window_choices))) {
      selected_historical_window <- time_series_historical_default_window(source_choice)
    } else {
      selected_historical_window <- selected_historical_window[[1L]]
    }
    selected_year_note_value <- suppressWarnings(as.integer(time_series_historical_selected_year()))
    selected_year_note_year <- if (is.na(selected_year_note_value) || !is.finite(selected_year_note_value)) "the selected year" else as.character(selected_year_note_value)
    selected_year_note_window_label <- if (identical(selected_historical_window, "record")) "full available record" else paste0(selected_historical_window, "-year")
    selected_year_note_text <- paste0(
      "Selected year mode evaluates ", selected_year_note_year,
      " against the ", selected_year_note_window_label,
      " lookback window ending in ", selected_year_note_year,
      ", across eligible variables and year types."
    )
    prior_psd_comparison_enabled <- identical(source_choice, "psd") && isTRUE(psd_prior_release_comparison_enabled())
    available_bottom_views <- if (identical(source_choice, "wasde")) {
      c("summary", "historical_records", "wasde_revision_comparison")
    } else if (isTRUE(prior_psd_comparison_enabled)) {
      c("summary", "historical_records", "psd_revision_comparison")
    } else {
      c("summary", "historical_records")
    }
    selected_bottom_view <- isolate(input$psd_time_series_bottom_view %||% "summary")
    selected_bottom_view <- as.character(selected_bottom_view)
    selected_bottom_view <- selected_bottom_view[!is.na(selected_bottom_view)]
    selected_bottom_view <- if (length(selected_bottom_view) > 0L) selected_bottom_view[[1L]] else "summary"
    if (!(selected_bottom_view %in% available_bottom_views)) {
      selected_bottom_view <- "summary"
    }

    tabsetPanel(
      id = "psd_time_series_bottom_view",
      type = "tabs",
      selected = selected_bottom_view,
      tabPanel(
        title = "Summary Statistics",
        value = "summary",
        div(
          style = "padding-top: 10px;",
          psd_table_decimal_controls(
            decrease_id = "psd_time_series_summary_digits_decrease",
            increase_id = "psd_time_series_summary_digits_increase",
            auto_id = "psd_time_series_summary_digits_auto",
            display_id = "psd_time_series_summary_digits_display",
            table_label = summary_table_label
          ),
          dataTableOutput("psd_time_series_summary_table")
        )
      ),
      tabPanel(
        title = "Historical Records",
        value = "historical_records",
        div(
          style = "padding-top: 10px;",
          tags$style(HTML("
            .psd-historical-records-controls {
              display: flex;
              flex-direction: column;
              gap: 10px;
              margin-bottom: 6px;
            }
            .psd-historical-records-mode-row,
            .psd-historical-records-sidebar-filter-controls,
            .psd-historical-records-table-filter-controls,
            .psd-historical-records-scope-row,
            .psd-historical-records-record-row,
            .psd-historical-records-record-window-row,
            .psd-historical-records-record-and-priority,
            .psd-historical-records-checkbox-row {
              display: flex;
              gap: 10px;
              align-items: flex-start;
              flex-wrap: wrap;
            }
            .psd-historical-records-mode-row {
              column-gap: 28px;
              row-gap: 10px;
            }
            .psd-historical-records-control {
              min-width: 220px;
            }
            .psd-historical-records-control .form-group {
              margin-bottom: 0;
            }
            .psd-historical-records-control .control-label {
              display: block;
              margin-bottom: 6px;
              line-height: 1.2;
            }
            .psd-historical-records-control .radio-inline {
              margin-top: 0;
            }
            .psd-historical-records-table-filter-group {
              display: flex;
              flex-direction: column;
              gap: 6px;
              width: 100%;
            }
            .psd-historical-records-table-filter-label {
              font-weight: 600;
              line-height: 1.2;
              margin-bottom: 0;
            }
            .psd-historical-records-table-filter-group .psd-historical-records-scope-row {
              column-gap: 12px;
              row-gap: 6px;
            }
            .psd-historical-records-table-filter-group .psd-historical-records-priority {
              min-width: 145px;
            }
            .psd-historical-records-sidebar-filter-group {
              display: flex;
              flex-direction: column;
              gap: 6px;
              min-width: 460px;
              flex: 1 1 460px;
            }
            .psd-historical-records-sidebar-filter-label {
              font-weight: 600;
              line-height: 1.2;
              margin-bottom: 0;
            }
            .psd-historical-records-sidebar-filter-group .psd-historical-records-scope-row {
              column-gap: 12px;
              row-gap: 6px;
            }
            .psd-historical-records-sidebar-filter-group .psd-historical-records-priority {
              min-width: 145px;
            }
            .psd-historical-records-priority {
              min-width: 220px;
              padding-top: 0;
            }
            .psd-historical-records-priority .shiny-input-container {
              width: auto;
            }
            .psd-historical-records-priority .form-group {
              margin-bottom: 0;
            }
            .psd-historical-records-priority .checkbox {
              margin-top: 0;
              margin-bottom: 0;
            }
            .psd-historical-records-priority .checkbox label {
              margin-bottom: 0;
              line-height: 1.42857143;
              white-space: nowrap;
            }
            .psd-historical-records-selected-year-note {
              color: #666;
              font-size: 12px;
              margin: -2px 0 6px 0;
            }
            .psd-historical-records-selected-year-only-disabled {
              color: #777;
            }
            .psd-historical-records-selected-year-only-disabled input {
              cursor: not-allowed;
            }
          ")),
          div(
            class = "psd-historical-records-controls",
            div(
              class = "psd-historical-records-mode-row",
              div(
                class = "psd-historical-records-control",
                radioButtons(
                  inputId = "psd_historical_records_mode",
                  label = "Mode:",
                  choices = historical_records_mode_choices,
                  selected = historical_records_mode,
                  inline = TRUE
                )
              )
            ),
            if (identical(historical_records_mode, "as_of")) div(
              class = "psd-historical-records-selected-year-note",
              selected_year_note_text
            ) else NULL,
            div(
              class = "psd-historical-records-record-row",
              div(
                class = "psd-historical-records-record-window-row",
                div(
                  class = "psd-historical-records-control",
                  radioButtons(
                    inputId = "psd_historical_records_direction",
                    label = "Record:",
                    choices = c("High" = "high", "Low" = "low", "Both" = "both"),
                    selected = input$psd_historical_records_direction %||% "both",
                    inline = TRUE
                  )
                ),
                if (identical(historical_records_mode, "as_of")) div(
                  class = "psd-historical-records-control",
                  radioButtons(
                    inputId = "psd_historical_records_window",
                    label = historical_window_label,
                    choices = historical_window_choices,
                    selected = selected_historical_window,
                    inline = TRUE
                  )
                ) else NULL
              )
            ),
            div(
              class = "psd-historical-records-table-filter-group",
              div(
                class = "psd-historical-records-table-filter-label",
                "Table filters:"
              ),
              div(
                class = "psd-historical-records-scope-row",
                div(
                  class = "psd-historical-records-priority",
                  checkboxInput(
                    inputId = "psd_historical_records_prioritize_metric",
                    label = "Selected variable only",
                    value = current_historical_records_priority_request(source_choice)
                  )
                ),
                if (identical(source_choice, "psd")) div(
                  class = "psd-historical-records-priority",
                  checkboxInput(
                    inputId = "psd_historical_records_selected_country_only",
                    label = "Selected country only",
                    value = current_historical_records_selected_country_request(source_choice)
                  )
                ) else NULL,
                if (identical(historical_records_mode, "as_of")) div(
                  class = "psd-historical-records-priority psd-historical-records-selected-year-only-disabled",
                  div(
                    class = "form-group shiny-input-container",
                    div(
                      class = "checkbox disabled",
                      tags$label(
                        tags$input(
                          id = "psd_historical_records_selected_year_only",
                          type = "checkbox",
                          disabled = "disabled",
                          checked = if (isTRUE(current_historical_records_selected_year_request(source_choice))) "checked" else NULL
                        ),
                        "Selected year only"
                      )
                    )
                  )
                ) else div(
                  class = "psd-historical-records-priority",
                  checkboxInput(
                    inputId = "psd_historical_records_selected_year_only",
                    label = "Selected year only",
                    value = current_historical_records_selected_year_request(source_choice)
                  )
                ),
                if (identical(source_choice, "nass")) div(
                  class = "psd-historical-records-priority",
                  checkboxInput(
                    inputId = "psd_historical_records_nass_hide_forecast",
                    label = "Hide Forecast",
                    value = current_historical_records_nass_hide_forecast(source_choice)
                  )
                ) else NULL
              )
            )
          ),
          uiOutput("psd_historical_records_summary_ui"),
          psd_table_decimal_controls(
            decrease_id = "psd_historical_records_digits_decrease",
            increase_id = "psd_historical_records_digits_increase",
            auto_id = "psd_historical_records_digits_auto",
            display_id = "psd_historical_records_digits_display",
            table_label = historical_table_label
          ),
          dataTableOutput("psd_historical_records_table")
        )
      ),
      if (isTRUE(prior_psd_comparison_enabled)) {
        tabPanel(
          title = "Prior PSD Comparison",
          value = "psd_revision_comparison",
          div(
            style = "padding-top: 10px;",
            uiOutput("psd_prior_comparison_notice_ui"),
            psd_table_decimal_controls(
              decrease_id = "psd_prior_comparison_digits_decrease",
              increase_id = "psd_prior_comparison_digits_increase",
              auto_id = "psd_prior_comparison_digits_auto",
              display_id = "psd_prior_comparison_digits_display",
              table_label = psd_comparison_table_label
            ),
            tags$div(
              style = "display: flex; gap: 10px; align-items: flex-start; flex-wrap: wrap; margin: 0 0 8px 0;",
              div(
                style = "min-width: 250px;",
                checkboxInput(
                  inputId = "psd_prior_comparison_changed_only",
                  label = "Show only variables with changes",
                  value = isTRUE(input$psd_prior_comparison_changed_only)
                )
              ),
              div(
                style = "min-width: 250px;",
                checkboxInput(
                  inputId = "psd_prior_comparison_selected_country_only",
                  label = "Selected country only",
                  value = isTRUE(input$psd_prior_comparison_selected_country_only)
                )
              ),
              div(
                style = "min-width: 250px;",
                checkboxInput(
                  inputId = "psd_prior_comparison_selected_year_only",
                  label = "Selected year only",
                  value = isTRUE(input$psd_prior_comparison_selected_year_only)
                )
              ),
              div(
                style = "min-width: 250px;",
                checkboxInput(
                  inputId = "psd_prior_comparison_selected_variable_only",
                  label = "Selected variable only",
                  value = isTRUE(input$psd_prior_comparison_selected_variable_only)
                )
              )
            ),
            tags$div(
              role = "region",
              `aria-label` = psd_comparison_table_label,
              dataTableOutput("psd_prior_comparison_table")
            )
          )
        )
      },
      if (identical(source_choice, "wasde")) {
        tabPanel(
          title = "Prior WASDE Comparison",
          value = "wasde_revision_comparison",
          div(
            style = "padding-top: 10px;",
            tags$p(
              style = "margin: 0 0 8px 0; color: #555; font-size: 12px;",
              paste0("Successful prior-release comparisons for the selected ", tolower(COMMODITY_TYPE_LABEL %||% "type"), " and country.")
            ),
            psd_table_decimal_controls(
              decrease_id = "wasde_prior_comparison_digits_decrease",
              increase_id = "wasde_prior_comparison_digits_increase",
              auto_id = "wasde_prior_comparison_digits_auto",
              display_id = "wasde_prior_comparison_digits_display",
              table_label = comparison_table_label
            ),
            tags$div(
              style = "display: flex; gap: 10px; align-items: flex-start; flex-wrap: wrap; margin: 0 0 8px 0;",
              div(
                style = "min-width: 250px;",
                checkboxInput(
                  inputId = "wasde_prior_comparison_changed_only",
                  label = "Show only variables with changes",
                  value = isTRUE(input$wasde_prior_comparison_changed_only)
                )
              ),
              div(
                style = "min-width: 290px;",
                checkboxInput(
                  inputId = "wasde_prior_comparison_sidebar_order",
                  label = "Sort variables by sidebar order",
                  value = isTRUE(input$wasde_prior_comparison_sidebar_order)
                )
              )
            ),
            tags$div(
              role = "region",
              `aria-label` = comparison_table_label,
              dataTableOutput("wasde_prior_comparison_table")
            )
          )
        )
      }
    )
  })

  output$psd_historical_records_table <- renderDT({
    start_time <- Sys.time()
    display_rows <- psd_historical_records_display_rows()
    source_choice <- current_source_choice_safe(default = input$data_source_choice %||% "export_sales")
    if (!is.data.frame(display_rows) || nrow(display_rows) == 0) {
      log_perf("psd_historical_records_table", start_time, details = list(status = "empty", rows = 0))
      return(NULL)
    }

    hidden_cols <- grep("^\\.\\.", names(display_rows))
    payload_cols <- c(
      country = match("..country", names(display_rows)) - 1L,
      commodity = match("..commodity", names(display_rows)) - 1L,
      metric = match("..metric_code", names(display_rows)) - 1L,
      basis = match("..basis_profile", names(display_rows)) - 1L,
      direction = match("..direction", names(display_rows)) - 1L,
      window = match("..window", names(display_rows)) - 1L,
      year = match("..market_year", names(display_rows)) - 1L
    )
    payload_cols_js <- jsonlite::toJSON(as.list(payload_cols), auto_unbox = TRUE)
    table_options_raw <- list(
      pageLength = 12,
      autoWidth = TRUE,
      dom = "ftip",
      columnDefs = list(list(targets = hidden_cols - 1L, visible = FALSE, searchable = FALSE))
    )

    if (identical(source_choice, "wasde")) {
      ties_sort_target <- dt_column_target(display_rows, "..ties_last_sort")
      pct_zero_sort_target <- dt_column_target(display_rows, "..pct_difference_zero_last_flag")
      pct_startup_sort_target <- dt_column_target(display_rows, "..pct_difference_startup_sort")
      fallback_sort_target <- dt_column_target(display_rows, "..fallback_sort_rank")

      startup_order <- list()
      if (length(ties_sort_target) > 0L) {
        startup_order <- c(startup_order, list(list(ties_sort_target[[1]], "asc")))
      }
      if (length(pct_zero_sort_target) > 0L) {
        startup_order <- c(startup_order, list(list(pct_zero_sort_target[[1]], "asc")))
      }
      if (length(pct_startup_sort_target) > 0L) {
        startup_order <- c(startup_order, list(list(pct_startup_sort_target[[1]], "asc")))
      }
      if (length(fallback_sort_target) > 0L) {
        startup_order <- c(startup_order, list(list(fallback_sort_target[[1]], "asc")))
      }

      if (length(startup_order) > 0L) {
        table_options_raw$order <- startup_order
      }
    }

    table_options <- psd_historical_records_search_options(table_options_raw)
    click_callback <- JS(
      paste(
        "var payloadCols =", payload_cols_js, ";",
        "table.on('click', 'tbody tr', function(){",
        "  var data = table.row(this).data();",
        "  if (!data) { return; }",
        "  table.$('tr.selected').removeClass('selected');",
        "  $(this).addClass('selected');",
        "  Shiny.setInputValue('psd_historical_records_row_click', {",
        "    country: data[payloadCols.country],",
        "    commodity: data[payloadCols.commodity],",
        "    metric: data[payloadCols.metric],",
        "    basis_profile: data[payloadCols.basis],",
        "    direction: data[payloadCols.direction],",
        "    window: data[payloadCols.window],",
        "    year: data[payloadCols.year],",
        "    nonce: Date.now()",
        "  }, {priority: 'event'});",
        "});"
      )
    )

    result <- datatable(
      display_rows,
      rownames = FALSE,
      escape = TRUE,
      selection = "none",
      options = table_options,
      callback = psd_historical_records_search_callback(callback = click_callback),
      class = "compact stripe hover"
    )

    log_perf("psd_historical_records_table", start_time, details = list(status = "ok", rows = nrow(display_rows)))
    result
  })

  observeEvent(input$psd_historical_records_row_click, {
    payload <- input$psd_historical_records_row_click
    if (is.null(payload) || !is.list(payload)) return()

    source_choice <- current_source_choice_safe()
    selected_country <- payload$country %||% NULL
    selected_commodity <- payload$commodity %||% NULL
    selected_metric <- payload$metric %||% NULL
    selected_year <- payload$year %||% NULL

    metric_choice_target <- if (identical(source_choice, "wasde")) {
      map_wasde_historical_metric_to_ui_metric(selected_metric)
    } else {
      selected_metric
    }

    if (!is.null(selected_country) && nzchar(selected_country)) {
      updateSelectInput(session, "country_choice", selected = selected_country)
    }
    if (!is.null(selected_commodity) && nzchar(selected_commodity)) {
      updateSelectInput(session, "commodity_choice", selected = selected_commodity)
    }
    if (!is.null(metric_choice_target) && nzchar(metric_choice_target)) {
      updateSelectInput(session, "metric_choice", selected = metric_choice_target)
    }
    if (!identical(source_choice, "wasde") && !is.null(selected_year) && nzchar(as.character(selected_year))) {
      updateSelectInput(session, "psd_historical_records_year", selected = as.character(selected_year))
    }

    updateTabsetPanel(session, "main_tabs_panel", selected = "Time Series Analysis Tool")
    updateTabsetPanel(session, "psd_time_series_bottom_view", selected = "historical_records")
  })

  observeEvent(input$wasde_prior_comparison_row_click, {
    payload <- input$wasde_prior_comparison_row_click
    if (is.null(payload) || !is.list(payload)) return()

    source_choice <- current_source_choice_safe()
    if (!identical(source_choice, "wasde")) return()

    selected_metric <- trimws(as.character(payload$metric %||% ""))
    selected_metric <- selected_metric[!is.na(selected_metric) & nzchar(selected_metric)]
    if (length(selected_metric) != 1L) return()

    valid_metrics <- trimws(as.character(unname(metric_choices_for_current_context())))
    valid_metrics <- valid_metrics[!is.na(valid_metrics) & nzchar(valid_metrics)]
    if (!(selected_metric[[1]] %in% valid_metrics)) return()

    updateRadioButtons(session, "metric_choice", selected = selected_metric[[1]])
  })

  build_psd_revision_comparison_rows <- function(selected_commodity = input$commodity_choice %||% default_commodity_choice_value()) {
    start_time <- Sys.time()
    commodity_values <- trimws(as.character(selected_commodity %||% character(0)))
    commodity_values <- commodity_values[!is.na(commodity_values) & nzchar(commodity_values)]
    commodity_value <- if (length(commodity_values) > 0L) commodity_values[[1L]] else default_commodity_choice_value()

    source_df <- load_psd_revision_delta()
    required_cols <- c(
      "country", "countryDescription", "commodity", "market_year", "normalized_metric_id", "attribute_name", "canonical_unit",
      "current_value_canonical", "prior_value_canonical", "value_difference", "percent_difference",
      "current_release_year", "current_release_month", "current_release_period", "current_release_ord",
      "prior_release_year", "prior_release_month", "prior_release_period", "prior_release_ord",
      "prior_release_available", "simulated_delta_active", "development_placeholder"
    )
    if (!is.data.frame(source_df) || nrow(source_df) == 0L || !all(required_cols %in% names(source_df))) {
      log_perf("build_psd_revision_comparison_rows()", start_time, details = list(status = "empty_or_invalid_source", rows = 0))
      return(data.frame())
    }
    if (!("release_gap_months" %in% names(source_df))) {
      source_df$release_gap_months <- NA_real_
    }

    visible_metric_ids <- unique(trimws(as.character(unname(get_metric_choices_for_context(
      active_tab = "Time Series Analysis Tool",
      source_choice = "psd",
      data_frequency = "monthly"
    )))))
    visible_metric_ids <- visible_metric_ids[!is.na(visible_metric_ids) & nzchar(visible_metric_ids)]
    psd_revision_metric_code_for_id <- function(metric_ids) {
      metric_ids <- trimws(as.character(metric_ids))
      metric_codes <- unname(psd_metric_column_map[metric_ids])
      metric_codes[metric_ids == "milling_rate"] <- "psd_milling_rate"
      metric_codes[is.na(metric_codes) | !nzchar(metric_codes)] <- NA_character_
      metric_codes
    }
    comparison_value_digits <- psd_table_value_digits_for_formatter(psd_prior_comparison_value_digits())

    release_period_label <- function(release_period, release_year, release_month) {
      release_period_clean <- trimws(as.character(release_period %||% ""))
      release_period_clean <- ifelse(is.na(release_period_clean), "", release_period_clean)
      fallback_label <- ifelse(
        !is.na(release_year) & !is.na(release_month),
        sprintf("%04d-%02d", suppressWarnings(as.integer(release_year)), suppressWarnings(as.integer(release_month))),
        NA_character_
      )
      ifelse(nzchar(release_period_clean), release_period_clean, fallback_label)
    }

    out <- source_df %>%
      mutate(
        market_year = suppressWarnings(as.integer(.data$market_year)),
        current_release_ord = suppressWarnings(as.integer(.data$current_release_ord)),
        prior_release_ord = suppressWarnings(as.integer(.data$prior_release_ord)),
        release_gap_months = suppressWarnings(as.numeric(.data$release_gap_months)),
        prior_release_available = dplyr::coalesce(as.logical(.data$prior_release_available), FALSE),
        simulated_delta_active = dplyr::coalesce(as.logical(.data$simulated_delta_active), FALSE),
        development_placeholder = dplyr::coalesce(as.logical(.data$development_placeholder), FALSE),
        metric_code = psd_revision_metric_code_for_id(.data$normalized_metric_id),
        current_value_native = suppressWarnings(as.numeric(.data$current_value_canonical)),
        prior_value_native = suppressWarnings(as.numeric(.data$prior_value_canonical)),
        revision_change_native = suppressWarnings(as.numeric(.data$value_difference)),
        revision_pct_change_native = suppressWarnings(as.numeric(.data$percent_difference))
      ) %>%
      filter(
        .data$commodity == commodity_value,
        .data$prior_release_available,
        is.finite(.data$market_year),
        is.finite(.data$current_release_ord),
        is.finite(.data$prior_release_ord),
        !is.na(.data$metric_code),
        nzchar(.data$metric_code)
      )

    if (is.data.frame(out) && nrow(out) > 0L) {
      latest_current_release_ord <- suppressWarnings(max(out$current_release_ord, na.rm = TRUE))
      if (is.finite(latest_current_release_ord)) {
        out <- out %>% filter(.data$current_release_ord == latest_current_release_ord)
      }
    }

    if (length(visible_metric_ids) > 0L) {
      out <- out %>% filter(.data$metric_code %in% visible_metric_ids)
    }
    if (!is.data.frame(out) || nrow(out) == 0L) {
      log_perf("build_psd_revision_comparison_rows()", start_time, details = list(status = "empty_filtered_source", rows = 0, commodity = commodity_value))
      return(data.frame())
    }

    out <- out %>%
      mutate(
        period_label = paste0("MY ", .data$market_year),
        attribute_label = dplyr::coalesce(dplyr::na_if(trimws(as.character(.data$attribute_name)), ""), trimws(as.character(.data$normalized_metric_id))),
        unit_display = dplyr::coalesce(dplyr::na_if(trimws(as.character(.data$canonical_unit)), ""), "PSD Unit"),
        current_release_label = release_period_label(.data$current_release_period, .data$current_release_year, .data$current_release_month),
        prior_release_label = release_period_label(.data$prior_release_period, .data$prior_release_year, .data$prior_release_month),
        current_estimate_display = mapply(function(value, metric_id) format_map_summary_value(value, metric_code = metric_id, value_digits = comparison_value_digits), .data$current_value_native, .data$metric_code, USE.NAMES = FALSE),
        prior_psd_display = mapply(function(value, metric_id) format_map_summary_value(value, metric_code = metric_id, value_digits = comparison_value_digits), .data$prior_value_native, .data$metric_code, USE.NAMES = FALSE),
        change_from_prior_display = mapply(function(value, metric_id) format_map_summary_value(value, metric_code = metric_id, value_digits = comparison_value_digits), .data$revision_change_native, .data$metric_code, USE.NAMES = FALSE),
        percent_change_display = ifelse(is.finite(.data$revision_pct_change_native), format_fixed_display_value_preserve_zeros(.data$revision_pct_change_native, digits = 2L, blank_for_na = TRUE), "")
      ) %>%
      arrange(desc(.data$market_year), desc(abs(.data$revision_pct_change_native)), .data$countryDescription, .data$attribute_label) %>%
      transmute(
        period_label = .data$period_label,
        period_sort = .data$market_year,
        country = .data$country,
        countryDescription = .data$countryDescription,
        commodity = .data$commodity,
        normalized_metric_id = .data$normalized_metric_id,
        metric_code = .data$metric_code,
        attribute_label = .data$attribute_label,
        unit_display = .data$unit_display,
        current_estimate_display = .data$current_estimate_display,
        prior_psd_display = .data$prior_psd_display,
        change_from_prior_display = .data$change_from_prior_display,
        percent_change_display = .data$percent_change_display,
        current_release_label = .data$current_release_label,
        prior_release_label = .data$prior_release_label,
        release_gap_months = .data$release_gap_months,
        simulated_delta_active = .data$simulated_delta_active,
        development_placeholder = .data$development_placeholder,
        revision_change_native = .data$revision_change_native,
        revision_pct_change_native = .data$revision_pct_change_native
      )

    log_perf("build_psd_revision_comparison_rows()", start_time, details = list(status = "ok", rows = nrow(out), commodity = commodity_value))
    out
  }

  psd_prior_comparison_notice_states <- function(comparison_rows, manual_prior_metadata = NULL) {
    if (!is.data.frame(comparison_rows) || nrow(comparison_rows) == 0L) {
      return(tibble::tibble(type = character(), severity = character(), message = character()))
    }

    append_notice <- function(notices, type, severity, message) {
      rbind(
        notices,
        data.frame(type = type, severity = severity, message = message, stringsAsFactors = FALSE)
      )
    }

    notices <- data.frame(type = character(), severity = character(), message = character(), stringsAsFactors = FALSE)
    simulated_active <- "simulated_delta_active" %in% names(comparison_rows) && any(as.logical(comparison_rows$simulated_delta_active), na.rm = TRUE)
    development_active <- "development_placeholder" %in% names(comparison_rows) && any(as.logical(comparison_rows$development_placeholder), na.rm = TRUE)
    if (isTRUE(simulated_active) || isTRUE(development_active)) {
      notices <- append_notice(
        notices,
        "simulated_delta_warning",
        "warning",
        "Prior PSD comparison is using legacy placeholder or simulated artifact values. Rebuild PSD processed data before using these rows for production review."
      )
    }

    has_displayable_world_rows <- "country" %in% names(comparison_rows) && any(trimws(as.character(comparison_rows$country)) == "GRAND_TOTAL", na.rm = TRUE)
    manual_prior_active <- is.list(manual_prior_metadata) && (
      isTRUE(manual_prior_metadata$manual_prior_mode) || identical(manual_prior_metadata$source_type %||% NA_character_, "manual_prior_psd_online_csv")
    )
    manual_world_status <- if (is.list(manual_prior_metadata)) {
      trimws(as.character((manual_prior_metadata$world_status %||% manual_prior_metadata$manual_prior_world_status) %||% ""))
    } else {
      ""
    }
    manual_prior_no_native_world <- isTRUE(manual_prior_active) && identical(manual_world_status, "manual_prior_no_native_world_rows")

    if (!isTRUE(has_displayable_world_rows)) {
      world_message <- if (isTRUE(manual_prior_no_native_world)) {
        "Note: World/Grand Total comparisons are not shown because the manual prior PSD Online source does not include World rows."
      } else {
        "Note: World/Grand Total comparisons are not shown because this comparison artifact does not contain paired World rows."
      }
      notices <- append_notice(notices, "world_missing", "info", world_message)
    }

    max_release_gap_months <- if ("release_gap_months" %in% names(comparison_rows)) {
      release_gap_values <- suppressWarnings(as.numeric(comparison_rows$release_gap_months))
      release_gap_values <- release_gap_values[is.finite(release_gap_values)]
      if (length(release_gap_values) > 0L) max(release_gap_values) else NA_real_
    } else {
      NA_real_
    }
    if (is.finite(max_release_gap_months) && max_release_gap_months > 1) {
      notices <- append_notice(
        notices,
        "release_gap_manual_prior_available",
        "warning",
        "Note: This comparison spans more than one PSD release month. If an intervening official release is available, download that PSD Online CSV into the matching Input/YYYY-MM folder and rebuild using the manual prior PSD CSV option."
      )
    }

    if (isTRUE(manual_prior_active)) {
      prior_period <- trimws(as.character((manual_prior_metadata$prior_release_period %||% manual_prior_metadata$prior_release_key) %||% ""))
      prior_period <- prior_period[!is.na(prior_period) & nzchar(prior_period)]
      attribution_message <- if (length(prior_period) > 0L) {
        paste0("Prior PSD values are sourced from the manual PSD Online CSV import for ", prior_period[[1L]], ".")
      } else {
        "Prior PSD values are sourced from a manual PSD Online CSV import."
      }
      notices <- append_notice(notices, "manual_prior_attribution", "info", attribution_message)
    }

    tibble::as_tibble(notices)
  }

  psd_prior_comparison_notice_div <- function(notice_state) {
    severity <- trimws(as.character(notice_state$severity %||% "info"))
    style <- if (identical(severity, "warning")) {
      "margin: 0 0 8px 0; padding: 6px 8px; border-left: 3px solid #b7791f; background: #fff8e1; color: #5f4700; font-size: 12px;"
    } else {
      "margin: 0 0 8px 0; padding: 6px 8px; border-left: 3px solid #2b6cb0; background: #ebf8ff; color: #1a365d; font-size: 12px;"
    }
    tags$div(style = style, notice_state$message %||% "")
  }

  output$psd_prior_comparison_notice_ui <- renderUI({
    source_choice <- current_source_choice_safe(default = input$data_source_choice %||% "export_sales")
    if (!identical(source_choice, "psd")) return(NULL)
    comparison_rows <- build_psd_revision_comparison_rows(selected_commodity = input$commodity_choice %||% default_commodity_choice_value())
    manual_prior_metadata <- if (exists("psd_revision_delta_manual_prior_metadata", mode = "function")) {
      tryCatch(psd_revision_delta_manual_prior_metadata(), error = function(...) NULL)
    } else {
      NULL
    }
    notice_states <- psd_prior_comparison_notice_states(comparison_rows, manual_prior_metadata = manual_prior_metadata)
    if (!is.data.frame(notice_states) || nrow(notice_states) == 0L) return(NULL)
    do.call(tagList, lapply(seq_len(nrow(notice_states)), function(idx) psd_prior_comparison_notice_div(notice_states[idx, , drop = FALSE])))
  })

  filter_psd_prior_comparison_rows_for_table <- function(comparison_rows, selected_variable_only = FALSE, changed_only = FALSE, selected_metric_code = "", selected_country_only = FALSE, selected_country_code = "", sort_zero_epsilon = 1e-12, selected_year_only = FALSE, selected_year = NA_integer_) {
    if (!is.data.frame(comparison_rows) || nrow(comparison_rows) == 0L) return(comparison_rows)

    selected_metric_values <- trimws(as.character(selected_metric_code %||% character(0)))
    selected_metric_values <- selected_metric_values[!is.na(selected_metric_values) & nzchar(selected_metric_values)]
    selected_metric_code <- if (length(selected_metric_values) > 0L) selected_metric_values[[1L]] else ""

    if (isTRUE(selected_country_only)) {
      selected_country_values <- trimws(as.character(selected_country_code %||% character(0)))
      selected_country_values <- selected_country_values[!is.na(selected_country_values) & nzchar(selected_country_values)]
      selected_country_code <- if (length(selected_country_values) > 0L) selected_country_values[[1L]] else ""

      if (nzchar(selected_country_code) && "country" %in% names(comparison_rows)) {
        country_pairs <- if (all(c("country", "countryDescription") %in% names(comparison_rows)) && exists("canonicalize_psd_country_pairs", mode = "function")) {
          canonicalize_psd_country_pairs(comparison_rows[, c("country", "countryDescription"), drop = FALSE])
        } else if ("countryDescription" %in% names(comparison_rows)) {
          unique(data.frame(country = as.character(comparison_rows$country), country_label = as.character(comparison_rows$countryDescription), stringsAsFactors = FALSE))
        } else {
          unique(data.frame(country = as.character(comparison_rows$country), country_label = as.character(comparison_rows$country), stringsAsFactors = FALSE))
        }
        country_pairs <- country_pairs[!is.na(country_pairs$country) & nzchar(country_pairs$country), , drop = FALSE]
        country_choices <- stats::setNames(country_pairs$country, country_pairs$country_label)
        resolved_country <- if (exists("resolve_psd_country_code", mode = "function")) {
          resolve_psd_country_code(selected_country_code, country_choices, base_choices = country_choices, default = NA_character_)
        } else if (selected_country_code %in% unname(country_choices)) {
          selected_country_code
        } else {
          NA_character_
        }
        resolved_country <- trimws(as.character(resolved_country %||% NA_character_))
        resolved_country <- resolved_country[!is.na(resolved_country) & nzchar(resolved_country)]
        if (length(resolved_country) > 0L) {
          comparison_rows <- comparison_rows %>% filter(.data$country == resolved_country[[1L]])
        } else {
          comparison_rows <- comparison_rows[0, , drop = FALSE]
        }
      } else {
        comparison_rows <- comparison_rows[0, , drop = FALSE]
      }
    }

    if (isTRUE(selected_variable_only)) {
      if (nzchar(selected_metric_code) && "metric_code" %in% names(comparison_rows)) {
        comparison_rows <- comparison_rows %>% filter(.data$metric_code == selected_metric_code)
      } else {
        comparison_rows <- comparison_rows[0, , drop = FALSE]
      }
    }

    if (isTRUE(selected_year_only)) {
      selected_year_values <- suppressWarnings(as.integer(selected_year %||% NA_integer_))
      selected_year_values <- selected_year_values[is.finite(selected_year_values)]
      selected_year_value <- if (length(selected_year_values) > 0L) selected_year_values[[1L]] else NA_integer_

      if (is.finite(selected_year_value) && "period_sort" %in% names(comparison_rows)) {
        comparison_rows <- comparison_rows %>% filter(.data$period_sort == .env$selected_year_value)
      } else {
        comparison_rows <- comparison_rows[0, , drop = FALSE]
      }
    }

    if (is.data.frame(comparison_rows) && nrow(comparison_rows) > 0L) {
      comparison_rows <- comparison_rows %>% mutate(`..changed_only_keep` = is.finite(.data$revision_change_native) & abs(.data$revision_change_native) > sort_zero_epsilon)
      if (isTRUE(changed_only)) comparison_rows <- comparison_rows %>% filter(.data$`..changed_only_keep`)
    }

    comparison_rows
  }

  psd_prior_comparison_empty_message <- function(selected_variable_only = FALSE, changed_only = FALSE, selected_country_only = FALSE, selected_year_only = FALSE, selected_year = NA_integer_) {
    if (!isTRUE(selected_year_only) && isTRUE(selected_country_only) && isTRUE(selected_variable_only) && isTRUE(changed_only)) {
      "No non-zero prior PSD comparison differences are available for the selected country and variable."
    } else if (!isTRUE(selected_year_only) && isTRUE(selected_country_only) && isTRUE(selected_variable_only)) {
      "No prior PSD comparison rows are available for the selected country and variable."
    } else if (!isTRUE(selected_year_only) && isTRUE(selected_country_only) && isTRUE(changed_only)) {
      "No non-zero prior PSD comparison differences are available for the selected country."
    } else if (!isTRUE(selected_year_only) && isTRUE(selected_country_only)) {
      "No prior PSD comparison rows are available for the selected country."
    } else if (!isTRUE(selected_year_only) && isTRUE(selected_variable_only) && isTRUE(changed_only)) {
      "No non-zero prior PSD comparison differences are available for the selected variable."
    } else if (!isTRUE(selected_year_only) && isTRUE(selected_variable_only)) {
      "No prior PSD comparison rows are available for the selected variable."
    } else if (!isTRUE(selected_year_only) && isTRUE(changed_only)) {
      paste0("No non-zero prior PSD comparison differences are available for the selected ", tolower(COMMODITY_TYPE_LABEL %||% "type"), ".")
    } else if (!isTRUE(selected_year_only)) {
      paste0("No successful prior PSD comparisons are available for the selected ", tolower(COMMODITY_TYPE_LABEL %||% "type"), ".")
    } else {
      selected_year_values <- suppressWarnings(as.integer(selected_year %||% NA_integer_))
      selected_year_values <- selected_year_values[is.finite(selected_year_values)]
      selected_year_label <- if (length(selected_year_values) > 0L) paste0("selected year (MY ", selected_year_values[[1L]], ")") else "selected year"
      scope_parts <- c(
        if (isTRUE(selected_country_only)) "selected country" else NULL,
        selected_year_label,
        if (isTRUE(selected_variable_only)) "selected variable" else NULL
      )
      scope_label <- if (length(scope_parts) == 1L) {
        scope_parts[[1L]]
      } else if (length(scope_parts) == 2L) {
        paste(scope_parts, collapse = " and ")
      } else {
        paste0(paste(scope_parts[-length(scope_parts)], collapse = ", "), ", and ", scope_parts[[length(scope_parts)]])
      }
      if (isTRUE(changed_only)) {
        paste0("No non-zero prior PSD comparison differences are available for the ", scope_label, ".")
      } else {
        paste0("No prior PSD comparison rows are available for the ", scope_label, ".")
      }
    }
  }

  output$psd_prior_comparison_table <- renderDT({
    start_time <- Sys.time()
    source_choice <- current_source_choice_safe(default = input$data_source_choice %||% "export_sales")
    changed_only <- isTRUE(input$psd_prior_comparison_changed_only)
    selected_country_only <- isTRUE(input$psd_prior_comparison_selected_country_only)
    selected_country_code <- trimws(as.character(input$country_choice %||% ""))
    selected_country_code <- selected_country_code[!is.na(selected_country_code) & nzchar(selected_country_code)]
    selected_country_code <- if (length(selected_country_code) > 0L) selected_country_code[[1L]] else ""
    selected_variable_only <- isTRUE(input$psd_prior_comparison_selected_variable_only)
    selected_metric_code <- ""
    sort_zero_epsilon <- 1e-12
    if (!identical(source_choice, "psd") || !is_time_series_source_active(source_choice = source_choice, active_tab = current_main_tab_safe())) return(NULL)

    selected_year_only <- isTRUE(input$psd_prior_comparison_selected_year_only)
    selected_year <- NA_integer_
    if (isTRUE(selected_year_only)) {
      selected_year_values <- suppressWarnings(as.integer(time_series_historical_selected_year()))
      selected_year_values <- selected_year_values[is.finite(selected_year_values)]
      selected_year <- if (length(selected_year_values) > 0L) selected_year_values[[1L]] else NA_integer_
    }

    comparison_rows <- build_psd_revision_comparison_rows(selected_commodity = input$commodity_choice %||% default_commodity_choice_value())
    if (isTRUE(selected_variable_only)) {
      selected_metric_values <- trimws(as.character(effective_main_metric() %||% character(0)))
      selected_metric_values <- selected_metric_values[!is.na(selected_metric_values) & nzchar(selected_metric_values)]
      selected_metric_code <- if (length(selected_metric_values) > 0L) selected_metric_values[[1L]] else ""
    }
    comparison_rows <- filter_psd_prior_comparison_rows_for_table(
      comparison_rows,
      selected_variable_only = selected_variable_only,
      changed_only = changed_only,
      selected_metric_code = selected_metric_code,
      selected_country_only = selected_country_only,
      selected_country_code = selected_country_code,
      sort_zero_epsilon = sort_zero_epsilon,
      selected_year_only = selected_year_only,
      selected_year = selected_year
    )

    if (!is.data.frame(comparison_rows) || nrow(comparison_rows) == 0L) {
      empty_message <- psd_prior_comparison_empty_message(selected_variable_only = selected_variable_only, changed_only = changed_only, selected_country_only = selected_country_only, selected_year_only = selected_year_only, selected_year = selected_year)
      log_perf("psd_prior_comparison_table", start_time, details = list(status = "empty", rows = 0, changed_only = changed_only, selected_country_only = selected_country_only, selected_country = selected_country_code, selected_year_only = selected_year_only, selected_year = selected_year, selected_year_source = "psd_historical_records_year", selected_variable_only = selected_variable_only, selected_metric = selected_metric_code))
      return(datatable(data.frame(Message = empty_message, stringsAsFactors = FALSE), options = list(dom = "t", ordering = FALSE, searching = FALSE, paging = FALSE, stateSave = FALSE), rownames = FALSE, selection = "none"))
    }

    comparison_table <- comparison_rows %>%
      transmute(
        "Period" = .data$period_label,
        "Country" = .data$countryDescription,
        "Attribute" = .data$attribute_label,
        "Current Estimate" = .data$current_estimate_display,
        "Prior PSD" = .data$prior_psd_display,
        "Difference" = .data$change_from_prior_display,
        "% Difference" = .data$percent_change_display,
        "Current Release" = .data$current_release_label,
        "Prior Release" = .data$prior_release_label,
        "Unit/Basis" = .data$unit_display,
        "..country" = .data$country,
        "..metric_code" = .data$metric_code,
        "..period_sort" = .data$period_sort,
        "..abs_pct_sort" = abs(.data$revision_pct_change_native)
      )

    period_sort_target <- dt_column_target(comparison_table, "..period_sort")
    abs_pct_sort_target <- dt_column_target(comparison_table, "..abs_pct_sort")
    country_target <- dt_column_target(comparison_table, "..country")
    metric_target <- dt_column_target(comparison_table, "..metric_code")
    hidden_targets <- grep("^\\.\\.", names(comparison_table)) - 1L
    hidden_targets <- as.integer(hidden_targets[hidden_targets >= 0L])

    result <- datatable(
      comparison_table,
      rownames = FALSE,
      selection = "none",
      escape = TRUE,
      options = list(pageLength = 25, lengthMenu = c(10, 25, 50, 100), stateSave = TRUE, order = list(list(period_sort_target, "desc"), list(abs_pct_sort_target, "desc")), columnDefs = list(list(visible = FALSE, targets = hidden_targets))),
      callback = JS(sprintf("table.on('click', 'tbody tr', function() { var row = table.row(this).data(); if (!row) return; Shiny.setInputValue('psd_prior_comparison_row_click', {country: row[%d], metric: row[%d], nonce: Date.now()}, {priority: 'event'}); });", country_target, metric_target)),
      class = "compact stripe hover"
    )

    log_perf("psd_prior_comparison_table", start_time, details = list(status = "ok", rows = nrow(comparison_table), changed_only = changed_only, selected_country_only = selected_country_only, selected_country = selected_country_code, selected_year_only = selected_year_only, selected_year = selected_year, selected_year_source = "psd_historical_records_year", selected_variable_only = selected_variable_only, selected_metric = selected_metric_code))
    result
  })

  observeEvent(input$psd_prior_comparison_row_click, {
    payload <- input$psd_prior_comparison_row_click
    if (is.null(payload) || !is.list(payload)) return()
    if (!identical(current_source_choice_safe(default = input$data_source_choice %||% "export_sales"), "psd")) return()
    if (!isTRUE(psd_prior_release_comparison_enabled())) return()
    selected_country <- trimws(as.character(payload$country %||% ""))
    selected_metric <- trimws(as.character(payload$metric %||% ""))
    if (!nzchar(selected_country) || !nzchar(selected_metric)) return()

    updateSelectInput(session, "country_choice", selected = selected_country)
  updateRadioButtons(session, "metric_choice", selected = selected_metric)
    write_canonical_psd_country(selected_country)
    if (exists("sync_psd_map_country_input", mode = "function")) {
      sync_psd_map_country_input(selected_country, issuer_event = "psd_prior_comparison_row_click")
    }
    updateTabsetPanel(session, "psd_time_series_bottom_view", selected = "psd_revision_comparison")
  }, ignoreInit = TRUE)

  output$psd_time_series_summary_table <- renderDT({
    start_time <- Sys.time()
    source_choice <- current_source_choice_safe()

    bundle <- psd_time_series_annual_bundle()

    if (!identical(bundle$status, "ok") || nrow(bundle$table_df) == 0) {
      log_perf(
        "psd_time_series_summary_table",
        start_time,
        details = list(status = bundle$status %||% "unknown", rows = 0)
      )
      return(NULL)
    }

    summary_table <- build_time_series_annual_summary_rows(
      bundle,
      value_digits = psd_time_series_summary_value_digits()
    )

    if (!is.data.frame(summary_table) || nrow(summary_table) == 0) {
      log_perf(
        "psd_time_series_summary_table",
        start_time,
        details = list(status = "empty_summary_rows", rows = 0)
      )
      return(NULL)
    }

    summary_caption_unit <- bundle$unit_label %||% get_metric_measurement_label(
      metric_code = bundle$metric_col,
      source_choice = source_choice,
      unit_choice = input$unit_choice,
      basis_choice = current_psd_time_series_basis_choice_safe(metric_code = bundle$metric_col),
      value_unit_choice = current_census_value_unit_choice_safe(source_choice = source_choice, metric_code = bundle$metric_col),
      commodity_name = input$commodity_choice,
      active_tab = current_main_tab_safe()
    )
    summary_caption <- tags$caption(
      style = "caption-side: top; text-align: left; color: #4b5563; padding-bottom: 6px;",
      paste0("Summary statistics shown in ", summary_caption_unit, ".")
    )

    result <- datatable(
      summary_table,
      caption = summary_caption,
      rownames = FALSE,
      options = list(pageLength = 12, autoWidth = TRUE, dom = "tip"),
      class = "compact stripe"
    )

    log_perf(
      "psd_time_series_summary_table",
      start_time,
      details = list(mode = "trendline", source = source_choice, metric = bundle$metric_col, rows = nrow(summary_table))
    )

    result
  })

  output$wasde_prior_comparison_table <- renderDT({
    start_time <- Sys.time()
    source_choice <- current_source_choice_safe(default = input$data_source_choice %||% "export_sales")
    sort_zero_epsilon <- 1e-12
    changed_only <- isTRUE(input$wasde_prior_comparison_changed_only)
    sidebar_order <- isTRUE(input$wasde_prior_comparison_sidebar_order)

    if (!identical(source_choice, "wasde") || !is_time_series_source_active(source_choice = source_choice, active_tab = current_main_tab_safe())) {
      return(NULL)
    }

    comparison_rows <- build_wasde_revision_comparison_rows(
      selected_country = input$country_choice %||% "U_S",
      selected_commodity = input$commodity_choice %||% default_commodity_choice_value()
    )

    if (!is.data.frame(comparison_rows) || nrow(comparison_rows) == 0) {
      log_perf(
        "wasde_prior_comparison_table",
        start_time,
        details = list(status = "empty", rows = 0, changed_only = changed_only, sidebar_order = sidebar_order)
      )
      return(datatable(
        data.frame(
          Message = paste0("No successful prior WASDE comparisons are available for the selected ", tolower(COMMODITY_TYPE_LABEL %||% "type"), " and country."),
          stringsAsFactors = FALSE
        ),
        options = list(dom = "t", ordering = FALSE, searching = FALSE, paging = FALSE, stateSave = FALSE),
        rownames = FALSE,
        selection = "none"
      ))
    }

    sidebar_metric_ids <- unique(trimws(as.character(unname(get_metric_choices_for_context(
      active_tab = "Time Series Analysis Tool",
      source_choice = "wasde",
      data_frequency = "monthly"
    )))))
    sidebar_metric_ids <- sidebar_metric_ids[!is.na(sidebar_metric_ids) & nzchar(sidebar_metric_ids)]
    sidebar_rank_lookup <- stats::setNames(seq_along(sidebar_metric_ids), sidebar_metric_ids)

    comparison_rows <- comparison_rows %>%
      mutate(
        `..changed_only_keep` = is.finite(.data$revision_change_native) & abs(.data$revision_change_native) > sort_zero_epsilon,
        `..sidebar_rank` = {
          metric_ids <- trimws(as.character(.data$normalized_metric_id))
          suppressWarnings(as.integer(unname(sidebar_rank_lookup[metric_ids])))
        },
        `..sidebar_rank_missing` = dplyr::if_else(is.finite(.data$`..sidebar_rank`), 0L, 1L),
        `..attribute_fallback_sort` = tolower(trimws(as.character(.data$attribute_label)))
      )

    if (isTRUE(changed_only)) {
      comparison_rows <- comparison_rows %>% filter(.data$`..changed_only_keep`)
    }

    if (!is.data.frame(comparison_rows) || nrow(comparison_rows) == 0) {
      empty_message <- if (isTRUE(changed_only)) {
        paste0("No non-zero prior WASDE comparison differences are available for the selected ", tolower(COMMODITY_TYPE_LABEL %||% "type"), " and country.")
      } else {
        paste0("No successful prior WASDE comparisons are available for the selected ", tolower(COMMODITY_TYPE_LABEL %||% "type"), " and country.")
      }

      log_perf(
        "wasde_prior_comparison_table",
        start_time,
        details = list(status = "empty_after_filter", rows = 0, changed_only = changed_only, sidebar_order = sidebar_order)
      )

      return(datatable(
        data.frame(
          Message = empty_message,
          stringsAsFactors = FALSE
        ),
        options = list(dom = "t", ordering = FALSE, searching = FALSE, paging = FALSE, stateSave = FALSE),
        rownames = FALSE,
        selection = "none"
      ))
    }

    comparison_table <- comparison_rows %>%
      transmute(
        "Period" = .data$period_label,
        "Attribute" = .data$attribute_label,
        "Current Estimate" = .data$current_estimate_display,
        "Prior WASDE" = .data$prior_wasde_display,
        "Difference" = .data$change_from_prior_display,
        "% Difference" = .data$percent_change_display,
        "Current Release" = .data$current_release_label,
        "Prior Release" = .data$prior_release_label,
        "Unit/Basis" = .data$unit_display,
        "..metric_code" = .data$normalized_metric_id,
        "..period_sort" = .data$period_sort,
        "..sidebar_rank_missing" = .data$`..sidebar_rank_missing`,
        "..sidebar_rank" = .data$`..sidebar_rank`,
        "..attribute_fallback_sort" = .data$`..attribute_fallback_sort`,
        "..change_sort_value" = dplyr::if_else(is.finite(.data$revision_change_native), .data$revision_change_native, NA_real_),
        "..change_zero_last_flag" = dplyr::if_else(
          !is.finite(.data$revision_change_native) | abs(.data$revision_change_native) <= sort_zero_epsilon,
          1L,
          0L
        ),
        "..pct_change_sort_value" = dplyr::if_else(is.finite(.data$revision_pct_change_native), .data$revision_pct_change_native, NA_real_),
        "..pct_change_zero_last_flag" = dplyr::if_else(
          !is.finite(.data$revision_pct_change_native) | abs(.data$revision_pct_change_native) <= sort_zero_epsilon,
          1L,
          0L
        )
      ) %>%
      group_by(.data$`..period_sort`) %>%
      mutate(
        `..pct_diff_non_zero` = is.finite(.data$`..pct_change_sort_value`) & abs(.data$`..pct_change_sort_value`) > sort_zero_epsilon,
        `..pct_diff_anchor_abs` = if (any(.data$`..pct_diff_non_zero`)) max(abs(.data$`..pct_change_sort_value`[.data$`..pct_diff_non_zero`]), na.rm = TRUE) else NA_real_,
        `..pct_diff_anchor_positive` = ifelse(
          is.finite(.data$`..pct_diff_anchor_abs`),
          any(
            .data$`..pct_diff_non_zero` &
              abs(abs(.data$`..pct_change_sort_value`) - .data$`..pct_diff_anchor_abs`) <= sort_zero_epsilon &
              .data$`..pct_change_sort_value` > 0
          ),
          FALSE
        ),
        `..pct_diff_anchor_negative` = ifelse(
          is.finite(.data$`..pct_diff_anchor_abs`),
          any(
            .data$`..pct_diff_non_zero` &
              abs(abs(.data$`..pct_change_sort_value`) - .data$`..pct_diff_anchor_abs`) <= sort_zero_epsilon &
              .data$`..pct_change_sort_value` < 0
          ),
          FALSE
        ),
        `..pct_diff_direction_sign` = dplyr::case_when(
          !is.finite(.data$`..pct_diff_anchor_abs`) ~ 0L,
          .data$`..pct_diff_anchor_positive` ~ 1L,
          .data$`..pct_diff_anchor_negative` ~ -1L,
          TRUE ~ 1L
        ),
        `..pct_diff_init_sort_value` = dplyr::if_else(
          .data$`..pct_change_zero_last_flag` == 1L,
          NA_real_,
          dplyr::if_else(
            .data$`..pct_diff_direction_sign` >= 0L,
            -.data$`..pct_change_sort_value`,
            .data$`..pct_change_sort_value`
          )
        ),
        `..pct_diff_fallback_rank` = dplyr::row_number()
      ) %>%
      ungroup() %>%
      select(
        -"..pct_diff_non_zero",
        -"..pct_diff_anchor_abs",
        -"..pct_diff_anchor_positive",
        -"..pct_diff_anchor_negative",
        -"..pct_diff_direction_sign"
      )

    period_sort_target <- dt_column_target(comparison_table, "..period_sort")
    change_target <- dt_column_target(comparison_table, "Difference")
    percent_change_target <- dt_column_target(comparison_table, "% Difference")
    change_sort_target <- dt_column_target(comparison_table, "..change_sort_value")
    change_zero_target <- dt_column_target(comparison_table, "..change_zero_last_flag")
    pct_change_sort_target <- dt_column_target(comparison_table, "..pct_change_sort_value")
    pct_change_zero_target <- dt_column_target(comparison_table, "..pct_change_zero_last_flag")
    pct_diff_init_sort_target <- dt_column_target(comparison_table, "..pct_diff_init_sort_value")
    pct_diff_fallback_rank_target <- dt_column_target(comparison_table, "..pct_diff_fallback_rank")
    sidebar_rank_missing_target <- dt_column_target(comparison_table, "..sidebar_rank_missing")
    sidebar_rank_target <- dt_column_target(comparison_table, "..sidebar_rank")
    attribute_fallback_sort_target <- dt_column_target(comparison_table, "..attribute_fallback_sort")
    metric_code_target <- dt_column_target(comparison_table, "..metric_code")

    hidden_targets <- grep("^\\.\\.", names(comparison_table)) - 1L
    hidden_targets <- as.integer(hidden_targets[hidden_targets >= 0L])

    column_defs <- list()
    if (length(hidden_targets) > 0L) {
      column_defs <- c(column_defs, list(list(targets = hidden_targets, visible = FALSE, searchable = FALSE)))
    }
    if (length(change_target) > 0L && length(change_zero_target) > 0L && length(change_sort_target) > 0L) {
      column_defs <- c(column_defs, list(list(targets = change_target, orderData = c(change_zero_target, change_sort_target))))
    }
    if (length(percent_change_target) > 0L && length(pct_change_zero_target) > 0L && length(pct_change_sort_target) > 0L) {
      column_defs <- c(column_defs, list(list(targets = percent_change_target, orderData = c(pct_change_zero_target, pct_change_sort_target))))
    }

    period_order_target <- if (length(period_sort_target) > 0L) period_sort_target[[1]] else 0L
    table_order <- list(list(period_order_target, "desc"))
    if (isTRUE(sidebar_order) && length(sidebar_rank_missing_target) > 0L && length(sidebar_rank_target) > 0L) {
      table_order <- c(table_order, list(
        list(sidebar_rank_missing_target[[1]], "asc"),
        list(sidebar_rank_target[[1]], "asc")
      ))
      if (length(attribute_fallback_sort_target) > 0L) {
        table_order <- c(table_order, list(list(attribute_fallback_sort_target[[1]], "asc")))
      }
    } else if (length(pct_change_zero_target) > 0L && length(pct_diff_init_sort_target) > 0L) {
      table_order <- c(table_order, list(
        list(pct_change_zero_target[[1]], "asc"),
        list(pct_diff_init_sort_target[[1]], "asc")
      ))
      if (length(pct_diff_fallback_rank_target) > 0L) {
        table_order <- c(table_order, list(list(pct_diff_fallback_rank_target[[1]], "asc")))
      }
    } else if (length(percent_change_target) > 0L) {
      table_order <- c(table_order, list(list(percent_change_target[[1]], "desc")))
    }

    table_options <- list(
      pageLength = 20,
      autoWidth = TRUE,
      dom = "tip",
      order = table_order,
      columnDefs = column_defs
    )

    metric_payload_cols <- list(metric = if (length(metric_code_target) > 0L) metric_code_target[[1]] else NA_integer_)
    metric_payload_cols_js <- jsonlite::toJSON(metric_payload_cols, auto_unbox = TRUE)
    click_callback <- JS(
      paste(
        "var payloadCols =", metric_payload_cols_js, ";",
        "table.on('click', 'tbody tr', function(){",
        "  var data = table.row(this).data();",
        "  if (!data || payloadCols.metric === null || payloadCols.metric === undefined || payloadCols.metric < 0) { return; }",
        "  var metric = data[payloadCols.metric];",
        "  if (metric === null || metric === undefined || String(metric).trim() === '') { return; }",
        "  table.$('tr.selected').removeClass('selected');",
        "  $(this).addClass('selected');",
        "  Shiny.setInputValue('wasde_prior_comparison_row_click', {",
        "    metric: metric,",
        "    nonce: Date.now() + Math.random()",
        "  }, {priority: 'event'});",
        "});"
      )
    )

    result <- datatable(
      comparison_table,
      rownames = FALSE,
      options = table_options,
      selection = "none",
      callback = click_callback,
      class = "compact stripe hover"
    )

    log_perf(
      "wasde_prior_comparison_table",
      start_time,
      details = list(
        status = "ok",
        rows = nrow(comparison_table),
        changed_only = changed_only,
        sidebar_order = sidebar_order,
        attributes = dplyr::n_distinct(comparison_rows$normalized_metric_id),
        market_year_min = suppressWarnings(min(comparison_rows$market_year, na.rm = TRUE)),
        market_year_max = suppressWarnings(max(comparison_rows$market_year, na.rm = TRUE))
      )
    )

    result
  })

  output$psd_time_series_plot <- renderPlotly({
    start_time <- Sys.time()
    source_choice <- current_source_choice_safe()

    if (!is_time_series_source_active(source_choice = source_choice, active_tab = current_main_tab_safe())) {
      return(plotly_empty_state(plot_title = "Annual time series unavailable"))
    }

    bundle <- psd_time_series_annual_bundle()
    if (!identical(bundle$status, "ok") || nrow(bundle$plot_df) == 0) {
      return(plotly_empty_state(plot_title = "No annual time series available"))
    }

    plot_df <- bundle$plot_df
    metric_col <- bundle$metric_col
    positive_plot_df <- plot_df %>%
      filter(!is.na(.data$current_value), is.finite(.data$current_value), .data$current_value > 0)

    if (nrow(positive_plot_df) > 0) {
      min_row <- positive_plot_df %>%
        filter(.data$current_value == min(.data$current_value, na.rm = TRUE)) %>%
        slice(1)

      max_row <- positive_plot_df %>%
        filter(.data$current_value == max(.data$current_value, na.rm = TRUE)) %>%
        slice(1)
    } else {
      min_row <- positive_plot_df
      max_row <- positive_plot_df
    }

    metric_label <- bundle$metric_label

    format_annotation_value <- function(value) {
      formatted <- format_time_series_annual_display_value(
        value,
        metric_code = metric_col,
        source_choice = bundle$source_choice %||% source_choice
      )
      if (is.null(formatted) || length(formatted) == 0) {
        return(NA_character_)
      }

      as.character(formatted[[1]])
    }

    annual_annotations <- list()
    if (nrow(min_row) > 0) {
      annual_annotations[[length(annual_annotations) + 1]] <- list(
        x = min_row$period_index[[1]],
        y = min_row$current_value[[1]],
        text = paste0("Min: ", min_row$period_label[[1]], " (", format_annotation_value(min_row$current_value[[1]]), ")"),
        showarrow = TRUE,
        arrowhead = 2,
        ax = 0,
        ay = 35,
        bgcolor = "rgba(255,255,255,0.9)",
        bordercolor = "#2c7fb8"
      )
    }

    if (nrow(max_row) > 0) {
      annual_annotations[[length(annual_annotations) + 1]] <- list(
        x = max_row$period_index[[1]],
        y = max_row$current_value[[1]],
        text = paste0("Max: ", max_row$period_label[[1]], " (", format_annotation_value(max_row$current_value[[1]]), ")"),
        showarrow = TRUE,
        arrowhead = 2,
        ax = 0,
        ay = -35,
        bgcolor = "rgba(255,255,255,0.9)",
        bordercolor = "#2c7fb8"
      )
    }

    xaxis_layout <- list(title = "Market Year")
    if (nrow(plot_df) > 0) {
      xaxis_layout$tickmode <- "array"
      xaxis_layout$tickvals <- plot_df$period_index
      xaxis_layout$ticktext <- plot_df$period_label
      xaxis_layout$range <- c(min(plot_df$period_index) - 0.25, max(plot_df$period_index) + 0.25)
    }

    out <- plot_ly(plot_df) %>%
      add_trace(
        x = ~period_index,
        y = ~current_value,
        text = ~period_label,
        hovertemplate = paste0("%{text}<br>", metric_label, ": %{y:.2f}<extra></extra>"),
        name = "Annual Value",
        type = "scatter",
        mode = "lines+markers",
        line = list(color = "#2c7fb8", width = 3),
        marker = list(size = 8)
      )

    if (isTRUE(bundle$fit_available)) {
      out <- out %>%
        add_trace(
          data = plot_df %>% filter(is.finite(.data$fitted_value)),
          x = ~period_index,
          y = ~fitted_value,
          text = ~period_label,
          hovertemplate = paste0("%{text}<br>OLS Trendline: %{y:.2f}<extra></extra>"),
          name = bundle$trendline_label,
          type = "scatter",
          mode = "lines",
          line = list(color = "#ff7f0e", width = 2.5, dash = "dash")
        )
    }

    out <- out %>%
      add_markers(
        data = max_row,
        x = ~period_index,
        y = ~current_value,
        text = ~period_label,
        hovertemplate = paste0("%{text}<br>Max: %{y:.2f}<extra></extra>"),
        name = "Annual Max",
        marker = list(color = "#d7301f", size = 11),
        showlegend = FALSE
      ) %>%
      add_markers(
        data = min_row,
        x = ~period_index,
        y = ~current_value,
        text = ~period_label,
        hovertemplate = paste0("%{text}<br>Min: %{y:.2f}<extra></extra>"),
        name = "Annual Min",
        marker = list(color = "#7a5195", size = 11),
        showlegend = FALSE
      ) %>%
      layout(
        title = bundle$base_title,
        xaxis = xaxis_layout,
        yaxis = list(title = paste0(metric_label, " (", bundle$unit_label, ")")),
        legend = list(orientation = "h", x = 0, y = 1.02, yanchor = "bottom"),
        annotations = annual_annotations,
        margin = list(t = 110),
        hovermode = "closest"
      )

    log_perf("psd_time_series_plot", start_time)
    out
  })

  # Output: Heatmap plot
  output$heatmap_plot <- renderPlotly({
    record_cache_body_execution(session, "heatmap_plot_executed")
    start_time <- Sys.time()
    df <- filtered_data()
    source_choice <- current_source_choice_safe(default = input$data_source_choice %||% "export_sales")
    display_year_type <- current_display_year_type(source_choice = source_choice)
    display_month_mapping <- current_display_month_mapping(source_choice = source_choice)
    display_month_axis_title <- current_display_month_axis_title(source_choice = source_choice, display_month_mapping = display_month_mapping)
    
    if (nrow(df) == 0) {
      return(plotly_empty_state(plot_title = "No data available"))
    }
    
    metric <- effective_main_metric()
    metric_code_active <- trimws(as.character(metric %||% ""))
    metric_unit_label <- get_metric_measurement_label(
      metric_code = metric,
      source_choice = source_choice,
      unit_choice = input$unit_choice,
      basis_choice = current_basis_choice_safe(),
      value_unit_choice = current_census_value_unit_choice_safe(
        source_choice = source_choice,
        metric_code = metric
      ),
      commodity_name = input$commodity_choice,
      active_tab = input$main_tabs_panel
    )

    if (identical(source_choice, "vp_trade") && metric_code_active %in% c("unit_value", "ytd_unit_value")) {
      heatmap_unit_context <- build_unit_resolution_context(
        tab_id = input$main_tabs_panel %||% current_main_tab_safe(),
        output_id = "heatmap_plot",
        source_choice = source_choice,
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
        market_scope = paste(sort(unique(stats::na.omit(as.character(df$market_year)))), collapse = "|"),
        rollup_level = input$vp_market_segment_choice %||% "",
        rollup_path = paste(
          input$vp_group_choice %||% "",
          input$vp_subgroup_choice %||% "",
          input$vp_market_segment_choice %||% "",
          sep = "|"
        ),
        run_id = "heatmap_plot_unit_resolution"
      )

      heatmap_unit_resolution <- tryCatch(
        resolve_vp_trade_display_unit(
          metric_code = metric_code_active,
          rows = df,
          context = heatmap_unit_context
        ),
        error = function(...) NULL
      )

      if (is.list(heatmap_unit_resolution)) {
        unit_guardrail_record_event(
          unit_resolution = heatmap_unit_resolution,
          context = heatmap_unit_context
        )
        if (!is.null(heatmap_unit_resolution$label) && nzchar(heatmap_unit_resolution$label)) {
          metric_unit_label <- heatmap_unit_resolution$label
        }
      }
    }
    
    # Create pivot table
    heatmap_base <- df %>%
      select(market_year, analysis_month, all_of(metric)) %>%
      dplyr::rename(value = all_of(metric))

    if (identical(input$data_frequency, "monthly")) {
      heatmap_period_counts <- heatmap_base %>%
        filter(!is.na(.data$analysis_month), is.finite(.data$analysis_month)) %>%
        distinct(.data$market_year, .data$analysis_month) %>%
        count(.data$market_year, name = "observed_periods")

      # Ensure a stable 12-month heatmap shape even when some months are missing.
      heatmap_base <- heatmap_base %>%
        group_by(market_year, analysis_month) %>%
        summarise(
          value = if (all(is.na(value))) NA_real_ else sum(value, na.rm = TRUE),
          .groups = "drop"
        ) %>%
        left_join(heatmap_period_counts, by = "market_year")

      if (identical(display_year_type, "fiscal") && nrow(heatmap_base) > 0) {
        current_heatmap_year <- suppressWarnings(max(heatmap_base$market_year, na.rm = TRUE))

        heatmap_base <- heatmap_base %>%
          mutate(observed_periods = dplyr::coalesce(.data$observed_periods, 0L)) %>%
          filter(.data$market_year == current_heatmap_year | .data$observed_periods >= 12L)
      }

      heatmap_base <- heatmap_base %>%
        select(-any_of("observed_periods")) %>%
        tidyr::complete(market_year, analysis_month = 1:12)
    } else {
      heatmap_period_counts <- heatmap_base %>%
        filter(!is.na(.data$analysis_month), is.finite(.data$analysis_month)) %>%
        distinct(.data$market_year, .data$analysis_month) %>%
        group_by(.data$market_year) %>%
        summarise(
          observed_periods = dplyr::n(),
          min_period = suppressWarnings(min(.data$analysis_month, na.rm = TRUE)),
          max_period = suppressWarnings(max(.data$analysis_month, na.rm = TRUE)),
          .groups = "drop"
        )

      heatmap_base <- heatmap_base %>%
        group_by(market_year, analysis_month) %>%
        summarise(
          value = if (all(is.na(value))) NA_real_ else sum(value, na.rm = TRUE),
          .groups = "drop"
        ) %>%
        left_join(heatmap_period_counts, by = "market_year")

      if (identical(display_year_type, "fiscal") && nrow(heatmap_base) > 0) {
        current_heatmap_year <- suppressWarnings(max(heatmap_base$market_year, na.rm = TRUE))

        heatmap_base <- heatmap_base %>%
          mutate(
            observed_periods = dplyr::coalesce(.data$observed_periods, 0L),
            min_period = dplyr::coalesce(.data$min_period, Inf),
            max_period = dplyr::coalesce(.data$max_period, -Inf)
          ) %>%
          filter(
            .data$market_year == current_heatmap_year |
              (.data$observed_periods >= 50L & .data$min_period <= 2L & .data$max_period >= 50L)
          )
      }

      heatmap_base <- heatmap_base %>%
        select(-any_of(c("observed_periods", "min_period", "max_period")))
    }

    heatmap_data <- heatmap_base %>%
      pivot_wider(
        names_from = analysis_month,
        values_from = value,
        values_fill = NA,
        values_fn = function(value) if (all(is.na(value))) NA_real_ else sum(value, na.rm = TRUE)
      ) %>%
      arrange(market_year)
    
    years_vec <- heatmap_data$market_year
    heatmap_matrix <- heatmap_data %>% select(-market_year) %>% as.matrix()
    heatmap_year_prefix <- build_display_year_short_prefix(source_choice = source_choice, display_month_mapping = display_month_mapping)
    heatmap_year_axis_title <- if (isTRUE(is_calendar_year_display_context(source_choice = source_choice, display_month_mapping = display_month_mapping))) {
      "Calendar Year"
    } else {
      "Market Year"
    }
    
    # Create x-axis labels based on frequency
    if (input$data_frequency == "monthly") {
      x_labels <- display_month_mapping$month_name
      x_title <- display_month_axis_title
      period_type <- "Monthly"
      x_axis_config <- list(title = x_title)
      hover_x_labels <- x_labels
    } else {
      x_title <- "Week Number"
      period_type <- "Weekly"
      x_labels <- seq_len(ncol(heatmap_matrix))
      hover_x_labels <- matrix(
        rep(paste0("Week ", seq_len(ncol(heatmap_matrix))), each = length(years_vec)),
        nrow = length(years_vec),
        ncol = ncol(heatmap_matrix),
        byrow = FALSE
      )

      current_label_source <- df %>%
        filter(market_year == max(market_year, na.rm = TRUE)) %>%
        select(analysis_month, week_ending_date) %>%
        distinct()

      x_axis_config <- build_weekly_x_axis_config_from_dates(
        label_source_df = current_label_source,
        axis_title = x_title,
        month_label_style = "abbrev",
        include_latest_label = TRUE,
        fallback_max_week = ncol(heatmap_matrix),
        year_type = display_year_type
      )
    }
    
    # Get metric display name for title/hover
    metric_display <- paste0(get_metric_label_for_context(metric), " (", metric_unit_label, ")")
    heatmap_hover_prefix <- if (!is.null(metric_unit_label) && nzchar(metric_unit_label)) {
      paste0("Value (", metric_unit_label, ")")
    } else {
      "Value"
    }
    
    # Create quantile-based color scale (robust to outliers)
    # Calculate percentiles to define color breakpoints
    all_values <- as.vector(heatmap_matrix)
    all_values <- all_values[!is.na(all_values)]
    
    if (length(all_values) > 0) {
      # Use percentiles for color scale breakpoints
      quantiles <- quantile(all_values, probs = c(0, 0.1, 0.25, 0.5, 0.75, 0.9, 1), na.rm = TRUE)
      
      # Normalize to 0-1 range for colorscale
      val_range <- range(all_values, na.rm = TRUE)
      if (val_range[2] > val_range[1]) {
        norm_quantiles <- (quantiles - val_range[1]) / (val_range[2] - val_range[1])
      } else {
        norm_quantiles <- c(0, 0.1, 0.25, 0.5, 0.75, 0.9, 1)
      }
      
      # Custom colorscale: blue (low) -> white (mid) -> red (high)
      custom_colorscale <- list(
        list(norm_quantiles[1], "#2166ac"),  # 0% - dark blue
        list(norm_quantiles[2], "#67a9cf"),  # 10% - light blue
        list(norm_quantiles[3], "#d1e5f0"),  # 25% - very light blue
        list(norm_quantiles[4], "#f7f7f7"),  # 50% - white/neutral
        list(norm_quantiles[5], "#fddbc7"),  # 75% - light orange
        list(norm_quantiles[6], "#ef8a62"),  # 90% - orange
        list(norm_quantiles[7], "#b2182b")   # 100% - dark red
      )
    } else {
      # Fallback to linear scale
      custom_colorscale <- "RdBu"
    }

    heatmap_complexity_details <- list(
      status = "ok",
      source_choice = source_choice,
      frequency = input$data_frequency,
      n_input_rows = nrow(df),
      n_heatmap_base_rows = nrow(heatmap_base),
      n_years = length(years_vec),
      n_periods = ncol(heatmap_matrix),
      n_cells = length(heatmap_matrix),
      n_non_na_cells = sum(!is.na(heatmap_matrix)),
      customdata_cells = length(hover_x_labels),
      colorscale_type = if (is.list(custom_colorscale)) "custom" else as.character(custom_colorscale),
      colorscale_length = if (is.list(custom_colorscale)) length(custom_colorscale) else 1L,
      hover_customdata_chars_est = sum(nchar(stats::na.omit(as.character(hover_x_labels))), na.rm = TRUE)
    )
    
    out <- plot_ly(
      z = heatmap_matrix,
      x = x_labels,
      y = paste0(heatmap_year_prefix, years_vec),
      customdata = hover_x_labels,
      type = "heatmap",
      colorscale = custom_colorscale,
      reversescale = FALSE,
      hovertemplate = paste0("<b>%{y}</b><br>%{customdata}<br>", heatmap_hover_prefix, ": %{z:,.0f}<extra></extra>"),
      colorbar = list(title = paste0("Value (", metric_unit_label, ")")),
      showscale = TRUE
    ) %>%
      layout(
        title = list(
          text = paste0(
            get_commodity_display_label(input$commodity_choice, current_basis_choice_safe()), " - ", if (identical(input$data_source_choice, "census") && identical(input$country_choice, "GRAND_TOTAL")) "World" else get_display_country(input$country_choice),
            "<br>", period_type, " ", metric_display, " Heatmap"
          ),
          y = 0.98,
          yanchor = "top"
        ),
        xaxis = modifyList(x_axis_config, list(title = "", automargin = TRUE, tickangle = 45)),
        yaxis = list(title = heatmap_year_axis_title),
        margin = list(t = 80)
      )
    
    log_perf("heatmap_plot", start_time, details = heatmap_complexity_details)
    out
  }) %>% bindCache(
    historical_trend_plot_base_cache_key()$data_source_choice,
    historical_trend_plot_base_cache_key()$vp_trade_flow_choice,
    historical_trend_plot_base_cache_key()$vp_group_choice,
    historical_trend_plot_base_cache_key()$vp_subgroup_choice,
    historical_trend_plot_base_cache_key()$vp_market_segment_choice,
    historical_trend_plot_base_cache_key()$vp_resolution_mode,
    historical_trend_plot_base_cache_key()$vp_resolved_group_filter,
    historical_trend_plot_base_cache_key()$vp_resolved_subgroup_filter,
    historical_trend_plot_base_cache_key()$vp_resolved_market_segment_filter,
    historical_trend_plot_base_cache_key()$vp_resolved_path,
    historical_trend_plot_base_cache_key()$vp_commodity_name_choice,
    historical_trend_plot_base_cache_key()$vp_commodity_detail_choice,
    historical_trend_plot_base_cache_key()$cache_data_version,
    historical_trend_plot_base_cache_key()$cache_schema_version,
    historical_trend_plot_base_cache_key()$commodity_choice,
    historical_trend_plot_base_cache_key()$country_choice,
    historical_trend_plot_base_cache_key()$data_frequency,
    historical_trend_plot_base_cache_key()$display_year_type,
    historical_trend_plot_base_cache_key()$metric,
    historical_trend_plot_base_cache_key()$unit_choice,
    historical_trend_plot_base_cache_key()$census_value_unit_choice,
    historical_trend_plot_base_cache_key()$basis_choice,
    historical_trend_plot_base_cache_key()$custom_types,
    historical_trend_plot_base_cache_key()$custom_countries
  )

  get_active_metric_label <- function(metric_col = effective_main_metric()) {
    get_metric_label_for_context(metric_col)
  }

  get_active_commodity_label <- function() {
    custom_names <- custom_types_enriched() %>%
      filter(.data$parse_ok) %>%
      pull(.data$custom_name)

    if (input$commodity_choice %in% custom_names) {
      paste0("Custom: ", input$commodity_choice)
    } else {
      get_commodity_display_label(input$commodity_choice, current_basis_choice_safe())
    }
  }

  get_active_country_label <- function(country_code, country_description = NA_character_) {
    if (identical(country_code, "GRAND_TOTAL")) {
      return("World")
    }

    normalized_country_code <- gsub("[^A-Z0-9]", "", toupper(as.character(country_code %||% "")))
    normalized_country_description <- gsub("[^A-Z0-9]", "", toupper(as.character(country_description %||% "")))
    if (normalized_country_code %in% c("US", "USA", "USTOTAL") || normalized_country_description %in% c("US", "USA", "USTOTAL")) {
      return("United States")
    }

    display_name <- get_display_country(country_code)
    normalized_display_name <- gsub("[^A-Z0-9]", "", toupper(as.character(display_name %||% "")))
    if (normalized_display_name %in% c("US", "USA", "USTOTAL")) {
      return("United States")
    }
    if (!is.na(display_name) && nzchar(display_name) && !identical(display_name, country_code)) {
      return(display_name)
    }

    if (!is.na(country_description) && nzchar(country_description)) {
      return(stringr::str_to_title(tolower(country_description)))
    }

    country_code
  }

  vp_data_tab_rollup_tokens <- function() {
    tokens <- if (exists("vp_rollup_tokens_for_app", mode = "function")) {
      tryCatch(vp_rollup_tokens_for_app(), error = function(...) NULL)
    } else {
      NULL
    }

    tokens %||% list(
      group = "__vp_rollup_all_group__",
      subgroup = "__vp_rollup_all_subgroup__",
      market_segment = "__vp_rollup_all_market_segment__"
    )
  }

  normalize_vp_data_tab_key_value <- function(values) {
    normalized <- tolower(trimws(as.character(values %||% "")))
    normalized[is.na(normalized)] <- ""
    normalized
  }

  build_vp_data_tab_lookup_key <- function(trade_values, commodity_name_values, commodity_detail_values) {
    paste(
      normalize_vp_data_tab_key_value(trade_values),
      normalize_vp_data_tab_key_value(commodity_name_values),
      normalize_vp_data_tab_key_value(commodity_detail_values),
      sep = "||"
    )
  }

  collapse_vp_data_tab_hierarchy_values <- function(values) {
    values_chr <- trimws(as.character(values %||% character(0)))
    values_chr <- values_chr[!is.na(values_chr) & nzchar(values_chr)]
    if (length(values_chr) == 0L) {
      return(NA_character_)
    }

    paste(sort(unique(values_chr)), collapse = "; ")
  }

  normalize_vp_rollup_display_value <- function(values, token_value, display_value) {
    out <- as.character(values %||% NA_character_)
    normalized_token <- trimws(as.character(token_value %||% ""))
    if (!nzchar(normalized_token)) {
      return(out)
    }

    matches_rollup <- !is.na(out) & trimws(out) == normalized_token
    out[matches_rollup] <- display_value
    out
  }

  vp_data_tab_native_hierarchy_lookup <- reactive({
    empty_lookup <- data.frame(
      .vp_lookup_key = character(),
      GroupNative = character(),
      SubgroupNative = character(),
      MarketSegmentNative = character(),
      stringsAsFactors = FALSE
    )

    if (exists("vp_trade_rows_available", mode = "function") && !isTRUE(vp_trade_rows_available(require_non_empty = TRUE))) {
      return(empty_lookup)
    }
    if (!exists("vp_trade_rows_available", mode = "function") && (!exists("rice_data_vp_trade_monthly", inherits = TRUE) || !is.data.frame(rice_data_vp_trade_monthly) || nrow(rice_data_vp_trade_monthly) == 0L)) {
      return(empty_lookup)
    }

    native_rows <- if (exists("vp_trade_rows_for_context", mode = "function")) {
      vp_trade_rows_for_context(require_non_empty = TRUE)
    } else {
      rice_data_vp_trade_monthly
    }
    if (exists("vp_native_rows_for_choice_lists", mode = "function")) {
      native_rows <- tryCatch(vp_native_rows_for_choice_lists(native_rows), error = function(...) native_rows)
    } else {
      if ("vp_is_rollup" %in% names(native_rows)) {
        rollup_mask <- !is.na(native_rows$vp_is_rollup) & as.logical(native_rows$vp_is_rollup)
        native_rows <- native_rows[!rollup_mask, , drop = FALSE]
      }

      token_cols <- intersect(c("Group", "Subgroup", "MarketSegment"), names(native_rows))
      if (length(token_cols) > 0L) {
        tokens <- vp_data_tab_rollup_tokens()
        token_values <- trimws(as.character(unname(unlist(tokens, use.names = FALSE))))
        token_values <- token_values[!is.na(token_values) & nzchar(token_values)]
        if (length(token_values) > 0L) {
          keep_mask <- rep(TRUE, nrow(native_rows))
          for (column_name in token_cols) {
            keep_mask <- keep_mask & !(trimws(as.character(native_rows[[column_name]])) %in% token_values)
          }
          native_rows <- native_rows[keep_mask, , drop = FALSE]
        }
      }
    }

    required_cols <- c("Trade", "CommodityName", "Group", "Subgroup", "MarketSegment")
    has_detail_col <- "commodity" %in% names(native_rows) || "CommodityDetail" %in% names(native_rows)
    if (!all(required_cols %in% names(native_rows)) || !has_detail_col || nrow(native_rows) == 0L) {
      return(empty_lookup)
    }

    commodity_detail_source <- if ("commodity" %in% names(native_rows)) {
      as.character(native_rows$commodity)
    } else {
      as.character(native_rows$CommodityDetail)
    }

    native_lookup <- native_rows %>%
      mutate(
        .vp_commodity_detail_source = commodity_detail_source,
        .vp_lookup_key = build_vp_data_tab_lookup_key(.data$Trade, .data$CommodityName, .data$.vp_commodity_detail_source),
        .vp_group_native = as.character(.data$Group %||% NA_character_),
        .vp_subgroup_native = as.character(.data$Subgroup %||% NA_character_),
        .vp_market_segment_native = as.character(.data$MarketSegment %||% NA_character_)
      ) %>%
      group_by(.data$.vp_lookup_key) %>%
      summarise(
        GroupNative = collapse_vp_data_tab_hierarchy_values(.data$.vp_group_native),
        SubgroupNative = collapse_vp_data_tab_hierarchy_values(.data$.vp_subgroup_native),
        MarketSegmentNative = collapse_vp_data_tab_hierarchy_values(.data$.vp_market_segment_native),
        .groups = "drop"
      )

    as.data.frame(native_lookup, stringsAsFactors = FALSE)
  })

  data_tab_dataset <- reactive({
    df <- filtered_data()
    metric_col <- effective_main_metric()
    source_choice <- current_source_choice_safe()
    active_tab <- current_main_tab_safe()
    is_census <- identical(input$data_source_choice, "census")
    is_psd <- identical(input$data_source_choice, "psd")
    resolved_basis <- resolve_basis_choice(
      input$commodity_choice,
      current_basis_choice_safe(),
      active_tab = active_tab,
      source_choice = source_choice
    )
    basis_choices <- basis_choices_for_commodity(
      input$commodity_choice,
      active_tab = active_tab,
      source_choice = source_choice
    )
    basis_values <- trimws(as.character(unname(basis_choices)))
    basis_labels <- trimws(as.character(names(basis_choices)))
    invalid_labels <- is.na(basis_labels) | !nzchar(basis_labels)
    basis_labels[invalid_labels] <- basis_values[invalid_labels]
    resolved_basis_idx <- match(trimws(as.character(resolved_basis)), basis_values)
    basis_display <- if (!is.na(resolved_basis_idx) && resolved_basis_idx >= 1L && resolved_basis_idx <= length(basis_labels)) {
      basis_labels[[resolved_basis_idx]]
    } else {
      get_basis_label(resolved_basis)
    }
    unit_display <- get_psd_metric_unit_label(metric_col, input$unit_choice, current_psd_area_unit_choice_safe())
    metric_label <- get_active_metric_label(metric_col)
    custom_names <- custom_types_enriched() %>%
      filter(.data$parse_ok) %>%
      pull(.data$custom_name)

    if (!nzchar(metric_col) || !(metric_col %in% names(df))) {
      return(data.frame())
    }

    if (identical(source_choice, "vp_trade")) {
      vp_rollup_tokens <- vp_data_tab_rollup_tokens()
      vp_rollup_group_token <- trimws(as.character(vp_rollup_tokens$group %||% ""))
      vp_rollup_subgroup_token <- trimws(as.character(vp_rollup_tokens$subgroup %||% ""))
      vp_rollup_market_segment_token <- trimws(as.character(vp_rollup_tokens$market_segment %||% ""))

      metric_unit_type <- if (metric_col %in% c("unit_value", "ytd_unit_value")) {
        "Unit value"
      } else if (identical(metric_col, "monthlyvalue") || identical(metric_col, "ytd_value")) {
        "Value"
      } else {
        "Volume"
      }

      metric_unit_desc <- if (identical(metric_col, "ytd_unit_value")) {
        as.character(df$ytd_unit_value_unit %||% df$unit_value_unit %||% NA_character_)
      } else if (identical(metric_col, "unit_value")) {
        as.character(df$unit_value_unit %||% NA_character_)
      } else if (identical(metric_col, "monthlyvalue") || identical(metric_col, "ytd_value")) {
        as.character(df$source_value_unit %||% NA_character_)
      } else {
        as.character(df$source_volume_unit %||% NA_character_)
      }

      vp_data <- df %>%
        mutate(
          .vp_trade_key_raw = as.character(.data$Trade %||% ""),
          Trade = tools::toTitleCase(.data$.vp_trade_key_raw),
          GeographicDesc = ifelse(.data$country == "GRAND_TOTAL", "World", as.character(.data$countryDescription %||% .data$country)),
          Year = suppressWarnings(as.integer(.data$calendar_year %||% NA_integer_)),
          MonthNumber = suppressWarnings(as.integer(.data$MonthNum %||% .data$month %||% NA_integer_)),
          MarketYear = as.character(.data$market_year %||% NA_character_),
          Group = as.character(.data$Group %||% NA_character_),
          Subgroup = as.character(.data$Subgroup %||% NA_character_),
          MarketSegment = as.character(.data$MarketSegment %||% NA_character_),
          CommodityName = as.character(.data$CommodityName %||% NA_character_),
          CommodityDetail = as.character(.data$commodity %||% .data$CommodityDetail %||% NA_character_),
          .vp_lookup_key = build_vp_data_tab_lookup_key(.data$.vp_trade_key_raw, .data$CommodityName, .data$CommodityDetail),
          UnitType = metric_unit_type,
          UnitDesc = metric_unit_desc,
          Amount = suppressWarnings(as.numeric(.data[[metric_col]]))
        )
      vp_data_rows_before_mapping <- nrow(vp_data)

      vp_lookup <- vp_data_tab_native_hierarchy_lookup()
      if (is.data.frame(vp_lookup) && nrow(vp_lookup) > 0L && ".vp_lookup_key" %in% names(vp_lookup)) {
        lookup_idx <- match(vp_data$.vp_lookup_key, vp_lookup$.vp_lookup_key)
        group_native <- vp_lookup$GroupNative[lookup_idx]
        subgroup_native <- vp_lookup$SubgroupNative[lookup_idx]
        market_segment_native <- vp_lookup$MarketSegmentNative[lookup_idx]
      } else {
        lookup_idx <- rep(NA_integer_, nrow(vp_data))
        group_native <- rep(NA_character_, nrow(vp_data))
        subgroup_native <- rep(NA_character_, nrow(vp_data))
        market_segment_native <- rep(NA_character_, nrow(vp_data))
      }

      fallback_group <- normalize_vp_rollup_display_value(vp_data$Group, vp_rollup_group_token, "All Groups")
      fallback_subgroup <- normalize_vp_rollup_display_value(vp_data$Subgroup, vp_rollup_subgroup_token, "All Subgroups")
      fallback_market_segment <- normalize_vp_rollup_display_value(vp_data$MarketSegment, vp_rollup_market_segment_token, "All Market Segments")

      # Keep row-scope hierarchy labels from the transformed VP rows; only use
      # native lookup values when a row-scope label is truly missing.
      vp_data$Group <- dplyr::coalesce(fallback_group, group_native)
      vp_data$Subgroup <- dplyr::coalesce(fallback_subgroup, subgroup_native)
      vp_data$MarketSegment <- dplyr::coalesce(fallback_market_segment, market_segment_native)

      if (nrow(vp_data) != vp_data_rows_before_mapping) {
        log_perf(
          "data_tab_dataset(vp_native_hierarchy_row_count_changed)",
          Sys.time(),
          details = list(
            source = source_choice,
            rows_before = vp_data_rows_before_mapping,
            rows_after = nrow(vp_data)
          )
        )
      }

      unmatched_rows <- sum(is.na(lookup_idx))
      if (unmatched_rows > 0L) {
        log_perf(
          "data_tab_dataset(vp_native_hierarchy_lookup_miss)",
          Sys.time(),
          details = list(
            source = source_choice,
            unmatched_rows = unmatched_rows,
            total_rows = nrow(vp_data)
          )
        )
      }

      vp_data <- vp_data %>%
        select(
          Trade,
          GeographicDesc,
          Year,
          MonthNumber,
          MarketYear,
          Group,
          Subgroup,
          MarketSegment,
          CommodityName,
          CommodityDetail,
          UnitType,
          UnitDesc,
          Amount
        ) %>%
        arrange(desc(.data$Year), desc(.data$MonthNumber))

      return(vp_data)
    }

    country_descriptions <- if ("countryDescription" %in% names(df)) {
      as.character(df$countryDescription)
    } else {
      rep(NA_character_, nrow(df))
    }

    provenance_col <- paste0(metric_col, "_provenance")
    provenance_note_col <- paste0(metric_col, "_provenance_note")
    world_source_col <- paste0(metric_col, "_world_source")
    components_col <- paste0(metric_col, "_construction_components")

    display_month_mapping <- current_display_month_mapping(source_choice = source_choice)
    effective_frequency <- current_data_frequency_safe(default = "monthly")
    use_weekly_schema <-
      !source_requires_monthly(source_choice) &&
      identical(effective_frequency, "weekly") &&
      ("week_ending_date" %in% names(df))

    if (!use_weekly_schema) {
      df <- df %>%
        left_join(display_month_mapping, by = "analysis_month") %>%
        mutate(
          commodity_display = ifelse(
            commodity %in% custom_names,
            paste0("Custom: ", commodity),
            get_commodity_display_label(commodity, current_basis_choice_safe())
          ),
          country_display = purrr::map2_chr(.data$country, country_descriptions, get_active_country_label),
          month_market_year = .data$analysis_month,
          unit_display = unit_display,
          basis_display = basis_display,
          value_provenance_display = if (is_psd && provenance_col %in% names(df)) .data[[provenance_col]] else NA_character_,
          provenance_note_display = if (is_psd && provenance_note_col %in% names(df)) .data[[provenance_note_col]] else NA_character_,
          world_source_display = if (is_psd && world_source_col %in% names(df)) .data[[world_source_col]] else NA_character_,
          construction_components_display = if (is_psd && components_col %in% names(df)) .data[[components_col]] else NA_character_
        ) %>%
        select(
          market_year,
          month_market_year,
          month_name,
          commodity_display,
          country_display,
          unit_display,
          basis_display,
          all_of(metric_col),
          any_of(c("value_provenance_display", "provenance_note_display", "world_source_display", "construction_components_display"))
        ) %>%
        arrange(market_year, month_market_year) %>%
        dplyr::rename(
          "MY" = market_year,
          "Month #" = month_market_year,
          "Month" = month_name,
          "Commodity" = commodity_display,
          "Country" = country_display,
          "Unit" = unit_display,
          "Basis" = basis_display,
          !!metric_label := all_of(metric_col),
          "Value Provenance" = value_provenance_display,
          "Provenance Note" = provenance_note_display,
          "World Source" = world_source_display,
          "Construction Components" = construction_components_display
        )
    } else {
      df <- df %>%
        mutate(
          week_date = format(.data$week_ending_date, "%m/%d/%Y"),
          commodity_display = ifelse(
            commodity %in% custom_names,
            paste0("Custom: ", commodity),
            get_commodity_display_label(commodity, current_basis_choice_safe())
          ),
          country_display = purrr::map2_chr(.data$country, country_descriptions, get_active_country_label),
          unit_display = unit_display,
          basis_display = basis_display,
          value_provenance_display = if (is_psd && provenance_col %in% names(df)) .data[[provenance_col]] else NA_character_,
          provenance_note_display = if (is_psd && provenance_note_col %in% names(df)) .data[[provenance_note_col]] else NA_character_,
          world_source_display = if (is_psd && world_source_col %in% names(df)) .data[[world_source_col]] else NA_character_,
          construction_components_display = if (is_psd && components_col %in% names(df)) .data[[components_col]] else NA_character_
        ) %>%
        select(
          market_year,
          analysis_month,
          week_date,
          commodity_display,
          country_display,
          unit_display,
          basis_display,
          all_of(metric_col),
          any_of(c("value_provenance_display", "provenance_note_display", "world_source_display", "construction_components_display"))
        ) %>%
        arrange(market_year, analysis_month) %>%
        dplyr::rename(
          "MY" = market_year,
          "Week" = analysis_month,
          "Week Ending" = week_date,
          "Commodity" = commodity_display,
          "Country" = country_display,
          "Unit" = unit_display,
          "Basis" = basis_display,
          !!metric_label := all_of(metric_col),
          "Value Provenance" = value_provenance_display,
          "Provenance Note" = provenance_note_display,
          "World Source" = world_source_display,
          "Construction Components" = construction_components_display
        )
    }

    if (!is_psd) {
      df <- df %>% select(-any_of(c("Value Provenance", "Provenance Note", "World Source", "Construction Components")))
    }

    df %>%
      mutate(across(where(is.numeric), ~round(., 2)))
  })

  last_published_data_path <- reactiveVal(NULL)
  last_published_data_error <- reactiveVal(NULL)

  # Output: Data table
  output$raw_data_table <- renderDT({
    start_time <- Sys.time()
    df <- data_tab_dataset()
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
      active_tab = current_main_tab_safe()
    )
    if (identical(source_choice, "vp_trade") && metric_code %in% c("unit_value", "ytd_unit_value")) {
      raw_table_unit_context <- build_unit_resolution_context(
        tab_id = current_main_tab_safe(),
        output_id = "raw_data_table",
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
        run_id = "raw_data_table_unit_resolution"
      )

      raw_table_unit_resolution <- tryCatch(
        resolve_vp_trade_display_unit(
          metric_code = metric_code,
          rows = filtered_data(),
          context = raw_table_unit_context
        ),
        error = function(...) NULL
      )

      if (is.list(raw_table_unit_resolution)) {
        unit_guardrail_record_event(
          unit_resolution = raw_table_unit_resolution,
          context = raw_table_unit_context
        )
        if (!is.null(raw_table_unit_resolution$label) && nzchar(raw_table_unit_resolution$label)) {
          metric_unit_label <- raw_table_unit_resolution$label
        }
      }
    }
    raw_data_caption <- tags$caption(
      style = "caption-side: top; text-align: left; color: #4b5563; padding-bottom: 6px;",
      paste0("Data tab values shown in ", metric_unit_label, ".")
    )
    default_order <- if (identical(source_choice, "vp_trade")) {
      list(
        list(match("Year", names(df)) - 1L, "desc"),
        list(match("MonthNumber", names(df)) - 1L, "desc")
      )
    } else if (identical(input$data_frequency, "monthly")) {
      list(
        list(match("MY", names(df)) - 1L, "desc"),
        list(match("Month #", names(df)) - 1L, "desc")
      )
    } else {
      list(
        list(match("MY", names(df)) - 1L, "desc"),
        list(match("Week", names(df)) - 1L, "desc")
      )
    }

    result <- datatable(
      df,
      caption = raw_data_caption,
      options = list(
        pageLength = 25,
        searching = TRUE,
        ordering = TRUE,
        order = default_order
      ),
      rownames = FALSE
    )
    if (identical(source_choice, "vp_trade") && "Amount" %in% names(df) && is.numeric(df$Amount)) {
      result <- result %>%
        formatRound(columns = "Amount", digits = 2, mark = ",")
    }
    log_perf(
      "raw_data_table",
      start_time,
      details = list(
        source = input$data_source_choice,
        rows = nrow(df),
        cols = ncol(df)
      )
    )
    result
  })

  publish_data_tab_dataset <- function(output_dir = app_output_dir) {
    df_to_publish <- data_tab_dataset()

    if (nrow(df_to_publish) == 0) {
      return(list(path = NULL, error = "No data available to publish."))
    }

    source_choice <- current_source_choice_safe(default = input$data_source_choice %||% "export_sales")
    metric_code <- effective_main_metric()

    census_trade_flow_input <- if (!is.null(input$census_trade_flow_choice) && input$census_trade_flow_choice %in% c("export", "import")) {
      input$census_trade_flow_choice
    } else {
      "export"
    }
    hybrid_trade_flow_input <- if (!is.null(input$hybrid_trade_flow_choice) && input$hybrid_trade_flow_choice %in% c("export", "import")) {
      input$hybrid_trade_flow_choice
    } else {
      "export"
    }
    vp_trade_flow_input <- if (!is.null(input$vp_trade_flow_choice) && input$vp_trade_flow_choice %in% c("export", "import")) {
      input$vp_trade_flow_choice
    } else {
      "export"
    }

    resolved_trade_flow <- effective_trade_flow_for_source(
      source_choice = source_choice,
      trade_flow_value = if (identical(source_choice, "census")) census_trade_flow_input else NULL,
      vp_trade_flow_value = if (identical(source_choice, "vp_trade")) vp_trade_flow_input else NULL
    )

    census_trade_flow_context <- if (identical(source_choice, "census_import")) {
      "import"
    } else if (identical(source_choice, "census")) {
      if (identical(resolved_trade_flow, "import")) "import" else "export"
    } else {
      census_trade_flow_input
    }
    hybrid_trade_flow_context <- if (identical(source_choice, "hybrid_import")) {
      "import"
    } else if (identical(source_choice, "hybrid")) {
      if (identical(resolved_trade_flow, "import")) "import" else "export"
    } else {
      hybrid_trade_flow_input
    }
    vp_trade_flow_context <- if (identical(source_choice, "vp_trade")) {
      if (identical(resolved_trade_flow, "import")) "import" else "export"
    } else {
      vp_trade_flow_input
    }

    metric_label <- get_metric_label_for_context(
      metric_code = metric_code,
      source_choice = source_choice,
      census_trade_flow = census_trade_flow_context,
      hybrid_trade_flow = hybrid_trade_flow_context,
      vp_trade_flow = vp_trade_flow_context
    )
    if (is.null(metric_label) || !nzchar(metric_label)) {
      metric_label <- get_active_metric_label(metric_code)
    }
    metric_label <- trimws(as.character(metric_label %||% ""))
    metric_label <- metric_label[!is.na(metric_label) & nzchar(metric_label)]
    metric_label <- if (length(metric_label) > 0L) metric_label[[1L]] else ""
    if (!nzchar(metric_label)) {
      metric_code_fallback <- trimws(as.character(metric_code %||% ""))
      metric_code_fallback <- metric_code_fallback[!is.na(metric_code_fallback) & nzchar(metric_code_fallback)]
      metric_label <- if (length(metric_code_fallback) > 0L) metric_code_fallback[[1L]] else "Metric"
    }

    # CSV-only publish contract: append Variable once at the final column position.
    if ("Variable" %in% names(df_to_publish)) {
      df_to_publish <- df_to_publish[, setdiff(names(df_to_publish), "Variable"), drop = FALSE]
    }
    df_to_publish$Variable <- metric_label

    commodity_label <- get_active_commodity_label()
    country_label <- get_active_country_label(input$country_choice)

    publish_result <- tryCatch({
      publish_data_to_csv(
        data = df_to_publish,
        metric_label = metric_label,
        commodity_label = commodity_label,
        country_label = country_label,
        output_dir = output_dir
      )
    }, error = function(e) {
      e
    })

    if (inherits(publish_result, "error")) {
      return(list(path = NULL, error = conditionMessage(publish_result)))
    }

    list(path = publish_result, error = NULL)
  }

  observeEvent(input$publish_filtered_data, {
    publish_result <- publish_data_tab_dataset()

    if (!is.null(publish_result$error)) {
      last_published_data_path(NULL)
      last_published_data_error(publish_result$error)
      showNotification(
        if (identical(publish_result$error, "No data available to publish.")) publish_result$error else paste("Publish failed:", publish_result$error),
        type = if (identical(publish_result$error, "No data available to publish.")) "warning" else "error",
        duration = NULL
      )
      return(invisible(NULL))
    }

    last_published_data_path(publish_result$path)
    last_published_data_error(NULL)
    showNotification(
      paste("Published data to", basename(publish_result$path)),
      type = "message"
    )
  }, ignoreInit = FALSE)

  build_market_year_partner_grouped_data <- function(df_ytd_snapshot, partner_selected, excluded_partners = character(0), comparison_mode = "country") {
    normalized_snapshot <- df_ytd_snapshot
    if (identical(comparison_mode, "country")) {
      normalized_snapshot <- normalized_snapshot %>%
        mutate(comparison_item = normalize_myc_country_selection_values(.data$comparison_item))
      selected_partners <- normalize_myc_country_selection_values(partner_selected)
      excluded_items <- normalize_myc_country_selection_values(excluded_partners)

      custom_country_items <- normalize_myc_country_selection_values(
        myc_custom_country_display_values(source_choice = current_source_choice_safe(default = input$data_source_choice %||% "export_sales"))
      )
      inactive_custom_items <- setdiff(custom_country_items, selected_partners)
      if (length(inactive_custom_items) > 0) {
        normalized_snapshot <- normalized_snapshot %>%
          filter(!(.data$comparison_item %in% inactive_custom_items))
      }
    } else {
      normalized_snapshot <- normalized_snapshot %>%
        mutate(comparison_item = trimws(as.character(.data$comparison_item)))
      selected_partners <- unique(trimws(as.character(partner_selected)))
      excluded_items <- unique(trimws(as.character(excluded_partners)))

      active_custom_names <- custom_types_enriched() %>%
        filter(.data$parse_ok) %>%
        pull(.data$custom_name) %>%
        as.character() %>%
        trimws() %>%
        unique()

      inactive_custom_items <- setdiff(active_custom_names, selected_partners)
      if (length(inactive_custom_items) > 0) {
        normalized_snapshot <- normalized_snapshot %>%
          filter(!(.data$comparison_item %in% inactive_custom_items))
      }
    }

    excluded_items <- excluded_items[excluded_items %in% unique(normalized_snapshot$comparison_item)]
    if (length(excluded_items) > 0) {
      normalized_snapshot <- normalized_snapshot %>% filter(!.data$comparison_item %in% excluded_items)
    }

    selected_partners <- selected_partners[selected_partners %in% unique(normalized_snapshot$comparison_item)]

    grouped_plot_data <- normalized_snapshot %>%
      mutate(partner_category = ifelse(comparison_item %in% selected_partners, comparison_item, "All Other")) %>%
      group_by(market_year, partner_category) %>%
      summarise(plot_value = (sum(plot_metric, na.rm = TRUE) * (NA_real_ ^ (sum(!is.na(plot_metric)) == 0))), .groups = "drop") %>%
      mutate(market_year = as.character(market_year))

    grouped_all_other_components <- normalized_snapshot %>%
      filter(!.data$comparison_item %in% selected_partners) %>%
      group_by(.data$market_year, .data$comparison_item) %>%
      summarise(plot_value = (sum(.data$plot_metric, na.rm = TRUE) * (NA_real_ ^ (sum(!is.na(.data$plot_metric)) == 0))), .groups = "drop")

    list(
      partner_selected = selected_partners,
      plot_data = grouped_plot_data,
      all_other_components = grouped_all_other_components
    )
  }

  resolve_market_year_partner_ordering <- function(plot_data, basis_state, partner_selected, current_my, all_other_present = FALSE, comparison_baseline_label = "Historical Avg") {
    partner_basis_lookup <- basis_state$basis_data %>%
      filter(.data$comparison_item %in% partner_selected) %>%
      transmute(
        partner_category = as.character(.data$comparison_item),
        plot_value = as.numeric(.data$basis_plot_value)
      )

    all_other_basis_year <- if (identical(basis_state$order_basis, "historical_avg")) {
      comparison_baseline_label
    } else {
      as.character(current_my)
    }

    all_other_row <- if (isTRUE(all_other_present)) {
      plot_data %>%
        filter(as.character(.data$market_year) == all_other_basis_year, .data$partner_category == "All Other") %>%
        group_by(.data$partner_category) %>%
        summarise(plot_value = sum(.data$plot_value, na.rm = TRUE), .groups = "drop")
    } else {
      data.frame(partner_category = character(0), plot_value = numeric(0), stringsAsFactors = FALSE)
    }

    if (isTRUE(all_other_present) && nrow(all_other_row) == 0) {
      all_other_row <- data.frame(
        partner_category = "All Other",
        plot_value = NA_real_,
        stringsAsFactors = FALSE
      )
    }

    order_source <- bind_rows(all_other_row, partner_basis_lookup)

    partner_sorted_asc <- partner_basis_lookup %>%
      arrange(.data$plot_value, .data$partner_category) %>%
      pull(.data$partner_category)

    missing_selected <- setdiff(partner_selected, partner_sorted_asc)
    if (length(missing_selected) > 0) {
      partner_sorted_asc <- c(partner_sorted_asc, missing_selected)
    }

    partner_levels <- c(if (isTRUE(all_other_present)) "All Other" else character(0), partner_sorted_asc)
    ranked_values <- setNames(partner_basis_lookup$plot_value, partner_basis_lookup$partner_category)

    list(
      order_source = order_source,
      order_basis = basis_state$order_basis,
      partner_levels = partner_levels,
      ranked_values = ranked_values
    )
  }

  market_year_partner_plot_state <- reactive({
    start_time <- Sys.time()
    record_cache_body_execution(session, "myc_partner_plot_state_executed")
    record_cache_body_execution(
      session,
      "market_year_partner_plot_state",
      details = list(source = input$data_source_choice %||% "unknown")
    )

    record_partner_share_data_read("market_year_partner_plot_state")
    comparison_basis_dependency <- list(
      input$projection_basis_mode,
      input$projection_reference_year,
      comparison_hist_years_committed()
    )
    invisible(comparison_basis_dependency)
    share_data <- partner_share_data()
    if (is.null(share_data)) {
      null_reason <- if (exists("partner_share_data_null_reason", mode = "function")) {
        tryCatch(partner_share_data_null_reason(), error = function(e) NULL)
      } else {
        NULL
      }
      log_perf(
        "market_year_partner_plot_state()",
        start_time,
        details = list(
          status = "no_share_data",
          source = input$data_source_choice %||% "unknown",
          null_reason = null_reason %||% "unknown"
        )
      )
      return(NULL)
    }

    df_ytd_snapshot <- share_data$df
    if (nrow(df_ytd_snapshot) == 0) {
      log_perf(
        "market_year_partner_plot_state()",
        start_time,
        details = list(
          status = "empty_snapshot",
          source = input$data_source_choice %||% "unknown",
          comparison_mode = share_data$comparison_mode,
          metric = share_data$metric_col
        )
      )
      return(NULL)
    }

    current_my <- share_data$current_my
    latest_period_index <- share_data$latest_period_index
    metric_col <- share_data$metric_col
    comparison_label <- share_data$category_label
    focus_label <- share_data$focus_label

    basis_state <- market_year_partner_basis_state()
    if (is.null(basis_state)) {
      log_perf(
        "market_year_partner_plot_state()",
        start_time,
        details = list(
          status = "no_basis_state",
          source = input$data_source_choice %||% "unknown",
          comparison_mode = share_data$comparison_mode,
          metric = share_data$metric_col,
          rows = nrow(df_ytd_snapshot)
        )
      )
      return(NULL)
    }

    effective_partner_selection <- market_year_effective_partner_selection()
    display_partners <- market_year_display_partner_selection()
    excluded_partners <- if (identical(share_data$comparison_mode, "type")) {
      display_selection <- normalize_myc_partner_values(display_partners, comparison_mode = "type")
      custom_component_exclusions <- derive_exact_myc_custom_component_exclusions(
        selection = display_selection,
        eligible_partners = share_data$eligible_partners
      )

      native_parent_exclusions <- if (isTRUE(is_myc_hybrid_type_mode_active())) {
        derived_exclusions <- derive_native_hybrid_parent_exclusions(
          selection = unique(c(display_selection, custom_component_exclusions)),
          eligible_partners = share_data$eligible_partners
        )

        unique(setdiff(derived_exclusions, display_selection))
      } else {
        character(0)
      }

      unique(c(native_parent_exclusions, custom_component_exclusions))
    } else if (
      identical(share_data$comparison_mode, "country") &&
      exists("derive_myc_country_custom_component_exclusions", mode = "function")
    ) {
      derive_myc_country_custom_component_exclusions(
        selection = display_partners,
        eligible_partners = share_data$eligible_partners
      )
    } else {
      character(0)
    }

    grouped_partner_data <- build_market_year_partner_grouped_data(
      df_ytd_snapshot,
      display_partners,
      excluded_partners = excluded_partners,
      comparison_mode = share_data$comparison_mode
    )
    partner_selected <- grouped_partner_data$partner_selected
    plot_data <- grouped_partner_data$plot_data
    all_other_components <- grouped_partner_data$all_other_components

    comparison_basis_mode <- share_data$comparison_basis_mode %||% "average"
    comparison_basis_years <- share_data$comparison_basis_years %||% share_data$hist_years
    comparison_baseline_label <- share_data$comparison_baseline_label %||% "Historical Avg"

    if (identical(comparison_basis_mode, "single_year") && length(comparison_basis_years) > 0) {
      plot_data <- plot_data %>%
        filter(!(.data$market_year %in% comparison_basis_years))
      all_other_components <- all_other_components %>%
        filter(!(.data$market_year %in% comparison_basis_years))
    }

    current_all_other_present <- nrow(all_other_components) > 0

    unit_label <- get_metric_measurement_label(
      metric_code = effective_main_metric(),
      source_choice = current_source_choice_safe(default = input$data_source_choice %||% "export_sales"),
      unit_choice = input$unit_choice,
      basis_choice = current_basis_choice_safe(),
      value_unit_choice = current_census_value_unit_choice_safe(
        source_choice = current_source_choice_safe(default = input$data_source_choice %||% "export_sales"),
        metric_code = effective_main_metric()
      ),
      commodity_name = input$commodity_choice,
      active_tab = input$main_tabs_panel
    )

    format_component_breakdown <- function(component_df, max_lines = 12L) {
      if (is.null(component_df) || nrow(component_df) == 0) {
        return(data.frame(market_year = character(), all_other_breakdown = character(), stringsAsFactors = FALSE))
      }

      component_df %>%
        mutate(
          market_year = as.character(.data$market_year),
          comparison_item = as.character(.data$comparison_item)
        ) %>%
        group_by(.data$market_year, .data$comparison_item) %>%
        summarise(plot_value = sum(.data$plot_value, na.rm = TRUE), .groups = "drop") %>%
        group_by(.data$market_year) %>%
        group_modify(~{
          ranked_components <- .x %>% arrange(desc(.data$plot_value), .data$comparison_item)
          visible_components <- head(ranked_components, max_lines)
          remaining_count <- nrow(ranked_components) - nrow(visible_components)

          detail_lines <- paste0(
            visible_components$comparison_item,
            ": ",
            format(round(visible_components$plot_value, 0), big.mark = ",", scientific = FALSE),
            " ",
            unit_label
          )

          breakdown <- if (length(detail_lines) > 0) {
            paste(detail_lines, collapse = "<br>")
          } else {
            "<details unavailable>"
          }

          if (remaining_count > 0) {
            breakdown <- paste0(breakdown, "<br>...and ", remaining_count, " more")
          }

          tibble(all_other_breakdown = breakdown)
        }) %>%
        ungroup()
    }

    all_other_breakdown <- format_component_breakdown(all_other_components)

    historical_all_other_present <- FALSE
    baseline_added <- FALSE

    if (length(comparison_basis_years) > 0) {
      hist_grouped_partner_data <- df_ytd_snapshot %>%
        filter(.data$market_year %in% comparison_basis_years) %>%
        build_market_year_partner_grouped_data(
          partner_selected = partner_selected,
          excluded_partners = excluded_partners,
          comparison_mode = share_data$comparison_mode
        )

      hist_data <- hist_grouped_partner_data$plot_data

      hist_all_other_components <- hist_grouped_partner_data$all_other_components %>%
        group_by(.data$comparison_item) %>%
        summarise(plot_value = mean(.data$plot_value, na.rm = TRUE), .groups = "drop") %>%
        mutate(market_year = comparison_baseline_label)
      historical_all_other_present <- nrow(hist_all_other_components) > 0

      partner_candidates <- unique(c(
        if (isTRUE(current_all_other_present) || isTRUE(historical_all_other_present)) "All Other" else character(0),
        partner_selected
      ))

      hist_avg <- data.frame(partner_category = partner_candidates, stringsAsFactors = FALSE) %>%
        left_join(
          hist_data %>%
            group_by(.data$partner_category) %>%
            summarise(plot_value = mean(.data$plot_value, na.rm = TRUE), .groups = "drop"),
          by = "partner_category"
        ) %>%
        mutate(
          plot_value = ifelse(is.na(.data$plot_value), 0, .data$plot_value),
          market_year = comparison_baseline_label
        )

      plot_data <- bind_rows(plot_data, hist_avg)
      baseline_added <- TRUE
      all_other_breakdown <- bind_rows(
        all_other_breakdown,
        format_component_breakdown(hist_all_other_components)
      )
    }

    year_levels <- sort(unique(as.character(plot_data$market_year[as.character(plot_data$market_year) != comparison_baseline_label])))
    baseline_present <- isTRUE(baseline_added) || comparison_baseline_label %in% as.character(plot_data$market_year)
    if (baseline_present) {
      year_levels <- year_levels[year_levels != comparison_baseline_label]
      current_level <- as.character(current_my)
      current_idx <- match(current_level, year_levels)

      if (!is.na(current_idx)) {
        year_levels <- append(year_levels, comparison_baseline_label, after = current_idx - 1L)
      } else {
        year_levels <- c(year_levels, comparison_baseline_label)
      }
    }
    plot_data$market_year <- factor(plot_data$market_year, levels = year_levels)

    all_other_present <- isTRUE(current_all_other_present) || isTRUE(historical_all_other_present)

    ordering_state <- resolve_market_year_partner_ordering(
      plot_data = plot_data,
      basis_state = basis_state,
      partner_selected = partner_selected,
      current_my = current_my,
      all_other_present = all_other_present,
      comparison_baseline_label = comparison_baseline_label
    )

    plot_data$partner_category <- factor(
      plot_data$partner_category,
      levels = ordering_state$partner_levels
    )

    plot_data <- plot_data %>%
      left_join(all_other_breakdown, by = "market_year") %>%
      arrange(match(.data$partner_category, ordering_state$partner_levels), match(.data$market_year, year_levels)) %>%
      group_by(.data$market_year) %>%
      mutate(
        year_total = (sum(.data$plot_value, na.rm = TRUE) * (NA_real_ ^ (sum(!is.na(.data$plot_value)) == 0))),
        share_pct = ifelse(.data$year_total > 0, .data$plot_value / .data$year_total, NA_real_)
      ) %>%
      ungroup()

    if (
      identical(input$main_tabs_panel, "Market Year Comparison Tool") &&
      exists("myc_transition_trace", mode = "function")
    ) {
      collapse_trace_values <- function(values, max_items = 8L) {
        values <- unique(as.character(values %||% character(0)))
        if (length(values) == 0) return("<none>")

        values <- values[seq_len(min(length(values), max_items))]
        paste(values, collapse = " | ")
      }

      current_all_other_sample <- if (nrow(all_other_components) > 0) {
        all_other_components %>%
          arrange(dplyr::desc(.data$plot_value), .data$comparison_item) %>%
          head(5) %>%
          transmute(label = sprintf("%s=%.0f", .data$comparison_item, .data$plot_value)) %>%
          pull(.data$label)
      } else {
        character(0)
      }

      myc_transition_trace(
        "market_year_partner_plot_state",
        details = list(
          comparison_mode = share_data$comparison_mode,
          focus_label = focus_label,
          display_partner_count = length(partner_selected),
          display_partner_sample = collapse_trace_values(partner_selected),
          excluded_partner_count = length(excluded_partners),
          excluded_partner_sample = collapse_trace_values(excluded_partners),
          current_all_other_present = isTRUE(current_all_other_present),
          current_all_other_component_count = nrow(all_other_components),
          current_all_other_sample = collapse_trace_values(current_all_other_sample),
          historical_all_other_present = isTRUE(historical_all_other_present),
          order_basis = ordering_state$order_basis,
          partner_level_sample = collapse_trace_values(ordering_state$partner_levels),
          comparison_baseline_label = comparison_baseline_label
        )
      )
    }

    log_perf(
      "market_year_partner_plot_state()",
      start_time,
      details = list(
        status = "ok",
        source = input$data_source_choice %||% "unknown",
        comparison_mode = share_data$comparison_mode,
        metric = metric_col,
        plot_rows = nrow(plot_data),
        contributor_partners_count = length(share_data$contributor_partners %||% character(0)),
        custom_contributor_count = length(share_data$explicit_custom_selection %||% character(0)),
        display_partners = length(partner_selected),
        excluded_partners = length(excluded_partners),
        current_all_other_present = isTRUE(current_all_other_present),
        historical_all_other_present = isTRUE(historical_all_other_present),
        order_basis = ordering_state$order_basis,
        hist_years = length(share_data$hist_years),
        comparison_basis_mode = share_data$comparison_basis_mode,
        comparison_basis_years = length(comparison_basis_years)
      )
    )

    list(
      plot_data = plot_data,
      all_other_breakdown = all_other_breakdown,
      current_my = current_my,
      latest_period_index = latest_period_index,
      metric_col = metric_col,
      comparison_mode = share_data$comparison_mode,
      comparison_label = comparison_label,
      focus_label = focus_label,
      unit_label = unit_label,
      partner_levels = ordering_state$partner_levels,
      order_source = ordering_state$order_source,
      order_basis = ordering_state$order_basis,
      ranked_values = ordering_state$ranked_values,
      hist_years = share_data$hist_years,
      comparison_basis_mode = share_data$comparison_basis_mode,
      comparison_reference_year = share_data$comparison_reference_year,
      comparison_reference_year_label = share_data$comparison_reference_year_label,
      comparison_basis_years = comparison_basis_years,
      comparison_baseline_label = comparison_baseline_label,
      display_partners = partner_selected,
      excluded_partners = excluded_partners,
      effective_partner_selection = effective_partner_selection,
      basis_state = basis_state
    )
  })

  calculate_myct_density_width <- function(year_count,
                                           viewport_width = NULL,
                                           reference_count = 5L,
                                           min_per_year = 110L,
                                           max_per_year = 220L,
                                           minimum_content_width = 600L,
                                           fallback_width = 900L) {
    year_count <- suppressWarnings(as.integer(year_count))
    if (length(year_count) != 1L || !is.finite(year_count) || year_count < 1L) {
      year_count <- 1L
    }

    viewport_width <- suppressWarnings(as.numeric(viewport_width))
    if (length(viewport_width) != 1L || !is.finite(viewport_width) || viewport_width <= 0) {
      viewport_width <- fallback_width
    }

    reference_count <- suppressWarnings(as.integer(reference_count))
    if (length(reference_count) != 1L || !is.finite(reference_count) || reference_count < 1L) {
      reference_count <- 5L
    }

    min_per_year <- suppressWarnings(as.numeric(min_per_year))
    if (length(min_per_year) != 1L || !is.finite(min_per_year) || min_per_year <= 0) {
      min_per_year <- 110
    }

    max_per_year <- suppressWarnings(as.numeric(max_per_year))
    if (length(max_per_year) != 1L || !is.finite(max_per_year) || max_per_year <= 0 || max_per_year < min_per_year) {
      max_per_year <- 220
    }

    minimum_content_width <- suppressWarnings(as.numeric(minimum_content_width))
    if (length(minimum_content_width) != 1L || !is.finite(minimum_content_width) || minimum_content_width <= 0) {
      minimum_content_width <- 600
    }

    fallback_width <- suppressWarnings(as.numeric(fallback_width))
    if (length(fallback_width) != 1L || !is.finite(fallback_width) || fallback_width <= 0) {
      fallback_width <- 900
    }

    bucketed_viewport_width <- ceiling(viewport_width / 50) * 50
    per_category_width <- bucketed_viewport_width / reference_count
    per_category_width <- min(max(per_category_width, min_per_year), max_per_year)

    as.integer(ceiling(max(year_count * per_category_width, minimum_content_width)))
  }

  normalize_myc_table_value_digits <- function(value) {
    if (is.null(value) || length(value) == 0L) {
      value <- summary_table_value_digits_min
    }

    value <- suppressWarnings(as.integer(value[[1]]))
    if (is.na(value)) value <- summary_table_value_digits_min
    max(summary_table_value_digits_min, min(summary_table_value_digits_max, value))
  }

  resolve_myc_table_measure_mode <- function(value) {
    mode_value <- as.character(value %||% "value")
    mode_value <- mode_value[!is.na(mode_value) & nzchar(mode_value)]
    if (length(mode_value) == 0L || !(mode_value[[1]] %in% c("value", "share"))) {
      return("value")
    }

    mode_value[[1]]
  }

  resolve_myc_table_comparison_mode <- function(value) {
    mode_value <- as.character(value %||% "current")
    mode_value <- mode_value[!is.na(mode_value) & nzchar(mode_value)]
    if (length(mode_value) == 0L || !(mode_value[[1]] %in% c("current", "comparison"))) {
      return("current")
    }

    mode_value[[1]]
  }

  myc_plot_market_year_levels <- function(plot_data) {
    x_category_levels <- as.character(levels(plot_data$market_year))
    if (length(x_category_levels) == 0L || !any(nzchar(x_category_levels))) {
      x_category_levels <- unique(as.character(plot_data$market_year))
    }

    x_category_levels[!is.na(x_category_levels) & nzchar(x_category_levels)]
  }

  order_myc_table_market_year_levels <- function(market_year_levels,
                                                 comparison_baseline_label = "Historical Avg") {
    market_year_levels <- as.character(market_year_levels)
    market_year_levels <- market_year_levels[!is.na(market_year_levels) & nzchar(market_year_levels)]
    if (length(market_year_levels) == 0L) {
      return(character(0))
    }

    baseline_levels <- market_year_levels[market_year_levels == comparison_baseline_label]
    remaining_levels <- market_year_levels[market_year_levels != comparison_baseline_label]
    numeric_years <- suppressWarnings(as.numeric(remaining_levels))

    numeric_levels <- remaining_levels[is.finite(numeric_years)]
    numeric_years <- numeric_years[is.finite(numeric_years)]
    if (length(numeric_levels) > 0L) {
      ordering <- order(numeric_years, decreasing = FALSE)
      numeric_levels <- numeric_levels[ordering]
      numeric_years <- numeric_years[ordering]
    }

    current_level <- character(0)
    prior_numeric_levels <- numeric_levels
    if (length(numeric_levels) > 0L) {
      current_year <- max(numeric_years, na.rm = TRUE)
      current_mask <- numeric_years == current_year
      current_level <- numeric_levels[current_mask]
      prior_numeric_levels <- numeric_levels[!current_mask]
    }

    nonnumeric_levels <- remaining_levels[!remaining_levels %in% numeric_levels]
    c(prior_numeric_levels, baseline_levels, current_level, nonnumeric_levels)
  }

  format_myc_market_year_label <- function(market_year_value,
                                           source_choice,
                                           comparison_baseline_label = "Historical Avg") {
    raw_label <- as.character(market_year_value)
    raw_label <- raw_label[!is.na(raw_label)]
    if (length(raw_label) == 1L && identical(raw_label[[1]], comparison_baseline_label)) {
      return(comparison_baseline_label)
    }

    build_map_display_year_label(market_year_value, source_choice = source_choice)
  }

  make_unique_myc_table_headers <- function(labels) {
    labels <- as.character(labels)
    labels[is.na(labels) | !nzchar(labels)] <- "Unknown"
    duplicate_mask <- duplicated(labels) | duplicated(labels, fromLast = TRUE)
    if (!any(duplicate_mask)) {
      return(labels)
    }

    sequence_by_label <- ave(seq_along(labels), labels, FUN = seq_along)
    labels[duplicate_mask] <- paste0(labels[duplicate_mask], " (", sequence_by_label[duplicate_mask], ")")
    labels
  }

  myc_category_column_header <- function(comparison_mode = "country") {
    mode_value <- trimws(as.character(comparison_mode %||% "country"))
    if (length(mode_value) == 0L || !nzchar(mode_value[[1L]])) {
      mode_value <- "country"
    } else {
      mode_value <- mode_value[[1L]]
    }

    if (identical(mode_value, "country")) "Country" else "Type"
  }

  order_myc_table_category_levels <- function(category_levels,
                                              value_source,
                                              current_market_year_key = "") {
    category_levels <- as.character(category_levels)
    category_levels <- category_levels[!is.na(category_levels) & nzchar(category_levels)]
    if (length(category_levels) == 0L) {
      return(character(0))
    }
    if (!is.data.frame(value_source) || nrow(value_source) == 0L) {
      return(category_levels)
    }

    normalized_current_key <- as.character(current_market_year_key %||% "")
    normalized_current_key <- normalized_current_key[!is.na(normalized_current_key) & nzchar(normalized_current_key)]
    normalized_current_key <- if (length(normalized_current_key) > 0L) normalized_current_key[[1L]] else ""

    available_years <- unique(as.character(value_source$market_year_key %||% character(0)))
    available_years <- available_years[!is.na(available_years) & nzchar(available_years)]
    if (!nzchar(normalized_current_key) || !(normalized_current_key %in% available_years)) {
      numeric_available_years <- suppressWarnings(as.numeric(available_years))
      if (any(is.finite(numeric_available_years))) {
        normalized_current_key <- available_years[[which.max(numeric_available_years)]]
      } else if (length(available_years) > 0L) {
        normalized_current_key <- available_years[[1L]]
      }
    }

    current_year_values <- value_source %>%
      filter(.data$market_year_key == normalized_current_key, .data$partner_key %in% category_levels) %>%
      group_by(.data$partner_key) %>%
      summarise(
        order_value = if (all(is.na(.data$table_value))) NA_real_ else sum(.data$table_value, na.rm = TRUE),
        .groups = "drop"
      )

    ordered_categories <- data.frame(
      partner_key = category_levels,
      original_order = seq_along(category_levels),
      stringsAsFactors = FALSE
    ) %>%
      left_join(current_year_values, by = "partner_key") %>%
      mutate(
        order_value = ifelse(is.finite(.data$order_value), .data$order_value, -Inf),
        is_all_other = grepl("^all\\s+other", tolower(trimws(.data$partner_key)))
      ) %>%
      arrange(.data$is_all_other, desc(.data$order_value), .data$original_order)

    as.character(ordered_categories$partner_key)
  }

  build_myc_table_comparison_values <- function(current_values,
                                                baseline_values,
                                                denominator_epsilon = 1e-9) {
    current_values <- suppressWarnings(as.numeric(current_values))
    baseline_values <- suppressWarnings(as.numeric(baseline_values))

    valid_current <- is.finite(current_values)
    valid_baseline <- is.finite(baseline_values)
    denominator_valid <- valid_baseline & (abs(baseline_values) >= denominator_epsilon)
    paired_valid <- valid_current & valid_baseline

    difference_raw <- rep(NA_real_, length(current_values))
    difference_raw[paired_valid] <- current_values[paired_valid] - baseline_values[paired_valid]

    pct_difference_raw <- rep(NA_real_, length(current_values))
    pct_idx <- valid_current & denominator_valid
    pct_difference_raw[pct_idx] <- (difference_raw[pct_idx] / baseline_values[pct_idx]) * 100

    list(
      difference_raw = difference_raw,
      pct_difference_raw = pct_difference_raw,
      denominator_valid = denominator_valid
    )
  }

  format_myc_table_percent_difference <- function(value, digits = 1L, blank_for_na = TRUE) {
    values <- suppressWarnings(as.numeric(value))
    digits <- suppressWarnings(as.integer(digits[[1L]]))
    if (is.na(digits) || digits < 0L) {
      digits <- 1L
    }

    vapply(values, function(single_value) {
      if (!is.finite(single_value)) {
        return(if (isTRUE(blank_for_na)) "" else NA_character_)
      }

      rounded_value <- round(single_value, digits = digits)
      formatted_value <- formatC(
        rounded_value,
        format = "f",
        digits = digits,
        big.mark = ","
      )
      paste0(if (rounded_value > 0) "+" else "", formatted_value, "%")
    }, character(1))
  }

  round_myc_market_year_table_values <- function(table_df, value_columns, digits) {
    if (!is.data.frame(table_df) || length(value_columns) == 0L) {
      return(table_df)
    }

    value_columns <- intersect(value_columns, names(table_df))
    if (length(value_columns) == 0L) {
      return(table_df)
    }

    digits <- normalize_myc_table_value_digits(digits)
    for (value_column in value_columns) {
      table_df[[value_column]] <- round(table_df[[value_column]], digits)
    }

    table_df
  }

  build_myc_market_year_table_state <- function(plot_state,
                                                table_mode = "value",
                                                table_comparison_mode = "current",
                                                source_choice = "export_sales") {
    if (is.null(plot_state) || is.null(plot_state$plot_data) || nrow(plot_state$plot_data) == 0) {
      return(NULL)
    }

    plot_data <- plot_state$plot_data
    comparison_baseline_label <- plot_state$comparison_baseline_label %||% "Historical Avg"
    x_category_levels <- myc_plot_market_year_levels(plot_data)
    x_category_levels <- order_myc_table_market_year_levels(
      x_category_levels,
      comparison_baseline_label = comparison_baseline_label
    )
    if (length(x_category_levels) == 0L) {
      return(NULL)
    }

    table_mode <- resolve_myc_table_measure_mode(table_mode)
    table_comparison_mode <- resolve_myc_table_comparison_mode(table_comparison_mode)
    partner_levels <- as.character(plot_state$partner_levels %||% character(0))
    partner_levels <- partner_levels[!is.na(partner_levels) & nzchar(partner_levels)]
    if (length(partner_levels) == 0L) {
      partner_levels <- unique(as.character(plot_data$partner_category))
    }

    legend_levels <- rev(partner_levels)
    legend_levels <- legend_levels[!is.na(legend_levels) & nzchar(legend_levels)]
    if (length(legend_levels) == 0L) {
      return(NULL)
    }

    category_levels <- partner_levels
    category_levels <- category_levels[!is.na(category_levels) & nzchar(category_levels)]
    if (length(category_levels) == 0L) {
      category_levels <- legend_levels
    }
    if (length(category_levels) == 0L) {
      return(NULL)
    }

    value_source <- plot_data %>%
      mutate(
        market_year_key = as.character(.data$market_year),
        partner_key = as.character(.data$partner_category),
        table_value = if (identical(table_mode, "share")) .data$share_pct * 100 else .data$plot_value
      ) %>%
      filter(.data$market_year_key %in% x_category_levels, .data$partner_key %in% legend_levels) %>%
      group_by(.data$market_year_key, .data$partner_key) %>%
      summarise(
        table_value = if (all(is.na(.data$table_value))) NA_real_ else sum(.data$table_value, na.rm = TRUE),
        .groups = "drop"
      )

    total_source <- plot_data %>%
      mutate(market_year_key = as.character(.data$market_year)) %>%
      filter(.data$market_year_key %in% x_category_levels) %>%
      group_by(.data$market_year_key) %>%
      summarise(
        total_value = if (all(is.na(.data$plot_value))) NA_real_ else sum(.data$plot_value, na.rm = TRUE),
        total_share = if (any(.data$year_total > 0, na.rm = TRUE)) 100 else NA_real_,
        .groups = "drop"
      )

    current_market_year_key <- as.character(plot_state$current_my %||% "")
    current_market_year_key <- current_market_year_key[!is.na(current_market_year_key) & nzchar(current_market_year_key)]
    current_market_year_key <- if (length(current_market_year_key) > 0L) current_market_year_key[[1L]] else ""

    category_levels <- order_myc_table_category_levels(
      category_levels = category_levels,
      value_source = value_source,
      current_market_year_key = current_market_year_key
    )
    if (length(category_levels) == 0L) {
      return(NULL)
    }

    market_year_labels <- vapply(
      x_category_levels,
      format_myc_market_year_label,
      character(1),
      source_choice = source_choice,
      comparison_baseline_label = comparison_baseline_label
    )
    year_headers <- make_unique_myc_table_headers(market_year_labels)
    year_header_by_key <- stats::setNames(year_headers, x_category_levels)

    baseline_market_year_key <- as.character(comparison_baseline_label %||% "")
    baseline_market_year_key <- baseline_market_year_key[!is.na(baseline_market_year_key) & nzchar(baseline_market_year_key)]
    baseline_market_year_key <- if (length(baseline_market_year_key) > 0L) baseline_market_year_key[[1L]] else ""

    current_year_header <- if (nzchar(current_market_year_key) && current_market_year_key %in% names(year_header_by_key)) {
      year_header_by_key[[current_market_year_key]]
    } else {
      NA_character_
    }
    baseline_header <- if (nzchar(baseline_market_year_key) && baseline_market_year_key %in% names(year_header_by_key)) {
      year_header_by_key[[baseline_market_year_key]]
    } else {
      NA_character_
    }

    comparison_mode <- trimws(as.character(plot_state$comparison_mode %||% "country"))
    comparison_mode <- comparison_mode[!is.na(comparison_mode) & nzchar(comparison_mode)]
    comparison_mode <- if (length(comparison_mode) > 0L) comparison_mode[[1L]] else "country"
    category_column_name <- myc_category_column_header(comparison_mode)

    unit_basis_label <- if (identical(table_mode, "share")) {
      "Percent (%)"
    } else {
      plot_state$unit_label %||% "current units"
    }

    table_df <- data.frame(row_category = c("Total", category_levels), stringsAsFactors = FALSE)
    names(table_df)[[1L]] <- category_column_name
    table_df[["Unit/Basis"]] <- rep(unit_basis_label, nrow(table_df))

    total_values <- vapply(x_category_levels, function(market_year_key) {
      matched_total <- total_source[total_source$market_year_key == market_year_key, , drop = FALSE]
      if (nrow(matched_total) == 0L) {
        return(0)
      }

      if (identical(table_mode, "share")) {
        suppressWarnings(as.numeric(matched_total$total_share[[1]]))
      } else {
        suppressWarnings(as.numeric(matched_total$total_value[[1]]))
      }
    }, numeric(1))

    total_values[is.na(total_values) | !is.finite(total_values)] <- 0

    for (year_idx in seq_along(x_category_levels)) {
      market_year_key <- x_category_levels[[year_idx]]
      year_header <- year_headers[[year_idx]]

      category_values <- vapply(category_levels, function(partner_name) {
        matched <- value_source$table_value[value_source$market_year_key == market_year_key & value_source$partner_key == partner_name]
        if (length(matched) == 0L) {
          return(0)
        }

        matched_value <- suppressWarnings(as.numeric(matched[[1]]))
        if (!is.finite(matched_value)) {
          return(0)
        }

        matched_value
      }, numeric(1))

      table_df[[year_header]] <- c(total_values[[year_idx]], category_values)
    }

    comparison_enabled <- identical(table_comparison_mode, "comparison")
    comparison_has_baseline <- !is.na(baseline_header) && nzchar(baseline_header) && baseline_header %in% names(table_df)
    comparison_has_current <- !is.na(current_year_header) && nzchar(current_year_header) && current_year_header %in% names(table_df)

    difference_header <- NA_character_
    percent_difference_header <- NA_character_

    if (isTRUE(comparison_enabled)) {
      baseline_label_for_header <- if (comparison_has_baseline) baseline_header else (plot_state$comparison_baseline_label %||% "Historical Avg")
      difference_header <- paste0("Difference vs ", baseline_label_for_header)
      percent_difference_header <- paste0("% Difference vs ", baseline_label_for_header)

      current_values <- if (comparison_has_current) suppressWarnings(as.numeric(table_df[[current_year_header]])) else rep(NA_real_, nrow(table_df))
      baseline_values <- if (comparison_has_baseline) suppressWarnings(as.numeric(table_df[[baseline_header]])) else rep(NA_real_, nrow(table_df))

      comparison_values <- build_myc_table_comparison_values(current_values, baseline_values)
      difference_values <- comparison_values$difference_raw
      if (!comparison_has_baseline || !comparison_has_current) {
        difference_values[] <- NA_real_
      }
      percent_values <- format_myc_table_percent_difference(comparison_values$pct_difference_raw, digits = 1L, blank_for_na = TRUE)

      table_df[[difference_header]] <- difference_values
      table_df[[percent_difference_header]] <- percent_values

      non_comparison_cols <- setdiff(names(table_df), c(difference_header, percent_difference_header))
      current_insert_idx <- if (comparison_has_current) match(current_year_header, non_comparison_cols) else length(non_comparison_cols)
      if (length(current_insert_idx) == 0L || is.na(current_insert_idx)) {
        current_insert_idx <- length(non_comparison_cols)
      }
      reordered_cols <- append(non_comparison_cols, c(difference_header, percent_difference_header), after = current_insert_idx)
      table_df <- table_df[, reordered_cols, drop = FALSE]
    }

    numeric_value_headers <- c(year_headers, if (isTRUE(comparison_enabled) && !is.na(difference_header) && nzchar(difference_header)) difference_header else character(0))
    numeric_value_idx <- match(numeric_value_headers, names(table_df))
    current_year_idx <- match(current_year_header, names(table_df))
    baseline_idx <- match(baseline_header, names(table_df))
    difference_idx <- match(difference_header, names(table_df))
    percent_difference_idx <- match(percent_difference_header, names(table_df))

    final_headers <- make_unique_myc_table_headers(names(table_df))
    names(table_df) <- final_headers

    value_columns <- final_headers[as.integer(numeric_value_idx[!is.na(numeric_value_idx)])]
    value_columns <- value_columns[!is.na(value_columns) & nzchar(value_columns)]

    current_year_header <- if (!is.na(current_year_idx)) final_headers[[current_year_idx]] else NA_character_
    baseline_header <- if (!is.na(baseline_idx)) final_headers[[baseline_idx]] else NA_character_
    difference_header <- if (!is.na(difference_idx)) final_headers[[difference_idx]] else NA_character_
    percent_difference_header <- if (!is.na(percent_difference_idx)) final_headers[[percent_difference_idx]] else NA_character_

    list(
      table_df = table_df,
      value_columns = value_columns,
      table_mode = table_mode,
      table_comparison_mode = table_comparison_mode,
      unit_basis_label = unit_basis_label,
      market_year_levels = x_category_levels,
      legend_levels = legend_levels,
      category_levels = category_levels,
      year_headers = year_headers,
      year_header_by_key = year_header_by_key,
      category_column_name = category_column_name,
      comparison_mode = comparison_mode,
      current_market_year_key = current_market_year_key,
      baseline_market_year_key = baseline_market_year_key,
      current_year_header = current_year_header,
      baseline_header = baseline_header,
      comparison_enabled = comparison_enabled,
      comparison_has_baseline = comparison_has_baseline,
      comparison_has_current = comparison_has_current,
      difference_header = difference_header,
      percent_difference_header = percent_difference_header
    )
  }

  build_myc_table_comparison_dt_config <- function(table_state) {
    if (is.null(table_state) || !isTRUE(table_state$comparison_enabled) || !is.data.frame(table_state$table_df) || nrow(table_state$table_df) == 0) {
      return(list(column_defs = list(), callback = JS("")))
    }

    table_df <- table_state$table_df
    baseline_target <- match(table_state$baseline_header, names(table_df)) - 1L
    difference_target <- match(table_state$difference_header, names(table_df)) - 1L
    percent_target <- match(table_state$percent_difference_header, names(table_df)) - 1L

    baseline_target <- as.integer(baseline_target[!is.na(baseline_target) & baseline_target >= 0L])
    difference_target <- as.integer(difference_target[!is.na(difference_target) & difference_target >= 0L])
    percent_target <- as.integer(percent_target[!is.na(percent_target) & percent_target >= 0L])

    comparison_targets <- as.integer(c(baseline_target, difference_target, percent_target))
    regular_targets <- as.integer(c(baseline_target, difference_target))

    column_defs <- list()
    if (length(baseline_target) > 0L) {
      column_defs <- c(column_defs, list(list(targets = baseline_target, className = "psd-summary-comparison-start")))
    }
    if (length(regular_targets) > 0L) {
      column_defs <- c(column_defs, list(list(targets = regular_targets, className = "psd-summary-comparison-band")))
    }
    if (length(percent_target) > 0L) {
      column_defs <- c(column_defs, list(list(targets = percent_target, className = "psd-summary-comparison-percent")))
    }

    to_js_array <- function(values) {
      values <- as.integer(values %||% integer(0))
      values <- values[!is.na(values)]
      paste0("[", paste(values, collapse = ","), "]")
    }

    callback <- JS(
      "function applyMycComparisonHeaderClasses(){",
      paste0("  var mycComparisonTargets = ", to_js_array(comparison_targets), ";"),
      paste0("  var mycStartTargets = ", to_js_array(baseline_target), ";"),
      paste0("  var mycPercentTargets = ", to_js_array(percent_target), ";"),
      "  table.columns().every(function(index){",
      "    var header = $(this.header());",
      "    header.removeClass('psd-summary-comparison-band psd-summary-comparison-start psd-summary-comparison-percent');",
      "    if (mycComparisonTargets.indexOf(index) !== -1) { header.addClass('psd-summary-comparison-band'); }",
      "    if (mycStartTargets.indexOf(index) !== -1) { header.addClass('psd-summary-comparison-start'); }",
      "    if (mycPercentTargets.indexOf(index) !== -1) { header.addClass('psd-summary-comparison-percent'); }",
      "  });",
      "}",
      "table.off('draw.dt.mycComparisonClasses').on('draw.dt.mycComparisonClasses', applyMycComparisonHeaderClasses);",
      "applyMycComparisonHeaderClasses();"
    )

    list(column_defs = column_defs, callback = callback)
  }

  build_myc_table_sortable_dt_config <- function(table_state) {
    if (is.null(table_state) || !is.data.frame(table_state$table_df) || nrow(table_state$table_df) == 0L) {
      return(list(
        table_df = table_state$table_df %||% data.frame(),
        column_defs = list(),
        callback = JS(""),
        order_fixed = list(),
        order = list()
      ))
    }

    sortable_df <- table_state$table_df
    original_col_count <- ncol(sortable_df)
    if (original_col_count == 0L) {
      return(list(
        table_df = sortable_df,
        column_defs = list(),
        callback = JS(""),
        order_fixed = list(),
        order = list()
      ))
    }

    row_labels <- trimws(tolower(as.character(sortable_df[[1L]] %||% character(0))))
    is_total_row <- row_labels == "total"
    is_all_other_row <- grepl("^all\\s+other", row_labels)

    sortable_df[["..myc_sort_pin_top"]] <- ifelse(is_total_row, 0L, 1L)
    sortable_df[["..myc_sort_pin_bottom"]] <- ifelse(is_all_other_row, 1L, 0L)
    sortable_df[["..myc_sort_base_order"]] <- seq_len(nrow(sortable_df))

    # Sortable columns are numeric-focused only (from column 3 onward).
    sortable_visible_columns <- if (original_col_count >= 3L) names(sortable_df)[3:original_col_count] else character(0)

    visible_sort_column_defs <- list()
    percent_sort_target <- integer(0)
    for (column_name in sortable_visible_columns) {
      column_target <- as.integer(match(column_name, names(sortable_df)) - 1L)
      if (!is.finite(column_target) || column_target < 0L) {
        next
      }

      if (!is.na(table_state$percent_difference_header) && nzchar(table_state$percent_difference_header) && identical(column_name, table_state$percent_difference_header)) {
        percent_sort_target <- column_target
        visible_sort_column_defs <- c(visible_sort_column_defs, list(list(targets = column_target, type = "myc-pct-bottom")))
        next
      }

      helper_col_name <- paste0("..myc_sort_num_", length(grep("^\\.\\.myc_sort_num_", names(sortable_df))) + 1L)
      helper_values <- suppressWarnings(as.numeric(sortable_df[[column_name]]))
      helper_values[!is.finite(helper_values)] <- NA_real_
      sortable_df[[helper_col_name]] <- helper_values
      helper_target <- as.integer(match(helper_col_name, names(sortable_df)) - 1L)
      if (is.finite(helper_target) && helper_target >= 0L) {
        visible_sort_column_defs <- c(visible_sort_column_defs, list(list(targets = column_target, orderData = helper_target)))
      }
    }

    helper_targets <- grep("^\\.\\.myc_sort_", names(sortable_df)) - 1L
    helper_targets <- as.integer(helper_targets[helper_targets >= 0L])

    comparison_dt_config <- build_myc_table_comparison_dt_config(
      modifyList(table_state, list(table_df = sortable_df), keep.null = TRUE)
    )

    base_column_defs <- list()
    if (original_col_count >= 2L) {
      base_column_defs <- c(base_column_defs, list(list(targets = as.integer(c(0L, 1L)), orderable = FALSE)))
    } else if (original_col_count == 1L) {
      base_column_defs <- c(base_column_defs, list(list(targets = as.integer(0L), orderable = FALSE)))
    }

    if (length(helper_targets) > 0L) {
      base_column_defs <- c(base_column_defs, list(list(targets = helper_targets, visible = FALSE, searchable = FALSE)))
    }

    composed_column_defs <- c(base_column_defs, visible_sort_column_defs, comparison_dt_config$column_defs)

    callback_lines <- c(
      "if ($.fn.dataTable && $.fn.dataTable.ext && !$.fn.dataTable.ext.type.order['myc-pct-bottom-asc']) {",
      "  var mycParsePct = function(value){",
      "    var text = value == null ? '' : String(value).trim();",
      "    if (!text.length) { return null; }",
      "    var numeric = Number(text.replace(/,/g, '').replace(/%/g, ''));",
      "    return isFinite(numeric) ? numeric : null;",
      "  };",
      "  $.fn.dataTable.ext.type.order['myc-pct-bottom-asc'] = function(a, b){",
      "    var av = mycParsePct(a);",
      "    var bv = mycParsePct(b);",
      "    var aBlank = av === null;",
      "    var bBlank = bv === null;",
      "    if (aBlank && bBlank) { return 0; }",
      "    if (aBlank) { return 1; }",
      "    if (bBlank) { return -1; }",
      "    return av - bv;",
      "  };",
      "  $.fn.dataTable.ext.type.order['myc-pct-bottom-desc'] = function(a, b){",
      "    var av = mycParsePct(a);",
      "    var bv = mycParsePct(b);",
      "    var aBlank = av === null;",
      "    var bBlank = bv === null;",
      "    if (aBlank && bBlank) { return 0; }",
      "    if (aBlank) { return 1; }",
      "    if (bBlank) { return -1; }",
      "    return bv - av;",
      "  };",
      "}"
    )
    if (length(comparison_dt_config$callback) > 0L) {
      callback_lines <- c(callback_lines, as.character(comparison_dt_config$callback))
    }

    pin_top_target <- as.integer(match("..myc_sort_pin_top", names(sortable_df)) - 1L)
    pin_bottom_target <- as.integer(match("..myc_sort_pin_bottom", names(sortable_df)) - 1L)
    base_order_target <- as.integer(match("..myc_sort_base_order", names(sortable_df)) - 1L)

    order_fixed_pre <- list()
    if (is.finite(pin_top_target) && pin_top_target >= 0L) {
      order_fixed_pre <- c(order_fixed_pre, list(list(pin_top_target, "asc")))
    }
    if (is.finite(pin_bottom_target) && pin_bottom_target >= 0L) {
      order_fixed_pre <- c(order_fixed_pre, list(list(pin_bottom_target, "asc")))
    }

    order_fixed_post <- list()
    if (is.finite(base_order_target) && base_order_target >= 0L) {
      order_fixed_post <- c(order_fixed_post, list(list(base_order_target, "asc")))
    }

    order_fixed <- list(pre = order_fixed_pre, post = order_fixed_post)
    if (length(order_fixed$pre) == 0L && length(order_fixed$post) == 0L) {
      order_fixed <- list()
    }

    list(
      table_df = sortable_df,
      column_defs = composed_column_defs,
      callback = JS(callback_lines),
      order_fixed = order_fixed,
      order = list()
    )
  }

  observeEvent(input$myc_table_digits_decrease, {
    current_digits <- normalize_myc_table_value_digits(isolate(myc_table_value_digits()))
    myc_table_value_digits(max(summary_table_value_digits_min, current_digits - 1L))
  }, ignoreInit = TRUE)

  observeEvent(input$myc_table_digits_increase, {
    current_digits <- normalize_myc_table_value_digits(isolate(myc_table_value_digits()))
    myc_table_value_digits(min(summary_table_value_digits_max, current_digits + 1L))
  }, ignoreInit = TRUE)

  output$myc_table_digits_display <- renderText({
    paste0("Decimals: ", normalize_myc_table_value_digits(myc_table_value_digits()))
  })

  output$partner_share_plot_scroll_ui <- renderUI({
    NULL
  })

  publish_myc_market_year_table_dataset <- function(output_dir = app_output_dir) {
    if (!is_market_year_comparison_output_active()) {
      return(list(path = NULL, error = "No market year table data available to publish."))
    }

    plot_state <- market_year_partner_plot_state()
    source_choice <- current_source_choice_safe(default = input$data_source_choice %||% "export_sales")
    table_state <- build_myc_market_year_table_state(
      plot_state = plot_state,
      table_mode = input$myc_table_measure_mode,
      table_comparison_mode = input$myc_table_comparison_mode,
      source_choice = source_choice
    )

    if (is.null(table_state) || !is.data.frame(table_state$table_df) || nrow(table_state$table_df) == 0) {
      return(list(path = NULL, error = "No market year table data available to publish."))
    }

    table_to_publish <- round_myc_market_year_table_values(
      table_state$table_df,
      value_columns = table_state$value_columns,
      digits = myc_table_value_digits()
    )

    mode_label <- if (identical(table_state$table_mode, "share")) "Shares" else "Values"
    metric_label <- paste(get_active_metric_label(), "Market Year Table", mode_label, sep = " - ")
    commodity_label <- get_active_commodity_label()
    country_label <- get_active_country_label(input$country_choice)

    publish_result <- tryCatch({
      publish_data_to_csv(
        data = table_to_publish,
        metric_label = metric_label,
        commodity_label = commodity_label,
        country_label = country_label,
        output_dir = output_dir
      )
    }, error = function(e) {
      e
    })

    if (inherits(publish_result, "error")) {
      return(list(path = NULL, error = conditionMessage(publish_result)))
    }

    list(path = publish_result, error = NULL)
  }

  output$myc_market_year_table <- renderDT({
    if (!is_market_year_comparison_output_active()) {
      record_myc_partner_output_lifecycle("table", "gated_skip")
      return(NULL)
    }

    start_time <- Sys.time()
    record_myc_partner_output_lifecycle("table", "executed")

    plot_state <- market_year_partner_plot_state()
    source_choice <- current_source_choice_safe(default = input$data_source_choice %||% "export_sales")
    table_state <- build_myc_market_year_table_state(
      plot_state = plot_state,
      table_mode = input$myc_table_measure_mode,
      table_comparison_mode = input$myc_table_comparison_mode,
      source_choice = source_choice
    )

    if (is.null(table_state) || !is.data.frame(table_state$table_df) || nrow(table_state$table_df) == 0) {
      log_perf(
        "myc_market_year_table",
        start_time,
        details = list(
          source = input$data_source_choice,
          status = "empty",
          rows = 0,
          mode = resolve_myc_table_measure_mode(input$myc_table_measure_mode)
        )
      )
      return(NULL)
    }

    sortable_dt_config <- build_myc_table_sortable_dt_config(table_state)
    dt_options <- list(
      dom = "t",
      paging = FALSE,
      searching = FALSE,
      ordering = TRUE,
      autoWidth = FALSE
    )
    if (length(sortable_dt_config$column_defs) > 0L) {
      dt_options$columnDefs <- sortable_dt_config$column_defs
    }
    if (length(sortable_dt_config$order_fixed) > 0L) {
      dt_options$orderFixed <- sortable_dt_config$order_fixed
    }
    if (length(sortable_dt_config$order) > 0L || is.list(sortable_dt_config$order)) {
      dt_options$order <- sortable_dt_config$order
    }

    result <- datatable(
      sortable_dt_config$table_df,
      options = dt_options,
      rownames = FALSE,
      selection = "none",
      callback = sortable_dt_config$callback
    )

    if (length(table_state$value_columns) > 0L) {
      result <- result %>%
        formatRound(
          columns = table_state$value_columns,
          digits = normalize_myc_table_value_digits(myc_table_value_digits()),
          mark = ","
        )
    }

    log_perf(
      "myc_market_year_table",
      start_time,
      details = list(
        source = input$data_source_choice,
        status = "ok",
        rows = nrow(table_state$table_df),
        cols = ncol(table_state$table_df),
        mode = table_state$table_mode,
        comparison_mode = table_state$table_comparison_mode,
        comparison_enabled = isTRUE(table_state$comparison_enabled),
        comparison_has_baseline = isTRUE(table_state$comparison_has_baseline),
        current_year_header = table_state$current_year_header %||% NA_character_,
        baseline_header = table_state$baseline_header %||% NA_character_
      )
    )

    result
  }, server = FALSE)

  observeEvent(input$publish_myc_market_year_table, {
    publish_result <- publish_myc_market_year_table_dataset()

    no_data_message <- "No market year table data available to publish."
    if (!is.null(publish_result$error)) {
      showNotification(
        if (identical(publish_result$error, no_data_message)) publish_result$error else paste("Publish failed:", publish_result$error),
        type = if (identical(publish_result$error, no_data_message)) "warning" else "error",
        duration = NULL
      )
      return(invisible(NULL))
    }

    showNotification(
      paste("Published data to", basename(publish_result$path)),
      type = "message"
    )
  }, ignoreInit = FALSE)

  output$partner_share_plot <- renderPlotly({
    if (!is_market_year_comparison_output_active()) {
      record_myc_partner_output_lifecycle("plot", "gated_skip")
      return(NULL)
    }

    start_time <- Sys.time()
    record_myc_partner_output_lifecycle("plot", "executed")
    record_partner_share_data_read("partner_share_plot")
    share_data <- partner_share_data()

    if (is.null(share_data)) {
      null_reason <- if (exists("partner_share_data_null_reason", mode = "function")) {
        tryCatch(partner_share_data_null_reason(), error = function(e) NULL)
      } else {
        NULL
      }
      empty_title <- dplyr::case_when(
        identical(null_reason, "metric_missing") ~ "Metric not supported in Market Year Comparison Tool",
        identical(null_reason, "no_snapshot") ~ "No data available for current Market Year Comparison selection",
        identical(null_reason, "empty_metric") ~ "No data available for selected metric and comparison",
        TRUE ~ "No data available"
      )

      result <- plotly_empty_state(plot_title = empty_title)
      log_perf(
        "partner_share_plot",
        start_time,
        details = list(
          source = input$data_source_choice,
          status = "empty",
          null_reason = null_reason %||% "unknown",
          metric = NA_character_,
          rows = 0,
          partners = 0
        )
      )
      return(result)
    }

    plot_state <- market_year_partner_plot_state()
    if (is.null(plot_state) || nrow(plot_state$plot_data) == 0) {
      result <- NULL
      log_perf(
        "partner_share_plot",
        start_time,
        details = list(
          source = input$data_source_choice,
          metric = share_data$metric_col,
          rows = 0,
          partners = 0
        )
      )
      return(result)
    }

    plot_data <- plot_state$plot_data
    x_category_levels <- myc_plot_market_year_levels(plot_data)

    current_my <- plot_state$current_my
    latest_period_index <- plot_state$latest_period_index
    metric_col <- plot_state$metric_col
    comparison_label <- plot_state$comparison_label
    focus_label <- plot_state$focus_label
    unit_label <- plot_state$unit_label
    partner_levels <- plot_state$partner_levels
    all_other_breakdown <- plot_state$all_other_breakdown
    comparison_baseline_label <- plot_state$comparison_baseline_label %||% "Historical Avg"

    metric_label <- get_active_metric_label(metric_col)
    source_choice <- current_source_choice_safe(default = input$data_source_choice %||% "export_sales")
    display_month_mapping <- current_display_month_mapping(source_choice = source_choice)
    year_field_label <- build_map_display_year_field_label(source_choice = source_choice)
    year_share_label <- build_display_year_share_field_label(source_choice = source_choice)

    period_label <- if (identical(input$data_frequency, "monthly")) {
      period_idx <- suppressWarnings(as.integer(latest_period_index))
      period_month <- display_month_mapping %>%
        filter(analysis_month == period_idx) %>%
        pull(month_name)

      if (length(period_month) == 1 && !is.na(period_month) && nzchar(period_month)) {
        period_month
      } else {
        paste0("Period ", latest_period_index)
      }
    } else {
      paste0("Week ", latest_period_index)
    }

    p <- plot_ly()
    show_share_labels <- isTRUE(input$show_partner_shares)
    show_value_labels <- isTRUE(input$show_partner_values)
    text_pos <- if (show_share_labels || show_value_labels) "inside" else "none"

    # Muted thematic rainbow nodes for dynamic interpolation
    # Anchored to existing chart identity colors used elsewhere in the app.
    all_other_color <- "#9e9e9e"
    rainbow_base_nodes <- c(
      "#d62728", # Current-series red anchor
      "#c74f32", # Burnt orange
      "#b56f3a", # Muted amber
      "#9f8b45", # Olive-gold
      "#7b9a56", # Muted green
      "#5b9b73", # Soft teal-green
      "#3e8f94", # Muted teal
      "#2f83ab", # Blue-teal bridge
      "#1f77b4", # Historical-series blue anchor
      "#6b63a6"  # Muted violet
    )

    build_partner_color_map <- function(partner_levels, ranked_values) {
      color_map <- setNames(rep("#2f4f8f", length(partner_levels)), partner_levels)
      if ("All Other" %in% names(color_map)) {
        color_map[["All Other"]] <- all_other_color
      }

      valid_ranked <- ranked_values[is.finite(ranked_values)]
      ranked_desc <- names(sort(valid_ranked, decreasing = TRUE, na.last = NA))

      # Filter out "All Other" and any levels not in our map
      ranked_partners <- ranked_desc[ranked_desc != "All Other" & ranked_desc %in% names(color_map)]
      
      N <- length(ranked_partners)
      if (N == 0) {
        return(color_map)
      }

      # Dynamically stretch the color ramp to fit exactly N partners
      dynamic_palette <- colorRampPalette(rainbow_base_nodes)(N)

      for (i in seq_len(N)) {
        partner_name <- ranked_partners[[i]]
        color_map[[partner_name]] <- dynamic_palette[[i]]
      }

      color_map
    }

    ranked_values <- plot_state$ranked_values

    partner_color_map <- build_partner_color_map(partner_levels, ranked_values)

    for (pc in partner_levels) {
      df_pc <- plot_data %>%
        filter(partner_category == pc) %>%
        mutate(display_market_year = vapply(
          .data$market_year,
          format_myc_market_year_label,
          character(1),
          source_choice = source_choice,
          comparison_baseline_label = comparison_baseline_label
        )) %>%
        mutate(
          hover_text_base = sprintf(
            "<b>%s</b><br>%s: %s<br>%s: %s %s<br>%s: %s",
            display_market_year,
            comparison_label,
            partner_category,
            metric_label,
            format(round(plot_value, 0), big.mark = ",", scientific = FALSE),
            unit_label,
            year_share_label,
            sprintf("%.1f%%", ifelse(is.na(share_pct), 0, share_pct * 100))
          ),
          hover_text = ifelse(
            partner_category == "All Other" & !is.na(all_other_breakdown) & nzchar(all_other_breakdown),
            paste0(hover_text_base, "<br><br>Includes:<br>", all_other_breakdown),
            hover_text_base
          ),
          share_label = ifelse(is.na(share_pct), "", sprintf("%.1f%%", share_pct * 100)),
          value_label = format(round(plot_value, 0), big.mark = ",", scientific = FALSE),
          text_label = case_when(
            show_share_labels && show_value_labels ~ paste0(value_label, " (", share_label, ")"),
            show_share_labels ~ share_label,
            show_value_labels ~ value_label,
            TRUE ~ ""
          )
        )
      p <- p %>% add_bars(
        data = df_pc,
        x = ~market_year,
        y = ~plot_value,
        name = pc,
        text = ~text_label,
        hovertext = ~hover_text,
        hovertemplate = "%{hovertext}<extra></extra>",
        textposition = text_pos,
        textfont = list(color = "#ffffff", size = 11),
        marker = list(
          color = partner_color_map[[pc]],
          line = list(color = "#ffffff", width = 0.7)
        )
      )
    }

    result <- p %>%
      layout(
        barmode = "stack",
        title = paste0(metric_label, " through ", period_label, " - ", focus_label),
        xaxis = list(
          title = year_field_label,
          type = "category",
          categoryorder = "array",
          categoryarray = x_category_levels
        ),
        yaxis = list(title = paste(metric_label, unit_label)),
        legend = list(title = list(text = paste0("<b>", comparison_label, "</b>")), traceorder = "reversed"),
        hovermode = "closest",
        hoverdistance = 25
      )
    log_perf(
      "partner_share_plot",
      start_time,
      details = list(
        source = input$data_source_choice,
        metric = metric_col,
        rows = nrow(plot_data),
          partners = length(partner_levels),
          order_basis = plot_state$order_basis
      )
    )
    result
  })

  normalize_map_country_location <- function(country_code, country_label) {
    normalized_label <- trimws(as.character(country_label))
    normalized_label[!nzchar(normalized_label)] <- NA_character_
    normalized_label[is.na(normalized_label) & !is.na(country_code)] <- trimws(as.character(country_code[is.na(normalized_label)]))

    dplyr::case_when(
      normalized_label %in% c("World", "Grand Total") ~ NA_character_,
      normalized_label %in% c("China (Mainland)") ~ "China",
      normalized_label %in% c("Russia") ~ "Russian Federation",
      normalized_label %in% c("South Korea") ~ "Korea, Republic of",
      normalized_label %in% c("North Korea") ~ "Korea, Democratic People's Republic of",
      normalized_label %in% c("Iran") ~ "Iran, Islamic Republic of",
      normalized_label %in% c("Syria") ~ "Syrian Arab Republic",
      normalized_label %in% c("Venezuela") ~ "Venezuela, Bolivarian Republic of",
      normalized_label %in% c("Bolivia") ~ "Bolivia, Plurinational State of",
      normalized_label %in% c("Laos") ~ "Lao People's Democratic Republic",
      normalized_label %in% c("Moldova") ~ "Moldova, Republic of",
      normalized_label %in% c("Tanzania") ~ "Tanzania, United Republic of",
      normalized_label %in% c("Vietnam") ~ "Viet Nam",
      normalized_label %in% c("Brunei") ~ "Brunei Darussalam",
      normalized_label %in% c("Micronesia, Federated States") ~ "Micronesia, Federated States of",
      normalized_label %in% c("Czech Republic") ~ "Czechia",
      normalized_label %in% c("Western Samoa") ~ "Samoa",
      normalized_label %in% c("French Pacific Islands", "Guam", "Hong Kong", "Macau", "American Samoa", "Cayman Islands", "Turks And Caicos Islands") ~ NA_character_,
      TRUE ~ normalized_label
    )
  }

  map_measure_mode <- reactive({
    metric_col <- effective_main_metric()
    valid_modes <- if (identical(map_comparison_mode(), "comparison")) {
      c("percent_change", "absolute_change")
    } else if (is_psd_non_share_metric(metric_col, source_choice = input$data_source_choice %||% NULL)) {
      "quantity_value"
    } else {
      c("share_pct", "quantity_value")
    }

    current_mode <- if (!is.null(input$map_measure_mode)) input$map_measure_mode else valid_modes[[1]]
    if (!(current_mode %in% valid_modes)) {
      return(valid_modes[[1]])
    }

    current_mode
  })

  map_comparison_eligible_metric_codes <- reactive({
    unname(map_historical_comparison_metric_choices())
  })

  map_metric_comparison_eligible <- reactive({
    metric_col <- effective_main_metric()
    !is.null(metric_col) && metric_col %in% map_comparison_eligible_metric_codes()
  })

  map_comparison_mode <- reactive({
    if (!isTRUE(map_metric_comparison_eligible())) {
      return("current")
    }

    current_mode <- if (!is.null(input$map_comparison_mode)) input$map_comparison_mode else "current"
    if (!(current_mode %in% c("current", "comparison"))) {
      return("current")
    }

    current_mode
  })

  map_top_n_cutoff <- reactive({
    top_n_selection <- map_top_n_selection()

    if (is.null(top_n_selection)) {
      return(NULL)
    }

    as.integer(top_n_selection[[1]])
  })

  format_psd_coverage_label <- function(calendar_year, calendar_month, abbreviated = TRUE) {
    year_value <- suppressWarnings(as.integer(calendar_year))
    month_value <- suppressWarnings(as.integer(calendar_month))

    if (length(year_value) != 1 || length(month_value) != 1 ||
        is.na(year_value) || is.na(month_value) ||
        !is.finite(year_value) || !is.finite(month_value) ||
        month_value < 1 || month_value > 12) {
      return("Unavailable")
    }

    month_labels <- if (isTRUE(abbreviated)) month.abb else month.name
    paste(month_labels[[month_value]], year_value)
  }

  latest_psd_coverage_info <- function(df) {
    if (is.null(df) || nrow(df) == 0 || !all(c("calendar_year", "calendar_month") %in% names(df))) {
      return(list(year = NA_integer_, month = NA_integer_, sort_key = NA_integer_, label = "Unavailable", full_label = "Unavailable"))
    }

    coverage_df <- df %>%
      mutate(
        calendar_year_num = suppressWarnings(as.integer(.data$calendar_year)),
        calendar_month_num = suppressWarnings(as.integer(.data$calendar_month))
      ) %>%
      filter(
        !is.na(.data$calendar_year_num),
        !is.na(.data$calendar_month_num),
        is.finite(.data$calendar_year_num),
        is.finite(.data$calendar_month_num),
        .data$calendar_month_num >= 1,
        .data$calendar_month_num <= 12
      ) %>%
      mutate(period_sort = (.data$calendar_year_num * 100L) + .data$calendar_month_num) %>%
      arrange(desc(.data$period_sort))

    if (nrow(coverage_df) == 0) {
      return(list(year = NA_integer_, month = NA_integer_, sort_key = NA_integer_, label = "Unavailable", full_label = "Unavailable"))
    }

    list(
      year = coverage_df$calendar_year_num[[1]],
      month = coverage_df$calendar_month_num[[1]],
      sort_key = coverage_df$period_sort[[1]],
      label = format_psd_coverage_label(coverage_df$calendar_year_num[[1]], coverage_df$calendar_month_num[[1]], abbreviated = TRUE),
      full_label = format_psd_coverage_label(coverage_df$calendar_year_num[[1]], coverage_df$calendar_month_num[[1]], abbreviated = FALSE)
    )
  }

  psd_selected_country_label <- reactive({
    selected_country <- map_selected_country()
    choice_values <- unname(psd_map_country_choices())
    choice_labels <- names(psd_map_country_choices())

    if (is.null(selected_country) || !nzchar(selected_country)) {
      selected_country <- "GRAND_TOTAL"
    }

    matched_index <- match(selected_country, choice_values)
    if (length(matched_index) == 1 && !is.na(matched_index)) {
      return(choice_labels[[matched_index]])
    }

    if (identical(selected_country, "GRAND_TOTAL")) {
      return("World")
    }

    selected_country
  })

  psd_world_map_coverage_note <- reactive({
    if (!is_psd_effective_map_tab_active()) {
      return(NULL)
    }

    df <- map_source_data()
    selected_market_year <- suppressWarnings(as.numeric(map_selected_market_year()))
    if (is.null(df) || nrow(df) == 0 || !is.finite(selected_market_year)) {
      return("Latest period covered in PSD data: Unavailable.")
    }

    coverage_info <- latest_psd_coverage_info(df %>% filter(.data$market_year == selected_market_year))
    paste0("Latest period covered in PSD data: ", coverage_info$full_label, ".")
  })

  summarize_psd_world_release_periods <- function(release_periods) {
    periods <- trimws(as.character(release_periods %||% ""))
    if (!nzchar(periods)) {
      return("release period unavailable")
    }

    period_parts <- unique(periods[nzchar(periods)])
    period_parts <- unique(trimws(unlist(strsplit(period_parts, "|", fixed = TRUE))))
    period_parts <- period_parts[nzchar(period_parts)]

    if (length(period_parts) == 0) {
      return("release period unavailable")
    }

    if (length(period_parts) == 1) {
      return(paste0("release period ", period_parts[[1]]))
    }

    paste0(
      "release periods spanning ",
      period_parts[[1]],
      " through ",
      period_parts[[length(period_parts)]],
      " (",
      length(period_parts),
      " periods)"
    )
  }

  normalize_psd_world_flag <- function(value) {
    if (is.logical(value)) {
      return(isTRUE(value))
    }

    normalized <- trimws(tolower(as.character(value %||% "")))
    normalized %in% c("true", "t", "1", "yes", "y")
  }

  resolve_psd_world_note_metric_id <- function(metric_col, basis_choice) {
    metric_id_lookup <- stats::setNames(names(psd_metric_column_map), unname(psd_metric_column_map))
    normalized_metric_id <- unname(metric_id_lookup[metric_col])

    if (length(normalized_metric_id) != 1 || is.na(normalized_metric_id) || !nzchar(normalized_metric_id)) {
      return(NA_character_)
    }

    if (identical(normalized_metric_id, "yield")) {
      if (identical(basis_choice, "milled_eq")) {
        return("yield_milled_eq")
      }

      return("yield")
    }

    if (normalized_metric_id %in% psd_basis_pair_metric_ids && identical(basis_choice, "rough_eq")) {
      return(paste0(normalized_metric_id, "_rough_eq"))
    }

    normalized_metric_id
  }

  psd_world_note_metric_label <- function(metric_col, basis_choice) {
    metric_label <- get_active_metric_label(metric_col)
    normalized_metric_id <- resolve_psd_world_note_metric_id(metric_col, basis_choice)

    if (is.na(normalized_metric_id) || !nzchar(normalized_metric_id)) {
      return(metric_label)
    }

    if (identical(normalized_metric_id, "rough_production")) {
      return("Rough Production")
    }

    if (
      identical(normalized_metric_id, "yield") ||
      identical(normalized_metric_id, "yield_milled_eq") ||
      grepl("_rough_eq$", normalized_metric_id)
    ) {
      return(paste0(metric_label, " (", get_basis_label(basis_choice), ")"))
    }

    metric_label
  }

  psd_world_map_rollup_state <- reactive({
    if (!is_psd_effective_map_tab_active()) {
      return(NULL)
    }

    selected_market_year <- suppressWarnings(as.numeric(map_selected_market_year()))
    selected_commodity <- resolved_psd_app_commodity()
    if (length(selected_market_year) == 0L || is.na(selected_market_year[[1]]) || !is.finite(selected_market_year[[1]])) {
      return(NULL)
    }
    selected_market_year <- selected_market_year[[1]]

    metric_col <- effective_main_metric()
    basis_choice <- effective_basis_choice_for_metric(
      metric_col,
      resolve_basis_choice(selected_commodity, current_basis_choice_safe()),
      "psd"
    )
    normalized_metric_id <- resolve_psd_world_note_metric_id(metric_col, basis_choice)

    if (length(normalized_metric_id) == 0L || is.na(normalized_metric_id[[1]]) || !nzchar(normalized_metric_id[[1]])) {
      return(NULL)
    }
    normalized_metric_id <- normalized_metric_id[[1]]

    world_rows <- rice_data_psd_long %>%
      filter(
        .data$country == "GRAND_TOTAL",
        .data$commodity == selected_commodity,
        .data$market_year == selected_market_year,
        .data$normalized_metric_id == .env$normalized_metric_id
      ) %>%
      mutate(
        analysis_month_num = suppressWarnings(as.integer(.data$analysis_month)),
        release_year_num = suppressWarnings(as.integer(.data$release_year)),
        release_month_num = suppressWarnings(as.integer(.data$release_month))
      ) %>%
      arrange(
        dplyr::desc(.data$analysis_month_num),
        dplyr::desc(.data$release_year_num),
        dplyr::desc(.data$release_month_num)
      )

    if (nrow(world_rows) == 0) {
      return(NULL)
    }

    row <- world_rows[1, , drop = FALSE]
    raw_world_source <- trimws(as.character(row$world_source[[1]] %||% ""))
    raw_world_rollup_mode <- trimws(as.character(row$world_rollup_mode[[1]] %||% ""))
    raw_release_periods <- trimws(as.character(row$world_rollup_release_periods[[1]] %||% ""))
    native_reference <- suppressWarnings(as.numeric(row$world_native_value_reference[[1]]))
    derived_reference <- suppressWarnings(as.numeric(row$world_derived_value_reference[[1]]))
    release_summary <- summarize_psd_world_release_periods(raw_release_periods)
    inferred_mixed_release <- grepl("|", raw_release_periods, fixed = TRUE)
    inferred_conflict <-
      identical(raw_world_rollup_mode, "native_world_preserved") &&
      is.finite(native_reference) &&
      is.finite(derived_reference) &&
      abs(native_reference - derived_reference) > 1e-6

    list(
      metric_col = metric_col,
      basis_choice = basis_choice,
      metric_label = psd_world_note_metric_label(metric_col, basis_choice),
      normalized_metric_id = normalized_metric_id,
      market_year = selected_market_year,
      world_source = raw_world_source,
      world_rollup_mode = raw_world_rollup_mode,
      world_is_mixed_release = normalize_psd_world_flag(row$world_is_mixed_release[[1]]) || inferred_mixed_release,
      world_value_conflict_flag = normalize_psd_world_flag(row$world_value_conflict_flag[[1]]) || inferred_conflict,
      world_native_value_reference = native_reference,
      world_derived_value_reference = derived_reference,
      release_summary = release_summary
    )
  })

  psd_world_map_rollup_note <- reactive({
    state <- psd_world_map_rollup_state()
    if (
      is.null(state) ||
      identical(state$world_rollup_mode, "native_world_endpoint") ||
      (!identical(state$world_source, "derived_world_asof") &&
         !identical(state$world_rollup_mode, "derived_world_asof") &&
         !identical(state$world_rollup_mode, "native_world_preserved"))
    ) {
      return(NULL)
    }

    if (isTRUE(state$world_value_conflict_flag) && identical(state$world_rollup_mode, "native_world_preserved")) {
      return(NULL)
    }

    if (isTRUE(state$world_is_mixed_release)) {
      return(paste0(
        "World ",
        state$metric_label,
        " uses an as-of country rollup built from mixed country ",
        state$release_summary,
        "."
      ))
    }

    paste0(
      "World ",
      state$metric_label,
      " uses an as-of country rollup built from the latest available country rows for MY ",
      state$market_year,
      " (",
      state$release_summary,
      ")."
    )
  })

  psd_world_map_conflict_note <- reactive({
    state <- psd_world_map_rollup_state()
    if (
      is.null(state) ||
      !isTRUE(state$world_value_conflict_flag) ||
      !identical(state$world_rollup_mode, "native_world_preserved")
    ) {
      return(NULL)
    }

    value_detail <- if (
      is.finite(state$world_native_value_reference) &&
      is.finite(state$world_derived_value_reference)
    ) {
      paste0(
        " Native WORLD=",
        format(signif(state$world_native_value_reference, 8), trim = TRUE, scientific = FALSE),
        ", derived rollup=",
        format(signif(state$world_derived_value_reference, 8), trim = TRUE, scientific = FALSE),
        "."
      )
    } else {
      ""
    }

    paste0(
      "World ",
      state$metric_label,
      " keeps the native PSD World value because it conflicts with the derived country rollup.",
      if (isTRUE(state$world_is_mixed_release)) {
        paste0(" The comparison used mixed country ", state$release_summary, ".")
      } else {
        paste0(" The comparison used the latest available country rows for MY ", state$market_year, " (", state$release_summary, ").")
      },
      value_detail
    )
  })

  psd_matrix_country_coverage_note <- reactive({
    if (!is_psd_effective_map_tab_active()) {
      return(NULL)
    }

    selected_country <- map_selected_country()
    if (is.null(selected_country) || !nzchar(selected_country)) {
      selected_country <- "GRAND_TOTAL"
    }

    coverage_info <- latest_psd_coverage_info(rice_data_psd_long %>% filter(.data$country == selected_country))
    paste0(
      "Latest period covered in PSD data for ",
      psd_selected_country_label(),
      ": ",
      coverage_info$full_label,
      "."
    )
  })

  build_map_matched_snapshot <- function(snapshot_df, metric_col) {
    if (is.null(snapshot_df) || nrow(snapshot_df) == 0 || !nzchar(metric_col) || !(metric_col %in% names(snapshot_df))) {
      return(list(
        matched_df = data.frame(),
        table_df = data.frame(),
        unmatched_labels = character(0)
      ))
    }

    has_country_description <- "countryDescription" %in% names(snapshot_df)
    has_country_label <- "country_label" %in% names(snapshot_df)
    has_map_location <- "map_location" %in% names(snapshot_df)
    has_calendar_year_num <- "calendar_year_num" %in% names(snapshot_df)
    has_calendar_month_num <- "calendar_month_num" %in% names(snapshot_df)
    has_calendar_year <- "calendar_year" %in% names(snapshot_df)
    has_calendar_month <- "calendar_month" %in% names(snapshot_df)
    has_latest_period_sort <- "latest_period_sort" %in% names(snapshot_df)

    year_df <- snapshot_df %>%
      mutate(quantity_value = suppressWarnings(as.numeric(.data[[metric_col]]))) %>%
      filter(!is.na(.data$quantity_value), is.finite(.data$quantity_value), .data$quantity_value >= 0) %>%
      mutate(
        country_label = if (has_country_label) {
          .data$country_label
        } else {
          normalize_myc_country_display_label(
            .data$country,
            if (has_country_description) .data$countryDescription else NA_character_
          )
        },
        map_location = if (has_map_location) {
          .data$map_location
        } else {
          normalize_map_country_location(.data$country, .data$country_label)
        },
        calendar_year_num = if (has_calendar_year_num) {
          suppressWarnings(as.integer(.data$calendar_year_num))
        } else if (has_calendar_year) {
          suppressWarnings(as.integer(.data$calendar_year))
        } else {
          NA_integer_
        },
        calendar_month_num = if (has_calendar_month_num) {
          suppressWarnings(as.integer(.data$calendar_month_num))
        } else if (has_calendar_month) {
          suppressWarnings(as.integer(.data$calendar_month))
        } else {
          NA_integer_
        },
        latest_period_sort = if (has_latest_period_sort) {
          suppressWarnings(as.integer(.data$latest_period_sort))
        } else {
          dplyr::if_else(
            !is.na(.data$calendar_year_num) & !is.na(.data$calendar_month_num) &
              is.finite(.data$calendar_year_num) & is.finite(.data$calendar_month_num) &
              .data$calendar_month_num >= 1 & .data$calendar_month_num <= 12,
            (.data$calendar_year_num * 100L) + .data$calendar_month_num,
            NA_integer_
          )
        }
      )

    if (nrow(year_df) == 0) {
      return(list(
        matched_df = data.frame(),
        table_df = data.frame(),
        unmatched_labels = character(0)
      ))
    }

    table_df <- year_df %>%
      group_by(.data$country) %>%
      arrange(dplyr::desc(.data$latest_period_sort), .by_group = TRUE) %>%
      summarise(
        selected_country_key = dplyr::first(.data$country),
        country_label = dplyr::first(.data$country_label),
        map_location = dplyr::first(.data$map_location),
        quantity_value = sum(.data$quantity_value, na.rm = TRUE),
        latest_period_sort = dplyr::first(.data$latest_period_sort),
        latest_calendar_year = dplyr::first(.data$calendar_year_num),
        latest_calendar_month = dplyr::first(.data$calendar_month_num),
        .groups = "drop"
      )

    total_quantity <- sum(table_df$quantity_value, na.rm = TRUE)
    table_df <- table_df %>%
      mutate(
        share_pct = if (is.finite(total_quantity) && total_quantity > 0) .data$quantity_value / total_quantity else 0
      )

    unmatched_labels <- table_df %>%
      filter(is.na(.data$map_location) | !nzchar(.data$map_location)) %>%
      pull(.data$country_label) %>%
      unique() %>%
      sort()

    matched_df <- table_df %>%
      filter(!is.na(.data$map_location), nzchar(.data$map_location)) %>%
      group_by(.data$map_location) %>%
      arrange(dplyr::desc(.data$latest_period_sort), .by_group = TRUE) %>%
      summarise(
        selected_country_key = dplyr::first(.data$selected_country_key),
        country_label = paste(sort(unique(.data$country_label)), collapse = " / "),
        quantity_value = sum(.data$quantity_value, na.rm = TRUE),
        share_pct = sum(.data$share_pct, na.rm = TRUE),
        latest_period_sort = dplyr::first(.data$latest_period_sort),
        latest_calendar_year = dplyr::first(.data$latest_calendar_year),
        latest_calendar_month = dplyr::first(.data$latest_calendar_month),
        .groups = "drop"
      )

    list(
      matched_df = matched_df,
      table_df = table_df,
      unmatched_labels = unmatched_labels
    )
  }

  map_comparison_dataset_cache_key <- reactive({
    list(
      runtime_source = map_runtime_source_cache_key(),
      selected_market_year = map_selected_market_year(),
      cutoff_state = map_cutoff_state(),
      comparison_mode = map_comparison_mode(),
      measure_mode = map_measure_mode(),
      comparison_hist_years = map_comparison_hist_years_committed(),
      projection_basis_mode = input$map_projection_basis_mode,
      projection_reference_year = input$map_projection_reference_year
    )
  })

  map_comparison_dataset <- reactive({
    record_cache_body_execution(session, "map_comparison_dataset")
    snapshot_base <- map_snapshot_base()
    selected_market_year <- suppressWarnings(as.numeric(map_selected_market_year()))
    metric_col <- effective_main_metric()
    df_source <- map_source_data()
    is_psd_source <- identical(input$data_source_choice, "psd")

    empty_state <- function(status,
                            baseline_label = NA_character_,
                            basis_mode = NA_character_,
                            reference_year = NA_real_,
                            hist_years = NA_integer_,
                            baseline_years = numeric(0),
                            unmatched_labels = character(0),
                            emphasis_ranked_df = data.frame(),
                            table_ranked_df = data.frame()) {
      list(
        status = status,
        metric_col = metric_col,
        selected_market_year = selected_market_year,
        latest_period_index = if (!is.null(snapshot_base)) snapshot_base$latest_period_index else NA_real_,
        selected_period_label = if (!is.null(snapshot_base)) snapshot_base$selected_period_label else NA_character_,
        baseline_label = baseline_label,
        basis_mode = basis_mode,
        reference_year = reference_year,
        hist_years = hist_years,
        baseline_years = baseline_years,
        ranked_df = data.frame(),
        emphasis_ranked_df = emphasis_ranked_df,
        table_ranked_df = table_ranked_df,
        unmatched_labels = unmatched_labels
      )
    }

    if (!isTRUE(map_metric_comparison_eligible())) {
      return(empty_state("comparison_metric_ineligible"))
    }

    if (is.null(snapshot_base) || is.null(df_source) || nrow(df_source) == 0 || !is.finite(selected_market_year)) {
      return(empty_state("no_data"))
    }

    current_snapshot_df <- snapshot_base$snapshot_df %>%
      filter(.data$market_year == selected_market_year)
    current_snapshot <- build_map_matched_snapshot(current_snapshot_df, metric_col)
    current_df <- current_snapshot$matched_df
    current_table_df <- current_snapshot$table_df

    if (nrow(current_table_df) == 0) {
      return(empty_state("no_year_data", unmatched_labels = current_snapshot$unmatched_labels))
    }

    comparison_state <- read_comparison_state_bundle_safe(
      surface = "map",
      source_choice = input$data_source_choice,
      year_choices = sort(unique(df_source$market_year)),
      hist_years_override = map_comparison_hist_years_committed()
    )
    hist_window <- comparison_state$hist_years
    basis_mode <- comparison_state$basis_mode
    reference_year <- suppressWarnings(as.numeric(comparison_state$reference_year))
    has_reference_year <- length(reference_year) == 1 && !is.na(reference_year) && is.finite(reference_year)

    baseline_years <- if (identical(basis_mode, "single_year") && has_reference_year) {
      reference_year
    } else {
      all_years <- sort(unique(df_source$market_year))
      all_years[is.finite(all_years) & all_years < selected_market_year & all_years >= (selected_market_year - hist_window)]
    }
    baseline_years <- sort(unique(baseline_years[is.finite(baseline_years)]))
    baseline_label <- if (identical(basis_mode, "single_year") && has_reference_year) {
      build_map_display_year_label(reference_year, source_choice = input$data_source_choice)
    } else {
      paste0("Historical Avg (", length(baseline_years), " yrs)")
    }

    if (length(baseline_years) == 0) {
      return(empty_state(
        "no_baseline_data",
        baseline_label = baseline_label,
        basis_mode = basis_mode,
        reference_year = if (has_reference_year) reference_year else NA_real_,
        hist_years = hist_window,
        baseline_years = baseline_years,
        unmatched_labels = current_snapshot$unmatched_labels
      ))
    }

    baseline_snapshots <- lapply(baseline_years, function(baseline_year) {
      df_year <- df_source %>% filter(.data$market_year == baseline_year)
      if (nrow(df_year) == 0) {
        return(NULL)
      }

      baseline_snapshot_df <- latest_available_snapshot_by_group(
        df = df_year,
        group_col = "country",
        cutoff_period = if (is_psd_source) NULL else snapshot_base$latest_period_index
      )
      baseline_snapshot <- build_map_matched_snapshot(baseline_snapshot_df, metric_col)
      if (nrow(baseline_snapshot$matched_df) == 0 && nrow(baseline_snapshot$table_df) == 0) {
        return(NULL)
      }

      list(
        baseline_year = baseline_year,
        matched_df = baseline_snapshot$matched_df,
        table_df = baseline_snapshot$table_df
      )
    })
    baseline_snapshots <- Filter(Negate(is.null), baseline_snapshots)

    baseline_parts <- lapply(baseline_snapshots, function(snapshot_entry) {
      baseline_matched_df <- snapshot_entry$matched_df
      if (nrow(baseline_matched_df) == 0) {
        return(NULL)
      }

      baseline_matched_df %>%
        transmute(
          map_location = .data$map_location,
          selected_country_key = .data$selected_country_key,
          country_label = .data$country_label,
          baseline_market_year = snapshot_entry$baseline_year,
          baseline_value = .data$quantity_value
        )
    })
    baseline_parts <- Filter(Negate(is.null), baseline_parts)

    baseline_table_parts <- lapply(baseline_snapshots, function(snapshot_entry) {
      baseline_table_df <- snapshot_entry$table_df
      if (nrow(baseline_table_df) == 0) {
        return(NULL)
      }

      baseline_table_df %>%
        transmute(
          selected_country_key = .data$selected_country_key,
          country_label = .data$country_label,
          baseline_market_year = snapshot_entry$baseline_year,
          baseline_value = .data$quantity_value
        )
    })
    baseline_table_parts <- Filter(Negate(is.null), baseline_table_parts)

    if (length(baseline_parts) == 0 && length(baseline_table_parts) == 0) {
      return(empty_state(
        "no_baseline_data",
        baseline_label = baseline_label,
        basis_mode = basis_mode,
        reference_year = if (has_reference_year) reference_year else NA_real_,
        hist_years = hist_window,
        baseline_years = baseline_years,
        unmatched_labels = current_snapshot$unmatched_labels
      ))
    }

    baseline_table_df <- if (length(baseline_table_parts) == 0) {
      data.frame(
        selected_country_key = character(),
        country_label = character(),
        baseline_value = numeric(),
        stringsAsFactors = FALSE
      )
    } else {
      bind_rows(baseline_table_parts) %>%
        group_by(.data$selected_country_key) %>%
        summarise(
          country_label = dplyr::first(.data$country_label),
          baseline_value = mean(.data$baseline_value, na.rm = TRUE),
          .groups = "drop"
        )
    }

    table_ranked_df <- full_join(
      current_table_df %>%
        transmute(
          selected_country_key = .data$selected_country_key,
          country_label = .data$country_label,
          current_value = .data$quantity_value,
          share_pct = .data$share_pct,
          latest_period_sort = .data$latest_period_sort,
          latest_calendar_year = .data$latest_calendar_year,
          latest_calendar_month = .data$latest_calendar_month
        ),
      baseline_table_df %>%
        transmute(
          selected_country_key = .data$selected_country_key,
          baseline_country_label = .data$country_label,
          baseline_value = .data$baseline_value
        ),
      by = "selected_country_key"
    ) %>%
      mutate(
        country_label = dplyr::coalesce(.data$country_label, .data$baseline_country_label, .data$selected_country_key),
        current_value = dplyr::coalesce(.data$current_value, 0),
        share_pct = dplyr::coalesce(.data$share_pct, 0),
        baseline_value = dplyr::coalesce(.data$baseline_value, 0),
        absolute_change = .data$current_value - .data$baseline_value,
        percent_change = dplyr::if_else(
          .data$baseline_value > 0,
          (.data$absolute_change / .data$baseline_value) * 100,
          NA_real_
        )
      ) %>%
      select(-baseline_country_label)

    baseline_df <- bind_rows(baseline_parts) %>%
      group_by(.data$map_location) %>%
      summarise(
        selected_country_key = dplyr::first(.data$selected_country_key),
        country_label = paste(sort(unique(.data$country_label)), collapse = " / "),
        baseline_value = mean(.data$baseline_value, na.rm = TRUE),
        .groups = "drop"
      )

    comparison_df <- full_join(
      current_df %>%
        transmute(
          map_location = .data$map_location,
          selected_country_key = .data$selected_country_key,
          country_label = .data$country_label,
          current_value = .data$quantity_value,
          share_pct = .data$share_pct,
          latest_period_sort = .data$latest_period_sort,
          latest_calendar_year = .data$latest_calendar_year,
          latest_calendar_month = .data$latest_calendar_month
        ),
      baseline_df %>%
        transmute(
          map_location = .data$map_location,
          baseline_selected_country_key = .data$selected_country_key,
          baseline_country_label = .data$country_label,
          baseline_value = .data$baseline_value
        ),
      by = "map_location"
    ) %>%
      mutate(
        selected_country_key = dplyr::coalesce(.data$selected_country_key, .data$baseline_selected_country_key, .data$country_label),
        country_label = dplyr::coalesce(.data$country_label, .data$baseline_country_label),
        current_value = dplyr::coalesce(.data$current_value, 0),
        share_pct = dplyr::coalesce(.data$share_pct, 0),
        baseline_value = dplyr::coalesce(.data$baseline_value, 0),
        absolute_change = .data$current_value - .data$baseline_value,
        percent_change = dplyr::if_else(
          .data$baseline_value > 0,
          (.data$absolute_change / .data$baseline_value) * 100,
          NA_real_
        )
      ) %>%
      select(-baseline_country_label, -baseline_selected_country_key)

    if (nrow(comparison_df) == 0) {
      return(empty_state(
        "no_mappable_data",
        baseline_label = baseline_label,
        basis_mode = basis_mode,
        reference_year = if (has_reference_year) reference_year else NA_real_,
        hist_years = hist_window,
        baseline_years = baseline_years,
        unmatched_labels = current_snapshot$unmatched_labels
      ))
    }

    emphasis_ranked_df <- current_df %>%
      transmute(
        map_location = .data$map_location,
        selected_country_key = .data$selected_country_key,
        country_label = .data$country_label,
        current_value = .data$quantity_value,
        share_pct = .data$share_pct,
        latest_period_sort = .data$latest_period_sort,
        latest_calendar_year = .data$latest_calendar_year,
        latest_calendar_month = .data$latest_calendar_month
      ) %>%
      arrange(desc(.data$current_value), desc(.data$share_pct), .data$country_label) %>%
      mutate(emphasis_rank = dplyr::row_number())

    comparison_metric <- map_measure_mode()
    table_ranked_df <- table_ranked_df %>%
      mutate(
        comparison_sort_value = if (identical(comparison_metric, "percent_change")) .data$percent_change else .data$absolute_change,
        comparison_available = is.finite(.data$comparison_sort_value)
      ) %>%
      arrange(
        desc(.data$comparison_available),
        desc(.data$comparison_sort_value),
        desc(.data$absolute_change),
        desc(.data$current_value),
        .data$country_label
      ) %>%
      mutate(rank = dplyr::row_number())

    ranked_df <- comparison_df %>%
      left_join(
        emphasis_ranked_df %>% select(all_of(c("map_location", "emphasis_rank"))),
        by = "map_location"
      ) %>%
      mutate(
        comparison_sort_value = if (identical(comparison_metric, "percent_change")) .data$percent_change else .data$absolute_change,
        comparison_available = is.finite(.data$comparison_sort_value)
      ) %>%
      arrange(
        desc(.data$comparison_available),
        desc(.data$comparison_sort_value),
        desc(.data$absolute_change),
        desc(.data$current_value),
        .data$country_label
      ) %>%
      mutate(rank = dplyr::row_number())

    list(
      status = "ok",
      metric_col = metric_col,
      selected_market_year = selected_market_year,
      latest_period_index = snapshot_base$latest_period_index,
      selected_period_label = snapshot_base$selected_period_label,
      baseline_label = baseline_label,
      basis_mode = basis_mode,
      reference_year = if (has_reference_year) reference_year else NA_real_,
      hist_years = hist_window,
      baseline_years = baseline_years,
      ranked_df = ranked_df,
      emphasis_ranked_df = emphasis_ranked_df,
      table_ranked_df = table_ranked_df,
      unmatched_labels = current_snapshot$unmatched_labels
    )
  }) %>% bindCache(
    map_comparison_dataset_cache_key()$runtime_source,
    map_comparison_dataset_cache_key()$selected_market_year,
    map_comparison_dataset_cache_key()$cutoff_state,
    map_comparison_dataset_cache_key()$comparison_mode,
    map_comparison_dataset_cache_key()$measure_mode,
    map_comparison_dataset_cache_key()$comparison_hist_years,
    map_comparison_dataset_cache_key()$projection_basis_mode,
    map_comparison_dataset_cache_key()$projection_reference_year
  )

  map_country_dataset_cache_key <- reactive({
    list(
      runtime_source = map_runtime_source_cache_key(),
      selected_market_year = map_selected_market_year(),
      cutoff_state = map_cutoff_state()
    )
  })

  map_country_dataset <- reactive({
    record_cache_body_execution(session, "map_country_dataset")
    snapshot_base <- map_snapshot_base()
    selected_market_year <- map_selected_market_year()
    metric_col <- effective_main_metric()

    if (is.null(snapshot_base) || is.null(selected_market_year)) {
      return(list(
        status = "no_data",
        metric_col = metric_col,
        selected_market_year = selected_market_year,
        matched_df = data.frame(),
        unmatched_labels = character(0),
        latest_period_index = NA_real_,
        selected_period_label = NA_character_
      ))
    }

    snapshot_df <- snapshot_base$snapshot_df
    if (is.null(snapshot_df) || nrow(snapshot_df) == 0) {
      return(list(
        status = "no_data",
        metric_col = metric_col,
        selected_market_year = selected_market_year,
        matched_df = data.frame(),
        unmatched_labels = character(0),
        latest_period_index = snapshot_base$latest_period_index,
        selected_period_label = snapshot_base$selected_period_label
      ))
    }

    if (!nzchar(metric_col) || !(metric_col %in% names(snapshot_df))) {
      return(list(
        status = "unsupported_metric",
        metric_col = metric_col,
        selected_market_year = selected_market_year,
        matched_df = data.frame(),
        unmatched_labels = character(0),
        latest_period_index = snapshot_base$latest_period_index,
        selected_period_label = snapshot_base$selected_period_label
      ))
    }

    year_df <- snapshot_df %>%
      filter(.data$market_year == as.numeric(selected_market_year)) %>%
      mutate(quantity_value = suppressWarnings(as.numeric(.data[[metric_col]]))) %>%
      filter(!is.na(.data$quantity_value), is.finite(.data$quantity_value), .data$quantity_value >= 0)

    if (nrow(year_df) == 0) {
      return(list(
        status = "no_year_data",
        metric_col = metric_col,
        selected_market_year = selected_market_year,
        matched_df = data.frame(),
        unmatched_labels = character(0),
        latest_period_index = snapshot_base$latest_period_index,
        selected_period_label = snapshot_base$selected_period_label
      ))
    }

    snapshot_state <- build_map_matched_snapshot(year_df, metric_col)
    matched_df <- snapshot_state$matched_df
    table_ranked_df <- snapshot_state$table_df %>%
      arrange(desc(.data$quantity_value), desc(.data$share_pct), .data$country_label) %>%
      mutate(rank = dplyr::row_number())

    status <- if (nrow(matched_df) == 0) "no_mappable_data" else "ok"
    zero_trade_count <- sum(matched_df$quantity_value <= 0, na.rm = TRUE)
    positive_trade_count <- sum(matched_df$quantity_value > 0, na.rm = TRUE)

    list(
      status = status,
      metric_col = metric_col,
      selected_market_year = selected_market_year,
      matched_df = matched_df,
      table_ranked_df = table_ranked_df,
      unmatched_labels = snapshot_state$unmatched_labels,
      zero_trade_count = zero_trade_count,
      positive_trade_count = positive_trade_count,
      latest_period_index = snapshot_base$latest_period_index,
      selected_period_label = snapshot_base$selected_period_label
    )
  }) %>% bindCache(
    map_country_dataset_cache_key()$runtime_source,
    map_country_dataset_cache_key()$selected_market_year,
    map_country_dataset_cache_key()$cutoff_state
  )

  map_ranked_dataset_cache_key <- reactive({
    list(
      runtime_source = map_runtime_source_cache_key(),
      selected_market_year = map_selected_market_year(),
      cutoff_state = map_cutoff_state(),
      comparison_mode = map_comparison_mode(),
      measure_mode = map_measure_mode(),
      comparison_fragment = if (identical(map_comparison_mode(), "comparison")) {
        paste(
          "map_comparison",
          map_comparison_hist_years_committed(),
          input$map_projection_basis_mode %||% "average",
          input$map_projection_reference_year %||% "none",
          sep = "|"
        )
      } else {
        "map_comparison_unused"
      }
    )
  })

  map_ranked_dataset <- reactive({
    record_cache_body_execution(session, "map_ranked_dataset")
    start_time <- Sys.time()
    is_psd_source <- identical(input$data_source_choice, "psd")

    if (identical(map_comparison_mode(), "comparison")) {
      map_state <- map_comparison_dataset()

      if (!identical(map_state$status, "ok") || nrow(map_state$ranked_df) == 0) {
        result <- list(
          mode = "comparison",
          map_state = map_state,
          ranked_df = data.frame(),
          emphasis_ranked_df = data.frame()
        )
        if (is_psd_source) {
          log_perf(
            "map_ranked_dataset()",
            start_time,
            details = list(
              source = "psd",
              mode = "comparison",
              status = map_state$status %||% "unknown",
              rows = 0,
              rank_basis_source = "map_comparison_dataset"
            )
          )
        }
        return(result)
      }

      result <- list(
        mode = "comparison",
        map_state = map_state,
        ranked_df = map_state$ranked_df,
        emphasis_ranked_df = map_state$emphasis_ranked_df
      )
      if (is_psd_source) {
        log_perf(
          "map_ranked_dataset()",
          start_time,
          details = list(
            source = "psd",
            mode = "comparison",
            status = map_state$status %||% "ok",
            rows = nrow(map_state$ranked_df),
            rank_basis_source = "map_comparison_dataset"
          )
        )
      }
      return(result)
    }

    map_state <- map_country_dataset()
    shade_mode <- map_measure_mode()

    if (!identical(map_state$status, "ok") || nrow(map_state$matched_df) == 0) {
      result <- list(
        mode = "current",
        map_state = map_state,
        ranked_df = data.frame(),
        emphasis_ranked_df = data.frame()
      )
      if (is_psd_source) {
        log_perf(
          "map_ranked_dataset()",
          start_time,
          details = list(source = "psd", mode = "current", status = map_state$status %||% "unknown", rows = 0)
        )
      }
      return(result)
    }

    ranked_df <- if (identical(shade_mode, "share_pct")) {
      map_state$matched_df %>%
        arrange(desc(.data$share_pct), desc(.data$quantity_value), .data$country_label)
    } else {
      map_state$matched_df %>%
        arrange(desc(.data$quantity_value), desc(.data$share_pct), .data$country_label)
    }

    ranked_df <- ranked_df %>%
      mutate(rank = dplyr::row_number())

    result <- list(
      mode = "current",
      map_state = map_state,
      ranked_df = ranked_df,
      emphasis_ranked_df = ranked_df
    )

    if (is_psd_source) {
      log_perf(
        "map_ranked_dataset()",
        start_time,
        details = list(source = "psd", mode = "current", status = map_state$status %||% "ok", rows = nrow(ranked_df))
      )
    }

    result
  }) %>% bindCache(
    map_ranked_dataset_cache_key()$runtime_source,
    map_ranked_dataset_cache_key()$selected_market_year,
    map_ranked_dataset_cache_key()$cutoff_state,
    map_ranked_dataset_cache_key()$comparison_mode,
    map_ranked_dataset_cache_key()$measure_mode,
    map_ranked_dataset_cache_key()$comparison_fragment
  )

  map_display_dataset_cache_key <- reactive({
    list(
      runtime_source = map_runtime_source_cache_key(),
      selected_market_year = map_selected_market_year(),
      cutoff_state = map_cutoff_state(),
      comparison_mode = map_comparison_mode(),
      measure_mode = map_measure_mode(),
      top_n_cutoff = map_top_n_cutoff(),
      comparison_fragment = if (identical(map_comparison_mode(), "comparison")) {
        paste(
          "map_comparison",
          map_comparison_hist_years_committed(),
          input$map_projection_basis_mode %||% "average",
          input$map_projection_reference_year %||% "none",
          sep = "|"
        )
      } else {
        "map_comparison_unused"
      }
    )
  })

  map_display_dataset <- reactive({
    record_cache_body_execution(session, "map_display_dataset")
    start_time <- Sys.time()
    top_n_cutoff <- map_top_n_cutoff()
    is_psd_source <- identical(input$data_source_choice, "psd")
    ranked_state <- map_ranked_dataset()
    display_mode <- ranked_state$mode
    map_state <- ranked_state$map_state

    if (identical(display_mode, "comparison")) {
      emphasis_ranked_df <- if (is.null(top_n_cutoff)) data.frame() else ranked_state$emphasis_ranked_df

      if (!identical(map_state$status, "ok") || nrow(ranked_state$ranked_df) == 0) {
        result <- list(
          mode = "comparison",
          map_state = map_state,
          ranked_df = data.frame(),
          display_df = data.frame(),
          emphasis_ranked_df = emphasis_ranked_df,
          top_n_cutoff = top_n_cutoff
        )
        if (is_psd_source) {
          log_perf(
            "map_display_dataset()",
            start_time,
            details = list(
              source = "psd",
              mode = "comparison",
              status = map_state$status %||% "unknown",
              rows = 0,
              rank_basis_source = "map_comparison_dataset"
            )
          )
        }
        return(result)
      }

      can_apply_top_n_filter <- !is.null(top_n_cutoff) && all(c("map_location", "emphasis_rank") %in% names(emphasis_ranked_df))

      display_df <- if (is.null(top_n_cutoff) || !can_apply_top_n_filter) {
        ranked_state$ranked_df
      } else {
        allowed_locations <- emphasis_ranked_df %>%
          filter(.data$emphasis_rank <= top_n_cutoff) %>%
          select(map_location) %>%
          distinct()

        ranked_state$ranked_df %>%
          semi_join(allowed_locations, by = "map_location")
      }

      if (nrow(display_df) > 0) {
        display_df <- display_df %>%
          mutate(rank = dplyr::row_number())
      }

      result <- list(
        mode = "comparison",
        map_state = map_state,
        ranked_df = ranked_state$ranked_df,
        display_df = display_df,
        emphasis_ranked_df = emphasis_ranked_df,
        top_n_cutoff = top_n_cutoff
      )
      if (is_psd_source) {
        log_perf(
          "map_display_dataset()",
          start_time,
          details = list(
            source = "psd",
            mode = "comparison",
            status = map_state$status %||% "ok",
            rows = nrow(display_df),
            rank_basis_source = "map_comparison_dataset"
          )
        )
      }
      return(result)
    }

    if (!identical(map_state$status, "ok") || nrow(ranked_state$ranked_df) == 0) {
      result <- list(
        mode = "current",
        map_state = map_state,
        ranked_df = data.frame(),
        display_df = data.frame(),
        emphasis_ranked_df = data.frame(),
        top_n_cutoff = top_n_cutoff
      )
      if (is_psd_source) {
        log_perf(
          "map_display_dataset()",
          start_time,
          details = list(source = "psd", mode = "current", status = map_state$status %||% "unknown", rows = 0)
        )
      }
      return(result)
    }

    display_df <- if (is.null(top_n_cutoff)) {
      ranked_state$ranked_df
    } else {
      ranked_state$ranked_df %>% slice_head(n = top_n_cutoff)
    }

    result <- list(
      mode = "current",
      map_state = map_state,
      ranked_df = ranked_state$ranked_df,
      display_df = display_df,
      emphasis_ranked_df = ranked_state$emphasis_ranked_df,
      top_n_cutoff = top_n_cutoff
    )

    if (is_psd_source) {
      log_perf(
        "map_display_dataset()",
        start_time,
        details = list(source = "psd", mode = "current", status = map_state$status %||% "ok", rows = nrow(display_df))
      )
    }

    result
  }) %>% bindCache(
    map_display_dataset_cache_key()$runtime_source,
    map_display_dataset_cache_key()$selected_market_year,
    map_display_dataset_cache_key()$cutoff_state,
    map_display_dataset_cache_key()$comparison_mode,
    map_display_dataset_cache_key()$measure_mode,
    map_display_dataset_cache_key()$top_n_cutoff,
    map_display_dataset_cache_key()$comparison_fragment
  )

  map_unit_resolution_rows <- function(map_display = NULL,
                                       map_state = NULL,
                                       source_choice = current_source_choice_safe(default = input$data_source_choice %||% "export_sales")) {
    if (!identical(source_choice, "vp_trade")) {
      return(data.frame())
    }

    resolved_state <- if (is.list(map_state)) map_state else map_display$map_state
    display_mode <- map_display$mode %||% map_comparison_mode()
    snapshot_base <- tryCatch(map_snapshot_base(), error = function(...) NULL)
    selected_market_year <- suppressWarnings(as.numeric(resolved_state$selected_market_year %||% map_selected_market_year()))
    has_selected_market_year <- length(selected_market_year) == 1L && is.finite(selected_market_year)

    if (is.null(snapshot_base) || !is.data.frame(snapshot_base$snapshot_df) || nrow(snapshot_base$snapshot_df) == 0 || !isTRUE(has_selected_market_year)) {
      return(data.frame())
    }

    current_rows <- snapshot_base$snapshot_df %>%
      filter(.data$market_year == selected_market_year)

    if (!identical(display_mode, "comparison")) {
      return(current_rows)
    }

    baseline_years <- suppressWarnings(as.numeric(resolved_state$baseline_years %||% numeric(0)))
    baseline_years <- sort(unique(baseline_years[is.finite(baseline_years)]))
    if (length(baseline_years) == 0L) {
      return(current_rows)
    }

    df_source <- tryCatch(map_source_data(), error = function(...) NULL)
    if (!is.data.frame(df_source) || nrow(df_source) == 0) {
      return(current_rows)
    }

    baseline_parts <- lapply(baseline_years, function(baseline_year) {
      baseline_rows <- df_source %>% filter(.data$market_year == baseline_year)
      if (nrow(baseline_rows) == 0) {
        return(NULL)
      }

      latest_available_snapshot_by_group(
        df = baseline_rows,
        group_col = "country",
        cutoff_period = snapshot_base$latest_period_index
      )
    })
    baseline_parts <- Filter(function(part) is.data.frame(part) && nrow(part) > 0, baseline_parts)

    bind_rows(c(list(current_rows), baseline_parts))
  }

  resolve_map_display_unit <- function(map_display = NULL,
                                       output_id = "map_plot",
                                       source_choice = current_source_choice_safe(default = input$data_source_choice %||% "export_sales"),
                                       metric_col = NULL,
                                       record_event = TRUE) {
    resolved_state <- if (is.list(map_display)) map_display$map_state else NULL
    metric_code <- trimws(as.character(metric_col %||% resolved_state$metric_col %||% effective_main_metric() %||% ""))
    metric_code <- metric_code[!is.na(metric_code) & nzchar(metric_code)]
    if (!identical(source_choice, "vp_trade") || length(metric_code) != 1L || !(metric_code %in% c("unit_value", "ytd_unit_value"))) {
      return(NULL)
    }

    display_mode <- map_display$mode %||% map_comparison_mode()
    unit_rows <- map_unit_resolution_rows(
      map_display = map_display,
      map_state = resolved_state,
      source_choice = source_choice
    )

    selected_market_year <- suppressWarnings(as.numeric(resolved_state$selected_market_year %||% map_selected_market_year()))
    has_selected_market_year <- length(selected_market_year) == 1L && is.finite(selected_market_year)
    baseline_years <- suppressWarnings(as.numeric(resolved_state$baseline_years %||% numeric(0)))
    baseline_years <- sort(unique(baseline_years[is.finite(baseline_years)]))
    market_scope <- paste(
      c(
        if (isTRUE(has_selected_market_year)) paste0("selected=", selected_market_year) else character(0),
        if (identical(display_mode, "comparison") && length(baseline_years) > 0L) paste0("baseline=", paste(baseline_years, collapse = ",")) else character(0)
      ),
      collapse = "|"
    )

    unit_context <- build_unit_resolution_context(
      tab_id = input$main_tabs_panel %||% current_main_tab_safe(),
      output_id = output_id,
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
      country_scope = map_selected_country() %||% "map_all_countries",
      market_scope = market_scope,
      rollup_level = input$vp_market_segment_choice %||% "",
      rollup_path = paste(
        input$vp_group_choice %||% "",
        input$vp_subgroup_choice %||% "",
        input$vp_market_segment_choice %||% "",
        sep = "|"
      ),
      run_id = paste0(output_id, "_unit_resolution")
    )

    unit_resolution <- tryCatch(
      resolve_vp_trade_display_unit(
        metric_code = metric_code,
        rows = unit_rows,
        context = unit_context
      ),
      error = function(...) NULL
    )

    if (is.list(unit_resolution) && isTRUE(record_event)) {
      unit_guardrail_record_event(
        unit_resolution = unit_resolution,
        context = unit_context
      )
    }

    unit_resolution
  }

  map_unit_guardrail_warning_text <- function(unit_resolution) {
    if (!is.list(unit_resolution)) {
      return(NULL)
    }

    status_value <- trimws(as.character(unit_resolution$status %||% ""))
    if (!(status_value %in% c("mixed_unit_anomaly", "missing_unit_anomaly"))) {
      return(NULL)
    }

    warning_text <- unit_guardrail_event_message(status_value, unit_resolution$message %||% "")
    if (nzchar(warning_text)) warning_text else NULL
  }

  map_selected_country <- reactiveVal(NULL)
  pending_psd_map_country_target <- reactiveVal(NULL)
  psd_map_choice_signature <- reactiveVal(NULL)
  psd_map_country_sync_request_seq <- reactiveVal(0L)
  pending_psd_map_country_programmatic_sync <- reactiveVal(NULL)
  psd_map_country_sync_window <- reactiveVal(NULL)
  last_psd_surface_main_tab <- reactiveVal(NULL)
  psd_time_series_country_handoff_guard <- reactiveVal(NULL)

  current_psd_time_series_country_handoff_guard <- function() {
    guard <- isolate(psd_time_series_country_handoff_guard())
    if (is.null(guard)) {
      return(NULL)
    }

    expires_at <- guard$expires_at %||% NULL
    if (!is.null(expires_at) && Sys.time() > expires_at) {
      psd_time_series_country_handoff_guard(NULL)
      return(NULL)
    }

    target_country <- as.character(guard$target_country %||% character(0))
    target_country <- target_country[!is.na(target_country) & nzchar(target_country)]
    if (length(target_country) == 0) {
      psd_time_series_country_handoff_guard(NULL)
      return(NULL)
    }

    target_country[[1]]
  }

  normalize_psd_map_sync_target <- function(selected_country) {
    selected_country <- as.character(selected_country %||% character(0))
    selected_country <- selected_country[!is.na(selected_country) & nzchar(selected_country)]

    if (length(selected_country) == 0) {
      return(NULL)
    }

    selected_country[[1]]
  }

  is_psd_map_country_sync_coalescing_issuer <- function(issuer_event) {
    issuer_event <- as.character(issuer_event %||% "")

    issuer_event %in% c(
      "map_activation_observer",
      "map_selected_country_observer",
      "map_choice_observer",
      "sidebar_country_observer",
      "map_summary_table_toggle"
    )
  }

  current_psd_map_country_sync_window_context <- function(selected_country = NULL) {
    list(
      target_country = normalize_psd_map_sync_target(selected_country),
      bottom_view = normalize_psd_map_bottom_view(
        isolate(input$psd_map_bottom_view %||% psd_map_bottom_view_state() %||% NULL),
        default = "summary"
      ),
      map_visible = isTRUE(is_raw_psd_map_tab_visible())
    )
  }

  build_psd_map_country_sync_window <- function(selected_country, issuer_event, immediate_request_id) {
    window_context <- current_psd_map_country_sync_window_context(selected_country)

    c(
      source_switch_epoch_fields(),
      list(
        target_country = window_context$target_country,
        authoritative_issuer = as.character(issuer_event %||% "other"),
        immediate_request_id = as.character(immediate_request_id %||% ""),
        bottom_view = window_context$bottom_view,
        map_visible = isTRUE(window_context$map_visible),
        deferred_request_scheduled = TRUE
      )
    )
  }

  mark_psd_map_country_sync_window_deferred_complete <- function(request_id) {
    current_window <- isolate(psd_map_country_sync_window())
    if (is.null(current_window)) {
      return(invisible(FALSE))
    }

    current_request_id <- as.character(current_window$immediate_request_id %||% "")
    request_id <- as.character(request_id %||% "")

    if (!nzchar(request_id) || !identical(current_request_id, request_id)) {
      return(invisible(FALSE))
    }

    current_window$deferred_request_scheduled <- FALSE
    psd_map_country_sync_window(current_window)
    invisible(TRUE)
  }

  clear_psd_map_country_sync_window <- function(reason = "other", request_id = NULL, target_country = NULL, bottom_view = NULL, force = FALSE) {
    current_window <- isolate(psd_map_country_sync_window())
    if (is.null(current_window)) {
      return(invisible(FALSE))
    }

    current_request_id <- as.character(current_window$immediate_request_id %||% "")
    current_target_country <- as.character(current_window$target_country %||% "")
    current_bottom_view <- as.character(current_window$bottom_view %||% "")
    request_id <- as.character(request_id %||% "")
    target_country <- as.character(target_country %||% "")
    bottom_view <- as.character(bottom_view %||% "")

    should_clear <- isTRUE(force) ||
      (nzchar(request_id) && identical(request_id, current_request_id)) ||
      (
        nzchar(target_country) &&
          nzchar(bottom_view) &&
          identical(target_country, current_target_country) &&
          identical(bottom_view, current_bottom_view)
      )

    if (!isTRUE(should_clear)) {
      return(invisible(FALSE))
    }

    reset_details <- list(
      window_target_country = if (nzchar(current_target_country)) current_target_country else NULL,
      authoritative_issuer = current_window$authoritative_issuer %||% NULL,
      authoritative_request_id = if (nzchar(current_request_id)) current_request_id else NULL,
      window_bottom_view = current_window$bottom_view %||% NULL,
      deferred_request_scheduled = isTRUE(current_window$deferred_request_scheduled),
      window_reset_reason = reason
    )

    emit_psd_map_country_trace(
      "psd_map_country_sync_window_reset",
      details = reset_details,
      reason = "map_country_sync",
      dedupe_key = "psd_map_country_sync_window_reset",
      dedupe_signature = build_transition_trace_signature(reset_details)
    )

    psd_map_country_sync_window(NULL)
    invisible(TRUE)
  }

  is_raw_psd_map_tab_visible <- function() {
      source_choice <- isolate(input$data_source_choice %||% NULL)
      active_tab <- isolate(input$main_tabs_panel %||% NULL)

      identical(source_choice, "psd") && identical(active_tab, "Map")
  }

  sidebar_country_sync_request_seq <- reactiveVal(0L)
  pending_sidebar_country_sync_request <- reactiveVal(NULL)

  build_sidebar_country_sync_message <- function(selected_country, phase, reason) {
    next_seq <- isolate(sidebar_country_sync_request_seq()) + 1L
    sidebar_country_sync_request_seq(next_seq)

    request_id <- sprintf("sidebar_country_sync_%s_%s", next_seq, phase)

    pending_sidebar_country_sync_request(c(
      source_switch_epoch_fields(),
      list(
        request_id = request_id,
        target_country = selected_country,
        reason = reason,
        phase = phase
      )
    ))

    list(
      inputId = "country_choice",
      value = selected_country,
      trace = c(
        source_switch_epoch_fields(),
        list(
        request_id = request_id,
        reason = reason,
        phase = phase,
        target_country = selected_country,
        input_id = "country_choice",
        current_selection = isolate(input$country_choice %||% NULL)
        )
      )
    )
  }

  clear_pending_sidebar_country_sync_request <- function(request_id = NULL, target_country = NULL, matched = FALSE) {
    pending_request <- isolate(pending_sidebar_country_sync_request())
    if (is.null(pending_request)) {
      return(invisible(FALSE))
    }

    pending_request_id <- as.character(pending_request$request_id %||% "")
    pending_target_country <- as.character(pending_request$target_country %||% "")
    request_id <- as.character(request_id %||% "")
    target_country <- as.character(target_country %||% "")

    should_clear <- isTRUE(matched) ||
      (nzchar(request_id) && identical(request_id, pending_request_id)) ||
      (nzchar(target_country) && identical(target_country, pending_target_country))

    if (!isTRUE(should_clear)) {
      return(invisible(FALSE))
    }

    pending_sidebar_country_sync_request(NULL)
    invisible(TRUE)
  }

  emit_psd_map_country_trace <- function(event, details = list(), reason = "map_country_reconcile", dedupe_key = NULL, dedupe_signature = NULL, force = FALSE) {
    if (!exists("psd_transition_trace", mode = "function")) {
      return(invisible(NULL))
    }

    current_selection <- isolate(map_selected_country())
    current_input <- isolate(input$psd_map_country_choice %||% NULL)
    current_view <- isolate(input$psd_map_bottom_view %||% psd_map_bottom_view_state() %||% NULL)

    psd_transition_trace(
      event = event,
      reason = reason,
      details = c(
        list(
          current_selection = current_selection,
          input_selection = current_input,
          bottom_view = current_view
        ),
        details
      ),
      dedupe_key = dedupe_key,
      dedupe_signature = dedupe_signature,
      force = force
    )
  }

  read_pending_sidebar_country_target_for_trace <- function() {
    if (!exists("pending_sidebar_country_target", mode = "function")) {
      return(NULL)
    }

    isolate(pending_sidebar_country_target())
  }

  build_psd_map_country_request_trace_fields <- function(selected_country, phase = NULL, issuer_event = "other", request_id = NULL, extra = list()) {
    selected_country <- as.character(selected_country %||% NULL)
    issuer_event <- as.character(issuer_event %||% "other")
    request_id <- as.character(request_id %||% NULL)

    c(
      source_switch_epoch_fields(),
      list(
        issuer_event = issuer_event,
        request_id = request_id,
        request_phase = phase,
        request_target_country = selected_country,
        current_map_selected_country_before = isolate(map_selected_country()),
        current_input_country_before = isolate(input$psd_map_country_choice %||% NULL),
        pending_psd_target_before = isolate(pending_psd_map_country_target()),
        pending_sidebar_target_before = read_pending_sidebar_country_target_for_trace(),
        current_bottom_view_before = isolate(input$psd_map_bottom_view %||% psd_map_bottom_view_state() %||% NULL)
      ),
      extra
    )
  }

  normalize_psd_map_bottom_view <- function(selected_view, default = NULL) {
    selected_view <- as.character(selected_view %||% character(0))
    selected_view <- selected_view[!is.na(selected_view) & nzchar(selected_view)]

    if (length(selected_view) > 0 && selected_view[[1]] %in% c("summary", "matrix")) {
      return(selected_view[[1]])
    }

    default
  }

  set_psd_map_bottom_view <- function(selected_view, update_visible_input = TRUE) {
    normalized_view <- normalize_psd_map_bottom_view(selected_view, default = NULL)
    if (is.null(normalized_view)) {
      return(invisible(FALSE))
    }

    if (!identical(isolate(psd_map_bottom_view_state()), normalized_view)) {
      psd_map_bottom_view_state(normalized_view)
    }

    if (
      isTRUE(update_visible_input) &&
      is_raw_psd_map_tab_visible() &&
      !identical(isolate(input$psd_map_bottom_view %||% NULL), normalized_view)
    ) {
      updateTabsetPanel(session, "psd_map_bottom_view", selected = normalized_view)
    }

    invisible(TRUE)
  }

  resolve_psd_map_activation_bottom_view <- function(default = "summary", force_summary = FALSE) {
    if (isTRUE(force_summary)) {
      ignored_entry_target <- if (exists("consume_psd_map_bottom_view_entry_target", mode = "function")) {
        tryCatch(consume_psd_map_bottom_view_entry_target(default = NULL), error = function(...) NULL)
      } else {
        NULL
      }
      ignored_entry_target <- normalize_psd_map_bottom_view(ignored_entry_target, default = NULL)

      return(list(
        view = "summary",
        source = if (!is.null(ignored_entry_target)) "time_series_reentry_override" else "time_series_reentry"
      ))
    }

    entry_target <- if (exists("consume_psd_map_bottom_view_entry_target", mode = "function")) {
      tryCatch(consume_psd_map_bottom_view_entry_target(default = NULL), error = function(...) NULL)
    } else {
      NULL
    }
    entry_target <- normalize_psd_map_bottom_view(entry_target, default = NULL)
    if (!is.null(entry_target)) {
      return(list(view = entry_target, source = "entry_target"))
    }

    current_view <- normalize_psd_map_bottom_view(
      isolate(input$psd_map_bottom_view %||% psd_map_bottom_view_state() %||% NULL),
      default = NULL
    )
    if (!is.null(current_view)) {
      return(list(view = current_view, source = "current_state"))
    }

    list(view = default, source = "default")
  }

  should_block_psd_map_guard_mismatch <- function(selected_country, guard_target) {
    selected_country <- as.character(selected_country %||% "")
    guard_target <- as.character(guard_target %||% "")

    nzchar(selected_country) &&
      nzchar(guard_target) &&
      !identical(selected_country, guard_target) &&
      identical(selected_country, "GRAND_TOTAL")
  }

  should_override_psd_map_guard_target <- function(selected_country, guard_target) {
    selected_country <- as.character(selected_country %||% "")
    guard_target <- as.character(guard_target %||% "")

    nzchar(selected_country) &&
      nzchar(guard_target) &&
      !identical(selected_country, guard_target) &&
      !identical(selected_country, "GRAND_TOTAL")
  }

  should_clear_pending_psd_map_target <- function(selected_country, pending_target, guard_target, clear_matching_target = FALSE) {
    selected_country <- as.character(selected_country %||% "")
    pending_target <- as.character(pending_target %||% "")
    guard_target <- as.character(guard_target %||% "")

    if (!nzchar(selected_country) || !nzchar(pending_target)) {
      return(FALSE)
    }

    if (should_override_psd_map_guard_target(selected_country, guard_target)) {
      return(TRUE)
    }

    isTRUE(clear_matching_target) && identical(selected_country, pending_target)
  }

  mark_psd_map_country_programmatic_sync <- function(payload) {
    payload <- payload %||% list()

    input_id <- as.character(payload$input_id %||% "")
    target_country <- as.character(payload$target_country %||% payload$after_value %||% payload$requested_value %||% "")
    matched_requested_value <- isTRUE(payload$matched_requested_value)

    if (!identical(input_id, "psd_map_country_choice") || !matched_requested_value || !nzchar(target_country)) {
      return(invisible(FALSE))
    }

    pending_psd_map_country_programmatic_sync(list(
      request_id = as.character(payload$request_id %||% ""),
      source_switch_epoch_id = as.character(payload$source_switch_epoch_id %||% ""),
      target_country = target_country,
      stage = as.character(payload$stage %||% ""),
      phase = as.character(payload$phase %||% "")
    ))

    invisible(TRUE)
  }

  consume_psd_map_country_programmatic_sync <- function(selected_country) {
    selected_country <- as.character(selected_country %||% "")
    if (!nzchar(selected_country)) {
      return(FALSE)
    }

    sync_payload <- isolate(pending_psd_map_country_programmatic_sync())
    sync_target <- as.character(sync_payload$target_country %||% "")
    if (!nzchar(sync_target)) {
      return(FALSE)
    }

    pending_psd_map_country_programmatic_sync(NULL)
    identical(sync_target, selected_country)
  }

  should_replay_preserved_psd_map_country <- function(preserved_selection) {
    preserved_selection <- as.character(preserved_selection %||% character(0))
    preserved_selection <- preserved_selection[!is.na(preserved_selection) & nzchar(preserved_selection)]
    if (length(preserved_selection) == 0) {
      return(FALSE)
    }

    current_selection <- as.character(isolate(map_selected_country()) %||% character(0))
    current_selection <- current_selection[!is.na(current_selection) & nzchar(current_selection)]

    pending_selection <- as.character(isolate(pending_psd_map_country_target()) %||% character(0))
    pending_selection <- pending_selection[!is.na(pending_selection) & nzchar(pending_selection)]

    current_matches <-
      length(current_selection) > 0 &&
      identical(current_selection[[1]], preserved_selection[[1]])

    pending_matches <-
      length(pending_selection) > 0 &&
      identical(pending_selection[[1]], preserved_selection[[1]])

    current_matches || pending_matches
  }

  build_psd_map_country_sync_message <- function(selected_country, phase, issuer_event = "other") {
    next_seq <- isolate(psd_map_country_sync_request_seq()) + 1L
    psd_map_country_sync_request_seq(next_seq)

    request_id <- sprintf("psd_map_sync_%s_%s", next_seq, phase)
    request_trace_details <- build_psd_map_country_request_trace_fields(
      selected_country = selected_country,
      phase = phase,
      issuer_event = issuer_event,
      request_id = request_id
    )

    emit_psd_map_country_trace(
      "build_psd_map_country_sync_message",
      details = request_trace_details,
      reason = "map_country_sync",
      dedupe_key = "build_psd_map_country_sync_message",
      dedupe_signature = build_transition_trace_signature(request_trace_details)
    )

    list(
      inputId = "psd_map_country_choice",
      value = selected_country,
      trace = c(
        source_switch_epoch_fields(),
        list(
        request_id = request_id,
        reason = "sync_psd_map_country_input",
        issuer_event = issuer_event,
        phase = phase,
        request_phase = phase,
        target_country = selected_country,
        request_target_country = selected_country,
        current_selection = isolate(map_selected_country()),
        input_selection = isolate(input$psd_map_country_choice %||% NULL),
        bottom_view = isolate(input$psd_map_bottom_view %||% psd_map_bottom_view_state() %||% NULL),
        current_map_selected_country_before = request_trace_details$current_map_selected_country_before,
        current_input_country_before = request_trace_details$current_input_country_before,
        pending_psd_target_before = request_trace_details$pending_psd_target_before,
        pending_sidebar_target_before = request_trace_details$pending_sidebar_target_before,
        current_bottom_view_before = request_trace_details$current_bottom_view_before
        )
      )
    )
  }

  current_psd_map_preferred_country <- function() {
    input_selection <- isolate(input$psd_map_country_choice %||% NULL)
    input_selection <- as.character(input_selection %||% character(0))
    input_selection <- input_selection[!is.na(input_selection) & nzchar(input_selection)]

    current_selection <- isolate(map_selected_country())
    current_selection <- as.character(current_selection %||% character(0))
    current_selection <- current_selection[!is.na(current_selection) & nzchar(current_selection)]

    pending_psd_selection <- isolate(pending_psd_map_country_target())
    pending_psd_selection <- as.character(pending_psd_selection %||% character(0))
    pending_psd_selection <- pending_psd_selection[!is.na(pending_psd_selection) & nzchar(pending_psd_selection)]

    if (length(pending_psd_selection) > 0) {
      return(pending_psd_selection[[1]])
    }

    pending_selection <- isolate(pending_sidebar_country_target())
    pending_selection <- as.character(pending_selection %||% character(0))
    pending_selection <- pending_selection[!is.na(pending_selection) & nzchar(pending_selection)]

    sidebar_selection <- isolate(input$country_choice %||% NULL)
    sidebar_selection <- as.character(sidebar_selection %||% character(0))
    sidebar_selection <- sidebar_selection[!is.na(sidebar_selection) & nzchar(sidebar_selection)]

    notes_jump_anchor <- if (exists("psd_notes_jump_anchor_country", mode = "function")) {
      isolate(psd_notes_jump_anchor_country())
    } else {
      NULL
    }
    notes_jump_anchor <- as.character(notes_jump_anchor %||% character(0))
    notes_jump_anchor <- notes_jump_anchor[!is.na(notes_jump_anchor) & nzchar(notes_jump_anchor)]
    notes_panel_open <- if (exists("notes_panel_visible", mode = "function")) {
      isTRUE(isolate(notes_panel_visible()))
    } else {
      FALSE
    }

    if (
      length(current_selection) > 0 &&
      length(pending_selection) > 0 &&
      identical(current_selection[[1]], pending_selection[[1]]) &&
      (length(input_selection) == 0 || !identical(input_selection[[1]], current_selection[[1]]))
    ) {
      return(current_selection[[1]])
    }

    if (
      length(current_selection) > 0 &&
      length(sidebar_selection) > 0 &&
      identical(current_selection[[1]], sidebar_selection[[1]]) &&
      (length(input_selection) == 0 || !identical(input_selection[[1]], current_selection[[1]]))
    ) {
      return(current_selection[[1]])
    }

    if (
      isTRUE(notes_panel_open) &&
      length(notes_jump_anchor) > 0 &&
      length(sidebar_selection) > 0 &&
      identical(notes_jump_anchor[[1]], sidebar_selection[[1]]) &&
      (length(input_selection) == 0 || !identical(input_selection[[1]], notes_jump_anchor[[1]]))
    ) {
      return(notes_jump_anchor[[1]])
    }

    if (
      !is_raw_psd_map_tab_visible() &&
      length(current_selection) > 0 &&
      (length(input_selection) == 0 || !identical(input_selection[[1]], current_selection[[1]]))
    ) {
      return(current_selection[[1]])
    }

    if (length(input_selection) > 0) {
      return(input_selection[[1]])
    }

    if (length(current_selection) > 0) {
      return(current_selection[[1]])
    }

    canonical_selection <- if (exists("read_canonical_psd_country", mode = "function")) {
      isolate(read_canonical_psd_country())
    } else {
      NULL
    }
    canonical_selection <- as.character(canonical_selection %||% character(0))
    canonical_selection <- canonical_selection[!is.na(canonical_selection) & nzchar(canonical_selection)]
    if (length(canonical_selection) > 0) {
      return(canonical_selection[[1]])
    }

    NULL
  }

  sync_psd_map_country_input <- function(selected_country, issuer_event = "other") {
    if (is.null(selected_country) || !nzchar(selected_country)) {
      return(invisible(NULL))
    }

    coalesce_request <-
      isTRUE(is_raw_psd_map_tab_visible()) &&
      isTRUE(is_psd_map_country_sync_coalescing_issuer(issuer_event))
    window_context <- current_psd_map_country_sync_window_context(selected_country)

    if (isTRUE(coalesce_request)) {
      active_window <- isolate(psd_map_country_sync_window())

      if (!is.null(active_window)) {
        active_request_id <- as.character(active_window$immediate_request_id %||% "")
        active_target_country <- as.character(active_window$target_country %||% "")
        active_bottom_view <- as.character(active_window$bottom_view %||% "")

        if (!isTRUE(active_window$map_visible) || !isTRUE(window_context$map_visible)) {
          clear_psd_map_country_sync_window(reason = "map_hidden", force = TRUE)
          active_window <- NULL
        } else if (!identical(active_target_country, window_context$target_country)) {
          clear_psd_map_country_sync_window(reason = "target_replaced", force = TRUE)
          active_window <- NULL
        } else if (!identical(active_bottom_view, as.character(window_context$bottom_view %||% ""))) {
          clear_psd_map_country_sync_window(reason = "bottom_view_changed", force = TRUE)
          active_window <- NULL
        }

        if (!is.null(active_window)) {
          suppressed_trace_details <- build_psd_map_country_request_trace_fields(
            selected_country = selected_country,
            phase = "immediate",
            issuer_event = issuer_event,
            request_id = NULL,
            extra = list(
              branch = "duplicate_suppressed_same_window",
              authoritative_issuer = active_window$authoritative_issuer %||% NULL,
              authoritative_request_id = if (nzchar(active_request_id)) active_request_id else NULL,
              duplicate_suppressed = TRUE,
              deferred_request_scheduled = isTRUE(active_window$deferred_request_scheduled),
              coalescing_bottom_view = active_window$bottom_view %||% NULL
            )
          )

          emit_psd_map_country_trace(
            "sync_psd_map_country_input_request",
            details = suppressed_trace_details,
            reason = "map_country_sync",
            dedupe_key = "sync_psd_map_country_input_request",
            dedupe_signature = build_transition_trace_signature(suppressed_trace_details)
          )

          return(invisible(NULL))
        }
      }
    }

    immediate_message <- build_psd_map_country_sync_message(
      selected_country,
      phase = "immediate",
      issuer_event = issuer_event
    )

    if (isTRUE(coalesce_request)) {
      psd_map_country_sync_window(
        build_psd_map_country_sync_window(
          selected_country = selected_country,
          issuer_event = issuer_event,
          immediate_request_id = immediate_message$trace$request_id
        )
      )
    }

    immediate_trace_details <- build_psd_map_country_request_trace_fields(
      selected_country = selected_country,
      phase = "immediate",
      issuer_event = issuer_event,
      request_id = immediate_message$trace$request_id,
      extra = list(
        branch = if (isTRUE(coalesce_request)) "immediate_update_request_authoritative" else "immediate_update_request",
        authoritative_issuer = if (isTRUE(coalesce_request)) issuer_event else NULL,
        authoritative_request_id = if (isTRUE(coalesce_request)) immediate_message$trace$request_id else NULL,
        duplicate_suppressed = FALSE,
        coalescing_bottom_view = if (isTRUE(coalesce_request)) window_context$bottom_view else NULL
      )
    )

    emit_psd_map_country_trace(
      "sync_psd_map_country_input_request",
      details = immediate_trace_details,
      reason = "map_country_sync",
      dedupe_key = "sync_psd_map_country_input_request",
      dedupe_signature = build_transition_trace_signature(immediate_trace_details)
    )

    updateSelectizeInput(session, "psd_map_country_choice", selected = selected_country)
    session$sendCustomMessage("setSelectizeOrShinyInputValue", immediate_message)

    session$onFlushed(function() {
      deferred_trace_base <- build_psd_map_country_request_trace_fields(
        selected_country = selected_country,
        issuer_event = issuer_event,
        extra = list(
          authoritative_issuer = if (isTRUE(coalesce_request)) issuer_event else NULL,
          authoritative_request_id = if (isTRUE(coalesce_request)) immediate_message$trace$request_id else NULL,
          duplicate_suppressed = FALSE,
          coalescing_bottom_view = if (isTRUE(coalesce_request)) window_context$bottom_view else NULL
        )
      )

      if (isTRUE(coalesce_request)) {
        active_window <- isolate(psd_map_country_sync_window())
        active_request_id <- as.character(active_window$immediate_request_id %||% "")

        if (is.null(active_window)) {
          skip_trace_details <- c(
            deferred_trace_base,
            list(branch = "skip_window_cleared")
          )

          emit_psd_map_country_trace(
            "sync_psd_map_country_input_deferred",
            details = skip_trace_details,
            reason = "map_country_sync",
            dedupe_key = "sync_psd_map_country_input_deferred",
            dedupe_signature = build_transition_trace_signature(skip_trace_details)
          )
          return()
        }

        if (!identical(active_request_id, immediate_message$trace$request_id)) {
          skip_trace_details <- c(
            deferred_trace_base,
            list(
              branch = "skip_window_replaced",
              active_authoritative_issuer = active_window$authoritative_issuer %||% NULL,
              active_authoritative_request_id = if (nzchar(active_request_id)) active_request_id else NULL
            )
          )

          emit_psd_map_country_trace(
            "sync_psd_map_country_input_deferred",
            details = skip_trace_details,
            reason = "map_country_sync",
            dedupe_key = "sync_psd_map_country_input_deferred",
            dedupe_signature = build_transition_trace_signature(skip_trace_details)
          )
          return()
        }
      }

      if (!is_raw_psd_map_tab_visible()) {
        skip_trace_details <- c(
          deferred_trace_base,
          list(branch = "skip_invisible")
        )

        emit_psd_map_country_trace(
          "sync_psd_map_country_input_deferred",
          details = skip_trace_details,
          reason = "map_country_sync",
          dedupe_key = "sync_psd_map_country_input_deferred",
          dedupe_signature = build_transition_trace_signature(skip_trace_details)
        )

        if (isTRUE(coalesce_request)) {
          clear_psd_map_country_sync_window(
            reason = "map_hidden",
            request_id = immediate_message$trace$request_id
          )
        }
        return()
      }

      current_input <- isolate(input$psd_map_country_choice %||% NULL)
      mark_psd_map_country_sync_window_deferred_complete(immediate_message$trace$request_id)

      if (!identical(current_input, selected_country)) {
        deferred_message <- build_psd_map_country_sync_message(
          selected_country,
          phase = "deferred_replay_update",
          issuer_event = issuer_event
        )
        updateSelectizeInput(session, "psd_map_country_choice", selected = selected_country)
        session$sendCustomMessage("setSelectizeOrShinyInputValue", deferred_message)
        branch <- "deferred_replay_update"
      } else {
        deferred_message <- build_psd_map_country_sync_message(
          selected_country,
          phase = "deferred_replay_noop",
          issuer_event = issuer_event
        )
        session$sendCustomMessage("setSelectizeOrShinyInputValue", deferred_message)
        branch <- "deferred_replay_noop"
      }

      deferred_trace_details <- build_psd_map_country_request_trace_fields(
        selected_country = selected_country,
        phase = deferred_message$trace$request_phase %||% deferred_message$trace$phase,
        issuer_event = issuer_event,
        request_id = deferred_message$trace$request_id,
        extra = list(
          current_input = current_input,
          branch = branch,
          authoritative_issuer = if (isTRUE(coalesce_request)) issuer_event else NULL,
          authoritative_request_id = if (isTRUE(coalesce_request)) immediate_message$trace$request_id else NULL,
          duplicate_suppressed = FALSE,
          coalescing_bottom_view = if (isTRUE(coalesce_request)) window_context$bottom_view else NULL
        )
      )

      emit_psd_map_country_trace(
        "sync_psd_map_country_input_deferred",
        details = deferred_trace_details,
        reason = "map_country_sync",
        dedupe_key = "sync_psd_map_country_input_deferred",
        dedupe_signature = build_transition_trace_signature(deferred_trace_details)
      )

      if (isTRUE(coalesce_request) && identical(current_input, selected_country)) {
        clear_psd_map_country_sync_window(
          reason = "deferred_input_aligned",
          request_id = immediate_message$trace$request_id
        )
      }
    }, once = TRUE)

    if (exists("request_psd_map_country_probe", mode = "function")) {
      request_psd_map_country_probe("sync_psd_map_country_input", delay_ms = 180L)
    }

    invisible(NULL)
  }

  resolve_psd_map_country_selection <- function(valid_choices, preferred_choice = NULL) {
    valid_choices <- as.character(valid_choices %||% character(0))
    valid_choices <- valid_choices[!is.na(valid_choices) & nzchar(valid_choices)]

    if (length(valid_choices) == 0) {
      emit_psd_map_country_trace(
        "resolve_psd_map_country_selection",
        details = list(
          valid_choice_count = 0,
          preferred_choice = preferred_choice,
          selected_country = NULL,
          branch = "no_valid_choices"
        ),
        reason = "map_country_resolution",
        dedupe_key = "resolve_psd_map_country_selection",
        dedupe_signature = build_transition_trace_signature(list(
          valid_choice_count = 0,
          preferred_choice = preferred_choice,
          selected_country = NULL,
          branch = "no_valid_choices"
        ))
      )
      return(NULL)
    }

    preferred_choice <- as.character(preferred_choice %||% character(0))
    preferred_choice <- preferred_choice[!is.na(preferred_choice) & nzchar(preferred_choice)]
    if (length(preferred_choice) > 0 && preferred_choice[[1]] %in% valid_choices) {
      selected_country <- preferred_choice[[1]]
      branch <- "preferred_choice"
    } else if ("GRAND_TOTAL" %in% valid_choices) {
      selected_country <- "GRAND_TOTAL"
      branch <- "grand_total_fallback"
    } else {
      selected_country <- valid_choices[[1]]
      branch <- "first_available"
    }

    emit_psd_map_country_trace(
      "resolve_psd_map_country_selection",
      details = list(
        valid_choice_count = length(valid_choices),
        preferred_choice = if (length(preferred_choice) > 0) preferred_choice[[1]] else NULL,
        selected_country = selected_country,
        grand_total_available = "GRAND_TOTAL" %in% valid_choices,
        first_available = valid_choices[[1]],
        branch = branch
      ),
      reason = "map_country_resolution",
      dedupe_key = "resolve_psd_map_country_selection",
      dedupe_signature = build_transition_trace_signature(list(
        valid_choice_count = length(valid_choices),
        preferred_choice = if (length(preferred_choice) > 0) preferred_choice[[1]] else NULL,
        selected_country = selected_country,
        grand_total_available = "GRAND_TOTAL" %in% valid_choices,
        first_available = valid_choices[[1]],
        branch = branch
      ))
    )

    selected_country
  }

  sync_sidebar_country_from_psd <- function(selected_country, reason = "psd_map_country") {
    selected_country <- as.character(selected_country %||% "")
    if (!nzchar(selected_country)) {
      return(invisible(FALSE))
    }

    pending_target <- as.character(isolate(pending_psd_map_country_target()) %||% "")
    notes_jump_anchor <- if (exists("psd_notes_jump_anchor_country", mode = "function")) {
      isolate(psd_notes_jump_anchor_country())
    } else {
      NULL
    }
    notes_jump_anchor <- as.character(notes_jump_anchor %||% "")
    notes_panel_open <- if (exists("notes_panel_visible", mode = "function")) {
      isTRUE(isolate(notes_panel_visible()))
    } else {
      FALSE
    }
    sidebar_selection <- as.character(isolate(input$country_choice %||% "") %||% "")
    pending_sidebar_target <- if (exists("pending_sidebar_country_target", mode = "function")) {
      as.character(isolate(pending_sidebar_country_target()) %||% "")
    } else {
      ""
    }
    current_map_selection <- as.character(isolate(map_selected_country()) %||% "")
    guard_target <- if (nzchar(pending_target)) {
      pending_target
    } else if (
      nzchar(pending_sidebar_target) &&
      identical(current_map_selection, pending_sidebar_target) &&
      !identical(sidebar_selection, pending_sidebar_target)
    ) {
      pending_sidebar_target
    } else if (isTRUE(notes_panel_open) && nzchar(notes_jump_anchor) && identical(notes_jump_anchor, sidebar_selection)) {
      notes_jump_anchor
    } else {
      ""
    }

    block_guard_mismatch <- should_block_psd_map_guard_mismatch(selected_country, guard_target)
    override_guard_target <- should_override_psd_map_guard_target(selected_country, guard_target)

    if (block_guard_mismatch) {
      pending_sidebar_before <- isolate(pending_sidebar_country_target())

      psd_transition_trace(
        event = "sync_sidebar_country_from_psd",
        reason = reason,
        details = list(
          selected_country_from_psd = selected_country,
          selected_country = selected_country,
          current_sidebar_country = sidebar_selection,
          visible_sidebar_input_before = sidebar_selection,
          pending_sidebar_before = pending_sidebar_before,
          pending_sidebar_after = pending_sidebar_before,
          pending_sidebar_country_before = isolate(pending_sidebar_country_target()),
          pending_sidebar_country_after = isolate(pending_sidebar_country_target()),
          pending_psd_target_before = if (nzchar(pending_target)) pending_target else NULL,
          pending_target = if (nzchar(pending_target)) pending_target else NULL,
          notes_jump_anchor = if (nzchar(notes_jump_anchor)) notes_jump_anchor else NULL,
          notes_panel_open = notes_panel_open,
          guard_target_before = if (nzchar(guard_target)) guard_target else NULL,
          guard_target = guard_target,
          can_update_sidebar_input = FALSE,
          visible_input_update_attempted = FALSE,
          shared_state_write_only = FALSE,
          branch = "ignore_pending_grand_total_mismatch"
        ),
        dedupe_key = "sync_sidebar_country_from_psd",
        dedupe_signature = build_transition_trace_signature(list(
          selected_country_from_psd = selected_country,
          selected_country = selected_country,
          current_sidebar_country = sidebar_selection,
          visible_sidebar_input_before = sidebar_selection,
          pending_sidebar_before = pending_sidebar_before,
          pending_sidebar_after = pending_sidebar_before,
          pending_sidebar_country_before = isolate(pending_sidebar_country_target()),
          pending_sidebar_country_after = isolate(pending_sidebar_country_target()),
          pending_psd_target_before = if (nzchar(pending_target)) pending_target else NULL,
          pending_target = if (nzchar(pending_target)) pending_target else NULL,
          notes_jump_anchor = if (nzchar(notes_jump_anchor)) notes_jump_anchor else NULL,
          notes_panel_open = notes_panel_open,
          guard_target_before = if (nzchar(guard_target)) guard_target else NULL,
          guard_target = guard_target,
          can_update_sidebar_input = FALSE,
          visible_input_update_attempted = FALSE,
          shared_state_write_only = FALSE,
          branch = "ignore_pending_grand_total_mismatch"
        ))
      )
      return(invisible(FALSE))
    }

    current_sidebar_country <- isolate(input$country_choice %||% NULL)
    pending_sidebar_country <- isolate(pending_sidebar_country_target())
    pending_sidebar_sync_request <- isolate(pending_sidebar_country_sync_request())
    pending_sidebar_sync_target <- as.character(pending_sidebar_sync_request$target_country %||% "")
    pending_sidebar_sync_request_id <- as.character(pending_sidebar_sync_request$request_id %||% "")
    pending_sidebar_before <- pending_sidebar_country

    sidebar_country_scalar <- function(value) {
      value <- as.character(value %||% character(0))
      value <- value[!is.na(value) & nzchar(value)]
      if (length(value) == 0) return("")
      value[[1]]
    }

    current_sidebar_country_value <- sidebar_country_scalar(current_sidebar_country)
    pending_sidebar_country_value <- sidebar_country_scalar(pending_sidebar_country)
    pending_sync_target_matches <- nzchar(pending_sidebar_sync_target) && identical(pending_sidebar_sync_target, selected_country)

    if (
      !isTRUE(override_guard_target) &&
        identical(current_sidebar_country_value, selected_country) &&
        identical(pending_sidebar_country_value, selected_country) &&
        (!nzchar(pending_sidebar_sync_target) || isTRUE(pending_sync_target_matches))
    ) {
      if (isTRUE(pending_sync_target_matches)) {
        clear_pending_sidebar_country_sync_request(
          target_country = selected_country,
          matched = TRUE
        )
        pending_sidebar_sync_request <- isolate(pending_sidebar_country_sync_request())
        pending_sidebar_sync_target <- as.character(pending_sidebar_sync_request$target_country %||% "")
        pending_sidebar_sync_request_id <- as.character(pending_sidebar_sync_request$request_id %||% "")
      }

      psd_transition_trace(
        event = "sync_sidebar_country_from_psd",
        reason = reason,
        details = list(
          selected_country_from_psd = selected_country,
          selected_country = selected_country,
          current_sidebar_country = current_sidebar_country,
          visible_sidebar_input_before = current_sidebar_country,
          pending_sidebar_before = pending_sidebar_before,
          pending_sidebar_after = pending_sidebar_country,
          pending_sidebar_country_before = pending_sidebar_country,
          pending_sidebar_country_after = pending_sidebar_country,
          pending_psd_target_before = if (nzchar(pending_target)) pending_target else NULL,
          pending_target = if (nzchar(pending_target)) pending_target else NULL,
          notes_jump_anchor = if (nzchar(notes_jump_anchor)) notes_jump_anchor else NULL,
          notes_panel_open = notes_panel_open,
          guard_target_before = if (nzchar(guard_target)) guard_target else NULL,
          guard_target = if (nzchar(guard_target)) guard_target else NULL,
          override_guard_target = override_guard_target,
          pending_target_cleared = FALSE,
          can_update_sidebar_input = TRUE,
          visible_input_update_attempted = FALSE,
          shared_state_write_only = FALSE,
          pending_sidebar_sync_request_id = if (nzchar(pending_sidebar_sync_request_id)) pending_sidebar_sync_request_id else NULL,
          pending_sidebar_sync_target = if (nzchar(pending_sidebar_sync_target)) pending_sidebar_sync_target else NULL,
          branch = "noop_sidebar_already_selected"
        ),
        dedupe_key = "sync_sidebar_country_from_psd",
        dedupe_signature = build_transition_trace_signature(list(
          selected_country_from_psd = selected_country,
          selected_country = selected_country,
          current_sidebar_country = current_sidebar_country,
          visible_sidebar_input_before = current_sidebar_country,
          pending_sidebar_before = pending_sidebar_before,
          pending_sidebar_after = pending_sidebar_country,
          pending_sidebar_country_before = pending_sidebar_country,
          pending_sidebar_country_after = pending_sidebar_country,
          pending_psd_target_before = if (nzchar(pending_target)) pending_target else NULL,
          pending_target = if (nzchar(pending_target)) pending_target else NULL,
          notes_jump_anchor = if (nzchar(notes_jump_anchor)) notes_jump_anchor else NULL,
          notes_panel_open = notes_panel_open,
          guard_target_before = if (nzchar(guard_target)) guard_target else NULL,
          guard_target = if (nzchar(guard_target)) guard_target else NULL,
          override_guard_target = override_guard_target,
          pending_target_cleared = FALSE,
          can_update_sidebar_input = TRUE,
          visible_input_update_attempted = FALSE,
          shared_state_write_only = FALSE,
          pending_sidebar_sync_request_id = if (nzchar(pending_sidebar_sync_request_id)) pending_sidebar_sync_request_id else NULL,
          pending_sidebar_sync_target = if (nzchar(pending_sidebar_sync_target)) pending_sidebar_sync_target else NULL,
          branch = "noop_sidebar_already_selected"
        ))
      )
      return(invisible(TRUE))
    }

    valid_sidebar_choices <- tryCatch(unname(country_choice_options()), error = function(e) NULL)
    valid_sidebar_choices <- as.character(valid_sidebar_choices %||% character(0))
    valid_sidebar_choices <- valid_sidebar_choices[!is.na(valid_sidebar_choices) & nzchar(valid_sidebar_choices)]

    can_update_sidebar_input <- length(valid_sidebar_choices) > 0 && selected_country %in% valid_sidebar_choices

    if (isTRUE(override_guard_target) && nzchar(pending_target)) {
      pending_psd_map_country_target(NULL)
    }

    pending_sidebar_country_target(selected_country)

    if (can_update_sidebar_input && identical(current_sidebar_country, selected_country)) {
      clear_pending_sidebar_country_sync_request(
        target_country = selected_country,
        matched = TRUE
      )
      pending_sidebar_sync_request <- isolate(pending_sidebar_country_sync_request())
      pending_sidebar_sync_target <- as.character(pending_sidebar_sync_request$target_country %||% "")
      pending_sidebar_sync_request_id <- as.character(pending_sidebar_sync_request$request_id %||% "")
    }

    if (
      can_update_sidebar_input &&
      !identical(current_sidebar_country, selected_country) &&
      nzchar(pending_sidebar_sync_target) &&
      identical(pending_sidebar_sync_target, selected_country)
    ) {
      branch <- "await_pending_sidebar_sync"
    } else if (can_update_sidebar_input && !identical(current_sidebar_country, selected_country)) {
      updateSelectizeInput(session, "country_choice", selected = selected_country)
      session$sendCustomMessage(
        "setSelectizeOrShinyInputValue",
        build_sidebar_country_sync_message(selected_country, "immediate", reason)
      )
      if (exists("request_sidebar_country_probe", mode = "function")) {
        request_sidebar_country_probe(paste0(reason, "_post_sync"), delay_ms = 180L)
      }
      branch <- "update_sidebar_input"
    } else if (can_update_sidebar_input) {
      if (exists("request_sidebar_country_probe", mode = "function")) {
        request_sidebar_country_probe(paste0(reason, "_already_selected"), delay_ms = 120L)
      }
      branch <- "keep_sidebar_input"
    } else {
      branch <- "pending_only"
    }

    pending_sidebar_after <- pending_sidebar_country_target()
    visible_input_update_attempted <- identical(branch, "update_sidebar_input")
    shared_state_write_only <-
      !isTRUE(visible_input_update_attempted) &&
      !identical(pending_sidebar_before, pending_sidebar_after)

    psd_transition_trace(
      event = "sync_sidebar_country_from_psd",
      reason = reason,
      details = list(
        selected_country_from_psd = selected_country,
        selected_country = selected_country,
        current_sidebar_country = current_sidebar_country,
        visible_sidebar_input_before = current_sidebar_country,
        pending_sidebar_before = pending_sidebar_before,
        pending_sidebar_after = pending_sidebar_after,
        pending_sidebar_country_before = pending_sidebar_country,
        pending_sidebar_country_after = pending_sidebar_country_target(),
        pending_psd_target_before = if (nzchar(pending_target)) pending_target else NULL,
        pending_target = if (nzchar(pending_target)) pending_target else NULL,
        notes_jump_anchor = if (nzchar(notes_jump_anchor)) notes_jump_anchor else NULL,
        notes_panel_open = notes_panel_open,
        guard_target_before = if (nzchar(guard_target)) guard_target else NULL,
        guard_target = if (nzchar(guard_target)) guard_target else NULL,
        override_guard_target = override_guard_target,
        pending_target_cleared = isTRUE(override_guard_target) && nzchar(pending_target),
        can_update_sidebar_input = can_update_sidebar_input,
        visible_input_update_attempted = visible_input_update_attempted,
        shared_state_write_only = shared_state_write_only,
        pending_sidebar_sync_request_id = if (nzchar(pending_sidebar_sync_request_id)) pending_sidebar_sync_request_id else NULL,
        pending_sidebar_sync_target = if (nzchar(pending_sidebar_sync_target)) pending_sidebar_sync_target else NULL,
        branch = branch
      ),
      dedupe_key = "sync_sidebar_country_from_psd",
      dedupe_signature = build_transition_trace_signature(list(
        selected_country_from_psd = selected_country,
        selected_country = selected_country,
        current_sidebar_country = current_sidebar_country,
        visible_sidebar_input_before = current_sidebar_country,
        pending_sidebar_before = pending_sidebar_before,
        pending_sidebar_after = pending_sidebar_after,
        pending_sidebar_country_before = pending_sidebar_country,
        pending_sidebar_country_after = pending_sidebar_country_target(),
        pending_psd_target_before = if (nzchar(pending_target)) pending_target else NULL,
        pending_target = if (nzchar(pending_target)) pending_target else NULL,
        notes_jump_anchor = if (nzchar(notes_jump_anchor)) notes_jump_anchor else NULL,
        notes_panel_open = notes_panel_open,
        guard_target_before = if (nzchar(guard_target)) guard_target else NULL,
        guard_target = if (nzchar(guard_target)) guard_target else NULL,
        override_guard_target = override_guard_target,
        pending_target_cleared = isTRUE(override_guard_target) && nzchar(pending_target),
        can_update_sidebar_input = can_update_sidebar_input,
        visible_input_update_attempted = visible_input_update_attempted,
        shared_state_write_only = shared_state_write_only,
        pending_sidebar_sync_request_id = if (nzchar(pending_sidebar_sync_request_id)) pending_sidebar_sync_request_id else NULL,
        pending_sidebar_sync_target = if (nzchar(pending_sidebar_sync_target)) pending_sidebar_sync_target else NULL,
        branch = branch
      ))
    )

    invisible(TRUE)
  }

  current_psd_active_country <- function() {
    current_tab <- isolate(tryCatch(current_main_tab_safe(), error = function(e) NULL) %||% NULL)
    raw_main_tab <- isolate(input$main_tabs_panel %||% NULL)
    raw_time_series_tab <- identical(raw_main_tab, "Time Series Analysis Tool")

    active_psd_country_choices <- tryCatch(isolate(country_choice_options()), error = function(e) NULL)
    active_psd_base_choices <- tryCatch(isolate(country_display_names_for_frequency()), error = function(e) NULL)
    if (is.null(active_psd_base_choices) || length(active_psd_base_choices) == 0) {
      active_psd_base_choices <- country_display_names
    }
    normalization_available <- !is.null(active_psd_country_choices) && length(active_psd_country_choices) > 0

    normalize_active_country_values <- function(values) {
      values <- as.character(values %||% character(0))
      values <- values[!is.na(values) & nzchar(values)]
      if (length(values) == 0) {
        return(character(0))
      }

      if (!isTRUE(normalization_available) || !exists("resolve_psd_country_code", mode = "function")) {
        return(values)
      }

      resolved_values <- vapply(values, function(value) {
        resolved_value <- resolve_psd_country_code(value, active_psd_country_choices, base_choices = active_psd_base_choices, default = NA_character_)
        as.character(resolved_value %||% NA_character_)
      }, character(1))
      resolved_values <- resolved_values[!is.na(resolved_values) & nzchar(resolved_values)]

      if (length(resolved_values) > 0) {
        return(unique(resolved_values))
      }

      character(0)
    }

    sidebar_country <- as.character(isolate(input$country_choice %||% character(0)))
    sidebar_country <- sidebar_country[!is.na(sidebar_country) & nzchar(sidebar_country)]
    sidebar_country <- normalize_active_country_values(sidebar_country)

    map_input_country <- as.character(isolate(input$psd_map_country_choice %||% character(0)))
    map_input_country <- map_input_country[!is.na(map_input_country) & nzchar(map_input_country)]
    map_input_country <- normalize_active_country_values(map_input_country)

    map_country <- as.character(isolate(map_selected_country()) %||% character(0))
    map_country <- map_country[!is.na(map_country) & nzchar(map_country)]
    map_country <- normalize_active_country_values(map_country)

    pending_sidebar_country <- as.character(isolate(pending_sidebar_country_target()) %||% character(0))
    pending_sidebar_country <- pending_sidebar_country[!is.na(pending_sidebar_country) & nzchar(pending_sidebar_country)]
    pending_sidebar_country <- normalize_active_country_values(pending_sidebar_country)

    transition_state <- tryCatch(current_psd_source_transition_state(), error = function(e) NULL)
    transition_country <- as.character(transition_state$country %||% character(0))
    transition_country <- transition_country[!is.na(transition_country) & nzchar(transition_country)]
    transition_country <- normalize_active_country_values(transition_country)

    canonical_country <- if (exists("read_canonical_psd_country", mode = "function")) {
      isolate(read_canonical_psd_country())
    } else {
      NULL
    }
    canonical_country <- as.character(canonical_country %||% character(0))
    canonical_country <- canonical_country[!is.na(canonical_country) & nzchar(canonical_country)]
    canonical_country <- normalize_active_country_values(canonical_country)

    guarded_mount_country <- NULL
    if (length(pending_sidebar_country) > 0 && !identical(pending_sidebar_country[[1]], "GRAND_TOTAL")) {
      guarded_mount_country <- pending_sidebar_country[[1]]
    } else if (length(transition_country) > 0 && !identical(transition_country[[1]], "GRAND_TOTAL")) {
      guarded_mount_country <- transition_country[[1]]
    }

    time_series_mount_guard_active <-
      isTRUE(raw_time_series_tab) &&
      length(sidebar_country) > 0 &&
      identical(sidebar_country[[1]], "GRAND_TOTAL") &&
      !is.null(guarded_mount_country) &&
      nzchar(guarded_mount_country)

    if (identical(current_tab, "Map") && !isTRUE(raw_time_series_tab)) {
      candidate_values <- c(
        map_input_country,
        map_country,
        sidebar_country
      )
    } else if (isTRUE(time_series_mount_guard_active)) {
      candidate_values <- c(
        guarded_mount_country,
        transition_country,
        canonical_country,
        sidebar_country,
        map_input_country,
        map_country
      )
    } else {
      candidate_values <- c(
        sidebar_country,
        map_input_country,
        map_country,
        pending_sidebar_country,
        transition_country,
        canonical_country
      )
    }

    candidate_values <- candidate_values[!is.na(candidate_values) & nzchar(candidate_values)]
    if (length(candidate_values) > 0) {
      return(candidate_values[[1]])
    }

    "GRAND_TOTAL"
  }

  observeEvent(input$psd_map_bottom_view, {
    if (!is.null(input$psd_map_bottom_view) && input$psd_map_bottom_view %in% c("summary", "matrix")) {
      selected_view <- input$psd_map_bottom_view
      notes_jump_anchor <- if (exists("psd_notes_jump_anchor_country", mode = "function")) {
        isolate(psd_notes_jump_anchor_country())
      } else {
        NULL
      }
      notes_jump_anchor <- as.character(notes_jump_anchor %||% character(0))
      notes_jump_anchor <- notes_jump_anchor[!is.na(notes_jump_anchor) & nzchar(notes_jump_anchor)]
      notes_panel_open <- if (exists("notes_panel_visible", mode = "function")) {
        isTRUE(isolate(notes_panel_visible()))
      } else {
        FALSE
      }
      sidebar_selection <- isolate(input$country_choice %||% NULL)
      sidebar_selection <- as.character(sidebar_selection %||% character(0))
      sidebar_selection <- sidebar_selection[!is.na(sidebar_selection) & nzchar(sidebar_selection)]

      current_selection <- isolate(map_selected_country())
      current_selection <- as.character(current_selection %||% character(0))
      current_selection <- current_selection[!is.na(current_selection) & nzchar(current_selection)]
      preserve_source <- NULL
      preserved_selection <- if (
        isTRUE(notes_panel_open) &&
        length(notes_jump_anchor) > 0 &&
        length(sidebar_selection) > 0 &&
        identical(notes_jump_anchor[[1]], sidebar_selection[[1]])
      ) {
        preserve_source <- "notes_jump_anchor"
        notes_jump_anchor[[1]]
      } else if (length(current_selection) > 0) {
        preserve_source <- "current_selection"
        current_selection[[1]]
      } else {
        NULL
      }

      if (!is.null(preserved_selection)) {
        preserve_before_details <- list(
          selected_view = selected_view,
          preserved_selection = preserved_selection,
          preserve_source = preserve_source,
          current_map_selected_country_before = isolate(map_selected_country()),
          current_input_country_before = isolate(input$psd_map_country_choice %||% NULL),
          pending_psd_target_before = isolate(pending_psd_map_country_target()),
          pending_sidebar_target_before = read_pending_sidebar_country_target_for_trace(),
          is_map_tab_visible = is_raw_psd_map_tab_visible(),
          should_replay_preserved_country = should_replay_preserved_psd_map_country(preserved_selection)
        )

        emit_psd_map_country_trace(
          "map_bottom_view_preserve_pending_target_before",
          details = preserve_before_details,
          reason = "map_country_reconcile",
          dedupe_key = "map_bottom_view_preserve_pending_target_before",
          dedupe_signature = build_transition_trace_signature(preserve_before_details)
        )

        pending_psd_map_country_target(preserved_selection)

        preserve_after_details <- c(
          preserve_before_details,
          list(pending_psd_target_after = isolate(pending_psd_map_country_target()))
        )

        emit_psd_map_country_trace(
          "map_bottom_view_preserve_pending_target_after",
          details = preserve_after_details,
          reason = "map_country_reconcile",
          dedupe_key = "map_bottom_view_preserve_pending_target_after",
          dedupe_signature = build_transition_trace_signature(preserve_after_details)
        )

        session$onFlushed(function() {
          if (!should_replay_preserved_psd_map_country(preserved_selection)) {
            return()
          }

          current_input_after <- isolate(input$psd_map_country_choice %||% NULL)
          if (!identical(current_input_after, preserved_selection)) {
            replay_trace_details <- build_psd_map_country_request_trace_fields(
              selected_country = preserved_selection,
              issuer_event = "map_bottom_view_preserve_replay",
              extra = list(
                selected_view = selected_view,
                preserve_source = preserve_source,
                current_input_replay = current_input_after,
                branch = "on_flushed_replay"
              )
            )

            emit_psd_map_country_trace(
              "map_bottom_view_preserve_replay",
              details = replay_trace_details,
              reason = "map_country_sync",
              dedupe_key = "map_bottom_view_preserve_replay",
              dedupe_signature = build_transition_trace_signature(replay_trace_details)
            )

            sync_psd_map_country_input(preserved_selection, issuer_event = "map_bottom_view_preserve_replay")
          }
        }, once = TRUE)

        later::later(function() {
          if (!is_raw_psd_map_tab_visible()) {
            return()
          }

          current_view_late <- isolate(input$psd_map_bottom_view %||% psd_map_bottom_view_state() %||% NULL)
          if (!identical(current_view_late, selected_view)) {
            return()
          }

          if (!should_replay_preserved_psd_map_country(preserved_selection)) {
            return()
          }

          current_input_late <- isolate(input$psd_map_country_choice %||% NULL)
          if (!identical(current_input_late, preserved_selection)) {
            replay_trace_details <- build_psd_map_country_request_trace_fields(
              selected_country = preserved_selection,
              issuer_event = "map_bottom_view_preserve_replay",
              extra = list(
                selected_view = selected_view,
                preserve_source = preserve_source,
                current_input_replay = current_input_late,
                branch = "later_replay"
              )
            )

            emit_psd_map_country_trace(
              "map_bottom_view_preserve_replay",
              details = replay_trace_details,
              reason = "map_country_sync",
              dedupe_key = "map_bottom_view_preserve_replay",
              dedupe_signature = build_transition_trace_signature(replay_trace_details)
            )

            sync_psd_map_country_input(preserved_selection, issuer_event = "map_bottom_view_preserve_replay")
          }

          current_input_final <- isolate(input$psd_map_country_choice %||% NULL)
          if (identical(current_input_final, preserved_selection)) {
            pending_psd_map_country_target(NULL)
          }
        }, delay = 0.35)
      }

      psd_map_bottom_view_state(selected_view)
      emit_psd_map_country_trace(
        "map_bottom_view_changed",
        details = list(
          selected_view = selected_view,
          notes_panel_open = notes_panel_open,
          notes_jump_anchor = if (length(notes_jump_anchor) > 0) notes_jump_anchor[[1]] else NULL,
          preserved_selection = preserved_selection,
          current_input_before = isolate(input$psd_map_country_choice %||% NULL),
          branch = if (!is.null(preserved_selection)) "preserve_current_selection" else "no_selection_to_preserve"
        )
      )
    }
  }, ignoreInit = FALSE)

  psd_map_country_choices <- reactive({
    psd_state <- psd_canonical_country_state()
    base_choices <- build_psd_country_choice_vector(
      ordered_df = psd_state$ordered_df,
      share_lookup = psd_state$share_lookup,
      metric_code = effective_main_metric()
    )

    defs <- tryCatch(custom_countries_enriched(), error = function(e) data.frame())
    defs_tbl <- as_tibble(defs %||% data.frame()) %>%
      filter(.data$parse_ok) %>%
      transmute(
        custom_name = trimws(as.character(.data$custom_name)),
        custom_name_key = tolower(trimws(as.character(.data$custom_name)))
      ) %>%
      filter(!is.na(.data$custom_name), nzchar(.data$custom_name)) %>%
      arrange(.data$custom_name_key, .data$custom_name) %>%
      distinct(.data$custom_name_key, .keep_all = TRUE)

    if (nrow(defs_tbl) == 0) {
      return(base_choices)
    }

    custom_values <- vapply(defs_tbl$custom_name, build_custom_country_choice_value, character(1))
    custom_labels <- paste0(defs_tbl$custom_name, " (Custom)")
    c(base_choices, stats::setNames(custom_values, custom_labels))
  })

  observeEvent(psd_map_country_choices(), {
    if (!is_psd_effective_map_tab_active()) {
      emit_psd_map_country_trace(
        "map_choice_observer",
        details = list(branch = "inactive_skip"),
        reason = "map_choice_reconcile",
        dedupe_key = "map_choice_observer",
        dedupe_signature = build_transition_trace_signature(list(branch = "inactive_skip"))
      )
      return()
    }

    choice_vector <- psd_map_country_choices()
    valid_choices <- unname(choice_vector)
    preferred_country <- current_psd_map_preferred_country()
    target_selection <- resolve_psd_map_country_selection(valid_choices, preferred_country)
    choice_signature <- paste(names(choice_vector), valid_choices, sep = "=", collapse = "||")
    choices_changed <- !identical(psd_map_choice_signature(), choice_signature)
    current_selection <- map_selected_country()

    emit_psd_map_country_trace(
      "map_choice_observer",
      details = list(
        issuer_event = "map_choice_observer",
        valid_choice_count = length(valid_choices),
        preferred_country = preferred_country,
        current_in_valid_choices = !is.null(current_selection) && nzchar(current_selection) && current_selection %in% valid_choices,
        target_selection = target_selection,
        choices_changed = choices_changed,
        sync_request_issued = !isTRUE(choices_changed) && !identical(input$psd_map_country_choice %||% NULL, target_selection),
        branch = if (isTRUE(choices_changed)) "update_choices_and_selection" else if (!identical(input$psd_map_country_choice %||% NULL, target_selection)) "update_selection_only" else "no_ui_update"
      ),
      reason = "map_choice_reconcile",
      dedupe_key = "map_choice_observer",
      dedupe_signature = build_transition_trace_signature(list(
        issuer_event = "map_choice_observer",
        valid_choice_count = length(valid_choices),
        current_selection = current_selection,
        preferred_country = preferred_country,
        current_in_valid_choices = !is.null(current_selection) && nzchar(current_selection) && current_selection %in% valid_choices,
        target_selection = target_selection,
        choices_changed = choices_changed,
        sync_request_issued = !isTRUE(choices_changed) && !identical(input$psd_map_country_choice %||% NULL, target_selection),
        branch = if (isTRUE(choices_changed)) "update_choices_and_selection" else if (!identical(input$psd_map_country_choice %||% NULL, target_selection)) "update_selection_only" else "no_ui_update"
      ))
    )

    if (!identical(map_selected_country(), target_selection)) {
      map_selected_country(target_selection)
    }

    if (isTRUE(choices_changed)) {
      updateSelectizeInput(session, "psd_map_country_choice", choices = choice_vector, selected = target_selection)
      psd_map_choice_signature(choice_signature)
    } else if (!identical(input$psd_map_country_choice %||% NULL, target_selection)) {
      sync_psd_map_country_input(target_selection, issuer_event = "map_choice_observer")
    }
  }, ignoreInit = FALSE)

  observeEvent(input$psd_map_country_choice, {
    map_input_active <- is_raw_psd_map_tab_visible()

    if (!isTRUE(map_input_active)) {
      clear_psd_map_country_sync_window(reason = "map_input_inactive", force = TRUE)

      emit_psd_map_country_trace(
        "map_input_country_observer",
        details = list(
          selected_country = as.character(input$psd_map_country_choice %||% NULL),
          branch = "inactive_skip"
        ),
        reason = "map_input_country",
        dedupe_key = "map_input_country_observer",
        dedupe_signature = build_transition_trace_signature(list(
          selected_country = as.character(input$psd_map_country_choice %||% NULL),
          branch = "inactive_skip"
        ))
      )
      return()
    }

    selected_country <- as.character(input$psd_map_country_choice)
    raw_main_tab <- as.character(input$main_tabs_panel %||% "")
    pending_target <- as.character(isolate(pending_psd_map_country_target()) %||% "")
    notes_jump_anchor <- if (exists("psd_notes_jump_anchor_country", mode = "function")) {
      isolate(psd_notes_jump_anchor_country())
    } else {
      NULL
    }
    notes_jump_anchor <- as.character(notes_jump_anchor %||% "")
    notes_panel_open <- if (exists("notes_panel_visible", mode = "function")) {
      isTRUE(isolate(notes_panel_visible()))
    } else {
      FALSE
    }
    sidebar_selection <- as.character(isolate(input$country_choice %||% "") %||% "")
    pending_sidebar_target <- if (exists("pending_sidebar_country_target", mode = "function")) {
      as.character(isolate(pending_sidebar_country_target()) %||% "")
    } else {
      ""
    }
    current_map_selection <- as.character(isolate(map_selected_country()) %||% "")
    guard_target <- if (nzchar(pending_target)) {
      pending_target
    } else if (
      nzchar(pending_sidebar_target) &&
      identical(current_map_selection, pending_sidebar_target) &&
      !identical(sidebar_selection, pending_sidebar_target)
    ) {
      pending_sidebar_target
    } else if (isTRUE(notes_panel_open) && nzchar(notes_jump_anchor) && identical(notes_jump_anchor, sidebar_selection)) {
      notes_jump_anchor
    } else {
      ""
    }
    off_surface_world_input <-
      identical(selected_country, "GRAND_TOTAL") &&
      nzchar(raw_main_tab) &&
      !(raw_main_tab %in% c("Map", "Time Series Analysis Tool"))
    raw_programmatic_sync <- isolate(pending_psd_map_country_programmatic_sync())
    raw_programmatic_request_id <- as.character(raw_programmatic_sync$request_id %||% "")
    raw_programmatic_target_country <- as.character(raw_programmatic_sync$target_country %||% "")
    raw_programmatic_stage <- as.character(raw_programmatic_sync$stage %||% "")
    raw_programmatic_phase <- as.character(raw_programmatic_sync$phase %||% "")
    raw_programmatic_present <- !is.null(raw_programmatic_sync) && (
      nzchar(raw_programmatic_request_id) ||
      nzchar(raw_programmatic_target_country) ||
      nzchar(raw_programmatic_stage) ||
      nzchar(raw_programmatic_phase)
    )
    raw_programmatic_match <- raw_programmatic_present && identical(raw_programmatic_target_country, selected_country)
    block_guard_mismatch_candidate <- should_block_psd_map_guard_mismatch(selected_country, guard_target)
    override_guard_target_candidate <- should_override_psd_map_guard_target(selected_country, guard_target)
    clear_pending_target_candidate <- should_clear_pending_psd_map_target(
      selected_country,
      pending_target,
      guard_target,
      clear_matching_target = !isTRUE(raw_programmatic_match)
    )

    emit_psd_map_country_trace(
      "map_input_country_preconsume",
      details = list(
        incoming_input_country = selected_country,
        current_map_selected_country_before = isolate(map_selected_country()),
        current_sidebar_country_before = isolate(input$country_choice %||% NULL),
        pending_psd_target_before = if (nzchar(pending_target)) pending_target else NULL,
        pending_sidebar_target_before = read_pending_sidebar_country_target_for_trace(),
        guard_target_before = if (nzchar(guard_target)) guard_target else NULL,
        raw_main_tab = if (nzchar(raw_main_tab)) raw_main_tab else NULL,
        off_surface_world_input = off_surface_world_input,
        raw_programmatic_request_id = if (nzchar(raw_programmatic_request_id)) raw_programmatic_request_id else NULL,
        raw_programmatic_target_country = if (nzchar(raw_programmatic_target_country)) raw_programmatic_target_country else NULL,
        raw_programmatic_stage = if (nzchar(raw_programmatic_stage)) raw_programmatic_stage else NULL,
        raw_programmatic_phase = if (nzchar(raw_programmatic_phase)) raw_programmatic_phase else NULL,
        raw_programmatic_present = raw_programmatic_present,
        raw_programmatic_matches_input = raw_programmatic_match,
        block_guard_mismatch_candidate = block_guard_mismatch_candidate,
        override_guard_target_candidate = override_guard_target_candidate,
        clear_pending_target_candidate = clear_pending_target_candidate
      ),
      reason = "map_input_country",
      dedupe_key = "map_input_country_preconsume",
      dedupe_signature = build_transition_trace_signature(list(
        incoming_input_country = selected_country,
        current_map_selected_country_before = isolate(map_selected_country()),
        current_sidebar_country_before = isolate(input$country_choice %||% NULL),
        pending_psd_target_before = if (nzchar(pending_target)) pending_target else NULL,
        pending_sidebar_target_before = read_pending_sidebar_country_target_for_trace(),
        guard_target_before = if (nzchar(guard_target)) guard_target else NULL,
        raw_main_tab = if (nzchar(raw_main_tab)) raw_main_tab else NULL,
        off_surface_world_input = off_surface_world_input,
        raw_programmatic_request_id = if (nzchar(raw_programmatic_request_id)) raw_programmatic_request_id else NULL,
        raw_programmatic_target_country = if (nzchar(raw_programmatic_target_country)) raw_programmatic_target_country else NULL,
        raw_programmatic_stage = if (nzchar(raw_programmatic_stage)) raw_programmatic_stage else NULL,
        raw_programmatic_phase = if (nzchar(raw_programmatic_phase)) raw_programmatic_phase else NULL,
        raw_programmatic_present = raw_programmatic_present,
        raw_programmatic_matches_input = raw_programmatic_match,
        block_guard_mismatch_candidate = block_guard_mismatch_candidate,
        override_guard_target_candidate = override_guard_target_candidate,
        clear_pending_target_candidate = clear_pending_target_candidate
      ))
    )

    block_guard_mismatch <- block_guard_mismatch_candidate
    override_guard_target <- override_guard_target_candidate
    programmatic_sync_match <- consume_psd_map_country_programmatic_sync(selected_country)
    clear_pending_target <- should_clear_pending_psd_map_target(
      selected_country,
      pending_target,
      guard_target,
      clear_matching_target = !isTRUE(programmatic_sync_match)
    )

    emit_psd_map_country_trace(
      "map_input_country_observer",
      details = list(
        selected_country = selected_country,
        pending_target = pending_target,
        notes_jump_anchor = if (nzchar(notes_jump_anchor)) notes_jump_anchor else NULL,
        notes_panel_open = notes_panel_open,
        guard_target = if (nzchar(guard_target)) guard_target else NULL,
        raw_main_tab = if (nzchar(raw_main_tab)) raw_main_tab else NULL,
        off_surface_world_input = off_surface_world_input,
        programmatic_sync_match = programmatic_sync_match,
        clear_pending_target = clear_pending_target,
        branch = if (isTRUE(off_surface_world_input)) {
          "ignore_off_surface_world_default"
        } else if (block_guard_mismatch) {
          "ignore_pending_grand_total_mismatch"
        } else if (clear_pending_target && override_guard_target) {
          "adopt_input_selection_clear_stale_pending"
        } else if (clear_pending_target) {
          "adopt_input_selection_clear_pending"
        } else if (override_guard_target) {
          "adopt_input_selection_override_guard"
        } else if (!is.na(selected_country) && nzchar(selected_country) && nzchar(guard_target) && identical(selected_country, guard_target) && nzchar(pending_target)) {
          "adopt_input_selection_keep_pending"
        } else if (!is.na(selected_country) && nzchar(selected_country) && nzchar(guard_target)) {
          "adopt_input_selection_keep_anchor"
        } else if (!is.na(selected_country) && nzchar(selected_country)) {
          "adopt_input_selection"
        } else {
          "ignore_blank"
        }
      ),
      reason = "map_input_country",
      dedupe_key = "map_input_country_observer",
      dedupe_signature = build_transition_trace_signature(list(
        selected_country = selected_country,
        pending_target = pending_target,
        notes_jump_anchor = if (nzchar(notes_jump_anchor)) notes_jump_anchor else NULL,
        notes_panel_open = notes_panel_open,
        guard_target = if (nzchar(guard_target)) guard_target else NULL,
        raw_main_tab = if (nzchar(raw_main_tab)) raw_main_tab else NULL,
        off_surface_world_input = off_surface_world_input,
        programmatic_sync_match = programmatic_sync_match,
        clear_pending_target = clear_pending_target,
        branch = if (isTRUE(off_surface_world_input)) {
          "ignore_off_surface_world_default"
        } else if (block_guard_mismatch) {
          "ignore_pending_grand_total_mismatch"
        } else if (clear_pending_target && override_guard_target) {
          "adopt_input_selection_clear_stale_pending"
        } else if (clear_pending_target) {
          "adopt_input_selection_clear_pending"
        } else if (override_guard_target) {
          "adopt_input_selection_override_guard"
        } else if (!is.na(selected_country) && nzchar(selected_country) && nzchar(guard_target) && identical(selected_country, guard_target) && nzchar(pending_target)) {
          "adopt_input_selection_keep_pending"
        } else if (!is.na(selected_country) && nzchar(selected_country) && nzchar(guard_target)) {
          "adopt_input_selection_keep_anchor"
        } else if (!is.na(selected_country) && nzchar(selected_country)) {
          "adopt_input_selection"
        } else {
          "ignore_blank"
        }
      ))
    )

    if (!is.na(selected_country) && nzchar(selected_country)) {
      if (isTRUE(off_surface_world_input)) {
        clear_psd_map_country_sync_window(reason = "off_surface_world_input", force = TRUE)
        return()
      }

      if (block_guard_mismatch) {
        clear_psd_map_country_sync_window(reason = "guard_repair", force = TRUE)

        # Repair remount/default races so the visible map selector snaps back to the guarded target.
        sync_psd_map_country_input(guard_target, issuer_event = "map_input_guard_repair")
        return()
      }

      clear_psd_map_country_sync_window(
        reason = "input_alignment_accepted",
        request_id = raw_programmatic_request_id,
        target_country = selected_country,
        bottom_view = normalize_psd_map_bottom_view(
          isolate(input$psd_map_bottom_view %||% psd_map_bottom_view_state() %||% NULL),
          default = "summary"
        )
      )

      if (isTRUE(clear_pending_target)) {
        pending_psd_map_country_target(NULL)
      }

      map_selected_country(selected_country)
      if (exists("write_canonical_psd_country", mode = "function")) {
        write_canonical_psd_country(selected_country)
      }
      sync_sidebar_country_from_psd(selected_country, reason = "map_input_country")
    }
  }, ignoreInit = FALSE)

  observe({
    if (!identical(input$data_source_choice %||% NULL, "psd")) {
      return()
    }

    if (!is_raw_psd_map_tab_visible()) {
      return()
    }

    input_selection <- as.character(input$psd_map_country_choice %||% character(0))
    input_selection <- input_selection[!is.na(input_selection) & nzchar(input_selection)]

    if (length(input_selection) == 0) {
      return()
    }

    valid_choices <- unname(psd_map_country_choices())
    valid_choices <- as.character(valid_choices %||% character(0))
    valid_choices <- valid_choices[!is.na(valid_choices) & nzchar(valid_choices)]
    selected_country <- input_selection[[1]]

    pending_target <- as.character(isolate(pending_psd_map_country_target()) %||% "")
    notes_jump_anchor <- if (exists("psd_notes_jump_anchor_country", mode = "function")) {
      isolate(psd_notes_jump_anchor_country())
    } else {
      NULL
    }
    notes_jump_anchor <- as.character(notes_jump_anchor %||% "")
    notes_panel_open <- if (exists("notes_panel_visible", mode = "function")) {
      isTRUE(isolate(notes_panel_visible()))
    } else {
      FALSE
    }
    sidebar_selection <- as.character(isolate(input$country_choice %||% "") %||% "")
    guard_target <- if (nzchar(pending_target)) {
      pending_target
    } else if (isTRUE(notes_panel_open) && nzchar(notes_jump_anchor) && identical(notes_jump_anchor, sidebar_selection)) {
      notes_jump_anchor
    } else {
      ""
    }

    block_guard_mismatch <- should_block_psd_map_guard_mismatch(selected_country, guard_target)
    override_guard_target <- should_override_psd_map_guard_target(selected_country, guard_target)
    clear_pending_target <- should_clear_pending_psd_map_target(selected_country, pending_target, guard_target)

    if (block_guard_mismatch) {
      emit_psd_map_country_trace(
        "psd_active_country_reconciler",
        details = list(
          selected_country = selected_country,
          pending_target = if (nzchar(pending_target)) pending_target else NULL,
          notes_jump_anchor = if (nzchar(notes_jump_anchor)) notes_jump_anchor else NULL,
          notes_panel_open = notes_panel_open,
          guard_target = guard_target,
          valid_choice_count = length(valid_choices),
          branch = "ignore_pending_grand_total_mismatch"
        ),
        reason = "psd_active_country_reconcile",
        dedupe_key = "psd_active_country_reconciler",
        dedupe_signature = build_transition_trace_signature(list(
          selected_country = selected_country,
          pending_target = if (nzchar(pending_target)) pending_target else NULL,
          notes_jump_anchor = if (nzchar(notes_jump_anchor)) notes_jump_anchor else NULL,
          notes_panel_open = notes_panel_open,
          guard_target = guard_target,
          valid_choice_count = length(valid_choices),
          branch = "ignore_pending_grand_total_mismatch"
        ))
      )
      return()
    }

    if (isTRUE(clear_pending_target)) {
      pending_psd_map_country_target(NULL)
    }

    if (!(selected_country %in% valid_choices)) {
      clear_psd_map_country_sync_window(
        reason = "invalid_input_selection",
        target_country = selected_country,
        bottom_view = normalize_psd_map_bottom_view(
          isolate(input$psd_map_bottom_view %||% psd_map_bottom_view_state() %||% NULL),
          default = "summary"
        )
      )

      emit_psd_map_country_trace(
        "psd_active_country_reconciler",
        details = list(
          selected_country = selected_country,
          pending_target = if (nzchar(pending_target)) pending_target else NULL,
          notes_jump_anchor = if (nzchar(notes_jump_anchor)) notes_jump_anchor else NULL,
          notes_panel_open = notes_panel_open,
          guard_target = if (nzchar(guard_target)) guard_target else NULL,
          valid_choice_count = length(valid_choices),
          branch = "ignore_invalid_input_selection"
        ),
        reason = "psd_active_country_reconcile",
        dedupe_key = "psd_active_country_reconciler",
        dedupe_signature = build_transition_trace_signature(list(
          selected_country = selected_country,
          pending_target = if (nzchar(pending_target)) pending_target else NULL,
          notes_jump_anchor = if (nzchar(notes_jump_anchor)) notes_jump_anchor else NULL,
          notes_panel_open = notes_panel_open,
          guard_target = if (nzchar(guard_target)) guard_target else NULL,
          valid_choice_count = length(valid_choices),
          branch = "ignore_invalid_input_selection"
        ))
      )
      return()
    }

    current_map_selection <- isolate(map_selected_country())
    if (!identical(current_map_selection, selected_country)) {
      map_selected_country(selected_country)
    }

    sync_sidebar_country_from_psd(selected_country, reason = "psd_active_country_reconcile")

    emit_psd_map_country_trace(
      "psd_active_country_reconciler",
      details = list(
        selected_country = selected_country,
        pending_target = if (nzchar(pending_target)) pending_target else NULL,
        notes_jump_anchor = if (nzchar(notes_jump_anchor)) notes_jump_anchor else NULL,
        notes_panel_open = notes_panel_open,
        guard_target = if (nzchar(guard_target)) guard_target else NULL,
        override_guard_target = override_guard_target,
        clear_pending_target = clear_pending_target,
        pending_target_cleared = clear_pending_target,
        current_map_selection_before = current_map_selection,
        current_sidebar_country = isolate(input$country_choice %||% NULL),
        valid_choice_count = length(valid_choices),
        branch = if (!identical(current_map_selection, selected_country) && isTRUE(clear_pending_target)) {
          "override_pending_target_and_sync"
        } else if (isTRUE(clear_pending_target)) {
          "clear_pending_target_and_sync"
        } else if (!identical(current_map_selection, selected_country)) {
          "adopt_and_sync"
        } else {
          "sync_sidebar_only"
        }
      ),
      reason = "psd_active_country_reconcile",
      dedupe_key = "psd_active_country_reconciler",
      dedupe_signature = build_transition_trace_signature(list(
        selected_country = selected_country,
        pending_target = if (nzchar(pending_target)) pending_target else NULL,
        notes_jump_anchor = if (nzchar(notes_jump_anchor)) notes_jump_anchor else NULL,
        notes_panel_open = notes_panel_open,
        guard_target = if (nzchar(guard_target)) guard_target else NULL,
        override_guard_target = override_guard_target,
        clear_pending_target = clear_pending_target,
        pending_target_cleared = clear_pending_target,
        current_map_selection_before = current_map_selection,
        current_sidebar_country = isolate(input$country_choice %||% NULL),
        valid_choice_count = length(valid_choices),
        branch = if (!identical(current_map_selection, selected_country) && isTRUE(clear_pending_target)) {
          "override_pending_target_and_sync"
        } else if (isTRUE(clear_pending_target)) {
          "clear_pending_target_and_sync"
        } else if (!identical(current_map_selection, selected_country)) {
          "adopt_and_sync"
        } else {
          "sync_sidebar_only"
        }
      ))
    )
  })

  observeEvent(input$country_choice, {
    if (!identical(input$data_source_choice %||% NULL, "psd")) {
      return()
    }

    sidebar_pending_target <- if (exists("pending_sidebar_country_target", mode = "function")) {
      as.character(isolate(pending_sidebar_country_target()) %||% character(0))
    } else {
      character(0)
    }
    sidebar_pending_target <- sidebar_pending_target[!is.na(sidebar_pending_target) & nzchar(sidebar_pending_target)]

    pending_target <- as.character(isolate(pending_psd_map_country_target()) %||% character(0))
    pending_target <- pending_target[!is.na(pending_target) & nzchar(pending_target)]

    sidebar_selection <- as.character(input$country_choice %||% character(0))
    sidebar_selection <- sidebar_selection[!is.na(sidebar_selection) & nzchar(sidebar_selection)]
    if (length(sidebar_selection) == 0) {
      return()
    }

    canonical_sidebar_selection <- if (exists("canonicalize_notes_country_codes", mode = "function")) {
      canonicalize_notes_country_codes(sidebar_selection[[1]])
    } else {
      sidebar_selection[[1]]
    }
    canonical_sidebar_selection <- as.character(canonical_sidebar_selection %||% character(0))
    canonical_sidebar_selection <- canonical_sidebar_selection[!is.na(canonical_sidebar_selection) & nzchar(canonical_sidebar_selection)]
    if (length(canonical_sidebar_selection) == 0) {
      return()
    }

    if (identical(sidebar_selection[[1]], canonical_sidebar_selection[[1]])) {
      time_series_handoff_guard <- current_psd_time_series_country_handoff_guard()
      time_series_handoff_target <- if (length(sidebar_pending_target) > 0) {
        sidebar_pending_target[[1]]
      } else {
        time_series_handoff_guard
      }

      guarded_psd_time_series_world_handoff <-
        identical(input$main_tabs_panel %||% NULL, "Time Series Analysis Tool") &&
        identical(sidebar_selection[[1]], "GRAND_TOTAL") &&
        !is.null(time_series_handoff_target) &&
        nzchar(time_series_handoff_target) &&
        !identical(time_series_handoff_target, "GRAND_TOTAL") &&
        identical(isolate(map_selected_country()), time_series_handoff_target)

      if (isTRUE(guarded_psd_time_series_world_handoff)) {
        sync_sidebar_country_from_psd(
          time_series_handoff_target,
          reason = "time_series_country_handoff"
        )
        emit_psd_map_country_trace(
          "clear_pending_psd_map_target_from_sidebar",
          details = list(
            sidebar_country = sidebar_selection[[1]],
            pending_target = if (length(pending_target) > 0) pending_target[[1]] else NULL,
            pending_sidebar_target = if (length(sidebar_pending_target) > 0) sidebar_pending_target[[1]] else NULL,
            time_series_handoff_guard = time_series_handoff_guard,
            time_series_handoff_target = time_series_handoff_target,
            canonical_sidebar_country = canonical_sidebar_selection[[1]],
            current_map_selected_country = isolate(map_selected_country()),
            branch = "ignore_stale_time_series_world_handoff"
          ),
          reason = "map_country_sync",
          dedupe_key = "clear_pending_psd_map_target_from_sidebar",
          dedupe_signature = build_transition_trace_signature(list(
            sidebar_country = sidebar_selection[[1]],
            pending_target = if (length(pending_target) > 0) pending_target[[1]] else NULL,
            pending_sidebar_target = if (length(sidebar_pending_target) > 0) sidebar_pending_target[[1]] else NULL,
            time_series_handoff_guard = time_series_handoff_guard,
            time_series_handoff_target = time_series_handoff_target,
            canonical_sidebar_country = canonical_sidebar_selection[[1]],
            current_map_selected_country = isolate(map_selected_country()),
            branch = "ignore_stale_time_series_world_handoff"
          ))
        )
        return()
      }

      if (
        length(sidebar_pending_target) > 0 &&
        !identical(sidebar_selection[[1]], sidebar_pending_target[[1]]) &&
        exists("pending_sidebar_country_target", mode = "function")
      ) {
        pending_sidebar_country_target(NULL)
        clear_psd_map_country_sync_window(
          reason = "sidebar_override",
          target_country = sidebar_pending_target[[1]],
          bottom_view = normalize_psd_map_bottom_view(
            isolate(input$psd_map_bottom_view %||% psd_map_bottom_view_state() %||% NULL),
            default = "summary"
          )
        )
      }

      if (length(pending_target) > 0 && !identical(sidebar_selection[[1]], pending_target[[1]])) {
        pending_psd_map_country_target(NULL)
        clear_psd_map_country_sync_window(
          reason = "sidebar_override",
          target_country = pending_target[[1]],
          bottom_view = normalize_psd_map_bottom_view(
            isolate(input$psd_map_bottom_view %||% psd_map_bottom_view_state() %||% NULL),
            default = "summary"
          )
        )
      }

      valid_choices <- unname(psd_map_country_choices())
      valid_choices <- as.character(valid_choices %||% character(0))
      valid_choices <- valid_choices[!is.na(valid_choices) & nzchar(valid_choices)]

      if (sidebar_selection[[1]] %in% valid_choices) {
        if (!identical(isolate(map_selected_country()), sidebar_selection[[1]])) {
          map_selected_country(sidebar_selection[[1]])
        }

        if (
          is_raw_psd_map_tab_visible() &&
          !identical(input$psd_map_country_choice %||% NULL, sidebar_selection[[1]])
        ) {
          sync_psd_map_country_input(sidebar_selection[[1]], issuer_event = "sidebar_country_observer")
        }
      }

      emit_psd_map_country_trace(
        "clear_pending_psd_map_target_from_sidebar",
        details = list(
          sidebar_country = sidebar_selection[[1]],
          pending_target = if (length(pending_target) > 0) pending_target[[1]] else NULL,
          pending_sidebar_target = if (length(sidebar_pending_target) > 0) sidebar_pending_target[[1]] else NULL,
          canonical_sidebar_country = canonical_sidebar_selection[[1]],
          current_map_selected_country = isolate(map_selected_country()),
          branch = if (sidebar_selection[[1]] %in% valid_choices) "explicit_sidebar_override_and_sync" else "explicit_sidebar_override"
        ),
        reason = "map_country_sync",
        dedupe_key = "clear_pending_psd_map_target_from_sidebar",
        dedupe_signature = build_transition_trace_signature(list(
          sidebar_country = sidebar_selection[[1]],
          pending_target = if (length(pending_target) > 0) pending_target[[1]] else NULL,
          pending_sidebar_target = if (length(sidebar_pending_target) > 0) sidebar_pending_target[[1]] else NULL,
          canonical_sidebar_country = canonical_sidebar_selection[[1]],
          current_map_selected_country = isolate(map_selected_country()),
          branch = if (sidebar_selection[[1]] %in% valid_choices) "explicit_sidebar_override_and_sync" else "explicit_sidebar_override"
        ))
      )
    }
  }, ignoreInit = TRUE)

  observeEvent(map_selected_country(), {
    if (!is_psd_effective_map_tab_active()) {
      emit_psd_map_country_trace(
        "map_selected_country_observer",
        details = list(
          selected_country = map_selected_country(),
          branch = "inactive_skip"
        ),
        reason = "map_selected_country",
        dedupe_key = "map_selected_country_observer",
        dedupe_signature = build_transition_trace_signature(list(
          selected_country = map_selected_country(),
          branch = "inactive_skip"
        ))
      )
      return()
    }

    selected_country <- map_selected_country()
    valid_choices <- unname(psd_map_country_choices())

    emit_psd_map_country_trace(
      "map_selected_country_observer",
      details = list(
        issuer_event = "map_selected_country_observer",
        selected_country = selected_country,
        selected_in_valid_choices = !is.null(selected_country) && nzchar(selected_country) && selected_country %in% valid_choices,
        sync_request_issued = !is.null(selected_country) && selected_country %in% valid_choices && !identical(input$psd_map_country_choice %||% NULL, selected_country),
        branch = if (!is.null(selected_country) && selected_country %in% valid_choices && !identical(input$psd_map_country_choice %||% NULL, selected_country)) "sync_input" else if (!is.null(selected_country) && selected_country %in% valid_choices) "already_aligned" else "invalid_selection"
      ),
      reason = "map_selected_country",
      dedupe_key = "map_selected_country_observer",
      dedupe_signature = build_transition_trace_signature(list(
        issuer_event = "map_selected_country_observer",
        selected_country = selected_country,
        selected_in_valid_choices = !is.null(selected_country) && nzchar(selected_country) && selected_country %in% valid_choices,
        sync_request_issued = !is.null(selected_country) && selected_country %in% valid_choices && !identical(input$psd_map_country_choice %||% NULL, selected_country),
        input_selection = input$psd_map_country_choice %||% NULL,
        branch = if (!is.null(selected_country) && selected_country %in% valid_choices && !identical(input$psd_map_country_choice %||% NULL, selected_country)) "sync_input" else if (!is.null(selected_country) && selected_country %in% valid_choices) "already_aligned" else "invalid_selection"
      ))
    )

    if (
      !is.null(selected_country) &&
      selected_country %in% valid_choices &&
      !identical(input$psd_map_country_choice %||% NULL, selected_country)
    ) {
      sync_psd_map_country_input(selected_country, issuer_event = "map_selected_country_observer")
    }
  }, ignoreInit = TRUE)

  observeEvent(map_display_dataset(), {
    map_display <- map_display_dataset()
    current_selection <- map_selected_country()
    selection_df <- if (identical(map_display$mode, "comparison")) {
      map_display$display_df
    } else {
      map_display$ranked_df
    }

    if (is.null(current_selection)) {
      return()
    }

    if (is_psd_effective_map_tab_active()) {
      return()
    }

    if (identical(input$data_source_choice %||% NULL, "psd")) {
      emit_psd_map_country_trace(
        "map_display_inactive_preserve",
        details = list(
          status = map_display$map_state$status %||% NULL,
          selection_rows = nrow(selection_df),
          current_selection = current_selection
        )
      )
      return()
    }

    if (!identical(map_display$map_state$status, "ok") ||
        nrow(selection_df) == 0 ||
        !(current_selection %in% selection_df$selected_country_key)) {
      map_selected_country(NULL)
    }
  }, ignoreInit = TRUE)

  observeEvent(input$map_summary_table_toggle, {
    toggle <- input$map_summary_table_toggle
    req(!is.null(toggle$country))

    toggle_country <- as.character(toggle$country %||% "")
    toggle_selected <- isTRUE(toggle$selected)
    seed_pending_target <- toggle_selected && nzchar(toggle_country) && !identical(toggle_country, "GRAND_TOTAL")
    activate_matrix <-
      toggle_selected &&
      is_psd_effective_map_tab_active() &&
      nzchar(toggle_country) &&
      !identical(toggle_country, "GRAND_TOTAL")
    sync_request_issued <- toggle_selected && nzchar(toggle_country) && is_raw_psd_map_tab_visible()

    toggle_branch <- if (toggle_selected) {
      if (activate_matrix) {
        "select_country_activate_matrix"
      } else {
        "select_country"
      }
    } else if (!is_psd_effective_map_tab_active()) {
      "clear_inactive"
    } else {
      "preserve_active"
    }

    emit_psd_map_country_trace(
      "map_summary_table_toggle",
      details = list(
        issuer_event = "map_summary_table_toggle",
        toggle_country = toggle_country,
        toggle_selected = toggle_selected,
        pending_target = if (seed_pending_target) toggle_country else NULL,
        activate_matrix = activate_matrix,
        sync_request_issued = sync_request_issued,
        branch = toggle_branch
      ),
      reason = "map_summary_toggle",
      dedupe_key = "map_summary_table_toggle",
      dedupe_signature = build_transition_trace_signature(list(
        issuer_event = "map_summary_table_toggle",
        toggle_country = toggle_country,
        toggle_selected = toggle_selected,
        pending_target = if (seed_pending_target) toggle_country else NULL,
        map_active = is_psd_effective_map_tab_active(),
        activate_matrix = activate_matrix,
        sync_request_issued = sync_request_issued,
        branch = toggle_branch
      ))
    )

    if (toggle_selected) {
      if (seed_pending_target) {
        pending_psd_map_country_target(toggle_country)
      } else {
        pending_psd_map_country_target(NULL)
      }

      map_selected_country(toggle_country)
      if (nzchar(toggle_country) && is_raw_psd_map_tab_visible()) {
        sync_psd_map_country_input(toggle_country, issuer_event = "map_summary_table_toggle")
      }
      if (activate_matrix) {
        set_psd_map_bottom_view("matrix")
      }
    } else {
      # Preserve the PSD map country across summary-table unmount/re-render churn.
      if (!is_psd_effective_map_tab_active()) {
        map_selected_country(NULL)
      }
    }
  })

  map_plot_click_ready <- reactiveVal(FALSE)

  map_plot_click_data <- reactive({
    if (!is_effective_map_tab_active()) {
      return(NULL)
    }

    if (!isTRUE(map_plot_click_ready())) {
      return(NULL)
    }

    suppressWarnings(plotly::event_data("plotly_click", source = "map_plot_source"))
  })

  observeEvent(map_plot_click_data(), {
    click_data <- map_plot_click_data()
    if (is.null(click_data)) {
      return()
    }

    selected_key <- if (!is.null(click_data$customdata)) {
      as.character(click_data$customdata)
    } else if (!is.null(click_data$location)) {
      map_display_dataset()$ranked_df %>%
        filter(.data$map_location == as.character(click_data$location)) %>%
        pull(.data$selected_country_key)
    } else {
      character(0)
    }

    if (length(selected_key) > 0 && !is.na(selected_key[[1]]) && nzchar(selected_key[[1]])) {
      activate_matrix <- is_psd_effective_map_tab_active() && !identical(selected_key[[1]], "GRAND_TOTAL")
      click_branch <- if (is_psd_effective_map_tab_active()) {
        if (activate_matrix) {
          "select_activate_matrix_and_sync_visible_input"
        } else {
          "select_and_sync_visible_input"
        }
      } else {
        "select_only"
      }

      emit_psd_map_country_trace(
        "map_plot_click",
        details = list(
          selected_country = selected_key[[1]],
          resolved_from = if (!is.null(click_data$customdata)) "customdata" else "location_lookup",
          map_active = is_psd_effective_map_tab_active(),
          activate_matrix = activate_matrix,
          branch = click_branch
        ),
        reason = "map_plot_click",
        dedupe_key = "map_plot_click",
        dedupe_signature = build_transition_trace_signature(list(
          selected_country = selected_key[[1]],
          resolved_from = if (!is.null(click_data$customdata)) "customdata" else "location_lookup",
          map_active = is_psd_effective_map_tab_active(),
          activate_matrix = activate_matrix,
          branch = click_branch
        ))
      )

      map_selected_country(selected_key[[1]])
      if (is_psd_effective_map_tab_active()) {
        if (activate_matrix) {
          set_psd_map_bottom_view("matrix")
        }
        updateSelectizeInput(session, "psd_map_country_choice", selected = selected_key[[1]])
      }
    } else {
      emit_psd_map_country_trace(
        "map_plot_click",
        details = list(branch = "no_country_resolved"),
        reason = "map_plot_click",
        dedupe_key = "map_plot_click",
        dedupe_signature = build_transition_trace_signature(list(branch = "no_country_resolved"))
      )
    }
  }, ignoreInit = TRUE)

  observeEvent(list(input$data_source_choice, input$main_tabs_panel), {
    source_choice <- isolate(input$data_source_choice %||% NULL)
    active_tab <- isolate(input$main_tabs_panel %||% NULL)
    active_tab <- as.character(active_tab %||% character(0))
    active_tab <- active_tab[!is.na(active_tab) & nzchar(active_tab)]
    previous_psd_surface_tab <- isolate(last_psd_surface_main_tab())

    if (identical(source_choice, "psd") && length(active_tab) > 0) {
      last_psd_surface_main_tab(active_tab[[1]])
    } else if (!identical(source_choice, "psd")) {
      last_psd_surface_main_tab(NULL)
    }

    if (!is_raw_psd_map_tab_visible()) {
      if (identical(source_choice, "psd") && identical(active_tab[[1]] %||% NULL, "Time Series Analysis Tool")) {
        handoff_country <- as.character(isolate(map_selected_country()) %||% character(0))
        handoff_country <- handoff_country[!is.na(handoff_country) & nzchar(handoff_country)]
        if (length(handoff_country) > 0 && !identical(handoff_country[[1]], "GRAND_TOTAL")) {
          psd_time_series_country_handoff_guard(list(
            target_country = handoff_country[[1]],
            expires_at = Sys.time() + 15
          ))
          sync_sidebar_country_from_psd(handoff_country[[1]], reason = "time_series_tab_entry")
        }
      }

      psd_map_choice_signature(NULL)
      clear_psd_map_country_sync_window(reason = "map_hidden", force = TRUE)

      emit_psd_map_country_trace(
        "map_activation_observer",
        details = list(branch = "inactive_reset_choice_signature"),
        reason = "map_activation",
        dedupe_key = "map_activation_observer",
        dedupe_signature = build_transition_trace_signature(list(branch = "inactive_reset_choice_signature"))
      )
      return()
    }

    time_series_reentry <- identical(previous_psd_surface_tab, "Time Series Analysis Tool")
    target_bottom_view <- resolve_psd_map_activation_bottom_view(default = "summary", force_summary = time_series_reentry)
    set_psd_map_bottom_view(target_bottom_view$view)

    valid_choices <- unname(psd_map_country_choices())
    preferred_country <- current_psd_map_preferred_country()
    current_selection <- as.character(isolate(map_selected_country()) %||% character(0))
    current_selection <- current_selection[!is.na(current_selection) & nzchar(current_selection)]
    input_selection <- as.character(isolate(input$psd_map_country_choice %||% character(0)))
    input_selection <- input_selection[!is.na(input_selection) & nzchar(input_selection)]
    pending_map_selection <- as.character(isolate(pending_psd_map_country_target()) %||% character(0))
    pending_map_selection <- pending_map_selection[!is.na(pending_map_selection) & nzchar(pending_map_selection)]
    pending_sidebar_selection <- if (exists("pending_sidebar_country_target", mode = "function")) {
      as.character(isolate(pending_sidebar_country_target()) %||% character(0))
    } else {
      character(0)
    }
    pending_sidebar_selection <- pending_sidebar_selection[!is.na(pending_sidebar_selection) & nzchar(pending_sidebar_selection)]

    activation_preferred_country <- if (
      length(current_selection) > 0 &&
      current_selection[[1]] %in% valid_choices &&
      length(input_selection) > 0 &&
      identical(preferred_country, input_selection[[1]]) &&
      !identical(current_selection[[1]], input_selection[[1]]) &&
      length(pending_map_selection) == 0 &&
      length(pending_sidebar_selection) == 0
    ) {
      current_selection[[1]]
    } else {
      preferred_country
    }

    target_country <- resolve_psd_map_country_selection(valid_choices, preferred_choice = activation_preferred_country)
    sync_request_issued <- !is.null(target_country) && nzchar(target_country) && !identical(input$psd_map_country_choice %||% NULL, target_country)
    emit_psd_map_country_trace(
      "map_activation_observer",
      details = list(
        issuer_event = "map_activation_observer",
        valid_choice_count = length(valid_choices),
        preferred_country = preferred_country,
        activation_preferred_country = activation_preferred_country,
        target_country = target_country,
        target_bottom_view = target_bottom_view$view,
        target_bottom_view_source = target_bottom_view$source,
        previous_psd_surface_tab = previous_psd_surface_tab,
        time_series_reentry = time_series_reentry,
        sync_request_issued = sync_request_issued,
        branch = if (!is.null(target_country) && nzchar(target_country)) "activate_with_target" else "activate_without_target"
      ),
      reason = "map_activation",
      dedupe_key = "map_activation_observer",
      dedupe_signature = build_transition_trace_signature(list(
        issuer_event = "map_activation_observer",
        valid_choice_count = length(valid_choices),
        preferred_country = preferred_country,
        activation_preferred_country = activation_preferred_country,
        target_country = target_country,
        target_bottom_view = target_bottom_view$view,
        target_bottom_view_source = target_bottom_view$source,
        previous_psd_surface_tab = previous_psd_surface_tab,
        time_series_reentry = time_series_reentry,
        sync_request_issued = sync_request_issued,
        branch = if (!is.null(target_country) && nzchar(target_country)) "activate_with_target" else "activate_without_target"
      ))
    )

    if (!is.null(target_country) && nzchar(target_country)) {
      if (!identical(map_selected_country(), target_country)) {
        map_selected_country(target_country)
      }

      if (!identical(input$psd_map_country_choice %||% NULL, target_country)) {
        sync_psd_map_country_input(target_country, issuer_event = "map_activation_observer")
      }
    }
  }, ignoreInit = TRUE)

  output$psd_map_controls_ui <- renderUI({
    surface_refresh_generation <- map_surface_refresh_nonce()
    controls_active <- is_psd_effective_map_tab_active()
    if (!controls_active) {
      raw_transition_state <- tryCatch(isolate(psd_source_transition_state()), error = function(...) NULL)
      current_transition_state <- tryCatch(isolate(current_psd_source_transition_state()), error = function(...) NULL)
      emit_psd_map_country_trace(
        "map_controls_render",
        details = list(
          outcome = "returned_null",
          raw_source = isolate(input$data_source_choice %||% NULL),
          safe_source = tryCatch(isolate(current_source_choice_safe()), error = function(...) NULL),
          raw_tab = isolate(input$main_tabs_panel %||% NULL),
          safe_tab = tryCatch(isolate(current_main_tab_safe()), error = function(...) NULL),
          is_psd_effective_map_tab_active = controls_active,
          raw_transition_active = tryCatch(as.character(isTRUE(isolate(psd_source_transition_active()))), error = function(...) "FALSE"),
          raw_transition_tab = if (is.null(raw_transition_state)) NULL else raw_transition_state$tab,
          current_transition_tab = if (is.null(current_transition_state)) NULL else current_transition_state$tab
        ),
        reason = "map_controls_render",
        dedupe_key = "map_controls_render_inactive",
        dedupe_signature = build_transition_trace_signature(list(
          raw_source = isolate(input$data_source_choice %||% NULL),
          raw_tab = isolate(input$main_tabs_panel %||% NULL),
          raw_transition_tab = if (is.null(raw_transition_state)) NULL else raw_transition_state$tab,
          current_transition_tab = if (is.null(current_transition_state)) NULL else current_transition_state$tab,
          outcome = "returned_null"
        ))
      )
      return(NULL)
    }

    choice_vector <- psd_map_country_choices()
    preferred_country <- isolate(current_psd_map_preferred_country())
    selected_country <- resolve_psd_map_country_selection(
      valid_choices = unname(choice_vector),
      preferred_choice = preferred_country
    )

    emit_psd_map_country_trace(
      "map_controls_render",
      details = list(
        outcome = "returned_country_control",
        raw_source = isolate(input$data_source_choice %||% NULL),
        safe_source = tryCatch(isolate(current_source_choice_safe()), error = function(...) NULL),
        raw_tab = isolate(input$main_tabs_panel %||% NULL),
        safe_tab = tryCatch(isolate(current_main_tab_safe()), error = function(...) NULL),
        is_psd_effective_map_tab_active = controls_active,
        valid_choice_count = length(choice_vector),
        preferred_country = preferred_country,
        rendered_selected_country = selected_country
      ),
      reason = "map_controls_render",
      dedupe_key = "map_controls_render",
      dedupe_signature = build_transition_trace_signature(list(
        raw_source = isolate(input$data_source_choice %||% NULL),
        raw_tab = isolate(input$main_tabs_panel %||% NULL),
        outcome = "returned_country_control",
        valid_choice_count = length(choice_vector),
        preferred_country = preferred_country,
        rendered_selected_country = selected_country
      ))
    )

    div(
      style = "padding: 0 0 4px 0; margin-top: 8px;",
      div(
        style = "max-width: 320px;",
        selectizeInput(
          inputId = "psd_map_country_choice",
          label = "Country:",
          choices = choice_vector,
          selected = selected_country,
          width = "100%",
          options = psd_country_selectize_options()
        )
      )
    )
  })

  outputOptions(output, "psd_map_controls_ui", suspendWhenHidden = FALSE)

  output$map_plot <- renderPlotly({
    source_choice <- current_source_choice_safe(default = input$data_source_choice %||% "export_sales")
    map_active <- isTRUE(tryCatch(is_effective_map_tab_active(source_choice = source_choice), error = function(e) FALSE))
    if (!map_active) {
      record_cache_body_execution(session, "map_plot_gated_skip")
      map_plot_click_ready(FALSE)
      return(NULL)
    }

    record_cache_body_execution(session, "map_plot_executed")
    start_time <- Sys.time()
    map_display <- map_display_dataset()
    display_mode <- map_display$mode
    map_state <- map_display$map_state
    top_n_cutoff <- map_display$top_n_cutoff
    metric_col <- map_state$metric_col
    metric_label <- get_active_metric_label(metric_col)

    finalize_map_plot <- function(plot_obj) {
      row_count <- if (is.data.frame(map_display$display_df) && nrow(map_display$display_df) > 0) {
        nrow(map_display$display_df)
      } else if (is.data.frame(map_display$ranked_df)) {
        nrow(map_display$ranked_df)
      } else {
        0L
      }

      if (identical(input$data_source_choice, "psd")) {
        log_perf(
          "psd_map_plot",
          start_time,
          details = list(
            status = map_state$status %||% "unknown",
            mode = display_mode %||% "unknown",
            metric = metric_col %||% NA_character_,
            rows = row_count
          )
        )
      } else {
        log_perf(
          "map_plot",
          start_time,
          details = list(
            status = map_state$status %||% "unknown",
            mode = display_mode %||% "unknown",
            metric = metric_col %||% NA_character_,
            source = source_choice,
            rows = row_count
          )
        )
      }

      map_plot_click_ready(TRUE)
      plot_obj %>% plotly::event_register("plotly_click")
    }

    build_map_empty_plot <- function(plot_title) {
      plotly::plot_ly(source = "map_plot_source", type = "scatter", mode = "lines") %>%
        layout(
          title = plot_title,
          xaxis = list(visible = FALSE, showgrid = FALSE, zeroline = FALSE),
          yaxis = list(visible = FALSE, showgrid = FALSE, zeroline = FALSE),
          showlegend = FALSE
        ) %>%
        finalize_map_plot()
    }

    if (identical(map_state$status, "comparison_metric_ineligible")) {
      return(build_map_empty_plot(plot_title = paste0(metric_label, " does not support historical comparison in the Map tab")))
    }

    if (identical(map_state$status, "unsupported_metric")) {
      return(build_map_empty_plot(plot_title = paste0(metric_label, " is not available for the Map tab")))
    }

    if (identical(map_state$status, "no_year_data")) {
      return(build_map_empty_plot(plot_title = paste0("No valid ", metric_label, " data for ", build_map_display_year_label(map_state$selected_market_year, source_choice = source_choice))))
    }

    if (identical(map_state$status, "no_mappable_data")) {
      return(build_map_empty_plot(plot_title = paste0("No map locations available for ", build_map_display_year_label(map_state$selected_market_year, source_choice = source_choice))))
    }

    if (!identical(map_state$status, "ok")) {
      return(build_map_empty_plot(plot_title = "No data available for the Map tab"))
    }

    shade_mode <- map_measure_mode()
    safe_basis_choice <- current_basis_choice_safe()
    unit_label <- get_metric_measurement_label(
      metric_code = metric_col,
      source_choice = input$data_source_choice,
      unit_choice = input$unit_choice,
      basis_choice = effective_basis_choice_for_metric(metric_col, safe_basis_choice, input$data_source_choice),
      value_unit_choice = current_census_value_unit_choice_safe(
        source_choice = input$data_source_choice,
        metric_code = metric_col
      ),
      commodity_name = input$commodity_choice,
      active_tab = input$main_tabs_panel,
      area_unit_choice = current_psd_area_unit_choice_safe()
    )
    map_unit_resolution <- resolve_map_display_unit(
      map_display = map_display,
      output_id = "map_plot",
      source_choice = source_choice,
      metric_col = metric_col
    )
    if (is.list(map_unit_resolution) && !is.null(map_unit_resolution$label) && nzchar(map_unit_resolution$label)) {
      unit_label <- map_unit_resolution$label
    }
    measurement_subtitle <- build_map_measurement_subtitle(metric_label, unit_label)
    commodity_label <- get_active_commodity_label()
    fill_label <- if (identical(display_mode, "comparison") && identical(shade_mode, "percent_change")) {
      "% Difference"
    } else if (identical(display_mode, "comparison")) {
      paste0("Difference (", unit_label, ")")
    } else if (identical(shade_mode, "share_pct")) {
      build_map_total_share_label(source_choice = source_choice)
    } else {
      paste0(metric_label, " (", unit_label, ")")
    }

    format_fill_value_label <- function(value) {
      if (identical(display_mode, "comparison") && identical(shade_mode, "percent_change")) {
        sprintf("%.1f%%", value)
      } else if (identical(display_mode, "comparison")) {
        format(round(value, 0), big.mark = ",", scientific = FALSE)
      } else if (identical(shade_mode, "share_pct")) {
        sprintf("%.1f%%", value)
      } else {
        format_map_summary_value(value, metric_code = metric_col)
      }
    }

    format_fill_range_label <- function(lower_bound, upper_bound) {
      if (isTRUE(all.equal(lower_bound, upper_bound))) {
        return(format_fill_value_label(lower_bound))
      }

      paste0(
        format_fill_value_label(lower_bound),
        " to ",
        format_fill_value_label(upper_bound)
      )
    }

    build_capped_comparison_scale <- function(values, quantile_prob = 0.9, min_cap = 1) {
      finite_values <- values[is.finite(values)]

      if (length(finite_values) == 0) {
        return(list(cap = min_cap, zmin = -min_cap, zmax = min_cap, color_values = numeric(0)))
      }

      abs_values <- abs(finite_values)
      if (length(abs_values) <= 2) {
        cap_value <- max(abs_values, na.rm = TRUE)
      } else {
        cap_value <- as.numeric(stats::quantile(abs_values, probs = quantile_prob, na.rm = TRUE, names = FALSE, type = 7))
      }

      if (!is.finite(cap_value) || cap_value <= 0) {
        cap_value <- max(abs_values, na.rm = TRUE)
      }

      if (!is.finite(cap_value) || cap_value <= 0) {
        cap_value <- min_cap
      }

      list(
        cap = cap_value,
        zmin = -cap_value,
        zmax = cap_value,
        color_values = pmax(pmin(finite_values, cap_value), -cap_value)
      )
    }

    build_comparison_colorbar_ticks <- function(scale) {
      tick_values <- c(scale$zmin, 0, scale$zmax)
      tick_values <- sort(unique(as.numeric(tick_values[is.finite(tick_values)])))

      list(
        tickvals = tick_values,
        ticktext = vapply(tick_values, format_fill_value_label, character(1))
      )
    }

    add_choropleth_layer <- function(plot_obj, data, ...) {
      if (is.null(data) || nrow(data) == 0) {
        return(plot_obj)
      }

      base_args <- c(
        list(
          data = data,
          type = "choropleth"
        ),
        list(...)
      )

      if ("hover_text" %in% names(data)) {
        hover_values <- as.character(data$hover_text)
        hover_values[is.na(hover_values)] <- ""
        base_args$hovertext <- I(hover_values)
      }

      if (is.null(plot_obj)) {
        return(do.call(plot_ly, c(list(source = "map_plot_source"), base_args)))
      }

      do.call(add_trace, c(list(plot_obj), base_args, list(inherit = FALSE)))
    }

    build_quantile_bin_map <- function(df, bin_count = 10) {
      if (nrow(df) == 0) {
        return(list(
          data = df,
          zmin = 1,
          zmax = 1,
          colorscale = list(list(0, "#2b8cbe"), list(1, "#2b8cbe")),
          tickvals = numeric(0),
          ticktext = character(0)
        ))
      }

      palette_colors <- c("#2b8cbe", "#7bccc4", "#fdae61", "#f46d43", "#d73027")
      requested_probs <- seq(0, 1, length.out = bin_count + 1)
      raw_breaks <- stats::quantile(df$fill_value, probs = requested_probs, na.rm = TRUE, names = FALSE, type = 7)
      breaks <- unique(as.numeric(raw_breaks))

      if (length(breaks) <= 1) {
        out_df <- df %>% mutate(color_bin = 1L)
        label_text <- format_fill_value_label(breaks[[1]])
        single_bin_color <- palette_colors[[length(palette_colors)]]

        return(list(
          data = out_df,
          zmin = 1,
          zmax = 1,
          colorscale = list(list(0, single_bin_color), list(1, single_bin_color)),
          tickvals = 1,
          ticktext = label_text
        ))
      }

      effective_bin_count <- length(breaks) - 1
      color_values <- cut(
        df$fill_value,
        breaks = breaks,
        include.lowest = TRUE,
        labels = FALSE,
        right = TRUE
      )
      color_values[is.na(color_values)] <- effective_bin_count

      out_df <- df %>% mutate(color_bin = as.integer(color_values))

      active_palette <- if (effective_bin_count <= length(palette_colors)) {
        palette_colors[seq_len(effective_bin_count)]
      } else {
        grDevices::colorRampPalette(palette_colors)(effective_bin_count)
      }

      colorscale <- unlist(lapply(seq_len(effective_bin_count), function(index) {
        lower_stop <- (index - 1) / effective_bin_count
        upper_stop <- index / effective_bin_count
        list(
          list(lower_stop, active_palette[[index]]),
          list(upper_stop, active_palette[[index]])
        )
      }), recursive = FALSE)

      ticktext <- vapply(seq_len(effective_bin_count), function(index) {
        format_fill_range_label(breaks[[index]], breaks[[index + 1]])
      }, character(1))

      list(
        data = out_df,
        zmin = 1,
        zmax = effective_bin_count,
        colorscale = colorscale,
        tickvals = seq_len(effective_bin_count),
        ticktext = ticktext
      )
    }

    build_rank_bucket_bin_map <- function(df, top_n_cutoff) {
      if (nrow(df) == 0) {
        return(list(
          data = df,
          zmin = 1,
          zmax = 1,
          colorscale = list(list(0, "#2b8cbe"), list(1, "#2b8cbe")),
          tickvals = numeric(0),
          ticktext = character(0)
        ))
      }

      total_bins <- if (identical(top_n_cutoff, 5L)) 6L else 11L
      palette_colors <- c("#2b8cbe", "#7bccc4", "#fdae61", "#f46d43", "#d73027")
      active_palette <- if (total_bins <= length(palette_colors)) {
        palette_colors[seq_len(total_bins)]
      } else {
        grDevices::colorRampPalette(palette_colors)(total_bins)
      }

      out_df <- df %>%
        mutate(
          color_bin = dplyr::case_when(
            .data$rank > top_n_cutoff ~ 1L,
            top_n_cutoff == 5L ~ as.integer(top_n_cutoff - .data$rank + 2L),
            top_n_cutoff == 10L ~ as.integer(top_n_cutoff - .data$rank + 2L),
            top_n_cutoff == 20L ~ as.integer(12L - ceiling(.data$rank / 2)),
            TRUE ~ 1L
          )
        )

      colorscale <- unlist(lapply(seq_len(total_bins), function(index) {
        lower_stop <- (index - 1) / total_bins
        upper_stop <- index / total_bins
        list(
          list(lower_stop, active_palette[[index]]),
          list(upper_stop, active_palette[[index]])
        )
      }), recursive = FALSE)

      tick_df <- out_df %>%
        group_by(.data$color_bin) %>%
        summarise(
          lower_bound = min(.data$fill_value, na.rm = TRUE),
          upper_bound = max(.data$fill_value, na.rm = TRUE),
          is_all_others = any(.data$rank > top_n_cutoff),
          .groups = "drop"
        ) %>%
        arrange(.data$color_bin) %>%
        mutate(
          ticktext = ifelse(
            .data$is_all_others,
            paste0("All other partners: ", mapply(format_fill_range_label, .data$lower_bound, .data$upper_bound, USE.NAMES = FALSE)),
            mapply(format_fill_range_label, .data$lower_bound, .data$upper_bound, USE.NAMES = FALSE)
          )
        )

      list(
        data = out_df,
        zmin = 1,
        zmax = total_bins,
        colorscale = colorscale,
        tickvals = tick_df$color_bin,
        ticktext = tick_df$ticktext
      )
    }

    if (identical(display_mode, "comparison")) {
      fill_label <- if (identical(shade_mode, "percent_change")) {
        "% Difference"
      } else {
        paste0("Difference (", unit_label, ")")
      }

      format_fill_value_label <- function(value) {
        if (identical(shade_mode, "percent_change")) {
          sprintf("%.1f%%", value)
        } else {
          format(round(value, 0), big.mark = ",", scientific = FALSE)
        }
      }

      full_plot_df <- map_display$ranked_df %>%
        mutate(
          fill_value = if (identical(shade_mode, "percent_change")) .data$percent_change else .data$absolute_change,
          hover_text = ifelse(
            is.finite(.data$percent_change),
            sprintf(
              "Country: %s<br>%s: %s<br>Comparison Rank: %s<br>Current Value: %s %s<br>Baseline (%s): %s %s<br>Difference: %s %s<br>%% Difference: %.1f%%",
              .data$country_label,
              build_map_display_year_field_label(source_choice = source_choice),
              map_state$selected_market_year,
              .data$rank,
              format(round(.data$current_value, 0), big.mark = ",", scientific = FALSE),
              unit_label,
              map_state$baseline_label,
              format(round(.data$baseline_value, 0), big.mark = ",", scientific = FALSE),
              unit_label,
              format(round(.data$absolute_change, 0), big.mark = ",", scientific = FALSE),
              unit_label,
              .data$percent_change
            ),
            sprintf(
              "Country: %s<br>%s: %s<br>Comparison Rank: %s<br>Current Value: %s %s<br>Baseline (%s): %s %s<br>Difference: %s %s<br>%% Difference: unavailable (baseline is zero or missing)",
              .data$country_label,
              build_map_display_year_field_label(source_choice = source_choice),
              map_state$selected_market_year,
              .data$rank,
              format(round(.data$current_value, 0), big.mark = ",", scientific = FALSE),
              unit_label,
              map_state$baseline_label,
              format(round(.data$baseline_value, 0), big.mark = ",", scientific = FALSE),
              unit_label,
              format(round(.data$absolute_change, 0), big.mark = ",", scientific = FALSE),
              unit_label
            )
          )
        )

      emphasis_df <- map_display$emphasis_ranked_df
      if (!("map_location" %in% names(emphasis_df))) {
        emphasis_df <- data.frame(
          map_location = character(),
          emphasis_rank = numeric(),
          stringsAsFactors = FALSE
        )
      } else if (!("emphasis_rank" %in% names(emphasis_df))) {
        emphasis_df <- emphasis_df %>% mutate(emphasis_rank = NA_real_)
      }
      emphasis_df <- emphasis_df %>%
        select(map_location, emphasis_rank)

      if ("emphasis_rank" %in% names(full_plot_df)) {
        full_plot_df <- full_plot_df %>% select(-emphasis_rank)
      }

      full_plot_df <- full_plot_df %>%
        left_join(emphasis_df, by = "map_location")

      if (!("emphasis_rank" %in% names(full_plot_df))) {
        full_plot_df$emphasis_rank <- Inf
      } else {
        full_plot_df$emphasis_rank[is.na(full_plot_df$emphasis_rank)] <- Inf
      }

      full_plot_df <- full_plot_df %>%
        mutate(
          is_emphasized = if (is.null(top_n_cutoff)) TRUE else .data$emphasis_rank <= top_n_cutoff,
          comparison_available = is.finite(.data$fill_value)
        )

      shaded_key_df <- map_display$display_df %>%
        select(map_location) %>%
        distinct()

      plot_df <- if (is.null(top_n_cutoff)) {
        full_plot_df
      } else {
        full_plot_df %>%
          semi_join(shaded_key_df, by = "map_location")
      }

      context_df <- if (is.null(top_n_cutoff)) {
        full_plot_df[0, , drop = FALSE]
      } else {
        full_plot_df %>%
          anti_join(shaded_key_df, by = "map_location") %>%
          mutate(layer_z = 1L)
      }

      neutral_df <- plot_df %>%
        filter(!.data$comparison_available) %>%
        mutate(layer_z = 1L)

      colored_df <- plot_df %>%
        filter(.data$is_emphasized, .data$comparison_available)

      top_five_df <- plot_df %>%
        filter(.data$emphasis_rank <= 5) %>%
        mutate(layer_z = 1L)

      selected_country_df <- if (!is.null(map_selected_country())) {
        full_plot_df %>%
          filter(.data$selected_country_key == map_selected_country()) %>%
          mutate(layer_z = 1L)
      } else {
        full_plot_df[0, , drop = FALSE]
      }

      comparison_scale <- build_capped_comparison_scale(colored_df$fill_value, quantile_prob = 0.9)
      comparison_colorbar_ticks <- build_comparison_colorbar_ticks(comparison_scale)
      colored_df <- colored_df %>%
        mutate(
          comparison_color_value = pmax(pmin(.data$fill_value, comparison_scale$cap), -comparison_scale$cap)
        )

      comparison_colorscale <- list(
        list(0, "#2166ac"),
        list(0.5, "#f7f7f7"),
        list(1, "#b2182b")
      )

      map_plot <- NULL
      map_plot <- add_choropleth_layer(
        map_plot,
        context_df,
        locations = ~map_location,
        locationmode = "country names",
        z = ~layer_z,
        customdata = ~selected_country_key,
        hovertext = ~hover_text,
        hovertemplate = "%{hovertext}<extra></extra>",
        colorscale = list(list(0, "#d0d5dd"), list(1, "#d0d5dd")),
        zmin = 0,
        zmax = 1,
        showscale = FALSE,
        marker = list(line = list(color = "#ffffff", width = 0.5)),
        showlegend = FALSE,
        name = "neutral_context"
      )
      map_plot <- add_choropleth_layer(
        map_plot,
        neutral_df,
        locations = ~map_location,
        locationmode = "country names",
        z = ~layer_z,
        customdata = ~selected_country_key,
        hovertext = ~hover_text,
        hovertemplate = "%{hovertext}<extra></extra>",
        colorscale = list(list(0, "#d0d5dd"), list(1, "#d0d5dd")),
        zmin = 0,
        zmax = 1,
        showscale = FALSE,
        marker = list(line = list(color = "#ffffff", width = 0.5)),
        showlegend = FALSE,
        name = "comparison_unavailable"
      )
      map_plot <- add_choropleth_layer(
        map_plot,
        colored_df,
        locations = ~map_location,
        locationmode = "country names",
        z = ~comparison_color_value,
        customdata = ~selected_country_key,
        hovertext = ~hover_text,
        hovertemplate = "%{hovertext}<extra></extra>",
        colorscale = comparison_colorscale,
        zmin = comparison_scale$zmin,
        zmax = comparison_scale$zmax,
        marker = list(line = list(color = "#ffffff", width = 0.5)),
        colorbar = list(
          title = fill_label,
          x = 0.985,
          len = 0.78,
          thickness = 16,
          tickmode = "array",
          tickvals = comparison_colorbar_ticks$tickvals,
          ticktext = comparison_colorbar_ticks$ticktext
        ),
        showlegend = FALSE,
        name = "comparison_colored"
      )
      map_plot <- add_choropleth_layer(
        map_plot,
        top_five_df,
        locations = ~map_location,
        locationmode = "country names",
        z = ~layer_z,
        customdata = ~selected_country_key,
        hovertext = ~hover_text,
        hovertemplate = "%{hovertext}<extra></extra>",
        colorscale = list(list(0, "rgba(0,0,0,0)"), list(1, "rgba(0,0,0,0)")),
        zmin = 0,
        zmax = 1,
        showscale = FALSE,
        marker = list(line = list(color = "#0f172a", width = 2.2)),
        showlegend = FALSE,
        name = "top_five_outline"
      )
      map_plot <- add_choropleth_layer(
        map_plot,
        selected_country_df,
        locations = ~map_location,
        locationmode = "country names",
        z = ~layer_z,
        customdata = ~selected_country_key,
        hovertext = ~hover_text,
        hovertemplate = "%{hovertext}<extra></extra>",
        colorscale = list(
          list(0, "rgba(255, 235, 59, 0.55)"),
          list(1, "rgba(255, 235, 59, 0.55)")
        ),
        zmin = 0,
        zmax = 1,
        showscale = FALSE,
        marker = list(line = list(color = "#111827", width = 5)),
        showlegend = FALSE,
        name = "selected_country"
      )

      return(
        map_plot %>%
          layout(
            title = paste0(
              metric_label,
              " - ",
              commodity_label,
              " - ",
              build_map_display_year_label(map_state$selected_market_year, source_choice = source_choice),
              "<br><sup>",
              measurement_subtitle,
              "</sup>"
            ),
            geo = list(
              domain = list(x = c(0.02, 0.93), y = c(0.02, 0.96)),
              scope = "world",
              projection = list(type = "natural earth"),
              lataxis = list(range = c(-58, 85)),
              showframe = FALSE,
              showcoastlines = TRUE,
              showcountries = TRUE,
              countrycolor = "#ffffff",
              showland = TRUE,
              landcolor = "#e9ecef",
              bgcolor = "rgba(0,0,0,0)"
            ),
            xaxis = list(visible = FALSE, showgrid = FALSE, zeroline = FALSE),
            yaxis = list(visible = FALSE, showgrid = FALSE, zeroline = FALSE),
            margin = list(t = 80, b = 0, l = 0, r = 0)
          ) %>%
          finalize_map_plot()
      )
    }

    full_plot_df <- map_display$ranked_df %>%
      mutate(
        fill_value = if (identical(shade_mode, "share_pct")) .data$share_pct * 100 else .data$quantity_value,
        hover_text = if (identical(shade_mode, "share_pct")) {
          sprintf(
            "Country: %s<br>%s: %s<br>Rank: %s<br>%s: %.1f%%",
            .data$country_label,
            build_map_display_year_field_label(source_choice = source_choice),
            map_state$selected_market_year,
            .data$rank,
            sub(" \\(\\%\\)$", "", build_map_total_share_label(source_choice = source_choice)),
            .data$share_pct * 100
          )
        } else {
          sprintf(
            "Country: %s<br>%s: %s<br>Rank: %s<br>%s: %s %s",
            .data$country_label,
            build_map_display_year_field_label(source_choice = source_choice),
            map_state$selected_market_year,
            .data$rank,
            metric_label,
            format_map_summary_value(.data$quantity_value, metric_code = metric_col),
            unit_label
          )
        }
      )

    shaded_key_df <- map_display$display_df %>%
      select(map_location) %>%
      distinct()

    plot_df <- if (is.null(top_n_cutoff)) {
      full_plot_df
    } else {
      full_plot_df %>%
        semi_join(shaded_key_df, by = "map_location")
    }

    context_df <- if (is.null(top_n_cutoff)) {
      full_plot_df[0, , drop = FALSE]
    } else {
      full_plot_df %>%
        anti_join(shaded_key_df, by = "map_location") %>%
        mutate(layer_z = 1L)
    }

    zero_trade_df <- plot_df %>%
      filter(.data$quantity_value <= 0) %>%
      mutate(layer_z = .data$fill_value)

    positive_trade_df <- plot_df %>%
      filter(.data$quantity_value > 0)

    positive_trade_color_map <- build_quantile_bin_map(positive_trade_df, bin_count = 10)
    positive_trade_df <- positive_trade_color_map$data

    top_five_df <- positive_trade_df %>%
      arrange(.data$rank) %>%
      slice_head(n = 5) %>%
      mutate(layer_z = 1L)

    selected_country_df <- if (!is.null(map_selected_country())) {
      full_plot_df %>%
        filter(.data$selected_country_key == map_selected_country()) %>%
        mutate(layer_z = 1L)
    } else {
      full_plot_df[0, , drop = FALSE]
    }

    map_plot <- NULL
    map_plot <- add_choropleth_layer(
      map_plot,
      context_df,
      locations = ~map_location,
      locationmode = "country names",
      z = ~layer_z,
      customdata = ~selected_country_key,
      hovertext = ~hover_text,
      hovertemplate = "%{hovertext}<extra></extra>",
      colorscale = list(list(0, "#d0d5dd"), list(1, "#d0d5dd")),
      zmin = 0,
      zmax = 1,
      showscale = FALSE,
      marker = list(line = list(color = "#ffffff", width = 0.5)),
      showlegend = FALSE,
      name = "neutral_context"
    )
    map_plot <- add_choropleth_layer(
      map_plot,
      zero_trade_df,
      locations = ~map_location,
      locationmode = "country names",
      z = ~layer_z,
      customdata = ~selected_country_key,
      hovertext = ~hover_text,
      hovertemplate = "%{hovertext}<extra></extra>",
      colorscale = list(list(0, "#d0d5dd"), list(1, "#d0d5dd")),
      zmin = 0,
      zmax = 1,
      showscale = FALSE,
      marker = list(line = list(color = "#ffffff", width = 0.5)),
      showlegend = FALSE,
      name = "zero_trade"
    )
    map_plot <- add_choropleth_layer(
      map_plot,
      positive_trade_df,
      locations = ~map_location,
      locationmode = "country names",
      z = ~color_bin,
      customdata = ~selected_country_key,
      hovertext = ~hover_text,
      hovertemplate = "%{hovertext}<extra></extra>",
      colorscale = positive_trade_color_map$colorscale,
      zmin = positive_trade_color_map$zmin,
      zmax = positive_trade_color_map$zmax,
      marker = list(line = list(color = "#ffffff", width = 0.5)),
      colorbar = list(
        title = fill_label,
        x = 0.985,
        len = 0.78,
        thickness = 16,
        tickmode = "array",
        tickvals = positive_trade_color_map$tickvals,
        ticktext = positive_trade_color_map$ticktext
      ),
      showlegend = FALSE,
      name = "current_colored"
    )
    map_plot <- add_choropleth_layer(
      map_plot,
      top_five_df,
      locations = ~map_location,
      locationmode = "country names",
      z = ~layer_z,
      customdata = ~selected_country_key,
      hovertext = ~hover_text,
      hovertemplate = "%{hovertext}<extra></extra>",
      colorscale = list(list(0, "rgba(0,0,0,0)"), list(1, "rgba(0,0,0,0)")),
      zmin = 0,
      zmax = 1,
      showscale = FALSE,
      marker = list(line = list(color = "#0f172a", width = 2.2)),
      showlegend = FALSE,
      name = "top_five_outline"
    )
    map_plot <- add_choropleth_layer(
      map_plot,
      selected_country_df,
      locations = ~map_location,
      locationmode = "country names",
      z = ~layer_z,
      customdata = ~selected_country_key,
      hovertext = ~hover_text,
      hovertemplate = "%{hovertext}<extra></extra>",
      colorscale = list(
        list(0, "rgba(255, 235, 59, 0.55)"),
        list(1, "rgba(255, 235, 59, 0.55)")
      ),
      zmin = 0,
      zmax = 1,
      showscale = FALSE,
      marker = list(line = list(color = "#111827", width = 5)),
      showlegend = FALSE,
      name = "selected_country"
    )

    map_plot %>%
      layout(
        title = paste0(
          metric_label,
          " - ",
          commodity_label,
          " - ",
          build_map_display_year_label(map_state$selected_market_year, source_choice = source_choice),
          "<br><sup>",
          measurement_subtitle,
          "</sup>"
        ),
        geo = list(
          domain = list(x = c(0.02, 0.93), y = c(0.02, 0.96)),
          scope = "world",
          projection = list(type = "natural earth"),
          lataxis = list(range = c(-58, 85)),
          showframe = FALSE,
          showcoastlines = TRUE,
          showcountries = TRUE,
          countrycolor = "#ffffff",
          showland = TRUE,
          landcolor = "#e9ecef",
          bgcolor = "rgba(0,0,0,0)"
        ),
            xaxis = list(visible = FALSE, showgrid = FALSE, zeroline = FALSE),
            yaxis = list(visible = FALSE, showgrid = FALSE, zeroline = FALSE),
        xaxis = list(visible = FALSE, showgrid = FALSE, zeroline = FALSE),
        yaxis = list(visible = FALSE, showgrid = FALSE, zeroline = FALSE),
        margin = list(t = 80, b = 0, l = 0, r = 0)
      ) %>%
      finalize_map_plot()
  })

  output$map_note_block <- renderUI({
    source_choice <- current_source_choice_safe(default = input$data_source_choice %||% "export_sales")
    map_state <- map_country_dataset()
    if (identical(map_comparison_mode(), "comparison")) {
      map_state <- map_comparison_dataset()
    }
    display_mode <- map_comparison_mode()
    top_n_cutoff <- map_top_n_cutoff()
    shade_mode <- map_measure_mode()
    metric_label <- get_active_metric_label(map_state$metric_col)
    safe_basis_choice <- current_basis_choice_safe()
    unit_label <- get_metric_measurement_label(
      metric_code = map_state$metric_col,
      source_choice = source_choice,
      unit_choice = input$unit_choice,
      basis_choice = effective_basis_choice_for_metric(map_state$metric_col, safe_basis_choice, source_choice),
      value_unit_choice = current_census_value_unit_choice_safe(
        source_choice = source_choice,
        metric_code = map_state$metric_col
      ),
      commodity_name = input$commodity_choice,
      active_tab = input$main_tabs_panel,
      area_unit_choice = current_psd_area_unit_choice_safe()
    )
    map_note_unit_resolution <- resolve_map_display_unit(
      map_display = list(mode = display_mode, map_state = map_state),
      output_id = "map_note_block",
      source_choice = source_choice,
      metric_col = map_state$metric_col
    )
    if (is.list(map_note_unit_resolution) && !is.null(map_note_unit_resolution$label) && nzchar(map_note_unit_resolution$label)) {
      unit_label <- map_note_unit_resolution$label
    }
    map_unit_warning_note <- map_unit_guardrail_warning_text(map_note_unit_resolution)
    warning_note <- get_product_weight_basis_note(input$commodity_choice, safe_basis_choice)

    if (identical(map_state$status, "comparison_metric_ineligible")) {
      return(
        tags$p(
          tags$em(paste0(metric_label, " does not support historical comparison in the Map tab. Choose an accumulated metric to enable Historical Comparison.")),
          if (!is.null(warning_note)) list(tags$br(), warning_note)
        )
      )
    }

    if (identical(map_state$status, "unsupported_metric")) {
      return(
        tags$p(
          tags$em(paste0("Map unavailable: ", metric_label, " is not available in the selected source or frequency context.")),
          if (!is.null(warning_note)) list(tags$br(), warning_note)
        )
      )
    }

    if (identical(map_state$status, "no_year_data")) {
      return(
        tags$p(
          tags$em(paste0("No valid ", metric_label, " values were available for ", build_map_display_year_label(map_state$selected_market_year), " after applying the current filters.")),
          if (!is.null(warning_note)) list(tags$br(), warning_note)
        )
      )
    }

    if (identical(map_state$status, "no_mappable_data")) {
      return(
        tags$p(
          tags$em("The selected data produced rows, but none mapped cleanly to the current world choropleth geography."),
          if (length(map_state$unmatched_labels) > 0) list(
            tags$br(),
            paste0("Unmapped countries: ", paste(head(map_state$unmatched_labels, 8), collapse = ", ")),
            if (length(map_state$unmatched_labels) > 8) paste0(", and ", length(map_state$unmatched_labels) - 8, " more") else ""
          ),
          if (!is.null(warning_note)) list(tags$br(), warning_note)
        )
      )
    }

    if (identical(map_state$status, "no_baseline_data")) {
      return(
        tags$p(
          tags$em("No valid historical baseline was available for the selected comparison settings."),
          if (!is.null(warning_note)) list(tags$br(), warning_note)
        )
      )
    }

    map_trade_flow <- effective_trade_flow_for_source(
      source_choice = source_choice,
      trade_flow_value = input$census_trade_flow_choice,
      vp_trade_flow_value = input$vp_trade_flow_choice
    )

    source_note <- if (source_choice %in% c("vp_trade", "census", "census_import", "hybrid", "hybrid_import")) {
      if (identical(map_trade_flow, "import")) {
        "Data are from the U.S. Census Bureau and reflect U.S. imports by country of origin."
      } else {
        "Data are from the U.S. Census Bureau and reflect U.S. exports by destination country."
      }
    } else {
      NULL
    }

    mode_note <- if (identical(display_mode, "comparison")) {
      if (identical(shade_mode, "percent_change")) {
        '"Historical Comparison" Mode shades countries by percent difference versus the selected baseline.'
      } else {
        paste0('"Historical Comparison" Mode shades countries by difference versus the selected baseline in ', unit_label, ".")
      }
    } else if (identical(shade_mode, "share_pct")) {
      paste0('"Current Level" Display Mode shades countries by share of the selected ', build_map_display_year_descriptor(input$data_source_choice %||% "export_sales"), ' total.')
    } else {
      paste0('"Current Level" Display Mode shades countries by current ', metric_label, " in ", unit_label, ".")
    }

    top_n_note <- if (identical(display_mode, "comparison")) {
      if (is.null(top_n_cutoff)) {
        "Shade top 5/10/20 limits comparison shading and ranking to the current-level top countries for the active metric; all other countries remain neutral context on the map and selectable."
      } else {
        paste0(
          "Shade top ",
          top_n_cutoff,
          " only is active: only those current-level top countries are shaded and ranked in the comparison view; all other countries remain neutral context and selectable."
        )
      }
    } else {
      if (is.null(top_n_cutoff)) {
        "Shade top 5/10/20 limits shading and ranking to the current-level top countries for the active variable; all other countries remain neutral context on the map and selectable."
      } else {
        paste0(
          "Shade top ",
          top_n_cutoff,
          " only is active: only those current-level top countries are shaded and ranked; all other countries remain neutral context and selectable."
        )
      }
    }

    unmapped_note <- if (length(map_state$unmatched_labels) > 0) {
      paste0(
        "Unmapped countries remain available in the PSD Map tables: ",
        paste(head(map_state$unmatched_labels, 8), collapse = ", "),
        if (length(map_state$unmatched_labels) > 8) paste0(", and ", length(map_state$unmatched_labels) - 8, " more") else "",
        "."
      )
    } else {
      NULL
    }

    primary_map_note <- if (!is.null(source_note) && nzchar(trimws(source_note))) {
      paste(source_note, mode_note)
    } else {
      mode_note
    }

    info_entries <- Filter(Negate(is.null), list(
      if (is_psd_effective_map_tab_active()) tags$em(psd_world_map_coverage_note()) else NULL,
      if (is_psd_effective_map_tab_active()) tags$em(psd_world_map_rollup_note()) else NULL,
      tags$em(paste0("Note: ", primary_map_note)),
      if (identical(display_mode, "comparison")) tags$em("The comparison color scale is capped to reduce distortion from extreme changes.") else NULL,
      tags$em(top_n_note),
      if (is_psd_effective_map_tab_active()) tags$em(unmapped_note) else NULL,
      build_weekly_axis_label_note(),
      if (identical(display_mode, "comparison")) tags$em(paste0(map_state$baseline_label, " is used as the historical comparison baseline.")) else NULL
    ))

    warning_entries <- Filter(Negate(is.null), list(
      if (is_psd_effective_map_tab_active()) tags$em(psd_world_map_conflict_note()) else NULL,
      if (!is.null(map_unit_warning_note)) tags$em(map_unit_warning_note) else NULL,
      warning_note
    ))

    build_note_paragraph(
      info_entries = info_entries,
      warning_entries = warning_entries
    )
  })

  normalize_psd_table_value_digits <- function(value) {
    if (is.null(value) || length(value) == 0L) {
      return(NA_integer_)
    }

    value <- suppressWarnings(as.integer(value[[1]]))
    if (is.na(value)) {
      return(NA_integer_)
    }

    max(psd_table_value_digits_min, min(psd_table_value_digits_max, value))
  }

  psd_table_value_digits_for_formatter <- function(value) {
    value_digits <- normalize_psd_table_value_digits(value)
    if (is.na(value_digits)) NULL else value_digits
  }

  psd_table_value_digits_cache_key <- function(value) {
    value_digits <- normalize_psd_table_value_digits(value)
    if (is.na(value_digits)) "auto" else value_digits
  }

  increase_psd_table_value_digits <- function(value) {
    value_digits <- normalize_psd_table_value_digits(value)
    if (is.na(value_digits)) {
      return(psd_table_value_digits_min)
    }

    min(psd_table_value_digits_max, value_digits + 1L)
  }

  decrease_psd_table_value_digits <- function(value) {
    value_digits <- normalize_psd_table_value_digits(value)
    if (is.na(value_digits)) {
      return(psd_table_value_digits_min)
    }

    max(psd_table_value_digits_min, value_digits - 1L)
  }

  render_psd_table_value_digits_label <- function(value) {
    value_digits <- normalize_psd_table_value_digits(value)
    if (is.na(value_digits)) "Decimals: Auto" else paste0("Decimals: ", value_digits)
  }

  observeEvent(input$non_psd_map_summary_digits_decrease, {
    non_psd_map_summary_value_digits(decrease_psd_table_value_digits(isolate(non_psd_map_summary_value_digits())))
  }, ignoreInit = TRUE)

  observeEvent(input$non_psd_map_summary_digits_increase, {
    non_psd_map_summary_value_digits(increase_psd_table_value_digits(isolate(non_psd_map_summary_value_digits())))
  }, ignoreInit = TRUE)

  observeEvent(input$non_psd_map_summary_digits_auto, {
    non_psd_map_summary_value_digits(NA_integer_)
  }, ignoreInit = TRUE)

  observeEvent(input$psd_map_summary_digits_decrease, {
    psd_map_summary_value_digits(decrease_psd_table_value_digits(isolate(psd_map_summary_value_digits())))
  }, ignoreInit = TRUE)

  observeEvent(input$psd_map_summary_digits_increase, {
    psd_map_summary_value_digits(increase_psd_table_value_digits(isolate(psd_map_summary_value_digits())))
  }, ignoreInit = TRUE)

  observeEvent(input$psd_map_summary_digits_auto, {
    psd_map_summary_value_digits(NA_integer_)
  }, ignoreInit = TRUE)

  observeEvent(input$psd_map_matrix_digits_decrease, {
    psd_map_matrix_value_digits(decrease_psd_table_value_digits(isolate(psd_map_matrix_value_digits())))
  }, ignoreInit = TRUE)

  observeEvent(input$psd_map_matrix_digits_increase, {
    psd_map_matrix_value_digits(increase_psd_table_value_digits(isolate(psd_map_matrix_value_digits())))
  }, ignoreInit = TRUE)

  observeEvent(input$psd_map_matrix_digits_auto, {
    psd_map_matrix_value_digits(NA_integer_)
  }, ignoreInit = TRUE)

  observeEvent(input$psd_time_series_summary_digits_decrease, {
    psd_time_series_summary_value_digits(decrease_psd_table_value_digits(isolate(psd_time_series_summary_value_digits())))
  }, ignoreInit = TRUE)

  observeEvent(input$psd_time_series_summary_digits_increase, {
    psd_time_series_summary_value_digits(increase_psd_table_value_digits(isolate(psd_time_series_summary_value_digits())))
  }, ignoreInit = TRUE)

  observeEvent(input$psd_time_series_summary_digits_auto, {
    psd_time_series_summary_value_digits(NA_integer_)
  }, ignoreInit = TRUE)

  observeEvent(input$psd_historical_records_digits_decrease, {
    psd_historical_records_value_digits(decrease_psd_table_value_digits(isolate(psd_historical_records_value_digits())))
  }, ignoreInit = TRUE)

  observeEvent(input$psd_historical_records_digits_increase, {
    psd_historical_records_value_digits(increase_psd_table_value_digits(isolate(psd_historical_records_value_digits())))
  }, ignoreInit = TRUE)

  observeEvent(input$psd_historical_records_digits_auto, {
    psd_historical_records_value_digits(NA_integer_)
  }, ignoreInit = TRUE)

  observeEvent(input$psd_prior_comparison_digits_decrease, {
    psd_prior_comparison_value_digits(decrease_psd_table_value_digits(isolate(psd_prior_comparison_value_digits())))
  }, ignoreInit = TRUE)

  observeEvent(input$psd_prior_comparison_digits_increase, {
    psd_prior_comparison_value_digits(increase_psd_table_value_digits(isolate(psd_prior_comparison_value_digits())))
  }, ignoreInit = TRUE)

  observeEvent(input$psd_prior_comparison_digits_auto, {
    psd_prior_comparison_value_digits(NA_integer_)
  }, ignoreInit = TRUE)

  observeEvent(input$wasde_prior_comparison_digits_decrease, {
    wasde_prior_comparison_value_digits(decrease_psd_table_value_digits(isolate(wasde_prior_comparison_value_digits())))
  }, ignoreInit = TRUE)

  observeEvent(input$wasde_prior_comparison_digits_increase, {
    wasde_prior_comparison_value_digits(increase_psd_table_value_digits(isolate(wasde_prior_comparison_value_digits())))
  }, ignoreInit = TRUE)

  observeEvent(input$wasde_prior_comparison_digits_auto, {
    wasde_prior_comparison_value_digits(NA_integer_)
  }, ignoreInit = TRUE)

  output$psd_map_summary_digits_display <- renderText({
    render_psd_table_value_digits_label(psd_map_summary_value_digits())
  })

  output$non_psd_map_summary_digits_display <- renderText({
    render_psd_table_value_digits_label(non_psd_map_summary_value_digits())
  })

  output$psd_map_matrix_digits_display <- renderText({
    render_psd_table_value_digits_label(psd_map_matrix_value_digits())
  })

  output$psd_time_series_summary_digits_display <- renderText({
    render_psd_table_value_digits_label(psd_time_series_summary_value_digits())
  })

  output$psd_historical_records_digits_display <- renderText({
    render_psd_table_value_digits_label(psd_historical_records_value_digits())
  })

  output$psd_prior_comparison_digits_display <- renderText({
    render_psd_table_value_digits_label(psd_prior_comparison_value_digits())
  })

  output$wasde_prior_comparison_digits_display <- renderText({
    render_psd_table_value_digits_label(wasde_prior_comparison_value_digits())
  })

  psd_table_decimal_controls <- function(decrease_id, increase_id, auto_id, display_id, table_label) {
    div(
      style = "display: flex; align-items: center; gap: 6px; flex-wrap: wrap; margin-bottom: 8px;",
      actionButton(
        inputId = decrease_id,
        label = NULL,
        icon = icon("minus"),
        class = "btn-default btn-sm",
        title = paste("Decrease", table_label, "decimals"),
        `aria-label` = paste("Decrease", table_label, "decimals")
      ),
      actionButton(
        inputId = increase_id,
        label = NULL,
        icon = icon("plus"),
        class = "btn-default btn-sm",
        title = paste("Increase", table_label, "decimals"),
        `aria-label` = paste("Increase", table_label, "decimals")
      ),
      actionButton(
        inputId = auto_id,
        label = NULL,
        icon = icon("undo"),
        class = "btn-default btn-sm",
        title = paste("Restore default", table_label, "decimals"),
        `aria-label` = paste("Restore default", table_label, "decimals")
      ),
      span(
        textOutput(display_id, inline = TRUE),
        style = "font-size: 12px; color: #555; margin-left: 4px;"
      )
    )
  }

  psd_map_summary_output_id_for_mode <- function(mode) {
    if (identical(mode, "comparison")) {
      "psd_map_summary_table_comparison"
    } else {
      "psd_map_summary_table_current"
    }
  }

  non_psd_map_summary_output_id_for_mode <- function(mode) {
    if (identical(mode, "comparison")) {
      "non_psd_map_summary_table_comparison"
    } else {
      "non_psd_map_summary_table_current"
    }
  }

  output$map_bottom_panel_ui <- renderUI({
    source_choice <- current_source_choice_safe(default = input$data_source_choice %||% "export_sales")
    transition_state <- tryCatch(current_psd_source_transition_state(), error = function(e) NULL)
    render_epoch <- source_switch_epoch_id()
    surface_refresh_generation <- map_surface_refresh_nonce()
    bottom_active <- isTRUE(tryCatch(is_effective_map_tab_active(source_choice = source_choice), error = function(e) FALSE)) ||
      (!is.null(transition_state) && identical(transition_state$tab, "Map"))
    is_psd_map_bottom <- identical(source_choice, "psd") || (!is.null(transition_state) && identical(transition_state$tab, "Map"))
    bottom_display_mode <- tryCatch(map_comparison_mode(), error = function(e) NULL)
    bottom_summary_output_id <- if (is_psd_map_bottom) {
      psd_map_summary_output_id_for_mode(bottom_display_mode)
    } else {
      non_psd_map_summary_output_id_for_mode(bottom_display_mode)
    }
    bottom_rendered_builder <- if (is_psd_map_bottom) "psd" else "non_psd"
    bottom_shell <- function(rendered_builder, ...) {
      rendered_profile <- if (identical(rendered_builder, "psd")) "psd" else "non_psd"
      div(
        class = paste0("map-bottom-panel-shell map-bottom-panel-shell-", rendered_profile),
        `data-source-profile` = rendered_profile,
        `data-source-epoch` = render_epoch %||% "",
        `data-rendered-builder` = rendered_builder,
        `data-rendered-surface` = "map_bottom_panel",
        ...
      )
    }

    if (exists("psd_transition_debug_enabled", mode = "function") && isTRUE(psd_transition_debug_enabled())) {
      raw_transition_state <- tryCatch(isolate(psd_source_transition_state()), error = function(...) NULL)
      psd_transition_trace(
        event = "map_bottom_panel_render",
        reason = "map_bottom_panel_ui",
        details = list(
          raw_source = input$data_source_choice %||% NULL,
          safe_source = source_choice,
          raw_tab = input$main_tabs_panel %||% NULL,
          safe_tab = tryCatch(current_main_tab_safe(), error = function(...) NULL),
          raw_transition_active = tryCatch(as.character(isTRUE(isolate(psd_source_transition_active()))), error = function(...) "FALSE"),
          raw_transition_tab = if (is.null(raw_transition_state)) NULL else raw_transition_state$tab,
          current_transition_tab = if (is.null(transition_state)) NULL else transition_state$tab,
          map_display_mode = bottom_display_mode,
          summary_output_id = bottom_summary_output_id,
          returned_bottom = bottom_rendered_builder
        ),
        dedupe_key = "map_bottom_panel_render",
        dedupe_signature = build_transition_trace_signature(list(
          safe_source = source_choice,
          raw_tab = input$main_tabs_panel %||% NULL,
          current_transition_tab = if (is.null(transition_state)) NULL else transition_state$tab,
          map_display_mode = bottom_display_mode,
          summary_output_id = bottom_summary_output_id,
          returned_bottom = bottom_rendered_builder
        ))
      )
    }

    if (!bottom_active) {
      record_cache_body_execution(session, "map_bottom_panel_ui_gated_skip")
      if (exists("psd_transition_debug_enabled", mode = "function") && isTRUE(psd_transition_debug_enabled())) {
        raw_transition_state <- tryCatch(isolate(psd_source_transition_state()), error = function(...) NULL)
        psd_transition_trace(
          event = "map_bottom_panel_render",
          reason = "map_bottom_panel_ui",
          details = list(
            raw_source = input$data_source_choice %||% NULL,
            safe_source = source_choice,
            raw_tab = input$main_tabs_panel %||% NULL,
            safe_tab = tryCatch(current_main_tab_safe(), error = function(...) NULL),
            raw_transition_active = tryCatch(as.character(isTRUE(isolate(psd_source_transition_active()))), error = function(...) "FALSE"),
            raw_transition_tab = if (is.null(raw_transition_state)) NULL else raw_transition_state$tab,
            current_transition_tab = if (is.null(transition_state)) NULL else transition_state$tab,
            map_display_mode = bottom_display_mode,
            summary_output_id = NULL,
            returned_bottom = NULL,
            outcome = "returned_null"
          ),
          dedupe_key = "map_bottom_panel_render_inactive",
          dedupe_signature = build_transition_trace_signature(list(
            safe_source = source_choice,
            raw_tab = input$main_tabs_panel %||% NULL,
            current_transition_tab = if (is.null(transition_state)) NULL else transition_state$tab,
            map_display_mode = bottom_display_mode,
            outcome = "returned_null"
          ))
        )
      }

      return(NULL)
    }

    record_cache_body_execution(session, "map_bottom_panel_ui_executed")

    if (is_psd_map_bottom) {
      selected_view <- if (!is.null(psd_map_bottom_view_state()) && psd_map_bottom_view_state() %in% c("matrix", "summary")) {
        psd_map_bottom_view_state()
      } else {
        "summary"
      }

      return(
        bottom_shell(
          "psd",
          tabsetPanel(
            id = "psd_map_bottom_view",
            type = "tabs",
            selected = selected_view,
            tabPanel(
              title = "Map Summary Table",
              value = "summary",
              div(
                style = "padding-top: 10px;",
                `data-psd-summary-schema` = if (identical(map_comparison_mode(), "comparison")) "comparison" else "current",
                psd_table_decimal_controls(
                  decrease_id = "psd_map_summary_digits_decrease",
                  increase_id = "psd_map_summary_digits_increase",
                  auto_id = "psd_map_summary_digits_auto",
                  display_id = "psd_map_summary_digits_display",
                  table_label = "PSD map summary table"
                ),
                div(
                  class = "psd-map-summary-table-output",
                  dataTableOutput(psd_map_summary_output_id_for_mode(map_comparison_mode()))
                )
              )
            ),
            tabPanel(
              title = "Market Year Comparison Table",
              value = "matrix",
              div(
                style = "padding-top: 10px;",
                psd_table_decimal_controls(
                  decrease_id = "psd_map_matrix_digits_decrease",
                  increase_id = "psd_map_matrix_digits_increase",
                  auto_id = "psd_map_matrix_digits_auto",
                  display_id = "psd_map_matrix_digits_display",
                  table_label = "PSD market year comparison table"
                ),
                tags$p(tags$em(psd_matrix_country_coverage_note())),
                dataTableOutput("psd_map_matrix_table")
              )
            )
          )
        )
      )
    }

    bottom_shell(
      "non_psd",
      tagList(
        h3(style = "margin-top: 0; margin-bottom: 10px;", "Map Summary Table"),
        psd_table_decimal_controls(
          decrease_id = "non_psd_map_summary_digits_decrease",
          increase_id = "non_psd_map_summary_digits_increase",
          auto_id = "non_psd_map_summary_digits_auto",
          display_id = "non_psd_map_summary_digits_display",
          table_label = "map summary table"
        ),
        div(
          class = "non-psd-map-summary-table-output",
          `data-non-psd-summary-schema` = if (identical(map_comparison_mode(), "comparison")) "comparison" else "current",
          dataTableOutput(non_psd_map_summary_output_id_for_mode(map_comparison_mode()))
        )
      )
    )
  })

  outputOptions(output, "map_bottom_panel_ui", suspendWhenHidden = TRUE)

  display_value_digits <- function(value, min_significant_digits = 3L) {
    numeric_value <- suppressWarnings(as.numeric(value))
    digits <- rep(0L, length(numeric_value))
    finite_nonzero <- is.finite(numeric_value) & !is.na(numeric_value) & numeric_value != 0

    digits[finite_nonzero] <- pmax(
      0L,
      as.integer(min_significant_digits) - 1L - floor(log10(abs(numeric_value[finite_nonzero])))
    )

    digits
  }

  format_significant_display_value <- function(value, min_significant_digits = 3L, blank_for_na = FALSE) {
    numeric_value <- suppressWarnings(as.numeric(value))
    digits <- display_value_digits(numeric_value, min_significant_digits)
    out <- rep(if (isTRUE(blank_for_na)) "" else NA_character_, length(numeric_value))
    finite_idx <- which(is.finite(numeric_value) & !is.na(numeric_value))

    out[finite_idx] <- vapply(finite_idx, function(idx) {
      if (identical(numeric_value[[idx]], 0)) {
        return("0")
      }

      formatC(
        numeric_value[[idx]],
        format = "f",
        digits = digits[[idx]],
        big.mark = ",",
        drop0trailing = FALSE
      )
    }, character(1))

    out
  }

  format_fixed_display_value <- function(value, digits = 2L, blank_for_na = FALSE) {
    numeric_value <- suppressWarnings(as.numeric(value))
    out <- rep(if (isTRUE(blank_for_na)) "" else NA_character_, length(numeric_value))
    finite_idx <- which(is.finite(numeric_value) & !is.na(numeric_value))

    out[finite_idx] <- vapply(finite_idx, function(idx) {
      if (identical(numeric_value[[idx]], 0)) {
        return("0")
      }

      formatC(
        numeric_value[[idx]],
        format = "f",
        digits = as.integer(digits),
        big.mark = ",",
        drop0trailing = TRUE
      )
    }, character(1))

    out
  }

  format_fixed_display_value_preserve_zeros <- function(value, digits = 2L, blank_for_na = FALSE) {
    numeric_value <- suppressWarnings(as.numeric(value))
    out <- rep(if (isTRUE(blank_for_na)) "" else NA_character_, length(numeric_value))
    finite_idx <- which(is.finite(numeric_value) & !is.na(numeric_value))

    out[finite_idx] <- vapply(finite_idx, function(idx) {
      formatC(
        numeric_value[[idx]],
        format = "f",
        digits = as.integer(digits),
        big.mark = ",",
        drop0trailing = FALSE
      )
    }, character(1))

    out
  }

  psd_matrix_metric_order <- function() {
    c(
      "psd_area_harvested",
      "psd_beginning_stocks",
      "psd_production",
      "psd_milling_rate",
      "psd_imports",
      "psd_ty_imports",
      "psd_ty_imports_from_us",
      "psd_total_supply",
      "psd_exports",
      "psd_ty_exports",
      "psd_domestic_consumption",
      "psd_ending_stocks",
      "psd_total_distribution",
      "psd_yield"
    )
  }

  format_psd_metric_display_value <- function(value, metric_code, blank_for_na = FALSE, min_significant_digits = 3L, yield_digits = 4L, value_digits = NULL) {
    fixed_value_digits <- psd_table_value_digits_for_formatter(value_digits)
    formatted_values <- if (is.null(fixed_value_digits)) {
      format_significant_display_value(
        value,
        min_significant_digits = min_significant_digits,
        blank_for_na = blank_for_na
      )
    } else {
      format_fixed_display_value_preserve_zeros(
        value,
        digits = fixed_value_digits,
        blank_for_na = blank_for_na
      )
    }

    metric_codes <- rep_len(as.character(metric_code), length(value))
    milling_rate_idx <- which(metric_codes == "psd_milling_rate")
    yield_idx <- which(metric_codes == "psd_yield")

    if (length(milling_rate_idx) > 0) {
      formatted_values[milling_rate_idx] <- format_fixed_display_value_preserve_zeros(
        value[milling_rate_idx] / 100,
        digits = 2L,
        blank_for_na = blank_for_na
      )
    }

    if (length(yield_idx) > 0 && is.null(fixed_value_digits)) {
      formatted_values[yield_idx] <- format_fixed_display_value(
        value[yield_idx],
        digits = yield_digits,
        blank_for_na = blank_for_na
      )
    }

    formatted_values
  }

  format_psd_matrix_percent_change_value <- function(value, digits = 1L, blank_for_na = TRUE) {
    values <- suppressWarnings(as.numeric(value))
    digits <- suppressWarnings(as.integer(digits[[1]]))
    if (is.na(digits) || digits < 0L) {
      digits <- 1L
    }

    vapply(values, function(single_value) {
      if (!is.finite(single_value)) {
        return(if (isTRUE(blank_for_na)) "" else NA_character_)
      }

      rounded_value <- round(single_value, digits = digits)
      formatted_value <- formatC(
        rounded_value,
        format = "f",
        digits = digits,
        big.mark = ","
      )
      paste0(if (rounded_value > 0) "+" else "", formatted_value, "%")
    }, character(1))
  }

  build_psd_map_matrix_comparison_state <- function() {
    if (!identical(map_comparison_mode(), "comparison")) {
      return(list(active = FALSE, status = "current_mode"))
    }

    selected_year <- suppressWarnings(as.numeric(map_selected_market_year()))
    if (!(length(selected_year) == 1L && is.finite(selected_year))) {
      return(list(active = FALSE, status = "missing_selected_year"))
    }

    comparison_state <- read_comparison_state_bundle_safe(
      surface = "map",
      source_choice = current_source_choice_safe(default = "psd"),
      year_choices = reference_year_choices(),
      hist_years_override = map_comparison_hist_years_committed()
    )

    list(
      active = TRUE,
      status = "active",
      selected_year = selected_year,
      basis_mode = comparison_state$basis_mode,
      reference_year = suppressWarnings(as.numeric(comparison_state$reference_year)),
      hist_years = suppressWarnings(as.integer(comparison_state$hist_years))
    )
  }

  resolve_psd_map_matrix_comparison_state <- function(comparison_state, available_years) {
    if (!is.list(comparison_state) || !isTRUE(comparison_state$active)) {
      return(list(active = FALSE, status = comparison_state$status %||% "inactive"))
    }

    selected_year <- suppressWarnings(as.numeric(comparison_state$selected_year))
    if (!(length(selected_year) == 1L && is.finite(selected_year))) {
      return(list(active = FALSE, status = "missing_selected_year"))
    }

    available_years <- sort(unique(suppressWarnings(as.numeric(available_years))))
    available_years <- available_years[is.finite(available_years)]
    basis_mode <- comparison_state$basis_mode %||% "average"
    if (!(basis_mode %in% c("average", "single_year"))) {
      basis_mode <- "average"
    }

    reference_year <- suppressWarnings(as.numeric(comparison_state$reference_year))
    has_reference_year <- length(reference_year) == 1L && is.finite(reference_year)
    hist_window <- suppressWarnings(as.integer(comparison_state$hist_years))
    if (!(length(hist_window) == 1L && is.finite(hist_window) && hist_window >= 1L)) {
      hist_window <- 3L
    }

    baseline_years <- if (identical(basis_mode, "single_year") && has_reference_year) {
      reference_year
    } else {
      available_years[available_years < selected_year & available_years >= (selected_year - hist_window)]
    }
    baseline_years <- sort(unique(baseline_years[is.finite(baseline_years)]))

    baseline_label <- if (identical(basis_mode, "single_year") && has_reference_year) {
      build_map_display_year_label(reference_year, source_choice = input$data_source_choice %||% "export_sales")
    } else {
      paste0("Historical Avg (", length(baseline_years), " yrs)")
    }

    list(
      active = TRUE,
      status = "active",
      selected_year = selected_year,
      basis_mode = basis_mode,
      reference_year = if (has_reference_year) reference_year else NA_real_,
      hist_years = hist_window,
      baseline_years = baseline_years,
      baseline_label = baseline_label
    )
  }

  build_map_comparison_column_labels <- function(selected_year,
                                                 baseline_label,
                                                 basis_mode = NULL,
                                                 reference_year = NULL,
                                                 source_choice = "psd") {
    selected_year_numeric <- suppressWarnings(as.numeric(selected_year))
    selected_year_label <- if (length(selected_year_numeric) == 1L && is.finite(selected_year_numeric)) {
      build_map_display_year_label(selected_year_numeric, source_choice = source_choice)
    } else {
      "Selected"
    }
    if (!is.character(selected_year_label) || length(selected_year_label) == 0 || !nzchar(selected_year_label[[1]])) {
      selected_year_label <- "Selected"
    }

    baseline_suffix <- if (length(baseline_label) > 0 && !is.na(baseline_label[[1]])) {
      as.character(baseline_label[[1]])
    } else {
      ""
    }

    reference_year_numeric <- suppressWarnings(as.numeric(reference_year))
    reference_year_label <- if (length(reference_year_numeric) == 1L && is.finite(reference_year_numeric)) {
      build_map_display_year_label(reference_year_numeric, source_choice = source_choice)
    } else {
      ""
    }
    has_reference_year_label <- is.character(reference_year_label) && length(reference_year_label) > 0 && nzchar(reference_year_label[[1]])

    baseline_col_name <- if (identical(basis_mode, "single_year") && isTRUE(has_reference_year_label)) {
      paste0("Reference ", reference_year_label[[1]])
    } else if (nzchar(baseline_suffix)) {
      paste0("Baseline ", baseline_suffix)
    } else {
      "Baseline"
    }

    absolute_col_name <- if (nzchar(baseline_suffix)) {
      paste0("Difference vs ", baseline_suffix)
    } else {
      "Difference"
    }

    percent_col_name <- if (nzchar(baseline_suffix)) {
      paste0("% Difference vs ", baseline_suffix)
    } else {
      "% Difference"
    }

    selected_col_name <- if (identical(selected_year_label[[1]], "Selected")) {
      "Selected"
    } else {
      paste0("Selected ", selected_year_label[[1]])
    }

    list(
      selected = selected_col_name,
      baseline = baseline_col_name,
      absolute = absolute_col_name,
      percent = percent_col_name
    )
  }

  append_psd_map_matrix_comparison_columns <- function(matrix_df, matrix_long_df, comparison_state, matrix_value_digits = NULL) {
    resolved_state <- resolve_psd_map_matrix_comparison_state(comparison_state, matrix_long_df$market_year_num %||% numeric(0))
    if (!isTRUE(resolved_state$active) || !is.data.frame(matrix_df) || nrow(matrix_df) == 0 || !is.data.frame(matrix_long_df) || nrow(matrix_long_df) == 0) {
      return(matrix_df)
    }

    selected_year <- resolved_state$selected_year
    baseline_years <- resolved_state$baseline_years %||% numeric(0)
    comparison_labels <- build_map_comparison_column_labels(
      selected_year = selected_year,
      baseline_label = resolved_state$baseline_label,
      basis_mode = resolved_state$basis_mode,
      reference_year = resolved_state$reference_year,
      source_choice = "psd"
    )

    metric_keys <- matrix_long_df %>%
      select(metric_col) %>%
      distinct()

    selected_values <- matrix_long_df %>%
      filter(.data$market_year_num == selected_year) %>%
      group_by(.data$metric_col) %>%
      summarise(current_value = dplyr::first(.data$value), .groups = "drop")

    baseline_values <- if (length(baseline_years) > 0L) {
      matrix_long_df %>%
        filter(.data$market_year_num %in% baseline_years, is.finite(.data$value)) %>%
        group_by(.data$metric_col) %>%
        summarise(baseline_value = mean(.data$value, na.rm = TRUE), .groups = "drop")
    } else {
      data.frame(metric_col = character(), baseline_value = numeric(), stringsAsFactors = FALSE)
    }

    comparison_display <- metric_keys %>%
      left_join(selected_values, by = "metric_col") %>%
      left_join(baseline_values, by = "metric_col") %>%
      mutate(
        absolute_change = .data$current_value - .data$baseline_value,
        percent_change = dplyr::if_else(
          is.finite(.data$baseline_value) & .data$baseline_value > 0,
          ((.data$current_value - .data$baseline_value) / .data$baseline_value) * 100,
          NA_real_
        ),
        selected_value_text = format_psd_metric_display_value(
          .data$current_value,
          .data$metric_col,
          blank_for_na = TRUE,
          yield_digits = 4L,
          value_digits = matrix_value_digits
        ),
        baseline_value_text = format_psd_metric_display_value(
          .data$baseline_value,
          .data$metric_col,
          blank_for_na = TRUE,
          yield_digits = 4L,
          value_digits = matrix_value_digits
        ),
        absolute_change_text = format_psd_metric_display_value(
          .data$absolute_change,
          .data$metric_col,
          blank_for_na = TRUE,
          yield_digits = 4L,
          value_digits = matrix_value_digits
        ),
        percent_change_text = format_psd_matrix_percent_change_value(.data$percent_change, digits = 1L, blank_for_na = TRUE)
      ) %>%
      select(metric_col, selected_value_text, baseline_value_text, absolute_change_text, percent_change_text)

    names(comparison_display)[names(comparison_display) == "selected_value_text"] <- comparison_labels$selected
    names(comparison_display)[names(comparison_display) == "baseline_value_text"] <- comparison_labels$baseline
    names(comparison_display)[names(comparison_display) == "absolute_change_text"] <- comparison_labels$absolute
    names(comparison_display)[names(comparison_display) == "percent_change_text"] <- comparison_labels$percent

    matrix_df %>%
      left_join(comparison_display, by = "metric_col")
  }

  psd_map_matrix_comparison_column_targets <- function(matrix_df, pattern = "^(Selected |Reference |Baseline |Difference vs |% Difference vs )") {
    if (!is.data.frame(matrix_df) || ncol(matrix_df) == 0) {
      return(integer(0))
    }

    target_positions <- grep(pattern, names(matrix_df)) - 1L
    as.integer(target_positions[target_positions >= 0L])
  }

  psd_map_matrix_has_comparison_contract <- function(matrix_df) {
    if (!is.data.frame(matrix_df) || ncol(matrix_df) == 0) {
      return(FALSE)
    }

    column_names <- names(matrix_df)
    all(c(
      any(grepl("^Selected ", column_names)),
      any(grepl("^(Reference |Baseline )", column_names)),
      any(grepl("^Difference vs ", column_names)),
      any(grepl("^% Difference vs ", column_names))
    ))
  }

  js_array_from_integer <- function(values) {
    values <- as.integer(values %||% integer(0))
    values <- values[!is.na(values)]
    paste0("[", paste(values, collapse = ","), "]")
  }

  dt_column_target <- function(table_df, column_name) {
    matched <- match(column_name, names(table_df))
    if (length(matched) == 0L || is.na(matched)) {
      return(integer(0))
    }

    as.integer(matched - 1L)
  }

  build_map_summary_comparison_dt_config <- function(summary_table,
                                                     comparison_labels,
                                                     show_percent_column = TRUE,
                                                     preferred_order_column = NULL) {
    hidden_targets <- grep("^\\.\\.", names(summary_table)) - 1L
    hidden_targets <- as.integer(hidden_targets[hidden_targets >= 0L])

    value_target <- dt_column_target(summary_table, "Value")
    baseline_target <- dt_column_target(summary_table, comparison_labels$baseline)
    absolute_target <- dt_column_target(summary_table, comparison_labels$absolute)
    percent_change_target <- dt_column_target(summary_table, comparison_labels$percent)
    percent_share_target <- dt_column_target(summary_table, "Percent")
    value_sort_target <- dt_column_target(summary_table, "..value_sort")
    baseline_sort_target <- dt_column_target(summary_table, "..baseline_sort")
    absolute_sort_target <- dt_column_target(summary_table, "..absolute_sort")
    percent_change_sort_target <- dt_column_target(summary_table, "..percent_change_sort")
    latest_period_sort_target <- dt_column_target(summary_table, "..latest_period_sort")
    date_updated_target <- dt_column_target(summary_table, "Date Updated")
    selected_country_target <- dt_column_target(summary_table, "..selected_country_key")

    comparison_targets <- as.integer(c(baseline_target, absolute_target, percent_change_target))
    comparison_targets <- comparison_targets[!is.na(comparison_targets)]
    comparison_regular_targets <- as.integer(c(baseline_target, absolute_target))
    comparison_regular_targets <- comparison_regular_targets[!is.na(comparison_regular_targets)]

    column_defs <- list()
    if (length(hidden_targets) > 0L) {
      column_defs <- c(column_defs, list(list(targets = hidden_targets, visible = FALSE, searchable = FALSE)))
    }
    if (length(date_updated_target) > 0L && length(latest_period_sort_target) > 0L) {
      column_defs <- c(column_defs, list(list(targets = date_updated_target, orderData = latest_period_sort_target)))
    }
    if (length(value_target) > 0L && length(value_sort_target) > 0L) {
      column_defs <- c(column_defs, list(list(targets = value_target, orderData = value_sort_target)))
    }
    if (length(baseline_target) > 0L && length(baseline_sort_target) > 0L) {
      column_defs <- c(column_defs, list(list(targets = baseline_target, orderData = baseline_sort_target)))
    }
    if (length(absolute_target) > 0L && length(absolute_sort_target) > 0L) {
      column_defs <- c(column_defs, list(list(targets = absolute_target, orderData = absolute_sort_target)))
    }
    if (length(percent_change_target) > 0L && length(percent_change_sort_target) > 0L) {
      column_defs <- c(column_defs, list(list(targets = percent_change_target, orderData = percent_change_sort_target)))
    }
    if (length(baseline_target) > 0L) {
      column_defs <- c(column_defs, list(list(targets = baseline_target, className = "psd-summary-comparison-start")))
    }
    if (length(comparison_regular_targets) > 0L) {
      column_defs <- c(column_defs, list(list(targets = comparison_regular_targets, className = "psd-summary-comparison-band")))
    }
    if (length(percent_change_target) > 0L) {
      column_defs <- c(column_defs, list(list(targets = percent_change_target, className = "psd-summary-comparison-percent")))
    }
    if (!isTRUE(show_percent_column) && length(percent_share_target) > 0L) {
      column_defs <- c(column_defs, list(list(targets = percent_share_target, visible = FALSE)))
    }

    preferred_order_target <- dt_column_target(summary_table, preferred_order_column %||% comparison_labels$percent)
    if (length(preferred_order_target) == 0L) {
      preferred_order_target <- percent_change_target
    }
    if (length(preferred_order_target) == 0L) {
      preferred_order_target <- value_target
    }
    if (length(preferred_order_target) == 0L) {
      preferred_order_target <- 0L
    }

    selected_country_target_js <- if (length(selected_country_target) > 0L) as.character(selected_country_target[[1]]) else "null"

    callback <- JS(
      "function applyMapSummaryComparisonHeaderClasses(){",
      paste0("  var summaryComparisonTargets = ", js_array_from_integer(comparison_targets), ";"),
      paste0("  var summaryStartTargets = ", js_array_from_integer(baseline_target), ";"),
      paste0("  var summaryPercentTargets = ", js_array_from_integer(percent_change_target), ";"),
      "  table.columns().every(function(index){",
      "    var header = $(this.header());",
      "    header.removeClass('psd-summary-comparison-band psd-summary-comparison-start psd-summary-comparison-percent');",
      "    if (summaryComparisonTargets.indexOf(index) !== -1) { header.addClass('psd-summary-comparison-band'); }",
      "    if (summaryStartTargets.indexOf(index) !== -1) { header.addClass('psd-summary-comparison-start'); }",
      "    if (summaryPercentTargets.indexOf(index) !== -1) { header.addClass('psd-summary-comparison-percent'); }",
      "  });",
      "}",
      "table.off('draw.dt.mapSummaryComparisonClasses').on('draw.dt.mapSummaryComparisonClasses', applyMapSummaryComparisonHeaderClasses);",
      "applyMapSummaryComparisonHeaderClasses();",
      paste0("var summarySelectedCountryTarget = ", selected_country_target_js, ";"),
      "table.on('click', 'tbody tr', function(){",
      "  var data = table.row(this).data();",
      "  if (!data || summarySelectedCountryTarget === null || summarySelectedCountryTarget >= data.length) { return; }",
      "  var selectedCountry = data[summarySelectedCountryTarget];",
      "  table.$('tr.selected').removeClass('selected');",
      "  $(this).addClass('selected');",
      "  if (selectedCountry) { Shiny.setInputValue('map_summary_table_toggle', {country: selectedCountry, selected: true, nonce: Date.now()}, {priority: 'event'}); }",
      "});"
    )

    list(
      column_defs = column_defs,
      order_target = as.integer(preferred_order_target[[1]]),
      callback = callback
    )
  }

  build_map_measurement_subtitle <- function(metric_label, unit_label) {
    paste0("Variable: ", metric_label, " | Measurement: ", unit_label)
  }

  map_year_label_profile <- function(source_choice = current_source_choice_safe(default = input$data_source_choice %||% "export_sales")) {
    if (isTRUE(is_calendar_year_display_context(source_choice = source_choice))) {
      return(list(
        prefix = "CY ",
        field = "Calendar Year",
        total = "Share of CY total (%)",
        share_field = "Share of CY total",
        descriptor = "calendar-year"
      ))
    }

    list(
      prefix = "MY ",
      field = "Market Year",
      total = "Share of MY total (%)",
      share_field = "Share of MY total",
      descriptor = "market-year"
    )
  }

  build_map_display_year_label <- function(year_value,
                                           source_choice = current_source_choice_safe(default = input$data_source_choice %||% "export_sales")) {
    profile <- map_year_label_profile(source_choice = source_choice)
    paste0(profile$prefix, year_value)
  }

  build_map_display_year_field_label <- function(source_choice = current_source_choice_safe(default = input$data_source_choice %||% "export_sales")) {
    map_year_label_profile(source_choice = source_choice)$field
  }

  build_map_total_share_label <- function(source_choice = current_source_choice_safe(default = input$data_source_choice %||% "export_sales")) {
    map_year_label_profile(source_choice = source_choice)$total
  }

  build_display_year_share_field_label <- function(source_choice = current_source_choice_safe(default = input$data_source_choice %||% "export_sales")) {
    map_year_label_profile(source_choice = source_choice)$share_field
  }

  build_map_display_year_descriptor <- function(source_choice = current_source_choice_safe(default = input$data_source_choice %||% "export_sales")) {
    map_year_label_profile(source_choice = source_choice)$descriptor
  }

  build_psd_map_matrix_df <- function(selected_country = "GRAND_TOTAL", max_years = NULL, value_digits = NULL, comparison_state = NULL) {
    start_time <- Sys.time()
    matrix_value_digits <- psd_table_value_digits_for_formatter(value_digits)
    country_value <- selected_country %||% "GRAND_TOTAL"
    if (!nzchar(country_value)) {
      country_value <- "GRAND_TOTAL"
    }
    commodity_value <- resolved_psd_app_commodity()

    if (exists("psd_transition_trace", mode = "function")) {
      psd_transition_trace(
        event = "build_psd_map_matrix_df_enter",
        reason = "matrix_build",
        details = list(
          requested_country = selected_country,
          normalized_country = country_value,
          current_map_selected_country = isolate(map_selected_country()),
          current_map_input_country = isolate(input$psd_map_country_choice %||% NULL),
          metric = effective_main_metric()
        ),
        dedupe_key = "build_psd_map_matrix_df_enter",
        dedupe_signature = build_transition_trace_signature(list(
          requested_country = selected_country,
          normalized_country = country_value,
          current_map_selected_country = isolate(map_selected_country()),
          current_map_input_country = isolate(input$psd_map_country_choice %||% NULL),
          metric = effective_main_metric()
        ))
      )
    }

    matrix_source <- build_psd_latest_market_year_rows(
      selected_country = country_value,
      selected_commodity = commodity_value,
      metric_code = effective_main_metric()
    )
    if (is.null(matrix_source) || nrow(matrix_source) == 0) {
      log_perf(
        "build_psd_map_matrix_df()",
        start_time,
        details = list(country = country_value, metric = effective_main_metric(), status = "empty_source", rows = 0)
      )
      return(data.frame())
    }

    metric_cols <- psd_matrix_metric_order()
    metric_cols <- metric_cols[metric_cols %in% names(matrix_source)]
    if (length(metric_cols) == 0) {
      log_perf(
        "build_psd_map_matrix_df()",
        start_time,
        details = list(country = country_value, metric = effective_main_metric(), status = "no_metric_cols", rows = 0)
      )
      return(data.frame())
    }

    matrix_source_full <- matrix_source
    source_market_year_count <- dplyr::n_distinct(matrix_source$market_year)
    requested_max_years <- suppressWarnings(as.integer(max_years %||% NA_integer_))
    year_cap_applied <- FALSE
    if (!is.na(requested_max_years) && requested_max_years > 0L && source_market_year_count > requested_max_years) {
      matrix_year_values <- sort(unique(suppressWarnings(as.integer(matrix_source$market_year))))
      matrix_year_values <- matrix_year_values[!is.na(matrix_year_values) & is.finite(matrix_year_values)]
      kept_market_years <- tail(matrix_year_values, requested_max_years)
      matrix_source <- matrix_source %>%
        filter(suppressWarnings(as.integer(.data$market_year)) %in% kept_market_years)
      year_cap_applied <- TRUE
    }

    metric_label_lookup <- stats::setNames(names(psd_metric_choices), unname(psd_metric_choices))
    area_unit_choice <- current_psd_area_unit_choice_safe()
    unit_choice <- input$unit_choice %||% "thousand_mt"
    basis_choice <- current_basis_choice_safe(default = default_basis_for_commodity(commodity_value, "psd"))
    active_tab <- current_main_tab_safe(selected_tab = input$main_tabs_panel %||% "Map")

    metric_unit_lookup <- stats::setNames(
      vapply(metric_cols, function(metric_col) {
        get_measurement_label_for_commodity(
          unit = unit_choice,
          commodity_name = commodity_value,
          basis_choice = effective_basis_choice_for_metric(metric_col, basis_choice, "psd"),
          active_tab = active_tab,
          metric_code = metric_col,
          source_choice = "psd",
          area_unit_choice = area_unit_choice
        )
      }, character(1)),
      metric_cols
    )

    matrix_long <- matrix_source %>%
      select(market_year, all_of(metric_cols)) %>%
      tidyr::pivot_longer(cols = all_of(metric_cols), names_to = "metric_col", values_to = "value") %>%
      mutate(
        market_year_num = suppressWarnings(as.numeric(.data$market_year)),
        Attribute = unname(metric_label_lookup[.data$metric_col]),
        Unit = unname(metric_unit_lookup[.data$metric_col]),
        market_year = paste0("MY ", .data$market_year),
        value_text = format_psd_metric_display_value(.data$value, .data$metric_col, blank_for_na = TRUE, yield_digits = 4L, value_digits = matrix_value_digits),
        attribute_order = match(.data$metric_col, psd_matrix_metric_order())
      )

    comparison_long <- matrix_source_full %>%
      select(market_year, all_of(metric_cols)) %>%
      tidyr::pivot_longer(cols = all_of(metric_cols), names_to = "metric_col", values_to = "value") %>%
      mutate(market_year_num = suppressWarnings(as.numeric(.data$market_year)))

    result <- matrix_long %>%
      select(metric_col, Attribute, Unit, market_year, value_text, attribute_order) %>%
      tidyr::pivot_wider(
        id_cols = c(metric_col, Attribute, Unit, attribute_order),
        names_from = market_year,
        values_from = value_text
      )

    result <- append_psd_map_matrix_comparison_columns(
      matrix_df = result,
      matrix_long_df = comparison_long,
      comparison_state = comparison_state,
      matrix_value_digits = matrix_value_digits
    ) %>%
      arrange(.data$attribute_order, .data$Attribute, .data$Unit) %>%
      select(-metric_col, -attribute_order)

    log_perf(
      "build_psd_map_matrix_df()",
      start_time,
      details = list(
        country = country_value,
        metric = effective_main_metric(),
        rows = nrow(result),
        cols = ncol(result),
        source_market_years = source_market_year_count,
        matrix_market_years = dplyr::n_distinct(matrix_source$market_year),
        year_cap_applied = year_cap_applied
      )
    )

    result
  }

  cap_psd_map_matrix_year_columns <- function(matrix_df, max_years = 8L) {
    if (!is.data.frame(matrix_df) || nrow(matrix_df) == 0) {
      return(matrix_df)
    }

    matrix_year_cols <- grep("^MY ", names(matrix_df), value = TRUE)
    if (length(matrix_year_cols) <= max_years) {
      return(matrix_df)
    }

    matrix_year_values <- suppressWarnings(as.integer(sub("^MY ", "", matrix_year_cols)))
    ordered_year_cols <- matrix_year_cols[order(matrix_year_values)]
    kept_year_cols <- tail(ordered_year_cols, as.integer(max_years))
    year_positions <- match(matrix_year_cols, names(matrix_df))
    first_year_position <- min(year_positions, na.rm = TRUE)
    last_year_position <- max(year_positions, na.rm = TRUE)
    leading_cols <- names(matrix_df)[seq_len(max(first_year_position - 1L, 0L))]
    trailing_cols <- if (last_year_position < ncol(matrix_df)) {
      names(matrix_df)[seq.int(last_year_position + 1L, ncol(matrix_df))]
    } else {
      character(0)
    }
    leading_cols <- setdiff(leading_cols, matrix_year_cols)
    trailing_cols <- setdiff(trailing_cols, matrix_year_cols)

    matrix_df[, c(leading_cols, kept_year_cols, trailing_cols), drop = FALSE]
  }

  resolve_psd_map_matrix_selected_country <- function(default = "GRAND_TOTAL") {
    current_selection <- as.character(map_selected_country() %||% character(0))
    current_selection <- current_selection[!is.na(current_selection) & nzchar(current_selection)]

    pending_selection <- as.character(pending_psd_map_country_target() %||% character(0))
    pending_selection <- pending_selection[!is.na(pending_selection) & nzchar(pending_selection)]

    input_selection <- as.character(input$psd_map_country_choice %||% character(0))
    input_selection <- input_selection[!is.na(input_selection) & nzchar(input_selection)]

    if (length(current_selection) > 0 && (!identical(current_selection[[1]], "GRAND_TOTAL") || length(pending_selection) == 0)) {
      return(current_selection[[1]])
    }

    if (length(pending_selection) > 0) {
      return(pending_selection[[1]])
    }

    if (length(input_selection) > 0) {
      return(input_selection[[1]])
    }

    if (length(current_selection) > 0) {
      return(current_selection[[1]])
    }

    default
  }

  build_psd_map_matrix_state <- function(selected_country = NULL, max_years = 8L) {
    selected_country <- as.character(selected_country %||% character(0))
    selected_country <- selected_country[!is.na(selected_country) & nzchar(selected_country)]
    if (length(selected_country) == 0) {
      selected_country <- resolve_psd_map_matrix_selected_country()
    } else {
      selected_country <- selected_country[[1]]
    }

    matrix_value_digits <- psd_table_value_digits_for_formatter(psd_map_matrix_value_digits())
    matrix_comparison_state <- build_psd_map_matrix_comparison_state()

    list(
      selected_country = selected_country,
      matrix_df = cap_psd_map_matrix_year_columns(
        build_psd_map_matrix_df(
          selected_country,
          max_years = max_years,
          value_digits = matrix_value_digits,
          comparison_state = matrix_comparison_state
        ),
        max_years = max_years
      )
    )
  }

  psd_map_matrix_cache_key <- reactive({
    psd_map_active <- is_psd_effective_map_tab_active()
    if (!isTRUE(psd_map_active)) {
      return(list(active = FALSE))
    }

    selected_country <- resolve_psd_map_matrix_selected_country()
    metric_code <- effective_main_metric()
    selected_commodity <- resolved_psd_app_commodity()

    matrix_comparison_mode <- map_comparison_mode() %||% "current"
    selected_market_year <- map_selected_market_year() %||% NA_character_
    comparison_basis_mode <- input$map_projection_basis_mode %||% "average"
    comparison_reference_year <- input$map_projection_reference_year %||% NA_character_
    comparison_hist_years <- map_comparison_hist_years_committed() %||% 3L
    matrix_comparison_key <- if (identical(matrix_comparison_mode, "comparison")) {
      list(
        mode = matrix_comparison_mode,
        selected_year = selected_market_year,
        basis_mode = comparison_basis_mode,
        reference_year = comparison_reference_year,
        hist_years = comparison_hist_years
      )
    } else {
      list(mode = matrix_comparison_mode)
    }

    list(
      active = TRUE,
      source_choice = current_source_choice_safe(default = "export_sales"),
      active_tab = current_main_tab_safe(selected_tab = input$main_tabs_panel %||% "Map"),
      selected_country = selected_country,
      selected_commodity = selected_commodity,
      metric = metric_code,
      input_unit = input$unit_choice %||% NULL,
      resolved_unit = current_unit_choice_safe(default = "thousand_mt"),
      matrix_basis = current_basis_choice_safe(default = default_basis_for_commodity(selected_commodity, "psd")),
      resolved_basis = active_resolved_basis(),
      psd_yield_lock = current_psd_yield_lock_input_safe(),
      area_unit = current_psd_area_unit_choice_safe(),
      matrix_digits = psd_table_value_digits_cache_key(psd_map_matrix_value_digits()),
      matrix_comparison = matrix_comparison_key,
      matrix_contract_version = "psd-map-matrix-comparison-v2",
      cache_data_version = cache_data_version,
      cache_schema_version = cache_schema_version
    )
  })

  psd_map_matrix_dataset <- reactive({
    record_cache_body_execution(session, "psd_map_matrix_dataset")
    if (!is_psd_effective_map_tab_active()) {
      return(list(
        selected_country = NULL,
        matrix_df = data.frame()
      ))
    }

    build_psd_map_matrix_state(max_years = 8L)
  }) %>% bindCache(psd_map_matrix_cache_key())

  output$psd_map_matrix_table <- renderDT({
    start_time <- Sys.time()
    if (!is_psd_effective_map_tab_active()) {
      log_perf("psd_map_matrix_table", start_time, details = list(status = "inactive", rows = 0))
      return(NULL)
    }

    matrix_state <- psd_map_matrix_dataset()
    selected_country <- matrix_state$selected_country %||% resolve_psd_map_matrix_selected_country()
    matrix_df <- matrix_state$matrix_df
    matrix_df_empty <- !is.data.frame(matrix_df) || nrow(matrix_df) == 0

    if (matrix_df_empty || (identical(map_comparison_mode(), "comparison") && !psd_map_matrix_has_comparison_contract(matrix_df))) {
      record_cache_body_execution(session, "psd_matrix_manual_rebuild")
      rebuilt_matrix_state <- build_psd_map_matrix_state(
        selected_country = resolve_psd_map_matrix_selected_country(),
        max_years = 8L
      )
      selected_country <- rebuilt_matrix_state$selected_country
      matrix_df <- rebuilt_matrix_state$matrix_df
    }

    if (!is.data.frame(matrix_df) || nrow(matrix_df) == 0) {
      log_perf(
        "psd_map_matrix_table",
        start_time,
        details = list(country = selected_country, status = "empty", rows = 0)
      )
      return(datatable(
        data.frame(Message = "No Market Year Comparison data is available for the selected country.", stringsAsFactors = FALSE),
        options = list(dom = "t", ordering = FALSE, searching = FALSE, paging = FALSE, stateSave = FALSE),
        rownames = FALSE,
        selection = "none"
      ))
    }

    comparison_targets <- psd_map_matrix_comparison_column_targets(matrix_df)
    comparison_start_target <- if (length(comparison_targets) > 0L) comparison_targets[[1L]] else integer(0)
    comparison_percent_targets <- psd_map_matrix_comparison_column_targets(matrix_df, pattern = "^% Difference vs ")
    comparison_regular_targets <- setdiff(comparison_targets, c(comparison_start_target, comparison_percent_targets))

    matrix_column_defs <- list()
    if (length(comparison_start_target) > 0L) {
      matrix_column_defs <- c(matrix_column_defs, list(list(
        targets = comparison_start_target,
        className = "dt-right psd-matrix-comparison-band psd-matrix-comparison-start"
      )))
    }
    if (length(comparison_regular_targets) > 0L) {
      matrix_column_defs <- c(matrix_column_defs, list(list(
        targets = comparison_regular_targets,
        className = "dt-right psd-matrix-comparison-band"
      )))
    }
    if (length(comparison_percent_targets) > 0L) {
      matrix_column_defs <- c(matrix_column_defs, list(list(
        targets = comparison_percent_targets,
        className = "dt-right psd-matrix-comparison-band psd-matrix-comparison-percent"
      )))
    }

    matrix_callback <- NULL
    if (length(comparison_targets) > 0L) {
      matrix_callback <- JS(
        paste0("var comparisonTargets = ", js_array_from_integer(comparison_targets), ";"),
        paste0("var comparisonStartTargets = ", js_array_from_integer(comparison_start_target), ";"),
        paste0("var comparisonPercentTargets = ", js_array_from_integer(comparison_percent_targets), ";"),
        "function addHeaderClasses(targets, className) {",
        "  $.each(targets, function(_, target) {",
        "    var header = table.column(target).header();",
        "    if (header) { $(header).addClass(className); }",
        "  });",
        "}",
        "addHeaderClasses(comparisonTargets, 'psd-matrix-comparison-band');",
        "addHeaderClasses(comparisonStartTargets, 'psd-matrix-comparison-start');",
        "addHeaderClasses(comparisonPercentTargets, 'psd-matrix-comparison-percent');"
      )
    }

    matrix_dt_args <- list(
      data = matrix_df,
      options = list(
        pageLength = 20,
        searching = TRUE,
        ordering = TRUE,
        scrollX = TRUE,
        stateSave = FALSE,
        columnDefs = matrix_column_defs
      ),
      rownames = FALSE,
      selection = "none"
    )
    if (!is.null(matrix_callback)) {
      matrix_dt_args$callback <- matrix_callback
    }

    result <- do.call(datatable, matrix_dt_args)

    log_perf(
      "psd_map_matrix_table",
      start_time,
      details = list(country = selected_country, rows = nrow(matrix_df), cols = ncol(matrix_df))
    )

    result
  })

  psd_display_numeric_value <- function(value, metric_code = NULL) {
    if (is_psd_milling_rate_metric(metric_code %||% NULL)) {
      return(value / 100)
    }

    value
  }

  format_map_summary_value <- function(value, metric_code = NULL, min_significant_digits = 3L, value_digits = NULL) {
    fixed_value_digits <- psd_table_value_digits_for_formatter(value_digits)
    if (!is.null(fixed_value_digits)) {
      return(format_fixed_display_value_preserve_zeros(
        psd_display_numeric_value(value, metric_code = metric_code),
        digits = fixed_value_digits,
        blank_for_na = FALSE
      ))
    }

    if (is_psd_milling_rate_metric(metric_code %||% NULL)) {
      return(format_fixed_display_value_preserve_zeros(
        psd_display_numeric_value(value, metric_code = metric_code),
        digits = 2L,
        blank_for_na = FALSE
      ))
    }

    if (is_psd_yield_metric(metric_code %||% NULL)) {
      return(format_fixed_display_value(value, digits = 2L, blank_for_na = FALSE))
    }

    format_significant_display_value(value, min_significant_digits = min_significant_digits, blank_for_na = FALSE)
  }

  format_psd_summary_numeric_value <- function(value, metric_code = NULL, value_digits = NULL) {
    if (is_psd_milling_rate_metric(metric_code %||% NULL)) {
      return(format_fixed_display_value_preserve_zeros(
        psd_display_numeric_value(value, metric_code = metric_code),
        digits = 2L,
        blank_for_na = FALSE
      ))
    }

    if (is_psd_yield_metric(metric_code %||% NULL)) {
      return(format_map_summary_value(value, metric_code = metric_code, value_digits = value_digits))
    }

    if (!is.null(psd_table_value_digits_for_formatter(value_digits))) {
      return(format_map_summary_value(value, metric_code = metric_code, value_digits = value_digits))
    }

    value
  }

  non_psd_map_summary_search_terms <- reactiveVal(list())

  non_psd_map_summary_search_scope_key <- function(mode = NULL, source_choice = NULL) {
    resolved_source <- source_choice %||% isolate(input$data_source_choice %||% "unknown")
    resolved_mode <- mode %||% isolate(map_comparison_mode() %||% "current")
    paste(resolved_source, resolved_mode, sep = ":")
  }

  observeEvent(input$non_psd_map_summary_table_search, {
    payload <- input$non_psd_map_summary_table_search
    search_term <- if (is.list(payload)) payload$search else payload
    search_term <- as.character(search_term %||% "")
    search_term <- search_term[!is.na(search_term)]
    search_term <- if (length(search_term) > 0L) search_term[[1L]] else ""
    scope_key <- if (is.list(payload)) payload$scope %||% NULL else NULL
    scope_key <- as.character(scope_key %||% non_psd_map_summary_search_scope_key())
    scope_key <- scope_key[!is.na(scope_key)]
    scope_key <- if (length(scope_key) > 0L) scope_key[[1L]] else non_psd_map_summary_search_scope_key()

    search_terms <- isolate(non_psd_map_summary_search_terms())
    if (!identical(search_terms[[scope_key]] %||% "", search_term)) {
      search_terms[[scope_key]] <- search_term
      non_psd_map_summary_search_terms(search_terms)
    }
  }, ignoreInit = TRUE)

  non_psd_map_summary_search_options <- function(options, mode = NULL, source_choice = NULL) {
    scope_key <- non_psd_map_summary_search_scope_key(mode = mode, source_choice = source_choice)
    search_terms <- isolate(non_psd_map_summary_search_terms())
    search_term <- as.character(search_terms[[scope_key]] %||% "")
    search_term <- search_term[!is.na(search_term)]
    search_term <- if (length(search_term) > 0L) search_term[[1L]] else ""

    if (nzchar(search_term)) {
      options$search <- list(search = search_term, regex = FALSE, smart = TRUE)
    }

    options
  }

  non_psd_map_summary_search_callback <- function(callback = NULL, mode = NULL, source_choice = NULL) {
    callback_lines <- if (is.null(callback)) character(0) else as.character(callback)
    scope_key <- non_psd_map_summary_search_scope_key(mode = mode, source_choice = source_choice)
    scope_key_json <- jsonlite::toJSON(scope_key, auto_unbox = TRUE)

    JS(
      paste0("var nonPsdSummarySearchKey = ", scope_key_json, ";"),
      "window.nonPsdMapSummarySearchMemory = window.nonPsdMapSummarySearchMemory || {};",
      "var nonPsdSummarySearchMemory = window.nonPsdMapSummarySearchMemory;",
      "var nonPsdSummarySettings = table.settings && table.settings()[0] ? table.settings()[0] : {};",
      "var nonPsdSummaryContainer = $(table.table().container());",
      "var nonPsdSummaryOutputRoot = nonPsdSummaryContainer.closest('.html-widget-output');",
      "if (!nonPsdSummaryOutputRoot.length) { nonPsdSummaryOutputRoot = nonPsdSummaryContainer; }",
      "var nonPsdSummaryOutputId = nonPsdSummaryOutputRoot.attr('id') || nonPsdSummarySettings.sTableId || 'non_psd_map_summary_table';",
      "var nonPsdSummaryNamespace = '.nonPsdSummary_' + String(nonPsdSummaryOutputId).replace(/[^A-Za-z0-9_]/g, '_');",
      "var nonPsdSummaryInit = nonPsdSummarySettings.oInit || {};",
      "var nonPsdSummaryConfiguredSearch = (nonPsdSummaryInit.search && typeof nonPsdSummaryInit.search.search !== 'undefined') ? (nonPsdSummaryInit.search.search || '') : '';",
      "var nonPsdSummaryHasStoredSearch = Object.prototype.hasOwnProperty.call(nonPsdSummarySearchMemory, nonPsdSummarySearchKey);",
      "var nonPsdSummaryDesiredSearch = nonPsdSummaryHasStoredSearch ? (nonPsdSummarySearchMemory[nonPsdSummarySearchKey] || '') : nonPsdSummaryConfiguredSearch;",
      "var nonPsdSummarySearchBox = nonPsdSummaryContainer.find('div.dataTables_filter input, div.dt-search input');",
      "var nonPsdSummarySearchPersistDelay = 300;",
      "var nonPsdSummarySearchPersistTimer = null;",
      "var nonPsdSummaryIsBootstrapping = true;",
      "var nonPsdSummaryIsRepairing = false;",
      "function nonPsdSummaryNormalize(value) {",
      "  return value == null ? '' : String(value);",
      "}",
      "function nonPsdSummaryDefer(callbackFn) {",
      "  if (window.requestAnimationFrame) {",
      "    window.requestAnimationFrame(function(){ window.setTimeout(callbackFn, 0); });",
      "  } else {",
      "    window.setTimeout(callbackFn, 0);",
      "  }",
      "}",
      "function nonPsdSummarySnapshot() {",
      "  var appliedRows = null;",
      "  var totalRows = null;",
      "  var tableSearch = '';",
      "  var infoText = '';",
      "  var filteredInfo = false;",
      "  try { appliedRows = table.rows({search: 'applied'}).count(); } catch (err) {}",
      "  try { totalRows = table.rows({search: 'none'}).count(); } catch (err) {}",
      "  try { tableSearch = nonPsdSummaryNormalize(table.search()); } catch (err) {}",
      "  try { infoText = nonPsdSummaryNormalize(nonPsdSummaryContainer.find('.dataTables_info').text()); } catch (err) {}",
      "  filteredInfo = infoText.indexOf('filtered from') !== -1;",
      "  return {",
      "    appliedRows: appliedRows,",
      "    totalRows: totalRows,",
      "    tableSearch: tableSearch,",
      "    searchBoxValue: nonPsdSummarySearchBox.length ? nonPsdSummaryNormalize(nonPsdSummarySearchBox.val()) : '',",
      "    infoText: infoText,",
      "    filteredInfo: filteredInfo",
      "  };",
      "}",
      "function nonPsdSummaryShouldRepair(snapshot) {",
      "  if (!snapshot || !(snapshot.totalRows > 0) || snapshot.appliedRows !== 0) {",
      "    return false;",
      "  }",
      "  var tableSearch = nonPsdSummaryNormalize(snapshot.tableSearch);",
      "  var searchBoxValue = nonPsdSummaryNormalize(snapshot.searchBoxValue);",
      "  if (tableSearch !== searchBoxValue) {",
      "    return true;",
      "  }",
      "  if (tableSearch === '' && searchBoxValue === '' && snapshot.filteredInfo) {",
      "    return true;",
      "  }",
      "  return false;",
      "}",
      "function nonPsdSummaryApplySearch(value, shouldDraw) {",
      "  var normalizedValue = nonPsdSummaryNormalize(value);",
      "  if (table.search() !== normalizedValue) {",
      "    table.search(normalizedValue);",
      "  }",
      "  if (nonPsdSummarySearchBox.length && nonPsdSummarySearchBox.val() !== normalizedValue) {",
      "    nonPsdSummarySearchBox.val(normalizedValue);",
      "  }",
      "  if (shouldDraw !== false) {",
      "    table.draw();",
      "  }",
      "}",
      "function nonPsdPushSummarySearch(value) {",
      "  value = nonPsdSummaryNormalize(value);",
      "  if (nonPsdSummaryIsBootstrapping || nonPsdSummaryIsRepairing) {",
      "    return;",
      "  }",
      "  if (window.Shiny && Shiny.setInputValue) {",
      "    Shiny.setInputValue('non_psd_map_summary_table_search', {search: value, scope: nonPsdSummarySearchKey, nonce: Date.now()}, {priority: 'event'});",
      "  }",
      "}",
      "function nonPsdRememberSummarySearch(value, immediate, persistToServer) {",
      "  value = nonPsdSummaryNormalize(value);",
      "  nonPsdSummarySearchMemory[nonPsdSummarySearchKey] = value;",
      "  if (persistToServer === false) {",
      "    return;",
      "  }",
      "  if (nonPsdSummarySearchPersistTimer) { clearTimeout(nonPsdSummarySearchPersistTimer); }",
      "  if (immediate) {",
      "    nonPsdPushSummarySearch(value);",
      "  } else {",
      "    nonPsdSummarySearchPersistTimer = setTimeout(function(){ nonPsdPushSummarySearch(value); }, nonPsdSummarySearchPersistDelay);",
      "  }",
      "}",
      "function nonPsdRepairSummaryState() {",
      "  var beforeRepair = nonPsdSummarySnapshot();",
      "  var intendedSearch = beforeRepair.tableSearch;",
      "  if (!nonPsdSummaryShouldRepair(beforeRepair)) {",
      "    return;",
      "  }",
      "  if (nonPsdSummaryIsRepairing) {",
      "    return;",
      "  }",
      "  nonPsdSummaryIsRepairing = true;",
      "  table.columns().every(function(){",
      "    if (this.search()) {",
      "      this.search('');",
      "    }",
      "  });",
      "  nonPsdSummaryApplySearch('', true);",
      "  if (table.columns && table.columns.adjust) {",
      "    table.columns.adjust();",
      "  }",
      "  nonPsdSummaryDefer(function(){",
      "    var afterClear = nonPsdSummarySnapshot();",
      "    if (intendedSearch !== '') {",
      "      nonPsdSummaryApplySearch(intendedSearch, true);",
      "    } else if (nonPsdSummarySearchBox.length && nonPsdSummarySearchBox.val() !== '') {",
      "      nonPsdSummarySearchBox.val('');",
      "    }",
      "    nonPsdSummaryDefer(function(){",
      "      nonPsdSummaryIsRepairing = false;",
      "      if (nonPsdSummaryShouldRepair(afterClear) && intendedSearch === '') {",
      "        nonPsdSummaryApplySearch('', true);",
      "      }",
      "    });",
      "  });",
      "}",
      "nonPsdSummaryApplySearch(nonPsdSummaryDesiredSearch, table.search() !== nonPsdSummaryDesiredSearch);",
      "if (nonPsdSummarySearchBox.length) {",
      "  var nonPsdSummarySearchBoxEvents = 'input' + nonPsdSummaryNamespace + ' keyup' + nonPsdSummaryNamespace + ' change' + nonPsdSummaryNamespace;",
      "  nonPsdSummarySearchBox.off(nonPsdSummarySearchBoxEvents).on(nonPsdSummarySearchBoxEvents, function(){",
      "    if (nonPsdSummaryIsBootstrapping || nonPsdSummaryIsRepairing) {",
      "      return;",
      "    }",
      "    nonPsdRememberSummarySearch($(this).val(), false, true);",
      "  });",
      "}",
      "table.off('search.dt' + nonPsdSummaryNamespace).on('search.dt' + nonPsdSummaryNamespace, function(){",
      "  if (nonPsdSummaryIsBootstrapping || nonPsdSummaryIsRepairing) {",
      "    return;",
      "  }",
      "  nonPsdRememberSummarySearch(table.search(), false, true);",
      "  nonPsdSummaryDefer(function(){ nonPsdRepairSummaryState(); });",
      "});",
      "table.off('draw.dt' + nonPsdSummaryNamespace).on('draw.dt' + nonPsdSummaryNamespace, function(){",
      "  if (nonPsdSummaryIsBootstrapping || nonPsdSummaryIsRepairing) {",
      "    return;",
      "  }",
      "  nonPsdSummaryDefer(function(){ nonPsdRepairSummaryState(); });",
      "});",
      "nonPsdRememberSummarySearch(nonPsdSummaryDesiredSearch, false, false);",
      "nonPsdSummaryDefer(function(){",
      "  nonPsdSummaryIsBootstrapping = false;",
      "  nonPsdRepairSummaryState();",
      "});",
      callback_lines
    )
  }

  psd_map_summary_search_term <- reactiveVal("")

  observeEvent(input$psd_map_summary_table_search, {
    payload <- input$psd_map_summary_table_search
    search_term <- if (is.list(payload)) payload$search else payload
    search_term <- as.character(search_term %||% "")
    search_term <- search_term[!is.na(search_term)]
    search_term <- if (length(search_term) > 0L) search_term[[1L]] else ""

    if (!identical(isolate(psd_map_summary_search_term()), search_term)) {
      psd_map_summary_search_term(search_term)
    }
  }, ignoreInit = TRUE)

  psd_map_summary_search_options <- function(options) {
    search_term <- isolate(as.character(psd_map_summary_search_term() %||% ""))
    search_term <- search_term[!is.na(search_term)]
    search_term <- if (length(search_term) > 0L) search_term[[1L]] else ""

    if (nzchar(search_term)) {
      options$search <- list(search = search_term, regex = FALSE, smart = TRUE)
    }

    options
  }

  psd_map_summary_search_callback <- function(callback = NULL) {
    callback_lines <- if (is.null(callback)) character(0) else as.character(callback)

    JS(
      "var psdSummarySearchKey = 'map_summary_table';",
      "window.psdMapSummarySearchMemory = window.psdMapSummarySearchMemory || {};",
      "var psdSummarySettings = table.settings && table.settings()[0] ? table.settings()[0] : {};",
      "var psdSummaryInit = psdSummarySettings.oInit || {};",
      "var psdSummaryInitialSearch = (psdSummaryInit.search && psdSummaryInit.search.search) || window.psdMapSummarySearchMemory[psdSummarySearchKey] || '';",
      "var psdSummarySearchBox = $(table.table().container()).find('div.dataTables_filter input, div.dt-search input');",
      "var psdSummarySearchPersistDelay = 300;",
      "var psdSummarySearchPersistTimer = null;",
      "function psdPushSummarySearch(value) {",
      "  value = value || '';",
      "  if (window.Shiny && Shiny.setInputValue) {",
      "    Shiny.setInputValue('psd_map_summary_table_search', {search: value, nonce: Date.now()}, {priority: 'event'});",
      "  }",
      "}",
      "function psdRememberSummarySearch(value, immediate) {",
      "  value = value || '';",
      "  window.psdMapSummarySearchMemory[psdSummarySearchKey] = value;",
      "  if (psdSummarySearchPersistTimer) { clearTimeout(psdSummarySearchPersistTimer); }",
      "  if (immediate) {",
      "    psdPushSummarySearch(value);",
      "  } else {",
      "    psdSummarySearchPersistTimer = setTimeout(function(){ psdPushSummarySearch(value); }, psdSummarySearchPersistDelay);",
      "  }",
      "}",
      "if (psdSummaryInitialSearch && table.search() !== psdSummaryInitialSearch) {",
      "  table.search(psdSummaryInitialSearch);",
      "  if (psdSummarySearchBox.length) { psdSummarySearchBox.val(psdSummaryInitialSearch); }",
      "  table.draw();",
      "} else if (psdSummarySearchBox.length && table.search()) {",
      "  psdSummarySearchBox.val(table.search());",
      "}",
      "if (psdSummarySearchBox.length) {",
      "  psdSummarySearchBox.off('.psdSummarySearchPersist').on('input.psdSummarySearchPersist keyup.psdSummarySearchPersist change.psdSummarySearchPersist', function(){",
      "    psdRememberSummarySearch($(this).val());",
      "  });",
      "}",
      "table.on('search.dt', function(){ psdRememberSummarySearch(table.search()); });",
      "psdRememberSummarySearch(table.search() || psdSummaryInitialSearch || '', true);",
      callback_lines
    )
  }

  render_map_summary_table_widget <- function(force_psd_mode = NULL, force_non_psd_mode = NULL) {
    start_time <- Sys.time()
    map_display <- map_display_dataset()
    map_state <- map_display$map_state
    shade_mode <- map_measure_mode()
    source_choice <- current_source_choice_safe(default = input$data_source_choice %||% "export_sales")
    is_psd_source <- identical(source_choice, "psd")
    if (!is.null(force_psd_mode)) {
      if (!is_psd_source) return(NULL)
      if (identical(force_psd_mode, "comparison") && !identical(map_display$mode, "comparison")) return(NULL)
      if (identical(force_psd_mode, "current") && identical(map_display$mode, "comparison")) return(NULL)
    }
    if (!is.null(force_non_psd_mode)) {
      if (is_psd_source) return(NULL)
      if (identical(force_non_psd_mode, "comparison") && !identical(map_display$mode, "comparison")) return(NULL)
      if (identical(force_non_psd_mode, "current") && identical(map_display$mode, "comparison")) return(NULL)
    }
    map_summary_output_id <- if (is_psd_source) {
      psd_map_summary_output_id_for_mode(map_display$mode)
    } else {
      non_psd_map_summary_output_id_for_mode(map_display$mode)
    }
    summary_unit_resolution <- resolve_map_display_unit(
      map_display = map_display,
      output_id = map_summary_output_id,
      source_choice = source_choice,
      metric_col = map_state$metric_col
    )
    summary_unit_warning <- map_unit_guardrail_warning_text(summary_unit_resolution)
    summary_caption <- if (!is.null(summary_unit_warning) && nzchar(trimws(summary_unit_warning))) {
      tags$caption(
        style = "caption-side: top; text-align: left; font-weight: normal; color: #555;",
        tags$span(summary_unit_warning)
      )
    } else {
      NULL
    }
    psd_map_summary_value_digits_fixed <- if (is_psd_source) {
      psd_table_value_digits_for_formatter(psd_map_summary_value_digits())
    } else {
      NULL
    }
    non_psd_map_summary_value_digits_fixed <- if (!is_psd_source) {
      psd_table_value_digits_for_formatter(non_psd_map_summary_value_digits())
    } else {
      NULL
    }
    show_percent_column <- !(is_psd_source && is_psd_non_share_metric(map_state$metric_col %||% NULL))
    visible_rank_lookup <- if (
      is.data.frame(map_display$display_df) &&
      nrow(map_display$display_df) > 0 &&
      all(c("selected_country_key", "rank") %in% names(map_display$display_df))
    ) {
      map_display$display_df %>%
        select(selected_country_key, display_rank = rank) %>%
        distinct()
    } else {
      data.frame(
        selected_country_key = character(),
        display_rank = integer(),
        stringsAsFactors = FALSE
      )
    }

    filter_visible_map_summary_rows <- function(table_rows) {
      if (
        !is.data.frame(table_rows) ||
        nrow(table_rows) == 0 ||
        is.null(map_display$top_n_cutoff) ||
        !("selected_country_key" %in% names(table_rows)) ||
        nrow(visible_rank_lookup) == 0
      ) {
        return(table_rows)
      }

      table_rows %>%
        semi_join(
          visible_rank_lookup %>% select(selected_country_key),
          by = "selected_country_key"
        ) %>%
        left_join(visible_rank_lookup, by = "selected_country_key") %>%
        mutate(rank = dplyr::coalesce(.data$display_rank, .data$rank)) %>%
        select(-any_of("display_rank"))
    }

    finalize_psd_map_summary <- function(result, status, row_count = 0L) {
      if (is_psd_source) {
        log_perf(
          "psd_map_summary_table",
          start_time,
          details = list(
            status = status,
            mode = map_display$mode %||% "unknown",
            metric = map_state$metric_col %||% NA_character_,
            rows = row_count
          )
        )
      }

      result
    }

    if (is_psd_source) {
      table_rows <- map_state$table_ranked_df %||% data.frame()
      if (!is.data.frame(table_rows) || nrow(table_rows) == 0) {
        return(finalize_psd_map_summary(NULL, status = "empty", row_count = 0L))
      }
    } else if (!identical(map_state$status, "ok") || nrow(map_display$display_df) == 0) {
      return(NULL)
    }

    if (identical(map_display$mode, "comparison")) {
      comparison_labels <- build_map_comparison_column_labels(
        selected_year = map_state$selected_market_year,
        baseline_label = map_state$baseline_label,
        basis_mode = map_state$basis_mode,
        reference_year = map_state$reference_year,
        source_choice = input$data_source_choice %||% "export_sales"
      )

      if (is_psd_source) {
        summary_table <- filter_visible_map_summary_rows(map_state$table_ranked_df) %>%
          transmute(
            "Market Year" = map_state$selected_market_year,
            "Date Updated" = vapply(seq_len(n()), function(row_idx) {
              format_psd_coverage_label(.data$latest_calendar_year[[row_idx]], .data$latest_calendar_month[[row_idx]], abbreviated = TRUE)
            }, character(1)),
            "Country" = .data$country_label,
            "Rank" = .data$rank,
            "Value" = format_map_summary_value(.data$current_value, metric_code = map_state$metric_col, value_digits = psd_map_summary_value_digits_fixed),
            "Percent" = .data$share_pct * 100,
            "..baseline_value_display" = format_psd_summary_numeric_value(.data$baseline_value, metric_code = map_state$metric_col, value_digits = psd_map_summary_value_digits_fixed),
            "..absolute_change_display" = format_psd_summary_numeric_value(.data$absolute_change, metric_code = map_state$metric_col, value_digits = psd_map_summary_value_digits_fixed),
            "..percent_change_display" = format_psd_matrix_percent_change_value(.data$percent_change, digits = 1L, blank_for_na = TRUE),
            "..latest_period_sort" = dplyr::coalesce(.data$latest_period_sort, -1L),
            "..selected_country_key" = .data$selected_country_key,
            "..value_sort" = .data$current_value,
            "..baseline_sort" = .data$baseline_value,
            "..absolute_sort" = .data$absolute_change,
            "..percent_change_sort" = .data$percent_change
          )

        names(summary_table)[names(summary_table) == "..baseline_value_display"] <- comparison_labels$baseline
        names(summary_table)[names(summary_table) == "..absolute_change_display"] <- comparison_labels$absolute
        names(summary_table)[names(summary_table) == "..percent_change_display"] <- comparison_labels$percent

        comparison_dt_config <- build_map_summary_comparison_dt_config(
          summary_table = summary_table,
          comparison_labels = comparison_labels,
          show_percent_column = show_percent_column,
          preferred_order_column = if (identical(shade_mode, "percent_change")) comparison_labels$percent else comparison_labels$absolute
        )

        summary_dt <- datatable(
          summary_table,
          caption = summary_caption,
          options = psd_map_summary_search_options(list(
            pageLength = 15,
            searching = TRUE,
            ordering = TRUE,
            stateSave = FALSE,
            order = list(list(comparison_dt_config$order_target, "desc")),
            columnDefs = comparison_dt_config$column_defs
          )),
          rownames = FALSE,
          selection = "none",
          callback = psd_map_summary_search_callback(comparison_dt_config$callback)
        ) %>%
          formatRound(columns = "Percent", digits = 3, mark = ",")

        if (is.null(psd_map_summary_value_digits_fixed) && !is_psd_milling_rate_metric(map_state$metric_col %||% NULL) && !is_psd_yield_metric(map_state$metric_col %||% NULL)) {
          summary_dt <- summary_dt %>% formatRound(columns = c(comparison_labels$baseline, comparison_labels$absolute), digits = 0, mark = ",")
        }

        return(finalize_psd_map_summary(summary_dt, status = "comparison", row_count = nrow(summary_table)))
      }

      summary_table <- map_display$display_df %>%
        transmute(
          "Market Year" = map_state$selected_market_year,
          "Week/Month to Date" = map_state$selected_period_label,
          "Country" = .data$country_label,
          "Rank" = .data$rank,
          "Value" = format_map_summary_value(.data$current_value, metric_code = map_state$metric_col, value_digits = non_psd_map_summary_value_digits_fixed),
          "Percent" = .data$share_pct * 100,
          "..baseline_value_display" = if (is.null(non_psd_map_summary_value_digits_fixed)) .data$baseline_value else format_map_summary_value(.data$baseline_value, metric_code = map_state$metric_col, value_digits = non_psd_map_summary_value_digits_fixed),
          "..absolute_change_display" = if (is.null(non_psd_map_summary_value_digits_fixed)) .data$absolute_change else format_map_summary_value(.data$absolute_change, metric_code = map_state$metric_col, value_digits = non_psd_map_summary_value_digits_fixed),
          "..percent_change_display" = .data$percent_change,
          "..selected_country_key" = .data$selected_country_key,
          "..value_sort" = .data$current_value,
          "..baseline_sort" = .data$baseline_value,
          "..absolute_sort" = .data$absolute_change
        )

      names(summary_table)[names(summary_table) == "..baseline_value_display"] <- comparison_labels$baseline
      names(summary_table)[names(summary_table) == "..absolute_change_display"] <- comparison_labels$absolute
      names(summary_table)[names(summary_table) == "..percent_change_display"] <- comparison_labels$percent

      comparison_dt_config <- build_map_summary_comparison_dt_config(
        summary_table = summary_table,
        comparison_labels = comparison_labels,
        show_percent_column = show_percent_column,
        preferred_order_column = if (identical(shade_mode, "percent_change")) comparison_labels$percent else comparison_labels$absolute
      )

      return(finalize_psd_map_summary(
        {
          summary_dt <- datatable(
          summary_table,
          caption = summary_caption,
          options = non_psd_map_summary_search_options(list(
            pageLength = 15,
            searching = TRUE,
            ordering = TRUE,
            stateSave = FALSE,
            order = list(list(comparison_dt_config$order_target, "desc")),
            columnDefs = comparison_dt_config$column_defs
          ), mode = map_display$mode %||% "comparison", source_choice = input$data_source_choice %||% "export_sales"),
          rownames = FALSE,
          selection = "none",
          callback = non_psd_map_summary_search_callback(
            comparison_dt_config$callback,
            mode = map_display$mode %||% "comparison",
            source_choice = input$data_source_choice %||% "export_sales"
          )
        ) %>%
            formatRound(columns = c("Percent", comparison_labels$percent), digits = 3, mark = ",")

          if (is.null(non_psd_map_summary_value_digits_fixed)) {
            summary_dt <- summary_dt %>% formatRound(columns = c(comparison_labels$baseline, comparison_labels$absolute), digits = 0, mark = ",")
          }

          summary_dt
        },
        status = "comparison",
        row_count = nrow(summary_table)
      ))
    }

    if (is_psd_source) {
      summary_table <- filter_visible_map_summary_rows(map_state$table_ranked_df) %>%
        transmute(
          "Market Year" = map_state$selected_market_year,
          "Date Updated" = vapply(seq_len(n()), function(row_idx) {
            format_psd_coverage_label(.data$latest_calendar_year[[row_idx]], .data$latest_calendar_month[[row_idx]], abbreviated = TRUE)
          }, character(1)),
          "Country" = .data$country_label,
          "Rank" = .data$rank,
          "Value" = format_map_summary_value(.data$quantity_value, metric_code = map_state$metric_col, value_digits = psd_map_summary_value_digits_fixed),
          "Percent" = .data$share_pct * 100,
          "..latest_period_sort" = dplyr::coalesce(.data$latest_period_sort, -1L),
          "..selected_country_key" = .data$selected_country_key,
          "..value_sort" = .data$quantity_value
        )

      ranked_column_defs <- list(
        list(targets = c(6, 7, 8), visible = FALSE, searchable = FALSE),
        list(targets = 1, orderData = 6),
        list(targets = 4, orderData = 8)
      )
      if (!show_percent_column) {
        ranked_column_defs <- c(ranked_column_defs, list(list(targets = 5, visible = FALSE, searchable = FALSE)))
      }

      return(finalize_psd_map_summary(
        datatable(
          summary_table,
          caption = summary_caption,
          options = psd_map_summary_search_options(list(
            pageLength = 15,
            searching = TRUE,
            ordering = TRUE,
            stateSave = FALSE,
            order = list(list(if (identical(shade_mode, "share_pct")) 5 else 4, "desc")),
              columnDefs = ranked_column_defs
          )),
          rownames = FALSE,
          selection = "none",
          callback = psd_map_summary_search_callback(JS(
            "table.on('click', 'tbody tr', function() {",
            "  var row = table.row(this);",
            "  if (!row.node()) { return; }",
            "  var data = row.data();",
            "  if (!data) { return; }",
            "  var selectedCountry = data[7];",
            "  table.$('tr.selected').removeClass('selected');",
            "  $(this).addClass('selected');",
            "  Shiny.setInputValue('map_summary_table_toggle', {country: selectedCountry, selected: true, nonce: Date.now()}, {priority: 'event'});",
            "});"
          ))
        ) %>%
          formatRound(
            columns = "Percent",
            digits = 3,
            mark = ","
          ),
        status = "current",
        row_count = nrow(summary_table)
      ))
    }

    summary_table <- map_display$display_df %>%
      transmute(
        "Market Year" = map_state$selected_market_year,
        "Week/Month to Date" = map_state$selected_period_label,
        "Country" = .data$country_label,
        "Rank" = .data$rank,
          "Value" = format_map_summary_value(.data$quantity_value, value_digits = non_psd_map_summary_value_digits_fixed),
        "Percent" = .data$share_pct * 100,
        "..selected_country_key" = .data$selected_country_key,
        "..value_sort" = .data$quantity_value
      )

    datatable(
      summary_table,
      caption = summary_caption,
      options = non_psd_map_summary_search_options(list(
        pageLength = 15,
        searching = TRUE,
        ordering = TRUE,
        stateSave = FALSE,
        order = list(list(if (identical(shade_mode, "share_pct")) 5 else 4, "desc")),
        columnDefs = list(
          list(targets = c(6, 7), visible = FALSE, searchable = FALSE),
          list(targets = 4, orderData = 7)
        )
      ), mode = map_display$mode %||% "current", source_choice = input$data_source_choice %||% "export_sales"),
      rownames = FALSE,
      selection = "none",
      callback = non_psd_map_summary_search_callback(JS(
        "table.on('click', 'tbody tr', function() {",
        "  var row = table.row(this);",
        "  if (!row.node()) { return; }",
        "  var data = row.data();",
        "  if (!data) { return; }",
        "  var selectedCountry = data[6];",
        "  table.$('tr.selected').removeClass('selected');",
        "  $(this).addClass('selected');",
        "  Shiny.setInputValue('map_summary_table_toggle', {country: selectedCountry, selected: true, nonce: Date.now()}, {priority: 'event'});",
        "});"
      ), mode = map_display$mode %||% "current", source_choice = input$data_source_choice %||% "export_sales")
    ) %>%
      formatRound(
        columns = "Percent",
        digits = 3,
        mark = ","
      )
  }

  output$map_summary_table <- renderDT({
    render_map_summary_table_widget()
  })

  output$non_psd_map_summary_table_current <- renderDT({
    render_map_summary_table_widget(force_non_psd_mode = "current")
  })

  output$non_psd_map_summary_table_comparison <- renderDT({
    render_map_summary_table_widget(force_non_psd_mode = "comparison")
  })

  output$psd_map_summary_table_current <- renderDT({
    render_map_summary_table_widget(force_psd_mode = "current")
  })

  output$psd_map_summary_table_comparison <- renderDT({
    render_map_summary_table_widget(force_psd_mode = "comparison")
  })

  outputOptions(output, "psd_map_summary_table_current", suspendWhenHidden = FALSE)
  outputOptions(output, "psd_map_summary_table_comparison", suspendWhenHidden = FALSE)
  outputOptions(output, "psd_map_matrix_table", suspendWhenHidden = FALSE)

  output$partner_share_hist_note <- renderUI({
    if (!is_market_year_comparison_output_active()) {
      record_myc_partner_output_lifecycle("hist_note", "gated_skip")
      return(NULL)
    }

    record_myc_partner_output_lifecycle("hist_note", "executed")
    record_partner_share_data_read("partner_share_hist_note")
    share_data <- partner_share_data()
    if (is.null(share_data)) return(NULL)

    comparison_basis_mode <- share_data$comparison_basis_mode %||% "average"
    comparison_basis_years <- share_data$comparison_basis_years %||% share_data$hist_years
    source_choice <- current_source_choice_safe(default = input$data_source_choice %||% "export_sales")
    warning_note <- if (identical(share_data$comparison_mode, "country")) {
      get_product_weight_basis_note(input$commodity_choice, current_basis_choice_safe())
    } else {
      NULL
    }

    if (length(comparison_basis_years) == 0) {
      missing_label <- if (identical(comparison_basis_mode, "single_year")) "Single reference baseline" else "Historical average bar"
      return(
        tags$p(
          tags$em(paste0(missing_label, " not shown (no comparison years available for the current filters).")),
          if (!is.null(warning_note)) list(
            tags$br(),
            warning_note
          )
        )
      )
    }

    note_text <- if (identical(comparison_basis_mode, "single_year")) {
      reference_label <- share_data$comparison_reference_year_label
      if (is.null(reference_label) || length(reference_label) != 1L || is.na(reference_label) || !nzchar(reference_label)) {
        reference_label <- build_map_display_year_label(comparison_basis_years[[1]], source_choice = source_choice)
      }
      paste0("Note: Comparison baseline based on ", reference_label)
    } else if (length(comparison_basis_years) == 1) {
      paste0("Note: Historical average based on ", build_map_display_year_label(comparison_basis_years, source_choice = source_choice))
    } else {
      paste0(
        "Note: Historical average based on ",
        build_map_display_year_label(min(comparison_basis_years), source_choice = source_choice),
        "-",
        build_map_display_year_label(max(comparison_basis_years), source_choice = source_choice),
        " (", length(comparison_basis_years), " years)"
      )
    }

    tags$p(
      tags$em(note_text),
      if (!is.null(warning_note)) list(
        tags$br(),
        warning_note
      )
    )
  })

  # ============================================================================
  # PACE ANALYSIS TOOL SERVER LOGIC
  # ============================================================================
  
  last_pace_context <- reactiveVal("")

  format_pace_target <- function(value) {
    numeric_value <- suppressWarnings(as.numeric(value))
    if (!is.finite(numeric_value)) return("")
    format(round(numeric_value, 0), big.mark = ",", scientific = FALSE, trim = TRUE)
  }

