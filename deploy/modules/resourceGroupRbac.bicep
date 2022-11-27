param principalId string
param roleDefinitionId string
@allowed([
  'Group'
  'ServicePrincipal'
  'User'
  'ForeignGroup'
  'Device'
])
param principalType string

resource airlockLoginRbac 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(principalId, resourceGroup().id, roleDefinitionId)
  properties: {
    principalId: principalId
    roleDefinitionId: roleDefinitionId
    principalType: principalType
  }
}
