# Experimental-family numerical validation

This campaign validates the canonical numerical contracts underlying
LibeRation's experimental SDE, DDE, DAE, QSP, and offline hybrid-component
families. These families do not have one universal external reference engine,
so each fixture uses an independently derived mathematical invariant:

- an Ornstein--Uhlenbeck transition law and scalar Kalman recursion for SDE
  filtering, plus seeded Monte Carlo moment calibration for simulation;
- a closed-form method-of-steps solution for a linear DDE with continuous
  initial history, including the derivative with respect to the delay;
- a nonlinear index-1 DAE with an analytic reduced solution and sensitivity;
- a first-order two-species QSP reaction with exact amounts, mass conservation,
  and parameter sensitivity;
- independent dense-network, spline, Gaussian-process, and learned-dynamics
  calculations for immutable offline hybrid components.

The runner writes comparison, convergence, coverage, JSON, provenance, and
Markdown evidence. Passing these canonical fixtures validates the implemented
numerical contracts; it does **not** qualify every possible nonlinear system or
make the experimental families suitable for clinical use.

Delay sensitivities are qualified for continuous histories. A parameterised
delay that moves an instantaneous event across the history boundary is
non-smooth and requires explicit event-sensitivity handling; it is intentionally
outside this validation claim.

From the consolidated repository root:

```text
Rscript tools/create-validation-library.R --source
Rscript validation/experimental-families/run-validation.R
```
