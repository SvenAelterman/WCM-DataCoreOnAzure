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

param vnetAddressSpace string = '10.19.0.0/16'
param subnetAddressSpace string = '10.19.{octet3}.0/24'

// Optional parameters
param tags object = {}
param sequence int = 1
param namingConvention string = '{rtype}-{wloadname}-{subwloadname}-{env}-{loc}-{seq}'
param deploymentTime string = utcNow()
param avdVmHostNameStructure string = 'vm-avd'

// Variables
var sequenceFormatted = format('{0:00}', sequence)
var deploymentNameStructure = '${workloadName}-{rtype}-${deploymentTime}'

// Naming structure only needs the resource type ({rtype}) replaced
var namingStructure = replace(replace(replace(replace(namingConvention, '{env}', toLower(environment)), '{loc}', location), '{seq}', sequenceFormatted), '{wloadname}', workloadName)
var coreNamingStructure = replace(namingStructure, '{subwloadname}', 'core')
var avdNamingStructure = replace(namingStructure, '{subwloadname}', 'avd')

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

module rolesModule 'common-modules/roles.bicep' = {
  name: replace(deploymentNameStructure, '{rtype}', 'roles')
  scope: coreHubResourceGroup
}

module abbreviationsModule 'common-modules/abbreviations.bicep' = {
  name: replace(deploymentNameStructure, '{rtype}', 'abbrev')
  scope: coreHubResourceGroup
}

var vnetAbbrev = abbreviationsModule.outputs.abbreviations['Virtual Network']

module hubVnetModule 'modules/vnet.bicep' = {
  name: replace(deploymentNameStructure, '{rtype}', 'vnet-hub-core')
  scope: coreHubResourceGroup
  params: {
    vnetName: replace(coreNamingStructure, '{rtype}', vnetAbbrev)
    location: location
    addressPrefix: vnetAddressSpace
    subnetAddressPrefix: subnetAddressSpace
    tags: tags
  }
}

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
    avdSubnetId: hubVnetModule.outputs.avdSubnetId
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
