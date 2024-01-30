using './main-prj.bicep'

param location = 'eastus'
param environment = 'Test'
param workloadName = ''
param computeDnsSuffix = ''
param dataExportApproverEmail = ''
param projectMemberAadGroupObjectId = ''

param publicStorageAccountAllowedIPs = []

// This should be simplified in the future
param vnetOctet2Base = 20
param vnetOctet2 = vnetOctet2Base + sequence - 1
param vnetAddressSpace = '10.${vnetOctet2}.0.0/16'
param subnetAddressSpace = '10.${vnetOctet2}.{octet3}.0/24'

param hubSubscriptionId = ''
param hubWorkloadName = ''
param shortHubWorkloadName = ''
param deployResearchVm = false
param avdVmHostNameStructure = 'vm-${workloadName}${sequence}'
param aadSysAdminGroupObjectId = ''
param tags = {}
param sequence = 3
param hubSequence = 3
param hubNamingConvention = '{rtype}-{wloadname}-{subwloadname}-{env}-{loc}-{seq}'
param namingConvention = hubNamingConvention
