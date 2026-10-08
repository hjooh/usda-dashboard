`%||%` <- function(x, y) {
  if (!is.null(x)) x else y
}

script_args <- commandArgs(trailingOnly = FALSE)
script_file_arg <- grep("^--file=", script_args, value = TRUE)
script_file <- if (length(script_file_arg) > 0L) sub("^--file=", "", script_file_arg[[1L]]) else "System/Testing/ftn_validated_unit_guardrail_fixture.R"
script_file <- normalizePath(script_file, winslash = "/", mustWork = TRUE)
repo_root <- normalizePath(file.path(dirname(script_file), "..", ".."), winslash = "/", mustWork = TRUE)
helper_path <- file.path(repo_root, "Programs", "app_source", "server", "02_partner_and_notes.R")

extract_assignment <- function(lines, object_name) {
  start_pattern <- paste0("^\\s*", object_name, "\\s*<-\\s*function\\b")
  start <- grep(start_pattern, lines, perl = TRUE)[[1L]]
  depth <- 0L
  saw_open <- FALSE

  for (end in seq.int(start, length(lines))) {
    line <- lines[[end]]
    depth <- depth + lengths(regmatches(line, gregexpr("\\{", line, perl = TRUE)))
    depth <- depth - lengths(regmatches(line, gregexpr("\\}", line, perl = TRUE)))
    saw_open <- saw_open || grepl("\\{", line, perl = TRUE)
    if (saw_open && depth == 0L) {
      return(lines[start:end])
    }
  }

  stop(sprintf("Unable to extract helper assignment: %s", object_name), call. = FALSE)
}

load_helper_assignment <- function(object_name, env) {
  helper_lines <- readLines(helper_path, warn = FALSE)
  expression_text <- paste(extract_assignment(helper_lines, object_name), collapse = "\n")
  eval(parse(text = expression_text), envir = env)
}

assert_true <- function(value, label) {
  if (!isTRUE(value)) {
    stop(sprintf("Assertion failed: %s", label), call. = FALSE)
  }
}

assert_identical <- function(actual, expected, label) {
  if (!identical(actual, expected)) {
    stop(
      sprintf(
        "Assertion failed: %s\nExpected: %s\nActual: %s",
        label,
        paste(capture.output(str(expected)), collapse = " "),
        paste(capture.output(str(actual)), collapse = " ")
      ),
      call. = FALSE
    )
  }
}

helper_env <- new.env(parent = globalenv())
helper_env$`%||%` <- `%||%`
for (helper_name in c(
  "resolve_display_unit",
  "build_unit_resolution_context",
  "unit_guardrail_event_message",
  "unit_guardrail_events_get",
  "unit_guardrail_events_clear",
  "unit_guardrail_record_event"
)) {
  load_helper_assignment(helper_name, helper_env)
}

clean_weight <- helper_env$resolve_display_unit(
  metric = "unit_value",
  source = "vp_trade",
  rows = data.frame(
    unit_value = c(1.25, 2.50, NA_real_),
    unit_value_unit = c("Dollars per pound", "Dollars per pound", "Dollars per gallon"),
    stringsAsFactors = FALSE
  )
)
assert_identical(clean_weight$status, "ok", "clean weight status")
assert_identical(clean_weight$label, "Dollars per pound", "clean weight label")
assert_identical(clean_weight$units, "Dollars per pound", "clean weight units")

clean_liquid <- helper_env$resolve_display_unit(
  metric = "ytd_unit_value",
  source = "vp_trade",
  rows = data.frame(
    ytd_unit_value = c(4.5, 5.5),
    ytd_unit_value_unit = c("Dollars per gallon", "Dollars per gallon"),
    stringsAsFactors = FALSE
  )
)
assert_identical(clean_liquid$status, "ok", "clean liquid status")
assert_identical(clean_liquid$label, "Dollars per gallon", "clean liquid label")

mixed_units <- helper_env$resolve_display_unit(
  metric = "unit_value",
  source = "vp_trade",
  rows = data.frame(
    unit_value = c(1.25, 2.50),
    unit_value_unit = c("Dollars per pound", "Dollars per gallon"),
    stringsAsFactors = FALSE
  ),
  context = helper_env$build_unit_resolution_context(
    tab_id = "fixture_tab",
    output_id = "fixture_output",
    source_choice = "vp_trade",
    metric_code = "unit_value",
    trade_flow = "export",
    hierarchy_path = "Fruit|All - excluding juice",
    country_scope = "World",
    market_scope = "CY 2025",
    rollup_level = "All - excluding juice",
    rollup_path = "Fruit|All - excluding juice",
    run_id = "unit_guardrail_fixture"
  )
)
assert_identical(mixed_units$status, "mixed_unit_anomaly", "mixed units status")
assert_identical(mixed_units$label, "Mixed unit values", "mixed units label")
assert_identical(mixed_units$units, c("Dollars per gallon", "Dollars per pound"), "mixed units sorted set")
assert_identical(
  mixed_units$message,
  "Multiple display units were observed for one unit-value metric context.",
  "mixed units resolver message"
)
assert_identical(
  helper_env$unit_guardrail_event_message(mixed_units$status, mixed_units$message),
  "Unit guardrail: mixed unit values detected; review All - excluding juice routing.",
  "mixed units deterministic event message"
)

missing_field <- helper_env$resolve_display_unit(
  metric = "unit_value",
  source = "vp_trade",
  rows = data.frame(unit_value = c(1.25, 2.50), stringsAsFactors = FALSE)
)
assert_identical(missing_field$status, "missing_unit_anomaly", "missing unit field status")
assert_identical(missing_field$message, "Expected unit field missing from rows: unit_value_unit", "missing unit field message")

missing_units <- helper_env$resolve_display_unit(
  metric = "unit_value",
  source = "vp_trade",
  rows = data.frame(
    unit_value = c(1.25, 2.50),
    unit_value_unit = c("", NA_character_),
    stringsAsFactors = FALSE
  )
)
assert_identical(missing_units$status, "missing_unit_anomaly", "missing unit labels status")
assert_identical(missing_units$message, "Finite unit-value rows are present but display unit labels are missing.", "missing unit labels message")

partial_missing <- helper_env$resolve_display_unit(
  metric = "unit_value",
  source = "vp_trade",
  rows = data.frame(
    unit_value = c(1.25, 2.50),
    unit_value_unit = c("Dollars per pound", ""),
    stringsAsFactors = FALSE
  )
)
assert_identical(partial_missing$status, "missing_unit_anomaly", "partial missing unit status")
assert_identical(partial_missing$label, "Dollars per pound", "partial missing unit label")
assert_identical(partial_missing$message, "Some finite unit-value rows are missing unit labels.", "partial missing unit message")

non_vp_source <- helper_env$resolve_display_unit(
  metric = "unit_value",
  source = "fas",
  rows = data.frame(unit_value = 1, unit_value_unit = "Dollars per pound", stringsAsFactors = FALSE)
)
assert_identical(non_vp_source$status, "fallback", "non-vp source fallback")

non_unit_metric <- helper_env$resolve_display_unit(
  metric = "quantity",
  source = "vp_trade",
  rows = data.frame(quantity = 1, unit_value_unit = "Dollars per pound", stringsAsFactors = FALSE)
)
assert_identical(non_unit_metric$status, "fallback", "non-unit metric fallback")
assert_identical(non_unit_metric$message, "Metric is not a vp_trade unit-value metric.", "non-unit metric message")

multi_metric <- helper_env$resolve_display_unit(
  metric = c("unit_value", "ytd_unit_value"),
  source = "vp_trade",
  rows = data.frame(unit_value = 1, unit_value_unit = "Dollars per pound", stringsAsFactors = FALSE)
)
assert_identical(multi_metric$status, "multi_metric", "multi metric status")
assert_identical(multi_metric$context$metric_count, 2L, "multi metric count")

session_domain <- new.env(parent = emptyenv())
session_domain$userData <- new.env(parent = emptyenv())
helper_env$unit_guardrail_events_clear(session_domain = session_domain)
event_row <- helper_env$unit_guardrail_record_event(
  unit_resolution = mixed_units,
  session_domain = session_domain
)
assert_true(is.data.frame(event_row) && nrow(event_row) == 1L, "event row recorded")
assert_identical(event_row$status, "mixed_unit_anomaly", "event status")
assert_identical(event_row$output_id, "fixture_output", "event output id")
assert_identical(event_row$message, "Unit guardrail: mixed unit values detected; review All - excluding juice routing.", "event message")
assert_identical(event_row$units, "Dollars per gallon|Dollars per pound", "event unit set")

helper_env$unit_guardrail_record_event(
  unit_resolution = mixed_units,
  session_domain = session_domain
)
events_after_duplicate <- helper_env$unit_guardrail_events_get(session_domain = session_domain)
assert_identical(nrow(events_after_duplicate), 1L, "duplicate event dedupe")

cat("FTN_UNIT_GUARDRAIL_FIXTURE_STATUS=PASS\n")