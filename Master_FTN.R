rm(list = ls())

get_master_script_dir <- function() {
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
  master_file <- frame_files[grepl("Master_FTN\\.R$", frame_files)]
  if (length(master_file) > 0L) {
    return(dirname(normalizePath(master_file[[length(master_file)]], winslash = "/", mustWork = FALSE)))
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

master_script_dir <- get_master_script_dir()
source(file.path(master_script_dir, "Programs", "vp_data_utils.R"), local = FALSE)
project_dir <- vp_find_root(master_script_dir)
vp_require_packages(c("shiny", "data.table"))
source(file.path(project_dir, "Programs", "shared_source_harmonization_utils.R"), local = FALSE)

`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0L) y else x
}

vp_master_truthy <- function(value, default = FALSE) {
  if (is.null(value) || length(value) == 0L || all(is.na(value))) return(default)
  normalized <- tolower(trimws(as.character(value[[1]])))
  if (!nzchar(normalized)) return(default)
  normalized %in% c("1", "true", "yes", "y", "on")
}

vp_master_parse_updates <- function(value) {
  tokens <- unlist(strsplit(paste(value, collapse = ","), ",", fixed = TRUE), use.names = FALSE)
  tokens <- tolower(trimws(tokens))
  tokens[nzchar(tokens)]
}

vp_master_allowed_updates <- function() {
  c("vp_trade", "metadata", "all", "none")
}

vp_master_expand_updates <- function(updates) {
  updates <- unique(updates)
  if (length(updates) == 0L || "none" %in% updates) return(character())
  if ("all" %in% updates) {
    updates <- unique(c(setdiff(updates, "all"), "vp_trade", "metadata"))
  }
  if ("vp_trade" %in% updates && !("metadata" %in% updates)) {
    updates <- c(updates, "metadata")
  }
  update_order <- c("vp_trade", "metadata")
  update_order[update_order %in% updates]
}

vp_master_resolve_updates <- function(interactive_mode = interactive()) {
  option_value <- getOption("vp_master_updates", NULL)
  env_value <- Sys.getenv("VP_MASTER_UPDATES", unset = "")

  raw_updates <- if (!is.null(option_value)) {
    option_value
  } else if (nzchar(env_value)) {
    env_value
  } else if (isTRUE(interactive_mode)) {
    "none"
  } else {
    character()
  }

  updates <- vp_master_parse_updates(raw_updates)
  allowed <- vp_master_allowed_updates()
  invalid <- setdiff(updates, allowed)
  if (length(invalid) > 0L) {
    stop(sprintf("Unsupported VP_MASTER_UPDATES value(s): %s.", paste(invalid, collapse = ", ")), call. = FALSE)
  }

  vp_master_expand_updates(updates)
}

vp_master_resolve_launch_app <- function(default = FALSE) {
  option_value <- getOption("vp_master_launch_app", NULL)
  env_value <- Sys.getenv("VP_MASTER_LAUNCH_APP", unset = "")
  if (!is.null(option_value)) return(vp_master_truthy(option_value, default = default))
  if (nzchar(env_value)) return(vp_master_truthy(env_value, default = default))
  isTRUE(default)
}

vp_master_resolve_launcher_browser <- function(interactive_mode = interactive()) {
  if (!isTRUE(interactive_mode)) return(FALSE)
  rstudio_available <- tryCatch(
    requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable(),
    error = function(...) FALSE
  )
  if (isTRUE(rstudio_available)) return(function(url) rstudioapi::viewer(url))
  TRUE
}

vp_master_is_hosted_rstudio_run_app_entry <- function(call_stack = sys.calls(), interactive_mode = interactive()) {
  if (!isTRUE(interactive_mode)) return(FALSE)
  if (requireNamespace("shiny", quietly = TRUE) && isTRUE(shiny::isRunning())) return(FALSE)
  call_text <- vapply(call_stack, function(call) paste(deparse(call), collapse = " "), character(1))
  any(grepl("sourceUTF8\\(", call_text)) && any(grepl("sharedEnv", call_text, fixed = TRUE))
}

vp_master_load_contract <- function(project_dir) {
  source(file.path(project_dir, "Programs", "shared_core", "commodity_contract_utils.R"), local = FALSE)
  source(file.path(project_dir, "System", "Config", "vp_contract.R"), local = FALSE)
  contract <- get_commodity_contract(project_dir)
  validate_commodity_contract(contract)
  validate_commodity_project_root(project_dir, contract)
  contract
}

vp_master_load_app_components <- function(project_dir) {
  project_dir <- normalizePath(project_dir, winslash = "/", mustWork = TRUE)
  app_source_dir <- file.path(project_dir, "Programs", "app_source")
  app_env <- new.env(parent = globalenv())
  app_env$app_source_dir <- app_source_dir
  app_env$commodity_contract <- vp_master_load_contract(project_dir)
  project_root_option <- contract_option_name(app_env$commodity_contract, "project_root")
  previous_project_root <- getOption(project_root_option, default = NULL)
  options(stats::setNames(list(project_dir), project_root_option))
  on.exit(options(stats::setNames(list(previous_project_root), project_root_option)), add = TRUE)

  source(file.path(app_source_dir, "global.R"), local = app_env)
  source(file.path(app_source_dir, "ui.R"), local = app_env)

  vp_server <- function(input, output, session) {
    server_files <- list.files(file.path(app_source_dir, "server"), pattern = "^[0-9]{2}_.*\\.R$", full.names = TRUE)
    for (server_file in server_files) {
      source(server_file, local = TRUE)
    }
  }
  environment(vp_server) <- app_env

  list(ui = app_env$ui, server = vp_server)
}

vp_master_progress_label <- function(update_name) {
  labels <- c(
    vp_trade = "FTN Trade Artifact",
    metadata = "App UI Metadata"
  )
  label <- labels[[update_name]]
  if (is.null(label) || !nzchar(label)) update_name else label
}

vp_master_report_progress <- function(progress_callback = NULL, update_name = NA_character_, phase = "info", detail = "", step = NA_integer_, total = NA_integer_) {
  update_name <- as.character(update_name)
  phase <- as.character(phase)
  detail <- as.character(detail)
  step <- suppressWarnings(as.integer(step))
  total <- suppressWarnings(as.integer(total))

  cat(
    "VP_MASTER_PROGRESS=",
    "update=", update_name,
    "|phase=", phase,
    "|step=", if (is.na(step)) "" else step,
    "|total=", if (is.na(total)) "" else total,
    "|detail=", detail,
    "\n",
    sep = ""
  )
  message(sprintf("[FTN MASTER] %s", detail))

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

vp_master_run_update <- function(project_dir, update_name, progress_callback = NULL) {
  switch(
    update_name,
    vp_trade = {
      vp_master_report_progress(progress_callback, update_name, "run", "Rebuilding FTN trade processed artifact")
      artifact <- as.data.frame(vp_build_trade_artifact(project_dir))
      list(status = "rebuilt", rows = nrow(artifact))
    },
    metadata = {
      vp_master_report_progress(progress_callback, update_name, "run", "Rebuilding FTN app UI metadata")
      metadata_env <- new.env(parent = globalenv())
      source(file.path(project_dir, "Programs", "Build_App_UI_Metadata.R"), local = metadata_env)
      result <- metadata_env$write_commodity_app_ui_metadata(project_root = project_dir)
      list(status = "rebuilt", rows = nrow(result$metadata$country_choices_all), artifact_path = result$artifact_path)
    },
    stop(sprintf("Unsupported FTN master update: %s", update_name), call. = FALSE)
  )
}

vp_master_print_update_result <- function(update_name, result) {
  cat("VP_MASTER_UPDATE=", update_name, "|status=", result$status, "\n", sep = "")
  detail_names <- setdiff(names(result), "status")
  for (detail_name in detail_names) {
    cat("VP_MASTER_UPDATE_DETAIL=", update_name, "|", detail_name, "=", result[[detail_name]], "\n", sep = "")
  }
}

vp_master_run_updates <- function(project_dir, updates, progress_callback = NULL) {
  updates <- vp_master_expand_updates(updates)
  results <- stats::setNames(vector("list", length(updates)), updates)
  total_updates <- length(updates)

  for (update_index in seq_along(updates)) {
    update_name <- updates[[update_index]]
    vp_master_report_progress(
      progress_callback,
      update_name = update_name,
      phase = "start",
      detail = sprintf("Starting %s update (%d of %d)", vp_master_progress_label(update_name), update_index, total_updates),
      step = update_index - 1L,
      total = total_updates
    )
    results[[update_name]] <- vp_master_run_update(project_dir, update_name, progress_callback = progress_callback)
    vp_master_print_update_result(update_name, results[[update_name]])
    vp_master_report_progress(
      progress_callback,
      update_name = update_name,
      phase = "complete",
      detail = sprintf("Completed %s update (%d of %d)", vp_master_progress_label(update_name), update_index, total_updates),
      step = update_index,
      total = total_updates
    )
  }

  results
}

vp_master_run <- function(project_dir, interactive_mode = interactive(), updates = NULL, launch_app = NULL, progress_callback = NULL) {
  project_dir <- normalizePath(project_dir, winslash = "/", mustWork = TRUE)
  resolved_updates <- if (is.null(updates)) {
    vp_master_resolve_updates(interactive_mode = interactive_mode)
  } else {
    vp_master_expand_updates(updates)
  }

  if (length(resolved_updates) == 0L) {
    vp_master_report_progress(progress_callback, NA_character_, "skip", "No FTN data updates selected", 0L, 0L)
  } else {
    vp_master_report_progress(
      progress_callback,
      NA_character_,
      "plan",
      sprintf("Selected FTN updates: %s", paste(vapply(resolved_updates, vp_master_progress_label, character(1)), collapse = ", ")),
      0L,
      length(resolved_updates)
    )
  }

  update_results <- vp_master_run_updates(project_dir, resolved_updates, progress_callback = progress_callback)
  resolved_launch_app <- if (is.null(launch_app)) {
    vp_master_resolve_launch_app(default = FALSE)
  } else {
    isTRUE(launch_app)
  }

  runtime_ready <- file.exists(vp_paths(project_dir)$artifact)

  cat("VP_MASTER_STATUS=PASS\n")
  cat("VP_MASTER_PROJECT_ROOT=", project_dir, "\n", sep = "")
  cat("VP_MASTER_UPDATES=", paste(resolved_updates, collapse = "|"), "\n", sep = "")
  cat("VP_MASTER_LAUNCH_APP=", resolved_launch_app, "\n", sep = "")
  cat("VP_MASTER_RUNTIME_READY=", runtime_ready, "\n", sep = "")

  if (isTRUE(resolved_launch_app) && !isTRUE(runtime_ready)) {
    message("FTN app launch requested, but the FTN artifact is missing. Run the FTN trade rebuild first.")
  }

  list(
    status = "PASS",
    project_dir = project_dir,
    updates = resolved_updates,
    update_results = update_results,
    launch_app = resolved_launch_app,
    runtime_ready = runtime_ready
  )
}

vp_master_create_launcher_components <- function(project_dir, launch_mode = c("return_payload", "handoff_workflow"), hosted_run_app = vp_master_is_hosted_rstudio_run_app_entry()) {
  launch_mode <- match.arg(launch_mode)
  project_dir <- normalizePath(project_dir, winslash = "/", mustWork = TRUE)

  launcher_ui <- shiny::fluidPage(
    shiny::titlePanel("FTN Data Pipeline Launcher"),
    shiny::fluidRow(
      shiny::column(
        width = 8,
        shiny::wellPanel(
          shiny::checkboxGroupInput(
            inputId = "update_groups",
            label = "Update these data sources before launching:",
            choices = c("FTN Trade Artifact" = "vp_trade", "App UI Metadata" = "metadata"),
            selected = c("vp_trade", "metadata")
          )
        ),
        shiny::actionButton("launch_selected", "Run Selected Updates And Launch App", class = "btn-primary"),
        shiny::actionButton("launch_no_updates", "Launch App Without Updates"),
        shiny::wellPanel(
          shiny::strong("Run status"),
          shiny::textOutput("vp_master_progress_status"),
          shiny::verbatimTextOutput("vp_master_progress_log", placeholder = TRUE)
        )
      )
    )
  )

  ui <- if (identical(launch_mode, "handoff_workflow") && isTRUE(hosted_run_app)) {
    shiny::tagList(shiny::uiOutput("vp_master_app_root"))
  } else {
    launcher_ui
  }

  server <- function(input, output, session) {
    launch_started <- FALSE
    app_mode <- shiny::reactiveVal("launcher")
    vp_app_components <- NULL
    vp_app_started <- FALSE
    progress_status <- shiny::reactiveVal("Waiting for a launch choice.")
    progress_log <- shiny::reactiveVal(character())

    append_progress <- function(detail) {
      detail <- as.character(detail)
      if (!nzchar(detail)) return(invisible(NULL))
      progress_status(detail)
      progress_log(c(progress_log(), detail))
      invisible(NULL)
    }

    progress_callback <- function(update_name, phase, detail, step, total) {
      if (!nzchar(detail)) return(invisible(NULL))
      append_progress(detail)
      invisible(NULL)
    }

    output$vp_master_progress_status <- shiny::renderText(progress_status())
    output$vp_master_progress_log <- shiny::renderText(paste(progress_log(), collapse = "\n"))

    execute_launch <- function(selected_updates, launch_app) {
      if (isTRUE(launch_started)) return(invisible(NULL))
      launch_started <<- TRUE

      selected_updates <- trimws(as.character(selected_updates %||% character()))
      selected_updates <- selected_updates[nzchar(selected_updates)]

      result <- tryCatch(
        vp_master_run(
          project_dir = project_dir,
          interactive_mode = TRUE,
          updates = selected_updates,
          launch_app = launch_app,
          progress_callback = progress_callback
        ),
        error = function(e) {
          append_progress(sprintf("Launch failed: %s", conditionMessage(e)))
          launch_started <<- FALSE
          NULL
        }
      )

      if (is.null(result)) return(invisible(NULL))

      if (identical(launch_mode, "return_payload")) {
        stopApp(list(
          enabled_updates = selected_updates,
          launch_app = isTRUE(launch_app),
          interactive_mode = TRUE
        ))
        return(invisible(NULL))
      }

      if (isTRUE(result$launch_app) && isTRUE(result$runtime_ready)) {
        vp_app_components <<- vp_master_load_app_components(project_dir)
        app_mode("app")
        append_progress("FTN app ready.")
      } else if (isTRUE(result$launch_app)) {
        append_progress("Launch requested, but the FTN artifact is missing. Run the FTN trade update first.")
        launch_started <<- FALSE
      } else {
        append_progress("Updates completed; app launch was not requested.")
        launch_started <<- FALSE
      }

      invisible(NULL)
    }

    shiny::observeEvent(input$launch_selected, {
      execute_launch(input$update_groups, launch_app = TRUE)
    })

    shiny::observeEvent(input$launch_no_updates, {
      execute_launch(character(), launch_app = TRUE)
    })

    if (identical(launch_mode, "handoff_workflow") && isTRUE(hosted_run_app)) {
      output$vp_master_app_root <- shiny::renderUI({
        if (identical(app_mode(), "app") && !is.null(vp_app_components)) {
          vp_app_components$ui
        } else {
          launcher_ui
        }
      })

      shiny::observe({
        if (!identical(app_mode(), "app")) return()
        if (is.null(vp_app_components)) return()
        if (isTRUE(vp_app_started)) return()
        vp_app_started <<- TRUE
        vp_app_components$server(input, output, session)
      })
    }
  }

  list(ui = ui, server = server)
}

vp_master_run_launcher_app <- function(project_dir, interactive_mode = interactive()) {
  components <- vp_master_create_launcher_components(
    project_dir = project_dir,
    launch_mode = "return_payload",
    hosted_run_app = FALSE
  )
  shiny::runApp(
    shiny::shinyApp(components$ui, components$server),
    launch.browser = vp_master_resolve_launcher_browser(interactive_mode = interactive_mode)
  )
}

vp_master_continue_from_launcher_result <- function(project_dir, launcher_result) {
  if (is.null(launcher_result)) return(invisible(NULL))

  master_result <- vp_master_run(
    project_dir = project_dir,
    interactive_mode = isTRUE(launcher_result$interactive_mode),
    updates = launcher_result$enabled_updates,
    launch_app = isTRUE(launcher_result$launch_app)
  )

  if (isTRUE(master_result$launch_app) && isTRUE(master_result$runtime_ready)) {
    source(file.path(project_dir, "FTN_Analysis_Shiny.R"), local = globalenv())
  }

  invisible(master_result)
}

hosted_rstudio_run_app <- vp_master_is_hosted_rstudio_run_app_entry()
launcher_components <- vp_master_create_launcher_components(project_dir, launch_mode = "handoff_workflow")
ui <- launcher_components$ui
server <- launcher_components$server

if (!interactive()) {
  master_result <- vp_master_run(project_dir = project_dir, interactive_mode = FALSE)
  if (isTRUE(master_result$launch_app) && isTRUE(master_result$runtime_ready)) {
    source(file.path(project_dir, "FTN_Analysis_Shiny.R"), local = globalenv())
  }
  quit(save = "no", status = 0L)
} else if (isTRUE(hosted_rstudio_run_app)) {
} else {
  launcher_result <- vp_master_run_launcher_app(project_dir = project_dir, interactive_mode = TRUE)
  vp_master_continue_from_launcher_result(project_dir = project_dir, launcher_result = launcher_result)
}

shiny::shinyApp(ui, server)
