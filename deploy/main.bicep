targetScope = 'subscription'

@allowed([
  'eastus2'
  'eastus'
])
param location string
@allowed([
  'test'
  'demo'
  'prod'
])
param environment string
param workloadName string

// Optional parameters
param tags object = {}
param sequence int = 1
param namingConvention string = '{rtype}-{wloadname}-{env}-{loc}-{seq}'
param deploymentTime string = utcNow()

// Variables
var sequenceFormatted = format('{0:00}', sequence)

// Naming structure only needs the resource type ({rtype}) replaced
var namingStructure = replace(replace(replace(replace(namingConvention, '{env}', environment), '{loc}', location), '{seq}', sequenceFormatted), '{wloadname}', workloadName)

resource hubResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: replace(namingStructure, '{rtype}', 'rg-hub')
  location: location
  tags: tags
}

module roles 'common-modules/roles.bicep' = {
  name: '${workloadName}-roles-${deploymentTime}'
  scope: hubResourceGroup
}

module abbreviations 'common-modules/abbreviations.bicep' = {
  name: '${workloadName}-abbrev-${deploymentTime}'
  scope: hubResourceGroup
}

// Add deployments here

module hubVnetModule 'modules/vnet.bicep' = {
  name: '$'
  scope: hubResourceGroup
  params: {
    vnetName: replace(namingConvention, '{rtype}', 'vnet')
  }
}

output namingStructure string = namingStructure
