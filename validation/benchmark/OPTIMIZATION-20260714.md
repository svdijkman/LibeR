# LibeRation estimator optimization results (2026-07-14)

The final optimized LibeRation build was measured on the standard fixture
(100 subjects, 800 records, one core). Current LibeRation results are one
fresh-process measurement. The pre-optimization LibeRation and NONMEM values
are medians of the three original validation repetitions. Core time includes
fitting and the covariance step where applicable.

| Method | Original LibeRation core (s) | Final LibeRation core (s) | Overall speed-up | NONMEM core (s) | Final LibeRation end-to-end (s) | NONMEM end-to-end (s) |
|---|---:|---:|---:|---:|---:|---:|
| FO | 4.10 | 0.37 | 11.1x | 0.08 | 0.70 | 3.37 |
| FOCE | 16.25 | 1.27 | 12.8x | 0.52 | 1.57 | 4.37 |
| FOCEI | 22.02 | 1.26 | 17.5x | 0.61 | 1.61 | 4.39 |
| Laplace | 24.72 | 1.00 | 24.7x | 1.00 | 1.33 | 4.44 |
| ITS | 16.97 | 0.49 | 34.6x | 6.53 | 0.82 | 10.40 |
| IMP | 90.11 | 12.53 | 7.2x | 79.17 | 12.85 | 82.76 |
| SAEM | 24.74 | 4.89 | 5.1x | 3.18 | 5.17 | 6.51 |

Standard simulation took 0.74 seconds core and 1.03 seconds end to end. The
original NONMEM medians were 7.97 and 11.89 seconds, respectively.

The small NONMEM core times for deterministic methods are listing-derived and
coarsely rounded. End-to-end time is the more stable operational comparison:
the final LibeRation process was faster in every row of this fixture. These
remain development measurements, not decision-grade repeated benchmarks.

## Implemented derivative architecture

- The user's R model is still supported. R code is parsed into the serializable
  LibeRtAD expression IR and the complete model/event calculation is then
  recorded and evaluated in C++; a C++ model specification uses the same
  downstream tapes.
- FO now has a persistent scalar CppAD tape for its complete marginal Gaussian
  objective: ETA linearization, residual covariance, full/IOV OMEGA,
  differentiable Cholesky log determinant, and quadratic term.
- FOCE, FOCEI, and Laplace use native C++ conditional ETA BFGS, persistent
  conditional-objective tapes, and implicit differentiation of the optimized
  ETA modes.
- The curvature contribution is also taped. FOCE/FOCEI differentiate the
  Gauss-Newton curvature; Laplace differentiates the exact conditional Hessian
  and its determinant, including the required third-order information. There
  is no finite-difference curvature remainder.
- ITS uses the exact envelope gradient. SAEM M-steps use batched exact CppAD
  conditional gradients.
- Hessian covariance steps for FO/FOCE/FOCEI/Laplace/ITS now differentiate the
  supplied population gradient rather than repeatedly rebuilding a fully
  numerical first derivative.
- Existing native ETA warm starts, derivative subsets, batched IMP/SAEM
  evaluation, persistent parallel workers, and covariance-context reuse remain
  in place.

IMP deliberately retains the common-random-number numerical population
gradient. Differentiating its finite-sample, parameter-dependent importance
proposal requires the proposal-mode, proposal-curvature, and reparameterized
sample derivatives. Substituting a fixed-sample score would optimize a
different finite Monte Carlo objective, so that shortcut was not used.

## Numerical regression

The new population gradients were compared against independently re-optimized
central differences for ITS, FOCE, FOCEI, and Laplace. Relative discrepancies
on the fixture were approximately 1e-6 or smaller (the limiting difference is
the conditional-mode optimization tolerance); FO tape gradients agreed to
about 1e-9. Taped curvature values match the reference calculations to machine
precision.

Against the preceding optimized build, maximum relative parameter changes on
the standard fixture were below 0.0002% for every method. FO tape coverage was
also checked for additive, proportional, exponential, combined, power, and
AR(1) residual models, plus full OMEGA, IOV, priors, and Windows PSOCK workers.

Raw final outputs are in `results/ad-population-final-20260714`. Intermediate
measurements are retained in `results/population-gradient-final-20260714`,
`results/fo-ad-final-20260714`, and `results/exact-curvature-final-20260714`.
The original paired NONMEM/LibeRation outputs are in
`results/standard-deterministic-20260714`.
