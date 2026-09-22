---
applyTo: ".github/workflows/**/*.yml,.github/workflows/**/*.yaml"
---

- Authenticate to Azure with GitHub OIDC through `azure/login`.
- Use protected `dev` and `prod` GitHub Environments.
- Promote the same commit from dev to prod.
- Add concurrency controls for every environment writer.
- Pin action major versions and tool versions.
- Never echo secrets or Azure access tokens.

