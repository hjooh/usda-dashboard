`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0L) y else x
}

resolve_repo_root <- function(start_dir = getwd()) {
  start_dir <- normalizePath(start_dir, winslash = "/", mustWork = FALSE)
  candidates <- unique(c(
    start_dir,
    vapply(1:8, function(level) normalizePath(file.path(start_dir, paste(rep("..", level), collapse = "/")), winslash = "/", mustWork = FALSE), character(1))
  ))

  for (candidate in candidates) {
    if (file.exists(file.path(candidate, ".vp_clone_root"))) {
      return(candidate)
    }
  }

  stop("Could not resolve FTN repository root (.vp_clone_root missing).", call. = FALSE)
}

first_non_empty <- function(values, default = "") {
  values <- trimws(as.character(values %||% character(0)))
  values <- values[!is.na(values) & nzchar(values)]
  if (length(values) == 0L) default else values[[1L]]
}

repo_root <- resolve_repo_root()
source(file.path(repo_root, "Programs", "vp_data_utils.R"), local = FALSE)
source(file.path(repo_root, "Programs", "shared_core", "commodity_contract_utils.R"), local = FALSE)
source(file.path(repo_root, "System", "Config", "vp_contract.R"), local = FALSE)

contract <- get_commodity_contract(repo_root)
app_ui_metadata_path <- contract_artifact_path(contract, "app_ui_metadata", repo_root)
paths <- vp_paths(repo_root)
required_files <- c(paths$artifact, paths$metadata, app_ui_metadata_path)
missing_files <- required_files[!file.exists(required_files)]
if (length(missing_files) > 0L) {
  stop(
    paste0(
      "Missing required FTN artifacts: ",
      paste(missing_files, collapse = " | "),
      ". Run Master_FTN.R with VP_MASTER_UPDATES=vp_trade,metadata first."
    ),
    call. = FALSE
  )
}

artifact_object <- readRDS(paths$artifact)
metadata_object <- readRDS(paths$metadata)
app_ui_metadata_object <- readRDS(app_ui_metadata_path)

artifact_data <- if (is.data.frame(artifact_object)) {
  artifact_object
} else if (is.list(artifact_object) && is.data.frame(artifact_object$data)) {
  artifact_object$data
} else {
  data.frame()
}

artifact_inline_metadata <- if (is.list(artifact_object)) artifact_object$metadata else NULL
source_signature_current <- vp_signature_string(vp_file_signature(paths$input_csv))
source_signature_artifact <- first_non_empty(c(
  artifact_inline_metadata$source_signature_string,
  metadata_object$source_signature_string
))
source_signature_metadata <- first_non_empty(metadata_object$source_signature_string)

if (!identical(source_signature_artifact, source_signature_current)) {
  stop(
    sprintf(
      "Artifact source signature mismatch. Expected %s; got %s.",
      source_signature_current,
      source_signature_artifact
    ),
    call. = FALSE
  )
}

if (!identical(source_signature_metadata, source_signature_current)) {
  stop(
    sprintf(
      "Metadata source signature mismatch. Expected %s; got %s.",
      source_signature_current,
      source_signature_metadata
    ),
    call. = FALSE
  )
}

if (!is.data.frame(artifact_data) || nrow(artifact_data) == 0L) {
  stop("FTN artifact has no rows.", call. = FALSE)
}

month_column <- first_non_empty(metadata_object$month_column)
if (!(month_column %in% c("MonthNum", "MonthNumber"))) {
  stop(sprintf("Unexpected month column in metadata: %s", month_column), call. = FALSE)
}

calendars <- metadata_object$calendars
if (!is.data.frame(calendars) || nrow(calendars) == 0L || !("calendar_signature" %in% names(calendars))) {
  stop("FTN metadata calendars are missing or malformed.", call. = FALSE)
}

calendar_signatures <- sort(unique(trimws(as.character(calendars$calendar_signature))))
calendar_signatures <- calendar_signatures[!is.na(calendar_signatures) & nzchar(calendar_signatures)]
expected_signatures <- c(
  "1-2-3-4-5-6-7-8-9-10-11-12",
  "10-11-12-1-2-3-4-5-6-7-8-9"
)

missing_expected_signatures <- setdiff(expected_signatures, calendar_signatures)
if (length(missing_expected_signatures) > 0L) {
  stop(
    paste0(
      "Expected FTN calendar signatures not found: ",
      paste(missing_expected_signatures, collapse = ", ")
    ),
    call. = FALSE
  )
}

rows_source <- suppressWarnings(as.integer(metadata_object$rows_source %||% NA_integer_))
rows_app <- suppressWarnings(as.integer(metadata_object$rows_app %||% NA_integer_))
if (!is.finite(rows_source) || rows_source <= 0L || !is.finite(rows_app) || rows_app <= 0L) {
  stop("Metadata row counters are missing or non-positive.", call. = FALSE)
}

app_ui_country_count <- NA_integer_
if (is.list(app_ui_metadata_object) && is.data.frame(app_ui_metadata_object$country_choices_all)) {
  app_ui_country_count <- nrow(app_ui_metadata_object$country_choices_all)
} else if (is.list(app_ui_metadata_object) && is.list(app_ui_metadata_object$metadata) && is.data.frame(app_ui_metadata_object$metadata$country_choices_all)) {
  app_ui_country_count <- nrow(app_ui_metadata_object$metadata$country_choices_all)
} else if (is.data.frame(app_ui_metadata_object)) {
  app_ui_country_count <- nrow(app_ui_metadata_object)
}

if (!is.finite(app_ui_country_count) || app_ui_country_count <= 0L) {
  stop("App UI metadata does not contain usable country choice rows.", call. = FALSE)
}

cat("FTN_ARTIFACT_PROBE_STATUS=PASS\n")
cat("FTN_ARTIFACT_PATH=", paths$artifact, "\n", sep = "")
cat("FTN_METADATA_PATH=", paths$metadata, "\n", sep = "")
cat("FTN_APP_UI_METADATA_PATH=", app_ui_metadata_path, "\n", sep = "")
cat("FTN_INPUT_CSV=", paths$input_csv, "\n", sep = "")
cat("FTN_ARTIFACT_ROWS=", nrow(artifact_data), "\n", sep = "")
cat("FTN_METADATA_ROWS_SOURCE=", rows_source, "\n", sep = "")
cat("FTN_METADATA_ROWS_APP=", rows_app, "\n", sep = "")
cat("FTN_APP_UI_COUNTRY_ROWS=", app_ui_country_count, "\n", sep = "")
cat("FTN_SOURCE_SIGNATURE=", source_signature_current, "\n", sep = "")
cat("FTN_MONTH_COLUMN=", month_column, "\n", sep = "")
cat("FTN_CALENDAR_SIGNATURE_COUNT=", length(calendar_signatures), "\n", sep = "")
cat("FTN_CALENDAR_SIGNATURE_HEAD=", paste(utils::head(calendar_signatures, 8L), collapse = "|"), "\n", sep = "")