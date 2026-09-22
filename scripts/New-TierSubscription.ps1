<#
.SYNOPSIS
Creates or updates an API Management subscription scoped to one Foundry product tier and returns its primary key.

.DESCRIPTION
Product-scope token limits only apply when a caller authenticates with a subscription scoped to that
product, so demonstrating the bronze/silver/gold tiers requires one subscription per tier.

Subscriptions hold secrets, so they are deliberately not stored as APIOps artifacts. Create them with
this script and keep the returned key out of source control.

.EXAMPLE
.\New-TierSubscription.ps1 -ResourceGroupName rg-foundrydeploydemo-dev -ApimServiceName apim-foundrydeploydemo-dev-ch -Tier gold
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true)]
    [string]$ApimServiceName,

    [Parameter(Mandatory = $true)]
    [ValidateSet('bronze', 'silver', 'gold')]
    [string]$Tier,

    [Parameter(Mandatory = $false)]
    [string]$SubscriptionName
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($SubscriptionName)) {
    $SubscriptionName = "foundry-$Tier-demo"
}

$apimId = az apim show --resource-group $ResourceGroupName --name $ApimServiceName --query id --output tsv
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($apimId)) {
    throw "API Management service '$ApimServiceName' was not found in resource group '$ResourceGroupName'."
}

$payload = @{
    properties = @{
        displayName = "Foundry $Tier tier"
        scope       = "$apimId/products/foundry-$Tier"
        state       = 'active'
    }
} | ConvertTo-Json -Compress

$bodyFile = New-TemporaryFile
try {
    Set-Content -LiteralPath $bodyFile -Value $payload -Encoding ascii

    az rest `
        --method put `
        --url "$apimId/subscriptions/$SubscriptionName`?api-version=2024-05-01" `
        --headers 'Content-Type=application/json' `
        --body "@$bodyFile" `
        --output none

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create subscription '$SubscriptionName'."
    }
}
finally {
    Remove-Item -LiteralPath $bodyFile -Force -ErrorAction SilentlyContinue
}

$primaryKey = az rest `
    --method post `
    --url "$apimId/subscriptions/$SubscriptionName/listSecrets?api-version=2024-05-01" `
    --query primaryKey `
    --output tsv

if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($primaryKey)) {
    throw "Failed to read the primary key for subscription '$SubscriptionName'."
}

Write-Host "Subscription '$SubscriptionName' is scoped to product 'foundry-$Tier'."
return $primaryKey
