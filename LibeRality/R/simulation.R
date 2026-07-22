.lity_expand_arm <- function(arm) {
  pieces <- lapply(seq_len(arm$size), function(id) {
    data <- arm$events; data$ID <- id; data
  })
  if (!length(pieces)) return(arm$events[0, , drop = FALSE])
  do.call(rbind, pieces)
}

.lity_simulate_noncontinuous <- function(data, endpoints) {
  for (endpoint in endpoints) {
    rows <- data$EVID == 0 & data$MDV == 0 & data$DVID == endpoint$dvid
    if (!any(rows) || endpoint$type == "continuous") next
    mu <- data$IPRED[rows]
    response <- if (endpoint$scale == "response") mu else .lity_link(mu, endpoint$link)
    if (endpoint$type == "binary") data$DV[rows] <- stats::rbinom(sum(rows), 1L, pmin(1, pmax(0, response)))
    else if (endpoint$type == "count" || endpoint$type == "recurrent_event") {
      response <- pmax(response, 1e-10)
      data$DV[rows] <- if (endpoint$distribution %in% c("negative_binomial", "negbin")) {
        stats::rnbinom(sum(rows), mu = response, size = endpoint$dispersion %||% 1)
      } else stats::rpois(sum(rows), response)
    } else if (endpoint$type == "ordinal") {
      thresholds <- endpoint$thresholds
      data$DV[rows] <- vapply(mu, function(eta) {
        cumulative <- if (endpoint$link == "probit") stats::pnorm(thresholds - eta) else stats::plogis(thresholds - eta)
        sample.int(length(thresholds) + 1L, 1L, prob = diff(c(0, cumulative, 1))) - 1L
      }, integer(1))
    } else {
      hazard <- pmax(response, 1e-12)
      data$DV[rows] <- stats::rpois(sum(rows), hazard)
    }
  }
  data
}

.lity_apply_operational_scenario <- function(data, scenario) {
  dose <- data$EVID != 0
  if (scenario$adherence < 1 && any(dose)) {
    omit <- dose & stats::runif(nrow(data)) > scenario$adherence
    data$AMT[omit] <- 0; data$RATE[omit] <- 0
  }
  observation <- data$EVID == 0 & data$MDV == 0
  if (scenario$missed_sample > 0 && any(observation)) {
    missed <- observation & stats::runif(nrow(data)) < scenario$missed_sample
    data$MDV[missed] <- 1L; data$DV[missed] <- NA_real_
  }
  if (scenario$dropout > 0) {
    for (id in unique(data$ID)) {
      if (stats::runif(1) < scenario$dropout) {
        times <- sort(unique(data$TIME[data$ID == id & observation]))
        if (length(times)) {
          dropout_time <- sample(times, 1L)
          dropped <- data$ID == id & data$TIME > dropout_time & data$EVID == 0
          data$MDV[dropped] <- 1L; data$DV[dropped] <- NA_real_
        }
      }
    }
  }
  data
}

#' Simulate complete trials under a LibeRality design
#'
#' @param design Design object.
#' @param n Number of replicated trials.
#' @param scenarios Scenario sampling probabilities; defaults to the design.
#' @param fit Whether to re-estimate each simulated trial with LibeRation.
#' @param method Estimation method when `fit = TRUE`.
#' @param seed Reproducible seed.
#' @param n_cores Simulation cores passed to LibeRation.
#' @param retain_data Retain simulated datasets.
#' @param progress Optional callback.
#' @return A `lity_simulation` result.
#' @export
lity_simulate_trials <- function(design, n = 100L, scenarios = design$scenarios,
                                 fit = FALSE, method = "FOCEI", seed = 7301L,
                                 n_cores = 1L, retain_data = TRUE, progress = NULL) {
  started <- proc.time()[[3L]]; n <- as.integer(n); .lity_seed(seed)
  if (length(n) != 1L || is.na(n) || n < 1L) .lity_stop("`n` must be positive.")
  scenarios <- .lity_named_list(scenarios, "scenarios", "lity_scenario")
  probability <- .lity_normalize_weights(vapply(scenarios, `[[`, numeric(1), "probability"))
  chosen <- sample(seq_along(scenarios), n, replace = TRUE, prob = probability)
  data_sets <- if (retain_data) vector("list", n) else NULL
  fits <- if (fit) vector("list", n) else NULL
  summaries <- vector("list", n)
  for (trial in seq_len(n)) {
    scenario <- scenarios[[chosen[[trial]]]]; model <- scenario$model %||% design$model
    arm_data <- lapply(names(design$arms), function(arm_name) {
      arm <- design$arms[[arm_name]]; events <- .lity_expand_arm(arm)
      for (name in names(scenario$covariates)) events[[name]] <- scenario$covariates[[name]]
      events <- .lity_apply_operational_scenario(events, scenario)
      simulated <- LibeRation::nm_simulate(
        model, events, theta = scenario$theta %||% model$THETAS$Value,
        omega = scenario$omega %||% model$OMEGAS$Value,
        sigma = scenario$sigma %||% model$SIGMAS$Value,
        random_effects = model$n_eta > 0L, residual = nrow(model$SIGMAS) > 0L,
        seed = seed + trial * 1009L + match(arm_name, names(design$arms)), n_cores = n_cores
      )
      simulated <- .lity_simulate_noncontinuous(simulated, design$endpoints)
      simulated$ARM <- arm_name
      simulated
    })
    offsets <- cumsum(c(0L, utils::head(vapply(arm_data, function(data) length(unique(data$ID)), integer(1)), -1L)))
    for (i in seq_along(arm_data)) arm_data[[i]]$ID <- arm_data[[i]]$ID + offsets[[i]]
    dataset <- do.call(rbind, arm_data); dataset$TRIAL <- trial; rownames(dataset) <- NULL
    if (retain_data) data_sets[[trial]] <- dataset
    fit_result <- if (fit) tryCatch(LibeRation::nm_est(model, dataset, method = method), error = identity) else NULL
    if (fit) fits[[trial]] <- fit_result
    summaries[[trial]] <- data.frame(
      trial = trial, scenario = scenario$name, observations = sum(dataset$EVID == 0 & dataset$MDV == 0),
      converged = if (!fit) NA else !inherits(fit_result, "error") && identical(fit_result$convergence, 0L),
      error = if (inherits(fit_result, "error")) conditionMessage(fit_result) else "",
      stringsAsFactors = FALSE
    )
    if (is.function(progress)) progress(as.list(summaries[[trial]][1L, ]))
  }
  result <- structure(list(
    schema = "liberality.simulation", version = 1L, id = .lity_id("simulation"),
    design_id = design$id, design = design, n = n,
    method = if (fit) method else "simulation only",
    scenario_draws = chosen, summary = do.call(rbind, summaries), data = data_sets,
    fits = fits, truth = lapply(scenarios, function(x) x$theta %||% design$model$THETAS$Value),
    seed = as.integer(seed), elapsed_seconds = proc.time()[[3L]] - started,
    created_at = .lity_now()
  ), class = "lity_simulation")
  result$operating_characteristics <- lity_operating_characteristics(result)
  result
}

#' Summarise empirical operating characteristics
#' @param simulation A result from [lity_simulate_trials()].
#' @param alpha Confidence interval alpha.
#' @export
lity_operating_characteristics <- function(simulation, alpha = 0.05) {
  if (!inherits(simulation, "lity_simulation")) .lity_stop("`simulation` must be a LibeRality trial simulation.")
  convergence <- if (is.null(simulation$fits)) NA_real_ else mean(simulation$summary$converged, na.rm = TRUE)
  if (is.null(simulation$fits)) return(list(convergence = convergence, estimates = data.frame(), coverage = data.frame()))
  successful <- which(vapply(simulation$fits, inherits, logical(1), "nm_fit"))
  if (!length(successful)) return(list(convergence = convergence, estimates = data.frame(), coverage = data.frame()))
  estimates <- do.call(rbind, lapply(successful, function(i) {
    fit <- simulation$fits[[i]]
    value <- fit$theta %||% fit$par[seq_len(length(simulation$truth[[simulation$scenario_draws[[i]]]]))]
    data.frame(trial = i, parameter = paste0("THETA", seq_along(value)), estimate = value,
               truth = simulation$truth[[simulation$scenario_draws[[i]]]], stringsAsFactors = FALSE)
  }))
  split_estimate <- split(estimates, estimates$parameter)
  summary <- do.call(rbind, lapply(split_estimate, function(data) data.frame(
    parameter = data$parameter[[1L]], mean = mean(data$estimate), bias = mean(data$estimate - data$truth),
    relative_bias = mean((data$estimate - data$truth) / data$truth),
    rmse = sqrt(mean((data$estimate - data$truth)^2)), n = nrow(data), stringsAsFactors = FALSE
  )))
  list(convergence = convergence, estimates = summary, raw_estimates = estimates,
       alpha = alpha, theoretical_information = "Use lity_information() for expected precision comparison.")
}

#' @export
print.lity_simulation <- function(x, ...) {
  cat("LibeRality trial simulation\n")
  cat("  trials:", x$n, " method:", x$method, " elapsed:", format(x$elapsed_seconds, digits = 5), "seconds\n")
  if (!is.na(x$operating_characteristics$convergence)) cat("  convergence:", x$operating_characteristics$convergence, "\n")
  invisible(x)
}
