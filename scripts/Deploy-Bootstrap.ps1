[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$AzureSubscriptionId = '8043efb5-d046-4aac-abcd-2c1a00e5ab86',
    [string]$ExpectedSubscriptionName = 'ME-MngEnvMCAP758145-chhouse-2',
    [string]$ExpectedTenantId = 'cd48c7b8-9369-443d-8a4c-bd1e53504a09',
    [string]$DeploymentLocation = 'westus3',
    [string]$GitHubOwner = 'christopherhouse',
    [string]$GitHubRepository = 'Foundry-Deployment-Demo',
    [string]$GitHubSubjectPrefix,
    [string]$ProdReviewerLogin = 'christopherhouse',
    [switch]$SkipGitHubConfiguration
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$bootstrapTemplate = Join-Path $repoRoot 'bootstrap\main.bicep'
$bootstrapParameters = Join-Path $repoRoot 'bootstrap\main.bicepparam'
$devParameters = Join-Path $repoRoot 'infra\environments\dev.bicepparam'
$prodParameters = Join-Path $repoRoot 'infra\environments\prod.bicepparam'
$repository = "$GitHubOwner/$GitHubRepository"

function Invoke-CheckedCommand {
    param(
        [Parameter(Mandatory = $true)]
        [scriptblock]$Command,

        [Parameter(Mandatory = $true)]
        [string]$FailureMessage
    )

    $result = & $Command
    if ($LASTEXITCODE -ne 0) {
        throw $FailureMessage
    }

    return $result
}

function Get-BicepStringParameter {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $content = Get-Content -LiteralPath $Path -Raw
    $pattern = "(?m)^\s*param\s+$([regex]::Escape($Name))\s*=\s*'([^']+)'\s*$"
    $match = [regex]::Match($content, $pattern)
    if (-not $match.Success) {
        throw "Unable to find string parameter '$Name' in '$Path'."
    }

    return $match.Groups[1].Value
}

foreach ($requiredFile in @($bootstrapTemplate, $bootstrapParameters, $devParameters, $prodParameters)) {
    if (-not (Test-Path -LiteralPath $requiredFile)) {
        throw "Required file does not exist: $requiredFile"
    }
}

Invoke-CheckedCommand `
    -Command { az account set --subscription $AzureSubscriptionId } `
    -FailureMessage "Unable to select Azure subscription '$AzureSubscriptionId'." | Out-Null

$account = Invoke-CheckedCommand `
    -Command { az account show --output json } `
    -FailureMessage 'Unable to read the selected Azure subscription.' |
    ConvertFrom-Json

if ($account.id -ne $AzureSubscriptionId) {
    throw "Selected subscription ID '$($account.id)' does not match '$AzureSubscriptionId'."
}

if ($account.name -ne $ExpectedSubscriptionName) {
    throw "Selected subscription name '$($account.name)' does not match '$ExpectedSubscriptionName'."
}

if ($account.tenantId -ne $ExpectedTenantId) {
    throw "Selected tenant '$($account.tenantId)' does not match '$ExpectedTenantId'."
}

$devResourceGroupName = Get-BicepStringParameter -Path $devParameters -Name 'resourceGroupName'
$prodResourceGroupName = Get-BicepStringParameter -Path $prodParameters -Name 'resourceGroupName'
$devFoundryAccountName = Get-BicepStringParameter -Path $devParameters -Name 'foundryAccountName'
$prodFoundryAccountName = Get-BicepStringParameter -Path $prodParameters -Name 'foundryAccountName'
$devApimServiceName = Get-BicepStringParameter -Path $devParameters -Name 'apimServiceName'
$prodApimServiceName = Get-BicepStringParameter -Path $prodParameters -Name 'apimServiceName'

$githubRepositoryName = $null
if (-not $GitHubSubjectPrefix -or -not $SkipGitHubConfiguration) {
    Invoke-CheckedCommand `
        -Command { gh auth status } `
        -FailureMessage 'GitHub CLI authentication is required to resolve repository OIDC settings.' |
        Out-Host

    $githubRepositoryName = Invoke-CheckedCommand `
        -Command { gh repo view $repository --json nameWithOwner --jq '.nameWithOwner' } `
        -FailureMessage "Unable to access GitHub repository '$repository'."

    if ($githubRepositoryName -ne $repository) {
        throw "GitHub repository '$githubRepositoryName' does not match '$repository'."
    }
}

if (-not $GitHubSubjectPrefix) {
    $oidcCustomizationJson = Invoke-CheckedCommand `
        -Command { gh api "repos/$repository/actions/oidc/customization/sub" } `
        -FailureMessage "Unable to read GitHub OIDC subject settings for '$repository'."

    $oidcCustomization = $oidcCustomizationJson | ConvertFrom-Json
    if (-not [string]::IsNullOrWhiteSpace($oidcCustomization.sub_claim_prefix)) {
        $GitHubSubjectPrefix = $oidcCustomization.sub_claim_prefix
    }
    elseif ($oidcCustomization.use_immutable_subject -eq $true) {
        throw "GitHub reports immutable OIDC subjects for '$repository' without a subject prefix."
    }
    else {
        $GitHubSubjectPrefix = "repo:$repository"
    }
}

Write-Host "Subscription: $($account.name) ($($account.id))"
Write-Host "Tenant:       $($account.tenantId)"
Write-Host "Region:       $DeploymentLocation"
Write-Host "OIDC subject: ${GitHubSubjectPrefix}:environment:<environment>"

Invoke-CheckedCommand `
    -Command {
        az deployment sub what-if `
            --name 'foundry-demo-bootstrap-preview' `
            --location $DeploymentLocation `
            --template-file $bootstrapTemplate `
            --parameters $bootstrapParameters `
            --parameters location=$DeploymentLocation `
            --parameters githubSubjectPrefix=$GitHubSubjectPrefix `
            --no-pretty-print
    } `
    -FailureMessage 'Bootstrap what-if failed.' | Out-Host

if (-not $PSCmdlet.ShouldProcess($account.name, 'Deploy resource groups, GitHub OIDC identities, federated credentials, and scoped RBAC')) {
    return
}

Invoke-CheckedCommand `
    -Command {
        az deployment sub create `
            --name 'foundry-demo-bootstrap' `
            --location $DeploymentLocation `
            --template-file $bootstrapTemplate `
            --parameters $bootstrapParameters `
            --parameters location=$DeploymentLocation `
            --parameters githubSubjectPrefix=$GitHubSubjectPrefix `
            --output none
    } `
    -FailureMessage 'Bootstrap deployment failed.' |
    Out-Null

$deploymentOutputsJson = Invoke-CheckedCommand `
    -Command {
        az deployment sub show `
            --name 'foundry-demo-bootstrap' `
            --subscription $AzureSubscriptionId `
            --query properties.outputs `
            --output json
    } `
    -FailureMessage 'Unable to read bootstrap deployment outputs.'

$deploymentOutputs = $deploymentOutputsJson | ConvertFrom-Json

if ($deploymentOutputs.devResourceGroupName.value -ne $devResourceGroupName) {
    throw 'Development resource group differs between bootstrap and workload parameters.'
}

if ($deploymentOutputs.prodResourceGroupName.value -ne $prodResourceGroupName) {
    throw 'Production resource group differs between bootstrap and workload parameters.'
}

if (-not $SkipGitHubConfiguration) {
    gh variable get ENABLE_AUTOMATIC_RELEASE --repo $repository *> $null
    if ($LASTEXITCODE -ne 0) {
        Invoke-CheckedCommand `
            -Command {
                gh variable set ENABLE_AUTOMATIC_RELEASE `
                    --repo $repository `
                    --body 'false'
            } `
            -FailureMessage 'Unable to initialize the repository release gate.' |
            Out-Null
    }

    $environmentSettings = @(
        @{
            Name = 'dev'
            ClientId = $deploymentOutputs.devIdentityClientId.value
            ResourceGroup = $devResourceGroupName
            FoundryAccount = $devFoundryAccountName
            ApimService = $devApimServiceName
        },
        @{
            Name = 'prod'
            ClientId = $deploymentOutputs.prodIdentityClientId.value
            ResourceGroup = $prodResourceGroupName
            FoundryAccount = $prodFoundryAccountName
            ApimService = $prodApimServiceName
        }
    )

    foreach ($settings in $environmentSettings) {
        $environmentName = $settings.Name
        Invoke-CheckedCommand `
            -Command { gh api --method PUT "repos/$repository/environments/$environmentName" } `
            -FailureMessage "Unable to create GitHub environment '$environmentName'." |
            Out-Null

        $variables = @{
            AZURE_CLIENT_ID = $settings.ClientId
            AZURE_TENANT_ID = $ExpectedTenantId
            AZURE_SUBSCRIPTION_ID = $AzureSubscriptionId
            DEPLOYMENT_LOCATION = $DeploymentLocation
            APIM_RESOURCE_GROUP = $settings.ResourceGroup
            APIM_SERVICE_NAME = $settings.ApimService
            FOUNDRY_ACCOUNT_NAME = $settings.FoundryAccount
        }

        foreach ($variable in $variables.GetEnumerator()) {
            Invoke-CheckedCommand `
                -Command {
                    gh variable set $variable.Key `
                        --env $environmentName `
                        --repo $repository `
                        --body $variable.Value
                } `
                -FailureMessage "Unable to set '$($variable.Key)' for GitHub environment '$environmentName'." |
                Out-Null
        }
    }

    $prodReviewerId = Invoke-CheckedCommand `
        -Command { gh api "users/$ProdReviewerLogin" --jq '.id' } `
        -FailureMessage "Unable to resolve GitHub production reviewer '$ProdReviewerLogin'."

    $prodEnvironmentConfiguration = @{
        wait_timer = 0
        prevent_self_review = $false
        reviewers = @(
            @{
                type = 'User'
                id = [int64]$prodReviewerId
            }
        )
    } | ConvertTo-Json -Depth 5

    $prodEnvironmentConfigurationFile = [System.IO.Path]::GetTempFileName()
    try {
        Set-Content `
            -LiteralPath $prodEnvironmentConfigurationFile `
            -Value $prodEnvironmentConfiguration `
            -Encoding UTF8

        Invoke-CheckedCommand `
            -Command {
                gh api `
                    --method PUT `
                    "repos/$repository/environments/prod" `
                    --input $prodEnvironmentConfigurationFile
            } `
            -FailureMessage "Unable to configure '$ProdReviewerLogin' as the production environment reviewer." |
            Out-Null
    }
    finally {
        Remove-Item -LiteralPath $prodEnvironmentConfigurationFile -Force -ErrorAction SilentlyContinue
    }
}

Write-Host 'Bootstrap completed successfully.'
Write-Host "Dev identity client ID:  $($deploymentOutputs.devIdentityClientId.value)"
Write-Host "Prod identity client ID: $($deploymentOutputs.prodIdentityClientId.value)"
if (-not $SkipGitHubConfiguration) {
    Write-Host "Production reviewer: $ProdReviewerLogin"
    Write-Host 'Automatic releases remain disabled until ENABLE_AUTOMATIC_RELEASE is set to true.'
}
