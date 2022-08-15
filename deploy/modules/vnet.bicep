param vnetName string
param location string
param addressPrefix string
param subnetAddressPrefix string

param deploymentNameStructure string = '{rtype}-${utcNow()}'
param enableDdosProtection bool = false
param tags object = {}
param enableNetworkWatcher bool = false

// TODO: Extract from here
param subnets array = [
  {
    name: 'default'
    addressPrefix: replace(subnetAddressPrefix, '{octet3}', '0')
    nsgId: ''
  }
  {
    name: 'avd'
    addressPrefix: replace(subnetAddressPrefix, '{octet3}', '1')
    nsgId: ''
  }
]

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

// Output the resource ID of the AVD subnet to use later
// TODO: Remove this in favor of the array
output avdSubnetId string = vnet.properties.subnets[1].id
output vNetId string = vnet.id
output subnetIds array = [for (subnet, i) in subnets: vnet.properties.subnets[i].id]
output vNetName string = vnet.name
output vNetAddressSpace array = vnet.properties.addressSpace.addressPrefixes
