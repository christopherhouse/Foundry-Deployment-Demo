[CmdletBinding()]
param(
    [string]$SourceCommit = 'a6943a926f76b3a2f90371b3466157eddf760e25',
    [string]$DestinationPath
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($DestinationPath)) {
    $DestinationPath = Join-Path $repoRoot 'apim-artifacts\apis\foundry-openai-v1\specification.yaml'
}

$sourcePath = 'specification/ai/data-plane/OpenAI.v1/azure-v1-v1-generated.json'
$sourceUrl = "https://raw.githubusercontent.com/Azure/azure-rest-api-specs/$SourceCommit/$sourcePath"
$source = Invoke-RestMethod -Uri $sourceUrl -Method Get
$httpMethods = @('get', 'post', 'put', 'patch', 'delete', 'head', 'options')

function Resolve-LocalReference {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Value,

        [Parameter(Mandatory = $true)]
        [object]$Document
    )

    $referenceProperty = $Value.PSObject.Properties['$ref']
    if (-not $referenceProperty) {
        return $Value
    }

    $reference = [string]$referenceProperty.Value
    if (-not $reference.StartsWith('#/')) {
        throw "External OpenAPI reference '$reference' is not supported."
    }

    $resolved = $Document
    foreach ($segment in $reference.Substring(2).Split('/')) {
        $decodedSegment = $segment.Replace('~1', '/').Replace('~0', '~')
        $property = $resolved.PSObject.Properties[$decodedSegment]
        if (-not $property) {
            throw "Unable to resolve OpenAPI reference '$reference'."
        }

        $resolved = $property.Value
    }

    return $resolved
}

function Convert-Parameter {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Parameter,

        [Parameter(Mandatory = $true)]
        [object]$Document
    )

    $resolved = Resolve-LocalReference -Value $Parameter -Document $Document
    if ($resolved.in -eq 'cookie') {
        return $null
    }

    $schemaType = [string]$resolved.schema.type
    if ($schemaType -notin @('array', 'boolean', 'integer', 'number', 'string')) {
        $schemaType = 'string'
    }

    $schema = [ordered]@{
        type = $schemaType
    }

    if ($schemaType -eq 'array') {
        $schema.items = [ordered]@{
            type = 'string'
        }
    }

    if ($resolved.schema.enum) {
        $schema.enum = @($resolved.schema.enum)
    }

    $converted = [ordered]@{
        name = [string]$resolved.name
        in = [string]$resolved.in
        required = [bool]$resolved.required
        schema = $schema
    }

    if (-not [string]::IsNullOrWhiteSpace([string]$resolved.description)) {
        $converted.description = [string]$resolved.description
    }

    return $converted
}

function New-GenericContent {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Content
    )

    $converted = [ordered]@{}
    foreach ($mediaTypeProperty in $Content.PSObject.Properties) {
        $schema = if ($mediaTypeProperty.Name -in @('application/octet-stream', 'audio/mpeg', 'audio/wav')) {
            [ordered]@{
                type = 'string'
                format = 'binary'
            }
        }
        else {
            [ordered]@{
                type = 'object'
                additionalProperties = $true
            }
        }

        $converted[$mediaTypeProperty.Name] = [ordered]@{
            schema = $schema
        }
    }

    return $converted
}

$convertedPaths = [ordered]@{}
$operationCount = 0

foreach ($pathProperty in $source.paths.PSObject.Properties) {
    $sourcePathItem = $pathProperty.Value
    $convertedPathItem = [ordered]@{}

    foreach ($methodProperty in $sourcePathItem.PSObject.Properties) {
        if ($methodProperty.Name -notin $httpMethods) {
            continue
        }

        $sourceOperation = $methodProperty.Value
        $operationId = [string]$sourceOperation.operationId
        if ([string]::IsNullOrWhiteSpace($operationId)) {
            throw "Operation '$($methodProperty.Name.ToUpperInvariant()) $($pathProperty.Name)' has no operationId."
        }

        $convertedOperation = [ordered]@{
            operationId = $operationId
            summary = if ([string]::IsNullOrWhiteSpace([string]$sourceOperation.summary)) {
                $operationId
            }
            else {
                [string]$sourceOperation.summary
            }
        }

        if ($sourceOperation.tags) {
            $convertedOperation.tags = @($sourceOperation.tags)
        }

        if (-not [string]::IsNullOrWhiteSpace([string]$sourceOperation.description)) {
            $convertedOperation.description = [string]$sourceOperation.description
        }

        $convertedParameters = [System.Collections.Generic.List[object]]::new()
        $parameterKeys = @{}
        $sourceParameters = @($sourcePathItem.parameters) + @($sourceOperation.parameters)
        foreach ($sourceParameter in $sourceParameters) {
            if (-not $sourceParameter) {
                continue
            }

            $convertedParameter = Convert-Parameter -Parameter $sourceParameter -Document $source
            if (-not $convertedParameter) {
                continue
            }

            $parameterKey = "$($convertedParameter.in):$($convertedParameter.name)".ToLowerInvariant()
            if (-not $parameterKeys.ContainsKey($parameterKey)) {
                $parameterKeys[$parameterKey] = $true
                $convertedParameters.Add($convertedParameter)
            }
        }

        foreach ($match in [regex]::Matches($pathProperty.Name, '\{([^}]+)\}')) {
            $parameterName = $match.Groups[1].Value
            $parameterKey = "path:$parameterName".ToLowerInvariant()
            if (-not $parameterKeys.ContainsKey($parameterKey)) {
                $parameterKeys[$parameterKey] = $true
                $convertedParameters.Add([ordered]@{
                    name = $parameterName
                    in = 'path'
                    required = $true
                    schema = [ordered]@{
                        type = 'string'
                    }
                })
            }
        }

        if ($convertedParameters.Count -gt 0) {
            $convertedOperation.parameters = $convertedParameters.ToArray()
        }

        if ($sourceOperation.requestBody) {
            $requestBody = Resolve-LocalReference -Value $sourceOperation.requestBody -Document $source
            $convertedRequestBody = [ordered]@{
                required = [bool]$requestBody.required
            }
            if (-not [string]::IsNullOrWhiteSpace([string]$requestBody.description)) {
                $convertedRequestBody.description = [string]$requestBody.description
            }
            if ($requestBody.content) {
                $convertedRequestBody.content = New-GenericContent -Content $requestBody.content
            }
            $convertedOperation.requestBody = $convertedRequestBody
        }

        $convertedResponses = [ordered]@{}
        foreach ($responseProperty in $sourceOperation.responses.PSObject.Properties) {
            $sourceResponse = Resolve-LocalReference -Value $responseProperty.Value -Document $source
            $convertedResponse = [ordered]@{
                description = if ([string]::IsNullOrWhiteSpace([string]$sourceResponse.description)) {
                    'Response'
                }
                else {
                    [string]$sourceResponse.description
                }
            }
            if ($sourceResponse.content) {
                $convertedResponse.content = New-GenericContent -Content $sourceResponse.content
            }
            $convertedResponses[$responseProperty.Name] = $convertedResponse
        }

        if ($convertedResponses.Count -eq 0) {
            $convertedResponses['default'] = [ordered]@{
                description = 'Response'
            }
        }

        $convertedOperation.responses = $convertedResponses
        $convertedPathItem[$methodProperty.Name] = $convertedOperation
        $operationCount++
    }

    if ($convertedPathItem.Count -gt 0) {
        $convertedPaths[$pathProperty.Name] = $convertedPathItem
    }
}

$convertedSpec = [ordered]@{
    openapi = '3.0.3'
    info = [ordered]@{
        title = 'Microsoft Foundry OpenAI v1'
        version = 'v1'
        description = "APIM-compatible operation catalog generated from the official Azure OpenAI v1 specification at commit $SourceCommit. Request and response schemas are intentionally permissive because API Management does not support the source specification's OpenAPI $($source.openapi) constructs."
    }
    servers = @(
        [ordered]@{
            url = '/openai/v1'
        }
    )
    paths = $convertedPaths
}

$destinationDirectory = Split-Path -Parent $DestinationPath
if (-not (Test-Path -LiteralPath $destinationDirectory)) {
    New-Item -ItemType Directory -Path $destinationDirectory -Force | Out-Null
}

$convertedSpec |
    ConvertTo-Json -Depth 100 |
    Set-Content -LiteralPath $DestinationPath -Encoding UTF8

Write-Host "Generated $operationCount operations from Azure OpenAI v1 commit $SourceCommit."
