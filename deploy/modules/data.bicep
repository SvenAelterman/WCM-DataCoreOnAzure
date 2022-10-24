targetScope = 'subscription'

param location string
param namingStructure string
param publicStNamingStructure string
param workspaceName string
param deploymentNameStructure string
param privateStorageAccountName string
param privateStorageAccountRG string
param containerNames object
param approverEmail string
param roles object
param publicStorageAccountName string
param projectFileShareName string
param keyVaultName string
param keyVaultResourceGroupName string
param privateStorageAccountConnStringSecretName string

param tags object = {}

// Get the project's DATA resource group
// This is where the private storage account is, and where we'll add the data automation resources
resource dataAutomationRG 'Microsoft.Resources/resourceGroups@2021-04-01' existing = {
  name: privateStorageAccountRG
}

// Get a reference to the already existing private storage account
resource privateStorageAccount 'Microsoft.Storage/storageAccounts@2021-02-01' existing = {
  name: privateStorageAccountName
  scope: dataAutomationRG
}

// User Assigned Managed Identity to be used for post-deployment tasks
module uami 'data/uami.bicep' = {
  name: replace(deploymentNameStructure, '{rtype}', 'uami')
  scope: dataAutomationRG
  params: {
    location: location
    namingStructure: namingStructure
    subwloadname: workspaceName
    roles: roles
    tags: tags
  }
}

// Azure Data Factory resource and contents
module adfModule 'data/adf.bicep' = {
  name: replace(deploymentNameStructure, '{rtype}', 'adf')
  scope: dataAutomationRG
  params: {
    namingStructure: namingStructure
    location: location
    deploymentNameStructure: deploymentNameStructure
    privateStorageAcctName: privateStorageAccountName
    userAssignedIdentityId: uami.outputs.managedIdentityId
    fileShareName: projectFileShareName
    tags: tags
    keyVaultName: keyVaultName
    keyVaultResourceGroupName: keyVaultResourceGroupName
    privateStorageAccountConnStringSecretName: privateStorageAccountConnStringSecretName
  }
}

// Logic app for approval workflow
module logicAppModule 'data/logicApp.bicep' = {
  name: replace(deploymentNameStructure, '{rtype}', 'logicApp')
  scope: dataAutomationRG
  params: {
    namingStructure: namingStructure
    location: location
    storageAcctName: privateStorageAccountName
    adfName: adfModule.outputs.name
    approverEmail: approverEmail
    tags: tags
  }
}

// Add Public Storage
module publicStorageAccountModule 'data/storage.bicep' = {
  name: replace(deploymentNameStructure, '{rtype}', 'st-pub')
  scope: dataAutomationRG
  params: {
    storageAccountName: publicStorageAccountName
    location: location
    namingStructure: publicStNamingStructure
    subwloadname: 'pub'
    containerNames: [
      // TODO: needs exported?
      containerNames.ingest
    ]
    principalIds: [
      adfModule.outputs.principalId
    ]
    privatize: false
    tags: tags
  }
}

// Setup System Event Grid Topic for public storage account. We only do this here to control the name of the event grid topic
module eventGridForPublicModule 'data/eventGrid.bicep' = {
  name: replace(deploymentNameStructure, '{rtype}', 'evgt-public')
  scope: dataAutomationRG
  params: {
    location: location
    namingStructure: publicStNamingStructure
    subwloadname: publicStorageAccountModule.outputs.storageAccountName
    resourceId: publicStorageAccountModule.outputs.storageAccountId
    topicName: 'Microsoft.Storage.StorageAccounts'
    tags: tags
  }
}

// Setup System Event Grid Topic for private storage account. We only do this here to control the name of the event grid topic
module eventGridForPrivateModule 'data/eventGrid.bicep' = {
  name: replace(deploymentNameStructure, '{rtype}', 'evgt-private')
  scope: dataAutomationRG
  params: {
    location: location
    namingStructure: namingStructure
    subwloadname: privateStorageAccountName
    resourceId: privateStorageAccount.id
    topicName: 'Microsoft.Storage.StorageAccounts'
    tags: tags
  }
}

//
module ingestTriggerModule 'data/adfTrigger.bicep' = {
  scope: dataAutomationRG
  name: replace(deploymentNameStructure, '{rtype}', 'adf-trigger-public')
  params: {
    adfName: adfModule.outputs.name
    workspaceName: workspaceName
    storageAccountId: publicStorageAccountModule.outputs.storageAccountId
    storageAccountType: 'Public'
    ingestPipelineName: adfModule.outputs.pipelineName
    sourceStorageAccountName: publicStorageAccountModule.outputs.storageAccountName
    sinkStorageAccountName: privateStorageAccountName
    containerName: containerNames.ingest
  }
}

module exportTriggerModule 'data/adfTrigger.bicep' = {
  scope: dataAutomationRG
  name: replace(deploymentNameStructure, '{rtype}', 'adf-trigger-private')
  params: {
    adfName: adfModule.outputs.name
    workspaceName: workspaceName
    storageAccountId: privateStorageAccount.id
    storageAccountType: 'Private'
    ingestPipelineName: adfModule.outputs.pipelineName
    sourceStorageAccountName: privateStorageAccountName
    sinkStorageAccountName: publicStorageAccountModule.outputs.storageAccountName
    containerName: containerNames.exportApproved
  }
}

module adfManagedPrivateEndpointModule 'data/adfManagedPrivateEndpoint.bicep' = {
  name: replace(deploymentNameStructure, '{rtype}', 'adf-pep')
  scope: dataAutomationRG
  params: {
    adfName: adfModule.outputs.name
    privateStorageAccountId: privateStorageAccount.id
    privateStorageAccountName: privateStorageAccountName
  }
}

// Deployment script for post deployment tasks
// * Start the triggers in the ADF
module startTriggerDeploymentScriptModule 'data/deploymentScript.bicep' = {
  name: 'StartTrigger-${replace(deploymentNameStructure, '{rtype}', 'dplscr')}'
  scope: dataAutomationRG
  params: {
    location: location
    subwloadname: 'StartTriggers'
    namingStructure: namingStructure
    arguments: ' -ResourceGroupName ${dataAutomationRG.name} -azureDataFactoryName ${adfModule.outputs.name} -privateLinkResourceId ${adfManagedPrivateEndpointModule.outputs.privateEndpointId}'
    scriptContent: '\r\n          param(\r\n            [string] [Parameter(Mandatory=$true)] $ResourceGroupName,\r\n            [string] [Parameter(Mandatory=$true)] $azureDataFactoryName,\r\n            [string] [Parameter(Mandatory=$true)] $privateLinkResourceId\r\n          )\r\n\r\n          Connect-AzAccount -Identity\r\n\r\n          # Start Triggers\r\n          Get-AzDataFactoryV2Trigger -DataFactoryName $azureDataFactoryName -ResourceGroupName $ResourceGroupName | Start-AzDataFactoryV2Trigger -Force | Out-Null\r\n\r\n          # Approve DFS private endpoint\r\n          foreach ($privateLinkConnection in (Get-AzPrivateEndpointConnection -PrivateLinkResourceId $privateLinkResourceId)) { if ($privateLinkConnection.PrivateLinkServiceConnectionState.Status -eq "Pending") { Approve-AzPrivateEndpointConnection -ResourceId $privateLinkConnection.id } }\r\n        '
    userAssignedIdentityId: uami.outputs.managedIdentityId
    tags: tags
  }
}
