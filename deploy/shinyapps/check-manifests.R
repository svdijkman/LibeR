apps <- c("liberation", "liberality", "liberator")

for (app in apps) {
  directory <- file.path("deploy", "shinyapps", app)
  dependencies <- rsconnect::appDependencies(
    directory,
    appFiles = "app.R",
    dependencyResolution = "library"
  )
  unresolved <- dependencies[is.na(dependencies$Source) |
                               !nzchar(dependencies$Source), , drop = FALSE]
  if (nrow(unresolved)) {
    stop(app, " has unresolved package sources: ",
         paste(unresolved$Package, collapse = ", "))
  }
  liber <- dependencies[grepl("^LibeR", dependencies$Package), , drop = FALSE]
  cat("\n", app, ": ", nrow(dependencies), " dependencies\n", sep = "")
  print(liber, row.names = FALSE)
}
