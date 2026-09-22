# Agent operating guide

Read `.github/copilot-instructions.md` before changing this repository.

- Infrastructure and model deployments live under `infra/` and are owned by Bicep.
- APIM APIs, backends, products, named values, and policies live under `apim-artifacts/` and are owned by APIOps.
- Environment-specific APIM property overrides live under `apiops/`.
- Never add credentials, Foundry keys, APIM subscription keys, or service-principal secrets.
- Keep PowerShell scripts compatible with Windows PowerShell 5.1.
- Validate changes with `.\scripts\Test-Repository.ps1`.

