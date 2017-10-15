function New-CMDpServer {
  [CmdletBinding(SupportsShouldProcess=$True)]
  param (
      [parameter(Mandatory=$True)]
        [ValidateNotNullOrEmpty()]
        [string] $ServerName,
      [parameter(Mandatory=$True)]
        [ValidateSet('Basic','Pxe')]
        [string] $RoleType
  )
  $date   = [DateTime]::Now.AddYears(30)
  $pxepwd = ConvertTo-SecureString "P@ssw0rd123" -AsPlainText -Force

  $svr = Get-CMSiteSystemServer -SiteSystemServerName $ServerName
  if (-not $svr) {
      Write-Verbose "creating site system role on: $ServerName"
      try {
          $svr = New-CMSiteSystemServer -SiteCode "P01" -SiteSystemServerName $ServerName
          Write-Verbose "$ServerName is now a site system server"
      }
      catch {
          Write-Error $_.Exception.Message
          break
      }
  }

  $dp  = Get-CMDistributionPoint -SiteSystemServerName $ServerName

  if (-not $dp) {
      Write-Verbose "creating DP role on: $ServerName"
      try {
          $dp  = Add-CMDistributionPoint -InputObject $svr -CertificateExpirationTimeUtc $date
          Write-Verbose "$ServerName is now a DP server"
      }
      catch {
          Write-Error $_.Exception.Message
          break
      }
  }

  Write-Verbose "configuring DP options"

  switch ($RoleType) {
    'Basic' {
      Set-CMDistributionPoint -InputObject $dp -Description "DP Server 123" -ClientConnectionType InternetAndIntranet `
        -EnableAnonymous $True -EnableBranchCache $True
      break
    'Pxe' {
      Set-CMDistributionPoint -InputObject $dp -Description "DP Server 123" -ClientConnectionType InternetAndIntranet `
        -EnableAnonymous $True -EnableBranchCache $True -EnablePxe $True -AllowPxeResponse $True -EnableUnknownComputerSupport $True `
        -PxePassword $pxepwd -RespondToAllNetwork
      break
    }
  } # switch
  Write-Host "$ServerName is now a DP server"
}
