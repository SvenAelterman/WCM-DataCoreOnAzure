param vnetName string
param location string
param addressPrefix string
param subnets array

param deploymentNameStructure string = '{rtype}-${utcNow()}'
param enableDdosProtection bool = false
param tags object = {}
param enableNetworkWatcher bool = false

resource vnet 'Microsoft.Network/virtualNetworks@2021-05-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressPrefix
      ]
    }
    enableDdosProtection: enableDdosProtection
    subnets: [for subnet in subnets: {
      name: subnet.name
      properties: {
        addressPrefix: subnet.addressPrefix
        networkSecurityGroup: empty(subnet.nsgId) ? null : {
          id: subnet.nsgId
        }
        routeTable: empty(subnet.routeTableId) ? null : {
          id: subnet.routeTableId
        }
      }
    }]
  }
}

module networkWatcher 'networkWatcherRG.bicep' = if (enableNetworkWatcher) {
  name: replace(deploymentNameStructure, '{rtype}', 'networkWatcherRG')
  scope: subscription()
  params: {
    location: location
    tags: tags
    deploymentNameStructure: deploymentNameStructure
  }
}

// Get the subnets' IDs in the same order as in the parameter array
// The value of vnet.subnets might be out of order
resource subnetRes 'Microsoft.Network/virtualNetworks/subnets@2022-01-01' existing = [for subnet in subnets: {
  name: subnet.name
  parent: vnet
}]

output vNetId string = vnet.id
// Ensure the subnet IDs are output in the same order as they were provided
// See https://github.com/Azure/bicep/discussions/4953 for background on this technique
output subnetIds array = [for (subnet, i) in subnets: subnetRes[i].id]
output vNetName string = vnet.name
output vNetAddressSpace array = vnet.properties.addressSpace.addressPrefixes
