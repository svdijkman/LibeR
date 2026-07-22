.lity_parameter_spec <- function(model) {
  theta <- model$THETAS
  omega <- model$OMEGAS
  sigma <- model$SIGMAS
  parts <- list()
  if (nrow(theta)) parts[[length(parts) + 1L]] <- data.frame(
    name = paste0("THETA", theta$THETA), type = "theta", index = seq_len(nrow(theta)),
    row = theta$THETA, col = theta$THETA, value = theta$Value,
    fixed = theta$FIX, stringsAsFactors = FALSE
  )
  if (nrow(omega)) parts[[length(parts) + 1L]] <- data.frame(
    name = paste0("OMEGA_", omega$ROW, "_", omega$COL), type = "omega",
    index = seq_len(nrow(omega)), row = omega$ROW, col = omega$COL,
    value = omega$Value, fixed = omega$FIX, stringsAsFactors = FALSE
  )
  if (nrow(sigma)) parts[[length(parts) + 1L]] <- data.frame(
    name = paste0("SIGMA", sigma$SIGMA), type = "sigma", index = seq_len(nrow(sigma)),
    row = sigma$SIGMA, col = sigma$SIGMA, value = sigma$Value,
    fixed = sigma$FIX, stringsAsFactors = FALSE
  )
  result <- if (length(parts)) do.call(rbind, parts) else data.frame(
    name = character(), type = character(), index = integer(), row = integer(),
    col = integer(), value = numeric(), fixed = logical(), stringsAsFactors = FALSE
  )
  result[!result$fixed, , drop = FALSE]
}

.lity_omega_matrix <- function(model, values = model$OMEGAS$Value) {
  n_eta <- as.integer(model$n_eta %||% 0L)
  result <- matrix(0, n_eta, n_eta)
  if (!n_eta || !nrow(model$OMEGAS)) return(result)
  for (i in seq_len(nrow(model$OMEGAS))) {
    row <- model$OMEGAS$ROW[[i]]; col <- model$OMEGAS$COL[[i]]
    result[row, col] <- result[col, row] <- values[[i]]
  }
  result
}

.lity_sigma_variance <- function(value, model) {
  if (identical(model$LIK_CONFIG$sigma_parameterization, "variance")) value else value^2
}

.lity_residual_variance <- function(model, prediction, sigma, dvid = 1L) {
  error <- model$LIK_CONFIG$error %||% model$ERROR_TYPE %||% "none"
  if (error == "auto") error <- model$ERROR_TYPE
  if (error == "none" || !length(sigma)) return(rep(1e-12, length(prediction)))
  per_response <- if (error %in% c("combined", "power")) 2L else 1L
  dvid <- pmax(1L, as.integer(dvid))
  result <- numeric(length(prediction))
  for (i in seq_along(prediction)) {
    offset <- (dvid[[i]] - 1L) * per_response + 1L
    if (offset + per_response - 1L > length(sigma)) offset <- 1L
    first <- .lity_sigma_variance(sigma[[offset]], model)
    mu <- prediction[[i]]
    result[[i]] <- switch(error,
      additive = first,
      exponential = first,
      proportional = first * mu^2,
      combined = first * mu^2 + .lity_sigma_variance(sigma[[offset + 1L]], model),
      power = first * max(abs(mu), 1e-12)^(2 * sigma[[offset + 1L]]),
      first
    )
  }
  pmax(result, 1e-16)
}

.lity_residual_covariance <- function(model, prediction, sigma, data) {
  variance <- .lity_residual_variance(model, prediction, sigma, data$DVID %||% rep(1L, length(prediction)))
  covariance <- diag(variance, length(variance))
  if (identical(model$LIK_CONFIG$sigma_corr, "ar1") && length(variance) > 1L) {
    rho <- model$LIK_CONFIG$ar1_rho
    time <- as.numeric(data$TIME)
    dvid <- as.integer(data$DVID %||% rep(1L, nrow(data)))
    correlation <- outer(time, time, function(a, b) rho^abs(a - b))
    correlation[outer(dvid, dvid, `!=`)] <- 0
    diag(correlation) <- 1
    covariance <- correlation * outer(sqrt(variance), sqrt(variance))
  }
  covariance
}

.lity_link <- function(value, link, inverse = TRUE) {
  if (!inverse) return(switch(link,
    logit = log(value / (1 - value)), probit = stats::qnorm(value),
    cloglog = log(-log(1 - value)), log = log(value), identity = value,
    .lity_stop("Unsupported link: ", link, ".")
  ))
  switch(link,
    logit = stats::plogis(value), probit = stats::pnorm(value),
    cloglog = 1 - exp(-exp(value)), log = exp(value), identity = value,
    .lity_stop("Unsupported link: ", link, ".")
  )
}

.lity_link_derivative <- function(value, link, scale) {
  if (scale == "response") return(rep(1, length(value)))
  switch(link,
    logit = { p <- stats::plogis(value); p * (1 - p) },
    probit = stats::dnorm(value),
    cloglog = exp(value - exp(value)),
    log = exp(value), identity = rep(1, length(value)),
    .lity_stop("Unsupported link: ", link, ".")
  )
}

.lity_response_moments <- function(mu, H, G, endpoint, time) {
  if (endpoint$type == "continuous") return(list(mean = mu, H = H, G = G, variance = NULL))
  if (endpoint$type == "ordinal") {
    thresholds <- endpoint$thresholds
    category_moments <- function(eta) {
      cumulative <- if (endpoint$link == "probit") stats::pnorm(thresholds - eta) else stats::plogis(thresholds - eta)
      probability <- diff(c(0, cumulative, 1))
      categories <- seq_along(probability) - 1
      c(mean = sum(categories * probability), variance = sum((categories - sum(categories * probability))^2 * probability))
    }
    moments <- t(vapply(mu, category_moments, numeric(2)))
    step <- pmax(1e-6, abs(mu) * 1e-6)
    derivative <- vapply(seq_along(mu), function(i) {
      (category_moments(mu[[i]] + step[[i]])[[1L]] - category_moments(mu[[i]] - step[[i]])[[1L]]) / (2 * step[[i]])
    }, numeric(1))
    return(list(mean = moments[, "mean"], H = derivative * H, G = derivative * G,
                variance = pmax(moments[, "variance"], 1e-10)))
  }
  response <- if (endpoint$scale == "response") mu else .lity_link(mu, endpoint$link)
  derivative <- .lity_link_derivative(mu, endpoint$link, endpoint$scale)
  if (endpoint$type == "binary") {
    response <- pmin(1 - 1e-9, pmax(1e-9, response)); variance <- response * (1 - response)
  } else if (endpoint$type == "count") {
    response <- pmax(response, 1e-9)
    variance <- if (endpoint$distribution %in% c("negative_binomial", "negbin")) {
      response + response^2 / (endpoint$dispersion %||% 1)
    } else response
  } else {
    hazard <- pmax(response, 1e-12)
    ordering <- order(time)
    delta <- numeric(length(time))
    sorted <- time[ordering]
    delta[ordering] <- c(diff(sorted), if (length(sorted) > 1L) stats::median(diff(sorted)) else 1)
    delta <- pmax(delta, 1e-8)
    response <- hazard * delta
    derivative <- derivative * delta
    variance <- response
  }
  list(mean = response, H = derivative * H, G = derivative * G, variance = pmax(variance, 1e-12))
}

.lity_numerical_matrix_derivative <- function(fn, value, index, relative_step = 1e-5) {
  step <- max(1e-7, abs(value[[index]]) * relative_step)
  plus <- minus <- value
  plus[[index]] <- plus[[index]] + step
  minus[[index]] <- minus[[index]] - step
  (fn(plus) - fn(minus)) / (2 * step)
}

.lity_prediction_parts <- function(model, events, theta, sigma, endpoint) {
  derivative <- LibeRation::nm_prediction_derivatives(model, events, theta = theta, sigma = sigma)
  observed <- which(events$EVID == 0 & events$MDV == 0 & as.integer(events$DVID) == endpoint$dvid)
  if (!length(observed)) return(NULL)
  jacobian <- derivative$jacobian
  theta_columns <- match(paste0("THETA_", seq_along(theta)), colnames(jacobian))
  H <- if (length(theta)) jacobian[observed, theta_columns, drop = FALSE] else matrix(0, length(observed), 0L)
  eta_pattern <- "^ETA_1_[0-9]+$"
  eta_columns <- grep(eta_pattern, colnames(jacobian))
  if (model$n_eta && length(eta_columns) != model$n_eta) {
    eta_columns <- grep("^ETA_[0-9]+$", colnames(jacobian))
  }
  G <- if (model$n_eta) jacobian[observed, eta_columns[seq_len(model$n_eta)], drop = FALSE] else matrix(0, length(observed), 0L)
  list(mu = as.numeric(derivative$value[observed]), H = H, G = G,
       data = events[observed, , drop = FALSE], diagnostics = list(
         propagation_kernel = derivative$propagation_kernel %||% "unknown",
         operation_count = derivative$operation_count %||% NA_integer_
       ))
}

.lity_endpoint_information <- function(model, events, endpoint, theta, omega, sigma,
                                       parameter_spec, tolerance,
                                       approximation = c("full_gaussian", "fo_block")) {
  approximation <- match.arg(approximation)
  prediction <- .lity_prediction_parts(model, events, theta, sigma, endpoint)
  if (is.null(prediction)) return(NULL)
  mu_original <- prediction$mu
  H_original <- prediction$H
  G_original <- prediction$G
  time <- as.numeric(prediction$data$TIME)
  exponential <- endpoint$type == "continuous" && identical(model$LIK_CONFIG$error, "exponential")
  if (exponential) {
    safe <- pmax(mu_original, 1e-12)
    mu <- log(safe); H <- H_original / safe; G <- G_original / safe
  } else {
    mu <- mu_original; H <- H_original; G <- G_original
  }
  moments <- .lity_response_moments(mu, H, G, endpoint, time)
  H <- moments$H; G <- moments$G
  omega_matrix <- .lity_omega_matrix(model, omega)
  if (endpoint$type == "continuous") {
    residual <- if (exponential) {
      temporary <- model; temporary$LIK_CONFIG$error <- "additive"
      .lity_residual_covariance(temporary, mu_original, sigma, prediction$data)
    } else .lity_residual_covariance(model, mu_original, sigma, prediction$data)
  } else residual <- diag(moments$variance, length(moments$variance))
  V <- if (ncol(G)) G %*% omega_matrix %*% t(G) + residual else residual
  k <- nrow(parameter_spec)
  Dmu <- matrix(0, nrow(H), k)
  theta_rows <- which(parameter_spec$type == "theta")
  if (length(theta_rows)) Dmu[, theta_rows] <- H[, parameter_spec$index[theta_rows], drop = FALSE]
  dV <- replicate(k, matrix(0, nrow(V), ncol(V)), simplify = FALSE)
  for (position in theta_rows) {
    theta_index <- parameter_spec$index[[position]]
    direction <- H_original[, theta_index]
    step <- max(1e-7, abs(theta[[theta_index]]) * 1e-5)
    plus_mu <- mu_original + direction * step
    minus_mu <- mu_original - direction * step
    if (endpoint$type == "continuous") {
      plus_r <- if (exponential) {
        temporary <- model; temporary$LIK_CONFIG$error <- "additive"
        .lity_residual_covariance(temporary, plus_mu, sigma, prediction$data)
      } else .lity_residual_covariance(model, plus_mu, sigma, prediction$data)
      minus_r <- if (exponential) {
        temporary <- model; temporary$LIK_CONFIG$error <- "additive"
        .lity_residual_covariance(temporary, minus_mu, sigma, prediction$data)
      } else .lity_residual_covariance(model, minus_mu, sigma, prediction$data)
      dV[[position]] <- (plus_r - minus_r) / (2 * step)
    } else {
      plus <- .lity_response_moments(if (exponential) log(pmax(plus_mu, 1e-12)) else plus_mu,
                                     H, G, endpoint, time)$variance
      minus <- .lity_response_moments(if (exponential) log(pmax(minus_mu, 1e-12)) else minus_mu,
                                      H, G, endpoint, time)$variance
      dV[[position]] <- diag((plus - minus) / (2 * step), length(plus))
    }
  }
  omega_rows <- which(parameter_spec$type == "omega")
  for (position in omega_rows) {
    derivative_omega <- matrix(0, model$n_eta, model$n_eta)
    row <- parameter_spec$row[[position]]; col <- parameter_spec$col[[position]]
    derivative_omega[row, col] <- 1
    derivative_omega[col, row] <- 1
    dV[[position]] <- G %*% derivative_omega %*% t(G)
  }
  sigma_rows <- which(parameter_spec$type == "sigma")
  if (endpoint$type == "continuous" && length(sigma_rows)) {
    for (position in sigma_rows) {
      sigma_index <- parameter_spec$index[[position]]
      dV[[position]] <- .lity_numerical_matrix_derivative(function(candidate) {
        if (exponential) {
          temporary <- model; temporary$LIK_CONFIG$error <- "additive"
          .lity_residual_covariance(temporary, mu_original, candidate, prediction$data)
        } else .lity_residual_covariance(model, mu_original, candidate, prediction$data)
      }, sigma, sigma_index)
    }
  }
  # PopED and PFIM use the conventional block-diagonal population-FO FIM:
  # fixed effects contribute through the mean and variance parameters through
  # the observation covariance, with the cross block set to zero.  Retain the
  # fuller Gaussian covariance-derivative form as LibeRality's default, but
  # expose this convention explicitly for interoperable validation.
  if (identical(approximation, "fo_block") && length(theta_rows)) {
    dV[theta_rows] <- replicate(length(theta_rows), matrix(0, nrow(V), ncol(V)), simplify = FALSE)
  }
  assembled <- lity_fim_cpp(Dmu, V, dV, tolerance)
  list(information = assembled$information, covariance = V,
       prediction = moments$mean, mean_jacobian = Dmu,
       observation_covariance_rank = assembled$observation_covariance_rank,
       diagnostics = prediction$diagnostics)
}

.lity_strata_for_arm <- function(population, arm) {
  strata <- population$strata
  if (arm$population %in% strata$name && !(arm$population == "default" && nrow(strata) > 1L)) {
    strata <- strata[strata$name == arm$population, , drop = FALSE]
    strata$weight <- 1
  }
  strata
}

#' Calculate expected information for a design
#'
#' Continuous outcomes use the multivariate-normal population FIM, including
#' mean/covariance cross-information and exact LibeRation prediction
#' sensitivities. Non-continuous outcomes use distribution-aware working
#' moments, allowing shared random effects and variance-component information.
#'
#' @param design LibeRality design.
#' @param scenario Scenario name, index, or object.
#' @param model Optional model override.
#' @param tolerance Numerical rank tolerance.
#' @param approximation Information approximation. `"full_gaussian"` includes
#'   covariance derivatives for fixed effects; `"fo_block"` uses the
#'   conventional block-diagonal population-FO form used by PopED and PFIM.
#' @return A `lity_information` object.
#' @export
lity_information <- function(design, scenario = 1L, model = NULL, tolerance = 1e-10,
                             approximation = c("full_gaussian", "fo_block")) {
  approximation <- match.arg(approximation)
  validation <- lity_validate(design)
  if (!validation$valid) .lity_stop("Invalid design: ", paste(validation$errors, collapse = "; "))
  if (inherits(scenario, "lity_scenario")) selected <- scenario
  else if (is.character(scenario)) selected <- design$scenarios[[scenario]]
  else selected <- design$scenarios[[as.integer(scenario)]]
  if (is.null(selected)) .lity_stop("Unknown design scenario.")
  model <- model %||% selected$model %||% design$model
  theta <- selected$theta %||% model$THETAS$Value
  omega <- selected$omega %||% model$OMEGAS$Value
  sigma <- selected$sigma %||% model$SIGMAS$Value
  if (length(theta) != nrow(model$THETAS) || length(omega) != nrow(model$OMEGAS) || length(sigma) != nrow(model$SIGMAS)) {
    .lity_stop("Scenario parameter dimensions do not match the selected model.")
  }
  parameters <- .lity_parameter_spec(model)
  total <- matrix(0, nrow(parameters), nrow(parameters), dimnames = list(parameters$name, parameters$name))
  arm_contributions <- list(); kernels <- character(); operation_count <- 0
  for (arm_name in names(design$arms)) {
    arm <- design$arms[[arm_name]]
    arm_total <- matrix(0, nrow(parameters), nrow(parameters), dimnames = dimnames(total))
    strata <- .lity_strata_for_arm(design$population, arm)
    for (stratum_index in seq_len(nrow(strata))) {
      events <- arm$events
      covariate_names <- setdiff(names(strata), c("name", "weight"))
      for (name in covariate_names) events[[name]] <- strata[[name]][[stratum_index]]
      for (name in names(selected$covariates)) events[[name]] <- selected$covariates[[name]]
      for (endpoint in design$endpoints) {
        contribution <- .lity_endpoint_information(
          model, events, endpoint, theta, omega, sigma, parameters, tolerance,
          approximation = approximation
        )
        if (is.null(contribution)) next
        effective <- arm$size * strata$weight[[stratum_index]] * selected$adherence *
          (1 - selected$dropout) * (1 - selected$missed_sample)
        arm_total <- arm_total + effective * contribution$information
        kernels <- c(kernels, contribution$diagnostics$propagation_kernel)
        operation_count <- operation_count + (contribution$diagnostics$operation_count %||% 0)
      }
    }
    arm_contributions[[arm_name]] <- arm_total
    total <- total + arm_total
  }
  if (!is.null(design$prior_fim)) {
    prior <- design$prior_fim
    if (!is.null(rownames(prior))) {
      aligned <- matrix(0, nrow(total), ncol(total), dimnames = dimnames(total))
      common <- intersect(rownames(prior), rownames(total))
      aligned[common, common] <- prior[common, common, drop = FALSE]
      prior <- aligned
    }
    if (!all(dim(prior) == dim(total))) .lity_stop("Prior FIM dimension does not match estimated parameters.")
    total <- total + prior
  }
  metrics <- lity_matrix_metrics_cpp(total, tolerance)
  covariance <- metrics$covariance
  dimnames(covariance) <- dimnames(total)
  values <- parameters$value
  se <- sqrt(pmax(diag(covariance), 0))
  rse <- ifelse(abs(values) > 1e-15, 100 * se / abs(values), NA_real_)
  names(se) <- names(rse) <- parameters$name
  structure(list(
    schema = "liberality.information", version = 1L,
    design_id = design$id, scenario = selected$name, model_hash = .lity_hash(model),
    matrix = total, covariance = covariance, parameters = parameters,
    se = se, rse = rse, eigenvalues = metrics$eigenvalues,
    rank = metrics$rank, condition_number = metrics$condition_number,
    log_determinant = metrics$log_determinant,
    trace_covariance = metrics$trace_covariance,
    minimum_eigenvalue = metrics$minimum_eigenvalue,
    arm_contributions = arm_contributions,
    diagnostics = list(
      method = if (identical(approximation, "fo_block")) {
        "block-diagonal population-FO expected information (PopED/PFIM convention)"
      } else "full Gaussian expected information",
      approximation = approximation,
      prediction_derivatives = "exact CppAD",
      covariance_derivatives = "analytic OMEGA; exact residual form with centred parameter derivatives",
      noncontinuous = "distribution-aware working-moment information",
      endpoint_blocks = "block diagonal conditional on shared parameter vector",
      propagation_kernels = sort(unique(kernels)), operation_count = operation_count,
      tolerance = tolerance, warnings = validation$warnings
    ), created_at = .lity_now()
  ), class = "lity_information")
}

#' @export
print.lity_information <- function(x, ...) {
  cat("LibeRality information\n")
  cat("  scenario:", x$scenario, " rank:", x$rank, "/", nrow(x$matrix),
      " condition:", format(x$condition_number, digits = 4), "\n")
  cat("  log determinant:", format(x$log_determinant, digits = 6), "\n")
  invisible(x)
}
