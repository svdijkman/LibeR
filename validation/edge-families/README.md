# Experimental-family edge validation

This campaign extends the canonical experimental-family gate with deliberately
difficult numerical and contract cases:

- multiplicative and nonlinear SDE simulation, plus particle-likelihood
  convergence in a linear-Gaussian limit;
- parameterized DDE delays crossing one or more bolus discontinuities and a
  stiff smooth-history DDE;
- larger block-sparse and coupled index-1 DAE systems;
- a ten-species reaction chain, a stiff reversible reaction, conservation, and
  compact parameter recovery for QSP models; and
- extreme softplus inputs, ReLU branches, spline boundaries/extrapolation,
  anisotropic Gaussian-process inputs, hybrid gradients, and immutable
  component-payload enforcement.

References are exact transition/moment laws, closed-form method-of-steps
solutions, independent Monte Carlo, analytic DAE reductions, exact reaction
solutions, and independent component calculations. The campaign records its
tolerances, seeds, source hashes, package versions, and complete comparison
table.

From the consolidated repository root:

```text
Rscript tools/create-validation-library.R --source
Rscript validation/edge-families/run-validation.R
```

Passing this campaign widens evidence for the named fixtures only. It does not
qualify arbitrary mechanistic systems, clinical use, or unlimited state and
parameter dimensions.
