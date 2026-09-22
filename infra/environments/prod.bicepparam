using '../main.bicep'

param environmentName = 'prod'
param location = 'westus3'
param resourceGroupName = 'rg-foundrydeploydemo-prod'
param foundryAccountName = 'foundrydeploydemo-prod-ch'
param foundryProjectName = 'foundry-demo-prod'
param apimServiceName = 'apim-foundrydeploydemo-prod-ch'
param apimPublisherName = 'Foundry Deployment Demo'
param apimPublisherEmail = 'replace-me@example.com'

// Promote the same reviewed model definition used in dev after validating
// production quota and regional availability.
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
  Environment: 'prod'
  Workload: 'AI'
}
