# PowerShell script to deploy the main.bicep template with parameter values

#Requires -Modules "Az"
#Requires -PSEdition Core

# Use these parameters to customize the deployment instead of modifying the default parameter values
[CmdletBinding()]
Param(
	[ValidateSet('eastus2', 'eastus')]
	[string]$Location = 'eastus',
	# The environment descriptor
	[ValidateSet('Test', 'Demo', 'Prod')]
	[string]$Environment = 'Demo',
	[string]$WorkloadName = 'wcmprj',
	[int]$Sequence = 2,
	[string]$NamingConvention = "{rtype}-$WorkloadName-{subwloadname}-{env}-{loc}-{seq}",
	[string]$VmNumber = "3",
	[Parameter(Mandatory)]
	[string]$ProjectSubscriptionId,
	[Parameter(Mandatory)]
	[string]$TenantId
)

[string]$SequenceFormatted = "{0:00}" -f $Sequence

$TemplateParameters = @{
	# REQUIRED
	location           = $Location
	subnetName         = 'default'
	virtualNetworkId   = '/subscriptions/2804b8a3-d41c-4603-815c-77d8813d196e/resourceGroups/rg-wcmprj-core-demo-eastus-02/providers/Microsoft.Network/virtualNetworks/vnet-wcmprj-core-demo-eastus-02'
	virtualMachineName = "prj$($SequenceFormatted)-vm$($VmNumber)"
	adminUsername      = 'AzureUser'
	# OPTIONAL
	tags               = @{
		'date-created'       = (Get-Date -Format 'yyyy-MM-dd')
		purpose              = $Environment
		lifetime             = 'medium'
		'customer-reference' = 'WCM'
	}
}

Select-AzSubscription $projectSubscriptionId -Tenant $tenantId

[string]$ResourceGroupName = $NamingConvention.Replace('{rtype}', 'rg').Replace('{env}', $Environment).Replace('{loc}', $Location).Replace('{seq}', $SequenceFormatted).Replace('{subwloadname}', 'compute').ToLower()

$DeploymentResult = New-AzResourceGroupDeployment -Location $Location -ResourceGroupName $ResourceGroupName `
	-Name "$WorkloadName-$Environment-$(Get-Date -Format 'yyyyMMddThhmmssZ' -AsUTC)" `
	-TemplateFile ".\modules\vm-research.bicep" -TemplateParameterObject $TemplateParameters

$DeploymentResult

if ($DeploymentResult.ProvisioningState -eq 'Succeeded') {
	Write-Host "🔥 Research VM Deployment '$($DeploymentResult.DeploymentName)' successful 🙂"
}
