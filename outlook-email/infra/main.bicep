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

@description('Optional. Existing Entra tenant ID for the MCP OAuth resource application used by APIM token validation. When paired with existingMcpOauthClientId, deployment reuses that app instead of creating a new MCP app registration.')
param existingMcpOauthTenantId string = ''

@description('Optional. Existing Entra client/application ID for the MCP OAuth resource application used by APIM token validation. When paired with existingMcpOauthTenantId, deployment reuses that app instead of creating a new MCP app registration.')
param existingMcpOauthClientId string = ''

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

@maxLength(50)
@description('Optional explicit API Management service name. Must use a valid APIM service name and is ignored when deployApim is false. Leave empty to use the standard derived APIM naming pattern.')
param apimNameOverride string = ''

@description('Whether to deploy API Management in internal virtual network mode. Requires an existing VNet, an APIM subnet, and private DNS planning.')
param apimInternalVirtualNetwork bool = false

@description('Optional existing subnet name for APIM when apimInternalVirtualNetwork is true. The subnet must already exist, have no delegation, and include the required NSG rules.')
param apimSubnetName string = ''

@description('Optional. Address prefix to update the existing APIM subnet inside an existing VNet when apimInternalVirtualNetwork is true. Leave empty to reference the subnet without changing it.')
param apimSubnetAddressPrefix string = ''

@description('Optional. Route table resource ID to attach when updating the APIM subnet inside an existing VNet.')
param apimSubnetRouteTableResourceId string = ''

@description('Optional. Network security group resource ID to attach when updating the APIM subnet inside an existing VNet.')
param apimSubnetNetworkSecurityGroupResourceId string = ''

@description('Whether to create a private endpoint for the Function App and disable public network access on the app.')
param deployFunctionAppPrivateEndpoint bool = false

@description('Whether to deploy the MCP server on Azure Container Apps (ACA) instead of Azure Functions. When true, set the azure.yaml service host to containerapp.')
param deployAca bool = false

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
    principalId: principalId
    mcpOutlookEmailExists: mcpOutlookEmailExists
    azdServiceName: deployAca ? 'outlook-email-aca' : 'outlook-email'
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
    existingVirtualNetworkName: existingVirtualNetworkName
    integrationSubnetName: integrationSubnetName
    integrationSubnetAddressPrefix: integrationSubnetAddressPrefix
    privateEndpointSubnetName: privateEndpointSubnetName
    integrationSubnetRouteTableResourceId: integrationSubnetRouteTableResourceId
    integrationSubnetNetworkSecurityGroupResourceId: integrationSubnetNetworkSecurityGroupResourceId
    privateDnsZoneResourceGroupName: privateDnsZoneResourceGroupName
    deployApim: deployApim
    apimSku: apimSku
    deployApimMcpApi: deployApimMcpApi
    apimNameOverride: apimNameOverride
    apimInternalVirtualNetwork: apimInternalVirtualNetwork
    apimSubnetName: apimSubnetName
    apimSubnetAddressPrefix: apimSubnetAddressPrefix
    apimSubnetRouteTableResourceId: apimSubnetRouteTableResourceId
    apimSubnetNetworkSecurityGroupResourceId: apimSubnetNetworkSecurityGroupResourceId
    deployFunctionAppPrivateEndpoint: deployFunctionAppPrivateEndpoint
    deployAca: deployAca
  }
  dependsOn: [
    rg
  ]
}

output AZURE_CONTAINER_REGISTRY_ENDPOINT string = resources.outputs.AZURE_CONTAINER_REGISTRY_ENDPOINT
output AZURE_RESOURCE_MCP_OUTLOOK_EMAIL_ID string = resources.outputs.AZURE_RESOURCE_MCP_OUTLOOK_EMAIL_ID
output AZURE_RESOURCE_MCP_OUTLOOK_EMAIL_NAME string = resources.outputs.AZURE_RESOURCE_MCP_OUTLOOK_EMAIL_NAME
output AZURE_RESOURCE_MCP_OUTLOOK_EMAIL_FQDN string = resources.outputs.AZURE_RESOURCE_MCP_OUTLOOK_EMAIL_FQDN
output AZURE_RESOURCE_MCP_OUTLOOK_EMAIL_GATEWAY_ID string = resources.outputs.AZURE_RESOURCE_MCP_OUTLOOK_EMAIL_GATEWAY_ID
output AZURE_RESOURCE_MCP_OUTLOOK_EMAIL_GATEWAY_NAME string = resources.outputs.AZURE_RESOURCE_MCP_OUTLOOK_EMAIL_GATEWAY_NAME
output AZURE_RESOURCE_MCP_OUTLOOK_EMAIL_GATEWAY_FQDN string = resources.outputs.AZURE_RESOURCE_MCP_OUTLOOK_EMAIL_GATEWAY_FQDN
output AZURE_RESOURCE_GROUP string = targetResourceGroupName
