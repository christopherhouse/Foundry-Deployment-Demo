<#
.SYNOPSIS
Activates a local agent gateway profile.

.DESCRIPTION
Validates a secret-bearing agents\profiles\<profile>.env.local file and atomically
copies it to agents\.env. Profile values are never written to the console.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('foundry-apim', 'ai-gateway')]
    [string]$Profile
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$profilesRoot = Join-Path $repoRoot 'agents\profiles'
$profilePath = Join-Path $profilesRoot "$Profile.env.local"
$activePath = Join-Path $repoRoot 'agents\.env'

function Read-ProfileSettings {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $settings = @{}
    $lineNumber = 0
    foreach ($rawLine in [System.IO.File]::ReadAllLines($Path)) {
        $lineNumber++
        $line = $rawLine.Trim()
        if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith('#')) {
            continue
        }

        $separator = $line.IndexOf('=')
        if ($separator -le 0) {
            throw "Invalid profile entry at line $lineNumber in '$Path'."
        }

        $name = $line.Substring(0, $separator).Trim()
        if ($settings.ContainsKey($name)) {
            throw "Profile '$Path' contains duplicate setting '$name'."
        }

        $settings[$name] = $line.Substring($separator + 1).Trim().Trim('"')
    }

    return $settings
}

function Get-RequiredSetting {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Settings,

        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    if (-not $Settings.ContainsKey($Name) -or [string]::IsNullOrWhiteSpace($Settings[$Name])) {
        throw "Agent profile '$Profile' requires setting '$Name'."
    }

    $value = [string]$Settings[$Name]
    if ($value -match '^<[^>]+>$') {
        throw "Agent profile setting '$Name' still contains an example placeholder."
    }

    return $value
}

function Assert-PositiveInteger {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Settings,

        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $value = Get-RequiredSetting -Settings $Settings -Name $Name
    $parsed = 0
    if (-not [int]::TryParse($value, [ref]$parsed) -or $parsed -le 0) {
        throw "Agent profile setting '$Name' must be a positive integer."
    }
}

if (-not (Test-Path -LiteralPath $profilePath)) {
    throw "Agent profile '$profilePath' was not found. Initialize or copy its .example file first."
}

$settings = Read-ProfileSettings -Path $profilePath
$configuredProfile = Get-RequiredSetting -Settings $settings -Name 'AGENT_PROFILE'
if ($configuredProfile -ne $Profile) {
    throw "Agent profile '$profilePath' declares AGENT_PROFILE='$configuredProfile' instead of '$Profile'."
}

$baseUrl = Get-RequiredSetting -Settings $settings -Name 'AGENT_BASE_URL'
[System.Uri]$uri = $null
if ((-not ([System.Uri]::TryCreate($baseUrl, [System.UriKind]::Absolute, [ref]$uri))) -or ($uri.Scheme -ne 'https')) {
    throw "Agent profile setting 'AGENT_BASE_URL' must be an absolute HTTPS URL."
}

Get-RequiredSetting -Settings $settings -Name 'AGENT_MODEL' | Out-Null
$authMode = Get-RequiredSetting -Settings $settings -Name 'AGENT_AUTH_MODE'
if ($authMode -notin @('entra-plus-key', 'api-key')) {
    throw "Agent profile setting 'AGENT_AUTH_MODE' must be 'entra-plus-key' or 'api-key'."
}

$keyHeader = Get-RequiredSetting -Settings $settings -Name 'AGENT_KEY_HEADER'
if ($keyHeader -notmatch '^[A-Za-z0-9-]+$') {
    throw "Agent profile setting 'AGENT_KEY_HEADER' may contain only letters, digits, and hyphens."
}

$triageKey = Get-RequiredSetting -Settings $settings -Name 'AGENT_TRIAGE_GATEWAY_KEY'
$marketKey = Get-RequiredSetting -Settings $settings -Name 'AGENT_MARKET_GATEWAY_KEY'
if ($triageKey -ceq $marketKey) {
    throw 'The Ticket Triage and Market Brief agents must use different gateway keys.'
}
if ($authMode -eq 'entra-plus-key') {
    Get-RequiredSetting -Settings $settings -Name 'AGENT_TOKEN_SCOPE' | Out-Null
}

foreach ($name in @(
    'AGENT_RETRY_MAX_ATTEMPTS',
    'AGENT_RETRY_MAX_DELAY_SECONDS',
    'AGENT_RETRY_TOTAL_BUDGET_SECONDS'
)) {
    Assert-PositiveInteger -Settings $settings -Name $name
}

$temporaryPath = "$activePath.$PID.tmp"
$backupPath = "$activePath.$PID.bak"
try {
    $encoding = New-Object System.Text.UTF8Encoding($false)
    $content = [System.IO.File]::ReadAllText($profilePath)
    [System.IO.File]::WriteAllText($temporaryPath, $content, $encoding)

    if (Test-Path -LiteralPath $activePath) {
        [System.IO.File]::Replace($temporaryPath, $activePath, $backupPath)
        Remove-Item -LiteralPath $backupPath -Force
    }
    else {
        [System.IO.File]::Move($temporaryPath, $activePath)
    }
}
finally {
    if (Test-Path -LiteralPath $temporaryPath) {
        Remove-Item -LiteralPath $temporaryPath -Force
    }
    if (Test-Path -LiteralPath $backupPath) {
        Remove-Item -LiteralPath $backupPath -Force
    }
}

Write-Host "Activated agent profile '$Profile'."
Write-Host "Endpoint: $($uri.AbsoluteUri.TrimEnd('/'))"
Write-Host "Model: $($settings['AGENT_MODEL'])"
Write-Host "Authentication: $authMode"
