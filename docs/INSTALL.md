# Installing a compatible LibeR ecosystem

The consolidated release is the source of truth. Do not mix arbitrary package
versions from different release dates.

## Compatibility-checked installer

Run the installer from the release tag you intend to install:

```r
source("https://raw.githubusercontent.com/svdijkman/LibeR/v0.9.0-research-beta.3/tools/install-ecosystem.R")
liber_install()
```

The installer reads `ecosystem.json`, installs the six packages in dependency
order, checks the exact versions, and runs `LibeRation::liber_doctor(strict =
TRUE)`. Source packages are the portable default. On Windows with the matching
R release, `liber_install(binary = TRUE)` uses the published precompiled
packages.

## Local source checkout

For development from the repository root, source the installer and install
from the current release manifest:

```r
source("tools/install-ecosystem.R")
liber_install()
```

The file defines `liber_install()` when sourced; release installation remains
explicit so opening the script never changes an R library unexpectedly.

## Diagnose an installation

```r
LibeRation::liber_doctor()
LibeRation::liber_support_matrix()
```

The doctor reports the compatibility set, compiled CppAD/Eigen provenance,
wire contracts, queue capabilities, and optional workspace health.
