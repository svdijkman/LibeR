test_that("therapeutic GUI retains shared theme, dove, and responsive controls", {
  script <- paste(readLines(
    system.file("htmlwidgets", "liberatorWorkbench.js", package = "LibeRator"),
    warn = FALSE
  ), collapse = "\n")
  base_css <- paste(readLines(
    system.file("htmlwidgets", "liberatorWorkbench.css", package = "LibeRator"),
    warn = FALSE
  ), collapse = "\n")
  extras_css <- paste(readLines(
    system.file("htmlwidgets", "liberatorExtras.css", package = "LibeRator"),
    warn = FALSE
  ), collapse = "\n")

  expect_match(script, 'localStorage\\.getItem\\("liber\\.theme"\\)')
  expect_match(script, "M29 72c17-4", fixed = TRUE)
  expect_match(script, "lr-sidebar-toggle", fixed = TRUE)
  expect_match(script, "lr-rail-toggle", fixed = TRUE)
  expect_match(script, "useDialogFocus", fixed = TRUE)
  expect_match(base_css, "--brand:", fixed = TRUE)
  expect_false(grepl("--purple", paste(base_css, extras_css)))
  expect_match(extras_css, "\\.lr-sidebar\\.open")
  expect_match(extras_css, "\\.lr-right\\.open")
})
