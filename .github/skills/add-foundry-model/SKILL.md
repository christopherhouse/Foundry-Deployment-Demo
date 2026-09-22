---
name: add-foundry-model
description: Add or update a Microsoft Foundry model deployment through environment Bicep parameter files and validate the change.
---

1. Identify the target environment parameter file.
2. Verify model name, version, format, SKU, capacity, regional availability, and quota.
3. Add one object to `modelDeployments`; do not edit the Foundry module for routine onboarding.
4. Use a stable deployment name that API clients can send in the OpenAI `model` field.
5. Run `az bicep build-params --file <parameter-file>`.
6. If promoting to prod, keep the reviewed model definition aligned unless an intentional difference is documented.
7. Update `docs/project-plan.md` when completing a planned demo milestone.

