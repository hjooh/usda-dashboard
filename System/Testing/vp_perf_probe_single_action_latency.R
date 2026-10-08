library(shinytest2)
source(file.path("System", "Testing", "vp_perf_acceptance_manifest.R"), local = TRUE)

`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0L) y else x
}

to_int_ms <- function(start_time, end_time = Sys.time()) {
  elapsed_seconds <- suppressWarnings(as.numeric(difftime(end_time, start_time, units = "secs")))
  if (!is.finite(elapsed_seconds)) return(NA_integer_)
  as.integer(round(elapsed_seconds * 1000))
}

is_truthy <- function(value, default = FALSE) {
  if (is.null(value) || length(value) == 0L || all(is.na(value))) return(default)
  normalized <- tolower(trimws(as.character(value[[1L]])))
  if (!nzchar(normalized)) return(default)
  normalized %in% c("1", "true", "yes", "y", "on")
}

parse_arg_value <- function(args, key, default = NULL) {
  prefix <- paste0("--", key, "=")
  hits <- args[startsWith(args, prefix)]
  if (length(hits) == 0L) return(default)
  sub(prefix, "", hits[[length(hits)]], fixed = TRUE)
}

normalize_cache_state <- function(value, default = "unknown_cache_state") {
  normalized <- trimws(as.character(value %||% default))
  if (!nzchar(normalized)) return(default)
  normalized
}

normalize_comparison_plot_cache_off <- function(value, default = FALSE) {
  isTRUE(is_truthy(value, default = default))
}

comparison_plot_cache_mode_from_flag <- function(cache_off) {
  if (isTRUE(cache_off)) "final_output_cache_off" else "final_output_cache_on"
}

is_unknown_cache_state <- function(value) {
  identical(tolower(normalize_cache_state(value)), "unknown_cache_state")
}

emit_probe <- function(key, value = NULL) {
  if (is.null(value)) {
    cat(sprintf("VP_PERF_SINGLE_ACTION_%s\n", key))
  } else {
    cat(sprintf("VP_PERF_SINGLE_ACTION_%s=%s\n", key, value))
  }
  flush.console()
}

js_string <- function(value) {
  value <- as.character(value %||% "")
  value <- gsub("\\", "\\\\", value, fixed = TRUE)
  value <- gsub("'", "\\'", value, fixed = TRUE)
  paste0("'", value, "'")
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

  stop("Could not resolve repository root for VP single-action probe.", call. = FALSE)
}

dom_exists <- function(app, id_value) {
  script <- sprintf(
    "(function(){ var id=%s; var docs=[document]; for (var i=0;i<window.frames.length;i++){ try{ if(window.frames[i].document) docs.push(window.frames[i].document);}catch(e){} } for (var j=0;j<docs.length;j++){ try{ if(docs[j].getElementById(id)!==null) return true; } catch(e){} } return false; })();",
    js_string(id_value)
  )
  out <- tryCatch(app$get_js(script), error = function(...) FALSE)
  if (identical(out, TRUE)) return(TRUE)
  identical(tolower(trimws(as.character(out %||% ""))), "true")
}

safe_rds_row_count <- function(path) {
  if (is.null(path) || !nzchar(path) || !file.exists(path)) return(NA_integer_)
  object <- tryCatch(readRDS(path), error = function(...) NULL)
  if (is.data.frame(object)) return(nrow(object))
  if (is.list(object)) return(length(object))
  NA_integer_
}

get_select_choices <- function(app, input_id) {
  script <- sprintf(
    "(function(){ var id=%s; var docs=[document]; for (var i=0;i<window.frames.length;i++){ try{ if(window.frames[i].document) docs.push(window.frames[i].document);}catch(e){} } for (var j=0;j<docs.length;j++){ try{ var el=docs[j].getElementById(id); if(!el) continue; if (el.selectize && el.selectize.options) { var vals=Object.keys(el.selectize.options).map(function(x){ return (x || '').trim(); }).filter(function(x){ return x.length>0; }); return vals.join('|||'); } if (el.options) { var out=[]; for (var k=0;k<el.options.length;k++){ out.push((el.options[k].value || '').trim()); } return out.join('|||'); } }catch(e){} } return ''; })();",
    js_string(input_id)
  )
  out <- tryCatch(as.character(app$get_js(script) %||% ""), error = function(...) "")
  if (!nzchar(out)) return(character(0))
  values <- strsplit(out, "\\|\\|\\|", fixed = FALSE)[[1L]]
  values <- trimws(values)
  values[nzchar(values)]
}

get_input_value <- function(app, input_id) {
  script <- sprintf(
    "(function(){ var id=%s; var docs=[document]; for (var i=0;i<window.frames.length;i++){ try{ if(window.frames[i].document) docs.push(window.frames[i].document);}catch(e){} } for (var j=0;j<docs.length;j++){ try{ var doc=docs[j]; var el=doc.getElementById(id); if(!el) continue; if (el.selectize && el.selectize.getValue) return String(el.selectize.getValue() || ''); var checked=el.querySelector('input[name=\"' + id + '\"]:checked'); if(checked && typeof checked.value !== 'undefined') return String(checked.value || ''); if (typeof el.value !== 'undefined') return String(el.value || ''); }catch(e){} } return ''; })();",
    js_string(input_id)
  )
  value <- tryCatch(as.character(app$get_js(script) %||% ""), error = function(...) "")
  value <- trimws(value[[1L]] %||% "")
  if (!nzchar(value)) return(NA_character_)
  value
}

get_first_existing_input <- function(app, input_ids) {
  for (input_id in input_ids) {
    if (!isTRUE(dom_exists(app, input_id))) next
    value <- get_input_value(app, input_id)
    if (!is.na(value)) return(list(id = input_id, value = value))
  }
  list(id = NA_character_, value = NA_character_)
}

get_main_tab_value <- function(app) {
  script <- "(function(){ var docs=[document]; for (var i=0;i<window.frames.length;i++){ try{ if(window.frames[i].document) docs.push(window.frames[i].document);}catch(e){} } for (var j=0;j<docs.length;j++){ try{ var doc=docs[j]; var input=doc.getElementById('main_tabs_panel'); if(input && typeof input.value !== 'undefined' && String(input.value || '').trim().length>0) return String(input.value || '').trim(); var root=doc.getElementById('main_tabs'); var scope=root || doc; var active=scope.querySelector('.tabbable > .nav > li.active > a, .tabbable > .nav-tabs > li.active > a, .nav > li.active > a, .nav-tabs > li.active > a'); if(active){ var dataValue=active.getAttribute('data-value'); if(dataValue && dataValue.trim().length>0) return dataValue.trim(); var text=(active.textContent || '').trim(); if(text.length>0) return text; } }catch(e){} } return ''; })();"
  value <- tryCatch(as.character(app$get_js(script) %||% ""), error = function(...) "")
  value <- trimws(value[[1L]] %||% "")
  if (!nzchar(value)) return(NA_character_)
  value
}

output_snapshot <- function(app, output_id) {
  empty_snapshot <- paste(c("false", "false", rep("0", 9L), rep("", 9L)), collapse = "|")
  script <- sprintf(
    paste0(
      "(function(){ var id=%s; var docs=[document];",
      " function countMatches(root, selector){ var count=0; try{ if(root.matches && root.matches(selector)) count++; }catch(e){} try{ count += root.querySelectorAll(selector).length; }catch(e){} return count; }",
      " function outputState(root, selector){ var node=root; while(node){ try{ if(node.matches && node.matches(selector)) return true; }catch(e){} node=node.parentElement; } return false; }",
      " function arrLen(value){ if(value===null || typeof value === 'undefined') return 0; if(Array.isArray(value)) return value.length; if(typeof value.length === 'number') return value.length; return 0; }",
      " function matrixCells(value){ if(value===null || typeof value === 'undefined') return 0; if(!Array.isArray(value)) return arrLen(value); var total=0; for(var i=0;i<value.length;i++){ if(Array.isArray(value[i])) total += value[i].length; else if(value[i]!==null && typeof value[i] !== 'undefined') total++; } return total; }",
      " function boundedChars(value, budget){ if(value===null || typeof value === 'undefined' || budget.items<=0) return 0; if(typeof value === 'string') { budget.items--; return value.length; } if(typeof value === 'number' || typeof value === 'boolean') { budget.items--; return String(value).length; } if(Array.isArray(value)){ var total=0; var max=Math.min(value.length, budget.items); for(var i=0;i<max;i++){ total += boundedChars(value[i], budget); if(budget.items<=0) break; } return total; } return 0; }",
      " function firstPlotlyData(root){ var candidates=[]; try{ if(root.data) candidates.push(root); }catch(e){} try{ var nodes=root.querySelectorAll('.js-plotly-plot,.plotly-graph-div'); for(var i=0;i<nodes.length;i++) candidates.push(nodes[i]); }catch(e){} for(var j=0;j<candidates.length;j++){ try{ if(candidates[j].data) return candidates[j].data; }catch(e){} } return null; }",
      " function complexityFields(root, win){ var data=firstPlotlyData(root); if(!data || !Array.isArray(data)) return ['', '', '', '', '', '', '', '', '']; var traceCount=data.length; var pointCount=0; var cellCount=0; var arrayValueCount=0; var textChars=0; var customdataChars=0; for(var i=0;i<data.length;i++){ var trace=data[i] || {}; var xLen=arrLen(trace.x); var yLen=arrLen(trace.y); var zCells=matrixCells(trace.z); var textLen=arrLen(trace.text); var customCells=matrixCells(trace.customdata); cellCount += zCells; pointCount += zCells > 0 ? zCells : Math.max(xLen, yLen, textLen, customCells); arrayValueCount += xLen + yLen + zCells + textLen + customCells; textChars += boundedChars(trace.text, {items:5000}) + boundedChars(trace.hovertext, {items:5000}) + boundedChars(trace.name, {items:100}) + boundedChars(trace.hovertemplate, {items:100}); customdataChars += boundedChars(trace.customdata, {items:5000}); } var mem=(win.performance && win.performance.memory) ? win.performance.memory : null; return [traceCount, pointCount, cellCount, arrayValueCount, textChars, customdataChars, mem ? Math.round(mem.usedJSHeapSize || 0) : '', mem ? Math.round(mem.totalJSHeapSize || 0) : '', mem ? Math.round(mem.jsHeapSizeLimit || 0) : '']; }",
      " for (var i=0;i<window.frames.length;i++){ try{ if(window.frames[i].document) docs.push(window.frames[i].document);}catch(e){} }",
      " for (var j=0;j<docs.length;j++){ try{ var el=docs[j].getElementById(id); if(!el) continue; var win=docs[j].defaultView; var rect=el.getBoundingClientRect(); var style=win.getComputedStyle(el); var visible=style.display!=='none' && style.visibility!=='hidden' && Number(style.opacity || 1)>0 && rect.width>0 && rect.height>0; var widgets=countMatches(el,'.plotly.html-widget,.html-widget,.dataTables_wrapper,table.dataTable'); var plotly=countMatches(el,'.plotly,.plotly-graph-div,.js-plotly-plot'); var mainSvg=countMatches(el,'.main-svg'); var svgContainer=countMatches(el,'.svg-container'); var loading=countMatches(el,'.shiny-output-error,.shiny-output-error-validation,.load-container,.loading,.recalculating') + (outputState(el,'.recalculating') ? 1 : 0); var text=(el.textContent || '').trim().length; var state=win.__vpSingleActionProbe || {}; var byId=state.plotlyAfterplotById || {}; var afterplot=Number(byId[id] || 0); return ['true', visible ? 'true' : 'false', Math.round(rect.width), Math.round(rect.height), widgets, text, plotly, mainSvg, svgContainer, loading, afterplot].concat(complexityFields(el, win)).join('|'); }catch(e){} }",
      " return %s; })();"
    ),
    js_string(output_id),
    js_string(empty_snapshot)
  )
  raw <- tryCatch(as.character(app$get_js(script) %||% empty_snapshot), error = function(...) empty_snapshot)
  parts <- strsplit(raw[[1L]], "|", fixed = TRUE)[[1L]]
  parts <- c(parts, rep("", 20L))[seq_len(20L)]
  list(
    present = identical(parts[[1L]], "true"),
    visible = identical(parts[[2L]], "true"),
    width = suppressWarnings(as.integer(parts[[3L]])),
    height = suppressWarnings(as.integer(parts[[4L]])),
    widget_count = suppressWarnings(as.integer(parts[[5L]])),
    text_length = suppressWarnings(as.integer(parts[[6L]])),
    plotly_node_count = suppressWarnings(as.integer(parts[[7L]])),
    plotly_main_svg_count = suppressWarnings(as.integer(parts[[8L]])),
    plotly_svg_container_count = suppressWarnings(as.integer(parts[[9L]])),
    loading_indicator_count = suppressWarnings(as.integer(parts[[10L]])),
    plotly_afterplot_count = suppressWarnings(as.integer(parts[[11L]])),
    plotly_trace_count = suppressWarnings(as.integer(parts[[12L]])),
    plotly_point_count = suppressWarnings(as.integer(parts[[13L]])),
    plotly_cell_count = suppressWarnings(as.integer(parts[[14L]])),
    plotly_array_value_count = suppressWarnings(as.integer(parts[[15L]])),
    plotly_text_chars_est = suppressWarnings(as.integer(parts[[16L]])),
    plotly_customdata_chars_est = suppressWarnings(as.integer(parts[[17L]])),
    js_heap_used_size = suppressWarnings(as.integer(parts[[18L]])),
    js_heap_total_size = suppressWarnings(as.integer(parts[[19L]])),
    js_heap_size_limit = suppressWarnings(as.integer(parts[[20L]]))
  )
}

browser_diagnostics <- function(app) {
  script <- "(function(){ try { var state=window.__vpSingleActionProbe || {}; var busy=document.querySelectorAll('.shiny-busy').length + (document.body && document.body.classList.contains('shiny-busy') ? 1 : 0); var plotly=document.querySelectorAll('.plotly,.plotly-graph-div').length; var widgets=document.querySelectorAll('.html-widget,.plotly.html-widget,.dataTables_wrapper,table.dataTable').length; return [document.getElementsByTagName('*').length,busy,plotly,widgets,state.busy||0,state.idle||0,state.inputChanged||0,state.plotlyAfterplot||0,state.plotlyRelayout||0,state.mutations||0].join('|'); } catch(e) { return '0|0|0|0|0|0|0|0|0|0'; } })();"
  raw <- tryCatch(as.character(app$get_js(script) %||% "0|0|0|0|0|0|0|0|0|0"), error = function(...) "0|0|0|0|0|0|0|0|0|0")
  parts <- strsplit(raw[[1L]], "|", fixed = TRUE)[[1L]]
  parts <- suppressWarnings(as.integer(c(parts, rep(NA_character_, 10L))[seq_len(10L)]))
  list(
    dom_node_count = parts[[1L]],
    shiny_busy_count = parts[[2L]],
    plotly_node_count = parts[[3L]],
    html_widget_count = parts[[4L]],
    client_busy_events = parts[[5L]],
    client_idle_events = parts[[6L]],
    client_input_changed_events = parts[[7L]],
    client_plotly_afterplot_events = parts[[8L]],
    client_plotly_relayout_events = parts[[9L]],
    client_mutation_events = parts[[10L]]
  )
}

install_browser_observers <- function(app) {
  script <- paste0(
    "(function(){",
    " if (window.__vpSingleActionProbeInstalled) return true;",
    " window.__vpSingleActionProbeInstalled=true;",
    " window.__vpSingleActionProbe={busy:0,idle:0,inputChanged:0,plotlyAfterplot:0,plotlyRelayout:0,mutations:0,plotlyAfterplotById:{},plotlyRelayoutById:{}};",
    " function nearestId(target){ var node=target; while(node){ if(node.id) return node.id; node=node.parentElement; } return ''; }",
    " function expectedElement(){ var timeline=window.__vpSingleActionTimeline || {}; var expected=timeline.expectedOutputId || ''; return expected ? document.getElementById(expected) : null; }",
    " function matchesExpected(target, expected){ try { var el=document.getElementById(expected); return !!(el && target && (target===el || (el.contains && el.contains(target)))); } catch(error) { return false; } }",
    " function eventOutputId(event, target){ var timeline=window.__vpSingleActionTimeline || {}; var expected=timeline.expectedOutputId || ''; var eventName=event && (event.name || event.outputId || event.output_id); if(expected && eventName && String(eventName).replace(/^output_/, '')===expected.replace(/^output_/, '')) return expected; if(expected && target && matchesExpected(target, expected)) return expected; var expectedNode=expectedElement(); if(expectedNode && event && event.binding && event.binding.el && matchesExpected(event.binding.el, expected)) return expected; return nearestId(target); }",
    " function mark(name,target,event){ var timeline=window.__vpSingleActionTimeline; if(!timeline) return; var id=eventOutputId(event || null, target || null); var expected=timeline.expectedOutputId || ''; var match=!!(expected && id===expected); if(!id){ timeline.unattributed=(timeline.unattributed||0)+1; } else if(expected && id!==expected){ timeline.mismatched=(timeline.mismatched||0)+1; } var ms=Math.round(performance.now()-(timeline.zero||performance.now())); if(timeline.marks[name]===null || typeof timeline.marks[name] === 'undefined') timeline.marks[name]=ms; timeline.lastMs=ms; timeline.events=timeline.events||[]; if(timeline.events.length<240) timeline.events.push(name+'@'+ms+'#'+(id||'')+'#'+(match?'1':'0')); }",
    " function checkOutput(outputId){ var timeline=window.__vpSingleActionTimeline; if(!timeline || !outputId) return; var el=document.getElementById(outputId); if(!el) return; var rect=el.getBoundingClientRect(); var style=window.getComputedStyle(el); var visible=style.display!=='none' && style.visibility!=='hidden' && Number(style.opacity || 1)>0 && rect.width>0 && rect.height>0; if(visible) mark('output_visible_nonzero', el, null); if(el.matches('.plotly.html-widget,.html-widget,.dataTables_wrapper,table.dataTable') || el.querySelector('.plotly.html-widget,.html-widget,.dataTables_wrapper,table.dataTable')) mark('widget_inserted', el, null); if(el.matches('.main-svg') || el.querySelector('.main-svg')) mark('main_svg_inserted', el, null); if(!(el.matches('.shiny-output-error,.shiny-output-error-validation,.load-container,.loading,.recalculating') || el.querySelector('.shiny-output-error,.shiny-output-error-validation,.load-container,.loading,.recalculating'))) mark('loading_indicator_cleared', el, null); }",
    " window.__vpSingleActionProbeMark=function(name,target){ mark(name,target||null,null); };",
    " window.__vpSingleActionProbeCheckOutput=checkOutput;",
    " document.addEventListener('shiny:busy', function(event){ window.__vpSingleActionProbe.busy++; mark('shiny_busy_first', event.target, event); }, true);",
    " document.addEventListener('shiny:idle', function(event){ window.__vpSingleActionProbe.idle++; mark('shiny_idle_last', event.target, event); }, true);",
    " document.addEventListener('shiny:value', function(event){ mark('shiny_value_output', event.target, event); }, true);",
    " document.addEventListener('change', function(){ window.__vpSingleActionProbe.inputChanged++; }, true);",
    " document.addEventListener('plotly_afterplot', function(event){ var id=eventOutputId(event, event.target); window.__vpSingleActionProbe.plotlyAfterplot++; if(id) window.__vpSingleActionProbe.plotlyAfterplotById[id]=(window.__vpSingleActionProbe.plotlyAfterplotById[id] || 0) + 1; mark('plotly_afterplot', event.target, event); }, true);",
    " document.addEventListener('plotly_relayout', function(event){ var id=eventOutputId(event, event.target); window.__vpSingleActionProbe.plotlyRelayout++; if(id) window.__vpSingleActionProbe.plotlyRelayoutById[id]=(window.__vpSingleActionProbe.plotlyRelayoutById[id] || 0) + 1; mark('plotly_relayout', event.target, event); }, true);",
    " if(window.jQuery){ window.jQuery(document).on('shown.bs.tab','.tabbable > .nav > li > a, .tabbable > .nav-tabs > li > a',function(){ var anchor=this; mark('tab_shown', anchor, null); window.requestAnimationFrame(function(){ mark('tab_after_paint', anchor, null); }); }); window.jQuery(document).on('shiny:value', function(event){ mark('shiny_value_output', event.target, event); }); window.jQuery(document).on('plotly_afterplot', function(event){ var id=eventOutputId(event, event.target); window.__vpSingleActionProbe.plotlyAfterplot++; if(id) window.__vpSingleActionProbe.plotlyAfterplotById[id]=(window.__vpSingleActionProbe.plotlyAfterplotById[id] || 0) + 1; mark('plotly_afterplot', event.target, event); }); window.jQuery(document).on('plotly_relayout', function(event){ var id=eventOutputId(event, event.target); window.__vpSingleActionProbe.plotlyRelayout++; if(id) window.__vpSingleActionProbe.plotlyRelayoutById[id]=(window.__vpSingleActionProbe.plotlyRelayoutById[id] || 0) + 1; mark('plotly_relayout', event.target, event); }); }",
    " try { var observer=new MutationObserver(function(mutations){ window.__vpSingleActionProbe.mutations += mutations.length; var timeline=window.__vpSingleActionTimeline; if(!timeline) return; for(var index=0; index<mutations.length; index++){ var mutation=mutations[index]; if(matchesExpected(mutation.target, timeline.expectedOutputId)){ mark('output_first_mutation', mutation.target, null); checkOutput(timeline.expectedOutputId); break; } } }); observer.observe(document.body || document.documentElement, {childList:true,subtree:true,attributes:true}); window.__vpSingleActionProbeObserver=observer; } catch(error) {}",
    " return true;",
    "})();"
  )
  tryCatch(isTRUE(app$get_js(script)), error = function(...) FALSE)
}

begin_action_timeline <- function(app, action_id, output_id, target_tab) {
  script <- sprintf(
    "(function(){ window.__vpSingleActionTimeline={actionId:%s,expectedOutputId:%s,targetTab:%s,zero:performance.now(),marks:{},events:[],unattributed:0,mismatched:0,lastMs:null}; if(window.__vpSingleActionProbeCheckOutput) window.__vpSingleActionProbeCheckOutput(%s); return true; })();",
    js_string(action_id),
    js_string(output_id),
    js_string(target_tab %||% ""),
    js_string(output_id)
  )
  tryCatch(isTRUE(app$get_js(script)), error = function(...) FALSE)
}

set_probe_action_context <- function(app, action_id, action_kind, target_id, target_value, output_id, target_tab, enabled = FALSE) {
  if (!isTRUE(enabled)) return(invisible(FALSE))

  script <- sprintf(
    paste0(
      "(function(){",
      " if (typeof Shiny === 'undefined' || !Shiny.setInputValue) return false;",
      " Shiny.setInputValue('vp_perf_probe_action_context', {",
      "action_id:%s, mutation_seq:null, action_kind:%s, target_id:%s, target_value:%s, target_output_id:%s, target_tab:%s, ",
      "context_source:'single_action_probe', context_status:'available', evidence_class:'exact_probe_action_context', missing_reason:null, nonce:%s",
      "}, {priority:'event'});",
      " return true;",
      "})();"
    ),
    js_string(as.character(action_id %||% "")),
    js_string(as.character(action_kind %||% "")),
    js_string(as.character(target_id %||% "")),
    js_string(as.character(target_value %||% "")),
    js_string(as.character(output_id %||% "")),
    js_string(as.character(target_tab %||% "")),
    js_string(paste(as.numeric(Sys.time()), sample.int(.Machine$integer.max, 1L), sep = "_"))
  )
  ok <- tryCatch(isTRUE(app$get_js(script)), error = function(...) FALSE)
  if (isTRUE(ok)) {
    soft_wait_for_idle(app, timeout_ms = 2000L)
  }
  invisible(ok)
}

record_action_timeline_mark <- function(app, mark_name, output_id = NULL) {
  target_expr <- if (!is.null(output_id) && nzchar(output_id)) {
    sprintf("document.getElementById(%s)", js_string(output_id))
  } else {
    "null"
  }
  script <- sprintf(
    "(function(){ if(window.__vpSingleActionProbeMark){ window.__vpSingleActionProbeMark(%s,%s); } return true; })();",
    js_string(mark_name),
    target_expr
  )
  tryCatch(isTRUE(app$get_js(script)), error = function(...) FALSE)
}

update_action_timeline_output <- function(app, output_id) {
  script <- sprintf(
    "(function(){ if(window.__vpSingleActionProbeCheckOutput){ window.__vpSingleActionProbeCheckOutput(%s); } return true; })();",
    js_string(output_id)
  )
  tryCatch(isTRUE(app$get_js(script)), error = function(...) FALSE)
}

action_timeline_snapshot <- function(app) {
  script <- "(function(){ var tl=window.__vpSingleActionTimeline || {}; var marks=tl.marks || {}; function val(name){ var value=marks[name]; return (value===null || typeof value === 'undefined') ? '' : String(value); } return [tl.actionId||'',tl.expectedOutputId||'',tl.targetTab||'',String((tl.events||[]).length),String(tl.unattributed||0),String(tl.mismatched||0),val('tab_click_dispatched'),val('target_accepted'),val('tab_shown'),val('tab_after_paint'),val('shiny_busy_first'),val('shiny_idle_last'),val('shiny_value_output'),val('output_first_mutation'),val('output_visible_nonzero'),val('widget_inserted'),val('main_svg_inserted'),val('plotly_afterplot'),val('plotly_relayout'),val('loading_indicator_cleared'),val('readiness_predicate_passed'),val('client_echo_ready'),(tl.lastMs===null || typeof tl.lastMs === 'undefined') ? '' : String(tl.lastMs),(tl.events||[]).join(';')].join('|'); })();"
  raw <- tryCatch(as.character(app$get_js(script) %||% ""), error = function(...) "")
  parts <- strsplit(raw[[1L]] %||% "", "|", fixed = TRUE)[[1L]]
  parts <- c(parts, rep("", 24L))[seq_len(24L)]
  parse_ms <- function(value) {
    out <- suppressWarnings(as.integer(value))
    if (is.na(out)) NA_integer_ else out
  }
  list(
    action_id = parts[[1L]],
    expected_output_id = parts[[2L]],
    target_tab = parts[[3L]],
    event_count = parse_ms(parts[[4L]]),
    unattributed_event_count = parse_ms(parts[[5L]]),
    mismatched_event_count = parse_ms(parts[[6L]]),
    tab_click_dispatched_ms = parse_ms(parts[[7L]]),
    target_accepted_ms = parse_ms(parts[[8L]]),
    tab_shown_ms = parse_ms(parts[[9L]]),
    tab_after_paint_ms = parse_ms(parts[[10L]]),
    shiny_busy_first_ms = parse_ms(parts[[11L]]),
    shiny_idle_last_ms = parse_ms(parts[[12L]]),
    shiny_value_output_ms = parse_ms(parts[[13L]]),
    output_first_mutation_ms = parse_ms(parts[[14L]]),
    output_visible_nonzero_ms = parse_ms(parts[[15L]]),
    widget_inserted_ms = parse_ms(parts[[16L]]),
    main_svg_inserted_ms = parse_ms(parts[[17L]]),
    plotly_afterplot_ms = parse_ms(parts[[18L]]),
    plotly_relayout_ms = parse_ms(parts[[19L]]),
    loading_indicator_cleared_ms = parse_ms(parts[[20L]]),
    readiness_predicate_passed_ms = parse_ms(parts[[21L]]),
    client_echo_ready_ms = parse_ms(parts[[22L]]),
    last_event_ms = parse_ms(parts[[23L]]),
    events = parts[[24L]]
  )
}

soft_wait_for_idle <- function(app, timeout_ms) {
  wait_ok <- TRUE
  wait_message <- ""
  tryCatch(
    app$wait_for_idle(timeout = timeout_ms),
    error = function(error) {
      wait_ok <<- FALSE
      wait_message <<- conditionMessage(error)
    }
  )

  list(ok = wait_ok, message = gsub("\n", " | ", wait_message, fixed = TRUE))
}

wait_for_condition <- function(stage_name, timeout_ms, predicate, interval_ms = 250L) {
  emit_probe("STAGE_BEGIN", stage_name)
  stage_start <- Sys.time()
  ok <- FALSE
  message <- "timeout"

  repeat {
    check <- tryCatch(predicate(), error = function(error) {
      message <<- conditionMessage(error)
      FALSE
    })
    if (isTRUE(check)) {
      ok <- TRUE
      message <- "ok"
      break
    }
    if (to_int_ms(stage_start) >= timeout_ms) break
    Sys.sleep(max(interval_ms, 50L) / 1000)
  }

  result <- list(ok = isTRUE(ok), message = message, elapsed_ms = to_int_ms(stage_start))
  emit_probe("STAGE_END", paste0(stage_name, "|ok=", isTRUE(result$ok), "|elapsed_ms=", result$elapsed_ms))
  result
}

set_input_no_wait <- function(app, input_id, value) {
  args <- c(setNames(list(value), input_id), list(wait_ = FALSE))
  do.call(app$set_inputs, args)
}

click_main_tab_no_wait <- function(app, tab_value) {
  script <- sprintf(
    "(function(){ var requested=%s; var docs=[document]; for (var i=0;i<window.frames.length;i++){ try{ if(window.frames[i].document) docs.push(window.frames[i].document);}catch(e){} } for (var j=0;j<docs.length;j++){ try{ var doc=docs[j]; var input=doc.getElementById('main_tabs_panel'); var root=doc.getElementById('main_tabs'); var scope=root || (input ? input.closest('.tabbable') : null) || doc; var anchors=scope.querySelectorAll('.tabbable > .nav > li > a, .tabbable > .nav-tabs > li > a, .nav > li > a, .nav-tabs > li > a'); for (var k=0;k<anchors.length;k++){ var anchor=anchors[k]; var dataValue=(anchor.getAttribute('data-value') || '').trim(); var text=(anchor.textContent || '').trim(); if (dataValue===requested || text===requested) { if (typeof anchor.click === 'function') { anchor.click(); } else { anchor.dispatchEvent(new MouseEvent('click', {bubbles:true, cancelable:true, view:doc.defaultView || window})); } return 'clicked'; } } }catch(e){} } return 'missing'; })();",
    js_string(tab_value)
  )
  result <- tryCatch(as.character(app$get_js(script) %||% "error"), error = function(error) paste("error", conditionMessage(error), sep = ":"))
  if (!identical(result[[1L]], "clicked")) {
    stop(sprintf("Could not click main tab '%s': %s", tab_value, result[[1L]]), call. = FALSE)
  }
  invisible(TRUE)
}

pick_specific_choice <- function(choices, preferred = character(0), excluded = c("__all__", "All", "", "GRAND_TOTAL"), allow_fallback_first = TRUE) {
  candidate_values <- choices[!(choices %in% excluded)]
  for (preferred_value in preferred) {
    if (preferred_value %in% candidate_values) return(preferred_value)
  }
  if (length(candidate_values) == 0L || !isTRUE(allow_fallback_first)) return(NA_character_)
  candidate_values[[1L]]
}

choice_sample <- function(choices, limit = 10L) {
  if (length(choices) == 0L) return("")
  paste(utils::head(choices, limit), collapse = "|")
}

wait_for_dependent_choice <- function(app, stage_name, downstream_id, target_value, upstream_id, upstream_value, timeout_ms) {
  stable_hits <- 0L
  last_choices <- character(0)
  last_upstream_value <- NA_character_

  wait <- wait_for_condition(
    stage_name,
    timeout_ms = timeout_ms,
    predicate = function() {
      last_choices <<- get_select_choices(app, downstream_id)
      last_upstream_value <<- get_input_value(app, upstream_id)
      target_present <- target_value %in% last_choices
      upstream_stable <- identical(last_upstream_value, upstream_value)
      if (isTRUE(target_present) && isTRUE(upstream_stable)) {
        stable_hits <<- stable_hits + 1L
      } else {
        stable_hits <<- 0L
      }
      stable_hits >= 2L
    }
  )

  final_choices <- get_select_choices(app, downstream_id)
  final_upstream_value <- get_input_value(app, upstream_id)
  list(
    ok = isTRUE(wait$ok),
    message = wait$message,
    elapsed_ms = wait$elapsed_ms,
    downstream_id = downstream_id,
    target_value = target_value,
    upstream_id = upstream_id,
    upstream_value = upstream_value,
    upstream_current_value = final_upstream_value,
    target_present = target_value %in% final_choices,
    choices_count = length(final_choices),
    choices_sample = choice_sample(final_choices),
    stable_polls = stable_hits
  )
}

is_plot_output_id <- function(output_id) {
  grepl("_plot$", output_id %||% "")
}

snapshot_ready <- function(snapshot, output_id) {
  base_ready <- isTRUE(snapshot$present) &&
    isTRUE(snapshot$visible) &&
    isTRUE((snapshot$loading_indicator_count %||% 0L) == 0L)
  if (!isTRUE(base_ready)) return(FALSE)

  if (isTRUE(is_plot_output_id(output_id))) {
    return((snapshot$widget_count %||% 0L) > 0L ||
      (snapshot$plotly_node_count %||% 0L) > 0L ||
      (snapshot$plotly_main_svg_count %||% 0L) > 0L)
  }

  (snapshot$widget_count %||% 0L) > 0L || (snapshot$text_length %||% 0L) > 0L
}

is_output_ready <- function(app, output_id) {
  update_action_timeline_output(app, output_id)
  snapshot <- output_snapshot(app, output_id)
  ready <- snapshot_ready(snapshot, output_id)
  if (isTRUE(ready)) {
    record_action_timeline_mark(app, "readiness_predicate_passed", output_id)
  }
  ready
}

client_echo_ready <- function(app) {
  token <- paste0("echo_", as.integer(stats::runif(1L, min = 100000L, max = 999999L)))
  script <- sprintf(
    "(function(){ try { var token=%s; window.__vpSingleActionProbeEcho=token; var done=false; requestAnimationFrame(function(){ window.__vpSingleActionProbeEchoReady=token; }); var el=document.getElementById('main_tabs') || document.body || document.documentElement; if (el && el.focus) { try { el.focus({preventScroll:true}); } catch(e) { el.focus(); } } if (el && el.click) { try { el.click(); } catch(e) {} } return true; } catch(e) { return false; } })();",
    js_string(token)
  )
  ok <- tryCatch(isTRUE(app$get_js(script)), error = function(...) FALSE)
  if (!isTRUE(ok)) return(FALSE)
  check_script <- sprintf(
    "(function(){ return String(window.__vpSingleActionProbeEchoReady || '') === %s; })();",
    js_string(token)
  )
  ready <- isTRUE(tryCatch(app$get_js(check_script), error = function(...) FALSE))
  if (isTRUE(ready)) {
    record_action_timeline_mark(app, "client_echo_ready")
  }
  ready
}

state_snapshot <- function(app, output_id = "comparison_plot") {
  type_choice <- get_first_existing_input(
    app,
    c("type_choice", "vp_type_choice", "commodity_type_choice", "custom_type_choice", "myc_type_choice")
  )
  output <- output_snapshot(app, output_id)
  list(
    data_source = get_input_value(app, "data_source_choice"),
    trade_flow = get_input_value(app, "vp_trade_flow_choice"),
    group = get_input_value(app, "vp_group_choice"),
    subgroup = get_input_value(app, "vp_subgroup_choice"),
    segment = get_input_value(app, "vp_market_segment_choice"),
    commodity_choice = get_input_value(app, "commodity_choice"),
    type_choice_id = type_choice$id,
    type_choice_value = type_choice$value,
    country_choice = get_input_value(app, "country_choice"),
    metric_choice = get_input_value(app, "metric_choice"),
    main_tab = get_main_tab_value(app),
    output_id = output_id,
    output_present = isTRUE(output$present),
    output_visible = isTRUE(output$visible),
    output_width = output$width,
    output_height = output$height,
    output_widget_count = output$widget_count,
    output_text_length = output$text_length,
    output_plotly_node_count = output$plotly_node_count,
    output_plotly_main_svg_count = output$plotly_main_svg_count,
    output_plotly_svg_container_count = output$plotly_svg_container_count,
    output_loading_indicator_count = output$loading_indicator_count,
    output_plotly_afterplot_count = output$plotly_afterplot_count
  )
}

state_signature <- function(snapshot) {
  paste(
    snapshot$data_source %||% "",
    snapshot$trade_flow %||% "",
    snapshot$group %||% "",
    snapshot$subgroup %||% "",
    snapshot$segment %||% "",
    snapshot$commodity_choice %||% "",
    snapshot$country_choice %||% "",
    snapshot$metric_choice %||% "",
    snapshot$main_tab %||% "",
    sep = "|"
  )
}

flatten_prefixed <- function(prefix, values) {
  names(values) <- paste(prefix, names(values), sep = "_")
  values
}

readiness_row <- function(app, label, action_index, action_name, readiness, output_id = "comparison_plot", acceptance_mode = FALSE, run_id = NA_character_, session_id = NA_character_) {
  action_id <- paste(label, sprintf("%02d", action_index), action_name, sep = "_")
  state <- state_snapshot(app, output_id = output_id)
  output <- output_snapshot(app, output_id)
  row <- c(
    list(
      label = label,
      run_id = run_id,
      session_id = session_id,
      action_index = action_index,
      action_id = action_id,
      action_name = action_name,
      action_kind = "hierarchy_readiness",
      acceptance_mode = isTRUE(acceptance_mode),
      status = if (isTRUE(readiness$ok)) "PASS" else "FAIL",
      error_message = if (isTRUE(readiness$ok)) NA_character_ else paste("dependent_choice_not_ready", readiness$message, sep = ":"),
      target_id = readiness$downstream_id,
      target_value = readiness$target_value,
      pending_trigger_id = NA_character_,
      pending_trigger_value = NA_character_,
      pending_set_ok = NA,
      pending_set_message = "",
      set_ok = TRUE,
      set_message = "",
      target_accepted_ok = isTRUE(readiness$ok),
      target_accepted_ms = readiness$elapsed_ms,
      visible_ready_ok = is_output_ready(app, output_id),
      visible_ready_ms = NA_integer_,
      client_interaction_ready_ok = NA,
      client_interaction_ready_ms = NA_integer_,
      full_idle_ok = NA,
      full_idle_ms = NA_integer_,
      full_idle_wait_ms = NA_integer_,
      wait_for_idle_message = readiness$message,
      total_action_ms = readiness$elapsed_ms,
      output_id = output_id,
      output_present = isTRUE(output$present),
      output_visible = isTRUE(output$visible),
      output_width = output$width,
      output_height = output$height,
      output_widget_count = output$widget_count,
      output_text_length = output$text_length,
      output_plotly_node_count = output$plotly_node_count,
      output_plotly_main_svg_count = output$plotly_main_svg_count,
      output_plotly_svg_container_count = output$plotly_svg_container_count,
      output_loading_indicator_count = output$loading_indicator_count,
      output_plotly_afterplot_count = output$plotly_afterplot_count,
      output_plotly_trace_count = output$plotly_trace_count,
      output_plotly_point_count = output$plotly_point_count,
      output_plotly_cell_count = output$plotly_cell_count,
      output_plotly_array_value_count = output$plotly_array_value_count,
      output_plotly_text_chars_est = output$plotly_text_chars_est,
      output_plotly_customdata_chars_est = output$plotly_customdata_chars_est,
      output_js_heap_used_size = output$js_heap_used_size,
      output_js_heap_total_size = output$js_heap_total_size,
      output_js_heap_size_limit = output$js_heap_size_limit,
      stale_output_check_ok = TRUE,
      before_state_signature = state_signature(state),
      final_state_signature = state_signature(state),
      readiness_downstream_id = readiness$downstream_id,
      readiness_target_value = readiness$target_value,
      readiness_upstream_id = readiness$upstream_id,
      readiness_upstream_value = readiness$upstream_value,
      readiness_upstream_current = readiness$upstream_current_value,
      readiness_target_present = isTRUE(readiness$target_present),
      readiness_choices_count = readiness$choices_count,
      readiness_choices_sample = readiness$choices_sample,
      readiness_stable_polls = readiness$stable_polls
    ),
    flatten_prefixed("before", state),
    flatten_prefixed("final", state),
    flatten_prefixed("before_browser", browser_diagnostics(app)),
    flatten_prefixed("after_browser", browser_diagnostics(app))
  )

  emit_probe(
    "ACTION_END",
    paste0(
      action_id,
      "|status=", if (isTRUE(readiness$ok)) "PASS" else "FAIL",
      "|target_present=", isTRUE(readiness$target_present),
      "|choices_count=", readiness$choices_count,
      "|stable_polls=", readiness$stable_polls
    )
  )
  as.data.frame(row, stringsAsFactors = FALSE, check.names = FALSE)
}

bind_probe_rows <- function(rows) {
  all_names <- unique(unlist(lapply(rows, names), use.names = FALSE))
  normalized <- lapply(rows, function(row) {
    missing_names <- setdiff(all_names, names(row))
    for (missing_name in missing_names) {
      row[[missing_name]] <- NA
    }
    row[all_names]
  })
  do.call(rbind, normalized)
}

measure_action <- function(app, label, action_index, action_name, action_kind, target_id, target_value, output_id, stage_timeout_ms, output_timeout_ms, full_idle_timeout_ms, pending_trigger = NULL, perf_boundary_markers_enabled = FALSE, acceptance_mode = FALSE, run_id = NA_character_, session_id = NA_character_) {
  action_id <- paste(label, sprintf("%02d", action_index), action_name, sep = "_")
  emit_probe("ACTION_BEGIN", action_id)
  before_diag <- browser_diagnostics(app)
  before_state <- state_snapshot(app, output_id = output_id)
  timeline_target_tab <- if (identical(target_id, "main_tabs_panel")) target_value else before_state$main_tab
  set_probe_action_context(
    app,
    action_id = action_id,
    action_kind = action_kind,
    target_id = target_id,
    target_value = target_value,
    output_id = output_id,
    target_tab = timeline_target_tab,
    enabled = perf_boundary_markers_enabled
  )
  begin_action_timeline(app, action_id = action_id, output_id = output_id, target_tab = timeline_target_tab)
  action_start <- Sys.time()
  set_ok <- TRUE
  set_message <- ""
  pending_set_ok <- NA
  pending_set_message <- ""

  if (!is.null(pending_trigger)) {
    pending_set_ok <- TRUE
    tryCatch(
      set_input_no_wait(app, pending_trigger$id, pending_trigger$value),
      error = function(error) {
        pending_set_ok <<- FALSE
        pending_set_message <<- conditionMessage(error)
      }
    )
  }

  tryCatch(
    if (identical(target_id, "main_tabs_panel")) {
      click_main_tab_no_wait(app, target_value)
      record_action_timeline_mark(app, "tab_click_dispatched")
    } else {
      set_input_no_wait(app, target_id, target_value)
    },
    error = function(error) {
      set_ok <<- FALSE
      set_message <<- conditionMessage(error)
    }
  )

  target_accepted_wait <- if (isTRUE(set_ok)) {
    wait_for_condition(
      paste0(action_id, "_target_accepted"),
      timeout_ms = min(stage_timeout_ms, 5000L),
      predicate = function() {
        if (identical(target_id, "main_tabs_panel")) {
          identical(get_main_tab_value(app), target_value)
        } else {
          identical(get_input_value(app, target_id), target_value)
        }
      }
    )
  } else {
    list(ok = FALSE, message = set_message, elapsed_ms = NA_integer_)
  }
  if (isTRUE(target_accepted_wait$ok)) {
    record_action_timeline_mark(app, "target_accepted", output_id)
  }

  visible_wait <- if (isTRUE(set_ok)) {
    wait_for_condition(
      paste0(action_id, "_visible_ready"),
      timeout_ms = output_timeout_ms,
      predicate = function() is_output_ready(app, output_id)
    )
  } else {
    list(ok = FALSE, message = set_message, elapsed_ms = NA_integer_)
  }
  visible_ready_ms <- if (isTRUE(visible_wait$ok)) to_int_ms(action_start) else NA_integer_

  client_wait <- if (isTRUE(set_ok)) {
    wait_for_condition(
      paste0(action_id, "_client_interaction_ready"),
      timeout_ms = min(stage_timeout_ms, 10000L),
      predicate = function() client_echo_ready(app)
    )
  } else {
    list(ok = FALSE, message = set_message, elapsed_ms = NA_integer_)
  }
  client_interaction_ready_ms <- if (isTRUE(client_wait$ok)) to_int_ms(action_start) else NA_integer_

  idle_start <- Sys.time()
  idle_raw <- if (isTRUE(set_ok)) soft_wait_for_idle(app, timeout_ms = full_idle_timeout_ms) else list(ok = FALSE, message = set_message)
  full_idle_ms <- if (isTRUE(idle_raw$ok)) to_int_ms(action_start) else NA_integer_
  idle_wait <- list(ok = isTRUE(idle_raw$ok), message = idle_raw$message, elapsed_ms = to_int_ms(idle_start))

  after_state <- state_snapshot(app, output_id = output_id)
  after_diag <- browser_diagnostics(app)
  output <- output_snapshot(app, output_id)
  timeline <- action_timeline_snapshot(app)
  final_signature <- state_signature(after_state)
  stale_output_check_ok <- snapshot_ready(output, output_id) && identical(after_state$output_id, output_id)
  base_status <- if (isTRUE(set_ok) && isTRUE(target_accepted_wait$ok) && isTRUE(visible_wait$ok) && isTRUE(client_wait$ok)) {
    if (isTRUE(idle_wait$ok)) "PASS" else "PARTIAL"
  } else if (isTRUE(set_ok) && (isTRUE(visible_wait$ok) || isTRUE(client_wait$ok))) {
    "PARTIAL"
  } else {
    "FAIL"
  }

  problems <- c(
    if (!isTRUE(pending_set_ok) && !is.na(pending_set_ok)) paste("pending_set_failed", pending_set_message, sep = ":") else character(0),
    if (!isTRUE(set_ok)) paste("set_failed", set_message, sep = ":") else character(0),
    if (!isTRUE(target_accepted_wait$ok)) paste("target_not_accepted", target_accepted_wait$message, sep = ":") else character(0),
    if (!isTRUE(visible_wait$ok)) paste("visible_not_ready", visible_wait$message, sep = ":") else character(0),
    if (!isTRUE(client_wait$ok)) paste("client_interaction_not_ready", client_wait$message, sep = ":") else character(0),
    if (!isTRUE(idle_wait$ok)) paste("full_idle_not_ready", idle_wait$message, sep = ":") else character(0),
    if (!isTRUE(stale_output_check_ok)) "stale_output_check_failed" else character(0)
  )

  if (isTRUE(acceptance_mode) && identical(base_status, "PARTIAL")) {
    problems <- c(problems, "acceptance_mode_partial_disallowed")
  }

  problems <- unique(problems[nzchar(problems)])
  status <- if (length(problems) == 0L && identical(base_status, "PASS")) "PASS" else "FAIL"

  row <- c(
    list(
      label = label,
      run_id = run_id,
      session_id = session_id,
      action_index = action_index,
      action_id = action_id,
      action_name = action_name,
      action_kind = action_kind,
      status = status,
      base_status = base_status,
      acceptance_mode = isTRUE(acceptance_mode),
      error_message = if (length(problems) > 0L) paste(problems, collapse = " || ") else NA_character_,
      target_id = target_id,
      target_value = target_value,
      pending_trigger_id = pending_trigger$id %||% NA_character_,
      pending_trigger_value = pending_trigger$value %||% NA_character_,
      pending_set_ok = pending_set_ok,
      pending_set_message = gsub("\n", " | ", pending_set_message, fixed = TRUE),
      set_ok = isTRUE(set_ok),
      set_message = gsub("\n", " | ", set_message, fixed = TRUE),
      target_accepted_ok = isTRUE(target_accepted_wait$ok),
      target_accepted_ms = if (isTRUE(target_accepted_wait$ok)) target_accepted_wait$elapsed_ms else NA_integer_,
      visible_ready_ok = isTRUE(visible_wait$ok),
      visible_ready_ms = visible_ready_ms,
      client_interaction_ready_ok = isTRUE(client_wait$ok),
      client_interaction_ready_ms = client_interaction_ready_ms,
      full_idle_ok = isTRUE(idle_wait$ok),
      full_idle_ms = full_idle_ms,
      full_idle_wait_ms = idle_wait$elapsed_ms,
      wait_for_idle_message = idle_wait$message,
      total_action_ms = to_int_ms(action_start),
      output_id = output_id,
      output_present = isTRUE(output$present),
      output_visible = isTRUE(output$visible),
      output_width = output$width,
      output_height = output$height,
      output_widget_count = output$widget_count,
      output_text_length = output$text_length,
      output_plotly_node_count = output$plotly_node_count,
      output_plotly_main_svg_count = output$plotly_main_svg_count,
      output_plotly_svg_container_count = output$plotly_svg_container_count,
      output_loading_indicator_count = output$loading_indicator_count,
      output_plotly_afterplot_count = output$plotly_afterplot_count,
      output_plotly_trace_count = output$plotly_trace_count,
      output_plotly_point_count = output$plotly_point_count,
      output_plotly_cell_count = output$plotly_cell_count,
      output_plotly_array_value_count = output$plotly_array_value_count,
      output_plotly_text_chars_est = output$plotly_text_chars_est,
      output_plotly_customdata_chars_est = output$plotly_customdata_chars_est,
      output_js_heap_used_size = output$js_heap_used_size,
      output_js_heap_total_size = output$js_heap_total_size,
      output_js_heap_size_limit = output$js_heap_size_limit,
      stale_output_check_ok = isTRUE(stale_output_check_ok),
      before_state_signature = state_signature(before_state),
      final_state_signature = final_signature
    ),
    flatten_prefixed("before", before_state),
    flatten_prefixed("final", after_state),
    flatten_prefixed("timeline", timeline),
    flatten_prefixed("before_browser", before_diag),
    flatten_prefixed("after_browser", after_diag)
  )

  emit_probe(
    "ACTION_END",
    paste0(
      action_id,
      "|status=", status,
      "|visible_ready_ms=", visible_ready_ms %||% "",
      "|client_interaction_ready_ms=", client_interaction_ready_ms %||% "",
      "|full_idle_ms=", full_idle_ms %||% ""
    )
  )
  as.data.frame(row, stringsAsFactors = FALSE, check.names = FALSE)
}

find_runtime_logs <- function(logs_dir, start_time, end_time, requested_runtime_log_path = NULL) {
  paths <- list.files(logs_dir, pattern = "^vp_runtime_perf_.*\\.jsonl$", full.names = TRUE)
  if (!is.null(requested_runtime_log_path) && file.exists(requested_runtime_log_path)) {
    paths <- unique(c(paths, requested_runtime_log_path))
  }
  paths <- paths[file.exists(paths)]
  if (length(paths) == 0L) return(character(0))

  info <- file.info(paths)
  start_bound <- start_time - 10
  end_bound <- end_time + 60
  candidates <- paths[!is.na(info$mtime) & info$mtime >= start_bound & info$mtime <= end_bound]
  candidates <- candidates[order(file.info(candidates)$mtime)]
  normalizePath(candidates, winslash = "/", mustWork = FALSE)
}

parse_iso_utc_to_epoch_ms <- function(value) {
  raw <- trimws(as.character(value %||% ""))
  if (!nzchar(raw)) return(NA_real_)

  parsed <- suppressWarnings(as.POSIXct(raw, tz = "UTC", format = "%Y-%m-%dT%H:%M:%OSZ"))
  if (is.na(parsed)) {
    parsed <- suppressWarnings(as.POSIXct(raw, tz = "UTC"))
  }
  if (is.na(parsed)) return(NA_real_)

  as.numeric(parsed) * 1000
}

first_non_empty <- function(values) {
  normalized <- trimws(as.character(values %||% character(0)))
  normalized <- normalized[!is.na(normalized) & nzchar(normalized)]
  if (length(normalized) == 0L) return(NA_character_)
  normalized[[1L]]
}

first_non_na_integer <- function(values) {
  normalized <- suppressWarnings(as.integer(values))
  normalized <- normalized[!is.na(normalized)]
  if (length(normalized) == 0L) return(NA_integer_)
  normalized[[1L]]
}

as_integer_safely <- function(values) {
  suppressWarnings(as.integer(values))
}

compute_gap_ms <- function(start_ms, end_ms) {
  start_int <- as_integer_safely(start_ms)
  end_int <- as_integer_safely(end_ms)

  n <- max(length(start_int), length(end_int))
  if (!is.finite(n) || is.na(n) || n < 1L) {
    return(NA_integer_)
  }

  if (length(start_int) == 0L) start_int <- rep(NA_integer_, n)
  if (length(end_int) == 0L) end_int <- rep(NA_integer_, n)

  if (length(start_int) != n) start_int <- rep_len(start_int, n)
  if (length(end_int) != n) end_int <- rep_len(end_int, n)

  gap <- ifelse(!is.na(start_int) & !is.na(end_int), end_int - start_int, NA_integer_)
  as.integer(gap)
}

coalesce_int <- function(...) {
  candidates <- list(...)
  for (candidate in candidates) {
    candidate_int <- as_integer_safely(candidate)
    if (length(candidate_int) == 0L) {
      next
    }
    if (!is.na(candidate_int[[1L]])) {
      return(candidate_int[[1L]])
    }
  }
  NA_integer_
}

parse_runtime_client_perf_events <- function(runtime_log_path) {
  if (is.null(runtime_log_path) || !nzchar(runtime_log_path) || !file.exists(runtime_log_path)) {
    return(data.frame())
  }
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    return(data.frame())
  }

  lines <- tryCatch(readLines(runtime_log_path, warn = FALSE, encoding = "UTF-8"), error = function(...) character(0))
  if (length(lines) == 0L) {
    return(data.frame())
  }

  rows <- lapply(lines, function(line) {
    parsed <- tryCatch(jsonlite::fromJSON(line, simplifyVector = TRUE), error = function(...) NULL)
    if (is.null(parsed) || !is.list(parsed)) return(NULL)
    if (!identical(as.character(parsed$event %||% ""), "client_perf")) return(NULL)

    data.frame(
      tag = as.character(parsed$tag %||% NA_character_),
      tab = as.character(parsed$tab %||% NA_character_),
      action_reason = as.character(parsed$action_reason %||% parsed$request_action_reason %||% NA_character_),
      request_action_reason = as.character(parsed$request_action_reason %||% parsed$action_reason %||% NA_character_),
      action_id = as.character(parsed$action_id %||% parsed$request_action_id %||% NA_character_),
      mutation_seq = as.character(parsed$mutation_seq %||% parsed$request_mutation_seq %||% NA_character_),
      request_action_id = as.character(parsed$request_action_id %||% parsed$action_id %||% NA_character_),
      request_mutation_seq = as.character(parsed$request_mutation_seq %||% parsed$mutation_seq %||% NA_character_),
      target_output_id = as.character(parsed$target_output_id %||% NA_character_),
      output_owner = as.character(parsed$output_owner %||% NA_character_),
      surface = as.character(parsed$surface %||% NA_character_),
      phase = as.character(parsed$phase %||% NA_character_),
      output_outcome = as.character(parsed$output_outcome %||% NA_character_),
      active_gate_outcome = as.character(parsed$active_gate_outcome %||% NA_character_),
      active_gate_result = as.character(parsed$active_gate_result %||% parsed$active_gate_outcome %||% NA_character_),
      active_gate_reason = as.character(parsed$active_gate_reason %||% NA_character_),
      active_gate_tab_safe = as.character(parsed$active_gate_tab_safe %||% NA_character_),
      active_gate_raw_tab = as.character(parsed$active_gate_raw_tab %||% NA_character_),
      active_gate_clock_basis = as.character(parsed$active_gate_clock_basis %||% NA_character_),
      active_gate_evidence_class = as.character(parsed$active_gate_evidence_class %||% NA_character_),
      exact_action_context_status = as.character(parsed$exact_action_context_status %||% NA_character_),
      exact_action_context_source = as.character(parsed$exact_action_context_source %||% NA_character_),
      exact_action_context_evidence_class = as.character(parsed$exact_action_context_evidence_class %||% NA_character_),
      exact_action_context_missing_reason = as.character(parsed$exact_action_context_missing_reason %||% NA_character_),
      exact_action_context_target_id = as.character(parsed$exact_action_context_target_id %||% NA_character_),
      exact_action_context_target_value = as.character(parsed$exact_action_context_target_value %||% NA_character_),
      exact_action_context_target_output_id = as.character(parsed$exact_action_context_target_output_id %||% NA_character_),
      exact_action_context_target_tab = as.character(parsed$exact_action_context_target_tab %||% NA_character_),
      dependency_snapshot_status = as.character(parsed$dependency_snapshot_status %||% NA_character_),
      dependency_snapshot_reason = as.character(parsed$dependency_snapshot_reason %||% NA_character_),
      dependency_snapshot_clock_basis = as.character(parsed$dependency_snapshot_clock_basis %||% NA_character_),
      dependency_snapshot_evidence_class = as.character(parsed$dependency_snapshot_evidence_class %||% NA_character_),
      fires_when = as.character(parsed$fires_when %||% NA_character_),
      guard_name = as.character(parsed$guard_name %||% NA_character_),
      reason_code = as.character(parsed$reason_code %||% NA_character_),
      cache_flush_registration_key = as.character(parsed$cache_flush_registration_key %||% NA_character_),
      useful_ready_rule = as.character(parsed$useful_ready_rule %||% NA_character_),
      cache_key_source = as.character(parsed$cache_key_source %||% NA_character_),
      cache_key_metric = as.character(parsed$cache_key_metric %||% NA_character_),
      cache_key_country = as.character(parsed$cache_key_country %||% NA_character_),
      cache_key_commodity = as.character(parsed$cache_key_commodity %||% NA_character_),
      cache_key_frequency = as.character(parsed$cache_key_frequency %||% NA_character_),
      cache_key_hist_years = as.character(parsed$cache_key_hist_years %||% NA_character_),
      cache_key_projection_basis_mode = as.character(parsed$cache_key_projection_basis_mode %||% NA_character_),
      cache_key_projection_reference_year = as.character(parsed$cache_key_projection_reference_year %||% NA_character_),
      cache_key_reference_week_shift = as.character(parsed$cache_key_reference_week_shift %||% NA_character_),
      cache_key_show_projections = as.character(parsed$cache_key_show_projections %||% NA_character_),
      cache_key_show_total_projection = as.character(parsed$cache_key_show_total_projection %||% NA_character_),
      cache_key_show_sum_projection = as.character(parsed$cache_key_show_sum_projection %||% NA_character_),
      cache_key_show_linear_projection = as.character(parsed$cache_key_show_linear_projection %||% NA_character_),
      cache_key_show_linear_projection_country = as.character(parsed$cache_key_show_linear_projection_country %||% NA_character_),
      cache_key_show_hist_avg = as.character(parsed$cache_key_show_hist_avg %||% NA_character_),
      cache_key_show_sd_bands = as.character(parsed$cache_key_show_sd_bands %||% NA_character_),
      cache_key_show_ytd_unit_value_overlay = as.character(parsed$cache_key_show_ytd_unit_value_overlay %||% NA_character_),
      action_elapsed_ms = suppressWarnings(as.integer(parsed$action_elapsed_ms %||% parsed$client_action_elapsed_ms %||% NA_integer_)),
      client_action_elapsed_ms = suppressWarnings(as.integer(parsed$client_action_elapsed_ms %||% parsed$action_elapsed_ms %||% NA_integer_)),
      cache_key_eval_action_id = as.character(parsed$cache_key_eval_action_id %||% parsed$request_action_id %||% parsed$action_id %||% NA_character_),
      cache_key_eval_mutation_seq = as.character(parsed$cache_key_eval_mutation_seq %||% parsed$request_mutation_seq %||% parsed$mutation_seq %||% NA_character_),
      cache_key_eval_action_reason = as.character(parsed$cache_key_eval_action_reason %||% parsed$request_action_reason %||% parsed$action_reason %||% NA_character_),
      cache_key_eval_action_ms = suppressWarnings(as.integer(parsed$cache_key_eval_action_ms %||% parsed$action_elapsed_ms %||% parsed$client_action_elapsed_ms %||% NA_integer_)),
      clock_basis = as.character(parsed$clock_basis %||% NA_character_),
      resize_request_id = as.character(parsed$resize_request_id %||% NA_character_),
      ts_utc = as.character(parsed$ts_utc %||% NA_character_),
      ts_epoch_ms = parse_iso_utc_to_epoch_ms(parsed$ts_utc %||% NA_character_),
      stringsAsFactors = FALSE
    )
  })

  rows <- Filter(Negate(is.null), rows)
  if (length(rows) == 0L) {
    return(data.frame())
  }

  do.call(rbind, rows)
}

parse_runtime_server_output_anchor_events <- function(runtime_log_path) {
  if (is.null(runtime_log_path) || !nzchar(runtime_log_path) || !file.exists(runtime_log_path)) {
    return(data.frame())
  }
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    return(data.frame())
  }

  lines <- tryCatch(readLines(runtime_log_path, warn = FALSE, encoding = "UTF-8"), error = function(...) character(0))
  if (length(lines) == 0L) {
    return(data.frame())
  }

  rows <- lapply(lines, function(line) {
    parsed <- tryCatch(jsonlite::fromJSON(line, simplifyVector = TRUE), error = function(...) NULL)
    if (is.null(parsed) || !is.list(parsed)) return(NULL)
    if (!identical(as.character(parsed$event %||% ""), "server_output_anchor")) return(NULL)

    data.frame(
      tag = as.character(parsed$tag %||% NA_character_),
      boundary = as.character(parsed$boundary %||% NA_character_),
      tab = as.character(parsed$tab %||% NA_character_),
      source = as.character(parsed$source %||% NA_character_),
      action_reason = as.character(parsed$action_reason %||% parsed$request_action_reason %||% NA_character_),
      request_action_reason = as.character(parsed$request_action_reason %||% parsed$action_reason %||% NA_character_),
      action_id = as.character(parsed$action_id %||% parsed$request_action_id %||% NA_character_),
      mutation_seq = as.character(parsed$mutation_seq %||% parsed$request_mutation_seq %||% NA_character_),
      request_action_id = as.character(parsed$request_action_id %||% parsed$action_id %||% NA_character_),
      request_mutation_seq = as.character(parsed$request_mutation_seq %||% parsed$mutation_seq %||% NA_character_),
      target_output_id = as.character(parsed$target_output_id %||% NA_character_),
      output_owner = as.character(parsed$output_owner %||% NA_character_),
      surface = as.character(parsed$surface %||% NA_character_),
      phase = as.character(parsed$phase %||% NA_character_),
      output_outcome = as.character(parsed$output_outcome %||% NA_character_),
      active_gate_outcome = as.character(parsed$active_gate_outcome %||% NA_character_),
      active_gate_result = as.character(parsed$active_gate_result %||% parsed$active_gate_outcome %||% NA_character_),
      active_gate_reason = as.character(parsed$active_gate_reason %||% NA_character_),
      active_gate_tab_safe = as.character(parsed$active_gate_tab_safe %||% NA_character_),
      active_gate_raw_tab = as.character(parsed$active_gate_raw_tab %||% NA_character_),
      active_gate_clock_basis = as.character(parsed$active_gate_clock_basis %||% NA_character_),
      active_gate_evidence_class = as.character(parsed$active_gate_evidence_class %||% NA_character_),
      exact_action_context_status = as.character(parsed$exact_action_context_status %||% NA_character_),
      exact_action_context_source = as.character(parsed$exact_action_context_source %||% NA_character_),
      exact_action_context_evidence_class = as.character(parsed$exact_action_context_evidence_class %||% NA_character_),
      exact_action_context_missing_reason = as.character(parsed$exact_action_context_missing_reason %||% NA_character_),
      exact_action_context_target_id = as.character(parsed$exact_action_context_target_id %||% NA_character_),
      exact_action_context_target_value = as.character(parsed$exact_action_context_target_value %||% NA_character_),
      exact_action_context_target_output_id = as.character(parsed$exact_action_context_target_output_id %||% NA_character_),
      exact_action_context_target_tab = as.character(parsed$exact_action_context_target_tab %||% NA_character_),
      dependency_snapshot_status = as.character(parsed$dependency_snapshot_status %||% NA_character_),
      dependency_snapshot_reason = as.character(parsed$dependency_snapshot_reason %||% NA_character_),
      dependency_snapshot_clock_basis = as.character(parsed$dependency_snapshot_clock_basis %||% NA_character_),
      dependency_snapshot_evidence_class = as.character(parsed$dependency_snapshot_evidence_class %||% NA_character_),
      fires_when = as.character(parsed$fires_when %||% NA_character_),
      guard_name = as.character(parsed$guard_name %||% NA_character_),
      reason_code = as.character(parsed$reason_code %||% NA_character_),
      observability_class = as.character(parsed$observability_class %||% NA_character_),
      flush_scope = as.character(parsed$flush_scope %||% NA_character_),
      clock_basis = as.character(parsed$clock_basis %||% NA_character_),
      output_anchor_clock = as.character(parsed$output_anchor_clock %||% NA_character_),
      useful_ready_rule = as.character(parsed$useful_ready_rule %||% NA_character_),
      cache_key_source = as.character(parsed$cache_key_source %||% NA_character_),
      cache_key_metric = as.character(parsed$cache_key_metric %||% NA_character_),
      cache_key_country = as.character(parsed$cache_key_country %||% NA_character_),
      cache_key_commodity = as.character(parsed$cache_key_commodity %||% NA_character_),
      cache_key_frequency = as.character(parsed$cache_key_frequency %||% NA_character_),
      cache_key_hist_years = as.character(parsed$cache_key_hist_years %||% NA_character_),
      cache_key_projection_basis_mode = as.character(parsed$cache_key_projection_basis_mode %||% NA_character_),
      cache_key_projection_reference_year = as.character(parsed$cache_key_projection_reference_year %||% NA_character_),
      cache_key_reference_week_shift = as.character(parsed$cache_key_reference_week_shift %||% NA_character_),
      cache_key_show_projections = as.character(parsed$cache_key_show_projections %||% NA_character_),
      cache_key_show_total_projection = as.character(parsed$cache_key_show_total_projection %||% NA_character_),
      cache_key_show_sum_projection = as.character(parsed$cache_key_show_sum_projection %||% NA_character_),
      cache_key_show_linear_projection = as.character(parsed$cache_key_show_linear_projection %||% NA_character_),
      cache_key_show_linear_projection_country = as.character(parsed$cache_key_show_linear_projection_country %||% NA_character_),
      cache_key_show_hist_avg = as.character(parsed$cache_key_show_hist_avg %||% NA_character_),
      cache_key_show_sd_bands = as.character(parsed$cache_key_show_sd_bands %||% NA_character_),
      cache_key_show_ytd_unit_value_overlay = as.character(parsed$cache_key_show_ytd_unit_value_overlay %||% NA_character_),
      elapsed_ms = suppressWarnings(as.integer(parsed$elapsed_ms %||% NA_integer_)),
      source_switch_age_ms = suppressWarnings(as.integer(parsed$source_switch_age_ms %||% NA_integer_)),
      source_switch_epoch_id = as.character(parsed$source_switch_epoch_id %||% NA_character_),
      ts_utc = as.character(parsed$ts_utc %||% NA_character_),
      ts_epoch_ms = parse_iso_utc_to_epoch_ms(parsed$ts_utc %||% NA_character_),
      stringsAsFactors = FALSE
    )
  })

  rows <- Filter(Negate(is.null), rows)
  if (length(rows) == 0L) {
    return(data.frame())
  }

  do.call(rbind, rows)
}

parse_runtime_cache_body_events <- function(runtime_log_path) {
  if (is.null(runtime_log_path) || !nzchar(runtime_log_path) || !file.exists(runtime_log_path)) {
    return(data.frame())
  }
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    return(data.frame())
  }

  lines <- tryCatch(readLines(runtime_log_path, warn = FALSE, encoding = "UTF-8"), error = function(...) character(0))
  if (length(lines) == 0L) {
    return(data.frame())
  }

  rows <- lapply(lines, function(line) {
    parsed <- tryCatch(jsonlite::fromJSON(line, simplifyVector = TRUE), error = function(...) NULL)
    if (is.null(parsed) || !is.list(parsed)) return(NULL)
    if (!identical(as.character(parsed$event %||% ""), "cache_body_execution")) return(NULL)

    data.frame(
      name = as.character(parsed$name %||% NA_character_),
      output_outcome = as.character(parsed$output_outcome %||% NA_character_),
      target_output_id = as.character(parsed$target_output_id %||% NA_character_),
      tab = as.character(parsed$tab %||% parsed$active_tab %||% NA_character_),
      source = as.character(parsed$source %||% NA_character_),
      ts_utc = as.character(parsed$ts_utc %||% NA_character_),
      ts_epoch_ms = parse_iso_utc_to_epoch_ms(parsed$ts_utc %||% NA_character_),
      stringsAsFactors = FALSE
    )
  })

  rows <- Filter(Negate(is.null), rows)
  if (length(rows) == 0L) {
    return(data.frame())
  }

  do.call(rbind, rows)
}

augment_result_with_wait_boundary_markers <- function(result) {
  if (!is.data.frame(result) || nrow(result) == 0L) {
    return(result)
  }

  required_int_columns <- c(
    "server_main_tabs_observer_complete_ms",
    "server_plotly_resize_sent_ms",
    "plotly_resize_handler_enter_ms",
    "plotly_resize_handler_flush_ms",
    "plotly_resize_after_paint_snapshot_ms",
    "boundary_visible_ready_ms",
    "visible_milestone_ms",
    "gap_visible_milestone_to_output_visible_nonzero_ms",
    "gap_visible_milestone_to_widget_inserted_ms",
    "gap_visible_milestone_to_main_svg_inserted_ms",
    "gap_visible_milestone_to_plotly_afterplot_ms",
    "gap_visible_milestone_to_loading_indicator_cleared_ms",
    "gap_visible_milestone_to_readiness_predicate_passed_ms",
    "gap_tab_after_paint_to_readiness_predicate_passed_ms",
    "gap_shiny_value_output_to_readiness_predicate_passed_ms",
    "gap_readiness_predicate_passed_to_client_echo_ready_ms",
    "gap_server_main_tabs_observer_complete_to_resize_sent_ms",
    "gap_resize_sent_to_handler_enter_ms",
    "gap_handler_enter_to_handler_flush_ms",
    "gap_handler_flush_to_after_paint_snapshot_ms",
    "gap_handler_flush_to_boundary_visible_ready_ms",
    "output_render_start_ms",
    "output_inputs_resolved_ms",
    "output_plot_object_built_ms",
    "output_render_returned_ms",
    "output_flush_cycle_observed_ms",
    "output_post_cache_key_flush_observed_ms",
    "output_client_value_received_ms",
    "output_widget_inserted_marker_ms",
    "output_main_svg_inserted_marker_ms",
    "output_plotly_afterplot_marker_ms",
    "output_loading_cleared_marker_ms",
    "output_useful_ready_ms",
    "cache_key_eval_action_ms",
    "cache_key_earliest_action_ms",
    "cache_key_latest_action_ms",
    "cache_key_selected_action_ms",
    "cache_key_candidate_count",
    "cache_key_earliest_epoch_ms",
    "cache_key_latest_epoch_ms",
    "cache_key_selected_epoch_ms",
    "cache_key_eval_to_value_gap_ms",
    "output_flush_cycle_marker_count",
    "output_post_cache_key_flush_marker_count",
    "downstream_render_body_marker_count",
    "gap_render_start_to_inputs_resolved_ms",
    "gap_inputs_resolved_to_plot_object_built_ms",
    "gap_plot_object_built_to_render_returned_ms",
    "gap_render_returned_to_client_value_received_ms",
    "gap_client_value_received_to_widget_inserted_ms",
    "gap_widget_inserted_to_plotly_afterplot_marker_ms",
    "gap_plotly_afterplot_marker_to_loading_cleared_ms",
    "gap_loading_cleared_to_useful_ready_ms",
    "gap_visible_milestone_to_useful_ready_ms"
  )
  for (column_name in required_int_columns) {
    if (!column_name %in% names(result)) {
      result[[column_name]] <- NA_integer_
    }
  }
  if (!"resize_request_id" %in% names(result)) {
    result$resize_request_id <- NA_character_
  }

  required_char_columns <- c(
    "request_action_reason",
    "action_id",
    "mutation_seq",
    "request_action_id",
    "request_mutation_seq",
    "client_action_elapsed_ms",
    "cache_key_eval_action_id",
    "cache_key_eval_mutation_seq",
    "cache_key_eval_action_reason",
    "cache_key_eval_join_confidence",
    "cache_key_eval_clock_basis",
    "cache_key_selection_reason",
    "active_gate_result",
    "active_gate_reason",
    "active_gate_tab_safe",
    "active_gate_raw_tab",
    "active_gate_clock_basis",
    "active_gate_evidence_class",
    "exact_action_context_status",
    "exact_action_context_source",
    "exact_action_context_evidence_class",
    "exact_action_context_missing_reason",
    "exact_action_context_target_id",
    "exact_action_context_target_value",
    "exact_action_context_target_output_id",
    "exact_action_context_target_tab",
    "dependency_snapshot_status",
    "dependency_snapshot_reason",
    "dependency_snapshot_clock_basis",
    "dependency_snapshot_evidence_class",
    "output_flush_cycle_observability_class",
    "output_flush_cycle_scope",
    "output_flush_cycle_join_confidence",
    "output_flush_cycle_clock_basis",
    "output_post_cache_key_flush_observability_class",
    "output_post_cache_key_flush_scope",
    "output_post_cache_key_flush_join_confidence",
    "output_post_cache_key_flush_clock_basis",
    "output_downstream_marker_missing_reason",
    "output_post_cache_key_marker_missing_reason",
    "downstream_render_body_outcome"
  )
  for (column_name in required_char_columns) {
    if (!column_name %in% names(result)) {
      result[[column_name]] <- NA_character_
    }
  }

  marker_tags <- c(
    "boundary_plotly_resize_handler_enter",
    "boundary_plotly_resize_handler_flush",
    "boundary_plotly_resize_after_paint_snapshot",
    "boundary_visible_ready",
    "plotly_resize",
    "boundary_comparison_cache_key_evaluated",
    "boundary_comparison_post_cache_key_flush_observed",
    "boundary_server_output_render_start",
    "boundary_server_output_inputs_resolved",
    "boundary_server_output_plot_object_built",
    "boundary_server_output_render_returned",
    "boundary_server_output_flush_cycle_observed",
    "boundary_output_client_value_received",
    "boundary_output_widget_inserted",
    "boundary_output_main_svg_inserted",
    "boundary_output_plotly_afterplot",
    "boundary_output_loading_cleared",
    "boundary_output_useful_ready"
  )

  marker_output_fields <- c(
    "target_output_id",
    "output_owner",
    "surface",
    "phase",
    "request_action_reason",
    "action_id",
    "mutation_seq",
    "request_action_id",
    "request_mutation_seq",
    "client_action_elapsed_ms",
    "cache_key_eval_action_id",
    "cache_key_eval_mutation_seq",
    "cache_key_eval_action_reason",
    "cache_key_eval_action_ms",
    "clock_basis",
    "active_gate_outcome",
    "active_gate_result",
    "active_gate_reason",
    "active_gate_tab_safe",
    "active_gate_raw_tab",
    "active_gate_clock_basis",
    "active_gate_evidence_class",
    "exact_action_context_status",
    "exact_action_context_source",
    "exact_action_context_evidence_class",
    "exact_action_context_missing_reason",
    "exact_action_context_target_id",
    "exact_action_context_target_value",
    "exact_action_context_target_output_id",
    "exact_action_context_target_tab",
    "dependency_snapshot_status",
    "dependency_snapshot_reason",
    "dependency_snapshot_clock_basis",
    "dependency_snapshot_evidence_class",
    "fires_when",
    "guard_name",
    "reason_code",
    "observability_class",
    "flush_scope",
    "output_anchor_clock",
    "cache_key_source",
    "cache_key_metric",
    "cache_key_country",
    "cache_key_commodity",
    "cache_key_frequency",
    "cache_key_hist_years",
    "cache_key_projection_basis_mode",
    "cache_key_projection_reference_year",
    "cache_key_reference_week_shift",
    "cache_key_show_projections",
    "cache_key_show_total_projection",
    "cache_key_show_sum_projection",
    "cache_key_show_linear_projection",
    "cache_key_show_linear_projection_country",
    "cache_key_show_hist_avg",
    "cache_key_show_sd_bands",
    "cache_key_show_ytd_unit_value_overlay",
    "output_outcome",
    "useful_ready_rule"
  )

  if (!all(marker_output_fields %in% names(result))) {
    for (field_name in setdiff(marker_output_fields, names(result))) {
      result[[field_name]] <- NA_character_
    }
  }

  runtime_event_cache <- list()
  runtime_server_anchor_cache <- list()
  cache_event_cache <- list()
  for (index in seq_len(nrow(result))) {
    if (!identical(as.character(result$target_id[[index]] %||% ""), "main_tabs_panel")) {
      next
    }

    runtime_path <- as.character(result$runtime_log_path[[index]] %||% "")
    if (!nzchar(runtime_path)) next
    if (!file.exists(runtime_path)) next

    events <- runtime_event_cache[[runtime_path]]
    if (is.null(events)) {
      events <- parse_runtime_client_perf_events(runtime_path)
      runtime_event_cache[[runtime_path]] <- events
    }
    if (!is.data.frame(events) || nrow(events) == 0L) next

    server_anchor_events <- runtime_server_anchor_cache[[runtime_path]]
    if (is.null(server_anchor_events)) {
      server_anchor_events <- parse_runtime_server_output_anchor_events(runtime_path)
      runtime_server_anchor_cache[[runtime_path]] <- server_anchor_events
    }

    cache_events <- cache_event_cache[[runtime_path]]
    if (is.null(cache_events)) {
      cache_events <- parse_runtime_cache_body_events(runtime_path)
      cache_event_cache[[runtime_path]] <- cache_events
    }

    tab_name <- as.character(result$target_value[[index]] %||% "")
    if (!nzchar(tab_name)) next
    action_reason <- paste0("tab_click:", tab_name)

    action_events <- events[identical(events$action_reason, action_reason) | events$action_reason == action_reason, , drop = FALSE]
    if (nrow(action_events) == 0L) next

    action_server_anchor_events <- server_anchor_events[0, , drop = FALSE]
    if (is.data.frame(server_anchor_events) && nrow(server_anchor_events) > 0L) {
      action_server_anchor_events <- server_anchor_events[
        identical(server_anchor_events$action_reason, action_reason) | server_anchor_events$action_reason == action_reason,
        ,
        drop = FALSE
      ]
      if (nrow(action_server_anchor_events) == 0L) {
        action_server_anchor_events <- server_anchor_events[
          identical(server_anchor_events$tab, tab_name) | server_anchor_events$tab == tab_name,
          ,
          drop = FALSE
        ]
      }
    }

    resize_request_id <- first_non_empty(action_events$resize_request_id[action_events$tag %in% marker_tags])
    if (is.na(resize_request_id)) {
      resize_request_id <- first_non_empty(action_events$resize_request_id)
    }
    result$resize_request_id[[index]] <- resize_request_id

    marker_elapsed <- function(tag) {
      first_non_na_integer(action_events$action_elapsed_ms[action_events$tag == tag])
    }

    result$plotly_resize_handler_enter_ms[[index]] <- marker_elapsed("boundary_plotly_resize_handler_enter")
    result$plotly_resize_handler_flush_ms[[index]] <- marker_elapsed("boundary_plotly_resize_handler_flush")
    result$plotly_resize_after_paint_snapshot_ms[[index]] <- marker_elapsed("boundary_plotly_resize_after_paint_snapshot")
    result$boundary_visible_ready_ms[[index]] <- marker_elapsed("boundary_visible_ready")

    action_anchor <- action_events[!is.na(action_events$action_elapsed_ms) & !is.na(action_events$ts_epoch_ms), , drop = FALSE]
    if (nrow(action_anchor) == 0L) next

    anchor_index <- which.min(action_anchor$action_elapsed_ms)
    action_start_epoch_ms <- as.numeric(action_anchor$ts_epoch_ms[[anchor_index]]) - as.numeric(action_anchor$action_elapsed_ms[[anchor_index]])
    if (!is.finite(action_start_epoch_ms)) next

    chain_events <- action_events
    if (!is.na(resize_request_id)) {
      chain_subset <- events[events$resize_request_id == resize_request_id, , drop = FALSE]
      if (nrow(chain_subset) > 0L) {
        chain_events <- chain_subset
      }
    }

    tab_actions <- c("tab_settled", "tab_revisit", "tab_while_pending")
    is_tab_action <- as.character(result$action_kind[[index]] %||% "") %in% tab_actions
    output_id_value <- as.character(result$output_id[[index]] %||% "")
    output_chain_events <- events[0, , drop = FALSE]
    output_server_anchor_events <- action_server_anchor_events[0, , drop = FALSE]
    output_downstream_events <- events[0, , drop = FALSE]
    if (is_tab_action && nzchar(output_id_value)) {
      output_chain_events <- action_events
      output_chain_events <- output_chain_events[output_chain_events$target_output_id == output_id_value, , drop = FALSE]
      if (!is.na(resize_request_id)) {
        output_chain_events <- output_chain_events[
          is.na(output_chain_events$resize_request_id) | output_chain_events$resize_request_id == resize_request_id,
          ,
          drop = FALSE
        ]
      }
      action_start_epoch <- action_start_epoch_ms
      output_chain_events <- output_chain_events[
        is.na(output_chain_events$ts_epoch_ms) |
          (output_chain_events$ts_epoch_ms >= (action_start_epoch - 250)) |
          (!is.na(output_chain_events$action_elapsed_ms) & output_chain_events$action_elapsed_ms >= 0L),
        ,
        drop = FALSE
      ]

      if (is.data.frame(action_server_anchor_events) && nrow(action_server_anchor_events) > 0L) {
        output_server_anchor_events <- action_server_anchor_events[
          action_server_anchor_events$target_output_id == output_id_value,
          ,
          drop = FALSE
        ]

        output_server_anchor_events <- output_server_anchor_events[
          is.na(output_server_anchor_events$ts_epoch_ms) |
            (output_server_anchor_events$ts_epoch_ms >= (action_start_epoch - 250)) |
            (!is.na(output_server_anchor_events$elapsed_ms) & output_server_anchor_events$elapsed_ms >= 0L),
          ,
          drop = FALSE
        ]

        output_downstream_events <- output_server_anchor_events[
          output_server_anchor_events$tag == "boundary_server_output_flush_cycle_observed",
          ,
          drop = FALSE
        ]
      }

      if (is.data.frame(server_anchor_events) && nrow(server_anchor_events) > 0L) {
        post_cache_candidates <- server_anchor_events[
          server_anchor_events$tag == "boundary_comparison_post_cache_key_flush_observed" &
            server_anchor_events$target_output_id == output_id_value &
            (server_anchor_events$tab == tab_name | is.na(server_anchor_events$tab)),
          ,
          drop = FALSE
        ]

        if (nrow(post_cache_candidates) > 0L) {
          post_cache_candidates <- post_cache_candidates[
            is.na(post_cache_candidates$ts_epoch_ms) |
              post_cache_candidates$ts_epoch_ms >= (action_start_epoch - 1000),
            ,
            drop = FALSE
          ]
        }

        client_value_epochs <- suppressWarnings(as.numeric(
          output_chain_events$ts_epoch_ms[output_chain_events$tag == "boundary_output_client_value_received"]
        ))
        client_value_epochs <- client_value_epochs[is.finite(client_value_epochs)]
        if (nrow(post_cache_candidates) > 0L && length(client_value_epochs) > 0L) {
          post_cache_candidates <- post_cache_candidates[
            is.na(post_cache_candidates$ts_epoch_ms) |
              post_cache_candidates$ts_epoch_ms <= (client_value_epochs[[1L]] + 250),
            ,
            drop = FALSE
          ]
        }

        if (nrow(post_cache_candidates) > 0L) {
          output_server_anchor_events <- unique(rbind(output_server_anchor_events, post_cache_candidates))
        }
      }
    }

    output_outcome_value <- NA_character_

    server_marker_elapsed <- function(tag) {
      tag_rows <- chain_events[chain_events$tag == tag & !is.na(chain_events$ts_epoch_ms), , drop = FALSE]
      if (nrow(tag_rows) == 0L) return(NA_integer_)
      elapsed <- as.integer(round(as.numeric(tag_rows$ts_epoch_ms[[1L]]) - action_start_epoch_ms))
      if (!is.finite(elapsed)) return(NA_integer_)
      if (elapsed < -1000L) return(NA_integer_)
      if (elapsed > 300000L) return(NA_integer_)
      elapsed
    }

    result$server_plotly_resize_sent_ms[[index]] <- server_marker_elapsed("boundary_server_plotly_resize_sent")
    result$server_main_tabs_observer_complete_ms[[index]] <- server_marker_elapsed("boundary_server_main_tabs_observer_complete")

    output_marker_elapsed <- function(tag) {
      tag_rows <- output_chain_events[output_chain_events$tag == tag, , drop = FALSE]
      if (nrow(tag_rows) == 0L) return(NA_integer_)
      from_action <- first_non_na_integer(tag_rows$action_elapsed_ms)
      if (!is.na(from_action)) return(from_action)
      tag_rows <- tag_rows[!is.na(tag_rows$ts_epoch_ms), , drop = FALSE]
      if (nrow(tag_rows) == 0L) return(NA_integer_)
      elapsed <- as.integer(round(as.numeric(tag_rows$ts_epoch_ms[[1L]]) - action_start_epoch_ms))
      if (!is.finite(elapsed)) return(NA_integer_)
      if (elapsed < -1000L) return(NA_integer_)
      if (elapsed > 300000L) return(NA_integer_)
      elapsed
    }

    output_server_anchor_elapsed <- function(tag) {
      if (!is.data.frame(output_server_anchor_events) || nrow(output_server_anchor_events) == 0L) {
        return(NA_integer_)
      }

      tag_rows <- output_server_anchor_events[output_server_anchor_events$tag == tag, , drop = FALSE]
      if (nrow(tag_rows) == 0L) return(NA_integer_)

      same_clock_elapsed <- first_non_na_integer(tag_rows$elapsed_ms)
      if (!is.na(same_clock_elapsed)) {
        if (same_clock_elapsed < -250L) return(NA_integer_)
        if (same_clock_elapsed > 300000L) return(NA_integer_)
        return(same_clock_elapsed)
      }

      tag_rows <- tag_rows[!is.na(tag_rows$source_switch_age_ms), , drop = FALSE]
      if (nrow(tag_rows) == 0L) return(NA_integer_)

      source_anchor <- first_non_na_integer(tag_rows$source_switch_age_ms)
      if (is.na(source_anchor)) return(NA_integer_)

      elapsed <- as.integer(source_anchor)
      if (!is.finite(elapsed)) return(NA_integer_)
      if (elapsed < -250L) return(NA_integer_)
      if (elapsed > 300000L) return(NA_integer_)
      elapsed
    }

    output_marker_field <- function(tag, field_name) {
      tag_rows <- output_chain_events[output_chain_events$tag == tag, , drop = FALSE]
      if (nrow(tag_rows) == 0L) return(NA_character_)
      first_non_empty(tag_rows[[field_name]])
    }

    output_server_anchor_field <- function(tag, field_name) {
      if (!is.data.frame(output_server_anchor_events) || nrow(output_server_anchor_events) == 0L) {
        return(NA_character_)
      }
      tag_rows <- output_server_anchor_events[output_server_anchor_events$tag == tag, , drop = FALSE]
      if (nrow(tag_rows) == 0L) return(NA_character_)
      first_non_empty(tag_rows[[field_name]])
    }

    output_server_anchor_action_elapsed <- function(tag) {
      if (!is.data.frame(output_server_anchor_events) || nrow(output_server_anchor_events) == 0L) {
        return(NA_integer_)
      }

      tag_rows <- output_server_anchor_events[output_server_anchor_events$tag == tag, , drop = FALSE]
      if (nrow(tag_rows) == 0L) return(NA_integer_)

      same_clock_elapsed <- first_non_na_integer(tag_rows$elapsed_ms)
      if (!is.na(same_clock_elapsed)) {
        if (same_clock_elapsed < -250L) return(NA_integer_)
        if (same_clock_elapsed > 300000L) return(NA_integer_)
        return(same_clock_elapsed)
      }

      tag_rows <- tag_rows[!is.na(tag_rows$ts_epoch_ms), , drop = FALSE]
      if (nrow(tag_rows) == 0L) return(NA_integer_)

      elapsed <- as.integer(round(as.numeric(tag_rows$ts_epoch_ms[[1L]]) - action_start_epoch_ms))
      if (!is.finite(elapsed)) return(NA_integer_)
      if (elapsed < -1000L) return(NA_integer_)
      if (elapsed > 300000L) return(NA_integer_)
      elapsed
    }

    clean_id_value <- function(value) {
      cleaned <- trimws(as.character(value %||% ""))
      cleaned <- cleaned[!is.na(cleaned) & nzchar(cleaned)]
      if (length(cleaned) == 0L) return(NA_character_)
      cleaned[[1L]]
    }

    normalize_id_vector <- function(values) {
      normalized <- trimws(as.character(values %||% NA_character_))
      normalized[is.na(normalized) | !nzchar(normalized)] <- NA_character_
      normalized
    }

    action_id_value <- clean_id_value(first_non_empty(c(result$action_id[[index]], result$timeline_action_id[[index]])))
    action_mutation_value <- clean_id_value(first_non_empty(result$timeline_mutation_seq[[index]]))

    selected_cache_key_event <- action_events[0, , drop = FALSE]
    selected_cache_key_candidates <- action_events[0, , drop = FALSE]
    cache_key_join_confidence <- "no_marker"
    cache_key_clock_basis <- "no_marker"
    cache_key_selection_reason <- "no_marker"
    cache_key_candidate_count <- 0L
    cache_key_earliest_action_ms <- NA_integer_
    cache_key_latest_action_ms <- NA_integer_
    cache_key_selected_action_ms <- NA_integer_
    cache_key_earliest_epoch_ms <- NA_integer_
    cache_key_latest_epoch_ms <- NA_integer_
    cache_key_selected_epoch_ms <- NA_integer_

    if (is_tab_action && nzchar(output_id_value)) {
      cache_key_events <- action_events[
        action_events$tag == "boundary_comparison_cache_key_evaluated" &
          action_events$target_output_id == output_id_value,
        ,
        drop = FALSE
      ]

      if (nrow(cache_key_events) > 0L) {
        cache_key_events <- cache_key_events[
          identical(cache_key_events$tab, tab_name) |
            cache_key_events$tab == tab_name |
            is.na(cache_key_events$tab),
          ,
          drop = FALSE
        ]
      }

      if (nrow(cache_key_events) > 0L) {
        cache_key_events$cache_key_ts_epoch_ms <- suppressWarnings(as.numeric(cache_key_events$ts_epoch_ms))
        cache_key_events$cache_key_action_ms <- suppressWarnings(as.integer(cache_key_events$cache_key_eval_action_ms %||% cache_key_events$action_elapsed_ms %||% cache_key_events$client_action_elapsed_ms))
        cache_key_events$cache_key_request_action_id <- normalize_id_vector(cache_key_events$request_action_id)
        cache_key_events$cache_key_request_mutation_seq <- normalize_id_vector(cache_key_events$request_mutation_seq)
        cache_key_events$cache_key_explicit_action_id <- normalize_id_vector(cache_key_events$cache_key_eval_action_id)
        cache_key_events$cache_key_explicit_mutation_seq <- normalize_id_vector(cache_key_events$cache_key_eval_mutation_seq)

        valid_epoch <- is.finite(cache_key_events$cache_key_ts_epoch_ms)
        valid_action <- !is.na(cache_key_events$cache_key_action_ms)
        cache_key_events <- cache_key_events[valid_epoch | valid_action, , drop = FALSE]
      }

      if (nrow(cache_key_events) > 0L) {
        exact_candidates <- cache_key_events[0, , drop = FALSE]
        if (!is.na(action_id_value)) {
          by_request <- !is.na(cache_key_events$cache_key_request_action_id) & cache_key_events$cache_key_request_action_id == action_id_value
          by_explicit <- !is.na(cache_key_events$cache_key_explicit_action_id) & cache_key_events$cache_key_explicit_action_id == action_id_value

          if (!is.na(action_mutation_value)) {
            by_request <- by_request & !is.na(cache_key_events$cache_key_request_mutation_seq) & cache_key_events$cache_key_request_mutation_seq == action_mutation_value
            by_explicit <- by_explicit & !is.na(cache_key_events$cache_key_explicit_mutation_seq) & cache_key_events$cache_key_explicit_mutation_seq == action_mutation_value
          }

          exact_candidates <- cache_key_events[by_request | by_explicit, , drop = FALSE]
        }

        client_value_candidates <- suppressWarnings(as.numeric(
          output_chain_events$ts_epoch_ms[output_chain_events$tag == "boundary_output_client_value_received"]
        ))
        client_value_candidates <- client_value_candidates[is.finite(client_value_candidates)]
        client_value_epoch <- if (length(client_value_candidates) == 0L) NA_real_ else client_value_candidates[[1L]]

        medium_candidates <- cache_key_events
        if (is.finite(action_start_epoch_ms)) {
          medium_candidates <- medium_candidates[
            !is.na(medium_candidates$cache_key_ts_epoch_ms) &
              medium_candidates$cache_key_ts_epoch_ms >= (action_start_epoch_ms - 250),
            ,
            drop = FALSE
          ]
        }
        if (is.finite(client_value_epoch)) {
          cache_before_value <- medium_candidates[
            medium_candidates$cache_key_ts_epoch_ms <= (client_value_epoch + 250),
            ,
            drop = FALSE
          ]
          if (nrow(cache_before_value) > 0L) {
            medium_candidates <- cache_before_value
          }
        }

        if (nrow(exact_candidates) > 0L) {
          selected_cache_key_candidates <- exact_candidates
          cache_key_join_confidence <- "strong_exact_action_join"
        } else if (nrow(medium_candidates) > 0L) {
          selected_cache_key_candidates <- medium_candidates
          cache_key_join_confidence <- "medium_action_window_join"
        } else {
          selected_cache_key_candidates <- cache_key_events
          cache_key_join_confidence <- "weak_timestamp_only"
        }

        cache_key_candidate_count <- as.integer(nrow(selected_cache_key_candidates))
        if (cache_key_candidate_count > 0L) {
          earliest_idx <- which.min(selected_cache_key_candidates$cache_key_ts_epoch_ms)
          latest_idx <- which.max(selected_cache_key_candidates$cache_key_ts_epoch_ms)
          selected_cache_key_event <- selected_cache_key_candidates[latest_idx, , drop = FALSE]

          cache_key_earliest_epoch_ms <- coalesce_int(round(selected_cache_key_candidates$cache_key_ts_epoch_ms[[earliest_idx]]))
          cache_key_latest_epoch_ms <- coalesce_int(round(selected_cache_key_candidates$cache_key_ts_epoch_ms[[latest_idx]]))
          cache_key_selected_epoch_ms <- coalesce_int(round(selected_cache_key_event$cache_key_ts_epoch_ms[[1L]]))
          cache_key_earliest_action_ms <- coalesce_int(selected_cache_key_candidates$cache_key_action_ms[[earliest_idx]])
          cache_key_latest_action_ms <- coalesce_int(selected_cache_key_candidates$cache_key_action_ms[[latest_idx]])
          cache_key_selected_action_ms <- coalesce_int(selected_cache_key_event$cache_key_action_ms[[1L]])

          cache_key_selection_reason <- if (cache_key_candidate_count > 1L) {
            "latest_before_value_with_multiple_candidates"
          } else if (identical(cache_key_join_confidence, "strong_exact_action_join")) {
            "exact_action_join_single_candidate"
          } else if (identical(cache_key_join_confidence, "medium_action_window_join")) {
            "action_window_single_candidate"
          } else {
            "timestamp_only_single_candidate"
          }

          event_clock_basis <- first_non_empty(selected_cache_key_event$clock_basis)
          if (!is.na(event_clock_basis) && nzchar(event_clock_basis)) {
            cache_key_clock_basis <- event_clock_basis
          } else if (!is.na(cache_key_selected_action_ms)) {
            cache_key_clock_basis <- "same_client_clock"
          } else if (identical(cache_key_join_confidence, "strong_exact_action_join")) {
            cache_key_clock_basis <- "strong_exact_action_join_no_elapsed"
          } else if (identical(cache_key_join_confidence, "medium_action_window_join")) {
            cache_key_clock_basis <- "server_epoch_inferred"
          } else {
            cache_key_clock_basis <- "weak_timestamp_only"
          }
        }
      }

      if (nrow(cache_key_events) == 0L) {
        cache_key_join_confidence <- "no_marker"
        cache_key_clock_basis <- "no_marker"
        cache_key_selection_reason <- "no_marker"
      }
    }

    cache_key_marker_field <- function(field_name) {
      if (is.data.frame(selected_cache_key_event) && nrow(selected_cache_key_event) > 0L) {
        return(first_non_empty(selected_cache_key_event[[field_name]]))
      }
      output_marker_field("boundary_comparison_cache_key_evaluated", field_name)
    }

    result$output_render_start_ms[[index]] <- coalesce_int(
      output_server_anchor_elapsed("boundary_server_output_render_start"),
      output_marker_elapsed("boundary_server_output_render_start")
    )
    result$output_inputs_resolved_ms[[index]] <- coalesce_int(
      output_server_anchor_elapsed("boundary_server_output_inputs_resolved"),
      output_marker_elapsed("boundary_server_output_inputs_resolved")
    )
    result$output_plot_object_built_ms[[index]] <- coalesce_int(
      output_server_anchor_elapsed("boundary_server_output_plot_object_built"),
      output_marker_elapsed("boundary_server_output_plot_object_built")
    )
    result$output_render_returned_ms[[index]] <- coalesce_int(
      output_server_anchor_elapsed("boundary_server_output_render_returned"),
      output_marker_elapsed("boundary_server_output_render_returned")
    )
    result$output_flush_cycle_observed_ms[[index]] <- output_server_anchor_elapsed("boundary_server_output_flush_cycle_observed")
    result$output_post_cache_key_flush_observed_ms[[index]] <- output_server_anchor_action_elapsed("boundary_comparison_post_cache_key_flush_observed")
    result$output_client_value_received_ms[[index]] <- output_marker_elapsed("boundary_output_client_value_received")
    result$output_widget_inserted_marker_ms[[index]] <- output_marker_elapsed("boundary_output_widget_inserted")
    result$output_main_svg_inserted_marker_ms[[index]] <- output_marker_elapsed("boundary_output_main_svg_inserted")
    result$output_plotly_afterplot_marker_ms[[index]] <- output_marker_elapsed("boundary_output_plotly_afterplot")
    result$output_loading_cleared_marker_ms[[index]] <- output_marker_elapsed("boundary_output_loading_cleared")
    result$output_useful_ready_ms[[index]] <- output_marker_elapsed("boundary_output_useful_ready")

    result$target_output_id[[index]] <- first_non_empty(c(
      output_marker_field("boundary_output_client_value_received", "target_output_id"),
      cache_key_marker_field("target_output_id"),
      output_server_anchor_field("boundary_server_output_render_start", "target_output_id"),
      output_server_anchor_field("boundary_server_output_render_returned", "target_output_id"),
      output_marker_field("boundary_server_output_render_start", "target_output_id"),
      output_marker_field("boundary_server_output_render_returned", "target_output_id"),
      output_id_value
    ))
    result$output_owner[[index]] <- first_non_empty(c(
      output_server_anchor_field("boundary_server_output_render_start", "output_owner"),
      output_marker_field("boundary_server_output_render_start", "output_owner")
    ))
    result$surface[[index]] <- first_non_empty(c(
      cache_key_marker_field("surface"),
      output_server_anchor_field("boundary_server_output_render_start", "surface"),
      output_marker_field("boundary_server_output_render_start", "surface")
    ))
    result$phase[[index]] <- first_non_empty(c(
      cache_key_marker_field("phase"),
      output_marker_field("boundary_output_useful_ready", "phase")
    ))
    result$active_gate_outcome[[index]] <- cache_key_marker_field("active_gate_outcome")
    result$active_gate_result[[index]] <- first_non_empty(c(
      cache_key_marker_field("active_gate_result"),
      cache_key_marker_field("active_gate_outcome"),
      output_server_anchor_field("boundary_comparison_post_cache_key_flush_observed", "active_gate_result"),
      output_server_anchor_field("boundary_comparison_post_cache_key_flush_observed", "active_gate_outcome")
    ))
    result$active_gate_reason[[index]] <- first_non_empty(c(
      cache_key_marker_field("active_gate_reason"),
      output_server_anchor_field("boundary_comparison_post_cache_key_flush_observed", "active_gate_reason")
    ))
    result$active_gate_tab_safe[[index]] <- first_non_empty(c(
      cache_key_marker_field("active_gate_tab_safe"),
      output_server_anchor_field("boundary_comparison_post_cache_key_flush_observed", "active_gate_tab_safe")
    ))
    result$active_gate_raw_tab[[index]] <- first_non_empty(c(
      cache_key_marker_field("active_gate_raw_tab"),
      output_server_anchor_field("boundary_comparison_post_cache_key_flush_observed", "active_gate_raw_tab")
    ))
    result$active_gate_clock_basis[[index]] <- first_non_empty(c(
      cache_key_marker_field("active_gate_clock_basis"),
      output_server_anchor_field("boundary_comparison_post_cache_key_flush_observed", "active_gate_clock_basis")
    ))
    result$active_gate_evidence_class[[index]] <- first_non_empty(c(
      cache_key_marker_field("active_gate_evidence_class"),
      output_server_anchor_field("boundary_comparison_post_cache_key_flush_observed", "active_gate_evidence_class")
    ))
    result$exact_action_context_status[[index]] <- first_non_empty(c(
      cache_key_marker_field("exact_action_context_status"),
      output_server_anchor_field("boundary_comparison_post_cache_key_flush_observed", "exact_action_context_status")
    ))
    result$exact_action_context_source[[index]] <- first_non_empty(c(
      cache_key_marker_field("exact_action_context_source"),
      output_server_anchor_field("boundary_comparison_post_cache_key_flush_observed", "exact_action_context_source")
    ))
    result$exact_action_context_evidence_class[[index]] <- first_non_empty(c(
      cache_key_marker_field("exact_action_context_evidence_class"),
      output_server_anchor_field("boundary_comparison_post_cache_key_flush_observed", "exact_action_context_evidence_class")
    ))
    result$exact_action_context_missing_reason[[index]] <- first_non_empty(c(
      cache_key_marker_field("exact_action_context_missing_reason"),
      output_server_anchor_field("boundary_comparison_post_cache_key_flush_observed", "exact_action_context_missing_reason")
    ))
    result$exact_action_context_target_id[[index]] <- first_non_empty(c(
      cache_key_marker_field("exact_action_context_target_id"),
      output_server_anchor_field("boundary_comparison_post_cache_key_flush_observed", "exact_action_context_target_id")
    ))
    result$exact_action_context_target_value[[index]] <- first_non_empty(c(
      cache_key_marker_field("exact_action_context_target_value"),
      output_server_anchor_field("boundary_comparison_post_cache_key_flush_observed", "exact_action_context_target_value")
    ))
    result$exact_action_context_target_output_id[[index]] <- first_non_empty(c(
      cache_key_marker_field("exact_action_context_target_output_id"),
      output_server_anchor_field("boundary_comparison_post_cache_key_flush_observed", "exact_action_context_target_output_id")
    ))
    result$exact_action_context_target_tab[[index]] <- first_non_empty(c(
      cache_key_marker_field("exact_action_context_target_tab"),
      output_server_anchor_field("boundary_comparison_post_cache_key_flush_observed", "exact_action_context_target_tab")
    ))
    result$dependency_snapshot_status[[index]] <- first_non_empty(c(
      cache_key_marker_field("dependency_snapshot_status"),
      output_server_anchor_field("boundary_comparison_post_cache_key_flush_observed", "dependency_snapshot_status")
    ))
    result$dependency_snapshot_reason[[index]] <- first_non_empty(c(
      cache_key_marker_field("dependency_snapshot_reason"),
      output_server_anchor_field("boundary_comparison_post_cache_key_flush_observed", "dependency_snapshot_reason")
    ))
    result$dependency_snapshot_clock_basis[[index]] <- first_non_empty(c(
      cache_key_marker_field("dependency_snapshot_clock_basis"),
      output_server_anchor_field("boundary_comparison_post_cache_key_flush_observed", "dependency_snapshot_clock_basis")
    ))
    result$dependency_snapshot_evidence_class[[index]] <- first_non_empty(c(
      cache_key_marker_field("dependency_snapshot_evidence_class"),
      output_server_anchor_field("boundary_comparison_post_cache_key_flush_observed", "dependency_snapshot_evidence_class")
    ))
    result$fires_when[[index]] <- cache_key_marker_field("fires_when")
    result$guard_name[[index]] <- cache_key_marker_field("guard_name")
    result$reason_code[[index]] <- cache_key_marker_field("reason_code")
    result$cache_key_source[[index]] <- cache_key_marker_field("cache_key_source")
    result$cache_key_metric[[index]] <- cache_key_marker_field("cache_key_metric")
    result$cache_key_country[[index]] <- cache_key_marker_field("cache_key_country")
    result$cache_key_commodity[[index]] <- cache_key_marker_field("cache_key_commodity")
    result$cache_key_frequency[[index]] <- cache_key_marker_field("cache_key_frequency")
    result$cache_key_hist_years[[index]] <- cache_key_marker_field("cache_key_hist_years")
    result$cache_key_projection_basis_mode[[index]] <- cache_key_marker_field("cache_key_projection_basis_mode")
    result$cache_key_projection_reference_year[[index]] <- cache_key_marker_field("cache_key_projection_reference_year")
    result$cache_key_reference_week_shift[[index]] <- cache_key_marker_field("cache_key_reference_week_shift")
    result$cache_key_show_projections[[index]] <- cache_key_marker_field("cache_key_show_projections")
    result$cache_key_show_total_projection[[index]] <- cache_key_marker_field("cache_key_show_total_projection")
    result$cache_key_show_sum_projection[[index]] <- cache_key_marker_field("cache_key_show_sum_projection")
    result$cache_key_show_linear_projection[[index]] <- cache_key_marker_field("cache_key_show_linear_projection")
    result$cache_key_show_linear_projection_country[[index]] <- cache_key_marker_field("cache_key_show_linear_projection_country")
    result$cache_key_show_hist_avg[[index]] <- cache_key_marker_field("cache_key_show_hist_avg")
    result$cache_key_show_sd_bands[[index]] <- cache_key_marker_field("cache_key_show_sd_bands")
    result$cache_key_show_ytd_unit_value_overlay[[index]] <- cache_key_marker_field("cache_key_show_ytd_unit_value_overlay")
    result$request_action_reason[[index]] <- first_non_empty(c(
      cache_key_marker_field("request_action_reason"),
      cache_key_marker_field("action_reason")
    ))
    result$request_action_id[[index]] <- first_non_empty(c(
      cache_key_marker_field("request_action_id"),
      cache_key_marker_field("action_id")
    ))
    result$request_mutation_seq[[index]] <- first_non_empty(c(
      cache_key_marker_field("request_mutation_seq"),
      cache_key_marker_field("mutation_seq")
    ))
    result$action_id[[index]] <- first_non_empty(c(
      cache_key_marker_field("action_id"),
      result$action_id[[index]],
      result$timeline_action_id[[index]]
    ))
    result$mutation_seq[[index]] <- first_non_empty(c(
      cache_key_marker_field("mutation_seq"),
      result$mutation_seq[[index]],
      result$timeline_mutation_seq[[index]]
    ))
    result$client_action_elapsed_ms[[index]] <- first_non_empty(c(
      cache_key_marker_field("client_action_elapsed_ms")
    ))
    result$cache_key_eval_action_id[[index]] <- first_non_empty(c(
      cache_key_marker_field("cache_key_eval_action_id"),
      result$request_action_id[[index]]
    ))
    result$cache_key_eval_mutation_seq[[index]] <- first_non_empty(c(
      cache_key_marker_field("cache_key_eval_mutation_seq"),
      result$request_mutation_seq[[index]]
    ))
    result$cache_key_eval_action_reason[[index]] <- first_non_empty(c(
      cache_key_marker_field("cache_key_eval_action_reason"),
      result$request_action_reason[[index]],
      cache_key_marker_field("action_reason")
    ))
    result$cache_key_eval_action_ms[[index]] <- coalesce_int(cache_key_selected_action_ms)
    result$cache_key_eval_join_confidence[[index]] <- cache_key_join_confidence
    result$cache_key_eval_clock_basis[[index]] <- cache_key_clock_basis
    result$cache_key_selection_reason[[index]] <- cache_key_selection_reason
    result$cache_key_candidate_count[[index]] <- coalesce_int(cache_key_candidate_count)
    result$cache_key_earliest_action_ms[[index]] <- coalesce_int(cache_key_earliest_action_ms)
    result$cache_key_latest_action_ms[[index]] <- coalesce_int(cache_key_latest_action_ms)
    result$cache_key_selected_action_ms[[index]] <- coalesce_int(cache_key_selected_action_ms)
    result$cache_key_earliest_epoch_ms[[index]] <- coalesce_int(cache_key_earliest_epoch_ms)
    result$cache_key_latest_epoch_ms[[index]] <- coalesce_int(cache_key_latest_epoch_ms)
    result$cache_key_selected_epoch_ms[[index]] <- coalesce_int(cache_key_selected_epoch_ms)

    if (identical(cache_key_clock_basis, "same_client_clock")) {
      result$cache_key_eval_to_value_gap_ms[[index]] <- compute_gap_ms(
        coalesce_int(cache_key_selected_action_ms),
        result$output_client_value_received_ms[[index]]
      )
    } else {
      result$cache_key_eval_to_value_gap_ms[[index]] <- NA_integer_
    }

    if (cache_key_candidate_count > 0L) {
      event_request_action_id <- clean_id_value(first_non_empty(selected_cache_key_event$request_action_id))
      event_action_id <- clean_id_value(first_non_empty(selected_cache_key_event$action_id))
      if (!is.na(action_id_value)) {
        exact_match <- (!is.na(event_request_action_id) && identical(event_request_action_id, action_id_value)) ||
          (!is.na(event_action_id) && identical(event_action_id, action_id_value))
        if (isTRUE(exact_match) && !identical(result$cache_key_eval_join_confidence[[index]], "strong_exact_action_join")) {
          result$cache_key_eval_join_confidence[[index]] <- "strong_exact_action_join"
          if (identical(result$cache_key_eval_clock_basis[[index]], "server_epoch_inferred")) {
            result$cache_key_eval_clock_basis[[index]] <- "strong_exact_action_join_no_elapsed"
          }
        }
      }
    }

    result$output_outcome[[index]] <- first_non_empty(c(
      cache_key_marker_field("output_outcome"),
      output_server_anchor_field("boundary_server_output_render_returned", "output_outcome"),
      output_server_anchor_field("boundary_server_output_plot_object_built", "output_outcome"),
      output_marker_field("boundary_server_output_render_returned", "output_outcome"),
      output_marker_field("boundary_server_output_plot_object_built", "output_outcome")
    ))
    output_outcome_value <- result$output_outcome[[index]]
    result$useful_ready_rule[[index]] <- output_marker_field("boundary_output_useful_ready", "useful_ready_rule")

    if (is_tab_action && nzchar(output_id_value) && is.data.frame(cache_events) && nrow(cache_events) > 0L) {
      cache_subset <- cache_events[
        cache_events$target_output_id == output_id_value &
          cache_events$name %in% c("comparison_plot_executed", "comparison_plot_gated_skip", "comparison_plot_empty_state_return", "comparison_plot_normal_return"),
        ,
        drop = FALSE
      ]

      if (nrow(cache_subset) > 0L) {
        if (!is.na(action_start_epoch_ms)) {
          cache_subset <- cache_subset[
            is.na(cache_subset$ts_epoch_ms) |
              (cache_subset$ts_epoch_ms >= (action_start_epoch_ms - 250)),
            ,
            drop = FALSE
          ]
        }

        if (nrow(cache_subset) > 0L) {
          cache_outcome <- first_non_empty(cache_subset$output_outcome)
          if (!is.na(cache_outcome)) {
            if (is.na(result$output_outcome[[index]]) || !nzchar(as.character(result$output_outcome[[index]]))) {
              result$output_outcome[[index]] <- cache_outcome
            } else {
              result$output_outcome[[index]] <- paste(unique(c(result$output_outcome[[index]], cache_outcome)), collapse = "|")
            }
          }
        }
      }
    }

    output_outcome_value <- result$output_outcome[[index]]

    flush_observability_class <- output_server_anchor_field("boundary_server_output_flush_cycle_observed", "observability_class")
    flush_scope_value <- output_server_anchor_field("boundary_server_output_flush_cycle_observed", "flush_scope")
    flush_clock_basis <- output_server_anchor_field("boundary_server_output_flush_cycle_observed", "clock_basis")
    if (is.na(flush_clock_basis)) {
      flush_clock_basis <- output_server_anchor_field("boundary_server_output_flush_cycle_observed", "output_anchor_clock")
    }

    result$output_flush_cycle_observability_class[[index]] <- flush_observability_class
    result$output_flush_cycle_scope[[index]] <- flush_scope_value
    result$output_flush_cycle_clock_basis[[index]] <- flush_clock_basis

    post_cache_flush_observability_class <- output_server_anchor_field("boundary_comparison_post_cache_key_flush_observed", "observability_class")
    post_cache_flush_scope_value <- output_server_anchor_field("boundary_comparison_post_cache_key_flush_observed", "flush_scope")
    post_cache_flush_clock_basis <- output_server_anchor_field("boundary_comparison_post_cache_key_flush_observed", "clock_basis")
    if (is.na(post_cache_flush_clock_basis)) {
      post_cache_flush_clock_basis <- output_server_anchor_field("boundary_comparison_post_cache_key_flush_observed", "output_anchor_clock")
    }

    result$output_post_cache_key_flush_observability_class[[index]] <- post_cache_flush_observability_class
    result$output_post_cache_key_flush_scope[[index]] <- post_cache_flush_scope_value
    result$output_post_cache_key_flush_clock_basis[[index]] <- post_cache_flush_clock_basis

    output_downstream_marker_count <- if (is.data.frame(output_downstream_events)) {
      as.integer(nrow(output_downstream_events))
    } else {
      0L
    }
    result$output_flush_cycle_marker_count[[index]] <- output_downstream_marker_count

    post_cache_flush_events <- if (is.data.frame(output_server_anchor_events) && nrow(output_server_anchor_events) > 0L) {
      output_server_anchor_events[
        output_server_anchor_events$tag == "boundary_comparison_post_cache_key_flush_observed",
        ,
        drop = FALSE
      ]
    } else {
      output_server_anchor_events[0, , drop = FALSE]
    }
    post_cache_flush_marker_count <- if (is.data.frame(post_cache_flush_events)) {
      as.integer(nrow(post_cache_flush_events))
    } else {
      0L
    }
    result$output_post_cache_key_flush_marker_count[[index]] <- post_cache_flush_marker_count

    downstream_render_tags <- c(
      "boundary_server_output_render_start",
      "boundary_server_output_inputs_resolved",
      "boundary_server_output_plot_object_built",
      "boundary_server_output_render_returned"
    )
    render_marker_count <- if (is.data.frame(output_server_anchor_events) && nrow(output_server_anchor_events) > 0L) {
      as.integer(sum(output_server_anchor_events$tag %in% downstream_render_tags, na.rm = TRUE))
    } else {
      0L
    }
    result$downstream_render_body_marker_count[[index]] <- render_marker_count

    downstream_render_outcome <- first_non_empty(c(
      output_server_anchor_field("boundary_server_output_render_returned", "output_outcome"),
      output_server_anchor_field("boundary_server_output_plot_object_built", "output_outcome")
    ))

    if (is.na(downstream_render_outcome) && is_tab_action && nzchar(output_id_value) && is.data.frame(cache_events) && nrow(cache_events) > 0L) {
      cache_render_subset <- cache_events[
        cache_events$target_output_id == output_id_value &
          cache_events$name %in% c("comparison_plot_executed", "comparison_plot_gated_skip", "comparison_plot_empty_state_return", "comparison_plot_normal_return"),
        ,
        drop = FALSE
      ]
      if (nrow(cache_render_subset) > 0L) {
        downstream_render_outcome <- first_non_empty(cache_render_subset$output_outcome)
      }
    }

    result$downstream_render_body_outcome[[index]] <- downstream_render_outcome

    flush_join_confidence <- "no_marker"
    if (output_downstream_marker_count > 0L) {
      flush_action_id <- first_non_empty(output_downstream_events$request_action_id)
      flush_mutation_seq <- first_non_empty(output_downstream_events$request_mutation_seq)
      has_exact <- !is.na(action_id_value) && !is.na(flush_action_id) && identical(action_id_value, flush_action_id)
      if (isTRUE(has_exact) && !is.na(action_mutation_value) && !is.na(flush_mutation_seq)) {
        has_exact <- identical(action_mutation_value, flush_mutation_seq)
      }

      if (isTRUE(has_exact)) {
        flush_join_confidence <- "strong_exact_action_join"
      } else {
        flush_join_confidence <- "medium_action_window_join"
      }
    }
    result$output_flush_cycle_join_confidence[[index]] <- flush_join_confidence

    post_cache_flush_join_confidence <- "no_marker"
    if (post_cache_flush_marker_count > 0L) {
      post_cache_action_id <- first_non_empty(post_cache_flush_events$request_action_id)
      post_cache_mutation_seq <- first_non_empty(post_cache_flush_events$request_mutation_seq)
      has_exact <- !is.na(action_id_value) && !is.na(post_cache_action_id) && identical(action_id_value, post_cache_action_id)
      if (isTRUE(has_exact) && !is.na(action_mutation_value) && !is.na(post_cache_mutation_seq)) {
        has_exact <- identical(action_mutation_value, post_cache_mutation_seq)
      }

      post_cache_action_reason <- first_non_empty(post_cache_flush_events$action_reason)
      if (isTRUE(has_exact)) {
        post_cache_flush_join_confidence <- "strong_exact_action_join"
      } else if (!is.na(post_cache_action_reason) && identical(post_cache_action_reason, action_reason)) {
        post_cache_flush_join_confidence <- "medium_action_window_join"
      } else {
        post_cache_flush_join_confidence <- "weak_timestamp_only"
      }
    }
    result$output_post_cache_key_flush_join_confidence[[index]] <- post_cache_flush_join_confidence

    missing_reasons <- character(0)
    if (!is_tab_action || !nzchar(output_id_value)) {
      missing_reasons <- c(missing_reasons, "not_target_tab_action")
    }
    if (output_downstream_marker_count == 0L) {
      if (grepl("active_gate_skip", output_outcome_value %||% "", fixed = TRUE)) {
        missing_reasons <- c(missing_reasons, "active_gate_skip")
      }
      if (grepl("empty_state_return", output_outcome_value %||% "", fixed = TRUE)) {
        missing_reasons <- c(missing_reasons, "empty_state_return")
      }
      if (render_marker_count == 0L && (is.na(output_outcome_value) || !nzchar(output_outcome_value))) {
        missing_reasons <- c(missing_reasons, "render_body_or_cache_path_unobserved")
      } else if (render_marker_count == 0L) {
        missing_reasons <- c(missing_reasons, "cache_hit_or_body_bypass_possible")
      }
      if (length(missing_reasons) == 0L) {
        missing_reasons <- c(missing_reasons, "no_flush_cycle_marker_for_action")
      }
    }

    result$output_downstream_marker_missing_reason[[index]] <- if (length(missing_reasons) > 0L) {
      paste(unique(missing_reasons), collapse = "|")
    } else {
      NA_character_
    }

    post_cache_missing_reasons <- character(0)
    if (!is_tab_action || !nzchar(output_id_value)) {
      post_cache_missing_reasons <- c(post_cache_missing_reasons, "not_target_tab_action")
    }
    if (post_cache_flush_marker_count == 0L) {
      if (cache_key_candidate_count == 0L) {
        post_cache_missing_reasons <- c(post_cache_missing_reasons, "no_cache_key_marker")
      }
      post_cache_missing_reasons <- c(post_cache_missing_reasons, "no_post_cache_key_flush_marker")
    }
    result$output_post_cache_key_marker_missing_reason[[index]] <- if (length(post_cache_missing_reasons) > 0L) {
      paste(unique(post_cache_missing_reasons), collapse = "|")
    } else {
      NA_character_
    }
  }

  visible_milestone_values <- vapply(
    seq_len(nrow(result)),
    function(index) {
      coalesce_int(
        result$boundary_visible_ready_ms[[index]],
        result$timeline_tab_after_paint_ms[[index]],
        result$timeline_tab_shown_ms[[index]]
      )
    },
    integer(1)
  )
  visible_milestone_values[visible_milestone_values == .Machine$integer.max] <- NA_integer_
  result$visible_milestone_ms <- visible_milestone_values

  result$gap_visible_milestone_to_output_visible_nonzero_ms <- compute_gap_ms(result$visible_milestone_ms, result$timeline_output_visible_nonzero_ms)
  result$gap_visible_milestone_to_widget_inserted_ms <- compute_gap_ms(result$visible_milestone_ms, result$timeline_widget_inserted_ms)
  result$gap_visible_milestone_to_main_svg_inserted_ms <- compute_gap_ms(result$visible_milestone_ms, result$timeline_main_svg_inserted_ms)
  result$gap_visible_milestone_to_plotly_afterplot_ms <- compute_gap_ms(result$visible_milestone_ms, result$timeline_plotly_afterplot_ms)
  result$gap_visible_milestone_to_loading_indicator_cleared_ms <- compute_gap_ms(result$visible_milestone_ms, result$timeline_loading_indicator_cleared_ms)
  result$gap_visible_milestone_to_readiness_predicate_passed_ms <- compute_gap_ms(result$visible_milestone_ms, result$timeline_readiness_predicate_passed_ms)
  result$gap_tab_after_paint_to_readiness_predicate_passed_ms <- compute_gap_ms(result$timeline_tab_after_paint_ms, result$timeline_readiness_predicate_passed_ms)
  result$gap_shiny_value_output_to_readiness_predicate_passed_ms <- compute_gap_ms(result$timeline_shiny_value_output_ms, result$timeline_readiness_predicate_passed_ms)
  result$gap_readiness_predicate_passed_to_client_echo_ready_ms <- compute_gap_ms(result$timeline_readiness_predicate_passed_ms, result$timeline_client_echo_ready_ms)
  result$gap_server_main_tabs_observer_complete_to_resize_sent_ms <- compute_gap_ms(result$server_main_tabs_observer_complete_ms, result$server_plotly_resize_sent_ms)
  result$gap_resize_sent_to_handler_enter_ms <- compute_gap_ms(result$server_plotly_resize_sent_ms, result$plotly_resize_handler_enter_ms)
  result$gap_handler_enter_to_handler_flush_ms <- compute_gap_ms(result$plotly_resize_handler_enter_ms, result$plotly_resize_handler_flush_ms)
  result$gap_handler_flush_to_after_paint_snapshot_ms <- compute_gap_ms(result$plotly_resize_handler_flush_ms, result$plotly_resize_after_paint_snapshot_ms)
  result$gap_handler_flush_to_boundary_visible_ready_ms <- compute_gap_ms(result$plotly_resize_handler_flush_ms, result$boundary_visible_ready_ms)

  result$gap_render_start_to_inputs_resolved_ms <- compute_gap_ms(result$output_render_start_ms, result$output_inputs_resolved_ms)
  result$gap_inputs_resolved_to_plot_object_built_ms <- compute_gap_ms(result$output_inputs_resolved_ms, result$output_plot_object_built_ms)
  result$gap_plot_object_built_to_render_returned_ms <- compute_gap_ms(result$output_plot_object_built_ms, result$output_render_returned_ms)
  result$gap_render_returned_to_client_value_received_ms <- compute_gap_ms(result$output_render_returned_ms, result$output_client_value_received_ms)
  result$gap_client_value_received_to_widget_inserted_ms <- compute_gap_ms(result$output_client_value_received_ms, result$output_widget_inserted_marker_ms)
  result$gap_widget_inserted_to_plotly_afterplot_marker_ms <- compute_gap_ms(result$output_widget_inserted_marker_ms, result$output_plotly_afterplot_marker_ms)
  result$gap_plotly_afterplot_marker_to_loading_cleared_ms <- compute_gap_ms(result$output_plotly_afterplot_marker_ms, result$output_loading_cleared_marker_ms)
  result$gap_loading_cleared_to_useful_ready_ms <- compute_gap_ms(result$output_loading_cleared_marker_ms, result$output_useful_ready_ms)
  result$gap_visible_milestone_to_useful_ready_ms <- compute_gap_ms(result$visible_milestone_ms, result$output_useful_ready_ms)

  # Defensive schema guard to prevent list-columns from reaching CSV writer.
  downstream_schema_columns <- c(
    "output_flush_cycle_observed_ms",
    "output_post_cache_key_flush_observed_ms",
    "output_flush_cycle_marker_count",
    "output_post_cache_key_flush_marker_count",
    "downstream_render_body_marker_count",
    "active_gate_result",
    "active_gate_reason",
    "active_gate_tab_safe",
    "active_gate_raw_tab",
    "active_gate_clock_basis",
    "active_gate_evidence_class",
    "exact_action_context_status",
    "exact_action_context_source",
    "exact_action_context_evidence_class",
    "exact_action_context_missing_reason",
    "exact_action_context_target_id",
    "exact_action_context_target_value",
    "exact_action_context_target_output_id",
    "exact_action_context_target_tab",
    "dependency_snapshot_status",
    "dependency_snapshot_reason",
    "dependency_snapshot_clock_basis",
    "dependency_snapshot_evidence_class",
    "output_flush_cycle_observability_class",
    "output_flush_cycle_scope",
    "output_flush_cycle_join_confidence",
    "output_flush_cycle_clock_basis",
    "output_downstream_marker_missing_reason",
    "output_post_cache_key_flush_observability_class",
    "output_post_cache_key_flush_scope",
    "output_post_cache_key_flush_join_confidence",
    "output_post_cache_key_flush_clock_basis",
    "output_post_cache_key_marker_missing_reason",
    "downstream_render_body_outcome"
  )
  for (column_name in downstream_schema_columns) {
    if (!column_name %in% names(result)) next
    if (is.list(result[[column_name]])) {
      stop(sprintf("augment_result_with_wait_boundary_markers: list column detected for %s", column_name), call. = FALSE)
    }
  }

  result
}

setup_canonical_state <- function(app, stage_timeout_ms, output_timeout_ms) {
  actions <- list(
    list(id = "data_source_choice", value = "vp_trade"),
    list(id = "main_tabs_panel", value = "Current vs. Average"),
    list(id = "vp_trade_flow_choice", value = "import"),
    list(id = "vp_group_choice", value = "__all__"),
    list(id = "vp_subgroup_choice", value = "__all__"),
    list(id = "vp_market_segment_choice", value = "__all__"),
    list(id = "commodity_choice", value = "All"),
    list(id = "country_choice", value = "GRAND_TOTAL")
  )
  results <- lapply(seq_along(actions), function(index) {
    action <- actions[[index]]
    stage_name <- paste0("setup_", index, "_", action$id)
    set_ok <- TRUE
    set_message <- ""
    emit_probe("STAGE_BEGIN", stage_name)
    tryCatch(
      set_input_no_wait(app, action$id, action$value),
      error = function(error) {
        set_ok <<- FALSE
        set_message <<- conditionMessage(error)
      }
    )
    wait <- if (isTRUE(set_ok)) soft_wait_for_idle(app, timeout_ms = stage_timeout_ms) else list(ok = FALSE, message = set_message)
    emit_probe("STAGE_END", paste0(stage_name, "|set_ok=", isTRUE(set_ok), "|wait_ok=", isTRUE(wait$ok)))
    list(set_ok = isTRUE(set_ok), wait_ok = isTRUE(wait$ok), message = wait$message %||% set_message)
  })
  output_wait <- wait_for_condition(
    "setup_current_output_ready",
    timeout_ms = output_timeout_ms,
    predicate = function() is_output_ready(app, "comparison_plot")
  )
  list(
    set_ok = all(vapply(results, function(item) isTRUE(item$set_ok), logical(1))),
    wait_ok = all(vapply(results, function(item) isTRUE(item$wait_ok), logical(1))) && isTRUE(output_wait$ok),
    output_wait_ok = isTRUE(output_wait$ok),
    messages = paste(vapply(results, function(item) item$message %||% "", character(1)), collapse = " || ")
  )
}

run_probe <- function(app_dir, label, cache_state, scenario, logs_dir, runtime_enabled, perf_boundary_markers_enabled, stage_timeout_ms, startup_timeout_ms, output_timeout_ms, full_idle_timeout_ms, test_vp_trade_artifact = "", acceptance_mode = FALSE, run_id = NA_character_, session_id = NA_character_, comparison_plot_cache_off = FALSE) {
  timestamp_token <- format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC")
  runtime_log_path <- file.path(logs_dir, paste0("vp_runtime_perf_single_action_", label, "_", timestamp_token, ".jsonl"))
  test_vp_trade_artifact <- trimws(as.character(test_vp_trade_artifact %||% ""))
  test_vp_trade_artifact_path <- if (nzchar(test_vp_trade_artifact)) normalizePath(test_vp_trade_artifact, winslash = "/", mustWork = FALSE) else ""
  test_vp_trade_artifact_rows <- safe_rds_row_count(test_vp_trade_artifact_path)
  Sys.setenv(VP_PERF_RUNTIME = if (isTRUE(runtime_enabled)) "true" else "false")
  Sys.setenv(VP_PERF_RUNTIME_MEMORY_MODE = "off")
  Sys.setenv(VP_PERF_RUNTIME_LOG_FILE = normalizePath(runtime_log_path, winslash = "/", mustWork = FALSE))
  Sys.setenv(VP_PERF_BOUNDARY_MARKERS = if (isTRUE(perf_boundary_markers_enabled)) "true" else "false")
  Sys.setenv(VP_PERF_RUN_ID = as.character(run_id %||% ""))
  Sys.setenv(VP_PERF_SESSION_ID = as.character(session_id %||% ""))
  Sys.setenv(VP_PERF_PROBE_TYPE = "single_action")
  Sys.setenv(VP_PERF_PROBE_LABEL = as.character(label %||% ""))
  Sys.setenv(VP_PERF_CACHE_STATE = as.character(cache_state %||% ""))
  Sys.setenv(VP_PERF_COMPARISON_PLOT_CACHE_OFF = if (isTRUE(comparison_plot_cache_off)) "true" else "false")
  Sys.setenv(NOT_CRAN = "true")
  if (nzchar(test_vp_trade_artifact_path)) {
    Sys.setenv(VP_PERF_TEST_ARTIFACT_OVERRIDE_ENABLED = "true")
    Sys.setenv(VP_PERF_TEST_VP_TRADE_ARTIFACT = test_vp_trade_artifact_path)
  } else {
    Sys.unsetenv("VP_PERF_TEST_ARTIFACT_OVERRIDE_ENABLED")
    Sys.unsetenv("VP_PERF_TEST_VP_TRADE_ARTIFACT")
  }
  options(
    vp_perf_runtime = isTRUE(runtime_enabled),
    vp_perf_boundary_markers = isTRUE(perf_boundary_markers_enabled),
    rice_perf_boundary_markers = isTRUE(perf_boundary_markers_enabled)
  )

  required_controls <- c(
    "data_source_choice",
    "vp_trade_flow_choice",
    "vp_group_choice",
    "vp_subgroup_choice",
    "vp_market_segment_choice",
    "country_choice",
    "commodity_choice",
    "metric_choice",
    "main_tabs_panel"
  )

  probe_start <- Sys.time()
  app_stopped <- FALSE
  emit_probe("STAGE_BEGIN", "appdriver_start")
  app <- shinytest2::AppDriver$new(
    app_dir = app_dir,
    name = paste0("vp_perf_single_action_", label),
    load_timeout = startup_timeout_ms,
    timeout = max(startup_timeout_ms, stage_timeout_ms, output_timeout_ms, full_idle_timeout_ms)
  )
  emit_probe("STAGE_END", "appdriver_start")
  on.exit(if (!isTRUE(app_stopped)) try(app$stop(), silent = TRUE), add = TRUE)

  emit_probe("STAGE_BEGIN", "startup_wait")
  startup_wait <- soft_wait_for_idle(app, timeout_ms = startup_timeout_ms)
  emit_probe("STAGE_END", paste0("startup_wait|ok=", isTRUE(startup_wait$ok)))
  startup_ready_ms <- to_int_ms(probe_start)
  install_browser_observers(app)

  controls_wait <- wait_for_condition(
    "required_controls_present",
    timeout_ms = stage_timeout_ms,
    predicate = function() all(vapply(required_controls, function(id_value) dom_exists(app, id_value), logical(1)))
  )
  missing_controls <- required_controls[!vapply(required_controls, function(id_value) dom_exists(app, id_value), logical(1))]
  setup_result <- setup_canonical_state(app, stage_timeout_ms = stage_timeout_ms, output_timeout_ms = output_timeout_ms)

  rows <- list()
  action_index <- 1L
  append_action <- function(...) {
    rows[[length(rows) + 1L]] <<- measure_action(..., perf_boundary_markers_enabled = perf_boundary_markers_enabled, acceptance_mode = acceptance_mode, run_id = run_id, session_id = session_id)
    action_index <<- action_index + 1L
  }

  run_canonical_non_tab_actions <- identical(scenario, "canonical")
  run_tab_current_only_actions <- identical(scenario, "tab_current_only")
  if (isTRUE(run_canonical_non_tab_actions)) {
    append_action(app, label, action_index, "group_all_to_dry_pulses", "hierarchy", "vp_group_choice", "Dry pulses", "comparison_plot", stage_timeout_ms, output_timeout_ms, full_idle_timeout_ms)
    subgroup_readiness <- wait_for_dependent_choice(
      app,
      paste(label, sprintf("%02d", action_index), "subgroup_choices_ready_after_group", sep = "_"),
      downstream_id = "vp_subgroup_choice",
      target_value = "Dried beans",
      upstream_id = "vp_group_choice",
      upstream_value = "Dry pulses",
      timeout_ms = stage_timeout_ms
    )
    rows[[length(rows) + 1L]] <- readiness_row(app, label, action_index, "subgroup_choices_ready_after_group", subgroup_readiness, "comparison_plot", acceptance_mode = acceptance_mode, run_id = run_id, session_id = session_id)
    action_index <- action_index + 1L
    append_action(app, label, action_index, "subgroup_all_to_dried_beans", "hierarchy", "vp_subgroup_choice", "Dried beans", "comparison_plot", stage_timeout_ms, output_timeout_ms, full_idle_timeout_ms)
    segment_readiness <- wait_for_dependent_choice(
      app,
      paste(label, sprintf("%02d", action_index), "segment_choices_ready_after_subgroup", sep = "_"),
      downstream_id = "vp_market_segment_choice",
      target_value = "Dried",
      upstream_id = "vp_subgroup_choice",
      upstream_value = "Dried beans",
      timeout_ms = stage_timeout_ms
    )
    rows[[length(rows) + 1L]] <- readiness_row(app, label, action_index, "segment_choices_ready_after_subgroup", segment_readiness, "comparison_plot", acceptance_mode = acceptance_mode, run_id = run_id, session_id = session_id)
    action_index <- action_index + 1L
    append_action(app, label, action_index, "segment_all_to_dried", "hierarchy", "vp_market_segment_choice", "Dried", "comparison_plot", stage_timeout_ms, output_timeout_ms, full_idle_timeout_ms)
  }

  commodity_choices <- get_select_choices(app, "commodity_choice")
  commodity_target <- pick_specific_choice(commodity_choices, excluded = c("All", "", "__all__"), allow_fallback_first = !isTRUE(acceptance_mode))
  if (isTRUE(acceptance_mode) && isTRUE(run_canonical_non_tab_actions) && is.na(commodity_target)) {
    stop("Acceptance mode requires a deterministic commodity target; none available after exclusions.", call. = FALSE)
  }
  if (isTRUE(run_canonical_non_tab_actions) && !is.na(commodity_target)) {
    append_action(app, label, action_index, "commodity_all_to_specific", "commodity", "commodity_choice", commodity_target, "comparison_plot", stage_timeout_ms, output_timeout_ms, full_idle_timeout_ms)
    append_action(app, label, action_index, "commodity_specific_to_all", "commodity", "commodity_choice", "All", "comparison_plot", stage_timeout_ms, output_timeout_ms, full_idle_timeout_ms)
  }

  if (isTRUE(run_tab_current_only_actions)) {
    append_action(app, label, action_index, "tab_settled_current", "tab_settled", "main_tabs_panel", "Current vs. Average", "comparison_plot", stage_timeout_ms, output_timeout_ms, full_idle_timeout_ms)
  } else {
    append_action(app, label, action_index, "tab_settled_historical_trend", "tab_settled", "main_tabs_panel", "Historical Trend", "timeseries_plot", stage_timeout_ms, output_timeout_ms, full_idle_timeout_ms)
    append_action(app, label, action_index, "tab_settled_heatmap", "tab_settled", "main_tabs_panel", "Heatmap", "heatmap_plot", stage_timeout_ms, output_timeout_ms, full_idle_timeout_ms)
    append_action(app, label, action_index, "tab_settled_map", "tab_settled", "main_tabs_panel", "Map", "map_plot", stage_timeout_ms, output_timeout_ms, full_idle_timeout_ms)
    append_action(app, label, action_index, "tab_settled_current", "tab_settled", "main_tabs_panel", "Current vs. Average", "comparison_plot", stage_timeout_ms, output_timeout_ms, full_idle_timeout_ms)

    if (identical(scenario, "tab_only_revisit")) {
      append_action(app, label, action_index, "tab_revisit_historical_trend", "tab_revisit", "main_tabs_panel", "Historical Trend", "timeseries_plot", stage_timeout_ms, output_timeout_ms, full_idle_timeout_ms)
      append_action(app, label, action_index, "tab_revisit_heatmap", "tab_revisit", "main_tabs_panel", "Heatmap", "heatmap_plot", stage_timeout_ms, output_timeout_ms, full_idle_timeout_ms)
      append_action(app, label, action_index, "tab_revisit_map", "tab_revisit", "main_tabs_panel", "Map", "map_plot", stage_timeout_ms, output_timeout_ms, full_idle_timeout_ms)
      append_action(app, label, action_index, "tab_revisit_current", "tab_revisit", "main_tabs_panel", "Current vs. Average", "comparison_plot", stage_timeout_ms, output_timeout_ms, full_idle_timeout_ms)
    }
  }

  if (isTRUE(run_canonical_non_tab_actions) && !is.na(commodity_target)) {
    append_action(
      app, label, action_index, "tab_while_commodity_pending_historical_trend", "tab_while_pending", "main_tabs_panel", "Historical Trend", "timeseries_plot",
      stage_timeout_ms, output_timeout_ms, full_idle_timeout_ms,
      pending_trigger = list(id = "commodity_choice", value = commodity_target)
    )
    append_action(app, label, action_index, "return_current_after_pending_tab", "tab_settled", "main_tabs_panel", "Current vs. Average", "comparison_plot", stage_timeout_ms, output_timeout_ms, full_idle_timeout_ms)
  }

  emit_probe("STAGE_BEGIN", "app_stop")
  try(app$stop(), silent = TRUE)
  app_stopped <- TRUE
  emit_probe("STAGE_END", "app_stop")

  probe_end <- Sys.time()
  runtime_log_candidates <- if (isTRUE(acceptance_mode)) {
    if (file.exists(runtime_log_path)) {
      normalizePath(runtime_log_path, winslash = "/", mustWork = FALSE)
    } else {
      character(0)
    }
  } else {
    find_runtime_logs(
      logs_dir = logs_dir,
      start_time = probe_start,
      end_time = probe_end,
      requested_runtime_log_path = runtime_log_path
    )
  }
  fallback_input <- paste(runtime_log_candidates, collapse = "|")

  result <- bind_probe_rows(rows)
  if (isTRUE(acceptance_mode) && length(runtime_log_candidates) == 0L) {
    existing_messages <- as.character(result$error_message %||% rep("", nrow(result)))
    existing_messages[is.na(existing_messages)] <- ""
    existing_messages <- trimws(existing_messages)
    result$error_message <- ifelse(
      nzchar(existing_messages),
      paste(existing_messages, "acceptance_mode_runtime_log_missing", sep = " || "),
      "acceptance_mode_runtime_log_missing"
    )
    result$status <- "FAIL"
  }
  result$cache_state <- cache_state
  result$run_id <- run_id
  result$session_id <- session_id
  result$acceptance_mode <- isTRUE(acceptance_mode)
  result$acceptance_run_manifest <- if (isTRUE(acceptance_mode)) normalizePath(runtime_log_path, winslash = "/", mustWork = FALSE) else NA_character_
  result$scenario <- scenario
  result$probe_start <- as.character(probe_start)
  result$probe_end <- as.character(probe_end)
  result$startup_ready_ms <- startup_ready_ms
  result$startup_wait_ok <- isTRUE(startup_wait$ok)
  result$controls_wait_ok <- isTRUE(controls_wait$ok)
  result$setup_set_ok <- isTRUE(setup_result$set_ok)
  result$setup_wait_ok <- isTRUE(setup_result$wait_ok)
  result$missing_controls <- paste(missing_controls, collapse = "|")
  result$runtime_enabled <- isTRUE(runtime_enabled)
  result$perf_boundary_markers_enabled <- isTRUE(perf_boundary_markers_enabled)
  result$runtime_log_path <- normalizePath(runtime_log_path, winslash = "/", mustWork = FALSE)
  result$runtime_log_exists <- file.exists(runtime_log_path)
  result$runtime_log_candidates <- fallback_input
  result$runtime_log_candidates_count <- length(runtime_log_candidates)
  result$fallback_input <- fallback_input
  result$test_vp_trade_artifact_path <- test_vp_trade_artifact_path
  result$test_vp_trade_artifact_exists <- nzchar(test_vp_trade_artifact_path) && file.exists(test_vp_trade_artifact_path)
  result$test_vp_trade_artifact_rows <- test_vp_trade_artifact_rows
  result$total_probe_ms <- to_int_ms(probe_start, probe_end)
  result$comparison_plot_cache_off <- isTRUE(comparison_plot_cache_off)
  result$comparison_plot_cache_mode <- comparison_plot_cache_mode_from_flag(comparison_plot_cache_off)
  result$comparison_plot_cache_mode_source <- "probe_cli_env"
  result$final_output_bindcache_enabled <- !isTRUE(comparison_plot_cache_off)
  result
}

write_acceptance_manifest <- function(logs_dir, result, label, cache_state, scenario, stage_timeout_ms, startup_timeout_ms, output_timeout_ms, full_idle_timeout_ms, args, runtime_enabled, test_vp_trade_artifact, manifest_path_arg = "") {
  acceptance_rows <- if ("acceptance_mode" %in% names(result)) as.logical(result$acceptance_mode %||% FALSE) else rep(FALSE, nrow(result))
  if (!any(acceptance_rows, na.rm = TRUE)) {
    return(list(manifest_csv = NA_character_, manifest_jsonl = NA_character_))
  }

  first_index <- which(acceptance_rows)[1L]
  runtime_log_paths <- unique(stats::na.omit(as.character(result$runtime_log_path %||% "")))
  runtime_log_paths <- runtime_log_paths[nzchar(runtime_log_paths)]

  artifact_signature <- paste(
    c(
      as.character(result$test_vp_trade_artifact_path[[first_index]] %||% ""),
      as.character(result$test_vp_trade_artifact_rows[[first_index]] %||% "")
    ),
    collapse = "|"
  )

  row <- data.frame(
    created_at_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    probe_type = "single_action",
    run_id = as.character(result$run_id[[first_index]] %||% ""),
    session_id = as.character(result$session_id[[first_index]] %||% ""),
    label = label,
    scenario = scenario,
    acceptance_mode = isTRUE(result$acceptance_mode[[first_index]]),
    cache_state = cache_state,
    comparison_plot_cache_off = isTRUE(result$comparison_plot_cache_off[[first_index]]),
    comparison_plot_cache_mode = as.character(result$comparison_plot_cache_mode[[first_index]] %||% comparison_plot_cache_mode_from_flag(FALSE)),
    comparison_plot_cache_mode_source = as.character(result$comparison_plot_cache_mode_source[[first_index]] %||% "probe_cli_env"),
    final_output_bindcache_enabled = isTRUE(result$final_output_bindcache_enabled[[first_index]]),
    status = as.character(paste(names(table(result$status)), as.integer(table(result$status)), sep = "=", collapse = "|")),
    base_status = as.character(paste(names(table(result$base_status)), as.integer(table(result$base_status)), sep = "=", collapse = "|")),
    provider_mode = vp_perf_detect_provider_mode(),
    runtime_enabled = isTRUE(runtime_enabled),
    perf_boundary_markers_enabled = isTRUE(result$perf_boundary_markers_enabled[[first_index]]),
    runtime_log_path = as.character(result$runtime_log_path[[first_index]] %||% ""),
    runtime_log_paths = paste(runtime_log_paths, collapse = "|"),
    acceptance_run_manifest = as.character(result$acceptance_run_manifest[[first_index]] %||% ""),
    runtime_log_candidates = as.character(result$runtime_log_candidates[[first_index]] %||% ""),
    output_csv_path = as.character(result$output_csv_path[[first_index]] %||% ""),
    probe_start = as.character(result$probe_start[[first_index]] %||% ""),
    probe_end = as.character(result$probe_end[[first_index]] %||% ""),
    action_count = as.integer(nrow(result)),
    stage_timeout_ms = as.integer(stage_timeout_ms),
    startup_timeout_ms = as.integer(startup_timeout_ms),
    output_timeout_ms = as.integer(output_timeout_ms),
    full_idle_timeout_ms = as.integer(full_idle_timeout_ms),
    test_vp_trade_artifact = as.character(test_vp_trade_artifact %||% ""),
    test_vp_trade_artifact_path = as.character(result$test_vp_trade_artifact_path[[first_index]] %||% ""),
    test_vp_trade_artifact_rows = as.character(result$test_vp_trade_artifact_rows[[first_index]] %||% ""),
    artifact_signature = artifact_signature,
    args = vp_perf_join_args(args),
    stringsAsFactors = FALSE
  )

  vp_perf_append_manifest_row(logs_dir = logs_dir, row_df = row, manifest_path_arg = manifest_path_arg)
}

failure_row <- function(label, cache_state, scenario, error_message, acceptance_mode = FALSE, run_id = NA_character_, session_id = NA_character_, comparison_plot_cache_off = FALSE) {
  data.frame(
    label = label,
    run_id = run_id,
    session_id = session_id,
    action_index = NA_integer_,
    action_id = NA_character_,
    action_name = NA_character_,
    action_kind = NA_character_,
    status = "FAIL",
    base_status = "FAIL",
    acceptance_mode = isTRUE(acceptance_mode),
    cache_state = cache_state,
    comparison_plot_cache_off = isTRUE(comparison_plot_cache_off),
    comparison_plot_cache_mode = comparison_plot_cache_mode_from_flag(comparison_plot_cache_off),
    comparison_plot_cache_mode_source = "probe_cli_env",
    final_output_bindcache_enabled = !isTRUE(comparison_plot_cache_off),
    scenario = scenario,
    error_message = error_message,
    runtime_log_path = NA_character_,
    runtime_log_candidates = NA_character_,
    acceptance_run_manifest = NA_character_,
    fallback_input = NA_character_,
    startup_ready_ms = NA_integer_,
    total_probe_ms = NA_integer_,
    stringsAsFactors = FALSE
  )
}

main <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  label <- trimws(as.character(parse_arg_value(args, "label", default = "single_action_latency")))
  if (!nzchar(label)) label <- "single_action_latency"
  cache_state <- normalize_cache_state(parse_arg_value(args, "cache-state", default = "unknown_cache_state"))
  acceptance_mode <- is_truthy(parse_arg_value(args, "acceptance-mode", default = "false"), default = FALSE)
  if (isTRUE(acceptance_mode) && is_unknown_cache_state(cache_state)) {
    stop("Acceptance mode requires explicit --cache-state (not unknown_cache_state).", call. = FALSE)
  }
  scenario <- trimws(as.character(parse_arg_value(args, "scenario", default = "canonical")))
  if (!scenario %in% c("canonical", "tab_only", "tab_only_revisit", "tab_current_only")) scenario <- "canonical"
  test_vp_trade_artifact <- trimws(as.character(parse_arg_value(args, "test-vp-trade-artifact", default = "")))
  runtime_enabled <- is_truthy(parse_arg_value(args, "runtime-perf", default = "true"), default = TRUE)
  perf_boundary_markers_enabled <- is_truthy(parse_arg_value(args, "perf-boundary-markers", default = "false"), default = FALSE)
  comparison_plot_cache_off <- normalize_comparison_plot_cache_off(parse_arg_value(args, "comparison-plot-cache-off", default = "false"), default = FALSE)
  manifest_path_arg <- trimws(as.character(parse_arg_value(args, "acceptance-manifest", default = "")))
  stage_timeout_ms <- suppressWarnings(as.integer(parse_arg_value(args, "stage-timeout-ms", default = "30000")))
  startup_timeout_ms <- suppressWarnings(as.integer(parse_arg_value(args, "startup-timeout-ms", default = "120000")))
  output_timeout_ms <- suppressWarnings(as.integer(parse_arg_value(args, "output-timeout-ms", default = "20000")))
  full_idle_timeout_ms <- suppressWarnings(as.integer(parse_arg_value(args, "full-idle-timeout-ms", default = "30000")))
  if (!is.finite(stage_timeout_ms) || is.na(stage_timeout_ms) || stage_timeout_ms < 1000L) stage_timeout_ms <- 30000L
  if (!is.finite(startup_timeout_ms) || is.na(startup_timeout_ms) || startup_timeout_ms < 1000L) startup_timeout_ms <- 120000L
  if (!is.finite(output_timeout_ms) || is.na(output_timeout_ms) || output_timeout_ms < 1000L) output_timeout_ms <- 20000L
  if (!is.finite(full_idle_timeout_ms) || is.na(full_idle_timeout_ms) || full_idle_timeout_ms < 1000L) full_idle_timeout_ms <- 30000L

  repo_root <- resolve_repo_root(getwd())
  vp_clone_dir <- file.path(repo_root, "VP Clone")
  logs_dir <- file.path(vp_clone_dir, "Logs")
  dir.create(logs_dir, recursive = TRUE, showWarnings = FALSE)

  timestamp_token <- format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC")
  run_id <- trimws(as.character(parse_arg_value(args, "run-id", default = "")))
  if (!nzchar(run_id)) run_id <- paste0("single_action_", label, "_", timestamp_token)
  session_id <- trimws(as.character(parse_arg_value(args, "session-id", default = run_id)))
  if (!nzchar(session_id)) session_id <- run_id
  output_path <- file.path(logs_dir, paste0("vp_perf_probe_single_action_latency_", label, "_", timestamp_token, ".csv"))

  cat("VP_PERF_SINGLE_ACTION_PROBE_START\n")
  cat(sprintf("VP_PERF_SINGLE_ACTION_RUN_ID=%s\n", run_id))
  cat(sprintf("VP_PERF_SINGLE_ACTION_SESSION_ID=%s\n", session_id))
  cat(sprintf("VP_PERF_SINGLE_ACTION_LABEL=%s\n", label))
  cat(sprintf("VP_PERF_SINGLE_ACTION_CACHE_STATE=%s\n", cache_state))
  cat(sprintf("VP_PERF_SINGLE_ACTION_ACCEPTANCE_MODE=%s\n", if (isTRUE(acceptance_mode)) "TRUE" else "FALSE"))
  cat(sprintf("VP_PERF_SINGLE_ACTION_SCENARIO=%s\n", scenario))
  cat(sprintf("VP_PERF_SINGLE_ACTION_RUNTIME_ENABLED=%s\n", if (isTRUE(runtime_enabled)) "TRUE" else "FALSE"))
  cat(sprintf("VP_PERF_SINGLE_ACTION_PERF_BOUNDARY_MARKERS_ENABLED=%s\n", if (isTRUE(perf_boundary_markers_enabled)) "TRUE" else "FALSE"))
  cat(sprintf("VP_PERF_SINGLE_ACTION_COMPARISON_PLOT_CACHE_OFF=%s\n", if (isTRUE(comparison_plot_cache_off)) "TRUE" else "FALSE"))

  if (!isTRUE(runtime_enabled)) {
    Sys.setenv(VP_PERF_RUNTIME = "false")
    options(vp_perf_runtime = FALSE)
  }

  result <- tryCatch(
    run_probe(
      app_dir = vp_clone_dir,
      label = label,
      cache_state = cache_state,
      scenario = scenario,
      logs_dir = logs_dir,
      runtime_enabled = runtime_enabled,
      perf_boundary_markers_enabled = perf_boundary_markers_enabled,
      stage_timeout_ms = stage_timeout_ms,
      startup_timeout_ms = startup_timeout_ms,
      output_timeout_ms = output_timeout_ms,
      full_idle_timeout_ms = full_idle_timeout_ms,
      test_vp_trade_artifact = test_vp_trade_artifact,
      acceptance_mode = acceptance_mode,
      run_id = run_id,
      session_id = session_id,
      comparison_plot_cache_off = comparison_plot_cache_off
    ),
    error = function(error) failure_row(label, cache_state, scenario, conditionMessage(error), acceptance_mode = acceptance_mode, run_id = run_id, session_id = session_id, comparison_plot_cache_off = comparison_plot_cache_off)
  )

  result <- augment_result_with_wait_boundary_markers(result)

  result$comparison_plot_cache_off <- isTRUE(comparison_plot_cache_off)
  result$comparison_plot_cache_mode <- comparison_plot_cache_mode_from_flag(comparison_plot_cache_off)
  result$comparison_plot_cache_mode_source <- "probe_cli_env"
  result$final_output_bindcache_enabled <- !isTRUE(comparison_plot_cache_off)

  result$output_csv_path <- normalizePath(output_path, winslash = "/", mustWork = FALSE)

  utils::write.csv(result, output_path, row.names = FALSE, na = "")

  manifest_write <- write_acceptance_manifest(
    logs_dir = logs_dir,
    result = result,
    label = label,
    cache_state = cache_state,
    scenario = scenario,
    stage_timeout_ms = stage_timeout_ms,
    startup_timeout_ms = startup_timeout_ms,
    output_timeout_ms = output_timeout_ms,
    full_idle_timeout_ms = full_idle_timeout_ms,
    args = args,
    runtime_enabled = runtime_enabled,
    test_vp_trade_artifact = test_vp_trade_artifact,
    manifest_path_arg = manifest_path_arg
  )

  status_counts <- paste(names(table(result$status)), as.integer(table(result$status)), sep = "=", collapse = "|")
  cat(sprintf("VP_PERF_SINGLE_ACTION_STATUS_COUNTS=%s\n", status_counts))
  cat(sprintf("VP_PERF_SINGLE_ACTION_OUTPUT=%s\n", normalizePath(output_path, winslash = "/", mustWork = FALSE)))
  cat(sprintf("VP_PERF_SINGLE_ACTION_RUNTIME_LOG=%s\n", result$runtime_log_path[[1L]] %||% ""))
  cat(sprintf("VP_PERF_SINGLE_ACTION_ACCEPTANCE_RUN_MANIFEST=%s\n", result$acceptance_run_manifest[[1L]] %||% ""))
  cat(sprintf("VP_PERF_SINGLE_ACTION_ACCEPTANCE_MANIFEST_CSV=%s\n", manifest_write$manifest_csv %||% ""))
  cat(sprintf("VP_PERF_SINGLE_ACTION_ACCEPTANCE_MANIFEST_JSONL=%s\n", manifest_write$manifest_jsonl %||% ""))
  cat(sprintf("VP_PERF_SINGLE_ACTION_COMPARISON_PLOT_CACHE_MODE=%s\n", result$comparison_plot_cache_mode[[1L]] %||% comparison_plot_cache_mode_from_flag(FALSE)))
  cat(sprintf("VP_PERF_SINGLE_ACTION_FALLBACK_INPUT=%s\n", result$fallback_input[[1L]] %||% ""))
  cat(sprintf("VP_PERF_SINGLE_ACTION_TOTAL_MS=%s\n", result$total_probe_ms[[1L]] %||% NA_integer_))
  if (any(!result$status %in% "PASS")) {
    cat(sprintf("VP_PERF_SINGLE_ACTION_ERRORS=%s\n", paste(stats::na.omit(result$error_message), collapse = " || ")))
  }
  cat("VP_PERF_SINGLE_ACTION_PROBE_COMPLETE\n")
}

main()