param adfName string
param storageAccountId string
param storageAccountName string

param privateEndpointGroupIDs array = [
  'dfs'
  'file'
]

// LATER: Hardcoded managed VNet name ('default')
resource privateEndpoint 'Microsoft.DataFactory/factories/managedVirtualNetworks/managedPrivateEndpoints@2018-06-01' = [for groupId in privateEndpointGroupIDs: {
  name: '${adfName}/default/pe-${storageAccountName}-${groupId}'
  properties: {
    privateLinkResourceId: storageAccountId
    groupId: groupId
  }
}]

// VERIFY: Only need to put out a single private link resource because they all refer to the same storage account?
output privateEndpointId string = privateEndpoint[0].properties.privateLinkResourceId
