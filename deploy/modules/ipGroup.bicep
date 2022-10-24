param namingStructure string
param location string
param ipAddresses array

resource ipGroup 'Microsoft.Network/ipGroups@2022-01-01' = {
  name: replace(namingStructure, '{rtype}', 'ipg')
  location: location
  properties: {
    ipAddresses: ipAddresses
  }
}

output ipGroupId string = ipGroup.id
