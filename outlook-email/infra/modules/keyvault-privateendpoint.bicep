param virtualNetworkName string
param subnetName string

@description('Specifies the Key Vault resource name.')
param keyVaultName string

param location string = resourceGroup().location
param tags object = {}
param privateDnsZoneResourceGroupName string = ''

resource vnet 'Microsoft.Network/virtualNetworks@2021-08-01' existing = {
  name: virtualNetworkName
}

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
}

var privateDnsZoneName = 'privatelink.vaultcore.azure.net'
var useSharedPrivateDnsZones = !empty(privateDnsZoneResourceGroupName)
var managedPrivateDnsZoneResourceId = !useSharedPrivateDnsZones ? privateDnsZoneDeployment!.outputs.resourceId : ''

resource sharedPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' existing = if (useSharedPrivateDnsZones) {
  name: privateDnsZoneName
  scope: resourceGroup(privateDnsZoneResourceGroupName)
}

module keyVaultPrivateEndpoint 'br/public:avm/res/network/private-endpoint:0.11.0' = {
  name: 'keyvault-private-endpoint-deployment'
  params: {
    name: 'pe-${keyVaultName}'
    location: location
    tags: tags
    subnetResourceId: '${vnet.id}/subnets/${subnetName}'
    privateLinkServiceConnections: [
      {
        name: 'keyVaultPrivateLinkConnection'
        properties: {
          privateLinkServiceId: keyVault.id
          groupIds: [
            'vault'
          ]
        }
      }
    ]
    customDnsConfigs: []
    privateDnsZoneGroup: {
      name: 'keyVaultPrivateDnsZoneGroup'
      privateDnsZoneGroupConfigs: [
        {
          name: 'keyVaultARecord'
          privateDnsZoneResourceId: useSharedPrivateDnsZones ? sharedPrivateDnsZone.id : managedPrivateDnsZoneResourceId
        }
      ]
    }
  }
}

module privateDnsZoneDeployment 'br/public:avm/res/network/private-dns-zone:0.7.1' = if (!useSharedPrivateDnsZones) {
  name: 'keyvault-private-dns-zone-deployment'
  params: {
    name: privateDnsZoneName
    location: 'global'
    tags: tags
    virtualNetworkLinks: [
      {
        name: '${keyVaultName}-vault-link'
        virtualNetworkResourceId: vnet.id
        registrationEnabled: false
        location: 'global'
        tags: tags
      }
    ]
  }
}

output privateDnsZoneResourceId string = useSharedPrivateDnsZones ? sharedPrivateDnsZone.id : managedPrivateDnsZoneResourceId
