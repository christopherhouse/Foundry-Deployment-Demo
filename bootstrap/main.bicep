targetScope = 'subscription'

@description('Azure region for the environment resource groups and deployment identities.')
param location string = 'westus3'

@description('Development resource group name.')
param devResourceGroupName string

@description('Production resource group name.')
param prodResourceGroupName string

@description('Development GitHub Actions user-assigned managed identity name.')
param devIdentityName string

@description('Production GitHub Actions user-assigned managed identity name.')
param prodIdentityName string

@description('GitHub repository owner.')
param githubOwner string

@description('GitHub repository name.')
param githubRepository string

@description('Tags applied to bootstrap resources.')
param tags object = {}

resource devResourceGroup 'Microsoft.Resources/resourceGroups@2025-04-01' = {
  name: devResourceGroupName
  location: location
  tags: union(tags, {
    Environment: 'dev'
    ManagedBy: 'Bicep'
    ringValue: 'r0'
  })
}

resource prodResourceGroup 'Microsoft.Resources/resourceGroups@2025-04-01' = {
  name: prodResourceGroupName
  location: location
  tags: union(tags, {
    Environment: 'prod'
    ManagedBy: 'Bicep'
    ringValue: 'r0'
  })
}

module devEnvironment './modules/environment-identity.bicep' = {
  name: 'bootstrap-dev-identity'
  scope: devResourceGroup
  params: {
    environmentName: 'dev'
    githubOwner: githubOwner
    githubRepository: githubRepository
    identityName: devIdentityName
    location: location
    tags: tags
  }
}

module prodEnvironment './modules/environment-identity.bicep' = {
  name: 'bootstrap-prod-identity'
  scope: prodResourceGroup
  params: {
    environmentName: 'prod'
    githubOwner: githubOwner
    githubRepository: githubRepository
    identityName: prodIdentityName
    location: location
    tags: tags
  }
}

output devResourceGroupName string = devResourceGroup.name
output devResourceGroupId string = devResourceGroup.id
output devIdentityName string = devEnvironment.outputs.identityName
output devIdentityClientId string = devEnvironment.outputs.clientId
output devIdentityPrincipalId string = devEnvironment.outputs.principalId
output prodResourceGroupName string = prodResourceGroup.name
output prodResourceGroupId string = prodResourceGroup.id
output prodIdentityName string = prodEnvironment.outputs.identityName
output prodIdentityClientId string = prodEnvironment.outputs.clientId
output prodIdentityPrincipalId string = prodEnvironment.outputs.principalId

