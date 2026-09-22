using '../main.bicep'

param environmentName = 'prod'
param location = 'westus3'
param resourceGroupName = 'rg-foundrydeploydemo-prod'
param foundryAccountName = 'foundrydeploydemo-prod-ch'
param foundryProjectName = 'foundry-demo-prod'
param apimServiceName = 'apim-foundrydeploydemo-prod-ch'
param apimPublisherName = 'Foundry Deployment Demo'
param apimPublisherEmail = 'replace-me@example.com'

// DataZoneStandard capacity is expressed in thousands of tokens per minute.
// Model versions and SKU support were verified in West US 3 on 2026-09-22.
param modelDeployments = [
  {
    name: 'gpt-6-astra'
    model: {
      format: 'OpenAI'
      name: 'gpt-6-astra'
      version: '2026-09-03'
    }
    sku: {
      name: 'DataZoneStandard'
      capacity: 50
    }
    versionUpgradeOption: 'NoAutoUpgrade'
  }
  {
    name: 'gpt-5-6-sol'
    model: {
      format: 'OpenAI'
      name: 'gpt-5.6-sol'
      version: '2026-07-09'
    }
    sku: {
      name: 'DataZoneStandard'
      capacity: 50
    }
    versionUpgradeOption: 'NoAutoUpgrade'
  }
  {
    name: 'gpt-5-6-luna'
    model: {
      format: 'OpenAI'
      name: 'gpt-5.6-luna'
      version: '2026-07-09'
    }
    sku: {
      name: 'DataZoneStandard'
      capacity: 50
    }
    versionUpgradeOption: 'NoAutoUpgrade'
  }
  {
    name: 'text-embedding-3-large'
    model: {
      format: 'OpenAI'
      name: 'text-embedding-3-large'
      version: '1'
    }
    sku: {
      name: 'DataZoneStandard'
      capacity: 50
    }
    versionUpgradeOption: 'NoAutoUpgrade'
  }
]

param tags = {
  Application: 'FoundryDeploymentDemo'
  Environment: 'prod'
  Workload: 'AI'
}
