# Change APIM configuration

1. Edit shared resources under `apim-artifacts/`.
2. Put endpoint or environment differences in `apiops/configuration.dev.yaml` and `apiops/configuration.prod.yaml`.
3. Run `.\scripts\Test-ApiOpsArtifacts.ps1`.
4. Open a pull request and review policy, OpenAPI, product, backend, and named-value dependencies.
5. Merge to publish to dev.
6. Review the dry run and smoke result, then approve prod.

Do not add `--delete-unmatched`.

## Extract portal changes into a pull request

Use **Actions > Extract APIOps artifacts > Run workflow** when an APIOps-owned resource was changed in the APIM portal and needs to be reconciled into source control.

1. Select the source environment. Use `dev` for the normal authoring flow; use `prod` only when intentionally reconciling a production-side change.
2. The workflow checks out the default branch and runs the pinned APIOps CLI against `apiops/configuration.extractor.yaml`.
3. `--remove-stale` synchronizes the managed extraction scope so additions, modifications, and deletions are represented.
4. The extracted tree is validated with `Test-ApiOpsArtifacts.ps1` before it can become a pull request.
5. The workflow opens `apim-extract-<environment>-<run-id>` against the default branch. If the extracted artifacts match the repository, no pull request is created.
6. Review the generated delta. Move environment-specific values into `apiops/configuration.dev.yaml` and `apiops/configuration.prod.yaml` before merging.

The extraction filter deliberately excludes Bicep-owned APIM loggers and diagnostics, APIM subscriptions, and other resources outside this repository's APIOps ownership boundary. The generated pull request is reviewed and merged through the same validation and release path as a hand-authored APIOps change.

Repository Actions settings must allow GitHub Actions to create pull requests. `Deploy-Bootstrap.ps1` configures that setting while leaving the default `GITHUB_TOKEN` permission read-only; only workflows that explicitly request `contents: write` and `pull-requests: write` receive those permissions.

## Change content safety enforcement

The API-level `llm-content-safety` policy screens requests and completions through the environment-specific `content-safety-backend`. The backend uses APIM's managed identity; do not add account keys or secret named values.

The default balanced posture enables prompt-shield detection and blocks severity 4 or higher for `Hate`, `SelfHarm`, `Sexual`, and `Violence`. Keep all category thresholds explicit and review changes to `shield-prompt`, `enforce-on-completions`, or thresholds as security behavior changes.

After publishing to dev, verify a benign prompt succeeds and an intentionally unsafe synthetic prompt receives `403`. Do not use real personal, confidential, or graphic content in the test payload.

The Foundry API specification is generated from Microsoft's official Azure OpenAI v1 contract:

```powershell
.\scripts\Update-FoundryOpenApiSpec.ps1
```

The generator pins the upstream `azure-rest-api-specs` commit and converts its OpenAPI 3.2 operation catalog to an APIM-compatible OpenAPI 3.0.3 document. Keep the generated request and response schemas permissive; APIM is the proxy/configuration boundary, while the official OpenAI client models remain the authoritative payload contract.

## Change a product tier's token budget

Tier limits are named values, so a tier change never touches Bicep.

1. Edit the base value in `apim-artifacts/namedValues/tier-<tier>-tokens-per-minute/namedValueInformation.json` or `tier-<tier>-token-quota/`.
2. Edit the matching entries in `apiops/configuration.dev.yaml` and `apiops/configuration.prod.yaml`. Both overrides must keep bronze < silver < gold; `Test-ApiOpsArtifacts.ps1` enforces this.
3. Run `.\scripts\Test-ApiOpsArtifacts.ps1`, then open a pull request.

To confirm enforcement after publish, create a subscription scoped to the product and read the response headers:

```powershell
$app = .\scripts\New-AgentAppRegistration.ps1
$token = az account get-access-token `
  --scope $app.Scope `
  --query accessToken `
  --output tsv

$key = .\scripts\New-TierSubscription.ps1 `
  -ResourceGroupName rg-foundrydeploydemo-dev `
  -ApimServiceName apim-foundrydeploydemo-dev-ch `
  -Tier gold

$response = Invoke-WebRequest `
  -Uri 'https://<apim>.azure-api.net/openai/v1/chat/completions' `
  -Method Post `
  -Headers @{ Authorization = "Bearer $token"; 'Ocp-Apim-Subscription-Key' = $key; 'Content-Type' = 'application/json' } `
  -Body '{"model":"gpt-5-6-sol","messages":[{"role":"user","content":"Say OK"}],"max_completion_tokens":16}' `
  -UseBasicParsing

$response.Headers['X-Foundry-Tier']
$response.Headers['X-Foundry-Tokens-Consumed']
$response.Headers['X-Foundry-Remaining-Tokens']
$response.Headers['X-Foundry-Remaining-Quota-Tokens']
```

Exceeding `tokens-per-minute` returns `429`; exceeding the daily `token-quota` returns `403`.

The call above intentionally uses a tiny budget because it only checks the throttling headers. It returns `200` with an empty `content` string, which is expected — see [Reasoning models and `max_completion_tokens`](#reasoning-models-and-max_completion_tokens).

## Reasoning models and `max_completion_tokens`

The deployed chat models are reasoning models. Reasoning tokens are drawn from `max_completion_tokens` *before* any visible text is produced, so an undersized budget returns `200` with `finish_reason: "length"` and an empty `content` string.

```text
max_completion_tokens=1000                    -> finish=length, 0 chars,    1000 reasoning tokens
max_completion_tokens=4000                    -> finish=stop,   5466 chars, 1867 reasoning tokens
max_completion_tokens=4000, effort=low        -> finish=stop,   5334 chars,  138 reasoning tokens
```

When you want visible output, budget roughly four times the text you expect, or pin the effort:

```json
{
  "model": "gpt-5-6-sol",
  "messages": [{ "role": "user", "content": "Write a 700 word essay about Azure API Management." }],
  "max_completion_tokens": 4000,
  "reasoning_effort": "low"
}
```

Reasoning tokens count toward `llm-token-limit` consumption and are reported separately as the `Completion Reasoning Tokens` metric, so throttling and metrics stay accurate either way.

## Demonstrate throttling in the test console

In the APIM test console, pick a tier subscription (`foundry-bronze-demo`, `foundry-silver-demo`, or `foundry-gold-demo`) rather than the default all-APIs master key. The master key bypasses product scope, so no tier policy runs.

The request above consumes roughly 3,300 tokens, which exceeds the bronze 1,000 tokens-per-minute ceiling. Sending it twice on the bronze key produces:

```text
call 1 -> HTTP 200  consumed=3342  remainingTPM=0
call 2 -> HTTP 429  {"statusCode":429,"message":"Token limit is exceeded. Try again in 59 seconds."}
```

The same request on the gold key succeeds repeatedly, because gold allows 20,000 tokens per minute.

## Inspect token metrics

Token consumption is emitted by `llm-emit-token-metric` in the Foundry API policy and lands in the environment's Application Insights component. Query the workspace:

```kusto
AppMetrics
| where Name in ("Total Tokens", "Prompt Tokens", "Completion Tokens")
| extend Product = tostring(Properties["Product ID"]), Operation = tostring(Properties["Operation ID"])
| summarize Tokens = sum(Sum) by Name, Product, Operation, bin(TimeGenerated, 5m)
| order by TimeGenerated desc
```

APIM emits one metric per token category reported by the model, including `Total Tokens`, `Prompt Tokens`, `Completion Tokens`, `Prompt Cached Tokens`, and `Completion Reasoning Tokens`. Every metric carries the `API ID`, `Operation ID`, `Product ID`, and `Subscription ID` dimensions.

Custom metric ingestion lags request telemetry by several minutes. To split Azure Monitor metric charts by dimension, set **Usage and estimated costs** > **Custom metrics (Preview)** to **With dimensions** on the Application Insights component once per environment; Azure exposes no supported ARM property for this preview setting.
