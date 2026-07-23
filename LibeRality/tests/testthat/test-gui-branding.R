test_that("the LibeR dove is shared by the favicon and workbench header", {
  favicon <- system.file("assets", "favicon.svg", package = "LibeRality")
  expect_true(nzchar(favicon))
  artwork <- paste(readLines(favicon, warn = FALSE), collapse = "\n")
  expect_lt(file.info(favicon)$size, 300000)
  expect_match(artwork, 'id="liberality-dove"', fixed = TRUE)
  expect_match(artwork, 'width="512"', fixed = TRUE)
  expect_match(artwork, "data:image/png;base64,", fixed = TRUE)

  icon_url <- "liberality-test-assets/favicon.svg"
  payload <- LibeRality:::.lity_gui_payload(
    lity_example()$design, lity_criterion_D(), icon = icon_url
  )
  expect_identical(payload$icon, icon_url)

  widget_source <- paste(
    readLines(system.file("htmlwidgets", "liberalityWorkbench.js", package = "LibeRality"), warn = FALSE),
    collapse = "\n"
  )
  expect_match(widget_source, 'props.icon ? e("img", { src: props.icon', fixed = TRUE)
})
