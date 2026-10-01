<#
.SYNOPSIS
Initializes local configuration for the two .NET demo agents.

.DESCRIPTION
Creates/updates the secretless Entra resource app, creates product-scoped bronze and gold APIM subscriptions,
and writes the resulting local settings to the gitignored agents/.env file.
#>
[CmdletBinding()]
param(
    [string]$AzureSubscriptionId = '8043efb5-d046-4aac-abcd-2c1a00e5ab86',
    [string]$ResourceGroupName = 'rg-foundrydeploydemo-dev',
    [string]$ApimServiceName = 'apim-foundrydeploydemo-dev-ch'
)

$ErrorActionPreference = 'Stop'
az account set --subscription $AzureSubscriptionId
if ($LASTEXITCODE -ne 0) {
    throw "Unable to select Azure subscription '$AzureSubscriptionId'."
}
$repoRoot = Split-Path -Parent $PSScriptRoot
$appScript = Join-Path $PSScriptRoot 'New-AgentAppRegistration.ps1'
$subscriptionScript = Join-Path $PSScriptRoot 'New-TierSubscription.ps1'
$envPath = Join-Path $repoRoot 'agents\.env'

$appResults = @(& $appScript)
$app = $appResults | Where-Object { $null -ne $_.ApplicationId } | Select-Object -Last 1
if ($null -eq $app) {
    throw 'The agent app registration script did not return application settings.'
}

$gatewayUrl = az apim show `
    --resource-group $ResourceGroupName `
    --name $ApimServiceName `
    --query gatewayUrl `
    --output tsv
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($gatewayUrl)) {
    throw "Unable to resolve the gateway URL for APIM service '$ApimServiceName'."
}

$bronzeKey = & $subscriptionScript `
    -ResourceGroupName $ResourceGroupName `
    -ApimServiceName $ApimServiceName `
    -Tier bronze `
    -SubscriptionName 'triage-agent-bronze'
if ([string]::IsNullOrWhiteSpace($bronzeKey)) {
    throw 'The bronze APIM subscription did not return a primary key.'
}

$goldKey = & $subscriptionScript `
    -ResourceGroupName $ResourceGroupName `
    -ApimServiceName $ApimServiceName `
    -Tier gold `
    -SubscriptionName 'brief-agent-gold'
if ([string]::IsNullOrWhiteSpace($goldKey)) {
    throw 'The gold APIM subscription did not return a primary key.'
}

$settings = @(
    "FOUNDRY_APIM_BASE_URL=$($gatewayUrl.TrimEnd('/'))/openai/v1"
    "FOUNDRY_AGENT_SCOPE=$($app.Scope)"
    'FOUNDRY_MODEL=gpt-5-6-luna'
    "FOUNDRY_BRONZE_SUBSCRIPTION_KEY=$bronzeKey"
    "FOUNDRY_GOLD_SUBSCRIPTION_KEY=$goldKey"
    'FOUNDRY_RETRY_MAX_ATTEMPTS=5'
    'FOUNDRY_RETRY_MAX_DELAY_SECONDS=90'
    'FOUNDRY_RETRY_TOTAL_BUDGET_SECONDS=180'
)

Set-Content -LiteralPath $envPath -Value $settings -Encoding ascii
Write-Host "Agent configuration written to '$envPath'."
Write-Host 'The file contains APIM subscription keys and must remain uncommitted.'
