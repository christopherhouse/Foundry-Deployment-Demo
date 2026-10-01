# Architecture and ownership

## Environment topology

Each environment has one resource group containing:

- Microsoft Foundry `AIServices` account
- Foundry project
- Zero or more model deployments
- Azure API Management Developer SKU instance
- Log Analytics workspace and workspace-based Application Insights component
- Azure Monitor diagnostic settings routing all Foundry account, Foundry project, and APIM resource logs and metrics to Log Analytics
- APIM Application Insights logger and service-scope diagnostic with custom metrics enabled
- Role assignment allowing the APIM system-assigned identity to invoke Foundry models

The environments use public endpoints and no virtual networks.

## Deployment boundaries

| Resource | Deployment system |
|---|---|
| Resource group | Bicep |
| Foundry account/project/model deployment | Bicep |
| APIM service and identity | Bicep |
| Log Analytics workspace and Application Insights | Bicep |
| Foundry account/project and APIM Azure Monitor diagnostic settings | Bicep |
| APIM Application Insights logger and diagnostic | Bicep |
| APIM-to-Foundry RBAC | Bicep |
| Foundry data plane administrator RBAC | Bicep |
| APIM API and OpenAPI contract | APIOps |
| APIM backend and named values | APIOps |
| APIM products and associations | APIOps |
| APIM policies | APIOps |

Do not cross these boundaries. A resource managed by both systems can oscillate or be deleted unexpectedly.

The APIM logger and diagnostic are the deliberate exception to "APIM configuration belongs to APIOps". The logger needs the Application Insights connection string, which Bicep can read from the component in the same resource group without ever writing a secret to the repository. `apiops/configuration.extractor.yaml` keeps `loggers` and `diagnostics` empty so APIOps never manages them.

## Foundry data plane access

Foundry keeps `disableLocalAuth: true`, so every data plane caller authenticates with Microsoft Entra. Human and automation principals that need direct Foundry access are data-driven through the `foundryDataPlaneAdmins` array in each environment `.bicepparam`. `infra/modules/role-assignments.bicep` assigns each entry two roles at the Foundry account scope:

| Role | Role definition ID | Grants |
|---|---|---|
| Cognitive Services OpenAI Contributor | `a001fd3d-188f-4b5d-821b-7da978bf7442` | Full OpenAI data plane: inference, fine-tuning, and deployment management |
| Foundry User | `53ca6127-db72-4b80-b1b0-d745d6d5456d` | Foundry project data actions such as agents, threads, and evaluations, plus reader on the account and project |

Together these are the broadest supported Foundry data plane access without granting subscription or resource-group control plane rights. Add or remove a principal by editing the array only; never hand-add a portal role assignment, because the next deployment will not reconcile it. Each entry carries an explicit `principalType` so assignments do not fail on Microsoft Graph replication delays.

## Resource diagnostics

Bicep creates Azure Monitor diagnostic settings on the Foundry account, its project, and the APIM service. All three use the `allLogs` category group and `AllMetrics`, route to the environment's Log Analytics workspace, and use resource-specific tables through `logAnalyticsDestinationType: Dedicated`.

The `allLogs` group avoids a hard-coded category list and automatically covers provider categories added after deployment. As of October 1, 2026, the deployed APIM services expose `GatewayLogs`, `WebSocketConnectionLogs`, `DeveloperPortalAuditLogs`, `GatewayLlmLogs`, and `GatewayMCPLogs`; the Foundry accounts expose `Audit`, `RequestResponse`, `AzureOpenAIRequestUsage`, `Trace`, and `ManagedNetworkEvent`; and the Foundry projects expose `Audit` and `Trace`. Model deployment child resources do not support diagnostic settings.

These Azure Monitor settings are separate from the APIM `applicationinsights` child diagnostic. Azure Monitor captures service resource logs and platform metrics in Log Analytics; the APIM child diagnostic sends API request telemetry and custom token metrics to Application Insights.

## Product tiers

Three published products expose the same Foundry API with different token budgets, enforced by `llm-token-limit` in each product policy.

| Product | Dev tokens/minute | Dev tokens/day | Prod tokens/minute | Prod tokens/day |
|---|---|---|---|---|
| `foundry-bronze` | 1,000 | 50,000 | 2,500 | 125,000 |
| `foundry-silver` | 5,000 | 250,000 | 12,500 | 625,000 |
| `foundry-gold` | 20,000 | 1,000,000 | 50,000 | 2,500,000 |

Limits are named values (`tier-<tier>-tokens-per-minute`, `tier-<tier>-token-quota`), so a tier change is an APIOps-only change. Each tier uses its own `counter-key` prefix so the tiers never share a counter. Responses carry `X-Foundry-Tier`, `X-Foundry-Tokens-Consumed`, `X-Foundry-Remaining-Tokens`, and `X-Foundry-Remaining-Quota-Tokens`.

`foundry-demo` remains as the untiered product used by smoke tests.

## Token metrics

The Foundry API policy emits `llm-emit-token-metric` into the `foundry-demo` metric namespace with the `API ID`, `Operation ID`, `Product ID`, and `Subscription ID` dimensions. This requires all of the following, which the repository provisions:

- A workspace-based Application Insights component (`infra/modules/monitoring.bicep`).
- An APIM `applicationInsights` logger pointed at that component.
- A service-scope `applicationinsights` diagnostic with `metrics: true`.

One manual step remains: in the Application Insights component, set **Usage and estimated costs** > **Custom metrics (Preview)** to **With dimensions**. Without it, metrics still emit and dimensions are still queryable in the `customMetrics` Log Analytics table, but Azure Monitor metrics charts cannot split by dimension. Azure does not expose a supported ARM property for this preview setting.

## Request path

1. A client sends an Azure OpenAI v1 request to `https://<apim>.azure-api.net/openai/v1/<operation>`. Use `/responses` for new text-generation integrations; `/chat/completions`, `/completions`, `/embeddings`, and the rest of the official v1 operation catalog are also represented.
2. APIM validates the caller's Microsoft Entra token against the tenant, Azure CLI client application ID, and dedicated agent API audience.
3. APIM requires a product-scoped subscription and applies the request rate limit.
4. The product policy enforces the tier's token rate limit and daily token quota.
5. The API policy emits token metrics to Application Insights.
6. APIM selects the environment-specific Foundry backend.
7. APIM obtains a separate Microsoft Entra token through its managed identity.
8. Foundry authorizes the APIM identity through `Cognitive Services OpenAI User`.
9. For inference operations, the request body `model` value selects the Foundry deployment.

The APIM contract is generated from Microsoft's official Azure OpenAI v1 specification. The upstream OpenAPI 3.2 document is converted to OpenAPI 3.0.3 with permissive payload schemas because APIM doesn't support OpenAPI 3.2. APIM uses the v1 Microsoft Entra audience `https://ai.azure.com` when it authenticates to Foundry.

## Demo agents and caller identity

The two .NET 10 demo agents use no tools or external services. Under the Foundry APIM profile, both use the `gpt-5-6-luna` deployment: the Ticket Triage Agent uses `foundry-bronze` for many small calls, while the Market Brief Analyst uses `foundry-gold` for three larger chained requests. The AI Gateway profile selects its model independently.

The agents use local, gitignored profiles so the demo can switch between two OpenAI-compatible gateway paths without changing code:

- `foundry-apim` targets the repository-managed APIM and Foundry resources.
- `ai-gateway` targets an externally managed AI Gateway preview resource. This repository does not deploy or configure that infrastructure.

For the Foundry APIM profile, caller authentication and tier selection are deliberately separate:

- `DefaultAzureCredential` obtains a delegated token for the `foundry-apim-demo-agents` resource application. Locally it uses the Azure CLI credential.
- The API policy validates tenant `cd48c7b8-9369-443d-8a4c-bd1e53504a09`, audience `22425f2b-4bf5-41c4-b6ce-11f2806ede72`, and caller application `04b07795-8ddb-461a-bbee-02f9e1bf7b46` (Azure CLI).
- Each agent also sends its own product-scoped APIM subscription key. That key selects bronze or gold limits and supplies the Subscription ID dimension for token metrics.
- A shared bounded retry policy honors `Retry-After` for `429` and `503`; daily-quota `403` responses are terminal.

The app registration has a delegated `user_impersonation` scope and pre-authorizes Azure CLI. It has no secret, certificate, or federated credential. APIM subscription keys remain in the local `foundry-apim` profile and are never APIOps artifacts.

The AI Gateway profile uses the `api-key` request header and separate local keys for the Ticket Triage and Market Brief agents. It does not initialize `DefaultAzureCredential` or send an Entra bearer token. Both profiles carry their own base URL and model name, and `scripts/Switch-AgentDemoProfile.ps1` validates and activates one profile as `agents/.env`.

## Promotion

Shared source artifacts are promoted unchanged. Bicep uses an environment-specific parameter file; APIOps uses an environment override file. GitHub Environments provide environment identity, variables, concurrency, and production approval.
