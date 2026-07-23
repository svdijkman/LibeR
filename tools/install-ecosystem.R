# Install one exact LibeR compatibility set from a consolidated GitHub release.
#
# From a trusted R session:
# source("https://raw.githubusercontent.com/svdijkman/LibeR/v0.9.0-research-beta.2/tools/install-ecosystem.R")
# liber_install()

liber_install <- function(
    tag = "v0.9.0-research-beta.2",
    library = .libPaths()[[1L]],
    binary = FALSE,
    repository = "svdijkman/LibeR") {
  if (getRversion() < "4.1.0") stop("LibeR requires R 4.1 or newer.", call. = FALSE)
  library <- path.expand(library)
  if (!dir.exists(library) && !dir.create(library, recursive = TRUE, showWarnings = FALSE)) {
    stop("Unable to create R library: ", library, call. = FALSE)
  }
  library <- normalizePath(library, winslash = "/", mustWork = TRUE)
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    install.packages("jsonlite", lib = library)
  }
  .libPaths(unique(c(library, .libPaths())))

  raw_root <- paste0("https://raw.githubusercontent.com/", repository, "/", tag)
  manifest_path <- tempfile(fileext = ".json")
  on.exit(unlink(manifest_path, force = TRUE), add = TRUE)
  utils::download.file(
    paste0(raw_root, "/ecosystem.json"), manifest_path,
    mode = "wb", quiet = FALSE
  )
  manifest <- jsonlite::fromJSON(manifest_path, simplifyVector = FALSE)
  packages <- names(manifest$packages)
  versions <- vapply(manifest$packages, `[[`, character(1), "version")

  stage <- tempfile("liber-install-")
  dir.create(stage, recursive = TRUE, showWarnings = FALSE)
  on.exit(unlink(stage, recursive = TRUE, force = TRUE), add = TRUE)
  descriptions <- file.path(stage, paste0(packages, "-DESCRIPTION"))
  for (index in seq_along(packages)) {
    utils::download.file(
      paste0(raw_root, "/", packages[[index]], "/DESCRIPTION"),
      descriptions[[index]], mode = "wb", quiet = TRUE
    )
  }
  description_dependencies <- function(path) {
    description <- read.dcf(path)
    fields <- intersect(c("Depends", "Imports", "LinkingTo"),
                        colnames(description))
    if (!length(fields)) return(character())
    entries <- unlist(strsplit(
      paste(description[1L, fields], collapse = ","), ",", fixed = TRUE
    ), use.names = FALSE)
    trimws(sub("\\s*\\([^)]*\\)\\s*$", "", entries))
  }
  direct <- unique(unlist(lapply(
    descriptions, description_dependencies
  ), use.names = FALSE))
  base_packages <- rownames(utils::installed.packages(priority = "base"))
  external <- setdiff(
    direct[nzchar(direct)], c("R", packages, base_packages)
  )
  missing <- external[!vapply(
    external, requireNamespace, logical(1), quietly = TRUE
  )]
  if (length(missing)) {
    message("Installing missing R dependencies: ", paste(missing, collapse = ", "))
    utils::install.packages(missing, lib = library, dependencies = NA)
  }
  unresolved <- external[!vapply(
    external, requireNamespace, logical(1), quietly = TRUE
  )]
  if (length(unresolved)) {
    stop("Unresolved R dependencies: ", paste(unresolved, collapse = ", "),
         call. = FALSE)
  }

  use_binary <- isTRUE(binary) && .Platform$OS.type == "windows"
  if (isTRUE(binary) && !use_binary) {
    warning("Precompiled LibeR archives are Windows-specific; using source packages.",
            call. = FALSE)
  }
  if (use_binary && !identical(paste(R.version$major, R.version$minor, sep = "."),
                               "4.6.0")) {
    warning(
      "The published Windows binaries were built with R 4.6.0; using source ",
      "packages for this R version.", call. = FALSE
    )
    use_binary <- FALSE
  }
  extension <- if (use_binary) ".zip" else ".tar.gz"
  release_root <- paste0(
    "https://github.com/", repository, "/releases/download/", tag, "/"
  )
  archives <- paste0(
    release_root, packages, "_", unname(versions[packages]), extension
  )
  archive_files <- file.path(
    stage, paste0(packages, "_", unname(versions[packages]), extension)
  )

  for (index in seq_along(packages)) {
    message(
      "Installing ", packages[[index]], " ", versions[[packages[[index]]]],
      " from ", tag
    )
    utils::download.file(
      archives[[index]], archive_files[[index]], mode = "wb", quiet = FALSE
    )
    utils::install.packages(
      archive_files[[index]], lib = library, repos = NULL,
      type = if (use_binary) "win.binary" else "source",
      dependencies = FALSE
    )
  }

  installed <- vapply(packages, function(package) {
    as.character(utils::packageVersion(package, lib.loc = library))
  }, character(1))
  mismatch <- installed != unname(versions[packages])
  if (any(mismatch)) {
    stop(
      "Installed package set does not match the release manifest: ",
      paste0(
        packages[mismatch], " expected ", unname(versions[packages][mismatch]),
        " but found ", installed[mismatch], collapse = "; "
      ),
      call. = FALSE
    )
  }
  doctor <- getExportedValue("LibeRation", "liber_doctor")
  result <- doctor(strict = TRUE, verbose = TRUE)
  message("Installed LibeR compatibility set ", manifest$release, " into ", library)
  invisible(result)
}
