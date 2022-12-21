param adfName string
param privateStorageAccountId string
param privateStorageAccountName string

// TODO: Hardcoded managed VNet name ('default')
resource privateEndpoint 'Microsoft.DataFactory/factories/managedVirtualNetworks/managedPrivateEndpoints@2018-06-01' = {
  name: '${adfName}/default/pe-${privateStorageAccountName}-dfs'
  properties: {
    privateLinkResourceId: privateStorageAccountId
    groupId: 'dfs'
  }
}

// TODO: Support for file private endpoint (parameter, airlock only needs file) => groupIds [] param

output privateEndpointId string = privateEndpoint.properties.privateLinkResourceId
