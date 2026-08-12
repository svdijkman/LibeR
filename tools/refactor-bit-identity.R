args <- commandArgs(trailingOnly = TRUE)

option_value <- function(name, default = NULL) {
  prefix <- paste0("--", name, "=")
  hit <- args[startsWith(args, prefix)]
  if (!length(hit)) return(default)
  sub(prefix, "", hit[[length(hit)]], fixed = TRUE)
}

action <- match.arg(option_value("action", "compare"), c("capture", "compare"))
baseline <- option_value(
  "baseline",
  file.path(tempdir(), "liberation-refactor-bit-identity.rds")
)
root <- normalizePath(option_value("root", "."), mustWork = TRUE)
refactor_library <- file.path(root, ".testlib-refactor")
dir.create(refactor_library, recursive = TRUE, showWarnings = FALSE)
.libPaths(c(refactor_library, .libPaths()))

if (!requireNamespace("pkgload", quietly = TRUE)) {
  stop("pkgload is required for the refactor bit-identity gate.", call. = FALSE)
}

pkgload::load_all(file.path(root, "LibeRation"), quiet = TRUE)
source(file.path(root, "validation", "benchmark", "scenarios.R"), local = TRUE)

seed <- 20260713L
scenario <- benchmark_scenario(
  "iv-bolus", 100L, c(0.5, 1, 2, 4, 8, 12, 24), seed
)

bayes_model <- scenario$model
prior_mean <- as.numeric(bayes_model$THETAS$Value)
prior_sd <- pmax(abs(prior_mean) * 0.5, 0.5)
bayes_model$LIK_CONFIG$priors <- do.call(
  rbind,
  lapply(seq_along(prior_mean), function(index) {
    LibeRation::nm_prior(
      paste0("THETA", index), distribution = "normal",
      mean = prior_mean[[index]], sd = prior_sd[[index]]
    )
  })
)
bayes_model$OMEGAS$FIX[] <- TRUE
bayes_model$SIGMAS$FIX[] <- TRUE

controls <- list(
  FO = list(),
  FOCE = list(),
  FOCEI = list(),
  LAPLACE = list(),
  ITS = list(
    its_mstep_schedule = "fixed", its_acceleration = "none",
    its_eta_schedule = "fixed"
  ),
  GQ = list(gq_order = 3L),
  IMP = list(
    n_imp = 16L, seed = seed, imp_sampling = "random",
    imp_proposal = "gaussian", imp_sample_schedule = "fixed",
    imp_mstep_schedule = "fixed", imp_mstep_maxit = 1L,
    imp_reuse_modes = FALSE, imp_auto_stop = FALSE,
    imp_subject_allocation = "fixed"
  ),
  SAEM = list(
    n_iter = 6L, burn = 2L, mcmc_steps = 1L, seed = seed,
    saem_kernel = "random_walk", auto_stop = FALSE,
    saem_mstep_interval_burn = 1L, saem_mstep_interval = 1L,
    saem_parameter_averaging = "none", mstep_maxit = 2L
  ),
  BAYES = list(
    n_burn = 2L, n_sample = 5L, n_thin = 1L, seed = seed,
    outer_kernel = "isotropic", eta_kernel = "random_walk",
    delayed_rejection_scale = 0
  ),
  NPML = list(np_points = 5L, np_cycles = 1L, np_weight_maxit = 50L),
  NPAG = list(
    np_points = 5L, np_cycles = 1L, np_weight_maxit = 50L,
    np_max_candidates = 10L
  )
)

numeric_bytes <- function(value) {
  value <- as.double(value)
  vapply(value, function(element) {
    paste(format(writeBin(element, raw(), size = 8L), width = 2L), collapse = "")
  }, character(1))
}

run_fit <- function(method, numerical_mode) {
  model <- if (identical(method, "BAYES")) bayes_model else scenario$model
  common <- list(
    model = model, data = scenario$data, method = method,
    maxit = 2L, eta_maxit = 50L, tolerance = 1e-7,
    collect_output = FALSE, covariance = FALSE, n_cores = 1L,
    numerical_mode = numerical_mode
  )
  fit <- do.call(LibeRation::nm_est, c(common, controls[[method]]))
  values <- list(
    objective = as.numeric(fit$objective),
    theta = as.numeric(fit$theta),
    omega = as.numeric(fit$omega),
    sigma = as.numeric(fit$sigma)
  )
  list(values = values, bytes = lapply(values, numeric_bytes))
}

modes <- c("nonmem_compatibility", "liber_optimized")
results <- setNames(vector("list", length(modes)), modes)
for (mode in modes) {
  results[[mode]] <- setNames(vector("list", length(controls)), names(controls))
  for (method in names(controls)) {
    message("Refactor identity gate: ", mode, " / ", method)
    results[[mode]][[method]] <- run_fit(method, mode)
  }
}

if (identical(action, "capture")) {
  dir.create(dirname(baseline), recursive = TRUE, showWarnings = FALSE)
  saveRDS(results, baseline, version = 3L)
  message("Captured refactor baseline: ", normalizePath(baseline))
  quit(save = "no", status = 0L)
}

if (!file.exists(baseline)) {
  stop("Refactor baseline does not exist: ", baseline, call. = FALSE)
}
expected <- readRDS(baseline)
failures <- character()
for (mode in modes) for (method in names(controls)) {
  before <- expected[[mode]][[method]]$bytes
  after <- results[[mode]][[method]]$bytes
  for (field in names(before)) {
    if (!identical(before[[field]], after[[field]])) {
      failures <- c(failures, paste(mode, method, field, sep = " / "))
    }
  }
}
if (length(failures)) {
  stop(
    "Bit-identity regression in: ", paste(failures, collapse = ", "),
    call. = FALSE
  )
}
message("All 22 estimator-policy fits are bit-identical to the baseline.")
