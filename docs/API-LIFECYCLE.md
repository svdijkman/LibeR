# Public API lifecycle

Only exported functions documented in a package manual are public API.
Unexported functions, R6 private members, widget payload fields, and C++ headers
outside the installed `LibeRtAD` interface are internal and may change between
minor releases.

Breaking changes to exported functions, semantic model contracts, job/result
wire formats, or durable workspace schemas require a major/minor compatibility
set, a reader/migration path for the previous version, and explicit NEWS
entries. Deprecations should warn for at least one compatibility release before
removal. Contract fixtures in LibeRation, LibeRality, and LibeRties are the
executable specification for cross-package interoperability.
