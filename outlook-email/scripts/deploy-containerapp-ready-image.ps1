[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $ImageRef,

    [int] $ReadyTimeoutSeconds = 600,

    [int] $PollIntervalSeconds = 10
)

$ErrorActionPreference = 'Stop'

function Get-TaipeiTimestamp {
    foreach ($timeZoneId in @('Taipei Standard Time', 'Asia/Taipei')) {
        try {
            $timeZone = [TimeZoneInfo]::FindSystemTimeZoneById($timeZoneId)
            return [TimeZoneInfo]::ConvertTime([DateTimeOffset]::UtcNow, $timeZone).ToString('yyyy-MM-dd HH:mm:ss zzz')
        }
        catch {
        }
    }

    return [DateTimeOffset]::UtcNow.ToOffset([TimeSpan]::FromHours(8)).ToString('yyyy-MM-dd HH:mm:ss zzz')
}

function Get-TaipeiRevisionSuffix {
    foreach ($timeZoneId in @('Taipei Standard Time', 'Asia/Taipei')) {
        try {
            $timeZone = [TimeZoneInfo]::FindSystemTimeZoneById($timeZoneId)
            return 'tpe-' + [TimeZoneInfo]::ConvertTime([DateTimeOffset]::UtcNow, $timeZone).ToString('MMddHHmmss')
        }
        catch {
        }
    }

    return 'tpe-' + [DateTimeOffset]::UtcNow.ToOffset([TimeSpan]::FromHours(8)).ToString('MMddHHmmss')
}

function Write-Step {
    param([string] $Message)

    Write-Host ('[{0}] {1}' -f (Get-TaipeiTimestamp), $Message)
}

function Import-AzdEnvironment {
    $envLines = azd env get-values
    foreach ($line in $envLines) {
        if ([string]::IsNullOrWhiteSpace($line)) {
            continue
        }

        $separatorIndex = $line.IndexOf('=')
        if ($separatorIndex -lt 1) {
            continue
        }

        $key = $line.Substring(0, $separatorIndex)
        $value = $line.Substring($separatorIndex + 1).Trim()
        if ($value.StartsWith('"') -and $value.EndsWith('"')) {
            $value = $value.Substring(1, $value.Length - 2)
        }

        Set-Item -Path ("Env:{0}" -f $key) -Value $value
    }
}

function Clone-Object {
    param([Parameter(Mandatory = $true)] $InputObject)

    return ($InputObject | ConvertTo-Json -Depth 100 | ConvertFrom-Json -Depth 100)
}

function Get-AzJson {
    param(
        [Parameter(Mandatory = $true)]
        [scriptblock] $Command,

        [Parameter(Mandatory = $true)]
        [string] $Description
    )

    $output = & $Command 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw ("Azure CLI failed while trying to {0}: {1}" -f $Description, (($output | Out-String).Trim()))
    }

    return $output | ConvertFrom-Json -Depth 100
}

function Invoke-AzCommand {
    param(
        [Parameter(Mandatory = $true)]
        [scriptblock] $Command,

        [Parameter(Mandatory = $true)]
        [string] $Description
    )

    $output = & $Command 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw ("Azure CLI failed while trying to {0}: {1}" -f $Description, (($output | Out-String).Trim()))
    }
}

function Get-ContainerAppUserAssignedIdentityResourceId {
    param([Parameter(Mandatory = $true)] $ContainerApp)

    $identityMap = $ContainerApp.identity.userAssignedIdentities
    if (-not $identityMap) {
        return $null
    }

    $identityNames = @($identityMap.PSObject.Properties.Name)
    if ($identityNames.Count -gt 0) {
        return $identityNames[0]
    }

    return $null
}

function Convert-KeyVaultReferenceToUrl {
    param([string] $Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $null
    }

    if (-not $Value.StartsWith('@Microsoft.KeyVault(') -or -not $Value.Contains('SecretUri=')) {
        return $null
    }

    return $Value.Replace('@Microsoft.KeyVault(SecretUri=', '').TrimEnd(')')
}

function Get-ContainerAppSecretSpec {
    param(
        [Parameter(Mandatory = $true)]
        [string] $SecretName,

        [string] $ConfiguredValue,

        [string] $UserAssignedIdentityResourceId
    )

    if ([string]::IsNullOrWhiteSpace($ConfiguredValue)) {
        return $null
    }

    $keyVaultUrl = Convert-KeyVaultReferenceToUrl -Value $ConfiguredValue
    if ($keyVaultUrl) {
        if ([string]::IsNullOrWhiteSpace($UserAssignedIdentityResourceId)) {
            throw "Cannot configure Container App secret '$SecretName' as a Key Vault reference because the Container App has no user-assigned identity."
        }

        return '{0}=keyvaultref:{1},identityref:{2}' -f $SecretName, $keyVaultUrl, $UserAssignedIdentityResourceId
    }

    return '{0}={1}' -f $SecretName, $ConfiguredValue
}

function Sync-ContainerAppSecrets {
    param(
        [Parameter(Mandatory = $true)]
        [string] $ResourceGroupName,

        [Parameter(Mandatory = $true)]
        [string] $ContainerAppName,

        [string] $UserAssignedIdentityResourceId
    )

    $secretSpecs = @()

    $graphSecretSpec = Get-ContainerAppSecretSpec `
        -SecretName 'graph-client-secret' `
        -ConfiguredValue $env:MCP_ENTRA_CLIENT_SECRET `
        -UserAssignedIdentityResourceId $UserAssignedIdentityResourceId
    if ($graphSecretSpec) {
        $secretSpecs += $graphSecretSpec
    }

    $mcpOauthSecretSpec = Get-ContainerAppSecretSpec `
        -SecretName 'mcp-oauth-client-secret' `
        -ConfiguredValue $env:MCP_OAUTH_CLIENT_SECRET `
        -UserAssignedIdentityResourceId $UserAssignedIdentityResourceId
    if ($mcpOauthSecretSpec) {
        $secretSpecs += $mcpOauthSecretSpec
    }

    if ($secretSpecs.Count -eq 0) {
        return
    }

    Write-Step 'Syncing Container App secret contract before the image rollout'
    $secretSetArgs = @(
        'containerapp', 'secret', 'set',
        '--resource-group', $ResourceGroupName,
        '--name', $ContainerAppName,
        '--only-show-errors',
        '--output', 'none',
        '--secrets'
    ) + $secretSpecs

    Invoke-AzCommand -Description 'sync the Container App secrets used by Graph auth and MCP OAuth' -Command { & az @secretSetArgs }
}

function Should-OverlayCurrentEnv {
    param([string] $Name)

    return $Name -eq 'APPLICATIONINSIGHTS_CONNECTION_STRING' `
        -or $Name -eq 'FUNCTIONS_CUSTOMHANDLER_PORT' `
        -or $Name -eq 'UseHttp' `
        -or $Name -eq 'AZURE_CLIENT_ID' `
        -or $Name -like 'EntraId__*' `
        -or $Name -like 'AllowedSenders__*' `
        -or $Name -like 'AllowedReplyTo__*'
}

Import-AzdEnvironment

$subscriptionId = $env:AZURE_SUBSCRIPTION_ID
$resourceGroupName = $env:AZURE_RESOURCE_GROUP_NAME
$containerAppName = $env:AZURE_RESOURCE_MCP_OUTLOOK_EMAIL_NAME

if (-not $subscriptionId) {
    throw 'AZURE_SUBSCRIPTION_ID is not set in the azd environment.'
}

if (-not $resourceGroupName) {
    throw 'AZURE_RESOURCE_GROUP_NAME is not set in the azd environment.'
}

if (-not $containerAppName) {
    throw 'AZURE_RESOURCE_MCP_OUTLOOK_EMAIL_NAME is not set in the azd environment.'
}

$containerAppResourceId = "/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.App/containerApps/$containerAppName"

Write-Step ("Reading current Container App state for {0}" -f $containerAppName)
$currentApp = Get-AzJson -Description 'read the current Container App state' -Command { az resource show --ids $containerAppResourceId --api-version 2024-03-01 }
$userAssignedIdentityResourceId = Get-ContainerAppUserAssignedIdentityResourceId -ContainerApp $currentApp
Sync-ContainerAppSecrets -ResourceGroupName $resourceGroupName -ContainerAppName $containerAppName -UserAssignedIdentityResourceId $userAssignedIdentityResourceId
$currentApp = Get-AzJson -Description 're-read the current Container App state after syncing secrets' -Command { az resource show --ids $containerAppResourceId --api-version 2024-03-01 }
$latestReadyRevisionName = $currentApp.properties.latestReadyRevisionName

if (-not $latestReadyRevisionName) {
    throw 'The Container App does not have a latestReadyRevisionName to clone.'
}

$readyRevisionResourceId = "$containerAppResourceId/revisions/$latestReadyRevisionName"
$readyRevision = Get-AzJson -Description 'read the latest ready revision' -Command { az resource show --ids $readyRevisionResourceId --api-version 2024-03-01 }

$currentTemplate = Clone-Object -InputObject $currentApp.properties.template
$readyTemplate = Clone-Object -InputObject $readyRevision.properties.template
$currentContainer = $currentTemplate.containers[0]
$readyContainer = $readyTemplate.containers[0]

$currentEnvByName = @{}
foreach ($entry in @($currentContainer.env)) {
    $currentEnvByName[$entry.name] = Clone-Object -InputObject $entry
}

$mergedEnvByName = @{}
$orderedNames = New-Object System.Collections.Generic.List[string]
foreach ($entry in @($readyContainer.env)) {
    $mergedEnvByName[$entry.name] = Clone-Object -InputObject $entry
    $orderedNames.Add($entry.name) | Out-Null
}

foreach ($name in $currentEnvByName.Keys) {
    if (-not (Should-OverlayCurrentEnv -Name $name)) {
        continue
    }

    $mergedEnvByName[$name] = Clone-Object -InputObject $currentEnvByName[$name]
    if (-not $orderedNames.Contains($name)) {
        $orderedNames.Add($name) | Out-Null
    }
}

if (-not $mergedEnvByName.ContainsKey('FUNCTIONS_CUSTOMHANDLER_PORT')) {
    $mergedEnvByName['FUNCTIONS_CUSTOMHANDLER_PORT'] = [pscustomobject]@{
        name  = 'FUNCTIONS_CUSTOMHANDLER_PORT'
        value = '8080'
    }
    if (-not $orderedNames.Contains('FUNCTIONS_CUSTOMHANDLER_PORT')) {
        $orderedNames.Add('FUNCTIONS_CUSTOMHANDLER_PORT') | Out-Null
    }
}

$mergedEnv = @()
foreach ($name in $orderedNames) {
    $entry = $mergedEnvByName[$name]
    if ($entry.PSObject.Properties.Name -contains 'secretRef' -and $entry.secretRef -eq 'entra-client-secret') {
        $entry.secretRef = 'graph-client-secret'
    }

    $mergedEnv += $entry
}

$readyContainer.image = $ImageRef
$readyContainer.env = $mergedEnv
$readyContainer.resources = Clone-Object -InputObject $currentContainer.resources
$readyContainer.args = Clone-Object -InputObject $currentContainer.args
$readyTemplate.scale = Clone-Object -InputObject $currentTemplate.scale
$readyTemplate.revisionSuffix = Get-TaipeiRevisionSuffix

$previousLatestRevisionName = $currentApp.properties.latestRevisionName
$updateArgs = @(
    'containerapp', 'update',
    '--resource-group', $resourceGroupName,
    '--name', $containerAppName,
    '--image', $ImageRef,
    '--container-name', $readyContainer.name,
    '--revision-suffix', $readyTemplate.revisionSuffix,
    '--cpu', [string]$readyContainer.resources.cpu,
    '--memory', [string]$readyContainer.resources.memory,
    '--min-replicas', [string]$readyTemplate.scale.minReplicas,
    '--max-replicas', [string]$readyTemplate.scale.maxReplicas,
    '--replace-env-vars'
)

foreach ($entry in $mergedEnv) {
    if ($entry.PSObject.Properties.Name -contains 'secretRef') {
        $updateArgs += ('{0}=secretref:{1}' -f $entry.name, $entry.secretRef)
    }
    else {
        $updateArgs += ('{0}={1}' -f $entry.name, $entry.value)
    }
}

Write-Step ("Deploying image {0} from latest ready revision {1}" -f $ImageRef, $latestReadyRevisionName)
Invoke-AzCommand -Description 'update the Container App image and template settings' -Command { & az @updateArgs }

$deadline = (Get-Date).AddSeconds($ReadyTimeoutSeconds)
$newLatestRevisionName = $null
do {
    Start-Sleep -Seconds $PollIntervalSeconds
    $currentApp = Get-AzJson -Description 'poll the updated Container App state' -Command { az resource show --ids $containerAppResourceId --api-version 2024-03-01 }

    if ($currentApp.properties.latestRevisionName -ne $previousLatestRevisionName) {
        $newLatestRevisionName = $currentApp.properties.latestRevisionName
    }

    Write-Step ("latestRevision={0} latestReadyRevision={1}" -f $currentApp.properties.latestRevisionName, $currentApp.properties.latestReadyRevisionName)

    if ($newLatestRevisionName -and $currentApp.properties.latestReadyRevisionName -eq $newLatestRevisionName) {
        Write-Step ("Container App revision {0} is ready." -f $newLatestRevisionName)
        return
    }
}
while ((Get-Date) -lt $deadline)

if (-not $newLatestRevisionName) {
    throw 'The Container App did not create a new revision after the template patch.'
}

$newRevisionResourceId = "$containerAppResourceId/revisions/$newLatestRevisionName"
$newRevision = Get-AzJson -Description 'read the failed revision state' -Command { az resource show --ids $newRevisionResourceId --api-version 2024-03-01 }
throw ("Container App revision {0} did not become ready. runningState={1}; healthState={2}" -f $newLatestRevisionName, $newRevision.properties.runningState, $newRevision.properties.healthState)
