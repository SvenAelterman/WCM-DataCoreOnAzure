param localVNetName string
param remoteVNetId string

param localName string
param remoteName string

resource localVNetPeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2021-02-01' = {
  name: '${localVNetName}/peer-${localName}-to-${remoteName}'
  properties: {
    allowVirtualNetworkAccess: false
    allowForwardedTraffic: false
    allowGatewayTransit: false
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: remoteVNetId
    }
  }
}
