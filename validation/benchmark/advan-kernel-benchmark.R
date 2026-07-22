#!/usr/bin/env Rscript

# Focused microbenchmark for the scalar-generic analytical propagation used by
# prediction tapes. It measures tape recording and repeated value/Jacobian
# evaluation; model parsing and C++ engine construction are deliberately kept
# outside the timed regions.

suppressPackageStartupMessages(library(LibeRation))

theta_table <- function(value) data.frame(THETA = seq_along(value), Value = value)

cases <- list(
  list(advan = 1L, obs = 1L, pred = "CL=THETA(1);V=THETA(2);S1=V",
       theta = c(2, 20)),
  list(advan = 2L, obs = 2L, pred = "KA=THETA(1);CL=THETA(2);V=THETA(3);S2=V",
       theta = c(1.1, 2, 20)),
  list(advan = 3L, obs = 1L,
       pred = "CL=THETA(1);VC=THETA(2);Q=THETA(3);VP=THETA(4);S1=VC",
       theta = c(2, 20, 1.5, 30)),
  list(advan = 4L, obs = 2L,
       pred = paste("KA=THETA(1)", "CL=THETA(2)", "VC=THETA(3)",
                    "Q=THETA(4)", "VP=THETA(5)", "S2=VC", sep = ";"),
       theta = c(1.1, 2, 20, 1.5, 30)),
  list(advan = 11L, obs = 1L,
       pred = paste("CL=THETA(1)", "VC=THETA(2)", "Q2=THETA(3)",
                    "VP1=THETA(4)", "Q3=THETA(5)", "VP2=THETA(6)",
                    "S1=VC", sep = ";"),
       theta = c(2, 20, 1.5, 30, 0.8, 50)),
  list(advan = 12L, obs = 2L,
       pred = paste("KA=THETA(1)", "CL=THETA(2)", "VC=THETA(3)",
                    "Q2=THETA(4)", "VP1=THETA(5)", "Q3=THETA(6)",
                    "VP2=THETA(7)", "S2=VC", sep = ";"),
       theta = c(1.1, 2, 20, 1.5, 30, 0.8, 50))
)

event_data <- function(regimen, subjects = 20L, observations = 33L) {
  sample_times <- seq(0, 24, length.out = observations)
  one <- data.frame(
    TIME = c(0, sample_times), EVID = c(1, rep(0, observations)),
    AMT = c(100, rep(0, observations)),
    RATE = c(if (regimen == "infusion") 10 else 0, rep(0, observations))
  )
  result <- one[rep(seq_len(nrow(one)), subjects), , drop = FALSE]
  result$ID <- rep(seq_len(subjects), each = nrow(one))
  result[, c("ID", "TIME", "EVID", "AMT", "RATE")]
}

seconds_per_call <- function(fn, minimum_seconds = 0.2, maximum_calls = 4096L) {
  calls <- 1L
  repeat {
    elapsed <- system.time(for (index in seq_len(calls)) value <- fn())[["elapsed"]]
    if (elapsed >= minimum_seconds || calls >= maximum_calls) {
      return(elapsed / calls)
    }
    calls <- min(maximum_calls, calls * 2L)
  }
}

measure <- function(case, regimen, specialized) {
  options(LibeRation.specialized_advan = specialized)
  data <- event_data(regimen)
  model <- nm_model(
    INPUT = names(data), ADVAN = case$advan, DOSECMP = 1L,
    OBSCMP = case$obs, PRED = case$pred, ERROR = "Y=F",
    THETAS = theta_table(case$theta)
  )
  engine <- NMEngine$new(model)
  record <- function() engine$prediction_tape(data)
  record_seconds <- seconds_per_call(record)
  tape <- record()
  evaluate <- function() LibeRation:::.liberation_prediction_tape_eval(
    tape$pointer, tape$point, TRUE
  )
  evaluate()
  evaluation_seconds <- seconds_per_call(evaluate)
  data.frame(
    advan = case$advan, regimen = regimen,
    kernel = if (specialized) "specialized" else "general",
    rows = nrow(data), operation_count = tape$operation_count,
    variable_count = tape$variable_count,
    record_milliseconds = 1000 * record_seconds,
    jacobian_milliseconds = 1000 * evaluation_seconds,
    stringsAsFactors = FALSE
  )
}

previous <- getOption("LibeRation.specialized_advan")
on.exit(options(LibeRation.specialized_advan = previous), add = TRUE)
results <- do.call(rbind, lapply(cases, function(case) {
  do.call(rbind, lapply(c("bolus", "infusion"), function(regimen) {
    rbind(
      measure(case, regimen, TRUE),
      measure(case, regimen, FALSE)
    )
  }))
}))

arguments <- commandArgs(trailingOnly = TRUE)
output <- if (length(arguments)) arguments[[1L]] else file.path(
  "validation", "benchmark", "results", "advan-specialized-20260714"
)
dir.create(output, recursive = TRUE, showWarnings = FALSE)
write.csv(results, file.path(output, "tape-benchmark.csv"), row.names = FALSE)

specialized <- results[results$kernel == "specialized", ]
general <- results[results$kernel == "general", ]
key <- paste(specialized$advan, specialized$regimen)
general <- general[match(key, paste(general$advan, general$regimen)), ]
summary <- data.frame(
  advan = specialized$advan, regimen = specialized$regimen,
  operation_reduction_percent = 100 *
    (general$operation_count - specialized$operation_count) /
    general$operation_count,
  recording_speedup = general$record_milliseconds /
    specialized$record_milliseconds,
  jacobian_speedup = general$jacobian_milliseconds /
    specialized$jacobian_milliseconds
)
write.csv(summary, file.path(output, "summary.csv"), row.names = FALSE)
print(summary, row.names = FALSE)
