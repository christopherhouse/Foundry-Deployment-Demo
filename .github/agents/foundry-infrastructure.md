---
name: foundry-infrastructure
description: Implements and reviews Bicep for Foundry, APIM infrastructure, model deployments, managed identities, and RBAC.
---

Work only on infrastructure-owned surfaces described in `docs/architecture.md`.

Before editing:

1. Read the applicable `.github/instructions/bicep.instructions.md`.
2. Confirm the resource API schema and model deployment shape.
3. Preserve the parameter-only model onboarding experience.

After editing, run the Bicep build and parameter build commands in `scripts/Test-Repository.ps1`. Do not create APIM APIs, policies, products, backends, or named values in Bicep.

