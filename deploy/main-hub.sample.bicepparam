using './main-hub.bicep'

param location = 'eastus'
param environment = 'Test'
param workloadName = ''
// Recommend using a Key Vault reference: az.
param airlockVmLocalAdminPassword = ''
param computeDnsSuffix = ''
param aadSysAdminGroupObjectId = ''
param aadDataAdminGroupObjectId = ''
param vnetAddressSpace = '10.19.0.0/16'
param subnetAddressSpace = '10.19.{octet3}.0/24'
param tags = {}
param sequence = 1
param namingConvention = '{rtype}-{wloadname}-{subwloadname}-{env}-{loc}-{seq}'
param airlockVmHostNameStructure = 'al-${workloadName}-${sequence}'
param deployBastionHost = true
