args <- commandArgs(trailingOnly = TRUE)
push <- "--push" %in% args
publish <- "--publish-releases" %in% args
if (publish && !push) {
  stop("`--publish-releases` requires `--push`.", call. = FALSE)
}

root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
manifest <- jsonlite::fromJSON(
  file.path(root, "ecosystem.json"), simplifyVector = FALSE
)
packages <- names(manifest$packages)
versions <- vapply(manifest$packages, `[[`, character(1), "version")
owner <- "svdijkman"

run <- function(command, arguments, directory = root, capture = FALSE) {
  old <- setwd(directory)
  on.exit(setwd(old), add = TRUE)
  output <- system2(
    command, arguments,
    stdout = if (capture) TRUE else "", stderr = if (capture) TRUE else ""
  )
  status <- attr(output, "status")
  if (is.null(status)) status <- 0L
  if (status != 0L) {
    stop(
      command, " failed in ", directory, ":\n",
      if (length(output)) paste(output, collapse = "\n") else "no output",
      call. = FALSE
    )
  }
  output
}

git_status <- run(
  "git", c("status", "--porcelain=v1", "--untracked-files=no"), capture = TRUE
)
if (length(git_status) && push) {
  stop("Mirror publication requires a clean tracked monorepo.", call. = FALSE)
}
source_commit <- trimws(run("git", c("rev-parse", "HEAD"), capture = TRUE)[[1L]])

stage <- tempfile("liber-mirrors-")
dir.create(stage, recursive = TRUE, showWarnings = FALSE)
stage <- normalizePath(stage, winslash = "/", mustWork = TRUE)
on.exit({
  target <- normalizePath(stage, winslash = "/", mustWork = FALSE)
  temp_root <- normalizePath(tempdir(), winslash = "/", mustWork = TRUE)
  if (startsWith(target, paste0(temp_root, "/")) && dir.exists(target)) {
    unlink(target, recursive = TRUE, force = TRUE)
  }
}, add = TRUE)

for (package in packages) {
  repository <- paste0("https://github.com/", owner, "/", package, ".git")
  clone <- file.path(stage, package)
  message("Synchronising ", package, " ", versions[[package]])
  run("git", c("clone", "--quiet", repository, shQuote(clone)))

  existing <- list.files(clone, all.files = TRUE, no.. = TRUE, full.names = TRUE)
  preserved <- file.path(clone, c(".git", ".github"))
  remove <- setdiff(
    normalizePath(existing, winslash = "/", mustWork = FALSE),
    normalizePath(preserved, winslash = "/", mustWork = FALSE)
  )
  if (length(remove)) unlink(remove, recursive = TRUE, force = TRUE)

  source <- file.path(root, package)
  entries <- list.files(source, all.files = TRUE, no.. = TRUE, full.names = TRUE)
  copied <- file.copy(
    entries, clone, recursive = TRUE, copy.mode = TRUE, copy.date = TRUE
  )
  if (!all(copied)) {
    stop("Unable to copy ", package, " into its mirror staging clone.",
         call. = FALSE)
  }
  run("git", c("add", "-A"), clone)
  changes <- run("git", c("status", "--porcelain=v1"), clone, capture = TRUE)
  if (length(changes)) {
    run("git", c("config", "user.name", "Sven C. van Dijkman"), clone)
    run(
      "git",
      c("config", "user.email", "svdijkman@users.noreply.github.com"),
      clone
    )
    run(
      "git",
      c(
        "commit", "--quiet", "-m",
        shQuote(paste0(
          "Release ", package, " ", versions[[package]],
          " from LibeR ", manifest$release
        ))
      ),
      clone
    )
  }
  mirror_commit <- trimws(
    run("git", c("rev-parse", "HEAD"), clone, capture = TRUE)[[1L]]
  )
  message(
    "  monorepo ", substr(source_commit, 1L, 12L),
    " -> mirror ", substr(mirror_commit, 1L, 12L)
  )

  if (push) {
    run("git", c("push", "origin", "HEAD:main"), clone)
    tag <- paste0("v", versions[[package]])
    remote_tag <- run(
      "git", c("ls-remote", "--tags", "origin", paste0("refs/tags/", tag)),
      clone, capture = TRUE
    )
    if (length(remote_tag)) {
      stop("Remote tag already exists for ", package, ": ", tag,
           call. = FALSE)
    }
    run(
      "git", c("tag", "-a", tag, "-m",
               shQuote(paste0(package, " ", versions[[package]]))),
      clone
    )
    run("git", c("push", "origin", tag), clone)

    if (publish) {
      release_dir <- file.path(root, "releases", manifest$release)
      assets <- file.path(
        release_dir,
        c(
          paste0(package, "_", versions[[package]], ".tar.gz"),
          paste0(package, "_", versions[[package]], ".zip"),
          paste0(package, "_", versions[[package]], ".pdf")
        )
      )
      assets <- assets[file.exists(assets)]
      if (!length(assets)) {
        stop("No release assets were found for ", package, ".", call. = FALSE)
      }
      run(
        "gh",
        c(
          "release", "create", tag, "--repo", paste0(owner, "/", package),
          "--title", shQuote(paste0(package, " ", versions[[package]])),
          "--notes",
          shQuote(paste0(
            "Research-beta package mirror generated from LibeR ecosystem ",
            manifest$release, " (monorepo ", source_commit, ")."
          )),
          shQuote(assets)
        ),
        clone
      )
    }
  }
}

message(
  if (push) "Package mirrors synchronised." else
    "Dry run completed. Re-run with --push after release validation."
)
