param namingStructure string
param location string
param abbreviations object
param avdVmHostNameStructure string
param avdSubnetId string
param workloadName string

param environment string = ''
param deploymentNameStructure string = '{rtype}-${utcNow()}'
param tags object = {}
param baseTime string = utcNow('u')
param deployVmsInSeparateRG bool = true

param loginPermissionObjectId string
param dvuRoleDefinitionId string
param virtualMachineUserLoginRoleDefinitionId string

param usePrivateLinkForHostPool bool = true
param privateEndpointSubnetId string = ''
param privateLinkDnsZoneId string = ''

var avdNamingStructure = replace(namingStructure, '{subwloadname}', 'avd')
var avdVmNamingStructure = replace(namingStructure, '{subwloadname}', deployVmsInSeparateRG ? 'avd-vm' : 'avd')

resource hostPool 'Microsoft.DesktopVirtualization/hostPools@2019-12-10-preview' = {
  name: replace(avdNamingStructure, '{rtype}', abbreviations['AVD Host Pool'])
  location: location
  properties: {
    hostPoolType: 'Pooled'
    #disable-next-line BCP037
    publicNetworkAccess: 'EnabledForClientsOnly'
    loadBalancerType: 'BreadthFirst'
    preferredAppGroupType: 'RailApplications'
    customRdpProperty: 'drivestoredirect:s:0;audiomode:i:0;videoplaybackmode:i:1;redirectclipboard:i:0;redirectprinters:i:0;devicestoredirect:s:0;redirectcomports:i:0;redirectsmartcards:i:1;usbdevicestoredirect:s:0;enablecredsspsupport:i:1;use multimon:i:1;targetisaadjoined:i:1;'
    friendlyName: '${environment} Research Enclave Access'
    // TODO: startVMOnConnect requires role configuration
    #disable-next-line BCP037
    startVMOnConnect: true
    registrationInfo: {
      registrationTokenOperation: 'Update'
      // Expire the new registration token in two days
      expirationTime: dateTimeAdd(baseTime, 'P2D')
    }
  }
}

// resource applicationGroup 'Microsoft.DesktopVirtualization/applicationGroups@2023-09-05' = {
//   name: replace(avdNamingStructure, '{rtype}', abbreviations['AVD App Group'])
//   location: location
//   properties: {
//     hostPoolArmPath: hostPool.id
//     applicationGroupType: 'RemoteApp'
//   }
// }

// Deploy desktop application group for spoke usage
resource desktopApplicationGroup 'Microsoft.DesktopVirtualization/applicationGroups@2023-09-05' = {
  name: replace(avdNamingStructure, '{rtype}', abbreviations['AVD App Group'])
  location: location
  tags: tags
  properties: {
    hostPoolArmPath: hostPool.id
    applicationGroupType: 'Desktop'
  }
}

resource sessionDesktop 'Microsoft.DesktopVirtualization/applicationGroups/desktops@2023-09-05' existing = {
  name: 'SessionDesktop'
  parent: desktopApplicationGroup
}

// LATER: Execute deployment script for Update-AzWvdDesktop -ResourceGroupName rg-wcmprj-avd-demo-eastus-02 -ApplicationGroupName ag-wcmprj-avd-demo-eastus-02 -Name SessionDesktop -FriendlyName Test

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(desktopApplicationGroup.id, loginPermissionObjectId, dvuRoleDefinitionId)
  scope: desktopApplicationGroup
  properties: {
    roleDefinitionId: dvuRoleDefinitionId
    principalId: loginPermissionObjectId
  }
}

// resource app 'Microsoft.DesktopVirtualization/applicationGroups/applications@2023-09-05' = {
//   name: 'Remote Desktop'
//   parent: applicationGroup
//   properties: {
//     commandLineSetting: 'DoNotAllow'
//     applicationType: 'InBuilt'
//     friendlyName: 'Remote Desktop'
//     filePath: 'C:\\Windows\\System32\\mstsc.exe'
//     iconPath: 'C:\\Windows\\System32\\mstsc.exe'
//     iconIndex: 0
//     showInPortal: true
//   }
// }

resource workspace 'Microsoft.DesktopVirtualization/workspaces@2023-09-05' = {
  name: replace(avdNamingStructure, '{rtype}', abbreviations['AVD Workspace'])
  location: location
  properties: {
    friendlyName: '${workloadName} Research Enclave Access'
    applicationGroupReferences: [
      desktopApplicationGroup.id
    ]
  }
}

// Deploy Azure VMs and join them to the host pool
module avdVM 'avd-vmRG.bicep' = {
  name: replace(deploymentNameStructure, '{rtype}', 'avdvm')
  scope: subscription()
  params: {
    hostPoolRegistrationToken: hostPool.properties.registrationInfo.token
    hostPoolName: hostPool.name
    location: location
    tags: tags
    deploymentNameStructure: deploymentNameStructure
    namingStructure: avdVmNamingStructure
    abbreviations: abbreviations
    avdVmHostNameStructure: avdVmHostNameStructure
    avdSubnetId: avdSubnetId

    loginPermissionObjectId: loginPermissionObjectId
    virtualMachineUserLoginRoleDefinitionId: virtualMachineUserLoginRoleDefinitionId
  }
}

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2023-04-01' = if (usePrivateLinkForHostPool) {
  name: replace(avdNamingStructure, '{rtype}', 'hp-pep')
  location: location
  tags: tags
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: replace(avdNamingStructure, '{rtype}', 'hp-pep')
        properties: {
          privateLinkServiceId: hostPool.id
          groupIds: [
            'connection'
          ]
        }
      }
    ]
  }
}

resource privateEndpointDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-04-01' = if (usePrivateLinkForHostPool) {
  name: 'default'
  parent: privateEndpoint
  properties: {
    privateDnsZoneConfigs: [
      {
        name: replace('privatelink.wvd.microsoft.com', '.', '-')
        properties: {
          privateDnsZoneId: privateLinkDnsZoneId
        }
      }
    ]
  }
}

// MAYBE: Create ASG for hosts? This is only relevant for NSGs, not for firewall rules though.
