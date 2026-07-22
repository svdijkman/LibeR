args <- commandArgs(trailingOnly = TRUE)
workspace <- normalizePath(args[[1L]], winslash = "/", mustWork = TRUE)
library_dir <- file.path(workspace, "validation", "liberary-installed-lib")
home_dir <- file.path(workspace, "validation", "liberary-gui-home")

.libPaths(c(library_dir, .libPaths()))
Sys.setenv(
  LIBERARY_HOME = home_dir,
  LIBERARY_DATA_DIR = file.path(home_dir, "data")
)

library(LibeRary)
LibeRary::ingest_shiny(
  host = "127.0.0.1",
  port = 48765L,
  launch.browser = FALSE
)
