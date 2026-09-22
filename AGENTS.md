# Agent operating guide

Read `.github/copilot-instructions.md` before changing this repository.

- Start every implementation from an updated `main` and a new `feature/`, `bugfix/`, or `chore/` branch.
- Push the completed branch for user review; never implement directly on `main`.
- After the user confirms a merge, return to `main`, pull with `--ff-only`, verify a clean synchronized worktree, and wait there for the next task.
- Bootstrap resources and GitHub OIDC identities live under `bootstrap/`; workload deployment identities must remain scoped to their own resource groups.
- Infrastructure and model deployments live under `infra/` and are owned by Bicep.
- APIM APIs, backends, products, named values, and policies live under `apim-artifacts/` and are owned by APIOps.
- Environment-specific APIM property overrides live under `apiops/`.
- Never add credentials, Foundry keys, APIM subscription keys, or service-principal secrets.
- Keep PowerShell scripts compatible with Windows PowerShell 5.1.
- Validate changes with `.\scripts\Test-Repository.ps1`.
