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
@secure()
param airlockVmLocalAdminPassword string

// Create private DNS zone with this name
param computeDnsSuffix string

// The AAD Object IDs of the user groups representing the different roles of the data core
// Required to complete role assignments
param aadSysAdminGroupObjectId string
param aadDataAdminGroupObjectId string

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

// REFERENCE MODULES
module rolesModule 'common-modules/roles.bicep' = {
  name: replace(deploymentNameStructure, '{rtype}', 'roles')
  scope: coreHubResourceGroup
}

module abbreviationsModule 'common-modules/abbreviations.bicep' = {
  name: replace(deploymentNameStructure, '{rtype}', 'abbrev')
  scope: coreHubResourceGroup
}
// END REFERENCE MODULES

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

// Enable sysadmins to log on to all VMs in the subscription
resource subscriptionLoginRbac 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(aadDataAdminGroupObjectId, subscription().id, '1c0163c0-47e6-4577-8991-ea5c82e286e4')
  properties: {
    principalId: aadSysAdminGroupObjectId
    roleDefinitionId: rolesModule.outputs.roles['Virtual Machine Administrator Login']
    principalType: 'Group'
    description: 'Enables Data Core Sysadmins to log in as administrators to all VMs in the subscription.'
  }
}

// Enable data admins to log on to Airlock VMs
module airlockLoginRbacModule 'modules/resourceGroupRbac.bicep' = {
  name: replace(deploymentNameStructure, '{rtype}', 'rbac-airlock-login')
  scope: airlockHubResourceGroup
  params: {
    principalId: aadDataAdminGroupObjectId
    principalType: 'Group'
    roleDefinitionId: rolesModule.outputs.roles['Virtual Machine User Login']
  }
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
    name: 'airlock-compute'
    addressPrefix: replace(subnetAddressSpace, '{octet3}', '3')
    // TODO: Apply NSG, route table to airlock-compute subnet?
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

module storagePrivateDnsZonesModule 'modules/privateDnsZone.bicep' = [for subresource in storageAccountSubResourcePrivateEndpoints: {
  name: replace(deploymentNameStructure, '{rtype}', 'dns-${subresource}')
  scope: coreHubResourceGroup
  params: {
    zoneName: 'privatelink.${subresource}.${az.environment().suffixes.storage}'
  }
}]

module storagePrivateDnsZoneVNetLinksModule 'modules/privateDnsZoneVNetLink.bicep' = [for (subresource, i) in storageAccountSubResourcePrivateEndpoints: {
  name: replace(deploymentNameStructure, '{rtype}', 'dns-link-${subresource}')
  scope: coreHubResourceGroup
  params: {
    dnsZoneName: storagePrivateDnsZonesModule[i].outputs.zoneName
    vnetId: hubVnetModule.outputs.vNetId
    registrationEnabled: false
  }
  dependsOn: [
    storagePrivateDnsZonesModule[i]
  ]
}]

module computePrivateDnsZoneModule 'modules/privateDnsZone.bicep' = {
  name: replace(deploymentNameStructure, '{rtype}', 'dns-compute')
  scope: coreHubResourceGroup
  params: {
    zoneName: computeDnsSuffix
  }
}

module computePrivateDnsZoneVNetLinkModule 'modules/privateDnsZoneVNetLink.bicep' = {
  name: replace(deploymentNameStructure, '{rtype}', 'dns-link-compute')
  scope: coreHubResourceGroup
  params: {
    dnsZoneName: computePrivateDnsZoneModule.outputs.zoneName
    vnetId: hubVnetModule.outputs.vNetId
    registrationEnabled: true
  }
  dependsOn: [
    computePrivateDnsZoneModule
  ]
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
      zoneId: storagePrivateDnsZonesModule[i].outputs.zoneId
      zoneName: storagePrivateDnsZonesModule[i].outputs.zoneName
    }]
    vmLocalAdminPassword: airlockVmLocalAdminPassword
    sequenceFormatted: sequenceFormatted
    vmSubnetName: hubVNetSubnets[3].name
    vmVnetId: hubVnetModule.outputs.vNetId
    tags: tags
  }
}

module bastionModule 'modules/bastion.bicep' = if (deployBastionHost) {
  name: replace(deploymentNameStructure, '{rtype}', 'bas')
  scope: coreHubResourceGroup
  params: {
    namingStructure: coreNamingStructure
    location: location
    bastionSubnetId: hubVnetModule.outputs.subnetIds[6]
    tags: tags
  }
}

module azureFirewallModule 'modules/azfw.bicep' = {
  name: replace(deploymentNameStructure, '{rtype}', 'fw')
  scope: coreHubResourceGroup
  params: {
    firewallSubnetId: hubVnetModule.outputs.subnetIds[4]
    fwManagementSubnetId: hubVnetModule.outputs.subnetIds[5]
    location: location
    namingStructure: coreNamingStructure
    tags: tags
  }
}

output privateDnsZoneIds array = [for (subresource, i) in storageAccountSubResourcePrivateEndpoints: storagePrivateDnsZonesModule[i].outputs.zoneId]
output airlockVmName string = airlockModule.outputs.vmName
output airlockStorageAccountName string = airlockModule.outputs.storageAccountName
output airlockResourceGroupName string = airlockHubResourceGroup.name
