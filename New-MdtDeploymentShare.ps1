<#
.SYNOPSIS
    Create a new MDT deployment share
.DESCRIPTION
    Create a new MDT deployment share
.PARAMETER MDTShareRoot
    [string] (required) SMB folder path of root where new deployment share will be created
.PARAMETER MDTShareName
    [string] (required) Name of deployment share
.PARAMETER MDTBuildAccount
    [string] (required) Name of user account for MDT build processing
.PARAMETER MDTDescription
    [string] (optional) Description for new MDT deployment share
.NOTES
    David Stein 2017.10.04
.EXAMPLE
    New-MdtDeploymentShare.ps1 -MDTShareRoot "E:\MDTShares" -MDTShareName "BuildLab" -MDTBuildAccount "CONTOSO\MDT-BA" -MDTDescription "Build Lab Deployment Share"
#>
param (
	[parameter(Mandatory=$True, HelpMessage="Root folder path for MDT shares")]
		[ValidateNotNullOrEmpty()]
		[string] $MDTShareRoot,
	[parameter(Mandatory=$True, HelpMessage="MDT deployment share name without dollar sign")]
		[ValidateNotNullOrEmpty()]
		[string] $MDTShareName,
	[parameter(Mandatory=$True, HelpMessage="MDT Build Account Name")]
		[ValidateNotNullOrEmpty()]
		[string] $MDTBuildAccount,
	[parameter(Mandatory=$False, HelpMessage="MDT Depoyment share description")]
		[string] $MDTDescription = ""
)
$fullpath  = "$MDTShareRoot\$MDTShareName"
$sharename = "$MDTShareName`$"
$hostname  = $env:COMPUTERNAME
if ($MDTDescription -eq "") { $MDTDescription = $MDTShareName }

Write-Verbose "deployment share path........ $fullpath"
Write-Verbose "deployment share name........ $sharename"
Write-Verbose "deployment share full path... \\$hostname\$sharename"
Write-Verbose "deployment share comment..... $MDTDescription"
Write-Verbose "MDT build account............ $MDTBuildAccount"

$mdtpath = (Get-Item -Path "HKLM:\SOFTWARE\Microsoft\Deployment 4").GetValue("Install_Dir")

if (Test-Path $fullpath) {
	Write-Warning "$fullpath already exists!"
	break
}
if (-not (Test-Path "$mdtpath\bin\MicrosoftDeploymentToolkit.psd1")) {
    Write-Warning "MDT powershell module could not be located"
    break
}

Write-Host "Preparing deployment share at: $fullpath"

New-Item -Path "$fullpath" -ItemType Directory
New-SmbShare -Name "$sharename" -Path "$fullpath" -FullAccess Administrators
Import-Module "$mdtpath\bin\MicrosoftDeploymentToolkit.psd1"
New-PSDrive -Name "DS002" -PSProvider "MDTProvider" -Root "$fullpath" -Description "$MDTDescription" -NetworkPath "\\$hostname\$sharename" -Verbose | 
	Add-MDTPersistentDrive -Verbose

Write-Host "Configuring file and share access permissions"

icacls "$fullpath" /grant "$MDTBuildAccount`:(OI)(CI)(RX)"
icacls "$fullpath" /grant "Administrators:(OI)(CI)(F)"
icacls "$fullpath" /grant "SYSTEM:(OI)(CI)(F)"
icacls "$fullpath\Captures" /grant "$MDTBuildAccount`:(OI)(CI)(M)"
 
# Configure Sharing Permissions for the MDT Build Lab deployment share
Grant-SmbShareAccess -Name $sharename -AccountName "EVERYONE" -AccessRight Change -Force
Revoke-SmbShareAccess -Name $sharename -AccountName "CREATOR OWNER" -Force

Write-Host "Complete! If the MDT deployment workbench is open, refresh the deployment shares list"
