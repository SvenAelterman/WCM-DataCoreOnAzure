param vnetName string
param location string
param addressPrefix string
param subnetAddressPrefix string

param deploymentNameStructure string = '{rtype}-${utcNow()}'
param enableDdosProtection bool = false
param tags object = {}
param enableNetworkWatcher bool = false

// Define the subnets needed
var subnets = [
  {
    name: 'default'
    addressPrefix: replace(subnetAddressPrefix, '{octet3}', '0')
  }
  {
    name: 'avd'
    addressPrefix: replace(subnetAddressPrefix, '{octet3}', '1')
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
output avdSubnetId string = vnet.properties.subnets[1].id
