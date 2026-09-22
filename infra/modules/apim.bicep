@description('Globally unique API Management service name.')
param serviceName string

@description('Azure region.')
param location string

@description('Publisher display name.')
param publisherName string

@description('Publisher email address.')
param publisherEmail string

@description('Resource tags.')
param tags object = {}

resource apim 'Microsoft.ApiManagement/service@2024-05-01' = {
  name: serviceName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  sku: {
    name: 'Developer'
    capacity: 1
  }
  tags: tags
  properties: {
    publisherEmail: publisherEmail
    publisherName: publisherName
    publicNetworkAccess: 'Enabled'
    virtualNetworkType: 'None'
  }
}

output serviceId string = apim.id
output principalId string = apim.identity.principalId
output gatewayUrl string = 'https://${serviceName}.azure-api.net'

