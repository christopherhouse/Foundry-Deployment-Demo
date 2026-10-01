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
    'namedValues\tier-bronze-tokens-per-minute\namedValueInformation.json',
    'namedValues\tier-bronze-token-quota\namedValueInformation.json',
    'namedValues\tier-silver-tokens-per-minute\namedValueInformation.json',
    'namedValues\tier-silver-token-quota\namedValueInformation.json',
    'namedValues\tier-gold-tokens-per-minute\namedValueInformation.json',
    'namedValues\tier-gold-token-quota\namedValueInformation.json',
    'products\foundry-demo\productInformation.json',
    'products\foundry-demo\apis.json',
    'products\foundry-bronze\productInformation.json',
    'products\foundry-bronze\apis.json',
    'products\foundry-bronze\policy.xml',
    'products\foundry-silver\productInformation.json',
    'products\foundry-silver\apis.json',
    'products\foundry-silver\policy.xml',
    'products\foundry-gold\productInformation.json',
    'products\foundry-gold\apis.json',
    'products\foundry-gold\policy.xml'
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

$apiPolicy = Get-Content -LiteralPath (Join-Path $artifactRoot 'apis\foundry-openai-v1\policy.xml') -Raw
if ($apiPolicy -notmatch '<llm-emit-token-metric') {
    throw 'The Foundry API policy must emit token metrics via llm-emit-token-metric.'
}

$tiers = @('bronze', 'silver', 'gold')
foreach ($tier in $tiers) {
    $policy = Get-Content -LiteralPath (Join-Path $artifactRoot "products\foundry-$tier\policy.xml") -Raw
    if ($policy -notmatch '<llm-token-limit') {
        throw "Product 'foundry-$tier' policy must apply the llm-token-limit policy."
    }

    foreach ($token in @("{{tier-$tier-tokens-per-minute}}", "{{tier-$tier-token-quota}}")) {
        if ($policy -notmatch [regex]::Escape($token)) {
            throw "Product 'foundry-$tier' policy must reference named value '$token'."
        }
    }

    $productApis = Get-Content -LiteralPath (Join-Path $artifactRoot "products\foundry-$tier\apis.json") -Raw | ConvertFrom-Json
    if (@($productApis).name -notcontains 'foundry-openai-v1') {
        throw "Product 'foundry-$tier' must include the foundry-openai-v1 API."
    }
}

# Tier limits must increase from bronze to gold in the base artifacts and in every override file.
$repoOverrides = Get-ChildItem -Path (Join-Path $repoRoot 'apiops') -Filter 'configuration.*.yaml' |
    Where-Object { $_.Name -ne 'configuration.extractor.yaml' }

foreach ($setting in @('tokens-per-minute', 'token-quota')) {
    $baseValues = $tiers | ForEach-Object {
        $file = Join-Path $artifactRoot "namedValues\tier-$_-$setting\namedValueInformation.json"
        [int](Get-Content -LiteralPath $file -Raw | ConvertFrom-Json).properties.value
    }

    if (-not ($baseValues[0] -lt $baseValues[1] -and $baseValues[1] -lt $baseValues[2])) {
        throw "Base '$setting' values must increase from bronze to gold but were $($baseValues -join ', ')."
    }

    foreach ($override in $repoOverrides) {
        $text = Get-Content -LiteralPath $override.FullName -Raw
        $overrideValues = $tiers | ForEach-Object {
            $match = [regex]::Match($text, "name:\s*tier-$_-$setting\s*\r?\n\s*properties:\s*\r?\n\s*value:\s*""(\d+)""")
            if (-not $match.Success) {
                throw "Override '$($override.Name)' is missing a value for tier-$_-$setting."
            }
            [int]$match.Groups[1].Value
        }

        if (-not ($overrideValues[0] -lt $overrideValues[1] -and $overrideValues[1] -lt $overrideValues[2])) {
            throw "Override '$($override.Name)' '$setting' values must increase from bronze to gold but were $($overrideValues -join ', ')."
        }
    }
}

$allText = Get-ChildItem -Path $artifactRoot -File -Recurse | ForEach-Object {
    Get-Content -LiteralPath $_.FullName -Raw
}

if (($allText -join "`n") -match '(?i)(client-secret|api-key\s*[:=]\s*[A-Za-z0-9]|REDACTED)') {
    throw 'Potential credential or unresolved redaction marker detected in APIOps artifacts.'
}

Write-Host 'APIOps artifact checks passed.'
