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

$allText = Get-ChildItem -Path $artifactRoot -File -Recurse | ForEach-Object {
    Get-Content -LiteralPath $_.FullName -Raw
}

if (($allText -join "`n") -match '(?i)(client-secret|api-key\s*[:=]\s*[A-Za-z0-9]|REDACTED)') {
    throw 'Potential credential or unresolved redaction marker detected in APIOps artifacts.'
}

Write-Host 'APIOps artifact checks passed.'

