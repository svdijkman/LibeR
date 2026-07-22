\name{lity_external_validate}
\alias{lity_external_validate}
\alias{print.lity_external_validation}
\title{Validate LibeRality against PopED and PFIM}
\usage{
lity_external_validate(
  fixtures = lity_external_validation_fixtures(),
  engines = c("PopED", "PFIM"),
  repetitions = 3L,
  tolerance = list(absolute = 1e-05, relative = 1e-04, rse = 0.01),
  output_dir = NULL,
  design_search = TRUE
)

\method{print}{lity_external_validation}(x, ...)
}
\arguments{
\item{fixtures}{Fixture identifiers returned by \code{lity_external_validation_fixtures()}.}
\item{engines}{External engines to run in addition to LibeRality.}
\item{repetitions}{Number of warm-core and end-to-end timing repetitions.}
\item{tolerance}{Named list containing absolute, relative and RSE tolerances. RSE is measured in percentage points.}
\item{output_dir}{Optional output directory for RDS, CSV, JSON, matrix and HTML artifacts.}
\item{design_search}{Whether to run the matched D-optimal candidate-grid search.}
\item{x}{External-validation result.}
\item{...}{Unused.}
}
\value{An object of class \code{lity_external_validation}.}
\description{
Runs matched population-FO designs through LibeRality, PopED and PFIM,
transforms residual-error parameters to a common variance scale, and compares
complete Fisher matrices, RSEs, determinants and runtimes.
}

