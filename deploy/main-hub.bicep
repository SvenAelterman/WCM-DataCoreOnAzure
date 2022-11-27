targetScope = 'subscription'

@allowed([
  'eastus2'
  'eastus'
])
param location string
@allowed([
  'Test'
  'Demo'
  'Prod'
])
param environment string
param workloadName string

// TODO: Create private DNS zone with this name
#disable-next-line no-unused-params
param computeDnsSuffix string

param vnetAddressSpace string = '10.19.0.0/16'
param subnetAddressSpace string = '10.19.{octet3}.0/24'

// Optional parameters
param tags object = {}
param sequence int = 1
param namingConvention string = '{rtype}-{wloadname}-{subwloadname}-{env}-{loc}-{seq}'
param deploymentTime string = utcNow()
param avdVmHostNameStructure string = 'vm-avd'
param deployBastionHost bool = true

// Variables
var sequenceFormatted = format('{0:00}', sequence)
var deploymentNameStructure = '${workloadName}-{rtype}-${deploymentTime}'

var storageAccountSubResourcePrivateEndpoints = [
  'blob'
  'file'
  'dfs'
]

// Naming structure only needs the resource type ({rtype}) replaced
var namingStructure = replace(replace(replace(replace(namingConvention, '{env}', toLower(environment)), '{loc}', location), '{seq}', sequenceFormatted), '{wloadname}', workloadName)
var coreNamingStructure = replace(namingStructure, '{subwloadname}', 'core')
var avdNamingStructure = replace(namingStructure, '{subwloadname}', 'avd')
var airlockNamingStructure = replace(namingStructure, '{subwloadname}', 'airlock')

resource coreHubResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: replace(coreNamingStructure, '{rtype}', 'rg')
  location: location
  tags: tags
}

resource avdHubResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: replace(avdNamingStructure, '{rtype}', 'rg')
  location: location
  tags: tags
}

// Contains the storage account for reviewing export requests
resource airlockHubResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: replace(airlockNamingStructure, '{rtype}', 'rg')
  location: location
  tags: tags
}

module rolesModule 'common-modules/roles.bicep' = {
  name: replace(deploymentNameStructure, '{rtype}', 'roles')
  scope: coreHubResourceGroup
}

module abbreviationsModule 'common-modules/abbreviations.bicep' = {
  name: replace(deploymentNameStructure, '{rtype}', 'abbrev')
  scope: coreHubResourceGroup
}

var vnetAbbrev = abbreviationsModule.outputs.abbreviations['Virtual Network']

var hubVNetSubnets = [
  {
    name: 'default'
    addressPrefix: replace(subnetAddressSpace, '{octet3}', '0')
    nsgId: ''
    routeTableId: ''
  }
  {
    name: 'avd'
    addressPrefix: replace(subnetAddressSpace, '{octet3}', '1')
    nsgId: ''
    routeTableId: ''
  }
  {
    name: 'data'
    addressPrefix: replace(subnetAddressSpace, '{octet3}', '2')
    nsgId: ''
    routeTableId: ''
  }
  {
    name: 'AzureFirewallSubnet'
    addressPrefix: replace(subnetAddressSpace, '{octet3}', '254')
    nsgId: ''
    routeTableId: ''
  }
  {
    name: 'AzureFirewallManagementSubnet'
    addressPrefix: replace(subnetAddressSpace, '{octet3}', '253')
    nsgId: ''
    routeTableId: ''
  }
  {
    name: 'AzureBastionSubnet'
    addressPrefix: replace(subnetAddressSpace, '{octet3}', '252')
    nsgId: ''
    routeTableId: ''
  }
]

module hubVnetModule 'modules/vnet.bicep' = {
  name: replace(deploymentNameStructure, '{rtype}', 'vnet-hub-core')
  scope: coreHubResourceGroup
  params: {
    vnetName: replace(coreNamingStructure, '{rtype}', vnetAbbrev)
    location: location
    addressPrefix: vnetAddressSpace
    tags: tags
    subnets: hubVNetSubnets
  }
}

module privateDnsZones 'modules/privateDnsZone.bicep' = [for subresource in storageAccountSubResourcePrivateEndpoints: {
  name: replace(deploymentNameStructure, '{rtype}', 'dns-${subresource}')
  scope: coreHubResourceGroup
  params: {
    zoneName: 'privatelink.${subresource}.${az.environment().suffixes.storage}'
  }
}]

module privateDnsZoneVNetLinks 'modules/privateDnsZoneVNetLink.bicep' = [for (subresource, i) in storageAccountSubResourcePrivateEndpoints: {
  name: replace(deploymentNameStructure, '{rtype}', 'dns-link-${subresource}')
  scope: coreHubResourceGroup
  params: {
    dnsZoneName: privateDnsZones[i].outputs.zoneName
    vnetId: hubVnetModule.outputs.vNetId
    registrationEnabled: false
  }
  dependsOn: [
    privateDnsZones[i]
  ]
}]

module logModule 'modules/log.bicep' = {
  name: replace(deploymentNameStructure, '{rtype}', 'log')
  scope: coreHubResourceGroup
  params: {
    location: location
    namingStructure: coreNamingStructure
    abbreviations: abbreviationsModule.outputs.abbreviations
  }
}

module hubAvdModule 'modules/avd.bicep' = {
  name: replace(deploymentNameStructure, '{rtype}', 'avd')
  dependsOn: [
    hubVnetModule
  ]
  scope: avdHubResourceGroup
  params: {
    namingStructure: namingStructure
    location: location
    tags: tags
    abbreviations: abbreviationsModule.outputs.abbreviations
    deploymentNameStructure: deploymentNameStructure
    avdVmHostNameStructure: avdVmHostNameStructure
    avdSubnetId: hubVnetModule.outputs.subnetIds[1]
    environment: environment
  }
}

module computeGalleryModule 'modules/gal.bicep' = {
  name: replace(deploymentNameStructure, '{rtype}', 'gal')
  scope: coreHubResourceGroup
  params: {
    location: location
    namingStructure: coreNamingStructure
    abbreviations: abbreviationsModule.outputs.abbreviations
    tags: tags
  }
}

module airlockModule 'modules/airlock.bicep' = {
  name: replace(deploymentNameStructure, '{rtype}', 'airlock')
  scope: airlockHubResourceGroup
  params: {
    location: location
    environment: environment
    deploymentNameStructure: deploymentNameStructure
    namingConvention: namingConvention
    workloadName: workloadName
    airlockNamingStructure: airlockNamingStructure
    sequence: sequence
    storageAccountSubResourcePrivateEndpoints: storageAccountSubResourcePrivateEndpoints
    dataSubnetId: hubVnetModule.outputs.subnetIds[2]
    privateDnsZones: [for (subresource, i) in storageAccountSubResourcePrivateEndpoints: {
      zoneId: privateDnsZones[i].outputs.zoneId
      zoneName: privateDnsZones[i].outputs.zoneName
    }]
  }
}

module bastionModule 'modules/bastion.bicep' = if (deployBastionHost) {
  name: replace(deploymentNameStructure, '{rtype}', 'bas')
  scope: coreHubResourceGroup
  params: {
    namingStructure: coreNamingStructure
    location: location
    bastionSubnetId: hubVnetModule.outputs.subnetIds[5]
    tags: tags
  }
}

module azureFirewallModule 'modules/azfw.bicep' = {
  name: replace(deploymentNameStructure, '{rtype}', 'fw')
  scope: coreHubResourceGroup
  params: {
    firewallSubnetId: hubVnetModule.outputs.subnetIds[3]
    fwManagementSubnetId: hubVnetModule.outputs.subnetIds[4]
    location: location
    namingStructure: coreNamingStructure
    tags: tags
  }
}

output privateDnsZoneIds array = [for (subresource, i) in storageAccountSubResourcePrivateEndpoints: privateDnsZones[i].outputs.zoneId]
