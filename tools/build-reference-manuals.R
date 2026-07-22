#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
root <- if (length(args)) normalizePath(args[[1L]], mustWork = TRUE) else normalizePath(".")
packages <- c("LibeRtAD", "LibeRation", "LibeRary", "LibeRator", "LibeRality", "LibeRties")
output_dir <- file.path(root, "docs", "manuals")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

html_escape <- function(x) {
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  x <- gsub(">", "&gt;", x, fixed = TRUE)
  gsub('"', "&quot;", x, fixed = TRUE)
}

for (package in packages) {
  package_dir <- file.path(root, package)
  description <- read.dcf(file.path(package_dir, "DESCRIPTION"))
  version <- unname(description[1L, "Version"])
  title <- unname(description[1L, "Title"])
  rd_files <- sort(list.files(file.path(package_dir, "man"), pattern = "[.]Rd$", full.names = TRUE))
  rd_files <- Filter(function(path) {
    rd <- tools::parse_Rd(path, encoding = "UTF-8")
    keywords <- vapply(Filter(function(x) identical(attr(x, "Rd_tag"), "\\keyword"), rd),
                       function(x) trimws(paste(unlist(x), collapse = "")), character(1L))
    !"internal" %in% keywords
  }, rd_files)

  topics <- lapply(rd_files, function(path) {
    rd <- tools::parse_Rd(path, encoding = "UTF-8")
    paste(capture.output(tools::Rd2HTML(
      rd,
      out = "",
      package = package,
      fragment = FALSE,
      standalone = FALSE,
      no_links = TRUE,
      outputEncoding = "UTF-8"
    )), collapse = "\n")
  })

  navigation <- vapply(rd_files, function(path) {
    name <- sub("[.]Rd$", "", basename(path))
    sprintf("<li><a href='#%s'>%s</a></li>", html_escape(name), html_escape(name))
  }, character(1L))

  html <- c(
    "<!doctype html>",
    "<html lang='en'><head><meta charset='utf-8'>",
    sprintf("<title>%s %s reference manual</title>", package, version),
    "<style>",
    "@page { size: A4; margin: 17mm 16mm 18mm; }",
    "body { font-family: 'Segoe UI', Arial, sans-serif; color:#172033; line-height:1.42; max-width:980px; margin:0 auto; }",
    "h1 { color:#173f73; font-size:30px; margin-bottom:4px; }",
    "h2 { color:#173f73; border-bottom:2px solid #d9e4f2; padding-bottom:5px; break-before:page; }",
    "h3 { color:#315d89; margin-top:1.2em; }",
    "code, pre { font-family: Consolas, 'Courier New', monospace; }",
    "pre { background:#f5f7fa; border:1px solid #d8dee8; border-radius:4px; padding:10px; overflow-wrap:anywhere; white-space:pre-wrap; }",
    "table { border-collapse:collapse; width:100%; } td { vertical-align:top; border-bottom:1px solid #e5e9ef; padding:6px; }",
    ".cover { min-height:235mm; display:flex; flex-direction:column; justify-content:center; }",
    ".subtitle { color:#516175; font-size:18px; } .meta { margin-top:30px; color:#68778b; }",
    ".toc { columns:2; column-gap:32px; } .toc li { break-inside:avoid; margin:3px 0; }",
    "a { color:#175c9c; text-decoration:none; }",
    "</style></head><body>",
    "<section class='cover'>",
    sprintf("<h1>%s reference manual</h1>", package),
    sprintf("<div class='subtitle'>%s</div>", html_escape(title)),
    sprintf("<div class='meta'>Version %s<br>Generated %s<br>%d help topics</div>",
            html_escape(version), format(Sys.Date(), "%Y-%m-%d"), length(rd_files)),
    "</section>",
    "<section><h2>Contents</h2><ul class='toc'>",
    navigation,
    "</ul></section>",
    unlist(topics, use.names = FALSE),
    "</body></html>"
  )

  output <- file.path(output_dir, sprintf("%s-%s-reference.html", package, version))
  writeLines(enc2utf8(html), output, useBytes = TRUE)
  message("Wrote ", output)
}
