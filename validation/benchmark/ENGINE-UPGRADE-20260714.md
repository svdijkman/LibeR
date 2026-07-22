# Population engine upgrade (2026-07-14)

This pass moves repeated subject work into compiled population kernels and adds
the safeguards and observability needed to tune them without hiding numerical
regressions.

## Implemented

- Conditional ETA modes are evaluated for a subject batch in one C++ call.
- FOCE/FOCEI/Laplace population gradients now perform conditional gradients,
  mixed Hessians, implicit ETA sensitivities, and curvature derivatives in one
  compiled batch call.
- Importance samples return objective values and CppAD scores together. IMP
  defaults to the normalized target-score gradient; `imp_gradient="finite_crn"`
  retains the finite common-random-number objective without that approximation.
- SAEM Metropolis updates are batched in C++, adapt their proposal scale during
  burn-in, update OMEGA from sufficient statistics, and use a closed-form SIGMA
  update for additive, proportional, and exponential residual models.
- Identical event/covariate layouts share prediction tapes. Observation-specific
  objective tapes remain separate. ADVAN6/13 retape after material movement from
  the recorded adaptive trajectory; analytical ADVANs avoid this guard entirely.
- A compiled scaled box-constrained BFGS optimizer is available. Calibration
  showed that R's mature L-BFGS-B/BFGS line search currently needs fewer
  population-objective evaluations, so `optimizer_backend="auto"` selects that
  path while retaining the compiled objective/gradient kernels.
- FO, FOCE, FOCEI, Laplace, and ITS now give L-BFGS-B/BFGS thin callbacks to a
  persistent C++ population-objective object. It owns parameter transforms,
  priors, conditional warm starts, curvature derivatives, ODE retaping, and
  value/gradient state. A gradient request at the same point reuses the modes
  calculated by the preceding objective request. PSOCK runs retain R as their
  necessary cross-process coordinator.
- Deterministic R/Hessian covariance objectives use the same persistent C++
  evaluator. `options(LibeRation.cpp_population_objective=FALSE)` retains the
  preceding implementation as a numerical and performance comparator.
- Covariance supports R/Hessian, S/OPG, R-inverse S R-inverse sandwich, and an
  automatic conditioning-based fallback. FO subject scores and conditional
  curvature contributions are differentiated exactly.
- Fit and benchmark results retain objective/gradient counts, conditional-mode
  work, optimizer trace/backend, tape records/retapes, and structural sharing.
- ADVAN1-4/11/12 prediction tapes select specialized scalar-generic
  propagation. ADVAN1-4 use closed low-dimensional transitions; ADVAN11/12
  retain robust native-dimension Pade transitions while avoiding affine
  augmentation. The preceding general matrix path remains available as a
  test-only option.
- The benchmark now supports IV bolus, oral, two- and three-compartment, full
  OMEGA, steady-state infusion, IOV, ADVAN6, and ADVAN13 scenarios. The matrix
  runner aggregates all scenario summaries.

## Calibration measurements

All measurements below used one core and fresh R processes where reported. They
are development checks, not repeated decision-grade benchmarks.

| Check | Earlier core | Current core | Result |
|---|---:|---:|---:|
| Standard FOCEI, fit + covariance | 1.26 s | 0.95 s | 1.33x faster |
| Standard IMP, fit only | 12.53 s | 2.70 s | 4.64x faster |
| Standard SAEM, fit only | 4.89 s | 4.62 s | 1.06x faster |

The subsequent persistent-objective calibration used three measured fresh
processes after one warm-up on the standard 100-subject FOCEI fixture:

| Scope | R-orchestrated objective | Persistent C++ objective | Result |
|---|---:|---:|---:|
| Fit core | 0.74 s | 0.41 s | 1.80x faster |
| Fit end to end | 1.01 s | 0.67 s | 1.51x faster |
| Fit + covariance core | 1.03 s | 0.52 s | 1.98x faster |
| Fit + covariance end to end | 1.33 s | 0.81 s | 1.64x faster |

The measured FOCEI objective differed by about `6e-9`, and the reported THETA,
OMEGA, and SIGMA estimates agreed to the displayed benchmark precision. The
current 0.52-second fit-plus-covariance core is 2.42x faster than the
1.26-second pre-upgrade baseline in the first table.

The current FOCEI run used 14 objective and 14 gradient evaluations, shared 99
of 100 prediction-tape structures, and performed no retapes. The quick native
outer-optimizer calibration reached the same FOCEI solution but required 26
objective evaluations versus 11 for R's optimizer; this is why auto selection
does not currently choose native BFGS.

Raw checks are retained in:

- `results/batched-population-guard-final`
- `results/imp-score-guard-final`
- `results/saem-guard-final`
- `results/native-optimizer-scaled-check`
- `results/r-optimizer-check`
- `results/cpp-population-focei-standard`
- `results/r-population-focei-standard`
- `results/cpp-population-focei-cov-standard`
- `results/r-population-focei-cov-standard`

The scenario harness itself was smoke-tested in `results/scenario-harness-check`.
The persistent FOCEI objective, covariance, and simulation paths passed all nine
scenarios in `results/cpp-population-matrix-smoke`.

## Specialized ADVAN tape microbenchmark

A focused 680-row, 20-subject benchmark records prediction tapes and repeatedly
evaluates their complete value/Jacobian calculation. This isolates the work
changed by the propagation kernels; it is not an end-to-end estimation
benchmark. Against the former general affine matrix exponential, optimized tape
operations fell by 92.7-99.4% for ADVAN1-4 across bolus and infusion regimens.
Measured Jacobian evaluation was 8.6-46.9x faster in this deliberately dense
microbenchmark. ADVAN11/12 pure-bolus tapes were unchanged because CppAD already
removed the all-zero affine column; infusion tapes fell by 12.4-13.0% in
operations and evaluated 1.17-1.22x faster.

The reproducible script and raw output are retained in
`advan-kernel-benchmark.R` and `results/advan-specialized-20260714`.
