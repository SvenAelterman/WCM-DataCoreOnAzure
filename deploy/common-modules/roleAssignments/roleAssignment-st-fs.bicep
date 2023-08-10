// Assigns role to an Azure Storage Account's File Share

param storageAccountName string
param fileShareName string
param principalId string
param roleDefinitionId string

param fileServicesName string = 'default'

resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' existing = {
  name: storageAccountName
}

resource fileService 'Microsoft.Storage/storageAccounts/fileServices@2022-09-01' existing = {
  name: fileServicesName
  parent: storageAccount
}

#disable-next-line BCP081 // /fileShares is the right type to assign permissions
resource fileShare 'Microsoft.Storage/storageAccounts/fileServices/fileShares@2022-09-01' existing = {
  name: fileShareName
  parent: fileService
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(fileShare.id, principalId, roleDefinitionId)
  scope: fileShare
  properties: {
    roleDefinitionId: roleDefinitionId
    principalId: principalId
  }
}

output id string = roleAssignment.id
