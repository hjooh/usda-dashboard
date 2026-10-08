`%||%` <- function(x, y) if (is.null(x) || length(x) == 0L) y else x

cat('CHK|start|', format(Sys.time(), '%Y-%m-%dT%H:%M:%SZ', tz='UTC'), '\n', sep='')
source('Programs/vp_data_utils.R', local = FALSE)
source('Programs/shared_source_harmonization_utils.R', local = FALSE)
project_dir <- normalizePath('.', winslash='/', mustWork=TRUE)
paths <- vp_paths(project_dir)
cat('CHK|input_csv|', paths[['input_csv']], '\n', sep='')

raw <- vp_read_csv(paths[['input_csv']])
cat('CHK|read_csv_rows|', nrow(raw), '\n', sep='')
month_column <- attr(raw, 'month_column') %||% 'MonthNum'
cat('CHK|month_column|', month_column, '\n', sep='')

source_rows <- vp_normalize_source_rows(raw)
cat('CHK|normalized_rows|', nrow(source_rows), '\n', sep='')

source_rows <- vp_append_all_type_rows(source_rows)
cat('CHK|all_type_rows|', nrow(source_rows), '\n', sep='')

calendars <- vp_infer_month_calendars(source_rows)
cat('CHK|calendar_rows|', nrow(calendars), '\n', sep='')
cat('CHK|calendar_signatures|', length(unique(as.character(calendars$calendar_signature))), '\n', sep='')

app_data <- vp_build_app_data(source_rows, calendars)
cat('CHK|app_rows|', nrow(app_data), '\n', sep='')

metadata <- vp_build_metadata(source_rows, app_data, calendars, paths[['input_csv']], month_column)
cat('CHK|metadata_rows_source|', metadata$rows_source, '\n', sep='')
cat('CHK|metadata_rows_app|', metadata$rows_app, '\n', sep='')

artifact <- as.data.frame(app_data)
if (exists('write_processed_artifact', mode = 'function')) {
  cat('CHK|artifact_write_mode|manifested\n', sep='')
  write_processed_artifact(
    data = artifact,
    artifact_path = paths[['artifact']],
    project_dir = project_dir,
    source_paths = paths[['input_csv']],
    extra_signatures = c(builder_version = vp_artifact_builder_version),
    artifact_metadata = metadata
  )
} else {
  cat('CHK|artifact_write_mode|plain_rds\n', sep='')
  saveRDS(artifact, paths[['artifact']])
}
cat('CHK|artifact_written|', paths[['artifact']], '\n', sep='')

saveRDS(metadata, paths[['metadata']])
cat('CHK|metadata_written|', paths[['metadata']], '\n', sep='')

cat('CHK|done|', format(Sys.time(), '%Y-%m-%dT%H:%M:%SZ', tz='UTC'), '\n', sep='')
