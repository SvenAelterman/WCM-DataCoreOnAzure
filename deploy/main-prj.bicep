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

param vnetOctet2Base int = 20
param vnetOctet2 int = vnetOctet2Base + sequence - 1

param vnetAddressSpace string = '10.${vnetOctet2}.0.0/16'
param subnetAddressSpace string = '10.${vnetOctet2}.{octet3}.0/24'

param hubSubscriptionId string
param hubWorkloadName string

// Optional parameters
param tags object = {}
param sequence int = 1
param hubSequence int = 1
// NOTE: Must be the same as the hub naming convention
param namingConvention string = '{rtype}-{wloadname}-{subwloadname}-{env}-{loc}-{seq}'
param deploymentTime string = utcNow()

// Variables
var sequenceFormatted = format('{0:00}', sequence)
var deploymentNameStructure = '${workloadName}-{rtype}-${deploymentTime}'

var storageAccountSubResourcePrivateEndpoints = [
  'blob'
  'file'
  'dfs'
]

// Naming structure only needs the resource type ({rtype}) replaced
var thisNamingStructure = replace(replace(replace(replace(namingConvention, '{env}', toLower(environment)), '{loc}', location), '{seq}', sequenceFormatted), '{wloadname}', workloadName)
var shortCoreNamingConvention = replace(namingConvention, '{subwloadname}', 'c')
var coreNamingStructure = replace(thisNamingStructure, '{subwloadname}', 'core')
var dataNamingStructure = replace(thisNamingStructure, '{subwloadname}', 'data')
var computeNamingStructure = replace(thisNamingStructure, '{subwloadname}', 'compute')

// Names of hub resources
var hubSequenceFormatted = format('{0:00}', hubSequence)
var hubCoreNamingStructure = replace(replace(replace(replace(replace(namingConvention, '{env}', toLower(environment)), '{loc}', location), '{seq}', hubSequenceFormatted), '{wloadname}', hubWorkloadName), '{subwloadname}', 'core')
var hubVNetName = replace(hubCoreNamingStructure, '{rtype}', 'vnet')

var containerNames = {
  exportApproved: 'export-approved'
  ingest: 'ingest'
  exportPending: 'export-pending'
  exportRequest: 'export-request'
}

resource corePrjResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: replace(coreNamingStructure, '{rtype}', 'rg')
  location: location
  tags: tags
}

resource dataPrjResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: replace(dataNamingStructure, '{rtype}', 'rg')
  location: location
  tags: tags
}

resource computeResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: replace(computeNamingStructure, '{rtype}', 'rg')
  location: location
  tags: tags
}

resource coreHubResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' existing = {
  name: replace(hubCoreNamingStructure, '{rtype}', 'rg')
  scope: subscription(hubSubscriptionId)
}

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2021-12-01-preview' existing = {
  name: replace(hubCoreNamingStructure, '{rtype}', 'log')
  scope: coreHubResourceGroup
}

resource hubVNet 'Microsoft.Network/virtualNetworks@2022-01-01' existing = {
  name: hubVNetName
  scope: coreHubResourceGroup
}

// TODO: Link with auto-registration Enabled to hub's 'research.aelterman.info' private DNS zone

// The existing Private DNS zones for the storage account sub-resources
resource privateDnsZones 'Microsoft.Network/privateDnsZones@2020-06-01' existing = [for subresource in storageAccountSubResourcePrivateEndpoints: {
  name: 'privatelink.${subresource}.${az.environment().suffixes.storage}'
  scope: coreHubResourceGroup
}]

module rolesModule 'common-modules/roles.bicep' = {
  name: replace(deploymentNameStructure, '{rtype}', 'roles')
  scope: corePrjResourceGroup
}

// Create a network security group for the default subnet
module defaultNsg 'modules/nsg-prj.bicep' = {
  name: replace(deploymentNameStructure, '{rtype}', 'nsg')
  scope: corePrjResourceGroup
  params: {
    location: location
    namingStructure: coreNamingStructure
    avdSubnetRange: hubVNet.properties.subnets[1].properties.addressPrefix
  }
}

var subnets = [
  {
    name: 'default'
    addressPrefix: replace(subnetAddressSpace, '{octet3}', '0')
    nsgId: defaultNsg.outputs.nsgId
  }
  {
    name: 'data'
    addressPrefix: replace(subnetAddressSpace, '{octet3}', '1')
    nsgId: ''
  }
]

// Create the research project's VNet
module vNetModule 'modules/vnet.bicep' = {
  name: replace(deploymentNameStructure, '{rtype}', 'vnet')
  scope: corePrjResourceGroup
  params: {
    location: location
    subnets: subnets
    vnetName: replace(coreNamingStructure, '{rtype}', 'vnet')
    addressPrefix: vnetAddressSpace
    tags: tags
  }
}

module privateDnsZoneVNetLinks 'modules/privateDnsZoneVNetLink.bicep' = [for (subresource, i) in storageAccountSubResourcePrivateEndpoints: {
  name: replace(deploymentNameStructure, '{rtype}', 'dns-link-${subresource}')
  scope: coreHubResourceGroup
  params: {
    dnsZoneName: privateDnsZones[i].name
    vnetId: vNetModule.outputs.vNetId
  }
}]

// Peer hub to spoke (this)
module hubPeeringModule 'modules/vnet-peering.bicep' = {
  name: replace(deploymentNameStructure, '{rtype}', 'peer-hub')
  scope: coreHubResourceGroup
  params: {
    localVNetName: hubVNetName
    localName: hubWorkloadName
    remoteName: '${workloadName}${sequenceFormatted}'
    // Remote is the spoke
    remoteVNetId: vNetModule.outputs.vNetId
    allowVirtualNetworkAccess: true
  }
}

// Peer spoke (this) to hub 
module spokePeeringModule 'modules/vnet-peering.bicep' = {
  name: replace(deploymentNameStructure, '{rtype}', 'peer-spoke')
  scope: corePrjResourceGroup
  dependsOn: [
    hubPeeringModule
  ]
  params: {
    // Local is the spoke
    localVNetName: vNetModule.outputs.vNetName
    localName: '${workloadName}${sequenceFormatted}'
    remoteName: hubWorkloadName
    remoteVNetId: resourceId(hubSubscriptionId, coreHubResourceGroup.name, 'Microsoft.Network/virtualNetworks', hubVNetName)
  }
}

module privateStorageAccountShortname 'common-modules/shortname.bicep' = {
  name: 'privateStorageAccountShortName'
  scope: corePrjResourceGroup
  params: {
    location: location
    sequence: sequence
    resourceType: 'st'
    workloadName: workloadName
    environment: environment
    namingConvention: shortCoreNamingConvention
    removeHyphens: true
  }
}

// Create the research project's primary private storage account
module privateStorageAccountModule 'modules/data/storage.bicep' = {
  name: replace(deploymentNameStructure, '{rtype}', 'data')
  scope: dataPrjResourceGroup
  params: {
    namingStructure: coreNamingStructure
    storageAccountName: privateStorageAccountShortname.outputs.shortName
    location: location
    privatize: true
    containerNames: [
      containerNames.exportRequest
    ]
    //vnetId: vNetModule.outputs.vNetId
    subnetId: vNetModule.outputs.subnetIds[1]
    tags: tags
    fileShareNames: [
      'shared'
    ]
    // privateEndpointSubResources: storageAccountSubResourcePrivateEndpoints
    // privateDnsZoneIds: {}
    privateEndpointInfo: [for (subresource, i) in storageAccountSubResourcePrivateEndpoints: {
      subResourceName: subresource
      dnsZoneId: privateDnsZones[i].id
      dnsZoneName: privateDnsZones[i].name
    }]
  }
}

// Create air lock/drawbridge for data move
module publicStorageAccountShortname 'common-modules/shortname.bicep' = {
  name: 'publicStorageAccountShortName'
  scope: corePrjResourceGroup
  params: {
    location: location
    sequence: sequence
    resourceType: 'st'
    workloadName: workloadName
    environment: environment
    namingConvention: replace(namingConvention, '{subwloadname}', 'd')
    removeHyphens: true
  }
}

module dataAutomationModule 'modules/data.bicep' = {
  name: replace(deploymentNameStructure, '{rtype}', 'data')
  params: {
    location: location
    namingStructure: dataNamingStructure
    publicStNamingStructure: replace(thisNamingStructure, '{subwloadname}', 'pub')
    workspaceName: '${workloadName}${sequenceFormatted}'
    roles: rolesModule.outputs.roles
    approverEmail: 'sven@aelterman.info'
    deploymentNameStructure: deploymentNameStructure
    privateStorageAccountRG: dataPrjResourceGroup.name
    privateStorageAccountName: privateStorageAccountModule.outputs.storageAccountName
    containerNames: containerNames
    tags: tags
    publicStorageAccountName: publicStorageAccountShortname.outputs.shortName
  }
}

// TODO: Permissions to log into VMs?
// TODO: VM to enroll with Intune?

output vnetAddressSpace array = vNetModule.outputs.vNetAddressSpace
output privateStorageAccountName string = privateStorageAccountShortname.outputs.shortName
output publicStorageAccountName string = publicStorageAccountShortname.outputs.shortName
output dataResourceGroupName string = dataPrjResourceGroup.name
