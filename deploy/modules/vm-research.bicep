param location string
param subnetName string
param virtualNetworkId string
param virtualMachineName string
param adminUsername string
@secure()
param adminPassword string

param tags object = {}
param patchMode string = 'AutomaticByOS'
param enableHotpatching bool = false
param virtualMachineComputerName string = virtualMachineName
param enableAcceleratedNetworking bool = true
param osDiskType string = 'StandardSSD_LRS'
param osDiskDeleteOption string = 'Delete'
param nicDeleteOption string = 'Delete'
param virtualMachineSize string = 'Standard_D2s_v4'

var vnetId = virtualNetworkId
//var vnetName = last(split(vnetId, '/'))
var subnetRef = '${vnetId}/subnets/${subnetName}'

// TODO: Add random 3 digits at the end
var networkInterfaceName = virtualMachineName

// TODO: Add existing virtual network and subnet resources to use as references

resource networkInterface 'Microsoft.Network/networkInterfaces@2021-03-01' = {
  name: networkInterfaceName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: subnetRef
          }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
    enableAcceleratedNetworking: enableAcceleratedNetworking
  }
  tags: tags
  dependsOn: []
}

resource virtualMachine 'Microsoft.Compute/virtualMachines@2022-03-01' = {
  name: virtualMachineName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: virtualMachineSize
    }
    storageProfile: {
      osDisk: {
        createOption: 'fromImage'
        managedDisk: {
          storageAccountType: osDiskType
        }
        deleteOption: osDiskDeleteOption
      }
      imageReference: {
        publisher: 'MicrosoftWindowsDesktop'
        offer: 'Windows-10'
        sku: 'win10-21h2-avd-g2'
        version: 'latest'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterface.id
          properties: {
            deleteOption: nicDeleteOption
          }
        }
      ]
    }
    osProfile: {
      computerName: virtualMachineComputerName
      adminUsername: adminUsername
      adminPassword: adminPassword
      windowsConfiguration: {
        enableAutomaticUpdates: true
        provisionVMAgent: true
        patchSettings: {
          enableHotpatching: enableHotpatching
          patchMode: patchMode
        }
      }
    }
    licenseType: 'Windows_Client'
  }
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
}

resource aadLoginExtension 'Microsoft.Compute/virtualMachines/extensions@2022-08-01' = {
  name: 'AADLoginForWindows'
  parent: virtualMachine
  location: location
  properties: {
    publisher: 'Microsoft.Azure.ActiveDirectory'
    type: 'AADLoginForWindows'
    autoUpgradeMinorVersion: true
    typeHandlerVersion: '1.0'
    // The setting below is key to enrolling in Intune
    settings: {
      mdmId: '0000000a-0000-0000-c000-000000000000'
    }
  }
}
