param principalId string
param roleDefinitionId string
param principalType string
param keyVaultName string
param secretName string

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: keyVaultName
  scope: resourceGroup()
}

resource secret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' existing = {
  name: secretName
  parent: keyVault
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('${secret.id}-${principalId}-${roleDefinitionId}')
  scope: secret
  properties: {
    principalId: principalId
    roleDefinitionId: roleDefinitionId
    principalType: principalType
  }
}
