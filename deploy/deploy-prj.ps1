# PowerShell script to deploy the main.bicep template with parameter values

#Requires -Modules "Az", "Microsoft.Graph.Groups"
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
	[ValidateLength(1, 10)]
	[string]$ShortWorkloadName = 'wcmprj',
	[int]$Sequence = 2,
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
	[string]$DataExportApproverEmail,

	[array]$PublicStorageAccountAllowedIPs,
	[Parameter(Mandatory)]
	[string]$ProjectAadGroupObjectId
)

# Break down the group member object ID into transitive user members
[array]$ProjectTransitiveMembers = Get-MgGroupTransitiveMemberAsUser -GroupId $ProjectAadGroupObjectId -Select UserPrincipalName, Id | `
	Select-Object @{E = { $_.Id }; L = "objectId" }, @{E = { $_.UserPrincipalName }; L = "upn" } | `
	# Perform some PowerShell tricks to convert the object into something Bicep/ARM can handle
	ConvertTo-Json | ConvertFrom-Json -AsHashTable

$TemplateParameters = @{
	# REQUIRED
	location                       = $Location
	environment                    = $Environment
	workloadName                   = $WorkloadName
	computeDnsSuffix               = $ComputeDnsSuffix
	dataExportApproverEmail        = $DataExportApproverEmail

	publicStorageAccountAllowedIPs = $PublicStorageAccountAllowedIPs

	projectMemberAadGroupObjectId  = $ProjectAadGroupObjectId
	projectMemberObjectIds         = $ProjectTransitiveMembers

	# OPTIONAL
	shortWorkloadName              = $ShortWorkloadName
	hubSubscriptionId              = $HubSubscriptionId
	hubWorkloadName                = 'wcmhub'
	sequence                       = $Sequence
	hubSequence                    = 2
	namingConvention               = $NamingConvention
	tags                           = @{
		'date-created' = (Get-Date -Format 'yyyy-MM-dd')
		purpose        = $Environment
		lifetime       = 'medium'
		'customer-ref' = 'WCM'
	}
}

Select-AzSubscription $ProjectSubscriptionId -Tenant $TenantId

$DeploymentResult = New-AzDeployment -Location $Location -Name "$WorkloadName-$Environment-$(Get-Date -Format 'yyyyMMddThhmmssZ' -AsUTC)" `
	-TemplateFile ".\main-prj.bicep" -TemplateParameterObject $TemplateParameters

if ($DeploymentResult.ProvisioningState -eq 'Succeeded') {
	# Extract output values from the DeploymentResult
	[string]$PrivateStorageAccountName = $DeploymentResult.Outputs.privateStorageAccountName.Value
	[string]$DataResourceGroupName = $DeploymentResult.Outputs.dataResourceGroupName.Value

	#$AzContext = Get-AzContext

	# AAD-join private storage account
	# LATER: Extract this into a separate module (we'll need it for the hub (airlock) too)

	# TODO: Replace this with the Az cmdlets now available: https://learn.microsoft.com/en-us/azure/storage/files/storage-files-identity-auth-azure-active-directory-enable?tabs=azure-powershell#configure-the-clients-to-retrieve-kerberos-tickets
	
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

		# TODO: Add domain name and domain GUID to Azure AD Kerberos configuration of file shares
	}
	catch {
		$DeploymentResult

		Write-Host $_.Exception.ToString()
		Write-Error -Message "Caught exception setting Storage Account directoryServiceOptions=AADKERB: $_" -ErrorAction Stop
	}
	
	# TODO: Grant admin consent for new App representing the Az File share? + exclude from MFA CA
	
	# TODO: Set file share (Az RBAC) permissions on share

	# TODO: Set blob RBAC permission on export-request container (inside Bicep, see TODO in main-prj.bicep)
}
else {
	Write-Error -Message "❌ Project Deployment failed: $($DeploymentResult.ProvisioningState)" -ErrorAction Stop
}