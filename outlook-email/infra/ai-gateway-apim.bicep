/**
 * @description Deploy Log Analytics Workspace + Application Insights + APIM Basicv2 with Private Endpoint.
 * Reusable template: provide a unique resourceNameStem for each project instance (3101, 3201, 3901).
 *
 * Derived resource names:
 *   APIM                     apim-<stem>
 *   Application Insights     appi-<stem>
 *   Log Analytics Workspace  log-<stem>
 *   Private Endpoint         pe-<stem>
 *
 * Basicv2 does NOT support VNet injection (apimVirtualNetworkType must be 'None').
 * Use deployPrivateEndpoint=true for inbound private access via Azure Private Link.
 *
 * Usage:
 *   az deployment group create \
 *     --resource-group <rg> \
 *     --template-file infra/ai-gateway-apim.bicep \
 *     --parameters infra/ai-gateway-apim.<project>.parameters.json \
 *     [--what-if]
 */

// ------------------
//    PARAMETERS
// ------------------

@description('Naming stem for resources, e.g. "fet-3101-ai-gateway". Produces apim-<stem>, appi-<stem>, log-<stem>, pe-<stem>.')
param resourceNameStem string

@description('Location for all resources.')
param location string = resourceGroup().location

@description('APIM pricing tier. Basicv2 does not support VNet injection; use deployPrivateEndpoint for inbound private access.')
@allowed([
  'Consumption'
  'Developer'
  'Basic'
  'Basicv2'
  'Standard'
  'Standardv2'
  'Premium'
])
param apimSku string = 'Basicv2'

@description('APIM virtual network deployment mode. Must be "None" for Basicv2.')
@allowed([
  'None'
  'External'
  'Internal'
])
param apimVirtualNetworkType string = 'None'

@description('Name of the existing virtual network. Used for Private Endpoint subnet reference.')
param virtualNetworkName string = 'apim-bst-vnet'

@description('Name of the existing subnet for Private Endpoint placement (Basicv2) or VNet injection (v1 tiers).')
param apimSubnetName string

@description('Publisher email shown in the APIM portal.')
param publisherEmail string = 'noreply@microsoft.com'

@description('Publisher name shown in the APIM portal.')
param publisherName string = 'Microsoft'

@description('Optional user-assigned managed identity resource ID for APIM backend token acquisition.')
param managedIdentityResourceId string = ''

@description('Deploy an inbound Private Endpoint for the APIM Gateway sub-resource. Recommended for Basicv2.')
param deployPrivateEndpoint bool = false

@description('Deploy APIM private DNS A-records. For PE mode, adds a DNS zone group on the PE. For VNet injection mode, creates manual A-records via apim-private-dns.bicep.')
param deployApimPrivateDns bool = true

@description('Resource ID of the VNet to link to the private DNS zones. Defaults to the VNet in the current resource group when empty.')
param virtualNetworkResourceId string = ''

@description('Resource group hosting the shared APIM private DNS zones.')
param privateDnsZoneResourceGroupName string = 'aibde-common-rg'

@description('Existing VNet link name in the APIM private DNS zones. Provide to reuse an existing link and avoid "already linked" conflicts. Only used in VNet injection mode.')
param existingVirtualNetworkLinkName string = ''

@description('Log Analytics Workspace retention in days.')
@minValue(30)
@maxValue(730)
param logRetentionDays int = 30

@description('Whether public network access to the APIM gateway is allowed. Disable to restrict inbound access to private endpoints only.')
@allowed([
  'Enabled'
  'Disabled'
])
param apimPublicNetworkAccess string = 'Enabled'

@description('Tags applied to all resources.')
param tags object = {}

// ------------------
//    VARIABLES
// ------------------

var abbrs = loadJsonContent('./abbreviations.json')
var normalizedStem = toLower(resourceNameStem)

var apiManagementName = '${abbrs.apiManagementService}${normalizedStem}'
var appInsightsName = '${abbrs.insightsComponents}${normalizedStem}'
var logAnalyticsName = '${abbrs.operationalInsightsWorkspaces}${normalizedStem}'
var peName = 'pe-${normalizedStem}'

// Used only for VNet injection mode (v1 tiers).
var apimSubnetResourceId = apimVirtualNetworkType != 'None' && !empty(virtualNetworkName) && !empty(apimSubnetName)
  ? resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, apimSubnetName)
  : ''

// Used for Private Endpoint placement.
var peSubnetResourceId = resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, apimSubnetName)

// Fall back to deriving VNet resource ID from name if not provided explicitly.
var effectiveVNetResourceId = !empty(virtualNetworkResourceId)
  ? virtualNetworkResourceId
  : resourceId('Microsoft.Network/virtualNetworks', virtualNetworkName)

var effectiveDnsRg = empty(privateDnsZoneResourceGroupName) ? resourceGroup().name : privateDnsZoneResourceGroupName

// Full resource ID of the azure-api.net private DNS zone (may be in a different RG).
var apimGatewayDnsZoneId = '/subscriptions/${subscription().subscriptionId}/resourceGroups/${effectiveDnsRg}/providers/Microsoft.Network/privateDnsZones/azure-api.net'

// ------------------
//    RESOURCES
// ------------------

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: logAnalyticsName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: logRetentionDays
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  tags: tags
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalyticsWorkspace.id
  }
}

module apimService './modules/apim.bicep' = {
  name: 'apim-${take(uniqueString(apiManagementName, resourceGroup().id), 8)}'
  params: {
    apiManagementName: apiManagementName
    location: location
    apimSku: apimSku
    apimVirtualNetworkType: apimVirtualNetworkType
    apimSubnetResourceId: apimSubnetResourceId
    publisherEmail: publisherEmail
    publisherName: publisherName
    managedIdentityResourceId: managedIdentityResourceId
    appInsightsInstrumentationKey: appInsights.properties.InstrumentationKey
    appInsightsId: appInsights.id
    publicNetworkAccess: apimPublicNetworkAccess
  }
}

// Private Endpoint for APIM Gateway sub-resource (Basicv2 inbound private access).
resource apimPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-09-01' = if (deployPrivateEndpoint) {
  name: peName
  location: location
  tags: tags
  properties: {
    subnet: {
      id: peSubnetResourceId
    }
    privateLinkServiceConnections: [
      {
        name: 'pe-conn-${normalizedStem}'
        properties: {
          privateLinkServiceId: apimService.outputs.id
          groupIds: [
            'Gateway'
          ]
        }
      }
    ]
  }
}

// DNS zone group: automatically registers PE private IP into the azure-api.net zone.
resource apimPeDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-09-01' = if (deployPrivateEndpoint && deployApimPrivateDns) {
  name: '${peName}/default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'azure-api-net'
        properties: {
          privateDnsZoneId: apimGatewayDnsZoneId
        }
      }
    ]
  }
  dependsOn: [
    apimPrivateEndpoint
  ]
}

// Manual A-records for VNet injection mode (Developer/Standard/Premium with Internal/External VNet).
// Not used for Basicv2 PE deployments.
module apimPrivateDns './modules/apim-private-dns.bicep' = if (!deployPrivateEndpoint && deployApimPrivateDns) {
  name: 'apim-dns-${take(uniqueString(apiManagementName, resourceGroup().id), 8)}'
  scope: resourceGroup(effectiveDnsRg)
  params: {
    apiManagementName: apiManagementName
    privateIpAddress: apimService.outputs.privateIpAddress
    virtualNetworkResourceId: effectiveVNetResourceId
    existingVirtualNetworkLinkName: existingVirtualNetworkLinkName
    tags: tags
  }
}

// ------------------
//    OUTPUTS
// ------------------

output apimName string = apimService.outputs.name
output apimGatewayUrl string = apimService.outputs.gatewayUrl
output apimPrivateIpAddress string = apimService.outputs.privateIpAddress
output appInsightsName string = appInsights.name
output logAnalyticsWorkspaceName string = logAnalyticsWorkspace.name
output privateEndpointName string = deployPrivateEndpoint ? peName : ''

