param environment string
param location string
param namingConvention string
param sequence int
param workloadName string
param deploymentNameStructure string
param airlockNamingStructure string
param dataSubnetId string
param privateDnsZones array

param storageAccountSubResourcePrivateEndpoints array = [
  'blob'
  'file'
  'dfs' ]

// Create name for the storage account used to hold data while being reviewed
module reviewStorageAccountName '../common-modules/shortname.bicep' = {
  name: replace(deploymentNameStructure, '{rtype}', 'stname')
  params: {
    environment: environment
    location: location
    namingConvention: replace(namingConvention, '{subwloadname}', 'd')
    resourceType: 'st'
    sequence: sequence
    workloadName: workloadName
    removeHyphens: true
  }
}

module reviewStorageModule 'data/storage.bicep' = {
  name: replace(deploymentNameStructure, '{rtype}', 'st')
  params: {
    containerNames: [
      // TODO: no hardcoding names here
      'export-requested'
      'export-approved'
    ]
    fileShareNames: [
      'export-pendingreview'
    ]
    location: location
    namingStructure: airlockNamingStructure
    privatize: true
    storageAccountName: reviewStorageAccountName.outputs.shortName
    subnetId: dataSubnetId
    subwloadname: 'data'
    privateEndpointInfo: [for (subresource, i) in storageAccountSubResourcePrivateEndpoints: {
      subResourceName: subresource
      dnsZoneId: privateDnsZones[i].zoneId
      dnsZoneName: privateDnsZones[i].zoneName
    }]
  }
}
