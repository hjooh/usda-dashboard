collapse_unique_text <- function(values) {
  cleaned <- trimws(as.character(values))
  cleaned[!nzchar(cleaned)] <- NA_character_
  cleaned <- unique(cleaned[!is.na(cleaned)])

  if (length(cleaned) == 0) return(NA_character_)
  paste(cleaned[order(cleaned)], collapse = " | ")
}

normalize_text <- function(values) {
  cleaned <- trimws(as.character(values))
  cleaned <- stringr::str_replace_all(cleaned, "\\s+", " ")
  tolower(cleaned)
}

normalize_trade_flow <- function(values) {
  normalized <- normalize_text(values)

  dplyr::case_when(
    normalized %in% c("export", "exports") ~ "export",
    normalized %in% c("import", "imports") ~ "import",
    TRUE ~ NA_character_
  )
}

maybe_log_perf <- function(tag, start_time, details = list()) {
  if (is.null(tag) || length(tag) == 0 || is.null(start_time)) {
    return(invisible(NULL))
  }

  log_perf_fn <- get0("log_perf", mode = "function", inherits = TRUE)
  if (!is.function(log_perf_fn)) {
    return(invisible(NULL))
  }

  log_perf_fn(tag, start_time, details = details)
  invisible(NULL)
}

canonical_country_label_from_code <- function(values) {
  cleaned <- trimws(as.character(values))
  cleaned[!nzchar(cleaned)] <- NA_character_
  ifelse(is.na(cleaned), NA_character_, stringr::str_to_title(tolower(cleaned)))
}

empty_country_canonical_map <- function() {
  tibble(
    source = character(),
    legacy_country_code = character(),
    legacy_country_label = character(),
    mapping_source_country_code = character(),
    canonical_country_code = character(),
    canonical_country_label = character(),
    canonical_review_row_id = character()
  )
}

empty_review_country_mapping_table <- function() {
  tibble(
    review_row_id = character(),
    review_bucket = character(),
    confidence = character(),
    normalized_country_label = character(),
    source_codes_match = character(),
    export_country_code = character(),
    export_source_country_code = character(),
    export_country_label_raw = character(),
    export_country_label_normalized = character(),
    census_country_code = character(),
    census_source_country_code = character(),
    census_country_label_raw = character(),
    census_country_label_normalized = character(),
    psd_country_code = character(),
    psd_source_country_code = character(),
    psd_country_label_raw = character(),
    psd_country_label_normalized = character(),
    suggested_action = character(),
    current_hybrid_risk = character(),
    review_decision = character(),
    canonical_country_code = character(),
    review_notes = character()
  )
}

standardize_review_country_mapping_table <- function(review_table) {
  empty_table <- empty_review_country_mapping_table()
  required_cols <- names(empty_table)

  if (!is.data.frame(review_table) || nrow(review_table) == 0) {
    return(empty_table)
  }

  out <- as_tibble(review_table)
  for (col_name in required_cols) {
    if (!col_name %in% names(out)) out[[col_name]] <- ""
  }

  out %>%
    mutate(across(all_of(required_cols), ~ trimws(as.character(.x)))) %>%
    select(all_of(required_cols))
}

resolve_review_canonical_country_code <- function(review_df) {
  dplyr::case_when(
    nzchar(review_df$canonical_country_code) ~ review_df$canonical_country_code,
    nzchar(review_df$psd_country_code) ~ review_df$psd_country_code,
    nzchar(review_df$census_country_code) ~ review_df$census_country_code,
    nzchar(review_df$export_country_code) ~ review_df$export_country_code,
    TRUE ~ ""
  )
}

resolve_review_canonical_country_label <- function(review_df, canonical_country_code) {
  canonical_label <- dplyr::case_when(
    nzchar(review_df$psd_country_label_raw) ~ review_df$psd_country_label_raw,
    nzchar(review_df$census_country_label_raw) ~ review_df$census_country_label_raw,
    nzchar(review_df$export_country_label_raw) ~ review_df$export_country_label_raw,
    TRUE ~ canonical_country_label_from_code(canonical_country_code)
  )

  canonical_label <- trimws(as.character(canonical_label))
  canonical_label[canonical_country_code %in% c("GRAND_TOTAL", "WORLD")] <- "World"
  canonical_label
}

standardize_country_canonical_map <- function(map_df, review_row_prefix = NULL) {
  empty_map <- empty_country_canonical_map()
  required_cols <- names(empty_map)

  if (!is.data.frame(map_df) || nrow(map_df) == 0) return(empty_map)

  out <- as_tibble(map_df)
  for (col_name in required_cols) {
    if (!col_name %in% names(out)) out[[col_name]] <- ""
  }

  out <- out %>%
    transmute(
      source = trimws(as.character(.data$source)),
      legacy_country_code = trimws(as.character(.data$legacy_country_code)),
      legacy_country_label = trimws(as.character(.data$legacy_country_label)),
      mapping_source_country_code = trimws(as.character(.data$mapping_source_country_code)),
      canonical_country_code = trimws(as.character(.data$canonical_country_code)),
      canonical_country_label = trimws(as.character(.data$canonical_country_label)),
      canonical_review_row_id = trimws(as.character(.data$canonical_review_row_id))
    ) %>%
    filter(nzchar(.data$source), nzchar(.data$legacy_country_code)) %>%
    mutate(
      canonical_country_label = dplyr::if_else(
        nzchar(.data$canonical_country_label),
        .data$canonical_country_label,
        canonical_country_label_from_code(.data$canonical_country_code)
      ),
      canonical_review_row_id = dplyr::if_else(
        nzchar(.data$canonical_review_row_id),
        .data$canonical_review_row_id,
        if (is.null(review_row_prefix)) "" else paste(review_row_prefix, .data$source, .data$legacy_country_code, sep = ":")
      )
    ) %>%
    distinct(source, legacy_country_code, .keep_all = TRUE)

  if (nrow(out) == 0) empty_map else out
}

load_baseline_country_canonical_map <- function(baseline_table_path) {
  if (!file.exists(baseline_table_path)) return(empty_country_canonical_map())

  baseline_map <- tryCatch(
    read.csv(baseline_table_path, stringsAsFactors = FALSE),
    error = function(...) empty_country_canonical_map()
  )

  standardize_country_canonical_map(baseline_map, review_row_prefix = "BASELINE")
}

load_review_country_canonical_overlay <- function(review_table_path) {
  empty_map <- empty_country_canonical_map()

  if (!file.exists(review_table_path)) return(empty_map)

  review_table <- tryCatch(
    read.csv(review_table_path, stringsAsFactors = FALSE),
    error = function(...) empty_map
  )

  review_table <- standardize_review_country_mapping_table(review_table)
  if (!is.data.frame(review_table) || nrow(review_table) == 0) return(empty_map)

  approved_rows <- review_table %>%
    filter(
      .data$review_bucket %in% c("same_country_code_label_diff", "same_normalized_label_different_code") |
        .data$review_decision %in% c("approve_alias_high_confidence", "approve_display_harmonization")
    ) %>%
    mutate(
      canonical_country_code = resolve_review_canonical_country_code(pick(everything())),
      canonical_country_label = resolve_review_canonical_country_label(pick(everything()), .data$canonical_country_code)
    ) %>%
    filter(nzchar(.data$canonical_country_code))

  export_map <- approved_rows %>%
    filter(nzchar(.data$export_country_code)) %>%
    transmute(
      source = "export_sales",
      legacy_country_code = .data$export_country_code,
      legacy_country_label = dplyr::coalesce(dplyr::na_if(.data$export_country_label_raw, ""), .data$export_country_code),
      mapping_source_country_code = .data$export_source_country_code,
      canonical_country_code = .data$canonical_country_code,
      canonical_country_label = .data$canonical_country_label,
      canonical_review_row_id = .data$review_row_id
    )

  census_map <- approved_rows %>%
    filter(nzchar(.data$census_country_code)) %>%
    transmute(
      source = "census",
      legacy_country_code = .data$census_country_code,
      legacy_country_label = dplyr::coalesce(dplyr::na_if(.data$census_country_label_raw, ""), .data$census_country_code),
      mapping_source_country_code = .data$census_source_country_code,
      canonical_country_code = .data$canonical_country_code,
      canonical_country_label = .data$canonical_country_label,
      canonical_review_row_id = .data$review_row_id
    )

  psd_map <- approved_rows %>%
    filter(nzchar(.data$psd_country_code)) %>%
    transmute(
      source = "psd",
      legacy_country_code = .data$psd_country_code,
      legacy_country_label = dplyr::coalesce(dplyr::na_if(.data$psd_country_label_raw, ""), .data$psd_country_code),
      mapping_source_country_code = .data$psd_source_country_code,
      canonical_country_code = .data$canonical_country_code,
      canonical_country_label = .data$canonical_country_label,
      canonical_review_row_id = .data$review_row_id
    )

  bind_rows(export_map, census_map, psd_map) %>%
    standardize_country_canonical_map()
}

compose_country_canonical_map <- function(baseline_map, review_map) {
  bind_rows(review_map, baseline_map) %>%
    standardize_country_canonical_map()
}

harmonization_refresh_enabled <- function() {
  isTRUE(getOption("rice_harmonization", FALSE))
}

ensure_country_review_overlay_ready <- function(review_table_path, review_generator_path, readme_path) {
  if (!harmonization_refresh_enabled()) return(invisible(FALSE))
  if (file.exists(review_table_path)) return(invisible(FALSE))
  if (!file.exists(review_generator_path)) return(invisible(FALSE))
  if (isTRUE(getOption("rice_running_harmonization_bootstrap", FALSE))) return(invisible(FALSE))
  if (!isTRUE(getOption("rice_use_canonical_country_map", TRUE))) return(invisible(FALSE))

  prior_wd <- getwd()
  prior_guard <- getOption("rice_running_harmonization_bootstrap", FALSE)
  prior_canonical_option <- getOption("rice_use_canonical_country_map", TRUE)

  on.exit({
    options(rice_running_harmonization_bootstrap = prior_guard)
    options(rice_use_canonical_country_map = prior_canonical_option)
    setwd(prior_wd)
  }, add = TRUE)

  options(rice_running_harmonization_bootstrap = TRUE)
  source(review_generator_path, local = new.env(parent = globalenv()))

  regenerated <- file.exists(review_table_path)
  if (regenerated) {
    message(
      sprintf(
        "Rice harmonization review table was regenerated automatically. See %s for approval and remap guidance.",
        readme_path
      )
    )
  }

  invisible(regenerated)
}

canonicalize_country_dataset <- function(df, source_name, canonical_map) {
  if (!is.data.frame(df) || nrow(df) == 0) return(df)

  source_map <- canonical_map %>%
    filter(.data$source == source_name) %>%
    select(-source)

  out <- df %>%
    mutate(
      country = trimws(as.character(.data$country)),
      countryDescription = trimws(as.character(.data$countryDescription)),
      country_legacy_code = trimws(as.character(.data$country)),
      countryDescription_legacy = trimws(as.character(.data$countryDescription))
    )

  if (nrow(source_map) == 0) {
    return(
      out %>% mutate(canonical_review_row_id = NA_character_)
    )
  }

  out %>%
    left_join(source_map, by = c("country_legacy_code" = "legacy_country_code")) %>%
    mutate(
      country = dplyr::if_else(
        !is.na(.data$canonical_country_code) & nzchar(.data$canonical_country_code),
        .data$canonical_country_code,
        .data$country_legacy_code
      ),
      countryDescription = dplyr::if_else(
        !is.na(.data$canonical_country_label) & nzchar(.data$canonical_country_label),
        .data$canonical_country_label,
        .data$countryDescription_legacy
      ),
      canonical_review_row_id = dplyr::na_if(.data$canonical_review_row_id, "")
    ) %>%
    select(-legacy_country_label, -mapping_source_country_code, -canonical_country_code, -canonical_country_label)
}

build_country_canonical_map <- function(baseline_table_path, review_table_path, review_generator_path, readme_path) {
  if (isFALSE(getOption("rice_use_canonical_country_map", TRUE))) {
    return(empty_country_canonical_map())
  }

  baseline_country_canonical_map <- load_baseline_country_canonical_map(baseline_table_path)

  if (harmonization_refresh_enabled()) {
    ensure_country_review_overlay_ready(
      review_table_path = review_table_path,
      review_generator_path = review_generator_path,
      readme_path = readme_path
    )
  }

  review_country_canonical_overlay <- if (harmonization_refresh_enabled()) {
    load_review_country_canonical_overlay(review_table_path)
  } else {
    empty_country_canonical_map()
  }

  compose_country_canonical_map(
    baseline_map = baseline_country_canonical_map,
    review_map = review_country_canonical_overlay
  )
}

safe_max_num <- function(value) {
  if (all(is.na(value))) return(NA_real_)
  suppressWarnings(max(value, na.rm = TRUE))
}

safe_max_date <- function(value) {
  if (all(is.na(value))) return(as.Date(NA))
  suppressWarnings(max(value, na.rm = TRUE))
}

safe_min_date <- function(value) {
  if (all(is.na(value))) return(as.Date(NA))
  suppressWarnings(min(value, na.rm = TRUE))
}

artifact_path_to_slash <- function(path) {
  if (length(path) == 0) return(character())
  path <- gsub("\\\\", "/", as.character(path))
  path <- gsub("/+", "/", path)
  sub("/+$", "", path)
}

artifact_identity_compare_values <- function(ids) {
  ids <- artifact_path_to_slash(ids)
  ids <- sub("^\\./+", "", ids)
  if (identical(.Platform$OS.type, "windows")) ids <- tolower(ids)
  ids
}

artifact_identity_vectors_equal <- function(expected, actual) {
  identical(
    artifact_identity_compare_values(expected),
    artifact_identity_compare_values(actual)
  )
}

normalize_artifact_id <- function(id) {
  id <- artifact_path_to_slash(id)
  id <- sub("^/+", "", id)
  sub("^\\./+", "", id)
}

artifact_relative_path <- function(path, project_dir) {
  path <- artifact_path_to_slash(path)
  project_dir <- artifact_path_to_slash(project_dir)
  path_cmp <- artifact_identity_compare_values(path)
  project_cmp <- artifact_identity_compare_values(project_dir)

  if (identical(path_cmp, project_cmp)) return("")

  project_prefix <- paste0(project_cmp, "/")
  if (!startsWith(path_cmp, project_prefix)) return(NA_character_)

  substring(path, nchar(project_dir) + 2L)
}

artifact_make_absolute_path <- function(path) {
  path <- artifact_path_to_slash(path)
  if (grepl("^[A-Za-z]:/", path) || startsWith(path, "/")) return(path)
  artifact_path_to_slash(file.path(getwd(), path))
}

artifact_source_identity_anchors <- function() {
  c("Output", "System", "Programs", "Documentation")
}

salvage_artifact_source_id <- function(path, project_dir) {
  components <- unlist(strsplit(artifact_path_to_slash(path), "/", fixed = TRUE), use.names = FALSE)
  components <- components[nzchar(components)]
  if (length(components) == 0) return(NA_character_)

  anchors <- artifact_source_identity_anchors()
  anchor_lookup <- stats::setNames(anchors, tolower(anchors))
  candidate_ids <- character()

  for (idx in seq_along(components)) {
    anchor_key <- tolower(components[[idx]])
    if (!anchor_key %in% names(anchor_lookup)) next

    suffix <- components[idx:length(components)]
    suffix[[1]] <- unname(anchor_lookup[[anchor_key]])
    candidate_id <- normalize_artifact_id(paste(suffix, collapse = "/"))
    candidate_path <- file.path(project_dir, candidate_id)

    if (file.exists(candidate_path) || dir.exists(candidate_path)) {
      candidate_ids <- c(candidate_ids, candidate_id)
    }
  }

  if (length(candidate_ids) == 0) return(NA_character_)

  candidate_compare <- artifact_identity_compare_values(candidate_ids)
  unique_candidates <- candidate_ids[!duplicated(candidate_compare)]
  if (length(unique_candidates) != 1) return(NA_character_)

  unname(unique_candidates[[1]])
}

build_artifact_source_id <- function(path, project_dir) {
  if (length(path) != 1 || is.na(path) || !nzchar(path)) return("unresolved|missing_path")

  raw_project_root <- artifact_make_absolute_path(project_dir)
  raw_relative_id <- artifact_relative_path(artifact_make_absolute_path(path), raw_project_root)
  if (!is.na(raw_relative_id)) return(normalize_artifact_id(raw_relative_id))

  project_root <- normalize_artifact_path(project_dir, must_work = TRUE)
  raw_relative_id <- artifact_relative_path(artifact_make_absolute_path(path), project_root)
  if (!is.na(raw_relative_id)) return(normalize_artifact_id(raw_relative_id))

  normalized_path <- normalize_artifact_path(path, must_work = file.exists(path))
  relative_id <- artifact_relative_path(normalized_path, project_root)

  if (!is.na(relative_id)) return(normalize_artifact_id(relative_id))

  salvaged_id <- salvage_artifact_source_id(normalized_path, project_root)
  if (!is.na(salvaged_id)) return(salvaged_id)

  paste("unresolved", artifact_path_to_slash(normalized_path), sep = "|")
}

build_artifact_source_ids <- function(paths, project_dir) {
  if (length(paths) == 0) return(character())
  unname(vapply(paths, build_artifact_source_id, character(1), project_dir = project_dir))
}

.file_signature_cache <- new.env(parent = emptyenv())

clear_file_signature_cache <- function() {
  rm(list = ls(.file_signature_cache, all.names = TRUE), envir = .file_signature_cache)
  invisible(TRUE)
}

build_file_signature_cache_key <- function(path, file_exists, file_size, file_mtime) {
  normalized_path <- suppressWarnings(normalizePath(path, winslash = "/", mustWork = FALSE))
  paste(
    normalized_path,
    if (isTRUE(file_exists)) "exists" else "missing",
    if (!is.na(file_size)) as.character(file_size) else "NA",
    if (!is.na(file_mtime)) as.character(file_mtime) else "NA",
    sep = "\r"
  )
}

build_file_signature <- function(path) {
  signature_start_time <- Sys.time()
  signature_mode <- "missing"
  signature_status <- "missing"
  file_size <- NA_real_
  file_mtime <- NA_real_
  signature <- "missing"
  signature_cache_enabled <- isTRUE(getOption("rice_file_signature_cache_enabled", TRUE))
  file_exists <- file.exists(path)

  if (file_exists) {
    info <- file.info(path)
    file_size <- suppressWarnings(as.numeric(info$size[[1]]))
    file_mtime <- suppressWarnings(as.numeric(info$mtime[[1]]))

    cache_key <- build_file_signature_cache_key(path, TRUE, file_size, file_mtime)
    if (isTRUE(signature_cache_enabled) && exists(cache_key, envir = .file_signature_cache, inherits = FALSE)) {
      cached_signature <- get(cache_key, envir = .file_signature_cache, inherits = FALSE)
      maybe_log_perf(
        "artifact_signature(build_file_signature)",
        signature_start_time,
        details = list(
          path = basename(path),
          file_size_bytes = if (!is.na(file_size)) as.character(file_size) else NA_character_,
          file_size_mb = if (!is.na(file_size)) round(file_size / 1024^2, 3) else NA_real_,
          signature_mode = cached_signature$signature_mode,
          status = "cache_hit"
        )
      )
      return(cached_signature$signature)
    }

    file_hash <- tryCatch(
      unname(tools::md5sum(path)),
      error = function(...) NA_character_
    )

    if (length(file_hash) == 1 && !is.na(file_hash) && nzchar(file_hash) && !is.na(file_size)) {
      signature_mode <- "md5"
      signature_status <- "ok"
      signature <- paste("md5", file_hash, as.character(file_size), sep = "|")
    } else {
      signature_mode <- "hash_unavailable"
      signature_status <- "hash_unavailable"
      signature <- paste("hash_unavailable", as.character(file_size), sep = "|")
    }

    if (isTRUE(signature_cache_enabled)) {
      assign(
        cache_key,
        list(signature = signature, signature_mode = signature_mode),
        envir = .file_signature_cache
      )
    }
  }

  maybe_log_perf(
    "artifact_signature(build_file_signature)",
    signature_start_time,
    details = list(
      path = basename(path),
      file_size_bytes = if (!is.na(file_size)) as.character(file_size) else NA_character_,
      file_size_mb = if (!is.na(file_size)) round(file_size / 1024^2, 3) else NA_real_,
      signature_mode = signature_mode,
      status = signature_status
    )
  )

  signature
}

normalize_artifact_path <- function(path, must_work = TRUE) {
  normalized <- suppressWarnings(normalizePath(path, winslash = "/", mustWork = must_work))
  unname(as.character(normalized))
}

normalize_artifact_paths <- function(paths, must_work = TRUE) {
  if (length(paths) == 0) return(character())
  unname(vapply(paths, normalize_artifact_path, character(1), must_work = must_work))
}

normalize_processed_artifact_signature <- function(signature) {
  if (length(signature) != 1 || is.na(signature) || !nzchar(signature)) {
    return("signature_unavailable|empty")
  }

  signature <- as.character(signature)
  parts <- unlist(strsplit(signature, "|", fixed = TRUE), use.names = FALSE)

  if (length(parts) == 3 && identical(parts[[1]], "md5")) {
    return(signature)
  }

  if (length(parts) >= 4 && identical(parts[[length(parts) - 2L]], "md5")) {
    return(paste("md5", parts[[length(parts) - 1L]], parts[[length(parts)]], sep = "|"))
  }

  if (length(parts) == 1 && identical(parts[[1]], "missing")) return("missing")
  if (length(parts) >= 2 && identical(parts[[length(parts)]], "missing")) return("missing")

  if (length(parts) >= 1 && identical(parts[[1]], "hash_unavailable")) return(signature)
  if (length(parts) >= 1 && identical(parts[[1]], "signature_unavailable")) return(signature)

  if (any(parts == "mtime_size") || length(parts) == 3) {
    return("signature_unavailable|mtime_size")
  }

  signature
}

normalize_processed_artifact_signatures <- function(signatures) {
  if (length(signatures) == 0) return(character())
  unname(vapply(signatures, normalize_processed_artifact_signature, character(1)))
}

processed_artifact_signatures_unavailable <- function(signatures) {
  signatures <- normalize_processed_artifact_signatures(signatures)
  is.na(signatures) |
    signatures == "missing" |
    startsWith(signatures, "hash_unavailable|") |
    startsWith(signatures, "signature_unavailable|")
}

get_processed_data_dir <- function(project_dir) {
  file.path(project_dir, "System", "Processed Data")
}

build_processed_artifact_filename <- function(csv_filename) {
  csv_base <- basename(csv_filename)
  if (!grepl("\\.csv$", csv_base, ignore.case = TRUE)) {
    stop("Processed artifact filenames must be derived from CSV basenames.", call. = FALSE)
  }

  sub("\\.csv$", "_pre.rds", csv_base, ignore.case = TRUE)
}

build_processed_artifact_path <- function(project_dir, csv_filename) {
  file.path(get_processed_data_dir(project_dir), build_processed_artifact_filename(csv_filename))
}

resolve_preferred_path <- function(preferred_path, legacy_paths = character()) {
  candidate_paths <- unique(c(preferred_path, legacy_paths))
  existing_paths <- candidate_paths[file.exists(candidate_paths)]

  if (length(existing_paths) > 0) {
    return(normalize_artifact_path(existing_paths[[1]], must_work = TRUE))
  }

  preferred_path
}

get_processed_artifact_manifest_path <- function(project_dir) {
  file.path(get_processed_data_dir(project_dir), "processed_artifacts_manifest.rds")
}

get_psd_release_archive_dir <- function(project_dir) {
  file.path(get_processed_data_dir(project_dir), "PSD Release Archive")
}

get_psd_release_archive_manifest_path <- function(project_dir) {
  file.path(get_psd_release_archive_dir(project_dir), "psd_release_archive_manifest.rds")
}

normalize_psd_release_key <- function(value) {
  if (length(value) == 0 || is.null(value)) return(NA_integer_)
  value <- value[[1]]
  if (is.na(value)) return(NA_integer_)

  if (is.character(value)) {
    trimmed <- trimws(value)
    if (!nzchar(trimmed)) return(NA_integer_)
    if (grepl("^[0-9]{4}[-_/][0-9]{1,2}$", trimmed)) {
      parts <- strsplit(trimmed, "[-_/]")[[1]]
      year <- suppressWarnings(as.integer(parts[[1]]))
      month <- suppressWarnings(as.integer(parts[[2]]))
      if (!is.na(year) && !is.na(month) && month >= 1L && month <= 12L) {
        return(as.integer(year * 100L + month))
      }
    }
  }

  numeric_value <- suppressWarnings(as.integer(value))
  if (is.na(numeric_value)) return(NA_integer_)
  year <- numeric_value %/% 100L
  month <- numeric_value %% 100L
  if (year < 1900L || month < 1L || month > 12L) return(NA_integer_)
  numeric_value
}

format_psd_release_period <- function(release_key) {
  release_key <- normalize_psd_release_key(release_key)
  if (is.na(release_key)) return(NA_character_)
  sprintf("%04d-%02d", release_key %/% 100L, release_key %% 100L)
}

derive_psd_release_key_from_data <- function(data) {
  if (!is.data.frame(data) || nrow(data) == 0) return(NA_integer_)

  release_keys <- integer()
  if (all(c("release_year", "release_month") %in% names(data))) {
    release_year <- suppressWarnings(as.integer(data$release_year))
    release_month <- suppressWarnings(as.integer(data$release_month))
    release_keys <- c(release_keys, release_year * 100L + release_month)
  }

  if ("release_period" %in% names(data)) {
    release_keys <- c(
      release_keys,
      unname(vapply(unique(data$release_period), normalize_psd_release_key, integer(1)))
    )
  }

  release_keys <- release_keys[!is.na(release_keys)]
  if (length(release_keys) == 0) return(NA_integer_)
  max(release_keys)
}

derive_prior_psd_release_key <- function(current_release_key) {
  current_release_key <- normalize_psd_release_key(current_release_key)
  if (is.na(current_release_key)) return(NA_integer_)

  release_year <- current_release_key %/% 100L
  release_month <- current_release_key %% 100L
  if (release_month == 1L) {
    return(as.integer((release_year - 1L) * 100L + 12L))
  }

  as.integer(release_year * 100L + release_month - 1L)
}

resolve_manual_prior_psd_release_key <- function(current_release_key = NULL, current_psd_data = NULL, prior_release_override = NULL) {
  override_key <- normalize_psd_release_key(prior_release_override)
  if (!is.na(override_key)) return(override_key)

  resolved_current_key <- normalize_psd_release_key(current_release_key)
  if (is.na(resolved_current_key) && !is.null(current_psd_data)) {
    resolved_current_key <- derive_psd_release_key_from_data(current_psd_data)
  }

  derive_prior_psd_release_key(resolved_current_key)
}

psd_manual_prior_canonical_folder <- function(input_root, prior_release_key) {
  prior_release_period <- format_psd_release_period(prior_release_key)
  if (is.na(prior_release_period)) return(NA_character_)
  file.path(input_root, prior_release_period)
}

read_psd_release_archive_manifest_with_status <- function(project_dir, manifest_path = get_psd_release_archive_manifest_path(project_dir)) {
  if (!file.exists(manifest_path)) {
    return(list(
      ok = FALSE,
      reason = "manifest_missing",
      detail = paste("PSD release archive manifest not found:", manifest_path),
      manifest = list()
    ))
  }

  manifest <- tryCatch(
    readRDS(manifest_path),
    error = function(e) e
  )

  if (inherits(manifest, "error")) {
    return(list(
      ok = FALSE,
      reason = "manifest_read_error",
      detail = conditionMessage(manifest),
      manifest = list()
    ))
  }

  if (!is.list(manifest)) {
    return(list(
      ok = FALSE,
      reason = "manifest_invalid",
      detail = paste("Manifest class:", paste(class(manifest), collapse = "/")),
      manifest = list()
    ))
  }

  list(
    ok = TRUE,
    reason = "manifest_current",
    detail = "PSD release archive manifest read successfully",
    manifest = manifest
  )
}

read_psd_release_archive_manifest <- function(project_dir, manifest_path = get_psd_release_archive_manifest_path(project_dir)) {
  read_psd_release_archive_manifest_with_status(project_dir, manifest_path = manifest_path)$manifest
}

write_psd_release_archive_manifest <- function(project_dir, manifest, manifest_path = get_psd_release_archive_manifest_path(project_dir)) {
  archive_dir <- dirname(manifest_path)
  if (!dir.exists(archive_dir)) dir.create(archive_dir, recursive = TRUE)
  safe_write_rds(manifest, manifest_path)
}

psd_release_archive_manifest_key <- function(artifact_role, archive_release_period) {
  paste(artifact_role, archive_release_period, sep = "|")
}

psd_release_archive_entry_matches <- function(entry, archive_release_period, artifact_role, source_artifact_signature) {
  entry_archive_release_period <- if (is.null(entry$archive_release_period)) NA_character_ else entry$archive_release_period
  entry_artifact_role <- if (is.null(entry$artifact_role)) NA_character_ else entry$artifact_role
  entry_source_artifact_signature <- if (is.null(entry$source_artifact_signature)) NA_character_ else entry$source_artifact_signature

  is.list(entry) &&
    identical(as.character(entry_archive_release_period), as.character(archive_release_period)) &&
    identical(as.character(entry_artifact_role), as.character(artifact_role)) &&
    identical(as.character(entry_source_artifact_signature), as.character(source_artifact_signature))
}

psd_archive_rollover_decision <- function(current_release_key, candidate_release_key, current_artifact_signature, archive_manifest = list(), artifact_role = "psd_rice_my_pre") {
  current_key <- normalize_psd_release_key(current_release_key)
  candidate_key <- normalize_psd_release_key(candidate_release_key)

  if (is.na(current_key) || is.na(candidate_key)) {
    return(list(
      action = "noop_missing_release_key",
      should_archive = FALSE,
      current_release_key = current_key,
      candidate_release_key = candidate_key,
      reason = "missing_or_ambiguous_release_key"
    ))
  }

  if (is.null(current_artifact_signature)) current_artifact_signature <- NA_character_
  current_artifact_signature <- normalize_processed_artifact_signature(current_artifact_signature)
  if (processed_artifact_signatures_unavailable(current_artifact_signature)) {
    return(list(
      action = "skip_missing_current",
      should_archive = FALSE,
      current_release_key = current_key,
      candidate_release_key = candidate_key,
      reason = "current_artifact_missing_or_signature_unavailable"
    ))
  }

  if (candidate_key <= current_key) {
    return(list(
      action = "noop_same_release",
      should_archive = FALSE,
      current_release_key = current_key,
      candidate_release_key = candidate_key,
      reason = "candidate_release_not_newer"
    ))
  }

  archive_release_period <- format_psd_release_period(current_key)
  existing_match <- any(vapply(
    archive_manifest,
    psd_release_archive_entry_matches,
    logical(1),
    archive_release_period = archive_release_period,
    artifact_role = artifact_role,
    source_artifact_signature = current_artifact_signature
  ))

  if (isTRUE(existing_match)) {
    return(list(
      action = "noop_existing_archive",
      should_archive = FALSE,
      current_release_key = current_key,
      candidate_release_key = candidate_key,
      archive_release_period = archive_release_period,
      reason = "matching_archive_already_exists"
    ))
  }

  list(
    action = "archive",
    should_archive = TRUE,
    current_release_key = current_key,
    candidate_release_key = candidate_key,
    archive_release_period = archive_release_period,
    candidate_release_period = format_psd_release_period(candidate_key),
    reason = "candidate_release_newer"
  )
}

psd_release_archive_destination_path <- function(archive_dir, artifact_path, archive_release_period) {
  artifact_ext <- tools::file_ext(artifact_path)
  artifact_stem <- if (nzchar(artifact_ext)) {
    sub(paste0("\\.", artifact_ext, "$"), "", basename(artifact_path))
  } else {
    basename(artifact_path)
  }
  file.path(archive_dir, paste0(artifact_stem, "_", archive_release_period, if (nzchar(artifact_ext)) paste0(".", artifact_ext) else ""))
}

psd_release_archive_row_count <- function(path) {
  object <- tryCatch(readRDS(path), error = function(...) NULL)
  if (is.data.frame(object)) return(nrow(object))
  if (is.null(object)) return(NA_integer_)
  length(object)
}

materialize_psd_release_archive <- function(project_dir, artifact_paths, archive_release_key, candidate_release_key, archive_reason = "release_rollover", development_placeholder = FALSE, simulated_delta_active = FALSE, archive_dir = get_psd_release_archive_dir(project_dir), manifest_path = get_psd_release_archive_manifest_path(project_dir)) {
  archive_release_period <- format_psd_release_period(archive_release_key)
  candidate_release_period <- format_psd_release_period(candidate_release_key)
  if (is.na(archive_release_period)) stop("A finite archive release key is required.", call. = FALSE)
  if (length(artifact_paths) == 0) stop("At least one PSD artifact path is required for archive materialization.", call. = FALSE)
  if (!dir.exists(archive_dir)) dir.create(archive_dir, recursive = TRUE)

  artifact_roles <- names(artifact_paths)
  artifact_paths <- as.character(artifact_paths)
  if (is.null(artifact_roles) || any(!nzchar(artifact_roles))) {
    artifact_roles <- sub("\\.rds$", "", basename(artifact_paths), ignore.case = TRUE)
  }

  manifest <- read_psd_release_archive_manifest(project_dir, manifest_path = manifest_path)
  pending_entries <- list()

  for (artifact_idx in seq_along(artifact_paths)) {
    artifact_path <- artifact_paths[[artifact_idx]]
    artifact_role <- artifact_roles[[artifact_idx]]
    if (!file.exists(artifact_path)) stop("PSD artifact not found for archive materialization: ", artifact_path, call. = FALSE)

    source_signature <- normalize_processed_artifact_signature(build_file_signature(artifact_path))
    destination_path <- psd_release_archive_destination_path(archive_dir, artifact_path, archive_release_period)
    destination_signature <- if (file.exists(destination_path)) normalize_processed_artifact_signature(build_file_signature(destination_path)) else NA_character_

    if (file.exists(destination_path) && !identical(destination_signature, source_signature)) {
      stop("Existing PSD archive artifact has a different signature: ", destination_path, call. = FALSE)
    }

    if (!file.exists(destination_path)) {
      temp_path <- tempfile(paste0(basename(destination_path), "."), tmpdir = archive_dir, fileext = ".tmp")
      copied <- file.copy(artifact_path, temp_path, overwrite = TRUE)
      if (!isTRUE(copied)) stop("Unable to copy PSD artifact to archive temp path: ", temp_path, call. = FALSE)

      temp_signature <- normalize_processed_artifact_signature(build_file_signature(temp_path))
      if (!identical(temp_signature, source_signature)) {
        unlink(temp_path)
        stop("PSD archive temp copy signature mismatch for ", artifact_path, ".", call. = FALSE)
      }

      renamed <- file.rename(temp_path, destination_path)
      if (!isTRUE(renamed)) {
        copied_final <- file.copy(temp_path, destination_path, overwrite = FALSE)
        unlink(temp_path)
        if (!isTRUE(copied_final)) stop("Unable to promote PSD archive artifact: ", destination_path, call. = FALSE)
      }
    }

    archived_signature <- normalize_processed_artifact_signature(build_file_signature(destination_path))
    if (!identical(archived_signature, source_signature)) {
      stop("PSD archive artifact signature mismatch after promotion for ", destination_path, ".", call. = FALSE)
    }

    source_row_count <- psd_release_archive_row_count(artifact_path)
    archived_row_count <- psd_release_archive_row_count(destination_path)
    if (!identical(source_row_count, archived_row_count)) {
      stop("PSD archive artifact row-count mismatch after promotion for ", destination_path, ".", call. = FALSE)
    }

    entry_key <- psd_release_archive_manifest_key(artifact_role, archive_release_period)
    pending_entries[[entry_key]] <- list(
      archive_release_period = archive_release_period,
      archive_release_label = archive_release_period,
      candidate_release_period = candidate_release_period,
      archive_created_at_utc = format(as.POSIXct(Sys.time(), tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ"),
      archive_reason = archive_reason,
      source_artifact_path = normalize_artifact_path(artifact_path, must_work = TRUE),
      source_artifact_signature = source_signature,
      archived_artifact_path = normalize_artifact_path(destination_path, must_work = TRUE),
      archived_artifact_signature = archived_signature,
      row_count = archived_row_count,
      artifact_role = artifact_role,
      development_placeholder = isTRUE(development_placeholder),
      simulated_delta_active = isTRUE(simulated_delta_active)
    )
  }

  manifest[names(pending_entries)] <- pending_entries
  write_psd_release_archive_manifest(project_dir, manifest, manifest_path = manifest_path)
  invisible(list(
    ok = TRUE,
    archive_release_period = archive_release_period,
    candidate_release_period = candidate_release_period,
    manifest_path = manifest_path,
    entries = pending_entries
  ))
}

archive_existing_psd_processed_artifacts_before_overwrite <- function(project_dir, candidate_data, artifact_paths, main_artifact_role = "psd_rice_my_pre", archive_reason = "release_rollover") {
  candidate_release_key <- derive_psd_release_key_from_data(candidate_data)
  artifact_roles <- names(artifact_paths)
  artifact_paths <- as.character(artifact_paths)
  if (is.null(artifact_roles) || any(!nzchar(artifact_roles))) {
    artifact_roles <- sub("\\.rds$", "", basename(artifact_paths), ignore.case = TRUE)
  }
  names(artifact_paths) <- artifact_roles

  main_artifact_path <- artifact_paths[[main_artifact_role]]
  if (is.null(main_artifact_path)) main_artifact_path <- artifact_paths[[1]]
  if (is.null(main_artifact_path) || !file.exists(main_artifact_path)) {
    return(list(
      action = "skip_missing_current",
      should_archive = FALSE,
      reason = "main_current_artifact_missing",
      candidate_release_key = candidate_release_key
    ))
  }

  current_data <- tryCatch(readRDS(main_artifact_path), error = function(e) e)
  if (inherits(current_data, "error")) {
    return(list(
      action = "skip_unreadable_current",
      should_archive = FALSE,
      reason = conditionMessage(current_data),
      candidate_release_key = candidate_release_key
    ))
  }

  current_release_key <- derive_psd_release_key_from_data(current_data)
  current_artifact_signature <- build_file_signature(main_artifact_path)
  archive_manifest <- read_psd_release_archive_manifest(project_dir)
  decision <- psd_archive_rollover_decision(
    current_release_key = current_release_key,
    candidate_release_key = candidate_release_key,
    current_artifact_signature = current_artifact_signature,
    archive_manifest = archive_manifest,
    artifact_role = main_artifact_role
  )

  decision$current_artifact_path <- main_artifact_path
  decision$current_artifact_signature <- normalize_processed_artifact_signature(current_artifact_signature)

  if (!isTRUE(decision$should_archive)) return(decision)

  existing_artifact_paths <- artifact_paths[file.exists(artifact_paths)]
  archive_result <- materialize_psd_release_archive(
    project_dir = project_dir,
    artifact_paths = existing_artifact_paths,
    archive_release_key = current_release_key,
    candidate_release_key = candidate_release_key,
    archive_reason = archive_reason
  )
  decision$archive_result <- archive_result
  decision
}

safe_write_rds <- function(object, path, compress = TRUE) {
  target_dir <- dirname(path)
  if (!dir.exists(target_dir)) dir.create(target_dir, recursive = TRUE)

  temp_path <- tempfile(paste0(basename(path), "."), tmpdir = target_dir, fileext = ".tmp")
  backup_path <- paste0(path, ".bak")

  on.exit({
    if (file.exists(temp_path)) unlink(temp_path)
  }, add = TRUE)

  saveRDS(object, temp_path, compress = compress)

  temp_read_ok <- tryCatch({
    readRDS(temp_path)
    TRUE
  }, error = function(...) FALSE)

  if (!isTRUE(temp_read_ok)) {
    stop("Temporary RDS write validation failed for ", path, ".", call. = FALSE)
  }

  if (file.exists(path)) {
    backup_ok <- file.copy(path, backup_path, overwrite = TRUE)
    if (!isTRUE(backup_ok)) {
      stop("Unable to create backup before replacing ", path, ".", call. = FALSE)
    }

    unlink_ok <- unlink(path) == 0
    if (!isTRUE(unlink_ok) && file.exists(path)) {
      stop("Unable to remove existing RDS before replacing ", path, ".", call. = FALSE)
    }
  }

  replace_ok <- file.rename(temp_path, path)
  if (!isTRUE(replace_ok)) {
    replace_ok <- file.copy(temp_path, path, overwrite = TRUE)
    if (isTRUE(replace_ok)) unlink(temp_path)
  }

  final_read_ok <- isTRUE(replace_ok) && tryCatch({
    readRDS(path)
    TRUE
  }, error = function(...) FALSE)

  if (!isTRUE(final_read_ok)) {
    if (file.exists(backup_path)) {
      file.copy(backup_path, path, overwrite = TRUE)
    }
    stop("Final RDS write validation failed for ", path, ".", call. = FALSE)
  }

  invisible(path)
}

read_processed_artifact_manifest_with_status <- function(project_dir) {
  manifest_path <- get_processed_artifact_manifest_path(project_dir)

  if (!file.exists(manifest_path)) {
    return(list(
      ok = FALSE,
      reason = "manifest_missing",
      detail = paste("Manifest not found:", manifest_path),
      manifest = list()
    ))
  }

  manifest <- tryCatch(
    readRDS(manifest_path),
    error = function(e) e
  )

  if (inherits(manifest, "error")) {
    return(list(
      ok = FALSE,
      reason = "manifest_read_error",
      detail = conditionMessage(manifest),
      manifest = list()
    ))
  }

  if (!is.list(manifest)) {
    return(list(
      ok = FALSE,
      reason = "manifest_invalid",
      detail = paste("Manifest class:", paste(class(manifest), collapse = "/")),
      manifest = list()
    ))
  }

  list(
    ok = TRUE,
    reason = "manifest_current",
    detail = "Manifest read successfully",
    manifest = manifest
  )
}

read_processed_artifact_manifest <- function(project_dir) {
  read_processed_artifact_manifest_with_status(project_dir)$manifest
}

read_processed_artifact_manifest_entry <- function(project_dir, artifact_path_or_name) {
  manifest <- read_processed_artifact_manifest(project_dir)
  manifest[[basename(artifact_path_or_name)]]
}

write_processed_artifact_manifest <- function(project_dir, manifest) {
  processed_data_dir <- get_processed_data_dir(project_dir)
  if (!dir.exists(processed_data_dir)) dir.create(processed_data_dir, recursive = TRUE)
  safe_write_rds(manifest, get_processed_artifact_manifest_path(project_dir))
}

build_harmonization_dependency_signatures <- function(baseline_table_path, review_table_path) {
  harmonization_mode <- dplyr::case_when(
    isFALSE(getOption("rice_use_canonical_country_map", TRUE)) ~ "canonical_map_disabled",
    harmonization_refresh_enabled() ~ "baseline_plus_refresh",
    TRUE ~ "baseline_only"
  )

  c(
    harmonization_mode = harmonization_mode,
    baseline_table = build_file_signature(baseline_table_path),
    review_table = if (identical(harmonization_mode, "baseline_plus_refresh")) {
      build_file_signature(review_table_path)
    } else {
      "review_overlay_ignored"
    }
  )
}

processed_artifact_recipe_versions <- function() {
  c(
    export_sales_weekly = "export_sales_weekly_recipe_2026_06_01_v2",
    export_sales_weekly_fiscal = "export_sales_weekly_fiscal_recipe_2026_06_01_v2",
    export_sales_monthly = "export_sales_monthly_recipe_2026_05_08_v1",
    export_sales_monthly_fiscal = "export_sales_monthly_fiscal_recipe_2026_05_09_v1",
    census_exports_monthly = "census_exports_monthly_recipe_2026_07_08_start_year_v1",
    census_exports_monthly_fiscal = "census_exports_monthly_fiscal_recipe_2026_05_11_v1",
    census_imports_monthly = "census_imports_monthly_recipe_2026_07_08_start_year_v1",
    census_imports_monthly_fiscal = "census_imports_monthly_fiscal_recipe_2026_05_11_v1",
    hybrid_monthly = "hybrid_monthly_recipe_2026_06_16_v3",
    hybrid_monthly_fiscal = "hybrid_monthly_fiscal_recipe_2026_06_16_v3",
    hybrid_import_monthly = "hybrid_import_monthly_recipe_2026_06_16_v2",
    hybrid_import_monthly_fiscal = "hybrid_import_monthly_fiscal_recipe_2026_06_16_v2",
    hybrid_weekly_imputed = "hybrid_weekly_imputed_recipe_2026_06_16_v4",
    hybrid_weekly_imputed_fiscal = "hybrid_weekly_imputed_fiscal_recipe_2026_06_16_v4",
    psd_marketing_year_long = "psd_marketing_year_long_recipe_2026_05_08_v1",
    psd_historical_records = "psd_historical_records_recipe_2026_05_27_v3",
    psd_revision_delta = "psd_revision_delta_recipe_2026_06_15_v1",
    nass_annual = "nass_annual_recipe_2026_06_24_v1",
    nass_state_lookup = "nass_state_lookup_recipe_2026_06_24_v1",
    nass_shellout_factors = "nass_shellout_factors_recipe_2026_06_30_v1",
    nass_historical_records = "nass_historical_records_recipe_2026_06_25_v1",
    wasde_marketing_year = "wasde_marketing_year_recipe_2026_06_10_v2",
    wasde_release_history = "wasde_release_history_recipe_2026_06_10_v2",
    wasde_revision_delta = "wasde_revision_delta_recipe_2026_06_10_v3",
    wasde_historical_records = "wasde_historical_records_recipe_2026_06_03_v1",
    app_ui_metadata = "app_ui_metadata_recipe_2026_05_09_v1"
  )
}

psd_historical_records_materializer_version <- function() {
  "psd_historical_records_materializer_2026_05_27_v4"
}

psd_revision_delta_materializer_version <- function() {
  "psd_revision_delta_materializer_2026_06_15_v1"
}

nass_annual_materializer_version <- function() {
  "nass_annual_materializer_2026_06_24_v1"
}

nass_state_lookup_materializer_version <- function() {
  "nass_state_lookup_materializer_2026_06_24_v1"
}

nass_shellout_factors_materializer_version <- function() {
  "nass_shellout_factors_materializer_2026_06_30_v1"
}

nass_historical_records_materializer_version <- function() {
  "nass_historical_records_materializer_2026_06_25_v1"
}

wasde_historical_records_materializer_version <- function() {
  "wasde_historical_records_materializer_2026_06_03_v1"
}

wasde_release_history_materializer_version <- function() {
  "wasde_release_history_materializer_2026_06_10_v2"
}

wasde_revision_delta_materializer_version <- function() {
  "wasde_revision_delta_materializer_2026_06_10_v3"
}

app_ui_metadata_materializer_version <- function() {
  "app_ui_metadata_materializer_2026_06_23_v2"
}

build_processed_artifact_extra_signatures <- function(artifact_family, baseline_table_path, review_table_path) {
  recipe_versions <- processed_artifact_recipe_versions()

  if (!artifact_family %in% names(recipe_versions)) {
    stop(
      paste0(
        "Unknown processed artifact recipe family: ",
        artifact_family,
        "."
      ),
      call. = FALSE
    )
  }

  signatures <- c(
    build_harmonization_dependency_signatures(
      baseline_table_path = baseline_table_path,
      review_table_path = review_table_path
    ),
    artifact_family = artifact_family,
    recipe_version = unname(recipe_versions[[artifact_family]])
  )

  if (identical(artifact_family, "export_sales_weekly_fiscal")) {
    signatures <- c(
      signatures,
      export_sales_fiscal_weekly_materializer = export_sales_fiscal_weekly_materializer_version()
    )
  }

  if (artifact_family %in% c(
    "export_sales_monthly_fiscal",
    "census_exports_monthly_fiscal",
    "census_imports_monthly_fiscal",
    "hybrid_monthly_fiscal",
    "hybrid_import_monthly_fiscal"
  )) {
    signatures <- c(
      signatures,
      non_psd_monthly_fiscal_materializer = non_psd_monthly_fiscal_materializer_version()
    )
  }

  if (identical(artifact_family, "hybrid_weekly_imputed_fiscal")) {
    signatures <- c(
      signatures,
      hybrid_weekly_imputed_fiscal_materializer = hybrid_weekly_imputed_fiscal_materializer_version()
    )
  }

  if (identical(artifact_family, "psd_marketing_year_long")) {
    signatures <- c(
      signatures,
      psd_phase1_crosswalk = build_psd_phase1_crosswalk_signature()
    )
  }

  if (identical(artifact_family, "psd_historical_records")) {
    signatures <- c(
      signatures,
      psd_phase1_crosswalk = build_psd_phase1_crosswalk_signature(),
      psd_historical_records_materializer = psd_historical_records_materializer_version()
    )
  }

  if (identical(artifact_family, "psd_revision_delta")) {
    signatures <- c(
      signatures,
      psd_phase1_crosswalk = build_psd_phase1_crosswalk_signature(),
      psd_revision_delta_materializer = psd_revision_delta_materializer_version()
    )
  }

  if (identical(artifact_family, "nass_annual")) {
    signatures <- c(
      signatures,
      nass_annual_materializer = nass_annual_materializer_version()
    )
  }

  if (identical(artifact_family, "nass_state_lookup")) {
    signatures <- c(
      signatures,
      nass_state_lookup_materializer = nass_state_lookup_materializer_version()
    )
  }

  if (identical(artifact_family, "nass_shellout_factors")) {
    signatures <- c(
      signatures,
      nass_shellout_factors_materializer = nass_shellout_factors_materializer_version()
    )
  }

  if (identical(artifact_family, "nass_historical_records")) {
    signatures <- c(
      signatures,
      nass_historical_records_materializer = nass_historical_records_materializer_version()
    )
  }

  if (identical(artifact_family, "wasde_historical_records")) {
    signatures <- c(
      signatures,
      wasde_historical_records_materializer = wasde_historical_records_materializer_version()
    )
  }

  if (identical(artifact_family, "wasde_release_history")) {
    signatures <- c(
      signatures,
      wasde_release_history_materializer = wasde_release_history_materializer_version()
    )
  }

  if (identical(artifact_family, "wasde_revision_delta")) {
    signatures <- c(
      signatures,
      wasde_revision_delta_materializer = wasde_revision_delta_materializer_version()
    )
  }

  if (identical(artifact_family, "app_ui_metadata")) {
    source_recipe_families <- c(
      "export_sales_weekly",
      "export_sales_monthly",
      "census_exports_monthly",
      "census_imports_monthly",
      "hybrid_monthly",
      "hybrid_import_monthly",
      "hybrid_weekly_imputed",
      "psd_marketing_year_long",
      "wasde_marketing_year"
    )
    source_recipe_versions <- recipe_versions[source_recipe_families]
    signatures <- c(
      signatures,
      app_ui_metadata_materializer = app_ui_metadata_materializer_version(),
      app_ui_metadata_source_recipes = paste(
        paste(names(source_recipe_versions), unname(source_recipe_versions), sep = "="),
        collapse = "|"
      )
    )
  }

  signatures
}

app_ui_country_label_strip_code_sources <- function() {
  c("census_export", "census_import")
}

app_ui_source_should_strip_country_code_prefix <- function(source_name) {
  source_name <- trimws(as.character(source_name %||% character(0)))
  any(source_name %in% app_ui_country_label_strip_code_sources())
}

strip_app_ui_census_country_code_prefix <- function(label_value) {
  cleaned_label <- as.character(label_value)
  stripped_label <- sub("^\\([0-9]+\\)\\s*", "", cleaned_label)
  stripped_label[is.na(cleaned_label)] <- NA_character_
  stripped_label
}

normalize_app_ui_country_display_label <- function(label_value, strip_codes = FALSE) {
  cleaned_label <- trimws(as.character(label_value))
  if (isTRUE(strip_codes)) {
    cleaned_label <- strip_app_ui_census_country_code_prefix(cleaned_label)
  }
  cleaned_label[!nzchar(cleaned_label)] <- NA_character_

  normalized_label <- canonical_country_label_from_code(cleaned_label)
  normalized_label[cleaned_label %in% c("WORLD", "World", "GRAND_TOTAL", "Grand Total", "GRAND TOTAL")] <- "World"
  normalized_label
}

choose_app_ui_lookup_country_label <- function(country_code, country_labels, canonical_label_lookup, strip_codes = FALSE) {
  cleaned_code <- trimws(as.character(country_code[[1]]))

  if (!nzchar(cleaned_code) || is.na(cleaned_code)) {
    return(NA_character_)
  }

  if (identical(cleaned_code, "GRAND_TOTAL")) {
    return("World")
  }

  canonical_candidate <- unname(canonical_label_lookup[cleaned_code])
  canonical_candidate <- normalize_app_ui_country_display_label(canonical_candidate, strip_codes = strip_codes)
  canonical_candidate <- canonical_candidate[!is.na(canonical_candidate) & nzchar(canonical_candidate)]
  if (length(canonical_candidate) > 0) {
    return(canonical_candidate[[1]])
  }

  normalized_candidates <- normalize_app_ui_country_display_label(country_labels, strip_codes = strip_codes)
  normalized_candidates <- unique(normalized_candidates[!is.na(normalized_candidates) & nzchar(normalized_candidates)])
  if (length(normalized_candidates) > 0) {
    return(normalized_candidates[order(nchar(normalized_candidates), normalized_candidates)][[1]])
  }

  fallback_label <- canonical_country_label_from_code(cleaned_code)
  if (is.na(fallback_label) || !nzchar(fallback_label)) {
    cleaned_code
  } else {
    fallback_label
  }
}

choose_app_ui_lookup_country_code <- function(country_codes, source_priorities = NULL) {
  cleaned_codes <- trimws(as.character(country_codes))
  cleaned_codes <- cleaned_codes[!is.na(cleaned_codes) & nzchar(cleaned_codes)]

  if (length(cleaned_codes) == 0) {
    return(NA_character_)
  }

  if ("GRAND_TOTAL" %in% cleaned_codes) {
    return("GRAND_TOTAL")
  }

  if (is.null(source_priorities)) {
    source_priorities <- rep.int(Inf, length(cleaned_codes))
  }

  priority_values <- suppressWarnings(as.integer(source_priorities))
  priority_values[is.na(priority_values)] <- .Machine$integer.max

  choice_df <- data.frame(
    country = cleaned_codes,
    source_priority = priority_values,
    stringsAsFactors = FALSE
  )
  choice_df <- choice_df[!duplicated(choice_df$country), , drop = FALSE]
  choice_df <- choice_df[order(choice_df$source_priority, nchar(choice_df$country), choice_df$country), , drop = FALSE]

  choice_df$country[[1]]
}

build_app_ui_country_choice_rows <- function(data, source_priority, source_name = NULL, strip_codes = app_ui_source_should_strip_country_code_prefix(source_name)) {
  if (is.null(data) || !is.data.frame(data) || nrow(data) == 0) {
    return(tibble(
      country = character(),
      countryDescription = character(),
      source_priority = integer()
    ))
  }

  data %>%
    transmute(
      country = as.character(.data$country),
      countryDescription = if (isTRUE(strip_codes)) {
        strip_app_ui_census_country_code_prefix(.data$countryDescription)
      } else {
        as.character(.data$countryDescription)
      }
    ) %>%
    filter(!is.na(.data$country), nzchar(.data$country)) %>%
    distinct(country, countryDescription) %>%
    mutate(source_priority = source_priority)
}

choose_app_ui_context_country_code <- function(country_codes) {
  unique_codes <- unique(trimws(as.character(country_codes)))
  unique_codes <- unique_codes[nzchar(unique_codes)]

  if (length(unique_codes) == 0) return(NA_character_)
  if ("GRAND_TOTAL" %in% unique_codes) return("GRAND_TOTAL")

  unique_codes[order(-nchar(unique_codes), unique_codes)][1]
}

choose_app_ui_context_country_label <- function(country_labels) {
  unique_labels <- unique(trimws(as.character(country_labels)))
  unique_labels <- unique_labels[nzchar(unique_labels)]

  if (length(unique_labels) == 0) return(NA_character_)
  if ("World" %in% unique_labels) return("World")

  unique_labels[order(nchar(unique_labels), unique_labels)][1]
}

build_app_ui_context_country_display_names <- function(choice_rows, display_lookup) {
  if (is.null(choice_rows) || !is.data.frame(choice_rows) || nrow(choice_rows) == 0) {
    return(stats::setNames(character(), character()))
  }

  country <- trimws(as.character(choice_rows$country))
  country[is.na(country)] <- ""
  country_description <- trimws(as.character(choice_rows$countryDescription))
  country_description[is.na(country_description)] <- ""

  display_idx <- country %in% names(display_lookup)
  if (any(display_idx)) {
    country_description[display_idx] <- unname(display_lookup[country[display_idx]])
  }

  empty_description_idx <- is.na(country_description) | !nzchar(country_description)
  country_description[empty_description_idx] <- country[empty_description_idx]
  country_description[country == "GRAND_TOTAL"] <- "World"

  keep_idx <- !is.na(country) & nzchar(country) & !is.na(country_description) & nzchar(country_description)
  if (!any(keep_idx)) {
    return(stats::setNames(character(), character()))
  }

  pair_df <- unique(data.frame(
    country = country[keep_idx],
    countryDescription = country_description[keep_idx],
    stringsAsFactors = FALSE
  ))

  country_by_label <- vapply(
    split(pair_df$country, pair_df$countryDescription),
    choose_app_ui_context_country_code,
    character(1)
  )
  label_df <- data.frame(
    countryDescription = names(country_by_label),
    country = unname(country_by_label),
    stringsAsFactors = FALSE
  )

  label_by_country <- vapply(
    split(label_df$countryDescription, label_df$country),
    choose_app_ui_context_country_label,
    character(1)
  )
  out_df <- data.frame(
    country = names(label_by_country),
    countryDescription = unname(label_by_country),
    stringsAsFactors = FALSE
  )
  out_df <- out_df[order(out_df$countryDescription, out_df$country), , drop = FALSE]

  stats::setNames(out_df$country, out_df$countryDescription)
}

app_ui_metadata_source_entry_data <- function(source_entry) {
  if (is.data.frame(source_entry)) return(source_entry)
  if (is.list(source_entry) && is.data.frame(source_entry$data)) return(source_entry$data)

  data.frame(country = character(), countryDescription = character(), stringsAsFactors = FALSE)
}

app_ui_metadata_source_entry_priority <- function(source_entry, fallback_priority) {
  if (is.list(source_entry) && !is.null(source_entry$source_priority)) {
    source_priority <- suppressWarnings(as.integer(source_entry$source_priority[[1]]))
    if (!is.na(source_priority)) return(source_priority)
  }

  fallback_priority
}

app_ui_country_display_context_keys <- function(source_names) {
  preferred_context_keys <- c(
    "psd",
    "wasde",
    "export_sales_weekly",
    "export_sales_monthly",
    "census_export",
    "census_import",
    "hybrid_export_monthly",
    "hybrid_import_monthly",
    "hybrid_weekly_imputed"
  )

  c(preferred_context_keys[preferred_context_keys %in% source_names], setdiff(source_names, preferred_context_keys))
}

materialize_app_ui_metadata <- function(country_canonical_map, source_datasets) {
  country_canonical_label_lookup <- bind_rows(
    country_canonical_map %>%
      transmute(
        lookup_country = trimws(as.character(.data$canonical_country_code)),
        canonical_country_label = trimws(as.character(.data$canonical_country_label))
      ),
    country_canonical_map %>%
      transmute(
        lookup_country = trimws(as.character(.data$legacy_country_code)),
        canonical_country_label = trimws(as.character(.data$canonical_country_label))
      )
  ) %>%
    filter(
      !is.na(.data$lookup_country),
      nzchar(.data$lookup_country),
      !is.na(.data$canonical_country_label),
      nzchar(.data$canonical_country_label)
    ) %>%
    group_by(.data$lookup_country) %>%
    summarise(
      canonical_country_label = choose_app_ui_lookup_country_label(
        .data$lookup_country,
        .data$canonical_country_label,
        stats::setNames(character(), character())
      ),
      .groups = "drop"
    )

  country_canonical_label_lookup <- stats::setNames(
    country_canonical_label_lookup$canonical_country_label,
    country_canonical_label_lookup$lookup_country
  )

  source_names <- names(source_datasets)
  if (is.null(source_names) || any(!nzchar(source_names))) {
    stop("App UI metadata source_datasets must be a fully named list.", call. = FALSE)
  }

  country_choice_row_sources <- stats::setNames(lapply(seq_along(source_datasets), function(source_idx) {
    source_name <- source_names[[source_idx]]
    source_entry <- source_datasets[[source_idx]]
    build_app_ui_country_choice_rows(
      data = app_ui_metadata_source_entry_data(source_entry),
      source_priority = app_ui_metadata_source_entry_priority(source_entry, source_idx),
      source_name = source_name
    )
  }), source_names)

  country_choice_label_rows <- bind_rows(country_choice_row_sources) %>%
    arrange(.data$source_priority, .data$countryDescription, .data$country) %>%
    group_by(.data$country) %>%
    summarise(
      countryDescription = choose_app_ui_lookup_country_label(
        .data$country,
        .data$countryDescription,
        country_canonical_label_lookup
      ),
      source_priority = min(.data$source_priority, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    filter(!is.na(.data$countryDescription), nzchar(.data$countryDescription))

  country_choices_all <- country_choice_label_rows %>%
    group_by(.data$countryDescription) %>%
    summarise(
      country = choose_app_ui_lookup_country_code(.data$country, .data$source_priority),
      .groups = "drop"
    ) %>%
    arrange(.data$countryDescription, .data$country)

  country_display_names <- stats::setNames(
    country_choices_all$country,
    country_choices_all$countryDescription
  )
  country_display_name_lookup <- stats::setNames(
    country_choice_label_rows$countryDescription,
    country_choice_label_rows$country
  )

  list(
    schema_version = app_ui_metadata_materializer_version(),
    country_canonical_label_lookup = country_canonical_label_lookup,
    country_choice_row_sources = country_choice_row_sources,
    country_choice_label_rows = country_choice_label_rows,
    country_choices_all = country_choices_all,
    country_display_names = country_display_names,
    country_display_name_lookup = country_display_name_lookup,
    country_display_name_context_keys = app_ui_country_display_context_keys(names(country_choice_row_sources))
  )
}

write_processed_artifact <- function(data, artifact_path, project_dir, source_paths = character(), extra_signatures = character(), compress = TRUE, artifact_metadata = NULL) {
  processed_data_dir <- get_processed_data_dir(project_dir)
  if (!dir.exists(processed_data_dir)) dir.create(processed_data_dir, recursive = TRUE)

  artifact_path_id <- build_artifact_source_id(artifact_path, project_dir)
  normalized_source_paths <- normalize_artifact_paths(source_paths, must_work = FALSE)
  source_path_ids <- build_artifact_source_ids(source_paths, project_dir)
  source_signatures <- normalize_processed_artifact_signatures(unname(vapply(source_paths, build_file_signature, character(1))))

  manifest <- read_processed_artifact_manifest(project_dir)
  manifest_key <- basename(artifact_path)
  existing_entry <- manifest[[manifest_key]]

  if (!is.null(existing_entry) && is.list(existing_entry)) {
    existing_artifact_path_id <- existing_entry$artifact_path_id
    if (is.null(existing_artifact_path_id) && !is.null(existing_entry$artifact_path)) {
      existing_artifact_path_id <- build_artifact_source_id(existing_entry$artifact_path, project_dir)
    }

    if (!is.null(existing_artifact_path_id) && !artifact_identity_vectors_equal(existing_artifact_path_id, artifact_path_id)) {
      stop(
        paste0(
          "Processed artifact manifest basename collision for ",
          manifest_key,
          ": existing artifact_path_id=",
          paste(existing_artifact_path_id, collapse = "|"),
          "; new artifact_path_id=",
          artifact_path_id,
          "."
        ),
        call. = FALSE
      )
    }
  }

  saveRDS(data, artifact_path, compress = compress)

  manifest_entry <- list(
    artifact_path_id = artifact_path_id,
    artifact_path = normalize_artifact_path(artifact_path, must_work = TRUE),
    built_at = as.character(Sys.time()),
    source_path_ids = source_path_ids,
    source_paths = normalized_source_paths,
    source_signatures = source_signatures,
    extra_signature_names = names(extra_signatures),
    extra_signatures = normalize_processed_artifact_signatures(unname(as.character(extra_signatures)))
  )

  if (!is.null(artifact_metadata)) {
    manifest_entry$artifact_metadata <- artifact_metadata
  }

  manifest[[basename(artifact_path)]] <- manifest_entry

  write_processed_artifact_manifest(project_dir, manifest)
  invisible(artifact_path)
}

processed_artifact_value_or <- function(value, fallback) {
  if (is.null(value)) fallback else value
}

processed_artifact_detail <- function(label, expected, actual) {
  paste0(
    label,
    " expected=[",
    paste(expected, collapse = " || "),
    "]; actual=[",
    paste(actual, collapse = " || "),
    "]"
  )
}

processed_artifact_status <- function(current, reason, detail, artifact_path, expected_source_paths = character(), actual_source_paths = character(), expected_source_signatures = character(), actual_source_signatures = character(), expected_extra_signature_names = character(), actual_extra_signature_names = character(), expected_extra_signatures = character(), actual_extra_signatures = character(), expected_source_ids = character(), actual_source_ids = character(), artifact_metadata = NULL) {
  list(
    current = isTRUE(current),
    reason = reason,
    detail = detail,
    artifact_path = artifact_path,
    expected_source_ids = expected_source_ids,
    actual_source_ids = actual_source_ids,
    expected_source_paths = expected_source_paths,
    actual_source_paths = actual_source_paths,
    expected_source_signatures = expected_source_signatures,
    actual_source_signatures = actual_source_signatures,
    expected_extra_signature_names = expected_extra_signature_names,
    actual_extra_signature_names = actual_extra_signature_names,
    expected_extra_signatures = expected_extra_signatures,
    actual_extra_signatures = actual_extra_signatures,
    artifact_metadata = artifact_metadata
  )
}

diagnose_processed_artifact_currentity <- function(artifact_path, project_dir, source_paths = character(), extra_signatures = character()) {
  expected_paths <- normalize_artifact_paths(source_paths, must_work = FALSE)
  expected_source_ids <- build_artifact_source_ids(source_paths, project_dir)
  expected_signatures <- normalize_processed_artifact_signatures(unname(vapply(source_paths, build_file_signature, character(1))))
  expected_extra_names <- names(extra_signatures)
  expected_extra_signatures <- normalize_processed_artifact_signatures(unname(as.character(extra_signatures)))

  if (!file.exists(artifact_path)) {
    return(processed_artifact_status(
      current = FALSE,
      reason = "artifact_missing",
      detail = paste("Artifact not found:", artifact_path),
      artifact_path = artifact_path,
      expected_source_ids = expected_source_ids,
      expected_source_paths = expected_paths,
      expected_source_signatures = expected_signatures,
      expected_extra_signature_names = expected_extra_names,
      expected_extra_signatures = expected_extra_signatures
    ))
  }

  manifest_status <- read_processed_artifact_manifest_with_status(project_dir)
  if (!isTRUE(manifest_status$ok)) {
    return(processed_artifact_status(
      current = FALSE,
      reason = manifest_status$reason,
      detail = manifest_status$detail,
      artifact_path = artifact_path,
      expected_source_ids = expected_source_ids,
      expected_source_paths = expected_paths,
      expected_source_signatures = expected_signatures,
      expected_extra_signature_names = expected_extra_names,
      expected_extra_signatures = expected_extra_signatures
    ))
  }

  entry <- manifest_status$manifest[[basename(artifact_path)]]
  if (is.null(entry) || !is.list(entry)) {
    return(processed_artifact_status(
      current = FALSE,
      reason = "manifest_entry_missing",
      detail = paste("Manifest entry not found:", basename(artifact_path)),
      artifact_path = artifact_path,
      expected_source_ids = expected_source_ids,
      expected_source_paths = expected_paths,
      expected_source_signatures = expected_signatures,
      expected_extra_signature_names = expected_extra_names,
      expected_extra_signatures = expected_extra_signatures
    ))
  }

  actual_paths <- unname(processed_artifact_value_or(entry$source_paths, character()))
  actual_source_ids <- unname(processed_artifact_value_or(entry$source_path_ids, character()))
  if (length(actual_source_ids) == 0 && length(actual_paths) > 0) {
    actual_source_ids <- build_artifact_source_ids(actual_paths, project_dir)
  }

  actual_signatures <- normalize_processed_artifact_signatures(unname(processed_artifact_value_or(entry$source_signatures, character())))
  actual_extra_names <- unname(processed_artifact_value_or(entry$extra_signature_names, character()))
  actual_extra_signatures <- normalize_processed_artifact_signatures(unname(processed_artifact_value_or(entry$extra_signatures, character())))
  artifact_metadata <- processed_artifact_value_or(entry$artifact_metadata, NULL)

  if (!artifact_identity_vectors_equal(expected_source_ids, actual_source_ids)) {
    return(processed_artifact_status(
      current = FALSE,
      reason = "source_path_mismatch",
      detail = paste(
        processed_artifact_detail("Source IDs", expected_source_ids, actual_source_ids),
        processed_artifact_detail("Diagnostic source paths", expected_paths, actual_paths),
        sep = "; "
      ),
      artifact_path = artifact_path,
      expected_source_ids = expected_source_ids,
      actual_source_ids = actual_source_ids,
      expected_source_paths = expected_paths,
      actual_source_paths = actual_paths,
      expected_source_signatures = expected_signatures,
      actual_source_signatures = actual_signatures,
      expected_extra_signature_names = expected_extra_names,
      actual_extra_signature_names = actual_extra_names,
      expected_extra_signatures = expected_extra_signatures,
      actual_extra_signatures = actual_extra_signatures,
      artifact_metadata = artifact_metadata
    ))
  }

  source_signatures_unavailable <- any(processed_artifact_signatures_unavailable(c(expected_signatures, actual_signatures)))
  if (!identical(actual_signatures, expected_signatures) || isTRUE(source_signatures_unavailable)) {
    return(processed_artifact_status(
      current = FALSE,
      reason = "source_signature_mismatch",
      detail = processed_artifact_detail("Source signatures", expected_signatures, actual_signatures),
      artifact_path = artifact_path,
      expected_source_ids = expected_source_ids,
      actual_source_ids = actual_source_ids,
      expected_source_paths = expected_paths,
      actual_source_paths = actual_paths,
      expected_source_signatures = expected_signatures,
      actual_source_signatures = actual_signatures,
      expected_extra_signature_names = expected_extra_names,
      actual_extra_signature_names = actual_extra_names,
      expected_extra_signatures = expected_extra_signatures,
      actual_extra_signatures = actual_extra_signatures,
      artifact_metadata = artifact_metadata
    ))
  }

  if (!identical(actual_extra_names, expected_extra_names)) {
    return(processed_artifact_status(
      current = FALSE,
      reason = "extra_signature_name_mismatch",
      detail = processed_artifact_detail("Extra signature names", expected_extra_names, actual_extra_names),
      artifact_path = artifact_path,
      expected_source_ids = expected_source_ids,
      actual_source_ids = actual_source_ids,
      expected_source_paths = expected_paths,
      actual_source_paths = actual_paths,
      expected_source_signatures = expected_signatures,
      actual_source_signatures = actual_signatures,
      expected_extra_signature_names = expected_extra_names,
      actual_extra_signature_names = actual_extra_names,
      expected_extra_signatures = expected_extra_signatures,
      actual_extra_signatures = actual_extra_signatures,
      artifact_metadata = artifact_metadata
    ))
  }

  extra_signatures_unavailable <- any(processed_artifact_signatures_unavailable(c(expected_extra_signatures, actual_extra_signatures)))
  if (!identical(actual_extra_signatures, expected_extra_signatures) || isTRUE(extra_signatures_unavailable)) {
    return(processed_artifact_status(
      current = FALSE,
      reason = "extra_signature_mismatch",
      detail = processed_artifact_detail("Extra signatures", expected_extra_signatures, actual_extra_signatures),
      artifact_path = artifact_path,
      expected_source_ids = expected_source_ids,
      actual_source_ids = actual_source_ids,
      expected_source_paths = expected_paths,
      actual_source_paths = actual_paths,
      expected_source_signatures = expected_signatures,
      actual_source_signatures = actual_signatures,
      expected_extra_signature_names = expected_extra_names,
      actual_extra_signature_names = actual_extra_names,
      expected_extra_signatures = expected_extra_signatures,
      actual_extra_signatures = actual_extra_signatures,
      artifact_metadata = artifact_metadata
    ))
  }

  processed_artifact_status(
    current = TRUE,
    reason = "current",
    detail = "Artifact manifest entry matches expected source and extra signatures.",
    artifact_path = artifact_path,
    expected_source_ids = expected_source_ids,
    actual_source_ids = actual_source_ids,
    expected_source_paths = expected_paths,
    actual_source_paths = actual_paths,
    expected_source_signatures = expected_signatures,
    actual_source_signatures = actual_signatures,
    expected_extra_signature_names = expected_extra_names,
    actual_extra_signature_names = actual_extra_names,
    expected_extra_signatures = expected_extra_signatures,
    actual_extra_signatures = actual_extra_signatures,
    artifact_metadata = artifact_metadata
  )
}

processed_artifact_is_current <- function(artifact_path, project_dir, source_paths = character(), extra_signatures = character(), perf_label = NULL) {
  perf_start_time <- if (!is.null(perf_label) && nzchar(perf_label[[1]])) Sys.time() else NULL
  status <- diagnose_processed_artifact_currentity(
    artifact_path = artifact_path,
    project_dir = project_dir,
    source_paths = source_paths,
    extra_signatures = extra_signatures
  )

  maybe_log_perf(
    if (!is.null(perf_start_time)) paste0(perf_label, ": currentity_check") else NULL,
    perf_start_time,
    details = list(path = basename(artifact_path), status = status$reason, current = status$current)
  )

  status$current
}

read_processed_artifact_with_status <- function(artifact_path, project_dir, source_paths = character(), extra_signatures = character(), perf_label = NULL) {
  perf_start_time <- if (!is.null(perf_label) && nzchar(perf_label[[1]])) Sys.time() else NULL
  currentity <- diagnose_processed_artifact_currentity(
    artifact_path = artifact_path,
    project_dir = project_dir,
    source_paths = source_paths,
    extra_signatures = extra_signatures
  )

  maybe_log_perf(
    if (!is.null(perf_start_time)) paste0(perf_label, ": currentity_check") else NULL,
    perf_start_time,
    details = list(path = basename(artifact_path), status = currentity$reason, current = currentity$current)
  )

  if (!isTRUE(currentity$current)) {
    return(list(
      data = NULL,
      current = FALSE,
      reason = currentity$reason,
      detail = currentity$detail,
      currentity = currentity
    ))
  }

  read_start_time <- if (!is.null(perf_label) && nzchar(perf_label[[1]])) Sys.time() else NULL
  read_status <- "ok"
  read_error <- NULL
  artifact <- tryCatch(
    readRDS(artifact_path),
    error = function(e) {
      read_status <<- "error"
      read_error <<- conditionMessage(e)
      NULL
    }
  )

  maybe_log_perf(
    if (!is.null(read_start_time)) paste0(perf_label, ": artifact_read") else NULL,
    read_start_time,
    details = list(
      path = basename(artifact_path),
      status = read_status,
      rows = if (is.data.frame(artifact)) nrow(artifact) else NA_integer_,
      cols = if (is.data.frame(artifact)) ncol(artifact) else NA_integer_
    )
  )

  if (identical(read_status, "error")) {
    return(list(
      data = NULL,
      current = FALSE,
      reason = "artifact_read_error",
      detail = read_error,
      currentity = currentity
    ))
  }

  list(
    data = artifact,
    current = TRUE,
    reason = "current",
    detail = currentity$detail,
    currentity = currentity
  )
}

read_processed_artifact_if_current <- function(artifact_path, project_dir, source_paths = character(), extra_signatures = character(), perf_label = NULL) {
  read_processed_artifact_with_status(
    artifact_path = artifact_path,
    project_dir = project_dir,
    source_paths = source_paths,
    extra_signatures = extra_signatures,
    perf_label = perf_label
  )$data
}

assert_required_columns <- function(file_path, required_columns, dataset_label) {
  header_line <- readLines(file_path, n = 1L, warn = FALSE, encoding = "UTF-8")
  if (length(header_line) == 0) {
    header_cols <- character()
  } else {
    header_cols <- names(read.csv(text = sub("^\ufeff", "", header_line[[1]]), nrows = 0, stringsAsFactors = FALSE, check.names = FALSE))
  }
  missing_cols <- setdiff(required_columns, header_cols)

  if (length(missing_cols) > 0) {
    stop(
      paste0(
        dataset_label,
        " is missing required columns: ",
        paste(missing_cols, collapse = ", "),
        "."
      ),
      call. = FALSE
    )
  }
}

assert_dataset_columns <- function(dataset, required_columns, dataset_label) {
  missing_cols <- setdiff(required_columns, names(dataset))

  if (length(missing_cols) > 0) {
    stop(
      paste0(
        dataset_label,
        " dropped required internal columns: ",
        paste(missing_cols, collapse = ", "),
        "."
      ),
      call. = FALSE
    )
  }
}

required_weekly_source_cols <- c(
  "country_source_code",
  "weeklyExports", "weeklyExports_rough_eq",
  "accumulatedExports", "accumulatedExports_rough_eq",
  "currentMYTotalCommitment", "currentMYTotalCommitment_rough_eq",
  "outstandingSales", "outstandingSales_rough_eq",
  "grossNewSales", "grossNewSales_rough_eq",
  "currentMYNetSales", "currentMYNetSales_rough_eq",
  "nextMYOutstandingSales", "nextMYOutstandingSales_rough_eq",
  "nextMYNetSales", "nextMYNetSales_rough_eq"
)

required_monthly_source_cols <- c(
  "country_source_code",
  "monthlyexports", "monthlyexports_rough_eq",
  "ytd_exports", "ytd_exports_rough_eq",
  "total_commitment", "total_commitment_rough_eq"
)

required_census_source_cols <- c(
  "HS_Country_Code", "HS_Code", "Country", "HS",
  "YEARNUM", "MONTHNUM", "Value", "Volume",
  "Unit_Value", "Unit_Volume",
  "Conversion to Rough_Equivalent", "Rough_Equivalent_Volume",
  "Country_Raw", "country_source_code", "countryDescription", "country", "commodity", "month",
  "market_year", "market_month", "market_month_name", "analysis_month",
  "monthlyexports", "monthlyvalue", "ytd_exports", "ytd_value"
)

required_census_import_source_cols <- c(
  "HS_Country_Code", "HS_Code", "Country", "HS",
  "YEARNUM", "MONTHNUM", "Value", "Volume",
  "Unit_Value", "Unit_Volume",
  "Conversion to Rough_Equivalent", "Rough_Equivalent_Volume",
  "Country_Raw", "country_source_code", "countryDescription", "country", "commodity", "month",
  "market_year", "market_month", "market_month_name", "analysis_month",
  "monthlyimports", "monthlyvalue", "ytd_imports", "ytd_value"
)

required_psd_source_cols <- c(
  "commodityCode", "countryCode", "marketYear", "calendarYear", "month",
  "attributeId", "unitId", "value",
  "commodityName", "countryName", "regionCode", "gencCode", "regionName",
  "unitDescription", "attributeName", "countryDescription", "release_row_key"
)

psd_manual_prior_csv_schema_version <- function() {
  "psd_online_manual_prior_csv_2026_06_16_v1"
}

psd_manual_prior_csv_required_cols <- function() {
  c(
    "Commodity_Code", "Commodity_Description", "Country_Code", "Country_Name",
    "Market_Year", "Calendar_Year", "Month", "Attribute_ID",
    "Attribute_Description", "Unit_ID", "Unit_Description", "Value"
  )
}

psd_manual_prior_rice_commodity_code <- function() {
  "0422110"
}

psd_manual_prior_rice_commodity_name <- function() {
  "Rice, Milled"
}

read_csv_header_columns <- function(file_path) {
  header_line <- readLines(file_path, n = 1L, warn = FALSE, encoding = "UTF-8")
  if (length(header_line) == 0) return(character())
  names(read.csv(text = sub("^\ufeff", "", header_line[[1]]), nrows = 0, stringsAsFactors = FALSE, check.names = FALSE))
}

manual_prior_psd_csv_schema_status <- function(csv_path) {
  expected_cols <- psd_manual_prior_csv_required_cols()
  actual_cols <- if (file.exists(csv_path)) read_csv_header_columns(csv_path) else character()
  missing_cols <- setdiff(expected_cols, actual_cols)

  list(
    ok = file.exists(csv_path) && length(missing_cols) == 0,
    manual_prior_schema_supported = file.exists(csv_path) && length(missing_cols) == 0,
    schema_version = psd_manual_prior_csv_schema_version(),
    csv_path = csv_path,
    expected_columns = expected_cols,
    actual_columns = actual_cols,
    missing_columns = missing_cols,
    unexpected_columns = setdiff(actual_cols, expected_cols),
    reason = dplyr::case_when(
      !file.exists(csv_path) ~ "csv_missing",
      length(missing_cols) > 0 ~ "schema_missing_required_columns",
      TRUE ~ "schema_supported"
    )
  )
}

assert_manual_prior_psd_csv_schema <- function(csv_path) {
  status <- manual_prior_psd_csv_schema_status(csv_path)
  if (!isTRUE(status$ok)) {
    stop(
      paste0(
        "Manual prior PSD CSV schema is unsupported for ",
        csv_path,
        ". Expected schema version ",
        status$schema_version,
        ". Missing columns: ",
        if (length(status$missing_columns) == 0) "none" else paste(status$missing_columns, collapse = ", "),
        ". Actual columns: ",
        if (length(status$actual_columns) == 0) "none" else paste(status$actual_columns, collapse = ", "),
        ". Rerun without manual prior mode or update the manual PSD CSV adapter."
      ),
      call. = FALSE
    )
  }

  invisible(status)
}

resolve_manual_prior_psd_csv <- function(project_dir, current_release_key = NULL, current_psd_data = NULL, input_root = file.path(project_dir, "Input"), explicit_csv_path = NULL, prior_release_override = NULL) {
  prior_release_key <- resolve_manual_prior_psd_release_key(
    current_release_key = current_release_key,
    current_psd_data = current_psd_data,
    prior_release_override = prior_release_override
  )
  prior_release_period <- format_psd_release_period(prior_release_key)
  if (is.na(prior_release_key) || is.na(prior_release_period)) {
    stop("Unable to resolve manual prior PSD release period from current PSD data or override.", call. = FALSE)
  }

  if (!is.null(explicit_csv_path) && nzchar(trimws(explicit_csv_path))) {
    csv_path <- normalizePath(explicit_csv_path, winslash = "/", mustWork = FALSE)
    if (!file.exists(csv_path)) stop("Manual prior PSD CSV path does not exist: ", csv_path, call. = FALSE)
    if (!grepl("\\.csv$", csv_path, ignore.case = TRUE)) {
      stop("Manual prior PSD path must point to an extracted CSV, not an archive or other file: ", csv_path, call. = FALSE)
    }
    folder_path <- dirname(csv_path)
  } else {
    folder_path <- psd_manual_prior_canonical_folder(input_root, prior_release_key)
    if (!dir.exists(folder_path)) {
      stop(
        paste0(
          "Manual prior PSD folder not found: ",
          folder_path,
          ". Expected canonical folder Input/",
          prior_release_period,
          " based on current PSD release."
        ),
        call. = FALSE
      )
    }

    csv_candidates <- list.files(folder_path, pattern = "\\.csv$", full.names = TRUE, recursive = FALSE)
    zip_candidates <- list.files(folder_path, pattern = "\\.zip$", full.names = TRUE, recursive = FALSE)
    if (length(csv_candidates) == 0 && length(zip_candidates) > 0) {
      stop(
        paste0(
          "Manual prior PSD folder contains only zip/archive files: ",
          folder_path,
          ". Extract the PSD Online CSV into Input/",
          prior_release_period,
          " before rerunning manual prior mode."
        ),
        call. = FALSE
      )
    }
    if (length(csv_candidates) != 1L) {
      stop(
        paste0(
          "Manual prior PSD folder must contain exactly one extracted CSV unless PSD_PRIOR_MANUAL_CSV_PATH is explicit: ",
          folder_path,
          ". Found ",
          length(csv_candidates),
          " CSV files."
        ),
        call. = FALSE
      )
    }
    csv_path <- normalizePath(csv_candidates[[1]], winslash = "/", mustWork = TRUE)
  }

  schema_status <- assert_manual_prior_psd_csv_schema(csv_path)

  list(
    ok = TRUE,
    source_type = "manual_prior_psd_online_csv",
    schema_version = schema_status$schema_version,
    prior_release_key = prior_release_key,
    prior_release_period = prior_release_period,
    canonical_folder = normalizePath(folder_path, winslash = "/", mustWork = FALSE),
    csv_path = csv_path,
    csv_signature = build_file_signature(csv_path),
    schema_status = schema_status
  )
}

normalize_manual_prior_psd_unit <- function(unit_description) {
  cleaned <- trimws(as.character(unit_description))
  cleaned <- gsub("^\\((.*)\\)$", "\\1", cleaned)
  cleaned <- stringr::str_replace_all(cleaned, "\\s+", " ")
  upper_cleaned <- toupper(cleaned)

  dplyr::case_when(
    upper_cleaned %in% c("1000 MT", "1,000 MT") ~ "1000 MT",
    upper_cleaned %in% c("1000 HA", "1,000 HA") ~ "1000 HA",
    upper_cleaned %in% c("MT/HA", "MT / HA") ~ "MT/HA",
    upper_cleaned %in% c("PERCENT", "%", "RATIO") ~ "ratio",
    TRUE ~ cleaned
  )
}

normalize_manual_prior_psd_unit_for_attribute <- function(attribute_id, attribute_name, unit_description) {
  attribute_id <- suppressWarnings(as.integer(attribute_id))
  attribute_name <- trimws(as.character(attribute_name))
  normalized_unit <- normalize_manual_prior_psd_unit(unit_description)

  dplyr::case_when(
    attribute_id == 182L & attribute_name == "Milling Rate (.9999)" ~ "ratio",
    TRUE ~ normalized_unit
  )
}

coerce_manual_prior_psd_numeric <- function(values, column_name, integer = FALSE) {
  cleaned <- trimws(as.character(values))
  cleaned[!nzchar(cleaned)] <- NA_character_
  numeric_values <- suppressWarnings(as.numeric(gsub(",", "", cleaned, fixed = TRUE)))
  bad <- !is.na(cleaned) & is.na(numeric_values)
  if (isTRUE(integer)) {
    bad <- bad | (!is.na(numeric_values) & numeric_values != floor(numeric_values))
  }

  if (any(bad)) {
    examples <- head(unique(cleaned[bad]), 5L)
    stop(
      paste0(
        "Manual prior PSD CSV has non-numeric values in ",
        column_name,
        ": ",
        paste(examples, collapse = ", "),
        " (bad row count: ",
        sum(bad),
        ")."
      ),
      call. = FALSE
    )
  }

  if (isTRUE(integer)) as.integer(numeric_values) else numeric_values
}

manual_prior_psd_world_row_filter <- function(data) {
  country_code <- toupper(trimws(as.character(data[["Country_Code"]])))
  country_name <- trimws(as.character(data[["Country_Name"]]))
  country_code %in% c(psd_native_world_country_code(), psd_world_country_code(), "WLD", "WORLD") |
    grepl("(^|[^A-Z])WORLD([^A-Z]|$)", toupper(country_name))
}

normalize_manual_prior_psd_csv_to_staging <- function(resolution, staging_dir = tempfile("manual_prior_psd_staging_")) {
  if (!is.list(resolution) || !isTRUE(resolution$ok)) {
    stop("Manual prior PSD CSV resolution is required before normalization.", call. = FALSE)
  }

  csv_path <- resolution$csv_path
  assert_manual_prior_psd_csv_schema(csv_path)
  prior_release_key <- normalize_psd_release_key(resolution$prior_release_key)
  prior_release_period <- format_psd_release_period(prior_release_key)
  if (is.na(prior_release_key) || is.na(prior_release_period)) {
    stop("Manual prior PSD normalization requires a valid prior release key.", call. = FALSE)
  }

  raw_manual <- read.csv(csv_path, stringsAsFactors = FALSE, check.names = FALSE, colClasses = "character")
  rice_rows <- raw_manual %>%
    mutate(
      Commodity_Code = trimws(as.character(.data$Commodity_Code)),
      Commodity_Description = trimws(as.character(.data$Commodity_Description))
    ) %>%
    filter(
      .data$Commodity_Code == psd_manual_prior_rice_commodity_code() |
        .data$Commodity_Description == psd_manual_prior_rice_commodity_name()
    )

  if (nrow(rice_rows) == 0) {
    stop(
      paste0(
        "Manual prior PSD CSV contains no rice rows for commodity code ",
        psd_manual_prior_rice_commodity_code(),
        " / ",
        psd_manual_prior_rice_commodity_name(),
        "."
      ),
      call. = FALSE
    )
  }

  release_year <- prior_release_key %/% 100L
  release_month <- prior_release_key %% 100L
  extracted_at_utc <- format(as.POSIXct(Sys.time(), tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  market_year_values <- coerce_manual_prior_psd_numeric(rice_rows$Market_Year, "Market_Year", integer = TRUE)
  market_year_window <- paste(range(market_year_values, na.rm = TRUE), collapse = "-")

  numeric_rice_rows <- rice_rows %>%
    mutate(
      marketYear = market_year_values,
      calendarYear = coerce_manual_prior_psd_numeric(.data$Calendar_Year, "Calendar_Year", integer = TRUE),
      month = coerce_manual_prior_psd_numeric(.data$Month, "Month", integer = TRUE),
      attributeId = coerce_manual_prior_psd_numeric(.data$Attribute_ID, "Attribute_ID", integer = TRUE),
      unitId = coerce_manual_prior_psd_numeric(.data$Unit_ID, "Unit_ID", integer = TRUE),
      value = coerce_manual_prior_psd_numeric(.data$Value, "Value", integer = FALSE),
      attributeName = trimws(as.character(.data$Attribute_Description)),
      normalized_online_unit = normalize_manual_prior_psd_unit_for_attribute(.data$attributeId, .data$attributeName, .data$Unit_Description),
      unitDescription = .data$normalized_online_unit,
      manual_prior_world_row = manual_prior_psd_world_row_filter(pick(everything()))
    )

  crosswalk <- psd_phase1_metric_crosswalk()
  crosswalk_check <- numeric_rice_rows %>%
    distinct(.data$attributeId, .data$attributeName, .data$unitDescription, .data$normalized_online_unit) %>%
    left_join(
      crosswalk %>% select("attributeId", "attributeName", "canonical_unit"),
      by = c("attributeId", "attributeName")
    )

  missing_crosswalk <- crosswalk_check %>% filter(is.na(.data$canonical_unit))
  if (nrow(missing_crosswalk) > 0) {
    stop(
      paste0(
        "Manual prior PSD CSV includes attributes missing from the phase-1 crosswalk: ",
        paste(sprintf("%s (%s)", missing_crosswalk$attributeName, missing_crosswalk$attributeId), collapse = ", "),
        "."
      ),
      call. = FALSE
    )
  }

  bad_units <- crosswalk_check %>% filter(.data$normalized_online_unit != .data$canonical_unit)
  if (nrow(bad_units) > 0) {
    stop(
      paste0(
        "Manual prior PSD CSV unit compatibility failed: ",
        paste(
          sprintf(
            "%s (%s) unit %s normalized to %s but expected %s",
            bad_units$attributeName,
            bad_units$attributeId,
            bad_units$unitDescription,
            bad_units$normalized_online_unit,
            bad_units$canonical_unit
          ),
          collapse = "; "
        ),
        "."
      ),
      call. = FALSE
    )
  }

  normalized_source <- numeric_rice_rows %>%
    transmute(
      commodityCode = psd_manual_prior_rice_commodity_code(),
      countryCode = dplyr::if_else(.data$manual_prior_world_row, psd_native_world_country_code(), trimws(as.character(.data$Country_Code))),
      marketYear = .data$marketYear,
      calendarYear = .data$calendarYear,
      month = .data$month,
      attributeId = .data$attributeId,
      unitId = .data$unitId,
      value = .data$value,
      commodityName = psd_manual_prior_rice_commodity_name(),
      countryName = trimws(as.character(.data$Country_Name)),
      regionCode = "",
      gencCode = "",
      regionName = "",
      unitDescription = .data$unitDescription,
      attributeName = .data$attributeName,
      countryDescription = dplyr::if_else(.data$manual_prior_world_row, "World", trimws(as.character(.data$Country_Name))),
      release_row_key = paste(
        psd_manual_prior_rice_commodity_code(),
        dplyr::if_else(.data$manual_prior_world_row, psd_native_world_country_code(), trimws(as.character(.data$Country_Code))),
        .data$marketYear,
        .data$calendarYear,
        .data$month,
        .data$attributeId,
        .data$unitId,
        prior_release_period,
        sep = "|"
      ),
      releaseYear = release_year,
      releaseMonth = release_month,
      release_period = prior_release_period,
      market_year_window = market_year_window,
      extracted_at_utc = extracted_at_utc,
      raw_csv_path = normalizePath(csv_path, winslash = "/", mustWork = TRUE),
      country_name_endpoint = trimws(as.character(.data$Country_Name)),
      country_description_endpoint_raw = dplyr::if_else(.data$manual_prior_world_row, "World", trimws(as.character(.data$Country_Name))),
      country_description_authoritative = dplyr::if_else(.data$manual_prior_world_row, "World", trimws(as.character(.data$Country_Name))),
      countryName_lookup = dplyr::if_else(.data$manual_prior_world_row, "World", trimws(as.character(.data$Country_Name))),
      psd_endpoint_scope = dplyr::if_else(.data$manual_prior_world_row, "world", "all_countries"),
      world_rollup_mode = NA_character_,
      world_rollup_release_periods = NA_character_,
      world_country_count = NA_integer_,
      world_is_mixed_release = NA,
      world_value_conflict_flag = NA,
      world_native_value_reference = NA_real_,
      world_derived_value_reference = NA_real_
    )

  assert_dataset_columns(normalized_source, required_psd_source_cols, "manual prior PSD normalized source")

  normalized_metadata <- normalized_source %>%
    distinct(
      .data$commodityCode, .data$countryCode, .data$marketYear, .data$calendarYear, .data$month,
      .data$releaseYear, .data$releaseMonth, .data$release_period,
      .data$raw_csv_path, .data$market_year_window, .data$extracted_at_utc
    )

  if (!dir.exists(staging_dir)) dir.create(staging_dir, recursive = TRUE)
  source_path <- file.path(staging_dir, paste0("manual_prior_psd_source_", prior_release_period, ".csv"))
  metadata_path <- file.path(staging_dir, paste0("manual_prior_psd_metadata_", prior_release_period, ".csv"))
  write.csv(normalized_source, source_path, row.names = FALSE, na = "")
  write.csv(normalized_metadata, metadata_path, row.names = FALSE, na = "")

  assert_required_columns(source_path, required_psd_source_cols, basename(source_path))
  assert_required_columns(
    metadata_path,
    c(
      "commodityCode", "countryCode", "marketYear", "calendarYear", "month",
      "releaseYear", "releaseMonth", "release_period", "raw_csv_path", "market_year_window", "extracted_at_utc"
    ),
    basename(metadata_path)
  )

  list(
    ok = TRUE,
    source_path = normalizePath(source_path, winslash = "/", mustWork = TRUE),
    metadata_path = normalizePath(metadata_path, winslash = "/", mustWork = TRUE),
    row_count = nrow(normalized_source),
    metadata_row_count = nrow(normalized_metadata),
    raw_row_count = nrow(raw_manual),
    rice_row_count = nrow(rice_rows),
    world_row_count = sum(normalized_source$countryCode == psd_native_world_country_code(), na.rm = TRUE),
    world_status = if (any(normalized_source$countryCode == psd_native_world_country_code(), na.rm = TRUE)) "native_world_rows_present" else "manual_prior_no_native_world_rows",
    prior_release_key = prior_release_key,
    prior_release_period = prior_release_period,
    schema_version = resolution$schema_version,
    csv_path = normalizePath(csv_path, winslash = "/", mustWork = TRUE),
    csv_signature = resolution$csv_signature,
    unit_check = crosswalk_check
  )
}

load_manual_prior_psd_marketing_year_data <- function(resolution, country_canonical_map, staging_dir = tempfile("manual_prior_psd_staging_")) {
  staging <- normalize_manual_prior_psd_csv_to_staging(
    resolution = resolution,
    staging_dir = staging_dir
  )

  data <- load_psd_marketing_year_data(
    path = staging$source_path,
    metadata_path = staging$metadata_path,
    country_canonical_map = country_canonical_map
  )

  list(
    ok = TRUE,
    data = data,
    staging = staging,
    resolution = resolution
  )
}

required_wasde_source_cols <- c(
  "COMMODITY_DESC", "COMMODITY_DESC2",
  "UNIT_DESC", "ATTRIBUTE_DESC", "GEOGRAPHY_DESC",
  "TIMEPERIOD_ID", "TIMEPERIOD_DESC", "TIMEPERIOD_SHORT", "TIMEPERIOD_LONG",
  "DATE_ESTIMATE_MADE", "LAST_UPDATED",
  "YEAR_ID", "AMOUNT"
)

required_waob_wasde_source_cols <- c(
  "wb_id", "cn_code", "cn_name",
  "cm_code", "cm_description",
  "attribute_id", "attribute_description",
  "cm_unit_id", "cm_unit_description",
  "wb_unit_id", "wb_unit_description",
  "market_year", "calendar_year", "forecast_month",
  "cm_value", "wb_value", "psd_value",
  "release_year", "release_month", "release_period",
  "last_update", "psd_last_update", "update_source", "update_userid"
)

psd_supported_volume_metric_ids <- c(
  "beginning_stocks", "production", "rough_production", "imports",
  "ty_imports", "ty_imports_from_us", "total_supply", "exports",
  "ty_exports", "domestic_consumption", "ending_stocks", "total_distribution"
)

psd_sum_based_metric_ids <- c(
  "area_harvested", "beginning_stocks", "production", "rough_production", "imports",
  "ty_imports", "ty_imports_from_us", "exports", "ty_exports",
  "domestic_consumption", "ending_stocks"
)

psd_derived_metric_ids <- c("yield", "milling_rate", "total_supply", "total_distribution")

psd_hidden_metric_ids <- c("area_harvested", "milling_rate", "yield")

psd_required_processed_cols <- c(
  "source", "frequency", "commodity", "commodity_group", "country", "countryDescription", "country_source_code",
  "market_year", "analysis_month", "calendar_year", "calendar_month",
  "release_year", "release_month", "release_period",
  "attribute_id", "attribute_name", "unit_id", "unit_name_raw",
  "phase1_status", "normalized_metric_id", "canonical_unit", "unit_handling_notes",
  "value_raw", "value_canonical", "release_row_key",
  "market_year_window", "extracted_at_utc",
  "value_provenance", "provenance_note", "world_source", "construction_components",
  "psd_endpoint_scope", "country_legacy_code", "countryDescription_legacy", "canonical_review_row_id",
  "world_rollup_mode", "world_rollup_release_periods", "world_country_count", "world_is_mixed_release",
  "world_value_conflict_flag", "world_native_value_reference", "world_derived_value_reference"
)

wasde_required_processed_cols <- c(
  "source", "frequency", "commodity", "commodity_group", "country", "countryDescription", "country_source_code",
  "market_year", "analysis_month", "calendar_year", "calendar_month",
  "release_year", "release_month", "release_period",
  "current_report_year", "current_report_month", "current_report_period", "current_report_label",
  "attribute_id", "attribute_name", "unit_id", "unit_name_raw",
  "revision_metric_id", "revision_unit_class",
  "phase1_status", "normalized_metric_id", "canonical_unit", "unit_handling_notes",
  "value_raw", "value_canonical", "release_row_key",
  "value_last_updated_at",
  "wasde_timeperiod_desc_raw", "wasde_timeperiod_short_raw", "wasde_timeperiod_long_raw",
  "wasde_public_last_updated_raw", "wasde_date_estimate_made_raw",
  "market_year_window", "extracted_at_utc",
  "value_provenance", "provenance_note", "world_source", "construction_components",
  "country_legacy_code", "countryDescription_legacy", "canonical_review_row_id"
)

waob_wasde_release_history_required_processed_cols <- c(
  wasde_required_processed_cols,
  "waob_row_id", "waob_country_code_raw", "waob_country_name_raw",
  "waob_commodity_code_raw", "waob_commodity_name_raw",
  "waob_attribute_id_raw", "waob_attribute_name_raw",
  "waob_cm_unit_id_raw", "waob_cm_unit_name_raw",
  "waob_wb_unit_id_raw", "waob_wb_unit_name_raw",
  "waob_forecast_month_raw", "waob_calendar_year_raw",
  "waob_release_year_raw", "waob_release_month_raw", "waob_release_period_raw",
  "waob_last_update_raw", "waob_psd_last_update_raw",
  "waob_pairing_key", "waob_report_unit_source"
)

wasde_revision_delta_required_processed_cols <- c(
  "source", "frequency", "commodity", "commodity_group", "country", "countryDescription", "country_source_code",
  "market_year", "analysis_month", "calendar_year", "calendar_month",
  "normalized_metric_id", "attribute_id", "attribute_name", "unit_id", "unit_name_raw", "canonical_unit",
  "revision_metric_id", "revision_unit_class",
  "phase1_status", "market_year_window", "extracted_at_utc",
  "current_release_year", "current_release_month", "current_release_period", "current_release_ord",
  "current_release_row_key", "current_waob_row_id", "current_value_canonical",
  "prior_release_year", "prior_release_month", "prior_release_period", "prior_release_ord",
  "prior_release_row_key", "prior_waob_row_id", "prior_value_canonical",
  "prior_waob_commodity_basis", "prior_waob_raw_commodity_code", "prior_waob_raw_commodity_name",
  "prior_waob_basis_candidate_count", "prior_waob_candidate_score", "prior_waob_candidate_margin",
  "prior_waob_basis_selection_status", "rough_candidate_raw_value", "milled_candidate_raw_value",
  "rough_candidate_raw_rel_diff", "milled_candidate_raw_rel_diff",
  "rough_candidate_diag_rel_diff", "milled_candidate_diag_rel_diff",
  "milling_rate_diagnostic_value",
  "prior_release_available", "release_gap_months",
  "series_mapping_status", "series_mapping_rule",
  "value_last_updated_at", "wasde_public_last_updated_raw", "waob_last_update_raw", "waob_psd_last_update_raw",
  "value_provenance", "provenance_note",
  "waob_pairing_key", "waob_report_unit_source",
  "country_legacy_code", "countryDescription_legacy", "canonical_review_row_id"
)

psd_revision_delta_required_processed_cols <- c(
  "source", "frequency", "commodity", "commodity_group", "country", "countryDescription", "country_source_code",
  "market_year", "analysis_month", "calendar_year", "calendar_month",
  "normalized_metric_id", "attribute_id", "attribute_name", "unit_id", "unit_name_raw", "canonical_unit",
  "phase1_status", "metric_class", "basis_profile", "market_year_window", "extracted_at_utc",
  "current_release_year", "current_release_month", "current_release_period", "current_release_ord",
  "current_release_row_key", "current_value_canonical",
  "prior_release_year", "prior_release_month", "prior_release_period", "prior_release_ord",
  "prior_release_row_key", "prior_value_canonical",
  "prior_release_available", "release_gap_months",
  "value_difference", "percent_difference",
  "simulated_delta_active", "simulated_delta_factor", "simulated_delta_zero_holdout", "development_placeholder",
  "world_pairing_status", "series_mapping_status", "series_mapping_rule",
  "value_provenance", "provenance_note", "world_source", "construction_components",
  "psd_endpoint_scope", "country_legacy_code", "countryDescription_legacy", "canonical_review_row_id"
)

psd_native_world_country_code <- function() {
  "WORLD"
}

psd_world_country_code <- function() {
  "GRAND_TOTAL"
}

psd_app_commodity_label <- function(default = "All Rice") {
  value <- getOption("commodity_psd_app_commodity_label", default = default)
  value <- trimws(as.character(value[[1]]))
  if (nzchar(value)) value else default
}

psd_app_commodity_group <- function(default = psd_app_commodity_label()) {
  value <- getOption("commodity_psd_app_commodity_group", default = default)
  value <- trimws(as.character(value[[1]]))
  if (nzchar(value)) value else default
}

psd_milling_rate_ratio <- function(production_value, rough_production_value) {
  ifelse(
    !is.na(production_value) & !is.na(rough_production_value) & rough_production_value != 0,
    (production_value / rough_production_value) * 10000,
    NA_real_
  )
}

psd_yield_value <- function(rough_production_value, area_harvested_value) {
  ifelse(
    !is.na(rough_production_value) & !is.na(area_harvested_value) & area_harvested_value != 0,
    rough_production_value / area_harvested_value,
    NA_real_
  )
}

psd_total_supply_value <- function(beginning_stocks_value, production_value, imports_value) {
  ifelse(
    !is.na(beginning_stocks_value) & !is.na(production_value) & !is.na(imports_value),
    beginning_stocks_value + production_value + imports_value,
    NA_real_
  )
}

psd_total_distribution_value <- function(domestic_consumption_value, exports_value, ending_stocks_value) {
  ifelse(
    !is.na(domestic_consumption_value) & !is.na(exports_value) & !is.na(ending_stocks_value),
    domestic_consumption_value + exports_value + ending_stocks_value,
    NA_real_
  )
}

psd_rough_from_milled_value <- function(milled_value, milling_rate_value) {
  ifelse(
    !is.na(milled_value) & !is.na(milling_rate_value) & milling_rate_value > 0,
    milled_value * (10000 / milling_rate_value),
    NA_real_
  )
}

psd_milled_from_rough_value <- function(rough_value, milling_rate_value) {
  ifelse(
    !is.na(rough_value) & !is.na(milling_rate_value) & milling_rate_value > 0,
    rough_value * (milling_rate_value / 10000),
    NA_real_
  )
}

psd_companion_metric_crosswalk <- function() {
  tibble::tibble(
    attributeId = c(-1001L, -1002L, -1003L, -1004L, -1005L, -1006L, -1007L, -1008L, -1009L, -1010L, -1011L, -1012L, -1013L),
    attributeName = c(
      "Area Harvested (Rough-equivalent)",
      "Beginning Stocks (Rough-equivalent)",
      "Production (Rough-equivalent)",
      "Imports (Rough-equivalent)",
      "TY Imports (Rough-equivalent)",
      "TY Imp. from U.S. (Rough-equivalent)",
      "Total Supply (Rough-equivalent)",
      "Exports (Rough-equivalent)",
      "TY Exports (Rough-equivalent)",
      "Domestic Consumption (Rough-equivalent)",
      "Ending Stocks (Rough-equivalent)",
      "Total Distribution (Rough-equivalent)",
      "Yield (Milled-equivalent)"
    ),
    phase1_status = rep("stored-hidden", 13),
    normalized_metric_id = c(
      "area_harvested_rough_eq",
      "beginning_stocks_rough_eq",
      "production_rough_eq",
      "imports_rough_eq",
      "ty_imports_rough_eq",
      "ty_imports_from_us_rough_eq",
      "total_supply_rough_eq",
      "exports_rough_eq",
      "ty_exports_rough_eq",
      "domestic_consumption_rough_eq",
      "ending_stocks_rough_eq",
      "total_distribution_rough_eq",
      "yield_milled_eq"
    ),
    canonical_unit = c(
      "1000 HA",
      rep("1000 MT", 11),
      "MT/HA"
    ),
    unit_handling_notes = c(
      "Derived basis-neutral companion row for app basis pairing.",
      rep("Derived rough-equivalent companion row from PSD milling rate.", 11),
      "Derived milled-equivalent companion row from native rough-equivalent Yield and PSD milling rate."
    )
  )
}

psd_market_year_month <- function(calendar_month_value) {
  calendar_month_num <- suppressWarnings(as.integer(calendar_month_value))
  ifelse(calendar_month_num >= 8, calendar_month_num - 7, calendar_month_num + 5)
}

psd_build_world_fallback_rows <- function(country_rows, template_world_rows = NULL) {
  if (!is.data.frame(country_rows) || nrow(country_rows) == 0) {
    return(tibble())
  }

  grouping_cols <- c(
    "source", "frequency", "commodity", "commodity_group",
    "market_year", "analysis_month", "calendar_year", "calendar_month",
    "release_year", "release_month", "release_period",
    "market_year_window", "extracted_at_utc"
  )

  fallback_base <- country_rows %>%
    filter(.data$country != psd_world_country_code()) %>%
    group_by(across(all_of(grouping_cols))) %>%
    summarise(
      expected_country_count = dplyr::n_distinct(.data$country),
      construction_components = paste(sort(unique(.data$country)), collapse = "|"),
      .groups = "drop"
    )

  if (nrow(fallback_base) == 0) {
    return(tibble())
  }

  metric_template <- country_rows %>%
    filter(.data$country != psd_world_country_code()) %>%
    distinct(
      .data$attribute_id,
      .data$attribute_name,
      .data$normalized_metric_id,
      .data$unit_id,
      .data$unit_name_raw,
      .data$phase1_status,
      .data$canonical_unit,
      .data$unit_handling_notes
    )

  fallback_rows <- fallback_base %>%
    tidyr::crossing(metric_template) %>%
    left_join(
      country_rows %>%
        filter(.data$country != psd_world_country_code()) %>%
        group_by(
          across(all_of(grouping_cols)),
          .data$attribute_id,
          .data$attribute_name,
          .data$normalized_metric_id,
          .data$unit_id,
          .data$unit_name_raw,
          .data$phase1_status,
          .data$canonical_unit,
          .data$unit_handling_notes
        ) %>%
        summarise(
          observed_country_count = dplyr::n_distinct(.data$country[!is.na(.data$value_canonical)]),
          sum_value = if (all(is.na(.data$value_canonical))) NA_real_ else sum(.data$value_canonical, na.rm = TRUE),
          .groups = "drop"
        ),
      by = c(grouping_cols, "attribute_id", "attribute_name", "normalized_metric_id", "unit_id", "unit_name_raw", "phase1_status", "canonical_unit", "unit_handling_notes")
    ) %>%
    mutate(
      fallback_eligible = !is.na(.data$expected_country_count) &
        !is.na(.data$observed_country_count) &
        .data$expected_country_count > 0 &
        .data$expected_country_count == .data$observed_country_count
    )

  sum_rows <- fallback_rows %>%
    filter(.data$fallback_eligible, .data$normalized_metric_id %in% psd_sum_based_metric_ids) %>%
    transmute(
      source = .data$source,
      frequency = .data$frequency,
      commodity = .data$commodity,
      commodity_group = .data$commodity_group,
      country = psd_world_country_code(),
      countryDescription = "World",
      country_source_code = psd_world_country_code(),
      market_year = .data$market_year,
      analysis_month = .data$analysis_month,
      calendar_year = .data$calendar_year,
      calendar_month = .data$calendar_month,
      release_year = .data$release_year,
      release_month = .data$release_month,
      release_period = .data$release_period,
      attribute_id = .data$attribute_id,
      attribute_name = .data$attribute_name,
      unit_id = .data$unit_id,
      unit_name_raw = .data$unit_name_raw,
      phase1_status = .data$phase1_status,
      normalized_metric_id = .data$normalized_metric_id,
      canonical_unit = .data$canonical_unit,
      unit_handling_notes = .data$unit_handling_notes,
      value_raw = .data$sum_value,
      value_canonical = .data$sum_value,
      release_row_key = paste(
        .data$market_year,
        .data$calendar_year,
        .data$calendar_month,
        psd_world_country_code(),
        .data$attribute_id,
        "synthetic_world",
        sep = "|"
      ),
      market_year_window = .data$market_year_window,
      extracted_at_utc = .data$extracted_at_utc,
      value_provenance = "synthetic_country_rollup",
      provenance_note = "Synthetic world row from complete country coverage.",
      world_source = "synthetic_country_rollup",
      construction_components = .data$construction_components,
      psd_endpoint_scope = "synthetic_world",
      country_legacy_code = psd_world_country_code(),
      countryDescription_legacy = "World",
      canonical_review_row_id = NA_character_
    )

  derived_input <- sum_rows %>%
    select(
      .data$market_year,
      .data$analysis_month,
      .data$calendar_year,
      .data$calendar_month,
      .data$release_year,
      .data$release_month,
      .data$release_period,
      .data$market_year_window,
      .data$extracted_at_utc,
      .data$construction_components,
      .data$normalized_metric_id,
      .data$value_canonical
    ) %>%
    tidyr::pivot_wider(names_from = normalized_metric_id, values_from = value_canonical) %>%
    mutate(
      yield = psd_yield_value(.data$rough_production, .data$area_harvested),
      milling_rate = psd_milling_rate_ratio(.data$production, .data$rough_production),
      total_supply = psd_total_supply_value(.data$beginning_stocks, .data$production, .data$imports),
      total_distribution = psd_total_distribution_value(.data$domestic_consumption, .data$exports, .data$ending_stocks)
    )

  derive_metric_row <- function(metric_id, attribute_name_value, unit_name_value, canonical_unit_value) {
    fallback_base %>%
      left_join(
        derived_input %>%
          select(
            .data$market_year,
            .data$analysis_month,
            .data$calendar_year,
            .data$calendar_month,
            .data$release_year,
            .data$release_month,
            .data$release_period,
            .data$market_year_window,
            .data$extracted_at_utc,
            .data$construction_components,
            !!metric_id := all_of(metric_id)
          ),
        by = c(
          "market_year", "analysis_month", "calendar_year", "calendar_month",
          "release_year", "release_month", "release_period", "market_year_window", "extracted_at_utc", "construction_components"
        )
      ) %>%
      transmute(
        source = "psd",
        frequency = "monthly",
        commodity = psd_app_commodity_label(),
        commodity_group = psd_app_commodity_group(),
        country = psd_world_country_code(),
        countryDescription = "World",
        country_source_code = psd_world_country_code(),
        market_year = .data$market_year,
        analysis_month = .data$analysis_month,
        calendar_year = .data$calendar_year,
        calendar_month = .data$calendar_month,
        release_year = .data$release_year,
        release_month = .data$release_month,
        release_period = .data$release_period,
        attribute_id = psd_phase1_metric_crosswalk()$attributeId[match(metric_id, psd_phase1_metric_crosswalk()$normalized_metric_id)],
        attribute_name = attribute_name_value,
        unit_id = NA_integer_,
        unit_name_raw = unit_name_value,
        phase1_status = if (metric_id %in% psd_hidden_metric_ids) "stored-hidden" else "supported-mapped",
        normalized_metric_id = metric_id,
        canonical_unit = canonical_unit_value,
        unit_handling_notes = "Derived synthetic world metric from complete country coverage.",
        value_raw = .data[[metric_id]],
        value_canonical = .data[[metric_id]],
        release_row_key = paste(
          .data$market_year,
          .data$calendar_year,
          .data$calendar_month,
          psd_world_country_code(),
          metric_id,
          "synthetic_world",
          sep = "|"
        ),
        market_year_window = .data$market_year_window,
        extracted_at_utc = .data$extracted_at_utc,
        value_provenance = "derived_from_components",
        provenance_note = "Derived synthetic world metric from complete country coverage.",
        world_source = "synthetic_country_rollup",
        construction_components = .data$construction_components,
        psd_endpoint_scope = "synthetic_world",
        country_legacy_code = psd_world_country_code(),
        countryDescription_legacy = "World",
        canonical_review_row_id = NA_character_
      ) %>%
      filter(!is.na(.data$value_canonical))
  }

  derived_rows <- bind_rows(
    derive_metric_row(
      metric_id = "yield",
      attribute_name_value = "Yield",
      unit_name_value = "(MT/HA)",
      canonical_unit_value = "MT/HA"
    ),
    derive_metric_row(
      metric_id = "milling_rate",
      attribute_name_value = "Milling Rate (.9999)",
      unit_name_value = "(.9999)",
      canonical_unit_value = "ratio"
    ),
    derive_metric_row(
      metric_id = "total_supply",
      attribute_name_value = "Total Supply",
      unit_name_value = "(1000 MT)",
      canonical_unit_value = "1000 MT"
    ),
    derive_metric_row(
      metric_id = "total_distribution",
      attribute_name_value = "Total Distribution",
      unit_name_value = "(1000 MT)",
      canonical_unit_value = "1000 MT"
    )
  )

  bind_rows(sum_rows, derived_rows)
}

psd_phase1_metric_crosswalk <- function() {
  native_crosswalk <- tibble::tibble(
    attributeId = c(4L, 20L, 28L, 54L, 57L, 81L, 84L, 86L, 88L, 113L, 125L, 176L, 178L, 182L, 184L),
    attributeName = c(
      "Area Harvested", "Beginning Stocks", "Production", "Rough Production", "Imports",
      "TY Imports", "TY Imp. from U.S.", "Total Supply", "Exports", "TY Exports",
      "Domestic Consumption", "Ending Stocks", "Total Distribution", "Milling Rate (.9999)", "Yield"
    ),
    phase1_status = c(
      "stored-hidden", "supported-mapped", "supported-mapped", "supported-mapped", "supported-mapped",
      "supported-mapped", "supported-mapped", "supported-mapped", "supported-mapped", "supported-mapped",
      "supported-mapped", "supported-mapped", "supported-mapped", "stored-hidden", "stored-hidden"
    ),
    normalized_metric_id = c(
      "area_harvested", "beginning_stocks", "production", "rough_production", "imports",
      "ty_imports", "ty_imports_from_us", "total_supply", "exports", "ty_exports",
      "domestic_consumption", "ending_stocks", "total_distribution", "milling_rate", "yield"
    ),
    canonical_unit = c(
      "1000 HA", "1000 MT", "1000 MT", "1000 MT", "1000 MT",
      "1000 MT", "1000 MT", "1000 MT", "1000 MT", "1000 MT",
      "1000 MT", "1000 MT", "1000 MT", "ratio", "MT/HA"
    ),
    unit_handling_notes = c(
      "Preserve raw 1000 HA for inspection only in phase 1.",
      "Keep raw 1000 MT as the phase-1 canonical inspection unit.",
      "Keep raw 1000 MT as the phase-1 canonical inspection unit.",
      "Keep raw 1000 MT as the phase-1 canonical inspection unit.",
      "Keep raw 1000 MT as the phase-1 canonical inspection unit.",
      "Keep raw 1000 MT as the phase-1 canonical inspection unit.",
      "Keep raw 1000 MT as the phase-1 canonical inspection unit.",
      "Keep raw 1000 MT as the phase-1 canonical inspection unit.",
      "Keep raw 1000 MT as the phase-1 canonical inspection unit.",
      "Keep raw 1000 MT as the phase-1 canonical inspection unit.",
      "Keep raw 1000 MT as the phase-1 canonical inspection unit.",
      "Keep raw 1000 MT as the phase-1 canonical inspection unit.",
      "Keep raw 1000 MT as the phase-1 canonical inspection unit.",
      "Preserve raw milling-rate ratio for inspection only in phase 1.",
      "Preserve raw MT/HA for inspection only in phase 1."
    )
  )

  bind_rows(native_crosswalk, psd_companion_metric_crosswalk())
}

build_psd_phase1_crosswalk_signature <- function() {
  crosswalk <- psd_phase1_metric_crosswalk() %>%
    arrange(.data$attributeId) %>%
    transmute(
      signature_row = paste(
        .data$attributeId,
        .data$attributeName,
        .data$phase1_status,
        .data$normalized_metric_id,
        .data$canonical_unit,
        .data$unit_handling_notes,
        sep = "::"
      )
    )

  paste(crosswalk$signature_row, collapse = "||")
}

psd_historical_records_metric_profiles <- function() {
  app_metric_map <- c(
    area_harvested = "psd_area_harvested",
    beginning_stocks = "psd_beginning_stocks",
    production = "psd_production",
    imports = "psd_imports",
    ty_imports = "psd_ty_imports",
    ty_imports_from_us = "psd_ty_imports_from_us",
    total_supply = "psd_total_supply",
    exports = "psd_exports",
    ty_exports = "psd_ty_exports",
    yield = "psd_yield",
    domestic_consumption = "psd_domestic_consumption",
    ending_stocks = "psd_ending_stocks",
    total_distribution = "psd_total_distribution"
  )

  quantity_metric_ids <- setdiff(names(app_metric_map), c("area_harvested", "yield"))

  dplyr::bind_rows(
    tibble::tibble(
      metric_id = "area_harvested",
      metric_code = unname(app_metric_map[["area_harvested"]]),
      normalized_metric_id = "area_harvested",
      basis_profile = "area",
      metric_class = "area"
    ),
    tibble::tibble(
      metric_id = rep(quantity_metric_ids, each = 2L),
      metric_code = unname(app_metric_map[rep(quantity_metric_ids, each = 2L)]),
      normalized_metric_id = as.vector(rbind(quantity_metric_ids, paste0(quantity_metric_ids, "_rough_eq"))),
      basis_profile = rep(c("milled_eq", "rough_eq"), times = length(quantity_metric_ids)),
      metric_class = "quantity"
    ),
    tibble::tibble(
      metric_id = "yield",
      metric_code = unname(app_metric_map[["yield"]]),
      normalized_metric_id = c("yield_milled_eq", "yield"),
      basis_profile = c("milled_eq", "rough_eq"),
      metric_class = "yield"
    ),
    tibble::tibble(
      metric_id = "milling_rate",
      metric_code = "psd_milling_rate",
      normalized_metric_id = "milling_rate",
      basis_profile = "rate",
      metric_class = "rate"
    )
  )
}

reduce_psd_latest_market_year_estimates <- function(data, group_cols) {
  if (!is.data.frame(data) || nrow(data) == 0) {
    return(tibble::tibble())
  }

  required_cols <- c("market_year", "analysis_month", "release_year", "release_month", group_cols)
  missing_cols <- setdiff(required_cols, names(data))
  if (length(missing_cols) > 0) {
    stop(
      paste0(
        "reduce_psd_latest_market_year_estimates() missing required columns: ",
        paste(missing_cols, collapse = ", ")
      ),
      call. = FALSE
    )
  }

  data %>%
    dplyr::mutate(
      market_year_num = suppressWarnings(as.integer(.data$market_year)),
      analysis_month_num = suppressWarnings(as.numeric(.data$analysis_month)),
      release_year_num = suppressWarnings(as.integer(.data$release_year)),
      release_month_num = suppressWarnings(as.integer(.data$release_month))
    ) %>%
    dplyr::arrange(
      dplyr::desc(.data$release_year_num),
      dplyr::desc(.data$release_month_num),
      dplyr::desc(.data$analysis_month_num),
      dplyr::desc(.data$market_year_num)
    ) %>%
    dplyr::group_by(dplyr::across(dplyr::all_of(unique(c(group_cols, "market_year"))))) %>%
    dplyr::slice_head(n = 1L) %>%
    dplyr::ungroup() %>%
    dplyr::select(-dplyr::any_of(c("market_year_num", "analysis_month_num", "release_year_num", "release_month_num")))
}

build_historical_record_all_time_rows_for_series <- function(series_df) {
  if (!is.data.frame(series_df) || nrow(series_df) == 0) {
    return(tibble::tibble())
  }

  series_df <- series_df %>%
    dplyr::mutate(
      market_year = suppressWarnings(as.integer(.data$market_year)),
      analysis_value = suppressWarnings(as.numeric(.data$analysis_value))
    ) %>%
    dplyr::filter(!is.na(.data$market_year), !is.na(.data$analysis_value), is.finite(.data$analysis_value)) %>%
    dplyr::arrange(.data$market_year)

  if (nrow(series_df) == 0) {
    return(tibble::tibble())
  }

  years <- series_df$market_year
  values <- series_df$analysis_value
  rows <- list()

  for (direction in c("high", "low")) {
    comparison_indices <- which(!is.na(values) & is.finite(values))
    low_positive_count <- sum(values[comparison_indices] > 0, na.rm = TRUE)
    if (identical(direction, "low")) {
      comparison_indices <- comparison_indices[values[comparison_indices] > 0]
    } else {
      comparison_indices <- comparison_indices[values[comparison_indices] > 0]
    }
    valid_comparison_count <- length(comparison_indices)
    if (valid_comparison_count == 0L) next

    record_value <- if (identical(direction, "high")) {
      max(values[comparison_indices], na.rm = TRUE)
    } else {
      min(values[comparison_indices], na.rm = TRUE)
    }

    if (identical(direction, "low")) {
      high_value <- max(values[comparison_indices], na.rm = TRUE)
      if (!is.na(high_value) && isTRUE(all.equal(high_value, record_value, tolerance = sqrt(.Machine$double.eps)))) next
    }

    tie_indices <- comparison_indices[values[comparison_indices] == record_value]
    selected_index <- max(tie_indices, na.rm = TRUE)
    selected_row <- series_df[selected_index, , drop = FALSE]
    selected_year <- years[[selected_index]]

    next_indices <- if (identical(direction, "high")) {
      comparison_indices[values[comparison_indices] < record_value]
    } else {
      comparison_indices[values[comparison_indices] > record_value]
    }
    next_distinct_value <- if (length(next_indices) == 0L) {
      NA_real_
    } else if (identical(direction, "high")) {
      max(values[next_indices], na.rm = TRUE)
    } else {
      min(values[next_indices], na.rm = TRUE)
    }
    next_distinct_year <- if (is.na(next_distinct_value)) {
      NA_integer_
    } else {
      max(years[next_indices[values[next_indices] == next_distinct_value]], na.rm = TRUE)
    }
    gap_abs <- if (is.na(next_distinct_value)) {
      NA_real_
    } else if (identical(direction, "high")) {
      record_value - next_distinct_value
    } else {
      next_distinct_value - record_value
    }
    gap_pct_status <- dplyr::case_when(
      is.na(next_distinct_value) ~ "initial_record",
      next_distinct_value == 0 ~ "undefined_zero_comparator",
      TRUE ~ "ok"
    )
    gap_pct <- if (identical(gap_pct_status, "ok")) {
      (gap_abs / abs(next_distinct_value)) * 100
    } else {
      NA_real_
    }
    tie_peer_candidates <- years[tie_indices[years[tie_indices] != selected_year]]

    rows[[length(rows) + 1L]] <- data.frame(
      country = selected_row$country[[1]],
      countryDescription = selected_row$countryDescription[[1]],
      commodity = selected_row$commodity[[1]],
      metric_id = selected_row$metric_id[[1]],
      metric_code = selected_row$metric_code[[1]],
      metric_class = selected_row$metric_class[[1]],
      basis_profile = selected_row$basis_profile[[1]],
      market_year = selected_year,
      analysis_month = selected_row$analysis_month[[1]],
      release_year = selected_row$release_year[[1]],
      release_month = selected_row$release_month[[1]],
      release_period = selected_row$release_period[[1]],
      direction = direction,
      window_label = "record",
      window_size = NA_integer_,
      actual_years_available = length(which(!is.na(values) & is.finite(values))),
      valid_comparison_count = valid_comparison_count,
      low_positive_count = low_positive_count,
      selected_value = record_value,
      record_value = record_value,
      is_tied_record = length(tie_indices) > 1L,
      tie_count = length(tie_indices),
      tie_peer_year = if (length(tie_peer_candidates) == 0L) NA_integer_ else max(tie_peer_candidates, na.rm = TRUE),
      next_distinct_year = next_distinct_year,
      next_distinct_value = next_distinct_value,
      gap_abs = gap_abs,
      gap_pct_vs_next_distinct = gap_pct,
      gap_pct_status = gap_pct_status,
      record_mode = "all_time",
      stringsAsFactors = FALSE
    )
  }

  if (length(rows) == 0L) return(tibble::tibble())
  tibble::as_tibble(do.call(rbind, rows))
}

build_psd_historical_record_rows_for_series <- function(series_df, windows = c(5L, 10L, 20L, NA_integer_), selected_years = NULL) {
  if (!is.data.frame(series_df) || nrow(series_df) == 0) {
    return(tibble::tibble())
  }

  series_df <- series_df %>%
    dplyr::mutate(
      market_year = suppressWarnings(as.integer(.data$market_year)),
      analysis_value = suppressWarnings(as.numeric(.data$analysis_value))
    ) %>%
    dplyr::filter(!is.na(.data$market_year), !is.na(.data$analysis_value), is.finite(.data$analysis_value)) %>%
    dplyr::arrange(.data$market_year)

  if (nrow(series_df) == 0) {
    return(tibble::tibble())
  }

  years <- series_df$market_year
  values <- series_df$analysis_value
  selected_years <- if (is.null(selected_years)) NULL else unique(suppressWarnings(as.integer(selected_years)))
  selected_years <- selected_years[!is.na(selected_years)]
  if (!is.null(selected_years) && length(selected_years) == 0) {
    return(tibble::tibble())
  }

  selected_indices <- seq_len(nrow(series_df))
  if (!is.null(selected_years)) {
    selected_indices <- selected_indices[years %in% selected_years]
  }
  if (length(selected_indices) == 0) {
    return(tibble::tibble())
  }

  window_specs <- tibble::tibble(
    window_label = ifelse(is.na(windows), "record", as.character(windows)),
    window_size = windows
  )
  max_rows <- length(selected_indices) * nrow(window_specs) * 2L
  rows <- list(
    country = character(max_rows),
    countryDescription = character(max_rows),
    commodity = character(max_rows),
    metric_id = character(max_rows),
    metric_code = character(max_rows),
    metric_class = character(max_rows),
    basis_profile = character(max_rows),
    market_year = integer(max_rows),
    analysis_month = integer(max_rows),
    release_year = integer(max_rows),
    release_month = integer(max_rows),
    release_period = character(max_rows),
    direction = character(max_rows),
    window_label = character(max_rows),
    window_size = integer(max_rows),
    actual_years_available = integer(max_rows),
    valid_comparison_count = integer(max_rows),
    low_positive_count = integer(max_rows),
    selected_value = numeric(max_rows),
    record_value = numeric(max_rows),
    is_tied_record = logical(max_rows),
    tie_count = integer(max_rows),
    tie_peer_year = integer(max_rows),
    next_distinct_year = integer(max_rows),
    next_distinct_value = numeric(max_rows),
    gap_abs = numeric(max_rows),
    gap_pct_vs_next_distinct = numeric(max_rows),
    gap_pct_status = character(max_rows)
  )
  rows$window_size[] <- NA_integer_
  rows$tie_peer_year[] <- NA_integer_
  rows$next_distinct_year[] <- NA_integer_
  rows$next_distinct_value[] <- NA_real_
  rows$gap_abs[] <- NA_real_
  rows$gap_pct_vs_next_distinct[] <- NA_real_
  row_index <- 0L

  for (selected_index in selected_indices) {
    selected_row <- series_df[selected_index, , drop = FALSE]
    selected_year <- years[[selected_index]]
    selected_value <- values[[selected_index]]
    if (is.na(selected_value) || !is.finite(selected_value) || selected_value <= 0) next

    for (window_index in seq_len(nrow(window_specs))) {
      window_size <- window_specs$window_size[[window_index]]
      window_indices <- seq_len(selected_index)
      if (!is.na(window_size) && length(window_indices) > window_size) {
        window_indices <- utils::tail(window_indices, window_size)
      }
      actual_years_available <- length(window_indices)

      for (direction in c("high", "low")) {
        comparison_indices <- window_indices[!is.na(values[window_indices]) & is.finite(values[window_indices])]
        low_positive_count <- sum(values[comparison_indices] > 0, na.rm = TRUE)

        if (identical(direction, "low")) {
          comparison_indices <- comparison_indices[values[comparison_indices] > 0]
        }

        valid_comparison_count <- length(comparison_indices)
        if (valid_comparison_count == 0) next

        record_value <- if (identical(direction, "high")) {
          max(values[comparison_indices], na.rm = TRUE)
        } else {
          min(values[comparison_indices], na.rm = TRUE)
        }

        if (identical(direction, "low")) {
          high_comparison_indices <- window_indices[!is.na(values[window_indices]) & is.finite(values[window_indices])]
          high_record_value <- if (length(high_comparison_indices) == 0L) {
            NA_real_
          } else {
            max(values[high_comparison_indices], na.rm = TRUE)
          }
          if (!is.na(high_record_value) && isTRUE(all.equal(high_record_value, record_value, tolerance = sqrt(.Machine$double.eps)))) next
        }

        if (!isTRUE(all.equal(selected_value, record_value, tolerance = sqrt(.Machine$double.eps)))) next

        tie_indices <- comparison_indices[values[comparison_indices] == record_value]
        next_indices <- if (identical(direction, "high")) {
          comparison_indices[values[comparison_indices] < record_value]
        } else {
          comparison_indices[values[comparison_indices] > record_value]
        }

        next_distinct_value <- if (length(next_indices) == 0) {
          NA_real_
        } else if (identical(direction, "high")) {
          max(values[next_indices], na.rm = TRUE)
        } else {
          min(values[next_indices], na.rm = TRUE)
        }

        next_distinct_year <- if (is.na(next_distinct_value)) {
          NA_integer_
        } else {
          max(years[next_indices[values[next_indices] == next_distinct_value]], na.rm = TRUE)
        }

        gap_abs <- if (is.na(next_distinct_value)) {
          NA_real_
        } else if (identical(direction, "high")) {
          selected_value - next_distinct_value
        } else {
          next_distinct_value - selected_value
        }

        gap_pct_status <- dplyr::case_when(
          is.na(next_distinct_value) ~ "initial_record",
          next_distinct_value == 0 ~ "undefined_zero_comparator",
          TRUE ~ "ok"
        )
        gap_pct <- if (identical(gap_pct_status, "ok")) {
          (gap_abs / abs(next_distinct_value)) * 100
        } else {
          NA_real_
        }

        tie_peer_candidates <- years[tie_indices[years[tie_indices] != selected_year]]
        tie_peer_year <- if (length(tie_peer_candidates) == 0) NA_integer_ else max(tie_peer_candidates, na.rm = TRUE)

        row_index <- row_index + 1L
        rows$country[[row_index]] <- selected_row$country[[1]]
        rows$countryDescription[[row_index]] <- selected_row$countryDescription[[1]]
        rows$commodity[[row_index]] <- selected_row$commodity[[1]]
        rows$metric_id[[row_index]] <- selected_row$metric_id[[1]]
        rows$metric_code[[row_index]] <- selected_row$metric_code[[1]]
        rows$metric_class[[row_index]] <- selected_row$metric_class[[1]]
        rows$basis_profile[[row_index]] <- selected_row$basis_profile[[1]]
        rows$market_year[[row_index]] <- selected_year
        rows$analysis_month[[row_index]] <- selected_row$analysis_month[[1]]
        rows$release_year[[row_index]] <- selected_row$release_year[[1]]
        rows$release_month[[row_index]] <- selected_row$release_month[[1]]
        rows$release_period[[row_index]] <- selected_row$release_period[[1]]
        rows$direction[[row_index]] <- direction
        rows$window_label[[row_index]] <- window_specs$window_label[[window_index]]
        rows$window_size[[row_index]] <- window_specs$window_size[[window_index]]
        rows$actual_years_available[[row_index]] <- actual_years_available
        rows$valid_comparison_count[[row_index]] <- valid_comparison_count
        rows$low_positive_count[[row_index]] <- low_positive_count
        rows$selected_value[[row_index]] <- selected_value
        rows$record_value[[row_index]] <- record_value
        rows$is_tied_record[[row_index]] <- length(tie_indices) > 1L
        rows$tie_count[[row_index]] <- length(tie_indices)
        rows$tie_peer_year[[row_index]] <- tie_peer_year
        rows$next_distinct_year[[row_index]] <- next_distinct_year
        rows$next_distinct_value[[row_index]] <- next_distinct_value
        rows$gap_abs[[row_index]] <- gap_abs
        rows$gap_pct_vs_next_distinct[[row_index]] <- gap_pct
        rows$gap_pct_status[[row_index]] <- gap_pct_status
      }
    }
  }

  if (row_index == 0L) {
    return(tibble::tibble())
  }

  keep <- seq_len(row_index)
  tibble::tibble(
    country = rows$country[keep],
    countryDescription = rows$countryDescription[keep],
    commodity = rows$commodity[keep],
    metric_id = rows$metric_id[keep],
    metric_code = rows$metric_code[keep],
    metric_class = rows$metric_class[keep],
    basis_profile = rows$basis_profile[keep],
    market_year = rows$market_year[keep],
    analysis_month = rows$analysis_month[keep],
    release_year = rows$release_year[keep],
    release_month = rows$release_month[keep],
    release_period = rows$release_period[keep],
    direction = rows$direction[keep],
    window_label = rows$window_label[keep],
    window_size = rows$window_size[keep],
    actual_years_available = rows$actual_years_available[keep],
    valid_comparison_count = rows$valid_comparison_count[keep],
    low_positive_count = rows$low_positive_count[keep],
    selected_value = rows$selected_value[keep],
    record_value = rows$record_value[keep],
    is_tied_record = rows$is_tied_record[keep],
    tie_count = rows$tie_count[keep],
    tie_peer_year = rows$tie_peer_year[keep],
    next_distinct_year = rows$next_distinct_year[keep],
    next_distinct_value = rows$next_distinct_value[keep],
    gap_abs = rows$gap_abs[keep],
    gap_pct_vs_next_distinct = rows$gap_pct_vs_next_distinct[keep],
    gap_pct_status = rows$gap_pct_status[keep],
    record_mode = "as_of"
  )
}

materialize_psd_historical_records <- function(psd_long_data, windows = c(5L, 10L, 20L, NA_integer_), selected_years = NULL) {
  assert_dataset_columns(psd_long_data, psd_required_processed_cols, "psd_historical_records source")

  profile_map <- psd_historical_records_metric_profiles()
  long_profiles <- psd_long_data %>%
    dplyr::filter(.data$normalized_metric_id %in% profile_map$normalized_metric_id) %>%
    dplyr::inner_join(profile_map, by = "normalized_metric_id") %>%
    dplyr::transmute(
      country = trimws(as.character(.data$country)),
      countryDescription = trimws(as.character(.data$countryDescription)),
      commodity = trimws(as.character(.data$commodity)),
      market_year = suppressWarnings(as.integer(.data$market_year)),
      analysis_month = suppressWarnings(as.integer(.data$analysis_month)),
      release_year = suppressWarnings(as.integer(.data$release_year)),
      release_month = suppressWarnings(as.integer(.data$release_month)),
      release_period = trimws(as.character(.data$release_period)),
      metric_id = .data$metric_id,
      metric_code = .data$metric_code,
      metric_class = .data$metric_class,
      basis_profile = .data$basis_profile,
      analysis_value = suppressWarnings(as.numeric(.data$value_canonical))
    ) %>%
    dplyr::filter(
      nzchar(.data$country),
      nzchar(.data$commodity),
      !is.na(.data$market_year),
      !is.na(.data$analysis_value),
      is.finite(.data$analysis_value)
    )

  latest_rows <- reduce_psd_latest_market_year_estimates(
    data = long_profiles,
    group_cols = c("country", "commodity", "metric_code", "basis_profile")
  )

  if (nrow(latest_rows) == 0) {
    return(tibble::tibble())
  }

  series_groups <- split(
    latest_rows,
    interaction(
      latest_rows$country,
      latest_rows$commodity,
      latest_rows$metric_code,
      latest_rows$basis_profile,
      drop = TRUE,
      sep = "\r"
    )
  )

  selected_years <- if (is.null(selected_years)) NULL else unique(suppressWarnings(as.integer(selected_years)))
  selected_years <- selected_years[!is.na(selected_years)]
  out <- dplyr::bind_rows(lapply(
    series_groups,
    build_psd_historical_record_rows_for_series,
    windows = windows,
    selected_years = selected_years
  ))
  if (nrow(out) == 0) {
    return(tibble::tibble())
  }

  out %>%
    dplyr::arrange(
      .data$market_year,
      .data$window_label,
      .data$direction,
      .data$metric_code,
      .data$commodity,
      .data$country
    )
}

compute_last_complete_month_from_weekly <- function(weekly_path = NULL, week_dates = NULL) {
  if (is.null(week_dates)) {
    if (is.null(weekly_path) || !nzchar(weekly_path)) {
      stop("compute_last_complete_month_from_weekly() requires either weekly_path or week_dates.", call. = FALSE)
    }

    assert_required_columns(weekly_path, required_weekly_source_cols, "weekly_data.csv")

    weekly_header_cols <- names(read.csv(weekly_path, nrows = 0, stringsAsFactors = FALSE, check.names = FALSE))
    date_col <- if ("weekEndingDate" %in% weekly_header_cols) {
      "weekEndingDate"
    } else if ("week_ending_date" %in% weekly_header_cols) {
      "week_ending_date"
    } else {
      stop("weekly_data.csv is missing a week ending date column.", call. = FALSE)
    }

    week_dates <- read.csv(weekly_path, stringsAsFactors = FALSE, check.names = FALSE) %>%
      transmute(week_ending_date = as.Date(.data[[date_col]])) %>%
      pull(.data$week_ending_date)
  } else {
    week_dates <- as.Date(week_dates)
  }

  most_recent_report_date <- safe_max_date(week_dates)
  if (is.na(most_recent_report_date)) {
    most_recent_report_date <- Sys.Date()
  }

  last_complete_calendar_month <- lubridate::month(most_recent_report_date) - 1
  last_complete_calendar_year <- lubridate::year(most_recent_report_date)

  if (last_complete_calendar_month == 0) {
    last_complete_calendar_month <- 12
    last_complete_calendar_year <- last_complete_calendar_year - 1
  }

  list(
    most_recent_report_date = most_recent_report_date,
    last_complete_calendar_month = last_complete_calendar_month,
    last_complete_calendar_year = last_complete_calendar_year
  )
}

load_export_sales_monthly_data <- function(monthly_path, country_canonical_map, last_complete_calendar_year, last_complete_calendar_month) {
  assert_required_columns(monthly_path, required_monthly_source_cols, "export_sales_monthly.csv")

  read.csv(monthly_path, stringsAsFactors = FALSE) %>%
    mutate(
      country = trimws(.data$country),
      countryDescription = trimws(.data$countryDescription),
      country_source_code = trimws(as.character(.data$country_source_code)),
      commodity = trimws(.data$commodity),
      analysis_month = .data$month_market_year,
      calendar_month = .data$month,
      calendar_year = ifelse(.data$calendar_month >= 8, .data$market_year, .data$market_year + 1),
      total_commitment = ifelse(.data$total_commitment == 0, NA, .data$total_commitment),
      total_commitment_rough_eq = ifelse(.data$total_commitment_rough_eq == 0, NA, .data$total_commitment_rough_eq)
    ) %>%
    canonicalize_country_dataset("export_sales", country_canonical_map) %>%
    arrange(.data$market_year, .data$analysis_month, .data$commodity, .data$country) %>%
    filter(
      (.data$calendar_year < last_complete_calendar_year) |
        (.data$calendar_year == last_complete_calendar_year & .data$calendar_month <= last_complete_calendar_month)
    )
}

normalize_census_commodity <- function(hs_values, hs_code_values) {
  hs_raw <- trimws(as.character(hs_values))
  hs_code_raw <- trimws(as.character(hs_code_values))
  base_raw <- ifelse(nzchar(hs_raw), hs_raw, hs_code_raw)

  base_upper <- toupper(gsub("\\s+", " ", base_raw))
  is_all_rice <- base_upper %in% c("ALL RICE", "ALL_RICE")

  has_code_prefix <- grepl("^\\([0-9]+\\)\\s*", hs_raw)
  hs_code <- ifelse(has_code_prefix, sub("^\\(([0-9]+)\\).*$", "\\1", hs_raw), "")
  hs_text_only <- ifelse(has_code_prefix, sub("^\\([0-9]+\\)\\s*", "", hs_raw), base_raw)
  hs_text_clean <- stringr::str_to_title(tolower(hs_text_only))

  out <- ifelse(
    has_code_prefix & nzchar(hs_text_clean),
    paste(hs_code, "-", hs_text_clean),
    hs_text_clean
  )

  out <- ifelse(is_all_rice, "All Rice", out)
  ifelse(!nzchar(out) & nzchar(hs_code_raw), hs_code_raw, out)
}

load_census_monthly_data <- function(path, country_canonical_map, trade_flow = c("export", "import")) {
  trade_flow <- match.arg(trade_flow)
  required_columns <- if (trade_flow == "export") required_census_source_cols else required_census_import_source_cols
  dataset_label <- if (trade_flow == "export") "hs_exports.csv" else "hs_imports.csv"

  assert_required_columns(path, required_columns, dataset_label)

  out <- read.csv(path, stringsAsFactors = FALSE, check.names = FALSE) %>%
    mutate(
      country = trimws(as.character(.data$country)),
      countryDescription = trimws(as.character(.data$countryDescription)),
      country_source_code = trimws(as.character(.data$country_source_code)),
      hs_code = trimws(as.character(.data$HS_Code)),
      commodity = normalize_census_commodity(.data$HS, .data$HS_Code),
      market_year = suppressWarnings(as.numeric(.data$market_year)),
      analysis_month = suppressWarnings(as.numeric(.data$analysis_month)),
      monthlyvalue = suppressWarnings(as.numeric(.data$monthlyvalue)),
      monthlyvolume = suppressWarnings(as.numeric(.data$Volume)) / 1000,
      monthlyvolume_rough_eq = suppressWarnings(as.numeric(.data$Rough_Equivalent_Volume)) / 1000,
      ytd_value = suppressWarnings(as.numeric(.data$ytd_value)),
      monthlyvalue_rough_eq = .data$monthlyvalue,
      ytd_value_rough_eq = .data$ytd_value,
      total_commitment = NA_real_,
      total_commitment_rough_eq = NA_real_,
      outstandingSales = NA_real_,
      outstandingSales_rough_eq = NA_real_,
      grossNewSales = NA_real_,
      grossNewSales_rough_eq = NA_real_,
      currentMYNetSales = NA_real_,
      currentMYNetSales_rough_eq = NA_real_,
      nextMYOutstandingSales = NA_real_,
      nextMYOutstandingSales_rough_eq = NA_real_,
      nextMYNetSales = NA_real_,
      nextMYNetSales_rough_eq = NA_real_,
      week_ending_date = as.Date(NA)
    )

  if (trade_flow == "export") {
    out <- out %>%
      mutate(
        monthlyexports = .data$monthlyvolume,
        monthlyexports_rough_eq = .data$monthlyvolume_rough_eq
      )
  } else {
    out <- out %>%
      mutate(
        monthlyimports = .data$monthlyvolume,
        monthlyimports_rough_eq = .data$monthlyvolume_rough_eq,
        monthlyexports = .data$monthlyimports,
        monthlyexports_rough_eq = .data$monthlyimports_rough_eq
      )
  }

  out <- out %>%
    arrange(.data$country, .data$commodity, .data$market_year, .data$analysis_month, .data$MONTHNUM) %>%
    group_by(.data$country, .data$countryDescription, .data$country_source_code, .data$commodity, .data$hs_code, .data$market_year) %>%
    mutate(
      ytd_volume = cumsum(dplyr::coalesce(.data$monthlyvolume, 0)),
      ytd_volume_rough_eq = cumsum(dplyr::coalesce(.data$monthlyvolume_rough_eq, 0)),
      ytd_value = cumsum(dplyr::coalesce(.data$monthlyvalue, 0)),
      ytd_value_rough_eq = .data$ytd_value,
      ytd_exports = cumsum(dplyr::coalesce(.data$monthlyexports, 0)),
      ytd_exports_rough_eq = cumsum(dplyr::coalesce(.data$monthlyexports_rough_eq, 0))
    ) %>%
    ungroup()

  if (trade_flow == "import") {
    out <- out %>%
      mutate(
        ytd_imports = .data$ytd_exports,
        ytd_imports_rough_eq = .data$ytd_exports_rough_eq
      )
  }

  out %>%
    canonicalize_country_dataset("census", country_canonical_map) %>%
    arrange(.data$market_year, .data$analysis_month, .data$commodity, .data$country)
}

load_psd_marketing_year_data <- function(path, metadata_path, country_canonical_map) {
  assert_required_columns(path, required_psd_source_cols, basename(path))

  metadata_required_cols <- c(
    "commodityCode", "countryCode", "marketYear", "calendarYear", "month",
    "releaseYear", "releaseMonth", "release_period", "raw_csv_path", "market_year_window", "extracted_at_utc"
  )
  assert_required_columns(metadata_path, metadata_required_cols, basename(metadata_path))

  raw_psd <- read.csv(path, stringsAsFactors = FALSE, check.names = FALSE) %>%
    mutate(
      commodityCode = as.character(.data$commodityCode),
      countryCode = trimws(as.character(.data$countryCode)),
      marketYear = suppressWarnings(as.integer(.data$marketYear)),
      calendarYear = suppressWarnings(as.integer(.data$calendarYear)),
      month = suppressWarnings(as.integer(.data$month)),
      attributeId = suppressWarnings(as.integer(.data$attributeId)),
      unitId = suppressWarnings(as.integer(.data$unitId)),
      value = suppressWarnings(as.numeric(.data$value)),
        releaseYear = if ("releaseYear" %in% names(.)) {
          suppressWarnings(as.integer(.data$releaseYear))
        } else {
          NA_integer_
        },
        releaseMonth = if ("releaseMonth" %in% names(.)) {
          suppressWarnings(as.integer(.data$releaseMonth))
        } else {
          NA_integer_
        },
        release_period = if ("release_period" %in% names(.)) {
          trimws(as.character(.data$release_period))
        } else {
          NA_character_
        },
        market_year_window = if ("market_year_window" %in% names(.)) {
          trimws(as.character(.data$market_year_window))
        } else {
          NA_character_
        },
        extracted_at_utc = if ("extracted_at_utc" %in% names(.)) {
          trimws(as.character(.data$extracted_at_utc))
        } else {
          NA_character_
        },
          world_rollup_mode = if ("world_rollup_mode" %in% names(.)) {
            trimws(as.character(.data$world_rollup_mode))
          } else {
            NA_character_
          },
          world_rollup_release_periods = if ("world_rollup_release_periods" %in% names(.)) {
            trimws(as.character(.data$world_rollup_release_periods))
          } else {
            NA_character_
          },
          world_country_count = if ("world_country_count" %in% names(.)) {
            suppressWarnings(as.integer(.data$world_country_count))
          } else {
            NA_integer_
          },
          world_is_mixed_release = if ("world_is_mixed_release" %in% names(.)) {
            as.logical(.data$world_is_mixed_release)
          } else {
            NA
          },
          world_value_conflict_flag = if ("world_value_conflict_flag" %in% names(.)) {
            as.logical(.data$world_value_conflict_flag)
          } else {
            NA
          },
          world_native_value_reference = if ("world_native_value_reference" %in% names(.)) {
            suppressWarnings(as.numeric(.data$world_native_value_reference))
          } else {
            NA_real_
          },
          world_derived_value_reference = if ("world_derived_value_reference" %in% names(.)) {
            suppressWarnings(as.numeric(.data$world_derived_value_reference))
          } else {
            NA_real_
          },
        country_name_endpoint = if ("country_name_endpoint" %in% names(.)) {
          trimws(as.character(.data$country_name_endpoint))
        } else {
          trimws(as.character(.data$countryName))
        },
        country_description_endpoint_raw = if ("country_description_endpoint_raw" %in% names(.)) {
          trimws(as.character(.data$country_description_endpoint_raw))
        } else if ("countryDescription" %in% names(.)) {
          trimws(as.character(.data$countryDescription))
        } else {
          NA_character_
        },
        country_name_lookup = if ("countryName_lookup" %in% names(.)) {
          trimws(as.character(.data$countryName_lookup))
        } else {
          NA_character_
        },
        country_description_authoritative = if ("country_description_authoritative" %in% names(.)) {
          trimws(as.character(.data$country_description_authoritative))
        } else if ("countryDescription" %in% names(.)) {
          trimws(as.character(.data$countryDescription))
        } else {
          NA_character_
        },
      psd_endpoint_scope = if ("psd_endpoint_scope" %in% names(.)) {
        dplyr::coalesce(trimws(as.character(.data$psd_endpoint_scope)), "all_countries")
      } else {
        "all_countries"
      }
    )

  psd_metadata <- read.csv(metadata_path, stringsAsFactors = FALSE, check.names = FALSE) %>%
    mutate(
      commodityCode = as.character(.data$commodityCode),
      countryCode = trimws(as.character(.data$countryCode)),
      marketYear = suppressWarnings(as.integer(.data$marketYear)),
      calendarYear = suppressWarnings(as.integer(.data$calendarYear)),
      month = suppressWarnings(as.integer(.data$month)),
      releaseYear = suppressWarnings(as.integer(.data$releaseYear)),
      releaseMonth = suppressWarnings(as.integer(.data$releaseMonth))
    )

  crosswalk <- psd_phase1_metric_crosswalk()

  out <- raw_psd %>%
    left_join(crosswalk, by = c("attributeId", "attributeName")) %>%
    left_join(
      psd_metadata %>%
        distinct(
          .data$commodityCode, .data$countryCode, .data$marketYear, .data$calendarYear, .data$month,
          releaseYear_metadata = .data$releaseYear,
          releaseMonth_metadata = .data$releaseMonth,
          release_period_metadata = .data$release_period,
          market_year_window_metadata = .data$market_year_window,
          extracted_at_utc_metadata = .data$extracted_at_utc
        ) %>%
        distinct(),
      by = c("commodityCode", "countryCode", "marketYear", "calendarYear", "month")
    ) %>%
    mutate(
      releaseYear = dplyr::coalesce(.data$releaseYear, .data$releaseYear_metadata),
      releaseMonth = dplyr::coalesce(.data$releaseMonth, .data$releaseMonth_metadata),
      release_period = dplyr::coalesce(.data$release_period, .data$release_period_metadata),
      market_year_window = dplyr::coalesce(.data$market_year_window, .data$market_year_window_metadata),
      extracted_at_utc = dplyr::coalesce(.data$extracted_at_utc, .data$extracted_at_utc_metadata)
    )

  missing_crosswalk <- out %>%
    filter(is.na(.data$phase1_status)) %>%
    distinct(attributeId, attributeName)

  if (nrow(missing_crosswalk) > 0) {
    stop(
      paste0(
        "PSD phase-1 crosswalk is missing attributes: ",
        paste(sprintf("%s (%s)", missing_crosswalk$attributeName, missing_crosswalk$attributeId), collapse = ", "),
        "."
      ),
      call. = FALSE
    )
  }

  native_out <- out %>%
    transmute(
      source = "psd",
      frequency = "monthly",
      commodity = psd_app_commodity_label(),
      commodity_group = psd_app_commodity_group(),
      country = .data$countryCode,
      countryDescription = trimws(as.character(.data$countryDescription)),
      country_source_code = .data$countryCode,
      country_name_endpoint = .data$country_name_endpoint,
      country_description_endpoint_raw = .data$country_description_endpoint_raw,
      country_name_lookup = .data$country_name_lookup,
      country_description_authoritative = .data$country_description_authoritative,
      market_year = .data$marketYear,
      analysis_month = psd_market_year_month(.data$month),
      calendar_year = .data$calendarYear,
      calendar_month = .data$month,
      release_year = .data$releaseYear,
      release_month = .data$releaseMonth,
      release_period = .data$release_period,
      commodity_code = .data$commodityCode,
      commodity_name = .data$commodityName,
      region_code = trimws(as.character(.data$regionCode)),
      region_name = trimws(as.character(.data$regionName)),
      genc_code = trimws(as.character(.data$gencCode)),
      attribute_id = .data$attributeId,
      attribute_name = .data$attributeName,
      unit_id = .data$unitId,
      unit_name_raw = trimws(as.character(.data$unitDescription)),
      phase1_status = .data$phase1_status,
      normalized_metric_id = .data$normalized_metric_id,
      canonical_unit = .data$canonical_unit,
      unit_handling_notes = .data$unit_handling_notes,
      value_raw = .data$value,
      value_canonical = .data$value,
      release_row_key = .data$release_row_key,
      market_year_window = .data$market_year_window,
      extracted_at_utc = .data$extracted_at_utc,
      value_provenance = "native_psd",
      provenance_note = NA_character_,
      world_source = dplyr::case_when(
        .data$countryCode == psd_native_world_country_code() & .data$psd_endpoint_scope == "world" ~ "native_world_endpoint",
        .data$countryCode == psd_native_world_country_code() & .data$psd_endpoint_scope == "derived_world_asof" ~ "derived_world_asof",
        TRUE ~ NA_character_
      ),
      construction_components = NA_character_,
      psd_endpoint_scope = dplyr::coalesce(.data$psd_endpoint_scope, "all_countries"),
      world_rollup_mode = .data$world_rollup_mode,
      world_rollup_release_periods = .data$world_rollup_release_periods,
      world_country_count = .data$world_country_count,
      world_is_mixed_release = .data$world_is_mixed_release,
      world_value_conflict_flag = .data$world_value_conflict_flag,
      world_native_value_reference = .data$world_native_value_reference,
      world_derived_value_reference = .data$world_derived_value_reference
    ) %>%
    mutate(
      country = ifelse(.data$country == psd_native_world_country_code(), psd_world_country_code(), .data$country),
      countryDescription = ifelse(.data$country == psd_world_country_code(), "World", .data$countryDescription),
      country_source_code = ifelse(.data$country == psd_world_country_code(), psd_world_country_code(), .data$country_source_code),
      country_description_authoritative = ifelse(.data$country == psd_world_country_code(), "World", .data$country_description_authoritative),
      country_legacy_code = ifelse(.data$country == psd_world_country_code(), psd_world_country_code(), .data$country),
      countryDescription_legacy = ifelse(.data$country == psd_world_country_code(), "World", .data$countryDescription)
    )

  native_world_rows <- native_out %>% filter(.data$country == psd_world_country_code(), .data$world_source == "native_world_endpoint")
  derived_world_rows <- native_out %>% filter(.data$country == psd_world_country_code(), .data$world_source == "derived_world_asof")
  country_rows <- native_out %>%
    filter(.data$country != psd_world_country_code()) %>%
    canonicalize_country_dataset("psd", country_canonical_map)

  missing_world_groups <- country_rows %>%
    distinct(market_year, analysis_month, calendar_year, calendar_month, release_period) %>%
    anti_join(
      native_world_rows %>% distinct(market_year, analysis_month, calendar_year, calendar_month, release_period),
      by = c("market_year", "analysis_month", "calendar_year", "calendar_month", "release_period")
    )

  # Short-run: exclude synthetic PSD world rollups from the processed artifact,
  # but keep the fallback block nearby so it can be restored easily.
  # synthetic_world_rows <- if (nrow(missing_world_groups) > 0) {
  #   psd_build_world_fallback_rows(country_rows)
  # } else {
  #   tibble()
  # }

  bind_rows(
    country_rows,
    native_world_rows,
    derived_world_rows
    # , synthetic_world_rows
  ) %>%
    arrange(.data$market_year, .data$analysis_month, .data$country, .data$attribute_id)
}

load_psd_monthly_data <- function(path, metadata_path, country_canonical_map) {
  load_psd_marketing_year_data(
    path = path,
    metadata_path = metadata_path,
    country_canonical_map = country_canonical_map
  )
}

normalize_wasde_commodity <- function(values) {
  cleaned <- trimws(as.character(values))
  normalized <- toupper(cleaned)

  out <- dplyr::case_when(
    normalized %in% c("RICE", "ALL RICE") ~ "All Rice",
    normalized %in% c("LONG", "LONG GRAIN", "RICE, LONG GRAIN", "LONG GRAIN RICE", "RICE LONG GRAIN") ~ "Long Grain",
    normalized %in% c(
      "MED & SHORT", "MEDIUM & SHORT", "MEDIUM SHORT", "MEDIUM AND SHORT GRAIN",
      "RICE, MEDIUM & SHORT GRAIN", "RICE MEDIUM & SHORT GRAIN",
      "MEDIUM/SHORT GRAIN", "MEDIUM/SHORT GRAIN RICE",
      "RICE, MEDIUM/SHORT GRAIN", "RICE MEDIUM/SHORT GRAIN",
      "MEDIUM AND SHORT GRAIN RICE", "RICE, MEDIUM AND SHORT GRAIN", "RICE MEDIUM AND SHORT GRAIN"
    ) ~ "Medium and Short Grain",
    TRUE ~ stringr::str_to_title(tolower(cleaned))
  )

  out[!nzchar(trimws(out))] <- "All Rice"
  out
}

normalize_wasde_metric_id <- function(values) {
  cleaned <- trimws(as.character(values))
  cleaned <- tolower(cleaned)
  cleaned <- gsub("&", " and ", cleaned, fixed = TRUE)
  cleaned <- gsub("[^a-z0-9]+", "_", cleaned)
  cleaned <- gsub("_+", "_", cleaned)
  cleaned <- gsub("^_|_$", "", cleaned)
  cleaned[!nzchar(cleaned)] <- "unknown_metric"
  cleaned
}

build_wasde_exports_rough_rows <- function(raw_wasde) {
  required_cols <- c(
    "COMMODITY_DESC", "COMMODITY_DESC2",
    "UNIT_DESC", "ATTRIBUTE_DESC", "GEOGRAPHY_DESC",
    "TIMEPERIOD_ID", "TIMEPERIOD_DESC", "TIMEPERIOD_SHORT", "TIMEPERIOD_LONG",
    "DATE_ESTIMATE_MADE", "LAST_UPDATED",
    "YEAR_ID", "AMOUNT"
  )

  if (!is.data.frame(raw_wasde) || nrow(raw_wasde) == 0 || !all(required_cols %in% names(raw_wasde))) {
    return(tibble::tibble())
  }

  first_non_empty_text <- function(values) {
    cleaned <- trimws(as.character(values))
    cleaned <- cleaned[!is.na(cleaned) & nzchar(cleaned)]
    if (length(cleaned) == 0) {
      return(NA_character_)
    }
    cleaned[[1]]
  }

  first_finite_numeric <- function(values) {
    cleaned <- suppressWarnings(as.numeric(values))
    cleaned <- cleaned[is.finite(cleaned)]
    if (length(cleaned) == 0) {
      return(NA_real_)
    }
    cleaned[[1]]
  }

  base_rows <- raw_wasde %>%
    transmute(
      COMMODITY_DESC = trimws(as.character(.data$COMMODITY_DESC)),
      COMMODITY_DESC2 = trimws(as.character(.data$COMMODITY_DESC2)),
      UNIT_DESC = trimws(as.character(.data$UNIT_DESC)),
      ATTRIBUTE_DESC = trimws(as.character(.data$ATTRIBUTE_DESC)),
      GEOGRAPHY_DESC = trimws(as.character(.data$GEOGRAPHY_DESC)),
      TIMEPERIOD_ID = suppressWarnings(as.integer(.data$TIMEPERIOD_ID)),
      TIMEPERIOD_DESC = trimws(as.character(.data$TIMEPERIOD_DESC)),
      TIMEPERIOD_SHORT = trimws(as.character(.data$TIMEPERIOD_SHORT)),
      TIMEPERIOD_LONG = trimws(as.character(.data$TIMEPERIOD_LONG)),
      DATE_ESTIMATE_MADE = trimws(as.character(.data$DATE_ESTIMATE_MADE)),
      LAST_UPDATED = trimws(as.character(.data$LAST_UPDATED)),
      YEAR_ID = suppressWarnings(as.integer(.data$YEAR_ID)),
      AMOUNT = suppressWarnings(as.numeric(.data$AMOUNT))
    ) %>%
    filter(
      toupper(.data$COMMODITY_DESC) %in% c("RICE", "ALL RICE"),
      .data$ATTRIBUTE_DESC %in% c("Qty of Exports", "Exports, milled production"),
      toupper(.data$UNIT_DESC) == "MILLION HUNDREDWEIGHT"
    )

  if (nrow(base_rows) == 0) {
    return(tibble::tibble())
  }

  grouped_rows <- base_rows %>%
    group_by(
      .data$GEOGRAPHY_DESC,
      .data$YEAR_ID,
      .data$TIMEPERIOD_ID,
      .data$TIMEPERIOD_DESC,
      .data$TIMEPERIOD_SHORT,
      .data$TIMEPERIOD_LONG
    ) %>%
    summarise(
      qty_of_exports_amount = first_finite_numeric(.data$AMOUNT[.data$ATTRIBUTE_DESC == "Qty of Exports"]),
      exports_milled_amount = first_finite_numeric(.data$AMOUNT[.data$ATTRIBUTE_DESC == "Exports, milled production"]),
      DATE_ESTIMATE_MADE = first_non_empty_text(.data$DATE_ESTIMATE_MADE),
      LAST_UPDATED = first_non_empty_text(.data$LAST_UPDATED),
      .groups = "drop"
    ) %>%
    filter(
      is.finite(.data$qty_of_exports_amount),
      is.finite(.data$exports_milled_amount)
    ) %>%
    transmute(
      COMMODITY_DESC = "RICE",
      COMMODITY_DESC2 = "Rice",
      UNIT_DESC = "Million Hundredweight",
      ATTRIBUTE_DESC = "Exports, rough production",
      GEOGRAPHY_DESC = .data$GEOGRAPHY_DESC,
      TIMEPERIOD_ID = .data$TIMEPERIOD_ID,
      TIMEPERIOD_DESC = .data$TIMEPERIOD_DESC,
      TIMEPERIOD_SHORT = .data$TIMEPERIOD_SHORT,
      TIMEPERIOD_LONG = .data$TIMEPERIOD_LONG,
      DATE_ESTIMATE_MADE = .data$DATE_ESTIMATE_MADE,
      LAST_UPDATED = .data$LAST_UPDATED,
      YEAR_ID = .data$YEAR_ID,
      AMOUNT = .data$qty_of_exports_amount - .data$exports_milled_amount
    )

  existing_derived_keys <- raw_wasde %>%
    transmute(
      GEOGRAPHY_DESC = trimws(as.character(.data$GEOGRAPHY_DESC)),
      YEAR_ID = suppressWarnings(as.integer(.data$YEAR_ID)),
      TIMEPERIOD_ID = suppressWarnings(as.integer(.data$TIMEPERIOD_ID)),
      TIMEPERIOD_DESC = trimws(as.character(.data$TIMEPERIOD_DESC)),
      TIMEPERIOD_SHORT = trimws(as.character(.data$TIMEPERIOD_SHORT)),
      TIMEPERIOD_LONG = trimws(as.character(.data$TIMEPERIOD_LONG)),
      ATTRIBUTE_DESC = trimws(as.character(.data$ATTRIBUTE_DESC))
    ) %>%
    filter(.data$ATTRIBUTE_DESC == "Exports, rough production") %>%
    select(-"ATTRIBUTE_DESC") %>%
    distinct()

  out <- grouped_rows %>%
    anti_join(
      existing_derived_keys,
      by = c(
        "GEOGRAPHY_DESC",
        "YEAR_ID",
        "TIMEPERIOD_ID",
        "TIMEPERIOD_DESC",
        "TIMEPERIOD_SHORT",
        "TIMEPERIOD_LONG"
      )
    ) %>%
    select(all_of(required_cols))

  out
}

build_wasde_total_domestic_and_residual_rows <- function(raw_wasde) {
  required_cols <- c(
    "COMMODITY_DESC", "COMMODITY_DESC2",
    "UNIT_DESC", "ATTRIBUTE_DESC", "GEOGRAPHY_DESC",
    "TIMEPERIOD_ID", "TIMEPERIOD_DESC", "TIMEPERIOD_SHORT", "TIMEPERIOD_LONG",
    "DATE_ESTIMATE_MADE", "LAST_UPDATED",
    "YEAR_ID", "AMOUNT"
  )

  if (!is.data.frame(raw_wasde) || nrow(raw_wasde) == 0 || !all(required_cols %in% names(raw_wasde))) {
    return(tibble::tibble())
  }

  first_non_empty_text <- function(values) {
    cleaned <- trimws(as.character(values))
    cleaned <- cleaned[!is.na(cleaned) & nzchar(cleaned)]
    if (length(cleaned) == 0) {
      return(NA_character_)
    }
    cleaned[[1]]
  }

  first_finite_numeric <- function(values) {
    cleaned <- suppressWarnings(as.numeric(values))
    cleaned <- cleaned[is.finite(cleaned)]
    if (length(cleaned) == 0) {
      return(NA_real_)
    }
    cleaned[[1]]
  }

  base_rows <- raw_wasde %>%
    transmute(
      COMMODITY_DESC = trimws(as.character(.data$COMMODITY_DESC)),
      COMMODITY_DESC2 = trimws(as.character(.data$COMMODITY_DESC2)),
      UNIT_DESC = trimws(as.character(.data$UNIT_DESC)),
      ATTRIBUTE_DESC = trimws(as.character(.data$ATTRIBUTE_DESC)),
      GEOGRAPHY_DESC = trimws(as.character(.data$GEOGRAPHY_DESC)),
      TIMEPERIOD_ID = suppressWarnings(as.integer(.data$TIMEPERIOD_ID)),
      TIMEPERIOD_DESC = trimws(as.character(.data$TIMEPERIOD_DESC)),
      TIMEPERIOD_SHORT = trimws(as.character(.data$TIMEPERIOD_SHORT)),
      TIMEPERIOD_LONG = trimws(as.character(.data$TIMEPERIOD_LONG)),
      DATE_ESTIMATE_MADE = trimws(as.character(.data$DATE_ESTIMATE_MADE)),
      LAST_UPDATED = trimws(as.character(.data$LAST_UPDATED)),
      YEAR_ID = suppressWarnings(as.integer(.data$YEAR_ID)),
      AMOUNT = suppressWarnings(as.numeric(.data$AMOUNT))
    ) %>%
    filter(
      toupper(.data$COMMODITY_DESC) %in% c("RICE", "ALL RICE"),
      .data$ATTRIBUTE_DESC %in% c("Total domestic", "Residual"),
      toupper(.data$UNIT_DESC) == "MILLION HUNDREDWEIGHT"
    )

  if (nrow(base_rows) == 0) {
    return(tibble::tibble())
  }

  grouped_rows <- base_rows %>%
    group_by(
      .data$GEOGRAPHY_DESC,
      .data$YEAR_ID,
      .data$TIMEPERIOD_ID,
      .data$TIMEPERIOD_DESC,
      .data$TIMEPERIOD_SHORT,
      .data$TIMEPERIOD_LONG
    ) %>%
    summarise(
      total_domestic_amount = first_finite_numeric(.data$AMOUNT[.data$ATTRIBUTE_DESC == "Total domestic"]),
      residual_amount = first_finite_numeric(.data$AMOUNT[.data$ATTRIBUTE_DESC == "Residual"]),
      DATE_ESTIMATE_MADE = first_non_empty_text(.data$DATE_ESTIMATE_MADE),
      LAST_UPDATED = first_non_empty_text(.data$LAST_UPDATED),
      .groups = "drop"
    ) %>%
    filter(
      is.finite(.data$total_domestic_amount),
      is.finite(.data$residual_amount)
    ) %>%
    transmute(
      COMMODITY_DESC = "RICE",
      COMMODITY_DESC2 = "Rice",
      UNIT_DESC = "Million Hundredweight",
      ATTRIBUTE_DESC = "Total Domestic and Residual",
      GEOGRAPHY_DESC = .data$GEOGRAPHY_DESC,
      TIMEPERIOD_ID = .data$TIMEPERIOD_ID,
      TIMEPERIOD_DESC = .data$TIMEPERIOD_DESC,
      TIMEPERIOD_SHORT = .data$TIMEPERIOD_SHORT,
      TIMEPERIOD_LONG = .data$TIMEPERIOD_LONG,
      DATE_ESTIMATE_MADE = .data$DATE_ESTIMATE_MADE,
      LAST_UPDATED = .data$LAST_UPDATED,
      YEAR_ID = .data$YEAR_ID,
      AMOUNT = .data$total_domestic_amount + .data$residual_amount
    )

  existing_derived_keys <- raw_wasde %>%
    transmute(
      GEOGRAPHY_DESC = trimws(as.character(.data$GEOGRAPHY_DESC)),
      YEAR_ID = suppressWarnings(as.integer(.data$YEAR_ID)),
      TIMEPERIOD_ID = suppressWarnings(as.integer(.data$TIMEPERIOD_ID)),
      TIMEPERIOD_DESC = trimws(as.character(.data$TIMEPERIOD_DESC)),
      TIMEPERIOD_SHORT = trimws(as.character(.data$TIMEPERIOD_SHORT)),
      TIMEPERIOD_LONG = trimws(as.character(.data$TIMEPERIOD_LONG)),
      ATTRIBUTE_DESC = trimws(as.character(.data$ATTRIBUTE_DESC))
    ) %>%
    filter(.data$ATTRIBUTE_DESC == "Total Domestic and Residual") %>%
    select(-"ATTRIBUTE_DESC") %>%
    distinct()

  out <- grouped_rows %>%
    anti_join(
      existing_derived_keys,
      by = c(
        "GEOGRAPHY_DESC",
        "YEAR_ID",
        "TIMEPERIOD_ID",
        "TIMEPERIOD_DESC",
        "TIMEPERIOD_SHORT",
        "TIMEPERIOD_LONG"
      )
    ) %>%
    select(all_of(required_cols))

  out
}

build_waob_total_domestic_and_residual_rows <- function(raw_waob) {
  if (!is.data.frame(raw_waob) || nrow(raw_waob) == 0 || !all(required_waob_wasde_source_cols %in% names(raw_waob))) {
    return(tibble::tibble())
  }

  first_non_empty_text <- function(values) {
    cleaned <- trimws(as.character(values))
    cleaned <- cleaned[!is.na(cleaned) & nzchar(cleaned)]
    if (length(cleaned) == 0) {
      return(NA_character_)
    }
    cleaned[[1]]
  }

  first_finite_numeric <- function(values) {
    cleaned <- suppressWarnings(as.numeric(values))
    cleaned <- cleaned[is.finite(cleaned)]
    if (length(cleaned) == 0) {
      return(NA_real_)
    }
    cleaned[[1]]
  }

  target_metric_ids <- c("domestic_consumption", "food_industrial_and_residual")
  metric_tokens <- normalize_waob_wasde_metric_id(raw_waob$attribute_description)
  scope_idx <- metric_tokens %in% target_metric_ids
  scoped_rows <- raw_waob[scope_idx, , drop = FALSE]
  scoped_metric_tokens <- metric_tokens[scope_idx]

  if (nrow(scoped_rows) == 0) {
    return(tibble::tibble())
  }

  make_key <- function(df) {
    paste(
      trimws(as.character(df$cn_code)),
      trimws(as.character(df$cm_code)),
      suppressWarnings(as.integer(df$market_year)),
      suppressWarnings(as.integer(df$release_year)),
      suppressWarnings(as.integer(df$release_month)),
      trimws(as.character(df$release_period)),
      suppressWarnings(as.integer(df$wb_unit_id)),
      suppressWarnings(as.integer(df$forecast_type)),
      suppressWarnings(as.integer(df$wb_forecast_type)),
      sep = "|"
    )
  }

  scoped_rows$metric_token <- scoped_metric_tokens
  scoped_rows$key <- make_key(scoped_rows)
  split_scoped_rows <- split(scoped_rows, scoped_rows$key, drop = TRUE)

  derived_rows_list <- lapply(split_scoped_rows, function(chunk) {
    token <- as.character(chunk$metric_token)
    domestic_value <- first_finite_numeric(chunk$wb_value[token == "domestic_consumption"])
    residual_value <- first_finite_numeric(chunk$wb_value[token == "food_industrial_and_residual"])

    if (!is.finite(domestic_value) || !is.finite(residual_value)) {
      return(NULL)
    }

    base_row <- chunk[1L, required_waob_wasde_source_cols, drop = FALSE]
    component_ids <- unique(suppressWarnings(as.integer(chunk$wb_id)))
    component_ids <- component_ids[is.finite(component_ids)]
    min_component_wb_id <- if (length(component_ids) > 0) min(component_ids) else NA_integer_
    synthetic_seed <- if (is.finite(min_component_wb_id)) as.integer(min_component_wb_id) else as.integer(1L)
    synthetic_wb_id <- as.integer(-1L * (2000000000L - synthetic_seed))
    component_note <- if (length(component_ids) > 0) paste(sort(component_ids), collapse = "|") else ""

    release_year <- suppressWarnings(as.integer(base_row$release_year[[1L]]))
    release_month <- suppressWarnings(as.integer(base_row$release_month[[1L]]))
    release_period <- trimws(as.character(base_row$release_period[[1L]]))
    if (is.na(release_period)) {
      release_period <- ""
    }
    if (!nzchar(release_period) && is.finite(release_year) && is.finite(release_month)) {
      release_period <- sprintf("%04d-%02d", release_year, release_month)
    }

    base_row$wb_id <- synthetic_wb_id
    base_row$attribute_id <- NA_integer_
    base_row$attribute_description <- "Total Domestic and Residual"
    base_row$wb_value <- domestic_value + residual_value
    base_row$cm_value <- NA_real_
    base_row$psd_value <- NA_real_
    base_row$calendar_year <- dplyr::coalesce(
      suppressWarnings(as.integer(base_row$calendar_year)),
      suppressWarnings(as.integer(base_row$release_year)),
      suppressWarnings(as.integer(base_row$market_year))
    )
    base_row$forecast_month <- dplyr::coalesce(
      suppressWarnings(as.integer(base_row$forecast_month)),
      suppressWarnings(as.integer(base_row$release_month))
    )
    base_row$last_update <- first_non_empty_text(chunk$last_update)
    base_row$psd_last_update <- first_non_empty_text(chunk$psd_last_update)
    base_row$update_source <- dplyr::coalesce(first_non_empty_text(chunk$update_source), "derived")
    base_row$update_userid <- dplyr::coalesce(first_non_empty_text(chunk$update_userid), "derived_total_domestic_and_residual")
    if (nzchar(component_note)) {
      base_row$update_userid <- paste0(base_row$update_userid, "|components:", component_note)
    }
    base_row$release_period <- release_period
    base_row
  })

  derived_rows <- do.call(rbind, derived_rows_list)
  if (is.null(derived_rows) || nrow(derived_rows) == 0) {
    return(tibble::tibble())
  }

  existing_mask <- metric_tokens == "total_domestic_and_residual"
  existing_keys <- if (any(existing_mask, na.rm = TRUE)) {
    make_key(raw_waob[existing_mask, , drop = FALSE])
  } else {
    character(0)
  }

  derived_keys <- make_key(derived_rows)
  derived_rows <- derived_rows[!(derived_keys %in% existing_keys), , drop = FALSE]

  if (nrow(derived_rows) == 0) {
    return(tibble::tibble())
  }

  tibble::as_tibble(derived_rows[, required_waob_wasde_source_cols, drop = FALSE])
}

wasde_month_name_to_int <- function(values) {
  cleaned <- tolower(trimws(as.character(values)))
  cleaned[!nzchar(cleaned)] <- NA_character_

  month_map <- c(
    january = 1L, jan = 1L,
    february = 2L, feb = 2L,
    march = 3L, mar = 3L,
    april = 4L, apr = 4L,
    may = 5L,
    june = 6L, jun = 6L,
    july = 7L, jul = 7L,
    august = 8L, aug = 8L,
    september = 9L, sep = 9L, sept = 9L,
    october = 10L, oct = 10L,
    november = 11L, nov = 11L,
    december = 12L, dec = 12L
  )

  out <- rep(NA_integer_, length(cleaned))
  for (name in names(month_map)) {
    out[is.na(out) & grepl(paste0("\\b", name, "\\b"), cleaned, perl = TRUE)] <- month_map[[name]]
  }

  suppressWarnings(as.integer(out))
}

resolve_wasde_report_month <- function(timeperiod_long, timeperiod_desc, timeperiod_short) {
  month_long <- wasde_month_name_to_int(timeperiod_long)
  month_desc <- wasde_month_name_to_int(timeperiod_desc)
  month_short <- wasde_month_name_to_int(timeperiod_short)

  dplyr::coalesce(month_long, month_desc, month_short)
}

resolve_wasde_report_month_default <- function(month_values) {
  values <- suppressWarnings(as.integer(month_values))
  values <- values[!is.na(values) & values >= 1L & values <= 12L]
  if (length(values) == 0) {
    return(NA_integer_)
  }

  freq <- sort(table(values), decreasing = TRUE)
  suppressWarnings(as.integer(names(freq)[[1]]))
}

classify_waob_wasde_revision_unit <- function(unit_desc) {
  token <- toupper(trimws(as.character(unit_desc)))
  token <- gsub("[^A-Z0-9]+", "_", token)
  token <- gsub("_+", "_", token)
  token <- gsub("^_|_$", "", token)
  token <- gsub("DOLLARS", "DOLLAR", token, fixed = TRUE)

  out <- rep("unknown", length(token))
  out[grepl("LBS_AC", token, fixed = TRUE)] <- "pounds_per_acre"
  out[
    out == "unknown" &
      (grepl("MILLION_ACRES", token, fixed = TRUE) | grepl("MIL_AC", token, fixed = TRUE))
  ] <- "million_acres"
  out[
    out == "unknown" &
      (grepl("MILLION_HUNDREDWEIGHT", token, fixed = TRUE) | grepl("MIL_CWT", token, fixed = TRUE) | grepl("MILLION_CWT", token, fixed = TRUE))
  ] <- "million_hundredweight"
  out[
    out == "unknown" &
      (grepl("MILLION_DOLLARS", token, fixed = TRUE) | (grepl("MIL_", token, fixed = TRUE) & grepl("DOLLAR", token, fixed = TRUE)))
  ] <- "million_dollars"
  out[
    out == "unknown" &
      (grepl("DOLLAR_PER_HUNDREDWEIGHT", token, fixed = TRUE) | (grepl("CWT", token, fixed = TRUE) & grepl("DOLLAR", token, fixed = TRUE)))
  ] <- "dollars_per_hundredweight"
  out[
    out == "unknown" &
      (grepl("DOLLAR_PER_TON", token, fixed = TRUE) | grepl("DOLLAR_PER_METRIC_TON", token, fixed = TRUE) | (grepl("MT", token, fixed = TRUE) & grepl("DOLLAR", token, fixed = TRUE)))
  ] <- "dollars_per_short_ton"
  out[
    out == "unknown" &
      (grepl("PERCENT", token, fixed = TRUE) | grepl("PCT", token, fixed = TRUE))
  ] <- "percent"
  out[
    out == "unknown" &
      (grepl("RATIO", token, fixed = TRUE) | grepl("MILLING_RATE", token, fixed = TRUE))
  ] <- "percent"

  out
}

normalize_wasde_revision_country_key <- function(values) {
  cleaned <- toupper(trimws(as.character(values)))
  cleaned <- gsub("[^A-Z0-9]+", "", cleaned)
  cleaned[!nzchar(cleaned)] <- NA_character_
  cleaned
}

waob_wasde_metric_alias_map <- function() {
  list(
    acreage_planted = c("area_planted"),
    average_price = c("season_avg_thai_100b_export", "mid_point_of_price_range", "calif_mid_point_of_price_range", "other_mid_point_of_price_range"),
    beginning_stocks = c("beginning_stocks"),
    commodity_credit_corporation_inventory = c("ccc_stocks"),
    contract_payments = c("counter_cyclical_payment_rate"),
    deficiency_payments = c("deficiency_payments"),
    denatured_for_fuel = c("food_industrial_and_residual"),
    ending_stocks = c("ending_stocks"),
    exports_pl_480 = c("non_commercial_exports"),
    exports_milled_production = c("milled_rough_equiv_exports", "rough_exports", "exports"),
    exports_rough_production = c("rough_exports", "exports", "milled_rough_equiv_exports"),
    farmer_owned_reserve = c("ending_stocks", "ending_stocks_of_brokens"),
    food_use = c("food_use"),
    harvested_acres = c("area_harvested"),
    imports = c("imports", "ty_imports"),
    land_diversion_payment_rate = c("counter_cyclical_payment_rate"),
    loan_rate = c("loan_rate"),
    market_value_of_production = c("market_value_of_production"),
    milling_rate = c("milling_rate_9999"),
    production = c("production", "rough_production"),
    projected_amount_of_free_stock_carryout_in_the_special_producer_stroage_loan_program = c("ending_stocks"),
    qty_of_exports = c("exports"),
    qty_of_seed_used = c("seed_use"),
    residual = c("food_industrial_and_residual"),
    stocks_to_use_ratio = c("stocks_to_use"),
    target_price = c("target_price"),
    total_domestic = c("domestic_consumption"),
    total_supply = c("total_supply"),
    total_use = c("total_use"),
    yield = c("yield")
  )
}

waob_wasde_unit_alias_map <- function() {
  list(
    pounds_per_acre = c("pounds_per_acre"),
    dollars_per_bushel = c("dollars_per_hundredweight", "dollars_per_short_ton"),
    dollars_per_hundredweight = c("dollars_per_hundredweight"),
    dollars_per_short_ton = c("dollars_per_short_ton"),
    million_acres = c("million_acres"),
    million_bushels = c("million_hundredweight"),
    million_dollars = c("million_dollars"),
    million_hundredweight = c("million_hundredweight"),
    percent = c("percent")
  )
}

waob_wasde_metric_candidates <- function(metric_id) {
  metric_value <- trimws(as.character(metric_id))
  if (is.na(metric_value)) metric_value <- ""
  if (!nzchar(metric_value)) {
    return(character(0))
  }

  alias_map <- waob_wasde_metric_alias_map()
  aliases <- alias_map[[metric_value]]
  if (is.null(aliases)) aliases <- character(0)
  unique(c(metric_value, aliases))
}

waob_wasde_unit_candidates <- function(unit_class) {
  class_value <- trimws(as.character(unit_class))
  if (is.na(class_value)) class_value <- ""
  if (!nzchar(class_value)) {
    return(character(0))
  }

  alias_map <- waob_wasde_unit_alias_map()
  aliases <- alias_map[[class_value]]
  if (is.null(aliases) || length(aliases) == 0) {
    return(class_value)
  }

  unique(c(class_value, aliases))
}

waob_wasde_commodity_candidates <- function(commodity_value) {
  commodity_clean <- trimws(as.character(commodity_value))
  if (is.na(commodity_clean) || !nzchar(commodity_clean)) {
    return(character(0))
  }

  if (identical(commodity_clean, "All Rice")) {
    return(c("All Rice", "Rough Rice"))
  }

  commodity_clean
}

waob_candidate_basis_label <- function(commodity_value) {
  commodity_clean <- trimws(as.character(commodity_value))

  dplyr::case_when(
    commodity_clean == "Rough Rice" ~ "rough",
    commodity_clean == "All Rice" ~ "milled",
    TRUE ~ "unknown"
  )
}

waob_safe_min_numeric <- function(values) {
  numeric_values <- suppressWarnings(as.numeric(values))
  numeric_values <- numeric_values[is.finite(numeric_values)]

  if (length(numeric_values) == 0) {
    return(NA_real_)
  }

  min(numeric_values)
}

waob_safe_second_min_numeric <- function(values) {
  numeric_values <- suppressWarnings(as.numeric(values))
  numeric_values <- sort(unique(numeric_values[is.finite(numeric_values)]))

  if (length(numeric_values) < 2) {
    return(NA_real_)
  }

  numeric_values[[2]]
}

waob_value_at_best_score <- function(values, scores) {
  numeric_values <- suppressWarnings(as.numeric(values))
  numeric_scores <- suppressWarnings(as.numeric(scores))
  valid <- is.finite(numeric_values) & is.finite(numeric_scores)

  if (!any(valid)) {
    return(NA_real_)
  }

  filtered_values <- numeric_values[valid]
  filtered_scores <- numeric_scores[valid]

  filtered_values[[which.min(filtered_scores)]]
}

waob_near_equal_numeric <- function(x, y) {
  x_num <- suppressWarnings(as.numeric(x))
  y_num <- suppressWarnings(as.numeric(y))

  if (
    length(x_num) == 0 ||
    length(y_num) == 0 ||
    is.na(x_num[[1]]) ||
    is.na(y_num[[1]]) ||
    !is.finite(x_num[[1]]) ||
    !is.finite(y_num[[1]])
  ) {
    return(FALSE)
  }

  isTRUE(all.equal(x_num[[1]], y_num[[1]], tolerance = sqrt(.Machine$double.eps)))
}

normalize_waob_wasde_commodity <- function(code_values, description_values) {
  code_clean <- trimws(as.character(code_values))
  desc_clean <- trimws(as.character(description_values))
  desc_norm <- toupper(desc_clean)

  out <- dplyr::case_when(
    code_clean == "422110" ~ "All Rice",
    code_clean == "9422200" ~ "Long Grain",
    code_clean == "9422300" ~ "Medium and Short Grain",
    code_clean == "9422100" ~ "Rough Rice",
    desc_norm %in% c("RICE", "ALL RICE", "RICE, MILLED") ~ "All Rice",
    desc_norm %in% c("LONG", "LONG GRAIN", "RICE, LONG", "RICE, LONG GRAIN", "LONG GRAIN RICE") ~ "Long Grain",
    desc_norm %in% c("MED & SHORT", "MEDIUM & SHORT", "RICE, MED AND SHORT", "RICE, MEDIUM AND SHORT", "RICE, MED & SHORT") ~ "Medium and Short Grain",
    desc_norm %in% c("RICE, ROUGH", "ROUGH RICE") ~ "Rough Rice",
    TRUE ~ normalize_wasde_commodity(desc_clean)
  )

  out[!nzchar(trimws(out))] <- "All Rice"
  out
}

normalize_waob_wasde_metric_id <- function(values) {
  normalize_wasde_metric_id(values)
}

is_waob_wasde_world_country <- function(country_code, country_name) {
  code_norm <- toupper(trimws(as.character(country_code)))
  name_norm <- toupper(trimws(as.character(country_name)))

  code_norm %in% c("WORLD", "WLD", "WRLD", "GRAND_TOTAL", "GRAND TOTAL", "00") |
    name_norm %in% c("WORLD", "TOTAL WORLD", "WORLD TOTAL", "GRAND TOTAL")
}

normalize_waob_wasde_country_code <- function(values) {
  normalized <- toupper(trimws(as.character(values)))
  normalized <- gsub("[^A-Z0-9]+", "_", normalized)
  normalized <- gsub("_+", "_", normalized)
  normalized <- gsub("^_|_$", "", normalized)
  normalized[!nzchar(normalized)] <- "UNKNOWN"
  normalized
}

is_wasde_world_geography <- function(values) {
  normalized <- toupper(trimws(as.character(values)))
  normalized %in% c("WORLD", "GRAND TOTAL", "GRAND_TOTAL", "TOTAL WORLD")
}

normalize_wasde_geography_code <- function(values) {
  normalized <- toupper(trimws(as.character(values)))
  normalized <- gsub("[^A-Z0-9]+", "_", normalized)
  normalized <- gsub("_+", "_", normalized)
  normalized <- gsub("^_|_$", "", normalized)
  normalized[!nzchar(normalized)] <- "UNKNOWN"
  normalized
}

load_wasde_marketing_year_data <- function(path, country_canonical_map) {
  assert_required_columns(path, required_wasde_source_cols, basename(path))

  raw_wasde <- read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
  raw_wasde$TIMEPERIOD_DESC <- trimws(as.character(raw_wasde$TIMEPERIOD_DESC))
  raw_wasde$TIMEPERIOD_SHORT <- trimws(as.character(raw_wasde$TIMEPERIOD_SHORT))
  raw_wasde$TIMEPERIOD_LONG <- trimws(as.character(raw_wasde$TIMEPERIOD_LONG))
  raw_wasde$LAST_UPDATED <- trimws(as.character(raw_wasde$LAST_UPDATED))
  raw_wasde$DATE_ESTIMATE_MADE <- trimws(as.character(raw_wasde$DATE_ESTIMATE_MADE))

  derived_exports_rough_rows <- build_wasde_exports_rough_rows(raw_wasde)
  if (nrow(derived_exports_rough_rows) > 0) {
    raw_wasde <- dplyr::bind_rows(raw_wasde, derived_exports_rough_rows)
  }

  derived_total_domestic_and_residual_rows <- build_wasde_total_domestic_and_residual_rows(raw_wasde)
  if (nrow(derived_total_domestic_and_residual_rows) > 0) {
    raw_wasde <- dplyr::bind_rows(raw_wasde, derived_total_domestic_and_residual_rows)
  }

  raw_wasde$resolved_report_month <- resolve_wasde_report_month(
    raw_wasde$TIMEPERIOD_LONG,
    raw_wasde$TIMEPERIOD_DESC,
    raw_wasde$TIMEPERIOD_SHORT
  )
  default_report_month <- resolve_wasde_report_month_default(raw_wasde$resolved_report_month)
  raw_wasde$resolved_report_month <- dplyr::coalesce(raw_wasde$resolved_report_month, default_report_month)

  market_year_values <- suppressWarnings(as.integer(raw_wasde$YEAR_ID))
  valid_market_years <- market_year_values[!is.na(market_year_values) & is.finite(market_year_values)]
  market_year_window <- if (length(valid_market_years) > 0) {
    sprintf("%s-%s", min(valid_market_years), max(valid_market_years))
  } else {
    NA_character_
  }

  extracted_at_utc <- format(as.POSIXct(Sys.time(), tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")

  out <- raw_wasde %>%
    transmute(
      source = "wasde",
      frequency = "annual",
      commodity = normalize_wasde_commodity(.data$COMMODITY_DESC2),
      commodity_group = .data$commodity,
      country = dplyr::if_else(
        is_wasde_world_geography(.data$GEOGRAPHY_DESC),
        "GRAND_TOTAL",
        normalize_wasde_geography_code(.data$GEOGRAPHY_DESC)
      ),
      countryDescription = dplyr::if_else(
        is_wasde_world_geography(.data$GEOGRAPHY_DESC),
        "World",
        trimws(as.character(.data$GEOGRAPHY_DESC))
      ),
      country_source_code = .data$country,
      market_year = suppressWarnings(as.integer(.data$YEAR_ID)),
      analysis_month = 12L,
      calendar_year = .data$market_year,
      calendar_month = 12L,
      release_year = .data$market_year,
      release_month = 12L,
      release_period = ifelse(is.na(.data$market_year), NA_character_, sprintf("%04d-12", .data$market_year)),
      current_report_year = NA_integer_,
      current_report_month = suppressWarnings(as.integer(.data$resolved_report_month)),
      current_report_period = ifelse(
        !is.na(.data$current_report_month),
        sprintf("M%02d", .data$current_report_month),
        NA_character_
      ),
      current_report_label = dplyr::coalesce(
        dplyr::na_if(trimws(as.character(.data$TIMEPERIOD_LONG)), ""),
        dplyr::na_if(trimws(as.character(.data$TIMEPERIOD_DESC)), ""),
        dplyr::na_if(trimws(as.character(.data$TIMEPERIOD_SHORT)), "")
      ),
      attribute_id = NA_integer_,
      attribute_name = trimws(as.character(.data$ATTRIBUTE_DESC)),
      unit_id = NA_integer_,
      unit_name_raw = trimws(as.character(.data$UNIT_DESC)),
      revision_metric_id = normalize_wasde_metric_id(.data$ATTRIBUTE_DESC),
      revision_unit_class = classify_waob_wasde_revision_unit(.data$UNIT_DESC),
      phase1_status = "wasde_native",
      normalized_metric_id = normalize_wasde_metric_id(.data$ATTRIBUTE_DESC),
      canonical_unit = .data$unit_name_raw,
      unit_handling_notes = "Preserve WASDE native units in phase 1.",
      value_raw = suppressWarnings(as.numeric(.data$AMOUNT)),
      value_canonical = .data$value_raw,
      value_last_updated_at = dplyr::na_if(trimws(as.character(.data$LAST_UPDATED)), ""),
      wasde_timeperiod_desc_raw = dplyr::na_if(trimws(as.character(.data$TIMEPERIOD_DESC)), ""),
      wasde_timeperiod_short_raw = dplyr::na_if(trimws(as.character(.data$TIMEPERIOD_SHORT)), ""),
      wasde_timeperiod_long_raw = dplyr::na_if(trimws(as.character(.data$TIMEPERIOD_LONG)), ""),
      wasde_public_last_updated_raw = dplyr::na_if(trimws(as.character(.data$LAST_UPDATED)), ""),
      wasde_date_estimate_made_raw = dplyr::na_if(trimws(as.character(.data$DATE_ESTIMATE_MADE)), ""),
      release_row_key = paste(
        .data$country_source_code,
        .data$commodity,
        .data$market_year,
        .data$normalized_metric_id,
        .data$unit_name_raw,
        dplyr::row_number(),
        sep = "|"
      ),
      market_year_window = market_year_window,
      extracted_at_utc = extracted_at_utc,
      value_provenance = "native_wasde",
      provenance_note = NA_character_,
      world_source = dplyr::if_else(.data$country == "GRAND_TOTAL", "native_world_wasde", NA_character_),
      construction_components = NA_character_,
      country_legacy_code = .data$country,
      countryDescription_legacy = .data$countryDescription,
      canonical_review_row_id = NA_character_
    ) %>%
    filter(
      !is.na(.data$market_year),
      !is.na(.data$value_canonical),
      is.finite(.data$value_canonical),
      nzchar(.data$commodity),
      nzchar(.data$country)
    )

  world_rows <- out %>% filter(.data$country == "GRAND_TOTAL")
  country_rows <- out %>%
    filter(.data$country != "GRAND_TOTAL") %>%
    canonicalize_country_dataset("wasde", country_canonical_map)

  bind_rows(country_rows, world_rows) %>%
    arrange(.data$market_year, .data$commodity, .data$attribute_name, .data$country)
}

load_waob_wasde_release_history_data <- function(path, country_canonical_map) {
  assert_required_columns(path, required_waob_wasde_source_cols, basename(path))

  raw_waob <- read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)

  derived_total_domestic_and_residual_rows <- build_waob_total_domestic_and_residual_rows(raw_waob)
  if (nrow(derived_total_domestic_and_residual_rows) > 0) {
    align_to_raw_column_types <- function(rows, template) {
      shared_cols <- intersect(names(rows), names(template))
      for (col_name in shared_cols) {
        template_col <- template[[col_name]]
        if (is.integer(template_col)) {
          rows[[col_name]] <- suppressWarnings(as.integer(rows[[col_name]]))
        } else if (is.numeric(template_col)) {
          rows[[col_name]] <- suppressWarnings(as.numeric(rows[[col_name]]))
        } else if (is.logical(template_col)) {
          rows[[col_name]] <- as.logical(rows[[col_name]])
        } else if (is.character(template_col)) {
          rows[[col_name]] <- as.character(rows[[col_name]])
        }
      }
      rows
    }

    derived_total_domestic_and_residual_rows <- align_to_raw_column_types(
      derived_total_domestic_and_residual_rows,
      raw_waob
    )
    raw_waob <- dplyr::bind_rows(raw_waob, derived_total_domestic_and_residual_rows)
  }

  raw_waob <- raw_waob %>%
    mutate(
      wb_id_int = suppressWarnings(as.integer(.data$wb_id)),
      market_year_int = suppressWarnings(as.integer(.data$market_year)),
      calendar_year_int = suppressWarnings(as.integer(.data$calendar_year)),
      forecast_month_int = suppressWarnings(as.integer(.data$forecast_month)),
      release_year_int = suppressWarnings(as.integer(.data$release_year)),
      release_month_int = suppressWarnings(as.integer(.data$release_month)),
      attribute_id_int = suppressWarnings(as.integer(.data$attribute_id)),
      cm_unit_id_int = suppressWarnings(as.integer(.data$cm_unit_id)),
      wb_unit_id_int = suppressWarnings(as.integer(.data$wb_unit_id)),
      wb_value_num = suppressWarnings(as.numeric(.data$wb_value)),
      cm_value_num = suppressWarnings(as.numeric(.data$cm_value)),
      release_period_clean = dplyr::na_if(trimws(as.character(.data$release_period)), ""),
      last_update_clean = dplyr::na_if(trimws(as.character(.data$last_update)), ""),
      psd_last_update_clean = dplyr::na_if(trimws(as.character(.data$psd_last_update)), ""),
      is_derived_total_domestic_and_residual = normalize_waob_wasde_metric_id(.data$attribute_description) == "total_domestic_and_residual" &
        grepl("\\|components:", trimws(as.character(.data$update_userid))),
      derived_component_ids = ifelse(
        .data$is_derived_total_domestic_and_residual,
        sub("^.*\\|components:", "", trimws(as.character(.data$update_userid))),
        NA_character_
      )
    )

  market_year_values <- raw_waob$market_year_int
  valid_market_years <- market_year_values[!is.na(market_year_values) & is.finite(market_year_values)]
  market_year_window <- if (length(valid_market_years) > 0) {
    sprintf("%s-%s", min(valid_market_years), max(valid_market_years))
  } else {
    NA_character_
  }

  extracted_at_utc <- format(as.POSIXct(Sys.time(), tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")

  out <- raw_waob %>%
    transmute(
      source = "wasde_waob_release_history",
      frequency = "annual",
      commodity = normalize_waob_wasde_commodity(.data$cm_code, .data$cm_description),
      commodity_group = .data$commodity,
      country = dplyr::if_else(
        is_waob_wasde_world_country(.data$cn_code, .data$cn_name),
        "GRAND_TOTAL",
        normalize_waob_wasde_country_code(.data$cn_code)
      ),
      countryDescription = dplyr::if_else(
        .data$country == "GRAND_TOTAL",
        "World",
        trimws(as.character(.data$cn_name))
      ),
      country_source_code = dplyr::if_else(
        .data$country == "GRAND_TOTAL",
        "GRAND_TOTAL",
        normalize_waob_wasde_country_code(.data$cn_code)
      ),
      market_year = .data$market_year_int,
      analysis_month = dplyr::if_else(
        !is.na(.data$forecast_month_int) & .data$forecast_month_int >= 1L & .data$forecast_month_int <= 12L,
        .data$forecast_month_int,
        dplyr::if_else(
          !is.na(.data$release_month_int) & .data$release_month_int >= 1L & .data$release_month_int <= 12L,
          .data$release_month_int,
          12L
        )
      ),
      calendar_year = dplyr::coalesce(.data$calendar_year_int, .data$release_year_int, .data$market_year_int),
      calendar_month = .data$analysis_month,
      release_year = dplyr::coalesce(.data$calendar_year_int, .data$release_year_int, .data$market_year_int),
      release_month = .data$analysis_month,
      release_period = dplyr::coalesce(
        ifelse(
          !is.na(.data$release_year) & !is.na(.data$release_month),
          sprintf("%04d-%02d", .data$release_year, .data$release_month),
          NA_character_
        ),
        .data$release_period_clean
      ),
      current_report_year = .data$release_year,
      current_report_month = .data$release_month,
      current_report_period = .data$release_period,
      current_report_label = .data$release_period,
      attribute_id = .data$attribute_id_int,
      attribute_name = trimws(as.character(.data$attribute_description)),
      unit_id = .data$wb_unit_id_int,
      unit_name_raw = trimws(as.character(.data$wb_unit_description)),
      revision_metric_id = normalize_waob_wasde_metric_id(.data$attribute_description),
      revision_unit_class = classify_waob_wasde_revision_unit(.data$wb_unit_description),
      phase1_status = dplyr::if_else(
        .data$is_derived_total_domestic_and_residual,
        "waob_release_history_derived",
        "waob_release_history_native"
      ),
      normalized_metric_id = normalize_waob_wasde_metric_id(.data$attribute_description),
      canonical_unit = .data$unit_name_raw,
      unit_handling_notes = "WASDE report units remain source-of-truth; wb_unit_description is preserved as canonical release unit.",
      value_raw = .data$wb_value_num,
      value_canonical = .data$value_raw,
      value_last_updated_at = dplyr::coalesce(.data$psd_last_update_clean, .data$last_update_clean),
      wasde_timeperiod_desc_raw = NA_character_,
      wasde_timeperiod_short_raw = NA_character_,
      wasde_timeperiod_long_raw = NA_character_,
      wasde_public_last_updated_raw = NA_character_,
      wasde_date_estimate_made_raw = NA_character_,
      release_row_key = paste("waob", .data$wb_id_int, sep = "|"),
      market_year_window = market_year_window,
      extracted_at_utc = extracted_at_utc,
      value_provenance = dplyr::if_else(
        .data$is_derived_total_domestic_and_residual,
        "derived_from_components",
        "native_waob_wb_value"
      ),
      provenance_note = dplyr::case_when(
        .data$is_derived_total_domestic_and_residual ~ "Derived as Domestic Consumption + Food, Industrial, and Residual within matching WAOB release/country/commodity/unit scope.",
        is.na(.data$cm_value_num) ~ "wb_value retained; cm_value unavailable.",
        TRUE ~ "wb_value retained as report-unit value."
      ),
      world_source = dplyr::if_else(.data$country == "GRAND_TOTAL", "native_world_waob", NA_character_),
      construction_components = dplyr::if_else(.data$is_derived_total_domestic_and_residual, .data$derived_component_ids, NA_character_),
      country_legacy_code = .data$country,
      countryDescription_legacy = .data$countryDescription,
      canonical_review_row_id = NA_character_,
      waob_row_id = .data$wb_id_int,
      waob_country_code_raw = trimws(as.character(.data$cn_code)),
      waob_country_name_raw = trimws(as.character(.data$cn_name)),
      waob_commodity_code_raw = trimws(as.character(.data$cm_code)),
      waob_commodity_name_raw = trimws(as.character(.data$cm_description)),
      waob_attribute_id_raw = .data$attribute_id_int,
      waob_attribute_name_raw = trimws(as.character(.data$attribute_description)),
      waob_cm_unit_id_raw = .data$cm_unit_id_int,
      waob_cm_unit_name_raw = trimws(as.character(.data$cm_unit_description)),
      waob_wb_unit_id_raw = .data$wb_unit_id_int,
      waob_wb_unit_name_raw = trimws(as.character(.data$wb_unit_description)),
      waob_forecast_month_raw = .data$forecast_month_int,
      waob_calendar_year_raw = .data$calendar_year_int,
      waob_release_year_raw = .data$release_year_int,
      waob_release_month_raw = .data$release_month_int,
      waob_release_period_raw = .data$release_period_clean,
      waob_last_update_raw = .data$last_update_clean,
      waob_psd_last_update_raw = .data$psd_last_update_clean,
      waob_pairing_key = paste(
        .data$country_source_code,
        .data$commodity,
        .data$market_year,
        .data$normalized_metric_id,
        .data$canonical_unit,
        sep = "|"
      ),
      waob_report_unit_source = dplyr::if_else(
        .data$is_derived_total_domestic_and_residual,
        "wasde_report_unit_truth_derived_from_components",
        "wasde_report_unit_truth"
      )
    ) %>%
    filter(
      !is.na(.data$market_year),
      !is.na(.data$release_year),
      !is.na(.data$release_month),
      !is.na(.data$value_canonical),
      is.finite(.data$value_canonical),
      nzchar(.data$commodity),
      nzchar(.data$country),
      nzchar(.data$normalized_metric_id),
      nzchar(.data$canonical_unit)
    )

  world_rows <- out %>% filter(.data$country == "GRAND_TOTAL")
  country_rows <- out %>%
    filter(.data$country != "GRAND_TOTAL") %>%
    canonicalize_country_dataset("waob_wasde", country_canonical_map)

  out <- bind_rows(country_rows, world_rows) %>%
    arrange(
      .data$release_year,
      .data$release_month,
      .data$market_year,
      .data$commodity,
      .data$attribute_name,
      .data$country
    )

  assert_dataset_columns(
    out,
    waob_wasde_release_history_required_processed_cols,
    "WAOB WASDE release-history processed artifact"
  )

  out
}

waob_release_ord_gap_months <- function(current_release_ord, prior_release_ord) {
  current_ord <- suppressWarnings(as.integer(current_release_ord))
  prior_ord <- suppressWarnings(as.integer(prior_release_ord))

  current_year <- current_ord %/% 100L
  current_month <- current_ord %% 100L
  prior_year <- prior_ord %/% 100L
  prior_month <- prior_ord %% 100L

  ifelse(
    is.na(current_ord) | is.na(prior_ord),
    NA_integer_,
    as.integer((current_year - prior_year) * 12L + (current_month - prior_month))
  )
}

waob_prior_release_target_ord <- function(current_release_ord) {
  current_ord <- suppressWarnings(as.integer(current_release_ord))
  current_year <- current_ord %/% 100L
  current_month <- current_ord %% 100L

  prior_year <- ifelse(current_month <= 1L, current_year - 1L, current_year)
  prior_month <- ifelse(current_month <= 1L, 12L, current_month - 1L)

  ifelse(
    is.na(current_ord),
    NA_integer_,
    as.integer(prior_year * 100L + prior_month)
  )
}

psd_release_ord_gap_months <- function(current_release_ord, prior_release_ord) {
  current_ord <- suppressWarnings(as.integer(current_release_ord))
  prior_ord <- suppressWarnings(as.integer(prior_release_ord))

  current_year <- current_ord %/% 100L
  current_month <- current_ord %% 100L
  prior_year <- prior_ord %/% 100L
  prior_month <- prior_ord %% 100L

  ifelse(
    is.na(current_ord) | is.na(prior_ord),
    NA_integer_,
    as.integer((current_year - prior_year) * 12L + (current_month - prior_month))
  )
}

psd_revision_stable_fraction <- function(keys, salt = "") {
  keys <- paste0(as.character(keys), "|", salt)
  vapply(keys, function(key) {
    ints <- utf8ToInt(key)
    if (length(ints) == 0L) return(0)
    (sum(ints * seq_along(ints)) %% 10000L) / 9999
  }, numeric(1), USE.NAMES = FALSE)
}

psd_revision_metric_class_fallback <- function(metric_ids, canonical_units) {
  metric_ids <- tolower(trimws(as.character(metric_ids)))
  canonical_units <- tolower(trimws(as.character(canonical_units)))
  dplyr::case_when(
    grepl("area|acre|hectare", metric_ids) | grepl("ha|acre", canonical_units) ~ "area",
    grepl("yield", metric_ids) | grepl("mt/ha", canonical_units, fixed = TRUE) ~ "yield",
    grepl("rate|ratio", metric_ids) | grepl("ratio|percent", canonical_units) ~ "rate",
    TRUE ~ "quantity"
  )
}

psd_revision_basis_profile_fallback <- function(metric_ids, canonical_units) {
  metric_ids <- tolower(trimws(as.character(metric_ids)))
  canonical_units <- tolower(trimws(as.character(canonical_units)))
  dplyr::case_when(
    grepl("area|acre|hectare", metric_ids) | grepl("ha|acre", canonical_units) ~ "area",
    grepl("rate|ratio", metric_ids) | grepl("ratio|percent", canonical_units) ~ "rate",
    grepl("rough", metric_ids) ~ "rough_eq",
    grepl("milled", metric_ids) ~ "milled_eq",
    TRUE ~ "native"
  )
}

psd_revision_prepare_rows <- function(data, role = c("current", "prior")) {
  role <- match.arg(role)
  if (!is.data.frame(data) || nrow(data) == 0L) return(tibble::tibble())

  required_cols <- c(
    "source", "frequency", "commodity", "commodity_group", "country", "countryDescription", "country_source_code",
    "market_year", "analysis_month", "calendar_year", "calendar_month",
    "release_year", "release_month", "release_period",
    "attribute_id", "attribute_name", "unit_id", "unit_name_raw",
    "phase1_status", "normalized_metric_id", "canonical_unit",
    "value_canonical", "release_row_key", "market_year_window", "extracted_at_utc",
    "value_provenance", "provenance_note", "world_source", "construction_components",
    "psd_endpoint_scope", "country_legacy_code", "countryDescription_legacy", "canonical_review_row_id"
  )
  assert_dataset_columns(data, required_cols, paste0("PSD revision-delta ", role, " source"))

  n <- nrow(data)
  optional_character <- function(column, default = NA_character_) {
    if (column %in% names(data)) trimws(as.character(data[[column]])) else rep(default, n)
  }

  optional_character_nonblank <- function(column, default = NA_character_) {
    values <- optional_character(column, default = default)
    values[!nzchar(values)] <- default
    values
  }

  metric_ids <- optional_character_nonblank("normalized_metric_id", "")
  canonical_units <- optional_character_nonblank("canonical_unit", "")
  metric_class <- optional_character_nonblank("metric_class", NA_character_)
  basis_profile <- optional_character_nonblank("basis_profile", NA_character_)
  metric_class <- ifelse(is.na(metric_class), psd_revision_metric_class_fallback(metric_ids, canonical_units), metric_class)
  basis_profile <- ifelse(is.na(basis_profile), psd_revision_basis_profile_fallback(metric_ids, canonical_units), basis_profile)

  out <- tibble::tibble(
    source = optional_character_nonblank("source", "psd_revision_delta"),
    frequency = optional_character_nonblank("frequency", "annual"),
    commodity = optional_character_nonblank("commodity", ""),
    commodity_group = optional_character_nonblank("commodity_group", ""),
    country = optional_character_nonblank("country", ""),
    countryDescription = optional_character_nonblank("countryDescription", ""),
    country_source_code = optional_character_nonblank("country_source_code", ""),
    market_year = suppressWarnings(as.integer(data$market_year)),
    analysis_month = suppressWarnings(as.integer(data$analysis_month)),
    calendar_year = suppressWarnings(as.integer(data$calendar_year)),
    calendar_month = suppressWarnings(as.integer(data$calendar_month)),
    release_year = suppressWarnings(as.integer(data$release_year)),
    release_month = suppressWarnings(as.integer(data$release_month)),
    release_period = optional_character_nonblank("release_period", NA_character_),
    release_ord = ifelse(
      !is.na(suppressWarnings(as.integer(data$release_year))) & !is.na(suppressWarnings(as.integer(data$release_month))),
      suppressWarnings(as.integer(data$release_year)) * 100L + suppressWarnings(as.integer(data$release_month)),
      unname(vapply(data$release_period, normalize_psd_release_key, integer(1)))
    ),
    normalized_metric_id = metric_ids,
    attribute_id = suppressWarnings(as.integer(data$attribute_id)),
    attribute_name = optional_character_nonblank("attribute_name", ""),
    unit_id = suppressWarnings(as.integer(data$unit_id)),
    unit_name_raw = optional_character_nonblank("unit_name_raw", ""),
    canonical_unit = canonical_units,
    phase1_status_source = optional_character_nonblank("phase1_status", ""),
    metric_class = metric_class,
    basis_profile = basis_profile,
    market_year_window = optional_character_nonblank("market_year_window", NA_character_),
    extracted_at_utc_source = optional_character_nonblank("extracted_at_utc", NA_character_),
    release_row_key = optional_character_nonblank("release_row_key", NA_character_),
    value_canonical = suppressWarnings(as.numeric(data$value_canonical)),
    value_provenance_source = optional_character_nonblank("value_provenance", NA_character_),
    provenance_note_source = optional_character_nonblank("provenance_note", NA_character_),
    world_source = optional_character_nonblank("world_source", NA_character_),
    construction_components = optional_character_nonblank("construction_components", NA_character_),
    psd_endpoint_scope = optional_character_nonblank("psd_endpoint_scope", NA_character_),
    country_legacy_code = optional_character_nonblank("country_legacy_code", NA_character_),
    countryDescription_legacy = optional_character_nonblank("countryDescription_legacy", NA_character_),
    canonical_review_row_id = optional_character_nonblank("canonical_review_row_id", NA_character_)
  ) %>%
    mutate(
      join_key = paste(
        .data$commodity,
        .data$country,
        .data$market_year,
        .data$normalized_metric_id,
        .data$canonical_unit,
        .data$metric_class,
        .data$basis_profile,
        .data$world_source,
        sep = "|"
      )
    ) %>%
    filter(
      nzchar(.data$commodity),
      nzchar(.data$country),
      nzchar(.data$normalized_metric_id),
      nzchar(.data$canonical_unit),
      !is.na(.data$market_year),
      !is.na(.data$value_canonical),
      is.finite(.data$value_canonical)
    ) %>%
    arrange(desc(.data$release_ord), .data$release_row_key) %>%
    distinct(.data$join_key, .keep_all = TRUE)

  out
}

materialize_psd_revision_delta_data <- function(current_psd_data, prior_psd_data, simulated_delta_active = FALSE, development_placeholder = FALSE, zero_holdout_fraction = 0.035, prior_source_label = "archived PSD processed data", prior_phase_status = "psd_current_plus_archived_prior", missing_prior_phase_status = "psd_current_without_archived_prior") {
  current_rows <- psd_revision_prepare_rows(current_psd_data, role = "current")
  prior_rows <- psd_revision_prepare_rows(prior_psd_data, role = "prior")

  if (nrow(current_rows) == 0L) return(tibble::tibble())

  prior_lookup <- prior_rows %>%
    transmute(
      join_key = .data$join_key,
      prior_release_year = .data$release_year,
      prior_release_month = .data$release_month,
      prior_release_period = .data$release_period,
      prior_release_ord = .data$release_ord,
      prior_release_row_key = .data$release_row_key,
      prior_value_canonical = .data$value_canonical,
      prior_world_source = .data$world_source,
      prior_metric_class = .data$metric_class,
      prior_basis_profile = .data$basis_profile
    )

  relaxed_prior_world_keys <- prior_rows %>%
    filter(.data$country == psd_world_country_code()) %>%
    transmute(
      relaxed_world_key = paste(
        .data$commodity,
        .data$country,
        .data$market_year,
        .data$normalized_metric_id,
        .data$canonical_unit,
        sep = "|"
      )
    ) %>%
    distinct()

  joined_rows <- current_rows %>%
    mutate(
      relaxed_world_key = paste(
        .data$commodity,
        .data$country,
        .data$market_year,
        .data$normalized_metric_id,
        .data$canonical_unit,
        sep = "|"
      )
    ) %>%
    left_join(prior_lookup, by = "join_key") %>%
    left_join(relaxed_prior_world_keys %>% mutate(relaxed_world_prior_exists = TRUE), by = "relaxed_world_key") %>%
    mutate(
      prior_release_available = !is.na(.data$prior_release_ord)
    )

  prior_available_count <- sum(joined_rows$prior_release_available, na.rm = TRUE)
  zero_holdout_target <- if (isTRUE(simulated_delta_active) && prior_available_count > 0L) {
    max(1L, as.integer(round(prior_available_count * zero_holdout_fraction)))
  } else {
    0L
  }
  zero_holdout_keys <- if (zero_holdout_target > 0L) {
    joined_rows %>%
      filter(.data$prior_release_available) %>%
      mutate(zero_holdout_score = psd_revision_stable_fraction(.data$join_key, salt = "zero_holdout")) %>%
      arrange(.data$zero_holdout_score, .data$join_key) %>%
      slice_head(n = zero_holdout_target) %>%
      pull(.data$join_key)
  } else {
    character()
  }

  out <- joined_rows %>%
    mutate(
      simulated_delta_zero_holdout = isTRUE(simulated_delta_active) &
        .data$prior_release_available &
        .data$join_key %in% zero_holdout_keys,
      simulated_delta_factor = dplyr::if_else(
        isTRUE(simulated_delta_active) & .data$prior_release_available & !.data$simulated_delta_zero_holdout,
        {
          signed_fraction <- psd_revision_stable_fraction(.data$join_key, salt = "signed_delta")
          magnitude_fraction <- psd_revision_stable_fraction(.data$join_key, salt = "magnitude_delta")
          sign <- ifelse(signed_fraction < 0.5, -1, 1)
          sign * (0.02 + magnitude_fraction * 0.03)
        },
        0
      ),
      current_value_canonical = dplyr::if_else(
        isTRUE(simulated_delta_active) & .data$prior_release_available,
        .data$prior_value_canonical * (1 + .data$simulated_delta_factor),
        .data$value_canonical
      ),
      value_difference = dplyr::if_else(
        .data$prior_release_available,
        .data$current_value_canonical - .data$prior_value_canonical,
        NA_real_
      ),
      percent_difference = dplyr::if_else(
        .data$prior_release_available & is.finite(.data$prior_value_canonical) & .data$prior_value_canonical != 0,
        (.data$value_difference / .data$prior_value_canonical) * 100,
        NA_real_
      ),
      current_release_year = .data$release_year,
      current_release_month = .data$release_month,
      current_release_period = .data$release_period,
      current_release_ord = .data$release_ord,
      current_release_row_key = .data$release_row_key,
      release_gap_months = psd_release_ord_gap_months(.data$current_release_ord, .data$prior_release_ord),
      world_pairing_status = dplyr::case_when(
        .data$country != psd_world_country_code() ~ "non_world",
        .data$prior_release_available ~ "world_metadata_exact",
        dplyr::coalesce(.data$relaxed_world_prior_exists, FALSE) ~ "world_metadata_mismatch_excluded",
        TRUE ~ "world_prior_missing"
      ),
      phase1_status = dplyr::case_when(
        .data$prior_release_available & isTRUE(development_placeholder) ~ "psd_current_plus_development_prior",
        .data$prior_release_available ~ prior_phase_status,
        TRUE ~ missing_prior_phase_status
      ),
      series_mapping_status = dplyr::if_else(.data$prior_release_available, "exact_processed_key", "unmatched"),
      series_mapping_rule = "commodity|country|market_year|metric|unit|metric_class|basis_profile|world_source",
      value_provenance = "psd_current_value_with_archived_prior",
      provenance_note = dplyr::case_when(
        isTRUE(simulated_delta_active) & .data$prior_release_available ~ paste0("Current value is deterministically simulated for development preview; prior value is sourced from ", prior_source_label, "."),
        .data$prior_release_available ~ paste0("Current value sourced from current PSD processed data; prior value sourced from ", prior_source_label, "."),
        TRUE ~ paste0("Current value sourced from current PSD processed data; no ", prior_source_label, " matched this processed series.")
      ),
      extracted_at_utc = format(as.POSIXct(Sys.time(), tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
      simulated_delta_active = isTRUE(simulated_delta_active) & .data$prior_release_available,
      development_placeholder = isTRUE(development_placeholder)
    ) %>%
    transmute(
      source = "psd_revision_delta",
      frequency = .data$frequency,
      commodity = .data$commodity,
      commodity_group = .data$commodity_group,
      country = .data$country,
      countryDescription = .data$countryDescription,
      country_source_code = .data$country_source_code,
      market_year = .data$market_year,
      analysis_month = .data$analysis_month,
      calendar_year = .data$calendar_year,
      calendar_month = .data$calendar_month,
      normalized_metric_id = .data$normalized_metric_id,
      attribute_id = .data$attribute_id,
      attribute_name = .data$attribute_name,
      unit_id = .data$unit_id,
      unit_name_raw = .data$unit_name_raw,
      canonical_unit = .data$canonical_unit,
      phase1_status = .data$phase1_status,
      metric_class = .data$metric_class,
      basis_profile = .data$basis_profile,
      market_year_window = .data$market_year_window,
      extracted_at_utc = .data$extracted_at_utc,
      current_release_year = .data$current_release_year,
      current_release_month = .data$current_release_month,
      current_release_period = .data$current_release_period,
      current_release_ord = .data$current_release_ord,
      current_release_row_key = .data$current_release_row_key,
      current_value_canonical = .data$current_value_canonical,
      prior_release_year = .data$prior_release_year,
      prior_release_month = .data$prior_release_month,
      prior_release_period = .data$prior_release_period,
      prior_release_ord = .data$prior_release_ord,
      prior_release_row_key = .data$prior_release_row_key,
      prior_value_canonical = .data$prior_value_canonical,
      prior_release_available = .data$prior_release_available,
      release_gap_months = .data$release_gap_months,
      value_difference = .data$value_difference,
      percent_difference = .data$percent_difference,
      simulated_delta_active = .data$simulated_delta_active,
      simulated_delta_factor = .data$simulated_delta_factor,
      simulated_delta_zero_holdout = .data$simulated_delta_zero_holdout,
      development_placeholder = .data$development_placeholder,
      world_pairing_status = .data$world_pairing_status,
      series_mapping_status = .data$series_mapping_status,
      series_mapping_rule = .data$series_mapping_rule,
      value_provenance = .data$value_provenance,
      provenance_note = .data$provenance_note,
      world_source = .data$world_source,
      construction_components = .data$construction_components,
      psd_endpoint_scope = .data$psd_endpoint_scope,
      country_legacy_code = .data$country_legacy_code,
      countryDescription_legacy = .data$countryDescription_legacy,
      canonical_review_row_id = .data$canonical_review_row_id
    ) %>%
    arrange(desc(.data$market_year), desc(abs(.data$percent_difference)), .data$commodity, .data$country, .data$normalized_metric_id)

  assert_dataset_columns(out, psd_revision_delta_required_processed_cols, "PSD revision-delta processed artifact")
  attr(out, "simulated_delta_active") <- isTRUE(simulated_delta_active)
  attr(out, "development_placeholder") <- isTRUE(development_placeholder)
  attr(out, "world_pairing_exclusions_count") <- sum(out$world_pairing_status == "world_metadata_mismatch_excluded", na.rm = TRUE)
  out
}

select_psd_release_archive_entry <- function(project_dir, artifact_role = "psd_rice_my_pre", max_release_key = Inf) {
  manifest <- read_psd_release_archive_manifest(project_dir)
  if (length(manifest) == 0L) return(NULL)

  entries <- manifest[vapply(manifest, function(entry) {
    is.list(entry) && identical(as.character(entry$artifact_role), artifact_role)
  }, logical(1))]
  if (length(entries) == 0L) return(NULL)

  release_keys <- vapply(entries, function(entry) normalize_psd_release_key(entry$archive_release_period), integer(1))
  keep <- !is.na(release_keys) & release_keys <= max_release_key
  if (!any(keep)) return(NULL)
  entries <- entries[keep]
  release_keys <- release_keys[keep]
  entries[[which.max(release_keys)]]
}

seed_psd_release_archive_if_missing <- function(project_dir, artifact_paths, release_key) {
  release_key <- normalize_psd_release_key(release_key)
  if (is.na(release_key)) {
    return(list(action = "skip_missing_release_key", development_placeholder = FALSE))
  }

  existing_entry <- select_psd_release_archive_entry(project_dir, artifact_role = "psd_rice_my_pre", max_release_key = release_key)
  if (!is.null(existing_entry) && identical(normalize_psd_release_key(existing_entry$archive_release_period), release_key)) {
    return(list(action = "noop_existing_archive", development_placeholder = isTRUE(existing_entry$development_placeholder), entry = existing_entry))
  }

  result <- materialize_psd_release_archive(
    project_dir = project_dir,
    artifact_paths = artifact_paths,
    archive_release_key = release_key,
    candidate_release_key = release_key,
    archive_reason = "development_seed_prior_placeholder",
    development_placeholder = TRUE,
    simulated_delta_active = FALSE
  )
  result$action <- "development_seed_archive"
  result$development_placeholder <- TRUE
  result
}

materialize_wasde_revision_delta_data <- function(wasde_marketing_year_data, wasde_release_history_data) {
  assert_dataset_columns(
    wasde_marketing_year_data,
    wasde_required_processed_cols,
    "wasde_revision_delta current source"
  )
  assert_dataset_columns(
    wasde_release_history_data,
    waob_wasde_release_history_required_processed_cols,
    "wasde_revision_delta prior source"
  )

  latest_waob_release_ord <- wasde_release_history_data %>%
    transmute(
      release_year = suppressWarnings(as.integer(.data$release_year)),
      release_month = suppressWarnings(as.integer(.data$release_month)),
      release_ord = ifelse(
        !is.na(.data$release_year) & !is.na(.data$release_month),
        .data$release_year * 100L + .data$release_month,
        NA_integer_
      )
    ) %>%
    filter(!is.na(.data$release_ord)) %>%
    summarise(latest_release_ord = max(.data$release_ord)) %>%
    pull(.data$latest_release_ord)

  if (length(latest_waob_release_ord) == 0 || is.na(latest_waob_release_ord) || !is.finite(latest_waob_release_ord)) {
    latest_waob_release_ord <- NA_integer_
  }

  latest_waob_release_year <- ifelse(!is.na(latest_waob_release_ord), latest_waob_release_ord %/% 100L, NA_integer_)
  latest_waob_release_month <- ifelse(!is.na(latest_waob_release_ord), latest_waob_release_ord %% 100L, NA_integer_)

  current_candidates <- wasde_marketing_year_data %>%
    transmute(
      source = "wasde_revision_delta",
      frequency = "annual",
      commodity = trimws(as.character(.data$commodity)),
      commodity_group = trimws(as.character(.data$commodity_group)),
      country = trimws(as.character(.data$country)),
      countryDescription = trimws(as.character(.data$countryDescription)),
      country_source_code = trimws(as.character(.data$country_source_code)),
      market_year = suppressWarnings(as.integer(.data$market_year)),
      analysis_month_input = suppressWarnings(as.integer(.data$analysis_month)),
      calendar_year_input = suppressWarnings(as.integer(.data$calendar_year)),
      calendar_month_input = suppressWarnings(as.integer(.data$calendar_month)),
      current_report_year = suppressWarnings(as.integer(.data$current_report_year)),
      current_report_month = suppressWarnings(as.integer(.data$current_report_month)),
      current_report_period = dplyr::na_if(trimws(as.character(.data$current_report_period)), ""),
      current_report_label = dplyr::na_if(trimws(as.character(.data$current_report_label)), ""),
      normalized_metric_id = trimws(as.character(.data$normalized_metric_id)),
      revision_metric_id = normalize_wasde_metric_id(
        dplyr::coalesce(
          dplyr::na_if(trimws(as.character(.data$revision_metric_id)), ""),
          dplyr::na_if(trimws(as.character(.data$normalized_metric_id)), ""),
          trimws(as.character(.data$attribute_name))
        )
      ),
      revision_unit_class = classify_waob_wasde_revision_unit(
        dplyr::coalesce(
          dplyr::na_if(trimws(as.character(.data$unit_name_raw)), ""),
          dplyr::na_if(trimws(as.character(.data$canonical_unit)), "")
        )
      ),
      attribute_id = suppressWarnings(as.integer(.data$attribute_id)),
      attribute_name = trimws(as.character(.data$attribute_name)),
      unit_id = suppressWarnings(as.integer(.data$unit_id)),
      unit_name_raw = trimws(as.character(.data$unit_name_raw)),
      canonical_unit = trimws(as.character(.data$canonical_unit)),
      market_year_window = trimws(as.character(.data$market_year_window)),
      current_release_row_key = dplyr::na_if(trimws(as.character(.data$release_row_key)), ""),
      current_value_canonical = suppressWarnings(as.numeric(.data$value_canonical)),
      value_last_updated_at = dplyr::na_if(trimws(as.character(.data$value_last_updated_at)), ""),
      wasde_public_last_updated_raw = dplyr::na_if(trimws(as.character(.data$wasde_public_last_updated_raw)), ""),
      country_legacy_code = trimws(as.character(.data$country_legacy_code)),
      countryDescription_legacy = trimws(as.character(.data$countryDescription_legacy)),
      canonical_review_row_id = dplyr::na_if(trimws(as.character(.data$canonical_review_row_id)), "")
    ) %>%
    mutate(
      country_join_key = normalize_wasde_revision_country_key(.data$country_source_code),
      scoped_revision_commodity = .data$commodity %in% c("All Rice", "Long Grain", "Medium and Short Grain"),
      current_release_month = dplyr::coalesce(
        dplyr::if_else(
          !is.na(.data$current_report_month) & .data$current_report_month >= 1L & .data$current_report_month <= 12L,
          .data$current_report_month,
          NA_integer_
        ),
        dplyr::if_else(
          !is.na(.data$analysis_month_input) & .data$analysis_month_input >= 1L & .data$analysis_month_input <= 12L,
          .data$analysis_month_input,
          NA_integer_
        ),
        latest_waob_release_month,
        12L
      ),
      current_release_year = dplyr::coalesce(.data$current_report_year, latest_waob_release_year, .data$market_year),
      current_release_period = ifelse(
        !is.na(.data$current_release_year) & !is.na(.data$current_release_month),
        sprintf("%04d-%02d", .data$current_release_year, .data$current_release_month),
        .data$current_report_period
      ),
      current_release_ord = ifelse(
        !is.na(.data$current_release_year) & !is.na(.data$current_release_month),
        .data$current_release_year * 100L + .data$current_release_month,
        NA_integer_
      ),
      prior_target_release_ord = dplyr::if_else(
        .data$scoped_revision_commodity,
        waob_prior_release_target_ord(.data$current_release_ord),
        NA_integer_
      ),
      waob_pairing_key = paste(
        .data$country_source_code,
        .data$commodity,
        .data$market_year,
        .data$revision_metric_id,
        .data$revision_unit_class,
        sep = "|"
      ),
      current_waob_row_id = NA_integer_,
      current_row_id = dplyr::row_number()
    ) %>%
    filter(
      nzchar(.data$commodity),
      nzchar(.data$country),
      nzchar(.data$country_source_code),
      !is.na(.data$country_join_key),
      nzchar(.data$normalized_metric_id),
      nzchar(.data$revision_metric_id),
      nzchar(.data$revision_unit_class),
      !is.na(.data$market_year),
      !is.na(.data$current_value_canonical),
      is.finite(.data$current_value_canonical)
    )

  if (nrow(current_candidates) == 0) {
    return(tibble::tibble())
  }

  wasde_milling_lookup <- current_candidates %>%
    filter(.data$normalized_metric_id == "milling_rate_9999") %>%
    transmute(
      country_join_key = .data$country_join_key,
      commodity = .data$commodity,
      market_year = .data$market_year,
      current_release_ord = .data$current_release_ord,
      milling_rate_diagnostic_value = suppressWarnings(as.numeric(.data$current_value_canonical))
    ) %>%
    filter(
      !is.na(.data$milling_rate_diagnostic_value),
      is.finite(.data$milling_rate_diagnostic_value),
      .data$milling_rate_diagnostic_value > 0
    ) %>%
    group_by(.data$country_join_key, .data$commodity, .data$market_year) %>%
    arrange(desc(.data$current_release_ord), .by_group = TRUE) %>%
    slice_head(n = 1L) %>%
    ungroup() %>%
    select(
      "country_join_key",
      "commodity",
      "market_year",
      "milling_rate_diagnostic_value"
    )

  waob_release_base <- wasde_release_history_data %>%
    transmute(
      country_source_code = trimws(as.character(.data$country_source_code)),
      country_join_key = normalize_wasde_revision_country_key(.data$country_source_code),
      commodity = trimws(as.character(.data$commodity)),
      market_year = suppressWarnings(as.integer(.data$market_year)),
      revision_metric_id = normalize_waob_wasde_metric_id(
        dplyr::coalesce(
          dplyr::na_if(trimws(as.character(.data$revision_metric_id)), ""),
          dplyr::na_if(trimws(as.character(.data$normalized_metric_id)), ""),
          trimws(as.character(.data$attribute_name))
        )
      ),
      revision_unit_class = classify_waob_wasde_revision_unit(
        dplyr::coalesce(
          dplyr::na_if(trimws(as.character(.data$revision_unit_class)), ""),
          dplyr::na_if(trimws(as.character(.data$unit_name_raw)), ""),
          dplyr::na_if(trimws(as.character(.data$canonical_unit)), "")
        )
      ),
      prior_release_year = suppressWarnings(as.integer(.data$release_year)),
      prior_release_month = suppressWarnings(as.integer(.data$release_month)),
      prior_release_period = dplyr::na_if(trimws(as.character(.data$release_period)), ""),
      prior_release_ord = ifelse(
        !is.na(.data$prior_release_year) & !is.na(.data$prior_release_month),
        .data$prior_release_year * 100L + .data$prior_release_month,
        NA_integer_
      ),
      prior_release_row_key = dplyr::na_if(trimws(as.character(.data$release_row_key)), ""),
      prior_waob_row_id = suppressWarnings(as.integer(.data$waob_row_id)),
      prior_value_canonical = suppressWarnings(as.numeric(.data$value_canonical)),
      waob_pairing_key = dplyr::na_if(trimws(as.character(.data$waob_pairing_key)), ""),
      waob_report_unit_source = dplyr::na_if(trimws(as.character(.data$waob_report_unit_source)), ""),
      prior_waob_raw_commodity_code = dplyr::na_if(trimws(as.character(.data$waob_commodity_code_raw)), ""),
      prior_waob_raw_commodity_name = dplyr::na_if(trimws(as.character(.data$waob_commodity_name_raw)), ""),
      waob_last_update_raw = dplyr::na_if(trimws(as.character(.data$waob_last_update_raw)), ""),
      waob_psd_last_update_raw = dplyr::na_if(trimws(as.character(.data$waob_psd_last_update_raw)), "")
    ) %>%
    filter(
      nzchar(.data$commodity),
      nzchar(.data$country_source_code),
      !is.na(.data$country_join_key),
      nzchar(.data$revision_metric_id),
      nzchar(.data$revision_unit_class),
      !is.na(.data$market_year),
      !is.na(.data$prior_release_ord),
      !is.na(.data$prior_value_canonical),
      is.finite(.data$prior_value_canonical)
    )

  current_match_candidates <- bind_rows(lapply(seq_len(nrow(current_candidates)), function(i) {
    row <- current_candidates[i, , drop = FALSE]
    commodity_candidates <- waob_wasde_commodity_candidates(row$commodity[[1]])
    metric_candidates <- waob_wasde_metric_candidates(row$revision_metric_id[[1]])
    unit_candidates <- waob_wasde_unit_candidates(row$revision_unit_class[[1]])

    if (length(commodity_candidates) == 0) {
      commodity_candidates <- row$commodity[[1]]
    }
    if (length(metric_candidates) == 0) {
      metric_candidates <- row$revision_metric_id[[1]]
    }
    if (length(unit_candidates) == 0) {
      unit_candidates <- row$revision_unit_class[[1]]
    }

    combinations <- expand.grid(
      match_commodity = commodity_candidates,
      match_metric_id = metric_candidates,
      match_unit_class = unit_candidates,
      stringsAsFactors = FALSE
    )

    tibble::tibble(
      current_row_id = row$current_row_id[[1]],
      country_join_key = row$country_join_key[[1]],
      commodity = row$commodity[[1]],
      current_metric_id = row$normalized_metric_id[[1]],
      market_year = row$market_year[[1]],
      current_release_ord = row$current_release_ord[[1]],
      match_commodity = combinations$match_commodity,
      match_metric_id = combinations$match_metric_id,
      match_unit_class = combinations$match_unit_class,
      series_mapping_status = ifelse(
        combinations$match_commodity == row$commodity[[1]] &
        combinations$match_metric_id == row$revision_metric_id[[1]] &
          combinations$match_unit_class == row$revision_unit_class[[1]],
        "exact",
        "alias"
      ),
      series_mapping_rule = ifelse(
        combinations$match_commodity == row$commodity[[1]] &
        combinations$match_metric_id == row$revision_metric_id[[1]] &
          combinations$match_unit_class == row$revision_unit_class[[1]],
        "exact_metric_unit",
        paste0(
          row$commodity[[1]], "=>", combinations$match_commodity,
          "|", row$revision_metric_id[[1]], "=>", combinations$match_metric_id,
          "|", row$revision_unit_class[[1]], "=>", combinations$match_unit_class
        )
      )
    )
  }))

  prior_candidates_expanded <- current_match_candidates %>%
    left_join(
      waob_release_base,
      by = c(
        "country_join_key",
        "match_commodity" = "commodity",
        "market_year",
        "match_metric_id" = "revision_metric_id",
        "match_unit_class" = "revision_unit_class"
      ),
      relationship = "many-to-many"
    ) %>%
    left_join(
      current_candidates %>%
        transmute(
          current_row_id = .data$current_row_id,
          scoped_revision_commodity = .data$scoped_revision_commodity,
          prior_target_release_ord = .data$prior_target_release_ord,
          current_value_canonical = .data$current_value_canonical,
          current_commodity = .data$commodity
        ),
      by = "current_row_id"
    ) %>%
    left_join(
      wasde_milling_lookup,
      by = c(
        "country_join_key",
        "current_commodity" = "commodity",
        "market_year"
      )
    ) %>%
    filter(
      dplyr::if_else(
        .data$scoped_revision_commodity,
        is.na(.data$prior_release_ord) |
          is.na(.data$prior_target_release_ord) |
          .data$prior_release_ord == .data$prior_target_release_ord,
        is.na(.data$prior_release_ord) |
          is.na(.data$current_release_ord) |
          .data$prior_release_ord < .data$current_release_ord
      )
    ) %>%
    mutate(
      has_prior = !is.na(.data$prior_release_ord),
      mapping_rank = ifelse(.data$series_mapping_status == "exact", 2L, 1L),
      prior_release_ord_rank = dplyr::coalesce(.data$prior_release_ord, -1L),
      prior_waob_row_rank = dplyr::coalesce(.data$prior_waob_row_id, -1L),
      candidate_basis = vapply(.data$match_commodity, waob_candidate_basis_label, character(1)),
      candidate_raw_abs_diff = ifelse(
        .data$has_prior,
        abs(.data$current_value_canonical - .data$prior_value_canonical),
        NA_real_
      ),
      candidate_raw_rel_diff = ifelse(
        .data$has_prior,
        .data$candidate_raw_abs_diff / pmax(abs(.data$current_value_canonical), 1),
        NA_real_
      ),
      candidate_diag_cross_basis_value = dplyr::case_when(
        .data$has_prior & .data$candidate_basis == "milled" & !is.na(.data$milling_rate_diagnostic_value) & .data$milling_rate_diagnostic_value > 0 ~ .data$prior_value_canonical / .data$milling_rate_diagnostic_value,
        .data$has_prior & .data$candidate_basis == "rough" & !is.na(.data$milling_rate_diagnostic_value) & .data$milling_rate_diagnostic_value > 0 ~ .data$prior_value_canonical * .data$milling_rate_diagnostic_value,
        TRUE ~ NA_real_
      ),
      candidate_diag_rel_diff = ifelse(
        .data$has_prior & !is.na(.data$candidate_diag_cross_basis_value),
        abs(.data$current_value_canonical - .data$candidate_diag_cross_basis_value) /
          pmax(abs(.data$current_value_canonical), 1),
        NA_real_
      )
    )

  select_prior_candidate_row <- function(candidate_rows) {
    if (nrow(candidate_rows) == 0) {
      return(tibble::tibble())
    }

    first_non_na <- function(values) {
      non_na <- values[!is.na(values)]
      if (length(non_na) == 0) {
        return(NA_real_)
      }
      non_na[[1]]
    }

    rank_by_raw_fit <- function(df) {
      if (nrow(df) == 0) {
        return(df)
      }

      df %>%
        arrange(
          dplyr::coalesce(.data$candidate_raw_rel_diff, Inf),
          dplyr::coalesce(.data$candidate_raw_abs_diff, Inf),
          desc(.data$mapping_rank),
          desc(.data$prior_release_ord_rank),
          desc(.data$prior_waob_row_rank)
        )
    }

    rank_legacy <- function(df) {
      if (nrow(df) == 0) {
        return(df)
      }

      df %>%
        arrange(
          desc(.data$has_prior),
          desc(.data$mapping_rank),
          desc(.data$prior_release_ord_rank),
          desc(.data$prior_waob_row_rank)
        )
    }

    current_row_id <- suppressWarnings(as.integer(candidate_rows$current_row_id[[1]]))
    current_commodity <- trimws(as.character(candidate_rows$current_commodity[[1]]))
    current_metric_id <- trimws(as.character(candidate_rows$current_metric_id[[1]]))
    is_all_rice_row <- identical(current_commodity, "All Rice")
    prefers_rough_on_equal_fit <- current_metric_id %in% c("harvested_acres", "area_harvested", "production", "rough_production", "milling_rate")
    prefers_rough_metric <- current_metric_id %in% c("exports_milled_production", "exports_rough_production")

    available_prior <- candidate_rows %>% filter(.data$has_prior)
    available_basis <- available_prior %>% filter(.data$candidate_basis %in% c("rough", "milled"))
    basis_count <- length(unique(available_basis$candidate_basis))

    rough_best <- rank_by_raw_fit(available_basis %>% filter(.data$candidate_basis == "rough")) %>%
      slice_head(n = 1L)
    milled_best <- rank_by_raw_fit(available_basis %>% filter(.data$candidate_basis == "milled")) %>%
      slice_head(n = 1L)

    rough_rel <- if (nrow(rough_best) == 1) rough_best$candidate_raw_rel_diff[[1]] else NA_real_
    milled_rel <- if (nrow(milled_best) == 1) milled_best$candidate_raw_rel_diff[[1]] else NA_real_
    rough_value <- if (nrow(rough_best) == 1) rough_best$prior_value_canonical[[1]] else NA_real_
    milled_value <- if (nrow(milled_best) == 1) milled_best$prior_value_canonical[[1]] else NA_real_
    rough_diag_rel <- if (nrow(rough_best) == 1) rough_best$candidate_diag_rel_diff[[1]] else NA_real_
    milled_diag_rel <- if (nrow(milled_best) == 1) milled_best$candidate_diag_rel_diff[[1]] else NA_real_

    selected_row <- NULL
    basis_selection_status <- "unmatched"
    candidate_margin <- NA_real_

    if (!is_all_rice_row) {
      legacy_selected <- rank_legacy(candidate_rows) %>% slice_head(n = 1L)
      if (nrow(legacy_selected) == 1 && isTRUE(legacy_selected$has_prior[[1]])) {
        selected_row <- legacy_selected
        basis_selection_status <- "selected_non_all_rice"
      }
      basis_count <- NA_integer_
    } else if (nrow(available_basis) == 0) {
      fallback_selected <- rank_legacy(available_prior) %>% slice_head(n = 1L)
      if (nrow(fallback_selected) == 1) {
        selected_row <- fallback_selected
        basis_selection_status <- "single_candidate"
        basis_count <- 1L
      }
    } else if (basis_count <= 1L) {
      selected_row <- rank_by_raw_fit(available_basis) %>% slice_head(n = 1L)
      basis_selection_status <- "single_candidate"
    } else if (nrow(rough_best) == 1 && nrow(milled_best) == 1 && !is.na(rough_rel) && !is.na(milled_rel)) {
      if (isTRUE(prefers_rough_metric) && nrow(rough_best) == 1) {
        selected_row <- rough_best
        basis_selection_status <- "selected_rough"
        candidate_margin <- if (!is.na(milled_rel) && !is.na(rough_rel)) milled_rel - rough_rel else NA_real_
      } else if (waob_near_equal_numeric(rough_rel, milled_rel)) {
        if (prefers_rough_on_equal_fit) {
          selected_row <- rough_best
          basis_selection_status <- "selected_rough"
          candidate_margin <- 0
        } else {
          basis_selection_status <- "ambiguous"
          candidate_margin <- 0
        }
      } else if (rough_rel < milled_rel) {
        selected_row <- rough_best
        basis_selection_status <- "selected_rough"
        candidate_margin <- milled_rel - rough_rel
      } else {
        selected_row <- milled_best
        basis_selection_status <- "selected_milled"
        candidate_margin <- rough_rel - milled_rel
      }
    } else {
      basis_selection_status <- "ambiguous"
    }

    selected_prior_available <- !is.null(selected_row) && nrow(selected_row) == 1 && isTRUE(selected_row$has_prior[[1]])
    selected_mapping_status <- if (selected_prior_available) selected_row$series_mapping_status[[1]] else if (basis_selection_status == "ambiguous") "ambiguous" else "unmatched"
    selected_mapping_rule <- if (selected_prior_available) selected_row$series_mapping_rule[[1]] else if (basis_selection_status == "ambiguous") "all_rice_raw_fit_not_decisive" else "no_waob_series_match"

    tibble::tibble(
      current_row_id = current_row_id,
      prior_release_year = if (selected_prior_available) selected_row$prior_release_year[[1]] else NA_integer_,
      prior_release_month = if (selected_prior_available) selected_row$prior_release_month[[1]] else NA_integer_,
      prior_release_period = if (selected_prior_available) selected_row$prior_release_period[[1]] else NA_character_,
      prior_release_ord = if (selected_prior_available) selected_row$prior_release_ord[[1]] else NA_integer_,
      prior_release_row_key = if (selected_prior_available) selected_row$prior_release_row_key[[1]] else NA_character_,
      prior_waob_row_id = if (selected_prior_available) selected_row$prior_waob_row_id[[1]] else NA_integer_,
      prior_value_canonical = if (selected_prior_available) selected_row$prior_value_canonical[[1]] else NA_real_,
      matched_waob_pairing_key = if (selected_prior_available) dplyr::coalesce(selected_row$waob_pairing_key[[1]], "") else "",
      waob_report_unit_source = if (selected_prior_available) selected_row$waob_report_unit_source[[1]] else NA_character_,
      waob_last_update_raw = if (selected_prior_available) selected_row$waob_last_update_raw[[1]] else NA_character_,
      waob_psd_last_update_raw = if (selected_prior_available) selected_row$waob_psd_last_update_raw[[1]] else NA_character_,
      series_mapping_status = selected_mapping_status,
      series_mapping_rule = selected_mapping_rule,
      prior_waob_commodity_basis = if (selected_prior_available) selected_row$candidate_basis[[1]] else NA_character_,
      prior_waob_raw_commodity_code = if (selected_prior_available) selected_row$prior_waob_raw_commodity_code[[1]] else NA_character_,
      prior_waob_raw_commodity_name = if (selected_prior_available) selected_row$prior_waob_raw_commodity_name[[1]] else NA_character_,
      prior_waob_basis_candidate_count = if (is_all_rice_row) suppressWarnings(as.integer(basis_count)) else NA_integer_,
      prior_waob_candidate_score = if (selected_prior_available) selected_row$candidate_raw_rel_diff[[1]] else NA_real_,
      prior_waob_candidate_margin = candidate_margin,
      prior_waob_basis_selection_status = basis_selection_status,
      rough_candidate_raw_value = rough_value,
      milled_candidate_raw_value = milled_value,
      rough_candidate_raw_rel_diff = rough_rel,
      milled_candidate_raw_rel_diff = milled_rel,
      rough_candidate_diag_rel_diff = rough_diag_rel,
      milled_candidate_diag_rel_diff = milled_diag_rel,
      milling_rate_diagnostic_value = first_non_na(candidate_rows$milling_rate_diagnostic_value)
    )
  }

  prior_candidates <- bind_rows(
    lapply(
      split(prior_candidates_expanded, prior_candidates_expanded$current_row_id),
      select_prior_candidate_row
    )
  )

  extracted_at_utc <- format(as.POSIXct(Sys.time(), tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")

  out <- current_candidates %>%
    left_join(prior_candidates, by = "current_row_id") %>%
    mutate(
      analysis_month = .data$current_release_month,
      calendar_year = .data$current_release_year,
      calendar_month = .data$current_release_month,
      phase1_status = dplyr::if_else(
        !is.na(.data$prior_release_ord),
        "wasde_current_plus_waob_prior",
        "wasde_current_without_waob_prior"
      ),
      prior_release_available = !is.na(.data$prior_release_ord),
      release_gap_months = waob_release_ord_gap_months(.data$current_release_ord, .data$prior_release_ord),
      prior_waob_basis_selection_status = dplyr::coalesce(.data$prior_waob_basis_selection_status, "unmatched"),
      series_mapping_status = dplyr::coalesce(.data$series_mapping_status, "unmatched"),
      series_mapping_rule = dplyr::coalesce(.data$series_mapping_rule, "no_waob_series_match"),
      waob_pairing_key = dplyr::na_if(dplyr::coalesce(.data$matched_waob_pairing_key, .data$waob_pairing_key), ""),
      waob_report_unit_source = dplyr::coalesce(.data$waob_report_unit_source, "waob_report_unit_truth"),
      waob_last_update_raw = .data$waob_last_update_raw,
      waob_psd_last_update_raw = .data$waob_psd_last_update_raw,
      value_provenance = "wasde_current_value_with_waob_lagged_prior",
      provenance_note = dplyr::case_when(
        .data$prior_release_available ~ "Current value sourced from WASDE current release; prior value sourced from latest WAOB release strictly before current report period.",
        .data$prior_waob_basis_selection_status == "ambiguous" ~ "Current value sourced from WASDE current release; WAOB lagged-prior basis candidates were non-decisive and retained as ambiguous.",
        TRUE ~ "Current value sourced from WASDE current release; no WAOB lagged-prior release matched for this series."
      ),
      extracted_at_utc = extracted_at_utc
    ) %>%
    select(all_of(wasde_revision_delta_required_processed_cols)) %>%
    arrange(.data$market_year, .data$commodity, .data$normalized_metric_id, .data$country)

  assert_dataset_columns(
    out,
    wasde_revision_delta_required_processed_cols,
    "WASDE revision-delta processed artifact"
  )

  out
}

materialize_wasde_historical_records <- function(wasde_data, windows = c(5L, 10L, 20L, NA_integer_), selected_years = NULL) {
  assert_dataset_columns(wasde_data, wasde_required_processed_cols, "wasde_historical_records source")

  long_profiles <- wasde_data %>%
    transmute(
      country = trimws(as.character(.data$country)),
      countryDescription = trimws(as.character(.data$countryDescription)),
      commodity = trimws(as.character(.data$commodity)),
      market_year = suppressWarnings(as.integer(.data$market_year)),
      analysis_month = suppressWarnings(as.integer(.data$analysis_month)),
      release_year = suppressWarnings(as.integer(.data$release_year)),
      release_month = suppressWarnings(as.integer(.data$release_month)),
      release_period = trimws(as.character(.data$release_period)),
      metric_id = trimws(as.character(.data$normalized_metric_id)),
      metric_code = paste0("wasde_", trimws(as.character(.data$normalized_metric_id))),
      metric_class = "value",
      basis_profile = "native",
      analysis_value = suppressWarnings(as.numeric(.data$value_canonical))
    ) %>%
    filter(
      nzchar(.data$country),
      nzchar(.data$commodity),
      nzchar(.data$metric_id),
      !is.na(.data$market_year),
      !is.na(.data$analysis_value),
      is.finite(.data$analysis_value)
    )

  latest_rows <- reduce_psd_latest_market_year_estimates(
    data = long_profiles,
    group_cols = c("country", "commodity", "metric_code", "basis_profile")
  )

  if (nrow(latest_rows) == 0) {
    return(tibble::tibble())
  }

  series_groups <- split(
    latest_rows,
    interaction(
      latest_rows$country,
      latest_rows$commodity,
      latest_rows$metric_code,
      latest_rows$basis_profile,
      drop = TRUE,
      sep = "\r"
    )
  )

  selected_years <- if (is.null(selected_years)) NULL else unique(suppressWarnings(as.integer(selected_years)))
  selected_years <- selected_years[!is.na(selected_years)]

  out <- dplyr::bind_rows(lapply(
    series_groups,
    build_psd_historical_record_rows_for_series,
    windows = windows,
    selected_years = selected_years
  ))

  if (nrow(out) == 0) {
    return(tibble::tibble())
  }

  out %>%
    arrange(
      .data$market_year,
      .data$window_label,
      .data$direction,
      .data$metric_code,
      .data$commodity,
      .data$country
    )
}

export_sales_build_market_week_spine <- function(data,
                                                 market_year_col,
                                                 week_date_col,
                                                 commodity_col = NULL,
                                                 country_col = NULL,
                                                 preferred_commodity = "All Rice",
                                                 preferred_country = "GRAND_TOTAL") {
  empty_spine <- tibble(
    market_year = integer(),
    week_ending_date = as.Date(character()),
    canonical_week_num = integer(),
    spine_source = character()
  )

  if (!is.data.frame(data) || nrow(data) == 0) {
    return(empty_spine)
  }
  if (!(market_year_col %in% names(data)) || !(week_date_col %in% names(data))) {
    return(empty_spine)
  }

  normalized <- tibble(
    market_year = suppressWarnings(as.integer(data[[market_year_col]])),
    week_ending_date = as.Date(data[[week_date_col]]),
    commodity = if (!is.null(commodity_col) && commodity_col %in% names(data)) {
      trimws(as.character(data[[commodity_col]]))
    } else {
      rep(NA_character_, nrow(data))
    },
    country = if (!is.null(country_col) && country_col %in% names(data)) {
      trimws(as.character(data[[country_col]]))
    } else {
      rep(NA_character_, nrow(data))
    }
  ) %>%
    filter(!is.na(.data$market_year), !is.na(.data$week_ending_date))

  if (nrow(normalized) == 0) {
    return(empty_spine)
  }

  preferred_spine <- normalized %>%
    filter(.data$commodity == preferred_commodity, .data$country == preferred_country) %>%
    distinct(.data$market_year, .data$week_ending_date)

  observed_union <- normalized %>%
    distinct(.data$market_year, .data$week_ending_date)

  missing_years <- setdiff(unique(observed_union$market_year), unique(preferred_spine$market_year))

  bind_rows(
    preferred_spine %>% mutate(spine_source = "preferred_world_all_rice"),
    observed_union %>%
      filter(.data$market_year %in% missing_years) %>%
      mutate(spine_source = "observed_union_fallback")
  ) %>%
    arrange(.data$market_year, .data$week_ending_date) %>%
    group_by(.data$market_year) %>%
    mutate(canonical_week_num = as.integer(row_number())) %>%
    ungroup()
}

prepare_export_sales_weekly_data <- function(weekly_path, country_canonical_map) {
  assert_required_columns(weekly_path, required_weekly_source_cols, "weekly_data.csv")

  rice_data_weekly_raw <- read.csv(weekly_path, stringsAsFactors = FALSE, check.names = FALSE)

  assert_dataset_columns(
    rice_data_weekly_raw,
    c("Mkt_yr", "weekEndingDate", "week_num", "commodityName", "countryName"),
    "weekly_data.csv"
  )

  market_week_spine <- export_sales_build_market_week_spine(
    data = rice_data_weekly_raw,
    market_year_col = "Mkt_yr",
    week_date_col = "weekEndingDate",
    commodity_col = "commodityName",
    country_col = "countryName"
  )

  rice_data_weekly_transformed <- rice_data_weekly_raw %>%
    mutate(
      country = trimws(.data$countryName),
      countryDescription = trimws(.data$countryDescription),
      country_source_code = trimws(as.character(.data$country_source_code)),
      commodity = trimws(.data$commodityName),
      market_year = suppressWarnings(as.integer(.data$Mkt_yr)),
      monthlyexports = .data$weeklyExports,
      monthlyexports_rough_eq = .data$weeklyExports_rough_eq,
      ytd_exports = .data$accumulatedExports,
      ytd_exports_rough_eq = .data$accumulatedExports_rough_eq,
      total_commitment = .data$currentMYTotalCommitment,
      total_commitment_rough_eq = .data$currentMYTotalCommitment_rough_eq,
      outstandingSales = .data$outstandingSales,
      outstandingSales_rough_eq = .data$outstandingSales_rough_eq,
      grossNewSales = .data$grossNewSales,
      grossNewSales_rough_eq = .data$grossNewSales_rough_eq,
      currentMYNetSales = .data$currentMYNetSales,
      currentMYNetSales_rough_eq = .data$currentMYNetSales_rough_eq,
      nextMYOutstandingSales = .data$nextMYOutstandingSales,
      nextMYOutstandingSales_rough_eq = .data$nextMYOutstandingSales_rough_eq,
      nextMYNetSales = .data$nextMYNetSales,
      nextMYNetSales_rough_eq = .data$nextMYNetSales_rough_eq,
      raw_week_num = suppressWarnings(as.integer(.data$week_num)),
      week_ending_date = as.Date(.data$weekEndingDate)
    ) %>%
    left_join(
      market_week_spine %>%
        select(market_year, week_ending_date, canonical_week_num),
      by = c("market_year", "week_ending_date")
    ) %>%
    mutate(
      resolved_week_num = dplyr::coalesce(suppressWarnings(as.integer(.data$canonical_week_num)), .data$raw_week_num),
      analysis_month = suppressWarnings(as.integer(pmin(.data$resolved_week_num, 52L)))
    ) %>%
    select(-any_of(c("raw_week_num", "canonical_week_num", "resolved_week_num"))) %>%
    canonicalize_country_dataset("export_sales", country_canonical_map)

  weekly_group_cols <- c("market_year", "analysis_month", "commodity", "country", "countryDescription", "country_source_code")
  weekly_metric_cols <- c(
    "ytd_exports", "ytd_exports_rough_eq", "total_commitment", "total_commitment_rough_eq",
    "outstandingSales", "outstandingSales_rough_eq", "nextMYOutstandingSales", "nextMYOutstandingSales_rough_eq"
  )

  weekly_duplicate_mask <- duplicated(rice_data_weekly_transformed[weekly_group_cols]) |
    duplicated(rice_data_weekly_transformed[weekly_group_cols], fromLast = TRUE)

  rice_data_weekly_singletons <- rice_data_weekly_transformed[!weekly_duplicate_mask, , drop = FALSE] %>%
    transmute(
      market_year, analysis_month, commodity, country, countryDescription, country_source_code,
      country_legacy_code = .data$country_legacy_code,
      countryDescription_legacy = .data$countryDescription_legacy,
      canonical_review_row_id = .data$canonical_review_row_id,
      monthlyexports, monthlyexports_rough_eq, ytd_exports, ytd_exports_rough_eq,
      total_commitment, total_commitment_rough_eq, outstandingSales, outstandingSales_rough_eq,
      grossNewSales, grossNewSales_rough_eq, currentMYNetSales, currentMYNetSales_rough_eq,
      nextMYOutstandingSales, nextMYOutstandingSales_rough_eq, nextMYNetSales, nextMYNetSales_rough_eq,
      week_ending_date,
      all_na_group_flag = is.na(.data$ytd_exports) |
        is.na(.data$total_commitment) |
        is.na(.data$outstandingSales) |
        is.na(.data$nextMYOutstandingSales) |
        is.na(.data$week_ending_date)
    ) %>%
    mutate(across(all_of(weekly_metric_cols), ~ ifelse(is.infinite(.), NA, .)))

  rice_data_weekly_duplicates <- rice_data_weekly_transformed[weekly_duplicate_mask, , drop = FALSE] %>%
    group_by(market_year, analysis_month, commodity, country, countryDescription, country_source_code) %>%
    summarise(
      country_legacy_code = collapse_unique_text(.data$country_legacy_code),
      countryDescription_legacy = collapse_unique_text(.data$countryDescription_legacy),
      canonical_review_row_id = collapse_unique_text(.data$canonical_review_row_id),
      monthlyexports = (sum(monthlyexports, na.rm = TRUE) * (NA_real_ ^ (sum(!is.na(monthlyexports)) == 0))),
      monthlyexports_rough_eq = (sum(monthlyexports_rough_eq, na.rm = TRUE) * (NA_real_ ^ (sum(!is.na(monthlyexports_rough_eq)) == 0))),
      grossNewSales = (sum(grossNewSales, na.rm = TRUE) * (NA_real_ ^ (sum(!is.na(grossNewSales)) == 0))),
      grossNewSales_rough_eq = (sum(grossNewSales_rough_eq, na.rm = TRUE) * (NA_real_ ^ (sum(!is.na(grossNewSales_rough_eq)) == 0))),
      currentMYNetSales = (sum(currentMYNetSales, na.rm = TRUE) * (NA_real_ ^ (sum(!is.na(currentMYNetSales)) == 0))),
      currentMYNetSales_rough_eq = (sum(currentMYNetSales_rough_eq, na.rm = TRUE) * (NA_real_ ^ (sum(!is.na(currentMYNetSales_rough_eq)) == 0))),
      nextMYNetSales = (sum(nextMYNetSales, na.rm = TRUE) * (NA_real_ ^ (sum(!is.na(nextMYNetSales)) == 0))),
      nextMYNetSales_rough_eq = (sum(nextMYNetSales_rough_eq, na.rm = TRUE) * (NA_real_ ^ (sum(!is.na(nextMYNetSales_rough_eq)) == 0))),
      ytd_exports = safe_max_num(ytd_exports),
      ytd_exports_rough_eq = safe_max_num(ytd_exports_rough_eq),
      total_commitment = safe_max_num(total_commitment),
      total_commitment_rough_eq = safe_max_num(total_commitment_rough_eq),
      outstandingSales = safe_max_num(outstandingSales),
      outstandingSales_rough_eq = safe_max_num(outstandingSales_rough_eq),
      nextMYOutstandingSales = safe_max_num(nextMYOutstandingSales),
      nextMYOutstandingSales_rough_eq = safe_max_num(nextMYOutstandingSales_rough_eq),
      week_ending_date = safe_max_date(week_ending_date),
      all_na_group_flag = all(is.na(ytd_exports)) || all(is.na(total_commitment)) || all(is.na(outstandingSales)) || all(is.na(nextMYOutstandingSales)) || all(is.na(week_ending_date)),
      .groups = "drop"
    ) %>%
    mutate(across(all_of(weekly_metric_cols), ~ ifelse(is.infinite(.), NA, .)))

  bind_rows(rice_data_weekly_singletons, rice_data_weekly_duplicates) %>%
    arrange(market_year, analysis_month, commodity, country)
}

export_sales_fiscal_weekly_materializer_version <- function() {
  "export_sales_fiscal_weekly_v3_2026_06_01"
}

export_sales_na_preserving_sum <- function(value) {
  sum(value, na.rm = TRUE) * (NA_real_ ^ (sum(!is.na(value)) == 0))
}

export_sales_na_preserving_cumsum <- function(value) {
  numeric_value <- suppressWarnings(as.numeric(value))
  if (length(numeric_value) == 0) return(numeric_value)
  if (all(is.na(numeric_value))) return(rep(NA_real_, length(numeric_value)))
  cumsum(dplyr::coalesce(numeric_value, 0))
}

export_sales_calendar_month_to_fiscal_year_start <- function(calendar_year, calendar_month) {
  calendar_year_num <- suppressWarnings(as.integer(calendar_year))
  calendar_month_num <- suppressWarnings(as.integer(calendar_month))

  ifelse(
    is.na(calendar_year_num) | is.na(calendar_month_num),
    NA_integer_,
    ifelse(calendar_month_num >= 10L, calendar_year_num, calendar_year_num - 1L)
  )
}

non_psd_monthly_fiscal_materializer_version <- function() {
  "non_psd_monthly_fiscal_v1_2026_05_09"
}

non_psd_monthly_fiscal_analysis_month_to_calendar_month <- function(analysis_month) {
  analysis_month_num <- suppressWarnings(as.integer(analysis_month))

  ifelse(
    is.na(analysis_month_num),
    NA_integer_,
    ifelse(analysis_month_num <= 5L, analysis_month_num + 7L, analysis_month_num - 5L)
  )
}

non_psd_monthly_fiscal_analysis_month_to_calendar_year <- function(market_year, analysis_month) {
  market_year_num <- suppressWarnings(as.integer(market_year))
  calendar_month <- non_psd_monthly_fiscal_analysis_month_to_calendar_month(analysis_month)

  ifelse(
    is.na(market_year_num) | is.na(calendar_month),
    NA_integer_,
    ifelse(calendar_month >= 8L, market_year_num, market_year_num + 1L)
  )
}

non_psd_monthly_fiscal_calendar_month_to_year_start <- function(calendar_year, calendar_month) {
  calendar_year_num <- suppressWarnings(as.integer(calendar_year))
  calendar_month_num <- suppressWarnings(as.integer(calendar_month))

  ifelse(
    is.na(calendar_year_num) | is.na(calendar_month_num),
    NA_integer_,
    ifelse(calendar_month_num >= 10L, calendar_year_num, calendar_year_num - 1L)
  )
}

non_psd_monthly_fiscal_calendar_month_to_period <- function(calendar_month) {
  calendar_month_num <- suppressWarnings(as.integer(calendar_month))

  ifelse(
    is.na(calendar_month_num),
    NA_integer_,
    ifelse(calendar_month_num >= 10L, calendar_month_num - 9L, calendar_month_num + 3L)
  )
}

non_psd_monthly_fiscal_na_preserving_cumsum <- function(value) {
  numeric_value <- suppressWarnings(as.numeric(value))
  if (length(numeric_value) == 0) return(numeric_value)
  if (all(is.na(numeric_value))) return(rep(NA_real_, length(numeric_value)))
  cumsum(dplyr::coalesce(numeric_value, 0))
}

non_psd_monthly_fiscal_group_cols <- function(df) {
  grouping_candidates <- c(
    "source", "frequency", "country", "countryDescription", "country_source_code",
    "country_legacy_code", "countryDescription_legacy", "canonical_review_row_id",
    "commodity", "commodity_group", "hybrid_source_tag", "hybrid_component_source",
    "weekly_data_segment", "market_year"
  )
  group_cols <- intersect(grouping_candidates, names(df))
  if (length(group_cols) == 0) {
    group_cols <- intersect(c("country", "commodity", "market_year"), names(df))
  }

  group_cols
}

materialize_non_psd_monthly_fiscal_data <- function(monthly_data, source_choice = NULL) {
  if (!is.data.frame(monthly_data) || nrow(monthly_data) == 0) {
    return(monthly_data)
  }

  required_cols <- c("market_year", "analysis_month")
  missing_cols <- setdiff(required_cols, names(monthly_data))
  if (length(missing_cols) > 0) {
    stop(
      "Cannot materialize fiscal monthly data; missing columns: ",
      paste(missing_cols, collapse = ", "),
      call. = FALSE
    )
  }

  out <- as_tibble(monthly_data)
  current_market_year <- suppressWarnings(as.integer(out$market_year))
  current_analysis_month <- suppressWarnings(as.integer(out$analysis_month))

  fallback_calendar_month <- non_psd_monthly_fiscal_analysis_month_to_calendar_month(current_analysis_month)
  fallback_calendar_year <- non_psd_monthly_fiscal_analysis_month_to_calendar_year(current_market_year, current_analysis_month)

  existing_calendar_month <- if ("calendar_month" %in% names(out)) {
    suppressWarnings(as.integer(out$calendar_month))
  } else {
    rep(NA_integer_, nrow(out))
  }
  existing_calendar_year <- if ("calendar_year" %in% names(out)) {
    suppressWarnings(as.integer(out$calendar_year))
  } else {
    rep(NA_integer_, nrow(out))
  }

  out$calendar_month <- dplyr::coalesce(existing_calendar_month, fallback_calendar_month)
  out$calendar_year <- dplyr::coalesce(existing_calendar_year, fallback_calendar_year)
  out$market_year <- non_psd_monthly_fiscal_calendar_month_to_year_start(out$calendar_year, out$calendar_month)
  out$analysis_month <- non_psd_monthly_fiscal_calendar_month_to_period(out$calendar_month)

  group_cols <- non_psd_monthly_fiscal_group_cols(out)
  order_cols <- intersect(c("analysis_month", "week_ending_date", "calendar_month"), names(out))
  cumulative_metric_sources <- c(
    ytd_exports = "monthlyexports",
    ytd_exports_rough_eq = "monthlyexports_rough_eq",
    ytd_imports = "monthlyimports",
    ytd_value = "monthlyvalue",
    ytd_value_rough_eq = "monthlyvalue_rough_eq"
  )
  cumulative_targets <- names(cumulative_metric_sources)[
    names(cumulative_metric_sources) %in% names(out) &
      cumulative_metric_sources %in% names(out)
  ]

  if (length(cumulative_targets) > 0 && length(group_cols) > 0 && length(order_cols) > 0) {
    out <- out %>%
      arrange(across(all_of(unique(c(group_cols, order_cols))))) %>%
      group_by(across(all_of(group_cols)))

    for (target_col in cumulative_targets) {
      source_col <- cumulative_metric_sources[[target_col]]
      out <- out %>% mutate(!!target_col := non_psd_monthly_fiscal_na_preserving_cumsum(.data[[source_col]]))
    }

    out <- out %>% ungroup()
  }

  commitment_cols <- intersect(
    c(
      "total_commitment", "total_commitment_rough_eq",
      "outstandingSales", "outstandingSales_rough_eq",
      "grossNewSales", "grossNewSales_rough_eq",
      "currentMYNetSales", "currentMYNetSales_rough_eq",
      "nextMYOutstandingSales", "nextMYOutstandingSales_rough_eq",
      "nextMYNetSales", "nextMYNetSales_rough_eq"
    ),
    names(out)
  )
  if (length(commitment_cols) > 0) {
    for (col_name in commitment_cols) {
      out[[col_name]] <- rep(NA_real_, nrow(out))
    }
  }

  out
}

export_sales_build_fiscal_week_lookup_from_dates <- function(week_ending_date) {
  tibble::tibble(week_ending_date = as.Date(week_ending_date)) %>%
    filter(!is.na(.data$week_ending_date)) %>%
    distinct() %>%
    mutate(
      week_start_date = .data$week_ending_date - lubridate::days(6),
      calendar_year = suppressWarnings(as.integer(lubridate::year(.data$week_ending_date))),
      calendar_month = suppressWarnings(as.integer(lubridate::month(.data$week_ending_date))),
      fiscal_market_year = export_sales_calendar_month_to_fiscal_year_start(.data$calendar_year, .data$calendar_month),
      start_calendar_year = suppressWarnings(as.integer(lubridate::year(.data$week_start_date))),
      start_calendar_month = suppressWarnings(as.integer(lubridate::month(.data$week_start_date))),
      same_calendar_month = .data$start_calendar_month == .data$calendar_month & .data$start_calendar_year == .data$calendar_year,
      current_month_overlap_days = dplyr::if_else(
        .data$same_calendar_month,
        7L,
        7L - as.integer(lubridate::ceiling_date(.data$week_start_date, unit = "month") - .data$week_start_date)
      ),
      current_month_share = .data$current_month_overlap_days / 7
    ) %>%
    arrange(.data$fiscal_market_year, .data$week_ending_date) %>%
    group_by(.data$fiscal_market_year) %>%
    mutate(
      fiscal_analysis_month = dplyr::row_number(),
      fiscal_analysis_month = pmin(.data$fiscal_analysis_month, 52L)
    ) %>%
    ungroup()
}

export_sales_apply_fiscal_boundary_week_adjustment <- function(df, fiscal_week_lookup) {
  if (!is.data.frame(df) || nrow(df) == 0 || !is.data.frame(fiscal_week_lookup) || nrow(fiscal_week_lookup) == 0) {
    return(df)
  }

  boundary_weeks <- fiscal_week_lookup %>%
    filter(
      .data$start_calendar_month == 9L,
      .data$fiscal_analysis_month == 1L,
      !.data$same_calendar_month,
      .data$calendar_month == 10L,
      .data$current_month_share > 0,
      .data$current_month_share < 1
    ) %>%
    transmute(
      next_fiscal_market_year = .data$fiscal_market_year,
      prior_fiscal_market_year = .data$fiscal_market_year - 1L,
      analysis_month = .data$fiscal_analysis_month,
      week_ending_date = .data$week_ending_date,
      retain_share = .data$current_month_share,
      carry_back_share = 1 - .data$current_month_share,
      synthetic_week_ending_date = as.Date(sprintf("%04d-09-30", .data$calendar_year)),
      synthetic_calendar_year = .data$calendar_year
    )

  if (nrow(boundary_weeks) == 0) return(df)

  split_value_cols <- intersect(
    c(
      "monthlyexports",
      "monthlyexports_rough_eq",
      "monthlyimports",
      "monthlyvalue",
      "monthlyvalue_rough_eq",
      "hybrid_quantity_cwt_rough_eq",
      "hybrid_pre_clamp_cwt_rough_eq",
      "final_adjusted_hybrid_cwt_rough_eq",
      "imputation_weight"
    ),
    names(df)
  )

  if (length(split_value_cols) == 0) return(df)

  rows_with_id <- df %>%
    mutate(
      week_ending_date = as.Date(.data$week_ending_date),
      .boundary_row_id = seq_len(n())
    )

  affected_rows <- rows_with_id %>%
    inner_join(
      boundary_weeks,
      by = c("market_year" = "next_fiscal_market_year", "analysis_month", "week_ending_date")
    )

  if (nrow(affected_rows) == 0) return(df)

  retained_rows <- affected_rows %>%
    mutate(across(all_of(split_value_cols), ~ .x * .data$retain_share))

  synthetic_rows <- affected_rows %>%
    mutate(
      market_year = .data$prior_fiscal_market_year,
      analysis_month = 52L,
      week_ending_date = .data$synthetic_week_ending_date,
      calendar_month = 9L,
      calendar_year = .data$synthetic_calendar_year,
      across(all_of(split_value_cols), ~ .x * .data$carry_back_share)
    )

  bind_rows(
    rows_with_id %>% filter(!(.data$.boundary_row_id %in% affected_rows$.boundary_row_id)),
    retained_rows,
    synthetic_rows
  ) %>%
    select(all_of(names(df)))
}

materialize_export_sales_weekly_fiscal_data <- function(weekly_data) {
  if (!is.data.frame(weekly_data) || nrow(weekly_data) == 0) {
    return(weekly_data)
  }

  required_cols <- c("market_year", "analysis_month", "week_ending_date", "commodity", "country", "countryDescription", "country_source_code")
  missing_cols <- setdiff(required_cols, names(weekly_data))
  if (length(missing_cols) > 0) {
    stop(
      "Cannot materialize fiscal Export Sales weekly data; missing columns: ",
      paste(missing_cols, collapse = ", "),
      call. = FALSE
    )
  }

  out <- as_tibble(weekly_data) %>%
    mutate(week_ending_date = as.Date(.data$week_ending_date))

  if (!("calendar_year" %in% names(out))) out$calendar_year <- NA_integer_
  if (!("calendar_month" %in% names(out))) out$calendar_month <- NA_integer_
  if (!("all_na_group_flag" %in% names(out))) out$all_na_group_flag <- FALSE

  observed_spine <- export_sales_build_market_week_spine(
    data = out,
    market_year_col = "market_year",
    week_date_col = "week_ending_date",
    commodity_col = "commodity",
    country_col = "country"
  )

  observed_week_dates <- observed_spine$week_ending_date
  observed_week_dates <- observed_week_dates[!is.na(observed_week_dates)]
  if (length(observed_week_dates) == 0) return(out)

  # Build fiscal lookup over a dense weekly sequence to preserve 52-week fiscal infrastructure.
  week_lookup <- export_sales_build_fiscal_week_lookup_from_dates(
    seq.Date(min(observed_week_dates), max(observed_week_dates), by = "week")
  )

  out <- out %>%
    left_join(
      week_lookup %>%
        transmute(
          week_ending_date,
          fiscal_market_year = .data$fiscal_market_year,
          fiscal_analysis_month = .data$fiscal_analysis_month,
          fiscal_calendar_year = .data$calendar_year,
          fiscal_calendar_month = .data$calendar_month
        ),
      by = "week_ending_date"
    ) %>%
    mutate(
      market_year = dplyr::coalesce(suppressWarnings(as.integer(.data$fiscal_market_year)), suppressWarnings(as.integer(.data$market_year))),
      analysis_month = dplyr::coalesce(suppressWarnings(as.integer(.data$fiscal_analysis_month)), suppressWarnings(as.integer(.data$analysis_month))),
      calendar_year = dplyr::coalesce(suppressWarnings(as.integer(.data$fiscal_calendar_year)), suppressWarnings(as.integer(.data$calendar_year))),
      calendar_month = dplyr::coalesce(suppressWarnings(as.integer(.data$fiscal_calendar_month)), suppressWarnings(as.integer(.data$calendar_month)))
    ) %>%
    select(-any_of(c("fiscal_market_year", "fiscal_analysis_month", "fiscal_calendar_year", "fiscal_calendar_month")))

  out <- export_sales_apply_fiscal_boundary_week_adjustment(out, week_lookup)

  key_cols <- intersect(
    c("market_year", "analysis_month", "commodity", "country", "countryDescription", "country_source_code"),
    names(out)
  )
  series_year_cols <- setdiff(key_cols, "analysis_month")

  text_rollup_cols <- intersect(
    c("country_legacy_code", "countryDescription_legacy", "canonical_review_row_id"),
    names(out)
  )
  flow_cols <- intersect(
    c(
      "monthlyexports", "monthlyexports_rough_eq",
      "grossNewSales", "grossNewSales_rough_eq",
      "currentMYNetSales", "currentMYNetSales_rough_eq",
      "nextMYNetSales", "nextMYNetSales_rough_eq"
    ),
    names(out)
  )
  commitment_cols <- intersect(
    c(
      "total_commitment", "total_commitment_rough_eq",
      "outstandingSales", "outstandingSales_rough_eq",
      "grossNewSales", "grossNewSales_rough_eq",
      "currentMYNetSales", "currentMYNetSales_rough_eq",
      "nextMYOutstandingSales", "nextMYOutstandingSales_rough_eq",
      "nextMYNetSales", "nextMYNetSales_rough_eq"
    ),
    names(out)
  )
  cumulative_metric_sources <- c(
    ytd_exports = "monthlyexports",
    ytd_exports_rough_eq = "monthlyexports_rough_eq"
  )
  cumulative_cols <- intersect(names(cumulative_metric_sources), names(out))
  explicit_numeric_cols <- unique(c(flow_cols, commitment_cols, cumulative_cols))
  other_numeric_cols <- setdiff(
    names(out)[vapply(out, is.numeric, logical(1))],
    unique(c(key_cols, explicit_numeric_cols, "calendar_year", "calendar_month"))
  )
  other_character_cols <- setdiff(
    names(out)[vapply(out, is.character, logical(1))],
    unique(c(key_cols, text_rollup_cols))
  )

  summarised <- out %>%
    group_by(across(all_of(key_cols))) %>%
    summarise(
      across(all_of(text_rollup_cols), collapse_unique_text),
      across(all_of(flow_cols), export_sales_na_preserving_sum),
      across(all_of(setdiff(unique(c(commitment_cols, cumulative_cols)), flow_cols)), safe_max_num),
      across(all_of(other_numeric_cols), safe_max_num),
      across(all_of(other_character_cols), collapse_unique_text),
      week_ending_date = safe_max_date(.data$week_ending_date),
      all_na_group_flag = all(is.na(.data$all_na_group_flag) | .data$all_na_group_flag %in% TRUE),
      .groups = "drop"
    )

  period_lookup <- week_lookup %>%
    transmute(
      market_year = .data$fiscal_market_year,
      analysis_month = .data$fiscal_analysis_month,
      period_week_ending_date = .data$week_ending_date,
      period_calendar_year = .data$calendar_year,
      period_calendar_month = .data$calendar_month
    ) %>%
    group_by(.data$market_year, .data$analysis_month) %>%
    summarise(
      period_week_ending_date = safe_max_date(.data$period_week_ending_date),
      period_calendar_year = suppressWarnings(as.integer(safe_max_num(.data$period_calendar_year))),
      period_calendar_month = suppressWarnings(as.integer(safe_max_num(.data$period_calendar_month))),
      .groups = "drop"
    )

  summarised_period_lookup <- summarised %>%
    distinct(
      .data$market_year,
      .data$analysis_month,
      period_week_ending_date = .data$week_ending_date
    ) %>%
    anti_join(period_lookup, by = c("market_year", "analysis_month")) %>%
    mutate(
      period_calendar_year = suppressWarnings(as.integer(lubridate::year(.data$period_week_ending_date))),
      period_calendar_month = suppressWarnings(as.integer(lubridate::month(.data$period_week_ending_date)))
    )

  if (nrow(summarised_period_lookup) > 0) {
    period_lookup <- bind_rows(period_lookup, summarised_period_lookup) %>%
      arrange(.data$market_year, .data$analysis_month, .data$period_week_ending_date)
  }

  scaffold <- summarised %>%
    distinct(across(all_of(series_year_cols))) %>%
    inner_join(period_lookup, by = "market_year", relationship = "many-to-many")

  completed <- scaffold %>%
    left_join(summarised, by = c(series_year_cols, "analysis_month")) %>%
    mutate(
      week_ending_date = dplyr::coalesce(.data$week_ending_date, .data$period_week_ending_date),
      calendar_year = suppressWarnings(as.integer(.data$period_calendar_year)),
      calendar_month = suppressWarnings(as.integer(.data$period_calendar_month)),
      all_na_group_flag = dplyr::coalesce(.data$all_na_group_flag, TRUE)
    ) %>%
    select(-any_of(c("period_week_ending_date", "period_calendar_year", "period_calendar_month")))

  cumulative_targets <- names(cumulative_metric_sources)[
    names(cumulative_metric_sources) %in% names(completed) & cumulative_metric_sources %in% names(completed)
  ]

  if (length(cumulative_targets) > 0 && length(series_year_cols) > 0) {
    completed <- completed %>%
      arrange(across(all_of(unique(c(series_year_cols, "analysis_month", "week_ending_date"))))) %>%
      group_by(across(all_of(series_year_cols)))

    for (target_col in cumulative_targets) {
      source_col <- cumulative_metric_sources[[target_col]]
      completed <- completed %>% mutate(!!target_col := export_sales_na_preserving_cumsum(.data[[source_col]]))
    }

    completed <- completed %>% ungroup()
  }

  if (length(commitment_cols) > 0) {
    for (col_name in commitment_cols) {
      completed[[col_name]] <- rep(NA_real_, nrow(completed))
    }
  }

  final_cols <- unique(c(names(weekly_data), setdiff(c("calendar_year", "calendar_month"), names(weekly_data))))

  completed %>%
    arrange(.data$market_year, .data$analysis_month, .data$commodity, .data$country) %>%
    select(any_of(final_cols), everything())
}

hybrid_weekly_imputed_fiscal_materializer_version <- function() {
  "hybrid_weekly_imputed_fiscal_v1_2026_05_09"
}

hybrid_fiscal_na_preserving_cumsum <- function(value) {
  numeric_value <- suppressWarnings(as.numeric(value))
  if (length(numeric_value) == 0) return(numeric_value)
  if (all(is.na(numeric_value))) return(rep(NA_real_, length(numeric_value)))
  cumsum(dplyr::coalesce(numeric_value, 0))
}

hybrid_fiscal_calendar_month_to_fiscal_year_start <- function(calendar_year, calendar_month) {
  calendar_year_num <- suppressWarnings(as.integer(calendar_year))
  calendar_month_num <- suppressWarnings(as.integer(calendar_month))

  ifelse(
    is.na(calendar_year_num) | is.na(calendar_month_num),
    NA_integer_,
    ifelse(calendar_month_num >= 10L, calendar_year_num, calendar_year_num - 1L)
  )
}

hybrid_fiscal_build_week_lookup_from_dates <- function(week_ending_date) {
  tibble::tibble(week_ending_date = as.Date(week_ending_date)) %>%
    filter(!is.na(.data$week_ending_date)) %>%
    distinct() %>%
    mutate(
      week_start_date = .data$week_ending_date - lubridate::days(6),
      calendar_year = suppressWarnings(as.integer(lubridate::year(.data$week_ending_date))),
      calendar_month = suppressWarnings(as.integer(lubridate::month(.data$week_ending_date))),
      fiscal_market_year = hybrid_fiscal_calendar_month_to_fiscal_year_start(.data$calendar_year, .data$calendar_month),
      start_calendar_year = suppressWarnings(as.integer(lubridate::year(.data$week_start_date))),
      start_calendar_month = suppressWarnings(as.integer(lubridate::month(.data$week_start_date))),
      same_calendar_month = .data$start_calendar_month == .data$calendar_month & .data$start_calendar_year == .data$calendar_year,
      current_month_overlap_days = dplyr::if_else(
        .data$same_calendar_month,
        7L,
        7L - as.integer(lubridate::ceiling_date(.data$week_start_date, unit = "month") - .data$week_start_date)
      ),
      current_month_share = .data$current_month_overlap_days / 7
    ) %>%
    arrange(.data$fiscal_market_year, .data$week_ending_date) %>%
    group_by(.data$fiscal_market_year) %>%
    mutate(
      fiscal_analysis_month = dplyr::row_number(),
      fiscal_analysis_month = pmin(.data$fiscal_analysis_month, 52L)
    ) %>%
    ungroup()
}

hybrid_fiscal_apply_boundary_week_adjustment <- function(df, fiscal_week_lookup) {
  if (!is.data.frame(df) || nrow(df) == 0 || !is.data.frame(fiscal_week_lookup) || nrow(fiscal_week_lookup) == 0) {
    return(df)
  }

  visible_week_counts <- df %>%
    distinct(.data$market_year, .data$analysis_month, .data$week_ending_date) %>%
    count(.data$market_year, name = "visible_weeks")

  recent_year <- suppressWarnings(max(visible_week_counts$market_year, na.rm = TRUE))
  if (!is.finite(recent_year)) return(df)

  problem_years <- visible_week_counts %>%
    filter(.data$market_year < recent_year, .data$visible_weeks == 51L) %>%
    pull(.data$market_year)

  if (length(problem_years) == 0) return(df)

  boundary_weeks <- fiscal_week_lookup %>%
    filter(
      .data$fiscal_market_year %in% (problem_years + 1L),
      .data$fiscal_analysis_month == 1L,
      !.data$same_calendar_month,
      .data$calendar_month == 10L,
      .data$current_month_share > 0,
      .data$current_month_share < 1
    ) %>%
    transmute(
      next_fiscal_market_year = .data$fiscal_market_year,
      prior_fiscal_market_year = .data$fiscal_market_year - 1L,
      analysis_month = .data$fiscal_analysis_month,
      week_ending_date = .data$week_ending_date,
      retain_share = .data$current_month_share,
      carry_back_share = 1 - .data$current_month_share,
      synthetic_week_ending_date = as.Date(sprintf("%04d-09-30", .data$calendar_year)),
      synthetic_calendar_year = .data$calendar_year
    )

  valid_prior_years <- boundary_weeks %>%
    count(.data$prior_fiscal_market_year, name = "candidate_count") %>%
    filter(.data$candidate_count == 1L) %>%
    pull(.data$prior_fiscal_market_year)

  if (length(valid_prior_years) == 0) return(df)

  boundary_weeks <- boundary_weeks %>%
    filter(.data$prior_fiscal_market_year %in% valid_prior_years)

  split_value_cols <- intersect(
    c(
      "monthlyexports",
      "monthlyexports_rough_eq",
      "monthlyimports",
      "monthlyvalue",
      "monthlyvalue_rough_eq",
      "hybrid_quantity_cwt_rough_eq",
      "hybrid_pre_clamp_cwt_rough_eq",
      "final_adjusted_hybrid_cwt_rough_eq",
      "imputation_weight"
    ),
    names(df)
  )

  if (length(split_value_cols) == 0) return(df)

  rows_with_id <- df %>%
    mutate(
      week_ending_date = as.Date(.data$week_ending_date),
      .boundary_row_id = seq_len(n())
    )

  affected_rows <- rows_with_id %>%
    inner_join(
      boundary_weeks,
      by = c("market_year" = "next_fiscal_market_year", "analysis_month", "week_ending_date")
    )

  if (nrow(affected_rows) == 0) return(df)

  retained_rows <- affected_rows %>%
    mutate(
      splice_boundary_flag = TRUE,
      across(all_of(split_value_cols), ~ .x * .data$retain_share)
    )

  synthetic_rows <- affected_rows %>%
    mutate(
      market_year = .data$prior_fiscal_market_year,
      analysis_month = 52L,
      week_ending_date = .data$synthetic_week_ending_date,
      calendar_month = 9L,
      calendar_year = .data$synthetic_calendar_year,
      splice_boundary_flag = TRUE,
      across(all_of(split_value_cols), ~ .x * .data$carry_back_share)
    )

  if ("monthly_reconciliation_analysis_month" %in% names(synthetic_rows)) {
    synthetic_rows$monthly_reconciliation_analysis_month <- 12L
  }
  if ("monthly_reconciliation_months" %in% names(synthetic_rows)) {
    synthetic_rows$monthly_reconciliation_months <- "12"
  }
  if ("market_month" %in% names(synthetic_rows)) {
    synthetic_rows$market_month <- 12L
  }
  if ("market_month_name" %in% names(synthetic_rows)) {
    synthetic_rows$market_month_name <- "September"
  }

  bind_rows(
    rows_with_id %>% filter(!(.data$.boundary_row_id %in% affected_rows$.boundary_row_id)),
    retained_rows,
    synthetic_rows
  ) %>%
    select(all_of(names(df)))
}

materialize_hybrid_weekly_imputed_fiscal_data <- function(weekly_data) {
  if (!is.data.frame(weekly_data) || nrow(weekly_data) == 0) {
    return(weekly_data)
  }

  required_cols <- c("market_year", "analysis_month", "week_ending_date", "country", "commodity")
  missing_cols <- setdiff(required_cols, names(weekly_data))
  if (length(missing_cols) > 0) {
    stop(
      "Cannot materialize fiscal Hybrid weekly-imputed data; missing columns: ",
      paste(missing_cols, collapse = ", "),
      call. = FALSE
    )
  }

  out <- as_tibble(weekly_data)
  week_dates <- as.Date(out$week_ending_date)
  valid_week_dates <- !is.na(week_dates) & is.finite(as.numeric(week_dates))

  if (any(valid_week_dates)) {
    week_lookup <- hybrid_fiscal_build_week_lookup_from_dates(week_dates[valid_week_dates])

    out <- out %>%
      mutate(week_ending_date = as.Date(.data$week_ending_date)) %>%
      left_join(
        week_lookup %>%
          transmute(
            week_ending_date,
            fiscal_market_year = .data$fiscal_market_year,
            fiscal_analysis_month = .data$fiscal_analysis_month,
            fiscal_calendar_year = .data$calendar_year,
            fiscal_calendar_month = .data$calendar_month
          ),
        by = "week_ending_date"
      )

    out$market_year <- dplyr::coalesce(
      suppressWarnings(as.integer(out$fiscal_market_year)),
      suppressWarnings(as.integer(out$market_year))
    )
    out$analysis_month <- dplyr::coalesce(
      suppressWarnings(as.integer(out$fiscal_analysis_month)),
      suppressWarnings(as.integer(out$analysis_month))
    )

    if ("calendar_year" %in% names(out)) {
      out$calendar_year <- dplyr::coalesce(
        suppressWarnings(as.integer(out$calendar_year)),
        suppressWarnings(as.integer(out$fiscal_calendar_year))
      )
    } else {
      out$calendar_year <- suppressWarnings(as.integer(out$fiscal_calendar_year))
    }

    if ("calendar_month" %in% names(out)) {
      out$calendar_month <- dplyr::coalesce(
        suppressWarnings(as.integer(out$calendar_month)),
        suppressWarnings(as.integer(out$fiscal_calendar_month))
      )
    } else {
      out$calendar_month <- suppressWarnings(as.integer(out$fiscal_calendar_month))
    }

    out$fiscal_market_year <- NULL
    out$fiscal_analysis_month <- NULL
    out$fiscal_calendar_year <- NULL
    out$fiscal_calendar_month <- NULL

    out <- hybrid_fiscal_apply_boundary_week_adjustment(out, week_lookup)
  }

  group_cols <- intersect(c("country", "commodity", "market_year"), names(out))
  order_cols <- intersect(c("analysis_month", "week_ending_date", "calendar_month"), names(out))
  cumulative_metric_sources <- c(
    ytd_exports = "monthlyexports",
    ytd_exports_rough_eq = "monthlyexports_rough_eq",
    ytd_imports = "monthlyimports",
    ytd_value = "monthlyvalue",
    ytd_value_rough_eq = "monthlyvalue_rough_eq"
  )
  cumulative_targets <- names(cumulative_metric_sources)[
    names(cumulative_metric_sources) %in% names(out) & cumulative_metric_sources %in% names(out)
  ]

  if (length(cumulative_targets) > 0 && length(group_cols) > 0 && length(order_cols) > 0) {
    out <- out %>%
      arrange(across(all_of(unique(c(group_cols, order_cols))))) %>%
      group_by(across(all_of(group_cols)))

    for (target_col in cumulative_targets) {
      source_col <- cumulative_metric_sources[[target_col]]
      out <- out %>% mutate(!!target_col := hybrid_fiscal_na_preserving_cumsum(.data[[source_col]]))
    }

    out <- out %>% ungroup()
  }

  commitment_cols <- intersect(
    c(
      "total_commitment", "total_commitment_rough_eq",
      "outstandingSales", "outstandingSales_rough_eq",
      "grossNewSales", "grossNewSales_rough_eq",
      "currentMYNetSales", "currentMYNetSales_rough_eq",
      "nextMYOutstandingSales", "nextMYOutstandingSales_rough_eq",
      "nextMYNetSales", "nextMYNetSales_rough_eq"
    ),
    names(out)
  )
  if (length(commitment_cols) > 0) {
    for (col_name in commitment_cols) {
      out[[col_name]] <- rep(NA_real_, nrow(out))
    }
  }

  out
}