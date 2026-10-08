normalize_commodity_path <- function(path) {
  normalizePath(path, winslash = "/", mustWork = FALSE)
}

commodity_script_dir <- function() {
  ctx <- tryCatch(rstudioapi::getActiveDocumentContext()$path, error = function(...) NULL)
  if (!is.null(ctx) && length(ctx) > 0L && nzchar(ctx[[1]])) {
    return(dirname(normalize_commodity_path(ctx[[1]])))
  }

  ofile <- tryCatch(sys.frames()[[1]]$ofile, error = function(...) NULL)
  if (!is.null(ofile) && length(ofile) > 0L && nzchar(ofile[[1]])) {
    return(dirname(normalize_commodity_path(ofile[[1]])))
  }

  command_args <- commandArgs(trailingOnly = FALSE)
  file_arg <- "--file="
  script_path <- command_args[startsWith(command_args, file_arg)]
  if (length(script_path) > 0L) {
    path <- sub(file_arg, "", script_path[[1]], fixed = TRUE)
    if (nzchar(path)) {
      return(dirname(normalize_commodity_path(path)))
    }
  }

  normalize_commodity_path(getwd())
}

required_contract_sections <- function() {
  c(
    "contract_schema_version",
    "identity",
    "runtime",
    "namespaces",
    "source_families",
    "artifacts",
    "adapters",
    "labels",
    "metadata",
    "dependencies",
    "credentials",
    "shared_core"
  )
}

required_source_family_fields <- function() {
  c(
    "structurally_present",
    "runtime_enabled",
    "build_enabled",
    "visible_in_ui",
    "disabled_reason",
    "required_packages",
    "required_artifacts",
    "adapter_name"
  )
}

contract_field <- function(contract, section, field, default = NULL) {
  section_value <- contract[[section]]
  if (is.null(section_value) || is.null(section_value[[field]])) {
    return(default)
  }

  section_value[[field]]
}

contract_option_name <- function(contract, key) {
  prefix <- contract_field(contract, "runtime", "option_prefix")
  if (is.null(prefix) || !nzchar(prefix)) {
    stop("Commodity contract is missing runtime option_prefix.", call. = FALSE)
  }

  paste(prefix, key, sep = "_")
}

contract_env_name <- function(contract, key) {
  prefix <- contract_field(contract, "runtime", "env_prefix")
  if (is.null(prefix) || !nzchar(prefix)) {
    stop("Commodity contract is missing runtime env_prefix.", call. = FALSE)
  }

  paste(toupper(prefix), toupper(key), sep = "_")
}

contract_label <- function(contract, key) {
  value <- contract$labels[[key]]
  if (is.null(value) || length(value) == 0L || !nzchar(value[[1]])) {
    stop(sprintf("Commodity contract is missing label: %s", key), call. = FALSE)
  }

  value[[1]]
}

contract_app_title <- function(contract) {
  value <- contract$identity$app_title %||% contract$labels$app_title
  value <- trimws(as.character(value[[1]] %||% ""))
  if (!nzchar(value)) {
    stop("Commodity contract is missing an app title.", call. = FALSE)
  }

  value
}

contract_aggregate_label <- function(contract) {
  value <- contract$identity$aggregate_label %||% contract$labels$aggregate_label
  value <- trimws(as.character(value[[1]] %||% ""))
  if (!nzchar(value)) {
    stop("Commodity contract is missing an aggregate label.", call. = FALSE)
  }

  value
}

contract_reserved_names <- function(contract) {
  values <- trimws(as.character(contract$identity$reserved_names %||% character()))
  values <- unique(values[!is.na(values) & nzchar(values)])
  if (length(values) == 0L) {
    values <- contract_aggregate_label(contract)
  }

  values
}

contract_artifact_path <- function(contract, role, project_root = contract$project_root) {
  artifact <- contract$artifacts[[role]]
  if (is.null(artifact)) {
    stop(sprintf("Commodity contract is missing artifact role: %s", role), call. = FALSE)
  }

  relative_path <- artifact$path
  if (is.null(relative_path) || length(relative_path) == 0L || !nzchar(relative_path[[1]])) {
    stop(sprintf("Commodity artifact role has no path: %s", role), call. = FALSE)
  }

  normalize_commodity_path(file.path(project_root, relative_path[[1]]))
}

contract_source_family <- function(contract, source_family) {
  source_entry <- contract$source_families[[source_family]]
  if (is.null(source_entry)) {
    stop(sprintf("Commodity contract is missing source family: %s", source_family), call. = FALSE)
  }

  source_entry
}

contract_source_enabled <- function(contract, source_family, usage = c("runtime", "build", "ui")) {
  usage <- match.arg(usage)
  source_entry <- contract_source_family(contract, source_family)
  flag_name <- switch(
    usage,
    runtime = "runtime_enabled",
    build = "build_enabled",
    ui = "visible_in_ui"
  )

  isTRUE(source_entry[[flag_name]])
}

contract_census_fiscal_year_enabled <- function(contract, usage = c("runtime", "build", "ui")) {
  usage <- match.arg(usage)
  fiscal_year <- contract_field(contract, "census", "fiscal_year", default = list())
  if (!is.list(fiscal_year)) {
    return(FALSE)
  }

  flag_name <- switch(
    usage,
    runtime = "runtime_enabled",
    build = "build_enabled",
    ui = "visible_in_ui"
  )

  isTRUE(fiscal_year[[flag_name]])
}

contract_ui_source_choices <- function(contract, include_disabled = FALSE) {
  choice_groups <- contract$labels$source_choice_groups %||% NULL
  family_map <- contract$labels$source_choice_families %||% NULL

  if (is.null(choice_groups) || length(choice_groups) == 0L) {
    stop("Commodity contract is missing UI source choice groups.", call. = FALSE)
  }
  if (is.null(family_map) || length(family_map) == 0L) {
    stop("Commodity contract is missing UI source choice family mappings.", call. = FALSE)
  }

  visible_groups <- lapply(choice_groups, function(group_choices) {
    source_values <- trimws(as.character(unname(group_choices)))
    display_labels <- names(group_choices)
    if (is.null(display_labels) || length(display_labels) != length(source_values) || any(!nzchar(display_labels))) {
      stop("Commodity UI source choices must have display labels.", call. = FALSE)
    }

    visible <- vapply(source_values, function(source_value) {
      source_families <- family_map[[source_value]] %||% source_value
      source_families <- trimws(as.character(source_families))
      source_families <- source_families[!is.na(source_families) & nzchar(source_families)]
      if (length(source_families) == 0L) {
        return(FALSE)
      }

      any(vapply(source_families, function(source_family) {
        contract_source_enabled(contract, source_family, usage = "ui")
      }, logical(1)))
    }, logical(1))

    keep <- isTRUE(include_disabled) | visible
    stats::setNames(source_values[keep], display_labels[keep])
  })

  visible_groups <- visible_groups[lengths(visible_groups) > 0L]
  visible_groups
}

contract_ui_source_values <- function(contract, include_disabled = FALSE) {
  choices <- contract_ui_source_choices(contract, include_disabled = include_disabled)
  unname(unlist(choices, use.names = FALSE))
}

contract_default_ui_source <- function(contract, default = NULL) {
  values <- contract_ui_source_values(contract)
  if (length(values) > 0L) {
    return(values[[1]])
  }

  default
}

contract_census_basis_choices <- function(contract) {
  choices <- contract$census$basis$choices %||% NULL
  if (is.null(choices) || length(choices) == 0L) {
    stop("Commodity contract is missing Census basis choices.", call. = FALSE)
  }

  labels <- trimws(as.character(names(choices)))
  values <- trimws(as.character(unname(choices)))
  keep <- !is.na(labels) & nzchar(labels) & !is.na(values) & nzchar(values)
  if (!any(keep)) {
    stop("Commodity Census basis choices must include labels and values.", call. = FALSE)
  }

  stats::setNames(values[keep], labels[keep])
}

contract_census_default_basis <- function(contract) {
  choices <- contract_census_basis_choices(contract)
  default <- trimws(as.character(contract$census$basis$default %||% character(0)))
  default <- default[!is.na(default) & nzchar(default)]
  if (length(default) == 0L || !(default[[1L]] %in% unname(choices))) {
    return(unname(choices[[1L]]))
  }

  default[[1L]]
}

contract_census_inshell_shell_out_factor <- function(contract, default = 0.6) {
  factor <- suppressWarnings(as.numeric(contract$census$basis$inshell_shell_out_factor %||% default))
  if (!(length(factor) == 1L && is.finite(factor) && factor > 0)) {
    return(default)
  }

  factor
}

contract_required_packages <- function(contract, usage = c("runtime", "validation"), source_family = NULL) {
  usage <- match.arg(usage)
  package_names <- character()

  package_names <- c(package_names, contract$dependencies[[paste0(usage, "_packages")]] %||% character())

  if (!is.null(source_family)) {
    source_entry <- contract_source_family(contract, source_family)
    package_names <- c(package_names, source_entry$required_packages %||% character())
  }

  unique(package_names[nzchar(package_names)])
}

assert_required_packages <- function(contract, usage = c("runtime", "validation"), source_family = NULL) {
  packages <- contract_required_packages(contract, usage = usage, source_family = source_family)
  missing_packages <- packages[!vapply(packages, requireNamespace, logical(1), quietly = TRUE)]

  if (length(missing_packages) > 0L) {
    stop(
      sprintf("Missing required R packages: %s", paste(missing_packages, collapse = ", ")),
      call. = FALSE
    )
  }

  invisible(TRUE)
}

validate_commodity_contract <- function(contract) {
  if (!is.list(contract)) {
    stop("Commodity contract must be a named list.", call. = FALSE)
  }

  missing_sections <- setdiff(required_contract_sections(), names(contract))
  if (length(missing_sections) > 0L) {
    stop(sprintf("Commodity contract missing sections: %s", paste(missing_sections, collapse = ", ")), call. = FALSE)
  }

  if (!identical(as.integer(contract$contract_schema_version), 1L)) {
    stop("Unsupported commodity contract schema version.", call. = FALSE)
  }

  identity_fields <- c("commodity_id", "commodity_name", "commodity_name_plural", "app_title", "aggregate_label", "reserved_names")
  missing_identity <- identity_fields[!vapply(identity_fields, function(field) !is.null(contract$identity[[field]]), logical(1))]
  if (length(missing_identity) > 0L) {
    stop(sprintf("Commodity contract identity missing fields: %s", paste(missing_identity, collapse = ", ")), call. = FALSE)
  }

  runtime_fields <- c("root_sentinel", "clone_marker", "entrypoint_file", "option_prefix", "env_prefix", "trace_file_prefix", "startup_fail_closed", "disabled_source_policy")
  missing_runtime <- runtime_fields[!vapply(runtime_fields, function(field) !is.null(contract$runtime[[field]]), logical(1))]
  if (length(missing_runtime) > 0L) {
    stop(sprintf("Commodity contract runtime missing fields: %s", paste(missing_runtime, collapse = ", ")), call. = FALSE)
  }

  if (length(names(contract$source_families)) == 0L) {
    stop("Commodity contract must define source families.", call. = FALSE)
  }

  missing_source_fields <- unlist(lapply(names(contract$source_families), function(source_family) {
    source_entry <- contract$source_families[[source_family]]
    missing_fields <- setdiff(required_source_family_fields(), names(source_entry))
    if (length(missing_fields) == 0L) {
      return(character())
    }
    paste(source_family, missing_fields, sep = ":")
  }), use.names = FALSE)
  if (length(missing_source_fields) > 0L) {
    stop(sprintf("Commodity source-family entries missing fields: %s", paste(missing_source_fields, collapse = ", ")), call. = FALSE)
  }

  artifact_roles <- names(contract$artifacts)
  if (length(artifact_roles) == 0L || any(!nzchar(artifact_roles))) {
    stop("Commodity contract must define named artifact roles.", call. = FALSE)
  }
  if (anyDuplicated(artifact_roles)) {
    stop("Commodity contract artifact roles must be unique.", call. = FALSE)
  }

  for (source_family in names(contract$source_families)) {
    source_entry <- contract$source_families[[source_family]]
    if (isTRUE(source_entry$runtime_enabled) || isTRUE(source_entry$build_enabled)) {
      adapter_name <- source_entry$adapter_name
      if (is.null(adapter_name) || !nzchar(adapter_name) || is.null(contract$adapters[[adapter_name]])) {
        stop(sprintf("Enabled source family has no registered adapter: %s", source_family), call. = FALSE)
      }
    }

    missing_artifact_roles <- setdiff(source_entry$required_artifacts %||% character(), artifact_roles)
    if (length(missing_artifact_roles) > 0L) {
      stop(
        sprintf("Source family %s references missing artifact roles: %s", source_family, paste(missing_artifact_roles, collapse = ", ")),
        call. = FALSE
      )
    }
  }

  invisible(TRUE)
}

commodity_root_marker_path <- function(candidate_dir, contract) {
  file.path(candidate_dir, contract$runtime$root_sentinel)
}

is_commodity_project_root <- function(candidate_dir, contract) {
  candidate_dir <- normalize_commodity_path(candidate_dir)
  marker_path <- commodity_root_marker_path(candidate_dir, contract)
  if (!file.exists(marker_path)) {
    return(FALSE)
  }

  marker_lines <- readLines(marker_path, warn = FALSE)
  has_marker <- any(marker_lines == contract$runtime$clone_marker)
  has_entrypoint <- file.exists(file.path(candidate_dir, contract$runtime$entrypoint_file))
  has_programs <- dir.exists(file.path(candidate_dir, "Programs"))
  has_system <- dir.exists(file.path(candidate_dir, "System"))
  has_code_review <- dir.exists(file.path(candidate_dir, "Code Review"))

  has_marker && has_entrypoint && has_programs && has_system && has_code_review
}

find_commodity_project_root <- function(start_dir = commodity_script_dir(), contract, max_depth = 8L) {
  option_root <- getOption(contract_option_name(contract, "project_root"), default = NULL)
  if (!is.null(option_root) && length(option_root) > 0L && nzchar(option_root[[1]])) {
    candidate <- normalize_commodity_path(option_root[[1]])
    if (is_commodity_project_root(candidate, contract)) {
      return(candidate)
    }
    stop("Configured commodity project root is not a valid clone root.", call. = FALSE)
  }

  start_dir <- normalize_commodity_path(start_dir)
  candidate_dirs <- unique(vapply(
    0:max_depth,
    function(level) {
      normalize_commodity_path(do.call(file.path, as.list(c(start_dir, rep("..", level)))))
    },
    character(1)
  ))

  for (candidate_dir in candidate_dirs) {
    if (is_commodity_project_root(candidate_dir, contract)) {
      return(candidate_dir)
    }
  }

  stop("Commodity clone root sentinel not found from launch context.", call. = FALSE)
}

validate_commodity_project_root <- function(project_root, contract) {
  if (!is_commodity_project_root(project_root, contract)) {
    stop("Project root failed commodity clone sentinel validation.", call. = FALSE)
  }

  forbidden_entrypoints <- setdiff(contract$runtime$forbidden_entrypoint_files %||% character(), contract$runtime$entrypoint_file)
  forbidden_present <- forbidden_entrypoints[file.exists(file.path(project_root, forbidden_entrypoints))]
  if (length(forbidden_present) > 0L) {
    stop(sprintf("Forbidden entrypoint(s) found in clone root: %s", paste(forbidden_present, collapse = ", ")), call. = FALSE)
  }

  invisible(TRUE)
}

commodity_runtime_marker_ready <- function(project_root, contract) {
  marker_path <- commodity_root_marker_path(project_root, contract)
  if (!file.exists(marker_path)) {
    return(FALSE)
  }

  marker_lines <- readLines(marker_path, warn = FALSE)
  any(marker_lines == "RUNTIME_SOURCE_READY=TRUE")
}

commodity_runtime_source_ready <- function(project_root, contract) {
  if (!commodity_runtime_marker_ready(project_root, contract)) {
    return(FALSE)
  }

  app_source_dir <- file.path(project_root, "Programs", "app_source")
  server_dir <- file.path(app_source_dir, "server")
  required_files <- c(
    file.path(app_source_dir, "global.R"),
    file.path(app_source_dir, "ui.R"),
    file.path(server_dir, sprintf("%02d_%s.R", 1:6, c(
      "state_and_custom_types",
      "partner_and_notes",
      "core_reactives_and_ui",
      "comparison_plots",
      "trend_and_heatmap",
      "pace_analysis_and_reset"
    )))
  )

  all(file.exists(required_files))
}

commodity_runtime_not_ready_message <- function(project_root, contract) {
  sprintf(
    "%s scaffold found at %s, but runtime source is intentionally disabled until commodity contract validation and runtime isolation are implemented.",
    contract$labels$app_name,
    normalize_commodity_path(project_root)
  )
}

`%||%` <- function(value, fallback) {
  if (is.null(value)) {
    fallback
  } else {
    value
  }
}