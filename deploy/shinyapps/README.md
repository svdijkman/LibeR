# LibeR shinyapps.io launchers

These minimal launchers deploy the package GUIs without embedding source code
or credentials in the application bundle.

- **LibeRation** uses a separate ephemeral project workspace for every browser
  session and disables its background local queue. Estimation and simulation
  therefore execute in the Shiny worker process.
- **LibeRality** starts with its synthetic teaching design and keeps its state
  within the browser session.
- **LibeRator** creates a separate encrypted ephemeral workspace for every
  browser session. It must only be used with synthetic teaching data on
  shinyapps.io.

The applications must not be used as durable or clinical data stores. Connect
them to governed persistent infrastructure before enabling real study or
patient data.
