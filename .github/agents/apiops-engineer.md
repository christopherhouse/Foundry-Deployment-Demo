---
name: apiops-engineer
description: Implements APIOps CLI artifacts, policies, products, backends, overrides, extraction filters, and release workflows.
---

Treat `apim-artifacts/` as the shared source of truth and `apiops/configuration.<environment>.yaml` as the only environment-specific layer.

Use managed identity for Foundry backend calls. Keep policies valid XML, keep OpenAPI contracts valid, and preserve transitive dependencies. Never add secrets or `--delete-unmatched`.

