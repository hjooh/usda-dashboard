options(vp_perf_log = TRUE)

options(rice_myc_transition_log = FALSE)
options(rice_myc_selectize_probe = FALSE)

get_entrypoint_dir <- function() {
  ctx <- tryCatch(rstudioapi::getActiveDocumentContext()$path, error = function(...) NULL)
  if (!is.null(ctx) && length(ctx) > 0L && nzchar(ctx[[1]])) {
    return(dirname(normalizePath(ctx[[1]], winslash = "/", mustWork = FALSE)))
  }

  frame_files <- vapply(sys.frames(), function(frame) {
    value <- tryCatch(frame$ofile, error = function(...) NULL)
    if (is.null(value) || length(value) == 0L) return("")
    as.character(value[[1]])
  }, character(1))
  frame_files <- frame_files[nzchar(frame_files)]
  entrypoint_file <- frame_files[grepl("FTN_Analysis_Shiny\\.R$", frame_files)]
  if (length(entrypoint_file) > 0L) {
    return(dirname(normalizePath(entrypoint_file[[length(entrypoint_file)]], winslash = "/", mustWork = FALSE)))
  }

  command_args <- commandArgs(trailingOnly = FALSE)
  file_arg <- "--file="
  script_arg <- command_args[startsWith(command_args, file_arg)]
  if (length(script_arg) > 0L) {
    script_path <- sub(file_arg, "", script_arg[[1]], fixed = TRUE)
    if (nzchar(script_path)) {
      return(dirname(normalizePath(script_path, winslash = "/", mustWork = FALSE)))
    }
  }

  normalizePath(getwd(), winslash = "/", mustWork = FALSE)
}

entrypoint_dir <- get_entrypoint_dir()
source(file.path(entrypoint_dir, "Programs", "vp_data_utils.R"), local = FALSE)
vp_clone_root <- vp_find_root(entrypoint_dir)
vp_require_packages(c("shiny", "data.table", "plotly", "DT", "dplyr", "tidyr", "purrr", "lubridate", "htmltools"))
source(file.path(vp_clone_root, "Programs", "shared_core", "commodity_contract_utils.R"), local = FALSE)
source(file.path(vp_clone_root, "System", "Config", "vp_contract.R"), local = FALSE)
commodity_contract <- get_commodity_contract(vp_clone_root)
validate_commodity_contract(commodity_contract)

app_source_dir <- file.path(vp_clone_root, "Programs", "app_source")
source(file.path(app_source_dir, "global.R"), local = TRUE)
source(file.path(app_source_dir, "ui.R"), local = TRUE)

server <- function(input, output, session) {
  for (server_file in list.files(file.path(app_source_dir, "server"), pattern = "^[0-9]{2}_.*\\.R$", full.names = TRUE)) {
    source(server_file, local = TRUE)
  }
}

shiny::shinyApp(ui, server)
