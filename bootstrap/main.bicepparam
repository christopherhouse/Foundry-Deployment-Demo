using './main.bicep'

param location = 'westus3'
param devResourceGroupName = 'rg-foundrydeploydemo-dev'
param prodResourceGroupName = 'rg-foundrydeploydemo-prod'
param devIdentityName = 'id-foundrydeploydemo-dev-github'
param prodIdentityName = 'id-foundrydeploydemo-prod-github'
param githubOwner = 'christopherhouse'
param githubRepository = 'Foundry-Deployment-Demo'

param tags = {
  Application: 'FoundryDeploymentDemo'
  Purpose: 'GitHubActionsBootstrap'
  Workload: 'AI'
}

