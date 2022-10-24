param location string
param keyVaultName string

param tags object = {}

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' = {
  name: keyVaultName
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    enablePurgeProtection: true
    enableSoftDelete: true
    enableRbacAuthorization: true
    softDeleteRetentionInDays: 7
    tenantId: subscription().tenantId
  }
  tags: tags
}

output keyVaultName string = keyVault.name
