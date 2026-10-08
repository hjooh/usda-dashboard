`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0L) y else x
}

parse_arg_value <- function(args, key, default = NULL) {
  prefix <- paste0("--", key, "=")
  hits <- args[startsWith(args, prefix)]
  if (length(hits) == 0L) return(default)
  sub(prefix, "", hits[[length(hits)]], fixed = TRUE)
}

resolve_repo_root <- function(start_dir = getwd()) {
  start_dir <- normalizePath(start_dir, winslash = "/", mustWork = FALSE)
  candidates <- vapply(0:8, function(level) {
    normalizePath(do.call(file.path, as.list(c(start_dir, rep("..", level)))), winslash = "/", mustWork = FALSE)
  }, character(1))

  for (candidate in unique(candidates)) {
    if (file.exists(file.path(candidate, "VP Clone", ".vp_clone_root"))) {
      return(candidate)
    }
    if (file.exists(file.path(candidate, ".vp_clone_root")) && basename(candidate) == "VP Clone") {
      return(dirname(candidate))
    }
  }

  stop("Could not resolve repository root for VP partition-provider probe.", call. = FALSE)
}

to_int_ms <- function(start_time, end_time = Sys.time()) {
  elapsed_seconds <- suppressWarnings(as.numeric(difftime(end_time, start_time, units = "secs")))
  if (!is.finite(elapsed_seconds)) return(NA_integer_)
  as.integer(round(elapsed_seconds * 1000))
}

safe_first <- function(value, default = NA_character_) {
  if (is.null(value) || length(value) == 0L || is.na(value[[1L]])) return(default)
  value[[1L]]
}

normalize_scalar <- function(value, default = "") {
  candidate <- trimws(as.character(safe_first(value, default = default)))
  if (!nzchar(candidate)) default else candidate
}

normalize_filter_value <- function(value) {
  candidate <- normalize_scalar(value, default = "")
  if (!nzchar(candidate) || identical(candidate, "__all__") || identical(candidate, "<none>")) {
    return(NA_character_)
  }
  candidate
}

valid_cache_states <- c("cold_artifact", "warm_partition_disk", "warm_session", "unknown_cache_state")

normalize_cache_state <- function(value) {
  candidate <- normalize_scalar(value, default = "unknown_cache_state")
  if (!(candidate %in% valid_cache_states)) return("unknown_cache_state")
  candidate
}

partition_hash <- function(values) {
  normalized <- trimws(as.character(values %||% character(0)))
  raw_values <- utf8ToInt(paste(normalized, collapse = "|"))
  if (length(raw_values) == 0L) return("0000000000000000")

  mod1 <- 2147483647
  mod2 <- 2147483629
  h1 <- 0
  h2 <- 0
  for (idx in seq_along(raw_values)) {
    value <- as.numeric(raw_values[[idx]])
    h1 <- (h1 * 131 + value + idx) %% mod1
    h2 <- (h2 * 137 + value + idx * 17) %% mod2
  }

  paste0(sprintf("%08x", as.integer(h1)), sprintf("%08x", as.integer(h2)))
}

partition_cache_key <- function(trade_flow, group_filter, subgroup_filter, market_segment_filter) {
  paste(
    "slice",
    trimws(as.character(trade_flow %||% "")),
    trimws(as.character(group_filter %||% "")),
    trimws(as.character(subgroup_filter %||% "")),
    trimws(as.character(market_segment_filter %||% "")),
    sep = "|"
  )
}

partition_file_name <- function(trade_flow, group_filter, subgroup_filter, market_segment_filter) {
  hash_token <- partition_hash(c(trade_flow, group_filter, subgroup_filter, market_segment_filter))
  paste0("slice__", hash_token, ".rds")
}

partition_file_size <- function(path) {
  info <- file.info(path)
  size <- suppressWarnings(as.numeric(info$size[[1L]]))
  if (is.finite(size)) size else NA_real_
}

file_signature <- function(path) {
  if (!file.exists(path)) return("missing")
  info <- file.info(path)
  file_size <- suppressWarnings(as.numeric(info$size[[1L]]))
  file_hash <- tryCatch(unname(tools::md5sum(path)), error = function(...) NA_character_)
  if (length(file_hash) == 1L && !is.na(file_hash) && nzchar(file_hash) && !is.na(file_size)) {
    return(paste("md5", file_hash, as.character(file_size), sep = "|"))
  }
  paste("hash_unavailable", as.character(file_size), sep = "|")
}

payload_schema_version <- "vp_trade_partition_payload_v1"

manifest_schema_version <- function(provider_version) {
  if (identical(provider_version, "vp_trade_partition_provider_v3")) {
    return("vp_trade_partition_manifest_v3")
  }
  "vp_trade_partition_manifest_v2"
}

source_fingerprint <- function(vp_rows) {
  if (!is.data.frame(vp_rows) || nrow(vp_rows) == 0L) return("empty_source")
  fingerprint_columns <- intersect(
    c("Trade", "Group", "Subgroup", "MarketSegment", "CommodityName", "commodity", "date", "Year", "Month"),
    names(vp_rows)
  )
  if (length(fingerprint_columns) == 0L) fingerprint_columns <- names(vp_rows)[seq_len(min(4L, length(names(vp_rows))))]

  sample_count <- min(257L, nrow(vp_rows))
  sample_rows <- unique(as.integer(round(seq(1L, nrow(vp_rows), length.out = sample_count))))
  sampled_values <- unlist(
    lapply(fingerprint_columns, function(column_name) {
      paste(column_name, trimws(as.character(vp_rows[[column_name]][sample_rows] %||% "")), sep = "=")
    }),
    use.names = FALSE
  )

  partition_hash(c(nrow(vp_rows), ncol(vp_rows), names(vp_rows), sampled_values))
}

source_identity <- function(vp_rows, artifact_path) {
  list(
    source_signature = file_signature(artifact_path),
    source_row_count = if (is.data.frame(vp_rows)) nrow(vp_rows) else NA_integer_,
    source_col_count = if (is.data.frame(vp_rows)) ncol(vp_rows) else NA_integer_,
    source_column_hash = if (is.data.frame(vp_rows)) partition_hash(names(vp_rows)) else "not_data_frame",
    source_row_order_fingerprint = source_fingerprint(vp_rows)
  )
}

atomic_save_rds <- function(object, path, compress = TRUE) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  temp_path <- tempfile(pattern = paste0(basename(path), "__"), tmpdir = dirname(path), fileext = ".tmp")
  save_ok <- tryCatch(
    {
      saveRDS(object, temp_path, compress = compress)
      TRUE
    },
    error = function(...) FALSE
  )
  if (!isTRUE(save_ok)) {
    if (file.exists(temp_path)) unlink(temp_path, force = TRUE)
    return(FALSE)
  }

  if (file.exists(path)) {
    unlink(path, force = TRUE)
  }
  rename_ok <- file.rename(temp_path, path)
  if (!isTRUE(rename_ok)) {
    if (file.exists(temp_path)) unlink(temp_path, force = TRUE)
    return(FALSE)
  }

  TRUE
}

clean_family_values <- function(values) {
  family_values <- trimws(tolower(as.character(values %||% character(0))))
  family_values <- family_values[!is.na(family_values) & nzchar(family_values)]
  unique(family_values[family_values %in% c("liquid", "weight")])
}

volume_metadata_from_rows <- function(partition_rows) {
  if (!is.data.frame(partition_rows) || nrow(partition_rows) == 0L) {
    return(list(unique_volume_families = character(0), volume_family = "unknown", has_mixed_volume_family = FALSE))
  }

  mixed_from_flag <- FALSE
  if ("vp_volume_family_mixed" %in% names(partition_rows)) {
    mixed_flags <- as.logical(partition_rows$vp_volume_family_mixed)
    mixed_flags[is.na(mixed_flags)] <- FALSE
    mixed_from_flag <- any(mixed_flags)
  }

  family_values <- character(0)
  if ("volume_unit_family" %in% names(partition_rows)) {
    family_values <- clean_family_values(partition_rows$volume_unit_family)
  }

  if (isTRUE(mixed_from_flag) && length(family_values) < 2L) {
    volume_family <- "mixed"
  } else if (length(family_values) == 1L) {
    volume_family <- family_values[[1L]]
  } else if (length(family_values) > 1L) {
    volume_family <- "mixed"
  } else {
    volume_family <- "unknown"
  }

  list(
    unique_volume_families = family_values,
    volume_family = volume_family,
    has_mixed_volume_family = isTRUE(mixed_from_flag) || identical(volume_family, "mixed")
  )
}

metadata_subindex <- function(partition_rows, columns) {
  columns <- intersect(columns, names(partition_rows))
  if (!is.data.frame(partition_rows) || nrow(partition_rows) == 0L || length(columns) == 0L) {
    return(list())
  }

  split_key <- do.call(paste, c(partition_rows[columns], sep = "\r"))
  split_rows <- split(seq_len(nrow(partition_rows)), split_key, drop = TRUE)
  out <- lapply(split_rows, function(row_index) {
    rows <- partition_rows[row_index, , drop = FALSE]
    volume_metadata <- volume_metadata_from_rows(rows)
    values <- lapply(columns, function(column_name) trimws(as.character(rows[[column_name]][[1L]] %||% "")))
    names(values) <- columns
    c(
      values,
      list(
        row_count = nrow(rows),
        unique_volume_families = volume_metadata$unique_volume_families,
        volume_family = volume_metadata$volume_family,
        has_mixed_volume_family = volume_metadata$has_mixed_volume_family
      )
    )
  })
  names(out) <- names(split_rows)
  out
}

build_metadata <- function(partition_rows) {
  volume_metadata <- volume_metadata_from_rows(partition_rows)
  list(
    metadata_schema_version = "vp_trade_partition_metadata_v1",
    row_count = if (is.data.frame(partition_rows)) nrow(partition_rows) else 0L,
    col_count = if (is.data.frame(partition_rows)) ncol(partition_rows) else 0L,
    unique_volume_families = volume_metadata$unique_volume_families,
    volume_family = volume_metadata$volume_family,
    has_mixed_volume_family = volume_metadata$has_mixed_volume_family,
    commodity_name_index = metadata_subindex(partition_rows, c("CommodityName")),
    commodity_detail_index = metadata_subindex(partition_rows, c("CommodityName", "commodity")),
    built_at = as.character(Sys.time())
  )
}

partition_manifest_compatible <- function(manifest, provider_version, builder_version, artifact_path) {
  is.list(manifest) &&
    identical(manifest$schema_version %||% NA_character_, manifest_schema_version(provider_version)) &&
    identical(manifest$provider_version %||% NA_character_, provider_version) &&
    identical(manifest$builder_version %||% NA_character_, builder_version) &&
    identical(manifest$source_artifact %||% NA_character_, basename(artifact_path)) &&
    identical(manifest$source_signature %||% NA_character_, file_signature(artifact_path)) &&
    is.list(manifest$entries)
}

partition_manifest_base <- function(provider_version, builder_version, artifact_path) {
  list(
    schema_version = manifest_schema_version(provider_version),
    provider_version = provider_version,
    builder_version = builder_version,
    source_artifact = basename(artifact_path),
    source_signature = file_signature(artifact_path),
    created_at = as.character(Sys.time()),
    updated_at = as.character(Sys.time()),
    entries = list()
  )
}

read_partition_manifest <- function(manifest_path, provider_version, builder_version, artifact_path) {
  if (!file.exists(manifest_path)) {
    return(list(ok = FALSE, reason = "manifest_missing", manifest = partition_manifest_base(provider_version, builder_version, artifact_path)))
  }

  manifest <- tryCatch(readRDS(manifest_path), error = function(error) error)
  if (inherits(manifest, "error")) {
    return(list(ok = FALSE, reason = "manifest_read_error", manifest = partition_manifest_base(provider_version, builder_version, artifact_path)))
  }
  if (!partition_manifest_compatible(manifest, provider_version, builder_version, artifact_path)) {
    return(list(ok = FALSE, reason = "manifest_stale_or_incompatible", manifest = partition_manifest_base(provider_version, builder_version, artifact_path)))
  }

  list(ok = TRUE, reason = "manifest_current", manifest = manifest)
}

write_partition_manifest <- function(manifest, manifest_path) {
  manifest$updated_at <- as.character(Sys.time())
  atomic_save_rds(manifest, manifest_path, compress = TRUE)
}

partition_entry_matches <- function(entry, partition_path, trade_flow, group_filter, subgroup_filter, market_segment_filter) {
  is.list(entry) &&
    identical(entry$file_name %||% NA_character_, basename(partition_path)) &&
    identical(entry$trade_flow %||% NA_character_, trimws(as.character(trade_flow %||% ""))) &&
    identical(entry$group_filter %||% NA_character_, trimws(as.character(group_filter %||% ""))) &&
    identical(entry$subgroup_filter %||% NA_character_, trimws(as.character(subgroup_filter %||% ""))) &&
    identical(entry$market_segment_filter %||% NA_character_, trimws(as.character(market_segment_filter %||% ""))) &&
    file.exists(partition_path) &&
    isTRUE(is.finite(as.numeric(entry$file_size_bytes %||% NA_real_))) &&
    identical(as.numeric(entry$file_size_bytes), partition_file_size(partition_path))
}

partition_rows_match_entry <- function(partition_rows, entry) {
  is.data.frame(partition_rows) &&
    identical(nrow(partition_rows), as.integer(entry$row_count %||% NA_integer_)) &&
    identical(ncol(partition_rows), as.integer(entry$col_count %||% NA_integer_))
}

filter_direct <- function(vp_rows, trade_flow, group_filter, subgroup_filter, market_segment_filter) {
  out <- vp_rows

  if ("Trade" %in% names(out) && !is.null(trade_flow) && nzchar(as.character(trade_flow[[1L]]))) {
    out <- out[out$Trade == as.character(trade_flow[[1L]]), , drop = FALSE]
  }
  if ("Group" %in% names(out) && !is.null(group_filter) && nzchar(as.character(group_filter[[1L]]))) {
    out <- out[out$Group == as.character(group_filter[[1L]]), , drop = FALSE]
  }
  if ("Subgroup" %in% names(out) && !is.null(subgroup_filter) && nzchar(as.character(subgroup_filter[[1L]]))) {
    out <- out[out$Subgroup == as.character(subgroup_filter[[1L]]), , drop = FALSE]
  }
  if ("MarketSegment" %in% names(out) && !is.null(market_segment_filter) && nzchar(as.character(market_segment_filter[[1L]]))) {
    out <- out[out$MarketSegment == as.character(market_segment_filter[[1L]]), , drop = FALSE]
  }

  out
}

filter_indices <- function(vp_rows, trade_flow, group_filter, subgroup_filter, market_segment_filter) {
  row_indices <- seq_len(nrow(vp_rows))

  if ("Trade" %in% names(vp_rows) && !is.null(trade_flow) && nzchar(as.character(trade_flow[[1L]]))) {
    row_indices <- row_indices[vp_rows$Trade[row_indices] == as.character(trade_flow[[1L]])]
  }
  if ("Group" %in% names(vp_rows) && !is.null(group_filter) && nzchar(as.character(group_filter[[1L]]))) {
    row_indices <- row_indices[vp_rows$Group[row_indices] == as.character(group_filter[[1L]])]
  }
  if ("Subgroup" %in% names(vp_rows) && !is.null(subgroup_filter) && nzchar(as.character(subgroup_filter[[1L]]))) {
    row_indices <- row_indices[vp_rows$Subgroup[row_indices] == as.character(subgroup_filter[[1L]])]
  }
  if ("MarketSegment" %in% names(vp_rows) && !is.null(market_segment_filter) && nzchar(as.character(market_segment_filter[[1L]]))) {
    row_indices <- row_indices[vp_rows$MarketSegment[row_indices] == as.character(market_segment_filter[[1L]])]
  }

  as.integer(row_indices)
}

build_payload <- function(row_indices, identity, trade_flow, group_filter, subgroup_filter, market_segment_filter) {
  row_indices <- as.integer(row_indices %||% integer(0))
  list(
    storage_mode = "row_index",
    payload_schema_version = payload_schema_version,
    row_indices = row_indices,
    row_count = length(row_indices),
    source_signature = identity$source_signature %||% NA_character_,
    source_row_count = identity$source_row_count %||% NA_integer_,
    source_col_count = identity$source_col_count %||% NA_integer_,
    source_column_hash = identity$source_column_hash %||% NA_character_,
    source_row_order_fingerprint = identity$source_row_order_fingerprint %||% NA_character_,
    trade_flow = trimws(as.character(trade_flow %||% "")),
    group_filter = trimws(as.character(group_filter %||% "")),
    subgroup_filter = trimws(as.character(subgroup_filter %||% "")),
    market_segment_filter = trimws(as.character(market_segment_filter %||% "")),
    materialized_at = as.character(Sys.time())
  )
}

payload_matches_entry <- function(payload, entry, identity) {
  if (!is.list(payload)) return(list(ok = FALSE, reason = "payload_not_list"))
  if (!identical(payload$storage_mode %||% NA_character_, "row_index")) return(list(ok = FALSE, reason = "payload_storage_mode_mismatch"))
  if (!identical(payload$payload_schema_version %||% NA_character_, payload_schema_version)) return(list(ok = FALSE, reason = "payload_schema_mismatch"))
  if (!identical(entry$storage_mode %||% NA_character_, "row_index")) return(list(ok = FALSE, reason = "entry_storage_mode_mismatch"))
  if (!identical(entry$payload_schema_version %||% NA_character_, payload_schema_version)) return(list(ok = FALSE, reason = "entry_payload_schema_mismatch"))

  row_indices <- payload$row_indices %||% NULL
  if (!is.integer(row_indices)) return(list(ok = FALSE, reason = "payload_indices_not_integer"))
  if (any(is.na(row_indices))) return(list(ok = FALSE, reason = "payload_indices_missing"))
  if (!identical(length(row_indices), as.integer(entry$row_count %||% NA_integer_))) return(list(ok = FALSE, reason = "payload_row_count_mismatch"))
  if (!identical(payload$row_count %||% NA_integer_, length(row_indices))) return(list(ok = FALSE, reason = "payload_index_count_mismatch"))
  if (length(row_indices) > 0L && (min(row_indices) < 1L || max(row_indices) > as.integer(identity$source_row_count %||% NA_integer_))) {
    return(list(ok = FALSE, reason = "payload_index_bounds_mismatch"))
  }

  fields <- c("source_signature", "source_row_count", "source_col_count", "source_column_hash", "source_row_order_fingerprint")
  for (field_name in fields) {
    if (!identical(payload[[field_name]] %||% NULL, identity[[field_name]] %||% NULL)) return(list(ok = FALSE, reason = paste0("payload_", field_name, "_mismatch")))
    if (!identical(entry[[field_name]] %||% NULL, identity[[field_name]] %||% NULL)) return(list(ok = FALSE, reason = paste0("entry_", field_name, "_mismatch")))
  }

  list(ok = TRUE, reason = "payload_current")
}

restore_rows <- function(vp_rows, payload, entry, identity) {
  payload_status <- payload_matches_entry(payload, entry, identity)
  if (!isTRUE(payload_status$ok)) return(list(ok = FALSE, reason = payload_status$reason, rows = NULL))
  rows <- vp_rows[payload$row_indices, , drop = FALSE]
  if (!partition_rows_match_entry(rows, entry)) return(list(ok = FALSE, reason = "restored_rows_entry_mismatch", rows = NULL))
  list(ok = TRUE, reason = "restored_rows_current", rows = rows)
}

build_entry <- function(partition_path,
                        partition_rows,
                        trade_flow,
                        group_filter,
                        subgroup_filter,
                        market_segment_filter,
                        payload = NULL,
                        identity = NULL) {
  if (!is.list(identity)) {
    identity <- list(
      source_signature = NA_character_,
      source_row_count = NA_integer_,
      source_col_count = NA_integer_,
      source_column_hash = NA_character_,
      source_row_order_fingerprint = NA_character_
    )
  }
  list(
    file_name = basename(partition_path),
    file_size_bytes = partition_file_size(partition_path),
    storage_mode = if (is.list(payload)) payload$storage_mode %||% "row_index" else "data_frame",
    payload_schema_version = if (is.list(payload)) payload$payload_schema_version %||% payload_schema_version else NA_character_,
    row_count = nrow(partition_rows),
    col_count = ncol(partition_rows),
    source_signature = identity$source_signature %||% NA_character_,
    source_row_count = identity$source_row_count %||% NA_integer_,
    source_col_count = identity$source_col_count %||% NA_integer_,
    source_column_hash = identity$source_column_hash %||% NA_character_,
    source_row_order_fingerprint = identity$source_row_order_fingerprint %||% NA_character_,
    index_count = if (is.list(payload)) length(payload$row_indices %||% integer(0)) else nrow(partition_rows),
    max_index = if (is.list(payload) && length(payload$row_indices %||% integer(0)) > 0L) max(payload$row_indices) else NA_integer_,
    trade_flow = trimws(as.character(trade_flow %||% "")),
    group_filter = trimws(as.character(group_filter %||% "")),
    subgroup_filter = trimws(as.character(subgroup_filter %||% "")),
    market_segment_filter = trimws(as.character(market_segment_filter %||% "")),
    metadata_schema_version = "vp_trade_partition_metadata_v1",
    metadata = build_metadata(partition_rows),
    materialized_at = as.character(Sys.time())
  )
}

entry_has_metadata <- function(entry) {
  is.list(entry) &&
    identical(entry$metadata_schema_version %||% NA_character_, "vp_trade_partition_metadata_v1") &&
    is.list(entry$metadata) &&
    identical(entry$metadata$metadata_schema_version %||% NA_character_, "vp_trade_partition_metadata_v1")
}

verify_manifest_metadata <- function(partition_rows, entry) {
  if (!entry_has_metadata(entry)) return(FALSE)
  expected <- build_metadata(partition_rows)
  identical(expected$row_count, entry$metadata$row_count) &&
    identical(expected$col_count, entry$metadata$col_count) &&
    identical(sort(expected$unique_volume_families), sort(entry$metadata$unique_volume_families %||% character(0))) &&
    identical(expected$volume_family, entry$metadata$volume_family) &&
    identical(isTRUE(expected$has_mixed_volume_family), isTRUE(entry$metadata$has_mixed_volume_family))
}

select_metadata <- function(metadata, commodity_name = NULL, commodity_detail = NULL) {
  if (!is.list(metadata)) return(NULL)

  normalized_commodity_name <- normalize_filter_value(commodity_name)
  normalized_commodity_detail <- normalize_filter_value(commodity_detail)

  if (!is.null(normalized_commodity_detail) && !is.na(normalized_commodity_detail)) {
    if (is.null(normalized_commodity_name) || is.na(normalized_commodity_name) || !is.list(metadata$commodity_detail_index)) {
      return(NULL)
    }
    detail_key <- paste(normalized_commodity_name, normalized_commodity_detail, sep = "\r")
    detail_metadata <- metadata$commodity_detail_index[[detail_key]]
    return(if (is.list(detail_metadata)) detail_metadata else NULL)
  }

  if (!is.null(normalized_commodity_name) && !is.na(normalized_commodity_name)) {
    if (!is.list(metadata$commodity_name_index)) {
      return(NULL)
    }
    name_metadata <- metadata$commodity_name_index[[normalized_commodity_name]]
    return(if (is.list(name_metadata)) name_metadata else NULL)
  }

  metadata
}

metadata_matches <- function(observed, expected) {
  is.list(observed) &&
    is.list(expected) &&
    identical(as.integer(expected$row_count %||% NA_integer_), as.integer(observed$row_count %||% NA_integer_)) &&
    identical(sort(expected$unique_volume_families %||% character(0)), sort(observed$unique_volume_families %||% character(0))) &&
    identical(expected$volume_family %||% "unknown", observed$volume_family %||% "unknown") &&
    identical(isTRUE(expected$has_mixed_volume_family), isTRUE(observed$has_mixed_volume_family))
}

provider_cache_entry_count <- function(cache_env) {
  length(ls(envir = cache_env, all.names = TRUE))
}

provider_cache_total_rows <- function(cache_env) {
  keys <- ls(envir = cache_env, all.names = TRUE)
  if (length(keys) == 0L) return(0L)
  sum(vapply(keys, function(key) {
    value <- get(key, envir = cache_env, inherits = FALSE)
    if (is.data.frame(value)) nrow(value) else 0L
  }, integer(1L)))
}

provider_cache_size_mb <- function(cache_env) {
  keys <- ls(envir = cache_env, all.names = TRUE)
  if (length(keys) == 0L) return(0)
  total_bytes <- sum(vapply(keys, function(key) {
    as.numeric(utils::object.size(get(key, envir = cache_env, inherits = FALSE)))
  }, numeric(1L)))
  total_bytes / (1024 * 1024)
}

probe_provider_slice <- function(vp_rows,
                                 cache_env,
                                 partition_dir,
                                 v2_partition_dir,
                                 manifest_path,
                                 artifact_path,
                                 provider_version,
                                 builder_version,
                                 scenario,
                                 request_kind,
                                 cache_state,
                                 partition_files_state,
                                 memory_cache_state,
                                 run_index) {
  trade_flow <- normalize_filter_value(scenario$trade_flow[[1L]])
  group_filter <- normalize_filter_value(scenario$group_filter[[1L]])
  subgroup_filter <- normalize_filter_value(scenario$subgroup_filter[[1L]])
  market_segment_filter <- normalize_filter_value(scenario$market_segment_filter[[1L]])
  commodity_name <- normalize_filter_value(scenario$commodity_name[[1L]])
  commodity_detail <- normalize_filter_value(scenario$commodity_detail[[1L]])

  cache_key <- partition_cache_key(trade_flow, group_filter, subgroup_filter, market_segment_filter)
  partition_path <- file.path(partition_dir, partition_file_name(trade_flow, group_filter, subgroup_filter, market_segment_filter))
  v2_partition_path <- file.path(v2_partition_dir, partition_file_name(trade_flow, group_filter, subgroup_filter, market_segment_filter))
  identity <- source_identity(vp_rows, artifact_path)
  start_time <- Sys.time()
  status <- "PASS"
  error_message <- NA_character_
  provider_mode <- NA_character_
  fallback_reason <- NA_character_
  manifest_reason <- NA_character_
  storage_mode <- if (identical(provider_version, "vp_trade_partition_provider_v3")) "row_index" else "data_frame"
  payload <- NULL
  index_count <- NA_integer_
  max_index <- NA_integer_
  v2_full_frame_read_ms <- NA_integer_
  v3_payload_read_ms <- NA_integer_
  reconstruction_ms <- NA_integer_
  row_content_parity <- FALSE
  source_mismatch_refused <- FALSE
  source_mismatch_reason <- NA_character_
  out <- NULL
  full_slice <- NULL
  manifest_entry <- NULL
  metadata <- NULL
  metadata_state <- "metadata_unavailable"
  metadata_definitive <- FALSE
  metadata_parity <- FALSE
  selected_metadata_state <- "metadata_unavailable"
  selected_metadata_definitive <- FALSE
  selected_metadata_parity <- FALSE
  metadata_lookup_ms <- NA_integer_
  full_rows_metadata_ms <- NA_integer_

  tryCatch({
    has_partition_cols <- all(c("Trade", "Group", "Subgroup", "MarketSegment") %in% names(vp_rows))
    if (file.exists(v2_partition_path)) {
      v2_read_start <- Sys.time()
      invisible(tryCatch(readRDS(v2_partition_path), error = function(error) error))
      v2_full_frame_read_ms <- to_int_ms(v2_read_start)
    }

    if (!isTRUE(has_partition_cols)) {
      provider_mode <- "direct_fallback"
      fallback_reason <- "missing_partition_columns"
      out <- filter_direct(vp_rows, trade_flow, group_filter, subgroup_filter, market_segment_filter)
      full_slice <- out
    } else if (exists(cache_key, envir = cache_env, inherits = FALSE)) {
      provider_mode <- "memory_cache"
      out <- get(cache_key, envir = cache_env, inherits = FALSE)
      full_slice <- out
    } else {
      metadata_start <- Sys.time()
      manifest_status <- read_partition_manifest(manifest_path, provider_version, builder_version, artifact_path)
      metadata_lookup_ms <- to_int_ms(metadata_start)
      manifest_reason <- manifest_status$reason
      manifest <- manifest_status$manifest
      manifest_entry <- manifest$entries[[cache_key]]
      if (isTRUE(manifest_status$ok) && partition_entry_matches(manifest_entry, partition_path, trade_flow, group_filter, subgroup_filter, market_segment_filter)) {
        metadata_state <- if (entry_has_metadata(manifest_entry)) "metadata_current" else "metadata_missing"
        metadata <- if (entry_has_metadata(manifest_entry)) manifest_entry$metadata else NULL
      } else {
        metadata_state <- manifest_status$reason %||% "metadata_unavailable"
      }
      provider_mode <- "disk_cache"

      if (isTRUE(manifest_status$ok) && partition_entry_matches(manifest_entry, partition_path, trade_flow, group_filter, subgroup_filter, market_segment_filter)) {
        read_start <- Sys.time()
        payload <- tryCatch(readRDS(partition_path), error = function(error) error)
        v3_payload_read_ms <- to_int_ms(read_start)
        if (inherits(payload, "error")) {
          fallback_reason <- "partition_read_error"
          payload <- NULL
        } else if (identical(provider_version, "vp_trade_partition_provider_v3")) {
          restore_start <- Sys.time()
          restore_status <- restore_rows(vp_rows, payload, manifest_entry, identity)
          reconstruction_ms <- to_int_ms(restore_start)
          if (isTRUE(restore_status$ok)) {
            out <- restore_status$rows
          } else {
            fallback_reason <- restore_status$reason %||% "partition_entry_mismatch"
          }
        } else {
          out <- payload
          if (!partition_rows_match_entry(out, manifest_entry)) {
            fallback_reason <- "partition_entry_mismatch"
            out <- NULL
          }
        }
      } else {
        fallback_reason <- manifest_status$reason %||% "manifest_entry_missing_or_stale"
      }

      if (is.null(out)) {
        provider_mode <- "materialized"
        full_rows_start <- Sys.time()
        row_indices <- filter_indices(vp_rows, trade_flow, group_filter, subgroup_filter, market_segment_filter)
        out <- vp_rows[row_indices, , drop = FALSE]
        payload <- if (identical(provider_version, "vp_trade_partition_provider_v3")) {
          build_payload(row_indices, identity, trade_flow, group_filter, subgroup_filter, market_segment_filter)
        } else {
          out
        }
        full_rows_metadata_ms <- to_int_ms(full_rows_start)
        save_ok <- atomic_save_rds(payload, partition_path, compress = TRUE)
        if (isTRUE(save_ok)) {
          manifest_entry <- build_entry(
            partition_path,
            out,
            trade_flow,
            group_filter,
            subgroup_filter,
            market_segment_filter,
            payload = if (identical(provider_version, "vp_trade_partition_provider_v3")) payload else NULL,
            identity = identity
          )
          manifest$entries[[cache_key]] <- manifest_entry
          write_partition_manifest(manifest, manifest_path)
          metadata <- manifest_entry$metadata
          metadata_state <- "metadata_current"
        } else {
          fallback_reason <- "partition_save_error"
          metadata_state <- "metadata_unavailable"
        }
      }

      full_slice <- out
      if (identical(provider_version, "vp_trade_partition_provider_v3") && is.list(payload) && is.list(manifest_entry)) {
        index_count <- length(payload$row_indices %||% integer(0))
        max_index <- if (index_count > 0L) max(payload$row_indices) else NA_integer_
        mismatched_identity <- identity
        mismatched_identity$source_row_count <- as.integer(identity$source_row_count %||% 0L) + 1L
        mismatch_status <- payload_matches_entry(payload, manifest_entry, mismatched_identity)
        source_mismatch_refused <- !isTRUE(mismatch_status$ok)
        source_mismatch_reason <- mismatch_status$reason %||% NA_character_
      }
      assign(cache_key, out, envir = cache_env)
    }

    if (is.data.frame(full_slice)) {
      direct_slice <- filter_direct(vp_rows, trade_flow, group_filter, subgroup_filter, market_segment_filter)
      row_content_parity <- identical(full_slice, direct_slice)
      if (!isTRUE(row_content_parity)) {
        status <- "FAIL"
        error_message <- "row_content_parity_mismatch"
      }
    }

    if (is.data.frame(full_slice)) {
      if (is.null(metadata) && is.list(manifest_entry) && entry_has_metadata(manifest_entry)) {
        metadata <- manifest_entry$metadata
        metadata_state <- "metadata_current"
      }
      if (is.list(metadata)) {
        metadata_definitive <- length(metadata$unique_volume_families %||% character(0)) == 1L
        metadata_parity <- verify_manifest_metadata(full_slice, list(metadata_schema_version = "vp_trade_partition_metadata_v1", metadata = metadata))
        if (is.na(full_rows_metadata_ms)) {
          full_rows_start <- Sys.time()
          invisible(build_metadata(full_slice))
          full_rows_metadata_ms <- to_int_ms(full_rows_start)
        }
      }
    }

    if (!is.null(commodity_name) && !is.na(commodity_name) && "CommodityName" %in% names(out)) {
      out <- out[out$CommodityName == commodity_name, , drop = FALSE]
    }
    if (!is.null(commodity_detail) && !is.na(commodity_detail) && "commodity" %in% names(out)) {
      out <- out[out$commodity == commodity_detail, , drop = FALSE]
    }
  }, error = function(error) {
    status <<- "FAIL"
    error_message <<- conditionMessage(error)
  })

  elapsed_ms <- to_int_ms(start_time)
  partition_info <- if (file.exists(partition_path)) file.info(partition_path) else NULL
  manifest_info <- if (file.exists(manifest_path)) file.info(manifest_path) else NULL
  full_metadata <- NULL
  if (is.data.frame(full_slice)) {
    full_rows_start <- Sys.time()
    full_metadata <- build_metadata(full_slice)
    if (is.na(full_rows_metadata_ms)) {
      full_rows_metadata_ms <- to_int_ms(full_rows_start)
    }
  }
  if (!is.list(metadata) && is.list(full_metadata)) {
    metadata <- full_metadata
    metadata_state <- if (identical(provider_mode, "memory_cache")) "metadata_from_memory_cache" else "metadata_from_full_rows"
    metadata_definitive <- length(metadata$unique_volume_families %||% character(0)) == 1L
    metadata_parity <- TRUE
  }
  if (is.list(metadata) && !isTRUE(metadata_parity)) {
    status <- "FAIL"
    error_message <- "metadata_parity_mismatch"
  }
  metadata_unique_families <- if (is.list(metadata)) metadata$unique_volume_families %||% character(0) else character(0)
  full_unique_families <- if (is.list(full_metadata)) full_metadata$unique_volume_families %||% character(0) else character(0)
  selected_metadata <- if (is.list(metadata)) select_metadata(metadata, commodity_name = commodity_name, commodity_detail = commodity_detail) else NULL
  selected_full_rows <- full_slice
  if (is.data.frame(selected_full_rows) && !is.null(commodity_name) && !is.na(commodity_name) && "CommodityName" %in% names(selected_full_rows)) {
    selected_full_rows <- selected_full_rows[selected_full_rows$CommodityName == commodity_name, , drop = FALSE]
  }
  if (is.data.frame(selected_full_rows) && !is.null(commodity_detail) && !is.na(commodity_detail) && "commodity" %in% names(selected_full_rows)) {
    selected_full_rows <- selected_full_rows[selected_full_rows$commodity == commodity_detail, , drop = FALSE]
  }
  selected_full_metadata <- if (is.data.frame(selected_full_rows)) build_metadata(selected_full_rows) else NULL
  if (is.list(selected_metadata)) {
    selected_metadata_state <- "metadata_current"
    selected_metadata_definitive <- length(selected_metadata$unique_volume_families %||% character(0)) == 1L
    selected_metadata_parity <- metadata_matches(selected_metadata, selected_full_metadata)
  } else if (is.data.frame(selected_full_rows) && nrow(selected_full_rows) == 0L) {
    selected_metadata_state <- "metadata_insufficient_empty_selection"
    selected_metadata_parity <- TRUE
  } else if (is.list(metadata)) {
    selected_metadata_state <- "metadata_insufficient"
  }
  if (is.list(selected_metadata) && !isTRUE(selected_metadata_parity)) {
    status <- "FAIL"
    error_message <- "selected_metadata_parity_mismatch"
  }
  if (identical(provider_version, "vp_trade_partition_provider_v3") && provider_mode %in% c("disk_cache", "materialized") && !isTRUE(source_mismatch_refused)) {
    status <- "FAIL"
    error_message <- "source_mismatch_refusal_missing"
  }
  selected_metadata_unique_families <- if (is.list(selected_metadata)) selected_metadata$unique_volume_families %||% character(0) else character(0)
  selected_full_unique_families <- if (is.list(selected_full_metadata)) selected_full_metadata$unique_volume_families %||% character(0) else character(0)

  data.frame(
    label = normalize_scalar(scenario$scenario[[1L]], default = "provider_slice"),
    timestamp = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    run_index = run_index,
    cache_state = cache_state,
    request_kind = request_kind,
    provider_mode = provider_mode,
    fallback_reason = fallback_reason,
    manifest_reason = manifest_reason,
    storage_mode = storage_mode,
    payload_schema_version = if (identical(provider_version, "vp_trade_partition_provider_v3")) payload_schema_version else NA_character_,
    source_eligible = TRUE,
    source_signature = identity$source_signature %||% NA_character_,
    source_row_count = identity$source_row_count %||% NA_integer_,
    source_col_count = identity$source_col_count %||% NA_integer_,
    source_column_hash = identity$source_column_hash %||% NA_character_,
    source_row_order_fingerprint = identity$source_row_order_fingerprint %||% NA_character_,
    index_count = index_count,
    max_index = max_index,
    v2_full_frame_read_ms = v2_full_frame_read_ms,
    v3_payload_read_ms = v3_payload_read_ms,
    reconstruction_ms = reconstruction_ms,
    row_content_parity = isTRUE(row_content_parity),
    source_mismatch_refused = isTRUE(source_mismatch_refused),
    source_mismatch_reason = source_mismatch_reason,
    metadata_state = metadata_state,
    metadata_definitive = isTRUE(metadata_definitive),
    metadata_parity = isTRUE(metadata_parity),
    metadata_lookup_ms = metadata_lookup_ms,
    full_rows_metadata_ms = full_rows_metadata_ms,
    selected_metadata_state = selected_metadata_state,
    selected_metadata_definitive = isTRUE(selected_metadata_definitive),
    selected_metadata_parity = isTRUE(selected_metadata_parity),
    unique_volume_families_metadata = paste(metadata_unique_families, collapse = "|"),
    unique_volume_families_full = paste(full_unique_families, collapse = "|"),
    unique_volume_families_selected_metadata = paste(selected_metadata_unique_families, collapse = "|"),
    unique_volume_families_selected_full = paste(selected_full_unique_families, collapse = "|"),
    volume_family_metadata = if (is.list(metadata)) metadata$volume_family %||% "unknown" else "unknown",
    volume_family_full = if (is.list(full_metadata)) full_metadata$volume_family %||% "unknown" else "unknown",
    volume_family_selected_metadata = if (is.list(selected_metadata)) selected_metadata$volume_family %||% "unknown" else "unknown",
    volume_family_selected_full = if (is.list(selected_full_metadata)) selected_full_metadata$volume_family %||% "unknown" else "unknown",
    has_mixed_metadata = if (is.list(metadata)) isTRUE(metadata$has_mixed_volume_family) else NA,
    has_mixed_full = if (is.list(full_metadata)) isTRUE(full_metadata$has_mixed_volume_family) else NA,
    has_mixed_selected_metadata = if (is.list(selected_metadata)) isTRUE(selected_metadata$has_mixed_volume_family) else NA,
    has_mixed_selected_full = if (is.list(selected_full_metadata)) isTRUE(selected_full_metadata$has_mixed_volume_family) else NA,
    elapsed_ms = elapsed_ms,
    elapsed_seconds = if (!is.na(elapsed_ms)) elapsed_ms / 1000 else NA_real_,
    rows = if (is.data.frame(out)) nrow(out) else NA_integer_,
    cols = if (is.data.frame(out)) ncol(out) else NA_integer_,
    full_slice_rows = if (is.data.frame(full_slice)) nrow(full_slice) else NA_integer_,
    full_slice_cols = if (is.data.frame(full_slice)) ncol(full_slice) else NA_integer_,
    selected_rows = if (is.data.frame(selected_full_rows)) nrow(selected_full_rows) else NA_integer_,
    partition_file = basename(partition_path),
    partition_file_exists = file.exists(partition_path),
    partition_file_size_mb = if (!is.null(partition_info)) as.numeric(partition_info$size) / (1024 * 1024) else NA_real_,
    manifest_size_mb = if (!is.null(manifest_info)) as.numeric(manifest_info$size) / (1024 * 1024) else NA_real_,
    metadata_size_mb = if (is.list(metadata)) as.numeric(utils::object.size(metadata)) / (1024 * 1024) else NA_real_,
    heavy_slice = is.data.frame(full_slice) && nrow(full_slice) > 100000L,
    trade_flow = trade_flow,
    group_filter = group_filter,
    subgroup_filter = subgroup_filter,
    market_segment_filter = market_segment_filter,
    commodity_name = commodity_name,
    commodity_detail = commodity_detail,
    filter_purpose = normalize_scalar(scenario$filter_purpose[[1L]], default = "provider_probe"),
    active_tab = normalize_scalar(scenario$active_tab[[1L]], default = "provider_probe"),
    source = normalize_scalar(scenario$source[[1L]], default = "vp_trade"),
    resolution_mode = normalize_scalar(scenario$resolution_mode[[1L]], default = "provider_probe"),
    strict_rollup_context = isTRUE(scenario$strict_rollup_context[[1L]]),
    sparse_selection = isTRUE(scenario$sparse_selection[[1L]]),
    path_name = normalize_scalar(scenario$path_name[[1L]], default = "provider_probe"),
    partition_files_state = partition_files_state,
    memory_cache_state = memory_cache_state,
    provider_cache_entry_count = provider_cache_entry_count(cache_env),
    provider_cache_total_rows = provider_cache_total_rows(cache_env),
    provider_cache_size_mb = provider_cache_size_mb(cache_env),
    status = status,
    error_message = error_message,
    stringsAsFactors = FALSE
  )
}

pick_default_scenario <- function(vp_rows) {
  required <- c("Trade", "Group", "Subgroup", "MarketSegment")
  missing <- setdiff(required, names(vp_rows))
  if (length(missing) > 0L) {
    stop(sprintf("Artifact missing required provider columns: %s", paste(missing, collapse = ", ")), call. = FALSE)
  }

  trade_values <- trimws(as.character(vp_rows$Trade %||% ""))
  group_values <- trimws(as.character(vp_rows$Group %||% ""))
  subgroup_values <- trimws(as.character(vp_rows$Subgroup %||% ""))
  segment_values <- trimws(as.character(vp_rows$MarketSegment %||% ""))
  commodity_name_values <- if ("CommodityName" %in% names(vp_rows)) trimws(as.character(vp_rows$CommodityName)) else rep("", nrow(vp_rows))
  commodity_detail_values <- if ("commodity" %in% names(vp_rows)) trimws(as.character(vp_rows$commodity)) else rep("", nrow(vp_rows))

  valid <- nzchar(trade_values) & nzchar(group_values) & nzchar(subgroup_values) & nzchar(segment_values)
  preferred <- which(valid & tolower(trade_values) == "import")
  if (length(preferred) == 0L) preferred <- which(valid)
  if (length(preferred) == 0L) stop("No valid provider scenario found in artifact.", call. = FALSE)

  index <- preferred[[1L]]
  data.frame(
    scenario = "default_provider_slice",
    trade_flow = trade_values[[index]],
    group_filter = group_values[[index]],
    subgroup_filter = subgroup_values[[index]],
    market_segment_filter = segment_values[[index]],
    commodity_name = commodity_name_values[[index]],
    commodity_detail = commodity_detail_values[[index]],
    filter_purpose = "provider_probe",
    active_tab = "provider_probe",
    source = "vp_trade",
    resolution_mode = "provider_probe",
    strict_rollup_context = FALSE,
    sparse_selection = FALSE,
    path_name = "provider_probe",
    stringsAsFactors = FALSE
  )
}

step6_disk_hit_scenarios <- function() {
  data.frame(
    scenario = c(
      "step6_export_rollup_mixed_check",
      "step6_import_rollup_artichokes_mixed_check",
      "step6_import_dry_pulses_artichokes_mixed_check",
      "step6_import_dried_beans_austrian_winter_peas_mixed_check",
      "step6_import_dried_bambara_beans_mixed_check"
    ),
    trade_flow = c("export", "import", "import", "import", "import"),
    group_filter = c("__vp_rollup_all_group__", "__vp_rollup_all_group__", "Dry pulses", "Dry pulses", "Dry pulses"),
    subgroup_filter = c("__vp_rollup_all_subgroup__", "__vp_rollup_all_subgroup__", "__vp_rollup_all_subgroup__", "Dried beans", "Dried beans"),
    market_segment_filter = c("__vp_rollup_all_market_segment__", "__vp_rollup_all_market_segment__", "__vp_rollup_all_market_segment__", "__vp_rollup_all_market_segment__", "Dried"),
    commodity_name = c(NA_character_, "Artichokes", "Artichokes", "Austrian winter peas", "Bambara beans"),
    commodity_detail = c(NA_character_, NA_character_, NA_character_, NA_character_, "All"),
    filter_purpose = "mixed_volume_family_check",
    active_tab = c("unknown", "Current vs. Average", "Current vs. Average", "Current vs. Average", "Current vs. Average"),
    source = "vp_trade",
    resolution_mode = "provider_probe",
    strict_rollup_context = TRUE,
    sparse_selection = FALSE,
    path_name = c("P3_group_all", "P3_group_all", "P3_group", "P3_subgroup", "P3_market_segment"),
    stringsAsFactors = FALSE
  )
}

build_scenario <- function(args, vp_rows) {
  scenario_set_arg <- trimws(as.character(parse_arg_value(args, "scenario-set", default = "")))
  if (identical(scenario_set_arg, "step6_disk_hit_slices")) {
    return(step6_disk_hit_scenarios())
  }

  scenario_arg <- trimws(as.character(parse_arg_value(args, "scenario", default = "")))
  if (!nzchar(scenario_arg)) return(pick_default_scenario(vp_rows))

  parts <- strsplit(scenario_arg, "\\|", fixed = FALSE)[[1L]]
  parts <- c(parts, rep("", max(0L, 7L - length(parts))))
  data.frame(
    scenario = parts[[1L]] %||% "custom_provider_slice",
    trade_flow = normalize_filter_value(parts[[2L]]),
    group_filter = normalize_filter_value(parts[[3L]]),
    subgroup_filter = normalize_filter_value(parts[[4L]]),
    market_segment_filter = normalize_filter_value(parts[[5L]]),
    commodity_name = normalize_filter_value(parts[[6L]]),
    commodity_detail = normalize_filter_value(parts[[7L]]),
    filter_purpose = "provider_probe",
    active_tab = "provider_probe",
    source = "vp_trade",
    resolution_mode = "provider_probe",
    strict_rollup_context = FALSE,
    sparse_selection = FALSE,
    path_name = "provider_probe",
    stringsAsFactors = FALSE
  )
}

main <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  repo_root <- resolve_repo_root(getwd())
  vp_clone_dir <- file.path(repo_root, "VP Clone")
  logs_dir <- file.path(vp_clone_dir, "Logs")
  dir.create(logs_dir, recursive = TRUE, showWarnings = FALSE)

  label <- normalize_scalar(parse_arg_value(args, "label", default = "partition_provider"), default = "partition_provider")
  request_kind <- normalize_scalar(parse_arg_value(args, "request-kind", default = "probe"), default = "probe")
  cache_state <- normalize_cache_state(parse_arg_value(args, "cache-state", default = "warm_partition_disk"))
  runs <- suppressWarnings(as.integer(parse_arg_value(args, "runs", default = "2")))
  if (!is.finite(runs) || is.na(runs) || runs < 1L) runs <- 2L

  artifact_path <- normalizePath(
    parse_arg_value(args, "artifact", default = file.path(vp_clone_dir, "System", "Processed Data", "vp_trade_monthly_pre.rds")),
    winslash = "/",
    mustWork = FALSE
  )
  builder_version <- normalize_scalar(parse_arg_value(args, "builder-version", default = "vp_trade_artifact_2026_07_28_v6"), default = "vp_trade_artifact_2026_07_28_v6")
  provider_version <- normalize_scalar(parse_arg_value(args, "provider-version", default = "vp_trade_partition_provider_v3"), default = "vp_trade_partition_provider_v3")
  v2_provider_version <- normalize_scalar(parse_arg_value(args, "v2-provider-version", default = "vp_trade_partition_provider_v2"), default = "vp_trade_partition_provider_v2")
  partition_dir <- normalizePath(
    parse_arg_value(args, "partition-dir", default = file.path(vp_clone_dir, "System", "Processed Data", "vp_trade_partitions", provider_version, builder_version)),
    winslash = "/",
    mustWork = FALSE
  )
  v2_partition_dir <- normalizePath(
    parse_arg_value(args, "v2-partition-dir", default = file.path(vp_clone_dir, "System", "Processed Data", "vp_trade_partitions", v2_provider_version, builder_version)),
    winslash = "/",
    mustWork = FALSE
  )
  manifest_path <- file.path(partition_dir, "vp_trade_partition_manifest.rds")

  timestamp_token <- format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC")
  raw_path <- file.path(logs_dir, paste0("vp_perf_probe_partition_provider_", label, "_", timestamp_token, ".csv"))

  cat("VP_PERF_PARTITION_PROVIDER_PROBE_START\n")
  cat(sprintf("VP_PERF_PARTITION_PROVIDER_LABEL=%s\n", label))
  cat(sprintf("VP_PERF_PARTITION_PROVIDER_CACHE_STATE=%s\n", cache_state))
  cat(sprintf("VP_PERF_PARTITION_PROVIDER_REQUEST_KIND=%s\n", request_kind))
  cat(sprintf("VP_PERF_PARTITION_PROVIDER_RUNS=%d\n", runs))

  load_start <- Sys.time()
  vp_rows <- readRDS(artifact_path)
  artifact_load_ms <- to_int_ms(load_start)
  scenarios <- build_scenario(args, vp_rows)
  cache_env <- new.env(parent = emptyenv())

  partition_files_state <- if (file.exists(manifest_path)) "manifest_present" else "manifest_missing"
  memory_cache_state <- "empty"
  cat(sprintf("VP_PERF_PARTITION_PROVIDER_ARTIFACT_LOAD_MS=%s\n", artifact_load_ms))
  cat(sprintf("VP_PERF_PARTITION_PROVIDER_SCENARIO_COUNT=%d\n", nrow(scenarios)))
  cat(sprintf("VP_PERF_PARTITION_PROVIDER_SCENARIO=%s\n", paste(scenarios$scenario, collapse = ",")))

  rows <- unlist(lapply(seq_len(nrow(scenarios)), function(scenario_index) {
    scenario <- scenarios[scenario_index, , drop = FALSE]
    lapply(seq_len(runs), function(run_index) {
      if (identical(cache_state, "warm_partition_disk") && run_index == 1L) {
        rm(list = ls(envir = cache_env, all.names = TRUE), envir = cache_env)
        memory_cache_state <<- "cleared_before_run"
      } else {
        memory_cache_state <<- if (provider_cache_entry_count(cache_env) > 0L) "preserved" else "empty"
      }

      cat(sprintf("VP_PERF_PARTITION_PROVIDER_RUN_BEGIN=%s|%d\n", scenario$scenario[[1L]], run_index))
      row <- probe_provider_slice(
        vp_rows = vp_rows,
        cache_env = cache_env,
        partition_dir = partition_dir,
        v2_partition_dir = v2_partition_dir,
        manifest_path = manifest_path,
        artifact_path = artifact_path,
        provider_version = provider_version,
        builder_version = builder_version,
        scenario = scenario,
        request_kind = request_kind,
        cache_state = if (run_index == 1L) cache_state else "warm_session",
        partition_files_state = partition_files_state,
        memory_cache_state = memory_cache_state,
        run_index = run_index
      )
      cat(sprintf(
        "VP_PERF_PARTITION_PROVIDER_RUN_STATUS=%s|%d|%s|mode=%s|%sms|rows=%s\n",
        scenario$scenario[[1L]],
        run_index,
        row$status[[1L]],
        row$provider_mode[[1L]],
        row$elapsed_ms[[1L]],
        row$rows[[1L]]
      ))
      if (identical(row$status[[1L]], "FAIL")) {
        cat(sprintf("VP_PERF_PARTITION_PROVIDER_RUN_ERROR=%s|%d|%s\n", scenario$scenario[[1L]], run_index, row$error_message[[1L]]))
      }
      row
    })
  }), recursive = FALSE)

  raw_df <- do.call(rbind, rows)
  raw_df$artifact_load_elapsed_ms <- artifact_load_ms
  raw_df$artifact_path <- artifact_path
  raw_df$partition_dir <- partition_dir
  raw_df$v2_partition_dir <- v2_partition_dir
  raw_df$manifest_path <- manifest_path
  utils::write.csv(raw_df, raw_path, row.names = FALSE)

  status <- if (all(identical(raw_df$status, rep("PASS", nrow(raw_df))))) "PASS" else "FAIL"
  cat(sprintf("VP_PERF_PARTITION_PROVIDER_OUTPUT=%s\n", normalizePath(raw_path, winslash = "/", mustWork = FALSE)))
  cat(sprintf("VP_PERF_PARTITION_PROVIDER_STATUS=%s\n", status))
  cat("VP_PERF_PARTITION_PROVIDER_PROBE_COMPLETE\n")
}

main()
