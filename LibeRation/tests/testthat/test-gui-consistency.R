test_that("modelling GUI retains shared theme and accessible dialogs", {
  script <- paste(readLines(
    system.file("htmlwidgets", "liberWorkbench.js", package = "LibeRation"),
    warn = FALSE
  ), collapse = "\n")
  css <- paste(readLines(
    system.file("htmlwidgets", "liberWorkbench.css", package = "LibeRation"),
    warn = FALSE
  ), collapse = "\n")

  expect_match(script, 'localStorage\\.getItem\\("liber\\.theme"\\)')
  expect_match(script, "useDialogFocus", fixed = TRUE)
  expect_match(script, 'event\\.key === "Escape"')
  expect_match(script, '"aria-label": props.title', fixed = TRUE)
  expect_match(css, "focus-visible", fixed = TRUE)
})
