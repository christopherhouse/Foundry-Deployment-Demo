[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$agentsRoot = $PSScriptRoot
$triageProject = Join-Path $agentsRoot 'src\TriageAgent\TriageAgent.csproj'
$briefProject = Join-Path $agentsRoot 'src\BriefAgent\BriefAgent.csproj'
$envFile = Join-Path $agentsRoot '.env'

if (-not (Test-Path -LiteralPath $envFile)) {
    throw "Agent configuration '$envFile' was not found. Run .\scripts\Initialize-AgentDemo.ps1 first."
}

function Start-AgentProcess {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectPath
    )

    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = 'dotnet'
    $startInfo.Arguments = "run --project `"$ProjectPath`" --no-build"
    $startInfo.UseShellExecute = $false

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $startInfo
    if (-not $process.Start()) {
        throw "Unable to start agent project '$ProjectPath'."
    }

    return $process
}

$triage = Start-AgentProcess -ProjectPath $triageProject
$brief = Start-AgentProcess -ProjectPath $briefProject

$triage.WaitForExit()
$brief.WaitForExit()

Write-Host "Ticket Triage Agent exit code: $($triage.ExitCode)"
Write-Host "Market Brief Analyst exit code: $($brief.ExitCode)"

if ($triage.ExitCode -ne 0 -or $brief.ExitCode -ne 0) {
    exit 1
}
