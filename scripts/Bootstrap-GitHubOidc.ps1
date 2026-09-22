[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)]
    [string]$GitHubOwner,

    [Parameter(Mandatory = $true)]
    [string]$GitHubRepository,

    [Parameter(Mandatory = $true)]
    [ValidateSet('dev', 'prod')]
    [string]$Environment,

    [Parameter(Mandatory = $true)]
    [string]$AzureSubscriptionId,

    [Parameter(Mandatory = $true)]
    [string]$RoleScope
)

$ErrorActionPreference = 'Stop'
$appDisplayName = "foundry-apiops-$Environment-github"
$repo = "$GitHubOwner/$GitHubRepository"

az account set --subscription $AzureSubscriptionId
if ($LASTEXITCODE -ne 0) {
    throw 'Unable to select the Azure subscription.'
}

$tenantId = az account show --query tenantId --output tsv
$appId = az ad app list --display-name $appDisplayName --query '[0].appId' --output tsv

if ([string]::IsNullOrWhiteSpace($appId)) {
    if ($PSCmdlet.ShouldProcess($appDisplayName, 'Create Microsoft Entra application')) {
        $appId = az ad app create --display-name $appDisplayName --query appId --output tsv
        if ($LASTEXITCODE -ne 0) {
            throw 'Unable to create the Microsoft Entra application.'
        }
    }
}

$objectId = az ad app show --id $appId --query id --output tsv
$servicePrincipalId = az ad sp list --filter "appId eq '$appId'" --query '[0].id' --output tsv

if ([string]::IsNullOrWhiteSpace($servicePrincipalId)) {
    if ($PSCmdlet.ShouldProcess($appDisplayName, 'Create service principal')) {
        $servicePrincipalId = az ad sp create --id $appId --query id --output tsv
        if ($LASTEXITCODE -ne 0) {
            throw 'Unable to create the service principal.'
        }
    }
}

$credentialName = "github-environment-$Environment"
$credential = @{
    name = $credentialName
    issuer = 'https://token.actions.githubusercontent.com'
    subject = "repo:${GitHubOwner}/${GitHubRepository}:environment:${Environment}"
    description = "GitHub Actions $Environment environment"
    audiences = @('api://AzureADTokenExchange')
} | ConvertTo-Json -Depth 5

$tempFile = [System.IO.Path]::GetTempFileName()
try {
    Set-Content -LiteralPath $tempFile -Value $credential -Encoding UTF8
    if ($PSCmdlet.ShouldProcess($credentialName, 'Create or replace federated credential')) {
        $existingCredentialId = az ad app federated-credential list --id $objectId --query "[?name=='$credentialName'].id | [0]" --output tsv
        if (-not [string]::IsNullOrWhiteSpace($existingCredentialId)) {
            az ad app federated-credential delete --id $objectId --federated-credential-id $existingCredentialId
        }
        az ad app federated-credential create --id $objectId --parameters $tempFile | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw 'Unable to configure the federated credential.'
        }
    }
}
finally {
    Remove-Item -LiteralPath $tempFile -Force -ErrorAction SilentlyContinue
}

foreach ($roleName in @('Contributor', 'Role Based Access Control Administrator')) {
    if ($PSCmdlet.ShouldProcess($RoleScope, "Assign $roleName to $appDisplayName")) {
        az role assignment create `
            --assignee-object-id $servicePrincipalId `
            --assignee-principal-type ServicePrincipal `
            --role $roleName `
            --scope $RoleScope | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "Unable to assign the $roleName role."
        }
    }
}

if ($PSCmdlet.ShouldProcess("$repo/$Environment", 'Create GitHub environment and variables')) {
    gh api --method PUT "repos/$repo/environments/$Environment" | Out-Null
    gh variable set AZURE_CLIENT_ID --env $Environment --repo $repo --body $appId
    gh variable set AZURE_TENANT_ID --env $Environment --repo $repo --body $tenantId
    gh variable set AZURE_SUBSCRIPTION_ID --env $Environment --repo $repo --body $AzureSubscriptionId
}

Write-Host "Configured OIDC identity '$appDisplayName' for GitHub environment '$Environment'."
Write-Host 'Add a required reviewer to the prod environment and configure deployment resource variables.'
