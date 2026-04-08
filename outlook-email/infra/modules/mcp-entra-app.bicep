extension microsoftGraphV1

@description('The name of the MCP Entra application')
param mcpAppUniqueName string

@description('The display name of the MCP Entra application')
param mcpAppDisplayName string

@description('Tenant ID where the application is registered')
param tenantId string = tenant().tenantId

@description('The principle id of the user-assigned managed identity')
param userAssignedIdentityPrincipleId string

@description('The web app name for callback URL configuration. When empty, no Function App redirect URI is registered.')
param functionAppName string = ''

@description('Whether to grant Microsoft Graph Mail.Send application role to the user-assigned managed identity. Set false when the Function App uses service principal credentials instead.')
param grantMailSendToManagedIdentity bool = true

@description('Provide an array of Microsoft Graph scopes like "User.Read"')
param graphAppScopes array = ['User.Read']

@description('Provide an array of Microsoft Graph roles like "Mail.Send"')
param graphAppRoles array = ['Mail.Send']

var loginEndpoint = environment().authentication.loginEndpoint
var issuer = '${loginEndpoint}${tenantId}/v2.0'

// Microsoft Graph app ID
var graphAppId = '00000003-0000-0000-c000-000000000000'
var msGraphAppId = graphAppId

// VS Code app ID
var vscodeAppId = 'aebc6443-996d-45c2-90f0-388ff96faa56'

// Permission ID
var applicationMailSendPermissionId = 'b633e1c5-b582-4048-a93e-9f11b44c7e96'

// Get the Microsoft Graph service principal so that the scope names
// can be looked up and mapped to a permission ID
resource msGraphSP 'Microsoft.Graph/servicePrincipals@v1.0' existing = {
  appId: graphAppId
}

var graphScopes = msGraphSP.oauth2PermissionScopes
var graphRoles = msGraphSP.appRoles

var scopes = map(filter(graphScopes, scope => contains(graphAppScopes, scope.value)), scope => {
  id: scope.id
  type: 'Scope'
})
var roles = map(filter(graphRoles, role => contains(graphAppRoles, role.value)), role => {
  id: role.id
  type: 'Role'
})

var delegatedPermissionId = guid(mcpAppUniqueName, 'user_impersonation')
var applicationRoleId = guid(mcpAppUniqueName, 'access_as_application')
resource mcpEntraApp 'Microsoft.Graph/applications@v1.0' = {
  displayName: mcpAppDisplayName
  uniqueName: mcpAppUniqueName
  api: {
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
    ]
    requestedAccessTokenVersion: 2
    preAuthorizedApplications: [
        {
          appId: vscodeAppId
          delegatedPermissionIds: [
            delegatedPermissionId
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
  // Parameterized Microsoft Graph delegated scopes based on appScopes
  requiredResourceAccess: [
    {
      resourceAppId: msGraphAppId // Microsoft Graph
      resourceAccess: concat(scopes, roles)
    }
  ]
  spa: {
    redirectUris: !empty(functionAppName) ? [
      'https://${functionAppName}.azurewebsites.net/auth/callback'
    ] : []
  }

  resource fic 'federatedIdentityCredentials@v1.0' = {
    name: '${mcpEntraApp.uniqueName}/msiAsFic'
    description: 'Trust the user-assigned MI as a credential for the MCP app'
    audiences: [
       'api://AzureADTokenExchange'
    ]
    issuer: issuer
    subject: userAssignedIdentityPrincipleId
  }
}

resource applicationRegistrationServicePrincipal 'Microsoft.Graph/servicePrincipals@v1.0' = {
  appId: mcpEntraApp.appId
}

resource applicationPermissionGrantForApp 'Microsoft.Graph/appRoleAssignedTo@v1.0' = {
  resourceId: msGraphSP.id
  appRoleId: applicationMailSendPermissionId
  principalId: applicationRegistrationServicePrincipal.id
}

resource applicationPermissionGrantForUserAssignedIdentity 'Microsoft.Graph/appRoleAssignedTo@v1.0' = if (grantMailSendToManagedIdentity) {
  resourceId: msGraphSP.id
  appRoleId: applicationMailSendPermissionId
  principalId: userAssignedIdentityPrincipleId
}

// Outputs
output mcpAppId string = mcpEntraApp.appId
output mcpAppTenantId string = tenantId
output mcpAppApplicationRoleValue string = 'access_as_application'
