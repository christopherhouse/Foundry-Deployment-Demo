# Change APIM configuration

1. Edit shared resources under `apim-artifacts/`.
2. Put endpoint or environment differences in `apiops/configuration.dev.yaml` and `apiops/configuration.prod.yaml`.
3. Run `.\scripts\Test-ApiOpsArtifacts.ps1`.
4. Open a pull request and review policy, OpenAPI, product, backend, and named-value dependencies.
5. Merge to publish to dev.
6. Review the dry run and smoke result, then approve prod.

Do not add `--delete-unmatched`. Use the manual extractor workflow only to establish or compare a controlled baseline; review extracted changes before merging.

The Foundry API specification is generated from Microsoft's official Azure OpenAI v1 contract:

```powershell
.\scripts\Update-FoundryOpenApiSpec.ps1
```

The generator pins the upstream `azure-rest-api-specs` commit and converts its OpenAPI 3.2 operation catalog to an APIM-compatible OpenAPI 3.0.3 document. Keep the generated request and response schemas permissive; APIM is the proxy/configuration boundary, while the official OpenAI client models remain the authoritative payload contract.
