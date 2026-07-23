#!/usr/bin/env Rscript

`%||%` <- function(x, y) if (is.null(x)) y else x
arguments <- commandArgs(trailingOnly = TRUE)
value_after <- function(name, default) {
  hit <- arguments[startsWith(arguments, paste0("--", name, "="))]
  if (!length(hit)) return(default)
  sub(paste0("^--", name, "="), "", hit[[1L]])
}
root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
manifest <- jsonlite::read_json(file.path(root, "ecosystem.json"), simplifyVector = FALSE)
lifecycle_path <- file.path(root, "api-lifecycle.json")
lifecycle <- jsonlite::read_json(lifecycle_path, simplifyVector = FALSE)
packages <- names(manifest$packages)

exports_for <- function(package) {
  namespace <- readLines(file.path(root, package, "NAMESPACE"), warn = FALSE)
  lines <- grep("^export\\(", namespace, value = TRUE)
  sub("^export\\((.*)\\)$", "\\1", lines)
}

rows <- lapply(packages, function(package) {
  exports <- exports_for(package)
  stable <- unlist(lifecycle$stable_contracts[[package]] %||% list(), use.names = FALSE)
  experimental <- unlist(lifecycle$experimental[[package]] %||% list(), use.names = FALSE)
  deprecated <- unlist(lifecycle$deprecated[[package]] %||% list(), use.names = FALSE)
  configured <- unique(c(stable, experimental, deprecated))
  unknown <- setdiff(configured, exports)
  if (length(unknown)) {
    stop(package, " API lifecycle config names unknown exports: ",
         paste(unknown, collapse = ", "), call. = FALSE)
  }
  status <- rep(lifecycle$policy$default %||% "evolving", length(exports))
  status[exports %in% stable] <- "stable-contract"
  status[exports %in% experimental] <- "experimental"
  status[exports %in% deprecated] <- "deprecated"
  data.frame(
    package = package, version = manifest$packages[[package]]$version,
    symbol = exports, status = status, stringsAsFactors = FALSE
  )
})
inventory <- do.call(rbind, rows)
rownames(inventory) <- NULL

output <- value_after("output", file.path(root, "docs", "api-inventory.csv"))
json_output <- value_after("json", sub("[.]csv$", ".json", output))
if (!grepl("^([A-Za-z]:)?[/\\]", output)) output <- file.path(root, output)
if (!grepl("^([A-Za-z]:)?[/\\]", json_output)) json_output <- file.path(root, json_output)
dir.create(dirname(output), recursive = TRUE, showWarnings = FALSE)
utils::write.csv(inventory, output, row.names = FALSE)
summary <- split(inventory$status, inventory$package)
summary <- lapply(summary, function(status) as.list(table(status)))
jsonlite::write_json(list(
  schema = "liber.api-inventory/1", release = manifest$release,
  lifecycle_schema = lifecycle$schema, policy = lifecycle$policy,
  summary = summary,
  entries = lapply(seq_len(nrow(inventory)), function(index) {
    as.list(inventory[index, , drop = FALSE])
  })
), json_output, auto_unbox = TRUE, pretty = TRUE)
cat("API inventory:", nrow(inventory), "exports ->", output, "\n")
