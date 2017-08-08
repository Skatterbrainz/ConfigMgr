<#
.SYNOPSIS
  BoxStarter/Chocolatey-ish script to configure an SCCM current branch Site Server

.DESCRIPTION
  Runs with boxstarter command (e.g. http://boxstarter.org/package/url?<gist_url>)
  Click the RAW button (not to be confused with WWE Raw), then copy the URL from the address bar, and paste into
  a PowerShell console on target machine after the ...url? string shown above.
  
  For example: http://boxstarter.org/package/url?http://blahbblah2304923049238092384092384093804928/sccm-setup.txt
  
  Portions of code adapted from... 
    https://www.windows-noob.com/forums/topic/14862-how-can-i-install-system-center-configuration-manager-version-1606-current-branch-on-windows-server-2016-with-sql-2016/?p=56812

.NOTES
  Spewed forth by: David Stein
  https://www.github.com/skatterbrainz
  Created........: 12/17/2016
  Modified.......: 01/25/2017
  
  Assumptions: 
  1. The computer is already assigned the intended name
  2. The computer is assigned a static IP, DNS and gateway
  3. Secondary disks are allocated (e.g. E:, F:
  4. The computer is joined to the target domain
  5. The server is Windows Server 2012 R2 or 2016
  6. The apps are SQL 2016, CM 1606, MDT 8443, ADK 1607
  
  Yes, you can use BoxStarter to handle the above steps too, but I was lazy and tired
  like a typical cranky old bastard that never gets his way in life, bah!!!
  
  Custom Files (see ZIP file under sccm-ps repo)...
  1. ServerRoles.xml (in scripts folder)
  2. RolesWsus.xml (in scripts folder)
  3. SqlConfig.ini (in scripts folder)
  4. SSMS-Setup-ENU.exe (in SQL source folder)
  5. CmConfig.ini (in scripts folder)
  6. ConfigMgrTools.msi (in SCCM source folder)
  7. ConfigMgr2012PowerShellCmdlets.msi (in SCCM source folder)
#>

#------------------------------------------------------------
# global parameters
#------------------------------------------------------------
$ServerName    = "CM01"
$DomainName    = "CONTOSO"
$DomainSuffix  = "contoso.com"
$scriptsPath   = "\\FS1\Scripts\CM"
$sharedSource  = "\\FS1\Apps\Sources\2016\SXS"
$sqlSource     = "\\FS1\Apps\MS\SQL2016"
$mdtSource     = "\\FS1\Apps\MS\MDT8443"
$adkSource     = "\\FS1\Apps\MS\ADK1607"
$cmSource      = "\\FS1\Apps\MS\CM1606"
$cmTarget      = "E:\ConfigMgr"
$cmPrereqs     = "E:\CMPreReqs"
$WSUSFolder    = "E:\wsus"
$SqlMemMin     = 8192
$SqlMemMax     = 8192
$tmpFolder     = $env:TEMP
$ScriptVersion = "2017.01.25.01"
#------------------------------------------------------------
# Note: You could leverage the dbatools PS module to handle the SQL memory configs
# but I'm still cranky and disappointed all the time.  Also, don't forget to 
# adjust the File Autogrowth assignments further below, or map them to your own
# variables if you prefer.
#------------------------------------------------------------
# SQL configuration file
# ref: https://msdn.microsoft.com/en-us/library/ms144259.aspx
#------------------------------------------------------------
# next line sets user as a SQL sysadmin
$yourusername="$DomainName\sccmadmin"
# path to the SQL media
$SQLsource="$sqlSource\"
$ACTION="Install"
$ASCOLLATION="Latin1_General_CI_AS"
$ErrorReporting="False"
$SUPPRESSPRIVACYSTATEMENTNOTICE="False"
$IACCEPTROPENLICENSETERMS="False"
$ENU="True"
$QUIET="True"
$QUIETSIMPLE="False"
$UpdateEnabled="True"
$USEMICROSOFTUPDATE="False"
$FEATURES="SQLENGINE,RS,CONN,IS,BC,SDK,BOL"
$UpdateSource="MU"
$HELP="False"
$INDICATEPROGRESS="False"
$X86="False"
$INSTANCENAME="MSSQLSERVER"
$INSTALLSHAREDDIR="C:\Program Files\Microsoft SQL Server"
$INSTALLSHAREDWOWDIR="C:\Program Files (x86)\Microsoft SQL Server"
$INSTANCEID="MSSQLSERVER"
$SQLBACKUPDIR="E:\SQLBACK"
$SQLUSERDBDIR="E:\SQLDB"
$SQLUSERDBLOGDIR="E:\SQLLOG"
$SQLTEMPDBDIR="E:\SQLTEMP"
$RSINSTALLMODE="DefaultNativeMode"
$SQLTELSVCACCT="NT Service\SQLTELEMETRY"
$SQLTELSVCSTARTUPTYPE="Automatic"
$ISTELSVCSTARTUPTYPE="Automatic"
$ISTELSVCACCT="NT Service\SSISTELEMETRY130"
$INSTANCEDIR="C:\Program Files\Microsoft SQL Server"
$AGTSVCACCOUNT="NT AUTHORITY\SYSTEM"
$AGTSVCSTARTUPTYPE="Automatic"
$ISSVCSTARTUPTYPE="Disabled"
$ISSVCACCOUNT="NT AUTHORITY\System"
$COMMFABRICPORT="0"
$COMMFABRICNETWORKLEVEL="0"
$COMMFABRICENCRYPTION="0"
$MATRIXCMBRICKCOMMPORT="0"
$SQLSVCSTARTUPTYPE="Automatic"
$FILESTREAMLEVEL="0"
$ENABLERANU="False"
$SQLCOLLATION="SQL_Latin1_General_CP1_CI_AS"
$SQLSVCACCOUNT="NT AUTHORITY\System"
$SQLSVCINSTANTFILEINIT="False"
$SQLSYSADMINACCOUNTS="$yourusername"
$SQLTEMPDBFILECOUNT="1"
$SQLTEMPDBFILESIZE="8"
$SQLTEMPDBFILEGROWTH="64"
$SQLTEMPDBLOGFILESIZE="8"
$SQLTEMPDBLOGFILEGROWTH="64"
$ADDCURRENTUSERASSQLADMIN="True"
$TCPENABLED="1"
$SqlSvcPwd=""
$NPENABLED="1"
$BROWSERSVCSTARTUPTYPE="Disabled"
$RSSVCACCOUNT="NT AUTHORITY\System"
$RSSVCSTARTUPTYPE="Automatic"
$IAcceptSQLServerLicenseTerms="True"
#------------------------------------------------------------
# SCCM configuration file
#------------------------------------------------------------
$Action="InstallPrimarySite"
$ProductID="EVAL"
$SiteCode="PS1"
$Sitename="Primary Site 1"
$SMSInstallDir="$cmTarget"
$SDKServer="$ServerName.$DomainSuffix"
$RoleCommunicationProtocol="HTTPorHTTPS"
$ClientsUsePKICertificate="0"
$PrerequisiteComp="0"
$PrerequisitePath="$cmPrereqs"
$ManagementPoint="$ServerName.$DomainSuffix"
$ManagementPointProtocol="HTTP"
$DistributionPoint="$ServerName.$DomainSuffix"
$DistributionPointProtocol="HTTP"
$DistributionPointInstallIIS="0"
$AdminConsole="1"
$JoinCEIP="0"
$SQLServerName="$ServerName.$DomainSuffix"
$DatabaseName="CM_PS1"
$SQLSSBPort="4022"
$CloudConnector="1"
$CloudConnectorServer="$ServerName.$DomainSuffix"
$UseProxy="0"
$ProxyName=""
$ProxyPort=""
$SysCenterId=""
$SAExpDate="$($(Get-Date).ToString("yyyy-MM-dd")) 00:00:00.000"
$SAActive="1"
$CurrentBranch="1"
#------------------------------------------------------------

$Boxstarter.RebootOk = $true

write-host "info: script version $ScriptVersion" -ForegroundColor Cyan

#------------------------------------------------------------
# functions
#------------------------------------------------------------

function Test-AppInstalled {
  param($DisplayName)
  $test = Get-WmiObject -Class Win32_Product | ? {$_.Caption -eq $DisplayName}
  (!($test -eq $null))
}

function Test-Feature {
  param($FeatureName)
  $(Get-WindowsFeature $FeatureName).Installed
}

function Disable-ServerManager {
  write-output "info: disabling server manager at startup..."
  New-ItemProperty -Path HKCU:\Software\Microsoft\ServerManager -Name DoNotOpenServerManagerAtLogon -PropertyType DWORD -Value "0x1" -Force | Out-Null
}

function Install-MsiPackage {
  param($ProductName, $Inst, $Options)
  if (Test-AppInstalled "$ProductName") {
    write-output "info: $ProductName is already installed"
  }
  else {
    if (Test-Path "$appInst") {
      write-output "info: installing $ProductName..."
      write-output "info: type...... msi"
      write-output "info: package... $Inst"
      write-output "info: options... $Options"
      $Arg2 = "/i ""$inst"" /qb! /norestart REBOOT=ReallySuppress"
      if ($Options -ne "") {
        $Arg2 += " ""$Options"""
      }
      try {
        $res = (Start-Process -FilePath "msiexec.exe" -ArgumentList $Arg2 -Wait -Passthru).ExitCode
        if ($res -ne 0) {
          write-output "error: exit code is $res"
          $errmsg = [ComponentModel.Win32Exception] $res
          write-output "error: $errmsg"
          $Boxstarter.RebootOk = $False
          break
        }
        else {
          write-output "info: exit code is $res"
        }
      }
      catch {
        $Boxstarter.RebootOk = $False
        write-output "error: installation failed!"
        break
      }
      write-output "info: installation successful"
      if (Test-PendingReboot) { Invoke-Reboot }
    }
    else {
      write-output "error: unable to locate $appInst"
      break
    }
  }
}

function Install-ExePackage {
  param($ProductName, $Inst, $Options)
  if (Test-AppInstalled "$ProductName") {
    write-output "info: $ProductName is already installed."
  }
  else {
    write-output "info: installing $ProductName..."
    write-output "info: type...... exe"
    write-output "info: source.... $Inst"
    write-output "info: options... $Options"
    try {
      $res = (Start-Process -FilePath "$Inst" -ArgumentList "$Options" -Wait -PassThru).ExitCode
      if ($res -ne 0) {
        write-output "error: exit code is $res"
        $Boxstarter.RebootOk = $False
        break
      }
      else {
        write-output "info: exit code is $res"
      }
    }
    catch {
      $ErrorMessage = $_.Exception.Message
      $FailedItem = $_.Exception.ItemName
      $Boxstarter.RebootOk = $False
      write-output "error: installation failed... $ErrorMessage"
      break
    }
    write-output "info: installation successful"
    if (Test-PendingReboot) { Invoke-Reboot }
  }
}

function Install-Roles {
  param(
    [parameter(Mandatory=$False)] $XmlFile = "", 
    [parameter(Mandatory=$False)] $RoleNames = ""
  )
  if ($xmlFile -ne "") {
    if (Test-Path $xmlFile) {
      write-output "info: installing server roles and features from config file..."
      Install-WindowsFeature -ConfigurationFilePath $xmlFile -Source $sharedSource
      write-output "info: roles and features installation completed."
    }
    else {
      write-output "error: unable to locate configuration file: $xmlFile"
      $Boxstarter.RebootOk = $False
      break
    }
  }
  else {
    write-output "info: installing server roles and features..."
    try {
      Install-WindowsFeature -Name $RoleNames.Split(",") -IncludeManagementTools -Source $sharedSource -ErrorAction Stop
    }
    catch {
      $ErrorMessage = $_.Exception.Message
      $FailedItem = $_.Exception.ItemName
      $Boxstarter.RebootOk = $False
      write-output "error: role names...... $RoleNames"
      write-output "error: config file..... $XmlFile"
      write-output "error: installation failed... $ErrorMessage"
      break
    }
    Start-Sleep -s 10
  }
#  if (Test-PendingReboot) { Invoke-Reboot }
}

#------------------------------------------------------------
# preliminary setup stuff
#------------------------------------------------------------

Disable-UAC
Disable-MicrosoftUpdate
Set-WindowsExplorerOptions -EnableShowHiddenFilesFoldersDrives -EnableShowProtectedOSFiles -EnableShowFileExtension
Disable-InternetExplorerESC
Disable-ServerManager

#------------------------------------------------------------
# windows roles and features
#------------------------------------------------------------

Install-Roles -XmlFile "$scriptsPath\ServerRoles.xml"
Install-Roles -RoleName "WDS"
Install-WindowsUpdate

#------------------------------------------------------------
# install SQL Server 2016
#------------------------------------------------------------

if (!(Test-AppInstalled "SQL Server 2016 Database Engine Services")) {
  
  # insert code here: if not using SYSTEM account, add domain account to "log on as service"
  
write-output "info: preparing unattend config file for SQL installation..."

$cfgData= @"
[OPTIONS]
Action="$ACTION"
ErrorReporting="$ERRORREPORTING"
Quiet="$Quiet"
Features="$FEATURES"
InstanceName="$INSTANCENAME"
InstanceDir="$INSTANCEDIR"
SQLBACKUPDIR="$SQLBACKUPDIR"
SQLUSERDBDIR="$SQLUSERDBDIR"
SQLUSERDBLOGDIR="$SQLUSERDBLOGDIR"
SQLTEMPDBDIR="$SQLTEMPDBDIR"
SQLSVCAccount="$SQLSVCACCOUNT"
SQLSysAdminAccounts="$SQLSYSADMINACCOUNTS"
SQLSVCStartupType="$SQLSVCSTARTUPTYPE"
AGTSVCACCOUNT="$AGTSVCACCOUNT"
AGTSVCSTARTUPTYPE="$AGTSVCSTARTUPTYPE"
RSSVCACCOUNT="$RSSVCACCOUNT"
RSSVCSTARTUPTYPE="$RSSVCSTARTUPTYPE"
ISSVCACCOUNT="$ISSVCACCOUNT" 
ISSVCSTARTUPTYPE="$ISSVCSTARTUPTYPE"
ASCOLLATION="$ASCOLLATION"
SQLCOLLATION="$SQLCOLLATION"
TCPENABLED="$TCPENABLED"
NPENABLED="$NPENABLED"
SQLSVCPASSWORD="$SqlSvcPwd"
AGTSVCPASSWORD="$SqlSvcPwd"
ASSVCPASSWORD="$SqlSvcPwd"
ISSVCPASSWORD="$SqlSvcPwd"
RSSVCPASSWORD="$SqlSvcPwd"
IAcceptSQLServerLicenseTerms="$IAcceptSQLServerLicenseTerms"
"@

  $cfgFile = "$scriptsPath\SqlConfigNew.ini"

  if (Test-Path "$cfgFile") {
    write-output "info: '$cfgFile' already exists, removing..."
    Remove-Item -Path "$cfgFile" -Force
    write-host "info: creating '$cfgFile'..."
    New-Item -Path "$cfgFile" -ItemType File -Value $cfgData
  } 
  else {
    write-host "info: creating '$cfgFile'..."
    New-Item -Path "$cfgFile" -ItemType File -Value $cfgData
  }

  $flist = @($SQLBACKUPDIR, $SQLUSERDBDIR, $SQLUSERDBLOGDIR, $SQLTEMPDBDIR)
  foreach ($n in $flist) {
    if (!(Test-Path $n)) {
      write-output "info: creating SQL folder: $n"
      New-Item -Path $n -ItemType Directory
    }
  }

  $prod    = "SQL Server 2016 Database Engine Services"
  $appInst = "$SQLsource\setup.exe"
  $argList = "/CONFIGURATIONFILE=$cfgFile"
  Install-ExePackage $prod $appInst $argList
}

#------------------------------------------------------------
# configure SQL memory limits
#------------------------------------------------------------

write-output "info: configuring SQL server memory limits..."
write-output "info: minimum = $SQLMemMin"
write-output "info: maximum = $SQLMemMax"
try {
  [System.Reflection.Assembly]::LoadWithPartialName('Microsoft.VisualBasic') | Out-Null
  [System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') | out-null
  $SQLMemory = New-Object ('Microsoft.SqlServer.Management.Smo.Server') ("(local)")
  $SQLMemory.Configuration.MinServerMemory.ConfigValue = $SQLMemMin
  $SQLMemory.Configuration.MaxServerMemory.ConfigValue = $SQLMemMax
  $SQLMemory.Configuration.Alter()
  write-output "info: SQL memory limits have been configured."
}
catch {
  write-output "error: failed to modify SQL memory limits. Continuing..."
}

#------------------------------------------------------------
# install SSMS
#------------------------------------------------------------

$prod    = "SQL Server 2016 Management Studio"
$appInst = "$sqlSource\SSMS-Setup-ENU.exe"
$argList = "/install /quiet /norestart"
Install-ExePackage $prod $appInst $argList

#------------------------------------------------------------
# install ADK
#------------------------------------------------------------

$prod    = "Windows Deployment Tools"
$appInst = "$adkSource\adksetup.exe"
$argList = " /Features OptionId.DeploymentTools OptionId.WindowsPreinstallationEnvironment OptionId.ImagingAndConfigurationDesigner OptionId.UserStateMigrationTool /norestart /quiet /ceip off"
Install-ExePackage $prod $appInst $argList

#------------------------------------------------------------
# install MDT
#------------------------------------------------------------

Install-MsiPackage "Microsoft Deployment Toolkit (6.3.8443.1000)" "$mdtSource\MicrosoftDeploymentToolkit_x64.msi" ""
# NOTE: Modify to use SQL database ****

#------------------------------------------------------------
# install WSUS role
#------------------------------------------------------------

if (!(Test-Path $WSUSFolder)) {
  write-output "info: creating wsus target folder..."
  New-Item -Path $WSUSFolder -ItemType Directory -Force
}
#Install-Roles -XmlFile "$scriptsPath\RoleWsus.xml"
Install-Roles -RoleNames "UpdateServices-Services,UpdateServices-DB,UpdateServices-RSAT"

write-output "info: invoking wsus post installation setup..."
$sqlhost = "$($env:COMPUTERNAME).$($env:USERDNSDOMAIN)"
write-output "info: wsus SQL_INSTANCE_NAME=$sqlhost"
write-output "info: wsus CONTENT_DIR=$WSUSFolder"
& 'C:\Program Files\Update Services\Tools\WsusUtil.exe' postinstall SQL_INSTANCE_NAME=$sqlhost CONTENT_DIR=$WSUSFolder | Out-Null

#------------------------------------------------------------
# Create firewall rule
#------------------------------------------------------------

if (!(Get-NetFirewallRule -DisplayName "SQL Server (TCP 1433) Inbound" -ErrorAction SilentlyContinue)) {
  write-output "info: creating network firewall rule..."
  New-NetFirewallRule -DisplayName "SQL Server (TCP 1433) Inbound" -Action Allow -Direction Inbound -LocalPort 1433 -Protocol TCP
}
else {
  write-output "info: firewall rule is already created."
}

#------------------------------------------------------------
# install SCCM 1606
#------------------------------------------------------------

if (!(Test-AppInstalled "ConfigMgr Management Point")) {

  # insert code here: extend AD schema
  # insert code here: create "system management" container
  # insert code here: delegate permissions on container to site server account
  
  write-output "info: preparing unattend config file for SCCM install..."

$cfgData= @"
[Identification]
Action="$Action"

[Options]
ProductID="$ProductID"
SiteCode="$SiteCode"
SiteName="$SiteName"
SMSInstallDir="$SMSInstallDir"
SDKServer="$ServerName"
RoleCommunicationProtocol="$RoleCommunicationProtocol"
ClientsUsePKICertificate="$ClientsUsePKICertificate"
PrerequisiteComp="$PrerequisiteComp"
PrerequisitePath="$PrerequisitePath"
ManagementPoint="$ManagementPoint"
ManagementPointProtocol="$ManagementPointProtocol"
DistributionPoint="$DistributionPoint"
DistributionPointProtocol="$DistributionPointProtocol"
DistributionPointInstallIIS="$DistributionPointInstallIIS"
AdminConsole="$AdminConsole"
JoinCEIP="$JoinCEIP"

[SQLConfigOptions]
SQLServerName="$SQLServerName"
DatabaseName="$DatabaseName"
SQLSSBPort="$SQLSSBPort"
SQLDataFilePath="$SQLUSERDBDIR"
SQLLogFilePath="$SQLUSERDBLOGDIR"

[CloudConnectorOptions]
CloudConnector="$CloudConnector"
CloudConnectorServer="$CloudConnectorServer"
UseProxy="$UseProxy"
ProxyName="$ProxyName"
ProxyPort="$ProxyPort"

[SystemCenterOptions]
SysCenterId="$SysCenterId"

[SABranchOptions]
SAActive="$SAActive"
CurrentBranch="$CurrentBranch"
SAExpiration="$SAExpDate"

[HierarchyExpansionOption]
"@

  if (!(Test-Path $SMSInstallDir)) {
    New-Item -Path $SMSInstallDir -ItemType Directory -Force
  }
  if (!(Test-Path $PrerequisitePath)) {
    New-Item -Path $PrerequisitePath -ItemType Directory -Force
  }
  
  Start-Sleep -Seconds 5
  
  $cfgFile = "$scriptsPath\CmConfigNew.ini"

  if (Test-Path "$cfgFile") {
    write-output "info: '$cfgFile' already exists, removing..."
    Remove-Item -Path "$cfgFile" -Force
    write-host "info: creating '$cfgFile'..."
    New-Item -Path "$cfgFile" -ItemType File -Value $cfgData
  } 
  else {
    write-host "info: creating '$cfgFile'..."
    New-Item -Path "$cfgFile" -ItemType File -Value $cfgData
  }
  $prod    = "ConfigMgr Management Point"
  $appInst = "$cmSource\SMSSETUP\bin\x64\setup.exe"
  $argList = "/script $cfgFile"
  Install-ExePackage $prod $appInst $argList
}

# insert code from here to handle MDT/SCCM configuration
# https://hinchley.net/2015/10/17/install-and-configure-microsoft-deployment-toolkit-2013-using-powershell/

#------------------------------------------------------------
# install CM 2012 R2 Toolkit
#------------------------------------------------------------

$prod    = "ConfigMgr 2012 Toolkit R2"
$appInst = "$cmSource\ConfigMgrTools.msi"
$argList = ""
Install-MsiPackage $prod $appInst $argList

# install CM powershell cmdlet library
$prod    = "System Center Configuration Manager Cmdlet Library"
$appInst = "$cmSource\ConfigMgr2012PowerShellCmdlets.msi"
$argList = ""
Install-MsiPackage $prod $appInst $argList

write-output "info: cleaning up and finishing..."

$Boxstarter.RebootOk = $False
Enable-WindowsUpdate
Enable-UAC

write-output "info: finished!"
