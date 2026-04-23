@description('The API Management service name used in the default internal hostnames.')
param apiManagementName string

@description('The internal private IP address of the APIM instance.')
param privateIpAddress string

@description('The virtual network resource ID that should resolve the APIM private hostnames.')
param virtualNetworkResourceId string

@description('Tags applied to the private DNS resources.')
param tags object = {}

@description('Optional existing private DNS virtual network link name to adopt when the shared zones are already linked to the target VNet.')
param existingVirtualNetworkLinkName string = ''

var zoneNames = [
  'azure-api.net'
  'portal.azure-api.net'
  'developer.azure-api.net'
  'management.azure-api.net'
  'scm.azure-api.net'
]

var linkName = !empty(existingVirtualNetworkLinkName) ? existingVirtualNetworkLinkName : 'link-${take(uniqueString(apiManagementName, virtualNetworkResourceId), 16)}'

resource privateDnsZones 'Microsoft.Network/privateDnsZones@2020-06-01' = [for zoneName in zoneNames: {
  name: zoneName
  location: 'global'
  tags: tags
}]

resource privateDnsZoneLinks 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = [for (zoneName, i) in zoneNames: {
  parent: privateDnsZones[i]
  name: linkName
  location: 'global'
  tags: tags
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: virtualNetworkResourceId
    }
  }
}]

resource apimHostRecords 'Microsoft.Network/privateDnsZones/A@2020-06-01' = [for (zoneName, i) in zoneNames: {
  parent: privateDnsZones[i]
  name: apiManagementName
  properties: {
    ttl: 3600
    aRecords: [
      {
        ipv4Address: privateIpAddress
      }
    ]
  }
}]
