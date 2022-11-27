param environment string
param location string
param namingConvention string
param sequence int
param sequenceFormatted string
param workloadName string
param deploymentNameStructure string
param airlockNamingStructure string
param dataSubnetId string
param privateDnsZones array
@secure()
param vmLocalAdminPassword string
param vmSubnetName string
param vmVnetId string

param storageAccountSubResourcePrivateEndpoints array = [
  'blob'
  'file'
  'dfs' ]

param tags object = {}

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
    tags: tags
  }
}

module airlockVmModule 'vm-research.bicep' = {
  name: replace(deploymentNameStructure, '{rtype}', 'airlockvm')
  params: {
    location: location
    adminPassword: vmLocalAdminPassword
    adminUsername: 'AzureUser'
    subnetName: vmSubnetName
    virtualMachineName: 'hub-airlock${sequenceFormatted}'
    virtualNetworkId: vmVnetId
    tags: tags
  }
}

// TODO: Deploy RBAC to allow admins to sign into airlock VM

output vmName string = airlockVmModule.outputs.vmName
