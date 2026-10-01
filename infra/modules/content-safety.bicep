@description('Globally unique Azure AI Content Safety account name.')
param accountName string

@description('Azure region.')
param location string

@description('Resource ID of the Log Analytics workspace that receives Content Safety logs and metrics.')
param logAnalyticsWorkspaceId string

@description('Resource tags.')
param tags object = {}

resource contentSafety 'Microsoft.CognitiveServices/accounts@2025-06-01' = {
  name: accountName
  location: location
  kind: 'ContentSafety'
  identity: {
    type: 'SystemAssigned'
  }
  sku: {
    name: 'S0'
  }
  tags: tags
  properties: {
    customSubDomainName: accountName
    disableLocalAuth: true
    publicNetworkAccess: 'Enabled'
  }
}

// The latest diagnostic settings API is preview-only and is required for categoryGroup.
#disable-next-line use-recent-api-versions
resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'content-safety-to-log-analytics'
  scope: contentSafety
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logAnalyticsDestinationType: 'Dedicated'
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

output accountId string = contentSafety.id
output endpoint string = contentSafety.properties.endpoint
