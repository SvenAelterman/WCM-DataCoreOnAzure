param firewallSubnetId string
param fwManagementSubnetId string
param location string
param namingStructure string

param firewallTier string = 'Basic'

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

// LATER: Only required for Basic SKU
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
      tier: firewallTier
    }
  }
  tags: tags
}

var ruleCollectionGroups = {
  AVD: {
    rules: loadJsonContent('../content/azFwPolRuleColls-AVD.json')
    priority: 500
  }
  AzurePlatform: {
    rules: loadJsonContent('../content/azFwPolRuleColls-AzurePlatform.json')
    priority: 1000
  }
  AVDRDWeb: {
    rules: loadJsonContent('../content/azFwPolRuleColls-AVDRDWeb.json')
    priority: 100
  }
  ManagedDevices: {
    rules: loadJsonContent('../content/azFwPolRuleColls-ManagedDevices.json')
    priority: 300
  }
  Office365Activation: {
    rules: loadJsonContent('../content/azFwPolRuleColls-Office365Activation.jsonc')
    priority: 700
  }
  ResearchDataSources: {
    rules: loadJsonContent('../content/azFwPolRuleColls-ResearchDataSources.json')
    priority: 600
  }
  Custom: {
    rules: loadJsonContent('../content/azFwPolRuleColls-Custom.jsonc')
    priority: 200
  }
}

@batchSize(1)
resource fwRuleCollectionGroups 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2022-07-01' = [for (group, i) in items(ruleCollectionGroups): {
  name: group.key
  parent: firewallPolicy
  properties: {
    priority: group.value.priority
    ruleCollections: group.value.rules
  }
}]

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
      tier: firewallTier
    }
  }
  tags: tags
  dependsOn: [
    fwRuleCollectionGroups
  ]
}

output fwPrIp string = firewall.properties.ipConfigurations[0].properties.privateIPAddress
