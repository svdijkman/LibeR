# AED-PKPD LibeRary baseline

Corpus: `aed-pkpd-reference` 0.1.2  
Run date: 16 July 2026  
Partition: locked test set, 22 appendix model records  
Numeric tolerance: 5% relative plus `1e-8` absolute

These are **silver-reference development results**, not validated scientific
accuracy estimates. All test records are currently tier C/D; no A/B records
have yet been independently checked in full against their publications.

## Text-only frozen baseline

Provider/model: Ollama `qwen2.5:7b-instruct`  
Pipeline: source PDF text -> strict LibeRary extraction JSON  
Completed: 22/22, no failed articles  
Observed wall time: approximately 646 seconds across the initial one-paper run
and the resumable remaining batch, including their R startup/wrap-up phases.

| Metric | Result |
|---|---:|
| Scalar-field coverage | 81.5% |
| Composite scalar score | 35.9% |
| Numeric parameter coverage | 67.6% |
| Covered numeric values within tolerance | 31.1% |
| Additional numeric predictions not represented in the appendix | 90 |

The scalar score combines exact normalized categorical matching and token-F1
for longer text. Additional numeric predictions are deliberately called
*unverified extras*: the silver appendix may omit information and therefore
cannot establish that every extra is hallucinated.

Machine-readable results are in `text-current/report/summary.json`, with one
row per model in `per_record.csv` and field details in `details.json`.

## Dual-pipeline smoke test

One protected paper was processed with:

- text: Ollama `qwen2.5:7b-instruct`;
- vision: Ollama `qwen3.5:9b`; and
- adjudication: Ollama `qwen3.5:9b`.

The complete run took approximately 230 seconds, including document-bundle
creation. Text and vision disagreed on 21 material claims (agreement 0.087), so
the final status correctly remained `needs_review`. The reconciled output used
the stronger text candidate for this paper.

| Variant | Scalar coverage | Scalar score | Numeric coverage | Numeric accuracy |
|---|---:|---:|---:|---:|
| Text | 100.0% | 38.6% | 100.0% | 50.0% |
| Vision | 66.7% | 13.2% | 66.7% | 0.0% |
| Reconciled | 100.0% | 38.6% | 100.0% | 50.0% |

This single-paper comparison only validates execution and variant scoring; it
is far too small to compare modalities generally. A complete dual baseline can
be resumed with `library_reference_run(..., extraction_mode = "dual")` after
the reference review has promoted a useful A/B test subset.
