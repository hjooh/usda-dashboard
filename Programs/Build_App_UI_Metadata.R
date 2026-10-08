suppressPackageStartupMessages({
  library(tidyverse)
})

get_vp_app_ui_metadata_script_dir <- function() {
  frame_files <- vapply(sys.frames(), function(frame) {
    value <- tryCatch(frame$ofile, error = function(...) NULL)
    if (is.null(value) || length(value) == 0L) return("")
    as.character(value[[1]])
  }, character(1))
  frame_files <- frame_files[nzchar(frame_files)]
  builder_file <- frame_files[grepl("Build_App_UI_Metadata\\.R$", frame_files)]
  if (length(builder_file) > 0L) {
    return(dirname(normalizePath(builder_file[[length(builder_file)]], winslash = "/", mustWork = FALSE)))
  }

  command_args <- commandArgs(trailingOnly = FALSE)
  file_arg <- "--file="
  script_arg <- command_args[startsWith(command_args, file_arg)]
  if (length(script_arg) > 0L) {
    script_path <- sub(file_arg, "", script_arg[[1]], fixed = TRUE)
    if (nzchar(script_path)) return(dirname(normalizePath(script_path, winslash = "/", mustWork = FALSE)))
  }

  normalizePath(getwd(), winslash = "/", mustWork = FALSE)
}

vp_app_ui_metadata_script_dir <- get_vp_app_ui_metadata_script_dir()
vp_app_ui_metadata_default_project_root <- normalizePath(file.path(vp_app_ui_metadata_script_dir, ".."), winslash = "/", mustWork = TRUE)

resolve_vp_app_ui_metadata_project_root <- function(project_root = NULL) {
  if (is.null(project_root) || length(project_root) == 0L || !nzchar(as.character(project_root[[1]]))) {
    project_root <- vp_app_ui_metadata_default_project_root
  }
  normalizePath(project_root, winslash = "/", mustWork = TRUE)
}

source(file.path(vp_app_ui_metadata_default_project_root, "Programs", "shared_core", "commodity_contract_utils.R"), local = FALSE)
source(file.path(vp_app_ui_metadata_default_project_root, "System", "Config", "vp_contract.R"), local = FALSE)
source(file.path(vp_app_ui_metadata_default_project_root, "Programs", "shared_source_harmonization_utils.R"), local = FALSE)
source(file.path(vp_app_ui_metadata_default_project_root, "Programs", "vp_data_utils.R"), local = FALSE)

vp_app_ui_metadata_required_fields <- function() {
  c(
    "country_canonical_label_lookup",
    "country_choice_row_sources",
    "country_choice_label_rows",
    "country_choices_all",
    "country_display_names",
    "country_display_name_lookup",
    "country_display_name_context_keys"
  )
}

vp_app_ui_metadata_country_harmonization_paths <- function(project_root) {
  country_harmonization_dir <- file.path(project_root, "Programs", "Country Harmonization Programs (Hybrid)")
  list(
    baseline_table_path = file.path(country_harmonization_dir, "country_harmonization_baseline.csv"),
    review_table_path = file.path(country_harmonization_dir, "country_mapping_review_table.csv"),
    review_generator_path = file.path(country_harmonization_dir, "generate_country_mapping_review_table.R"),
    readme_path = file.path(project_root, "Documentation", "README_country_harmonization_hybrid.txt")
  )
}

build_vp_app_ui_metadata_extra_signatures <- function(project_root, artifact_family = "app_ui_metadata") {
  paths <- vp_app_ui_metadata_country_harmonization_paths(project_root)
  signatures <- build_processed_artifact_extra_signatures(
    artifact_family = artifact_family,
    baseline_table_path = paths$baseline_table_path,
    review_table_path = paths$review_table_path
  )
  signatures <- signatures[!processed_artifact_signatures_unavailable(signatures)]
  c(signatures, vp_trade_builder_version = vp_artifact_builder_version)
}

build_vp_app_ui_country_canonical_map <- function(project_root, source_datasets) {
  paths <- vp_app_ui_metadata_country_harmonization_paths(project_root)
  configured_map <- build_country_canonical_map(
    baseline_table_path = paths$baseline_table_path,
    review_table_path = paths$review_table_path,
    review_generator_path = paths$review_generator_path,
    readme_path = paths$readme_path
  )

  source_rows <- dplyr::bind_rows(lapply(names(source_datasets), function(source_name) {
    source_data <- app_ui_metadata_source_entry_data(source_datasets[[source_name]])
    if (!is.data.frame(source_data) || nrow(source_data) == 0L || !all(c("country", "countryDescription") %in% names(source_data))) {
      return(empty_country_canonical_map())
    }

    source_data %>%
      dplyr::transmute(
        source = source_name,
        legacy_country_code = trimws(as.character(.data$country)),
        legacy_country_label = trimws(as.character(.data$countryDescription)),
        mapping_source_country_code = trimws(as.character(.data$country)),
        canonical_country_code = trimws(as.character(.data$country)),
        canonical_country_label = trimws(as.character(.data$countryDescription)),
        canonical_review_row_id = paste("VP_APP_UI_METADATA_SOURCE", source_name, trimws(as.character(.data$country)), sep = ":")
      )
  }))
  source_map <- standardize_country_canonical_map(source_rows)

  if (!is.data.frame(configured_map) || nrow(configured_map) == 0L) return(source_map)
  if (!is.data.frame(source_map) || nrow(source_map) == 0L) return(configured_map)

  configured_keys <- paste(configured_map$source, configured_map$legacy_country_code, sep = "\r")
  source_keys <- paste(source_map$source, source_map$legacy_country_code, sep = "\r")
  source_missing_from_config <- source_map[!(source_keys %in% configured_keys), , drop = FALSE]
  standardize_country_canonical_map(dplyr::bind_rows(configured_map, source_missing_from_config))
}

vp_app_ui_metadata_country_rows <- function(source_data) {
  if (!is.data.frame(source_data) || nrow(source_data) == 0L || !all(c("country", "countryDescription") %in% names(source_data))) {
    return(data.frame(country = character(), countryDescription = character(), stringsAsFactors = FALSE))
  }

  source_data %>%
    dplyr::transmute(
      country = trimws(as.character(.data$country)),
      countryDescription = trimws(as.character(.data$countryDescription))
    ) %>%
    dplyr::filter(!is.na(.data$country), nzchar(.data$country)) %>%
    dplyr::distinct(.data$country, .data$countryDescription) %>%
    as.data.frame(stringsAsFactors = FALSE)
}

build_vp_app_ui_metadata_source_datasets <- function(project_root, read_artifact_fn = read_processed_artifact_if_current) {
  paths <- vp_paths(project_root)
  vp_trade_data <- read_artifact_fn(
    artifact_path = paths$artifact,
    project_dir = project_root,
    source_paths = paths$input_csv,
    extra_signatures = c(builder_version = vp_artifact_builder_version),
    perf_label = "build_vp_app_ui_metadata(vp_trade)"
  )

  if (is.null(vp_trade_data)) {
    stop("VP app UI metadata cannot be built because the VP trade artifact is missing or stale.", call. = FALSE)
  }

  list(
    vp_trade = list(
      data = vp_app_ui_metadata_country_rows(vp_trade_data),
      source_priority = 1L
    )
  )
}

materialize_vp_app_ui_metadata <- function(project_root, read_artifact_fn = read_processed_artifact_if_current) {
  source_datasets <- build_vp_app_ui_metadata_source_datasets(project_root, read_artifact_fn)
  materialize_app_ui_metadata(
    country_canonical_map = build_vp_app_ui_country_canonical_map(project_root, source_datasets),
    source_datasets = source_datasets
  )
}

validate_vp_app_ui_metadata_artifact <- function(metadata) {
  missing_fields <- setdiff(vp_app_ui_metadata_required_fields(), names(metadata))
  if (length(missing_fields) > 0L) {
    stop(sprintf("VP app UI metadata artifact missing fields: %s", paste(missing_fields, collapse = ", ")), call. = FALSE)
  }

  invisible(TRUE)
}

write_commodity_app_ui_metadata <- function(project_root = NULL, read_artifact_fn = read_processed_artifact_if_current) {
  project_root <- resolve_vp_app_ui_metadata_project_root(project_root)
  contract <- get_commodity_contract(project_root)
  validate_commodity_contract(contract)
  validate_commodity_project_root(project_root, contract)

  metadata <- materialize_vp_app_ui_metadata(project_root, read_artifact_fn)
  validate_vp_app_ui_metadata_artifact(metadata)

  artifact_path <- contract_artifact_path(contract, "app_ui_metadata", project_root)
  source_paths <- vp_paths(project_root)$input_csv
  dir.create(dirname(artifact_path), recursive = TRUE, showWarnings = FALSE)
  write_processed_artifact(
    data = metadata,
    artifact_path = artifact_path,
    project_dir = project_root,
    source_paths = source_paths,
    extra_signatures = build_vp_app_ui_metadata_extra_signatures(project_root, "app_ui_metadata"),
    artifact_metadata = list(
      mode = "enabled_sources",
      metadata_source_entries = "vp_trade",
      missing_artifact_policy = contract$metadata$missing_artifact_policy,
      conflict_policy = contract$metadata$conflict_policy,
      vp_trade_builder_version = vp_artifact_builder_version
    )
  )

  list(
    artifact_path = artifact_path,
    source_count = 1L,
    source_entries = "vp_trade",
    mode = "enabled_sources",
    metadata = metadata
  )
}

vp_app_ui_metadata_builder_running_as_script <- function() {
  command_args <- commandArgs(trailingOnly = FALSE)
  file_arg <- "--file="
  script_arg <- command_args[startsWith(command_args, file_arg)]
  if (length(script_arg) == 0L) return(FALSE)

  script_path <- normalizePath(sub(file_arg, "", script_arg[[1]], fixed = TRUE), winslash = "/", mustWork = FALSE)
  identical(basename(script_path), "Build_App_UI_Metadata.R")
}

if (vp_app_ui_metadata_builder_running_as_script()) {
  result <- write_commodity_app_ui_metadata(project_root = vp_app_ui_metadata_default_project_root)
  cat("VP_APP_UI_METADATA_BUILD_STATUS=PASS\n")
  cat("APP_UI_METADATA_ARTIFACT=", result$artifact_path, "\n", sep = "")
  cat("APP_UI_METADATA_MODE=", result$mode, "\n", sep = "")
  cat("APP_UI_METADATA_SOURCE_COUNT=", result$source_count, "\n", sep = "")
  cat("APP_UI_METADATA_SOURCE_ENTRIES=", paste(result$source_entries, collapse = "|"), "\n", sep = "")
}
