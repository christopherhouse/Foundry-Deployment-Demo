---
name: promote-apiops-change
description: Implement and safely promote an APIM API, policy, product, backend, or named-value change with APIOps CLI.
---

1. Modify shared files under `apim-artifacts/`.
2. Put only required endpoint or environment differences in `apiops/configuration.<environment>.yaml`.
3. Check API/product/backend/named-value dependencies.
4. Run `scripts/Test-ApiOpsArtifacts.ps1`.
5. Use `apiops publish --dry-run` against dev before publishing.
6. Publish the same commit to dev and prod, with prod approval.
7. Never add secrets or `--delete-unmatched`.

