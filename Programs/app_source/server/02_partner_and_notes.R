  market_year_comparison_mode <- reactive({
    mode_value <- if (!is.null(input$market_year_compare_mode)) input$market_year_compare_mode else "country"

    if (!(mode_value %in% c("country", "type"))) {
      return("country")
    }

    mode_value
  })

  market_year_comparison_meta <- reactive({
    mode <- market_year_comparison_mode()

    if (identical(mode, "type")) {
      list(
        mode = "type",
        category_label = "Type",
        select_label = "Show types separately:",
        interaction_hint = "Click in the box to choose types.",
        helper_text = "Unselected types are grouped into All Other.",
        placeholder = "Type to search types...",
        reset_label = "Reset defaults"
      )
    } else {
      list(
        mode = "country",
        category_label = "Country",
        select_label = "Show countries separately:",
        interaction_hint = "Click in the box to choose countries.",
        helper_text = "Unselected countries are grouped into All Other.",
        placeholder = "Type to search countries...",
        reset_label = "Reset defaults"
      )
    }
  })

  market_year_latest_ordering_enabled <- reactive({
    identical(input$main_tabs_panel, "Market Year Comparison Tool") &&
      isTRUE(input$myc_order_by_latest_market_year)
  })

  is_market_year_comparison_output_active <- function() {
    identical(current_main_tab_safe(), "Market Year Comparison Tool")
  }

  record_myc_partner_output_lifecycle <- function(output_name, state) {
    record_cache_body_execution(session, paste0("myc_partner_output_", state))
    record_cache_body_execution(session, paste0("myc_partner_", output_name, "_", state))
  }

  record_partner_share_data_read <- function(read_site) {
    record_cache_body_execution(session, paste0("partner_share_data_read_", read_site))
  }

  vp_all_choice <- "__all__"

  vp_faceted_hierarchy_enabled <- function() {
    option_value <- getOption("vp_faceted_hierarchy_enabled", NULL)
    if (!is.null(option_value)) {
      return(isTRUE(option_value))
    }

    env_value <- Sys.getenv("VP_FACETED_HIERARCHY_ENABLED", unset = "")
    if (!nzchar(env_value)) {
      return(TRUE)
    }

    tolower(trimws(env_value)) %in% c("1", "true", "yes", "y", "on")
  }

  vp_faceted_filter_debug_enabled <- function() {
    option_value <- getOption("vp_faceted_filter_debug", NULL)
    if (!is.null(option_value)) {
      return(isTRUE(option_value))
    }

    env_value <- Sys.getenv("VP_FACETED_FILTER_DEBUG", unset = "")
    nzchar(env_value) && tolower(trimws(env_value)) %in% c("1", "true", "yes", "y", "on")
  }

  vp_faceted_stage_a_cache <- new.env(parent = emptyenv())
  vp_faceted_stage_a_cache_order <- character(0)
  vp_faceted_stage_a_cache_limit <- 12L
  vp_resolved_hierarchy_cache <- new.env(parent = emptyenv())
  vp_resolved_hierarchy_cache_hit_counts <- new.env(parent = emptyenv())
  vp_resolved_hierarchy_cache_order <- character(0)
  vp_resolved_hierarchy_cache_limit <- 24L
  vp_trade_context_cache <- new.env(parent = emptyenv())
  vp_trade_context_cache_order <- character(0)
  vp_trade_context_cache_limit <- 36L
  vp_trade_context_metadata_cache <- new.env(parent = emptyenv())
  vp_trade_context_metadata_cache_order <- character(0)
  vp_trade_context_metadata_cache_limit <- 36L

  vp_faceted_stage_a_cache_key <- function(input_rows,
                                           trade_flow,
                                           resolved) {
    paste(
      "stage_a",
      input_rows %||% NA_integer_,
      resolved$resolution_mode %||% "unknown",
      resolved$path_name %||% "unknown",
      trade_flow %||% "export",
      resolved$cache_group_filter %||% vp_all_choice,
      resolved$cache_subgroup_filter %||% vp_all_choice,
      resolved$cache_market_segment_filter %||% vp_all_choice,
      isTRUE(vp_faceted_hierarchy_enabled()),
      sep = "|"
    )
  }

  vp_faceted_stage_a_cache_get <- function(cache_key) {
    if (!nzchar(as.character(cache_key %||% ""))) return(NULL)
    if (!exists(cache_key, envir = vp_faceted_stage_a_cache, inherits = FALSE)) return(NULL)

    get(cache_key, envir = vp_faceted_stage_a_cache, inherits = FALSE)
  }

  vp_faceted_stage_a_cache_set <- function(cache_key, value) {
    if (!nzchar(as.character(cache_key %||% "")) || !is.data.frame(value)) return(invisible(FALSE))

    assign(cache_key, value, envir = vp_faceted_stage_a_cache)
    vp_faceted_stage_a_cache_order <<- unique(c(vp_faceted_stage_a_cache_order, cache_key))
    if (length(vp_faceted_stage_a_cache_order) > vp_faceted_stage_a_cache_limit) {
      remove_keys <- head(vp_faceted_stage_a_cache_order, length(vp_faceted_stage_a_cache_order) - vp_faceted_stage_a_cache_limit)
      rm(list = remove_keys, envir = vp_faceted_stage_a_cache)
      vp_faceted_stage_a_cache_order <<- setdiff(vp_faceted_stage_a_cache_order, remove_keys)
    }

    invisible(TRUE)
  }

  vp_resolved_hierarchy_cache_key <- function(vp_group_choice,
                                              vp_subgroup_choice,
                                              vp_market_segment_choice) {
    normalized <- vp_normalize_hierarchy_choices(
      vp_group_choice = vp_group_choice,
      vp_subgroup_choice = vp_subgroup_choice,
      vp_market_segment_choice = vp_market_segment_choice
    )
    tokens <- vp_rollup_tokens_for_app()

    paste(
      "resolved_hierarchy",
      normalized$group_choice %||% vp_all_choice,
      normalized$subgroup_choice %||% vp_all_choice,
      normalized$market_segment_choice %||% vp_all_choice,
      isTRUE(vp_faceted_hierarchy_enabled()),
      tokens$group %||% "",
      tokens$subgroup %||% "",
      tokens$market_segment %||% "",
      sep = "|"
    )
  }

  vp_resolved_hierarchy_cache_get <- function(cache_key) {
    if (!nzchar(as.character(cache_key %||% ""))) return(NULL)
    if (!exists(cache_key, envir = vp_resolved_hierarchy_cache, inherits = FALSE)) return(NULL)

    get(cache_key, envir = vp_resolved_hierarchy_cache, inherits = FALSE)
  }

  vp_resolved_hierarchy_cache_set <- function(cache_key, value) {
    if (!nzchar(as.character(cache_key %||% "")) || !is.list(value)) return(invisible(FALSE))

    assign(cache_key, value, envir = vp_resolved_hierarchy_cache)
    assign(cache_key, 0L, envir = vp_resolved_hierarchy_cache_hit_counts)
    vp_resolved_hierarchy_cache_order <<- unique(c(vp_resolved_hierarchy_cache_order, cache_key))
    if (length(vp_resolved_hierarchy_cache_order) > vp_resolved_hierarchy_cache_limit) {
      remove_keys <- head(vp_resolved_hierarchy_cache_order, length(vp_resolved_hierarchy_cache_order) - vp_resolved_hierarchy_cache_limit)
      rm(list = remove_keys, envir = vp_resolved_hierarchy_cache)
      rm(list = remove_keys[exists(remove_keys, envir = vp_resolved_hierarchy_cache_hit_counts, inherits = FALSE)], envir = vp_resolved_hierarchy_cache_hit_counts)
      vp_resolved_hierarchy_cache_order <<- setdiff(vp_resolved_hierarchy_cache_order, remove_keys)
    }

    invisible(TRUE)
  }

  vp_resolved_hierarchy_cache_hit_milestone <- function(cache_key) {
    if (!nzchar(as.character(cache_key %||% ""))) return(NA_integer_)

    current_count <- get0(cache_key, envir = vp_resolved_hierarchy_cache_hit_counts, inherits = FALSE, ifnotfound = 0L)
    next_count <- as.integer(current_count) + 1L
    assign(cache_key, next_count, envir = vp_resolved_hierarchy_cache_hit_counts)

    if (next_count %in% c(1L, 2L, 5L, 10L, 25L, 50L, 100L, 250L, 500L, 1000L)) {
      return(next_count)
    }

    NA_integer_
  }

  vp_trade_context_cache_get <- function(cache_key) {
    if (!nzchar(as.character(cache_key %||% ""))) return(NULL)
    if (!exists(cache_key, envir = vp_trade_context_cache, inherits = FALSE)) return(NULL)

    get(cache_key, envir = vp_trade_context_cache, inherits = FALSE)
  }

  vp_trade_context_cache_set <- function(cache_key, value) {
    if (!nzchar(as.character(cache_key %||% "")) || !is.list(value) || !is.data.frame(value$rows)) {
      return(invisible(FALSE))
    }

    assign(cache_key, value, envir = vp_trade_context_cache)
    vp_trade_context_cache_order <<- unique(c(vp_trade_context_cache_order, cache_key))
    if (length(vp_trade_context_cache_order) > vp_trade_context_cache_limit) {
      remove_keys <- head(vp_trade_context_cache_order, length(vp_trade_context_cache_order) - vp_trade_context_cache_limit)
      rm(list = remove_keys, envir = vp_trade_context_cache)
      vp_trade_context_cache_order <<- setdiff(vp_trade_context_cache_order, remove_keys)
    }

    invisible(TRUE)
  }

  vp_trade_context_metadata_cache_get <- function(cache_key) {
    if (!nzchar(as.character(cache_key %||% ""))) return(NULL)
    if (!exists(cache_key, envir = vp_trade_context_metadata_cache, inherits = FALSE)) return(NULL)

    get(cache_key, envir = vp_trade_context_metadata_cache, inherits = FALSE)
  }

  vp_trade_context_metadata_cache_set <- function(cache_key, value) {
    if (!nzchar(as.character(cache_key %||% "")) || !is.list(value)) {
      return(invisible(FALSE))
    }

    assign(cache_key, value, envir = vp_trade_context_metadata_cache)
    vp_trade_context_metadata_cache_order <<- unique(c(vp_trade_context_metadata_cache_order, cache_key))
    if (length(vp_trade_context_metadata_cache_order) > vp_trade_context_metadata_cache_limit) {
      remove_keys <- head(vp_trade_context_metadata_cache_order, length(vp_trade_context_metadata_cache_order) - vp_trade_context_metadata_cache_limit)
      rm(list = remove_keys, envir = vp_trade_context_metadata_cache)
      vp_trade_context_metadata_cache_order <<- setdiff(vp_trade_context_metadata_cache_order, remove_keys)
    }

    invisible(TRUE)
  }

  vp_trade_context_country_state <- function(country_choice,
                                             mode = "quantity_units_context") {
    mode_value <- trimws(as.character(mode %||% "quantity_units_context"))
    mode_value <- mode_value[!is.na(mode_value) & nzchar(mode_value)]
    mode_value <- if (length(mode_value) > 0L) mode_value[[1L]] else "quantity_units_context"

    if (identical(mode_value, "mixed_volume_family")) {
      normalized_country <- as.character(country_choice %||% NA_character_)
      normalized_country <- normalized_country[!is.na(normalized_country) & nzchar(normalized_country)]
    } else {
      normalized_country <- trimws(as.character(country_choice %||% character(0)))
      normalized_country <- normalized_country[!is.na(normalized_country) & nzchar(normalized_country)]
    }

    has_country <- length(normalized_country) > 0L
    country_value <- if (has_country) normalized_country[[1L]] else NA_character_
    country_is_custom <- has_country && isTRUE(is_custom_country_choice_value(country_value))
    use_country_filter <- has_country && !country_is_custom

    list(
      mode = mode_value,
      has_country = has_country,
      country_value = country_value,
      country_is_custom = country_is_custom,
      use_country_filter = use_country_filter
    )
  }

  vp_trade_context_family_from_rows <- function(rows) {
    if (!is.data.frame(rows) || nrow(rows) == 0) {
      return("unknown")
    }

    if ("vp_volume_family_mixed" %in% names(rows)) {
      mixed_flags <- as.logical(rows$vp_volume_family_mixed)
      mixed_flags[is.na(mixed_flags)] <- FALSE
      if (any(mixed_flags)) {
        return("mixed")
      }
    }

    family_values <- character(0)
    if ("volume_unit_family" %in% names(rows)) {
      family_values <- trimws(tolower(as.character(rows$volume_unit_family)))
      family_values <- family_values[!is.na(family_values) & nzchar(family_values)]
    }

    if (length(family_values) == 0L && "source_volume_unit" %in% names(rows) && exists("vp_volume_family", mode = "function")) {
      derived_family <- tryCatch(vp_volume_family(rows$source_volume_unit), error = function(...) NULL)
      if (!is.null(derived_family)) {
        family_values <- trimws(tolower(as.character(derived_family)))
        family_values <- family_values[!is.na(family_values) & nzchar(family_values)]
      }
    }

    family_values <- unique(family_values[family_values %in% c("liquid", "weight")])
    if (length(family_values) == 1L) {
      return(family_values[[1L]])
    }

    if (length(family_values) > 1L) {
      return("mixed")
    }

    "unknown"
  }

  vp_trade_context_metadata_state <- function(reason = "metadata_unavailable") {
    list(
      ok = FALSE,
      reason = reason,
      metadata_state = reason,
      metadata_definitive = FALSE,
      has_mixed_volume_family = NA,
      volume_family = "unknown",
      row_count = NA_integer_,
      metadata = NULL
    )
  }

  vp_trade_context_metadata_select <- function(metadata,
                                               commodity_name = NULL,
                                               commodity_detail = NULL) {
    if (!is.list(metadata)) return(NULL)

    normalized_commodity_name <- trimws(as.character(commodity_name %||% character(0)))
    normalized_commodity_name <- normalized_commodity_name[!is.na(normalized_commodity_name) & nzchar(normalized_commodity_name)]
    normalized_commodity_detail <- trimws(as.character(commodity_detail %||% character(0)))
    normalized_commodity_detail <- normalized_commodity_detail[!is.na(normalized_commodity_detail) & nzchar(normalized_commodity_detail)]

    if (length(normalized_commodity_detail) > 0L) {
      if (length(normalized_commodity_name) == 0L || !is.list(metadata$commodity_detail_index)) {
        return(NULL)
      }
      detail_key <- paste(normalized_commodity_name[[1L]], normalized_commodity_detail[[1L]], sep = "\r")
      detail_metadata <- metadata$commodity_detail_index[[detail_key]]
      return(if (is.list(detail_metadata)) detail_metadata else NULL)
    }

    if (length(normalized_commodity_name) > 0L) {
      if (!is.list(metadata$commodity_name_index)) {
        return(NULL)
      }
      name_metadata <- metadata$commodity_name_index[[normalized_commodity_name[[1L]]]]
      return(if (is.list(name_metadata)) name_metadata else NULL)
    }

    metadata
  }

  vp_trade_context_metadata_entry <- function(source_choice = input$data_source_choice,
                                              country_choice = input$country_choice,
                                              vp_group_choice = input$vp_group_choice,
                                              vp_subgroup_choice = input$vp_subgroup_choice,
                                              vp_market_segment_choice = input$vp_market_segment_choice,
                                              vp_commodity_name_choice = input$vp_commodity_name_choice,
                                              vp_commodity_detail_choice = input$commodity_choice,
                                              vp_filter_purpose = "quantity_units_context",
                                              country_mode = "quantity_units_context") {
    if (!identical(source_choice, "vp_trade")) {
      return(vp_trade_context_metadata_state("metadata_unavailable"))
    }
    if (!exists("vp_partition_get_hierarchy_metadata", mode = "function") || !exists("vp_partition_provider_enabled", mode = "function") || !isTRUE(vp_partition_provider_enabled())) {
      return(vp_trade_context_metadata_state("metadata_unavailable"))
    }

    resolved <- resolve_vp_hierarchy_tokens(vp_group_choice, vp_subgroup_choice, vp_market_segment_choice)
    if (!isTRUE(resolved$use_partition_provider)) {
      return(vp_trade_context_metadata_state("metadata_unavailable"))
    }

    trade_flow <- if (!is.null(input$vp_trade_flow_choice) && input$vp_trade_flow_choice %in% c("export", "import")) input$vp_trade_flow_choice else "export"
    country_state <- vp_trade_context_country_state(country_choice = country_choice, mode = country_mode)
    if (isTRUE(country_state$use_country_filter)) {
      return(vp_trade_context_metadata_state("metadata_insufficient"))
    }

    commodity_name <- trimws(as.character(vp_commodity_name_choice %||% character(0)))
    commodity_name <- commodity_name[!is.na(commodity_name) & nzchar(commodity_name)]
    commodity_detail <- trimws(as.character(vp_commodity_detail_choice %||% character(0)))
    commodity_detail <- commodity_detail[!is.na(commodity_detail) & nzchar(commodity_detail)]
    filter_purpose <- trimws(as.character(vp_filter_purpose %||% "unspecified"))
    filter_purpose <- filter_purpose[!is.na(filter_purpose) & nzchar(filter_purpose)]
    filter_purpose <- if (length(filter_purpose) > 0L) filter_purpose[[1L]] else "unspecified"

    metadata_cache_key <- paste(
      "vp_trade_context",
      "metadata_only",
      source_choice %||% "unknown",
      trade_flow,
      resolved$group_choice %||% vp_all_choice,
      resolved$subgroup_choice %||% vp_all_choice,
      resolved$market_segment_choice %||% vp_all_choice,
      resolved$resolution_mode %||% "unknown",
      resolved$path_name %||% "unknown",
      isTRUE(resolved$strict_rollup_context),
      isTRUE(resolved$sparse_selection),
      if (length(commodity_name) > 0L) commodity_name[[1L]] else "<none>",
      if (length(commodity_detail) > 0L) commodity_detail[[1L]] else "<none>",
      country_state$mode,
      country_state$country_value %||% "<none>",
      isTRUE(country_state$country_is_custom),
      sep = "|"
    )
    cached_metadata_entry <- vp_trade_context_metadata_cache_get(metadata_cache_key)
    if (is.list(cached_metadata_entry)) {
      return(cached_metadata_entry)
    }

    provider_context <- list(
      request_kind = "user_hit",
      filter_purpose = filter_purpose,
      active_tab = input$main_tabs_panel %||% "unknown",
      source = source_choice %||% "unknown",
      trade_flow = trade_flow,
      group_filter = resolved$group_filter %||% "",
      subgroup_filter = resolved$subgroup_filter %||% "",
      market_segment_filter = resolved$market_segment_filter %||% "",
      commodity_name = if (length(commodity_name) > 0L) commodity_name[[1L]] else "<none>",
      commodity_detail = if (length(commodity_detail) > 0L) commodity_detail[[1L]] else "<none>",
      resolution_mode = resolved$resolution_mode %||% "unknown",
      strict_rollup_context = isTRUE(resolved$strict_rollup_context),
      sparse_selection = isTRUE(resolved$sparse_selection),
      path_name = resolved$path_name %||% "unknown"
    )

    provider_metadata <- tryCatch(
      vp_partition_get_hierarchy_metadata(
        trade_flow = trade_flow,
        group_filter = resolved$group_filter,
        subgroup_filter = resolved$subgroup_filter,
        market_segment_filter = resolved$market_segment_filter,
        provider_context = provider_context
      ),
      error = function(error) {
        vp_trade_context_metadata_state("metadata_unavailable")
      }
    )
    if (!isTRUE(provider_metadata$ok) || !is.list(provider_metadata$metadata)) {
      out <- vp_trade_context_metadata_state(provider_metadata$metadata_state %||% provider_metadata$reason %||% "metadata_unavailable")
      vp_trade_context_metadata_cache_set(metadata_cache_key, out)
      return(out)
    }

    selected_metadata <- vp_trade_context_metadata_select(
      provider_metadata$metadata,
      commodity_name = if (length(commodity_name) > 0L) commodity_name[[1L]] else NULL,
      commodity_detail = if (length(commodity_detail) > 0L) commodity_detail[[1L]] else NULL
    )
    if (!is.list(selected_metadata)) {
      out <- vp_trade_context_metadata_state("metadata_insufficient")
      vp_trade_context_metadata_cache_set(metadata_cache_key, out)
      return(out)
    }

    unique_families <- selected_metadata$unique_volume_families %||% character(0)
    unique_families <- unique(trimws(tolower(as.character(unique_families))))
    unique_families <- unique_families[!is.na(unique_families) & nzchar(unique_families)]
    metadata_definitive <- length(unique_families) == 1L && unique_families[[1L]] %in% c("liquid", "weight")

    out <- list(
      ok = isTRUE(metadata_definitive),
      reason = if (isTRUE(metadata_definitive)) "metadata_current" else "metadata_not_definitive",
      metadata_state = if (isTRUE(metadata_definitive)) provider_metadata$metadata_state %||% "metadata_current" else "metadata_not_definitive",
      metadata_definitive = isTRUE(metadata_definitive),
      has_mixed_volume_family = if (isTRUE(metadata_definitive)) isTRUE(selected_metadata$has_mixed_volume_family) else NA,
      volume_family = if (isTRUE(metadata_definitive)) unique_families[[1L]] else "unknown",
      row_count = selected_metadata$row_count %||% NA_integer_,
      metadata = selected_metadata,
      manifest_reason = provider_metadata$manifest_reason %||% NA_character_,
      manifest_cache_state = provider_metadata$manifest_cache_state %||% "unknown"
    )
    vp_trade_context_metadata_cache_set(metadata_cache_key, out)
    out
  }

  vp_trade_context_entry <- function(source_choice = input$data_source_choice,
                                     country_choice = input$country_choice,
                                     vp_group_choice = input$vp_group_choice,
                                     vp_subgroup_choice = input$vp_subgroup_choice,
                                     vp_market_segment_choice = input$vp_market_segment_choice,
                                     vp_commodity_name_choice = input$vp_commodity_name_choice,
                                     vp_commodity_detail_choice = input$commodity_choice,
                                     vp_filter_purpose = "quantity_units_context",
                                     country_mode = "quantity_units_context",
                                     require_rows = TRUE) {
    if (exists("vp_trade_rows_available", mode = "function") && !isTRUE(vp_trade_rows_available(require_non_empty = TRUE))) {
      return(list(rows = data.frame(), has_mixed_volume_family = FALSE, volume_family = "unknown"))
    }
    if (!exists("vp_trade_rows_available", mode = "function") && (!exists("rice_data_vp_trade_monthly", inherits = TRUE) || !is.data.frame(rice_data_vp_trade_monthly) || nrow(rice_data_vp_trade_monthly) == 0)) {
      return(list(rows = data.frame(), has_mixed_volume_family = FALSE, volume_family = "unknown"))
    }

    resolved <- resolve_vp_hierarchy_tokens(vp_group_choice, vp_subgroup_choice, vp_market_segment_choice)
    trade_flow <- if (!is.null(input$vp_trade_flow_choice) && input$vp_trade_flow_choice %in% c("export", "import")) input$vp_trade_flow_choice else "export"

    commodity_name <- trimws(as.character(vp_commodity_name_choice %||% character(0)))
    commodity_name <- commodity_name[!is.na(commodity_name) & nzchar(commodity_name)]
    commodity_detail <- trimws(as.character(vp_commodity_detail_choice %||% character(0)))
    commodity_detail <- commodity_detail[!is.na(commodity_detail) & nzchar(commodity_detail)]

    country_state <- vp_trade_context_country_state(country_choice = country_choice, mode = country_mode)
    if (!isTRUE(require_rows)) {
      return(vp_trade_context_metadata_entry(
        source_choice = source_choice,
        country_choice = country_choice,
        vp_group_choice = vp_group_choice,
        vp_subgroup_choice = vp_subgroup_choice,
        vp_market_segment_choice = vp_market_segment_choice,
        vp_commodity_name_choice = vp_commodity_name_choice,
        vp_commodity_detail_choice = vp_commodity_detail_choice,
        vp_filter_purpose = vp_filter_purpose,
        country_mode = country_mode
      ))
    }

    context_key <- paste(
      "vp_trade_context",
      "rows_required",
      source_choice %||% "unknown",
      trade_flow,
      resolved$group_choice %||% vp_all_choice,
      resolved$subgroup_choice %||% vp_all_choice,
      resolved$market_segment_choice %||% vp_all_choice,
      resolved$resolution_mode %||% "unknown",
      resolved$path_name %||% "unknown",
      isTRUE(resolved$strict_rollup_context),
      isTRUE(resolved$sparse_selection),
      if (length(commodity_name) > 0L) commodity_name[[1L]] else "<none>",
      if (length(commodity_detail) > 0L) commodity_detail[[1L]] else "<none>",
      country_state$mode,
      country_state$country_value %||% "<none>",
      isTRUE(country_state$country_is_custom),
      sep = "|"
    )

    cached_entry <- vp_trade_context_cache_get(context_key)
    if (is.list(cached_entry) && is.data.frame(cached_entry$rows)) {
      return(cached_entry)
    }

    vp_context_rows <- if (exists("vp_trade_rows_for_context", mode = "function")) {
      vp_trade_rows_for_context(require_non_empty = TRUE)
    } else {
      rice_data_vp_trade_monthly
    }

    context_rows <- filter_vp_rows_for_resolved_hierarchy(
      vp_rows = vp_context_rows,
      vp_trade_flow_choice = trade_flow,
      vp_group_choice = vp_group_choice,
      vp_subgroup_choice = vp_subgroup_choice,
      vp_market_segment_choice = vp_market_segment_choice,
      vp_commodity_name_choice = vp_commodity_name_choice,
      vp_commodity_detail_choice = vp_commodity_detail_choice,
      vp_filter_purpose = vp_filter_purpose
    )

    if (is.data.frame(context_rows) && nrow(context_rows) > 0 && "country" %in% names(context_rows) && isTRUE(country_state$use_country_filter)) {
      context_rows <- context_rows[context_rows$country == country_state$country_value, , drop = FALSE]
    }

    if (!is.data.frame(context_rows)) {
      context_rows <- data.frame()
    }

    has_mixed_volume_family <- FALSE
    if (nrow(context_rows) > 0 && "vp_volume_family_mixed" %in% names(context_rows)) {
      mixed_flags <- as.logical(context_rows$vp_volume_family_mixed)
      mixed_flags[is.na(mixed_flags)] <- FALSE
      has_mixed_volume_family <- any(mixed_flags)
    }

    volume_family <- vp_trade_context_family_from_rows(context_rows)
    attr(context_rows, "vp_context_volume_family") <- volume_family
    attr(context_rows, "vp_context_has_mixed_volume_family") <- has_mixed_volume_family

    context_entry <- list(
      rows = context_rows,
      has_mixed_volume_family = has_mixed_volume_family,
      volume_family = volume_family
    )
    vp_trade_context_cache_set(context_key, context_entry)
    context_entry
  }

  vp_normalize_choice_value <- function(choice_value, fallback = vp_all_choice) {
    normalized <- trimws(as.character(choice_value %||% fallback))
    normalized <- normalized[!is.na(normalized) & nzchar(normalized)]
    if (length(normalized) == 0L) {
      return(fallback)
    }

    normalized[[1L]]
  }

  vp_normalize_hierarchy_choices <- function(vp_group_choice,
                                              vp_subgroup_choice,
                                              vp_market_segment_choice) {
    list(
      group_choice = vp_normalize_choice_value(vp_group_choice, fallback = vp_all_choice),
      subgroup_choice = vp_normalize_choice_value(vp_subgroup_choice, fallback = vp_all_choice),
      market_segment_choice = vp_normalize_choice_value(vp_market_segment_choice, fallback = vp_all_choice)
    )
  }

  vp_rollup_tokens_for_app <- function() {
    list(
      group = get0("vp_rollup_group_token", envir = .GlobalEnv, ifnotfound = "__vp_rollup_all_group__"),
      subgroup = get0("vp_rollup_subgroup_token", envir = .GlobalEnv, ifnotfound = "__vp_rollup_all_subgroup__"),
      market_segment = get0("vp_rollup_market_segment_token", envir = .GlobalEnv, ifnotfound = "__vp_rollup_all_market_segment__")
    )
  }

  is_vp_rollup_token_value <- function(values) {
    tokens <- unname(unlist(vp_rollup_tokens_for_app(), use.names = FALSE))
    normalized <- trimws(as.character(values %||% character(0)))
    normalized[!is.na(normalized) & normalized %in% tokens]
  }

  vp_native_rows_for_choice_lists <- function(vp_rows) {
    if (!is.data.frame(vp_rows) || nrow(vp_rows) == 0) {
      return(vp_rows)
    }

    out <- vp_rows
    if ("vp_is_rollup" %in% names(out)) {
      rollup_mask <- !is.na(out$vp_is_rollup) & as.logical(out$vp_is_rollup)
      out <- out[!rollup_mask, , drop = FALSE]
    }

    token_cols <- intersect(c("Group", "Subgroup", "MarketSegment"), names(out))
    if (length(token_cols) > 0) {
      tokens <- unname(unlist(vp_rollup_tokens_for_app(), use.names = FALSE))
      keep_mask <- rep(TRUE, nrow(out))
      for (column_name in token_cols) {
        keep_mask <- keep_mask & !(trimws(as.character(out[[column_name]])) %in% tokens)
      }
      out <- out[keep_mask, , drop = FALSE]
    }

    out
  }

  vp_filter_rows_for_hierarchy_choices <- function(vp_rows,
                                                    group_choice = vp_all_choice,
                                                    subgroup_choice = vp_all_choice,
                                                    market_segment_choice = vp_all_choice,
                                                    native_only = TRUE) {
    if (!is.data.frame(vp_rows) || nrow(vp_rows) == 0L) {
      return(data.frame())
    }

    out <- vp_rows
    if (isTRUE(native_only)) {
      out <- vp_native_rows_for_choice_lists(out)
    }

    group_choice <- vp_normalize_choice_value(group_choice, fallback = vp_all_choice)
    subgroup_choice <- vp_normalize_choice_value(subgroup_choice, fallback = vp_all_choice)
    market_segment_choice <- vp_normalize_choice_value(market_segment_choice, fallback = vp_all_choice)

    if (!identical(group_choice, vp_all_choice) && "Group" %in% names(out)) {
      out <- out[out$Group == group_choice, , drop = FALSE]
    }
    if (!identical(subgroup_choice, vp_all_choice) && "Subgroup" %in% names(out)) {
      out <- out[out$Subgroup == subgroup_choice, , drop = FALSE]
    }
    if (!identical(market_segment_choice, vp_all_choice) && "MarketSegment" %in% names(out)) {
      out <- out[out$MarketSegment == market_segment_choice, , drop = FALSE]
    }

    out
  }

  vp_choice_values_for_column <- function(vp_rows, column_name) {
    if (!is.data.frame(vp_rows) || nrow(vp_rows) == 0L || !(column_name %in% names(vp_rows))) {
      return(character(0))
    }

    values <- sort(unique(as.character(vp_rows[[column_name]])))
    values[!is.na(values) & nzchar(values)]
  }

  vp_resolve_hierarchy_choice_state <- function(vp_rows,
                                                selected_group,
                                                selected_subgroup,
                                                selected_market_segment,
                                                preserve_input_id = NULL) {
    id_map <- c(
      vp_group_choice = "group",
      vp_subgroup_choice = "subgroup",
      vp_market_segment_choice = "market_segment"
    )
    preserve_key <- if (!is.null(preserve_input_id) && preserve_input_id %in% names(id_map)) {
      unname(id_map[[preserve_input_id]])
    } else {
      NULL
    }

    selected <- list(
      group = vp_normalize_choice_value(selected_group, fallback = vp_all_choice),
      subgroup = vp_normalize_choice_value(selected_subgroup, fallback = vp_all_choice),
      market_segment = vp_normalize_choice_value(selected_market_segment, fallback = vp_all_choice)
    )

    build_choices <- function(current_selected) {
      group_rows <- vp_filter_rows_for_hierarchy_choices(
        vp_rows,
        group_choice = vp_all_choice,
        subgroup_choice = current_selected$subgroup,
        market_segment_choice = current_selected$market_segment,
        native_only = TRUE
      )
      subgroup_rows <- vp_filter_rows_for_hierarchy_choices(
        vp_rows,
        group_choice = current_selected$group,
        subgroup_choice = vp_all_choice,
        market_segment_choice = current_selected$market_segment,
        native_only = TRUE
      )
      market_segment_rows <- vp_filter_rows_for_hierarchy_choices(
        vp_rows,
        group_choice = current_selected$group,
        subgroup_choice = current_selected$subgroup,
        market_segment_choice = vp_all_choice,
        native_only = TRUE
      )

      group_values <- vp_choice_values_for_column(group_rows, "Group")
      subgroup_values <- vp_choice_values_for_column(subgroup_rows, "Subgroup")
      market_segment_values <- vp_choice_values_for_column(market_segment_rows, "MarketSegment")

      list(
        group_choices = c("All Groups" = vp_all_choice, stats::setNames(group_values, group_values)),
        subgroup_choices = c("All Subgroups" = vp_all_choice, stats::setNames(subgroup_values, subgroup_values)),
        market_segment_choices = c("All Market Segments" = vp_all_choice, stats::setNames(market_segment_values, market_segment_values))
      )
    }

    choice_bundle <- build_choices(selected)
    for (iteration in seq_len(4L)) {
      changed <- FALSE
      if (!is.null(preserve_key)) {
        preserve_choices <- switch(
          preserve_key,
          group = unname(choice_bundle$group_choices),
          subgroup = unname(choice_bundle$subgroup_choices),
          market_segment = unname(choice_bundle$market_segment_choices),
          character(0)
        )
        if (!(selected[[preserve_key]] %in% preserve_choices)) {
          selected[[preserve_key]] <- vp_all_choice
          changed <- TRUE
        }
      }

      non_preserve_keys <- setdiff(c("group", "subgroup", "market_segment"), preserve_key)
      for (selection_key in non_preserve_keys) {
        candidate_choices <- switch(
          selection_key,
          group = unname(choice_bundle$group_choices),
          subgroup = unname(choice_bundle$subgroup_choices),
          market_segment = unname(choice_bundle$market_segment_choices),
          character(0)
        )
        if (!(selected[[selection_key]] %in% candidate_choices)) {
          selected[[selection_key]] <- vp_all_choice
          changed <- TRUE
        }
      }

      if (!isTRUE(changed)) {
        break
      }
      choice_bundle <- build_choices(selected)
    }

    choice_bundle <- build_choices(selected)

    list(
      group_choice = selected$group,
      subgroup_choice = selected$subgroup,
      market_segment_choice = selected$market_segment,
      group_choices = choice_bundle$group_choices,
      subgroup_choices = choice_bundle$subgroup_choices,
      market_segment_choices = choice_bundle$market_segment_choices,
      reset_disabled = identical(selected$group, vp_all_choice) &&
        identical(selected$subgroup, vp_all_choice) &&
        identical(selected$market_segment, vp_all_choice)
    )
  }

  canonicalize_vp_hierarchy_selection <- function(vp_group_choice = input$vp_group_choice,
                                                   vp_subgroup_choice = input$vp_subgroup_choice,
                                                   vp_market_segment_choice = input$vp_market_segment_choice) {
    normalized <- vp_normalize_hierarchy_choices(
      vp_group_choice = vp_group_choice,
      vp_subgroup_choice = vp_subgroup_choice,
      vp_market_segment_choice = vp_market_segment_choice
    )

    group_value <- normalized$group_choice
    subgroup_value <- normalized$subgroup_choice
    market_segment_value <- normalized$market_segment_choice

    faceted_enabled <- isTRUE(vp_faceted_hierarchy_enabled())
    if (!isTRUE(faceted_enabled)) {
      group_all <- identical(group_value, vp_all_choice)
      subgroup_all <- group_all || identical(subgroup_value, vp_all_choice)
      market_segment_all <- subgroup_all || identical(market_segment_value, vp_all_choice)

      path_name <- if (group_all) {
        "P3_group_all"
      } else if (subgroup_all) {
        "P2_subgroup_all"
      } else if (market_segment_all) {
        "P1_segment_all"
      } else {
        "P0_native"
      }

      resolution_mode <- if (identical(path_name, "P0_native")) "native_specific" else "strict_rollup"
      strict_rollup_context <- identical(resolution_mode, "strict_rollup")

      return(list(
        group_choice = if (group_all) vp_all_choice else group_value,
        subgroup_choice = if (subgroup_all) vp_all_choice else subgroup_value,
        market_segment_choice = if (market_segment_all) vp_all_choice else market_segment_value,
        group_all = group_all,
        subgroup_all = subgroup_all,
        market_segment_all = market_segment_all,
        aggregate_context = strict_rollup_context,
        strict_rollup_context = strict_rollup_context,
        sparse_selection = FALSE,
        resolution_mode = resolution_mode,
        use_partition_provider = TRUE,
        path_name = path_name,
        faceted_enabled = FALSE
      ))
    }

    group_all <- identical(group_value, vp_all_choice)
    subgroup_all <- identical(subgroup_value, vp_all_choice)
    market_segment_all <- identical(market_segment_value, vp_all_choice)

    resolution_mode <- "faceted_native"
    path_name <- "P0_faceted"
    strict_rollup_context <- FALSE
    use_partition_provider <- FALSE

    if (group_all && subgroup_all && market_segment_all) {
      resolution_mode <- "strict_rollup"
      path_name <- "P3_group_all"
      strict_rollup_context <- TRUE
      use_partition_provider <- TRUE
    } else if (!group_all && subgroup_all && market_segment_all) {
      resolution_mode <- "strict_rollup"
      path_name <- "P2_subgroup_all"
      strict_rollup_context <- TRUE
      use_partition_provider <- TRUE
    } else if (!group_all && !subgroup_all && market_segment_all) {
      resolution_mode <- "strict_rollup"
      path_name <- "P1_segment_all"
      strict_rollup_context <- TRUE
      use_partition_provider <- TRUE
    } else if (!group_all && !subgroup_all && !market_segment_all) {
      resolution_mode <- "native_specific"
      path_name <- "P0_native"
      strict_rollup_context <- FALSE
      use_partition_provider <- TRUE
    }

    list(
      group_choice = group_value,
      subgroup_choice = subgroup_value,
      market_segment_choice = market_segment_value,
      group_all = group_all,
      subgroup_all = subgroup_all,
      market_segment_all = market_segment_all,
      aggregate_context = strict_rollup_context,
      strict_rollup_context = strict_rollup_context,
      sparse_selection = identical(resolution_mode, "faceted_native"),
      resolution_mode = resolution_mode,
      use_partition_provider = use_partition_provider,
      path_name = path_name,
      faceted_enabled = TRUE
    )
  }

  resolve_vp_hierarchy_tokens <- function(vp_group_choice = input$vp_group_choice,
                                          vp_subgroup_choice = input$vp_subgroup_choice,
                                          vp_market_segment_choice = input$vp_market_segment_choice) {
    cache_key <- vp_resolved_hierarchy_cache_key(
      vp_group_choice = vp_group_choice,
      vp_subgroup_choice = vp_subgroup_choice,
      vp_market_segment_choice = vp_market_segment_choice
    )
    cached_resolved <- vp_resolved_hierarchy_cache_get(cache_key)
    if (is.list(cached_resolved)) {
      hit_count <- vp_resolved_hierarchy_cache_hit_milestone(cache_key)
      if (is.finite(hit_count)) {
        record_cache_body_execution(
          session,
          "vp_resolved_hierarchy_context_cache_hit",
          details = c(
            list(
              hit_count = hit_count,
              cache_key_prefix = substr(cache_key, 1L, 120L),
              active_tab = input$main_tabs_panel %||% "unknown",
              source = input$data_source_choice %||% "unknown"
            ),
            if (exists("vp_hierarchy_fanout_context", mode = "function")) vp_hierarchy_fanout_context(resolved = cached_resolved) else list()
          )
        )
      }
      return(cached_resolved)
    }

    canonical <- canonicalize_vp_hierarchy_selection(
      vp_group_choice = vp_group_choice,
      vp_subgroup_choice = vp_subgroup_choice,
      vp_market_segment_choice = vp_market_segment_choice
    )
    tokens <- vp_rollup_tokens_for_app()

    provider_group_filter <- canonical$group_choice
    provider_subgroup_filter <- canonical$subgroup_choice
    provider_market_segment_filter <- canonical$market_segment_choice

    if (isTRUE(canonical$strict_rollup_context)) {
      provider_group_filter <- if (canonical$group_all) tokens$group else canonical$group_choice
      provider_subgroup_filter <- if (canonical$subgroup_all) tokens$subgroup else canonical$subgroup_choice
      provider_market_segment_filter <- if (canonical$market_segment_all) tokens$market_segment else canonical$market_segment_choice
    }

    group_active_filter <- if (canonical$group_all) NULL else canonical$group_choice
    subgroup_active_filter <- if (canonical$subgroup_all) NULL else canonical$subgroup_choice
    market_segment_active_filter <- if (canonical$market_segment_all) NULL else canonical$market_segment_choice

    resolved <- list(
      group_choice = canonical$group_choice,
      subgroup_choice = canonical$subgroup_choice,
      market_segment_choice = canonical$market_segment_choice,
      group_filter = provider_group_filter,
      subgroup_filter = provider_subgroup_filter,
      market_segment_filter = provider_market_segment_filter,
      group_active_filter = group_active_filter,
      subgroup_active_filter = subgroup_active_filter,
      market_segment_active_filter = market_segment_active_filter,
      cache_group_filter = if (is.null(group_active_filter)) vp_all_choice else group_active_filter,
      cache_subgroup_filter = if (is.null(subgroup_active_filter)) vp_all_choice else subgroup_active_filter,
      cache_market_segment_filter = if (is.null(market_segment_active_filter)) vp_all_choice else market_segment_active_filter,
      strict_rollup_context = canonical$strict_rollup_context,
      sparse_selection = canonical$sparse_selection,
      resolution_mode = canonical$resolution_mode,
      use_partition_provider = canonical$use_partition_provider,
      aggregate_context = canonical$aggregate_context,
      path_name = canonical$path_name
    )
    vp_resolved_hierarchy_cache_set(cache_key, resolved)
    record_cache_body_execution(
      session,
      "vp_resolved_hierarchy_context_cache_miss",
      details = c(
        list(
          cache_key_prefix = substr(cache_key, 1L, 120L),
          active_tab = input$main_tabs_panel %||% "unknown",
          source = input$data_source_choice %||% "unknown"
        ),
        if (exists("vp_hierarchy_fanout_context", mode = "function")) vp_hierarchy_fanout_context(resolved = resolved) else list()
      )
    )

    resolved
  }

  filter_vp_rows_for_resolved_hierarchy <- function(vp_rows,
                                                     vp_trade_flow_choice = input$vp_trade_flow_choice,
                                                     vp_group_choice = input$vp_group_choice,
                                                     vp_subgroup_choice = input$vp_subgroup_choice,
                                                     vp_market_segment_choice = input$vp_market_segment_choice,
                                                     vp_commodity_name_choice = input$vp_commodity_name_choice,
                                                     vp_commodity_detail_choice = NULL,
                                                     vp_filter_purpose = "unspecified") {
    if (!is.data.frame(vp_rows) || nrow(vp_rows) == 0) {
      return(data.frame())
    }

    start_time <- Sys.time()
    input_rows <- nrow(vp_rows)
    filter_purpose <- trimws(as.character(vp_filter_purpose %||% "unspecified"))
    filter_purpose <- filter_purpose[!is.na(filter_purpose) & nzchar(filter_purpose)]
    filter_purpose <- if (length(filter_purpose) > 0L) filter_purpose[[1L]] else "unspecified"

    resolved <- resolve_vp_hierarchy_tokens(vp_group_choice, vp_subgroup_choice, vp_market_segment_choice)
    trade_flow <- if (!is.null(vp_trade_flow_choice) && vp_trade_flow_choice %in% c("export", "import")) vp_trade_flow_choice else "export"

    commodity_name <- trimws(as.character(vp_commodity_name_choice %||% character(0)))
    commodity_name <- commodity_name[!is.na(commodity_name) & nzchar(commodity_name)]

    commodity_detail <- trimws(as.character(vp_commodity_detail_choice %||% character(0)))
    commodity_detail <- commodity_detail[!is.na(commodity_detail) & nzchar(commodity_detail)]
    commodity_detail_is_all <- length(commodity_detail) > 0 && identical(commodity_detail[[1]], vp_all_type_label)
    commodity_detail_is_builder <- length(commodity_detail) > 0 && identical(commodity_detail[[1]], CUSTOM_BUILDER_CHOICE)
    hierarchy_fanout_context <- if (exists("vp_hierarchy_fanout_context", mode = "function")) {
      tryCatch(vp_hierarchy_fanout_context(resolved = resolved), error = function(...) list())
    } else {
      list()
    }
    filter_counter_name <- paste0(
      "filter_vp_rows_for_resolved_hierarchy_",
      gsub("[^A-Za-z0-9_]+", "_", filter_purpose)
    )
    filter_context_key <- list(
      source = input$data_source_choice %||% "unknown",
      active_tab = input$main_tabs_panel %||% "unknown",
      filter_purpose = filter_purpose,
      trade_flow = trade_flow,
      group_choice = resolved$group_choice %||% vp_all_choice,
      subgroup_choice = resolved$subgroup_choice %||% vp_all_choice,
      market_segment_choice = resolved$market_segment_choice %||% vp_all_choice,
      commodity_name = if (length(commodity_name) > 0L) commodity_name[[1L]] else "<none>",
      commodity_detail = if (length(commodity_detail) > 0L) commodity_detail[[1L]] else "<none>",
      resolution_mode = resolved$resolution_mode %||% "unknown",
      path_name = resolved$path_name %||% "unknown",
      strict_rollup_context = isTRUE(resolved$strict_rollup_context),
      sparse_selection = isTRUE(resolved$sparse_selection)
    )
    record_cache_body_execution(
      session,
      filter_counter_name,
      details = c(
        filter_context_key,
        hierarchy_fanout_context,
        list(input_rows = input_rows)
      )
    )
    record_cache_key_delta(
      session,
      filter_counter_name,
      key = filter_context_key,
      details = list(
        filter_purpose = filter_purpose,
        active_tab = filter_context_key$active_tab,
        source = filter_context_key$source
      )
    )
    debug_details <- if (isTRUE(vp_faceted_filter_debug_enabled())) {
      list(
        requested_group_choice = vp_normalize_choice_value(vp_group_choice),
        requested_subgroup_choice = vp_normalize_choice_value(vp_subgroup_choice),
        requested_market_segment_choice = vp_normalize_choice_value(vp_market_segment_choice),
        requested_commodity_name = if (length(commodity_name) > 0L) commodity_name[[1L]] else "<none>",
        requested_commodity_detail = if (length(commodity_detail) > 0L) commodity_detail[[1L]] else "<none>"
      )
    } else {
      list()
    }
    provider_context <- list(
      request_kind = "user_hit",
      filter_purpose = filter_purpose,
      active_tab = filter_context_key$active_tab,
      source = filter_context_key$source,
      trade_flow = trade_flow,
      group_filter = resolved$group_filter %||% "",
      subgroup_filter = resolved$subgroup_filter %||% "",
      market_segment_filter = resolved$market_segment_filter %||% "",
      commodity_name = if (length(commodity_name) > 0L) commodity_name[[1L]] else "<none>",
      commodity_detail = if (length(commodity_detail) > 0L) commodity_detail[[1L]] else "<none>",
      resolution_mode = resolved$resolution_mode %||% "unknown",
      strict_rollup_context = isTRUE(resolved$strict_rollup_context),
      sparse_selection = isTRUE(resolved$sparse_selection),
      path_name = resolved$path_name %||% "unknown"
    )

    if (isTRUE(resolved$use_partition_provider) && exists("vp_partition_provider_filter_rows", mode = "function")) {
      provider_out <- tryCatch(
        vp_partition_provider_filter_rows(
          vp_rows = vp_rows,
          trade_flow = trade_flow,
          group_filter = resolved$group_filter,
          subgroup_filter = resolved$subgroup_filter,
          market_segment_filter = resolved$market_segment_filter,
          commodity_name = if (length(commodity_name) > 0) commodity_name[[1]] else NULL,
          commodity_detail = if (length(commodity_detail) > 0) commodity_detail[[1]] else NULL,
          provider_context = provider_context
        ),
        error = function(e) {
          log_perf(
            "filter_vp_rows_for_resolved_hierarchy(provider)",
            Sys.time(),
            details = list(
              status = "provider_error",
              filter_purpose = filter_purpose,
              message = conditionMessage(e)
            )
          )
          NULL
        }
      )

      if (is.data.frame(provider_out)) {
        log_perf(
          "filter_vp_rows_for_resolved_hierarchy()",
          start_time,
          details = c(list(
            mode = "partition_provider",
            filter_purpose = filter_purpose,
            resolution_mode = resolved$resolution_mode %||% "unknown",
            strict_rollup_context = isTRUE(resolved$strict_rollup_context),
            sparse_selection = isTRUE(resolved$sparse_selection),
            path_name = resolved$path_name %||% "unknown",
            trade_flow = trade_flow,
            input_rows = input_rows,
            output_rows = nrow(provider_out),
            group_filter = resolved$group_filter %||% "n/a",
            subgroup_filter = resolved$subgroup_filter %||% "n/a",
            market_segment_filter = resolved$market_segment_filter %||% "n/a"
          ), debug_details)
        )
        return(provider_out)
      }
    }

    stage_a_cache_hit <- FALSE
    stage_a_cache_key <- NA_character_
    if (!isTRUE(resolved$strict_rollup_context)) {
      stage_a_cache_key <- vp_faceted_stage_a_cache_key(
        input_rows = input_rows,
        trade_flow = trade_flow,
        resolved = resolved
      )
      cached_stage_a <- vp_faceted_stage_a_cache_get(stage_a_cache_key)
      if (is.data.frame(cached_stage_a)) {
        out <- cached_stage_a
        stage_a_cache_hit <- TRUE
      } else {
        out <- vp_native_rows_for_choice_lists(vp_rows)
        if ("Trade" %in% names(out)) {
          out <- out[out$Trade == trade_flow, , drop = FALSE]
        }
        if ("Group" %in% names(out) && !is.null(resolved$group_active_filter)) {
          out <- out[out$Group == resolved$group_active_filter, , drop = FALSE]
        }
        if ("Subgroup" %in% names(out) && !is.null(resolved$subgroup_active_filter)) {
          out <- out[out$Subgroup == resolved$subgroup_active_filter, , drop = FALSE]
        }
        if ("MarketSegment" %in% names(out) && !is.null(resolved$market_segment_active_filter)) {
          out <- out[out$MarketSegment == resolved$market_segment_active_filter, , drop = FALSE]
        }
        vp_faceted_stage_a_cache_set(stage_a_cache_key, out)
      }
    } else {
      out <- vp_rows
      if ("Trade" %in% names(out)) {
        out <- out[out$Trade == trade_flow, , drop = FALSE]
      }
      if ("Group" %in% names(out) && nzchar(as.character(resolved$group_filter %||% ""))) {
        out <- out[out$Group == resolved$group_filter, , drop = FALSE]
      }
      if ("Subgroup" %in% names(out) && nzchar(as.character(resolved$subgroup_filter %||% ""))) {
        out <- out[out$Subgroup == resolved$subgroup_filter, , drop = FALSE]
      }
      if ("MarketSegment" %in% names(out) && nzchar(as.character(resolved$market_segment_filter %||% ""))) {
        out <- out[out$MarketSegment == resolved$market_segment_filter, , drop = FALSE]
      }
    }

    if (length(commodity_name) > 0 && "CommodityName" %in% names(out)) {
      commodity_name_values <- sort(unique(as.character(out$CommodityName)))
      commodity_name_values <- commodity_name_values[!is.na(commodity_name_values) & nzchar(commodity_name_values)]

      commodity_name_target <- commodity_name[[1]]
      if (!isTRUE(resolved$strict_rollup_context) && !(commodity_name_target %in% commodity_name_values) && length(commodity_name_values) > 0L) {
        commodity_name_target <- commodity_name_values[[1L]]
      }

      if (commodity_name_target %in% commodity_name_values) {
        out <- out[out$CommodityName == commodity_name_target, , drop = FALSE]
      } else {
        out <- out[FALSE, , drop = FALSE]
      }
    }

    if (length(commodity_detail) > 0 && "commodity" %in% names(out) &&
        !commodity_detail_is_builder &&
        !(commodity_detail_is_all && !isTRUE(resolved$strict_rollup_context))) {
      commodity_detail_values <- sort(unique(as.character(out$commodity)))
      commodity_detail_values <- commodity_detail_values[!is.na(commodity_detail_values) & nzchar(commodity_detail_values)]

      commodity_detail_target <- commodity_detail[[1]]
      if (!isTRUE(resolved$strict_rollup_context) && !(commodity_detail_target %in% commodity_detail_values) && length(commodity_detail_values) > 0L) {
        if (vp_all_type_label %in% commodity_detail_values) {
          commodity_detail_target <- vp_all_type_label
        } else {
          commodity_detail_target <- commodity_detail_values[[1L]]
        }
      }

      if (commodity_detail_target %in% commodity_detail_values) {
        out <- out[out$commodity == commodity_detail_target, , drop = FALSE]
      } else {
        out <- out[FALSE, , drop = FALSE]
      }
    }

    log_perf(
      "filter_vp_rows_for_resolved_hierarchy()",
      start_time,
      details = c(list(
        mode = "direct_filter",
        filter_purpose = filter_purpose,
        resolution_mode = resolved$resolution_mode %||% "unknown",
        strict_rollup_context = isTRUE(resolved$strict_rollup_context),
        sparse_selection = isTRUE(resolved$sparse_selection),
        path_name = resolved$path_name %||% "unknown",
        trade_flow = trade_flow,
        input_rows = input_rows,
        output_rows = nrow(out),
        native_only_filter = !isTRUE(resolved$strict_rollup_context),
        stage_a_cache_hit = stage_a_cache_hit,
        stage_a_cache_key = if (isTRUE(vp_faceted_filter_debug_enabled())) stage_a_cache_key else "<hidden>",
        commodity_detail_is_all = commodity_detail_is_all,
        commodity_detail_is_builder = commodity_detail_is_builder,
        group_active_filter = resolved$group_active_filter %||% vp_all_choice,
        subgroup_active_filter = resolved$subgroup_active_filter %||% vp_all_choice,
        market_segment_active_filter = resolved$market_segment_active_filter %||% vp_all_choice
      ), debug_details)
    )

    out
  }

  vp_rollup_context_active <- function(source_choice = current_source_choice_safe(default = input$data_source_choice %||% "export_sales"),
                                       vp_group_choice = input$vp_group_choice,
                                       vp_subgroup_choice = input$vp_subgroup_choice,
                                       vp_market_segment_choice = input$vp_market_segment_choice,
                                       vp_commodity_detail_choice = input$commodity_choice) {
    if (!identical(source_choice, "vp_trade")) {
      return(FALSE)
    }

    resolved <- resolve_vp_hierarchy_tokens(
      vp_group_choice = vp_group_choice,
      vp_subgroup_choice = vp_subgroup_choice,
      vp_market_segment_choice = vp_market_segment_choice
    )

    commodity_detail <- trimws(as.character(vp_commodity_detail_choice %||% ""))
    commodity_is_all <- length(commodity_detail) > 0 && identical(commodity_detail[[1]], vp_all_type_label)

    isTRUE(resolved$aggregate_context) || commodity_is_all
  }

  vp_rollup_context_has_mixed_volume_family <- function(source_choice = current_source_choice_safe(default = input$data_source_choice %||% "export_sales"),
                                                        country_choice = input$country_choice,
                                                        vp_group_choice = input$vp_group_choice,
                                                        vp_subgroup_choice = input$vp_subgroup_choice,
                                                        vp_market_segment_choice = input$vp_market_segment_choice,
                                                        vp_commodity_name_choice = input$vp_commodity_name_choice,
                                                        vp_commodity_detail_choice = input$commodity_choice) {
    if (!identical(source_choice, "vp_trade")) {
      return(FALSE)
    }
    if (exists("vp_trade_rows_available", mode = "function") && !isTRUE(vp_trade_rows_available(require_non_empty = TRUE))) {
      return(FALSE)
    }
    if (!exists("vp_trade_rows_available", mode = "function") && (!exists("rice_data_vp_trade_monthly", inherits = TRUE) || !is.data.frame(rice_data_vp_trade_monthly) || nrow(rice_data_vp_trade_monthly) == 0)) {
      return(FALSE)
    }

    vp_rows_check <- if (exists("vp_trade_rows_for_context", mode = "function")) {
      vp_trade_rows_for_context(require_non_empty = TRUE)
    } else {
      rice_data_vp_trade_monthly
    }

    if (!("vp_volume_family_mixed" %in% names(vp_rows_check))) {
      return(FALSE)
    }

    context_entry <- vp_trade_context_entry(
      source_choice = source_choice,
      country_choice = country_choice,
      vp_group_choice = vp_group_choice,
      vp_subgroup_choice = vp_subgroup_choice,
      vp_market_segment_choice = vp_market_segment_choice,
      vp_commodity_name_choice = vp_commodity_name_choice,
      vp_commodity_detail_choice = vp_commodity_detail_choice,
      vp_filter_purpose = "mixed_volume_family_check",
      country_mode = "mixed_volume_family",
      require_rows = FALSE
    )
    if (is.list(context_entry) && isTRUE(context_entry$metadata_definitive)) {
      return(isTRUE(context_entry$has_mixed_volume_family))
    }

    context_entry <- vp_trade_context_entry(
      source_choice = source_choice,
      country_choice = country_choice,
      vp_group_choice = vp_group_choice,
      vp_subgroup_choice = vp_subgroup_choice,
      vp_market_segment_choice = vp_market_segment_choice,
      vp_commodity_name_choice = vp_commodity_name_choice,
      vp_commodity_detail_choice = vp_commodity_detail_choice,
      vp_filter_purpose = "mixed_volume_family_check",
      country_mode = "mixed_volume_family",
      require_rows = TRUE
    )
    context_rows <- context_entry$rows

    if (!is.data.frame(context_rows) || nrow(context_rows) == 0) {
      return(FALSE)
    }

    if (!is.null(context_entry$has_mixed_volume_family)) {
      return(isTRUE(context_entry$has_mixed_volume_family))
    }

    any(!is.na(context_rows$vp_volume_family_mixed) & as.logical(context_rows$vp_volume_family_mixed), na.rm = TRUE)
  }

  vp_trade_metric_supports_quantity_units <- function(metric_code = effective_main_metric()) {
    metric_values <- trimws(as.character(metric_code %||% character(0)))
    metric_values <- metric_values[!is.na(metric_values) & nzchar(metric_values)]
    metric_value <- if (length(metric_values) > 0L) metric_values[[1L]] else ""

    !(metric_value %in% c("unit_value", "ytd_unit_value")) && !is_census_value_metric(metric_value, source_choice = "vp_trade")
  }

  vp_trade_context_rows_for_quantity_units <- function(country_choice = input$country_choice,
                                                       vp_group_choice = input$vp_group_choice,
                                                       vp_subgroup_choice = input$vp_subgroup_choice,
                                                       vp_market_segment_choice = input$vp_market_segment_choice,
                                                       vp_commodity_name_choice = input$vp_commodity_name_choice,
                                                       vp_commodity_detail_choice = input$commodity_choice) {
    context_entry <- vp_trade_context_entry(
      source_choice = input$data_source_choice,
      country_choice = country_choice,
      vp_group_choice = vp_group_choice,
      vp_subgroup_choice = vp_subgroup_choice,
      vp_market_segment_choice = vp_market_segment_choice,
      vp_commodity_name_choice = vp_commodity_name_choice,
      vp_commodity_detail_choice = vp_commodity_detail_choice,
      vp_filter_purpose = "quantity_units_context",
      country_mode = "quantity_units_context"
    )

    context_entry$rows
  }

  vp_trade_context_volume_family <- function(metric_code = effective_main_metric(),
                                             country_choice = input$country_choice,
                                             vp_group_choice = input$vp_group_choice,
                                             vp_subgroup_choice = input$vp_subgroup_choice,
                                             vp_market_segment_choice = input$vp_market_segment_choice,
                                             vp_commodity_name_choice = input$vp_commodity_name_choice,
                                             vp_commodity_detail_choice = input$commodity_choice,
                                             context_rows = NULL) {
    if (!isTRUE(vp_trade_metric_supports_quantity_units(metric_code))) {
      return("unknown")
    }

    rows <- context_rows
    if (is.null(rows)) {
      context_entry <- vp_trade_context_entry(
        source_choice = input$data_source_choice,
        country_choice = country_choice,
        vp_group_choice = vp_group_choice,
        vp_subgroup_choice = vp_subgroup_choice,
        vp_market_segment_choice = vp_market_segment_choice,
        vp_commodity_name_choice = vp_commodity_name_choice,
        vp_commodity_detail_choice = vp_commodity_detail_choice,
        vp_filter_purpose = "quantity_units_context",
        country_mode = "quantity_units_context",
        require_rows = FALSE
      )
      if (is.list(context_entry) && isTRUE(context_entry$metadata_definitive) && context_entry$volume_family %in% c("liquid", "weight")) {
        return(context_entry$volume_family)
      }

      context_entry <- vp_trade_context_entry(
        source_choice = input$data_source_choice,
        country_choice = country_choice,
        vp_group_choice = vp_group_choice,
        vp_subgroup_choice = vp_subgroup_choice,
        vp_market_segment_choice = vp_market_segment_choice,
        vp_commodity_name_choice = vp_commodity_name_choice,
        vp_commodity_detail_choice = vp_commodity_detail_choice,
        vp_filter_purpose = "quantity_units_context",
        country_mode = "quantity_units_context",
        require_rows = TRUE
      )
      rows <- context_entry$rows

      if (is.character(context_entry$volume_family) && length(context_entry$volume_family) == 1L && nzchar(context_entry$volume_family)) {
        return(context_entry$volume_family)
      }
    }

    context_family <- attr(rows, "vp_context_volume_family", exact = TRUE)
    if (is.character(context_family) && length(context_family) == 1L && nzchar(context_family)) {
      return(context_family)
    }

    if (!is.data.frame(rows) || nrow(rows) == 0) {
      return("unknown")
    }

    if ("vp_volume_family_mixed" %in% names(rows)) {
      mixed_flags <- as.logical(rows$vp_volume_family_mixed)
      mixed_flags[is.na(mixed_flags)] <- FALSE
      if (any(mixed_flags)) {
        return("mixed")
      }
    }

    vp_trade_context_family_from_rows(rows)
  }

  vp_trade_quantity_unit_unavailable_reason <- function(source_choice = current_source_choice_safe(default = input$data_source_choice %||% "export_sales"),
                                                        metric_code = effective_main_metric()) {
    if (!identical(source_choice, "vp_trade") || !isTRUE(vp_trade_metric_supports_quantity_units(metric_code))) {
      return(NULL)
    }

    family <- vp_trade_context_volume_family(metric_code = metric_code)
    if (identical(family, "mixed")) {
      return("Quantity unit conversion is unavailable for mixed liquid and weight VP rows in this selection.")
    }

    if (identical(family, "unknown")) {
      return("Quantity unit conversion is temporarily unavailable for this VP selection.")
    }

    NULL
  }

  vp_trade_quantity_unit_choices_for_context <- function(metric_code = effective_main_metric()) {
    if (!isTRUE(vp_trade_metric_supports_quantity_units(metric_code))) {
      return(standard_quantity_unit_choices)
    }

    family <- vp_trade_context_volume_family(metric_code = metric_code)
    if (identical(family, "liquid")) {
      return(c(
        "1000 Gallons" = "thousand_gallons",
        "Gallons" = "gallons"
      ))
    }

    standard_quantity_unit_choices
  }

  vp_trade_default_quantity_unit_for_context <- function(metric_code = effective_main_metric()) {
    if (!isTRUE(vp_trade_metric_supports_quantity_units(metric_code))) {
      return("thousand_lbs")
    }

    family <- vp_trade_context_volume_family(metric_code = metric_code)
    if (identical(family, "liquid")) {
      return("thousand_gallons")
    }

    if (identical(family, "weight")) {
      return("thousand_lbs")
    }

    NULL
  }

  vp_trade_pending_default_unit_target <- function(metric_code = effective_main_metric()) {
    target <- vp_trade_default_quantity_unit_for_context(metric_code = metric_code)
    if (is.null(target) || !nzchar(target)) {
      return(NULL)
    }

    target
  }

  map_cutoff_state <- reactiveVal(list(use_latest = TRUE, period = NULL))
  myc_cutoff_state <- reactiveVal(list(use_latest = FALSE, period = NULL))
  psd_map_bottom_view_state <- reactiveVal("summary")

  snapshot_period_input_label <- function(frequency_value = input$data_frequency) {
    if (identical(frequency_value, "monthly")) {
      return("Through Month:")
    }

    "Through Week Ending Date:"
  }

  myc_snapshot_period_input_label <- function(frequency_value = input$data_frequency) {
    if (identical(frequency_value, "monthly")) {
      return("Analyze through month:")
    }

    "Analyze through week ending:"
  }

  snapshot_period_display_label <- function(period_index,
                                            week_ending_date = as.Date(NA),
                                            frequency_value = input$data_frequency,
                                            year_type_value = NULL,
                                            source_choice_value = NULL) {
    if (!is.finite(period_index) || is.na(period_index)) {
      return(NA_character_)
    }

    if (identical(frequency_value, "monthly")) {
      source_choice <- if (!is.null(source_choice_value) && nzchar(source_choice_value)) {
        source_choice_value
      } else if (exists("current_source_choice_safe", mode = "function")) {
        current_source_choice_safe(default = "export_sales")
      } else {
        "export_sales"
      }

      resolved_year_type <- if (identical(source_choice, "psd")) {
        "marketing"
      } else if (!is.null(year_type_value) && nzchar(as.character(year_type_value))) {
        normalize_non_psd_year_type(year_type_value, default = "marketing")
      } else if (exists("current_non_psd_year_type_safe", mode = "function")) {
        current_non_psd_year_type_safe(source_choice = source_choice, default = "marketing")
      } else {
        "marketing"
      }

      display_month_mapping <- if (exists("current_display_month_mapping", mode = "function")) {
        current_display_month_mapping(source_choice = source_choice)
      } else {
        month_mapping_for_year_type(resolved_year_type)
      }

      month_name <- display_month_mapping %>%
        filter(.data$analysis_month == as.integer(period_index)) %>%
        pull(.data$month_name)

      if (length(month_name) == 1 && !is.na(month_name) && nzchar(month_name)) {
        return(month_name)
      }

      return(paste0("Period ", period_index))
    }

    if (!is.na(week_ending_date) && is.finite(as.numeric(week_ending_date))) {
      return(paste0("Week ", period_index, " (ending ", format(week_ending_date, "%m/%d/%Y"), ")"))
    }

    paste0("Week ", period_index)
  }

  build_snapshot_period_lookup <- function(df, snapshot_market_year) {
    if (is.null(df) || nrow(df) == 0 || !is.finite(snapshot_market_year)) {
      return(data.frame())
    }

    current_rows <- df %>%
      filter(.data$market_year == snapshot_market_year, !is.na(.data$analysis_month))

    if (nrow(current_rows) == 0) {
      return(data.frame())
    }

    current_rows %>%
      group_by(.data$analysis_month) %>%
      summarise(
        week_ending_date = if ("week_ending_date" %in% names(current_rows)) {
          available_dates <- .data$week_ending_date[!is.na(.data$week_ending_date)]
          if (length(available_dates) > 0) max(available_dates) else as.Date(NA)
        } else {
          as.Date(NA)
        },
        .groups = "drop"
      ) %>%
      arrange(.data$analysis_month) %>%
      mutate(
        period_label = vapply(
          seq_len(n()),
          function(row_idx) snapshot_period_display_label(
            period_index = .data$analysis_month[[row_idx]],
            week_ending_date = .data$week_ending_date[[row_idx]]
          ),
          character(1)
        )
      )
  }

  build_snapshot_period_choices <- function(period_lookup) {
    if (is.null(period_lookup) || nrow(period_lookup) == 0) {
      return(character(0))
    }

    stats::setNames(as.character(period_lookup$analysis_month), period_lookup$period_label)
  }

  resolve_snapshot_cutoff <- function(period_choices, state_value) {
    valid_values <- unname(period_choices)
    if (length(valid_values) == 0) {
      return(list(use_latest = TRUE, period = NULL, latest_period = NULL))
    }

    latest_period <- valid_values[[length(valid_values)]]
    remembered_use_latest <- isTRUE(state_value$use_latest)
    remembered_period <- if (!is.null(state_value$period)) as.character(state_value$period) else NULL
    selected_period <- if (!remembered_use_latest && !is.null(remembered_period) && remembered_period %in% valid_values) {
      remembered_period
    } else {
      latest_period
    }

    list(
      use_latest = remembered_use_latest,
      period = selected_period,
      latest_period = latest_period
    )
  }

  build_snapshot_base <- function(df, group_col, state_value, snapshot_market_year = NULL, snapshot_market_year_only = FALSE) {
    if (is.null(df) || nrow(df) == 0) return(NULL)

    current_my <- suppressWarnings(max(df$market_year, na.rm = TRUE))
    if (!is.finite(current_my)) return(NULL)

    if (is.null(snapshot_market_year) || !is.finite(snapshot_market_year)) {
      snapshot_market_year <- current_my
    }

    period_lookup <- build_snapshot_period_lookup(df, snapshot_market_year)
    period_choices <- build_snapshot_period_choices(period_lookup)
    cutoff_state <- resolve_snapshot_cutoff(period_choices, state_value)
    cutoff_period <- suppressWarnings(as.numeric(cutoff_state$period))

    if (!is.finite(cutoff_period)) {
      return(NULL)
    }

    snapshot_source <- df
    if (isTRUE(snapshot_market_year_only)) {
      snapshot_source <- snapshot_source %>%
        filter(.data$market_year == snapshot_market_year)
    }

    snapshot_df <- latest_available_snapshot_by_group(
      df = snapshot_source,
      group_col = group_col,
      cutoff_period = cutoff_period
    )

    list(
      snapshot_df = snapshot_df,
      current_my = current_my,
      snapshot_market_year = snapshot_market_year,
      latest_period_index = cutoff_period,
      latest_available_period_index = suppressWarnings(as.numeric(cutoff_state$latest_period)),
      period_lookup = period_lookup,
      selected_period_label = if (nrow(period_lookup) > 0) {
        matched_label <- period_lookup$period_label[period_lookup$analysis_month == cutoff_period]
        if (length(matched_label) > 0) matched_label[[1]] else snapshot_period_display_label(cutoff_period)
      } else {
        snapshot_period_display_label(cutoff_period)
      },
      period_choices = period_choices,
      cutoff_state = cutoff_state
    )
  }

  observeEvent(list(input$map_use_latest_period, input$map_cutoff_period), {
    if (!identical(input$main_tabs_panel, "Map")) return()

    map_cutoff_state(list(
      use_latest = isTRUE(input$map_use_latest_period),
      period = if (!is.null(input$map_cutoff_period)) as.character(input$map_cutoff_period) else NULL
    ))
  }, ignoreInit = TRUE)

  observeEvent(input$myc_cutoff_period, {
    if (!identical(input$main_tabs_panel, "Market Year Comparison Tool")) return()

    myc_cutoff_state(list(
      use_latest = FALSE,
      period = if (!is.null(input$myc_cutoff_period)) as.character(input$myc_cutoff_period) else NULL
    ))
  }, ignoreInit = TRUE)

  map_runtime_stable_data_cache_key <- reactive({
    source_choice <- current_source_choice_safe()
    metric_code <- effective_main_metric()
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

    list(
      source = source_choice,
      frequency = current_data_frequency_safe(),
      year_type = if (identical(source_choice, "psd")) {
        "marketing"
      } else {
        current_non_psd_year_type_safe(source_choice = source_choice, default = "marketing")
      },
      vp_trade_flow = vp_trade_flow_choice(),
      vp_group = if (!is.null(input$vp_group_choice)) input$vp_group_choice else "__all__",
      vp_subgroup = if (!is.null(input$vp_subgroup_choice)) input$vp_subgroup_choice else "__all__",
      vp_market_segment = if (!is.null(input$vp_market_segment_choice)) input$vp_market_segment_choice else "__all__",
      vp_resolution_mode = resolved_vp$resolution_mode %||% "n/a",
      vp_resolved_path = resolved_vp$path_name %||% "n/a",
      vp_resolved_group_filter = resolved_vp$cache_group_filter %||% "n/a",
      vp_resolved_subgroup_filter = resolved_vp$cache_subgroup_filter %||% "n/a",
      vp_resolved_market_segment_filter = resolved_vp$cache_market_segment_filter %||% "n/a",
      vp_commodity_name = if (!is.null(input$vp_commodity_name_choice)) input$vp_commodity_name_choice else NA_character_,
      vp_commodity_detail = if (!is.null(input$commodity_choice)) input$commodity_choice else NA_character_,
      commodity = input$commodity_choice %||% NA_character_,
      metric = metric_code,
      unit = current_unit_choice_safe(),
      basis = current_basis_choice_safe(),
      custom_types = if (identical(source_choice, "psd")) "psd" else custom_types_cache_key(),
      cache_data_version = cache_data_version,
      cache_schema_version = cache_schema_version
    )
  })

  map_runtime_transition_cache_key <- reactive({
    list(
      source_switch_epoch_id = source_switch_epoch_id(),
      psd_transition = current_psd_source_transition_state()
    )
  })

  map_runtime_source_cache_key <- reactive({
    stable_key <- map_runtime_stable_data_cache_key()

    record_cache_key_delta(
      session,
      "map_runtime_source_cache_key",
      stable_key,
      details = list(
        source = stable_key$source %||% NA_character_,
        metric = stable_key$metric %||% NA_character_
      )
    )

    stable_key
  })

  map_snapshot_base_cache_key <- reactive({
    list(
      runtime_source = map_runtime_source_cache_key(),
      selected_market_year = map_selected_market_year(),
      cutoff_state = map_cutoff_state()
    )
  })

  map_source_data <- reactive({
    req(input$commodity_choice)
    source_choice <- if (!is.null(input$data_source_choice)) input$data_source_choice else "export_sales"
    metric_code <- effective_main_metric()
    record_cache_body_execution(session, "map_source_data", details = list(source = source_choice, metric = metric_code))

    df_map <- if (identical(source_choice, "psd")) {
      df_psd <- build_psd_country_metric_frame(
        metric_code,
        input$commodity_choice,
        extra_cols = c("calendar_year", "calendar_month", "release_year", "release_month", "release_period")
      )
      if (is.null(df_psd) || nrow(df_psd) == 0 || !"country" %in% names(df_psd)) return(NULL)

      df_psd %>%
        filter(!(.data$country %in% c("GRAND_TOTAL", "Grand Total")))
    } else {
      record_cache_body_execution(session, "selected_data_read_map_source_data", details = list(source = source_choice, metric = metric_code))
      df_all <- selected_data()
      if (is.null(df_all) || nrow(df_all) == 0) return(NULL)

      df_all %>%
        filter(
          .data$commodity == input$commodity_choice,
          !(.data$country %in% c("GRAND_TOTAL", "Grand Total"))
        ) %>%
        apply_psd_yield_lock_to_df(
          metric_code = metric_code,
          source_choice = source_choice,
          unit_choice = if (!is.null(input$unit_choice)) input$unit_choice else "thousand_mt",
          area_unit_choice = current_psd_area_unit_choice_safe()
        )
    }

    if (is.null(df_map) || nrow(df_map) == 0) return(NULL)

    has_country_description <- "countryDescription" %in% names(df_map)
    has_calendar_year <- "calendar_year" %in% names(df_map)
    has_calendar_month <- "calendar_month" %in% names(df_map)

    df_map %>%
      mutate(
        country_label = normalize_myc_country_display_label(
          .data$country,
          if (has_country_description) .data$countryDescription else NA_character_
        ),
        map_location = normalize_map_country_location(.data$country, .data$country_label),
        calendar_year_num = if (has_calendar_year) suppressWarnings(as.integer(.data$calendar_year)) else NA_integer_,
        calendar_month_num = if (has_calendar_month) suppressWarnings(as.integer(.data$calendar_month)) else NA_integer_,
        latest_period_sort = dplyr::if_else(
          !is.na(.data$calendar_year_num) & !is.na(.data$calendar_month_num) &
            is.finite(.data$calendar_year_num) & is.finite(.data$calendar_month_num) &
            .data$calendar_month_num >= 1 & .data$calendar_month_num <= 12,
          (.data$calendar_year_num * 100L) + .data$calendar_month_num,
          NA_integer_
        )
      )
  }) %>% bindCache(map_runtime_source_cache_key())

  map_market_year_choices <- reactive({
    df <- map_source_data()
    if (is.null(df) || nrow(df) == 0) {
      return(character(0))
    }

    market_years <- sort(unique(df$market_year), decreasing = TRUE)
    market_years <- market_years[is.finite(market_years)]
    if (length(market_years) == 0) return(character(0))

    stats::setNames(as.character(market_years), as.character(market_years))
  })

  map_selected_market_year <- reactive({
    valid_choices <- unname(map_market_year_choices())
    if (length(valid_choices) == 0) return(NULL)

    current_value <- if (!is.null(input$map_market_year)) as.character(input$map_market_year) else NULL
    if (!is.null(current_value) && current_value %in% valid_choices) {
      return(current_value)
    }

    valid_choices[[1]]
  })

  map_snapshot_base <- reactive({
    record_cache_body_execution(session, "map_snapshot_base")
    df <- map_source_data()
    if (is.null(df) || nrow(df) == 0) return(NULL)

    selected_market_year <- suppressWarnings(as.numeric(map_selected_market_year()))

    if (nrow(df) == 0) return(NULL)

    build_snapshot_base(
      df = df,
      group_col = "country",
      state_value = map_cutoff_state(),
      snapshot_market_year = selected_market_year,
      snapshot_market_year_only = TRUE
    )
  }) %>% bindCache(
    map_snapshot_base_cache_key()$runtime_source,
    map_snapshot_base_cache_key()$selected_market_year,
    map_snapshot_base_cache_key()$cutoff_state
  )

  observeEvent(
    list(input$map_projection_basis_mode, input$map_projection_reference_year, map_comparison_hist_years_committed()),
    {
      if (!identical(current_main_tab_safe(), "Map")) {
        return()
      }

      year_choices <- reference_year_choices_safe()
      comparison_state <- read_comparison_state_bundle_safe(
        surface = "map",
        source_choice = current_source_choice_safe(),
        year_choices = year_choices,
        hist_years_override = map_comparison_hist_years_committed()
      )

      set_remembered_comparison_state_bundle(
        source_choice = current_source_choice_safe(),
        basis_mode = comparison_state$basis_mode,
        reference_year = comparison_state$reference_year,
        hist_years = comparison_state$hist_years,
        year_choices = year_choices
      )
    },
    ignoreInit = TRUE
  )

  map_sidebar_style <- function() {
    tags$style(HTML("\n      .map-display-options-section { margin-bottom: 4px; }\n      .map-display-options-body { padding: 0; background-color: transparent; border-radius: 0; }\n      .map-display-shading-control { margin-bottom: 8px; padding-left: 0; }\n      .map-display-shading-control .form-group { margin-bottom: 0; }\n      .map-display-shading-control .control-label { margin-bottom: 12px; }\n      .map-display-shading-control .radio { margin-top: 0; margin-bottom: 2px; }\n      .map-display-shading-control .radio:last-child { margin-bottom: 0; }\n      .map-display-emphasis-box { padding: 6px 10px 4px 0; background-color: #eef1f4; border-radius: 5px; }\n      .map-top-partner-controls .form-group { margin-bottom: 0; }\n      .map-top-partner-controls .checkbox { margin-top: 0; margin-bottom: 0; }\n      .map-top-partner-controls .checkbox + .checkbox { margin-top: 2px; }\n      .map-top-partner-controls .checkbox label { margin-bottom: 0; }\n    "))
  }

  build_map_sidebar_common_state <- function(source_choice) {
    map_metric_selected <- effective_main_metric()
    map_display_mode_choices <- map_display_mode_choices_for_current_context()
    map_comparison_selected <- effective_map_display_mode()
    map_measure_choices <- if (identical(map_comparison_selected, "comparison")) {
      c("% Difference" = "percent_change", "Difference" = "absolute_change")
    } else if (is_psd_non_share_metric(map_metric_selected, source_choice = source_choice)) {
      c("Value" = "quantity_value")
    } else {
      c("Share Percent" = "share_pct", "Value" = "quantity_value")
    }
    map_measure_selected <- if (!is.null(input$map_measure_mode) && input$map_measure_mode %in% unname(map_measure_choices)) {
      input$map_measure_mode
    } else {
      unname(map_measure_choices[[1]])
    }
    comparison_reference_years <- reference_year_choices_safe()
    map_comparison_state <- read_comparison_state_bundle_safe(
      surface = "map",
      source_choice = source_choice,
      year_choices = comparison_reference_years
    )

    list(
      year_choices = map_market_year_choices(),
      selected_year = map_selected_market_year(),
      display_mode_choices = map_display_mode_choices,
      comparison_selected = map_comparison_selected,
      measure_choices = map_measure_choices,
      measure_selected = map_measure_selected,
      top_partner_labels = top_partner_filter_label_text(),
      top5_selected = identical(map_top_n_selection(), 5L),
      top10_selected = identical(map_top_n_selection(), 10L),
      top20_selected = identical(map_top_n_selection(), 20L),
      comparison_reference_years = comparison_reference_years,
      basis_mode = map_comparison_state$basis_mode,
      reference_year = map_comparison_state$reference_year,
      hist_years = map_comparison_state$hist_years,
      hist_year_max = available_hist_year_count(comparison_reference_years)
    )
  }

  build_map_primary_year_control <- function(map_state, label = NULL) {
    if (is.null(label)) {
      label <- if (exists("build_map_display_year_field_label", mode = "function")) {
        paste0(build_map_display_year_field_label(source_choice = current_source_choice_safe(default = "export_sales")), ":")
      } else {
        "Market Year:"
      }
    }

    div(
      style = "flex: 1 1 130px; min-width: 120px;",
      selectInput(
        inputId = "map_market_year",
        label = label,
        choices = map_state$year_choices,
        selected = map_state$selected_year,
        width = "100%"
      )
    )
  }

  build_map_top_partner_controls <- function(map_state) {
    div(
      class = "map-top-partner-controls",
      style = "margin-top: 0; margin-bottom: 0;",
      checkboxInput(
        inputId = "map_top5_only",
        label = map_state$top_partner_labels$top5,
        value = map_state$top5_selected
      ),
      checkboxInput(
        inputId = "map_top10_only",
        label = map_state$top_partner_labels$top10,
        value = map_state$top10_selected
      ),
      checkboxInput(
        inputId = "map_top20_only",
        label = map_state$top_partner_labels$top20,
        value = map_state$top20_selected
      )
    )
  }

  build_map_display_controls <- function(map_state) {
    div(
      class = "map-display-options-section",
      hr(style = "margin: 6px 0 8px 0;"),
      div(
        class = "map-display-options-body",
        div(
          class = "map-display-mode-control",
          radioButtons(
            inputId = "map_comparison_mode",
            label = "Display Mode:",
            choices = map_state$display_mode_choices,
            selected = map_state$comparison_selected,
            inline = FALSE
          )
        ),
        conditionalPanel(
          condition = "input.map_comparison_mode == 'comparison'",
          div(
            class = "map-comparison-basis-control",
            radioButtons(
              inputId = "map_projection_basis_mode",
              label = "Comparison Basis:",
              choices = c("Multi-Year Average" = "average", "Single Reference Year" = "single_year"),
              selected = map_state$basis_mode,
              inline = FALSE
            ),
            if (identical(map_state$basis_mode, "single_year")) {
              div(
                class = "map-comparison-basis-year",
                selectInput(
                  inputId = "map_projection_reference_year",
                  label = "Select Reference Year:",
                  choices = map_state$comparison_reference_years,
                  selected = map_state$reference_year,
                  width = "100%"
                )
              )
            } else {
              comparison_hist_slider(
                input_id = "map_hist_years",
                label = "Years for Historical Average:",
                hist_year_max = map_state$hist_year_max,
                hist_years = map_state$hist_years
              )
            }
          )
        ),
        div(
          class = "map-display-shading-control",
          radioButtons(
            inputId = "map_measure_mode",
            label = "Map Shading:",
            choices = map_state$measure_choices,
            selected = map_state$measure_selected,
            inline = FALSE
          )
        ),
        div(
          class = "map-display-emphasis-box",
          build_map_top_partner_controls(map_state)
        )
      )
    )
  }

  build_psd_map_sidebar_ui <- function(map_state, map_commodity_row, source_epoch = NULL) {
    div(
      class = "map-sidebar-shell map-sidebar-shell-psd",
      `data-source-profile` = "psd",
      `data-source-epoch` = source_epoch %||% "",
      `data-rendered-builder` = "psd",
      `data-rendered-surface` = "map_sidebar",
      style = "padding: 8px; background-color: #f5f5f5; border-radius: 5px; margin-bottom: 10px;",
      map_sidebar_style(),
      map_commodity_row,
      uiOutput("custom_type_warning_ui"),
      uiOutput("psd_map_controls_ui"),
      div(
        style = "display: flex; gap: 8px; align-items: flex-end; flex-wrap: wrap; margin-bottom: 12px;",
        build_map_primary_year_control(map_state, label = "Year:")
      ),
      build_map_display_controls(map_state)
    )
  }

  build_non_psd_map_sidebar_ui <- function(map_state, map_commodity_row, source_epoch = NULL) {
    map_snapshot <- map_snapshot_base()
    map_period_choices <- if (!is.null(map_snapshot)) map_snapshot$period_choices else character(0)
    map_cutoff <- if (!is.null(map_snapshot)) map_snapshot$cutoff_state else list(use_latest = TRUE, period = NULL)

    div(
      class = "map-sidebar-shell map-sidebar-shell-non-psd",
      `data-source-profile` = "non_psd",
      `data-source-epoch` = source_epoch %||% "",
      `data-rendered-builder` = "non_psd",
      `data-rendered-surface` = "map_sidebar",
      style = "padding: 8px; background-color: #f5f5f5; border-radius: 5px; margin-bottom: 10px;",
      map_sidebar_style(),
      map_commodity_row,
      uiOutput("custom_type_warning_ui"),
      div(
        style = "display: flex; gap: 8px; align-items: flex-end; flex-wrap: wrap; margin-bottom: 12px;",
        build_map_primary_year_control(map_state),
        div(
          style = "flex: 1 1 220px; min-width: 220px;",
          checkboxInput(
            inputId = "map_use_latest_period",
            label = "Use latest available period",
            value = isTRUE(map_cutoff$use_latest)
          )
        ),
        conditionalPanel(
          condition = "input.map_use_latest_period == false",
          div(
            style = "flex: 1 1 260px; min-width: 240px;",
            selectInput(
              inputId = "map_cutoff_period",
              label = snapshot_period_input_label(),
              choices = map_period_choices,
              selected = map_cutoff$period,
              width = "100%"
            )
          )
        )
      ),
      build_map_display_controls(map_state)
    )
  }

  output$market_year_compare_filters_ui <- renderUI({
    active_main_tab <- current_main_tab_safe()
    is_market_year_tab <- identical(active_main_tab, "Market Year Comparison Tool")
    is_map_tab <- identical(active_main_tab, "Map")
    selected_source <- current_source_choice_safe(default = input$data_source_choice %||% "export_sales")
    transition_state <- current_psd_source_transition_state()
    render_epoch <- source_switch_epoch_id()
    surface_refresh_generation <- map_surface_refresh_nonce()
    map_sidebar_source <- selected_source
    if (!is.null(transition_state) && identical(transition_state$tab, "Map")) {
      map_sidebar_source <- "psd"
    }
    is_source_time_series_tab <- (selected_source %in% c("psd", "wasde", "nass")) && identical(active_main_tab, "Time Series Analysis Tool")

    selected_mode <- if (!is.null(input$market_year_compare_mode) && input$market_year_compare_mode %in% c("country", "type")) {
      input$market_year_compare_mode
    } else {
      "country"
    }

    notes_in_commodity_row <- !identical(selected_source, "vp_trade") && (
      identical(selected_source, "wasde") ||
        (is_market_year_tab && identical(selected_mode, "country"))
    )
    notes_in_country_row <- !identical(selected_source, "vp_trade") && !notes_in_commodity_row && (!is_market_year_tab || identical(selected_mode, "type"))

    notes_button <- actionButton(
      inputId = "edit_notes_btn",
      label = "📝 Notes",
      style = paste(
        "background-color: #f0f0f0;",
        "border: 1px solid #ccc;",
        "padding: 6px 12px;",
        "font-size: 12px;",
        "height: 34px;",
        "line-height: 20px;",
        "margin-bottom: 0;",
        "white-space: nowrap;"
      )
    )

    button_group_style <- "display: flex; gap: 6px; align-items: flex-end; flex: 0 0 auto;"

    commodity_row <- div(
      class = "notes-layout-row notes-layout-row-commodity",
      `data-notes-row` = "commodity",
      style = paste(
        "display: flex; gap: 6px; align-items: flex-end; margin-bottom: 8px; flex-wrap: nowrap;",
        if (is_market_year_tab && identical(selected_mode, "type")) "display: none;" else ""
      ),
      div(class = "notes-layout-input-wrap notes-layout-input-wrap-commodity", style = "flex: 1 1 0; min-width: 0; margin-bottom: 0;", uiOutput("commodity_choice_ui")),
      if (notes_in_commodity_row) {
        div(class = "notes-layout-button-wrap notes-layout-button-wrap-commodity", style = button_group_style, notes_button)
      }
    )

    country_row <- div(
      class = "notes-layout-row notes-layout-row-country",
      `data-notes-row` = "country",
      style = paste(
        "display: flex; gap: 6px; align-items: flex-end; margin-bottom: 0; flex-wrap: nowrap;",
        if (identical(selected_source, "wasde") || (is_market_year_tab && identical(selected_mode, "country"))) "display: none;" else ""
      ),
      div(class = "notes-layout-input-wrap notes-layout-input-wrap-country", style = "flex: 1 1 0; min-width: 0; margin-bottom: 0;", uiOutput("country_choice_ui")),
      div(
        class = "notes-layout-button-wrap notes-layout-button-wrap-country",
        style = button_group_style,
        if (notes_in_country_row) notes_button
      )
    )

      baseline_filters <- tagList(
        commodity_row,
        uiOutput("custom_type_warning_ui"),
        country_row
      )

    if (is_map_tab) {
      map_state <- build_map_sidebar_common_state(map_sidebar_source)
      map_commodity_row <- div(
        class = "notes-layout-row notes-layout-row-map",
        `data-notes-row` = "map",
        style = "display: flex; gap: 6px; align-items: flex-end; margin-bottom: 0; flex-wrap: nowrap;",
        div(class = "notes-layout-input-wrap notes-layout-input-wrap-map", style = "flex: 1 1 0; min-width: 0; margin-bottom: 0;", uiOutput("commodity_choice_ui")),
        if (!identical(selected_source, "vp_trade")) {
          div(class = "notes-layout-button-wrap notes-layout-button-wrap-map", style = button_group_style, notes_button)
        }
      )

      returned_builder <- if (identical(map_sidebar_source, "psd")) "psd" else "non_psd"
      if (isTRUE(psd_transition_debug_enabled())) {
        raw_transition_state <- tryCatch(isolate(psd_source_transition_state()), error = function(...) NULL)
        raw_transition_active <- tryCatch(isTRUE(isolate(psd_source_transition_active())), error = function(...) FALSE)
        display_mode_choices_value <- if (length(map_state$display_mode_choices) > 0) {
          paste(as.character(unname(map_state$display_mode_choices)), collapse = "|")
        } else {
          NULL
        }
        psd_transition_trace(
          event = "map_sidebar_render",
          reason = "market_year_compare_filters_ui",
          details = list(
            raw_source = input$data_source_choice %||% NULL,
            safe_source = selected_source,
            raw_tab = input$main_tabs_panel %||% NULL,
            safe_tab = active_main_tab,
            raw_transition_active = as.character(isTRUE(raw_transition_active)),
            raw_transition_tab = if (is.null(raw_transition_state)) NULL else raw_transition_state$tab,
            raw_transition_frequency = if (is.null(raw_transition_state)) NULL else raw_transition_state$frequency,
            raw_transition_metric = if (is.null(raw_transition_state)) NULL else raw_transition_state$metric,
            current_transition_tab = if (is.null(transition_state)) NULL else transition_state$tab,
            current_transition_frequency = if (is.null(transition_state)) NULL else transition_state$frequency,
            current_transition_metric = if (is.null(transition_state)) NULL else transition_state$metric,
            map_sidebar_source = map_sidebar_source,
            input_display_mode = input$map_comparison_mode %||% NULL,
            effective_display_mode = map_state$comparison_selected,
            display_mode_choices = display_mode_choices_value,
            returned_builder = returned_builder,
            returned_psd_placeholder = identical(returned_builder, "psd"),
            returned_non_psd_cutoff_controls = identical(returned_builder, "non_psd")
          ),
          dedupe_key = "map_sidebar_render",
          dedupe_signature = build_transition_trace_signature(list(
            safe_source = selected_source,
            safe_tab = active_main_tab,
            map_sidebar_source = map_sidebar_source,
            input_display_mode = input$map_comparison_mode %||% NULL,
            effective_display_mode = map_state$comparison_selected,
            returned_builder = returned_builder,
            raw_transition_active = raw_transition_active,
            current_transition_tab = if (is.null(transition_state)) NULL else transition_state$tab
          ))
        )
      }

      if (identical(map_sidebar_source, "psd")) {
        return(build_psd_map_sidebar_ui(map_state, map_commodity_row, render_epoch))
      }

      return(build_non_psd_map_sidebar_ui(map_state, map_commodity_row, render_epoch))
    }

    if (is_source_time_series_tab) {
      if (identical(selected_source, "wasde")) {
        return(
          div(
            style = "padding: 8px; background-color: #f5f5f5; border-radius: 5px; margin-bottom: 10px;",
            baseline_filters
          )
        )
      }

      nass_historical_records_year_choices <- function() {
        annual_rows <- tryCatch(rice_data_nass_annual, error = function(...) NULL)
        eligible_metric_ids <- tryCatch(unique(trimws(as.character(unname(nass_metric_choices)))), error = function(...) character())
        eligible_metric_ids <- sub("^nass_", "", eligible_metric_ids)
        eligible_metric_ids <- eligible_metric_ids[!is.na(eligible_metric_ids) & nzchar(eligible_metric_ids)]

        if (is.data.frame(annual_rows) && nrow(annual_rows) > 0) {
          if ("country" %in% names(annual_rows)) {
            annual_rows <- annual_rows[trimws(as.character(annual_rows$country)) == "US", , drop = FALSE]
          }
          if ("metric_id" %in% names(annual_rows) && length(eligible_metric_ids) > 0L) {
            annual_rows <- annual_rows[trimws(as.character(annual_rows$metric_id)) %in% eligible_metric_ids, , drop = FALSE]
          }
          years <- sort(unique(suppressWarnings(as.integer(annual_rows$market_year))), decreasing = TRUE)
          years <- years[!is.na(years)]
          if (length(years) > 0L) return(years)
        }

        fallback_records <- tryCatch(load_nass_historical_records(), error = function(...) NULL)
        if (is.data.frame(fallback_records) && nrow(fallback_records) > 0) {
          if ("country" %in% names(fallback_records)) {
            fallback_records <- fallback_records[trimws(as.character(fallback_records$country)) == "US", , drop = FALSE]
          }
          years <- sort(unique(suppressWarnings(as.integer(fallback_records$market_year))), decreasing = TRUE)
          years <- years[!is.na(years)]
          if (length(years) > 0L) return(years)
        }

        integer(0)
      }

      time_series_year_choices <- if (identical(selected_source, "nass")) {
        nass_historical_records_year_choices()
      } else if (is.data.frame(non_nass_historical_records <- tryCatch(load_psd_historical_records(), error = function(...) NULL)) && nrow(non_nass_historical_records) > 0) {
        sort(unique(suppressWarnings(as.integer(non_nass_historical_records$market_year))), decreasing = TRUE)
      } else {
        head(sort(unique(suppressWarnings(as.integer(rice_data_psd_marketing_year$market_year))), decreasing = TRUE), 1L)
      }
      time_series_year_choices <- time_series_year_choices[!is.na(time_series_year_choices)]
      psd_historical_records_selected_year <- suppressWarnings(as.integer(input$psd_historical_records_year %||% NA_integer_))
      if (length(time_series_year_choices) == 0) {
        time_series_year_choices <- integer(0)
        psd_historical_records_selected_year <- NULL
      } else if (is.na(psd_historical_records_selected_year) || !(psd_historical_records_selected_year %in% time_series_year_choices)) {
        psd_historical_records_selected_year <- time_series_year_choices[[1]]
      }

      return(
        div(
          style = "padding: 8px; background-color: #f5f5f5; border-radius: 5px; margin-bottom: 10px;",
          baseline_filters,
          div(
            style = "margin-top: 8px;",
            selectInput(
              inputId = "psd_historical_records_year",
              label = "Year:",
              choices = time_series_year_choices,
              selected = psd_historical_records_selected_year,
              width = "100%"
            )
          )
        )
      )
    }

    if (!is_market_year_tab) {
        return(baseline_filters)
    }

    div(
      style = "padding: 8px; background-color: #f5f5f5; border-radius: 5px; margin-bottom: 10px;",
      div(
        style = "margin-bottom: 8px;",
        radioButtons(
          inputId = "market_year_compare_mode",
          label = "Mode:",
          choices = c(
            "Type Analysis (Choose Type to see Major Trade Partners)" = "country",
            "Country Analysis (Choose Country to see Market Shares of Types)" = "type"
          ),
          selected = selected_mode,
          inline = FALSE
        )
      ),
      baseline_filters
    )
  })

  outputOptions(output, "market_year_compare_filters_ui", suspendWhenHidden = FALSE)

  output$myc_cutoff_controls_ui <- renderUI({
    if (!identical(input$main_tabs_panel, "Market Year Comparison Tool")) {
      myc_transition_trace(
        "myc_cutoff_controls_ui_return",
        details = list(branch = "not_myc_tab", tab = input$main_tabs_panel %||% "<null>")
      )
      return(NULL)
    }

    myc_transition_trace(
      "myc_cutoff_controls_ui_enter",
      details = list(
        mode = input$market_year_compare_mode %||% "<null>",
        source = current_source_choice_safe(),
        vp_commodity_name = input$vp_commodity_name_choice %||% "<null>",
        commodity_choice = input$commodity_choice %||% "<null>",
        country_choice = input$country_choice %||% "<null>"
      )
    )

    myc_snapshot <- partner_snapshot()
    myc_period_choices <- if (!is.null(myc_snapshot)) myc_snapshot$period_choices else character(0)
    myc_cutoff <- if (!is.null(myc_snapshot)) myc_snapshot$cutoff_state else list(use_latest = FALSE, period = NULL)

    myc_transition_trace(
      "myc_cutoff_controls_ui_ready",
      details = list(
        snapshot_null = is.null(myc_snapshot),
        period_choices = length(myc_period_choices),
        period_sample = paste(head(myc_period_choices, 5L), collapse = " | "),
        cutoff_use_latest = isTRUE(myc_cutoff$use_latest),
        cutoff_period = myc_cutoff$period %||% "<null>",
        mode = input$market_year_compare_mode %||% "<null>",
        vp_commodity_name = input$vp_commodity_name_choice %||% "<null>",
        commodity_choice = input$commodity_choice %||% "<null>",
        country_choice = input$country_choice %||% "<null>"
      )
    )

    div(
      style = "padding: 0 8px 8px 8px; background-color: #f5f5f5; border-radius: 5px; margin-top: 2px; margin-bottom: 10px;",
      div(
        style = "display: flex; gap: 8px; align-items: flex-end; flex-wrap: wrap;",
        div(
          style = "flex: 1 1 260px; min-width: 240px;",
          selectInput(
            inputId = "myc_cutoff_period",
            label = myc_snapshot_period_input_label(),
            choices = myc_period_choices,
            selected = myc_cutoff$period,
            width = "100%"
          )
        )
      )
    )
  })

  outputOptions(output, "myc_cutoff_controls_ui", suspendWhenHidden = FALSE)

  output$partner_show_panel <- renderUI({
    if (!identical(input$main_tabs_panel, "Market Year Comparison Tool")) {
      return(NULL)
    }

    meta <- market_year_comparison_meta()

    div(
      style = "padding: 4px 8px 6px 8px; background-color: #f5f5f5; border-radius: 5px; margin-top: 0; margin-bottom: 8px;",
      div(style = "font-weight: 600; margin-bottom: 1px;", meta$select_label),
      div(style = "margin-bottom: 3px; margin-left: 1px; color: #6c757d; font-size: 12px;", meta$interaction_hint),
      selectizeInput(
        inputId = "partner_show",
        label = NULL,
        choices = NULL,
        selected = NULL,
        multiple = TRUE,
        options = list(placeholder = meta$placeholder, plugins = list("remove_button"))
      ),
      uiOutput("myc_country_sort_ui"),
      actionLink("partner_reset_top", meta$reset_label, style = "margin-left: 4px;"),
      div(style = "margin-top: 1px; margin-left: 4px; color: #6c757d; font-size: 12px;", meta$helper_text)
    )
  })

  normalize_multi_select <- function(values) {
    if (is.null(values)) return(character(0))

    unique(trimws(as.character(values)))
  }

  normalize_title_case_label <- function(values) {
    cleaned_values <- trimws(as.character(values))
    cleaned_values[is.na(cleaned_values)] <- ""

    normalized_values <- stringr::str_to_title(tolower(cleaned_values))
    normalized_values[!nzchar(normalized_values)] <- ""
    normalized_values
  }

  custom_country_display_name_lookup <- function(source_choice = current_source_choice_safe()) {
    if (identical(source_choice, "nass")) {
      return(stats::setNames(character(0), character(0)))
    }

    defs <- tryCatch(custom_countries_enriched(), error = function(e) data.frame())
    defs_tbl <- as_tibble(defs %||% data.frame()) %>%
      filter(.data$parse_ok) %>%
      transmute(custom_name = trimws(as.character(.data$custom_name))) %>%
      filter(!is.na(.data$custom_name), nzchar(.data$custom_name)) %>%
      mutate(custom_key = tolower(.data$custom_name)) %>%
      arrange(.data$custom_key, .data$custom_name) %>%
      distinct(.data$custom_key, .keep_all = TRUE)

    if (nrow(defs_tbl) == 0) {
      return(stats::setNames(character(0), character(0)))
    }

    stats::setNames(defs_tbl$custom_name, defs_tbl$custom_key)
  }

  apply_custom_country_display_overrides <- function(values, source_choice = current_source_choice_safe()) {
    normalized_values <- trimws(as.character(values %||% character(0)))
    normalized_values[is.na(normalized_values)] <- ""
    if (length(normalized_values) == 0) {
      return(normalized_values)
    }

    lookup <- custom_country_display_name_lookup(source_choice = source_choice)
    if (length(lookup) == 0) {
      return(normalized_values)
    }

    value_keys <- tolower(normalized_values)
    override_hits <- value_keys %in% names(lookup)
    if (any(override_hits)) {
      normalized_values[override_hits] <- unname(lookup[value_keys[override_hits]])
    }

    normalized_values
  }

  normalize_myc_country_display_label <- function(country, countryDescription, source_choice = current_source_choice_safe()) {
    country_values <- trimws(as.character(country))
    description_values <- trimws(as.character(countryDescription))
    country_values[is.na(country_values)] <- ""
    description_values[is.na(description_values)] <- ""

    fallback_values <- ifelse(nzchar(description_values), description_values, country_values)
    source_choice <- trimws(as.character(source_choice %||% ""))
    source_choice <- source_choice[!is.na(source_choice) & nzchar(source_choice)]
    if (length(source_choice) > 0L && identical(source_choice[[1L]], "census")) {
      fallback_values <- strip_app_ui_census_country_code_prefix(fallback_values)
    }
    normalized_values <- normalize_title_case_label(fallback_values)
    normalized_values[country_values %in% c("GRAND_TOTAL", "Grand Total")] <- "World"
    normalized_values <- apply_custom_country_display_overrides(normalized_values, source_choice = source_choice)
    normalized_values
  }

  normalize_myc_country_selection_values <- function(values, source_choice = current_source_choice_safe()) {
    cleaned_values <- trimws(as.character(values))
    cleaned_values[is.na(cleaned_values)] <- ""

    normalized_values <- normalize_title_case_label(cleaned_values)
    normalized_values[cleaned_values %in% c("GRAND_TOTAL", "Grand Total", "World", "world")] <- "World"
    normalized_values <- apply_custom_country_display_overrides(normalized_values, source_choice = source_choice)
    normalized_values
  }

  normalize_myc_partner_values <- function(values, comparison_mode = market_year_comparison_mode()) {
    if (identical(comparison_mode, "type")) {
      return(normalize_multi_select(values))
    }

    cleaned_values <- trimws(as.character(values))
    cleaned_values[is.na(cleaned_values)] <- ""

    normalized_values <- normalize_myc_country_selection_values(cleaned_values)
    action_values <- c(CUSTOM_COUNTRY_BUILDER_CHOICE, CUSTOM_BUILDER_CHOICE)
    action_idx <- cleaned_values %in% action_values
    normalized_values[action_idx] <- cleaned_values[action_idx]
    unique(normalized_values[nzchar(normalized_values)])
  }

  resolve_myc_partner_action_choice <- function(
    comparison_mode = market_year_comparison_mode(),
    source_choice = current_source_choice_safe()
  ) {
    if (identical(comparison_mode, "country")) {
      if (identical(source_choice, "nass")) {
        return(NULL)
      }

      return(CUSTOM_COUNTRY_BUILDER_CHOICE)
    }

    if (identical(comparison_mode, "type")) {
      return(CUSTOM_BUILDER_CHOICE)
    }

    NULL
  }

  myc_custom_country_display_values <- function(source_choice = current_source_choice_safe()) {
    if (identical(source_choice, "nass")) {
      return(character(0))
    }

    defs <- tryCatch(custom_countries_enriched(), error = function(e) data.frame())
    defs_tbl <- as_tibble(defs %||% data.frame()) %>%
      filter(.data$parse_ok) %>%
      transmute(custom_name = trimws(as.character(.data$custom_name))) %>%
      filter(!is.na(.data$custom_name), nzchar(.data$custom_name))

    if (nrow(defs_tbl) == 0) {
      return(character(0))
    }

    normalize_myc_country_selection_values(defs_tbl$custom_name)
  }

  is_all_rice_display_label <- function(label_value) {
    normalized_value <- trimws(as.character(label_value))
    aggregate_label <- trimws(as.character(COMMODITY_AGGREGATE_LABEL %||% "All Rice"))
    reserved_names <- trimws(as.character(CUSTOM_RESERVED_NAMES %||% aggregate_label))
    normalized_value %in% c(
      aggregate_label,
      reserved_names,
      paste0(aggregate_label, " (PRODUCT-WEIGHT)"),
      paste0(aggregate_label, " (UNADJUSTED)"),
      "All Rice",
      "All Rice (PRODUCT-WEIGHT)",
      "All Rice (UNADJUSTED)",
      "All"
    )
  }

  last_country_comparison_selection <- reactiveVal(character(0))
  last_type_comparison_selection <- reactiveVal(character(0))
  last_country_comparison_selection_manual <- reactiveVal(FALSE)
  last_type_comparison_selection_manual <- reactiveVal(FALSE)
  last_world_type_comparison_selection <- reactiveVal(character(0))
  last_world_type_comparison_selection_manual <- reactiveVal(FALSE)
  myc_country_analysis_default_applied <- reactiveVal(FALSE)
  partner_selection_context_version <- reactiveVal(0L)
  partner_selection_input_version <- reactiveVal(0L)
  partner_selection_force_default <- reactiveVal(FALSE)
  partner_selection_manual_override <- reactiveVal(FALSE)
  partner_selection_reset_override <- reactiveVal(NULL)
  partner_selection_reset_override_manual <- reactiveVal(NULL)
  partner_selection_preserve_remembered_state <- reactiveVal(FALSE)
  partner_selection_programmatic_selected <- reactiveVal(NULL)
  partner_selection_programmatic_manual <- reactiveVal(FALSE)
  partner_selection_legalized_override <- reactiveVal(NULL)
  partner_selection_programmatic_all_rice_reset <- reactiveVal(FALSE)
  partner_selection_programmatic_world_reset <- reactiveVal(FALSE)
  partner_selection_top_up_defaults_on_repopulation <- reactiveVal(FALSE)
  partner_selection_basis_signature <- reactiveVal(NULL)
  partner_selection_basis_signature_manual <- reactiveVal(FALSE)
  myc_native_reset_excluded_partners <- reactiveVal(character(0))
  myc_country_overlap_legalization_messages_state <- reactiveVal(character(0))
  census_corrections_audit_data <- reactiveVal(load_census_corrections_audit(census_corrections_audit_path))
  census_corrections_registry_data <- reactiveVal(load_census_corrections_registry(census_corrections_input_path))
  census_correction_edit_target_id <- reactiveVal(NULL)
  census_correction_form_submit_nonce <- reactiveVal(0L)
  show_census_corrections_audit_section <- reactiveVal(FALSE)
  show_archived_census_corrections_section <- reactiveVal(FALSE)

  myc_transition_action_id <- reactiveVal(0L)
  myc_transition_mutation_seq <- reactiveVal(0L)
  psd_transition_action_id <- reactiveVal(0L)
  psd_transition_mutation_seq <- reactiveVal(0L)
  psd_transition_origin_trigger <- reactiveVal(NULL)
  source_switch_epoch_id <- reactiveVal(0L)
  source_switch_epoch_state <- reactiveVal(NULL)
  source_switch_epoch_trace_seq <- reactiveVal(0L)
  main_tab_resize_request_seq <- reactiveVal(0L)

  myc_transition_debug_enabled <- function() {
    isTRUE(getOption("rice_myc_transition_log", default = FALSE))
  }

  psd_transition_debug_enabled <- function() {
    psd_transition_log_enabled()
  }

  psd_map_selectize_probe_enabled <- function() {
    isTRUE(getOption("rice_psd_map_selectize_probe", default = FALSE))
  }

  source_switch_epoch_fields <- function(include_age = FALSE) {
    state <- isolate(source_switch_epoch_state())
    epoch_id <- isolate(source_switch_epoch_id())

    fields <- list(source_switch_epoch_id = epoch_id)
    if (!is.null(state)) {
      fields <- c(
        fields,
        list(
          source_switch_trigger = state$trigger %||% NULL,
          source_switch_from = state$previous_source %||% NULL,
          source_switch_to = state$source_choice %||% NULL,
          source_switch_started_at_utc = state$started_at_utc %||% NULL
        )
      )

      if (isTRUE(include_age)) {
        fields$source_switch_age_ms <- perf_elapsed_ms(state$started_at)
      }
    }

    fields
  }

  source_switch_epoch_is_stale <- function(epoch_id) {
    epoch_id <- as.character(epoch_id %||% "")
    if (!nzchar(epoch_id)) return(NA)

    !identical(epoch_id, as.character(isolate(source_switch_epoch_id())))
  }

  source_switch_epoch_trace <- function(event, details = list(), force = FALSE) {
    if (!isTRUE(force) && !isTRUE(perf_log_enabled()) && !isTRUE(psd_transition_debug_enabled())) {
      return(invisible(FALSE))
    }

    next_seq <- isolate(source_switch_epoch_trace_seq()) + 1L
    source_switch_epoch_trace_seq(next_seq)

    log_trace(
      "SOURCE_SWITCH_TRACE",
      c(
        list(event = event, source_switch_trace_seq = next_seq),
        source_switch_epoch_fields(include_age = TRUE),
        details
      )
    )
    invisible(TRUE)
  }

  next_main_tab_resize_request_id <- function(tab, source) {
    next_seq <- isolate(main_tab_resize_request_seq()) + 1L
    main_tab_resize_request_seq(next_seq)

    paste(
      normalize_psd_source_entry_scalar(source) %||% "unknown_source",
      normalize_psd_source_entry_scalar(tab) %||% "unknown_tab",
      as.integer(isolate(source_switch_epoch_id())),
      as.integer(next_seq),
      as.numeric(Sys.time()),
      sep = "|"
    )
  }

  begin_source_switch_epoch <- function(trigger, source_choice, previous_source_choice) {
    next_epoch_id <- isolate(source_switch_epoch_id()) + 1L
    started_at <- Sys.time()

    source_switch_epoch_id(next_epoch_id)
    source_switch_epoch_state(list(
      id = next_epoch_id,
      trigger = trigger,
      source_choice = source_choice,
      previous_source = previous_source_choice %||% NULL,
      started_at = started_at,
      started_at_utc = format(started_at, "%Y-%m-%dT%H:%M:%OS3Z", tz = "UTC")
    ))
    source_switch_epoch_trace_seq(0L)

    source_switch_epoch_trace(
      "epoch_begin",
      details = list(
        source = source_choice,
        previous_source = previous_source_choice %||% NULL,
        trigger = trigger
      )
    )

    invisible(next_epoch_id)
  }

  myc_selectize_probe_enabled <- function() {
    isTRUE(getOption("rice_myc_selectize_probe", default = FALSE))
  }

  build_transition_trace_signature <- function(values = list()) {
    if (is.null(values) || length(values) == 0) {
      return("<empty>")
    }

    paste(
      names(values),
      vapply(values, format_perf_detail_value, character(1)),
      sep = "=",
      collapse = "||"
    )
  }

  transition_trace_signature_should_emit <- function(namespace, key, signature) {
    if (is.null(key) || !nzchar(key)) {
      return(TRUE)
    }

    normalized_signature <- if (is.null(signature) || !nzchar(signature)) "<empty>" else signature

    if (is.null(session$userData$transition_trace_signature_cache) ||
        !inherits(session$userData$transition_trace_signature_cache, "environment")) {
      session$userData$transition_trace_signature_cache <- new.env(parent = emptyenv())
    }

    cache <- session$userData$transition_trace_signature_cache
    cache_key <- paste(namespace, key, sep = "::")
    previous_signature <- if (exists(cache_key, envir = cache, inherits = FALSE)) {
      get(cache_key, envir = cache, inherits = FALSE)
    } else {
      NULL
    }

    if (identical(previous_signature, normalized_signature)) {
      return(FALSE)
    }

    assign(cache_key, normalized_signature, envir = cache)
    TRUE
  }

  myc_transition_ids <- function() {
    list(
      action_id = isolate(myc_transition_action_id()),
      mutation_seq = isolate(myc_transition_mutation_seq())
    )
  }

  psd_transition_ids <- function() {
    list(
      action_id = isolate(psd_transition_action_id()),
      mutation_seq = isolate(psd_transition_mutation_seq()),
      origin_trigger = isolate(psd_transition_origin_trigger()),
      source_switch_epoch_id = isolate(source_switch_epoch_id())
    )
  }

  myc_transition_trace <- function(event, details = list()) {
    if (!isTRUE(myc_transition_debug_enabled())) return(invisible(NULL))

    ids <- myc_transition_ids()
    payload <- c(
      list(
        event = event,
        action_id = ids$action_id,
        mutation_seq = ids$mutation_seq
      ),
      details
    )

    detail_pairs <- paste(
      names(payload),
      vapply(payload, format_perf_detail_value, character(1)),
      sep = "="
    )

    message(sprintf("[MYC_TRACE] %s", paste(detail_pairs, collapse = ", ")))
    invisible(NULL)
  }

  psd_transition_trace <- function(event, reason, details = list(), resolved_basis = NULL, dedupe_key = NULL, dedupe_signature = NULL, force = FALSE) {
    if (!isTRUE(psd_transition_debug_enabled())) return(invisible(FALSE))

    ids <- psd_transition_ids()
    safe_input_value <- function(input_id) {
      tryCatch(input[[input_id]], error = function(...) NULL)
    }

    data_source_choice <- safe_input_value("data_source_choice")
    main_tabs_panel <- safe_input_value("main_tabs_panel")
    data_frequency <- safe_input_value("data_frequency")
    metric_choice <- safe_input_value("metric_choice")
    basis_choice <- safe_input_value("basis_choice")

    source_choice <- if (!is.null(data_source_choice) && nzchar(data_source_choice)) data_source_choice else "export_sales"
    transition_state <- tryCatch(current_psd_source_transition_state(), error = function(...) NULL)
    base_payload <- c(
      list(
        event = event,
        reason = reason,
        action_id = ids$action_id,
        mutation_seq = ids$mutation_seq,
        origin_trigger = ids$origin_trigger,
        source_switch_epoch_id = ids$source_switch_epoch_id,
        source_switch_trigger = source_switch_epoch_fields()$source_switch_trigger %||% NULL,
        source_switch_from = source_switch_epoch_fields()$source_switch_from %||% NULL,
        source_switch_to = source_switch_epoch_fields()$source_switch_to %||% NULL,
        source = source_choice,
        tab = if (!is.null(main_tabs_panel) && nzchar(main_tabs_panel)) main_tabs_panel else NULL,
        frequency = if (!is.null(data_frequency) && nzchar(data_frequency)) data_frequency else NULL,
        metric = if (!is.null(metric_choice) && nzchar(metric_choice)) metric_choice else NULL,
        raw_basis = if (!is.null(basis_choice) && nzchar(basis_choice)) basis_choice else NULL,
        raw_basis_scope = session$userData$basis_input_scope,
        remembered_psd_basis = session$userData[[remembered_basis_choice_state_key("psd")]],
        transition_basis = if (is.null(transition_state)) NULL else transition_state$basis,
        resolved_basis = resolved_basis
      ),
      details
    )

    if (!isTRUE(force) && !is.null(dedupe_key) && nzchar(dedupe_key)) {
      if (is.null(dedupe_signature)) {
        dedupe_signature <- build_transition_trace_signature(base_payload)
      }

      if (!transition_trace_signature_should_emit("psd", dedupe_key, dedupe_signature)) {
        return(invisible(FALSE))
      }
    }

    next_seq <- isolate(session$userData$psd_trace_seq %||% 0L) + 1L
    session$userData$psd_trace_seq <- next_seq

    payload <- c(base_payload, list(seq = next_seq))

    log_trace("PSD_TRACE", payload)
    invisible(TRUE)
  }

  begin_psd_transition_action <- function(trigger, details = list()) {
    if (!isTRUE(psd_transition_debug_enabled())) {
      return(invisible(NULL))
    }

    safe_input_value <- function(input_id) {
      tryCatch(input[[input_id]], error = function(...) NULL)
    }

    next_action_id <- isolate(psd_transition_action_id()) + 1L
    psd_transition_action_id(next_action_id)
    psd_transition_mutation_seq(0L)
    psd_transition_origin_trigger(trigger)

    psd_transition_trace(
      event = "action_begin",
      reason = "action",
      details = c(
        list(
          trigger = trigger,
          source_choice = current_source_choice_safe(),
          raw_tab = safe_input_value("main_tabs_panel") %||% NULL,
          sidebar_country = safe_input_value("country_choice") %||% NULL
        ),
        details
      ),
      force = TRUE
    )

    invisible(next_action_id)
  }

  mark_psd_transition_mutation <- function(event, reason, details = list(), resolved_basis = NULL, dedupe_key = NULL, dedupe_signature = NULL, force = FALSE) {
    if (!isTRUE(psd_transition_debug_enabled())) {
      return(invisible(NULL))
    }

    next_seq <- isolate(psd_transition_mutation_seq()) + 1L
    psd_transition_mutation_seq(next_seq)
    psd_transition_trace(
      event = event,
      reason = reason,
      details = details,
      resolved_basis = resolved_basis,
      dedupe_key = dedupe_key,
      dedupe_signature = dedupe_signature,
      force = force
    )
    invisible(next_seq)
  }

  request_psd_map_country_probe <- function(reason, delay_ms = 90L) {
    if (!isTRUE(psd_map_selectize_probe_enabled())) {
      return(invisible(FALSE))
    }

    payload <- list(
      reason = reason,
      action_id = isolate(psd_transition_action_id()),
      mutation_seq = isolate(psd_transition_mutation_seq()),
      source_switch_epoch_id = isolate(source_switch_epoch_id()),
      requested_at_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%OS3Z", tz = "UTC"),
      delay_ms = as.integer(delay_ms)
    )

    session$onFlushed(function() {
      session$sendCustomMessage("capturePsdMapCountryProbe", payload)
    }, once = TRUE)

    invisible(TRUE)
  }

  request_sidebar_country_probe <- function(reason, delay_ms = 90L) {
    if (!isTRUE(psd_map_selectize_probe_enabled())) {
      return(invisible(FALSE))
    }

    payload <- list(
      reason = reason,
      action_id = isolate(psd_transition_action_id()),
      mutation_seq = isolate(psd_transition_mutation_seq()),
      source_switch_epoch_id = isolate(source_switch_epoch_id()),
      requested_at_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%OS3Z", tz = "UTC"),
      delay_ms = as.integer(delay_ms)
    )

    session$onFlushed(function() {
      session$sendCustomMessage("captureSidebarCountryProbe", payload)
    }, once = TRUE)

    invisible(TRUE)
  }

  begin_myc_transition_action <- function(trigger) {
    next_action_id <- isolate(myc_transition_action_id()) + 1L
    myc_transition_action_id(next_action_id)
    myc_transition_mutation_seq(0L)

    myc_transition_trace(
      "action_begin",
      details = list(
        trigger = trigger,
        mode = isolate(market_year_comparison_mode()),
        country = isolate(input$country_choice),
        commodity = isolate(input$commodity_choice)
      )
    )

    invisible(next_action_id)
  }

  empty_myc_sidebar_transition_context <- function() {
    list(
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
    )
  }

  normalize_myc_sidebar_transition_context <- function(context) {
    normalized <- empty_myc_sidebar_transition_context()
    if (is.list(context)) {
      common_names <- intersect(names(context), names(normalized))
      normalized[common_names] <- context[common_names]
    }

    normalized$active <- isTRUE(normalized$active)
    normalized$restore_pending <- isTRUE(normalized$restore_pending)
    normalized$manual_country_override <- isTRUE(normalized$manual_country_override)
    normalized$manual_commodity_override <- isTRUE(normalized$manual_commodity_override)
    normalized
  }

  scalar_myc_sidebar_value <- function(value) {
    values <- as.character(value %||% character(0))
    values <- values[!is.na(values) & nzchar(values)]
    if (length(values) == 0) return(NULL)
    values[[1]]
  }

  read_myc_sidebar_transition_context <- function() {
    normalize_myc_sidebar_transition_context(isolate(myc_sidebar_transition_context()))
  }

  write_myc_sidebar_transition_context <- function(context) {
    normalized_context <- normalize_myc_sidebar_transition_context(context)
    current_context <- normalize_myc_sidebar_transition_context(isolate(myc_sidebar_transition_context()))
    if (identical(normalized_context, current_context)) {
      return(invisible(FALSE))
    }

    myc_sidebar_transition_context(normalized_context)
    invisible(TRUE)
  }

  reset_myc_sidebar_transition_context <- function(reason = "reset") {
    myc_transition_trace(
      "myc_sidebar_context_reset",
      details = list(reason = reason)
    )
    write_myc_sidebar_transition_context(empty_myc_sidebar_transition_context())
  }

  capture_myc_sidebar_entry_context <- function(trigger = "unknown") {
    if (!identical(input$main_tabs_panel, "Market Year Comparison Tool")) return(invisible(FALSE))

    context <- read_myc_sidebar_transition_context()
    if (isTRUE(context$active)) {
      return(invisible(FALSE))
    }

    pre_entry_country <- scalar_myc_sidebar_value(isolate(input$country_choice)) %||% "GRAND_TOTAL"
    pre_entry_commodity <- scalar_myc_sidebar_value(isolate(input$commodity_choice)) %||% default_commodity_choice_value()

    context <- empty_myc_sidebar_transition_context()
    context$active <- TRUE
    context$pre_entry_country <- pre_entry_country
    context$pre_entry_commodity <- pre_entry_commodity
    context$entry_trigger <- trigger
    write_myc_sidebar_transition_context(context)

    myc_transition_trace(
      "myc_sidebar_context_capture",
      details = list(
        trigger = trigger,
        pre_entry_country = pre_entry_country,
        pre_entry_commodity = pre_entry_commodity,
        mode = isolate(market_year_comparison_mode())
      )
    )

    invisible(TRUE)
  }

  capture_myc_sidebar_entry_context_with_automatic <- function(kind, value, branch = "automatic", trigger = "automatic") {
    if (!identical(input$main_tabs_panel, "Market Year Comparison Tool")) {
      return(list(captured = FALSE, marked = FALSE, context = read_myc_sidebar_transition_context()))
    }

    value <- scalar_myc_sidebar_value(value)
    if (is.null(value)) {
      return(list(captured = FALSE, marked = FALSE, context = read_myc_sidebar_transition_context()))
    }

    context <- read_myc_sidebar_transition_context()
    if (isTRUE(context$active)) {
      return(list(captured = FALSE, marked = FALSE, context = context))
    }

    pre_entry_country <- scalar_myc_sidebar_value(isolate(input$country_choice)) %||% "GRAND_TOTAL"
    pre_entry_commodity <- scalar_myc_sidebar_value(isolate(input$commodity_choice)) %||% default_commodity_choice_value()

    context <- empty_myc_sidebar_transition_context()
    context$active <- TRUE
    context$pre_entry_country <- pre_entry_country
    context$pre_entry_commodity <- pre_entry_commodity
    context$entry_trigger <- trigger

    if (identical(kind, "country")) {
      context$automatic_country <- value
      context$automatic_country_branch <- branch
    } else if (identical(kind, "commodity")) {
      context$automatic_commodity <- value
      context$automatic_commodity_branch <- branch
    } else {
      return(list(captured = FALSE, marked = FALSE, context = context))
    }

    write_myc_sidebar_transition_context(context)

    myc_transition_trace(
      "myc_sidebar_context_capture",
      details = list(
        trigger = trigger,
        pre_entry_country = pre_entry_country,
        pre_entry_commodity = pre_entry_commodity,
        mode = isolate(market_year_comparison_mode())
      )
    )

    list(captured = TRUE, marked = TRUE, context = context)
  }

  mark_myc_automatic_country_fallback <- function(country, branch = "automatic") {
    if (!identical(input$main_tabs_panel, "Market Year Comparison Tool")) return(invisible(FALSE))

    country <- scalar_myc_sidebar_value(country)
    if (is.null(country)) return(invisible(FALSE))

    batched_context <- capture_myc_sidebar_entry_context_with_automatic(
      kind = "country",
      value = country,
      branch = branch,
      trigger = "automatic_country_fallback"
    )
    context <- batched_context$context
    if (isTRUE(batched_context$marked)) {
      myc_transition_trace(
        "myc_sidebar_auto_country_marked",
        details = list(country = country, branch = branch, pre_entry_country = context$pre_entry_country)
      )
      return(invisible(TRUE))
    }

    if (isTRUE(context$manual_country_override)) {
      return(invisible(FALSE))
    }
    if (
      identical(context$automatic_country, country) &&
      identical(context$automatic_country_branch, branch)
    ) {
      return(invisible(FALSE))
    }

    context$automatic_country <- country
    context$automatic_country_branch <- branch
    write_myc_sidebar_transition_context(context)

    myc_transition_trace(
      "myc_sidebar_auto_country_marked",
      details = list(country = country, branch = branch, pre_entry_country = context$pre_entry_country)
    )

    invisible(TRUE)
  }

  mark_myc_manual_country_choice <- function(country) {
    if (!identical(input$main_tabs_panel, "Market Year Comparison Tool")) return(invisible(FALSE))

    country <- scalar_myc_sidebar_value(country)
    if (is.null(country)) return(invisible(FALSE))

    context <- read_myc_sidebar_transition_context()
    if (!isTRUE(context$active) || is.null(context$automatic_country)) return(invisible(FALSE))
    if (identical(country, context$automatic_country)) return(invisible(FALSE))

    context$manual_country_override <- TRUE
    context$automatic_country <- NULL
    context$automatic_country_branch <- NULL
    write_myc_sidebar_transition_context(context)

    myc_transition_trace(
      "myc_sidebar_manual_country_marked",
      details = list(country = country)
    )

    invisible(TRUE)
  }

  is_myc_automatic_country_value <- function(country) {
    country <- scalar_myc_sidebar_value(country)
    if (is.null(country)) return(FALSE)

    context <- read_myc_sidebar_transition_context()
    !isTRUE(context$manual_country_override) &&
      !is.null(context$automatic_country) &&
      identical(country, context$automatic_country)
  }

  mark_myc_automatic_commodity_fallback <- function(commodity, branch = "automatic") {
    if (!identical(input$main_tabs_panel, "Market Year Comparison Tool")) return(invisible(FALSE))

    commodity <- scalar_myc_sidebar_value(commodity)
    if (is.null(commodity)) return(invisible(FALSE))

    batched_context <- capture_myc_sidebar_entry_context_with_automatic(
      kind = "commodity",
      value = commodity,
      branch = branch,
      trigger = "automatic_commodity_fallback"
    )
    context <- batched_context$context
    if (isTRUE(batched_context$marked)) {
      myc_transition_trace(
        "myc_sidebar_auto_commodity_marked",
        details = list(commodity = commodity, branch = branch, pre_entry_commodity = context$pre_entry_commodity)
      )
      return(invisible(TRUE))
    }

    if (isTRUE(context$manual_commodity_override)) {
      return(invisible(FALSE))
    }
    if (
      identical(context$automatic_commodity, commodity) &&
      identical(context$automatic_commodity_branch, branch)
    ) {
      return(invisible(FALSE))
    }

    context$automatic_commodity <- commodity
    context$automatic_commodity_branch <- branch
    write_myc_sidebar_transition_context(context)

    myc_transition_trace(
      "myc_sidebar_auto_commodity_marked",
      details = list(commodity = commodity, branch = branch, pre_entry_commodity = context$pre_entry_commodity)
    )

    invisible(TRUE)
  }

  mark_myc_manual_commodity_choice <- function(commodity) {
    if (!identical(input$main_tabs_panel, "Market Year Comparison Tool")) return(invisible(FALSE))

    commodity <- scalar_myc_sidebar_value(commodity)
    if (is.null(commodity)) return(invisible(FALSE))

    context <- read_myc_sidebar_transition_context()
    if (!isTRUE(context$active) || is.null(context$automatic_commodity)) return(invisible(FALSE))
    if (identical(commodity, context$automatic_commodity)) return(invisible(FALSE))

    context$manual_commodity_override <- TRUE
    context$automatic_commodity <- NULL
    context$automatic_commodity_branch <- NULL
    write_myc_sidebar_transition_context(context)

    myc_transition_trace(
      "myc_sidebar_manual_commodity_marked",
      details = list(commodity = commodity)
    )

    invisible(TRUE)
  }

  is_myc_automatic_commodity_value <- function(commodity) {
    commodity <- scalar_myc_sidebar_value(commodity)
    if (is.null(commodity)) return(FALSE)

    context <- read_myc_sidebar_transition_context()
    !isTRUE(context$manual_commodity_override) &&
      !is.null(context$automatic_commodity) &&
      identical(commodity, context$automatic_commodity)
  }

  myc_sidebar_country_is_legal <- function(country) {
    country <- scalar_myc_sidebar_value(country)
    if (is.null(country)) return(FALSE)

    if (!identical(input$main_tabs_panel, "Market Year Comparison Tool")) {
      base_choices <- tryCatch(country_display_names_for_frequency(), error = function(e) NULL)
      if (is.null(base_choices) || length(base_choices) == 0) {
        base_choices <- country_display_names
      }
      return(country %in% as.character(unname(base_choices %||% character(0))))
    }

    choices <- tryCatch(country_choice_options(), error = function(e) NULL)
    country %in% as.character(unname(choices %||% character(0)))
  }

  myc_sidebar_commodity_is_legal <- function(commodity) {
    commodity <- scalar_myc_sidebar_value(commodity)
    if (is.null(commodity)) return(FALSE)

    choices <- tryCatch(commodity_choice_fallback_values(), error = function(e) NULL)
    commodity %in% as.character(unname(choices %||% character(0)))
  }

  complete_myc_sidebar_restore_if_ready <- function(reason = "input_observed") {
    context <- read_myc_sidebar_transition_context()
    if (!isTRUE(context$restore_pending)) return(invisible(FALSE))

    current_country <- scalar_myc_sidebar_value(isolate(input$country_choice))
    current_commodity <- scalar_myc_sidebar_value(isolate(input$commodity_choice))

    country_done <-
      is.null(context$automatic_country) ||
      isTRUE(context$manual_country_override) ||
      !identical(current_country, context$automatic_country)
    commodity_done <-
      is.null(context$automatic_commodity) ||
      isTRUE(context$manual_commodity_override) ||
      !identical(current_commodity, context$automatic_commodity)

    if (isTRUE(country_done) && isTRUE(commodity_done)) {
      reset_myc_sidebar_transition_context(reason)
      return(invisible(TRUE))
    }

    invisible(FALSE)
  }

  restore_myc_sidebar_transition_context <- function(trigger = "unknown", leaving_myc = FALSE) {
    context <- read_myc_sidebar_transition_context()
    if (!isTRUE(context$active) && !isTRUE(context$restore_pending)) {
      return(invisible(FALSE))
    }

    current_country <- scalar_myc_sidebar_value(isolate(input$country_choice))
    current_commodity <- scalar_myc_sidebar_value(isolate(input$commodity_choice))
    current_pending_country <- scalar_myc_sidebar_value(isolate(pending_sidebar_country_target()))
    scheduled_updates <- character(0)

    if (
      !is.null(context$automatic_country) &&
      !isTRUE(context$manual_country_override) &&
      identical(current_country, context$automatic_country) &&
      myc_sidebar_country_is_legal(context$pre_entry_country)
    ) {
      country_update_scheduled <- FALSE
      if (!identical(current_pending_country, context$pre_entry_country)) {
        pending_sidebar_country_target(context$pre_entry_country)
        current_pending_country <- context$pre_entry_country
        country_update_scheduled <- TRUE
      }

      if (!identical(current_country, context$pre_entry_country)) {
        updateSelectizeInput(session, "country_choice", selected = context$pre_entry_country)
        country_update_scheduled <- TRUE
      }

      if (isTRUE(country_update_scheduled)) {
        scheduled_updates <- c(scheduled_updates, "country")
      }
    }

    if (
      !is.null(context$automatic_commodity) &&
      !isTRUE(context$manual_commodity_override) &&
      identical(current_commodity, context$automatic_commodity) &&
      myc_sidebar_commodity_is_legal(context$pre_entry_commodity)
    ) {
      if (!identical(current_commodity, context$pre_entry_commodity)) {
        updateSelectizeInput(session, "commodity_choice", selected = context$pre_entry_commodity)
        scheduled_updates <- c(scheduled_updates, "commodity")
      }
    }

    if (length(scheduled_updates) > 0) {
      context$active <- !isTRUE(leaving_myc)
      context$restore_pending <- TRUE
      write_myc_sidebar_transition_context(context)
      myc_transition_trace(
        "myc_sidebar_context_restore",
        details = list(
          trigger = trigger,
          leaving_myc = isTRUE(leaving_myc),
          updates = paste(scheduled_updates, collapse = "|"),
          pre_entry_country = context$pre_entry_country,
          pre_entry_commodity = context$pre_entry_commodity,
          automatic_country = context$automatic_country,
          automatic_commodity = context$automatic_commodity
        )
      )
      return(invisible(TRUE))
    }

    if (isTRUE(leaving_myc)) {
      reset_myc_sidebar_transition_context(trigger)
    }

    invisible(FALSE)
  }

  observeEvent(input$main_tabs_panel, {
    if (identical(input$main_tabs_panel, "Market Year Comparison Tool")) {
      capture_myc_sidebar_entry_context("main_tabs_panel")
    } else {
      restore_myc_sidebar_transition_context("main_tabs_panel_exit", leaving_myc = TRUE)
    }
  }, ignoreInit = TRUE, priority = 120)

  mark_myc_transition_mutation <- function(event, details = list()) {
    next_seq <- isolate(myc_transition_mutation_seq()) + 1L
    myc_transition_mutation_seq(next_seq)
    myc_transition_trace(event, details = details)
    invisible(next_seq)
  }

  request_partner_show_probe <- function(reason, delay_ms = 60L) {
    if (!isTRUE(myc_selectize_probe_enabled())) {
      return(invisible(FALSE))
    }

    payload <- list(
      reason = reason,
      action_id = isolate(myc_transition_action_id()),
      mutation_seq = isolate(myc_transition_mutation_seq()),
      requested_at_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%OS3Z", tz = "UTC"),
      delay_ms = as.integer(delay_ms)
    )

    session$onFlushed(function() {
      session$sendCustomMessage("capturePartnerShowProbe", payload)
    }, once = TRUE)

    invisible(TRUE)
  }

  request_myc_output_probe <- function(reason, delay_ms = 90L) {
    if (!isTRUE(myc_selectize_probe_enabled())) {
      return(invisible(FALSE))
    }

    payload <- list(
      reason = reason,
      action_id = isolate(myc_transition_action_id()),
      mutation_seq = isolate(myc_transition_mutation_seq()),
      requested_at_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%OS3Z", tz = "UTC"),
      delay_ms = as.integer(delay_ms)
    )

    session$onFlushed(function() {
      session$sendCustomMessage("captureMycOutputProbe", payload)
    }, once = TRUE)

    invisible(TRUE)
  }

  market_year_auto_collapse_share_threshold <- 0.01

  build_myc_partner_basis_signature <- function(share_data) {
    if (is.null(share_data)) return(NULL)

    paste(
      share_data$comparison_mode %||% "unknown_mode",
      share_data$metric_col %||% "unknown_metric",
      share_data$focus_label %||% "unknown_focus",
      share_data$current_my %||% "unknown_current_my",
      share_data$comparison_basis_mode %||% "unknown_basis_mode",
      paste(sort(unique(share_data$comparison_basis_years %||% numeric(0))), collapse = ","),
      share_data$comparison_reference_year %||% "unknown_reference_year",
      sep = "|"
    )
  }

  invalidate_partner_input_selection <- function(
    force_default = TRUE,
    reset_override = NULL,
    reset_override_manual = NULL,
    preserve_remembered_state = FALSE,
    top_up_defaults_on_repopulation = FALSE
  ) {
    partner_selection_context_version(partner_selection_context_version() + 1L)
    partner_selection_force_default(isTRUE(force_default))
    partner_selection_manual_override(FALSE)
    partner_selection_reset_override(reset_override)
    partner_selection_reset_override_manual(reset_override_manual)
    partner_selection_preserve_remembered_state(isTRUE(preserve_remembered_state))
    partner_selection_top_up_defaults_on_repopulation(isTRUE(top_up_defaults_on_repopulation))

    mark_myc_transition_mutation(
      "invalidate_partner_input_selection",
      details = list(
        force_default = isTRUE(force_default),
        reset_override_size = length(reset_override %||% character(0)),
        reset_override_manual = isTRUE(reset_override_manual),
        preserve_remembered_state = isTRUE(preserve_remembered_state),
        top_up_defaults_on_repopulation = isTRUE(top_up_defaults_on_repopulation),
        context_version = partner_selection_context_version()
      )
    )
  }

  clear_partner_show_input <- function(preserve_transition_state = FALSE) {
    if (!isTRUE(preserve_transition_state)) {
      myc_native_reset_excluded_partners(character(0))
      partner_selection_reset_override(NULL)
      partner_selection_reset_override_manual(NULL)
      partner_selection_preserve_remembered_state(FALSE)
      partner_selection_top_up_defaults_on_repopulation(FALSE)
    }
    partner_selection_programmatic_selected(character(0))
    partner_selection_programmatic_manual(FALSE)
    partner_selection_legalized_override(NULL)

    mark_myc_transition_mutation(
      "clear_partner_show_input",
      details = list(
        preserve_transition_state = isTRUE(preserve_transition_state)
      )
    )

    updateSelectizeInput(session, "partner_show", choices = NULL, selected = character(0), server = TRUE)
    request_partner_show_probe("clear_partner_show_input")
    request_myc_output_probe("clear_partner_show_input")
    session$sendCustomMessage("forcePlotlyResize", list(tab = "Market Year Comparison Tool"))
    request_myc_output_probe("clear_partner_show_input_after_plotly_redraw", delay_ms = 420L)
  }

  flatten_myc_partner_choice_values <- function(choices, comparison_mode = market_year_comparison_mode()) {
    if (is.null(choices) || length(choices) == 0) return(character(0))

    if (is.list(choices) && !is.atomic(choices)) {
      flattened <- unlist(lapply(choices, function(group_choices) {
        flatten_myc_partner_choice_values(group_choices, comparison_mode = comparison_mode)
      }), use.names = FALSE)

      flattened <- as.character(flattened)
      flattened <- flattened[!is.na(flattened) & nzchar(flattened)]
      return(unique(flattened))
    }

    choice_values <- as.character(unname(choices))
    normalized_values <- normalize_myc_partner_values(choice_values, comparison_mode = comparison_mode)
    unique(normalized_values[!is.na(normalized_values) & nzchar(normalized_values)])
  }

  normalize_myc_partner_choice_map <- function(choices, comparison_mode = market_year_comparison_mode()) {
    if (is.null(choices) || length(choices) == 0) return(character(0))

    normalize_choice_vector <- function(choice_vector) {
      choice_values <- as.character(unname(choice_vector))
      normalized_values <- normalize_myc_partner_values(choice_values, comparison_mode = comparison_mode)

      if (!is.null(names(choice_vector)) && length(names(choice_vector)) == length(choice_values)) {
        labels <- as.character(names(choice_vector))
      } else {
        labels <- normalized_values
      }

      keep_idx <- !is.na(normalized_values) & nzchar(normalized_values)
      normalized_values <- normalized_values[keep_idx]
      labels <- labels[keep_idx]

      if (length(normalized_values) == 0) return(character(0))

      dedupe_idx <- !duplicated(normalized_values)
      stats::setNames(normalized_values[dedupe_idx], labels[dedupe_idx])
    }

    if (is.list(choices) && !is.atomic(choices)) {
      group_names <- names(choices)
      if (is.null(group_names)) {
        group_names <- rep("", length(choices))
      }

      seen_values <- character(0)
      normalized_groups <- list()

      for (idx in seq_along(choices)) {
        group_name <- trimws(as.character(group_names[[idx]] %||% ""))
        if (!nzchar(group_name)) {
          group_name <- paste0("Group ", idx)
        }

        group_choice_map <- normalize_choice_vector(choices[[idx]])
        if (length(group_choice_map) == 0) {
          next
        }

        group_values <- as.character(unname(group_choice_map))
        keep_idx <- !(group_values %in% seen_values)
        group_choice_map <- group_choice_map[keep_idx]
        if (length(group_choice_map) == 0) {
          next
        }

        seen_values <- c(seen_values, as.character(unname(group_choice_map)))

        normalized_groups[[group_name]] <- group_choice_map
      }

      if (length(normalized_groups) == 0) {
        return(character(0))
      }

      return(normalized_groups)
    }

    normalize_choice_vector(choices)
  }

  remove_myc_partner_choices <- function(choices, removed_values, comparison_mode = market_year_comparison_mode()) {
    normalized_removed <- normalize_myc_partner_values(removed_values, comparison_mode = comparison_mode)
    normalized_removed <- unique(normalized_removed[!is.na(normalized_removed) & nzchar(normalized_removed)])
    if (length(normalized_removed) == 0 || is.null(choices) || length(choices) == 0) return(choices)

    prune_choice_vector <- function(choice_vector) {
      choice_values <- normalize_myc_partner_values(as.character(unname(choice_vector)), comparison_mode = comparison_mode)
      keep_idx <- !(choice_values %in% normalized_removed)
      choice_vector[keep_idx]
    }

    if (is.list(choices) && !is.atomic(choices)) {
      pruned_choices <- lapply(choices, prune_choice_vector)
      pruned_choices <- pruned_choices[vapply(pruned_choices, length, integer(1)) > 0]
      return(pruned_choices)
    }

    prune_choice_vector(choices)
  }

  update_partner_show_input <- function(choices, selected, selection_is_manual = FALSE) {
    comparison_mode <- market_year_comparison_mode()
    normalized_choice_map <- normalize_myc_partner_choice_map(choices, comparison_mode = comparison_mode)
    normalized_selected <- normalize_myc_partner_values(selected, comparison_mode = comparison_mode)
    normalized_choice_values <- flatten_myc_partner_choice_values(normalized_choice_map, comparison_mode = comparison_mode)
    partner_selection_programmatic_selected(normalized_selected)
    partner_selection_programmatic_manual(isTRUE(selection_is_manual))

    mark_myc_transition_mutation(
      "update_partner_show_input",
      details = list(
        choices = length(normalized_choice_values),
        selected = length(normalized_selected),
        selection_is_manual = isTRUE(selection_is_manual)
      )
    )

    updateSelectizeInput(
      session,
      "partner_show",
      choices = normalized_choice_map,
      selected = normalized_selected,
      server = !is.list(normalized_choice_map)
    )

    request_partner_show_probe("update_partner_show_input")
    request_myc_output_probe("update_partner_show_input")
    session$sendCustomMessage("forcePlotlyResize", list(tab = "Market Year Comparison Tool"))
    request_myc_output_probe("update_partner_show_input_after_plotly_redraw", delay_ms = 420L)
  }

  force_partner_show_visible_selection <- function(selected, reason = "server_force", delay_ms = 0L) {
    comparison_mode <- market_year_comparison_mode()
    normalized_selected <- normalize_myc_partner_values(selected, comparison_mode = comparison_mode)
    normalized_selected <- unique(normalized_selected[!is.na(normalized_selected) & nzchar(normalized_selected)])

    session$sendCustomMessage(
      "forcePartnerShowSelection",
      list(
        selected = unname(as.list(normalized_selected)),
        reason = reason,
        delay_ms = delay_ms
      )
    )

    request_partner_show_probe(paste0(reason, "_force_visible"), delay_ms = delay_ms + 80L)
    invisible(normalized_selected)
  }

  set_partner_selection_legalized_override <- function(comparison_mode, selection) {
    normalized_selection <- normalize_myc_partner_values(selection, comparison_mode = comparison_mode)
    partner_selection_legalized_override(list(
      comparison_mode = comparison_mode,
      selection = normalized_selection
    ))
    invisible(normalized_selection)
  }

  get_partner_selection_legalized_override <- function(comparison_mode = market_year_comparison_mode()) {
    override <- isolate(partner_selection_legalized_override())
    if (is.null(override) || !identical(override$comparison_mode %||% "", comparison_mode)) {
      return(character(0))
    }

    normalize_myc_partner_values(override$selection %||% character(0), comparison_mode = comparison_mode)
  }

  clear_partner_selection_legalized_override <- function() {
    partner_selection_legalized_override(NULL)
    invisible(NULL)
  }

  get_remembered_partner_selection_state <- function(comparison_mode = market_year_comparison_mode()) {
    if (identical(comparison_mode, "type")) {
      return(list(
        selection = normalize_myc_partner_values(last_type_comparison_selection(), comparison_mode = "type"),
        selection_is_manual = isTRUE(last_type_comparison_selection_manual())
      ))
    }

    list(
      selection = normalize_myc_partner_values(last_country_comparison_selection(), comparison_mode = "country"),
      selection_is_manual = isTRUE(last_country_comparison_selection_manual())
    )
  }

  get_world_type_partner_selection_state <- function() {
    list(
      selection = normalize_myc_partner_values(last_world_type_comparison_selection(), comparison_mode = "type"),
      selection_is_manual = isTRUE(last_world_type_comparison_selection_manual())
    )
  }

  set_remembered_partner_selection_state <- function(
    comparison_mode = market_year_comparison_mode(),
    selection = character(0),
    selection_is_manual = FALSE
  ) {
    normalized_selection <- normalize_myc_partner_values(selection, comparison_mode = comparison_mode)

    if (identical(comparison_mode, "type")) {
      last_type_comparison_selection(normalized_selection)
      last_type_comparison_selection_manual(isTRUE(selection_is_manual))
      if (identical(input$country_choice, "GRAND_TOTAL")) {
        last_world_type_comparison_selection(normalized_selection)
        last_world_type_comparison_selection_manual(isTRUE(selection_is_manual))
      }
      return(invisible(NULL))
    }

    last_country_comparison_selection(normalized_selection)
    last_country_comparison_selection_manual(isTRUE(selection_is_manual))
    invisible(NULL)
  }

  reset_world_type_partner_selection_state <- function() {
    last_world_type_comparison_selection(character(0))
    last_world_type_comparison_selection_manual(FALSE)
    invisible(NULL)
  }

  get_remembered_partner_selection <- function(
    comparison_mode = market_year_comparison_mode(),
    eligible_choices = NULL,
    manual_only = FALSE
  ) {
    state <- get_remembered_partner_selection_state(comparison_mode)
    if (isTRUE(manual_only) && !isTRUE(state$selection_is_manual)) {
      return(character(0))
    }

    remembered_selection <- state$selection
    if (!is.null(eligible_choices)) {
      remembered_selection <- remembered_selection[remembered_selection %in% unique(normalize_myc_partner_values(eligible_choices, comparison_mode = comparison_mode))]
    }

    unique(remembered_selection)
  }

  update_remembered_partner_selection_from_visible <- function(
    comparison_mode = market_year_comparison_mode(),
    visible_selection,
    eligible_choices,
    selection_is_manual = TRUE
  ) {
    eligible_choices <- unique(normalize_myc_partner_values(eligible_choices, comparison_mode = comparison_mode))
    visible_selection <- unique(normalize_myc_partner_values(visible_selection, comparison_mode = comparison_mode))
    current_state <- get_remembered_partner_selection_state(comparison_mode)
    hidden_selection <- current_state$selection[!(current_state$selection %in% eligible_choices)]

    set_remembered_partner_selection_state(
      comparison_mode = comparison_mode,
      selection = unique(c(hidden_selection, visible_selection)),
      selection_is_manual = selection_is_manual
    )
  }

  reset_market_year_comparison_selection <- function(comparison_mode) {
    set_remembered_partner_selection_state(comparison_mode, character(0), FALSE)
  }

  capture_active_myc_partner_selection_state <- function(comparison_mode = market_year_comparison_mode()) {
    record_partner_share_data_read("capture_active_myc_partner_selection_state")
    share_data <- tryCatch(partner_share_data(), error = function(e) NULL)
    if (is.null(share_data)) {
      return(list(selection = character(0), selection_is_manual = FALSE))
    }

    partner_choices <- unique(normalize_myc_partner_values(share_data$eligible_partners, comparison_mode = comparison_mode))
    current_input_selection <- normalize_myc_partner_values(isolate(input$partner_show), comparison_mode = comparison_mode)
    legal_current_input <- unique(current_input_selection[current_input_selection %in% partner_choices])
    remembered_state <- get_remembered_partner_selection_state(comparison_mode)
    legal_remembered_selection <- unique(remembered_state$selection[remembered_state$selection %in% partner_choices])

    if (identical(partner_selection_input_version(), partner_selection_context_version()) && isTRUE(partner_selection_manual_override()) && length(legal_current_input) > 0) {
      return(list(selection = legal_current_input, selection_is_manual = TRUE))
    }

    if (isTRUE(remembered_state$selection_is_manual) && length(legal_remembered_selection) > 0) {
      return(list(selection = legal_remembered_selection, selection_is_manual = TRUE))
    }

    effective_selection <- normalize_myc_partner_values(isolate(market_year_effective_partner_selection()), comparison_mode = comparison_mode)
    list(
      selection = unique(effective_selection[effective_selection %in% partner_choices]),
      selection_is_manual = FALSE
    )
  }

  is_myc_hybrid_type_mode_active <- function() {
    source_choice <- current_source_choice_safe()

    identical(input$main_tabs_panel, "Market Year Comparison Tool") &&
      identical(market_year_comparison_mode(), "type") &&
      identical(source_choice, "hybrid") &&
      identical(if (!is.null(input$hybrid_trade_flow_choice)) input$hybrid_trade_flow_choice else "export", "export")
  }

  is_myc_type_mode_active <- function() {
    identical(input$main_tabs_panel, "Market Year Comparison Tool") &&
      identical(market_year_comparison_mode(), "type")
  }

  normalize_myc_type_selection_values <- function(values) {
    normalized_values <- normalize_myc_partner_values(values, comparison_mode = "type")
    unique(normalized_values[nzchar(normalized_values)])
  }

  get_myc_native_display_map <- function() {
    source_choice <- current_source_choice_safe()
    native_choices <- unique(active_native_commodities())
    stats::setNames(vapply(native_choices, function(commodity_name) {
      get_commodity_display_label(
        commodity_name,
        input$basis_choice,
        source_choice = source_choice,
        hybrid_trade_flow = if (identical(source_choice, "hybrid")) active_hybrid_trade_flow() else "export"
      )
    }, character(1)), native_choices)
  }

  get_myc_native_default_partner_choices <- function(eligible_partners) {
    normalized_eligible <- normalize_myc_type_selection_values(eligible_partners)
    native_display_values <- unique(unname(get_myc_native_display_map()))
    native_display_values <- normalize_myc_type_selection_values(native_display_values)

    normalized_eligible[normalized_eligible %in% native_display_values]
  }

  get_myc_native_raw_name_from_display <- function(display_name) {
    display_map <- get_myc_native_display_map()
    matches <- names(display_map)[display_map == display_name]
    if (length(matches) == 0) return(NA_character_)
    matches[[1]]
  }

  get_myc_native_leaf_set <- function(native_name) {
    native_choices <- unique(active_native_commodities())
    if (!(native_name %in% native_choices)) return(character(0))

    source_choice <- current_source_choice_safe()
    if (identical(source_choice, "hybrid") && identical(active_hybrid_trade_flow(), "export") && native_name %in% native_hybrid_export_nodes) {
      return(sort(get_native_hybrid_export_leaf_descendants(native_name)))
    }

    native_name
  }

  sanitize_native_hybrid_partner_selection <- function(selection) {
    normalized_selection <- normalize_myc_type_selection_values(selection)
    if (!is_myc_hybrid_type_mode_active()) {
      return(list(selection = normalized_selection, removed_parents = character(0)))
    }

    native_selection <- normalized_selection[normalized_selection %in% native_hybrid_export_nodes]

    removed_parents <- unique(vapply(native_selection, function(selection_name) {
      if (!(selection_name %in% native_hybrid_export_parent_nodes)) {
        return(NA_character_)
      }

      candidate_leaves <- get_native_hybrid_export_leaf_descendants(selection_name)
      overlapping_descendants <- setdiff(native_selection, selection_name)
      overlapping_descendants <- overlapping_descendants[vapply(overlapping_descendants, function(other_name) {
        other_leaves <- get_native_hybrid_export_leaf_descendants(other_name)
        length(other_leaves) > 0 && all(other_leaves %in% candidate_leaves)
      }, logical(1))]

      if (length(overlapping_descendants) > 0) selection_name else NA_character_
    }, character(1)))
    removed_parents <- removed_parents[!is.na(removed_parents)]

    list(
      selection = unique(c(
        normalized_selection[!(normalized_selection %in% native_selection)],
        setdiff(native_selection, removed_parents)
      )),
      removed_parents = removed_parents
    )
  }

  derive_native_hybrid_parent_exclusions <- function(selection, eligible_partners = NULL) {
    if (!is_myc_hybrid_type_mode_active()) return(character(0))

    normalized_selection <- normalize_myc_type_selection_values(selection)
    selected_native_items <- normalized_selection[normalized_selection %in% native_hybrid_export_nodes]

    if (!is.null(eligible_partners)) {
      eligible_native_items <- normalize_myc_type_selection_values(eligible_partners)
      eligible_native_items <- eligible_native_items[eligible_native_items %in% native_hybrid_export_nodes]
    } else {
      eligible_native_items <- native_hybrid_export_nodes
    }

    selected_leaf_items <- selected_native_items[selected_native_items %in% native_hybrid_export_leaf_nodes]
    if (length(selected_leaf_items) == 0) {
      return(character(0))
    }

    native_parent_candidates <- setdiff(eligible_native_items, native_hybrid_export_leaf_nodes)
    unique(native_parent_candidates[vapply(native_parent_candidates, function(parent_name) {
      parent_leaves <- get_native_hybrid_export_leaf_descendants(parent_name)
      length(intersect(parent_leaves, selected_leaf_items)) > 0
    }, logical(1))])
  }

  resolve_hybrid_native_default_partner_state <- function(eligible_partners, basis_state) {
    auto_display_partners <- unique(normalize_myc_type_selection_values(basis_state$auto_display_partners))
    default_partners <- unique(normalize_myc_type_selection_values(basis_state$default_partners))
    excluded_partners <- character(0)

    if (!is_myc_hybrid_type_mode_active()) {
      return(list(
        auto_display_partners = auto_display_partners,
        default_partners = default_partners,
        excluded_partners = excluded_partners
      ))
    }

    eligible_native_leaves <- normalize_myc_type_selection_values(eligible_partners)
    eligible_native_leaves <- eligible_native_leaves[eligible_native_leaves %in% native_hybrid_export_leaf_nodes]

    if (length(eligible_native_leaves) == 0) {
      return(list(
        auto_display_partners = auto_display_partners,
        default_partners = default_partners,
        excluded_partners = excluded_partners
      ))
    }

    ranked_native_leaves <- normalize_myc_type_selection_values(basis_state$ranked_partners)
    ranked_native_leaves <- ranked_native_leaves[ranked_native_leaves %in% eligible_native_leaves]
    resolved_native_leaves <- unique(c(ranked_native_leaves, eligible_native_leaves))
    excluded_partners <- derive_native_hybrid_parent_exclusions(
      selection = resolved_native_leaves,
      eligible_partners = eligible_partners
    )

    list(
      auto_display_partners = resolved_native_leaves,
      default_partners = resolved_native_leaves,
      excluded_partners = excluded_partners
    )
  }

  build_exact_myc_custom_signature <- function(selection_name) {
    if (!is_myc_type_mode_active()) return(NULL)

    custom_def <- custom_types_enriched() %>%
      filter(.data$parse_ok, .data$custom_name == selection_name)

    if (nrow(custom_def) == 0) return(NULL)

    parsed_def <- custom_def$parsed[[1]]
    if (is.null(parsed_def) || is.null(parsed_def$coefficients)) return(NULL)

    coeffs <- parsed_def$coefficients
    coeffs <- coeffs[abs(coeffs) > 1e-12]
    if (length(coeffs) == 0) return(NULL)
    if (any(abs(coeffs - 1) > 1e-12)) return(NULL)

    native_choices <- unique(active_native_commodities())
    if (!all(names(coeffs) %in% native_choices)) return(NULL)

    leaf_weights <- numeric(0)
    for (ref_name in names(coeffs)) {
      ref_leaves <- get_myc_native_leaf_set(ref_name)
      if (length(ref_leaves) == 0) return(NULL)

      missing_leaf_names <- setdiff(ref_leaves, names(leaf_weights))
      if (length(missing_leaf_names) > 0) {
        leaf_weights[missing_leaf_names] <- 0
      }
      leaf_weights[ref_leaves] <- leaf_weights[ref_leaves] + coeffs[[ref_name]]
    }

    if (any(abs(leaf_weights - round(leaf_weights)) > 1e-12)) return(NULL)
    if (any(leaf_weights > 1)) return(NULL)

    leaf_set <- sort(names(leaf_weights[leaf_weights > 0]))
    if (length(leaf_set) == 0) return(NULL)

    native_display_map <- get_myc_native_display_map()
    covered_native_raw <- native_choices[vapply(native_choices, function(native_name) {
      native_leaf_set <- get_myc_native_leaf_set(native_name)
      length(native_leaf_set) > 0 && all(native_leaf_set %in% leaf_set)
    }, logical(1))]
    covered_native_display <- sort(unique(unname(native_display_map[covered_native_raw])))

    list(
      name = selection_name,
      leaf_set = leaf_set,
      covered_native_display = setdiff(covered_native_display, selection_name),
      covered_native_raw = setdiff(covered_native_raw, selection_name)
    )
  }

  derive_exact_myc_custom_component_exclusions <- function(selection, eligible_partners = NULL) {
    normalized_selection <- normalize_myc_type_selection_values(selection)
    native_display_values <- unique(unname(get_myc_native_display_map()))
    selected_custom_names <- setdiff(normalized_selection, native_display_values)

    custom_signatures <- lapply(selected_custom_names, build_exact_myc_custom_signature)
    custom_signatures <- Filter(Negate(is.null), custom_signatures)
    if (length(custom_signatures) == 0) return(character(0))

    excluded_display <- sort(unique(unlist(lapply(custom_signatures, `[[`, "covered_native_display"), use.names = FALSE)))
    if (!is.null(eligible_partners)) {
      eligible_display <- normalize_myc_type_selection_values(eligible_partners)
      excluded_display <- excluded_display[excluded_display %in% eligible_display]
    }

    excluded_display[nzchar(excluded_display)]
  }

  detect_exact_myc_custom_selected_overrides <- function(selection, eligible_partners = NULL) {
    normalized_selection <- normalize_myc_type_selection_values(selection)
    native_display_values <- unique(unname(get_myc_native_display_map()))
    selected_custom_names <- setdiff(normalized_selection, native_display_values)

    custom_signatures <- lapply(selected_custom_names, build_exact_myc_custom_signature)
    custom_signatures <- Filter(Negate(is.null), custom_signatures)
    if (length(custom_signatures) == 0) {
      return(data.frame(
        custom_name = character(),
        native_name = character(),
        stringsAsFactors = FALSE
      ))
    }

    override_rows <- lapply(custom_signatures, function(custom_signature) {
      selected_native_names <- intersect(custom_signature$covered_native_display, normalized_selection)
      if (length(selected_native_names) == 0) return(NULL)

      data.frame(
        custom_name = custom_signature$name,
        native_name = selected_native_names,
        stringsAsFactors = FALSE
      )
    })
    override_rows <- Filter(Negate(is.null), override_rows)
    if (length(override_rows) == 0) {
      return(data.frame(
        custom_name = character(),
        native_name = character(),
        stringsAsFactors = FALSE
      ))
    }

    override_df <- bind_rows(override_rows) %>% distinct()
    if (!is.null(eligible_partners)) {
      eligible_display <- normalize_myc_type_selection_values(eligible_partners)
      override_df <- override_df %>% filter(.data$native_name %in% eligible_display)
    }

    override_df
  }

  get_myc_country_partner_code_map <- function() {
    snap <- tryCatch(partner_snapshot(), error = function(e) NULL)
    if (is.null(snap) || !is.data.frame(snap$df) || nrow(snap$df) == 0) {
      return(stats::setNames(character(0), character(0)))
    }

    if (!("comparison_item" %in% names(snap$df)) || !("country" %in% names(snap$df))) {
      return(stats::setNames(character(0), character(0)))
    }

    map_df <- snap$df %>%
      transmute(
        comparison_item = normalize_myc_country_selection_values(.data$comparison_item),
        country = trimws(as.character(.data$country))
      ) %>%
      filter(!is.na(.data$comparison_item), nzchar(.data$comparison_item), !is.na(.data$country), nzchar(.data$country)) %>%
      mutate(priority = if_else(startsWith(.data$country, CUSTOM_COUNTRY_CHOICE_PREFIX), 2L, 1L)) %>%
      arrange(.data$comparison_item, dplyr::desc(.data$priority), .data$country) %>%
      distinct(.data$comparison_item, .keep_all = TRUE)

    stats::setNames(map_df$country, map_df$comparison_item)
  }

  resolve_myc_custom_country_leaf_set <- function(custom_name_key, defs_by_key, active_stack = character(0)) {
    custom_name_key <- tolower(trimws(as.character(custom_name_key %||% "")))
    custom_name_key <- custom_name_key[!is.na(custom_name_key) & nzchar(custom_name_key)]
    if (length(custom_name_key) == 0) {
      return(character(0))
    }

    custom_name_key <- custom_name_key[[1]]
    if (custom_name_key %in% active_stack) {
      return(character(0))
    }

    def_rows <- defs_by_key[[custom_name_key]]
    if (is.null(def_rows) || nrow(def_rows) == 0) {
      return(character(0))
    }

    parsed <- def_rows$parsed[[1]]
    if (is.null(parsed) || is.null(parsed$coefficients)) {
      return(character(0))
    }

    coeffs <- parsed$coefficients
    term_keys <- names(coeffs %||% numeric(0))
    term_keys <- term_keys[!is.na(term_keys) & nzchar(term_keys)]
    if (length(term_keys) == 0) {
      return(character(0))
    }

    leaf_set <- character(0)
    for (term_key in term_keys) {
      coef_value <- suppressWarnings(as.numeric(coeffs[[term_key]]))
      if (!is.finite(coef_value) || abs(coef_value) <= 1e-12) next

      if (startsWith(term_key, "custom:")) {
        child_key <- sub("^custom:", "", term_key)
        child_leaf_set <- resolve_myc_custom_country_leaf_set(
          custom_name_key = child_key,
          defs_by_key = defs_by_key,
          active_stack = c(active_stack, custom_name_key)
        )
        leaf_set <- c(leaf_set, child_leaf_set)
      } else {
        leaf_set <- c(leaf_set, term_key)
      }
    }

    sort(unique(leaf_set[nzchar(leaf_set)]))
  }

  build_myc_country_overlap_items <- function(selection, eligible_partners = NULL) {
    normalized_selection <- normalize_myc_country_selection_values(selection)
    if (!is.null(eligible_partners)) {
      eligible_partners <- normalize_myc_country_selection_values(eligible_partners)
      normalized_selection <- normalized_selection[normalized_selection %in% eligible_partners]
    }
    normalized_selection <- unique(normalized_selection[nzchar(normalized_selection)])
    if (length(normalized_selection) == 0) {
      return(list())
    }

    country_code_map <- get_myc_country_partner_code_map()
    if (length(country_code_map) == 0) {
      return(list())
    }

    defs_tbl <- as_tibble(tryCatch(custom_countries_enriched(), error = function(e) data.frame())) %>%
      filter(.data$parse_ok) %>%
      mutate(custom_name_key = tolower(trimws(as.character(.data$custom_name)))) %>%
      filter(!is.na(.data$custom_name_key), nzchar(.data$custom_name_key)) %>%
      arrange(.data$custom_name_key, .data$custom_name) %>%
      distinct(.data$custom_name_key, .keep_all = TRUE)
    defs_by_key <- split(defs_tbl, defs_tbl$custom_name_key)
    custom_display_lookup <- if (nrow(defs_tbl) > 0) {
      display_values <- normalize_myc_country_selection_values(defs_tbl$custom_name)
      stats::setNames(defs_tbl$custom_name_key, tolower(display_values))
    } else {
      stats::setNames(character(0), character(0))
    }

    overlap_items <- list()
    for (selection_name in normalized_selection) {
      country_code <- unname(country_code_map[selection_name])
      country_code <- country_code[!is.na(country_code)]
      country_code <- if (length(country_code) > 0) country_code[[1L]] else ""
      country_code <- trimws(as.character(country_code %||% ""))
      if (!nzchar(country_code)) {
        selection_key <- tolower(trimws(as.character(selection_name %||% "")))
        mapped_custom_key <- unname(custom_display_lookup[selection_key])
        mapped_custom_key <- mapped_custom_key[!is.na(mapped_custom_key) & nzchar(mapped_custom_key)]
        if (length(mapped_custom_key) == 0) next

        leaf_set <- resolve_myc_custom_country_leaf_set(mapped_custom_key[[1L]], defs_by_key)
        if (length(leaf_set) == 0) next

        overlap_items[[length(overlap_items) + 1L]] <- list(
          name = selection_name,
          source = "custom",
          leaf_set = sort(unique(leaf_set))
        )
        next
      }

      if (isTRUE(is_custom_country_choice_value(country_code))) {
        custom_name <- parse_custom_country_choice_name(country_code)
        custom_key <- tolower(trimws(as.character(custom_name %||% "")))
        leaf_set <- resolve_myc_custom_country_leaf_set(custom_key, defs_by_key)
        if (length(leaf_set) == 0) next

        overlap_items[[length(overlap_items) + 1L]] <- list(
          name = selection_name,
          source = "custom",
          leaf_set = sort(unique(leaf_set))
        )
      } else {
        overlap_items[[length(overlap_items) + 1L]] <- list(
          name = selection_name,
          source = "native",
          leaf_set = country_code
        )
      }
    }

    overlap_items
  }

  detect_exact_myc_country_custom_native_overlaps <- function(selection, eligible_partners = NULL) {
    overlap_items <- build_myc_country_overlap_items(selection, eligible_partners = eligible_partners)
    if (length(overlap_items) < 2) {
      return(data.frame(
        custom_name = character(),
        native_name = character(),
        stringsAsFactors = FALSE
      ))
    }

    overlap_rows <- list()
    for (left_index in seq_len(length(overlap_items) - 1L)) {
      left_item <- overlap_items[[left_index]]
      for (right_index in seq.int(left_index + 1L, length(overlap_items))) {
        right_item <- overlap_items[[right_index]]
        if (identical(left_item$source, right_item$source)) next
        if (!identical(sort(left_item$leaf_set), sort(right_item$leaf_set))) next

        custom_name <- if (identical(left_item$source, "custom")) left_item$name else right_item$name
        native_name <- if (identical(left_item$source, "native")) left_item$name else right_item$name
        overlap_rows[[length(overlap_rows) + 1L]] <- data.frame(
          custom_name = custom_name,
          native_name = native_name,
          stringsAsFactors = FALSE
        )
      }
    }

    if (length(overlap_rows) == 0) {
      return(data.frame(
        custom_name = character(),
        native_name = character(),
        stringsAsFactors = FALSE
      ))
    }

    bind_rows(overlap_rows) %>% distinct()
  }

  derive_myc_country_custom_component_exclusions <- function(selection, eligible_partners = NULL) {
    normalized_selection <- normalize_myc_country_selection_values(selection)
    normalized_selection <- unique(normalized_selection[nzchar(normalized_selection)])

    normalized_eligible <- NULL
    if (!is.null(eligible_partners)) {
      normalized_eligible <- normalize_myc_country_selection_values(eligible_partners)
      normalized_selection <- normalized_selection[normalized_selection %in% normalized_eligible]
    }

    if (length(normalized_selection) == 0) {
      return(character(0))
    }

    overlap_items <- build_myc_country_overlap_items(normalized_selection, eligible_partners = normalized_eligible)
    if (length(overlap_items) == 0) {
      return(character(0))
    }

    custom_items <- overlap_items[vapply(overlap_items, function(item) {
      identical(item$source %||% "", "custom")
    }, logical(1))]
    if (length(custom_items) == 0) {
      return(character(0))
    }

    selected_leaf_codes <- unique(unlist(lapply(custom_items, function(item) item$leaf_set %||% character(0)), use.names = FALSE))
    selected_leaf_codes <- selected_leaf_codes[!is.na(selected_leaf_codes) & nzchar(selected_leaf_codes)]
    if (length(selected_leaf_codes) == 0) {
      return(character(0))
    }

    country_code_map <- get_myc_country_partner_code_map()
    if (length(country_code_map) == 0) {
      return(character(0))
    }

    map_names <- normalize_myc_country_selection_values(names(country_code_map))
    map_codes <- trimws(as.character(unname(country_code_map)))
    map_df <- tibble::tibble(
      comparison_item = map_names,
      country_code = map_codes
    ) %>%
      filter(!is.na(.data$comparison_item), nzchar(.data$comparison_item), !is.na(.data$country_code), nzchar(.data$country_code))

    if (!is.null(normalized_eligible)) {
      map_df <- map_df %>% filter(.data$comparison_item %in% normalized_eligible)
    }

    excluded_components <- map_df %>%
      filter(!startsWith(.data$country_code, CUSTOM_COUNTRY_CHOICE_PREFIX), .data$country_code %in% selected_leaf_codes) %>%
      pull(.data$comparison_item)

    sort(unique(excluded_components))
  }

  legalize_myc_country_partner_selection <- function(selection, previous_selection = character(0), eligible_partners = NULL) {
    normalized_selection <- normalize_myc_country_selection_values(selection)
    normalized_selection <- unique(normalized_selection[nzchar(normalized_selection)])

    if (!is.null(eligible_partners)) {
      eligible_partners <- normalize_myc_country_selection_values(eligible_partners)
      normalized_selection <- normalized_selection[normalized_selection %in% eligible_partners]
    }

    if (length(normalized_selection) == 0) {
      return(list(
        selection = character(0),
        removed = character(0),
        removed_components = character(0),
        removed_aggregates = character(0),
        restored_to_all_other = character(0),
        messages = character(0),
        added_anchor = NA_character_,
        exact_overlap_pairs = data.frame(custom_name = character(), native_name = character(), stringsAsFactors = FALSE)
      ))
    }

    overlap_items <- build_myc_country_overlap_items(normalized_selection, eligible_partners = eligible_partners)
    items_by_name <- stats::setNames(overlap_items, vapply(overlap_items, `[[`, character(1), "name"))

    previous_selection <- normalize_myc_country_selection_values(previous_selection)
    added_candidates <- setdiff(normalized_selection, previous_selection)
    added_anchor <- if (length(added_candidates) > 0) {
      candidate_order <- normalized_selection[normalized_selection %in% added_candidates]
      candidate_order[[length(candidate_order)]]
    } else {
      NA_character_
    }

    directional_removed <- character(0)
    removed_children <- character(0)
    removed_parents <- character(0)
    directional_messages <- character(0)
    if (!is.na(added_anchor) && added_anchor %in% names(items_by_name)) {
      anchor_item <- items_by_name[[added_anchor]]
      anchor_leaf_set <- sort(unique(anchor_item$leaf_set %||% character(0)))

      for (selection_name in normalized_selection) {
        if (identical(selection_name, added_anchor) || !(selection_name %in% names(items_by_name))) next

        candidate_item <- items_by_name[[selection_name]]
        candidate_leaf_set <- sort(unique(candidate_item$leaf_set %||% character(0)))
        if (length(anchor_leaf_set) == 0 || length(candidate_leaf_set) == 0) next

        if (length(intersect(anchor_leaf_set, candidate_leaf_set)) == 0) next

        if (all(candidate_leaf_set %in% anchor_leaf_set) && length(candidate_leaf_set) < length(anchor_leaf_set)) {
          removed_children <- c(removed_children, selection_name)
        } else if (all(anchor_leaf_set %in% candidate_leaf_set) && length(anchor_leaf_set) < length(candidate_leaf_set)) {
          removed_parents <- c(removed_parents, selection_name)
        }
      }

      removed_children <- sort(unique(removed_children))
      removed_parents <- sort(unique(removed_parents))
      directional_removed <- unique(c(removed_children, removed_parents))

      if (length(removed_children) > 0) {
        directional_messages <- c(
          directional_messages,
          paste0(
            added_anchor,
            " was added and pruned overlapping component countries: ",
            paste(removed_children, collapse = ", "),
            "."
          )
        )
      }

      if (length(removed_parents) > 0) {
        directional_messages <- c(
          directional_messages,
          paste0(
            added_anchor,
            " was added and pruned overlapping aggregate countries: ",
            paste(removed_parents, collapse = ", "),
            "."
          )
        )
      }
    }

    exact_overlap_pairs <- detect_exact_myc_country_custom_native_overlaps(
      selection = normalized_selection,
      eligible_partners = eligible_partners
    )

    exact_removed <- character(0)
    exact_messages <- character(0)
    if (nrow(exact_overlap_pairs) > 0) {
      exact_removed <- sort(unique(exact_overlap_pairs$native_name))

      exact_messages <- exact_overlap_pairs %>%
        group_by(.data$custom_name) %>%
        summarise(
          warning_message = paste0(
            .data$custom_name[[1]],
            " exactly overlaps selected native countries and auto-excludes them from effective totals: ",
            paste(sort(unique(.data$native_name)), collapse = ", "),
            "."
          ),
          .groups = "drop"
        ) %>%
        pull(.data$warning_message)
    }

    removed_values <- unique(c(directional_removed, exact_removed))
    resolved_selection <- normalized_selection[!(normalized_selection %in% removed_values)]
    resolved_selection <- unique(resolved_selection[nzchar(resolved_selection)])

    selected_custom_excluded_components <- derive_myc_country_custom_component_exclusions(
      selection = resolved_selection,
      eligible_partners = eligible_partners
    )
    selected_custom_excluded_components <- sort(unique(selected_custom_excluded_components[!is.na(selected_custom_excluded_components) & nzchar(selected_custom_excluded_components)]))
    added_anchor_is_custom <- !is.na(added_anchor) &&
      added_anchor %in% resolved_selection &&
      added_anchor %in% names(items_by_name) &&
      identical(items_by_name[[added_anchor]]$source %||% "", "custom")
    if (isTRUE(added_anchor_is_custom)) {
      anchor_component_message_values <- derive_myc_country_custom_component_exclusions(
        selection = added_anchor,
        eligible_partners = eligible_partners
      )
      anchor_component_message_values <- sort(unique(anchor_component_message_values[!is.na(anchor_component_message_values) & nzchar(anchor_component_message_values)]))
    } else {
      anchor_component_message_values <- character(0)
    }

    if (length(anchor_component_message_values) > 0) {
      directional_messages <- c(
        directional_messages,
        paste0(
          added_anchor,
          " excludes component countries from All Other: ",
          paste(anchor_component_message_values, collapse = ", "),
          "."
        )
      )
    }

    restored_components <- character(0)
    if (length(removed_parents) > 0) {
      country_code_map <- get_myc_country_partner_code_map()
      if (length(country_code_map) > 0) {
        map_df <- tibble::tibble(
          comparison_item = normalize_myc_country_selection_values(names(country_code_map)),
          country_code = trimws(as.character(unname(country_code_map)))
        ) %>%
          filter(!is.na(.data$comparison_item), nzchar(.data$comparison_item), !is.na(.data$country_code), nzchar(.data$country_code))

        if (!is.null(eligible_partners)) {
          map_df <- map_df %>% filter(.data$comparison_item %in% eligible_partners)
        }

        for (parent_name in removed_parents) {
          if (!(parent_name %in% names(items_by_name))) next

          parent_leaf_set <- sort(unique(items_by_name[[parent_name]]$leaf_set %||% character(0)))
          if (length(parent_leaf_set) == 0) next

          parent_components <- map_df %>%
            filter(!startsWith(.data$country_code, CUSTOM_COUNTRY_CHOICE_PREFIX), .data$country_code %in% parent_leaf_set) %>%
            pull(.data$comparison_item)

          restored_components <- c(restored_components, parent_components)
        }

        restored_components <- sort(unique(restored_components[!is.na(restored_components) & nzchar(restored_components)]))
        if (length(restored_components) > 0) {
          restored_message_values <- restored_components
          if (length(restored_message_values) > 8) {
            restored_message_values <- c(
              restored_message_values[seq_len(8)],
              paste0("...and ", length(restored_components) - 8, " more")
            )
          }

          directional_messages <- c(
            directional_messages,
            paste0(
              added_anchor,
              " was added and restored component countries from pruned aggregates to All Other: ",
              paste(restored_message_values, collapse = ", "),
              "."
            )
          )
        }
      }
    }

    if (!is.null(eligible_partners)) {
      eligible_partners <- normalize_myc_country_selection_values(eligible_partners)
      resolved_selection <- resolved_selection[resolved_selection %in% eligible_partners]
    }

    list(
      selection = resolved_selection,
      removed = removed_values,
      removed_components = unique(c(removed_children, exact_removed)),
      removed_aggregates = removed_parents,
      excluded_from_all_other = selected_custom_excluded_components,
      restored_to_all_other = restored_components,
      messages = unique(c(directional_messages, exact_messages)),
      added_anchor = added_anchor,
      exact_overlap_pairs = exact_overlap_pairs
    )
  }

  build_exact_custom_hybrid_signature <- function(selection_name) {
    if (!is_myc_hybrid_type_mode_active()) return(NULL)

    custom_def <- custom_types_enriched() %>%
      filter(.data$parse_ok, .data$custom_name == selection_name)

    if (nrow(custom_def) == 0) return(NULL)

    parsed_def <- custom_def$parsed[[1]]
    if (is.null(parsed_def) || is.null(parsed_def$coefficients)) return(NULL)

    coeffs <- parsed_def$coefficients
    coeffs <- coeffs[abs(coeffs) > 1e-12]
    if (length(coeffs) == 0) return(NULL)
    if (any(abs(coeffs - 1) > 1e-12)) return(NULL)
    native_choices <- unique(active_native_commodities())
    if (!all(names(coeffs) %in% native_choices)) return(NULL)

    leaf_weights <- stats::setNames(rep(0, length(native_hybrid_export_leaf_nodes)), native_hybrid_export_leaf_nodes)
    for (ref_name in names(coeffs)) {
      ref_leaves <- get_myc_native_leaf_set(ref_name)
      if (length(ref_leaves) == 0) return(NULL)
      leaf_weights[ref_leaves] <- leaf_weights[ref_leaves] + coeffs[[ref_name]]
    }

    if (any(abs(leaf_weights - round(leaf_weights)) > 1e-12)) return(NULL)
    if (any(leaf_weights > 1)) return(NULL)

    leaf_set <- sort(names(leaf_weights[leaf_weights > 0]))
    if (length(leaf_set) == 0) return(NULL)

    exact_native_match <- native_choices[vapply(native_choices, function(node_name) {
      identical(sort(get_myc_native_leaf_set(node_name)), leaf_set)
    }, logical(1))]

    family_candidates <- native_hybrid_export_non_root_family_nodes[vapply(native_hybrid_export_non_root_family_nodes, function(node_name) {
      family_leaves <- get_native_hybrid_export_leaf_descendants(node_name)
      all(leaf_set %in% family_leaves)
    }, logical(1))]

    if (length(exact_native_match) > 0) {
      family_parent <- paste(get_native_hybrid_export_family_parents(exact_native_match[[1]]), collapse = "|")
      return(list(
        name = selection_name,
        source = "custom",
        leaf_set = leaf_set,
        family_parent = family_parent,
        exact_native_match = exact_native_match[[1]]
      ))
    }

    if (length(family_candidates) != 1) return(NULL)

    list(
      name = selection_name,
      source = "custom",
      leaf_set = leaf_set,
      family_parent = family_candidates[[1]],
      exact_native_match = NA_character_
    )
  }

  build_myc_hybrid_overlap_items <- function(selection) {
    normalized_selection <- normalize_myc_type_selection_values(selection)
    overlap_items <- vector("list", 0)

    for (selection_name in normalized_selection) {
      if (selection_name %in% native_hybrid_export_nodes) {
        overlap_items[[length(overlap_items) + 1L]] <- list(
          name = selection_name,
          source = "native",
          leaf_set = sort(get_native_hybrid_export_leaf_descendants(selection_name)),
          family_parent = paste(get_native_hybrid_export_family_parents(selection_name), collapse = "|"),
          exact_native_match = selection_name
        )
        next
      }

      custom_signature <- build_exact_custom_hybrid_signature(selection_name)
      if (!is.null(custom_signature)) {
        overlap_items[[length(overlap_items) + 1L]] <- custom_signature
      }
    }

    overlap_items
  }

  detect_exact_hybrid_overlap_pairs <- function(selection) {
    overlap_items <- build_myc_hybrid_overlap_items(selection)
    if (length(overlap_items) < 2) {
      return(data.frame(
        left_name = character(),
        right_name = character(),
        left_source = character(),
        right_source = character(),
        family_parent = character(),
        stringsAsFactors = FALSE
      ))
    }

    overlap_pairs <- list()
    for (left_index in seq_len(length(overlap_items) - 1L)) {
      left_item <- overlap_items[[left_index]]
      for (right_index in seq.int(left_index + 1L, length(overlap_items))) {
        right_item <- overlap_items[[right_index]]
        shared_leaves <- intersect(left_item$leaf_set, right_item$leaf_set)
        is_nested_overlap <- length(shared_leaves) > 0 &&
          (all(left_item$leaf_set %in% right_item$leaf_set) || all(right_item$leaf_set %in% left_item$leaf_set))

        if (!is_nested_overlap) next

        family_parent <- unique(na.omit(c(left_item$family_parent, right_item$family_parent)))
        overlap_pairs[[length(overlap_pairs) + 1L]] <- data.frame(
          left_name = left_item$name,
          right_name = right_item$name,
          left_source = left_item$source,
          right_source = right_item$source,
          family_parent = if (length(family_parent) > 0) family_parent[[1]] else NA_character_,
          stringsAsFactors = FALSE
        )
      }
    }

    if (length(overlap_pairs) == 0) {
      return(data.frame(
        left_name = character(),
        right_name = character(),
        left_source = character(),
        right_source = character(),
        family_parent = character(),
        stringsAsFactors = FALSE
      ))
    }

    bind_rows(overlap_pairs) %>% distinct()
  }

  perform_myc_partner_selection_reset <- function(
    comparison_mode,
    reset_mode = c(
      "legalize_only",
      "default_reseed",
      "preserve_selection_clear_runtime_manual",
      "preserve_legal_current_context",
      "preserve_legal_current_context_topup_defaults",
      "restore_prior_context_manual_if_legal"
    ),
    selection = character(0),
    selection_is_manual = FALSE,
    clear_world_type_memory = FALSE,
    preserve_remembered_state = FALSE
  ) {
    reset_mode <- match.arg(reset_mode)
    normalized_selection <- normalize_myc_partner_values(selection, comparison_mode = comparison_mode)

    myc_transition_trace(
      "perform_myc_partner_selection_reset_enter",
      details = list(
        comparison_mode = comparison_mode,
        reset_mode = reset_mode,
        selection_size = length(normalized_selection),
        selection_is_manual = isTRUE(selection_is_manual),
        clear_world_type_memory = isTRUE(clear_world_type_memory),
        preserve_remembered_state = isTRUE(preserve_remembered_state)
      )
    )

    if (isTRUE(clear_world_type_memory)) {
      reset_world_type_partner_selection_state()
    }

    if (identical(reset_mode, "default_reseed")) {
      invalidate_partner_input_selection(
        force_default = TRUE,
        preserve_remembered_state = preserve_remembered_state,
        top_up_defaults_on_repopulation = FALSE
      )
      reset_market_year_comparison_selection(comparison_mode)
      clear_partner_show_input(preserve_transition_state = TRUE)
      myc_transition_trace("perform_myc_partner_selection_reset_exit", details = list(reset_mode = reset_mode, branch = "default_reseed"))
      return(invisible(NULL))
    }

    if (identical(reset_mode, "preserve_selection_clear_runtime_manual")) {
      if (!isTRUE(selection_is_manual) || length(normalized_selection) == 0) {
        invalidate_partner_input_selection(force_default = TRUE)
        reset_market_year_comparison_selection(comparison_mode)
        clear_partner_show_input(preserve_transition_state = TRUE)
        myc_transition_trace("perform_myc_partner_selection_reset_exit", details = list(reset_mode = reset_mode, branch = "fallback_default_reseed"))
        return(invisible(NULL))
      }

      invalidate_partner_input_selection(
        force_default = FALSE,
        reset_override = normalized_selection,
        reset_override_manual = FALSE,
        preserve_remembered_state = TRUE,
        top_up_defaults_on_repopulation = FALSE
      )
      clear_partner_show_input(preserve_transition_state = TRUE)
      myc_transition_trace("perform_myc_partner_selection_reset_exit", details = list(reset_mode = reset_mode, branch = "preserve_manual_cleared"))
      return(invisible(NULL))
    }

    reset_market_year_comparison_selection(comparison_mode)
    if (
      identical(reset_mode, "preserve_legal_current_context_topup_defaults") &&
      !isTRUE(selection_is_manual)
    ) {
      invalidate_partner_input_selection(
        force_default = TRUE,
        top_up_defaults_on_repopulation = FALSE
      )
    } else if (length(normalized_selection) == 0) {
      invalidate_partner_input_selection(
        force_default = TRUE,
        top_up_defaults_on_repopulation = FALSE
      )
    } else {
      invalidate_partner_input_selection(
        force_default = FALSE,
        reset_override = normalized_selection,
        reset_override_manual = isTRUE(selection_is_manual),
        top_up_defaults_on_repopulation = identical(reset_mode, "preserve_legal_current_context_topup_defaults")
      )
    }

    clear_partner_show_input(preserve_transition_state = TRUE)
    myc_transition_trace("perform_myc_partner_selection_reset_exit", details = list(reset_mode = reset_mode, branch = "generic"))
  }

  observeEvent(input$partner_show, {
    comparison_mode <- market_year_comparison_mode()
    selections <- normalize_myc_partner_values(input$partner_show, comparison_mode = comparison_mode)
    record_partner_share_data_read("partner_show_observer")
    share_data <- tryCatch(partner_share_data(), error = function(e) NULL)
    partner_choices <- if (!is.null(share_data)) unique(normalize_myc_partner_values(share_data$eligible_partners, comparison_mode = share_data$comparison_mode)) else character(0)

    action_choice <- resolve_myc_partner_action_choice(comparison_mode = comparison_mode)
    if (!is.null(action_choice) && action_choice %in% selections) {
      retained_selection <- unique(selections[selections != action_choice])
      if (length(partner_choices) > 0) {
        retained_selection <- unique(retained_selection[retained_selection %in% partner_choices])
      }

      retained_selection <- if (!is.null(share_data)) {
        order_myc_selected_partners_by_market_share(retained_selection, share_data)
      } else {
        retained_selection
      }

      if (!is.null(share_data)) {
        update_remembered_partner_selection_from_visible(
          comparison_mode = share_data$comparison_mode,
          visible_selection = retained_selection,
          eligible_choices = partner_choices,
          selection_is_manual = TRUE
        )
      }

      partner_selection_manual_override(TRUE)
      myc_country_overlap_legalization_messages_state(character(0))

      myc_transition_trace(
        "partner_show_action_sentinel_selected",
        details = list(
          comparison_mode = comparison_mode,
          action_choice = action_choice,
          retained_selection = length(retained_selection)
        )
      )

      update_partner_show_input(
        choices = market_year_partner_show_choices(),
        selected = retained_selection,
        selection_is_manual = TRUE
      )

      if (identical(comparison_mode, "country")) {
        if (exists("show_custom_country_builder_modal", mode = "function")) {
          show_custom_country_builder_modal()
        }
      } else if (identical(comparison_mode, "type")) {
        if (exists("show_custom_builder_modal", mode = "function")) {
          show_custom_builder_modal()
        }
      }

      return()
    }

    current_context_version <- partner_selection_context_version()
    current_input_version <- partner_selection_input_version()
    force_default_active <- isTRUE(partner_selection_force_default())
    prior_manual_override <- isTRUE(isolate(partner_selection_manual_override()))
    legalized_override_selection <- get_partner_selection_legalized_override(comparison_mode)
    pending_programmatic_selection <- isolate(partner_selection_programmatic_selected())
    pending_programmatic_manual <- isTRUE(isolate(partner_selection_programmatic_manual()))
    preserve_remembered_state <- isTRUE(isolate(partner_selection_preserve_remembered_state()))
    has_pending_programmatic_selection <- !is.null(pending_programmatic_selection)
    pending_programmatic_selection <- if (has_pending_programmatic_selection) {
      normalize_myc_partner_values(pending_programmatic_selection, comparison_mode = comparison_mode)
    } else {
      character(0)
    }
    selection_matches_pending_programmatic <-
      has_pending_programmatic_selection && identical(sort(selections), sort(pending_programmatic_selection))

    if (selection_matches_pending_programmatic) {
      partner_selection_programmatic_selected(NULL)
      partner_selection_programmatic_manual(FALSE)
      partner_selection_reset_override(NULL)
      partner_selection_reset_override_manual(NULL)
      partner_selection_preserve_remembered_state(FALSE)
      clear_partner_selection_legalized_override()
    } else if (has_pending_programmatic_selection && length(legalized_override_selection) > 0) {
      myc_transition_trace(
        "partner_show_process_against_pending_legalized_selection",
        details = list(
          comparison_mode = comparison_mode,
          raw_selection_size = length(selections),
          legalized_selection_size = length(legalized_override_selection)
        )
      )

      partner_selection_programmatic_selected(NULL)
      partner_selection_programmatic_manual(FALSE)
      partner_selection_reset_override(NULL)
      partner_selection_reset_override_manual(NULL)
      partner_selection_preserve_remembered_state(FALSE)
    } else if (has_pending_programmatic_selection) {
      partner_selection_programmatic_selected(NULL)
      partner_selection_programmatic_manual(FALSE)
      partner_selection_reset_override(NULL)
      partner_selection_reset_override_manual(NULL)
      partner_selection_preserve_remembered_state(FALSE)
    }

    if (length(legalized_override_selection) > 0) {
      if (!identical(sort(selections), sort(legalized_override_selection))) {
        myc_transition_trace(
          "partner_show_legalize_raw_against_override",
          details = list(
            comparison_mode = comparison_mode,
            raw_selection_size = length(selections),
            legalized_selection_size = length(legalized_override_selection)
          )
        )
      } else {
        clear_partner_selection_legalized_override()
      }
    }

    legal_default_selection <- if (!is.null(share_data) && length(partner_choices) > 0) {
      unique(share_data$default_sel[share_data$default_sel %in% partner_choices])
    } else {
      character(0)
    }
    legal_selections <- if (length(partner_choices) > 0) {
      unique(selections[selections %in% partner_choices])
    } else {
      selections
    }
    pre_legalization_selections <- legal_selections

    if (!isTRUE(selection_matches_pending_programmatic) && !is.null(share_data) && identical(share_data$comparison_mode, "country")) {
      remembered_state_before <- get_remembered_partner_selection_state("country")
      previous_selection_for_legalization <- if (length(legalized_override_selection) > 0) {
        legalized_override_selection
      } else {
        remembered_state_before$selection
      }
      legalization_result <- legalize_myc_country_partner_selection(
        selection = legal_selections,
        previous_selection = previous_selection_for_legalization,
        eligible_partners = partner_choices
      )

      legal_selections <- legalization_result$selection
      myc_country_overlap_legalization_messages_state(legalization_result$messages)

      if (length(legalization_result$removed) > 0) {
        myc_transition_trace(
          "myc_country_overlap_legalization",
          details = list(
            removed_count = length(legalization_result$removed),
            removed_values = paste(sort(unique(legalization_result$removed)), collapse = "|"),
            anchor = legalization_result$added_anchor,
            exact_overlap_pairs = nrow(legalization_result$exact_overlap_pairs),
            message_count = length(legalization_result$messages)
          )
        )
      }
    } else if (is.null(share_data) || !identical(share_data$comparison_mode %||% "", "country")) {
      myc_country_overlap_legalization_messages_state(character(0))
    }

    selection_changed_by_legalization <- !identical(pre_legalization_selections, legal_selections)

    ordered_legal_selections <- if (!is.null(share_data)) {
      order_myc_selected_partners_by_market_share(legal_selections, share_data)
    } else {
      legal_selections
    }
    selection_matches_default_reseed <- identical(sort(legal_selections), sort(legal_default_selection))

    selection_is_manual <- if (selection_matches_pending_programmatic) {
      pending_programmatic_manual
    } else if (selection_matches_default_reseed && !isTRUE(prior_manual_override)) {
      FALSE
    } else {
      TRUE
    }

    if (!isTRUE(selection_matches_pending_programmatic) && isTRUE(selection_changed_by_legalization)) {
      selection_is_manual <- TRUE
    }

    if (isTRUE(force_default_active)) {
      if (length(legal_selections) == 0) {
        partner_selection_input_version(-1L)
        return()
      }

      if (!identical(current_input_version, current_context_version)) {
        myc_transition_trace(
          "partner_show_ignore_stale_force_default",
          details = list(
            selection_size = length(legal_selections),
            selection_matches_pending_programmatic = isTRUE(selection_matches_pending_programmatic),
            selection_matches_default_reseed = isTRUE(selection_matches_default_reseed)
          )
        )
        partner_selection_input_version(-1L)
        return()
      }

      partner_selection_force_default(FALSE)
      if (selection_matches_pending_programmatic || selection_matches_default_reseed) {
        selection_is_manual <- FALSE
      }
    }

    partner_selection_input_version(partner_selection_context_version())
    partner_selection_manual_override(selection_is_manual)
    current_basis_signature <- build_myc_partner_basis_signature(share_data)
    if (!is.null(current_basis_signature) && nzchar(current_basis_signature)) {
      partner_selection_basis_signature(current_basis_signature)
      partner_selection_basis_signature_manual(isTRUE(selection_is_manual))
    }

    if (isTRUE(selection_is_manual)) {
      myc_native_reset_excluded_partners(character(0))
      partner_selection_reset_override(NULL)
    }

    if (selection_matches_pending_programmatic) {
      if (!isTRUE(pending_programmatic_manual) && !isTRUE(preserve_remembered_state)) {
        set_remembered_partner_selection_state(
          comparison_mode = comparison_mode,
          selection = ordered_legal_selections,
          selection_is_manual = FALSE
        )
      }
      return()
    }

    if (isTRUE(selection_changed_by_legalization)) {
      set_partner_selection_legalized_override(
        comparison_mode = comparison_mode,
        selection = ordered_legal_selections
      )
      update_remembered_partner_selection_from_visible(
        comparison_mode = comparison_mode,
        visible_selection = ordered_legal_selections,
        eligible_choices = partner_choices,
        selection_is_manual = TRUE
      )
      update_partner_show_input(
        choices = remove_myc_partner_choices(
          market_year_partner_show_choices(),
          legalization_result$removed,
          comparison_mode = comparison_mode
        ),
        selected = ordered_legal_selections,
        selection_is_manual = TRUE
      )
      force_partner_show_visible_selection(
        ordered_legal_selections,
        reason = "myc_country_overlap_legalization",
        delay_ms = 40L
      )
      return()
    }

    if (isTRUE(selection_is_manual)) {
      if (isTRUE(selection_changed_by_legalization) || !identical(legal_selections, ordered_legal_selections)) {
        if (!identical(legal_selections, ordered_legal_selections)) {
          set_partner_selection_legalized_override(
            comparison_mode = comparison_mode,
            selection = ordered_legal_selections
          )
        }
        update_remembered_partner_selection_from_visible(
          comparison_mode = comparison_mode,
          visible_selection = ordered_legal_selections,
          eligible_choices = partner_choices,
          selection_is_manual = TRUE
        )
        update_partner_show_input(
          choices = market_year_partner_show_choices(),
          selected = ordered_legal_selections,
          selection_is_manual = TRUE
        )
        return()
      }

      update_remembered_partner_selection_from_visible(
        comparison_mode = comparison_mode,
        visible_selection = ordered_legal_selections,
        eligible_choices = partner_choices,
        selection_is_manual = TRUE
      )
      if (identical(sort(selections), sort(ordered_legal_selections))) {
        clear_partner_selection_legalized_override()
      }
      return()
    }

    remembered_state <- get_remembered_partner_selection_state(comparison_mode)
    if (!isTRUE(remembered_state$selection_is_manual) && length(remembered_state$selection) == 0) {
      set_remembered_partner_selection_state(
        comparison_mode = comparison_mode,
        selection = ordered_legal_selections,
        selection_is_manual = FALSE
      )
    }
  }, ignoreInit = TRUE)

  observeEvent(input$market_year_compare_mode, {
    if (!identical(input$main_tabs_panel, "Market Year Comparison Tool")) return()

    capture_myc_sidebar_entry_context("market_year_compare_mode")
    restore_myc_sidebar_transition_context("market_year_compare_mode", leaving_myc = FALSE)

    begin_myc_transition_action("market_year_compare_mode")
    myc_transition_trace(
      "mode_switch_observer_enter",
      details = list(
        selected_mode = input$market_year_compare_mode,
        country = isolate(input$country_choice),
        commodity = isolate(input$commodity_choice)
      )
    )

    comparison_mode <- market_year_comparison_mode()
    reset_world_type_partner_selection_state()

    if (identical(comparison_mode, "type")) {
      perform_myc_partner_selection_reset(
        "type",
        reset_mode = "default_reseed",
        clear_world_type_memory = TRUE,
        preserve_remembered_state = TRUE
      )
      return()
    }

    perform_myc_partner_selection_reset(
      "country",
      reset_mode = "default_reseed",
      clear_world_type_memory = TRUE
    )
  }, ignoreInit = TRUE, priority = 100)

  observeEvent(list(input$main_tabs_panel, input$market_year_compare_mode, input$country_choice), {
    if (!identical(input$main_tabs_panel, "Market Year Comparison Tool")) return()
    if (!identical(market_year_comparison_mode(), "type")) return()
    if (isTRUE(myc_country_analysis_default_applied())) return()

    if (identical(input$country_choice, "GRAND_TOTAL")) {
      myc_country_analysis_default_applied(TRUE)
    }
  }, ignoreInit = TRUE, priority = 110)

  observeEvent(input$myc_order_by_latest_market_year, {
    if (!identical(input$main_tabs_panel, "Market Year Comparison Tool")) return()

    current_state <- capture_active_myc_partner_selection_state(market_year_comparison_mode())
    perform_myc_partner_selection_reset(
      market_year_comparison_mode(),
      reset_mode = "preserve_selection_clear_runtime_manual",
      selection = current_state$selection,
      selection_is_manual = current_state$selection_is_manual
    )
  }, ignoreInit = TRUE, priority = 100)

  observeEvent(input$commodity_choice, {
    if (!identical(input$main_tabs_panel, "Market Year Comparison Tool")) return()

    comparison_mode <- market_year_comparison_mode()
    if (!(comparison_mode %in% c("country", "type"))) return()

    if (isTRUE(partner_selection_programmatic_all_rice_reset())) {
      if (identical(input$commodity_choice, default_commodity_choice_value())) {
        partner_selection_programmatic_all_rice_reset(FALSE)
      }
      return()
    }

    if (identical(comparison_mode, "type")) {
      valid_commodity_choices <- tryCatch(commodity_choice_fallback_values(), error = function(e) character(0))
      valid_commodity_values <- unique(unname(valid_commodity_choices))
      current_commodity <- scalar_myc_sidebar_value(input$commodity_choice)
      current_commodity_valid <- !is.null(current_commodity) && current_commodity %in% valid_commodity_values

      if (!isTRUE(current_commodity_valid)) {
        myc_transition_trace(
          "commodity_choice_observer_waiting_for_type_fallback",
          details = list(
            commodity = current_commodity %||% "<null>",
            valid_choices = length(valid_commodity_values),
            valid_choice_sample = paste(head(valid_commodity_values, 5L), collapse = " | ")
          )
        )
        return()
      }

      if (isTRUE(is_myc_automatic_commodity_value(current_commodity))) {
        myc_transition_trace(
          "commodity_choice_observer_skip_automatic_type_fallback",
          details = list(commodity = current_commodity)
        )
        return()
      }
    }

    current_state <- capture_active_myc_partner_selection_state(comparison_mode)
    perform_myc_partner_selection_reset(
      comparison_mode,
      reset_mode = if (isTRUE(current_state$selection_is_manual)) {
        "preserve_selection_clear_runtime_manual"
      } else {
        "default_reseed"
      },
      selection = current_state$selection,
      selection_is_manual = current_state$selection_is_manual
    )
  }, ignoreInit = TRUE, priority = 100)

  observeEvent(input$vp_commodity_name_choice, {
    if (!identical(input$main_tabs_panel, "Market Year Comparison Tool")) return()
    if (!identical(current_source_choice_safe(default = input$data_source_choice %||% "export_sales"), "vp_trade")) return()

    comparison_mode <- market_year_comparison_mode()
    if (!(comparison_mode %in% c("country", "type"))) return()

    if (identical(comparison_mode, "type")) {
      valid_commodity_choices <- tryCatch(commodity_choice_fallback_values(), error = function(e) character(0))
      valid_commodity_values <- unique(unname(valid_commodity_choices))
      current_commodity <- scalar_myc_sidebar_value(input$commodity_choice)
      current_commodity_valid <- !is.null(current_commodity) && current_commodity %in% valid_commodity_values

      if (!isTRUE(current_commodity_valid)) {
        myc_transition_trace(
          "vp_commodity_name_observer_waiting_for_type_fallback",
          details = list(
            vp_commodity_name = input$vp_commodity_name_choice,
            commodity = current_commodity %||% "<null>",
            valid_choices = length(valid_commodity_values),
            valid_choice_sample = paste(head(valid_commodity_values, 5L), collapse = " | ")
          )
        )
        return()
      }

      if (isTRUE(is_myc_automatic_commodity_value(current_commodity))) {
        myc_transition_trace(
          "vp_commodity_name_observer_skip_automatic_type_fallback",
          details = list(
            vp_commodity_name = input$vp_commodity_name_choice,
            commodity = current_commodity
          )
        )
        return()
      }
    }

    current_state <- capture_active_myc_partner_selection_state(comparison_mode)
    perform_myc_partner_selection_reset(
      comparison_mode,
      reset_mode = if (isTRUE(current_state$selection_is_manual)) {
        "preserve_selection_clear_runtime_manual"
      } else {
        "default_reseed"
      },
      selection = current_state$selection,
      selection_is_manual = current_state$selection_is_manual
    )
  }, ignoreInit = TRUE, priority = 100)

  observeEvent(input$country_choice, {
    if (!identical(input$main_tabs_panel, "Market Year Comparison Tool")) return()
    if (!identical(market_year_comparison_mode(), "type")) return()

    myc_transition_trace(
      "type_country_observer_enter",
      details = list(
        country = input$country_choice,
        programmatic_world_reset = isTRUE(partner_selection_programmatic_world_reset())
      )
    )

    if (isTRUE(partner_selection_programmatic_world_reset())) {
      if (identical(input$country_choice, "GRAND_TOTAL")) {
        partner_selection_programmatic_world_reset(FALSE)
        mark_myc_transition_mutation(
          "clear_programmatic_world_reset",
          details = list(reason = "country_choice_reached_grand_total")
        )
      }
      return()
    }

    if (identical(input$country_choice, "GRAND_TOTAL")) {
      world_type_state <- get_world_type_partner_selection_state()
      perform_myc_partner_selection_reset(
        "type",
        reset_mode = "restore_prior_context_manual_if_legal",
        selection = world_type_state$selection,
        selection_is_manual = world_type_state$selection_is_manual
      )
      return()
    }

    current_state <- capture_active_myc_partner_selection_state("type")
    perform_myc_partner_selection_reset(
      "type",
      reset_mode = "preserve_legal_current_context_topup_defaults",
      selection = current_state$selection,
      selection_is_manual = current_state$selection_is_manual
    )
  }, ignoreInit = TRUE, priority = 100)

  observeEvent(list(input$data_source_choice, input$census_trade_flow_choice, input$hybrid_trade_flow_choice, input$vp_trade_flow_choice), {
    if (!identical(input$main_tabs_panel, "Market Year Comparison Tool")) return()

    source_choice <- if (!is.null(input$data_source_choice)) input$data_source_choice else "export_sales"
    comparison_mode <- market_year_comparison_mode()
    if (!(source_choice %in% c("census", "hybrid", "vp_trade"))) return()
    if (!(comparison_mode %in% c("country", "type"))) return()

    current_state <- capture_active_myc_partner_selection_state(comparison_mode)
    reset_mode <- if (isTRUE(current_state$selection_is_manual)) {
      "preserve_selection_clear_runtime_manual"
    } else {
      "default_reseed"
    }

    perform_myc_partner_selection_reset(
      comparison_mode,
      reset_mode = reset_mode,
      selection = current_state$selection,
      selection_is_manual = current_state$selection_is_manual
    )
  }, ignoreInit = TRUE, priority = 100)

  latest_available_snapshot_by_group <- function(df, group_col, cutoff_period = NULL) {
    if (is.null(df) || nrow(df) == 0) return(df)

    snapshot_df <- df
    if (!is.null(cutoff_period) && is.finite(cutoff_period)) {
      snapshot_df <- snapshot_df %>% filter(.data$analysis_month <= cutoff_period)
    }

    if (nrow(snapshot_df) == 0) return(snapshot_df)

    snapshot_df %>%
      mutate(snapshot_group = .data[[group_col]]) %>%
      group_by(.data$market_year, .data$snapshot_group) %>%
      filter({
        valid_periods <- .data$analysis_month[!is.na(.data$analysis_month)]
        if (length(valid_periods) > 0) {
          .data$analysis_month == max(valid_periods)
        } else {
          FALSE
        }
      }) %>%
      ungroup() %>%
        select(-snapshot_group)
  }

  enforce_vp_rollup_precedence <- function(df) {
    if (!is.data.frame(df) || nrow(df) == 0 || !("vp_is_rollup" %in% names(df))) {
      return(df)
    }

    key_cols <- intersect(
      c("Trade", "Group", "Subgroup", "MarketSegment", "CommodityName", "commodity", "country", "market_year", "analysis_month"),
      names(df)
    )
    if (length(key_cols) == 0) {
      return(df)
    }

    df %>%
      mutate(.vp_rollup_flag = !is.na(.data$vp_is_rollup) & as.logical(.data$vp_is_rollup)) %>%
      group_by(across(all_of(key_cols))) %>%
      filter(if (any(.data$.vp_rollup_flag, na.rm = TRUE)) .data$.vp_rollup_flag else TRUE) %>%
      ungroup() %>%
      select(-.vp_rollup_flag)
  }

  # Shared snapshot for Market Year Comparison Tool (latest period per MY, current metric)
  partner_snapshot <- reactive({
    record_cache_body_execution(session, "selected_data_read_partner_snapshot")
    df_all <- selected_data()
    if (is.null(df_all)) return(NULL)

    source_choice <- current_source_choice_safe()
    comparison_mode <- market_year_comparison_mode()

    df <- df_all

    if (identical(source_choice, "census")) {
      df <- df %>%
        mutate(
          countryDescription = dplyr::if_else(
            .data$country == "GRAND_TOTAL",
            "World",
            stringr::str_to_title(tolower(.data$countryDescription))
          )
        )
    }

    if (identical(comparison_mode, "type")) {
      selected_country <- input$country_choice
      if (is.null(selected_country) || !nzchar(selected_country)) return(NULL)

      # Backward-compatible resolver: tolerate persisted custom-country display values.
      if (!is_custom_country_choice_value(selected_country)) {
        custom_country_values <- unique(as.character(df$country[startsWith(as.character(df$country), CUSTOM_COUNTRY_CHOICE_PREFIX)]))
        if (length(custom_country_values) > 0) {
          custom_country_names <- vapply(custom_country_values, function(choice_value) {
            parsed_name <- parse_custom_country_choice_name(choice_value)
            if (is.null(parsed_name)) "" else tolower(trimws(as.character(parsed_name)))
          }, character(1))
          selected_country_key <- tolower(trimws(as.character(selected_country)))
          matched_idx <- which(custom_country_names == selected_country_key)
          if (length(matched_idx) > 0) {
            selected_country <- custom_country_values[[matched_idx[[1L]]]]
          }
        }
      }

      df <- df %>%
        filter(.data$country == selected_country) %>%
        mutate(
          comparison_item = vapply(
            .data$commodity,
            function(commodity_name) get_commodity_display_label(commodity_name, input$basis_choice),
            character(1)
          )
        ) %>%
        filter(!is_all_rice_display_label(.data$comparison_item))
    } else {
      df <- df %>%
        filter(.data$commodity == input$commodity_choice) %>%
        filter(!.data$country %in% c("GRAND_TOTAL", "Grand Total"))

      if (exists("build_custom_country_filtered_data", mode = "function")) {
        custom_defs <- tryCatch(custom_countries_enriched(), error = function(e) data.frame())
        custom_defs_tbl <- as_tibble(custom_defs %||% data.frame()) %>%
          filter(.data$parse_ok) %>%
          transmute(custom_name = trimws(as.character(.data$custom_name))) %>%
          filter(!is.na(.data$custom_name), nzchar(.data$custom_name)) %>%
          mutate(custom_name_key = tolower(.data$custom_name)) %>%
          arrange(.data$custom_name_key, .data$custom_name) %>%
          distinct(.data$custom_name_key, .keep_all = TRUE)

        if (nrow(custom_defs_tbl) > 0) {
          df_native <- df %>%
            filter(!startsWith(as.character(.data$country), CUSTOM_COUNTRY_CHOICE_PREFIX))

          custom_frames <- lapply(custom_defs_tbl$custom_name, function(custom_name) {
            choice_value <- build_custom_country_choice_value(custom_name)
            tryCatch(
              build_custom_country_filtered_data(
                source_df = df_native,
                custom_choice_value = choice_value,
                custom_country_defs = custom_defs
              ),
              error = function(e) data.frame()
            )
          })

          custom_frames <- Filter(function(frame) is.data.frame(frame) && nrow(frame) > 0, custom_frames)
          if (length(custom_frames) > 0) {
            df <- bind_rows(df_native, bind_rows(custom_frames))
          }
        }
      }

      df <- df %>%
        mutate(
          comparison_item = normalize_myc_country_display_label(
            .data$country,
            .data$countryDescription,
            source_choice = source_choice
          )
        )
    }

    df <- enforce_vp_rollup_precedence(df)

    if (nrow(df) == 0) return(NULL)

    snapshot_base <- build_snapshot_base(
      df = df,
      group_col = "comparison_item",
      state_value = myc_cutoff_state()
    )
    if (is.null(snapshot_base)) return(NULL)

    focus_label <- if (identical(comparison_mode, "type")) {
      if (identical(input$country_choice, "GRAND_TOTAL")) "World" else get_display_country(input$country_choice)
    } else {
      get_commodity_display_label(input$commodity_choice, input$basis_choice)
    }

    list(
      df = snapshot_base$snapshot_df,
      current_my = snapshot_base$current_my,
      latest_period_index = snapshot_base$latest_period_index,
      period_choices = snapshot_base$period_choices,
      cutoff_state = snapshot_base$cutoff_state,
      comparison_mode = comparison_mode,
      category_label = if (identical(comparison_mode, "type")) COMMODITY_TYPE_LABEL else "Country",
      focus_label = focus_label
    )
  })

  resolve_market_year_partner_basis_state <- function(
    df,
    current_my,
    comparison_basis_years,
    partner_choices,
    prefer_latest_market_year = FALSE,
    min_share_pct = market_year_auto_collapse_share_threshold
  ) {
    partner_choices <- unique(partner_choices)
    if (length(partner_choices) == 0) {
      return(list(
        order_basis = "fallback",
        basis_data = data.frame(
          comparison_item = character(),
          basis_plot_value = numeric(),
          basis_share_pct = numeric(),
          stringsAsFactors = FALSE
        ),
        threshold_partners = character(0),
        fallback_partners = character(0),
        auto_display_partners = character(0),
        default_partners = character(0),
        ranked_partners = character(0)
      ))
    }

    build_basis_summary <- function(target_years) {
      if (length(target_years) == 0) {
        return(data.frame(
          comparison_item = partner_choices,
          basis_plot_value = 0,
          basis_share_pct = 0,
          stringsAsFactors = FALSE
        ))
      }

      yearly_partner_data <- df %>%
        filter(.data$market_year %in% target_years, .data$comparison_item %in% partner_choices) %>%
        group_by(.data$market_year, .data$comparison_item) %>%
        summarise(plot_value = sum(.data$plot_metric, na.rm = TRUE), .groups = "drop")

      year_totals <- df %>%
        filter(.data$market_year %in% target_years) %>%
        group_by(.data$market_year) %>%
        summarise(year_total = sum(.data$plot_metric, na.rm = TRUE), .groups = "drop")

      basis_grid <- expand.grid(
        market_year = target_years,
        comparison_item = partner_choices,
        stringsAsFactors = FALSE
      )

      basis_grid %>%
        left_join(yearly_partner_data, by = c("market_year", "comparison_item")) %>%
        left_join(year_totals, by = "market_year") %>%
        mutate(
          plot_value = ifelse(is.na(.data$plot_value), 0, .data$plot_value),
          year_total = ifelse(is.na(.data$year_total), 0, .data$year_total),
          share_pct = ifelse(.data$year_total > 0, .data$plot_value / .data$year_total, 0)
        ) %>%
        group_by(.data$comparison_item) %>%
        summarise(
          basis_plot_value = mean(.data$plot_value, na.rm = TRUE),
          basis_share_pct = mean(.data$share_pct, na.rm = TRUE),
          .groups = "drop"
        ) %>%
        arrange(dplyr::desc(.data$basis_plot_value), .data$comparison_item)
    }

    latest_basis_data <- build_basis_summary(current_my)
    comparison_basis_data <- build_basis_summary(comparison_basis_years)

    latest_has_signal <- nrow(latest_basis_data) > 0 && any(latest_basis_data$basis_plot_value > 0, na.rm = TRUE)
    comparison_has_signal <- nrow(comparison_basis_data) > 0 && any(comparison_basis_data$basis_plot_value > 0, na.rm = TRUE)

    if (!prefer_latest_market_year && comparison_has_signal) {
      basis_data <- comparison_basis_data
      order_basis <- "historical_avg"
    } else if (latest_has_signal) {
      basis_data <- latest_basis_data
      order_basis <- "current_my"
    } else if (comparison_has_signal) {
      basis_data <- comparison_basis_data
      order_basis <- "historical_avg"
    } else {
      basis_data <- latest_basis_data
      order_basis <- "fallback"
    }

    ranked_partners <- basis_data %>%
      arrange(dplyr::desc(.data$basis_plot_value), .data$comparison_item) %>%
      pull(.data$comparison_item)

    threshold_partners <- basis_data %>%
      filter(.data$basis_share_pct >= min_share_pct) %>%
      arrange(dplyr::desc(.data$basis_plot_value), .data$comparison_item) %>%
      pull(.data$comparison_item)

    fallback_partners <- if (length(threshold_partners) == 0 && length(ranked_partners) > 0) {
      ranked_partners[[1]]
    } else {
      character(0)
    }

    auto_display_partners <- unique(c(threshold_partners, fallback_partners))
    default_partners <- head(auto_display_partners, 5)

    list(
      order_basis = order_basis,
      basis_data = basis_data,
      threshold_partners = threshold_partners,
      fallback_partners = fallback_partners,
      auto_display_partners = auto_display_partners,
      default_partners = default_partners,
      ranked_partners = ranked_partners
    )
  }

  build_myc_comparison_basis_bundle <- function(numeric_years, current_my, source_choice = current_source_choice_safe()) {
    year_choices <- normalize_comparison_year_choices(numeric_years)
    comparison_state <- read_comparison_state_bundle_safe(
      surface = "standard",
      source_choice = source_choice,
      year_choices = year_choices,
      hist_years_override = comparison_hist_years_committed()
    )

    historical_years <- historical_years_for_window(
      year_choices,
      current_my,
      comparison_state$hist_years
    )

    reference_year <- suppressWarnings(as.numeric(comparison_state$reference_year))
    has_reference_year <- length(reference_year) == 1L && is.finite(reference_year) && reference_year %in% year_choices
    comparison_basis_years <- if (identical(comparison_state$basis_mode, "single_year") && isTRUE(has_reference_year)) {
      reference_year
    } else {
      historical_years
    }

    display_year_label <- function(year_value) {
      year_value <- suppressWarnings(as.numeric(year_value))
      if (length(year_value) != 1L || !is.finite(year_value)) {
        return(NA_character_)
      }
      build_display_year_label(year_value, source_choice = source_choice)
    }

    reference_year_label <- if (isTRUE(has_reference_year)) display_year_label(reference_year) else NA_character_
    comparison_baseline_label <- if (identical(comparison_state$basis_mode, "single_year") && isTRUE(has_reference_year) && !is.na(reference_year_label)) {
      paste0("Reference ", reference_year_label)
    } else {
      "Historical Avg"
    }

    list(
      comparison_basis_mode = comparison_state$basis_mode,
      comparison_reference_year = if (isTRUE(has_reference_year)) reference_year else NA_real_,
      comparison_reference_year_label = reference_year_label,
      historical_years = historical_years,
      comparison_basis_years = sort(unique(comparison_basis_years[is.finite(comparison_basis_years)])),
      comparison_baseline_label = comparison_baseline_label,
      comparison_hist_years = comparison_state$hist_years
    )
  }

  partner_share_data_null_reason <- reactiveVal(NULL)

  partner_share_data <- reactive({
    start_time <- Sys.time()
    partner_share_data_null_reason(NULL)
    snap <- partner_snapshot()
    source_choice <- current_source_choice_safe()
    record_cache_body_execution(
      session,
      "partner_share_data",
      details = list(
        source = source_choice,
        comparison_mode = if (!is.null(snap)) snap$comparison_mode else "missing"
      )
    )
    if (is.null(snap)) {
      partner_share_data_null_reason("no_snapshot")
      log_perf(
        "partner_share_data()",
        start_time,
        details = list(
          status = "no_snapshot",
          source = source_choice
        )
      )
      return(NULL)
    }

    metric_col <- effective_main_metric()
    # Allow any available metric; bail only if the current metric column does not exist
    if (!(metric_col %in% names(snap$df))) {
      partner_share_data_null_reason("metric_missing")
      log_perf(
        "partner_share_data()",
        start_time,
        details = list(
          status = "metric_missing",
          source = source_choice,
          comparison_mode = snap$comparison_mode,
          metric = metric_col,
          rows = nrow(snap$df)
        )
      )
      return(NULL)
    }

    df <- snap$df %>%
      mutate(plot_metric = .data[[metric_col]]) %>%
      filter(!is.na(.data$plot_metric), .data$plot_metric > 0)

    if (nrow(df) == 0) {
      partner_share_data_null_reason("empty_metric")
      log_perf(
        "partner_share_data()",
        start_time,
        details = list(
          status = "empty_metric",
          source = source_choice,
          comparison_mode = snap$comparison_mode,
          metric = metric_col,
          rows = 0L
        )
      )
      return(NULL)
    }

    current_my <- snap$current_my
    numeric_years <- sort(unique(df$market_year))
    comparison_basis_dependency <- list(
      input$projection_basis_mode,
      input$projection_reference_year,
      comparison_hist_years_committed()
    )
    invisible(comparison_basis_dependency)
    comparison_basis <- build_myc_comparison_basis_bundle(numeric_years, current_my)
    hist_years_vec <- comparison_basis$historical_years
    comparison_basis_years <- comparison_basis$comparison_basis_years
    displayed_years <- unique(c(current_my, comparison_basis_years))

    df <- df %>%
      filter(.data$market_year %in% displayed_years)

    # Allow any partner that appears in the filtered snapshot so users can manually add low-share items.
    eligible_partners <- df %>%
      group_by(.data$comparison_item) %>%
      summarise(has_data = any(!is.na(.data$plot_metric) & .data$plot_metric > 0, na.rm = TRUE), .groups = "drop") %>%
      filter(.data$has_data) %>%
      dplyr::pull(.data$comparison_item)

    eligible_partners <- sort(unique(eligible_partners))

    custom_partner_values <- if (identical(snap$comparison_mode, "country")) {
      normalize_myc_country_selection_values(myc_custom_country_display_values(source_choice = current_source_choice_safe()))
    } else if (identical(snap$comparison_mode, "type")) {
      custom_type_defs <- tryCatch(custom_types_enriched(), error = function(e) data.frame())
      custom_type_names <- as_tibble(custom_type_defs %||% data.frame()) %>%
        filter(.data$parse_ok) %>%
        transmute(custom_name = trimws(as.character(.data$custom_name))) %>%
        filter(!is.na(.data$custom_name), nzchar(.data$custom_name)) %>%
        pull(.data$custom_name)

      normalize_myc_type_selection_values(custom_type_names)
    } else {
      character(0)
    }
    custom_partner_values <- unique(custom_partner_values[custom_partner_values %in% eligible_partners])

    if (identical(snap$comparison_mode, "country")) {
      custom_country_values <- myc_custom_country_display_values(source_choice = current_source_choice_safe())
      if (length(custom_country_values) > 0) {
        eligible_partners <- sort(unique(c(eligible_partners, custom_country_values)))
      }
    }

    default_basis_partner_choices <- setdiff(eligible_partners, custom_partner_values)
    if (identical(snap$comparison_mode, "type")) {
      native_default_partner_choices <- get_myc_native_default_partner_choices(eligible_partners)
      if (length(native_default_partner_choices) > 0) {
        default_basis_partner_choices <- setdiff(native_default_partner_choices, custom_partner_values)
      }
    }

    legalized_override_selection <- get_partner_selection_legalized_override(snap$comparison_mode)
    pending_programmatic_selection <- isolate(partner_selection_programmatic_selected())
    pending_programmatic_manual <- isTRUE(isolate(partner_selection_programmatic_manual()))
    input_selected <- if (length(legalized_override_selection) > 0) {
      legalized_override_selection
    } else if (!is.null(pending_programmatic_selection) && isTRUE(pending_programmatic_manual)) {
      normalize_myc_partner_values(pending_programmatic_selection, comparison_mode = snap$comparison_mode)
    } else {
      normalize_myc_partner_values(input$partner_show, comparison_mode = snap$comparison_mode)
    }
    legal_manual_input_selection <- character(0)
    if (identical(partner_selection_input_version(), partner_selection_context_version()) && isTRUE(partner_selection_manual_override())) {
      legal_manual_input_selection <- unique(input_selected[input_selected %in% eligible_partners])
    }

    remembered_state_for_legalization <- get_remembered_partner_selection_state(snap$comparison_mode)
    remembered_manual_selection <- get_remembered_partner_selection(
      comparison_mode = snap$comparison_mode,
      eligible_choices = eligible_partners,
      manual_only = TRUE
    )

    explicit_selection <- unique(c(legal_manual_input_selection, remembered_manual_selection))
    if (identical(snap$comparison_mode, "country") && length(explicit_selection) > 0) {
      explicit_selection <- legalize_myc_country_partner_selection(
        selection = explicit_selection,
        previous_selection = remembered_state_for_legalization$selection,
        eligible_partners = eligible_partners
      )$selection
    }
    explicit_custom_selection <- unique(explicit_selection[explicit_selection %in% custom_partner_values])

    contributor_partners <- unique(c(
      setdiff(eligible_partners, custom_partner_values),
      explicit_custom_selection
    ))

    contributor_totals <- df %>%
      filter(.data$comparison_item %in% contributor_partners) %>%
      group_by(.data$market_year) %>%
      summarise(
        year_total = (sum(.data$plot_metric, na.rm = TRUE) * (NA_real_ ^ (sum(!is.na(.data$plot_metric)) == 0))),
        .groups = "drop"
      )

    df <- df %>%
      left_join(contributor_totals, by = "market_year") %>%
      mutate(
        share_pct = ifelse(.data$year_total > 0, .data$plot_metric / .data$year_total, NA_real_)
      )

    basis_state <- resolve_market_year_partner_basis_state(
      df = df,
      current_my = current_my,
      comparison_basis_years = comparison_basis_years,
      partner_choices = default_basis_partner_choices,
      prefer_latest_market_year = isTRUE(input$myc_order_by_latest_market_year)
    )

    hybrid_default_state <- resolve_hybrid_native_default_partner_state(
      eligible_partners = eligible_partners,
      basis_state = basis_state
    )
    default_sel <- hybrid_default_state$default_partners
    auto_display_partners <- hybrid_default_state$auto_display_partners
    default_excluded_partners <- hybrid_default_state$excluded_partners

    partner_share_data_null_reason(NULL)

    log_perf(
      "partner_share_data()",
      start_time,
      details = list(
        status = "ok",
        source = source_choice,
        comparison_mode = snap$comparison_mode,
        metric = metric_col,
        rows = nrow(df),
        eligible_partners = length(eligible_partners),
        default_basis_partners = length(default_basis_partner_choices),
        contributor_partners_count = length(contributor_partners),
        custom_contributor_count = length(explicit_custom_selection),
        default_selection = length(default_sel),
        auto_display_partners = length(auto_display_partners),
        default_excluded_partners = length(default_excluded_partners),
          displayed_years = length(displayed_years),
          comparison_basis_mode = comparison_basis$comparison_basis_mode,
          comparison_basis_years = length(comparison_basis_years)
      )
    )

    list(
      df = df,
      eligible_partners = eligible_partners,
      default_basis_partners = default_basis_partner_choices,
      contributor_partners = contributor_partners,
      custom_partner_values = custom_partner_values,
      explicit_custom_selection = explicit_custom_selection,
      default_sel = default_sel,
      auto_display_partners = auto_display_partners,
      default_excluded_partners = default_excluded_partners,
      basis_state = basis_state,
      current_my = current_my,
      latest_period_index = snap$latest_period_index,
      metric_col = metric_col,
      displayed_years = displayed_years,
      hist_years = hist_years_vec,
      comparison_basis = comparison_basis,
      comparison_basis_mode = comparison_basis$comparison_basis_mode,
      comparison_reference_year = comparison_basis$comparison_reference_year,
      comparison_reference_year_label = comparison_basis$comparison_reference_year_label,
      comparison_basis_years = comparison_basis_years,
      comparison_baseline_label = comparison_basis$comparison_baseline_label,
      comparison_mode = snap$comparison_mode,
      category_label = snap$category_label,
      focus_label = snap$focus_label
    )
  })

  market_year_partner_basis_state <- reactive({
    record_partner_share_data_read("market_year_partner_basis_state")
    share_data <- partner_share_data()
    if (is.null(share_data)) return(NULL)

    share_data$basis_state
  })

  market_year_manual_partner_selection <- reactive({
    record_partner_share_data_read("market_year_manual_partner_selection")
    share_data <- partner_share_data()
    if (is.null(share_data)) return(character(0))

    partner_choices <- unique(share_data$eligible_partners)
    if (length(partner_choices) == 0) return(character(0))

    legalized_override_selection <- get_partner_selection_legalized_override(share_data$comparison_mode)
    pending_programmatic_selection <- isolate(partner_selection_programmatic_selected())
    pending_programmatic_manual <- isTRUE(isolate(partner_selection_programmatic_manual()))
    input_selected <- if (length(legalized_override_selection) > 0) {
      legalized_override_selection
    } else if (!is.null(pending_programmatic_selection) && isTRUE(pending_programmatic_manual)) {
      normalize_myc_partner_values(pending_programmatic_selection, comparison_mode = share_data$comparison_mode)
    } else {
      normalize_myc_partner_values(input$partner_show, comparison_mode = share_data$comparison_mode)
    }
    legal_input_selected <- character(0)
    if (identical(partner_selection_input_version(), partner_selection_context_version()) && isTRUE(partner_selection_manual_override())) {
      legal_input_selected <- unique(input_selected[input_selected %in% partner_choices])
    }
    if (length(legal_input_selected) > 0) {
      if (identical(share_data$comparison_mode, "country")) {
        remembered_state <- get_remembered_partner_selection_state("country")
        legal_input_selected <- legalize_myc_country_partner_selection(
          selection = legal_input_selected,
          previous_selection = remembered_state$selection,
          eligible_partners = partner_choices
        )$selection
      }
      return(legal_input_selected)
    }

    if (identical(share_data$comparison_mode, "type")) {
      remembered_selection <- get_remembered_partner_selection("type", eligible_choices = partner_choices, manual_only = TRUE)
    } else {
      remembered_selection <- get_remembered_partner_selection("country", eligible_choices = partner_choices, manual_only = TRUE)
    }

    remembered_selection <- unique(remembered_selection)
    if (identical(share_data$comparison_mode, "country") && length(remembered_selection) > 0) {
      remembered_state <- get_remembered_partner_selection_state("country")
      remembered_selection <- legalize_myc_country_partner_selection(
        selection = remembered_selection,
        previous_selection = remembered_state$selection,
        eligible_partners = partner_choices
      )$selection
    }

    remembered_selection
  })

  market_year_display_partner_selection <- reactive({
    record_partner_share_data_read("market_year_display_partner_selection")
    share_data <- partner_share_data()
    if (is.null(share_data)) return(character(0))

    effective_selection <- market_year_effective_partner_selection()
    manual_selection <- market_year_manual_partner_selection()
    auto_display_partners <- unique(share_data$auto_display_partners)

    unique(c(
      effective_selection[effective_selection %in% auto_display_partners],
      manual_selection
    ))
  })

  myc_native_hybrid_overlap_messages <- reactive({
    if (!is_myc_hybrid_type_mode_active()) return(character(0))

    display_selection <- market_year_display_partner_selection()
    native_selection <- normalize_myc_type_selection_values(display_selection)
    native_selection <- native_selection[native_selection %in% native_hybrid_export_nodes]

    overlap_messages <- character(0)
    for (selection_name in native_selection) {
      if (!(selection_name %in% native_hybrid_export_parent_nodes)) next

      selection_leaves <- get_native_hybrid_export_leaf_descendants(selection_name)
      descendant_selection <- setdiff(native_selection, selection_name)
      descendant_selection <- descendant_selection[vapply(descendant_selection, function(other_name) {
        other_leaves <- get_native_hybrid_export_leaf_descendants(other_name)
        length(other_leaves) > 0 && all(other_leaves %in% selection_leaves)
      }, logical(1))]

      if (length(descendant_selection) > 0) {
        overlap_messages <- c(
          overlap_messages,
          paste0(selection_name, " overlaps with ", paste(sort(unique(descendant_selection)), collapse = ", "), ".")
        )
      }
    }

    unique(overlap_messages)
  })

  myc_custom_exact_hybrid_overlap_messages <- reactive({
    if (!is_myc_hybrid_type_mode_active()) return(character(0))

    overlap_pairs <- detect_exact_hybrid_overlap_pairs(market_year_display_partner_selection())
    if (nrow(overlap_pairs) == 0) return(character(0))

    custom_pairs <- overlap_pairs %>%
      filter(.data$left_source == "custom" | .data$right_source == "custom")

    if (nrow(custom_pairs) == 0) return(character(0))

    custom_pairs %>%
      mutate(
        custom_name = if_else(.data$left_source == "custom", .data$left_name, .data$right_name),
        overlapping_name = if_else(.data$left_source == "custom", .data$right_name, .data$left_name)
      ) %>%
      group_by(.data$custom_name) %>%
      summarise(
        warning_message = paste0(
          .data$custom_name[[1]],
          " exactly overlaps with selected Hybrid categories: ",
          paste(sort(unique(.data$overlapping_name)), collapse = ", "),
          "."
        ),
        .groups = "drop"
      ) %>%
      pull(.data$warning_message)
  })

  myc_custom_integrity_override_messages <- reactive({
    if (!is_myc_type_mode_active()) return(character(0))

    record_partner_share_data_read("myc_custom_integrity_override_messages")
    share_data <- tryCatch(partner_share_data(), error = function(e) NULL)
    override_pairs <- detect_exact_myc_custom_selected_overrides(
      selection = market_year_display_partner_selection(),
      eligible_partners = if (!is.null(share_data)) share_data$eligible_partners else NULL
    )
    if (nrow(override_pairs) == 0) return(character(0))

    format_numbered_override_names <- function(names_vec) {
      numbered_names <- paste0(seq_along(names_vec), ") ", names_vec)
      if (length(numbered_names) <= 1) return(numbered_names)
      if (length(numbered_names) == 2) {
        return(paste(numbered_names, collapse = ", and "))
      }

      paste0(
        paste(numbered_names[-length(numbered_names)], collapse = ", "),
        ", and ",
        numbered_names[[length(numbered_names)]]
      )
    }

    override_pairs %>%
      group_by(.data$custom_name) %>%
      summarise(
        warning_message = paste0(
          .data$custom_name[[1]],
          " fully overlaps selected ", tolower(COMMODITY_TYPE_LABEL %||% "commodity type"), " values and overrides them in chart totals: ",
          format_numbered_override_names(sort(unique(.data$native_name))),
          "."
        ),
        .groups = "drop"
      ) %>%
      pull(.data$warning_message)
  })

  myc_country_overlap_legalization_messages <- reactive({
    if (!identical(market_year_comparison_mode(), "country")) {
      return(character(0))
    }

    messages <- as.character(myc_country_overlap_legalization_messages_state() %||% character(0))
    messages <- messages[!is.na(messages) & nzchar(messages)]
    unique(messages)
  })

  market_year_partner_choice_order <- reactive({
    record_partner_share_data_read("market_year_partner_choice_order")
    share_data <- partner_share_data()
    if (is.null(share_data)) return(character(0))

    partner_choices <- unique(share_data$eligible_partners)
    if (length(partner_choices) == 0) return(character(0))

    if (identical(input$main_tabs_panel, "Market Year Comparison Tool")) {
      current_sort <- if (!is.null(input$country_sort) && input$country_sort %in% c("alpha", "value")) {
        input$country_sort
      } else {
        "value"
      }

      if (identical(current_sort, "alpha")) {
        record_partner_share_data_read("market_year_partner_show_choices")
        return(sort(partner_choices))
      }

      current_ranked <- share_data$df %>%
        filter(.data$market_year == share_data$current_my, .data$comparison_item %in% partner_choices) %>%
        group_by(.data$comparison_item) %>%
        summarise(
          share_pct = first(.data$share_pct),
          plot_metric = first(.data$plot_metric),
          .groups = "drop"
        ) %>%
        arrange(dplyr::desc(dplyr::coalesce(.data$share_pct, -Inf)), dplyr::desc(dplyr::coalesce(.data$plot_metric, -Inf)), .data$comparison_item) %>%
        pull(.data$comparison_item)

      return(unique(c(current_ranked, partner_choices)))
    }

    if (!isTRUE(market_year_latest_ordering_enabled())) {
      return(partner_choices)
    }

    latest_ranked <- share_data$df %>%
      filter(.data$market_year == share_data$current_my, .data$comparison_item %in% partner_choices) %>%
      group_by(.data$comparison_item) %>%
      summarise(plot_metric = sum(.data$plot_metric, na.rm = TRUE), .groups = "drop") %>%
      arrange(dplyr::desc(.data$plot_metric), .data$comparison_item) %>%
      pull(.data$comparison_item)

    unique(c(latest_ranked, partner_choices))
  })

  order_myc_selected_partners_by_market_share <- function(selection, share_data) {
    if (is.null(share_data)) {
      return(character(0))
    }

    comparison_mode <- share_data$comparison_mode %||% market_year_comparison_mode()
    normalized_selection <- normalize_myc_partner_values(selection, comparison_mode = comparison_mode)
    partner_choices <- unique(normalize_myc_partner_values(share_data$eligible_partners, comparison_mode = comparison_mode))
    legal_selection <- unique(normalized_selection[normalized_selection %in% partner_choices])
    if (length(legal_selection) <= 1) {
      return(legal_selection)
    }

    ranked_selection <- share_data$df %>%
      filter(.data$market_year == share_data$current_my, .data$comparison_item %in% legal_selection) %>%
      group_by(.data$comparison_item) %>%
      summarise(
        share_pct = first(.data$share_pct),
        plot_metric = first(.data$plot_metric),
        .groups = "drop"
      ) %>%
      arrange(
        dplyr::desc(dplyr::coalesce(.data$share_pct, -Inf)),
        dplyr::desc(dplyr::coalesce(.data$plot_metric, -Inf)),
        .data$comparison_item
      ) %>%
      pull(.data$comparison_item)

    unique(c(ranked_selection, legal_selection))
  }

  build_grouped_myc_partner_show_choices <- function(flat_choices, share_data) {
    if (is.null(flat_choices) || length(flat_choices) == 0) {
      return(flat_choices)
    }

    comparison_mode <- share_data$comparison_mode %||% market_year_comparison_mode()
    choice_values <- as.character(unname(flat_choices))
    choice_labels <- as.character(names(flat_choices) %||% choice_values)

    if (identical(comparison_mode, "country")) {
      custom_country_values <- myc_custom_country_display_values(source_choice = current_source_choice_safe())
      custom_lookup <- share_data$df %>%
        filter(.data$comparison_item %in% choice_values) %>%
        mutate(
          country_value = trimws(as.character(.data$country %||% "")),
          is_custom = startsWith(.data$country_value, CUSTOM_COUNTRY_CHOICE_PREFIX)
        ) %>%
        group_by(.data$comparison_item) %>%
        summarise(is_custom = any(.data$is_custom), .groups = "drop") %>%
        {
          stats::setNames(.$is_custom, .$comparison_item)
        }

      choice_is_custom <- function(choice_value) {
        custom_flag <- unname(custom_lookup[choice_value])
        is_custom_from_lookup <- length(custom_flag) > 0 && isTRUE(custom_flag[[1L]])
        is_custom_from_lookup || (choice_value %in% custom_country_values)
      }

      custom_idx <- vapply(choice_values, function(choice_value) {
        choice_is_custom(choice_value)
      }, logical(1))
      native_idx <- !custom_idx

      grouped_choices <- list()
      native_choices <- stats::setNames(choice_values[native_idx], choice_labels[native_idx])
      custom_choices <- stats::setNames(choice_values[custom_idx], choice_labels[custom_idx])

      if (length(native_choices) > 0) {
        grouped_choices[["Native Countries"]] <- native_choices
      }
      if (length(custom_choices) > 0) {
        grouped_choices[["Custom Countries"]] <- custom_choices
      }

      action_choice <- resolve_myc_partner_action_choice(comparison_mode = "country")
      if (!is.null(action_choice)) {
        grouped_choices[["Actions"]] <- stats::setNames(action_choice, "Custom Country Builder...")
      }

      return(grouped_choices)
    }

    if (identical(comparison_mode, "type")) {
      custom_type_defs <- tryCatch(custom_types_enriched(), error = function(e) data.frame())
      custom_type_names <- as_tibble(custom_type_defs %||% data.frame()) %>%
        filter(.data$parse_ok) %>%
        transmute(custom_name = trimws(as.character(.data$custom_name))) %>%
        filter(!is.na(.data$custom_name), nzchar(.data$custom_name)) %>%
        pull(.data$custom_name)

      custom_lookup <- share_data$df %>%
        filter(.data$comparison_item %in% choice_values) %>%
        mutate(
          commodity_name = trimws(as.character(.data$commodity %||% "")),
          is_custom = .data$commodity_name %in% custom_type_names
        ) %>%
        group_by(.data$comparison_item) %>%
        summarise(is_custom = any(.data$is_custom), .groups = "drop") %>%
        {
          stats::setNames(.$is_custom, .$comparison_item)
        }

      choice_is_custom <- function(choice_value) {
        custom_flag <- unname(custom_lookup[choice_value])
        length(custom_flag) > 0 && isTRUE(custom_flag[[1L]])
      }

      custom_idx <- vapply(choice_values, function(choice_value) {
        choice_is_custom(choice_value)
      }, logical(1))
      native_idx <- !custom_idx

      grouped_choices <- list()
      native_choices <- stats::setNames(choice_values[native_idx], choice_labels[native_idx])
      custom_choices <- stats::setNames(choice_values[custom_idx], choice_labels[custom_idx])

      if (length(native_choices) > 0) {
        grouped_choices[["Native Types"]] <- native_choices
      }
      if (length(custom_choices) > 0) {
        grouped_choices[["Custom Types"]] <- custom_choices
      }

      grouped_choices[["Actions"]] <- stats::setNames(CUSTOM_BUILDER_CHOICE, "Custom Type Builder...")
      return(grouped_choices)
    }

    flat_choices
  }

  market_year_partner_show_choices <- reactive({
    share_data <- partner_share_data()
    if (is.null(share_data)) return(character(0))

    partner_choices <- market_year_partner_choice_order()
    if (length(partner_choices) == 0) return(character(0))

    share_lookup <- share_data$df %>%
      filter(.data$market_year == share_data$current_my, .data$comparison_item %in% partner_choices) %>%
      group_by(.data$comparison_item) %>%
      summarise(share_pct = first(.data$share_pct), .groups = "drop") %>%
      {
        stats::setNames(.$share_pct, .$comparison_item)
      }

    flat_choices <- stats::setNames(
      partner_choices,
      vapply(partner_choices, function(choice_value) {
        share_val <- unname(share_lookup[choice_value])
        if (length(share_val) == 0 || is.na(share_val)) {
          return(choice_value)
        }

        paste0(choice_value, " (", sprintf("%.1f%%", share_val * 100), ")")
      }, character(1))
    )

    build_grouped_myc_partner_show_choices(flat_choices, share_data)
  })

  market_year_effective_partner_selection <- reactive({
    record_partner_share_data_read("market_year_effective_partner_selection")
    share_data <- partner_share_data()
    if (is.null(share_data)) return(character(0))

    partner_choices <- unique(share_data$eligible_partners)
    if (length(partner_choices) == 0) return(character(0))

    if (isTRUE(partner_selection_force_default())) {
      legal_default_selection <- unique(share_data$default_sel[share_data$default_sel %in% partner_choices])
      if (length(legal_default_selection) > 0) {
        return(order_myc_selected_partners_by_market_share(legal_default_selection, share_data))
      }
    }

    reset_override_selection <- normalize_myc_partner_values(partner_selection_reset_override(), comparison_mode = share_data$comparison_mode)
    legal_reset_override_selection <- unique(reset_override_selection[reset_override_selection %in% partner_choices])
    if (length(legal_reset_override_selection) > 0) {
      return(order_myc_selected_partners_by_market_share(legal_reset_override_selection, share_data))
    }

    legalized_override_selection <- get_partner_selection_legalized_override(share_data$comparison_mode)
    pending_programmatic_selection <- isolate(partner_selection_programmatic_selected())
    pending_programmatic_manual <- isTRUE(isolate(partner_selection_programmatic_manual()))
    input_selected <- if (length(legalized_override_selection) > 0) {
      legalized_override_selection
    } else if (!is.null(pending_programmatic_selection) && isTRUE(pending_programmatic_manual)) {
      normalize_myc_partner_values(pending_programmatic_selection, comparison_mode = share_data$comparison_mode)
    } else {
      normalize_multi_select(input$partner_show)
    }
    legal_input_selected <- character(0)
    if (identical(partner_selection_input_version(), partner_selection_context_version())) {
      legal_input_selected <- unique(input_selected[input_selected %in% partner_choices])
    }
    if (length(legal_input_selected) > 0) {
      if (identical(share_data$comparison_mode, "country")) {
        remembered_state <- get_remembered_partner_selection_state("country")
        legal_input_selected <- legalize_myc_country_partner_selection(
          selection = legal_input_selected,
          previous_selection = remembered_state$selection,
          eligible_partners = partner_choices
        )$selection
      }
      return(order_myc_selected_partners_by_market_share(legal_input_selected, share_data))
    }

    legal_remembered_selection <- get_remembered_partner_selection(
      comparison_mode = share_data$comparison_mode,
      eligible_choices = partner_choices,
      manual_only = TRUE
    )
    if (length(legal_remembered_selection) > 0) {
      if (identical(share_data$comparison_mode, "country")) {
        remembered_state <- get_remembered_partner_selection_state("country")
        legal_remembered_selection <- legalize_myc_country_partner_selection(
          selection = legal_remembered_selection,
          previous_selection = remembered_state$selection,
          eligible_partners = partner_choices
        )$selection
      }
      return(order_myc_selected_partners_by_market_share(legal_remembered_selection, share_data))
    }

    legal_default_selection <- unique(share_data$default_sel[share_data$default_sel %in% partner_choices])
    if (length(legal_default_selection) > 0) {
      return(order_myc_selected_partners_by_market_share(legal_default_selection, share_data))
    }

    non_custom_fallback <- unique(share_data$default_basis_partners %||% character(0))
    non_custom_fallback <- non_custom_fallback[non_custom_fallback %in% partner_choices]
    if (length(non_custom_fallback) > 0) {
      return(non_custom_fallback[[1]])
    }

    partner_choices[1]
  })

  # One-time initializer state for Custom Comparison Tool defaults.
  custom_comparison_initialized <- reactiveVal(FALSE)
  custom_comparison_pending_metric_targets <- reactiveVal(list())

  resolve_custom_comparison_country <- function(preferred_country = "GRAND_TOTAL") {
    panel_country_choices <- country_choice_options()
    if (is.null(panel_country_choices) || length(panel_country_choices) == 0) {
      panel_country_choices <- setNames("GRAND_TOTAL", "Grand Total")
    }

    panel_country_codes <- unique(unname(panel_country_choices))
    panel_country_codes <- panel_country_codes[!is.na(panel_country_codes) & nzchar(panel_country_codes)]
    if (length(panel_country_codes) == 0) return("GRAND_TOTAL")
    if (!is.null(preferred_country) && preferred_country %in% panel_country_codes) return(preferred_country)
    if ("GRAND_TOTAL" %in% panel_country_codes) return("GRAND_TOTAL")
    panel_country_codes[[1]]
  }

  custom_comparison_country_universe <- function() {
    panel_country_choices <- country_display_names_for_frequency()
    if (is.null(panel_country_choices) || length(panel_country_choices) == 0) {
      panel_country_choices <- country_choice_options()
    }
    if (is.null(panel_country_choices) || length(panel_country_choices) == 0) {
      panel_country_choices <- setNames("GRAND_TOTAL", "Grand Total")
    }

    panel_country_codes <- unique(unname(panel_country_choices))
    panel_country_codes[!is.na(panel_country_codes) & nzchar(panel_country_codes)]
  }

  resolve_custom_comparison_commodity <- function(preferred_commodity = default_commodity_choice_value()) {
    default_commodity <- default_commodity_choice_value()
    available_commodities <- commodity_choice_real_values()
    if (length(available_commodities) == 0) {
      available_commodities <- setNames(default_commodity, default_commodity)
    }

    commodity_values <- unique(unname(available_commodities))
    commodity_values <- commodity_values[!is.na(commodity_values) & nzchar(commodity_values)]
    if (length(commodity_values) == 0) return(default_commodity)
    if (!is.null(preferred_commodity) && preferred_commodity %in% commodity_values) return(preferred_commodity)
    if (default_commodity %in% commodity_values) return(default_commodity)
    commodity_values[[1]]
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

  perf_scalar_or_default <- function(value, default = "NULL") {
    if (is.null(value) || length(value) == 0) return(default)

    normalized <- trimws(as.character(value[[1]]))
    if (is.na(normalized) || !nzchar(normalized)) default else normalized
  }

  custom_comparison_perf_details <- function(extra = list()) {
    source_choice <- if (!is.null(input$data_source_choice)) input$data_source_choice else "export_sales"

    c(
      list(
        tab = perf_scalar_or_default(input$main_tabs_panel),
        source = source_choice,
        frequency = perf_scalar_or_default(input$data_frequency),
        trade_flow = effective_trade_flow_for_source(source_choice, input$census_trade_flow_choice, input$vp_trade_flow_choice),
        metric = perf_scalar_or_default(effective_main_metric()),
        commodity = perf_scalar_or_default(input$commodity_choice),
        country = perf_scalar_or_default(input$country_choice)
      ),
      extra
    )
  }

  panel_target_prefix_count <- function(panel_targets, prefix) {
    panel_target_names <- names(panel_targets)
    if (is.null(panel_target_names) || length(panel_target_names) == 0) return(0L)

    sum(startsWith(panel_target_names, prefix))
  }

  reconcile_custom_comparison_non_metric_targets <- function() {
    start_time <- Sys.time()

    normalize_choice_values <- function(values, fallback_value) {
      if (length(values) == 0) {
        values <- setNames(fallback_value, fallback_value)
      }

      normalized_values <- unique(unname(values))
      normalized_values[!is.na(normalized_values) & nzchar(normalized_values)]
    }

    choose_preserved_value <- function(field_name, legal_values, resolver) {
      stored_value <- isolate(panel_state[[field_name]])
      current_value <- input[[field_name]]

      if (!is.null(stored_value) && stored_value %in% legal_values) {
        return(stored_value)
      }

      if (!is.null(current_value) && current_value %in% legal_values) {
        return(current_value)
      }

      fallback_value <- if (!is.null(stored_value)) stored_value else current_value
      resolver(fallback_value)
    }

    country_fields <- c("country_right_2up", "country_grid_2", "country_grid_3", "country_grid_4")
    commodity_fields <- c("commodity_right_2up", "commodity_grid_2", "commodity_grid_3", "commodity_grid_4")
    vp_commodity_name_fields <- c("vp_commodity_name_right_2up", "vp_commodity_name_grid_3", "vp_commodity_name_grid_4")

    legal_country_values <- normalize_choice_values(country_choice_options(), "GRAND_TOTAL")
    legal_commodity_values <- normalize_choice_values(commodity_choice_real_values(), default_commodity_choice_value())
    legal_vp_commodity_name_values <- normalize_choice_values(
      custom_comparison_vp_commodity_name_choices(),
      resolve_custom_comparison_vp_commodity_name(input$vp_commodity_name_choice)
    )
    panel_targets <- list()

    for (field_name in country_fields) {
      reconciled_value <- choose_preserved_value(
        field_name,
        legal_country_values,
        resolve_custom_comparison_country
      )

      if (!identical(isolate(panel_state[[field_name]]), reconciled_value)) {
        panel_targets[[field_name]] <- reconciled_value
      }
    }

    for (field_name in commodity_fields) {
      reconciled_value <- choose_preserved_value(
        field_name,
        legal_commodity_values,
        resolve_custom_comparison_commodity
      )

      if (!identical(isolate(panel_state[[field_name]]), reconciled_value)) {
        panel_targets[[field_name]] <- reconciled_value
      }
    }

    if (identical(current_source_choice_safe(default = input$data_source_choice %||% "export_sales"), "vp_trade")) {
      for (field_name in vp_commodity_name_fields) {
        reconciled_value <- choose_preserved_value(
          field_name,
          legal_vp_commodity_name_values,
          resolve_custom_comparison_vp_commodity_name
        )

        if (!identical(isolate(panel_state[[field_name]]), reconciled_value)) {
          panel_targets[[field_name]] <- reconciled_value
        }
      }
    }

    log_perf(
      "reconcile_custom_comparison_non_metric_targets()",
      start_time,
      details = custom_comparison_perf_details(list(
        legal_country_values = length(legal_country_values),
        legal_commodity_values = length(legal_commodity_values),
        legal_vp_commodity_name_values = length(legal_vp_commodity_name_values),
        target_updates = length(panel_targets),
        country_updates = panel_target_prefix_count(panel_targets, "country_"),
        commodity_updates = panel_target_prefix_count(panel_targets, "commodity_"),
        vp_commodity_name_updates = panel_target_prefix_count(panel_targets, "vp_commodity_name_")
      ))
    )

    panel_targets
  }

  apply_custom_comparison_panel_targets <- function(panel_targets) {
    start_time <- Sys.time()

    normalize_input_value <- function(value) {
      if (is.null(value) || length(value) == 0) return(NULL)
      normalized <- as.character(value[[1]])
      if (is.na(normalized) || !nzchar(normalized)) return(NULL)
      normalized
    }

    panel_target_names <- names(panel_targets)
    metric_targets <- if (is.null(panel_target_names) || length(panel_target_names) == 0) {
      list()
    } else {
      panel_targets[startsWith(panel_target_names, "metric_")]
    }
    if (length(metric_targets) > 0) {
      pending_targets <- isolate(custom_comparison_pending_metric_targets())
      pending_targets[names(metric_targets)] <- metric_targets
      custom_comparison_pending_metric_targets(pending_targets)
    }

    panel_state_updates <- sum(vapply(names(panel_targets), function(field_name) {
      !is.null(panel_targets[[field_name]]) && !identical(panel_state[[field_name]], panel_targets[[field_name]])
    }, logical(1)))

    input_updates <- sum(vapply(names(panel_targets), function(field_name) {
      target_value <- panel_targets[[field_name]]
      !is.null(target_value) && !identical(normalize_input_value(input[[field_name]]), target_value)
    }, logical(1)))

    session$onFlushed(function() {
      isolate({
        if (panel_state_updates > 0) {
          for (field_name in names(panel_targets)) {
            target_value <- panel_targets[[field_name]]
            if (!is.null(target_value) && !identical(panel_state[[field_name]], target_value)) {
              panel_state[[field_name]] <- target_value
            }
          }
        }

        if (input_updates > 0) {
          for (field_name in names(panel_targets)) {
            target_value <- panel_targets[[field_name]]
            if (!is.null(target_value) && !identical(normalize_input_value(input[[field_name]]), target_value)) {
              updateSelectInput(session, field_name, selected = target_value)
            }
          }
        }
      })
    }, once = TRUE)

    log_perf(
      "apply_custom_comparison_panel_targets()",
      start_time,
      details = custom_comparison_perf_details(list(
        target_updates = length(panel_targets),
        metric_updates = length(metric_targets),
        panel_state_updates = panel_state_updates,
        queued_input_updates = input_updates
      ))
    )
  }

  psd_metric_choices <- c(
    "Exports" = "psd_exports",
    "Imports" = "psd_imports",
    "Production" = "psd_production",
    "Beginning Stocks" = "psd_beginning_stocks",
    "Ending Stocks" = "psd_ending_stocks",
    "Domestic Consumption" = "psd_domestic_consumption",
    "Total Supply" = "psd_total_supply",
    "Total Distribution" = "psd_total_distribution"
  )

  wasde_metric_catalog_fallback <- data.frame(
    metric_id = c(
      "acreage_planted",
      "average_price",
      "beginning_stocks",
      "commodity_credit_corporation_inventory",
      "contract_payments",
      "deficiency_payments",
      "denatured_for_fuel",
      "ending_stocks",
      "exports_milled_production",
      "exports_rough_production",
      "exports_pl_480",
      "food_use",
      "harvested_acres",
      "imports",
      "land_diversion_payment_rate",
      "loan_rate",
      "market_value_of_production",
      "milling_rate",
      "production",
      "projected_amount_of_free_stock_carryout_in_the_special_producer_stroage_loan_program",
      "qty_of_exports",
      "qty_of_seed_used",
      "residual",
      "stocks_to_use_ratio",
      "target_price",
      "total_domestic",
      "total_domestic_and_residual",
      "total_supply",
      "total_use",
      "yield"
    ),
    metric_label = c(
      "Acreage planted",
      "Average price",
      "Beginning stocks",
      "Commodity Credit Corporation inventory",
      "Contract Payments",
      "Deficiency payments",
      "Denatured for fuel",
      "Ending stocks",
      "Exports, milled production",
      "Exports, rough production = Qty of Exports - Exports, milled production",
      "Exports PL 480",
      "Food use",
      "Harvested acres",
      "Imports",
      "Land diversion payment rate",
      "Loan rate",
      "Market value of production",
      "Milling rate",
      "Production",
      "Projected amount of free-stock carryout in the special producer stroage loan program",
      "Qty of Exports",
      "Qty of Seed Used",
      "Residual",
      "Stocks-to-use ratio",
      "Target price",
      "Total domestic",
      "Total Domestic and Residual",
      "Total supply",
      "Total use",
      "Yield"
    ),
    canonical_unit = c(
      "Million acres",
      "Dollars per Hundredweight",
      "Million Hundredweight",
      "Million Hundredweight",
      "Million dollars",
      "Million dollars",
      "Million Hundredweight",
      "Million Hundredweight",
      "Million Hundredweight",
      "Million Hundredweight",
      "Million Hundredweight",
      "Million Hundredweight",
      "Million acres",
      "Million Hundredweight",
      "Percent",
      "Dollars per bushel",
      "Million dollars",
      "Percent",
      "Million Hundredweight",
      "Million Hundredweight",
      "Million Hundredweight",
      "Million Hundredweight",
      "Million Hundredweight",
      "Percent",
      "Dollars per Hundredweight",
      "Million Hundredweight",
      "Million Hundredweight",
      "Million Hundredweight",
      "Million Hundredweight",
      "Pounds per acre"
    ),
    stringsAsFactors = FALSE
  )

  common_quantity_unit_choices <- c(
    "Million Hundredweight" = "million_cwt",
    "1000 Metric Tons" = "thousand_mt",
    "Metric Tons (MT)" = "mt",
    "Kilograms (KG)" = "kg",
    "1000 Kilograms" = "thousand_kg",
    "US Tons" = "us_tons",
    "1000 Pounds" = "thousand_lbs",
    "Pounds" = "lbs",
    "Hundredweight (CWT)" = "cwt",
    "Million Pounds" = "mil_lbs"
  )

  census_value_metric_codes <- c("monthlyvalue", "ytd_value")

  census_value_unit_choices <- c(
    "Billion Dollars" = "billion_dollars",
    "Million Dollars" = "million_dollars",
    "1000 Dollars" = "thousand_dollars",
    "Dollars" = "dollars"
  )

  standard_quantity_unit_choices <- common_quantity_unit_choices

  psd_quantity_unit_choices <- common_quantity_unit_choices

  wasde_quantity_unit_choices <- c(
    "Million Hundredweight" = "million_cwt",
    "1000 Metric Tons" = "thousand_mt",
    "Metric Tons (MT)" = "mt",
    "Kilograms (KG)" = "kg",
    "1000 Kilograms" = "thousand_kg",
    "Bushels" = "bushels",
    "US Tons" = "us_tons",
    "1000 Pounds" = "thousand_lbs",
    "Million Pounds" = "mil_lbs",
    "Pounds" = "lbs",
    "Hundredweight (CWT)" = "cwt"
  )

  wasde_metric_canonical_unit_overrides <- c(
    "stocks_to_use_ratio" = "Percent"
  )

  wasde_metric_label_overrides <- c(
    "exports_rough_production" = "Exports, rough production",
    "total_domestic_and_residual" = "Total Domestic and Residual",
    "yield" = "Yield per harvested acre"
  )

  apply_wasde_metric_canonical_unit_overrides <- function(metric_catalog) {
    if (
      !is.data.frame(metric_catalog) ||
        nrow(metric_catalog) == 0 ||
        !all(c("metric_id", "canonical_unit") %in% names(metric_catalog))
    ) {
      return(metric_catalog)
    }

    metric_ids <- trimws(as.character(metric_catalog$metric_id))
    override_mask <- !is.na(metric_ids) & metric_ids %in% names(wasde_metric_canonical_unit_overrides)
    if (!any(override_mask)) {
      return(metric_catalog)
    }

    metric_catalog$canonical_unit[override_mask] <- unname(wasde_metric_canonical_unit_overrides[metric_ids[override_mask]])
    metric_catalog
  }

  apply_wasde_metric_label_overrides <- function(metric_catalog) {
    if (
      !is.data.frame(metric_catalog) ||
        nrow(metric_catalog) == 0 ||
        !all(c("metric_id", "metric_label") %in% names(metric_catalog))
    ) {
      return(metric_catalog)
    }

    metric_ids <- trimws(as.character(metric_catalog$metric_id))
    override_mask <- !is.na(metric_ids) & metric_ids %in% names(wasde_metric_label_overrides)
    if (!any(override_mask)) {
      return(metric_catalog)
    }

    metric_catalog$metric_label[override_mask] <- unname(wasde_metric_label_overrides[metric_ids[override_mask]])
    metric_catalog
  }

  wasde_metric_priority_ids <- c(
    "acreage_planted",
    "harvested_acres",
    "yield",
    "beginning_stocks",
    "production",
    "imports",
    "total_supply",
    "total_domestic",
    "qty_of_exports",
    "exports_rough_production",
    "exports_milled_production",
    "total_use",
    "ending_stocks",
    "milling_rate",
    "average_price"
  )

  normalize_wasde_metric_order_label <- function(metric_labels) {
    label_values <- trimws(as.character(metric_labels))
    label_values[is.na(label_values)] <- ""
    tolower(label_values)
  }

  order_wasde_metric_catalog <- function(metric_catalog) {
    if (
      !is.data.frame(metric_catalog) ||
        nrow(metric_catalog) == 0 ||
        !all(c("metric_id", "metric_label") %in% names(metric_catalog))
    ) {
      return(metric_catalog)
    }

    metric_ids <- trimws(as.character(metric_catalog$metric_id))
    priority_lookup <- stats::setNames(seq_along(wasde_metric_priority_ids), wasde_metric_priority_ids)
    priority_rank <- unname(priority_lookup[metric_ids])
    priority_rank[is.na(priority_rank)] <- length(wasde_metric_priority_ids) + 1L

    order_idx <- order(
      priority_rank,
      normalize_wasde_metric_order_label(metric_catalog$metric_label),
      metric_ids,
      na.last = TRUE
    )

    metric_catalog[order_idx, , drop = FALSE]
  }

  finalize_wasde_metric_catalog <- function(metric_catalog) {
    required_cols <- c("metric_id", "metric_label", "canonical_unit")
    if (!is.data.frame(metric_catalog) || !all(required_cols %in% names(metric_catalog)) || nrow(metric_catalog) == 0) {
      metric_catalog <- wasde_metric_catalog_fallback
    }

    metric_catalog <- metric_catalog %>%
      transmute(
        metric_id = trimws(as.character(.data$metric_id)),
        metric_label = trimws(as.character(.data$metric_label)),
        canonical_unit = trimws(as.character(.data$canonical_unit))
      ) %>%
      filter(!is.na(.data$metric_id), nzchar(.data$metric_id))

    if (nrow(metric_catalog) == 0) {
      metric_catalog <- wasde_metric_catalog_fallback
    }

    metric_catalog %>%
      apply_wasde_metric_canonical_unit_overrides() %>%
      apply_wasde_metric_label_overrides() %>%
      order_wasde_metric_catalog()
  }

  build_wasde_metric_catalog <- function(source_df = tryCatch(rice_data_wasde_marketing_year, error = function(...) NULL)) {
    runtime_catalog <- data.frame(stringsAsFactors = FALSE)

    if (is.data.frame(source_df) && nrow(source_df) > 0 && ("normalized_metric_id" %in% names(source_df))) {
      label_col <- if ("attribute_name" %in% names(source_df)) {
        "attribute_name"
      } else if ("attribute_desc" %in% names(source_df)) {
        "attribute_desc"
      } else {
        NULL
      }

      runtime_catalog <- source_df %>%
        transmute(
          metric_id = trimws(as.character(.data$normalized_metric_id)),
          metric_label = if (!is.null(label_col)) trimws(as.character(.data[[label_col]])) else "",
          canonical_unit = if ("canonical_unit" %in% names(source_df)) trimws(as.character(.data$canonical_unit)) else ""
        ) %>%
        filter(!is.na(.data$metric_id), nzchar(.data$metric_id)) %>%
        group_by(.data$metric_id) %>%
        summarise(
          metric_label = {
            candidate_labels <- .data$metric_label[!is.na(.data$metric_label) & nzchar(.data$metric_label)]
            if (length(candidate_labels) > 0) {
              candidate_labels[[1]]
            } else {
              stringr::str_to_sentence(gsub("_", " ", .data$metric_id[[1]]))
            }
          },
          canonical_unit = {
            candidate_units <- .data$canonical_unit[!is.na(.data$canonical_unit) & nzchar(.data$canonical_unit)]
            if (length(candidate_units) > 0) {
              candidate_units[[1]]
            } else {
              "WASDE Unit"
            }
          },
          .groups = "drop"
        )
    }

    fallback_only <- wasde_metric_catalog_fallback %>%
      filter(!(.data$metric_id %in% runtime_catalog$metric_id))

    finalize_wasde_metric_catalog(bind_rows(runtime_catalog, fallback_only))
  }

  wasde_metric_catalog <- build_wasde_metric_catalog()

  normalize_wasde_metric_label_token <- function(metric_labels) {
    label_values <- trimws(as.character(metric_labels))
    label_values[is.na(label_values)] <- ""
    label_values <- toupper(label_values)
    label_values <- gsub("[^A-Z0-9]+", " ", label_values)
    label_values <- gsub("\\s+", " ", label_values)
    trimws(label_values)
  }

  wasde_ui_hidden_metric_id_fallbacks <- c(
    "commodity_credit_corporation_inventory",
    "contract_payments",
    "deficiency_payments",
    "denatured_for_fuel",
    "farmer_owned_reserve",
    "food_use",
    "land_diversion_payment_rate",
    "market_value_of_production",
    "residual",
    "total_domestic_and_residual",
    "projected_amount_of_free_stock_carryout_in_the_special_producer_stroage_loan_program",
    "projected_amount_of_free_stock_carryout_in_the_special_producer_storage_loan_program"
  )

  resolve_wasde_ui_hidden_metric_ids <- function(metric_catalog = wasde_metric_catalog) {
    if (!is.data.frame(metric_catalog) || nrow(metric_catalog) == 0) {
      return(unique(wasde_ui_hidden_metric_id_fallbacks))
    }

    normalized_labels <- normalize_wasde_metric_label_token(metric_catalog$metric_label)
    hidden_label_patterns <- c(
      "^COMMODITY CREDIT CORPORATION INVENTORY$",
      "^CONTRACT PAYMENTS$",
      "^DEFICIENCY PAYMENTS$",
      "^DENATURED FOR FUEL$",
      "^FOOD USE$",
      "^LAND DIVERSION PAYMENT RATE$",
      "^MARKET VALUE OF PRODUCTION$",
      "^PROJECTED AMOUNT OF FREE STOCK CARRYOUT"
    )

    label_hidden_flags <- vapply(
      normalized_labels,
      function(label_value) {
        if (!nzchar(label_value)) {
          return(FALSE)
        }

        any(vapply(hidden_label_patterns, function(pattern) grepl(pattern, label_value), logical(1)))
      },
      logical(1)
    )

    label_hidden_ids <- metric_catalog$metric_id[label_hidden_flags]
    label_hidden_ids <- trimws(as.character(label_hidden_ids))
    label_hidden_ids <- label_hidden_ids[!is.na(label_hidden_ids) & nzchar(label_hidden_ids)]

    available_ids <- trimws(as.character(metric_catalog$metric_id))
    available_ids <- available_ids[!is.na(available_ids) & nzchar(available_ids)]
    fallback_hidden_ids <- wasde_ui_hidden_metric_id_fallbacks[wasde_ui_hidden_metric_id_fallbacks %in% available_ids]

    unique(c(label_hidden_ids, fallback_hidden_ids))
  }

  filter_wasde_ui_metric_choices <- function(metric_choices, hidden_metric_ids = resolve_wasde_ui_hidden_metric_ids()) {
    if (length(metric_choices) == 0 || length(hidden_metric_ids) == 0) {
      return(metric_choices)
    }

    metric_choices[!(unname(metric_choices) %in% hidden_metric_ids)]
  }

  wasde_metric_choice_labels <- make.unique(wasde_metric_catalog$metric_label)
  wasde_metric_choices <- stats::setNames(wasde_metric_catalog$metric_id, wasde_metric_choice_labels)
  wasde_metric_choices <- filter_wasde_ui_metric_choices(wasde_metric_choices)
  wasde_metric_label_lookup <- stats::setNames(wasde_metric_catalog$metric_label, wasde_metric_catalog$metric_id)
  wasde_metric_unit_lookup <- stats::setNames(wasde_metric_catalog$canonical_unit, wasde_metric_catalog$metric_id)
  wasde_metric_alias_map <- c(
    ytd_exports = "qty_of_exports",
    total_commitment = "total_domestic",
    wasde_qty_of_exports = "qty_of_exports",
    wasde_total_domestic = "total_domestic"
  )

  build_nass_metric_catalog <- function(source_df = tryCatch(rice_data_nass_annual, error = function(...) NULL)) {
    nass_metric_ui_code <- function(metric_id, metric_source_id = NULL) {
      metric_id <- trimws(as.character(metric_id))
      metric_source_id <- trimws(as.character(metric_source_id %||% ""))

      if (is.na(metric_id) || !nzchar(metric_id)) {
        return(metric_id)
      }

      if (startsWith(metric_id, "nass_")) {
        return(metric_id)
      }

      if (identical(metric_id, "yield") && identical(metric_source_id, "yield_utilized_tons")) {
        return("nass_yield_may_estimate")
      }

      if (identical(metric_id, "yield") && metric_source_id %in% c("yield_utilized", "yield_shelled_utilized")) {
        return("nass_yield")
      }

      paste0("nass_", metric_id)
    }

    fallback_catalog <- tibble::tibble(
      metric_id = c(
        "nass_acres_bearing",
        "nass_yield_may_estimate",
        "nass_yield",
        "nass_production_shelled_lb",
        "nass_price_received_per_lb",
        "nass_production_shelled_value"
      ),
      metric_label = c(
        "Bearing Acres",
        "Yield - May estimate",
        "Yield",
        "Production, Shelled",
        "Price Received",
        "Production Value"
      ),
      canonical_unit = c("1,000 acres", "lb/acre", "lb/acre", "million lb", "dollars/lb", "1,000 dollars")
    )

    if (!is.data.frame(source_df) || nrow(source_df) == 0 || !("metric_id" %in% names(source_df))) {
      return(fallback_catalog)
    }

    runtime_catalog <- source_df %>%
      transmute(
        metric_id = vapply(
          seq_len(n()),
          function(idx) nass_metric_ui_code(
            metric_id = .data$metric_id[[idx]],
            metric_source_id = if ("metric_source_id" %in% names(source_df)) .data$metric_source_id[[idx]] else ""
          ),
          character(1)
        ),
        metric_label = if ("metric_label" %in% names(source_df)) trimws(as.character(.data$metric_label)) else "",
        canonical_unit = if ("unit" %in% names(source_df)) trimws(as.character(.data$unit)) else ""
      ) %>%
      filter(!is.na(.data$metric_id), nzchar(.data$metric_id)) %>%
      mutate(
        metric_label = dplyr::case_when(
          .data$metric_id == "nass_yield_may_estimate" ~ "Yield - May estimate",
          .data$metric_id == "nass_yield" ~ "Yield",
          TRUE ~ .data$metric_label
        )
      ) %>%
      group_by(.data$metric_id) %>%
      summarise(
        metric_label = {
          candidate_labels <- .data$metric_label[!is.na(.data$metric_label) & nzchar(.data$metric_label)]
          if (length(candidate_labels) > 0) candidate_labels[[1]] else stringr::str_to_title(gsub("_", " ", .data$metric_id[[1]]))
        },
        canonical_unit = {
          candidate_units <- .data$canonical_unit[!is.na(.data$canonical_unit) & nzchar(.data$canonical_unit)]
          if (length(candidate_units) > 0) candidate_units[[1]] else "NASS Unit"
        },
        .groups = "drop"
      )

    metric_sort_rank <- c(
      nass_acres_bearing = 1L,
      nass_yield_may_estimate = 2L,
      nass_yield = 3L,
      nass_production_shelled_lb = 4L,
      nass_price_received_per_lb = 5L,
      nass_production_shelled_value = 6L,
      nass_shellout_factor = 7L
    )

    bind_rows(runtime_catalog, fallback_catalog %>% filter(!(.data$metric_id %in% runtime_catalog$metric_id))) %>%
      distinct(.data$metric_id, .keep_all = TRUE) %>%
      mutate(sort_rank = unname(metric_sort_rank[.data$metric_id]), sort_rank = ifelse(is.na(.data$sort_rank), 999L, .data$sort_rank)) %>%
      arrange(.data$sort_rank, .data$metric_label) %>%
      select(-sort_rank)
  }

  nass_metric_catalog <- build_nass_metric_catalog()
  nass_metric_choices <- stats::setNames(nass_metric_catalog$metric_id, make.unique(nass_metric_catalog$metric_label))
  nass_metric_label_lookup <- stats::setNames(nass_metric_catalog$metric_label, nass_metric_catalog$metric_id)
  nass_metric_unit_lookup <- stats::setNames(nass_metric_catalog$canonical_unit, nass_metric_catalog$metric_id)

  nass_metric_route_for_code <- function(metric_code) {
    metric_values <- trimws(as.character(metric_code %||% ""))
    metric_values <- metric_values[!is.na(metric_values) & nzchar(metric_values)]
    metric_code_value <- if (length(metric_values) > 0L) metric_values[[1L]] else ""
    metric_id_raw <- sub("^nass_", "", metric_code_value)

    route <- switch(
      metric_id_raw,
      "yield_may_estimate" = list(
        metric_id = "yield",
        metric_source_ids = c("yield_utilized_tons"),
        source_precedence = c("yield_utilized_tons"),
        collapse_by_year = FALSE
      ),
      "yield" = list(
        metric_id = "yield",
        metric_source_ids = c("yield_utilized", "yield_shelled_utilized"),
        source_precedence = c("yield_shelled_utilized", "yield_utilized"),
        collapse_by_year = TRUE
      ),
      list(
        metric_id = metric_id_raw,
        metric_source_ids = character(0),
        source_precedence = character(0),
        collapse_by_year = FALSE
      )
    )

    route$metric_code <- metric_code_value
    route$metric_source_ids <- unique(route$metric_source_ids)
    route$source_precedence <- unique(route$source_precedence)
    route
  }

  normalize_nass_metric_id <- function(metric_code) {
    route <- nass_metric_route_for_code(metric_code)
    metric_id <- trimws(as.character(route$metric_id %||% ""))
    if (!nzchar(metric_id)) return(NA_character_)
    metric_id
  }

  nass_metric_row_id_for_code <- function(metric_code) {
    nass_metric_route_for_code(metric_code)$metric_id
  }

  nass_metric_route_row_mask <- function(source_df, metric_code, collapse = FALSE) {
    if (!is.data.frame(source_df) || nrow(source_df) == 0 || !("metric_id" %in% names(source_df))) {
      return(logical(0))
    }

    route <- nass_metric_route_for_code(metric_code)
    metric_id_values <- trimws(as.character(source_df$metric_id))
    metric_id_values[is.na(metric_id_values)] <- ""
    row_mask <- metric_id_values == trimws(as.character(route$metric_id %||% ""))

    if (length(route$metric_source_ids) > 0L) {
      if (!("metric_source_id" %in% names(source_df))) {
        return(rep(FALSE, nrow(source_df)))
      }

      metric_source_values <- trimws(as.character(source_df$metric_source_id))
      metric_source_values[is.na(metric_source_values)] <- ""
      row_mask <- row_mask & metric_source_values %in% route$metric_source_ids
    }

    if (!isTRUE(collapse) || !isTRUE(route$collapse_by_year) || sum(row_mask, na.rm = TRUE) <= 1L) {
      return(row_mask)
    }

    selected_idx <- which(row_mask)
    selected_rows <- source_df[selected_idx, , drop = FALSE]

    source_rank <- rep(1L, nrow(selected_rows))
    if (length(route$source_precedence) > 0L && "metric_source_id" %in% names(selected_rows)) {
      source_rank <- match(trimws(as.character(selected_rows$metric_source_id)), route$source_precedence)
      source_rank[is.na(source_rank)] <- length(route$source_precedence) + 1L
    }

    release_rank <- rep(-1L, nrow(selected_rows))
    if ("release_month" %in% names(selected_rows)) {
      release_rank <- suppressWarnings(as.integer(selected_rows$release_month))
      release_rank[is.na(release_rank)] <- -1L
    } else if ("analysis_month" %in% names(selected_rows)) {
      release_rank <- suppressWarnings(as.integer(selected_rows$analysis_month))
      release_rank[is.na(release_rank)] <- -1L
    }

    market_year_values <- if ("market_year" %in% names(selected_rows)) suppressWarnings(as.integer(selected_rows$market_year)) else rep(NA_integer_, nrow(selected_rows))
    calendar_year_values <- if ("calendar_year" %in% names(selected_rows)) suppressWarnings(as.integer(selected_rows$calendar_year)) else rep(NA_integer_, nrow(selected_rows))
    period_year_values <- ifelse(is.na(market_year_values), calendar_year_values, market_year_values)
    period_year_values[is.na(period_year_values)] <- seq_len(nrow(selected_rows))[is.na(period_year_values)]

    key_country <- if ("country" %in% names(selected_rows)) trimws(as.character(selected_rows$country)) else rep("", nrow(selected_rows))
    key_commodity <- if ("commodity" %in% names(selected_rows)) trimws(as.character(selected_rows$commodity)) else rep("", nrow(selected_rows))
    key_year_type <- if ("annual_year_type" %in% names(selected_rows)) trimws(as.character(selected_rows$annual_year_type)) else rep("", nrow(selected_rows))
    collapse_key <- paste(key_country, key_commodity, key_year_type, period_year_values, sep = "\r")

    tie_breaker <- seq_along(selected_idx)
    ranked_order <- order(collapse_key, source_rank, -release_rank, -tie_breaker)
    ranked_keys <- collapse_key[ranked_order]
    keep_ranked <- !duplicated(ranked_keys)
    keep_idx <- selected_idx[ranked_order[keep_ranked]]

    out_mask <- rep(FALSE, nrow(source_df))
    out_mask[keep_idx] <- TRUE
    out_mask
  }

  nass_metric_label_for_code <- function(metric_code) {
    metric_id <- trimws(as.character(metric_code %||% ""))
    metric_id <- metric_id[!is.na(metric_id) & nzchar(metric_id)]
    if (length(metric_id) == 0L) return("NASS Metric")

    metric_label <- unname(nass_metric_label_lookup[[metric_id[[1L]]]])
    if (length(metric_label) == 1L && !is.na(metric_label) && nzchar(metric_label)) {
      return(metric_label)
    }

    stringr::str_to_title(gsub("_", " ", sub("^nass_", "", metric_id[[1L]])))
  }

  nass_metric_unit_for_code <- function(metric_code, default = "NASS Unit") {
    metric_id <- trimws(as.character(metric_code %||% ""))
    metric_id <- metric_id[!is.na(metric_id) & nzchar(metric_id)]
    if (length(metric_id) == 0L) return(default)

    metric_unit <- unname(nass_metric_unit_lookup[[metric_id[[1L]]]])
    if (length(metric_unit) == 1L && !is.na(metric_unit) && nzchar(metric_unit)) {
      return(metric_unit)
    }

    default
  }

  normalize_wasde_metric_id <- function(metric_code) {
    metric_values <- trimws(as.character(metric_code))
    metric_values <- metric_values[!is.na(metric_values) & nzchar(metric_values)]

    if (length(metric_values) == 0L) {
      return(NULL)
    }

    metric_id <- metric_values[[1L]]
    if (startsWith(metric_id, "wasde_")) {
      metric_id <- sub("^wasde_", "", metric_id)
    }

    if (metric_id %in% names(wasde_metric_alias_map)) {
      metric_id <- unname(wasde_metric_alias_map[[metric_id]])
    }

    if (!(metric_id %in% wasde_metric_catalog$metric_id)) {
      return(NULL)
    }

    metric_id
  }

  wasde_metric_label_for_code <- function(metric_code) {
    metric_id <- normalize_wasde_metric_id(metric_code)
    if (!is.null(metric_id)) {
      metric_label <- unname(wasde_metric_label_lookup[[metric_id]])
      if (length(metric_label) == 1L && !is.na(metric_label) && nzchar(metric_label)) {
        return(metric_label)
      }
    }

    fallback_code <- trimws(as.character(metric_code))
    fallback_code <- fallback_code[!is.na(fallback_code) & nzchar(fallback_code)]
    if (length(fallback_code) == 0L) {
      return("WASDE Metric")
    }

    stringr::str_to_title(gsub("_", " ", gsub("^wasde_", "", fallback_code[[1L]])))
  }

  wasde_metric_unit_for_code <- function(metric_code, default = "WASDE Unit") {
    metric_id <- normalize_wasde_metric_id(metric_code)
    if (is.null(metric_id)) {
      return(default)
    }

    if (metric_id %in% names(wasde_metric_canonical_unit_overrides)) {
      return(unname(wasde_metric_canonical_unit_overrides[[metric_id]]))
    }

    metric_unit <- unname(wasde_metric_unit_lookup[[metric_id]])
    if (length(metric_unit) == 1L && !is.na(metric_unit) && nzchar(metric_unit)) {
      return(metric_unit)
    }

    default
  }

  normalize_wasde_canonical_unit_label <- function(metric_code) {
    tolower(trimws(wasde_metric_unit_for_code(metric_code, default = "")))
  }

  wasde_metric_family_for_code <- function(metric_code) {
    metric_id <- normalize_wasde_metric_id(metric_code)
    if (!is.null(metric_id) && identical(metric_id, "stocks_to_use_ratio")) {
      return("percent")
    }

    canonical_unit <- normalize_wasde_canonical_unit_label(metric_code)

    if (!nzchar(canonical_unit)) {
      return("native")
    }

    if (canonical_unit %in% c("million hundredweight", "million bushels")) {
      return("quantity")
    }

    if (canonical_unit == "million acres") {
      return("area")
    }

    if (canonical_unit == "pounds per acre") {
      return("yield")
    }

    if (canonical_unit == "million dollars") {
      return("dollar_total")
    }

    if (startsWith(canonical_unit, "dollars per")) {
      return("dollar_rate")
    }

    if (grepl("percent|ratio", canonical_unit)) {
      return("percent")
    }

    "native"
  }

  is_wasde_quantity_metric <- function(metric_code) {
    identical(wasde_metric_family_for_code(metric_code), "quantity")
  }

  is_wasde_area_metric <- function(metric_code) {
    identical(wasde_metric_family_for_code(metric_code), "area")
  }

  is_wasde_yield_metric <- function(metric_code) {
    identical(wasde_metric_family_for_code(metric_code), "yield")
  }

  is_wasde_dollar_total_metric <- function(metric_code) {
    identical(wasde_metric_family_for_code(metric_code), "dollar_total")
  }

  is_wasde_dollar_rate_metric <- function(metric_code) {
    identical(wasde_metric_family_for_code(metric_code), "dollar_rate")
  }

  is_wasde_locked_control_metric <- function(metric_code) {
    metric_id <- normalize_wasde_metric_id(metric_code)
    !is.null(metric_id) && metric_id %in% c("loan_rate", "milling_rate")
  }

  is_wasde_basis_metric <- function(metric_code) {
    is_wasde_quantity_metric(metric_code)
  }

  is_wasde_value_metric <- function(metric_code, source_choice = current_source_choice_safe()) {
    identical(source_choice, "wasde") && !is_wasde_locked_control_metric(metric_code) && (
      is_wasde_dollar_total_metric(metric_code) ||
        is_wasde_dollar_rate_metric(metric_code)
    )
  }

  is_wasde_visible_metric <- function(metric_code) {
    metric_id <- normalize_wasde_metric_id(metric_code)
    !is.null(metric_id) && metric_id %in% unname(wasde_metric_choices)
  }

  is_wasde_price_lock_metric <- function(metric_code) {
    is_wasde_visible_metric(metric_code) &&
      is_wasde_dollar_rate_metric(metric_code) &&
      !is_wasde_locked_control_metric(metric_code)
  }

  is_wasde_yield_lock_metric <- function(metric_code) {
    is_wasde_visible_metric(metric_code) && is_wasde_yield_metric(metric_code)
  }

  wasde_lock_context_allows_metric_lock <- function(lock_context = "selected_metric") {
    context_value <- trimws(as.character(lock_context %||% "selected_metric"))
    context_value <- context_value[!is.na(context_value) & nzchar(context_value)]
    if (length(context_value) == 0L) {
      context_value <- "selected_metric"
    } else {
      context_value <- context_value[[1L]]
    }

    context_value %in% c("selected_metric", "mixed_row", "historical_row")
  }

  wasde_control_profile <- function(metric_code = NULL) {
    hidden_profile <- list(show_quantity = FALSE, show_area = FALSE, show_basis = FALSE, show_value = FALSE)

    if (is_wasde_locked_control_metric(metric_code)) {
      return(hidden_profile)
    }

    metric_family <- wasde_metric_family_for_code(metric_code)

    switch(
      metric_family,
      "quantity" = list(show_quantity = TRUE, show_area = FALSE, show_basis = TRUE, show_value = FALSE),
      "area" = list(show_quantity = FALSE, show_area = TRUE, show_basis = FALSE, show_value = FALSE),
      "yield" = list(show_quantity = TRUE, show_area = TRUE, show_basis = FALSE, show_value = FALSE),
      "dollar_total" = list(show_quantity = FALSE, show_area = FALSE, show_basis = FALSE, show_value = TRUE),
      "dollar_rate" = list(show_quantity = TRUE, show_area = FALSE, show_basis = FALSE, show_value = TRUE),
      hidden_profile
    )
  }

  default_wasde_unit_choice_for_metric <- function(metric_code = NULL) {
    metric_family <- wasde_metric_family_for_code(metric_code)
    canonical_unit <- normalize_wasde_canonical_unit_label(metric_code)

    if (identical(metric_family, "quantity")) {
      return("million_cwt")
    }

    if (identical(metric_family, "yield")) {
      return("lbs")
    }

    if (identical(metric_family, "dollar_rate")) {
      if (grepl("bushel", canonical_unit, fixed = TRUE)) {
        return("bushels")
      }

      if (grepl("short ton", canonical_unit, fixed = TRUE)) {
        return("us_tons")
      }

      if (grepl("hundredweight|cwt", canonical_unit)) {
        return("cwt")
      }

      if (grepl("pound", canonical_unit, fixed = TRUE)) {
        return("lbs")
      }
    }

    "lbs"
  }

  wasde_unit_choices_for_metric <- function(metric_code = NULL) {
    profile <- wasde_control_profile(metric_code)
    if (isTRUE(profile$show_quantity)) {
      return(wasde_quantity_unit_choices)
    }

    stats::setNames("cwt", wasde_metric_unit_for_code(metric_code, default = "WASDE Unit"))
  }

  psd_area_unit_choices <- c(
    "1000 Hectares" = "thousand_ha",
    "Hectares (HA)" = "ha",
    "1000 Acres" = "thousand_ac",
    "Acres (AC)" = "ac"
  )

  is_psd_area_metric <- function(metric_code) {
    identical(metric_code, "psd_area_harvested")
  }

  is_psd_yield_metric <- function(metric_code) {
    identical(metric_code, "psd_yield")
  }

  is_psd_milling_rate_metric <- function(metric_code) {
    identical(metric_code, "psd_milling_rate")
  }

  is_psd_quantity_metric <- function(metric_code) {
    !is_psd_area_metric(metric_code) &&
      !is_psd_yield_metric(metric_code) &&
      !is_psd_milling_rate_metric(metric_code)
  }

  is_census_value_metric <- function(metric_code, source_choice = current_source_choice_safe()) {
    if (!(source_choice %in% c("census", "vp_trade")) || is.null(metric_code) || length(metric_code) == 0L) {
      return(FALSE)
    }

    metric_code <- trimws(as.character(metric_code[[1]]))
    !is.na(metric_code) && metric_code %in% census_value_metric_codes
  }

  nass_metric_family_for_code <- function(metric_code) {
    metric_id <- normalize_nass_metric_id(metric_code)
    switch(
      metric_id,
      "acres_bearing" = "area",
      "production_shelled_lb" = "quantity",
      "yield" = "yield",
      "production_shelled_value" = "value_total",
      "price_received_per_lb" = "price_rate",
      "shellout_factor" = "ratio",
      "native"
    )
  }

  is_nass_area_metric <- function(metric_code) {
    identical(nass_metric_family_for_code(metric_code), "area")
  }

  is_nass_quantity_metric <- function(metric_code) {
    identical(nass_metric_family_for_code(metric_code), "quantity")
  }

  is_nass_yield_metric <- function(metric_code) {
    identical(nass_metric_family_for_code(metric_code), "yield")
  }

  is_nass_value_metric <- function(metric_code) {
    identical(nass_metric_family_for_code(metric_code), "value_total")
  }

  is_nass_price_rate_metric <- function(metric_code) {
    identical(nass_metric_family_for_code(metric_code), "price_rate")
  }

  is_nass_yield_lock_metric <- function(metric_code) {
    metric_values <- trimws(as.character(metric_code %||% ""))
    metric_values <- metric_values[!is.na(metric_values) & nzchar(metric_values)]
    length(metric_values) > 0L && metric_values[[1L]] %in% c("nass_yield_may_estimate", "nass_yield")
  }

  is_nass_price_lock_metric <- function(metric_code) {
    metric_values <- trimws(as.character(metric_code %||% ""))
    metric_values <- metric_values[!is.na(metric_values) & nzchar(metric_values)]
    length(metric_values) > 0L && identical(metric_values[[1L]], "nass_price_received_per_lb")
  }

  is_nass_basis_metric <- function(metric_code) {
    is_nass_quantity_metric(metric_code) || is_nass_yield_metric(metric_code) || is_nass_price_rate_metric(metric_code)
  }

  nass_control_profile <- function(metric_code = effective_main_metric(), source_choice = current_source_choice_safe()) {
    hidden_profile <- list(show_quantity = FALSE, show_area = FALSE, show_basis = FALSE, show_value = FALSE)
    if (!identical(source_choice, "nass")) {
      return(hidden_profile)
    }

    switch(
      nass_metric_family_for_code(metric_code),
      "quantity" = list(show_quantity = TRUE, show_area = FALSE, show_basis = TRUE, show_value = FALSE),
      "yield" = list(show_quantity = TRUE, show_area = TRUE, show_basis = TRUE, show_value = FALSE),
      "area" = list(show_quantity = FALSE, show_area = TRUE, show_basis = FALSE, show_value = FALSE),
      "value_total" = list(show_quantity = FALSE, show_area = FALSE, show_basis = FALSE, show_value = TRUE),
      "price_rate" = list(show_quantity = TRUE, show_area = FALSE, show_basis = TRUE, show_value = TRUE),
      hidden_profile
    )
  }

  nass_rate_numerator_unit_choices <- c(
    "Cents" = "cents",
    "Dollars" = "dollars"
  )

  default_census_value_unit_choice <- function() {
    "thousand_dollars"
  }

  default_wasde_value_unit_choice <- function(metric_code = NULL) {
    if (is_wasde_dollar_rate_metric(metric_code)) {
      return("dollars")
    }

    "million_dollars"
  }

  default_value_unit_choice_for_context <- function(
    source_choice = current_source_choice_safe(),
    metric_code = effective_main_metric()
  ) {
    if (identical(source_choice, "wasde")) {
      return(default_wasde_value_unit_choice(metric_code))
    }

    if (identical(source_choice, "nass") && is_nass_price_rate_metric(metric_code)) {
      return("cents")
    }

    if (identical(source_choice, "nass") && is_nass_value_metric(metric_code)) {
      return("thousand_dollars")
    }

    default_census_value_unit_choice()
  }

  value_unit_choices_for_context <- function(
    source_choice = current_source_choice_safe(),
    metric_code = effective_main_metric()
  ) {
    if (identical(source_choice, "wasde")) {
      return(census_value_unit_choices)
    }

    if (identical(source_choice, "nass") && is_nass_price_rate_metric(metric_code)) {
      return(nass_rate_numerator_unit_choices)
    }

    if (identical(source_choice, "nass") && is_nass_value_metric(metric_code)) {
      return(census_value_unit_choices)
    }

    census_value_unit_choices
  }

  resolve_census_value_unit_choice <- function(
    value_unit_choice,
    default = default_census_value_unit_choice(),
    source_choice = current_source_choice_safe(),
    metric_code = effective_main_metric()
  ) {
    valid_choices <- unname(value_unit_choices_for_context(source_choice, metric_code))

    if (!is.null(value_unit_choice) && length(value_unit_choice) > 0L) {
      value_unit_choice <- trimws(as.character(value_unit_choice[[1]]))
      if (!is.na(value_unit_choice) && nzchar(value_unit_choice) && value_unit_choice %in% valid_choices) {
        return(value_unit_choice)
      }
    }

    default
  }

  value_unit_state_key_for_source <- function(source_choice = current_source_choice_safe()) {
    if (identical(source_choice, "wasde")) {
      return("wasde_value_unit_choice_state")
    }

    if (identical(source_choice, "nass")) {
      return("nass_value_unit_choice_state")
    }

    "census_value_unit_choice_state"
  }

  read_remembered_value_unit_choice <- function(source_choice = current_source_choice_safe()) {
    key <- value_unit_state_key_for_source(source_choice)
    session$userData[[key]]
  }

  write_remembered_value_unit_choice <- function(value_unit_choice, source_choice = current_source_choice_safe()) {
    key <- value_unit_state_key_for_source(source_choice)
    session$userData[[key]] <- value_unit_choice

    if (identical(source_choice, "wasde")) {
      session$userData$wasde_value_unit_metric_scope <- effective_main_metric()
    } else if (identical(source_choice, "nass")) {
      session$userData$nass_value_unit_metric_scope <- effective_main_metric()
    }
  }

  current_census_value_unit_choice_safe <- function(
    default = default_value_unit_choice_for_context(),
    source_choice = current_source_choice_safe(),
    metric_code = effective_main_metric()
  ) {
    tryCatch({
      resolved_default <- resolve_census_value_unit_choice(
        default,
        default = default_value_unit_choice_for_context(source_choice, metric_code),
        source_choice = source_choice,
        metric_code = metric_code
      )
      value_unit_choice <- input$value_unit_choice
      remembered_value <- read_remembered_value_unit_choice(source_choice)
      valid_choices <- unname(value_unit_choices_for_context(source_choice, metric_code))
      wasde_metric_scope <- session$userData$wasde_value_unit_metric_scope
      nass_metric_scope <- session$userData$nass_value_unit_metric_scope
      input_matches_metric_scope <- if (identical(source_choice, "wasde")) {
        identical(wasde_metric_scope, metric_code)
      } else if (identical(source_choice, "nass")) {
        identical(nass_metric_scope, metric_code)
      } else {
        TRUE
      }

      if (!is.null(value_unit_choice) && nzchar(value_unit_choice) && value_unit_choice %in% valid_choices && input_matches_metric_scope) {
        return(value_unit_choice)
      }

      if (!is.null(remembered_value) && nzchar(remembered_value) && remembered_value %in% valid_choices && input_matches_metric_scope) {
        return(remembered_value)
      }

      resolved_default
    }, error = function(...) default)
  }

  census_value_unit_cache_key <- function(
    source_choice = current_source_choice_safe(),
    metric_code = effective_main_metric()
  ) {
    if (is_census_value_metric(metric_code, source_choice) || is_wasde_value_metric(metric_code, source_choice)) {
      return(current_census_value_unit_choice_safe(source_choice = source_choice, metric_code = metric_code))
    }

    "n/a"
  }

  value_unit_conversion <- function(
    value,
    value_unit_choice = default_census_value_unit_choice(),
    source_choice = current_source_choice_safe(),
    metric_code = effective_main_metric()
  ) {
    value_unit_choice <- resolve_census_value_unit_choice(
      value_unit_choice,
      default = default_value_unit_choice_for_context(source_choice, metric_code),
      source_choice = source_choice,
      metric_code = metric_code
    )
    dollar_values <- suppressWarnings(as.numeric(value))

    divisor <- switch(
      value_unit_choice,
      "native_dollars" = 1,
      "billion_dollars" = 1000000000,
      "million_dollars" = 1000000,
      "thousand_dollars" = 1000,
      "dollars" = 1,
      1000
    )

    sanitize_numeric(dollar_values / divisor)
  }

  get_value_unit_label <- function(
    value_unit_choice = default_census_value_unit_choice(),
    source_choice = current_source_choice_safe(),
    metric_code = effective_main_metric()
  ) {
    value_unit_choice <- resolve_census_value_unit_choice(
      value_unit_choice,
      default = default_value_unit_choice_for_context(source_choice, metric_code),
      source_choice = source_choice,
      metric_code = metric_code
    )
    active_choices <- value_unit_choices_for_context(source_choice, metric_code)
    label <- names(active_choices)[match(value_unit_choice, unname(active_choices))]

    if (length(label) == 1L && !is.na(label) && nzchar(label)) {
      return(label)
    }

    if (identical(source_choice, "wasde")) {
      "Million Dollars"
    } else {
      "1000 Dollars"
    }
  }

  is_psd_time_series_tool_active <- function(
    source_choice = current_source_choice_safe(),
    active_tab = current_main_tab_safe()
  ) {
    identical(source_choice, "psd") && identical(active_tab, "Time Series Analysis Tool")
  }

  psd_time_series_control_profile <- function(
    metric_code = effective_main_metric(),
    source_choice = current_source_choice_safe(),
    active_tab = current_main_tab_safe()
  ) {
    if (!is_psd_time_series_tool_active(source_choice, active_tab)) {
      return(NULL)
    }

    if (is_psd_area_metric(metric_code)) {
      return(list(show_quantity = FALSE, show_area = TRUE, show_basis = FALSE))
    }

    if (is_psd_milling_rate_metric(metric_code)) {
      return(list(show_quantity = FALSE, show_area = FALSE, show_basis = FALSE))
    }

    if (is_psd_yield_metric(metric_code)) {
      return(list(show_quantity = TRUE, show_area = TRUE, show_basis = TRUE))
    }

    list(show_quantity = TRUE, show_area = FALSE, show_basis = TRUE)
  }

  is_psd_non_share_metric <- function(metric_code = NULL, source_choice = NULL) {
    active_source_choice <- if (!is.null(source_choice)) {
      source_choice
    } else {
      current_source_choice_safe(default = NULL)
    }

    identical(active_source_choice, "psd") &&
      (is_psd_yield_metric(metric_code %||% NULL) || is_psd_milling_rate_metric(metric_code %||% NULL))
  }

  current_psd_area_unit_choice_safe <- function(
    default = "thousand_ha",
    source_choice = current_source_choice_safe(),
    metric_code = effective_main_metric()
  ) {
    tryCatch({
      area_unit_choice <- input$psd_area_unit_choice
      state_key <- if (identical(source_choice, "nass")) "nass_area_unit_choice_state" else "psd_area_unit_choice_state"
      metric_scope_key <- if (identical(source_choice, "nass")) "nass_area_unit_metric_scope" else NULL
      input_matches_scope <- is.null(metric_scope_key) || identical(session$userData[[metric_scope_key]], metric_code)

      if (!is.null(area_unit_choice) && nzchar(area_unit_choice) && area_unit_choice %in% unname(psd_area_unit_choices) && input_matches_scope) {
        area_unit_choice
      } else {
        remembered_value <- session$userData[[state_key]]
        if (!is.null(remembered_value) && nzchar(remembered_value) && remembered_value %in% unname(psd_area_unit_choices)) {
          remembered_value
        } else {
          default
        }
      }
    }, error = function(...) default)
  }

  current_psd_quantity_unit_choice_safe <- function(
    default = "thousand_mt",
    metric_code = effective_main_metric(),
    source_choice = current_source_choice_safe()
  ) {
    tryCatch({
      valid_choices <- unname(unit_choices_for_context(source_choice, metric_code))
      unit_choice <- input$unit_choice
      remembered_value <- session$userData$psd_quantity_unit_choice_state
      input_scope <- session$userData$unit_choice_input_scope
      has_remembered_value <- !is.null(remembered_value) && nzchar(remembered_value)
      input_has_valid_value <- !is.null(unit_choice) && nzchar(unit_choice) && unit_choice %in% valid_choices
      input_matches_source_scope <- if (identical(source_choice, "psd")) {
        identical(input_scope, "psd")
      } else {
        TRUE
      }
      transition_state <- if (identical(source_choice, "psd")) current_psd_source_transition_state() else NULL

      if (
        !is.null(transition_state) &&
        !is.null(transition_state$unit) &&
        nzchar(transition_state$unit) &&
        transition_state$unit %in% valid_choices
      ) {
        return(transition_state$unit)
      }

      if (input_has_valid_value && input_matches_source_scope) {
        return(unit_choice)
      }

      if (identical(source_choice, "psd") && has_remembered_value && remembered_value %in% valid_choices) {
        return(remembered_value)
      }

      if (has_remembered_value && remembered_value %in% valid_choices) {
        return(remembered_value)
      }

      if (!identical(source_choice, "psd") && !is.null(unit_choice) && nzchar(unit_choice) && unit_choice %in% valid_choices) {
        return(unit_choice)
      }

      default
    }, error = function(...) default)
  }

  current_psd_yield_lock_input_safe <- function(default = TRUE) {
    tryCatch({
      lock_value <- input$psd_yield_lock_rough_eq
      if (is.null(lock_value) || length(lock_value) == 0) {
        remembered_value <- session$userData$psd_yield_lock_state
        if (is.null(remembered_value) || length(remembered_value) == 0) default else isTRUE(remembered_value)
      } else {
        isTRUE(lock_value)
      }
    }, error = function(...) default)
  }

  psd_yield_lock_active_for_metric <- function(
    metric_code = effective_main_metric(),
    source_choice = current_source_choice_safe()
  ) {
    identical(source_choice, "psd") &&
      !is_psd_time_series_tool_active(source_choice) &&
      identical(metric_code, "psd_yield") &&
      isTRUE(current_psd_yield_lock_input_safe())
  }

  current_wasde_metric_lock_input_safe <- function(input_id, state_key, default = TRUE) {
    tryCatch({
      lock_value <- input[[input_id]]
      if (is.null(lock_value) || length(lock_value) == 0) {
        remembered_value <- session$userData[[state_key]]
        if (is.null(remembered_value) || length(remembered_value) == 0) default else isTRUE(remembered_value)
      } else {
        isTRUE(lock_value)
      }
    }, error = function(...) default)
  }

  current_wasde_price_lock_input_safe <- function(default = TRUE) {
    current_wasde_metric_lock_input_safe(
      input_id = "wasde_price_lock_native_rate",
      state_key = "wasde_price_lock_state",
      default = default
    )
  }

  current_wasde_yield_lock_input_safe <- function(default = TRUE) {
    current_wasde_metric_lock_input_safe(
      input_id = "wasde_yield_lock_rough_eq",
      state_key = "wasde_yield_lock_state",
      default = default
    )
  }

  wasde_price_lock_active_for_metric <- function(
    metric_code = effective_main_metric(),
    source_choice = current_source_choice_safe()
  ) {
    identical(source_choice, "wasde") &&
      is_wasde_price_lock_metric(metric_code) &&
      isTRUE(current_wasde_price_lock_input_safe())
  }

  wasde_yield_lock_active_for_metric <- function(
    metric_code = effective_main_metric(),
    source_choice = current_source_choice_safe()
  ) {
    identical(source_choice, "wasde") &&
      is_wasde_yield_lock_metric(metric_code) &&
      isTRUE(current_wasde_yield_lock_input_safe())
  }

  wasde_price_lock_label <- function(metric_code) {
    denominator_label <- tryCatch(get_unit_label(default_wasde_unit_choice_for_metric(metric_code)), error = function(...) "WASDE native rate")
    if (!is.null(denominator_label) && length(denominator_label) > 0L && nzchar(denominator_label[[1L]])) {
      return(paste0("Lock price unit to Dollars per ", denominator_label[[1L]]))
    }

    "Lock price unit to WASDE native rate"
  }

  wasde_yield_lock_label <- function() {
    "Lock Yield to Pounds/AC and Rough-equivalent"
  }

  current_nass_metric_lock_input_safe <- function(input_id, state_key, default = TRUE) {
    tryCatch({
      lock_value <- input[[input_id]]
      if (is.null(lock_value) || length(lock_value) == 0) {
        remembered_value <- session$userData[[state_key]]
        if (is.null(remembered_value) || length(remembered_value) == 0) default else isTRUE(remembered_value)
      } else {
        isTRUE(lock_value)
      }
    }, error = function(...) default)
  }

  current_nass_yield_lock_input_safe <- function(default = TRUE) {
    current_nass_metric_lock_input_safe(
      input_id = "nass_yield_lock_enabled",
      state_key = "nass_yield_lock_state",
      default = default
    )
  }

  current_nass_price_lock_input_safe <- function(default = TRUE) {
    current_nass_metric_lock_input_safe(
      input_id = "nass_price_lock_enabled",
      state_key = "nass_price_lock_state",
      default = default
    )
  }

  nass_yield_lock_active_for_metric <- function(
    metric_code = effective_main_metric(),
    source_choice = current_source_choice_safe()
  ) {
    identical(source_choice, "nass") &&
      is_nass_yield_lock_metric(metric_code) &&
      isTRUE(current_nass_yield_lock_input_safe())
  }

  nass_price_lock_active_for_metric <- function(
    metric_code = effective_main_metric(),
    source_choice = current_source_choice_safe()
  ) {
    identical(source_choice, "nass") &&
      is_nass_price_lock_metric(metric_code) &&
      isTRUE(current_nass_price_lock_input_safe())
  }

  nass_yield_lock_targets <- function(metric_code) {
    if (identical(trimws(as.character(metric_code %||% "")), "nass_yield_may_estimate")) {
      return(list(unit_choice = "us_tons", area_unit_choice = "ac", basis_choice = "inshell_eq", value_unit_choice = "n/a"))
    }

    list(unit_choice = "lbs", area_unit_choice = "ac", basis_choice = "shelled_eq", value_unit_choice = "n/a")
  }

  nass_price_lock_targets <- function(metric_code) {
    list(unit_choice = "lbs", area_unit_choice = "n/a", basis_choice = "shelled_eq", value_unit_choice = "dollars")
  }

  nass_yield_lock_label <- function(metric_code) {
    target <- nass_yield_lock_targets(metric_code)
    paste0(
      "Lock Yield to ",
      get_unit_label(target$unit_choice),
      "/",
      get_unit_label(target$area_unit_choice),
      " and ",
      get_basis_label(target$basis_choice)
    )
  }

  nass_price_lock_label <- function(metric_code) {
    target <- nass_price_lock_targets(metric_code)
    paste0(
      "Lock price unit to ",
      get_value_unit_label(target$value_unit_choice, source_choice = "nass", metric_code = metric_code),
      " per ",
      get_unit_label(target$unit_choice),
      ", ",
      get_basis_label(target$basis_choice)
    )
  }

  nass_effective_conversion_controls <- function(
    metric_code,
    source_choice = current_source_choice_safe(),
    unit_choice = current_unit_choice_safe(default = default_unit_choice_for_context(source_choice, metric_code)),
    area_unit_choice = current_psd_area_unit_choice_safe(default_nass_area_unit_choice_for_metric(metric_code)),
    basis_choice = current_basis_choice_safe(),
    value_unit_choice = current_census_value_unit_choice_safe(source_choice = source_choice, metric_code = metric_code),
    lock_context = "selected_metric"
  ) {
    out <- list(
      unit_choice = unit_choice,
      area_unit_choice = area_unit_choice,
      basis_choice = basis_choice,
      value_unit_choice = value_unit_choice,
      price_locked = FALSE,
      yield_locked = FALSE
    )

    if (!identical(source_choice, "nass")) {
      return(out)
    }

    if (!isTRUE(wasde_lock_context_allows_metric_lock(lock_context))) {
      return(out)
    }

    if (nass_yield_lock_active_for_metric(metric_code, source_choice)) {
      target <- nass_yield_lock_targets(metric_code)
      out$unit_choice <- target$unit_choice
      out$area_unit_choice <- target$area_unit_choice
      out$basis_choice <- target$basis_choice
      out$yield_locked <- TRUE
    }

    if (nass_price_lock_active_for_metric(metric_code, source_choice)) {
      target <- nass_price_lock_targets(metric_code)
      out$unit_choice <- target$unit_choice
      out$value_unit_choice <- target$value_unit_choice
      out$basis_choice <- target$basis_choice
      out$price_locked <- TRUE
    }

    out
  }

  wasde_effective_conversion_controls <- function(
    metric_code,
    source_choice = current_source_choice_safe(),
    unit_choice = current_unit_choice_safe(default = default_unit_choice_for_context(source_choice, metric_code)),
    area_unit_choice = current_psd_area_unit_choice_safe(),
    basis_choice = current_basis_choice_safe(),
    value_unit_choice = current_census_value_unit_choice_safe(source_choice = source_choice, metric_code = metric_code),
    lock_context = "selected_metric"
  ) {
    out <- list(
      unit_choice = unit_choice,
      area_unit_choice = area_unit_choice,
      basis_choice = basis_choice,
      value_unit_choice = value_unit_choice,
      price_locked = FALSE,
      yield_locked = FALSE
    )

    if (!identical(source_choice, "wasde")) {
      return(out)
    }

    if (!isTRUE(wasde_lock_context_allows_metric_lock(lock_context))) {
      return(out)
    }

    if (wasde_price_lock_active_for_metric(metric_code, source_choice)) {
      out$unit_choice <- default_wasde_unit_choice_for_metric(metric_code)
      out$value_unit_choice <- "dollars"
      out$basis_choice <- "rough_eq"
      out$price_locked <- TRUE
    }

    if (wasde_yield_lock_active_for_metric(metric_code, source_choice)) {
      out$unit_choice <- "lbs"
      out$area_unit_choice <- "ac"
      out$basis_choice <- "rough_eq"
      out$yield_locked <- TRUE
    }

    out
  }

  current_psd_time_series_basis_choice_safe <- function(
    metric_code = effective_main_metric(),
    commodity_name = if (!is.null(input$commodity_choice)) input$commodity_choice else default_commodity_choice_value()
  ) {
    if (!identical(current_source_choice_safe(), "psd")) {
      return(current_basis_choice_safe(default = default_basis_for_commodity(commodity_name)))
    }

    if (!is_psd_time_series_tool_active()) {
      return(effective_basis_choice_for_metric(
        metric_code,
        current_basis_choice_safe(default = default_basis_for_commodity(commodity_name)),
        "psd"
      ))
    }

    profile <- psd_time_series_control_profile(metric_code, "psd", "Time Series Analysis Tool")
    if (!isTRUE(profile$show_basis)) {
      return(default_basis_for_commodity(commodity_name))
    }

    resolve_basis_choice(
      commodity_name,
      current_basis_choice_safe(default = default_basis_for_commodity(commodity_name)),
      active_tab = "Time Series Analysis Tool",
      source_choice = "psd"
    )
  }

  effective_basis_choice_for_metric <- function(
    metric_code,
    basis_choice = NULL,
    source_choice = "export_sales"
  ) {
    if (psd_yield_lock_active_for_metric(metric_code, source_choice)) {
      return("rough_eq")
    }

    basis_choice
  }

  apply_psd_yield_lock_to_df <- function(
    df,
    metric_code = effective_main_metric(),
    source_choice = current_source_choice_safe(),
    unit_choice = current_unit_choice_safe(default = "thousand_mt"),
    area_unit_choice = current_psd_area_unit_choice_safe()
  ) {
      if (!isTRUE(psd_yield_lock_active_for_metric(metric_code, source_choice))) {
      return(df)
    }

    if (is.null(df) || !is.data.frame(df) || nrow(df) == 0 || !"psd_yield" %in% names(df) || !"psd_yield_rough_eq" %in% names(rice_data_psd_marketing_year)) {
      return(df)
    }

    join_cols <- c("country", "commodity", "market_year", "analysis_month", "release_year", "release_month", "release_period")
    join_cols <- join_cols[join_cols %in% names(df) & join_cols %in% names(rice_data_psd_marketing_year)]
    if (length(join_cols) == 0) {
      return(df)
    }

    native_yield_source <- rice_data_psd_marketing_year %>%
        select(all_of(join_cols), psd_yield_rough_eq) %>%
      mutate(
        psd_yield_locked = unit_conversion(
          .data$psd_yield_rough_eq,
          unit_choice,
          source_choice = "psd",
          metric_code = "psd_yield",
          area_unit_choice = area_unit_choice
        )
      ) %>%
      select(-psd_yield_rough_eq)

    df %>%
      left_join(native_yield_source, by = join_cols) %>%
      mutate(psd_yield = dplyr::coalesce(.data$psd_yield_locked, .data$psd_yield)) %>%
      select(-any_of("psd_yield_locked"))
  }

  default_metric_for_source <- function(source_choice = current_source_choice_safe()) {
    if (identical(source_choice, "psd")) {
      return("psd_production")
    }

    if (identical(source_choice, "wasde")) {
      return("qty_of_exports")
    }

    if (identical(source_choice, "nass")) {
      return("nass_production_shelled_lb")
    }

    "ytd_exports"
  }

  default_nass_area_unit_choice_for_metric <- function(metric_code = effective_main_metric()) {
    if (is_nass_yield_metric(metric_code)) {
      return("ac")
    }

    "thousand_ac"
  }

  unit_choices_for_context <- function(
    source_choice = current_source_choice_safe(),
    metric_code = NULL
  ) {
    if (identical(source_choice, "psd")) {
      return(psd_quantity_unit_choices)
    }

    if (identical(source_choice, "vp_trade")) {
      return(vp_trade_quantity_unit_choices_for_context(metric_code = metric_code))
    }

    if (identical(source_choice, "wasde")) {
      return(wasde_unit_choices_for_metric(metric_code))
    }

    if (identical(source_choice, "nass")) {
      return(standard_quantity_unit_choices)
    }

    standard_quantity_unit_choices
  }

  default_unit_choice_for_context <- function(
    source_choice = current_source_choice_safe(),
    metric_code = NULL
  ) {
    if (identical(source_choice, "psd")) {
      return("us_tons")
    }

    if (identical(source_choice, "wasde")) {
      return(default_wasde_unit_choice_for_metric(metric_code))
    }

    if (identical(source_choice, "nass")) {
      if (is_nass_quantity_metric(metric_code)) {
        return("us_tons")
      }

      if (is_nass_yield_metric(metric_code)) {
        return("lbs")
      }

      if (is_nass_price_rate_metric(metric_code)) {
        return("lbs")
      }

      return("mil_lbs")
    }

    if (identical(source_choice, "vp_trade")) {
      vp_default <- vp_trade_default_quantity_unit_for_context(metric_code = metric_code)
      if (!is.null(vp_default) && nzchar(vp_default)) {
        return(vp_default)
      }

      return("thousand_lbs")
    }

    "us_tons"
  }

  resolve_psd_metric_defaults <- function(metric_code) {
    if (identical(metric_code, "psd_yield")) {
      return(list(
        unit_choice = default_unit_choice_for_context("psd", metric_code),
        basis_choice = psd_default_basis_choice(),
        area_unit_choice = "thousand_ha"
      ))
    }

    list(
      unit_choice = default_unit_choice_for_context("psd", metric_code),
      basis_choice = psd_default_basis_choice(),
      area_unit_choice = "thousand_ha"
    )
  }

  resolve_unit_choice <- function(
    unit_choice,
    source_choice = current_source_choice_safe(),
    metric_code = NULL
  ) {
    valid_choices <- unname(unit_choices_for_context(source_choice, metric_code))

    if (!is.null(unit_choice) && unit_choice %in% valid_choices) {
      return(unit_choice)
    }

    default_unit_choice_for_context(source_choice, metric_code)
  }

  show_psd_area_unit_choice <- function(
    source_choice = current_source_choice_safe(),
    metric_code = NULL
  ) {
      if (identical(source_choice, "wasde")) {
        return(TRUE)
      }

      if (identical(source_choice, "nass")) {
        return(TRUE)
      }

      profile <- psd_time_series_control_profile(metric_code, source_choice)
      if (!is.null(profile)) {
        return(isTRUE(profile$show_area))
      }

      identical(source_choice, "psd")
  }

  show_quantity_unit_choice <- function(
    source_choice = current_source_choice_safe(),
    metric_code = NULL
  ) {
      if (identical(source_choice, "vp_trade")) {
        if (!isTRUE(vp_trade_metric_supports_quantity_units(metric_code))) {
          return(FALSE)
        }

        return(is.null(vp_trade_quantity_unit_unavailable_reason(source_choice = source_choice, metric_code = metric_code)))
      }

      if (identical(source_choice, "vp_trade") && metric_code %in% c("unit_value", "ytd_unit_value")) {
        return(FALSE)
      }

      if (identical(source_choice, "wasde")) {
        return(TRUE)
      }

      if (identical(source_choice, "nass")) {
        return(TRUE)
      }

      profile <- psd_time_series_control_profile(metric_code, source_choice)
      if (!is.null(profile)) {
        return(isTRUE(profile$show_quantity))
      }

      if (is_census_value_metric(metric_code, source_choice)) {
        return(FALSE)
      }

      TRUE
  }

  show_basis_choice <- function(
    source_choice = current_source_choice_safe(),
    metric_code = NULL
  ) {
      if (identical(source_choice, "vp_trade")) {
        return(FALSE)
      }

      if (identical(source_choice, "wasde")) {
        return(TRUE)
      }

      if (identical(source_choice, "nass")) {
        return(TRUE)
      }

      profile <- psd_time_series_control_profile(metric_code, source_choice)
      if (!is.null(profile)) {
        return(isTRUE(profile$show_basis))
      }

      if (is_census_value_metric(metric_code, source_choice)) {
        return(FALSE)
      }

      TRUE
  }

  show_value_unit_choice <- function(
    source_choice = current_source_choice_safe(),
    metric_code = NULL
  ) {
      if (identical(source_choice, "wasde")) {
        return(TRUE)
      }

      if (identical(source_choice, "nass")) {
        return(TRUE)
      }

      profile <- psd_time_series_control_profile(metric_code, source_choice)
      if (!is.null(profile)) {
        return(FALSE)
      }

      is_census_value_metric(metric_code, source_choice)
  }

  projection_metric_choices_for_source <- function(source_choice = current_source_choice_safe()) {
    if (identical(source_choice, "psd")) {
      return(unname(psd_metric_choices))
    }

    if (identical(source_choice, "wasde")) {
      return(unname(wasde_metric_choices))
    }

    if (identical(source_choice, "nass")) {
      return(unname(nass_metric_choices))
    }

    if (identical(source_choice, "vp_trade")) {
      return(c("ytd_exports", "ytd_value"))
    }

    c("ytd_exports", "total_commitment")
  }

  runtime_default_source_choice <- function(default = "vp_trade") {
    if (exists("startup_default_ui_source", mode = "function")) {
      contract_default <- startup_default_ui_source(default = "vp_trade")
      contract_default <- trimws(as.character(contract_default %||% ""))
      if (length(contract_default) > 0L && nzchar(contract_default[[1L]])) {
        return(contract_default[[1L]])
      }
    }

    default %||% "vp_trade"
  }

  runtime_visible_source_values <- function() {
    if (exists("startup_ui_source_values", mode = "function")) {
      source_values <- startup_ui_source_values(include_disabled = FALSE)
      source_values <- trimws(as.character(source_values))
      source_values <- source_values[!is.na(source_values) & nzchar(source_values)]
      if (length(source_values) > 0L) {
        return(source_values)
      }
    }

    "vp_trade"
  }

  normalize_runtime_source_choice <- function(source_choice = NULL, default = runtime_default_source_choice()) {
    source_value <- trimws(as.character(source_choice %||% ""))
    source_value <- source_value[!is.na(source_value) & nzchar(source_value)]
    if (length(source_value) == 0L) {
      source_value <- trimws(as.character(default %||% ""))
    }
    if (length(source_value) == 0L || !nzchar(source_value[[1]])) {
      source_value <- "vp_trade"
    }
    source_value <- source_value[[1]]

    visible_values <- runtime_visible_source_values()
    visible_values <- trimws(as.character(visible_values))
    visible_values <- visible_values[!is.na(visible_values) & nzchar(visible_values)]
    if (length(visible_values) == 0L || source_value %in% visible_values) {
      return(source_value)
    }

    fallback <- runtime_default_source_choice(default = "vp_trade")
    fallback <- trimws(as.character(fallback %||% ""))
    if (length(fallback) > 0L && nzchar(fallback[[1]]) && fallback[[1]] %in% visible_values) {
      return(fallback[[1]])
    }

    visible_values[[1]]
  }

  source_allows_historical_projection <- function(source_choice = current_source_choice_safe()) {
    source_choice <- normalize_runtime_source_choice(source_choice)
    !identical(source_choice, "psd")
  }

  allowed_main_tabs_for_source <- function(source_choice = current_source_choice_safe()) {
    source_choice <- normalize_runtime_source_choice(source_choice)
    if (identical(source_choice, "psd")) {
      return(c("Map", "Time Series Analysis Tool"))
    }

    if (identical(source_choice, "wasde")) {
      return("Time Series Analysis Tool")
    }

    if (identical(source_choice, "nass")) {
      return("Time Series Analysis Tool")
    }

    tabs <- c(
      "Current vs. Average",
      "Historical Trend",
      "Map",
      "Heatmap",
      "Data",
      "Custom Comparison Tool",
      "Market Year Comparison Tool",
      "Pace Analysis Tool",
      if (source_choice %in% c("census", "hybrid")) "Census Corrections"
    )

    unique(tabs)
  }

  resizeable_main_tabs_for_source <- function(source_choice = current_source_choice_safe()) {
    source_choice <- normalize_runtime_source_choice(source_choice)
    if (identical(source_choice, "psd")) {
      return(c("Map", "Time Series Analysis Tool"))
    }

    if (identical(source_choice, "wasde")) {
      return("Time Series Analysis Tool")
    }

    tabs <- c(
      "Current vs. Average",
      "Historical Trend",
      "Map",
      "Heatmap",
      "Custom Comparison Tool",
      "Market Year Comparison Tool",
      "Pace Analysis Tool"
    )

    unique(tabs)
  }

  should_send_plotly_resize_for_tab <- function(active_tab, source_choice = current_source_choice_safe()) {
    !is.null(active_tab) && nzchar(active_tab) && active_tab %in% resizeable_main_tabs_for_source(source_choice)
  }

  normalize_main_tab_for_source <- function(selected_tab, source_choice = current_source_choice_safe()) {
    allowed_tabs <- allowed_main_tabs_for_source(source_choice)
    if (!is.null(selected_tab) && nzchar(selected_tab) && selected_tab %in% allowed_tabs) {
      normalized_tab <- selected_tab
      branch <- "selected_tab_allowed"
    } else {
      normalized_tab <- allowed_tabs[[1]]
      branch <- "fallback_first_allowed"
    }

    psd_transition_trace(
      event = "normalize_main_tab_for_source",
      reason = "tab_normalization",
      details = list(
        source_choice = source_choice,
        raw_tab = selected_tab,
        normalized_tab = normalized_tab,
        branch = branch,
        allowed_tab_count = length(allowed_tabs)
      ),
      dedupe_key = "normalize_main_tab_for_source",
      dedupe_signature = build_transition_trace_signature(list(
        source_choice = source_choice,
        raw_tab = selected_tab,
        normalized_tab = normalized_tab,
        branch = branch,
        allowed_tab_count = length(allowed_tabs)
      ))
    )

    normalized_tab
  }

  current_main_tab_safe <- function(
    selected_tab = NULL,
    source_choice = current_source_choice_safe()
  ) {
    if (is.null(selected_tab)) {
      selected_tab <- tryCatch(input$main_tabs_panel, error = function(...) NULL)
    }

    transition_state <- current_psd_source_transition_state()
    if (!is.null(transition_state)) {
      resolved_tab <- transition_state$tab
      branch <- "transition_override"
    } else {
      resolved_tab <- normalize_main_tab_for_source(selected_tab, source_choice)
      branch <- "normalized_raw_tab"
    }

    psd_transition_trace(
      event = "current_main_tab_safe",
      reason = "tab_resolution",
      details = list(
        source_choice = source_choice,
        raw_tab = selected_tab,
        resolved_tab = resolved_tab,
        branch = branch,
        transition_override_active = !is.null(transition_state)
      ),
      dedupe_key = "current_main_tab_safe",
      dedupe_signature = build_transition_trace_signature(list(
        source_choice = source_choice,
        raw_tab = selected_tab,
        resolved_tab = resolved_tab,
        branch = branch,
        transition_override_active = !is.null(transition_state)
      ))
    )

    resolved_tab
  }

  normalized_raw_main_tab <- function(
    selected_tab = if (!is.null(input$main_tabs_panel)) input$main_tabs_panel else NULL,
    source_choice = current_source_choice_safe()
  ) {
    normalized_tab <- normalize_main_tab_for_source(selected_tab, source_choice)

    psd_transition_trace(
      event = "normalized_raw_main_tab",
      reason = "tab_normalization",
      details = list(
        source_choice = source_choice,
        raw_tab = selected_tab,
        normalized_tab = normalized_tab
      ),
      dedupe_key = "normalized_raw_main_tab",
      dedupe_signature = build_transition_trace_signature(list(
        source_choice = source_choice,
        raw_tab = selected_tab,
        normalized_tab = normalized_tab
      ))
    )

    normalized_tab
  }

  is_effective_map_tab_active <- function(source_choice = current_source_choice_safe()) {
    identical(normalized_raw_main_tab(source_choice = source_choice), "Map")
  }

  is_psd_effective_map_tab_active <- function() {
    source_choice <- current_source_choice_safe()
    normalized_tab <- normalized_raw_main_tab(source_choice = source_choice)
    is_active <- identical(source_choice, "psd") && identical(normalized_tab, "Map")

    psd_transition_trace(
      event = "is_psd_effective_map_tab_active",
      reason = "tab_activation_check",
      details = list(
        source_choice = source_choice,
        normalized_tab = normalized_tab,
        is_active = is_active
      ),
      dedupe_key = "is_psd_effective_map_tab_active",
      dedupe_signature = build_transition_trace_signature(list(
        source_choice = source_choice,
        normalized_tab = normalized_tab,
        is_active = is_active
      ))
    )

    is_active
  }

  get_metric_label_for_context <- function(
    metric_code,
    source_choice = if (!is.null(input$data_source_choice)) input$data_source_choice else "export_sales",
    census_trade_flow = if (!is.null(input$census_trade_flow_choice) && input$census_trade_flow_choice %in% c("export", "import")) input$census_trade_flow_choice else "export",
    hybrid_trade_flow = if (!is.null(input$hybrid_trade_flow_choice) && input$hybrid_trade_flow_choice %in% c("export", "import")) input$hybrid_trade_flow_choice else "export",
    vp_trade_flow = if (!is.null(input$vp_trade_flow_choice) && input$vp_trade_flow_choice %in% c("export", "import")) input$vp_trade_flow_choice else "export"
  ) {
    source_choice <- as.character(source_choice)[[1]]
    census_trade_flow <- if (identical(census_trade_flow, "import")) "import" else "export"
    hybrid_trade_flow <- if (identical(hybrid_trade_flow, "import")) "import" else "export"
    active_trade_flow <- "export"

    if (identical(source_choice, "census")) {
      active_trade_flow <- census_trade_flow
    } else if (identical(source_choice, "census_import")) {
      active_trade_flow <- "import"
    } else if (identical(source_choice, "hybrid")) {
      active_trade_flow <- hybrid_trade_flow
    } else if (identical(source_choice, "hybrid_import")) {
      active_trade_flow <- "import"
    } else if (identical(source_choice, "vp_trade")) {
      active_trade_flow <- if (identical(vp_trade_flow, "import")) "import" else "export"
    }

    if (identical(source_choice, "wasde")) {
      return(wasde_metric_label_for_code(metric_code))
    }

    if (identical(source_choice, "nass")) {
      return(nass_metric_label_for_code(metric_code))
    }

    common_metric_names <- c(
      monthlyexports = if (identical(active_trade_flow, "import")) "Monthly Imports" else "Monthly Exports",
      ytd_exports = if (identical(active_trade_flow, "import")) "Accumulated Imports" else "Accumulated Exports",
      total_commitment = "Total Commitment",
      outstandingSales = "Outstanding Sales",
      grossNewSales = "Gross New Sales",
      currentMYNetSales = "Current MY Net Sales",
      nextMYOutstandingSales = "Next MY Outstanding Sales",
      nextMYNetSales = "Next MY Net Sales",
      monthlyvalue = if (identical(active_trade_flow, "import")) "Monthly Imports Value" else "Monthly Value",
      ytd_value = if (identical(active_trade_flow, "import")) "Accumulated Imports Value" else "Accumulated Value",
      unit_value = if (identical(active_trade_flow, "import")) "Import Unit Value" else "Export Unit Value",
      ytd_unit_value = if (identical(active_trade_flow, "import")) "Accumulated Import Unit Value" else "Accumulated Export Unit Value"
    )

    psd_metric_names <- c(
      psd_exports = "Exports",
      psd_imports = "Imports",
      psd_production = "Production",
      psd_beginning_stocks = "Beginning Stocks",
      psd_ending_stocks = "Ending Stocks",
      psd_domestic_consumption = "Domestic Consumption",
      psd_total_supply = "Total Supply",
      psd_total_distribution = "Total Distribution"
    )

    metric_lookup <- if (identical(source_choice, "psd")) {
      psd_metric_names
    } else {
      common_metric_names
    }
    metric_label <- unname(metric_lookup[metric_code])
    if (length(metric_label) == 1 && !is.na(metric_label) && nzchar(metric_label)) metric_label else metric_code
  }

  get_metric_choices_for_context <- function(
    active_tab = input$main_tabs_panel,
    source_choice = if (!is.null(input$data_source_choice)) input$data_source_choice else "export_sales",
    data_frequency = input$data_frequency,
    census_trade_flow = if (!is.null(input$census_trade_flow_choice) && input$census_trade_flow_choice %in% c("export", "import")) input$census_trade_flow_choice else "export",
    hybrid_trade_flow = if (!is.null(input$hybrid_trade_flow_choice) && input$hybrid_trade_flow_choice %in% c("export", "import")) input$hybrid_trade_flow_choice else "export",
    vp_trade_flow = if (!is.null(input$vp_trade_flow_choice) && input$vp_trade_flow_choice %in% c("export", "import")) input$vp_trade_flow_choice else "export",
    selected_hybrid_mode = hybrid_mode_choice(),
    map_display_mode = if (!is.null(input$map_comparison_mode)) input$map_comparison_mode else "current"
  ) {
    data_frequency <- if (!is.null(data_frequency) && data_frequency %in% c("weekly", "monthly")) {
      data_frequency
    } else {
      "weekly"
    }

    if (identical(source_choice, "psd") || identical(source_choice, "wasde") || identical(source_choice, "nass")) {
      data_frequency <- "monthly"
    }

    census_mode <- identical(source_choice, "census")
    hybrid_mode <- identical(source_choice, "hybrid")
    vp_trade_mode <- identical(source_choice, "vp_trade")
    psd_mode <- identical(source_choice, "psd")
    wasde_mode <- identical(source_choice, "wasde")
    nass_mode <- identical(source_choice, "nass")
    hybrid_import_mode <- hybrid_mode && identical(hybrid_trade_flow, "import")

    monthly_choices_vp_export <- c(
      "Monthly Exports" = "monthlyexports",
      "Accumulated Exports" = "ytd_exports",
      "Monthly Value" = "monthlyvalue",
      "Accumulated Value" = "ytd_value",
      "Export Unit Value" = "unit_value"
    )

    monthly_choices_vp_import <- c(
      "Monthly Imports" = "monthlyexports",
      "Accumulated Imports" = "ytd_exports",
      "Monthly Imports Value" = "monthlyvalue",
      "Accumulated Imports Value" = "ytd_value",
      "Import Unit Value" = "unit_value"
    )

    partner_allowed_vp_export <- c(
      "Accumulated Exports" = "ytd_exports",
      "Accumulated Value" = "ytd_value"
    )

    partner_allowed_vp_import <- c(
      "Accumulated Imports" = "ytd_exports",
      "Accumulated Imports Value" = "ytd_value"
    )

    monthly_cumulative_vp_export <- c(
      "Accumulated Exports" = "ytd_exports",
      "Accumulated Value" = "ytd_value"
    )

    monthly_cumulative_vp_import <- c(
      "Accumulated Imports" = "ytd_exports",
      "Accumulated Imports Value" = "ytd_value"
    )

    vp_context_has_mixed_volume <- FALSE
    if (isTRUE(vp_trade_mode)) {
      vp_context_has_mixed_volume <- isTRUE(vp_rollup_context_has_mixed_volume_family(
        source_choice = source_choice,
        country_choice = input$country_choice,
        vp_group_choice = input$vp_group_choice,
        vp_subgroup_choice = input$vp_subgroup_choice,
        vp_market_segment_choice = input$vp_market_segment_choice,
        vp_commodity_name_choice = input$vp_commodity_name_choice,
        vp_commodity_detail_choice = input$commodity_choice
      ))
    }

    apply_vp_context_metric_filters <- function(metric_choices,
                                                has_mixed_volume_context = vp_context_has_mixed_volume) {
      if (!isTRUE(vp_trade_mode) || length(metric_choices) == 0) {
        return(metric_choices)
      }

      filtered_choices <- metric_choices

      if (isTRUE(has_mixed_volume_context)) {
        mixed_volume_blocked_metrics <- c("monthlyexports", "ytd_exports", "total_commitment")
        allow_accumulated_volume_default <- isTRUE(isolate(vp_trade_metric_default_pending())) || identical(input$metric_choice, "ytd_exports")
        if (isTRUE(allow_accumulated_volume_default)) {
          mixed_volume_blocked_metrics <- setdiff(mixed_volume_blocked_metrics, "ytd_exports")
        }
        filtered_choices <- filtered_choices[!(unname(filtered_choices) %in% mixed_volume_blocked_metrics)]
      }

      filtered_choices
    }

    if (isTRUE(vp_trade_mode)) {
      monthly_choices_vp_export <- apply_vp_context_metric_filters(monthly_choices_vp_export, has_mixed_volume_context = vp_context_has_mixed_volume)
      monthly_choices_vp_import <- apply_vp_context_metric_filters(monthly_choices_vp_import, has_mixed_volume_context = vp_context_has_mixed_volume)
      partner_allowed_vp_export <- apply_vp_context_metric_filters(partner_allowed_vp_export, has_mixed_volume_context = vp_context_has_mixed_volume)
      partner_allowed_vp_import <- apply_vp_context_metric_filters(partner_allowed_vp_import, has_mixed_volume_context = vp_context_has_mixed_volume)
      monthly_cumulative_vp_export <- apply_vp_context_metric_filters(monthly_cumulative_vp_export, has_mixed_volume_context = vp_context_has_mixed_volume)
      monthly_cumulative_vp_import <- apply_vp_context_metric_filters(monthly_cumulative_vp_import, has_mixed_volume_context = vp_context_has_mixed_volume)
    }

    monthly_choices_export <- c(
      "Monthly Exports" = "monthlyexports",
      "Year-to-Date Exports" = "ytd_exports",
      "Total Commitment" = "total_commitment"
    )

    monthly_choices_hybrid_export <- c(
      "Monthly Exports" = "monthlyexports",
      "Accumulated Exports" = "ytd_exports"
    )

    monthly_choices_hybrid_import <- c(
      "Monthly Imports" = "monthlyexports",
      "Accumulated Imports" = "ytd_exports"
    )

    weekly_choices_hybrid <- c(
      "Weekly Exports" = "monthlyexports",
      "Accumulated Exports" = "ytd_exports"
    )

    monthly_choices_census <- c(
      "Monthly Exports" = "monthlyexports",
      "Accumulated Exports" = "ytd_exports",
      "Monthly Value" = "monthlyvalue",
      "Accumulated Value" = "ytd_value"
    )

    monthly_choices_census_import <- c(
      "Monthly Imports" = "monthlyexports",
      "Accumulated Imports" = "ytd_exports",
      "Monthly Imports Value" = "monthlyvalue",
      "Accumulated Imports Value" = "ytd_value"
    )

    weekly_choices_export <- c(
      "Weekly Exports" = "monthlyexports",
      "Accumulated Exports" = "ytd_exports",
      "Outstanding Sales" = "outstandingSales",
      "Gross New Sales" = "grossNewSales",
      "Current MY Net Sales" = "currentMYNetSales",
      "Current MY Total Commitment" = "total_commitment",
      "Next MY Outstanding Sales" = "nextMYOutstandingSales",
      "Next MY Net Sales" = "nextMYNetSales"
    )

    partner_allowed_export <- c(
      "Accumulated Exports" = "ytd_exports",
      "Current MY Total Commitment" = "total_commitment"
    )

    partner_allowed_hybrid_export <- c(
      "Accumulated Exports" = "ytd_exports"
    )

    partner_allowed_hybrid_import <- c(
      "Accumulated Imports" = "ytd_exports"
    )

    partner_allowed_census <- c(
      "Accumulated Exports" = "ytd_exports",
      "Accumulated Value" = "ytd_value"
    )

    partner_allowed_census_import <- c(
      "Accumulated Imports" = "ytd_exports",
      "Accumulated Imports Value" = "ytd_value"
    )

    monthly_cumulative_export <- c(
      "Year-to-Date Exports" = "ytd_exports",
      "Total Commitment" = "total_commitment"
    )

    monthly_cumulative_hybrid_export <- c(
      "Accumulated Exports" = "ytd_exports"
    )

    monthly_cumulative_hybrid_import <- c(
      "Accumulated Imports" = "ytd_exports"
    )

    monthly_cumulative_census <- c(
      "Accumulated Exports" = "ytd_exports",
      "Accumulated Value" = "ytd_value"
    )

    monthly_cumulative_census_import <- c(
      "Accumulated Imports" = "ytd_exports",
      "Accumulated Imports Value" = "ytd_value"
    )

    map_historical_comparison_choices <- if (hybrid_mode) {
      if (hybrid_import_mode) {
        monthly_cumulative_hybrid_import
      } else {
        monthly_cumulative_hybrid_export
      }
    } else if (vp_trade_mode) {
      if (identical(vp_trade_flow, "import")) {
        monthly_cumulative_vp_import
      } else {
        monthly_cumulative_vp_export
      }
    } else if (psd_mode) {
      psd_metric_choices[unname(psd_metric_choices) != "psd_milling_rate"]
    } else if (wasde_mode) {
      wasde_metric_choices
    } else if (nass_mode) {
      nass_metric_choices
    } else if (census_mode) {
      if (identical(census_trade_flow, "import")) {
        monthly_cumulative_census_import
      } else {
        monthly_cumulative_census
      }
    } else {
      c(
        "Accumulated Exports" = "ytd_exports"
      )
    }

    if (identical(active_tab, "Map") && identical(map_display_mode, "comparison")) {
      return(map_historical_comparison_choices)
    }

    if (identical(active_tab, "Market Year Comparison Tool")) {
      if (psd_mode) {
        return(psd_metric_choices)
      }
      if (wasde_mode) {
        return(wasde_metric_choices)
      }
      if (nass_mode) {
        return(nass_metric_choices)
      }
      if (vp_trade_mode) {
        return(if (identical(vp_trade_flow, "import")) partner_allowed_vp_import else partner_allowed_vp_export)
      }
      if (hybrid_mode) {
        return(if (hybrid_import_mode) partner_allowed_hybrid_import else partner_allowed_hybrid_export)
      }
      if (census_mode) {
        return(if (identical(census_trade_flow, "import")) partner_allowed_census_import else partner_allowed_census)
      }
      return(partner_allowed_export)
    }

    if (identical(active_tab, "Pace Analysis Tool")) {
      if (psd_mode) {
        return(psd_metric_choices)
      }
      if (wasde_mode) {
        return(wasde_metric_choices)
      }
      if (nass_mode) {
        return(nass_metric_choices)
      }
      if (vp_trade_mode) {
        return(if (identical(vp_trade_flow, "import")) monthly_cumulative_vp_import else monthly_cumulative_vp_export)
      }
      if (identical(data_frequency, "monthly")) {
        if (hybrid_mode) {
          return(if (hybrid_import_mode) monthly_cumulative_hybrid_import else monthly_cumulative_hybrid_export)
        }
        if (census_mode) {
          return(if (identical(census_trade_flow, "import")) monthly_cumulative_census_import else monthly_cumulative_census)
        }
        return(monthly_cumulative_export)
      }

      if (hybrid_mode) {
        return(if (hybrid_import_mode) partner_allowed_hybrid_import else partner_allowed_hybrid_export)
      }
      return(partner_allowed_export)
    }

    if (psd_mode) {
      return(psd_metric_choices)
    }

    if (wasde_mode) {
      return(wasde_metric_choices)
    }

    if (nass_mode) {
      return(nass_metric_choices)
    }

    if (vp_trade_mode) {
      return(if (identical(vp_trade_flow, "import")) monthly_choices_vp_import else monthly_choices_vp_export)
    }

    if (hybrid_mode) {
      if (hybrid_import_mode) {
        return(monthly_choices_hybrid_import)
      }
      return(if (identical(selected_hybrid_mode, "weekly_imputed")) weekly_choices_hybrid else monthly_choices_hybrid_export)
    }

    if (census_mode) {
      return(if (identical(census_trade_flow, "import")) monthly_choices_census_import else monthly_choices_census)
    }

    if (identical(data_frequency, "monthly")) {
      return(monthly_choices_export)
    }

    weekly_choices_export
  }

  filter_main_metric_choices_for_year_type <- function(metric_choices,
                                                       source_choice = if (!is.null(input$data_source_choice)) input$data_source_choice else "export_sales",
                                                       data_frequency = input$data_frequency,
                                                       year_type = current_non_psd_year_type_safe(source_choice = source_choice, default = "marketing")) {
    if (!identical(source_choice, "export_sales") ||
        !identical(year_type, "fiscal")) {
      return(metric_choices)
    }

    blocked_metric_codes <- if (identical(data_frequency, "weekly")) {
      c(
        "total_commitment",
        "outstandingSales",
        "grossNewSales",
        "currentMYNetSales",
        "nextMYOutstandingSales",
        "nextMYNetSales"
      )
    } else if (identical(data_frequency, "monthly")) {
      "total_commitment"
    } else {
      character(0)
    }

    if (length(blocked_metric_codes) == 0) {
      return(metric_choices)
    }

    metric_choices[!(unname(metric_choices) %in% blocked_metric_codes)]
  }

  resolve_metric_fallback <- function(metric_choices, preferred_metric = "ytd_exports") {
    metric_codes <- unname(metric_choices)
    if (length(metric_codes) == 0) return(NULL)
    if (!is.null(preferred_metric) && preferred_metric %in% metric_codes) return(preferred_metric)
    if ("qty_of_exports" %in% metric_codes) return("qty_of_exports")
    if ("ytd_exports" %in% metric_codes) return("ytd_exports")
    metric_codes[[1]]
  }

  sanitize_metric_for_choices <- function(metric_value, metric_choices, preferred_metric = "ytd_exports") {
    metric_codes <- unname(metric_choices)
    if (!is.null(metric_value) && metric_value %in% metric_codes) {
      return(metric_value)
    }
    resolve_metric_fallback(metric_choices, preferred_metric)
  }

  map_historical_comparison_metric_choices <- function(
    source_choice = if (!is.null(input$data_source_choice)) input$data_source_choice else "export_sales",
    data_frequency = input$data_frequency,
    census_trade_flow = if (!is.null(input$census_trade_flow_choice) && input$census_trade_flow_choice %in% c("export", "import")) input$census_trade_flow_choice else "export",
    hybrid_trade_flow = if (!is.null(input$hybrid_trade_flow_choice) && input$hybrid_trade_flow_choice %in% c("export", "import")) input$hybrid_trade_flow_choice else "export",
    selected_hybrid_mode = hybrid_mode_choice()
  ) {
    get_metric_choices_for_context(
      active_tab = "Map",
      source_choice = source_choice,
      data_frequency = data_frequency,
      census_trade_flow = census_trade_flow,
      hybrid_trade_flow = hybrid_trade_flow,
      selected_hybrid_mode = selected_hybrid_mode,
      map_display_mode = "comparison"
    )
  }

  map_metric_choices_for_mode_gating <- reactive({
    source_choice <- current_source_choice_safe()
    data_frequency <- current_data_frequency_safe()
    filter_main_metric_choices_for_year_type(
      get_metric_choices_for_context(map_display_mode = "current"),
      source_choice = source_choice,
      data_frequency = data_frequency,
      year_type = current_non_psd_year_type_safe(source_choice = source_choice, default = "marketing")
    )
  })

  map_metric_selection_for_mode_gating <- reactive({
    sanitize_metric_for_choices(
      input$metric_choice,
      map_metric_choices_for_mode_gating(),
      preferred_metric = default_metric_for_source()
    )
  })

  map_display_mode_choices_for_current_context <- reactive({
    map_metric_selected <- map_metric_selection_for_mode_gating()
    comparison_metric_codes <- unname(map_historical_comparison_metric_choices())

    if (!is.null(map_metric_selected) && map_metric_selected %in% comparison_metric_codes) {
      return(c("Current Level" = "current", "Historical Comparison" = "comparison"))
    }

    c("Current Level" = "current")
  })

  effective_map_display_mode <- reactive({
    valid_modes <- unname(map_display_mode_choices_for_current_context())
    current_mode <- if (!is.null(input$map_comparison_mode)) input$map_comparison_mode else valid_modes[[1]]

    if (!(current_mode %in% valid_modes)) {
      return(valid_modes[[1]])
    }

    current_mode
  })

  metric_choices_for_current_context <- reactive({
    transition_state <- current_psd_source_transition_state()
    if (!is.null(transition_state)) {
      return(transition_state$metric_choices)
    }

    source_choice <- current_source_choice_safe()
    data_frequency <- current_data_frequency_safe()
    year_type <- current_non_psd_year_type_safe(source_choice = source_choice, default = "marketing")

    filter_main_metric_choices_for_year_type(
      get_metric_choices_for_context(
        source_choice = source_choice,
        data_frequency = data_frequency,
        map_display_mode = effective_map_display_mode()
      ),
      source_choice = source_choice,
      data_frequency = data_frequency,
      year_type = year_type
    )
  })

  effective_main_metric <- reactive({
    transition_state <- current_psd_source_transition_state()
    if (!is.null(transition_state)) {
      return(transition_state$metric)
    }

    sanitize_metric_for_choices(
      input$metric_choice,
      metric_choices_for_current_context(),
      preferred_metric = default_metric_for_source()
    )
  })

  custom_comparison_metric_choices <- function() {
    source_choice <- current_source_choice_safe()
    data_frequency <- current_data_frequency_safe()
    year_type <- current_non_psd_year_type_safe(source_choice = source_choice, default = "marketing")

    filter_main_metric_choices_for_year_type(
      get_metric_choices_for_context(
        active_tab = "Custom Comparison Tool",
        source_choice = source_choice,
        data_frequency = data_frequency
      ),
      source_choice = source_choice,
      data_frequency = data_frequency,
      year_type = year_type
    )
  }

  custom_valid_metric_codes <- function() {
    unname(custom_comparison_metric_choices())
  }

  custom_share_candidates <- function(metric_code, commodity_code, available_codes) {
    start_time <- Sys.time()
    source_rows <- 0L
    recent_rows <- 0L
    snapshot_rows <- 0L
    result_rows <- 0L
    status <- "ok"

    on.exit({
      log_perf(
        "custom_share_candidates()",
        start_time,
        details = custom_comparison_perf_details(list(
          metric_code = metric_code,
          commodity_code = commodity_code,
          available_codes = if (is.null(available_codes)) 0L else length(available_codes),
          source_rows = source_rows,
          recent_rows = recent_rows,
          snapshot_rows = snapshot_rows,
          result_rows = result_rows,
          status = status
        ))
      )
    }, add = TRUE)

    record_cache_body_execution(session, "selected_data_read_custom_share_candidates", details = list(metric = metric_code, commodity = commodity_code))
    df_all <- selected_data()
    if (is.null(df_all) || !(metric_code %in% names(df_all))) {
      status <- "missing_metric"
      return(data.frame(country = character(), value = numeric(), share_pct = numeric(), stringsAsFactors = FALSE))
    }

    df <- df_all %>%
      filter(.data$commodity == commodity_code) %>%
      filter(!.data$country %in% c("GRAND_TOTAL", "Grand Total"))
    source_rows <- nrow(df)

    if (nrow(df) == 0) {
      status <- "no_source_rows"
      return(data.frame(country = character(), value = numeric(), share_pct = numeric(), stringsAsFactors = FALSE))
    }

    current_my <- suppressWarnings(max(df$market_year, na.rm = TRUE))
    if (!is.finite(current_my)) {
      status <- "invalid_market_year"
      return(data.frame(country = character(), value = numeric(), share_pct = numeric(), stringsAsFactors = FALSE))
    }

    recent_data <- df %>% filter(.data$market_year == current_my)
    recent_rows <- nrow(recent_data)
    if (nrow(recent_data) == 0) {
      status <- "no_recent_rows"
      return(data.frame(country = character(), value = numeric(), share_pct = numeric(), stringsAsFactors = FALSE))
    }

    most_recent_period <- suppressWarnings(max(recent_data$analysis_month, na.rm = TRUE))
    if (!is.finite(most_recent_period)) {
      status <- "invalid_analysis_month"
      return(data.frame(country = character(), value = numeric(), share_pct = numeric(), stringsAsFactors = FALSE))
    }

    snap <- recent_data %>%
      filter(.data$analysis_month == most_recent_period) %>%
      transmute(
        country = .data$country,
        value = suppressWarnings(as.numeric(.data[[metric_code]]))
      ) %>%
      filter(!is.na(.data$value), .data$value > 0)

    if (!is.null(available_codes) && length(available_codes) > 0) {
      snap <- snap %>% filter(.data$country %in% available_codes)
    }
    snapshot_rows <- nrow(snap)

    if (nrow(snap) == 0) {
      status <- "no_snapshot_rows"
      return(data.frame(country = character(), value = numeric(), share_pct = numeric(), stringsAsFactors = FALSE))
    }

    total_value <- (sum(snap$value, na.rm = TRUE) * (NA_real_ ^ (sum(!is.na(snap$value)) == 0)))
    if (!is.finite(total_value) || total_value <= 0) {
      status <- "invalid_total_value"
      return(data.frame(country = character(), value = numeric(), share_pct = numeric(), stringsAsFactors = FALSE))
    }

    result <- snap %>%
      mutate(share_pct = .data$value / total_value) %>%
      arrange(dplyr::desc(.data$value), .data$country)

    result_rows <- nrow(result)
    result
  }

  choose_custom_panel_countries <- function(selected_country, share_df, available_codes, n = 3) {
    available_non_grand <- unique(available_codes[!available_codes %in% c("GRAND_TOTAL", "Grand Total")])
    selected_country_code <- if (is.null(selected_country) || length(selected_country) == 0) {
      NA_character_
    } else {
      selected_country_value <- trimws(as.character(selected_country[[1]]))
      if (is.na(selected_country_value) || !nzchar(selected_country_value)) NA_character_ else selected_country_value
    }

    ordered <- available_non_grand
    if (is.data.frame(share_df) && nrow(share_df) > 0) {
      highest_order <- share_df$country
      if (!is.na(selected_country_code) && !identical(selected_country_code, "GRAND_TOTAL") && selected_country_code %in% share_df$country) {
        selected_share <- share_df$share_pct[match(selected_country_code, share_df$country)]
        nearest <- share_df %>%
          filter(.data$country != selected_country_code) %>%
          mutate(abs_diff = abs(.data$share_pct - selected_share)) %>%
          arrange(.data$abs_diff, dplyr::desc(.data$value), .data$country)
        ordered <- c(nearest$country, highest_order, available_non_grand)
      } else {
        ordered <- c(highest_order, available_non_grand)
      }
    }

    picked_unique <- unique(ordered[ordered %in% available_non_grand])
    if (length(picked_unique) == 0) {
      if ("GRAND_TOTAL" %in% available_codes) return(rep("GRAND_TOTAL", n))
      return(character(0))
    }

    if (length(picked_unique) >= n) {
      return(head(picked_unique, n))
    }

    # If not enough eligible countries exist, repeat the last ranked candidate deterministically.
    c(picked_unique, rep(picked_unique[length(picked_unique)], n - length(picked_unique)))
  }

  choose_top_custom_panel_countries <- function(metric_code, commodity_code, n = 3, available_codes = NULL) {
    start_time <- Sys.time()

    if (is.null(available_codes) || length(available_codes) == 0) {
      available_codes <- custom_comparison_country_universe()
    }

    available_codes <- available_codes[!is.na(available_codes) & nzchar(available_codes)]
    available_non_grand <- available_codes[!available_codes %in% c("GRAND_TOTAL", "Grand Total")]
    result <- character(0)
    status <- "ranked"

    share_df <- custom_share_candidates(
      metric_code = metric_code,
      commodity_code = commodity_code,
      available_codes = available_non_grand
    )

    ranked_countries <- unique(share_df$country[share_df$country %in% available_non_grand])

    if (length(ranked_countries) == 0) {
      if (length(available_non_grand) == 0) {
        fallback_country <- resolve_custom_comparison_country("GRAND_TOTAL")
        result <- rep(fallback_country, n)
        status <- "fallback_grand_total"
      } else if (length(available_non_grand) >= n) {
        result <- head(available_non_grand, n)
        status <- "fallback_available"
      } else {
        result <- c(
          available_non_grand,
          rep(available_non_grand[length(available_non_grand)], n - length(available_non_grand))
        )
        status <- "fallback_repeated"
      }
    } else {
      result <- head(ranked_countries, n)
    }

    log_perf(
      "choose_top_custom_panel_countries()",
      start_time,
      details = custom_comparison_perf_details(list(
        metric_code = metric_code,
        commodity_code = commodity_code,
        requested_n = n,
        available_non_grand = length(available_non_grand),
        ranked_candidates = length(ranked_countries),
        result_count = length(result),
        status = status
      ))
    )

    if (length(result) >= n) {
      return(result)
    }

    if (length(result) == 0) {
      return(result)
    }

    c(result, rep(result[length(result)], n - length(result)))

    if (length(ranked_countries) >= n) {
      return(head(ranked_countries, n))
    }

    c(ranked_countries, rep(ranked_countries[length(ranked_countries)], n - length(ranked_countries)))
  }

  build_custom_comparison_reset_targets <- function() {
    source_choice <- if (!is.null(input$data_source_choice)) input$data_source_choice else "export_sales"
    year_type <- current_non_psd_year_type_safe(source_choice = source_choice, default = "marketing")
    vp_commodity_name_default <- resolve_custom_comparison_vp_commodity_name(input$vp_commodity_name_choice)

    if (identical(source_choice, "export_sales") && identical(year_type, "fiscal")) {
      target_metric <- sanitize_metric_for_choices(
        NULL,
        custom_comparison_metric_choices(),
        preferred_metric = "ytd_exports"
      )
      target_commodity <- resolve_custom_comparison_commodity(default_commodity_choice_value())
      top_countries <- choose_top_custom_panel_countries(
        metric_code = target_metric,
        commodity_code = target_commodity,
        n = 3,
        available_codes = custom_comparison_country_universe()
      )

      return(list(
        metric_right = target_metric,
        country_right_2up = top_countries[1],
        commodity_right_2up = target_commodity,
        vp_commodity_name_right_2up = vp_commodity_name_default,
        metric_grid_2 = target_metric,
        country_grid_2 = top_countries[1],
        commodity_grid_2 = target_commodity,
        metric_grid_3 = target_metric,
        country_grid_3 = top_countries[2],
        commodity_grid_3 = target_commodity,
        vp_commodity_name_grid_3 = vp_commodity_name_default,
        metric_grid_4 = target_metric,
        country_grid_4 = top_countries[3],
        commodity_grid_4 = target_commodity,
        vp_commodity_name_grid_4 = vp_commodity_name_default
      ))
    }

    if (identical(source_choice, "export_sales")) {
      metric_right_default <- sanitize_metric_for_choices(
        NULL,
        custom_comparison_metric_choices(),
        preferred_metric = "monthlyexports"
      )
      metric_grid_3_default <- sanitize_metric_for_choices(
        NULL,
        custom_comparison_metric_choices(),
        preferred_metric = "outstandingSales"
      )
      metric_grid_4_default <- sanitize_metric_for_choices(
        NULL,
        custom_comparison_metric_choices(),
        preferred_metric = "total_commitment"
      )
      country_default <- resolve_custom_comparison_country("GRAND_TOTAL")
      commodity_default <- resolve_custom_comparison_commodity(default_commodity_choice_value())

      return(list(
        metric_right = metric_right_default,
        country_right_2up = country_default,
        commodity_right_2up = commodity_default,
        vp_commodity_name_right_2up = vp_commodity_name_default,
        metric_grid_2 = metric_right_default,
        country_grid_2 = country_default,
        commodity_grid_2 = commodity_default,
        metric_grid_3 = metric_grid_3_default,
        country_grid_3 = country_default,
        commodity_grid_3 = commodity_default,
        vp_commodity_name_grid_3 = vp_commodity_name_default,
        metric_grid_4 = metric_grid_4_default,
        country_grid_4 = country_default,
        commodity_grid_4 = commodity_default,
        vp_commodity_name_grid_4 = vp_commodity_name_default
      ))
    }

    target_metric <- sanitize_metric_for_choices(
      NULL,
      custom_comparison_metric_choices(),
      preferred_metric = "ytd_exports"
    )
    target_commodity <- resolve_custom_comparison_commodity(default_commodity_choice_value())
    top_countries <- choose_top_custom_panel_countries(
      metric_code = target_metric,
      commodity_code = target_commodity,
      n = 3,
      available_codes = custom_comparison_country_universe()
    )

    list(
      metric_right = target_metric,
      country_right_2up = top_countries[1],
      commodity_right_2up = target_commodity,
      vp_commodity_name_right_2up = vp_commodity_name_default,
      metric_grid_2 = target_metric,
      country_grid_2 = top_countries[1],
      commodity_grid_2 = target_commodity,
      metric_grid_3 = target_metric,
      country_grid_3 = top_countries[2],
      commodity_grid_3 = target_commodity,
      vp_commodity_name_grid_3 = vp_commodity_name_default,
      metric_grid_4 = target_metric,
      country_grid_4 = top_countries[3],
      commodity_grid_4 = target_commodity,
      vp_commodity_name_grid_4 = vp_commodity_name_default
    )
  }

  # Update partner selection choices/defaults for Market Year Comparison Tool
  observe({
    current_main_tab <- input$main_tabs_panel
    if (!identical(current_main_tab, "Market Year Comparison Tool")) return()

    dependency_snapshot <- list(
      compare_mode = input$market_year_compare_mode,
      commodity = input$commodity_choice,
      country = input$country_choice,
      metric = effective_main_metric(),
      order_by_latest_market_year = input$myc_order_by_latest_market_year,
      comparison_basis_mode = input$projection_basis_mode,
      comparison_reference_year = input$projection_reference_year,
      comparison_hist_years = comparison_hist_years_committed(),
      context_version = partner_selection_context_version()
    )
    invisible(dependency_snapshot)

    record_partner_share_data_read("partner_repopulation_observer")
    share_data <- partner_share_data()
    partner_choices <- market_year_partner_choice_order()
    current_basis_signature <- build_myc_partner_basis_signature(share_data)
    previous_basis_signature <- isolate(partner_selection_basis_signature())
    previous_basis_signature_manual <- isTRUE(isolate(partner_selection_basis_signature_manual()))
    basis_signature_changed <- !is.null(current_basis_signature) && !identical(previous_basis_signature, current_basis_signature)

    isolate({

      myc_transition_trace(
        "partner_repopulation_observer_enter",
        details = list(
          compare_mode = isolate(market_year_comparison_mode()),
          country = isolate(input$country_choice),
          commodity = isolate(input$commodity_choice),
          force_default = isTRUE(partner_selection_force_default()),
          world_reset_pending = isTRUE(partner_selection_programmatic_world_reset()),
          all_rice_reset_pending = isTRUE(partner_selection_programmatic_all_rice_reset())
        )
      )

      if (is.null(share_data)) {
        clear_partner_show_input(
          preserve_transition_state = isTRUE(partner_selection_force_default()) || !is.null(partner_selection_reset_override())
        )
        return()
      }

      if (length(partner_choices) == 0) {
        clear_partner_show_input(
          preserve_transition_state = isTRUE(partner_selection_force_default()) || !is.null(partner_selection_reset_override())
        )
        return()
      }

      if (isTRUE(partner_selection_programmatic_world_reset())) {
        if (!identical(input$country_choice, "GRAND_TOTAL")) {
          myc_transition_trace("partner_repopulation_waiting_for_world_reset")
          clear_partner_show_input(preserve_transition_state = TRUE)
          return()
        }
        partner_selection_programmatic_world_reset(FALSE)
        mark_myc_transition_mutation(
          "clear_programmatic_world_reset",
          details = list(reason = "partner_repopulation_country_is_grand_total")
        )
      }

      if (isTRUE(partner_selection_programmatic_all_rice_reset())) {
        if (!identical(input$commodity_choice, default_commodity_choice_value())) {
          myc_transition_trace("partner_repopulation_waiting_for_all_rice_reset")
          clear_partner_show_input(preserve_transition_state = TRUE)
          return()
        }
        partner_selection_programmatic_all_rice_reset(FALSE)
        mark_myc_transition_mutation(
          "clear_programmatic_all_rice_reset",
          details = list(reason = "partner_repopulation_commodity_is_all_rice")
        )
      }

      current_input_selection <- normalize_myc_partner_values(
        isolate(input$partner_show),
        comparison_mode = share_data$comparison_mode
      )
      current_input_matches_context <- identical(
        partner_selection_input_version(),
        partner_selection_context_version()
      )
      legalized_override_selection <- get_partner_selection_legalized_override(share_data$comparison_mode)
      legal_legalized_override_selection <- unique(legalized_override_selection[legalized_override_selection %in% partner_choices])
      pending_programmatic_selection <- isolate(partner_selection_programmatic_selected())
      pending_programmatic_manual <- isTRUE(isolate(partner_selection_programmatic_manual()))
      legal_pending_programmatic_selection <- if (!is.null(pending_programmatic_selection) && isTRUE(pending_programmatic_manual)) {
        pending_programmatic_selection <- normalize_myc_partner_values(pending_programmatic_selection, comparison_mode = share_data$comparison_mode)
        unique(pending_programmatic_selection[pending_programmatic_selection %in% partner_choices])
      } else {
        character(0)
      }
      legal_current_input <- if (isTRUE(current_input_matches_context)) {
        unique(current_input_selection[current_input_selection %in% partner_choices])
      } else {
        character(0)
      }

      remembered_state <- get_remembered_partner_selection_state(share_data$comparison_mode)
      remembered_selection_is_manual <- isTRUE(remembered_state$selection_is_manual)
      preserve_remembered_state <- isTRUE(partner_selection_preserve_remembered_state())
      top_up_defaults_on_repopulation <- isTRUE(partner_selection_top_up_defaults_on_repopulation())
      legal_remembered_selection <- get_remembered_partner_selection(
        comparison_mode = share_data$comparison_mode,
        eligible_choices = partner_choices,
        manual_only = TRUE
      )
      legal_default_selection <- unique(share_data$default_sel[share_data$default_sel %in% partner_choices])
      reset_override_selection <- normalize_myc_partner_values(partner_selection_reset_override(), comparison_mode = share_data$comparison_mode)
      legal_reset_override_selection <- unique(reset_override_selection[reset_override_selection %in% partner_choices])
      basis_default_reseed_required <- isTRUE(basis_signature_changed) &&
        !isTRUE(previous_basis_signature_manual) &&
        length(legal_default_selection) > 0
      if (isTRUE(partner_selection_force_default())) {
        resolved_selection <- market_year_effective_partner_selection()
        resolved_selection_is_manual <- FALSE
      } else if (length(legal_legalized_override_selection) > 0) {
        resolved_selection <- legal_legalized_override_selection
        resolved_selection_is_manual <- TRUE
      } else if (length(legal_pending_programmatic_selection) > 0) {
        resolved_selection <- legal_pending_programmatic_selection
        resolved_selection_is_manual <- TRUE
      } else if (length(legal_reset_override_selection) > 0) {
        resolved_selection <- legal_reset_override_selection
        resolved_selection_is_manual <- isTRUE(partner_selection_reset_override_manual())

        # For type-mode country transitions, keep legal manual picks and top up defaults.
        if (
          isTRUE(top_up_defaults_on_repopulation) &&
          identical(share_data$comparison_mode, "type") &&
          isTRUE(resolved_selection_is_manual) &&
          length(legal_default_selection) > 0
        ) {
          resolved_selection <- unique(c(resolved_selection, legal_default_selection))
        }
      } else if (isTRUE(basis_default_reseed_required)) {
        resolved_selection <- legal_default_selection
        resolved_selection_is_manual <- FALSE
      } else if (length(legal_current_input) > 0) {
        resolved_selection <- legal_current_input
        resolved_selection_is_manual <- isTRUE(partner_selection_manual_override())
      } else if (length(legal_remembered_selection) > 0) {
        resolved_selection <- legal_remembered_selection
        resolved_selection_is_manual <- remembered_selection_is_manual
      } else {
        resolved_selection <- market_year_effective_partner_selection()
        resolved_selection_is_manual <- FALSE
      }

      resolved_selection <- order_myc_selected_partners_by_market_share(resolved_selection, share_data)

      partner_selection_manual_override(resolved_selection_is_manual)
      if (identical(share_data$comparison_mode, "type") && !isTRUE(resolved_selection_is_manual)) {
        myc_native_reset_excluded_partners(normalize_myc_partner_values(share_data$default_excluded_partners, comparison_mode = "type"))
      } else {
        myc_native_reset_excluded_partners(character(0))
      }

      if (!isTRUE(preserve_remembered_state)) {
        set_remembered_partner_selection_state(
          comparison_mode = share_data$comparison_mode,
          selection = resolved_selection,
          selection_is_manual = resolved_selection_is_manual
        )
      }

      if (isTRUE(partner_selection_force_default())) {
        partner_selection_input_version(-1L)
        partner_selection_force_default(FALSE)
      }

      if (isTRUE(top_up_defaults_on_repopulation)) {
        partner_selection_top_up_defaults_on_repopulation(FALSE)
      }

      if (!is.null(current_basis_signature) && nzchar(current_basis_signature)) {
        partner_selection_basis_signature(current_basis_signature)
        partner_selection_basis_signature_manual(isTRUE(resolved_selection_is_manual))
      }

      update_partner_show_input(
        choices = market_year_partner_show_choices(),
        selected = resolved_selection,
        selection_is_manual = resolved_selection_is_manual
      )
      if (length(legal_legalized_override_selection) > 0 || length(legal_pending_programmatic_selection) > 0) {
        force_partner_show_visible_selection(
          resolved_selection,
          reason = "partner_repopulation_legalized_selection",
          delay_ms = 40L
        )
      }

      myc_transition_trace(
        "partner_repopulation_observer_exit",
        details = list(
          partner_choices = length(partner_choices),
          resolved_selection_size = length(resolved_selection),
          resolved_selection_is_manual = isTRUE(resolved_selection_is_manual),
          basis_signature_changed = isTRUE(basis_signature_changed),
          basis_default_reseed_required = isTRUE(basis_default_reseed_required),
          top_up_defaults_on_repopulation = isTRUE(top_up_defaults_on_repopulation)
        )
      )
    })
  })

  observeEvent(input$partner_reset_top, {
    if (!identical(input$main_tabs_panel, "Market Year Comparison Tool")) return()

    record_partner_share_data_read("partner_reset_observer")
    share_data <- partner_share_data()
    if (is.null(share_data)) return()

    default_sel <- share_data$default_sel
    excluded_partners <- share_data$default_excluded_partners %||% character(0)

    myc_native_reset_excluded_partners(excluded_partners)
    partner_selection_reset_override(default_sel)
    set_remembered_partner_selection_state(share_data$comparison_mode, default_sel, FALSE)
    partner_selection_manual_override(FALSE)
    current_basis_signature <- build_myc_partner_basis_signature(share_data)
    if (!is.null(current_basis_signature) && nzchar(current_basis_signature)) {
      partner_selection_basis_signature(current_basis_signature)
      partner_selection_basis_signature_manual(FALSE)
    }

    update_partner_show_input(
      choices = market_year_partner_show_choices(),
      selected = default_sel,
      selection_is_manual = FALSE
    )
  }, ignoreInit = TRUE)

  # Remember last non-partner frequency so we can restore it after leaving Market Year Comparison Tool
  last_non_partner_frequency <- reactiveVal("weekly")
  last_non_psd_main_tab <- reactiveVal("Current vs. Average")
  non_psd_main_tab_restore_target <- reactiveVal(NULL)
  main_tabs_render_nonce <- reactiveVal(0L)
  last_main_tabs_mismatch_recovery_key <- reactiveVal(NULL)
  map_surface_refresh_nonce <- reactiveVal(0L)
  source_surface_refresh_attempts <- reactiveVal(list())
  last_non_psd_year_type <- reactiveVal("marketing")
  last_observed_data_source_choice <- reactiveVal(NULL)
  vp_trade_metric_default_pending <- reactiveVal(FALSE)
  vp_trade_unit_default_pending <- reactiveVal(FALSE)
  psd_source_entry_pending <- reactiveVal(FALSE)
  psd_source_transition_active <- reactiveVal(FALSE)
  psd_source_transition_state <- reactiveVal(NULL)
  psd_map_bottom_view_entry_target <- reactiveVal(NULL)

  normalize_psd_source_entry_scalar <- function(value) {
    candidate <- as.character(value %||% character(0))
    candidate <- candidate[!is.na(candidate) & nzchar(candidate)]
    if (length(candidate) == 0) return(NULL)
    candidate[[1]]
  }

    remember_non_psd_main_tab_if_valid <- function(source_choice, selected_tab, reason = NULL) {
      source_choice <- normalize_psd_source_entry_scalar(source_choice)
      selected_tab <- normalize_psd_source_entry_scalar(selected_tab)

      if (is.null(source_choice) || identical(source_choice, "psd") || is.null(selected_tab)) {
        return(invisible(FALSE))
      }

      allowed_tabs <- allowed_main_tabs_for_source(source_choice)
      if (!(selected_tab %in% allowed_tabs)) {
        return(invisible(FALSE))
      }

      remembered_tab <- isolate(last_non_psd_main_tab())
      restore_target <- isolate(non_psd_main_tab_restore_target())
      if (!is.null(restore_target) && !identical(selected_tab, restore_target)) {
        return(invisible(FALSE))
      }

      updated_memory <- !identical(remembered_tab, selected_tab)
      cleared_restore_target <- !is.null(restore_target) && identical(selected_tab, restore_target)

      if (updated_memory) {
        last_non_psd_main_tab(selected_tab)
      }
      if (cleared_restore_target) {
        non_psd_main_tab_restore_target(NULL)
      }

      if (updated_memory || cleared_restore_target) {
        psd_transition_trace(
          event = "remember_non_psd_main_tab",
          reason = reason %||% "non_psd_tab_memory",
          details = list(
            action = "remember_non_psd_main_tab",
            source_choice = source_choice,
            selected_tab = selected_tab,
            previous_remembered_tab = remembered_tab,
            restore_target = restore_target,
            updated_memory = updated_memory,
            cleared_restore_target = cleared_restore_target
          )
        )
      }

      invisible(TRUE)
    }

  resolve_non_psd_main_tab_target <- function(source_choice, preferred_tab = NULL) {
    allowed_tabs <- allowed_main_tabs_for_source(source_choice)
    candidate <- normalize_psd_source_entry_scalar(preferred_tab)
    if (!is.null(candidate) && candidate %in% allowed_tabs) return(candidate)

    default_tab <- "Current vs. Average"
    if (default_tab %in% allowed_tabs) return(default_tab)

    allowed_tabs[[1]]
  }

  target_main_tab_for_source <- function(current_tab, source_choice) {
    if (!(source_choice %in% c("psd", "wasde"))) {
      restore_target <- non_psd_main_tab_restore_target()
      if (!is.null(restore_target)) {
        return(resolve_non_psd_main_tab_target(source_choice, restore_target))
      }
    }

    normalize_main_tab_for_source(current_tab, source_choice)
  }

  main_tabs_profile_for_source <- function(source_choice) {
    normalized_source <- normalize_psd_source_entry_scalar(source_choice)
    if (identical(normalized_source, "psd")) return("psd")
    if (identical(normalized_source, "nass")) return("wasde")
    if (identical(normalized_source, "wasde")) return("wasde")
    "non_psd"
  }

  main_tabs_expected_count_for_source <- function(source_choice) {
    length(allowed_main_tabs_for_source(source_choice))
  }

  send_main_tabs_safe_select <- function(target_tab, source_choice, reason, delay_ms = 0L) {
    target_tab <- normalize_psd_source_entry_scalar(target_tab)
    source_choice <- normalize_psd_source_entry_scalar(source_choice) %||% "export_sales"
    if (is.null(target_tab)) return(invisible(FALSE))

    message <- list(
      tab = target_tab,
      source = source_choice,
      profile = main_tabs_profile_for_source(source_choice),
      expected_count = main_tabs_expected_count_for_source(source_choice),
      reason = reason,
      delay_ms = delay_ms,
      max_attempts = 24L,
      retry_delay_ms = 75L,
      request_id = paste(
        source_choice,
        target_tab,
        reason,
        as.integer(isolate(main_tabs_render_nonce())),
        as.numeric(Sys.time()),
        sep = "|"
      )
    )
    session$userData$last_main_tabs_safe_select_request <- message
    session$sendCustomMessage("selectMainTabWhenProfileReady", message)

    invisible(TRUE)
  }

  schedule_main_tabs_safe_select <- function(target_tab, source_choice, reason, delay_ms = 0L) {
    target_tab <- normalize_psd_source_entry_scalar(target_tab)
    source_choice <- normalize_psd_source_entry_scalar(source_choice) %||% "export_sales"
    if (is.null(target_tab)) return(invisible(FALSE))

    session$onFlushed(function() {
      send_main_tabs_safe_select(target_tab, source_choice, reason, delay_ms = delay_ms)
    }, once = TRUE)

    invisible(TRUE)
  }

  bump_main_tabs_render_nonce <- function() {
    main_tabs_render_nonce(as.integer(isolate(main_tabs_render_nonce())) + 1L)
  }

  bump_map_surface_refresh_nonce <- function() {
    current_generation <- as.integer(isolate(map_surface_refresh_nonce()))
    next_generation <- current_generation + 1L
    map_surface_refresh_nonce(next_generation)
    record_cache_body_execution(
      session,
      "map_surface_refresh_nonce_bumped",
      details = list(
        source = isolate(input$data_source_choice %||% NULL),
        active_tab = isolate(input$main_tabs_panel %||% NULL),
        previous_generation = current_generation,
        next_generation = next_generation
      )
    )
  }

  capture_psd_source_entry_context <- function(source_choice, previous_source_choice) {
    list(
      source_choice = normalize_psd_source_entry_scalar(source_choice),
      previous_source_choice = normalize_psd_source_entry_scalar(previous_source_choice),
      visible_country = normalize_psd_source_entry_scalar(tryCatch(input$country_choice, error = function(...) NULL)),
      raw_basis = normalize_psd_source_entry_scalar(tryCatch(input$basis_choice, error = function(...) NULL)),
      basis_input_scope = normalize_psd_source_entry_scalar(session$userData$basis_input_scope),
      remembered_non_psd_basis = normalize_psd_source_entry_scalar(read_remembered_basis_choice_state("non_psd")),
      remembered_psd_basis = normalize_psd_source_entry_scalar(read_remembered_basis_choice_state("psd")),
      raw_unit = normalize_psd_source_entry_scalar(tryCatch(input$unit_choice, error = function(...) NULL)),
      unit_input_scope = normalize_psd_source_entry_scalar(session$userData$unit_choice_input_scope)
    )
  }

  is_direct_psd_source_entry_context <- function(source_entry_context = NULL) {
    if (!is.list(source_entry_context)) return(FALSE)
    source_choice <- normalize_psd_source_entry_scalar(source_entry_context$source_choice)
    previous_source_choice <- normalize_psd_source_entry_scalar(source_entry_context$previous_source_choice)

    identical(source_choice, "psd") && !identical(previous_source_choice, "psd")
  }

  resolve_psd_transition_country_candidate <- function(candidate, default = NULL) {
    candidate <- as.character(candidate %||% character(0))
    candidate <- candidate[!is.na(candidate) & nzchar(candidate)]

    if (length(candidate) == 0) {
      return(default)
    }

    candidate <- candidate[[1]]

    canonical_candidate <- if (exists("canonicalize_notes_country_codes", mode = "function")) {
      canonicalize_notes_country_codes(candidate)
    } else {
      candidate
    }

    canonical_candidate <- as.character(canonical_candidate %||% character(0))
    canonical_candidate <- canonical_candidate[!is.na(canonical_candidate) & nzchar(canonical_candidate)]

    if (length(canonical_candidate) > 0) {
      return(canonical_candidate[[1]])
    }

    default
  }

  resolve_psd_transition_country_target <- function(default = "GRAND_TOTAL", source_entry_context = NULL) {
    if (is_direct_psd_source_entry_context(source_entry_context)) {
      visible_source_country <- resolve_psd_transition_country_candidate(
        candidate = source_entry_context$visible_country,
        default = NULL
      )

      if (!is.null(visible_source_country) && nzchar(visible_source_country)) {
        return(visible_source_country)
      }
    }

    pending_sidebar_country <- isolate(pending_sidebar_country_target())
    pending_map_country <- if (exists("pending_psd_map_country_target", mode = "function")) {
      isolate(pending_psd_map_country_target())
    } else {
      NULL
    }
    canonical_country <- if (exists("read_canonical_psd_country", mode = "function")) {
      isolate(read_canonical_psd_country())
    } else {
      NULL
    }
    sidebar_country <- tryCatch(input$country_choice, error = function(...) NULL)
    map_country <- if (exists("map_selected_country", mode = "function")) {
      isolate(map_selected_country())
    } else {
      NULL
    }

    non_grand_sidebar_country <- as.character(sidebar_country %||% character(0))
    non_grand_sidebar_country <- non_grand_sidebar_country[
      !is.na(non_grand_sidebar_country) &
        nzchar(non_grand_sidebar_country) &
        !identical(non_grand_sidebar_country, "GRAND_TOTAL")
    ]

    candidate_values <- c(
      as.character(pending_sidebar_country %||% character(0)),
      as.character(pending_map_country %||% character(0)),
      non_grand_sidebar_country,
      as.character(canonical_country %||% character(0)),
      as.character(map_country %||% character(0)),
      as.character(sidebar_country %||% character(0))
    )
    candidate_values <- candidate_values[!is.na(candidate_values) & nzchar(candidate_values)]

    if (length(candidate_values) == 0) {
      return(default)
    }

    for (candidate_value in candidate_values) {
      resolved_candidate <- resolve_psd_transition_country_candidate(
        candidate = candidate_value,
        default = NULL
      )

      if (!is.null(resolved_candidate) && nzchar(resolved_candidate)) {
        return(resolved_candidate)
      }
    }

    default
  }

  resolve_psd_source_entry_basis <- function(
    commodity_choice,
    target_tab,
    valid_basis_choices,
    metric_defaults,
    source_entry_context = NULL,
    remembered_psd_basis = NULL
  ) {
    resolve_existing_basis <- function(candidate_basis) {
      candidate_basis <- normalize_psd_source_entry_scalar(candidate_basis)
      resolved_basis <- resolve_basis_choice(
        commodity_choice,
        candidate_basis %||% metric_defaults$basis_choice,
        target_tab,
        source_choice = "psd"
      )

      if (resolved_basis %in% valid_basis_choices) {
        return(resolved_basis)
      }

      metric_defaults$basis_choice
    }

    fallback_candidate <- normalize_psd_source_entry_scalar(remembered_psd_basis) %||% metric_defaults$basis_choice

    if (is_direct_psd_source_entry_context(source_entry_context)) {
      visible_source_country <- resolve_psd_transition_country_candidate(
        candidate = source_entry_context$visible_country,
        default = NULL
      )
      raw_basis <- normalize_psd_source_entry_scalar(source_entry_context$raw_basis)
      raw_basis_scope <- normalize_psd_source_entry_scalar(source_entry_context$basis_input_scope)
      remembered_non_psd_basis <- normalize_psd_source_entry_scalar(source_entry_context$remembered_non_psd_basis)
      source_basis_candidate <- if (identical(raw_basis_scope, "non_psd") && !is.null(raw_basis)) {
        raw_basis
      } else {
        remembered_non_psd_basis %||% raw_basis
      }

      if (identical(visible_source_country, "GRAND_TOTAL")) {
        return(list(
          basis = resolve_existing_basis("inshell_eq"),
          reason = "world_force_inshell",
          candidate = source_basis_candidate %||% "inshell_eq"
        ))
      }

      if (
        !is.null(visible_source_country) &&
        !identical(visible_source_country, "GRAND_TOTAL") &&
        source_basis_candidate %in% c("milled_eq", "rough_eq", "shelled_eq", "shelled_basis", "inshell_eq")
      ) {
        carried_basis <- resolve_basis_choice(
          commodity_choice,
          source_basis_candidate,
          target_tab,
          source_choice = "psd"
        )

        if (carried_basis %in% valid_basis_choices) {
          return(list(
            basis = carried_basis,
            reason = "carry_source_basis",
            candidate = source_basis_candidate
          ))
        }
      }
    }

    list(
      basis = resolve_existing_basis(fallback_candidate),
      reason = "existing_fallback",
      candidate = fallback_candidate
    )
  }

  resolve_psd_source_entry_unit <- function(
    metric_defaults,
    valid_unit_choices,
    target_metric,
    source_entry_context = NULL
  ) {
    default_unit <- metric_defaults$unit_choice
    if (!(default_unit %in% valid_unit_choices) && length(valid_unit_choices) > 0) {
      default_unit <- valid_unit_choices[[1]]
    }

    if (is_direct_psd_source_entry_context(source_entry_context)) {
      raw_unit <- normalize_psd_source_entry_scalar(source_entry_context$raw_unit)
      raw_unit_scope <- normalize_psd_source_entry_scalar(source_entry_context$unit_input_scope)
      if (
        raw_unit_scope %in% c("non_psd", "nass") &&
        !is.null(raw_unit) &&
        raw_unit %in% valid_unit_choices
      ) {
        return(raw_unit)
      }

      remembered_unit <- normalize_psd_source_entry_scalar(session$userData$psd_quantity_unit_choice_state)
      if (!is.null(remembered_unit) && remembered_unit %in% valid_unit_choices) {
        return(remembered_unit)
      }

      return(default_unit)
    }

    target_unit <- current_psd_quantity_unit_choice_safe(
      default = default_unit,
      metric_code = target_metric,
      source_choice = "psd"
    )
    if (target_unit %in% valid_unit_choices) target_unit else default_unit
  }

  resolve_psd_map_bottom_view_entry_target <- function(target_country = NULL, default = "summary") {
    target_country <- as.character(target_country %||% character(0))
    target_country <- target_country[!is.na(target_country) & nzchar(target_country)]

    if (length(target_country) > 0 && !identical(target_country[[1]], "GRAND_TOTAL")) {
      return("matrix")
    }

    default
  }

  queue_psd_map_bottom_view_entry_target <- function(target_country = NULL, default = "summary") {
    target_country <- as.character(target_country %||% character(0))
    target_country <- target_country[!is.na(target_country) & nzchar(target_country)]

    if (length(target_country) == 0) {
      target_country <- resolve_psd_transition_country_target(default = "GRAND_TOTAL")
    } else {
      target_country <- target_country[[1]]
    }

    target_view <- resolve_psd_map_bottom_view_entry_target(
      target_country = target_country,
      default = default
    )
    psd_map_bottom_view_entry_target(target_view)
    target_view
  }

  consume_psd_map_bottom_view_entry_target <- function(default = NULL) {
    target_view <- isolate(psd_map_bottom_view_entry_target())

    if (!is.null(target_view) && target_view %in% c("summary", "matrix")) {
      psd_map_bottom_view_entry_target(NULL)
      return(target_view)
    }

    default
  }

  build_psd_source_transition_state <- function(source_entry_context = NULL, preferred_tab = NULL) {
    preferred_tab <- normalize_psd_source_entry_scalar(preferred_tab %||% input$main_tabs_panel %||% NULL)
    target_tab <- normalize_main_tab_for_source(preferred_tab, "psd")
    target_frequency <- "monthly"
    direct_country_candidate <- if (is_direct_psd_source_entry_context(source_entry_context)) {
      resolve_psd_transition_country_candidate(source_entry_context$visible_country, default = NULL)
    } else {
      NULL
    }
    target_country <- resolve_psd_transition_country_target(source_entry_context = source_entry_context)
    target_country_reason <- if (!is.null(direct_country_candidate) && nzchar(direct_country_candidate)) {
      "visible_source_country"
    } else {
      "existing_fallback"
    }
    commodity_choice <- if (!is.null(input$commodity_choice) && nzchar(input$commodity_choice)) input$commodity_choice else default_commodity_choice_value()
    metric_choices <- get_metric_choices_for_context(
      active_tab = target_tab,
      source_choice = "psd",
      data_frequency = target_frequency,
      map_display_mode = if (!is.null(input$map_comparison_mode)) input$map_comparison_mode else "current"
    )
    target_metric <- sanitize_metric_for_choices(
      input$metric_choice,
      metric_choices,
      preferred_metric = default_metric_for_source("psd")
    )
    metric_defaults <- resolve_psd_metric_defaults(target_metric)
    valid_unit_choices <- unname(unit_choices_for_context("psd", target_metric))
    valid_basis_choices <- unname(basis_choices_for_commodity(commodity_choice, target_tab, "psd"))
    remembered_psd_basis <- normalize_psd_source_entry_scalar(source_entry_context$remembered_psd_basis) %||%
      normalize_psd_source_entry_scalar(read_remembered_basis_choice_state("psd"))
    basis_decision <- resolve_psd_source_entry_basis(
      commodity_choice = commodity_choice,
      target_tab = target_tab,
      valid_basis_choices = valid_basis_choices,
      metric_defaults = metric_defaults,
      source_entry_context = source_entry_context,
      remembered_psd_basis = remembered_psd_basis
    )
    target_basis <- basis_decision$basis

    target_unit <- resolve_psd_source_entry_unit(
      metric_defaults = metric_defaults,
      valid_unit_choices = valid_unit_choices,
      target_metric = target_metric,
      source_entry_context = source_entry_context
    )

    target_state <- list(
      tab = target_tab,
      frequency = target_frequency,
      country = target_country,
      metric = target_metric,
      metric_choices = metric_choices,
      unit = target_unit,
      unit_choices = unit_choices_for_context("psd", target_metric),
      basis = target_basis,
      target_country_reason = target_country_reason,
      target_country_candidate = direct_country_candidate,
      target_basis_reason = basis_decision$reason,
      target_basis_candidate = basis_decision$candidate
    )

    psd_transition_trace(
      event = "build_transition_state",
      reason = "source_entry_default",
      details = list(
        action = "build_target_state",
        target_tab = target_state$tab,
        target_country = target_state$country,
        target_frequency = target_state$frequency,
        target_metric = target_state$metric,
        target_unit = target_state$unit,
        target_basis = target_state$basis,
        target_country_reason = target_state$target_country_reason,
        target_basis_reason = target_state$target_basis_reason,
        target_basis_candidate = target_state$target_basis_candidate
      ),
      resolved_basis = target_state$basis
    )

    target_state
  }

  current_source_choice_safe <- function(default = runtime_default_source_choice()) {
    "vp_trade"
  }

  current_psd_source_transition_state <- function() {
    source_choice <- current_source_choice_safe()
    if (!isTRUE(psd_source_transition_active()) || !identical(source_choice, "psd")) {
      return(NULL)
    }

    psd_source_transition_state()
  }

  psd_transition_inputs_match_target <- function(target_state = current_psd_source_transition_state()) {
    if (is.null(target_state)) {
      return(FALSE)
    }

    identical(current_source_choice_safe(), "psd") &&
      identical(current_data_frequency_safe(), target_state$frequency) &&
      identical(effective_main_metric(), target_state$metric) &&
      identical(current_unit_choice_safe(), target_state$unit) &&
      identical(current_basis_choice_safe(), target_state$basis) &&
      identical(current_main_tab_safe(source_choice = "psd"), target_state$tab)
  }

  current_data_frequency_safe <- function(default = "weekly") {
    source_choice <- current_source_choice_safe()
    input_frequency <- tryCatch(input$data_frequency, error = function(...) NULL)
    if (identical(source_choice, "psd") || identical(source_choice, "wasde") || identical(source_choice, "nass") || identical(source_choice, "vp_trade")) {
      return("monthly")
    }

    transition_state <- current_psd_source_transition_state()
    if (!is.null(transition_state)) {
      return(transition_state$frequency)
    }

    if (!is.null(input_frequency) && input_frequency %in% c("weekly", "monthly")) {
      input_frequency
    } else {
      default
    }
  }

  current_unit_choice_safe <- function(default = "lbs") {
    source_choice <- current_source_choice_safe()
    transition_state <- current_psd_source_transition_state()
    unit_choice <- tryCatch(input$unit_choice, error = function(...) NULL)

    if (!is.null(transition_state)) {
      return(transition_state$unit)
    }

    if (identical(source_choice, "psd")) {
      metric_code <- effective_main_metric()
      psd_defaults <- resolve_psd_metric_defaults(metric_code)
      return(current_psd_quantity_unit_choice_safe(
        default = psd_defaults$unit_choice,
        metric_code = metric_code,
        source_choice = source_choice
      ))
    }

    if (identical(source_choice, "wasde")) {
      metric_code <- effective_main_metric()
      valid_choices <- unname(unit_choices_for_context(source_choice, metric_code))
      resolved_default <- default_unit_choice_for_context(source_choice, metric_code)

      if (!is.null(unit_choice) && nzchar(unit_choice) && unit_choice %in% valid_choices) {
        return(unit_choice)
      }

      return(resolved_default)
    }

    if (identical(source_choice, "nass")) {
      metric_code <- effective_main_metric()
      valid_choices <- unname(unit_choices_for_context(source_choice, metric_code))
      resolved_default <- default_unit_choice_for_context(source_choice, metric_code)
      nass_metric_scope <- session$userData$nass_unit_choice_metric_scope

      if (
        identical(nass_metric_scope, metric_code) &&
        !is.null(unit_choice) &&
        nzchar(unit_choice) &&
        unit_choice %in% valid_choices
      ) {
        return(unit_choice)
      }

      return(resolved_default)
    }

    unit_scope <- if (identical(source_choice, "nass")) {
      "nass"
    } else if (identical(source_choice, "psd")) {
      "psd"
    } else if (identical(source_choice, "wasde")) {
      "wasde"
    } else {
      "non_psd"
    }
    valid_choices <- unname(unit_choices_for_context(source_choice, effective_main_metric()))
    raw_unit_scope <- session$userData$unit_choice_input_scope
    vp_pending_target_unit <- vp_trade_pending_default_unit_target(metric_code = effective_main_metric())
    if (
      identical(source_choice, "vp_trade") &&
      isTRUE(isolate(vp_trade_unit_default_pending())) &&
      !is.null(vp_pending_target_unit) &&
      vp_pending_target_unit %in% valid_choices
    ) {
      return(vp_pending_target_unit)
    }
    if (
      identical(raw_unit_scope, unit_scope) &&
      !is.null(unit_choice) &&
      nzchar(unit_choice) &&
      unit_choice %in% valid_choices
    ) {
      return(unit_choice)
    }

    default
  }

  basis_choice_scope_for_source <- function(source_choice = current_source_choice_safe()) {
    if (identical(source_choice, "psd")) {
      return("psd")
    }

    if (identical(source_choice, "nass")) {
      return("nass")
    }

    "non_psd"
  }

  remembered_basis_choice_state_key <- function(scope = basis_choice_scope_for_source()) {
    paste0("basis_choice_state_", scope)
  }

  read_remembered_basis_choice_state <- function(scope = basis_choice_scope_for_source()) {
    session$userData[[remembered_basis_choice_state_key(scope)]]
  }

  mark_pending_programmatic_basis_update <- function(basis_choice, scope = basis_choice_scope_for_source()) {
    session$userData$pending_programmatic_basis_update <- list(
      basis = basis_choice,
      scope = scope
    )
    invisible(basis_choice)
  }

  read_pending_programmatic_basis_update <- function() {
    session$userData$pending_programmatic_basis_update
  }

  clear_pending_programmatic_basis_update <- function() {
    session$userData$pending_programmatic_basis_update <- NULL
    invisible(NULL)
  }

  write_remembered_basis_choice_state <- function(basis_choice, scope = basis_choice_scope_for_source()) {
    session$userData[[remembered_basis_choice_state_key(scope)]] <- basis_choice
    psd_transition_trace(
      event = "write_remembered_basis",
      reason = if (identical(scope, "psd")) "basis_input_persist" else "explicit_reset",
      details = list(
        action = "write_remembered_basis",
        write_scope = scope,
        write_basis = basis_choice
      ),
      resolved_basis = basis_choice
    )
    invisible(basis_choice)
  }

  current_basis_choice_safe <- function(default = census_default_basis_choice()) {
    source_choice <- current_source_choice_safe()
    basis_scope <- basis_choice_scope_for_source(source_choice)
    active_tab <- current_main_tab_safe()
    commodity_choice <- tryCatch({
      input_commodity <- input$commodity_choice
      if (length(input_commodity) == 1L && !is.na(input_commodity) && nzchar(input_commodity)) input_commodity else default_commodity_choice_value()
    }, error = function(...) default_commodity_choice_value())
    remembered_basis <- read_remembered_basis_choice_state(basis_scope)
    pending_basis_update <- read_pending_programmatic_basis_update()
    raw_basis <- tryCatch({
      input_basis <- input$basis_choice
      if (length(input_basis) == 1L && !is.na(input_basis) && nzchar(input_basis)) input_basis else NULL
    }, error = function(...) NULL)
    raw_basis_scope <- session$userData$basis_input_scope
    raw_basis_matches_scope <- identical(raw_basis_scope, basis_scope)

    resolve_candidate_basis <- function(candidate_basis) {
      if (is.null(candidate_basis) || length(candidate_basis) == 0L || is.na(candidate_basis[[1]]) || !nzchar(candidate_basis[[1]])) return(NULL)
      candidate_basis <- candidate_basis[[1]]

      resolved_basis <- resolve_basis_choice(
        commodity_choice,
        candidate_basis,
        active_tab,
        source_choice = source_choice
      )
      valid_choices <- unname(basis_choices_for_commodity(commodity_choice, active_tab, source_choice))

      if (length(resolved_basis) == 1L && !is.na(resolved_basis) && resolved_basis %in% valid_choices) resolved_basis else NULL
    }

    transition_state <- current_psd_source_transition_state()
    branch_name <- NULL
    resolved_basis <- NULL
    if (!is.null(transition_state)) {
      branch_name <- "transition"
      resolved_basis <- transition_state$basis
    }

    if (
      is.null(resolved_basis) &&
      !is.null(pending_basis_update) &&
      identical(pending_basis_update$scope, basis_scope)
    ) {
      raw_basis_conflicts_with_pending <- raw_basis_matches_scope &&
        !is.null(raw_basis) &&
        !identical(raw_basis, pending_basis_update$basis)

      if (!isTRUE(raw_basis_conflicts_with_pending)) {
        resolved_pending_basis <- resolve_candidate_basis(pending_basis_update$basis)
        if (!is.null(resolved_pending_basis)) {
          branch_name <- "pending_scope_match"
          resolved_basis <- resolved_pending_basis
        }
      }
    }

    if (is.null(resolved_basis) && raw_basis_matches_scope) {
      resolved_raw_basis <- resolve_candidate_basis(raw_basis)
      if (!is.null(resolved_raw_basis)) {
        branch_name <- "raw_scope_match"
        resolved_basis <- resolved_raw_basis
      }
    }

    if (is.null(resolved_basis)) {
      resolved_remembered_basis <- resolve_candidate_basis(remembered_basis)
      if (!is.null(resolved_remembered_basis)) {
        branch_name <- "remembered_scope_match"
        resolved_basis <- resolved_remembered_basis
      }
    }

    if (
      is.null(resolved_basis) &&
      identical(source_choice, "nass") &&
      length(raw_basis_scope) == 1L &&
      !is.na(raw_basis_scope) &&
      raw_basis_scope %in% c("non_psd", "psd")
    ) {
      resolved_cross_scope_basis <- resolve_candidate_basis(raw_basis)
      if (!is.null(resolved_cross_scope_basis)) {
        branch_name <- "raw_cross_scope_carryover"
        resolved_basis <- resolved_cross_scope_basis
      }
    }

    if (is.null(resolved_basis) && !identical(source_choice, "nass")) {
      resolved_raw_basis <- resolve_candidate_basis(raw_basis)
      if (!is.null(resolved_raw_basis)) {
        branch_name <- "raw_fallback"
        resolved_basis <- resolved_raw_basis
      }
    }

    if (is.null(resolved_basis)) {
      branch_name <- "default"
      resolved_basis <- resolve_basis_choice(commodity_choice, default, active_tab, source_choice = source_choice)
    }

    trace_signature <- paste(
      branch_name,
      source_choice,
      basis_scope,
      raw_basis %||% "<null>",
      raw_basis_scope %||% "<null>",
      remembered_basis %||% "<null>",
      resolved_basis %||% "<null>",
      sep = "|"
    )

    if (!identical(isolate(session$userData$psd_last_basis_resolution_signature), trace_signature)) {
      session$userData$psd_last_basis_resolution_signature <- trace_signature
      psd_transition_trace(
        event = "resolve_basis_safe",
        reason = branch_name,
        details = list(
          action = "resolve_basis",
          basis_scope = basis_scope,
          commodity = commodity_choice,
          active_tab = active_tab,
          raw_basis_candidate = raw_basis,
          remembered_basis_candidate = remembered_basis
        ),
        resolved_basis = resolved_basis
      )
    }

    resolved_basis
  }

  hybrid_trade_flow_choice <- function() {
    selected_flow <- if (!is.null(input$hybrid_trade_flow_choice)) input$hybrid_trade_flow_choice else "export"
    if (selected_flow %in% c("export", "import")) selected_flow else "export"
  }

  vp_trade_flow_choice <- function() {
    selected_flow <- if (!is.null(input$vp_trade_flow_choice)) input$vp_trade_flow_choice else "export"
    if (selected_flow %in% c("export", "import")) selected_flow else "export"
  }

  hybrid_mode_choice <- function() {
    if (identical(hybrid_trade_flow_choice(), "import")) {
      return("standard")
    }

    selected_mode <- if (!is.null(input$hybrid_mode_choice)) input$hybrid_mode_choice else "standard"
    if (selected_mode %in% c("standard", "weekly_imputed")) selected_mode else "standard"
  }

  is_hybrid_import_mode <- function() {
    identical(if (!is.null(input$data_source_choice)) input$data_source_choice else "export_sales", "hybrid") &&
      identical(hybrid_trade_flow_choice(), "import")
  }

  source_requires_monthly <- function(source_choice) {
    identical(source_choice, "census") ||
      identical(source_choice, "psd") ||
      identical(source_choice, "wasde") ||
      identical(source_choice, "nass") ||
      (identical(source_choice, "hybrid") && (is_hybrid_import_mode() || !identical(hybrid_mode_choice(), "weekly_imputed")))
  }

  frequency_choices_for_source <- function(source_choice, partner_tab_active = FALSE) {
    if (identical(source_choice, "vp_trade")) {
      return(c("Monthly" = "monthly"))
    }

    if (identical(source_choice, "census")) {
      return(c("Monthly" = "monthly"))
    }

    if (identical(source_choice, "psd")) {
      return(c("Annual" = "monthly"))
    }

    if (identical(source_choice, "wasde")) {
      return(c("Annual" = "monthly"))
    }

    if (identical(source_choice, "nass")) {
      return(c("Annual" = "monthly"))
    }

    if (identical(source_choice, "hybrid")) {
      if (is_hybrid_import_mode()) {
        return(c("Monthly" = "monthly"))
      }

      if (identical(hybrid_mode_choice(), "weekly_imputed")) {
        return(c("Weekly" = "weekly"))
      }

      return(c("Monthly" = "monthly"))
    }

    if (isTRUE(partner_tab_active)) {
      return(c("Weekly" = "weekly"))
    }

    c("Weekly" = "weekly", "Monthly" = "monthly")
  }

  source_supports_year_type <- function(source_choice) {
    if (identical(source_choice, "census")) {
      return(isTRUE(startup_census_fiscal_year_enabled("ui")))
    }

    !(source_choice %in% c("psd", "wasde", "nass"))
  }

  normalize_metric_lock_context <- function(lock_context = "selected_metric") {
    allowed_contexts <- c("selected_metric", "mixed_row", "historical_row")
    context_value <- trimws(as.character(lock_context %||% "selected_metric"))
    context_value <- context_value[!is.na(context_value) & nzchar(context_value)]

    if (length(context_value) == 0L) {
      return("selected_metric")
    }

    context_value <- context_value[[1L]]
    if (!(context_value %in% allowed_contexts)) {
      return("selected_metric")
    }

    context_value
  }

  nass_annual_year_type_choices <- function(metric_code = NULL) {
    fallback_choices <- c(
      "Calendar Year" = "calendar_year",
      "Marketing Year" = "marketing_year",
      "Forecast" = "forecast"
    )

    source_df <- tryCatch(rice_data_nass_annual, error = function(...) NULL)
    if (!is.data.frame(source_df) || nrow(source_df) == 0 || !("annual_year_type" %in% names(source_df))) {
      return(fallback_choices)
    }

    metric_route <- nass_metric_route_for_code(metric_code)
    metric_row_id <- trimws(as.character(metric_route$metric_id %||% ""))
    if (nzchar(metric_row_id) && "metric_id" %in% names(source_df)) {
      source_df <- source_df[trimws(as.character(source_df$metric_id)) == metric_row_id, , drop = FALSE]

      if (nrow(source_df) > 0L && length(metric_route$metric_source_ids) > 0L && "metric_source_id" %in% names(source_df)) {
        source_df_source_filtered <- source_df[trimws(as.character(source_df$metric_source_id)) %in% metric_route$metric_source_ids, , drop = FALSE]
        if (nrow(source_df_source_filtered) > 0L) {
          source_df <- source_df_source_filtered
        }
      }
    }

    if (nrow(source_df) == 0L) {
      return(fallback_choices[FALSE])
    }

    available_types <- unique(trimws(as.character(source_df$annual_year_type)))
    available_types <- available_types[!is.na(available_types) & nzchar(available_types)]
    if (length(available_types) == 0L) {
      return(fallback_choices[FALSE])
    }

    choices <- fallback_choices[unname(fallback_choices) %in% available_types]

    metric_code_value <- trimws(as.character(metric_code %||% ""))
    metric_code_value <- metric_code_value[!is.na(metric_code_value) & nzchar(metric_code_value)]
    if (length(metric_code_value) > 0L && identical(metric_code_value[[1L]], "nass_yield")) {
      choices <- choices[unname(choices) != "forecast"]
    }

    choices
  }

  current_nass_annual_year_type_safe <- function(default = NULL, metric_code = effective_main_metric()) {
    choices <- nass_annual_year_type_choices(metric_code = metric_code)
    valid_values <- unname(choices)
    input_value <- tryCatch(input$nass_annual_year_type, error = function(...) NULL)
    input_value <- trimws(as.character(input_value %||% ""))
    input_value <- input_value[!is.na(input_value) & nzchar(input_value)]
    if (length(input_value) > 0L && input_value[[1L]] %in% valid_values) {
      return(input_value[[1L]])
    }

    if (!is.null(default) && default %in% valid_values) {
      return(default)
    }

    if (length(valid_values) == 0L) {
      fallback_default <- trimws(as.character(default %||% "calendar_year"))
      fallback_default <- fallback_default[!is.na(fallback_default) & nzchar(fallback_default)]
      if (length(fallback_default) > 0L) return(fallback_default[[1L]])
      return("calendar_year")
    }

    valid_values[[1L]]
  }

  observeEvent(list(input$data_source_choice, input$metric_choice), {
    if (!identical(current_source_choice_safe(default = NULL), "nass")) {
      return()
    }

    metric_code <- effective_main_metric()
    choices <- nass_annual_year_type_choices(metric_code = metric_code)
    if (length(choices) == 0L) {
      return()
    }

    updateRadioButtons(
      session,
      "nass_annual_year_type",
      choices = choices,
      selected = current_nass_annual_year_type_safe(metric_code = metric_code)
    )
  }, ignoreInit = FALSE)

  year_type_choices_for_source <- function(source_choice) {
    if (!source_supports_year_type(source_choice)) {
      return(character(0))
    }

    non_psd_year_type_choices()
  }

  current_non_psd_year_type_safe <- function(source_choice = current_source_choice_safe(),
                                             default = "marketing") {
    if (!source_supports_year_type(source_choice)) {
      return("marketing")
    }

    valid_choices <- unname(year_type_choices_for_source(source_choice))

    input_value <- tryCatch(input$year_type_choice, error = function(...) NULL)
    normalized_input <- normalize_non_psd_year_type(input_value, default = default)
    if (!is.null(input_value) && normalized_input %in% valid_choices) {
      return(normalized_input)
    }

    remembered_value <- tryCatch(isolate(last_non_psd_year_type()), error = function(...) default)
    normalized_remembered <- normalize_non_psd_year_type(remembered_value, default = default)
    if (normalized_remembered %in% valid_choices) {
      return(normalized_remembered)
    }

    normalize_non_psd_year_type(default, default = "marketing")
  }

  census_trade_flow_state <- reactiveVal("export")
  vp_trade_flow_state <- reactiveVal("export")

  emphasize_current_avg_label_text <- reactive({
    source_choice <- current_source_choice_safe()
    year_abbrev <- if (identical(current_non_psd_year_type_safe(source_choice = source_choice), "fiscal")) "FY" else "MY"

    paste0("Emphasize Current ", year_abbrev, " + Historical Avg")
  })

  effective_trade_flow_for_source <- function(source_choice, trade_flow_value = NULL, vp_trade_flow_value = NULL) {
    if (identical(source_choice, "hybrid")) {
      return(hybrid_trade_flow_choice())
    }

    if (identical(source_choice, "vp_trade")) {
      if (!is.null(vp_trade_flow_value) && vp_trade_flow_value %in% c("export", "import")) {
        return(vp_trade_flow_value)
      }

      input_value <- tryCatch(input$vp_trade_flow_choice, error = function(...) NULL)
      if (!is.null(input_value) && input_value %in% c("export", "import")) {
        return(input_value)
      }

      state_value <- tryCatch(isolate(vp_trade_flow_state()), error = function(...) NULL)
      if (!is.null(state_value) && state_value %in% c("export", "import")) {
        return(state_value)
      }

      return("export")
    }

    if (!identical(source_choice, "census")) return("n/a")

    if (!is.null(trade_flow_value) && trade_flow_value %in% c("export", "import")) {
      return(trade_flow_value)
    }

    state_value <- tryCatch(isolate(census_trade_flow_state()), error = function(...) NULL)
    if (!is.null(state_value) && state_value %in% c("export", "import")) {
      return(state_value)
    }

    "export"
  }

  top_partner_filter_label_text <- reactive({
    source_choice <- current_source_choice_safe()
    trade_flow_value <- if (identical(source_choice, "census")) input$census_trade_flow_choice else NULL
    vp_flow_value <- if (identical(source_choice, "vp_trade")) input$vp_trade_flow_choice else NULL
    flow_label <- if (identical(effective_trade_flow_for_source(source_choice, trade_flow_value, vp_flow_value), "import")) "import" else "export"
    map_mode_active <- is_effective_map_tab_active(source_choice = source_choice)

    if (isTRUE(map_mode_active)) {
      return(list(
        top5 = "Shade top 5 only",
        top10 = "Shade top 10 only",
        top20 = "Shade top 20 only"
      ))
    }

    list(
      top5 = paste0("Emphasize top 5 ", flow_label, " partners"),
      top10 = paste0("Emphasize top 10 ", flow_label, " partners"),
      top20 = paste0("Emphasize top 20 ", flow_label, " partners")
    )
  })

  map_top_n_selection <- reactiveVal(20L)

  set_map_top_n_selection <- function(selection) {
    normalized_selection <- if (is.null(selection)) NULL else as.integer(selection[[1]])

    if (!identical(isolate(map_top_n_selection()), normalized_selection)) {
      map_top_n_selection(normalized_selection)
    }
  }

  observe({
    top_partner_labels <- top_partner_filter_label_text()
    top_n_selection <- map_top_n_selection()

    updateCheckboxInput(session, "top5_only", label = top_partner_labels$top5)
    updateCheckboxInput(session, "top10_only", label = top_partner_labels$top10)
    updateCheckboxInput(session, "map_top5_only", label = top_partner_labels$top5, value = identical(top_n_selection, 5L))
    updateCheckboxInput(session, "map_top10_only", label = top_partner_labels$top10, value = identical(top_n_selection, 10L))
    updateCheckboxInput(session, "map_top20_only", label = top_partner_labels$top20, value = identical(top_n_selection, 20L))
  })

  observeEvent(input$map_top5_only, {
    if (isTRUE(input$map_top5_only)) {
      set_map_top_n_selection(5L)
      return()
    }

    if (identical(isolate(map_top_n_selection()), 5L)) {
      set_map_top_n_selection(NULL)
    }
  }, ignoreInit = TRUE)

  observeEvent(input$map_top10_only, {
    if (isTRUE(input$map_top10_only)) {
      set_map_top_n_selection(10L)
      return()
    }

    if (identical(isolate(map_top_n_selection()), 10L)) {
      set_map_top_n_selection(NULL)
    }
  }, ignoreInit = TRUE)

  observeEvent(input$map_top20_only, {
    if (isTRUE(input$map_top20_only)) {
      set_map_top_n_selection(20L)
      return()
    }

    if (identical(isolate(map_top_n_selection()), 20L)) {
      set_map_top_n_selection(NULL)
    }
  }, ignoreInit = TRUE)

  observe({
    updateCheckboxInput(
      session,
      "emphasize_current_avg",
      label = emphasize_current_avg_label_text()
    )
  })

  observe({
    if (!is_effective_map_tab_active()) {
      return()
    }

    valid_modes <- map_display_mode_choices_for_current_context()
    selected_mode <- effective_map_display_mode()

    updateRadioButtons(
      session,
      "map_comparison_mode",
      choices = valid_modes,
      selected = selected_mode
    )
  })

  log_client_perf <- function(tag, details = NULL) {
    perf_console_enabled <- isTRUE(perf_log_enabled())
    perf_runtime_enabled <- isTRUE(runtime_perf_enabled())
    if (!perf_console_enabled && !perf_runtime_enabled) return(invisible(FALSE))

    payload_details <- details %||% list()
    if (!is.list(payload_details)) {
      payload_details <- list(value = payload_details)
    }

    action_id <- payload_details$action_id %||% payload_details$request_action_id %||% NULL
    mutation_seq <- payload_details$mutation_seq %||% payload_details$request_mutation_seq %||% NULL
    action_reason <- payload_details$action_reason %||% payload_details$reason %||% NULL

    enriched_details <- c(
      source_switch_epoch_fields(include_age = TRUE),
      list(
        server_source = input$data_source_choice %||% NULL,
        server_tab = input$main_tabs_panel %||% NULL,
        request_action_id = action_id,
        request_mutation_seq = mutation_seq,
        request_action_reason = action_reason
      ),
      payload_details
    )

    if (perf_console_enabled) {
      detail_suffix <- ""
      if (!is.null(enriched_details) && length(enriched_details) > 0) {
        detail_pairs <- paste(
          names(enriched_details),
          vapply(enriched_details, format_perf_detail_value, character(1)),
          sep = "="
        )
        detail_suffix <- paste0(" | ", paste(detail_pairs, collapse = ", "))
      }

      message(sprintf("[PERF][client] %s%s", tag, detail_suffix))
    }

    if (perf_runtime_enabled) {
      runtime_perf_record(
        event = "client_perf",
        session = session,
        details = c(
          list(tag = as.character(tag)),
          enriched_details
        )
      )
    }

    invisible(TRUE)
  }

  normalize_client_perf_boundary_tag <- function(value, default = "unknown") {
    raw <- trimws(as.character(value %||% default))
    raw <- raw[!is.na(raw) & nzchar(raw)]
    if (length(raw) == 0L) {
      return(default)
    }

    normalized <- tolower(raw[[1L]])
    normalized <- gsub("[^a-z0-9]+", "_", normalized)
    normalized <- gsub("^_+|_+$", "", normalized)
    if (!nzchar(normalized)) {
      return(default)
    }

    normalized
  }

  observeEvent(input$data_frequency, {
    source_choice <- current_source_choice_safe()
    available_choices <- unname(frequency_choices_for_source(source_choice, partner_tab_active = FALSE))

    if (!identical(input$main_tabs_panel, "Market Year Comparison Tool") &&
        !is.null(input$data_frequency) &&
        length(available_choices) > 1 &&
        input$data_frequency %in% available_choices) {
      last_non_partner_frequency(input$data_frequency)
    }
  }, ignoreInit = TRUE)

  observeEvent(input$main_tabs_panel, {
    start_time <- Sys.time()
    active_tab <- input$main_tabs_panel
    source_choice <- current_source_choice_safe()
    requested_frequency <- "none"
    control_update <- FALSE
    resize_requested <- FALSE
    resize_request_id <- NULL

    if (is.null(active_tab)) return()

    if (isTRUE(psd_source_transition_active()) && identical(source_choice, "psd")) {
      return()
    }

    if (identical(source_choice, "psd") && identical(active_tab, "Time Series Analysis Tool")) {
      current_sidebar_country <- as.character(input$country_choice %||% character(0))
      current_sidebar_country <- current_sidebar_country[!is.na(current_sidebar_country) & nzchar(current_sidebar_country)]

      pending_sidebar_country <- as.character(isolate(pending_sidebar_country_target()) %||% character(0))
      pending_sidebar_country <- pending_sidebar_country[!is.na(pending_sidebar_country) & nzchar(pending_sidebar_country)]

      target_country <- as.character(resolve_psd_transition_country_target(default = NULL) %||% character(0))
      target_country <- target_country[!is.na(target_country) & nzchar(target_country)]

      should_seed_time_series_pending_country <-
        (length(current_sidebar_country) == 0 || identical(current_sidebar_country[[1]], "GRAND_TOTAL")) &&
        (length(pending_sidebar_country) == 0 || identical(pending_sidebar_country[[1]], "GRAND_TOTAL")) &&
        length(target_country) > 0 &&
        !identical(target_country[[1]], "GRAND_TOTAL")

      if (isTRUE(should_seed_time_series_pending_country)) {
        pending_sidebar_country_target(target_country[[1]])
        if (exists("write_canonical_psd_country", mode = "function")) {
          try(write_canonical_psd_country(target_country[[1]]), silent = TRUE)
        }
        psd_transition_trace(
          event = "activate_transition_state",
          reason = "source_entry_default",
          details = list(
            action = "seed_time_series_pending_country",
            target_tab = active_tab,
            target_country = target_country[[1]],
            current_sidebar_country = if (length(current_sidebar_country) > 0) current_sidebar_country[[1]] else NULL,
            pending_sidebar_country_before = if (length(pending_sidebar_country) > 0) pending_sidebar_country[[1]] else NULL
          )
        )
      }
    }

    session$sendCustomMessage(
      "toggleCensusCorrectionsSidebar",
      list(hide_sidebar = identical(active_tab, "Census Corrections"))
    )

    if (identical(active_tab, "Market Year Comparison Tool")) {
      if (!source_requires_monthly(source_choice) && !identical(input$data_frequency, "weekly")) {
        requested_frequency <- "weekly"
        control_update <- TRUE
        updateRadioButtons(session, "data_frequency", selected = "weekly")
      }
    } else {
      desired_freq <- last_non_partner_frequency()
      if (!source_requires_monthly(source_choice) && !is.null(desired_freq) && !identical(input$data_frequency, desired_freq)) {
        requested_frequency <- desired_freq
        control_update <- TRUE
        updateRadioButtons(session, "data_frequency", selected = desired_freq)
      }
    }

    # Trigger widget resize only for tab families that actually render plotly surfaces.
    if (should_send_plotly_resize_for_tab(active_tab, source_choice)) {
      resize_requested <- TRUE
      resize_request_id <- next_main_tab_resize_request_id(active_tab, source_choice)
      if (isTRUE(perf_boundary_markers_enabled())) {
        log_client_perf(
          "boundary_server_plotly_resize_sent",
          c(
            source_switch_epoch_fields(include_age = TRUE),
            list(
              boundary = "server_plotly_resize_sent",
              tab = active_tab,
              source = source_choice,
              resize_request_id = resize_request_id,
              observer_elapsed_ms = perf_elapsed_ms(start_time)
            )
          )
        )
      }
      session$sendCustomMessage(
        "forcePlotlyResize",
        c(
          list(tab = active_tab, resize_request_id = resize_request_id),
          source_switch_epoch_fields()
        )
      )
    }

    if (isTRUE(perf_boundary_markers_enabled())) {
      log_client_perf(
        "boundary_server_main_tabs_observer_complete",
        list(
          boundary = "server_main_tabs_observer_complete",
          tab = active_tab,
          source = source_choice,
          requested_frequency = requested_frequency,
          control_update = control_update,
          resize_requested = resize_requested,
          resize_request_id = resize_request_id,
          elapsed_ms = perf_elapsed_ms(start_time)
        )
      )
    }

    log_perf(
      "observeEvent(main_tabs_panel)",
      start_time,
      details = list(
        tab = active_tab,
        source = source_choice,
        frequency = input$data_frequency,
        requested_frequency = requested_frequency,
        control_update = control_update,
        resize_requested = resize_requested,
        resize_request_id = resize_request_id
      )
    )
  }, ignoreInit = TRUE)

  observeEvent(input$client_perf_plotly_resize, {
    if (!isTRUE(perf_boundary_markers_enabled())) return()
    payload <- input$client_perf_plotly_resize
    if (is.null(payload)) return()

    output_id <- payload$target_output_id %||% NULL
    if (is.null(output_id)) return()

    log_client_perf(
      "boundary_server_plotly_resize_recorded",
      list(
        boundary = "server_plotly_resize_recorded",
        target_output_id = output_id,
        tab = payload$tab %||% NULL,
        resize_request_id = payload$resize_request_id %||% NULL,
        target_present_after_paint = payload$target_present_after_paint %||% NULL,
        target_visible_after_paint = payload$target_visible_after_paint %||% NULL,
        target_widget_count_after_paint = payload$target_widget_count_after_paint %||% NULL,
        target_main_svg_count_after_paint = payload$target_main_svg_count_after_paint %||% NULL,
        target_loading_indicator_count_after_paint = payload$target_loading_indicator_count_after_paint %||% NULL,
        client_action_elapsed_ms = payload$action_elapsed_ms %||% NULL,
        client_resize_elapsed_ms = payload$elapsed_ms %||% NULL
      )
    )
  }, ignoreInit = TRUE)

  # Smart default initialization for Custom Comparison Tool (first open only).
  observeEvent(input$main_tabs_panel, {
    if (!identical(input$main_tabs_panel, "Custom Comparison Tool")) return()
    if (isTRUE(custom_comparison_initialized())) return()

    req(effective_main_metric(), input$commodity_choice, input$country_choice, input$data_frequency)

    apply_custom_comparison_panel_targets(build_custom_comparison_reset_targets())

    if (!isTRUE(input$show_metric_grid)) {
      updateCheckboxInput(session, "show_metric_grid", value = TRUE)
    }

    custom_comparison_initialized(TRUE)
  }, ignoreInit = TRUE)

  observeEvent(input$custom_comp_apply_sidebar_country, {
    start_time <- Sys.time()
    target_country <- resolve_custom_comparison_country(input$country_choice)
    panel_targets <- list(
      country_right_2up = target_country,
      country_grid_2 = target_country,
      country_grid_3 = target_country,
      country_grid_4 = target_country
    )

    apply_custom_comparison_panel_targets(panel_targets)

    log_perf(
      "observeEvent(custom_comp_apply_sidebar_country)",
      start_time,
      details = custom_comparison_perf_details(list(
        target_country = target_country,
        target_updates = length(panel_targets)
      ))
    )
  }, ignoreInit = TRUE)

  observeEvent(input$custom_comp_apply_sidebar_type, {
    start_time <- Sys.time()
    target_commodity <- resolve_custom_comparison_commodity(input$commodity_choice)
    panel_targets <- list(
      commodity_right_2up = target_commodity,
      commodity_grid_2 = target_commodity,
      commodity_grid_3 = target_commodity,
      commodity_grid_4 = target_commodity
    )

    apply_custom_comparison_panel_targets(panel_targets)

    log_perf(
      "observeEvent(custom_comp_apply_sidebar_type)",
      start_time,
      details = custom_comparison_perf_details(list(
        target_commodity = target_commodity,
        target_updates = length(panel_targets)
      ))
    )
  }, ignoreInit = TRUE)

  observeEvent(input$custom_comp_apply_sidebar_variable, {
    start_time <- Sys.time()
    target_metric <- sanitize_metric_for_choices(
      effective_main_metric(),
      custom_comparison_metric_choices(),
      preferred_metric = "monthlyexports"
    )
    panel_targets <- list(
      metric_right = target_metric,
      metric_grid_2 = target_metric,
      metric_grid_3 = target_metric,
      metric_grid_4 = target_metric
    )

    apply_custom_comparison_panel_targets(panel_targets)

    log_perf(
      "observeEvent(custom_comp_apply_sidebar_variable)",
      start_time,
      details = custom_comparison_perf_details(list(
        target_metric = target_metric,
        target_updates = length(panel_targets)
      ))
    )
  }, ignoreInit = TRUE)

  observeEvent(input$custom_comp_apply_top_partners, {
    start_time <- Sys.time()
    target_metric <- sanitize_metric_for_choices(
      effective_main_metric(),
      custom_comparison_metric_choices(),
      preferred_metric = "monthlyexports"
    )
    target_commodity <- resolve_custom_comparison_commodity(input$commodity_choice)
    picked_countries <- choose_top_custom_panel_countries(
      metric_code = target_metric,
      commodity_code = target_commodity,
      n = 3
    )
    panel_targets <- list(
      country_right_2up = picked_countries[1],
      country_grid_2 = picked_countries[1],
      country_grid_3 = picked_countries[2],
      country_grid_4 = picked_countries[3]
    )

    apply_custom_comparison_panel_targets(panel_targets)

    log_perf(
      "observeEvent(custom_comp_apply_top_partners)",
      start_time,
      details = custom_comparison_perf_details(list(
        target_metric = target_metric,
        target_commodity = target_commodity,
        picked_1 = perf_scalar_or_default(picked_countries[1]),
        picked_2 = perf_scalar_or_default(picked_countries[2]),
        picked_3 = perf_scalar_or_default(picked_countries[3]),
        target_updates = length(panel_targets)
      ))
    )
  }, ignoreInit = TRUE)

  observeEvent(input$custom_comp_apply_top_commodity, {
    start_time <- Sys.time()
    if (!identical(current_source_choice_safe(default = input$data_source_choice %||% "export_sales"), "vp_trade")) return()

    target_vp_commodity_name <- resolve_custom_comparison_vp_commodity_name(input$vp_commodity_name_choice)
    panel_targets <- list(
      vp_commodity_name_right_2up = target_vp_commodity_name,
      vp_commodity_name_grid_3 = target_vp_commodity_name,
      vp_commodity_name_grid_4 = target_vp_commodity_name
    )

    apply_custom_comparison_panel_targets(panel_targets)

    log_perf(
      "observeEvent(custom_comp_apply_top_commodity)",
      start_time,
      details = custom_comparison_perf_details(list(
        target_vp_commodity_name = perf_scalar_or_default(target_vp_commodity_name),
        target_updates = length(panel_targets)
      ))
    )
  }, ignoreInit = TRUE)

  observeEvent(input$custom_comp_reset_defaults, {
    start_time <- Sys.time()
    panel_targets <- build_custom_comparison_reset_targets()

    apply_custom_comparison_panel_targets(panel_targets)

    log_perf(
      "observeEvent(custom_comp_reset_defaults)",
      start_time,
      details = custom_comparison_perf_details(list(
        target_updates = length(panel_targets),
        country_updates = panel_target_prefix_count(panel_targets, "country_"),
        commodity_updates = panel_target_prefix_count(panel_targets, "commodity_"),
        metric_updates = panel_target_prefix_count(panel_targets, "metric_")
      ))
    )
  }, ignoreInit = TRUE)

  observe({
    start_time <- Sys.time()
    if (isTRUE(psd_source_transition_active())) {
      return()
    }

    metric_choices <- metric_choices_for_current_context()
    selected_metric <- effective_main_metric()
    current_metric <- input$metric_choice
    source_choice <- current_source_choice_safe(default = input$data_source_choice %||% "export_sales")
    force_vp_trade_default_metric <- identical(source_choice, "vp_trade") &&
      isTRUE(isolate(vp_trade_metric_default_pending())) &&
      "ytd_exports" %in% unname(metric_choices)
    if (isTRUE(force_vp_trade_default_metric)) {
      selected_metric <- "ytd_exports"
    } else if (!identical(source_choice, "vp_trade") && isTRUE(isolate(vp_trade_metric_default_pending()))) {
      vp_trade_metric_default_pending(FALSE)
    }
    metric_updated <- FALSE

    if (!is.null(selected_metric) && !identical(current_metric, selected_metric)) {
      updateRadioButtons(
        session,
        "metric_choice",
        choices = metric_choices,
        selected = selected_metric
      )

      metric_updated <- TRUE
    }

    if (isTRUE(force_vp_trade_default_metric) && (isTRUE(metric_updated) || identical(current_metric, selected_metric))) {
      vp_trade_metric_default_pending(FALSE)
    }

    if (metric_updated) {
      log_perf(
        "observe(metric_choice reconcile)",
        start_time,
        details = custom_comparison_perf_details(list(
          current_metric = perf_scalar_or_default(current_metric),
          selected_metric = perf_scalar_or_default(selected_metric),
          force_vp_trade_default_metric = force_vp_trade_default_metric,
          choice_count = length(metric_choices)
        ))
      )
    }
  })

  observe({
    valid_metric_choices <- custom_comparison_metric_choices()
    source_choice <- current_source_choice_safe()
    panel_metric_defaults <- c(
      metric_right = "monthlyexports",
      metric_grid_2 = "monthlyexports",
      metric_grid_3 = "outstandingSales",
      metric_grid_4 = if (identical(source_choice, "vp_trade")) "ytd_value" else "total_commitment"
    )
    custom_comparison_active <- identical(input$main_tabs_panel, "Custom Comparison Tool")

    pending_metric_targets <- isolate(custom_comparison_pending_metric_targets())
    pending_targets_changed <- FALSE

    for (input_id in names(panel_metric_defaults)) {
      current_value <- input[[input_id]]
      stored_value <- isolate(panel_state[[input_id]])
      pending_value <- pending_metric_targets[[input_id]]

      if (!is.null(pending_value) && identical(current_value, pending_value)) {
        pending_metric_targets[[input_id]] <- NULL
        pending_value <- NULL
        pending_targets_changed <- TRUE
      }

      selected_value <- if (!is.null(pending_value)) {
        pending_value
      } else if (!is.null(current_value)) {
        current_value
      } else {
        stored_value
      }

      sanitized_value <- sanitize_metric_for_choices(
        selected_value,
        valid_metric_choices,
        preferred_metric = panel_metric_defaults[[input_id]]
      )

      if (!identical(panel_state[[input_id]], sanitized_value)) {
        panel_state[[input_id]] <- sanitized_value
      }

      if (custom_comparison_active && !is.null(current_value) && !identical(current_value, sanitized_value)) {
        updateSelectInput(session, input_id, selected = sanitized_value)
      }
    }

    if (pending_targets_changed) {
      custom_comparison_pending_metric_targets(pending_metric_targets)
    }
  })

    vp_hierarchy_last_changed <- reactiveVal("vp_group_choice")
    vp_hierarchy_change_nonce <- reactiveVal(0L)

    vp_hierarchy_fanout_context <- function(resolved = NULL) {
      generation <- tryCatch(as.integer(isolate(vp_hierarchy_change_nonce())), error = function(...) NA_integer_)
      last_changed <- tryCatch(as.character(isolate(vp_hierarchy_last_changed())), error = function(...) NA_character_)
      trade_flow <- tryCatch({
        value <- isolate(input$vp_trade_flow_choice %||% "export")
        if (value %in% c("export", "import")) value else "export"
      }, error = function(...) "export")
      group_choice <- tryCatch(isolate(input$vp_group_choice %||% vp_all_choice), error = function(...) vp_all_choice)
      subgroup_choice <- tryCatch(isolate(input$vp_subgroup_choice %||% vp_all_choice), error = function(...) vp_all_choice)
      market_segment_choice <- tryCatch(isolate(input$vp_market_segment_choice %||% vp_all_choice), error = function(...) vp_all_choice)
      commodity_name <- tryCatch(isolate(input$vp_commodity_name_choice %||% "<none>"), error = function(...) "<none>")
      commodity_detail <- tryCatch(isolate(input$commodity_choice %||% "<none>"), error = function(...) "<none>")

      if (is.null(resolved) && exists("resolve_vp_hierarchy_tokens", mode = "function")) {
        resolved <- tryCatch(
          resolve_vp_hierarchy_tokens(group_choice, subgroup_choice, market_segment_choice),
          error = function(...) NULL
        )
      }

      resolution_mode <- resolved$resolution_mode %||% "unknown"
      path_name <- resolved$path_name %||% "unknown"
      signature <- paste(
        trade_flow,
        resolved$group_choice %||% group_choice,
        resolved$subgroup_choice %||% subgroup_choice,
        resolved$market_segment_choice %||% market_segment_choice,
        resolution_mode,
        path_name,
        commodity_name,
        commodity_detail,
        sep = "|"
      )

      list(
        hierarchy_generation = generation,
        hierarchy_last_changed = last_changed %||% NA_character_,
        hierarchy_signature = signature,
        hierarchy_trade_flow = trade_flow,
        hierarchy_group = resolved$group_choice %||% group_choice,
        hierarchy_subgroup = resolved$subgroup_choice %||% subgroup_choice,
        hierarchy_market_segment = resolved$market_segment_choice %||% market_segment_choice,
        hierarchy_resolution_mode = resolution_mode,
        hierarchy_path_name = path_name,
        hierarchy_commodity_name = commodity_name,
        hierarchy_commodity_detail = commodity_detail
      )
    }

    bump_vp_hierarchy_change_nonce <- function(input_id) {
      current_generation <- as.integer(isolate(vp_hierarchy_change_nonce()))
      next_generation <- current_generation + 1L
      vp_hierarchy_change_nonce(next_generation)
      record_cache_body_execution(
        session,
        "vp_hierarchy_change_nonce_bumped",
        details = list(
          source = isolate(input$data_source_choice %||% NULL),
          active_tab = isolate(input$main_tabs_panel %||% NULL),
          input_id = input_id,
          previous_generation = current_generation,
          next_generation = next_generation
        )
      )
    }

    observeEvent(input$vp_group_choice, {
      vp_hierarchy_last_changed("vp_group_choice")
      bump_vp_hierarchy_change_nonce("vp_group_choice")
    }, ignoreInit = TRUE)

    observeEvent(input$vp_subgroup_choice, {
      vp_hierarchy_last_changed("vp_subgroup_choice")
      bump_vp_hierarchy_change_nonce("vp_subgroup_choice")
    }, ignoreInit = TRUE)

    observeEvent(input$vp_market_segment_choice, {
      vp_hierarchy_last_changed("vp_market_segment_choice")
      bump_vp_hierarchy_change_nonce("vp_market_segment_choice")
    }, ignoreInit = TRUE)

    observeEvent(input$vp_reset_hierarchy_filters, {
      if (!identical(current_source_choice_safe(default = input$data_source_choice %||% "export_sales"), "vp_trade")) {
        return()
      }

      updateSelectInput(session, "vp_group_choice", selected = vp_all_choice)
      updateSelectInput(session, "vp_subgroup_choice", selected = vp_all_choice)
      updateSelectInput(session, "vp_market_segment_choice", selected = vp_all_choice)
      vp_hierarchy_last_changed("vp_group_choice")
      bump_vp_hierarchy_change_nonce("vp_reset_hierarchy_filters")
    }, ignoreInit = TRUE)

    observeEvent(list(input$main_tabs_panel, input$vp_trade_flow_choice, input$vp_group_choice, input$vp_subgroup_choice, input$vp_market_segment_choice), {
      if (!identical(input$main_tabs_panel, "Custom Comparison Tool")) return()
      if (!identical(current_source_choice_safe(default = input$data_source_choice %||% "export_sales"), "vp_trade")) return()

      valid_choices <- custom_comparison_vp_commodity_name_choices()
      valid_values <- unique(unname(valid_choices))
      valid_values <- valid_values[!is.na(valid_values) & nzchar(valid_values)]
      if (length(valid_values) == 0L) return()

      current_value <- as.character(input$vp_commodity_name_choice %||% character(0))
      current_value <- current_value[!is.na(current_value) & nzchar(current_value)]
      current_value <- if (length(current_value) > 0L) current_value[[1L]] else NULL
      if (!is.null(current_value) && current_value %in% valid_values) return()

      fallback <- resolve_custom_comparison_vp_commodity_name(current_value)
      if (is.null(fallback) || !nzchar(as.character(fallback))) return()

      updateSelectInput(session, "vp_commodity_name_choice", selected = fallback)
      log_perf(
        "observe(custom comparison vp commodity correction)",
        Sys.time(),
        details = list(
          source = current_source_choice_safe(default = "vp_trade"),
          active_tab = input$main_tabs_panel,
          previous = current_value %||% "<null>",
          fallback = fallback,
          valid_choices = length(valid_values)
        )
      )
    }, ignoreInit = TRUE, priority = 100)

  # Data frequency UI (source-specific control row)
  output$data_frequency_ui <- renderUI({
    surface_refresh_generation <- map_surface_refresh_nonce()
    hierarchy_change_generation <- vp_hierarchy_change_nonce()
    active_tab <- input$main_tabs_panel
    partner_tab_active <- identical(active_tab, "Market Year Comparison Tool")
    source_choice <- if (!is.null(input$data_source_choice)) input$data_source_choice else startup_default_ui_source(default = NULL)
    data_source_choices <- startup_ui_source_choices()
    valid_source_values <- startup_ui_source_values()

    if (length(valid_source_values) == 0L) {
      return(tagList(
        div(
          class = "top-filter-row",
          style = "display: flex; align-items: flex-start; gap: 6px; flex-wrap: wrap;",
          div(class = "top-filter-helper", style = "color: #6c757d;", COMMODITY_DISABLED_SOURCE_MESSAGE)
        )
      ))
    }

    selected_source <- if (source_choice %in% valid_source_values) {
      source_choice
    } else {
      startup_default_ui_source(default = valid_source_values[[1]])
    }

    record_cache_body_execution(
      session,
      "data_frequency_ui_rendered",
      details = c(
        list(
          source = selected_source,
          active_tab = active_tab %||% NULL,
          surface_refresh_generation = surface_refresh_generation,
          hierarchy_change_generation = hierarchy_change_generation,
          vp_trade_flow = isolate(input$vp_trade_flow_choice %||% NULL),
          vp_group = isolate(input$vp_group_choice %||% NULL),
          vp_subgroup = isolate(input$vp_subgroup_choice %||% NULL),
          vp_market_segment = isolate(input$vp_market_segment_choice %||% NULL),
          vp_hierarchy_last_changed = isolate(vp_hierarchy_last_changed())
        ),
        vp_hierarchy_fanout_context()
      )
    )

    supports_year_type <- source_supports_year_type(selected_source)
    year_type_choices <- year_type_choices_for_source(selected_source)
    selected_year_type <- if (isTRUE(supports_year_type)) {
      current_non_psd_year_type_safe(
        source_choice = selected_source,
        default = isolate(last_non_psd_year_type())
      )
    } else {
      "marketing"
    }
    if (!selected_year_type %in% unname(year_type_choices)) {
      selected_year_type <- if (length(year_type_choices) > 0) unname(year_type_choices[[1]]) else "marketing"
    }

    census_mode <- identical(selected_source, "census")
    hybrid_mode <- identical(selected_source, "hybrid")
    hybrid_import_mode <- hybrid_mode && identical(hybrid_trade_flow_choice(), "import")
    census_trade_flow <- isolate(census_trade_flow_state())
    if (!(census_trade_flow %in% c("export", "import"))) {
      census_trade_flow <- "export"
    }
    selected_hybrid_mode <- hybrid_mode_choice()
    selected_hybrid_trade_flow <- hybrid_trade_flow_choice()
    selected_vp_trade_flow <- vp_trade_flow_choice()
    nass_mode <- identical(selected_source, "nass")
    nass_metric_choice <- if (nass_mode) effective_main_metric() else NULL
    nass_year_type_choices <- if (nass_mode) nass_annual_year_type_choices(metric_code = nass_metric_choice) else character(0)
    selected_nass_year_type <- if (nass_mode) current_nass_annual_year_type_safe(metric_code = nass_metric_choice) else NULL

    choices <- frequency_choices_for_source(selected_source, partner_tab_active)
    selected_freq <- if (!is.null(input$data_frequency) && input$data_frequency %in% choices) {
      input$data_frequency
    } else {
      unname(choices[[1]])
    }
    data_frequency_inline <- identical(selected_source, "psd")

    helper_text <- if (hybrid_import_mode) {
      div(class = "top-filter-helper", style = "margin-top: 6px; color: #6c757d;", "Hybrid import mode uses monthly data only.")
    } else if (hybrid_mode && identical(selected_hybrid_mode, "weekly_imputed")) {
      div(
        class = "top-filter-helper",
        style = "margin-top: 6px; color: #6c757d;",
        "Weekly-Imputed Hybrid uses weekly exports only and blends imputed Hybrid history with observed Export Sales extension."
      )
    } else if (hybrid_mode) {
      div(class = "top-filter-helper", style = "margin-top: 6px; color: #6c757d;", "Standard Hybrid uses monthly data only.")
    } else if (identical(selected_source, "psd")) {
      div(class = "top-filter-helper", style = "margin-top: 6px; color: #6c757d;", "PSD uses annual market-year updates only.")
    } else if (nass_mode) {
      div(class = "top-filter-helper", style = "margin-top: 6px; color: #6c757d;", "NASS uses annual QuickStats records only.")
    } else {
      NULL
    }

    vp_trade_mode <- identical(selected_source, "vp_trade")
    vp_filter_data <- if (vp_trade_mode && exists("vp_trade_rows_or_empty", mode = "function")) {
      vp_trade_rows_or_empty(require_non_empty = FALSE)
    } else if (vp_trade_mode && exists("rice_data_vp_trade_monthly", inherits = TRUE) && is.data.frame(rice_data_vp_trade_monthly)) {
      rice_data_vp_trade_monthly
    } else {
      data.frame()
    }
    vp_filter_data <- vp_native_rows_for_choice_lists(vp_filter_data)
    if (vp_trade_mode && "Trade" %in% names(vp_filter_data)) {
      vp_filter_data <- vp_filter_data[vp_filter_data$Trade == selected_vp_trade_flow, , drop = FALSE]
    }

    vp_all_choice <- "__all__"
    selected_vp_group <- vp_normalize_choice_value(isolate(input$vp_group_choice), fallback = vp_all_choice)
    selected_vp_subgroup <- vp_normalize_choice_value(isolate(input$vp_subgroup_choice), fallback = vp_all_choice)
    selected_vp_market_segment <- vp_normalize_choice_value(isolate(input$vp_market_segment_choice), fallback = vp_all_choice)
    faceted_hierarchy_enabled <- isTRUE(vp_faceted_hierarchy_enabled())

    if (isTRUE(faceted_hierarchy_enabled)) {
      hierarchy_choice_state <- vp_resolve_hierarchy_choice_state(
        vp_rows = vp_filter_data,
        selected_group = selected_vp_group,
        selected_subgroup = selected_vp_subgroup,
        selected_market_segment = selected_vp_market_segment,
        preserve_input_id = vp_hierarchy_last_changed()
      )
      selected_vp_group <- hierarchy_choice_state$group_choice
      selected_vp_subgroup <- hierarchy_choice_state$subgroup_choice
      selected_vp_market_segment <- hierarchy_choice_state$market_segment_choice
      vp_group_choices <- hierarchy_choice_state$group_choices
      vp_subgroup_choices <- hierarchy_choice_state$subgroup_choices
      vp_market_segment_choices <- hierarchy_choice_state$market_segment_choices

      vp_commodity_data <- vp_filter_rows_for_hierarchy_choices(
        vp_rows = vp_filter_data,
        group_choice = selected_vp_group,
        subgroup_choice = selected_vp_subgroup,
        market_segment_choice = selected_vp_market_segment,
        native_only = TRUE
      )
      vp_hierarchy_reset_disabled <- isTRUE(hierarchy_choice_state$reset_disabled)
    } else {
      vp_group_values <- if ("Group" %in% names(vp_filter_data)) sort(unique(as.character(vp_filter_data$Group))) else character(0)
      vp_group_values <- vp_group_values[!is.na(vp_group_values) & nzchar(vp_group_values)]
      vp_group_choices <- c("All Groups" = vp_all_choice, stats::setNames(vp_group_values, vp_group_values))
      if (!(selected_vp_group %in% unname(vp_group_choices))) selected_vp_group <- vp_all_choice

      canonical_vp_selection <- canonicalize_vp_hierarchy_selection(
        vp_group_choice = selected_vp_group,
        vp_subgroup_choice = selected_vp_subgroup,
        vp_market_segment_choice = selected_vp_market_segment
      )
      selected_vp_group <- canonical_vp_selection$group_choice
      selected_vp_subgroup <- canonical_vp_selection$subgroup_choice
      selected_vp_market_segment <- canonical_vp_selection$market_segment_choice

      vp_subgroup_data <- if (!identical(selected_vp_group, vp_all_choice)) {
        vp_filter_data[vp_filter_data$Group == selected_vp_group, , drop = FALSE]
      } else {
        vp_filter_data
      }
      vp_subgroup_values <- if ("Subgroup" %in% names(vp_subgroup_data)) sort(unique(as.character(vp_subgroup_data$Subgroup))) else character(0)
      vp_subgroup_values <- vp_subgroup_values[!is.na(vp_subgroup_values) & nzchar(vp_subgroup_values)]
      vp_subgroup_choices <- c("All Subgroups" = vp_all_choice, stats::setNames(vp_subgroup_values, vp_subgroup_values))
      if (!(selected_vp_subgroup %in% unname(vp_subgroup_choices))) selected_vp_subgroup <- vp_all_choice

      vp_market_segment_data <- vp_subgroup_data
      if (!identical(selected_vp_subgroup, vp_all_choice)) {
        vp_market_segment_data <- vp_market_segment_data[vp_market_segment_data$Subgroup == selected_vp_subgroup, , drop = FALSE]
      }
      vp_market_segment_values <- if ("MarketSegment" %in% names(vp_market_segment_data)) sort(unique(as.character(vp_market_segment_data$MarketSegment))) else character(0)
      vp_market_segment_values <- vp_market_segment_values[!is.na(vp_market_segment_values) & nzchar(vp_market_segment_values)]
      vp_market_segment_choices <- c("All Market Segments" = vp_all_choice, stats::setNames(vp_market_segment_values, vp_market_segment_values))
      if (!(selected_vp_market_segment %in% unname(vp_market_segment_choices))) selected_vp_market_segment <- vp_all_choice

      vp_commodity_data <- vp_market_segment_data
      if (!identical(selected_vp_market_segment, vp_all_choice)) {
        vp_commodity_data <- vp_commodity_data[vp_commodity_data$MarketSegment == selected_vp_market_segment, , drop = FALSE]
      }

      vp_hierarchy_reset_disabled <- identical(selected_vp_group, vp_all_choice) &&
        identical(selected_vp_subgroup, vp_all_choice) &&
        identical(selected_vp_market_segment, vp_all_choice)
    }

    vp_commodity_values <- if ("CommodityName" %in% names(vp_commodity_data)) sort(unique(as.character(vp_commodity_data$CommodityName))) else character(0)
    vp_commodity_values <- vp_commodity_values[!is.na(vp_commodity_values) & nzchar(vp_commodity_values)]
    vp_commodity_choices <- stats::setNames(vp_commodity_values, vp_commodity_values)
    selected_vp_commodity <- input$vp_commodity_name_choice %||% NULL
    if (is.null(selected_vp_commodity) || !(selected_vp_commodity %in% unname(vp_commodity_choices))) {
      selected_vp_commodity <- if (length(vp_commodity_choices) > 0L) unname(vp_commodity_choices[[1]]) else NULL
    }

    tagList(
      tags$style(HTML("\n        .top-filter-row .top-filter-control .form-group {\n          margin-bottom: 0;\n        }\n        .top-filter-row .top-filter-control .control-label {\n          display: block;\n          margin-top: 0;\n          margin-bottom: 6px;\n          line-height: 1.2;\n        }\n        .top-filter-row .top-filter-control .radio-inline {\n          margin-top: 0;\n        }\n        .top-filter-row .top-filter-control .shiny-input-radiogroup.shiny-input-container {\n          width: auto;\n          min-width: 0;\n          max-width: none;\n        }\n        .top-filter-row .top-filter-divider {\n          align-self: stretch;\n          width: 1px;\n          background-color: #d0d0d0;\n          margin: 0 3px;\n        }\n        .top-filter-row .top-filter-compact-group {\n          display: flex;\n          align-items: flex-start;\n          gap: 4px;\n          flex-wrap: wrap;\n        }\n        .top-filter-row .top-filter-frequency-year-group {\n          display: flex;\n          align-items: flex-start;\n          gap: 4px;\n          flex-wrap: wrap;\n        }\n        .top-filter-row .top-filter-control-trade-flow {\n          min-width: 128px;\n        }\n        .top-filter-row .top-filter-control-hybrid {\n          flex: 0 1 196px;\n          min-width: 168px;\n          max-width: 196px;\n        }\n        .top-filter-row .top-filter-control-hybrid .shiny-options-group {\n          display: flex;\n          flex-wrap: wrap;\n          column-gap: 8px;\n          row-gap: 4px;\n        }\n        .top-filter-row .top-filter-control-hybrid .radio-inline {\n          display: inline-flex;\n          align-items: flex-start;\n          margin-right: 0;\n          white-space: normal;\n        }\n        .top-filter-row .top-filter-control-hybrid .radio-inline + .radio-inline {\n          margin-left: 0;\n        }\n        .top-filter-row .top-filter-control-hybrid .radio-inline input[type='radio'] {\n          margin-top: 3px;\n        }\n        .top-filter-row .top-filter-control-frequency {\n          flex: 0 0 auto;\n          min-width: 136px;\n        }\n        .top-filter-row .top-filter-control-year-type {\n          min-width: 148px;\n        }\n      ")),
      div(
        class = "top-filter-row",
        style = "display: flex; align-items: flex-start; gap: 6px; flex-wrap: wrap;",
        if (vp_trade_mode) {
          tagList(
            div(
              class = "top-filter-hierarchy-cluster",
              style = "display: flex; align-items: flex-start; gap: 6px; flex-wrap: wrap; margin-right: 12px;",
              div(
                class = "top-filter-control",
                style = "min-width: 180px;",
                selectInput(
                  inputId = "vp_group_choice",
                  label = "Group:",
                  choices = vp_group_choices,
                  selected = selected_vp_group,
                  width = "100%"
                )
              ),
              div(
                class = "top-filter-control",
                style = "min-width: 180px;",
                selectInput(
                  inputId = "vp_subgroup_choice",
                  label = "Subgroup:",
                  choices = vp_subgroup_choices,
                  selected = selected_vp_subgroup,
                  width = "100%"
                )
              ),
              div(
                class = "top-filter-control",
                style = "min-width: 220px;",
                selectInput(
                  inputId = "vp_market_segment_choice",
                  label = "Market Segment:",
                  choices = vp_market_segment_choices,
                  selected = selected_vp_market_segment,
                  width = "100%"
                )
              ),
              div(
                class = "top-filter-control vp-hierarchy-reset-control",
                actionButton(
                  inputId = "vp_reset_hierarchy_filters",
                  label = NULL,
                  icon = icon("rotate-left"),
                  title = "Clear Group, Subgroup, and Market Segment",
                  class = "btn btn-default btn-sm",
                  disabled = if (isTRUE(vp_hierarchy_reset_disabled)) "disabled" else NULL
                )
              )
            ),
            div(
              class = "top-filter-control",
              style = "min-width: 220px;",
              selectInput(
                inputId = "vp_commodity_name_choice",
                label = "Commodity:",
                choices = vp_commodity_choices,
                selected = selected_vp_commodity,
                width = "100%"
              )
            ),
            div(
              style = "display: none;",
              selectInput(
                inputId = "data_source_choice",
                label = "Data Source:",
                choices = data_source_choices,
                selected = selected_source,
                width = "100%"
              )
            )
          )
        } else {
          div(
            class = "top-filter-control",
            style = "min-width: 220px;",
            selectInput(
              inputId = "data_source_choice",
              label = "Data Source:",
              choices = data_source_choices,
              selected = selected_source,
              width = "100%"
            )
          )
        },
        div(class = "top-filter-divider"),
        if (census_mode) {
          div(
            class = "top-filter-compact-group",
            div(
              class = "top-filter-control top-filter-control-trade-flow",
              radioButtons(
                inputId = "census_trade_flow_choice",
                label = "Trade Flow:",
                choices = c("Export" = "export", "Import" = "import"),
                selected = census_trade_flow,
                inline = FALSE
              )
            ),
            div(
              class = "top-filter-frequency-year-group",
              div(
                class = "top-filter-control top-filter-control-frequency",
                radioButtons(
                  inputId = "data_frequency",
                  label = "Data Frequency:",
                  choices = choices,
                  selected = selected_freq,
                  inline = data_frequency_inline
                )
              ),
              if (supports_year_type) {
                div(
                  class = "top-filter-control top-filter-control-year-type",
                  radioButtons(
                    inputId = "year_type_choice",
                    label = "Year Type:",
                    choices = year_type_choices,
                    selected = selected_year_type,
                    inline = FALSE
                  )
                )
              }
            )
          )
        } else if (hybrid_mode) {
          div(
            class = "top-filter-compact-group",
            div(
              class = "top-filter-control top-filter-control-trade-flow",
              radioButtons(
                inputId = "hybrid_trade_flow_choice",
                label = "Trade Flow:",
                choices = c("Export" = "export", "Import" = "import"),
                selected = selected_hybrid_trade_flow,
                inline = FALSE
              )
            ),
            if (!hybrid_import_mode) {
              div(
                class = "top-filter-control top-filter-control-hybrid",
                radioButtons(
                  inputId = "hybrid_mode_choice",
                  label = "Hybrid Mode:",
                  choices = c(
                    "Standard Hybrid" = "standard",
                    "Weekly-Imputed Hybrid" = "weekly_imputed"
                  ),
                  selected = selected_hybrid_mode,
                  inline = TRUE
                )
              )
            },
            div(
              class = "top-filter-frequency-year-group",
              div(
                class = "top-filter-control top-filter-control-frequency",
                radioButtons(
                  inputId = "data_frequency",
                  label = "Data Frequency:",
                  choices = choices,
                  selected = selected_freq,
                  inline = data_frequency_inline
                )
              ),
              if (supports_year_type) {
                div(
                  class = "top-filter-control top-filter-control-year-type",
                  radioButtons(
                    inputId = "year_type_choice",
                    label = "Year Type:",
                    choices = year_type_choices,
                    selected = selected_year_type,
                    inline = FALSE
                  )
                )
              }
            )
          )
        } else if (vp_trade_mode) {
          div(
            class = "top-filter-compact-group",
            div(
              class = "top-filter-control top-filter-control-trade-flow",
              radioButtons(
                inputId = "vp_trade_flow_choice",
                label = "Trade Flow:",
                choices = c("Export" = "export", "Import" = "import"),
                selected = selected_vp_trade_flow,
                inline = FALSE
              )
            ),
            div(
              class = "top-filter-control top-filter-control-frequency",
              radioButtons(
                inputId = "data_frequency",
                label = "Data Frequency:",
                choices = c("Monthly" = "monthly"),
                selected = "monthly",
                inline = FALSE
              )
            )
          )
        } else {
          div(
            class = "top-filter-frequency-year-group",
            div(
              class = "top-filter-control top-filter-control-frequency",
              radioButtons(
                inputId = "data_frequency",
                label = "Data Frequency:",
                choices = choices,
                selected = selected_freq,
                inline = data_frequency_inline
              )
            ),
            if (supports_year_type) {
              div(
                class = "top-filter-control top-filter-control-year-type",
                radioButtons(
                  inputId = "year_type_choice",
                  label = "Year Type:",
                  choices = year_type_choices,
                  selected = selected_year_type,
                  inline = FALSE
                )
              )
            },
            if (nass_mode && length(nass_year_type_choices) > 0L) {
              div(
                class = "top-filter-control top-filter-control-year-type",
                radioButtons(
                  inputId = "nass_annual_year_type",
                  label = "Year Type:",
                  choices = nass_year_type_choices,
                  selected = selected_nass_year_type,
                  inline = FALSE
                )
              )
            }
          )
        }
      ),
      helper_text
    )
  })

  outputOptions(output, "data_frequency_ui", suspendWhenHidden = FALSE)

  observeEvent(input$census_trade_flow_choice, {
    if (!is.null(input$census_trade_flow_choice) && input$census_trade_flow_choice %in% c("export", "import")) {
      census_trade_flow_state(input$census_trade_flow_choice)
    }
  }, ignoreInit = TRUE)

  observeEvent(input$vp_trade_flow_choice, {
    if (!is.null(input$vp_trade_flow_choice) && input$vp_trade_flow_choice %in% c("export", "import")) {
      vp_trade_flow_state(input$vp_trade_flow_choice)
    }
  }, ignoreInit = TRUE)

  observeEvent(input$year_type_choice, {
    source_choice <- current_source_choice_safe()
    if (!source_supports_year_type(source_choice)) {
      return()
    }

    resolved_year_type <- normalize_non_psd_year_type(
      input$year_type_choice,
      default = isolate(last_non_psd_year_type())
    )

    if (!identical(isolate(last_non_psd_year_type()), resolved_year_type)) {
      last_non_psd_year_type(resolved_year_type)
    }
  }, ignoreInit = TRUE)

  observeEvent(list(input$data_source_choice, input$main_tabs_panel), {
    source_choice <- current_source_choice_safe()
    remember_non_psd_main_tab_if_valid(
      source_choice = source_choice,
      selected_tab = input$main_tabs_panel,
      reason = "non_psd_tab_observer"
    )
  }, ignoreInit = FALSE, priority = -10)

  observeEvent(input$data_source_choice, {
    source_switch_start_time <- Sys.time()
    source_choice <- current_source_choice_safe()
    previous_source_choice <- isolate(last_observed_data_source_choice())
    source_switch_epoch <- begin_source_switch_epoch(
      trigger = "data_source_choice",
      source_choice = source_choice,
      previous_source_choice = previous_source_choice
    )
    is_psd_source_entry <- identical(source_choice, "psd") && !identical(previous_source_choice, "psd")
    is_psd_source_exit <- identical(previous_source_choice, "psd") && !identical(source_choice, "psd")
    is_vp_trade_source_entry <- identical(source_choice, "vp_trade") && !identical(previous_source_choice, "vp_trade")
    raw_main_tab <- normalize_psd_source_entry_scalar(input$main_tabs_panel)
    initialized_trade_flow <- FALSE
    initialized_year_type <- FALSE
    psd_exit_target_tab <- NULL
    source_entry_context <- capture_psd_source_entry_context(source_choice, previous_source_choice)

    psd_source_entry_pending(is_psd_source_entry)
  vp_trade_metric_default_pending(is_vp_trade_source_entry)
    vp_trade_unit_default_pending(is_vp_trade_source_entry)
    session$userData$psd_source_entry_context <- if (isTRUE(is_psd_source_entry)) source_entry_context else NULL

    if (identical(source_choice, "psd")) {
      if (isTRUE(is_psd_source_entry)) {
        remember_non_psd_main_tab_if_valid(
          source_choice = previous_source_choice,
          selected_tab = raw_main_tab,
          reason = "psd_source_entry_seed"
        )
      }

      non_psd_main_tab_restore_target(NULL)
      if (isTRUE(is_psd_source_entry)) {
        psd_source_transition_active(TRUE)
        target_state <- build_psd_source_transition_state(source_entry_context = source_entry_context)
        psd_source_transition_state(target_state)
        target_bottom_view <- queue_psd_map_bottom_view_entry_target(target_state$country)
        pending_sidebar_country_target(target_state$country)
        if (exists("pending_psd_map_country_target", mode = "function")) {
          try(pending_psd_map_country_target(target_state$country), silent = TRUE)
        }
        if (exists("write_canonical_psd_country", mode = "function")) {
          try(write_canonical_psd_country(target_state$country), silent = TRUE)
        }
        bump_main_tabs_render_nonce()
        psd_transition_trace(
          event = "activate_transition_state",
          reason = "source_entry_default",
          details = list(
            action = "activate_transition_state",
            target_tab = target_state$tab,
            target_country = target_state$country,
            target_frequency = target_state$frequency,
            target_metric = target_state$metric,
            target_basis = target_state$basis,
            target_country_reason = target_state$target_country_reason,
            target_basis_reason = target_state$target_basis_reason,
            target_bottom_view = target_bottom_view
          ),
          resolved_basis = target_state$basis
        )
      } else {
        psd_transition_trace(
          event = "activate_transition_state",
          reason = "source_entry_default",
          details = list(
            action = "skip_redundant_psd_source_event",
            previous_source = previous_source_choice,
            current_source = source_choice
          )
        )
      }
    } else {
      psd_source_entry_pending(FALSE)
      psd_source_transition_active(FALSE)
      psd_source_transition_state(NULL)
      psd_map_bottom_view_entry_target(NULL)
      session$userData$psd_source_entry_context <- NULL

      if (!isTRUE(is_psd_source_exit)) {
        remember_non_psd_main_tab_if_valid(
          source_choice = source_choice,
          selected_tab = raw_main_tab,
          reason = "non_psd_source_event_seed"
        )
      }

      if (isTRUE(is_psd_source_exit)) {
        psd_exit_target_tab <- resolve_non_psd_main_tab_target(
          source_choice,
          isolate(last_non_psd_main_tab())
        )
        non_psd_main_tab_restore_target(psd_exit_target_tab)
        psd_transition_trace(
          event = "restore_non_psd_main_tab",
          reason = "psd_source_exit",
          details = list(
            action = "restore_non_psd_main_tab",
            previous_source = previous_source_choice,
            current_source = source_choice,
            current_tab = input$main_tabs_panel %||% NULL,
            target_tab = psd_exit_target_tab,
            remembered_non_psd_tab = isolate(last_non_psd_main_tab())
          )
        )
        schedule_main_tabs_safe_select(
          psd_exit_target_tab,
          source_choice,
          reason = "psd_source_exit_restore"
        )
      } else {
        non_psd_main_tab_restore_target(NULL)
      }
    }

    last_observed_data_source_choice(source_choice)

    if (identical(source_choice, "census") && !(isolate(census_trade_flow_state()) %in% c("export", "import"))) {
      initialized_trade_flow <- TRUE
      census_trade_flow_state("export")
    }

    if (source_supports_year_type(source_choice)) {
      target_year_type <- current_non_psd_year_type_safe(
        source_choice = source_choice,
        default = isolate(last_non_psd_year_type())
      )

      if (!identical(isolate(last_non_psd_year_type()), target_year_type)) {
        last_non_psd_year_type(target_year_type)
      }

      if (!identical(input$year_type_choice, target_year_type)) {
        initialized_year_type <- TRUE
        updateRadioButtons(session, "year_type_choice", selected = target_year_type)
      }
    }

    if (identical(source_choice, "vp_trade") && !identical(input$data_frequency, "monthly")) {
      updateRadioButtons(session, "data_frequency", selected = "monthly")
    }

    log_perf(
      "observeEvent(data_source_choice)",
      source_switch_start_time,
      details = c(
        source_switch_epoch_fields(include_age = TRUE),
        list(
        tab = input$main_tabs_panel,
        source = source_choice,
        previous_source = previous_source_choice %||% NULL,
        is_vp_trade_source_entry = is_vp_trade_source_entry,
        is_psd_source_entry = is_psd_source_entry,
        is_psd_source_exit = is_psd_source_exit,
        psd_exit_target_tab = psd_exit_target_tab %||% NULL,
        hybrid_mode = hybrid_mode_choice(),
        frequency = input$data_frequency,
        year_type = if (source_supports_year_type(source_choice)) {
          current_non_psd_year_type_safe(source_choice = source_choice, default = isolate(last_non_psd_year_type()))
        } else {
          "marketing"
        },
        trade_flow = effective_trade_flow_for_source(source_choice, input$census_trade_flow_choice, input$vp_trade_flow_choice),
        monthly_only = source_requires_monthly(source_choice),
        initialized_trade_flow = initialized_trade_flow,
        initialized_year_type = initialized_year_type
        )
      )
    )

    source_switch_epoch_trace(
      "data_source_choice_observer_complete",
      details = list(
        source = source_choice,
        previous_source = previous_source_choice %||% NULL,
        is_vp_trade_source_entry = is_vp_trade_source_entry,
        is_psd_source_entry = is_psd_source_entry,
        is_psd_source_exit = is_psd_source_exit,
        psd_exit_target_tab = psd_exit_target_tab %||% NULL,
        initialized_trade_flow = initialized_trade_flow,
        initialized_year_type = initialized_year_type,
        observer_elapsed_ms = perf_elapsed_ms(source_switch_start_time),
        source_switch_epoch = source_switch_epoch
      )
    )
  }, ignoreInit = TRUE, priority = 100)

  observeEvent(list(input$data_source_choice, input$hybrid_trade_flow_choice, input$hybrid_mode_choice), {
    source_choice <- current_source_choice_safe()
    if (!identical(source_choice, "hybrid")) return()

    desired_frequency <- if (is_hybrid_import_mode()) {
      "monthly"
    } else if (identical(hybrid_mode_choice(), "weekly_imputed")) {
      "weekly"
    } else {
      "monthly"
    }

    if (!identical(input$data_frequency, desired_frequency)) {
      updateRadioButtons(session, "data_frequency", selected = desired_frequency)
    }
  }, ignoreInit = TRUE)

  observeEvent(input$data_source_choice, {
    psd_entry_observer_start_time <- Sys.time()
    source_choice <- current_source_choice_safe()
    if (!identical(source_choice, "psd")) {
      log_perf(
        "observeEvent(data_source_choice:psd_entry_ui_updates)",
        psd_entry_observer_start_time,
        details = c(
          source_switch_epoch_fields(include_age = TRUE),
          list(source = source_choice, status = "skip_non_psd")
        )
      )
      return()
    }
    if (!isTRUE(isolate(psd_source_entry_pending()))) {
      log_perf(
        "observeEvent(data_source_choice:psd_entry_ui_updates)",
        psd_entry_observer_start_time,
        details = c(
          source_switch_epoch_fields(include_age = TRUE),
          list(source = source_choice, status = "skip_not_pending")
        )
      )
      return()
    }

    on.exit(psd_source_entry_pending(FALSE), add = TRUE)

    target_state <- current_psd_source_transition_state()
    if (is.null(target_state)) {
      target_state <- build_psd_source_transition_state(
        source_entry_context = isolate(session$userData$psd_source_entry_context)
      )
      psd_source_transition_state(target_state)
    }
    basis_scope <- basis_choice_scope_for_source(source_choice)
    psd_source_transition_active(TRUE)
    queue_psd_map_bottom_view_entry_target(target_state$country)
    pending_sidebar_country_target(target_state$country)
    if (exists("pending_psd_map_country_target", mode = "function")) {
      try(pending_psd_map_country_target(target_state$country), silent = TRUE)
    }
    if (exists("write_canonical_psd_country", mode = "function")) {
      try(write_canonical_psd_country(target_state$country), silent = TRUE)
    }

    if (!identical(input$data_frequency, target_state$frequency)) {
      updateRadioButtons(session, "data_frequency", selected = target_state$frequency)
    }

    updateRadioButtons(
      session,
      "metric_choice",
      choices = target_state$metric_choices,
      selected = target_state$metric
    )
    updateSelectInput(
      session,
      "unit_choice",
      choices = target_state$unit_choices,
      selected = target_state$unit
    )
    session$userData$psd_quantity_unit_choice_state <- target_state$unit
    write_remembered_basis_choice_state(target_state$basis, basis_scope)
    if (identical(input$basis_choice, target_state$basis)) {
      session$userData$basis_input_scope <- basis_scope
    }
    psd_transition_trace(
      event = "update_basis_choice",
      reason = "source_entry_default",
      details = list(
        action = "update_basis_choice",
        update_scope = basis_scope,
        selected_basis = target_state$basis,
        target_basis_reason = target_state$target_basis_reason,
        target_metric = target_state$metric,
        target_frequency = target_state$frequency
      ),
      resolved_basis = target_state$basis
    )
    mark_pending_programmatic_basis_update(target_state$basis, basis_scope)
    updateSelectInput(session, "basis_choice", selected = target_state$basis)

    schedule_main_tabs_safe_select(
      target_state$tab,
      "psd",
      reason = "psd_source_entry_profile_restore"
    )

    log_perf(
      "observeEvent(data_source_choice:psd_entry_ui_updates)",
      psd_entry_observer_start_time,
      details = c(
        source_switch_epoch_fields(include_age = TRUE),
        list(
          source = source_choice,
          status = "applied",
          target_tab = target_state$tab,
          target_country = target_state$country,
          target_frequency = target_state$frequency,
          target_metric = target_state$metric,
          target_basis = target_state$basis,
          target_country_reason = target_state$target_country_reason,
          target_basis_reason = target_state$target_basis_reason,
          basis_scope = basis_scope
        )
      )
    )

    source_switch_epoch_trace(
      "psd_entry_ui_updates_complete",
      details = list(
        target_tab = target_state$tab,
        target_country = target_state$country,
        target_frequency = target_state$frequency,
        target_metric = target_state$metric,
        target_basis = target_state$basis,
        target_country_reason = target_state$target_country_reason,
        target_basis_reason = target_state$target_basis_reason,
        observer_elapsed_ms = perf_elapsed_ms(psd_entry_observer_start_time)
      )
    )

  }, ignoreInit = TRUE)

  observe({
    target_state <- current_psd_source_transition_state()
    if (is.null(target_state)) {
      return()
    }

    if (!psd_transition_inputs_match_target(target_state)) {
      return()
    }

    psd_transition_trace(
      event = "clear_transition_state",
      reason = "transition_clear",
      details = list(
        action = "clear_transition_state",
        cleared_basis = target_state$basis,
        cleared_metric = target_state$metric
      ),
      resolved_basis = target_state$basis
    )
    source_switch_epoch_trace(
      "transition_state_cleared",
      details = list(
        cleared_country = target_state$country,
        cleared_basis = target_state$basis,
        cleared_metric = target_state$metric,
        epoch_elapsed_ms = source_switch_epoch_fields(include_age = TRUE)$source_switch_age_ms %||% NULL
      )
    )
    psd_source_transition_state(NULL)
    psd_source_transition_active(FALSE)
  })

  # When source/flow changes, preserve current Custom Comparison layout whenever
  # the stored selections are still legal in the new context.
  observeEvent(list(input$data_source_choice, input$census_trade_flow_choice, input$hybrid_trade_flow_choice, input$vp_trade_flow_choice), {
    start_time <- Sys.time()
    source_choice <- if (!is.null(input$data_source_choice)) input$data_source_choice else "export_sales"
    trade_flow <- effective_trade_flow_for_source(source_choice, input$census_trade_flow_choice, input$vp_trade_flow_choice)

    panel_targets <- reconcile_custom_comparison_non_metric_targets()

    if (length(panel_targets) > 0) {
      apply_custom_comparison_panel_targets(panel_targets)
    }

    log_perf(
      "observeEvent(source_or_trade_flow -> custom_panel_reconcile)",
      start_time,
      details = list(
        source = source_choice,
        trade_flow = trade_flow,
        target_updates = length(panel_targets),
        country_updates = panel_target_prefix_count(panel_targets, "country_"),
        commodity_updates = panel_target_prefix_count(panel_targets, "commodity_")
      )
    )
  }, ignoreInit = TRUE)

  observeEvent(input$client_perf_main_tabs_mount, {
    payload <- input$client_perf_main_tabs_mount
    if (is.null(payload)) return()

    log_client_perf("main_tabs_mount", payload)
  }, ignoreInit = TRUE)

  observeEvent(input$client_perf_main_tabs_profile, {
    payload <- input$client_perf_main_tabs_profile
    if (is.null(payload)) return()

    server_source <- input$data_source_choice %||% "export_sales"
    expected_profile <- main_tabs_profile_for_source(server_source)
    expected_count <- main_tabs_expected_count_for_source(server_source)
    nav_link_count <- suppressWarnings(as.integer(payload$nav_link_count %||% NA_integer_))
    dom_profile <- payload$profile %||% NULL
    dom_source <- payload$source %||% NULL
    profile_mismatch <- !is.null(dom_profile) && !identical(dom_profile, expected_profile)
    source_mismatch <- !is.null(dom_source) && !identical(dom_source, server_source)
    server_count_mismatch <- !is.na(nav_link_count) && !identical(nav_link_count, as.integer(expected_count))
    raw_server_tab <- input$main_tabs_panel %||% NULL
    normalized_server_tab <- normalize_main_tab_for_source(raw_server_tab, server_source)
    dom_active_tab <- payload$tab %||% NULL
    legal_tabs <- allowed_main_tabs_for_source(server_source)
    dom_tab_is_legal <- !is.null(dom_active_tab) && identical(dom_active_tab %in% legal_tabs, TRUE)
    raw_tab_mismatch <- !is.null(raw_server_tab) && !identical(raw_server_tab, normalized_server_tab)
    dom_tab_mismatch <- dom_tab_is_legal && !identical(dom_active_tab, normalized_server_tab)
    tab_mismatch <- isTRUE(raw_tab_mismatch || dom_tab_mismatch)

    log_client_perf(
      "main_tabs_profile",
      c(
        source_switch_epoch_fields(include_age = TRUE),
        list(
          server_source = server_source,
          server_tab = raw_server_tab,
          normalized_server_tab = normalized_server_tab,
          dom_profile = payload$profile %||% NULL,
          dom_source = payload$source %||% NULL,
          expected_count = payload$expected_count %||% NULL,
          nav_link_count = payload$nav_link_count %||% NULL,
          tab_pane_count = payload$tab_pane_count %||% NULL,
          active_tab = payload$tab %||% NULL,
          profile_mismatch = payload$profile_mismatch %||% NULL,
          count_mismatch = payload$count_mismatch %||% NULL,
          raw_tab_mismatch = raw_tab_mismatch,
          dom_tab_mismatch = dom_tab_mismatch,
          tab_mismatch = tab_mismatch,
          reason = payload$reason %||% NULL,
          client_ts = payload$ts %||% NULL
        )
      )
    )

    if (!isTRUE(profile_mismatch || source_mismatch || server_count_mismatch || tab_mismatch)) {
      last_main_tabs_mismatch_recovery_key(NULL)
      return()
    }

    target_tab <- target_main_tab_for_source(input$main_tabs_panel, server_source)
    recovery_key <- paste(
      server_source,
      expected_profile,
      expected_count,
      target_tab,
      dom_profile %||% "<null>",
      dom_source %||% "<null>",
      nav_link_count %||% "<null>",
      raw_server_tab %||% "<null>",
      normalized_server_tab %||% "<null>",
      dom_active_tab %||% "<null>",
      sep = "|"
    )

    if (identical(isolate(last_main_tabs_mismatch_recovery_key()), recovery_key)) {
      return()
    }

    last_main_tabs_mismatch_recovery_key(recovery_key)
    bump_main_tabs_render_nonce()
    schedule_main_tabs_safe_select(
      target_tab,
      server_source,
      reason = "main_tabs_profile_mismatch_recovery",
      delay_ms = 75L
    )
    log_client_perf(
      "main_tabs_profile_recovery",
      c(
        source_switch_epoch_fields(include_age = TRUE),
        list(
          server_source = server_source,
          expected_profile = expected_profile,
          expected_count = expected_count,
          target_tab = target_tab,
          normalized_server_tab = normalized_server_tab,
          dom_profile = dom_profile,
          dom_source = dom_source,
          dom_active_tab = dom_active_tab,
          nav_link_count = nav_link_count,
          raw_tab_mismatch = raw_tab_mismatch,
          dom_tab_mismatch = dom_tab_mismatch,
          tab_mismatch = tab_mismatch,
          recovery_key = recovery_key
        )
      )
    )
  }, ignoreInit = TRUE)

  observeEvent(input$client_perf_main_tabs_safe_select, {
    payload <- input$client_perf_main_tabs_safe_select
    if (is.null(payload)) return()

    log_client_perf(
      "main_tabs_safe_select",
      c(
        source_switch_epoch_fields(include_age = TRUE),
        list(
          server_source = input$data_source_choice %||% NULL,
          server_tab = input$main_tabs_panel %||% NULL,
          status = payload$status %||% NULL,
          reason = payload$reason %||% NULL,
          requested_tab = payload$requested_tab %||% NULL,
          expected_source = payload$expected_source %||% NULL,
          expected_profile = payload$expected_profile %||% NULL,
          expected_count = payload$expected_count %||% NULL,
          dom_source = payload$source %||% NULL,
          dom_profile = payload$profile %||% NULL,
          nav_link_count = payload$nav_link_count %||% NULL,
          tab_pane_count = payload$tab_pane_count %||% NULL,
          before_tab = payload$before_tab %||% NULL,
          after_tab = payload$after_tab %||% NULL,
          input_value = payload$input_value %||% NULL,
          attempt = payload$attempt %||% NULL,
          request_id = payload$request_id %||% NULL,
          client_ts = payload$ts %||% NULL
        )
      )
    )
  }, ignoreInit = TRUE)

  observeEvent(input$client_perf_source_shell, {
    if (!isTRUE(perf_log_enabled())) return()
    payload <- input$client_perf_source_shell
    if (is.null(payload)) return()

    log_client_perf(
      "source_shell",
      c(
        source_switch_epoch_fields(include_age = TRUE),
        list(
          server_source = input$data_source_choice %||% NULL,
          server_tab = input$main_tabs_panel %||% NULL,
          client_server_source = payload$server_source %||% NULL,
          active_tab = payload$active_tab %||% NULL,
          main_tabs_panel = payload$main_tabs_panel %||% NULL,
          main_dom_source = payload$main_dom_source %||% NULL,
          main_dom_profile = payload$main_dom_profile %||% NULL,
          main_expected_count = payload$main_expected_count %||% NULL,
          main_nav_link_count = payload$main_nav_link_count %||% NULL,
          main_tab_pane_count = payload$main_tab_pane_count %||% NULL,
          main_source_mismatch = payload$main_source_mismatch %||% NULL,
          main_profile_mismatch = payload$main_profile_mismatch %||% NULL,
          source_shell_mismatch_reason = payload$source_shell_mismatch_reason %||% NULL,
          top_data_source_dom_value = payload$top_data_source_dom_value %||% NULL,
          top_data_source_input_value = payload$top_data_source_input_value %||% NULL,
          top_visible = payload$top_visible %||% NULL,
          top_display = payload$top_display %||% NULL,
          top_visibility = payload$top_visibility %||% NULL,
          top_width = payload$top_width %||% NULL,
          top_height = payload$top_height %||% NULL,
          top_frequency_dom_value = payload$top_frequency_dom_value %||% NULL,
          top_frequency_input_value = payload$top_frequency_input_value %||% NULL,
          top_frequency_values = payload$top_frequency_values %||% NULL,
          top_weekly_option_present = payload$top_weekly_option_present %||% NULL,
          top_monthly_option_present = payload$top_monthly_option_present %||% NULL,
          top_psd_helper_present = payload$top_psd_helper_present %||% NULL,
          top_year_type_present = payload$top_year_type_present %||% NULL,
          top_census_trade_flow_present = payload$top_census_trade_flow_present %||% NULL,
          top_hybrid_trade_flow_present = payload$top_hybrid_trade_flow_present %||% NULL,
          top_hybrid_mode_present = payload$top_hybrid_mode_present %||% NULL,
          sidebar_psd_country_present = payload$sidebar_psd_country_present %||% NULL,
          sidebar_psd_country_visible = payload$sidebar_psd_country_visible %||% NULL,
          sidebar_non_psd_cutoff_present = payload$sidebar_non_psd_cutoff_present %||% NULL,
          sidebar_non_psd_cutoff_visible = payload$sidebar_non_psd_cutoff_visible %||% NULL,
          sidebar_visible = payload$sidebar_visible %||% NULL,
          sidebar_jquery_visible = payload$sidebar_jquery_visible %||% NULL,
          sidebar_display = payload$sidebar_display %||% NULL,
          sidebar_visibility = payload$sidebar_visibility %||% NULL,
          sidebar_opacity = payload$sidebar_opacity %||% NULL,
          sidebar_width = payload$sidebar_width %||% NULL,
          sidebar_height = payload$sidebar_height %||% NULL,
          sidebar_text_length = payload$sidebar_text_length %||% NULL,
          sidebar_child_input_count = payload$sidebar_child_input_count %||% NULL,
          sidebar_visible_child_input_count = payload$sidebar_visible_child_input_count %||% NULL,
          sidebar_hidden_child_input_count = payload$sidebar_hidden_child_input_count %||% NULL,
          sidebar_selectize_count = payload$sidebar_selectize_count %||% NULL,
          sidebar_child_input_ids = payload$sidebar_child_input_ids %||% NULL,
          sidebar_source_profile = payload$sidebar_source_profile %||% NULL,
          sidebar_source_epoch = payload$sidebar_source_epoch %||% NULL,
          sidebar_rendered_builder = payload$sidebar_rendered_builder %||% NULL,
          sidebar_rendered_surface = payload$sidebar_rendered_surface %||% NULL,
          sidebar_metadata_mismatch = payload$sidebar_metadata_mismatch %||% NULL,
          sidebar_blank_or_masked = payload$sidebar_blank_or_masked %||% NULL,
          psd_map_controls_present = payload$psd_map_controls_present %||% NULL,
          psd_map_controls_visible = payload$psd_map_controls_visible %||% NULL,
          psd_map_controls_text_length = payload$psd_map_controls_text_length %||% NULL,
          psd_map_controls_child_input_count = payload$psd_map_controls_child_input_count %||% NULL,
          sidebar_stale_non_psd = payload$sidebar_stale_non_psd %||% NULL,
          psd_controls_missing = payload$psd_controls_missing %||% NULL,
          sidebar_top_partner_present = payload$sidebar_top_partner_present %||% NULL,
          metric_visible = payload$metric_visible %||% NULL,
          unit_visible = payload$unit_visible %||% NULL,
          bottom_visible = payload$bottom_visible %||% NULL,
          bottom_display = payload$bottom_display %||% NULL,
          bottom_visibility = payload$bottom_visibility %||% NULL,
          bottom_width = payload$bottom_width %||% NULL,
          bottom_height = payload$bottom_height %||% NULL,
          bottom_source_profile = payload$bottom_source_profile %||% NULL,
          bottom_source_epoch = payload$bottom_source_epoch %||% NULL,
          bottom_rendered_builder = payload$bottom_rendered_builder %||% NULL,
          bottom_rendered_surface = payload$bottom_rendered_surface %||% NULL,
          bottom_metadata_mismatch = payload$bottom_metadata_mismatch %||% NULL,
          bottom_psd_view_present = payload$bottom_psd_view_present %||% NULL,
          bottom_psd_current_present = payload$bottom_psd_current_present %||% NULL,
          bottom_psd_current_visible = payload$bottom_psd_current_visible %||% NULL,
          bottom_psd_comparison_present = payload$bottom_psd_comparison_present %||% NULL,
          bottom_psd_comparison_visible = payload$bottom_psd_comparison_visible %||% NULL,
          bottom_psd_matrix_present = payload$bottom_psd_matrix_present %||% NULL,
          bottom_psd_matrix_visible = payload$bottom_psd_matrix_visible %||% NULL,
          bottom_non_psd_summary_present = payload$bottom_non_psd_summary_present %||% NULL,
          bottom_non_psd_summary_visible = payload$bottom_non_psd_summary_visible %||% NULL,
          bottom_stale_non_psd = payload$bottom_stale_non_psd %||% NULL,
          map_plot_present = payload$map_plot_present %||% NULL,
          map_plot_visible = payload$map_plot_visible %||% NULL,
          map_plot_width = payload$map_plot_width %||% NULL,
          map_plot_height = payload$map_plot_height %||% NULL,
          psd_fragments_present = payload$psd_fragments_present %||% NULL,
          non_psd_fragments_present = payload$non_psd_fragments_present %||% NULL,
          source_shell_mismatch = payload$source_shell_mismatch %||% NULL,
          reason = payload$reason %||% NULL,
          client_ts = payload$ts %||% NULL
        )
      )
    )
  }, ignoreInit = TRUE)

  observeEvent(input$client_source_surface_refresh_request, {
    payload <- input$client_source_surface_refresh_request
    if (is.null(payload)) return()

    payload_truthy <- function(value) {
      if (is.null(value) || length(value) == 0) return(FALSE)
      if (is.logical(value)) return(isTRUE(value[[1]]))
      normalized <- tolower(trimws(as.character(value[[1]])))
      normalized %in% c("true", "t", "1", "yes")
    }

    payload_scalar <- function(value) {
      normalize_psd_source_entry_scalar(value)
    }

    server_source <- current_source_choice_safe(default = input$data_source_choice %||% "export_sales")
    expected_profile <- main_tabs_profile_for_source(server_source)
    server_tab <- current_main_tab_safe()
    client_source <- payload_scalar(payload$server_source)
    client_active_tab <- payload_scalar(payload$active_tab)
    client_main_tab <- payload_scalar(payload$main_tabs_panel)
    main_dom_source <- payload_scalar(payload$main_dom_source)
    main_dom_profile <- payload_scalar(payload$main_dom_profile)

    source_ok <- identical(server_source, "psd") && identical(client_source, "psd")
    tab_ok <- identical(server_tab, "Map") || identical(client_active_tab, "Map") || identical(client_main_tab, "Map")
    main_aligned <- identical(main_dom_source, server_source) && identical(main_dom_profile, expected_profile)
    sidebar_stale <- payload_truthy(payload$sidebar_metadata_mismatch) ||
      identical(payload_scalar(payload$sidebar_source_profile), "non_psd") ||
      identical(payload_scalar(payload$sidebar_rendered_builder), "non_psd") ||
      payload_truthy(payload$sidebar_non_psd_cutoff_visible)
    bottom_stale <- payload_truthy(payload$bottom_metadata_mismatch) ||
      identical(payload_scalar(payload$bottom_source_profile), "non_psd") ||
      identical(payload_scalar(payload$bottom_rendered_builder), "non_psd") ||
      payload_truthy(payload$bottom_non_psd_summary_visible)
    top_stale <- payload_truthy(payload$top_shell_mismatch)
    should_refresh <- isTRUE(source_ok && tab_ok && main_aligned && (sidebar_stale || bottom_stale || top_stale))

    request_key <- paste(
      source_switch_epoch_id(),
      server_source,
      server_tab %||% "<null>",
      payload_scalar(payload$sidebar_source_epoch) %||% "<null>",
      payload_scalar(payload$sidebar_rendered_builder) %||% "<null>",
      payload_scalar(payload$bottom_source_epoch) %||% "<null>",
      payload_scalar(payload$bottom_rendered_builder) %||% "<null>",
      payload_scalar(payload$request_key) %||% "<null>",
      sep = "|"
    )
    attempts <- isolate(source_surface_refresh_attempts())
    attempt_count <- suppressWarnings(as.integer(attempts[[request_key]] %||% 0L))
    if (is.na(attempt_count)) attempt_count <- 0L
    attempt_limit <- 2L
    status <- "skipped_validation"

    if (isTRUE(should_refresh)) {
      if (attempt_count < attempt_limit) {
        attempts[[request_key]] <- attempt_count + 1L
        source_surface_refresh_attempts(attempts)
        bump_map_surface_refresh_nonce()
        status <- "applied"
      } else {
        status <- "skipped_attempt_limit"
      }
    }

    log_client_perf(
      "source_surface_refresh_request",
      c(
        source_switch_epoch_fields(include_age = TRUE),
        list(
          status = status,
          should_refresh = should_refresh,
          server_source = server_source,
          server_tab = server_tab,
          client_source = client_source,
          client_active_tab = client_active_tab,
          client_main_tab = client_main_tab,
          main_dom_source = main_dom_source,
          main_dom_profile = main_dom_profile,
          source_ok = source_ok,
          tab_ok = tab_ok,
          main_aligned = main_aligned,
          top_stale = top_stale,
          sidebar_stale = sidebar_stale,
          bottom_stale = bottom_stale,
          sidebar_source_profile = payload$sidebar_source_profile %||% NULL,
          sidebar_source_epoch = payload$sidebar_source_epoch %||% NULL,
          sidebar_rendered_builder = payload$sidebar_rendered_builder %||% NULL,
          bottom_source_profile = payload$bottom_source_profile %||% NULL,
          bottom_source_epoch = payload$bottom_source_epoch %||% NULL,
          bottom_rendered_builder = payload$bottom_rendered_builder %||% NULL,
          source_shell_mismatch_reason = payload$source_shell_mismatch_reason %||% NULL,
          request_reason = payload$reason %||% NULL,
          request_attempt = payload$attempt %||% NULL,
          server_attempt_count = attempt_count + if (identical(status, "applied")) 1L else 0L,
          attempt_limit = attempt_limit,
          refresh_nonce = isolate(map_surface_refresh_nonce()),
          request_key = request_key,
          client_request_key = payload$request_key %||% NULL,
          client_ts = payload$ts %||% NULL
        )
      )
    )
  }, ignoreInit = TRUE)

  observeEvent(input$client_perf_tab_shown, {
    payload <- input$client_perf_tab_shown
    if (is.null(payload)) return()

    log_client_perf("tab_shown", payload)
  }, ignoreInit = TRUE)

  observeEvent(input$client_perf_tab_after_paint, {
    payload <- input$client_perf_tab_after_paint
    if (is.null(payload)) return()

    log_client_perf("tab_after_paint", payload)
  }, ignoreInit = TRUE)

  observeEvent(input$client_perf_plotly_resize, {
    payload <- input$client_perf_plotly_resize
    if (is.null(payload)) return()

    log_client_perf("plotly_resize", payload)
  }, ignoreInit = TRUE)

  observeEvent(input$client_perf_boundary_marker, {
    payload <- input$client_perf_boundary_marker
    if (is.null(payload)) return()

    boundary_tag <- normalize_client_perf_boundary_tag(payload$boundary)
    log_client_perf(paste0("boundary_", boundary_tag), payload)
  }, ignoreInit = TRUE)

  observeEvent(input$client_myc_partner_show_probe, {
    payload <- input$client_myc_partner_show_probe
    if (is.null(payload)) return()

    comparison_mode <- isolate(market_year_comparison_mode())
    client_selected <- normalize_myc_partner_values(payload$selected_values %||% character(0), comparison_mode = comparison_mode)
    client_display <- normalize_myc_partner_values(payload$selected_labels %||% character(0), comparison_mode = comparison_mode)
    server_selected <- normalize_myc_partner_values(isolate(input$partner_show) %||% character(0), comparison_mode = comparison_mode)

    myc_transition_trace(
      "client_partner_show_probe",
      details = list(
        reason = perf_scalar_or_default(payload$reason),
        mode = comparison_mode,
        has_selectize = isTRUE(payload$has_selectize),
        choice_count = perf_scalar_or_default(payload$choice_count),
        client_selected_count = length(client_selected),
        client_selected_values = if (length(client_selected)) paste(client_selected, collapse = "|") else "<none>",
        client_display_count = length(client_display),
        client_display_values = if (length(client_display)) paste(client_display, collapse = "|") else "<none>",
        server_selected_count = length(server_selected),
        server_selected_values = if (length(server_selected)) paste(server_selected, collapse = "|") else "<none>",
        client_ts = perf_scalar_or_default(payload$captured_at_iso),
        request_action_id = perf_scalar_or_default(payload$action_id),
        request_mutation_seq = perf_scalar_or_default(payload$mutation_seq)
      )
    )
  }, ignoreInit = TRUE)

  observeEvent(input$client_myc_output_probe, {
    payload <- input$client_myc_output_probe
    if (is.null(payload)) return()

    summarize_output_node <- function(node_payload) {
      if (is.null(node_payload)) {
        return("missing")
      }

      paste(
        paste0("exists=", isTRUE(node_payload$exists)),
        paste0("visible=", isTRUE(node_payload$visible)),
        paste0("width=", perf_scalar_or_default(node_payload$width)),
        paste0("height=", perf_scalar_or_default(node_payload$height)),
        paste0("display=", perf_scalar_or_default(node_payload$display)),
        paste0("visibility=", perf_scalar_or_default(node_payload$visibility)),
        paste0("children=", perf_scalar_or_default(node_payload$child_count)),
        paste0("text=", perf_scalar_or_default(node_payload$text_length)),
        paste0("plotly=", perf_scalar_or_default(node_payload$plotly_count)),
        paste0("svg=", perf_scalar_or_default(node_payload$main_svg_count)),
        paste0("bars=", perf_scalar_or_default(node_payload$bar_path_count)),
        paste0("legend=", perf_scalar_or_default(node_payload$legend_count)),
        paste0("bar_w=", perf_scalar_or_default(node_payload$first_bar_width)),
        paste0("bar_h=", perf_scalar_or_default(node_payload$first_bar_height)),
        paste0("bar_fill=", perf_scalar_or_default(node_payload$first_bar_fill)),
        paste0("bar_opacity=", perf_scalar_or_default(node_payload$first_bar_opacity)),
        sep = ","
      )
    }

    myc_transition_trace(
      "client_myc_output_probe",
      details = list(
        reason = perf_scalar_or_default(payload$reason),
        plot_scroll = summarize_output_node(payload$plot_scroll),
        plot_width = summarize_output_node(payload$plot_width),
        plot = summarize_output_node(payload$plot),
        table = summarize_output_node(payload$table),
        comparison_basis = summarize_output_node(payload$comparison_basis),
        myc_cutoff = summarize_output_node(payload$myc_cutoff),
        client_ts = perf_scalar_or_default(payload$captured_at_iso),
        request_action_id = perf_scalar_or_default(payload$action_id),
        request_mutation_seq = perf_scalar_or_default(payload$mutation_seq)
      )
    )
  }, ignoreInit = TRUE)

  observeEvent(input$client_notes_trace, {
    payload <- input$client_notes_trace
    if (is.null(payload)) return()

    notes_event_name <- perf_scalar_or_default(payload$event, default = "unknown")
    panel_geometry <- payload$panel_geometry
    if (is.null(panel_geometry) && !is.null(payload$after)) {
      panel_geometry <- payload$after
    }

    notes_trace(
      paste0("client_", notes_event_name),
      details = list(
        reason = perf_scalar_or_default(payload$reason),
        panel_visible = isTRUE(payload$panel_visible),
        panel_minimized = isTRUE(payload$panel_minimized),
        has_selectize = isTRUE(payload$has_selectize),
        is_open = isTRUE(payload$is_open),
        choice_count = perf_scalar_or_default(payload$choice_count),
        selected_count = perf_scalar_or_default(payload$selected_count),
        selected_value = notes_trace_text(payload$selected_value, default = "<none>"),
        selected_label = notes_trace_text(payload$selected_label, default = "<none>"),
        control_input_present = isTRUE(payload$control_input_present),
        control_input_disabled = if (is.null(payload$control_input_disabled)) "NULL" else as.character(isTRUE(payload$control_input_disabled)),
        control_input_tabindex = notes_trace_text(payload$control_input_tabindex, default = "<none>"),
        control_input_value = notes_trace_text(payload$control_input_value, default = ""),
        active_element = notes_trace_text(payload$active_element, default = "<none>"),
        key = notes_trace_text(payload$key, default = "NULL"),
        which = perf_scalar_or_default(payload$which),
        control_input_value_before = notes_trace_text(payload$control_input_value_before, default = ""),
        control_input_value_after = notes_trace_text(payload$control_input_value_after, default = ""),
        panel_geometry_present = !is.null(panel_geometry),
        panel_left = perf_scalar_or_default(panel_geometry$left),
        panel_top = perf_scalar_or_default(panel_geometry$top),
        panel_right = perf_scalar_or_default(panel_geometry$right),
        panel_bottom = perf_scalar_or_default(panel_geometry$bottom),
        panel_width = perf_scalar_or_default(panel_geometry$width),
        panel_height = perf_scalar_or_default(panel_geometry$height),
        panel_viewport_width = perf_scalar_or_default(panel_geometry$viewport_width),
        panel_viewport_height = perf_scalar_or_default(panel_geometry$viewport_height),
        panel_header_reachable = if (is.null(panel_geometry$header_reachable)) "NULL" else as.character(isTRUE(panel_geometry$header_reachable)),
        panel_fully_in_viewport = if (is.null(panel_geometry$fully_in_viewport)) "NULL" else as.character(isTRUE(panel_geometry$fully_in_viewport)),
        panel_recovery_changed = if (is.null(payload$changed)) "NULL" else as.character(isTRUE(payload$changed)),
        panel_recovery_hard_reset = if (is.null(payload$hard_reset)) "NULL" else as.character(isTRUE(payload$hard_reset)),
        panel_recovery_steps = notes_trace_values(payload$steps, default = "<none>"),
        client_ts = perf_scalar_or_default(payload$captured_at_iso),
        request_action_id = perf_scalar_or_default(payload$request_action_id),
        request_mutation_seq = perf_scalar_or_default(payload$request_mutation_seq),
        request_ts = perf_scalar_or_default(payload$request_ts)
      )
    )
  }, ignoreInit = TRUE)

  observeEvent(input$client_psd_map_country_probe, {
    payload <- input$client_psd_map_country_probe
    if (is.null(payload)) return()

    psd_transition_trace(
      event = "client_psd_map_country_probe",
      reason = "client_psd_map_probe",
      details = list(
        probe_reason = perf_scalar_or_default(payload$reason),
        client_step = perf_scalar_or_default(payload$client_step),
        has_selectize = isTRUE(payload$has_selectize),
        is_open = isTRUE(payload$is_open),
        choice_count = perf_scalar_or_default(payload$choice_count),
        selected_count = perf_scalar_or_default(payload$selected_count),
        selected_value = perf_scalar_or_default(payload$selected_value),
        selected_label = perf_scalar_or_default(payload$selected_label),
        request_id = perf_scalar_or_default(payload$request_id),
        request_phase = perf_scalar_or_default(payload$request_phase %||% payload$phase),
        request_target_country = perf_scalar_or_default(payload$request_target_country %||% payload$target_country),
        input_id = perf_scalar_or_default(payload$input_id),
        dom_value_before = perf_scalar_or_default(payload$dom_value_before),
        dom_value_after = perf_scalar_or_default(payload$dom_value_after),
        control_present = if (is.null(payload$control_present)) "NULL" else as.character(isTRUE(payload$control_present)),
        matched_requested_value = if (is.null(payload$matched_requested_value)) "NULL" else as.character(isTRUE(payload$matched_requested_value)),
        control_input_present = isTRUE(payload$control_input_present),
        control_input_disabled = if (is.null(payload$control_input_disabled)) "NULL" else as.character(isTRUE(payload$control_input_disabled)),
        control_input_tabindex = perf_scalar_or_default(payload$control_input_tabindex),
        control_input_value = perf_scalar_or_default(payload$control_input_value, default = ""),
        active_element = perf_scalar_or_default(payload$active_element),
        client_ts = perf_scalar_or_default(payload$captured_at_iso),
        request_action_id = perf_scalar_or_default(payload$action_id),
        request_mutation_seq = perf_scalar_or_default(payload$mutation_seq),
        request_ts = perf_scalar_or_default(payload$requested_at_utc),
        client_source_switch_epoch_id = perf_scalar_or_default(payload$source_switch_epoch_id),
        stale_source_switch_epoch = source_switch_epoch_is_stale(payload$source_switch_epoch_id)
      ),
      dedupe_key = "client_psd_map_country_probe",
      dedupe_signature = build_transition_trace_signature(list(
        probe_reason = perf_scalar_or_default(payload$reason),
        client_step = perf_scalar_or_default(payload$client_step),
        has_selectize = isTRUE(payload$has_selectize),
        is_open = isTRUE(payload$is_open),
        choice_count = perf_scalar_or_default(payload$choice_count),
        selected_count = perf_scalar_or_default(payload$selected_count),
        selected_value = perf_scalar_or_default(payload$selected_value),
        selected_label = perf_scalar_or_default(payload$selected_label),
        request_id = perf_scalar_or_default(payload$request_id),
        request_phase = perf_scalar_or_default(payload$request_phase %||% payload$phase),
        request_target_country = perf_scalar_or_default(payload$request_target_country %||% payload$target_country),
        input_id = perf_scalar_or_default(payload$input_id),
        dom_value_before = perf_scalar_or_default(payload$dom_value_before),
        dom_value_after = perf_scalar_or_default(payload$dom_value_after),
        control_present = if (is.null(payload$control_present)) "NULL" else as.character(isTRUE(payload$control_present)),
        matched_requested_value = if (is.null(payload$matched_requested_value)) "NULL" else as.character(isTRUE(payload$matched_requested_value)),
        control_input_present = isTRUE(payload$control_input_present),
        control_input_disabled = if (is.null(payload$control_input_disabled)) "NULL" else as.character(isTRUE(payload$control_input_disabled)),
        control_input_tabindex = perf_scalar_or_default(payload$control_input_tabindex),
        control_input_value = perf_scalar_or_default(payload$control_input_value, default = ""),
        active_element = perf_scalar_or_default(payload$active_element),
        request_action_id = perf_scalar_or_default(payload$action_id),
        request_mutation_seq = perf_scalar_or_default(payload$mutation_seq),
        client_source_switch_epoch_id = perf_scalar_or_default(payload$source_switch_epoch_id),
        stale_source_switch_epoch = source_switch_epoch_is_stale(payload$source_switch_epoch_id)
      ))
    )
  }, ignoreInit = TRUE)

  observeEvent(input$client_sidebar_country_probe, {
    payload <- input$client_sidebar_country_probe
    if (is.null(payload)) return()

    psd_transition_trace(
      event = "client_sidebar_country_probe",
      reason = "client_sidebar_probe",
      details = list(
        probe_reason = perf_scalar_or_default(payload$reason),
        has_selectize = isTRUE(payload$has_selectize),
        is_open = isTRUE(payload$is_open),
        choice_count = perf_scalar_or_default(payload$choice_count),
        selected_count = perf_scalar_or_default(payload$selected_count),
        selected_value = perf_scalar_or_default(payload$selected_value),
        selected_label = perf_scalar_or_default(payload$selected_label),
        control_input_present = isTRUE(payload$control_input_present),
        control_input_disabled = if (is.null(payload$control_input_disabled)) "NULL" else as.character(isTRUE(payload$control_input_disabled)),
        control_input_tabindex = perf_scalar_or_default(payload$control_input_tabindex),
        control_input_value = perf_scalar_or_default(payload$control_input_value, default = ""),
        active_element = perf_scalar_or_default(payload$active_element),
        client_ts = perf_scalar_or_default(payload$captured_at_iso),
        request_action_id = perf_scalar_or_default(payload$action_id),
        request_mutation_seq = perf_scalar_or_default(payload$mutation_seq),
        request_ts = perf_scalar_or_default(payload$requested_at_utc),
        client_source_switch_epoch_id = perf_scalar_or_default(payload$source_switch_epoch_id),
        stale_source_switch_epoch = source_switch_epoch_is_stale(payload$source_switch_epoch_id)
      ),
      dedupe_key = "client_sidebar_country_probe",
      dedupe_signature = build_transition_trace_signature(list(
        probe_reason = perf_scalar_or_default(payload$reason),
        has_selectize = isTRUE(payload$has_selectize),
        is_open = isTRUE(payload$is_open),
        choice_count = perf_scalar_or_default(payload$choice_count),
        selected_count = perf_scalar_or_default(payload$selected_count),
        selected_value = perf_scalar_or_default(payload$selected_value),
        selected_label = perf_scalar_or_default(payload$selected_label),
        control_input_present = isTRUE(payload$control_input_present),
        control_input_disabled = if (is.null(payload$control_input_disabled)) "NULL" else as.character(isTRUE(payload$control_input_disabled)),
        control_input_tabindex = perf_scalar_or_default(payload$control_input_tabindex),
        control_input_value = perf_scalar_or_default(payload$control_input_value, default = ""),
        active_element = perf_scalar_or_default(payload$active_element),
        request_action_id = perf_scalar_or_default(payload$action_id),
        request_mutation_seq = perf_scalar_or_default(payload$mutation_seq),
        client_source_switch_epoch_id = perf_scalar_or_default(payload$source_switch_epoch_id),
        stale_source_switch_epoch = source_switch_epoch_is_stale(payload$source_switch_epoch_id)
      ))
    )
  }, ignoreInit = TRUE)

  observeEvent(input$client_psd_map_country_sync_ack, {
    payload <- input$client_psd_map_country_sync_ack
    if (is.null(payload)) return()

    raw_programmatic_sync_before_write <- if (exists("pending_psd_map_country_programmatic_sync", mode = "function")) {
      isolate(pending_psd_map_country_programmatic_sync())
    } else {
      NULL
    }
    current_map_selected_country_at_ack <- if (exists("map_selected_country", mode = "function")) {
      isolate(map_selected_country())
    } else {
      NULL
    }
    pending_psd_target_at_ack <- if (exists("pending_psd_map_country_target", mode = "function")) {
      isolate(pending_psd_map_country_target())
    } else {
      NULL
    }
    pending_sidebar_target_at_ack <- if (exists("pending_sidebar_country_target", mode = "function")) {
      isolate(pending_sidebar_country_target())
    } else {
      NULL
    }

    if (exists("mark_psd_map_country_programmatic_sync", mode = "function")) {
      mark_psd_map_country_programmatic_sync(payload)
    }

    psd_transition_trace(
      event = "client_psd_map_country_sync_ack",
      reason = "client_psd_map_sync_ack",
      details = list(
        ack_stage = perf_scalar_or_default(payload$stage),
        sync_stage = perf_scalar_or_default(payload$stage),
        sync_reason = perf_scalar_or_default(payload$reason),
        ack_phase = perf_scalar_or_default(payload$phase),
        sync_phase = perf_scalar_or_default(payload$phase),
        request_id = perf_scalar_or_default(payload$request_id),
        target_country = perf_scalar_or_default(payload$target_country),
        input_id = perf_scalar_or_default(payload$input_id),
        requested_value = perf_scalar_or_default(payload$requested_value),
        before_value = perf_scalar_or_default(payload$before_value),
        after_value = perf_scalar_or_default(payload$after_value),
        matched_requested_value = if (is.null(payload$matched_requested_value)) "NULL" else as.character(isTRUE(payload$matched_requested_value)),
        has_selectize = if (is.null(payload$has_selectize)) "NULL" else as.character(isTRUE(payload$has_selectize)),
        current_map_selected_country_at_ack = perf_scalar_or_default(current_map_selected_country_at_ack),
        current_input_country_at_ack = perf_scalar_or_default(input$psd_map_country_choice %||% NULL),
        pending_psd_target_at_ack = perf_scalar_or_default(pending_psd_target_at_ack),
        pending_sidebar_target_at_ack = perf_scalar_or_default(pending_sidebar_target_at_ack),
        raw_programmatic_request_id_before_write = perf_scalar_or_default(raw_programmatic_sync_before_write$request_id %||% NULL),
        raw_programmatic_target_country_before_write = perf_scalar_or_default(raw_programmatic_sync_before_write$target_country %||% NULL),
        client_ts = perf_scalar_or_default(payload$captured_at_iso),
        client_source_switch_epoch_id = perf_scalar_or_default(payload$source_switch_epoch_id),
        stale_source_switch_epoch = source_switch_epoch_is_stale(payload$source_switch_epoch_id)
      ),
      dedupe_key = "client_psd_map_country_sync_ack",
      dedupe_signature = build_transition_trace_signature(list(
        ack_stage = perf_scalar_or_default(payload$stage),
        sync_stage = perf_scalar_or_default(payload$stage),
        sync_reason = perf_scalar_or_default(payload$reason),
        ack_phase = perf_scalar_or_default(payload$phase),
        sync_phase = perf_scalar_or_default(payload$phase),
        request_id = perf_scalar_or_default(payload$request_id),
        target_country = perf_scalar_or_default(payload$target_country),
        requested_value = perf_scalar_or_default(payload$requested_value),
        before_value = perf_scalar_or_default(payload$before_value),
        after_value = perf_scalar_or_default(payload$after_value),
        matched_requested_value = if (is.null(payload$matched_requested_value)) "NULL" else as.character(isTRUE(payload$matched_requested_value)),
        has_selectize = if (is.null(payload$has_selectize)) "NULL" else as.character(isTRUE(payload$has_selectize)),
        current_map_selected_country_at_ack = perf_scalar_or_default(current_map_selected_country_at_ack),
        current_input_country_at_ack = perf_scalar_or_default(input$psd_map_country_choice %||% NULL),
        pending_psd_target_at_ack = perf_scalar_or_default(pending_psd_target_at_ack),
        pending_sidebar_target_at_ack = perf_scalar_or_default(pending_sidebar_target_at_ack),
        raw_programmatic_request_id_before_write = perf_scalar_or_default(raw_programmatic_sync_before_write$request_id %||% NULL),
        raw_programmatic_target_country_before_write = perf_scalar_or_default(raw_programmatic_sync_before_write$target_country %||% NULL),
        client_source_switch_epoch_id = perf_scalar_or_default(payload$source_switch_epoch_id),
        stale_source_switch_epoch = source_switch_epoch_is_stale(payload$source_switch_epoch_id)
      ))
    )
  }, ignoreInit = TRUE)

  observeEvent(input$client_sidebar_country_sync_ack, {
    payload <- input$client_sidebar_country_sync_ack
    if (is.null(payload)) return()

    if (exists("clear_pending_sidebar_country_sync_request", mode = "function")) {
      clear_pending_sidebar_country_sync_request(
        request_id = payload$request_id %||% NULL,
        target_country = payload$after_value %||% payload$requested_value %||% payload$target_country %||% NULL,
        matched = isTRUE(payload$matched_requested_value)
      )
    }

    psd_transition_trace(
      event = "client_sidebar_country_sync_ack",
      reason = "client_sidebar_sync_ack",
      details = list(
        sync_stage = perf_scalar_or_default(payload$stage),
        sync_reason = perf_scalar_or_default(payload$reason),
        sync_phase = perf_scalar_or_default(payload$phase),
        request_id = perf_scalar_or_default(payload$request_id),
        target_country = perf_scalar_or_default(payload$target_country),
        input_id = perf_scalar_or_default(payload$input_id),
        requested_value = perf_scalar_or_default(payload$requested_value),
        before_value = perf_scalar_or_default(payload$before_value),
        after_value = perf_scalar_or_default(payload$after_value),
        matched_requested_value = if (is.null(payload$matched_requested_value)) "NULL" else as.character(isTRUE(payload$matched_requested_value)),
        has_selectize = if (is.null(payload$has_selectize)) "NULL" else as.character(isTRUE(payload$has_selectize)),
        client_ts = perf_scalar_or_default(payload$captured_at_iso),
        client_source_switch_epoch_id = perf_scalar_or_default(payload$source_switch_epoch_id),
        stale_source_switch_epoch = source_switch_epoch_is_stale(payload$source_switch_epoch_id)
      ),
      dedupe_key = "client_sidebar_country_sync_ack",
      dedupe_signature = build_transition_trace_signature(list(
        sync_stage = perf_scalar_or_default(payload$stage),
        sync_reason = perf_scalar_or_default(payload$reason),
        sync_phase = perf_scalar_or_default(payload$phase),
        request_id = perf_scalar_or_default(payload$request_id),
        target_country = perf_scalar_or_default(payload$target_country),
        requested_value = perf_scalar_or_default(payload$requested_value),
        before_value = perf_scalar_or_default(payload$before_value),
        after_value = perf_scalar_or_default(payload$after_value),
        matched_requested_value = if (is.null(payload$matched_requested_value)) "NULL" else as.character(isTRUE(payload$matched_requested_value)),
        has_selectize = if (is.null(payload$has_selectize)) "NULL" else as.character(isTRUE(payload$has_selectize)),
        client_source_switch_epoch_id = perf_scalar_or_default(payload$source_switch_epoch_id),
        stale_source_switch_epoch = source_switch_epoch_is_stale(payload$source_switch_epoch_id)
      ))
    )
  }, ignoreInit = TRUE)

  observeEvent(input$client_manual_debug_capture, {
    payload <- input$client_manual_debug_capture
    if (is.null(payload)) return()

    notes_snapshot <- payload$notes_snapshot %||% list()
    psd_snapshot <- payload$psd_snapshot %||% list()
    sidebar_snapshot <- payload$sidebar_snapshot %||% list()
    source_shell_snapshot <- payload$source_shell_snapshot %||% list()
    server_map_selected_country <- if (exists("map_selected_country", mode = "function")) isolate(map_selected_country()) else NULL
    server_pending_sidebar_country <- if (exists("pending_sidebar_country_target", mode = "function")) isolate(pending_sidebar_country_target()) else NULL
    server_pending_psd_country <- if (exists("pending_psd_map_country_target", mode = "function")) isolate(pending_psd_map_country_target()) else NULL
    server_psd_bottom_view <- isolate(input$psd_map_bottom_view %||% psd_map_bottom_view_state() %||% NULL)
    server_safe_source_choice <- tryCatch(isolate(current_source_choice_safe(default = input$data_source_choice %||% "export_sales")), error = function(...) NULL)
    server_safe_main_tab <- tryCatch(isolate(current_main_tab_safe()), error = function(...) NULL)
    source_switch_fields <- tryCatch(source_switch_epoch_fields(include_age = TRUE), error = function(...) list())
    raw_transition_active <- tryCatch(isTRUE(isolate(psd_source_transition_active())), error = function(...) FALSE)
    raw_transition_state <- tryCatch(isolate(psd_source_transition_state()), error = function(...) NULL)
    current_transition_state <- tryCatch(isolate(current_psd_source_transition_state()), error = function(...) NULL)
    map_display_mode_choices <- tryCatch(isolate(map_display_mode_choices_for_current_context()), error = function(...) character(0))
    map_display_mode_choices_value <- if (length(map_display_mode_choices) > 0) paste(as.character(unname(map_display_mode_choices)), collapse = "|") else NULL
    effective_map_mode <- tryCatch(isolate(effective_map_display_mode()), error = function(...) NULL)
    server_year_filter_values <- tryCatch(as.character(input$year_filter %||% character(0)), error = function(...) character(0))
    server_year_filter_values <- server_year_filter_values[nzchar(server_year_filter_values)]
    server_year_filter_checked_values <- if (length(server_year_filter_values) > 0) paste(server_year_filter_values, collapse = "|") else NULL

    transition_field <- function(state, field) {
      if (is.null(state) || is.null(state[[field]])) return(NULL)
      state[[field]]
    }

    notes_trace(
      "manual_debug_capture",
      details = list(
        reason = notes_trace_text(payload$reason, default = "manual_capture"),
        client_notes_selected_value = notes_trace_text(notes_snapshot$selected_value, default = "<none>"),
        client_notes_selected_label = notes_trace_text(notes_snapshot$selected_label, default = "<none>"),
        client_notes_choice_count = perf_scalar_or_default(notes_snapshot$choice_count),
        client_notes_control_value = notes_trace_text(notes_snapshot$control_input_value, default = ""),
        client_notes_panel_visible = isTRUE(notes_snapshot$panel_visible),
        client_notes_panel_minimized = isTRUE(notes_snapshot$panel_minimized),
        client_notes_active_element = notes_trace_text(notes_snapshot$active_element, default = "<none>"),
        server_notes_picker_country = notes_trace_text(input$floating_notes_country_picker, default = "<none>"),
        server_notes_hidden_country = notes_trace_text(input$floating_notes_country, default = "<none>"),
        client_ts = perf_scalar_or_default(payload$captured_at_iso)
      )
    )

    psd_transition_trace(
      event = "manual_debug_capture",
      reason = "manual_debug_capture",
      details = list(
        capture_reason = perf_scalar_or_default(payload$reason, default = "manual_capture"),
        capture_shortcut = perf_scalar_or_default(payload$shortcut),
        client_active_tab = perf_scalar_or_default(payload$active_tab),
        client_main_tabs_panel = perf_scalar_or_default(payload$main_tabs_panel),
        client_data_source_choice = perf_scalar_or_default(payload$data_source_choice),
        client_sidebar_country = perf_scalar_or_default(payload$sidebar_country),
        client_notes_hidden_country = perf_scalar_or_default(payload$notes_hidden_country),
        client_notes_picker_country = perf_scalar_or_default(payload$notes_picker_country),
        client_psd_map_bottom_view = perf_scalar_or_default(payload$psd_map_bottom_view),
        client_psd_map_country_choice = perf_scalar_or_default(payload$psd_map_country_choice),
        client_psd_has_selectize = isTRUE(psd_snapshot$has_selectize),
        client_psd_is_open = isTRUE(psd_snapshot$is_open),
        client_psd_choice_count = perf_scalar_or_default(psd_snapshot$choice_count),
        client_psd_selected_value = perf_scalar_or_default(psd_snapshot$selected_value),
        client_psd_selected_label = perf_scalar_or_default(psd_snapshot$selected_label),
        client_psd_control_value = perf_scalar_or_default(psd_snapshot$control_input_value, default = ""),
        client_psd_active_element = perf_scalar_or_default(psd_snapshot$active_element),
        client_sidebar_has_selectize = isTRUE(sidebar_snapshot$has_selectize),
        client_sidebar_is_open = isTRUE(sidebar_snapshot$is_open),
        client_sidebar_choice_count = perf_scalar_or_default(sidebar_snapshot$choice_count),
        client_sidebar_selected_value = perf_scalar_or_default(sidebar_snapshot$selected_value),
        client_sidebar_selected_label = perf_scalar_or_default(sidebar_snapshot$selected_label),
        client_sidebar_control_value = perf_scalar_or_default(sidebar_snapshot$control_input_value, default = ""),
        client_sidebar_active_element = perf_scalar_or_default(sidebar_snapshot$active_element),
        client_shell_server_source = perf_scalar_or_default(source_shell_snapshot$server_source),
        client_shell_main_dom_source = perf_scalar_or_default(source_shell_snapshot$main_dom_source),
        client_shell_main_dom_profile = perf_scalar_or_default(source_shell_snapshot$main_dom_profile),
        client_shell_main_nav_link_count = perf_scalar_or_default(source_shell_snapshot$main_nav_link_count),
        client_shell_mismatch_reason = perf_scalar_or_default(source_shell_snapshot$source_shell_mismatch_reason),
        client_shell_top_data_source_dom_value = perf_scalar_or_default(source_shell_snapshot$top_data_source_dom_value),
        client_shell_top_frequency_input_value = perf_scalar_or_default(source_shell_snapshot$top_frequency_input_value),
        client_shell_top_frequency_values = perf_scalar_or_default(source_shell_snapshot$top_frequency_values),
        client_shell_top_psd_helper_present = if (is.null(source_shell_snapshot$top_psd_helper_present)) "NULL" else as.character(isTRUE(source_shell_snapshot$top_psd_helper_present)),
        client_shell_top_year_type_present = if (is.null(source_shell_snapshot$top_year_type_present)) "NULL" else as.character(isTRUE(source_shell_snapshot$top_year_type_present)),
        client_shell_sidebar_psd_country_present = if (is.null(source_shell_snapshot$sidebar_psd_country_present)) "NULL" else as.character(isTRUE(source_shell_snapshot$sidebar_psd_country_present)),
        client_shell_sidebar_psd_country_visible = if (is.null(source_shell_snapshot$sidebar_psd_country_visible)) "NULL" else as.character(isTRUE(source_shell_snapshot$sidebar_psd_country_visible)),
        client_shell_sidebar_non_psd_cutoff_present = if (is.null(source_shell_snapshot$sidebar_non_psd_cutoff_present)) "NULL" else as.character(isTRUE(source_shell_snapshot$sidebar_non_psd_cutoff_present)),
        client_shell_sidebar_non_psd_cutoff_visible = if (is.null(source_shell_snapshot$sidebar_non_psd_cutoff_visible)) "NULL" else as.character(isTRUE(source_shell_snapshot$sidebar_non_psd_cutoff_visible)),
        client_shell_sidebar_visible = if (is.null(source_shell_snapshot$sidebar_visible)) "NULL" else as.character(isTRUE(source_shell_snapshot$sidebar_visible)),
        client_shell_sidebar_blank_or_masked = if (is.null(source_shell_snapshot$sidebar_blank_or_masked)) "NULL" else as.character(isTRUE(source_shell_snapshot$sidebar_blank_or_masked)),
        client_shell_sidebar_visibility = perf_scalar_or_default(source_shell_snapshot$sidebar_visibility),
        client_shell_sidebar_width = perf_scalar_or_default(source_shell_snapshot$sidebar_width),
        client_shell_sidebar_height = perf_scalar_or_default(source_shell_snapshot$sidebar_height),
        client_shell_sidebar_text_length = perf_scalar_or_default(source_shell_snapshot$sidebar_text_length),
        client_shell_sidebar_child_input_count = perf_scalar_or_default(source_shell_snapshot$sidebar_child_input_count),
        client_shell_sidebar_visible_child_input_count = perf_scalar_or_default(source_shell_snapshot$sidebar_visible_child_input_count),
        client_shell_sidebar_child_input_ids = perf_scalar_or_default(source_shell_snapshot$sidebar_child_input_ids),
        client_shell_sidebar_source_profile = perf_scalar_or_default(source_shell_snapshot$sidebar_source_profile),
        client_shell_sidebar_source_epoch = perf_scalar_or_default(source_shell_snapshot$sidebar_source_epoch),
        client_shell_sidebar_rendered_builder = perf_scalar_or_default(source_shell_snapshot$sidebar_rendered_builder),
        client_shell_sidebar_rendered_surface = perf_scalar_or_default(source_shell_snapshot$sidebar_rendered_surface),
        client_shell_sidebar_metadata_mismatch = if (is.null(source_shell_snapshot$sidebar_metadata_mismatch)) "NULL" else as.character(isTRUE(source_shell_snapshot$sidebar_metadata_mismatch)),
        client_shell_psd_map_controls_present = if (is.null(source_shell_snapshot$psd_map_controls_present)) "NULL" else as.character(isTRUE(source_shell_snapshot$psd_map_controls_present)),
        client_shell_psd_map_controls_visible = if (is.null(source_shell_snapshot$psd_map_controls_visible)) "NULL" else as.character(isTRUE(source_shell_snapshot$psd_map_controls_visible)),
        client_shell_sidebar_stale_non_psd = if (is.null(source_shell_snapshot$sidebar_stale_non_psd)) "NULL" else as.character(isTRUE(source_shell_snapshot$sidebar_stale_non_psd)),
        client_shell_psd_controls_missing = if (is.null(source_shell_snapshot$psd_controls_missing)) "NULL" else as.character(isTRUE(source_shell_snapshot$psd_controls_missing)),
        client_shell_bottom_source_profile = perf_scalar_or_default(source_shell_snapshot$bottom_source_profile),
        client_shell_bottom_source_epoch = perf_scalar_or_default(source_shell_snapshot$bottom_source_epoch),
        client_shell_bottom_rendered_builder = perf_scalar_or_default(source_shell_snapshot$bottom_rendered_builder),
        client_shell_bottom_rendered_surface = perf_scalar_or_default(source_shell_snapshot$bottom_rendered_surface),
        client_shell_bottom_metadata_mismatch = if (is.null(source_shell_snapshot$bottom_metadata_mismatch)) "NULL" else as.character(isTRUE(source_shell_snapshot$bottom_metadata_mismatch)),
        client_shell_bottom_psd_view_present = if (is.null(source_shell_snapshot$bottom_psd_view_present)) "NULL" else as.character(isTRUE(source_shell_snapshot$bottom_psd_view_present)),
        client_shell_bottom_psd_current_visible = if (is.null(source_shell_snapshot$bottom_psd_current_visible)) "NULL" else as.character(isTRUE(source_shell_snapshot$bottom_psd_current_visible)),
        client_shell_bottom_psd_comparison_visible = if (is.null(source_shell_snapshot$bottom_psd_comparison_visible)) "NULL" else as.character(isTRUE(source_shell_snapshot$bottom_psd_comparison_visible)),
        client_shell_bottom_non_psd_summary_present = if (is.null(source_shell_snapshot$bottom_non_psd_summary_present)) "NULL" else as.character(isTRUE(source_shell_snapshot$bottom_non_psd_summary_present)),
        client_shell_bottom_non_psd_summary_visible = if (is.null(source_shell_snapshot$bottom_non_psd_summary_visible)) "NULL" else as.character(isTRUE(source_shell_snapshot$bottom_non_psd_summary_visible)),
        client_shell_bottom_stale_non_psd = if (is.null(source_shell_snapshot$bottom_stale_non_psd)) "NULL" else as.character(isTRUE(source_shell_snapshot$bottom_stale_non_psd)),
        client_shell_map_plot_visible = if (is.null(source_shell_snapshot$map_plot_visible)) "NULL" else as.character(isTRUE(source_shell_snapshot$map_plot_visible)),
        client_shell_timeseries_plot_present = if (is.null(source_shell_snapshot$timeseries_plot_present)) "NULL" else as.character(isTRUE(source_shell_snapshot$timeseries_plot_present)),
        client_shell_timeseries_visible = if (is.null(source_shell_snapshot$timeseries_visible)) "NULL" else as.character(isTRUE(source_shell_snapshot$timeseries_visible)),
        client_shell_timeseries_state = perf_scalar_or_default(source_shell_snapshot$timeseries_state),
        client_shell_timeseries_text_excerpt = perf_scalar_or_default(source_shell_snapshot$timeseries_text_excerpt),
        client_shell_year_filter_present = if (is.null(source_shell_snapshot$year_filter_present)) "NULL" else as.character(isTRUE(source_shell_snapshot$year_filter_present)),
        client_shell_year_filter_visible = if (is.null(source_shell_snapshot$year_filter_visible)) "NULL" else as.character(isTRUE(source_shell_snapshot$year_filter_visible)),
        client_shell_year_filter_option_count = perf_scalar_or_default(source_shell_snapshot$year_filter_option_count),
        client_shell_year_filter_checked_count = perf_scalar_or_default(source_shell_snapshot$year_filter_checked_count),
        client_shell_year_filter_checked_values = perf_scalar_or_default(source_shell_snapshot$year_filter_checked_values),
        client_shell_source_shell_mismatch = if (is.null(source_shell_snapshot$source_shell_mismatch)) "NULL" else as.character(isTRUE(source_shell_snapshot$source_shell_mismatch)),
        server_data_source_choice = perf_scalar_or_default(input$data_source_choice),
        server_current_source_choice = perf_scalar_or_default(server_safe_source_choice),
        server_data_frequency = perf_scalar_or_default(input$data_frequency),
        server_main_tabs_panel = perf_scalar_or_default(input$main_tabs_panel),
        server_current_main_tab = perf_scalar_or_default(server_safe_main_tab),
        server_source_switch_age_ms = perf_scalar_or_default(source_switch_fields$source_switch_age_ms),
        server_raw_psd_transition_active = as.character(isTRUE(raw_transition_active)),
        server_raw_psd_transition_tab = perf_scalar_or_default(transition_field(raw_transition_state, "tab")),
        server_raw_psd_transition_frequency = perf_scalar_or_default(transition_field(raw_transition_state, "frequency")),
        server_raw_psd_transition_metric = perf_scalar_or_default(transition_field(raw_transition_state, "metric")),
        server_raw_psd_transition_basis = perf_scalar_or_default(transition_field(raw_transition_state, "basis")),
        server_current_psd_transition_tab = perf_scalar_or_default(transition_field(current_transition_state, "tab")),
        server_current_psd_transition_frequency = perf_scalar_or_default(transition_field(current_transition_state, "frequency")),
        server_current_psd_transition_metric = perf_scalar_or_default(transition_field(current_transition_state, "metric")),
        server_current_psd_transition_basis = perf_scalar_or_default(transition_field(current_transition_state, "basis")),
        server_map_comparison_mode = perf_scalar_or_default(input$map_comparison_mode),
        server_effective_map_display_mode = perf_scalar_or_default(effective_map_mode),
        server_map_display_mode_choices = perf_scalar_or_default(map_display_mode_choices_value),
        server_sidebar_country = perf_scalar_or_default(input$country_choice),
        server_psd_map_bottom_view = perf_scalar_or_default(server_psd_bottom_view),
        server_psd_map_country_choice = perf_scalar_or_default(input$psd_map_country_choice),
        server_map_selected_country = perf_scalar_or_default(server_map_selected_country),
        server_pending_sidebar_country = perf_scalar_or_default(server_pending_sidebar_country),
        server_pending_psd_country = perf_scalar_or_default(server_pending_psd_country),
        server_year_filter_checked_count = perf_scalar_or_default(length(server_year_filter_values)),
        server_year_filter_checked_values = perf_scalar_or_default(server_year_filter_checked_values),
        client_ts = perf_scalar_or_default(payload$captured_at_iso)
      ),
      force = TRUE
    )
  }, ignoreInit = TRUE)

  output$data_quality_warning_ui <- renderUI({
    req(input$data_frequency)

    if (!identical(input$data_frequency, "weekly")) return(NULL)
    if (!nzchar(weekly_all_na_warning_message)) return(NULL)

    div(
      style = "padding: 8px; background-color: #fff3cd; border: 1px solid #ffeeba; color: #856404; margin-top: 8px; border-radius: 4px;",
      strong("Weekly data quality warning: "),
      span(weekly_all_na_warning_message)
    )
  })

  # ============================================================================
  # NOTES MANAGEMENT (Floating Panel)
  # ============================================================================

  replace_current_user_notes_in_all_notes <- function(updated_notes, reason = "current_user_update") {
    existing_all_notes <- normalize_notes_df(all_notes_data(), include_user = TRUE)
    updated_user_notes <- normalize_notes_df(updated_notes, include_user = TRUE)
    updated_user_notes$user <- user_id

    other_notes <- existing_all_notes[existing_all_notes$user != user_id, , drop = FALSE]
    next_all_notes <- dplyr::bind_rows(other_notes, updated_user_notes)
    all_notes_data(next_all_notes)

    notes_trace(
      "all_notes_current_user_replaced",
      details = list(
        reason = reason,
        user_rows = nrow(updated_user_notes),
        other_rows = nrow(other_notes),
        total_rows = nrow(next_all_notes)
      ),
      force = TRUE
    )

    invisible(next_all_notes)
  }

  refresh_all_notes_data_from_disk <- function(reason = "refresh") {
    refresh_start_time <- Sys.time()
    refreshed_notes <- tryCatch(
      load_all_notes(notes_dir, perf_context = paste0("notes_", reason, "(load_all_notes)")),
      error = function(e) {
        notes_trace(
          "all_notes_refresh_failed",
          details = list(reason = reason, error = conditionMessage(e)),
          force = TRUE
        )
        showNotification(
          paste("Could not refresh other users' notes:", conditionMessage(e)),
          type = "warning",
          duration = 8
        )
        NULL
      }
    )

    if (is.null(refreshed_notes)) {
      return(FALSE)
    }

    all_notes_data(refreshed_notes)
    log_perf(
      paste0("notes_", reason, "(refresh_all_notes_data)"),
      refresh_start_time,
      details = list(rows = nrow(refreshed_notes), users = dplyr::n_distinct(refreshed_notes$user))
    )
    notes_trace(
      "all_notes_refresh_completed",
      details = list(reason = reason, rows = nrow(refreshed_notes), users = dplyr::n_distinct(refreshed_notes$user)),
      force = TRUE
    )

    TRUE
  }

  # Show modal with other users' notes when button is clicked
  observeEvent(input$view_other_notes_btn, {
    country_code <- current_notes_country()
    req(country_code)
    refresh_all_notes_data_from_disk("view_other_notes")
    # Filter all_notes_df for this country, excluding current user
    notes_df <- all_notes_for_family()
    other_notes <- notes_df[notes_df$country == country_code & notes_df$user != user_id, ]
    if (nrow(other_notes) == 0) {
      notes_ui <- div("No notes from other users for this country.")
    } else {
      notes_ui <- tagList(
        lapply(seq_len(nrow(other_notes)), function(i) {
          div(
            style = "margin-bottom: 18px; padding: 8px; border: 1px solid #eee; border-radius: 5px; background: #fafbfc;",
            strong(paste0("User: ", other_notes$user[i])),
            br(),
            em(paste0("Last updated: ", other_notes$last_updated[i])),
            br(),
            div(style = "margin-top: 6px; white-space: pre-wrap;", other_notes$note[i])
          )
        })
      )
    }
    showModal(modalDialog(
      title = paste("Other Users' Notes for", notes_country_display_label(country_code)),
      notes_ui,
      easyClose = TRUE,
      footer = modalButton("Close")
    ))
  })

  # Warning banner for Market Year Comparison Tool when metric unsupported
  output$partner_share_warning <- renderUI({
    if (!is_market_year_comparison_output_active()) {
      record_myc_partner_output_lifecycle("warning", "gated_skip")
      return(NULL)
    }

    record_myc_partner_output_lifecycle("warning", "executed")
    req(effective_main_metric(), input$data_frequency)

    source_choice <- current_source_choice_safe()
    partner_allowed <- if (identical(source_choice, "vp_trade")) {
      c("ytd_exports", "ytd_value")
    } else {
      c("ytd_exports", "total_commitment")
    }
    allowed_labels <- if (identical(source_choice, "wasde")) {
      "Qty of Exports or Total Domestic Use"
    } else if (identical(source_choice, "vp_trade")) {
      "Accumulated Exports or Accumulated Value"
    } else {
      "Accumulated Exports or Current MY Total Commitment"
    }

    warning_blocks <- list()

    build_warning_block <- function(title_text, body_children) {
      div(
        style = "padding: 8px; background-color: #fff3cd; border: 1px solid #ffeeba; color: #856404; margin-bottom: 10px; border-radius: 4px;",
        strong(title_text),
        body_children
      )
    }

    if (!(effective_main_metric() %in% partner_allowed)) {
      warning_blocks[[length(warning_blocks) + 1L]] <- build_warning_block(
        "Metric not supported for Market Year Comparison Tool.",
        span(paste0(" Please choose ", allowed_labels, "."))
      )
    }

    native_overlap_messages <- myc_native_hybrid_overlap_messages()
    if (length(native_overlap_messages) > 0) {
      warning_blocks[[length(warning_blocks) + 1L]] <- build_warning_block(
        "Hybrid hierarchy overlap warning.",
        tags$ul(
          style = "margin-top: 6px; margin-bottom: 0; padding-left: 18px;",
          lapply(unique(native_overlap_messages), tags$li)
        )
      )
    }

    custom_override_messages <- myc_custom_integrity_override_messages()
    if (length(custom_override_messages) > 0) {
      warning_blocks[[length(warning_blocks) + 1L]] <- build_warning_block(
        "Custom overlap integrity notice.",
        tags$ul(
          style = "margin-top: 6px; margin-bottom: 0; padding-left: 18px;",
          lapply(unique(custom_override_messages), tags$li)
        )
      )
    }

    country_overlap_messages <- myc_country_overlap_legalization_messages()
    if (length(country_overlap_messages) > 0) {
      warning_blocks[[length(warning_blocks) + 1L]] <- build_warning_block(
        "Custom-country overlap legalization notice.",
        tags$ul(
          style = "margin-top: 6px; margin-bottom: 0; padding-left: 18px;",
          lapply(unique(country_overlap_messages), tags$li)
        )
      )
    }

    if (length(warning_blocks) == 0) {
      return(NULL)
    }

    do.call(tagList, warning_blocks)
  })

  # Load notes from CSV file at app startup (current user only)
  notes_data <- reactiveVal(load_notes(user_notes_path))

  notes_source_family_for_source <- function(source_choice = NULL) {
    if (is.null(source_choice) || !nzchar(source_choice)) {
      source_choice <- "export_sales"
    }

    if (identical(source_choice, "psd")) {
      return("global")
    }

    "domestic"
  }

  current_notes_source_family <- reactive({
    source_choice <- current_source_choice_safe()
    source_family <- notes_source_family_for_source(source_choice)

    notes_trace(
      "current_notes_source_family",
      details = list(
        source_choice = source_choice,
        source_family = source_family
      ),
      dedupe_key = "current_notes_source_family",
      dedupe_signature = build_transition_trace_signature(list(
        source_choice = source_choice,
        source_family = source_family
      ))
    )

    source_family
  })

  notes_family_title_text <- function(source_family = current_notes_source_family()) {
    if (identical(source_family, "global")) {
      return("Global Notes")
    }

    "Domestic Notes"
  }

  notes_family_note_text <- function(source_family = current_notes_source_family()) {
    if (identical(source_family, "global")) {
      return("global note")
    }

    "domestic note"
  }

  notes_active_country_choices <- function(include_share_suffix = FALSE) {
    if (identical(current_source_choice_safe(), "psd")) {
      append_custom_country_choices <- function(choice_vector) {
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
          return(choice_vector)
        }

        custom_values <- vapply(defs_tbl$custom_name, build_custom_country_choice_value, character(1))
        custom_labels <- paste0(defs_tbl$custom_name, " (Custom)")
        c(choice_vector, stats::setNames(custom_values, custom_labels))
      }

      psd_state <- tryCatch(psd_canonical_country_state(), error = function(e) NULL)

      if (is.list(psd_state) && is.data.frame(psd_state$ordered_df) && nrow(psd_state$ordered_df) > 0) {
        if (isTRUE(include_share_suffix)) {
          return(append_custom_country_choices(build_psd_country_choice_vector(
            ordered_df = psd_state$ordered_df,
            share_lookup = psd_state$share_lookup,
            metric_code = psd_state$metric_col %||% effective_main_metric()
          )))
        }

        choice_values <- trimws(as.character(psd_state$ordered_df$country %||% character(0)))
        choice_labels <- trimws(as.character(psd_state$ordered_df$country_label %||% character(0)))
        keep_rows <- !is.na(choice_values) & nzchar(choice_values) & !is.na(choice_labels) & nzchar(choice_labels)

        if (any(keep_rows)) {
          return(append_custom_country_choices(stats::setNames(choice_values[keep_rows], choice_labels[keep_rows])))
        }
      }

      return(NULL)
    }

    legal_country_choices <- tryCatch(country_choice_options(), error = function(e) NULL)
    legal_country_values <- as.character(unname(legal_country_choices) %||% character(0))
    legal_country_values <- legal_country_values[!is.na(legal_country_values) & nzchar(legal_country_values)]

    if (length(legal_country_values) > 0) {
      return(legal_country_choices)
    }

    tryCatch(country_display_names_for_frequency(), error = function(e) NULL)
  }

  current_notes_display_label <- function(country_code) {
    frequency_choices <- notes_active_country_choices()
    base_choices <- if (!is.null(country_display_names) && length(country_display_names) > 0) {
      country_display_names
    } else {
      setNames("GRAND_TOTAL", "World")
    }

    notes_country_display_label(
      country_code,
      frequency_choices = frequency_choices,
      base_choices = base_choices
    )
  }

  user_notes_for_family <- reactive({
    current_family <- current_notes_source_family()
    notes_df <- normalize_notes_df(notes_data())
    notes_df[notes_df$source_family == current_family, , drop = FALSE]
  })

  all_notes_for_family <- reactive({
    current_family <- current_notes_source_family()
    notes_df <- normalize_notes_df(all_notes_data(), include_user = TRUE)
    notes_df[notes_df$source_family == current_family, , drop = FALSE]
  })

  normalize_notes_country_codes <- function(values) {
    cleaned_values <- canonicalize_notes_country_codes(values)
    cleaned_values <- trimws(as.character(cleaned_values))
    cleaned_values[is.na(cleaned_values)] <- ""

    unique(cleaned_values[nzchar(cleaned_values)])
  }

  clean_notes_country_values <- function(values) {
    cleaned_values <- trimws(as.character(values))
    cleaned_values[is.na(cleaned_values)] <- ""

    unique(cleaned_values[nzchar(cleaned_values)])
  }

  normalize_notes_country_label <- function(value) {
    cleaned_value <- trimws(as.character(value %||% ""))
    if (!nzchar(cleaned_value)) return("")
    if (identical(cleaned_value, "GRAND_TOTAL")) return("World")

    stringr::str_to_title(tolower(cleaned_value))
  }

  normalize_notes_country_display_key <- function(values) {
    cleaned_values <- trimws(as.character(values))
    cleaned_values[is.na(cleaned_values)] <- ""
    cleaned_values <- gsub("\\s*\\([^)]*%\\)\\s*$", "", cleaned_values)

    normalize_notes_country_lookup_key(cleaned_values)
  }

  notes_exact_sidebar_country_label <- function(country_code, frequency_choices = NULL, base_choices = NULL) {
    label_candidates <- c(
      names(frequency_choices)[unname(frequency_choices) == country_code],
      names(base_choices)[unname(base_choices) == country_code]
    )

    cleaned_labels <- trimws(as.character(label_candidates))
    cleaned_labels <- cleaned_labels[!is.na(cleaned_labels) & nzchar(cleaned_labels)]
    cleaned_labels <- unique(cleaned_labels)

    if (length(cleaned_labels) == 0) {
      return("")
    }

    cleaned_labels[[1]]
  }

  notes_country_display_label <- function(country_code, frequency_choices = NULL, base_choices = NULL) {
    normalized_code <- normalize_notes_country_codes(country_code)
    if (length(normalized_code) == 0) return("")

    country_code <- normalized_code[[1]]
    if (identical(country_code, "GRAND_TOTAL")) return("World")

    exact_sidebar_label <- notes_exact_sidebar_country_label(
      country_code,
      frequency_choices = frequency_choices,
      base_choices = base_choices
    )
    if (nzchar(exact_sidebar_label)) {
      return(exact_sidebar_label)
    }

    display_country <- get_display_country(country_code)
    if (!identical(display_country, country_code) && !is.na(display_country) && nzchar(display_country)) {
      return(display_country)
    }

    normalized_code_label <- normalize_notes_country_label(country_code)
    if (nzchar(normalized_code_label)) {
      return(normalized_code_label)
    }

    country_code
  }

  normalize_notes_choice_frame <- function(choice_vector) {
    choice_labels <- as.character(names(choice_vector) %||% character(0))
    choice_values <- as.character(unname(choice_vector) %||% character(0))
    keep_rows <- !is.na(choice_values) & nzchar(choice_values)

    if (!any(keep_rows)) {
      return(data.frame(
        label = character(),
        value = character(),
        canonical_value = character(),
        label_key = character(),
        stringsAsFactors = FALSE
      ))
    }

    choice_labels <- choice_labels[keep_rows]
    choice_values <- choice_values[keep_rows]

    data.frame(
      label = choice_labels,
      value = choice_values,
      canonical_value = canonicalize_notes_country_codes(choice_values),
      label_key = normalize_notes_country_display_key(choice_labels),
      stringsAsFactors = FALSE
    )
  }

  resolve_notes_country_choice <- function(country_code, choice_vector, frequency_choices = NULL, base_choices = NULL) {
    normalized_country <- normalize_notes_country_codes(country_code)
    if (length(normalized_country) == 0) {
      return(NULL)
    }

    normalized_country <- normalized_country[[1]]
    choice_frame <- normalize_notes_choice_frame(choice_vector)
    if (nrow(choice_frame) == 0) {
      return(NULL)
    }

    exact_match <- choice_frame[choice_frame$value == normalized_country, , drop = FALSE]
    if (nrow(exact_match) > 0) {
      return(exact_match$value[[1]])
    }

    canonical_country <- canonicalize_notes_country_codes(normalized_country)
    canonical_country <- if (length(canonical_country) > 0) canonical_country[[1]] else normalized_country
    canonical_match <- choice_frame[choice_frame$canonical_value == canonical_country, , drop = FALSE]
    if (nrow(canonical_match) > 0) {
      return(canonical_match$value[[1]])
    }

    target_label <- notes_country_display_label(
      normalized_country,
      frequency_choices = frequency_choices,
      base_choices = base_choices
    )
    target_label_key <- normalize_notes_country_display_key(target_label)
    label_match <- choice_frame[choice_frame$label_key == target_label_key, , drop = FALSE]
    if (nrow(label_match) > 0) {
      return(label_match$value[[1]])
    }

    NULL
  }

  notes_country_choices <- reactive({
    frequency_choices <- notes_active_country_choices()
    base_choices <- if (!is.null(country_display_names) && length(country_display_names) > 0) {
      country_display_names
    } else {
      setNames("GRAND_TOTAL", "World")
    }

    scoped_user_notes <- user_notes_for_family()
    scoped_all_notes <- all_notes_for_family()

    candidate_priority_lookup <- c(active_frequency = 1L, global_base = 2L, note_backed = 3L)
    candidate_frames <- list()

    append_candidate_rows <- function(codes, provenance, canonicalize_values = TRUE) {
      candidate_codes <- if (isTRUE(canonicalize_values)) {
        normalize_notes_country_codes(codes)
      } else {
        clean_notes_country_values(codes)
      }

      if (length(candidate_codes) == 0) {
        return(invisible(NULL))
      }

      candidate_frames[[length(candidate_frames) + 1L]] <<- data.frame(
        country = candidate_codes,
        provenance = provenance,
        source_priority = unname(candidate_priority_lookup[[provenance]]),
        stringsAsFactors = FALSE
      )

      invisible(NULL)
    }

    append_candidate_rows(
      if (!is.null(frequency_choices) && length(frequency_choices) > 0) unname(frequency_choices) else character(0),
      "active_frequency",
      canonicalize_values = FALSE
    )
    append_candidate_rows(unname(base_choices), "global_base", canonicalize_values = FALSE)
    append_candidate_rows(c(scoped_user_notes$country, scoped_all_notes$country), "note_backed")

    if (length(candidate_frames) == 0) {
      return(stats::setNames(character(), character()))
    }

    candidate_df <- do.call(rbind, candidate_frames)
    candidate_df$label <- vapply(
      candidate_df$country,
      notes_country_display_label,
      character(1),
      frequency_choices = frequency_choices,
      base_choices = base_choices
    )

    keep_rows <-
      !is.na(candidate_df$country) & nzchar(candidate_df$country) &
      !is.na(candidate_df$label) & nzchar(candidate_df$label)
    candidate_df <- candidate_df[keep_rows, , drop = FALSE]

    if (nrow(candidate_df) == 0) {
      return(stats::setNames(character(), character()))
    }

    candidate_df <- candidate_df[order(candidate_df$source_priority, candidate_df$country), , drop = FALSE]
    label_keys <- normalize_notes_country_display_key(candidate_df$label)
    candidate_df <- candidate_df[!duplicated(label_keys), , drop = FALSE]
    candidate_df <- candidate_df[order(candidate_df$label != "World", candidate_df$label, candidate_df$country), , drop = FALSE]

    choice_vector <- stats::setNames(candidate_df$country, candidate_df$label)

    notes_trace(
      "notes_country_choices",
      details = list(
        source_family = current_notes_source_family(),
        frequency_choice_count = length(frequency_choices %||% character(0)),
        base_choice_count = length(base_choices %||% character(0)),
        note_backed_count = length(normalize_notes_country_codes(c(scoped_user_notes$country, scoped_all_notes$country))),
        choice_count = length(choice_vector),
        first_choice = if (length(choice_vector) > 0) unname(choice_vector[[1]]) else NULL
      ),
      dedupe_key = "notes_country_choices",
      dedupe_signature = build_transition_trace_signature(list(
        source_family = current_notes_source_family(),
        frequency_choice_count = length(frequency_choices %||% character(0)),
        base_choice_count = length(base_choices %||% character(0)),
        note_backed_count = length(normalize_notes_country_codes(c(scoped_user_notes$country, scoped_all_notes$country))),
        choice_values = paste(as.character(unname(choice_vector) %||% character(0)), collapse = "|"),
        choice_labels = paste(as.character(names(choice_vector) %||% character(0)), collapse = "|")
      ))
    )

    choice_vector
  })

  save_note_for_country_if_changed <- function(country_code, note_text, source_family = current_notes_source_family()) {
    if (is.null(country_code) || !nzchar(country_code)) return(FALSE)

    save_path_start_time <- Sys.time()

    current_notes <- notes_data()
    existing_note <- get_note(country_code, current_notes, source_family = source_family)
    if (identical(existing_note, note_text)) {
      return(FALSE)
    }

    updated_notes <- update_note(country_code, note_text, current_notes, source_family = source_family)
    notes_data(updated_notes)
    replace_current_user_notes_in_all_notes(updated_notes, reason = "save_note_for_country_if_changed")

    save_result <- tryCatch({
      save_notes(updated_notes, user_notes_path, perf_context = "notes_save_user_notes")
      TRUE
    }, error = function(e) {
      notes_trace(
        "notes_save_failed",
        details = list(
          country = perf_scalar_or_default(country_code),
          source_family = perf_scalar_or_default(source_family),
          error = conditionMessage(e),
          user_notes_file = basename(user_notes_path)
        ),
        force = TRUE
      )
      showNotification(
        paste("Could not write Notes CSV. Your edit is kept in this app session, but it may not be saved to disk:", conditionMessage(e)),
        type = "error",
        duration = 10
      )
      FALSE
    })

    log_perf(
      "notes_save(save_note_for_country_if_changed)",
      save_path_start_time,
      details = list(
        country = country_code,
        source_family = source_family,
        saved_to_disk = save_result,
        rows = nrow(updated_notes)
      )
    )
    notes_trace(
      "notes_save_completed",
      details = list(
        country = perf_scalar_or_default(country_code),
        source_family = perf_scalar_or_default(source_family),
        saved_to_disk = save_result,
        rows = nrow(updated_notes)
      ),
      force = TRUE
    )

    isTRUE(save_result)
  }

  build_notes_footer_button <- function(input_id, label, class, style = NULL, disabled = FALSE, title = NULL) {
    button_tag <- actionButton(
      inputId = input_id,
      label = label,
      class = class,
      style = style
    )

    if (!isTRUE(disabled)) {
      return(button_tag)
    }

    disabled_tag <- htmltools::tagAppendAttributes(button_tag, disabled = "disabled")
    if (!is.null(title) && nzchar(title)) {
      disabled_tag <- htmltools::tagAppendAttributes(disabled_tag, title = title)
    }

    disabled_tag
  }
  
  # Track which country's notes are currently being edited
  current_notes_country <- reactiveVal(NULL)
  notes_panel_visible <- reactiveVal(FALSE)
  psd_notes_jump_anchor_country <- reactiveVal(NULL)
  notes_country_control_last_sync <- reactiveVal(NULL)
  notes_hidden_programmatic_selected <- reactiveVal(NULL)
  notes_picker_programmatic_selected <- reactiveVal(NULL)
  notes_family_transition_message <- reactiveVal(NULL)
  notes_pending_family_transition <- reactiveVal(NULL)
  notes_last_source_family <- reactiveVal("domestic")

  committed_notes_country <- reactive({
    hidden_country <- input$floating_notes_country
    if (!is.null(hidden_country) && nzchar(hidden_country)) {
      return(hidden_country)
    }

    current_notes_country()
  })

  notes_effective_sidebar_country <- reactive({
    psd_map_active <- isTRUE(tryCatch(is_psd_effective_map_tab_active(), error = function(e) FALSE)) ||
      isTRUE(tryCatch(is_raw_psd_map_tab_visible(), error = function(e) FALSE))
    source_choice <- if (!is.null(input$data_source_choice)) input$data_source_choice else "export_sales"
    raw_main_tab <- input$main_tabs_panel %||% NULL
    map_sidebar_country <- if (psd_map_active) input$psd_map_country_choice %||% "" else ""
    map_selected <- if (psd_map_active) tryCatch(map_selected_country(), error = function(e) NULL) %||% "" else ""
    map_preferred <- if (psd_map_active && exists("current_psd_map_preferred_country", mode = "function")) {
      tryCatch(current_psd_map_preferred_country(), error = function(e) NULL) %||% ""
    } else {
      ""
    }
    sidebar_country <- input$country_choice %||% ""
    pending_sidebar_country <- as.character(tryCatch(isolate(pending_sidebar_country_target()), error = function(e) NULL) %||% "")
    pending_target <- if (exists("pending_psd_map_country_target", mode = "function")) {
      as.character(tryCatch(isolate(pending_psd_map_country_target()), error = function(e) NULL) %||% "")
    } else {
      ""
    }
    notes_jump_anchor <- as.character(psd_notes_jump_anchor_country() %||% "")
    notes_panel_open <- isTRUE(notes_panel_visible())
    transition_message <- as.character(tryCatch(notes_family_transition_message(), error = function(e) NULL) %||% "")
    notes_country <- as.character(current_notes_country() %||% "")

    guard_target <- if (nzchar(pending_target)) {
      pending_target
    } else if (isTRUE(notes_panel_open) && nzchar(notes_jump_anchor) && identical(notes_jump_anchor, sidebar_country)) {
      notes_jump_anchor
    } else {
      ""
    }

    map_input_mismatch <- isTRUE(psd_map_active) && nzchar(map_sidebar_country) && nzchar(guard_target) && !identical(map_sidebar_country, guard_target)

    if (isTRUE(map_input_mismatch) && nzchar(map_selected) && identical(map_selected, guard_target)) {
      resolved_country <- map_selected
      branch <- "psd_map_guarded_selected_country"
    } else if (isTRUE(map_input_mismatch) && identical(sidebar_country, guard_target)) {
      resolved_country <- sidebar_country
      branch <- "psd_map_guarded_sidebar_country"
    } else if (psd_map_active && nzchar(map_sidebar_country)) {
      resolved_country <- map_sidebar_country
      branch <- "psd_map_input"
    } else if (psd_map_active && nzchar(pending_sidebar_country)) {
      resolved_country <- pending_sidebar_country
      branch <- "psd_map_pending_sidebar_country"
    } else if (psd_map_active && nzchar(map_preferred)) {
      resolved_country <- map_preferred
      branch <- "psd_map_preferred_country"
    } else if (psd_map_active && nzchar(map_selected)) {
      resolved_country <- map_selected
      branch <- "psd_map_selected_country"
    } else if (psd_map_active) {
      resolved_country <- sidebar_country
      branch <- "psd_map_fallback_sidebar"
    } else if (
      identical(source_choice, "psd") &&
      isTRUE(notes_panel_open) &&
      nzchar(transition_message) &&
      nzchar(notes_country) &&
      !identical(notes_country, "GRAND_TOTAL") &&
      !identical(sidebar_country, notes_country)
    ) {
      resolved_country <- notes_country
      branch <- "psd_notes_transition_country"
    } else if (
      identical(source_choice, "psd") &&
      isTRUE(notes_panel_open) &&
      nzchar(pending_sidebar_country) &&
      !identical(pending_sidebar_country, "GRAND_TOTAL") &&
      !identical(sidebar_country, pending_sidebar_country)
    ) {
      resolved_country <- pending_sidebar_country
      branch <- "psd_pending_sidebar_country"
    } else if (
      identical(source_choice, "psd") &&
      identical(raw_main_tab, "Time Series Analysis Tool") &&
      identical(sidebar_country, "GRAND_TOTAL") &&
      nzchar(pending_sidebar_country) &&
      !identical(pending_sidebar_country, "GRAND_TOTAL")
    ) {
      resolved_country <- pending_sidebar_country
      branch <- "psd_time_series_pending_sidebar_country"
    } else {
      resolved_country <- sidebar_country
      branch <- "shared_sidebar"
    }

    notes_trace(
      "notes_effective_sidebar_country",
      details = list(
        psd_map_active = psd_map_active,
        map_input_country = map_sidebar_country,
        map_selected_country = map_selected,
        map_preferred_country = map_preferred,
        sidebar_country = sidebar_country,
        pending_sidebar_country = if (nzchar(pending_sidebar_country)) pending_sidebar_country else NULL,
        pending_target = if (nzchar(pending_target)) pending_target else NULL,
        notes_jump_anchor = if (nzchar(notes_jump_anchor)) notes_jump_anchor else NULL,
        transition_message = if (nzchar(transition_message)) transition_message else NULL,
        notes_country = if (nzchar(notes_country)) notes_country else NULL,
        notes_panel_open = notes_panel_open,
        guard_target = if (nzchar(guard_target)) guard_target else NULL,
        map_input_mismatch = map_input_mismatch,
        resolved_country = resolved_country,
        branch = branch
      ),
      dedupe_key = "notes_effective_sidebar_country",
      dedupe_signature = build_transition_trace_signature(list(
        psd_map_active = psd_map_active,
        map_input_country = map_sidebar_country,
        map_selected_country = map_selected,
        map_preferred_country = map_preferred,
        sidebar_country = sidebar_country,
        pending_sidebar_country = if (nzchar(pending_sidebar_country)) pending_sidebar_country else NULL,
        pending_target = if (nzchar(pending_target)) pending_target else NULL,
        notes_jump_anchor = if (nzchar(notes_jump_anchor)) notes_jump_anchor else NULL,
        transition_message = if (nzchar(transition_message)) transition_message else NULL,
        notes_country = if (nzchar(notes_country)) notes_country else NULL,
        notes_panel_open = notes_panel_open,
        guard_target = if (nzchar(guard_target)) guard_target else NULL,
        map_input_mismatch = map_input_mismatch,
        resolved_country = resolved_country,
        branch = branch
      ))
    )

    resolved_country
  })

  notes_actual_visible_sidebar_country <- function() {
    psd_map_visible <- isTRUE(tryCatch(is_raw_psd_map_tab_visible(), error = function(e) FALSE))
    pending_sidebar_country <- as.character(tryCatch(isolate(pending_sidebar_country_target()), error = function(e) NULL) %||% "")

    if (!psd_map_visible) {
      sidebar_country <- as.character(input$country_choice %||% "")
      if (nzchar(sidebar_country)) {
        return(sidebar_country)
      }
      if (nzchar(pending_sidebar_country)) {
        return(pending_sidebar_country)
      }
      return(notes_effective_sidebar_country())
    }

    map_input_country <- as.character(input$psd_map_country_choice %||% "")
    if (nzchar(map_input_country)) {
      return(map_input_country)
    }

    map_selected_country_value <- as.character(tryCatch(map_selected_country(), error = function(e) NULL) %||% "")
    if (nzchar(map_selected_country_value)) {
      return(map_selected_country_value)
    }

    if (nzchar(pending_sidebar_country)) {
      return(pending_sidebar_country)
    }

    preferred_map_country <- if (exists("current_psd_map_preferred_country", mode = "function")) {
      as.character(tryCatch(current_psd_map_preferred_country(), error = function(e) NULL) %||% "")
    } else {
      ""
    }
    if (nzchar(preferred_map_country)) {
      return(preferred_map_country)
    }

    notes_effective_sidebar_country()
  }

  notes_visible_sidebar_country <- function() {
    psd_map_visible <- isTRUE(tryCatch(is_raw_psd_map_tab_visible(), error = function(e) FALSE))
    source_choice <- as.character(input$data_source_choice %||% "export_sales")
    transition_message <- as.character(tryCatch(notes_family_transition_message(), error = function(e) NULL) %||% "")
    notes_country <- as.character(current_notes_country() %||% "")
    pending_sidebar_country <- as.character(tryCatch(isolate(pending_sidebar_country_target()), error = function(e) NULL) %||% "")

    if (
      identical(source_choice, "psd") &&
      isTRUE(notes_panel_visible()) &&
      nzchar(transition_message) &&
      nzchar(notes_country) &&
      !identical(notes_country, "GRAND_TOTAL")
    ) {
      if (nzchar(pending_sidebar_country) && identical(notes_country, pending_sidebar_country)) {
        return(notes_country)
      }

      if (!psd_map_visible) {
        sidebar_country <- as.character(input$country_choice %||% "")
        if (!identical(sidebar_country, notes_country)) {
          return(notes_country)
        }
      }

      map_input_country <- as.character(input$psd_map_country_choice %||% "")
      if (!identical(map_input_country, notes_country)) {
        return(notes_country)
      }
    }

    if (!psd_map_visible) {
      return(notes_effective_sidebar_country())
    }

    map_input_country <- as.character(input$psd_map_country_choice %||% "")
    if (nzchar(map_input_country)) {
      return(map_input_country)
    }

    map_selected_country_value <- as.character(tryCatch(map_selected_country(), error = function(e) NULL) %||% "")
    if (nzchar(map_selected_country_value)) {
      return(map_selected_country_value)
    }

    if (nzchar(pending_sidebar_country)) {
      return(pending_sidebar_country)
    }

    preferred_map_country <- if (exists("current_psd_map_preferred_country", mode = "function")) {
      as.character(tryCatch(current_psd_map_preferred_country(), error = function(e) NULL) %||% "")
    } else {
      ""
    }
    if (nzchar(preferred_map_country)) {
      return(preferred_map_country)
    }

    notes_effective_sidebar_country()
  }

  notes_sidebar_pull_state <- reactive({
    target_country <- notes_actual_visible_sidebar_country()
    current_notes_selection <- committed_notes_country() %||% ""

    if (is.null(target_country) || !nzchar(target_country)) {
      return(list(
        enabled = FALSE,
        target_country = NULL,
        reason = "Choose a sidebar country before pulling it into Notes."
      ))
    }

    legal_country_choices <- tryCatch(country_choice_options(), error = function(e) NULL)
    legal_country_values <- unique(as.character(unname(legal_country_choices) %||% character(0)))
    legal_country_values <- legal_country_values[!is.na(legal_country_values) & nzchar(legal_country_values)]

    if (length(legal_country_values) == 0) {
      return(list(
        enabled = FALSE,
        target_country = target_country,
        reason = "Sidebar country choices are not ready yet."
      ))
    }

    if (!(target_country %in% legal_country_values)) {
      return(list(
        enabled = FALSE,
        target_country = target_country,
        reason = "The current sidebar country is not available for the active filters."
      ))
    }

    if (identical(current_notes_selection, target_country)) {
      return(list(
        enabled = FALSE,
        target_country = target_country,
        reason = "Notes already match the current sidebar country."
      ))
    }

    list(
      enabled = TRUE,
      target_country = target_country,
      reason = NULL
    )
  })

  notes_sidebar_jump_state <- reactive({
    target_country <- committed_notes_country()
    current_sidebar_country <- notes_effective_sidebar_country()
    is_myc_type_mode <- identical(input$main_tabs_panel, "Market Year Comparison Tool") &&
      identical(market_year_comparison_mode(), "type")

    if (is_myc_type_mode) {
      return(list(
        enabled = FALSE,
        target_country = target_country,
        reason = "Jump unavailable while Market Year Comparison is in type mode."
      ))
    }

    if (is.null(target_country) || !nzchar(target_country)) {
      return(list(
        enabled = FALSE,
        target_country = NULL,
        reason = "Open Notes for a country before jumping it into the sidebar."
      ))
    }

    legal_country_choices <- tryCatch(country_choice_options(), error = function(e) NULL)
    legal_country_values <- unique(as.character(unname(legal_country_choices) %||% character(0)))
    legal_country_values <- legal_country_values[!is.na(legal_country_values) & nzchar(legal_country_values)]
    resolved_target_country <- resolve_notes_country_choice(
      target_country,
      legal_country_choices,
      frequency_choices = legal_country_choices,
      base_choices = country_display_names
    )

    if (length(legal_country_values) == 0) {
      return(list(
        enabled = FALSE,
        target_country = target_country,
        reason = "Sidebar country choices are not ready yet."
      ))
    }

    if (is.null(resolved_target_country) || !nzchar(resolved_target_country)) {
      return(list(
        enabled = FALSE,
        target_country = target_country,
        reason = "The Notes country is not available in the sidebar for the current filters."
      ))
    }

    if (identical(current_sidebar_country, resolved_target_country)) {
      return(list(
        enabled = FALSE,
        target_country = resolved_target_country,
        reason = "Notes already match the current sidebar country."
      ))
    }

    list(
      enabled = TRUE,
      target_country = resolved_target_country,
      reason = NULL
    )
  })

  output$floating_notes_family_context <- renderText({
    notes_family_title_text()
  })

  output$floating_notes_sync_status <- renderText({
    status_lines <- character(0)
    transition_message <- notes_family_transition_message()

    if (!is.null(transition_message) && nzchar(transition_message)) {
      status_lines <- c(status_lines, transition_message)
    }

    notes_country <- committed_notes_country()
    sidebar_country <- notes_actual_visible_sidebar_country()

    if (!is.null(notes_country) && nzchar(notes_country) && nzchar(sidebar_country) && !identical(notes_country, sidebar_country)) {
      status_lines <- c(
        status_lines,
        paste0(
          "Notes: ", current_notes_display_label(notes_country),
          " | Sidebar: ", current_notes_display_label(sidebar_country)
        )
      )
    }

    paste(status_lines, collapse = " ")
  })

  notes_jump_input_targets <- function(target_country) {
    jump_targets <- list(country_choice = target_country)

    psd_map_active <- isTRUE(tryCatch(is_psd_effective_map_tab_active(), error = function(e) FALSE))
    if (!psd_map_active) {
      psd_transition_trace(
        event = "notes_jump_input_targets",
        reason = "notes_jump_targets",
        details = list(
          target_country = target_country,
          psd_map_active = FALSE,
          valid_map_choice_count = 0,
          included_psd_map_target = FALSE,
          dispatched_inputs = paste(names(jump_targets), collapse = "|")
        ),
        dedupe_key = "notes_jump_input_targets",
        dedupe_signature = build_transition_trace_signature(list(
          target_country = target_country,
          psd_map_active = FALSE,
          valid_map_choice_count = 0,
          included_psd_map_target = FALSE,
          dispatched_inputs = paste(names(jump_targets), collapse = "|")
        ))
      )

      return(jump_targets)
    }

    valid_map_choices <- tryCatch(unname(psd_map_country_choices()), error = function(e) character(0))
    valid_map_choices <- as.character(valid_map_choices %||% character(0))
    valid_map_choices <- valid_map_choices[!is.na(valid_map_choices) & nzchar(valid_map_choices)]

    if (target_country %in% valid_map_choices) {
      jump_targets$psd_map_country_choice <- target_country
    }

    psd_transition_trace(
      event = "notes_jump_input_targets",
      reason = "notes_jump_targets",
      details = list(
        target_country = target_country,
        psd_map_active = TRUE,
        valid_map_choice_count = length(valid_map_choices),
        included_psd_map_target = "psd_map_country_choice" %in% names(jump_targets),
        dispatched_inputs = paste(names(jump_targets), collapse = "|")
      ),
      dedupe_key = "notes_jump_input_targets",
      dedupe_signature = build_transition_trace_signature(list(
        target_country = target_country,
        psd_map_active = TRUE,
        valid_map_choice_count = length(valid_map_choices),
        included_psd_map_target = "psd_map_country_choice" %in% names(jump_targets),
        dispatched_inputs = paste(names(jump_targets), collapse = "|")
      ))
    )

    jump_targets
  }

  output$floating_note_empty_state <- renderText({
    country_code <- current_notes_country()
    note_text <- input$floating_note_text %||% ""

    if (is.null(country_code) || !nzchar(country_code) || nzchar(trimws(note_text))) {
      return("")
    }

    paste0(
      "No ", notes_family_note_text(),
      " yet for ", current_notes_display_label(country_code), "."
    )
  })

  output$floating_notes_jump_action <- renderUI({
    pull_state <- notes_sidebar_pull_state()
    jump_state <- notes_sidebar_jump_state()

    div(
      class = "notes-footer-jump-action",
      div(
        class = "notes-footer-buttons",
        build_notes_footer_button(
          "pull_sidebar_country_to_notes",
          "Pull From Sidebar",
          class = "btn-default btn-sm",
          disabled = !isTRUE(pull_state$enabled),
          title = pull_state$reason %||% NULL
        ),
        build_notes_footer_button(
          "jump_notes_country_to_sidebar",
          "Push To Sidebar",
          class = "btn-default btn-sm",
          disabled = !isTRUE(jump_state$enabled),
          title = jump_state$reason %||% NULL
        )
      ),
      if (!isTRUE(pull_state$enabled) && !is.null(pull_state$reason) && nzchar(pull_state$reason)) {
        div(class = "notes-myc-picker-hint notes-footer-hint", paste0("Pull: ", pull_state$reason))
      },
      if (!isTRUE(jump_state$enabled) && !is.null(jump_state$reason) && nzchar(jump_state$reason)) {
        div(class = "notes-myc-picker-hint notes-footer-hint", paste0("Push: ", jump_state$reason))
      }
    )
  })

  outputOptions(output, "floating_notes_jump_action", suspendWhenHidden = FALSE)
  outputOptions(output, "floating_notes_family_context", suspendWhenHidden = FALSE)
  outputOptions(output, "floating_notes_sync_status", suspendWhenHidden = FALSE)
  outputOptions(output, "floating_note_empty_state", suspendWhenHidden = FALSE)

  observeEvent(current_notes_source_family(), {
    next_family <- current_notes_source_family()
    previous_family <- isolate(notes_last_source_family())
    notes_last_source_family(next_family)

    skip_reason <- if (is.null(previous_family)) {
      "no_previous_family"
    } else if (identical(previous_family, next_family)) {
      "no_family_change"
    } else if (!isTRUE(notes_panel_visible())) {
      "panel_hidden"
    } else {
      NULL
    }

    notes_trace(
      "notes_source_family_observed",
      details = list(
        previous_family = previous_family,
        next_family = next_family,
        active_country = perf_scalar_or_default(current_notes_country()),
        panel_visible = isTRUE(notes_panel_visible()),
        branch = if (is.null(skip_reason)) "queue_transition" else skip_reason
      ),
      dedupe_key = "notes_source_family_observed",
      dedupe_signature = build_transition_trace_signature(list(
        previous_family = previous_family,
        next_family = next_family,
        active_country = perf_scalar_or_default(current_notes_country()),
        panel_visible = isTRUE(notes_panel_visible()),
        branch = if (is.null(skip_reason)) "queue_transition" else skip_reason
      ))
    )

    if (!is.null(skip_reason)) {
      return()
    }

    begin_notes_trace_action(
      "notes_source_family_changed",
      details = list(
        previous_family = previous_family,
        next_family = next_family,
        active_country = perf_scalar_or_default(current_notes_country())
      )
    )

    active_country <- current_notes_country()
    saved_note <- FALSE
    if (!is.null(active_country) && nzchar(active_country)) {
      saved_note <- save_note_for_country_if_changed(
        active_country,
        input$floating_note_text %||% "",
        source_family = previous_family
      )
    }

    session$onFlushed(function() {
      notes_pending_family_transition(list(
        previous_family = previous_family,
        next_family = next_family,
        active_country = active_country %||% "",
        saved_previous_note = saved_note
      ))
    }, once = TRUE)
  }, ignoreInit = TRUE)

  observeEvent(notes_pending_family_transition(), {
    transition_state <- notes_pending_family_transition()
    if (is.null(transition_state)) {
      return()
    }
    notes_pending_family_transition(NULL)

    next_family <- transition_state$next_family %||% current_notes_source_family()
    active_country <- transition_state$active_country %||% ""
    previous_family <- transition_state$previous_family %||% ""
    saved_note <- isTRUE(transition_state$saved_previous_note)

    available_choices <- notes_country_choices()
    available_values <- as.character(unname(available_choices) %||% character(0))
    available_values <- available_values[!is.na(available_values) & nzchar(available_values)]
    sidebar_country <- notes_effective_sidebar_country()

    resolved_active_country <- resolve_notes_country_choice(
      active_country,
      available_choices,
      frequency_choices = available_choices,
      base_choices = country_display_names
    )
    resolved_sidebar_country <- resolve_notes_country_choice(
      sidebar_country,
      available_choices,
      frequency_choices = available_choices,
      base_choices = country_display_names
    )

    active_country_legal <- !is.null(resolved_active_country) && nzchar(resolved_active_country)
    sidebar_country_legal <- !is.null(resolved_sidebar_country) && nzchar(resolved_sidebar_country)

    active_country_canonical <- if (isTRUE(active_country_legal)) canonicalize_notes_country_codes(resolved_active_country) else character(0)
    sidebar_country_canonical <- if (isTRUE(sidebar_country_legal)) canonicalize_notes_country_codes(resolved_sidebar_country) else character(0)
    shared_canonical_country <-
      length(active_country_canonical) > 0 &&
      length(sidebar_country_canonical) > 0 &&
      identical(active_country_canonical[[1]], sidebar_country_canonical[[1]])

    prefer_sidebar_materialized_target <-
      isTRUE(active_country_legal) &&
      isTRUE(sidebar_country_legal) &&
      isTRUE(shared_canonical_country) &&
      !identical(resolved_active_country, resolved_sidebar_country)

    target_country <- if (prefer_sidebar_materialized_target) {
      resolved_sidebar_country
    } else if (active_country_legal) {
      resolved_active_country
    } else if (sidebar_country_legal) {
      resolved_sidebar_country
    } else if (length(available_values) > 0) {
      available_values[[1]]
    } else {
      "GRAND_TOTAL"
    }

    target_branch <- if (prefer_sidebar_materialized_target) {
      "sidebar_country_same_canonical"
    } else if (active_country_legal) {
      "active_country"
    } else if (sidebar_country_legal) {
      "sidebar_country"
    } else if (length(available_values) > 0) {
      "first_available"
    } else {
      "explicit_grand_total"
    }

    sidebar_handoff_target <- NULL
    if (exists("country_choice_options", mode = "function")) {
      sidebar_choices <- tryCatch(country_choice_options(), error = function(e) NULL)
      sidebar_handoff_target <- resolve_notes_country_choice(
        target_country,
        sidebar_choices,
        frequency_choices = sidebar_choices,
        base_choices = country_display_names
      )
    }
    sidebar_handoff_target <- sidebar_handoff_target %||% ""
    if (nzchar(sidebar_handoff_target) && !identical(sidebar_handoff_target, "GRAND_TOTAL")) {
      if (exists("pending_sidebar_country_target", mode = "function")) {
        pending_sidebar_country_target(sidebar_handoff_target)
      }
      if (exists("last_valid_sidebar_country", mode = "function")) {
        try(last_valid_sidebar_country(sidebar_handoff_target), silent = TRUE)
      }
    }

    notes_trace(
      "notes_pending_family_transition",
      details = list(
        previous_family = previous_family,
        next_family = next_family,
        active_country = perf_scalar_or_default(active_country),
        resolved_active_country = perf_scalar_or_default(resolved_active_country),
        sidebar_country = perf_scalar_or_default(sidebar_country),
        resolved_sidebar_country = perf_scalar_or_default(resolved_sidebar_country),
        active_country_canonical = perf_scalar_or_default(active_country_canonical),
        sidebar_country_canonical = perf_scalar_or_default(sidebar_country_canonical),
        shared_canonical_country = shared_canonical_country,
        prefer_sidebar_materialized_target = prefer_sidebar_materialized_target,
        available_value_count = length(available_values),
        active_country_legal = active_country_legal,
        sidebar_country_legal = sidebar_country_legal,
        target_country = perf_scalar_or_default(target_country),
        sidebar_handoff_target = perf_scalar_or_default(sidebar_handoff_target),
        target_branch = target_branch,
        saved_previous_note = saved_note
      ),
      dedupe_key = "notes_pending_family_transition",
      dedupe_signature = build_transition_trace_signature(list(
        previous_family = previous_family,
        next_family = next_family,
        active_country = perf_scalar_or_default(active_country),
        resolved_active_country = perf_scalar_or_default(resolved_active_country),
        sidebar_country = perf_scalar_or_default(sidebar_country),
        resolved_sidebar_country = perf_scalar_or_default(resolved_sidebar_country),
        active_country_canonical = perf_scalar_or_default(active_country_canonical),
        sidebar_country_canonical = perf_scalar_or_default(sidebar_country_canonical),
        shared_canonical_country = shared_canonical_country,
        prefer_sidebar_materialized_target = prefer_sidebar_materialized_target,
        available_value_count = length(available_values),
        active_country_legal = active_country_legal,
        sidebar_country_legal = sidebar_country_legal,
        target_country = perf_scalar_or_default(target_country),
        sidebar_handoff_target = perf_scalar_or_default(sidebar_handoff_target),
        target_branch = target_branch,
        saved_previous_note = saved_note
      ))
    )

    current_notes_country(target_country)
    current_note <- get_note(target_country, notes_data(), source_family = next_family)
    sync_notes_country_control(
      preferred_country = target_country,
      reason = "notes_source_family_changed",
      hidden_update_mode = "force",
      picker_update_mode = "force"
    )
    updateTextAreaInput(session, "floating_note_text", value = current_note)
    notes_family_transition_message(
      paste0(
        "Switched to ", tolower(notes_family_title_text(next_family)),
        " for ", current_notes_display_label(target_country), "."
      )
    )
    mark_notes_trace_mutation(
      "notes_source_family_retargeted",
      details = list(
        previous_family = previous_family,
        next_family = next_family,
        previous_country = perf_scalar_or_default(active_country),
        target_country = perf_scalar_or_default(target_country),
        sidebar_handoff_target = perf_scalar_or_default(sidebar_handoff_target),
        target_branch = target_branch,
        available_value_count = length(available_values),
        saved_previous_note = saved_note,
        note_chars = nchar(current_note %||% "")
      )
    )
  }, ignoreInit = TRUE)

  notes_trace_action_id <- reactiveVal(0L)
  notes_trace_mutation_seq <- reactiveVal(0L)

  notes_transition_debug_enabled <- function() {
    isTRUE(getOption("rice_notes_transition_log", default = FALSE))
  }

  notes_selectize_probe_enabled <- function() {
    isTRUE(getOption("rice_notes_selectize_probe", default = FALSE))
  }

  notes_trace_ids <- function() {
    list(
      action_id = isolate(notes_trace_action_id()),
      mutation_seq = isolate(notes_trace_mutation_seq())
    )
  }

  notes_trace_text <- function(value, default = "NULL") {
    if (is.null(value) || length(value) == 0) return(default)

    normalized <- trimws(paste(as.character(value), collapse = "|"))
    normalized <- gsub("[\r\n,]+", ";", normalized)
    if (is.na(normalized) || !nzchar(normalized)) default else normalized
  }

  notes_trace_values <- function(values, default = "<none>") {
    if (is.null(values) || length(values) == 0) return(default)

    cleaned_values <- trimws(as.character(values))
    cleaned_values <- cleaned_values[!is.na(cleaned_values) & nzchar(cleaned_values)]
    if (length(cleaned_values) == 0) return(default)

    cleaned_values <- gsub("[\r\n,]+", ";", cleaned_values)
    paste(unique(cleaned_values), collapse = "|")
  }

  notes_trace <- function(event, details = list(), dedupe_key = NULL, dedupe_signature = NULL, force = FALSE) {
    if (!isTRUE(notes_transition_debug_enabled())) return(invisible(FALSE))

    ids <- notes_trace_ids()
    payload <- c(
      list(
        event = event,
        action_id = ids$action_id,
        mutation_seq = ids$mutation_seq
      ),
      details
    )

    if (!isTRUE(force) && !is.null(dedupe_key) && nzchar(dedupe_key)) {
      if (is.null(dedupe_signature)) {
        dedupe_signature <- build_transition_trace_signature(payload)
      }

      if (!transition_trace_signature_should_emit("notes", dedupe_key, dedupe_signature)) {
        return(invisible(FALSE))
      }
    }

    detail_pairs <- paste(
      names(payload),
      vapply(payload, format_perf_detail_value, character(1)),
      sep = "="
    )

    message(sprintf("[NOTES_TRACE] %s", paste(detail_pairs, collapse = ", ")))
    invisible(TRUE)
  }

  begin_notes_trace_action <- function(trigger, details = list()) {
    next_action_id <- isolate(notes_trace_action_id()) + 1L
    notes_trace_action_id(next_action_id)
    notes_trace_mutation_seq(0L)

    notes_trace(
      "action_begin",
      details = c(
        list(
          trigger = trigger,
          current_country = perf_scalar_or_default(current_notes_country()),
          selected_country = perf_scalar_or_default(input$floating_notes_country),
          panel_visible = isTRUE(isolate(notes_panel_visible()))
        ),
        details
      )
    )

    invisible(next_action_id)
  }

  mark_notes_trace_mutation <- function(event, details = list()) {
    next_seq <- isolate(notes_trace_mutation_seq()) + 1L
    notes_trace_mutation_seq(next_seq)
    notes_trace(event, details = details)
    invisible(next_seq)
  }

  request_notes_country_probe <- function(reason, delay_ms = 60L) {
    if (!isTRUE(notes_selectize_probe_enabled())) {
      return(invisible(FALSE))
    }

    payload <- list(
      reason = reason,
      action_id = isolate(notes_trace_action_id()),
      mutation_seq = isolate(notes_trace_mutation_seq()),
      requested_at_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%OS3Z", tz = "UTC"),
      delay_ms = as.integer(delay_ms)
    )

    session$onFlushed(function() {
      session$sendCustomMessage("captureNotesCountryProbe", payload)
    }, once = TRUE)

    invisible(TRUE)
  }

  build_notes_country_control_state <- function(preferred_country = current_notes_country()) {
    note_country_choices <- notes_country_choices()
    selected_country <- preferred_country
    selection_branch <- "preferred_country"

    if (!is.null(selected_country) && nzchar(selected_country) && !(selected_country %in% unname(note_country_choices))) {
      resolved_country <- resolve_notes_country_choice(
        selected_country,
        note_country_choices,
        frequency_choices = note_country_choices,
        base_choices = country_display_names
      )

      if (!is.null(resolved_country) && nzchar(resolved_country)) {
        selected_country <- resolved_country
        selection_branch <- "resolved_country_alias"
      } else {
        note_country_choices <- c(
          note_country_choices,
          stats::setNames(
            selected_country,
            notes_country_display_label(selected_country)
          )
        )
        selection_branch <- "appended_missing_preferred_country"
      }
    }

    if (is.null(selected_country) || !nzchar(selected_country) || !(selected_country %in% unname(note_country_choices))) {
      if (length(note_country_choices) > 0) {
        selected_country <- unname(note_country_choices)[1]
        selection_branch <- "fallback_first_available"
      } else {
        selected_country <- "GRAND_TOTAL"
        selection_branch <- "explicit_grand_total"
      }
    }

    notes_trace(
      "build_notes_country_control_state",
      details = list(
        preferred_country = perf_scalar_or_default(preferred_country),
        selected_country = perf_scalar_or_default(selected_country),
        choice_count = length(note_country_choices),
        selection_branch = selection_branch
      ),
      dedupe_key = "build_notes_country_control_state",
      dedupe_signature = build_transition_trace_signature(list(
        preferred_country = perf_scalar_or_default(preferred_country),
        selected_country = perf_scalar_or_default(selected_country),
        choice_count = length(note_country_choices),
        selection_branch = selection_branch,
        choice_values = paste(as.character(unname(note_country_choices) %||% character(0)), collapse = "|"),
        choice_labels = paste(as.character(names(note_country_choices) %||% character(0)), collapse = "|")
      ))
    )

    list(
      choices = note_country_choices,
      selected = selected_country
    )
  }

  notes_country_control_signature <- function(control_state) {
    list(
      choice_labels = as.character(names(control_state$choices) %||% character(0)),
      choice_values = as.character(unname(control_state$choices) %||% character(0)),
      selected = as.character(control_state$selected %||% "")
    )
  }

  sync_notes_country_control <- function(preferred_country = current_notes_country(), reason = "notes_country_control_sync", hidden_update_mode = c("auto", "force", "skip"), picker_update_mode = c("auto", "force", "skip")) {
    hidden_update_mode <- match.arg(hidden_update_mode)
    picker_update_mode <- match.arg(picker_update_mode)
    control_state <- build_notes_country_control_state(preferred_country)
    target_signature <- notes_country_control_signature(control_state)
    last_sync_signature <- isolate(notes_country_control_last_sync())
    choices_changed_since_last_sync <- is.null(last_sync_signature) ||
      !identical(last_sync_signature$choice_labels, target_signature$choice_labels) ||
      !identical(last_sync_signature$choice_values, target_signature$choice_values)
    same_as_last_sync <- !is.null(last_sync_signature) && identical(last_sync_signature, target_signature)
    hidden_matches_target <- identical(input$floating_notes_country, control_state$selected)
    picker_matches_target <- identical(input$floating_notes_country_picker, control_state$selected)
    hidden_needs_update <- switch(
      hidden_update_mode,
      force = TRUE,
      skip = FALSE,
      auto = !same_as_last_sync && (!hidden_matches_target || choices_changed_since_last_sync)
    )
    picker_needs_update <- switch(
      picker_update_mode,
      force = TRUE,
      skip = FALSE,
      auto = !same_as_last_sync && (!picker_matches_target || choices_changed_since_last_sync)
    )

    if (!identical(current_notes_country(), control_state$selected)) {
      current_notes_country(control_state$selected)
    }

    notes_trace(
      "notes_country_control_sync",
      details = list(
        reason = reason,
        hidden_update_mode = hidden_update_mode,
        picker_update_mode = picker_update_mode,
        same_as_last_sync = same_as_last_sync,
        choices_changed_since_last_sync = choices_changed_since_last_sync,
        hidden_matches_target = hidden_matches_target,
        picker_matches_target = picker_matches_target,
        hidden_updated = hidden_needs_update,
        picker_updated = picker_needs_update,
        selected_country = notes_trace_text(control_state$selected),
        choice_count = length(control_state$choices),
        choice_values = notes_trace_values(unname(control_state$choices))
      )
    )

    if (hidden_needs_update) {
      notes_hidden_programmatic_selected(control_state$selected)
      updateSelectInput(
        session,
        "floating_notes_country",
        choices = control_state$choices,
        selected = control_state$selected
      )
    } else {
      notes_hidden_programmatic_selected(NULL)
    }

    if (picker_needs_update) {
      notes_picker_programmatic_selected(control_state$selected)
      updateSelectizeInput(
        session,
        "floating_notes_country_picker",
        choices = control_state$choices,
        selected = control_state$selected,
        server = TRUE
      )
    } else {
      notes_picker_programmatic_selected(NULL)
    }

    notes_country_control_last_sync(target_signature)

    request_notes_country_probe(reason, delay_ms = 120L)
    invisible(control_state)
  }

  observeEvent(input$floating_notes_country_picker, {
    next_country <- input$floating_notes_country_picker
    pending_programmatic_country <- isolate(notes_picker_programmatic_selected())

    if (!is.null(pending_programmatic_country) && identical(next_country, pending_programmatic_country)) {
      notes_picker_programmatic_selected(NULL)
      mark_notes_trace_mutation(
        "notes_picker_programmatic_selection_consumed",
        details = list(next_country = perf_scalar_or_default(next_country))
      )
      request_notes_country_probe("floating_notes_country_picker_programmatic_selection_consumed", delay_ms = 120L)
      return()
    }

    if (is.null(next_country) || !nzchar(next_country)) {
      mark_notes_trace_mutation(
        "notes_picker_blank_ignored",
        details = list(current_country = perf_scalar_or_default(current_notes_country()))
      )
      request_notes_country_probe("floating_notes_country_picker_blank_ignored", delay_ms = 120L)
      return()
    }
    if (identical(input$floating_notes_country, next_country)) return()

    updateSelectInput(
      session,
      "floating_notes_country",
      selected = next_country
    )
  }, ignoreInit = TRUE)
  
  # Show floating panel when Notes button is clicked
  observeEvent(input$edit_notes_btn, {
    sidebar_country <- notes_effective_sidebar_country()
    req(!is.null(sidebar_country), nzchar(sidebar_country))

    notes_family_transition_message(NULL)

    begin_notes_trace_action(
      "edit_notes_btn",
      details = list(
        target_country = perf_scalar_or_default(sidebar_country)
      )
    )

    previous_country <- current_notes_country()
    saved_previous_note <- FALSE
    if (!is.null(previous_country) && nzchar(previous_country)) {
      saved_previous_note <- save_note_for_country_if_changed(previous_country, input$floating_note_text %||% "")
    }

    mark_notes_trace_mutation(
      "notes_open_prepare",
      details = list(
        previous_country = perf_scalar_or_default(previous_country),
        saved_previous_note = saved_previous_note
      )
    )

    current_notes_country(sidebar_country)
    sync_notes_country_control(
      preferred_country = sidebar_country,
      reason = "edit_notes_btn",
      hidden_update_mode = "force",
      picker_update_mode = "force"
    )

    notes_panel_visible(TRUE)
    mark_notes_trace_mutation(
      "notes_panel_visible_set",
      details = list(panel_visible = isTRUE(notes_panel_visible()))
    )
    
    # Get current note for this country
    current_note <- get_note(sidebar_country, notes_data(), source_family = current_notes_source_family())
    
    # Update the text area with current note
    updateTextAreaInput(session, "floating_note_text", value = current_note)
    mark_notes_trace_mutation(
      "notes_open_text_loaded",
      details = list(
        target_country = perf_scalar_or_default(sidebar_country),
        note_chars = nchar(current_note %||% "")
      )
    )
    request_notes_country_probe("edit_notes_btn", delay_ms = 180L)
    
    # Show the floating panel using JavaScript
    session$onFlushed(function() {
      session$sendCustomMessage("showNotesPanel", list())
    }, once = TRUE)
  })

  observeEvent(input$floating_notes_close_event, {
    notes_family_transition_message(NULL)
    begin_notes_trace_action("floating_notes_close_event")

    active_country <- current_notes_country()
    saved_note <- FALSE
    if (!is.null(active_country) && nzchar(active_country)) {
      saved_note <- save_note_for_country_if_changed(active_country, input$floating_note_text %||% "")
    }
    notes_panel_visible(FALSE)
    psd_notes_jump_anchor_country(NULL)
    mark_notes_trace_mutation(
      "notes_panel_closed",
      details = list(
        active_country = perf_scalar_or_default(active_country),
        saved_note = saved_note,
        panel_visible = isTRUE(notes_panel_visible()),
        psd_notes_jump_anchor_country = perf_scalar_or_default(psd_notes_jump_anchor_country())
      )
    )
  }, ignoreInit = TRUE)
  
  observeEvent(input$floating_notes_country, {
    next_country <- input$floating_notes_country
    if (is.null(next_country) || !nzchar(next_country)) return()

    pending_programmatic_country <- isolate(notes_hidden_programmatic_selected())
    if (!is.null(pending_programmatic_country) && identical(next_country, pending_programmatic_country)) {
      notes_hidden_programmatic_selected(NULL)
      mark_notes_trace_mutation(
        "notes_hidden_programmatic_selection_consumed",
        details = list(next_country = perf_scalar_or_default(next_country))
      )
      request_notes_country_probe("floating_notes_country_programmatic_selection_consumed", delay_ms = 120L)
      return()
    }

    resolved_next_country <- resolve_notes_country_choice(
      next_country,
      notes_country_choices(),
      frequency_choices = notes_country_choices(),
      base_choices = country_display_names
    )
    effective_next_country <- if (!is.null(resolved_next_country) && nzchar(resolved_next_country)) {
      resolved_next_country
    } else {
      next_country
    }

    notes_family_transition_message(NULL)

    begin_notes_trace_action(
      "floating_notes_country",
      details = list(
        next_country = perf_scalar_or_default(next_country),
        resolved_next_country = perf_scalar_or_default(resolved_next_country),
        effective_next_country = perf_scalar_or_default(effective_next_country)
      )
    )

    previous_country <- current_notes_country()
    saved_previous_note <- FALSE
    if (!is.null(previous_country) && nzchar(previous_country) && !identical(previous_country, effective_next_country)) {
      saved_previous_note <- save_note_for_country_if_changed(previous_country, input$floating_note_text %||% "")
    }

    if (!identical(previous_country, effective_next_country)) {
      current_notes_country(effective_next_country)
      current_note <- get_note(effective_next_country, notes_data(), source_family = current_notes_source_family())
      updateTextAreaInput(session, "floating_note_text", value = current_note)
      sync_notes_country_control(preferred_country = effective_next_country, reason = "floating_notes_country")
      mark_notes_trace_mutation(
        "notes_country_changed",
        details = list(
          previous_country = perf_scalar_or_default(previous_country),
          next_country = perf_scalar_or_default(next_country),
          resolved_next_country = perf_scalar_or_default(resolved_next_country),
          effective_next_country = perf_scalar_or_default(effective_next_country),
          saved_previous_note = saved_previous_note,
          note_chars = nchar(current_note %||% "")
        )
      )
    } else {
      mark_notes_trace_mutation(
        "notes_country_unchanged",
        details = list(
          current_country = perf_scalar_or_default(next_country),
          saved_previous_note = saved_previous_note
        )
      )
    }
  }, ignoreInit = TRUE)
  
  # Display timestamp in floating panel
  output$floating_note_timestamp <- renderText({
    country_code <- current_notes_country()
    if (is.null(country_code)) return("")
    
    current_notes <- normalize_notes_df(notes_data())
    row <- current_notes[
      current_notes$country == country_code &
        current_notes$source_family == current_notes_source_family(),
      ,
      drop = FALSE
    ]
    if (nrow(row) > 0 && !is.na(row$last_updated[1]) && row$last_updated[1] != "") {
      paste("Saved:", format(as.POSIXct(row$last_updated[1]), "%b %d, %H:%M"))
    } else {
      "Not saved yet"
    }
  })
  
  # Save note from floating panel
  observeEvent(input$save_floating_note, {
    country_code <- current_notes_country()
    req(country_code, input$floating_note_text)

    notes_family_transition_message(NULL)

    begin_notes_trace_action(
      "save_floating_note",
      details = list(country_code = perf_scalar_or_default(country_code))
    )

    saved_note <- save_note_for_country_if_changed(country_code, input$floating_note_text)
    mark_notes_trace_mutation(
      "notes_saved",
      details = list(
        country_code = perf_scalar_or_default(country_code),
        saved_note = saved_note,
        note_chars = nchar(input$floating_note_text %||% "")
      )
    )
  })

  observeEvent(input$jump_notes_country_to_sidebar, {
    jump_state <- notes_sidebar_jump_state()
    if (!isTRUE(jump_state$enabled)) {
      return()
    }

    notes_family_transition_message(NULL)

    begin_notes_trace_action(
      "jump_notes_country_to_sidebar",
      details = list(
        target_country = perf_scalar_or_default(jump_state$target_country),
        current_sidebar_country = perf_scalar_or_default(notes_effective_sidebar_country())
      )
    )

    begin_psd_transition_action(
      "jump_notes_country_to_sidebar",
      details = list(
        origin_notes_action_id = isolate(notes_trace_action_id()),
        origin_notes_mutation_seq = isolate(notes_trace_mutation_seq()),
        target_country = perf_scalar_or_default(jump_state$target_country),
        current_sidebar_country = perf_scalar_or_default(notes_effective_sidebar_country())
      )
    )

    jump_targets <- notes_jump_input_targets(jump_state$target_country)
    pending_sidebar_country_before <- isolate(pending_sidebar_country_target())
    pending_sidebar_country_target(jump_state$target_country)

    seeded_psd_map_country <- FALSE
    if ("psd_map_country_choice" %in% names(jump_targets)) {
      target_map_country <- as.character(jump_targets[["psd_map_country_choice"]] %||% "")
      if (nzchar(target_map_country)) {
        psd_notes_jump_anchor_country(target_map_country)

        if (exists("pending_psd_map_country_target", mode = "function")) {
          try(pending_psd_map_country_target(target_map_country), silent = TRUE)
        }

        seeded_psd_map_country <- isTRUE(tryCatch({
          map_selected_country(target_map_country)
          TRUE
        }, error = function(e) FALSE))
      }
    }

    for (input_id in names(jump_targets)) {
      target_value <- jump_targets[[input_id]]
      updateSelectizeInput(session, input_id, selected = target_value)
      session$sendCustomMessage(
        "setSelectizeOrShinyInputValue",
        list(inputId = input_id, value = target_value)
      )
    }

    mark_psd_transition_mutation(
      event = "notes_jump_applied",
      reason = "notes_jump_apply",
      details = list(
        target_country = perf_scalar_or_default(jump_state$target_country),
        before_pending_sidebar_country = perf_scalar_or_default(pending_sidebar_country_before),
        after_pending_sidebar_country = perf_scalar_or_default(pending_sidebar_country_target()),
        psd_notes_jump_anchor_country = perf_scalar_or_default(psd_notes_jump_anchor_country()),
        seeded_psd_map_country = seeded_psd_map_country,
        dispatched_inputs = paste(names(jump_targets), collapse = "|"),
        dispatched_values = paste(vapply(jump_targets, format_perf_detail_value, character(1)), collapse = "|")
      ),
      force = TRUE
    )
    request_psd_map_country_probe("notes_jump_applied", delay_ms = 180L)

    mark_notes_trace_mutation(
      "notes_jump_applied",
      details = list(
        target_country = perf_scalar_or_default(jump_state$target_country),
        pending_sidebar_country = perf_scalar_or_default(pending_sidebar_country_target()),
        psd_notes_jump_anchor_country = perf_scalar_or_default(psd_notes_jump_anchor_country()),
        seeded_psd_map_country = seeded_psd_map_country,
        dispatched_inputs = paste(names(jump_targets), collapse = "|")
      )
    )
  }, ignoreInit = TRUE)

  observeEvent(input$pull_sidebar_country_to_notes, {
    pull_state <- notes_sidebar_pull_state()
    if (!isTRUE(pull_state$enabled)) {
      return()
    }

    notes_family_transition_message(NULL)

    begin_notes_trace_action(
      "pull_sidebar_country_to_notes",
      details = list(
        target_country = perf_scalar_or_default(pull_state$target_country),
        current_notes_country = perf_scalar_or_default(committed_notes_country())
      )
    )

    previous_country <- current_notes_country()
    saved_previous_note <- FALSE
    if (!is.null(previous_country) && nzchar(previous_country) && !identical(previous_country, pull_state$target_country)) {
      saved_previous_note <- save_note_for_country_if_changed(previous_country, input$floating_note_text %||% "")
    }

    current_notes_country(pull_state$target_country)
    current_note <- get_note(
      pull_state$target_country,
      notes_data(),
      source_family = current_notes_source_family()
    )
    updateTextAreaInput(session, "floating_note_text", value = current_note)
    sync_notes_country_control(
      preferred_country = pull_state$target_country,
      reason = "pull_sidebar_country_to_notes",
      hidden_update_mode = "force",
      picker_update_mode = "force"
    )
    mark_notes_trace_mutation(
      "notes_pull_applied",
      details = list(
        previous_country = perf_scalar_or_default(previous_country),
        target_country = perf_scalar_or_default(pull_state$target_country),
        saved_previous_note = saved_previous_note,
        note_chars = nchar(current_note %||% "")
      )
    )
  }, ignoreInit = TRUE)

  observeEvent(input$clear_floating_note, {
    showModal(modalDialog(
      title = "Clear All My Notes?",
      "This will clear all notes saved under your user account. Other users' notes will not be changed.",
      easyClose = TRUE,
      footer = tagList(
        modalButton("Cancel"),
        actionButton("confirm_clear_floating_note", "Confirm Clear", class = "btn-danger")
      )
    ))
  })

  observeEvent(input$confirm_clear_floating_note, {
    removeModal()

    empty_notes <- data.frame(
      country = character(),
      note = character(),
      last_updated = character(),
      stringsAsFactors = FALSE
    )

    # Clear current user's notes only.
    clear_saved <- tryCatch({
      save_notes(empty_notes, user_notes_path, perf_context = "notes_clear_user_notes")
      TRUE
    }, error = function(e) {
      showNotification(
        paste("Could not clear the Notes CSV on disk:", conditionMessage(e)),
        type = "error",
        duration = 10
      )
      notes_trace("notes_clear_failed", details = list(error = conditionMessage(e)), force = TRUE)
      FALSE
    })
    if (!isTRUE(clear_saved)) {
      return()
    }
    notes_data(empty_notes)
    replace_current_user_notes_in_all_notes(empty_notes, reason = "clear_current_user_notes")

    # Clear in-panel text immediately for the active country context.
    updateTextAreaInput(session, "floating_note_text", value = "")
  })

  current_corrections_source_choice <- function() {
    current_source_choice_safe()
  }

  current_corrections_trade_flow <- function() {
    source_choice <- current_corrections_source_choice()
    if (identical(source_choice, "hybrid")) return(hybrid_trade_flow_choice())
    if (identical(source_choice, "census")) return(effective_trade_flow_for_source(source_choice, input$census_trade_flow_choice))
    if (identical(source_choice, "vp_trade")) return(effective_trade_flow_for_source(source_choice, input$census_trade_flow_choice, input$vp_trade_flow_choice))
    "export"
  }

  normalize_census_correction_edit_target_id <- function(value = census_correction_edit_target_id()) {
    normalized_value <- suppressWarnings(as.integer(value))
    if (length(normalized_value) != 1 || is.na(normalized_value)) return(NULL)
    normalized_value
  }

  has_census_correction_edit_target <- function(value = census_correction_edit_target_id()) {
    !is.null(normalize_census_correction_edit_target_id(value))
  }

  build_census_corrections_section_header <- function(title, expanded, link_id) {
    caret_symbol <- if (isTRUE(expanded)) "▼" else "▶"
    toggle_label <- if (isTRUE(expanded)) "Hide" else "Show"

    div(
      style = "margin: 0 0 8px 0;",
      actionLink(
        inputId = link_id,
        label = HTML(sprintf(
          "<span>%s</span><span style='font-size: 12px; font-weight: 400; color: #6c757d;'>%s %s</span>",
          htmltools::htmlEscape(title),
          caret_symbol,
          toggle_label
        )),
        style = paste(
          "display: flex; justify-content: space-between; align-items: baseline;",
          "width: 100%; padding: 0; border: 0; background: transparent;",
          "color: #333; text-decoration: none; font-size: 18px; font-weight: 500;",
          "line-height: 1.1;"
        )
      )
    )
  }

  current_corrections_dataset <- reactive({
    source_choice <- current_corrections_source_choice()
    trade_flow <- current_corrections_trade_flow()

    if (identical(source_choice, "hybrid")) {
      if (identical(trade_flow, "import")) return(rice_data_hybrid_import_monthly)
      return(rice_data_hybrid_monthly)
    }

    if (identical(source_choice, "census")) {
      if (identical(trade_flow, "import")) return(rice_data_census_imports_monthly)
      return(rice_data_census_monthly)
    }

    tibble()
  })

  visible_census_corrections_audit <- reactive({
    audit_df <- census_corrections_audit_data()
    if (is.null(audit_df) || nrow(audit_df) == 0) return(empty_census_corrections_audit())

    source_choice <- current_corrections_source_choice()
    visible_flow <- if (identical(source_choice, "hybrid")) {
      "export"
    } else if (identical(source_choice, "census")) {
      current_corrections_trade_flow()
    } else {
      NA_character_
    }

    if (is.na(visible_flow)) return(empty_census_corrections_audit())

    audit_df %>%
      filter(.data$trade_flow == visible_flow) %>%
      arrange(desc(.data$applied_at), .data$country, .data$hs_code)
  })

  census_correction_reference_map <- reactive({
    trade_flow <- current_corrections_trade_flow()
    load_correction_map_reference() %>%
      transmute(
        trade_flow = normalize_trade_flow(.data[["Trade Flow"]]),
        hs_code = trimws(as.character(.data[["HS code"]])),
        hs_display_label = dplyr::coalesce(
          na_if(trimws(as.character(.data[["HS Display Label"]])), ""),
          na_if(trimws(as.character(.data[["RiceType Display Label"]])), ""),
          na_if(trimws(as.character(.data$RiceType)), ""),
          trimws(as.character(.data[["HS code"]]))
        ),
        rice_type = trimws(as.character(.data$RiceType)),
        rice_type_display = dplyr::coalesce(
          na_if(trimws(as.character(.data[["RiceType Display Label"]])), ""),
          na_if(trimws(as.character(.data$RiceType)), ""),
          trimws(as.character(.data[["HS code"]]))
        ),
        correction_ui_active = .data$Correction_UI_Active,
        display_group = trimws(as.character(.data[["Display Group"]])),
        display_order = dplyr::coalesce(suppressWarnings(as.integer(.data[["Display Order"]])), 9999L),
        equivalent_default = trimws(as.character(.data[["Equivalent Default"]])),
        unit_default = trimws(as.character(.data[["Unit Default"]]))
      ) %>%
      filter(.data$trade_flow == trade_flow, .data$correction_ui_active %in% TRUE, nzchar(.data$hs_code)) %>%
      arrange(.data$display_group, .data$display_order, .data$hs_display_label, .data$hs_code)
  })

  census_correction_trade_flow <- reactive({
    current_corrections_trade_flow()
  })

  census_correction_country_choices <- reactive({
    source_df <- current_corrections_dataset()
    if (is.null(source_df) || nrow(source_df) == 0) return(setNames(character(0), character(0)))

    choices_df <- source_df %>%
      select(country, countryDescription) %>%
      mutate(
        country = trimws(as.character(.data$country)),
        countryDescription = trimws(as.character(.data$countryDescription))
      ) %>%
      filter(.data$country != "GRAND_TOTAL", nzchar(.data$countryDescription)) %>%
      distinct() %>%
      arrange(.data$countryDescription, .data$country)

    setNames(choices_df$countryDescription, choices_df$countryDescription)
  })

  census_correction_hs_choices <- reactive({
    reference_map <- census_correction_reference_map()
    if (nrow(reference_map) == 0) return(setNames(character(0), character(0)))

    labels <- ifelse(
      nzchar(reference_map$hs_display_label),
      paste0(reference_map$hs_code, " - ", reference_map$hs_display_label),
      reference_map$hs_code
    )
    setNames(reference_map$hs_code, labels)
  })

  census_correction_selected_hs_record <- reactive({
    selected_hs <- if (!is.null(input$census_correction_hs_code_select)) trimws(as.character(input$census_correction_hs_code_select)) else ""
    reference_map <- census_correction_reference_map()
    if (!nzchar(selected_hs) || nrow(reference_map) == 0) return(NULL)
    selected_row <- reference_map %>% filter(.data$hs_code == selected_hs)
    if (nrow(selected_row) == 0) return(NULL)
    selected_row[1, , drop = FALSE]
  })

  census_correction_preview_record <- reactive({
    hs_record <- census_correction_selected_hs_record()
    if (is.null(hs_record)) return(NULL)

    correction_id <- normalize_census_correction_edit_target_id()
    current_registry <- census_corrections_registry_data()
    existing_row <- if (has_census_correction_edit_target(correction_id)) {
      current_registry %>% filter(.data[["Correction ID"]] == correction_id)
    } else {
      empty_census_corrections_registry()[0, ]
    }

    data.frame(
      `Correction ID` = if (has_census_correction_edit_target(correction_id)) correction_id else NA_integer_,
      Active = TRUE,
      `Trade Flow` = census_correction_trade_flow(),
      `Month start` = suppressWarnings(as.integer(input$census_correction_start_month)),
      `Year start` = suppressWarnings(as.integer(input$census_correction_start_year)),
      `Month end` = suppressWarnings(as.integer(input$census_correction_end_month)),
      `Year end` = suppressWarnings(as.integer(input$census_correction_end_year)),
      Country = if (!is.null(input$census_correction_country_select)) trimws(as.character(input$census_correction_country_select)) else "",
      RiceType = hs_record$rice_type[[1]],
      `HS code` = hs_record$hs_code[[1]],
      Volume = suppressWarnings(as.numeric(input$census_correction_volume)),
      Unit = if (!is.null(input$census_correction_unit)) trimws(as.character(input$census_correction_unit)) else "mt",
      Equivalent = if (!is.null(input$census_correction_equivalent)) trimws(as.character(input$census_correction_equivalent)) else "unadjusted",
      Reason = if (!is.null(input$census_correction_reason)) trimws(as.character(input$census_correction_reason)) else "",
      `Created At` = if (nrow(existing_row) > 0) existing_row[["Created At"]][1] else "",
      `Created By` = if (nrow(existing_row) > 0) existing_row[["Created By"]][1] else "",
      `Updated At` = if (nrow(existing_row) > 0) existing_row[["Updated At"]][1] else "",
      `Updated By` = if (nrow(existing_row) > 0) existing_row[["Updated By"]][1] else "",
      `Archived At` = if (nrow(existing_row) > 0) existing_row[["Archived At"]][1] else "",
      `Archived By` = if (nrow(existing_row) > 0) existing_row[["Archived By"]][1] else "",
      `Archive Reason` = if (nrow(existing_row) > 0) existing_row[["Archive Reason"]][1] else "",
      check.names = FALSE,
      stringsAsFactors = FALSE
    )
  })

  census_correction_validation_errors <- reactive({
    errors <- character(0)
    source_choice <- current_corrections_source_choice()
    if (!(source_choice %in% c("census", "hybrid"))) {
      errors <- c(errors, "Corrections can only be managed from the Census or Hybrid data source views.")
    }

    country_value <- if (!is.null(input$census_correction_country_select)) trimws(as.character(input$census_correction_country_select)) else ""
    if (!nzchar(country_value)) {
      errors <- c(errors, "Select a country for the correction.")
    } else if (tolower(country_value) %in% c("world", "grand_total")) {
      errors <- c(errors, "World / GRAND_TOTAL corrections are not authorable in the phase-1 workspace.")
    }

    hs_record <- census_correction_selected_hs_record()
    if (is.null(hs_record)) {
      errors <- c(errors, "Select an HS code that is active in Correction_Map for the current trade flow.")
    }

    start_month <- suppressWarnings(as.integer(input$census_correction_start_month))
    end_month <- suppressWarnings(as.integer(input$census_correction_end_month))
    start_year <- suppressWarnings(as.integer(input$census_correction_start_year))
    end_year <- suppressWarnings(as.integer(input$census_correction_end_year))
    if (is.na(start_month) || start_month < 1 || start_month > 12) errors <- c(errors, "Start month must be between 1 and 12.")
    if (is.na(end_month) || end_month < 1 || end_month > 12) errors <- c(errors, "End month must be between 1 and 12.")
    if (is.na(start_year)) errors <- c(errors, "Start year is required.")
    if (is.na(end_year)) errors <- c(errors, "End year is required.")
    if (!is.na(start_month) && !is.na(end_month) && !is.na(start_year) && !is.na(end_year)) {
      if ((end_year * 100L + end_month) < (start_year * 100L + start_month)) {
        errors <- c(errors, "End month/year must be the same as or later than the start month/year.")
      }
    }

    volume_value <- suppressWarnings(as.numeric(input$census_correction_volume))
    if (is.na(volume_value)) {
      errors <- c(errors, "Volume is required.")
    } else if (identical(volume_value, 0)) {
      errors <- c(errors, "Volume cannot be zero.")
    }

    unit_value <- if (!is.null(input$census_correction_unit)) trimws(as.character(input$census_correction_unit)) else ""
    if (!(unit_value %in% c("mt", "kg", "lbs", "cwt", "us_tons"))) {
      errors <- c(errors, "Unit must be one of the supported correction units.")
    }

    equivalent_value <- if (!is.null(input$census_correction_equivalent)) trimws(as.character(input$census_correction_equivalent)) else ""
    if (!(equivalent_value %in% c("unadjusted", "rough_eq"))) {
      errors <- c(errors, "Equivalent must be Unadjusted or Rough-equivalent.")
    }

    unique(errors)
  })

  active_census_corrections_table_data <- reactive({
    trade_flow <- census_correction_trade_flow()
    census_corrections_registry_data() %>%
      filter(.data$Active %in% TRUE, normalize_trade_flow(.data[["Trade Flow"]]) == trade_flow) %>%
      arrange(desc(.data[["Updated At"]]), desc(.data[["Created At"]]), .data$Country, .data[["HS code"]])
  })

  archived_census_corrections_table_data <- reactive({
    trade_flow <- census_correction_trade_flow()
    census_corrections_registry_data() %>%
      filter(!(.data$Active %in% TRUE), normalize_trade_flow(.data[["Trade Flow"]]) == trade_flow) %>%
      arrange(desc(.data[["Archived At"]]), .data$Country, .data[["HS code"]])
  })

  selected_active_correction_ids <- reactive({
    selected_rows <- input$active_census_corrections_table_rows_selected
    table_df <- active_census_corrections_table_data()
    if (is.null(selected_rows) || length(selected_rows) == 0 || nrow(table_df) == 0) return(integer(0))
    suppressWarnings(as.integer(table_df[["Correction ID"]][selected_rows]))
  })

  selected_archived_correction_ids <- reactive({
    selected_rows <- input$archived_census_corrections_table_rows_selected
    table_df <- archived_census_corrections_table_data()
    if (is.null(selected_rows) || length(selected_rows) == 0 || nrow(table_df) == 0) return(integer(0))
    suppressWarnings(as.integer(table_df[["Correction ID"]][selected_rows]))
  })

  reset_census_correction_form_inputs <- function(selected_country = NULL, selected_hs = NULL, selected_unit = "mt", selected_equivalent = "unadjusted") {
    country_choices <- census_correction_country_choices()
    hs_choices <- census_correction_hs_choices()

    if (is.null(selected_country) || !(selected_country %in% unname(country_choices))) {
      selected_country <- if (length(country_choices) > 0) unname(country_choices)[1] else character(0)
    }

    if (is.null(selected_hs) || !(selected_hs %in% unname(hs_choices))) {
      selected_hs <- if (length(hs_choices) > 0) unname(hs_choices)[1] else character(0)
    }

    updateSelectInput(session, "census_correction_country_select", choices = country_choices, selected = selected_country)
    updateSelectInput(session, "census_correction_hs_code_select", choices = hs_choices, selected = selected_hs)
    updateNumericInput(session, "census_correction_start_month", value = 1)
    updateNumericInput(session, "census_correction_start_year", value = as.integer(format(Sys.Date(), "%Y")))
    updateNumericInput(session, "census_correction_end_month", value = 1)
    updateNumericInput(session, "census_correction_end_year", value = as.integer(format(Sys.Date(), "%Y")))
    updateNumericInput(session, "census_correction_volume", value = NA_real_)
    updateSelectInput(session, "census_correction_unit", selected = selected_unit)
    updateSelectInput(session, "census_correction_equivalent", selected = selected_equivalent)
    updateTextAreaInput(session, "census_correction_reason", value = "")
  }

  observeEvent(input$main_tabs_panel, {
    if (!identical(input$main_tabs_panel, "Census Corrections")) return()
    census_corrections_registry_data(load_census_corrections_registry(census_corrections_input_path))
  }, ignoreInit = TRUE)

  observe({
    country_choices <- census_correction_country_choices()
    current_selected <- if (!is.null(input$census_correction_country_select)) input$census_correction_country_select else NULL
    if (has_census_correction_edit_target()) return()

    selected_country <- if (!is.null(current_selected) && current_selected %in% unname(country_choices)) {
      current_selected
    } else if (length(country_choices) > 0) {
      unname(country_choices)[1]
    } else {
      character(0)
    }

    updateSelectInput(session, "census_correction_country_select", choices = country_choices, selected = selected_country)
  })

  observe({
    hs_choices <- census_correction_hs_choices()
    current_selected <- if (!is.null(input$census_correction_hs_code_select)) input$census_correction_hs_code_select else NULL
    if (has_census_correction_edit_target()) return()

    selected_hs <- if (!is.null(current_selected) && current_selected %in% unname(hs_choices)) {
      current_selected
    } else if (length(hs_choices) > 0) {
      unname(hs_choices)[1]
    } else {
      character(0)
    }

    updateSelectInput(session, "census_correction_hs_code_select", choices = hs_choices, selected = selected_hs)
  })

  observeEvent(census_correction_selected_hs_record(), {
    if (has_census_correction_edit_target()) return()
    hs_record <- census_correction_selected_hs_record()
    if (is.null(hs_record)) return()

    default_unit <- trimws(as.character(hs_record$unit_default[[1]]))
    default_equivalent <- trimws(as.character(hs_record$equivalent_default[[1]]))

    if (default_unit %in% c("mt", "kg", "lbs", "cwt", "us_tons")) {
      updateSelectInput(session, "census_correction_unit", selected = default_unit)
    }
    if (default_equivalent %in% c("unadjusted", "rough_eq")) {
      updateSelectInput(session, "census_correction_equivalent", selected = default_equivalent)
    }
  }, ignoreInit = TRUE)

  observeEvent(active_census_corrections_table_data(), {
    edit_target_id <- normalize_census_correction_edit_target_id()
    if (is.null(edit_target_id)) return()
    if (!(edit_target_id %in% active_census_corrections_table_data()[["Correction ID"]])) {
      census_correction_edit_target_id(NULL)
    }
  })

  output$census_correction_form_context_ui <- renderUI({
    hs_record <- census_correction_selected_hs_record()
    source_choice <- current_corrections_source_choice()
    trade_flow_label <- stringr::str_to_title(census_correction_trade_flow())
    source_note <- if (identical(source_choice, "hybrid")) {
      paste0("Hybrid/Aggregate corrections follow the active ", trade_flow_label, " flow and write back to the shared corrections registry.")
    } else {
      "Corrections follow the currently selected Census trade flow view."
    }

    tagList(
      div(strong("Trade Flow: "), trade_flow_label),
      div(strong(paste0("Derived ", COMMODITY_TYPE_LABEL, ": ")), if (!is.null(hs_record)) hs_record$rice_type_display[[1]] else "Select an HS code"),
      div(style = "margin-top: 6px; color: #6c757d;", source_note)
    )
  })

  output$census_correction_validation_errors_ui <- renderUI({
    errors <- census_correction_validation_errors()
    if (length(errors) == 0) return(NULL)

    div(
      style = "margin-top: 10px; padding: 10px; background-color: #f8d7da; border: 1px solid #f1aeb5; border-radius: 4px; color: #842029;",
      tags$strong("Validation issues:"),
      tags$ul(lapply(errors, tags$li), style = "margin-bottom: 0; padding-left: 20px;")
    )
  })

  output$census_correction_preview_ui <- renderUI({
    preview_row <- census_correction_preview_record()
    if (is.null(preview_row) || nrow(preview_row) == 0) return(NULL)

    preview_items <- list(
      paste0("Country: ", preview_row$Country[[1]]),
      paste0(COMMODITY_TYPE_LABEL, ": ", preview_row$RiceType[[1]]),
      paste0("HS Code: ", preview_row[["HS code"]][[1]]),
      paste0("Window: ", sprintf("%04d-%02d to %04d-%02d", preview_row[["Year start"]][[1]], preview_row[["Month start"]][[1]], preview_row[["Year end"]][[1]], preview_row[["Month end"]][[1]])),
      paste0("Volume: ", preview_row$Volume[[1]], " ", preview_row$Unit[[1]], " (", preview_row$Equivalent[[1]], ")")
    )

    div(
      style = "margin-top: 10px; padding: 10px; background-color: #f8f9fa; border: 1px solid #d9dee3; border-radius: 4px;",
      tags$strong("Preview record:"),
      tags$ul(lapply(preview_items, tags$li), style = "margin-bottom: 0; padding-left: 20px;")
    )
  })

  output$census_corrections_status_ui <- renderUI({
    source_choice <- current_corrections_source_choice()
    if (!(source_choice %in% c("census", "hybrid"))) return(NULL)

    visible_audit <- visible_census_corrections_audit()
    active_count <- nrow(active_census_corrections_table_data())
    archived_count <- nrow(archived_census_corrections_table_data())
    current_flow_label <- if (identical(source_choice, "hybrid")) {
      if (identical(census_correction_trade_flow(), "import")) {
        "Hybrid/Aggregate import corrections shown for the active Hybrid import view."
      } else {
        "Hybrid/Aggregate export corrections shown for the active Hybrid export view."
      }
    } else if (identical(census_correction_trade_flow(), "import")) {
      "Import corrections shown for the active Census import view."
    } else {
      "Export corrections shown for the active Census export view."
    }

    div(
      style = "margin-bottom: 12px;",
      div(
        style = "padding: 10px; background-color: #fff3cd; border: 1px solid #ffeeba; border-radius: 4px; color: #856404;",
        strong("Rebuild Required: "),
        "Editing corrections updates the registry only. Rerun Master.R and relaunch the app to rebuild Census and Hybrid artifacts.",
        br(),
        span(style = "display: block; margin-top: 6px;", current_flow_label),
        span(style = "display: block; margin-top: 4px;", paste0(format(active_count, big.mark = ","), " active row(s), ", format(archived_count, big.mark = ","), " archived row(s) for this flow.")),
        span(style = "display: block; margin-top: 4px;", paste0(format(nrow(visible_audit), big.mark = ","), " applied audit row(s) currently loaded for this view."))
      )
    )
  })

  output$census_corrections_audit_section_header_ui <- renderUI({
    build_census_corrections_section_header(
      title = "Applied Corrections Audit",
      expanded = show_census_corrections_audit_section(),
      link_id = "toggle_census_corrections_audit_section"
    )
  })

  output$archived_census_corrections_section_header_ui <- renderUI({
    build_census_corrections_section_header(
      title = "Archived Corrections",
      expanded = show_archived_census_corrections_section(),
      link_id = "toggle_archived_census_corrections_section"
    )
  })

  output$census_corrections_audit_section_body_ui <- renderUI({
    if (!isTRUE(show_census_corrections_audit_section())) return(NULL)
    dataTableOutput("census_corrections_table")
  })

  output$archived_census_corrections_section_body_ui <- renderUI({
    if (!isTRUE(show_archived_census_corrections_section())) return(NULL)

    tagList(
      div(
        style = "margin-bottom: 8px; display: flex; gap: 8px; flex-wrap: wrap;",
        actionButton("restore_archived_corrections_btn", "Restore Selected Archived", class = "btn-default")
      ),
      dataTableOutput("archived_census_corrections_table")
    )
  })

  output$active_census_corrections_table <- renderDT({
    table_df <- active_census_corrections_table_data()
    display_df <- table_df %>%
      transmute(
        `Correction ID` = .data[["Correction ID"]],
        Country = .data$Country,
        Type = .data$RiceType,
        `HS Code` = .data[["HS code"]],
        `Date Window` = sprintf("%04d-%02d to %04d-%02d", .data[["Year start"]], .data[["Month start"]], .data[["Year end"]], .data[["Month end"]]),
        Volume = .data$Volume,
        Unit = .data$Unit,
        Equivalent = .data$Equivalent,
        Reason = .data$Reason,
        `Updated At` = .data[["Updated At"]]
      )

    datatable(
      display_df,
      selection = list(mode = "multiple", target = "row"),
      options = list(pageLength = 8, searching = TRUE, ordering = TRUE),
      rownames = FALSE
    ) %>% formatRound("Volume", digits = 1, mark = ",")
  })

  output$archived_census_corrections_table <- renderDT({
    table_df <- archived_census_corrections_table_data()
    display_df <- table_df %>%
      transmute(
        `Correction ID` = .data[["Correction ID"]],
        Country = .data$Country,
        Type = .data$RiceType,
        `HS Code` = .data[["HS code"]],
        `Date Window` = sprintf("%04d-%02d to %04d-%02d", .data[["Year start"]], .data[["Month start"]], .data[["Year end"]], .data[["Month end"]]),
        Volume = .data$Volume,
        Unit = .data$Unit,
        Equivalent = .data$Equivalent,
        `Archive Reason` = .data[["Archive Reason"]],
        `Archived At` = .data[["Archived At"]]
      )

    datatable(
      display_df,
      selection = list(mode = "multiple", target = "row"),
      options = list(pageLength = 8, searching = TRUE, ordering = TRUE),
      rownames = FALSE
    ) %>% formatRound("Volume", digits = 1, mark = ",")
  })

  observeEvent(input$toggle_census_corrections_audit_section, {
    show_census_corrections_audit_section(!isTRUE(show_census_corrections_audit_section()))
  })

  observeEvent(input$toggle_archived_census_corrections_section, {
    show_archived_census_corrections_section(!isTRUE(show_archived_census_corrections_section()))
  })

  output$census_corrections_table <- renderDT({
    visible_audit <- visible_census_corrections_audit()
    if (nrow(visible_audit) == 0) {
      empty_table <- data.frame(
        `Applied At` = character(),
        `Trade Flow` = character(),
        `Country` = character(),
        Type = character(),
        `HS Code` = character(),
        `Input Volume` = numeric(),
        `Unit` = character(),
        `Basis` = character(),
        `Monthly Delta (MT, Unadjusted)` = numeric(),
        `Monthly Rough Eq Delta (KG)` = numeric(),
        `Affected Months` = character(),
        `Matched Rows` = integer(),
        `Total Rough Eq Delta (KG)` = numeric(),
        check.names = FALSE
      )

      return(datatable(empty_table, options = list(dom = "t"), rownames = FALSE))
    }

    table_df <- visible_audit %>%
      transmute(
        `Applied At` = .data$applied_at,
        `Trade Flow` = stringr::str_to_title(.data$trade_flow),
        `Country` = .data$country,
        Type = .data$rice_type,
        `HS Code` = .data$hs_code,
        `Input Volume` = .data$input_volume,
        `Unit` = .data$input_unit,
        `Basis` = .data$input_equivalent,
        `Monthly Delta (MT, Unadjusted)` = .data$normalized_unadjusted_mt_delta,
        `Monthly Rough Eq Delta (KG)` = .data$normalized_rough_eq_delta,
        `Affected Months` = .data$affected_month_span,
        `Matched Rows` = .data$matched_row_count,
        `Total Rough Eq Delta (KG)` = .data$total_rough_eq_delta_applied
      )

    datatable(
      table_df,
      options = list(pageLength = 10, searching = TRUE, ordering = TRUE),
      rownames = FALSE
    ) %>%
      formatRound(
        c("Input Volume", "Monthly Delta (MT, Unadjusted)", "Monthly Rough Eq Delta (KG)", "Total Rough Eq Delta (KG)"),
        digits = 1,
        mark = ","
      )
  })

  observeEvent(input$new_census_correction_btn, {
    census_correction_edit_target_id(NULL)
    reset_census_correction_form_inputs()
  })

  observeEvent(input$edit_active_census_correction_btn, {
    start_time <- Sys.time()
    selected_ids <- selected_active_correction_ids()
    if (length(selected_ids) != 1) {
      log_perf(
        "observeEvent(edit_active_census_correction_btn)",
        start_time,
        details = list(
          status = "invalid_selection",
          selected_count = length(selected_ids)
        )
      )

      showNotification("Select exactly one active correction row to edit.", type = "warning")
      return()
    }

    edit_row <- active_census_corrections_table_data() %>% filter(.data[["Correction ID"]] == selected_ids[[1]])
    if (nrow(edit_row) == 0) {
      log_perf(
        "observeEvent(edit_active_census_correction_btn)",
        start_time,
        details = list(
          status = "missing_row",
          selected_count = length(selected_ids),
          correction_id = selected_ids[[1]]
        )
      )

      return()
    }

    census_correction_edit_target_id(selected_ids[[1]])
    updateSelectInput(session, "census_correction_country_select", choices = census_correction_country_choices(), selected = edit_row$Country[[1]])
    updateSelectInput(session, "census_correction_hs_code_select", choices = census_correction_hs_choices(), selected = edit_row[["HS code"]][[1]])
    updateNumericInput(session, "census_correction_start_month", value = edit_row[["Month start"]][[1]])
    updateNumericInput(session, "census_correction_start_year", value = edit_row[["Year start"]][[1]])
    updateNumericInput(session, "census_correction_end_month", value = edit_row[["Month end"]][[1]])
    updateNumericInput(session, "census_correction_end_year", value = edit_row[["Year end"]][[1]])
    updateNumericInput(session, "census_correction_volume", value = edit_row$Volume[[1]])
    updateSelectInput(session, "census_correction_unit", selected = edit_row$Unit[[1]])
    updateSelectInput(session, "census_correction_equivalent", selected = edit_row$Equivalent[[1]])
    updateTextAreaInput(session, "census_correction_reason", value = edit_row$Reason[[1]])

    log_perf(
      "observeEvent(edit_active_census_correction_btn)",
      start_time,
      details = list(
        status = "loaded",
        selected_count = length(selected_ids),
        correction_id = selected_ids[[1]],
        country = perf_scalar_or_default(edit_row$Country[[1]]),
        hs_code = perf_scalar_or_default(edit_row[["HS code"]][[1]])
      )
    )
  })

  observeEvent(input$save_census_correction_btn, {
    start_time <- Sys.time()
    validation_errors <- census_correction_validation_errors()
    if (length(validation_errors) > 0) {
      log_perf(
        "observeEvent(save_census_correction_btn)",
        start_time,
        details = list(
          status = "validation_error",
          validation_error_count = length(validation_errors),
          edit_target = perf_scalar_or_default(census_correction_edit_target_id())
        )
      )

      showNotification(validation_errors[[1]], type = "error", duration = 8)
      return()
    }

    preview_start_time <- Sys.time()
    preview_row <- census_correction_preview_record()
    if (is.null(preview_row) || nrow(preview_row) == 0) {
      log_perf(
        "observeEvent(save_census_correction_btn)",
        start_time,
        details = list(
          status = "empty_preview",
          preview_seconds = round(as.numeric(difftime(Sys.time(), preview_start_time, units = "secs")), 4),
          edit_target = perf_scalar_or_default(census_correction_edit_target_id())
        )
      )

      showNotification("Correction preview could not be created.", type = "error")
      return()
    }

    registry_rows_before <- nrow(census_corrections_registry_data())
    write_start_time <- Sys.time()
    updated_registry <- upsert_census_correction_record(census_corrections_registry_data(), preview_row[1, , drop = FALSE], editor = user_id)
    write_census_corrections_registry(updated_registry, census_corrections_input_path)
    write_seconds <- round(as.numeric(difftime(Sys.time(), write_start_time, units = "secs")), 4)
    census_corrections_registry_data(updated_registry)
    census_correction_form_submit_nonce(census_correction_form_submit_nonce() + 1L)
    census_correction_edit_target_id(NULL)
    reset_census_correction_form_inputs()

    log_perf(
      "observeEvent(save_census_correction_btn)",
      start_time,
      details = list(
        status = "saved",
        correction_id = perf_scalar_or_default(preview_row[["Correction ID"]]),
        preview_rows = nrow(preview_row),
        preview_seconds = round(as.numeric(difftime(write_start_time, preview_start_time, units = "secs")), 4),
        write_seconds = write_seconds,
        registry_rows_before = registry_rows_before,
        registry_rows_after = nrow(updated_registry)
      )
    )

    showNotification("Correction registry updated. Rerun Master.R and relaunch the app to rebuild corrected artifacts.", type = "message", duration = 8)
  })

  observeEvent(input$archive_active_corrections_btn, {
    start_time <- Sys.time()
    selected_ids <- selected_active_correction_ids()
    if (length(selected_ids) == 0) {
      log_perf(
        "observeEvent(archive_active_corrections_btn)",
        start_time,
        details = list(
          status = "invalid_selection",
          selected_count = 0
        )
      )

      showNotification("Select one or more active correction rows to archive.", type = "warning")
      return()
    }

    registry_rows_before <- nrow(census_corrections_registry_data())
    write_start_time <- Sys.time()
    cleared_edit_target <- has_census_correction_edit_target() && normalize_census_correction_edit_target_id() %in% selected_ids
    updated_registry <- archive_census_correction_records(
      census_corrections_registry_data(),
      selected_ids,
      editor = user_id,
      archive_reason = "Archived from Census Corrections workspace"
    )
    write_census_corrections_registry(updated_registry, census_corrections_input_path)
    write_seconds <- round(as.numeric(difftime(Sys.time(), write_start_time, units = "secs")), 4)
    census_corrections_registry_data(updated_registry)
    if (cleared_edit_target) {
      census_correction_edit_target_id(NULL)
    }

    log_perf(
      "observeEvent(archive_active_corrections_btn)",
      start_time,
      details = list(
        status = "archived",
        selected_count = length(selected_ids),
        write_seconds = write_seconds,
        registry_rows_before = registry_rows_before,
        registry_rows_after = nrow(updated_registry),
        cleared_edit_target = cleared_edit_target
      )
    )

    showNotification("Selected correction rows were archived. Rerun Master.R and relaunch the app after any desired edits.", type = "warning", duration = 8)
  })

  observeEvent(input$restore_archived_corrections_btn, {
    start_time <- Sys.time()
    selected_ids <- selected_archived_correction_ids()
    if (length(selected_ids) == 0) {
      log_perf(
        "observeEvent(restore_archived_corrections_btn)",
        start_time,
        details = list(
          status = "invalid_selection",
          selected_count = 0
        )
      )

      showNotification("Select one or more archived correction rows to restore.", type = "warning")
      return()
    }

    registry_rows_before <- nrow(census_corrections_registry_data())
    write_start_time <- Sys.time()
    updated_registry <- restore_census_correction_records(census_corrections_registry_data(), selected_ids, editor = user_id)
    write_census_corrections_registry(updated_registry, census_corrections_input_path)
    write_seconds <- round(as.numeric(difftime(Sys.time(), write_start_time, units = "secs")), 4)
    census_corrections_registry_data(updated_registry)

    log_perf(
      "observeEvent(restore_archived_corrections_btn)",
      start_time,
      details = list(
        status = "restored",
        selected_count = length(selected_ids),
        write_seconds = write_seconds,
        registry_rows_before = registry_rows_before,
        registry_rows_after = nrow(updated_registry)
      )
    )

    showNotification("Selected correction rows were restored. Rerun Master.R and relaunch the app to rebuild corrected artifacts.", type = "message", duration = 8)
  })
  
  # ============================================================================
  # UNIT/BASIS CONVERSION HELPER FUNCTIONS
  # ============================================================================
  # These functions handle the conversion of export quantity data from the source
  # unit (Metric Tons) to the user's selected unit of measurement. The source data
  # from FAS Export Sales Reports is always provided in Metric Tons.
  #
  # Conversion Reference:
  #   - 1 Metric Ton (MT) = 1,000 kilograms = 2,204.62 pounds
  #   - 1,000 kilograms = 1 Metric Ton (MT)
  #   - 1 US Ton (short ton) = 2,000 pounds, so 1 MT = 1.10231 US tons
  #   - 1 Hundredweight (CWT) = 100 pounds, so 1 MT = 22.0462 CWT
  #   - Million pounds is simply pounds divided by 1,000,000
  # ============================================================================

  basis_choices_all <- contract_census_basis_choices(startup_commodity_contract)

  census_default_basis_choice <- function() {
    contract_census_default_basis(startup_commodity_contract)
  }

  census_inshell_shell_out_factor <- function() {
    contract_census_inshell_shell_out_factor(startup_commodity_contract)
  }

  default_basis_for_commodity <- function(commodity_name, source_choice = current_source_choice_safe()) {
    if (identical(source_choice, "psd")) {
      return(psd_default_basis_choice())
    }

    if (identical(source_choice, "wasde")) {
      return("rough_eq")
    }

    if (identical(source_choice, "nass")) {
      return("inshell_eq")
    }

    census_default_basis_choice()
  }

  psd_basis_profile_choice <- function(default = "milled_basis") {
    profile <- tryCatch(startup_psd_basis_profile(default = default), error = function(...) default)
    profile <- trimws(as.character(profile %||% default))
    profile <- profile[!is.na(profile) & nzchar(profile)]
    if (length(profile) == 0L) default else profile[[1L]]
  }

  psd_basis_choices_for_profile <- function(profile = psd_basis_profile_choice()) {
    if (identical(profile, "shelled_basis")) {
      return(c(
        "Shelled Equivalent" = "shelled_basis",
        "In-Shell Equivalent" = "inshell_eq"
      ))
    }

    c(
      "Milled-equivalent" = "milled_eq",
      "Rough-equivalent" = "rough_eq"
    )
  }

  psd_default_basis_choice <- function(profile = psd_basis_profile_choice()) {
    if (identical(profile, "shelled_basis")) "inshell_eq" else "milled_eq"
  }

  product_weight_hybrid_export_leaf_commodities <- c(
    "Rough Rice, MSG",
    "Rough Rice, Long Grain",
    "Milled, MSG",
    "Milled, Long Grain",
    "Medium/Short Grain (MSG)",
    "Long Grain"
  )

  product_weight_hybrid_import_leaf_commodities <- c(
    "Medium/Short Grain (MSG)",
    "Long Grain"
  )

  product_basis_explicit_registry_for_scope <- function(source_scope) {
    scope <- normalize_product_basis_scope(source_scope)

    if (identical(scope, "hybrid_export")) {
      return(normalize_product_basis_registry(data.frame(
        source_scope = scope,
        commodity = c(
          "All Rice",
          "Rough Rice",
          "Milled Rice",
          "Rough Rice, MSG",
          "Rough Rice, Long Grain",
          "Milled, MSG",
          "Milled, Long Grain",
          "Medium/Short Grain (MSG)",
          "Long Grain"
        ),
        product_basis_code = c("mixed", "rough", "milled", "rough", "rough", "milled", "milled", "mixed", "mixed"),
        basis_source = "hybrid_formula_metadata",
        derived_flag = c(TRUE, FALSE, TRUE, FALSE, TRUE, FALSE, TRUE, TRUE, TRUE),
        basis_note = c(
          "Hybrid All Rice comes from Census all-rice product-weight quantities and can combine product bases.",
          "Hybrid Rough Rice comes from Census rough-rice product-weight quantities.",
          "Hybrid Milled Rice is derived as All Rice minus Rough Rice on product-weight quantities.",
          "Hybrid Rough Rice, MSG comes from Export Sales rough-rice product-weight quantities.",
          "Hybrid Rough Rice, Long Grain is derived as rough-rice product-weight quantities minus rough MSG.",
          "Hybrid Milled, MSG comes from Census milled-rice product-weight quantities.",
          "Hybrid Milled, Long Grain is derived from milled-rice product-weight quantities.",
          "Hybrid Medium/Short Grain (MSG) is derived as Rough Rice, MSG plus Milled, MSG and can combine product bases.",
          "Hybrid Long Grain is derived as Rough Rice, Long Grain plus Milled, Long Grain and can combine product bases."
        ),
        stringsAsFactors = FALSE
      )))
    }

    product_basis_empty_registry()
  }

  product_basis_source_data_for_scope <- function(source_scope = active_custom_scope()) {
    scope <- normalize_product_basis_scope(source_scope)
    data_frequency <- current_data_frequency_safe()

    switch(
      scope,
      census_export = rice_data_census_monthly,
      census_import = rice_data_census_imports_monthly,
      hybrid_export = {
        hybrid_mode <- tryCatch(hybrid_mode_choice(), error = function(...) "standard")
        if (identical(data_frequency, "weekly") && identical(hybrid_mode, "weekly_imputed")) {
          rice_data_hybrid_weekly_imputed
        } else {
          rice_data_hybrid_monthly
        }
      },
      hybrid_import = rice_data_hybrid_import_monthly,
      export_sales = {
        if (identical(data_frequency, "monthly")) rice_data_monthly else rice_data_weekly
      },
      product_basis_empty_registry()
    )
  }

  product_basis_registry_cache_key <- reactive({
    scope <- active_custom_scope()
    source_df <- product_basis_source_data_for_scope(scope)

    list(
      source_scope = scope,
      frequency = current_data_frequency_safe(),
      hybrid_trade_flow = tryCatch(hybrid_trade_flow_choice(), error = function(...) "export"),
      hybrid_mode = tryCatch(hybrid_mode_choice(), error = function(...) "standard"),
      rows = if (is.data.frame(source_df)) nrow(source_df) else 0L,
      columns = if (is.data.frame(source_df)) paste(names(source_df), collapse = "|") else "",
      cache_data_version = cache_data_version,
      cache_schema_version = cache_schema_version
    )
  })

  product_basis_registry <- reactive({
    scope <- active_custom_scope()

    if (identical(scope, "psd")) {
      return(product_basis_empty_registry())
    }

    infer_product_basis_registry(
      df = product_basis_source_data_for_scope(scope),
      source_scope = scope,
      explicit_registry = product_basis_explicit_registry_for_scope(scope)
    )
  }) %>%
    bindCache(product_basis_registry_cache_key())

  product_weight_basis_allowed <- function(
    commodity_name,
    active_tab = NULL,
    source_choice = current_source_choice_safe(),
    hybrid_trade_flow = NULL
  ) {
    commodity_values <- as.character(commodity_name)
    commodity_values <- commodity_values[!is.na(commodity_values) & nzchar(commodity_values)]

    if (length(commodity_values) == 0) {
      return(FALSE)
    }

    commodity_name <- commodity_values[[1]]

    if (identical(source_choice, "psd") || identical(commodity_name, CUSTOM_BUILDER_CHOICE)) {
      return(FALSE)
    }

    source_choice %in% c("export_sales", "census", "hybrid")
  }

  comparison_state_family_for_source <- function(source_choice = current_source_choice_safe()) {
    if (identical(source_choice, "psd")) "psd" else "domestic"
  }

  reference_year_choices_safe <- function() {
    if (!exists("reference_year_choices", mode = "function", inherits = TRUE)) {
      return(NULL)
    }

    tryCatch(reference_year_choices(), error = function(...) NULL)
  }

  comparison_state_default_reference_year <- function(year_choices = reference_year_choices_safe()) {
    if (length(year_choices) > 1) {
      year_choices[[2]]
    } else if (length(year_choices) == 1) {
      year_choices[[1]]
    } else {
      NULL
    }
  }

  normalize_comparison_year_choices <- function(year_choices) {
    years <- suppressWarnings(as.numeric(year_choices))
    years <- years[is.finite(years)]
    sort(unique(years), decreasing = TRUE)
  }

  available_hist_year_count <- function(year_choices) {
    years <- normalize_comparison_year_choices(year_choices)
    max(length(years) - 1L, 1L)
  }

  comparison_default_hist_years <- function(year_choices, default = 3L) {
    hist_max <- available_hist_year_count(year_choices)
    default <- suppressWarnings(as.integer(default))
    if (!(length(default) == 1 && is.finite(default) && default >= 1L)) {
      default <- 3L
    }
    as.integer(min(default, hist_max))
  }

  sanitize_comparison_hist_years <- function(value, year_choices = reference_year_choices_safe(), default = 3L) {
    hist_max <- available_hist_year_count(year_choices)
    value <- suppressWarnings(as.integer(value))
    if (!(length(value) == 1 && is.finite(value) && value >= 1L)) {
      value <- comparison_default_hist_years(year_choices, default = default)
    }

    as.integer(min(max(value, 1L), hist_max))
  }

  comparison_hist_years_debounce_ms <- function(default = 300L) {
    default <- suppressWarnings(as.integer(default))
    if (!(length(default) == 1 && is.finite(default) && default >= 0L)) {
      default <- 300L
    }

    option_default <- if (isTRUE(getOption("shiny.testmode", FALSE))) 0L else default
    delay <- suppressWarnings(as.integer(getOption("rice.comparison_hist_years_debounce_ms", option_default)))
    if (!(length(delay) == 1 && is.finite(delay) && delay >= 0L)) {
      delay <- option_default
    }

    as.integer(delay)
  }

  commit_comparison_hist_years_reactive <- function(raw_reactive) {
    delay <- comparison_hist_years_debounce_ms()
    if (delay > 0L) {
      return(shiny::debounce(raw_reactive, delay))
    }

    raw_reactive
  }

  comparison_hist_years_raw <- reactive({
    sanitize_comparison_hist_years(input$hist_years, reference_year_choices_safe())
  })

  comparison_hist_years_committed <- commit_comparison_hist_years_reactive(comparison_hist_years_raw)

  map_comparison_hist_years_raw <- reactive({
    sanitize_comparison_hist_years(input$map_hist_years, reference_year_choices_safe())
  })

  map_comparison_hist_years_committed <- commit_comparison_hist_years_reactive(map_comparison_hist_years_raw)

  comparison_hist_slider_grid_num <- function(hist_year_max) {
    hist_year_max <- suppressWarnings(as.integer(hist_year_max))
    if (!(length(hist_year_max) == 1 && is.finite(hist_year_max) && hist_year_max >= 1L)) {
      hist_year_max <- 1L
    }
    as.integer(max(hist_year_max - 1L, 1L))
  }

  comparison_hist_slider <- function(input_id, label, hist_year_max, hist_years) {
    hist_year_max <- suppressWarnings(as.integer(hist_year_max))
    if (!(length(hist_year_max) == 1 && is.finite(hist_year_max) && hist_year_max >= 1L)) {
      hist_year_max <- 1L
    }

    hist_years <- suppressWarnings(as.integer(hist_years))
    if (!(length(hist_years) == 1 && is.finite(hist_years) && hist_years >= 1L)) {
      hist_years <- min(3L, hist_year_max)
    }
    hist_years <- as.integer(min(max(hist_years, 1L), hist_year_max))

    slider <- sliderInput(
      inputId = input_id,
      label = label,
      min = 1,
      max = hist_year_max,
      value = hist_years,
      step = 1,
      ticks = TRUE
    )

    htmltools::tagQuery(slider)$
      find("input")$
      removeAttrs(c("data-grid-num", "data-grid-snap"))$
      addAttrs(
        `data-grid-num` = as.character(comparison_hist_slider_grid_num(hist_year_max)),
        `data-grid-snap` = "true"
      )$
      allTags()
  }

  historical_years_for_window <- function(available_years, recent_year = NULL, hist_window = 3L) {
    years <- normalize_comparison_year_choices(available_years)
    if (length(years) == 0) return(numeric(0))

    recent_year <- suppressWarnings(as.numeric(recent_year))
    if (!(length(recent_year) == 1 && is.finite(recent_year) && recent_year %in% years)) {
      recent_year <- years[[1]]
    }

    hist_window <- suppressWarnings(as.integer(hist_window))
    if (!(length(hist_window) == 1 && is.finite(hist_window) && hist_window >= 1L)) {
      hist_window <- comparison_default_hist_years(years)
    }

    prior_years <- years[years < recent_year]
    head(prior_years, min(length(prior_years), hist_window))
  }

  normalize_comparison_state_bundle <- function(state = NULL, year_choices = reference_year_choices_safe()) {
    state <- state %||% list()

    basis_mode <- state$basis_mode %||% "average"
    if (!(length(basis_mode) == 1 && !is.na(basis_mode) && basis_mode %in% c("average", "single_year"))) {
      basis_mode <- "average"
    }

    hist_years <- suppressWarnings(as.integer(state$hist_years))
    if (!(length(hist_years) == 1 && is.finite(hist_years) && hist_years >= 1)) {
      hist_years <- comparison_default_hist_years(year_choices)
    } else {
      hist_years <- as.integer(min(hist_years, available_hist_year_count(year_choices)))
    }

    default_reference_year <- comparison_state_default_reference_year(year_choices)
    reference_year <- suppressWarnings(as.numeric(state$reference_year))
    if (length(year_choices) > 0) {
      if (!(length(reference_year) == 1 && is.finite(reference_year) && reference_year %in% year_choices)) {
        reference_year <- default_reference_year
      }
    } else if (!(length(reference_year) == 1 && is.finite(reference_year))) {
      reference_year <- default_reference_year
    }

    list(
      basis_mode = basis_mode,
      reference_year = reference_year,
      hist_years = hist_years
    )
  }

  get_remembered_comparison_state_bundle <- function(
    source_choice = current_source_choice_safe(),
    year_choices = reference_year_choices_safe()
  ) {
    family_key <- comparison_state_family_for_source(source_choice)
    store <- session$userData$comparison_state_bundles
    remembered_state <- if (is.list(store)) store[[family_key]] else NULL

    normalize_comparison_state_bundle(remembered_state, year_choices)
  }

  set_remembered_comparison_state_bundle <- function(
    source_choice = current_source_choice_safe(),
    basis_mode = NULL,
    reference_year = NULL,
    hist_years = NULL,
    year_choices = reference_year_choices_safe()
  ) {
    family_key <- comparison_state_family_for_source(source_choice)
    current_state <- get_remembered_comparison_state_bundle(source_choice, year_choices)

    next_state <- current_state
    if (!is.null(basis_mode)) {
      next_state$basis_mode <- basis_mode
    }
    if (!is.null(reference_year) || identical(reference_year, NULL)) {
      next_state$reference_year <- reference_year
    }
    if (!is.null(hist_years)) {
      next_state$hist_years <- hist_years
    }

    normalized_state <- normalize_comparison_state_bundle(next_state, year_choices)
    store <- session$userData$comparison_state_bundles
    if (!is.list(store)) {
      store <- list()
    }
    store[[family_key]] <- normalized_state
    session$userData$comparison_state_bundles <- store

    invisible(normalized_state)
  }

  read_comparison_state_bundle_safe <- function(
    surface = c("auto", "standard", "map"),
    source_choice = current_source_choice_safe(),
    year_choices = reference_year_choices_safe(),
    hist_years_override = NULL
  ) {
    surface <- match.arg(surface)
    if (identical(surface, "auto")) {
      active_tab <- tryCatch(input$main_tabs_panel, error = function(...) NULL)
      surface <- if (identical(active_tab, "Map")) "map" else "standard"
    }

    remembered_state <- get_remembered_comparison_state_bundle(source_choice, year_choices)
    basis_input_id <- if (identical(surface, "map")) "map_projection_basis_mode" else "projection_basis_mode"
    ref_input_id <- if (identical(surface, "map")) "map_projection_reference_year" else "projection_reference_year"
    hist_input_id <- if (identical(surface, "map")) "map_hist_years" else "hist_years"

    current_basis_mode <- tryCatch(input[[basis_input_id]], error = function(...) NULL)
    current_reference_year <- tryCatch(input[[ref_input_id]], error = function(...) NULL)
    current_hist_years <- if (!is.null(hist_years_override)) hist_years_override else tryCatch(input[[hist_input_id]], error = function(...) NULL)
    parsed_hist_years <- suppressWarnings(as.integer(current_hist_years))

    normalize_comparison_state_bundle(
      list(
        basis_mode = if (length(current_basis_mode) == 1 && !is.na(current_basis_mode) && current_basis_mode %in% c("average", "single_year")) current_basis_mode else remembered_state$basis_mode,
        reference_year = if (!is.null(current_reference_year) && length(current_reference_year) == 1 && nzchar(as.character(current_reference_year))) current_reference_year else remembered_state$reference_year,
        hist_years = if (length(parsed_hist_years) == 1 && is.finite(parsed_hist_years) && parsed_hist_years >= 1) parsed_hist_years else remembered_state$hist_years
      ),
      year_choices
    )
  }

  current_comparison_basis_mode_safe <- function(
    surface = c("auto", "standard", "map"),
    source_choice = current_source_choice_safe(),
    year_choices = reference_year_choices_safe()
  ) {
    read_comparison_state_bundle_safe(surface, source_choice, year_choices)$basis_mode
  }

  current_comparison_reference_year_safe <- function(
    surface = c("auto", "standard", "map"),
    source_choice = current_source_choice_safe(),
    year_choices = reference_year_choices_safe()
  ) {
    read_comparison_state_bundle_safe(surface, source_choice, year_choices)$reference_year
  }

  current_comparison_hist_years_safe <- function(
    surface = c("auto", "standard", "map"),
    source_choice = current_source_choice_safe(),
    year_choices = reference_year_choices_safe()
  ) {
    read_comparison_state_bundle_safe(surface, source_choice, year_choices)$hist_years
  }

  basis_choices_for_commodity <- function(
    commodity_name,
    active_tab = NULL,
    source_choice = current_source_choice_safe()
  ) {
    if (identical(source_choice, "psd")) {
      return(psd_basis_choices_for_profile())
    }

    if (identical(source_choice, "wasde")) {
      return(c(
        "Rough-equivalent" = "rough_eq",
        "Milled-equivalent" = "milled_eq"
      ))
    }

    if (identical(source_choice, "nass")) {
      return(c(
        "Shelled Equivalent" = "shelled_eq",
        "In-Shell Equivalent" = "inshell_eq"
      ))
    }

    basis_choices_all
  }

  resolve_basis_choice <- function(
    commodity_name,
    basis_choice,
    active_tab = NULL,
    source_choice = current_source_choice_safe()
  ) {
    if (identical(source_choice, "psd")) {
      valid_psd_choices <- unname(psd_basis_choices_for_profile())

      if (!is.null(basis_choice) && nzchar(basis_choice) && basis_choice %in% valid_psd_choices) {
        return(basis_choice)
      }

      return(psd_default_basis_choice())
    }

    if (identical(source_choice, "wasde")) {
      valid_wasde_choices <- c("rough_eq", "milled_eq")

      if (identical(basis_choice, "brown_eq")) {
        return("rough_eq")
      }

      if (!is.null(basis_choice) && nzchar(basis_choice) && basis_choice %in% valid_wasde_choices) {
        return(basis_choice)
      }

      return("rough_eq")
    }

    fallback_basis <- default_basis_for_commodity(commodity_name, source_choice)

    if (!identical(source_choice, "psd") && !identical(source_choice, "wasde")) {
      valid_choices <- unname(basis_choices_for_commodity(commodity_name, active_tab, source_choice))
      if (!is.null(basis_choice) && nzchar(basis_choice) && basis_choice %in% valid_choices) {
        return(basis_choice)
      }

      return(fallback_basis)
    }

    if (is.null(basis_choice) || !nzchar(basis_choice)) {
      return(fallback_basis)
    }

    if (identical(basis_choice, "unadjusted") && !isTRUE(product_weight_basis_allowed(commodity_name, active_tab, source_choice))) {
      return(fallback_basis)
    }

    basis_choice
  }

  sanitize_numeric <- function(value) {
    out <- suppressWarnings(as.numeric(value))
    out[!is.finite(out)] <- NA_real_
    out
  }

  basis_conversion <- function(base_value, rough_value, basis_choice, source_choice = current_source_choice_safe()) {
    if (identical(source_choice, "psd")) {
      basis_values <- switch(
        basis_choice,
        "shelled_basis" = base_value,
        "inshell_eq" = base_value / census_inshell_shell_out_factor(),
        "rough_eq" = rough_value,
        "milled_eq" = base_value,
        base_value
      )

      return(sanitize_numeric(basis_values))
    }

    basis_values <- switch(
      basis_choice,
      "shelled_eq" = rough_value,
      "inshell_eq" = rough_value / census_inshell_shell_out_factor(),
      "unadjusted" = base_value,
      "brown_eq" = rough_value / 1.25,
      "milled_eq" = rough_value / 1.42857142857143,
      rough_value
    )

    sanitize_numeric(basis_values)
  }

  nass_shellout_factor_for_context <- function(
    years = NULL,
    countries = NULL,
    annual_year_types = NULL,
    n = NULL,
    default = census_inshell_shell_out_factor()
  ) {
    if (is.null(n)) {
      n <- max(length(years), length(countries), length(annual_year_types), 1L)
    }
    n <- suppressWarnings(as.integer(n))
    if (!(length(n) == 1L && is.finite(n) && n >= 1L)) n <- 1L
    out <- rep(suppressWarnings(as.numeric(default)), n)

    if (!exists("rice_data_nass_shellout_factors", inherits = TRUE) || !is.data.frame(rice_data_nass_shellout_factors) || nrow(rice_data_nass_shellout_factors) == 0L) {
      return(out)
    }

    factors_df <- rice_data_nass_shellout_factors
    required_cols <- c("country", "calendar_year", "annual_year_type", "shell_out_factor", "factor_status")
    if (!all(required_cols %in% names(factors_df))) return(out)

    years <- rep_len(suppressWarnings(as.integer(years %||% NA_integer_)), n)
    countries <- rep_len(trimws(as.character(countries %||% "US")), n)
    countries[countries %in% c("", NA_character_, "GRAND_TOTAL")] <- "US"
    annual_year_types <- rep_len(trimws(as.character(annual_year_types %||% "calendar_year")), n)
    annual_year_types[annual_year_types %in% c("", NA_character_)] <- "calendar_year"

    valid_factors <- factors_df[
      trimws(as.character(factors_df$factor_status)) == "nass_derived" &
        !is.na(suppressWarnings(as.numeric(factors_df$shell_out_factor))) &
        is.finite(suppressWarnings(as.numeric(factors_df$shell_out_factor))) &
        suppressWarnings(as.numeric(factors_df$shell_out_factor)) > 0,
      ,
      drop = FALSE
    ]
    if (nrow(valid_factors) == 0L) return(out)

    lookup_key <- paste(
      trimws(as.character(valid_factors$country)),
      suppressWarnings(as.integer(valid_factors$calendar_year)),
      trimws(as.character(valid_factors$annual_year_type)),
      sep = "\r"
    )
    lookup_values <- suppressWarnings(as.numeric(valid_factors$shell_out_factor))
    keep <- !duplicated(lookup_key)
    match_key <- paste(countries, years, annual_year_types, sep = "\r")
    matched <- match(match_key, lookup_key[keep])
    has_match <- !is.na(matched)
    out[has_match] <- lookup_values[keep][matched[has_match]]

    unmatched <- !has_match & !is.na(years)
    if (any(unmatched)) {
      nass_years <- if (exists("rice_data_nass_annual", inherits = TRUE) && is.data.frame(rice_data_nass_annual) && "calendar_year" %in% names(rice_data_nass_annual)) {
        suppressWarnings(as.integer(rice_data_nass_annual$calendar_year))
      } else {
        suppressWarnings(as.integer(valid_factors$calendar_year))
      }
      current_year <- if (any(!is.na(nass_years))) max(nass_years, na.rm = TRUE) else NA_integer_
      lag_eligible <- unmatched & !is.na(current_year) & years == current_year
      if (any(lag_eligible)) {
        lag_match_key <- paste(countries[lag_eligible], years[lag_eligible] - 1L, annual_year_types[lag_eligible], sep = "\r")
        lag_matched <- match(lag_match_key, lookup_key[keep])
        lag_has_match <- !is.na(lag_matched)
        lag_indices <- which(lag_eligible)
        out[lag_indices[lag_has_match]] <- lookup_values[keep][lag_matched[lag_has_match]]
      }
    }
    out
  }

  convert_nass_display_values <- function(
    values,
    metric_code,
    unit_choice = default_unit_choice_for_context("nass", metric_code),
    area_unit_choice = default_nass_area_unit_choice_for_metric(metric_code),
    basis_choice = current_basis_choice_safe(),
    value_unit_choice = default_value_unit_choice_for_context("nass", metric_code),
    years = NULL,
    countries = NULL,
    annual_year_types = NULL,
    lock_context = "selected_metric"
  ) {
    native_values <- sanitize_numeric(values)
    metric_family <- nass_metric_family_for_code(metric_code)
    effective_controls <- nass_effective_conversion_controls(
      metric_code = metric_code,
      source_choice = "nass",
      unit_choice = unit_choice,
      area_unit_choice = area_unit_choice,
      basis_choice = basis_choice,
      value_unit_choice = value_unit_choice,
      lock_context = lock_context
    )
    unit_choice <- effective_controls$unit_choice
    area_unit_choice <- effective_controls$area_unit_choice
    basis_choice <- effective_controls$basis_choice
    value_unit_choice <- effective_controls$value_unit_choice
    shellout_factors <- nass_shellout_factor_for_context(
      years = years,
      countries = countries,
      annual_year_types = annual_year_types,
      n = length(native_values)
    )
    resolved_basis <- resolve_basis_choice(
      input$commodity_choice %||% default_commodity_choice_value(),
      basis_choice,
      active_tab = current_main_tab_safe(),
      source_choice = "nass"
    )

    apply_nass_basis <- function(value) {
      if (metric_family %in% c("quantity", "yield") && identical(resolved_basis, "inshell_eq")) {
        return(value / shellout_factors)
      }

      value
    }

    pounds_per_quantity_unit <- function(unit_code) {
      switch(
        unit_code,
        "thousand_mt" = 1000 * 2204.62,
        "mt" = 2204.62,
        "kg" = 2.20462,
        "thousand_kg" = 2204.62,
        "us_tons" = 2000,
        "thousand_lbs" = 1000,
        "lbs" = 1,
        "cwt" = 100,
        "mil_lbs" = 1000000,
        1000000
      )
    }

    nass_rate_numerator_multiplier <- function(value_unit_code) {
      switch(
        value_unit_code,
        "dollars" = 0.01,
        "cents" = 1,
        1
      )
    }

    acres_per_area_unit <- function(area_code) {
      switch(
        area_code,
        "ac" = 1,
        "thousand_ac" = 1000,
        "ha" = 2.47105,
        "thousand_ha" = 2471.05,
        1000
      )
    }

    resolve_nass_area_unit_choice <- function(area_code, default = default_nass_area_unit_choice_for_metric(metric_code)) {
      area_values <- trimws(as.character(area_code %||% ""))
      area_values <- area_values[!is.na(area_values) & nzchar(area_values)]
      if (length(area_values) > 0L && area_values[[1L]] %in% unname(psd_area_unit_choices)) {
        return(area_values[[1L]])
      }

      current_psd_area_unit_choice_safe(default, source_choice = "nass", metric_code = metric_code)
    }

    if (identical(metric_family, "quantity")) {
      million_pounds <- apply_nass_basis(native_values)
      pounds <- million_pounds * 1000000
      resolved_unit <- resolve_unit_choice(unit_choice, "nass", metric_code)
      return(sanitize_numeric(pounds / pounds_per_quantity_unit(resolved_unit)))
    }

    if (identical(metric_family, "yield")) {
      pounds_per_acre <- apply_nass_basis(native_values)
      resolved_unit <- resolve_unit_choice(unit_choice, "nass", metric_code)
      target_area_unit <- resolve_nass_area_unit_choice(area_unit_choice)
      converted_values <- (pounds_per_acre * acres_per_area_unit(target_area_unit)) / pounds_per_quantity_unit(resolved_unit)
      return(sanitize_numeric(converted_values))
    }

    if (identical(metric_family, "area")) {
      acres <- native_values * 1000
      target_area_unit <- resolve_nass_area_unit_choice(area_unit_choice)
      converted_values <- switch(
        target_area_unit,
        "ac" = acres,
        "thousand_ac" = acres / 1000,
        "ha" = acres / 2.47105,
        "thousand_ha" = acres / 2471.05,
        acres / 1000
      )
      return(sanitize_numeric(converted_values))
    }

    if (identical(metric_family, "value_total")) {
      target_value_unit <- resolve_census_value_unit_choice(
        value_unit_choice,
        default = default_value_unit_choice_for_context("nass", metric_code),
        source_choice = "nass",
        metric_code = metric_code
      )
      thousand_dollars <- native_values
      converted_values <- switch(
        target_value_unit,
        "dollars" = thousand_dollars * 1000,
        "thousand_dollars" = thousand_dollars,
        "million_dollars" = thousand_dollars / 1000,
        "billion_dollars" = thousand_dollars / 1000000,
        thousand_dollars
      )
      return(sanitize_numeric(converted_values))
    }

    if (identical(metric_family, "price_rate")) {
      resolved_unit <- resolve_unit_choice(unit_choice, "nass", metric_code)
      target_value_unit <- resolve_census_value_unit_choice(
        value_unit_choice,
        default = default_value_unit_choice_for_context("nass", metric_code),
        source_choice = "nass",
        metric_code = metric_code
      )
      basis_factor <- if (identical(resolved_basis, "inshell_eq")) shellout_factors else 1
      converted_values <- native_values *
        nass_rate_numerator_multiplier(target_value_unit) *
        pounds_per_quantity_unit(resolved_unit) *
        basis_factor
      return(sanitize_numeric(converted_values))
    }

    sanitize_numeric(native_values)
  }

  vp_trade_quantity_unit_conversion <- function(
    value,
    unit,
    volume_unit_family = NULL,
    source_volume_unit = NULL,
    vp_volume_family_mixed = NULL
  ) {
    values <- sanitize_numeric(value)
    n <- length(values)
    if (n == 0L) {
      return(values)
    }

    normalize_length <- function(x, default = NA_character_) {
      raw_values <- as.character(x %||% character(0))
      if (length(raw_values) == 0L) {
        return(rep(default, n))
      }
      normalized <- trimws(tolower(raw_values))
      if (length(normalized) == 1L) {
        return(rep(normalized[[1L]], n))
      }
      if (length(normalized) != n) {
        return(rep(normalized[[1L]], n))
      }
      normalized
    }

    family_values <- normalize_length(volume_unit_family)
    if (any(is.na(family_values) | !nzchar(family_values)) && exists("vp_volume_family", mode = "function")) {
      source_units <- as.character(source_volume_unit %||% character(0))
      if (length(source_units) > 0L) {
        if (length(source_units) == 1L) {
          source_units <- rep(source_units[[1L]], n)
        } else if (length(source_units) != n) {
          source_units <- rep(source_units[[1L]], n)
        }
        derived_family <- tryCatch(vp_volume_family(source_units), error = function(...) rep(NA_character_, n))
        derived_family <- trimws(tolower(as.character(derived_family)))
        if (length(derived_family) == 1L) {
          derived_family <- rep(derived_family[[1L]], n)
        } else if (length(derived_family) != n) {
          derived_family <- rep(derived_family[[1L]], n)
        }
        needs_fill <- is.na(family_values) | !nzchar(family_values)
        family_values[needs_fill] <- derived_family[needs_fill]
      }
    }

    mixed_values <- as.logical(vp_volume_family_mixed)
    if (length(mixed_values) == 0L) {
      mixed_values <- rep(FALSE, n)
    } else if (length(mixed_values) == 1L) {
      mixed_values <- rep(mixed_values[[1L]], n)
    } else if (length(mixed_values) != n) {
      mixed_values <- rep(mixed_values[[1L]], n)
    }
    mixed_values[is.na(mixed_values)] <- FALSE

    family_values[!(family_values %in% c("liquid", "weight"))] <- NA_character_

    unit_values <- trimws(as.character(unit %||% character(0)))
    unit_values <- unit_values[!is.na(unit_values) & nzchar(unit_values)]
    if (length(unit_values) == 0L) {
      return(rep(NA_real_, n))
    }
    unit_code <- unit_values[[1L]]

    converted <- rep(NA_real_, n)
    liquid_idx <- !mixed_values & family_values == "liquid"
    weight_idx <- !mixed_values & family_values == "weight"

    if (any(liquid_idx)) {
      converted[liquid_idx] <- switch(
        unit_code,
        "gallons" = values[liquid_idx],
        "thousand_gallons" = values[liquid_idx] / 1000,
        rep(NA_real_, sum(liquid_idx))
      )
    }

    if (any(weight_idx)) {
      mt_values <- values[weight_idx]
      converted[weight_idx] <- switch(
        unit_code,
        "thousand_mt" = mt_values / 1000,
        "mt" = mt_values,
        "kg" = mt_values * 1000,
        "thousand_kg" = mt_values,
        "us_tons" = mt_values * 1.10231,
        "thousand_lbs" = mt_values * 2204.62 / 1000,
        "lbs" = mt_values * 2204.62,
        "cwt" = mt_values * 22.0462,
        "million_cwt" = mt_values * 22.0462 / 1000000,
        "mil_lbs" = mt_values * 2204.62 / 1000000,
        rep(NA_real_, sum(weight_idx))
      )
    }

    sanitize_numeric(converted)
  }
  
  # unit_conversion()
  # -----------------
  # Converts a numeric value from Metric Tons to the specified target unit.
  # This function is vectorized and can be applied to entire columns using dplyr::mutate().
  #
  # Parameters:
  #   value - numeric value(s) in Metric Tons to be converted
  #   unit  - character string specifying the target unit code:
  #           "thousand_mt", "mt", "kg", "thousand_kg", "us_tons", "lbs",
  #           "thousand_lbs", "cwt", "mil_lbs" (and WASDE-specific "million_cwt"/"native_unit")
  #
  # Returns:
  #   Numeric value(s) converted to the target unit
  unit_conversion <- function(
    value,
    unit,
    source_choice = current_source_choice_safe(),
    metric_code = NULL,
    area_unit_choice = current_psd_area_unit_choice_safe(),
    basis_choice = current_basis_choice_safe(),
    value_unit_choice = current_census_value_unit_choice_safe(source_choice = source_choice, metric_code = metric_code),
    commodity_choice = NULL,
    lock_context = "selected_metric"
  ) {
    wasde_mt_per_bushel <- 45 * 0.00045359237

    wasde_mt_per_quantity_unit <- function(unit_code, metric_family = wasde_metric_family_for_code(metric_code), metric_code_value = metric_code) {
      canonical_unit <- normalize_wasde_canonical_unit_label(metric_code_value)

      if (identical(unit_code, "native_unit")) {
        if (identical(metric_family, "quantity")) {
          return(1000000 * 0.045359237)
        }

        if (identical(metric_family, "yield")) {
          return(0.00045359237)
        }

        if (identical(metric_family, "dollar_rate")) {
          if (grepl("short ton", canonical_unit, fixed = TRUE)) {
            return(0.90718474)
          }

          if (grepl("bushel", canonical_unit, fixed = TRUE)) {
            return(wasde_mt_per_bushel)
          }

          return(0.045359237)
        }
      }

      switch(
        unit_code,
        "million_cwt" = 1000000 * 0.045359237,
        "thousand_mt" = 1000,
        "mt" = 1,
        "kg" = 0.001,
        "thousand_kg" = 1,
        "bushels" = wasde_mt_per_bushel,
        "us_tons" = 0.90718474,
        "thousand_lbs" = 1000 * 0.00045359237,
        "lbs" = 0.00045359237,
        "cwt" = 0.045359237,
        "mil_lbs" = 1000000 * 0.00045359237,
        1000000 * 0.045359237
      )
    }

    wasde_acres_per_area_unit <- function(area_code) {
      switch(
        area_code,
        "ac" = 1,
        "thousand_ac" = 1000,
        "ha" = 2.47105,
        "thousand_ha" = 2471.05,
        1000
      )
    }

    resolved_wasde_basis <- function() {
      explicit_commodity <- trimws(as.character(commodity_choice %||% character(0)))
      explicit_commodity <- explicit_commodity[!is.na(explicit_commodity) & nzchar(explicit_commodity)]

      input_commodity <- tryCatch(shiny::isolate(input$commodity_choice), error = function(...) NULL)
      input_commodity <- trimws(as.character(input_commodity %||% character(0)))
      input_commodity <- input_commodity[!is.na(input_commodity) & nzchar(input_commodity)]

      resolved_commodity <- if (length(explicit_commodity) > 0L) {
        explicit_commodity[[1L]]
      } else if (length(input_commodity) > 0L) {
        input_commodity[[1L]]
      } else {
        default_commodity_choice_value()
      }

      resolve_basis_choice(
        resolved_commodity,
        basis_choice,
        active_tab = current_main_tab_safe(),
        source_choice = "wasde"
      )
    }

    wasde_basis_inverse_multiplier <- function(resolved_basis_choice) {
      if (identical(resolved_basis_choice, "milled_eq")) {
        return(1.42857142857143)
      }

      if (identical(resolved_basis_choice, "brown_eq")) {
        return(1.25)
      }

      1
    }

    area_multiplier <- switch(
      area_unit_choice,
      "ac" = 2.47105,
      "ha" = 1,
      "thousand_ac" = 2.47105 / 1000,
      "thousand_ha" = 1 / 1000,
      1 / 1000
    )

    if (identical(source_choice, "wasde")) {
      native_values <- sanitize_numeric(value)
      metric_family <- wasde_metric_family_for_code(metric_code)

      if (is_wasde_locked_control_metric(metric_code)) {
        return(sanitize_numeric(native_values))
      }

      effective_controls <- list(
        unit_choice = unit,
        area_unit_choice = area_unit_choice,
        basis_choice = basis_choice,
        value_unit_choice = value_unit_choice,
        price_locked = FALSE,
        yield_locked = FALSE
      )
      effective_controls <- wasde_effective_conversion_controls(
        metric_code = metric_code,
        source_choice = "wasde",
        unit_choice = unit,
        area_unit_choice = area_unit_choice,
        basis_choice = basis_choice,
        value_unit_choice = value_unit_choice,
        lock_context = lock_context
      )
      unit <- effective_controls$unit_choice
      area_unit_choice <- effective_controls$area_unit_choice
      basis_choice <- effective_controls$basis_choice
      value_unit_choice <- effective_controls$value_unit_choice

      resolved_basis <- resolved_wasde_basis()
      resolved_unit_choice <- resolve_unit_choice(unit, source_choice = "wasde", metric_code = metric_code)
      resolved_value_unit <- resolve_census_value_unit_choice(
        value_unit_choice,
        default = default_value_unit_choice_for_context("wasde", metric_code),
        source_choice = "wasde",
        metric_code = metric_code
      )

      if (identical(metric_family, "quantity")) {
        basis_values <- basis_conversion(
          base_value = native_values,
          rough_value = native_values,
          basis_choice = resolved_basis,
          source_choice = "wasde"
        )

        million_cwt_values <- sanitize_numeric(basis_values)
        cwt_values <- million_cwt_values * 1000000
        mt_values <- cwt_values * 0.045359237

        converted_values <- switch(
          resolved_unit_choice,
          "native_unit" = million_cwt_values,
          "million_cwt" = million_cwt_values,
          "thousand_mt" = mt_values / 1000,
          "mt" = mt_values,
          "kg" = mt_values * 1000,
          "thousand_kg" = mt_values,
          "bushels" = mt_values / wasde_mt_per_bushel,
          "us_tons" = cwt_values / 20,
          "lbs" = cwt_values * 100,
          "cwt" = cwt_values,
          "mil_lbs" = (cwt_values * 100) / 1000000,
          million_cwt_values
        )

        return(sanitize_numeric(converted_values))
      }

      if (identical(metric_family, "area")) {
        acres_values <- native_values * 1000000

        converted_values <- switch(
          area_unit_choice,
          "ac" = acres_values,
          "thousand_ac" = acres_values / 1000,
          "ha" = acres_values / 2.47105,
          "thousand_ha" = acres_values / 2471.05,
          acres_values / 1000
        )

        return(sanitize_numeric(converted_values))
      }

      if (identical(metric_family, "yield")) {
        native_mt_per_acre <- native_values * 0.00045359237
        acres_per_target_area <- wasde_acres_per_area_unit(area_unit_choice)
        target_mt_per_unit <- wasde_mt_per_quantity_unit(resolved_unit_choice, metric_family = "yield", metric_code_value = metric_code)

        if (identical(resolved_unit_choice, "native_unit") && identical(area_unit_choice, "ac")) {
          return(sanitize_numeric(native_values))
        }

        converted_values <- (native_mt_per_acre * acres_per_target_area) / target_mt_per_unit
        return(sanitize_numeric(converted_values))
      }

      if (identical(metric_family, "dollar_total")) {
        canonical_unit <- normalize_wasde_canonical_unit_label(metric_code)
        dollar_multiplier <- if (identical(canonical_unit, "million dollars")) 1000000 else 1

        if (identical(resolved_value_unit, "native_dollars")) {
          return(sanitize_numeric(native_values))
        }

        native_dollars <- native_values * dollar_multiplier

        converted_values <- value_unit_conversion(
          native_dollars,
          resolved_value_unit,
          source_choice = "wasde",
          metric_code = metric_code
        )

        return(sanitize_numeric(converted_values))
      }

      if (identical(metric_family, "dollar_rate")) {
        native_denom_mt <- wasde_mt_per_quantity_unit("native_unit", metric_family = "dollar_rate", metric_code_value = metric_code)
        target_denom_mt <- wasde_mt_per_quantity_unit(resolved_unit_choice, metric_family = "dollar_rate", metric_code_value = metric_code)

        denominator_multiplier <- if (
          is.finite(native_denom_mt) && native_denom_mt > 0 &&
            is.finite(target_denom_mt) && target_denom_mt > 0
        ) {
          target_denom_mt / native_denom_mt
        } else {
          1
        }

        basis_multiplier <- wasde_basis_inverse_multiplier(resolved_basis)
        dollars_per_target_unit <- native_values * denominator_multiplier * basis_multiplier

        if (identical(resolved_value_unit, "native_dollars")) {
          return(sanitize_numeric(dollars_per_target_unit))
        }

        converted_values <- value_unit_conversion(
          dollars_per_target_unit,
          resolved_value_unit,
          source_choice = "wasde",
          metric_code = metric_code
        )

        return(sanitize_numeric(converted_values))
      }

      sanitize_numeric(native_values)
    }

    if (identical(source_choice, "psd") && is_psd_area_metric(metric_code)) {
      thousand_ha_values <- value

      return(switch(
        area_unit_choice,
        "ac" = thousand_ha_values * 2471.05,
        "ha" = thousand_ha_values * 1000,
        "thousand_ac" = thousand_ha_values * 2.47105,
        "thousand_ha" = thousand_ha_values,
        thousand_ha_values
      ))
    }

    if (identical(source_choice, "psd") && is_psd_yield_metric(metric_code)) {
      quantity_multiplier <- switch(
        unit,
        "thousand_mt" = 1 / 1000,
        "mt" = 1,
        "kg" = 1000,
        "thousand_kg" = 1,
        "us_tons" = 1.10231,
        "thousand_lbs" = 2204.62 / 1000,
        "lbs" = 2204.62,
        "cwt" = 22.0462,
        "million_cwt" = 22.0462 / 1000000,
        "mil_lbs" = 2204.62 / 1000000,
        1 / 1000
      )

      return(value * (quantity_multiplier / area_multiplier))
    }

    mt_values <- value

    switch(unit,
      "thousand_mt" = value / 1000,
      "mt" = mt_values,
      "kg" = mt_values * 1000,
      "thousand_kg" = mt_values,
      "us_tons" = mt_values * 1.10231,
      "thousand_lbs" = mt_values * 2204.62 / 1000,
      "lbs" = mt_values * 2204.62,
      "cwt" = mt_values * 22.0462,
      "million_cwt" = mt_values * 22.0462 / 1000000,
      "mil_lbs" = mt_values * 2204.62 / 1000000,
      mt_values
    )
  }
  
  # get_unit_label()
  # ----------------
  # Returns a human-readable display name for the specified unit code.
  # Used primarily for axis labels in plots and table headers to ensure
  # users can clearly identify the unit of measurement being displayed.
  #
  # Parameters:
  #   unit - character string unit code ("mt", "us_tons", "lbs", "cwt", or "mil_lbs")
  #
  # Returns:
  #   Character string with the display-friendly unit name
  get_unit_label <- function(unit) {
    switch(unit,
      "native_unit" = "WASDE Unit",
      "million_cwt" = "Million CWT",
      "thousand_mt" = "1000 MT",
      "thousand_kg" = "1000 Kilograms",
      "thousand_ha" = "1000 HA",
      "ha" = "HA",
      "thousand_ac" = "1000 AC",
      "ac" = "AC",
      "mt" = "Metric Tons",
      "kg" = "Kilograms (KG)",
      "bushels" = "Bushels",
      "thousand_gallons" = "1000 Gallons",
      "gallons" = "Gallons",
      "us_tons" = "US Tons",
      "thousand_lbs" = "1000 Pounds",
      "lbs" = "Pounds",
      "cwt" = "CWT",
      "mil_lbs" = "Million Pounds"
    )
  }

  get_basis_label <- function(basis) {
    switch(
      basis,
      "shelled_basis" = "Shelled Basis",
      "shelled_eq" = "shelled-equivalent",
      "inshell_eq" = "inshell-equivalent",
      "milled_eq" = "Milled-equivalent",
      "rough_eq" = "Rough-equivalent",
      "brown_eq" = "Brown-equivalent",
      "unadjusted" = "Product-weight",
      "Rough-equivalent"
    )
  }

  get_measurement_label <- function(unit, basis) {
    paste0(get_unit_label(unit), ", ", get_basis_label(basis))
  }

  get_psd_metric_unit_label <- function(metric_code, unit_choice, area_unit_choice = current_psd_area_unit_choice_safe()) {
    if (is_psd_area_metric(metric_code)) {
      return(get_unit_label(area_unit_choice))
    }

    if (is_psd_milling_rate_metric(metric_code)) {
      return("Percent")
    }

    if (is_psd_yield_metric(metric_code)) {
      return(paste0(get_unit_label(unit_choice), "/", get_unit_label(area_unit_choice)))
    }

    get_unit_label(unit_choice)
  }

  nass_display_unit_label <- function(
    metric_code,
    unit_choice = current_unit_choice_safe(default = default_unit_choice_for_context("nass", metric_code)),
    area_unit_choice = current_psd_area_unit_choice_safe(default_nass_area_unit_choice_for_metric(metric_code)),
    basis_choice = current_basis_choice_safe(),
    value_unit_choice = current_census_value_unit_choice_safe(source_choice = "nass", metric_code = metric_code),
    commodity_name = default_commodity_choice_value(),
    active_tab = current_main_tab_safe(),
    lock_context = "selected_metric"
  ) {
    metric_family <- nass_metric_family_for_code(metric_code)
    effective_controls <- nass_effective_conversion_controls(
      metric_code = metric_code,
      source_choice = "nass",
      unit_choice = unit_choice,
      area_unit_choice = area_unit_choice,
      basis_choice = basis_choice,
      value_unit_choice = value_unit_choice,
      lock_context = lock_context
    )
    unit_choice <- effective_controls$unit_choice
    area_unit_choice <- effective_controls$area_unit_choice
    basis_choice <- effective_controls$basis_choice
    value_unit_choice <- effective_controls$value_unit_choice
    resolved_basis <- resolve_basis_choice(
      commodity_name,
      basis_choice,
      active_tab = active_tab,
      source_choice = "nass"
    )

    if (identical(metric_family, "area")) {
      return(get_unit_label(area_unit_choice))
    }

    if (identical(metric_family, "quantity")) {
      return(paste0(get_unit_label(resolve_unit_choice(unit_choice, "nass", metric_code)), ", ", get_basis_label(resolved_basis)))
    }

    if (identical(metric_family, "yield")) {
      return(paste0(
        get_unit_label(resolve_unit_choice(unit_choice, "nass", metric_code)),
        "/",
        get_unit_label(area_unit_choice),
        ", ",
        get_basis_label(resolved_basis)
      ))
    }

    if (identical(metric_family, "value_total")) {
      return(get_value_unit_label(value_unit_choice, source_choice = "nass", metric_code = metric_code))
    }

    if (identical(metric_family, "price_rate")) {
      return(paste0(
        get_value_unit_label(value_unit_choice, source_choice = "nass", metric_code = metric_code),
        "/",
        get_unit_label(resolve_unit_choice(unit_choice, "nass", metric_code)),
        ", ",
        get_basis_label(resolved_basis)
      ))
    }

    nass_metric_unit_for_code(metric_code)
  }

  is_product_weight_basis <- function(
    commodity_name,
    basis_choice,
    active_tab = NULL,
    source_choice = current_source_choice_safe()
  ) {
    evaluate_one <- function(one_commodity) {
      resolved_basis <- resolve_basis_choice(one_commodity, basis_choice, active_tab, source_choice)
      identical(resolved_basis, "unadjusted") &&
        isTRUE(product_weight_basis_allowed(one_commodity, active_tab, source_choice))
    }

    if (length(commodity_name) > 1) {
      return(vapply(as.character(commodity_name), evaluate_one, logical(1)))
    }

    commodity_values <- as.character(commodity_name)
    commodity_values <- commodity_values[!is.na(commodity_values) & nzchar(commodity_values)]
    if (length(commodity_values) == 0) {
      return(FALSE)
    }

    evaluate_one(commodity_values[[1]])
  }

  is_all_rice_unadjusted <- function(commodity_name, basis_choice) {
    if (length(commodity_name) > 1) {
      return(as.character(commodity_name) == "All Rice" & is_product_weight_basis("All Rice", basis_choice))
    }

    identical(commodity_name, "All Rice") && isTRUE(is_product_weight_basis(commodity_name, basis_choice))
  }

  get_commodity_display_label <- function(commodity_name, basis_choice, source_choice = current_source_choice_safe(), hybrid_trade_flow = NULL, census_trade_flow = NULL) {
    if (is.null(hybrid_trade_flow)) {
      hybrid_trade_flow <- tryCatch(active_hybrid_trade_flow(), error = function(...) "export")
    }
    if (is.null(census_trade_flow)) {
      census_trade_flow <- tryCatch(active_census_trade_flow(), error = function(...) "export")
    }
    use_hybrid_import_display_labels <- identical(source_choice, "hybrid") && identical(hybrid_trade_flow, "import")
    use_census_display_labels <- identical(source_choice, "census")

    apply_census_display_labels <- function(values) {
      out <- as.character(values)
      if (!isTRUE(use_census_display_labels) || length(out) == 0L) {
        return(out)
      }

      flow <- trimws(as.character(census_trade_flow %||% "export"))
      flow <- flow[!is.na(flow) & nzchar(flow)]
      flow <- if (length(flow) > 0L && identical(flow[[1L]], "import")) "import" else "export"
      census_choices <- if (identical(flow, "import")) native_commodities_census_imports else native_commodities_census_exports
      choice_values <- trimws(as.character(unname(census_choices)))
      choice_labels <- trimws(as.character(names(census_choices)))
      lookup_idx <- match(trimws(out), choice_values)
      has_lookup <- !is.na(lookup_idx) & lookup_idx >= 1L & lookup_idx <= length(choice_labels)
      out[has_lookup] <- choice_labels[lookup_idx[has_lookup]]
      out
    }

    if (length(commodity_name) > 1) {
      out <- as.character(commodity_name)
      all_rice_product_weight <- isTRUE(is_product_weight_basis("All Rice", basis_choice))

      if (isTRUE(all_rice_product_weight)) {
        out[out == "All Rice"] <- "All Rice (PRODUCT-WEIGHT)"
      }
      if (isTRUE(use_hybrid_import_display_labels)) {
        out <- dplyr::coalesce(
          unname(hybrid_import_commodity_display_labels[out]),
          out
        )
      }
      out <- apply_census_display_labels(out)
      return(out)
    }

    if (identical(commodity_name, "All Rice") && isTRUE(is_product_weight_basis(commodity_name, basis_choice))) {
      return("All Rice (PRODUCT-WEIGHT)")
    }
    if (isTRUE(use_hybrid_import_display_labels) && commodity_name %in% names(hybrid_import_commodity_display_labels)) {
      return(unname(hybrid_import_commodity_display_labels[[commodity_name]]))
    }
    apply_census_display_labels(commodity_name)[[1L]]
  }

  get_measurement_label_for_commodity <- function(unit, commodity_name, basis_choice, active_tab = NULL, metric_code = NULL, source_choice = current_source_choice_safe(), area_unit_choice = current_psd_area_unit_choice_safe(), value_unit_choice = NULL, lock_context = "selected_metric") {
    resolved_basis <- resolve_basis_choice(commodity_name, basis_choice, active_tab, source_choice)

    if (identical(source_choice, "psd") && !is.null(metric_code) && is_psd_area_metric(metric_code)) {
      return(get_psd_metric_unit_label(metric_code, unit, area_unit_choice))
    }

    if (identical(source_choice, "psd") && !is.null(metric_code) && is_psd_milling_rate_metric(metric_code)) {
      return(get_psd_metric_unit_label(metric_code, unit, area_unit_choice))
    }

    if (identical(source_choice, "psd") && !is.null(metric_code) && is_psd_yield_metric(metric_code)) {
      return(paste0(get_psd_metric_unit_label(metric_code, unit, area_unit_choice), ", ", get_basis_label(resolved_basis)))
    }

    if (identical(source_choice, "nass")) {
      return(nass_display_unit_label(
        metric_code = metric_code,
        unit_choice = unit,
        area_unit_choice = area_unit_choice,
        basis_choice = basis_choice,
        value_unit_choice = value_unit_choice %||% current_census_value_unit_choice_safe(source_choice = "nass", metric_code = metric_code),
        commodity_name = commodity_name,
        active_tab = active_tab,
        lock_context = lock_context
      ))
    }

    if (identical(source_choice, "wasde")) {
      effective_controls <- list(
        unit_choice = unit,
        area_unit_choice = area_unit_choice,
        basis_choice = basis_choice,
        value_unit_choice = value_unit_choice %||% current_census_value_unit_choice_safe(source_choice = "wasde", metric_code = metric_code),
        price_locked = FALSE,
        yield_locked = FALSE
      )
      effective_controls <- wasde_effective_conversion_controls(
        metric_code = metric_code,
        source_choice = "wasde",
        unit_choice = unit,
        area_unit_choice = area_unit_choice,
        basis_choice = basis_choice,
        value_unit_choice = value_unit_choice %||% current_census_value_unit_choice_safe(source_choice = "wasde", metric_code = metric_code),
        lock_context = lock_context
      )
      unit <- effective_controls$unit_choice
      area_unit_choice <- effective_controls$area_unit_choice
      basis_choice <- effective_controls$basis_choice
      value_unit_choice <- effective_controls$value_unit_choice
      resolved_basis <- resolve_basis_choice(commodity_name, basis_choice, active_tab, source_choice)
      metric_family <- wasde_metric_family_for_code(metric_code)
      resolved_value_unit <- if (!is.null(value_unit_choice) && length(value_unit_choice) > 0L) {
        resolve_census_value_unit_choice(
          value_unit_choice,
          default = default_value_unit_choice_for_context("wasde", metric_code),
          source_choice = "wasde",
          metric_code = metric_code
        )
      } else {
        current_census_value_unit_choice_safe(source_choice = "wasde", metric_code = metric_code)
      }

      if (is_wasde_locked_control_metric(metric_code)) {
        return(wasde_metric_unit_for_code(metric_code, default = "WASDE Unit"))
      }

      if (identical(metric_family, "area")) {
        return(get_unit_label(area_unit_choice))
      }

      if (identical(metric_family, "yield")) {
        return(paste0(get_unit_label(unit), "/", get_unit_label(area_unit_choice), ", ", get_basis_label(resolved_basis)))
      }

      if (identical(metric_family, "dollar_total")) {
        return(get_value_unit_label(resolved_value_unit, source_choice = "wasde", metric_code = metric_code))
      }

      if (identical(metric_family, "dollar_rate")) {
        canonical_unit <- wasde_metric_unit_for_code(metric_code, default = "WASDE Unit")
        native_denominator_label <- trimws(sub("^.*per\\s+", "", canonical_unit, ignore.case = TRUE))
        if (!nzchar(native_denominator_label)) {
          native_denominator_label <- "CWT"
        }

        denominator_label <- if (identical(unit, "native_unit")) {
          native_denominator_label
        } else {
          get_unit_label(unit)
        }

        rate_label <- paste0(
          get_value_unit_label(resolved_value_unit, source_choice = "wasde", metric_code = metric_code),
          " per ",
          denominator_label
        )

        if (is_wasde_basis_metric(metric_code)) {
          rate_label <- paste0(rate_label, ", ", get_basis_label(resolved_basis))
        }

        return(rate_label)
      }

      if (identical(metric_family, "percent")) {
        return("Percent")
      }

      if (is_wasde_basis_metric(metric_code)) {
        return(get_measurement_label(unit, resolved_basis))
      }

      return(wasde_metric_unit_for_code(metric_code, default = "WASDE Unit"))
    }

    get_measurement_label(unit, resolved_basis)
  }

  resolve_display_unit <- function(metric,
                                   source,
                                   rows,
                                   context = list(),
                                   fallback_context = NULL) {
    source_values <- trimws(as.character(source %||% character(0)))
    source_values <- source_values[!is.na(source_values) & nzchar(source_values)]
    source_value <- if (length(source_values) > 0L) source_values[[1L]] else ""

    metric_values <- trimws(as.character(metric %||% character(0)))
    metric_values <- metric_values[!is.na(metric_values) & nzchar(metric_values)]
    metric_values <- unique(metric_values)

    merged_context <- if (is.list(context)) context else list(context = context)
    if (is.list(fallback_context) && length(fallback_context) > 0L) {
      merged_context <- c(merged_context, fallback_context)
    }

    make_result <- function(label = "",
                            status = "fallback",
                            units = character(0),
                            message = "",
                            metric_value = metric_values,
                            source_label = source_value,
                            extra_context = list()) {
      out <- list(
        label = as.character(label %||% ""),
        status = as.character(status %||% "fallback"),
        units = as.character(units %||% character(0)),
        metric = metric_value,
        source = source_label,
        message = as.character(message %||% ""),
        context = c(merged_context, extra_context)
      )
      class(out) <- c("ftn_display_unit_resolution", class(out))
      out
    }

    if (length(metric_values) == 0L) {
      return(make_result(
        status = "fallback",
        message = "No metric code provided for display-unit resolution."
      ))
    }

    if (length(metric_values) > 1L) {
      return(make_result(
        status = "multi_metric",
        metric_value = metric_values,
        message = "Multiple metrics were provided; per-metric unit resolution is required.",
        extra_context = list(metric_count = length(metric_values))
      ))
    }

    metric_value <- metric_values[[1L]]
    if (!identical(source_value, "vp_trade")) {
      return(make_result(
        metric_value = metric_value,
        status = "fallback",
        message = "Display-unit resolver currently specializes vp_trade unit-value metrics."
      ))
    }

    unit_field <- switch(
      metric_value,
      "unit_value" = "unit_value_unit",
      "ytd_unit_value" = "ytd_unit_value_unit",
      NULL
    )
    if (is.null(unit_field)) {
      return(make_result(
        metric_value = metric_value,
        status = "fallback",
        message = "Metric is not a vp_trade unit-value metric."
      ))
    }

    if (!is.data.frame(rows) || nrow(rows) == 0L) {
      return(make_result(
        metric_value = metric_value,
        status = "fallback",
        message = "No rows were provided for display-unit resolution.",
        extra_context = list(unit_field = unit_field, row_count = 0L)
      ))
    }

    if (!(unit_field %in% names(rows))) {
      return(make_result(
        metric_value = metric_value,
        status = "missing_unit_anomaly",
        message = paste0("Expected unit field missing from rows: ", unit_field),
        extra_context = list(unit_field = unit_field, row_count = nrow(rows))
      ))
    }

    observed_mask <- rep(TRUE, nrow(rows))
    if (metric_value %in% names(rows)) {
      metric_numeric <- suppressWarnings(as.numeric(rows[[metric_value]]))
      observed_mask <- is.finite(metric_numeric)
    }

    observed_count <- sum(observed_mask, na.rm = TRUE)
    if (observed_count == 0L) {
      return(make_result(
        metric_value = metric_value,
        status = "fallback",
        message = "No finite metric values were available for display-unit resolution.",
        extra_context = list(unit_field = unit_field, row_count = nrow(rows), observed_count = observed_count)
      ))
    }

    unit_values <- trimws(as.character(rows[[unit_field]]))
    unit_values[is.na(unit_values)] <- ""
    observed_units <- unit_values[observed_mask]

    missing_unit_rows <- sum(!nzchar(observed_units), na.rm = TRUE)
    present_units <- sort(unique(observed_units[nzchar(observed_units)]))
    unit_count <- length(present_units)

    if (unit_count > 1L) {
      return(make_result(
        label = "Mixed unit values",
        metric_value = metric_value,
        status = "mixed_unit_anomaly",
        units = present_units,
        message = "Multiple display units were observed for one unit-value metric context.",
        extra_context = list(
          unit_field = unit_field,
          row_count = nrow(rows),
          observed_count = observed_count,
          missing_unit_rows = missing_unit_rows,
          unit_count = unit_count
        )
      ))
    }

    if (unit_count == 0L) {
      return(make_result(
        metric_value = metric_value,
        status = "missing_unit_anomaly",
        units = character(0),
        message = "Finite unit-value rows are present but display unit labels are missing.",
        extra_context = list(
          unit_field = unit_field,
          row_count = nrow(rows),
          observed_count = observed_count,
          missing_unit_rows = missing_unit_rows,
          unit_count = unit_count
        )
      ))
    }

    status <- if (missing_unit_rows > 0L) "missing_unit_anomaly" else "ok"
    message <- if (missing_unit_rows > 0L) {
      "Some finite unit-value rows are missing unit labels."
    } else {
      ""
    }

    make_result(
      label = present_units[[1L]],
      metric_value = metric_value,
      status = status,
      units = present_units,
      message = message,
      extra_context = list(
        unit_field = unit_field,
        row_count = nrow(rows),
        observed_count = observed_count,
        missing_unit_rows = missing_unit_rows,
        unit_count = unit_count
      )
    )
  }

  resolve_vp_trade_display_unit <- function(metric_code = effective_main_metric(),
                                            rows = NULL,
                                            context = list(),
                                            fallback_context = NULL) {
    resolved_rows <- rows
    if (is.null(resolved_rows)) {
      context_entry <- vp_trade_context_entry(
        source_choice = input$data_source_choice,
        country_choice = input$country_choice,
        vp_group_choice = input$vp_group_choice,
        vp_subgroup_choice = input$vp_subgroup_choice,
        vp_market_segment_choice = input$vp_market_segment_choice,
        vp_commodity_name_choice = input$vp_commodity_name_choice,
        vp_commodity_detail_choice = input$commodity_choice,
        vp_filter_purpose = "display_unit_resolver",
        country_mode = "display_unit_resolver",
        require_rows = TRUE
      )
      resolved_rows <- context_entry$rows
    }

    resolve_display_unit(
      metric = metric_code,
      source = "vp_trade",
      rows = resolved_rows,
      context = context,
      fallback_context = fallback_context
    )
  }

  build_unit_resolution_context <- function(tab_id = NULL,
                                            output_id = NULL,
                                            source_choice = NULL,
                                            metric_code = NULL,
                                            trade_flow = NULL,
                                            hierarchy_path = NULL,
                                            country_scope = NULL,
                                            market_scope = NULL,
                                            rollup_level = NULL,
                                            rollup_path = NULL,
                                            run_id = NULL,
                                            extra = list()) {
    context <- list(
      tab_id = tab_id,
      output_id = output_id,
      source = source_choice,
      metric = metric_code,
      trade_flow = trade_flow,
      hierarchy_path = hierarchy_path,
      country_scope = country_scope,
      market_scope = market_scope,
      rollup_level = rollup_level,
      rollup_path = rollup_path,
      run_id = run_id
    )

    if (is.list(extra) && length(extra) > 0L) {
      context <- c(context, extra)
    }

    context
  }

  unit_guardrail_event_message <- function(status_value,
                                           default_message = "") {
    status_value <- trimws(as.character(status_value %||% ""))
    if (identical(status_value, "mixed_unit_anomaly")) {
      return("Unit guardrail: mixed unit values detected; review All - excluding juice routing.")
    }
    if (identical(status_value, "missing_unit_anomaly")) {
      return("Unit guardrail: missing display units detected for unit-value rows.")
    }

    trimws(as.character(default_message %||% ""))
  }

  unit_guardrail_events_get <- function(session_domain = getDefaultReactiveDomain()) {
    if (is.null(session_domain) || is.null(session_domain$userData)) {
      return(data.frame(stringsAsFactors = FALSE))
    }

    events <- session_domain$userData$unit_guardrail_events
    if (!is.data.frame(events)) {
      return(data.frame(stringsAsFactors = FALSE))
    }

    events
  }

  unit_guardrail_events_clear <- function(session_domain = getDefaultReactiveDomain()) {
    if (is.null(session_domain) || is.null(session_domain$userData)) {
      return(invisible(FALSE))
    }

    session_domain$userData$unit_guardrail_events <- data.frame(stringsAsFactors = FALSE)
    session_domain$userData$unit_guardrail_signatures <- character(0)
    invisible(TRUE)
  }

  unit_guardrail_record_event <- function(unit_resolution,
                                          context = list(),
                                          session_domain = getDefaultReactiveDomain(),
                                          include_ok = FALSE) {
    if (!is.list(unit_resolution)) {
      return(invisible(NULL))
    }
    if (is.null(session_domain) || is.null(session_domain$userData)) {
      return(invisible(NULL))
    }

    status_value <- trimws(as.character(unit_resolution$status %||% "fallback"))
    if (!isTRUE(include_ok) && identical(status_value, "ok")) {
      return(invisible(NULL))
    }

    context_values <- if (is.list(context)) context else list(context = context)
    resolution_context <- if (is.list(unit_resolution$context)) unit_resolution$context else list()
    merged_context <- c(context_values, resolution_context)

    units <- sort(unique(trimws(as.character(unit_resolution$units %||% character(0)))))
    units <- units[!is.na(units) & nzchar(units)]

    timestamp_utc <- format(Sys.time(), tz = "UTC", usetz = TRUE)
    run_id <- as.character(merged_context$run_id %||% timestamp_utc)
    tab_id <- as.character(merged_context$tab_id %||% "")
    output_id <- as.character(merged_context$output_id %||% "")
    source_value <- as.character(merged_context$source %||% unit_resolution$source %||% "")
    metric_value <- as.character(merged_context$metric %||% unit_resolution$metric %||% "")
    trade_flow <- as.character(merged_context$trade_flow %||% "")
    hierarchy_path <- as.character(merged_context$hierarchy_path %||% "")
    country_scope <- as.character(merged_context$country_scope %||% "")
    market_scope <- as.character(merged_context$market_scope %||% "")
    rollup_level <- as.character(merged_context$rollup_level %||% "")
    rollup_path <- as.character(merged_context$rollup_path %||% "")
    event_message <- unit_guardrail_event_message(status_value, unit_resolution$message %||% "")
    unit_set <- if (length(units) > 0L) paste(units, collapse = "|") else ""

    event_signature <- paste(
      tab_id,
      output_id,
      source_value,
      metric_value,
      status_value,
      trade_flow,
      hierarchy_path,
      country_scope,
      market_scope,
      rollup_level,
      rollup_path,
      unit_set,
      sep = "||"
    )

    signatures <- session_domain$userData$unit_guardrail_signatures
    if (is.null(signatures)) signatures <- character(0)
    signatures <- as.character(signatures)
    if (event_signature %in% signatures) {
      return(invisible(NULL))
    }

    event_row <- data.frame(
      timestamp_utc = timestamp_utc,
      run_id = run_id,
      tab_id = tab_id,
      output_id = output_id,
      source = source_value,
      metric = metric_value,
      status = status_value,
      message = event_message,
      units = unit_set,
      trade_flow = trade_flow,
      hierarchy_path = hierarchy_path,
      country_scope = country_scope,
      market_scope = market_scope,
      rollup_level = rollup_level,
      rollup_path = rollup_path,
      stringsAsFactors = FALSE
    )

    existing_events <- unit_guardrail_events_get(session_domain = session_domain)
    if (!is.data.frame(existing_events) || nrow(existing_events) == 0L) {
      session_domain$userData$unit_guardrail_events <- event_row
    } else {
      session_domain$userData$unit_guardrail_events <- dplyr::bind_rows(existing_events, event_row)
    }

    session_domain$userData$unit_guardrail_signatures <- c(signatures, event_signature)
    invisible(event_row)
  }

  get_metric_measurement_label <- function(
    metric_code = effective_main_metric(),
    source_choice = current_source_choice_safe(),
    unit_choice = current_unit_choice_safe(),
    basis_choice = current_basis_choice_safe(),
    value_unit_choice = current_census_value_unit_choice_safe(source_choice = source_choice, metric_code = metric_code),
    commodity_name = if (!is.null(input$commodity_choice)) input$commodity_choice else default_commodity_choice_value(),
    active_tab = current_main_tab_safe(),
    area_unit_choice = current_psd_area_unit_choice_safe(),
    lock_context = "selected_metric"
  ) {
    lock_context <- normalize_metric_lock_context(lock_context)

    if (identical(source_choice, "vp_trade") && metric_code %in% c("unit_value", "ytd_unit_value")) {
      unit_resolution <- tryCatch(
        resolve_vp_trade_display_unit(
          metric_code = metric_code,
          context = list(
            metric_code = metric_code,
            source_choice = source_choice,
            lock_context = lock_context
          )
        ),
        error = function(...) NULL
      )
      if (is.list(unit_resolution)) {
        unit_guardrail_record_event(
          unit_resolution = unit_resolution,
          context = build_unit_resolution_context(
            tab_id = current_main_tab_safe(),
            output_id = "metric_measurement_label",
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
            run_id = "measurement_label_resolution"
          )
        )
      }
      if (is.list(unit_resolution) && !is.null(unit_resolution$label) && nzchar(unit_resolution$label)) {
        return(unit_resolution$label)
      }
      return("Native Unit Value")
    }

    if (identical(source_choice, "vp_trade")) {
      if (is_census_value_metric(metric_code, source_choice)) {
        return(get_value_unit_label(value_unit_choice, source_choice = source_choice, metric_code = metric_code))
      }

      return(get_unit_label(unit_choice))
    }

    if (is_census_value_metric(metric_code, source_choice)) {
      return(get_value_unit_label(value_unit_choice))
    }

    if (identical(source_choice, "nass")) {
      return(nass_display_unit_label(
        metric_code = metric_code,
        unit_choice = unit_choice,
        area_unit_choice = area_unit_choice,
        basis_choice = basis_choice,
        value_unit_choice = value_unit_choice,
        commodity_name = commodity_name,
        active_tab = active_tab,
        lock_context = lock_context
      ))
    }

    get_measurement_label_for_commodity(
      unit = unit_choice,
      commodity_name = commodity_name,
      basis_choice = basis_choice,
      active_tab = active_tab,
      metric_code = metric_code,
      source_choice = source_choice,
      area_unit_choice = area_unit_choice,
      value_unit_choice = value_unit_choice,
      lock_context = lock_context
    )
  }

  product_basis_summary_for_commodity <- function(commodity_name) {
    commodity_values <- as.character(commodity_name)
    commodity_values <- commodity_values[!is.na(commodity_values) & nzchar(commodity_values)]
    if (length(commodity_values) == 0) {
      return(list(summary = "", mixed = FALSE, components = data.frame()))
    }

    commodity_name <- commodity_values[[1]]
    registry_df <- tryCatch(product_basis_registry(), error = function(...) product_basis_empty_registry())
    custom_df <- tryCatch(custom_types_enriched(), error = function(...) NULL)

    if (is.data.frame(custom_df) && nrow(custom_df) > 0 && "custom_name" %in% names(custom_df)) {
      custom_row <- custom_df %>% filter(.data$custom_name == commodity_name, .data$parse_ok)
      if (nrow(custom_row) > 0 && "product_basis_summary" %in% names(custom_row)) {
        return(list(
          summary = as.character(custom_row$product_basis_summary[[1]] %||% ""),
          mixed = isTRUE(custom_row$product_basis_mixed[[1]]),
          components = custom_row$product_basis_components[[1]] %||% data.frame()
        ))
      }
    }

    product_basis_summary_for_refs(commodity_name, registry_df)
  }

  get_product_weight_basis_note <- function(
    commodity_name,
    basis_choice,
    active_tab = current_main_tab_safe(),
    source_choice = current_source_choice_safe()
  ) {
    if (!isTRUE(is_product_weight_basis(commodity_name, basis_choice, active_tab, source_choice))) return(NULL)

    basis_summary <- product_basis_summary_for_commodity(commodity_name)
    note_text <- "WARNING: Product-weight uses source product-basis quantities before rough/brown/milled-equivalent conversion."

    if (nzchar(basis_summary$summary %||% "")) {
      note_text <- paste0(note_text, " Components: ", basis_summary$summary, ".")
    }

    if (isTRUE(basis_summary$mixed)) {
      note_text <- paste0(note_text, " Mixed, variable, or unknown components can combine different product bases.")
    }

    tags$em(note_text)
  }

  get_unadjusted_all_rice_note <- function(commodity_name, basis_choice) {
    get_product_weight_basis_note(commodity_name, basis_choice)
  }

  # --- EXPLICIT NUMERIC SPOT-CHECK ASSERTIONS (REGRESSION PASS) ---
  # Validate that basis/unit/value contracts still match expected arithmetic.
  run_conversion_contract_assertions <- function() {
    quantity_unit_conversion <- function(
      value,
      unit,
      source_choice = "census",
      metric_code = NULL,
      basis_choice = census_default_basis_choice()
    ) {
      unit_conversion(
        value,
        unit,
        source_choice = source_choice,
        metric_code = metric_code,
        area_unit_choice = "ha",
        basis_choice = basis_choice,
        value_unit_choice = "thousand_dollars",
        commodity_choice = default_commodity_choice_value()
      )
    }

    stopifnot(
      "Basis unadjusted failed" = identical(basis_conversion(100, 150, "unadjusted"), 100),
      "Basis rough_eq failed" = identical(basis_conversion(100, 150, "rough_eq"), 150),
      "Basis brown_eq failed" = isTRUE(all.equal(basis_conversion(100, 150, "brown_eq"), 150 / 1.25)),
      "Basis milled_eq failed" = isTRUE(all.equal(basis_conversion(100, 150, "milled_eq"), 150 / 1.42857142857143)),
      "PSD basis milled_eq failed" = identical(basis_conversion(100, 69, "milled_eq", source_choice = "psd"), 100),
      "PSD basis rough_eq failed" = identical(basis_conversion(100, 69, "rough_eq", source_choice = "psd"), 69),
      "PSD basis shelled_basis failed" = identical(basis_conversion(100, 69, "shelled_basis", source_choice = "psd"), 100),
      "PSD basis inshell_eq failed" = isTRUE(all.equal(basis_conversion(100, 69, "inshell_eq", source_choice = "psd"), 100 / census_inshell_shell_out_factor()))
    )

    psd_default_basis <- default_basis_for_commodity(default_commodity_choice_value(), "psd")
    psd_allowed_basis_choices <- unname(basis_choices_for_commodity(default_commodity_choice_value(), source_choice = "psd"))
    psd_expected_default_basis <- psd_default_basis_choice()

    if (identical(psd_basis_profile_choice(), "shelled_basis")) {
      stopifnot(
        "PSD shelled default basis helper consistency failed" = identical(psd_default_basis, psd_expected_default_basis),
        "PSD shelled default basis membership failed" = isTRUE(psd_default_basis %in% psd_allowed_basis_choices),
        "PSD shelled choices failed" = identical(psd_allowed_basis_choices, c("shelled_basis", "inshell_eq")),
        "PSD shelled label failed" = identical(get_basis_label("shelled_basis"), "Shelled Basis")
      )
    } else {
      stopifnot(
        "PSD milled-profile default basis helper consistency failed" = identical(psd_default_basis, psd_expected_default_basis),
        "PSD milled-profile default basis membership failed" = isTRUE(psd_default_basis %in% psd_allowed_basis_choices),
        "PSD milled-profile choices failed" = identical(psd_allowed_basis_choices, c("milled_eq", "rough_eq"))
      )
    }

    stopifnot(
      "Unit MT failed" = identical(quantity_unit_conversion(100, "mt"), 100),
      "Unit KG failed" = identical(quantity_unit_conversion(100, "kg"), 100000),
      "Unit 1000 KG failed" = identical(quantity_unit_conversion(100, "thousand_kg"), 100),
      "Unit US Tons failed" = isTRUE(all.equal(quantity_unit_conversion(100, "us_tons"), 100 * 1.10231)),
      "Unit 1000 Pounds failed" = isTRUE(all.equal(quantity_unit_conversion(100, "thousand_lbs"), 100 * 2204.62 / 1000)),
      "Unit CWT failed" = isTRUE(all.equal(quantity_unit_conversion(100, "cwt"), 100 * 22.0462)),
      "PSD Unit MT identity failed" = identical(quantity_unit_conversion(1, "mt", source_choice = "psd", metric_code = "psd_production", basis_choice = "rough_eq"), 1),
      "PSD Unit KG failed" = identical(quantity_unit_conversion(1, "kg", source_choice = "psd", metric_code = "psd_production", basis_choice = "rough_eq"), 1000),
      "PSD Unit 1000 KG failed" = identical(quantity_unit_conversion(1, "thousand_kg", source_choice = "psd", metric_code = "psd_production", basis_choice = "rough_eq"), 1),
      "PSD Unit 1000 Pounds failed" = isTRUE(all.equal(quantity_unit_conversion(1, "thousand_lbs", source_choice = "psd", metric_code = "psd_production", basis_choice = "rough_eq"), 2.20462)),
      "PSD Unit Pounds failed" = isTRUE(all.equal(quantity_unit_conversion(1, "lbs", source_choice = "psd", metric_code = "psd_production", basis_choice = "rough_eq"), 2204.62)),
      "WASDE Unit KG failed" = isTRUE(all.equal(quantity_unit_conversion(1, "kg", source_choice = "wasde", metric_code = "qty_of_exports", basis_choice = "rough_eq"), 45359237)),
      "WASDE Unit 1000 KG failed" = isTRUE(all.equal(quantity_unit_conversion(1, "thousand_kg", source_choice = "wasde", metric_code = "qty_of_exports", basis_choice = "rough_eq"), 45359.237)),
      "VP Liquid Gallons identity failed" = identical(vp_trade_quantity_unit_conversion(2500, "gallons", volume_unit_family = "liquid"), 2500),
      "VP Liquid 1000 Gallons failed" = identical(vp_trade_quantity_unit_conversion(2500, "thousand_gallons", volume_unit_family = "liquid"), 2.5),
      "VP Liquid weight unit blocked failed" = is.na(vp_trade_quantity_unit_conversion(2500, "thousand_lbs", volume_unit_family = "liquid")),
      "VP Mixed volume blocked failed" = is.na(vp_trade_quantity_unit_conversion(2500, "gallons", volume_unit_family = "liquid", vp_volume_family_mixed = TRUE)),
      "Unit Gallons label failed" = identical(get_unit_label("gallons"), "Gallons"),
      "Unit 1000 Pounds label failed" = identical(get_unit_label("thousand_lbs"), "1000 Pounds")
    )

    stopifnot(
      "Value unit dollars failed" = identical(value_unit_conversion(1000, "dollars"), 1000),
      "Value unit 1000 Dollars failed" = identical(value_unit_conversion(1000, "thousand_dollars"), 1),
      "Value unit Million Dollars failed" = identical(value_unit_conversion(1000000, "million_dollars"), 1),
      "Value unit Billion Dollars failed" = identical(value_unit_conversion(1000000000, "billion_dollars"), 1)
    )

    if (identical(default_commodity_choice_value(), "All Rice")) {
      stopifnot(
        "Display label All Rice product-weight failed" = identical(get_commodity_display_label("All Rice", "unadjusted"), "All Rice (PRODUCT-WEIGHT)"),
        "Display label All Rice rough failed" = identical(get_commodity_display_label("All Rice", "rough_eq"), "All Rice"),
        "Display label non-All failed" = identical(get_commodity_display_label("Rice - Long Grain, Milled", "unadjusted"), "Rice - Long Grain, Milled"),
        "Commodity measurement label failed" = identical(get_measurement_label_for_commodity("cwt", "All Rice", "unadjusted"), "CWT, Product-weight"),
        "WASDE brown fallback failed" = identical(resolve_basis_choice("All Rice", "brown_eq", source_choice = "wasde"), "rough_eq"),
        "WASDE brown hidden failed" = !"brown_eq" %in% unname(basis_choices_for_commodity("All Rice", source_choice = "wasde")),
        "Non-hybrid product-weight allowed failed" = identical(resolve_basis_choice("Rice - Long Grain, Milled", "unadjusted", source_choice = "export_sales"), "unadjusted"),
        "Hybrid export product-weight allowed failed" = identical(resolve_basis_choice("Rough Rice, MSG", "unadjusted", source_choice = "hybrid"), "unadjusted"),
        "Hybrid parent product-weight allowed failed" = identical(resolve_basis_choice("Rough Rice", "unadjusted", source_choice = "hybrid"), "unadjusted"),
        "Hybrid import product-weight allowed failed" = isTRUE(product_weight_basis_allowed("Long Grain", source_choice = "hybrid", hybrid_trade_flow = "import")),
        "Custom Comparison product-weight allowed failed" = identical(resolve_basis_choice("All Rice", "unadjusted", "Custom Comparison Tool"), "unadjusted"),
        "PSD product-weight hidden failed" = !"unadjusted" %in% unname(basis_choices_for_commodity("All Rice", source_choice = "psd"))
      )
    }
  }

  conversion_contract_assertions_enabled <-
    isTRUE(getOption("rice_startup_contract_assertions", FALSE)) ||
    isTRUE(getOption("shiny.testmode", FALSE))

  if (isTRUE(conversion_contract_assertions_enabled)) {
    run_conversion_contract_assertions()
  }
  # ----------------------------------------------------------------

  output$basis_choice_ui <- renderUI({
    commodity_choice <- if (!is.null(input$commodity_choice)) input$commodity_choice else default_commodity_choice_value()
    active_tab <- if (!is.null(input$main_tabs_panel)) input$main_tabs_panel else NULL
    source_choice <- current_source_choice_safe()
    metric_choice <- effective_main_metric()
    basis_choices <- basis_choices_for_commodity(commodity_choice, active_tab, source_choice)
    selected_basis <- resolve_basis_choice(
      commodity_choice,
      current_basis_choice_safe(default = default_basis_for_commodity(commodity_choice, source_choice)),
      active_tab,
      source_choice = source_choice
    )

    if (!(selected_basis %in% unname(basis_choices))) {
      selected_basis <- default_basis_for_commodity(commodity_choice, source_choice)
    }

    selectInput(
      inputId = "basis_choice",
      label = "Basis:",
      choices = basis_choices,
      selected = selected_basis
    )
  })

  resolve_wasde_native_control_defaults <- function(
    metric_choice = effective_main_metric(),
    commodity_choice = if (!is.null(input$commodity_choice)) input$commodity_choice else default_commodity_choice_value()
  ) {
    list(
      unit_choice = default_unit_choice_for_context("wasde", metric_choice),
      area_unit_choice = "ac",
      basis_choice = default_basis_for_commodity(commodity_choice, "wasde"),
      value_unit_choice = default_value_unit_choice_for_context("wasde", metric_choice)
    )
  }

  queue_wasde_native_override <- function(control_id, target_value) {
    control_id <- trimws(as.character(control_id %||% ""))
    target_value <- trimws(as.character(target_value %||% ""))
    if (!nzchar(control_id) || !nzchar(target_value)) {
      return(invisible(NULL))
    }

    pending_overrides <- session$userData$wasde_native_one_shot_overrides
    if (is.null(pending_overrides) || !is.list(pending_overrides)) {
      pending_overrides <- list()
    }

    pending_overrides[[control_id]] <- target_value
    session$userData$wasde_native_one_shot_overrides <- pending_overrides
    invisible(NULL)
  }

  consume_wasde_native_override <- function(control_id, valid_choices = NULL) {
    control_id <- trimws(as.character(control_id %||% ""))
    if (!nzchar(control_id)) {
      return(NULL)
    }

    pending_overrides <- session$userData$wasde_native_one_shot_overrides
    if (is.null(pending_overrides) || !is.list(pending_overrides) || is.null(pending_overrides[[control_id]])) {
      return(NULL)
    }

    override_value <- trimws(as.character(pending_overrides[[control_id]] %||% ""))
    if (!nzchar(override_value)) {
      pending_overrides[[control_id]] <- NULL
      session$userData$wasde_native_one_shot_overrides <- if (length(pending_overrides) > 0L) pending_overrides else NULL
      return(NULL)
    }

    if (!is.null(valid_choices) && length(valid_choices) > 0L && !(override_value %in% valid_choices)) {
      return(NULL)
    }

    pending_overrides[[control_id]] <- NULL
    session$userData$wasde_native_one_shot_overrides <- if (length(pending_overrides) > 0L) pending_overrides else NULL
    override_value
  }

  apply_wasde_native_control_defaults <- function(
    metric_choice = effective_main_metric(),
    commodity_choice = if (!is.null(input$commodity_choice)) input$commodity_choice else default_commodity_choice_value(),
    reason = "wasde_native_reset"
  ) {
    defaults <- resolve_wasde_native_control_defaults(metric_choice = metric_choice, commodity_choice = commodity_choice)
    unit_choices <- unit_choices_for_context("wasde", metric_choice)
    value_choices <- value_unit_choices_for_context("wasde", metric_choice)
    basis_choices <- basis_choices_for_commodity(commodity_choice, current_main_tab_safe(), "wasde")
    unit_values <- unname(unit_choices)
    value_values <- unname(value_choices)
    basis_values <- unname(basis_choices)

    native_unit <- defaults$unit_choice
    if (!(native_unit %in% unit_values)) {
      queue_wasde_native_override("unit_choice", native_unit)
      native_unit <- unit_values[[1]]
    }
    native_area <- if (defaults$area_unit_choice %in% unname(psd_area_unit_choices)) defaults$area_unit_choice else "ac"
    native_basis <- defaults$basis_choice
    if (!(native_basis %in% basis_values)) {
      queue_wasde_native_override("basis_choice", native_basis)
      native_basis <- basis_values[[1]]
    }
    native_value_unit <- defaults$value_unit_choice
    if (!(native_value_unit %in% value_values)) {
      queue_wasde_native_override("value_unit_choice", native_value_unit)
      native_value_unit <- value_values[[1]]
    }

    write_remembered_value_unit_choice(native_value_unit, source_choice = "wasde")

    updateSelectInput(session, "unit_choice", choices = unit_choices, selected = native_unit)
    updateSelectInput(session, "psd_area_unit_choice", choices = psd_area_unit_choices, selected = native_area)
    updateSelectInput(session, "basis_choice", choices = basis_choices, selected = native_basis)
    updateSelectInput(session, "value_unit_choice", choices = value_choices, selected = native_value_unit)

    session$userData$wasde_native_control_last_reason <- reason
  }

  observeEvent(input$data_source_choice, {
    source_choice <- if (!is.null(input$data_source_choice)) input$data_source_choice else "export_sales"
    previous_source <- session$userData$last_data_source_choice %||% ""

    if (
      identical(source_choice, "wasde") &&
      !identical(previous_source, "wasde") &&
      !isTRUE(session$userData$wasde_native_initialized_once)
    ) {
      apply_wasde_native_control_defaults(reason = "wasde_first_entry")
      session$userData$wasde_native_initialized_once <- TRUE
    }

    session$userData$last_data_source_choice <- source_choice
  }, ignoreInit = FALSE)

  observeEvent(input$wasde_reset_native_units, {
    if (!identical(current_source_choice_safe(), "wasde")) {
      return()
    }

    apply_wasde_native_control_defaults(reason = "wasde_reset_action")
    session$userData$wasde_native_initialized_once <- TRUE
  }, ignoreInit = TRUE)

  output$unit_controls_ui <- renderUI({
    source_choice <- if (!is.null(input$data_source_choice)) input$data_source_choice else "export_sales"
    metric_choice <- effective_main_metric()
    unit_choices <- unit_choices_for_context(source_choice, metric_choice)
    selected_unit <- current_unit_choice_safe(default = default_unit_choice_for_context(source_choice, metric_choice))
    selected_unit <- resolve_unit_choice(selected_unit, source_choice, metric_choice)
    selected_area_unit <- current_psd_area_unit_choice_safe()
    selected_value_unit <- current_census_value_unit_choice_safe(source_choice = source_choice, metric_code = metric_choice)
    value_unit_choices <- value_unit_choices_for_context(source_choice, metric_choice)
    vp_quantity_unit_unavailable_reason <- vp_trade_quantity_unit_unavailable_reason(source_choice = source_choice, metric_code = metric_choice)

    if (identical(source_choice, "psd")) {
      psd_defaults <- resolve_psd_metric_defaults(metric_choice)
      selected_unit <- current_psd_quantity_unit_choice_safe(
        default = psd_defaults$unit_choice,
        metric_code = metric_choice,
        source_choice = source_choice
      )
      selected_unit <- resolve_unit_choice(selected_unit, source_choice, metric_choice)
      selected_area_unit <- current_psd_area_unit_choice_safe(psd_defaults$area_unit_choice)
    } else if (identical(source_choice, "wasde")) {
      selected_unit <- current_unit_choice_safe(default = default_unit_choice_for_context(source_choice, metric_choice))
      selected_unit <- resolve_unit_choice(selected_unit, source_choice, metric_choice)
    } else if (identical(source_choice, "nass")) {
      selected_unit <- current_unit_choice_safe(default = default_unit_choice_for_context(source_choice, metric_choice))
      selected_unit <- resolve_unit_choice(selected_unit, source_choice, metric_choice)
      selected_area_unit <- current_psd_area_unit_choice_safe(
        default_nass_area_unit_choice_for_metric(metric_choice),
        source_choice = source_choice,
        metric_code = metric_choice
      )
    }

    div(
      style = "display: flex; gap: 6px; align-items: flex-end; margin-bottom: 15px; flex-wrap: wrap;",
      if (show_quantity_unit_choice(source_choice, metric_choice)) {
        div(
          style = "flex: 1 1 180px; min-width: 160px; margin-bottom: 0;",
          selectInput(
            inputId = "unit_choice",
            label = "Quantity Unit:",
            choices = unit_choices,
            selected = selected_unit
          )
        )
      },
      if (!is.null(vp_quantity_unit_unavailable_reason)) {
        div(
          style = "flex: 1 1 260px; min-width: 220px; margin-bottom: 0;",
          div(
            style = "font-size: 12px; color: #6b7280; padding: 7px 10px; border: 1px solid #d1d5db; border-radius: 4px; background-color: #f9fafb;",
            vp_quantity_unit_unavailable_reason
          )
        )
      },
      if (show_psd_area_unit_choice(source_choice, metric_choice)) {
        div(
          style = "flex: 1 1 180px; min-width: 160px; margin-bottom: 0;",
          selectInput(
            inputId = "psd_area_unit_choice",
            label = "Area Unit:",
            choices = psd_area_unit_choices,
            selected = selected_area_unit
          )
        )
      },
      if (show_value_unit_choice(source_choice, metric_choice)) {
        div(
          style = "flex: 1 1 180px; min-width: 160px; margin-bottom: 0;",
          selectInput(
            inputId = "value_unit_choice",
            label = "Value Unit:",
            choices = value_unit_choices,
            selected = selected_value_unit
          )
        )
      },
      if (show_basis_choice(source_choice, metric_choice)) {
        div(
          style = "flex: 1 1 180px; min-width: 160px; margin-bottom: 0;",
          uiOutput("basis_choice_ui")
        )
      },
      if (identical(source_choice, "wasde")) {
        div(
          style = "flex: 0 0 auto; min-width: 180px; margin-bottom: 0;",
          actionButton(
            inputId = "wasde_reset_native_units",
            label = "Reset unit defaults"
          )
        )
      }
    )
  })

  observeEvent(list(input$data_source_choice, input$metric_choice), {
    source_choice <- if (!is.null(input$data_source_choice)) input$data_source_choice else "export_sales"
    metric_choice <- effective_main_metric()
    unit_choices <- unit_choices_for_context(source_choice, metric_choice)
    vp_quantity_unit_unavailable_reason <- vp_trade_quantity_unit_unavailable_reason(source_choice = source_choice, metric_code = metric_choice)
    vp_pending_target_unit <- vp_trade_pending_default_unit_target(metric_code = metric_choice)
    selected_unit <- current_unit_choice_safe(default = default_unit_choice_for_context(source_choice, metric_choice))
    selected_unit <- resolve_unit_choice(selected_unit, source_choice, metric_choice)
    force_vp_trade_default_unit <- identical(source_choice, "vp_trade") &&
      isTRUE(isolate(vp_trade_unit_default_pending())) &&
      !is.null(vp_pending_target_unit) &&
      vp_pending_target_unit %in% unname(unit_choices) &&
      is.null(vp_quantity_unit_unavailable_reason)
    if (isTRUE(force_vp_trade_default_unit)) {
      selected_unit <- vp_pending_target_unit
    } else if (identical(source_choice, "vp_trade") && isTRUE(isolate(vp_trade_unit_default_pending()))) {
      vp_trade_unit_default_pending(FALSE)
    } else if (!identical(source_choice, "vp_trade") && isTRUE(isolate(vp_trade_unit_default_pending()))) {
      vp_trade_unit_default_pending(FALSE)
    }

    if (identical(source_choice, "psd")) {
      psd_defaults <- resolve_psd_metric_defaults(metric_choice)
      selected_unit <- current_psd_quantity_unit_choice_safe(
        default = psd_defaults$unit_choice,
        metric_code = metric_choice,
        source_choice = source_choice
      )
      selected_unit <- resolve_unit_choice(selected_unit, source_choice, metric_choice)
    }

    if (identical(source_choice, "wasde")) {
      unit_metric_scope <- session$userData$wasde_unit_choice_metric_scope
      input_unit_choice <- input$unit_choice
      input_unit_valid <- !is.null(input_unit_choice) &&
        nzchar(input_unit_choice) &&
        input_unit_choice %in% unname(unit_choices)

      if (!identical(unit_metric_scope, metric_choice) && !input_unit_valid) {
        selected_unit <- default_unit_choice_for_context(source_choice, metric_choice)
      }

      override_unit <- consume_wasde_native_override("unit_choice", unname(unit_choices))
      if (!is.null(override_unit) && nzchar(override_unit)) {
        selected_unit <- override_unit
      }
    }

    if (identical(source_choice, "nass")) {
      unit_metric_scope <- session$userData$nass_unit_choice_metric_scope
      input_unit_choice <- input$unit_choice
      input_unit_valid <- !is.null(input_unit_choice) &&
        nzchar(input_unit_choice) &&
        input_unit_choice %in% unname(unit_choices)

      if (!identical(unit_metric_scope, metric_choice) && !input_unit_valid) {
        selected_unit <- default_unit_choice_for_context(source_choice, metric_choice)
      }
    }

    if (identical(source_choice, "vp_trade") && !is.null(vp_quantity_unit_unavailable_reason)) {
      vp_trade_unit_default_pending(FALSE)
    } else {
      unit_updated <- FALSE
      if (!(input$unit_choice %in% unname(unit_choices)) || !identical(input$unit_choice, selected_unit)) {
        updateSelectInput(
          session,
          "unit_choice",
          choices = unit_choices,
          selected = selected_unit
        )
        unit_updated <- TRUE
      }
      if (isTRUE(force_vp_trade_default_unit) && identical(input$unit_choice, selected_unit)) {
        vp_trade_unit_default_pending(FALSE)
      }
    }
  }, ignoreInit = TRUE)

  observeEvent(list(input$data_source_choice, input$metric_choice, input$census_trade_flow_choice, input$value_unit_choice), {
    source_choice <- if (!is.null(input$data_source_choice)) input$data_source_choice else "export_sales"
    metric_choice <- effective_main_metric()

    if (!show_value_unit_choice(source_choice, metric_choice)) {
      return()
    }

    selected_value_unit <- current_census_value_unit_choice_safe(source_choice = source_choice, metric_code = metric_choice)
    active_value_choices <- unname(value_unit_choices_for_context(source_choice, metric_choice))

    if (identical(source_choice, "wasde")) {
      value_metric_scope <- session$userData$wasde_value_unit_metric_scope
      if (!identical(value_metric_scope, metric_choice)) {
        selected_value_unit <- default_value_unit_choice_for_context(source_choice, metric_choice)
      }

      override_value_unit <- consume_wasde_native_override("value_unit_choice", active_value_choices)
      if (!is.null(override_value_unit) && nzchar(override_value_unit)) {
        selected_value_unit <- override_value_unit
      }
    }

    if (identical(source_choice, "nass")) {
      value_metric_scope <- session$userData$nass_value_unit_metric_scope
      if (!identical(value_metric_scope, metric_choice)) {
        selected_value_unit <- default_value_unit_choice_for_context(source_choice, metric_choice)
      }
    }

    if (
      is.null(input$value_unit_choice) ||
      !(input$value_unit_choice %in% active_value_choices) ||
      !identical(input$value_unit_choice, selected_value_unit)
    ) {
      updateSelectInput(
        session,
        "value_unit_choice",
        choices = value_unit_choices_for_context(source_choice, metric_choice),
        selected = selected_value_unit
      )
      return()
    }

    write_remembered_value_unit_choice(selected_value_unit, source_choice = source_choice)
  }, ignoreInit = TRUE)

  observeEvent(input$unit_choice, {
    source_choice <- if (!is.null(input$data_source_choice)) input$data_source_choice else "export_sales"
    metric_choice <- effective_main_metric()
    valid_choices <- unname(unit_choices_for_context(source_choice, metric_choice))
    vp_pending_target_unit <- if (identical(source_choice, "vp_trade")) {
      vp_trade_pending_default_unit_target(metric_code = metric_choice)
    } else {
      NULL
    }
    unit_scope <- if (identical(source_choice, "psd")) {
      "psd"
    } else if (identical(source_choice, "wasde")) {
      "wasde"
    } else if (identical(source_choice, "nass")) {
      "nass"
    } else {
      "non_psd"
    }

    if (
      identical(source_choice, "vp_trade") &&
      isTRUE(isolate(vp_trade_unit_default_pending())) &&
      !is.null(vp_pending_target_unit) &&
      !identical(input$unit_choice, vp_pending_target_unit)
    ) {
      return()
    }

    if (identical(source_choice, "vp_trade") && isTRUE(isolate(vp_trade_unit_default_pending())) && is.null(vp_pending_target_unit)) {
      vp_trade_unit_default_pending(FALSE)
    }

    if (identical(source_choice, "vp_trade") && !is.null(vp_pending_target_unit) && identical(input$unit_choice, vp_pending_target_unit)) {
      vp_trade_unit_default_pending(FALSE)
    }

    if (!is.null(input$unit_choice) && nzchar(input$unit_choice) && input$unit_choice %in% valid_choices) {
      session$userData$unit_choice_input_scope <- unit_scope

      if (identical(source_choice, "wasde")) {
        session$userData$wasde_unit_choice_metric_scope <- metric_choice
      } else if (identical(source_choice, "nass")) {
        session$userData$nass_unit_choice_metric_scope <- metric_choice
      }
    }

    if (
      identical(source_choice, "psd") &&
      !is.null(input$unit_choice) &&
      nzchar(input$unit_choice) &&
      input$unit_choice %in% valid_choices
    ) {
      session$userData$psd_quantity_unit_choice_state <- input$unit_choice
    }
  }, ignoreInit = TRUE, priority = 100)

  observeEvent(input$psd_area_unit_choice, {
    source_choice <- if (!is.null(input$data_source_choice)) input$data_source_choice else "export_sales"
    if (
      source_choice %in% c("psd", "nass") &&
      !is.null(input$psd_area_unit_choice) &&
      nzchar(input$psd_area_unit_choice) &&
      input$psd_area_unit_choice %in% unname(psd_area_unit_choices)
    ) {
      if (identical(source_choice, "nass")) {
        session$userData$nass_area_unit_choice_state <- input$psd_area_unit_choice
        session$userData$nass_area_unit_metric_scope <- effective_main_metric()
      } else {
        session$userData$psd_area_unit_choice_state <- input$psd_area_unit_choice
      }
    }
  }, ignoreInit = TRUE)

  observeEvent(input$commodity_choice, {
    req(input$commodity_choice)
    source_choice <- current_source_choice_safe()
    active_tab <- current_main_tab_safe()
    basis_choices <- basis_choices_for_commodity(input$commodity_choice, active_tab, source_choice)
    selected_basis <- resolve_basis_choice(
      input$commodity_choice,
      current_basis_choice_safe(default = default_basis_for_commodity(input$commodity_choice, source_choice)),
      active_tab,
      source_choice = source_choice
    )

    if (!(selected_basis %in% unname(basis_choices))) {
      selected_basis <- default_basis_for_commodity(input$commodity_choice, source_choice)
    }

    if (identical(source_choice, "wasde")) {
      override_basis <- consume_wasde_native_override("basis_choice", unname(basis_choices))
      if (!is.null(override_basis) && nzchar(override_basis)) {
        selected_basis <- override_basis
      }
    }

    psd_transition_trace(
      event = "reconcile_basis_choice",
      reason = "basis_reconcile",
      details = list(
        action = "update_basis_choice",
        reconcile_scope = basis_choice_scope_for_source(source_choice),
        commodity = input$commodity_choice,
        active_tab = active_tab,
        choice_count = length(basis_choices)
      ),
      resolved_basis = selected_basis
    )
    mark_pending_programmatic_basis_update(selected_basis, basis_choice_scope_for_source(source_choice))
    updateSelectInput(
      session,
      "basis_choice",
      choices = basis_choices,
      selected = selected_basis
    )
  }, ignoreInit = FALSE)

  observeEvent(input$basis_choice, {
    source_choice <- current_source_choice_safe()
    basis_scope <- basis_choice_scope_for_source(source_choice)
    pending_basis_update <- read_pending_programmatic_basis_update()

    if (
      !is.null(pending_basis_update) &&
      identical(pending_basis_update$scope, basis_scope)
    ) {
      if (identical(input$basis_choice, pending_basis_update$basis)) {
        session$userData$basis_input_scope <- basis_scope
        clear_pending_programmatic_basis_update()
        return()
      }

      clear_pending_programmatic_basis_update()
    }

    commodity_choice <- if (!is.null(input$commodity_choice) && nzchar(input$commodity_choice)) input$commodity_choice else default_commodity_choice_value()
    active_tab <- current_main_tab_safe()
    resolved_basis <- resolve_basis_choice(
      commodity_choice,
      input$basis_choice,
      active_tab,
      source_choice = source_choice
    )
    valid_choices <- unname(basis_choices_for_commodity(commodity_choice, active_tab, source_choice))

    if (resolved_basis %in% valid_choices) {
      psd_transition_trace(
        event = "persist_basis_input",
        reason = "basis_input_persist",
        details = list(
          action = "persist_basis_input",
          persist_scope = basis_scope,
          selected_basis = input$basis_choice,
          resolved_input_basis = resolved_basis
        ),
        resolved_basis = resolved_basis
      )
      write_remembered_basis_choice_state(resolved_basis, basis_scope)
      session$userData$basis_input_scope <- basis_scope
    }
  }, ignoreInit = FALSE, priority = 100)

  observeEvent(list(input$data_source_choice, input$main_tabs_panel, input$commodity_choice, input$basis_choice), {
    req(input$commodity_choice)
    source_choice <- current_source_choice_safe()
     transition_state <- current_psd_source_transition_state()

     if (identical(source_choice, "psd") && !is.null(transition_state)) {
       return()
     }

    basis_scope <- basis_choice_scope_for_source(source_choice)
    active_tab <- current_main_tab_safe()
    basis_choices <- basis_choices_for_commodity(input$commodity_choice, active_tab, source_choice)
    resolved_basis <- resolve_basis_choice(
      input$commodity_choice,
      current_basis_choice_safe(default = default_basis_for_commodity(input$commodity_choice, source_choice)),
      active_tab,
      source_choice = source_choice
    )

    if (identical(source_choice, "wasde")) {
      override_basis <- consume_wasde_native_override("basis_choice", unname(basis_choices))
      if (!is.null(override_basis) && nzchar(override_basis)) {
        resolved_basis <- override_basis
      }
    }

    raw_basis_scope <- session$userData$basis_input_scope

    if (
      !(input$basis_choice %in% unname(basis_choices)) ||
      !identical(input$basis_choice, resolved_basis) ||
      !identical(raw_basis_scope, basis_scope)
    ) {
      write_remembered_basis_choice_state(resolved_basis, basis_scope)
      psd_transition_trace(
        event = "reconcile_basis_choice",
        reason = "basis_reconcile",
        details = list(
          action = "update_basis_choice",
          reconcile_scope = basis_scope,
          selected_basis = input$basis_choice,
          reconciled_basis = resolved_basis,
          raw_scope = raw_basis_scope,
          choice_count = length(basis_choices)
        ),
        resolved_basis = resolved_basis
      )
      mark_pending_programmatic_basis_update(resolved_basis, basis_scope)
      updateSelectInput(
        session,
        "basis_choice",
        choices = basis_choices,
        selected = resolved_basis
      )
    }
  }, ignoreInit = TRUE)
  
  # ============================================================================
  # SELECTED DATA REACTIVE
  # ============================================================================
  # This is the primary data source reactive that all downstream analysis depends on.
  # It performs two critical functions:
  #
  # 1. DATA FREQUENCY SELECTION:
  #    Chooses between monthly or weekly export sales data based on user's toggle.
  #    - Monthly data: Aggregated by calendar month, good for trend analysis
  #    - Weekly data: More granular, shows recent market activity in detail
  #
  # 2. BASIS + UNIT CONVERSION (applied early in pipeline):
  #    Converts metric columns to the selected basis first (using _rough_eq pairs),
  #    then applies unit conversion from Metric Tons. By applying conversion here,
  #    all downstream calculations (projections, summaries, percentages) automatically
  #    use the correct unit+basis without additional logic.
  #
  # This reactive invalidates whenever:
  #    - User changes data frequency (weekly <-> monthly)
  #    - User changes unit of analysis selection
  #    - User changes basis selection
  #    - User changes commodity
  # ============================================================================
  # ISOLATED REACTIVES FOR PERFORMANCE
  # ============================================================================
  
  active_resolved_basis <- reactive({
    req(input$commodity_choice)
    resolve_basis_choice(
      input$commodity_choice,
      current_basis_choice_safe(),
      current_main_tab_safe(),
      source_choice = current_source_choice_safe()
    )
  })

  base_data_converted <- reactive({
    start_time <- Sys.time()
    req(input$commodity_choice)

    source_choice <- current_source_choice_safe()
    data_frequency <- current_data_frequency_safe()
    unit_choice <- current_unit_choice_safe()
    value_unit_choice <- current_census_value_unit_choice_safe(
      source_choice = source_choice,
      metric_code = effective_main_metric()
    )
    census_trade_flow <- if (!is.null(input$census_trade_flow_choice) && input$census_trade_flow_choice %in% c("export", "import")) {
      input$census_trade_flow_choice
    } else {
      "export"
    }
    hybrid_trade_flow <- hybrid_trade_flow_choice()
    hybrid_mode <- if (identical(source_choice, "hybrid")) hybrid_mode_choice() else "n/a"
    year_type_choice <- if (!identical(source_choice, "psd")) {
      current_non_psd_year_type_safe(source_choice = source_choice, default = "marketing")
    } else {
      "marketing"
    }
    census_fiscal_year_runtime_enabled <- isTRUE(startup_census_fiscal_year_enabled("runtime"))
    use_export_sales_weekly_fiscal_data <- identical(source_choice, "export_sales") &&
      identical(data_frequency, "weekly") &&
      identical(year_type_choice, "fiscal")
    use_export_sales_monthly_fiscal_data <- identical(source_choice, "export_sales") &&
      identical(data_frequency, "monthly") &&
      identical(year_type_choice, "fiscal")
    use_census_exports_monthly_fiscal_data <- isTRUE(census_fiscal_year_runtime_enabled) &&
      identical(source_choice, "census") &&
      identical(census_trade_flow, "export") &&
      identical(data_frequency, "monthly") &&
      identical(year_type_choice, "fiscal")
    use_census_imports_monthly_fiscal_data <- isTRUE(census_fiscal_year_runtime_enabled) &&
      identical(source_choice, "census") &&
      identical(census_trade_flow, "import") &&
      identical(data_frequency, "monthly") &&
      identical(year_type_choice, "fiscal")
    use_hybrid_monthly_fiscal_data <- identical(source_choice, "hybrid") &&
      identical(hybrid_trade_flow, "export") &&
      !identical(hybrid_mode, "weekly_imputed") &&
      identical(data_frequency, "monthly") &&
      identical(year_type_choice, "fiscal")
    use_hybrid_import_monthly_fiscal_data <- identical(source_choice, "hybrid") &&
      identical(hybrid_trade_flow, "import") &&
      identical(data_frequency, "monthly") &&
      identical(year_type_choice, "fiscal")
    use_hybrid_weekly_imputed_fiscal_data <- identical(source_choice, "hybrid") &&
      identical(hybrid_trade_flow, "export") &&
      identical(hybrid_mode, "weekly_imputed") &&
      identical(data_frequency, "weekly") &&
      identical(year_type_choice, "fiscal")
    use_preprocessed_monthly_fiscal_data <- isTRUE(use_export_sales_monthly_fiscal_data) ||
      isTRUE(use_census_exports_monthly_fiscal_data) ||
      isTRUE(use_census_imports_monthly_fiscal_data) ||
      isTRUE(use_hybrid_monthly_fiscal_data) ||
      isTRUE(use_hybrid_import_monthly_fiscal_data)
    resolved_basis <- active_resolved_basis()

    record_cache_body_execution(
      session,
      "base_data_converted",
      details = list(
        source = source_choice,
        frequency = data_frequency,
        year_type = year_type_choice,
        commodity = input$commodity_choice %||% NA_character_,
        unit = unit_choice,
        value_unit = if (identical(source_choice, "census")) value_unit_choice else "n/a",
        basis = resolved_basis,
        census_trade_flow = if (identical(source_choice, "census")) census_trade_flow else "n/a",
        hybrid_trade_flow = if (identical(source_choice, "hybrid")) hybrid_trade_flow else "n/a",
        hybrid_mode = hybrid_mode
      )
    )

    # Step 1: Select the appropriate base dataset based on frequency toggle
    dataset_select_start_time <- Sys.time()
    base_data <- if (identical(source_choice, "vp_trade")) {
      vp_rows <- if (exists("vp_trade_rows_for_context", mode = "function")) {
        vp_trade_rows_for_context(require_non_empty = TRUE)
      } else {
        rice_data_vp_trade_monthly
      }
      vp_trade_flow <- vp_trade_flow_choice()
      vp_commodity_name <- input$vp_commodity_name_choice %||% NULL
      vp_commodity_detail <- input$commodity_choice %||% NULL

      vp_rows <- filter_vp_rows_for_resolved_hierarchy(
        vp_rows = vp_rows,
        vp_trade_flow_choice = vp_trade_flow,
        vp_group_choice = input$vp_group_choice,
        vp_subgroup_choice = input$vp_subgroup_choice,
        vp_market_segment_choice = input$vp_market_segment_choice,
        vp_commodity_name_choice = vp_commodity_name,
        vp_commodity_detail_choice = if (!isTRUE(is_myc_type_mode_active())) vp_commodity_detail else NULL,
        vp_filter_purpose = "base_data_converted"
      )

      vp_rows
    } else if (identical(source_choice, "census")) {
      if (isTRUE(use_census_imports_monthly_fiscal_data)) {
        rice_data_census_imports_monthly_fiscal
      } else if (isTRUE(use_census_exports_monthly_fiscal_data)) {
        rice_data_census_monthly_fiscal
      } else if (identical(census_trade_flow, "import")) {
        rice_data_census_imports_monthly
      } else {
        rice_data_census_monthly
      }
    } else if (identical(source_choice, "psd")) {
      rice_data_psd_marketing_year
    } else if (identical(source_choice, "wasde")) {
      rice_data_wasde_marketing_year
    } else if (identical(source_choice, "nass")) {
      rice_data_nass_annual %>%
        filter(.data$annual_year_type == current_nass_annual_year_type_safe(metric_code = effective_main_metric()))
    } else if (identical(source_choice, "hybrid")) {
      if (isTRUE(use_hybrid_import_monthly_fiscal_data)) {
        rice_data_hybrid_import_monthly_fiscal
      } else if (identical(hybrid_trade_flow, "import")) {
        rice_data_hybrid_import_monthly
      } else if (isTRUE(use_hybrid_weekly_imputed_fiscal_data)) {
        rice_data_hybrid_weekly_imputed_fiscal
      } else if (isTRUE(use_hybrid_monthly_fiscal_data)) {
        rice_data_hybrid_monthly_fiscal
      } else if (identical(hybrid_mode, "weekly_imputed")) {
        rice_data_hybrid_weekly_imputed
      } else {
        rice_data_hybrid_monthly
      }
    } else if (isTRUE(use_export_sales_weekly_fiscal_data)) {
      rice_data_weekly_fiscal
    } else if (isTRUE(use_export_sales_monthly_fiscal_data)) {
      rice_data_monthly_fiscal
    } else if (identical(data_frequency, "monthly")) {
      rice_data_monthly
    } else {
      rice_data_weekly
    }
    dataset_select_elapsed_ms <- perf_elapsed_ms(dataset_select_start_time)

    if (identical(source_choice, "wasde") &&
      "normalized_metric_id" %in% names(base_data) &&
      "value_canonical" %in% names(base_data)) {
      wasde_metric_ids <- unique(unname(wasde_metric_catalog$metric_id))
      wasde_metric_ids <- wasde_metric_ids[!is.na(wasde_metric_ids) & nzchar(wasde_metric_ids)]
      wasde_metric_ids <- intersect(wasde_metric_ids, unique(base_data$normalized_metric_id))

      for (metric_id in wasde_metric_ids) {
        metric_values <- ifelse(base_data$normalized_metric_id == metric_id, base_data$value_canonical, NA_real_)
        base_data[[metric_id]] <- sanitize_numeric(metric_values)

        rough_col <- paste0(metric_id, "_rough_eq")
        if (!(rough_col %in% names(base_data))) {
          base_data[[rough_col]] <- base_data[[metric_id]]
        }
      }
    }

    if (identical(source_choice, "nass") &&
      "metric_id" %in% names(base_data) &&
      "value_canonical" %in% names(base_data)) {
      nass_metric_ids <- unique(unname(nass_metric_choices))
      nass_metric_ids <- nass_metric_ids[!is.na(nass_metric_ids) & nzchar(nass_metric_ids)]

      for (metric_id in nass_metric_ids) {
        metric_route <- nass_metric_route_for_code(metric_id)
        metric_row_mask <- nass_metric_route_row_mask(
          source_df = base_data,
          metric_code = metric_id,
          collapse = isTRUE(metric_route$collapse_by_year)
        )

        if (length(metric_row_mask) != nrow(base_data)) {
          metric_row_mask <- rep(FALSE, nrow(base_data))
        }

        metric_values <- ifelse(metric_row_mask, base_data$value_canonical, NA_real_)
        base_data[[metric_id]] <- sanitize_numeric(metric_values)
      }
    }

    numeric_cols <- c("monthlyexports", "ytd_exports", "total_commitment",
                      "outstandingSales", "grossNewSales", "currentMYNetSales",
                      "nextMYOutstandingSales", "nextMYNetSales",
              "monthlyvalue", "ytd_value", "unit_value", "ytd_unit_value",
                      unname(psd_metric_choices),
                      unname(wasde_metric_catalog$metric_id),
                      unname(nass_metric_choices))
    metric_cols <- intersect(numeric_cols, names(base_data))

    # Step 5: Basis transform first, then apply unit conversion.
    basis_unit_start_time <- Sys.time()
    for (metric_col in metric_cols) {
      if (identical(source_choice, "psd") && is_psd_milling_rate_metric(metric_col)) {
        base_data[[metric_col]] <- sanitize_numeric(base_data[[metric_col]])
        next
      }

      if (identical(source_choice, "vp_trade") && metric_col %in% c("unit_value", "ytd_unit_value")) {
        base_data[[metric_col]] <- sanitize_numeric(base_data[[metric_col]])
        next
      }

      if (is_census_value_metric(metric_col, source_choice)) {
        base_data[[metric_col]] <- sanitize_numeric(value_unit_conversion(
          base_data[[metric_col]],
          value_unit_choice,
          source_choice = source_choice,
          metric_code = metric_col
        ))
        next
      }

      if (identical(source_choice, "wasde")) {
        base_data[[metric_col]] <- sanitize_numeric(convert_wasde_display_values(
          values = base_data[[metric_col]],
          metric_code = metric_col,
          unit_choice = unit_choice,
          area_unit_choice = current_psd_area_unit_choice_safe(),
          basis_choice = resolved_basis,
          value_unit_choice = value_unit_choice,
          milling_factors = wasde_default_milling_factor,
          commodity_choice = input$commodity_choice %||% default_commodity_choice_value(),
          active_tab = current_main_tab_safe()
        ))
        next
      }

      if (identical(source_choice, "nass")) {
        base_data[[metric_col]] <- sanitize_numeric(convert_nass_display_values(
          values = base_data[[metric_col]],
          metric_code = metric_col,
          unit_choice = unit_choice,
          area_unit_choice = current_psd_area_unit_choice_safe(
            default_nass_area_unit_choice_for_metric(metric_col),
            source_choice = source_choice,
            metric_code = metric_col
          ),
          basis_choice = resolved_basis,
          value_unit_choice = value_unit_choice,
          years = base_data$calendar_year %||% base_data$market_year,
          countries = base_data$country,
          annual_year_types = base_data$annual_year_type,
          lock_context = "selected_metric"
        ))
        next
      }

      if (identical(source_choice, "vp_trade") && isTRUE(vp_trade_metric_supports_quantity_units(metric_col))) {
        base_data[[metric_col]] <- sanitize_numeric(vp_trade_quantity_unit_conversion(
          value = base_data[[metric_col]],
          unit = unit_choice,
          volume_unit_family = if ("volume_unit_family" %in% names(base_data)) base_data$volume_unit_family else NULL,
          source_volume_unit = if ("source_volume_unit" %in% names(base_data)) base_data$source_volume_unit else NULL,
          vp_volume_family_mixed = if ("vp_volume_family_mixed" %in% names(base_data)) base_data$vp_volume_family_mixed else NULL
        ))
        next
      }

      rough_col <- paste0(metric_col, "_rough_eq")
      rough_values_raw <- if (rough_col %in% names(base_data)) {
        base_data[[rough_col]]
      } else {
        base_data[[metric_col]]
      }

      if (length(rough_values_raw) == 0L) {
        rough_values_raw <- rep(NA_real_, nrow(base_data))
      }

      basis_values <- basis_conversion(
        base_value = base_data[[metric_col]],
        rough_value = rough_values_raw,
        basis_choice = resolved_basis,
        source_choice = source_choice
      )

      converted_values <- unit_conversion(
        basis_values,
        unit_choice,
        source_choice = source_choice,
        metric_code = metric_col,
        area_unit_choice = current_psd_area_unit_choice_safe(),
        basis_choice = resolved_basis,
        value_unit_choice = value_unit_choice
      )
      base_data[[metric_col]] <- sanitize_numeric(converted_values)
    }
    basis_unit_elapsed_ms <- perf_elapsed_ms(basis_unit_start_time)

    fiscal_transform_applied <- FALSE
    fiscal_transform_elapsed_ms <- 0L
    if (!identical(source_choice, "psd") &&
      !identical(source_choice, "nass") &&
      !isTRUE(use_export_sales_weekly_fiscal_data) &&
      !isTRUE(use_hybrid_weekly_imputed_fiscal_data) &&
      !isTRUE(use_preprocessed_monthly_fiscal_data)) {
      fiscal_transform_applied <- TRUE
      fiscal_transform_start_time <- Sys.time()
      base_data <- apply_non_psd_year_type_view(
        df = base_data,
        year_type = year_type_choice,
        frequency = data_frequency,
        source_choice = source_choice
      )
      fiscal_transform_elapsed_ms <- perf_elapsed_ms(fiscal_transform_start_time)
    }
    
    log_perf(
      "base_data_converted()",
      start_time,
      details = c(
        source_switch_epoch_fields(include_age = TRUE),
        list(
        source = source_choice,
        hybrid_mode = hybrid_mode,
        hybrid_trade_flow = if (identical(source_choice, "hybrid")) hybrid_trade_flow else "n/a",
        frequency = data_frequency,
        year_type = year_type_choice,
        unit = unit_choice,
        value_unit = if (source_choice %in% c("census", "wasde")) value_unit_choice else "n/a",
        basis = resolved_basis,
        rows = nrow(base_data),
        metric_cols = length(metric_cols),
        dataset_select_elapsed_ms = dataset_select_elapsed_ms,
        basis_unit_elapsed_ms = basis_unit_elapsed_ms,
        fiscal_transform_applied = fiscal_transform_applied,
        fiscal_transform_elapsed_ms = fiscal_transform_elapsed_ms,
        used_preprocessed_weekly_fiscal = use_export_sales_weekly_fiscal_data,
        used_preprocessed_monthly_fiscal = use_preprocessed_monthly_fiscal_data,
        used_preprocessed_hybrid_weekly_fiscal = use_hybrid_weekly_imputed_fiscal_data
        )
      )
    )
    base_data
  })

  # ============================================================================
  # GLOBAL DATASET REACTIVE
  # ============================================================================
  selected_data <- reactive({
    start_time <- Sys.time()
    base_data_start_time <- Sys.time()
    base_data <- base_data_converted()
    base_data_elapsed_ms <- perf_elapsed_ms(base_data_start_time)
    source_choice <- if (!is.null(input$data_source_choice)) input$data_source_choice else "export_sales"
    
    numeric_cols <- c("monthlyexports", "ytd_exports", "total_commitment",
              "outstandingSales", "grossNewSales", "currentMYNetSales",
              "nextMYOutstandingSales", "nextMYNetSales",
              "monthlyvalue", "ytd_value",
              unname(psd_metric_choices),
              unname(wasde_metric_catalog$metric_id),
              unname(nass_metric_choices))
    metric_cols <- intersect(numeric_cols, names(base_data))
    active_custom_defs <- custom_types_enriched() %>%
      filter(.data$parse_ok) %>%
      filter(purrr::map_lgl(.data$referenced_commodities, ~ length(setdiff(.x, active_native_commodities())) == 0))

    if (identical(source_choice, "nass")) {
      active_custom_defs <- active_custom_defs[0, , drop = FALSE]
    }

    # ONLY materialize custom formulas that are actively displayed in the UI to save massive CPU time
    active_ui_commodities <- unique(c(
      input$commodity_choice,
      panel_state$commodity_right_2up,
      panel_state$commodity_grid_2,
      panel_state$commodity_grid_3,
      panel_state$commodity_grid_4
    ))

    if (isTRUE(is_myc_type_mode_active())) {
      active_ui_commodities <- unique(c(active_ui_commodities, active_custom_defs$custom_name))
    }
    
    active_custom_defs <- active_custom_defs %>%
      filter(.data$custom_name %in% active_ui_commodities)

    record_cache_body_execution(
      session,
      "selected_data",
      details = list(
        source = source_choice,
        metric_cols = length(metric_cols),
        active_commodity_count = length(active_ui_commodities),
        active_custom_defs = nrow(active_custom_defs),
        base_data_elapsed_ms = base_data_elapsed_ms
      )
    )

    materialize_start_time <- Sys.time()
    out <- materialize_custom_commodities(base_data, active_custom_defs, metric_cols)

    log_perf(
      "selected_data(): materialize_custom_commodities",
      materialize_start_time,
      details = c(
        source_switch_epoch_fields(include_age = TRUE),
        list(
        source = source_choice,
        active_custom_defs = nrow(active_custom_defs),
        active_ui_commodities = length(active_ui_commodities),
        base_rows = nrow(base_data),
        out_rows = nrow(out)
        )
      )
    )

    log_perf(
      "selected_data(): total",
      start_time,
      details = c(
        source_switch_epoch_fields(include_age = TRUE),
        list(
        source = source_choice,
        metric_cols = length(metric_cols),
        active_custom_defs = nrow(active_custom_defs),
        base_data_elapsed_ms = base_data_elapsed_ms,
        out_rows = nrow(out)
        )
      )
    )
    out
  })
  
  # ============================================================================
  # COUNTRY SORT UI REACTIVE
  # ============================================================================
  # Dynamically generates the country sorting options in the sidebar.
  # The sort options allow users to reorder the country dropdown list by:
  #   1. Alphabetical order (default)
  #   2. % Difference from Historical Average - ranks countries by how much their
  #      current period's value deviates from their historical average
  #   3. % Difference from Year-End Projection - ranks countries by how much their
  #      projected year-end total differs from historical patterns (only shown for
  #      cumulative metrics like YTD exports and total commitment)
  #
  # The period label (e.g., "in W28" or "in Mar") is dynamically determined from
  # the most recent data point to help users understand what "current period" means.
  # ============================================================================
  country_sort_period_source_data <- function() {
    source_choice <- current_source_choice_safe()
    data_frequency <- current_data_frequency_safe()
    census_trade_flow <- if (!is.null(input$census_trade_flow_choice) && input$census_trade_flow_choice %in% c("export", "import")) {
      input$census_trade_flow_choice
    } else {
      "export"
    }
    hybrid_trade_flow <- hybrid_trade_flow_choice()
    hybrid_mode <- if (identical(source_choice, "hybrid")) hybrid_mode_choice() else "n/a"
    year_type_choice <- if (!identical(source_choice, "psd")) {
      current_non_psd_year_type_safe(source_choice = source_choice, default = "marketing")
    } else {
      "marketing"
    }
    census_fiscal_year_runtime_enabled <- isTRUE(startup_census_fiscal_year_enabled("runtime"))

    use_export_sales_weekly_fiscal_data <- identical(source_choice, "export_sales") &&
      identical(data_frequency, "weekly") &&
      identical(year_type_choice, "fiscal")
    use_export_sales_monthly_fiscal_data <- identical(source_choice, "export_sales") &&
      identical(data_frequency, "monthly") &&
      identical(year_type_choice, "fiscal")
    use_census_exports_monthly_fiscal_data <- isTRUE(census_fiscal_year_runtime_enabled) &&
      identical(source_choice, "census") &&
      identical(census_trade_flow, "export") &&
      identical(data_frequency, "monthly") &&
      identical(year_type_choice, "fiscal")
    use_census_imports_monthly_fiscal_data <- isTRUE(census_fiscal_year_runtime_enabled) &&
      identical(source_choice, "census") &&
      identical(census_trade_flow, "import") &&
      identical(data_frequency, "monthly") &&
      identical(year_type_choice, "fiscal")
    use_hybrid_monthly_fiscal_data <- identical(source_choice, "hybrid") &&
      identical(hybrid_trade_flow, "export") &&
      !identical(hybrid_mode, "weekly_imputed") &&
      identical(data_frequency, "monthly") &&
      identical(year_type_choice, "fiscal")
    use_hybrid_import_monthly_fiscal_data <- identical(source_choice, "hybrid") &&
      identical(hybrid_trade_flow, "import") &&
      identical(data_frequency, "monthly") &&
      identical(year_type_choice, "fiscal")
    use_hybrid_weekly_imputed_fiscal_data <- identical(source_choice, "hybrid") &&
      identical(hybrid_trade_flow, "export") &&
      identical(hybrid_mode, "weekly_imputed") &&
      identical(data_frequency, "weekly") &&
      identical(year_type_choice, "fiscal")

    if (identical(source_choice, "vp_trade")) {
      vp_rows <- if (exists("vp_trade_rows_for_context", mode = "function")) {
        vp_trade_rows_for_context(require_non_empty = TRUE)
      } else {
        rice_data_vp_trade_monthly
      }
      vp_trade_flow <- vp_trade_flow_choice()
      vp_commodity_name <- input$vp_commodity_name_choice %||% NULL
      vp_commodity_detail <- input$commodity_choice %||% NULL

      vp_rows <- filter_vp_rows_for_resolved_hierarchy(
        vp_rows = vp_rows,
        vp_trade_flow_choice = vp_trade_flow,
        vp_group_choice = input$vp_group_choice,
        vp_subgroup_choice = input$vp_subgroup_choice,
        vp_market_segment_choice = input$vp_market_segment_choice,
        vp_commodity_name_choice = vp_commodity_name,
        vp_commodity_detail_choice = vp_commodity_detail,
        vp_filter_purpose = "filtered_data"
      )

      vp_rows
    } else if (identical(source_choice, "census")) {
      if (isTRUE(use_census_imports_monthly_fiscal_data)) {
        rice_data_census_imports_monthly_fiscal
      } else if (isTRUE(use_census_exports_monthly_fiscal_data)) {
        rice_data_census_monthly_fiscal
      } else if (identical(census_trade_flow, "import")) {
        rice_data_census_imports_monthly
      } else {
        rice_data_census_monthly
      }
    } else if (identical(source_choice, "psd")) {
      rice_data_psd_marketing_year
    } else if (identical(source_choice, "wasde")) {
      rice_data_wasde_marketing_year
    } else if (identical(source_choice, "hybrid")) {
      if (isTRUE(use_hybrid_import_monthly_fiscal_data)) {
        rice_data_hybrid_import_monthly_fiscal
      } else if (identical(hybrid_trade_flow, "import")) {
        rice_data_hybrid_import_monthly
      } else if (isTRUE(use_hybrid_weekly_imputed_fiscal_data)) {
        rice_data_hybrid_weekly_imputed_fiscal
      } else if (isTRUE(use_hybrid_monthly_fiscal_data)) {
        rice_data_hybrid_monthly_fiscal
      } else if (identical(hybrid_mode, "weekly_imputed")) {
        rice_data_hybrid_weekly_imputed
      } else {
        rice_data_hybrid_monthly
      }
    } else if (isTRUE(use_export_sales_weekly_fiscal_data)) {
      rice_data_weekly_fiscal
    } else if (isTRUE(use_export_sales_monthly_fiscal_data)) {
      rice_data_monthly_fiscal
    } else if (identical(data_frequency, "monthly")) {
      rice_data_monthly
    } else {
      rice_data_weekly
    }
  }

  country_sort_period_commodities <- function(commodity_choice) {
    native_commodities <- active_native_commodities()
    if (commodity_choice %in% native_commodities) {
      return(commodity_choice)
    }

    custom_def <- custom_types_enriched() %>%
      filter(.data$parse_ok, .data$custom_name == commodity_choice)
    if (nrow(custom_def) != 1) {
      return(character(0))
    }

    referenced_commodities <- unique(unlist(custom_def$referenced_commodities, use.names = FALSE))
    if (length(referenced_commodities) == 0 || length(setdiff(referenced_commodities, native_commodities)) > 0) {
      return(character(0))
    }

    referenced_commodities
  }

  country_sort_latest_period_label <- function(commodity_choice) {
    source_df <- country_sort_period_source_data()
    required_cols <- c("commodity", "market_year", "analysis_month")
    if (is.null(source_df) || !all(required_cols %in% names(source_df))) {
      return("")
    }

    period_commodities <- country_sort_period_commodities(commodity_choice)
    if (length(period_commodities) == 0) {
      return("")
    }

    df <- source_df %>%
      filter(.data$commodity %in% period_commodities)
    if (nrow(df) == 0) {
      return("")
    }

    recent_year <- suppressWarnings(max(df$market_year, na.rm = TRUE))
    if (!is.finite(recent_year)) {
      return("")
    }

    recent_data <- df %>% filter(.data$market_year == recent_year)
    if (nrow(recent_data) == 0) {
      return("")
    }

    most_recent_period <- suppressWarnings(max(recent_data$analysis_month, na.rm = TRUE))
    if (!is.finite(most_recent_period)) {
      return("")
    }

    if (identical(input$data_frequency, "weekly")) {
      return(paste0(" (in W", most_recent_period, ")"))
    }

    source_choice <- current_source_choice_safe()
    display_year_type <- if (identical(source_choice, "psd")) {
      "marketing"
    } else {
      current_non_psd_year_type_safe(source_choice = source_choice, default = "marketing")
    }

    display_month_mapping <- if (exists("current_display_month_mapping", mode = "function")) {
      current_display_month_mapping(source_choice = source_choice)
    } else {
      month_mapping_for_year_type(display_year_type)
    }

    month_abbrev <- display_month_mapping %>%
      filter(.data$analysis_month == suppressWarnings(as.integer(most_recent_period))) %>%
      pull(.data$month_abbrev)

    if (length(month_abbrev) == 1 && !is.na(month_abbrev) && nzchar(month_abbrev)) {
      paste0(" (in ", month_abbrev, ")")
    } else {
      paste0(" (in P", most_recent_period, ")")
    }
  }

  build_country_sort_ui <- function(myc_active) {
    req(input$data_frequency)
    myc_type_mode_active <- identical(input$main_tabs_panel, "Market Year Comparison Tool") &&
      identical(market_year_comparison_mode(), "type")
    myc_sort_label <- if (isTRUE(myc_type_mode_active)) "Sort Types By:" else "Sort Countries By:"

    period_label <- ""
    if (!isTRUE(myc_active)) {
      req(input$commodity_choice)
      period_label <- country_sort_latest_period_label(input$commodity_choice)
    }
    
    # Preserve current selection
    current_sort <- if (!is.null(input$country_sort)) input$country_sort else "value"
    # Map old values to new consolidated value
    if (current_sort %in% c("proj_diff", "linear_proj_diff")) {
      current_sort <- "proj_diff"
    }
    
    # Preserve projection type selection
    current_proj_type <- if (!is.null(input$proj_sort_type)) input$proj_sort_type else "historical"

    if (isTRUE(myc_active)) {
      sort_choices <- c("alpha", "value")
      names(sort_choices) <- c("Alphabetical", "Current Share (latest period)")

      if (!(current_sort %in% sort_choices)) {
        current_sort <- "value"
      }

      return(
        div(
          style = "margin-top: 8px; margin-bottom: 8px;",
          radioButtons(
            inputId = "country_sort",
            label = myc_sort_label,
            choices = sort_choices,
            selected = current_sort,
            inline = FALSE
          )
        )
      )
    }
    
    # Determine if projections are available (only for cumulative metrics)
    cumulative_metrics <- c("ytd_exports", "total_commitment")
    metric <- effective_main_metric()
    has_projections <- length(metric) > 0 && metric %in% cumulative_metrics
    
    # Build choices - only include projection sort if metric supports it
    sort_choices <- if (has_projections) {
      c("alpha", "value", "pct_diff", "proj_diff")
    } else {
      c("alpha", "value", "pct_diff")
    }

    # Build labels
    pct_diff_label <- paste0("% Diff from Historical Avg", period_label)
    if (has_projections) {
      names(sort_choices) <- c("Alphabetical", "Current Value (latest period)", pct_diff_label, "% Diff from Year-End Projection")
    } else {
      names(sort_choices) <- c("Alphabetical", "Current Value (latest period)", pct_diff_label)
    }
    
    # Reset sort selection if it's no longer available
    if (!(current_sort %in% sort_choices)) {
      current_sort <- "value"
    }
    
    div(
      style = "padding: 8px; background-color: #f5f5f5; border-radius: 5px; margin-bottom: 10px;",
      radioButtons(
        inputId = "country_sort",
        label = "Sort Countries By:",
        choices = sort_choices,
        selected = current_sort,
        inline = FALSE
      ),
      
      # Conditional dropdown for projection type (only when proj_diff is selected and available)
      if (has_projections) {
        conditionalPanel(
          condition = "input.country_sort == 'proj_diff'",
          div(
            style = "margin-left: 20px; margin-top: -5px;",
            selectInput(
              inputId = "proj_sort_type",
              label = "Projection Type:",
              choices = c(
                "Historical Pattern" = "historical",
                "Linear Fit" = "linear"
              ),
              selected = current_proj_type,
              width = "200px"
            )
          )
        )
      },
      
      # Conditional checkbox for reverse sort (pct_diff, proj_diff, value)
      conditionalPanel(
        condition = "input.country_sort == 'pct_diff' || input.country_sort == 'proj_diff' || input.country_sort == 'value'",
        checkboxInput(
          inputId = "reverse_sort",
          label = "Show lowest values first",
          value = FALSE
        )
      )
    )
  }

  output$standard_country_sort_ui <- renderUI({
    if (identical(input$main_tabs_panel, "Market Year Comparison Tool")) {
      return(NULL)
    }

    build_country_sort_ui(myc_active = FALSE)
  })

  output$myc_country_sort_ui <- renderUI({
    if (!identical(input$main_tabs_panel, "Market Year Comparison Tool")) {
      return(NULL)
    }

    build_country_sort_ui(myc_active = TRUE)
  })
  
  # Reactive: render metric choice UI based on frequency
  observeEvent(input$psd_yield_lock_rough_eq, {
    session$userData$psd_yield_lock_state <- isTRUE(input$psd_yield_lock_rough_eq)
  }, ignoreInit = FALSE)

  observeEvent(input$wasde_price_lock_native_rate, {
    session$userData$wasde_price_lock_state <- isTRUE(input$wasde_price_lock_native_rate)
  }, ignoreInit = FALSE)

  observeEvent(input$wasde_yield_lock_rough_eq, {
    session$userData$wasde_yield_lock_state <- isTRUE(input$wasde_yield_lock_rough_eq)
  }, ignoreInit = FALSE)

  observeEvent(input$nass_yield_lock_enabled, {
    session$userData$nass_yield_lock_state <- isTRUE(input$nass_yield_lock_enabled)
  }, ignoreInit = FALSE)

  observeEvent(input$nass_price_lock_enabled, {
    session$userData$nass_price_lock_state <- isTRUE(input$nass_price_lock_enabled)
  }, ignoreInit = FALSE)

  output$metric_choice_ui <- renderUI({
    base_choices <- metric_choices_for_current_context()
    selected_metric <- effective_main_metric()
    source_choice <- if (!is.null(input$data_source_choice)) input$data_source_choice else "export_sales"
    show_psd_yield_lock <- identical(source_choice, "psd") &&
      identical(selected_metric, "psd_yield") &&
      !is_psd_time_series_tool_active(source_choice)

    if (!source_choice %in% c("psd", "wasde", "nass")) {
      metric_controls <- radioButtons(
        inputId = "metric_choice",
        label = "Variable to Analyze:",
        choices = base_choices,
        selected = selected_metric
      )

      if (identical(current_main_tab_safe(), "Market Year Comparison Tool")) {
        return(
          div(
            class = "myc-metric-choice-aligner",
            style = "padding: 0 8px;",
            metric_controls
          )
        )
      }

      return(metric_controls)
    }

    choice_labels <- names(base_choices)
    choice_values <- unname(base_choices)

    metric_options <- lapply(seq_along(choice_values), function(idx) {
      choice_value <- choice_values[[idx]]
      choice_label <- choice_labels[[idx]]
      option_class <- switch(
        source_choice,
        "wasde" = "wasde-metric-option-row",
        "nass" = "nass-metric-option-row",
        "psd-metric-option-row"
      )

      div(
        class = paste("radio", option_class),
        tags$label(
          tags$input(
            type = "radio",
            name = "metric_choice",
            value = choice_value,
            checked = if (identical(choice_value, selected_metric)) "checked" else NULL
          ),
          tags$span(choice_label)
        ),
        if (identical(choice_value, "psd_yield") && isTRUE(show_psd_yield_lock)) {
          div(
            class = "psd-yield-lock-under-option",
            checkboxInput(
              inputId = "psd_yield_lock_rough_eq",
              label = "Lock Yield Basis to Rough-equivalent",
              value = current_psd_yield_lock_input_safe()
            )
          )
        },
        if (identical(source_choice, "wasde") && identical(choice_value, selected_metric) && is_wasde_price_lock_metric(choice_value)) {
          div(
            class = "wasde-price-lock-under-option",
            checkboxInput(
              inputId = "wasde_price_lock_native_rate",
              label = wasde_price_lock_label(choice_value),
              value = current_wasde_price_lock_input_safe()
            )
          )
        },
        if (identical(source_choice, "wasde") && identical(choice_value, selected_metric) && is_wasde_yield_lock_metric(choice_value)) {
          div(
            class = "wasde-yield-lock-under-option",
            checkboxInput(
              inputId = "wasde_yield_lock_rough_eq",
              label = wasde_yield_lock_label(),
              value = current_wasde_yield_lock_input_safe()
            )
          )
        },
        if (identical(source_choice, "nass") && identical(choice_value, selected_metric) && is_nass_yield_lock_metric(choice_value)) {
          div(
            class = "nass-yield-lock-under-option",
            checkboxInput(
              inputId = "nass_yield_lock_enabled",
              label = nass_yield_lock_label(choice_value),
              value = current_nass_yield_lock_input_safe()
            )
          )
        },
        if (identical(source_choice, "nass") && identical(choice_value, selected_metric) && is_nass_price_lock_metric(choice_value)) {
          div(
            class = "nass-price-lock-under-option",
            checkboxInput(
              inputId = "nass_price_lock_enabled",
              label = nass_price_lock_label(choice_value),
              value = current_nass_price_lock_input_safe()
            )
          )
        }
      )
    })

    div(
      id = "metric_choice",
      class = paste(
        "form-group shiny-input-radiogroup shiny-input-container",
        switch(
          source_choice,
          "wasde" = "wasde-metric-choice-group",
          "nass" = "nass-metric-choice-group",
          "psd-metric-choice-group"
        )
      ),
      tags$label(
        class = "control-label",
        id = "metric_choice-label",
        `for` = "metric_choice",
        "Variable to Analyze:"
      ),
      div(
        class = "shiny-options-group",
        role = "radiogroup",
        `aria-labelledby` = "metric_choice-label",
        tagList(metric_options)
      )
    )
  })

  output$vp_ytd_unit_value_overlay_control <- renderUI({
    source_choice <- current_source_choice_safe(default = input$data_source_choice %||% "export_sales")
    if (!identical(source_choice, "vp_trade")) return(NULL)
    if (!identical(input$data_frequency %||% "monthly", "monthly")) return(NULL)
    if (!identical(effective_main_metric(), "unit_value")) return(NULL)

    vp_rows <- tryCatch(filtered_data(), error = function(...) data.frame())
    if (!is.data.frame(vp_rows) || !("ytd_unit_value" %in% names(vp_rows))) return(NULL)
    ytd_values <- suppressWarnings(as.numeric(vp_rows$ytd_unit_value))
    if (!any(is.finite(ytd_values), na.rm = TRUE)) return(NULL)

    checkboxInput(
      inputId = "show_ytd_unit_value_overlay",
      label = "Show accumulated unit value",
      value = isTRUE(input$show_ytd_unit_value_overlay)
    )
  })

  # Dynamic main tabset, including Country Comparison when weekly is selected
  output$main_tabs <- renderUI({
    start_time <- Sys.time()
    main_tabs_render_generation <- main_tabs_render_nonce()
    source_choice_for_log <- if (!is.null(input$data_source_choice)) input$data_source_choice else "export_sales"
    frequency_for_log <- isolate(input$data_frequency)
    selected_tab <- target_main_tab_for_source(isolate(input$main_tabs_panel), source_choice_for_log)
    show_non_psd_tabs <- !(source_choice_for_log %in% c("psd", "wasde", "nass"))

    tabs <- list()

    if (show_non_psd_tabs) {
      tabs <- c(
        tabs,
        list(
          tabPanel(
            title = "Current vs. Historical",
            value = "Current vs. Average",
            uiOutput("comparison_title"),
            uiOutput("vp_ytd_unit_value_overlay_control"),
            plotlyOutput("comparison_plot", height = "500px"),
            uiOutput("comparison_hist_note"),
            hr(),
            div(
              style = "margin: 20px 0 10px 0;",
              h3("Summary Statistics", style = "margin-bottom: 6px;"),
              div(
                style = "display: flex; align-items: center; gap: 6px; flex-wrap: wrap;",
                actionButton(
                  inputId = "summary_digits_decrease",
                  label = NULL,
                  icon = icon("minus"),
                  class = "btn-default btn-sm",
                  title = "Decrease summary table decimals",
                  `aria-label` = "Decrease summary table decimals"
                ),
                actionButton(
                  inputId = "summary_digits_increase",
                  label = NULL,
                  icon = icon("plus"),
                  class = "btn-default btn-sm",
                  title = "Increase summary table decimals",
                  `aria-label` = "Increase summary table decimals"
                ),
                span(
                  textOutput("summary_digits_display", inline = TRUE),
                  style = "font-size: 12px; color: #555; margin-left: 4px;"
                )
              ),
              uiOutput("comparison_reference_week_shift_ui")
            ),
            dataTableOutput("summary_table")
          ),
          tabPanel(
            title = "Historical Trendlines",
            value = "Historical Trend",
            h3("Time Series: All Years in Dataset"),
            plotlyOutput("timeseries_plot", height = "500px"),
            uiOutput("historical_trend_note"),
            tags$style(HTML("\n            #historical-trend-controls {\n              display: flex;\n              align-items: flex-start;\n              gap: 16px;\n              flex-wrap: wrap;\n            }\n            #historical-trend-controls .form-group { margin-bottom: 0; }\n            #historical-trend-controls .control-label { margin-bottom: 6px; }\n            #historical-trend-controls .checkbox { margin-top: 0; margin-bottom: 6px; }\n            #historical-trend-controls .checkbox:last-child { margin-bottom: 0; }\n            #historical-trend-years { min-width: 300px; }\n            #historical-trend-display-options { min-width: 300px; }\n          ")),
            div(
              id = "historical-trend-controls",
              div(
                id = "historical-trend-years",
                checkboxGroupInput(
                  inputId = "year_filter",
                  label = "Select Years to Display:",
                  choices = NULL,
                  inline = TRUE
                )
              ),
              div(
                id = "historical-trend-display-options",
                class = "form-group",
                tags$label(class = "control-label", "Display Options:"),
                conditionalPanel(
                  condition = "(input.metric_choice != 'ytd_exports' && input.metric_choice != 'total_commitment') || input.projection_basis_mode != 'single_year'",
                  checkboxInput(
                    inputId = "show_hist_avg",
                    label = "Show Historical Average",
                    value = TRUE,
                    width = "100%"
                  )
                ),
                checkboxInput(
                  inputId = "emphasize_current_avg",
                  label = "Emphasize Current MY + Historical Avg",
                  value = FALSE,
                  width = "100%"
                )
              )
            )
          )
        )
      )
    }

    # Tab 3: Map
    if (!(source_choice_for_log %in% c("wasde", "nass"))) {
      tabs <- c(
        tabs,
        list(
          tabPanel(
            title = "Map",
            value = "Map",
            plotlyOutput("map_plot", height = "480px"),
            uiOutput("map_note_block"),
            hr(style = "margin: 8px 0;"),
            uiOutput("map_bottom_panel_ui")
          )
        )
      )
    }

    if (source_choice_for_log %in% c("psd", "wasde", "nass")) {
      annual_time_series_header <- if (identical(source_choice_for_log, "wasde")) {
        "Annual Time Series: WASDE Annual Values by Market Year"
      } else if (identical(source_choice_for_log, "nass")) {
        "Annual Time Series: NASS QuickStats Commodity Values"
      } else {
        "Annual Time Series: Latest PSD Estimate by Market Year"
      }

      tabs <- c(
        tabs,
        list(
          tabPanel(
            title = "Time Series Analysis Tool",
            value = "Time Series Analysis Tool",
            h3(annual_time_series_header),
              plotlyOutput("psd_time_series_plot", height = "500px"),
              uiOutput("psd_time_series_note_block"),
              hr(style = "margin: 8px 0;"),
              uiOutput("psd_time_series_bottom_panel_ui")
          )
        )
      )
    }

    # Tab 4: Heatmap
    if (show_non_psd_tabs) {
      tabs <- c(
        tabs,
        list(
          tabPanel(
            title = uiOutput("heatmap_tab_title"),
            value = "Heatmap",
            h3("Year vs. Period Matrix"),
            plotlyOutput("heatmap_plot", height = "600px"),
            uiOutput("heatmap_note_block")
          )
        )
      )
    }

    if (show_non_psd_tabs) {
      tabs <- c(
        tabs,
        list(
          tabPanel(
            title = "Data",
            value = "Data",
            h3("Filtered Dataset"),
            actionButton(
              inputId = "publish_filtered_data",
              label = "Publish Data",
              class = "btn-primary"
            ),
            div(style = "height: 12px;"),
            dataTableOutput("raw_data_table")
          )
        )
      )
    }

    if (source_choice_for_log %in% c("census", "hybrid")) {
      tabs <- c(
        tabs,
        list(
          tabPanel(
            "Census Corrections",
            h3("Census Corrections Workspace"),
            uiOutput("census_corrections_status_ui"),
            fluidRow(
              column(
                width = 4,
                div(
                  style = "padding: 12px; background-color: #f8f9fa; border: 1px solid #d9dee3; border-radius: 6px;",
                  h4("Correction Form"),
                  uiOutput("census_correction_form_context_ui"),
                  div(style = "height: 10px;"),
                  selectInput("census_correction_country_select", "Country:", choices = character(0)),
                  selectInput("census_correction_hs_code_select", "HS Code:", choices = character(0)),
                  fluidRow(
                    column(6, numericInput("census_correction_start_month", "Start Month:", value = 1, min = 1, max = 12, step = 1)),
                    column(6, numericInput("census_correction_start_year", "Start Year:", value = as.integer(format(Sys.Date(), "%Y")), min = 2000, max = 2100, step = 1))
                  ),
                  fluidRow(
                    column(6, numericInput("census_correction_end_month", "End Month:", value = 1, min = 1, max = 12, step = 1)),
                    column(6, numericInput("census_correction_end_year", "End Year:", value = as.integer(format(Sys.Date(), "%Y")), min = 2000, max = 2100, step = 1))
                  ),
                  numericInput("census_correction_volume", "Volume:", value = NA_real_),
                  selectInput(
                    "census_correction_unit",
                    "Unit:",
                    choices = c("Metric Tons" = "mt", "Kilograms" = "kg", "Pounds" = "lbs", "CWT" = "cwt", "US Tons" = "us_tons"),
                    selected = "mt"
                  ),
                  selectInput(
                    "census_correction_equivalent",
                    "Equivalent:",
                    choices = c("Unadjusted" = "unadjusted", "Rough-equivalent" = "rough_eq"),
                    selected = "unadjusted"
                  ),
                  textAreaInput("census_correction_reason", "Reason:", value = "", rows = 3, width = "100%"),
                  div(
                    style = "display: flex; gap: 8px; flex-wrap: wrap;",
                    actionButton("save_census_correction_btn", "Save / Update Correction", class = "btn-primary"),
                    actionButton("new_census_correction_btn", "Clear Form", class = "btn-default"),
                    actionButton("edit_active_census_correction_btn", "Edit Selected Active", class = "btn-default")
                  ),
                  uiOutput("census_correction_validation_errors_ui"),
                  uiOutput("census_correction_preview_ui")
                )
              ),
              column(
                width = 8,
                h4("Active Corrections"),
                div(
                  style = "margin-bottom: 8px; display: flex; gap: 8px; flex-wrap: wrap;",
                  actionButton("archive_active_corrections_btn", "Archive Selected Active", class = "btn-warning")
                ),
                dataTableOutput("active_census_corrections_table"),
                div(style = "height: 16px;"),
                uiOutput("census_corrections_audit_section_header_ui"),
                uiOutput("census_corrections_audit_section_body_ui"),
                div(style = "height: 24px;"),
                uiOutput("archived_census_corrections_section_header_ui"),
                uiOutput("archived_census_corrections_section_body_ui")
              )
            )
          )
        )
      )
    }

    # Tab 5: Custom Comparison Tool (available for both weekly and monthly)
    if (show_non_psd_tabs) {
      tabs <- c(
        tabs,
        list(
          tabPanel(
            "Custom Comparison Tool",
          fluidRow(
            column(
              width = 12,
              div(
                h4("Custom Comparison Tool Views"),
                tags$style(HTML("\n                  .custom-comparison-header {\n                    display: flex;\n                    align-items: flex-start;\n                    --custom-comp-row-height: 34px;\n                    --custom-comp-row-gap: 8px;\n                    --custom-comp-title-offset: 26px;\n                    gap: 20px;\n                    flex-wrap: wrap;\n                    margin-bottom: 12px;\n                  }\n                  .custom-comparison-quick-apply {\n                    display: flex;\n                    flex-direction: column;\n                    padding: 10px 12px;\n                    min-width: 332px;\n                    border: 1px solid #d9dee3;\n                    border-radius: 6px;\n                    background-color: #f8f9fa;\n                  }\n                  .custom-comparison-quick-apply-title {\n                    font-size: 12px;\n                    font-weight: 600;\n                    text-transform: uppercase;\n                    letter-spacing: 0.04em;\n                    color: #495057;\n                    margin-bottom: 2px;\n                  }\n                  .custom-comparison-quick-apply-body {\n                    display: grid;\n                    grid-template-rows: repeat(2, minmax(var(--custom-comp-row-height), auto));\n                    row-gap: var(--custom-comp-row-gap);\n                  }\n                  .custom-comparison-quick-apply-row {\n                    display: flex;\n                    align-items: center;\n                    gap: 8px;\n                    flex-wrap: nowrap;\n                    min-height: var(--custom-comp-row-height);\n                  }\n                  .custom-comparison-quick-apply-row .btn {\n                    min-width: 146px;\n                  }\n                  .custom-comparison-checkbox-stack {\n                    display: grid;\n                    grid-template-rows: repeat(2, minmax(var(--custom-comp-row-height), auto));\n                    row-gap: var(--custom-comp-row-gap);\n                    min-width: 0;\n                    align-items: flex-start;\n                    margin-top: var(--custom-comp-title-offset);\n                  }\n                  .custom-comparison-checkbox-row {\n                    display: flex;\n                    align-items: center;\n                    gap: 16px;\n                    flex-wrap: wrap;\n                    min-height: var(--custom-comp-row-height);\n                  }\n                  .custom-comparison-checkbox-row-top {\n                    display: inline-flex;\n                    width: auto;\n                    gap: 16px;\n                    flex-wrap: nowrap;\n                    align-self: flex-start;\n                  }\n                  .custom-comparison-checkbox-row-top > div {\n                    flex: 0 0 auto;\n                    width: auto;\n                  }\n                  .custom-comparison-checkbox-row-top .shiny-input-container {\n                    width: auto;\n                  }\n                  .custom-comparison-checkbox-row-top .checkbox {\n                    margin-top: 0;\n                    margin-bottom: 0;\n                    white-space: nowrap;\n                  }\n                  .custom-comparison-checkbox-row .checkbox {\n                    margin-top: 0;\n                    margin-bottom: 0;\n                    display: flex;\n                    align-items: center;\n                    min-height: var(--custom-comp-row-height);\n                  }\n                  .custom-comparison-checkbox-row .checkbox label {\n                    display: flex;\n                    align-items: center;\n                    margin-bottom: 0;\n                    min-height: var(--custom-comp-row-height);\n                  }\n                  .custom-comparison-checkbox-row .form-group {\n                    margin-bottom: 0;\n                  }\n                  @media (max-width: 860px) {\n                    .custom-comparison-checkbox-stack {\n                      margin-top: 0;\n                    }\n                  }\n                ")),
                div(
                  class = "custom-comparison-header",
                  div(
                    class = "custom-comparison-quick-apply",
                    div(
                      class = "custom-comparison-quick-apply-title",
                      "Quick Apply Side and Top Bar Selection"
                    ),
                    div(
                      class = "custom-comparison-quick-apply-body",
                      div(
                        class = "custom-comparison-quick-apply-row",
                        actionButton(
                          inputId = "custom_comp_apply_top_commodity",
                          label = "Apply Commodity",
                          class = "btn-default btn-sm"
                        ),
                        actionButton(
                          inputId = "custom_comp_apply_sidebar_type",
                          label = "Apply Type",
                          class = "btn-default btn-sm"
                        )
                      ),
                      div(
                        class = "custom-comparison-quick-apply-row",
                        actionButton(
                          inputId = "custom_comp_apply_sidebar_country",
                          label = "Apply Country",
                          class = "btn-default btn-sm"
                        ),
                        actionButton(
                          inputId = "custom_comp_apply_sidebar_variable",
                          label = "Apply Variable",
                          class = "btn-default btn-sm"
                        )
                      ),
                      div(
                        class = "custom-comparison-quick-apply-row",
                        actionButton(
                          inputId = "custom_comp_apply_top_partners",
                          label = "Top 3 Partners",
                          class = "btn-default btn-sm"
                        ),
                        actionButton(
                          inputId = "custom_comp_reset_defaults",
                          label = "Reset Defaults",
                          class = "btn-default btn-sm"
                        )
                      )
                    )
                  ),
                  div(
                    class = "custom-comparison-checkbox-stack",
                    div(
                      class = "custom-comparison-checkbox-row custom-comparison-checkbox-row-top",
                      div(
                        checkboxInput(
                          inputId = "lock_to_top_left_scale",
                          label = "Match all panel scales",
                          value = FALSE
                        )
                      ),
                      conditionalPanel(
                        condition = "input.lock_to_top_left_scale == true",
                        div(
                          checkboxInput(
                            inputId = "overlay_visible_panels",
                            label = "Overlay visible panels in one chart",
                            value = FALSE
                          )
                        )
                      )
                    ),
                    div(
                      class = "custom-comparison-checkbox-row",
                      div(
                        checkboxInput(
                          inputId = "show_metric_grid",
                          label = "4-panel grid (2x2)",
                          value = TRUE
                        )
                      )
                    )
                  )
                )
              )
            )
          ),
          uiOutput("metric_comparison_hist_note"),
          uiOutput("metric_comparison_body")
          )
        )
      )
    }

    # Tab 6: Market Year Comparison Tool (Top 5 + All Other)
    if (show_non_psd_tabs) {
      tabs <- c(
        tabs,
        list(
          tabPanel(
            "Market Year Comparison Tool",
            h3("Market Year Comparison Tool"),
            checkboxInput(
              inputId = "show_partner_shares",
              label = "Display share labels on bars",
              value = FALSE,
              width = "200px"
            ),
            div(
              style = "margin-top: -6px;",
              checkboxInput(
                inputId = "show_partner_values",
                label = "Display value labels on bars",
                value = FALSE,
                width = "240px"
              )
            ),
            div(
              style = "margin-top: -6px;",
              checkboxInput(
                inputId = "myc_order_by_latest_market_year",
                label = "Use most recent market year for ordering",
                value = FALSE,
                width = "320px"
              )
            ),
            uiOutput("partner_share_warning"),
            div(
              id = "partner_share_plot_scroll_container",
              class = "myct-plot-scroll-container",
              style = "width: 100%; overflow-x: auto; overflow-y: visible; padding-bottom: 12px; -webkit-overflow-scrolling: touch;",
              div(
                id = "partner_share_plot_width_container",
                class = "myct-plot-width-container",
                style = "min-width: 100%; width: 100%;",
                plotlyOutput("partner_share_plot", width = "100%", height = "600px")
              )
            ),
            uiOutput("partner_share_hist_note"),
            hr(style = "margin: 14px 0 10px 0;"),
            div(
              style = "margin: 10px 0 10px 0;",
              h3("Market Year Table", style = "margin-bottom: 6px;"),
              div(
                class = "myc-table-controls",
                style = "display: flex; flex-direction: column; align-items: stretch; gap: 4px; margin-bottom: 8px;",
                div(
                  class = "myc-table-measure-row",
                  style = "display: flex; align-items: center; gap: 10px; flex-wrap: wrap;",
                  radioButtons(
                    inputId = "myc_table_measure_mode",
                    label = NULL,
                    choices = c("Values" = "value", "Shares" = "share"),
                    selected = "value",
                    inline = TRUE
                  )
                ),
                div(
                  class = "myc-table-comparison-row",
                  style = "display: flex; align-items: center; gap: 10px; flex-wrap: wrap; margin-top: -2px;",
                  radioButtons(
                    inputId = "myc_table_comparison_mode",
                    label = NULL,
                    choices = c("Current" = "current", "Comparison" = "comparison"),
                    selected = "current",
                    inline = TRUE
                  )
                ),
                div(
                  class = "myc-table-action-row",
                  style = "display: flex; align-items: center; justify-content: space-between; gap: 10px; flex-wrap: wrap;",
                  div(
                    class = "myc-table-decimal-row",
                    style = "display: flex; align-items: center; gap: 6px; flex-wrap: wrap;",
                    actionButton(
                      inputId = "myc_table_digits_decrease",
                      label = NULL,
                      icon = icon("minus"),
                      class = "btn-default btn-sm",
                      title = "Decrease market year table decimals",
                      `aria-label` = "Decrease market year table decimals"
                    ),
                    actionButton(
                      inputId = "myc_table_digits_increase",
                      label = NULL,
                      icon = icon("plus"),
                      class = "btn-default btn-sm",
                      title = "Increase market year table decimals",
                      `aria-label` = "Increase market year table decimals"
                    ),
                    span(
                      textOutput("myc_table_digits_display", inline = TRUE),
                      style = "font-size: 12px; color: #555; margin-left: 4px;"
                    )
                  ),
                  div(
                    class = "myc-table-publish-row",
                    style = "display: flex; justify-content: flex-end; align-items: center; margin: 0;",
                    actionButton(
                      inputId = "publish_myc_market_year_table",
                      label = "Publish Data",
                      class = "btn-primary"
                    )
                  )
                )
              )
            ),
            dataTableOutput("myc_market_year_table")
          )
        )
      )
    }

    # Tab 7: Pace Analysis Tool
    if (show_non_psd_tabs) {
      tabs <- c(
        tabs,
        list(
          tabPanel(
            "Pace Analysis Tool",
            h3("Pace Analysis Tool"),
            p("Set a year-end target to estimate the average pace required from the current period onward to achieve it. Use the sidebar to select different variables, target countries, and toggle between Weekly and Monthly data frequencies."),
          tags$style(HTML("\
            .pace-top-row { display: flex; align-items: stretch; }\
            .pace-top-row > [class*='col-'] { display: flex; flex-direction: column; }\
            .pace-target-panel { height: 100%; margin-bottom: 0; }\
            .pace-kpi-shell { height: 100%; }\
            .pace-kpi-col { display: flex; flex-direction: column; height: 100%; }\
            .pace-kpi-col > .shiny-html-output { flex: 1; display: flex; }\
            .pace-kpi-col > .shiny-html-output > .pace-kpi-shell { flex: 1; }\
          ")),
          div(
            class = "row pace-top-row",
            column(
              width = 4,
              wellPanel(
                class = "pace-target-panel",
                tags$style(HTML("
                  #pace_target_container .form-group {
                    margin-bottom: 5px !important;
                  }
                ")),
                tags$script(HTML("(function() {
                  function formatWithCommas(raw) {
                    var digits = (raw || '').replace(/[^0-9]/g, '');
                    if (!digits) return '';
                    return Number(digits).toLocaleString('en-US');
                  }

                  $(document).on('input', '#pace_target_single', function() {
                    var input = this;
                    var raw = input.value || '';
                    var caret = input.selectionStart || 0;

                    var digitsLeftOfCaret = raw.slice(0, caret).replace(/[^0-9]/g, '').length;
                    var formatted = formatWithCommas(raw);

                    if (formatted === raw) return;

                    input.value = formatted;

                    var newCaret = 0;
                    var seenDigits = 0;
                    while (newCaret < formatted.length && seenDigits < digitsLeftOfCaret) {
                      if (/[0-9]/.test(formatted.charAt(newCaret))) seenDigits++;
                      newCaret++;
                    }
                    input.setSelectionRange(newCaret, newCaret);
                  });
                })();")),
                div(id = "pace_target_container",
                  textInput(
                    inputId = "pace_target_single",
                    label = "Year-End Target Volume:",
                    value = "0"
                  )
                ),
                div(
                  style = "display: grid; grid-template-columns: auto auto auto; column-gap: 6px; row-gap: 6px; margin-bottom: 15px; align-items: center;",
                  actionButton(
                    inputId = "pace_reset_target",
                    label = "Reset to default",
                    style = "grid-column: 1; grid-row: 1;"
                  ),
                  actionButton(
                    inputId = "pace_increase_5",
                    label = "+ 5%",
                    style = "grid-column: 2; grid-row: 1;"
                  ),
                  actionButton(
                    inputId = "pace_increase_10",
                    label = "+ 10%",
                    style = "grid-column: 3; grid-row: 1;"
                  ),
                  actionButton(
                    inputId = "pace_decrease_5",
                    label = "- 5%",
                    style = "grid-column: 2; grid-row: 2;"
                  ),
                  actionButton(
                    inputId = "pace_decrease_10",
                    label = "- 10%",
                    style = "grid-column: 3; grid-row: 2;"
                  )
                ),
                p(
                  style = "font-size: 12px; margin-bottom: 0;",
                  uiOutput("pace_target_note")
                )
              )
            ),
            column(
              width = 8,
              div(class = "pace-kpi-col", uiOutput("pace_kpi_ui", style = "height: 100%;"))
            )
          ),
          hr(),
          uiOutput("pace_gauges_combined_ui", style = "margin-top: 6px;"),
          plotlyOutput("pace_plot", height = "380px"),
          uiOutput("pace_hist_note")
          )
        )
      )
    }

    # Provide an id so we can detect active tab for metric filtering
    tabset_args <- list(id = "main_tabs_panel")
    if (!is.null(selected_tab) && nzchar(selected_tab)) {
      tabset_args$selected <- selected_tab
    }

    tabset_result <- do.call(tabsetPanel, c(tabset_args, tabs))
    main_tabs_profile <- main_tabs_profile_for_source(source_choice_for_log)
    result <- div(
      class = "main-tabs-profile-shell",
      `data-main-tabs-profile` = main_tabs_profile,
      `data-main-tabs-source` = source_choice_for_log,
      `data-main-tabs-expected-count` = length(tabs),
      `data-main-tabs-selected` = selected_tab %||% "",
      `data-main-tabs-render-generation` = main_tabs_render_generation,
      `data-main-tabs-render-key` = paste(
        main_tabs_profile,
        source_choice_for_log,
        length(tabs),
        selected_tab %||% "",
        main_tabs_render_generation,
        sep = "|"
      ),
      tabset_result
    )

    log_perf(
      "output$main_tabs",
      start_time,
      details = list(
        source = source_choice_for_log,
        frequency = frequency_for_log,
        profile = main_tabs_profile,
        selected_tab = selected_tab,
        render_generation = main_tabs_render_generation,
        tab_count = length(tabs)
      )
    )

    result
  })

  observeEvent(list(input$data_source_choice, input$main_tabs_panel), {
    source_choice <- if (!is.null(input$data_source_choice)) input$data_source_choice else "export_sales"
    normalized_tab <- target_main_tab_for_source(input$main_tabs_panel, source_choice)

    if (isTRUE(psd_source_transition_active()) && identical(source_choice, "psd")) {
      return()
    }

    if (!identical(input$main_tabs_panel, normalized_tab)) {
      schedule_main_tabs_safe_select(
        normalized_tab,
        source_choice,
        reason = "main_tabs_normalize"
      )
    }
  }, ignoreInit = TRUE)
  

