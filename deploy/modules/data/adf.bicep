// Required parameters
param location string
param namingStructure string
param deploymentNameStructure string
param subwloadname string = ''
param privateStorageAcctName string
param userAssignedIdentityId string
@description('Name of the Azure Files share where incoming data should be delivered')
param fileShareName string
param privateStorageAccountConnStringSecretName string
param keyVaultName string
param keyVaultResourceGroupName string

// Optional parameters
@description('Name of the folder in the Azure file share to deliver incoming data')
param incomingFolderName string = 'incoming'

param tags object = {}
param pipelineName string = 'pipe-data_move'

var baseName = !empty(subwloadname) ? replace(namingStructure, '{subwloadname}', subwloadname) : replace(namingStructure, '-{subwloadname}', '')
var managedVnetName = 'default'
var autoResolveIntegrationRuntimeName = 'AutoResolveIntegrationRuntime'
var adlsGen2LinkedServiceName = 'ls_ADLSGen2_Generic'
var azFilesLinkedServiceName = 'ls_AzFiles_Generic'
var kvLinkedServiceName = 'ls_KeyVault'

resource privateStorageAcct 'Microsoft.Storage/storageAccounts@2021-08-01' existing = {
  name: privateStorageAcctName
}

// The Key Vault where ADF can get the connection string for the Azure File Share linked service
resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: keyVaultName
  scope: resourceGroup(keyVaultResourceGroupName)
}

resource adf 'Microsoft.DataFactory/factories@2018-06-01' = {
  name: replace(baseName, '{rtype}', 'adf')
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  tags: tags
}

// deployment script to stop triggers
module stopTriggersDeploymentScriptModule 'deploymentScript.bicep' = {
  name: 'StopTrigger-${replace(deploymentNameStructure, '{rtype}', 'dplscr')}'
  params: {
    location: location
    subwloadname: 'StopTriggers'
    namingStructure: namingStructure
    arguments: ' -ResourceGroupName ${resourceGroup().name} -azureDataFactoryName ${adf.name}'
    scriptContent: '\r\n          param(\r\n            [string] [Parameter(Mandatory=$true)] $ResourceGroupName,\r\n            [string] [Parameter(Mandatory=$true)] $azureDataFactoryName\r\n            )\r\n\r\n          Connect-AzAccount -Identity\r\n\r\n          # Stop Triggers\r\n          Get-AzDataFactoryV2Trigger -DataFactoryName $azureDataFactoryName -ResourceGroupName $ResourceGroupName | Where-Object { $_.RuntimeState -eq \'Started\' } | Stop-AzDataFactoryV2Trigger -Force | Out-Null\r\n'
    userAssignedIdentityId: userAssignedIdentityId
  }
}

resource managedVnet 'Microsoft.DataFactory/factories/managedVirtualNetworks@2018-06-01' = {
  name: '${adf.name}/${managedVnetName}'
  properties: {}
}

resource integrationRuntime 'Microsoft.DataFactory/factories/integrationRuntimes@2018-06-01' = {
  name: '${adf.name}/${autoResolveIntegrationRuntimeName}'
  dependsOn: [
    managedVnet
  ]
  properties: {
    type: 'Managed'
    managedVirtualNetwork: {
      type: 'ManagedVirtualNetworkReference'
      referenceName: managedVnetName
    }
    typeProperties: {
      computeProperties: {
        location: 'AutoResolve'
      }
    }
  }
}

module rolesModule '../../common-modules/roles.bicep' = {
  name: 'roles'
}

// RBAC role assignment for ADF to Key Vault
module adfKeyVaultRoleAssignmentModule '../keyVault-Secret-RoleAssignment.bicep' = {
  name: '${adf.name}-rbac-${keyVaultName}'
  scope: resourceGroup(keyVaultResourceGroupName)
  params: {
    principalId: adf.identity.principalId
    roleDefinitionId: rolesModule.outputs.roles['Key Vault Secrets User']
    principalType: 'ServicePrincipal'
    keyVaultName: keyVault.name
    secretName: privateStorageAccountConnStringSecretName
  }
}

// Linked service for Key Vault, used by File Share linked service to get connection string
resource keyVaultLinkedService 'Microsoft.DataFactory/factories/linkedservices@2018-06-01' = {
  name: kvLinkedServiceName
  parent: adf
  dependsOn: [
    adfKeyVaultRoleAssignmentModule
  ]
  properties: {
    type: 'AzureKeyVault'
    typeProperties: {
      baseUrl: keyVault.properties.vaultUri
    }
  }
}

resource genericLinkedServiceAdlsGen2 'Microsoft.DataFactory/factories/linkedservices@2018-06-01' = {
  name: adlsGen2LinkedServiceName
  parent: adf
  dependsOn: [
    integrationRuntime
  ]
  properties: {
    type: 'AzureBlobFS'
    typeProperties: {
      url: '@{concat(\'https://\', linkedService().storageAccountName, \'.dfs.${environment().suffixes.storage}\')}'
    }
    connectVia: {
      referenceName: autoResolveIntegrationRuntimeName
      type: 'IntegrationRuntimeReference'
    }
    parameters: {
      storageAccountName: {
        type: 'String'
      }
    }
  }
}

resource genericLinkedServiceAzFiles 'Microsoft.DataFactory/factories/linkedservices@2018-06-01' = {
  name: azFilesLinkedServiceName
  parent: adf
  dependsOn: [
    integrationRuntime
    adfKeyVaultRoleAssignmentModule
    keyVaultLinkedService
  ]
  properties: {
    type: 'AzureFileStorage'
    typeProperties: {
      fileShare: '@{linkedService().fileShareName}'
      connectionString: {
        type: 'AzureKeyVaultSecret'
        store: {
          referenceName: kvLinkedServiceName
          type: 'LinkedServiceReference'
        }
        secretName: {
          type: 'Expression'
          value: '@{concat(linkedService().storageAccountName, \'-connstring1\')}'
        }
      }
    }
    parameters: {
      storageAccountName: {
        type: 'String'
      }
      fileShareName: {
        type: 'String'
        defaultValue: fileShareName
      }
    }
    connectVia: {
      referenceName: autoResolveIntegrationRuntimeName
      type: 'IntegrationRuntimeReference'
    }
  }
}

// Create Azure Files dataset
resource AzFilesDataset 'Microsoft.DataFactory/factories/datasets@2018-06-01' = {
  name: 'AzFilesDataset'
  parent: adf
  properties: {
    linkedServiceName: {
      referenceName: azFilesLinkedServiceName
      type: 'LinkedServiceReference'
      parameters: {
        storageAccountName: {
          type: 'Expression'
          value: '@dataset().storageAccountName'
        }
      }
    }
    type: 'Binary'
    typeProperties: {
      location: {
        type: 'AzureFileStorageLocation'
        folderPath: incomingFolderName
        fileName: {
          type: 'Expression'
          value: '@dataset().fileName'
        }
      }
    }
    parameters: {
      fileName: {
        type: 'String'
      }
      storageAccountName: {
        type: 'String'
      }
    }
  }
}

resource dfsDataset 'Microsoft.DataFactory/factories/datasets@2018-06-01' = {
  name: 'DfsDataset'
  parent: adf
  properties: {
    type: 'Binary'
    linkedServiceName: {
      referenceName: adlsGen2LinkedServiceName
      type: 'LinkedServiceReference'
      parameters: {
        storageAccountName: {
          value: '@dataset().storageAccountName'
          type: 'Expression'
        }
      }
    }
    parameters: {
      storageAccountName: {
        type: 'String'
      }
      folderPath: {
        type: 'String'
      }
      fileName: {
        type: 'String'
      }
    }
    typeProperties: {
      location: {
        type: 'AzureBlobFSLocation'
        fileName: {
          value: '@dataset().fileName'
          type: 'Expression'
        }
        fileSystem: {
          value: '@dataset().folderPath'
          type: 'Expression'
        }
      }
    }
  }
  dependsOn: [
    genericLinkedServiceAdlsGen2
  ]
}

resource pipeline 'Microsoft.DataFactory/factories/pipelines@2018-06-01' = {
  name: '${adf.name}/${pipelineName}'
  properties: {
    // The pipeline's activity definitions are stored in a JSON file to keep this file readable
    activities: [
      json(loadTextContent('../../content/adfPipeline.json'))
    ]
    parameters: {
      sourceStorageAccountName: {
        type: 'String'
      }
      sinkStorageAccountName: {
        type: 'String'
      }
      sourceFolderPath: {
        type: 'String'
      }
      sinkFolderPath: {
        type: 'String'
      }
      fileName: {
        type: 'String'
      }
    }
  }
  dependsOn: [
    dfsDataset
  ]
}

// TODO: Abstract to storage-RoleAssignment module
var storageAccountRoleDefinitionId = rolesModule.outputs.roles['Storage Blob Data Contributor']

// Grant the ADF the Storage Blob Data Contributor role on the private storage account
resource adfPrivateStgRole 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  // TODO: Fix name by combining object, subject, and role ID
  name: guid('${privateStorageAcct.name}-${adf.name}-StorageBlobDataContributor')
  scope: privateStorageAcct
  properties: {
    roleDefinitionId: storageAccountRoleDefinitionId
    principalId: adf.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

output principalId string = adf.identity.principalId
output name string = adf.name
output pipelineName string = pipelineName
