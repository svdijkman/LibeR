# Estimation-method validation

This campaign is the release gate for every estimation algorithm exposed by
`LibeRation::nm_est()`. It deliberately does not treat “the fit returned” as
validation.

The methods use the strongest applicable reference:

- FO, FOCE, FOCEI, Laplace, ITS, IMP, and SAEM use generated, matched NONMEM
  7.3 control streams. The deterministic methods are direct mappings; the
  stochastic methods additionally have independent-reference checks because
  finite stochastic runs are not expected to be numerically identical.
- GQ is compared with base-R adaptive integration of the one-dimensional
  subject likelihood and an independently optimized exact marginal maximum.
- BAYES, HMC, and NUTS are compared with a normalized marginal posterior
  obtained by adaptive ETA integration and numerical integration over the
  bounded population parameter. Sampler convergence, effective sample size,
  divergence, and acceptance diagnostics are gated where available.
- NPML is compared with an independent fixed-support EM implementation. NPAG
  must reproduce its reported final likelihood independently and must not
  reduce the optimized likelihood relative to its fixed starting grid.

The compact fixture fixes residual and random-effect variances and estimates
one bounded fixed effect. This isolates each algorithm from unrelated
multi-parameter identifiability and makes an independent high-accuracy
reference practical. Broader ADVAN, dosing, OMEGA, residual-error, and
covariance validation remains in the separate model and scenario matrices.

Run the portable independent-reference campaign:

```text
Rscript tools/create-validation-library.R --source
Rscript validation/estimation-methods/run-validation.R
```

Run the complete gate, including generated NONMEM jobs through PsN:

```text
Rscript validation/estimation-methods/run-validation.R --run-nonmem
```

Use `--quick` only while developing the harness. A quick run uses fewer
stochastic draws and records that reduced profile in its provenance.
