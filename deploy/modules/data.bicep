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

param airlockStorageAccountId string
param airlockStorageAccountName string
param airlockFileShareName string

param hubKeyVaultName string
param hubKeyVaultResourceGroupName string
param hubSubscriptionId string

param publicStorageAccountAllowedIPs array = []
param projectMemberAadGroupObjectId string

param fileShareNames object

param tags object = {}

resource hubKvRg 'Microsoft.Resources/resourceGroups@2021-04-01' existing = {
  name: hubKeyVaultResourceGroupName
  scope: subscription(hubSubscriptionId)
}

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
    // TODO: Limit roles
    roles: toObject(filter(items(roles), role => !contains(role.key, ' ')), item => item.key, item => item.value)
    tags: tags
  }
}

// Azure Data Factory resource and contents
module adfModule 'data/adf.bicep' = {
  name: take(replace(deploymentNameStructure, '{rtype}', 'adf'), 64)
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

// Grant ADF managed identity access to hub's KV to retrieve secrets
module adfHubKvRoleAssignment '../common-modules/roleAssignments/roleAssignment-kv.bicep' = {
  name: take(replace(deploymentNameStructure, '{rtype}', 'adf-rbac-hubkv'), 64)
  scope: hubKvRg
  params: {
    kvName: hubKeyVaultName
    principalId: adfModule.outputs.principalId
    roleDefinitionId: roles.KeyVaultSecretsUser
  }
}

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
    hubCoreKeyVaultUri: hubKv.properties.vaultUri
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
      projectMemberAadGroupObjectId
    ]
    privatize: false
    allowedIpAddresses: publicStorageAccountAllowedIPs
    tags: union(tags, { 'hidden-title': 'External/Public Storage Account' })
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
    // TODO: This is no longer needed because incoming has its own share
    additionalSinkFolderPath: 'i'
    sinkFileShareName: fileShareNames.projectIncoming
    // The URL of the project's Key Vault
    // The project's KV stores the connection string to the project's file share
    // TODO: Validate the KV URL has the https:// prefix already?
    sinkConnStringKvBaseUrl: prjKeyVault.properties.vaultUri
  }
}

module adfManagedPrivateEndpointModule 'data/adfManagedPrivateEndpoint.bicep' = {
  name: take(replace(deploymentNameStructure, '{rtype}', 'adf-pep'), 64)
  params: {
    adfName: adfModule.outputs.name
    storageAccountId: privateStorageAccount.id
    storageAccountName: privateStorageAccountName
  }
}

// Create a private endpoint for the hub's airlock storage account file endpoint
module adfHubAirlockManagedPrivateEndpointModule 'data/adfManagedPrivateEndpoint.bicep' = {
  name: take(replace(deploymentNameStructure, '{rtype}', 'adf-pep-hub'), 64)
  params: {
    adfName: adfModule.outputs.name
    storageAccountId: airlockStorageAccountId
    storageAccountName: airlockStorageAccountName
    privateEndpointGroupIDs: [ 'file' ]
  }
}

// TODO: 2024-02-28: Approval for hub airlock managed private endpoint

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
