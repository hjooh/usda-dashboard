library(shinytest2)
Sys.setenv(NOT_CRAN = "true")
app <- AppDriver$new(app_dir = ".", name = "ftn_dom_probe", load_timeout = 240000, timeout = 240000)
on.exit(app$stop(), add = TRUE)
try(app$wait_for_idle(timeout = 120000), silent = TRUE)

cat("JS_CHECK_BEGIN\n")

title_txt <- tryCatch(as.character(app$get_js("(function(){ return document.title || ''; })();")), error = function(e) paste0("ERR:", conditionMessage(e)))
cat("DOC_TITLE=", title_txt, "\n", sep = "")

body_snip <- tryCatch(as.character(app$get_js("(function(){ var t = (document.body && document.body.innerText) ? document.body.innerText : ''; return t.substring(0, 400); })();")), error = function(e) paste0("ERR:", conditionMessage(e)))
cat("BODY_SNIPPET=", gsub("\n", " ", body_snip), "\n", sep = "")

ids_joined <- tryCatch(as.character(app$get_js("(function(){ var docs=[document]; for (var i=0;i<window.frames.length;i++){ try{ if(window.frames[i].document) docs.push(window.frames[i].document); } catch(e) {} } var out=[]; for (var j=0;j<docs.length;j++){ try{ var nodes=docs[j].querySelectorAll('[id]'); for (var k=0;k<nodes.length;k++){ if(nodes[k].id){ out.push(nodes[k].id); } } } catch(e) {} } var dedup=[]; var seen={}; for (var n=0;n<out.length;n++){ var key=out[n]; if(!seen[key]){ seen[key]=true; dedup.push(key); } } return dedup.slice(0,500).join('|||'); })();")), error = function(e) paste0("ERR:", conditionMessage(e)))
cat("IDS_JOINED=", ids_joined, "\n", sep = "")

needle <- c('data_source_choice','vp_trade_flow_choice','vp_group_choice','vp_subgroup_choice','vp_market_segment_choice','vp_commodity_name_choice','commodity_choice','country_choice')
for (id in needle) {
  exists_flag <- tryCatch(as.character(app$get_js(sprintf("(function(){ return document.getElementById('%s') !== null; })();", id))), error = function(e) paste0("ERR:", conditionMessage(e)))
  cat("ID_PRESENT_", id, "=", exists_flag, "\n", sep = "")
}

cat("JS_CHECK_END\n")
