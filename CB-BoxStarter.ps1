<#
.DESCRIPTION
  Configuration Baseline - BoxStarter install
.NOTES
  configuration baseline remediation script for boxstarter installations
#>

. { Invoke-WebRequest -useb http://boxstarter.org/bootstrapper.ps1 } | Invoke-Expression; Get-BoxStarter -Force
