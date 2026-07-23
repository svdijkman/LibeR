# LibeR 0.9 research-beta programme

The research beta prioritises evidence, recoverability, scale, and user
onboarding over additional model families.

## Release gates

1. Every package passes `R CMD check` without errors or warnings on Windows,
   Linux, and macOS.
2. Cross-package model/job/result/workspace contracts pass in an isolated
   installation.
3. Browser regression tests pass at desktop and mobile viewport sizes.
4. The machine-readable support matrix passes `tools/support-matrix-check.R`.
5. Published performance is correctness-gated and retains provenance.
6. NONMEM prediction/estimation and PopED/PFIM design comparisons pass for
   their declared scopes.
7. The 1,000-subject scheduled workflow records cold wall time, startup, core
   time, worker/result payloads, and peak R heap.
8. Source archives, Windows binaries, manuals, API inventory, checksums, and
   release evidence are generated from one clean commit.

## Evidence language

- **Validated**: compared with an independent external implementation or an
  analytic solution under an explicit tolerance.
- **Verified**: deterministic internal, derivative, recovery, property, and
  integration tests are available, without a complete independent reference.
- **Experimental**: implemented for research exploration but not sufficiently
  qualified for routine use.

The canonical declaration is
`LibeRation/inst/ecosystem/support-matrix.csv` and is available at runtime
through `LibeRation::liber_support_matrix()`.

## Package priorities

1. LibeRtAD/LibeRation: numerical correctness, realistic performance, and
   estimator robustness.
2. LibeRties: durable state transitions, restart recovery, deployment
   isolation, and security.
3. LibeRality: broader matched PopED/PFIM design validation.
4. LibeRator: virtual-patient and retrospective research validation; no
   autonomous clinical claims.
5. LibeRary: field-level extraction accuracy and evidence traceability rather
   than new extraction stages.

New major model families remain deferred until the beta gates are stable.
