ui <- fluidPage(
  # CSS for floating notes panel
  tags$head(
    tags$style(HTML('
      #floating_notes_panel {
        position: fixed;
        top: 100px;
        right: 20px;
        width: 320px;
        min-width: 250px;
        max-width: 600px;
        min-height: 200px;
        background: white;
        border: 1px solid #ccc;
        border-radius: 8px;
        box-shadow: 0 4px 12px rgba(0,0,0,0.15);
        z-index: 1000;
        display: none;
        resize: both;
        overflow: hidden;
      }
      #floating_notes_panel.visible {
        display: flex;
        flex-direction: column;
      }
      #notes_panel_header {
        background: #f5f5f5;
        padding: 10px 15px;
        border-bottom: 1px solid #ddd;
        border-radius: 8px 8px 0 0;
        cursor: move;
        display: flex;
        justify-content: space-between;
        align-items: center;
        font-weight: bold;
        flex-shrink: 0;
      }
      #notes_panel_header .notes-title-wrap {
        display: flex;
        flex-direction: column;
        gap: 2px;
      }
      #notes_panel_header .notes-family-cue {
        font-size: 11px;
        font-weight: 600;
        color: #6e7b85;
        line-height: 1.2;
      }
      #notes_panel_header .close-btn {
        background: none;
        border: none;
        font-size: 18px;
        cursor: pointer;
        color: #666;
        padding: 0 5px;
      }
      #notes_panel_header .close-btn:hover {
        color: #333;
      }
      #notes_panel_body {
        padding: 15px;
        flex: 1;
        display: flex;
        flex-direction: column;
        overflow: hidden;
      }
      body > .selectize-dropdown {
        z-index: 2000 !important;
      }
      #notes_panel_body .notes-country-wrap {
        margin-bottom: 12px;
      }
      #notes_panel_body .notes-sync-status {
        margin-bottom: 10px;
        color: #5c6b77;
        font-size: 12px;
        line-height: 1.25;
      }
      #notes_panel_body .notes-country-wrap .form-group {
        margin-bottom: 0;
      }
      #notes_panel_body .notes-myc-picker {
        padding: 10px 12px 12px 12px;
        background: linear-gradient(180deg, #f6f7f8 0%, #eceff1 100%);
        border: 1px solid #d7dee5;
        border-radius: 10px;
      }
      #notes_panel_body .notes-myc-picker-label {
        font-size: 11px;
        font-weight: 700;
        letter-spacing: 0.06em;
        text-transform: uppercase;
        color: #5c6b77;
        margin-bottom: 3px;
      }
      #notes_panel_body .notes-myc-picker-hint {
        margin-bottom: 8px;
        color: #6e7b85;
        font-size: 12px;
        line-height: 1.25;
      }
      #notes_panel_body .notes-myc-picker .selectize-control.single .selectize-input {
        min-height: 38px;
        border-radius: 8px;
        border: 1px solid #c7d2da;
        background: #ffffff;
        box-shadow: none;
        padding: 8px 34px 8px 12px;
      }
      #notes_panel_body .notes-myc-picker .selectize-control.single .selectize-input.focus {
        border-color: #7aa6b0;
        box-shadow: 0 0 0 2px rgba(122, 166, 176, 0.15);
      }
      #notes_panel_body .notes-myc-picker .selectize-control.single .selectize-input:after {
        border-color: #69818a transparent transparent transparent;
        right: 12px;
      }
      #notes_panel_body .notes-myc-picker .selectize-control.single .selectize-input.dropdown-active:after {
        border-color: transparent transparent #69818a transparent;
      }
      #notes_panel_body .notes-myc-picker .selectize-dropdown,
      body > .selectize-dropdown.notes-myc-picker-dropdown {
        border-radius: 8px;
        border: 1px solid #c7d2da;
        box-shadow: 0 10px 24px rgba(31, 58, 74, 0.14);
      }
      #notes_panel_body .notes-myc-picker .option,
      body > .selectize-dropdown.notes-myc-picker-dropdown .option {
        padding: 8px 10px;
        line-height: 1.3;
      }
      #notes_panel_body .notes-myc-picker .option.active,
      body > .selectize-dropdown.notes-myc-picker-dropdown .option.active {
        background: #e8f3f5;
        color: #22424d;
      }
      #notes_panel_body .notes-myc-picker .form-group {
        margin-bottom: 0;
      }
      #notes_panel_body .notes-textarea-wrap {
        flex: 1;
        display: flex;
        flex-direction: column;
      }
      #notes_panel_body .notes-empty-state {
        margin-top: 6px;
        color: #6e7b85;
        font-size: 12px;
        font-style: italic;
        line-height: 1.25;
      }
      #notes_panel_body .notes-textarea-wrap .form-group {
        flex: 1;
        display: flex;
        flex-direction: column;
        margin-bottom: 0;
      }
      #notes_panel_body textarea {
        width: 100%;
        flex: 1;
        min-height: 80px;
        resize: none;
        border: 1px solid #ccc;
        border-radius: 4px;
        padding: 8px;
        font-size: 14px;
        box-sizing: border-box;
      }
      #notes_panel_footer {
        padding: 10px 15px;
        border-top: 1px solid #eee;
        display: flex;
        justify-content: space-between;
        align-items: center;
        flex-shrink: 0;
      }
      #notes_panel_footer .timestamp {
        font-size: 11px;
        color: #888;
      }
      .notes-footer-actions {
        display: flex;
        flex-direction: column;
        align-items: flex-end;
        gap: 4px;
      }
      .notes-footer-buttons {
        display: flex;
        align-items: center;
        flex-wrap: wrap;
        justify-content: flex-end;
        gap: 6px;
      }
      .notes-footer-buttons .btn {
        margin-left: 0 !important;
      }
      .notes-footer-hint {
        text-align: right;
      }
      .notes-footer-jump-action {
        display: flex;
        flex-direction: column;
        align-items: flex-end;
        gap: 4px;
      }
      .minimize-btn {
        background: none;
        border: none;
        font-size: 16px;
        cursor: pointer;
        color: #666;
        padding: 0 5px;
      }
      #notes_panel_body.minimized {
        display: none;
      }
      #notes_panel_footer.minimized {
        display: none;
      }
      /* Visual separator before Custom Comparison Tool tab via pseudo-element */
      li a[data-value="Custom Comparison Tool"] {
        position: relative;
        padding-left: 14px;
        margin-left: 14px;
      }
      li a[data-value="Custom Comparison Tool"]::before {
        content: "";
        position: absolute;
        left: -10px;
        top: 50%;
        transform: translateY(-50%);
        height: 18px;
        border-left: 2px solid #bbb;
      }

      #myc_market_year_table .dataTables_wrapper {
        width: 100%;
      }

      #myc_market_year_table table.dataTable {
        width: 100% !important;
        table-layout: fixed;
      }

      #myc_market_year_table table.dataTable thead th {
        white-space: normal;
        overflow-wrap: anywhere;
        word-break: normal;
      }

      #myc_market_year_table table.dataTable tbody td {
        white-space: nowrap;
        overflow: hidden;
        text-overflow: ellipsis;
      }

      #myc_market_year_table table.dataTable thead th:nth-child(1),
      #myc_market_year_table table.dataTable tbody td:nth-child(1) {
        width: 110px;
      }

      #myc_market_year_table table.dataTable thead th:nth-child(2),
      #myc_market_year_table table.dataTable tbody td:nth-child(2) {
        width: 150px;
      }

      #myc_market_year_table table.dataTable thead th:nth-child(-n+2),
      #myc_market_year_table table.dataTable tbody td:nth-child(-n+2),
      #myc_market_year_table .dataTables_scrollHead thead th:nth-child(-n+2),
      #myc_market_year_table .dataTables_scrollBody tbody td:nth-child(-n+2) {
        text-align: left !important;
      }

      #myc_market_year_table table.dataTable thead th:nth-child(n+3),
      #myc_market_year_table table.dataTable tbody td:nth-child(n+3),
      #myc_market_year_table .dataTables_scrollHead thead th:nth-child(n+3),
      #myc_market_year_table .dataTables_scrollBody tbody td:nth-child(n+3) {
        text-align: right !important;
      }

      /* Shared sidebar spacing contract for projection controls */
      .sidebar-projection-block {
        padding: 0;
        margin-top: 15px;
        margin-bottom: 0;
      }
        .pace-header-spacer {
          height: 8px;
        }
      .sidebar-projection-header {
        margin: 0 0 5px 0;
        padding: 0;
        font-size: 14px;
        font-weight: 700;
      }
      .pace-projection-header {
        margin-bottom: 8px;
      }
      .sidebar-option-row {
        margin: 0;
      }
      .notes-layout-row .notes-layout-input-wrap > .shiny-html-output > .form-group,
      .notes-layout-row .notes-layout-input-wrap > .shiny-html-output .form-group.shiny-input-container {
        margin-bottom: 0;
      }
      .vp-hierarchy-reset-control {
        display: flex;
        align-items: flex-start;
        flex: 0 0 34px;
        width: 34px;
        min-width: 34px;
        max-width: 34px;
        padding-top: calc(1.2em + 6px);
      }
      .vp-hierarchy-reset-control .btn {
        width: 34px;
        height: 34px;
        min-height: 34px;
        padding: 0;
        display: inline-flex;
        align-items: center;
        justify-content: center;
        box-sizing: border-box;
        line-height: 1;
        margin: 0;
      }
      .sidebar-projection-header + .sidebar-option-group,
      .sidebar-projection-header + .sidebar-option-row {
        margin-top: 0;
      }
      .sidebar-option-group > .form-group {
        margin: 0;
      }
      .sidebar-option-group > .form-group + .form-group {
        margin-top: 4px;
      }
      .sidebar-option-group .shiny-options-group {
        margin-top: 0;
        margin-left: 0;
      }
      .sidebar-option-group .radio,
      .sidebar-option-group .checkbox {
        margin: 0;
      }
      .sidebar-option-group .radio + .radio,
      .sidebar-option-group .checkbox + .checkbox {
        margin-top: 4px;
      }
      .sidebar-option-group .radio label,
      .sidebar-option-group .checkbox label {
        margin-bottom: 0;
      }
      .psd-metric-choice-group .radio {
        margin: 0;
      }
      .psd-metric-choice-group > .control-label {
        display: block;
        margin-bottom: 14px;
      }
      .psd-metric-choice-group .shiny-options-group {
        margin-top: 0;
      }
      .psd-metric-choice-group .radio + .radio {
        margin-top: 4px;
      }
      .psd-yield-lock-under-option {
        margin: 4px 0 0 22px;
      }
      .psd-yield-lock-under-option .form-group.shiny-input-container {
        margin-bottom: 0;
      }
      .psd-yield-lock-under-option .checkbox {
        margin: 0;
      }
      .psd-yield-lock-under-option .checkbox label {
        margin-bottom: 0;
      }
      .wasde-price-lock-under-option,
      .wasde-yield-lock-under-option,
      .nass-price-lock-under-option,
      .nass-yield-lock-under-option {
        margin: 4px 0 0 22px;
      }
      .wasde-price-lock-under-option .form-group.shiny-input-container,
      .wasde-yield-lock-under-option .form-group.shiny-input-container,
      .nass-price-lock-under-option .form-group.shiny-input-container,
      .nass-yield-lock-under-option .form-group.shiny-input-container {
        margin-bottom: 0;
      }
      .wasde-price-lock-under-option .checkbox,
      .wasde-yield-lock-under-option .checkbox,
      .nass-price-lock-under-option .checkbox,
      .nass-yield-lock-under-option .checkbox {
        margin: 0;
      }
      .wasde-price-lock-under-option .checkbox label,
      .wasde-yield-lock-under-option .checkbox label,
      .nass-price-lock-under-option .checkbox label,
      .nass-yield-lock-under-option .checkbox label {
        margin-bottom: 0;
      }
      .pace-projection-options .control-label {
        display: none;
        margin: 0;
      }
      .sidebar-basis-block {
        padding: 0;
        margin-top: 5px;
        margin-bottom: 0;
      }
      .sidebar-basis-block .form-group.shiny-input-container {
        margin-bottom: 0;
      }
      .sidebar-basis-year {
        margin-top: 100px;
      }
      .sidebar-section-divider {
        margin: 6px 0 8px 0;
      }
      .sidebar-divider-before-projections {
        margin: 10px 0 12px 0;
      }
      .sidebar-divider-before-variable {
        margin: 14px 0 14px 0; border-top: 1px solid #eee;
      }
      .sidebar-divider-after-variable {
        margin: 14px 0 14px 0; border-top: 1px solid #eee;
      }
      body.census-corrections-sidebar-hidden #main_sidebar_shell > .row > .col-sm-3 {
        display: none !important;
      }
      body.census-corrections-sidebar-hidden #main_sidebar_shell > .row > .col-sm-9 {
        width: 100% !important;
        float: none !important;
      }
      #psd_map_matrix_table table.dataTable thead th.psd-matrix-comparison-band,
      #map_summary_table table.dataTable thead th.psd-summary-comparison-band,
      #myc_market_year_table table.dataTable thead th.psd-summary-comparison-band,
      .non-psd-map-summary-table-output table.dataTable thead th.psd-summary-comparison-band,
      .psd-map-summary-table-output table.dataTable thead th.psd-summary-comparison-band {
        background-color: #f4f6f8;
        color: #3f4a52;
        font-weight: 700;
      }
      #psd_map_matrix_table table.dataTable tbody td.psd-matrix-comparison-band,
      #map_summary_table table.dataTable tbody td.psd-summary-comparison-band,
      #myc_market_year_table table.dataTable tbody td.psd-summary-comparison-band,
      .non-psd-map-summary-table-output table.dataTable tbody td.psd-summary-comparison-band,
      .psd-map-summary-table-output table.dataTable tbody td.psd-summary-comparison-band {
        background-color: #fbfcfd;
      }
      #psd_map_matrix_table table.dataTable thead th.psd-matrix-comparison-start,
      #psd_map_matrix_table table.dataTable tbody td.psd-matrix-comparison-start,
      #map_summary_table table.dataTable thead th.psd-summary-comparison-start,
      #map_summary_table table.dataTable tbody td.psd-summary-comparison-start,
      #myc_market_year_table table.dataTable thead th.psd-summary-comparison-start,
      #myc_market_year_table table.dataTable tbody td.psd-summary-comparison-start,
      .non-psd-map-summary-table-output table.dataTable thead th.psd-summary-comparison-start,
      .non-psd-map-summary-table-output table.dataTable tbody td.psd-summary-comparison-start,
      .psd-map-summary-table-output table.dataTable thead th.psd-summary-comparison-start,
      .psd-map-summary-table-output table.dataTable tbody td.psd-summary-comparison-start {
        border-left: 2px solid #c9d1d9 !important;
      }
      #psd_map_matrix_table table.dataTable thead th.psd-matrix-comparison-percent,
      #psd_map_matrix_table table.dataTable tbody td.psd-matrix-comparison-percent,
      #map_summary_table table.dataTable thead th.psd-summary-comparison-percent,
      #map_summary_table table.dataTable tbody td.psd-summary-comparison-percent,
      #myc_market_year_table table.dataTable thead th.psd-summary-comparison-percent,
      #myc_market_year_table table.dataTable tbody td.psd-summary-comparison-percent,
      .non-psd-map-summary-table-output table.dataTable thead th.psd-summary-comparison-percent,
      .non-psd-map-summary-table-output table.dataTable tbody td.psd-summary-comparison-percent,
      .psd-map-summary-table-output table.dataTable thead th.psd-summary-comparison-percent,
      .psd-map-summary-table-output table.dataTable tbody td.psd-summary-comparison-percent {
        background-color: #f2f4f6;
        font-weight: 600;
      }
      #psd_map_matrix_table table.dataTable tbody tr:hover td.psd-matrix-comparison-band,
      #psd_map_matrix_table table.dataTable tbody tr:hover td.psd-matrix-comparison-percent,
      #map_summary_table table.dataTable tbody tr:hover td.psd-summary-comparison-band,
      #map_summary_table table.dataTable tbody tr:hover td.psd-summary-comparison-percent,
      #myc_market_year_table table.dataTable tbody tr:hover td.psd-summary-comparison-band,
      #myc_market_year_table table.dataTable tbody tr:hover td.psd-summary-comparison-percent,
      .non-psd-map-summary-table-output table.dataTable tbody tr:hover td.psd-summary-comparison-band,
      .non-psd-map-summary-table-output table.dataTable tbody tr:hover td.psd-summary-comparison-percent,
      .psd-map-summary-table-output table.dataTable tbody tr:hover td.psd-summary-comparison-band,
      .psd-map-summary-table-output table.dataTable tbody tr:hover td.psd-summary-comparison-percent {
        background-color: #f3f6f8;
      }
    ')),
      tags$script(HTML(sprintf(
        "window.riceClientDebug = {\n  notesTraceEnabled: %s,\n  notesProbeEnabled: %s,\n  psdTraceEnabled: %s,\n  psdProbeEnabled: %s,\n  sourceShellTraceEnabled: %s,\n  mycProbeEnabled: %s,\n  manualCaptureEnabled: %s,\n  perfBoundaryMarkersEnabled: %s\n};\nwindow.almondClientDebug = window.riceClientDebug;",
        tolower(as.character(isTRUE(getOption("rice_notes_transition_log", default = FALSE)))),
        tolower(as.character(isTRUE(getOption("rice_notes_selectize_probe", default = FALSE)))),
        tolower(as.character(
          isTRUE(getOption("almond_psd_transition_log", default = FALSE)) ||
            isTRUE(getOption("rice_psd_transition_log", default = FALSE))
        )),
        tolower(as.character(isTRUE(getOption("rice_psd_map_selectize_probe", default = FALSE)))),
        tolower(as.character(isTRUE(getOption("rice_source_shell_trace", default = FALSE)))),
        tolower(as.character(isTRUE(getOption("rice_myc_selectize_probe", default = FALSE)))),
        tolower(as.character(
          isTRUE(getOption("rice_notes_transition_log", default = FALSE)) ||
            isTRUE(getOption("almond_psd_transition_log", default = FALSE)) ||
            isTRUE(getOption("rice_psd_transition_log", default = FALSE)) ||
            isTRUE(getOption("rice_psd_map_selectize_probe", default = FALSE))
        )),
        tolower(as.character(
          isTRUE(getOption("vp_perf_boundary_markers", default = FALSE)) ||
            isTRUE(getOption("rice_perf_boundary_markers", default = FALSE)) ||
            perf_truthy(Sys.getenv("VP_PERF_BOUNDARY_MARKERS", unset = ""), default = FALSE)
        ))
      ))),
    # JavaScript for dragging functionality
    tags$script(HTML("
      $(document).ready(function() {
        var isDragging = false;
        var offsetX, offsetY;
        var pendingNotesPanelResizeTimer = null;
        var perfState = {
          pageLoadStartedAt: window.performance ? window.performance.now() : Date.now(),
          lastTabClickedAt: null,
          lastTabName: null,
          actionId: 0,
          mutationSeq: 0,
          actionReason: 'initial_mount',
          actionStartedAt: null,
          mainTabsMountLogged: false,
          mainTabsLastProfileKey: null,
          mainTabsProfileProbeScheduled: false,
          mainTabsSafeSelectLastKey: null,
          sourceShellLastKey: null,
          sourceShellLastSentAt: 0,
          sourceShellSampleSeq: 0,
          sourceSurfaceRefreshRequests: {},
          outputMaterializationMarkerKeys: {}
        };
        var pendingPlotlyResizeTimer = null;
        var pendingPlotlyResizeMessage = null;
        var riceClientDebug = window.riceClientDebug || {};

        function notesTraceEnabled() {
          return !!riceClientDebug.notesTraceEnabled;
        }

        function notesProbeEnabled() {
          return !!riceClientDebug.notesProbeEnabled;
        }

        function psdTraceEnabled() {
          return !!riceClientDebug.psdTraceEnabled;
        }

        function psdProbeEnabled() {
          return !!riceClientDebug.psdProbeEnabled;
        }

        function psdClientDebugActive() {
          return psdTraceEnabled() || psdProbeEnabled();
        }

        function sourceShellTraceEnabled() {
          return !!riceClientDebug.sourceShellTraceEnabled;
        }

        function mycProbeEnabled() {
          return !!riceClientDebug.mycProbeEnabled;
        }

        function perfBoundaryMarkersEnabled() {
          return !!riceClientDebug.perfBoundaryMarkersEnabled;
        }

        function notesClientDebugActive() {
          return notesTraceEnabled() || notesProbeEnabled();
        }

        function manualCaptureEnabled() {
          return !!riceClientDebug.manualCaptureEnabled;
        }

        function perfNow() {
          return window.performance ? window.performance.now() : Date.now();
        }

        function beginPerfAction(reason) {
          perfState.actionId = (perfState.actionId || 0) + 1;
          perfState.mutationSeq = 0;
          perfState.actionReason = reason || 'unknown';
          perfState.actionStartedAt = perfNow();
          perfState.outputMaterializationMarkerKeys = {};

          if (perfState.actionReason !== 'initial_mount') {
            emitBoundaryMarker('action_begin', {
              reason: perfState.actionReason
            });
          }

          return perfState.actionId;
        }

        function nextPerfMutationSeq() {
          perfState.mutationSeq = (perfState.mutationSeq || 0) + 1;
          return perfState.mutationSeq;
        }

        function notesFloatingPanelSnapshot() {
          var panel = document.getElementById('floating_notes_panel');
          var header = document.getElementById('notes_panel_header');
          var viewportWidth = window.innerWidth || document.documentElement.clientWidth || 0;
          var viewportHeight = window.innerHeight || document.documentElement.clientHeight || 0;

          if (!panel) {
            return {
              exists: false,
              viewport_width: viewportWidth,
              viewport_height: viewportHeight
            };
          }

          var style = window.getComputedStyle(panel);
          var rect = panel.getBoundingClientRect();
          var headerRect = header ? header.getBoundingClientRect() : rect;
          var panelVisible = panel.classList.contains('visible') && style.display !== 'none' && style.visibility !== 'hidden' && rect.width > 0 && rect.height > 0;
          var finiteGeometry = [rect.left, rect.top, rect.right, rect.bottom, rect.width, rect.height].every(function(value) {
            return Number.isFinite(value);
          });
          var headerReachable = panelVisible && headerRect.right > 0 && headerRect.left < viewportWidth && headerRect.bottom > 0 && headerRect.top < viewportHeight;
          var panelReachable = panelVisible && rect.right > 0 && rect.left < viewportWidth && rect.bottom > 0 && rect.top < viewportHeight;
          var fullyInViewport = panelVisible && rect.left >= 0 && rect.top >= 0 && rect.right <= viewportWidth && rect.bottom <= viewportHeight;

          return {
            exists: true,
            class_visible: panel.classList.contains('visible'),
            display: style.display,
            visibility: style.visibility,
            css_left: style.left,
            css_right: style.right,
            css_top: style.top,
            css_width: style.width,
            css_height: style.height,
            left: rect.left,
            top: rect.top,
            right: rect.right,
            bottom: rect.bottom,
            width: rect.width,
            height: rect.height,
            header_left: headerRect.left,
            header_top: headerRect.top,
            header_right: headerRect.right,
            header_bottom: headerRect.bottom,
            viewport_width: viewportWidth,
            viewport_height: viewportHeight,
            panel_visible: panelVisible,
            panel_reachable: panelReachable,
            header_reachable: headerReachable,
            fully_in_viewport: fullyInViewport,
            finite_geometry: finiteGeometry,
            exceeds_viewport_width: rect.width > viewportWidth,
            exceeds_viewport_height: rect.height > viewportHeight
          };
        }

        function notesPanelLimits() {
          var margin = 12;
          var viewportWidth = window.innerWidth || document.documentElement.clientWidth || 0;
          var viewportHeight = window.innerHeight || document.documentElement.clientHeight || 0;

          return {
            margin: margin,
            viewport_width: viewportWidth,
            viewport_height: viewportHeight,
            max_width: Math.min(600, Math.max(160, viewportWidth - (margin * 2))),
            max_height: Math.max(120, viewportHeight - (margin * 2))
          };
        }

        function hardResetNotesFloatingPanel(panel, reason) {
          var limits = notesPanelLimits();
          var width = Math.min(320, limits.max_width);
          var top = Math.min(100, Math.max(limits.margin, limits.viewport_height - limits.max_height - limits.margin));

          panel.css({
            left: 'auto',
            right: '20px',
            top: top + 'px',
            width: width + 'px',
            height: '',
            maxWidth: limits.max_width + 'px',
            maxHeight: limits.max_height + 'px'
          });

          return {
            changed: true,
            hard_reset: true,
            reason: reason || 'hard_reset'
          };
        }

        function recoverNotesFloatingPanel(options) {
          options = options || {};
          var panel = $('#floating_notes_panel');
          if (!panel.length) {
            return {
              changed: false,
              reason: options.reason || null,
              before: notesFloatingPanelSnapshot(),
              after: notesFloatingPanelSnapshot()
            };
          }

          var before = notesFloatingPanelSnapshot();
          var limits = notesPanelLimits();
          var changed = false;
          var hardReset = false;
          var steps = [];

          panel.css({
            maxWidth: limits.max_width + 'px',
            maxHeight: limits.max_height + 'px'
          });

          if (!before.exists || !before.finite_geometry) {
            var resetResult = hardResetNotesFloatingPanel(panel, 'invalid_geometry');
            hardReset = true;
            changed = true;
            steps.push(resetResult.reason);
          } else {
            var targetWidth = Math.min(before.width, limits.max_width);
            var targetHeight = Math.min(before.height, limits.max_height);

            if (Number.isFinite(targetWidth) && targetWidth > 0 && Math.abs(targetWidth - before.width) > 0.5) {
              panel.css('width', targetWidth + 'px');
              changed = true;
              steps.push('width_clamped');
            }
            if (Number.isFinite(targetHeight) && targetHeight > 0 && Math.abs(targetHeight - before.height) > 0.5) {
              panel.css('height', targetHeight + 'px');
              changed = true;
              steps.push('height_clamped');
            }
          }

          var current = notesFloatingPanelSnapshot();
          if (!hardReset && current.exists && current.finite_geometry) {
            var left = Number.isFinite(options.left) ? Number(options.left) : current.left;
            var top = Number.isFinite(options.top) ? Number(options.top) : current.top;
            var maxLeft = Math.max(limits.margin, limits.viewport_width - current.width - limits.margin);
            var maxTop = Math.max(limits.margin, limits.viewport_height - current.height - limits.margin);
            var clampedLeft = Math.min(Math.max(left, limits.margin), maxLeft);
            var clampedTop = Math.min(Math.max(top, limits.margin), maxTop);

            if (!current.header_reachable || !current.fully_in_viewport || Math.abs(clampedLeft - current.left) > 0.5 || Math.abs(clampedTop - current.top) > 0.5) {
              panel.css({
                left: clampedLeft + 'px',
                top: clampedTop + 'px',
                right: 'auto'
              });
              changed = true;
              steps.push('position_clamped');
            }
          }

          var after = notesFloatingPanelSnapshot();
          var result = {
            changed: changed,
            hard_reset: hardReset,
            reason: options.reason || null,
            steps: steps,
            before: before,
            after: after
          };

          if (notesClientDebugActive() && changed) {
            emitNotesTrace('panel_geometry_recovered', result);
          }

          return result;
        }

        window.notesFloatingPanelGeometrySnapshot = notesFloatingPanelSnapshot;
        window.notesFloatingPanelRecover = recoverNotesFloatingPanel;

        function mainTabsInput() {
          var outputRoot = $('#main_tabs');
          var scopedInput = outputRoot.find('[id=main_tabs_panel]').last();
          if (scopedInput.length) return scopedInput;
          return $('[id=main_tabs_panel]').last();
        }

        function mainTabsContainer() {
          var inputEl = mainTabsInput();
          if (!inputEl.length) return $();
          return inputEl.closest('.tabbable');
        }

        function mainTabsProfileShell() {
          var inputEl = mainTabsInput();
          if (!inputEl.length) return $();
          return inputEl.closest('.main-tabs-profile-shell');
        }

        function currentMainTabValue() {
          var inputEl = mainTabsInput();
          if (!inputEl.length) return null;
          var value = inputEl.val();
          return value && value.length ? value : null;
        }

        function isMainTabsAnchor(anchorEl) {
          var container = mainTabsContainer();
          if (!container.length) return false;
          var anchorContainer = $(anchorEl).closest('.tabbable');
          return anchorContainer.length && anchorContainer.get(0) === container.get(0);
        }

        function activeTabName() {
          var container = mainTabsContainer();
          var activeTab = container.find('> .nav > li.active > a, > .nav-tabs > li.active > a').first();
          if (!activeTab.length) return currentMainTabValue();
          var dataValue = activeTab.attr('data-value');
          if (dataValue && dataValue.length) return dataValue;
          var text = $.trim(activeTab.text());
          return text || currentMainTabValue();
        }

        function mainTabsAnchorForValue(container, tabValue) {
          var requested = $.trim(String(tabValue || ''));
          if (!requested.length || !container.length) return $();

          var anchors = container.find('> .nav > li > a, > .nav-tabs > li > a');
          var dataValueMatch = anchors.filter(function() {
            return String($(this).attr('data-value') || '') === requested;
          }).first();
          if (dataValueMatch.length) return dataValueMatch;

          return anchors.filter(function() {
            return $.trim($(this).text()) === requested;
          }).first();
        }

        function mainTabsReadinessSnapshot(expectedSource, expectedProfile, expectedCount) {
          var inputEl = mainTabsInput();
          var container = mainTabsContainer();
          var shell = mainTabsProfileShell();
          var navLinks = container.find('> .nav > li > a, > .nav-tabs > li > a');
          var tabPanes = container.find('> .tab-content > .tab-pane');
          var domSource = shell.attr('data-main-tabs-source') || null;
          var domProfile = shell.attr('data-main-tabs-profile') || null;
          var expectedCountReady = expectedCount === null || navLinks.length === expectedCount;

          return {
            input_present: inputEl.length > 0,
            shell_present: shell.length > 0,
            source: domSource,
            profile: domProfile,
            nav_link_count: navLinks.length,
            tab_pane_count: tabPanes.length,
            source_ready: !expectedSource || domSource === expectedSource,
            profile_ready: !expectedProfile || domProfile === expectedProfile,
            count_ready: expectedCountReady
          };
        }

        function expectedMainTabsProfileForSource(sourceValue) {
          var normalizedSource = sourceValue == null ? '' : $.trim(String(sourceValue));
          if (normalizedSource === 'psd') return 'psd';
          if (normalizedSource === 'nass') return 'wasde';
          if (normalizedSource === 'wasde') return 'wasde';
          return 'non_psd';
        }

        function selectMainTabWhenProfileReady(message) {
          var payload = message || {};
          var targetTab = $.trim(String(payload.tab || ''));
          var expectedSource = payload.source ? String(payload.source) : null;
          var expectedProfile = payload.profile ? String(payload.profile) : null;
          var expectedCount = payload.expected_count == null ? null : parseInt(payload.expected_count, 10);
          var maxAttempts = parseInt(payload.max_attempts == null ? 20 : payload.max_attempts, 10);
          var retryDelayMs = parseInt(payload.retry_delay_ms == null ? 75 : payload.retry_delay_ms, 10);
          var initialDelayMs = parseInt(payload.delay_ms == null ? 0 : payload.delay_ms, 10);
          var requestId = payload.request_id || [expectedSource, expectedProfile, targetTab, Date.now()].join('|');
          var reason = payload.reason || 'safe_main_tab_select';
          var attempt = 0;

          if (!Number.isFinite(expectedCount)) expectedCount = null;
          if (!Number.isFinite(maxAttempts) || maxAttempts < 1) maxAttempts = 20;
          if (!Number.isFinite(retryDelayMs) || retryDelayMs < 0) retryDelayMs = 75;
          if (!Number.isFinite(initialDelayMs) || initialDelayMs < 0) initialDelayMs = 0;

          function emitSafeSelect(status, extra) {
            emitClientPerf('client_perf_main_tabs_safe_select', $.extend({
              status: status,
              reason: reason,
              request_id: requestId,
              requested_tab: targetTab,
              expected_source: expectedSource,
              expected_profile: expectedProfile,
              expected_count: expectedCount,
              attempt: attempt
            }, extra || {}));
          }

          function scheduleRetry() {
            window.setTimeout(trySelect, retryDelayMs);
          }

          function trySelect() {
            attempt += 1;
            var readiness = mainTabsReadinessSnapshot(expectedSource, expectedProfile, expectedCount);
            var container = mainTabsContainer();
            var ready = readiness.input_present && readiness.shell_present && readiness.nav_link_count > 0 &&
              readiness.source_ready && readiness.profile_ready && readiness.count_ready;

            if (!targetTab.length) {
              emitSafeSelect('skipped_no_target', readiness);
              return;
            }

            if (!ready) {
              if (attempt < maxAttempts) {
                scheduleRetry();
                return;
              }
              emitSafeSelect('timeout_not_ready', readiness);
              emitMainTabsProfileSnapshot('safe_select_timeout_not_ready');
              return;
            }

            var currentInputValue = currentMainTabValue();
            var psdAllowedTabs = ['Map', 'Time Series Analysis Tool'];
            if (expectedProfile === 'psd' && psdAllowedTabs.indexOf(currentInputValue) >= 0 &&
                currentInputValue !== targetTab) {
              emitSafeSelect('skipped_stale_target', $.extend({
                current_input_value: currentInputValue
              }, readiness));
              return;
            }

            var anchor = mainTabsAnchorForValue(container, targetTab);
            if (!anchor.length) {
              if (attempt < maxAttempts) {
                scheduleRetry();
                return;
              }
              emitSafeSelect('timeout_tab_missing', readiness);
              emitMainTabsProfileSnapshot('safe_select_timeout_tab_missing');
              return;
            }

            var beforeTab = activeTabName();
            try {
              if ($.fn.tab) {
                anchor.tab('show');
              } else {
                anchor.trigger('click');
              }
            } catch (error) {
              emitSafeSelect('error', $.extend({
                error_message: error && error.message ? error.message : String(error)
              }, readiness));
              return;
            }

            window.requestAnimationFrame(function() {
              emitSafeSelect('applied', $.extend({
                before_tab: beforeTab,
                after_tab: activeTabName(),
                input_value: currentMainTabValue()
              }, readiness));
              emitMainTabsProfileSnapshot('safe_select_applied');
            });
          }

          var requestKey = [requestId, targetTab, expectedSource, expectedProfile, expectedCount].join('|');
          if (requestKey === perfState.mainTabsSafeSelectLastKey) return;
          perfState.mainTabsSafeSelectLastKey = requestKey;
          window.setTimeout(trySelect, initialDelayMs);
        }

        function mainTabsProfileSnapshot(reason) {
          var inputEl = mainTabsInput();
          var container = mainTabsContainer();
          var shell = mainTabsProfileShell();
          var navLinks = container.find('> .nav > li > a, > .nav-tabs > li > a');
          var tabPanes = container.find('> .tab-content > .tab-pane');
          var inputValues = (window.Shiny && window.Shiny.shinyapp && window.Shiny.shinyapp.$inputValues) || {};
          var source = shell.attr('data-main-tabs-source') || null;
          var profile = shell.attr('data-main-tabs-profile') || null;
          var expectedCountRaw = shell.attr('data-main-tabs-expected-count');
          var expectedCount = expectedCountRaw ? parseInt(expectedCountRaw, 10) : null;
          var serverSource = inputValues.data_source_choice || null;
          var expectedProfile = expectedMainTabsProfileForSource(serverSource);

          if (!inputEl.length || !navLinks.length) return null;

          return {
            reason: reason || 'main_tabs_profile',
            tab: activeTabName(),
            main_tabs_panel: currentMainTabValue(),
            profile: profile,
            source: source,
            server_source: serverSource,
            expected_profile: expectedProfile,
            expected_count: expectedCount,
            nav_link_count: navLinks.length,
            tab_pane_count: tabPanes.length,
            selected: shell.attr('data-main-tabs-selected') || null,
            render_key: shell.attr('data-main-tabs-render-key') || null,
            profile_mismatch: !!(profile && expectedProfile && profile !== expectedProfile),
            count_mismatch: expectedCount !== null && expectedCount !== navLinks.length,
            dom_node_count: container.find('*').length
          };
        }

        function nodeInScope(node, scope) {
          if (!node) return false;
          if (!scope || !scope.length) return true;
          return scope.is(node) || scope.has(node).length > 0;
        }

        function scopedInputsByName(inputId, scope) {
          var selector = 'input[name=\"' + inputId + '\"]';
          return scope && scope.length ? scope.find(selector) : $(selector);
        }

        function domInputValue(inputId, scope) {
          var node = document.getElementById(inputId);
          if (!nodeInScope(node, scope)) node = null;
          if (node && node.selectize && typeof node.selectize.getValue === 'function') {
            var selectizeValue = node.selectize.getValue();
            return Array.isArray(selectizeValue) ? selectizeValue.join('|') : String(selectizeValue || '');
          }

          var checkedRadio = scopedInputsByName(inputId, scope).filter(':checked');
          if (checkedRadio.length) return String(checkedRadio.val() || '');

          if (!node) return null;

          var value = $(node).val();
          if (Array.isArray(value)) return value.join('|');
          return value == null ? null : String(value);
        }

        function inputPresent(inputId, scope) {
          var node = document.getElementById(inputId);
          return nodeInScope(node, scope) || scopedInputsByName(inputId, scope).length > 0;
        }

        function radioValues(inputId, scope) {
          return scopedInputsByName(inputId, scope).map(function() {
            return String($(this).val() || '');
          }).get().filter(function(value) {
            return value.length > 0;
          }).join('|');
        }

        function compactDomText(element) {
          if (!element || !element.length) return '';
          return $.trim(String(element.text() || '').replace(/\\s+/g, ' ')).slice(0, 500);
        }

        function sanitizeTraceToken(value) {
          if (value == null) return '';
          return String(value)
            .replace(/[\\r\\n,|]+/g, '_')
            .replace(/[ ]+/g, '_')
            .slice(0, 120);
        }

        function uniquePipeTokens(values) {
          var seen = {};
          return (values || []).map(sanitizeTraceToken).filter(function(value) {
            if (!value.length || seen[value]) return false;
            seen[value] = true;
            return true;
          }).join('|');
        }

        function elementVisibilityProbe(element) {
          var wrapped = element && element.jquery ? element : $(element || []);
          var node = wrapped.length ? wrapped.get(0) : null;
          if (!node) {
            return {
              present: false,
              jquery_visible: false,
              computed_display: '<missing>',
              computed_visibility: '<missing>',
              computed_opacity: '<missing>',
              width: 0,
              height: 0,
              content_visible: false
            };
          }

          var computed = window.getComputedStyle ? window.getComputedStyle(node) : null;
          var rect = node.getBoundingClientRect ? node.getBoundingClientRect() : { width: 0, height: 0 };
          var display = computed ? computed.display : '<unknown>';
          var visibility = computed ? computed.visibility : '<unknown>';
          var opacity = computed ? computed.opacity : '<unknown>';
          var numericOpacity = parseFloat(opacity);
          if (!Number.isFinite(numericOpacity)) numericOpacity = 1;
          var width = Math.round((rect && rect.width ? rect.width : wrapped.outerWidth() || 0) * 10) / 10;
          var height = Math.round((rect && rect.height ? rect.height : wrapped.outerHeight() || 0) * 10) / 10;
          var contentVisible = display !== 'none' && visibility !== 'hidden' && visibility !== 'collapse' &&
            numericOpacity > 0 && width > 0 && height > 0;

          return {
            present: true,
            jquery_visible: wrapped.is(':visible'),
            computed_display: sanitizeTraceToken(display),
            computed_visibility: sanitizeTraceToken(visibility),
            computed_opacity: sanitizeTraceToken(opacity),
            width: width,
            height: height,
            content_visible: contentVisible
          };
        }

        function inputEffectiveVisible(inputId, scope) {
          var node = document.getElementById(inputId);
          if (nodeInScope(node, scope)) {
            if (node && node.selectize && node.selectize.$control && node.selectize.$control.length) {
              if (elementVisibilityProbe(node.selectize.$control).content_visible) return true;
            }

            var nodeProbe = elementVisibilityProbe($(node));
            if (nodeProbe.content_visible) return true;

            var nodeContainerProbe = elementVisibilityProbe($(node).closest('.form-group, .shiny-input-container, label'));
            if (nodeContainerProbe.content_visible) return true;
          }

          return scopedInputsByName(inputId, scope).filter(function() {
            var inputElement = $(this);
            if (elementVisibilityProbe(inputElement).content_visible) return true;
            return elementVisibilityProbe(inputElement.closest('label, .radio, .checkbox, .form-group, .shiny-input-container')).content_visible;
          }).length > 0;
        }

        function surfaceProbe(elementOrSelector) {
          var element = elementOrSelector && elementOrSelector.jquery ? elementOrSelector : $(elementOrSelector || []);
          element = element.first();
          var probe = elementVisibilityProbe(element);
          if (!probe.present) {
            return $.extend(probe, {
              text_length: 0,
              child_input_count: 0,
              visible_child_input_count: 0,
              hidden_child_input_count: 0,
              selectize_count: 0,
              child_input_ids: ''
            });
          }

          var childInputs = element.find('input, select, textarea, button').addBack('input, select, textarea, button').filter(function() {
            return !!(this.id || this.name);
          });
          var visibleChildInputs = childInputs.filter(function() {
            var inputElement = $(this);
            if (this.selectize && this.selectize.$control && this.selectize.$control.length) {
              return elementVisibilityProbe(this.selectize.$control).content_visible;
            }
            if (elementVisibilityProbe(inputElement).content_visible) return true;
            return elementVisibilityProbe(inputElement.closest('label, .radio, .checkbox, .form-group, .shiny-input-container')).content_visible;
          });
          var inputIds = childInputs.map(function() {
            return this.id || this.name || '';
          }).get();

          return $.extend(probe, {
            text_length: compactDomText(element).length,
            child_input_count: childInputs.length,
            visible_child_input_count: visibleChildInputs.length,
            hidden_child_input_count: Math.max(0, childInputs.length - visibleChildInputs.length),
            selectize_count: element.find('.selectize-control').length,
            child_input_ids: uniquePipeTokens(inputIds)
          });
        }

        function surfaceMetadata(elementOrSelector) {
          var element = elementOrSelector && elementOrSelector.jquery ? elementOrSelector : $(elementOrSelector || []);
          element = element.first();
          var emptyMetadata = {
            source_profile: null,
            source_epoch: null,
            rendered_builder: null,
            rendered_surface: null
          };
          if (!element.length) return emptyMetadata;

          var metadataNode = element.filter('[data-source-profile], [data-source-epoch], [data-rendered-builder], [data-rendered-surface]').first();
          if (!metadataNode.length) {
            metadataNode = element.find('[data-source-profile], [data-source-epoch], [data-rendered-builder], [data-rendered-surface]').first();
          }
          if (!metadataNode.length) return emptyMetadata;

          return {
            source_profile: sanitizeTraceToken(metadataNode.attr('data-source-profile') || '') || null,
            source_epoch: sanitizeTraceToken(metadataNode.attr('data-source-epoch') || '') || null,
            rendered_builder: sanitizeTraceToken(metadataNode.attr('data-rendered-builder') || '') || null,
            rendered_surface: sanitizeTraceToken(metadataNode.attr('data-rendered-surface') || '') || null
          };
        }

        function sourceShellSnapshot(reason) {
          var inputValues = (window.Shiny && window.Shiny.shinyapp && window.Shiny.shinyapp.$inputValues) || {};
          var mainSnapshot = mainTabsProfileSnapshot(reason || 'source_shell') || {};
          var currentMainTab = currentMainTabValue();
          var currentActiveTab = activeTabName();
          var topOutput = $('#data_frequency_ui');
          var sidebarOutput = $('#market_year_compare_filters_ui');
          var psdMapControlsOutput = $('#psd_map_controls_ui');
          var metricOutput = $('#metric_choice_ui');
          var unitOutput = $('#unit_controls_ui');
          var bottomOutput = $('#map_bottom_panel_ui');
          var mapPlotOutput = $('#map_plot');
          var timeseriesOutput = $('#timeseries_plot');
          var yearFilterOutput = $('#year_filter');
          var topProbe = surfaceProbe(topOutput);
          var sidebarProbe = surfaceProbe(sidebarOutput);
          var psdMapControlsProbe = surfaceProbe(psdMapControlsOutput);
          var metricProbe = surfaceProbe(metricOutput);
          var unitProbe = surfaceProbe(unitOutput);
          var bottomProbe = surfaceProbe(bottomOutput);
          var mapPlotProbe = surfaceProbe(mapPlotOutput);
          var timeseriesProbe = surfaceProbe(timeseriesOutput);
          var yearFilterProbe = surfaceProbe(yearFilterOutput);
          var sidebarMetadata = surfaceMetadata(sidebarOutput);
          var bottomMetadata = surfaceMetadata(bottomOutput);
          var topText = compactDomText(topOutput);
          var timeseriesText = compactDomText(timeseriesOutput);
          var frequencyValues = radioValues('data_frequency', topOutput);
          var frequencyParts = frequencyValues ? frequencyValues.split('|') : [];
          var yearFilterInputs = yearFilterOutput.find('input[type=checkbox]');
          var yearFilterCheckedInputs = yearFilterInputs.filter(':checked');
          var yearFilterCheckedValues = uniquePipeTokens(yearFilterCheckedInputs.map(function() {
            return $(this).val() || '';
          }).get());
          var serverSource = inputValues.data_source_choice || domInputValue('data_source_choice') || null;
          var expectedProfile = expectedMainTabsProfileForSource(serverSource);
          var isPsdSource = serverSource === 'psd';
          var topPsdHelperPresent = topText.indexOf('PSD uses annual market-year updates only.') !== -1;
          var topWeeklyPresent = frequencyParts.indexOf('weekly') !== -1;
          var topYearTypePresent = inputPresent('year_type_choice', topOutput);
          var topCensusTradeFlowPresent = inputPresent('census_trade_flow_choice', topOutput);
          var topHybridTradeFlowPresent = inputPresent('hybrid_trade_flow_choice', topOutput);
          var topHybridModePresent = inputPresent('hybrid_mode_choice', topOutput);
          var sidebarPsdCountryPresent = inputPresent('psd_map_country_choice', sidebarOutput);
          var sidebarNonPsdCutoffPresent = inputPresent('map_use_latest_period', sidebarOutput) || inputPresent('map_cutoff_period', sidebarOutput);
          var sidebarPsdCountryVisible = inputEffectiveVisible('psd_map_country_choice', sidebarOutput);
          var sidebarNonPsdCutoffVisible = inputEffectiveVisible('map_use_latest_period', sidebarOutput) || inputEffectiveVisible('map_cutoff_period', sidebarOutput);
          var bottomPsdViewPresent = inputPresent('psd_map_bottom_view', bottomOutput);
          var bottomPsdCurrentPresent = bottomOutput.find('#psd_map_summary_table_current').length > 0;
          var bottomPsdComparisonPresent = bottomOutput.find('#psd_map_summary_table_comparison').length > 0;
          var bottomPsdMatrixPresent = bottomOutput.find('#psd_map_matrix_table').length > 0;
          var bottomPsdCurrentVisible = elementVisibilityProbe(bottomOutput.find('#psd_map_summary_table_current').first()).content_visible;
          var bottomPsdComparisonVisible = elementVisibilityProbe(bottomOutput.find('#psd_map_summary_table_comparison').first()).content_visible;
          var bottomPsdMatrixVisible = elementVisibilityProbe(bottomOutput.find('#psd_map_matrix_table').first()).content_visible;
          var bottomPsdPresent = bottomPsdViewPresent || bottomPsdCurrentPresent || bottomPsdComparisonPresent || bottomPsdMatrixPresent;
          var bottomNonPsdCurrentPresent = bottomOutput.find('#non_psd_map_summary_table_current').length > 0;
          var bottomNonPsdComparisonPresent = bottomOutput.find('#non_psd_map_summary_table_comparison').length > 0;
          var bottomNonPsdLegacyPresent = bottomOutput.find('#map_summary_table').length > 0;
          var bottomNonPsdWrapperPresent = bottomOutput.find('.non-psd-map-summary-table-output').length > 0;
          var bottomNonPsdCurrentVisible = elementVisibilityProbe(bottomOutput.find('#non_psd_map_summary_table_current').first()).content_visible;
          var bottomNonPsdComparisonVisible = elementVisibilityProbe(bottomOutput.find('#non_psd_map_summary_table_comparison').first()).content_visible;
          var bottomNonPsdLegacyVisible = elementVisibilityProbe(bottomOutput.find('#map_summary_table').first()).content_visible;
          var bottomNonPsdWrapperVisible = elementVisibilityProbe(bottomOutput.find('.non-psd-map-summary-table-output').first()).content_visible;
          var bottomNonPsdPresent = bottomNonPsdCurrentPresent || bottomNonPsdComparisonPresent || bottomNonPsdLegacyPresent || bottomNonPsdWrapperPresent;
          var bottomNonPsdVisible = bottomNonPsdCurrentVisible || bottomNonPsdComparisonVisible || bottomNonPsdLegacyVisible || bottomNonPsdWrapperVisible;
          var mainSourceMismatch = !!(mainSnapshot.source && serverSource && mainSnapshot.source !== serverSource);
          var mainProfileMismatch = !!(mainSnapshot.profile && expectedProfile && mainSnapshot.profile !== expectedProfile);
          var topNonPsdFragmentsPresent = topWeeklyPresent || topYearTypePresent || topCensusTradeFlowPresent ||
            topHybridTradeFlowPresent || topHybridModePresent;
          var topPsdFragmentsPresent = topPsdHelperPresent;
          var sidebarPsdFragmentsPresent = sidebarPsdCountryPresent;
          var sidebarNonPsdFragmentsPresent = sidebarNonPsdCutoffPresent;
          var bottomPsdFragmentsPresent = bottomPsdPresent;
          var bottomNonPsdFragmentsPresent = bottomNonPsdPresent;
          var psdFragmentsPresent = topPsdFragmentsPresent || sidebarPsdFragmentsPresent || bottomPsdFragmentsPresent;
          var nonPsdFragmentsPresent = topNonPsdFragmentsPresent || sidebarNonPsdFragmentsPresent || bottomNonPsdFragmentsPresent;
          var sidebarMetadataMismatch = !!(sidebarMetadata.source_profile && expectedProfile && sidebarMetadata.source_profile !== expectedProfile);
          var bottomMetadataMismatch = !!(bottomMetadata.source_profile && expectedProfile && bottomMetadata.source_profile !== expectedProfile);
          var isMapTab = currentMainTab === 'Map' || currentActiveTab === 'Map';
          var sidebarStaleNonPsd = !!(isPsdSource && isMapTab && sidebarNonPsdFragmentsPresent);
          var bottomStaleNonPsd = !!(isPsdSource && isMapTab && bottomNonPsdFragmentsPresent);
          var psdControlsMissing = !!(isPsdSource && isMapTab && !sidebarPsdCountryPresent);
          var topShellMismatch = isPsdSource ? (topNonPsdFragmentsPresent && !topPsdFragmentsPresent) :
            (topPsdFragmentsPresent && !topNonPsdFragmentsPresent);
          var sidebarShellMismatch = isPsdSource ? (sidebarNonPsdFragmentsPresent && !sidebarPsdFragmentsPresent) :
            (sidebarPsdFragmentsPresent && !sidebarNonPsdFragmentsPresent);
          var bottomShellMismatch = isPsdSource ? (bottomNonPsdFragmentsPresent && !bottomPsdFragmentsPresent) :
            (bottomPsdFragmentsPresent && !bottomNonPsdFragmentsPresent);
          var sourceShellMismatch = mainSourceMismatch || mainProfileMismatch || topShellMismatch ||
            sidebarShellMismatch || bottomShellMismatch || sidebarMetadataMismatch || bottomMetadataMismatch;
          var mismatchReasons = [];
          if (mainSourceMismatch) mismatchReasons.push('main_source');
          if (mainProfileMismatch) mismatchReasons.push('main_profile');
          if (mainSourceMismatch || mainProfileMismatch) mismatchReasons.push('main_shell_lagging');
          if (topShellMismatch) mismatchReasons.push('top');
          if (sidebarShellMismatch) mismatchReasons.push('sidebar');
          if (bottomShellMismatch) mismatchReasons.push('bottom');
          if (sidebarMetadataMismatch) mismatchReasons.push('sidebar_metadata');
          if (bottomMetadataMismatch) mismatchReasons.push('bottom_metadata');
          if (sidebarStaleNonPsd) mismatchReasons.push('sidebar_stale_non_psd');
          if (bottomStaleNonPsd) mismatchReasons.push('bottom_stale_non_psd');
          if (psdControlsMissing) mismatchReasons.push('psd_controls_missing');
          var sourceShellMismatchReason = mismatchReasons.length ? mismatchReasons.join('|') : 'none';
          var sidebarBlankOrMasked = sidebarProbe.present && (!sidebarProbe.content_visible ||
            (sidebarProbe.text_length === 0 && sidebarProbe.child_input_count === 0));
          var timeseriesState = 'absent';
          if (timeseriesProbe.present) {
            if (timeseriesText.indexOf('No data available for selected years') !== -1) {
              timeseriesState = 'no_data_selected_years';
            } else if (timeseriesText.indexOf('No data available') !== -1) {
              timeseriesState = 'no_data';
            } else if (timeseriesProbe.content_visible && timeseriesText.length > 0) {
              timeseriesState = 'rendered';
            } else if (timeseriesProbe.content_visible) {
              timeseriesState = 'visible_blank';
            } else {
              timeseriesState = 'hidden';
            }
          }

          return {
            reason: reason || 'source_shell',
            active_tab: currentActiveTab,
            main_tabs_panel: currentMainTab,
            server_source: serverSource,
            expected_profile: expectedProfile,
            main_dom_source: mainSnapshot.source || null,
            main_dom_profile: mainSnapshot.profile || null,
            main_expected_count: mainSnapshot.expected_count || null,
            main_nav_link_count: mainSnapshot.nav_link_count || null,
            main_tab_pane_count: mainSnapshot.tab_pane_count || null,
            main_render_key: mainSnapshot.render_key || null,
            main_source_mismatch: mainSourceMismatch,
            main_profile_mismatch: mainProfileMismatch,
            top_output_present: topProbe.present,
            top_visible: topProbe.content_visible,
            top_display: topProbe.computed_display,
            top_visibility: topProbe.computed_visibility,
            top_width: topProbe.width,
            top_height: topProbe.height,
            top_data_source_dom_value: domInputValue('data_source_choice', topOutput),
            top_data_source_input_value: inputValues.data_source_choice || null,
            top_frequency_dom_value: domInputValue('data_frequency', topOutput),
            top_frequency_input_value: inputValues.data_frequency || null,
            top_frequency_values: frequencyValues,
            top_weekly_option_present: topWeeklyPresent,
            top_monthly_option_present: frequencyParts.indexOf('monthly') !== -1,
            top_psd_helper_present: topPsdHelperPresent,
            top_year_type_present: topYearTypePresent,
            top_census_trade_flow_present: topCensusTradeFlowPresent,
            top_hybrid_trade_flow_present: topHybridTradeFlowPresent,
            top_hybrid_mode_present: topHybridModePresent,
            top_shell_mismatch: topShellMismatch,
            sidebar_output_present: sidebarProbe.present,
            sidebar_visible: sidebarProbe.content_visible,
            sidebar_jquery_visible: sidebarProbe.jquery_visible,
            sidebar_display: sidebarProbe.computed_display,
            sidebar_visibility: sidebarProbe.computed_visibility,
            sidebar_opacity: sidebarProbe.computed_opacity,
            sidebar_width: sidebarProbe.width,
            sidebar_height: sidebarProbe.height,
            sidebar_text_length: sidebarProbe.text_length,
            sidebar_child_input_count: sidebarProbe.child_input_count,
            sidebar_visible_child_input_count: sidebarProbe.visible_child_input_count,
            sidebar_hidden_child_input_count: sidebarProbe.hidden_child_input_count,
            sidebar_selectize_count: sidebarProbe.selectize_count,
            sidebar_child_input_ids: sidebarProbe.child_input_ids,
            sidebar_source_profile: sidebarMetadata.source_profile,
            sidebar_source_epoch: sidebarMetadata.source_epoch,
            sidebar_rendered_builder: sidebarMetadata.rendered_builder,
            sidebar_rendered_surface: sidebarMetadata.rendered_surface,
            sidebar_metadata_mismatch: sidebarMetadataMismatch,
            sidebar_blank_or_masked: sidebarBlankOrMasked,
            sidebar_psd_country_present: sidebarPsdCountryPresent,
            sidebar_psd_country_visible: sidebarPsdCountryVisible,
            sidebar_non_psd_cutoff_present: sidebarNonPsdCutoffPresent,
            sidebar_non_psd_cutoff_visible: sidebarNonPsdCutoffVisible,
            sidebar_stale_non_psd: sidebarStaleNonPsd,
            psd_controls_missing: psdControlsMissing,
            psd_map_controls_present: psdMapControlsProbe.present,
            psd_map_controls_visible: psdMapControlsProbe.content_visible,
            psd_map_controls_text_length: psdMapControlsProbe.text_length,
            psd_map_controls_child_input_count: psdMapControlsProbe.child_input_count,
            sidebar_map_market_year_present: inputPresent('map_market_year', sidebarOutput),
            sidebar_map_measure_present: inputPresent('map_measure_mode', sidebarOutput),
            sidebar_map_comparison_present: inputPresent('map_comparison_mode', sidebarOutput),
            sidebar_top_partner_present: inputPresent('map_top5_only', sidebarOutput) || inputPresent('map_top10_only', sidebarOutput) || inputPresent('map_top20_only', sidebarOutput),
            sidebar_shell_mismatch: sidebarShellMismatch,
            metric_output_present: metricProbe.present,
            metric_visible: metricProbe.content_visible,
            unit_output_present: unitProbe.present,
            unit_visible: unitProbe.content_visible,
            bottom_output_present: bottomProbe.present,
            bottom_visible: bottomProbe.content_visible,
            bottom_display: bottomProbe.computed_display,
            bottom_visibility: bottomProbe.computed_visibility,
            bottom_width: bottomProbe.width,
            bottom_height: bottomProbe.height,
            bottom_source_profile: bottomMetadata.source_profile,
            bottom_source_epoch: bottomMetadata.source_epoch,
            bottom_rendered_builder: bottomMetadata.rendered_builder,
            bottom_rendered_surface: bottomMetadata.rendered_surface,
            bottom_metadata_mismatch: bottomMetadataMismatch,
            bottom_psd_view_present: bottomPsdViewPresent,
            bottom_psd_current_present: bottomPsdCurrentPresent,
            bottom_psd_current_visible: bottomPsdCurrentVisible,
            bottom_psd_comparison_present: bottomPsdComparisonPresent,
            bottom_psd_comparison_visible: bottomPsdComparisonVisible,
            bottom_psd_matrix_present: bottomPsdMatrixPresent,
            bottom_psd_matrix_visible: bottomPsdMatrixVisible,
            bottom_non_psd_current_present: bottomNonPsdCurrentPresent,
            bottom_non_psd_current_visible: bottomNonPsdCurrentVisible,
            bottom_non_psd_comparison_present: bottomNonPsdComparisonPresent,
            bottom_non_psd_comparison_visible: bottomNonPsdComparisonVisible,
            bottom_non_psd_summary_present: bottomNonPsdPresent,
            bottom_non_psd_summary_visible: bottomNonPsdVisible,
            bottom_stale_non_psd: bottomStaleNonPsd,
            bottom_shell_mismatch: bottomShellMismatch,
            map_plot_present: mapPlotProbe.present,
            map_plot_visible: mapPlotProbe.content_visible,
            map_plot_width: mapPlotProbe.width,
            map_plot_height: mapPlotProbe.height,
            timeseries_plot_present: timeseriesProbe.present,
            timeseries_visible: timeseriesProbe.content_visible,
            timeseries_width: timeseriesProbe.width,
            timeseries_height: timeseriesProbe.height,
            timeseries_state: timeseriesState,
            timeseries_text_excerpt: sanitizeTraceToken(timeseriesText),
            year_filter_present: yearFilterProbe.present,
            year_filter_visible: yearFilterProbe.content_visible,
            year_filter_option_count: yearFilterInputs.length,
            year_filter_checked_count: yearFilterCheckedInputs.length,
            year_filter_checked_values: yearFilterCheckedValues,
            psd_fragments_present: psdFragmentsPresent,
            non_psd_fragments_present: nonPsdFragmentsPresent,
            source_shell_mismatch: sourceShellMismatch,
            source_shell_mismatch_reason: sourceShellMismatchReason
          };
        }

        function sourceSurfaceRefreshNeeded(snapshot) {
          if (!snapshot || snapshot.server_source !== 'psd') return false;
          var activeTab = snapshot.active_tab || snapshot.main_tabs_panel;
          if (activeTab !== 'Map') return false;
          if (snapshot.main_dom_source !== 'psd' || snapshot.main_dom_profile !== 'psd') return false;

          var topStale = !!snapshot.top_shell_mismatch;
          var sidebarStale = !!snapshot.sidebar_metadata_mismatch ||
            snapshot.sidebar_source_profile === 'non_psd' ||
            snapshot.sidebar_rendered_builder === 'non_psd' ||
            !!snapshot.sidebar_non_psd_cutoff_visible ||
            !!snapshot.psd_controls_missing;
          var bottomStale = !!snapshot.bottom_metadata_mismatch ||
            snapshot.bottom_source_profile === 'non_psd' ||
            snapshot.bottom_rendered_builder === 'non_psd' ||
            !!snapshot.bottom_non_psd_summary_visible;

          return topStale || sidebarStale || bottomStale;
        }

        function maybeRequestSourceSurfaceRefresh(snapshot, now) {
          if (!sourceSurfaceRefreshNeeded(snapshot)) return false;
          if (typeof Shiny === 'undefined' || !Shiny.setInputValue) return false;

          now = now || perfNow();
          var requestKey = [
            snapshot.server_source || '',
            snapshot.active_tab || '',
            snapshot.main_tabs_panel || '',
            snapshot.main_dom_source || '',
            snapshot.main_dom_profile || '',
            snapshot.sidebar_source_epoch || '',
            snapshot.sidebar_rendered_builder || '',
            snapshot.bottom_source_epoch || '',
            snapshot.bottom_rendered_builder || '',
            snapshot.source_shell_mismatch_reason || ''
          ].join('|');
          var requestState = perfState.sourceSurfaceRefreshRequests[requestKey] || { count: 0, last_at: 0 };
          if (requestState.count >= 2) return false;
          if (now - requestState.last_at < 1500) return false;

          requestState.count += 1;
          requestState.last_at = now;
          perfState.sourceSurfaceRefreshRequests[requestKey] = requestState;

          emitClientPerf('client_source_surface_refresh_request', {
            reason: snapshot.reason,
            request_key: requestKey,
            attempt: requestState.count,
            server_source: snapshot.server_source,
            active_tab: snapshot.active_tab,
            main_tabs_panel: snapshot.main_tabs_panel,
            main_dom_source: snapshot.main_dom_source,
            main_dom_profile: snapshot.main_dom_profile,
            top_shell_mismatch: snapshot.top_shell_mismatch,
            sidebar_source_profile: snapshot.sidebar_source_profile,
            sidebar_source_epoch: snapshot.sidebar_source_epoch,
            sidebar_rendered_builder: snapshot.sidebar_rendered_builder,
            sidebar_metadata_mismatch: snapshot.sidebar_metadata_mismatch,
            sidebar_non_psd_cutoff_visible: snapshot.sidebar_non_psd_cutoff_visible,
            bottom_source_profile: snapshot.bottom_source_profile,
            bottom_source_epoch: snapshot.bottom_source_epoch,
            bottom_rendered_builder: snapshot.bottom_rendered_builder,
            bottom_metadata_mismatch: snapshot.bottom_metadata_mismatch,
            bottom_non_psd_summary_visible: snapshot.bottom_non_psd_summary_visible,
            source_shell_mismatch_reason: snapshot.source_shell_mismatch_reason
          });

          return true;
        }

        function emitSourceShellSnapshot(reason, force) {
          var snapshot = sourceShellSnapshot(reason || 'source_shell');
          var now = perfNow();
          maybeRequestSourceSurfaceRefresh(snapshot, now);
          if (!sourceShellTraceEnabled()) return snapshot;
          if (!snapshot.top_output_present && !snapshot.main_nav_link_count && !snapshot.sidebar_output_present) return snapshot;

          if (!force && now - perfState.sourceShellLastSentAt < 750) return snapshot;

          var shellKey = [
            snapshot.reason,
            snapshot.server_source,
            snapshot.main_tabs_panel,
            snapshot.main_dom_source,
            snapshot.main_dom_profile,
            snapshot.main_nav_link_count,
            snapshot.top_data_source_dom_value,
            snapshot.top_frequency_values,
            snapshot.top_frequency_input_value,
            snapshot.top_psd_helper_present,
            snapshot.top_year_type_present,
            snapshot.top_census_trade_flow_present,
            snapshot.top_hybrid_trade_flow_present,
            snapshot.top_hybrid_mode_present,
            snapshot.sidebar_source_profile,
            snapshot.sidebar_source_epoch,
            snapshot.sidebar_rendered_builder,
            snapshot.sidebar_rendered_surface,
            snapshot.sidebar_metadata_mismatch,
            snapshot.sidebar_psd_country_present,
            snapshot.sidebar_psd_country_visible,
            snapshot.sidebar_non_psd_cutoff_present,
            snapshot.sidebar_non_psd_cutoff_visible,
            snapshot.sidebar_stale_non_psd,
            snapshot.psd_controls_missing,
            snapshot.sidebar_visible,
            snapshot.sidebar_blank_or_masked,
            snapshot.bottom_source_profile,
            snapshot.bottom_source_epoch,
            snapshot.bottom_rendered_builder,
            snapshot.bottom_rendered_surface,
            snapshot.bottom_metadata_mismatch,
            snapshot.bottom_psd_view_present,
            snapshot.bottom_psd_current_present,
            snapshot.bottom_psd_current_visible,
            snapshot.bottom_psd_comparison_present,
            snapshot.bottom_psd_comparison_visible,
            snapshot.bottom_non_psd_summary_present,
            snapshot.bottom_non_psd_summary_visible,
            snapshot.bottom_stale_non_psd,
            snapshot.map_plot_visible,
            snapshot.timeseries_visible,
            snapshot.timeseries_state,
            snapshot.year_filter_option_count,
            snapshot.year_filter_checked_count,
            snapshot.year_filter_checked_values,
            snapshot.source_shell_mismatch,
            snapshot.source_shell_mismatch_reason
          ].join('|');

          if (!force && shellKey === perfState.sourceShellLastKey) return snapshot;
          perfState.sourceShellLastKey = shellKey;
          perfState.sourceShellLastSentAt = now;
          emitClientPerf('client_perf_source_shell', snapshot);
          return snapshot;
        }

        function sourceShellAutoEnabled() {
          return sourceShellTraceEnabled();
        }

        function scheduleSourceShellSamples(reason) {
          perfState.sourceShellSampleSeq += 1;
          var sampleSeq = perfState.sourceShellSampleSeq;
          [500, 2000, 6000].forEach(function(delayMs) {
            window.setTimeout(function() {
              if (sampleSeq !== perfState.sourceShellSampleSeq) return;
              emitSourceShellSnapshot((reason || 'auto_source_shell') + '_t' + delayMs, false);
            }, delayMs);
          });
        }

        function emitMainTabsProfileSnapshot(reason) {
          var snapshot = mainTabsProfileSnapshot(reason);
          if (!snapshot) return;

          var profileKey = [
            snapshot.render_key,
            snapshot.server_source,
            snapshot.tab,
            snapshot.nav_link_count,
            snapshot.tab_pane_count,
            snapshot.profile_mismatch,
            snapshot.count_mismatch
          ].join('|');

          if (profileKey === perfState.mainTabsLastProfileKey) return;
          perfState.mainTabsLastProfileKey = profileKey;
          emitClientPerf('client_perf_main_tabs_profile', snapshot);
          emitSourceShellSnapshot(reason || 'main_tabs_profile');
        }

        function emitClientPerf(id, payload) {
          if (typeof Shiny === 'undefined' || !Shiny.setInputValue) return;
          var now = perfNow();
          var actionElapsed = perfState.actionStartedAt === null ? null : Math.round(now - perfState.actionStartedAt);
          Shiny.setInputValue(
            id,
            $.extend(
              {
                ts: Date.now(),
                action_id: perfState.actionId || 0,
                mutation_seq: nextPerfMutationSeq(),
                action_reason: perfState.actionReason || null,
                action_elapsed_ms: actionElapsed
              },
              payload || {}
            ),
            { priority: 'event' }
          );
        }

        function emitBoundaryMarker(boundary, payload) {
          if (!perfBoundaryMarkersEnabled()) return;

          var boundaryName = String(boundary || 'unknown_boundary').trim();
          if (!boundaryName.length) boundaryName = 'unknown_boundary';

          emitClientPerf('client_perf_boundary_marker', $.extend({
            boundary: boundaryName
          }, payload || {}));
        }

        function targetOutputIdForMainTab(tabName) {
          if (tabName === 'Historical Trend') return 'timeseries_plot';
          if (tabName === 'Heatmap') return 'heatmap_plot';
          if (tabName === 'Map') return 'map_plot';
          if (tabName === 'Current vs. Average') return 'comparison_plot';
          return null;
        }

        function countWithin(outputNode, selector) {
          var count = 0;
          if (!outputNode) return count;
          try {
            if (outputNode.matches && outputNode.matches(selector)) count += 1;
          } catch (error) {}
          try {
            count += outputNode.querySelectorAll(selector).length;
          } catch (error) {}
          return count;
        }

        function outputResizeState(outputId) {
          var outputNode = outputId ? document.getElementById(outputId) : null;
          if (!outputNode) {
            return {
              present: false,
              visible: false,
              width: 0,
              height: 0,
              widget_count: 0,
              main_svg_count: 0,
              loading_indicator_count: null
            };
          }
          var rect = outputNode.getBoundingClientRect();
          var style = window.getComputedStyle(outputNode);
          return {
            present: true,
            visible: style.display !== 'none' && style.visibility !== 'hidden' && Number(style.opacity || 1) > 0 && rect.width > 0 && rect.height > 0,
            width: Math.round(rect.width),
            height: Math.round(rect.height),
            widget_count: countWithin(outputNode, '.plotly.html-widget,.html-widget,.dataTables_wrapper,table.dataTable'),
            main_svg_count: countWithin(outputNode, '.main-svg'),
            loading_indicator_count: countWithin(outputNode, '.shiny-output-error,.shiny-output-error-validation,.load-container,.loading,.recalculating') + ($(outputNode).closest('.recalculating').length ? 1 : 0)
          };
        }

        function emitOutputMaterializationBoundary(boundaryName, outputId, extras) {
          if (!perfBoundaryMarkersEnabled()) return;
          if (outputId !== 'comparison_plot') return;

          var phaseName = (extras && extras.phase) ? String(extras.phase) : '';
          var dedupeKey = [String(perfState.actionId || 0), String(boundaryName || ''), String(outputId || ''), phaseName].join('|');
          if (perfState.outputMaterializationMarkerKeys[dedupeKey]) return;
          perfState.outputMaterializationMarkerKeys[dedupeKey] = true;

          var state = outputResizeState(outputId);
          var payload = $.extend({
            target_output_id: outputId,
            tab: currentMainTabValue() || activeTabName() || null,
            target_present: state.present,
            target_visible: state.visible,
            target_width: state.width,
            target_height: state.height,
            target_widget_count: state.widget_count,
            target_main_svg_count: state.main_svg_count,
            target_loading_indicator_count: state.loading_indicator_count
          }, extras || {});

          emitBoundaryMarker(boundaryName, payload);
        }

        beginPerfAction('initial_mount');

        $(document).on('change', '#data_source_choice, #census_trade_flow_choice, #hybrid_trade_flow_choice, #vp_trade_flow_choice, #vp_group_choice, #vp_subgroup_choice, #vp_market_segment_choice, #country_choice, #commodity_choice, #main_tabs_panel', function() {
          var inputId = this && this.id ? this.id : 'unknown_input';
          beginPerfAction('input_change:' + inputId);
        });

        function notesActiveElementSummary() {
          var active = document.activeElement;
          if (!active) return '<none>';

          var parts = [active.tagName ? active.tagName.toLowerCase() : '<unknown>'];
          if (active.id) parts.push('#' + active.id);
          if (active.className && typeof active.className === 'string') {
            parts.push('.' + $.trim(active.className).replace(/\\s+/g, '.'));
          }

          return parts.join('');
        }

        function emitNotesTrace(eventName, payload) {
          if (!notesTraceEnabled()) return;
          if (typeof Shiny === 'undefined' || !Shiny.setInputValue) return;

          Shiny.setInputValue('client_notes_trace', $.extend({
            event: eventName,
            captured_at_iso: new Date().toISOString(),
            nonce: Date.now()
          }, payload || {}), { priority: 'event' });
        }

        function notesSelectizeSnapshot(reason, extraPayload) {
          var panel = $('#floating_notes_panel');
          var selectNode = document.getElementById('floating_notes_country_picker');
          var selectize = selectNode && selectNode.selectize ? selectNode.selectize : null;
          var searchInput = null;
          var controlInput = selectize && selectize.$control_input && selectize.$control_input.length ? selectize.$control_input : null;
          var options = selectize && selectize.options ? selectize.options : {};
          var selectedValues = selectize && Array.isArray(selectize.items) ? selectize.items.slice() : [];
          var selectedLabels = selectedValues.map(function(value) {
            if (options[value] && options[value].text) return String(options[value].text);
            return String(value);
          });

          if (!controlInput && searchInput) {
            controlInput = $(searchInput);
          }

          return $.extend({
            reason: reason || null,
            panel_visible: panel.hasClass('visible'),
            panel_minimized: $('#notes_panel_body').hasClass('minimized'),
            panel_geometry: notesFloatingPanelSnapshot(),
            has_selectize: !!selectize,
            is_open: !!(selectize && selectize.isOpen),
            choice_count: Object.keys(options).length,
            selected_count: selectedValues.length,
            selected_value: selectedValues.length ? String(selectedValues[0]) : '<none>',
            selected_label: selectedLabels.length ? String(selectedLabels[0]) : '<none>',
            control_input_present: !!controlInput,
            control_input_disabled: controlInput ? !!controlInput.prop('disabled') : null,
            control_input_tabindex: controlInput ? String(controlInput.attr('tabindex') || '<none>') : '<none>',
            control_input_value: controlInput ? String(controlInput.val() || '') : '',
            active_element: notesActiveElementSummary()
          }, extraPayload || {});
        }

        function traceNotesState(eventName, reason, extraPayload) {
          if (!notesClientDebugActive()) return;
          emitNotesTrace(eventName, notesSelectizeSnapshot(reason, extraPayload));
        }

        function emitPsdMapCountryProbe(payload) {
          if (!psdProbeEnabled()) return;
          if (typeof Shiny === 'undefined' || !Shiny.setInputValue) return;

          Shiny.setInputValue('client_psd_map_country_probe', $.extend({
            captured_at_iso: new Date().toISOString(),
            nonce: Date.now()
          }, payload || {}), { priority: 'event' });
        }

        function emitPsdMapCountrySyncAck(payload) {
          if (!psdClientDebugActive()) return;
          if (typeof Shiny === 'undefined' || !Shiny.setInputValue) return;

          Shiny.setInputValue('client_psd_map_country_sync_ack', $.extend({
            captured_at_iso: new Date().toISOString(),
            nonce: Date.now()
          }, payload || {}), { priority: 'event' });
        }

        function emitSidebarCountryProbe(payload) {
          if (!psdProbeEnabled()) return;
          if (typeof Shiny === 'undefined' || !Shiny.setInputValue) return;

          Shiny.setInputValue('client_sidebar_country_probe', $.extend({
            captured_at_iso: new Date().toISOString(),
            nonce: Date.now()
          }, payload || {}), { priority: 'event' });
        }

        function emitSidebarCountrySyncAck(payload) {
          if (!psdClientDebugActive()) return;
          if (typeof Shiny === 'undefined' || !Shiny.setInputValue) return;

          Shiny.setInputValue('client_sidebar_country_sync_ack', $.extend({
            captured_at_iso: new Date().toISOString(),
            nonce: Date.now()
          }, payload || {}), { priority: 'event' });
        }

        function psdMapCountrySelectizeSnapshot(reason, extraPayload) {
          var selectize = getPsdMapCountryChoiceSelectize();
          var controlInput = selectize && selectize.$control_input && selectize.$control_input.length ? selectize.$control_input : null;
          var options = selectize && selectize.options ? selectize.options : {};
          var selectedValues = selectize && Array.isArray(selectize.items) ? selectize.items.slice() : [];
          var selectedLabels = selectedValues.map(function(value) {
            if (options[value] && options[value].text) return String(options[value].text);
            return String(value);
          });

          return $.extend({
            reason: reason || null,
            panel_visible: $('#floating_notes_panel').hasClass('visible'),
            panel_minimized: $('#notes_panel_body').hasClass('minimized'),
            panel_geometry: notesFloatingPanelSnapshot(),
            has_selectize: !!selectize,
            is_open: !!(selectize && selectize.isOpen),
            choice_count: Object.keys(options).length,
            selected_count: selectedValues.length,
            selected_value: selectedValues.length ? String(selectedValues[0]) : '<none>',
            selected_label: selectedLabels.length ? String(selectedLabels[0]) : '<none>',
            control_input_present: !!controlInput,
            control_input_disabled: controlInput ? !!controlInput.prop('disabled') : null,
            control_input_tabindex: controlInput ? String(controlInput.attr('tabindex') || '<none>') : '<none>',
            control_input_value: controlInput ? String(controlInput.val() || '') : '',
            active_element: notesActiveElementSummary()
          }, extraPayload || {});
        }

        function tracePsdMapCountryState(reason, extraPayload) {
          emitPsdMapCountryProbe(psdMapCountrySelectizeSnapshot(reason, extraPayload));
        }

        function sidebarCountrySelectizeSnapshot(reason, extraPayload) {
          var selectize = getSidebarCountrySelectize();
          var controlInput = selectize && selectize.$control_input && selectize.$control_input.length ? selectize.$control_input : null;
          var options = selectize && selectize.options ? selectize.options : {};
          var selectedValues = selectize && Array.isArray(selectize.items) ? selectize.items.slice() : [];
          var selectedLabels = selectedValues.map(function(value) {
            if (options[value] && options[value].text) return String(options[value].text);
            return String(value);
          });

          return $.extend({
            reason: reason || null,
            panel_visible: $('#floating_notes_panel').hasClass('visible'),
            panel_minimized: $('#notes_panel_body').hasClass('minimized'),
            panel_geometry: notesFloatingPanelSnapshot(),
            has_selectize: !!selectize,
            is_open: !!(selectize && selectize.isOpen),
            choice_count: Object.keys(options).length,
            selected_count: selectedValues.length,
            selected_value: selectedValues.length ? String(selectedValues[0]) : '<none>',
            selected_label: selectedLabels.length ? String(selectedLabels[0]) : '<none>',
            control_input_present: !!controlInput,
            control_input_disabled: controlInput ? !!controlInput.prop('disabled') : null,
            control_input_tabindex: controlInput ? String(controlInput.attr('tabindex') || '<none>') : '<none>',
            control_input_value: controlInput ? String(controlInput.val() || '') : '',
            active_element: notesActiveElementSummary()
          }, extraPayload || {});
        }

        function traceSidebarCountryState(reason, extraPayload) {
          emitSidebarCountryProbe(sidebarCountrySelectizeSnapshot(reason, extraPayload));
        }

        function showDebugCaptureToast(message) {
          if (!manualCaptureEnabled()) return;
          var toast = document.getElementById('debug_capture_toast');
          if (!toast) {
            toast = document.createElement('div');
            toast.id = 'debug_capture_toast';
            toast.style.position = 'fixed';
            toast.style.right = '16px';
            toast.style.bottom = '16px';
            toast.style.zIndex = '100000';
            toast.style.background = 'rgba(37, 52, 72, 0.96)';
            toast.style.color = '#ffffff';
            toast.style.padding = '10px 14px';
            toast.style.borderRadius = '8px';
            toast.style.boxShadow = '0 6px 18px rgba(0, 0, 0, 0.24)';
            toast.style.fontSize = '13px';
            toast.style.fontWeight = '600';
            toast.style.opacity = '0';
            toast.style.transition = 'opacity 120ms ease-in-out';
            toast.style.pointerEvents = 'none';
            document.body.appendChild(toast);
          }

          toast.textContent = message || 'Debug snapshot captured';
          toast.style.opacity = '1';

          if (toast.__hideTimer) {
            window.clearTimeout(toast.__hideTimer);
          }

          toast.__hideTimer = window.setTimeout(function() {
            toast.style.opacity = '0';
          }, 1400);
        }

        function ensureDebugCaptureButton() {
          if (!manualCaptureEnabled()) {
            $('#debug_capture_button, #debug_capture_toast').remove();
            return null;
          }

          var button = document.getElementById('debug_capture_button');
          if (!button) {
            button = document.createElement('button');
            button.id = 'debug_capture_button';
            button.type = 'button';
            button.textContent = 'Capture Debug Snapshot';
            button.style.position = 'fixed';
            button.style.right = '16px';
            button.style.bottom = '56px';
            button.style.zIndex = '99999';
            button.style.border = '0';
            button.style.borderRadius = '999px';
            button.style.padding = '10px 14px';
            button.style.background = '#1f6f5f';
            button.style.color = '#ffffff';
            button.style.boxShadow = '0 8px 24px rgba(0, 0, 0, 0.22)';
            button.style.fontSize = '13px';
            button.style.fontWeight = '700';
            button.style.cursor = 'pointer';
            button.style.opacity = '0.92';
            button.style.transition = 'opacity 120ms ease-in-out';
            button.addEventListener('mouseenter', function() {
              button.style.opacity = '1';
            });
            button.addEventListener('mouseleave', function() {
              button.style.opacity = '0.92';
            });
            button.addEventListener('click', function() {
              emitManualDebugCapture('manual_button', {
                trigger: 'button'
              });
            });
            document.body.appendChild(button);
          }

          return button;
        }

        function emitManualDebugCapture(reason, extraPayload) {
          if (!manualCaptureEnabled()) return;
          if (typeof Shiny === 'undefined' || !Shiny.setInputValue) return;

          var inputValues = (window.Shiny && window.Shiny.shinyapp && window.Shiny.shinyapp.$inputValues) || {};
          Shiny.setInputValue('client_manual_debug_capture', $.extend({
            reason: reason || 'manual_capture',
            captured_at_iso: new Date().toISOString(),
            nonce: Date.now(),
            active_tab: activeTabName(),
            main_tabs_panel: currentMainTabValue(),
            data_source_choice: inputValues.data_source_choice || null,
            sidebar_country: inputValues.country_choice || null,
            notes_hidden_country: inputValues.floating_notes_country || null,
            notes_picker_country: inputValues.floating_notes_country_picker || null,
            psd_map_bottom_view: inputValues.psd_map_bottom_view || null,
            psd_map_country_choice: inputValues.psd_map_country_choice || null,
            notes_snapshot: notesSelectizeSnapshot(reason || 'manual_capture'),
            psd_snapshot: psdMapCountrySelectizeSnapshot(reason || 'manual_capture'),
            sidebar_snapshot: sidebarCountrySelectizeSnapshot(reason || 'manual_capture'),
            source_shell_snapshot: sourceShellSnapshot(reason || 'manual_capture')
          }, extraPayload || {}), { priority: 'event' });

          showDebugCaptureToast('Debug snapshot captured');
        }

        window.captureRiceDebugSnapshot = function(reason, extraPayload) {
          emitManualDebugCapture(reason || 'manual_capture', extraPayload || {});
        };

        if (manualCaptureEnabled()) {
          ensureDebugCaptureButton();
        }

        function logMainTabsMountIfReady() {
          var inputEl = mainTabsInput();
          var container = mainTabsContainer();
          var navLinks = container.find('> .nav > li > a, > .nav-tabs > li > a');
          var tabPanes = container.find('> .tab-content > .tab-pane');
          var activePane = tabPanes.filter('.active').first();
          var activePaneWidgets = activePane.find('.plotly.html-widget');

          if (!inputEl.length) return;
          if (!navLinks.length) return;

          emitMainTabsProfileSnapshot(perfState.mainTabsMountLogged ? 'mutation' : 'initial_mount');
          if (perfState.mainTabsMountLogged) return;

          perfState.mainTabsMountLogged = true;
          emitClientPerf('client_perf_main_tabs_mount', {
            tab: activeTabName(),
            elapsed_ms: Math.round(perfNow() - perfState.pageLoadStartedAt),
            nav_link_count: navLinks.length,
            tab_pane_count: tabPanes.length,
            active_plotly_count: activePaneWidgets.length,
            dom_node_count: container.find('*').length
          });

          window.requestAnimationFrame(function() {
            window.requestAnimationFrame(function() {
              var refreshedActivePane = container.find('> .tab-content > .tab-pane.active').first();
              var visibleWidgets = refreshedActivePane.find('.plotly.html-widget').filter(function() {
                var widget = $(this);
                return widget.is(':visible') && widget.width() > 0 && widget.height() > 0;
              });

              emitClientPerf('client_perf_tab_after_paint', {
                tab: activeTabName(),
                elapsed_ms: Math.round(perfNow() - perfState.pageLoadStartedAt),
                phase: 'initial_mount',
                visible_plotly_count: visibleWidgets.length,
                dom_node_count: container.find('*').length
              });
            });
          });
        }

        var mainTabsObserver = new MutationObserver(function() {
          if (perfState.mainTabsProfileProbeScheduled) return;
          perfState.mainTabsProfileProbeScheduled = true;
          window.requestAnimationFrame(function() {
            perfState.mainTabsProfileProbeScheduled = false;
            logMainTabsMountIfReady();
            if (sourceShellAutoEnabled()) emitSourceShellSnapshot('mutation');
          });
        });

        if (document.body) {
          mainTabsObserver.observe(document.body, { childList: true, subtree: true });
        }

        logMainTabsMountIfReady();
  emitSourceShellSnapshot('initial_mount');

        $(document).on('change', '#data_source_choice', function() {
          window.requestAnimationFrame(function() {
            emitSourceShellSnapshot('data_source_change', true);
            scheduleSourceShellSamples('auto_source_change');
          });
        });

        $(document).on('shown.bs.tab', function(e) {
          if (!isMainTabsAnchor(e.target)) return;
          window.requestAnimationFrame(function() {
            emitSourceShellSnapshot('auto_tab_shown', true);
            scheduleSourceShellSamples('auto_tab_shown');
          });
        });

        $(document).on('shiny:value', function(event) {
          if (!sourceShellAutoEnabled()) return;
          var outputName = event && (event.name || (event.target && event.target.id)) ? String(event.name || event.target.id) : '';
          if (['market_year_compare_filters_ui', 'psd_map_controls_ui', 'map_bottom_panel_ui'].indexOf(outputName) < 0) return;
          window.requestAnimationFrame(function() {
            emitSourceShellSnapshot('auto_shiny_value_' + sanitizeTraceToken(outputName), false);
            scheduleSourceShellSamples('auto_shiny_value_' + sanitizeTraceToken(outputName));
          });
        });

        $(document).on('shiny:value', function(event) {
          if (!perfBoundaryMarkersEnabled()) return;

          var outputName = event && (event.name || (event.target && event.target.id)) ? String(event.name || event.target.id) : '';
          if (!outputName.length) return;
          if (outputName !== 'comparison_plot') return;

          window.requestAnimationFrame(function() {
            emitOutputMaterializationBoundary('output_client_value_received', outputName, {
              phase: 'shiny_value_output'
            });

            var state = outputResizeState(outputName);
            if ((state.widget_count || 0) > 0) {
              emitOutputMaterializationBoundary('output_widget_inserted', outputName, {
                phase: 'widget_present_after_shiny_value'
              });
            }
            if ((state.main_svg_count || 0) > 0) {
              emitOutputMaterializationBoundary('output_main_svg_inserted', outputName, {
                phase: 'main_svg_present_after_shiny_value'
              });
            }
            if ((state.loading_indicator_count || 0) === 0) {
              emitOutputMaterializationBoundary('output_loading_cleared', outputName, {
                phase: 'loading_cleared_after_shiny_value'
              });
            }
          });
        });

        $(document).on('plotly_afterplot', function(event) {
          if (!perfBoundaryMarkersEnabled()) return;

          var targetId = event && event.target && event.target.id ? String(event.target.id) : '';
          var closestOutputId = targetId;
          if (!closestOutputId) {
            try {
              var closest = event && event.target && event.target.closest ? event.target.closest('.shiny-bound-output') : null;
              closestOutputId = closest && closest.id ? String(closest.id) : '';
            } catch (error) {
              closestOutputId = '';
            }
          }
          if (closestOutputId !== 'comparison_plot') return;

          emitOutputMaterializationBoundary('output_plotly_afterplot', closestOutputId, {
            phase: 'plotly_afterplot'
          });

          var state = outputResizeState(closestOutputId);
          if ((state.loading_indicator_count || 0) === 0) {
            emitOutputMaterializationBoundary('output_loading_cleared', closestOutputId, {
              phase: 'loading_cleared_after_afterplot'
            });
          }
          if (state.present && state.visible && ((state.widget_count || 0) > 0 || (state.main_svg_count || 0) > 0) && (state.loading_indicator_count || 0) === 0) {
            emitOutputMaterializationBoundary('output_useful_ready', closestOutputId, {
              phase: 'plotly_afterplot_and_loading_cleared',
              useful_ready_rule: 'plotly_afterplot_and_loading_cleared'
            });
          }
        });

        function getNotesCountrySelectize() {
          var selectNode = document.getElementById('floating_notes_country_picker');
          return selectNode && selectNode.selectize ? selectNode.selectize : null;
        }

        function getNotesCountrySearchInput() {
          var selectize = getNotesCountrySelectize();
          if (selectize && selectize.$control_input && selectize.$control_input.length) {
            return selectize.$control_input;
          }
          return null;
        }

        function isNotesPrintableKey(e) {
          if (!e || e.ctrlKey || e.metaKey || e.altKey) return false;
          return typeof e.key === 'string' && e.key.length === 1;
        }

        function prepareNotesCountrySelectizeForTyping(selectize, reason) {
          if (!selectize) return false;

          if (typeof selectize.unlock === 'function') {
            selectize.unlock();
          }

          if (selectize.$control && selectize.$control.length) {
            selectize.$control.removeClass('locked disabled');
          }

          if (selectize.$control_input && selectize.$control_input.length) {
            selectize.$control_input.prop('disabled', false);
            selectize.$control_input.prop('readonly', false);
            selectize.$control_input.removeAttr('readonly');
            if (!selectize.$control_input.attr('tabindex')) {
              selectize.$control_input.attr('tabindex', '0');
            }
          }

          traceNotesState('typing_unlock', reason || 'typing_unlock', {
            control_input_readonly: !!(selectize.$control_input && selectize.$control_input.prop('readonly')),
            control_input_disabled: !!(selectize.$control_input && selectize.$control_input.prop('disabled'))
          });

          return true;
        }

        function applyNotesManualQueryFallback(selectize, key) {
          if (!selectize || !selectize.$control_input || !selectize.$control_input.length) {
            return false;
          }

          var currentValue = String(selectize.$control_input.val() || selectize.lastValue || '');
          var nextValue = currentValue;

          if (isNotesPrintableKey({ key: key, ctrlKey: false, metaKey: false, altKey: false })) {
            nextValue = currentValue + key;
          } else if (key === 'Backspace') {
            nextValue = currentValue.slice(0, Math.max(0, currentValue.length - 1));
          } else if (key === 'Delete') {
            nextValue = '';
          } else {
            return false;
          }

          prepareNotesCountrySelectizeForTyping(selectize, 'manual_query_fallback');

          if (typeof selectize.setTextboxValue === 'function') {
            selectize.setTextboxValue(nextValue);
          } else {
            selectize.$control_input.val(nextValue);
          }

          if (typeof selectize.open === 'function' && !selectize.isOpen) {
            selectize.open();
          }

          if (typeof selectize.onSearchChange === 'function') {
            selectize.onSearchChange(nextValue);
          }
          if (typeof selectize.refreshOptions === 'function') {
            selectize.refreshOptions(true);
          }

          traceNotesState('manual_query_applied', 'manual_query_fallback', {
            key: key,
            control_input_value_after: nextValue
          });

          return true;
        }

        function attachNotesCountrySelectizeTracing() {
          var selectize = getNotesCountrySelectize();
          var searchInput = getNotesCountrySearchInput();

          if (!selectize || !selectize.$control || !selectize.$control.length) return !!searchInput;
          if (selectize.$control.attr('data-notes-trace-bound') === 'true') return true;

          selectize.$control.attr('data-notes-trace-bound', 'true');
          selectize.__notesLastNativeInputAt = 0;
          selectize.__notesFallbackNonce = 0;
          if (notesClientDebugActive()) {
            selectize.$control.off('.notesTrace');
            selectize.$control.on('mousedown.notesTrace', function() {
              traceNotesState('control_mousedown', 'control_mousedown');
            });
            selectize.$control.on('click.notesTrace', function() {
              traceNotesState('control_click', 'control_click');
            });
          }

          if (typeof selectize.on === 'function') {
            selectize.on('dropdown_open', function() {
              prepareNotesCountrySelectizeForTyping(selectize, 'dropdown_open');
            });
            selectize.on('focus', function() {
              prepareNotesCountrySelectizeForTyping(selectize, 'selectize_focus');
            });
            selectize.on('item_add', function() {
              if (typeof selectize.setTextboxValue === 'function') {
                selectize.setTextboxValue('');
              }
            });
          }

          if (selectize.$control_input && selectize.$control_input.length) {
            selectize.$control_input.off('.notesTrace');
            selectize.$control_input.on('focus.notesTrace', function() {
              prepareNotesCountrySelectizeForTyping(selectize, 'input_focus');
              traceNotesState('input_focus', 'dom_focus');
            });
            selectize.$control_input.on('blur.notesTrace', function() {
              traceNotesState('input_blur', 'dom_blur');
            });
            selectize.$control_input.on('keydown.notesTrace', function(e) {
              prepareNotesCountrySelectizeForTyping(selectize, 'keydown');
              traceNotesState('input_keydown', 'dom_keydown', {
                key: e.key || null,
                which: e.which || null,
                control_input_value_before: String($(this).val() || '')
              });

              if (!isNotesPrintableKey(e) && e.key !== 'Backspace' && e.key !== 'Delete') {
                return;
              }

              var beforeValue = String($(this).val() || '');
              var fallbackNonce = (selectize.__notesFallbackNonce || 0) + 1;
              selectize.__notesFallbackNonce = fallbackNonce;

              window.setTimeout(function() {
                if (!selectize || selectize.__notesFallbackNonce !== fallbackNonce) return;

                var currentValue = String((selectize.$control_input && selectize.$control_input.val()) || '');
                var nativeInputAt = Number(selectize.__notesLastNativeInputAt || 0);
                if (nativeInputAt >= fallbackNonce || currentValue !== beforeValue) {
                  return;
                }

                applyNotesManualQueryFallback(selectize, e.key || '');
              }, 0);
            });
            selectize.$control_input.on('input.notesTrace', function() {
              selectize.__notesLastNativeInputAt = Number(selectize.__notesFallbackNonce || 0);
              traceNotesState('input_value_changed', 'dom_input', {
                control_input_value_after: String($(this).val() || '')
              });
            });
            selectize.$control_input.on('compositionstart.notesTrace', function() {
              traceNotesState('input_composition_start', 'composition_start');
            });
            selectize.$control_input.on('compositionend.notesTrace', function() {
              traceNotesState('input_composition_end', 'composition_end', {
                control_input_value_after: String($(this).val() || '')
              });
            });
          }

          prepareNotesCountrySelectizeForTyping(selectize, 'bind');
          traceNotesState('selectize_bound', 'bind');
          return true;
        }

        function activateNotesCountrySelectize(openDropdown) {
          var selectize = getNotesCountrySelectize();
          var searchInput = getNotesCountrySearchInput();
          if (!selectize && (!searchInput || !searchInput.length)) {
            emitNotesTrace('activation_skipped', {
              reason: 'missing_notes_country_input',
              panel_visible: $('#floating_notes_panel').hasClass('visible'),
              active_element: notesActiveElementSummary()
            });
            return false;
          }
          if (!$('#floating_notes_panel').hasClass('visible')) {
            emitNotesTrace('activation_skipped', {
              reason: 'panel_hidden',
              has_selectize: !!selectize,
              active_element: notesActiveElementSummary()
            });
            return false;
          }

          attachNotesCountrySelectizeTracing();
          prepareNotesCountrySelectizeForTyping(selectize, openDropdown ? 'activate_open' : 'activate_focus');
          traceNotesState('activation_attempt', openDropdown ? 'activate_open' : 'activate_focus');

          if (!selectize && searchInput && searchInput.length) {
            if (document.activeElement !== searchInput.get(0)) {
              searchInput.focus();
              searchInput.get(0).select();
            }
            traceNotesState('activation_result', openDropdown ? 'activate_open' : 'activate_focus');
            return true;
          }

          if (selectize.$control_input && selectize.$control_input.length) {
            if (document.activeElement !== selectize.$control_input.get(0)) {
              selectize.focus();
            }
          } else if (selectize.$control && selectize.$control.length && document.activeElement !== selectize.$control.get(0)) {
            selectize.focus();
          }

          if (openDropdown && !selectize.isOpen) {
            selectize.open();
          }

          if (selectize.isOpen) {
            selectize.positionDropdown();
          }

          traceNotesState('activation_result', openDropdown ? 'activate_open' : 'activate_focus');

          return true;
        }

        var notesActivationTimer = null;

        function scheduleNotesCountrySelectizeActivation(openDropdown) {
          if (notesActivationTimer !== null) {
            window.clearTimeout(notesActivationTimer);
            notesActivationTimer = null;
          }

          notesActivationTimer = window.setTimeout(function() {
            notesActivationTimer = null;
            activateNotesCountrySelectize(openDropdown);
          }, 0);
        }

        window.notesTraceClosePanel = function() {
          traceNotesState('close_click', 'close_button');
          if (window.Shiny && Shiny.setInputValue) {
            Shiny.setInputValue('floating_notes_close_event', Date.now(), { priority: 'event' });
          }
          $('#floating_notes_panel').removeClass('visible');
        };

        var notesCountryObserver = null;

        if (notesClientDebugActive()) {
          notesCountryObserver = new MutationObserver(function() {
            attachNotesCountrySelectizeTracing();
          });

          if (document.body) {
            notesCountryObserver.observe(document.body, { childList: true, subtree: true });
          }
        }

        function getCountryChoiceSelectize() {
          var selectNode = document.getElementById('country_choice');
          return selectNode && selectNode.selectize ? selectNode.selectize : null;
        }

        function isCountryChoicePrintableKey(e) {
          if (!e || e.ctrlKey || e.metaKey || e.altKey) return false;
          return typeof e.key === 'string' && e.key.length === 1;
        }

        function prepareCountryChoiceSelectizeForTyping(selectize) {
          if (!selectize) return false;

          if (typeof selectize.unlock === 'function') {
            selectize.unlock();
          }

          if (selectize.$control && selectize.$control.length) {
            selectize.$control.removeClass('locked disabled');
          }

          if (selectize.$control_input && selectize.$control_input.length) {
            selectize.$control_input.prop('disabled', false);
            selectize.$control_input.prop('readonly', false);
            selectize.$control_input.removeAttr('readonly');
            if (!selectize.$control_input.attr('tabindex')) {
              selectize.$control_input.attr('tabindex', '0');
            }
          }

          return true;
        }

        function getSelectizeActiveOptionValue(selectize) {
          if (!selectize || !selectize.$activeOption || !selectize.$activeOption.length) {
            return null;
          }

          var activeValue = selectize.$activeOption.attr('data-value');
          if (typeof activeValue !== 'string' || !activeValue.length) {
            return null;
          }

          return activeValue;
        }

        function moveFocusToNextTabStop(activeElement) {
          var currentElement = activeElement || document.activeElement;
          if (!currentElement || !document.body) return false;

          var tabbables = Array.prototype.filter.call(
            document.querySelectorAll('a[href], area[href], input:not([disabled]), select:not([disabled]), textarea:not([disabled]), button:not([disabled]), iframe, object, embed, [tabindex], [contenteditable=\"true\"]'),
            function(node) {
              if (!node) return false;
              if (node.tabIndex < 0) return false;
              if (!node.getClientRects || node.getClientRects().length === 0) return false;
              if (node.getAttribute('aria-hidden') === 'true') return false;
              return true;
            }
          );

          if (tabbables.length === 0) return false;

          var currentIndex = tabbables.indexOf(currentElement);
          if (currentIndex < 0) {
            var currentContainer = currentElement.closest ? currentElement.closest('.selectize-control') : null;
            if (currentContainer) {
              currentIndex = tabbables.indexOf(currentContainer);
            }
          }

          if (currentIndex < 0 || currentIndex >= tabbables.length - 1) {
            return false;
          }

          var nextTarget = tabbables[currentIndex + 1];
          if (!nextTarget || typeof nextTarget.focus !== 'function') {
            return false;
          }

          nextTarget.focus();
          return true;
        }

        function commitHighlightedSelectizeOptionOnTab(selectize, eventTarget) {
          if (!selectize) return false;

          var activeValue = getSelectizeActiveOptionValue(selectize);
          if (!activeValue) {
            return false;
          }

          if (typeof selectize.setValue === 'function') {
            selectize.setValue(activeValue);
          }
          if (typeof selectize.close === 'function') {
            selectize.close();
          }

          window.setTimeout(function() {
            moveFocusToNextTabStop(eventTarget || (selectize.$control_input && selectize.$control_input.length ? selectize.$control_input.get(0) : null));
          }, 0);

          return true;
        }

        function applyCountryChoiceManualQueryFallback(selectize, key) {
          if (!selectize || !selectize.$control_input || !selectize.$control_input.length) {
            return false;
          }

          var currentValue = String(selectize.$control_input.val() || selectize.lastValue || '');
          var nextValue = currentValue;

          if (isCountryChoicePrintableKey({ key: key, ctrlKey: false, metaKey: false, altKey: false })) {
            nextValue = currentValue + key;
          } else if (key === 'Backspace') {
            nextValue = currentValue.slice(0, Math.max(0, currentValue.length - 1));
          } else if (key === 'Delete') {
            nextValue = '';
          } else {
            return false;
          }

          prepareCountryChoiceSelectizeForTyping(selectize);

          if (typeof selectize.setTextboxValue === 'function') {
            selectize.setTextboxValue(nextValue);
          } else {
            selectize.$control_input.val(nextValue);
          }

          if (typeof selectize.open === 'function' && !selectize.isOpen) {
            selectize.open();
          }

          if (typeof selectize.onSearchChange === 'function') {
            selectize.onSearchChange(nextValue);
          }
          if (typeof selectize.refreshOptions === 'function') {
            selectize.refreshOptions(true);
          }

          return true;
        }

        function attachCountryChoiceSelectizeTyping() {
          var selectize = getCountryChoiceSelectize();
          if (!selectize || !selectize.$control || !selectize.$control.length) return false;
          if (selectize.$control.attr('data-country-choice-bound') === 'true') return true;

          selectize.$control.attr('data-country-choice-bound', 'true');
          selectize.__countryChoiceLastNativeInputAt = 0;
          selectize.__countryChoiceFallbackNonce = 0;

          selectize.$control.off('.countryChoiceType');
          selectize.$control.on('mousedown.countryChoiceType click.countryChoiceType', function(e) {
            prepareCountryChoiceSelectizeForTyping(selectize);
            traceSidebarCountryState('country_choice_' + e.type, {
              client_step: e.type,
              dom_event_type: e.type,
              event_target: e.target && e.target.tagName ? e.target.tagName.toLowerCase() : '<unknown>'
            });
            if (selectize.$control_input && selectize.$control_input.length && document.activeElement !== selectize.$control_input.get(0)) {
              selectize.focus();
            }
          });

          if (typeof selectize.on === 'function') {
            selectize.on('dropdown_open', function() {
              prepareCountryChoiceSelectizeForTyping(selectize);
              traceSidebarCountryState('country_choice_dropdown_open', { client_step: 'dropdown_open' });
            });
            selectize.on('focus', function() {
              prepareCountryChoiceSelectizeForTyping(selectize);
              traceSidebarCountryState('country_choice_focus', { client_step: 'focus' });
            });
            selectize.on('blur', function() {
              traceSidebarCountryState('country_choice_blur', { client_step: 'blur' });
            });
            selectize.on('change', function(value) {
              traceSidebarCountryState('country_choice_change', {
                client_step: 'change',
                changed_value: String(value || '')
              });
            });
            selectize.on('item_add', function() {
              traceSidebarCountryState('country_choice_item_add', { client_step: 'item_add' });
              if (typeof selectize.setTextboxValue === 'function') {
                selectize.setTextboxValue('');
              }
            });
          }

          if (selectize.$control_input && selectize.$control_input.length) {
            selectize.$control_input.off('.countryChoiceType');
            selectize.$control_input.on('focus.countryChoiceType', function() {
              prepareCountryChoiceSelectizeForTyping(selectize);
            });
            selectize.$control_input.on('keydown.countryChoiceType', function(e) {
              prepareCountryChoiceSelectizeForTyping(selectize);

              if (e.key === 'Tab') {
                if (commitHighlightedSelectizeOptionOnTab(selectize, this)) {
                  e.preventDefault();
                }
                return;
              }

              if (e.key === 'Backspace' || e.key === 'Delete') {
                e.preventDefault();
                applyCountryChoiceManualQueryFallback(selectize, e.key || '');
                return;
              }

              if (!isCountryChoicePrintableKey(e)) {
                return;
              }

              var beforeValue = String($(this).val() || '');
              var fallbackNonce = (selectize.__countryChoiceFallbackNonce || 0) + 1;
              selectize.__countryChoiceFallbackNonce = fallbackNonce;

              window.setTimeout(function() {
                if (!selectize || selectize.__countryChoiceFallbackNonce !== fallbackNonce) return;

                var currentValue = String((selectize.$control_input && selectize.$control_input.val()) || '');
                var nativeInputAt = Number(selectize.__countryChoiceLastNativeInputAt || 0);
                if (nativeInputAt >= fallbackNonce || currentValue !== beforeValue) {
                  return;
                }

                applyCountryChoiceManualQueryFallback(selectize, e.key || '');
              }, 0);
            });
            selectize.$control_input.on('input.countryChoiceType', function() {
              selectize.__countryChoiceLastNativeInputAt = Number(selectize.__countryChoiceFallbackNonce || 0);
            });
          }

          prepareCountryChoiceSelectizeForTyping(selectize);
          applyPendingSidebarCountrySync(selectize);
          return true;
        }

        var countryChoiceObserver = new MutationObserver(function() {
          attachCountryChoiceSelectizeTyping();
        });

        if (document.body) {
          countryChoiceObserver.observe(document.body, { childList: true, subtree: true });
        }

        attachCountryChoiceSelectizeTyping();

        function getPsdMapCountryChoiceSelectize() {
          var selectNode = document.getElementById('psd_map_country_choice');
          return selectNode && selectNode.selectize ? selectNode.selectize : null;
        }

        function getSidebarCountrySelectize() {
          var selectNode = document.getElementById('country_choice');
          return selectNode && selectNode.selectize ? selectNode.selectize : null;
        }

        var pendingSidebarCountrySync = null;

        function rememberPendingSidebarCountrySync(nextValue, traceMeta) {
          if (typeof nextValue !== 'string' || !nextValue.length) {
            return;
          }

          pendingSidebarCountrySync = {
            value: String(nextValue || ''),
            trace: traceMeta && typeof traceMeta === 'object' ? traceMeta : {}
          };
        }

        function clearPendingSidebarCountrySyncIfMatched(currentValue) {
          if (!pendingSidebarCountrySync) {
            return;
          }

          if (String(currentValue || '') === String(pendingSidebarCountrySync.value || '')) {
            pendingSidebarCountrySync = null;
          }
        }

        function applyPendingSidebarCountrySync(selectize) {
          if (!selectize || !pendingSidebarCountrySync) {
            return false;
          }

          var nextValue = String(pendingSidebarCountrySync.value || '');
          if (!nextValue.length) {
            return false;
          }

          var beforeValue = String(selectize.getValue() || '');
          if (beforeValue !== nextValue) {
            selectize.setValue(nextValue);
          }

          var afterValue = String(selectize.getValue() || '');
          emitSidebarCountrySyncAck($.extend({
            input_id: 'country_choice',
            stage: 'bind_pending_apply',
            requested_value: nextValue,
            before_value: beforeValue,
            after_value: afterValue,
            matched_requested_value: afterValue === nextValue,
            has_selectize: true
          }, pendingSidebarCountrySync.trace || {}));

          clearPendingSidebarCountrySyncIfMatched(afterValue);
          return afterValue === nextValue;
        }

        function setSelectizeOrShinyInputValue(inputId, nextValue, traceMeta) {
          var trace = traceMeta && typeof traceMeta === 'object' ? traceMeta : {};
          var requestedValue = nextValue == null ? '' : String(nextValue);
          var retryUntilMatch = !!trace.retry_until_match;
          var retryDelays = Array.isArray(trace.retry_delays_ms) ? trace.retry_delays_ms : [];
          var requestId = trace.request_id || null;
          var requestPhase = trace.request_phase || trace.phase || null;
          var requestTargetCountry = trace.request_target_country || trace.target_country || requestedValue;

          if (inputId === 'country_choice') {
            rememberPendingSidebarCountrySync(requestedValue, trace);
          }

          function tracePsdMapSyncClientStep(clientStep, domValueBefore, domValueAfter, controlPresent, hasSelectize, matchedRequestedValue) {
            if (inputId !== 'psd_map_country_choice') {
              return;
            }

            tracePsdMapCountryState(trace.reason || 'sync_psd_map_country_input', {
              client_step: clientStep,
              request_id: requestId,
              request_phase: requestPhase,
              request_target_country: requestTargetCountry,
              source_switch_epoch_id: trace.source_switch_epoch_id || null,
              source_switch_trigger: trace.source_switch_trigger || null,
              source_switch_from: trace.source_switch_from || null,
              source_switch_to: trace.source_switch_to || null,
              input_id: inputId,
              dom_value_before: domValueBefore == null ? null : String(domValueBefore),
              dom_value_after: domValueAfter == null ? null : String(domValueAfter),
              control_present: !!controlPresent,
              has_selectize: !!hasSelectize,
              matched_requested_value: matchedRequestedValue
            });
          }

          function scheduleSidebarRetrySync() {
            if (inputId !== 'country_choice' || !retryUntilMatch || retryDelays.length === 0) {
              return;
            }

            retryDelays.forEach(function(delayMsRaw) {
              var delayMs = Number(delayMsRaw);
              if (!Number.isFinite(delayMs) || delayMs < 0) {
                return;
              }

              window.setTimeout(function() {
                var currentNode = document.getElementById(inputId);
                var currentSelectize = currentNode && currentNode.selectize ? currentNode.selectize : null;
                var beforeRetryValue = currentSelectize ? String(currentSelectize.getValue() || '') : '';

                if (currentSelectize) {
                  if (beforeRetryValue !== requestedValue) {
                    currentSelectize.setValue(requestedValue);
                  }

                  var afterRetryValue = String(currentSelectize.getValue() || '');
                  emitSidebarCountrySyncAck($.extend({
                    input_id: inputId,
                    stage: 'retry_' + delayMs + 'ms',
                    requested_value: requestedValue,
                    before_value: beforeRetryValue,
                    after_value: afterRetryValue,
                    matched_requested_value: afterRetryValue === requestedValue,
                    has_selectize: true
                  }, trace));
                  clearPendingSidebarCountrySyncIfMatched(afterRetryValue);
                  return;
                }

                if (window.Shiny && typeof Shiny.setInputValue === 'function') {
                  Shiny.setInputValue(inputId, requestedValue, { priority: 'event' });
                  emitSidebarCountrySyncAck($.extend({
                    input_id: inputId,
                    stage: 'retry_' + delayMs + 'ms_shiny_input_fallback',
                    requested_value: requestedValue,
                    before_value: null,
                    after_value: requestedValue,
                    matched_requested_value: true,
                    has_selectize: false
                  }, trace));
                }
              }, delayMs);
            });
          }

          if (typeof inputId !== 'string' || !inputId.length) {
            return false;
          }

          var selectNode = document.getElementById(inputId);
          if (selectNode && selectNode.selectize) {
            var beforeValue = String(selectNode.selectize.getValue() || '');

            tracePsdMapSyncClientStep('before_set_value', beforeValue, beforeValue, !!selectNode, true, beforeValue === requestedValue);

            if (beforeValue !== requestedValue) {
              selectNode.selectize.setValue(requestedValue);
            }

            var afterValue = String(selectNode.selectize.getValue() || '');
            tracePsdMapSyncClientStep('after_set_value', beforeValue, afterValue, !!selectNode, true, afterValue === requestedValue);

            if (inputId === 'psd_map_country_choice') {
              var immediateValue = String(selectNode.selectize.getValue() || '');
              tracePsdMapSyncClientStep('emit_ack_immediate', beforeValue, immediateValue, !!selectNode, true, immediateValue === requestedValue);
              emitPsdMapCountrySyncAck($.extend({
                input_id: inputId,
                stage: 'immediate',
                requested_value: requestedValue,
                before_value: beforeValue,
                after_value: immediateValue,
                matched_requested_value: immediateValue === requestedValue,
                has_selectize: true
              }, trace));

              window.setTimeout(function() {
                var currentNode = document.getElementById(inputId);
                var currentSelectize = currentNode && currentNode.selectize ? currentNode.selectize : null;
                var deferredValue = currentSelectize ? String(currentSelectize.getValue() || '') : '';
                tracePsdMapSyncClientStep('emit_ack_deferred_120ms', beforeValue, deferredValue, !!currentNode, !!currentSelectize, deferredValue === requestedValue);
                emitPsdMapCountrySyncAck($.extend({
                  input_id: inputId,
                  stage: 'deferred_120ms',
                  requested_value: requestedValue,
                  before_value: beforeValue,
                  after_value: deferredValue,
                  matched_requested_value: deferredValue === requestedValue,
                  has_selectize: !!currentSelectize
                }, trace));
              }, 120);
            } else if (inputId === 'country_choice') {
              var sidebarImmediateValue = String(selectNode.selectize.getValue() || '');
              emitSidebarCountrySyncAck($.extend({
                input_id: inputId,
                stage: 'immediate',
                requested_value: requestedValue,
                before_value: beforeValue,
                after_value: sidebarImmediateValue,
                matched_requested_value: sidebarImmediateValue === requestedValue,
                has_selectize: true
              }, trace));
              clearPendingSidebarCountrySyncIfMatched(sidebarImmediateValue);

              window.setTimeout(function() {
                var currentNode = document.getElementById(inputId);
                var currentSelectize = currentNode && currentNode.selectize ? currentNode.selectize : null;
                var deferredValue = currentSelectize ? String(currentSelectize.getValue() || '') : '';
                emitSidebarCountrySyncAck($.extend({
                  input_id: inputId,
                  stage: 'deferred_120ms',
                  requested_value: requestedValue,
                  before_value: beforeValue,
                  after_value: deferredValue,
                  matched_requested_value: deferredValue === requestedValue,
                  has_selectize: !!currentSelectize
                }, trace));
                clearPendingSidebarCountrySyncIfMatched(deferredValue);
              }, 120);

              scheduleSidebarRetrySync();
            }

            return true;
          }

          if (window.Shiny && typeof Shiny.setInputValue === 'function') {
            Shiny.setInputValue(inputId, requestedValue, { priority: 'event' });

            if (inputId === 'psd_map_country_choice') {
              tracePsdMapSyncClientStep('shiny_input_fallback', null, requestedValue, !!selectNode, false, true);
              emitPsdMapCountrySyncAck($.extend({
                input_id: inputId,
                stage: 'shiny_input_fallback',
                requested_value: requestedValue,
                before_value: null,
                after_value: requestedValue,
                matched_requested_value: true,
                has_selectize: false
              }, trace));
            } else if (inputId === 'country_choice') {
              emitSidebarCountrySyncAck($.extend({
                input_id: inputId,
                stage: 'shiny_input_fallback',
                requested_value: requestedValue,
                before_value: null,
                after_value: requestedValue,
                matched_requested_value: true,
                has_selectize: false
              }, trace));

              scheduleSidebarRetrySync();
            }

            return true;
          }

          return false;
        }

        function isPsdMapCountryChoicePrintableKey(e) {
          if (!e || e.ctrlKey || e.metaKey || e.altKey) return false;
          return typeof e.key === 'string' && e.key.length === 1;
        }

        function preparePsdMapCountryChoiceSelectizeForTyping(selectize) {
          if (!selectize) return false;

          if (typeof selectize.unlock === 'function') {
            selectize.unlock();
          }

          if (selectize.$control && selectize.$control.length) {
            selectize.$control.removeClass('locked disabled');
          }

          if (selectize.$control_input && selectize.$control_input.length) {
            selectize.$control_input.prop('disabled', false);
            selectize.$control_input.prop('readonly', false);
            selectize.$control_input.removeAttr('readonly');
            if (!selectize.$control_input.attr('tabindex')) {
              selectize.$control_input.attr('tabindex', '0');
            }
          }

          return true;
        }

        function applyPsdMapCountryChoiceManualQueryFallback(selectize, key) {
          if (!selectize || !selectize.$control_input || !selectize.$control_input.length) {
            return false;
          }

          var currentValue = String(selectize.$control_input.val() || selectize.lastValue || '');
          var nextValue = currentValue;

          if (isPsdMapCountryChoicePrintableKey({ key: key, ctrlKey: false, metaKey: false, altKey: false })) {
            nextValue = currentValue + key;
          } else if (key === 'Backspace') {
            nextValue = currentValue.slice(0, Math.max(0, currentValue.length - 1));
          } else if (key === 'Delete') {
            nextValue = '';
          } else {
            return false;
          }

          preparePsdMapCountryChoiceSelectizeForTyping(selectize);

          if (typeof selectize.setTextboxValue === 'function') {
            selectize.setTextboxValue(nextValue);
          } else {
            selectize.$control_input.val(nextValue);
          }

          if (typeof selectize.open === 'function' && !selectize.isOpen) {
            selectize.open();
          }

          if (typeof selectize.onSearchChange === 'function') {
            selectize.onSearchChange(nextValue);
          }
          if (typeof selectize.refreshOptions === 'function') {
            selectize.refreshOptions(true);
          }

          return true;
        }

        function attachPsdMapCountryChoiceSelectizeTyping() {
          var selectize = getPsdMapCountryChoiceSelectize();
          if (!selectize || !selectize.$control || !selectize.$control.length) return false;
          if (selectize.$control.attr('data-psd-map-country-choice-bound') === 'true') return true;

          selectize.$control.attr('data-psd-map-country-choice-bound', 'true');
          selectize.__psdMapCountryChoiceLastNativeInputAt = 0;
          selectize.__psdMapCountryChoiceFallbackNonce = 0;

          selectize.$control.off('.psdMapCountryChoiceType');
          selectize.$control.on('mousedown.psdMapCountryChoiceType click.psdMapCountryChoiceType', function(e) {
            preparePsdMapCountryChoiceSelectizeForTyping(selectize);
            tracePsdMapCountryState('psd_map_country_choice_' + e.type, {
              client_step: e.type,
              dom_event_type: e.type,
              event_target: e.target && e.target.tagName ? e.target.tagName.toLowerCase() : '<unknown>'
            });
            if (selectize.$control_input && selectize.$control_input.length && document.activeElement !== selectize.$control_input.get(0)) {
              selectize.focus();
            }
          });

          if (typeof selectize.on === 'function') {
            selectize.on('dropdown_open', function() {
              preparePsdMapCountryChoiceSelectizeForTyping(selectize);
              tracePsdMapCountryState('psd_map_country_choice_dropdown_open', { client_step: 'dropdown_open' });
            });
            selectize.on('focus', function() {
              preparePsdMapCountryChoiceSelectizeForTyping(selectize);
              tracePsdMapCountryState('psd_map_country_choice_focus', { client_step: 'focus' });
            });
            selectize.on('blur', function() {
              tracePsdMapCountryState('psd_map_country_choice_blur', { client_step: 'blur' });
            });
            selectize.on('change', function(value) {
              tracePsdMapCountryState('psd_map_country_choice_change', {
                client_step: 'change',
                changed_value: String(value || '')
              });
            });
            selectize.on('item_add', function() {
              tracePsdMapCountryState('psd_map_country_choice_item_add', { client_step: 'item_add' });
              if (typeof selectize.setTextboxValue === 'function') {
                selectize.setTextboxValue('');
              }
            });
          }

          if (selectize.$control_input && selectize.$control_input.length) {
            selectize.$control_input.off('.psdMapCountryChoiceType');
            selectize.$control_input.on('focus.psdMapCountryChoiceType', function() {
              preparePsdMapCountryChoiceSelectizeForTyping(selectize);
            });
            selectize.$control_input.on('keydown.psdMapCountryChoiceType', function(e) {
              preparePsdMapCountryChoiceSelectizeForTyping(selectize);

              if (e.key === 'Backspace' || e.key === 'Delete') {
                e.preventDefault();
                applyPsdMapCountryChoiceManualQueryFallback(selectize, e.key || '');
                return;
              }

              if (!isPsdMapCountryChoicePrintableKey(e)) {
                return;
              }

              var beforeValue = String($(this).val() || '');
              var fallbackNonce = (selectize.__psdMapCountryChoiceFallbackNonce || 0) + 1;
              selectize.__psdMapCountryChoiceFallbackNonce = fallbackNonce;

              window.setTimeout(function() {
                if (!selectize || selectize.__psdMapCountryChoiceFallbackNonce !== fallbackNonce) return;

                var currentValue = String((selectize.$control_input && selectize.$control_input.val()) || '');
                var nativeInputAt = Number(selectize.__psdMapCountryChoiceLastNativeInputAt || 0);
                if (nativeInputAt >= fallbackNonce || currentValue !== beforeValue) {
                  return;
                }

                applyPsdMapCountryChoiceManualQueryFallback(selectize, e.key || '');
              }, 0);
            });
            selectize.$control_input.on('input.psdMapCountryChoiceType', function() {
              selectize.__psdMapCountryChoiceLastNativeInputAt = Number(selectize.__psdMapCountryChoiceFallbackNonce || 0);
            });
          }

          preparePsdMapCountryChoiceSelectizeForTyping(selectize);
          return true;
        }

        var psdMapCountryChoiceObserver = new MutationObserver(function() {
          attachPsdMapCountryChoiceSelectizeTyping();
        });

        if (document.body) {
          psdMapCountryChoiceObserver.observe(document.body, { childList: true, subtree: true });
        }

        attachPsdMapCountryChoiceSelectizeTyping();

        function getCommodityChoiceSelectize() {
          var selectNode = document.getElementById('commodity_choice');
          return selectNode && selectNode.selectize ? selectNode.selectize : null;
        }

        function isCommodityChoicePrintableKey(e) {
          if (!e || e.ctrlKey || e.metaKey || e.altKey) return false;
          return typeof e.key === 'string' && e.key.length === 1;
        }

        function prepareCommodityChoiceSelectizeForTyping(selectize) {
          if (!selectize) return false;

          if (typeof selectize.unlock === 'function') {
            selectize.unlock();
          }

          if (selectize.$control && selectize.$control.length) {
            selectize.$control.removeClass('locked disabled');
          }

          if (selectize.$control_input && selectize.$control_input.length) {
            selectize.$control_input.prop('disabled', false);
            selectize.$control_input.prop('readonly', false);
            selectize.$control_input.removeAttr('readonly');
            if (!selectize.$control_input.attr('tabindex')) {
              selectize.$control_input.attr('tabindex', '0');
            }
          }

          return true;
        }

        function applyCommodityChoiceManualQueryFallback(selectize, key) {
          if (!selectize || !selectize.$control_input || !selectize.$control_input.length) {
            return false;
          }

          var currentValue = String(selectize.$control_input.val() || selectize.lastValue || '');
          var nextValue = currentValue;

          if (isCommodityChoicePrintableKey({ key: key, ctrlKey: false, metaKey: false, altKey: false })) {
            nextValue = currentValue + key;
          } else if (key === 'Backspace') {
            nextValue = currentValue.slice(0, Math.max(0, currentValue.length - 1));
          } else if (key === 'Delete') {
            nextValue = '';
          } else {
            return false;
          }

          prepareCommodityChoiceSelectizeForTyping(selectize);

          if (typeof selectize.setTextboxValue === 'function') {
            selectize.setTextboxValue(nextValue);
          } else {
            selectize.$control_input.val(nextValue);
          }

          if (typeof selectize.open === 'function' && !selectize.isOpen) {
            selectize.open();
          }

          if (typeof selectize.onSearchChange === 'function') {
            selectize.onSearchChange(nextValue);
          }
          if (typeof selectize.refreshOptions === 'function') {
            selectize.refreshOptions(true);
          }

          return true;
        }

        function attachCommodityChoiceSelectizeTyping() {
          var selectize = getCommodityChoiceSelectize();
          if (!selectize || !selectize.$control || !selectize.$control.length) return false;
          if (selectize.$control.attr('data-commodity-choice-bound') === 'true') return true;

          selectize.$control.attr('data-commodity-choice-bound', 'true');
          selectize.__commodityChoiceLastNativeInputAt = 0;
          selectize.__commodityChoiceFallbackNonce = 0;

          selectize.$control.off('.commodityChoiceType');
          selectize.$control.on('mousedown.commodityChoiceType click.commodityChoiceType', function() {
            prepareCommodityChoiceSelectizeForTyping(selectize);
            if (selectize.$control_input && selectize.$control_input.length && document.activeElement !== selectize.$control_input.get(0)) {
              selectize.focus();
            }
          });

          if (typeof selectize.on === 'function') {
            selectize.on('dropdown_open', function() {
              prepareCommodityChoiceSelectizeForTyping(selectize);
            });
            selectize.on('focus', function() {
              prepareCommodityChoiceSelectizeForTyping(selectize);
            });
            selectize.on('item_add', function() {
              if (typeof selectize.setTextboxValue === 'function') {
                selectize.setTextboxValue('');
              }
            });
          }

          if (selectize.$control_input && selectize.$control_input.length) {
            selectize.$control_input.off('.commodityChoiceType');
            selectize.$control_input.on('focus.commodityChoiceType', function() {
              prepareCommodityChoiceSelectizeForTyping(selectize);
            });
            selectize.$control_input.on('keydown.commodityChoiceType', function(e) {
              prepareCommodityChoiceSelectizeForTyping(selectize);

              if (e.key === 'Tab') {
                if (commitHighlightedSelectizeOptionOnTab(selectize, this)) {
                  e.preventDefault();
                }
                return;
              }

              if (e.key === 'Backspace' || e.key === 'Delete') {
                e.preventDefault();
                applyCommodityChoiceManualQueryFallback(selectize, e.key || '');
                return;
              }

              if (!isCommodityChoicePrintableKey(e)) {
                return;
              }

              var beforeValue = String($(this).val() || '');
              var fallbackNonce = (selectize.__commodityChoiceFallbackNonce || 0) + 1;
              selectize.__commodityChoiceFallbackNonce = fallbackNonce;

              window.setTimeout(function() {
                if (!selectize || selectize.__commodityChoiceFallbackNonce !== fallbackNonce) return;

                var currentValue = String((selectize.$control_input && selectize.$control_input.val()) || '');
                var nativeInputAt = Number(selectize.__commodityChoiceLastNativeInputAt || 0);
                if (nativeInputAt >= fallbackNonce || currentValue !== beforeValue) {
                  return;
                }

                applyCommodityChoiceManualQueryFallback(selectize, e.key || '');
              }, 0);
            });
            selectize.$control_input.on('input.commodityChoiceType', function() {
              selectize.__commodityChoiceLastNativeInputAt = Number(selectize.__commodityChoiceFallbackNonce || 0);
            });
          }

          prepareCommodityChoiceSelectizeForTyping(selectize);
          return true;
        }

        var commodityChoiceObserver = new MutationObserver(function() {
          attachCommodityChoiceSelectizeTyping();
        });

        if (document.body) {
          commodityChoiceObserver.observe(document.body, { childList: true, subtree: true });
        }

        attachCommodityChoiceSelectizeTyping();
        
        // Make panel draggable by header
        $(document).on('mousedown', '#notes_panel_header', function(e) {
          if ($(e.target).hasClass('close-btn') || $(e.target).hasClass('minimize-btn')) return;
          isDragging = true;
          var panel = $('#floating_notes_panel');
          var rect = panel.length ? panel.get(0).getBoundingClientRect() : { left: 0, top: 0 };
          offsetX = e.clientX - rect.left;
          offsetY = e.clientY - rect.top;
          e.preventDefault();
        });
        
        $(document).on('mousemove', function(e) {
          if (isDragging) {
            recoverNotesFloatingPanel({
              reason: 'drag_move',
              left: e.clientX - offsetX,
              top: e.clientY - offsetY
            });
          }
        });
        
        $(document).on('mouseup', function() {
          if (isDragging) {
            recoverNotesFloatingPanel({ reason: 'drag_end' });
          }
          isDragging = false;
        });

        $(window).on('resize.notesFloatingPanel', function() {
          if (!$('#floating_notes_panel').hasClass('visible')) return;
          if (pendingNotesPanelResizeTimer) {
            window.clearTimeout(pendingNotesPanelResizeTimer);
          }
          pendingNotesPanelResizeTimer = window.setTimeout(function() {
            pendingNotesPanelResizeTimer = null;
            recoverNotesFloatingPanel({ reason: 'viewport_resize' });
          }, 100);
        });

        // Toggle minimize
        $(document).on('click', '.minimize-btn', function() {
          $('#notes_panel_body').toggleClass('minimized');
          $('#notes_panel_footer').toggleClass('minimized');
          var btn = $(this);
          btn.text(btn.text() === '−' ? '□' : '−');

          if ($('#floating_notes_panel').hasClass('visible') && !$('#notes_panel_body').hasClass('minimized')) {
            scheduleNotesCountrySelectizeActivation(false);
          }
        });

        // Insert formula tokens/operators at caret position in custom builder textarea.
        $(document).on('click', '.formula-insert-btn', function() {
          var textToInsert = $(this).attr('data-insert') || '';
          if (!textToInsert) return;

          var targetId = $(this).attr('data-target') || '';
          if (!targetId) {
            targetId = document.getElementById('custom_builder_formula') ? 'custom_builder_formula' : 'custom_country_builder_formula';
          }

          var textarea = document.getElementById(targetId);
          if (!textarea) return;

          var start = textarea.selectionStart || 0;
          var end = textarea.selectionEnd || start;
          var current = textarea.value || '';
          var next = current.substring(0, start) + textToInsert + current.substring(end);

          textarea.value = next;
          textarea.focus();
          var caret = start + textToInsert.length;
          textarea.setSelectionRange(caret, caret);

          $(textarea).trigger('input');
          $(textarea).trigger('change');
        });
        
        // Shiny message handler to show the panel
        Shiny.addCustomMessageHandler('showNotesPanel', function(message) {
          traceNotesState('panel_show_requested', 'showNotesPanel_before');
          $('#floating_notes_panel').addClass('visible');
          recoverNotesFloatingPanel({ reason: 'showNotesPanel' });
          scheduleNotesCountrySelectizeActivation(false);
          window.setTimeout(function() {
            traceNotesState('panel_show_post_activation', 'showNotesPanel_after');
          }, 180);
        });

        Shiny.addCustomMessageHandler('setSelectizeOrShinyInputValue', function(message) {
          var payload = message || {};
          setSelectizeOrShinyInputValue(payload.inputId, payload.value, payload.trace || {});
        });

        Shiny.addCustomMessageHandler('selectMainTabWhenProfileReady', function(message) {
          selectMainTabWhenProfileReady(message || {});
        });

        Shiny.addCustomMessageHandler('captureNotesCountryProbe', function(message) {
          if (!notesProbeEnabled()) {
            return;
          }

          var request = message || {};
          var delayMs = Number(request.delay_ms);
          if (!Number.isFinite(delayMs) || delayMs < 0) {
            delayMs = 0;
          }

          window.setTimeout(function() {
            traceNotesState('probe', request.reason || null, {
              request_action_id: request.action_id || null,
              request_mutation_seq: request.mutation_seq || null,
              request_ts: request.requested_at_utc || null
            });
          }, delayMs);
        });

        Shiny.addCustomMessageHandler('capturePsdMapCountryProbe', function(message) {
          if (!psdProbeEnabled()) {
            return;
          }

          var request = message || {};
          var delayMs = Number(request.delay_ms);
          if (!Number.isFinite(delayMs) || delayMs < 0) {
            delayMs = 0;
          }

          window.setTimeout(function() {
            tracePsdMapCountryState(request.reason || null, {
              action_id: request.action_id || null,
              mutation_seq: request.mutation_seq || null,
              requested_at_utc: request.requested_at_utc || null
            });
          }, delayMs);
        });

        Shiny.addCustomMessageHandler('captureSidebarCountryProbe', function(message) {
          if (!psdProbeEnabled()) {
            return;
          }

          var request = message || {};
          var delayMs = Number(request.delay_ms);
          if (!Number.isFinite(delayMs) || delayMs < 0) {
            delayMs = 0;
          }

          window.setTimeout(function() {
            traceSidebarCountryState(request.reason || null, {
              action_id: request.action_id || null,
              mutation_seq: request.mutation_seq || null,
              requested_at_utc: request.requested_at_utc || null
            });
          }, delayMs);
        });

        if (manualCaptureEnabled()) {
          $(document).on('keydown', function(e) {
            var isCaptureShortcut = !!(
              (e.ctrlKey || e.metaKey) &&
              e.shiftKey &&
              (e.code === 'Period' || e.key === '.' || e.key === '>')
            );

            if (!isCaptureShortcut) return;

            e.preventDefault();
            emitManualDebugCapture('manual_hotkey', {
              shortcut: 'Ctrl+Shift+.'
            });
          });
        }

        Shiny.addCustomMessageHandler('toggleCensusCorrectionsSidebar', function(message) {
          var hideSidebar = !!(message && message.hide_sidebar);
          $('body').toggleClass('census-corrections-sidebar-hidden', hideSidebar);
        });

        Shiny.addCustomMessageHandler('capturePartnerShowProbe', function(message) {
          if (!mycProbeEnabled()) {
            return;
          }

          var request = message || {};
          var delayMs = Number(request.delay_ms);
          if (!Number.isFinite(delayMs) || delayMs < 0) {
            delayMs = 0;
          }

          window.setTimeout(function() {
            var selectNode = document.getElementById('partner_show');
            var selectize = selectNode && selectNode.selectize ? selectNode.selectize : null;
            var selectedValues = [];
            var selectedLabels = [];
            var choiceCount = 0;

            if (selectize) {
              selectedValues = (selectize.items || []).slice();
              var options = selectize.options || {};
              selectedLabels = selectedValues.map(function(value) {
                if (options[value] && options[value].text) return String(options[value].text);
                return String(value);
              });
              choiceCount = Object.keys(options).length;
            } else {
              var fallbackValues = $('#partner_show').val();
              if (Array.isArray(fallbackValues)) {
                selectedValues = fallbackValues.slice();
              } else if (typeof fallbackValues === 'string' && fallbackValues.length > 0) {
                selectedValues = [fallbackValues];
              }
              selectedLabels = selectedValues.slice();
            }

            Shiny.setInputValue('client_myc_partner_show_probe', {
              reason: request.reason || null,
              action_id: request.action_id || null,
              mutation_seq: request.mutation_seq || null,
              selected_values: selectedValues,
              selected_labels: selectedLabels,
              choice_count: choiceCount,
              has_selectize: !!selectize,
              captured_at_iso: new Date().toISOString(),
              nonce: Date.now()
            }, { priority: 'event' });
          }, delayMs);
        });

        Shiny.addCustomMessageHandler('captureMycOutputProbe', function(message) {
          if (!mycProbeEnabled()) {
            return;
          }

          var request = message || {};
          var delayMs = Number(request.delay_ms);
          if (!Number.isFinite(delayMs) || delayMs < 0) {
            delayMs = 0;
          }

          function describeNode(selector) {
            var node = document.querySelector(selector);
            if (!node) {
              return {
                exists: false,
                visible: false,
                width: 0,
                height: 0,
                display: null,
                visibility: null,
                child_count: 0,
                text_length: 0
              };
            }

            var rect = node.getBoundingClientRect();
            var style = window.getComputedStyle(node);
            var firstBar = node.querySelector ? node.querySelector('.barlayer path') : null;
            var firstBarRect = firstBar ? firstBar.getBoundingClientRect() : null;
            var firstBarStyle = firstBar ? window.getComputedStyle(firstBar) : null;
            return {
              exists: true,
              visible: !!(rect.width || rect.height || node.getClientRects().length),
              width: Math.round(rect.width),
              height: Math.round(rect.height),
              display: style.display,
              visibility: style.visibility,
              child_count: node.children ? node.children.length : 0,
              text_length: (node.textContent || '').trim().length,
              plotly_count: node.querySelectorAll ? node.querySelectorAll('.plotly').length : 0,
              main_svg_count: node.querySelectorAll ? node.querySelectorAll('.main-svg').length : 0,
              bar_path_count: node.querySelectorAll ? node.querySelectorAll('.barlayer path').length : 0,
              legend_count: node.querySelectorAll ? node.querySelectorAll('.legend').length : 0,
              first_bar_width: firstBarRect ? Math.round(firstBarRect.width) : 0,
              first_bar_height: firstBarRect ? Math.round(firstBarRect.height) : 0,
              first_bar_fill: firstBarStyle ? firstBarStyle.fill : null,
              first_bar_opacity: firstBarStyle ? firstBarStyle.opacity : null
            };
          }

          window.setTimeout(function() {
            Shiny.setInputValue('client_myc_output_probe', {
              reason: request.reason || null,
              action_id: request.action_id || null,
              mutation_seq: request.mutation_seq || null,
              plot_scroll: describeNode('#partner_share_plot_scroll_container'),
              plot_width: describeNode('#partner_share_plot_width_container'),
              plot: describeNode('#partner_share_plot'),
              table: describeNode('#myc_market_year_table'),
              comparison_basis: describeNode('#comparison_basis_ui'),
              myc_cutoff: describeNode('#myc_cutoff_controls_ui'),
              captured_at_iso: new Date().toISOString(),
              nonce: Date.now()
            }, { priority: 'event' });
          }, delayMs);
        });

        Shiny.addCustomMessageHandler('forcePartnerShowSelection', function(message) {
          var request = message || {};
          var selectedValues = Array.isArray(request.selected) ? request.selected.map(String) : [];
          var delayMs = Number(request.delay_ms);
          if (!Number.isFinite(delayMs) || delayMs < 0) {
            delayMs = 0;
          }

          window.setTimeout(function() {
            var selectNode = document.getElementById('partner_show');
            var selectize = selectNode && selectNode.selectize ? selectNode.selectize : null;

            if (selectize) {
              selectedValues.forEach(function(value) {
                if (!selectize.options[value]) {
                  selectize.addOption({ value: value, text: value });
                }
              });
              selectize.clear(true);
              selectize.setValue(selectedValues, true);
              selectize.refreshItems();
              selectize.refreshOptions(false);
              return;
            }

            $('#partner_show').val(selectedValues).trigger('change.selectize');
          }, delayMs);
        });

        $(document).on('click', '.tabbable > .nav > li > a, .tabbable > .nav-tabs > li > a', function() {
          if ($(this).attr('data-toggle') !== 'tab' || !isMainTabsAnchor(this)) return;
          perfState.lastTabClickedAt = perfNow();
          perfState.lastTabName = $(this).attr('data-value') || $.trim($(this).text()) || null;
          beginPerfAction('tab_click:' + (perfState.lastTabName || 'unknown_tab'));
          emitBoundaryMarker('tab_click_dispatched', {
            tab: perfState.lastTabName || null
          });
        });

        $(document).on('shown.bs.tab', '.tabbable > .nav > li > a, .tabbable > .nav-tabs > li > a', function() {
          if ($(this).attr('data-toggle') !== 'tab' || !isMainTabsAnchor(this)) return;
          var now = perfNow();
          var tabName = $(this).attr('data-value') || $.trim($(this).text()) || perfState.lastTabName || currentMainTabValue();

          emitClientPerf('client_perf_tab_shown', {
            tab: tabName,
            elapsed_ms: perfState.lastTabClickedAt === null ? null : Math.round(now - perfState.lastTabClickedAt)
          });

          emitBoundaryMarker('tab_shown', {
            tab: tabName,
            elapsed_ms: perfState.lastTabClickedAt === null ? null : Math.round(now - perfState.lastTabClickedAt)
          });

          setTimeout(function() {
            emitClientPerf('client_perf_tab_after_paint', {
              tab: tabName,
              elapsed_ms: perfState.lastTabClickedAt === null ? null : Math.round(perfNow() - perfState.lastTabClickedAt)
            });

            emitBoundaryMarker('tab_after_paint', {
              tab: tabName,
              elapsed_ms: perfState.lastTabClickedAt === null ? null : Math.round(perfNow() - perfState.lastTabClickedAt)
            });
          }, 0);
        });

        // Force plotly widgets to recompute size after tab/layout changes.
        Shiny.addCustomMessageHandler('forcePlotlyResize', function(message) {
          var resizeStartedAt = perfNow();
          pendingPlotlyResizeMessage = message || {};
          var resizeRequestId = (message && message.resize_request_id) ? message.resize_request_id : null;
          emitBoundaryMarker('plotly_resize_handler_enter', {
            tab: (message && message.tab) ? message.tab : (currentMainTabValue() || activeTabName() || currentMainTabValue()),
            resize_request_id: resizeRequestId,
            elapsed_ms: 0
          });
          if (pendingPlotlyResizeTimer !== null) {
            window.clearTimeout(pendingPlotlyResizeTimer);
          }

          pendingPlotlyResizeTimer = window.setTimeout(function() {
            var resizeMessage = pendingPlotlyResizeMessage || {};
            pendingPlotlyResizeTimer = null;
            pendingPlotlyResizeMessage = null;
              var currentTabValue = currentMainTabValue();
              var targetOutputId = targetOutputIdForMainTab(resizeMessage.tab || currentTabValue || activeTabName() || currentMainTabValue());
              var targetStateBefore = outputResizeState(targetOutputId);
              if (resizeMessage.tab && currentTabValue && resizeMessage.tab !== currentTabValue) {
                var skippedTargetState = outputResizeState(targetOutputId);
                emitClientPerf('client_perf_plotly_resize_skipped', {
                  requested_tab: resizeMessage.tab,
                  active_tab: currentTabValue,
                  resize_request_id: resizeMessage.resize_request_id || null,
                  target_output_id: targetOutputId,
                  target_present: skippedTargetState.present,
                  target_visible: skippedTargetState.visible,
                  target_width: skippedTargetState.width,
                  target_height: skippedTargetState.height,
                  target_widget_count: skippedTargetState.widget_count,
                  target_main_svg_count: skippedTargetState.main_svg_count,
                  target_loading_indicator_count: skippedTargetState.loading_indicator_count,
                  source_switch_epoch_id: resizeMessage.source_switch_epoch_id || null,
                  source_switch_trigger: resizeMessage.source_switch_trigger || null,
                  source_switch_from: resizeMessage.source_switch_from || null,
                  source_switch_to: resizeMessage.source_switch_to || null,
                  elapsed_ms: Math.round(perfNow() - resizeStartedAt)
                });
                return;
              }
            var resizedCount = 0;
            var visibleWidgets = $('.plotly.html-widget').filter(function() {
              var widget = $(this);
              return widget.is(':visible') && widget.width() > 0 && widget.height() > 0;
            });
            window.dispatchEvent(new Event('resize'));
            if (window.Plotly && visibleWidgets.length) {
              visibleWidgets.each(function() {
                try {
                  Plotly.Plots.resize(this);
                  if (typeof Plotly.redraw === 'function') {
                    Plotly.redraw(this);
                  }
                  resizedCount += 1;
                } catch (e) {}
              });
            }
            var targetStateAfterResize = outputResizeState(targetOutputId);
            emitBoundaryMarker('plotly_resize_handler_flush', {
              tab: resizeMessage.tab || currentTabValue || activeTabName() || currentMainTabValue(),
              resize_request_id: resizeMessage.resize_request_id || null,
              target_output_id: targetOutputId,
              target_present_after_resize: targetStateAfterResize.present,
              target_visible_after_resize: targetStateAfterResize.visible,
              target_widget_count_after_resize: targetStateAfterResize.widget_count,
              target_main_svg_count_after_resize: targetStateAfterResize.main_svg_count,
              target_loading_indicator_count_after_resize: targetStateAfterResize.loading_indicator_count,
              visible_widget_count: visibleWidgets.length,
              resized_count: resizedCount,
              elapsed_ms: Math.round(perfNow() - resizeStartedAt)
            });

            window.requestAnimationFrame(function() {
              var targetStateAfterPaint = outputResizeState(targetOutputId);
              emitBoundaryMarker('plotly_resize_after_paint_snapshot', {
                tab: resizeMessage.tab || currentTabValue || activeTabName() || currentMainTabValue(),
                resize_request_id: resizeMessage.resize_request_id || null,
                target_output_id: targetOutputId,
                target_present_after_paint: targetStateAfterPaint.present,
                target_visible_after_paint: targetStateAfterPaint.visible,
                target_widget_count_after_paint: targetStateAfterPaint.widget_count,
                target_main_svg_count_after_paint: targetStateAfterPaint.main_svg_count,
                target_loading_indicator_count_after_paint: targetStateAfterPaint.loading_indicator_count,
                elapsed_ms: Math.round(perfNow() - resizeStartedAt)
              });
              emitClientPerf('client_perf_plotly_resize', {
                tab: resizeMessage.tab || currentTabValue || activeTabName() || currentMainTabValue(),
                resize_request_id: resizeMessage.resize_request_id || null,
                target_output_id: targetOutputId,
                target_present_before: targetStateBefore.present,
                target_visible_before: targetStateBefore.visible,
                target_width_before: targetStateBefore.width,
                target_height_before: targetStateBefore.height,
                target_widget_count_before: targetStateBefore.widget_count,
                target_main_svg_count_before: targetStateBefore.main_svg_count,
                target_loading_indicator_count_before: targetStateBefore.loading_indicator_count,
                target_present_after_resize: targetStateAfterResize.present,
                target_visible_after_resize: targetStateAfterResize.visible,
                target_width_after_resize: targetStateAfterResize.width,
                target_height_after_resize: targetStateAfterResize.height,
                target_widget_count_after_resize: targetStateAfterResize.widget_count,
                target_main_svg_count_after_resize: targetStateAfterResize.main_svg_count,
                target_loading_indicator_count_after_resize: targetStateAfterResize.loading_indicator_count,
                target_present_after_paint: targetStateAfterPaint.present,
                target_visible_after_paint: targetStateAfterPaint.visible,
                target_width_after_paint: targetStateAfterPaint.width,
                target_height_after_paint: targetStateAfterPaint.height,
                target_widget_count_after_paint: targetStateAfterPaint.widget_count,
                target_main_svg_count_after_paint: targetStateAfterPaint.main_svg_count,
                target_loading_indicator_count_after_paint: targetStateAfterPaint.loading_indicator_count,
                source_switch_epoch_id: resizeMessage.source_switch_epoch_id || null,
                source_switch_trigger: resizeMessage.source_switch_trigger || null,
                source_switch_from: resizeMessage.source_switch_from || null,
                source_switch_to: resizeMessage.source_switch_to || null,
                elapsed_ms: Math.round(perfNow() - resizeStartedAt),
                resized_count: resizedCount,
                visible_widget_count: visibleWidgets.length
              });

              var outputVisibleReady = targetStateAfterPaint.present &&
                targetStateAfterPaint.visible;

              if (outputVisibleReady) {
                emitBoundaryMarker('visible_ready', {
                  tab: resizeMessage.tab || currentTabValue || activeTabName() || currentMainTabValue(),
                  resize_request_id: resizeMessage.resize_request_id || null,
                  target_output_id: targetOutputId,
                  target_width: targetStateAfterPaint.width,
                  target_height: targetStateAfterPaint.height,
                  target_widget_count: targetStateAfterPaint.widget_count,
                  target_main_svg_count: targetStateAfterPaint.main_svg_count,
                  target_loading_indicator_count: targetStateAfterPaint.loading_indicator_count,
                  elapsed_ms: Math.round(perfNow() - resizeStartedAt)
                });
              }
            });
          }, 120);
        });
      });
    "))
  ),
  
  titlePanel(APP_TITLE_LABEL),
  
  # Data frequency toggle
  fluidRow(
    column(
      width = 12,
      div(
        style = "padding: 10px; background-color: #f5f5f5; border-radius: 5px; margin-bottom: 15px;",
        uiOutput("data_frequency_ui"),
        uiOutput("data_quality_warning_ui")
      )
    )
  ),
  
  div(
    id = "main_sidebar_shell",
    sidebarLayout(
      sidebarPanel(
      width = 3,
      
      h4("Filter Parameters"),
      uiOutput("market_year_compare_filters_ui"),
      
      # Top partners filter
      conditionalPanel(
        condition = "input.main_tabs_panel != 'Market Year Comparison Tool' && input.main_tabs_panel != 'Map' && input.main_tabs_panel != 'Time Series Analysis Tool'",
        div(
          style = "padding: 4px 8px; background-color: #f0f0f0; border-radius: 5px; margin-top: 5px; margin-bottom: 8px;",
          div(style = "margin-bottom: 2px;",
            checkboxInput(
              inputId = "top5_only",
              label = "Show only top 5 export partners",
              value = FALSE
            )
          ),
          div(style = "margin-top: -10px;",
            checkboxInput(
              inputId = "top10_only",
              label = "Show only top 10 export partners",
              value = FALSE
            )
          )
        )
      ),

      # Country sort order (dynamic labels based on current period)
      conditionalPanel(
        condition = "input.main_tabs_panel != 'Market Year Comparison Tool' && input.main_tabs_panel != 'Map' && input.main_tabs_panel != 'Time Series Analysis Tool'",
          uiOutput("standard_country_sort_ui")
      ),

      # Market Year Comparison Tool customization: select comparison items to show separately
      uiOutput("partner_show_panel"),
      
      conditionalPanel(
          condition = "input.main_tabs_panel != 'Map' && input.main_tabs_panel != 'Heatmap' && input.main_tabs_panel != 'Data' && input.main_tabs_panel != 'Time Series Analysis Tool'",
        hr(class = "sidebar-divider-before-projections")
      ),

        uiOutput("comparison_basis_ui"),

      uiOutput("myc_cutoff_controls_ui"),

      # Year-End Projections section (only shown for cumulative metrics)
      conditionalPanel(
          condition = "input.main_tabs_panel != 'Market Year Comparison Tool' && input.main_tabs_panel != 'Map' && input.main_tabs_panel != 'Heatmap' && input.main_tabs_panel != 'Data' && input.main_tabs_panel != 'Time Series Analysis Tool'",
        uiOutput("projection_controls_ui")
      ),

      # Metric selection dropdown - dynamically updated based on data frequency
      # (weekly vs monthly data have different available metrics)
      hr(class = "sidebar-divider-before-variable"),
      uiOutput("metric_choice_ui"),

      hr(class = "sidebar-divider-after-variable"),
      
      # Unit of Analysis Selection
      # --------------------------
      # Allows users to convert all export quantity data from the source unit (Metric Tons)
      # into their preferred unit of measurement. The conversion is applied early in the
      # data pipeline (in selected_data() reactive) so all downstream calculations,
      # visualizations, and summary statistics reflect the chosen unit.
      # 
      # Available units:
      #   - Metric Tons (MT): Base unit, no conversion applied (1 MT = 1 MT)
      #   - Kilograms (KG): SI mass unit (1 MT = 1,000 KG)
      #   - 1000 Kilograms: Equivalent to one Metric Ton (1 MT = 1,000 KG)
      #   - US Tons: Also called "short tons" (1 MT = 1.10231 US tons)
      #   - 1000 Pounds: Source-native trade volume scale for many VP datasets (1 MT = 2.20462 thousand lbs)
      #   - Pounds (lbs): Common US weight unit (1 MT = 2,204.62 lbs)
      #   - Hundredweight (CWT): 100 pounds, commonly used in agriculture (1 MT = 22.0462 CWT)
      #   - Million Pounds: For large-scale aggregations (1 MT = 0.00220462 million lbs)
      uiOutput("unit_controls_ui"),
      
      hr(),
      
      h4("Analysis Info"),
      textOutput("data_summary"),
      
      hr()
    ),
    
      mainPanel(
        width = 9,
        
        # Main analysis tabs (including conditional Country Comparison tab)
        uiOutput("main_tabs")
      )
    )
  ),
  
  # Floating Notes Panel
  div(
    id = "floating_notes_panel",
    div(
      id = "notes_panel_header",
      div(
        class = "notes-title-wrap",
        span("Notes"),
        span(class = "notes-family-cue", textOutput("floating_notes_family_context", inline = TRUE))
      ),
      div(
        tags$button(class = "minimize-btn", "−"),
        tags$button(
          class = "close-btn",
          onclick = "window.notesTraceClosePanel();",
          "✕"
        )
      )
    ),
    div(
      id = "notes_panel_body",
      div(class = "notes-sync-status", textOutput("floating_notes_sync_status", inline = TRUE)),
      div(
        class = "notes-country-wrap",
        div(
          class = "notes-myc-picker",
          div(class = "notes-myc-picker-label", "Country"),
          div(class = "notes-myc-picker-hint", "Type to filter countries, then choose one from the same dropdown."),
          selectizeInput(
            inputId = "floating_notes_country_picker",
            label = NULL,
            choices = c("World" = "GRAND_TOTAL"),
            selected = "GRAND_TOTAL",
            multiple = FALSE,
            options = list(
              placeholder = "Choose a country...",
              maxOptions = 200,
              closeAfterSelect = TRUE,
              openOnFocus = TRUE,
              dropdownParent = "body"
            ),
            width = "100%"
          )
        ),
        div(
          style = "display: none;",
          selectInput(
            inputId = "floating_notes_country",
            label = NULL,
            choices = c("World" = "GRAND_TOTAL"),
            selected = "GRAND_TOTAL",
            selectize = FALSE,
            width = "100%"
          )
        )
      ),
      div(
        class = "notes-textarea-wrap",
        textAreaInput(
          inputId = "floating_note_text",
          label = NULL,
          value = "",
          placeholder = "Enter notes for the selected country...",
          rows = 6,
          width = "100%"
        ),
        div(class = "notes-empty-state", textOutput("floating_note_empty_state", inline = TRUE))
      )
    ),
    div(
      id = "notes_panel_footer",
      span(class = "timestamp", textOutput("floating_note_timestamp", inline = TRUE)),
      div(
        class = "notes-footer-actions",
        div(
          class = "notes-footer-buttons",
          actionButton("save_floating_note", "Save", class = "btn-sm btn-primary"),
          actionButton("clear_floating_note", "Clear My Notes", class = "btn-sm btn-danger"),
          actionButton("view_other_notes_btn", "View Other Users' Notes", class = "btn-sm btn-secondary")
        ),
        uiOutput("floating_notes_jump_action")
      )
    )
  )
)

