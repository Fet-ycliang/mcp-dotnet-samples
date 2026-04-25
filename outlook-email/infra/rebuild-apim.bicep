/**
 * @description Rebuilds an APIM instance into an existing VNet subnet.
 * Use this after running remove-apim.bicep (or manually deleting the old APIM)
 * when you need to recreate APIM — e.g. after a subnet-prefix migration.
 * The target subnet must already exist; this template references it by name only
 * and does NOT modify its address prefix or delegations.
 *
 * Usage:
 *   az deployment group create \
 *     --resource-group <rg-name> \
 *     --template-file infra/rebuild-apim.bicep \
 *     --parameters infra/rebuild-apim.parameters.json
 *
 * Prerequisites:
 *   - The target subnet (virtualNetworkName / apimSubnetName) must exist with
 *     the correct prefix, NSG, and route table already attached.
 *   - For Internal VNet mode the private DNS zones for APIM must exist in the
 *     resource group specified by privateDnsZoneResourceGroupName (or the same
 *     resource group when left empty).
 */

// ------------------
//    PARAMETERS
// ------------------

@description('Resource naming stem, e.g. fet-outlook-email-bst. Used to derive apimName when apimNameOverride is empty.')
param resourceNameStem string

@description('Optional. Explicit APIM service name. Overrides the apim-<resourceNameStem> default.')
@maxLength(50)
param apimNameOverride string = ''

@description('Location for the APIM instance.')
param location string = resourceGroup().location

@description('APIM SKU. Developer is required for Internal VNet mode.')
@allowed([
  'Consumption'
  'Developer'
  'Basic'
  'Basicv2'
  'Standard'
  'Standardv2'
  'Premium'
])
param apimSku string = 'Developer'

@description('APIM virtual network deployment mode.')
@allowed([
  'None'
  'External'
  'Internal'
])
param apimVirtualNetworkType string = 'Internal'

@description('Name of the existing virtual network that contains the APIM subnet.')
param virtualNetworkName string = ''

@description('Name of the existing subnet for APIM injection. The subnet must already have the correct prefix, NSG, and route table.')
param apimSubnetName string = ''

@description('Publisher e-mail shown in the APIM portal.')
param publisherEmail string = 'noreply@microsoft.com'

@description('Publisher name shown in the APIM portal.')
param publisherName string = 'Microsoft'

@description('Optional. Resource ID of a user-assigned managed identity for APIM backend token acquisition.')
param managedIdentityResourceId string = ''

@description('Optional. Application Insights instrumentation key for APIM diagnostics logging.')
param appInsightsInstrumentationKey string = ''

@description('Optional. Application Insights resource ID for APIM diagnostics logging.')
param appInsightsId string = ''

@description('Whether to also (re-)create the private DNS A-records for this APIM instance.')
param deployApimPrivateDns bool = false

@description('Resource ID of the virtual network to link the private DNS zones to. Required when deployApimPrivateDns is true.')
param virtualNetworkResourceId string = ''

@description('Resource group that hosts the APIM private DNS zones. Leave empty if the DNS zones are in the same resource group.')
param privateDnsZoneResourceGroupName string = ''

@description('Existing VNet link name in the APIM private DNS zones. Supply this to reuse an existing link instead of creating a new one (avoids "already linked" conflicts).')
param existingVirtualNetworkLinkName string = ''

@description('Tags applied to all resources.')
param tags object = {}

// ------------------
//    VARIABLES
// ------------------

var abbrs = loadJsonContent('./abbreviations.json')
var normalizedStem = toLower(resourceNameStem)
var apiManagementName = !empty(apimNameOverride) ? apimNameOverride : '${abbrs.apiManagementService}${normalizedStem}'

var apimSubnetResourceId = apimVirtualNetworkType != 'None' && !empty(virtualNetworkName) && !empty(apimSubnetName)
  ? resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, apimSubnetName)
  : ''

var effectiveDnsRg = empty(privateDnsZoneResourceGroupName) ? resourceGroup().name : privateDnsZoneResourceGroupName

// ------------------
//    RESOURCES
// ------------------

module apimService './modules/apim.bicep' = {
  name: 'rebuild-apim-${take(uniqueString(apiManagementName, resourceGroup().id), 8)}'
  params: {
    apiManagementName: apiManagementName
    location: location
    apimSku: apimSku
    apimVirtualNetworkType: apimVirtualNetworkType
    apimSubnetResourceId: apimSubnetResourceId
    publisherEmail: publisherEmail
    publisherName: publisherName
    managedIdentityResourceId: managedIdentityResourceId
    appInsightsInstrumentationKey: appInsightsInstrumentationKey
    appInsightsId: appInsightsId
  }
}

module apimPrivateDns './modules/apim-private-dns.bicep' = if (deployApimPrivateDns && !empty(virtualNetworkResourceId)) {
  name: 'rebuild-apim-dns-${take(uniqueString(apiManagementName, resourceGroup().id), 8)}'
  scope: resourceGroup(effectiveDnsRg)
  params: {
    apiManagementName: apiManagementName
    privateIpAddress: apimService.outputs.privateIpAddress
    virtualNetworkResourceId: virtualNetworkResourceId
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
