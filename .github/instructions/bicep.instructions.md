---
applyTo: "infra/**/*.bicep,infra/**/*.bicepparam,bicepconfig.json"
---

- Keep the deployment subscription-scoped and reusable for both environments.
- Use current stable API versions verified against the Bicep schema.
- Keep resource names and environment-specific values in `.bicepparam` files.
- Add model deployments only through the `modelDeployments` array.
- Use managed identity and RBAC; never emit or store account keys.
- Preserve outputs consumed by runbooks and workflows.
- Validate with `az bicep build` and `az bicep build-params`.

