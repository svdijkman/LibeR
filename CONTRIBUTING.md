# Contributing to LibeR

LibeR welcomes reproducible bug reports, independent numerical comparisons,
documentation improvements, and focused code contributions. The consolidated
repository is the authoritative source for the six-package compatibility set;
the individual package repositories are release mirrors.

## Reporting problems

Use the issue form matching the problem. Numerical disagreements should state
the independent reference, model parameterisation, seed, stopping criteria,
tolerances, and quantitative differences. Performance reports should separate
cold end-to-end, warm end-to-end, core execution, peak memory, and GUI latency.

Create a redacted diagnostic archive with:

```r
LibeRation::liber_support_bundle()
```

The default archive contains runtime and structural metadata but not datasets,
model code, parameter estimates, environment variables, credentials, patient
identifiers, or workspace contents. Inspect every archive before sharing it.

## Development

Work from the consolidated repository and keep changes inside the owning
package. Add a NEWS entry and tests. Numerical changes require an independent
comparison wherever one exists; agreement between two paths sharing the same
implementation is not sufficient evidence.

Before submitting:

```text
Rscript tools/ci-check.R
Rscript tools/integration-check.R
Rscript tools/browser-check.R
```

External NONMEM, PopED, and PFIM validation is run separately because those
tools are not all available in ordinary CI.

## Safety

Never commit or attach patient data, credentials, private publications,
institutional tokens, server payloads, user workspaces, or unredacted logs.
Security vulnerabilities must be reported privately as described in
`SECURITY.md`.
