#requires -RunAsAdministrator
#requires -version 3
<#
.SYNOPSIS
  Import CM Applications from an XML file
.DESCRIPTION
  Import CM Applications from an XML file
.PARAMETER DataSet
  [xml] (required) results of XML import using Get-Content, etc.
.PARAMETER SiteCode
  [string] (required) ConfigMgr site code
.PARAMETER HostName
  [string] (required) ConfigMgr site server (MP or SMS Provider)
.NOTES
  Author: skatterbrainz@github
.EXAMPLE
  [xml]$xmldata = Get-Content ".\Import-Apps.xml"
  .\Import-Apps.ps1 -DataSet $xmldata -SiteCode "P01" -HostName "CM01"
#>
[CmdletBinding(SupportsShouldProcess=$True)]
param (
  [parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]
    $DataSet,
  [parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]
    [string] $SiteCode,
  [parameter(Mandatory=$True)]
    [ValidateNotNullOrEmpty()]
    [string] $HostName
)
# based on = https://raw.githubusercontent.com/DexterPOSH/PS_ConfigMgr/master/SCCM2012_CreateScriptApps.ps1
Import-Module -Name "$(Split-Path $Env:SMS_ADMIN_UI_PATH)\ConfigurationManager.psd1"
Set-Location -Path "$sitecode`:"

function Import-CMSiteApplications {
    [CmdletBinding(SupportsShouldProcess=$True)]
    param (
        $DataSet
    )
    $PSDefaultParameterValues =@{"get-cimclass:namespace"="Root\SMS\site_$sitecode";"get-cimclass:computername"="$hostname";"get-cimInstance:computername"="$hostname";"get-ciminstance:namespace"="Root\SMS\site_$sitecode"}
    foreach ($appSet in $DataSet.configuration.cmsite.applications.application | Where-Object {$_.enabled -eq 'true'}) {
        # APPLICATION
        # name="7-Zip" 
        # enabled="true" 
        # publisher="7-Zip" 
        # version="16.04" 
        # categories="General" 
        # comment="File compression utility" 
        # keywords="file,zip,utility,archive,compression"

        $appName = $appSet.name 
        $appComm = $appSet.comment
        $appPub  = $appSet.publisher
        $appVer  = $appSet.version
        $appCats = $appSet.categories
        $appKeys = $appSet.keywords

        Write-Verbose "app name......... $appName"
        Write-Verbose "app publisher.... $appPub"
        Write-Verbose "app comment...... $appComm"
        Write-Verbose "app version...... $appVer"
        Write-Verbose "app categories... $appCats"
        Write-Verbose "app keywords..... $appKeys"

        try {
            $app = New-CMApplication -Name "$appName" -Description "appComm" -SoftwareVersion "1.0" -AutoInstall $true -Publisher $appPub -ErrorAction SilentlyContinue
            Write-Verbose "application created successfully"
        }
        catch {
            if ($_.Exception.Message -eq 'An object with the specified name already exists.') {
                Write-Verbose "Application already defined"
                $app = Get-CMApplication -Name $appName
            }
            else {
                Write-Error $_.Exception.Message
                $app = $null
            }
        }
        if ($app) {
            foreach ($depType in $appSet.deptypes.deptype) {
                # DEPLOYMENT TYPE:
                # name="x64 installer" 
                # source="\\contoso.com\software\Apps\Notepad++\7.5\npp.7.5.installer.x64.exe" 
                # options="/s" 
                # uninstall="C:\Program Files\Notepad++\uninstall.exe" 
                # detect="registry:HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Notepad++,DisplayVersion(ge)7.5" 
                # requires="" 
                # comment="64-bit installer" />

                $depName   = $depType.name
                $depSource = $depType.source
                $depOpts   = $depType.options
                $depData   = $depType.detect
                $uninst    = $depType.uninstall
                $depComm   = $depType.comment
                $reqts     = $depType.requires
                $depPath   = Split-Path -Path $depSource
                $depFile   = Split-Path -Path $depSource -Leaf
                $program   = "$depFile $depOpts"

                Write-Verbose "dep name........ $depName"
                Write-Verbose "dep comment..... $depComm"
                Write-Verbose "dep Source...... $depSource"
                Write-Verbose "dep options..... $depOpts"
                Write-Verbose "dep detect...... $depData"
                Write-Verbose "dep uninstall... $uninst"
                Write-Verbose "dep reqts....... $reqts"
                Write-Verbose "dep path........ $depPath"
                Write-Verbose "dep file........ $depFile"
                Write-Verbose "dep program..... $program"

                if ($depOpts -eq 'auto') {
                    Write-Verbose "installer type: msi"
                    try {
                        Add-CMDeploymentType -ApplicationName $appName -AutoIdentifyFromInstallationFile -ForceForUnknownPublisher $true -InstallationFileLocation $depSource -MsiInstaller -DeploymentTypeName $depName
                        Write-Verbose "deployment type created"
                    }
                    catch {
                        if ($_.Exception.Message -like '*same name already exists.') {
                            Write-Verbose "deployment type already exists"
                        }
                        else {
                            Write-Error $_
                        }
                    }
                }
                else {
                    if ($depData.StartsWith("registry")) {
                        # registry:HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Notepad++,DisplayVersion,-ge,7.5
                        $depDetect  = $depData.Split(":")[1]
                        $depRuleSet = $depDetect.Split(",")
                        $ruleKey    = $depRuleSet[0] # "HKLM:\...."
                        $ruleKey = $ruleKey.Substring(5)
                        $ruleVal    = $depRuleSet[1] # "DisplayVersion"
                        $ruleChk    = $depRuleSet[2] # "-ge"
                        $ruleData   = $depRuleSet[3] # "7.5"
                    }
                    $scriptDetection = @"
try {
    $Reg = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, "default")
    $key = $reg.OpenSubKey("$ruleKey")
    $val = $key.GetValue("$ruleVal")
    if ($val $ruleChk "$ruleData") {Write-Host 'Installed'}
}
catch {}
"@
                    Write-Verbose "rule: $scriptDetection"

                    $DeploymentTypeHash = @{
                        ManualSpecifyDeploymentType = $true
                        ApplicationName = "$appName"
                        DeploymentTypeName = "$DepName"
                        DetectDeploymentTypeByCustomScript = $true
                        ScriptInstaller = $true
                        ScriptType = 'PowerShell'
                        ScriptContent =$scriptDetection
                        AdministratorComment = "$depComm"
                        ContentLocation = "$depPath"
                        InstallationProgram = "$program"
                        UninstallProgram = "$uninst"
                        RequiresUserInteraction = $false
                        InstallationBehaviorType = 'InstallForSystem'
                        InstallationProgramVisibility = 'Hidden'
                    }

                    Write-Verbose "Adding Deployment Type"

                    Add-CMDeploymentType @DeploymentTypeHash -EnableBranchCache $True

                    if ($folder -eq "") {
                        Write-Verbose "Moving application object to folder: $folder"
                        $app = Get-CMApplication -Name $ApplicationName
                        $app | Move-CMObject -FolderPath "Application\$folder" | Out-Null
                    }
                } # if
            } # foreach - deployment type
            Write-Verbose "-----------------------------------------------"
        } # if
    } # foreach - application
    Write-Output $result
}
