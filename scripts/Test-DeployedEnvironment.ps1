[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true)]
    [string]$FoundryAccountName,

    [Parameter(Mandatory = $true)]
    [string]$ContentSafetyAccountName,

    [Parameter(Mandatory = $true)]
    [string]$ApimServiceName
)

$ErrorActionPreference = 'Stop'

function Test-ResourceDiagnosticSetting {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResourceId,

        [Parameter(Mandatory = $true)]
        [string]$SettingName,

        [Parameter(Mandatory = $true)]
        [string]$ExpectedWorkspaceId
    )

    $settingJson = az monitor diagnostic-settings show `
        --resource $ResourceId `
        --name $SettingName `
        --output json

    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($settingJson)) {
        throw "Azure Monitor diagnostic setting '$SettingName' was not found."
    }

    $setting = $settingJson | ConvertFrom-Json
    if ($setting.workspaceId -ne $ExpectedWorkspaceId) {
        throw "Diagnostic setting '$SettingName' does not route to the environment Log Analytics workspace."
    }

    $allLogs = @($setting.logs | Where-Object {
        $_.enabled -eq $true -and $_.categoryGroup -eq 'allLogs'
    })
    if ($allLogs.Count -ne 1) {
        throw "Diagnostic setting '$SettingName' does not enable the allLogs category group."
    }

    $allMetrics = @($setting.metrics | Where-Object {
        $_.enabled -eq $true -and $_.category -eq 'AllMetrics'
    })
    if ($allMetrics.Count -ne 1) {
        throw "Diagnostic setting '$SettingName' does not enable AllMetrics."
    }
}

$workspaceIds = @(az monitor log-analytics workspace list `
    --resource-group $ResourceGroupName `
    --query '[].id' `
    --output tsv | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })

if ($LASTEXITCODE -ne 0 -or $workspaceIds.Count -ne 1) {
    throw 'Expected exactly one Log Analytics workspace in the environment resource group.'
}

$workspaceId = $workspaceIds[0]

$foundryId = az cognitiveservices account show `
    --resource-group $ResourceGroupName `
    --name $FoundryAccountName `
    --query id `
    --output tsv

if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($foundryId)) {
    throw 'Foundry account was not found.'
}

$contentSafetyJson = az cognitiveservices account show `
    --resource-group $ResourceGroupName `
    --name $ContentSafetyAccountName `
    --output json

if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($contentSafetyJson)) {
    throw 'Azure AI Content Safety account was not found.'
}

$contentSafety = $contentSafetyJson | ConvertFrom-Json
if ($contentSafety.kind -ne 'ContentSafety' -or $contentSafety.properties.disableLocalAuth -ne $true) {
    throw 'Azure AI Content Safety must use kind ContentSafety with local authentication disabled.'
}

$contentSafetyId = $contentSafety.id

$foundryProjectIds = @(az rest `
    --method get `
    --url "$foundryId/projects?api-version=2025-06-01" `
    --query 'value[].id' `
    --output tsv | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })

if ($LASTEXITCODE -ne 0 -or $foundryProjectIds.Count -ne 1) {
    throw 'Expected exactly one Foundry project in the environment account.'
}

$foundryProjectId = $foundryProjectIds[0]

$apimId = az apim show `
    --resource-group $ResourceGroupName `
    --name $ApimServiceName `
    --query id `
    --output tsv

if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($apimId)) {
    throw 'API Management service was not found.'
}

$apimPrincipalId = az apim show `
    --resource-group $ResourceGroupName `
    --name $ApimServiceName `
    --query identity.principalId `
    --output tsv

if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($apimPrincipalId)) {
    throw 'API Management system-assigned identity was not found.'
}

$contentSafetyRoleCount = az role assignment list `
    --scope $contentSafetyId `
    --assignee-object-id $apimPrincipalId `
    --query "[?roleDefinitionName == 'Cognitive Services User'] | length(@)" `
    --output tsv

if ($LASTEXITCODE -ne 0 -or [int]$contentSafetyRoleCount -ne 1) {
    throw 'APIM does not have Cognitive Services User on the Content Safety account.'
}

$apiName = az rest `
    --method get `
    --url "$apimId/apis/foundry-openai-v1?api-version=2024-05-01" `
    --query name `
    --output tsv

if ($LASTEXITCODE -ne 0 -or $apiName -ne 'foundry-openai-v1') {
    throw 'Foundry APIM API was not found.'
}

$contentSafetyBackendJson = az rest `
    --method get `
    --url "$apimId/backends/content-safety-backend?api-version=2024-05-01" `
    --output json

if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($contentSafetyBackendJson)) {
    throw 'APIM Content Safety backend was not found.'
}

$contentSafetyBackend = $contentSafetyBackendJson | ConvertFrom-Json
$expectedContentSafetyUrl = "https://$ContentSafetyAccountName.cognitiveservices.azure.com"
if ($contentSafetyBackend.properties.url -ne $expectedContentSafetyUrl) {
    throw "APIM Content Safety backend URL does not match '$expectedContentSafetyUrl'."
}

if ($contentSafetyBackend.properties.credentials.managedIdentity.resource -ne 'https://cognitiveservices.azure.com') {
    throw 'APIM Content Safety backend does not use managed identity authentication.'
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

if ($LASTEXITCODE -ne 0 -or -not ($apiPolicy -match '<validate-azure-ad-token')) {
    throw 'The Foundry API policy is missing Microsoft Entra token validation.'
}

if (
    $apiPolicy -notmatch '<llm-content-safety' -or
    $apiPolicy -notmatch 'backend-id="content-safety-backend"' -or
    $apiPolicy -notmatch 'shield-prompt="true"' -or
    $apiPolicy -notmatch 'enforce-on-completions="true"'
) {
    throw 'The Foundry API policy is missing balanced Content Safety enforcement.'
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

Test-ResourceDiagnosticSetting `
    -ResourceId $foundryId `
    -SettingName 'foundry-to-log-analytics' `
    -ExpectedWorkspaceId $workspaceId

Test-ResourceDiagnosticSetting `
    -ResourceId $foundryProjectId `
    -SettingName 'foundry-project-to-log-analytics' `
    -ExpectedWorkspaceId $workspaceId

Test-ResourceDiagnosticSetting `
    -ResourceId $contentSafetyId `
    -SettingName 'content-safety-to-log-analytics' `
    -ExpectedWorkspaceId $workspaceId

Test-ResourceDiagnosticSetting `
    -ResourceId $apimId `
    -SettingName 'apim-to-log-analytics' `
    -ExpectedWorkspaceId $workspaceId

Write-Host 'Deployed environment resource checks passed.'
