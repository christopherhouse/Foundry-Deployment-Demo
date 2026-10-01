# Code Review: APIM Consumer Agents

**Review date:** October 1, 2026  
**Pull request:** #9 (`feature/apim-consumer-agents`)  
**Merge commit:** `12fa55e`  
**Reviewed range:** `52e0919..12fa55e`

The review covered the C#, PowerShell, APIM policy, Bicep, APIOps configuration,
and validation changes introduced by the pull request. It focused on
performance, complexity and maintainability, security, and stability.

| Severity | Identified issue | Type | Location | Proposed remediation |
| --- | --- | --- | --- | --- |
| High | The generated Entra application ID and tenant are not propagated to APIM. The initialization script can configure agents for a new application while APIM continues validating hard-coded values, causing every request to return HTTP 401. | Stability; complexity | `scripts/New-AgentAppRegistration.ps1:41-68`; `scripts/Initialize-AgentDemo.ps1:59-62`; `apiops/configuration.dev.yaml:13-21`; `apiops/configuration.prod.yaml:13-21`; `apim-artifacts/apis/foundry-openai-v1/policy.xml:3-9` | Make the tenant and application IDs explicit deployment inputs shared by application provisioning and APIOps overrides. Alternatively, fail initialization when the discovered IDs differ from APIM. Extend deployed validation to compare the actual named-value contents. |
| Medium | App registration discovery uses only the non-unique display name. A same-named, unrelated application could have its identifier URI, scopes, and pre-authorized clients overwritten. | Security; stability | `scripts/New-AgentAppRegistration.ps1:41-67,94-136` | Require or persist the immutable application or object ID. For initial name-based discovery, verify a repository-specific ownership marker and expected identifier URI before making changes. Refuse to modify ambiguous or unrecognized applications. |
| Medium | When the next `Retry-After` delay exceeds the remaining retry budget, the policy returns a zero delay rather than stopping. This results in immediate retry attempts against an already-throttled service. | Stability | `agents/src/FoundryAgents.Core/RetryAfterPolicy.cs:39-68` | Determine whether the delay fits before approving the retry. If it does not, mark the retry budget exhausted and return `false` from `ShouldRetry`. |
| Medium | The custom retry policy rejects every exception without consulting the SDK base policy, disabling retries for transient connection resets, DNS failures, timeouts, and similar transport errors. | Stability | `agents/src/FoundryAgents.Core/RetryAfterPolicy.cs:22-26` | Preserve `base.ShouldRetry(message, exception)` for transient exceptions while enforcing the configured attempt and total-wait limits. Suppress only explicitly non-transient failures. |
| Medium | APIM accepts only Azure CLI client tokens, but the agent uses `DefaultAzureCredential`, which may select Visual Studio, Visual Studio Code, managed identity, environment credentials, or another client that APIM rejects. | Stability; complexity | `agents/src/FoundryAgents.Core/ApimChatClient.cs:19-22`; `apim-artifacts/apis/foundry-openai-v1/policy.xml:3-6` | Use `AzureCliCredential` if Azure CLI is intentionally the only permitted client. Otherwise, explicitly configure the allowed credential sources and include their application IDs in the APIM authorization policy. |

## Performance assessment

No credible performance defect was identified in the merged changes. The
zero-delay retry behavior can increase traffic during throttling, but its
primary impact is service stability and reliability.
