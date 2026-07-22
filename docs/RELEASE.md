# Release and source-of-truth policy

This repository root is the authoritative source for the six-package LibeR
compatibility set. Package archives, check directories, installed libraries,
benchmark outputs, user workspaces, and deployment bundles are generated
artefacts and are not source. `ecosystem.json` pins the package versions and
wire/workspace contracts released together.

Every release must:

1. pass package checks on Windows, Linux, and macOS;
2. pass cross-package wire, queue, and workspace integration tests;
3. pass the browser regression suite at desktop and mobile viewport sizes;
4. publish performance only after `nm_validation_gate()` passes correctness;
5. run the scheduled NONMEM, PopED, and PFIM external validation matrix;
6. regenerate help, vignettes, manuals, source/binary archives, checksums, and
   the compatibility manifest; and
7. be tagged from the exact source commit used to build the artefacts.

Use `Rscript tools/release.R` from a clean checkout. It refuses a version
mismatch between package DESCRIPTION files and `ecosystem.json`, builds into a
release-specific directory, and writes SHA-256 checksums. Release notes must
name skipped external tools and must not promote experimental smoke tests to
reference validation.
