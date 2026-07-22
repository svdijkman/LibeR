`%||%` <- function(x, y) if (is.null(x)) y else x

.lity_stop <- function(..., call. = FALSE) stop(..., call. = call.)

.lity_now <- function() format(Sys.time(), "%Y-%m-%dT%H:%M:%OS3Z", tz = "UTC")

.lity_id <- function(prefix = "lity") {
  paste0(prefix, "-", format(Sys.time(), "%Y%m%d%H%M%OS3", tz = "UTC"), "-",
         sprintf("%08x", sample.int(.Machine$integer.max, 1L)))
}

.lity_scalar <- function(x, name, allow_empty = FALSE) {
  x <- trimws(as.character(x))
  if (length(x) != 1L || is.na(x) || (!allow_empty && !nzchar(x))) {
    .lity_stop("`", name, "` must be one ", if (!allow_empty) "non-empty " else "", "character value.")
  }
  x
}

.lity_number <- function(x, name, finite = TRUE, lower = -Inf, upper = Inf) {
  x <- as.numeric(x)
  if (length(x) != 1L || is.na(x) || (finite && !is.finite(x)) || x < lower || x > upper) {
    .lity_stop("`", name, "` is outside its permitted numeric range.")
  }
  x
}

.lity_probability <- function(x, name = "probability") {
  .lity_number(x, name, lower = 0, upper = 1)
}

.lity_named_list <- function(x, name, class = NULL) {
  if (is.null(x)) return(list())
  if (!is.list(x)) .lity_stop("`", name, "` must be a list.")
  if (!is.null(class) && any(!vapply(x, inherits, logical(1), class))) {
    .lity_stop("Every element of `", name, "` must inherit from `", class, "`.")
  }
  if (length(x) && (is.null(names(x)) || any(!nzchar(names(x))))) {
    names(x) <- vapply(seq_along(x), function(i) {
      value <- x[[i]]$name %||% x[[i]]$id %||% paste0(name, "-", i)
      as.character(value)[[1L]]
    }, character(1))
  }
  x
}

.lity_normalize_weights <- function(weights, name = "weights") {
  weights <- as.numeric(weights)
  if (!length(weights) || any(!is.finite(weights)) || any(weights < 0) || sum(weights) <= 0) {
    .lity_stop("`", name, "` must contain non-negative finite values with a positive sum.")
  }
  weights / sum(weights)
}

.lity_hash <- function(x) digest::digest(x, algo = "sha256", serialize = TRUE)

.lity_rows <- function(x) {
  if (!is.data.frame(x) || !nrow(x)) return(list())
  unname(lapply(seq_len(nrow(x)), function(i) as.list(x[i, , drop = FALSE])))
}

.lity_safe_inverse <- function(matrix, tolerance = 1e-10) {
  matrix <- (as.matrix(matrix) + t(as.matrix(matrix))) / 2
  if (!nrow(matrix)) return(matrix)
  eig <- eigen(matrix, symmetric = TRUE)
  threshold <- max(abs(eig$values), 1) * tolerance
  inverse_values <- ifelse(eig$values > threshold, 1 / eig$values, 0)
  inverse <- eig$vectors %*% (inverse_values * t(eig$vectors))
  dimnames(inverse) <- dimnames(matrix)
  attr(inverse, "rank") <- sum(eig$values > threshold)
  attr(inverse, "eigenvalues") <- eig$values
  inverse
}

.lity_match_parameters <- function(requested, available, allow_empty = FALSE) {
  if (is.null(requested)) return(seq_along(available))
  if (is.numeric(requested)) {
    index <- as.integer(requested)
  } else {
    index <- match(toupper(gsub("_", "", requested)), toupper(gsub("_", "", available)))
  }
  if (anyNA(index) || any(index < 1L) || any(index > length(available))) {
    .lity_stop("Unknown parameter selection: ", paste(requested[is.na(index) | index < 1L | index > length(available)], collapse = ", "), ".")
  }
  if (!allow_empty && !length(index)) .lity_stop("At least one parameter must be selected.")
  unique(index)
}

.lity_arm_keys <- function(design, arms) {
  if (is.null(arms)) return(names(design$arms))
  arms <- as.character(arms)
  keys <- vapply(arms, function(arm) {
    if (arm %in% names(design$arms)) return(arm)
    display <- vapply(design$arms, `[[`, character(1), "name")
    index <- match(arm, display)
    if (is.na(index)) .lity_stop("Unknown design arm `", arm, "`.")
    names(design$arms)[[index]]
  }, character(1))
  unname(keys)
}

.lity_seed <- function(seed) {
  if (is.null(seed)) return(NULL)
  seed <- as.integer(seed)
  if (length(seed) != 1L || is.na(seed)) .lity_stop("`seed` must be one integer.")
  set.seed(seed)
  seed
}

.lity_restore_object <- function(x) {
  if (!is.list(x) || is.data.frame(x)) return(x)
  x <- lapply(x, .lity_restore_object)
  schema <- as.character(x$schema %||% "")
  classes <- switch(schema,
    "liberality.design" = "lity_design",
    "liberality.arm" = "lity_arm",
    "liberality.endpoint" = "lity_endpoint",
    "liberality.population" = "lity_population",
    "liberality.scenario" = "lity_scenario",
    "liberality.variable" = "lity_variable",
    "liberality.constraint" = "lity_constraint",
    "liberality.criterion" = "lity_criterion",
    "liberality.information" = "lity_information",
    "liberality.evaluation" = "lity_evaluation",
    "liberality.optimisation" = "lity_optimisation",
    "liberality.pareto" = c("lity_pareto", "lity_optimisation"),
    "liberality.simulation" = "lity_simulation",
    NULL
  )
  if (!is.null(classes)) class(x) <- classes
  if (is.null(classes) && all(c("ADVAN", "PRED", "THETAS") %in% names(x))) class(x) <- "nm_model"
  x
}

#' Restore a LibeRality object from its semantic contract
#'
#' Remote JSON transport deliberately discards arbitrary R attributes. This
#' function rebuilds LibeRality classes exclusively from validated
#' `liberality.*` schema identifiers, including classes nested inside results.
#'
#' @param x A list decoded from a LibeRality wire result.
#' @return The recursively reconstructed LibeRality object.
#' @export
lity_contract_restore <- function(x) {
  restored <- .lity_restore_object(x)
  schema <- if (is.list(restored)) as.character(restored$schema %||% "") else ""
  if (!grepl("^liberality\\.", schema)) {
    .lity_stop("`x` is not a LibeRality semantic contract.")
  }
  restored
}
