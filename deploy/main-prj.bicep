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
@maxLength(10)
param shortWorkloadName string = take(replace(replace(replace(replace(replace(workloadName, 'a', ''), 'e', ''), 'i', ''), 'o', ''), 'u', ''), 10)
param computeDnsSuffix string
param dataExportApproverEmail string

@description('Single project membership AAD group object ID.')
param projectMemberAadGroupObjectId string
@description('Array of objects containing individual user object IDs and UPNs. Schema: { upn: string, objectId: string }')
param projectMemberObjectIds array

param publicStorageAccountAllowedIPs array = []

// Provide reasonable defaults for octet 2 of the VNet address space.
// If the address space parameters are specified, this won't be used.
param vnetOctet2Base int = 20
param vnetOctet2 int = vnetOctet2Base + sequence - 1

param vnetAddressSpace string = '10.${vnetOctet2}.0.0/16'
// {octet3} is a placeholder that will be determined by the subnet deployments
param subnetAddressSpace string = '10.${vnetOctet2}.{octet3}.0/24'

param hubSubscriptionId string
param hubWorkloadName string
// Default the short workload name (for name of KV): remove all vowels
@maxLength(10)
param shortHubWorkloadName string = take(replace(replace(replace(replace(replace(hubWorkloadName, 'a', ''), 'e', ''), 'i', ''), 'o', ''), 'u', ''), 10)

// LATER: Deploy research VM in this spoke if true
#disable-next-line no-unused-params
param deployResearchVm bool = false

// Optional parameters
param tags object = {}
param sequence int = 1
param hubSequence int = 1
// NOTE: Must be the same as the hub naming convention
param namingConvention string = '{rtype}-{wloadname}-{subwloadname}-{env}-{loc}-{seq}'
param hubNamingConvention string = namingConvention
param deploymentTime string = utcNow()

// Variables
var sequenceFormatted = format('{0:00}', sequence)
var deploymentNameStructure = '${workloadName}-${toLower(environment)}-{rtype}-${deploymentTime}'

var storageAccountSubResourcePrivateEndpoints = [
  'blob'
  'file'
  'dfs'
]

var subWorkloadNames = {
  core: 'core'
  data: 'data'
  compute: 'compute'
  hubAirlock: 'airlock'
  hubCore: 'core'
}

// shortCoreNamingConvention is used by the shortname modules for key vault 
// LATER: Storage account names should use short naming convention
var shortCoreNamingConvention = replace(namingConvention, '{subwloadname}', take(subWorkloadNames.core, 1))

// Naming structure only needs the resource type ({rtype}) replaced
var thisNamingStructure = replace(replace(replace(replace(namingConvention, '{env}', toLower(environment)), '{loc}', location), '{seq}', sequenceFormatted), '{wloadname}', workloadName)
var coreNamingStructure = replace(thisNamingStructure, '{subwloadname}', subWorkloadNames.core)
var dataNamingStructure = replace(thisNamingStructure, '{subwloadname}', subWorkloadNames.data)
var computeNamingStructure = replace(thisNamingStructure, '{subwloadname}', subWorkloadNames.compute)

// Names of hub resources [The hub is deployed from main-hub.bicep before deploying project resources.]
var hubSequenceFormatted = format('{0:00}', hubSequence)
var hubCoreNamingStructure = replace(replace(replace(replace(replace(namingConvention, '{env}', toLower(environment)), '{loc}', location), '{seq}', hubSequenceFormatted), '{wloadname}', hubWorkloadName), '{subwloadname}', 'core')
var hubAirlockNamingStructure = replace(replace(replace(replace(replace(namingConvention, '{env}', toLower(environment)), '{loc}', location), '{seq}', hubSequenceFormatted), '{wloadname}', hubWorkloadName), '{subwloadname}', 'airlock')
var hubVNetName = replace(hubCoreNamingStructure, '{rtype}', 'vnet')
var hubFwName = replace(hubCoreNamingStructure, '{rtype}', 'fw')

// TODO: Load from JSON to share with hub
var containerNames = {
  // In the public storage account
  exportApproved: 'export-approved'
  ingest: 'ingest'
  //exportPending: 'export-pending'
  // In the private storage account
  exportRequest: 'export-request'
}

var fileShareNames = {
  projectShared: 'shared'
  projectIncoming: 'incoming'
  projectPersonalPrefix: 'personal-'
  airlock: 'export-pendingreview'
}

// Define three resource groups for the project's Azure resources
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

// Get a reference to the hub's core resource group
resource coreHubResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' existing = {
  name: replace(hubCoreNamingStructure, '{rtype}', 'rg')
  scope: subscription(hubSubscriptionId)
}

// The Log Analytics Workspace in the hub should exist.
// Sending data to the workspace should be done with Azure Policy, so we're not explicitly using it.
#disable-next-line no-unused-existing-resources
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2021-12-01-preview' existing = {
  name: replace(hubCoreNamingStructure, '{rtype}', 'log')
  scope: coreHubResourceGroup
}

resource hubVNet 'Microsoft.Network/virtualNetworks@2022-01-01' existing = {
  name: hubVNetName
  scope: coreHubResourceGroup
}

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

// Refererence to the existing hub firewall
resource firewall 'Microsoft.Network/azureFirewalls@2022-01-01' existing = {
  name: hubFwName
  scope: coreHubResourceGroup
}

// Create a route table to tunnel Internet traffic to the hub FW.
// Some traffic is allowed to bypass the hub FW.
module udrModule 'modules/udr.bicep' = {
  name: replace(deploymentNameStructure, '{rtype}', 'udr')
  scope: corePrjResourceGroup
  params: {
    location: location
    namingStructure: coreNamingStructure
    nvaIpAddress: firewall.properties.ipConfigurations[0].properties.privateIPAddress
  }
}

// Defining the virtual network subnets for the research project's VNet
var subnets = [
  {
    // LATER: Consider renaming to 'compute'
    name: 'default'
    addressPrefix: replace(subnetAddressSpace, '{octet3}', '0')
    nsgId: defaultNsg.outputs.nsgId
    routeTableId: udrModule.outputs.routeTableId
  }
  {
    name: 'data'
    addressPrefix: replace(subnetAddressSpace, '{octet3}', '1')
    nsgId: ''
    routeTableId: ''
  }
]

// Create the research project's VNet
// Use the subnets output
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
    vNetId: vNetModule.outputs.vNetId
    registrationEnabled: false
  }
}]

// Peer hub to spoke (the project's VNet (created by this module) is the spoke)
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

// Create a name that is compatible with the storage account name conventions
// for the project's private storage account
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

var peInfo = [for (subresource, i) in storageAccountSubResourcePrivateEndpoints: {
  subResourceName: subresource
  dnsZoneId: privateDnsZones[i].id
  dnsZoneName: privateDnsZones[i].name
}]

// Create file share names for the personal file shares: append the UPN while replacing invalid file share name characters
var personalFileShares = [for member in projectMemberObjectIds: {
  upn: member.upn
  objectId: member.objectId
  fileShareName: toLower('${fileShareNames.projectPersonalPrefix}${replace(replace(member.upn, '@', '-'), '.', '-')}')
}]

var personalFileShareNames = map(personalFileShares, pfs => pfs.fileShareName)

var projectFileShareNames = [
  fileShareNames.projectShared
  fileShareNames.projectIncoming
]

var actualProjectFileShareNames = concat(personalFileShareNames, projectFileShareNames)

// Create the research project's primary private storage account
module privateStorageAccountModule 'modules/data/storage.bicep' = {
  name: replace(deploymentNameStructure, '{rtype}', 'st')
  scope: dataPrjResourceGroup
  params: {
    namingStructure: coreNamingStructure
    storageAccountName: privateStorageAccountShortname.outputs.shortName
    location: location
    privatize: true
    containerNames: [
      containerNames.exportRequest
    ]
    subnetId: vNetModule.outputs.subnetIds[1]
    tags: tags
    fileShareNames: actualProjectFileShareNames
    privateEndpointInfo: peInfo

    // Use the module to assign permissions to the blob storage
    principalIds: [ projectMemberAadGroupObjectId ]
  }
}

// TODO: Assign permissions to the file shares to specified group object IDs

// Key Vault is required for the data automation module.
// First, create a name for the Key Vault
module keyVaultShortNameModule 'common-modules/shortname.bicep' = {
  name: 'keyVaultShortName'
  scope: corePrjResourceGroup
  params: {
    location: location
    environment: environment
    namingConvention: shortCoreNamingConvention
    resourceType: 'kv'
    sequence: sequence
    workloadName: shortWorkloadName
  }
}

// Then, create the Key Vault resource
module keyVaultModule 'modules/keyVault.bicep' = {
  name: replace(deploymentNameStructure, '{rtype}', 'kv')
  scope: corePrjResourceGroup
  params: {
    keyVaultName: keyVaultShortNameModule.outputs.shortName
    location: location
    tags: tags
  }
}

// Default to using storage account access key 1 for ADF
var whichKey = 1

// Store storage account key 1 in Key Vault Secret to be used by ADF
module privateStorageAccountConnStringSecretModule 'modules/keyVault-StorageAccountConnString.bicep' = {
  name: replace(deploymentNameStructure, '{rtype}', 'kv-connstring1')
  params: {
    keyVaultName: keyVaultModule.outputs.keyVaultName
    keyVaultResourceGroupName: corePrjResourceGroup.name
    storageAccountName: privateStorageAccountModule.outputs.storageAccountName
    storageAccountResourceGroupName: dataPrjResourceGroup.name
    whichKey: whichKey
  }
}

// Create air lock/drawbridge for data move (dataAutomationModule)
// First, create a name for the public storage account which will be created by the dataAutomationModule
module publicStorageAccountShortname 'common-modules/shortname.bicep' = {
  name: 'publicStorageAccountShortName'
  // The public storage account will be created in the data resource group
  // But where we generate the name doesn't matter
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

// Reference the existing hub's airlock resource group
resource airlockRg 'Microsoft.Resources/resourceGroups@2021-04-01' existing = {
  name: replace(hubAirlockNamingStructure, '{rtype}', 'rg')
  scope: subscription(hubSubscriptionId)
}

// Recreate the name of the hub's airlock storage account
// LATER: Have as parameter for input instead of recreating?
module airlockStorageAccountNameModule 'common-modules/shortname.bicep' = {
  name: replace(deploymentNameStructure, '{rtype}', 'stname')
  scope: airlockRg
  params: {
    environment: environment
    location: location
    //namingConvention: replace(namingConvention, '{subwloadname}', 'a')
    namingConvention: replace(namingConvention, '{subwloadname}', take(subWorkloadNames.hubAirlock, 1))
    resourceType: 'st'
    sequence: sequence
    workloadName: hubWorkloadName
    removeHyphens: true
  }
}

// Get the name of the hub's Key Vault
module hubKeyVaultShortNameModule 'common-modules/shortname.bicep' = {
  name: replace(deploymentNameStructure, '{rtype}', 'kv-shortname')
  scope: coreHubResourceGroup
  params: {
    location: location
    environment: environment
    namingConvention: replace(hubNamingConvention, '{subwloadname}', take(subWorkloadNames.hubCore, 1))
    resourceType: 'kv'
    sequence: hubSequence
    workloadName: shortHubWorkloadName
  }
}

// Deploy the data movement automation (ADF, logic app, etc.)
module dataAutomationModule 'modules/data.bicep' = {
  name: replace(deploymentNameStructure, '{rtype}', 'data')
  scope: dataPrjResourceGroup
  params: {
    location: location
    namingStructure: dataNamingStructure
    publicStNamingStructure: replace(thisNamingStructure, '{subwloadname}', 'pub')
    workspaceName: '${workloadName}${sequenceFormatted}'
    roles: rolesModule.outputs.roles
    approverEmail: dataExportApproverEmail
    deploymentNameStructure: deploymentNameStructure
    // Project's private storage account created earlier
    privateStorageAccountName: privateStorageAccountModule.outputs.storageAccountName
    containerNames: containerNames
    tags: tags
    // This storage account is created by the data module
    publicStorageAccountName: publicStorageAccountShortname.outputs.shortName
    keyVaultName: keyVaultModule.outputs.keyVaultName
    privateStorageAccountConnStringSecretName: privateStorageAccountConnStringSecretModule.outputs.secretName
    keyVaultResourceGroupName: corePrjResourceGroup.name
    airlockFileShareName: fileShareNames.airlock
    airlockStorageAccountName: airlockStorageAccountNameModule.outputs.shortName
    hubSubscriptionId: hubSubscriptionId
    hubKeyVaultName: hubKeyVaultShortNameModule.outputs.shortName
    hubKeyVaultResourceGroupName: coreHubResourceGroup.name
    publicStorageAccountAllowedIPs: publicStorageAccountAllowedIPs
    projectMemberAadGroupObjectId: projectMemberAadGroupObjectId
  }
}

// TODO: Permissions to log into VMs - RBAC role assignments

// Create an IP group to be used in Azure Firewall rules.
module ipGroupModule 'modules/ipGroup.bicep' = {
  name: replace(deploymentNameStructure, '{rtype}', 'ipg')
  scope: corePrjResourceGroup
  params: {
    location: location
    ipAddresses: vNetModule.outputs.vNetAddressSpace
    namingStructure: coreNamingStructure
  }
}

// TODO: Add firewall rules to policy based on ipGroup

resource computePrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  name: computeDnsSuffix
  scope: coreHubResourceGroup
}

// Link the project virtual network to the hub's compute Private DNS Zone
module computePrivateDnsZoneVNetLinkModule 'modules/privateDnsZoneVNetLink.bicep' = {
  name: replace(deploymentNameStructure, '{rtype}', 'dns-link-compute')
  scope: coreHubResourceGroup
  params: {
    dnsZoneName: computePrivateDnsZone.name
    vNetId: vNetModule.outputs.vNetId
    // New NICs in the virtual network will register with DNS
    registrationEnabled: true
  }
}

output vnetAddressSpace array = vNetModule.outputs.vNetAddressSpace
output privateStorageAccountName string = privateStorageAccountShortname.outputs.shortName
output publicStorageAccountName string = publicStorageAccountShortname.outputs.shortName
output dataResourceGroupName string = dataPrjResourceGroup.name
output subnets array = vNetModule.outputs.subnetIds
