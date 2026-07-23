args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1L) {
  stop("Usage: scale-gate.R <raw-results.csv>", call. = FALSE)
}
path <- normalizePath(args[[1L]], winslash = "/", mustWork = TRUE)
results <- utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
required <- c(
  "engine", "status", "measured", "subjects", "process_wall_seconds",
  "peak_r_heap_mb", "input_payload_bytes", "result_payload_bytes"
)
missing <- setdiff(required, names(results))
if (length(missing)) stop("Scale results are missing: ", paste(missing, collapse = ", "))
results <- results[results$engine == "LibeRation" & results$measured, , drop = FALSE]
if (!nrow(results)) stop("No measured LibeRation scale result was found.", call. = FALSE)
if (any(results$status != "ok")) stop("At least one scale workload failed.", call. = FALSE)
if (any(results$subjects < 1000L)) stop("Scale gate requires at least 1,000 subjects.")

maximum_wall <- as.numeric(Sys.getenv("LIBER_SCALE_MAX_WALL_SECONDS", "900"))
maximum_heap <- as.numeric(Sys.getenv("LIBER_SCALE_MAX_HEAP_MB", "4096"))
if (any(!is.finite(results$process_wall_seconds)) ||
    any(results$process_wall_seconds > maximum_wall)) {
  stop("Scale wall-time ceiling exceeded (", maximum_wall, " seconds).", call. = FALSE)
}
if (any(!is.finite(results$peak_r_heap_mb)) ||
    any(results$peak_r_heap_mb > maximum_heap)) {
  stop("Scale R-heap ceiling exceeded (", maximum_heap, " MB).", call. = FALSE)
}
if (any(!is.finite(results$input_payload_bytes)) ||
    any(!is.finite(results$result_payload_bytes))) {
  stop("Scale payload measurement is incomplete.", call. = FALSE)
}
cat(
  "Scale gate passed:", max(results$subjects), "subjects;",
  sprintf("%.2f s maximum wall; %.1f MB maximum R heap.\n",
          max(results$process_wall_seconds), max(results$peak_r_heap_mb))
)
