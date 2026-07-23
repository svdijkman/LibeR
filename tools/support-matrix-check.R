args <- commandArgs(trailingOnly = TRUE)
root <- if (length(args)) args[[1L]] else getwd()
root <- normalizePath(root, winslash = "/", mustWork = TRUE)
path <- file.path(root, "LibeRation", "inst", "ecosystem", "support-matrix.csv")
if (!file.exists(path)) stop("Support matrix is missing.", call. = FALSE)

matrix <- utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
required_columns <- c(
  "package", "capability", "status", "evidence_tier", "reference", "gate",
  "last_verified", "recommended_use"
)
missing_columns <- setdiff(required_columns, names(matrix))
if (length(missing_columns)) {
  stop("Support matrix is missing columns: ", paste(missing_columns, collapse = ", "),
       call. = FALSE)
}
packages <- c("LibeRtAD", "LibeRation", "LibeRties", "LibeRary", "LibeRator", "LibeRality")
if (!setequal(unique(matrix$package), packages)) {
  stop("Support matrix package coverage does not match the ecosystem.", call. = FALSE)
}
if (anyDuplicated(paste(matrix$package, matrix$capability, sep = "::"))) {
  stop("Support matrix contains duplicate package/capability rows.", call. = FALSE)
}
if (any(!matrix$evidence_tier %in% c("validated", "verified", "experimental"))) {
  stop("Support matrix contains an invalid evidence tier.", call. = FALSE)
}
if (any(!matrix$status %in% c("implemented", "experimental", "not-qualified",
                              "external-control"))) {
  stop("Support matrix contains an invalid implementation status.", call. = FALSE)
}
if (any(!nzchar(trimws(matrix$gate))) || any(!nzchar(trimws(matrix$recommended_use)))) {
  stop("Every support-matrix row requires a gate and recommended use.", call. = FALSE)
}
dates <- as.Date(matrix$last_verified)
if (anyNA(dates) || any(dates > Sys.Date())) {
  stop("Support-matrix verification dates are invalid.", call. = FALSE)
}
if (any(matrix$evidence_tier == "validated" &
        (!nzchar(trimws(matrix$reference)) | grepl("^none$", matrix$reference, ignore.case = TRUE)))) {
  stop("Validated capabilities require an independent reference.", call. = FALSE)
}
cat("Support matrix:", nrow(matrix), "capabilities across", length(packages), "packages.\n")
