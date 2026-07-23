liber_validation_manifest <- function(root) {
  path <- file.path(root, "ecosystem.json")
  if (!file.exists(path)) stop("Missing ecosystem manifest: ", path, call. = FALSE)
  jsonlite::fromJSON(path, simplifyVector = FALSE)
}

liber_validation_git <- function(root) {
  run_git <- function(args) {
    output <- suppressWarnings(system2(
      "git", c("-C", shQuote(root), args), stdout = TRUE, stderr = TRUE
    ))
    status <- attr(output, "status")
    if (!is.null(status) && status != 0L) return("")
    paste(output, collapse = "\n")
  }
  commit <- trimws(run_git(c("rev-parse", "HEAD")))
  status <- run_git(c("status", "--porcelain=v1", "--untracked-files=all"))
  difference <- run_git(c("diff", "--binary", "HEAD", "--"))
  status_lines <- if (nzchar(status)) strsplit(status, "\n", fixed = TRUE)[[1L]] else character()
  untracked <- substring(status_lines[startsWith(status_lines, "?? ")], 4L)
  untracked <- file.path(root, untracked)
  untracked <- untracked[file.exists(untracked) & !dir.exists(untracked)]
  untracked_hashes <- if (length(untracked)) vapply(untracked, liber_validation_sha256, character(1)) else character()
  difference_material <- paste(
    difference, status, paste(names(untracked_hashes), untracked_hashes, collapse = "\n"),
    sep = "\n"
  )
  difference_hash <- if (nzchar(trimws(difference_material))) {
    paste0(openssl::sha256(charToRaw(enc2utf8(difference_material))))
  } else NA_character_
  list(
    commit = if (nzchar(commit)) commit else NA_character_,
    tracked_worktree_clean = !nzchar(trimws(status)),
    tracked_status = status_lines,
    tracked_diff_sha256 = difference_hash
  )
}

liber_validation_sha256 <- function(path) {
  path <- normalizePath(path, winslash = "/", mustWork = TRUE)
  connection <- file(path, "rb")
  on.exit(close(connection), add = TRUE)
  paste0(openssl::sha256(readBin(connection, "raw", n = file.info(path)$size)))
}

liber_validation_library_name <- function(root) {
  manifest <- liber_validation_manifest(root)
  git <- liber_validation_git(root)
  commit <- if (is.na(git$commit)) "no-git" else substr(git$commit, 1L, 12L)
  if (!isTRUE(git$tracked_worktree_clean)) {
    commit <- paste0(commit, "-dirty-", substr(git$tracked_diff_sha256, 1L, 12L))
  }
  paste0(gsub("[^A-Za-z0-9_.-]", "-", manifest$release), "-", commit)
}

liber_validation_library <- function(root, packages,
                                     library = Sys.getenv("LIBER_VALIDATION_LIBRARY", ""),
                                     allow_release_library = FALSE) {
  manifest <- liber_validation_manifest(root)
  packages <- unique(as.character(packages))
  unknown <- setdiff(packages, names(manifest$packages))
  if (length(unknown)) {
    stop("Validation requested packages absent from ecosystem.json: ",
         paste(unknown, collapse = ", "), call. = FALSE)
  }
  canonical <- file.path(
    root, ".validation-libraries", liber_validation_library_name(root)
  )
  candidates <- Filter(nzchar, c(library, canonical))
  if (isTRUE(allow_release_library)) {
    candidates <- c(candidates, file.path(root, ".release-buildlib"))
  }
  candidates <- unique(candidates[dir.exists(candidates)])
  if (!length(candidates)) {
    stop(
      "No versioned validation library is available. Run `Rscript tools/create-validation-library.R` ",
      "or set LIBER_VALIDATION_LIBRARY to an exact, isolated library.", call. = FALSE
    )
  }
  selected <- normalizePath(candidates[[1L]], winslash = "/", mustWork = TRUE)
  expected <- vapply(manifest$packages[packages], `[[`, character(1), "version")
  installed <- vapply(packages, function(package) {
    description <- tryCatch(
      utils::packageDescription(package, lib.loc = selected),
      error = function(error) NULL
    )
    if (is.null(description)) NA_character_ else as.character(description$Version)
  }, character(1))
  mismatch <- is.na(installed) | installed != expected
  if (any(mismatch)) {
    detail <- paste0(packages[mismatch], " expected ", expected[mismatch],
                     ", found ", installed[mismatch])
    stop("Validation library version mismatch: ", paste(detail, collapse = "; "),
         call. = FALSE)
  }
  marker <- file.path(selected, "LIBER_VALIDATION_LIBRARY.json")
  if (!file.exists(marker) && !nzchar(library) && !isTRUE(allow_release_library)) {
    stop("The selected library is not an immutable LibeR validation library: ", selected,
         call. = FALSE)
  }
  marker_value <- if (file.exists(marker)) {
    jsonlite::read_json(marker, simplifyVector = FALSE)
  } else {
    NULL
  }
  if (!is.null(marker_value)) {
    optional_string <- function(value) {
      if (is.null(value) || !length(value) || is.na(value[[1L]])) NA_character_
      else as.character(value[[1L]])
    }
    git <- liber_validation_git(root)
    expected_marker <- list(
      release = as.character(manifest$release),
      git_commit = optional_string(git$commit),
      tracked_diff_sha256 = optional_string(git$tracked_diff_sha256),
      source_manifest_sha256 = liber_validation_sha256(file.path(root, "ecosystem.json"))
    )
    actual_marker <- list(
      release = optional_string(marker_value$release),
      git_commit = optional_string(marker_value$git_commit),
      tracked_diff_sha256 = optional_string(marker_value$tracked_diff_sha256),
      source_manifest_sha256 = optional_string(marker_value$source_manifest_sha256)
    )
    equal_optional <- function(left, right) {
      (is.na(left) && is.na(right)) || identical(left, right)
    }
    marker_ok <- vapply(
      names(expected_marker),
      function(field) equal_optional(actual_marker[[field]], expected_marker[[field]]),
      logical(1)
    )
    if (!all(marker_ok)) {
      stop(
        "Validation library provenance does not match the current source (",
        paste(names(marker_ok)[!marker_ok], collapse = ", "),
        "). Rebuild it with `Rscript tools/create-validation-library.R --source`.",
        call. = FALSE
      )
    }
  }
  .libPaths(unique(c(selected, .libPaths())))
  list(
    path = selected,
    packages = stats::setNames(as.list(installed), packages),
    expected = stats::setNames(as.list(expected), packages),
    marker = marker_value
  )
}

liber_validation_provenance <- function(root, packages, library,
                                        inputs = character(), seeds = list(),
                                        tolerances = list(), dependencies = character(),
                                        metadata = list(), output = NULL) {
  manifest_path <- file.path(root, "ecosystem.json")
  git <- liber_validation_git(root)
  input_paths <- unique(normalizePath(inputs[file.exists(inputs)], winslash = "/",
                                     mustWork = TRUE))
  input_records <- lapply(input_paths, function(path) list(
    path = path,
    bytes = unname(file.info(path)$size),
    sha256 = liber_validation_sha256(path)
  ))
  names(input_records) <- basename(input_paths)
  dependency_names <- unique(c(packages, dependencies))
  dependency_versions <- vapply(dependency_names, function(package) {
    if (!requireNamespace(package, quietly = TRUE)) return(NA_character_)
    as.character(utils::packageVersion(package))
  }, character(1))
  value <- list(
    schema = "liber.validation-evidence/1",
    created_at_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%OS3Z", tz = "UTC"),
    release = liber_validation_manifest(root)$release,
    ecosystem_manifest_sha256 = liber_validation_sha256(manifest_path),
    git = git,
    validation_library = normalizePath(library, winslash = "/", mustWork = TRUE),
    packages = stats::setNames(as.list(dependency_versions[packages]), packages),
    dependencies = stats::setNames(as.list(dependency_versions[dependencies]), dependencies),
    r = list(version = R.version.string, platform = R.version$platform),
    system = as.list(Sys.info()),
    seeds = seeds,
    tolerances = tolerances,
    inputs = input_records,
    metadata = metadata
  )
  if (!is.null(output)) {
    dir.create(dirname(output), recursive = TRUE, showWarnings = FALSE)
    temporary <- tempfile("validation-provenance-", tmpdir = dirname(output), fileext = ".json")
    jsonlite::write_json(value, temporary, auto_unbox = TRUE, pretty = TRUE,
                         null = "null", digits = 17)
    if (!file.rename(temporary, output)) {
      unlink(temporary)
      stop("Unable to publish validation provenance: ", output, call. = FALSE)
    }
  }
  value
}
