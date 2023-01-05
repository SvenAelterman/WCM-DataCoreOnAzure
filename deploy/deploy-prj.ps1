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
	[string]$WorkloadName = 'researchprj',
	[ValidateLength(1, 10)]
	[string]$ShortWorkloadName = 'rsrchprj',
	[int]$Sequence = 1,
	[string]$NamingConvention = "{rtype}-{wloadname}-{subwloadname}-{env}-{loc}-{seq}",
	[Parameter(Mandatory)]
	[string]$ProjectSubscriptionId,
	[Parameter(Mandatory)]
	[string]$HubSubscriptionId,
	[Parameter(Mandatory)]
	[string]$TenantId,
	[Parameter(Mandatory)]
	[string]$ComputeDnsSuffix,
	[Parameter(Mandatory)]
	[string]$DataExportApproverEmail
)

$TemplateParameters = @{
	# REQUIRED
	location                = $Location
	environment             = $Environment
	workloadName            = $WorkloadName
	computeDnsSuffix        = $ComputeDnsSuffix
	dataExportApproverEmail = $DataExportApproverEmail

	# OPTIONAL
	shortWorkloadName       = $ShortWorkloadName
	hubSubscriptionId       = $HubSubscriptionId
	hubWorkloadName         = 'researchhub'
	sequence                = $Sequence
	hubSequence             = 1
	namingConvention        = $NamingConvention
	tags                    = @{
		'date-created' = (Get-Date -Format 'yyyy-MM-dd')
		purpose        = $Environment
		lifetime       = 'medium'
	}
}

Select-AzSubscription $ProjectSubscriptionId -Tenant $TenantId

$DeploymentResult = New-AzDeployment -Location $Location -Name "$WorkloadName-$Environment-$(Get-Date -Format 'yyyyMMddThhmmssZ' -AsUTC)" `
	-TemplateFile ".\main-prj.bicep" -TemplateParameterObject $TemplateParameters

$DeploymentResult

if ($DeploymentResult.ProvisioningState -eq 'Succeeded') {
	# Extract output values from the DeploymentResult
	[string]$PrivateStorageAccountName = $DeploymentResult.Outputs.privateStorageAccountName.Value
	[string]$DataResourceGroupName = $DeploymentResult.Outputs.dataResourceGroupName.Value

	$AzContext = Get-AzContext

	# AAD-join private storage account
	# LATER: Extract this into a separate module (we'll need it for the hub too)

	[string]$Uri = ('https://management.azure.com/subscriptions/{0}/resourceGroups/{1}/providers/Microsoft.Storage/storageAccounts/{2}?api-version=2021-04-01' -f $ProjectSubscriptionId, $DataResourceGroupName, $PrivateStorageAccountName);

	Write-Host $PrivateStorageAccountName ", " $DataResourceGroupName ", " $tenantId ", " $ProjectSubscriptionId "," $Uri

	$json = @{properties = @{azureFilesIdentityBasedAuthentication = @{directoryServiceOptions = "AADKERB" } } };
	$json = $json | ConvertTo-Json -Depth 99

	$token = $(Get-AzAccessToken).Token
	$headers = @{ Authorization = "Bearer $token" }

	try {
		Invoke-RestMethod -Uri $Uri -ContentType 'application/json' -Method PATCH -Headers $Headers -Body $json;
		New-AzStorageAccountKey -ResourceGroupName $DataResourceGroupName -Name $PrivateStorageAccountName -KeyName kerb1 -ErrorAction Stop

		# LATER: Use dynamic determination of FQDN for storage account
		# $storageAccountEndpoint = $AzContext | `
		# Select-Object -ExpandProperty Environment | `
		# Select-Object -ExpandProperty StorageEndpointSuffix
		Get-AzADServicePrincipal -Searchstring "[Storage Account] $PrivateStorageAccountName.file.core.windows.net"

		Write-Host "🔥 Project Deployment '$($DeploymentResult.DeploymentName)' successful 🙂"
	}
	catch {
		Write-Host $_.Exception.ToString()
		Write-Error -Message "Caught exception setting Storage Account directoryServiceOptions=AADKERB: $_" -ErrorAction Stop
	}
	
	# TODO: Grant admin consent for new App representing the Az File share?
	
	# TODO: Set file share (Az RBAC) permissions on share

	# TODO: Set blob RBAC permission on export-request container
}
