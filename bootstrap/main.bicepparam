using './main.bicep'

param location = 'westus3'
param devResourceGroupName = 'rg-foundrydeploydemo-dev'
param prodResourceGroupName = 'rg-foundrydeploydemo-prod'
param devIdentityName = 'id-foundrydeploydemo-dev-github'
param prodIdentityName = 'id-foundrydeploydemo-prod-github'
param githubSubjectPrefix = 'repo:christopherhouse@748998/Foundry-Deployment-Demo@1381590348'

param tags = {
  Application: 'FoundryDeploymentDemo'
  Purpose: 'GitHubActionsBootstrap'
  Workload: 'AI'
}
