[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Push-Location $repoRoot

try {
    az bicep build --file .\infra\main.bicep --stdout | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw 'Bicep build failed.'
    }

    foreach ($parameterFile in @(
        '.\infra\environments\dev.bicepparam',
        '.\infra\environments\prod.bicepparam'
    )) {
        az bicep build-params --file $parameterFile --stdout | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "Bicep parameter build failed: $parameterFile"
        }
    }

    & (Join-Path $PSScriptRoot 'Test-ApiOpsArtifacts.ps1')

    if (-not (Test-Path -LiteralPath '.\node_modules')) {
        npm ci --ignore-scripts
        if ($LASTEXITCODE -ne 0) {
            throw 'npm ci failed.'
        }
    }

    $version = npx apiops --version
    if ($LASTEXITCODE -ne 0 -or $version -notmatch '^1\.0\.3') {
        throw "Expected APIOps CLI 1.0.3 but found '$version'."
    }

    Write-Host 'Repository validation passed.'
}
finally {
    Pop-Location
}

