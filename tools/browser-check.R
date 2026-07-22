root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
if (!requireNamespace("pak", quietly = TRUE)) install.packages("pak")
pak::pkg_install(file.path(root, c("LibeRtAD", "LibeRation", "LibeRties")),
                 dependencies = TRUE, upgrade = FALSE)
Sys.setenv(LIBER_RUN_BROWSER_TESTS = "true", NOT_CRAN = "true")
testthat::test_file(
  file.path(root, "LibeRation", "tests", "testthat", "test-browser-e2e.R"),
  reporter = "summary", stop_on_failure = TRUE
)
