#' Define an optimisable design variable
#'
#' @param name Variable name.
#' @param target `sampling_time`, `dose`, `rate`, `duration`, `arm_size`,
#'   `allocation`, or `covariate`.
#' @param arm Target arm name.
#' @param index Observation/dose index when relevant.
#' @param lower,upper Bounds.
#' @param values Candidate values for discrete or categorical variables.
#' @param initial Initial value; inferred from the design when omitted.
#' @param type Continuous, integer, discrete, or categorical.
#' @param covariate Covariate column for a covariate variable.
#' @param metadata Additional metadata.
#' @export
lity_variable <- function(name, target = c("sampling_time", "dose", "rate", "duration",
                                           "arm_size", "allocation", "covariate"),
                          arm, index = 1L, lower = -Inf, upper = Inf, values = NULL,
                          initial = NULL, type = c("continuous", "integer", "discrete", "categorical"),
                          covariate = NULL, metadata = list()) {
  target <- match.arg(target)
  type <- match.arg(type)
  lower <- as.numeric(lower); upper <- as.numeric(upper)
  if (length(lower) != 1L || length(upper) != 1L || is.na(lower) || is.na(upper) || lower > upper) {
    .lity_stop("Variable bounds are invalid.")
  }
  if (type %in% c("discrete", "categorical")) {
    if (is.null(values) || !length(values)) .lity_stop("Discrete variables require candidate `values`.")
    if (type == "discrete") values <- as.numeric(values)
  }
  if (target == "covariate" && (is.null(covariate) || !nzchar(covariate))) .lity_stop("A covariate variable requires `covariate`.")
  structure(list(
    schema = "liberality.variable", version = 1L, name = .lity_scalar(name, "name"),
    target = target, arm = .lity_scalar(arm, "arm"), index = as.integer(index)[[1L]],
    lower = lower, upper = upper, values = values, initial = initial, type = type,
    covariate = covariate, metadata = metadata
  ), class = "lity_variable")
}

.lity_variable_current <- function(design, variable) {
  arm_key <- .lity_arm_keys(design, variable$arm)[[1L]]
  arm <- design$arms[[arm_key]]
  if (variable$target == "arm_size") return(arm$size)
  if (variable$target == "allocation") return(arm$allocation)
  if (variable$target == "sampling_time") {
    row <- which(arm$events$.LITY_OBS == variable$index)
    if (length(row) != 1L) .lity_stop("Sampling variable `", variable$name, "` has an invalid observation index.")
    return(arm$events$TIME[[row]])
  }
  if (variable$target %in% c("dose", "rate", "duration")) {
    row <- which(arm$events$.LITY_DOSE == variable$index)
    if (length(row) != 1L) .lity_stop("Dose variable `", variable$name, "` has an invalid dose index.")
    if (variable$target == "dose") return(arm$events$AMT[[row]])
    if (variable$target == "rate") return(arm$events$RATE[[row]])
    rate <- arm$events$RATE[[row]]
    return(if (is.finite(rate) && rate > 0) arm$events$AMT[[row]] / rate else 0)
  }
  if (variable$target == "covariate") {
    if (!variable$covariate %in% names(arm$events)) .lity_stop("Unknown covariate column `", variable$covariate, "`.")
    return(arm$events[[variable$covariate]][[1L]])
  }
  .lity_stop("Unsupported variable target.")
}

.lity_apply_variable <- function(design, variable, value) {
  arm_key <- .lity_arm_keys(design, variable$arm)[[1L]]
  arm <- design$arms[[arm_key]]
  if (variable$type == "integer") value <- round(as.numeric(value))
  if (variable$type == "discrete") value <- variable$values[[which.min(abs(as.numeric(variable$values) - as.numeric(value)))]]
  if (variable$type == "categorical" && !value %in% variable$values) value <- variable$values[[1L]]
  if (is.numeric(value)) value <- min(variable$upper, max(variable$lower, value))
  if (variable$target == "arm_size") arm$size <- as.integer(value)
  else if (variable$target == "allocation") arm$allocation <- as.numeric(value)
  else if (variable$target == "sampling_time") {
    row <- which(arm$events$.LITY_OBS == variable$index)
    arm$events$TIME[row] <- as.numeric(value)
  } else if (variable$target %in% c("dose", "rate", "duration")) {
    row <- which(arm$events$.LITY_DOSE == variable$index)
    if (variable$target == "dose") arm$events$AMT[row] <- as.numeric(value)
    if (variable$target == "rate") arm$events$RATE[row] <- as.numeric(value)
    if (variable$target == "duration") arm$events$RATE[row] <- if (value > 0) arm$events$AMT[row] / as.numeric(value) else 0
  } else if (variable$target == "covariate") arm$events[[variable$covariate]] <- value
  arm$events <- arm$events[order(arm$events$TIME, -arm$events$EVID, na.last = TRUE), , drop = FALSE]
  rownames(arm$events) <- NULL
  design$arms[[arm_key]] <- arm
  design
}

.lity_apply_values <- function(design, values) {
  if (length(values) != length(design$variables)) .lity_stop("Variable value vector has the wrong length.")
  for (i in seq_along(values)) design <- .lity_apply_variable(design, design$variables[[i]], values[[i]])
  design
}

.lity_design_cost <- function(design) {
  sum(vapply(design$arms, function(arm) {
    observations <- sum(arm$events$EVID == 0 & arm$events$MDV == 0)
    visits <- length(unique(arm$events$TIME[arm$events$EVID == 0 & arm$events$MDV == 0]))
    arm$costs$fixed + arm$size * arm$costs$per_subject +
      arm$size * visits * arm$costs$per_visit +
      arm$size * observations * (arm$costs$per_sample + arm$costs$assay)
  }, numeric(1)))
}

.lity_design_burden <- function(design, weights = list(subject = 1, visit = 1, sample = 1, volume = 1)) {
  weights <- utils::modifyList(list(subject = 1, visit = 1, sample = 1, volume = 1), weights)
  sum(vapply(design$arms, function(arm) {
    observations <- sum(arm$events$EVID == 0 & arm$events$MDV == 0)
    visits <- length(unique(arm$events$TIME[arm$events$EVID == 0 & arm$events$MDV == 0]))
    weights$subject * arm$size + weights$visit * arm$size * visits +
      weights$sample * arm$size * observations +
      weights$volume * arm$size * observations * arm$sample_volume
  }, numeric(1)))
}

#' Define a design constraint
#' @param name Constraint name.
#' @param type Constraint type.
#' @param limit Upper or lower limit, depending on `type`.
#' @param arm Optional arm.
#' @param endpoint Optional endpoint.
#' @param parameters Optional parameter selection for precision constraints.
#' @param lower,upper Optional interval bounds.
#' @param function_value Custom function accepting a design and returning a scalar.
#' @param metadata Additional metadata.
#' @export
lity_constraint <- function(name, type = c("min_separation", "max_samples", "total_subjects",
                                           "total_cost", "max_blood_volume", "max_duration",
                                           "arm_size", "allocation", "max_rse", "minimum_power",
                                           "exposure", "custom"), limit, arm = NULL,
                            endpoint = NULL, parameters = NULL, lower = NULL, upper = NULL,
                            function_value = NULL, metadata = list()) {
  type <- match.arg(type)
  if (type == "custom" && !is.function(function_value)) .lity_stop("Custom constraints require `function_value`.")
  structure(list(
    schema = "liberality.constraint", version = 1L,
    name = .lity_scalar(name, "name"), type = type,
    limit = .lity_number(limit, "limit"), arm = arm, endpoint = endpoint,
    parameters = parameters, lower = lower, upper = upper,
    function_value = function_value, metadata = metadata
  ), class = "lity_constraint")
}

#' @export
print.lity_constraint <- function(x, ...) {
  cat("LibeRality constraint:", x$name, "[", x$type, "] limit", x$limit, "\n")
  invisible(x)
}

.lity_constraint_one <- function(design, constraint, evaluation = NULL) {
  arms <- design$arms[.lity_arm_keys(design, constraint$arm)]
  value <- switch(constraint$type,
    min_separation = {
      differences <- unlist(lapply(arms, function(arm) {
        times <- sort(arm$events$TIME[arm$events$EVID == 0 & arm$events$MDV == 0])
        if (length(times) < 2L) Inf else diff(times)
      }))
      min(differences)
    },
    max_samples = max(vapply(arms, function(arm) sum(arm$events$EVID == 0 & arm$events$MDV == 0), numeric(1))),
    total_subjects = sum(vapply(design$arms, `[[`, numeric(1), "size")),
    total_cost = .lity_design_cost(design),
    max_blood_volume = max(vapply(arms, function(arm) arm$sample_volume * sum(arm$events$EVID == 0 & arm$events$MDV == 0), numeric(1))),
    max_duration = max(vapply(arms, function(arm) diff(range(arm$events$TIME)), numeric(1))),
    arm_size = if (length(arms) == 1L) arms[[1L]]$size else sum(vapply(arms, `[[`, numeric(1), "size")),
    allocation = if (length(arms) == 1L) arms[[1L]]$allocation else sum(vapply(arms, `[[`, numeric(1), "allocation")),
    max_rse = {
      if (is.null(evaluation)) {
        evaluation <- lity_evaluate(
          design,
          lity_criterion_rse(parameters = constraint$parameters, summary = "max")
        )
      }
      available <- rownames(evaluation$information[[1L]]$matrix)
      selected <- .lity_match_parameters(constraint$parameters, available)
      scenario_rse <- vapply(evaluation$information, function(info) {
        values <- info$rse[selected]
        if (all(!is.finite(values))) Inf else max(values, na.rm = TRUE)
      }, numeric(1))
      max(scenario_rse)
    },
    minimum_power = {
      if (is.null(evaluation)) .lity_stop("A minimum-power constraint requires an evaluation containing a power criterion.")
      power <- evaluation$criteria$value[evaluation$criteria$type %in% c("power", "superiority", "noninferiority")]
      if (!length(power)) .lity_stop("Evaluation has no power criterion.")
      min(power)
    },
    exposure = {
      if (is.null(evaluation)) .lity_stop("An exposure constraint requires an evaluation.")
      target <- evaluation$criteria$value[evaluation$criteria$type == "target_attainment"]
      if (!length(target)) .lity_stop("Evaluation has no target-attainment result.")
      min(target)
    },
    custom = as.numeric(constraint$function_value(design))[[1L]],
    .lity_stop("Unsupported constraint type.")
  )
  lower_types <- c("min_separation", "minimum_power", "exposure")
  violation <- if (!is.null(constraint$lower) || !is.null(constraint$upper)) {
    lower <- as.numeric(constraint$lower %||% -Inf)[[1L]]
    upper <- as.numeric(constraint$upper %||% Inf)[[1L]]
    max(0, lower - value) + max(0, value - upper)
  } else if (constraint$type %in% lower_types) {
    max(0, constraint$limit - value)
  } else {
    max(0, value - constraint$limit)
  }
  data.frame(name = constraint$name, type = constraint$type, value = value,
             limit = constraint$limit, violation = violation, feasible = violation <= 1e-10,
             stringsAsFactors = FALSE)
}

#' Evaluate all design constraints
#' @param design Design object.
#' @param evaluation Optional cached design evaluation.
#' @export
lity_constraint_check <- function(design, evaluation = NULL) {
  if (!inherits(design, "lity_design")) .lity_stop("`design` must be a LibeRality design.")
  if (!length(design$constraints)) return(data.frame(
    name = character(), type = character(), value = numeric(), limit = numeric(),
    violation = numeric(), feasible = logical(), stringsAsFactors = FALSE
  ))
  do.call(rbind, lapply(design$constraints, function(constraint) {
    .lity_constraint_one(design, constraint, evaluation)
  }))
}
