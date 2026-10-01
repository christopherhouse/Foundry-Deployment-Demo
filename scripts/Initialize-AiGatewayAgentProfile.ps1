<#
.SYNOPSIS
Creates and optionally activates the local AI Gateway agent profile.

.DESCRIPTION
Writes the AI Gateway URL, exact registered model alias, and two securely prompted
API keys to the gitignored agents\profiles\ai-gateway.env.local file.
#>
[CmdletBinding()]
param(
    [string]$BaseUrl = 'https://astral-spring-2206.azure-api.net/default/models/openai/v1',

    [Parameter(Mandatory = $true, HelpMessage = 'Exact model name registered under AI Gateway Models (preview).')]
    [string]$Model,

    [System.Security.SecureString]$TriageApiKey,

    [System.Security.SecureString]$MarketApiKey,

    [switch]$NoActivate
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$profilesRoot = Join-Path $repoRoot 'agents\profiles'
$profilePath = Join-Path $profilesRoot 'ai-gateway.env.local'
$switchScript = Join-Path $PSScriptRoot 'Switch-AgentDemoProfile.ps1'

function ConvertFrom-SecureValue {
    param(
        [Parameter(Mandatory = $true)]
        [System.Security.SecureString]$Value
    )

    $pointer = [IntPtr]::Zero
    try {
        $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Value)
        return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)
    }
    finally {
        if ($pointer -ne [IntPtr]::Zero) {
            [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer)
        }
    }
}

if ($null -eq $TriageApiKey) {
    $TriageApiKey = Read-Host 'Ticket Triage Agent API key' -AsSecureString
}
if ($null -eq $MarketApiKey) {
    $MarketApiKey = Read-Host 'Market Brief Analyst API key' -AsSecureString
}

$triageKey = ConvertFrom-SecureValue -Value $TriageApiKey
$marketKey = ConvertFrom-SecureValue -Value $MarketApiKey
if ([string]::IsNullOrWhiteSpace($Model)) {
    throw 'The AI Gateway model name is required.'
}
if ([string]::IsNullOrWhiteSpace($triageKey) -or [string]::IsNullOrWhiteSpace($marketKey)) {
    throw 'Both AI Gateway API keys are required.'
}
if (($BaseUrl -match '[\r\n]') -or ($Model -match '[\r\n]') -or ($triageKey -match '[\r\n]') -or ($marketKey -match '[\r\n]')) {
    throw 'AI Gateway profile values may not contain newline characters.'
}
if ($triageKey -ceq $marketKey) {
    throw 'The Ticket Triage and Market Brief agents must use different API keys.'
}

New-Item -ItemType Directory -Path $profilesRoot -Force | Out-Null
$settings = @(
    'AGENT_PROFILE=ai-gateway'
    "AGENT_BASE_URL=$($BaseUrl.TrimEnd('/'))"
    "AGENT_MODEL=$Model"
    'AGENT_AUTH_MODE=api-key'
    'AGENT_KEY_HEADER=api-key'
    'AGENT_TRIAGE_LABEL=ticket'
    'AGENT_MARKET_LABEL=market'
    'AGENT_REASONING_EFFORT=none'
    "AGENT_TRIAGE_GATEWAY_KEY=$triageKey"
    "AGENT_MARKET_GATEWAY_KEY=$marketKey"
    'AGENT_RETRY_MAX_ATTEMPTS=5'
    'AGENT_RETRY_MAX_DELAY_SECONDS=90'
    'AGENT_RETRY_TOTAL_BUDGET_SECONDS=180'
)

$encoding = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllLines($profilePath, $settings, $encoding)
Write-Host "AI Gateway agent profile written to '$profilePath'."
Write-Host 'The file contains API keys and must remain uncommitted.'

if (-not $NoActivate) {
    & $switchScript -Profile 'ai-gateway'
}
