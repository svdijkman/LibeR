# NONMEM versus LibeRation benchmark: 20260718T093655

## Scope

- Profile: `standard` (100 subjects, 900 input records, 100 simulation replicates).
- Scenario: `oral` — one-compartment first-order oral absorption (ADVAN2/TRANS2).
- Measured repetitions: 1; unmeasured warm-ups: 0.
- Estimation methods: FO, FOCE, FOCEI, LAPLACE.
- LibeRation outer optimizer: `auto`.
- LibeRation population objective: `cpp`.
- Covariance requested where directly comparable: TRUE.

End-to-end time is measured outside a fresh process. NONMEM starts through a fresh PsN `execute` directory; LibeRation starts through a fresh `Rscript --vanilla` process and writes a result summary before exit.
Core time is engine-reported elapsed estimation/covariance time for NONMEM and elapsed `nm_est`/`nm_simulate` time for LibeRation. NONMEM simulation falls back to its reported total CPU time when no simulation-specific elapsed time is available.

A ratio above 1 means NONMEM took longer; below 1 means LibeRation took longer.

## Paired median results

No paired successful measurements were available.

## Numerical sanity check

Relative differences are `(LibeRation - NONMEM) / abs(NONMEM) * 100`. Objective values are not compared because method-specific constants and reported objective definitions can differ.

No paired successful measurements were available.

## Environment

- OS: Windows 10 x64 (x86_64-w64-mingw32)
- CPU: AMD64 Family 23 Model 113 Stepping 0, AuthenticAMD
- R: R version 4.6.0 (2026-04-24 ucrt)
- LibeRation: 0.6.0
- PsN execute: `C:\PORTAB~1\Perl\bin\execute.bat`

## Interpretation limits

- These are matched workflow benchmarks, not proof of mathematical equivalence. Parameter outputs are retained in `raw-results.csv` for sanity checking.
- Fresh-process wall time includes startup and output creation but excludes fixture generation and post-run report parsing for both engines.
- FO/FOCE/FOCEI/LAPLACE have direct method mappings. ITS/IMP/SAEM controls are aligned by iteration/sample counts where possible, but implementation details differ.
- BAYES is intentionally excluded until a matched NONMEM prior specification is defined.
- Run on an otherwise idle machine, keep both engines single-threaded, and use the standard profile for decision-grade comparisons.

