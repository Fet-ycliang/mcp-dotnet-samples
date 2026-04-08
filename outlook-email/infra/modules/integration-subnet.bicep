@description('Name of the existing virtual network to update.')
param vnetName string

@description('Name of the integration subnet to create or update. Must not contain underscores and must use Microsoft.App/environments delegation for Flex Consumption.')
param subnetName string

@description('Address prefix for the integration subnet, e.g. "10.0.2.0/24".')
param addressPrefix string

@description('Optional. Route table resource ID to attach to the subnet.')
param routeTableId string = ''

@description('Optional. Network security group resource ID to attach to the subnet.')
param nsgId string = ''

resource existingVNet 'Microsoft.Network/virtualNetworks@2024-05-01' existing = {
  name: vnetName
}

resource integrationSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = {
  name: subnetName
  parent: existingVNet
  properties: {
    addressPrefix: addressPrefix
    delegations: [
      {
        name: 'flexConsumptionDelegation'
        properties: {
          serviceName: 'Microsoft.App/environments'
        }
      }
    ]
    routeTable: !empty(routeTableId) ? {
      id: routeTableId
    } : null
    networkSecurityGroup: !empty(nsgId) ? {
      id: nsgId
    } : null
  }
}

output subnetResourceId string = integrationSubnet.id
