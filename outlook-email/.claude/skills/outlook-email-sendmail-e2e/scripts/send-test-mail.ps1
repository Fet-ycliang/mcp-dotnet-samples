[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string[]] $Recipients,

    [Parameter()]
    [string] $Title = 'Outlook Email Graph 測試信',

    [Parameter()]
    [string] $Body = '這封信直接透過 Microsoft Graph 送出。',

    [Parameter()]
    [string] $Sender,

    [Parameter()]
    [string[]] $ReplyTo,

    [Parameter()]
    [string] $ConfigPath,

    [Parameter()]
    [switch] $AllowAnyRecipient
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($ConfigPath))
{
    $ConfigPath = Join-Path $PSScriptRoot '..\..\..\src\McpSamples.OutlookEmail.HybridApp\local.settings.json'
}

$resolvedConfigPath = (Resolve-Path $ConfigPath).Path
$settings = (Get-Content $resolvedConfigPath -Raw | ConvertFrom-Json).Values

function Get-SettingValue
{
    param(
        [Parameter(Mandatory)]
        [psobject] $Source,

        [Parameter(Mandatory)]
        [string] $Name
    )

    return ($Source.PSObject.Properties | Where-Object Name -eq $Name | Select-Object -First 1 -ExpandProperty Value)
}

function Get-SettingValuesByPrefix
{
    param(
        [Parameter(Mandatory)]
        [psobject] $Source,

        [Parameter(Mandatory)]
        [string] $Prefix
    )

    return @(
        $Source.PSObject.Properties |
            Where-Object { $_.Name -like "$Prefix*" -and -not [string]::IsNullOrWhiteSpace([string]$_.Value) } |
            Sort-Object Name |
            ForEach-Object { ([string]$_.Value).Trim() }
    )
}

function Get-RequiredSettingValue
{
    param(
        [Parameter(Mandatory)]
        [psobject] $Source,

        [Parameter(Mandatory)]
        [string] $Name
    )

    $value = Get-SettingValue -Source $Source -Name $Name
    if ([string]::IsNullOrWhiteSpace([string]$value))
    {
        throw "Required setting '$Name' was not found in '$resolvedConfigPath'."
    }

    return [string]$value
}

function Get-SettingValueWithEnvironmentOverride
{
    param(
        [Parameter(Mandatory)]
        [psobject] $Source,

        [Parameter(Mandatory)]
        [string] $Name
    )

    $value = [Environment]::GetEnvironmentVariable($Name)
    if (-not [string]::IsNullOrWhiteSpace($value))
    {
        return $value
    }

    return Get-SettingValue -Source $Source -Name $Name
}

function Get-RequiredSettingValueWithEnvironmentOverride
{
    param(
        [Parameter(Mandatory)]
        [psobject] $Source,

        [Parameter(Mandatory)]
        [string] $Name
    )

    $value = Get-SettingValueWithEnvironmentOverride -Source $Source -Name $Name
    if ([string]::IsNullOrWhiteSpace([string]$value))
    {
        throw "Required setting '$Name' was not found in environment variables or '$resolvedConfigPath'."
    }

    return [string]$value
}

function Assert-AllowedValues
{
    param(
        [AllowEmptyCollection()]
        [string[]] $AllowedValues = @(),

        [AllowEmptyCollection()]
        [string[]] $ActualValues = @(),

        [Parameter(Mandatory)]
        [string] $ParameterName
    )

    if ($AllowedValues.Count -eq 0 -or $ActualValues.Count -eq 0)
    {
        return
    }

    $normalizedAllowlist = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($value in $AllowedValues)
    {
        if (-not [string]::IsNullOrWhiteSpace($value))
        {
            [void]$normalizedAllowlist.Add($value.Trim())
        }
    }

    $invalidValues = @(
        $ActualValues |
            Where-Object {
                $candidate = $_.Trim()
                -not $normalizedAllowlist.Contains($candidate)
            } |
            ForEach-Object { $_.Trim() }
    )

    if ($invalidValues.Count -gt 0)
    {
        $allowlistText = [string]::Join(', ', $normalizedAllowlist)
        throw "$ParameterName contains values outside the allowlist: $($invalidValues -join ', '). Allowed values: $allowlistText."
    }
}

$tenantId = Get-RequiredSettingValueWithEnvironmentOverride -Source $settings -Name 'EntraId__TenantId'
$clientId = Get-RequiredSettingValueWithEnvironmentOverride -Source $settings -Name 'EntraId__ClientId'
$clientSecret = Get-RequiredSettingValueWithEnvironmentOverride -Source $settings -Name 'EntraId__ClientSecret'

$allowedSenders = Get-SettingValuesByPrefix -Source $settings -Prefix 'AllowedSenders__'
$allowedReplyTo = Get-SettingValuesByPrefix -Source $settings -Prefix 'AllowedReplyTo__'
$allowedRecipients = Get-SettingValuesByPrefix -Source $settings -Prefix 'AllowedRecipients__'

if ([string]::IsNullOrWhiteSpace($Sender))
{
    $Sender = Get-RequiredSettingValue -Source $settings -Name 'AllowedSenders__0'
}

$Sender = $Sender.Trim()
$Recipients = @(
    $Recipients |
        Where-Object { $null -ne $_ } |
        ForEach-Object { $_.Trim() } |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
)
$ReplyTo = @(
    $ReplyTo |
        Where-Object { $null -ne $_ } |
        ForEach-Object { $_.Trim() } |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
)

if ($Recipients.Count -eq 0)
{
    throw 'At least one recipient is required.'
}

if ($allowedSenders.Count -eq 0)
{
    throw "At least one AllowedSenders__N entry must be configured in '$resolvedConfigPath'."
}

if ($ReplyTo.Count -gt 0 -and $allowedReplyTo.Count -eq 0)
{
    throw "ReplyTo requires AllowedReplyTo__N to be configured in '$resolvedConfigPath'."
}

Assert-AllowedValues -AllowedValues $allowedSenders -ActualValues @($Sender) -ParameterName 'Sender'
Assert-AllowedValues -AllowedValues $allowedReplyTo -ActualValues $ReplyTo -ParameterName 'ReplyTo'

if (-not $AllowAnyRecipient)
{
    $recipientAllowlist = @(
        (@($allowedRecipients) + @($allowedSenders) + @($allowedReplyTo)) |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            Select-Object -Unique
    )

    Assert-AllowedValues -AllowedValues $recipientAllowlist -ActualValues $Recipients -ParameterName 'Recipients'
}

$message = @{
    subject = $Title
    body = @{
        contentType = 'Text'
        content = $Body
    }
    toRecipients = @(
        $Recipients | ForEach-Object {
            @{
                emailAddress = @{
                    address = $_
                }
            }
        }
    )
}

if ($ReplyTo.Count -gt 0)
{
    $message.replyTo = @(
        $ReplyTo | ForEach-Object {
            @{
                emailAddress = @{
                    address = $_
                }
            }
        }
    )
}

$payload = @{
    message = $message
    saveToSentItems = $true
}

$result = [pscustomobject]@{
    Status = 'Prepared'
    Sender = $Sender
    Recipients = ($Recipients -join ';')
    ReplyTo = ($ReplyTo -join ';')
    Title = $Title
    ConfigPath = $resolvedConfigPath
}

if (-not $PSCmdlet.ShouldProcess($result.Recipients, "Send '$Title' from $Sender"))
{
    $result.Status = 'WhatIf'
    return $result
}

$tokenResponse = Invoke-RestMethod -Method Post -Uri "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token" -Body @{
    client_id = $clientId
    client_secret = $clientSecret
    scope = 'https://graph.microsoft.com/.default'
    grant_type = 'client_credentials'
}

$encodedSender = [Uri]::EscapeDataString($Sender)

Invoke-RestMethod -Method Post -Uri "https://graph.microsoft.com/v1.0/users/$encodedSender/sendMail" -Headers @{
    Authorization = "Bearer $($tokenResponse.access_token)"
} -ContentType 'application/json' -Body ($payload | ConvertTo-Json -Depth 10) | Out-Null

$result.Status = 'Sent'
return $result
