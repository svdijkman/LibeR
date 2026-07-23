test_that("design GUI retains shared theme and accessible dialogs", {
  script <- paste(readLines(
    system.file("htmlwidgets", "liberalityWorkbench.js", package = "LibeRality"),
    warn = FALSE
  ), collapse = "\n")
  css <- paste(readLines(
    system.file("htmlwidgets", "liberalityWorkbench.css", package = "LibeRality"),
    warn = FALSE
  ), collapse = "\n")

  expect_match(script, 'localStorage\\.getItem\\("liber\\.theme"\\)')
  expect_match(script, "useDialogFocus", fixed = TRUE)
  expect_match(script, 'event\\.key === "Escape"')
  expect_match(script, '"aria-label": p.title', fixed = TRUE)
  expect_match(css, "focus-visible", fixed = TRUE)
})
