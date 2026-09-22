# Rollback

## Model or infrastructure change

Revert the commit that changed Bicep or `.bicepparam`, merge it, and run the infrastructure deployment workflow. A Git revert does not change Azure until the workflow deploys it.

## APIM configuration change

Revert the APIOps artifact commit, merge it, and run the APIOps publishing workflow. Review the dry run before applying.

## Troubleshooting checks

- Model deployment failure: verify region, model version, SKU, capacity, and quota.
- APIM provisioning: Developer SKU creation can take a significant amount of time.
- OIDC login: verify repository, branch/environment subject, client ID, tenant ID, and subscription ID.
- Authorization: allow time for role-assignment propagation and verify APIM's current principal ID.
- APIOps dependency error: confirm product associations, backend IDs, named values, and override resource names.
- Backend 401/403: verify the APIM identity has `Cognitive Services OpenAI User` on the correct Foundry account.

