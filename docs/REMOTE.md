# Remote execution

LibeRties provides the same durable queue behind local and authenticated HTTP
interfaces. A remote user cannot select a filesystem namespace: every job
operation derives the tenant from a 256-bit bearer token. Only a SHA-256 token
digest is stored in the server registry.

## Start a development server

```r
library(LibeRties)

root <- "D:/liberties-data"
user <- ls_user_create(
  root,
  "alice",
  limits = list(max_concurrent_jobs = 2L, max_queued_jobs = 20L),
  scopes = c("jobs:read", "jobs:write"),
  expires = Sys.time() + 90 * 24 * 3600
)

# Store user$token in a secret manager; it is shown only at creation.
Sys.setenv(LIBERTIES_STORAGE_KEY = ls_generate_storage_key())
ls_server_preflight(root, "127.0.0.1")
ls_run_api(root, host = "127.0.0.1", port = 8000L, production = FALSE)
```

Connect from the modelling workstation:

```r
remote <- ls_remote(
  "https://liberties.example.org",
  Sys.getenv("LIBERTIES_TOKEN")
)

id <- remote$submit(ls_job("simulate", model, data))
remote$status(id)
result <- remote$result(id)
```

LibeRary triage, parsing, text extraction, PDF-vision extraction, assessment,
and adjudication can use the same queue through `library_job()`. PDF or parsed
text transfer requires explicit confirmation. The remote worker must have
LibeRary, Docling plus its PDF dependencies, and the selected LLM provider
credentials installed/configured. Credentials are read from the server
environment and are not included in the job payload.

The typed literature job names are `library_triage`, `library_parse`,
`library_index`, `library_dual_extract`, `library_assess`, and
`library_adjudicate`. A worker stores temporary document bundles inside its
job-specific directory and returns structured results; it never publishes into
the client's catalogue implicitly.

The LibeRation Jobs tab stores remote client definitions, the selected queue,
and the bearer token in `<workspace>/.liberation/client-settings.rds`. This file
is outside the package library, is written atomically, and is restricted to the
current user (`0600`) where the platform supports POSIX permissions. Editing a
remote without entering a replacement token retains the existing token. Remove
the queue from the Jobs tab to remove its saved client definition.

The local queue itself is stored in `<workspace>/.jobs`. LibeRation loads that
history before the first workbench render and polls it once the browser session
is ready, so queued, running, and completed work is visible after restarting R.
Server-side users and job history remain under `LIBERTIES_ROOT` (or
`options(LibeRties.root = ...)`); package installation directories are never
used for durable state.

The repository smoke test starts a loopback server, submits an ADVAN1 job, and
retrieves its C++ result:

```r
Rscript tools/smoke-remote.R
```

## Security boundary

- The public API accepts `liber.job.wire/2` JSON (and reads version 1 only for
  migration compatibility). It has no RDS upload or arbitrary-code endpoint.
- The receiver recompiles semantic model text with `nm_model()` and does not
  trust client-provided expression IR.
- Payloads cannot contain functions, calls, environments, weak references, or
  external pointers.
- Job and result files use SHA-256 integrity digests. When
  `LIBERTIES_STORAGE_KEY` is configured, internal RDS metadata, payloads, and
  results are additionally authenticated-encrypted at rest.
- User identifiers and job identifiers are validated path components, and all
  API operations derive the user from the bearer token.
- Scoped, optionally expiring bearer tokens and request throttling constrain
  access; user/token administration is retained in a hash-chained audit log.
- Queue, payload, result-download, storage, wall-time, CPU-time, complete
  process-tree size, and resident memory limits are enforced per tenant and
  recorded in job provenance.
- Metadata updates are lock-protected state transitions, so cancellation or a
  resource failure cannot be overwritten by a late worker completion.
- API responses disable caching and framing. Cross-origin access is not enabled
  by default.

For a remote deployment, keep the R service on a private/loopback interface and
terminate TLS at a maintained reverse proxy. `ls_server_preflight()` checks the
declared TLS, at-rest encryption, and OS-isolation boundary and production mode
fails closed. The worker boundary is a fresh
restricted R subprocess, scrubbed startup environment, single-thread numerical
environment, job-specific working directory, and tenant-specific storage.
Resource monitoring also survives queue-controller restarts by verifying PID
creation times before acting on a recovered worker. Production hosting must
still add OS-account or container isolation; an R subprocess alone is not
claimed as a hostile-code sandbox.
