param vnetName string
param subnetAddressPrefix string
param subnetName string

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2021-05-01' = {
  name: '${vnetName}/${subnetName}'
  properties: {
    addressPrefix: subnetAddressPrefix
  }
}

output subnetId string = subnet.id
