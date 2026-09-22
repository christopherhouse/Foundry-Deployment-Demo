# Foundry Deployment Demo

This repository demonstrates two independent continuous-delivery paths:

1. **Microsoft Foundry infrastructure and model deployments** through Bicep and environment-specific `.bicepparam` files.
2. **Azure API Management configuration** through the APIOps CLI, including an OpenAI v1-compatible API, backend, tiered products, named values, and policy.

The demo uses one Azure subscription, separate `dev` and `prod` resource groups, public endpoints, and separate APIM Developer SKU instances. Developer SKU is intentionally demo-only and has no production SLA.

Each environment also has a dedicated Log Analytics workspace and Application Insights component so APIM can emit per-tier token-consumption metrics.

Three published products — `foundry-bronze`, `foundry-silver`, and `foundry-gold` — expose the same Foundry API with increasing token-per-minute limits and daily token quotas, enforced by product-scope `llm-token-limit` policies. See [Architecture](docs/architecture.md) for the tier table.

Bootstrap Bicep creates the two West US 3 resource groups and one GitHub OIDC user-assigned managed identity per environment. Each identity receives `Contributor` and `User Access Administrator` only on its own resource group.

Automatic merge-driven releases are gated by repository variable `ENABLE_AUTOMATIC_RELEASE`. Bootstrap initializes it to `false`; enable it only after workload-specific values and model quota are ready.

## Architecture

```text
GitHub pull request
  |-- Bicep validation
  `-- APIOps artifact validation

main
  |-- deploy Bicep to dev
  |-- publish APIOps artifacts to dev
  |-- GitHub Environment approval
  |-- deploy the same commit to prod
  `-- publish the same artifacts to prod with prod overrides

APIM (managed identity) --> Microsoft Foundry model deployments
```

Bicep owns resource groups, Foundry, model deployments, APIM service instances, identities, RBAC, Log Analytics, Application Insights, and the APIM Application Insights logger and diagnostic. APIOps owns APIM APIs, backends, named values, products, associations, and policies.

## Prerequisites

- Azure CLI with Bicep CLI
- PowerShell 5.1 or later
- Node.js 22 or later
- GitHub CLI for optional environment/bootstrap automation
- Permissions to create resource groups, Foundry resources, APIM, role assignments, app registrations, and federated credentials

## Development workflow

All implementation work uses a short-lived branch created from the latest `main`:

- `feature/<name>` for new capabilities
- `bugfix/<name>` for defect fixes
- `chore/<name>` for maintenance, documentation, tooling, or configuration

Push the branch and merge it through a pull request. After the merge, update local `main` with `git pull --ff-only origin main` before creating the next branch.

## Quick start

1. Review and edit `infra/environments/dev.bicepparam` and `infra/environments/prod.bicepparam`.
2. Add at least one model deployment by uncommenting the example object in each environment file and verify model availability and quota in the selected region.
3. Run `.\scripts\Test-Repository.ps1`.
4. Run `.\scripts\Deploy-Bootstrap.ps1` to create resource groups, OIDC identities, scoped RBAC, and GitHub environment variables.
5. Merge the scaffold or run `.github/workflows/release.yml` to deploy infrastructure and publish APIM configuration in order.
6. Use the dedicated infrastructure and APIOps workflows only for targeted manual recovery or demonstration steps.

## Add a model deployment

Model deployments are an array in each `.bicepparam`:

```bicep
param modelDeployments = [
  {
    name: 'gpt-4-1-mini'
    model: {
      format: 'OpenAI'
      name: 'gpt-4.1-mini'
      version: '2025-04-14'
    }
    sku: {
      name: 'Standard'
      capacity: 10
    }
    versionUpgradeOption: 'NoAutoUpgrade'
  }
]
```

Create a pull request with the parameter change. The infrastructure workflows validate it, deploy it to dev after merge, and require approval before prod.

## Documentation

- [Project charter](docs/project-charter.md)
- [Project plan](docs/project-plan.md)
- [Architecture and ownership](docs/architecture.md)
- [Bootstrap runbook](docs/runbooks/bootstrap.md)
- [Deploy a model](docs/runbooks/deploy-model.md)
- [Change APIM configuration](docs/runbooks/change-apim-configuration.md)
- [Rollback](docs/runbooks/rollback.md)
