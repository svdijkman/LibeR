#!/usr/bin/env Rscript

# Re-run only the saved synthetic adjudication inputs against the temporary
# memory-optimized Ollama endpoint. Text/vision extraction is deliberately not
# repeated, so elapsed time is directly comparable with adjudication-result.json.

root <- normalizePath("validation/liberary-e2e-probe", winslash = "/", mustWork = TRUE)
pkgload::load_all("LibeRary", quiet = TRUE)

dual <- jsonlite::read_json(
  file.path(root, "dual-result.json"),
  simplifyVector = FALSE
)
bundle <- ingest_read_document_bundle(
  file.path(root, "library/documents/synthetic-e2e/02d9dfc979629586/bundle.json")
)

cfg <- ingest_load_config()
cfg$ollama$num_ctx <- 8192L
cfg$ollama$num_predict <- 3072L
cfg$ollama$timeout_seconds <- 1800L
cfg$llm$providers$ollama$base_url <- "http://127.0.0.1:11435"
cfg$llm$adjudication <- list(
  provider = "ollama",
  model = "qwen3.6:27b",
  temperature = 0,
  num_ctx = 8192L,
  num_predict = 3072L,
  timeout_seconds = 1800L,
  think = FALSE
)
cfg <- ingest_validate_config(cfg)

started <- Sys.time()
result <- ingest_adjudicate_extractions(
  metadata = list(id = "synthetic-e2e"),
  text = dual$text,
  vision = dual$vision,
  comparison = dual$comparison,
  bundle = bundle,
  cfg = cfg
)
elapsed <- unname(as.numeric(difftime(Sys.time(), started, units = "secs")))

output <- list(
  experiment = list(
    description = "Saved adjudicator-only rerun with Flash Attention and q8_0 KV cache",
    endpoint = cfg$llm$providers$ollama$base_url,
    model = cfg$llm$adjudication$model,
    num_ctx = cfg$llm$adjudication$num_ctx,
    num_predict = cfg$llm$adjudication$num_predict,
    flash_attention = TRUE,
    kv_cache_type = "q8_0",
    elapsed_seconds = elapsed,
    completed_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%OS3Z", tz = "UTC")
  ),
  adjudication = result
)

jsonlite::write_json(
  output,
  file.path(root, "adjudication-result-27b-optimized.json"),
  auto_unbox = TRUE,
  pretty = TRUE,
  null = "null",
  digits = NA
)

cat(jsonlite::toJSON(list(
  available = isTRUE(result$available),
  elapsed_seconds = elapsed,
  prompt_md5 = result$audit$prompt_md5 %||% NA_character_,
  prompt_chars = result$audit$prompt_chars %||% NA_integer_,
  input_tokens = result$audit$usage$input_tokens %||% NA_integer_,
  output_tokens = result$audit$usage$output_tokens %||% NA_integer_,
  done_reason = result$audit$usage$done_reason %||% NA_character_,
  error = result$error %||% ""
), auto_unbox = TRUE, pretty = TRUE, null = "null"), "\n")
