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
| P8.1 | Demo | Configure exact Azure/GitHub values | P7.1 | Not started | OIDC, variables, names, and publisher metadata are configured |
| P8.2 | Demo | Deploy dev infrastructure and APIOps baseline | P8.1 | Not started | Dev smoke tests pass |
| P8.3 | Demo | Approve and deploy prod | P8.2 | Not started | Prod smoke tests pass |
| P8.4 | Demo | Demonstrate model and APIM change CD | P8.3 | Not started | Both change paths and rollback are demonstrated |

## Decision log

| Date | Decision | Rationale |
|---|---|---|
| 2026-09-22 | Use Foundry `AIServices` accounts with child projects | Current Foundry resource model without legacy hubs |
| 2026-09-22 | Bicep owns infrastructure; APIOps owns APIM configuration | Prevents competing writers and independent release lifecycles |
| 2026-09-22 | Use APIOps CLI 1.0.3 | Current official package version reviewed during scaffold |
| 2026-09-22 | Use separate Developer APIM instances | Clear environment isolation for a cost-conscious demo |
| 2026-09-22 | Promote the same commit through protected environments | Auditable, repeatable dev-to-prod flow |

## Risks

| Risk | Response |
|---|---|
| Model version or quota unavailable | Verify before uncommenting model objects; keep model data parameterized |
| Developer SKU mistaken for production | Label all documentation and tags as demo/nonproduction |
| Global resource name collision | Edit names before deployment and keep APIOps overrides aligned |
| RBAC propagation delay | Retry smoke tests after role assignments settle |
| APIOps format/version changes | Pin version and upgrade only through a reviewed PR |

