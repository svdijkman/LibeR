packages <- c("LibeRtAD", "LibeRation", "LibeRary", "LibeRator", "LibeRality", "LibeRties")
root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)

if (!requireNamespace("pak", quietly = TRUE)) install.packages("pak")
if (!requireNamespace("rcmdcheck", quietly = TRUE)) install.packages("rcmdcheck")

local <- paste0("./", packages)
pak::pkg_install(
  local,
  dependencies = c("Depends", "Imports", "LinkingTo"),
  upgrade = FALSE
)

failures <- list()
for (package in packages) {
  message("\n===== R CMD check: ", package, " =====")
  result <- rcmdcheck::rcmdcheck(
    file.path(root, package),
    args = c("--no-manual", "--as-cran"),
    build_args = "--no-manual",
    env = c(
      `_R_CHECK_FORCE_SUGGESTS_` = "false",
      `_R_CHECK_CRAN_INCOMING_REMOTE_` = "false",
      `_LIBERALITY_RUN_EXTERNAL_VALIDATION_` = "false"
    ),
    error_on = "never",
    check_dir = file.path(tempdir(), paste0(package, "-check"))
  )
  if (length(result$errors) || length(result$warnings)) failures[[package]] <- result
}

if (length(failures)) {
  details <- vapply(names(failures), function(package) {
    result <- failures[[package]]
    paste0(package, ": ", length(result$errors), " error(s), ",
           length(result$warnings), " warning(s)")
  }, character(1))
  stop("Package checks failed:\n", paste(details, collapse = "\n"), call. = FALSE)
}
