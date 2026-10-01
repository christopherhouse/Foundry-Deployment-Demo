<#
.SYNOPSIS
Initializes local configuration for the two .NET demo agents.

.DESCRIPTION
Creates/updates the secretless Entra resource app, creates product-scoped bronze and gold APIM subscriptions,
writes the resulting local Foundry APIM profile, and activates it as agents/.env.
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
$switchScript = Join-Path $PSScriptRoot 'Switch-AgentDemoProfile.ps1'
$profilesRoot = Join-Path $repoRoot 'agents\profiles'
$profilePath = Join-Path $profilesRoot 'foundry-apim.env.local'

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
    'AGENT_PROFILE=foundry-apim'
    "AGENT_BASE_URL=$($gatewayUrl.TrimEnd('/'))/openai/v1"
    'AGENT_MODEL=gpt-5-6-luna'
    'AGENT_AUTH_MODE=entra-plus-key'
    'AGENT_KEY_HEADER=Ocp-Apim-Subscription-Key'
    "AGENT_TOKEN_SCOPE=$($app.Scope)"
    'AGENT_TRIAGE_LABEL=bronze'
    'AGENT_MARKET_LABEL=gold'
    "AGENT_TRIAGE_GATEWAY_KEY=$bronzeKey"
    "AGENT_MARKET_GATEWAY_KEY=$goldKey"
    'AGENT_RETRY_MAX_ATTEMPTS=5'
    'AGENT_RETRY_MAX_DELAY_SECONDS=90'
    'AGENT_RETRY_TOTAL_BUDGET_SECONDS=180'
)

New-Item -ItemType Directory -Path $profilesRoot -Force | Out-Null
Set-Content -LiteralPath $profilePath -Value $settings -Encoding ascii
Write-Host "Foundry APIM agent profile written to '$profilePath'."
Write-Host 'The file contains APIM subscription keys and must remain uncommitted.'
& $switchScript -Profile 'foundry-apim'
