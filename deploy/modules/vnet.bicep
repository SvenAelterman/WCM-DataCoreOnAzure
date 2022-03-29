param vnetName string
param location string
param addressPrefix string
param subnetAddressPrefix string

param deploymentNameStructure string = '{rtype}-${utcNow()}'
param enableDdosProtection bool = false
param tags object = {}
param enableNetworkWatcher bool = true

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
  }
}

module defaultSubnet 'vnet-subnet.bicep' = {
  name: replace(deploymentNameStructure, '{rtype}', 'vnet-subnet-default')
  params: {
    vnetName: vnet.name
    subnetName: 'default'
    subnetAddressPrefix: subnetAddressPrefix
  }
}

module networkWatcher 'networkWatcherRG.bicep' = if (enableNetworkWatcher) {
  name: replace(deploymentNameStructure, '{rtype}', 'networkWatcherRG')
  scope: subscription()
  params: {
    location: location
    tags: tags
  }
}
