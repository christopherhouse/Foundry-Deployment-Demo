targetScope = 'resourceGroup'

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

@description('Short environment name.')
@allowed([
  'dev'
  'prod'
])
param environmentName string

@description('Azure region for all resources in this environment.')
param location string

@description('Resource group name for this environment.')
param resourceGroupName string

@description('Globally unique Microsoft Foundry account name.')
param foundryAccountName string

@description('Foundry project name.')
param foundryProjectName string

@description('Globally unique API Management service name.')
param apimServiceName string

@description('API Management publisher display name.')
param apimPublisherName string

@description('API Management publisher email address.')
param apimPublisherEmail string

@description('Foundry model deployments for this environment.')
param modelDeployments ModelDeployment[] = []

@description('Tags applied to deployed resources.')
param tags object = {}

var moduleDeploymentSuffix = uniqueString(deployment().name)

module foundry './modules/foundry.bicep' = {
  name: 'foundry-${environmentName}-${moduleDeploymentSuffix}'
  params: {
    accountName: foundryAccountName
    projectName: foundryProjectName
    location: location
    modelDeployments: modelDeployments
    tags: tags
  }
}

module apim './modules/apim.bicep' = {
  name: 'apim-${environmentName}-${moduleDeploymentSuffix}'
  params: {
    serviceName: apimServiceName
    location: location
    publisherName: apimPublisherName
    publisherEmail: apimPublisherEmail
    tags: tags
  }
}

module foundryAccess './modules/role-assignments.bicep' = {
  name: 'foundry-access-${environmentName}-${moduleDeploymentSuffix}'
  dependsOn: [
    foundry
  ]
  params: {
    foundryAccountName: foundryAccountName
    principalId: apim.outputs.principalId
  }
}

output configuredResourceGroupName string = resourceGroupName
output resourceGroupId string = resourceGroup().id
output foundryAccountId string = foundry.outputs.accountId
output foundryEndpoint string = foundry.outputs.endpoint
output foundryOpenAiEndpoint string = foundry.outputs.openAiEndpoint
output foundryProjectId string = foundry.outputs.projectId
output modelDeploymentNames array = foundry.outputs.modelDeploymentNames
output apimServiceId string = apim.outputs.serviceId
output apimGatewayUrl string = apim.outputs.gatewayUrl
