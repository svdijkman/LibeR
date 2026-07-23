# LibeRary reference qualification

LibeRary keeps appendix-derived Tier C/D references separate from independently
verified Tier A/B records. Silver results are valuable for development but must
not be described as gold-standard validation.

After a protected Tier A/B corpus has been scored with
`library_reference_benchmark()`, qualify it explicitly with:

```r
report <- library_reference_benchmark(corpus, predictions, partition = "test")
library_reference_release_gate(report, error = TRUE)
```

The default gate requires at least 20 strict records, complete strict
predictions, high field/semantic coverage, and high numeric accuracy. Thresholds
are arguments so a protocol can pre-specify them, but lowering them must be an
explicit, auditable choice. No current silver AED appendix result can satisfy
this gate.
