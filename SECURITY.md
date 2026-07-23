# LibeR security policy

LibeR is research software. LibeRator is not a medical device, and no package
in this repository is qualified for autonomous clinical decision-making or a
regulatory submission without a separate, documented validation programme.

Please report suspected vulnerabilities privately to the package maintainer at
`svdijkman@users.noreply.github.com`. Do not include patient data, credentials,
private publications, or server payloads in a public issue. A useful report
identifies the package/version, affected platform, minimal reproduction,
security impact, and any temporary mitigation.

Supported security fixes target the most recent ecosystem compatibility set in
`ecosystem.json`. Public remote deployments must use TLS, scoped and expiring
tokens, request throttling, authenticated at-rest storage encryption, and an
external OS-account/container sandbox. LibeRties' built-in restricted R
subprocess is defense in depth, not a hostile-code isolation boundary. Run
`LibeRties::ls_server_preflight(..., strict = TRUE)` before starting a
production service, provide a probe connected to the actual sandbox on
platforms without built-in detection, configure the exact trusted proxy
addresses, and preserve the audit log outside the worker namespace. A
deployment label or forwarded header from an untrusted peer is never accepted
as security evidence.

Patient-facing deployments additionally require a jurisdiction-specific threat
model, identity/access management, backup and recovery validation, key
rotation, retention/deletion policy, monitoring, incident response, software
bill of materials, and independent penetration testing.
