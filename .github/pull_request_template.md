## Change

Describe the infrastructure, model, API, policy, product, or documentation change.

## Ownership

- [ ] Bicep-only infrastructure change
- [ ] APIOps-only APIM configuration change
- [ ] Coordinated change with correct deployment sequencing

## Validation

- [ ] `.\scripts\Test-Repository.ps1`
- [ ] Model availability/quota verified when model parameters changed
- [ ] APIOps dry run reviewed when APIM artifacts changed
- [ ] No secrets, keys, or unresolved placeholders added
- [ ] Documentation and project plan updated

## Promotion

Explain any intentional dev/prod difference and the rollback path.

