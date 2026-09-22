# Architecture and ownership

## Environment topology

Each environment has one resource group containing:

- Microsoft Foundry `AIServices` account
- Foundry project
- Zero or more model deployments
- Azure API Management Developer SKU instance
- Log Analytics workspace and workspace-based Application Insights component
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
| APIM Application Insights logger and diagnostic | Bicep |
| APIM-to-Foundry RBAC | Bicep |
| APIM API and OpenAPI contract | APIOps |
| APIM backend and named values | APIOps |
| APIM products and associations | APIOps |
| APIM policies | APIOps |

Do not cross these boundaries. A resource managed by both systems can oscillate or be deleted unexpectedly.

The APIM logger and diagnostic are the deliberate exception to "APIM configuration belongs to APIOps". The logger needs the Application Insights connection string, which Bicep can read from the component in the same resource group without ever writing a secret to the repository. `apiops/configuration.extractor.yaml` keeps `loggers` and `diagnostics` empty so APIOps never manages them.

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
2. APIM enforces a subscription and rate limit.
3. The product policy enforces the tier's token rate limit and daily token quota.
4. The API policy emits token metrics to Application Insights.
5. APIM selects the environment-specific Foundry backend.
6. APIM obtains a Microsoft Entra token through its managed identity.
7. Foundry authorizes the APIM identity through `Cognitive Services OpenAI User`.
8. For inference operations, the request body `model` value selects the Foundry deployment.

The APIM contract is generated from Microsoft's official Azure OpenAI v1 specification. The upstream OpenAPI 3.2 document is converted to OpenAPI 3.0.3 with permissive payload schemas because APIM doesn't support OpenAPI 3.2. APIM uses the v1 Microsoft Entra audience `https://ai.azure.com`.

## Promotion

Shared source artifacts are promoted unchanged. Bicep uses an environment-specific parameter file; APIOps uses an environment override file. GitHub Environments provide environment identity, variables, concurrency, and production approval.
