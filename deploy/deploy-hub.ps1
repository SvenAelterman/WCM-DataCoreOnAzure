<#
.SYNOPSIS
    Deploy the WCM DataCore Secure Enclave Hub resources to the target subscription.
#>

#Requires -Modules "Az"
#Requires -PSEdition Core

# Use these parameters to customize the deployment instead of modifying the default parameter values
[CmdletBinding(SupportsShouldProcess)]
Param(
	[Parameter(Mandatory)]
	[string]$HubSubscriptionId,
	[Parameter(Mandatory)]
	[string]$TenantId,
	[Parameter()]
	[string]$TemplateParameterFile = '.\main-hub.bicepparam'
)

# Define common parameters for the New-AzDeployment cmdlet
[hashtable]$CmdLetParameters = @{
	TemplateFile = '.\main-hub.bicep'
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

# Generate a unique name for the deployment
[string]$DeploymentName = "$WorkloadName-$(Get-Date -Format 'yyyyMMddThhmmssZ' -AsUTC)"
$CmdLetParameters.Add('Name', $DeploymentName)

$CmdLetParameters.Add('Location', $Location)

# Ignore the WhatIfPreference for the subscription selection, otherwise the deployment might indicate that all resources will be created.
Select-AzSubscription $HubSubscriptionId -Tenant $TenantId -WhatIf:$false

# Execute the deployment
$DeploymentResult = New-AzDeployment @CmdLetParameters -WhatIf:$WhatIfPreference

if ($DeploymentResult.ProvisioningState -eq 'Succeeded') {
	# AFTER ACTIONS
	# LATER: Move to deployment script

	# JOIN AIRLOCK STORAGE ACCOUNT TO AAD FOR AUTH
	# Extract output values from the DeploymentResult
	[string]$storageAccountName = $DeploymentResult.Outputs.airlockStorageAccountName.Value
	[string]$airlockResourceGroupName = $DeploymentResult.Outputs.airlockResourceGroupName.Value

	[string]$Uri = ('https://management.azure.com/subscriptions/{0}/resourceGroups/{1}/providers/Microsoft.Storage/storageAccounts/{2}?api-version=2021-04-01' -f $HubSubscriptionId, $airlockResourceGroupName, $storageAccountName);

	Write-Host $storageAccountName ", " $airlockResourceGroupName ", " $TenantId ", " $HubSubscriptionId "," $Uri

	$json = @{properties = @{azureFilesIdentityBasedAuthentication = @{directoryServiceOptions = "AADKERB" } } };
	$json = $json | ConvertTo-Json -Depth 99

	$token = $(Get-AzAccessToken).Token
	$headers = @{ Authorization = "Bearer $token" }

	try {
		Invoke-RestMethod -Uri $Uri -ContentType 'application/json' -Method PATCH -Headers $Headers -Body $json;
		New-AzStorageAccountKey -ResourceGroupName $airlockResourceGroupName -Name $storageAccountName -KeyName kerb1 -ErrorAction Stop

		Get-AzADServicePrincipal -Searchstring "[Storage Account] $storageAccountName.file.core.windows.net"

		# TODO: Grant admin consent for new App representing the Az File share?

		Write-Host "🔥 Hub Deployment '$($DeploymentResult.DeploymentName)' successful 🙂"
	}
	catch {
		Write-Host $_.Exception.ToString()
		Write-Error -Message "Caught exception setting Storage Account directoryServiceOptions=AADKERB: $_" -ErrorAction Stop
	}
}
else {
	if (! $WhatIfPreference) {
		$DeploymentResult
		Write-Error -Message "❌ Deployment failed 😢" -ErrorAction Stop
	}
}
