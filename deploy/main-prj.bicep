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

param vnetAddressSpace string = '10.20.0.0/16'
param subnetAddressSpace string = '10.20.{octet3}.0/24'

param hubSubscriptionId string
param hubWorkloadName string

// Optional parameters
param tags object = {}
param sequence int = 1
// NOTE: Must be the same as the hub naming convention
param namingConvention string = '{rtype}-{wloadname}-{subwloadname}-{env}-{loc}-{seq}'
param deploymentTime string = utcNow()

// Variables
var sequenceFormatted = format('{0:00}', sequence)
var deploymentNameStructure = '${workloadName}-{rtype}-${deploymentTime}'

// Naming structure only needs the resource type ({rtype}) replaced
var namingStructure = replace(replace(replace(replace(namingConvention, '{env}', toLower(environment)), '{loc}', location), '{seq}', sequenceFormatted), '{wloadname}', workloadName)
var coreNamingStructure = replace(namingStructure, '{subwloadname}', 'core')
var dataNamingStructure = replace(namingStructure, '{subwloadname}', 'data')
var computeNamingStructure = replace(namingStructure, '{subwloadname}', 'compute')

// Names of hub resources
var hubCoreNamingStructure = replace(replace(replace(replace(replace(namingConvention, '{env}', toLower(environment)), '{loc}', location), '{seq}', sequenceFormatted), '{wloadname}', hubWorkloadName), '{subwloadname}', 'core')
var hubVNetName = replace(hubCoreNamingStructure, '{rtype}', 'vnet')

var containerNames = {
  'exportApprovedContainerName': 'export-approved'
  'ingestContainerName': 'ingest'
  'exportPendingContainerName': 'export-pending'
}

var subnets = [
  {
    name: 'default'
    addressPrefix: replace(subnetAddressSpace, '{octet3}', '0')
  }
  {
    name: 'data'
    addressPrefix: replace(subnetAddressSpace, '{octet3}', '1')
  }
]

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

module rolesModule 'common-modules/roles.bicep' = {
  name: replace(deploymentNameStructure, '{rtype}', 'roles')
  scope: corePrjResourceGroup
}

// Create the research project's VNet
module vNetModule 'modules/vnet.bicep' = {
  name: replace(deploymentNameStructure, '{rtype}', 'vnet')
  scope: corePrjResourceGroup
  params: {
    location: location
    subnetAddressPrefix: subnetAddressSpace
    subnets: subnets
    vnetName: replace(coreNamingStructure, '{rtype}', 'vnet')
    addressPrefix: vnetAddressSpace
    tags: tags
  }
}

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

// Create the research project's storage account
module privateStorageAccountModule 'modules/data/storage.bicep' = {
  name: replace(deploymentNameStructure, '{rtype}', 'data')
  scope: dataPrjResourceGroup
  params: {
    location: location
    privatize: true
    namingStructure: dataNamingStructure
    containerNames: [
      containerNames['exportApprovedContainerName']
      containerNames['exportPendingContainerName']
    ]
    vnetId: vNetModule.outputs.vNetId
    subnetId: vNetModule.outputs.subnetIds[1]
    tags: tags
  }
}

// Create air lock/drawbridge for data move
module dataAutomationModule 'modules/data.bicep' = {
  name: replace(deploymentNameStructure, '{rtype}', 'data')
  params: {
    location: location
    namingStructure: dataNamingStructure
    publicStNamingStructure: replace(namingStructure, '{subwloadname}', 'pub')
    workspaceName: '${workloadName}${sequenceFormatted}'
    roles: rolesModule.outputs.roles
    approverEmail: 'sven@aelterman.info'
    deploymentNameStructure: deploymentNameStructure
    privateStorageAccountRG: dataPrjResourceGroup.name
    privateStorageAccountName: privateStorageAccountModule.outputs.storageAccountName
    containerNames: containerNames
    tags: tags
  }
}

// TODO: Permissions to log into VMs?
// TODO: VM to enroll with Intune?
