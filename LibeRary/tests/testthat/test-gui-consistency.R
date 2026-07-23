test_that("catalogue GUIs retain shared theme, version labels, and compact settings", {
  package_root <- system.file(package = "LibeRary")
  catalog_js <- paste(readLines(
    file.path(package_root, "shiny", "www", "library-gui.js"), warn = FALSE
  ), collapse = "\n")
  ingest_js <- paste(readLines(
    file.path(package_root, "shiny-ingest", "www", "ingest-gui.js"), warn = FALSE
  ), collapse = "\n")
  ingest_app <- paste(readLines(
    file.path(package_root, "shiny-ingest", "app.R"), warn = FALSE
  ), collapse = "\n")
  reference_js <- paste(readLines(
    file.path(package_root, "shiny-reference", "www", "reference.js"), warn = FALSE
  ), collapse = "\n")

  expect_match(catalog_js, 'localStorage\\.getItem\\("liber\\.theme"\\)')
  expect_match(ingest_js, 'localStorage\\.getItem\\("liber\\.theme"\\)')
  expect_match(reference_js, "localStorage.getItem('liber.theme')", fixed = TRUE)
  expect_match(ingest_app, "ingest-version-pill", fixed = TRUE)
  expect_match(ingest_app, "ingest-settings-group", fixed = TRUE)
})

test_that("GUI dove assets remain true compact vectors", {
  paths <- c(
    system.file("shiny", "www", "favicon.svg", package = "LibeRary"),
    system.file("shiny-ingest", "www", "favicon.svg", package = "LibeRary")
  )
  expect_true(all(file.exists(paths)))
  expect_true(all(file.info(paths)$size < 4096))
  expect_true(all(vapply(paths, function(path) {
    grepl("<path", paste(readLines(path, warn = FALSE), collapse = ""))
  }, logical(1))))
})

test_that("all LibeRary GUI modes can be inspected without launching a browser", {
  expect_s3_class(ingest_shiny(launch.browser = NULL), "shiny.appobj")
  expect_s3_class(library_reference_shiny(launch.browser = NULL), "shiny.appobj")
})
