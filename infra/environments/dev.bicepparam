using '../main.bicep'

param environmentName = 'dev'
param location = 'eastus2'
param resourceGroupName = 'rg-foundrydeploydemo-dev'
param foundryAccountName = 'foundrydeploydemo-dev-ch'
param foundryProjectName = 'foundry-demo-dev'
param apimServiceName = 'apim-foundrydeploydemo-dev-ch'
param apimPublisherName = 'Foundry Deployment Demo'
param apimPublisherEmail = 'replace-me@example.com'

// Verify model availability, version, SKU, and quota in the selected region,
// then add one or more objects to this array.
param modelDeployments = [
  // {
  //   name: 'gpt-4-1-mini'
  //   model: {
  //     format: 'OpenAI'
  //     name: 'gpt-4.1-mini'
  //     version: '2025-04-14'
  //   }
  //   sku: {
  //     name: 'Standard'
  //     capacity: 10
  //   }
  //   versionUpgradeOption: 'NoAutoUpgrade'
  // }
]

param tags = {
  Application: 'FoundryDeploymentDemo'
  Environment: 'dev'
  Workload: 'AI'
}

