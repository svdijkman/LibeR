`%or%` <- function(left, right) {
  if (is.null(left) || !length(left)) right else left
}

for (package in c("LibeRtAD", "LibeRation", "LibeRality", "LibeRator")) {
  description <- utils::packageDescription(package)
  cat(
    package,
    description$Version,
    description$RemoteRepo %or% "",
    description$RemoteRef %or% "",
    description$RemoteSha %or% "",
    "\n"
  )
}
