args <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", args, value = TRUE)
script <- if (length(file_arg)) sub("^--file=", "", file_arg[[1L]]) else "tools/smoke-remote.R"
root <- normalizePath(file.path(dirname(script), ".."), winslash = "/", mustWork = TRUE)
source(file.path(root, "tools", "validation-runtime.R"), local = TRUE)
validation_runtime <- liber_validation_library(
  root, c("LibeRtAD", "LibeRation", "LibeRties")
)

library(LibeRties)
server_root <- tempfile("liberties-http-")
user <- ls_user_create(server_root, "smoke", limits = list(max_concurrent_jobs = 1L))
port <- httpuv::randomPort()
process <- callr::r_bg(
  function(root, port, libraries) {
    .libPaths(unique(c(libraries, .libPaths())))
    LibeRties::ls_run_api(root, host = "127.0.0.1", port = port,
                          max_workers_per_user = 1L, quiet = TRUE)
  },
  args = list(root = server_root, port = port, libraries = .libPaths()),
  libpath = .libPaths(), supervise = TRUE
)
on.exit(if (process$is_alive()) process$kill(), add = TRUE)

remote <- ls_remote(paste0("http://127.0.0.1:", port), user$token, timeout = 10)
deadline <- proc.time()[["elapsed"]] + 10
repeat {
  ready <- tryCatch(identical(as.character(remote$authenticate()$username), "smoke"),
                    error = function(e) FALSE)
  if (ready) break
  if (proc.time()[["elapsed"]] > deadline) {
    stop("Remote API did not become ready.\n", paste(process$read_error_lines(), collapse = "\n"))
  }
  Sys.sleep(0.05)
}

model <- LibeRation::nm_model(
  INPUT = c("ID", "TIME", "EVID", "AMT"), ADVAN = 1,
  PRED = "CL=THETA(1)\nV=THETA(2)\nS1=V", ERROR = "Y=F",
  THETAS = data.frame(THETA = 1:2, Value = c(2, 20))
)
job <- ls_job(
  "simulate", model,
  data.frame(ID = 1, TIME = c(0, 1), EVID = c(1, 0), AMT = c(100, 0)),
  label = "remote smoke"
)
id <- remote$submit(job)
deadline <- proc.time()[["elapsed"]] + 20
repeat {
  status <- as.character(remote$status(id)$status)
  if (status %in% c("completed", "failed", "cancelled")) break
  if (proc.time()[["elapsed"]] > deadline) stop("Remote job timed out.")
  Sys.sleep(0.05)
}
if (!identical(status, "completed")) stop("Remote job ended in state: ", status)
result <- remote$result(id)
expected <- c(5, 5 * exp(-0.1))
comparison <- all.equal(result$IPRED, expected, tolerance = 1e-10)
if (!isTRUE(comparison)) {
  stop("Remote result did not match the ADVAN1 reference: ",
       paste(format(result$IPRED, digits = 16), collapse = ", "),
       " (", paste(comparison, collapse = "; "), ")")
}
if (!identical(attr(result, "solver"), "advan")) stop("Remote result metadata was lost.")
cat("Remote HTTP smoke test: PASS\n")
