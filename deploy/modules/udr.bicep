param location string
param namingStructure string
param nvaIpAddress string

resource udr 'Microsoft.Network/routeTables@2022-01-01' = {
  name: replace(namingStructure, '{rtype}', 'udr')
  location: location
  properties: {
    disableBgpRoutePropagation: false
  }
}

resource routeToFw 'Microsoft.Network/routeTables/routes@2022-01-01' = {
  name: 'Internet-via-Firewall'
  parent: udr
  properties: {
    nextHopType: 'VirtualAppliance'
    nextHopIpAddress: nvaIpAddress
    addressPrefix: '0.0.0.0/0'
  }
}

resource routeToUpdateDelivery 'Microsoft.Network/routeTables/routes@2022-01-01' = {
  name: 'UpdateDelivery'
  parent: udr
  properties: {
    nextHopType: 'Internet'
    addressPrefix: 'AzureUpdateDelivery'
  }
}

resource routeToDefenderForCloud 'Microsoft.Network/routeTables/routes@2022-01-01' = {
  name: 'DefenderForCloud'
  parent: udr
  properties: {
    nextHopType: 'Internet'
    addressPrefix: 'AzureSecurityCenter'
  }
}

// resource routeToAVD 'Microsoft.Network/routeTables/routes@2022-01-01' = {
//   name: 'AzureVirtualDesktop'
//   parent: udr
//   properties: {
//     nextHopType: 'Internet'
//     addressPrefix: 'WindowsVirtualDesktop'
//   }
// }

output routeTableId string = udr.id
