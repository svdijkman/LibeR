test_that("administration GUI retains shared theme and version branding", {
  source <- paste(deparse(body(LibeRties::ls_admin_gui)), collapse = "\n")
  css <- paste(readLines(
    system.file("admin-assets", "admin.css", package = "LibeRties"),
    warn = FALSE
  ), collapse = "\n")

  expect_match(source, "localStorage.getItem('liber.theme')", fixed = TRUE)
  expect_match(source, "package_version", fixed = TRUE)
  expect_match(source, "la-version-pill", fixed = TRUE)
  expect_match(css, "focus-visible", fixed = TRUE)
})
