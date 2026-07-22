args <- commandArgs(trailingOnly = TRUE)
workspace <- normalizePath(args[[1L]], winslash = "/", mustWork = TRUE)
home_dir <- file.path(workspace, "validation", "liberary-gui-home")

Sys.setenv(
  LIBERARY_HOME = home_dir,
  LIBERARY_DATA_DIR = file.path(home_dir, "data")
)
devtools::load_all(file.path(workspace, "LibeRary"), quiet = TRUE)
LibeRary::ingest_shiny(
  host = "127.0.0.1",
  port = 48766L,
  launch.browser = FALSE
)
