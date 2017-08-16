
<#
.SYNOPSIS
  Stupid function for a stupid reason
.DESCRIPTION
  why am I having to write this?
  why doesnt Get-CMDiscoveryMethod return a "Enabled" property?
  why does Get-CMDiscoveryMethod take sooooo long to execute?
  why are you reading this?
  why am I talking to myself?
.NOTES
  get some sleep - this function takes a looooong time to execute
#>

function Test-CMDiscoveryEnabled {
	[CmdletBinding()]
    param (
        [parameter(Mandatory=$True, ValueFromPipeline=$True)]
        [ValidateSet('ActiveDirectoryForest',
            'ActiveDirectoryGroupDiscovery',
            'ActiveDirectorySystemDiscovery',
            'ActiveDirectoryUserDiscovery',
            'HeartbeatDiscovery',
            'NetworkDiscovery')]
        [string] $Name
    )
    Get-CMDiscoveryMethod -Name $Name | 
        Select-Object -ExpandProperty Props | 
            Where-Object {$_.Value1 -eq "ACTIVE"} | 
                Select-Object -ExpandProperty Value1 | 
                    Foreach-Object {$_ -eq 'ACTIVE'}
}
