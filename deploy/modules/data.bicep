param location string
param namingStructure string
param publicStNamingStructure string
param workspaceName string
param deploymentNameStructure string
param privateStorageAccountName string
param publicStorageAccountName string
param containerNames object
param approverEmail string
param roles object
param keyVaultName string
param keyVaultResourceGroupName string
param privateStorageAccountConnStringSecretName string
param airlockStorageAccountName string
param airlockFileShareName string
param hubKeyVaultName string
param hubKeyVaultResourceGroupName string
param hubSubscriptionId string
param publicStorageAccountAllowedIPs array = []

param tags object = {}

resource hubKvRg 'Microsoft.Resources/resourceGroups@2021-04-01' existing = {
  name: hubKeyVaultResourceGroupName
  scope: subscription(hubSubscriptionId)
}

// TODO: Disable linter until RBAC assigned
#disable-next-line no-unused-existing-resources
resource hubKv 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: hubKeyVaultName
  scope: hubKvRg
}

// Get a reference to the already existing private storage account
resource privateStorageAccount 'Microsoft.Storage/storageAccounts@2021-02-01' existing = {
  name: privateStorageAccountName
}

// User Assigned Managed Identity to be used for post-deployment tasks
module uami 'data/uami.bicep' = {
  name: replace(deploymentNameStructure, '{rtype}', 'uami')
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
  params: {
    namingStructure: namingStructure
    location: location
    deploymentNameStructure: deploymentNameStructure
    privateStorageAcctName: privateStorageAccountName
    userAssignedIdentityId: uami.outputs.managedIdentityId
    tags: tags
    keyVaultName: keyVaultName
    keyVaultResourceGroupName: keyVaultResourceGroupName
    privateStorageAccountConnStringSecretName: privateStorageAccountConnStringSecretName
  }
}

// TODO: Grant ADF managed identity access to hub's KV to retrieve secrets

// Logic app for export review (moves file to airlock and sends approval email)
module logicAppModule 'data/logicApp.bicep' = {
  name: replace(deploymentNameStructure, '{rtype}', 'logic')
  params: {
    namingStructure: namingStructure
    location: location
    prjStorageAcctName: privateStorageAccountName
    airlockFileShareName: airlockFileShareName
    airlockStorageAcctName: airlockStorageAccountName
    adfName: adfModule.outputs.name
    approverEmail: approverEmail
    sinkFolderPath: privateStorageAccountName
    sourceFolderPath: containerNames.exportRequest
    prjPublicStorageAcctName: publicStorageAccountName
    tags: tags
  }
}

// Add Public Storage
module publicStorageAccountModule 'data/storage.bicep' = {
  name: replace(deploymentNameStructure, '{rtype}', 'st-pub')
  params: {
    storageAccountName: publicStorageAccountName
    location: location
    namingStructure: publicStNamingStructure
    subwloadname: 'pub'
    containerNames: [
      containerNames.ingest
      containerNames.exportApproved
    ]
    principalIds: [
      adfModule.outputs.principalId
    ]
    privatize: false
    allowedIpAddresses: publicStorageAccountAllowedIPs
    tags: tags
  }
}

// Setup System Event Grid Topic for public storage account. We only do this here to control the name of the event grid topic
module eventGridForPublicModule 'data/eventGrid.bicep' = {
  name: replace(deploymentNameStructure, '{rtype}', 'evgt-public')
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
  params: {
    location: location
    namingStructure: namingStructure
    subwloadname: privateStorageAccountName
    resourceId: privateStorageAccount.id
    topicName: 'Microsoft.Storage.StorageAccounts'
    tags: tags
  }
}

resource kvRg 'Microsoft.Resources/resourceGroups@2021-04-01' existing = {
  name: keyVaultResourceGroupName
  scope: subscription()
}

resource prjKeyVault 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: keyVaultName
  scope: kvRg
}

// Trigger to move ingested blobs from the project's public storage account to the private storage account
module ingestTriggerModule 'data/adfTrigger.bicep' = {
  name: replace(deploymentNameStructure, '{rtype}', 'adf-trigger-ingest')
  params: {
    adfName: adfModule.outputs.name
    workspaceName: workspaceName
    storageAccountId: publicStorageAccountModule.outputs.storageAccountId
    storageAccountType: 'Public'
    ingestPipelineName: adfModule.outputs.pipelineName
    sourceStorageAccountName: publicStorageAccountModule.outputs.storageAccountName
    sinkStorageAccountName: privateStorageAccountName
    containerName: containerNames.ingest
    additionalSinkFolderPath: 'incoming'
    // TODO: Do not hardcode file share name 'shared'
    sinkFileShareName: 'shared'
    // The URL of the project's Key Vault
    // The project's KV stores the connection string to the project's file share
    // TODO: Validate the KV URL has the https:// prefix already
    sinkConnStringKvBaseUrl: prjKeyVault.properties.vaultUri
  }
}

module adfManagedPrivateEndpointModule 'data/adfManagedPrivateEndpoint.bicep' = {
  name: replace(deploymentNameStructure, '{rtype}', 'adf-pep')
  params: {
    adfName: adfModule.outputs.name
    privateStorageAccountId: privateStorageAccount.id
    privateStorageAccountName: privateStorageAccountName
  }
}

// TODO: Create managed private endpoint for airlock storage account

// Deployment script for post deployment tasks
// * Start the triggers in the ADF
module startTriggerDeploymentScriptModule 'data/deploymentScript.bicep' = {
  name: 'StartTrigger-${replace(deploymentNameStructure, '{rtype}', 'dplscr')}'
  params: {
    location: location
    subwloadname: 'StartTriggers'
    namingStructure: namingStructure
    arguments: ' -ResourceGroupName ${resourceGroup().name} -azureDataFactoryName ${adfModule.outputs.name} -privateLinkResourceId ${adfManagedPrivateEndpointModule.outputs.privateEndpointId}'
    scriptContent: '\r\n          param(\r\n            [string] [Parameter(Mandatory=$true)] $ResourceGroupName,\r\n            [string] [Parameter(Mandatory=$true)] $azureDataFactoryName,\r\n            [string] [Parameter(Mandatory=$true)] $privateLinkResourceId\r\n          )\r\n\r\n          Connect-AzAccount -Identity\r\n\r\n          # Start Triggers\r\n          Get-AzDataFactoryV2Trigger -DataFactoryName $azureDataFactoryName -ResourceGroupName $ResourceGroupName | Start-AzDataFactoryV2Trigger -Force | Out-Null\r\n\r\n          # Approve DFS private endpoint\r\n          foreach ($privateLinkConnection in (Get-AzPrivateEndpointConnection -PrivateLinkResourceId $privateLinkResourceId)) { if ($privateLinkConnection.PrivateLinkServiceConnectionState.Status -eq "Pending") { Approve-AzPrivateEndpointConnection -ResourceId $privateLinkConnection.id } }\r\n        '
    userAssignedIdentityId: uami.outputs.managedIdentityId
    tags: tags
  }
}
