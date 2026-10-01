[CmdletBinding()]
param(
    [string]$ArtifactRoot = (Join-Path (Split-Path -Parent $PSScriptRoot) 'apim-artifacts')
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $ArtifactRoot -PathType Container)) {
    throw "APIOps artifact directory does not exist: $ArtifactRoot"
}

$policyExpressionAttributePattern = '(?<name>[\w:-]+)="(?<value>@\([^"]*".*?\))"(?=\s+(?:[\w:-]+=|/?>))'
$repairedCount = 0
$utf8WithoutBom = New-Object System.Text.UTF8Encoding($false)

Get-ChildItem -LiteralPath $ArtifactRoot -Filter 'policy.xml' -File -Recurse | ForEach-Object {
    $path = $_.FullName
    $content = [System.IO.File]::ReadAllText($path)
    $repaired = [regex]::Replace(
        $content,
        $policyExpressionAttributePattern,
        {
            param($match)

            $name = $match.Groups['name'].Value
            $value = $match.Groups['value'].Value -replace "'", '&apos;'
            return "$name='$value'"
        }
    )

    if ($repaired -ne $content) {
        [System.IO.File]::WriteAllText($path, $repaired, $utf8WithoutBom)
        $repairedCount++
    }
}

Write-Host "Repaired $repairedCount extracted APIOps policy file(s)."
