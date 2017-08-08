<#
.DESCRIPTION
  Configuration Baseline - Chocolatey install
.NOTES
  configuration baseline remediation script for chocolatey installations
#>

Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
##SET PATH=%PATH%;%ALLUSERSPROFILE%\chocolatey\bin
