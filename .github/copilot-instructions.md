# Repository instructions

This repository is a two-environment Microsoft Foundry and Azure API Management deployment demo.

## Development branch workflow

- Never implement changes directly on `main`.
- Before starting every task:
  1. Confirm the working tree is clean.
  2. Check out `main`.
  3. Run `git pull --ff-only origin main`.
  4. Create a new kebab-case branch from the updated `main`.
- Branch names must use exactly one of these prefixes:
  - `feature/` for new user-facing behavior or capabilities.
  - `bugfix/` for defect corrections.
  - `chore/` for maintenance, documentation, tooling, refactoring, or repository configuration.
- Keep one task or cohesive change set per branch.
- After validation, commit and push the branch for pull-request review. Do not merge it unless the user explicitly asks.
- When the user confirms that the branch was merged:
  1. Check out `main`.
  2. Run `git pull --ff-only origin main`.
  3. Confirm local `main` matches `origin/main` and the working tree is clean.
  4. Remain on the updated `main` until the next task, then create a fresh branch.

## Architecture invariants

- Use Bicep for Azure infrastructure.
- `bootstrap/main.bicep` is subscription-scoped and owns environment resource groups, GitHub OIDC user-assigned managed identities, federated credentials, and deployment-identity RBAC.
- `infra/main.bicep` is resource-group-scoped and each `.bicepparam` deploys one environment into a resource group created by bootstrap.
- GitHub deployment identities receive `Contributor` and `User Access Administrator` only at their environment resource-group scope.
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
