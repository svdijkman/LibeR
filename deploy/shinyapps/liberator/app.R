options(shiny.maxRequestSize = 25 * 1024^2)

library(LibeRator)

# This hosted build is a research/teaching demonstration. Every browser
# session receives a separate encrypted workspace on ephemeral storage.
lator_gui(
  path = file.path(tempdir(), "LibeRator-shinyapps"),
  session_workspace = TRUE,
  teaching_example = TRUE,
  launch.browser = NULL
)
