  # Reactive cache for all users' notes to keep cross-user modal content current.
  all_notes_data <- reactiveVal(all_notes_df)
  pending_sidebar_country_target <- reactiveVal(NULL)
  canonical_psd_country <- reactiveVal(NULL)
  summary_table_value_digits_min <- 0L
  summary_table_value_digits_max <- 6L
  summary_table_value_digits <- reactiveVal(summary_table_value_digits_min)
  myc_table_value_digits <- reactiveVal(summary_table_value_digits_min)
  comparison_reference_week_shift_min <- -2L
  comparison_reference_week_shift_max <- 0L
  comparison_reference_week_shift <- reactiveVal(0L)
  psd_table_value_digits_min <- summary_table_value_digits_min
  psd_table_value_digits_max <- summary_table_value_digits_max
  non_psd_map_summary_value_digits <- reactiveVal(NA_integer_)
  psd_map_summary_value_digits <- reactiveVal(NA_integer_)
  psd_map_matrix_value_digits <- reactiveVal(NA_integer_)
  psd_time_series_summary_value_digits <- reactiveVal(NA_integer_)
  psd_historical_records_value_digits <- reactiveVal(NA_integer_)
  psd_prior_comparison_value_digits <- reactiveVal(NA_integer_)
  wasde_prior_comparison_value_digits <- reactiveVal(NA_integer_)

  normalize_psd_country_candidate <- function(value) {
    candidate <- as.character(value %||% character(0))
    candidate <- candidate[!is.na(candidate) & nzchar(candidate)]
    if (length(candidate) == 0) return(NULL)
    candidate[[1]]
  }

  read_canonical_psd_country <- function(default = NULL) {
    candidate <- normalize_psd_country_candidate(isolate(canonical_psd_country()))
    if (!is.null(candidate)) candidate else default
  }

  write_canonical_psd_country <- function(value) {
    candidate <- normalize_psd_country_candidate(value)
    canonical_psd_country(candidate)
    invisible(candidate)
  }

  default_commodity_choice_value <- function() {
    candidate <- trimws(as.character(COMMODITY_AGGREGATE_LABEL %||% "All"))
    candidate <- candidate[!is.na(candidate) & nzchar(candidate)]
    if (length(candidate) == 0L) "All" else candidate[[1L]]
  }

  default_commodity_choice_named <- function() {
    value <- default_commodity_choice_value()
    stats::setNames(value, value)
  }
  
  # Persistent panel state for Country Comparison (prevents sidebar changes from resetting panel selections)
  panel_state <- reactiveValues(
    metric_right = "monthlyexports",
    country_right_2up = "GRAND_TOTAL",
    commodity_right_2up = default_commodity_choice_value(),
    vp_commodity_name_right_2up = NA_character_,
    metric_grid_2 = "monthlyexports",
    country_grid_2 = "GRAND_TOTAL",
    commodity_grid_2 = default_commodity_choice_value(),
    metric_grid_3 = "outstandingSales",
    country_grid_3 = "GRAND_TOTAL",
    commodity_grid_3 = default_commodity_choice_value(),
    vp_commodity_name_grid_3 = NA_character_,
    metric_grid_4 = "total_commitment",
    country_grid_4 = "GRAND_TOTAL",
    commodity_grid_4 = default_commodity_choice_value(),
    vp_commodity_name_grid_4 = NA_character_
  )

  observeEvent(input$metric_right, {
    if (!is.null(input$metric_right)) panel_state$metric_right <- input$metric_right
  }, ignoreInit = TRUE)
  observeEvent(input$country_right_2up, {
    if (!is.null(input$country_right_2up)) panel_state$country_right_2up <- input$country_right_2up
  }, ignoreInit = TRUE)
  observeEvent(input$commodity_right_2up, {
    if (!is.null(input$commodity_right_2up)) panel_state$commodity_right_2up <- input$commodity_right_2up
  }, ignoreInit = TRUE)
  observeEvent(input$vp_commodity_name_right_2up, {
    if (!is.null(input$vp_commodity_name_right_2up)) panel_state$vp_commodity_name_right_2up <- input$vp_commodity_name_right_2up
  }, ignoreInit = TRUE)

  observeEvent(input$metric_grid_2, {
    if (!is.null(input$metric_grid_2)) panel_state$metric_grid_2 <- input$metric_grid_2
  }, ignoreInit = TRUE)
  observeEvent(input$country_grid_2, {
    if (!is.null(input$country_grid_2)) panel_state$country_grid_2 <- input$country_grid_2
  }, ignoreInit = TRUE)
  observeEvent(input$commodity_grid_2, {
    if (!is.null(input$commodity_grid_2)) panel_state$commodity_grid_2 <- input$commodity_grid_2
  }, ignoreInit = TRUE)

  observeEvent(input$metric_grid_3, {
    if (!is.null(input$metric_grid_3)) panel_state$metric_grid_3 <- input$metric_grid_3
  }, ignoreInit = TRUE)
  observeEvent(input$country_grid_3, {
    if (!is.null(input$country_grid_3)) panel_state$country_grid_3 <- input$country_grid_3
  }, ignoreInit = TRUE)
  observeEvent(input$commodity_grid_3, {
    if (!is.null(input$commodity_grid_3)) panel_state$commodity_grid_3 <- input$commodity_grid_3
  }, ignoreInit = TRUE)
  observeEvent(input$vp_commodity_name_grid_3, {
    if (!is.null(input$vp_commodity_name_grid_3)) panel_state$vp_commodity_name_grid_3 <- input$vp_commodity_name_grid_3
  }, ignoreInit = TRUE)

  observeEvent(input$metric_grid_4, {
    if (!is.null(input$metric_grid_4)) panel_state$metric_grid_4 <- input$metric_grid_4
  }, ignoreInit = TRUE)
  observeEvent(input$country_grid_4, {
    if (!is.null(input$country_grid_4)) panel_state$country_grid_4 <- input$country_grid_4
  }, ignoreInit = TRUE)
  observeEvent(input$commodity_grid_4, {
    if (!is.null(input$commodity_grid_4)) panel_state$commodity_grid_4 <- input$commodity_grid_4
  }, ignoreInit = TRUE)
  observeEvent(input$vp_commodity_name_grid_4, {
    if (!is.null(input$vp_commodity_name_grid_4)) panel_state$vp_commodity_name_grid_4 <- input$vp_commodity_name_grid_4
  }, ignoreInit = TRUE)

  initial_custom_types <- load_custom_types(
    user_custom_types_path,
    user_custom_types_census_reset_marker_path,
    user_custom_types_hybrid_reset_marker_path
  )
  custom_types_data <- reactiveVal(initial_custom_types)
  initial_custom_countries <- load_custom_countries(user_custom_countries_path)
  custom_countries_data <- reactiveVal(initial_custom_countries)
  census_custom_types_reset_notice_shown <- reactiveVal(FALSE)
  census_custom_types_reset_removed_count <- attr(initial_custom_types, "census_reset_removed_count")
  hybrid_custom_types_reset_notice_shown <- reactiveVal(FALSE)
  hybrid_custom_types_reset_removed_count <- attr(initial_custom_types, "hybrid_reset_removed_count")
  custom_warning_shown <- reactiveVal(FALSE)
  custom_country_warning_shown <- reactiveVal(FALSE)
  last_non_custom_commodity <- reactiveVal(default_commodity_choice_value())
  vp_type_empty_choice_transition <- reactiveVal(FALSE)
  myc_sidebar_transition_context <- reactiveVal(list(
    active = FALSE,
    restore_pending = FALSE,
    pre_entry_country = NULL,
    pre_entry_commodity = NULL,
    automatic_country = NULL,
    automatic_country_branch = NULL,
    manual_country_override = FALSE,
    automatic_commodity = NULL,
    automatic_commodity_branch = NULL,
    manual_commodity_override = FALSE,
    entry_trigger = NULL
  ))

  normalize_scope_value <- function(scope_value) {
    if (is.na(scope_value) || !nzchar(scope_value)) return("export_sales")
    if (scope_value %in% c("export_sales", "census_export", "census_import", "hybrid_export", "hybrid_import", "nass", "psd", "wasde")) return(scope_value)
    if (identical(scope_value, "hybrid")) return("hybrid_export")
    "export_sales"
  }

  observe({
    if (census_custom_types_reset_notice_shown()) return()
    if (is.null(census_custom_types_reset_removed_count) || census_custom_types_reset_removed_count <= 0) return()

    showNotification(
      paste0(
        "Census custom types were reset (", census_custom_types_reset_removed_count,
        " removed) after the scope update. Recreate any Census custom types you still need."
      ),
      type = "warning",
      duration = 10
    )
    census_custom_types_reset_notice_shown(TRUE)
  })

  observe({
    if (hybrid_custom_types_reset_notice_shown()) return()
    if (is.null(hybrid_custom_types_reset_removed_count) || hybrid_custom_types_reset_removed_count <= 0) return()

    showNotification(
      paste0(
        "Hybrid custom types were reset (", hybrid_custom_types_reset_removed_count,
        " removed) after the scope update. Recreate any Hybrid custom types you still need."
      ),
      type = "warning",
      duration = 10
    )
    hybrid_custom_types_reset_notice_shown(TRUE)
  })

  active_census_trade_flow <- reactive({
    if (!is.null(input$census_trade_flow_choice) && input$census_trade_flow_choice %in% c("export", "import")) {
      input$census_trade_flow_choice
    } else {
      "export"
    }
  })

  active_hybrid_trade_flow <- reactive({
    if (!is.null(input$hybrid_trade_flow_choice) && input$hybrid_trade_flow_choice %in% c("export", "import")) {
      input$hybrid_trade_flow_choice
    } else {
      "export"
    }
  })

  active_source_choice <- function(default = NULL) {
    if (exists("current_source_choice_safe", mode = "function")) {
      if (is.null(default)) {
        return(current_source_choice_safe())
      }
      return(current_source_choice_safe(default = default))
    }

    default <- default %||% "export_sales"
    source_choice <- input$data_source_choice
    source_choice <- trimws(as.character(source_choice %||% default))
    source_choice <- source_choice[!is.na(source_choice) & nzchar(source_choice)]
    if (length(source_choice) == 0L) default else source_choice[[1L]]
  }

  active_census_commodity_choices <- function() {
    aggregate_choice <- default_commodity_choice_named()
    census_values <- if (identical(active_census_trade_flow(), "import")) {
      native_commodities_census_imports
    } else {
      native_commodities_census_exports
    }
    census_values <- census_values[!(unname(census_values) %in% unname(aggregate_choice))]

    c(aggregate_choice, census_values)
  }

  active_custom_scope <- reactive({
    source_choice <- active_source_choice()
    if (identical(source_choice, "vp_trade")) {
      "vp_trade"
    } else if (identical(source_choice, "census")) {
      if (identical(active_census_trade_flow(), "import")) "census_import" else "census_export"
    } else if (identical(source_choice, "hybrid")) {
      if (identical(active_hybrid_trade_flow(), "import")) "hybrid_import" else "hybrid_export"
    } else if (identical(source_choice, "psd")) {
      "psd"
    } else if (identical(source_choice, "nass")) {
      "nass"
    } else if (identical(source_choice, "wasde")) {
      "wasde"
    } else {
      "export_sales"
    }
  })

  active_parse_commodities <- reactive({
    source_choice <- active_source_choice()
    if (identical(source_choice, "vp_trade")) {
      return(native_commodities_vp_trade)
    } else if (identical(source_choice, "census")) {
      return(active_census_commodity_choices())
    } else if (identical(source_choice, "hybrid")) {
      if (identical(active_hybrid_trade_flow(), "import")) {
        return(native_commodities_hybrid_import)
      }
      return(native_commodities_hybrid_export)
    } else if (identical(source_choice, "psd")) {
      return(native_commodities_psd)
    } else if (identical(source_choice, "nass")) {
      return(default_commodity_choice_named())
    } else if (identical(source_choice, "wasde")) {
      return(native_commodities_wasde)
    } else {
      sort(unique(c(native_commodities_monthly, native_commodities_weekly)))
    }
  })

  custom_types_for_scope <- reactive({
    as_tibble(custom_types_data()) %>%
      mutate(
        source_scope = vapply(as.character(.data$source_scope), normalize_scope_value, character(1))
      ) %>%
      filter(.data$source_scope == active_custom_scope())
  })

  active_native_commodities <- reactive({
    source_choice <- active_source_choice()
    if (identical(source_choice, "vp_trade")) {
      return(native_commodities_vp_trade)
    } else if (identical(source_choice, "census")) {
      return(active_census_commodity_choices())
    } else if (identical(source_choice, "hybrid")) {
      if (identical(active_hybrid_trade_flow(), "import")) {
        return(native_commodities_hybrid_import)
      }
      return(native_commodities_hybrid_export)
    } else if (identical(source_choice, "psd")) {
      return(native_commodities_psd)
    } else if (identical(source_choice, "nass")) {
      return(default_commodity_choice_named())
    } else if (identical(source_choice, "wasde")) {
      return(native_commodities_wasde)
    }

    if (identical(input$data_frequency, "monthly")) {
      native_commodities_monthly
    } else {
      native_commodities_weekly
    }
  })

  custom_types_enriched <- reactive({
    start_time <- Sys.time()
    custom_df <- custom_types_for_scope()

    record_cache_body_execution(
      session,
      "custom_types_enriched",
      details = list(
        source = input$data_source_choice %||% "export_sales",
        frequency = input$data_frequency %||% "weekly",
        scope = active_custom_scope(),
        rows = nrow(custom_df)
      )
    )

    if (nrow(custom_df) == 0) {
      result <- custom_df %>%
        mutate(
          parse_ok = logical(0),
          parse_error = character(0),
          parsed = vector("list", 0),
          referenced_commodities = vector("list", 0),
          product_basis_components = vector("list", 0),
          product_basis_codes = vector("list", 0),
          product_basis_summary = character(0),
          product_basis_mixed = logical(0)
        )

      log_perf(
        "custom_types_enriched()",
        start_time,
        details = list(
          source = input$data_source_choice,
          frequency = input$data_frequency,
          scope = active_custom_scope(),
          rows = 0,
          valid = 0
        )
      )

      return(result)
    }

    parsed_results <- purrr::map(custom_df$formula, function(formula_text) {
      tryCatch({
        parsed <- parse_custom_formula(formula_text, active_parse_commodities())
        list(ok = TRUE, parsed = parsed, error = "")
      }, error = function(e) {
        list(ok = FALSE, parsed = NULL, error = conditionMessage(e))
      })
    })

    basis_registry <- tryCatch(product_basis_registry(), error = function(...) product_basis_empty_registry())
    product_basis_results <- purrr::map(parsed_results, function(parsed_result) {
      parsed <- parsed_result$parsed
      if (is.null(parsed)) {
        return(product_basis_summary_for_refs(character(), basis_registry))
      }

      product_basis_summary_for_refs(
        referenced_commodities = parsed$referenced_commodities,
        registry_df = basis_registry,
        coefficients = parsed$coefficients
      )
    })

    result <- custom_df %>%
      mutate(
        parse_ok = purrr::map_lgl(parsed_results, "ok"),
        parse_error = purrr::map_chr(parsed_results, "error"),
        parsed = purrr::map(parsed_results, "parsed"),
        referenced_commodities = purrr::map(parsed, ~ {
          if (is.null(.x)) character() else .x$referenced_commodities
        }),
        normalized_formula = purrr::map2_chr(
          .data$parse_ok,
          .data$parsed,
          ~ if (.x) .y$normalized_formula else NA_character_
        ),
        product_basis_components = purrr::map(product_basis_results, "components"),
        product_basis_codes = purrr::map(product_basis_results, "codes"),
        product_basis_summary = purrr::map_chr(product_basis_results, "summary"),
        product_basis_mixed = purrr::map_lgl(product_basis_results, "mixed")
      )

    log_perf(
      "custom_types_enriched()",
      start_time,
      details = list(
        source = input$data_source_choice,
        frequency = input$data_frequency,
        scope = active_custom_scope(),
        rows = nrow(result),
        valid = sum(result$parse_ok, na.rm = TRUE)
      )
    )

    result
  })

  custom_types_cache_key <- reactive({
    defs <- custom_types_enriched()
    scope_key <- active_custom_scope()

    if (nrow(defs) == 0) {
      return(paste("scope", scope_key, "empty", sep = "||"))
    }

    normalized_defs <- defs %>%
      transmute(
        source_scope = as.character(.data$source_scope),
        custom_name = as.character(.data$custom_name),
        parse_ok = if_else(is.na(.data$parse_ok), FALSE, .data$parse_ok),
        normalized_formula = if_else(
          .data$parse_ok & !is.na(.data$normalized_formula),
          as.character(.data$normalized_formula),
          "__invalid__"
        )
      ) %>%
      arrange(.data$source_scope, .data$custom_name, .data$normalized_formula, .data$parse_ok)

    paste(
      scope_key,
      paste(
        normalized_defs$source_scope,
        normalized_defs$custom_name,
        normalized_defs$parse_ok,
        normalized_defs$normalized_formula,
        sep = "|"
      ),
      sep = "||"
    )
  })

  observe({
    if (custom_warning_shown()) return()
    defs <- custom_types_enriched()
    invalid_count <- sum(!defs$parse_ok, na.rm = TRUE)
    if (invalid_count > 0) {
      showNotification(
        paste0("Loaded ", invalid_count, " invalid custom type definition(s). They are ignored until corrected."),
        type = "warning",
        duration = 8
      )
      custom_warning_shown(TRUE)
    }
  })

  custom_countries_for_scope <- reactive({
    as_tibble(custom_countries_data()) %>%
      mutate(
        source_scope = vapply(
          as.character(.data$source_scope),
          normalize_custom_definition_scope,
          character(1),
          default_scope = "export_sales"
        )
      ) %>%
      filter(.data$source_scope == active_custom_scope())
  })

  custom_countries_enriched <- reactive({
    start_time <- Sys.time()
    custom_country_df <- custom_countries_for_scope()

    record_cache_body_execution(
      session,
      "custom_countries_enriched",
      details = list(
        source = input$data_source_choice %||% "export_sales",
        frequency = input$data_frequency %||% "weekly",
        scope = active_custom_scope(),
        rows = nrow(custom_country_df)
      )
    )

    if (nrow(custom_country_df) == 0) {
      return(
        custom_country_df %>%
          mutate(
            parse_ok = logical(0),
            parse_error = character(0),
            parsed = vector("list", 0),
            referenced_countries = vector("list", 0),
            referenced_custom_countries = vector("list", 0),
            dependency_cycle_flag = logical(0)
          )
      )
    }

    parsed_results <- purrr::map(custom_country_df$formula, function(formula_text) {
      tryCatch({
        parsed <- parse_custom_country_formula(
          formula_text = formula_text,
          source_scope = active_custom_scope(),
          frequency = input$data_frequency %||% "monthly",
          custom_country_names = custom_country_df$custom_name
        )
        list(ok = TRUE, parsed = parsed, error = "")
      }, error = function(e) {
        list(ok = FALSE, parsed = NULL, error = conditionMessage(e))
      })
    })

    result <- custom_country_df %>%
      mutate(
        parse_ok = purrr::map_lgl(parsed_results, "ok"),
        parse_error = purrr::map_chr(parsed_results, "error"),
        parsed = purrr::map(parsed_results, "parsed"),
        normalized_formula = purrr::map2_chr(
          .data$parse_ok,
          .data$parsed,
          ~ if (.x && !is.null(.y$normalized_formula)) .y$normalized_formula else NA_character_
        ),
        referenced_countries = purrr::map(.data$parsed, ~ if (is.null(.x)) character() else (.x$referenced_countries %||% character())),
        referenced_custom_countries = purrr::map(.data$parsed, ~ if (is.null(.x)) character() else (.x$referenced_custom_countries %||% character())),
        dependency_cycle_flag = FALSE
      )

    cycle_details <- detect_custom_country_cycles(
      result %>%
        transmute(
          custom_name = .data$custom_name,
          referenced_custom_countries = .data$referenced_custom_countries
        )
    )

    if (isTRUE(cycle_details$has_cycle)) {
      cycle_nodes <- tolower(trimws(as.character(cycle_details$cycle_nodes %||% character())))
      cycle_nodes <- cycle_nodes[!is.na(cycle_nodes) & nzchar(cycle_nodes)]
      cycle_mask <- tolower(trimws(as.character(result$custom_name))) %in% cycle_nodes

      if (any(cycle_mask)) {
        existing_errors <- result$parse_error[cycle_mask]
        existing_errors[is.na(existing_errors)] <- ""
        existing_errors <- ifelse(
          nzchar(existing_errors),
          paste0(existing_errors, " | Recursive custom-country dependency detected."),
          "Recursive custom-country dependency detected."
        )

        result$parse_ok[cycle_mask] <- FALSE
        result$parse_error[cycle_mask] <- existing_errors
        result$dependency_cycle_flag[cycle_mask] <- TRUE
      }
    }

    log_perf(
      "custom_countries_enriched()",
      start_time,
      details = list(
        source = input$data_source_choice,
        frequency = input$data_frequency,
        scope = active_custom_scope(),
        rows = nrow(result),
        valid = sum(result$parse_ok, na.rm = TRUE),
        cycles = sum(result$dependency_cycle_flag, na.rm = TRUE)
      )
    )

    result
  })

  custom_country_cache_key <- reactive({
    defs <- custom_countries_enriched()
    scope_key <- active_custom_scope()

    if (nrow(defs) == 0) {
      return(paste("scope", scope_key, "empty", sep = "||"))
    }

    normalized_defs <- defs %>%
      transmute(
        source_scope = as.character(.data$source_scope),
        custom_country_id = as.character(.data$custom_country_id),
        custom_name = as.character(.data$custom_name),
        parse_ok = if_else(is.na(.data$parse_ok), FALSE, .data$parse_ok),
        normalized_formula = if_else(
          .data$parse_ok & !is.na(.data$normalized_formula),
          as.character(.data$normalized_formula),
          "__invalid__"
        )
      ) %>%
      arrange(.data$source_scope, .data$custom_name, .data$custom_country_id, .data$normalized_formula)

    paste(
      scope_key,
      paste(
        normalized_defs$source_scope,
        normalized_defs$custom_country_id,
        normalized_defs$custom_name,
        normalized_defs$parse_ok,
        normalized_defs$normalized_formula,
        sep = "|"
      ),
      sep = "||"
    )
  })

  observe({
    if (custom_country_warning_shown()) return()
    defs <- custom_countries_enriched()
    invalid_count <- sum(!defs$parse_ok, na.rm = TRUE)
    if (invalid_count > 0) {
      showNotification(
        paste0("Loaded ", invalid_count, " invalid custom-country definition(s). They are ignored until corrected."),
        type = "warning",
        duration = 8
      )
      custom_country_warning_shown(TRUE)
    }
  })

  validate_custom_country_builder_inputs <- function(custom_name, formula_text, existing_name = NULL) {
    name_trim <- trimws(as.character(custom_name %||% ""))
    formula_trim <- trimws(as.character(formula_text %||% ""))

    if (!nzchar(name_trim)) {
      return(list(ok = FALSE, message = "Custom country name is required.", parsed = NULL, name = name_trim, formula = formula_trim))
    }

    if (!nzchar(formula_trim)) {
      return(list(ok = FALSE, message = "Formula is required.", parsed = NULL, name = name_trim, formula = formula_trim))
    }

    native_country_choices <- custom_country_native_choice_map(
      source_scope = active_custom_scope(),
      frequency = input$data_frequency %||% "monthly"
    )
    reserved_names <- unique(c(
      CUSTOM_COUNTRY_RESERVED_NAMES,
      names(native_country_choices),
      unname(native_country_choices)
    ))
    reserved_names <- tolower(trimws(as.character(reserved_names)))
    reserved_names <- reserved_names[!is.na(reserved_names) & nzchar(reserved_names)]

    if (tolower(name_trim) %in% reserved_names) {
      return(list(
        ok = FALSE,
        message = "This custom country name is reserved or conflicts with an existing native country label/code.",
        parsed = NULL,
        name = name_trim,
        formula = formula_trim
      ))
    }

    existing_names <- custom_countries_for_scope()$custom_name
    duplicate_names <- existing_names[tolower(existing_names) == tolower(name_trim)]
    if (!is.null(existing_name) && nzchar(existing_name)) {
      duplicate_names <- duplicate_names[tolower(duplicate_names) != tolower(existing_name)]
    }
    if (length(duplicate_names) > 0) {
      return(list(ok = FALSE, message = "A custom country with this name already exists.", parsed = NULL, name = name_trim, formula = formula_trim))
    }

    parsed <- tryCatch(
      parse_custom_country_formula(
        formula_text = formula_trim,
        source_scope = active_custom_scope(),
        frequency = input$data_frequency %||% "monthly",
        custom_country_names = custom_countries_for_scope()$custom_name
      ),
      error = function(e) e
    )
    if (inherits(parsed, "error")) {
      return(list(ok = FALSE, message = conditionMessage(parsed), parsed = NULL, name = name_trim, formula = formula_trim))
    }

    existing_dependency_df <- custom_countries_enriched() %>%
      transmute(
        custom_name = as.character(.data$custom_name),
        referenced_custom_countries = .data$referenced_custom_countries
      )

    if (!is.null(existing_name) && nzchar(existing_name)) {
      existing_dependency_df <- existing_dependency_df %>%
        filter(tolower(.data$custom_name) != tolower(existing_name))
    }

    candidate_dependency_df <- bind_rows(
      existing_dependency_df,
      tibble::tibble(
        custom_name = name_trim,
        referenced_custom_countries = list(parsed$referenced_custom_countries %||% character())
      )
    )
    cycle_details <- detect_custom_country_cycles(candidate_dependency_df)
    candidate_key <- tolower(name_trim)
    cycle_nodes <- tolower(trimws(as.character(cycle_details$cycle_nodes %||% character())))
    cycle_nodes <- cycle_nodes[!is.na(cycle_nodes) & nzchar(cycle_nodes)]

    if (isTRUE(cycle_details$has_cycle) && candidate_key %in% cycle_nodes) {
      cycle_message <- if (length(cycle_details$cycles) > 0) {
        paste0(" Recursive path: ", cycle_details$cycles[[1]], ".")
      } else {
        ""
      }
      return(list(
        ok = FALSE,
        message = paste0("Custom country recursion is not allowed.", cycle_message),
        parsed = NULL,
        name = name_trim,
        formula = formula_trim
      ))
    }

    normalized_formula <- parsed$normalized_formula %||% formula_trim
    source_scope <- active_custom_scope()
    generated_id <- build_deterministic_custom_country_id(name_trim, normalized_formula, source_scope)

    list(
      ok = TRUE,
      message = "Valid formula.",
      parsed = parsed,
      name = name_trim,
      formula = formula_trim,
      normalized_formula = normalized_formula,
      source_scope = source_scope,
      custom_country_id = generated_id
    )
  }

  output$custom_country_builder_validation_ui <- renderUI({
    req(input$custom_country_builder_name, input$custom_country_builder_formula)

    existing_name <- if (!is.null(input$custom_country_builder_existing) && input$custom_country_builder_existing != "__new__") {
      input$custom_country_builder_existing
    } else {
      NULL
    }

    validation <- validate_custom_country_builder_inputs(
      custom_name = input$custom_country_builder_name,
      formula_text = input$custom_country_builder_formula,
      existing_name = existing_name
    )

    if (validation$ok) {
      parsed <- validation$parsed
      referenced_native <- parsed$referenced_countries %||% character()
      referenced_custom <- parsed$referenced_custom_countries %||% character()

      div(
        style = "padding: 8px; background-color: #d4edda; border: 1px solid #c3e6cb; color: #155724; border-radius: 4px;",
        strong("Formula is valid."),
        div(style = "margin-top: 4px;", paste0("Normalized: ", validation$normalized_formula)),
        div(style = "margin-top: 4px;", paste0("Referenced native countries: ", length(referenced_native))),
        div(style = "margin-top: 4px;", paste0("Referenced custom countries: ", length(referenced_custom)))
      )
    } else {
      div(
        style = "padding: 8px; background-color: #f8d7da; border: 1px solid #f5c6cb; color: #721c24; border-radius: 4px;",
        strong("Cannot save yet."),
        div(style = "margin-top: 4px;", validation$message)
      )
    }
  })

  show_custom_country_builder_modal <- function(selected_existing = "__new__") {
    custom_names <- custom_countries_for_scope()$custom_name
    modal_existing_choices <- c("Create new custom country" = "__new__")
    if (length(custom_names) > 0) {
      modal_existing_choices <- c(modal_existing_choices, stats::setNames(custom_names, custom_names))
    }

    selected_value <- if (!is.null(selected_existing) && selected_existing %in% modal_existing_choices) {
      selected_existing
    } else {
      "__new__"
    }

    showModal(modalDialog(
      title = "Custom Country Type Builder",
      size = "l",
      fluidRow(
        column(
          width = 8,
          selectInput(
            inputId = "custom_country_builder_existing",
            label = "Existing custom countries:",
            choices = modal_existing_choices,
            selected = selected_value
          ),
          textInput(
            inputId = "custom_country_builder_name",
            label = "Custom country name:"
          ),
          textAreaInput(
            inputId = "custom_country_builder_formula",
            label = "Formula (use {Country} tokens):",
            placeholder = "Example: {United States} + {Mexico} - 0.25 * {Canada}",
            rows = 6,
            width = "100%"
          ),
          div(
            style = "font-size: 12px; color: #6c757d; margin-bottom: 8px;",
            "Allowed operators: +, -, *, parentheses. Multiplication must be scalar x {Country Token}."
          ),
          uiOutput("custom_country_builder_validation_ui")
        ),
        column(
          width = 4,
          div(style = "border-left: 1px solid #e9ecef; padding-left: 10px;", uiOutput("custom_country_builder_quick_insert_ui"))
        )
      ),
      footer = tagList(
        actionButton("custom_country_builder_save_new", "Save New", class = "btn-primary"),
        actionButton("custom_country_builder_update", "Update", class = "btn-secondary"),
        actionButton("custom_country_builder_delete", "Delete", class = "btn-warning"),
        actionButton("custom_country_builder_clear_all", "Clear All", class = "btn-danger"),
        modalButton("Cancel")
      ),
      easyClose = TRUE
    ))
  }

  observeEvent(input$custom_country_builder_existing, {
    req(input$custom_country_builder_existing)

    if (identical(input$custom_country_builder_existing, "__new__")) {
      updateTextInput(session, "custom_country_builder_name", value = "")
      updateTextAreaInput(session, "custom_country_builder_formula", value = "")
      return()
    }

    row <- custom_countries_for_scope() %>%
      filter(.data$custom_name == input$custom_country_builder_existing)
    if (nrow(row) == 0) return()

    updateTextInput(session, "custom_country_builder_name", value = row$custom_name[1])
    updateTextAreaInput(session, "custom_country_builder_formula", value = row$formula[1])
  }, ignoreInit = TRUE)

  observeEvent(input$custom_country_builder_save_new, {
    validation <- validate_custom_country_builder_inputs(
      custom_name = input$custom_country_builder_name,
      formula_text = input$custom_country_builder_formula
    )
    if (!validation$ok) {
      showNotification(validation$message, type = "error")
      return()
    }

    timestamp <- as.character(Sys.time())
    current_df <- as_tibble(custom_countries_data())
    new_row <- tibble::tibble(
      custom_country_id = validation$custom_country_id,
      custom_name = validation$name,
      formula = validation$formula,
      normalized_formula = validation$normalized_formula,
      source_scope = validation$source_scope,
      created_at = timestamp,
      updated_at = timestamp,
      version = "1"
    )

    next_df <- bind_rows(current_df, new_row)
    next_df_out <- as.data.frame(next_df, stringsAsFactors = FALSE)
    save_custom_countries(next_df_out, user_custom_countries_path)
    custom_countries_data(next_df_out)

    removeModal()
    showNotification("Custom country saved.", type = "message")
  })

  observeEvent(input$custom_country_builder_update, {
    existing_name <- input$custom_country_builder_existing
    if (is.null(existing_name) || identical(existing_name, "__new__")) {
      showNotification("Select an existing custom country to update.", type = "error")
      return()
    }

    validation <- validate_custom_country_builder_inputs(
      custom_name = input$custom_country_builder_name,
      formula_text = input$custom_country_builder_formula,
      existing_name = existing_name
    )
    if (!validation$ok) {
      showNotification(validation$message, type = "error")
      return()
    }

    current_df <- as_tibble(custom_countries_data()) %>%
      mutate(
        source_scope = vapply(
          as.character(.data$source_scope),
          normalize_custom_definition_scope,
          character(1),
          default_scope = "export_sales"
        )
      )

    target_idx <- which(current_df$custom_name == existing_name & current_df$source_scope == validation$source_scope)
    if (length(target_idx) == 0) {
      showNotification("The selected custom country no longer exists.", type = "error")
      return()
    }

    row_idx <- target_idx[[1]]
    current_df$custom_country_id[row_idx] <- validation$custom_country_id
    current_df$custom_name[row_idx] <- validation$name
    current_df$formula[row_idx] <- validation$formula
    current_df$normalized_formula[row_idx] <- validation$normalized_formula
    current_df$updated_at[row_idx] <- as.character(Sys.time())
    current_df$version[row_idx] <- "1"

    current_df_out <- as.data.frame(current_df, stringsAsFactors = FALSE)
    save_custom_countries(current_df_out, user_custom_countries_path)
    custom_countries_data(current_df_out)

    removeModal()
    showNotification("Custom country updated.", type = "message")
  })

  observeEvent(input$custom_country_builder_delete, {
    existing_name <- input$custom_country_builder_existing
    if (is.null(existing_name) || identical(existing_name, "__new__")) {
      showNotification("Select an existing custom country to delete.", type = "error")
      return()
    }

    showModal(modalDialog(
      title = "Delete Custom Country",
      paste0("Delete custom country '", existing_name, "'?"),
      footer = tagList(
        actionButton("custom_country_builder_confirm_delete", "Delete", class = "btn-danger"),
        modalButton("Cancel")
      ),
      easyClose = TRUE
    ))
  })

  observeEvent(input$custom_country_builder_confirm_delete, {
    existing_name <- input$custom_country_builder_existing
    if (is.null(existing_name) || identical(existing_name, "__new__")) {
      return()
    }

    next_df <- as_tibble(custom_countries_data()) %>%
      mutate(
        source_scope = vapply(
          as.character(.data$source_scope),
          normalize_custom_definition_scope,
          character(1),
          default_scope = "export_sales"
        )
      ) %>%
      filter(!(.data$custom_name == existing_name & .data$source_scope == active_custom_scope()))

    next_df_out <- as.data.frame(next_df, stringsAsFactors = FALSE)
    save_custom_countries(next_df_out, user_custom_countries_path)
    custom_countries_data(next_df_out)

    removeModal()
    removeModal()
    showNotification("Custom country deleted.", type = "message")
  })

  observeEvent(input$custom_country_builder_clear_all, {
    showModal(modalDialog(
      title = "Clear All Custom Countries",
      "Are you sure you'd like to clear all custom countries for the active source scope?",
      footer = tagList(
        actionButton("custom_country_builder_confirm_clear_all", "Yes, Clear All", class = "btn-danger"),
        modalButton("Cancel")
      ),
      easyClose = TRUE
    ))
  })

  observeEvent(input$custom_country_builder_confirm_clear_all, {
    remaining_df <- as_tibble(custom_countries_data()) %>%
      mutate(
        source_scope = vapply(
          as.character(.data$source_scope),
          normalize_custom_definition_scope,
          character(1),
          default_scope = "export_sales"
        )
      ) %>%
      filter(.data$source_scope != active_custom_scope())

    remaining_df_out <- as.data.frame(remaining_df, stringsAsFactors = FALSE)
    save_custom_countries(remaining_df_out, user_custom_countries_path)
    custom_countries_data(remaining_df_out)

    removeModal()
    removeModal()
    showNotification("All custom countries cleared for the active data scope.", type = "warning")
  })

  observeEvent(input$country_choice, {
    choice <- as.character(input$country_choice %||% "")
    choice <- choice[!is.na(choice) & nzchar(choice)]
    if (length(choice) == 0L || !identical(choice[[1L]], CUSTOM_COUNTRY_BUILDER_CHOICE)) {
      return()
    }

    fallback_choices <- tryCatch(country_choice_options(), error = function(e) NULL)
    fallback_values <- unique(as.character(unname(fallback_choices) %||% character(0)))
    fallback_values <- fallback_values[
      !is.na(fallback_values) & nzchar(fallback_values) & fallback_values != CUSTOM_COUNTRY_BUILDER_CHOICE
    ]

    fallback <- if (exists("last_valid_sidebar_country", mode = "function")) {
      isolate(last_valid_sidebar_country())
    } else {
      NULL
    }
    fallback <- as.character(fallback %||% character(0))
    fallback <- fallback[!is.na(fallback) & nzchar(fallback)]
    fallback <- if (length(fallback) > 0) fallback[[1L]] else NULL

    if (is.null(fallback) || !(fallback %in% fallback_values)) {
      if ("GRAND_TOTAL" %in% fallback_values) {
        fallback <- "GRAND_TOTAL"
      } else if (length(fallback_values) > 0) {
        fallback <- fallback_values[[1L]]
      } else {
        fallback <- "GRAND_TOTAL"
      }
    }

    updateSelectizeInput(session, "country_choice", selected = fallback)
    show_custom_country_builder_modal()
  }, ignoreInit = TRUE)

  format_myc_type_commodity_choices <- function(choices, include_builder) {
    myc_type_mode_active <- identical(input$main_tabs_panel, "Market Year Comparison Tool") &&
      identical(market_year_comparison_mode(), "type")

    if (!isTRUE(myc_type_mode_active) || length(choices) == 0) {
      return(choices)
    }

    if (is.list(choices) && !is.null(names(choices))) {
      grouped_result <- list()

      for (group_name in names(choices)) {
        group_choices <- choices[[group_name]]
        if (length(group_choices) == 0) next

        group_include_builder <- isTRUE(include_builder) && any(unname(group_choices) == CUSTOM_BUILDER_CHOICE)
        formatted_group <- format_myc_type_commodity_choices(group_choices, include_builder = group_include_builder)
        if (length(formatted_group) == 0) next

        grouped_result[[group_name]] <- formatted_group
      }

      return(grouped_result)
    }

    choice_df <- tibble::tibble(
      choice_label = names(choices),
      choice_value = unname(choices),
      original_order = seq_along(choices)
    )

    builder_rows <- choice_df %>% filter(.data$choice_value == CUSTOM_BUILDER_CHOICE)
    choice_df <- choice_df %>% filter(.data$choice_value != CUSTOM_BUILDER_CHOICE)

    share_data <- tryCatch(partner_share_data(), error = function(e) NULL)
    if (
      !is.null(share_data) &&
      identical(share_data$comparison_mode, "type") &&
      !is.null(share_data$df) &&
      nrow(share_data$df) > 0
    ) {
      current_share_df <- share_data$df %>%
        filter(.data$market_year == share_data$current_my) %>%
        group_by(.data$commodity, .data$comparison_item) %>%
        summarise(
          share_pct = first(.data$share_pct),
          plot_metric = first(.data$plot_metric),
          .groups = "drop"
        )

      choice_df <- choice_df %>%
        left_join(
          current_share_df,
          by = c("choice_value" = "commodity", "choice_label" = "comparison_item")
        ) %>%
        mutate(
          choice_label = dplyr::if_else(
            !is.na(.data$share_pct),
            paste0(.data$choice_label, " (", sprintf("%.1f%%", .data$share_pct * 100), ")"),
            .data$choice_label
          )
        )

      current_sort <- if (!is.null(input$country_sort)) input$country_sort else "value"
      if (identical(current_sort, "value")) {
        if (isTRUE(input$reverse_sort)) {
          choice_df <- choice_df %>%
            arrange(dplyr::coalesce(.data$share_pct, Inf), dplyr::coalesce(.data$plot_metric, Inf), .data$choice_label)
        } else {
          choice_df <- choice_df %>%
            arrange(dplyr::desc(dplyr::coalesce(.data$share_pct, -Inf)), dplyr::desc(dplyr::coalesce(.data$plot_metric, -Inf)), .data$choice_label)
        }
      }
    }

    if (!identical(if (!is.null(input$country_sort)) input$country_sort else "value", "value")) {
      choice_df <- choice_df %>% arrange(.data$original_order)
    }

    result <- stats::setNames(choice_df$choice_value, choice_df$choice_label)
    if (include_builder && nrow(builder_rows) > 0) {
      result <- c(result, stats::setNames(builder_rows$choice_value, builder_rows$choice_label))
    }

    result
  }

  vp_type_choice_base_cache <- new.env(parent = emptyenv())

  normalize_vp_type_choice_cache_value <- function(value, default = "<none>") {
    value <- trimws(as.character(value %||% character(0)))
    value <- value[!is.na(value) & nzchar(value)]
    if (length(value) == 0L) return(default)
    value[[1L]]
  }

  encode_vp_type_choice_cache_value <- function(value) {
    value <- normalize_vp_type_choice_cache_value(value)
    paste0(nchar(value, type = "bytes"), ":", value)
  }

  current_vp_type_choice_base_cache_key <- function(myc_type_mode_active) {
    resolved <- if (exists("resolve_vp_hierarchy_tokens", mode = "function")) {
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
      source_choice = active_source_choice(),
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
      myc_type_mode_active = if (isTRUE(myc_type_mode_active)) "TRUE" else "FALSE"
    )

    paste(vapply(parts, encode_vp_type_choice_cache_value, character(1)), collapse = "\036")
  }

  record_vp_type_choice_base_cache_event <- function(event_name, cache_key) {
    if (!exists("record_cache_body_execution", mode = "function")) {
      return(invisible(NULL))
    }

    record_cache_body_execution(
      session,
      paste0("type_choice_base_values_cache_", event_name),
      details = list(
        source = active_source_choice(),
        active_tab = input$main_tabs_panel %||% "unknown",
        cache_key_prefix = substr(cache_key, 1L, 120L)
      )
    )
    invisible(NULL)
  }

  build_commodity_choice_base_values <- function(include_builder = FALSE) {
    myc_type_mode_active <- identical(input$main_tabs_panel, "Market Year Comparison Tool") &&
      identical(market_year_comparison_mode(), "type")

    if (identical(active_source_choice(), "vp_trade")) {
      cache_key <- current_vp_type_choice_base_cache_key(myc_type_mode_active)
      if (exists(cache_key, envir = vp_type_choice_base_cache, inherits = FALSE)) {
        record_vp_type_choice_base_cache_event("hit", cache_key)
        vp_native_choices <- get(cache_key, envir = vp_type_choice_base_cache, inherits = FALSE)
        custom_names <- custom_types_enriched() %>%
          filter(.data$parse_ok) %>%
          pull(.data$custom_name)
        return(build_rice_type_choices(vp_native_choices, custom_names, include_builder = include_builder))
      }

      record_vp_type_choice_base_cache_event("miss", cache_key)
      vp_rows <- if (exists("vp_trade_rows_or_empty", mode = "function")) {
        vp_trade_rows_or_empty(require_non_empty = FALSE)
      } else if (exists("rice_data_vp_trade_monthly", inherits = TRUE) && is.data.frame(rice_data_vp_trade_monthly)) {
        rice_data_vp_trade_monthly
      } else {
        data.frame()
      }
      vp_trade_flow <- input$vp_trade_flow_choice %||% "export"
      vp_commodity_name <- input$vp_commodity_name_choice %||% NULL

      if (exists("filter_vp_rows_for_resolved_hierarchy", mode = "function")) {
        vp_rows <- filter_vp_rows_for_resolved_hierarchy(
          vp_rows = vp_rows,
          vp_trade_flow_choice = vp_trade_flow,
          vp_group_choice = input$vp_group_choice,
          vp_subgroup_choice = input$vp_subgroup_choice,
          vp_market_segment_choice = input$vp_market_segment_choice,
          vp_commodity_name_choice = NULL,
          vp_commodity_detail_choice = NULL,
          vp_filter_purpose = "type_choice_base_values"
        )

        vp_commodity_values <- if ("CommodityName" %in% names(vp_rows)) {
          sort(unique(as.character(vp_rows$CommodityName)))
        } else {
          character(0)
        }
        vp_commodity_values <- vp_commodity_values[!is.na(vp_commodity_values) & nzchar(vp_commodity_values)]

        vp_commodity_name_value <- trimws(as.character(vp_commodity_name %||% character(0)))
        vp_commodity_name_value <- vp_commodity_name_value[!is.na(vp_commodity_name_value) & nzchar(vp_commodity_name_value)]
        vp_commodity_name_value <- if (length(vp_commodity_name_value) > 0L) vp_commodity_name_value[[1L]] else NULL
        if (is.null(vp_commodity_name_value) || !(vp_commodity_name_value %in% vp_commodity_values)) {
          vp_commodity_name_value <- if (length(vp_commodity_values) > 0L) vp_commodity_values[[1L]] else NULL
        }

        if (!is.null(vp_commodity_name_value) && "CommodityName" %in% names(vp_rows)) {
          vp_rows <- vp_rows[vp_rows$CommodityName == vp_commodity_name_value, , drop = FALSE]
        }
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
        if (!is.null(vp_commodity_name) && nzchar(as.character(vp_commodity_name)) && "CommodityName" %in% names(vp_rows)) {
          vp_rows <- vp_rows[vp_rows$CommodityName == vp_commodity_name, , drop = FALSE]
        }
      }

      vp_detail_values <- if ("CommodityDetail" %in% names(vp_rows)) sort(unique(as.character(vp_rows$CommodityDetail))) else character(0)
      vp_detail_values <- vp_detail_values[!is.na(vp_detail_values) & nzchar(vp_detail_values)]
      vp_all_label <- if (exists("vp_all_type_label", mode = "character")) vp_all_type_label else "All"
      vp_all_excluding_label <- if (exists("vp_all_excluding_juice_label", mode = "character")) vp_all_excluding_juice_label else "All - excluding juice"
      if (vp_all_excluding_label %in% vp_detail_values) {
        vp_detail_values <- vp_detail_values[vp_detail_values != vp_all_label]
      }
      if (isTRUE(myc_type_mode_active)) {
        vp_detail_values <- vp_detail_values[vp_detail_values != vp_all_label]
      } else if (vp_all_label %in% vp_detail_values) {
        vp_detail_values <- c(vp_all_label, vp_detail_values[vp_detail_values != vp_all_label])
      }

      custom_names <- custom_types_enriched() %>%
        filter(.data$parse_ok) %>%
        pull(.data$custom_name)

      vp_native_choices <- stats::setNames(vp_detail_values, vp_detail_values)
      assign(cache_key, vp_native_choices, envir = vp_type_choice_base_cache)
      return(build_rice_type_choices(vp_native_choices, custom_names, include_builder = include_builder))
    }

    native_values <- active_native_commodities()

    custom_names <- custom_types_enriched() %>%
      filter(.data$parse_ok) %>%
      pull(.data$custom_name)

    choices <- build_rice_type_choices(native_values, custom_names, include_builder = include_builder)
    aggregate_label <- default_commodity_choice_value()
    if (identical(active_source_choice(), "census") && !(aggregate_label %in% unname(choices))) {
      choices <- c(stats::setNames(aggregate_label, aggregate_label), choices)
    } else if (identical(input$data_source_choice, "hybrid")) {
      hybrid_choices <- if (identical(active_hybrid_trade_flow(), "import")) {
        display_labels <- dplyr::coalesce(
          unname(hybrid_import_commodity_display_labels[native_commodities_hybrid_import]),
          native_commodities_hybrid_import
        )
        setNames(native_commodities_hybrid_import, display_labels)
      } else {
        setNames(native_commodities_hybrid_export, native_commodities_hybrid_export)
      }
      choices <- c(hybrid_choices, choices[!(unname(choices) %in% unname(hybrid_choices))])
    }

    if (isTRUE(myc_type_mode_active)) {
      choices <- choices[unname(choices) != aggregate_label]
    }

    choices
  }

  commodity_choice_values <- reactive({
    custom_names <- custom_types_enriched() %>%
      filter(.data$parse_ok) %>%
      pull(.data$custom_name)

    choices <- build_commodity_choice_base_values(include_builder = TRUE)
    formatted_choices <- format_myc_type_commodity_choices(choices, include_builder = TRUE)
    group_rice_type_choices(formatted_choices, custom_names = custom_names, include_builder = TRUE)
  })

  commodity_choice_display_values <- reactive({
    choices <- commodity_choice_values()
    if (length(choices) == 0) {
      if (identical(active_source_choice(), "vp_trade")) {
        return(character(0))
      }
      return(default_commodity_choice_named())
    }

    choices
  })

  commodity_choice_native_base_values <- reactive({
    build_commodity_choice_base_values(include_builder = FALSE)
  })

  commodity_choice_real_values <- reactive({
    choices <- commodity_choice_native_base_values()
    format_myc_type_commodity_choices(choices, include_builder = FALSE)
  })

  commodity_choice_fallback_values <- reactive({
    choices <- commodity_choice_native_base_values()
    if (length(choices) == 0) {
      if (identical(active_source_choice(), "vp_trade")) {
        return(character(0))
      }
      return(default_commodity_choice_named())
    }

    choices
  })

  custom_type_block_message_for <- function(commodity_name) {
    if (is.null(commodity_name) || identical(commodity_name, CUSTOM_BUILDER_CHOICE)) return(NULL)

    defs <- custom_types_enriched() %>%
      filter(.data$parse_ok, .data$custom_name == commodity_name)

    if (nrow(defs) == 0) return(NULL)

    missing_refs <- setdiff(defs$referenced_commodities[[1]], active_native_commodities())
    if (length(missing_refs) == 0) return(NULL)

    freq_label <- if (identical(input$data_frequency, "monthly")) "monthly" else "weekly"
    paste0(
      "Selected custom type cannot be computed for ", freq_label,
      " data because these ", tolower(COMMODITY_TYPE_LABEL %||% "commodity type"), " values are unavailable: ",
      paste(missing_refs, collapse = ", "),
      "."
    )
  }

  custom_type_block_message <- reactive({
    custom_type_block_message_for(input$commodity_choice)
  })

  output$custom_type_warning_ui <- renderUI({
    msg <- custom_type_block_message()
    if (is.null(msg)) return(NULL)

    div(
      style = "padding: 8px; background-color: #fff3cd; border: 1px solid #f5c6cb; color: #856404; border-radius: 4px; margin-top: -4px; margin-bottom: 10px;",
      strong("Custom type blocked for current frequency."),
      div(style = "margin-top: 4px;", msg)
    )
  })

  output$commodity_choice_ui <- renderUI({
    start_time <- Sys.time()
    choices <- commodity_choice_display_values()
    fallback_choices <- commodity_choice_fallback_values()
    source_choice <- active_source_choice()
    myc_type_mode_active <- identical(input$main_tabs_panel, "Market Year Comparison Tool") &&
      identical(market_year_comparison_mode(), "type")
    if (length(fallback_choices) == 0) {
      if (identical(source_choice, "vp_trade")) {
        fallback_choices <- character(0)
      } else {
        fallback_choices <- setNames(COMMODITY_AGGREGATE_LABEL, COMMODITY_AGGREGATE_LABEL)
      }
    }
    vp_empty_transition_active <- identical(source_choice, "vp_trade") && length(fallback_choices) == 0
    if (isTRUE(vp_empty_transition_active)) {
      vp_type_empty_choice_transition(TRUE)
    }

    current_choice <- input$commodity_choice
    selected <- current_choice
    builder_selected <- identical(selected, CUSTOM_BUILDER_CHOICE)
    stale_vp_builder_choice <- identical(source_choice, "vp_trade") &&
      identical(selected, CUSTOM_BUILDER_CHOICE) &&
      isTRUE(vp_type_empty_choice_transition())
    automatic_choice_pending_restore <-
      !isTRUE(myc_type_mode_active) &&
      exists("is_myc_automatic_commodity_value", mode = "function") &&
      isTRUE(is_myc_automatic_commodity_value(current_choice))
    current_choice_valid <- !isTRUE(automatic_choice_pending_restore) &&
      !isTRUE(stale_vp_builder_choice) &&
      !isTRUE(builder_selected) &&
      !is.null(selected) && selected %in% fallback_choices
    if (isTRUE(stale_vp_builder_choice)) {
      fallback <- if ("All" %in% fallback_choices) {
        "All"
      } else if (length(fallback_choices) > 0) {
        remembered_fallback <- last_non_custom_commodity()
        if (!is.null(remembered_fallback) && remembered_fallback %in% fallback_choices) remembered_fallback else unname(fallback_choices[1])
      } else {
        NULL
      }
      selected <- fallback
    } else if (is.null(selected) || !(selected %in% fallback_choices)) {
      if (identical(source_choice, "vp_trade") && length(fallback_choices) == 0) {
        selected <- NULL
      } else {
        fallback <- last_non_custom_commodity()
        if (is.null(fallback) || !(fallback %in% fallback_choices)) {
          fallback <- if (identical(source_choice, "vp_trade") && "All" %in% fallback_choices) {
            "All"
          } else if (COMMODITY_AGGREGATE_LABEL %in% fallback_choices) {
            COMMODITY_AGGREGATE_LABEL
          } else {
            unname(fallback_choices[1])
          }
        }
        selected <- fallback
      }
    } else if (isTRUE(automatic_choice_pending_restore)) {
      if (identical(source_choice, "vp_trade") && length(fallback_choices) == 0) {
        selected <- NULL
      } else {
        fallback <- last_non_custom_commodity()
        if (is.null(fallback) || !(fallback %in% fallback_choices)) {
          fallback <- if (identical(source_choice, "vp_trade") && "All" %in% fallback_choices) {
            "All"
          } else if (COMMODITY_AGGREGATE_LABEL %in% fallback_choices) {
            COMMODITY_AGGREGATE_LABEL
          } else {
            unname(fallback_choices[1])
          }
        }
        selected <- fallback
      }
    }

    myc_transition_trace_safe(
      "commodity_choice_ui_render",
      details = list(
        source = input$data_source_choice,
        frequency = input$data_frequency,
        current_choice = if (!is.null(current_choice)) current_choice else "NULL",
        current_is_valid = !is.null(current_choice) && current_choice %in% fallback_choices,
        selected = selected,
        choice_count = length(fallback_choices),
        choice_sample = paste(head(fallback_choices, 8), collapse = " | "),
        stale_vp_builder_choice = isTRUE(stale_vp_builder_choice),
        vp_empty_transition_pending = isTRUE(vp_type_empty_choice_transition()),
        render_only_recompute = !isTRUE(identical(current_choice, selected))
      )
    )

    resolved_label <- if (identical(active_source_choice(), "vp_trade")) {
      "Type"
    } else {
      COMMODITY_TYPE_LABEL
    }

    result <- selectizeInput(
      inputId = "commodity_choice",
      label = resolved_label,
      choices = choices,
      selected = selected,
      multiple = FALSE,
      options = list(
        placeholder = COMMODITY_TYPE_PLACEHOLDER,
        openOnFocus = TRUE,
        closeAfterSelect = TRUE,
        maxOptions = 250
      )
    )

    log_perf(
      "output$commodity_choice_ui",
      start_time,
      details = list(
        source = input$data_source_choice,
        frequency = input$data_frequency,
        scope = active_custom_scope(),
        selected = selected,
        choices = length(fallback_choices),
        stale_vp_builder_choice = isTRUE(stale_vp_builder_choice),
        vp_empty_transition_pending = isTRUE(vp_type_empty_choice_transition())
      )
    )

    result
  })

  validate_custom_builder_inputs <- function(custom_name, formula_text, existing_name = NULL) {
    name_trim <- trimws(as.character(custom_name))
    formula_trim <- trimws(as.character(formula_text))

    if (!nzchar(name_trim)) {
      return(list(ok = FALSE, message = "Custom type name is required.", parsed = NULL, name = name_trim, formula = formula_trim))
    }

    if (!nzchar(formula_trim)) {
      return(list(ok = FALSE, message = "Formula is required.", parsed = NULL, name = name_trim, formula = formula_trim))
    }

    if (tolower(name_trim) %in% tolower(c(CUSTOM_RESERVED_NAMES, active_parse_commodities(), "Custom"))) {
      return(list(ok = FALSE, message = paste0("This custom type name is reserved or conflicts with an existing native ", tolower(COMMODITY_TYPE_LABEL %||% "commodity type"), "."), parsed = NULL, name = name_trim, formula = formula_trim))
    }

    existing_names <- custom_types_for_scope()$custom_name
    duplicate_names <- existing_names[tolower(existing_names) == tolower(name_trim)]
    if (!is.null(existing_name) && nzchar(existing_name)) {
      duplicate_names <- duplicate_names[tolower(duplicate_names) != tolower(existing_name)]
    }
    if (length(duplicate_names) > 0) {
      return(list(ok = FALSE, message = "A custom type with this name already exists.", parsed = NULL, name = name_trim, formula = formula_trim))
    }

    parsed <- tryCatch(
      parse_custom_formula(formula_trim, active_parse_commodities()),
      error = function(e) e
    )
    if (inherits(parsed, "error")) {
      return(list(ok = FALSE, message = conditionMessage(parsed), parsed = NULL, name = name_trim, formula = formula_trim))
    }

    missing_refs <- setdiff(parsed$referenced_commodities, active_native_commodities())
    if (length(missing_refs) > 0) {
      freq_label <- if (identical(input$data_frequency, "monthly")) "monthly" else "weekly"
      return(list(
        ok = FALSE,
        message = paste0("Formula references ", tolower(COMMODITY_TYPE_LABEL %||% "commodity type"), " values unavailable in ", freq_label, " data: ", paste(missing_refs, collapse = ", "), "."),
        parsed = NULL,
        name = name_trim,
        formula = formula_trim
      ))
    }

    basis_registry <- tryCatch(product_basis_registry(), error = function(...) product_basis_empty_registry())
    product_basis_summary <- product_basis_summary_for_refs(
      referenced_commodities = parsed$referenced_commodities,
      registry_df = basis_registry,
      coefficients = parsed$coefficients
    )

    list(
      ok = TRUE,
      message = "Valid formula.",
      parsed = parsed,
      name = name_trim,
      formula = formula_trim,
      product_basis_summary = product_basis_summary
    )
  }

  output$custom_builder_validation_ui <- renderUI({
    req(input$custom_builder_name, input$custom_builder_formula)

    existing_name <- if (!is.null(input$custom_builder_existing) && input$custom_builder_existing != "__new__") {
      input$custom_builder_existing
    } else {
      NULL
    }

    validation <- validate_custom_builder_inputs(input$custom_builder_name, input$custom_builder_formula, existing_name)
    if (validation$ok) {
      product_basis_summary <- validation$product_basis_summary
      product_basis_summary_text <- if (!is.null(product_basis_summary) && nzchar(product_basis_summary$summary %||% "")) {
        product_basis_summary$summary
      } else {
        "Unavailable"
      }
      product_basis_warning <- if (!is.null(product_basis_summary) && isTRUE(product_basis_summary$mixed)) {
        div(style = "margin-top: 4px;", "Product-weight may combine components with different, variable, or unknown product bases.")
      } else {
        NULL
      }

      div(
        style = "padding: 8px; background-color: #d4edda; border: 1px solid #c3e6cb; color: #155724; border-radius: 4px;",
        strong("Formula is valid."),
        div(style = "margin-top: 4px;", paste0("Normalized: ", validation$parsed$normalized_formula)),
        div(style = "margin-top: 4px;", paste0("Product basis: ", product_basis_summary_text)),
        product_basis_warning
      )
    } else {
      div(
        style = "padding: 8px; background-color: #f8d7da; border: 1px solid #f5c6cb; color: #721c24; border-radius: 4px;",
        strong("Cannot save yet."),
        div(style = "margin-top: 4px;", validation$message)
      )
    }
  })

  output$custom_builder_quick_insert_ui <- renderUI({
    native_values <- active_native_commodities()
    if (length(native_values) == 0) return(NULL)

    type_buttons <- lapply(native_values, function(name) {
      tags$button(
        type = "button",
        class = "btn btn-default btn-sm formula-insert-btn",
        style = "margin: 3px;",
        `data-insert` = paste0("{", name, "}"),
        `data-target` = "custom_builder_formula",
        name
      )
    })

    ops <- c("+", "-", "*")
    op_buttons <- lapply(ops, function(op) {
      tags$button(
        type = "button",
        class = "btn btn-info btn-sm formula-insert-btn",
        style = "margin: 3px; min-width: 36px;",
        `data-insert` = paste0(" ", op, " "),
        `data-target` = "custom_builder_formula",
        op
      )
    })

    tagList(
      h5("Quick Insert"),
      div(style = "margin-bottom: 8px;", op_buttons),
      div(style = "max-height: 220px; overflow-y: auto; border: 1px solid #ddd; border-radius: 4px; padding: 6px;", type_buttons)
    )
  })

  show_custom_builder_modal <- function(selected_existing = "__new__") {
    custom_names <- custom_types_for_scope()$custom_name

    modal_existing_choices <- c("Create new custom type" = "__new__")
    if (length(custom_names) > 0) {
      modal_existing_choices <- c(modal_existing_choices, setNames(custom_names, custom_names))
    }

    selected_value <- if (!is.null(selected_existing) && selected_existing %in% modal_existing_choices) {
      selected_existing
    } else {
      "__new__"
    }

    showModal(modalDialog(
      title = paste0("Custom ", COMMODITY_TYPE_LABEL, " Builder"),
      size = "l",
      fluidRow(
        column(
          width = 8,
          selectInput(
            inputId = "custom_builder_existing",
            label = "Existing custom types:",
            choices = modal_existing_choices,
            selected = selected_value
          ),
          textInput(
            inputId = "custom_builder_name",
            label = "Custom type name:"
          ),
          textAreaInput(
            inputId = "custom_builder_formula",
            label = paste0("Formula (use {", COMMODITY_TYPE_LABEL, "} tokens):"),
            placeholder = "Example: 2 * {Type A} - {Type B}",
            rows = 5,
            width = "100%"
          ),
          div(style = "font-size: 12px; color: #6c757d; margin-bottom: 8px;", paste0("Allowed operators: +, -, *, parentheses. Multiplication must be scalar x ", tolower(COMMODITY_TYPE_LABEL %||% "commodity type"), " only.")),
          uiOutput("custom_builder_validation_ui")
        ),
        column(
          width = 4,
          div(style = "border-left: 1px solid #e9ecef; padding-left: 10px;", uiOutput("custom_builder_quick_insert_ui"))
        )
      ),
      footer = tagList(
        actionButton("custom_builder_save_new", "Save New", class = "btn-primary"),
        actionButton("custom_builder_update", "Update", class = "btn-secondary"),
        actionButton("custom_builder_delete", "Delete", class = "btn-warning"),
        actionButton("custom_builder_clear_all", "Clear All", class = "btn-danger"),
        modalButton("Cancel")
      ),
      easyClose = TRUE
    ))
  }

  output$custom_country_builder_quick_insert_ui <- renderUI({
    native_choice_map <- custom_country_native_choice_map(
      source_scope = active_custom_scope(),
      frequency = input$data_frequency %||% "monthly"
    )
    native_labels <- names(native_choice_map %||% character(0))
    native_labels <- trimws(as.character(native_labels))
    native_labels <- unique(native_labels[!is.na(native_labels) & nzchar(native_labels)])

    if (length(native_labels) == 0) return(NULL)

    country_buttons <- lapply(native_labels, function(name) {
      tags$button(
        type = "button",
        class = "btn btn-default btn-sm formula-insert-btn",
        style = "margin: 3px;",
        `data-insert` = paste0("{", name, "}"),
        `data-target` = "custom_country_builder_formula",
        name
      )
    })

    ops <- c("+", "-", "*")
    op_buttons <- lapply(ops, function(op) {
      tags$button(
        type = "button",
        class = "btn btn-info btn-sm formula-insert-btn",
        style = "margin: 3px; min-width: 36px;",
        `data-insert` = paste0(" ", op, " "),
        `data-target` = "custom_country_builder_formula",
        op
      )
    })

    tagList(
      h5("Quick Insert"),
      div(style = "margin-bottom: 8px;", op_buttons),
      div(style = "max-height: 220px; overflow-y: auto; border: 1px solid #ddd; border-radius: 4px; padding: 6px;", country_buttons)
    )
  })

  observeEvent(input$custom_builder_existing, {
    req(input$custom_builder_existing)

    if (identical(input$custom_builder_existing, "__new__")) {
      updateTextInput(session, "custom_builder_name", value = "")
      updateTextAreaInput(session, "custom_builder_formula", value = "")
      return()
    }

    row <- custom_types_for_scope() %>% filter(.data$custom_name == input$custom_builder_existing)
    if (nrow(row) == 0) return()

    updateTextInput(session, "custom_builder_name", value = row$custom_name[1])
    updateTextAreaInput(session, "custom_builder_formula", value = row$formula[1])
  }, ignoreInit = TRUE)

  observeEvent(input$custom_builder_save_new, {
    start_time <- Sys.time()
    validation <- validate_custom_builder_inputs(input$custom_builder_name, input$custom_builder_formula)
    if (!validation$ok) {
      log_perf(
        "observeEvent(custom_builder_save_new)",
        start_time,
        details = list(
          scope = active_custom_scope(),
          status = "validation_error",
          current_rows = nrow(custom_types_for_scope())
        )
      )

      showNotification(validation$message, type = "error")
      return()
    }

    current_df <- as_tibble(custom_types_data())
    current_scope_rows <- nrow(custom_types_for_scope())
    timestamp <- as.character(Sys.time())
    new_row <- tibble(
      custom_name = validation$name,
      formula = validation$formula,
      normalized_formula = validation$parsed$normalized_formula,
      source_scope = active_custom_scope(),
      created_at = timestamp,
      updated_at = timestamp,
      version = "1"
    )

    next_df <- bind_rows(current_df, new_row)
    next_df_out <- as.data.frame(next_df, stringsAsFactors = FALSE)
    save_custom_types(next_df_out, user_custom_types_path)
    custom_types_data(next_df_out)

    removeModal()
    updateSelectizeInput(session, "commodity_choice", selected = validation$name)

    log_perf(
      "observeEvent(custom_builder_save_new)",
      start_time,
      details = list(
        scope = active_custom_scope(),
        status = "saved_new",
        custom_name = validation$name,
        parse_ok = !is.null(validation$parsed),
        rows_before = current_scope_rows,
        rows_after = current_scope_rows + 1L,
        selected_commodity_changed = !identical(input$commodity_choice, validation$name)
        )
      )

    showNotification("Custom type saved.", type = "message")
  })

  observeEvent(input$custom_builder_update, {
    start_time <- Sys.time()
    existing_name <- input$custom_builder_existing
    if (is.null(existing_name) || identical(existing_name, "__new__")) {
      log_perf(
        "observeEvent(custom_builder_update)",
        start_time,
        details = list(
          scope = active_custom_scope(),
          status = "missing_existing_name"
        )
      )

      showNotification("Select an existing custom type to update.", type = "error")
      return()
    }

    validation <- validate_custom_builder_inputs(input$custom_builder_name, input$custom_builder_formula, existing_name = existing_name)
    if (!validation$ok) {
      log_perf(
        "observeEvent(custom_builder_update)",
        start_time,
        details = list(
          scope = active_custom_scope(),
          status = "validation_error",
          existing_name = existing_name,
          current_rows = nrow(custom_types_for_scope())
        )
      )

      showNotification(validation$message, type = "error")
      return()
    }

    current_df <- as_tibble(custom_types_data()) %>%
      mutate(
        source_scope = vapply(as.character(.data$source_scope), normalize_scope_value, character(1))
      )
    current_scope_rows <- sum(current_df$source_scope == active_custom_scope())
    target_idx <- which(current_df$custom_name == existing_name & current_df$source_scope == active_custom_scope())
    if (length(target_idx) == 0) {
      log_perf(
        "observeEvent(custom_builder_update)",
        start_time,
        details = list(
          scope = active_custom_scope(),
          status = "missing_target",
          existing_name = existing_name,
          current_rows = current_scope_rows
        )
      )

      showNotification("The selected custom type no longer exists.", type = "error")
      return()
    }

    current_df$custom_name[target_idx[1]] <- validation$name
    current_df$formula[target_idx[1]] <- validation$formula
    current_df$normalized_formula[target_idx[1]] <- validation$parsed$normalized_formula
    current_df$updated_at[target_idx[1]] <- as.character(Sys.time())

    current_df_out <- as.data.frame(current_df, stringsAsFactors = FALSE)
    save_custom_types(current_df_out, user_custom_types_path)
    custom_types_data(current_df_out)

    removeModal()
    updateSelectizeInput(session, "commodity_choice", selected = validation$name)

    log_perf(
      "observeEvent(custom_builder_update)",
      start_time,
      details = list(
        scope = active_custom_scope(),
        status = "updated",
        previous_name = existing_name,
        custom_name = validation$name,
        parse_ok = !is.null(validation$parsed),
        rows_before = current_scope_rows,
        rows_after = current_scope_rows,
        selected_commodity_changed = !identical(input$commodity_choice, validation$name)
      )
    )

    showNotification("Custom type updated.", type = "message")
  })

  observeEvent(input$custom_builder_delete, {
    existing_name <- input$custom_builder_existing
    if (is.null(existing_name) || identical(existing_name, "__new__")) {
      showNotification("Select an existing custom type to delete.", type = "error")
      return()
    }

    showModal(modalDialog(
      title = "Delete Custom Type",
      paste0("Delete custom type '", existing_name, "'?"),
      footer = tagList(
        actionButton("custom_builder_confirm_delete", "Delete", class = "btn-danger"),
        modalButton("Cancel")
      ),
      easyClose = TRUE
    ))
  })

  observeEvent(input$custom_builder_confirm_delete, {
    start_time <- Sys.time()
    existing_name <- input$custom_builder_existing
    if (is.null(existing_name) || identical(existing_name, "__new__")) {
      log_perf(
        "observeEvent(custom_builder_confirm_delete)",
        start_time,
        details = list(
          scope = active_custom_scope(),
          status = "missing_existing_name"
        )
      )

      return()
    }

    current_scope_rows <- nrow(custom_types_for_scope())
    previous_choice <- input$commodity_choice
    next_df <- as_tibble(custom_types_data()) %>%
      mutate(
        source_scope = vapply(as.character(.data$source_scope), normalize_scope_value, character(1))
      ) %>%
      filter(!(.data$custom_name == existing_name & .data$source_scope == active_custom_scope()))

    next_df_out <- as.data.frame(next_df, stringsAsFactors = FALSE)
    save_custom_types(next_df_out, user_custom_types_path)
    custom_types_data(next_df_out)

    fallback <- NULL
    valid_choices <- commodity_choice_real_values()
    if (length(valid_choices) > 0) {
      fallback <- resolve_valid_non_custom_fallback(valid_choices)
      updateSelectizeInput(session, "commodity_choice", selected = fallback)
    }

    removeModal()
    removeModal()

    log_perf(
      "observeEvent(custom_builder_confirm_delete)",
      start_time,
      details = list(
        scope = active_custom_scope(),
        status = "deleted",
        custom_name = existing_name,
        rows_before = current_scope_rows,
        rows_after = max(current_scope_rows - 1L, 0L),
        selected_commodity_changed = !is.null(fallback) && !identical(previous_choice, fallback),
        fallback = if (!is.null(fallback)) fallback else "NULL"
      )
    )

    showNotification("Custom type deleted.", type = "message")
  })

  observeEvent(input$custom_builder_clear_all, {
    showModal(modalDialog(
      title = "Clear All Custom Types",
      "Are you sure you'd like to clear all custom types?",
      footer = tagList(
        actionButton("custom_builder_confirm_clear_all", "Yes, Clear All", class = "btn-danger"),
        modalButton("Cancel")
      ),
      easyClose = TRUE
    ))
  })

  observeEvent(input$custom_builder_confirm_clear_all, {
    start_time <- Sys.time()
    current_scope_rows <- nrow(custom_types_for_scope())
    previous_choice <- input$commodity_choice
    remaining_df <- as_tibble(custom_types_data()) %>%
      mutate(
        source_scope = vapply(as.character(.data$source_scope), normalize_scope_value, character(1))
      ) %>%
      filter(.data$source_scope != active_custom_scope())

    remaining_df_out <- as.data.frame(remaining_df, stringsAsFactors = FALSE)
    save_custom_types(remaining_df_out, user_custom_types_path)
    custom_types_data(remaining_df_out)

    fallback <- NULL
    valid_choices <- commodity_choice_real_values()
    if (length(valid_choices) > 0) {
      fallback <- resolve_valid_non_custom_fallback(valid_choices)
      updateSelectizeInput(session, "commodity_choice", selected = fallback)
    }

    removeModal()
    removeModal()

    log_perf(
      "observeEvent(custom_builder_confirm_clear_all)",
      start_time,
      details = list(
        scope = active_custom_scope(),
        status = "cleared",
        rows_before = current_scope_rows,
        rows_after = 0L,
        selected_commodity_changed = !is.null(fallback) && !identical(previous_choice, fallback),
        fallback = if (!is.null(fallback)) fallback else "NULL"
      )
    )

    showNotification("All custom types cleared for the active data source.", type = "warning")
  })

  observeEvent(input$commodity_choice, {
    choice <- input$commodity_choice
    if (is.null(choice)) return()

    if (choice %in% active_native_commodities()) {
      if (exists("is_myc_automatic_commodity_value", mode = "function") && isTRUE(is_myc_automatic_commodity_value(choice))) {
        myc_transition_trace_safe(
          "skip_remember_automatic_commodity",
          details = list(choice = choice)
        )
      } else {
        if (exists("mark_myc_manual_commodity_choice", mode = "function")) {
          mark_myc_manual_commodity_choice(choice)
        }
        last_non_custom_commodity(choice)
      }
    }

    if (exists("complete_myc_sidebar_restore_if_ready", mode = "function")) {
      complete_myc_sidebar_restore_if_ready("commodity_choice_observed")
    }

    if (identical(choice, CUSTOM_BUILDER_CHOICE)) {
      start_time <- Sys.time()
      fallback <- last_non_custom_commodity()
      valid_choices <- commodity_choice_fallback_values()
      source_choice <- active_source_choice()

      if (identical(source_choice, "vp_trade") && (length(valid_choices) == 0 || isTRUE(vp_type_empty_choice_transition()))) {
        myc_transition_trace_safe(
          "custom_builder_suppressed_vp_transition",
          details = list(
            source = source_choice,
            choice = choice,
            valid_choice_count = length(valid_choices),
            fallback = if (!is.null(fallback) && nzchar(as.character(fallback))) as.character(fallback) else "NULL",
            empty_transition_pending = isTRUE(vp_type_empty_choice_transition())
          )
        )

        if (is.null(fallback) || !(fallback %in% valid_choices)) {
          fallback <- if ("All" %in% valid_choices) {
            "All"
          } else if (length(valid_choices) > 0) {
            unname(valid_choices[1])
          } else {
            NULL
          }
        }

        if (!is.null(fallback) && nzchar(as.character(fallback))) {
          updateSelectizeInput(session, "commodity_choice", selected = fallback)
        }

        log_perf(
          "custom_builder_suppressed_vp_transition",
          start_time,
          details = list(
            source = source_choice,
            choice = choice,
            valid_choices = length(valid_choices),
            fallback = if (!is.null(fallback) && nzchar(as.character(fallback))) as.character(fallback) else "NULL",
            empty_transition_pending = isTRUE(vp_type_empty_choice_transition())
          )
        )

        vp_type_empty_choice_transition(FALSE)

        return()
      }

      if (is.null(fallback) || !(fallback %in% valid_choices)) {
        aggregate_label <- default_commodity_choice_value()
        if (identical(source_choice, "vp_trade") && "All" %in% valid_choices) {
          fallback <- "All"
        } else if (aggregate_label %in% valid_choices) {
          fallback <- aggregate_label
        } else if (length(valid_choices) > 0) {
          fallback <- unname(valid_choices[1])
        } else {
          fallback <- NULL
        }
      }

      if (!is.null(fallback) && nzchar(as.character(fallback))) {
        updateSelectizeInput(session, "commodity_choice", selected = fallback)
      }

      myc_transition_trace_safe(
        "custom_builder_modal_opened",
        details = list(
          source = source_choice,
          choice = choice,
          valid_choice_count = length(valid_choices),
          fallback = if (!is.null(fallback) && nzchar(as.character(fallback))) as.character(fallback) else "NULL"
        )
      )

      if (identical(source_choice, "vp_trade")) {
        vp_type_empty_choice_transition(FALSE)
      }

      log_perf(
        "custom_builder_modal_opened",
        start_time,
        details = list(
          source = source_choice,
          choice = choice,
          valid_choices = length(valid_choices),
          fallback = if (!is.null(fallback) && nzchar(as.character(fallback))) as.character(fallback) else "NULL"
        )
      )

      show_custom_builder_modal()
    }
  }, ignoreInit = TRUE)

  myc_transition_trace_safe <- function(event, details = list()) {
    tracer <- get0("myc_transition_trace", inherits = TRUE)
    if (!is.function(tracer)) return(invisible(NULL))
    tracer(event, details = details)
    invisible(NULL)
  }

  observe({
    start_time <- Sys.time()
    valid_choices <- commodity_choice_fallback_values()
    if (length(valid_choices) == 0) {
      return()
    }

    current_choice <- input$commodity_choice
    if (is.null(current_choice) || !nzchar(current_choice)) {
      return()
    }
    myc_type_mode_active <- identical(input$main_tabs_panel, "Market Year Comparison Tool") &&
      identical(market_year_comparison_mode(), "type")
    if (!is.null(current_choice) && current_choice %in% valid_choices) {
      return()
    }

    remembered_non_custom <- last_non_custom_commodity()
    fallback <- remembered_non_custom
    fallback_source <- "last_non_custom_commodity"
    if (is.null(fallback) || !(fallback %in% valid_choices)) {
      aggregate_label <- default_commodity_choice_value()
      if (identical(active_source_choice(), "vp_trade") && "All" %in% valid_choices) {
        fallback <- "All"
        fallback_source <- "vp_all"
      } else {
        fallback <- if (aggregate_label %in% valid_choices) aggregate_label else unname(valid_choices[1])
        fallback_source <- if (aggregate_label %in% valid_choices) "aggregate_label" else "first_valid_choice"
      }
    }

    myc_transition_trace_safe(
      "commodity_fallback_update",
      details = list(
        source = input$data_source_choice,
        frequency = input$data_frequency,
        current_choice = if (!is.null(current_choice)) current_choice else "NULL",
        current_is_valid = !is.null(current_choice) && current_choice %in% valid_choices,
        current_nchar = if (!is.null(current_choice)) nchar(current_choice) else 0,
        remembered_non_custom = if (!is.null(remembered_non_custom)) remembered_non_custom else "NULL",
        fallback = fallback,
        fallback_source = fallback_source,
        valid_choices = length(valid_choices),
        valid_choices_sample = paste(head(valid_choices, 8), collapse = " | "),
        valid_contains_lg_milled = any(valid_choices == "Rice - Long Grain, Milled"),
        valid_contains_med_short_milled = any(valid_choices == "Rice- Med,Short,Other Milled")
      )
    )

    if (isTRUE(myc_type_mode_active) && exists("mark_myc_automatic_commodity_fallback", mode = "function")) {
      mark_myc_automatic_commodity_fallback(fallback, branch = fallback_source)
    }

    updateSelectizeInput(session, "commodity_choice", selected = fallback)

    log_perf(
      "observe(commodity_choice fallback)",
      start_time,
      details = list(
        source = input$data_source_choice,
        frequency = input$data_frequency,
        scope = active_custom_scope(),
        current_choice = if (!is.null(current_choice)) current_choice else "NULL",
        current_is_valid = !is.null(current_choice) && current_choice %in% valid_choices,
        fallback = fallback,
        fallback_source = fallback_source,
        valid_choices = length(valid_choices)
      )
    )
  })

  resolve_valid_non_custom_fallback <- function(valid_choices) {
    fallback <- last_non_custom_commodity()
    if (is.null(fallback) || !(fallback %in% valid_choices)) {
      aggregate_label <- default_commodity_choice_value()
      if (identical(active_source_choice(), "vp_trade") && "All" %in% valid_choices) {
        fallback <- "All"
      } else {
        fallback <- if (aggregate_label %in% valid_choices) aggregate_label else unname(valid_choices[1])
      }
    }
    fallback
  }

  observe({
    start_time <- Sys.time()
    valid_choices <- commodity_choice_fallback_values()
    if (length(valid_choices) == 0) return()

    fallback <- resolve_valid_non_custom_fallback(valid_choices)
    panel_state_updates <- 0L
    input_updates <- 0L
    custom_comparison_active <- identical(input$main_tabs_panel, "Custom Comparison Tool")

    panel_fields <- c("commodity_right_2up", "commodity_grid_2", "commodity_grid_3", "commodity_grid_4")
    for (fld in panel_fields) {
      current_value <- panel_state[[fld]]
      if (is.null(current_value) || !(current_value %in% valid_choices)) {
        panel_state[[fld]] <- fallback
        panel_state_updates <- panel_state_updates + 1L
      }
    }

    input_ids <- c("commodity_right_2up", "commodity_grid_2", "commodity_grid_3", "commodity_grid_4")
    if (custom_comparison_active) {
      for (id in input_ids) {
        val <- input[[id]]
        if (is.null(val) || !(val %in% valid_choices)) {
          updateSelectInput(session, id, selected = fallback)
          input_updates <- input_updates + 1L
        }
      }
    }

    current_choice <- input$commodity_choice
    commodity_choice_invalid <- !is.null(current_choice) &&
      !(current_choice %in% valid_choices)

    myc_type_mode_active <- identical(input$main_tabs_panel, "Market Year Comparison Tool") &&
      identical(market_year_comparison_mode(), "type")
    if (isTRUE(myc_type_mode_active) && isTRUE(commodity_choice_invalid)) {
      if (exists("mark_myc_automatic_commodity_fallback", mode = "function")) {
        mark_myc_automatic_commodity_fallback(fallback, branch = "myc_type_panel_correction")
      }
      updateSelectizeInput(session, "commodity_choice", selected = fallback)
      input_updates <- input_updates + 1L
    } else if (isTRUE(custom_comparison_active) && isTRUE(commodity_choice_invalid)) {
      updateSelectizeInput(session, "commodity_choice", selected = fallback)
      input_updates <- input_updates + 1L
    }

    if (panel_state_updates > 0L || input_updates > 0L || commodity_choice_invalid) {
      panel_invalid_fields <- panel_fields[vapply(panel_fields, function(fld) {
        val <- panel_state[[fld]]
        is.null(val) || !(val %in% valid_choices)
      }, logical(1))]

      myc_transition_trace_safe(
        "panel_commodity_correction",
        details = list(
          source = input$data_source_choice,
          frequency = input$data_frequency,
          panel_state_updates = panel_state_updates,
          input_updates = input_updates,
          commodity_choice_invalid = commodity_choice_invalid,
          current_choice = if (!is.null(current_choice)) current_choice else "NULL",
          valid_choices = length(valid_choices),
          valid_choices_sample = paste(head(valid_choices, 8), collapse = " | "),
          panel_invalid_fields = paste(panel_invalid_fields, collapse = "|"),
          custom_comparison_active = custom_comparison_active,
          correction_scope = if (input_updates > 0L) "visible_inputs" else "hidden_panel_only"
        )
      )

      log_perf(
        "observe(panel commodity correction)",
        start_time,
        details = list(
          source = input$data_source_choice,
          frequency = input$data_frequency,
          scope = active_custom_scope(),
          custom_comparison_active = custom_comparison_active,
          fallback = fallback,
          panel_state_updates = panel_state_updates,
          input_updates = input_updates,
          commodity_choice_invalid = commodity_choice_invalid
        )
      )
    }
  })

