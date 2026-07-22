# Safe training-export preview

This preview intentionally contains zero JSONL examples. Version 0.1.2 of the
reference corpus is still entirely C/D silver-tier, and no model has yet been
marked training-eligible after source-paper review.

`candidates.json` records why every candidate was skipped. After reviewed A/B
decisions are applied with `library_reference_revise()`, rerun
`library_reference_training_export()` against the successor corpus version.

Do not bypass this guard for a production adapter. `allow_silver = TRUE` is
available only for clearly labelled experiments and never permits test data.
