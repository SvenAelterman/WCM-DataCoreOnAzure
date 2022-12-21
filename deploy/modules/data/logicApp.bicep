param location string
param namingStructure string
param adfName string
param prjStorageAcctName string
param prjPublicStorageAcctName string
param airlockStorageAcctName string
param airlockFileShareName string
param approverEmail string
param sourceFolderPath string
param sinkFolderPath string

param subwloadname string = ''
param tags object = {}

var baseName = !empty(subwloadname) ? replace(namingStructure, '{subwloadname}', subwloadname) : replace(namingStructure, '-{subwloadname}', '')

// Project's private storage account
resource prjStorageAcct 'Microsoft.Storage/storageAccounts@2022-09-01' existing = {
  name: prjStorageAcctName
}

resource prjPublicStorageAcct 'Microsoft.Storage/storageAccounts@2022-09-01' existing = {
  name: prjPublicStorageAcctName
}

resource adf 'Microsoft.DataFactory/factories@2018-06-01' existing = {
  name: adfName
}

// As of 2022-10-23, Bicep does not have type info for this resource type
#disable-next-line BCP081
resource adfConnection 'Microsoft.Web/connections@2018-07-01-preview' = {
  name: 'api-${adfName}'
  location: location
  kind: 'V1'
  properties: {
    displayName: adfName
    api: {
      id: subscriptionResourceId('Microsoft.Web/locations/managedApis', location, 'azuredatafactory')
    }
    parameterValueType: 'Alternative'
  }
  tags: tags
}

// As of 2022-10-23, Bicep does not have type info for this resource type
#disable-next-line BCP081
resource stgConnection 'Microsoft.Web/connections@2018-07-01-preview' = {
  name: 'api-${prjStorageAcctName}'
  location: location
  kind: 'V1'
  properties: {
    displayName: prjStorageAcctName
    api: {
      id: subscriptionResourceId('Microsoft.Web/locations/managedApis', location, 'azureblob')
    }
    parameterValueSet: {
      name: 'managedIdentityAuth'
      value: {}
    }
  }
  tags: tags
}

// As of 2022-10-23, Bicep does not have type info for this resource type
#disable-next-line BCP081
resource emailConnection 'Microsoft.Web/connections@2018-07-01-preview' = {
  name: 'api-office365'
  location: location
  kind: 'V1'
  properties: {
    displayName: 'office365'
    api: {
      id: subscriptionResourceId('Microsoft.Web/locations/managedApis', location, 'office365')
    }
  }
  tags: tags
}

resource logicApp 'Microsoft.Logic/workflows@2019-05-01' = {
  name: replace(baseName, '{rtype}', 'logic')
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    definition: json(loadTextContent('../../content/logicAppWorkflow.json'))
    parameters: {
      '$connections': {
        value: {
          azureblob: {
            connectionId: stgConnection.id
            connectionName: 'azureblob'
            connectionProperties: {
              authentication: {
                type: 'ManagedServiceIdentity'
              }
            }
            id: subscriptionResourceId('Microsoft.Web/locations/managedApis', location, 'azureblob')
          }
          azuredatafactory: {
            connectionId: adfConnection.id
            connectionName: 'azuredatafactory'
            connectionProperties: {
              authentication: {
                type: 'ManagedServiceIdentity'
              }
            }
            id: subscriptionResourceId('Microsoft.Web/locations/managedApis', location, 'azuredatafactory')
          }
          office365: {
            connectionId: emailConnection.id
            connectionName: 'office365'
            id: subscriptionResourceId('Microsoft.Web/locations/managedApis', location, 'office365')
          }
        }
      }
      subscriptionId: {
        value: subscription().subscriptionId
      }
      dataFactoryRG: {
        value: resourceGroup().name
      }
      dataFactoryName: {
        value: adf.name
      }
      sourceStorageAccountName: {
        value: prjStorageAcctName
      }
      sourceFolderPath: {
        value: sourceFolderPath
      }
      sinkStorageAccountName: {
        value: airlockStorageAcctName
      }
      notificationEmail: {
        value: approverEmail
      }
      sinkFileShareName: {
        value: airlockFileShareName
      }
      sinkFolderPath: {
        value: sinkFolderPath
      }
      finalSinkStorageAccountName: {
        value: prjPublicStorageAcctName
      }
      // TODO: Add parameters for pipeline names
      // TODO: Add parameter for Key Vault URL (sinkConnStringKvBaseUrl)
      // TODO: Add parameter for source container name (for trigger value)
      exportApprovedContainerName: {
        // TODO: Do not hardcode container name
        value: 'export-approved'
      }
    }
  }
  tags: tags
}

// Set RBAC on ADF for Logic App
resource logicAppAdfRole 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  name: guid('rbac-${adf.name}-${logicApp.name}')
  scope: adf
  properties: {
    // TODO: Use Roles module
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '673868aa-7521-48a0-acc6-0f60742d39f5')
    principalId: logicApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Set RBAC on project Storage Account for Logic App
resource logicAppPrivateStgRole 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  name: guid('rbac-${prjStorageAcct.name}-${logicApp.name}')
  scope: prjStorageAcct
  properties: {
    // TODO: Use Roles module
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')
    principalId: logicApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}
