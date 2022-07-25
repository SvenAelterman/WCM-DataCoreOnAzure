param namingStructure string
param hostPoolRegistrationToken string
param location string
param abbreviations object
param deploymentNameStructure string
param avdVmHostNameStructure string
param hostPoolName string
param avdSubnetId string

param vmCount int = 1

// Use the same VM templates as used by the Add VM to hostpool process
var nestedTemplatesLocation = 'https://wvdportalstorageblob.blob.core.windows.net/galleryartifacts/armtemplates/Hostpool_12-9-2021/nestedTemplates/'
var vmTemplateUri = '${nestedTemplatesLocation}managedDisks-galleryvm.json'

var rdshPrefix = '${avdVmHostNameStructure}-'

// Create availability set
// TODO: Consider moving this to the AVD resource group instead of the VM resource group [the availability set should survive deleting VMs]
resource availabilitySet 'Microsoft.Compute/availabilitySets@2021-11-01' = {
  name: replace(namingStructure, '{rtype}', abbreviations['Availability Set'])
  location: location
  properties: {
    platformFaultDomainCount: 2
    platformUpdateDomainCount: 5
  }
  sku: {
    name: 'Aligned'
  }
}

// Deploy the session host VMs just like the Add VM to hostpool process would
resource vmDeployment 'Microsoft.Resources/deployments@2021-04-01' = {
  name: replace(deploymentNameStructure, '{rtype}', 'avdvm')
  properties: {
    mode: 'Incremental'
    templateLink: {
      uri: vmTemplateUri
      contentVersion: '1.0.0.0'
    }
    parameters: {
      artifactsLocation: {
        value: 'https://wvdportalstorageblob.blob.core.windows.net/galleryartifacts/Configuration_02-23-2022.zip'
      }
      availabilityOption: {
        value: 'AvailabilitySet'
      }
      availabilitySetName: {
        value: availabilitySet.name
      }
      vmGalleryImageOffer: {
        value: 'office-365'
      }
      vmGalleryImagePublisher: {
        value: 'microsoftwindowsdesktop'
      }
      vmGalleryImageHasPlan: {
        value: false
      }
      vmGalleryImageSKU: {
        value: 'win11-21h2-avd-m365'
      }
      rdshPrefix: {
        value: rdshPrefix
      }
      rdshNumberOfInstances: {
        value: vmCount
      }
      rdshVMDiskType: {
        value: 'StandardSSD_LRS'
      }
      rdshVmSize: {
        value: 'Standard_D2s_v3'
      }
      enableAcceleratedNetworking: {
        value: true
      }
      vmAdministratorAccountUsername: {
        value: 'AzureUser'
      }
      vmAdministratorAccountPassword: {
        value: 'Test1234'
      }
      administratorAccountUsername: {
        value: ''
      }
      administratorAccountPassword: {
        value: ''
      }
      'subnet-id': {
        value: avdSubnetId
      }
      vhds: {
        value: 'vhds/${rdshPrefix}'
      }
      location: {
        value: location
      }
      createNetworkSecurityGroup: {
        value: false
      }
      vmInitialNumber: {
        value: 0
      }
      hostpoolName: {
        value: hostPoolName
      }
      hostpoolToken: {
        value: hostPoolRegistrationToken
      }
      aadJoin: {
        value: true
      }
      intune: {
        value: true
      }
      securityType: {
        value: 'TrustedLaunch'
      }
      secureBoot: {
        value: true
      }
      vTPM: {
        value: true
      }
      vmImageVhdUri: {
        value: ''
      }
    }
  }
}

// TODO: Join hosts to ASG
