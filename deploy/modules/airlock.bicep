param environment string
param location string
param namingConvention string
param sequence int
param workloadName string
param deploymentNameStructure string
param airlockNamingStructure string
param dataSubnetId string
param privateDnsZones array

// We only need a file share
param storageAccountSubResourcePrivateEndpoints array

param tags object = {}

// Create name for the storage account used to hold data while being reviewed
module airlockStorageAccountNameModule '../common-modules/shortname.bicep' = {
  name: replace(deploymentNameStructure, '{rtype}', 'stname')
  params: {
    environment: environment
    location: location
    // TODO: Do not hardcode short value of airlock subworkloadname
    namingConvention: replace(namingConvention, '{subwloadname}', 'a')
    resourceType: 'st'
    sequence: sequence
    // TODO: Use short name of workload?
    workloadName: workloadName
    removeHyphens: true
  }
}

module airlockStorageModule 'data/storage.bicep' = {
  name: replace(deploymentNameStructure, '{rtype}', 'st')
  params: {
    containerNames: []
    fileShareNames: [
      'export-pendingreview'
    ]
    location: location
    namingStructure: airlockNamingStructure
    privatize: true
    storageAccountName: airlockStorageAccountNameModule.outputs.shortName
    subnetId: dataSubnetId
    subwloadname: 'data'
    privateEndpointInfo: [for (subresource, i) in storageAccountSubResourcePrivateEndpoints: {
      subResourceName: subresource
      dnsZoneId: privateDnsZones[i].zoneId
      dnsZoneName: privateDnsZones[i].zoneName
    }]
    tags: union(tags, { 'hidden-title': 'Airlock Storage Account' })
  }
}

// TODO: Create entry in hub Key Vault for connection string

// TODO: Deploy RBAC for storage account (data admins)

output storageAccountName string = airlockStorageModule.outputs.storageAccountName
