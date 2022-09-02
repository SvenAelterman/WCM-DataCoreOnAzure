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
	hubSequence       = 1
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
	# Extract output values from the DeploymentResult
	[string]$privateStorageAccountName = $DeploymentResult.Outputs.privateStorageAccountName.Value
	[string]$dataResourceGroupName = $DeploymentResult.Outputs.dataResourceGroupName.Value

	$azContext = Get-AzContext
	# AAD-join private storage account
	[string]$tenantId = $azContext.Tenant.Id
	[string]$subscriptionId = $azContext.Subscription.Id

	[string]$Uri = ('https://management.azure.com/subscriptions/{0}/resourceGroups/{1}/providers/Microsoft.Storage/storageAccounts/{2}?api-version=2021-04-01' -f $subscriptionId, $dataResourceGroupName, $privateStorageAccountName);

	Write-Host $privateStorageAccountName ", " $dataResourceGroupName ", " $tenantId ", " $subscriptionId "," $Uri

	$json = @{properties = @{azureFilesIdentityBasedAuthentication = @{directoryServiceOptions = "AADKERB" } } };
	$json = $json | ConvertTo-Json -Depth 99

	$token = $(Get-AzAccessToken).Token
	$headers = @{ Authorization = "Bearer $token" }

	try {
		Invoke-RestMethod -Uri $Uri -ContentType 'application/json' -Method PATCH -Headers $Headers -Body $json;
		New-AzStorageAccountKey -ResourceGroupName $dataResourceGroupName -Name $privateStorageAccountName -KeyName kerb1 -ErrorAction Stop

		Get-AzADServicePrincipal -Searchstring "[Storage Account] $privateStorageAccountName.file.core.windows.net"
	}
	catch {
		Write-Host $_.Exception.ToString()
		Write-Error -Message "Caught exception setting Storage Account directoryServiceOptions=AADKERB: $_" -ErrorAction Stop
	}
	
	# TODO: set permissions on share(s) (read-only: use app attach sample)


}
