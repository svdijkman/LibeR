args <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", args, value = TRUE)
script <- if (length(file_arg)) {
  sub("^--file=", "", file_arg[[1L]])
} else {
  "validation/ad-backends/run-benchmark.R"
}
root <- normalizePath(file.path(dirname(script), "..", ".."), mustWork = TRUE)
harness <- file.path(root, "validation", "ad-backends")
output <- file.path(harness, "results")
dir.create(output, recursive = TRUE, showWarnings = FALSE)

iterations_arg <- grep("^--iterations=", commandArgs(trailingOnly = TRUE), value = TRUE)
iterations <- if (length(iterations_arg)) {
  as.integer(sub("^--iterations=", "", iterations_arg[[1L]]))
} else {
  200L
}
if (is.na(iterations) || iterations < 1L) stop("--iterations must be positive.")

local_library <- file.path(root, ".testlib-current")
if (dir.exists(local_library)) .libPaths(c(local_library, .libPaths()))
if (!requireNamespace("LibeRtAD", quietly = TRUE)) {
  stop("Install LibeRtAD before running the external AD benchmark.")
}

elapsed <- function(expression) {
  started <- proc.time()[["elapsed"]]
  value <- force(expression)
  list(value = value, seconds = unname(proc.time()[["elapsed"]] - started))
}
timed_calls <- function(fun, n = iterations) {
  fun()
  samples <- numeric(5)
  for (sample in seq_along(samples)) {
    started <- proc.time()[["elapsed"]]
    for (iteration in seq_len(n)) fun()
    samples[[sample]] <- (proc.time()[["elapsed"]] - started) * 1e6 / n
  }
  unname(stats::median(samples))
}
number <- function(value) format(value, digits = 17, scientific = TRUE)

cases <- local({
  dimension <- 10L
  rows <- 400L
  x <- outer(seq_len(rows), seq_len(dimension), function(row, column) {
    sin(row * (column + 0.5) / 23) + cos(row / (column + 2))
  })
  truth <- seq(-0.7, 0.7, length.out = dimension)
  probability <- stats::plogis(drop(x %*% truth))
  y <- as.integer(((seq_len(rows) * 37L) %% 101L) / 101 < probability)
  list(
    rosenbrock_10d = list(
      id = 1L, point = rep(-0.4, dimension),
      x = matrix(numeric(), 0L, dimension), y = numeric()
    ),
    logistic_400x10 = list(
      id = 2L, point = seq(-0.2, 0.2, length.out = dimension),
      x = x, y = y
    )
  )
})

libertad_code <- function(case) {
  names <- paste0("B", seq_along(case$point))
  if (case$id == 1L) {
    terms <- unlist(lapply(seq_len(length(names) - 1L), function(index) {
      c(
        paste0(
          "R", index, " = 100 * (", names[[index + 1L]], " - ",
          names[[index]], "^2)^2"
        ),
        paste0("S", index, " = (1 - ", names[[index]], ")^2")
      )
    }))
    final <- paste(c(
      paste0("R", seq_len(length(names) - 1L)),
      paste0("S", seq_len(length(names) - 1L))
    ), collapse = " + ")
  } else {
    terms <- character(nrow(case$x) * 2L)
    likelihood <- character(nrow(case$x))
    for (row in seq_len(nrow(case$x))) {
      linear <- paste(
        paste(number(case$x[row, ]), names, sep = " * "),
        collapse = " + "
      )
      terms[[2L * row - 1L]] <- paste0("L", row, " = ", linear)
      terms[[2L * row]] <- paste0(
        "N", row, " = log1p(exp(L", row, ")) - ",
        case$y[[row]], " * L", row
      )
      likelihood[[row]] <- paste0("N", row)
    }
    final <- paste(likelihood, collapse = " + ")
  }
  paste(c(terms, paste0("Y = ", final)), collapse = "\n")
}

result_row <- function(case_name, backend, status = "completed", message = NA_character_,
                       compile_seconds = NA_real_, tape_seconds = NA_real_,
                       value_gradient_us = NA_real_, hessian_us = NA_real_,
                       value = NA_real_, max_gradient_difference = NA_real_,
                       object_bytes = NA_real_, tape_bytes_proxy = NA_real_,
                       version = NA_character_) {
  data.frame(
    case = case_name, backend = backend, status = status, message = message,
    compile_seconds = compile_seconds, tape_seconds = tape_seconds,
    value_gradient_microseconds = value_gradient_us,
    hessian_microseconds = hessian_us, value = value,
    max_gradient_difference = max_gradient_difference,
    object_bytes = object_bytes, tape_bytes_proxy = tape_bytes_proxy,
    version = version, stringsAsFactors = FALSE
  )
}

results <- list()
references <- list()
for (case_name in names(cases)) {
  case <- cases[[case_name]]
  names(case$point) <- paste0("B", seq_along(case$point))
  built <- elapsed(LibeRtAD::ad_compile(
    libertad_code(case), inputs = names(case$point), outputs = "Y",
    at = case$point, wrt = names(case$point)
  ))
  model <- built$value
  evaluation <- model$value_gradient(case$point)
  references[[case_name]] <- list(
    value = unname(evaluation$value[[1L]]),
    gradient = unname(evaluation$gradient)
  )
  info <- model$tape_info()
  results[[length(results) + 1L]] <- result_row(
    case_name, "LibeRtAD", compile_seconds = built$seconds,
    tape_seconds = built$seconds,
    value_gradient_us = timed_calls(function() model$value_gradient(case$point)),
    hessian_us = timed_calls(function() model$hessian(case$point)),
    value = references[[case_name]]$value,
    max_gradient_difference = 0,
    object_bytes = as.numeric(object.size(model)),
    tape_bytes_proxy = info$resident_bytes_proxy,
    version = as.character(utils::packageVersion("LibeRtAD"))
  )
}

if (!requireNamespace("TMB", quietly = TRUE)) {
  for (case_name in names(cases)) {
    results[[length(results) + 1L]] <- result_row(
      case_name, "TMB", status = "skipped",
      message = "R package TMB is not installed."
    )
  }
} else {
  tmb_source <- file.path(harness, "tmb_objective.cpp")
  build_dir <- file.path(output, "tmb-build")
  dir.create(build_dir, recursive = TRUE, showWarnings = FALSE)
  file.copy(tmb_source, build_dir, overwrite = TRUE)
  old <- getwd()
  compiled <- tryCatch(
    {
      setwd(build_dir)
      elapsed(TMB::compile("tmb_objective.cpp", flags = "-O2"))
    },
    error = identity,
    finally = setwd(old)
  )
  tmb_dll <- NULL
  if (!inherits(compiled, "error")) {
    tmb_dll <- normalizePath(
      file.path(build_dir, TMB::dynlib("tmb_objective")),
      mustWork = TRUE
    )
    dyn.load(tmb_dll)
  }
  for (case_name in names(cases)) {
    case <- cases[[case_name]]
    if (inherits(compiled, "error")) {
      results[[length(results) + 1L]] <- result_row(
        case_name, "TMB", status = "failed",
        message = conditionMessage(compiled)
      )
      next
    }
    taped <- elapsed(TMB::MakeADFun(
      data = list(case_id = case$id, x = case$x, y = case$y),
      parameters = list(beta = case$point), DLL = "tmb_objective",
      silent = TRUE
    ))
    objective <- taped$value
    value <- objective$fn(case$point)
    gradient <- objective$gr(case$point)
    results[[length(results) + 1L]] <- result_row(
      case_name, "TMB", compile_seconds = compiled$seconds,
      tape_seconds = taped$seconds,
      value_gradient_us = timed_calls(function() {
        objective$fn(case$point); objective$gr(case$point)
      }),
      hessian_us = timed_calls(function() objective$he(case$point)),
      value = value,
      max_gradient_difference = max(abs(
        gradient - references[[case_name]]$gradient
      )),
      object_bytes = as.numeric(object.size(objective)),
      version = as.character(utils::packageVersion("TMB"))
    )
  }
  if (!is.null(tmb_dll)) {
    try(dyn.unload(tmb_dll), silent = TRUE)
  }
}

cmdstan_available <- requireNamespace("cmdstanr", quietly = TRUE) &&
  tryCatch(nzchar(cmdstanr::cmdstan_path()), error = function(error) FALSE)
if (!cmdstan_available) {
  for (case_name in names(cases)) {
    results[[length(results) + 1L]] <- result_row(
      case_name, "CmdStan", status = "skipped",
      message = "cmdstanr and a configured CmdStan toolchain are required."
    )
  }
} else {
  stan_build <- tryCatch(
    elapsed(cmdstanr::cmdstan_model(
      file.path(harness, "stan_objective.stan"), quiet = TRUE
    )),
    error = identity
  )
  for (case_name in names(cases)) {
    case <- cases[[case_name]]
    if (inherits(stan_build, "error")) {
      results[[length(results) + 1L]] <- result_row(
        case_name, "CmdStan", status = "failed",
        message = conditionMessage(stan_build)
      )
      next
    }
    data <- list(
      case_id = case$id, N = nrow(case$x), K = length(case$point),
      x = case$x, y = as.integer(case$y)
    )
    initialized <- tryCatch(elapsed({
      fit <- stan_build$value$optimize(
        data = data, init = list(beta = unname(case$point)),
        iter = 1L, refresh = 0L
      )
      fit$init_model_methods(verbose = FALSE, hessian = TRUE)
      fit
    }), error = identity)
    if (inherits(initialized, "error")) {
      results[[length(results) + 1L]] <- result_row(
        case_name, "CmdStan", status = "failed",
        message = conditionMessage(initialized)
      )
      next
    }
    fit <- initialized$value
    gradient <- fit$grad_log_prob(case$point, jacobian = FALSE)
    value <- -as.numeric(attr(gradient, "log_prob"))
    results[[length(results) + 1L]] <- result_row(
      case_name, "CmdStan", compile_seconds = stan_build$seconds,
      tape_seconds = initialized$seconds,
      value_gradient_us = timed_calls(function() {
        fit$grad_log_prob(case$point, jacobian = FALSE)
      }),
      hessian_us = timed_calls(function() {
        fit$hessian(case$point, jacobian = FALSE)
      }),
      value = value,
      max_gradient_difference = max(abs(
        -as.numeric(gradient) - references[[case_name]]$gradient
      )),
      object_bytes = as.numeric(object.size(fit)),
      version = paste0(
        utils::packageVersion("cmdstanr"), " / CmdStan ",
        cmdstanr::cmdstan_version()
      )
    )
  }
}

table <- do.call(rbind, results)
manifest <- list(
  generated_at = format(Sys.time(), tz = "UTC", usetz = TRUE),
  R = R.version.string,
  platform = R.version$platform,
  iterations = iterations,
  results = table
)
utils::write.csv(table, file.path(output, "benchmark.csv"), row.names = FALSE)
saveRDS(manifest, file.path(output, "benchmark.rds"), version = 3L)
print(table, row.names = FALSE)
