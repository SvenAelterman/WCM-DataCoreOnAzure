targetScope = 'subscription'

param location string
param hostPoolRegistrationToken string
param hostPoolName string
param namingStructure string
param abbreviations object
param avdVmHostNameStructure string
param avdSubnetId string

param loginPermissionObjectId string
param virtualMachineUserLoginRoleDefinitionId string

param deploymentNameStructure string = '{rtype}-${utcNow()}'
param tags object = {}
param vmCount int = 1

// If needed, create a separate resource group for the VMs
resource avdVmResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: replace(namingStructure, '{rtype}', abbreviations['Resource Group'])
  location: location
  tags: tags
}

module roleAssignmentModule '../common-modules/roleAssignments/roleAssignment-rg.bicep' = {
  name: take(replace(deploymentNameStructure, '{rtype}', 'rg-rbac'), 64)
  scope: avdVmResourceGroup
  params: {
    principalId: loginPermissionObjectId
    roleDefinitionId: virtualMachineUserLoginRoleDefinitionId
  }
}

module avdVm 'avd-vm.bicep' = {
  name: replace(deploymentNameStructure, '{rtype}', 'avdvm-vms')
  scope: avdVmResourceGroup
  params: {
    namingStructure: namingStructure
    hostPoolRegistrationToken: hostPoolRegistrationToken
    location: location
    abbreviations: abbreviations
    deploymentNameStructure: deploymentNameStructure
    vmCount: vmCount
    avdVmHostNameStructure: avdVmHostNameStructure
    hostPoolName: hostPoolName
    avdSubnetId: avdSubnetId
  }
}
