<#
.SYNOPSIS
	PowerShell script to deploy the main.bicep template with parameter values
#>

#Requires -Modules "Az", "Microsoft.Graph.Groups"
#Requires -PSEdition Core

# TODO: Use Bicep parameter file instead 

# Use these parameters to customize the deployment instead of modifying the default parameter values
[CmdletBinding(SupportsShouldProcess)]
Param(
	[Parameter(Mandatory)]
	[string]$ProjectSubscriptionId,
	[Parameter(Mandatory)]
	[string]$TenantId,
	[Parameter()]
	[string]$TemplateParameterFile = 'main-prj.bicepparam'
)

Connect-MgGraph -Scopes "Group.Read.All" -NoWelcome

# Define common parameters for the New-AzDeployment cmdlet
[hashtable]$CmdLetParameters = @{
	TemplateFile = 'main-prj.bicep'
	#	projectMemberObjectIds = $ProjectTransitiveMembers
}

# Process the template parameter file and read relevant values for use here
Write-Verbose "Using template parameter file '$TemplateParameterFile'"
[string]$TemplateParameterJsonFile = [System.IO.Path]::ChangeExtension($TemplateParameterFile, 'json')
bicep build-params $TemplateParameterFile --outfile $TemplateParameterJsonFile

$CmdLetParameters.Add('TemplateParameterFile', $TemplateParameterJsonFile)

# Read the values from the parameters file, to use when generating the $DeploymentName value
$ParameterFileContents = (Get-Content $TemplateParameterJsonFile | ConvertFrom-Json)
$WorkloadName = $ParameterFileContents.parameters.workloadName.value
$Location = $ParameterFileContents.parameters.location.value

$ProjectAadGroupObjectId = $ParameterFileContents.parameters.projectMemberAadGroupObjectId.value

# Break down the group member object ID into transitive user members
[array]$ProjectTransitiveMembers = Get-MgGroupTransitiveMemberAsUser -GroupId $ProjectAadGroupObjectId -Select UserPrincipalName, Id | `
	Select-Object @{E = { $_.Id }; L = "objectId" }, @{E = { $_.UserPrincipalName }; L = "upn" } | `
	# Perform some PowerShell tricks to convert the object into something Bicep/ARM can handle
	ConvertTo-Json | ConvertFrom-Json -AsHashTable

Write-Verbose "Project member count: $($ProjectTransitiveMembers.Length)"

$CmdLetParameters.Add('projectMemberObjectIds', $ProjectTransitiveMembers)

# Generate a unique name for the deployment
[string]$DeploymentName = "$WorkloadName-$(Get-Date -Format 'yyyyMMddThhmmssZ' -AsUTC)"
$CmdLetParameters.Add('Name', $DeploymentName)
$CmdLetParameters.Add('Location', $Location)

# Ignore the WhatIfPreference for the subscription selection, otherwise the deployment might indicate that all resources will be created.
Select-AzSubscription $ProjectSubscriptionId -Tenant $TenantId -WhatIf:$false

# Execute the deployment
$DeploymentResult = New-AzDeployment @CmdLetParameters -WhatIf:$WhatIfPreference

if ($DeploymentResult.ProvisioningState -eq 'Succeeded') {
	# Extract output values from the DeploymentResult
	[string]$PrivateStorageAccountName = $DeploymentResult.Outputs.privateStorageAccountName.Value
	[string]$DataResourceGroupName = $DeploymentResult.Outputs.dataResourceGroupName.Value

	# AAD-join private storage account
	# LATER: Extract this into a separate module or use DeploymentScripts (we'll need it for the hub (airlock) too)

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
	
	# TODO: Set blob RBAC permission on export-request container (inside Bicep, see TODO in main-prj.bicep)
}
else {
	if (! $WhatIfPreference) {
		$DeploymentResult
		Write-Error -Message "❌ Project Deployment failed: $($DeploymentResult.ProvisioningState)" -ErrorAction Stop
	}
}