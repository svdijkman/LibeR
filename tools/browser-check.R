root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
if (!requireNamespace("pak", quietly = TRUE)) install.packages("pak")
packages <- c("LibeRtAD", "LibeRation", "LibeRary", "LibeRator", "LibeRality", "LibeRties")
pak::pkg_install(file.path(root, packages),
                 dependencies = TRUE, upgrade = FALSE)
Sys.setenv(LIBER_RUN_BROWSER_TESTS = "true", NOT_CRAN = "true")
for (package in packages) {
  path <- file.path(root, package, "tests", "testthat", "test-browser-e2e.R")
  if (file.exists(path)) {
    testthat::test_file(path, reporter = "summary", stop_on_failure = TRUE)
  }
}
