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
	#
	[Parameter()]
	[string]$WorkloadName = 'researchprj',
	#
	[int]$Sequence = 1,
	[string]$NamingConvention = "{rtype}-{wloadname}-{subwloadname}-{env}-{loc}-{seq}"
)

$TemplateParameters = @{
	# REQUIRED
	location          = $Location
	environment       = $Environment
	workloadName      = $WorkloadName

	# OPTIONAL
	hubSubscriptionId = '2715e6dd-7a1f-406c-9d9f-06122817408f'
	hubWorkloadName   = 'researchhub'
	sequence          = $Sequence
	namingConvention  = $NamingConvention
	tags              = @{
		'date-created' = (Get-Date -Format 'yyyy-MM-dd')
		purpose        = $Environment
		lifetime       = 'medium'
		'customer-ref' = 'WCM'
	}
}

# Sven's research project sub (5)
Select-AzSubscription 1097603d-3720-4053-9380-a61b085faf5d

$DeploymentResult = New-AzDeployment -Location $Location -Name "$WorkloadName-$Environment-$(Get-Date -Format 'yyyyMMddThhmmssZ' -AsUTC)" `
	-TemplateFile ".\main-prj.bicep" -TemplateParameterObject $TemplateParameters

$DeploymentResult

if ($DeploymentResult.ProvisioningState -eq 'Succeeded') {
}

# TODO: Project templates: peering, NSGs