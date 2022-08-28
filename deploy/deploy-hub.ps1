# PowerShell script to deploy the main.bicep template with parameter values

#Requires -Modules "Az"
#Requires -PSEdition Core

# Use these parameters to customize the deployment instead of modifying the default parameter values
[CmdletBinding()]
Param(
	[ValidateSet('eastus2', 'eastus')]
	[string]$Location = 'eastus2',
	# The environment descriptor
	[ValidateSet('Test', 'Demo', 'Prod')]
	[string]$Environment = 'Demo',
	[string]$WorkloadName = 'researchhub',
	[int]$Sequence = 1,
	[string]$NamingConvention = "{rtype}-$WorkloadName-{subwloadname}-{env}-{loc}-{seq}",
	[string]$computeDnsSuffix = 'research.aelterman.info'
)

$TemplateParameters = @{
	# REQUIRED
	location         = $Location
	environment      = $Environment
	workloadName     = $WorkloadName
	computeDnsSuffix = $computeDnsSuffix

	# OPTIONAL
	sequence         = $Sequence
	namingConvention = $NamingConvention
	tags             = @{
		'date-created' = (Get-Date -Format 'yyyy-MM-dd')
		purpose        = $Environment
		lifetime       = 'medium'
		'customer-ref' = 'WCM'
	}
}

# Sven's research hub sub (3)
Select-AzSubscription 2715e6dd-7a1f-406c-9d9f-06122817408f

$DeploymentResult = New-AzDeployment -Location $Location -Name "$WorkloadName-$Environment-$(Get-Date -Format 'yyyyMMddThhmmssZ' -AsUTC)" `
	-TemplateFile ".\main-hub.bicep" -TemplateParameterObject $TemplateParameters

$DeploymentResult

if ($DeploymentResult.ProvisioningState -eq 'Succeeded') {
	# AFTER ACTIONS
	# - Assign access to AVD application group + Virtual Machine User Login

}

# TODO: Domain-join hub (review) private storage accounts

# TODO: NSGs