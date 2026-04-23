extension microsoftGraphV1

@description('The unique name of the APIM MCP resource application')
param mcpAppUniqueName string

@description('The display name of the APIM MCP resource application')
param mcpAppDisplayName string

@description('Application ID URI exposed by the APIM MCP resource application, for example api://apim-mcp.')
param mcpAppIdentifierUri string

@description('Tenant ID where the application is registered')
param tenantId string = tenant().tenantId

var vscodeAppId = 'aebc6443-996d-45c2-90f0-388ff96faa56'
var delegatedPermissionId = guid(mcpAppUniqueName, 'user_impersonation')
var delegatedMcpAccessPermissionId = guid(mcpAppUniqueName, 'mcp.access')
var applicationRoleId = guid(mcpAppUniqueName, 'access_as_application')

resource mcpEntraApp 'Microsoft.Graph/applications@v1.0' = {
  displayName: mcpAppDisplayName
  uniqueName: mcpAppUniqueName
  identifierUris: [
    mcpAppIdentifierUri
  ]
  api: {
    requestedAccessTokenVersion: 2
    oauth2PermissionScopes: [
      {
        id: delegatedPermissionId
        adminConsentDescription: 'Allows the application to access MCP resources on behalf of the signed-in user'
        adminConsentDisplayName: 'Access MCP resources'
        isEnabled: true
        type: 'User'
        userConsentDescription: 'Allows the app to access MCP resources on your behalf'
        userConsentDisplayName: 'Access MCP resources'
        value: 'user_impersonation'
      }
      {
        id: delegatedMcpAccessPermissionId
        adminConsentDescription: 'Allows the application to access MCP resources with the mcp.access delegated scope'
        adminConsentDisplayName: 'Access MCP resources (mcp.access)'
        isEnabled: true
        type: 'User'
        userConsentDescription: 'Allows the app to access MCP resources using the mcp.access delegated scope'
        userConsentDisplayName: 'Access MCP resources (mcp.access)'
        value: 'mcp.access'
      }
    ]
    preAuthorizedApplications: [
      {
        appId: vscodeAppId
        delegatedPermissionIds: [
          delegatedPermissionId
          delegatedMcpAccessPermissionId
        ]
      }
    ]
  }
  appRoles: [
    {
      id: applicationRoleId
      allowedMemberTypes: [
        'Application'
      ]
      description: 'Allows the application to access MCP resources as itself'
      displayName: 'Access MCP resources as the application'
      isEnabled: true
      value: 'access_as_application'
    }
  ]
}

resource applicationRegistrationServicePrincipal 'Microsoft.Graph/servicePrincipals@v1.0' = {
  appId: mcpEntraApp.appId
}

output mcpAppId string = mcpEntraApp.appId
output mcpAppIdUri string = mcpAppIdentifierUri
output mcpAppTenantId string = tenantId
output mcpAppApplicationRoleValue string = 'access_as_application'
