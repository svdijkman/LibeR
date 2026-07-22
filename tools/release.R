root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
manifest <- jsonlite::fromJSON(file.path(root, "ecosystem.json"), simplifyVector = FALSE)
packages <- names(manifest$packages)
versions <- vapply(manifest$packages, `[[`, character(1), "version")

# R CMD build may compile vignettes before R CMD INSTALL gets a chance to
# configure the toolchain.  Make clean Windows release shells reproducible by
# discovering Rtools explicitly instead of relying on an interactive PATH.
if (.Platform$OS.type == "windows") {
  rtools_roots <- unique(Filter(nzchar, c(
    Sys.getenv("RTOOLS45_HOME"), Sys.getenv("RTOOLS_HOME"), "C:/rtools45"
  )))
  rtools_root <- rtools_roots[vapply(rtools_roots, function(path) {
    file.exists(file.path(path, "x86_64-w64-mingw32.static.posix", "bin", "g++.exe"))
  }, logical(1))][1L]
  if (!is.na(rtools_root)) {
    tool_paths <- normalizePath(c(
      file.path(rtools_root, "x86_64-w64-mingw32.static.posix", "bin"),
      file.path(rtools_root, "usr", "bin")
    ), winslash = "/", mustWork = TRUE)
    Sys.setenv(
      PATH = paste(c(tool_paths, Sys.getenv("PATH")), collapse = .Platform$path.sep),
      R_MAKEVARS_USER = file.path(root, "tools", "Makevars.rtools45")
    )
  }
}

actual <- vapply(packages, function(package) {
  read.dcf(file.path(root, package, "DESCRIPTION"))[[1L, "Version"]]
}, character(1))
if (!identical(unname(actual), unname(versions))) {
  stop("DESCRIPTION versions do not match ecosystem.json:\n",
       paste(paste(packages, actual, versions, sep = ": "), collapse = "\n"), call. = FALSE)
}

destination <- file.path(root, "releases", manifest$release)
dir.create(destination, recursive = TRUE, showWarnings = FALSE)
bundled_pandoc <- file.path(root, "tools", "pandoc-3.10")
if (dir.exists(bundled_pandoc) && !nzchar(Sys.getenv("RSTUDIO_PANDOC"))) {
  Sys.setenv(RSTUDIO_PANDOC = bundled_pandoc)
}

manual_status <- system2(file.path(R.home("bin"), "Rscript"),
                         c(shQuote(file.path(root, "tools", "build-reference-manuals.R")),
                           shQuote(root)))
if (!identical(manual_status, 0L)) stop("Reference-manual generation failed.", call. = FALSE)

for (package in packages) {
  status <- system2(file.path(R.home("bin"), "R"),
                    c("CMD", "build", "--no-manual", shQuote(file.path(root, package))),
                    stdout = TRUE, stderr = TRUE)
  if (!is.null(attr(status, "status")) && attr(status, "status") != 0L) {
    stop("Failed to build ", package, ":\n", paste(status, collapse = "\n"), call. = FALSE)
  }
  archive <- file.path(root, paste0(package, "_", versions[[package]], ".tar.gz"))
  if (!file.exists(archive)) stop("Build did not create ", archive, call. = FALSE)
  file.copy(archive, destination, overwrite = TRUE)
}

if (.Platform$OS.type == "windows") {
  binary_library <- file.path(root, ".release-buildlib")
  dir.create(binary_library, recursive = TRUE, showWarnings = FALSE)
  binary_libs <- paste(c(binary_library, .libPaths()), collapse = .Platform$path.sep)
  for (package in packages) {
    status <- system2(
      file.path(R.home("bin"), "R"),
      c("CMD", "INSTALL", "--build", "--preclean", "-l", shQuote(binary_library),
        shQuote(file.path(root, package))),
      stdout = TRUE, stderr = TRUE,
      env = paste0("R_LIBS=", binary_libs)
    )
    if (!is.null(attr(status, "status")) && attr(status, "status") != 0L) {
      stop("Failed to build Windows binary for ", package, ":\n",
           paste(status, collapse = "\n"), call. = FALSE)
    }
    archive <- file.path(root, paste0(package, "_", versions[[package]], ".zip"))
    if (!file.exists(archive)) stop("Binary build did not create ", archive, call. = FALSE)
    file.copy(archive, destination, overwrite = TRUE)
  }
}
if (!requireNamespace("openssl", quietly = TRUE)) install.packages("openssl")
archives <- list.files(destination, full.names = TRUE, pattern = "(\\.tar\\.gz|\\.zip)$")
checksums <- vapply(archives, function(path) {
  connection <- file(path, "rb")
  on.exit(close(connection), add = TRUE)
  paste0(openssl::sha256(readBin(connection, "raw", n = file.info(path)$size)))
}, character(1))
writeLines(paste(checksums, basename(archives)), file.path(destination, "SHA256SUMS"))
