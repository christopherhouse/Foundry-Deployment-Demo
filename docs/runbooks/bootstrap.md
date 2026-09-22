# Bootstrap

## 1. Confirm the target

The committed bootstrap targets:

- Subscription: `ME-MngEnvMCAP758145-chhouse-2`
- Subscription ID: `8043efb5-d046-4aac-abcd-2c1a00e5ab86`
- Tenant ID: `cd48c7b8-9369-443d-8a4c-bd1e53504a09`
- Region: `westus3`

The bootstrap creates:

- `rg-foundrydeploydemo-dev`
- `rg-foundrydeploydemo-prod`
- One user-assigned managed identity in each resource group
- One GitHub environment federated credential per identity
- `Contributor` and `User Access Administrator` for each identity, scoped only to its resource group

## 2. Customize workload values

Edit both files under `infra/environments/`:

- Globally unique Foundry and APIM names
- Azure location
- APIM publisher email
- Resource group names if required

Keep `apiops/configuration.dev.yaml` and `apiops/configuration.prod.yaml` backend URLs aligned with the Foundry account names.

## 3. Validate locally

```powershell
.\scripts\Test-Repository.ps1
```

## 4. Deploy the bootstrap

The operator must be able to create resource groups, managed identities, federated credentials, and role assignments in the target subscription.

```powershell
.\scripts\Deploy-Bootstrap.ps1
```

The script:

- Verifies the exact subscription name, ID, and tenant.
- Runs an Azure what-if.
- Deploys `bootstrap/main.bicep`.
- Creates or updates the GitHub `dev` and `prod` environments.
- Sets all nonsecret environment variables used by the workflows.
- Configures `christopherhouse` as the required production reviewer.
- Initializes repository variable `ENABLE_AUTOMATIC_RELEASE=false` so merging bootstrap changes cannot deploy the workload prematurely.

Use `-WhatIf` to preview script-side changes or `-SkipGitHubConfiguration` to deploy only Azure resources.

Override the reviewer with `-ProdReviewerLogin <login>` when another reviewer should approve production.

After publisher metadata, model details, and quota are ready, enable merge-driven releases:

```powershell
gh variable set ENABLE_AUTOMATIC_RELEASE `
  --repo christopherhouse/Foundry-Deployment-Demo `
  --body true
```

## 5. GitHub environment variables

The script sets:

- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`
- `DEPLOYMENT_LOCATION`
- `APIM_RESOURCE_GROUP`
- `APIM_SERVICE_NAME`
- `FOUNDRY_ACCOUNT_NAME`

The committed default names are:

| Environment | Resource group | APIM |
|---|---|---|
| dev | `rg-foundrydeploydemo-dev` | `apim-foundrydeploydemo-dev-ch` |
| prod | `rg-foundrydeploydemo-prod` | `apim-foundrydeploydemo-prod-ch` |

## 6. Deploy the workload

Merges to `main` run the coordinated **Release dev and prod** workflow. Use **Deploy infrastructure** or **Publish APIOps artifacts** manually only for targeted recovery or demonstration steps.
