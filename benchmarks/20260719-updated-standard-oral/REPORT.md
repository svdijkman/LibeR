# NONMEM versus LibeRation benchmark: 20260719T132609

> **Historical, not publishable performance evidence.** This run predates the
> correctness-gated benchmark contract, used one measured repetition without
> warm-up, and several methods did not meet acceptable parameter-agreement
> criteria. Retain it for engineering diagnosis only; do not use its timings
> to claim estimator performance or parity.

## Scope

- Profile: `standard` (100 subjects, 900 input records, 100 simulation replicates).
- Scenario: `oral` — one-compartment first-order oral absorption (ADVAN2/TRANS2).
- Measured repetitions: 1; unmeasured warm-ups: 0.
- Estimation methods: FO, FOCE, FOCEI, LAPLACE, ITS, IMP, SAEM.
- LibeRation outer optimizer: `auto`.
- LibeRation population objective: `cpp`.
- Covariance requested where directly comparable: TRUE.

End-to-end time is measured outside a fresh process. NONMEM starts through a fresh PsN `execute` directory; LibeRation starts through a fresh `Rscript --vanilla` process and writes a result summary before exit.
Core time is engine-reported elapsed estimation/covariance time for NONMEM and elapsed `nm_est`/`nm_simulate` time for LibeRation. NONMEM simulation falls back to its reported total CPU time when no simulation-specific elapsed time is available.

A ratio above 1 means NONMEM took longer; below 1 means LibeRation took longer.

## Paired median results

| workload | method | mapping | nonmem_end_to_end_seconds | liberation_end_to_end_seconds | end_to_end_ratio_nonmem_over_liberation | nonmem_core_seconds | liberation_core_seconds | core_ratio_nonmem_over_liberation | nonmem_noncore_overhead_seconds | liberation_noncore_overhead_seconds |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| estimation | FO | direct | 4.630 | 0.860 | 5.384 | 0.260 | 0.470 | 0.553 | 4.370 | 0.390 |
| estimation | FOCEI | direct | 6.690 | 1.010 | 6.624 | 2.410 | 0.670 | 3.597 | 4.280 | 0.340 |
| estimation | LAPLACE | direct | 5.590 | 1.140 | 4.904 | 2.170 | 0.780 | 2.782 | 3.420 | 0.360 |
| estimation | ITS | approximately aligned controls | 47.000 | 1.090 | 43.119 | 42.780 | 0.740 | 57.811 | 4.220 | 0.350 |
| estimation | IMP | approximately aligned controls | 161.440 | 6.010 | 26.862 | 156.860 | 5.670 | 27.665 | 4.580 | 0.340 |
| estimation | SAEM | approximately aligned controls | 8.610 | 4.890 | 1.761 | 4.930 | 4.580 | 1.076 | 3.680 | 0.310 |
| simulation | SIMULATION | direct | 15.190 | 1.420 | 10.697 | 9.844 | 1.070 | 9.200 | 5.346 | 0.350 |

## Numerical sanity check

Relative differences are `(LibeRation - NONMEM) / abs(NONMEM) * 100`. Objective values are not compared because method-specific constants and reported objective definitions can differ.

| method | mapping | theta1_relative_difference_percent | theta2_relative_difference_percent | omega1_relative_difference_percent | sigma1_relative_difference_percent |
| --- | --- | --- | --- | --- | --- |
| FO | direct | 0.579 | 0.000 | 524.598 | 1.242 |
| FOCEI | direct | 20.899 | 0.000 | 430.399 | -93.871 |
| LAPLACE | direct | 5.686 | 0.000 | 198.415 | -95.467 |
| ITS | approximately aligned controls | 150.692 | -85.000 | 204.425 | -67.428 |
| IMP | approximately aligned controls | 32.267 | 1399.985 | 313.069 | 0.188 |
| SAEM | approximately aligned controls | 33.949 | -85.000 | 1031.266 | 136970933019.795 |

## Environment

- OS: Windows 10 x64 (x86_64-w64-mingw32)
- CPU: AMD64 Family 23 Model 113 Stepping 0, AuthenticAMD
- R: R version 4.6.0 (2026-04-24 ucrt)
- LibeRation: 0.6.2
- PsN execute: `C:\PORTAB~1\Perl\bin\execute.bat`

## Interpretation limits

- These are matched workflow benchmarks, not proof of mathematical equivalence. Parameter outputs are retained in `raw-results.csv` for sanity checking.
- Fresh-process wall time includes startup and output creation but excludes fixture generation and post-run report parsing for both engines.
- FO/FOCE/FOCEI/LAPLACE have direct method mappings. ITS/IMP/SAEM controls are aligned by iteration/sample counts where possible, but implementation details differ.
- BAYES is intentionally excluded until a matched NONMEM prior specification is defined.
- Run on an otherwise idle machine, keep both engines single-threaded, and use the standard profile for decision-grade comparisons.

