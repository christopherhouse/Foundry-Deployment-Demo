type DataPlaneAdmin = {
  @description('Entra object ID of the principal receiving Foundry data plane administration access.')
  principalId: string

  @description('Principal type of the object ID, so role assignments do not fail on Graph replication delays.')
  principalType: 'User' | 'Group' | 'ServicePrincipal'
}

@description('Microsoft Foundry account name.')
param foundryAccountName string

@description('Principal ID that requires Foundry model invocation access.')
param principalId string

@description('Principals granted full Foundry data plane access on the Foundry account.')
param dataPlaneAdmins DataPlaneAdmin[] = []

var cognitiveServicesOpenAiUserRoleId = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'
)

// Full OpenAI data plane access: inference, fine-tuning, and deployment management.
var cognitiveServicesOpenAiContributorRoleId = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  'a001fd3d-188f-4b5d-821b-7da978bf7442'
)

// Foundry project data actions such as agents, threads, and evaluations.
var foundryUserRoleId = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  '53ca6127-db72-4b80-b1b0-d745d6d5456d'
)

resource foundry 'Microsoft.CognitiveServices/accounts@2025-06-01' existing = {
  name: foundryAccountName
}

resource foundryOpenAiUser 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(foundry.id, principalId, cognitiveServicesOpenAiUserRoleId)
  scope: foundry
  properties: {
    principalId: principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: cognitiveServicesOpenAiUserRoleId
  }
}

resource foundryOpenAiContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for admin in dataPlaneAdmins: {
    name: guid(foundry.id, admin.principalId, cognitiveServicesOpenAiContributorRoleId)
    scope: foundry
    properties: {
      principalId: admin.principalId
      principalType: admin.principalType
      roleDefinitionId: cognitiveServicesOpenAiContributorRoleId
    }
  }
]

resource foundryUser 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for admin in dataPlaneAdmins: {
    name: guid(foundry.id, admin.principalId, foundryUserRoleId)
    scope: foundry
    properties: {
      principalId: admin.principalId
      principalType: admin.principalType
      roleDefinitionId: foundryUserRoleId
    }
  }
]

output roleAssignmentId string = foundryOpenAiUser.id
output dataPlaneAdminRoleAssignmentIds array = [
  for (admin, index) in dataPlaneAdmins: [
    foundryOpenAiContributor[index].id
    foundryUser[index].id
  ]
]

