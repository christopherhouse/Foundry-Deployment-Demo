<#
.SYNOPSIS
Creates or updates the secretless Microsoft Entra resource application used to authenticate the demo agents to APIM.

.DESCRIPTION
The application exposes a delegated user_impersonation scope and pre-authorizes the Azure CLI public client.
This lets DefaultAzureCredential use the signed-in Azure CLI user without a client secret. The application is a
resource API only; it does not receive a password, certificate, or federated credential.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$DisplayName = 'foundry-apim-demo-agents'
)

$ErrorActionPreference = 'Stop'
$azureCliClientId = '04b07795-8ddb-461a-bbee-02f9e1bf7b46'
$scopeValue = 'user_impersonation'

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

$account = Invoke-CheckedCommand `
    -Command { az account show --output json } `
    -FailureMessage 'Azure CLI authentication is required.' |
    ConvertFrom-Json

$appIds = @(Invoke-CheckedCommand `
    -Command { az ad app list --display-name $DisplayName --query '[].appId' --output tsv } `
    -FailureMessage "Unable to search for app registration '$DisplayName'." |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) })

if ($appIds.Count -gt 1) {
    throw "More than one app registration is named '$DisplayName'. Resolve the duplicate before continuing."
}

if ($appIds.Count -eq 0) {
    if (-not $PSCmdlet.ShouldProcess($DisplayName, 'Create Microsoft Entra app registration')) {
        return
    }

    Invoke-CheckedCommand `
        -Command {
            az ad app create `
                --display-name $DisplayName `
                --sign-in-audience AzureADMyOrg `
                --output none
        } `
        -FailureMessage "Unable to create app registration '$DisplayName'." |
        Out-Null
}

$appId = Invoke-CheckedCommand `
    -Command { az ad app list --display-name $DisplayName --query '[0].appId' --output tsv } `
    -FailureMessage "Unable to resolve the application ID for '$DisplayName'."
$objectId = Invoke-CheckedCommand `
    -Command { az ad app show --id $appId --query id --output tsv } `
    -FailureMessage "Unable to resolve the object ID for '$DisplayName'."

if ([string]::IsNullOrWhiteSpace($appId) -or [string]::IsNullOrWhiteSpace($objectId)) {
    throw "App registration '$DisplayName' did not return an application ID and object ID."
}

$current = Invoke-CheckedCommand `
    -Command { az ad app show --id $appId --output json } `
    -FailureMessage "Unable to read app registration '$DisplayName'." |
    ConvertFrom-Json

$scope = @($current.api.oauth2PermissionScopes | Where-Object { $_.value -eq $scopeValue }) | Select-Object -First 1
$scopeId = if ($null -ne $scope) { $scope.id } else { [guid]::NewGuid().ToString() }

$scopeDefinition = @{
    id = $scopeId
    adminConsentDescription = 'Allow the signed-in user to invoke the Foundry APIM demo API.'
    adminConsentDisplayName = 'Invoke the Foundry APIM demo API'
    isEnabled = $true
    type = 'User'
    userConsentDescription = 'Allow this application to invoke the Foundry APIM demo API on your behalf.'
    userConsentDisplayName = 'Invoke the Foundry APIM demo API'
    value = $scopeValue
}

if ($PSCmdlet.ShouldProcess($DisplayName, 'Configure identifier URI, delegated scope, and Azure CLI pre-authorization')) {
    $payloadFile = New-TemporaryFile
    try {
        $scopePayload = @{
            identifierUris = @("api://$appId")
            api = @{
                requestedAccessTokenVersion = 2
                oauth2PermissionScopes = @($scopeDefinition)
            }
        } | ConvertTo-Json -Depth 10 -Compress
        Set-Content -LiteralPath $payloadFile -Value $scopePayload -Encoding ascii
        Invoke-CheckedCommand `
            -Command {
                az rest `
                    --method patch `
                    --url "https://graph.microsoft.com/v1.0/applications/$objectId" `
                    --headers 'Content-Type=application/json' `
                    --body "@$payloadFile" `
                    --output none
            } `
            -FailureMessage "Unable to configure the delegated scope for '$DisplayName'." |
            Out-Null

        $preAuthorizationPayload = @{
            api = @{
                requestedAccessTokenVersion = 2
                oauth2PermissionScopes = @($scopeDefinition)
                preAuthorizedApplications = @(
                    @{
                        appId = $azureCliClientId
                        delegatedPermissionIds = @($scopeId)
                    }
                )
            }
        } | ConvertTo-Json -Depth 10 -Compress
        Set-Content -LiteralPath $payloadFile -Value $preAuthorizationPayload -Encoding ascii
        Invoke-CheckedCommand `
            -Command {
                az rest `
                    --method patch `
                    --url "https://graph.microsoft.com/v1.0/applications/$objectId" `
                    --headers 'Content-Type=application/json' `
                    --body "@$payloadFile" `
                    --output none
            } `
            -FailureMessage "Unable to pre-authorize Azure CLI for '$DisplayName'." |
            Out-Null
    }
    finally {
        Remove-Item -LiteralPath $payloadFile -Force -ErrorAction SilentlyContinue
    }
}

$servicePrincipals = @(Invoke-CheckedCommand `
    -Command { az ad sp list --filter "appId eq '$appId'" --output json } `
    -FailureMessage "Unable to search for the service principal for '$DisplayName'." |
    ConvertFrom-Json |
    Where-Object { $null -ne $_ })

if ($servicePrincipals.Count -eq 0 -and $PSCmdlet.ShouldProcess($DisplayName, 'Create service principal for the resource application')) {
    Invoke-CheckedCommand `
        -Command { az ad sp create --id $appId --output none } `
        -FailureMessage "Unable to create the service principal for '$DisplayName'." |
        Out-Null
}

$result = [pscustomobject]@{
    DisplayName = $DisplayName
    TenantId = $account.tenantId
    ApplicationId = $appId
    Audience = $appId
    Scope = "api://$appId/.default"
    AllowedClientApplicationId = $azureCliClientId
}

$result
