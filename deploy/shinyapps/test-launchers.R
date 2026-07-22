options(warn = 2)

apps <- c(
  liberation = "deploy/shinyapps/liberation/app.R",
  liberality = "deploy/shinyapps/liberality/app.R",
  liberator = "deploy/shinyapps/liberator/app.R"
)

for (name in names(apps)) {
  value <- source(apps[[name]], local = new.env(parent = globalenv()))$value
  stopifnot(inherits(value, "shiny.appobj"))
  shiny::testServer(value$serverFuncSource(), {
    session$flushReact()
  })
  cat(name, "launcher and server initialization OK\n")
}
