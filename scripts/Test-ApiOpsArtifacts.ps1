[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$artifactRoot = Join-Path $repoRoot 'apim-artifacts'

$requiredFiles = @(
    'apis\foundry-openai-v1\apiInformation.json',
    'apis\foundry-openai-v1\specification.yaml',
    'apis\foundry-openai-v1\policy.xml',
    'backends\foundry-backend\backendInformation.json',
    'namedValues\foundry-api-audience\namedValueInformation.json',
    'namedValues\foundry-rate-limit-calls\namedValueInformation.json',
    'products\foundry-demo\productInformation.json',
    'products\foundry-demo\apis.json'
)

foreach ($relativePath in $requiredFiles) {
    $path = Join-Path $artifactRoot $relativePath
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Required APIOps artifact is missing: $relativePath"
    }
}

Get-ChildItem -Path $artifactRoot -Filter '*.json' -Recurse | ForEach-Object {
    try {
        Get-Content -LiteralPath $_.FullName -Raw | ConvertFrom-Json | Out-Null
    }
    catch {
        throw "Invalid JSON artifact '$($_.FullName)': $($_.Exception.Message)"
    }
}

Get-ChildItem -Path $artifactRoot -Filter '*.xml' -Recurse | ForEach-Object {
    try {
        [xml](Get-Content -LiteralPath $_.FullName -Raw) | Out-Null
    }
    catch {
        throw "Invalid XML policy '$($_.FullName)': $($_.Exception.Message)"
    }
}

$openApiPath = Join-Path $artifactRoot 'apis\foundry-openai-v1\specification.yaml'
try {
    $openApi = Get-Content -LiteralPath $openApiPath -Raw | ConvertFrom-Json
}
catch {
    throw "Invalid generated OpenAPI artifact '$openApiPath': $($_.Exception.Message)"
}

if ($openApi.openapi -ne '3.0.3') {
    throw "Expected APIM-compatible OpenAPI 3.0.3 but found '$($openApi.openapi)'."
}

$requiredOperations = @(
    'createChatCompletion',
    'createCompletion',
    'createEmbedding',
    'createResponse',
    'getResponse',
    'listModels'
)

$operationIds = $openApi.paths.PSObject.Properties | ForEach-Object {
    $_.Value.PSObject.Properties | ForEach-Object {
        $_.Value.operationId
    }
}

foreach ($operationId in $requiredOperations) {
    if ($operationIds -notcontains $operationId) {
        throw "Required Azure OpenAI v1 operation is missing: $operationId"
    }
}

if ($operationIds.Count -lt 100) {
    throw "Expected the full Azure OpenAI v1 operation catalog but found only $($operationIds.Count) operations."
}

$allText = Get-ChildItem -Path $artifactRoot -File -Recurse | ForEach-Object {
    Get-Content -LiteralPath $_.FullName -Raw
}

if (($allText -join "`n") -match '(?i)(client-secret|api-key\s*[:=]\s*[A-Za-z0-9]|REDACTED)') {
    throw 'Potential credential or unresolved redaction marker detected in APIOps artifacts.'
}

Write-Host 'APIOps artifact checks passed.'
