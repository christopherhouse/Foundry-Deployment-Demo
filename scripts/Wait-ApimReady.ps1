[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true)]
    [string]$ApimServiceName,

    [ValidateRange(1, 120)]
    [int]$TimeoutMinutes = 60,

    [ValidateRange(5, 300)]
    [int]$PollIntervalSeconds = 30
)

$ErrorActionPreference = 'Stop'
$deadline = (Get-Date).AddMinutes($TimeoutMinutes)

while ($true) {
    $output = az apim show `
        --resource-group $ResourceGroupName `
        --name $ApimServiceName `
        --query provisioningState `
        --output tsv 2>&1

    if ($LASTEXITCODE -ne 0) {
        $message = $output -join [Environment]::NewLine
        if ($message -match 'ResourceNotFound|could not be found') {
            Write-Host "APIM service '$ApimServiceName' does not exist yet."
            $global:LASTEXITCODE = 0
            return
        }

        throw "Unable to read APIM service '$ApimServiceName': $message"
    }

    $provisioningState = ($output | Select-Object -Last 1).Trim()
    if ($provisioningState -eq 'Succeeded') {
        Write-Host "APIM service '$ApimServiceName' is ready."
        return
    }

    if ($provisioningState -in @('Failed', 'Canceled', 'Deleted')) {
        throw "APIM service '$ApimServiceName' is in terminal state '$provisioningState'."
    }

    if ((Get-Date) -ge $deadline) {
        throw "Timed out waiting for APIM service '$ApimServiceName'. Current state: '$provisioningState'."
    }

    Write-Host "APIM service '$ApimServiceName' is '$provisioningState'. Waiting $PollIntervalSeconds seconds."
    Start-Sleep -Seconds $PollIntervalSeconds
}
