param location string
param namingStructure string
param containerNames array
@maxLength(23)
param storageAccountName string
param privatize bool

// Must be specified if privatize == true
param privateEndpointInfo array = []
param subnetId string = ''

param fileShareNames array = []
param subwloadname string = ''
param skuName string = 'Standard_LRS'
param principalIds array = []
param tags object = {}
param allowedIpAddresses array = []

var assignRole = !empty(principalIds)
var baseName = !empty(subwloadname) ? replace(namingStructure, '{subwloadname}', subwloadname) : replace(namingStructure, '-{subwloadname}', '')

var resourceAccessRules = !privatize ? [
  // Allow access from any Data Factory in the same resource group
  {
    tenantId: subscription().tenantId
    resourceId: resourceId(subscription().subscriptionId, resourceGroup().name, 'Microsoft.DataFactory/factories', '*')
  }
  // TODO: Add rule for EventGrid?
] : [
  // Enclave (private) storage account needs to allow the Logic App access to trigger the workflow
  {
    tenantId: subscription().tenantId
    resourceId: resourceId(subscription().subscriptionId, resourceGroup().name, 'Microsoft.Logic/workflows', '*')
  }
]

var ipRules = [for ipAddress in allowedIpAddresses: {
  value: ipAddress
  action: 'Allow'
}]

resource storageAccount 'Microsoft.Storage/storageAccounts@2021-09-01' = {
  name: storageAccountName
  location: location
  kind: 'StorageV2'
  sku: {
    name: skuName
  }
  properties: {
    minimumTlsVersion: 'TLS1_2'
    allowedCopyScope: privatize ? 'AAD' : null
    defaultToOAuthAuthentication: true
    allowBlobPublicAccess: false
    isHnsEnabled: true
    // Completely disable the public endpoint if the storage account will use private endpoints only
    supportsHttpsTrafficOnly: true
    publicNetworkAccess: privatize ? 'Disabled' : 'Enabled'
    accessTier: 'Hot'
    networkAcls: {
      bypass: 'None'
      // This controls the "Enabled from all networks" radio button for the public endpoint
      // Deny all networks if account is private, has a list of allowed IPs, or has resource access rules
      defaultAction: privatize || length(allowedIpAddresses) > 0 || length(resourceAccessRules) > 0 ? 'Deny' : 'Allow' // force deny inbound traffic
      // Do not add public access point IP rules if the storage account must be private
      ipRules: !privatize ? ipRules : []
      // Do not integrate via vnet due to service delegation requirements
      virtualNetworkRules: []
      // Do not add resource access rules if the storage account must be private
      resourceAccessRules: !privatize ? resourceAccessRules : []
    }
  }
  tags: tags
}

resource blobServices 'Microsoft.Storage/storageAccounts/blobServices@2021-09-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    containerDeleteRetentionPolicy: {
      enabled: true
      days: 7
    }
    deleteRetentionPolicy: {
      enabled: false
    }
  }
}

// Create each required container
resource container 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-09-01' = [for c in containerNames: {
  parent: blobServices
  name: c
}]

resource fileServices 'Microsoft.Storage/storageAccounts/fileServices@2021-09-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    shareDeleteRetentionPolicy: {
      days: 7
      enabled: true
    }
    protocolSettings: {
      smb: {
        versions: 'SMB3.0;SMB3.1.1;'
        authenticationMethods: 'Kerberos;'
        kerberosTicketEncryption: 'AES-256;'
        channelEncryption: 'AES-128-GCM;AES-256-GCM;'
      }
    }
  }
}

// Create each required file share
resource fileShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2021-09-01' = [for fs in fileShareNames: {
  parent: fileServices
  name: fs
}]

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2021-03-01' = [for info in privateEndpointInfo: if (privatize) {
  name: replace(baseName, '{rtype}', 'pep-${info.subResourceName}')
  location: location
  tags: tags
  properties: {
    subnet: {
      id: subnetId
    }
    privateLinkServiceConnections: [
      {
        name: replace(baseName, '{rtype}', 'pep-${info.subResourceName}')
        properties: {
          privateLinkServiceId: storageAccount.id
          groupIds: [
            info.subResourceName
          ]
        }
      }
    ]
  }
}]

resource privateEndpointDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2021-03-01' = [for (info, i) in privateEndpointInfo: if (privatize) {
  name: 'default'
  parent: privateEndpoint[i]
  properties: {
    privateDnsZoneConfigs: [
      {
        name: replace(info.dnsZoneName, '.', '-')
        properties: {
          privateDnsZoneId: info.dnsZoneId
        }
      }
    ]
  }
}]

var blobRoleDefinitionId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')

// Assign Storage Blob data contrib to principalId if sent to this module
resource rbacAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for i in principalIds: if (assignRole) {
  name: guid(storageAccount.id, i, blobRoleDefinitionId)
  scope: storageAccount
  properties: {
    roleDefinitionId: blobRoleDefinitionId
    principalId: i
    //principalType: 'ServicePrincipal'
  }
}]

output storageAccountId string = storageAccount.id
output storageAccountName string = storageAccount.name
