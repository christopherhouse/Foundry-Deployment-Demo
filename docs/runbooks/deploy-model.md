# Deploy a model

1. Confirm the model, version, SKU, capacity, quota, and regional availability.
2. Add the deployment object to `modelDeployments` in `dev.bicepparam`.
3. Add the intended production definition to `prod.bicepparam`.
4. Run `.\scripts\Test-Repository.ps1`.
5. Open and merge a pull request.
6. Verify dev deployment and invoke the APIM API with the deployment name in the request body `model` property.
7. Approve the protected prod deployment.

To remove or roll back a deployment, revert the parameter change and redeploy. Treat removal as destructive and verify no clients still use the deployment name.

