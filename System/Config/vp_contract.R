get_commodity_contract <- function(project_root = normalizePath(getwd(), winslash = "/", mustWork = FALSE)) {
  project_root <- normalizePath(project_root, winslash = "/", mustWork = FALSE)

  disabled_source <- function(reason = "Not used by the VP Current vs. Historical phase 1 app.") {
    list(
      structurally_present = TRUE,
      runtime_enabled = FALSE,
      build_enabled = FALSE,
      visible_in_ui = FALSE,
      disabled_reason = reason,
      required_packages = character(),
      required_artifacts = character(),
      adapter_name = "disabled"
    )
  }

  list(
    contract_schema_version = 1L,
    project_root = project_root,
    identity = list(
      commodity_id = "vp",
      commodity_name = "Fruit and Tree Nut",
      commodity_name_plural = "Fruits and Tree Nuts",
      app_title = "USDA-ERS Fruit and Tree Nut Trade Analysis Tool",
      aggregate_label = "All Fruit and Tree Nut Commodities",
      reserved_names = c("All Fruit and Tree Nut Commodities")
    ),
    runtime = list(
      root_sentinel = ".vp_clone_root",
      clone_marker = "VP_CLONE_ROOT=TRUE",
      entrypoint_file = "FTN_Analysis_Shiny.R",
      option_prefix = "vp",
      env_prefix = "VP",
      trace_file_prefix = "vp",
      startup_fail_closed = TRUE,
      disabled_source_policy = "contract_disabled",
      forbidden_entrypoint_files = c("Almond_Analysis_Shiny.R", "Rice_Analysis_Shiny.R")
    ),
    namespaces = list(
      notes_namespace = "vp_notes_disabled",
      corrections_namespace = "vp_corrections_disabled",
      custom_types_namespace = "vp_custom_types",
      custom_countries_namespace = "vp_custom_countries",
      cache_namespace = "vp_cache",
      processed_artifact_namespace = "vp_processed"
    ),
    source_families = list(
      vp_trade = list(
        structurally_present = TRUE,
        runtime_enabled = TRUE,
        build_enabled = TRUE,
        visible_in_ui = TRUE,
        disabled_reason = "VP local CSV trade artifact is enabled.",
        required_packages = c("data.table", "dplyr", "tidyr", "tibble"),
        required_artifacts = c("vp_trade_monthly", "app_ui_metadata"),
        adapter_name = "vp_trade"
      ),
      census_exports = disabled_source(),
      census_imports = disabled_source(),
      psd = disabled_source(),
      nass = disabled_source(),
      wasde = disabled_source(),
      export_sales = disabled_source(),
      hybrid = disabled_source(),
      pace = disabled_source("Future VP feature tab seam only."),
      myc = disabled_source("Future VP feature tab seam only."),
      notes = disabled_source("Notes are excluded from VP."),
      corrections = disabled_source("Census Corrections are excluded from VP."),
      custom_types = list(
        structurally_present = TRUE,
        runtime_enabled = TRUE,
        build_enabled = FALSE,
        visible_in_ui = TRUE,
        disabled_reason = "VP custom builders are enabled.",
        required_packages = character(),
        required_artifacts = character(),
        adapter_name = "vp_custom_types"
      )
    ),
    artifacts = list(
      hs_reference_workbook = list(path = "System/Reference/vp_hs_reference_placeholder.xlsx", required = FALSE),
      app_ui_metadata = list(path = "System/Processed Data/app_ui_metadata_pre.rds", required = FALSE),
      vp_trade_monthly = list(path = "System/Processed Data/vp_trade_monthly_pre.rds", required = TRUE),
      vp_trade_metadata = list(path = "System/Processed Data/vp_trade_metadata_pre.rds", required = FALSE),
      export_sales_weekly = list(path = "System/Processed Data/export_sales_weekly_pre.rds", required = FALSE),
      export_sales_weekly_fiscal = list(path = "System/Processed Data/export_sales_weekly_fiscal_pre.rds", required = FALSE),
      export_sales_monthly = list(path = "System/Processed Data/export_sales_monthly_pre.rds", required = FALSE),
      export_sales_monthly_fiscal = list(path = "System/Processed Data/export_sales_monthly_fiscal_pre.rds", required = FALSE),
      census_exports_monthly = list(path = "System/Processed Data/census_vp_exports_monthly_pre.rds", required = FALSE),
      census_exports_monthly_fiscal = list(path = "System/Processed Data/census_vp_exports_monthly_fiscal_pre.rds", required = FALSE),
      census_imports_monthly = list(path = "System/Processed Data/census_vp_imports_monthly_pre.rds", required = FALSE),
      census_imports_monthly_fiscal = list(path = "System/Processed Data/census_vp_imports_monthly_fiscal_pre.rds", required = FALSE),
      census_fixture_combined = list(path = "System/Processed Data/census_vp_fixture_pre.rds", required = FALSE),
      census_fixture_correction_targets = list(path = "System/Processed Data/census_vp_fixture_correction_targets_pre.rds", required = FALSE),
      census_combined = list(path = "System/Processed Data/census_vp_pre.rds", required = FALSE),
      census_correction_targets = list(path = "System/Processed Data/census_vp_correction_targets_pre.rds", required = FALSE),
      psd_marketing_year = list(path = "System/Processed Data/psd_vp_my_pre.rds", required = FALSE),
      psd_historical_records = list(path = "System/Processed Data/psd_vp_historical_records_pre.rds", required = FALSE),
      nass_annual = list(path = "System/Processed Data/nass_vp_annual_pre.rds", required = FALSE),
      nass_state_lookup = list(path = "System/Processed Data/nass_vp_state_lookup_pre.rds", required = FALSE),
      nass_shellout_factors = list(path = "System/Processed Data/nass_vp_shellout_factors_pre.rds", required = FALSE),
      nass_historical_records = list(path = "System/Processed Data/nass_vp_historical_records_pre.rds", required = FALSE),
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
      notes = list(path = "System/Notes/vp_notes_disabled.csv", required = FALSE),
      corrections_registry = list(path = "System/Corrections/vp_corrections_registry_disabled.csv", required = FALSE),
      corrections_audit = list(path = "System/Corrections/vp_corrections_applied_disabled.csv", required = FALSE),
      custom_types = list(path = "System/CustomTypes/vp_custom_types.csv", required = FALSE),
      cache = list(path = "System/Cache", required = FALSE)
    ),
    adapters = list(
      vp_trade = list(source_family = "vp_trade", status = "enabled", module = "Programs/vp_data_utils.R", contract_section = "vp_trade"),
      vp_custom_types = list(source_family = "custom_types", status = "enabled"),
      disabled = list(source_family = character(), status = "disabled")
    ),
    labels = list(
      app_name = "FTN VP-Parity Clone",
      app_title = "USDA-ERS Fruit and Tree Nut Trade Analysis Tool",
      aggregate_label = "All Fruit and Tree Nut Commodities",
      commodity_type_label = "Commodity Detail:",
      commodity_type_placeholder = "Type to filter FTN commodity details...",
      disabled_source_message = "This source family is not used by the FTN Current vs. Historical app.",
      source_choice_families = list(vp_trade = "vp_trade"),
      source_choice_groups = list("Fruit and Tree Nut Trade" = c("FTN Trade" = "vp_trade"))
    ),
    census = list(
      fiscal_year = list(runtime_enabled = FALSE, build_enabled = FALSE, visible_in_ui = FALSE),
      basis = list(default = "vp_identity", choices = c("VP Identity" = "vp_identity"), shelled_alias = "rough_eq", inshell_shell_out_factor = 1, value_metrics_basis_invariant = TRUE)
    ),
    metadata = list(
      enabled_source_order = c("vp_trade"),
      source_priorities = c(vp_trade = 1L),
      source_entries = list(
        vp_trade = list(
          source_family = "vp_trade",
          processed_artifact_role = "vp_trade_monthly",
          source_artifact_roles = "vp_trade_monthly",
          artifact_family = "vp_trade_monthly",
          source_priority = 1L
        )
      ),
      missing_artifact_policy = "fail_for_enabled_sources",
      conflict_policy = "fail_for_enabled_sources"
    ),
    dependencies = list(
      runtime_packages = c("shiny", "tidyverse", "DT", "plotly", "data.table"),
      validation_packages = c("shinytest2"),
      lockfile_policy = "repo_level_decision_pending"
    ),
    credentials = list(
      environment_variables = character(),
      local_config_glob = "System/Config/*.local.R",
      fail_closed = FALSE
    ),
    shared_core = list(
      generic_terms = c("commodity", "source_family", "adapter", "artifact_role", "namespace"),
      forbidden_shared_prefixes = c("rice_", "almond_"),
      local_prefix = "vp_"
    )
  )
}
