# Validation strategy

Validation is layered so a defect cannot hide behind agreement between two
paths sharing the same implementation.

Published performance results are now **correctness gated**. A timing record is
publishable only when `nm_validation_gate()` passes the declared objective,
parameter, ETA, and prediction tolerances and at least three post-warm-up timing
repetitions are present. Reports must retain `nm_benchmark_provenance()`, which
records the R/platform, package and compiled-engine versions, commit identifier,
warm-up count, and repetition count. A fast run with materially different
estimates is a failed validation, not a speed result.

1. **Closed-form unit tests**: one-compartment bolus, infusion, oral input,
   accumulation ratios, equal-rate limits, and mass balance.
2. **Backend cross-checks**: optimized ADVAN predictions against the independent
   matrix backend across randomized parameters, routes, and event schedules.
   ADVAN6 is checked against closed forms, and ADVAN13 against deliberately
   stiff linear systems with known solutions.
3. **Derivative checks**: AD Jacobians/Hessians against high-accuracy finite
   differences, including nearly coincident rates and steady-state solves.
4. **NONMEM/PsN comparisons**: generated control streams run through `execute`
   and compared on predictions, objectives, gradients where exposed, estimates,
   covariance results, ETAs, and simulation summaries.
5. **Method matrix**: FO, FOCE, FOCEI, Laplace, ITS, IMP, SAEM, BAYES, mixtures,
   IOV, BLQ/censoring, and priors each receive deterministic compact fixtures.
6. **Queue parity**: the same serialized job must produce equivalent local and
   LibeRties-worker results, with package/version fingerprints recorded.

## LibeRality external optimal-design validation

`validation/liberality/external/run-validation.R` independently constructs
matched population-FO designs in LibeRality, PopED 0.7.0, and PFIM 7.0.3. The
suite compares complete Fisher matrices after transforming PFIM residual-error
standard deviations to LibeRality's variance scale. It additionally compares
RSEs and log determinants, records setup, cold, warm-core, and end-to-end
runtimes, and checks that all engines select the same candidate in a matched
D-optimal grid search.

Fixtures cover one-compartment oral/proportional, IV-bolus/additive, and
oral/independent-combined designs. PFIM's `Combined1` implements
`(a + b*f)^2`, not the independent `a^2 + b^2*f^2` convention used by
LibeRality and PopED; the suite records that coverage limitation explicitly
instead of comparing non-equivalent models. Every run writes complete matrices,
CSV summaries, RDS and JSON results, and a self-contained HTML report, and
exits non-zero when a declared numerical or design-ranking tolerance fails.

The July 2026 Windows baseline passed all seven supported comparisons. Across
the suite, the largest absolute FIM element difference was `3.57e-6`, the
largest relative Frobenius difference was `3.67e-11`, and the largest RSE
difference was `3.79e-9` percentage points. LibeRality, PopED, and PFIM all
selected the `0.1 h` candidate and agreed on the D-optimal log determinant to
better than `3.1e-10`.

NONMEM tests are opt-in and skip with an explicit reason when `execute` is not
available. Test fixtures contain generated data and model code, not proprietary
NONMEM examples.

The specialized ADVAN1-4/11/12 AD transitions are additionally checked against
the retained general Pade affine propagator for complete prediction values and
every THETA/ETA/SIGMA Jacobian column. The comparison covers bolus and periodic
steady-state infusion event paths. Arbitrary matrix graphs are asserted to stay
on the general kernel. Prediction-tape metadata exposes the selected kernel and
optimized operation count so a dispatch regression cannot silently pass only
on numerical equivalence.

## Current NONMEM 7.3 prediction benchmark

`validation/nonmem/run-validation.R` executes independent generated fixtures
through PsN and compares observation-record `IPRED` values with LibeRation.
The July 2026 Windows benchmark produced:

| Fixture | Maximum absolute difference | Compared records |
|---|---:|---:|
| ADVAN1 | 1.43683332e-9 | 6 |
| ADVAN2 | 2.99838998e-9 | 6 |
| ADVAN3 | 4.42779680e-9 | 6 |
| ADVAN4 | 1.09334830e-9 | 6 |
| ADVAN11 | 4.55660842e-9 | 6 |
| ADVAN12 | 1.91085725e-9 | 6 |
| ADVAN6 | 3.30286110e-9 | 6 |
| ADVAN13 | 7.83511256e-10 | 6 |
| ADVAN1 repeated bolus steady state | 3.46666562e-9 | 4 |
| ADVAN1 intermittent-infusion steady state | 3.99814670e-9 | 6 |
| ADVAN1 modelled rate (`RATE=-1`, `R1`) | 4.35503544e-9 | 6 |
| ADVAN1 modelled duration (`RATE=-2`, `D1`) | 4.35503544e-9 | 6 |

The compact FOCEI benchmark estimates clearance with fixed residual and random
effect variances, then compares the final fixed effect and every subject ETA.
Against NONMEM 7.3, the July 2026 benchmark gave an absolute THETA1 difference
of `1.28471e-4` and a maximum ETA1 difference of `7.29743e-5`.

Run the benchmark from `validation/nonmem` after installing the three local
packages:

```r
Rscript run-validation.R --run
```

Without `--run`, existing NONMEM tables are reused. The runner still checks
record alignment and numerical tolerances, and it fails if PsN reports success
without producing a NONMEM listing and the expected table.
