@description('The name of the API Management service')
param apimServiceName string

@description('The name of the App Service hosting the MCP endpoints')
param functionAppName string

@description('Optional explicit backend base URL for the MCP API facade. When provided, APIM forwards to this URL instead of the Function App hostname.')
param backendUrl string = ''

@description('The client/application ID of the MCP resource app')
param mcpAppId string

@description('The Application ID URI of the MCP resource app, for example api://apim-mcp. Defaults to api://<mcpAppId> when omitted.')
param mcpAppIdUri string = ''

@description('The tenant ID of the MCP resource app')
param mcpAppTenantId string

@description('The client/application ID of the direct MCP resource app that protects the backend Function App / ACA path.')
param backendMcpAppId string

@description('The Application ID URI of the direct MCP resource app. Defaults to api://<backendMcpAppId> when omitted.')
param backendMcpAppIdUri string = ''

@minLength(1)
@description('The client/application ID of the Claude caller public client app returned by the OAuth register stub. Required when the APIM OAuth facade is deployed.')
param mcpClaudeClientId string

@description('Optional. Semicolon-separated Entra client/application IDs allowed to call the APIM retained MCP path. MCP_CLAUDE_CLIENT_ID is always included automatically.')
param apimAllowedClientApplicationsCsv string = ''

@description('Optional. Semicolon-separated exact redirect URIs allowed for the Claude public client on the APIM OAuth facade. Defaults to http://localhost.')
param mcpClaudeRedirectUrisCsv string = 'http://localhost'

@description('The client/application ID of the managed identity APIM should use when calling the backend.')
param backendManagedIdentityClientId string

resource apimService 'Microsoft.ApiManagement/service@2023-05-01-preview' existing = {
  name: apimServiceName
}

resource functionApp 'Microsoft.Web/sites@2023-12-01' existing = {
  name: functionAppName
}

var effectiveMcpAppIdUri = !empty(mcpAppIdUri) ? mcpAppIdUri : 'api://${mcpAppId}'
var effectiveBackendMcpAppIdUri = !empty(backendMcpAppIdUri) ? backendMcpAppIdUri : 'api://${backendMcpAppId}'
var mcpScope = '${effectiveMcpAppIdUri}/mcp.access'
var gatewayBaseUrl = apimService.properties.gatewayUrl
var mcpOauthBaseUrl = '${gatewayBaseUrl}/mcp-oauth'
var additionalApimAllowedClientApplications = empty(apimAllowedClientApplicationsCsv) ? [] : filter(map(split(apimAllowedClientApplicationsCsv, ';'), appId => trim(appId)), appId => !empty(appId))
var effectiveApimAllowedClientApplicationsCsv = join(concat([
  mcpClaudeClientId
], additionalApimAllowedClientApplications), ';')
var effectiveMcpClaudeRedirectUrisCsv = join(filter(map(split(mcpClaudeRedirectUrisCsv, ';'), redirectUri => trim(redirectUri)), redirectUri => !empty(redirectUri)), ';')

resource mcpTenantIdNamedValue 'Microsoft.ApiManagement/service/namedValues@2021-08-01' = {
  parent: apimService
  name: 'McpTenantId'
  properties: {
    displayName: 'McpTenantId'
    value: mcpAppTenantId
    secret: false
  }
}

resource mcpClientIdNamedValue 'Microsoft.ApiManagement/service/namedValues@2021-08-01' = {
  parent: apimService
  name: 'McpClientId'
  properties: {
    displayName: 'McpClientId'
    value: mcpAppId
    secret: false
  }
}

resource mcpAppIdUriNamedValue 'Microsoft.ApiManagement/service/namedValues@2021-08-01' = {
  parent: apimService
  name: 'McpAppIdUri'
  properties: {
    displayName: 'McpAppIdUri'
    value: effectiveMcpAppIdUri
    secret: false
  }
}

resource mcpScopeNamedValue 'Microsoft.ApiManagement/service/namedValues@2021-08-01' = {
  parent: apimService
  name: 'McpScope'
  properties: {
    displayName: 'McpScope'
    value: mcpScope
    secret: false
  }
}

resource mcpClaudeClientIdNamedValue 'Microsoft.ApiManagement/service/namedValues@2021-08-01' = {
  parent: apimService
  name: 'McpClaudeClientId'
  properties: {
    displayName: 'McpClaudeClientId'
    value: mcpClaudeClientId
    secret: false
  }
}

resource mcpAllowedCallerAppIdsCsvNamedValue 'Microsoft.ApiManagement/service/namedValues@2021-08-01' = {
  parent: apimService
  name: 'McpAllowedCallerAppIdsCsv'
  properties: {
    displayName: 'McpAllowedCallerAppIdsCsv'
    value: effectiveApimAllowedClientApplicationsCsv
    secret: false
  }
}

resource mcpClaudeRedirectUrisCsvNamedValue 'Microsoft.ApiManagement/service/namedValues@2021-08-01' = {
  parent: apimService
  name: 'McpClaudeRedirectUrisCsv'
  properties: {
    displayName: 'McpClaudeRedirectUrisCsv'
    value: effectiveMcpClaudeRedirectUrisCsv
    secret: false
  }
}

resource backendMcpClientIdNamedValue 'Microsoft.ApiManagement/service/namedValues@2021-08-01' = {
  parent: apimService
  name: 'BackendMcpClientId'
  properties: {
    displayName: 'BackendMcpClientId'
    value: backendMcpAppId
    secret: false
  }
}

resource backendMcpAppIdUriNamedValue 'Microsoft.ApiManagement/service/namedValues@2021-08-01' = {
  parent: apimService
  name: 'BackendMcpAppIdUri'
  properties: {
    displayName: 'BackendMcpAppIdUri'
    value: effectiveBackendMcpAppIdUri
    secret: false
  }
}

resource apimBackendClientIdNamedValue 'Microsoft.ApiManagement/service/namedValues@2021-08-01' = {
  parent: apimService
  name: 'ApimBackendClientId'
  properties: {
    displayName: 'ApimBackendClientId'
    value: backendManagedIdentityClientId
    secret: false
  }
}

resource APIMGatewayURLNamedValue 'Microsoft.ApiManagement/service/namedValues@2021-08-01' = {
  parent: apimService
  name: 'APIMGatewayURL'
  properties: {
    displayName: 'APIMGatewayURL'
    value: gatewayBaseUrl
    secret: false
  }
}

resource mcpOauthBaseUrlNamedValue 'Microsoft.ApiManagement/service/namedValues@2021-08-01' = {
  parent: apimService
  name: 'McpOAuthBaseUrl'
  properties: {
    displayName: 'McpOAuthBaseUrl'
    value: mcpOauthBaseUrl
    secret: false
  }
}

resource mcpApi 'Microsoft.ApiManagement/service/apis@2023-05-01-preview' = {
  parent: apimService
  name: 'mcp'
  properties: {
    displayName: 'MCP API'
    description: 'Model Context Protocol API endpoints'
    subscriptionRequired: false
    path: '/'
    protocols: [
      'https'
    ]
    serviceUrl: empty(backendUrl) ? 'https://${functionApp.properties.defaultHostName}/' : backendUrl
  }
}

resource mcpApiPolicy 'Microsoft.ApiManagement/service/apis/policies@2023-05-01-preview' = {
  parent: mcpApi
  name: 'policy'
  properties: {
    format: 'rawxml'
    value: loadTextContent('mcp-api.policy.xml')
  }
  dependsOn: [
    APIMGatewayURLNamedValue
    apimBackendClientIdNamedValue
    backendMcpAppIdUriNamedValue
    backendMcpClientIdNamedValue
    mcpClaudeClientIdNamedValue
    mcpAppIdUriNamedValue
    mcpClientIdNamedValue
    mcpOauthBaseUrlNamedValue
    mcpScopeNamedValue
    mcpTenantIdNamedValue
  ]
}

resource mcpStreamableGetOperation 'Microsoft.ApiManagement/service/apis/operations@2023-05-01-preview' = {
  parent: mcpApi
  name: 'mcp-streamable-get'
  properties: {
    displayName: 'MCP Streamable GET Endpoint'
    method: 'GET'
    urlTemplate: '/mcp'
    description: 'Streamable GET endpoint for MCP Server'
  }
}

resource mcpStreamablePostOperation 'Microsoft.ApiManagement/service/apis/operations@2023-05-01-preview' = {
  parent: mcpApi
  name: 'mcp-streamable-post'
  properties: {
    displayName: 'MCP Streamable POST Endpoint'
    method: 'POST'
    urlTemplate: '/mcp'
    description: 'Streamable POST endpoint for MCP Server'
  }
}

resource mcpPrmOperation 'Microsoft.ApiManagement/service/apis/operations@2023-05-01-preview' = {
  parent: mcpApi
  name: 'mcp-prm'
  properties: {
    displayName: 'Protected Resource Metadata'
    method: 'GET'
    urlTemplate: '/.well-known/oauth-protected-resource'
    description: 'Protected Resource Metadata endpoint (RFC 9728)'
  }
}

resource mcpPrmPolicy 'Microsoft.ApiManagement/service/apis/operations/policies@2023-05-01-preview' = {
  parent: mcpPrmOperation
  name: 'policy'
  properties: {
    format: 'rawxml'
    value: loadTextContent('mcp-prm.policy.xml')
  }
  dependsOn: [
    APIMGatewayURLNamedValue
    mcpClaudeClientIdNamedValue
    mcpAppIdUriNamedValue
    mcpClientIdNamedValue
    mcpOauthBaseUrlNamedValue
    mcpScopeNamedValue
    mcpTenantIdNamedValue
  ]
}

resource mcpOAuthApi 'Microsoft.ApiManagement/service/apis@2023-05-01-preview' = {
  parent: apimService
  name: 'mcp-oauth'
  properties: {
    displayName: 'MCP OAuth API'
    description: 'OAuth discovery and token facade for MCP clients'
    subscriptionRequired: false
    path: 'mcp-oauth'
    protocols: [
      'https'
    ]
    serviceUrl: '${environment().authentication.loginEndpoint}${mcpAppTenantId}/oauth2/v2.0'
  }
}

resource mcpOAuthApiPolicy 'Microsoft.ApiManagement/service/apis/policies@2023-05-01-preview' = {
  parent: mcpOAuthApi
  name: 'policy'
  properties: {
    format: 'rawxml'
    value: loadTextContent('mcp-oauth-api.policy.xml')
  }
}

resource mcpOAuthRegisterOperation 'Microsoft.ApiManagement/service/apis/operations@2023-05-01-preview' = {
  parent: mcpOAuthApi
  name: 'mcp-oauth-register'
  properties: {
    displayName: 'Register OAuth Client'
    method: 'POST'
    urlTemplate: '/register'
    description: 'Static DCR-compatible registration stub for MCP clients'
  }
}

resource mcpOAuthAuthorizationServerOperation 'Microsoft.ApiManagement/service/apis/operations@2023-05-01-preview' = {
  parent: mcpOAuthApi
  name: 'mcp-oauth-authorization-server'
  properties: {
    displayName: 'OAuth Authorization Server Metadata'
    method: 'GET'
    urlTemplate: '/.well-known/oauth-authorization-server'
    description: 'OAuth authorization server metadata for MCP clients'
  }
}

resource mcpOAuthOpenIdConfigurationOperation 'Microsoft.ApiManagement/service/apis/operations@2023-05-01-preview' = {
  parent: mcpOAuthApi
  name: 'mcp-oauth-openid-configuration'
  properties: {
    displayName: 'OpenID Configuration'
    method: 'GET'
    urlTemplate: '/.well-known/openid-configuration'
    description: 'OpenID configuration facade for MCP clients'
  }
}

resource mcpOAuthAuthorizeOperation 'Microsoft.ApiManagement/service/apis/operations@2023-05-01-preview' = {
  parent: mcpOAuthApi
  name: 'mcp-oauth-authorize'
  properties: {
    displayName: 'Authorize Client'
    method: 'GET'
    urlTemplate: '/authorize'
    description: 'Redirects browser-based auth flows to Microsoft Entra'
  }
}

resource mcpOAuthTokenOperation 'Microsoft.ApiManagement/service/apis/operations@2023-05-01-preview' = {
  parent: mcpOAuthApi
  name: 'mcp-oauth-token'
  properties: {
    displayName: 'Token Endpoint'
    method: 'POST'
    urlTemplate: '/token'
    description: 'Proxies OAuth token requests to Microsoft Entra'
  }
}

resource mcpOAuthPrmOperation 'Microsoft.ApiManagement/service/apis/operations@2023-05-01-preview' = {
  parent: mcpOAuthApi
  name: 'mcp-oauth-protected-resource'
  properties: {
    displayName: 'OAuth Protected Resource Metadata'
    method: 'GET'
    urlTemplate: '/.well-known/oauth-protected-resource'
    description: 'Protected resource metadata advertised during 401 challenges'
  }
}

resource mcpOAuthRegisterPolicy 'Microsoft.ApiManagement/service/apis/operations/policies@2023-05-01-preview' = {
  parent: mcpOAuthRegisterOperation
  name: 'policy'
  properties: {
    format: 'rawxml'
    value: loadTextContent('mcp-oauth-register.policy.xml')
  }
  dependsOn: [
    mcpClaudeClientIdNamedValue
    mcpClaudeRedirectUrisCsvNamedValue
    mcpAppIdUriNamedValue
    mcpClientIdNamedValue
    mcpScopeNamedValue
  ]
}

resource mcpOAuthAuthorizationServerPolicy 'Microsoft.ApiManagement/service/apis/operations/policies@2023-05-01-preview' = {
  parent: mcpOAuthAuthorizationServerOperation
  name: 'policy'
  properties: {
    format: 'rawxml'
    value: loadTextContent('mcp-oauth-authorization-server.policy.xml')
  }
  dependsOn: [
    mcpOauthBaseUrlNamedValue
    mcpScopeNamedValue
    mcpTenantIdNamedValue
  ]
}

resource mcpOAuthOpenIdConfigurationPolicy 'Microsoft.ApiManagement/service/apis/operations/policies@2023-05-01-preview' = {
  parent: mcpOAuthOpenIdConfigurationOperation
  name: 'policy'
  properties: {
    format: 'rawxml'
    value: loadTextContent('mcp-oauth-openid-configuration.policy.xml')
  }
  dependsOn: [
    mcpOauthBaseUrlNamedValue
    mcpScopeNamedValue
    mcpTenantIdNamedValue
  ]
}

resource mcpOAuthAuthorizePolicy 'Microsoft.ApiManagement/service/apis/operations/policies@2023-05-01-preview' = {
  parent: mcpOAuthAuthorizeOperation
  name: 'policy'
  properties: {
    format: 'rawxml'
    value: loadTextContent('mcp-oauth-authorize.policy.xml')
  }
  dependsOn: [
    mcpClaudeClientIdNamedValue
    mcpClaudeRedirectUrisCsvNamedValue
    mcpOauthBaseUrlNamedValue
    mcpScopeNamedValue
    mcpTenantIdNamedValue
  ]
}

resource mcpOAuthTokenPolicy 'Microsoft.ApiManagement/service/apis/operations/policies@2023-05-01-preview' = {
  parent: mcpOAuthTokenOperation
  name: 'policy'
  properties: {
    format: 'rawxml'
    value: loadTextContent('mcp-oauth-token.policy.xml')
  }
  dependsOn: [
    mcpTenantIdNamedValue
  ]
}

resource mcpOAuthPrmPolicy 'Microsoft.ApiManagement/service/apis/operations/policies@2023-05-01-preview' = {
  parent: mcpOAuthPrmOperation
  name: 'policy'
  properties: {
    format: 'rawxml'
    value: loadTextContent('mcp-oauth-protected-resource.policy.xml')
  }
  dependsOn: [
    APIMGatewayURLNamedValue
    mcpOauthBaseUrlNamedValue
    mcpScopeNamedValue
  ]
}

output apiId string = mcpApi.id
output oauthApiId string = mcpOAuthApi.id
output mcpAppId string = mcpAppId
output mcpAppTenantId string = mcpAppTenantId
output mcpAppIdUri string = effectiveMcpAppIdUri
output mcpScope string = mcpScope
output backendUrl string = empty(backendUrl) ? 'https://${functionApp.properties.defaultHostName}/' : backendUrl
output mcpOAuthBaseUrl string = mcpOauthBaseUrl
