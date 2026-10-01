[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true)]
    [string]$FoundryAccountName,

    [Parameter(Mandatory = $true)]
    [string]$ApimServiceName
)

$ErrorActionPreference = 'Stop'

$foundryId = az cognitiveservices account show `
    --resource-group $ResourceGroupName `
    --name $FoundryAccountName `
    --query id `
    --output tsv

if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($foundryId)) {
    throw 'Foundry account was not found.'
}

$apimId = az apim show `
    --resource-group $ResourceGroupName `
    --name $ApimServiceName `
    --query id `
    --output tsv

if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($apimId)) {
    throw 'API Management service was not found.'
}

$apiName = az rest `
    --method get `
    --url "$apimId/apis/foundry-openai-v1?api-version=2024-05-01" `
    --query name `
    --output tsv

if ($LASTEXITCODE -ne 0 -or $apiName -ne 'foundry-openai-v1') {
    throw 'Foundry APIM API was not found.'
}

foreach ($namedValueName in @('entra-tenant-id', 'agent-client-application-id', 'agent-token-audience')) {
    $foundNamedValue = az rest `
        --method get `
        --url "$apimId/namedValues/$namedValueName`?api-version=2024-05-01" `
        --query name `
        --output tsv

    if ($LASTEXITCODE -ne 0 -or $foundNamedValue -ne $namedValueName) {
        throw "APIM named value '$namedValueName' was not found."
    }
}

$apiPolicy = az rest `
    --method get `
    --url "$apimId/apis/foundry-openai-v1/policies/policy?api-version=2024-05-01&format=rawxml" `
    --query properties.value `
    --output tsv

if ($LASTEXITCODE -ne 0 -or $apiPolicy -notmatch '<validate-azure-ad-token') {
    throw 'The Foundry API policy is missing Microsoft Entra token validation.'
}

foreach ($productName in @('foundry-demo', 'foundry-bronze', 'foundry-silver', 'foundry-gold')) {
    $foundProduct = az rest `
        --method get `
        --url "$apimId/products/$productName`?api-version=2024-05-01" `
        --query name `
        --output tsv

    if ($LASTEXITCODE -ne 0 -or $foundProduct -ne $productName) {
        throw "APIM product '$productName' was not found."
    }
}

$diagnosticMetrics = az rest `
    --method get `
    --url "$apimId/diagnostics/applicationinsights?api-version=2024-05-01" `
    --query properties.metrics `
    --output tsv

if ($LASTEXITCODE -ne 0 -or $diagnosticMetrics -ne 'true') {
    throw 'APIM Application Insights diagnostic is missing or does not have custom metrics enabled.'
}

Write-Host 'Deployed environment resource checks passed.'

