# Run the switchable .NET agent demo

The demo runs two unattended .NET 10 console agents through a selectable local gateway profile:

| Agent | Foundry APIM product | Traffic shape | Demonstrates |
|---|---|---|---|
| Ticket Triage Agent | `foundry-bronze` | 20 small requests | TPM throttling, `Retry-After`, per-call token headers |
| Market Brief Analyst | `foundry-gold` | Three large chained requests | High-throughput token consumption without bronze-tier throttling |

The `foundry-apim` profile uses Microsoft Entra ID plus separate product-scoped APIM subscription keys. The `ai-gateway` profile uses separate `api-key` values for the two agents and does not acquire or send an Entra token.

## Prerequisites

- The selected OpenAI-compatible gateway and model deployment are available.
- .NET 10 SDK is installed.
- For `foundry-apim`, the dev infrastructure and APIOps artifacts are deployed, Azure CLI is signed in to tenant `cd48c7b8-9369-443d-8a4c-bd1e53504a09`, the signed-in user can manage app registrations and APIM subscriptions, and Application Insights custom metrics are configured **With dimensions** as described in [Architecture](../architecture.md#token-metrics).

## Initialize the Foundry APIM profile

From the repository root:

```powershell
.\scripts\Initialize-AgentDemo.ps1
```

The script:

1. Creates or updates the secretless `foundry-apim-demo-agents` app registration.
2. Exposes a delegated `user_impersonation` permission, pre-authorizes Azure CLI, and configures the clients to request `api://<application-id>/.default`.
3. Creates `triage-agent-bronze` and `brief-agent-gold` APIM subscriptions.
4. Writes the APIM URL, Entra scope, model, retry settings, and subscription keys to gitignored `agents\profiles\foundry-apim.env.local`.
5. Activates that profile as `agents\.env`.

No application secret, Foundry key, or APIM key is committed.

## Initialize the AI Gateway profile

Run:

```powershell
.\scripts\Initialize-AiGatewayAgentProfile.ps1 -Model '<ai-gateway-model-deployment>'
```

The script defaults the base URL to:

```text
https://astral-spring-2206.azure-api.net/default/models/openai/v1
```

It securely prompts for the Ticket Triage Agent API key and Market Brief Analyst API key, writes them to gitignored `agents\profiles\ai-gateway.env.local`, and activates the profile. The API keys are sent through the `api-key` header. The AI Gateway profile does not request or send an Entra bearer token.

Use `-BaseUrl` to override the endpoint. For non-interactive local automation, pass `SecureString` values through `-TriageApiKey` and `-MarketApiKey`; do not put plaintext keys in shell command history.

## Switch profiles

Activate either saved profile without recreating it:

```powershell
.\scripts\Switch-AgentDemoProfile.ps1 -Profile foundry-apim
.\scripts\Switch-AgentDemoProfile.ps1 -Profile ai-gateway
```

The switcher validates the URL, model, authentication mode, header, both agent keys, and retry settings before atomically replacing `agents\.env`. It prints profile metadata but never credential values.

## Build and run

```powershell
dotnet build .\agents\FoundryAgents.slnx
.\agents\run-demo.ps1 -Profile foundry-apim
.\agents\run-demo.ps1 -Profile ai-gateway
```

Omit `-Profile` to use the active `agents\.env`. The two processes run concurrently. Every call prints SDK token usage. When the Foundry APIM profile returns them, the runner also prints:

- `X-Foundry-Tier`
- `X-Foundry-Tokens-Consumed`
- `X-Foundry-Remaining-Tokens`
- `X-Foundry-Remaining-Quota-Tokens`

The Foundry APIM bronze agent is expected to receive one or more `429` responses. The shared retry policy honors `Retry-After` as delta-seconds or an HTTP date, adds jitter, and retries within bounded attempt and wait budgets. A throttled request that later succeeds is a successful demo outcome. A `403` quota or authorization response is terminal and is not retried.

Override the defaults in either local profile when needed:

```text
AGENT_RETRY_MAX_ATTEMPTS=5
AGENT_RETRY_MAX_DELAY_SECONDS=90
AGENT_RETRY_TOTAL_BUDGET_SECONDS=180
```

## Validate the access token

This verifies the expected v2 claims without printing the token:

```powershell
$scope = 'api://22425f2b-4bf5-41c4-b6ce-11f2806ede72/.default'
$token = az account get-access-token --scope $scope --query accessToken --output tsv
$payload = $token.Split('.')[1].Replace('-', '+').Replace('_', '/')
while ($payload.Length % 4) { $payload += '=' }
$claims = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($payload)) | ConvertFrom-Json
$claims | Select-Object aud, azp, tid, iss, scp
```

Expected values:

- `aud`: `22425f2b-4bf5-41c4-b6ce-11f2806ede72`
- `azp`: `04b07795-8ddb-461a-bbee-02f9e1bf7b46` (Azure CLI)
- `tid`: `cd48c7b8-9369-443d-8a4c-bd1e53504a09`
- `scp`: `user_impersonation`

## Query token metrics

First discover the emitted metric names in the environment's Log Analytics workspace:

```kusto
customMetrics
| where timestamp > ago(30m)
| distinct name
| order by name asc
```

Then inspect dimensions and measurements:

```kusto
customMetrics
| where timestamp > ago(30m)
| project timestamp, name, value, customDimensions
| order by timestamp desc
```

After confirming the metric names, split usage by product and APIM subscription:

```kusto
customMetrics
| where timestamp > ago(30m)
| extend ProductId = tostring(customDimensions["Product ID"])
| extend SubscriptionId = tostring(customDimensions["Subscription ID"])
| summarize Tokens = sum(value) by name, ProductId, SubscriptionId, bin(timestamp, 1m)
| order by timestamp asc
```

The expected result has independent series for `foundry-bronze` / `triage-agent-bronze` and `foundry-gold` / `brief-agent-gold`.

## Reset local configuration

Delete only the affected `agents\profiles\*.env.local` file and `agents\.env`, then rerun that profile's initialization script. Do not commit any of these files.
