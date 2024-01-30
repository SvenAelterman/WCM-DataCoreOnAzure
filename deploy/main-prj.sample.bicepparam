using './main-prj.bicep'

param location = 'eastus'
param environment = 'Test'
param workloadName = ''
param computeDnsSuffix = ''
param dataExportApproverEmail = ''
param projectMemberAadGroupObjectId = ''

param publicStorageAccountAllowedIPs = []

// This should be simplified in the future
param vnetAddressSpace = '10.10.0.0/16'

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
