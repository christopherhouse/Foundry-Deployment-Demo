@description('Globally unique Microsoft Foundry account name.')
param accountName string

@description('Foundry project name.')
param projectName string

@description('Azure region.')
param location string

@description('Model deployment definitions.')
param modelDeployments ModelDeployment[] = []

@description('Resource tags.')
param tags object = {}

resource foundry 'Microsoft.CognitiveServices/accounts@2025-06-01' = {
  name: accountName
  location: location
  kind: 'AIServices'
  identity: {
    type: 'SystemAssigned'
  }
  sku: {
    name: 'S0'
  }
  tags: tags
  properties: {
    allowProjectManagement: true
    customSubDomainName: accountName
    defaultProject: projectName
    disableLocalAuth: true
    publicNetworkAccess: 'Enabled'
    restrictOutboundNetworkAccess: false
  }

  resource project 'projects' = {
    name: projectName
    location: location
    identity: {
      type: 'SystemAssigned'
    }
    tags: tags
    properties: {
      displayName: projectName
      description: 'Foundry Deployment Demo project'
    }
  }

  @batchSize(1)
  resource deployments 'deployments' = [for deployment in modelDeployments: {
    name: deployment.name
    sku: {
      name: deployment.sku.name
      capacity: deployment.sku.capacity
    }
    properties: {
      model: {
        format: deployment.model.format
        name: deployment.model.name
        version: deployment.model.version
      }
      versionUpgradeOption: deployment.versionUpgradeOption
    }
    dependsOn: [
      project
    ]
  }]
}

output accountId string = foundry.id
output endpoint string = foundry.properties.endpoint
output openAiEndpoint string = 'https://${accountName}.openai.azure.com'
output projectId string = foundry::project.id
output modelDeploymentNames array = [for deployment in modelDeployments: deployment.name]

type ModelDeployment = {
  name: string
  model: {
    format: string
    name: string
    version: string
  }
  sku: {
    name: string
    capacity: int
  }
  versionUpgradeOption: 'OnceNewDefaultVersionAvailable' | 'OnceCurrentVersionExpired' | 'NoAutoUpgrade'
}
