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
	[string]$ComputeDnsSuffix,
	[securestring]$AirlockVmLocalAdminPassword,
	[Parameter(Mandatory)]
	[string]$HubSubscriptionId,
	[Parameter(Mandatory)]
	[string]$TenantId,
	[string]$AadSysAdminGroupObjectId,
	[string]$AadDataAdminGroupObjectId
)

$TemplateParameters = @{
	# REQUIRED
	location                    = $Location
	environment                 = $Environment
	workloadName                = $WorkloadName
	computeDnsSuffix            = $ComputeDnsSuffix
	airlockVmLocalAdminPassword = $AirlockVmLocalAdminPassword
	aadSysAdminGroupObjectId    = $AadSysAdminGroupObjectId
	aadDataAdminGroupObjectId   = $AadDataAdminGroupObjectId

	# OPTIONAL
	sequence                    = $Sequence
	namingConvention            = $NamingConvention
	tags                        = @{
		'date-created' = (Get-Date -Format 'yyyy-MM-dd')
		purpose        = $Environment
		lifetime       = 'medium'
		'customer-ref' = 'WCM'
	}
}

Select-AzSubscription $HubSubscriptionId -Tenant $TenantId

$DeploymentResult = New-AzDeployment -Location $Location -Name "$WorkloadName-$Environment-$(Get-Date -Format 'yyyyMMddThhmmssZ' -AsUTC)" `
	-TemplateFile ".\main-hub.bicep" -TemplateParameterObject $TemplateParameters

$DeploymentResult

if ($DeploymentResult.ProvisioningState -eq 'Succeeded') {
	# AFTER ACTIONS

	# JOIN AIRLOCK STORAGE ACCOUNT TO AAD FOR AUTH
	# Extract output values from the DeploymentResult
	[string]$storageAccountName = $DeploymentResult.Outputs.airlockStorageAccountName.Value
	[string]$airlockResourceGroupName = $DeploymentResult.Outputs.airlockResourceGroupName.Value

	[string]$Uri = ('https://management.azure.com/subscriptions/{0}/resourceGroups/{1}/providers/Microsoft.Storage/storageAccounts/{2}?api-version=2021-04-01' -f $HubSubscriptionId, $airlockResourceGroupName, $storageAccountName);

	Write-Host $storageAccountName ", " $airlockResourceGroupName ", " $tenantId ", " $HubSubscriptionId "," $Uri

	$json = @{properties = @{azureFilesIdentityBasedAuthentication = @{directoryServiceOptions = "AADKERB" } } };
	$json = $json | ConvertTo-Json -Depth 99

	$token = $(Get-AzAccessToken).Token
	$headers = @{ Authorization = "Bearer $token" }

	try {
		Invoke-RestMethod -Uri $Uri -ContentType 'application/json' -Method PATCH -Headers $Headers -Body $json;
		New-AzStorageAccountKey -ResourceGroupName $airlockResourceGroupName -Name $storageAccountName -KeyName kerb1 -ErrorAction Stop

		Get-AzADServicePrincipal -Searchstring "[Storage Account] $storageAccountName.file.core.windows.net"
		Write-Host "🔥 Hub Deployment '$($DeploymentResult.DeploymentName)' successful 🙂"
	}
	catch {
		Write-Host $_.Exception.ToString()
		Write-Error -Message "Caught exception setting Storage Account directoryServiceOptions=AADKERB: $_" -ErrorAction Stop
	}
}

# TODO: Domain-join hub (review) private storage account
