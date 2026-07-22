test_that("optimal-design GUI can return a hosted Shiny application", {
  app <- liberality_gui(launch.browser = NULL)
  expect_s3_class(app, "shiny.appobj")
  shiny::testServer(app[["serverFuncSource"]](), {
    session$flushReact()
  })
})
