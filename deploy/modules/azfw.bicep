param firewallSubnetId string
param fwManagementSubnetId string
param location string
param namingStructure string

param tags object = {}

// Create public IP for the Azure Firewall
resource firewallPublicIp 'Microsoft.Network/publicIPAddresses@2022-01-01' = {
  name: replace(namingStructure, '{rtype}', 'pip-fw1')
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
  }
  tags: tags
}

resource firewallPublicIp2 'Microsoft.Network/publicIPAddresses@2022-01-01' = {
  name: replace(namingStructure, '{rtype}', 'pip-fw2')
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
  }
  tags: tags
}

// Create standard firewall policy
resource firewallPolicy 'Microsoft.Network/firewallPolicies@2022-01-01' = {
  name: replace(namingStructure, '{rtype}', 'fwpol')
  location: location
  properties: {
    sku: {
      tier: 'Basic'
    }
  }
  tags: tags
}

//resource intuneFirewallRule 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2022-01-01' = {
//  name: ''
//  parent: firewallPolicy
//  properties: {
//    priority: 100
//  }
//}

// Create Azure Firewall Basic SKU
resource firewall 'Microsoft.Network/azureFirewalls@2022-01-01' = {
  name: replace(namingStructure, '{rtype}', 'fw')
  location: location
  properties: {
    ipConfigurations: [
      {
        name: firewallPublicIp.name
        properties: {
          subnet: {
            id: firewallSubnetId
          }
          publicIPAddress: {
            id: firewallPublicIp.id
          }
        }

      }
    ]
    managementIpConfiguration: {
      name: replace(namingStructure, '{rtype}', 'fwmgt')
      properties: {
        publicIPAddress: {
          id: firewallPublicIp2.id
        }
        subnet: {
          id: fwManagementSubnetId
        }
      }
    }
    firewallPolicy: {
      id: firewallPolicy.id
    }
    sku: {
      name: 'AZFW_VNet'
      tier: 'Basic'
    }
  }
}

output fwPrIp string = firewall.properties.ipConfigurations[0].properties.privateIPAddress
