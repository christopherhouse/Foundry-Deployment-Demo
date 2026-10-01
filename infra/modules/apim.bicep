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

@description('Application Insights component name used for API Management diagnostics and token metrics.')
param applicationInsightsName string

@description('Resource ID of the Log Analytics workspace that receives API Management resource logs and metrics.')
param logAnalyticsWorkspaceId string

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: applicationInsightsName
}

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

resource applicationInsightsLogger 'Microsoft.ApiManagement/service/loggers@2024-05-01' = {
  parent: apim
  name: 'applicationinsights'
  properties: {
    loggerType: 'applicationInsights'
    description: 'Application Insights logger for Foundry API telemetry and token metrics.'
    resourceId: applicationInsights.id
    isBuffered: true
    credentials: {
      connectionString: applicationInsights.properties.ConnectionString
    }
  }
}

// Service-scope diagnostic enables Application Insights logging for every API and turns on
// custom metric emission, which llm-emit-token-metric requires.
resource applicationInsightsDiagnostic 'Microsoft.ApiManagement/service/diagnostics@2024-05-01' = {
  parent: apim
  name: 'applicationinsights'
  properties: {
    loggerId: applicationInsightsLogger.id
    metrics: true
    alwaysLog: 'allErrors'
    logClientIp: true
    httpCorrelationProtocol: 'W3C'
    operationNameFormat: 'Name'
    verbosity: 'information'
    sampling: {
      samplingType: 'fixed'
      percentage: 100
    }
  }
}

// The latest diagnostic settings API is preview-only and is required for categoryGroup.
#disable-next-line use-recent-api-versions
resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'apim-to-log-analytics'
  scope: apim
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

output serviceId string = apim.id
output principalId string = apim.identity.principalId
output gatewayUrl string = 'https://${serviceName}.azure-api.net'
output applicationInsightsLoggerId string = applicationInsightsLogger.id
