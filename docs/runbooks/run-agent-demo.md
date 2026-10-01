# Run the .NET agent demo

The demo runs two unattended .NET 10 console agents against the same `gpt-5-6-luna` deployment through APIM:

| Agent | Product | Traffic shape | Demonstrates |
|---|---|---|---|
| Ticket Triage Agent | `foundry-bronze` | 20 small requests | TPM throttling, `Retry-After`, per-call token headers |
| Market Brief Analyst | `foundry-gold` | Three large chained requests | High-throughput token consumption without bronze-tier throttling |

Both use Microsoft Entra ID for caller authentication and separate product-scoped APIM subscription keys for tier enforcement and attribution.

## Prerequisites

- The dev infrastructure and APIOps artifacts are deployed.
- Azure CLI is signed in to tenant `cd48c7b8-9369-443d-8a4c-bd1e53504a09`.
- The signed-in user can manage app registrations and APIM subscriptions.
- .NET 10 SDK is installed.
- Application Insights custom metrics are configured **With dimensions** as described in [Architecture](../architecture.md#token-metrics).

## Initialize

From the repository root:

```powershell
.\scripts\Initialize-AgentDemo.ps1
```

The script:

1. Creates or updates the secretless `foundry-apim-demo-agents` app registration.
2. Exposes a delegated `user_impersonation` permission, pre-authorizes Azure CLI, and configures the clients to request `api://<application-id>/.default`.
3. Creates `triage-agent-bronze` and `brief-agent-gold` APIM subscriptions.
4. Writes the APIM URL, Entra scope, model, retry settings, and subscription keys to gitignored `agents/.env`.

No application secret, Foundry key, or APIM key is committed.

## Build and run

```powershell
dotnet build .\agents\FoundryAgents.slnx
.\agents\run-demo.ps1
```

The two processes run concurrently. Each call prints SDK token usage and these APIM headers:

- `X-Foundry-Tier`
- `X-Foundry-Tokens-Consumed`
- `X-Foundry-Remaining-Tokens`
- `X-Foundry-Remaining-Quota-Tokens`

The bronze agent is expected to receive one or more `429` responses. The shared retry policy honors `Retry-After` as delta-seconds or an HTTP date, adds jitter, and retries within bounded attempt and wait budgets. A throttled request that later succeeds is a successful demo outcome. A `403` daily-quota response is terminal and is not retried.

Override the defaults in `agents/.env` when needed:

```text
FOUNDRY_RETRY_MAX_ATTEMPTS=5
FOUNDRY_RETRY_MAX_DELAY_SECONDS=90
FOUNDRY_RETRY_TOTAL_BUDGET_SECONDS=180
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

Delete only `agents/.env` if the APIM subscriptions or app registration change, then run the initialization script again. Do not commit the file.
