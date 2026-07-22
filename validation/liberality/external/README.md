# LibeRality external validation

This suite compares complete population-FO Fisher information matrices from
LibeRality, PopED and PFIM after harmonising parameter names and residual-error
parameterisation. It also compares RSEs and log determinants, records cold and
warm runtimes, and runs a matched D-optimal candidate-grid search.

The versioned fixtures cover:

- One-compartment oral PK with log-normal IIV and proportional error.
- One-compartment IV-bolus PK with log-normal IIV and additive error.
- One-compartment oral PK with independent additive and proportional errors.

PFIM 7.0.3 defines `Combined1` as `(a + b*f)^2`; it does not implement the
independent `a^2 + b^2*f^2` convention used by LibeRality and PopED. The
combined fixture is consequently validated against PopED and recorded as
unsupported for PFIM rather than treated as a numerical failure.

Install the isolated dependencies from the repository root:

```powershell
Rscript validation/liberality/external/install-dependencies.R
```

Run the full suite:

```powershell
Rscript validation/liberality/external/run-validation.R --repetitions=10
```

The script returns a non-zero status on a numerical or grid-search failure.
Generated artifacts include the complete matrices, comparison and timing CSVs,
an RDS result, a JSON manifest and a self-contained HTML report.

## July 2026 baseline

The committed Windows baseline used LibeRality 0.1.1, PopED 0.7.0 and PFIM
7.0.3. All seven declared pairwise comparisons passed. The largest absolute FIM
element difference was `3.57e-6`, the largest relative Frobenius difference was
`3.67e-11`, and the largest absolute RSE difference was `3.79e-9` percentage
points. All three engines selected `0.1 h` in the oral D-optimal candidate-grid
search and returned a log determinant of approximately `41.23505`.

For the oral/proportional fixture, median warm core evaluations were about 4.0
ms (LibeRality), 5.8 ms (PopED), and 48.4 ms (PFIM) on the validation machine.
These small-fixture timings are implementation diagnostics, not general claims
about package speed; the numerical agreement and selected design are the
primary validation endpoints. See `baseline/report.html` and the CSV/RDS/JSON
files beside it for the complete result.
