[CmdletBinding()]
param()

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

function Write-Step {
    param([string] $Message)

    Write-Host ('[{0}] {1}' -f (Get-TaipeiTimestamp), $Message)
}

if (
    [string]::Equals($env:GITHUB_ACTIONS, 'true', [System.StringComparison]::OrdinalIgnoreCase) -and
    [string]::Equals($env:MCP_SKIP_POSTDEPLOY_VALIDATION, 'true', [System.StringComparison]::OrdinalIgnoreCase)
) {
    Write-Step 'Skipping postdeploy MCP validation for the approved GitHub Actions CI fallback path.'
    return
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

function Get-McpAccessToken {
    param(
        [Parameter(Mandatory = $true)]
        [string] $ResourceClientId
    )

    if ($env:MCP_VALIDATION_CLIENT_ID -and $env:MCP_VALIDATION_CLIENT_SECRET) {
        $tenantId = if ($env:MCP_VALIDATION_TENANT_ID) { $env:MCP_VALIDATION_TENANT_ID } else { $env:MCP_OAUTH_TENANT_ID }
        if (-not $tenantId) {
            throw 'MCP_VALIDATION_TENANT_ID or MCP_OAUTH_TENANT_ID is required when using MCP_VALIDATION_CLIENT_ID.'
        }

        Write-Step ('Using dedicated validation app {0}' -f $env:MCP_VALIDATION_CLIENT_ID)
        $tokenResponse = Invoke-RestMethod `
            -Method Post `
            -Uri ("https://login.microsoftonline.com/{0}/oauth2/v2.0/token" -f $tenantId) `
            -ContentType 'application/x-www-form-urlencoded' `
            -Body @{
                client_id     = $env:MCP_VALIDATION_CLIENT_ID
                client_secret = $env:MCP_VALIDATION_CLIENT_SECRET
                grant_type    = 'client_credentials'
                scope         = ('api://{0}/.default' -f $ResourceClientId)
            }

        return $tokenResponse.access_token
    }

    Write-Step 'Using current Azure CLI identity for postdeploy validation'
    return az account get-access-token --scope ("api://{0}/user_impersonation" -f $ResourceClientId) --query accessToken -o tsv
}

function Invoke-McpRequest {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Url,

        [Parameter(Mandatory = $true)]
        [string] $Token,

        [Parameter(Mandatory = $true)]
        [hashtable] $Payload,

        [string] $SessionId
    )

    $headers = @{
        Authorization = "Bearer $Token"
        Accept        = 'application/json, text/event-stream'
        'MCP-Protocol-Version' = '2025-03-26'
    }

    if ($SessionId) {
        $headers['Mcp-Session-Id'] = $SessionId
    }

    return Invoke-WebRequest `
        -Uri $Url `
        -Method Post `
        -Headers $headers `
        -ContentType 'application/json' `
        -Body ($Payload | ConvertTo-Json -Depth 20)
}

function Get-McpPayload {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Content
    )

    $trimmed = $Content.Trim()
    if ($trimmed.StartsWith('{') -or $trimmed.StartsWith('[')) {
        return $trimmed | ConvertFrom-Json -Depth 20
    }

    $dataLine = $Content -split "`r?`n" | Where-Object { $_ -like 'data:*' } | Select-Object -Last 1
    if (-not $dataLine) {
        throw 'The MCP endpoint did not return either JSON or an SSE data payload.'
    }

    $json = $dataLine.Substring(5).Trim()
    return $json | ConvertFrom-Json -Depth 20
}

Import-AzdEnvironment

$appHostName = $env:AZURE_RESOURCE_MCP_OUTLOOK_EMAIL_FQDN
$resourceClientId = $env:MCP_OAUTH_CLIENT_ID

if (-not $appHostName) {
    throw 'AZURE_RESOURCE_MCP_OUTLOOK_EMAIL_FQDN is not set in the azd environment.'
}

if (-not $resourceClientId) {
    throw 'MCP_OAUTH_CLIENT_ID is not set in the azd environment.'
}

$endpoint = "https://$appHostName/mcp"
Write-Step ('Starting postdeploy MCP validation for {0}' -f $endpoint)

$token = Get-McpAccessToken -ResourceClientId $resourceClientId
if (-not $token) {
    throw 'Failed to acquire an access token for MCP validation.'
}

Write-Step 'Calling /mcp initialize on the deployed Container App'
$initializeResponse = Invoke-McpRequest `
    -Url $endpoint `
    -Token $token `
    -Payload @{
        jsonrpc = '2.0'
        id      = 1
        method  = 'initialize'
        params  = @{
            protocolVersion = '2025-03-26'
            capabilities    = @{}
            clientInfo      = @{
                name    = 'azd-postdeploy-validation'
                version = '1.0'
            }
        }
    }

$initializePayload = Get-McpPayload -Content $initializeResponse.Content
$sessionId = if ($initializeResponse.Headers['Mcp-Session-Id']) { $initializeResponse.Headers['Mcp-Session-Id'] } else { $initializeResponse.Headers['mcp-session-id'] }

if (-not $initializePayload.result.protocolVersion) {
    throw 'Initialize response did not include protocolVersion.'
}

Write-Step 'Calling /mcp tools/list'
$toolsResponse = Invoke-McpRequest `
    -Url $endpoint `
    -Token $token `
    -SessionId $sessionId `
    -Payload @{
        jsonrpc = '2.0'
        id      = 2
        method  = 'tools/list'
        params  = @{}
    }

$toolsPayload = Get-McpPayload -Content $toolsResponse.Content
$toolNames = @($toolsPayload.result.tools | ForEach-Object { $_.name })

foreach ($requiredTool in @('send_email', 'generate_pptx_attachment', 'generate_xlsx_attachment')) {
    if (-not ($toolNames -contains $requiredTool)) {
        throw ('The {0} tool was not returned by tools/list. Returned tools: {1}' -f $requiredTool, ($toolNames -join ', '))
    }
}

Write-Step ('Postdeploy MCP validation succeeded. Tools returned: {0}' -f ($toolNames -join ', '))
