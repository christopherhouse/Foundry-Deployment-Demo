using '../main.bicep'

param environmentName = 'dev'
param location = 'westus3'
param resourceGroupName = 'rg-foundrydeploydemo-dev'
param foundryAccountName = 'foundrydeploydemo-dev-ch'
param foundryProjectName = 'foundry-demo-dev'
param contentSafetyAccountName = 'cs-foundrydeploydemo-dev-ch'
param apimServiceName = 'apim-foundrydeploydemo-dev-ch'
param apimPublisherName = 'Foundry Deployment Demo'
param apimPublisherEmail = 'replace-me@example.com'
param logAnalyticsWorkspaceName = 'log-foundrydeploydemo-dev'
param applicationInsightsName = 'appi-foundrydeploydemo-dev'
param logAnalyticsRetentionInDays = 30

// DataZoneStandard capacity is expressed in thousands of tokens per minute.
// Model versions and SKU support were verified in West US 3 on 2026-10-01.
param modelDeployments = [
  // Catalog retirement for inference is scheduled for 2027-04-14.
  {
    name: 'gpt-4o-mini'
    model: {
      format: 'OpenAI'
      name: 'gpt-4o-mini'
      version: '2024-07-18'
    }
    sku: {
      name: 'DataZoneStandard'
      capacity: 50
    }
    versionUpgradeOption: 'NoAutoUpgrade'
  }
  {
    name: 'gpt-6-astra'
    model: {
      format: 'OpenAI'
      name: 'gpt-6-astra'
      version: '2026-09-03'
    }
    sku: {
      name: 'DataZoneStandard'
      capacity: 20
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
      capacity: 20
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
      capacity: 20
    }
    versionUpgradeOption: 'NoAutoUpgrade'
  }
  // Catalog retirement for inference is scheduled for 2028-01-11.
  {
    name: 'gpt-5-6-terra'
    model: {
      format: 'OpenAI'
      name: 'gpt-5.6-terra'
      version: '2026-07-09'
    }
    sku: {
      name: 'DataZoneStandard'
      capacity: 100
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
      capacity: 30
    }
    versionUpgradeOption: 'NoAutoUpgrade'
  }
]

// Entra object IDs granted Cognitive Services OpenAI Contributor and Foundry User
// on the Foundry account for full data plane access.
param foundryDataPlaneAdmins = [
  {
    principalId: 'fbe4845f-3ca2-4bc0-b2bd-e6f2dc79f2ae'
    principalType: 'User'
  }
]

param tags = {
  Application: 'FoundryDeploymentDemo'
  Environment: 'dev'
  Workload: 'AI'
}
