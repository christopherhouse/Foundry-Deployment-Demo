@description('Short environment name.')
@allowed([
  'dev'
  'prod'
])
param environmentName string

@description('User-assigned managed identity name.')
param identityName string

@description('Azure region.')
param location string

@description('GitHub OIDC subject prefix for this repository.')
param githubSubjectPrefix string

@description('Resource tags.')
param tags object = {}

var contributorRoleDefinitionId = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  'b24988ac-6180-42a0-ab88-20f7382dd24c'
)

var userAccessAdministratorRoleDefinitionId = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  '18d7d88d-d35e-4fb5-a5c3-7773c20a72d9'
)

resource deploymentIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2024-11-30' = {
  name: identityName
  location: location
  tags: union(tags, {
    Environment: environmentName
    ManagedBy: 'Bicep'
  })

  resource githubEnvironmentCredential 'federatedIdentityCredentials' = {
    name: 'github-environment-${environmentName}'
    properties: {
      audiences: [
        'api://AzureADTokenExchange'
      ]
      issuer: 'https://token.actions.githubusercontent.com'
      subject: '${githubSubjectPrefix}:environment:${environmentName}'
    }
  }
}

resource contributorAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, deploymentIdentity.id, contributorRoleDefinitionId)
  properties: {
    principalId: deploymentIdentity.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: contributorRoleDefinitionId
  }
}

resource userAccessAdministratorAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, deploymentIdentity.id, userAccessAdministratorRoleDefinitionId)
  properties: {
    principalId: deploymentIdentity.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: userAccessAdministratorRoleDefinitionId
  }
}

output identityName string = deploymentIdentity.name
output clientId string = deploymentIdentity.properties.clientId
output principalId string = deploymentIdentity.properties.principalId
