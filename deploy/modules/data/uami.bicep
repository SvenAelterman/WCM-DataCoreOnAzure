param location string
param namingStructure string
param subwloadname string = ''
param roles object
param tags object

var baseName = !empty(subwloadname) ? replace(namingStructure, '{subwloadname}', subwloadname) : replace(namingStructure, '-{subwloadname}', '')

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: replace(baseName, '{rtype}', 'uami')
  location: location
  tags: tags
}

// assign roles to the uami for post deployment tasks
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for r in items(roles): {
  name: guid(resourceGroup().id, managedIdentity.name, r.value)
  properties: {
    roleDefinitionId: r.value
    principalId: managedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}]

output managedIdentityId string = managedIdentity.id
