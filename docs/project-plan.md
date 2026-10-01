# Project plan

Update `Status` as work progresses. Valid values are `Not started`, `In progress`, `Blocked`, and `Done`.

| ID | Phase | Task | Depends on | Status | Acceptance criteria |
|---|---|---|---|---|---|
| P1.1 | Repository | Establish repository structure and governance | - | Done | README, ignore rules, templates, and ownership guidance exist |
| P1.2 | Repository | Add charter, architecture, decisions, and runbooks | P1.1 | Done | Documentation covers scope, ownership, operation, and rollback |
| P2.1 | Copilot | Add repository/path instructions | P1.1 | Done | Bicep/APIOps/security invariants are explicit |
| P2.2 | Copilot | Add custom agents and skills | P2.1 | Done | Foundry, APIOps, and release workflows have focused guidance |
| P3.1 | IaC | Implement Foundry and project module | P1.1 | Done | Module compiles and supports model arrays |
| P3.2 | IaC | Implement APIM and RBAC modules | P3.1 | Done | APIM identity receives Foundry invocation role |
| P3.3 | IaC | Add dev/prod parameter files | P3.2 | Done | Both environments compile independently |
| P4.1 | APIOps | Initialize and pin APIOps CLI | P1.1 | Done | Node dependency is pinned and generated conventions reviewed |
| P4.2 | APIOps | Seed Foundry API artifacts | P4.1 | Done | API, backend, named values, product, and policy are represented |
| P4.3 | APIOps | Add dev/prod overrides and filters | P4.2 | Done | Shared artifacts promote with endpoint overrides |
| P5.1 | Identity | Add OIDC bootstrap automation and guide | P3.2 | Done | Environments and federated identities can be configured |
| P6.1 | CI/CD | Add infrastructure validation and deployment workflows | P3.3, P5.1 | Done | Dev deploy and approval-gated prod promotion exist |
| P6.2 | CI/CD | Add APIOps validation and publishing workflows | P4.3, P5.1 | Done | Dry-run, dev publish, and prod promotion exist |
| P7.1 | Quality | Add local validation and smoke-test scripts | P6.1, P6.2 | Done | Repository and deployed environment checks are repeatable |
| P8.1 | Demo | Bootstrap Azure/GitHub foundation | P7.1 | Done | WU3 RGs, OIDC identities, scoped RBAC, environment variables, and prod approval are configured |
| P8.2 | Demo | Configure workload-specific values | P8.1 | Done | West US 3 model version/SKU/capacity values and subscription quota are confirmed by the successful dev deployment |
| P8.3 | Demo | Deploy dev infrastructure and APIOps baseline | P8.2 | Done | Dev infrastructure and the 106-operation v1 APIOps contract are published; `/models`, `/responses`, and `/embeddings` smoke tests pass |
| P8.4 | Demo | Approve and deploy prod | P8.3 | In progress | Prod smoke tests pass |
| P8.5 | Demo | Demonstrate model and APIM change CD | P8.4 | Not started | Both change paths and rollback are demonstrated |
| P9.1 | Governance | Add Log Analytics and Application Insights with APIM diagnostics | P8.3 | Done | Each environment has a dedicated workspace and component, and the APIM diagnostic has `metrics: true` |
| P9.2 | Governance | Add bronze/silver/gold products with tiered token limits | P9.1 | Done | Each product publishes the Foundry API and enforces its own `llm-token-limit` rate limit and daily quota |
| P9.3 | Governance | Emit token metrics from the Foundry API policy | P9.1 | Done | `llm-emit-token-metric` reports token consumption with API, operation, product, and subscription dimensions |

## Decision log

| Date | Decision | Rationale |
|---|---|---|
| 2026-09-22 | Use Foundry `AIServices` accounts with child projects | Current Foundry resource model without legacy hubs |
| 2026-09-22 | Bicep owns infrastructure; APIOps owns APIM configuration | Prevents competing writers and independent release lifecycles |
| 2026-09-22 | Use APIOps CLI 1.0.3 | Current official package version reviewed during scaffold |
| 2026-09-22 | Use separate Developer APIM instances | Clear environment isolation for a cost-conscious demo |
| 2026-09-22 | Promote the same commit through protected environments | Auditable, repeatable dev-to-prod flow |
| 2026-09-22 | Use WU3 UAMIs for GitHub OIDC | Keeps federation and RBAC in ARM/Bicep and scopes deployment permissions to each environment RG |
| 2026-09-22 | Use Data Zone Standard for three recent chat models and one embedding model | West US 3 catalog confirms GA support for GPT-6 Astra, GPT-5.6 Sol, GPT-5.6 Luna, and text-embedding-3-large |
| 2026-09-22 | Discover the GitHub OIDC subject prefix from the repository API | Immutable GitHub subjects include owner and repository IDs and must exactly match Azure federated credentials |
| 2026-09-22 | Register workload resource providers during bootstrap | RG-scoped deployment identities cannot register subscription providers during the release |
| 2026-09-22 | Serialize Foundry project and model child-resource writes | The Cognitive Services control plane rejects concurrent mutations of the same Foundry account |
| 2026-09-22 | Use unique nested deployment names and wait for APIM readiness | Canceled parent runs can leave long-running APIM module deployments active and block retries that reuse a static name |
| 2026-09-22 | Generate the APIM contract from the official Azure OpenAI v1 specification | The upstream contract is OpenAPI 3.2, so generation preserves all operations while downgrading to APIM-compatible OpenAPI 3.0.3 with permissive payload schemas |
| 2026-09-22 | Clear the Azure CLI exit code when APIM does not exist | A missing APIM service is the expected first-deployment state and must not fail the readiness step |
| 2026-09-22 | Let Bicep own the APIM Application Insights logger and diagnostic | The logger needs the component connection string; Bicep reads it in-template so no secret is committed, and the extractor filter keeps `loggers`/`diagnostics` out of APIOps |
| 2026-09-22 | Enforce token budgets with product-scope `llm-token-limit` and tier named values | Tier changes stay an APIOps-only change, and a per-tier `counter-key` prefix keeps the three counters independent |
| 2026-09-22 | Emit token metrics once at API scope instead of per product | A single `llm-emit-token-metric` with a `Product ID` dimension attributes consumption per tier without duplicating policy |
| 2026-09-22 | Re-authenticate to Azure after the infrastructure deployment step | Creating APIM can exceed the lifetime of the OIDC-derived Azure CLI token that the APIOps CLI reuses through `DefaultAzureCredential` |

## Risks

| Risk | Response |
|---|---|
| Model quota is insufficient | Keep automatic releases disabled until review; use the first dev deployment to confirm subscription quota and adjust requested TPM if necessary |
| Developer SKU mistaken for production | Label all documentation and tags as demo/nonproduction |
| Global resource name collision | Edit names before deployment and keep APIOps overrides aligned |
| RBAC propagation delay | Retry smoke tests after role assignments settle |
| APIOps format/version changes | Pin version and upgrade only through a reviewed PR |
