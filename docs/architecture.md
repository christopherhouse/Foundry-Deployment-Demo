# Architecture and ownership

## Environment topology

Each environment has one resource group containing:

- Microsoft Foundry `AIServices` account
- Foundry project
- Zero or more model deployments
- Azure API Management Developer SKU instance
- Role assignment allowing the APIM system-assigned identity to invoke Foundry models

The environments use public endpoints and no virtual networks.

## Deployment boundaries

| Resource | Deployment system |
|---|---|
| Resource group | Bicep |
| Foundry account/project/model deployment | Bicep |
| APIM service and identity | Bicep |
| APIM-to-Foundry RBAC | Bicep |
| APIM API and OpenAPI contract | APIOps |
| APIM backend and named values | APIOps |
| APIM products and associations | APIOps |
| APIM policies | APIOps |

Do not cross these boundaries. A resource managed by both systems can oscillate or be deleted unexpectedly.

## Request path

1. A client sends an Azure OpenAI v1 request to `https://<apim>.azure-api.net/openai/v1/<operation>`. Use `/responses` for new text-generation integrations; `/chat/completions`, `/completions`, `/embeddings`, and the rest of the official v1 operation catalog are also represented.
2. APIM enforces a subscription and rate limit.
3. APIM selects the environment-specific Foundry backend.
4. APIM obtains a Microsoft Entra token through its managed identity.
5. Foundry authorizes the APIM identity through `Cognitive Services OpenAI User`.
6. For inference operations, the request body `model` value selects the Foundry deployment.

The APIM contract is generated from Microsoft's official Azure OpenAI v1 specification. The upstream OpenAPI 3.2 document is converted to OpenAPI 3.0.3 with permissive payload schemas because APIM doesn't support OpenAPI 3.2. APIM uses the v1 Microsoft Entra audience `https://ai.azure.com`.

## Promotion

Shared source artifacts are promoted unchanged. Bicep uses an environment-specific parameter file; APIOps uses an environment override file. GitHub Environments provide environment identity, variables, concurrency, and production approval.
