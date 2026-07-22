# AED-PKPD Reference Corpus

Version: 0.2.2

This corpus is deliberately separate from the live LibeRary catalogue.
The appendix-derived records are silver-tier until independently checked against the source paper.
ADVAN/TRANS and structured demographic fields are inferred from preserved appendix text and must be source-reviewed before strict scoring.
Reproduction targets are intentionally empty until concentration data are extracted from the source figures or tables.
The locked test partition must never be included in RAG indexes, prompts, demonstrations, or training exports.

Use `LibeRary::library_reference_validate()` before benchmarking and
`LibeRary::library_reference_training_export()` to create leakage-checked training data.
