almond_master_truthy <- function(value, default = FALSE) {
  if (is.null(value) || length(value) == 0L || all(is.na(value))) return(default)
  normalized <- tolower(trimws(as.character(value[[1]])))
  if (!nzchar(normalized)) return(default)
  normalized %in% c("1", "true", "yes", "y", "on")
}

almond_master_parse_updates <- function(value) {
  tokens <- unlist(strsplit(paste(value, collapse = ","), ",", fixed = TRUE), use.names = FALSE)
  tokens <- tolower(trimws(tokens))
  tokens[nzchar(tokens)]
}

almond_master_allowed_updates <- function() {
  c("census_fixture", "census_live", "psd", "nass", "metadata", "all", "none")
}

almond_master_data_updates <- function() {
  c("census_fixture", "census_live", "psd", "nass")
}

almond_master_expand_updates <- function(updates) {
  updates <- unique(updates)
  if (length(updates) == 0L || "none" %in% updates) return(character())
  if ("all" %in% updates) {
    updates <- unique(c(setdiff(updates, "all"), "census_live", "psd", "nass"))
  }
  if (all(c("census_fixture", "census_live") %in% updates)) {
    stop("Select either Census fixture or Census live SQL, not both.", call. = FALSE)
  }
  if (any(almond_master_data_updates() %in% updates) && !"metadata" %in% updates) {
    updates <- c(updates, "metadata")
  }
  update_order <- c("census_live", "census_fixture", "psd", "nass", "metadata")
  update_order[update_order %in% updates]
}

almond_master_prompt_update_selection <- function() {
  prompt_choices <- c("Census fixture", "Census live SQL", "PSD live API", "NASS live SQL", "App UI metadata", "Safe local rebuild", "No updates")
  selected_choices <- utils::select.list(
    choices = prompt_choices,
    preselect = c("Census live SQL", "PSD live API", "NASS live SQL"),
    multiple = TRUE,
    title = "Select Almond data rebuild steps"
  )

  if (length(selected_choices) == 0L) return("none")
  if ("No updates" %in% selected_choices) return("none")
  if ("Safe local rebuild" %in% selected_choices) return(c("census_fixture", "metadata"))

  selection_map <- c(
    "Census fixture" = "census_fixture",
    "Census live SQL" = "census_live",
    "PSD live API" = "psd",
    "NASS live SQL" = "nass",
    "App UI metadata" = "metadata"
  )
  unname(selection_map[selected_choices])
}

almond_master_resolve_updates <- function(interactive_mode = interactive()) {
  option_value <- getOption("almond_master_updates", NULL)
  env_value <- Sys.getenv("ALMOND_MASTER_UPDATES", unset = "")

  raw_updates <- if (!is.null(option_value)) {
    option_value
  } else if (nzchar(env_value)) {
    env_value
  } else if (isTRUE(interactive_mode)) {
    almond_master_prompt_update_selection()
  } else {
    character()
  }

  updates <- almond_master_parse_updates(raw_updates)
  allowed <- almond_master_allowed_updates()
  invalid <- setdiff(updates, allowed)
  if (length(invalid) > 0L) {
    stop(sprintf("Unsupported ALMOND_MASTER_UPDATES value(s): %s.", paste(invalid, collapse = ", ")), call. = FALSE)
  }

  almond_master_expand_updates(updates)
}

almond_master_resolve_launch_app <- function(interactive_mode = interactive(), default = FALSE) {
  option_value <- getOption("almond_master_launch_app", NULL)
  env_value <- Sys.getenv("ALMOND_MASTER_LAUNCH_APP", unset = "")
  if (!is.null(option_value)) return(almond_master_truthy(option_value, default = default))
  if (nzchar(env_value)) return(almond_master_truthy(env_value, default = default))
  isTRUE(default)
}

almond_master_resolve_launcher_browser <- function(interactive_mode = interactive()) {
  if (!isTRUE(interactive_mode)) return(FALSE)
  rstudio_available <- tryCatch(
    requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable(),
    error = function(...) FALSE
  )
  if (isTRUE(rstudio_available)) return(function(url) rstudioapi::viewer(url))
  TRUE
}

almond_master_is_hosted_rstudio_run_app_entry <- function(call_stack = sys.calls(), interactive_mode = interactive()) {
  if (!isTRUE(interactive_mode)) return(FALSE)
  if (requireNamespace("shiny", quietly = TRUE) && isTRUE(shiny::isRunning())) return(FALSE)
  call_text <- vapply(call_stack, function(call) paste(deparse(call), collapse = " "), character(1))
  any(grepl("sourceUTF8\\(", call_text)) && any(grepl("sharedEnv", call_text, fixed = TRUE))
}

almond_master_load_contract <- function(project_dir) {
  source(file.path(project_dir, "Programs", "shared_core", "commodity_contract_utils.R"), local = FALSE)
  source(file.path(project_dir, "System", "Config", "commodity_contract.R"), local = FALSE)
  contract <- get_commodity_contract(project_dir)
  validate_commodity_contract(contract)
  validate_commodity_project_root(project_dir, contract)
  contract
}

almond_master_source_family_enabled <- function(contract, family_id) {
  family <- contract$source_families[[family_id]]
  !is.null(family) &&
    isTRUE(family$structurally_present) &&
    isTRUE(family$runtime_enabled) &&
    isTRUE(family$build_enabled) &&
    isTRUE(family$visible_in_ui)
}

almond_master_source_disabled_reason <- function(contract, family_ids, fallback) {
  reasons <- vapply(family_ids, function(family_id) {
    family <- contract$source_families[[family_id]]
    reason <- family$disabled_reason
    if (is.null(reason) || length(reason) == 0L || !nzchar(as.character(reason[[1]]))) return(NA_character_)
    as.character(reason[[1]])
  }, character(1))
  reasons <- unique(stats::na.omit(reasons))
  if (length(reasons) > 0L) paste(reasons, collapse = " ") else fallback
}

almond_master_source_catalog <- function(contract) {
  census_enabled <- all(vapply(c("census_exports", "census_imports"), function(family_id) {
    almond_master_source_family_enabled(contract, family_id)
  }, logical(1)))
  psd_enabled <- almond_master_source_family_enabled(contract, "psd")
  nass_enabled <- almond_master_source_family_enabled(contract, "nass")
  export_sales_enabled <- almond_master_source_family_enabled(contract, "export_sales")
  wasde_enabled <- almond_master_source_family_enabled(contract, "wasde")

  data.frame(
    id = c("census", "psd", "nass", "export_sales", "wasde"),
    label = c("Census", "Production, Supply, and Distribution", "National Agricultural Statistics Service", "Export Sales", "WASDE"),
    update = c("census_live", "psd", "nass", "export_sales", "wasde"),
    enabled = c(census_enabled, psd_enabled, nass_enabled, export_sales_enabled, wasde_enabled),
    selected = c(census_enabled, psd_enabled, nass_enabled, FALSE, FALSE),
    disabled_reason = c(
      if (isTRUE(census_enabled)) "" else almond_master_source_disabled_reason(contract, c("census_exports", "census_imports"), "Census is not enabled for Almond rebuilds."),
      if (isTRUE(psd_enabled)) "" else almond_master_source_disabled_reason(contract, "psd", "PSD is not enabled for Almond rebuilds."),
      if (isTRUE(nass_enabled)) "" else almond_master_source_disabled_reason(contract, "nass", "NASS is not enabled for Almond rebuilds."),
      if (isTRUE(export_sales_enabled)) "" else almond_master_source_disabled_reason(contract, "export_sales", "No local Almond Export Sales source evidence."),
      if (isTRUE(wasde_enabled)) "" else almond_master_source_disabled_reason(contract, "wasde", "No local Almond WASDE source evidence.")
    ),
    checkbox = c(TRUE, TRUE, TRUE, TRUE, TRUE),
    stringsAsFactors = FALSE
  )
}

almond_master_render_source_checkbox <- function(source_row, input_id = "update_groups") {
  source_id <- as.character(source_row$id[[1]])
  source_label <- as.character(source_row$label[[1]])
  source_update <- as.character(source_row$update[[1]])
  source_enabled <- isTRUE(source_row$enabled[[1]])
  source_selected <- isTRUE(source_row$selected[[1]]) && source_enabled
  disabled_reason <- as.character(source_row$disabled_reason[[1]])
  checkbox_id <- paste(input_id, source_id, sep = "_")
  choice_class <- paste(c("almond-master-source-choice", if (!source_enabled) "disabled"), collapse = " ")

  shiny::tags$div(
    class = choice_class,
    shiny::tags$label(
      class = "checkbox",
      `for` = checkbox_id,
      shiny::tags$input(
        id = checkbox_id,
        type = "checkbox",
        name = input_id,
        value = source_update,
        checked = if (source_selected) "checked" else NULL,
        disabled = if (!source_enabled) "disabled" else NULL
      ),
      shiny::tags$span(source_label)
    ),
    if (!source_enabled && nzchar(disabled_reason)) {
      shiny::tags$div(class = "almond-master-source-reason", disabled_reason)
    } else {
      NULL
    }
  )
}

almond_master_render_source_selector <- function(catalog, input_id = "update_groups") {
  shiny::tags$div(
    id = input_id,
    class = "form-group shiny-input-checkboxgroup shiny-input-container",
    shiny::tags$label(class = "control-label", `for` = input_id, "Update these data sources before launching:"),
    lapply(seq_len(nrow(catalog)), function(row_index) {
      almond_master_render_source_checkbox(catalog[row_index, , drop = FALSE], input_id = input_id)
    }),
    shiny::tags$p(
      class = "help-block almond-master-dependent-note",
      "Export Sales and WASDE data are not available for Almonds."
    )
  )
}

almond_master_build_launcher_result <- function(enabled_updates, launch_app = TRUE, interactive_mode = interactive()) {
  list(
    enabled_updates = almond_master_expand_updates(enabled_updates),
    launch_app = isTRUE(launch_app),
    interactive_mode = isTRUE(interactive_mode)
  )
}

almond_master_progress_label <- function(update_name) {
  labels <- c(
    census_fixture = "Census fixture",
    census_live = "Census live SQL",
    psd = "PSD live API",
    nass = "NASS live SQL",
    metadata = "App UI metadata"
  )
  label <- labels[[update_name]]
  if (is.null(label) || !nzchar(label)) update_name else label
}

almond_master_report_progress <- function(progress_callback = NULL, update_name = NA_character_, phase = "info", detail = "", step = NA_integer_, total = NA_integer_) {
  update_name <- as.character(update_name)
  phase <- as.character(phase)
  detail <- as.character(detail)
  step <- suppressWarnings(as.integer(step))
  total <- suppressWarnings(as.integer(total))

  cat(
    "ALMOND_MASTER_PROGRESS=",
    "update=", update_name,
    "|phase=", phase,
    "|step=", if (is.na(step)) "" else step,
    "|total=", if (is.na(total)) "" else total,
    "|detail=", detail,
    "\n",
    sep = ""
  )
  message(sprintf("[ALMOND MASTER] %s", detail))

  if (is.function(progress_callback)) {
    progress_callback(
      update_name = update_name,
      phase = phase,
      detail = detail,
      step = step,
      total = total
    )
  }

  invisible(NULL)
}

almond_master_load_app_components <- function(project_dir) {
  project_dir <- normalizePath(project_dir, winslash = "/", mustWork = TRUE)
  app_source_dir <- file.path(project_dir, "Programs", "app_source")
  app_env <- new.env(parent = globalenv())
  app_env$app_source_dir <- app_source_dir
  app_env$commodity_contract <- almond_master_load_contract(project_dir)
  project_root_option <- contract_option_name(app_env$commodity_contract, "project_root")
  previous_project_root <- getOption(project_root_option, default = NULL)
  options(stats::setNames(list(project_dir), project_root_option))
  on.exit(options(stats::setNames(list(previous_project_root), project_root_option)), add = TRUE)

  source(file.path(app_source_dir, "global.R"), local = app_env)
  source(file.path(app_source_dir, "ui.R"), local = app_env)

  almond_server <- function(input, output, session) {
    server_files <- list.files(file.path(app_source_dir, "server"), pattern = "^[0-9]{2}_.*\\.R$", full.names = TRUE)
    for (server_file in server_files) {
      source(server_file, local = TRUE)
    }
  }
  environment(almond_server) <- app_env

  list(ui = app_env$ui, server = almond_server)
}

almond_master_continue_from_launcher_result <- function(project_dir, launcher_result) {
  if (is.null(launcher_result)) return(invisible(NULL))

  master_result <- almond_master_run(
    project_dir = project_dir,
    interactive_mode = isTRUE(launcher_result$interactive_mode),
    updates = launcher_result$enabled_updates,
    launch_app = isTRUE(launcher_result$launch_app)
  )

  if (isTRUE(master_result$launch_app) && isTRUE(master_result$runtime_ready)) {
    source(file.path(project_dir, "Almond_Analysis_Shiny.R"), local = globalenv())
  }

  invisible(master_result)
}

almond_master_create_launcher_components <- function(
  project_dir,
  launch_mode = c("return_payload", "handoff_workflow"),
  hosted_run_app = almond_master_is_hosted_rstudio_run_app_entry()
) {
  launch_mode <- match.arg(launch_mode)
  project_dir <- normalizePath(project_dir, winslash = "/", mustWork = TRUE)
  contract <- almond_master_load_contract(project_dir)
  source_catalog <- almond_master_source_catalog(contract)

  launcher_ui <- shiny::fluidPage(
    shiny::tags$head(
      shiny::tags$style(shiny::HTML("\n        .almond-master-source-choice.disabled { color: #777; opacity: 0.65; }\n        .almond-master-source-choice .checkbox { margin-bottom: 3px; }\n        .almond-master-source-reason { margin: -2px 0 8px 22px; color: #666; font-size: 12px; line-height: 1.3; }\n        .almond-master-dependent-note { margin-bottom: 0; color: #555; }\n      "))
    ),
    shiny::titlePanel("Almond Data Pipeline Launcher"),
    shiny::fluidRow(
      shiny::column(
        width = 8,
        shiny::wellPanel(
          almond_master_render_source_selector(source_catalog, input_id = "update_groups")
        ),
        shiny::actionButton("launch_selected", "Run Selected Updates And Launch App", class = "btn-primary"),
        shiny::actionButton("launch_no_updates", "Launch App Without Updates"),
        shiny::wellPanel(
          shiny::strong("Run status"),
          shiny::textOutput("almond_master_progress_status"),
          shiny::verbatimTextOutput("almond_master_progress_log", placeholder = TRUE)
        )
      )
    )
  )

  ui <- if (identical(launch_mode, "handoff_workflow") && isTRUE(hosted_run_app)) {
    shiny::tagList(shiny::uiOutput("almond_master_app_root"))
  } else {
    launcher_ui
  }

  server <- function(input, output, session) {
    launch_started <- FALSE
    app_mode <- shiny::reactiveVal("launcher")
    almond_app_components <- NULL
    almond_app_started <- FALSE
    progress_status <- shiny::reactiveVal("Waiting for a launch choice.")
    progress_log <- shiny::reactiveVal(character())

    append_progress <- function(detail) {
      detail <- as.character(detail)
      if (!nzchar(detail)) return(invisible(NULL))
      progress_status(detail)
      progress_log(c(progress_log(), detail))
      invisible(NULL)
    }

    output$almond_master_progress_status <- shiny::renderText(progress_status())
    output$almond_master_progress_log <- shiny::renderText(paste(progress_log(), collapse = "\n"))

    if (identical(launch_mode, "handoff_workflow") && isTRUE(hosted_run_app)) {
      output$almond_master_app_root <- shiny::renderUI({
        if (identical(app_mode(), "almond") && !is.null(almond_app_components)) {
          almond_app_components$ui
        } else {
          launcher_ui
        }
      })
    }

    launch_main_app <- function(enabled_updates, launch_app = TRUE) {
      if (launch_started) return(invisible(NULL))
      launch_started <<- TRUE
      launcher_result <- almond_master_build_launcher_result(
        enabled_updates = enabled_updates,
        launch_app = isTRUE(launch_app),
        interactive_mode = TRUE
      )

      if (identical(launch_mode, "handoff_workflow") && isTRUE(hosted_run_app)) {
        master_result <- shiny::withProgress(
          message = "Running Almond data updates",
          value = 0,
          {
            almond_master_run(
              project_dir = project_dir,
              interactive_mode = TRUE,
              updates = launcher_result$enabled_updates,
              launch_app = FALSE,
              progress_callback = function(update_name, phase, detail, step, total) {
                append_progress(detail)
                if (!is.na(step) && !is.na(total) && total > 0L) {
                  shiny::setProgress(value = min(step / total, 1), detail = detail)
                } else {
                  shiny::incProgress(0, detail = detail)
                }
              }
            )
          }
        )

        if (!isTRUE(launcher_result$launch_app) || !isTRUE(master_result$runtime_ready)) {
          return(invisible(NULL))
        }

        append_progress("Updates complete; loading Almond app in this session.")

        almond_app_components <<- almond_master_load_app_components(project_dir)
        if (!isTRUE(almond_app_started)) {
          almond_app_started <<- TRUE
          almond_app_components$server(input, output, session)
        }
        app_mode("almond")
        return(invisible(NULL))
      }

      if (identical(launch_mode, "handoff_workflow")) {
        session$onSessionEnded(function() {
          almond_master_continue_from_launcher_result(project_dir, launcher_result)
        })
        shiny::stopApp(invisible(NULL))
        return(invisible(NULL))
      }

      shiny::stopApp(launcher_result)
    }

    shiny::observeEvent(input$launch_selected, {
      selected_updates <- input$update_groups
      if (is.null(selected_updates)) selected_updates <- character()
      launch_main_app(selected_updates, launch_app = TRUE)
    })

    shiny::observeEvent(input$launch_no_updates, {
      launch_main_app(character(), launch_app = TRUE)
    })
  }

  list(ui = ui, server = server)
}

almond_master_run_launcher_app <- function(project_dir, interactive_mode = interactive()) {
  launcher_components <- almond_master_create_launcher_components(project_dir, launch_mode = "return_payload")
  launcher_app <- shiny::shinyApp(launcher_components$ui, launcher_components$server)
  shiny::runApp(
    launcher_app,
    launch.browser = almond_master_resolve_launcher_browser(interactive_mode = interactive_mode)
  )
}

almond_master_source_program <- function(project_dir, relative_path) {
  program_env <- new.env(parent = globalenv())
  source(file.path(project_dir, relative_path), local = program_env)
  program_env
}

almond_master_run_census_fixture <- function(project_dir, progress_callback = NULL) {
  almond_master_report_progress(progress_callback, "census_fixture", "stage", "Loading Census fixture builder")
  builder_env <- almond_master_source_program(project_dir, file.path("Programs", "Build_Processed_Census_Almonds.R"))
  almond_master_report_progress(progress_callback, "census_fixture", "stage", "Building Census fixture artifacts")
  paths <- builder_env$build_almond_census_fixture_artifact(project_dir)
  almond_master_report_progress(progress_callback, "census_fixture", "stage", "Reading Census fixture artifact summary")
  artifact <- readRDS(paths$artifact_path)
  targets <- readRDS(paths$correction_targets_path)
  list(
    status = "PASS",
    artifact_path = paths$artifact_path,
    correction_targets_path = paths$correction_targets_path,
    import_rows = nrow(artifact$imports),
    export_rows = nrow(artifact$exports),
    correction_target_rows = nrow(targets)
  )
}

almond_master_run_census_live <- function(project_dir, progress_callback = NULL) {
  almond_master_report_progress(progress_callback, "census_live", "stage", "Loading Census pull and build programs")
  pull_env <- almond_master_source_program(project_dir, file.path("Programs", "Pull_Census_Almonds.R"))
  builder_env <- almond_master_source_program(project_dir, file.path("Programs", "Build_Processed_Census_Almonds.R"))
  almond_master_report_progress(progress_callback, "census_live", "stage", "Downloading Almond Census raw import/export data")
  raw_result <- pull_env$pull_almond_census_raw(project_dir)
  almond_master_report_progress(progress_callback, "census_live", "stage", "Building processed Almond Census artifacts")
  build_paths <- builder_env$build_almond_census_live_artifact(project_dir)
  almond_master_report_progress(progress_callback, "census_live", "stage", "Reading Census artifact summary")
  artifact <- readRDS(build_paths$artifact_path)
  targets <- readRDS(build_paths$correction_targets_path)
  list(
    status = "PASS",
    imports_path = raw_result$imports_path,
    exports_path = raw_result$exports_path,
    artifact_path = build_paths$artifact_path,
    correction_targets_path = build_paths$correction_targets_path,
    raw_import_rows = raw_result$import_rows,
    raw_export_rows = raw_result$export_rows,
    import_rows = nrow(artifact$imports),
    export_rows = nrow(artifact$exports),
    correction_target_rows = nrow(targets)
  )
}

almond_master_run_psd <- function(project_dir, progress_callback = NULL) {
  almond_master_report_progress(progress_callback, "psd", "stage", "Loading PSD pull and build programs")
  pull_env <- almond_master_source_program(project_dir, file.path("Programs", "Pull_FAS_PSD_Almonds_Phase1.R"))
  builder_env <- almond_master_source_program(project_dir, file.path("Programs", "Build_Processed_FAS_PSD_Almonds_Phase1.R"))
  almond_master_report_progress(progress_callback, "psd", "stage", "Downloading PSD lookup data")
  lookup_path <- pull_env$pull_almond_psd_lookup_phase1(project_dir)
  almond_master_report_progress(progress_callback, "psd", "stage", "Downloading PSD raw market-year data")
  raw_result <- pull_env$pull_almond_psd_raw_phase1(project_dir)
  almond_master_report_progress(progress_callback, "psd", "stage", "Building processed PSD artifacts")
  build_result <- builder_env$build_processed_almond_psd_phase1(project_dir)
  list(
    status = "PASS",
    lookup_path = lookup_path,
    raw_csv_path = raw_result$raw_csv_path,
    metadata_csv_path = raw_result$metadata_csv_path,
    artifact_path = build_result$artifact_path,
    historical_records_path = build_result$historical_records_path,
    raw_rows = raw_result$row_count,
    processed_rows = build_result$row_count,
    historical_record_rows = build_result$historical_record_count
  )
}

almond_master_run_nass <- function(project_dir, progress_callback = NULL) {
  almond_master_report_progress(progress_callback, "nass", "stage", "Loading NASS pull and build programs")
  pull_env <- almond_master_source_program(project_dir, file.path("Programs", "Pull_NASS_Almonds.R"))
  builder_env <- almond_master_source_program(project_dir, file.path("Programs", "Build_Processed_NASS_Almonds.R"))
  almond_master_report_progress(progress_callback, "nass", "stage", "Downloading NASS QuickStats raw data")
  raw_result <- pull_env$pull_almond_nass_raw(project_dir)
  almond_master_report_progress(progress_callback, "nass", "stage", "Building processed NASS artifacts")
  build_result <- builder_env$build_almond_nass_processed(project_dir)
  list(
    status = "PASS",
    raw_path = raw_result$raw_path,
    processed_path = build_result$processed_path,
    state_lookup_path = build_result$state_lookup_path,
    processed_csv_path = build_result$processed_csv_path,
    raw_rows = raw_result$row_count,
    processed_rows = build_result$row_count,
    state_lookup_rows = build_result$state_count,
    metric_count = build_result$metric_count,
    annual_year_types = build_result$annual_year_types,
    reference_periods = build_result$reference_periods
  )
}

almond_master_run_metadata <- function(project_dir, progress_callback = NULL) {
  almond_master_report_progress(progress_callback, "metadata", "stage", "Building app UI metadata artifact")
  metadata_env <- almond_master_source_program(project_dir, file.path("Programs", "Build_App_UI_Metadata.R"))
  result <- metadata_env$write_commodity_app_ui_metadata(project_root = project_dir)
  list(
    status = "PASS",
    artifact_path = result$artifact_path,
    mode = result$mode,
    source_count = result$source_count,
    source_entries = paste(result$source_entries, collapse = "|")
  )
}

almond_master_run_update <- function(project_dir, update_name, progress_callback = NULL) {
  switch(
    update_name,
    census_fixture = almond_master_run_census_fixture(project_dir, progress_callback = progress_callback),
    census_live = almond_master_run_census_live(project_dir, progress_callback = progress_callback),
    psd = almond_master_run_psd(project_dir, progress_callback = progress_callback),
    nass = almond_master_run_nass(project_dir, progress_callback = progress_callback),
    metadata = almond_master_run_metadata(project_dir, progress_callback = progress_callback),
    stop(sprintf("Unsupported Almond master update: %s", update_name), call. = FALSE)
  )
}

almond_master_print_update_result <- function(update_name, result) {
  cat("ALMOND_MASTER_UPDATE=", update_name, "|status=", result$status, "\n", sep = "")
  detail_names <- setdiff(names(result), "status")
  for (detail_name in detail_names) {
    cat("ALMOND_MASTER_UPDATE_DETAIL=", update_name, "|", detail_name, "=", result[[detail_name]], "\n", sep = "")
  }
}

almond_master_run_updates <- function(project_dir, updates, progress_callback = NULL) {
  updates <- almond_master_expand_updates(updates)
  results <- stats::setNames(vector("list", length(updates)), updates)
  total_updates <- length(updates)
  for (update_index in seq_along(updates)) {
    update_name <- updates[[update_index]]
    almond_master_report_progress(
      progress_callback,
      update_name = update_name,
      phase = "start",
      detail = sprintf("Starting %s update (%d of %d)", almond_master_progress_label(update_name), update_index, total_updates),
      step = update_index - 1L,
      total = total_updates
    )
    results[[update_name]] <- almond_master_run_update(project_dir, update_name, progress_callback = progress_callback)
    almond_master_print_update_result(update_name, results[[update_name]])
    almond_master_report_progress(
      progress_callback,
      update_name = update_name,
      phase = "complete",
      detail = sprintf("Completed %s update (%d of %d)", almond_master_progress_label(update_name), update_index, total_updates),
      step = update_index,
      total = total_updates
    )
  }
  results
}

almond_master_run <- function(project_dir, interactive_mode = interactive(), updates = NULL, launch_app = NULL, progress_callback = NULL) {
  project_dir <- normalizePath(project_dir, winslash = "/", mustWork = TRUE)
  contract <- almond_master_load_contract(project_dir)

  resolved_updates <- if (is.null(updates)) {
    almond_master_resolve_updates(interactive_mode = interactive_mode)
  } else {
    almond_master_expand_updates(updates)
  }
  if (length(resolved_updates) == 0L) {
    almond_master_report_progress(progress_callback, NA_character_, "skip", "No Almond data updates selected", 0L, 0L)
  } else {
    almond_master_report_progress(
      progress_callback,
      NA_character_,
      "plan",
      sprintf("Selected Almond updates: %s", paste(vapply(resolved_updates, almond_master_progress_label, character(1)), collapse = ", ")),
      0L,
      length(resolved_updates)
    )
  }
  update_results <- almond_master_run_updates(project_dir, resolved_updates, progress_callback = progress_callback)
  resolved_launch_app <- if (is.null(launch_app)) {
    almond_master_resolve_launch_app(interactive_mode = interactive_mode, default = FALSE)
  } else {
    isTRUE(launch_app)
  }
  runtime_ready <- commodity_runtime_source_ready(project_dir, contract)
  marker_lines <- readLines(file.path(project_dir, contract$runtime$root_sentinel), warn = FALSE)
  runtime_marker <- paste(marker_lines[grepl("RUNTIME_SOURCE_READY", marker_lines, fixed = TRUE)], collapse = "|")

  cat("ALMOND_RICE_CLONE_MASTER_STATUS=PASS\n")
  cat("ALMOND_MASTER_PROJECT_ROOT=", project_dir, "\n", sep = "")
  cat("ALMOND_MASTER_UPDATES=", paste(resolved_updates, collapse = "|"), "\n", sep = "")
  cat("ALMOND_MASTER_LAUNCH_APP=", resolved_launch_app, "\n", sep = "")
  cat("ALMOND_MASTER_RUNTIME_READY=", runtime_ready, "\n", sep = "")
  cat("RUNTIME_SOURCE_READY_MARKER=", runtime_marker, "\n", sep = "")

  if (isTRUE(resolved_launch_app) && !isTRUE(runtime_ready)) {
    message(commodity_runtime_not_ready_message(project_dir, contract))
  }

  list(
    status = "PASS",
    project_dir = project_dir,
    updates = resolved_updates,
    update_results = update_results,
    launch_app = resolved_launch_app,
    runtime_ready = runtime_ready,
    runtime_marker = runtime_marker
  )
}
