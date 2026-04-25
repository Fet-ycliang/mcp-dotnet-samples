targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the environment that can be used as part of naming resource convention')
param environmentName string

@minLength(1)
@description('Primary location for all resources & Flex Consumption Function App')
@allowed([
  'australiaeast'
  'brazilsouth'
  'eastus'
  'eastus2'
  'southeastasia'
  'westeurope'
  'southafricanorth'
  'uaenorth'
])
@metadata({
  azd: {
    type: 'location'
  }
})
param location string

@description('Optional. Existing resource group name to deploy into. Leave empty to create rg-<environmentName>.')
param existingResourceGroupName string = ''

@description('Optional. Resource naming stem. Defaults to environmentName, for example fet-outlook-email-bst.')
param resourceNameStem string = ''

@description('Optional. Existing Azure Container Registry name to reuse for azd remote builds and ACA image pulls. Defaults to fetimageacr.')
param existingContainerRegistryName string = 'fetimageacr'

@description('Optional. Existing AcrPull role assignment name/GUID to adopt when reusing a shared ACR that already granted the ACA identity pull access.')
param existingContainerRegistryAcrPullRoleAssignmentName string = ''

@description('Tag value for cost allocation.')
param tagCostCenter string = '3901'

@description('Tag value for purpose classification.')
param tagPurpose string = 'ai_lab'

@description('Tag value for environment type classification.')
param tagEnvType string = 'Develop'

@description('Tag value for workload classification.')
param tagWorkload string = 'outlook-email'

@description('Tag value for service classification.')
param tagService string = 'mcp'

@description('Tag value for managed-by classification.')
param tagManagedBy string = 'azd'

param mcpOutlookEmailExists bool

param vnetEnabled bool = true // Enable VNet by default

@description('Id of the user or app to assign application roles')
param principalId string

@description('Whether to temporarily grant deployment user RBAC for storage and monitoring troubleshooting. Keep false in production.')
param allowUserIdentityPrincipalRbac bool = false

@description('Semicolon-separated sender allowlist that will be projected to Function App settings as AllowedSenders__N.')
param allowedSendersCsv string = ''

@description('Semicolon-separated reply-to allowlist that will be projected to Function App settings as AllowedReplyTo__N.')
param allowedReplyToCsv string = ''

@description('Whether Graph auth should use managed identity. Set false to use EntraId__TenantId / EntraId__ClientId / EntraId__ClientSecret app settings.')
param graphUseManagedIdentity bool = true

@description('Optional. Graph tenant ID when using service principal credentials from Function App app settings.')
param entraTenantId string = ''

@description('Optional. Graph client ID when using service principal credentials from Function App app settings.')
param entraClientId string = ''

@secure()
@description('Optional. Graph client secret or Key Vault reference string when using service principal credentials from Function App app settings.')
param entraClientSecret string = ''

@description('Optional legacy fallback. Existing Entra tenant ID for the shared MCP OAuth resource application. Prefer MCP_DIRECT_* for direct Easy Auth and MCP_APIM_RESOURCE_* for the APIM facade.')
param existingMcpOauthTenantId string = ''

@description('Optional legacy fallback. Existing Entra client/application ID for the shared MCP OAuth resource application. Prefer MCP_DIRECT_* for direct Easy Auth and MCP_APIM_RESOURCE_* for the APIM facade.')
param existingMcpOauthClientId string = ''

@description('Optional legacy fallback. Existing Application ID URI for the shared MCP OAuth resource application, for example api://apim-mcp. Prefer MCP_DIRECT_APPLICATION_ID_URI or MCP_APIM_RESOURCE_APPLICATION_ID_URI.')
param mcpOauthApplicationIdUri string = ''

@secure()
@description('Optional legacy fallback. Client secret or Key Vault reference string that must remain mapped to the ACA secret name mcp-oauth-client-secret. Prefer MCP_DIRECT_CLIENT_SECRET.')
param mcpOauthClientSecret string = ''

@description('Optional. Existing Entra tenant ID for the direct MCP resource application that protects the Function App / ACA direct path.')
param directMcpTenantId string = ''

@description('Optional. Existing Entra client/application ID for the direct MCP resource application that protects the Function App / ACA direct path.')
param directMcpClientId string = ''

@description('Optional. Existing Application ID URI for the direct MCP resource application. Leave empty to derive api://<directMcpClientId>.')
param directMcpApplicationIdUri string = ''

@secure()
@description('Optional. Client secret or Key Vault reference string for the direct MCP resource application. This must remain mapped to the ACA secret name mcp-oauth-client-secret.')
param directMcpClientSecret string = ''

@description('Optional. Semicolon-separated Entra client/application IDs allowed to call the Function App private endpoint directly with MCP OAuth tokens.')
param directAllowedClientApplicationsCsv string = ''

@description('Optional. Semicolon-separated Application (client) IDs of external M2M caller applications (e.g., Databricks service principal) that should receive the access_as_application role on the direct MCP resource application. Corresponds to MCP_EXTERNAL_CALLER_APP_IDS_CSV.')
param externalCallerAppIdsCsv string = ''

@description('Optional. Existing Entra tenant ID for the APIM MCP resource application. When paired with apimResourceClientId, deployment reuses that app instead of creating a new APIM MCP resource app.')
param apimResourceTenantId string = ''

@description('Optional. Existing Entra client/application ID for the APIM MCP resource application. When paired with apimResourceTenantId, deployment reuses that app instead of creating a new APIM MCP resource app.')
param apimResourceClientId string = ''

@description('Optional. Existing Application ID URI for the APIM MCP resource application. Leave empty to derive api://<apimResourceClientId> when reusing an existing app.')
param apimResourceApplicationIdUri string = ''

@description('Optional. Existing Entra client/application ID for the Claude caller public client app used by the APIM OAuth register stub. Required when the APIM OAuth facade is deployed.')
param mcpClaudeClientId string = ''

@description('Optional. Semicolon-separated Entra client/application IDs allowed to call the APIM retained MCP path. MCP_CLAUDE_CLIENT_ID is always included automatically.')
param apimAllowedClientApplicationsCsv string = ''

@description('Optional. Semicolon-separated exact redirect URIs allowed for the Claude public client on the APIM OAuth facade. Defaults to http://localhost.')
param mcpClaudeRedirectUrisCsv string = 'http://localhost'

@description('Optional. Existing VNet name to reuse when vnetEnabled is true. Leave empty to create a new VNet.')
param existingVirtualNetworkName string = ''

@description('Optional. Name of the Flex Consumption integration subnet. When reusing an existing VNet, this subnet must not contain underscores and must be delegated to Microsoft.App/environments.')
param integrationSubnetName string = ''

@description('Optional. Address prefix to create or update the integration subnet inside an existing VNet.')
param integrationSubnetAddressPrefix string = ''

@description('Optional. Existing subnet name to host private endpoints when reusing an existing VNet.')
param privateEndpointSubnetName string = ''

@description('Optional. Route table resource ID to attach when creating the integration subnet inside an existing VNet.')
param integrationSubnetRouteTableResourceId string = ''

@description('Optional. Network security group resource ID to attach when creating the integration subnet inside an existing VNet.')
param integrationSubnetNetworkSecurityGroupResourceId string = ''

@description('Optional. Resource group that hosts shared private DNS zones to reuse for private endpoints and internal APIM hostnames.')
param privateDnsZoneResourceGroupName string = ''

@description('Whether to deploy the sample Key Vault used for Key Vault referenced secrets.')
param deployKeyVault bool = false

@description('Optional explicit Key Vault name. Leave empty to use the standard derived naming pattern.')
param keyVaultNameOverride string = ''

@allowed([
  'Enabled'
  'Disabled'
])
@description('Public network access mode for the sample Key Vault. Keep Enabled while callers are still migrating to the private endpoint.')
param keyVaultPublicNetworkAccess string = 'Enabled'

@description('Whether to create a private endpoint for the sample Key Vault. Requires VNet + private endpoint subnet planning.')
param deployKeyVaultPrivateEndpoint bool = false

@description('Whether to deploy API Management and the MCP API facade.')
param deployApim bool = true

@description('API Management SKU for the APIM + OAuth MCP gateway path. Use Developer for dev/test cost control, and reassess before production.')
@allowed([
  'Developer'
  'Basic'
  'Basicv2'
  'Standard'
  'Standardv2'
  'Premium'
])
param apimSku string = 'Basicv2'

@description('Whether to configure the MCP API facade and OAuth app objects inside APIM. Set false to deploy APIM networking/private DNS first and defer OAuth later.')
param deployApimMcpApi bool = true

@description('Optional. Existing Container App name that the APIM MCP facade should forward to. Leave empty to keep the Function App backend.')
param apimBackendContainerAppName string = ''

@maxLength(50)
@description('Optional explicit API Management service name. Must use a valid APIM service name and is ignored when deployApim is false. Leave empty to use the standard derived APIM naming pattern.')
param apimNameOverride string = ''

@description('Whether to deploy API Management in internal virtual network mode. Requires an existing VNet, an APIM subnet, and private DNS planning.')
param apimInternalVirtualNetwork bool = false

@description('Optional existing subnet name for APIM when apimInternalVirtualNetwork is true. The subnet must already exist, have no delegation, and include the required NSG rules.')
param apimSubnetName string = ''

@description('Optional. Existing APIM private DNS virtual network link name to adopt when the private zones are already linked to the target VNet.')
param apimPrivateDnsVirtualNetworkLinkName string = ''

@description('Optional. Address prefix to update the existing APIM subnet inside an existing VNet when apimInternalVirtualNetwork is true. Leave empty to reference the subnet without changing it.')
param apimSubnetAddressPrefix string = ''

@description('Optional. Route table resource ID to attach when updating the APIM subnet inside an existing VNet.')
param apimSubnetRouteTableResourceId string = ''

@description('Optional. Network security group resource ID to attach when updating the APIM subnet inside an existing VNet.')
param apimSubnetNetworkSecurityGroupResourceId string = ''

@description('Whether to create a private endpoint for the Function App and disable public network access on the app.')
param deployFunctionAppPrivateEndpoint bool = false

// Tags that should be applied to all resources.
// 
// Note that 'azd-service-name' tags should be applied separately to service host resources.
// Example usage:
//   tags: union(tags, { 'azd-service-name': <service name in azure.yaml> })
var effectiveResourceNameStem = toLower(empty(resourceNameStem) ? environmentName : resourceNameStem)
var environmentTag = last(split(effectiveResourceNameStem, '-'))
var tags = {
  'azd-env-name': environmentName
  cost_center: tagCostCenter
  Purpose: tagPurpose
  EnvType: tagEnvType
  environment: environmentTag
  workload: tagWorkload
  service: tagService
  managed_by: tagManagedBy
}

var targetResourceGroupName = empty(existingResourceGroupName) ? 'rg-${environmentName}' : existingResourceGroupName

// Organize resources in a resource group
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = if (empty(existingResourceGroupName)) {
  name: targetResourceGroupName
  location: location
  tags: tags
}

module resources 'resources.bicep' = {
  scope: resourceGroup(targetResourceGroupName)
  name: 'resources'
  params: {
    location: location
    tags: tags
    resourceNameStem: effectiveResourceNameStem
    existingContainerRegistryName: existingContainerRegistryName
    existingContainerRegistryAcrPullRoleAssignmentName: existingContainerRegistryAcrPullRoleAssignmentName
    principalId: principalId
    mcpOutlookEmailExists: mcpOutlookEmailExists
    azdServiceName: 'outlook-email'
    vnetEnabled: vnetEnabled
    allowUserIdentityPrincipalRbac: allowUserIdentityPrincipalRbac
    allowedSendersCsv: allowedSendersCsv
    allowedReplyToCsv: allowedReplyToCsv
    graphUseManagedIdentity: graphUseManagedIdentity
    entraTenantId: entraTenantId
    entraClientId: entraClientId
    entraClientSecret: entraClientSecret
    existingMcpOauthTenantId: existingMcpOauthTenantId
    existingMcpOauthClientId: existingMcpOauthClientId
    mcpOauthApplicationIdUri: mcpOauthApplicationIdUri
    mcpOauthClientSecret: mcpOauthClientSecret
    directMcpTenantId: directMcpTenantId
    directMcpClientId: directMcpClientId
    directMcpApplicationIdUri: directMcpApplicationIdUri
    directMcpClientSecret: directMcpClientSecret
    directAllowedClientApplicationsCsv: directAllowedClientApplicationsCsv
    externalCallerAppIdsCsv: externalCallerAppIdsCsv
    apimResourceTenantId: apimResourceTenantId
    apimResourceClientId: apimResourceClientId
    apimResourceApplicationIdUri: apimResourceApplicationIdUri
    mcpClaudeClientId: mcpClaudeClientId
    apimAllowedClientApplicationsCsv: apimAllowedClientApplicationsCsv
    mcpClaudeRedirectUrisCsv: mcpClaudeRedirectUrisCsv
    existingVirtualNetworkName: existingVirtualNetworkName
    integrationSubnetName: integrationSubnetName
    integrationSubnetAddressPrefix: integrationSubnetAddressPrefix
    privateEndpointSubnetName: privateEndpointSubnetName
    integrationSubnetRouteTableResourceId: integrationSubnetRouteTableResourceId
    integrationSubnetNetworkSecurityGroupResourceId: integrationSubnetNetworkSecurityGroupResourceId
    privateDnsZoneResourceGroupName: privateDnsZoneResourceGroupName
    deployKeyVault: deployKeyVault
    keyVaultNameOverride: keyVaultNameOverride
    keyVaultPublicNetworkAccess: keyVaultPublicNetworkAccess
    deployKeyVaultPrivateEndpoint: deployKeyVaultPrivateEndpoint
    deployApim: deployApim
    apimSku: apimSku
    deployApimMcpApi: deployApimMcpApi
    apimBackendContainerAppName: apimBackendContainerAppName
    apimNameOverride: apimNameOverride
    apimInternalVirtualNetwork: apimInternalVirtualNetwork
    apimSubnetName: apimSubnetName
    apimPrivateDnsVirtualNetworkLinkName: apimPrivateDnsVirtualNetworkLinkName
    apimSubnetAddressPrefix: apimSubnetAddressPrefix
    apimSubnetRouteTableResourceId: apimSubnetRouteTableResourceId
    apimSubnetNetworkSecurityGroupResourceId: apimSubnetNetworkSecurityGroupResourceId
    deployFunctionAppPrivateEndpoint: deployFunctionAppPrivateEndpoint
  }
  dependsOn: [
    rg
  ]
}

output AZURE_CONTAINER_REGISTRY_ENDPOINT string = resources.outputs.AZURE_CONTAINER_REGISTRY_ENDPOINT
output AZURE_RESOURCE_KEY_VAULT_ID string = resources.outputs.AZURE_RESOURCE_KEY_VAULT_ID
output AZURE_RESOURCE_KEY_VAULT_NAME string = resources.outputs.AZURE_RESOURCE_KEY_VAULT_NAME
output AZURE_RESOURCE_KEY_VAULT_URI string = resources.outputs.AZURE_RESOURCE_KEY_VAULT_URI
output AZURE_RESOURCE_MCP_OUTLOOK_EMAIL_ID string = resources.outputs.AZURE_RESOURCE_MCP_OUTLOOK_EMAIL_ID
output AZURE_RESOURCE_MCP_OUTLOOK_EMAIL_NAME string = resources.outputs.AZURE_RESOURCE_MCP_OUTLOOK_EMAIL_NAME
output AZURE_RESOURCE_MCP_OUTLOOK_EMAIL_FQDN string = resources.outputs.AZURE_RESOURCE_MCP_OUTLOOK_EMAIL_FQDN
output AZURE_RESOURCE_MCP_OUTLOOK_EMAIL_GATEWAY_ID string = resources.outputs.AZURE_RESOURCE_MCP_OUTLOOK_EMAIL_GATEWAY_ID
output AZURE_RESOURCE_MCP_OUTLOOK_EMAIL_GATEWAY_NAME string = resources.outputs.AZURE_RESOURCE_MCP_OUTLOOK_EMAIL_GATEWAY_NAME
output AZURE_RESOURCE_MCP_OUTLOOK_EMAIL_GATEWAY_FQDN string = resources.outputs.AZURE_RESOURCE_MCP_OUTLOOK_EMAIL_GATEWAY_FQDN
output AZURE_RESOURCE_MCP_OUTLOOK_EMAIL_APIM_BACKEND_FQDN string = resources.outputs.AZURE_RESOURCE_MCP_OUTLOOK_EMAIL_APIM_BACKEND_FQDN
output AZURE_RESOURCE_GROUP string = targetResourceGroupName
