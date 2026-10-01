---
applyTo: "apim-artifacts/**,apiops/**"
---

- Follow the APIOps CLI v1 artifact format exactly.
- Use shared artifacts plus environment override files; do not fork the artifact tree per environment.
- APIM-to-Foundry authentication must use `authentication-managed-identity`.
- Do not commit secrets or redacted extraction placeholders.
- Preserve product-to-API associations and backend dependencies.
- Product tiers (`foundry-bronze`, `foundry-silver`, `foundry-gold`) enforce token budgets with `llm-token-limit` in the product policy. Read limits from `tier-<tier>-*` named values and give each tier its own `counter-key` prefix so the counters stay independent.
- `llm-emit-token-metric` belongs once at API scope. It requires the Bicep-owned Application Insights logger plus the service diagnostic with `metrics: true`; do not add `loggers` or `diagnostics` artifacts.
- Do not use destructive `--delete-unmatched` publishing.

