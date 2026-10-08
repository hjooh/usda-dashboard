library(shinytest2)
`%||%` <- function(x, y) if (is.null(x) || length(x) == 0L) y else x
Sys.setenv(NOT_CRAN = "true")
app <- AppDriver$new(app_dir = ".", name = paste0("ftn_source_probe_", as.integer(as.numeric(Sys.time()))), load_timeout = 180000, timeout = 180000)
on.exit(app$stop(), add = TRUE)

try(app$wait_for_idle(timeout = 20000), silent = TRUE)

val <- tryCatch(app$get_values()$input$data_source_choice, error = function(e) paste0("ERR:", conditionMessage(e)))
cat("INPUT_data_source_choice=", as.character(val %||% "<NULL>"), "\n", sep = "")

raw_choices <- tryCatch(as.character(app$get_js("(function(){ var id='data_source_choice'; var docs=[document]; for (var i=0;i<window.frames.length;i++){ try{ if(window.frames[i].document) docs.push(window.frames[i].document);}catch(e){} } for (var j=0;j<docs.length;j++){ try{ var el=docs[j].getElementById(id); if(!el) continue; if(el.selectize && el.selectize.options){ var optionKeys=Object.keys(el.selectize.options).map(function(x){ return (x||'').trim(); }).filter(function(x){ return x.length>0; }); if(optionKeys.length>0) return optionKeys.join('|||'); } if(el.options){ var vals=[]; for(var k=0;k<el.options.length;k++){ vals.push((el.options[k].value||'').trim()); } return vals.join('|||'); } }catch(e){} } return ''; })();")), error = function(e) paste0("ERR:", conditionMessage(e)))
cat("RAW_SOURCE_CHOICES=", raw_choices, "\n", sep = "")

raw_labels <- tryCatch(as.character(app$get_js("(function(){ var id='data_source_choice'; var docs=[document]; for (var i=0;i<window.frames.length;i++){ try{ if(window.frames[i].document) docs.push(window.frames[i].document);}catch(e){} } for (var j=0;j<docs.length;j++){ try{ var el=docs[j].getElementById(id); if(!el) continue; if(el.selectize && el.selectize.options){ var opt=el.selectize.options; var keys=Object.keys(opt); var pairs=[]; for (var k=0;k<keys.length;k++){ var key=keys[k]; var text=''; try{ text=(opt[key] && opt[key].text) ? String(opt[key].text) : ''; }catch(e){} pairs.push(key + '=>' + text); } if(pairs.length>0) return pairs.join('|||'); } if(el.options){ var pairs2=[]; for(var q=0;q<el.options.length;q++){ var ov=(el.options[q].value||'').trim(); var ot=(el.options[q].text||'').trim(); pairs2.push(ov + '=>' + ot); } return pairs2.join('|||'); } }catch(e){} } return ''; })();")), error = function(e) paste0("ERR:", conditionMessage(e)))
cat("SOURCE_KEY_LABEL_PAIRS=", raw_labels, "\n", sep = "")

presence <- tryCatch(as.character(app$get_js("(function(){ return document.getElementById('data_source_choice') !== null; })();")), error = function(e) paste0("ERR:", conditionMessage(e)))
cat("PRESENT_data_source_choice=", presence, "\n", sep = "")
