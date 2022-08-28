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
//param vnetId string = ''
param principalIds array = []
param tags object = {}

var assignRole = !empty(principalIds)
var baseName = !empty(subwloadname) ? replace(namingStructure, '{subwloadname}', subwloadname) : replace(namingStructure, '-{subwloadname}', '')
//var endpoint = 'privatelink.blob.${environment().suffixes.storage}'

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
    supportsHttpsTrafficOnly: true
    publicNetworkAccess: privatize ? 'Disabled' : 'Enabled'
    accessTier: 'Hot'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: privatize ? 'Deny' : 'Allow' // force deny inbound traffic
      ipRules: [] // Don't allow any IPs through the firewall
      virtualNetworkRules: [] // Do not integrate via vnet due to service delegation requirements
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
        versions: 'SMB3.1.1;'
        authenticationMethods: 'Kerberos;'
        kerberosTicketEncryption: 'AES-256;'
        channelEncryption: 'AES-256-GCM;'
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

// Assign Storage Blob data contrib to principalId if sent to this module
resource rbacAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = [for i in principalIds: if (assignRole) {
  name: guid('rbac-${storageAccount.name}-${i}')
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')
    principalId: i
    principalType: 'ServicePrincipal'
  }
}]

output storageAccountId string = storageAccount.id
output storageAccountName string = storageAccount.name
