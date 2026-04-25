extension microsoftGraphV1

/**
 * @module entra-app-role-assignment
 * @description Assigns a Microsoft Entra application role (appRoleAssignedTo) to a caller
 * service principal on a target resource application.
 *
 * Typical use: grant Databricks (or any external M2M caller) the
 * access_as_application role on the MCP resource application so it can obtain
 * an application access token (Client Credentials Grant, RFC 6749 §4.4).
 *
 * Usage (standalone, one-off grant):
 *   az deployment group create \
 *     --resource-group <rg> \
 *     --template-file infra/modules/entra-app-role-assignment.bicep \
 *     --parameters callerAppId=<caller-client-id> resourceAppId=<resource-client-id>
 *
 * Called automatically from resources.bicep when
 * externalCallerAppIdsCsv contains the caller's application (client) ID.
 */

// ------------------
//    PARAMETERS
// ------------------

@description('Application (client) ID of the caller application that needs the role assigned. For Databricks, this is the DatabricksAgent / DatabricksExternalMcp app ID.')
param callerAppId string

@description('Application (client) ID of the resource application that defines the role. For the MCP direct path, this is the mcpEntraApp (MCP_DIRECT_CLIENT_ID) app ID.')
param resourceAppId string

@description('Value of the application role to assign. Use access_as_application for M2M callers (Client Credentials Grant).')
param roleValue string = 'access_as_application'

// ------------------
//    RESOURCES
// ------------------

resource callerServicePrincipal 'Microsoft.Graph/servicePrincipals@v1.0' existing = {
  appId: callerAppId
}

resource resourceServicePrincipal 'Microsoft.Graph/servicePrincipals@v1.0' existing = {
  appId: resourceAppId
}

var appRoleId = first(filter(resourceServicePrincipal.appRoles, r => r.value == roleValue))!.id

resource appRoleAssignment 'Microsoft.Graph/appRoleAssignedTo@v1.0' = {
  resourceId: resourceServicePrincipal.id
  appRoleId: appRoleId
  principalId: callerServicePrincipal.id
}

// ------------------
//    OUTPUTS
// ------------------

output assignmentId string = appRoleAssignment.id
output callerPrincipalId string = callerServicePrincipal.id
output appRoleId string = appRoleId
