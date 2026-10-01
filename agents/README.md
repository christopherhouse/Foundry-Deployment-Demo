# Switchable AI gateway demo agents

Two unattended .NET 10 console agents can run through either of two local profiles:

- **`foundry-apim`** uses Microsoft Entra authentication plus separate bronze and gold APIM subscription keys.
- **`ai-gateway`** uses separate `api-key` credentials for the Ticket Triage and Market Brief agents, with no Entra token.

Each profile carries its own OpenAI-compatible base URL and model deployment name. Both agents print model token usage, retry waits, and a per-run summary. Foundry-specific gateway headers are printed only when the active gateway returns them.

## Initialize profiles

```powershell
# Creates and activates agents\profiles\foundry-apim.env.local
.\scripts\Initialize-AgentDemo.ps1

# Securely prompts for two AI Gateway API keys and activates the profile
.\scripts\Initialize-AiGatewayAgentProfile.ps1 -Model '<registered-model-alias>'
```

The AI Gateway profile defaults to:

```text
https://astral-spring-2206.azure-api.net/default/models/openai/v1
```

Both local profile files and the generated `agents\.env` are ignored by Git.

Use the exact model name shown under AI Gateway **Models (preview)**, including any provider or account prefix. For example: `foundrydeploydemo-dev-ch/gpt-4o-mini`.

## Switch and run

```powershell
.\scripts\Switch-AgentDemoProfile.ps1 -Profile foundry-apim
.\scripts\Switch-AgentDemoProfile.ps1 -Profile ai-gateway

dotnet build .\agents\FoundryAgents.slnx
.\agents\run-demo.ps1 -Profile foundry-apim
.\agents\run-demo.ps1 -Profile ai-gateway
```

Omit `-Profile` to use the currently active `agents\.env`. The switcher validates the complete source profile before replacing the active configuration and never prints credential values.
