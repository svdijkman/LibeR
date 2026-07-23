packages <- c("LibeRtAD", "LibeRation", "LibeRary", "LibeRator", "LibeRality", "LibeRties")
root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
if (.Platform$OS.type == "windows") {
  rtools_roots <- unique(Filter(nzchar, c(
    Sys.getenv("RTOOLS45_HOME"), Sys.getenv("RTOOLS_HOME"), "C:/rtools45"
  )))
  rtools_root <- rtools_roots[vapply(rtools_roots, function(path) {
    file.exists(file.path(
      path, "x86_64-w64-mingw32.static.posix", "bin", "g++.exe"
    ))
  }, logical(1))][1L]
  if (!is.na(rtools_root)) {
    tool_paths <- normalizePath(c(
      file.path(rtools_root, "x86_64-w64-mingw32.static.posix", "bin"),
      file.path(rtools_root, "usr", "bin")
    ), winslash = "/", mustWork = TRUE)
    Sys.setenv(
      PATH = paste(c(tool_paths, Sys.getenv("PATH")),
                   collapse = .Platform$path.sep),
      R_MAKEVARS_USER = file.path(root, "tools", "Makevars.rtools45")
    )
  }
}
local_library <- Sys.getenv(
  "LIBER_INSTALL_LIBRARY", file.path(root, ".testlib-ci")
)
dir.create(local_library, recursive = TRUE, showWarnings = FALSE)
.libPaths(unique(c(local_library, .libPaths())))
Sys.setenv(
  LIBER_INSTALL_LIBRARY = local_library,
  R_LIBS = paste(.libPaths(), collapse = .Platform$path.sep)
)

matrix_status <- system2(
  file.path(R.home("bin"), "Rscript"),
  c(file.path(root, "tools", "support-matrix-check.R"), root)
)
if (!identical(matrix_status, 0L)) stop("Support-matrix validation failed.", call. = FALSE)

if (!requireNamespace("rcmdcheck", quietly = TRUE)) install.packages("rcmdcheck")

if (!identical(tolower(Sys.getenv("LIBER_SKIP_LOCAL_INSTALL")), "true")) {
  install_status <- system2(
    file.path(R.home("bin"), "Rscript"),
    file.path(root, "tools", "install-local-stack.R")
  )
  if (!identical(install_status, 0L)) {
    stop("Unable to install the exact local package stack.", call. = FALSE)
  }
}

failures <- list()
for (package in packages) {
  message("\n===== R CMD check: ", package, " =====")
  result <- rcmdcheck::rcmdcheck(
    file.path(root, package),
    args = c("--no-manual", "--as-cran"),
    build_args = "--no-manual",
    env = c(
      `_R_CHECK_FORCE_SUGGESTS_` = "false",
      `_R_CHECK_CRAN_INCOMING_REMOTE_` = "false",
      `_LIBERALITY_RUN_EXTERNAL_VALIDATION_` = "false"
    ),
    error_on = "never",
    check_dir = file.path(tempdir(), paste0(package, "-check"))
  )
  if (length(result$errors) || length(result$warnings)) failures[[package]] <- result
}

if (length(failures)) {
  details <- vapply(names(failures), function(package) {
    result <- failures[[package]]
    paste0(package, ": ", length(result$errors), " error(s), ",
           length(result$warnings), " warning(s)")
  }, character(1))
  stop("Package checks failed:\n", paste(details, collapse = "\n"), call. = FALSE)
}
