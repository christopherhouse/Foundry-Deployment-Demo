# Bootstrap

## 1. Customize source values

Edit both files under `infra/environments/`:

- Globally unique Foundry and APIM names
- Azure location
- APIM publisher email
- Resource group names if required

Keep `apiops/configuration.dev.yaml` and `apiops/configuration.prod.yaml` backend URLs aligned with the Foundry account names.

## 2. Validate locally

```powershell
.\scripts\Test-Repository.ps1
```

## 3. Create GitHub environments and OIDC identities

Run the bootstrap script once per environment with an Azure scope appropriate for the deployment identity:

```powershell
.\scripts\Bootstrap-GitHubOidc.ps1 `
  -GitHubOwner christopherhouse `
  -GitHubRepository Foundry-Deployment-Demo `
  -Environment dev `
  -AzureSubscriptionId <subscription-id> `
  -RoleScope /subscriptions/<subscription-id>
```

Repeat for `prod`. Review the broad subscription-level `Contributor` and `Role Based Access Control Administrator` assignments used to create resource groups and Foundry RBAC; reduce scope after initial bootstrap when practical.

Configure a required reviewer on the `prod` GitHub Environment in repository settings.

## 4. Configure environment variables

The script sets identity and subscription variables. Add:

- `DEPLOYMENT_LOCATION`
- `APIM_RESOURCE_GROUP`
- `APIM_SERVICE_NAME`
- `FOUNDRY_ACCOUNT_NAME`

The committed default names are:

| Environment | Resource group | APIM |
|---|---|---|
| dev | `rg-foundrydeploydemo-dev` | `apim-foundrydeploydemo-dev-ch` |
| prod | `rg-foundrydeploydemo-prod` | `apim-foundrydeploydemo-prod-ch` |

## 5. Deploy

Merges to `main` run the coordinated **Release dev and prod** workflow. Use **Deploy infrastructure** or **Publish APIOps artifacts** manually only for targeted recovery or demonstration steps.
