# Non-PK likelihood and latent-state validation

This suite validates LibeRation model families that are not ordinary continuous
PK observations. It deliberately uses two kinds of reference:

1. **Direct NONMEM 7.3 comparisons** for likelihoods that have a faithful
   row-wise NONMEM `LIKELIHOOD` representation: Bernoulli, interval
   time-to-event, and observed discrete-time Markov models.
2. **Independent mathematical references** where NONMEM does not expose a
   like-for-like first-class result: exact state-path enumeration for HMMs,
   analytic two-state matrix exponentials for CTMC/CT-HMM models, and a scalar
   closed-form Kalman filter.

The deterministic suite also covers categorical, count, recurrent-event, and
competing-risk likelihoods. Each run writes `comparisons.csv`, `coverage.csv`,
`summary.json`, `provenance.json`, and a concise Markdown report. A comparison
is never marked as passed when its declared reference was unavailable.

From the consolidated repository root:

```text
Rscript tools/create-validation-library.R --source
Rscript validation/nonpk/run-validation.R --run-nonmem
```

Omit `--run-nonmem` to run the independent-reference suite and reuse existing
NONMEM tables if present. Use `--skip-nonmem` to make the independent suite
fully portable. The stochastic and experimental families (particle filters,
SDE, DDE, QSP, and hybrid learned components) remain under simulation,
convergence, and seed-reproducibility tests; deterministic agreement from this
runner must not be interpreted as clinical qualification.
