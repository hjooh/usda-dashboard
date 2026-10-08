get_commodity_contract <- function(project_root = normalizePath(getwd(), winslash = "/", mustWork = FALSE)) {
  project_root <- normalizePath(project_root, winslash = "/", mustWork = FALSE)

  list(
    contract_schema_version = 1L,
    project_root = project_root,
    identity = list(
      commodity_id = "almond",
      commodity_name = "Almond",
      commodity_name_plural = "Almonds",
      app_title = "USDA-ERS Almond Analysis Tool",
      aggregate_label = "All Almonds",
      reserved_names = c("All Almonds")
    ),
    runtime = list(
      root_sentinel = ".almond_rice_clone_root",
      clone_marker = "ALMOND_RICE_CLONE_ROOT=TRUE",
      entrypoint_file = "Almond_Analysis_Shiny.R",
      option_prefix = "almond",
      env_prefix = "ALMOND",
      trace_file_prefix = "almond",
      startup_fail_closed = TRUE,
      disabled_source_policy = "contract_disabled",
      forbidden_entrypoint_files = c("Rice_Analysis_Shiny.R")
    ),
    namespaces = list(
      notes_namespace = "almond_notes",
      corrections_namespace = "almond_corrections",
      custom_types_namespace = "almond_custom_types",
      cache_namespace = "almond_cache",
      processed_artifact_namespace = "almond_processed"
    ),
    source_families = list(
      census_exports = list(
        structurally_present = TRUE,
        runtime_enabled = TRUE,
        build_enabled = TRUE,
        visible_in_ui = TRUE,
        disabled_reason = "Enabled for Step 26 Census-first runtime activation after live Census and data-parity validation.",
        required_packages = c("RODBC", "dplyr", "tidyr", "readr", "tibble"),
        required_artifacts = c("census_exports_monthly", "census_combined", "census_correction_targets"),
        adapter_name = "almond_census"
      ),
      census_imports = list(
        structurally_present = TRUE,
        runtime_enabled = TRUE,
        build_enabled = TRUE,
        visible_in_ui = TRUE,
        disabled_reason = "Enabled for Step 26 Census-first runtime activation after live Census and data-parity validation.",
        required_packages = c("RODBC", "dplyr", "tidyr", "readr", "tibble"),
        required_artifacts = c("census_imports_monthly", "census_combined", "census_correction_targets"),
        adapter_name = "almond_census"
      ),
      psd = list(
        structurally_present = TRUE,
        runtime_enabled = TRUE,
        build_enabled = TRUE,
        visible_in_ui = TRUE,
        disabled_reason = "Enabled for Almond PSD Map and Time Series validation after live artifact, runtime, and metadata checks.",
        required_packages = c("httr", "jsonlite", "dplyr", "tidyr", "tibble"),
        required_artifacts = c("psd_marketing_year", "psd_historical_records"),
        adapter_name = "almond_psd"
      ),
      nass = list(
        structurally_present = TRUE,
        runtime_enabled = TRUE,
        build_enabled = TRUE,
        visible_in_ui = TRUE,
        disabled_reason = "Enabled for Almond NASS annual domestic market validation after SQL schema exploration.",
        required_packages = c("RODBC", "dplyr", "tidyr", "readr", "tibble"),
        required_artifacts = c("nass_raw", "nass_annual"),
        adapter_name = "almond_nass"
      ),
      wasde = list(
        structurally_present = TRUE,
        runtime_enabled = FALSE,
        build_enabled = FALSE,
        visible_in_ui = FALSE,
        disabled_reason = "No local Almond WASDE source evidence.",
        required_packages = c("RODBC"),
        required_artifacts = character(),
        adapter_name = "disabled_wasde"
      ),
      export_sales = list(
        structurally_present = TRUE,
        runtime_enabled = FALSE,
        build_enabled = FALSE,
        visible_in_ui = FALSE,
        disabled_reason = "No local Almond Export Sales source evidence.",
        required_packages = c("httr", "jsonlite", "data.table", "lubridate"),
        required_artifacts = character(),
        adapter_name = "disabled_export_sales"
      ),
      hybrid = list(
        structurally_present = TRUE,
        runtime_enabled = FALSE,
        build_enabled = FALSE,
        visible_in_ui = FALSE,
        disabled_reason = "Requires upstream source contracts that are not yet enabled.",
        required_packages = c("dplyr", "tidyr", "tibble"),
        required_artifacts = character(),
        adapter_name = "disabled_hybrid"
      ),
      pace = list(
        structurally_present = TRUE,
        runtime_enabled = TRUE,
        build_enabled = FALSE,
        visible_in_ui = TRUE,
        disabled_reason = "PACE is enabled as a Census runtime feature using Census monthly artifacts; WASDE/PSD target overlay remains gated.",
        required_packages = character(),
        required_artifacts = c("census_exports_monthly", "census_imports_monthly"),
        adapter_name = "census_pace"
      ),
      myc = list(
        structurally_present = TRUE,
        runtime_enabled = FALSE,
        build_enabled = FALSE,
        visible_in_ui = FALSE,
        disabled_reason = "Source-specific share/cutoff validation pending.",
        required_packages = character(),
        required_artifacts = character(),
        adapter_name = "disabled_myc"
      ),
      notes = list(
        structurally_present = TRUE,
        runtime_enabled = TRUE,
        build_enabled = FALSE,
        visible_in_ui = TRUE,
        disabled_reason = "Enabled after Almond-local namespace isolation.",
        required_packages = character(),
        required_artifacts = character(),
        adapter_name = "almond_notes"
      ),
      corrections = list(
        structurally_present = TRUE,
        runtime_enabled = TRUE,
        build_enabled = TRUE,
        visible_in_ui = TRUE,
        disabled_reason = "Enabled for Census after Almond-local correction registry/audit namespace isolation.",
        required_packages = c("dplyr", "readr", "tibble"),
        required_artifacts = c("census_correction_targets"),
        adapter_name = "almond_corrections"
      ),
      custom_types = list(
        structurally_present = TRUE,
        runtime_enabled = TRUE,
        build_enabled = FALSE,
        visible_in_ui = TRUE,
        disabled_reason = "Enabled after Almond-local custom type namespace isolation.",
        required_packages = character(),
        required_artifacts = character(),
        adapter_name = "almond_custom_types"
      )
    ),
    artifacts = list(
      hs_reference_workbook = list(path = "System/Reference/Almond_HSCodes_workbook.xlsx", required = FALSE),
      app_ui_metadata = list(path = "System/Processed Data/app_ui_metadata_pre.rds", required = FALSE),
      export_sales_weekly = list(path = "System/Processed Data/export_sales_weekly_pre.rds", required = FALSE),
      export_sales_weekly_fiscal = list(path = "System/Processed Data/export_sales_weekly_fiscal_pre.rds", required = FALSE),
      export_sales_monthly = list(path = "System/Processed Data/export_sales_monthly_pre.rds", required = FALSE),
      export_sales_monthly_fiscal = list(path = "System/Processed Data/export_sales_monthly_fiscal_pre.rds", required = FALSE),
      census_exports_raw = list(path = "Output/Census data/census_almond_exports_raw.csv", required = FALSE),
      census_imports_raw = list(path = "Output/Census data/census_almond_imports_raw.csv", required = FALSE),
      census_exports_monthly = list(path = "System/Processed Data/census_almond_exports_monthly_pre.rds", required = FALSE),
      census_exports_monthly_fiscal = list(path = "System/Processed Data/census_almond_exports_monthly_fiscal_pre.rds", required = FALSE),
      census_imports_monthly = list(path = "System/Processed Data/census_almond_imports_monthly_pre.rds", required = FALSE),
      census_imports_monthly_fiscal = list(path = "System/Processed Data/census_almond_imports_monthly_fiscal_pre.rds", required = FALSE),
      census_fixture_combined = list(path = "System/Processed Data/census_almond_fixture_pre.rds", required = FALSE),
      census_fixture_correction_targets = list(path = "System/Processed Data/census_almond_fixture_correction_targets_pre.rds", required = FALSE),
      census_combined = list(path = "System/Processed Data/census_almond_pre.rds", required = FALSE),
      census_correction_targets = list(path = "System/Processed Data/census_almond_correction_targets_pre.rds", required = FALSE),
      psd_lookup = list(path = "Output/FAS PSD data/psd_almond_phase1_lookup.rds", required = FALSE),
      psd_raw = list(path = "Output/FAS PSD data/psd_almond_my.csv", required = FALSE),
      psd_metadata = list(path = "Output/FAS PSD data/psd_almond_my_metadata.csv", required = FALSE),
      psd_summary = list(path = "Output/FAS PSD data/psd_almond_my_phase1_summary.txt", required = FALSE),
      psd_marketing_year = list(path = "System/Processed Data/psd_almond_my_pre.rds", required = FALSE),
      psd_historical_records = list(path = "System/Processed Data/psd_almond_historical_records_pre.rds", required = FALSE),
      nass_raw = list(path = "Output/NASS data/nass_almond_annual_raw.csv", required = FALSE),
      nass_annual = list(path = "System/Processed Data/nass_almond_annual_pre.rds", required = FALSE),
      nass_state_lookup = list(path = "System/Processed Data/nass_almond_state_lookup_pre.rds", required = FALSE),
      nass_shellout_factors = list(path = "System/Processed Data/nass_almond_shellout_factors_pre.rds", required = FALSE),
      nass_historical_records = list(path = "System/Processed Data/nass_almond_historical_records_pre.rds", required = FALSE),
      hybrid_export_monthly = list(path = "System/Processed Data/hybrid_export_monthly_pre.rds", required = FALSE),
      hybrid_export_monthly_fiscal = list(path = "System/Processed Data/hybrid_export_monthly_fiscal_pre.rds", required = FALSE),
      hybrid_import_monthly = list(path = "System/Processed Data/hybrid_import_monthly_pre.rds", required = FALSE),
      hybrid_import_monthly_fiscal = list(path = "System/Processed Data/hybrid_import_monthly_fiscal_pre.rds", required = FALSE),
      hybrid_weekly_imputed = list(path = "System/Processed Data/hybrid_weekly_imputed_pre.rds", required = FALSE),
      hybrid_weekly_imputed_fiscal = list(path = "System/Processed Data/hybrid_weekly_imputed_fiscal_pre.rds", required = FALSE),
      wasde_marketing_year = list(path = "System/Processed Data/wasde_marketing_year_pre.rds", required = FALSE),
      wasde_historical_records = list(path = "System/Processed Data/wasde_historical_records_pre.rds", required = FALSE),
      wasde_release_history = list(path = "System/Processed Data/wasde_release_history_pre.rds", required = FALSE),
      wasde_revision_delta = list(path = "System/Processed Data/wasde_revision_delta_pre.rds", required = FALSE),
      psd_revision_delta = list(path = "System/Processed Data/psd_revision_delta_pre.rds", required = FALSE),
      notes = list(path = "System/Notes/almond_notes.csv", required = FALSE),
      corrections_registry = list(path = "System/Corrections/census_corrections_registry.csv", required = FALSE),
      corrections_audit = list(path = "System/Corrections/census_corrections_applied.csv", required = FALSE),
      custom_types = list(path = "System/CustomTypes/almond_custom_types.csv", required = FALSE),
      cache = list(path = "System/Cache", required = FALSE)
    ),
    adapters = list(
      almond_census = list(
        source_family = c("census_exports", "census_imports"),
        status = "candidate",
        module = "Programs/adapters/census_adapter.R",
        contract_section = "census",
        validation_harness = "System/Testing/Harnesses/test_census_adapter_contract.R"
      ),
      almond_psd = list(
        source_family = "psd",
        status = "candidate",
        module = "Programs/adapters/psd_adapter.R",
        contract_section = "psd",
        validation_harness = "System/Testing/Harnesses/test_psd_adapter_contract.R"
      ),
      almond_nass = list(
        source_family = "nass",
        status = "candidate",
        module = "Programs/adapters/nass_adapter.R",
        contract_section = "nass",
        validation_harness = "System/Testing/Harnesses/test_nass_source_surface_contract.R"
      ),
      almond_notes = list(source_family = "notes", status = "pending_namespace"),
      almond_corrections = list(source_family = "corrections", status = "pending_schema"),
      almond_custom_types = list(source_family = "custom_types", status = "pending_namespace"),
      disabled_wasde = list(source_family = "wasde", status = "disabled"),
      disabled_export_sales = list(source_family = "export_sales", status = "disabled"),
      disabled_hybrid = list(source_family = "hybrid", status = "disabled"),
      census_pace = list(source_family = "pace", status = "enabled_with_census"),
      disabled_pace = list(source_family = "pace", status = "disabled"),
      disabled_myc = list(source_family = "myc", status = "disabled")
    ),
    labels = list(
      app_name = "Almond Shiny Rice Clone",
      app_title = "USDA-ERS Almond Analysis Tool",
      aggregate_label = "All Almonds",
      commodity_type_label = "Almond Type:",
      commodity_type_placeholder = "Type to filter almond types...",
      disabled_source_message = "This source family is structurally present but not enabled for Almond yet.",
      source_choice_families = list(
        export_sales = "export_sales",
        census = c("census_exports", "census_imports"),
        hybrid = "hybrid",
        nass = "nass",
        wasde = "wasde",
        psd = "psd"
      ),
      source_choice_groups = list(
        "Domestic Trade Analysis" = c(
          "Export Sales" = "export_sales",
          "Census Data" = "census",
          "Hybrid/Aggregate" = "hybrid"
        ),
        "Domestic Market Analysis" = c(
          "National Agricultural Statistics Service" = "nass"
        ),
        "Domestic Balance Sheet Analysis" = c(
          "World Agricultural Supply and Demand Estimates" = "wasde"
        ),
        "Global Analysis" = c(
          "Production, Supply, and Distribution" = "psd"
        )
      )
    ),
    census = list(
      market_year_start_month = 8L,
      default_start_year = 2010L,
      historical_start_market_year = 2010L,
      native_world_country_code = "0001",
      app_world_country_code = "GRAND_TOTAL",
      aggregate_hs_code = "ALL_ALMONDS",
      aggregate_reporting_code = "ALL_ALMONDS",
      sql_server = "AERGCAZU3DBPRD1",
      start_year_env = "ALMOND_CENSUS_START_YEAR",
      end_year_env = "ALMOND_CENSUS_END_YEAR",
      value_metrics_enabled = FALSE,
      value_metrics_disabled_reason = "Almond Census value metrics remain disabled until raw source, processed artifacts, correction targets, app metadata, and UI metric contracts preserve populated value fields.",
      fiscal_year = list(
        runtime_enabled = FALSE,
        build_enabled = FALSE,
        visible_in_ui = FALSE,
        disabled_reason = "Almond Census fiscal-year views are retained as dormant plumbing but disabled for monthly marketing-year-only runtime."
      ),
      raw_required_columns = c(
        "HS_Country_Code", "HS_Code", "Attrib_Code", "UOM_Code", "Country",
        "HS", "Attrib", "UOM", "YEARNUM", "MONTHNUM", "AMOUNT"
      ),
      prepared_required_columns = c("HS_Country_Code", "Country", "HS_Code", "Year", "Month", "Quantity_KG"),
      processed_required_columns = c(
        "flow", "country_code", "country_name", "hs_code", "reporting_code", "Year", "Month",
        "market_year", "quantity_kg", "quantity_1000_lb", "quantity_mt", "shelled_basis_factor",
        "shelled_basis_1000_lb", "shelled_basis_mt", "trade_value", "is_corrected", "applied_correction_ids"
      ),
      correction_target_required_columns = c(
        "correction_target_key", "flow", "country_code", "country_name", "hs_code", "reporting_code",
        "year", "month", "measure", "market_year", "shelled_basis_factor", "quantity_kg", "quantity_mt",
        "quantity_1000_lb", "shelled_basis_mt", "trade_value"
      ),
      reporting_code_rollups = c("0802120005" = "802129999", "0802120015" = "802129999"),
      shelled_basis_factors = c("0802110000" = 0.6, "2008194000" = 0.7),
      basis = list(
        default = "inshell_eq",
        choices = c(
          "Shelled Equivalent" = "shelled_eq",
          "In-Shell Equivalent" = "inshell_eq"
        ),
        shelled_alias = "rough_eq",
        inshell_shell_out_factor = 0.6,
        value_metrics_basis_invariant = TRUE
      ),
      flows = list(
        imports = list(
          database = "hsimports",
          view = "[hsimports].[hsimports].[view_HSIMPORT_Data]",
          hs_codes = c("0802110000", "0802120005", "0802120015", "2008194000"),
          product_choices = c(
            "0802110000 - ALMONDS, FRESH OR DRIED, IN SHELL" = "0802110000",
            "0802120005 - CERTIFIED ORGANIC ALMONDS, FRESH OR DRIED, SHELLED" = "0802120005",
            "0802120015 - ALMONDS, FRESH OR DRIED, SHELLED" = "0802120015",
            "2008194000 - ALMONDS, PREPARED OR PRESERVED NESOI" = "2008194000"
          ),
          weight_attribute = "22",
          value_attribute = "21",
          attributes = c("21", "22"),
          raw_artifact_role = "census_imports_raw",
          processed_artifact_role = "census_imports_monthly"
        ),
        exports = list(
          database = "hsexports",
          view = "[hsexports].[hsexports].[view_HSEXPORT_Data]",
          hs_codes = c("0802120000", "0802110000", "2008194000"),
          product_choices = c(
            "0802120000 - ALMONDS, FRESH OR DRIED, SHELLED" = "0802120000",
            "0802110000 - ALMONDS, FRESH OR DRIED, IN SHELL" = "0802110000",
            "2008194000 - ALMONDS, PREPARED OR PRESERVED NESOI" = "2008194000"
          ),
          weight_attribute = "12",
          value_attribute = "11",
          attributes = c("11", "12"),
          raw_artifact_role = "census_exports_raw",
          processed_artifact_role = "census_exports_monthly"
        )
      )
    ),
    psd = list(
      api_key_env = "ALMOND_PSD_API_KEY",
      fallback_api_key_env = "FAS_PSD_API_KEY",
      api_key_file_env = "ALMOND_PSD_API_KEY_FILE",
      default_api_key_file = "Input/fas_psd_api_key.txt",
      start_year_env = "ALMOND_PSD_START_YEAR",
      end_year_env = "ALMOND_PSD_END_YEAR",
      default_start_year = 1960L,
      market_year_start_month = 8L,
      commodity_code = "0577400",
      commodity_name = "Almonds, Shelled Basis",
      commodity_group = "Almonds",
      app_commodity_label = "All Almonds",
      app_commodity_group = "Almonds",
      native_world_country_code = "WORLD",
      app_world_country_code = "GRAND_TOTAL",
      lookup_artifact_role = "psd_lookup",
      raw_artifact_role = "psd_raw",
      metadata_artifact_role = "psd_metadata",
      summary_artifact_role = "psd_summary",
      processed_artifact_role = "psd_marketing_year",
      historical_records_artifact_role = "psd_historical_records",
      expected_native_metric_ids = c(
        "beginning_stocks", "production", "imports", "total_supply",
        "exports", "domestic_consumption", "ending_stocks", "total_distribution"
      ),
      native_unit_profile = "(MT)",
      basis_profile = "shelled_basis",
      prior_release_comparison_enabled = FALSE,
      prior_release_disabled_reason = "Almond PSD prior-release/revision comparison remains deferred until release archive semantics are validated."
    ),
    nass = list(
      sql_server = "AERGCAZU3DBPRD1",
      database = "NASSQUICKSTATS",
      schema = "QSDATA",
      table = "NASS_QUICKSTATS_SURVEY_CROPS",
      commodity_desc = "ALMONDS",
      default_start_year = 2000L,
      geography_type = "state",
      national_aggregate_label = "U.S. Total",
      native_national_state_alpha = "US",
      default_state_alpha = "US",
      state_aggregate_level = "STATE",
      national_aggregate_level = "NATIONAL",
      frequency_desc = "ANNUAL",
      annual_year_types = c("calendar_year", "marketing_year", "forecast"),
      final_reference_periods = c("YEAR", "MARKETING YEAR"),
      forecast_reference_periods = c("YEAR - MAY FORECAST", "YEAR - JUL FORECAST"),
      raw_artifact_role = "nass_raw",
      processed_artifact_role = "nass_annual",
      state_lookup_artifact_role = "nass_state_lookup",
      factor_artifact_role = "nass_shellout_factors",
      historical_records_artifact_role = "nass_historical_records",
      already_shelled_basis = TRUE,
      short_descriptions = c(
        acres_bearing = "ALMONDS - ACRES BEARING",
        yield_utilized = "ALMONDS, UTILIZED - YIELD, MEASURED IN LB / ACRE",
        yield_utilized_tons = "ALMONDS, UTILIZED - YIELD, MEASURED IN TONS / ACRE",
        yield_shelled_utilized = "ALMONDS, UTILIZED, SHELLED - YIELD, MEASURED IN LB / ACRE",
        production_shelled_lb = "ALMONDS, UTILIZED, SHELLED - PRODUCTION, MEASURED IN LB",
        price_received_per_lb = "ALMONDS - PRICE RECEIVED, MEASURED IN $ / LB",
        production_shelled_value = "ALMONDS, UTILIZED, SHELLED - PRODUCTION, MEASURED IN $"
      ),
      factor_short_descriptions = c(
        production_shelled_lb = "ALMONDS, UTILIZED, SHELLED - PRODUCTION, MEASURED IN LB",
        production_shelled_lb_modern = "ALMONDS, SHELLED - PRODUCTION, MEASURED IN LB",
        production_inshell_lb = "ALMONDS, IN SHELL - PRODUCTION, MEASURED IN LB",
        production_inshell_basis_tons = "ALMONDS, UTILIZED, SHELLED - PRODUCTION, MEASURED IN TONS, IN SHELL BASIS"
      ),
      metric_labels = c(
        acres_bearing = "Bearing Acres",
        yield = "Yield",
        production_shelled_lb = "Production",
        price_received_per_lb = "Price Received",
        production_shelled_value = "Production Value",
        shellout_factor = "Shell-Out Factor"
      ),
      scaling = list(
        acres_bearing = list(divisor = 1000, unit = "1,000 acres"),
        yield = list(multiplier = 1, unit = "lb / acre"),
        production_shelled_lb = list(divisor = 1000000, unit = "million lb"),
        price_received_per_lb = list(multiplier = 100, unit = "cents / lb"),
        production_shelled_value = list(divisor = 1000, unit = "1,000 dollars"),
        shellout_factor = list(multiplier = 1, unit = "ratio")
      )
    ),
    metadata = list(
      enabled_source_order = c("census_export", "census_import", "nass", "psd"),
      source_priorities = c(psd = 1L, nass = 1L, census_exports = 2L, census_imports = 2L),
      source_entries = list(
        psd = list(
          source_family = "psd",
          processed_artifact_role = "psd_marketing_year",
          source_artifact_roles = c("psd_raw", "psd_metadata"),
          artifact_family = "psd_marketing_year_long",
          source_priority = 1L
        ),
        nass = list(
          source_family = "nass",
          processed_artifact_role = "nass_annual",
          source_artifact_roles = "nass_raw",
          artifact_family = "nass_annual",
          source_priority = 1L
        ),
        wasde = list(
          source_family = "wasde",
          processed_artifact_role = "wasde_marketing_year",
          source_artifact_roles = character(),
          artifact_family = "wasde_marketing_year",
          source_priority = 1L
        ),
        census_export = list(
          source_family = "census_exports",
          processed_artifact_role = "census_exports_monthly",
          source_artifact_roles = "census_exports_raw",
          artifact_family = "census_exports_monthly",
          source_priority = 2L
        ),
        census_import = list(
          source_family = "census_imports",
          processed_artifact_role = "census_imports_monthly",
          source_artifact_roles = "census_imports_raw",
          artifact_family = "census_imports_monthly",
          source_priority = 2L
        ),
        export_sales_monthly = list(
          source_family = "export_sales",
          processed_artifact_role = "export_sales_monthly",
          source_artifact_roles = character(),
          artifact_family = "export_sales_monthly",
          source_priority = 3L
        ),
        export_sales_weekly = list(
          source_family = "export_sales",
          processed_artifact_role = "export_sales_weekly",
          source_artifact_roles = character(),
          artifact_family = "export_sales_weekly",
          source_priority = 3L
        ),
        hybrid_export_monthly = list(
          source_family = "hybrid",
          processed_artifact_role = "hybrid_export_monthly",
          source_artifact_roles = character(),
          artifact_family = "hybrid_monthly",
          source_priority = 4L
        ),
        hybrid_import_monthly = list(
          source_family = "hybrid",
          processed_artifact_role = "hybrid_import_monthly",
          source_artifact_roles = character(),
          artifact_family = "hybrid_import_monthly",
          source_priority = 4L
        ),
        hybrid_weekly_imputed = list(
          source_family = "hybrid",
          processed_artifact_role = "hybrid_weekly_imputed",
          source_artifact_roles = character(),
          artifact_family = "hybrid_weekly_imputed",
          source_priority = 4L
        )
      ),
      missing_artifact_policy = "disabled_source_placeholder",
      conflict_policy = "fail_for_enabled_sources"
    ),
    dependencies = list(
      runtime_packages = c("shiny", "tidyverse", "DT", "plotly"),
      validation_packages = c("shinytest2"),
      lockfile_policy = "repo_level_decision_pending"
    ),
    credentials = list(
      environment_variables = c("ALMOND_CENSUS_DSN", "ALMOND_PSD_API_KEY"),
      local_config_glob = "System/Config/*.local.R",
      fail_closed = TRUE
    ),
    shared_core = list(
      generic_terms = c("commodity", "source_family", "adapter", "artifact_role", "namespace"),
      forbidden_shared_prefixes = c("rice_", "almond_"),
      onboarding_doc = "SCAFFOLDING.md"
    )
  )
}