.lity_html_table <- function(data, digits = 4) {
  data <- as.data.frame(data, stringsAsFactors = FALSE)
  numeric <- vapply(data, is.numeric, logical(1))
  data[numeric] <- lapply(data[numeric], function(x) ifelse(is.finite(x), format(round(x, digits), trim = TRUE), as.character(x)))
  htmltools::tags$table(class = "lity-report-table",
    htmltools::tags$thead(htmltools::tags$tr(lapply(names(data), htmltools::tags$th))),
    htmltools::tags$tbody(lapply(seq_len(nrow(data)), function(i) {
      htmltools::tags$tr(lapply(data[i, , drop = FALSE], function(value) htmltools::tags$td(as.character(value[[1L]]))))
    }))
  )
}

#' Generate a reproducible optimal-design report
#' @param x Design, evaluation, optimisation, Pareto, or simulation result.
#' @param file Output HTML path.
#' @param title Optional report title.
#' @return Normalized report path, invisibly.
#' @export
lity_report <- function(x, file = tempfile("LibeRality-report-", fileext = ".html"),
                        title = NULL) {
  design <- if (inherits(x, "lity_design")) x else x$design %||% x$initial_design
  evaluation <- if (inherits(x, "lity_evaluation")) x else x$evaluation %||% NULL
  title <- title %||% paste("LibeRality design report -", design$name %||% "analysis")
  arm_table <- do.call(rbind, lapply(design$arms, function(arm) data.frame(
    arm = arm$name, subjects = arm$size,
    samples_per_subject = sum(arm$events$EVID == 0 & arm$events$MDV == 0),
    duration_hours = diff(range(arm$events$TIME)), population = arm$population,
    cost = .lity_design_cost(structure(utils::modifyList(design, list(arms = list(arm))), class = "lity_design")),
    stringsAsFactors = FALSE
  )))
  sections <- list(
    htmltools::tags$section(htmltools::tags$h2("Design summary"),
      htmltools::tags$p(design$description %||% ""),
      htmltools::tags$p(paste("Design id:", design$id)), .lity_html_table(arm_table)),
    htmltools::tags$section(htmltools::tags$h2("Assumptions"),
      htmltools::tags$p(paste("Model: ADVAN", design$model$ADVAN, "TRANS", design$model$TRANS)),
      htmltools::tags$p(paste("Scenarios:", paste(names(design$scenarios), collapse = ", "))),
      htmltools::tags$p(paste("Parameters:", paste(.lity_parameter_spec(design$model)$name, collapse = ", "))))
  )
  if (!is.null(evaluation)) {
    information <- evaluation$information[[1L]]
    precision <- data.frame(parameter = names(information$se), SE = information$se,
                            RSE_percent = information$rse, stringsAsFactors = FALSE)
    sections <- c(sections, list(
      htmltools::tags$section(htmltools::tags$h2("Design criteria"), .lity_html_table(evaluation$criteria)),
      htmltools::tags$section(htmltools::tags$h2("Expected precision"),
        htmltools::tags$p(paste("Numerical rank", information$rank, "of", nrow(information$matrix),
                               "condition number", format(information$condition_number, digits = 5))),
        .lity_html_table(precision)),
      htmltools::tags$section(htmltools::tags$h2("Constraints"),
        if (nrow(evaluation$constraints)) .lity_html_table(evaluation$constraints) else htmltools::tags$p("No constraints."))
    ))
  }
  if (inherits(x, "lity_optimisation")) sections <- c(sections, list(
    htmltools::tags$section(htmltools::tags$h2("Optimisation"),
      htmltools::tags$p(paste("Method:", x$method, "evaluations:", x$evaluations,
                             "elapsed seconds:", round(x$elapsed_seconds, 3))),
      htmltools::tags$p(x$message %||% ""))
  ))
  if (inherits(x, "lity_simulation")) sections <- c(sections, list(
    htmltools::tags$section(htmltools::tags$h2("Trial simulation"), .lity_html_table(x$summary))
  ))
  page <- htmltools::tags$html(
    htmltools::tags$head(htmltools::tags$title(title), htmltools::tags$style(htmltools::HTML(
      "body{font-family:Inter,Segoe UI,sans-serif;margin:40px;color:#2d2a25;background:#fbfaf7}header{border-bottom:4px solid #c88923;margin-bottom:28px}h1{color:#80520d}h2{color:#684714;margin-top:32px}.lity-report-table{border-collapse:collapse;width:100%;background:white}.lity-report-table th,.lity-report-table td{border:1px solid #ddd6c9;padding:8px;text-align:left}.lity-report-table th{background:#f4ead8;color:#5f451a}.notice{border-left:4px solid #c88923;padding:10px 14px;background:#fff5df;color:#5b482b}footer{margin-top:40px;color:#766f65;font-size:12px}"
    ))),
    htmltools::tags$body(htmltools::tags$header(htmltools::tags$h1(title),
      htmltools::tags$p(paste("Generated", .lity_now()))), sections,
      htmltools::tags$p(class = "notice", "Research and teaching output. Independent statistical, operational, clinical, and ethical review remains required."),
      htmltools::tags$footer(paste("LibeRality", tryCatch(as.character(utils::packageVersion("LibeRality")), error = function(e) "0.1.0"),
                                   "| design hash", .lity_hash(design))))
  )
  htmltools::save_html(page, file = file, background = "white")
  invisible(normalizePath(file, winslash = "/", mustWork = TRUE))
}

