[CmdletBinding()]
Param()

[string]$ProjectSubscriptionId = 'RESEARCH PROJECT SUBSCRIPTION ID'
[string]$TenantId = 'AAD TENANT ID'

./deploy-vm-research.ps1 -ProjectSubscriptionId $ProjectSubscriptionId -TenantId $TenantId