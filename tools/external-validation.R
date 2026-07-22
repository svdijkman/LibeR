root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
packages <- c("LibeRtAD", "LibeRation", "LibeRality")
if (!requireNamespace("pak", quietly = TRUE)) install.packages("pak")
pak::pkg_install(file.path(root, packages), dependencies = TRUE, upgrade = FALSE)
pak::pkg_install(c("PopED", "PFIM"), dependencies = TRUE, upgrade = FALSE)
Sys.setenv(`_LIBERALITY_RUN_EXTERNAL_VALIDATION_` = "true")
result <- testthat::test_dir(
  file.path(root, "LibeRality", "tests", "testthat"),
  filter = "external-validation", reporter = "summary", stop_on_failure = TRUE
)
dir.create(file.path(root, "validation", "liberality", "external", "results"),
           recursive = TRUE, showWarnings = FALSE)
saveRDS(result, file.path(root, "validation", "liberality", "external", "results",
                          "test-results.rds"))
