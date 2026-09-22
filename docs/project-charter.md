# Project charter

## Purpose

Demonstrate repeatable continuous delivery for Microsoft Foundry model deployments and Azure API Management configuration using Bicep, APIOps CLI, GitHub Actions, managed identity, and GitHub OIDC.

## Goals

- Deploy equivalent dev and prod Foundry/APIM environments in separate resource groups.
- Add model deployments by changing `.bicepparam` data rather than module code.
- Promote APIM API, backend, product, named-value, and policy changes through source control.
- Demonstrate approval-gated promotion of the same reviewed commit from dev to prod.
- Keep the repository understandable enough for a live customer or engineering demonstration.

## Non-goals

- Production SLA, multi-region design, or production APIM tier selection.
- VNets, private endpoints, private DNS, firewalls, or private runners.
- Application code, agent implementation, or data-plane workload development.
- Automatic model quota acquisition or model catalog discovery.

## Constraints

- One Azure subscription.
- Two Azure resource groups.
- Public endpoints.
- APIM Developer SKU in both environments.
- GitHub is the source-control and CI/CD platform.
- No stored Azure client secrets.

## Success measures

1. A model deployment change is merged, deployed to dev, approved, and deployed to prod.
2. An APIM policy or API artifact change is merged, published to dev, approved, and published to prod.
3. APIM invokes Foundry through managed identity.
4. Repository validation catches malformed Bicep, JSON, XML, ownership overlap, and common secret mistakes.

## Definition of done

The documented bootstrap succeeds in a target subscription, both CD paths complete, smoke tests pass, rollback is demonstrated, and the project plan records the completed demo milestone.

