/**
 * @description Deploy MCP API (Named Values + OAuth facade + validate-jwt policy) onto an existing APIM service.
 * Calls modules/mcp-api.bicep with a Container App backend URL.
 * Use this for standalone MCP API deployments that do not redeploy the APIM service itself.
 *
 * Usage:
 *   az deployment group create \
 *     --resource-group <rg> \
 *     --template-file infra/deploy-mcp-api.bicep \
 *     --parameters infra/deploy-mcp-api.<project>.parameters.json \
 *     [--what-if]
 */

// ------------------
//    PARAMETERS
// ------------------

@description('Name of the existing APIM service to deploy the MCP API onto.')
param apimServiceName string

@description('Name of the existing user-assigned managed identity APIM uses for backend token acquisition (e.g. id-fet-outlook-email-bst-apim).')
param managedIdentityName string

@description('HTTPS base URL of the Container App backend, e.g. https://<fqdn>/. APIM forwards /outlook-email/mcp to this URL.')
param backendUrl string

@description('The client/application ID of the APIM resource app (apim-mcp).')
param mcpAppId string

@description('The Application ID URI of the APIM resource app, e.g. api://apim-mcp. Defaults to api://<mcpAppId> when omitted.')
param mcpAppIdUri string = ''

@description('The tenant ID hosting the Entra ID apps.')
param mcpAppTenantId string

@description('The client/application ID of the direct MCP resource app that protects the backend Container App path.')
param backendMcpAppId string

@description('The Application ID URI of the direct MCP resource app. Defaults to api://<backendMcpAppId> when omitted.')
param backendMcpAppIdUri string = ''

@minLength(1)
@description('The client/application ID of the Claude public client app used by the OAuth register stub.')
param mcpClaudeClientId string

@description('Optional. Semicolon-separated Entra client IDs allowed to call the APIM retained MCP path in addition to mcpClaudeClientId.')
param apimAllowedClientApplicationsCsv string = ''

@description('Semicolon-separated redirect URIs allowed for the Claude public client on the APIM OAuth facade.')
param mcpClaudeRedirectUrisCsv string = 'http://localhost'

// ------------------
//    RESOURCES
// ------------------

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: managedIdentityName
}

module mcpApi './modules/mcp-api.bicep' = {
  name: 'mcp-api-${take(uniqueString(apimServiceName, resourceGroup().id), 8)}'
  params: {
    apimServiceName: apimServiceName
    backendUrl: backendUrl
    mcpAppId: mcpAppId
    mcpAppIdUri: mcpAppIdUri
    mcpAppTenantId: mcpAppTenantId
    backendMcpAppId: backendMcpAppId
    backendMcpAppIdUri: backendMcpAppIdUri
    mcpClaudeClientId: mcpClaudeClientId
    apimAllowedClientApplicationsCsv: apimAllowedClientApplicationsCsv
    mcpClaudeRedirectUrisCsv: mcpClaudeRedirectUrisCsv
    backendManagedIdentityClientId: managedIdentity.properties.clientId
  }
}

// ------------------
//    OUTPUTS
// ------------------

output apiId string = mcpApi.outputs.apiId
output oauthApiId string = mcpApi.outputs.oauthApiId
output mcpOAuthBaseUrl string = mcpApi.outputs.mcpOAuthBaseUrl
output backendUrl string = mcpApi.outputs.backendUrl
