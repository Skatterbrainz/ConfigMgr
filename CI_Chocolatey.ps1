<#
.DESCRIPTION
  Configuration Item - Chocolatey installed
.NOTES
  Configuration Item script for detecting chocolatey.
  Using verbose/explicit outputs
#>

if (Test-Path "$($env:PROGRAMDATA)\chocolatey\choco.exe") {
  Write-Output $True
}
else {
	Write-Output $False
}
