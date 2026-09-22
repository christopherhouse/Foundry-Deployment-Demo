# Repository instructions

This repository is a two-environment Microsoft Foundry and Azure API Management deployment demo.

## Architecture invariants

- Use Bicep for Azure infrastructure.
- `infra/main.bicep` is subscription-scoped and each `.bicepparam` deploys one environment.
- Do not add VNets, private endpoints, or private DNS unless the project scope explicitly changes.
- Foundry model deployments must remain data-driven through the `modelDeployments` parameter array.
- Bicep owns resource groups, Foundry resources/projects/deployments, APIM service instances, managed identities, and RBAC.
- APIOps owns APIM APIs, specifications, backends, named values, products, associations, and policies.
- Never define the same APIM child resource in both Bicep and `apim-artifacts/`.

## Security

- Use GitHub OIDC and managed identities. Never introduce service-principal secrets, API keys, Foundry keys, or APIM subscription keys.
- APIM authenticates to Foundry with its managed identity and the `Cognitive Services OpenAI User` role.
- Keep `disableLocalAuth: true` on Foundry unless a documented requirement changes.
- Do not add `--delete-unmatched` to APIOps publishing without an explicit, reviewed decision.

## Versions and validation

- Pin tool, action, Bicep API, and module versions deliberately.
- APIOps CLI is pinned in `package.json`; upgrade it only in a dedicated change that reviews the changelog.
- Keep PowerShell scripts compatible with Windows PowerShell 5.1.
- Run `.\scripts\Test-Repository.ps1` after relevant changes.
- Update README, architecture, runbooks, and project plan when behavior or ownership changes.

