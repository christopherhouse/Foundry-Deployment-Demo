# Change APIM configuration

1. Edit shared resources under `apim-artifacts/`.
2. Put endpoint or environment differences in `apiops/configuration.dev.yaml` and `apiops/configuration.prod.yaml`.
3. Run `.\scripts\Test-ApiOpsArtifacts.ps1`.
4. Open a pull request and review policy, OpenAPI, product, backend, and named-value dependencies.
5. Merge to publish to dev.
6. Review the dry run and smoke result, then approve prod.

Do not add `--delete-unmatched`. Use the manual extractor workflow only to establish or compare a controlled baseline; review extracted changes before merging.

