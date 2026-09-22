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

1. A client sends an OpenAI v1-compatible request to `https://<apim>.azure-api.net/openai/v1/chat/completions`.
2. APIM enforces a subscription and rate limit.
3. APIM selects the environment-specific Foundry backend.
4. APIM obtains a Microsoft Entra token through its managed identity.
5. Foundry authorizes the APIM identity through `Cognitive Services OpenAI User`.
6. The request body `model` value selects the Foundry deployment.

## Promotion

Shared source artifacts are promoted unchanged. Bicep uses an environment-specific parameter file; APIOps uses an environment override file. GitHub Environments provide environment identity, variables, concurrency, and production approval.

