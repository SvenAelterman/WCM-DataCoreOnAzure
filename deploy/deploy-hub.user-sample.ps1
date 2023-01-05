[CmdletBinding()]
Param()

[string]$HubSubscriptionId = 'SUBSCRIPTION ID OF RESEARCH HUB'
[string]$TenantId = 'AAD TENANT ID'

[string]$ComputeDnsSuffix = 'research.yourorg.domain'

# LATER: Get from Key Vault
$VmLocalCred = Get-Credential -Message 'Airlock VM local admin user name and password'
# TODO: Use in Bicep
[string]$AirlockVmLocalUserName = $VmLocalCred.UserName
[securestring]$AirlockVmLocalAdminPassword = $VmLocalCred.Password

[string]$AadDataAdminGroupObjectId = 'AAD GROUP OBJECT ID'
[string]$AadSysAdminGroupObjectId = 'AAD GROUP OBJECT ID'

./deploy-hub.ps1 -HubSubscriptionId $HubSubscriptionId -TenantId $TenantId `
	-ComputeDnsSuffix $ComputeDnsSuffix -AirlockVmLocalAdminPassword $AirlockVmLocalAdminPassword `
	-AadDataAdminGroupObjectId $AadDataAdminGroupObjectId  -AadSysAdminGroupObjectId $AadSysAdminGroupObjectId