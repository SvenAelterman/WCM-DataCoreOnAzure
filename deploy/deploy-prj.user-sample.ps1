[CmdletBinding()]
Param()

[string]$ProjectSubscriptionId = 'RESEARCH PROJECT SUBSCRIPTION ID'
[string]$HubSubscriptionId = 'RESEARCH HUB SUBSCRIPTION ID'
[string]$TenantId = 'AAD TENANT ID'

[string]$ComputeDnsSuffix = 'research.yourorg.domain'

[string]$DataExportApproverEmail = 'email@yourorg.domain'

./deploy-prj.ps1 -ProjectSubscriptionId $ProjectSubscriptionId -HubSubscriptionId $HubSubscriptionId -TenantId $TenantId `
	-ComputeDnsSuffix $ComputeDnsSuffix -DataExportApproverEmail $DataExportApproverEmail