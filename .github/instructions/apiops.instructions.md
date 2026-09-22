---
applyTo: "apim-artifacts/**,apiops/**"
---

- Follow the APIOps CLI v1 artifact format exactly.
- Use shared artifacts plus environment override files; do not fork the artifact tree per environment.
- APIM-to-Foundry authentication must use `authentication-managed-identity`.
- Do not commit secrets or redacted extraction placeholders.
- Preserve product-to-API associations and backend dependencies.
- Do not use destructive `--delete-unmatched` publishing.

