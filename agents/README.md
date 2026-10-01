# Foundry APIM demo agents

Two unattended .NET 10 console agents call the same `gpt-5-6-luna` deployment through APIM:

- **Ticket Triage Agent** uses `foundry-bronze` and makes many small calls, intentionally demonstrating TPM throttling and `Retry-After` recovery.
- **Market Brief Analyst** uses `foundry-gold` and makes three larger chained calls to produce a synthetic executive brief.

Both authenticate with a Microsoft Entra user token from `DefaultAzureCredential` and send a separate product-scoped APIM subscription key. They print model token usage, APIM token headers, retry waits, and a per-run summary.

## Run

```powershell
.\scripts\Initialize-AgentDemo.ps1

dotnet build .\agents\FoundryAgents.slnx
.\agents\run-demo.ps1
```

The initialization script writes `agents/.env`, which is ignored by git. No Foundry key, service-principal secret, or APIM subscription key is committed.
