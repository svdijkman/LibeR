root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
if (!requireNamespace("pak", quietly = TRUE)) install.packages("pak")
packages <- c("LibeRtAD", "LibeRation", "LibeRary", "LibeRator", "LibeRality", "LibeRties")
if (!identical(tolower(Sys.getenv("LIBER_SKIP_INSTALL")), "true")) {
  pak::pkg_install(
    paste0("./", packages),
    dependencies = c("Depends", "Imports", "LinkingTo"),
    upgrade = FALSE
  )
}
required <- c("testthat", "shinytest2", "DT")
missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) {
  stop(
    "Browser validation requires: ", paste(missing, collapse = ", "),
    ". The CI dependency step must install these packages explicitly.",
    call. = FALSE
  )
}
Sys.setenv(LIBER_RUN_BROWSER_TESTS = "true", NOT_CRAN = "true")
for (package in packages) {
  path <- file.path(root, package, "tests", "testthat", "test-browser-e2e.R")
  if (file.exists(path)) {
    testthat::test_file(path, reporter = "summary", stop_on_failure = TRUE)
  }
}
