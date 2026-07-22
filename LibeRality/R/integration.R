#' Import a reviewed LibeRary model
#' @param library_id Catalogue identifier.
#' @param root Optional catalogue root.
#' @param allow_draft Permit a draft entry.
#' @export
lity_model_from_liberary <- function(library_id, root = NULL, allow_draft = FALSE) {
  if (!requireNamespace("LibeRary", quietly = TRUE)) .lity_stop("Install LibeRary to import catalogue models.")
  arguments <- list(library_id)
  if (!is.null(root)) arguments$root <- root
  entry <- do.call(LibeRary::library_get, arguments)
  if (!isTRUE(entry$validation$valid)) .lity_stop("LibeRary entry validation failed: ", paste(entry$validation$errors, collapse = "; "))
  if (!allow_draft && !entry$status %in% c("review", "reviewed", "published", "qualified")) {
    .lity_stop("LibeRary entry is not reviewed; set `allow_draft = TRUE` for exploratory work.")
  }
  control <- do.call(LibeRary::library_model, arguments)
  parsed <- LibeRation::nm_control_read(control, strict = TRUE)
  model <- parsed$model %||% parsed
  attr(model, "library_provenance") <- list(library_id = library_id, status = entry$status,
                                             imported_at = .lity_now(), hash = .lity_hash(entry))
  model
}

#' Export a final design to LibeRation
#' @param design Design or optimisation result.
#' @param simulate Generate a stochastic dataset instead of event templates.
#' @param seed Simulation seed.
#' @param workspace Optional LibeRation workspace.
#' @param project Optional project id/name. A project and first model version
#'   are created when both workspace and project are supplied.
#' @return Dataset or project metadata.
#' @export
lity_to_liberation <- function(design, simulate = FALSE, seed = 7301L,
                               workspace = NULL, project = NULL) {
  if (inherits(design, "lity_optimisation")) design <- design$design
  if (!inherits(design, "lity_design")) .lity_stop("`design` must be a design or optimisation result.")
  dataset <- if (simulate) {
    lity_simulate_trials(design, n = 1L, seed = seed, retain_data = TRUE)$data[[1L]]
  } else {
    pieces <- lapply(names(design$arms), function(name) {
      data <- .lity_expand_arm(design$arms[[name]]); data$ARM <- name; data
    })
    offsets <- cumsum(c(0L, utils::head(vapply(pieces, function(data) length(unique(data$ID)), integer(1)), -1L)))
    for (i in seq_along(pieces)) pieces[[i]]$ID <- pieces[[i]]$ID + offsets[[i]]
    do.call(rbind, pieces)
  }
  if (is.null(workspace) || is.null(project)) return(dataset)
  existing <- LibeRation::nm_project_list(workspace)
  if (project %in% existing$id) project_id <- project else {
    created <- LibeRation::nm_project_create(workspace, project,
      description = paste("Optimised design imported from LibeRality", design$id))
    project_id <- created$id
  }
  version <- LibeRation::nm_project_save(
    workspace, project_id, model = design$model, data = dataset,
    label = "Design001", provenance = list(
      source = "LibeRality", design_id = design$id, design_hash = .lity_hash(design),
      LibeRality = tryCatch(as.character(utils::packageVersion("LibeRality")), error = function(e) "0.1.0")
    )
  )
  list(project = project_id, version = version, data = dataset)
}

#' Create a typed LibeRties optimal-design job
#' @param design Serializable design.
#' @param criterion Criterion.
#' @param operation Evaluate, optimise, simulate, or Pareto exploration.
#' @param arguments Additional operation arguments.
#' @param label Job label.
#' @export
lity_job <- function(design, criterion = lity_criterion_D(),
                     operation = c("optimise", "evaluate", "simulate", "pareto"),
                     arguments = list(), label = NULL) {
  if (!requireNamespace("LibeRties", quietly = TRUE)) .lity_stop("Install LibeRties to create queue jobs.")
  operation <- match.arg(operation)
  if (!inherits(design, "lity_design")) .lity_stop("`design` must be a LibeRality design.")
  if (!inherits(criterion, "lity_criterion")) .lity_stop("`criterion` must be a LibeRality criterion.")
  arguments <- c(list(operation = operation, criterion = criterion), arguments)
  LibeRties::ls_job("optimal_design", model = design$model, data = design,
                    arguments = arguments, label = label %||% paste(operation, design$name))
}

#' Execute a typed LibeRality worker task
#' @param model Serialized primary model retained by the queue contract.
#' @param design Serialized design.
#' @param arguments Worker arguments.
#' @export
lity_worker_task <- function(model, design, arguments = list()) {
  design <- .lity_restore_object(design)
  arguments <- .lity_restore_object(arguments)
  if (!inherits(design, "lity_design") || !inherits(model, "nm_model")) .lity_stop("Invalid optimal-design worker payload.")
  design$model <- model
  operation <- arguments$operation %||% "optimise"
  criterion <- arguments$criterion %||% lity_criterion_D()
  arguments$operation <- arguments$criterion <- NULL
  switch(operation,
    evaluate = do.call(lity_evaluate, c(list(design = design, criteria = criterion), arguments)),
    optimise = do.call(lity_optimise, c(list(design = design, criterion = criterion), arguments)),
    simulate = do.call(lity_simulate_trials, c(list(design = design), arguments)),
    pareto = do.call(lity_pareto, c(list(design = design, criterion = criterion), arguments)),
    .lity_stop("Unsupported optimal-design operation: ", operation, ".")
  )
}
