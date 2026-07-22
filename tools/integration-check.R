packages <- c("LibeRtAD", "LibeRation", "LibeRary", "LibeRator", "LibeRality", "LibeRties")
root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
if (!identical(tolower(Sys.getenv("LIBER_SKIP_INSTALL")), "true")) {
  if (!requireNamespace("pak", quietly = TRUE)) install.packages("pak")
  pak::pkg_install(file.path(root, packages), dependencies = TRUE, upgrade = FALSE)
}

library(LibeRation)
library(LibeRality)
library(LibeRties)

model <- nm_model(
  INPUT = c("ID", "TIME", "EVID", "AMT", "DV", "MDV"), ADVAN = 1,
  PRED = "CL=THETA(1)*exp(ETA(1));V=THETA(2);S1=V", ERROR = "Y=F+ERR(1)",
  THETAS = data.frame(THETA = 1:2, Value = c(2, 20), FIX = TRUE),
  OMEGAS = data.frame(OMEGA = 1, Value = 0.1, FIX = TRUE),
  SIGMAS = data.frame(SIGMA = 1, Value = 0.1, FIX = TRUE)
)
data <- data.frame(
  ID = 1, TIME = c(0, 1, 4), EVID = c(1, 0, 0), AMT = c(100, 0, 0),
  DV = c(NA, 4.5, 3.1), MDV = c(1, 0, 0)
)
job <- ls_job("estimate", model, data, arguments = list(method = "FOCEI", maxit = 2L))
rebuilt <- ls_job_decode(ls_job_encode(job))
stopifnot(inherits(rebuilt$model, "nm_model"), rebuilt$type == "estimate")

evaluation <- lity_evaluate(lity_example()$design, lity_criterion_D())
roundtrip <- ls_result_decode(ls_result_encode(evaluation))
stopifnot(inherits(roundtrip, "lity_evaluation"), inherits(roundtrip$design, "lity_design"))

queue <- ls_local_queue(tempfile("liber-ci-queue-"), max_workers = 1L)
on.exit(queue$shutdown(), add = TRUE)
id <- queue$submit(job)
deadline <- Sys.time() + 120
repeat {
  queue$poll()
  status <- queue$status(id)$status
  if (status %in% c("completed", "failed", "cancelled")) break
  if (Sys.time() > deadline) stop("Integration worker timed out.")
  Sys.sleep(0.1)
}
stopifnot(status == "completed", inherits(queue$result(id), "nm_fit"))
message("Cross-package job, result, and worker integration passed.")
