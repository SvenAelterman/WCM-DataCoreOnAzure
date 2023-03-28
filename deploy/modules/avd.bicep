param namingStructure string
param location string
param abbreviations object
param avdVmHostNameStructure string
param avdSubnetId string

param environment string = ''
param deploymentNameStructure string = '{rtype}-${utcNow()}'
param tags object = {}
param baseTime string = utcNow('u')
param deployVmsInSeparateRG bool = true

var avdNamingStructure = replace(namingStructure, '{subwloadname}', 'avd')
var avdVmNamingStructure = replace(namingStructure, '{subwloadname}', deployVmsInSeparateRG ? 'avd-vm' : 'avd')

resource hostPool 'Microsoft.DesktopVirtualization/hostPools@2019-12-10-preview' = {
  name: replace(avdNamingStructure, '{rtype}', abbreviations['AVD Host Pool'])
  location: location
  properties: {
    hostPoolType: 'Pooled'
    loadBalancerType: 'BreadthFirst'
    preferredAppGroupType: 'RailApplications'
    customRdpProperty: 'drivestoredirect:s:0;audiomode:i:0;videoplaybackmode:i:1;redirectclipboard:i:0;redirectprinters:i:0;devicestoredirect:s:0;redirectcomports:i:0;redirectsmartcards:i:1;usbdevicestoredirect:s:0;enablecredsspsupport:i:1;use multimon:i:1;targetisaadjoined:i:1;'
    friendlyName: '${environment} Research Enclave Access'
    // TODO: startVMOnConnect requires role configuration
    startVMOnConnect: true
    registrationInfo: {
      registrationTokenOperation: 'Update'
      // Expire the new registration token in two days
      expirationTime: dateTimeAdd(baseTime, 'P2D')
    }
  }
}

resource applicationGroup 'Microsoft.DesktopVirtualization/applicationGroups@2021-09-03-preview' = {
  name: replace(avdNamingStructure, '{rtype}', abbreviations['AVD App Group'])
  location: location
  properties: {
    hostPoolArmPath: hostPool.id
    applicationGroupType: 'RemoteApp'
  }
}

resource app 'Microsoft.DesktopVirtualization/applicationGroups/applications@2021-09-03-preview' = {
  name: 'Remote Desktop'
  parent: applicationGroup
  properties: {
    commandLineSetting: 'DoNotAllow'
    applicationType: 'InBuilt'
    friendlyName: 'Remote Desktop'
    filePath: 'C:\\Windows\\System32\\mstsc.exe'
    iconPath: 'C:\\Windows\\System32\\mstsc.exe'
    iconIndex: 0
    showInPortal: true
  }
}

resource workspace 'Microsoft.DesktopVirtualization/workspaces@2021-09-03-preview' = {
  name: replace(avdNamingStructure, '{rtype}', abbreviations['AVD Workspace'])
  location: location
  properties: {
    friendlyName: 'Research Enclave Access'
    applicationGroupReferences: [
      applicationGroup.id
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
  }
}

// TODO: Create ASG for hosts?
